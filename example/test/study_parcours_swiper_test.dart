import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show DomainFailure;
import 'package:zcrud_example/demos/fakes/in_memory_study_store.dart';
import 'package:zcrud_example/demos/study_session_demo_screen.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionCardSwiper, ZSessionSummaryView, ZSummaryCelebration;

import 'support/pump_helpers.dart';

/// T7 (AC5/AC7) — fluidité de la pile + robustesse AD-10 + latch `onStackEnd`.
void main() {
  List<ZFlashcard> writtenCards(int n) => <ZFlashcard>[
        for (var i = 0; i < n; i++)
          ZFlashcard(
            id: 'c$i',
            folderId: 'demoStudyFolder',
            type: ZFlashcardType.openQuestion,
            question: 'Question **markdown** n°$i.',
            answer: 'r$i',
          ),
      ];

  StudyAutoStart start(int n, {ZReviewMode mode = ZReviewMode.learn}) =>
      StudyAutoStart(mode: mode, queue: writtenCards(n));

  Widget host(
    StudyAutoStart auto, {
    RebuildLog? log,
    InMemoryStudyStore? store,
    VoidCallback? onSummaryShown,
  }) =>
      wrapForTest(
        StudySessionDemoScreen(
          autoStart: auto,
          rebuildLog: log,
          store: store,
          onSummaryShown: onSummaryShown,
          celebration: ZSummaryCelebration.none,
        ),
      );

  group('AC7 — fluidité de la pile', () {
    testWidgets('aucune carte HORS-ÉCRAN n\'est construite à l\'avance '
        '(fenêtrage : la 4ᵉ carte n\'existe pas au montage)', (tester) async {
      useTallSurface(tester);
      final log = RebuildLog();
      await tester.pumpWidget(host(start(4), log: log));
      await tester.pumpAndSettle();

      // `numberOfCardsDisplayed = min(2, 4)` ⇒ seules 2 cartes sont montées.
      expect(log.countOf('card_c0'), greaterThan(0));
      expect(log.countOf('card_c3'), 0,
          reason: 'la 4ᵉ carte (hors-écran) ne doit PAS être construite au '
              'montage — sinon la pile n\'est pas fenêtrée (coût O(n))');
    });

    testWidgets('la progression atteint `onStackEnd` → écran de célébration '
        '(isLoop:false ; la pile se termine)', (tester) async {
      useTallSurface(tester);
      var summaries = 0;
      await tester.pumpWidget(host(start(3), onSummaryShown: () => summaries++));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(summaries, 1, reason: 'la pile finie pousse la célébration');
      expect(find.byType(ZSessionSummaryView), findsOneWidget);
    });
  });

  group('AC4 — latch one-shot `onStackEnd`', () {
    testWidgets('la célébration est poussée EXACTEMENT une fois '
        '(compteur == 1) et le swiper disparaît', (tester) async {
      useTallSurface(tester);
      var summaries = 0;
      await tester.pumpWidget(host(start(2), onSummaryShown: () => summaries++));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(summaries, 1);
      // Le swiper a cédé la place au résumé (plus de bouton d'avance) ⇒ aucune
      // ré-émission possible : le latch tient PAR CONSTRUCTION.
      expect(find.byKey(ZSessionCardSwiper.nextButtonKey), findsNothing);
      expect(find.byType(ZSessionSummaryView), findsOneWidget);
    });
  });

  group('AC5 — robustesse AD-10 (chaque cas assère une ISSUE, pas « aucune '
      'exception »)', () {
    testWidgets('session VIDE (0 carte) : issue de sortie présente, aucun '
        'cul-de-sac', (tester) async {
      await tester.pumpWidget(host(start(0)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Une ISSUE existe (bouton de retour) — jamais un écran vide bloquant.
      final finish = find.byKey(const ValueKey<String>('studyEmptyFinish'));
      expect(finish, findsOneWidget);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      // Retour au sélecteur (le corpus de démo n'est pas vide) : parcours vivant.
      expect(find.byType(ZSessionSummaryView), findsNothing);
    });

    testWidgets('session d\'UNE carte : atteint la fin en 1 avance '
        '(numberOfCardsDisplayed = min(2,1))', (tester) async {
      useTallSurface(tester);
      var summaries = 0;
      await tester.pumpWidget(host(start(1), onSummaryShown: () => summaries++));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(summaries, 1, reason: 'une carte ⇒ une avance ⇒ fin atteignable');
    });

    testWidgets('ABANDON en cours : démontage propre, aucun timer survivant '
        'ne tire sur un arbre mort', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(start(3)));
      await tester.pumpAndSettle();
      // L'apprenant quitte : on remplace le parcours par un autre arbre → dispose.
      await tester.pumpWidget(wrapForTest(const Text('ailleurs')));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull,
          reason: 'un Timer/ticker survivant appellerait sur un State démonté');
      expect(find.text('ailleurs'), findsOneWidget);
    });

    testWidgets('PORT en échec (écriture SRS) : la saisie n\'est PAS perdue, '
        'l\'échec est typé (Left), zéro écriture SRS', (tester) async {
      useTallSurface(tester);
      final store = InMemoryStudyStore.demo(
        reviewFailure: const DomainFailure('SRS indisponible (fake)'),
      );
      // Un seul écran, mode learn (spaced/learn = seuls à écrire du SRS).
      await tester.pumpWidget(
        host(
          const StudyAutoStart(
            mode: ZReviewMode.learn,
            queue: <ZFlashcard>[
              ZFlashcard(
                id: 'w0',
                folderId: 'demoStudyFolder',
                type: ZFlashcardType.openQuestion,
                question: 'Question rédigée.',
                answer: 'attendu',
              ),
            ],
          ),
          store: store,
        ),
      );
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'ma réponse');
      await tester.pump();
      // Soumettre → advisory (succès) puis écriture SRS (échec Left).
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un échec de port est un Left, jamais une exception (AD-10)');
      // Saisie NON perdue : le texte soumis reste lisible dans le champ.
      final editable = tester.widget<EditableText>(field);
      expect(editable.controller.text, 'ma réponse',
          reason: 'la saisie doit survivre à l\'échec du port');
      // Échec TYPÉ ⇒ aucune écriture SRS n\'a abouti.
      expect(store.srsWrites, 0,
          reason: 'l\'écriture SRS a échoué (Left) — le compteur reste à 0');
    });

    testWidgets('CONTRÔLE POSITIF du seam SRS : store SAIN ⇒ une soumission '
        'learn ÉCRIT bien du SRS (srsWrites == 1) — le « 0 » ci-dessus n\'est '
        'pas un câblage mort', (tester) async {
      useTallSurface(tester);
      final store = InMemoryStudyStore.demo(); // aucun échec configuré.
      await tester.pumpWidget(
        host(
          const StudyAutoStart(
            mode: ZReviewMode.learn,
            queue: <ZFlashcard>[
              ZFlashcard(
                id: 'w0',
                folderId: 'demoStudyFolder',
                type: ZFlashcardType.openQuestion,
                question: 'Question rédigée.',
                answer: 'attendu',
              ),
            ],
          ),
          store: store,
        ),
      );
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'attendu');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
      expect(store.srsWrites, 1,
          reason: '🔴 le seam d\'écriture SRS est réellement câblé (spaced/learn) '
              '— sinon l\'assertion « 0 » du test d\'échec serait infalsifiable');
    });

    testWidgets('RE-SEED de la file (resync didUpdateWidget) : le moteur SRS est '
        'ré-amorcé sur la NOUVELLE file, la carte courante périmée disparaît, '
        'aucun RangeError', (tester) async {
      useTallSurface(tester);
      // File de 3 cartes SRS. On fait AVANCER le moteur (un lapse déplace son
      // front de c0 → c1), puis on change la file d'entrée : le resync
      // `didUpdateWidget` doit ré-amorcer un moteur NEUF sur la nouvelle file
      // (front = c0), effaçant le curseur périmé (c1) — la leçon su-8.
      var auto = start(3);
      late void Function(void Function()) setOuter;
      await tester.pumpWidget(
        wrapForTest(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return StudySessionDemoScreen(
                autoStart: auto,
                celebration: ZSummaryCelebration.none,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Départ : le front du moteur est c0.
      expect(find.byKey(const ValueKey<String>('answer_c0')), findsOneWidget);

      // « Je ne sais pas » sur c0 ⇒ lapse : le moteur réinsère c0 en aval et son
      // front devient c1 (le swiper SUIT la file dynamique — su-10 D1).
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('answer_c1')), findsOneWidget,
          reason: 'après un lapse, le front du moteur SRS avance à c1');

      // La file d'entrée change (2 cartes FRAÎCHES c0, c1) : re-seed attendu.
      setOuter(() => auto = start(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un index survivant à la file provoquerait un RangeError '
              '(su-4 D1) — le re-seed didUpdateWidget doit le rouvrir proprement');
      // 🔴 FALSIFIABLE (leçon su-7/su-8) : le moteur est ré-amorcé sur la NOUVELLE
      // file ⇒ son front redevient c0. Sans resync, le moteur garderait sa file
      // post-lapse [c1, c0, c2] et son front resterait c1 → answer_c1 survivrait,
      // answer_c0 serait absent → ROUGE (queue périmée).
      expect(find.byKey(const ValueKey<String>('answer_c0')), findsOneWidget,
          reason: 're-seed : le moteur repart sur le front de la nouvelle file');
      expect(find.byKey(const ValueKey<String>('answer_c1')), findsNothing,
          reason: 'le front périmé (c1) de l\'ANCIENNE session ne survit pas au '
              're-seed — sinon queue périmée (su-8)');
    });
  });
}
