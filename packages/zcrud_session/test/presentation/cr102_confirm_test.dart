import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZAnswerGradingVisibility;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'z_answer_input_harness.dart';

void main() {
  testWidgets('correction différée garde confirmation et cible tactile 48dp', (
    tester,
  ) async {
    final grades = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.whiteExam,
              correctionVisibility: ZCorrectionVisibility.deferred,
              advanceBehavior: ZCardAdvanceBehavior.confirm,
              onAdvanceWithQuality: grades.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(K.answerTrue));
    await tester.pump();
    final button = find.byKey(const ValueKey<String>('zConfirmLearning'));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.byKey(const ValueKey<String>('zSrsQuality_5')), findsNothing);
    await tester.tap(button);
    expect(grades, hasLength(1));
  });
  testWidgets('palier manuel avant réponse attend aussi confirmation', (
    tester,
  ) async {
    final grades = <int>[];
    await tester.pumpWidget(
      host(
        ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.learn,
          advanceBehavior: ZCardAdvanceBehavior.confirm,
          gradingVisibility: ZAnswerGradingVisibility.always,
          onAdvanceWithQuality: grades.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('zSrsQuality_4')));
    await tester.pump();
    expect(grades, isEmpty);
    await tester.tap(find.byKey(const ValueKey<String>('zConfirmLearning')));
    await tester.pump();
    expect(grades, [4]);
  });
  testWidgets(
    'confirmation transmet le palier choisi une seule fois et permet réessai',
    (tester) async {
      final grades = <int>[];
      final pending = Completer<bool>();
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard().copyWith(
              explanation: 'Parce que la règle le prévoit.',
            ),
            mode: ZReviewMode.learn,
            advanceBehavior: ZCardAdvanceBehavior.confirm,
            confirmLabel: 'Continuer mon apprentissage',
            feedbackTitleFor: (q) => 'Palier $q',
            explanationTitle: 'Pourquoi cette réponse ?',
            onConfirm: (q) {
              grades.add(q);
              return grades.length == 1 ? pending.future : Future.value(true);
            },
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(grades, isEmpty);
      expect(find.text('Pourquoi cette réponse ?'), findsOneWidget);
      expect(find.text('Parce que la règle le prévoit.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('zSrsQuality_3')));
      await tester.pump();
      expect(find.text('Palier 3'), findsOneWidget);
      final confirm = find.byKey(const ValueKey<String>('zConfirmLearning'));
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(grades, [3]);
      pending.complete(false);
      await tester.pump();
      await tester.tap(confirm);
      await tester.pump();
      expect(grades, [3, 3]);
      await tester.tap(confirm);
      expect(grades, [3, 3]);
    },
  );

  testWidgets('retour typé personnalisable et reset de carte', (tester) async {
    final qualities = <int>[];
    ZFlashcardAnswerInput input(ZFlashcard card) => ZFlashcardAnswerInput(
      card: card,
      mode: ZReviewMode.learn,
      advanceBehavior: ZCardAdvanceBehavior.confirm,
      onAdvanceWithQuality: qualities.add,
      feedbackBuilder: (_, feedback) => Text('Retour ${feedback.quality}'),
    );
    await tester.pumpWidget(host(input(trueFalseCard())));
    await tester.tap(find.byKey(K.answerTrue));
    await tester.pump();
    expect(find.textContaining('Retour'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('zConfirmLearning')));
    await tester.pump();
    expect(qualities, hasLength(1));
    await tester.pumpWidget(host(input(trueFalseCard().copyWith(id: 'new'))));
    expect(
      find.byKey(const ValueKey<String>('zConfirmLearning')),
      findsNothing,
    );
    await tester.tap(find.byKey(K.answerTrue));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('zConfirmLearning')));
    expect(qualities, hasLength(2));
  });
}
