/// Verdict d'examen blanc — le SEUIL est une donnée de l'hôte, jamais du socle.
///
/// Chaque garde nomme la régression qu'elle attrape, et chacune a été rejouée
/// ROUGE PAR ASSERTION sur une injection ciblée dans `lib/`, puis restaurée par
/// copie de fichier.
///
/// ## Les attendus sont écrits à la main
///
/// `7/10 = 0.7` et `6/10 = 0.6` sont dérivés du corpus **de tête**, jamais lus
/// d'une constante du code : comparer le code à lui-même ne rougirait jamais.
/// Le corpus `7/10` face à un seuil de `0.7` est choisi pour taper **sur la
/// frontière exacte** — c'est ce qui rend la garde capable d'attraper un `>`
/// écrit à la place d'un `>=` (« 70 % requis » qui recale un 70 %).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

/// 7 correctes sur 10 — **exactement** le seuil de 0,7.
const ZStudySessionResult _sevenOfTen = ZStudySessionResult(
  mode: ZReviewMode.whiteExam,
  total: 10,
  correct: 7,
  byQuality: <String, int>{'0': 3, '4': 4, '5': 3},
);

/// 6 correctes sur 10 — sous le seuil de 0,7.
const ZStudySessionResult _sixOfTen = ZStudySessionResult(
  mode: ZReviewMode.whiteExam,
  total: 10,
  correct: 6,
  byQuality: <String, int>{'0': 4, '4': 4, '5': 2},
);

List<ZSessionItem> _queue(int count) => <ZSessionItem>[
  for (var i = 0; i < count; i++)
    ZSessionItem(flashcardId: 'c$i', folderId: 'f'),
];

/// Moteur soumis avec [correctCount] bonnes réponses sur [total].
ZWhiteExamSessionEngine _submitted({
  required int total,
  required int correctCount,
  double? successRatio,
  ZSrsConfig config = const ZSrsConfig(),
}) {
  final engine = ZWhiteExamSessionEngine(
    queue: _queue(total),
    config: config,
    successRatio: successRatio,
  )..start();
  for (var i = 0; i < total; i++) {
    engine.answer(i < correctCount ? 5 : 0);
  }
  return engine..submit();
}

