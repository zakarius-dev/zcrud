/// AC6 / AC9 / AC11 — `ZDocumentReadingState` : `learning` **hors-codegen**,
/// **zéro clé LWW interne**, désérialisation imbriquée défensive.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('AC6 / D8 — forme de l\'entité', () {
    test('est `ZExtensible` mais N\'EST PAS un `ZEntity` (clé = docId)', () {
      const s = ZDocumentReadingState();
      expect(s, isA<ZExtensible>());
      expect(
        s,
        isNot(isA<ZEntity>()),
        reason: 'D8 : jointure 1↔1 par `docId` (patron ZRepetitionInfo/flashcardId) '
            '— aucun `id` propre, aucune réconciliation.',
      );
    });

    test('défauts sûrs', () {
      const s = ZDocumentReadingState();
      expect(s.docId, '');
      expect(s.currentPage, 1, reason: '1-based : première ouverture');
      expect(s.pageCount, isNull);
      expect(s.prefs, const ZDocumentViewerPrefs());
      expect(s.learning, ZDocumentLearningInfo.empty);
      expect(s.extension, isNull);
      expect(s.extra, isEmpty);
    });

    test('round-trip STABLE (idempotent) — instance PLEINE', () {
      const s = ZDocumentReadingState(
        docId: 'd1',
        currentPage: 7,
        pageCount: 42,
        prefs: ZDocumentViewerPrefs(
          zoomLevel: 2.0,
          scrollDirection: ZDocumentScrollDirection.horizontal,
          pageLayout: ZDocumentPageLayout.single,
        ),
        learning: ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2, 3: 0}),
        extra: <String, dynamic>{'zz_app': 'v'},
      );
      final m1 = s.toMap();
      final relu = ZDocumentReadingState.fromMap(m1);
      final m2 = relu.toMap();

      expect(relu, s);
      expect(m2, equals(m1), reason: 'toMap → fromMap → toMap est IDEMPOTENT');
      expect(m1['doc_id'], 'd1');
      expect(m1['current_page'], 7);
      expect(m1['page_count'], 42);
      expect(m1['prefs'], isA<Map<String, dynamic>>());
      expect((m1['prefs'] as Map)['zoom_level'], 2.0);
      expect(m1['learning'],
          equals(<String, dynamic>{'quality_by_page': <String, dynamic>{'1': 2, '3': 0}}));
      expect(m1['zz_app'], 'v');
    });

    test('round-trip STABLE — instance MINIMALE', () {
      const s = ZDocumentReadingState();
      final m1 = s.toMap();
      expect(ZDocumentReadingState.fromMap(m1), s);
      expect(ZDocumentReadingState.fromMap(m1).toMap(), equals(m1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC6 / D4 — `learning` = CANAL HORS-CODEGEN (patron `ZFlashcard.source`).
  //
  // ⚠️ Le générateur ne supporte AUCUN type `Map` (D3) ⇒ `ZDocumentLearningInfo`
  // n'est PAS un `@ZcrudModel` ⇒ `learning` ne PEUT PAS être un `@ZcrudField`.
  // Il est décodé/réémis À LA MAIN, et sa clé est RÉSERVÉE — sinon elle
  // atterrirait dans `extra` ET serait émise EN DOUBLE.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC6 / D4 — `learning` : canal HORS-CODEGEN, OBSERVÉ (anti-H2)', () {
    test('`learning` n\'est PAS un champ du schéma généré', () {
      final specNames =
          $ZDocumentReadingStateFieldSpecs.map((s) => s.name).toSet();
      expect(
        specNames,
        isNot(contains('learning')),
        reason: 'D3/D4 : `Map<int,int>` n\'est pas (dé)sérialisable par le '
            'générateur — l\'annoter ferait ÉCHOUER LE BUILD.',
      );
      expect(specNames, equals(<String>{'doc_id', 'current_page', 'page_count', 'prefs'}));
    });

    test('DÉCODÉ à la main : la map imbriquée est reconstruite', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'learning': <String, dynamic>{
          'quality_by_page': <String, dynamic>{'1': 2, '5': 0},
        },
      });
      expect(s.learning.qualityByPage, equals(<int, int>{1: 2, 5: 0}));
      expect(s.learning.masteredCount, 1);
      expect(s.learning.isMastered(1), isTrue);
    });

    test('RÉÉMIS à la main : `learning` est TOUJOURS dans toMap (même vide)', () {
      expect(const ZDocumentReadingState().toMap()['learning'],
          equals(<String, dynamic>{'quality_by_page': <String, dynamic>{}}));
    });

    test('sa clé est RÉSERVÉE : jamais dans `extra`, jamais émise EN DOUBLE', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'learning': <String, dynamic>{
          'quality_by_page': <String, dynamic>{'2': 2},
        },
      });
      expect(s.extra.containsKey('learning'), isFalse,
          reason: 'sinon elle serait réémise DEUX fois (une par `...extra`, une '
              'par le câblage manuel) ⇒ round-trip non idempotent, `==` cassée.');
      final m = s.toMap();
      expect(m['learning'],
          equals(<String, dynamic>{'quality_by_page': <String, dynamic>{'2': 2}}));
      // Idempotence prouvée : relire puis réémettre rend la MÊME map.
      expect(ZDocumentReadingState.fromMap(m).toMap(), equals(m));
    });

    test('CORROMPU : `learning` non-map / absent ⇒ `empty`, JAMAIS de throw', () {
      for (final raw in <Object?>[null, 42, 'x', true, <String>[]]) {
        final s = ZDocumentReadingState.fromMap(<String, dynamic>{'learning': raw});
        expect(s.learning, ZDocumentLearningInfo.empty, reason: 'raw = $raw');
      }
      expect(
        ZDocumentReadingState.fromMap(const <String, dynamic>{}).learning,
        ZDocumentLearningInfo.empty,
      );
    });

    test('CORROMPU : `learning` avec entrées invalides ⇒ entrées ignorées', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'learning': <String, dynamic>{
          'quality_by_page': <String, dynamic>{'0': 2, 'abc': 1, '3': 'x', '4': 2},
        },
      });
      expect(s.learning.qualityByPage, equals(<int, int>{4: 2}));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC9 — R-A / R-C : les DEUX contrôles d'AD-19.
  //
  // 🔴 lex déclare, DANS CETTE ENTITÉ : « /// Clé LWW (dernière écriture). »
  // `final DateTime updatedAt;`. Le porter aurait logé la CLÉ D'AUTORITÉ DU MERGE
  // dans le corps métier — que le store écrase à chaque `put`.
  // ═══════════════════════════════════════════════════════════════════════════
  group('ZDocumentReadingState — AD-19 : clés de sync hors-entité (AC9)', () {
    test(r'(R-C) `$ZDocumentReadingStateFieldSpecs` ∩ reservedKeys == {}', () {
      final specNames =
          $ZDocumentReadingStateFieldSpecs.map((s) => s.name).toSet();
      expect(
        specNames.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
        reason: 'lex loge ici la clé LWW `updatedAt` INLINE — la porter aurait '
            'recréé la perte de données soldée en ES-1.3 (le store écrit sa méta '
            'APRÈS le corps à chaque `put`).',
      );
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });

    test('(AD-19.1.b) aucun `persistAs: timestamp` sur une clé réservée', () {
      expect(
        $ZDocumentReadingStateTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect($ZDocumentReadingStateTimestampFields, isEmpty);
    });

    test('(R-A) fromMap d\'une map de STORE : clés de sync hors de `extra`', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'current_page': 3,
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });
      expect(s.extra.containsKey('updated_at'), isFalse);
      expect(s.extra.containsKey('is_deleted'), isFalse);
      expect(s.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys), isEmpty);
      // ANTI-VACUITÉ : on ne passe pas (a) en vidant `extra`.
      expect(s.extra['zz_cle_inconnue'], 'gardee');
      expect(s.currentPage, 3);
    });

    test('(R-A) toMap() ne RÉÉMET aucune clé de sync (AD-16)', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
      });
      final m = s.toMap();
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('is_deleted'), isFalse);
      expect(m.containsKey('updatedAt'), isFalse);
      expect(m.containsKey('isDeleted'), isFalse);
    });

    test('convergence : un état mémoire == le même relu du store', () {
      final fromStore = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'current_page': 6,
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
      });
      const inMemory = ZDocumentReadingState(docId: 'd1', currentPage: 6);
      expect(fromStore.extra, isEmpty);
      expect(fromStore, inMemory);
      expect(fromStore.hashCode, inMemory.hashCode);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC11 / R-H — invariants de valeur + désérialisation IMBRIQUÉE défensive.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — currentPage 1-based (garde + corrompu)', () {
    int page(Object? raw) =>
        ZDocumentReadingState.fromMap(<String, dynamic>{'current_page': raw})
            .currentPage;

    test('GARDE : 1 et 42 conservés', () {
      expect(page(1), 1);
      expect(page(42), 42);
    });

    test('CORROMPU : 0 / -3 / "abc" / absent / null ⇒ 1', () {
      expect(page(0), 1);
      expect(page(-3), 1);
      expect(page('abc'), 1);
      expect(page(null), 1);
      expect(page(<String, dynamic>{}), 1);
      expect(ZDocumentReadingState.fromMap(const <String, dynamic>{}).currentPage, 1);
    });

    test('currentPage >= 1 TOUJOURS (y compris via copyWith)', () {
      const s = ZDocumentReadingState(docId: 'd');
      expect(s.copyWith(currentPage: 0).currentPage, 1);
      expect(s.copyWith(currentPage: -9).currentPage, 1);
      expect(s.copyWith(currentPage: 5).currentPage, 5);
    });
  });

  group('AC11 — pageCount (garde + corrompu)', () {
    int? count(Object? raw) =>
        ZDocumentReadingState.fromMap(<String, dynamic>{'page_count': raw}).pageCount;

    test('GARDE : 12 conservé', () => expect(count(12), 12));

    test('CORROMPU : 0 / -1 / "x" / null ⇒ null', () {
      expect(count(0), isNull);
      expect(count(-1), isNull);
      expect(count('x'), isNull);
      expect(count(null), isNull);
      expect(ZDocumentReadingState.fromMap(const <String, dynamic>{}).pageCount, isNull);
    });

    test('copyWith sanitise aussi', () {
      const s = ZDocumentReadingState(docId: 'd', pageCount: 10);
      expect(s.copyWith(pageCount: 0).pageCount, isNull);
      expect(s.copyWith(pageCount: -1).pageCount, isNull);
      expect(s.copyWith(pageCount: 20).pageCount, 20);
    });
  });

  group('AC6 — désérialisation IMBRIQUÉE défensive (AD-10 / NFR-S4)', () {
    test('`prefs: 42` (non-map) ⇒ préférences par DÉFAUT, jamais de throw', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{'prefs': 42});
      expect(s.prefs, const ZDocumentViewerPrefs());
    });

    test('`prefs` : toute forme corrompue ⇒ défauts', () {
      for (final raw in <Object?>[42, 'x', true, <String>[], null]) {
        final s = ZDocumentReadingState.fromMap(<String, dynamic>{'prefs': raw});
        expect(s.prefs, const ZDocumentViewerPrefs(), reason: 'raw = $raw');
      }
    });

    test('`prefs` PARTIELLEMENT corrompue ⇒ champs sains conservés, zoom borné',
        () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'prefs': <String, dynamic>{
          'zoom_level': -5, // ⇒ 1.0
          'scroll_direction': 'horizontal', // conservé
          'page_layout': 'zz_inconnu', // ⇒ continuous
        },
      });
      expect(s.prefs.zoomLevel, kDefaultZoomLevel);
      expect(s.prefs.scrollDirection, ZDocumentScrollDirection.horizontal);
      expect(s.prefs.pageLayout, ZDocumentPageLayout.continuous);
    });

    test('MAP ENTIÈREMENT CORROMPUE : aucun throw, tous défauts sûrs', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 42,
        'current_page': 'abc',
        'page_count': -1,
        'prefs': 42,
        'learning': 'x',
        'extension': <String>[],
      });
      expect(s.docId, '');
      expect(s.currentPage, 1);
      expect(s.pageCount, isNull);
      expect(s.prefs, const ZDocumentViewerPrefs());
      expect(s.learning, ZDocumentLearningInfo.empty);
      expect(s.extension, isNull);
    });

    test('AC11 — `fromMap(const {})` ne THROW PAS (map vide)', () {
      expect(() => ZDocumentReadingState.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(ZDocumentReadingState.fromMap(const <String, dynamic>{}),
          const ZDocumentReadingState());
    });
  });

  group('copyWith d\'instance : canaux hors-codegen préservés', () {
    test('argument omis ⇒ conservé (learning / extra / extension compris)', () {
      final s = ZDocumentReadingState.fromMap(<String, dynamic>{
        'doc_id': 'd1',
        'learning': <String, dynamic>{
          'quality_by_page': <String, dynamic>{'1': 2},
        },
        'zz_app': 'v',
      });
      final c = s.copyWith(currentPage: 4);
      expect(c.currentPage, 4);
      expect(c.learning.qualityByPage, equals(<int, int>{1: 2}),
          reason: 'le copyWith GÉNÉRÉ ignore `learning` (hors-codegen)');
      expect(c.extra['zz_app'], 'v');
      expect(c.docId, 'd1');
    });
  });
}
