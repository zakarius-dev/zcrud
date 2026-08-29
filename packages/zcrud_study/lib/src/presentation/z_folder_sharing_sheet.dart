/// `ZFolderSharingSheet` — feuille de partage d'un dossier d'étude.
///
/// Assemble, sur le port `ZStudySharingPort` déjà porté par le domaine, les
/// quatre gestes de partage d'un dossier : le **lien** révocable, les
/// **adhésions**, les **interrupteurs** de partage portés par le dossier, et
/// la **publication** en galerie publique.
///
/// ## Elle naît fermée
///
/// Sans port, la feuille n'est pas montable : c'est l'appelant qui décide de
/// la construire. Montée, elle interroge encore le portail
/// [zSharingAccessGranted] : fonctionnalité indisponible **ou** ACL refusant
/// ⇒ un état « accès refusé » ANNONCÉ (`liveRegion`), jamais une feuille
/// vide ni un masquage silencieux. L'absence de `ZcrudScope` refuse.
///
/// ## Le socle n'interprète aucun identifiant
///
/// La saisie d'invitation (identifiant interne, adresse électronique,
/// pseudonyme…) n'est **jamais** analysée ici : elle est remise telle quelle
/// à [ZFolderSharingSheet.principalResolver], que l'application fournit.
/// L'adhésion accordée porte **exactement** la valeur rendue par ce
/// résolveur ; un `null` ⇒ aucune écriture, un motif annoncé. Sans
/// résolveur, la surface d'invitation est ABSENTE de l'arbre.
///
/// ## Rien n'est levé, rien n'est écrit en double
///
/// Chaque geste consomme un `Either<ZFailure, T>` (invariant AD-11) : un
/// `Left` alimente l'aire d'erreur annoncée et le canal
/// [ZFolderSharingSheet.onFailure], et laisse l'état INTACT — jamais une
/// exception. Chaque geste porte son propre verrou d'occupation : une
/// seconde pression pendant l'appel n'émet pas un second appel.
///
/// ## Réactivité granulaire (invariant AD-2)
///
/// L'état est éclaté en `ValueNotifier` par tranche (lien, publication,
/// erreur, occupations) et les adhésions vivent dans un `StreamBuilder`
/// isolé, abonné UNE fois : un événement du flux d'adhésions ne reconstruit
/// ni l'aire du lien, ni la saisie d'invitation, ni la section galerie.
///
/// ## Deux voies pour l'administration : callback ou port COMPAGNON
///
/// `ZStudySharingPort` ne porte ni la révocation d'une adhésion, ni la
/// mutation des drapeaux du dossier (« rejoignable par lien », « les membres
/// peuvent inviter ») — et aucune méthode ne lui est ajoutée : un
/// implémenteur de ce port v1 n'a rien à changer. Ces trois capacités vivent
/// dans un port **compagnon** additif, [ZStudySharingAdminPort] ; le fournir
/// débloque les surfaces correspondantes.
///
/// Chaque capacité est donc gréée par le **callback** historique **OU** par
/// le port compagnon, et le **callback prime** quand les deux sont présents :
///
/// - révocation d'adhésion : [ZFolderSharingSheet.onRevokeMembership], sinon
///   [ZStudySharingAdminPort.revokeMembership] ;
/// - « rejoignable par lien » : [ZFolderSharingSheet.onSetJoinableWithLink],
///   sinon [ZStudySharingAdminPort.setJoinableByLink] ;
/// - « les membres peuvent inviter » :
///   [ZFolderSharingSheet.onSetMembersCanInvite], sinon
///   [ZStudySharingAdminPort.setMembersCanInvite].
///
/// Sans l'une ni l'autre voie — ou avec un port compagnon dont `isAvailable`
/// est `false` — la surface reste ABSENTE de l'arbre, jamais grisée ni
/// inerte (invariant AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZAcl, ZFailure, ZResult, ZcrudTheme;

