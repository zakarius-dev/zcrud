/// **Lot 1 « étude »** — PORTAGE des suites de parcours de l'assemblage de
/// référence, assertion par assertion, sur `ZStudySessionHost`.
///
/// ## Pourquoi un portage, et pas une réutilisation
///
/// `example/test/study_parcours_{sm1,modes,swiper}_test.dart` sont câblées sur
/// `StudySessionDemoScreen` / `StudyAutoStart` / `rebuildLog` — le triplet de
/// la **démo**, pas du socle. Les faire passer « sur mon widget » demanderait de
/// **rebaser la démo** sur `ZStudySessionHost`, c'est-à-dire d'écrire dans
/// `example/` — hors du périmètre de ce lot.
///
/// Ce fichier porte donc leurs **assertions**, exercées sur le socle :
///
/// | Suite d'origine | Assertion portée |
/// |---|---|
/// | `swiper` AC7 | fenêtrage : la 4ᵉ carte n'est pas construite au montage |
/// | `swiper` AC7 | la progression atteint `onStackEnd` → fin de session |
/// | `swiper` AC4 | latch one-shot : la fin est poussée **exactement une fois** |
/// | `modes` D3 | `whiteExam` bout-en-bout : `total=2`, `correct=1` |
/// | `modes` D3 | `list` / `cramming` : zéro écriture SRS |
///
/// (`sm1` est porté à part, dans `z_study_session_sm1_test.dart`.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardSubmission, ZSessionCardSwiper;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import '../support/z_study_session_harness.dart';

void main() {
  group('AC7 — fluidité de la pile', () {
    testWidgets(
        'aucune carte HORS-ÉCRAN n\'est construite à l\'avance (fenêtrage : '
        'la 4ᵉ carte n\'existe pas au montage)', (tester) async {
      useTallSurface(tester);
      final log = RebuildLog();
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: writtenCards(4),
            reviewer: FakeSessionReviewer().call,
            cardBuilder: (BuildContext c, ZFlashcard card) => RebuildProbe(
              name: 'card_${card.id}',
              log: log,
              child: Text('carte ${card.id}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(log.countOf('card_c0'), greaterThan(0),
          reason: 'sonde vivante : la carte de devant EST construite');
      expect(log.countOf('card_c3'), 0,
          reason: '🔴 la 4ᵉ carte (hors-écran) ne doit PAS être construite au '
              'montage — sinon la pile n\'est pas fenêtrée (coût O(n))');
    });

    testWidgets('la progression atteint `onStackEnd` → fin de session',
        (tester) async {
      useTallSurface(tester);
      var ended = 0;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(3),
            onSessionEnd: (_, _) => ended++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(ended, 1, reason: 'la pile finie pousse la fin de session');
    });
  });

  group('AC4 — latch one-shot de fin de session', () {
    testWidgets(
        '🔴 la fin est poussée EXACTEMENT une fois et le swiper cède la place',
        (tester) async {
      useTallSurface(tester);
      var ended = 0;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            onSessionEnd: (_, _) => ended++,
            summaryBuilder: (BuildContext c, ZStudySessionResult r, Duration d) =>
                Text('RÉSUMÉ ${r.total}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(ended, 1);
      // Le swiper a cédé la place ⇒ aucune ré-émission possible : le latch
      // tient PAR CONSTRUCTION, en plus de tenir par le drapeau.
      expect(find.byKey(ZSessionCardSwiper.nextButtonKey), findsNothing);
      expect(find.textContaining('RÉSUMÉ'), findsOneWidget);
    });
  });

  group('D3 — runtime par mode au-delà de `learn` (AD-34)', () {
    testWidgets(
        '🔴 `whiteExam` BOUT-EN-BOUT : 2 réponses (une juste, une fausse) ⇒ '
        'résultat scoré `total=2`, `correct=1`, zéro exception', (tester) async {
      useTallSurface(tester);
      ZStudySessionResult? captured;
      late void Function(int) grade;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.whiteExam,
            queue: writtenCards(2),
            onSessionEnd: (ZStudySessionResult r, Duration d) => captured = r,
            gradingBuilder: (BuildContext c, item, submit) {
              grade = (int q) => submit(
                    ZFlashcardSubmission(
                      quality: q,
                      timeTaken: Duration.zero,
                      hintsUsed: 0,
                    ),
                  );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Carte 0 : JUSTE (q=5 ≥ seuil 3). Puis avance POSITIONNELLE (l'examen a
      // une file FIXE : c'est le swiper qui commande la progression).
      grade(5);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      // Carte 1 : FAUSSE (q=1 < seuil).
      grade(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(captured, isNotNull, reason: 'l\'examen soumis pousse son résultat');
      expect(captured!.total, 2, reason: 'les 2 réponses sont comptées');
      expect(captured!.correct, 1,
          reason: '🔴 q5 (≥ seuil) correcte, q1 (< seuil) incorrecte — le score '
              'vient du MOTEUR (scoreur légitime), pas d\'un recompte local');
    });

    testWidgets(
        '🔴 `list` : atteint la fin, ZÉRO écriture SRS (mode non-SRS — AD-34)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      var ended = 0;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            // Seam FOURNI : s'il était consommé par un mode linéaire, le
            // compteur le dirait. On cherche la porte dérobée, on ne la
            // suppose pas absente.
            reviewer: reviewer.call,
            onSessionEnd: (_, _) => ended++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(ended, 1);
      expect(reviewer.writes, 0,
          reason: '🔴 le runtime linéaire (`list`) n\'écrit JAMAIS de SRS');
    });

    testWidgets(
        '🔴 `cramming` : se déroule sans exception, ZÉRO écriture SRS, et un '
        'raté RE-BOUCLE (c\'est ce qui le distingue de `list`)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.cramming,
            queue: writtenCards(2),
            reviewer: reviewer.call,
            counterBuilder: (BuildContext c, ZStudySessionProgress p) =>
                Text('restant:${p.remaining} lapses:${p.lapses}'),
            gradingBuilder: (BuildContext c, item, submit) {
              grade = (int q) => submit(
                    ZFlashcardSubmission(
                      quality: q,
                      timeTaken: Duration.zero,
                      hintsUsed: 0,
                    ),
                  );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('restant:2 lapses:0'), findsOneWidget);

      // Raté ⇒ re-boucle : la carte est réinsérée, le compteur de lapses monte
      // et le restant NE DESCEND PAS. C'est la propriété propre au cramming.
      grade(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('restant:2 lapses:1'), findsOneWidget,
          reason: '🔴 en cramming un raté RE-BOUCLE — sinon le mode se '
              'comporterait comme `list` et son intérêt disparaîtrait');
      expect(reviewer.writes, 0,
          reason: '🔴 `cramming` (runtime linéaire) n\'écrit JAMAIS de SRS');
    });
  });
}
