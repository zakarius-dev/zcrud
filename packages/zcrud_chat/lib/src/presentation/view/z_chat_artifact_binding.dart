/// La dérivation **déclaration → rendu** d'un artefact, et le créneau
/// d'actions branché sur le contrôleur de fil de travail.
///
/// ## Une déclaration, un rendu dérivé
///
/// L'hôte déclare ses artefacts **une fois**, dans le vocabulaire pur du
/// kernel (`ZChatArtifactDeclaration` : clé, jetons d'icône, de libellé et
/// d'accent, verbes). Ce fichier en dérive la forme de rendu
/// ([ZChatArtifactSpec] : `IconData`, `Color`, texte localisé, lectures
/// d'état) en lisant l'état dans le contrôleur et en résolvant les jetons
/// par les **résolveurs de l'hôte** ([ZChatArtifactResolvers]).
///
/// ## Le socle n'invente rien
///
/// Un jeton qu'aucun résolveur ne reconnaît donne un glyphe **absent**, une
/// couleur **absente**, un libellé **vide** — jamais un glyphe, une couleur
/// ou un mot choisis par le socle. C'est ce qui garantit qu'une déclaration
/// incomplète est visible comme telle, et qu'aucune chaîne n'est codée ici.
///
/// ## Le créneau, par tranche
///
/// [zChatNotebookArtifactsSlot] rend la barre d'artefacts d'un message sous
/// un écouteur qui n'observe **que les tranches de ce message** : une
/// génération qui aboutit sur un message ne reconstruit que sa barre.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../notebook/z_chat_notebook_controller.dart';
import '../render/z_chat_seam_failure.dart';
import 'z_chat_artifact_bar.dart';
import 'z_chat_artifact_spec.dart';
import 'z_chat_message_tile.dart';
import 'z_chat_notebook_skin.dart';

/// Résout une clé d'icône opaque en glyphe. `null` signifie aucun glyphe.
typedef ZChatArtifactIconResolver = IconData? Function(String iconKey);

/// Résout un jeton de libellé en texte **déjà localisé**. `null` signifie
/// aucun texte.
typedef ZChatArtifactLabelResolver = String? Function(String labelToken);

/// Résout un jeton d'accent en couleur. `null` signifie la couleur ambiante
/// (chaîne `ZChatNotebookSkin` puis thème).
typedef ZChatArtifactAccentResolver = Color? Function(String accentToken);

/// Les trois résolveurs de l'hôte. Chacun est optionnel : absent, le jeton
/// correspondant n'est jamais résolu.
@immutable
class ZChatArtifactResolvers {
  /// Construit les résolveurs.
  const ZChatArtifactResolvers({this.icon, this.label, this.accent});

  /// Aucun résolveur : ni glyphe, ni texte, ni couleur.
  static const ZChatArtifactResolvers none = ZChatArtifactResolvers();

  /// Résolveur d'icône.
  final ZChatArtifactIconResolver? icon;

  /// Résolveur de libellé.
  final ZChatArtifactLabelResolver? label;

  /// Résolveur d'accent.
  final ZChatArtifactAccentResolver? accent;

  /// Le glyphe de [iconKey], ou `null`. Un résolveur qui lève vaut `null`.
  IconData? iconOf(String? iconKey) {
    final ZChatArtifactIconResolver? resolve = icon;
    if (iconKey == null || resolve == null) return null;
    try {
      return resolve(iconKey);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return null;
    }
  }

  /// Le texte de [labelToken], ou `null`. Un résolveur qui lève vaut `null`.
  String? labelOf(String? labelToken) {
    final ZChatArtifactLabelResolver? resolve = label;
    if (labelToken == null || resolve == null) return null;
    try {
      return resolve(labelToken);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return null;
    }
  }

  /// La couleur de [accentToken], ou `null`. Un résolveur qui lève vaut
  /// `null`.
  Color? accentOf(String? accentToken) {
    final ZChatArtifactAccentResolver? resolve = accent;
    if (accentToken == null || resolve == null) return null;
    try {
      return resolve(accentToken);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return null;
    }
  }
}