import '../domain/z_public_study_folder.dart';
import '../domain/z_share_link.dart';
import '../domain/z_study_membership.dart';
import '../domain/z_study_sharing_admin_port.dart';
import '../domain/z_study_sharing_port.dart';
import 'z_feature_availability.dart';
import 'z_study_sharing_gate.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Résout une saisie libre en identifiant d'acteur OPAQUE.
///
/// Le socle ne lit, ne valide et ne normalise jamais la saisie : il la
/// transmet verbatim. Retourner `null` (adresse inconnue, compte absent,
/// saisie invalide) ⇒ aucune adhésion n'est accordée.
typedef ZPrincipalResolver = Future<String?> Function(String input);

/// Libellé INJECTÉ d'un rôle d'adhésion (i18n — le socle ne nomme aucun rôle).
typedef ZMembershipRoleLabel = String Function(ZMembershipRole role);

/// Mutateur faillible d'un drapeau de partage porté par le dossier.
typedef ZSharingFlagUpdater = Future<ZResult<void>> Function(bool value);

/// Révocation faillible d'une adhésion, remise à l'application.
typedef ZMembershipRevoker = Future<ZResult<void>> Function(
  ZStudyMembership membership,
);

/// Canal d'échec de l'application (toaster, journal…).
typedef ZSharingFailureReporter = void Function(ZFailure failure);

/// Libellés INJECTÉS de la feuille de partage (i18n — aucun libellé en dur,
/// FR-26). Tous requis : un défaut dans une langue serait un libellé en dur
/// sans voie de remplacement.
@immutable
class ZFolderSharingLabels {
  /// Construit les libellés injectés.
  const ZFolderSharingLabels({
    required this.accessDenied,
    required this.linkSectionTitle,
    required this.noLink,
    required this.createLink,
    required this.revokeLink,
    required this.copyLink,
    required this.linkCopied,
    required this.linkRevoked,
    required this.membersSectionTitle,
    required this.noMembers,
    required this.principalFieldLabel,
    required this.principalFieldHint,
    required this.grantMembership,
    required this.principalUnresolved,
    required this.revokeMembership,
    required this.gallerySectionTitle,
    required this.notPublished,
    required this.published,
    required this.publishToGallery,
    required this.unpublish,
    required this.joinableWithLink,
    required this.membersCanInvite,
  });

  /// État de refus d'accès (ACL ou disponibilité).
  final String accessDenied;

  /// Titre de la section « lien de partage ».
  final String linkSectionTitle;

  /// État « aucun lien actif ».
  final String noLink;

  /// Libellé de création du lien.
  final String createLink;

  /// Libellé de révocation du lien.
  final String revokeLink;

  /// Libellé de copie du lien.
  final String copyLink;

  /// État « lien copié ».
  final String linkCopied;

  /// État « lien révoqué ».
  final String linkRevoked;

  /// Titre de la section « adhésions ».
  final String membersSectionTitle;

  /// État « aucune adhésion ».
  final String noMembers;

  /// Libellé du champ d'invitation.
  final String principalFieldLabel;

  /// Indice du champ d'invitation.
  final String principalFieldHint;

  /// Libellé du bouton d'octroi d'adhésion.
  final String grantMembership;

  /// Motif annoncé quand le résolveur ne rend aucun identifiant.
  final String principalUnresolved;

  /// Libellé de révocation d'une adhésion.
  final String revokeMembership;

  /// Titre de la section « galerie publique ».
  final String gallerySectionTitle;

  /// État « non publié ».
  final String notPublished;

  /// État « publié ».
  final String published;

  /// Libellé de publication.
  final String publishToGallery;

  /// Libellé de dépublication.
  final String unpublish;

  /// Libellé de l'interrupteur « rejoignable par lien ».
  final String joinableWithLink;

  /// Libellé de l'interrupteur « les membres peuvent inviter ».
  final String membersCanInvite;
}

/// Feuille de partage d'un dossier, montée sur un [ZStudySharingPort].
class ZFolderSharingSheet extends StatefulWidget {
  /// Construit la feuille autour du [port] et du dossier [folderId].
  const ZFolderSharingSheet({
    required this.port,
    required this.folderId,
    required this.labels,
    required this.roleLabel,
    this.adminPort,
    this.principalResolver,
    this.onRevokeMembership,
    this.initialLink,
    this.initialPublicFolder,
    this.roles = const <ZMembershipRole>[
      ZMembershipRole.contributor,
      ZMembershipRole.viewer,
    ],
    this.onCopyLink,
    this.onSetJoinableWithLink,
    this.onSetMembersCanInvite,
    this.joinableWithLink = false,
    this.membersCanInvite = false,
    this.onFailure,
    this.availability,
    this.acl,
    this.featureKey = zFeatureKeyFolderSharing,
    super.key,
  });

