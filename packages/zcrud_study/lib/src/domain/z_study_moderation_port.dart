/// Contrat de modération communautaire d'un dossier d'étude partagé.
///
/// Seam optionnelle du domaine `zcrud_study` : contrat pur
/// (`abstract interface class`, jamais `sealed`, invariant AD-4 — extension
/// par composition) que l'application hôte implémente en le branchant sur son
/// propre backend. Aucun SDK, endpoint, clé, jeton, nom de collection ni
/// primitive de chiffrement ne fuit dans ce port (invariant AD-12).
///
/// Toute opération retourne `Future<ZResult<T>>` (invariant AD-11,
/// `Either<ZFailure, T>`) ou `Future<ZResult<Unit>>` pour un effet sans
/// valeur ; le flux de signalements est un `Stream<List<ZStudyFolderReport>>`
/// nu — jamais enveloppé dans [ZResult].
///
/// `resolveReport` et `takedown` sont des actions de modération réservées au
/// propriétaire ou à un modérateur : leur autorisation suit la même logique
/// owner-only que le contrôle d'accès de partage (voir `ZStudySharingAcl`).
/// L'application hôte doit répliquer cette même règle côté serveur — ce
/// contrat neutre ne l'impose pas lui-même. `report`, en revanche, reste
/// ouvert à tout utilisateur qui signale.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_folder_report.dart';

/// Contrat neutre de modération d'un dossier partagé (invariant AD-5 :
/// domaine backend-agnostique, `Either<ZFailure, T>`).
abstract interface class ZStudyModerationPort {
  /// Enregistre un signalement. `Right(Unit)` en succès ; `Left(ZFailure)` en
  /// cas d'échec (réseau, quota, validation).
  Future<ZResult<Unit>> report(ZStudyFolderReport report);

  /// Flux **NU** des signalements d'un dossier (`Stream<List<T>>`, AD-5).
  Stream<List<ZStudyFolderReport>> watchReports(String folderId);

  /// Résout un signalement (action de modération). `Right(Unit)` en succès ;
  /// `Left` si non autorisé ou en cas d'échec.
  Future<ZResult<Unit>> resolveReport(String reportId);

  /// Retire un dossier de la diffusion publique (action de modération).
  /// `Right(Unit)` en succès ; `Left` si non autorisé ou en cas d'échec.
  Future<ZResult<Unit>> takedown(String folderId);
}
