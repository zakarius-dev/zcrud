/// Gardes de `ZEaseFactorAdjustment` — stratégie d'ajustement du facteur de
/// facilité déclarée sur `ZSrsConfig` et consommée par `ZSm2Scheduler`.
///
/// ## Pourquoi la garde « canonique » est ANCRÉE SUR LE PLANIFICATEUR
///
/// Vérifier seulement `ZCanonicalEaseFactorAdjustment.apply(...)` contre la
/// formule littérale serait MAL ANCRÉ : le défaut redouté n'est pas que la
/// stratégie canonique se trompe, c'est que le planificateur cesse de
/// l'appliquer — défaut par défaut changé, appel oublié, clamp déplacé. La
/// table de vecteurs ci-dessous passe donc par `ZSm2Scheduler` avec la config
/// PAR DÉFAUT, et compare à la formule littérale écrite ICI, en égalité
/// EXACTE (`equals`, jamais `moreOrLessEquals`) : le défaut passif exigé est
/// l'INERTIE ABSOLUE (mêmes doubles, au bit près, qu'avant l'existence du
/// point d'extension).
///
/// `z_sm2_contract_test.dart` reste le verrou de la courbe complète
/// (intervalles, compteurs, dates). Ce fichier-ci ne le duplique pas : il ne
/// regarde QUE le facteur de facilité, sur une grille de 20 états de départ ×
/// 6 qualités que le contrat ne couvre pas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Horloge fixée — aucun `DateTime.now()` (déterminisme).
final DateTime kNow = DateTime.utc(2026, 1, 1);

/// Config canonique, propriétaire de toutes les bornes lues ici.
const ZSrsConfig kCanonicalConfig = ZSrsConfig();

/// 20 facteurs de facilité de départ couvrant `[minEaseFactor, maxEaseFactor]`
/// et débordant des deux côtés (le clamp doit être exercé, pas contourné).
List<double> _startingEaseFactors() =>
    <double>[for (var i = 0; i < 20; i++) 1.2 + i * 0.08];

/// État de répétition portant [easeFactor], avec un historique déjà entamé
/// (`repetitions: 2`) : la branche multiplicative est celle du régime
/// courant, et l'ajustement du facteur de facilité y est appliqué comme
/// partout ailleurs.
ZRepetitionInfo _infoWith(double easeFactor) => ZRepetitionInfo(
      flashcardId: 'c',
      folderId: 'f',
      interval: 6,
      repetitions: 2,
      easeFactor: easeFactor,
    );

