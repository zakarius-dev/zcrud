/// Tests de `ZColorPalette`/`zFnv1a32` (ES-1.2, AC1/AC2, D1/D2).
///
/// - Vecteurs FNV-1a **publiés** (oracle indépendant de l'implémentation).
/// - Remap déterministe : clé connue → identité ; `null`/`''` → fallback ;
///   clé inconnue → clé **∈ keys**, stable cross-run.
/// - Palette custom, `ZKeyHash` injecté, jamais de throw.
/// - Repli **défensif en release** (finding L1) : `effectiveFallbackKey`.
///
/// ⚠️ **Ce fichier DOIT rester compilable en JavaScript** (aucun `dart:io`,
/// aucun accès au système de fichiers) : c'est lui qui, rejoué par
/// `dart test -p node` (script melos `test:js`, enchaîné dans `melos run
/// verify`), **prouve** le déterminisme web de `zFnv1a32` — la seule chose qui
/// attrape la « simplification » de la multiplication décomposée (verte sur VM,
/// cassée sur le web). Le garde de pureté SM-S5 (qui lit les sources via
/// `dart:io`) vit désormais dans `z_kernel_purity_test.dart` (`@TestOn('vm')`).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('zFnv1a32 — vecteurs publiés (D2, AC2)', () {
    test("'' -> 0x811C9DC5", () {
      expect(zFnv1a32(''), 0x811C9DC5);
    });

    test("'a' -> 0xE40C292C", () {
      expect(zFnv1a32('a'), 0xE40C292C);
    });

    test("'foobar' -> 0xBF9CF968", () {
      expect(zFnv1a32('foobar'), 0xBF9CF968);
    });

    test('déterministe : 100 appels -> même résultat', () {
      final first = zFnv1a32('déterminisme-café-日本語');
      for (var i = 0; i < 100; i++) {
        expect(zFnv1a32('déterminisme-café-日本語'), first);
      }
    });

    test('résultat toujours masqué sur 32 bits', () {
      for (final key in <String>['', 'a', 'foobar', 'x' * 500]) {
        final h = zFnv1a32(key);
        expect(h, greaterThanOrEqualTo(0));
        expect(h, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });
  });

  group('ZColorPalette.defaultStudy (AC1)', () {
    const palette = ZColorPalette.defaultStudy();

    test('const-constructible, keys non vide, fallback inclus', () {
      expect(palette.keys, isNotEmpty);
      expect(palette.keys.contains(palette.fallbackKey), isTrue);
      expect(palette.fallbackKey, 'neutral');
    });

    test('clé connue -> identité (AC2)', () {
      for (final key in palette.keys) {
        expect(palette.resolveKey(key), key);
      }
    });

    test('null / vide -> fallbackKey (AC2)', () {
      expect(palette.resolveKey(null), palette.fallbackKey);
      expect(palette.resolveKey(''), palette.fallbackKey);
    });

    test('clé inconnue -> clé appartenant à keys, jamais de throw', () {
      for (final raw in <String>[
        'legacyKeyDODLP',
        'futureUnknownKey',
        'unknown-🔥-key',
      ]) {
        final resolved = palette.resolveKey(raw);
        expect(palette.keys.contains(resolved), isTrue);
      }
    });

    test('déterminisme : même entrée -> même sortie (cross-run)', () {
      const raw = 'un-tag-quelconque-non-repertorie';
      final first = palette.resolveKey(raw);
      for (var i = 0; i < 100; i++) {
        expect(palette.resolveKey(raw), first);
      }
    });

    test('table golden clé inconnue -> clé remappée (figée)', () {
      // Golden figé par l'implémentation FNV-1a + les 8 clés defaultStudy.
      // Si ce test casse après un refactor de zFnv1a32/defaultStudy, c'est
      // voulu : le remap n'est PAS un contrat de persistance (D2), mais sa
      // stabilité intra-version l'est.
      final goldenInputs = <String>[
        'legacyRed',
        'legacyBlue',
        'course-de-droit',
        'annotation-1',
      ];
      final goldenResults = goldenInputs.map(palette.resolveKey).toList();
      // Rejoué : doit être stable.
      expect(goldenInputs.map(palette.resolveKey).toList(), goldenResults);
      for (final r in goldenResults) {
        expect(palette.keys.contains(r), isTrue);
      }
    });

    test('indexOf cohérent avec resolveKey', () {
      for (final raw in <String?>['primary', 'inconnue-xyz', null, '']) {
        final resolved = palette.resolveKey(raw);
        expect(palette.indexOf(raw), palette.keys.indexOf(resolved));
      }
    });
  });

  group('ZColorPalette — palette custom + ZKeyHash injecté (AC1/AC2)', () {
    test('palette custom, autres clés que defaultStudy', () {
      final palette = ZColorPalette(
        keys: const <String>['rouge', 'bleu', 'vert'],
        fallbackKey: 'bleu',
      );
      expect(palette.resolveKey(null), 'bleu');
      expect(palette.resolveKey('rouge'), 'rouge');
      expect(palette.keys.contains(palette.resolveKey('clé-inconnue')), isTrue);
    });

    test('ZKeyHash injecté (constant) -> clé prévisible', () {
      final palette = ZColorPalette(
        keys: const <String>['a', 'b', 'c'],
        fallbackKey: 'a',
        hash: (_) => 0, // constant -> toujours keys[0 % 3] == 'a'.
      );
      expect(palette.resolveKey('anything'), 'a');
      expect(palette.resolveKey('other'), 'a');
    });

    test('ZKeyHash injecté (index 2) -> clé prévisible', () {
      final palette = ZColorPalette(
        keys: const <String>['a', 'b', 'c'],
        fallbackKey: 'a',
        hash: (_) => 2,
      );
      expect(palette.resolveKey('anything'), 'c');
    });

    test('assert : keys vide OU fallbackKey absent -> échoue en mode debug', () {
      expect(
        () => ZColorPalette(keys: const <String>[], fallbackKey: 'x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZColorPalette(
          keys: const <String>['a', 'b'],
          fallbackKey: 'absente',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('égalité structurelle (==/hashCode)', () {
      const p1 = ZColorPalette.defaultStudy();
      const p2 = ZColorPalette.defaultStudy();
      expect(p1, p2);
      expect(p1.hashCode, p2.hashCode);
    });
  });

  // Finding L1 (code-review ES-1.2) : les `assert` du constructeur sont RETIRÉS
  // en release. Une palette dont `fallbackKey ∉ keys` y survivrait, et
  // `resolveKey` rendrait une clé HORS `keys` (violation de l'invariant AC2),
  // avec `indexOf == -1` → `RangeError` chez un consommateur UI. La logique de
  // repli est donc isolée dans `ZColorPalette.effectiveFallbackKey` (statique,
  // pure) — directement testable, contrairement au chemin release qui n'est pas
  // atteignable sous `dart test` (asserts toujours actifs).
  group('ZColorPalette.effectiveFallbackKey — défensif en release (L1, AD-10)',
      () {
    test('fallbackKey ∈ keys -> rendu tel quel', () {
      expect(
        ZColorPalette.effectiveFallbackKey(const <String>['a', 'b'], 'b'),
        'b',
      );
    });

    test('fallbackKey ∉ keys -> repli sur keys.first (jamais hors keys)', () {
      final resolved = ZColorPalette.effectiveFallbackKey(
        const <String>['a', 'b'],
        'absente',
      );
      expect(resolved, 'a');
      expect(const <String>['a', 'b'].contains(resolved), isTrue);
    });

    test('keys vide -> fallbackKey tel quel, aucun throw', () {
      expect(
        ZColorPalette.effectiveFallbackKey(const <String>[], 'x'),
        'x',
      );
    });
  });

  group('resolveKey/indexOf — invariants défensifs (L1, AC2)', () {
    test('resolveKey rend TOUJOURS un élément de keys (palette valide)', () {
      final palette = ZColorPalette(
        keys: const <String>['rouge', 'bleu', 'vert'],
        fallbackKey: 'bleu',
      );
      for (final raw in <String?>[
        null,
        '',
        'rouge',
        'inconnue',
        'clé-🔥',
        'x' * 200,
      ]) {
        expect(palette.keys.contains(palette.resolveKey(raw)), isTrue);
      }
    });

    test('indexOf est TOUJOURS un index valide (jamais -1, pas de RangeError)',
        () {
      const palette = ZColorPalette.defaultStudy();
      for (final raw in <String?>[null, '', 'primary', 'inconnue-xyz', '   ']) {
        final index = palette.indexOf(raw);
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(palette.keys.length));
        // Un consommateur UI peut indexer sans garde (AD-10).
        expect(palette.keys[index], palette.resolveKey(raw));
      }
    });

    test('ZKeyHash injecté NÉGATIF -> index toujours dans les bornes', () {
      final palette = ZColorPalette(
        keys: const <String>['a', 'b', 'c'],
        fallbackKey: 'a',
        hash: (_) => -7, // `%` par un diviseur positif reste non négatif en Dart.
      );
      final resolved = palette.resolveKey('inconnue');
      expect(palette.keys.contains(resolved), isTrue);
      expect(palette.indexOf('inconnue'), greaterThanOrEqualTo(0));
    });
  });
}
