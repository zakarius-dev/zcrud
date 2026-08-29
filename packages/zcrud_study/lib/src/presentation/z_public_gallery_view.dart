/// `ZPublicGalleryView` — liste des dossiers d'étude publiés en galerie.
///
/// Corps composable (aucun `Scaffold`) qui rend un flux NU de
/// `ZPublicStudyFolder` en cartes d'item de ce paquet, avec les gestes
/// « rejoindre », « copier » et « signaler ».
///
/// ## Elle naît fermée
///
/// La disponibilité de la fonctionnalité **et** l'autorisation `ZAcl` sont
/// interrogées par [zSharingAccessGranted] : un refus rend un état « accès
/// refusé » ANNONCÉ, distinct d'une liste vide. L'absence de `ZcrudScope`
/// refuse.
///
/// ## Le flux : de l'application, ou d'un port COMPAGNON
///
/// `ZStudySharingPort` publie et dépublie un dossier mais n'expose aucune
/// lecture de galerie, et aucune méthode ne lui est ajoutée : un implémenteur
/// de ce port v1 n'a rien à changer. La lecture vit dans un port
/// **compagnon** additif, [ZStudySharingReadPort] — le fournir débloque
/// l'alimentation autonome de cette vue.
///
/// Les deux voies coexistent, et la **priorité est au paramètre** :
/// [ZPublicGalleryView.folders] fourni ⇒ c'est ce flux qui est rendu, même si
/// un [ZPublicGalleryView.readPort] l'est aussi. Sans paramètre, le flux du
/// port disponible est consommé (abonné UNE fois). Sans l'un ni l'autre — ou
/// avec un port dont `isAvailable` est `false` — la vue rend son état vide.
///
/// ## Le signalement est optionnel
///
/// L'action « signaler » n'est montée que si un `ZStudyModerationPort` est
/// fourni : sans lui, elle est ABSENTE de l'arbre, jamais grisée ni inerte
/// (invariant AD-4). Un `Left` alimente l'aire d'erreur annoncée et le canal
/// de l'application — jamais une exception.
///
/// ## Liste VIRTUALISÉE
///
/// Le rendu passe par `ListView.builder` : une galerie de mille fiches ne
/// construit que les cellules visibles.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZAcl, ZDataRequest, ZFailure, ZResult, ZcrudTheme;

import '../domain/z_public_study_folder.dart';
import '../domain/z_study_folder_report.dart';
import '../domain/z_study_moderation_port.dart';
import '../domain/z_study_sharing_read_port.dart';
import 'z_feature_availability.dart';
import 'z_folder_sharing_sheet.dart' show ZSharingFailureReporter;
import 'z_study_sharing_gate.dart';
import 'z_study_tools_item_card.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Libellés INJECTÉS de la galerie publique (i18n — aucun libellé en dur,
/// FR-26). Tous requis : un défaut dans une langue serait un libellé en dur
/// sans voie de remplacement.
@immutable
class ZPublicGalleryLabels {
  /// Construit les libellés injectés.
  const ZPublicGalleryLabels({
    required this.accessDenied,
    required this.empty,
    required this.join,
    required this.copy,
    required this.report,
    required this.reported,
  });

  /// État de refus d'accès (ACL ou disponibilité).
  final String accessDenied;

  /// État « aucune fiche publiée ».
  final String empty;

  /// Libellé du geste « rejoindre ».
  final String join;

  /// Libellé du geste « copier ».
  final String copy;

  /// Libellé du geste « signaler ».
  final String report;

  /// Confirmation annoncée après un signalement accepté.
  final String reported;
}

/// Vue de galerie publique, montée sur un flux fourni par l'application.
class ZPublicGalleryView extends StatefulWidget {
  /// Construit la galerie autour du flux [folders].
  const ZPublicGalleryView({
    required this.labels,
    required this.titleFallback,
    this.folders,
    this.readPort,
    this.readRequest,
    this.moderationPort,
    this.reporterUid = '',
    this.reportReason = '',
    this.onJoin,
    this.onCopy,
    this.onFailure,
    this.availability,
    this.acl,
    this.featureKey = zFeatureKeyPublicGallery,
    super.key,
  });

  /// Flux NU des fiches publiées (`Stream<List<T>>`, invariant AD-5), fourni
  /// par l'application. **Prioritaire** sur [readPort] quand les deux sont
  /// présents. `null` ⇒ la vue se rabat sur [readPort].
  final Stream<List<ZPublicStudyFolder>>? folders;

  /// Port compagnon de lecture. Consommé SEULEMENT si [folders] est `null` et
  /// si `isAvailable` vaut `true` ; son flux est abonné UNE fois.
  final ZStudySharingReadPort? readPort;

  /// Requête neutre transmise verbatim à
  /// [ZStudySharingReadPort.watchPublicFolders] (pagination par curseur,
  /// tris, filtres). Sans effet si le flux vient de [folders].
  final ZDataRequest? readRequest;

  /// Libellés injectés.
  final ZPublicGalleryLabels labels;

  /// Libellé INJECTÉ d'une fiche sans titre (le socle n'en fabrique aucun).
  final String titleFallback;

  /// Port de modération. `null` ⇒ geste « signaler » ABSENT de l'arbre.
  final ZStudyModerationPort? moderationPort;

  /// Identifiant OPAQUE de l'auteur du signalement, transmis verbatim.
  final String reporterUid;

  /// Motif transmis verbatim au signalement (le socle n'en compose aucun).
  final String reportReason;