void main() {
  group('canonique — INERTIE ABSOLUE du planificateur par défaut', () {
    test('la config par défaut porte la stratégie canonique', () {
      expect(
        kCanonicalConfig.easeFactorAdjustment,
        isA<ZCanonicalEaseFactorAdjustment>(),
      );
      expect(
        kCanonicalConfig.easeFactorAdjustment,
        equals(const ZEaseFactorAdjustment.canonical()),
      );
    });

    test(
        'ZSm2Scheduler par défaut : easeFactor EXACTEMENT égal à la formule '
        'littérale clampée, pour 20 EF de départ × q0..q5', () {
      const scheduler = ZSm2Scheduler();
      var vectors = 0;
      for (final start in _startingEaseFactors()) {
        for (var q = 0; q <= 5; q++) {
          // Formule SuperMemo-2 écrite ICI, à la main, dans l'ordre exact des
          // opérations d'origine. Toute réécriture « équivalente » côté lib
          // décalerait les derniers bits et rougirait cette égalité stricte.
          final raw = start + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
          final expected = raw
              .clamp(
                kCanonicalConfig.minEaseFactor,
                kCanonicalConfig.maxEaseFactor,
              )
              .toDouble();

          final actual =
              scheduler.apply(_infoWith(start), q, now: kNow).easeFactor;
          expect(
            actual,
            equals(expected),
            reason: 'EF de départ $start, q=$q : le planificateur par défaut '
                'DOIT rendre la valeur canonique au bit près',
          );
          vectors++;
        }
      }
      // Méta-garde : sans elle, une grille vidée par erreur rendrait ce test
      // vert sans avoir rien mesuré.
      expect(vectors, 120);
    });

    test(
        'la stratégie canonique appelée directement rend la valeur BRUTE '
        '(non bornée) — le clamp appartient au planificateur', () {
      const canonical = ZEaseFactorAdjustment.canonical();
      // 2.5 + 0.1 = 2.6 : au-dessus du plafond 2.5, et rendu tel quel.
      expect(canonical.apply(2.5, 5, kCanonicalConfig), equals(2.6));
      expect(
        canonical.apply(2.5, 5, kCanonicalConfig),
        greaterThan(kCanonicalConfig.maxEaseFactor),
      );
    });

    test('qualité hors échelle : clampée par la config, jamais de levée', () {
      const canonical = ZEaseFactorAdjustment.canonical();
      expect(
        canonical.apply(2.0, 1000, kCanonicalConfig),
        equals(canonical.apply(2.0, 5, kCanonicalConfig)),
      );
      expect(
        canonical.apply(2.0, -1000, kCanonicalConfig),
        equals(canonical.apply(2.0, 0, kCanonicalConfig)),
      );
    });
  });

  group('table — delta additif déclaré par l\'application', () {
    // Table volontairement PARTIELLE (q4 absent) : la table n'a pas à être
    // totale, et l'absence doit valoir « aucune variation », pas un repli sur
    // la formule canonique (qui, elle, ferait bouger l'EF).
    const table = ZEaseFactorAdjustment.table(
      deltaByQuality: <int, double>{0: -0.4, 1: -0.3, 3: 0.05, 5: 0.2},
    );

    test('la qualité présente applique EXACTEMENT son delta', () {
      expect(table.apply(2.0, 5, kCanonicalConfig), equals(2.2));
      expect(table.apply(2.0, 3, kCanonicalConfig), equals(2.05));
      expect(table.apply(2.0, 0, kCanonicalConfig), equals(1.6));
    });

    test('la qualité ABSENTE de la table laisse l\'EF strictement inchangé',
        () {
      // q4 n'est pas dans la table. Une retombée sur la formule canonique
      // rendrait 2.5 (+0.1) : c'est ce que cette égalité stricte interdit.
      expect(table.apply(2.4, 4, kCanonicalConfig), equals(2.4));
    });

    test('penalizeLapse:false ⇒ AUCUNE variation sous le seuil de réussite',
        () {
      const lenient = ZEaseFactorAdjustment.table(
        deltaByQuality: <int, double>{0: -0.4, 1: -0.3, 2: -0.2, 5: 0.2},
        penalizeLapse: false,
      );
      // Sous le seuil (passThreshold = 3) : delta DÉCLARÉ, mais neutralisé.
      for (var q = kCanonicalConfig.minQuality;
          q < kCanonicalConfig.passThreshold;
          q++) {
        expect(
          lenient.apply(2.0, q, kCanonicalConfig),
          equals(2.0),
          reason: 'q=$q est sous le seuil : l\'EF ne doit PAS bouger',
        );
      }
      // Au-dessus du seuil, la table s'applique normalement.
      expect(lenient.apply(2.0, 5, kCanonicalConfig), equals(2.2));
    });

    test('penalizeLapse:true (défaut) ⇒ le delta sous le seuil s\'applique',
        () {
      // Contre-preuve du test précédent : sans le drapeau, la même note fait
      // bien bouger l'EF (sinon la garde ci-dessus serait HORS D'ATTEINTE).
      expect(table.apply(2.0, 1, kCanonicalConfig), equals(1.7));
    });

    test('le planificateur BORNE le résultat de la table aux deux bornes', () {
      const explosive = ZSrsConfig(
        easeFactorAdjustment: ZEaseFactorAdjustment.table(
          deltaByQuality: <int, double>{0: -9.0, 5: 9.0},
        ),
      );
      const scheduler = ZSm2Scheduler(config: explosive);
      expect(
        scheduler.apply(_infoWith(2.0), 5, now: kNow).easeFactor,
        equals(explosive.maxEaseFactor),
      );
      expect(
        scheduler.apply(_infoWith(2.0), 0, now: kNow).easeFactor,
        equals(explosive.minEaseFactor),
      );
    });

    test('le planificateur consomme la table déclarée sur la config', () {
      const tabled = ZSrsConfig(easeFactorAdjustment: table);
      const scheduler = ZSm2Scheduler(config: tabled);
      // 2.0 + 0.2 = 2.2, sous le plafond : la valeur de la table transparaît
      // telle quelle jusqu'à l'état rendu.
      expect(
        scheduler.apply(_infoWith(2.0), 5, now: kNow).easeFactor,
        equals(2.2),
      );
      // Et ce n'est PAS la valeur canonique (2.1) : la garde discrimine.
      expect(
        scheduler.apply(_infoWith(2.0), 5, now: kNow).easeFactor,
        isNot(equals(const ZSm2Scheduler()
            .apply(_infoWith(2.0), 5, now: kNow)
            .easeFactor)),
      );
    });

    test('qualité hors échelle : clampée, jamais de levée', () {
      expect(table.apply(2.0, 1000, kCanonicalConfig), equals(2.2));
      expect(table.apply(2.0, -1000, kCanonicalConfig), equals(1.6));
    });
  });

  group('(dé)sérialisation TOLÉRANTE — inconnu ⇒ canonique', () {
    const canonical = ZEaseFactorAdjustment.canonical();
    const table = ZEaseFactorAdjustment.table(
      deltaByQuality: <int, double>{0: -0.4, 5: 0.2},
      penalizeLapse: false,
    );

    test('round-trip canonique : toMap → fromMap = la MÊME stratégie', () {
      expect(
        ZEaseFactorAdjustment.fromMap(canonical.toMap()),
        equals(canonical),
      );
      expect(canonical.toMap(), equals(<String, dynamic>{'kind': 'canonical'}));
    });

    test('round-trip table : toMap → fromMap = la MÊME stratégie', () {
      final round = ZEaseFactorAdjustment.fromMap(table.toMap());
      expect(round, equals(table));
      // Le comportement survit au round-trip, pas seulement l'égalité.
      expect(
        round.apply(2.0, 0, kCanonicalConfig),
        equals(table.apply(2.0, 0, kCanonicalConfig)),
      );
      expect(
        round.apply(2.0, 5, kCanonicalConfig),
        equals(table.apply(2.0, 5, kCanonicalConfig)),
      );
    });

    test('la table sérialisée porte des clés CHAÎNES (contrainte JSON)', () {
      expect(
        table.toMap(),
        equals(<String, dynamic>{
          'kind': 'table',
          'delta_by_quality': <String, dynamic>{'0': -0.4, '5': 0.2},
          'penalize_lapse': false,
        }),
      );
    });

    test('formes NON RECONNUES ⇒ canonique, jamais de levée', () {
      final degraded = <String, Map<String, dynamic>?>{
        'map nulle': null,
        'discriminant absent': <String, dynamic>{},
        'discriminant inconnu': <String, dynamic>{'kind': 'markov'},
        'discriminant non-chaîne': <String, dynamic>{'kind': 7},
        'table absente': <String, dynamic>{'kind': 'table'},
        'table non-Map': <String, dynamic>{
          'kind': 'table',
          'delta_by_quality': 'oui',
        },
        'table sans entrée lisible': <String, dynamic>{
          'kind': 'table',
          'delta_by_quality': <String, dynamic>{'x': 1.0, '3': 'non'},
        },
      };
      for (final entry in degraded.entries) {
        late ZEaseFactorAdjustment read;
        expect(
          () => read = ZEaseFactorAdjustment.fromMap(entry.value),
          returnsNormally,
          reason: entry.key,
        );
        expect(read, equals(canonical), reason: entry.key);
      }
      expect(degraded, hasLength(7)); // méta-garde : la table n'est pas vide.
    });

    test('table PARTIELLEMENT lisible : les entrées valides sont gardées', () {
      final read = ZEaseFactorAdjustment.fromMap(<String, dynamic>{
        'kind': 'table',
        'delta_by_quality': <String, dynamic>{
          '5': 0.2, // lisible
          'x': 1.0, // clé illisible : ignorée
          '3': 'non', // valeur illisible : ignorée
          '0': -1, // `int` accepté comme `num`
        },
      });
      expect(
        read,
        equals(
          const ZEaseFactorAdjustment.table(
            deltaByQuality: <int, double>{5: 0.2, 0: -1.0},
          ),
        ),
      );
    });

    test('penalize_lapse non booléen ⇒ défaut `true` (la table pénalise)', () {
      // `#absent` note la clé MANQUANTE : elle n'est simplement pas écrite.
      const absent = #absent;
      for (final raw in <Object>[absent, 'non', 0, <String>[]]) {
        final map = <String, dynamic>{
          'kind': 'table',
          'delta_by_quality': <String, dynamic>{'1': -0.3},
        };
        if (raw != absent) map['penalize_lapse'] = raw;
        final read = ZEaseFactorAdjustment.fromMap(map);
        // Preuve par le COMPORTEMENT : q=1 est sous le seuil, et le delta
        // s'applique — donc `penalizeLapse` vaut bien `true`.
        expect(
          read.apply(2.0, 1, kCanonicalConfig),
          equals(1.7),
          reason: 'penalize_lapse = $raw',
        );
      }
    });
  });
}
