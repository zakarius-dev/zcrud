import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/fakes/fake_answer_evaluation_port.dart';
import 'package:zcrud_example/demos/fakes/in_memory_study_store.dart';
import 'package:zcrud_example/demos/study_session_demo_screen.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZSessionCardSwiper,
        ZSessionModeSelector,
        ZSessionSummaryView,
        ZSummaryCelebration;

import 'support/pump_helpers.dart';

/// su-10 D2 + D3 — le PREMIER maillon d'AC1 (sélecteur → session) est piloté par
/// un test, et le runtime-par-mode (AD-34) est exercé au-delà du seul `learn`.
void main() {
  ZFlashcard written(String id, String answer) => ZFlashcard(
        id: id,
        folderId: 'demoStudyFolder',
        type: ZFlashcardType.openQuestion,
        question: 'Question $id.',
        answer: answer,
      );

  // ── D2 ────────────────────────────────────────────────────────────────────
  group('D2 — transition RÉELLE sélecteur → session (1ᵉʳ maillon d\'AC1)', () {
    testWidgets('taper une option du ZSessionModeSelector démarre la session '
        '(le swiper apparaît) — `_onStart` / `zReviewModeForKind` EXERCÉS',
        (tester) async {
      useTallSurface(tester);
      // Aucun `autoStart` : on entre par la PHASE SÉLECTEUR (comme un vrai
      // utilisateur depuis l'accueil), pas par le seam de test.
      await tester.pumpWidget(
        wrapForTest(
          StudySessionDemoScreen(
            store: InMemoryStudyStore.demo(),
            celebration: ZSummaryCelebration.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le sélecteur est monté, la session n'a PAS démarré.
      expect(find.byType(ZSessionModeSelector), findsOneWidget);
      expect(find.byType(ZSessionCardSwiper), findsNothing);

      // Le corpus de démo n'a aucun état SRS ⇒ toutes les cartes sont « à
      // apprendre » ⇒ l'option « Apprendre » est présente. On la TAPE.
      await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
      await tester.pumpAndSettle();

      // 🔴 La bascule a bien eu lieu : le swiper est là, le sélecteur a disparu.
      expect(find.byType(ZSessionCardSwiper), findsOneWidget,
          reason: 'onStart → _seedSession → phase studying : le swiper doit '
              's\'afficher (sinon le 1ᵉʳ arc du parcours est mort — su-2)');
      expect(find.byType(ZSessionModeSelector), findsNothing);
    });
  });

  // ── D3 ────────────────────────────────────────────────────────────────────
  group('D3 — runtime par mode au-delà de learn (AD-34)', () {
    testWidgets('whiteExam BOUT-EN-BOUT : start → answer(×2) → submit → result '
        'scoré (total=2, correct=1), zéro exception', (tester) async {
      useTallSurface(tester);
      final queue = <ZFlashcard>[
        written('w0', 'alpha'),
        written('w1', 'beta'),
      ];
      await tester.pumpWidget(
        wrapForTest(
          StudySessionDemoScreen(
            autoStart:
                StudyAutoStart(mode: ZReviewMode.whiteExam, queue: queue),
            evaluationPort: FakeAnswerEvaluationPort(),
            celebration: ZSummaryCelebration.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Carte 0 : réponse JUSTE (q=5). Réponse → soumission (engine.answer) →
      // avance linéaire du swiper (contrat POSITIONNEL de l'examen).
      Finder field() => find.descendant(
            of: find.byKey(const ValueKey<String>('zAnswerField')),
            matching: find.byType(EditableText),
          );
      await tester.enterText(field(), 'alpha');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      // Carte 1 : réponse FAUSSE (q=1 = lapse).
      await tester.enterText(field(), 'réponse fausse');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
      // Avance au-delà de la dernière carte ⇒ onStackEnd ⇒ submit() ⇒ score figé.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final summary = find.byType(ZSessionSummaryView);
      expect(summary, findsOneWidget, reason: 'l\'examen soumis pousse le résumé');
      // 🔴 Le SCORE de l'examen (agrégat pur du moteur) est réellement câblé :
      final result = tester.widget<ZSessionSummaryView>(summary).result;
      expect(result.total, 2, reason: 'les 2 réponses sont comptées');
      expect(result.correct, 1,
          reason: 'q5 (≥ seuil) correcte, q1 (< seuil) incorrecte');
    });

    testWidgets('runtime LINÉAIRE `list` (via seam autoStart) : atteint la fin, '
        'ZÉRO écriture SRS (mode non-SRS — AD-34)', (tester) async {
      useTallSurface(tester);
      final store = InMemoryStudyStore(
        cardsById: <String, ZFlashcard>{
          'l0': written('l0', 'x'),
          'l1': written('l1', 'y'),
        },
      );
      await tester.pumpWidget(
        wrapForTest(
          StudySessionDemoScreen(
            autoStart: StudyAutoStart(
              mode: ZReviewMode.list,
              queue: <ZFlashcard>[written('l0', 'x'), written('l1', 'y')],
            ),
            store: store,
            evaluationPort: FakeAnswerEvaluationPort(),
            celebration: ZSummaryCelebration.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder field() => find.descendant(
            of: find.byKey(const ValueKey<String>('zAnswerField')),
            matching: find.byType(EditableText),
          );
      for (var i = 0; i < 2; i++) {
        await tester.enterText(field(), 'x');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(ZSessionSummaryView), findsOneWidget);
      // 🔴 AD-34 : un mode LINÉAIRE ne câble AUCUN `ZSessionReviewer` — aucune
      // écriture SRS n'a pu se produire (pas de porte dérobée).
      expect(store.srsWrites, 0,
          reason: 'le runtime linéaire (list) n\'écrit JAMAIS de SRS');
    });

    testWidgets('runtime `cramming` (via seam autoStart) : se déroule sans '
        'exception et n\'écrit AUCUN SRS (mode non-SRS — AD-34)', (tester) async {
      useTallSurface(tester);
      final store = InMemoryStudyStore(
        cardsById: <String, ZFlashcard>{'k0': written('k0', 'x')},
      );
      await tester.pumpWidget(
        wrapForTest(
          StudySessionDemoScreen(
            autoStart: StudyAutoStart(
              mode: ZReviewMode.cramming,
              queue: <ZFlashcard>[written('k0', 'x')],
            ),
            store: store,
            evaluationPort: FakeAnswerEvaluationPort(),
            celebration: ZSummaryCelebration.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('zAnswerField')),
          matching: find.byType(EditableText),
        ),
        'x',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(store.srsWrites, 0,
          reason: 'cramming (runtime linéaire) n\'écrit JAMAIS de SRS');
    });
  });
}