  /// Port de partage injecté par l'application hôte.
  final ZStudySharingPort port;

  /// Dossier gouverné par cette feuille (clé neutre `String`).
  final String folderId;

  /// Libellés injectés.
  final ZFolderSharingLabels labels;

  /// Fabrique INJECTÉE des libellés de rôle : le socle ne traduit aucun rôle.
  final ZMembershipRoleLabel roleLabel;

  /// Résolveur de la saisie d'invitation. `null` ⇒ surface d'invitation
  /// ABSENTE de l'arbre (invariant AD-4 : capacité absente, jamais inerte).
  final ZPrincipalResolver? principalResolver;

  /// Port compagnon d'administration. Consommé pour toute capacité dont le
  /// callback historique n'est pas fourni, et seulement si `isAvailable` vaut
  /// `true`. `null` ⇒ seules les capacités gréées par callback existent.
  final ZStudySharingAdminPort? adminPort;

  /// Révocation d'une adhésion. **Prioritaire** sur
  /// [ZStudySharingAdminPort.revokeMembership]. `null` ⇒ la voie du port
  /// compagnon prend le relais ; sans elle non plus, action ABSENTE.
  final ZMembershipRevoker? onRevokeMembership;

  /// Lien déjà connu de l'application, ou `null`.
  final ZShareLink? initialLink;

  /// Fiche de galerie déjà connue, ou `null` (non publié).
  final ZPublicStudyFolder? initialPublicFolder;

  /// Rôles proposés à l'octroi (ordre préservé).
  final List<ZMembershipRole> roles;

  /// Remise du jeton de lien à l'application (presse-papiers, partage
  /// système…). `null` ⇒ action de copie ABSENTE : ce paquet ne dépend
  /// d'aucun service de plateforme.
  final ValueChanged<ZShareLink>? onCopyLink;

  /// Mutateur du drapeau « rejoignable par lien ». **Prioritaire** sur
  /// [ZStudySharingAdminPort.setJoinableByLink]. `null` ⇒ la voie du port
  /// compagnon prend le relais ; sans elle non plus, interrupteur ABSENT.
  final ZSharingFlagUpdater? onSetJoinableWithLink;

  /// Mutateur du drapeau « les membres peuvent inviter ». **Prioritaire** sur
  /// [ZStudySharingAdminPort.setMembersCanInvite]. `null` ⇒ la voie du port
  /// compagnon prend le relais ; sans elle non plus, interrupteur ABSENT.
  final ZSharingFlagUpdater? onSetMembersCanInvite;

  /// Valeur initiale du drapeau « rejoignable par lien ».
  final bool joinableWithLink;

  /// Valeur initiale du drapeau « les membres peuvent inviter ».
  final bool membersCanInvite;

  /// Canal d'échec de l'application, en plus de l'aire annoncée.
  final ZSharingFailureReporter? onFailure;

  /// Disponibilité explicite. `null` ⇒ lue sur `ZFeatureAvailabilityScope`.
  final ZFeatureAvailability? availability;

  /// ACL explicite. `null` ⇒ lue sur le `ZcrudScope` (absence ⇒ refus).
  final ZAcl? acl;

  /// Clé de fonctionnalité interrogée.
  final String featureKey;

  @override
  State<ZFolderSharingSheet> createState() => _ZFolderSharingSheetState();
}

class _ZFolderSharingSheetState extends State<ZFolderSharingSheet> {
  // Controller STABLE (créé UNE fois, jamais dans build() — AD-2).
  late final TextEditingController _principalController;

  // Flux abonné UNE fois : un rebuild ne réabonne jamais le port.
  late final Stream<List<ZStudyMembership>> _memberships;

