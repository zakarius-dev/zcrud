// CR-LEX-8 / CR-LEX-9 — normalisation temporelle appliquée trop tard et trop
// étroitement (session lex_douane, 2026-07-21).
//
// CR-8 : `_normalizeMetaIso` ne convertissait QUE la clé LWW `updated_at`. Tout
//        autre champ portant un `Timestamp` natif arrivait BRUT au `decode` de
//        l'hôte — or les entités Z* sont backend-agnostiques (AD-16) et leur
//        `fromMap` généré ne sait pas le lire : le champ retombait à `null`.
//        Un hôte écrivant ses dates en `Timestamp` perdait TOUTES ses dates au
//        cutover, sans erreur.
// CR-9 : `ZSyncMeta.fromJson(map)` était construit sur le map BRUT (le décodage
//        normalise une copie) : `updatedAt` valait `null` et c'est ce `null` qui
//        était PERSISTÉ — la clé d'arbitrage LWW retombait à vide.
//
// ⚠️ Piège de test signalé par lex, et respecté ici : un round-trip qui n'exerce
// que le chemin ISO reste VERT. Il faut injecter un `Timestamp` BRUT.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

const String _kKind = 'dated';
const String _kCollection = 'dated_docs';

/// Entité PORTANT UNE DATE, décodée comme le ferait un `fromMap` **généré** :
/// il ne connaît que la String ISO — jamais un `Timestamp` (AD-16).
class _Dated extends ZEntity {
  const _Dated({this.id, required this.title, this.date});

  @override
  final String? id;
  final String title;
  final DateTime? date;

