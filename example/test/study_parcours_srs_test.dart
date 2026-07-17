import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/fakes/fake_answer_evaluation_port.dart';
import 'package:zcrud_example/demos/fakes/in_memory_study_store.dart';
import 'package:zcrud_example/demos/study_session_demo_screen.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionSummaryView, ZSummaryCelebration;

import 'support/pump_helpers.dart';

/// su-10 D1 (MAJEUR) — **CHAQUE note d'une session SRS multi-cartes atteint le
/// SRS**, y compris après un lapse (qui, avant la correction, faisait diverger le
/// curseur du moteur — file CYCLIQUE — de celui du swiper — file FIXE — et
/// sautait SILENCIEUSEMENT toutes les notes suivantes).
///
/// 🔴 R3 (rougir par le COMPORTEMENT) : ce test pilote un parcours SRS
/// **auto-avançant** (chaque soumission fait suivre le swiper à la file dynamique
/// du moteur). Sous l'ancienne implémentation (soumettre n'avançait pas le
/// swiper), la 1ʳᵉ carte restait figée « corrigée » après le lapse : la 2ᵉ
/// soumission ne trouverait plus de bouton de soumission ⇒ ROUGE, et `srsWrites`
/// resterait à 1 (au lieu de 4) ⇒ ROUGE.
void main() {
  ZFlashcard written(String id) => ZFlashcard(
        id: id,
        folderId: 'demoStudyFolder',
        type: ZFlashcardType.openQuestion,
        question: 'Question **markdown** $id.',
        answer: 'r_$id',
      );

  testWidgets(
      '🔴 session learn de 3 cartes AVEC un lapse : les 4 notes atteignent TOUTES '
      'le SRS (srsWrites == nb de soumissions, les 3 cartes écrites)',
      (tester) async {
    useTallSurface(tester);
    final queue = <ZFlashcard>[written('c0'), written('c1'), written('c2')];
    final store = InMemoryStudyStore(
      cardsById: <String, ZFlashcard>{for (final c in queue) c.id!: c},
    );
    // Port advisory qui pré-sélectionne TOUJOURS une réussite (q=5) sur la voie
    // rédigée — le lapse, lui, viendra du bouton « Je ne sais pas » (borne basse).
    final evalPort = FakeAnswerEvaluationPort(correctQuality: 5, wrongQuality: 5);

    await tester.pumpWidget(
      wrapForTest(
        StudySessionDemoScreen(
          autoStart: StudyAutoStart(mode: ZReviewMode.learn, queue: queue),
          store: store,
          evaluationPort: evalPort,
          celebration: ZSummaryCelebration.none,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Départ : le front du moteur est c0.
    expect(find.byKey(const ValueKey<String>('answer_c0')), findsOneWidget);

    // NOTE 1 — LAPSE sur c0 (« Je ne sais pas ») : la carte est réinsérée en aval
    // et le front avance. Sans la correction su-10, cette note passe, mais toutes
    // les SUIVANTES seraient sautées.
    await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
    await tester.pumpAndSettle();

    // NOTES 2..4 — trois réponses rédigées (réussite) sur les cartes suivantes
    // (c1, puis c0 réinséré, puis c2). Le parcours AVANCE de lui-même à chaque
    // soumission ⇒ un nouveau champ apparaît tant qu'il reste des cartes.
    for (var i = 0; i < 3; i++) {
      final field = find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );
      expect(field, findsOneWidget,
          reason: 'la carte suivante doit s\'afficher (parcours auto-avançant) — '
              'sinon le curseur du moteur et celui du swiper ont divergé (D1)');
      await tester.enterText(field, 'réponse $i');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
    }

    // 🔴 L'ASSERTION PORTEUSE : 4 soumissions ⇒ 4 écritures SRS. Une note sautée
    // (le bug D1) donnerait srsWrites < 4.
    expect(store.srsWrites, 4,
        reason: 'chaque soumission (1 lapse + 3 réussites) DOIT emprunter la voie '
            'd\'écriture SRS — aucune note silencieusement sautée');
    // Contenu correct PAR CARTE : les 3 cartes distinctes ont bien reçu un état
    // SRS (c2, la dernière, était précisément celle que l\'ancien garde perdait).
    expect(store.srsById.keys, containsAll(<String>['c0', 'c1', 'c2']),
        reason: 'les 3 cartes distinctes ont chacune un état SRS écrit');
    // La session se termine sur la célébration (fin de la séquence du moteur).
    expect(find.byType(ZSessionSummaryView), findsOneWidget);
  });
}
