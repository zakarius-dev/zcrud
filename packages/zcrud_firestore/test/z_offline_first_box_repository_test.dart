// Tests ES-3.2 : base offline-first `ZOfflineFirstBoxRepository<T>`.
//
// Backend : `fake_cloud_firestore` (dev-dep) + `HiveZLocalStore` réel (tmpdir),
// parité E5-2/E5-3. `_ThrowingFirestore` pour la panne distante (miroir E5).
// Pouvoir discriminant (R12) : seeds LWW par écriture VERBATIM (méta précise via
// `applyMerged` local / `set` direct cloud) — jamais un seed « propre » masquant
// la sémantique. Chaque garde naît avec sa fixture d'échec (commentaires ★ R3-x).
//
// Couvre : Template Method (AC1/AC2), offline autoritaire (AC3), matérialisation
// éphémère (AC4), LWW hors-entité (AC5), merge-key sans T.updatedAt (AC6),
// hasPendingWrites (AC7), extension typée round-trip cloud (AC8), hors-entité non
// fuité (AC9), signatures nues (AC11), sync best-effort (AC12).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ───────────────────────── Modèle de test SANS `updatedAt` (miroir ZMindmap) ──
//
// _Note n'a AUCUN champ `updatedAt` : la merge-key LWW est donc OBLIGATOIREMENT
// hors-entité (AC6). Router la comparaison vers `entity.updatedAt` ne compilerait
// même pas (ZEntity n'expose aucun `updatedAt`) — garde structurelle (R3-d).
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

// ───────────────────────── Entité extensible de test (AC8, miroir ZSmartNote) ──

class _TypedExt implements ZExtension {
  const _TypedExt(this.value);
  final String value;
  @override
  int get formatVersion => 1;
  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': 1, 'value': value};
}

class _OpaqueExt implements ZExtension {
  const _OpaqueExt(this.payload);
  final Map<String, dynamic> payload;
  @override
  int get formatVersion => 0;
  @override
  Map<String, dynamic> toJson() => payload;
}

class _Probe extends ZEntity {
  const _Probe({this.id, this.extension});

  @override
  final String? id;
  final ZExtension? extension;

  factory _Probe.fromMap(
    Map<String, dynamic> map, {
    ZExtension? Function(Map<String, dynamic>)? extensionParser,
  }) {
    final rawExt = map['extension'];
    ZExtension? ext;
    if (rawExt is Map<String, dynamic>) {
      final typed = extensionParser == null
          ? null
          : ZExtension.guard<ZExtension?>(() => extensionParser(rawExt));
      ext = typed ?? _OpaqueExt(rawExt); // survie verbatim (AD-10)
    }
    return _Probe(id: map['id'] as String?, extension: ext);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        if (extension != null) 'extension': extension!.toJson(),
      };
}

ZExtension? _resolveProbeExt(String kind, Map<String, dynamic> json) =>
    kind == 'probe' ? _TypedExt('${json['value']}') : null;

/// Registre de `_Probe` — `thread` câble la variante consciente du contexte.
ZcrudRegistry _probeRegistry({required bool withContext}) {
  final r = ZcrudRegistry(
    decodeContext: withContext
        ? const ZDecodeContext(extensionParser: _resolveProbeExt)
        : null,
  );
  r.register<_Probe>(
    'probe',
    fromMap: _Probe.fromMap,
    toMap: (v) => v.toMap(),
    fromMapWithContext: (map, context) => _Probe.fromMap(
      map,
      extensionParser: context?.extensionParser == null
          ? null
          : (json) => context!.extensionParser!('probe', json),
    ),
  );
  return r;
}

// ───────────────────────── Firestore de test ───────────────────────────────

/// Lève `FirebaseException` à tout accès `collection()` (offline simulé, E5).
class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'firestore', code: 'unavailable');
  }
}

// ───────────────────────── Résolveurs & builders ───────────────────────────

const String _kNote = 'note';
const String _kNoteCollection = 'notes';

ZFirestorePathResolver _flatResolver([String kind = _kNote]) =>
    ZFirestorePathResolver(<String, ZFirestorePathRule>{
      kind: ZFirestorePathRule.flatTopLevel(collection: _kNoteCollection),
    });

ZSyncEntry<_Note> _entry(String id, String title, int count, DateTime at,
        {bool deleted = false}) =>
    ZSyncEntry<_Note>(
      entity: _Note(id: id, title: title, count: count),
      meta: ZSyncMeta(updatedAt: at, isDeleted: deleted),
    );

