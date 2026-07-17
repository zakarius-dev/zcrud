/// AC1 — évaluation LOCALE exacte QCM/VF (AD-35) : mode simple/multiple DÉDUIT,
/// égalité ensembliste STRICTE, bornes LUES sur `ZSrsConfig` (AD-46).
///
/// Tests **PURS** (aucun widget). ⚠️ Aucun `expect` ne passe par une fonction
/// locale de test : tout traverse le VRAI `zEvaluateLocally` du barrel public
/// (défaut D5 de su-1 — un test qui appelle sa propre closure est tautologique).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// QCM à **UN** seul choix correct (index 1) — mode « choix unique » attendu.
ZFlashcard _qcmSingle() => const ZFlashcard(
      question: 'Capitale du Togo ?',
      type: ZFlashcardType.multipleChoice,
      choices: <ZChoice>[
        ZChoice(content: 'Accra'),
        ZChoice(content: 'Lomé', isCorrect: true),
        ZChoice(content: 'Cotonou'),
      ],
    );

/// QCM à **DEUX** choix corrects (index 0 et 2) — mode « multi » attendu.
ZFlashcard _qcmMulti() => const ZFlashcard(
      question: 'Lesquels sont des pays ?',
      type: ZFlashcardType.multipleChoice,
      choices: <ZChoice>[
        ZChoice(content: 'Togo', isCorrect: true),
        ZChoice(content: 'Lomé'),
        ZChoice(content: 'Ghana', isCorrect: true),
      ],
    );

ZFlashcard _trueFalse({required bool? isTrue}) => ZFlashcard(
      question: 'Le Togo borde le Ghana.',
      type: ZFlashcardType.trueOrFalse,
      isTrue: isTrue,
    );

