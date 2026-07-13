// DP-11 (gap B14) : hint de persistance `timestamp` consommé par
// `FirebaseZRepositoryImpl` via le param neutre `timestampFields` (Set<String>).
//
// Prouve : (a) écriture ISO→Timestamp natif sur disque pour les clés hintées ;
// (b) round-trip getById restitue l'entité (ISO d'origine) ; (c) SANS hint le
// champ reste String ISO (rétro-compat AC7) ; (d) lecture bi-format d'un doc
// pré-existant stocké en String ISO ; (e) valeur null → null ; (f) `updated_at`
// (ZSyncMeta) reste String ISO même avec une clé d'entité hintée (AC8) ; (g)
// confinement AD-5 (grep `Timestamp` hors `lib/src/data`).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

/// Entité minimale avec un champ date sérialisé en **String ISO-8601** (comme le
/// code généré) — cible de la conversion `Timestamp` du hint B14.
class _Event extends ZEntity {
  const _Event({this.id, required this.title, this.createdAt});

  @override
  final String? id;
  final String title;
  final DateTime? createdAt;

  static _Event fromMap(Map<String, dynamic> map) => _Event(
        id: map['id'] as String?,
        title: (map['title'] as String?) ?? '',
        createdAt: map['created_at'] is String
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is _Event &&
      other.id == id &&
      other.title == title &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, title, createdAt);
}

const String _kPath = 'events';
const Set<String> _kTsFields = <String>{'created_at'};

FirebaseZRepositoryImpl<_Event> _repo(
  FakeFirebaseFirestore fs, {
  Set<String> timestampFields = const <String>{},
}) =>
    FirebaseZRepositoryImpl<_Event>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'event',
      fromMap: _Event.fromMap,
      toMap: (e) => e.toMap(),
      timestampFields: timestampFields,
    );

Future<Map<String, dynamic>> _rawDoc(FakeFirebaseFirestore fs, String id) async {
  final snap = await fs.collection(_kPath).doc(id).get();
  return snap.data() ?? <String, dynamic>{};
}

