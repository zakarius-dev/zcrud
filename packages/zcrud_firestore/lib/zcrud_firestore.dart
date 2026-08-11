/// Barrel d'API publique de `zcrud_firestore`.
///
/// Adaptateurs Firestore + Hive, offline-first.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
///
/// **Isolation (invariant AD-5)** : ce barrel n'exporte AUCUN type
/// `cloud_firestore` ni `hive`. Les signatures publiques de
/// [FirebaseZRepositoryImpl] / [HiveZLocalStore] / [FirestoreZRemoteStore]
/// restent `ZResult<…>` / `Stream<List<T>>` **nues** ; l'injection d'une
/// instance `FirebaseFirestore` (repo/remote) ou d'une `Box` Hive (local) est
/// la SEULE couture (voulue) vers le backend.
///
/// Ce barrel réunit les DEUX stores offline-first — [HiveZLocalStore] (local,
/// source de vérité) et [FirestoreZRemoteStore] (distant, fire-and-forget) —
/// ainsi que le dépôt composite qui les fusionne
/// ([ZOfflineFirstRepository]/[ZOfflineFirstBoxRepository]), un batcher de
/// cascade borné, un résolveur de chemins bi-topologie, et les fabriques
/// study (résolveur, codec legacy, migrateur, orchestrateur de sync).
library;

export 'src/data/firebase_z_repository_impl.dart';
export 'src/data/firestore_z_remote_store.dart';
export 'src/data/hive_z_local_store.dart';
export 'src/data/z_firestore_api.dart';
// Exécuteur borné de cascade `ZFirestoreCascadeBatcher` + rapport observable
// `ZCascadeReport`. `deleteCascade → ZResult<ZCascadeReport>` (soft-delete
// hors-entité en lots ≤ 450, panne remontée en `Left`). Compose le registre
// kernel (quoi) + `ZFirestorePathResolver` (où). Signatures publiques NUES —
// aucun type `cloud_firestore` exporté (invariants AD-5/AD-11).
export 'src/data/z_firestore_app_file_resolver.dart';
export 'src/data/z_firestore_cascade_batcher.dart';
// Résolveur de chemins `ZFirestorePathResolver` bi-topologie (flat / nested /
// liens de partage globaux). Entrée NEUTRE → chemin `String` ; aucun type
// hive/cloud_firestore n'est exporté (invariant AD-5).
export 'src/data/z_firestore_path_resolver.dart';
// Fabriques d'adaptateur folder-scopé et user-scopé CONCRÈTES
// (`buildFolderScopedStudyRepository<T>` / `buildUserScopedStudyRepository<T>`)
// — composent `ZFirestorePathRule.nestedUnderParent` + `ZFirestorePathResolver`
// + `ZOfflineFirstBoxRepository<T>`. Générique-par-topologie (aucun nom
// consommateur en dur, aucune arête d'entité). Retour NEUTRE
// `ZStudyRepository<T>` ; seul `FirebaseFirestore` (paramètre) est une
// couture backend. `buildFolderScopedResolver` (`@visibleForTesting`) n'est
// PAS réexporté.
export 'src/data/z_folder_scoped_study_repository.dart'
    show buildFolderScopedStudyRepository, buildUserScopedStudyRepository;
// Base offline-first `ZOfflineFirstBoxRepository<T>` — implémente le point
// d'extension `persist` du gabarit `ZStudyRepository<T>` ; merge LWW
// hors-entité, `hasPendingWrites`, listener temps réel, rattrapage
// local-only. Signatures publiques NUES (aucun type hive/cloud_firestore).
export 'src/data/z_offline_first_box_repository.dart';
// Dépôt offline-first `ZOfflineFirstRepository<T>` (compose local+distant,
// merge Last-Write-Wins, soft-delete propagé, lot ≤ 450, `Right(unit)` si
// offline). Signatures publiques NUES (aucun type hive/cloud_firestore).
export 'src/data/z_offline_first_repository.dart';
// Codec/normaliseur d'adaptateur `ZStudyLegacyCodec` — camelCase↔snake_case,
// mapping de statuts legacy, `ZSyncMeta` additif rétro-compatible, interop
// dates `int` millis. Normaliseur PUR de `Map` DÉFENSIF (jamais throw) ;
// signature NUE `Map<String,dynamic>` (aucun type cloud_firestore —
// invariant AD-5). Le mapping de casse/valeur vit EXCLUSIVEMENT ici.
export 'src/data/z_study_codec.dart';
// Migrateur de corpus legacy flat→canonique `ZLegacyStudyMigrator` (+
// `ZDocumentMigrationOutcome`/`ZLegacyMigrationReport`). Compose
// `ZStudyLegacyCodec` (par document) et ajoute une garde d'idempotence, un
// recensement de préservation métier, un rapport auditable et un mode
// simulation (dry-run). Signature NUE `Map<String,dynamic>` (aucun type
// cloud_firestore/hive — invariant AD-5) ; générique par `Map` (aucune arête
// d'entité).
export 'src/data/z_study_migrator.dart';
// Fabrique de câblage `assembleZStudySyncOrchestrator` — liste de dépôts
// INJECTÉE, aucun import/liste codés en dur. Compose `ZSyncOrchestrator` :
// best-effort + débounce hérité. Signature NUE (aucun type backend exporté ;
// aucun gestionnaire d'état/`firebase_auth`/`connectivity_plus` — invariant
// AD-15).
export 'src/data/z_study_sync_orchestrator.dart';
