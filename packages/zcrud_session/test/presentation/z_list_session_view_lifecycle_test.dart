/// SU-7 / AC5 — Rien n'est **jamais** persisté ; l'abandon n'écrit RIEN
/// (frontière **DÉCLARÉE**, AD-43/D5).
///
/// ⚠️ **Portée déclarée honnêtement** : `ZListSessionView` est un
/// `StatelessWidget` — il ne détient **aucun** contrôleur, **aucun** état. Il n'y
/// a donc **rien à `dispose`r** dans la vue, et l'injection R3 « retirer le
/// `dispose()` du contrôleur d'examen » ne s'applique **pas à la vue** : elle
/// s'applique à l'**hôte** (qui, lui, détient le moteur `ChangeNotifier`). C'est
/// exactement ce que teste `_dispose du moteur_` ci-dessous.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_exam_harness.dart';

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> answerFirst(WidgetTester tester, String q) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(q),
          matching: find.byType(ZFlashcardAnswerInput),
        ),
        matching: find.byKey(EK.answerTrue),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'AC5 — répondre à 2/3 puis DÉMONTER : aucune exception (AD-10)',
    (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')];
      await tester.pumpWidget(ExamHost(cards: cards));
      await answerFirst(tester, 'Q1');
      await answerFirst(tester, 'Q2');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 AD-10 : l\'abandon d\'un examen a levé une exception.',
      );
    },
  );

  testWidgets(
    'AC5 — au REMONTAGE, un examen NEUF repart en `setup` : rien n\'a été '
    'repris (il n\'y a PAS de brouillon — c\'est un CHOIX, D5)',
    (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2')];
      await tester.pumpWidget(ExamHost(cards: cards, autoStart: false));

      // Contre-preuve : sans `start()`, la phase EST `setup` au départ.
      var host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.engine.phase, ZWhiteExamPhase.setup);

      host.engine.start();
      await tester.pumpAndSettle();
      await answerFirst(tester, 'Q1');
      expect(host.engine.answered, 1, reason: 'une réponse a bien été donnée');

      // Abandon TOTAL, puis retour.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ExamHost(cards: cards, autoStart: false, key: const ValueKey<int>(2)),
      );
      await tester.pumpAndSettle();

      host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.engine.phase, ZWhiteExamPhase.setup,
          reason: '🔴 D5 : un examen repris est un examen faussé.');
      expect(host.engine.answered, 0,
          reason: '🔴 D5 : une réponse a survécu à l\'abandon ⇒ quelque chose a '
              'été persisté, alors que RIEN ne doit l\'être, par aucun chemin.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AC5 — DÉMONTAGE PENDANT une transition (à mi-`pump`) : aucune exception',
    (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2')];
      await tester.pumpWidget(ExamHost(cards: cards));
      await answerFirst(tester, 'Q1');

      // Ouvre le dialog (transition de route RÉELLE), puis démonte AU MILIEU de
      // son animation — jamais après `pumpAndSettle`, qui la ferait disparaître.
      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 AD-10 : démonter pendant une animation a levé (typiquement '
            'un `setState after dispose`).',
      );
    },
  );

  testWidgets(
    'AC5 — en phase `setup`, la saisie est INERTE : aucune réponse ne peut '
    'partir avant `start()` (⇒ le `StateError` d\'`answer()` est '
    'INATTEIGNABLE, sans aucun `try-catch`)',
    (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examCard('Q1')],
          autoStart: false,
        ),
      );
      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.engine.phase, ZWhiteExamPhase.setup);

      // 🔴 On TAPE RÉELLEMENT (présence ≠ association).
      await tester.tap(find.byKey(EK.answerTrue), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(host.answeredIndexes, isEmpty);
      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 `answer()` a été appelé en phase `setup` ⇒ le moteur a levé '
            '`StateError`. Le gate par la PHASE a échoué.',
      );
    },
  );
}
