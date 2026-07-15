/// Tests de `ZDocumentAnnotation` (ES-2.5, FR-S8, AC5–AC13) — `ZEntity` +
/// `ZExtensible`, patron `extra` ES-2.2b INTÉGRAL, AD-19 (cœur FR), défensif
/// AD-10, clamp `[0,1]` par élément de `rects`.
///
/// Pur Dart : `dart test` (aucun `dart:io`, aucun `flutter_test`). Vecteurs à
/// **pouvoir discriminant OBSERVÉ** (leçon ES-2.3).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
// Import DIRECT : `ZDocumentAnnotationZcrud` est `hide` du barrel (son copyWith
// généré remettrait `extra`/`extension` aux défauts). Ce test prouve le masquage.
import 'package:zcrud_document/src/domain/z_document_annotation.dart'
    show ZDocumentAnnotationZcrud;
import 'package:zcrud_document/zcrud_document.dart';

/// Extension type de test (AD-4 pt.1) — round-trip d'un slot `extension` typé.
class _TestExt extends ZExtension {
  const _TestExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};

  static ZExtension? fromJsonSafe(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null;
    return ZExtension.guard<ZExtension?>(() => _TestExt(json['note'] as String));
  }

  @override
  bool operator ==(Object other) =>
      other is _TestExt && note == other.note && formatVersion == 1;

  @override
  int get hashCode => Object.hash(note, formatVersion);
}

