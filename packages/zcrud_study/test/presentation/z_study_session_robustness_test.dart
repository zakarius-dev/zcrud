/// **Lot 1 « étude »** — AD-10 : chaque cas dégradé assère une **ISSUE**, pas
/// « aucune exception ».
///
/// 🔴 `expect(tester.takeException(), isNull)` seul est une garde faible : un
/// écran gelé, muet et sans sortie ne lève aucune exception non plus. Chaque
/// test ci-dessous nomme donc ce qui doit **rester possible** pour l'apprenant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZDomainFailure;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart' show ZFlashcardSubmission;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

void main() {
  Finder answerField() => find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );

  testWidgets(
      '🔴 session VIDE (0 carte) : issue de sortie PRÉSENTE et CÂBLÉE — jamais '
      'un cul-de-sac', (tester) async {
    useTallSurface(tester);
    var exited = 0;
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: const [],
          reviewer: FakeSessionReviewer().call,
          onExit: () => exited++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Finder exit = find.byKey(ZStudySessionView.exitButtonKey);
    expect(exit, findsOneWidget);
    await tester.tap(exit);
    expect(exited, 1, reason: '🔴 une issue non câblée est un bouton mort');
  });

  testWidgets(
      'session d\'UNE carte : un LAPSE ne termine PAS (le moteur SRS est '
      'CYCLIQUE), une RÉUSSITE termine — la fin reste atteignable',
      (tester) async {
    useTallSurface(tester);
    var ended = 0;
    late void Function(int) grade;
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: <ZFlashcard>[writtenCard('solo')],
          reviewer: FakeSessionReviewer().call,
          onSessionEnd: (_, _) => ended++,
          // Slot de notation minimal : il route une qualité CHOISIE vers le
          // runtime. C'est la voie `submit` du host, exercée directement — sans
          // dépendre du barème advisory de la surface par défaut.
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
    expect(tester.takeException(), isNull,
        reason: '`numberOfCardsDisplayed = min(2, 1)` — une file d\'UNE carte '
            'ne doit pas faire lever l\'assert du paquet de swipe');

    // 🔴 LAPSE (q=0 < seuil 3) : le moteur RÉINSÈRE la carte — la session
    // continue. C'est le contrat SRS, pas un défaut : une carte ratée doit
    // revenir. Une session qui se terminerait ici perdrait la reprise.
    grade(0);
    await tester.pumpAndSettle();
    expect(ended, 0,
        reason: '🔴 un lapse ne termine PAS une session SRS : le moteur est '
            'CYCLIQUE (il réinsère les ratés en aval)');

    // RÉUSSITE (q=5 ≥ seuil) : la carte est consommée, la file se vide, la fin
    // est poussée — exactement une fois (latch).
    grade(5);
    await tester.pumpAndSettle();
    expect(ended, 1, reason: 'une réussite consomme la carte ⇒ fin atteinte');
  });

  testWidgets(
      '🔴 PORT EN ÉCHEC (`Left`) : la saisie N\'EST PAS perdue, aucune '
      'exception, ZÉRO écriture SRS aboutie', (tester) async {
    useTallSurface(tester);
    final reviewer = FakeSessionReviewer(
      failure: const ZDomainFailure('SRS indisponible (harnais)'),
    );
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: <ZFlashcard>[writtenCard('w0', answer: 'attendu')],
          reviewer: reviewer.call,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(answerField(), 'ma réponse');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '🔴 un échec de port est un `Left`, jamais une exception');
    final EditableText editable = tester.widget<EditableText>(answerField());
    expect(editable.controller.text, 'ma réponse',
        reason: '🔴 la saisie DOIT survivre à l\'échec du port : l\'apprenant '
            'ne doit pas retaper sa réponse parce que le réseau a lâché');
    expect(reviewer.writes, 0,
        reason: 'l\'écriture a échoué (`Left`) — le compteur reste à 0');
  });

  testWidgets(
      '🔴 AD-34 — mode SRS SANS reviewer : repli explicite + issue, aucun '
      'no-op fabriqué, aucun throw', (tester) async {
    useTallSurface(tester);
    var exited = 0;
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(3),
          // reviewer VOLONTAIREMENT absent.
          onExit: () => exited++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '🔴 un `assert` du moteur linéaire — ou un `!` sur le seam — '
            'ferait tomber l\'écran ici');
    expect(find.byKey(ZStudySessionView.unavailableKey), findsOneWidget,
        reason: '🔴 le diagnostic doit être DIT : une session muette qui '
            'n\'écrit rien serait pire qu\'un refus explicite');
    // …et surtout : la session n'a PAS démarré en douce sur un runtime qui
    // n'écrirait rien (la porte dérobée qu'AD-34 ferme).
    expect(find.byKey(const ValueKey<String>('zAnswerField')), findsNothing);
    await tester.tap(find.byKey(ZStudySessionView.exitButtonKey));
    expect(exited, 1);
  });

  testWidgets(
      'ABANDON en cours : démontage propre, aucun timer survivant ne tire sur '
      'un arbre mort', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(3),
          reviewer: FakeSessionReviewer().call,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // L'apprenant quitte : l'arbre est remplacé ⇒ `dispose`.
    await tester.pumpWidget(wrapForTest(const Text('ailleurs')));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull,
        reason: '🔴 un notifier non libéré, ou un `grade` en vol qui écrirait '
            'après démontage, lèverait ici');
    expect(find.text('ailleurs'), findsOneWidget);
  });

  testWidgets(
      '🔴 un `grade` EN VOL au moment du démontage n\'écrit pas sur un `State` '
      'mort', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(3),
          reviewer: FakeSessionReviewer().call,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Note lancée…
    await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
    // …et démontage AVANT que le `Future` du seam ne retombe.
    await tester.pumpWidget(wrapForTest(const Text('parti')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '🔴 la garde `if (!mounted) return` de `_gradeAndAdvance` est '
            'ce qui empêche une écriture de tranche sur un `State` démonté');
  });

  testWidgets('une carte SANS `id` est écartée sans faire tomber la session',
      (tester) async {
    useTallSurface(tester);
    // Carte éphémère (id nul) mêlée à deux cartes valides : la file doit se
    // construire sur les identités résolubles, jamais lever.
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: <ZFlashcard>[
            writtenCard('k0'),
            // Carte ÉPHÉMÈRE : `id == null` (AD-14). Elle n'a pas d'identité,
            // donc aucune entrée possible dans la file ni dans la table.
            const ZFlashcard(
              folderId: kHarnessFolderId,
              type: ZFlashcardType.openQuestion,
              question: 'Carte éphémère.',
              answer: 'x',
            ),
            writtenCard('k1'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_k0')),
        findsOneWidget);
  });
}