/// Dérive la forme de rendu de [declaration], l'état étant lu dans
/// [controller] et les jetons résolus par [resolvers].
///
/// * présence, compte et occupation lisent la tranche
///   `controller.statusOf(message, clé)` — un message sans identité est
///   traité comme absent ;
/// * chaque verbe est visible **si et seulement si** le contrôleur l'offre
///   (`verbsFor` : état, lecture seule, rôle du message) ;
/// * la sélection d'un verbe appelle `controller.runArtifactVerb` — la
///   confirmation d'un verbe destructeur est posée **par le contrôleur**
///   (seam `confirm`), jamais par la barre : le verbe dérivé n'est donc pas
///   marqué destructeur pour le rendu, afin qu'une seule question soit posée.
ZChatArtifactSpec zChatArtifactSpecOf(
  ZChatArtifactDeclaration declaration, {
  required ZChatNotebookController controller,
  ZChatArtifactResolvers resolvers = ZChatArtifactResolvers.none,
}) {
  final String key = declaration.key;
  ZChatArtifactStatus status(ZChatMessage m) {
    final String? id = m.id;
    return id == null
        ? ZChatArtifactStatus.absent
        : controller.statusOf(id, key).value;
  }

  bool offered(ZChatMessage m, String verbKey) {
    final String? id = m.id;
    if (id == null) return false;
    for (final ZChatArtifactVerb v in controller.verbsFor(id, key)) {
      if (v.key == verbKey) return true;
    }
    return false;
  }

  return ZChatArtifactSpec(
    key: key,
    icon: resolvers.iconOf(declaration.iconKey),
    label: resolvers.labelOf(declaration.labelToken) ?? '',
    accent: resolvers.accentOf(declaration.accentToken),
    presence: (ZChatMessage m) => status(m).isPresent,
    count: declaration.hasCount
        ? (ZChatMessage m) => status(m).badgeCount
        : null,
    busy: (ZChatMessage m) => status(m).isBusy,
    actions: <ZChatArtifactAction>[
      for (final ZChatArtifactVerb verb in declaration.verbs)
        ZChatArtifactAction(
          label: resolvers.labelOf(verb.labelToken) ?? '',
          icon: resolvers.iconOf(verb.iconKey),
          accent: resolvers.accentOf(verb.accentToken),
          visible: (ZChatMessage m, bool _) => offered(m, verb.key),
          onSelected: (ZChatMessage m) {
            final String? id = m.id;
            if (id == null) return;
            controller.runArtifactVerb(
              messageId: id,
              artifactKey: key,
              verbKey: verb.key,
            );
          },
        ),
    ],
  );
}

/// Dérive la forme de rendu de **tous** les artefacts de
/// `controller.registry`, dans l'ordre de présentation du registre.
List<ZChatArtifactSpec> zChatArtifactSpecsOf(
  ZChatNotebookController controller, {
  ZChatArtifactResolvers resolvers = ZChatArtifactResolvers.none,
}) =>
    List<ZChatArtifactSpec>.unmodifiable(<ZChatArtifactSpec>[
      for (final ZChatArtifactDeclaration d in controller.registry.declarations)
        zChatArtifactSpecOf(d, controller: controller, resolvers: resolvers),
    ]);

/// Le créneau d'actions par message, branché sur [controller] : la barre
/// d'artefacts de chaque message est rendue sous un écouteur de **ses**
/// tranches (une par artefact déclaré, plus le mode lecture seule).
///
/// À passer tel quel à `ZChatNotebookView.actionsBuilder` en laissant
/// `artifacts` vide : la vue reste celle d'un hôte passif, et c'est ce
/// créneau qui apporte les artefacts. [host] est le créneau propre de
/// l'hôte, rendu au-dessus de la barre. Les autres paramètres sont relayés à
/// [ZChatArtifactBar.slot].
ZChatMessageSlotBuilder zChatNotebookArtifactsSlot({
  required ZChatNotebookController controller,
  ZChatArtifactResolvers resolvers = ZChatArtifactResolvers.none,
  ZChatMessageSlotBuilder? host,
  ZChatNotebookSkin? skin,
  ZChatArtifactConfirm? confirm,
  double? spacing,
  ZChatArtifactMenuBuilder? menuBuilder,
  int menuCrossAxisCount = kZChatArtifactMenuCrossAxisCount,
}) {
  final List<ZChatArtifactSpec> specs =
      zChatArtifactSpecsOf(controller, resolvers: resolvers);
  final ZChatMessageSlotBuilder bar = ZChatArtifactBar.slot(
    artifacts: specs,
    skin: skin,
    confirm: confirm,
    spacing: spacing,
    menuBuilder: menuBuilder,
    menuCrossAxisCount: menuCrossAxisCount,
  );
  return (BuildContext context, ZChatMessage message) {
    final Widget? own = host?.call(context, message);
    final String? id = message.id;
    if (specs.isEmpty || id == null) return own;
    final Widget slice = ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        for (final ZChatArtifactSpec s in specs) controller.statusOf(id, s.key),
        controller.readOnly,
      ]),
      builder: (BuildContext context, Widget? _) =>
          bar(context, message) ?? const SizedBox.shrink(),
    );
    if (own == null) return slice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[own, slice],
    );
  };
}
