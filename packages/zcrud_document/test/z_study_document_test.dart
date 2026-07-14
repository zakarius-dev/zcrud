/// AC2 / AC9 / AC11 — `ZStudyDocument` : conforme AD-19 **dès la naissance**,
/// round-trip stable, invariants de valeur gardés.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
// Import DIRECT de l'implémentation : `ZStudyDocumentZcrud` est volontairement
// `hide` du barrel public (son `copyWith` généré remettrait `extra`/`extension`
// aux défauts). Ce test PROUVE justement ce masquage — d'où l'import interne.
import 'package:zcrud_document/src/domain/z_study_document.dart'
    show ZStudyDocumentZcrud;
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('AC2 — forme de l\'entité', () {
    test('est un `ZEntity` (id opaque nullable) ET un `ZExtensible`', () {
      const d = ZStudyDocument();
      expect(d, isA<ZEntity>());
      expect(d, isA<ZExtensible>());
      expect(d.id, isNull);
      expect(d.isEphemeral, isTrue);
      expect(const ZStudyDocument(id: 'x').isEphemeral, isFalse);
    });

    test('défauts sûrs du constructeur', () {
      const d = ZStudyDocument();
      expect(d.folderId, '');
      expect(d.fileName, '');
      expect(d.status, ZDocumentStatus.uploading);
      expect(d.storagePath, '');
      expect(d.pageCount, isNull);
      expect(d.sizeBytes, 0);
      expect(d.createdAt, isNull);
      expect(d.extension, isNull);
      expect(d.extra, isEmpty);
    });

    test('round-trip STABLE (idempotent) — instance PLEINE', () {
      final d = ZStudyDocument(
        id: 'd1',
        folderId: 'f1',
        fileName: 'cours.pdf',
        status: ZDocumentStatus.ready,
        storagePath: 'gs://bucket/d1.pdf',
        pageCount: 12,
        sizeBytes: 1024,
        createdAt: DateTime.utc(2026, 5, 5),
        extra: const <String, dynamic>{'zz_app': 'valeur'},
      );
      final m1 = d.toMap();
      final relu = ZStudyDocument.fromMap(m1);
      final m2 = relu.toMap();

      expect(relu, d);
      expect(m2, equals(m1), reason: 'toMap → fromMap → toMap est IDEMPOTENT');
      expect(m1['id'], 'd1');
      expect(m1['folder_id'], 'f1');
      expect(m1['file_name'], 'cours.pdf');
      expect(m1['status'], 'ready', reason: 'enum en camelCase, par NOM');
      expect(m1['storage_path'], 'gs://bucket/d1.pdf');
      expect(m1['page_count'], 12);
      expect(m1['size_bytes'], 1024);
      expect(m1['created_at'], '2026-05-05T00:00:00.000Z', reason: 'ISO-8601');
      expect(m1['zz_app'], 'valeur', reason: '`extra` étalé par le toMap d\'instance');
    });

    test('round-trip STABLE — instance MINIMALE', () {
      const d = ZStudyDocument();
      final m1 = d.toMap();
      final relu = ZStudyDocument.fromMap(m1);
      expect(relu, d);
      expect(relu.toMap(), equals(m1));
    });

    test('convergence : une instance mémoire == la même relue du store', () {
      final fromStore = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 'd1',
        'folder_id': 'f1',
        'file_name': 'x.pdf',
        'size_bytes': 10,
        // clés du STORE, écrites DANS LE CORPS (AD-19.2 pt.1)
        'updated_at': '2026-05-05T00:00:00.000Z',
        'is_deleted': false,
      });
      const inMemory = ZStudyDocument(
        id: 'd1',
        folderId: 'f1',
        fileName: 'x.pdf',
        sizeBytes: 10,
      );
      expect(fromStore.extra, isEmpty,
          reason: 'les clés de sync N\'entrent PAS dans extra');
      expect(fromStore, inMemory);
      expect(fromStore.hashCode, inMemory.hashCode);
    });

    test('NFR-S3/SM-S5 : la map persistée ne porte que des types NEUTRES', () {
      final m = ZStudyDocument(
        id: 'd',
        status: ZDocumentStatus.ready,
        createdAt: DateTime.utc(2026),
      ).toMap();
      for (final v in m.values) {
        expect(
          v == null || v is String || v is num || v is bool || v is List || v is Map,
          isTrue,
          reason: 'aucun Timestamp/Color/IconData/type cloud_firestore : $v '
              '(${v.runtimeType})',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC9 — R-A / R-C : les DEUX contrôles d'AD-19, explicitement, par entité.
  // Calqué sur « ZRepetitionInfo — AD-19 : clés de sync hors-entité (ES-1.3) »
  // (z_repetition_info_test.dart) — reproduit, pas réinventé.
  //
  // ⚠️ SI CE GROUPE TOMBE : `_reservedKeys` a perdu `...ZSyncMeta.reservedKeys`.
  // L'oubli s'est produit 2 fois sur 4 en ES-1.3, SOUS 1193 TESTS VERTS.
  // ═══════════════════════════════════════════════════════════════════════════
  group('ZStudyDocument — AD-19 : clés de sync hors-entité (AC9)', () {
    test(r'(R-C) `$ZStudyDocumentFieldSpecs` ∩ ZSyncMeta.reservedKeys == {}', () {
      // AD-19.1.a — le gate NE COUVRE PAS ce contrôle : il est écrit ICI,
      // explicitement. lex porte `updatedAt` ET `isDeleted` INLINE sur
      // `StudyDocument` : les porter aurait recréé la perte de données (le store
      // écrit sa méta APRÈS le corps à chaque `put`).
      final specNames = $ZStudyDocumentFieldSpecs.map((s) => s.name).toSet();
      expect(
        specNames.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
        reason: 'ZStudyDocument ne doit déclarer NI updated_at NI is_deleted : '
            'ces clés appartiennent au STORE (ZSyncMeta), pas au domaine.',
      );
      // Et la clé métier `created_at` — DISTINCTE — est bien là (précédent
      // `ZStudyFolder.archivedAt`).
      expect(specNames, contains('created_at'));
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });

    test('(AD-19.1.b) aucun `persistAs: timestamp` sur une clé réservée', () {
      // `$ZStudyDocumentTimestampFields` est la métadonnée NEUTRE émise par le
      // générateur pour `@ZcrudField(persistAs: ZPersistAs.timestamp)`.
      expect(
        $ZStudyDocumentTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect($ZStudyDocumentTimestampFields, isEmpty,
          reason: 'aucun persistAs: timestamp n\'est requis par ES-2.1');
    });

    test('(R-A) fromMap d\'une map de STORE : ni is_deleted ni updated_at dans extra',
        () {
      final d = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 'd1',
        'folder_id': 'f1',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });

      expect(d.extra.containsKey('is_deleted'), isFalse);
      expect(d.extra.containsKey('updated_at'), isFalse);
      expect(d.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys), isEmpty);
      // ANTI-VACUITÉ : on ne passe pas (a) en vidant `extra`.
      expect(d.extra['zz_cle_inconnue'], 'gardee');
    });

    test('(R-A) toMap() ne RÉÉMET aucune clé de sync (AD-16)', () {
      final d = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 'd1',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
      });
      final m = d.toMap();
      expect(m.containsKey('is_deleted'), isFalse);
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('isDeleted'), isFalse);
      expect(m.containsKey('updatedAt'), isFalse);
    });

    test('`extension` est réservée (jamais capturée dans extra)', () {
      final d = ZStudyDocument.fromMap(<String, dynamic>{
        'extension': <String, dynamic>{'format_version': 1},
      });
      expect(d.extra.containsKey('extension'), isFalse);
      expect(d.extension, isNull, reason: 'aucun parser injecté ⇒ repli null');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC11 / R-H — invariants de valeur : GARDE + CAS CORROMPU (AD-10).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — invariants de valeur (garde + corrompu, jamais de throw)', () {
    ZStudyDocument decode(Map<String, dynamic> m) => ZStudyDocument.fromMap(m);

    test('pageCount : GARDE 12 conservé', () {
      expect(decode(<String, dynamic>{'page_count': 12}).pageCount, 12);
      expect(decode(<String, dynamic>{'page_count': 1}).pageCount, 1);
    });

    test('pageCount : CORROMPU 0 / -1 / "x" / absent ⇒ null', () {
      expect(decode(<String, dynamic>{'page_count': 0}).pageCount, isNull);
      expect(decode(<String, dynamic>{'page_count': -1}).pageCount, isNull);
      expect(decode(<String, dynamic>{'page_count': 'x'}).pageCount, isNull);
      expect(decode(<String, dynamic>{'page_count': null}).pageCount, isNull);
      expect(decode(const <String, dynamic>{}).pageCount, isNull);
    });

    test('sizeBytes : GARDE 1024 conservé', () {
      expect(decode(<String, dynamic>{'size_bytes': 1024}).sizeBytes, 1024);
      expect(decode(<String, dynamic>{'size_bytes': 0}).sizeBytes, 0);
    });

    test('sizeBytes : CORROMPU -1 / "x" / absent ⇒ 0', () {
      expect(decode(<String, dynamic>{'size_bytes': -1}).sizeBytes, 0);
      expect(decode(<String, dynamic>{'size_bytes': 'x'}).sizeBytes, 0);
      expect(decode(<String, dynamic>{'size_bytes': null}).sizeBytes, 0);
      expect(decode(const <String, dynamic>{}).sizeBytes, 0);
    });

    test('createdAt : ISO valide conservée ; illisible ⇒ null', () {
      expect(decode(<String, dynamic>{'created_at': '2026-05-05T00:00:00.000Z'})
          .createdAt, DateTime.utc(2026, 5, 5));
      expect(decode(<String, dynamic>{'created_at': 'pas-une-date'}).createdAt,
          isNull);
      expect(decode(<String, dynamic>{'created_at': 42}).createdAt, isNull);
    });

    test('AC11 — `fromMap(const {})` ne THROW PAS (map vide)', () {
      expect(() => ZStudyDocument.fromMap(const <String, dynamic>{}),
          returnsNormally);
      final d = ZStudyDocument.fromMap(const <String, dynamic>{});
      expect(d, const ZStudyDocument());
    });

    test('map INTÉGRALEMENT corrompue : jamais de throw, défauts sûrs partout', () {
      final d = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 42,
        'folder_id': <String>[],
        'file_name': <String, dynamic>{},
        'status': 3.14,
        'storage_path': true,
        'page_count': 'abc',
        'size_bytes': <String>['x'],
        'created_at': <String, dynamic>{},
        'extension': 'pas-une-map',
      });
      expect(d.id, isNull);
      expect(d.folderId, '');
      expect(d.fileName, '');
      expect(d.status, ZDocumentStatus.uploading);
      expect(d.storagePath, '');
      expect(d.pageCount, isNull);
      expect(d.sizeBytes, 0);
      expect(d.createdAt, isNull);
      expect(d.extension, isNull);
    });
  });

  group('copyWith d\'instance : sentinelle, canaux hors-codegen préservés', () {
    test('argument omis ⇒ valeur conservée (extra/extension compris)', () {
      final d = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 'd1',
        'zz_app': 'v',
      });
      final c = d.copyWith(fileName: 'autre.pdf');
      expect(c.fileName, 'autre.pdf');
      expect(c.id, 'd1');
      expect(c.extra['zz_app'], 'v',
          reason: 'le copyWith GÉNÉRÉ aurait remis `extra` au défaut — perte '
              'silencieuse. Le copyWith d\'INSTANCE le masque.');
    });

    test('`null` explicite ⇒ reset (distinct de « non fourni »)', () {
      const d = ZStudyDocument(id: 'd1', pageCount: 5);
      expect(d.copyWith(id: null).id, isNull);
      expect(d.copyWith(pageCount: null).pageCount, isNull);
      expect(d.copyWith().id, 'd1');
    });
  });

  // =========================================================================
  // 🔴 H2 (code-review ES-2.1) — `copyWith` NE ROUVRE PAS les invariants R-H que
  // `fromMap` ferme (perte silencieuse à l'ÉCRITURE).
  //
  // LE TROU : `copyWith` passait `sizeBytes as int` et `pageCount as int?` BRUTS,
  // alors que ses DEUX SŒURS de la même story (`ZDocumentViewerPrefs`,
  // `ZDocumentReadingState`) sanitisaient. La dartdoc de `sizeBytes` PROMETTAIT
  // pourtant « jamais négative — R-H » : une promesse EN PROSE qu'AUCUNE machine
  // ne tenait.
  //
  // Le groupe `copyWith` ci-dessus ne teste QUE la sémantique de SENTINELLE, et
  // le test de convergence (l. 75) n'exerce QUE la voie `fromMap` : le trou était
  // invisible sous 112 tests verts. Ces tests MORDENT.
  // =========================================================================
  group('H2 — `copyWith` SANITISE (l\'invariant tient aux DEUX frontières)', () {
    test('MORD : `sizeBytes: -1` ⇒ 0 (jamais négative — la dartdoc le PROMET)',
        () {
      const d = ZStudyDocument(id: 'd1');
      expect(d.copyWith(sizeBytes: -1).sizeBytes, 0);
      expect(d.copyWith(sizeBytes: -999999).sizeBytes, 0);
      // GARDE : une valeur légale reste intacte.
      expect(d.copyWith(sizeBytes: 1024).sizeBytes, 1024);
      expect(d.copyWith(sizeBytes: 0).sizeBytes, 0);
    });

    test('MORD : `pageCount: 0` / négatif ⇒ null (« inconnu », pas « zéro page »)',
        () {
      const d = ZStudyDocument(id: 'd1', pageCount: 12);
      expect(d.copyWith(pageCount: 0).pageCount, isNull);
      expect(d.copyWith(pageCount: -3).pageCount, isNull);
      // GARDE : une valeur légale reste intacte ; `null` explicite reste un reset.
      expect(d.copyWith(pageCount: 42).pageCount, 42);
      expect(d.copyWith(pageCount: null).pageCount, isNull);
      expect(d.copyWith().pageCount, 12);
    });

    test('CONVERGENCE par la voie `copyWith` : ce qui est PERSISTÉ est RELISIBLE',
        () {
      // Le scénario EXACT du finding : avant le correctif, `toMap()` persistait
      // `{'size_bytes': -1, 'page_count': 0}` — HORS du domaine de définition —
      // et la relecture les MODIFIAIT silencieusement (0 / null) ⇒ round-trip NON
      // idempotent, `==` cassée entre l'instance mémoire et la même relue du store.
      final d = ZStudyDocument.fromMap(const <String, dynamic>{'id': 'd1'})
          .copyWith(sizeBytes: -1, pageCount: 0);
      final m = d.toMap();

      expect(m['size_bytes'], 0, reason: 'AUCUNE valeur hors-domaine PERSISTÉE');
      expect(m['page_count'], isNull);

      final relu = ZStudyDocument.fromMap(m);
      expect(relu, d, reason: 'convergence : l\'instance mémoire == la même relue '
          'du store — c\'est CELA que le round-trip doit garantir, y compris par '
          'la voie `copyWith` (et pas seulement par la voie `fromMap`).');
      expect(relu.toMap(), equals(m), reason: 'idempotence du round-trip');
    });

    test('la garde est la MÊME FONCTION NOMMÉE aux deux frontières (anti-dérive)',
        () {
      // Deux implémentations jumelles finiraient par diverger : la garde est
      // exposée, nommée, et consommée par `fromMap` ET `copyWith`.
      expect(ZStudyDocument.sanitizeSizeBytes(-1), 0);
      expect(ZStudyDocument.sanitizeSizeBytes(7), 7);
      expect(ZStudyDocument.sanitizePageCount(0), isNull);
      expect(ZStudyDocument.sanitizePageCount(null), isNull);
      expect(ZStudyDocument.sanitizePageCount(3), 3);
    });
  });

  group('barrel : les extensions générées des `ZExtensible` sont `hide`', () {
    test('`ZStudyDocumentZcrud` n\'est pas exportée par le barrel public', () {
      // Elle reste accessible en interne (import direct ci-dessus) — c'est bien
      // le BARREL qui la masque, parce que son `copyWith` généré remettrait
      // `extra`/`extension` aux défauts (perte silencieuse).
      const d = ZStudyDocument(id: 'x');
      expect(ZStudyDocumentZcrud(d).toMap()['id'], 'x');
      expect(
        ZStudyDocumentZcrud(d).toMap().containsKey('zz'),
        isFalse,
        reason: 'le toMap GÉNÉRÉ n\'étale PAS `extra` — d\'où le toMap d\'instance',
      );
    });
  });
}