void main() {
  group('AC5 — forme de l\'entité', () {
    test('est un `ZEntity` (id opaque nullable) ET un `ZExtensible`', () {
      const a = ZDocumentAnnotation();
      expect(a, isA<ZEntity>());
      expect(a, isA<ZExtensible>());
      expect(a.id, isNull);
      expect(a.isEphemeral, isTrue);
      expect(const ZDocumentAnnotation(id: 'x').isEphemeral, isFalse);
    });

    test('défauts sûrs du constructeur', () {
      const a = ZDocumentAnnotation();
      expect(a.docId, '');
      expect(a.page, 1);
      expect(a.kind, ZDocumentAnnotationKind.highlight);
      expect(a.colorKey, '');
      expect(a.bounds, const ZAnnotationBounds());
      expect(a.rects, isNull);
      expect(a.text, isNull);
      expect(a.createdAt, isNull);
      expect(a.extension, isNull);
      expect(a.extra, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC10 — round-trip zéro-perte (AD-4) : instance PLEINE, ≥2 rects distincts,
  // ≥1 clé inconnue (pouvoir discriminant).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC10 — round-trip zéro-perte', () {
    test('instance PLEINE : fromMap(toMap(a)) == a (égalité profonde)', () {
      final a = ZDocumentAnnotation(
        id: 'ann1',
        docId: 'doc1',
        page: 4,
        kind: ZDocumentAnnotationKind.stickyNote,
        colorKey: 'yellow',
        bounds: const ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        rects: const <ZAnnotationBounds>[
          ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
          ZAnnotationBounds(x: 0.5, y: 0.6, width: 0.2, height: 0.1),
        ],
        text: 'ma note',
        createdAt: DateTime.utc(2026, 5, 5),
        extension: const _TestExt('typed'),
        extra: const <String, dynamic>{'zz_app': 'gardee'},
      );
      final m1 = a.toMap();
      final relu =
          ZDocumentAnnotation.fromMap(m1, extensionParser: _TestExt.fromJsonSafe);
      final m2 = relu.toMap();

      expect(relu, a, reason: 'égalité PROFONDE (rects + extra + extension)');
      expect(relu.hashCode, a.hashCode);
      expect(m2, equals(m1), reason: 'toMap → fromMap → toMap IDEMPOTENT');
      expect(m1['doc_id'], 'doc1');
      expect(m1['page'], 4);
      expect(m1['kind'], 'stickyNote', reason: 'enum camelCase par NOM');
      expect(m1['color_key'], 'yellow');
      expect(m1['created_at'], '2026-05-05T00:00:00.000Z', reason: 'ISO-8601');
      expect((m1['rects'] as List).length, 2);
      expect(m1['zz_app'], 'gardee', reason: '`extra` étalé par le toMap d\'instance');
      expect(m1['extension'], <String, dynamic>{'format_version': 1, 'note': 'typed'});
    });

    test('instance MINIMALE : round-trip stable', () {
      const a = ZDocumentAnnotation();
      final m1 = a.toMap();
      final relu = ZDocumentAnnotation.fromMap(m1);
      expect(relu, a);
      expect(relu.toMap(), equals(m1));
    });

    test('rects : deux listes de contenu égal ⇒ annotations égales (deep)', () {
      const r = <ZAnnotationBounds>[ZAnnotationBounds(x: 0.1, width: 0.2)];
      const a = ZDocumentAnnotation(id: 'a', rects: r);
      const b = ZDocumentAnnotation(
        id: 'a',
        rects: <ZAnnotationBounds>[ZAnnotationBounds(x: 0.1, width: 0.2)],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      // DISCRIMINANT : un rect différent casse l'égalité.
      const c = ZDocumentAnnotation(
        id: 'a',
        rects: <ZAnnotationBounds>[ZAnnotationBounds(x: 0.9, width: 0.2)],
      );
      expect(a, isNot(equals(c)));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC9 — enum : round-trip discriminant (valeur DISTINCTE du défaut).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC9 — enum `ZDocumentAnnotationKind`', () {
    test('stickyNote ⇄ "stickyNote" (discriminant : ≠ défaut highlight)', () {
      const a = ZDocumentAnnotation(id: 'a', kind: ZDocumentAnnotationKind.stickyNote);
      expect(a.toMap()['kind'], 'stickyNote');
      final relu = ZDocumentAnnotation.fromMap(a.toMap());
      expect(relu.kind, ZDocumentAnnotationKind.stickyNote);
    });

    test('kind inconnu / null / non-String ⇒ highlight (1ʳᵉ constante, D5)', () {
      expect(ZDocumentAnnotation.fromMap(<String, dynamic>{'kind': 'zzz'}).kind,
          ZDocumentAnnotationKind.highlight);
      expect(ZDocumentAnnotation.fromMap(<String, dynamic>{'kind': null}).kind,
          ZDocumentAnnotationKind.highlight);
      expect(ZDocumentAnnotation.fromMap(<String, dynamic>{'kind': 42}).kind,
          ZDocumentAnnotationKind.highlight);
      expect(ZDocumentAnnotation.fromMap(const <String, dynamic>{}).kind,
          ZDocumentAnnotationKind.highlight);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC8 — défensif AD-10 total : map polluée, jamais de throw.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC8 — défensif AD-10 (jamais de throw)', () {
    test('FIXTURE R2 — map polluée (kind/bounds/rects/page corrompus)', () {
      final a = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'kind': 'zzz',
        'bounds': 'not-a-map',
        'rects': <dynamic>[
          <String, dynamic>{'x': 2.0, 'y': -1.0, 'width': 0.3, 'height': 0.4},
          'garbage',
        ],
        'page': -4,
      });
      expect(a.kind, ZDocumentAnnotationKind.highlight);
      expect(a.bounds, const ZAnnotationBounds(),
          reason: 'bounds corrompu ⇒ (0,0,0,0), jamais de throw du parent');
      expect(a.page, 1, reason: 'page < 1 ⇒ 1 (sanitizePage)');
      // rects : l'élément corrompu ('garbage') est IGNORÉ ; le survivant est
      // auto-clampé [0,1].
      expect(a.rects, hasLength(1));
      expect(a.rects!.single,
          const ZAnnotationBounds(x: 1.0, y: 0.0, width: 0.3, height: 0.4),
          reason: 'x:2→1, y:-1→0 (clamp par ZAnnotationBounds.fromMap)');
    });

    test('`fromMap(const {})` ne THROW PAS', () {
      expect(() => ZDocumentAnnotation.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(ZDocumentAnnotation.fromMap(const <String, dynamic>{}),
          const ZDocumentAnnotation());
    });

    test('map INTÉGRALEMENT corrompue : défauts sûrs partout, jamais de throw', () {
      final a = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'id': 42,
        'doc_id': <String>[],
        'page': 'abc',
        'kind': 3.14,
        'color_key': true,
        'bounds': <String>['x'],
        'rects': 'not-a-list',
        'text': <String, dynamic>{},
        'created_at': <String, dynamic>{},
        'extension': 'pas-une-map',
      });
      expect(a.id, isNull);
      expect(a.docId, '');
      expect(a.page, 1);
      expect(a.kind, ZDocumentAnnotationKind.highlight);
      expect(a.colorKey, '');
      expect(a.bounds, const ZAnnotationBounds());
      expect(a.rects, isNull, reason: 'rects non-liste ⇒ null');
      expect(a.text, isNull);
      expect(a.createdAt, isNull);
      expect(a.extension, isNull);
    });

    test('sanitizePage : garde nommée aux deux frontières', () {
      expect(ZDocumentAnnotation.sanitizePage(0), 1);
      expect(ZDocumentAnnotation.sanitizePage(-9), 1);
      expect(ZDocumentAnnotation.sanitizePage(1), 1);
      expect(ZDocumentAnnotation.sanitizePage(7), 7);
      // copyWith re-sanitise (2ᵉ frontière).
      expect(const ZDocumentAnnotation(id: 'a', page: 5).copyWith(page: 0).page, 1);
      expect(const ZDocumentAnnotation(id: 'a', page: 5).copyWith(page: -3).page, 1);
      expect(const ZDocumentAnnotation(id: 'a', page: 5).copyWith(page: 9).page, 9);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC6 — 🔴 AD-19 : `is_deleted` ET `updated_at` HORS-ENTITÉ (cœur de la FR).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC6 — AD-19 : clés de sync hors-entité', () {
    test(r'($FieldSpecs ∩ ZSyncMeta.reservedKeys == {}) — ni updated_at ni is_deleted',
        () {
      final specNames =
          $ZDocumentAnnotationFieldSpecs.map((s) => s.name).toSet();
      expect(specNames.intersection(ZSyncMeta.reservedKeys), isEmpty,
          reason: 'aucune clé de champ ne collisionne une clé réservée');
      expect(specNames, contains('created_at'),
          reason: 'createdAt conservé (clé distincte)');
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });

    test('(AD-19.1.b) aucun `persistAs: timestamp` sur une clé réservée', () {
      expect(
        $ZDocumentAnnotationTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
    });

    test('FIXTURE R2 — is_deleted/updated_at injectés : jamais dans extra ni toMap',
        () {
      final a = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'id': 'ann1',
        'doc_id': 'doc1',
        'is_deleted': true,
        'updated_at': '2026-01-01T00:00:00Z',
        'zz_unknown': 'x',
      });
      // extra ne capture PAS les clés de sync (propriété du store).
      expect(a.extra.containsKey('is_deleted'), isFalse);
      expect(a.extra.containsKey('updated_at'), isFalse);
      expect(a.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys), isEmpty);
      // ANTI-VACUITÉ : on ne passe pas en vidant extra — la clé INCONNUE survit.
      expect(a.extra['zz_unknown'], 'x');

      final m = a.toMap();
      expect(m.containsKey('is_deleted'), isFalse);
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('isDeleted'), isFalse);
      expect(m.containsKey('updatedAt'), isFalse);
      // round-trip AD-4 non régressé : la clé inconnue est bien réémise.
      expect(m['zz_unknown'], 'x');
    });

    test('convergence : instance mémoire == la même relue d\'un STORE', () {
      final fromStore = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'id': 'ann1',
        'doc_id': 'doc1',
        'page': 2,
        'updated_at': '2026-05-05T00:00:00.000Z',
        'is_deleted': false,
      });
      const inMemory =
          ZDocumentAnnotation(id: 'ann1', docId: 'doc1', page: 2);
      expect(fromStore.extra, isEmpty);
      expect(fromStore, inMemory);
      expect(fromStore.hashCode, inMemory.hashCode);
    });

    test('`extension` est réservée (jamais capturée dans extra)', () {
      final a = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'extension': <String, dynamic>{'format_version': 1},
      });
      expect(a.extra.containsKey('extension'), isFalse);
      expect(a.extension, isNull, reason: 'aucun parser injecté ⇒ repli null');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC7 — patron `extra` ES-2.2b : accesseur normalisant, garde partagée,
  // copyWith à sentinelle. Le ctor `const` POLLUÉ ne fuit jamais une clé réservée.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC7 — patron `extra` ES-2.2b', () {
    test('ctor POLLUÉ (clé réservée dans extra) ⇒ accesseur la STRIPPE', () {
      const a = ZDocumentAnnotation(
        id: 'a',
        extra: <String, dynamic>{
          'updated_at': 'triche',
          'is_deleted': true,
          'zz_ok': 'v',
        },
      );
      // L'accesseur NORMALISE : les clés réservées disparaissent, l'inconnue reste.
      expect(a.extra.containsKey('updated_at'), isFalse);
      expect(a.extra.containsKey('is_deleted'), isFalse);
      expect(a.extra['zz_ok'], 'v');
      // Et toMap() ne les réémet pas non plus.
      final m = a.toMap();
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('is_deleted'), isFalse);
    });

    test('copyWith(extra:) applique la MÊME garde (ne rouvre pas le filtre)', () {
      const a = ZDocumentAnnotation(id: 'a');
      final c = a.copyWith(extra: <String, dynamic>{
        'updated_at': 'triche',
        'zz_ok': 'v',
      });
      expect(c.extra.containsKey('updated_at'), isFalse);
      expect(c.extra['zz_ok'], 'v');
      expect(c.toMap().containsKey('updated_at'), isFalse);
    });

    test('copyWith à sentinelle : argument omis ⇒ conservé, extension/extra compris',
        () {
      final a = ZDocumentAnnotation.fromMap(<String, dynamic>{
        'id': 'a',
        'zz_app': 'v',
      });
      final c = a.copyWith(colorKey: 'blue');
      expect(c.colorKey, 'blue');
      expect(c.id, 'a');
      expect(c.extra['zz_app'], 'v',
          reason: 'le copyWith GÉNÉRÉ aurait remis extra au défaut — masqué par '
              'le copyWith d\'instance');
    });

    test('copyWith : `null` explicite ⇒ reset (distinct de « non fourni »)', () {
      const a = ZDocumentAnnotation(id: 'a', text: 'note', rects: <ZAnnotationBounds>[]);
      expect(a.copyWith(id: null).id, isNull);
      expect(a.copyWith(text: null).text, isNull);
      expect(a.copyWith(rects: null).rects, isNull);
      expect(a.copyWith().text, 'note');
    });

    test('colorKey BRUT — aucun clamp (D6)', () {
      const a = ZDocumentAnnotation(id: 'a', colorKey: 'ma-couleur-libre-#42');
      expect(a.toMap()['color_key'], 'ma-couleur-libre-#42');
      expect(ZDocumentAnnotation.fromMap(a.toMap()).colorKey,
          'ma-couleur-libre-#42');
    });
  });

  group('AC15 — NFR-S3/SM-S5 : la map persistée ne porte que des types NEUTRES', () {
    test('aucun Timestamp/Color/type cloud_firestore', () {
      final m = ZDocumentAnnotation(
        id: 'a',
        kind: ZDocumentAnnotationKind.stickyNote,
        bounds: const ZAnnotationBounds(x: 0.1),
        rects: const <ZAnnotationBounds>[ZAnnotationBounds(x: 0.2)],
        createdAt: DateTime.utc(2026),
        extension: const _TestExt('t'),
      ).toMap();
      void checkNeutral(Object? v) {
        if (v is Map) {
          for (final e in v.values) {
            checkNeutral(e);
          }
        } else if (v is List) {
          for (final e in v) {
            checkNeutral(e);
          }
        } else {
          expect(v == null || v is String || v is num || v is bool, isTrue,
              reason: 'type non neutre : $v (${v.runtimeType})');
        }
      }

      checkNeutral(m);
    });
  });

  group('AC13 — l\'extension générée est `hide` du barrel', () {
    test('`ZDocumentAnnotationZcrud` accessible en INTERNE, masquée du barrel', () {
      const a = ZDocumentAnnotation(id: 'x');
      expect(ZDocumentAnnotationZcrud(a).toMap()['id'], 'x');
      expect(ZDocumentAnnotationZcrud(a).toMap().containsKey('zz'), isFalse,
          reason: 'le toMap GÉNÉRÉ n\'étale PAS extra — d\'où le toMap d\'instance');
    });
  });
}
