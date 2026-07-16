/// Port neutre de **partage** `ZStudySharingPort` (Story ES-9.4, AC1/AC4/AC7).
///
/// origine: seam de partage OPTIONNEL du domaine `zcrud_study` (AD-5/AD-11/AD-26).
/// Contrat **pur** (`abstract interface class`, **jamais** `sealed` — AD-4 :
/// frontière inter-package, l'app *implements* librement). L'app hôte le branche
/// sur son backend (Firestore/Hive/HTTP…) : **aucun** SDK, endpoint, clé, token,
/// nom de collection en dur ni crypto ne fuit ici (AD-11/AD-12).
///
/// ## Surface AD-5 (pincée par liaison de type statique)
///
/// Toute mutation retourne `Future<ZResult<T>>` (= `Either<ZFailure, T>`), ou
/// `Future<ZResult<Unit>>` pour un void ; tout flux est un `Stream<List<T>>`
/// **NU** — **jamais** un `T` nu, **jamais** un `Stream` enveloppé dans `ZResult`.
///
/// ## 🔴 Consommation de la garde ACL (AC5, dette sécu lex)
///
/// Chaque mutation d'un **champ de contrôle** (`createShareLink`/`revokeShareLink`/
/// `grantMembership`/`publishToGallery`/`unpublish`) DOIT **consommer**
/// `ZStudySharingAcl.canMutateControl(...)` : une mutation par un **non-owner**
/// remonte `Left(ZFailure)` (échec d'autorisation domaine), **jamais** un `Right`
/// silencieux. L'enforcement **serveur** reste HORS domaine (**DW-ES94-1**, cf.
/// `ZStudySharingAcl`) : les règles backend de l'app doivent **répliquer** ce
/// prédicat.
///
/// ## `study_share_links` — collection GLOBALE (AD-20)
///
/// La collection des liens est **globale** : sa résolution de chemin est un
/// concern d'**adapter** (hors domaine). Ce port ne code **aucun** nom de
/// collection.
library;

import 'package:zcrud_core/domain.dart';

import 'z_public_study_folder.dart';
import 'z_share_link.dart';
import 'z_study_membership.dart';

/// Contrat neutre de partage d'un dossier d'étude (AD-5 : `Either<ZFailure,·>`).
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
