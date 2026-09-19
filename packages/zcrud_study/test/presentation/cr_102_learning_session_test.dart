import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionInfo;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../support/lotw1_seams.dart';
import '../support/lotw2_scaffold.dart';
import '../support/z_study_session_harness.dart';

void main() {
  testWidgets('politique remplacée sans réamorcer la session', (tester) async {
    useTallSurface(tester);
    final reviewer = FakeSessionReviewer();
    final queue = writtenCards(1);
    var completed = false;
    Future<void> mount(ZQueuePolicy policy) async {
      await tester.pumpWidget(wrapForTest(ZStudySessionHost(
        mode: ZReviewMode.learn, queue: queue, reviewer: reviewer.call,
        learning: ZLearningSessionOptions(queuePolicy: policy),
        onSessionEnd: (_, _) => completed = true,
      )));
      await tester.pumpAndSettle();
    }
    await mount(ZQueuePolicy(reinsertOffsetFor: (_) => 3));
    var input = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
    expect(await input.onConfirm!(4), isTrue);
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    await mount(ZQueuePolicy(reinsertOffsetFor: (_) => 3, removeAtOrAbove: 3));
    input = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
    expect(await input.onConfirm!(4), isTrue);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(reviewer.qualities, [4, 4]);
  });
  testWidgets('options apprentissage inertes hors régimes SRS', (tester) async {
    useTallSurface(tester);
    for (final mode in [ZReviewMode.whiteExam, ZReviewMode.cramming, ZReviewMode.list]) {
      await tester.pumpWidget(wrapForTest(ZStudySessionHost(
        mode: mode, queue: writtenCards(2),
        learning: const ZLearningSessionOptions(showProgressBadge: true),
      )));
      await tester.pumpAndSettle();
      final input = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
      expect(input.advanceBehavior, isNull);
      expect(input.onConfirm, isNull);
      expect(input.onSubmitted, isNotNull);
      expect(find.text('0%'), findsNothing);
    }
  });

  testWidgets('review tardive ne modifie pas la nouvelle session', (tester) async {
    useTallSurface(tester);
    final pending = Completer<ZResult<ZRepetitionInfo>>();
    await tester.pumpWidget(wrapForTest(ZStudySessionHost(
      mode: ZReviewMode.learn, queue: writtenCards(2),
      reviewer: ({required flashcardId, required folderId, required quality, now}) => pending.future,
      learning: const ZLearningSessionOptions(),
    )));
    await tester.pumpAndSettle();
    final old = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
    final confirming = old.onConfirm!(5);
    await tester.pumpWidget(wrapForTest(ZStudySessionHost(
      mode: ZReviewMode.learn, queue: writtenCards(3),
      reviewer: FakeSessionReviewer().call,
      learning: const ZLearningSessionOptions(),
    )));
    await tester.pumpAndSettle();
    pending.complete(Right(ZRepetitionInfo(flashcardId: 'c0', folderId: 'f')));
    expect(await confirming, isFalse);
    await tester.pumpAndSettle();
    final current = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
    expect(current.card.id, 'c0');
    expect(tester.takeException(), isNull);
    expect(await current.onConfirm!(5), isTrue);
  });

  testWidgets('exception reviewer devient échec réessayable', (tester) async {
    useTallSurface(tester);
    var calls = 0;
    await tester.pumpWidget(wrapForTest(ZStudySessionHost(
      mode: ZReviewMode.learn, queue: writtenCards(2),
      reviewer: ({required flashcardId, required folderId, required quality, now}) async {
        calls++;
        throw StateError('reviewer indisponible');
      },
      learning: const ZLearningSessionOptions(),
    )));
    await tester.pumpAndSettle();
    final input = tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
    expect(await input.onConfirm!(5), isFalse);
    expect(await input.onConfirm!(5), isFalse);
    expect(calls, 2);
  });
  testWidgets('scaffold wired relaie les options apprentissage', (
    tester,
  ) async {
    useTallSurface(tester);
    final wiring = lotW2Wiring(LotW1Seams(scene: W1Scene.socle, optIn: {'learning'}));
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionScaffold.wired(
          wiring: wiring,
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ZStudySessionHost>(find.byType(ZStudySessionHost)).learning,
      same(wiring.learning),
    );
    expect(
      tester
          .widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput))
          .advanceBehavior,
      isNull,
    );
  });

  testWidgets(
    'échec de confirmation conserve la carte et autorise le réessai',
    (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer(
        failure: const ZDomainFailure('indisponible'),
      );
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: writtenCards(2),
            reviewer: reviewer.call,
            learning: const ZLearningSessionOptions(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = tester.widget<ZFlashcardAnswerInput>(
        find.byType(ZFlashcardAnswerInput),
      );
      expect(await input.onConfirm!(5), isFalse);
      await tester.pumpAndSettle();
      final retry = tester.widget<ZFlashcardAnswerInput>(
        find.byType(ZFlashcardAnswerInput),
      );
      expect(retry.key, input.key);
      expect(retry.card.id, 'c0');
      expect(await retry.onConfirm!(4), isFalse);
      expect(reviewer.writes, 0);
    },
  );

  testWidgets('confirmation écrit une fois puis passe sans seconde retenue', (
    tester,
  ) async {
    useTallSurface(tester);
    final reviewer = FakeSessionReviewer();
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(2),
          reviewer: reviewer.call,
          learning: const ZLearningSessionOptions(showProgressBadge: true),
          labels: const ZStudySessionLabels(confirmAction: 'Suivante'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = tester.widget<ZFlashcardAnswerInput>(
      find.byType(ZFlashcardAnswerInput),
    );
    expect(input.onSubmitted, isNull);
    expect(input.advanceBehavior, ZCardAdvanceBehavior.confirm);
    expect(input.confirmLabel, 'Suivante');
    expect(find.text('0 / 2'), findsOneWidget);
    expect(reviewer.writes, 0);
    final first = input.onConfirm!(5);
    expect(await input.onConfirm!(5), isFalse);
    expect(await first, isTrue);
    await tester.pumpAndSettle();
    expect(reviewer.qualities, [5]);
    expect(
      tester
          .widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput))
          .card
          .id,
      'c1',
    );
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('politique apprentissage réinsère q4 sans lapse', (tester) async {
    useTallSurface(tester);
    final reviewer = FakeSessionReviewer();
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: reviewer.call,
          learning: ZLearningSessionOptions(
            queuePolicy: ZQueuePolicy(reinsertOffsetFor: (_) => 0),
            showProgressBadge: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = tester.widget<ZFlashcardAnswerInput>(
      find.byType(ZFlashcardAnswerInput),
    );
    expect(await input.onConfirm!(4), isTrue);
    await tester.pumpAndSettle();
    final next = tester.widget<ZFlashcardAnswerInput>(
      find.byType(ZFlashcardAnswerInput),
    );
    expect(next.card.id, 'c0');
    expect(next.key, isNot(input.key));
    expect(reviewer.qualities, [4]);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
  });
}
