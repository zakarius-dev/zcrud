// Tests PUR-DART (sans `BuildContext`) de la politique par défaut : table de
// vérité du mapping Material 3 (AC4/D4/D5) + déterminisme + défaut `formWeight`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

void main() {
  group('ZPresentationPolicy (défaut Material 3) — table de vérité', () {
    const policy = ZPresentationPolicy();

    test('compact → sheet (quel que soit le poids)', () {
      expect(
        policy.resolve(ZWindowSizeClass.compact, formWeight: ZFormWeight.light),
        ZEditionPresentation.sheet,
      );
      expect(
        policy.resolve(ZWindowSizeClass.compact, formWeight: ZFormWeight.heavy),
        ZEditionPresentation.sheet,
      );
    });

    test('medium → dialog (quel que soit le poids)', () {
      expect(
        policy.resolve(ZWindowSizeClass.medium, formWeight: ZFormWeight.light),
        ZEditionPresentation.dialog,
      );
      expect(
        policy.resolve(ZWindowSizeClass.medium, formWeight: ZFormWeight.heavy),
        ZEditionPresentation.dialog,
      );
    });

    test('expanded + light → dialog', () {
      expect(
        policy.resolve(ZWindowSizeClass.expanded, formWeight: ZFormWeight.light),
        ZEditionPresentation.dialog,
      );
    });

    test('expanded + heavy → page', () {
      expect(
        policy.resolve(ZWindowSizeClass.expanded, formWeight: ZFormWeight.heavy),
        ZEditionPresentation.page,
      );
    });

    test('alias const .material() donne le même mapping', () {
      const material = ZPresentationPolicy.material();
      for (final sizeClass in ZWindowSizeClass.values) {
        for (final weight in ZFormWeight.values) {
          expect(
            material.resolve(sizeClass, formWeight: weight),
            policy.resolve(sizeClass, formWeight: weight),
          );
        }
      }
    });
  });

  group('ZPresentationPolicy — défaut du paramètre `formWeight`', () {
    const policy = ZPresentationPolicy();

    test('formWeight omis == light', () {
      // Sur `expanded`, light → dialog : prouve que le défaut est bien `light`.
      expect(
        policy.resolve(ZWindowSizeClass.expanded),
        ZEditionPresentation.dialog,
      );
      for (final sizeClass in ZWindowSizeClass.values) {
        expect(
          policy.resolve(sizeClass),
          policy.resolve(sizeClass, formWeight: ZFormWeight.light),
        );
      }
    });
  });

  group('ZPresentationPolicy — déterminisme', () {
    const policy = ZPresentationPolicy();

    test('deux appels identiques donnent le même résultat', () {
      for (final sizeClass in ZWindowSizeClass.values) {
        for (final weight in ZFormWeight.values) {
          final first = policy.resolve(sizeClass, formWeight: weight);
          final second = policy.resolve(sizeClass, formWeight: weight);
          expect(first, second);
        }
      }
    });

    test('exhaustivité : chaque combinaison retourne un mode (jamais de throw)',
        () {
      for (final sizeClass in ZWindowSizeClass.values) {
        for (final weight in ZFormWeight.values) {
          expect(
            () => policy.resolve(sizeClass, formWeight: weight),
            returnsNormally,
          );
          expect(
            policy.resolve(sizeClass, formWeight: weight),
            isA<ZEditionPresentation>(),
          );
        }
      }
    });
  });
}
