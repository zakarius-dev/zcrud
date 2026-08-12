/// Adaptateur **Firestore** concret du port neutre `ZRemoteStore<T>`.
///
/// Store DISTANT **fire-and-forget** (invariant AD-9). Réalisé par
/// **composition** sur l'adaptateur Firestore [FirebaseZRepositoryImpl] — pas
/// d'héritage (invariant AD-4 rejette l'héritage de classes sérialisées) et
/// pas de second traducteur `ZDataRequest→Query`. Le port distant reste
/// **mince** : `push→save`, `remoteDelete→softDelete`, `pull→getAll`,
/// `watchAll→watchAll`.
///
/// **Fire-and-forget best-effort (borné)** : la sémantique du port est que
/// le distant **n'est jamais la source de vérité** (un échec distant ≠ un échec
/// du store local). Cette implémentation se **contente de déléguer** à
/// l'adaptateur Firestore et de **propager son `ZResult` typé**
/// (`ZServerFailure` inclus, jamais avalé). L'**orchestration** — débounce,
/// best-effort silencieux (`Right(unit)` si déconnecté), cascade bornée ≤
/// 450, merge Last-Write-Wins sur `updatedAt` — vit dans les autres fichiers
/// de ce paquet et n'est **PAS** implémentée ici (frontière **volontaire**).
///
/// **Isolation (invariant AD-5, re-vérifiée)** : aucun type `cloud_firestore`
/// ne fuit — la classe n'importe même **pas** `cloud_firestore` (elle ne
/// connaît que le repository neutre). Les signatures restent `ZResult<…>` /
/// `Stream<List<T>>` **nues**.
library;

// `prefer_initializing_formals` : FAUX POSITIF (champ privé exposé en
// paramètre nommé — `this._x` interdit par Dart). Désactivé au niveau
// fichier, comme les autres adaptateurs de ce paquet.
// ignore_for_file: prefer_initializing_formals

import 'package:zcrud_core/zcrud_core.dart';

import 'firebase_z_repository_impl.dart';

/// Adaptateur Firestore de [ZRemoteStore] pour l'agrégat [T], par
/// **composition** sur un [FirebaseZRepositoryImpl].
///
/// **Injection** : le [repository] Firestore (couture DI ; il porte
/// lui-même l'instance `FirebaseFirestore`). Le remote store n'ajoute aucune
/// logique de traduction — il **délègue** intégralement, préservant la MÊME
/// sémantique de clé (corps `id`) et de soft-delete (`is_deleted`/`updated_at`
/// hors-entité) que le repository sous-jacent.
class FirestoreZRemoteStore<T extends ZEntity> extends ZRemoteStore<T> {
  /// Construit le store distant par composition sur le [repository].
  FirestoreZRemoteStore({
    required FirebaseZRepositoryImpl<T> repository,
  }) : _repository = repository;

  final FirebaseZRepositoryImpl<T> _repository;

  @override
  Future<ZResult<T>> push(T item) => _repository.save(item);

  @override
  Future<ZResult<Unit>> remoteDelete(String id) => _repository.softDelete(id);

  @override
  Future<ZResult<List<T>>> pull({ZDataRequest? request}) =>
      _repository.getAll(request: request);

  @override
  Stream<List<T>> watchAll() => _repository.watchAll();

  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() =>
      _repository.syncEntriesAll();

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) =>
      _repository.writeMerged(entry);

  @override
  Future<ZResult<Unit>> applyMergedAll(List<ZSyncEntry<T>> entries) =>
      _repository.applyMergedAll(entries);

  @override
  void dispose() => _repository.dispose();
}
