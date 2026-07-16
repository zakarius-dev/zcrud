// Tests unitaires PURS (sans `BuildContext`) de `computeCrossAxisCount`.
//
// Couvre : formule floor+clamp aux frontières (AC1/AC3), clamp bas ≥ 1
// anti-bug iffd (AC1), clamp haut (AC3), défauts sûrs sans throw ni division
// par zéro (AC2). Aucun import Flutter widgets requis.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

void main() {
  group('AC1/AC3 — formule floor + clamp, frontières déterministes', () {
    test('w == minW → 1', () {
      expect(
        computeCrossAxisCount(availableWidth: 300, minItemWidth: 300),
        1,
      );
    });

    test('w == 2·minW → 2', () {
      expect(
        computeCrossAxisCount(availableWidth: 600, minItemWidth: 300),
        2,
      );
    });

    test('w == 2·minW − 1 → 1 (floor)', () {
      expect(
        computeCrossAxisCount(availableWidth: 599, minItemWidth: 300),
        1,
      );
    });

    test('w == ½·minW → 1 (clamp bas)', () {
      expect(
        computeCrossAxisCount(availableWidth: 150, minItemWidth: 300),
        1,
      );
    });

    test('1000 / 300 → 3 (parité widget AC5)', () {
      expect(
        computeCrossAxisCount(availableWidth: 1000, minItemWidth: 300),
        3,
      );
    });

    test('très grande largeur + maxColumns: 4 → 4 (clamp haut)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 10000,
          minItemWidth: 300,
          maxColumns: 4,
        ),
        4,
      );
    });

    test('maxColumns: null → non plafonné (borne pratique = floor)', () {
      expect(
        computeCrossAxisCount(availableWidth: 10000, minItemWidth: 300),
        33, // 10000 / 300 = 33.33 → floor 33
      );
    });
  });

  group('AC1 — clamp bas ≥ 1 (anti-bug iffd, jamais 0)', () {
    test('w=100, minW=300 → 1 (écran étroit)', () {
      expect(
        computeCrossAxisCount(availableWidth: 100, minItemWidth: 300),
        1,
      );
    });

    test('minColumns: 0 → plancher remonté à 1', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 100,
          minItemWidth: 300,
          minColumns: 0,
        ),
        1,
      );
    });

    test('minColumns: -5 → plancher remonté à 1', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 100,
          minItemWidth: 300,
          minColumns: -5,
        ),
        1,
      );
    });

    test('minColumns: 3, largeur étroite → plancher 3', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 100,
          minItemWidth: 300,
          minColumns: 3,
        ),
        3,
      );
    });
  });

  group('AC2 — défauts sûrs : aucun throw, aucune division par zéro', () {
    test('minW=0 → lo (aucune division)', () {
      expect(
        () => computeCrossAxisCount(availableWidth: 900, minItemWidth: 0),
        returnsNormally,
      );
      expect(
        computeCrossAxisCount(availableWidth: 900, minItemWidth: 0),
        1,
      );
    });

    test('minW=-10 → lo', () {
      expect(
        computeCrossAxisCount(availableWidth: 900, minItemWidth: -10),
        1,
      );
    });

    test('minW=NaN → lo', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: double.nan,
        ),
        1,
      );
    });

    test('w=0 → lo', () {
      expect(
        computeCrossAxisCount(availableWidth: 0, minItemWidth: 300),
        1,
      );
    });

    test('w=-1 → lo', () {
      expect(
        computeCrossAxisCount(availableWidth: -1, minItemWidth: 300),
        1,
      );
    });

    test('w=NaN → lo', () {
      expect(
        computeCrossAxisCount(
          availableWidth: double.nan,
          minItemWidth: 300,
        ),
        1,
      );
    });

    test('w=infinity, maxColumns: 6 → 6 (borné)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: double.infinity,
          minItemWidth: 300,
          maxColumns: 6,
        ),
        6,
      );
    });

    test('w=infinity, maxColumns: null → lo (jamais non borné)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: double.infinity,
          minItemWidth: 300,
        ),
        1,
      );
    });

    test('maxColumns: 2, minColumns: 5 → 5 (maxColumns remonté à lo, pas de RangeError)',
        () {
      expect(
        () => computeCrossAxisCount(
          availableWidth: 5000,
          minItemWidth: 300,
          minColumns: 5,
          maxColumns: 2,
        ),
        returnsNormally,
      );
      expect(
        computeCrossAxisCount(
          availableWidth: 5000,
          minItemWidth: 300,
          minColumns: 5,
          maxColumns: 2,
        ),
        5,
      );
    });

    test('minW=NaN ET w=NaN ET minColumns=0 → 1 (cumul dégénéré)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: double.nan,
          minItemWidth: double.nan,
          minColumns: 0,
        ),
        1,
      );
    });
  });

  group('AC9 — prise en compte du spacing et du padding horizontal', () {
    test('spacing réduit n d\'au moins 1 (920, minW 300, spacing 20)', () {
      // Sans spacing : 920/300 = 3.06 → 3.
      expect(
        computeCrossAxisCount(availableWidth: 920, minItemWidth: 300),
        3,
      );
      // Avec spacing 20 : (920+20)/(300+20) = 940/320 = 2.9375 → 2.
      expect(
        computeCrossAxisCount(
          availableWidth: 920,
          minItemWidth: 300,
          spacing: 20,
        ),
        2,
      );
    });

    test('padding réduit n d\'au moins 1 (1000, minW 300, padding 120)', () {
      // Sans padding : 1000/300 = 3.33 → 3.
      expect(
        computeCrossAxisCount(availableWidth: 1000, minItemWidth: 300),
        3,
      );
      // Avec padding 120 : effectiveWidth 880 → 880/300 = 2.93 → 2.
      expect(
        computeCrossAxisCount(
          availableWidth: 1000,
          minItemWidth: 300,
          horizontalPadding: 120,
        ),
        2,
      );
    });

    test('spacing + padding cumulés font DIVERGER du floor brut '
        '(1000, minW 300, spacing 100, padding 100 → 2, pas 3)', () {
      // Valeurs choisies pour que le résultat DIFFÈRE du floor naïf (test
      // réellement porteur, LOW-2) : sans params, floor(1000/300) = 3 ;
      // avec spacing+padding, effectiveWidth = 1000 − 100 = 900,
      // (900+100)/(300+100) = 1000/400 = 2.5 → 2.
      expect(
        computeCrossAxisCount(availableWidth: 1000, minItemWidth: 300),
        3,
        reason: 'contraste : le floor brut donne 3 colonnes',
      );
      expect(
        computeCrossAxisCount(
          availableWidth: 1000,
          minItemWidth: 300,
          spacing: 100,
          horizontalPadding: 100,
        ),
        2,
        reason: 'AC9 : gouttières + padding déduits → 2 colonnes, pas 3',
      );
    });

    test('horizontalPadding >= availableWidth → minColumns (lo)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 300,
          minItemWidth: 100,
          horizontalPadding: 300,
        ),
        1,
      );
      expect(
        computeCrossAxisCount(
          availableWidth: 300,
          minItemWidth: 100,
          horizontalPadding: 500,
          minColumns: 2,
        ),
        2,
      );
    });

    test('spacing négatif → traité comme 0 (identique à spacing par défaut)',
        () {
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          spacing: -50,
        ),
        computeCrossAxisCount(availableWidth: 900, minItemWidth: 300),
      );
    });

    test('spacing NaN → traité comme 0', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          spacing: double.nan,
        ),
        3,
      );
    });

    test('horizontalPadding négatif → traité comme 0', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          horizontalPadding: -100,
        ),
        3,
      );
    });

    test('horizontalPadding NaN → traité comme 0', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          horizontalPadding: double.nan,
        ),
        3,
      );
    });

    test('spacing/padding infinis → traités comme 0, aucun throw', () {
      expect(
        () => computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          spacing: double.infinity,
          horizontalPadding: double.infinity,
        ),
        returnsNormally,
      );
      expect(
        computeCrossAxisCount(
          availableWidth: 900,
          minItemWidth: 300,
          spacing: double.infinity,
          horizontalPadding: double.infinity,
        ),
        3,
      );
    });

    test('clamp haut respecté avec spacing (maxColumns)', () {
      expect(
        computeCrossAxisCount(
          availableWidth: 10000,
          minItemWidth: 300,
          spacing: 16,
          maxColumns: 4,
        ),
        4,
      );
    });

    test(
        'RÉTRO-COMPAT : spacing:0, horizontalPadding:0 == ancien floor sur '
        'plusieurs largeurs', () {
      const minW = 300.0;
      for (final w in <double>[
        150,
        299,
        300,
        301,
        599,
        600,
        900,
        1000,
        2999,
        10000,
      ]) {
        final expected = (w / minW).floor().clamp(1, 1 << 30);
        expect(
          computeCrossAxisCount(
            availableWidth: w,
            minItemWidth: minW,
            spacing: 0,
            horizontalPadding: 0,
          ),
          expected,
          reason: 'w=$w devrait rester ⌊w/minW⌋ borné ≥ 1',
        );
        // Et strictement égal à l'appel SANS les nouveaux paramètres.
        expect(
          computeCrossAxisCount(availableWidth: w, minItemWidth: minW),
          computeCrossAxisCount(
            availableWidth: w,
            minItemWidth: minW,
            spacing: 0,
            horizontalPadding: 0,
          ),
        );
      }
    });
  });
}
