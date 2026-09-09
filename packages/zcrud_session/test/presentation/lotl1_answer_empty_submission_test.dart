/// Refus d'une soumission RÉDIGÉE VIDE — le port d'évaluation n'est jamais
/// atteint, et le message de validation existant est montré.
///
/// Pourquoi la mesure porte sur DEUX compteurs et non un seul : compter les
/// appels au port ne dit rien de ce que la surface a ÉMIS. Une surface qui
/// refuserait l'appel mais émettrait quand même une `ZFlashcardSubmission`
/// noterait la carte sur une copie blanche. Chaque garde mesure donc
/// l'appel (`SpyEvaluationPort.callCount`) ET la sortie observable
/// (`onSubmitted`).
///
/// Le refus n'est PAS un verrou : l'apprenant doit pouvoir corriger et
/// resoumettre. Les gardes lisent donc aussi `TextField.readOnly` et la
/// présence du bouton.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

/// Le champ rédigé réellement monté (jamais un `find.byType(TextField)` nu :
/// la surface peut en porter un autre).
TextField _field(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(K.answerField),
    matching: find.byType(TextField),
  ),
);

Widget _surface({
  required SpyEvaluationPort port,
  required void Function(ZFlashcardSubmission) onSubmitted,
  bool allowSkipEvaluation = false,
}) => host(
  ZFlashcardAnswerInput(
    card: writtenCard(),
    mode: ZReviewMode.learn,
    evaluationPort: port,
    allowSkipEvaluation: allowSkipEvaluation,
    onQualitySelected: (_) {},
    onSubmitted: onSubmitted,
  ),
);

void main() {
  group('Soumission rédigée VIDE — le port n\'est pas atteint', () {
    testWidgets('« Valider » sans avoir rien tapé ⇒ 0 appel, 0 soumission', (
      tester,
    ) async {
      final port = SpyEvaluationPort();
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(_surface(port: port, onSubmitted: emitted.add));

      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(
        port.callCount,
        0,
        reason:
            '🔴 une copie blanche est partie au barème IA : le port a été '
            'appelé avant toute vérification de la saisie',
      );
      expect(
        emitted,
        isEmpty,
        reason:
            '🔴 une soumission a été émise sur une réponse vide — la carte '
            'serait notée sur rien',
      );
    });

    testWidgets('le message de validation EXISTANT est montré', (tester) async {
      final port = SpyEvaluationPort();
      await tester.pumpWidget(_surface(port: port, onSubmitted: (_) {}));

      expect(
        find.text('Réponse requise'),
        findsNothing,
        reason: 'aucun message avant le geste — sinon la garde ne mesure rien',
      );

      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(
        find.text('Réponse requise'),
        findsOneWidget,
        reason:
            '🔴 le refus est SILENCIEUX : rien n\'indique à l\'apprenant '
            'pourquoi son geste n\'a rien fait',
      );
    });

    testWidgets('le refus ne VERROUILLE pas la saisie — on peut resoumettre', (
      tester,
    ) async {
      final port = SpyEvaluationPort();
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(_surface(port: port, onSubmitted: emitted.add));

      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(
        _field(tester).readOnly,
        isFalse,
        reason: '🔴 le refus a verrouillé le champ : la carte est perdue',
      );
      expect(
        find.byKey(K.submit),
        findsOneWidget,
        reason: '🔴 le bouton a disparu après un refus',
      );

      // Le chemin nominal est INCHANGÉ après un refus.
      await tester.enterText(find.byKey(K.answerField), 'ma réponse');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(port.callCount, 1, reason: 'la soumission valide passe');
      expect(emitted, hasLength(1));
      expect(
        find.text('Réponse requise'),
        findsNothing,
        reason: 'le message s\'efface dès que la saisie est valide',
      );
    });

    testWidgets('une saisie de BLANCS seulement est vide elle aussi', (
      tester,
    ) async {
      final port = SpyEvaluationPort();
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(_surface(port: port, onSubmitted: emitted.add));

      await tester.enterText(find.byKey(K.answerField), '   \n  ');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(port.callCount, 0, reason: '🔴 des blancs sont partis au barème');
      expect(emitted, isEmpty);
    });

    testWidgets('« évaluer sans IA » sur du vide ne soumet rien non plus', (
      tester,
    ) async {
      final port = SpyEvaluationPort();
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        _surface(
          port: port,
          onSubmitted: emitted.add,
          allowSkipEvaluation: true,
        ),
      );

      await tester.tap(find.byKey(ZFlashcardAnswerInput.skipEvaluationKey));
      await tester.pumpAndSettle();

      expect(port.callCount, 0);
      expect(
        emitted,
        isEmpty,
        reason:
            '🔴 la voie sans IA a noté une copie blanche au seuil de passage '
            '— la vacuité est une propriété de la SAISIE, pas du barème',
      );
      expect(
        _field(tester).readOnly,
        isFalse,
        reason: 'le refus reste réversible sur cette voie aussi',
      );
    });
  });

  group('Les chemins VOLONTAIRES restent ouverts', () {
    testWidgets('« Je ne sais pas » soumet une carte vide, sans le port', (
      tester,
    ) async {
      final port = SpyEvaluationPort();
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(_surface(port: port, onSubmitted: emitted.add));

      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();

      expect(port.callCount, 0, reason: 'ce chemin n\'a jamais appelé le port');
      expect(
        emitted,
        hasLength(1),
        reason:
            '🔴 le refus de la copie blanche a mangé le chemin « je passe » : '
            'l\'apprenant ne peut plus avancer',
      );
      expect(emitted.single.quality, const ZSrsConfig().minQuality);
    });

    testWidgets('un QCM sans choix coché n\'est pas touché par le refus', (
      tester,
    ) async {
      final List<ZFlashcardSubmission> emitted = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            onQualitySelected: (_) {},
            onSubmitted: emitted.add,
          ),
        ),
      );

      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      // Inertie : le routage local précède le refus, qui ne porte QUE sur la
      // saisie rédigée. Un QCM n'a pas de texte à trouver vide.
      expect(
        emitted,
        hasLength(1),
        reason:
            '🔴 le refus a débordé sur la voie locale : un QCM n\'a pas de '
            'champ de rédaction, sa vacuité n\'est pas la même chose',
      );
      expect(find.text('Réponse requise'), findsNothing);
    });
  });
}
