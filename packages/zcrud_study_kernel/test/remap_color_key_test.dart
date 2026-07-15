/// Tests de `remapColorKey` (ES-2.3, FR-S6, AC3/AC11 — décision D3).
///
/// PUR · TOTAL · DÉTERMINISTE · palette INJECTÉE · jamais `crypto` · jamais
/// hors-palette. Les **vecteurs golden** épinglent le remap DÉTERMINISTE (via
/// l'algorithme FNV-1a JS-safe de la palette) — c'est eux qui rougissent si le
/// hash injecté est remplacé (injection R3 n°5).
///
/// ⚠️ **Aucun `dart:io`** (AC14) — compilable en JavaScript (patron
/// `z_color_palette_test.dart`).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  final palette = const ZColorPalette.defaultStudy();
  // keys neutres : [primary, secondary, tertiary, success, warning, danger,
  // info, neutral] ; fallbackKey = 'neutral' ; hash = zFnv1a32 (JS-safe).

  group('remapColorKey — clé connue → identité (AC3)', () {
    test('clé exacte de la palette rendue telle quelle', () {
      expect(
        remapColorKey(palette: palette, rawColorKey: 'warning', seedTitle: 'x'),
        'warning',
      );
    });

    test('casse/espaces normalisés puis identité si connue', () {
      expect(
        remapColorKey(palette: palette, rawColorKey: '  WARNING '),
        'warning',
      );
    });
  });

  group('remapColorKey — clé inconnue → remap déterministe ∈ keys (AC3)', () {
    test('résultat TOUJOURS ∈ palette.keys, pour toute combinaison', () {
      final raws = <String?>[null, '', 'blue', 'zzz_inconnue', 'warning'];
      final seeds = <String?>[null, '', 'Droit', 'x', 'warning'];
      for (final r in raws) {
        for (final s in seeds) {
          final out = remapColorKey(palette: palette, rawColorKey: r, seedTitle: s);
          expect(palette.keys, contains(out),
              reason: 'raw=$r seed=$s -> $out hors palette');
        }
      }
    });

    test('jamais de throw (matrice complète)', () {
      expect(
        () => remapColorKey(palette: palette, rawColorKey: null, seedTitle: null),
        returnsNormally,
      );
    });
  });

  group('remapColorKey — VECTEURS GOLDEN (déterminisme, D3/AC3)', () {
    // 🔴 Oracle FIGÉ (dérivé de zFnv1a32 % 8 sur les keys neutres ordonnées) :
    // c'est ce qui ROUGIT si le `hash` injecté de la palette change (injection
    // R3 n°5). Mêmes entrées → MÊME sortie, cross-plateforme.
    const golden = <String, String>{
      'Droit Douanier': 'tertiary', // fnv1a32 % 8 == 2
      'tag inconnu': 'neutral', //     == 7
      'zzz': 'danger', //              == 5
      'x': 'neutral', //               == 7
    };

    golden.forEach((seed, expected) {
      test("seed '$seed' -> $expected (rawColorKey inconnue)", () {
        expect(
          remapColorKey(
            palette: palette,
            rawColorKey: 'inconnue_hors_palette',
            seedTitle: seed,
          ),
          expected,
        );
      });
    });

    test('déterministe : 100 appels -> même sortie', () {
      final first =
          remapColorKey(palette: palette, rawColorKey: 'zz', seedTitle: 'Droit');
      for (var i = 0; i < 100; i++) {
        expect(
          remapColorKey(palette: palette, rawColorKey: 'zz', seedTitle: 'Droit'),
          first,
        );
      }
    });

    test('sémantique lex « même seedTitle → même clé » (AC3)', () {
      final a = remapColorKey(
          palette: palette, rawColorKey: 'inconnue', seedTitle: 'Droit Douanier');
      final b = remapColorKey(
          palette: palette, rawColorKey: 'autre_inconnue', seedTitle: 'Droit Douanier');
      expect(a, b); // la graine gouverne, pas la clé brute inconnue
      expect(a, 'tertiary');
    });

    test('raw null/vide + seed présent remappe sur le seed', () {
      expect(remapColorKey(palette: palette, seedTitle: 'Droit Douanier'),
          'tertiary');
      expect(remapColorKey(palette: palette, rawColorKey: '', seedTitle: 'zzz'),
          'danger');
    });

    test('raw null + seed null -> fallbackKey de la palette', () {
      expect(remapColorKey(palette: palette), 'neutral');
    });
  });

  group('remapColorKey — palette INJECTÉE (AC3, jamais 8 clés lex en dur)', () {
    test('deux palettes différentes -> mappings différents', () {
      final p2 = ZColorPalette(
        keys: const <String>['a', 'b', 'c'],
        fallbackKey: 'a',
      );
      final out = remapColorKey(palette: p2, rawColorKey: 'zz', seedTitle: 'zzz');
      expect(p2.keys, contains(out));
      // clé connue de p2 rendue telle quelle (pas de remap)
      expect(remapColorKey(palette: p2, rawColorKey: 'b'), 'b');
    });

    test(
        'LOW-1 — clé connue en CASSE EXACTE non-minuscule rendue VERBATIM '
        '(identité stricte, cohérente avec resolveKey)', () {
      // Palette à clés NON-minuscules portant un hash CONSTANT (=1) : tout remap
      // d'une clé INCONNUE renvoie DÉTERMINISTEMENT keys[1] == 'Green'. Une clé
      // connue en casse exacte AUTRE que l'index-1 (ici 'Blue'@0, 'Red'@2) diverge
      // donc GARANTIEMENT si elle transite par le remap-hash — ce test a un
      // POUVOIR DISCRIMINANT observé (l'ancien code `toLowerCase`-only le fait
      // ROUGIR), il ne « passe » pas par coïncidence de hash (motif dominant du
      // projet : seul un rouge provoqué prouve un filet).
      final pMixedCase = ZColorPalette(
        keys: const <String>['Blue', 'Green', 'Red'],
        fallbackKey: 'Blue',
        hash: (_) => 1, // remap(inconnu) -> keys[1] == 'Green'
      );
      // Casse exacte hors index-1 → identité stricte (verbatim), jamais remappée
      // (l'ancien code aurait renvoyé 'Green' via le hash).
      expect(remapColorKey(palette: pMixedCase, rawColorKey: 'Blue'), 'Blue');
      expect(remapColorKey(palette: pMixedCase, rawColorKey: '  Red '), 'Red');
      // Contrôle : une clé RÉELLEMENT inconnue remappe bien vers keys[1].
      expect(
        remapColorKey(palette: pMixedCase, rawColorKey: 'zzz', seedTitle: 'zzz'),
        'Green',
      );
      // Le contrat général tient toujours : résultat ∈ keys, jamais de throw.
      final out = remapColorKey(
          palette: pMixedCase, rawColorKey: 'inconnue', seedTitle: 'x');
      expect(pMixedCase.keys, contains(out));
    });

    test('🔴 INJECTION R3 n°5 — hash injecté gouverne le golden (déterminisme)',
        () {
      // Palette EXPLICITE portant l'algorithme JS-safe `zFnv1a32`. Le golden
      // 'Droit Douanier' -> 'tertiary' n'est vrai QUE parce que ce hash est
      // injecté. Remplacer `hash: zFnv1a32` par un `hash` constant/`String
      // .hashCode` DANS CE TEST fait ROUGIR l'assertion ci-dessous (injection R3
      // n°5) — prouvant que le remap dépend BIEN de l'algorithme injecté, jamais
      // d'un hash local dupliqué (R6).
      final p = ZColorPalette(
        keys: const <String>[
          'primary',
          'secondary',
          'tertiary',
          'success',
          'warning',
          'danger',
          'info',
          'neutral',
        ],
        fallbackKey: 'neutral',
        hash: zFnv1a32, // ← cible de l'injection R3 n°5
      );
      expect(
        remapColorKey(palette: p, rawColorKey: 'inconnue', seedTitle: 'Droit Douanier'),
        'tertiary',
      );
    });
  });
}
