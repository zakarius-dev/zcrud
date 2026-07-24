// CR-LEX-19 — `ZEntity.isEphemeral` était un contrat que les implémentations
// NE CONSULTAIENT PAS : elles testaient `id == null` directement. Une entité
// dont l'`id` est NON-NULLABLE (ex. `ZMindmap`, `isEphemeral => id.isEmpty`)
// n'est jamais `null` — elle était donc déclarée matérialisée, et un document
// de clé VIDE partait en base.
//
// CR-LEX-30 — seule la topologie `nestedUnderParent` avait sa fabrique publiée.
// Un hôte dont la collection est RACINE devait ré-assembler la composition à la
// main, à chaque site ; le contournement a fini en production.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const String _kNote = 'note';

/// Entité à `id` **NON-NULLABLE** — le cas que `id == null` ne sait pas voir.
class _IdNonNullable extends ZEntity {
  const _IdNonNullable({this.id = '', required this.title});

  @override
  final String id;
  final String title;

  /// C'est CE contrat que les implémentations ignoraient.
  @override
  bool get isEphemeral => id.isEmpty;

  static _IdNonNullable fromMap(Map<String, dynamic> m) => _IdNonNullable(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
      );
  Map<String, dynamic> toMap() =>
      <String, dynamic>{'id': id, 'title': title};
}

void main() {
  late Directory tmp;
  var seq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('crlex1930');
    Hive.init(tmp.path);
  });
  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('🔴 CR-LEX-19 — `isEphemeral` fait foi, pas `id == null`', () {
    test('une entité à `id` NON-NULLABLE et VIDE est matérialisée', () async {
      final box = await Hive.openBox<dynamic>('n_${seq++}');
      final store = HiveZLocalStore<_IdNonNullable>(
        box: box,
        kind: _kNote,
        fromMap: _IdNonNullable.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'materialise',
      );

      final saved = (await store.put(const _IdNonNullable(title: 'T')))
          .getOrElse(() => throw StateError('left'));

      expect(saved.id, 'materialise',
          reason: '`id == null` était faux ici — l\'entité passait pour '
              'matérialisée et un document de clé VIDE partait en base');
      expect(box.containsKey(''), isFalse,
          reason: 'aucune clé vide ne doit exister dans la box');
      expect(box.containsKey('materialise'), isTrue);
    });

    test('une entité DÉJÀ identifiée garde son `id`', () async {
      final box = await Hive.openBox<dynamic>('n_${seq++}');
      final store = HiveZLocalStore<_IdNonNullable>(
        box: box,
        kind: _kNote,
        fromMap: _IdNonNullable.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'JAMAIS',
      );
      final saved = (await store.put(const _IdNonNullable(id: 'x1', title: 'T')))
          .getOrElse(() => throw StateError('left'));
      expect(saved.id, 'x1');
      expect(box.containsKey('JAMAIS'), isFalse);
    });

    test('le corps persisté porte l\'id matérialisé (invariant clé↔corps)',
        () async {
      final box = await Hive.openBox<dynamic>('n_${seq++}');
      final store = HiveZLocalStore<_IdNonNullable>(
        box: box,
        kind: _kNote,
        fromMap: _IdNonNullable.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'materialise',
      );
      await store.put(const _IdNonNullable(title: 'T'));
      final raw =
          jsonDecode(box.get('materialise') as String) as Map<String, dynamic>;
      expect(raw['id'], 'materialise');
    });

    test('putMerged consulte AUSSI `isEphemeral`', () async {
      final box = await Hive.openBox<dynamic>('n_${seq++}');
      final store = HiveZLocalStore<_IdNonNullable>(
        box: box,
        kind: _kNote,
        fromMap: _IdNonNullable.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'materialise',
      );
      final saved = (await store.putMerged(const _IdNonNullable(title: 'T')))
          .getOrElse(() => throw StateError('left'));
      expect(saved.id, 'materialise');
    });
  });

  group('🔴 CR-LEX-30 — la fabrique `flatTopLevel(userScoped:)` est publiée', () {
    Future<HiveZLocalStore<_IdNonNullable>> local() async {
      final box = await Hive.openBox<dynamic>('n_${seq++}');
      return HiveZLocalStore<_IdNonNullable>(
        box: box,
        kind: _kNote,
        fromMap: _IdNonNullable.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'gen',
      );
    }

    test('elle construit un dépôt utilisable, sans ré-assemblage à la main',
        () async {
      final repo = buildUserScopedStudyRepository<_IdNonNullable>(
        firestore: FakeFirebaseFirestore(),
        local: await local(),
        kind: _kNote,
        collection: 'notes',
        decode: _IdNonNullable.fromMap,
        encode: (x) => x.toMap(),
        userScoped: true,
        userId: 'u1',
        autoListen: false,
      );
      expect(repo, isA<ZStudyRepository<_IdNonNullable>>(),
          reason: 'type de retour NEUTRE — aucun type Firestore en signature');

      final saved = await repo.save(const _IdNonNullable(id: 'x1', title: 'T'));
      expect(saved.isRight(), isTrue);
    });

    test('🔴 elle écrit DANS le scope utilisateur demandé', () async {
      final fs = FakeFirebaseFirestore();
      final repo = buildUserScopedStudyRepository<_IdNonNullable>(
        firestore: fs,
        local: await local(),
        kind: _kNote,
        collection: 'notes',
        decode: _IdNonNullable.fromMap,
        encode: (x) => x.toMap(),
        userScoped: true,
        userId: 'u1',
        autoListen: false,
      );
      await repo.save(const _IdNonNullable(id: 'x1', title: 'T'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final scoped = await fs.collection('users/u1/notes').get();
      expect(scoped.docs, hasLength(1),
          reason: 'le document doit vivre SOUS l\'utilisateur');
      final racine = await fs.collection('notes').get();
      expect(racine.docs, isEmpty,
          reason: 'jamais à la racine quand userScoped vaut true');
    });

    test('`userScoped: false` écrit à la RACINE', () async {
      final fs = FakeFirebaseFirestore();
      final repo = buildUserScopedStudyRepository<_IdNonNullable>(
        firestore: fs,
        local: await local(),
        kind: _kNote,
        collection: 'notes',
        decode: _IdNonNullable.fromMap,
        encode: (x) => x.toMap(),
        userScoped: false,
        autoListen: false,
      );
      await repo.save(const _IdNonNullable(id: 'x1', title: 'T'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await fs.collection('notes').get()).docs, hasLength(1));
    });
  });
}