  late final ValueNotifier<ZShareLink?> _link;
  late final ValueNotifier<ZPublicStudyFolder?> _public;
  late final ValueNotifier<String?> _error;
  late final ValueNotifier<bool> _copied;
  late final ValueNotifier<bool> _linkBusy;
  late final ValueNotifier<bool> _memberBusy;
  late final ValueNotifier<bool> _galleryBusy;
  late final ValueNotifier<ZMembershipRole> _role;
  late final ValueNotifier<bool> _joinable;
  late final ValueNotifier<bool> _canInvite;

  @override
  void initState() {
    super.initState();
    _principalController = TextEditingController();
    _memberships = widget.port.watchMemberships(widget.folderId);
    _link = ValueNotifier<ZShareLink?>(widget.initialLink);
    _public = ValueNotifier<ZPublicStudyFolder?>(widget.initialPublicFolder);
    _error = ValueNotifier<String?>(null);
    _copied = ValueNotifier<bool>(false);
    _linkBusy = ValueNotifier<bool>(false);
    _memberBusy = ValueNotifier<bool>(false);
    _galleryBusy = ValueNotifier<bool>(false);
    _role = ValueNotifier<ZMembershipRole>(
      widget.roles.isEmpty ? ZMembershipRole.viewer : widget.roles.first,
    );
    _joinable = ValueNotifier<bool>(widget.joinableWithLink);
    _canInvite = ValueNotifier<bool>(widget.membersCanInvite);
  }

  @override
  void dispose() {
    _principalController.dispose();
    _link.dispose();
    _public.dispose();
    _error.dispose();
    _copied.dispose();
    _linkBusy.dispose();
    _memberBusy.dispose();
    _galleryBusy.dispose();
    _role.dispose();
    _joinable.dispose();
    _canInvite.dispose();
    super.dispose();
  }

  // Verrou d'occupation PAR interrupteur : une seconde bascule pendant
  // l'appel en vol n'émet pas un second appel.
  final Set<ValueNotifier<bool>> _flagsInFlight = <ValueNotifier<bool>>{};

  /// Port compagnon effectivement utilisable, ou `null` (absent, ou coupé à
  /// chaud par `isAvailable`).
  ZStudySharingAdminPort? get _admin {
    final ZStudySharingAdminPort? port = widget.adminPort;
    return port != null && port.isAvailable ? port : null;
  }

  /// Voie de révocation retenue. Le callback historique PRIME ; le port
  /// compagnon ne sert que de relais.
  ZMembershipRevoker? get _revoker {
    final ZMembershipRevoker? callback = widget.onRevokeMembership;
    if (callback != null) return callback;
    final ZStudySharingAdminPort? port = _admin;
    if (port == null) return null;
    // L'identité d'une adhésion non persistée est `null` : le port reçoit
    // alors la chaîne vide, comme la révocation de lien le fait déjà.
    return (ZStudyMembership membership) =>
        port.revokeMembership(membership.id ?? '');
  }

  /// Mutateur retenu pour « rejoignable par lien ». Le callback PRIME.
  ZSharingFlagUpdater? get _joinableUpdater {
    final ZSharingFlagUpdater? callback = widget.onSetJoinableWithLink;
    if (callback != null) return callback;
    final ZStudySharingAdminPort? port = _admin;
    if (port == null) return null;
    return (bool value) => port.setJoinableByLink(widget.folderId, value);
  }

  /// Mutateur retenu pour « les membres peuvent inviter ». Le callback PRIME.
  ZSharingFlagUpdater? get _canInviteUpdater {
    final ZSharingFlagUpdater? callback = widget.onSetMembersCanInvite;
    if (callback != null) return callback;
    final ZStudySharingAdminPort? port = _admin;
    if (port == null) return null;
    return (bool value) => port.setMembersCanInvite(widget.folderId, value);
  }

  /// Un `Left` alimente l'aire annoncée ET le canal de l'application, sans
  /// jamais lever ni altérer l'état courant.
  void _fail(ZFailure failure) {
    _error.value = failure.message;
    widget.onFailure?.call(failure);
  }

