// Tests E5-3 : patron offline-first LWW + soft-delete + `ZSyncMeta`.
//
// - Store LOCAL = `HiveZLocalStore` réel (tmpdir) ; store DISTANT =
//   `FirestoreZRemoteStore` réel sur `fake_cloud_firestore`. Les seeds à
//   `updated_at` PRÉCIS passent par `applyMerged`/`writeMerged` (écriture
//   verbatim) — jamais un seed « propre » qui masque la sémantique LWW.
// - Injection d'échec distant : `_ThrowingFirestore` (FirebaseException →
//   ServerFailure) ; comptage de lots : `_CountingFirestore` (override `batch()`).
//
// Couvre : syncEntries tombstones (AC3), applyMerged anti-now() (AC4), lectures
// local + getById soft-deleté→NotFound (AC8), write offline réussit (AC9), sync()
// 5 cas de convergence dont tombstones (AC10), Right(unit) offline vs
// Left(CacheFailure) local (AC11), 451→2 lots atomiques (AC12), soft-delete
// bout-en-bout (AC13), isolation signatures (AC14).
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

class _Note extends ZEntity {
  const _Note({this.id, required this.title, required this.count});

  @override
  final String? id;
  final String title;
  final int count;

  static _Note fromMap(Map<String, dynamic> map) {
    final title = map['title'];
    final count = map['count'];
    if (title is! String) throw const FormatException('title');
    if (count is! int) throw const FormatException('count');
    return _Note(id: map['id'] as String?, title: title, count: count);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      other is _Note &&
      other.id == id &&
      other.title == title &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, title, count);

  @override
  String toString() => '_Note($id, $title, $count)';
}

const String _kPath = 'notes';

FirebaseZRepositoryImpl<_Note> _repoImpl(FirebaseFirestore fs) =>
    FirebaseZRepositoryImpl<_Note>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'note',
      fromMap: _Note.fromMap,
      toMap: (n) => n.toMap(),
    );

FirestoreZRemoteStore<_Note> _remoteStore(FirebaseFirestore fs) =>
    FirestoreZRemoteStore<_Note>(repository: _repoImpl(fs));

/// FirebaseFirestore de test qui **lève** sur tout accès `collection()`
/// (FirebaseException → ServerFailure). Miroir E5-1.
class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'firestore', code: 'unavailable');
  }
}

/// FirebaseFirestore de test qui **compte** les `WriteBatch` créés (prouve le
/// découpage ≤ 450 par lot, AC12).
class _CountingFirestore extends FakeFirebaseFirestore {
  int batches = 0;

  @override
  WriteBatch batch() {
    batches++;
    return super.batch();
  }
}

/// Décorateur de [ZRemoteStore] qui **retarde `push`** derrière une « porte »
/// ([_gate]) : prouve que `save()` est **fire-and-forget** (MAJEUR-1) — il rend
/// la main AVANT que la propagation distante se termine. Les autres méthodes
/// délèguent au store réel.
class _SlowRemote<T extends ZEntity> implements ZRemoteStore<T> {
  _SlowRemote(this._inner, this._gate);

  final ZRemoteStore<T> _inner;
  final Completer<void> _gate;
  bool pushCompleted = false;

  @override
  Future<ZResult<T>> push(T item) async {
    await _gate.future; // bloque tant que le test n'ouvre pas la porte
    pushCompleted = true;
    return _inner.push(item);
  }

  @override
  Future<ZResult<Unit>> remoteDelete(String id) => _inner.remoteDelete(id);

  @override
  Future<ZResult<List<T>>> pull({ZDataRequest? request}) =>
      _inner.pull(request: request);

  @override
  Stream<List<T>> watchAll() => _inner.watchAll();

  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() => _inner.syncEntries();

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) =>
      _inner.applyMerged(entry);

  @override
  Future<ZResult<Unit>> applyMergedAll(List<ZSyncEntry<T>> entries) =>
      _inner.applyMergedAll(entries);

  @override
  void dispose() => _inner.dispose();
}

ZSyncEntry<_Note> _entry(
  String id,
  String title,
  int count,
  DateTime at, {
  bool deleted = false,
}) =>
    ZSyncEntry<_Note>(
      entity: _Note(id: id, title: title, count: count),
      meta: ZSyncMeta(updatedAt: at, isDeleted: deleted),
    );

