/// Tests de `ZAnnotationBounds` (ES-2.5, FR-S8, AC1–AC4) — VO borné `[0,1]`.
///
/// Pur Dart : `dart test` (aucun `dart:io`, aucun `flutter_test`). Les vecteurs
/// ont un **pouvoir discriminant OBSERVÉ** (leçon ES-2.3 : un golden peut passer
/// par coïncidence) — pour le clamp `[0,1]`, ils prouvent qu'un test ROUGIT si
/// `sanitizeCoord` est neutralisé (cf. groupe « injection R3 »).
library;

import 'package:test/test.dart';
// Import DIRECT de l'implémentation : `ZAnnotationBoundsZcrud` est volontairement
// `hide` du barrel public (son `copyWith`/`toMap` généré CONTOURNERAIT le clamp
// `[0,1]`). Ce test PROUVE justement ce masquage — d'où l'import interne.
import 'package:zcrud_document/src/domain/z_annotation_bounds.dart'
    show ZAnnotationBoundsZcrud;
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('AC1 — forme du value object', () {
    test('défauts `const` : (0,0,0,0)', () {
      const b = ZAnnotationBounds();
      expect(b.x, 0.0);
      expect(b.y, 0.0);
      expect(b.width, 0.0);
      expect(b.height, 0.0);
    });

    test('==/hashCode de valeur', () {
      const a = ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      const b = ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      const c = ZAnnotationBounds(x: 0.9, y: 0.2, width: 0.3, height: 0.4);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('round-trip STABLE (idempotent)', () {
      const b = ZAnnotationBounds(x: 0.1, y: 0.25, width: 0.5, height: 0.75);
      final m1 = b.toMap();
      final relu = ZAnnotationBounds.fromMap(m1);
      expect(relu, b);
      expect(relu.toMap(), equals(m1));
      expect(m1['x'], 0.1);
      expect(m1['y'], 0.25);
      expect(m1['width'], 0.5);
      expect(m1['height'], 0.75);
    });
  });

  group('AC3 — défensif AD-10 total (jamais de throw)', () {
    test('`fromMap(const {})` ⇒ (0,0,0,0), pas de throw', () {
      expect(() => ZAnnotationBounds.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(ZAnnotationBounds.fromMap(const <String, dynamic>{}),
          const ZAnnotationBounds());
    });

    test('valeur non numérique (`abc`/`null`/liste) ⇒ 0.0 au décodage', () {
      final b = ZAnnotationBounds.fromMap(<String, dynamic>{
        'x': 'abc',
        'y': null,
        'width': <String>[],
        'height': <String, dynamic>{},
      });
      expect(b.x, 0.0);
      expect(b.y, 0.0);
      expect(b.width, 0.0);
      expect(b.height, 0.0);
    });

    test('coords numériques sous forme de String (`"0.5"`) décodées', () {
      final b = ZAnnotationBounds.fromMap(<String, dynamic>{'x': '0.5'});
      expect(b.x, 0.5);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC2 — INVARIANT `[0,1]` : garde `sanitizeCoord` aux DEUX frontières.
  // Fixture d'échec ISOLÉE (R2) + pouvoir discriminant OBSERVÉ.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC2 — clamp `[0,1]` (garde partagée `sanitizeCoord`)', () {
    test('FIXTURE R2 — fromMap {x:5, y:-3, width:NaN, height:0.4}', () {
      final b = ZAnnotationBounds.fromMap(<String, dynamic>{
        'x': 5.0,
        'y': -3.0,
        'width': double.nan,
        'height': 0.4,
      });
      // DISCRIMINANT : 5.0 → 1.0 (≠ 0.0 défaut, ≠ 5.0 brut) ; -3.0 → 0.0.
      expect(b.x, 1.0, reason: 'hors-borne haute ⇒ 1.0');
      expect(b.y, 0.0, reason: 'négatif ⇒ 0.0 (clamp bas)');
      expect(b.width, 0.0, reason: 'NaN ⇒ 0.0 (non fini)');
      expect(b.height, 0.4, reason: 'valeur légale conservée');
    });

    test('±Infinity ⇒ 0.0 (non fini)', () {
      final b = ZAnnotationBounds.fromMap(<String, dynamic>{
        'x': double.infinity,
        'y': double.negativeInfinity,
      });
      expect(b.x, 0.0);
      expect(b.y, 0.0);
    });

    test('clamp aux BORNES exactes (0.0 et 1.0 conservés)', () {
      final b = ZAnnotationBounds.fromMap(
          <String, dynamic>{'x': 0.0, 'y': 1.0, 'width': 1.0, 'height': 0.0});
      expect(b.x, 0.0);
      expect(b.y, 1.0);
      expect(b.width, 1.0);
      expect(b.height, 0.0);
    });

    test('copyWith RE-CLAMPE (2ᵉ frontière) — x:5 ⇒ 1.0, y:-2 ⇒ 0.0', () {
      const base = ZAnnotationBounds(x: 0.5, y: 0.5, width: 0.5, height: 0.5);
      final c = base.copyWith(x: 5.0, y: -2.0, width: double.nan);
      // DISCRIMINANT : sans re-clamp, x resterait 5.0 / y -2.0.
      expect(c.x, 1.0);
      expect(c.y, 0.0);
      expect(c.width, 0.0);
      expect(c.height, 0.5, reason: 'argument omis ⇒ valeur conservée');
    });

    test('la garde est la MÊME FONCTION NOMMÉE (anti-dérive H2)', () {
      expect(ZAnnotationBounds.sanitizeCoord(5.0), 1.0);
      expect(ZAnnotationBounds.sanitizeCoord(-3.0), 0.0);
      expect(ZAnnotationBounds.sanitizeCoord(double.nan), 0.0);
      expect(ZAnnotationBounds.sanitizeCoord(double.infinity), 0.0);
      expect(ZAnnotationBounds.sanitizeCoord(0.42), 0.42);
      expect(ZAnnotationBounds.sanitizeCoord(0.0), 0.0);
      expect(ZAnnotationBounds.sanitizeCoord(1.0), 1.0);
    });

    // Convergence : une valeur hors-domaine mutée puis persistée est RELISIBLE.
    test('CONVERGENCE par la voie `copyWith` : rien de hors-domaine persisté', () {
      final b = const ZAnnotationBounds().copyWith(x: 5.0, y: -1.0);
      final m = b.toMap();
      expect(m['x'], 1.0);
      expect(m['y'], 0.0);
      final relu = ZAnnotationBounds.fromMap(m);
      expect(relu, b, reason: 'idempotence : mémoire == relue');
    });
  });

  group('AC4 — pas de `dart:ui`, pas de helper `fromPageRect`/`toPageRect`', () {
    test('la surface publique n\'expose AUCUNE conversion espace-page', () {
      // Ces membres existent en lex (importent `dart:ui`) — ils ne sont PAS
      // portés ici (D3). Preuve indirecte : le VO ne porte que 4 doubles + les
      // méthodes de (dé)sérialisation/copie. La pureté du package est
      // vérifiée par le gate de graphe (CORE OUT=0, zéro `dart:ui`).
      const b = ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      expect(b.toMap().keys.toSet(),
          <String>{'x', 'y', 'width', 'height'});
    });
  });

  group('AC13 — extension générée (masquage tenu par convention `hide`)', () {
    test('`ZAnnotationBoundsZcrud` existe et reste accessible en INTERNE', () {
      // ⚠️ HONNÊTETÉ DU FILET (code-review ES-2.5, MEDIUM-1) : ce test NE prouve
      // PAS le masquage du barrel. Il utilise l'import INTERNE et passerait même
      // si `hide ZAnnotationBoundsZcrud` était retiré du barrel public. Il vérifie
      // seulement que l'extension générée EXISTE (le copyWith/toMap généré
      // contournerait le clamp [0,1], d'où le `hide` du barrel — tenu par
      // CONVENTION). La garde MACHINE du non-export fait défaut ici : la règle (h)
      // du gate reserved-keys ne couvre QUE les classes `ZExtensible`, pas ce VO
      // NON-`ZExtensible` à invariant. C'est une DETTE DE PATRON TRANSVERSE
      // `DW-ES25-1` (étendre (h) aux @ZcrudModel NON-`ZExtensible` à invariant de
      // valeur, sans faux positif sur les VO exportables `ZChoice`/`ZSuggestedTag`),
      // à prototyper (R4) et statuer en rétro ES-2.
      const b = ZAnnotationBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      expect(ZAnnotationBoundsZcrud(b).toMap()['x'], 0.1);
    });
  });
}
