/// Gardes de `ZSrsConfig.neutralQuality` — la qualité posée quand aucune
/// évaluation n'est disponible.
///
/// Deux propriétés distinctes, gardées séparément :
/// 1. **INERTIE** — le défaut (`null`) ne change strictement rien : la
///    configuration par défaut reste égale à elle-même et
///    `effectiveNeutralQuality` retombe sur `passThreshold` ;
/// 2. **BORNAGE DÉFENSIF** — une valeur hors échelle est *clampée à la
///    construction*, jamais rejetée par une levée (invariant AD-10). La garde
///    exige l'**égalité stricte** avec la borne : un `lessThanOrEqualTo`
///    serait vert même sans clamp du tout sur la borne opposée.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  group('neutralQuality — inertie du défaut', () {
    test('le défaut est `null` et n\'altère pas l\'égalité du VO', () {
      const defaults = ZSrsConfig();
      expect(defaults.neutralQuality, isNull);
      expect(defaults, equals(const ZSrsConfig(neutralQuality: null)));
      expect(
        defaults.hashCode,
        equals(const ZSrsConfig(neutralQuality: null).hashCode),
      );
    });

    test('`null` ⇒ la résolution rend passThreshold (jamais un littéral)', () {
      const defaults = ZSrsConfig();
      expect(defaults.effectiveNeutralQuality, equals(defaults.passThreshold));

      // Preuve que la résolution LIT la config et ne recopie pas `3` : une
      // config dont le seuil de réussite diffère change la résolution.
      const strict = ZSrsConfig(passThreshold: 5);
      expect(strict.effectiveNeutralQuality, equals(5));
    });

    test('une valeur déclarée PRIME sur passThreshold', () {
      const declared = ZSrsConfig(neutralQuality: 1);
      expect(declared.neutralQuality, equals(1));
      expect(declared.effectiveNeutralQuality, equals(1));
      expect(
        declared.effectiveNeutralQuality,
        isNot(equals(declared.passThreshold)),
      );
    });
  });

  group('neutralQuality — bornage DÉFENSIF, jamais une levée', () {
    test('au-dessus du sommet ⇒ ramené EXACTEMENT à maxQuality', () {
      const high = ZSrsConfig(neutralQuality: 99);
      expect(high.neutralQuality, equals(high.maxQuality));
      expect(high.effectiveNeutralQuality, equals(high.maxQuality));
    });

    test('sous le plancher ⇒ ramené EXACTEMENT à minQuality', () {
      const low = ZSrsConfig(neutralQuality: -99);
      expect(low.neutralQuality, equals(low.minQuality));

      // Échelle tronquée par le bas : le plancher lu est bien celui de la
      // config, pas le littéral `0`.
      const truncated = ZSrsConfig(minQuality: 1, neutralQuality: 0);
      expect(truncated.neutralQuality, equals(1));
    });

    test('une valeur DANS l\'échelle traverse intacte (pas de sur-clamp)', () {
      for (var q = 0; q <= 5; q++) {
        expect(
          ZSrsConfig(neutralQuality: q).neutralQuality,
          equals(q),
          reason: 'q=$q est dans l\'échelle : aucun bornage attendu',
        );
      }
    });

    test('aucune levée pour une valeur hors échelle (AD-10)', () {
      expect(() => const ZSrsConfig(neutralQuality: 99), returnsNormally);
      expect(() => const ZSrsConfig(neutralQuality: -99), returnsNormally);
    });

    test('la classe reste utilisable en contexte `const`', () {
      const config = ZSrsConfig(neutralQuality: 99);
      expect(config.neutralQuality, equals(5));
    });
  });

  group('neutralQuality / easeFactorAdjustment — discriminants du VO', () {
    test('deux neutralQuality différents ⇒ configs NON égales', () {
      expect(
        const ZSrsConfig(neutralQuality: 1),
        isNot(equals(const ZSrsConfig(neutralQuality: 2))),
      );
      expect(
        const ZSrsConfig(neutralQuality: 1),
        isNot(equals(const ZSrsConfig())),
      );
    });

    test('deux stratégies d\'EF différentes ⇒ configs NON égales', () {
      const tabled = ZSrsConfig(
        easeFactorAdjustment: ZEaseFactorAdjustment.table(
          deltaByQuality: <int, double>{5: 0.2},
        ),
      );
      expect(tabled, isNot(equals(const ZSrsConfig())));
      expect(
        tabled,
        equals(
          const ZSrsConfig(
            easeFactorAdjustment: ZEaseFactorAdjustment.table(
              deltaByQuality: <int, double>{5: 0.2},
            ),
          ),
        ),
      );
      // Deux tables de contenus différents ne sont pas égales (l'égalité de
      // la stratégie compare le CONTENU de la table, pas l'identité de Map).
      expect(
        tabled,
        isNot(
          equals(
            const ZSrsConfig(
              easeFactorAdjustment: ZEaseFactorAdjustment.table(
                deltaByQuality: <int, double>{5: 0.3},
              ),
            ),
          ),
        ),
      );
    });
  });
}