void main() {
  const config = ZSrsConfig();

  group('AC1 — routage : le TYPE décide, jamais un retour null', () {
    test('zIsLocallyEvaluatedType : QCM et V/F sont LOCAUX, les 4 autres NON',
        () {
      // 🔒 La garde centrale d'AD-35. Ces 6 cas couvrent l'enum RÉEL.
      expect(zIsLocallyEvaluatedType(ZFlashcardType.multipleChoice), isTrue);
      expect(zIsLocallyEvaluatedType(ZFlashcardType.trueOrFalse), isTrue);
      expect(zIsLocallyEvaluatedType(ZFlashcardType.openQuestion), isFalse);
      expect(zIsLocallyEvaluatedType(ZFlashcardType.exercise), isFalse);
      expect(zIsLocallyEvaluatedType(ZFlashcardType.fillBlank), isFalse);
      expect(zIsLocallyEvaluatedType(ZFlashcardType.shortAnswer), isFalse);
    });

    test(
        '🔴 un QCM MALFORMÉ reste un type LOCAL — router sur `null` l\'enverrait '
        'à l\'IA (AD-35 violé en silence)', () {
      // C'est le piège que `zIsLocallyEvaluatedType` existe pour fermer :
      // `zEvaluateLocally` rend `null` pour DEUX raisons distinctes (type non
      // local / carte malformée). Un routage « null ⇒ port » confondrait les
      // deux et enverrait un QCM à l'IA.
      const malformed = ZFlashcard(
        question: 'QCM sans choix',
        type: ZFlashcardType.multipleChoice,
      );
      expect(
        zEvaluateLocally(
          card: malformed,
          selectedChoiceIndexes: const <int>{},
          config: config,
        ),
        isNull,
        reason: 'carte malformée ⇒ aucune évaluation possible',
      );
      expect(
        zIsLocallyEvaluatedType(malformed.type),
        isTrue,
        reason: 'MAIS le type reste LOCAL ⇒ le port ne doit JAMAIS être appelé',
      );
    });
  });

  group('AC1 — mode simple/multiple DÉDUIT du nb de isCorrect', () {
    test('1 correct ⇒ choix unique ; 2 corrects ⇒ multi', () {
      // 🔴 Discriminant R3-I1b : un mode câblé sur un booléen constant fait
      // rougir l'un des deux cas, quel que soit le booléen choisi.
      expect(zIsSingleChoiceQcm(_qcmSingle()), isTrue);
      expect(zIsSingleChoiceQcm(_qcmMulti()), isFalse);
    });

    test('les indices corrects sont DÉDUITS des données (positions)', () {
      expect(zCorrectChoiceIndexes(_qcmSingle()), <int>{1});
      expect(zCorrectChoiceIndexes(_qcmMulti()), <int>{0, 2});
    });
  });

  group('AC1 — QCM : ÉGALITÉ ensembliste STRICTE (jamais un sous-ensemble)', () {
    test('sélection EXACTE ⇒ maxQuality', () {
      expect(
        zEvaluateLocally(
          card: _qcmMulti(),
          selectedChoiceIndexes: const <int>{0, 2},
          config: config,
        ),
        config.maxQuality,
      );
    });

    test('🔴 une bonne réponse MANQUANTE ⇒ minQuality (R3-I1c)', () {
      // Une comparaison par SOUS-ENSEMBLE (`correct.containsAll(selected)`)
      // noterait ceci « exact » : l'apprenant a coché du juste, mais pas tout.
      expect(
        zEvaluateLocally(
          card: _qcmMulti(),
          selectedChoiceIndexes: const <int>{0},
          config: config,
        ),
        config.minQuality,
      );
    });

    test('🔴 une MAUVAISE cochée (en plus de toutes les bonnes) ⇒ minQuality',
        () {
      // Une comparaison `selected.containsAll(correct)` noterait ceci « exact » :
      // cocher TOUTES les cases deviendrait une stratégie gagnante.
      expect(
        zEvaluateLocally(
          card: _qcmMulti(),
          selectedChoiceIndexes: const <int>{0, 1, 2},
          config: config,
        ),
        config.minQuality,
      );
    });

    test('sélection vide sur une carte valide ⇒ minQuality', () {
      expect(
        zEvaluateLocally(
          card: _qcmSingle(),
          selectedChoiceIndexes: const <int>{},
          config: config,
        ),
        config.minQuality,
      );
    });
  });

  group('AC1 — Vrai/Faux', () {
    test('réponse juste ⇒ maxQuality ; fausse ⇒ minQuality', () {
      expect(
        zEvaluateLocally(
          card: _trueFalse(isTrue: true),
          selectedChoiceIndexes: const <int>{},
          answeredTrue: true,
          config: config,
        ),
        config.maxQuality,
      );
      expect(
        zEvaluateLocally(
          card: _trueFalse(isTrue: true),
          selectedChoiceIndexes: const <int>{},
          answeredTrue: false,
          config: config,
        ),
        config.minQuality,
      );
    });

    test('AD-10 — isTrue == null ⇒ null (aucune saisie offerte, aucun throw)',
        () {
      expect(
        zEvaluateLocally(
          card: _trueFalse(isTrue: null),
          selectedChoiceIndexes: const <int>{},
          answeredTrue: true,
          config: config,
        ),
        isNull,
      );
    });

    test('sans réponse (answeredTrue == null) ⇒ null', () {
      expect(
        zEvaluateLocally(
          card: _trueFalse(isTrue: true),
          selectedChoiceIndexes: const <int>{},
          config: config,
        ),
        isNull,
      );
    });
  });

  group('AC1 — AD-10 : cartes malformées ⇒ null, jamais d\'exception', () {
    test('choices vide ⇒ null', () {
      expect(
        zEvaluateLocally(
          card: const ZFlashcard(
            question: 'q',
            type: ZFlashcardType.multipleChoice,
            choices: <ZChoice>[],
          ),
          selectedChoiceIndexes: const <int>{},
          config: config,
        ),
        isNull,
      );
    });

    test('🔴 QCM SANS AUCUN choix correct ⇒ null (jamais « réussi à vide »)',
        () {
      // Sans ce garde, `{} == {}` rendrait maxQuality à qui ne coche RIEN :
      // une carte malformée RÉCOMPENSERAIT l'apprenant.
      expect(
        zEvaluateLocally(
          card: const ZFlashcard(
            question: 'q',
            type: ZFlashcardType.multipleChoice,
            choices: <ZChoice>[
              ZChoice(content: 'a'),
              ZChoice(content: 'b'),
            ],
          ),
          selectedChoiceIndexes: const <int>{},
          config: config,
        ),
        isNull,
      );
    });

    test('les 4 types NON locaux ⇒ null (évalués par le port, AC2)', () {
      for (final type in <ZFlashcardType>[
        ZFlashcardType.openQuestion,
        ZFlashcardType.exercise,
        ZFlashcardType.fillBlank,
        ZFlashcardType.shortAnswer,
      ]) {
        expect(
          zEvaluateLocally(
            card: ZFlashcard(question: 'q', type: type),
            selectedChoiceIndexes: const <int>{},
            config: config,
          ),
          isNull,
          reason: '$type n\'est pas évalué localement',
        );
      }
    });
  });

  group('AC1 — 🔒 bornes LUES sur ZSrsConfig, jamais 0/5 en dur (AD-46)', () {
    test('🔴 minQuality: 1 ⇒ une mauvaise réponse vaut 1 (et NON 0)', () {
      // 🔴 Discriminant R3-I4/D7 : une borne écrite `0` en dur ROUGIT ICI, et
      // seulement ici — d'où la valeur DISCRIMINANTE.
      const c1 = ZSrsConfig(minQuality: 1);
      expect(
        zEvaluateLocally(
          card: _qcmSingle(),
          selectedChoiceIndexes: const <int>{0},
          config: c1,
        ),
        1,
      );
    });

    test('la borne haute est lue : réponse exacte ⇒ config.maxQuality', () {
      const c1 = ZSrsConfig(minQuality: 1);
      expect(
        zEvaluateLocally(
          card: _qcmSingle(),
          selectedChoiceIndexes: const <int>{1},
          config: c1,
        ),
        c1.maxQuality,
      );
    });
  });
}
