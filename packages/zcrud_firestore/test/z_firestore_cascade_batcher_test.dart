/// Tests à **pouvoir discriminant** de `ZFirestoreCascadeBatcher` (ES-3.3,
/// AC6-AC11). `flutter test` (VM) + `fake_cloud_firestore` ; `_CommitFailFirestore`
/// (parité E5 `_ThrowingFirestore`) pour la panne de lot.
///
/// **TÊTE : bornage ≤ 450 (AC8)** — observé via `report.batchCount` (450→1,
/// 451→2, 900→2, 901→3). `fake_cloud_firestore` n'impose PAS la limite 500, donc
/// un test « n'a pas throw » serait POWERLESS : seul `batchCount` prouve le
/// découpage. Chaque garde porte son commentaire R3 (quel retrait fait ROUGIR).
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ───────────────────────── Fixtures de topologie ────────────────────────────

/// Résolveur **flat** (IFFD) : chaque `kind` est une collection top-level ; les
/// enfants sont retrouvés par `where(childParentRef == parentId)`.
ZFirestorePathResolver _flatResolver() =>
    ZFirestorePathResolver(<String, ZFirestorePathRule>{
      'study_folder':
          const ZFirestorePathRule.flatTopLevel(collection: 'study_folders'),
      'flashcard':
          const ZFirestorePathRule.flatTopLevel(collection: 'flashcards'),
      'repetition_info': const ZFirestorePathRule.flatTopLevel(
          collection: 'repetition_infos'),
      'smart_note':
          const ZFirestorePathRule.flatTopLevel(collection: 'smart_notes'),
      'mindmap':
          const ZFirestorePathRule.flatTopLevel(collection: 'mindmaps'),
      'study_document': const ZFirestorePathRule.flatTopLevel(
          collection: 'study_documents'),
      'document_annotation': const ZFirestorePathRule.flatTopLevel(
          collection: 'document_annotations'),
      'exam': const ZFirestorePathRule.flatTopLevel(collection: 'exams'),
    });

/// Résolveur **nested** (lex) : les flashcards vivent en sous-collection sous le
/// dossier (`users/{uid}/study_folders/{folderId}/flashcards`).
ZFirestorePathResolver _nestedResolver() =>
    ZFirestorePathResolver(<String, ZFirestorePathRule>{
      'study_folder': const ZFirestorePathRule.flatTopLevel(
          collection: 'study_folders', userScoped: true),
      'flashcard': const ZFirestorePathRule.nestedUnderParent(
        collection: 'flashcards',
        parentCollection: 'study_folders',
      ),
    });

/// Registre canonique **miroir de lex** (flat) — arête par relation, ownership
/// unique par arête.
ZCascadeRegistry _lexMirrorRegistry() => ZCascadeRegistry(<ZCascadeEdge>[
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'study_folder',
        childParentRef: 'parent_id',
        owner: 'zcrud_study_kernel',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_flashcard',
      ),
      const ZCascadeEdge(
        parentKind: 'flashcard',
        childKind: 'repetition_info',
        childParentRef: 'flashcard_id',
        owner: 'zcrud_flashcard',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'smart_note',
        childParentRef: 'folder_id',
        owner: 'zcrud_note',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'mindmap',
        childParentRef: 'folder_id',
        owner: 'zcrud_mindmap',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'study_document',
        childParentRef: 'folder_id',
        owner: 'zcrud_document',
      ),
      const ZCascadeEdge(
        parentKind: 'study_document',
        childKind: 'document_annotation',
        childParentRef: 'document_id',
        owner: 'zcrud_document',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'exam',
        childParentRef: 'folder_id',
        owner: 'zcrud_exam',
      ),
    ]);

/// Registre minimal `study_folder → flashcard` (fixtures de bornage AC8).
ZCascadeRegistry _folderFlashcardRegistry() =>
    ZCascadeRegistry(<ZCascadeEdge>[
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_flashcard',
      ),
    ]);

// ───────────────────── Firestore de test : panne de commit ──────────────────

