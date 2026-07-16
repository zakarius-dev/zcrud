/// Port neutre de **modération** `ZStudyModerationPort` (Story ES-9.4, AC1/AC7).
///
/// origine: seam de modération communautaire OPTIONNEL du domaine `zcrud_study`
/// (FR-S32, AD-5/AD-11/AD-26). Contrat **pur** (`abstract interface class`,
/// **jamais** `sealed` — AD-4). L'app hôte le branche sur son backend : **aucun**
/// SDK, endpoint, clé, token, nom de collection en dur ni crypto (AD-11/AD-12).
///
/// ## Surface AD-5
///
/// Toute opération retourne `Future<ZResult<T>>` / `Future<ZResult<Unit>>` ; le
/// flux de signalements est un `Stream<List<ZStudyFolderReport>>` **NU** — jamais
/// enveloppé dans `ZResult`.
///
/// ## Autorité (renvoi vers `ZStudySharingAcl`)
///
/// `resolveReport`/`takedown` sont des **actions de modération** owner/modérateur :
/// leur autorisation suit la même logique owner-only que
/// `ZStudySharingAcl.canMutateControl` ; l'enforcement **serveur** reste HORS
/// domaine (**DW-ES94-1**). `report` est ouvert à tout utilisateur signalant.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_folder_report.dart';

/// Contrat neutre de modération d'un dossier partagé (AD-5 : `Either<ZFailure,·>`).
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
