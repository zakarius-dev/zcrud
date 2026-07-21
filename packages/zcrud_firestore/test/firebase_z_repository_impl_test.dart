// Tests E5-1 : `FirebaseZRepositoryImpl<T>` (traduction `ZDataRequest→Query`,
// curseur, soft-delete/restore, count, décodage défensif, isolation d'erreurs).
//
// Backend : `fake_cloud_firestore` (fidélité where/orderBy/limit/startAfter/
// snapshots/count). Injection d'exception : sous-classe `_ThrowingFirestore` qui
// lève une `FirebaseException` à `collection()` (voir plus bas) — `mock_exceptions`
// est structurellement inapplicable au fake (indexé par identité d'objet).
//
// Couverture mappée aux ACs (voir noms de groupes/tests).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

/// Entité de test minimale. `fromMap` **strict** : lève sur `title`/`count`
/// corrompus (permet de prouver le décodage défensif de l'adaptateur).
class _Note extends ZEntity {
  const _Note({
    this.id,
    required this.title,
    required this.count,
    this.tags = const <String>[],
  });

  @override
  final String? id;
  final String title;
  final int count;
  final List<String> tags;

  static _Note fromMap(Map<String, dynamic> map) {
    final title = map['title'];
    final count = map['count'];
    if (title is! String) {
      throw const FormatException('title manquant/invalide');
    }
    if (count is! int) {
      throw const FormatException('count manquant/invalide');
    }
    return _Note(
      id: map['id'] as String?,
      title: title,
      count: count,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'count': count,
        'tags': tags,
      };

  @override
  bool operator ==(Object other) =>
      other is _Note &&
      other.id == id &&
      other.title == title &&
      other.count == count &&
      _listEq(other.tags, tags);

  @override
  int get hashCode => Object.hash(id, title, count, Object.hashAll(tags));

  @override
  String toString() => '_Note(id: $id, title: $title, count: $count)';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const String _kPath = 'notes';

FirebaseZRepositoryImpl<_Note> _repo(FakeFirebaseFirestore fs) =>
    FirebaseZRepositoryImpl<_Note>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'note',
      fromMap: _Note.fromMap,
      toMap: (n) => n.toMap(),
    );

/// Insère un document BRUT (contourne l'encodeur) avec `is_deleted` explicite —
/// nécessaire car l'exclusion serveur repose sur `is_deleted == false`. Le corps
/// porte aussi son `id` logique, **exactement comme l'adaptateur l'écrit** via
/// `save` : c'est la clé du tie-break `orderBy('id')` (AC12).
Future<void> _seedRaw(
  FakeFirebaseFirestore fs,
  String id,
  Map<String, dynamic> body, {
  bool isDeleted = false,
}) =>
    fs.collection(_kPath).doc(id).set(<String, dynamic>{
      ...body,
      'id': id,
      'is_deleted': isDeleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

/// FirebaseFirestore de test qui **lève une `FirebaseException`** sur tout accès
/// `collection(...)`.
///
/// Pourquoi cette approche plutôt que `mock_exceptions` : `fake_cloud_firestore`
/// renvoie une **nouvelle** instance de collection/requête à CHAQUE appel, et
/// `mock_exceptions` indexe ses attentes par **identité d'objet**. Il est donc
/// structurellement impossible d'injecter une exception sur l'objet requête
/// construit EN INTERNE par le repository (le test n'y a aucune référence
/// partagée). On injecte donc la `FirebaseException` à la **frontière d'accès
/// Firestore** — exactement le type d'erreur que `_guard` doit convertir en
/// `Left(ZServerFailure)` sans jamais l'avaler ni la laisser remonter (AC9,
/// bug #3, AD-11).
class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'firestore', code: 'unavailable');
  }
}

