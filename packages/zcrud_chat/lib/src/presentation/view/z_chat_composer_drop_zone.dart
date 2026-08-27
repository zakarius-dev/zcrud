/// **La zone de dépôt** — le socle expose la zone et le rappel ; le greffon de
/// glisser-déposer reste chez l'hôte.
///
/// ## Pourquoi une zone, et pas un `DropTarget`
///
/// Recevoir un fichier glissé depuis le bureau demande un greffon natif — il
/// n'y a rien dans `flutter/widgets` pour cela. Ce paquet n'en prend aucun :
/// un hôte qui ne reçoit jamais de fichier glissé ne doit hériter ni du
/// greffon, ni de ses entrées de manifeste, ni de sa surface native.
///
/// [ZChatComposerDropZone] fournit donc les deux pièces que le socle peut
/// tenir sans greffon :
///
/// * un **créneau enveloppant** ([wrap]) où l'hôte monte le widget de son
///   greffon autour de la saisie ;
/// * un **rappel** ([ZChatComposerDropHandle.deliver]) par lequel ce greffon
///   remet les fichiers, plus l'état de survol qui pilote la mise en évidence.
///
/// Le socle n'ouvre aucun fichier, ne lit aucun chemin, ne devine aucun type
/// MIME : c'est le greffon qui construit les [ZPendingAttachment].
///
/// ## Inertie
///
/// Sans [wrap], la zone rend **exactement** son enfant : aucun widget de plus
/// dans l'arbre, aucun geste changé. Un hôte qui n'a pas de greffon monte donc
/// la même chose qu'avant, ou ne monte pas la zone du tout.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../attachment/z_chat_attachment_controller.dart';
import '../attachment/z_pending_attachment.dart';

/// Ce que l'hôte reçoit quand des fichiers sont déposés.
typedef ZChatComposerFilesCallback =
    void Function(List<ZPendingAttachment> files);

/// Le créneau enveloppant : l'hôte y monte le widget de son greffon.
///
/// [handle] est la poignée par laquelle le greffon remet ses fichiers et
/// signale le survol ; [child] est la saisie à envelopper, telle quelle.
typedef ZChatComposerDropWrap =
    Widget Function(
      BuildContext context,
      ZChatComposerDropHandle handle,
      Widget child,
    );

/// La poignée remise au greffon d'hôte.
///
/// Elle ne porte que deux verbes, et aucun des deux ne lit quoi que ce soit :
/// le socle **reçoit** ce que le greffon lui donne.
abstract interface class ZChatComposerDropHandle {
  /// Remet les fichiers déposés.
  ///
  /// Chacun traverse le contrôleur de pièces jointes quand il y en a un —
  /// c'est lui, et lui seul, qui applique le plafond, les types admis et la
  /// taille maximale. Le rappel d'hôte reçoit ensuite la liste **telle qu'elle
  /// a été déposée**, y compris les fichiers que le contrôleur a refusés :
  /// c'est l'hôte qui décide s'il en dit quelque chose.
  ///
  /// Le survol est remis à `false` : un dépôt met fin au survol.
  void deliver(List<ZPendingAttachment> files);

  /// Signale que des fichiers survolent la zone (ou ne la survolent plus).
  void setHovering(bool value);

  /// L'état de survol, pour une mise en évidence à rebuild ciblé.
  ValueListenable<bool> get isHovering;
}

/// Zone enveloppante recevant des fichiers déposés par un greffon d'hôte.
class ZChatComposerDropZone extends StatefulWidget {
  /// Construit la zone.
  const ZChatComposerDropZone({
    super.key,
    required this.child,
    this.onFiles,
    this.attachments,
    this.wrap,
    this.overlay,
  });

  /// La saisie enveloppée.
  final Widget child;

  /// Rappel d'hôte, appelé avec les fichiers déposés. `null` ⇒ seul le
  /// contrôleur de pièces jointes est servi (s'il y en a un).
  final ZChatComposerFilesCallback? onFiles;

  /// Contrôleur qui reçoit les fichiers déposés. `null` ⇒ le socle ne les
  /// range nulle part : il se contente de les transmettre à [onFiles].
  final ZChatAttachmentController? attachments;

  /// Le créneau enveloppant. `null` ⇒ zone **inerte** : l'arbre est celui de
  /// [child], à l'identique.
  final ZChatComposerDropWrap? wrap;

  /// Mise en évidence pendant le survol, superposée à [child].
  ///
  /// `null` ⇒ aucune mise en évidence. Le socle n'en peint aucune de son
  /// propre chef : il n'a ni la couleur, ni le libellé (invariant FR-26).
  final WidgetBuilder? overlay;

  @override
  State<ZChatComposerDropZone> createState() => _ZChatComposerDropZoneState();
}

class _ZChatComposerDropZoneState extends State<ZChatComposerDropZone>
    implements ZChatComposerDropHandle {
  /// Créé une fois — jamais au rebuild (invariant AD-2).
  final ValueNotifier<bool> _hovering = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get isHovering => _hovering;

  @override
  void setHovering(bool value) {
    if (!mounted) return;
    _hovering.value = value;
  }

  @override
  void deliver(List<ZPendingAttachment> files) {
    _hovering.value = false;
    if (files.isEmpty) return;
    final ZChatAttachmentController? sink = widget.attachments;
    if (sink != null) {
      for (final ZPendingAttachment f in files) {
        // Le résultat n'est pas relu ici : le contrôleur porte déjà son
        // dernier échec dans sa propre tranche, et le socle ne double pas
        // cette source.
        sink.add(f);
      }
    }
    widget.onFiles?.call(List<ZPendingAttachment>.unmodifiable(files));
  }

  @override
  void dispose() {
    _hovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZChatComposerDropWrap? wrap = widget.wrap;
    // Zone INERTE : pas de greffon monté, donc rien de plus dans l'arbre.
    if (wrap == null) return widget.child;

    final WidgetBuilder? overlay = widget.overlay;
    // La `Stack` est montée UNE fois, dès que l'hôte demande une mise en
    // évidence — jamais insérée puis retirée au gré du survol. Un enfant qui
    // change de parent est réinflaté : la saisie y perdrait son état, et donc
    // son focus et son curseur (invariant AD-2). Seule la COUCHE du dessus
    // s'allume et s'éteint.
    final Widget body =
        overlay == null
            ? widget.child
            : Stack(
              // Invariant AD-13 : alignement directionnel.
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                widget.child,
                Positioned.fill(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hovering,
                    builder:
                        (BuildContext context, bool hovering, Widget? _) =>
                            hovering
                                ? overlay(context)
                                : const SizedBox.shrink(),
                  ),
                ),
              ],
            );

    return wrap(context, this, body);
  }
}
