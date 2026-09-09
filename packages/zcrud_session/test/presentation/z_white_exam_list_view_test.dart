/// Surface d'examen blanc en liste : `ZWhiteExamListView`.
///
/// Les gardes visent les points où un examen se fausse : une note attribuée à
/// la mauvaise question, une copie soumise sans que le candidat sache ce
/// qu'il rend, une liste qui retombe entièrement à chaque frappe.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import '../support/z_sources.dart';

/// Hôte de référence : il détient le moteur et le contrôleur, comme une
/// application le ferait.
class _ExamHost extends StatefulWidget {
  const _ExamHost({
    required this.count,
    this.policy = const ZWhiteExamSubmitPolicy(),
    this.labels = const ZWhiteExamSessionLabels(),
    this.onQuestionBuild,
    this.textDirection = TextDirection.ltr,
    this.resultBuilder,
  });

  final int count;
  final ZWhiteExamSubmitPolicy policy;
  final ZWhiteExamSessionLabels labels;
  final void Function(int index)? onQuestionBuild;
  final TextDirection textDirection;
  final ZWhiteExamResultBuilder? resultBuilder;

  @override
  State<_ExamHost> createState() => _ExamHostState();
}

class _ExamHostState extends State<_ExamHost> {
  late final ZWhiteExamSessionEngine engine = ZWhiteExamSessionEngine(
    queue: <ZSessionItem>[
      for (var i = 0; i < widget.count; i++)
        ZSessionItem(flashcardId: 'q$i', folderId: 'f'),
    ],
    startImmediately: true,
  );
  late final ZWhiteExamSessionController controller =
      ZWhiteExamSessionController(engine: engine);

  int submitted = 0;

