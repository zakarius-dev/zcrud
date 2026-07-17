/// `ZSrsConfig` — propriétaire UNIQUE des bornes d'échelle de qualité (SU-1, AC1).
///
/// AD-46 : l'échelle `0..5` est **possédée par le domaine** (`ZSrsConfig`) ;
/// `ZQualityScale` en **dérive** (`fromConfig`) — jamais l'inverse, jamais deux
/// sources de vérité. AD-10 : toute qualité reçue hors bornes est **clampée**
/// (jamais d'exception), et [ZSrsConfig.clampQuality] en est l'unique propriétaire.
///
/// **Pouvoir discriminant (R3)** : les cas sur une config **non-défaut**
/// (`1..5`, l'échelle « sans blackout ») sont INSATISFIABLES par un
/// `clamp(0, 5)` en dur — ils PROUVENT que le clamp lit réellement la config.
/// Injection R3-I1 : remplacer le corps de `clampQuality` par
/// `quality.clamp(0, 5)` ⇒ ces cas ROUGISSENT.
///
/// L'échelle discriminante est `1..5` et **non** `1..4` : `maxQuality` est
/// épinglé à `5` par assert (SM-2 est un algorithme 0..5 — cf. AD-46), donc une
/// config `1..4` n'est plus constructible. `minQuality: 1` discrimine tout aussi
/// bien la dérivation, sans exercer une config que le moteur ne sait pas servir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  group('AC1 — bornes d\'échelle possédées par ZSrsConfig (AD-46)', () {
    test('les défauts canoniques portent l\'échelle SM-2 pleine 0..5', () {
      const config = ZSrsConfig();
      expect(config.minQuality, 0);
      expect(config.maxQuality, 5);
      // Le seuil de réussite préexistant reste intact (non-régression).
      expect(config.passThreshold, 3);
    });

    test('la classe reste utilisable en contexte `const` (VO pur-Dart, AD-14)', () {
      // Compile-time : si `ZSrsConfig` cessait d'être `const`, ceci ne
      // compilerait pas (le test rougirait à la compilation).
      const config = ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 2);
      expect(config.minQuality, 1);
    });
  });

  group('AC1 — clampQuality, unique propriétaire du clamp (AD-10/AD-46)', () {
    test('sur l\'échelle par défaut (0..5) : sous-borne, sur-borne, intérieur', () {
      const config = ZSrsConfig();
      expect(config.clampQuality(-3), 0, reason: 'sous-borne ⇒ clampée à min');
      expect(config.clampQuality(9), 5, reason: 'sur-borne ⇒ clampée à max');
      expect(config.clampQuality(3), 3, reason: 'valeur interne ⇒ inchangée');
      // Les bornes elles-mêmes sont dans l'échelle (clamp inclusif).
      expect(config.clampQuality(0), 0);
      expect(config.clampQuality(5), 5);
    });

    test(
      'DISCRIMINANT R3-I1 — sur une échelle NON-défaut (1..5, « sans '
      'blackout »), le clamp lit la config et non `0..5` en dur',
      () {
        const config = ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 2);
        // Insatisfiable par `quality.clamp(0, 5)` : celui-ci rendrait 0.
        expect(config.clampQuality(0), 1,
            reason: 'un clamp(0,5) en dur rendrait 0 — la config dit min=1');
        expect(config.clampQuality(-100), 1,
            reason: 'toute sous-borne est ramenée au min de la CONFIG');
        expect(config.clampQuality(2), 2);
        // La borne haute reste 5 (épinglée par assert) : elle ne discrimine
        // pas ici — c'est `minQuality` qui porte tout le pouvoir R3.
        expect(config.clampQuality(9), 5);
      },
    );

    test('ne lève JAMAIS — toute valeur extrême est clampée (AD-10)', () {
      const config = ZSrsConfig();
      expect(() => config.clampQuality(-1 << 30), returnsNormally);
      expect(config.clampQuality(1 << 30), 5);
    });
  });

  group('AC1 — assert de cohérence de l\'échelle', () {
    test('min >= max est refusé', () {
      expect(
        () => ZSrsConfig(minQuality: 5, maxQuality: 5, passThreshold: 5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZSrsConfig(minQuality: 4, maxQuality: 2, passThreshold: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('passThreshold <= minQuality est refusé (seuil hors échelle utile)', () {
      expect(
        () => ZSrsConfig(minQuality: 2, maxQuality: 5, passThreshold: 2),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZSrsConfig(minQuality: 2, maxQuality: 5, passThreshold: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('passThreshold > maxQuality est refusé', () {
      expect(
        () => ZSrsConfig(minQuality: 0, maxQuality: 5, passThreshold: 6),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'PORTEUR — une échelle que SM-2 ne sait pas honorer est INCONSTRUCTIBLE '
      '(maxQuality != 5 refusé, AD-46)',
      () {
        // SM-2 est intrinsèquement 0..5 : sa formule `(5 - q)` est GELÉE par
        // `z_sm2_contract_test.dart`. Sans cette garde, `maxQuality: 4` serait
        // constructible et `deltaEF(4)` vaudrait 0.0000 au MEILLEUR score
        // possible ⇒ l'easeFactor ne croîtrait JAMAIS, en silence. La garde
        // ferme le trou PAR CONSTRUCTION (transposition de l'ancien
        // `assert(max == 5)` de `ZQualityScale` vers son nouveau propriétaire).
        expect(
          () => ZSrsConfig(minQuality: 1, maxQuality: 4, passThreshold: 2),
          throwsA(isA<AssertionError>()),
          reason: 'sommet tronqué (4) : deltaEF au score max serait NUL',
        );
        expect(
          () => ZSrsConfig(minQuality: 0, maxQuality: 4, passThreshold: 3),
          throwsA(isA<AssertionError>()),
        );
        // Sur-borne : `(5 - q)` deviendrait NÉGATIF au-delà de 5.
        expect(
          () => ZSrsConfig(minQuality: 0, maxQuality: 10, passThreshold: 6),
          throwsA(isA<AssertionError>()),
          reason: 'sommet > 5 : le domaine déclarerait des crans que le '
              'scheduler traiterait en échec (corruption silencieuse)',
        );
      },
    );

    test(
      'PORTEUR — une borne basse hors {0, 1} est INCONSTRUCTIBLE (AD-46)',
      () {
        // Seules `0` (blackout total) et `1` (sans blackout) sont honorables
        // par la formule gelée : toute autre borne décalerait l'échelle.
        expect(
          () => ZSrsConfig(minQuality: 2, maxQuality: 5, passThreshold: 3),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => ZSrsConfig(minQuality: -1, maxQuality: 5, passThreshold: 3),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('les configurations légitimes passent (la garde ne sur-bloque pas)', () {
      expect(() => const ZSrsConfig(), returnsNormally);
      // Les configs réellement construites par les tests existants du repo.
      expect(() => const ZSrsConfig(passThreshold: 4), returnsNormally);
      expect(
        () => const ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 3),
        returnsNormally,
      );
      // Cas limite légitime : passThreshold == maxQuality (seule la note max passe).
      expect(
        () => const ZSrsConfig(minQuality: 0, maxQuality: 5, passThreshold: 5),
        returnsNormally,
      );
    });
  });

  group('AC1 — ==/hashCode intègrent les nouvelles bornes', () {
    test('deux configs d\'échelles DIFFÉRENTES ne sont pas égales', () {
      const full = ZSrsConfig(minQuality: 0, maxQuality: 5, passThreshold: 3);
      const truncatedMin = ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 3);

      // Sans `minQuality` dans `==`, ces deux configs seraient ÉGALES (bug
      // d'invalidation : une échelle changée ne rafraîchirait pas l'UI).
      // `maxQuality` est épinglé à 5 par assert : il ne peut PAS discriminer
      // deux configs — seul `minQuality` porte la variation d'échelle. Il reste
      // néanmoins dans `==`/`hashCode` par cohérence de VO.
      expect(full, isNot(equals(truncatedMin)));
      expect(full.hashCode, isNot(equals(truncatedMin.hashCode)));
    });

    test('deux configs identiques restent égales (non-régression du VO)', () {
      expect(const ZSrsConfig(), equals(const ZSrsConfig()));
      expect(const ZSrsConfig().hashCode, const ZSrsConfig().hashCode);
      expect(
        const ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 2),
        equals(const ZSrsConfig(minQuality: 1, maxQuality: 5, passThreshold: 2)),
      );
    });

    test('les champs préexistants restent discriminants (non-régression)', () {
      expect(
        const ZSrsConfig(),
        isNot(equals(const ZSrsConfig(passThreshold: 4))),
      );
      expect(
        const ZSrsConfig(),
        isNot(equals(const ZSrsConfig(minEaseFactor: 1.4))),
      );
    });
  });
}