void main() {
  group('zWhiteExamVerdictFor — le seuil vient de l\'hôte', () {
    test(
      'G1 — seuil 0,7 et 7 sur 10 : RÉUSSI (la frontière exacte réussit)',
      () {
        final verdict = zWhiteExamVerdictFor(_sevenOfTen, successRatio: 0.7);

        expect(
          verdict,
          isNotNull,
          reason: 'un seuil déclaré doit produire un verdict',
        );
        expect(
          verdict!.passed,
          isTrue,
          reason:
              'ATTRAPE : une comparaison STRICTE (`>` au lieu de `>=`) — '
              'l\'apprenant qui atteint exactement les 70 % exigés serait '
              'recalé, sans aucune exception ni test rouge ailleurs',
        );
        // 7/10, écrit à la main.
        expect(verdict.ratio, 0.7);
        expect(verdict.correct, 7);
        expect(verdict.total, 10);
      },
    );

    test('G2 — seuil 0,7 et 6 sur 10 : NON RÉUSSI', () {
      final verdict = zWhiteExamVerdictFor(_sixOfTen, successRatio: 0.7);

      expect(verdict, isNotNull);
      expect(
        verdict!.passed,
        isFalse,
        reason:
            'ATTRAPE : un verdict qui réussit tout le monde (comparaison '
            'inversée, seuil ignoré) — une célébration sur un échec',
      );
      // 6/10, écrit à la main.
      expect(verdict.ratio, 0.6);
      expect(verdict.correct, 6);
    });

    test('G3 — sans seuil déclaré : AUCUN verdict', () {
      expect(
        zWhiteExamVerdictFor(_sevenOfTen),
        isNull,
        reason:
            'ATTRAPE : un seuil de repli inventé par le socle — le seuil de '
            'réussite est une règle de l\'application, le socle n\'en porte '
            'aucune valeur',
      );
      expect(
        zWhiteExamVerdictFor(_sixOfTen, successRatio: null),
        isNull,
        reason: 'un `null` explicite vaut « aucun seuil », pas « seuil 0 »',
      );
    });

    test('G4 — aucun résultat : aucun verdict, même avec un seuil', () {
      expect(zWhiteExamVerdictFor(null, successRatio: 0.7), isNull);
    });

    test('G5 — le seuil est BORNÉ à [0, 1] ; `NaN` ne juge rien', () {
      // 1,4 borné à 1 ⇒ 7/10 ne suffit plus.
      expect(
        zWhiteExamVerdictFor(_sevenOfTen, successRatio: 1.4)!.passed,
        isFalse,
        reason:
            'ATTRAPE : un seuil non borné — `1.4` laissé tel quel rendrait '
            'l\'examen INGAGNABLE (aucun ratio ne dépasse 1)',
      );
      // 100 % exigé, 100 % obtenu : réussi (la borne haute reste atteignable).
      expect(
        zWhiteExamVerdictFor(
          const ZStudySessionResult(total: 4, correct: 4),
          successRatio: 1.4,
        )!.passed,
        isTrue,
      );
      // −0,2 borné à 0 ⇒ tout réussit, y compris 0 sur 10.
      expect(
        zWhiteExamVerdictFor(
          const ZStudySessionResult(total: 10),
          successRatio: -0.2,
        )!.passed,
        isTrue,
        reason:
            'ATTRAPE : un seuil négatif non borné — un `-0.2` laissé tel quel '
            'ferait échouer un ratio de 0 sur une comparaison flottante',
      );
      expect(
        zWhiteExamVerdictFor(_sevenOfTen, successRatio: double.nan),
        isNull,
        reason:
            'ATTRAPE : un `NaN` propagé — toute comparaison avec `NaN` est '
            'fausse, donc l\'examen serait RECALÉ en silence',
      );
      expect(zClampSuccessRatio(1.4), 1.0);
      expect(zClampSuccessRatio(-0.2), 0.0);
      expect(zClampSuccessRatio(double.nan), isNull);
      expect(zClampSuccessRatio(null), isNull);
    });

    test('G6 — le ratio ne divise jamais par zéro et ne dépasse jamais 1', () {
      // Examen vide : ratio 0, aucune exception.
      final empty = zWhiteExamVerdictFor(
        const ZStudySessionResult(),
        successRatio: 0.7,
      );
      expect(empty!.ratio, 0.0);
      expect(empty.passed, isFalse);
      // Données incohérentes (correct > total) : ratio borné à 1.
      expect(
        zWhiteExamVerdictFor(
          const ZStudySessionResult(total: 2, correct: 5),
          successRatio: 0.7,
        )!.ratio,
        1.0,
      );
    });

    test('G7 — value-object : égalité structurelle', () {
      expect(
        zWhiteExamVerdictFor(_sevenOfTen, successRatio: 0.7),
        const ZWhiteExamVerdict(
          passed: true,
          ratio: 0.7,
          correct: 7,
          total: 10,
        ),
      );
      expect(
        zWhiteExamVerdictFor(_sevenOfTen, successRatio: 0.7).hashCode,
        const ZWhiteExamVerdict(
          passed: true,
          ratio: 0.7,
          correct: 7,
          total: 10,
        ).hashCode,
      );
    });
  });

  group('ZWhiteExamSessionEngine — le verdict est DÉRIVÉ, jamais stocké', () {
    test('G8 — sans seuil, le moteur ne rend aucun verdict après submit', () {
      final engine = _submitted(total: 10, correctCount: 7);

      expect(engine.result, isNotNull, reason: 'l\'examen EST soumis');
      expect(
        engine.verdict,
        isNull,
        reason:
            'ATTRAPE : un verdict rendu sans seuil déclaré — inertie du '
            'défaut : un hôte qui n\'a rien demandé ne reçoit rien',
      );
      expect(engine.successRatio, isNull);
    });

    test('G9 — avec seuil 0,7 : verdict RÉUSSI à 7 sur 10, MANQUÉ à 6', () {
      expect(
        _submitted(total: 10, correctCount: 7, successRatio: 0.7).verdict,
        const ZWhiteExamVerdict(
          passed: true,
          ratio: 0.7,
          correct: 7,
          total: 10,
        ),
      );
      expect(
        _submitted(total: 10, correctCount: 6, successRatio: 0.7).verdict!
            .passed,
        isFalse,
      );
    });

    test('G10 — avant soumission, aucun verdict même avec un seuil', () {
      final engine = ZWhiteExamSessionEngine(
        queue: _queue(10),
        successRatio: 0.7,
      )..start();
      engine.answer(5);

      expect(
        engine.verdict,
        isNull,
        reason:
            'ATTRAPE : un verdict rendu sur un examen NON SOUMIS — il '
            'annoncerait un échec à mi-parcours',
      );
    });

    test('G11 — le moteur BORNE le seuil qu\'on lui donne', () {
      expect(
        ZWhiteExamSessionEngine(queue: _queue(1), successRatio: 1.4)
            .successRatio,
        1.0,
      );
      expect(
        ZWhiteExamSessionEngine(queue: _queue(1), successRatio: -0.2)
            .successRatio,
        0.0,
      );
      expect(
        ZWhiteExamSessionEngine(queue: _queue(1), successRatio: double.nan)
            .successRatio,
        isNull,
      );
    });
  });

  group('ZWhiteExamSessionController — il RELAIE le verdict du moteur', () {
    test('G12 — le verdict apparaît dans la projection à la soumission', () {
      final engine = ZWhiteExamSessionEngine(
        queue: _queue(10),
        successRatio: 0.7,
      );
      final controller = ZWhiteExamSessionController(engine: engine);
      addTearDown(controller.dispose);

      expect(controller.state.value.verdict, isNull, reason: 'phase setup');

      engine.start();
      for (var i = 0; i < 10; i++) {
        engine.answer(i < 7 ? 5 : 0);
      }
      engine.submit();

      expect(
        controller.state.value.verdict,
        const ZWhiteExamVerdict(
          passed: true,
          ratio: 0.7,
          correct: 7,
          total: 10,
        ),
        reason:
            'ATTRAPE : une projection qui oublie le verdict — la surface de '
            'présentation ne le verrait jamais, et l\'écran de fin ne '
            'célébrerait rien',
      );
    });

    test('G13 — sans seuil, la projection reste sans verdict', () {
      final engine = ZWhiteExamSessionEngine(queue: _queue(2));
      final controller = ZWhiteExamSessionController(engine: engine);
      addTearDown(controller.dispose);

      engine
        ..start()
        ..answer(5)
        ..answer(5)
        ..submit();

      expect(controller.state.value.result, isNotNull);
      expect(controller.state.value.verdict, isNull);
    });
  });
}
