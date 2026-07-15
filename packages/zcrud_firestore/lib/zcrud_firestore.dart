/// Barrel d'API publique de `zcrud_firestore`.
///
/// Adapters Firestore + Hive (offline-first).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
///
/// **Isolation AD-5** : ce barrel n'exporte AUCUN type `cloud_firestore` ni
/// `hive`. Les signatures publiques de [FirebaseZRepositoryImpl] /
/// [HiveZLocalStore] / [FirestoreZRemoteStore] restent `ZResult<…>` /
/// `Stream<List<T>>` **nues** ; l'injection d'une instance `FirebaseFirestore`
/// (repo/remote) ou d'une `Box` Hive (local) est la SEULE couture (voulue) vers
/// le backend.
///
/// **E5-2** ajoute les DEUX stores offline-first : [HiveZLocalStore] (local,
/// source de vérité) et [FirestoreZRemoteStore] (distant, fire-and-forget). Le
/// merge LWW/orchestrateur (E5-3/E5-4) n'est PAS ici.
library;

export 'src/data/firebase_z_repository_impl.dart';
export 'src/data/firestore_z_remote_store.dart';
export 'src/data/hive_z_local_store.dart';
export 'src/data/z_firestore_api.dart';
// ES-3.3 (FR-S14, AD-21) : exécuteur borné de cascade `ZFirestoreCascadeBatcher`
// + rapport observable `ZCascadeReport`. `deleteCascade → ZResult<ZCascadeReport>`
// (soft-delete hors-entité en lots ≤ 450, panne remontée en `Left`). Compose le
// registre kernel (quoi) + `ZFirestorePathResolver` (où). Signatures publiques
// NUES — aucun type `cloud_firestore` exporté (AD-5/AD-11).
export 'src/data/z_firestore_cascade_batcher.dart';
// ES-3.2 (FR-S13) : résolveur de chemins `ZFirestorePathResolver` bi-topologie
// (flat IFFD / nested lex / global share-links). Entrée NEUTRE → chemin `String` ;
// aucun type hive/cloud_firestore n'est exporté (AD-5).
export 'src/data/z_firestore_path_resolver.dart';
// ES-3.2 (FR-S13) : base offline-first `ZOfflineFirstBoxRepository<T>` — implémente
// le point d'extension `persist` du Template Method `ZStudyRepository<T>` (ES-3.1) ;
// merge LWW hors-entité, `hasPendingWrites`, listener temps réel, rattrapage
// local-only. Signatures publiques NUES (aucun type hive/cloud_firestore).
export 'src/data/z_offline_first_box_repository.dart';
// E5-3 : dépôt offline-first `ZOfflineFirstRepository<T>` (compose local+distant,
// merge Last-Write-Wins, soft-delete propagé, lot ≤ 450, `Right(unit)` si offline).
// Signatures publiques NUES (aucun type hive/cloud_firestore).
export 'src/data/z_offline_first_repository.dart';
// ES-3.5 (FR-S16, AD-27/AD-10) : codec/normaliseur d'adaptateur `ZStudyLegacyCodec`
// — camelCase↔snake_case, mapping legacy IFFD 6→4 statuts (DW-ES21-1), `ZSyncMeta`
// additif rétro-compatible, interop dates `int` millis (DW-ES32-1). Normaliseur PUR
// de `Map` DÉFENSIF (jamais throw) ; signature NUE `Map<String,dynamic>` (aucun type
// cloud_firestore — AD-5). Le mapping de casse/valeur vit EXCLUSIVEMENT ici (AD-27).
export 'src/data/z_study_codec.dart';
// ES-3.4 (FR-S15, AD-20) : fabrique de câblage `assembleZStudySyncOrchestrator`
// — remplaçant neutre de `study_sync_manager.dart` (liste de repos INJECTÉE, aucun
// import/liste codés en dur). Compose `ZSyncOrchestrator` (E5-4) : best-effort +
// débounce ~400 ms hérités (AD-4). Signature NUE (aucun type backend exporté ;
// aucun Riverpod/firebase_auth/connectivity_plus — AD-15).
export 'src/data/z_study_sync_orchestrator.dart';
