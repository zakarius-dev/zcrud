// CR-LEX-13 / CR-LEX-18 — deux modèles d'interaction que la surface imposait.
//
// CR-13 : le choix « avec/sans IA » était une propriété de CONSTRUCTION (port
//         fourni ou non). Un hôte qui l'offre comme AFFORDANCE — bouton
//         d'auto-évaluation à côté du bouton IA — devait remonter le widget à
//         chaque bascule.
// CR-18 : l'indice STOCKÉ n'était servi qu'au tap. Adopter la surface faisait
//         donc DISPARAÎTRE de l'écran un contenu que l'hôte affichait toujours,
//         et en rendait l'obtention payante (plafond AD-36).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

const _written = ZFlashcard(
  question: 'Q',
  answer: 'A',
  type: ZFlashcardType.openQuestion,
);

const _withHint = ZFlashcard(
  question: 'Q',
  answer: 'A',
  type: ZFlashcardType.openQuestion,
  hint: 'Un indice stocké',
);

final Finder _skip = find.byKey(ZFlashcardAnswerInput.skipEvaluationKey);

void main() {
  group('CR-LEX-13 — « évaluer sans IA » au RUNTIME', () {
    testWidgets('🔴 le bouton soumet SANS appeler le port', (tester) async {
      final port = SpyEvaluationPort();
      ZFlashcardSubmission? submitted;
      await tester.pumpWidget(host(ZFlashcardAnswerInput(
        card: _written,
        mode: ZReviewMode.learn,
        evaluationPort: port,
        allowSkipEvaluation: true,
        onSubmitted: (s) => submitted = s,
      )));

      await tester.enterText(find.byType(TextField), 'ma réponse');
      expect(_skip, findsOneWidget);
      await tester.tap(_skip);
      await tester.pumpAndSettle();

      // Discriminant : avant, TOUTE soumission traversait le port dès qu'il
      // était fourni — aucune branche d'esquive par soumission.
      expect(port.callCount, 0, reason: 'le port ne doit PAS être appelé');
      expect(submitted, isNotNull, reason: 'la soumission a bien lieu');
    });

    testWidgets('la soumission normale appelle TOUJOURS le port', (tester) async {
      final port = SpyEvaluationPort();
      await tester.pumpWidget(host(ZFlashcardAnswerInput(
        card: _written,
        mode: ZReviewMode.learn,
        evaluationPort: port,
        allowSkipEvaluation: true,
      )));
      await tester.enterText(find.byType(TextField), 'ma réponse');
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();
      expect(port.callCount, 1, reason: 'les deux voies coexistent');
    });

    testWidgets('allowSkipEvaluation:false (défaut) ⇒ bouton ABSENT',
        (tester) async {
      await tester.pumpWidget(host(ZFlashcardAnswerInput(
        card: _written,
        mode: ZReviewMode.learn,
        evaluationPort: SpyEvaluationPort(),
      )));
      expect(_skip, findsNothing);
    });

    testWidgets('sans port ⇒ bouton ABSENT (rien à esquiver)', (tester) async {
      await tester.pumpWidget(host(const ZFlashcardAnswerInput(
        card: _written,
        mode: ZReviewMode.learn,
        allowSkipEvaluation: true,
      )));
      expect(_skip, findsNothing);
    });
  });

  group('CR-LEX-18 — indice stocké servi d\'emblée', () {
    testWidgets('🔴 revealStoredHint ⇒ l\'indice est visible SANS geste',
        (tester) async {
      await tester.pumpWidget(host(const ZFlashcardAnswerInput(
        card: _withHint,
        mode: ZReviewMode.learn,
        revealStoredHint: true,
      )));
      await tester.pump();
      expect(find.text('Un indice stocké'), findsOneWidget);
    });

    testWidgets('false (défaut) ⇒ l\'indice reste derrière le bouton',
        (tester) async {
      await tester.pumpWidget(host(const ZFlashcardAnswerInput(
        card: _withHint,
        mode: ZReviewMode.learn,
      )));
      await tester.pump();
      expect(find.text('Un indice stocké'), findsNothing);
      expect(find.byKey(K.hintButton), findsOneWidget);
    });

    testWidgets('🔴 l\'indice révélé d\'emblée est COMPTÉ (hintsUsed)',
        (tester) async {
      // Point crucial : il passe par la MÊME voie que le bouton. Un chemin
      // parallèle l'afficherait sans le compter — la pénalité divergerait de ce
      // que l'utilisateur a réellement vu, précisément le défaut du
      // contournement app-side.
      final port = SpyEvaluationPort();
      await tester.pumpWidget(host(ZFlashcardAnswerInput(
        card: _withHint,
        mode: ZReviewMode.learn,
        evaluationPort: port,
        revealStoredHint: true,
      )));
      await tester.enterText(find.byType(TextField), 'r');
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();
      expect(port.request?.hintsUsed, 1);
    });

    testWidgets('une carte SANS indice ne rend rien de plus', (tester) async {
      await tester.pumpWidget(host(const ZFlashcardAnswerInput(
        card: _written,
        mode: ZReviewMode.learn,
        revealStoredHint: true,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