/// FakeFirestore dont **`batch().commit()` lève** (parité E5 `_ThrowingFirestore`,
/// mais côté COMMIT, pas côté lecture — l'énumération doit réussir).
class _CommitFailFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _ThrowingBatch();
}

/// `WriteBatch` dont `commit()` échoue ; `set`/`update`/`delete` = no-op.
class _ThrowingBatch implements WriteBatch {
  @override
  Future<void> commit() => Future<void>.error(
      FirebaseException(plugin: 'firestore', code: 'unavailable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ───────────────────────── Helpers de lecture ───────────────────────────────

Future<bool> _isDeleted(
  FakeFirebaseFirestore fs,
  String collection,
  String id,
) async {
  final snap = await fs.collection(collection).doc(id).get();
  return snap.data()?['is_deleted'] == true;
}

Future<Map<String, dynamic>?> _body(
  FakeFirebaseFirestore fs,
  String collection,
  String id,
) async =>
    (await fs.collection(collection).doc(id).get()).data();

/// Racine du repo (pour le grep anti-réflexion AC4).
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/packages/zcrud_firestore').existsSync() &&
        Directory('${dir.path}/packages/zcrud_study_kernel').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('racine du repo introuvable depuis ${Directory.current.path}');
}

/// Lignes de **code** (commentaires `//`/`///` retirés — la dartdoc peut nommer
/// les tokens bannis pour documenter la règle sans faux positif).
String _codeOnly(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('AC6 — construction + rapport typé (aucun type backend en retour)', () {
    test('le batcher s\'instancie et deleteCascade → ZResult<ZCascadeReport>',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('study_folders').doc('f1').set(<String, dynamic>{
        'title': 'root',
      });
      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      final result = await batcher.deleteCascade(
        rootKind: 'study_folder',
        rootId: 'f1',
      );
      final report = result.fold((f) => fail('attendu Right : $f'), (r) => r);
      expect(report, isA<ZCascadeReport>());
      expect(report.writeCount, equals(1)); // le seul root
      expect(report.batchCount, equals(1));
    });
  });

  group('AC8 — BORNAGE ≤ 450 / lot (writeCount → batchCount) [CŒUR]', () {
    // writeCount total = N flashcards + 1 (root). Cardinalités choisies pour
    // tomber PILE sur les bornes : 450→1, 451→2, 900→2, 901→3.
    Future<ZCascadeReport> runWith(int flashcards) async {
      final fs = FakeFirebaseFirestore();
      await fs
          .collection('study_folders')
          .doc('f1')
          .set(<String, dynamic>{'title': 'root'});
      for (var i = 0; i < flashcards; i++) {
        await fs
            .collection('flashcards')
            .doc('c$i')
            .set(<String, dynamic>{'folder_id': 'f1'});
      }
      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      final result = await batcher.deleteCascade(
        rootKind: 'study_folder',
        rootId: 'f1',
      );
      return result.fold((f) => fail('attendu Right : $f'), (r) => r);
    }

    // R3-a : remplacer la boucle de flush par un unique `batch.commit()` fait
    // tomber CHAQUE cas > 450 à batchCount == 1 ⇒ (b)/(c)/(d) ROUGISSENT.
    test('writeCount 450 ⇒ batchCount 1', () async {
      final r = await runWith(449);
      expect(r.writeCount, equals(450));
      expect(r.batchCount, equals(1));
    });

    test('writeCount 451 ⇒ batchCount 2', () async {
      final r = await runWith(450);
      expect(r.writeCount, equals(451));
      expect(r.batchCount, equals(2));
    });

    test('writeCount 900 ⇒ batchCount 2', () async {
      final r = await runWith(899);
      expect(r.writeCount, equals(900));
      expect(r.batchCount, equals(2));
    });

    test('writeCount 901 ⇒ batchCount 3', () async {
      final r = await runWith(900);
      expect(r.writeCount, equals(901));
      expect(r.batchCount, equals(3));
    });
  });

  group('AC7 — cascade complète ; frère NON déclaré intact', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      await fs.collection('study_folders').doc('f1').set(
          <String, dynamic>{'title': 'root'});
      // sous-dossier f2 (self-edge, parent_id == f1)
      await fs.collection('study_folders').doc('f2').set(
          <String, dynamic>{'title': 'sub', 'parent_id': 'f1'});
      await fs.collection('flashcards').doc('c1').set(
          <String, dynamic>{'folder_id': 'f1'});
      // carte sous le SOUS-dossier (cascade transitive de niveau 2)
      await fs.collection('flashcards').doc('c2').set(
          <String, dynamic>{'folder_id': 'f2'});
      await fs.collection('repetition_infos').doc('r1').set(
          <String, dynamic>{'flashcard_id': 'c1'});
      await fs.collection('smart_notes').doc('n1').set(
          <String, dynamic>{'folder_id': 'f1'});
      await fs.collection('mindmaps').doc('m1').set(
          <String, dynamic>{'folder_id': 'f1'});
      await fs.collection('study_documents').doc('d1').set(
          <String, dynamic>{'folder_id': 'f1'});
      await fs.collection('document_annotations').doc('a1').set(
          <String, dynamic>{'document_id': 'd1'});
      await fs.collection('exams').doc('e1').set(
          <String, dynamic>{'folder_id': 'f1'});
      // FRÈRE NON DÉCLARÉ (collection absente du registre)
      await fs.collection('unrelated').doc('u1').set(
          <String, dynamic>{'folder_id': 'f1'});
    });