void main() {
  group('DP-11 — hint timestamp (AC4/AC5/AC6/AC7/AC8)', () {
    test('AC4 — save écrit un Timestamp natif sur disque pour la clé hintée',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      final at = DateTime.utc(2026, 7, 9, 10, 30);

      final saved =
          await repo.save(const _Event(id: 'e1', title: 'T').copyWithAt(at));
      expect(saved.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'e1');
      expect(raw['created_at'], isA<Timestamp>()); // format disque = Timestamp
      expect((raw['created_at'] as Timestamp).toDate().toUtc(), at);
    });

    test('MAJEUR-1 — writeMerged (voie sync/merge) écrit AUSSI un Timestamp natif',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      final at = DateTime.utc(2026, 7, 9, 10, 30);
      final entry = ZSyncEntry<_Event>(
        entity: const _Event(id: 'e1', title: 'T').copyWithAt(at),
        meta: ZSyncMeta(updatedAt: DateTime.utc(2026, 7, 10), isDeleted: false),
      );

      final res = await repo.writeMerged(entry);
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'e1');
      // Format disque UNIFORME avec la voie save (plus de String ISO mixte).
      expect(raw['created_at'], isA<Timestamp>());
      expect((raw['created_at'] as Timestamp).toDate().toUtc(), at);
      // ZSyncMeta jamais convertie (LWW intact).
      expect(raw['updated_at'], isA<String>());
      expect(raw['is_deleted'], isFalse);
    });

    test('AC5 — getById round-trip restitue le DateTime d\'origine', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      final at = DateTime.utc(2026, 7, 9, 10, 30);

      await repo.save(const _Event(id: 'e1', title: 'T').copyWithAt(at));
      final got = await repo.getById('e1');
      expect(got.isRight(), isTrue);
      got.fold((_) => fail('gauche'), (e) => expect(e.createdAt, at));
    });

    test('AC7 — SANS timestampFields, le champ reste String ISO (rétro-compat)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs); // aucun hint
      final at = DateTime.utc(2026, 7, 9, 10, 30);

      await repo.save(const _Event(id: 'e1', title: 'T').copyWithAt(at));
      final raw = await _rawDoc(fs, 'e1');
      expect(raw['created_at'], isA<String>());
      expect(raw['created_at'], '2026-07-09T10:30:00.000Z');
    });

    test('AC5 — lecture bi-format : doc pré-existant en String ISO décodé sans '
        'perte', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      // Doc hérité : `created_at` stocké en String ISO (pas Timestamp).
      await fs.collection(_kPath).doc('e2').set(<String, dynamic>{
        'id': 'e2',
        'title': 'legacy',
        'created_at': '2026-07-09T10:30:00.000Z',
        'is_deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final got = await repo.getById('e2');
      got.fold(
        (_) => fail('gauche'),
        (e) => expect(e.createdAt, DateTime.utc(2026, 7, 9, 10, 30)),
      );
    });

    test('AC4 — valeur null reste null (défensif, aucun throw)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);

      await repo.save(const _Event(id: 'e3', title: 'sans date'));
      final raw = await _rawDoc(fs, 'e3');
      expect(raw['created_at'], isNull);

      final got = await repo.getById('e3');
      got.fold((_) => fail('gauche'), (e) => expect(e.createdAt, isNull));
    });

    test('AC8 — updated_at (ZSyncMeta) reste String ISO malgré la clé hintée',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      await repo
          .save(const _Event(id: 'e1', title: 'T').copyWithAt(DateTime.utc(2026)));

      final raw = await _rawDoc(fs, 'e1');
      expect(raw['updated_at'], isA<String>()); // jamais Timestamp (LWW ISO)
      expect(raw['is_deleted'], isFalse);
      expect(raw['created_at'], isA<Timestamp>()); // clé d'entité, elle, convertie
    });

    test('AC5 — watch émet une entité décodée depuis un Timestamp sur disque',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      final at = DateTime.utc(2026, 7, 9, 10, 30);
      await repo.save(const _Event(id: 'e1', title: 'T').copyWithAt(at));

      final first = await repo.watchAll().first;
      expect(first.single.createdAt, at);
      repo.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AD-19 / ES-1.3 — findings M2 + M3 du code-review.
  //
  // Le test STAR du kernel prouve que la méta PRIME sur le miroir. Il ne prouve
  // PAS qu'elle SURVIT au décodage. Ces tests ferment ce trou : une méta
  // NEUTRALISÉE à `null` fait dégénérer le merge LWW en « le local gagne
  // toujours » (écritures distantes perdues, silencieusement, sans test rouge).
  //
  // Deux vecteurs de neutralisation :
  //  - M3 : un document LEGACY (DODLP) porte `updated_at` en `Timestamp` natif ;
  //  - M2 : un dev annote `updated_at` en `persistAs: timestamp` (gap B14).
  // ───────────────────────────────────────────────────────────────────────────
  group('AD-19 (M3) — la méta SURVIT au décodage d\'un document LEGACY', () {
    test(
        'syncEntriesAll : `updated_at` en Timestamp natif ⇒ ZSyncMeta.updatedAt '
        'PEUPLÉE (la clé d\'autorité du merge n\'est PAS perdue)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs); // aucun hint : cas DODLP « pur legacy »
      final at = DateTime.utc(2026, 3, 1, 12);

      // Document réellement écrit par DODLP : toutes les dates en `Timestamp`
      // natif, `updated_at` COMPRIS (zcrud, lui, écrit de l'ISO-8601).
      await fs.collection(_kPath).doc('legacy').set(<String, dynamic>{
        'id': 'legacy',
        'title': 'doc DODLP',
        'created_at': Timestamp.fromDate(DateTime.utc(2026)),
        'updated_at': Timestamp.fromDate(at), // ← clé d'AUTORITÉ du merge
        'is_deleted': false,
      });

      final res = await repo.syncEntriesAll();
      expect(res.isRight(), isTrue);
      res.fold((f) => fail('gauche: $f'), (entries) {
        final entry = entries.single;
        expect(
          entry.meta.updatedAt,
          isNotNull,
          reason: 'AVANT la correction M3, `_parseIso(Timestamp)` renvoyait '
              '`null` : la clé LWW était PERDUE sur TOUTE la donnée legacy ⇒ '
              'ZLwwResolver dégénérait en « le local gagne toujours ».',
        );
        expect(entry.meta.updatedAt, at);
        expect(entry.meta.isDeleted, isFalse);
        // `ZSyncEntry.updatedAt` est DÉRIVÉ de la méta : c'est l'autorité.
        expect(entry.updatedAt, at);
      });
    });

    test(
        'le LWW ne DÉGÉNÈRE PAS : le distant legacy (Timestamp 2026) bat un '
        'local daté 2020 (avant M3, le local gagnait toujours)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final remoteAt = DateTime.utc(2026, 3, 1, 12);

      await fs.collection(_kPath).doc('legacy').set(<String, dynamic>{
        'id': 'legacy',
        'title': 'version DISTANTE (la plus récente)',
        'updated_at': Timestamp.fromDate(remoteAt),
        'is_deleted': false,
      });

      final pulled = await repo.syncEntriesAll();
      final remote = pulled.fold<List<ZSyncEntry<_Event>>>(
        (f) => fail('gauche: $f'),
        (entries) => entries,
      ).single;

      final local = ZSyncEntry<_Event>(
        entity: const _Event(id: 'legacy', title: 'version LOCALE (périmée)'),
        meta: ZSyncMeta(updatedAt: DateTime.utc(2020), isDeleted: false),
      );

      const resolver = ZLwwResolver();
      final decision = resolver.resolve<_Event>(local, remote);

      expect(
        decision.action,
        ZLwwAction.adoptRemoteIntoLocal,
        reason: 'Méta distante `null` (bug M3) ⇒ « jamais synchronisé » ⇒ le '
            'LOCAL aurait gagné et l\'écriture distante 2026 aurait été '
            'ÉCRASÉE. La méta doit survivre au décodage.',
      );
      expect(decision.entry!.entity.title, 'version DISTANTE (la plus récente)');
    });

    test(
        'forme SÉRIALISÉE d\'un Timestamp ({_seconds,_nanoseconds}) ⇒ méta '
        'peuplée aussi (export/REST, cache JSON)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final at = DateTime.utc(2026, 3, 1, 12);

      await fs.collection(_kPath).doc('rest').set(<String, dynamic>{
        'id': 'rest',
        'title': 'export REST',
        'updated_at': <String, dynamic>{
          '_seconds': at.millisecondsSinceEpoch ~/ 1000,
          '_nanoseconds': 0,
        },
        'is_deleted': false,
      });

      final res = await repo.syncEntriesAll();
      res.fold(
        (f) => fail('gauche: $f'),
        (entries) => expect(entries.single.meta.updatedAt, at),
      );
    });

    test(
        'rétro-compat : un `updated_at` déjà en String ISO reste décodé à '
        'l\'identique (tolérance bi-format, AD-10)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      final at = DateTime.utc(2026, 3, 1, 12);

      await repo.save(const _Event(id: 'e1', title: 'zcrud-native'));
      final raw = await _rawDoc(fs, 'e1');
      expect(raw['updated_at'], isA<String>()); // écriture zcrud = ISO

      await fs.collection(_kPath).doc('e2').set(<String, dynamic>{
        'id': 'e2',
        'title': 'iso',
        'updated_at': at.toIso8601String(),
        'is_deleted': false,
      });

      final res = await repo.syncEntriesAll();
      res.fold((f) => fail('gauche: $f'), (entries) {
        final iso = entries.firstWhere((e) => e.entity.id == 'e2');
        expect(iso.meta.updatedAt, at);
      });
    });

    test('valeur corrompue (`updated_at: 42`) ⇒ méta null, AUCUN throw (AD-10)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      await fs.collection(_kPath).doc('bad').set(<String, dynamic>{
        'id': 'bad',
        'title': 'corrompu',
        'updated_at': 42,
        'is_deleted': false,
      });

      final res = await repo.syncEntriesAll();
      res.fold((f) => fail('gauche: $f'), (entries) {
        expect(entries.single.meta.updatedAt, isNull);
        expect(entries.single.entity.title, 'corrompu');
      });
    });
  });

  group('AD-19 (M2) — une clé RÉSERVÉE ne peut pas être hintée `timestamp`', () {
    test(
        'timestampFields ∩ ZSyncMeta.reservedKeys ≠ {} ⇒ AssertionError '
        '(garde MACHINE, plus une convention en commentaire)', () {
      final fs = FakeFirebaseFirestore();

      expect(
        () => _repo(fs, timestampFields: <String>{'created_at', 'updated_at'}),
        throwsA(isA<AssertionError>()),
        reason: 'Hinter `updated_at` en Timestamp natif NEUTRALISERAIT la clé '
            'LWW au décodage ⇒ merge dégénéré. Interdit par AD-19.1.',
      );
      expect(
        () => _repo(fs, timestampFields: <String>{'is_deleted'}),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
        'un hint LÉGITIME (clé de corps) reste accepté et opérant (aucune '
        'régression B14)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, timestampFields: _kTsFields);
      final at = DateTime.utc(2026, 7, 9, 10, 30);

      await repo.save(const _Event(id: 'e1', title: 'T').copyWithAt(at));
      final raw = await _rawDoc(fs, 'e1');
      expect(raw['created_at'], isA<Timestamp>());
      expect(raw['updated_at'], isA<String>()); // la méta reste ISO (AD-9)
    });
  });

  group('DP-11 — confinement AD-5 (AC6)', () {
    test('`Timestamp` absent hors zcrud_firestore/lib/src/data', () {
      // Localise la racine du package quel que soit le CWD.
      Directory pkg() {
        for (final base in <String>['', 'packages/zcrud_firestore/']) {
          final d = Directory(base.isEmpty ? '.' : base);
          if (File('${d.path}/pubspec.yaml').existsSync() &&
              Directory('${d.path}/lib/src/data').existsSync()) {
            return d;
          }
        }
        fail('Racine zcrud_firestore introuvable depuis ${Directory.current.path}');
      }

      final libDir = Directory('${pkg().path}/lib');
      final offenders = <String>[];
      for (final ent in libDir.listSync(recursive: true, followLinks: false)) {
        if (ent is! File || !ent.path.endsWith('.dart')) continue;
        // Seul `lib/src/data/**` a le droit de mentionner Timestamp.
        if (ent.path.contains('${Platform.pathSeparator}src'
            '${Platform.pathSeparator}data${Platform.pathSeparator}')) {
          continue;
        }
        if (ent.readAsStringSync().contains('Timestamp')) {
          offenders.add(ent.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Timestamp doit rester confiné à lib/src/data (AD-5) : '
              '${offenders.join(', ')}');
    });
  });
}

/// Helper local : `_Event` étant `const` sans `copyWith` généré, on fournit une
/// petite fabrique pour fixer `createdAt` sans alourdir le modèle de test.
extension on _Event {
  _Event copyWithAt(DateTime at) =>
      _Event(id: id, title: title, createdAt: at);
}