/// Sous-classe rejetante : `validate → Left` (Template Method ES-3.1, AC2).
class _RejectingRepo extends ZOfflineFirstBoxRepository<_Note> {
  _RejectingRepo({
    required super.local,
    required super.firestore,
    required super.resolver,
    required super.kind,
    required super.decode,
    required super.encode,
    super.autoListen,
  });

  @override
  ZResult<Unit> validate(_Note item) =>
      Left<ZFailure, Unit>(ZDomainFailure('rejet métier'));
}

void main() {
  late Directory tmp;
  var boxSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('offline_first_box_test');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<HiveZLocalStore<_Note>> noteLocal() async {
    final box = await Hive.openBox<dynamic>('notes_${boxSeq++}');
    var n = 0;
    return HiveZLocalStore<_Note>(
      box: box,
      kind: _kNote,
      fromMap: _Note.fromMap,
      toMap: (x) => x.toMap(),
      idFactory: () => 'eph${(++n).toString().padLeft(3, '0')}',
    );
  }

  ZOfflineFirstBoxRepository<_Note> noteRepo(
    HiveZLocalStore<_Note> local,
    FirebaseFirestore fs, {
    ZFirestorePathResolver? resolver,
    Map<String, dynamic> Function(_Note)? encode,
    Future<bool> Function()? isConnected,
    bool autoListen = false,
  }) =>
      ZOfflineFirstBoxRepository<_Note>(
        local: local,
        firestore: fs,
        resolver: resolver ?? _flatResolver(),
        kind: _kNote,
        decode: _Note.fromMap,
        encode: encode ?? (n) => n.toMap(),
        isConnected: isConnected,
        autoListen: autoListen,
      );

  // Écrit un doc cloud VERBATIM (méta précise) — jamais un seed « propre ».
  Future<void> seedCloud(FirebaseFirestore fs, String id, String title,
      int count, DateTime at,
      {bool deleted = false}) async {
    await fs.collection(_kNoteCollection).doc(id).set(<String, dynamic>{
      'id': id,
      'title': title,
      'count': count,
      ZSyncMeta.kUpdatedAt: at.toIso8601String(),
      ZSyncMeta.kIsDeleted: deleted,
    });
  }

  // ───────────────────────── AC1 — surface & Template Method ────────────────

  group('AC1 — extends ZStudyRepository, implémente persist, flux nus', () {
    test('instanciation + save (hérité) délègue validate→persist ; watchAll nu',
        () async {
      final local = await noteLocal();
      final repo = noteRepo(local, FakeFirebaseFirestore());
      // Le type expose bien un ZStudyRepository (Template Method hérité).
      expect(repo, isA<ZStudyRepository<_Note>>());

      final saved = await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      expect(saved.isRight(), isTrue);

      // watchAll() est un Stream<List<T>> NU (jamais Stream<Either<...>>).
      final Stream<List<_Note>> stream = repo.watchAll();
      final first = await stream.first;
      expect(first.map((n) => n.id), <String>['a']);
      repo.dispose();
    });
  });

  // ───────────────────────── AC2 — validate→Left BLOQUE l'écriture ──────────

  group('AC2 — Template Method : validate→Left bloque put local ET push', () {
    test('save rejeté : Left exact, aucun put local, collection cloud vide',
        () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = _RejectingRepo(
        local: local,
        firestore: fs,
        resolver: _flatResolver(),
        kind: _kNote,
        decode: _Note.fromMap,
        encode: (n) => n.toMap(),
        autoListen: false,
      );

      final res = await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      expect(res.isLeft(), isTrue);
      res.leftMap((f) => expect((f as ZDomainFailure).message, 'rejet métier'));

      // AUCUNE écriture locale (le put n'a jamais eu lieu).
      expect((await repo.getById('a')).isLeft(), isTrue);
      // AUCUNE écriture Firestore (persist jamais atteint).
      final cloud = await fs.collection(_kNoteCollection).get();
      expect(cloud.docs, isEmpty,
          reason: 'validate→Left doit court-circuiter persist (R3-a)');
      repo.dispose();
    });
  });

  // ───────────────────────── AC3 — offline-first autoritaire ────────────────

  group('AC3 — persist réussit même Firestore en panne (fire-and-forget)', () {
    test('save Right + lisible localement malgré FirebaseException distante',
        () async {
      final local = await noteLocal();
      // ★ R3-b : rendre le push AWAITÉ + propagé ferait échouer save ici (le
      // distant lève) → `expect(saved.isRight())` ROUGE. Le fire-and-forget
      // (`unawaited`) prouve que le local reste autoritaire (AD-9).
      final repo = noteRepo(local, _ThrowingFirestore());

      final saved = await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      expect(saved.isRight(), isTrue,
          reason: 'échec distant n\'invalide PAS le succès local');
      final back = (await repo.getById('a')).getOrElse(() => fail('getById'));
      expect(back.title, 'A');
      repo.dispose();
    });
  });

  // ───────────────────────── AC4 — matérialisation de l'éphémère ────────────

  group('AC4 — persist matérialise l\'éphémère (id opaque attribué ICI)', () {
    test('deux éphémères → deux id distincts ; corps id == clé de document',
        () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs);

      final s1 = (await repo.save(const _Note(title: 'A', count: 1)))
          .getOrElse(() => fail('s1'));
      final s2 = (await repo.save(const _Note(title: 'B', count: 2)))
          .getOrElse(() => fail('s2'));
      expect(s1.id, isNotNull);
      expect(s2.id, isNotNull);
      expect(s1.id, isNot(s2.id), reason: 'deux id opaques distincts');

      // Relecture locale par l'id matérialisé.
      expect((await repo.getById(s1.id!)).isRight(), isTrue);

      // Corps id == clé de document côté cloud (fire-and-forget → petit délai).
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final doc = await fs.collection(_kNoteCollection).doc(s1.id!).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['id'], s1.id, reason: 'invariant clé↔corps');
      repo.dispose();
    });
  });

  // ───────────────────────── AC5 — LWW hors-entité (cœur discriminant) ──────

  group('AC5 — merge LWW sur updated_at hors-entité (strictement plus récent)',
      () {
    test('(a)(b)(c)(d) via sync() one-shot', () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs);

      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 6, 1);

      // (a) cloud POSTÉRIEUR au local → le local ADOPTE le cloud.
      await local.applyMerged(_entry('a', 'local-a', 1, older));
      await seedCloud(fs, 'a', 'cloud-a', 1, newer);
      // (b) cloud ANTÉRIEUR au local → le local est CONSERVÉ (cloud ignoré).
      await local.applyMerged(_entry('b', 'local-b', 2, newer));
      await seedCloud(fs, 'b', 'cloud-b', 2, older);
      // (c) local-only NON supprimé → upload de rattrapage vers Firestore.
      await local.applyMerged(_entry('c', 'local-c', 3, newer));
      // (d) cloud-only → adopté localement.
      await seedCloud(fs, 'd', 'cloud-d', 4, newer);

      final res = await repo.sync();
      expect(res.isRight(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 30)); // rattrapage

      // (a) le local a adopté le corps + la méta distante (verbatim).
      final a = (await local.getById('a')).getOrElse(() => fail('a'));
      expect(a.title, 'cloud-a', reason: '(a) cloud plus récent adopté');
      final aMeta = (await local.syncEntries())
          .getOrElse(() => fail('meta'))
          .firstWhere((e) => e.id == 'a');
      expect(aMeta.updatedAt, newer, reason: '(a) méta distante préservée');
      // (b) ★ R3-c : inverser isAfter→isBefore ferait adopter le cloud ANCIEN →
      // ce titre deviendrait 'cloud-b' → ROUGE.
      final b = (await local.getById('b')).getOrElse(() => fail('b'));
      expect(b.title, 'local-b', reason: '(b) cloud plus ancien IGNORÉ (LWW)');
      // (c) rattrapage : la local-only est montée au cloud.
      final cDoc = await fs.collection(_kNoteCollection).doc('c').get();
      expect(cDoc.exists, isTrue, reason: '(c) upload de rattrapage local-only');
      expect(cDoc.data()!['title'], 'local-c');
      // (d) cloud-only adopté localement.
      final d = (await local.getById('d')).getOrElse(() => fail('d'));
      expect(d.title, 'cloud-d', reason: '(d) cloud-only adopté');
      repo.dispose();
    });
  });

  // ───────────────────────── AC6 — merge-key sans T.updatedAt ───────────────

  group('AC6 — merge-key hors-entité pour une entité SANS updatedAt (ZMindmap)',
      () {
    test('la clé LWW vient EXCLUSIVEMENT de ZSyncMeta (méta), jamais de T', () {
      // Garde STRUCTURELLE : _Note n'a aucun champ `updatedAt`. Router la
      // comparaison vers `entity.updatedAt` (R3-d) ne COMPILE pas — ZEntity
      // n'expose aucun `updatedAt`. On documente l'invariant : le code source du
      // dépôt ne lit `updated_at` que via la méta (ZSyncMeta.kUpdatedAt).
      final src = File(_repoPath()).readAsStringSync();
      expect(src.contains('.updatedAt'), isTrue,
          reason: 'la clé LWW est lue de ZSyncMeta/ZSyncEntry (méta)');
      // Aucune lecture d'un champ `updatedAt` sur l'ENTITÉ générique.
      expect(RegExp(r'entity\.updatedAt|item\.updatedAt|\.entity\.updatedAt')
          .hasMatch(src), isFalse,
          reason: 'jamais T.updatedAt (entité sans ce champ — AC6/R3-d)');
    });

    test('AC5 (a)/(b) restent corrects pour _Note (sans updatedAt)', () async {
      // Re-preuve fonctionnelle : le merge (a)/(b) marche sur _Note qui n'a
      // PAS de champ updatedAt — donc la clé est bien hors-entité.
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs);
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 9, 9);
      await local.applyMerged(_entry('a', 'L', 1, older));
      await seedCloud(fs, 'a', 'C', 1, newer);
      await repo.sync();
      expect((await local.getById('a')).getOrElse(() => fail('a')).title, 'C');
      repo.dispose();
    });
  });

  // ───────────────────────── AC7 — filtrage hasPendingWrites ────────────────

  group('AC7 — un écho local (hasPendingWrites=true) ne déclenche PAS de merge',
      () {
    test('true → aucun merge ; false → merge normal', () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs, autoListen: false);

      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 6, 1);
      // Local vivant ancien ; un "écho" cloud plus récent.
      await local.applyMerged(_entry('a', 'local', 1, older));
      final echo = <MapEntry<String, Map<String, dynamic>>>[
        MapEntry('a', <String, dynamic>{
          'id': 'a',
          'title': 'cloud',
          'count': 1,
          ZSyncMeta.kUpdatedAt: newer.toIso8601String(),
          ZSyncMeta.kIsDeleted: false,
        }),
      ];

      // ★ R3-e : retirer `if (hasPendingWrites) return;` ferait merger l'écho →
      // le titre deviendrait 'cloud' → ROUGE.
      await repo.handleCloudSnapshot(echo, hasPendingWrites: true);
      expect((await local.getById('a')).getOrElse(() => fail('a')).title,
          'local',
          reason: 'écho local (hasPendingWrites) ignoré : aucun merge');

      // Snapshot CONFIRMÉ → merge normal (le cloud plus récent est adopté).
      await repo.handleCloudSnapshot(echo, hasPendingWrites: false);
      expect((await local.getById('a')).getOrElse(() => fail('a')).title,
          'cloud',
          reason: 'snapshot confirmé : merge LWW appliqué');
      repo.dispose();
    });
  });

  // ───────────────────────── AC8 — extension typée round-trip cloud ─────────

  group('AC8 — l\'extension TYPÉE survit au round-trip cloud→merge→local', () {
    Future<HiveZLocalStore<_Probe>> probeLocal(ZcrudRegistry r) async {
      final box = await Hive.openBox<dynamic>('probes_${boxSeq++}');
      return HiveZLocalStore<_Probe>(
        box: box,
        kind: 'probe',
        fromMap: (m) => r.decode('probe', m) as _Probe,
        toMap: (p) => r.encode('probe', p),
      );
    }

    ZOfflineFirstBoxRepository<_Probe> probeRepo(
            HiveZLocalStore<_Probe> local, FirebaseFirestore fs, ZcrudRegistry r) =>
        ZOfflineFirstBoxRepository<_Probe>(
          local: local,
          firestore: fs,
          resolver: ZFirestorePathResolver(<String, ZFirestorePathRule>{
            'probe': const ZFirestorePathRule.flatTopLevel(collection: 'probes'),
          }),
          kind: 'probe',
          // D7 : décodage cloud CONTEXTUALISÉ via registry.decode.
          decode: (m) => r.decode('probe', m) as _Probe,
          encode: (p) => r.encode('probe', p),
          autoListen: false,
        );

    Future<void> seedProbe(FirebaseFirestore fs) async {
      await fs.collection('probes').doc('p1').set(<String, dynamic>{
        'id': 'p1',
        'extension': <String, dynamic>{'format_version': 1, 'value': 'hi'},
        ZSyncMeta.kUpdatedAt: DateTime.utc(2026, 5, 5).toIso8601String(),
        ZSyncMeta.kIsDeleted: false,
      });
    }

    test('AVEC contexte : getById restitue l\'extension TYPÉE', () async {
      final r = _probeRegistry(withContext: true);
      final local = await probeLocal(r);
      final fs = FakeFirebaseFirestore();
      final repo = probeRepo(local, fs, r);
      await seedProbe(fs);

      await repo.sync(); // pull → merge → applyMerged local
      final got = (await repo.getById('p1')).getOrElse(() => fail('getById'));
      expect(got.extension, isA<_TypedExt>(),
          reason: 'ES-3.0 threadé : l\'extension revient TYPÉE');
      expect((got.extension! as _TypedExt).value, 'hi');
      repo.dispose();
    });

    test('★ R3-f — SANS contexte (decode nu) : l\'extension revient OPAQUE',
        () async {
      final r = _probeRegistry(withContext: false); // contexte NON câblé
      final local = await probeLocal(r);
      final fs = FakeFirebaseFirestore();
      final repo = probeRepo(local, fs, r);
      await seedProbe(fs);

      await repo.sync();
      final got = (await repo.getById('p1')).getOrElse(() => fail('getById'));
      // Le threading ES-3.0 est LOAD-BEARING : sans lui → opaque (DW-ES14-2).
      expect(got.extension, isA<_OpaqueExt>());
      expect(got.extension, isNot(isA<_TypedExt>()));
      repo.dispose();
    });
  });

  // ───────────────────────── AC9 — hors-entité non fuité ────────────────────

  group('AC9 — is_deleted/updated_at HORS-ENTITÉ, jamais dans le corps', () {
    test('le corps métier toMap ne contient NI is_deleted NI updated_at', () {
      final body = const _Note(id: 'a', title: 'A', count: 1).toMap();
      expect(body.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(body.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
    });

    test('★ R3-g — stripReserved empêche un corps fuité de clobberer la méta',
        () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      // Encodeur MALVEILLANT : fuit `is_deleted:true` + `updated_at:'LEAK'` dans
      // le corps. Le dépôt DOIT les stripper (le corps est épandu en dernier).
      final repo = noteRepo(local, fs, encode: (n) => <String, dynamic>{
            'title': n.title,
            'count': n.count,
            ZSyncMeta.kIsDeleted: true,
            ZSyncMeta.kUpdatedAt: 'LEAK',
          });

      await repo.save(const _Note(id: 'a', title: 'A', count: 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final doc = await fs.collection(_kNoteCollection).doc('a').get();
      // ★ R3-g : retirer `stripReserved` laisserait la fuite écraser la méta
      // autoritaire → is_deleted deviendrait `true` / updated_at 'LEAK' → ROUGE.
      expect(doc.data()![ZSyncMeta.kIsDeleted], isFalse,
          reason: 'la méta autoritaire (false) n\'est PAS clobberée par le corps');
      expect(doc.data()![ZSyncMeta.kUpdatedAt], isNot('LEAK'),
          reason: 'updated_at reste la méta ISO (jamais la fuite du corps)');
      expect(
          DateTime.tryParse('${doc.data()![ZSyncMeta.kUpdatedAt]}'), isNotNull);
      repo.dispose();
    });

    test('softDelete : is_deleted bascule sans toucher le corps ; lectures excluent',
        () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs);
      await repo.save(const _Note(id: 'a', title: 'métier', count: 42));
      await repo.save(const _Note(id: 'b', title: 'B', count: 2));

      final del = await repo.softDelete('a');
      expect(del.isRight(), isTrue);
      expect((await repo.getById('a')).isLeft(), isTrue, reason: 'tombstone');
      expect(
          (await repo.getAll()).getOrElse(() => fail('getAll')).map((n) => n.id),
          <String>['b']);

      // Le corps métier de 'a' reste intact (via la voie sync, tombstone inclus).
      final aEntry = (await local.syncEntries())
          .getOrElse(() => fail('sync'))
          .firstWhere((e) => e.id == 'a');
      expect(aEntry.isDeleted, isTrue);
      expect(aEntry.entity, const _Note(id: 'a', title: 'métier', count: 42),
          reason: 'aucun champ métier touché par le soft-delete');

      final restored = await repo.restore('a');
      expect(restored.isRight(), isTrue);
      expect((await repo.getById('a')).isRight(), isTrue);
      repo.dispose();
    });
  });

  // ───────────────────────── AC12 — sync() best-effort ──────────────────────

  group('AC12 — sync() best-effort : Right(unit) si offline, local intact', () {
    test('FirebaseException distante → Right(unit), local inchangé', () async {
      final local = await noteLocal();
      await local.applyMerged(_entry('a', 'A', 1, DateTime.utc(2026, 1, 1)));
      final repo = noteRepo(local, _ThrowingFirestore());

      final res = await repo.sync();
      expect(res.isRight(), isTrue, reason: 'distant injoignable = offline');
      expect((await repo.getById('a')).getOrElse(() => fail('a')).title, 'A',
          reason: 'local intact');
      repo.dispose();
    });

    test('isConnected=false → court-circuit Right(unit) (aucun accès réseau)',
        () async {
      final local = await noteLocal();
      // Ce Firestore lèverait s'il était touché → prouve le court-circuit.
      final repo = noteRepo(local, _ThrowingFirestore(),
          isConnected: () async => false);
      final res = await repo.sync();
      expect(res.isRight(), isTrue);
      repo.dispose();
    });

    test('Firestore sain + doc plus récent → sync adopte + Right(unit)',
        () async {
      final local = await noteLocal();
      final fs = FakeFirebaseFirestore();
      final repo = noteRepo(local, fs);
      await local.applyMerged(_entry('a', 'old', 1, DateTime.utc(2026, 1, 1)));
      await seedCloud(fs, 'a', 'new', 1, DateTime.utc(2026, 6, 1));

      final res = await repo.sync();
      expect(res.isRight(), isTrue);
      expect((await local.getById('a')).getOrElse(() => fail('a')).title, 'new');
      repo.dispose();
    });
  });

  // ───────────────────────── AC11 — signatures nues (AD-5/AD-11) ────────────

  group('AC11 — aucun type backend dans une signature publique', () {
    test('z_offline_first_box_repository.dart : signatures NUES', () {
      final src = File(_repoPath()).readAsStringSync();
      const forbidden = <String>[
        r'\bBox\b',
        r'\bHiveObject\b',
        r'\bHiveError\b',
        r'\bQuery\b',
        r'\bCollectionReference\b',
        r'\bDocumentSnapshot\b',
        r'\bQuerySnapshot\b',
        r'\bTimestamp\b',
        r'\bFilter\b',
        r'\bWriteBatch\b',
        r'\bFirebaseException\b',
        r'\bFirebaseFirestore\b',
      ];
      final forbiddenRe = RegExp(forbidden.join('|'));
      // Signatures de MÉTHODES/GETTERS publics (2 espaces d'indentation).
      final publicMember = RegExp(
        r'^  (?:@override\s+)?(?:@visibleForTesting\s+)?(?:factory\s+|static\s+)?[A-Za-z_][\w<>,.\?\s\[\]]*?\b([A-Za-z][\w]*)\s*(?:\(|=>|\{|get\s)',
      );
      var scanned = 0;
      final offenders = <String>[];
      var inBlock = false;
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final t = raw.trimLeft();
        if (inBlock) {
          if (t.contains('*/')) inBlock = false;
          continue;
        }
        if (t.startsWith('/*')) {
          if (!t.contains('*/')) inBlock = true;
          continue;
        }
        if (t.startsWith('//') || t.startsWith('///')) continue;
        // Constructeur (nom de classe) — ignoré (la couture DI y est permise).
        if (t.startsWith('ZOfflineFirstBoxRepository(') ||
            raw.contains('required this.') ||
            raw.contains(': _')) {
          continue;
        }
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

    test('le barrel n\'importe/exporte AUCUNE lib hive/cloud_firestore', () {
      final barrel = File(_barrelPath()).readAsStringSync();
      // Scan des seules directives import/export (les commentaires MENTIONNENT
      // ces libs comme confinées — c'est légitime).
      final directives = barrel
          .split('\n')
          .where((l) =>
              l.trimLeft().startsWith('export ') ||
              l.trimLeft().startsWith('import '))
          .join('\n');
      expect(directives.contains('package:cloud_firestore'), isFalse);
      expect(directives.contains('package:hive'), isFalse);
      expect(directives.contains('package:firebase_core'), isFalse);
    });
  });
}

String _repoPath() => _find('lib/src/data/z_offline_first_box_repository.dart');
String _barrelPath() => _find('lib/zcrud_firestore.dart');

String _find(String rel) {
  for (final base in <String>['', 'packages/zcrud_firestore/']) {
    final f = File('$base$rel');
    if (f.existsSync()) return f.path;
  }
  fail('$rel introuvable depuis ${Directory.current.path}');
}