  @override
  void dispose() {
    controller.dispose();
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Directionality(
      textDirection: widget.textDirection,
      child: Scaffold(
        body: ZWhiteExamListView(
          controller: controller,
          labels: widget.labels,
          submitPolicy: widget.policy,
          resultBuilder: widget.resultBuilder,
          onSubmitted: () => submitted += 1,
          questionBuilder: (context, question) {
            widget.onQuestionBuild?.call(question.index);
            return SizedBox(
              height: 16,
              child: TextButton(
                key: ValueKey<String>('answer_${question.index}'),
                onPressed: () => question.onAnswer(5),
                child: const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    ),
  );
}

_ExamHostState _host(WidgetTester tester) =>
    tester.state<_ExamHostState>(find.byType(_ExamHost));

Key _questionKey(int i) =>
    ValueKey<String>('${ZWhiteExamListView.questionKeyPrefix}$i');
Key _dontKnowKey(int i) =>
    ValueKey<String>('${ZWhiteExamListView.dontKnowKeyPrefix}$i');
Key _markKey(int i) => ValueKey<String>('${ZWhiteExamListView.markKeyPrefix}$i');

void main() {
  testWidgets('toutes les questions sont posées à la fois', (tester) async {
    await tester.pumpWidget(const _ExamHost(count: 4));

    for (var i = 0; i < 4; i++) {
      expect(find.byKey(_questionKey(i)), findsOneWidget, reason: 'question $i');
    }
    expect(find.byKey(ZWhiteExamListView.listKey), findsOneWidget);
  });

  testWidgets('la liste est virtualisée, jamais construite d\'un bloc', (
    tester,
  ) async {
    await tester.pumpWidget(const _ExamHost(count: 200));

    expect(find.byKey(_questionKey(0)), findsOneWidget);
    expect(
      find.byKey(_questionKey(199)),
      findsNothing,
      reason: 'une question hors écran ne doit pas être construite',
    );
  });

  testWidgets('répondre à une question ne reconstruit QUE celle-là', (
    tester,
  ) async {
    final builds = <int, int>{};
    await tester.pumpWidget(
      _ExamHost(
        count: 4,
        onQuestionBuild: (index) => builds[index] = (builds[index] ?? 0) + 1,
      ),
    );
    final before = Map<int, int>.of(builds);

    await tester.tap(find.byKey(const ValueKey<String>('answer_1')));
    await tester.pump();

    expect(builds[1], before[1]! + 1, reason: 'la question répondue');
    expect(builds[0], before[0], reason: 'sa voisine ne bouge pas');
    expect(builds[2], before[2]);
    expect(builds[3], before[3]);
  });

  testWidgets('marquer une question ne reconstruit QUE celle-là', (
    tester,
  ) async {
    final builds = <int, int>{};
    await tester.pumpWidget(
      _ExamHost(
        count: 4,
        onQuestionBuild: (index) => builds[index] = (builds[index] ?? 0) + 1,
      ),
    );
    final before = Map<int, int>.of(builds);

    await tester.tap(find.byKey(_markKey(2)));
    await tester.pump();

    expect(builds[2], before[2]! + 1);
    expect(builds[0], before[0]);
    expect(builds[1], before[1]);
    expect(builds[3], before[3]);
  });

  testWidgets('la note part sous SA question, jamais sous une autre', (
    tester,
  ) async {
    await tester.pumpWidget(const _ExamHost(count: 4));

    await tester.tap(find.byKey(const ValueKey<String>('answer_2')));
    await tester.pump();

    final engine = _host(tester).engine;
    expect(engine.state.answerFor(2).quality, 5);
    expect(engine.state.answerFor(0).isAnswered, isFalse);
    expect(engine.answeredCount, 1);
    expect(engine.unansweredCount, 3);
  });

  testWidgets('« je ne sais pas » compte répondue et fausse', (tester) async {
    await tester.pumpWidget(const _ExamHost(count: 3));

    await tester.tap(find.byKey(_dontKnowKey(1)));
    await tester.pump();

    final engine = _host(tester).engine;
    expect(engine.state.answerFor(1).kind, ZExamAnswerKind.dontKnow);
    expect(engine.answeredCount, 1);

    engine.submit();
    expect(engine.result?.total, 1);
    expect(engine.result?.correct, 0);
  });

  testWidgets('le drapeau bascule sans toucher à la réponse', (tester) async {
    await tester.pumpWidget(const _ExamHost(count: 3));

    await tester.tap(find.byKey(const ValueKey<String>('answer_0')));
    await tester.pump();
    await tester.tap(find.byKey(_markKey(0)));
    await tester.pump();

    final engine = _host(tester).engine;
    expect(engine.marked, <int>{0});
    expect(engine.state.answerFor(0).quality, 5);

    await tester.tap(find.byKey(_markKey(0)));
    await tester.pump();
    expect(engine.marked, isEmpty);
    expect(engine.state.answerFor(0).quality, 5);
  });

  group('soumission', () {
    testWidgets('le dialogue porte le compte EXACT de questions blanches', (
      tester,
    ) async {
      await tester.pumpWidget(const _ExamHost(count: 5));
      await tester.tap(find.byKey(const ValueKey<String>('answer_0')));
      await tester.pump();

      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(ZWhiteExamListView.dialogUnansweredTextKey),
            )
            .data,
        '4',
      );
    });

    testWidgets('annuler ne soumet rien', (tester) async {
      await tester.pumpWidget(const _ExamHost(count: 3));
      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZWhiteExamListView.cancelKey));
      await tester.pumpAndSettle();

      final host = _host(tester);
      expect(host.engine.phase, ZWhiteExamPhase.running);
      expect(host.engine.result, isNull);
      expect(host.submitted, 0);
      expect(find.byKey(ZWhiteExamListView.submitKey), findsOneWidget);
    });

    testWidgets('confirmer soumet, et les blanches comptent fausses', (
      tester,
    ) async {
      await tester.pumpWidget(const _ExamHost(count: 4));
      await tester.tap(find.byKey(const ValueKey<String>('answer_0')));
      await tester.pump();
      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZWhiteExamListView.confirmKey));
      await tester.pumpAndSettle();

      final host = _host(tester);
      expect(host.engine.phase, ZWhiteExamPhase.submitted);
      expect(host.engine.result?.total, 4, reason: 'notée sur toute l\'épreuve');
      expect(host.engine.result?.correct, 1);
      expect(host.submitted, 1);
      expect(
        find.byKey(ZWhiteExamListView.submitKey),
        findsNothing,
        reason: 'plus aucune affordance : la double soumission est impossible',
      );
    });

    testWidgets('une copie complète ne demande aucune confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(const _ExamHost(count: 2));
      await tester.tap(find.byKey(const ValueKey<String>('answer_0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('answer_1')));
      await tester.pump();

      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ZWhiteExamListView.confirmKey), findsNothing);
      expect(_host(tester).engine.phase, ZWhiteExamPhase.submitted);
    });

    testWidgets('une politique sans confirmation soumet au premier geste', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _ExamHost(
          count: 3,
          policy: ZWhiteExamSubmitPolicy.immediate(),
        ),
      );

      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ZWhiteExamListView.confirmKey), findsNothing);
      expect(_host(tester).engine.phase, ZWhiteExamPhase.submitted);
      expect(_host(tester).engine.result?.total, 3);
    });

    testWidgets('sans le régime, une blanche ne pèse sur rien', (tester) async {
      await tester.pumpWidget(
        const _ExamHost(
          count: 3,
          policy: ZWhiteExamSubmitPolicy.immediate(
            countUnansweredAsIncorrect: false,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('answer_0')));
      await tester.pump();
      await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
      await tester.pumpAndSettle();

      expect(_host(tester).engine.result?.total, 1);
    });

    testWidgets('le compte de blanches est visible ET annoncé', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const _ExamHost(count: 3));
      await tester.tap(find.byKey(const ValueKey<String>('answer_1')));
      await tester.pump();

      expect(
        tester
            .widget<Text>(find.byKey(ZWhiteExamListView.unansweredTextKey))
            .data,
        '2',
      );
      expect(
        tester
            .getSemantics(find.byKey(ZWhiteExamListView.unansweredKey))
            .value,
        '2',
      );
      handle.dispose();
    });
  });

  testWidgets('un examen sans question n\'offre aucune soumission', (
    tester,
  ) async {
    await tester.pumpWidget(const _ExamHost(count: 0));

    expect(find.byKey(ZWhiteExamListView.emptyKey), findsOneWidget);
    expect(find.byKey(ZWhiteExamListView.submitKey), findsNothing);
  });

  testWidgets('le résultat n\'apparaît qu\'une fois la copie rendue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ExamHost(
        count: 2,
        policy: const ZWhiteExamSubmitPolicy.immediate(),
        resultBuilder: (context, state) =>
            Text('${state.result?.total}', textAlign: TextAlign.start),
      ),
    );

    expect(find.byKey(ZWhiteExamListView.resultKey), findsNothing);

    await tester.tap(find.byKey(ZWhiteExamListView.submitKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ZWhiteExamListView.resultKey), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  group('accessibilité', () {
    testWidgets('chaque question annonce son rang et son état', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const _ExamHost(count: 3));

      expect(tester.getSemantics(find.byKey(_questionKey(1))).value, '2');

      await tester.tap(find.byKey(const ValueKey<String>('answer_1')));
      await tester.pump();
      await tester.tap(find.byKey(_markKey(1)));
      await tester.pump();

      final semantics = tester.getSemantics(find.byKey(_questionKey(1)));
      expect(semantics.value, contains('2'));
      expect(semantics.value, contains('répondue'));
      expect(semantics.value, contains('marquée'));
      handle.dispose();
    });

    testWidgets('l\'annonce d\'une question est remplaçable par l\'hôte', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _ExamHost(
          count: 2,
          labels: ZWhiteExamSessionLabels(
            questionItemSemanticsLabel: (index, answer, marked) =>
                'Item hôte $index',
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(_questionKey(1))).label,
        contains('Item hôte 1'),
      );
      handle.dispose();
    });

    testWidgets('les contrôles ont des cibles tactiles de 48 dp', (
      tester,
    ) async {
      await tester.pumpWidget(const _ExamHost(count: 2));

      expect(
        tester.getSize(find.byKey(_dontKnowKey(0))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(_markKey(0))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(ZWhiteExamListView.submitKey)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('le badge de rang reste directionnel en RTL', (tester) async {
      await tester.pumpWidget(
        const _ExamHost(count: 2, textDirection: TextDirection.rtl),
      );

      final padding = tester
          .widget<Padding>(
            find.byKey(
              ValueKey<String>('${ZWhiteExamListView.badgeKeyPrefix}0'),
            ),
          )
          .padding;
      expect(padding, isA<EdgeInsetsDirectional>());
    });
  });

  test('la surface ne porte ni couleur ni libellé en dur', () {
    final source = strippedSource(
      File('lib/src/presentation/z_white_exam_list_view.dart'),
    );
    // Un `Text('…')` dont le littéral, une fois les interpolations retirées,
    // porte encore une lettre est une chaîne à traduire codée en dur. Une
    // interpolation pure d'un nombre rend un NOMBRE : la bannir
    // serait un faux positif, et une garde qui crie au loup finit désactivée.
    final hardcoded = RegExp(r"""Text\s*\(\s*'([^']*)'""")
        .allMatches(source)
        .map((m) => m.group(1) ?? '')
        .where(
          (literal) => literal
              .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
              .replaceAll(RegExp(r'\$\w+'), '')
              .contains(RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]')),
        )
        .toList();
    expect(hardcoded, isEmpty, reason: 'libellés en dur : $hardcoded');
    expect(source.contains('Colors.'), isFalse);
    expect(source.contains('Color(0x'), isFalse);
    expect(source.contains('EdgeInsets.only(left:'), isFalse);
    expect(source.contains('EdgeInsets.only(right:'), isFalse);
    expect(source.contains('ListView.builder'), isTrue);
    expect(source.contains('minWidth: minTarget'), isTrue);
  });
}
