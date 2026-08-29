/// Contrat d'**administration** du partage d'un dossier d'étude — révocation
/// d'adhésion et drapeaux de partage.
///
/// Port **compagnon** de `ZStudySharingPort` : additif et indépendant. Un
/// implémenteur du port de partage n'a rien à changer pour continuer à
/// fonctionner — ce contrat vit à côté, jamais à l'intérieur. Fournir ce
/// compagnon débloque les surfaces d'administration correspondantes (l'action
/// de révocation d'une adhésion, les interrupteurs de partage) ; ne pas le
/// fournir laisse ces surfaces exactement dans leur état antérieur.
///
/// Seam optionnelle du domaine : contrat pur (`abstract interface class`,
/// jamais `sealed`, invariant AD-4). Aucun SDK, endpoint, clé, jeton, nom de
/// collection ni primitive de chiffrement n'y fuit (invariant AD-12).
///
/// Toutes les opérations portent sur des **champs de contrôle** : elles
/// doivent consommer `ZStudySharingAcl.canMutateControl` — une mutation
/// tentée par un acteur qui n'est pas propriétaire du dossier remonte `Left`
/// (échec d'autorisation domaine), jamais un `Right` silencieux.
/// L'application hôte doit répliquer cette même règle dans ses propres règles
/// de sécurité serveur — ce contrat neutre ne l'impose pas lui-même.
///
/// Chaque opération retourne `Future<ZResult<Unit>>` (invariant AD-11) : un
/// effet sans valeur, jamais une entité nue.
library;

import 'package:zcrud_core/domain.dart';

/// Contrat neutre d'administration du partage (invariant AD-5 : domaine
/// backend-agnostique, `Either<ZFailure, T>`).
abstract interface class ZStudySharingAdminPort {
  /// Révoque l'adhésion d'identité opaque [membershipId]
  /// (`ZStudyMembership.id`).
  ///
  /// L'identité d'une adhésion pas encore persistée est `null` : un appelant
  /// n'a alors rien à révoquer. `Right(Unit)` en succès ; `Left(ZFailure)` si
  /// l'acteur n'est pas habilité (garde ACL) ou en cas d'échec.
  Future<ZResult<Unit>> revokeMembership(String membershipId);

  /// Pose le drapeau « rejoignable par lien » de [folderId] à [value]
  /// (champ de contrôle `can_be_joined_with_link` de l'entité de dossier).
  ///
  /// `Right(Unit)` en succès ; `Left` si non autorisé ou en cas d'échec.
  Future<ZResult<Unit>> setJoinableByLink(String folderId, bool value);

  /// Pose le drapeau « les membres peuvent inviter » de [folderId] à [value]
  /// (champ de contrôle `co_workers_can_invite_others` de l'entité de
  /// dossier).
  ///
  /// `Right(Unit)` en succès ; `Left` si non autorisé ou en cas d'échec.
  Future<ZResult<Unit>> setMembersCanInvite(String folderId, bool value);

  /// `true` si l'administration du partage est utilisable **maintenant**.
  ///
  /// Permet à un hôte de brancher une seule implémentation et d'en couper
  /// l'administration à chaud (réglage, rôle courant, indisponibilité du
  /// backend) sans retirer le port de l'arbre. Un consommateur qui le voit à
  /// `false` se comporte comme si aucun port n'était fourni.
  bool get isAvailable;
}

/// Port d'administration **inerte** : disponible nulle part, n'écrit rien.
///
/// Valeur par défaut pour un hôte qui veut câbler la fente sans encore avoir
/// de voie d'écriture, et sujet neutre aux tests. `isAvailable` valant
/// `false`, un consommateur correct ne l'appelle jamais ; s'il l'appelle
/// quand même, il reçoit un `Right(Unit)` sans effet — jamais une exception.
class ZInertStudySharingAdminPort implements ZStudySharingAdminPort {
  /// Construit le port inerte (`const` : une seule instance suffit).
  const ZInertStudySharingAdminPort();

  @override
  bool get isAvailable => false;

  @override
  Future<ZResult<Unit>> revokeMembership(String membershipId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> setJoinableByLink(String folderId, bool value) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> setMembersCanInvite(
    String folderId,
    bool value,
  ) async =>
      const Right<ZFailure, Unit>(unit);
}