  static _Dated fromMap(Map<String, dynamic> map) {
    final raw = map['date'];
    return _Dated(
      id: map['id'] as String?,
      title: map['title'] as String? ?? '',
      // Exactement la tolérance d'un codegen zcrud : String ISO uniquement.
      date: raw is String ? DateTime.tryParse(raw) : null,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        if (date != null) 'date': date!.toIso8601String(),
      };
}

ZFirestorePathResolver _resolver() => ZFirestorePathResolver(
      <String, ZFirestorePathRule>{
        _kKind: const ZFirestorePathRule.globalTopLevel(
          collection: _kCollection,
        ),
      },
    );

void main() {
  mainCr10();
  late Directory dir;
  late Box<dynamic> box;
  late HiveZLocalStore<_Dated> local;
  late FakeFirebaseFirestore fs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zcrud_cr_lex8');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('cr_lex8_${dir.path.hashCode}');
    local = HiveZLocalStore<_Dated>(
      box: box,
      kind: _kKind,
      fromMap: _Dated.fromMap,
      toMap: (e) => e.toMap(),
    );
    fs = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await box.close();
    await dir.delete(recursive: true);
  });

  ZOfflineFirstBoxRepository<_Dated> repo() =>
      ZOfflineFirstBoxRepository<_Dated>(
        local: local,
        firestore: fs,
        resolver: _resolver(),
        kind: _kKind,
        decode: _Dated.fromMap,
        encode: (e) => e.toMap(),
      );

  group('CR-LEX-8 — tout champ Timestamp est normalisé, pas seulement la clé LWW',
      () {
    test('🔴 un `date` en Timestamp BRUT survit au décodage', () async {
      final when = DateTime.utc(2024, 3, 15, 10, 30);
      // Le cas EXACT de lex : la production écrit `Timestamp.fromDate(...)`.
      await fs.collection(_kCollection).doc('d1').set(<String, dynamic>{
        'id': 'd1',
        'title': 'Examen',
        'date': Timestamp.fromDate(when),
        ZSyncMeta.kUpdatedAt: Timestamp.fromDate(when),
        ZSyncMeta.kIsDeleted: false,
      });

      final r = await repo().sync();
      expect(r.isRight(), isTrue);

      final entries = (await local.syncEntries()).getOrElse(() => const []);
      expect(entries, hasLength(1));
      // Avant correctif : `null` — la date de TOUS les enregistrements perdue.
      expect(entries.single.entity.date, when);
    });

    test('la forme sérialisée `{_seconds,_nanoseconds}` est couverte', () async {
      final when = DateTime.utc(2024, 5, 1, 8);
      await fs.collection(_kCollection).doc('d2').set(<String, dynamic>{
        'id': 'd2',
        'title': 'Sérialisé',
        'date': <String, dynamic>{
          '_seconds': when.millisecondsSinceEpoch ~/ 1000,
          '_nanoseconds': 0,
        },
        ZSyncMeta.kUpdatedAt: when.toIso8601String(),
        ZSyncMeta.kIsDeleted: false,
      });

      await repo().sync();
      final entries = (await local.syncEntries()).getOrElse(() => const []);
      expect(entries.single.entity.date, when);
    });

    test('une String ISO déjà normalisée traverse INCHANGÉE (idempotence)',
        () async {
      final when = DateTime.utc(2024, 7, 4, 12);
      await fs.collection(_kCollection).doc('d3').set(<String, dynamic>{
        'id': 'd3',
        'title': 'Déjà ISO',
        'date': when.toIso8601String(),
        ZSyncMeta.kUpdatedAt: when.toIso8601String(),
        ZSyncMeta.kIsDeleted: false,
      });

      await repo().sync();
      final entries = (await local.syncEntries()).getOrElse(() => const []);
      expect(entries.single.entity.date, when);
    });

    test('une valeur NON temporelle traverse intacte (AD-10)', () async {
      await fs.collection(_kCollection).doc('d4').set(<String, dynamic>{
        'id': 'd4',
        'title': 'Sans date',
        'date': 'pas-une-date',
        ZSyncMeta.kUpdatedAt: DateTime.utc(2024).toIso8601String(),
        ZSyncMeta.kIsDeleted: false,
      });

      await repo().sync();
      final entries = (await local.syncEntries()).getOrElse(() => const []);
      // Le titre survit, la date invalide → null sans throw.
      expect(entries.single.entity.title, 'Sans date');
      expect(entries.single.entity.date, isNull);
    });
  });

  group('CR-LEX-9 — la clé LWW persistée porte l\'horodatage RÉEL', () {
    test('🔴 `updated_at` en Timestamp n\'est plus persisté à null', () async {
      final when = DateTime.utc(2024, 9, 9, 9);
      await fs.collection(_kCollection).doc('m1').set(<String, dynamic>{
        'id': 'm1',
        'title': 'Méta',
        ZSyncMeta.kUpdatedAt: Timestamp.fromDate(when),
        ZSyncMeta.kIsDeleted: false,
      });

      await repo().sync();
      final entries = (await local.syncEntries()).getOrElse(() => const []);
      expect(entries, hasLength(1));
      // Avant correctif : `null` PERSISTÉ ⇒ l'arbitrage LWW des cycles suivants
      // se faisait sur une base fausse, pouvant écraser le plus récent par le
      // plus ancien, silencieusement.
      expect(entries.single.meta.updatedAt, isNotNull);
      expect(entries.single.meta.updatedAt, when);
    });

    test('l\'arbitrage LWW reste correct : un cloud PLUS ANCIEN n\'écrase pas',
        () async {
      final recent = DateTime.utc(2024, 12, 1);
      final older = DateTime.utc(2024, 1, 1);

      // Local récent, déjà connu.
      await local.applyMerged(ZSyncEntry<_Dated>(
        entity: _Dated(id: 'w1', title: 'local récent', date: recent),
        meta: ZSyncMeta(updatedAt: recent, isDeleted: false),
      ));

      // Cloud plus ancien, horodaté en Timestamp brut.
      await fs.collection(_kCollection).doc('w1').set(<String, dynamic>{
        'id': 'w1',
        'title': 'cloud ancien',
        ZSyncMeta.kUpdatedAt: Timestamp.fromDate(older),
        ZSyncMeta.kIsDeleted: false,
      });

      await repo().sync();
      final entries = (await local.syncEntries()).getOrElse(() => const []);
      expect(entries.single.entity.title, 'local récent',
          reason: 'un cloud plus ancien ne doit jamais écraser le local');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CR-LEX-10 — découverte des parents d'une topologie nested.
//
// Un repository folder-scopé est figé sur UN parentId : son sync() ne couvre que
// ce dossier. Sur un appareil NEUF (store local vide), l'hôte n'avait aucune
// source pour découvrir les dossiers existants — la découverte était circulaire,
// et sync() rendait Right(unit) sur une liste vide : succès SILENCIEUX.
// Faute d'API, lex devait interroger FirebaseFirestore elle-même, perçant
// l'isolation backend (AD-5/AD-11).
void mainCr10() {
  const String kNested = 'exam';
  const String kParentCol = 'study_folders';

  ZFirestorePathResolver nestedResolver() => ZFirestorePathResolver(
        <String, ZFirestorePathRule>{
          kNested: const ZFirestorePathRule.nestedUnderParent(
            collection: 'exams',
            parentCollection: kParentCol,
          ),
        },
      );

  group('CR-LEX-10 — listParentIds', () {
    late Directory dir;
    late Box<dynamic> box;
    late HiveZLocalStore<_Dated> local;
    late FakeFirebaseFirestore fs;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zcrud_cr_lex10');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('cr_lex10_${dir.path.hashCode}');
      local = HiveZLocalStore<_Dated>(
        box: box,
        kind: kNested,
        fromMap: _Dated.fromMap,
        toMap: (e) => e.toMap(),
      );
      fs = FakeFirebaseFirestore();
    });

    tearDown(() async {
      await box.close();
      await dir.delete(recursive: true);
    });

    ZOfflineFirstBoxRepository<_Dated> nestedRepo({String parentId = 'f1'}) =>
        ZOfflineFirstBoxRepository<_Dated>(
          local: local,
          firestore: fs,
          resolver: nestedResolver(),
          kind: kNested,
          decode: _Dated.fromMap,
          encode: (e) => e.toMap(),
          userId: 'u1',
          parentId: parentId,
          autoListen: false,
        );

    test('🔴 APPAREIL NEUF : les dossiers cloud sont découvrables, local vide',
        () async {
      // Le scénario exact de la CR : 2 dossiers au cloud, store local VIDE.
      await fs.collection('users/u1/$kParentCol').doc('f1').set(
          <String, dynamic>{'name': 'Dossier 1'});
      await fs.collection('users/u1/$kParentCol').doc('f2').set(
          <String, dynamic>{'name': 'Dossier 2'});

      final ids = (await nestedRepo().listParentIds())
          .getOrElse(() => const <String>[]);
      // Avant : l'hôte ne pouvait RIEN découvrir ⇒ sync() no-op ⇒ liste vide.
      expect(ids..sort(), <String>['f1', 'f2']);
    });

    test('aucun parent au cloud ⇒ liste vide, mais Right (pas une erreur)',
        () async {
      final r = await nestedRepo().listParentIds();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => const <String>['x']), isEmpty);
    });

    test('une topologie NON nested rend Left explicite, jamais une liste vide',
        () async {
      // Le mode dégradé silencieux est précisément ce qu'on élimine.
      final flat = ZOfflineFirstBoxRepository<_Dated>(
        local: local,
        firestore: fs,
        resolver: _resolver(), // globalTopLevel
        kind: _kKind,
        decode: _Dated.fromMap,
        encode: (e) => e.toMap(),
        autoListen: false,
      );
      final r = await flat.listParentIds();
      expect(r.isLeft(), isTrue);
    });

    test('user-scopé sans userId ⇒ Left explicite', () async {
      final noUser = ZOfflineFirstBoxRepository<_Dated>(
        local: local,
        firestore: fs,
        resolver: nestedResolver(),
        kind: kNested,
        decode: _Dated.fromMap,
        encode: (e) => e.toMap(),
        parentId: 'f1',
        autoListen: false,
      );
      final r = await noUser.listParentIds();
      expect(r.isLeft(), isTrue);
    });

    test('aucun type backend dans la signature (AD-5)', () async {
      final ids = await nestedRepo().listParentIds();
      expect(ids, isA<Either<ZFailure, List<String>>>());
    });
  });
}
