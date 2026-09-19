import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';

import '../support/z_study_session_harness.dart';

void main() {
  testWidgets('scaffold : réponse, palier ajusté, confirmation et fin réelle', (
    tester,
  ) async {
    useTallSurface(tester);
    final reviewer = FakeSessionReviewer();
    final selected = <int>[];
    var ended = 0;
    await tester.pumpWidget(
      wrapForTest(
        ZStudySessionScaffold(
          title: 'Apprentissage',
          mode: ZReviewMode.learn,
          queue: [
            ZFlashcard(
              id: 'vf',
              folderId: 'f',
              question: 'Le ciel est bleu ?',
              type: ZFlashcardType.trueOrFalse,
              isTrue: true,
            ),
          ],
          reviewer: reviewer.call,
          learning: ZLearningSessionOptions(
            queuePolicy: ZQueuePolicy(reinsertOffsetFor: (_) => 3),
          ),
          onQualitySelected: selected.add,
          onSessionEnd: (_, _) => ended++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('zAnswerTrue')));
    await tester.pumpAndSettle();
    expect(reviewer.writes, 0);
    await tester.tap(find.byKey(const ValueKey<String>('zSrsQuality_4')));
    await tester.pump();
    expect(reviewer.writes, 0);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey<String>('zConfirmLearning')));
    await tester.pumpAndSettle();
    expect(reviewer.qualities, [4]);
    expect(selected, [4]);
    expect(ended, 0); // q4 reste dans la file d'apprentissage.
    expect(
      find.byKey(const ValueKey<String>('zConfirmLearning')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey<String>('zAnswerTrue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('zSrsQuality_5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('zConfirmLearning')));
    await tester.pumpAndSettle();
    expect(reviewer.qualities, [4, 5]);
    expect(reviewer.gradedIds, ['vf', 'vf']);
    expect(ended, 1);
  });
}