  Future<void> _createLink() async {
    if (_linkBusy.value) return;
    _linkBusy.value = true;
    final ZResult<ZShareLink> result =
        await widget.port.createShareLink(widget.folderId);
    if (!mounted) return;
    result.fold(_fail, (ZShareLink link) {
      _error.value = null;
      _copied.value = false;
      _link.value = link;
    });
    _linkBusy.value = false;
  }

  Future<void> _revokeLink() async {
    final ZShareLink? current = _link.value;
    if (current == null || _linkBusy.value) return;
    _linkBusy.value = true;
    final ZResult<void> result =
        await widget.port.revokeShareLink(current.id ?? '');
    if (!mounted) return;
    result.fold(_fail, (_) {
      _error.value = null;
      _copied.value = false;
      // Révocation MONOTONE : l'entité porte l'état, elle n'est pas effacée.
      _link.value = current.revoke();
    });
    _linkBusy.value = false;
  }

  Future<void> _grant() async {
    final ZPrincipalResolver? resolver = widget.principalResolver;
    if (resolver == null || _memberBusy.value) return;
    _memberBusy.value = true;
    final String? principal = await resolver(_principalController.text);
    if (!mounted) return;
    if (principal == null) {
      _error.value = widget.labels.principalUnresolved;
      _memberBusy.value = false;
      return;
    }
    final ZResult<ZStudyMembership> result = await widget.port.grantMembership(
      ZStudyMembership(
        folderId: widget.folderId,
        // Verbatim : la valeur RENDUE par le résolveur, jamais la saisie.
        actorUid: principal,
        role: _role.value,
      ),
    );
    if (!mounted) return;
    result.fold(_fail, (_) {
      _error.value = null;
      _principalController.clear();
    });
    _memberBusy.value = false;
  }

  Future<void> _revokeMembership(ZStudyMembership membership) async {
    final ZMembershipRevoker? revoker = _revoker;
    if (revoker == null || _memberBusy.value) return;
    _memberBusy.value = true;
    final ZResult<void> result = await revoker(membership);
    if (!mounted) return;
    result.fold(_fail, (_) {
      _error.value = null;
    });
    _memberBusy.value = false;
  }

  Future<void> _publish() async {
    if (_galleryBusy.value) return;
    _galleryBusy.value = true;
    final ZResult<ZPublicStudyFolder> result =
        await widget.port.publishToGallery(widget.folderId);
    if (!mounted) return;
    result.fold(_fail, (ZPublicStudyFolder folder) {
      _error.value = null;
      _public.value = folder;
    });
    _galleryBusy.value = false;
  }

  Future<void> _unpublish() async {
    if (_galleryBusy.value) return;
    _galleryBusy.value = true;
    final ZResult<void> result = await widget.port.unpublish(widget.folderId);
    if (!mounted) return;
    result.fold(_fail, (_) {
      _error.value = null;
      _public.value = null;
    });
    _galleryBusy.value = false;
  }

  Future<void> _setFlag(
    ZSharingFlagUpdater updater,
    ValueNotifier<bool> slot,
    bool value,
  ) async {
    if (_flagsInFlight.contains(slot)) return;
    _flagsInFlight.add(slot);
    final bool previous = slot.value;
    slot.value = value;
    final ZResult<void> result = await updater(value);
    if (!mounted) {
      _flagsInFlight.remove(slot);
      return;
    }
    // Un échec REND l'état antérieur : jamais un interrupteur qui ment.
    result.fold((ZFailure failure) {
      slot.value = previous;
      _fail(failure);
    }, (_) {
      _error.value = null;
    });
    _flagsInFlight.remove(slot);
  }

