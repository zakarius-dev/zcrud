// ES-10.2 AC3/AC4 — fabrique d'adapter folder-scopé CONCRÈTE
// `buildFolderScopedStudyRepository<T>` (composition MINCE des briques ES-3 pour
// la topologie `users/{uid}/{parent}/{folderId}/{collection}`).
//
// R20 (frontière honnête) : le garde `parentId manquant → Left` + la résolution
// de chemin vivent dans `ZFirestorePathResolver` (ES-3, déjà testé). L'APPORT
// propre d'ES-10.2 = prouver que la fabrique COMPOSE la bonne règle
// `nestedUnderParent(collection, parentCollection)` (chemin nested EXACT, AC3) et
// PROPAGE le `Left` folderId-manquant au lieu de bâtir un chemin plat de repli
// (AC4) — testé via le seam de composition `buildFolderScopedResolver` que la
// fabrique utilise EN INTERNE.
//
// Injections R3 co-livrées :
//  R3-I6 — intervertir `collection`/`parentCollection` dans la règle composée ⇒
//          l'assertion `users/u1/study_folders/f1/study_documents` rougit.
//  R3-I4 — bâtir une règle `flatTopLevel` de repli (folderId avalé) ⇒ le cas
//          folderId='' n'est PLUS un `Left` (parentId non exigé) ⇒ rougit.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Le seam de composition `@visibleForTesting` (non réexporté par le barrel).
import 'package:zcrud_firestore/src/data/z_folder_scoped_study_repository.dart'
    show buildFolderScopedResolver;
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Fake local store GÉNÉRIQUE — jamais sollicité (autoListen:false, aucune op).
class _FakeLocal<T extends ZEntity> implements ZLocalStore<T> {
  @override
  Stream<List<T>> watchAll() => const Stream.empty();
  @override
  Future<ZResult<List<T>>> getAll() => throw UnimplementedError();
  @override
  Future<ZResult<T>> getById(String id) => throw UnimplementedError();
  @override
  Future<ZResult<T>> put(T item) => throw UnimplementedError();
  @override
  Future<ZResult<Unit>> softDelete(String id) => throw UnimplementedError();
  @override
  Future<ZResult<Unit>> restore(String id) => throw UnimplementedError();
  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() =>
      throw UnimplementedError();
  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) =>
      throw UnimplementedError();
  @override
  Future<ZResult<Unit>> clear() => throw UnimplementedError();
  @override
  void dispose() {}
}

void main() {
  const kind = 'study_document';
  const collection = 'study_documents';
  const parentCollection = 'study_folders';

  test('AC3 — la règle composée résout le chemin nested EXACT '
      'users/u1/study_folders/f1/study_documents [R3-I6]', () {
    final resolver = buildFolderScopedResolver(
      kind: kind,
      collection: collection,
      parentCollection: parentCollection,
    );
    final path = resolver.resolveCollection(
      kind: kind,
      userId: 'u1',
      parentId: 'f1',
    );
    expect(
      path.fold((f) => 'LEFT:${f.message}', (p) => p),
      'users/u1/study_folders/f1/study_documents',
    );
  });

  test('AC4 — folderId vide (parentId="") ⇒ Left(DomainFailure) explicite '
      'nommant parentId + le kind, jamais un chemin muet [R3-I4]', () {
    final resolver = buildFolderScopedResolver(
      kind: kind,
      collection: collection,
      parentCollection: parentCollection,
    );
    final res = resolver.resolveCollection(
      kind: kind,
      userId: 'u1',
      parentId: '', // folderId manquant propagé tel quel.
    );
    expect(res.isLeft(), isTrue,
        reason: 'la topologie nested EXIGE un parentId non vide');
    final msg = res.fold((f) => f.message, (p) => 'RIGHT:$p');
    expect(msg, contains('parentId'));
    expect(msg, contains(kind));
    expect(res.fold((f) => f, (_) => null), isA<DomainFailure>());
  });

  test('AC3 — le type de retour public est le PORT NEUTRE ZStudyRepository<T> '
      '(garde compile-time ; aucun cloud_firestore en retour)', () {
    final repo = buildFolderScopedStudyRepository<ZStudyFolder>(
      firestore: FakeFirebaseFirestore(),
      local: _FakeLocal<ZStudyFolder>(),
      kind: 'study_folder',
      collection: 'study_folders',
      parentCollection: 'users_folders',
      decode: (m) => ZStudyFolder(id: m['id'] as String?, title: ''),
      encode: (v) => <String, dynamic>{'id': v.id},
      userId: 'u1',
      folderId: 'f1',
      autoListen: false, // pas de listener temps réel en test.
    );
    addTearDown(repo.dispose);
    expect(repo, isA<ZStudyRepository<ZStudyFolder>>());
    // Composition effective des briques ES-3 (non redéclarées).
    expect(repo, isA<ZOfflineFirstBoxRepository<ZStudyFolder>>());

    // 🔴 LOAD-BEARING (MEDIUM-1 code-review) : la fabrique PUBLIQUE a bien câblé
    // `collection`/`parentCollection` dans le resolver du repo produit. Swapper
    // ces 2 arguments AU SITE D'APPEL de la fabrique (jamais couvert par le test
    // du helper `buildFolderScopedResolver` en isolation) rend ce chemin FAUX ⇒
    // rougit ici. C'est le symbole que lex consommera : son câblage est prouvé.
    final resolved =
        (repo as ZOfflineFirstBoxRepository<ZStudyFolder>).resolver.resolveCollection(
      kind: 'study_folder',
      userId: 'u1',
      parentId: 'f1',
    );
    expect(
      resolved.fold((f) => 'LEFT:${f.message}', (p) => p),
      'users/u1/users_folders/f1/study_folders',
    );
  });
}
