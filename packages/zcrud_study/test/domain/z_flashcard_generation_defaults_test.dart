// SU-9/AC3/AC4 — bornage `count` + répartition par type (SOURCE UNIQUE, AD-10).
//
// Le domaine ne fait pas confiance à ses entrées : `0`/négatif/énorme/`null`,
// somme ≠ count, type inconnu, valeur négative sont DÉGRADÉS gracieusement,
// jamais une exception. Ces tests rougissent PAR LE COMPORTEMENT si une borne
// saute ou si la répartition cesse d'être exacte.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _allTypes = ZFlashcardType.values;

void main() {
  group('AC3 — zClampGenerationCount borne [1,50] sans throw (AD-10)', () {
    test('null → défaut consigné (10)', () {
      expect(zClampGenerationCount(null), zDefaultGenerationCount);
      expect(zDefaultGenerationCount, 10);
    });

    test('0 → 1, -5 → 1 (jamais < min)', () {
      expect(zClampGenerationCount(0), 1);
      expect(zClampGenerationCount(-5), 1);
    });

    test('10000 → 50 (jamais > max)', () {
      expect(zClampGenerationCount(10000), 50);
    });

    test('dans les bornes → inchangé', () {
      expect(zClampGenerationCount(1), 1);
      expect(zClampGenerationCount(10), 10);
      expect(zClampGenerationCount(50), 50);
    });

    test('aucune entrée ne lève (balayage adverse)', () {
      for (final v in <int?>[null, -1000000, -1, 0, 1, 25, 50, 51, 999999]) {
        final r = zClampGenerationCount(v);
        expect(r, inInclusiveRange(1, 50),
            reason: 'clamp($v) = $r hors [1,50]');
      }
    });
  });

  group('AC3 — zEvenTypesDistribution : somme EXACTE, reste déterministe', () {
    test('la somme égale TOUJOURS le count borné', () {
      for (final count in <int>[1, 2, 3, 6, 7, 13, 50]) {
        final dist = zEvenTypesDistribution(count, _allTypes);
        final sum = dist.values.fold<int>(0, (a, b) => a + b);
        expect(sum, count, reason: 'count=$count : somme=$sum ≠ $count');
      }
    });

    test('count fou est borné AVANT répartition (somme = 50, pas 10000)', () {
      final dist = zEvenTypesDistribution(10000, _allTypes);
      final sum = dist.values.fold<int>(0, (a, b) => a + b);
      expect(sum, 50);
    });

    test('reste distribué sur les PREMIERS types (déterministe)', () {
      // 7 cartes sur 6 types : base=1 chacun, reste=1 au 1er type.
      final dist = zEvenTypesDistribution(7, _allTypes);
      expect(dist[_allTypes.first], 2);
      for (final t in _allTypes.skip(1)) {
        expect(dist[t], 1, reason: 'seul le 1er type reçoit le reste');
      }
    });

    test('types vide → map vide (aucune division par zéro, AD-10)', () {
      expect(zEvenTypesDistribution(10, const <ZFlashcardType>[]), isEmpty);
    });

    test('types dupliqués : dédupliqués sans fausser la somme', () {
      final dist = zEvenTypesDistribution(
        4,
        <ZFlashcardType>[
          ZFlashcardType.openQuestion,
          ZFlashcardType.openQuestion,
          ZFlashcardType.trueOrFalse,
        ],
      );
      expect(dist.length, 2);
      expect(dist.values.fold<int>(0, (a, b) => a + b), 4);
    });
  });

  group('AC4 — zNormalizeTypesDistribution : normalisée, jamais de throw', () {
    test('null → répartition équitable du countIfNull borné', () {
      final dist = zNormalizeTypesDistribution(null,
          types: _allTypes, countIfNull: 6);
      expect(dist.values.fold<int>(0, (a, b) => a + b), 6);
    });

    test('valeur négative → ramenée à 0 (conservée)', () {
      final dist = zNormalizeTypesDistribution(
        <ZFlashcardType, int>{ZFlashcardType.openQuestion: -3},
        types: _allTypes,
      );
      expect(dist[ZFlashcardType.openQuestion], 0);
    });

    test('type hors des admis → ÉCARTÉ', () {
      // exercise n'est PAS dans la liste admise ⇒ retiré.
      final dist = zNormalizeTypesDistribution(
        <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 3,
          ZFlashcardType.exercise: 4,
        },
        types: const <ZFlashcardType>[ZFlashcardType.openQuestion],
      );
      expect(dist.containsKey(ZFlashcardType.exercise), isFalse);
      expect(dist[ZFlashcardType.openQuestion], 3);
    });

    test('distribution fournie FAIT FOI : count effectif = somme retenue', () {
      final dist = zNormalizeTypesDistribution(
        <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 2,
          ZFlashcardType.trueOrFalse: 5,
        },
        types: _allTypes,
      );
      expect(dist.values.fold<int>(0, (a, b) => a + b), 7);
    });

    test('somme > 50 : total borné à 50 en tronquant déterministement', () {
      final dist = zNormalizeTypesDistribution(
        <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 40,
          ZFlashcardType.trueOrFalse: 40,
        },
        types: _allTypes,
      );
      expect(dist.values.fold<int>(0, (a, b) => a + b), 50);
    });

    test('aucune combinaison adverse ne lève', () {
      expect(
        () => zNormalizeTypesDistribution(
          <ZFlashcardType, int>{
            ZFlashcardType.openQuestion: -100,
            ZFlashcardType.fillBlank: 99999,
          },
          types: _allTypes,
        ),
        returnsNormally,
      );
    });
  });
}