  @override
  Widget build(BuildContext context) {
    final bool granted = zSharingAccessGranted(
      context,
      action: ZStudySharingActions.manageSharing,
      featureKey: widget.featureKey,
      collectionId: widget.folderId,
      availability: widget.availability,
      acl: widget.acl,
    );
    if (!granted) {
      return Semantics(
        liveRegion: true,
        child: Text(
          widget.labels.accessDenied,
          key: const ValueKey<String>('z-folder-sharing-denied'),
          textAlign: TextAlign.start,
        ),
      );
    }
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return SingleChildScrollView(
      key: const ValueKey<String>('z-folder-sharing-body'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildLinkSection(theme),
          SizedBox(height: theme.gapL),
          _buildFlagsSection(),
          _buildMembersSection(theme),
          SizedBox(height: theme.gapL),
          _buildGallerySection(theme),
          _buildErrorArea(theme),
        ],
      ),
    );
  }

  Widget _buildLinkSection(ZcrudTheme theme) => Column(
        key: const ValueKey<String>('z-folder-sharing-link-section'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.labels.linkSectionTitle, textAlign: TextAlign.start),
          SizedBox(height: theme.gapS),
          ValueListenableBuilder<ZShareLink?>(
            valueListenable: _link,
            builder: (BuildContext context, ZShareLink? link, _) =>
                ValueListenableBuilder<bool>(
              valueListenable: _linkBusy,
              builder: (BuildContext context, bool busy, _) {
                final bool active = link != null && !link.revoked;
                return Wrap(
                  spacing: theme.gapM,
                  runSpacing: theme.gapS,
                  children: <Widget>[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        link == null
                            ? widget.labels.noLink
                            : (link.revoked
                                ? widget.labels.linkRevoked
                                : link.token),
                        key: const ValueKey<String>('z-folder-sharing-link'),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    if (!active)
                      _button(
                        keyValue: 'z-folder-sharing-create-link',
                        label: widget.labels.createLink,
                        onPressed: busy ? null : _createLink,
                      ),
                    if (active) ...<Widget>[
                      _button(
                        keyValue: 'z-folder-sharing-revoke-link',
                        label: widget.labels.revokeLink,
                        onPressed: busy ? null : _revokeLink,
                      ),
                      if (widget.onCopyLink != null)
                        _button(
                          keyValue: 'z-folder-sharing-copy-link',
                          label: widget.labels.copyLink,
                          onPressed: () {
                            widget.onCopyLink!(link);
                            _copied.value = true;
                          },
                        ),
                    ],
                    ValueListenableBuilder<bool>(
                      valueListenable: _copied,
                      builder: (BuildContext context, bool copied, _) =>
                          copied && active
                              ? Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    widget.labels.linkCopied,
                                    key: const ValueKey<String>(
                                      'z-folder-sharing-link-copied',
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

  /// Interrupteurs de partage : rendus SEULEMENT si une voie de mutation
  /// existe — le mutateur de l'application, sinon le port compagnon.
  Widget _buildFlagsSection() {
    final ZSharingFlagUpdater? joinable = _joinableUpdater;
    final ZSharingFlagUpdater? invite = _canInviteUpdater;
    if (joinable == null && invite == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (joinable != null)
          _switch(
            keyValue: 'z-folder-sharing-joinable',
            label: widget.labels.joinableWithLink,
            slot: _joinable,
            updater: joinable,
          ),
        if (invite != null)
          _switch(
            keyValue: 'z-folder-sharing-can-invite',
            label: widget.labels.membersCanInvite,
            slot: _canInvite,
            updater: invite,
          ),
      ],
    );
  }

  Widget _switch({
    required String keyValue,
    required String label,
    required ValueNotifier<bool> slot,
    required ZSharingFlagUpdater updater,
  }) =>
      ValueListenableBuilder<bool>(
        valueListenable: slot,
        builder: (BuildContext context, bool value, _) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kMinTapTarget),
          child: SwitchListTile(
            key: ValueKey<String>(keyValue),
            value: value,
            title: Text(label, textAlign: TextAlign.start),
            onChanged: (bool next) => _setFlag(updater, slot, next),
          ),
        ),
      );

  /// Adhésions : flux NU rendu dans un `StreamBuilder` ISOLÉ (un événement ne
  /// reconstruit que cette section) et liste VIRTUALISÉE.
  Widget _buildMembersSection(ZcrudTheme theme) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.labels.membersSectionTitle, textAlign: TextAlign.start),
          SizedBox(height: theme.gapS),
          StreamBuilder<List<ZStudyMembership>>(
            key: const ValueKey<String>('z-folder-sharing-members'),
            stream: _memberships,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<ZStudyMembership>> snapshot,
            ) {
              final List<ZStudyMembership> members =
                  snapshot.data ?? const <ZStudyMembership>[];
              if (members.isEmpty) {
                return Text(
                  widget.labels.noMembers,
                  key: const ValueKey<String>('z-folder-sharing-no-members'),
                  textAlign: TextAlign.start,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (BuildContext context, int index) {
                  final ZStudyMembership member = members[index];
                  return ListTile(
                    key: ValueKey<String>(
                      'z-folder-sharing-member-${member.id ?? member.actorUid}',
                    ),
                    title: Text(member.actorUid, textAlign: TextAlign.start),
                    subtitle: Text(
                      widget.roleLabel(member.role),
                      textAlign: TextAlign.start,
                    ),
                    trailing: _revoker == null
                        ? null
                        : _button(
                            keyValue: 'z-folder-sharing-revoke-member-$index',
                            label: widget.labels.revokeMembership,
                            onPressed: () => _revokeMembership(member),
                          ),
                  );
                },
              );
            },
          ),
          if (widget.principalResolver != null) _buildGrantArea(theme),
        ],
      );

  Widget _buildGrantArea(ZcrudTheme theme) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: theme.gapM),
          // Controller STABLE, hors des tranches réactives : taper ne
          // reconstruit rien d'autre que le champ lui-même (AD-2).
          TextField(
            key: const ValueKey<String>('z-folder-sharing-principal'),
            controller: _principalController,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: widget.labels.principalFieldLabel,
              hintText: widget.labels.principalFieldHint,
            ),
          ),
          SizedBox(height: theme.gapS),
          if (widget.roles.isNotEmpty)
            ValueListenableBuilder<ZMembershipRole>(
              valueListenable: _role,
              builder: (BuildContext context, ZMembershipRole role, _) => Wrap(
                spacing: theme.gapS,
                children: <Widget>[
                  for (final ZMembershipRole option in widget.roles)
                    ChoiceChip(
                      key: ValueKey<String>(
                        'z-folder-sharing-role-${option.name}',
                      ),
                      selected: option == role,
                      onSelected: (_) => _role.value = option,
                      label: Text(
                        widget.roleLabel(option),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(height: theme.gapS),
          ValueListenableBuilder<bool>(
            valueListenable: _memberBusy,
            builder: (BuildContext context, bool busy, _) => _button(
              keyValue: 'z-folder-sharing-grant',
              label: widget.labels.grantMembership,
              onPressed: busy ? null : _grant,
            ),
          ),
        ],
      );

  Widget _buildGallerySection(ZcrudTheme theme) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.labels.gallerySectionTitle, textAlign: TextAlign.start),
          SizedBox(height: theme.gapS),
          ValueListenableBuilder<ZPublicStudyFolder?>(
            valueListenable: _public,
            builder: (BuildContext context, ZPublicStudyFolder? folder, _) =>
                ValueListenableBuilder<bool>(
              valueListenable: _galleryBusy,
              builder: (BuildContext context, bool busy, _) => Wrap(
                spacing: theme.gapM,
                runSpacing: theme.gapS,
                children: <Widget>[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      folder == null
                          ? widget.labels.notPublished
                          : widget.labels.published,
                      key: const ValueKey<String>(
                        'z-folder-sharing-gallery-state',
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (folder == null)
                    _button(
                      keyValue: 'z-folder-sharing-publish',
                      label: widget.labels.publishToGallery,
                      onPressed: busy ? null : _publish,
                    )
                  else
                    _button(
                      keyValue: 'z-folder-sharing-unpublish',
                      label: widget.labels.unpublish,
                      onPressed: busy ? null : _unpublish,
                    ),
                ],
              ),
            ),
          ),
        ],
      );

  /// Aire d'erreur NON bloquante : annoncée (`liveRegion`), l'état reste
  /// intact.
  Widget _buildErrorArea(ZcrudTheme theme) => ValueListenableBuilder<String?>(
        valueListenable: _error,
        builder: (BuildContext context, String? message, _) => message == null
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsetsDirectional.only(top: theme.gapM),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey<String>('z-folder-sharing-error'),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
      );

  Widget _button({
    required String keyValue,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: ElevatedButton(
          key: ValueKey<String>(keyValue),
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
}