    test('tous les descendants déclarés sont soft-deletés ; unrelated intact',
        () async {
      final batcher = ZFirestoreCascadeBatcher(
        registry: _lexMirrorRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      final result = await batcher.deleteCascade(
        rootKind: 'study_folder',
        rootId: 'f1',
      );
      expect(result.isRight(), isTrue);

      // R3-b (partie batcher) : skip un childKind (ex. document_annotation) à
      // l'exécution laisse `a1` actif ⇒ ce test ROUGIT.
      expect(await _isDeleted(fs, 'study_folders', 'f1'), isTrue, reason: 'root');
      expect(await _isDeleted(fs, 'study_folders', 'f2'), isTrue,
          reason: 'sous-dossier');
      expect(await _isDeleted(fs, 'flashcards', 'c1'), isTrue);
      expect(await _isDeleted(fs, 'flashcards', 'c2'), isTrue,
          reason: 'carte du sous-dossier (transitive niveau 2)');
      expect(await _isDeleted(fs, 'repetition_infos', 'r1'), isTrue,
          reason: 'transitive flashcard→repetition');
      expect(await _isDeleted(fs, 'smart_notes', 'n1'), isTrue);
      expect(await _isDeleted(fs, 'mindmaps', 'm1'), isTrue);
      expect(await _isDeleted(fs, 'study_documents', 'd1'), isTrue);
      expect(await _isDeleted(fs, 'document_annotations', 'a1'), isTrue,
          reason: 'transitive document→annotation');
      expect(await _isDeleted(fs, 'exams', 'e1'), isTrue);

      // Frère non déclaré : JAMAIS touché.
      expect(await _isDeleted(fs, 'unrelated', 'u1'), isFalse,
          reason: 'collection non déclarée dans le registre');
    });
  });

  group('AC9 — soft-delete HORS-ENTITÉ (merge:true, corps préservé)', () {
    test('is_deleted posé ; le corps métier `title` survit', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('study_folders').doc('f1').set(
          <String, dynamic>{'title': 'root'});
      await fs.collection('flashcards').doc('c1').set(
          <String, dynamic>{'title': 'x', 'folder_id': 'f1'});

      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      await batcher.deleteCascade(rootKind: 'study_folder', rootId: 'f1');

      // R3-c : retirer `SetOptions(merge:true)` ⇒ le `set` REMPLACE le doc ⇒
      // `title` disparaît ⇒ ce test ROUGIT.
      final body = await _body(fs, 'flashcards', 'c1');
      expect(body, isNotNull);
      expect(body!['title'], equals('x'), reason: 'corps métier préservé');
      expect(body['folder_id'], equals('f1'));
      expect(body['is_deleted'], isTrue);
      expect(body.containsKey('updated_at'), isTrue,
          reason: 'la seule autre clé écrite est la méta hors-entité');
    });
  });

  group('AC10 — panne de lot NON avalée (Left, jamais Right)', () {
    test('commit() qui échoue ⇒ Left(ServerFailure)', () async {
      final fs = _CommitFailFirestore();
      await fs.collection('study_folders').doc('f1').set(
          <String, dynamic>{'title': 'root'});
      await fs.collection('flashcards').doc('c1').set(
          <String, dynamic>{'folder_id': 'f1'});

      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      final result = await batcher.deleteCascade(
        rootKind: 'study_folder',
        rootId: 'f1',
      );

      // R3-e : envelopper le commit dans `catch (_) { return Right(report); }`
      // masque la panne ⇒ ce test ROUGIT (attendait Left).
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('la panne de commit ne doit JAMAIS remonter Right'),
      );
    });
  });

  group('AC11 — bi-topologie résolue par ZFirestorePathResolver', () {
    test('nested (lex) : sous-collection sous parent, tous enfants cascadés',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs
          .collection('users/u1/study_folders')
          .doc('f1')
          .set(<String, dynamic>{'title': 'root'});
      await fs
          .collection('users/u1/study_folders/f1/flashcards')
          .doc('c1')
          .set(<String, dynamic>{'q': 'a'});
      await fs
          .collection('users/u1/study_folders/f1/flashcards')
          .doc('c2')
          .set(<String, dynamic>{'q': 'b'});

      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _nestedResolver(),
        firestore: fs,
      );
      final result = await batcher.deleteCascade(
        rootKind: 'study_folder',
        rootId: 'f1',
        userId: 'u1',
      );
      expect(result.isRight(), isTrue);
      expect(await _isDeleted(fs, 'users/u1/study_folders', 'f1'), isTrue);
      expect(
          await _isDeleted(fs, 'users/u1/study_folders/f1/flashcards', 'c1'),
          isTrue);
      expect(
          await _isDeleted(fs, 'users/u1/study_folders/f1/flashcards', 'c2'),
          isTrue);
    });

    test('flat (IFFD) : where(folder_id==parent) ; carte d\'un AUTRE parent intacte',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('study_folders').doc('f1').set(
          <String, dynamic>{'title': 'root'});
      await fs.collection('flashcards').doc('c1').set(
          <String, dynamic>{'folder_id': 'f1'});
      await fs.collection('flashcards').doc('cOther').set(
          <String, dynamic>{'folder_id': 'autre'});

      final batcher = ZFirestoreCascadeBatcher(
        registry: _folderFlashcardRegistry(),
        resolver: _flatResolver(),
        firestore: fs,
      );
      await batcher.deleteCascade(rootKind: 'study_folder', rootId: 'f1');

      // R3 (topologie) : forcer la stratégie nested (retirer le `where`) ferait
      // soft-deleter cOther aussi ⇒ ce test ROUGIT.
      expect(await _isDeleted(fs, 'flashcards', 'c1'), isTrue);
      expect(await _isDeleted(fs, 'flashcards', 'cOther'), isFalse,
          reason: 'enfant d\'un AUTRE parent — le where(FK) le protège');
    });
  });

  group('AC4 — anti-réflexion : ni runtimeType ni .toString() en dérivation', () {
    late Directory root;
    setUpAll(() => root = _repoRoot());

    for (final rel in <String>[
      'packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart',
      'packages/zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart',
    ]) {
      test('$rel ne dérive aucun kind/chemin par réflexion', () {
        final code = _codeOnly(File('${root.path}/$rel'));
        // R3-d : router la résolution d'un childKind via `child.runtimeType
        // .toString()` réintroduirait ces tokens ⇒ ce grep ROUGIT.
        expect(code.contains('runtimeType'), isFalse,
            reason: '$rel : `runtimeType` banni (AD-3/NFR-S8)');
        expect(code.contains('.toString('), isFalse,
            reason: '$rel : `.toString()` banni en dérivation de kind/chemin');
      });
    }
  });
}
