/// Contrat de partage d'un dossier d'étude — liens, adhésions, galerie
/// publique.
///
/// Seam optionnelle du domaine `zcrud_study` : contrat pur
/// (`abstract interface class`, jamais `sealed`, invariant AD-4) que
/// l'application hôte implémente en le branchant sur son propre backend
/// (Firestore, Hive, HTTP…). Aucun SDK, endpoint, clé, jeton, nom de
/// collection ni primitive de chiffrement ne fuit dans ce port (invariant
/// AD-12).
///
/// Toute mutation retourne `Future<ZResult<T>>` (invariant AD-11,
/// `Either<ZFailure, T>`), ou `Future<ZResult<Unit>>` pour un effet sans
/// valeur ; tout flux est un `Stream<List<T>>` nu — jamais un `T` nu, jamais
/// un flux enveloppé dans [ZResult].
///
/// Chaque mutation d'un **champ de contrôle** (`createShareLink`,
/// `revokeShareLink`, `grantMembership`, `publishToGallery`, `unpublish`)
/// doit consommer `ZStudySharingAcl.canMutateControl` : une mutation tentée
/// par un acteur qui n'est pas propriétaire du dossier remonte `Left`
/// (échec d'autorisation domaine), jamais un `Right` silencieux.
/// L'application hôte doit répliquer cette même règle dans ses propres
/// règles de sécurité serveur — ce contrat neutre ne l'impose pas lui-même.
///
/// La collection des liens de partage est **globale** (partagée entre tous
/// les dossiers) ; la résolution de son chemin de stockage est un concern
/// d'adaptateur, hors du domaine — ce port ne code aucun nom de collection.
library;

import 'package:zcrud_core/domain.dart';

import 'z_public_study_folder.dart';
import 'z_share_link.dart';
import 'z_study_membership.dart';

/// Contrat neutre de partage d'un dossier d'étude (invariant AD-5 : domaine
/// backend-agnostique, `Either<ZFailure, T>`).
abstract interface class ZStudySharingPort {
  /// Crée (ou active) un [ZShareLink] pour [folderId]. `Left` si non autorisé
  /// (garde ACL owner-only) ou en cas d'échec ; `Right(ZShareLink)` en succès.
  Future<ZResult<ZShareLink>> createShareLink(String folderId);

  /// **Révoque** un lien (opération de contrôle **monotone**). Retourne
  /// `ZResult<Unit>` (`Either<ZFailure, Unit>`) — **jamais** un [ZShareLink] nu.
  /// `Left(ZFailure)` si l'acteur n'est pas owner (garde ACL) ou en cas d'échec.
  Future<ZResult<Unit>> revokeShareLink(String linkId);

  /// Accorde (ou met à jour) une adhésion. `Left` si l'acteur ne peut pas muter
  /// le `role` (champ de contrôle, garde ACL) ; `Right(ZStudyMembership)` sinon.
  Future<ZResult<ZStudyMembership>> grantMembership(ZStudyMembership membership);

  /// Flux **NU** des adhésions d'un dossier (`Stream<List<T>>`, AD-5) — jamais
  /// enveloppé dans `ZResult`.
  Stream<List<ZStudyMembership>> watchMemberships(String folderId);

  /// Publie [folderId] en galerie publique (champ de contrôle `listed_at`).
  /// `Left` si non autorisé (garde ACL) ; `Right(ZPublicStudyFolder)` en succès.
  Future<ZResult<ZPublicStudyFolder>> publishToGallery(String folderId);

  /// Retire [folderId] de la galerie (champ de contrôle). `Right(Unit)` en
  /// succès ; `Left` si non autorisé (garde ACL) ou en cas d'échec.
  Future<ZResult<Unit>> unpublish(String folderId);
}