void main() {
  group('AC1 — withConverter round-trip', () {
    test('save (éphémère) matérialise un id puis getById restitue l\'égal',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      final saved = await repo.save(
        const _Note(title: 'Alpha', count: 3, tags: <String>['a', 'b']),
      );
      final note = saved.getOrElse(() => fail('save a échoué: $saved'));
      expect(note.id, isNotNull);
      expect(note.isEphemeral, isFalse);

      final fetched = await repo.getById(note.id!);
      expect(
        fetched.getOrElse(() => fail('getById a échoué: $fetched')),
        equals(note),
      );
    });

    test('withConverter typé : lecture directe re-décode fidèlement l\'entité',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final saved = await repo.save(const _Note(title: 'Bravo', count: 7));
      final id = saved.toIterable().first.id!;

      final typed = fs
          .collection(_kPath)
          .withConverter<_Note>(
            fromFirestore: (s, _) =>
                _Note.fromMap(<String, dynamic>{...?s.data(), 'id': s.id}),
            toFirestore: (v, _) => v.toMap(),
          )
          .doc(id);
      final snap = await typed.get();
      expect(snap.data()!.title, 'Bravo');
      expect(snap.data()!.count, 7);
    });
  });

  group('AC2 — streams NUS + exclusion soft-deleted', () {
    test('watchAll émet un seed immédiat (Stream<List<T>> nu)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await repo.save(const _Note(title: 'x', count: 1));

      final first = await repo.watchAll().first;
      expect(first, isA<List<_Note>>());
      expect(first.length, 1);
      repo.dispose();
    });

    test('collection vide émet [] (pas d\'erreur)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final first = await repo.watchAll().first;
      expect(first, isEmpty);
      repo.dispose();
    });

    test('un soft-deleted est exclu des lectures/flux', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final a = (await repo.save(const _Note(title: 'a', count: 1)))
          .toIterable()
          .first;
      await repo.save(const _Note(title: 'b', count: 2));

      await repo.softDelete(a.id!);

      final all = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(all.map((n) => n.title), <String>['b']);
    });
  });

  group('AC6 — traduction ZDataRequest → Query (mapping des ops)', () {
    late FakeFirebaseFirestore fs;
    late FirebaseZRepositoryImpl<_Note> repo;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      repo = _repo(fs);
      await _seedRaw(fs, 'n1', <String, dynamic>{
        'title': 'un',
        'count': 1,
        'tags': <String>['red'],
      });
      await _seedRaw(fs, 'n2', <String, dynamic>{
        'title': 'deux',
        'count': 2,
        'tags': <String>['green'],
      });
      await _seedRaw(fs, 'n3', <String, dynamic>{
        'title': 'trois',
        'count': 3,
        'tags': <String>['red', 'blue'],
      });
    });

    Future<List<String>> titles(ZDataRequest req) async {
      final r = (await repo.getAll(request: req)).getOrElse(() => fail('getAll'));
      return r.map((n) => n.title).toList();
    }

    test('eq', () async {
      expect(
        await titles(const ZDataRequest(
            filters: <ZFilter>[ZFilter('count', ZFilterOp.eq, 2)])),
        <String>['deux'],
      );
    });

    test('gt / gte / lt / lte', () async {
      expect(
        (await titles(const ZDataRequest(
                filters: <ZFilter>[ZFilter('count', ZFilterOp.gt, 1)])))
            .toSet(),
        <String>{'deux', 'trois'},
      );
      expect(
        (await titles(const ZDataRequest(
                filters: <ZFilter>[ZFilter('count', ZFilterOp.lte, 2)])))
            .toSet(),
        <String>{'un', 'deux'},
      );
    });

    test('neq', () async {
      expect(
        (await titles(const ZDataRequest(
                filters: <ZFilter>[ZFilter('count', ZFilterOp.neq, 2)])))
            .toSet(),
        <String>{'un', 'trois'},
      );
    });

    test('isIn (whereIn)', () async {
      expect(
        (await titles(const ZDataRequest(filters: <ZFilter>[
          ZFilter('count', ZFilterOp.isIn, <int>[1, 3])
        ])))
            .toSet(),
        <String>{'un', 'trois'},
      );
    });

    test('contains → arrayContains (appartenance à un champ collection)',
        () async {
      expect(
        (await titles(const ZDataRequest(filters: <ZFilter>[
          ZFilter('tags', ZFilterOp.contains, 'red')
        ])))
            .toSet(),
        <String>{'un', 'trois'},
      );
    });

    test('ZSort desc + tri appliqué', () async {
      expect(
        await titles(const ZDataRequest(
            sorts: <ZSort>[ZSort('count', ZSortDirection.desc)])),
        <String>['trois', 'deux', 'un'],
      );
    });
  });

  group('AC7 — bug #1 corrigé : filtre + tri + limit coexistent (3 clauses)',
      () {
    test('aucune clause perdue par réassignation manquée', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      for (var i = 1; i <= 5; i++) {
        await _seedRaw(fs, 'k$i',
            <String, dynamic>{'title': 't$i', 'count': i});
      }
      // filtre count >= 2 (exclut t1) + tri desc + limit 2 → [t5, t4].
      final req = const ZDataRequest(
        filters: <ZFilter>[ZFilter('count', ZFilterOp.gte, 2)],
        sorts: <ZSort>[ZSort('count', ZSortDirection.desc)],
        limit: 2,
      );
      final r = (await repo.getAll(request: req)).getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.title), <String>['t5', 't4']);
    });
  });

  group('AC4 — count', () {
    test('count applique les filtres et exclut les soft-deleted', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seedRaw(fs, 'c1', <String, dynamic>{'title': 'a', 'count': 1});
      await _seedRaw(fs, 'c2', <String, dynamic>{'title': 'b', 'count': 5});
      await _seedRaw(fs, 'c3', <String, dynamic>{'title': 'c', 'count': 9});
      await _seedRaw(fs, 'c4', <String, dynamic>{'title': 'd', 'count': 9},
          isDeleted: true);

      expect((await repo.count()).getOrElse(() => -1), 3);
      expect(
        (await repo.count(
                request: const ZDataRequest(
                    filters: <ZFilter>[ZFilter('count', ZFilterOp.gte, 5)])))
            .getOrElse(() => -1),
        2,
      );
    });
  });

  group('AC5 — softDelete / restore hors-entité', () {
    test('bascule is_deleted sans toucher aux champs métier + restore', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final n = (await repo.save(const _Note(title: 'métier', count: 42)))
          .toIterable()
          .first;

      final del = await repo.softDelete(n.id!);
      expect(del.isRight(), isTrue);

      final raw = await fs.collection(_kPath).doc(n.id!).get();
      expect(raw.data()!['is_deleted'], isTrue);
      // champs métier intacts
      expect(raw.data()!['title'], 'métier');
      expect(raw.data()!['count'], 42);

      // exclu tant que soft-deleted
      expect((await repo.getById(n.id!)).isLeft(), isTrue);

      final res = await repo.restore(n.id!);
      expect(res.isRight(), isTrue);
      expect((await repo.getById(n.id!)).isRight(), isTrue);
    });

    test('softDelete d\'un id inconnu → Left(ZNotFoundFailure)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final r = await repo.softDelete('inconnu');
      expect(r.isLeft(), isTrue);
      r.leftMap((f) => expect(f, isA<ZNotFoundFailure>()));
    });
  });

  group('AC10 — bug #4 : null ≠ erreur', () {
    test('getById sur id inconnu → Left(ZNotFoundFailure) (jamais exception)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final r = await repo.getById('nope');
      expect(r.isLeft(), isTrue);
      r.leftMap((f) {
        expect(f, isA<ZNotFoundFailure>());
        expect((f as ZNotFoundFailure).id, 'nope');
      });
    });
  });

  group('AC11 — décodage défensif (AD-10)', () {
    test('1 document corrompu parmi N → N-1 sans throw', () async {
      final fs = FakeFirebaseFirestore();
      final logs = <String>[];
      final repo = FirebaseZRepositoryImpl<_Note>(
        firestore: fs,
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
        logger: (m, {error, stackTrace}) => logs.add(m),
      );
      await _seedRaw(fs, 'ok1', <String, dynamic>{'title': 'ok1', 'count': 1});
      // corrompu : count est une String → fromMap lève, doit être écarté
      await _seedRaw(
          fs, 'bad', <String, dynamic>{'title': 'bad', 'count': 'NaN'});
      await _seedRaw(fs, 'ok2', <String, dynamic>{'title': 'ok2', 'count': 2});

      final r = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.title).toSet(), <String>{'ok1', 'ok2'});
      expect(logs, isNotEmpty); // écarté + loggé (jamais avalé silencieusement)
    });

    test('fromMapSafe explicite est utilisé (voie ZModelAdapter)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = FirebaseZRepositoryImpl<_Note>(
        firestore: fs,
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
        fromMapSafe: (m) {
          try {
            return _Note.fromMap(m);
          } on Object {
            return null;
          }
        },
      );
      await _seedRaw(fs, 'ok', <String, dynamic>{'title': 'ok', 'count': 1});
      await _seedRaw(
          fs, 'bad', <String, dynamic>{'title': 42, 'count': 1});
      final r = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.title), <String>['ok']);
    });
  });

  group('AC12 — tie-break id + curseur startAfter (pagination déterministe)',
      () {
    test('deux lignes à clé de tri égale → ordre total stable, sans doublon',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      // même count → départage par id (doc id)
      await _seedRaw(fs, 'idA', <String, dynamic>{'title': 'A', 'count': 5});
      await _seedRaw(fs, 'idB', <String, dynamic>{'title': 'B', 'count': 5});
      await _seedRaw(fs, 'idC', <String, dynamic>{'title': 'C', 'count': 5});

      const sorts = <ZSort>[ZSort('count')];
      final page1 = (await repo.getAll(
        request: const ZDataRequest(sorts: sorts, limit: 2),
      ))
          .getOrElse(() => fail('page1'));
      expect(page1.length, 2);

      // curseur = dernier élément de la page 1 (valeurs de tri + id)
      final last = page1.last;
      final cursor = ZCursor(values: <Object?>[last.count], id: last.id);
      final page2 = (await repo.getAll(
        request: ZDataRequest(sorts: sorts, limit: 2, startAfter: cursor),
      ))
          .getOrElse(() => fail('page2'));

      final ids1 = page1.map((n) => n.id).toSet();
      final ids2 = page2.map((n) => n.id).toSet();
      // aucun doublon à la frontière
      expect(ids1.intersection(ids2), isEmpty);
      // couverture totale des 3 éléments
      expect(ids1.union(ids2).length, 3);
    });
  });

  group('AC9 — bug #3 : FirebaseException → ZServerFailure (jamais avalé)', () {
    test('une FirebaseException pendant getAll devient Left(ZServerFailure)',
        () async {
      final repo = FirebaseZRepositoryImpl<_Note>(
        firestore: _ThrowingFirestore(),
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
      );

      final r = await repo.getAll();
      // Jamais d'exception qui remonte, jamais un Left muet : ZServerFailure typé.
      expect(r.isLeft(), isTrue);
      r.leftMap((f) => expect(f, isA<ZServerFailure>()));
    });
  });

  group('AC3 — getAll sans requête = tout le non-soft-deleted', () {
    test('retourne tous les vivants', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await repo.save(const _Note(title: 'a', count: 1));
      await repo.save(const _Note(title: 'b', count: 2));
      final all = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(all.length, 2);
    });
  });

  group('MAJEUR-1 — tie-break id (option b) : invariant save-écrit-`id`', () {
    // Option (a) `orderBy(FieldPath.documentId)` est PROUVÉE infaisable sur le
    // fake : `startAfter` sur une clé `documentId` lève `Invalid argument(s):
    // key must be String or FieldPath but found FieldPathType`. On retient (b)
    // (champ `id` de corps) sous précondition « collection zcrud-native ». Le
    // fake N'imite PAS l'exclusion prod d'un doc sans corps `id` (il le classe
    // `null`) — un test ne peut donc prouver l'exclusion prod ; il PROUVE
    // l'invariant exécutoire qui la neutralise : tout doc écrit par `save` porte
    // son `id` de corps.
    test('save (éphémère) écrit TOUJOURS le champ `id` de corps == doc.id',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final n = (await repo.save(const _Note(title: 'x', count: 1)))
          .toIterable()
          .first;
      final raw = await fs.collection(_kPath).doc(n.id!).get();
      expect(raw.data()!['id'], equals(n.id),
          reason: 'Invariant tie-break AC12 : le corps porte son id logique.');
    });

    test('save (id fourni) écrit le champ `id` de corps == doc.id', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final n =
          (await repo.save(const _Note(id: 'fixed1', title: 'y', count: 2)))
              .toIterable()
              .first;
      final raw = await fs.collection(_kPath).doc('fixed1').get();
      expect(raw.data()!['id'], 'fixed1');
      expect(n.id, 'fixed1');
    });
  });

  group('MAJEUR-2 — doc SANS `is_deleted` : exclusion COHÉRENTE get/getAll/watch',
      () {
    // Seed DIRECT (contourne _seedRaw) : PAS de champ `is_deleted`. Doit être
    // exclu de façon COHÉRENTE sur les 3 chemins (pas de divergence getById vs
    // getAll/watch).
    Future<void> seedNoSoftDelete(FakeFirebaseFirestore fs, String id) =>
        fs.collection(_kPath).doc(id).set(<String, dynamic>{
          'id': id,
          'title': 'legacy',
          'count': 1,
          // volontairement AUCUN `is_deleted`.
        });

    test('getById exclut (NotFound), getAll exclut, watch exclut — cohérent',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await seedNoSoftDelete(fs, 'legacy1');
      // un doc conforme pour prouver que seul le non-conforme est écarté
      await repo.save(const _Note(id: 'ok1', title: 'ok', count: 9));

      // getById : Left(NotFound) — aligné sur getAll/watch (MAJEUR-2).
      final byId = await repo.getById('legacy1');
      expect(byId.isLeft(), isTrue);
      byId.leftMap((f) => expect(f, isA<ZNotFoundFailure>()));

      // getAll : le legacy est absent, le conforme présent.
      final all = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(all.map((n) => n.id).toSet(), <String>{'ok1'});

      // watch : même exclusion.
      final watched = await repo.watchAll().first;
      expect(watched.map((n) => n.id).toSet(), <String>{'ok1'});
      repo.dispose();

      // le doc conforme, lui, RESTE visible par getById (pas de faux négatif).
      expect((await repo.getById('ok1')).isRight(), isTrue);
    });
  });

  group('MEDIUM-1 — AC9 : erreur SYNCHRONE de flux passe par le canal du stream',
      () {
    test('watch avec Firestore qui throw à collection() → addError, pas de throw',
        () async {
      final repo = FirebaseZRepositoryImpl<_Note>(
        firestore: _ThrowingFirestore(),
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
      );
      // L'appel `watch(...)` NE DOIT PAS lever synchroniquement.
      final stream = repo.watch(const ZDataRequest());
      // L'erreur arrive via le CANAL du stream, typée ZServerFailure (AD-11).
      await expectLater(
        stream,
        emitsError(isA<ZServerFailure>()),
      );
      repo.dispose();
    });

    test('watchAll avec Firestore qui throw à collection() → addError', () async {
      final repo = FirebaseZRepositoryImpl<_Note>(
        firestore: _ThrowingFirestore(),
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
      );
      final stream = repo.watchAll();
      await expectLater(stream, emitsError(isA<ZServerFailure>()));
      repo.dispose();
    });
  });

  group('LOW-2 — mapping ZFilterOp.isNull → where(isNull:true)', () {
    test('isNull ne retient que les docs à champ null', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await fs.collection(_kPath).doc('a').set(<String, dynamic>{
        'id': 'a',
        'title': 'a',
        'count': 1,
        'parent': null,
        'is_deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await fs.collection(_kPath).doc('b').set(<String, dynamic>{
        'id': 'b',
        'title': 'b',
        'count': 2,
        'parent': 'x',
        'is_deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      final r = (await repo.getAll(
        request: const ZDataRequest(
          filters: <ZFilter>[ZFilter('parent', ZFilterOp.isNull, null)],
        ),
      ))
          .getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.id), <String>['a']);
    });
  });

  group('LOW-4 — save = overwrite total qui RESSUSCITE (intentionnel)', () {
    test('re-save d\'une entité soft-deletée la rend de nouveau visible',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final n = (await repo.save(const _Note(id: 'r1', title: 't', count: 1)))
          .toIterable()
          .first;
      await repo.softDelete(n.id!);
      expect((await repo.getById(n.id!)).isLeft(), isTrue); // masqué

      // re-save (même id) → _encode réécrit is_deleted=false → RESSUSCITE.
      await repo.save(const _Note(id: 'r1', title: 't2', count: 5));
      final back = await repo.getById('r1');
      expect(back.isRight(), isTrue);
      final raw = await fs.collection(_kPath).doc('r1').get();
      expect(raw.data()!['is_deleted'], isFalse);
      expect(raw.data()!['title'], 't2');
    });
  });

  group('MEDIUM-2 — AC13/AC14 : isolation AD-5 testée dans la suite', () {
    // AC13 : aucun des 6 types Firestore interdits (Query / CollectionReference /
    // DocumentSnapshot / Timestamp / Filter / FirebaseException) n'apparaît dans
    // une SIGNATURE PUBLIQUE de l'API exportée. Le constructeur expose
    // `FirebaseFirestore` : couture DI VOULUE (hors des 6 types), donc TOLÉRÉE.
    test('AC13 — aucun type cloud_firestore dans une signature publique', () {
      final pkg = _pkgDir();
      // Le barrel ne ré-exporte AUCUN paquet Firebase.
      final barrel =
          File('${pkg.path}/lib/zcrud_firestore.dart').readAsStringSync();
      for (final bad in <String>['cloud_firestore', 'firebase_core']) {
        expect(RegExp("export\\s+'package:$bad").hasMatch(barrel), isFalse,
            reason: 'Le barrel ne doit PAS ré-exporter package:$bad (AD-5).');
      }

      // Les 6 types interdits (bornés par \b) ne doivent apparaître sur AUCUNE
      // ligne de DÉCLARATION DE MEMBRE PUBLIC des fichiers exportés.
      const forbidden = <String>[
        r'\bQuery\b',
        r'\bCollectionReference\b',
        r'\bDocumentReference\b',
        r'\bDocumentSnapshot\b',
        r'\bQuerySnapshot\b',
        r'\bQueryDocumentSnapshot\b',
        r'\bTimestamp\b',
        r'\bFilter\b',
        r'\bFirebaseException\b',
        r'\bFieldPath\b',
        r'\bWriteBatch\b',
      ];
      final forbiddenRe = RegExp(forbidden.join('|'));
      // Une ligne de déclaration de membre public : indentée d'EXACTEMENT 2
      // espaces (membre de classe, `dart format`), nom NON préfixé `_`, suivie
      // d'une `(` (méthode/constructeur) ou d'un `get`. Les corps de méthode
      // (indent >= 4) et les membres privés sont exclus par construction.
      final publicMember = RegExp(
        r'^  (?:@override\s+)?(?:factory\s+|static\s+)?[A-Za-z_][\w<>,.\?\s\[\]]*?\b([A-Za-z][\w]*)\s*(?:\(|=>|\{|get\s)',
      );
      final exported = <String>[
        'lib/src/data/firebase_z_repository_impl.dart',
        'lib/src/data/z_firestore_api.dart',
      ];
      var publicSignatureLinesScanned = 0;
      final offenders = <String>[];
      for (final rel in exported) {
        final lines = File('${pkg.path}/$rel').readAsLinesSync();
        var inBlockComment = false;
        for (final raw in lines) {
          final trimmed = raw.trimLeft();
          if (inBlockComment) {
            if (trimmed.contains('*/')) inBlockComment = false;
            continue;
          }
          if (trimmed.startsWith('/*')) {
            if (!trimmed.contains('*/')) inBlockComment = true;
            continue;
          }
          if (trimmed.startsWith('//') || trimmed.startsWith('/// ') ||
              trimmed.startsWith('///')) {
            continue;
          }
          final m = publicMember.firstMatch(raw);
          if (m == null) continue;
          final name = m.group(1)!;
          if (name.startsWith('_')) continue; // membre privé : hors API publique
          publicSignatureLinesScanned++;
          if (forbiddenRe.hasMatch(raw)) {
            offenders.add(raw.trim());
          }
        }
      }
      // Contrôle POSITIF anti-faux-vert : le scanner a bien vu des signatures
      // publiques (sinon il ne prouverait rien).
      expect(publicSignatureLinesScanned, greaterThan(3),
          reason: 'Le scanner doit avoir capturé des signatures publiques '
              '(getAll/getById/save/...) — sinon FAUX VERT.');
      expect(offenders, isEmpty,
          reason: 'Type Firestore interdit dans une signature publique '
              '(AD-5) :\n${offenders.join('\n')}');
    });

    // AC14 : `zcrud_core` ne déclare AUCUNE dépendance Firebase/Firestore.
    test('AC14 — zcrud_core ne dépend d\'aucun paquet Firebase', () {
      final core = _coreDir();
      final lines = File('${core.path}/pubspec.yaml').readAsLinesSync();
      // Scan des 3 blocs de dépendances (hors commentaires) : aucun `firebase*`
      // ni `cloud_firestore`.
      const depBlocks = <String>[
        'dependencies:',
        'dev_dependencies:',
        'dependency_overrides:',
      ];
      var inDeps = false;
      final offenders = <String>[];
      for (final raw in lines) {
        final noComment = raw.replaceFirst(RegExp(r'#.*$'), '');
        final line = noComment.trimRight();
        if (line.isEmpty) continue;
        if (depBlocks.contains(line.trim())) {
          inDeps = true;
          continue;
        }
        // Nouvelle clé top-level (non indentée) hors bloc deps → sortie de bloc.
        if (RegExp(r'^[A-Za-z_]').hasMatch(line) &&
            !depBlocks.contains(line.trim())) {
          inDeps = false;
          continue;
        }
        if (!inDeps) continue;
        final m = RegExp(r'^\s{2,}([A-Za-z0-9_]+)\s*:').firstMatch(line);
        if (m == null) continue;
        final dep = m.group(1)!;
        if (dep.contains('firebase') || dep.contains('cloud_firestore')) {
          offenders.add(dep);
        }
      }
      expect(offenders, isEmpty,
          reason: 'zcrud_core ne doit dépendre d\'AUCUN paquet Firebase '
              '(AD-1/AD-5). Trouvé : $offenders');
    });
  });

  // Ancrage : Right est bien le sous-type dartz attendu (contrat AD-11).
  test('ZResult = Either<ZFailure,T> (Right côté succès)', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final r = await repo.getAll();
    expect(r, isA<Right<ZFailure, List<_Note>>>());
  });
}

/// Localise le répertoire du package `zcrud_firestore` quel que soit le CWD
/// (racine du workspace ou dossier du package sous `flutter test`).
Directory _pkgDir() {
  for (final base in <String>['', 'packages/zcrud_firestore/']) {
    final dir = Directory(base.isEmpty ? '.' : base);
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/src/data').existsSync()) {
      return dir;
    }
  }
  fail('Répertoire zcrud_firestore introuvable depuis ${Directory.current.path}');
}

/// Localise le répertoire du package `zcrud_core` (lecture SEULE de son pubspec,
/// AC14) quel que soit le CWD.
Directory _coreDir() {
  for (final base in <String>[
    '../zcrud_core',
    'packages/zcrud_core',
    '../../packages/zcrud_core',
  ]) {
    final dir = Directory(base);
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
  }
  fail('Répertoire zcrud_core introuvable depuis ${Directory.current.path}');
}