void main() {
  late Directory tmp;
  var boxSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('offline_first_test');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<HiveZLocalStore<_Note>> localStore() async {
    final box = await Hive.openBox<dynamic>('notes_${boxSeq++}');
    var n = 0;
    return HiveZLocalStore<_Note>(
      box: box,
      kind: 'note',
      fromMap: _Note.fromMap,
      toMap: (x) => x.toMap(),
      idFactory: () => 'eph${(++n).toString().padLeft(3, '0')}',
    );
  }

  // ───────────────────────── AC3 — syncEntries inclut les tombstones ──────────

  group('AC3 — syncEntries() inclut les tombstones + méta (local & distant)',
      () {
    test('Hive: N entrées dont soft-deletées → toutes rendues avec leur méta',
        () async {
      final local = await localStore();
      await local.applyMerged(_entry('a', 'A', 1, DateTime.utc(2026, 1, 1)));
      await local.applyMerged(
          _entry('b', 'B', 2, DateTime.utc(2026, 2, 1), deleted: true));

      final entries =
          (await local.syncEntries()).getOrElse(() => fail('syncEntries'));
      expect(entries.map((e) => e.id), <String>['a', 'b']);
      final b = entries.firstWhere((e) => e.id == 'b');
      expect(b.isDeleted, isTrue, reason: 'le tombstone est inclus (≠ getAll)');
      expect(b.updatedAt, DateTime.utc(2026, 2, 1));

      // getAll (visible) EXCLUT le tombstone → contraste prouvé.
      final visible = (await local.getAll()).getOrElse(() => fail('getAll'));
      expect(visible.map((e) => e.id), <String>['a']);
      local.dispose();
    });

    test('Firestore: syncEntries inclut le tombstone (≠ pull)', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remoteStore(fs);
      await remote.applyMerged(_entry('a', 'A', 1, DateTime.utc(2026, 1, 1)));
      await remote.applyMerged(
          _entry('b', 'B', 2, DateTime.utc(2026, 2, 1), deleted: true));

      final entries =
          (await remote.syncEntries()).getOrElse(() => fail('syncEntries'));
      expect(entries.map((e) => e.id).toSet(), <String>{'a', 'b'});
      expect(entries.firstWhere((e) => e.id == 'b').isDeleted, isTrue);

      final pulled = (await remote.pull()).getOrElse(() => fail('pull'));
      expect(pulled.map((e) => e.id), <String>['a']);
      remote.dispose();
    });

    test('Hive: 1 corrompu parmi N → N-1 sans throw (défensif AD-10)', () async {
      final box = await Hive.openBox<dynamic>('notes_corrupt');
      final local = HiveZLocalStore<_Note>(
        box: box,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (x) => x.toMap(),
      );
      await local.applyMerged(_entry('ok', 'OK', 1, DateTime.utc(2026, 1, 1)));
      // Corrompt une entrée brute directement (count non-int → fromMap lève).
      await box.put('bad', '{"id":"bad","title":"x","count":"NaN",'
          '"is_deleted":false,"updated_at":"2026-01-01T00:00:00.000Z"}');

      final entries =
          (await local.syncEntries()).getOrElse(() => fail('syncEntries'));
      expect(entries.map((e) => e.id), <String>['ok'],
          reason: 'le corrompu est écarté, jamais un throw');
      local.dispose();
    });
  });

  // ───────────────────────── AC4 — applyMerged préserve la méta (anti-now) ────

  group('AC4/anti-ping-pong — applyMerged écrit la méta VERBATIM (jamais now())',
      () {
    test('Hive: updated_at préservé + corps id + tombstone', () async {
      final local = await localStore();
      final t = DateTime.utc(2025, 3, 3, 9);
      await local
          .applyMerged(_entry('x', 'métier', 7, t, deleted: true));

      final entries =
          (await local.syncEntries()).getOrElse(() => fail('syncEntries'));
      final e = entries.single;
      expect(e.updatedAt, t, reason: 'pas de dérive vers now()');
      expect(e.isDeleted, isTrue);
      expect(e.entity, const _Note(id: 'x', title: 'métier', count: 7),
          reason: 'corps id + champs métier intacts');
      local.dispose();
    });

    test('Firestore: updated_at préservé (verbatim) + tombstone', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remoteStore(fs);
      final t = DateTime.utc(2025, 5, 5, 8);
      await remote.applyMerged(_entry('x', 'y', 3, t, deleted: true));

      final raw = await fs.collection(_kPath).doc('x').get();
      expect(raw.data()!['updated_at'], t.toIso8601String());
      expect(raw.data()!['is_deleted'], isTrue);
      expect(raw.data()!['title'], 'y');
      remote.dispose();
    });
  });

  // ───────────────────────── AC12 — lot borné ≤ 450 ──────────────────────────

  group('AC12 — propagation distante bornée ≤ 450 écritures/lot', () {
    test('451 entrées → 2 lots (450 + 1), chacun committé', () async {
      final fs = _CountingFirestore();
      final remote = _remoteStore(fs);
      final entries = <ZSyncEntry<_Note>>[
        for (var i = 0; i < 451; i++)
          _entry('n${i.toString().padLeft(4, '0')}', 't$i', i,
              DateTime.utc(2026, 1, 1)),
      ];

      final res = await remote.applyMergedAll(entries);
      expect(res.isRight(), isTrue);
      expect(fs.batches, 2, reason: '450 + 1 → 2 WriteBatch');

      // Les 451 documents sont bien committés (aucune écriture partielle).
      final all = (await remote.syncEntries()).getOrElse(() => fail('sync'));
      expect(all.length, 451);
      remote.dispose();
    });

    test('liste vide → Right(unit), 0 lot', () async {
      final fs = _CountingFirestore();
      final remote = _remoteStore(fs);
      final res = await remote.applyMergedAll(<ZSyncEntry<_Note>>[]);
      expect(res.isRight(), isTrue);
      expect(fs.batches, 0);
      remote.dispose();
    });
  });

  // ───────────────────────── AC8 — lectures = LOCAL source de vérité ──────────

  group('AC8 — lectures délèguent au LOCAL ; soft-deleté → NotFound', () {
    test('getById soft-deleté → NotFound ; getAll/watchAll excluent', () async {
      final local = await localStore();
      final fs = FakeFirebaseFirestore();
      final repo = ZOfflineFirstRepository<_Note>(
        local: local,
        remote: _remoteStore(fs),
      );
      await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      await repo.save(const _Note(id: 'b', title: 'B', count: 2));
      await repo.softDelete('a');

      final byId = await repo.getById('a');
      expect(byId.isLeft(), isTrue);
      byId.leftMap((f) => expect(f, isA<NotFoundFailure>()));

      final all = (await repo.getAll()).getOrElse(() => fail('getAll'));
      expect(all.map((n) => n.id), <String>['b']);
      final watched = await repo.watchAll().first;
      expect(watched.map((n) => n.id), <String>['b']);
      expect((await repo.count()).getOrElse(() => -1), 1);
      repo.dispose();
    });
  });

  // ───────────────────────── AC9 — écriture LOCAL-first, distant offline ──────

  group('AC9 — write HORS-LIGNE réussit (Right) + lisible localement', () {
    test('save/softDelete réussissent même si le distant échoue (ServerFailure)',
        () async {
      final local = await localStore();
      // Distant qui échoue systématiquement (offline simulé).
      final repo = ZOfflineFirstRepository<_Note>(
        local: local,
        remote: _remoteStore(_ThrowingFirestore()),
      );

      final saved = await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      expect(saved.isRight(), isTrue,
          reason: 'échec distant n\'invalide PAS le succès local (AD-9)');

      // Lisible localement immédiatement.
      final back = (await repo.getById('a')).getOrElse(() => fail('getById'));
      expect(back.title, 'A');

      final del = await repo.softDelete('a');
      expect(del.isRight(), isTrue);
      expect((await repo.getById('a')).isLeft(), isTrue);
      repo.dispose();
    });

    test(
        'MAJEUR-1 — save() rend la main AVANT la fin de la propagation distante '
        '(fire-and-forget non bloquant, AD-9)', () async {
      final local = await localStore();
      final gate = Completer<void>();
      final slow = _SlowRemote<_Note>(_remoteStore(FakeFirebaseFirestore()), gate);
      final repo = ZOfflineFirstRepository<_Note>(local: local, remote: slow);

      // La porte distante est FERMÉE : si save() attendait le push, il ne
      // rendrait jamais la main ici.
      final saved = await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      expect(saved.isRight(), isTrue);
      expect(slow.pushCompleted, isFalse,
          reason: 'save() ne doit PAS attendre la propagation distante');

      // Ouvre la porte : la propagation best-effort s'achève ensuite.
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(slow.pushCompleted, isTrue,
          reason: 'la propagation distante a bien lieu, mais APRÈS le retour');
      repo.dispose();
    });
  });

  // ───────────────────────── AC10 — sync() convergence (5 cas) ────────────────

  group('AC10 — sync() : pull one-shot + merge LWW (tombstones inclus)', () {
    test('5 cas de convergence en un seul sync()', () async {
      final local = await localStore();
      final fs = FakeFirebaseFirestore();
      final remote = _remoteStore(fs);
      final repo =
          ZOfflineFirstRepository<_Note>(local: local, remote: remote);

      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 6, 1);

      // (i) distant plus récent → adopté localement.
      await local.applyMerged(_entry('i', 'local-i', 1, older));
      await remote.applyMerged(_entry('i', 'remote-i', 1, newer));
      // (ii) local plus récent → poussé au distant.
      await local.applyMerged(_entry('ii', 'local-ii', 2, newer));
      await remote.applyMerged(_entry('ii', 'remote-ii', 2, older));
      // (iii) tombstone distant plus récent → soft-deleté localement.
      await local.applyMerged(_entry('iii', 'x', 3, older));
      await remote.applyMerged(_entry('iii', 'x', 3, newer, deleted: true));
      // (iv) tombstone local plus récent → propagé au distant.
      await local.applyMerged(_entry('iv', 'y', 4, newer, deleted: true));
      await remote.applyMerged(_entry('iv', 'y', 4, older));
      // (v) égal + états identiques → noop (pas de ping-pong).
      await local.applyMerged(_entry('v', 'same', 5, older));
      await remote.applyMerged(_entry('v', 'same', 5, older));

      final res = await repo.sync();
      expect(res.isRight(), isTrue);

      final localAfter =
          (await local.syncEntries()).getOrElse(() => fail('local'));
      final remoteAfter =
          (await remote.syncEntries()).getOrElse(() => fail('remote'));
      _Note localById(String id) =>
          localAfter.firstWhere((e) => e.id == id).entity;
      ZSyncEntry<_Note> lEntry(String id) =>
          localAfter.firstWhere((e) => e.id == id);
      ZSyncEntry<_Note> rEntry(String id) =>
          remoteAfter.firstWhere((e) => e.id == id);

      // (i) local a adopté le corps distant + son updated_at (anti-now()).
      expect(localById('i').title, 'remote-i');
      expect(lEntry('i').updatedAt, newer, reason: 'méta distante préservée');
      // (ii) distant a reçu le gagnant local + son updated_at.
      expect(rEntry('ii').entity.title, 'local-ii');
      expect(rEntry('ii').updatedAt, newer);
      // (iii) l'entité disparaît des lectures visibles locales.
      expect(lEntry('iii').isDeleted, isTrue);
      expect((await repo.getById('iii')).isLeft(), isTrue);
      // (iv) le tombstone local est propagé au distant.
      expect(rEntry('iv').isDeleted, isTrue);
      // (v) noop : updated_at inchangé des deux côtés (pas de now()).
      expect(lEntry('v').updatedAt, older);
      expect(rEntry('v').updatedAt, older);

      repo.dispose();
    });
  });

  // ───────────────────────── AC11 — Right(unit) offline vs Left local ─────────

  group('AC11 — sync() : offline → Right(unit) ; panne locale → Left', () {
    test('remote ServerFailure (syncEntries) → Right(unit)', () async {
      final local = await localStore();
      await local.applyMerged(_entry('a', 'A', 1, DateTime.utc(2026, 1, 1)));
      final repo = ZOfflineFirstRepository<_Note>(
        local: local,
        remote: _remoteStore(_ThrowingFirestore()),
      );
      final res = await repo.sync();
      expect(res.isRight(), isTrue, reason: 'distant injoignable = offline');
      repo.dispose();
    });

    test('isConnected == false → court-circuit Right(unit) (pas d\'accès réseau)',
        () async {
      final local = await localStore();
      final repo = ZOfflineFirstRepository<_Note>(
        local: local,
        // Ce distant lèverait s'il était touché — prouve le court-circuit.
        remote: _remoteStore(_ThrowingFirestore()),
        isConnected: () async => false,
      );
      final res = await repo.sync();
      expect(res.isRight(), isTrue);
      repo.dispose();
    });

    test('erreur LOCALE (box fermée) → Left(CacheFailure) (jamais avalée)',
        () async {
      final box = await Hive.openBox<dynamic>('notes_local_fail');
      final local = HiveZLocalStore<_Note>(
        box: box,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (x) => x.toMap(),
      );
      final repo = ZOfflineFirstRepository<_Note>(
        local: local,
        remote: _remoteStore(FakeFirebaseFirestore()),
      );
      await box.close(); // toute lecture locale → HiveError → CacheFailure

      final res = await repo.sync();
      expect(res.isLeft(), isTrue);
      res.leftMap((f) => expect(f, isA<CacheFailure>()));
      repo.dispose();
    });
  });

  // ───────────────────────── AC13 — soft-delete bout-en-bout ──────────────────

  group('AC13 — soft-delete hors-entité conservé bout-en-bout', () {
    test('soft-delete puis merge : corps intact, seul is_deleted/updated_at bouge',
        () async {
      final local = await localStore();
      final fs = FakeFirebaseFirestore();
      final remote = _remoteStore(fs);
      final repo =
          ZOfflineFirstRepository<_Note>(local: local, remote: remote);

      // Tombstone distant plus récent que le local vivant → adopté localement.
      await local.applyMerged(
          _entry('a', 'métier', 42, DateTime.utc(2026, 1, 1)));
      await remote.applyMerged(_entry('a', 'métier', 42,
          DateTime.utc(2026, 2, 1),
          deleted: true));

      await repo.sync();

      final e = (await local.syncEntries())
          .getOrElse(() => fail('sync'))
          .single;
      expect(e.isDeleted, isTrue);
      expect(e.entity, const _Note(id: 'a', title: 'métier', count: 42),
          reason: 'aucun champ métier touché par le soft-delete');
      expect(e.updatedAt, DateTime.utc(2026, 2, 1),
          reason: 'seule la méta a bougé (verbatim, jamais now())');
      repo.dispose();
    });
  });

  // ───────────────────────── AC14 — isolation signatures (AD-5) ───────────────

  group('AC14 — aucun type backend dans une signature publique du dépôt', () {
    test('z_offline_first_repository.dart : aucun symbole hive/cloud_firestore',
        () {
      final pkg = _pkgDir();
      final src = File(
              '${pkg.path}/lib/src/data/z_offline_first_repository.dart')
          .readAsStringSync();
      // Le fichier n'importe AUCUN backend.
      expect(src.contains('package:cloud_firestore'), isFalse);
      expect(src.contains('package:hive'), isFalse);
      expect(src.contains('package:firebase_core'), isFalse);

      const forbidden = <String>[
        r'\bBox\b',
        r'\bHiveObject\b',
        r'\bHiveError\b',
        r'\bQuery\b',
        r'\bCollectionReference\b',
        r'\bDocumentSnapshot\b',
        r'\bTimestamp\b',
        r'\bFilter\b',
        r'\bWriteBatch\b',
        r'\bFirebaseException\b',
      ];
      final forbiddenRe = RegExp(forbidden.join('|'));
      final publicMember = RegExp(
        r'^  (?:@override\s+)?(?:factory\s+|static\s+)?[A-Za-z_][\w<>,.\?\s\[\]]*?\b([A-Za-z][\w]*)\s*(?:\(|=>|\{|get\s)',
      );
      var scanned = 0;
      final offenders = <String>[];
      var inBlockComment = false;
      for (final raw in src.split('\n')) {
        final trimmed = raw.trimLeft();
        if (inBlockComment) {
          if (trimmed.contains('*/')) inBlockComment = false;
          continue;
        }
        if (trimmed.startsWith('/*')) {
          if (!trimmed.contains('*/')) inBlockComment = true;
          continue;
        }
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        final m = publicMember.firstMatch(raw);
        if (m == null || m.group(1)!.startsWith('_')) continue;
        scanned++;
        if (forbiddenRe.hasMatch(raw)) offenders.add(raw.trim());
      }
      expect(scanned, greaterThan(3),
          reason: 'le scanner doit voir des signatures publiques (sinon faux vert)');
      expect(offenders, isEmpty,
          reason: 'type backend interdit en signature publique (AD-5):\n'
              '${offenders.join('\n')}');
    });
  });
}

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