  /// Geste « rejoindre » remis à l'application. `null` ⇒ action ABSENTE.
  final ValueChanged<ZPublicStudyFolder>? onJoin;

  /// Geste « copier » remis à l'application. `null` ⇒ action ABSENTE.
  final ValueChanged<ZPublicStudyFolder>? onCopy;

  /// Canal d'échec de l'application, en plus de l'aire annoncée.
  final ZSharingFailureReporter? onFailure;

  /// Disponibilité explicite. `null` ⇒ lue sur `ZFeatureAvailabilityScope`.
  final ZFeatureAvailability? availability;

  /// ACL explicite. `null` ⇒ lue sur le `ZcrudScope` (absence ⇒ refus).
  final ZAcl? acl;

  /// Clé de fonctionnalité interrogée.
  final String featureKey;

  @override
  State<ZPublicGalleryView> createState() => _ZPublicGalleryViewState();
}

class _ZPublicGalleryViewState extends State<ZPublicGalleryView> {
  late final ValueNotifier<String?> _message;
  late final ValueNotifier<bool> _busy;

  /// Flux du port compagnon, ouvert UNE fois : un rebuild ne réabonne jamais
  /// le port (invariant AD-2). `null` si le paramètre prime, si aucun port
  /// n'est fourni, ou si le port se déclare indisponible.
  Stream<List<ZPublicStudyFolder>>? _portFolders;

  @override
  void initState() {
    super.initState();
    _message = ValueNotifier<String?>(null);
    _busy = ValueNotifier<bool>(false);
    final ZStudySharingReadPort? port = widget.readPort;
    if (widget.folders == null && port != null && port.isAvailable) {
      _portFolders = port.watchPublicFolders(request: widget.readRequest);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _report(ZPublicStudyFolder folder) async {
    final ZStudyModerationPort? port = widget.moderationPort;
    if (port == null || _busy.value) return;
    _busy.value = true;
    final ZResult<void> result = await port.report(
      ZStudyFolderReport(
        folderId: folder.folderId,
        reporterUid: widget.reporterUid,
        reason: widget.reportReason,
      ),
    );
    if (!mounted) return;
    result.fold((ZFailure failure) {
      _message.value = failure.message;
      widget.onFailure?.call(failure);
    }, (_) {
      _message.value = widget.labels.reported;
    });
    _busy.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool granted = zSharingAccessGranted(
      context,
      action: ZStudySharingActions.browseGallery,
      featureKey: widget.featureKey,
      availability: widget.availability,
      acl: widget.acl,
    );
    if (!granted) {
      return Semantics(
        liveRegion: true,
        child: Text(
          widget.labels.accessDenied,
          key: const ValueKey<String>('z-public-gallery-denied'),
          textAlign: TextAlign.start,
        ),
      );
    }
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Column(
      key: const ValueKey<String>('z-public-gallery-body'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(
          child: StreamBuilder<List<ZPublicStudyFolder>>(
            key: const ValueKey<String>('z-public-gallery-stream'),
            // Le PARAMÈTRE prime : la voie historique reste inchangée, le
            // port compagnon ne sert que de repli.
            stream: widget.folders ?? _portFolders,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<ZPublicStudyFolder>> snapshot,
            ) {
              final List<ZPublicStudyFolder> folders =
                  snapshot.data ?? const <ZPublicStudyFolder>[];
              if (folders.isEmpty) {
                return Text(
                  widget.labels.empty,
                  key: const ValueKey<String>('z-public-gallery-empty'),
                  textAlign: TextAlign.start,
                );
              }
              // Liste VIRTUALISÉE : jamais un `ListView(children: …)`.
              return ListView.builder(
                key: const ValueKey<String>('z-public-gallery-list'),
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (BuildContext context, int index) =>
                    _buildCard(theme, folders[index], index),
              );
            },
          ),
        ),
        _buildMessageArea(theme),
      ],
    );
  }

  /// Fiche rendue par la carte d'item du paquet — aucune apparence
  /// réécrite, aucune couleur littérale (FR-26).
  Widget _buildCard(ZcrudTheme theme, ZPublicStudyFolder folder, int index) {
    final String title =
        folder.title.isEmpty ? widget.titleFallback : folder.title;
    return ZStudyToolsItemCard(
      key: ValueKey<String>(
        'z-public-gallery-card-${folder.id ?? folder.folderId}',
      ),
      title: title,
      subtitle: folder.ownerUid.isEmpty ? null : folder.ownerUid,
      trailing: Wrap(
        spacing: theme.gapS,
        children: <Widget>[
          if (widget.onJoin != null)
            _action(
              keyValue: 'z-public-gallery-join-$index',
              label: widget.labels.join,
              onPressed: () => widget.onJoin!(folder),
            ),
          if (widget.onCopy != null)
            _action(
              keyValue: 'z-public-gallery-copy-$index',
              label: widget.labels.copy,
              onPressed: () => widget.onCopy!(folder),
            ),
          if (widget.moderationPort != null)
            ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (BuildContext context, bool busy, _) => _action(
                keyValue: 'z-public-gallery-report-$index',
                label: widget.labels.report,
                onPressed: busy ? null : () => _report(folder),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageArea(ZcrudTheme theme) => ValueListenableBuilder<String?>(
        valueListenable: _message,
        builder: (BuildContext context, String? message, _) => message == null
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsetsDirectional.only(top: theme.gapM),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey<String>('z-public-gallery-message'),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
      );

  Widget _action({
    required String keyValue,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: TextButton(
          key: ValueKey<String>(keyValue),
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
}
