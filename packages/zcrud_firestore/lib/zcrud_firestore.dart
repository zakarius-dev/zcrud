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
// E5-3 : dépôt offline-first `ZOfflineFirstRepository<T>` (compose local+distant,
// merge Last-Write-Wins, soft-delete propagé, lot ≤ 450, `Right(unit)` si offline).
// Signatures publiques NUES (aucun type hive/cloud_firestore).
export 'src/data/z_offline_first_repository.dart';
