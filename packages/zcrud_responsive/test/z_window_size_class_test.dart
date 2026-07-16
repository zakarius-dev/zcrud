// Tests PURS (sans BuildContext) de la résolution `width → ZWindowSizeClass`
// (AC3, D4). Vérifie les bornes M3 (599/600/839/840) et les défauts sûrs
// (0/-1/NaN/infinity) — jamais de throw (AD-10).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

void main() {
  group('ZWindowSizeClass.fromWidth — bornes M3 (600/840)', () {
    test('599 → compact (juste sous le seuil medium)', () {
      expect(ZWindowSizeClass.fromWidth(599), ZWindowSizeClass.compact);
    });

    test('600 → medium (seuil inclusif)', () {
      expect(ZWindowSizeClass.fromWidth(600), ZWindowSizeClass.medium);
    });

    test('839 → medium (juste sous le seuil expanded)', () {
      expect(ZWindowSizeClass.fromWidth(839), ZWindowSizeClass.medium);
    });

    test('840 → expanded (seuil inclusif)', () {
      expect(ZWindowSizeClass.fromWidth(840), ZWindowSizeClass.expanded);
    });

    test('valeurs intermédiaires nominales', () {
      expect(ZWindowSizeClass.fromWidth(500), ZWindowSizeClass.compact);
      expect(ZWindowSizeClass.fromWidth(700), ZWindowSizeClass.medium);
      expect(ZWindowSizeClass.fromWidth(1000), ZWindowSizeClass.expanded);
    });
  });

  group('ZWindowSizeClass.fromWidth — défauts sûrs (AD-10, jamais de throw)', () {
    test('0 → compact', () {
      expect(ZWindowSizeClass.fromWidth(0), ZWindowSizeClass.compact);
    });

    test('-1 (négatif) → compact', () {
      expect(ZWindowSizeClass.fromWidth(-1), ZWindowSizeClass.compact);
    });

    test('NaN → compact (comparaisons NaN >= seuil toujours false)', () {
      expect(ZWindowSizeClass.fromWidth(double.nan), ZWindowSizeClass.compact);
    });

    test('infinity → expanded', () {
      expect(
        ZWindowSizeClass.fromWidth(double.infinity),
        ZWindowSizeClass.expanded,
      );
    });

    test('-infinity → compact', () {
      expect(
        ZWindowSizeClass.fromWidth(double.negativeInfinity),
        ZWindowSizeClass.compact,
      );
    });

    test('aucune entrée ne lève', () {
      for (final w in <double>[
        0,
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        599,
        600,
        840,
      ]) {
        expect(() => ZWindowSizeClass.fromWidth(w), returnsNormally);
      }
    });
  });

  group('Seuils centralisés (AC3)', () {
    test('constantes M3 = 600 / 840', () {
      expect(ZWindowSizeThresholds.mediumMinWidth, 600);
      expect(ZWindowSizeThresholds.expandedMinWidth, 840);
    });
  });

  test('enum expose exactement 3 paliers (NFR-U7, enums > booléens)', () {
    expect(ZWindowSizeClass.values, <ZWindowSizeClass>[
      ZWindowSizeClass.compact,
      ZWindowSizeClass.medium,
      ZWindowSizeClass.expanded,
    ]);
  });
}
