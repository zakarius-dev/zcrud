import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/fakes/fake_answer_evaluation_port.dart';
import 'package:zcrud_example/demos/fakes/fake_flashcard_hint_port.dart';
import 'package:zcrud_example/demos/fakes/in_memory_study_store.dart';
import 'package:zcrud_example/demos/study_session_demo_screen.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSummaryCelebration;

import 'support/pump_helpers.dart';

/// su-10 D5 — les **témoins `callCount`** des fakes (documentés dans leur dartdoc
/// comme les gardes falsifiantes d'AD-35/AD-36) sont désormais RÉELLEMENT assérés
/// au niveau du parcours assemblé (la prose cesse de mentir : les invariants
/// spine sont exercés bout-en-bout, pas seulement affirmés).
void main() {
  Widget host(
    ZFlashcard card, {
    required FakeAnswerEvaluationPort evalPort,
    FakeFlashcardHintPort? hintPort,
  }) =>
      wrapForTest(
        StudySessionDemoScreen(
          autoStart: StudyAutoStart(
            mode: ZReviewMode.learn,
            queue: <ZFlashcard>[card],
          ),
          store: InMemoryStudyStore(
            cardsById: <String, ZFlashcard>{card.id!: card},
          ),
          evaluationPort: evalPort,
          hintPort: hintPort,
          celebration: ZSummaryCelebration.none,
        ),
      );

  group('D5 / AD-35 — le port d\'évaluation n\'est JAMAIS appelé pour un type '
      'évalué LOCALEMENT (QCM / Vrai-Faux)', () {
    testWidgets('QCM : soumission locale ⇒ evaluationPort.callCount == 0',
        (tester) async {
      useTallSurface(tester);
      final evalPort = FakeAnswerEvaluationPort();
      const qcm = ZFlashcard(
        id: 'q0',
        folderId: 'demoStudyFolder',
        type: ZFlashcardType.multipleChoice,
        question: 'Quel régime suspend les droits ?',
        choices: <ZChoice>[
          ZChoice(content: 'Consommation', isCorrect: false),
          ZChoice(content: 'Transit', isCorrect: true),
        ],
      );
      await tester.pumpWidget(host(qcm, evalPort: evalPort));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('zAnswerChoice_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();

      expect(evalPort.callCount, 0,
          reason: 'AD-35 : un QCM est évalué localement — le port advisory ne '
              'doit JAMAIS être sollicité');
    });

    testWidgets('Vrai/Faux : réponse locale ⇒ evaluationPort.callCount == 0',
        (tester) async {
      useTallSurface(tester);
      final evalPort = FakeAnswerEvaluationPort();
      const vf = ZFlashcard(
        id: 'v0',
        folderId: 'demoStudyFolder',
        type: ZFlashcardType.trueOrFalse,
        question: 'Le BESC est exigé à l\'export.',
        isTrue: false,
      );
      await tester.pumpWidget(host(vf, evalPort: evalPort));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('zAnswerFalse')));
      await tester.pumpAndSettle();

      expect(evalPort.callCount, 0,
          reason: 'AD-35 : un Vrai/Faux est évalué localement — le port advisory '
              'ne doit JAMAIS être sollicité');
    });
  });

  group('D5 / AD-36 — l\'indice STOCKÉ est servi D\'ABORD ; le port n\'est appelé '
      'qu\'APRÈS épuisement du stock', () {
    testWidgets('1ᵉʳ indice = stocké (callCount == 0) ; 2ᵉ = port '
        '(callCount == 1)', (tester) async {
      useTallSurface(tester);
      final evalPort = FakeAnswerEvaluationPort();
      final hintPort = FakeFlashcardHintPort();
      const card = ZFlashcard(
        id: 'h0',
        folderId: 'demoStudyFolder',
        type: ZFlashcardType.openQuestion,
        question: 'Donnez la formule de la valeur en douane.',
        answer: 'V = P + F + A',
        hint: 'Trois termes additifs.',
      );
      await tester.pumpWidget(host(card, evalPort: evalPort, hintPort: hintPort));
      await tester.pumpAndSettle();

      // 1ᵉʳ tap : l'indice STOCKÉ (`ZFlashcard.hint`) est servi — port NON appelé.
      await tester.tap(find.byKey(const ValueKey<String>('zHintButton')));
      await tester.pumpAndSettle();
      expect(hintPort.callCount, 0,
          reason: 'AD-36 : le stock (ZFlashcard.hint) est servi AVANT tout appel '
              'au port');
      expect(find.text('Trois termes additifs.'), findsOneWidget,
          reason: 'l\'indice stocké est bien affiché');

      // 2ᵉ tap : stock épuisé ⇒ le port est appelé (une seule fois).
      await tester.tap(find.byKey(const ValueKey<String>('zHintButton')));
      await tester.pumpAndSettle();
      expect(hintPort.callCount, 1,
          reason: 'AD-36 : le port n\'est sollicité qu\'APRÈS épuisement du stock');
    });
  });
}
