@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import '../support/z_sources.dart';

void main() {
  testWidgets('le tic du minuteur ne reconstruit que son widget', (
    tester,
  ) async {
    final timer = ValueNotifier<Duration>(const Duration(minutes: 2));
    final engine = _engine();
    engine.start();
    final controller = ZWhiteExamSessionController(engine: engine);
    var questionBuilds = 0;
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(
      _app(
        controller: controller,
        timer: timer,
        onQuestionBuild: () => questionBuilds += 1,
      ),
    );
    final initialQuestionBuilds = questionBuilds;

    timer.value = const Duration(minutes: 1, seconds: 59);
    await tester.pump();

    expect(questionBuilds, initialQuestionBuilds);
    expect(find.text('01:59'), findsOneWidget);
  });

  testWidgets('le contrôleur fourni reste la même instance au rebuild parent', (
    tester,
  ) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    final parent = GlobalKey<_RebuildingHostState>();
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(
      _RebuildingHost(key: parent, controller: controller, timer: timer),
    );
    parent.currentState!.rebuild();
    await tester.pump();

    expect(parent.currentState!.controllerSeen, same(controller));
  });

  testWidgets('les libellés et les slots injectés sont rendus', (tester) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(find.text('Démarrage hôte'), findsOneWidget);
    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    expect(find.text('Question hôte'), findsOneWidget);
    expect(find.text('Soumission hôte'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('answer')));
    await tester.pump();
    await tester.tap(find.byKey(ZWhiteExamSessionView.submitKey));
    await tester.pump();
    expect(find.text('Correction hôte'), findsOneWidget);
    expect(find.text('Résultat hôte'), findsOneWidget);
  });

  testWidgets('navigation, correction et résultat suivent le moteur', (
    tester,
  ) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(engine.phase, ZWhiteExamPhase.setup);
    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    expect(engine.phase, ZWhiteExamPhase.running);
    await tester.tap(find.byKey(const ValueKey<String>('answer')));
    await tester.pump();
    await tester.tap(find.byKey(ZWhiteExamSessionView.submitKey));
    await tester.pump();

    expect(engine.phase, ZWhiteExamPhase.submitted);
    expect(engine.result, isNotNull);
    expect(find.byKey(ZWhiteExamSessionView.submitKey), findsNothing);
    expect(find.text('Résultat hôte'), findsOneWidget);
  });

  testWidgets('les régions clés ont des semantics explicites', (tester) async {
    final handle = tester.ensureSemantics();
    final timer = ValueNotifier<Duration>(const Duration(seconds: 5));
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(
      tester.getSemantics(find.byKey(ZWhiteExamSessionView.timerKey)).label,
      contains('Temps hôte'),
    );
    expect(
      tester
          .getSemantics(find.byKey(ZWhiteExamSessionView.navigationKey))
          .label,
      contains('Navigation hôte'),
    );
    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(ZWhiteExamSessionView.questionKey)).label,
      contains('Question hôte'),
    );
    handle.dispose();
  });

  testWidgets('les actions ont des cibles tactiles de 48 dp', (tester) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(
      tester.getSize(find.byKey(ZWhiteExamSessionView.startKey)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(ZWhiteExamSessionView.submitKey)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('la navigation reste directionnelle en RTL', (tester) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = _engine();
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(
      _app(
        controller: controller,
        timer: timer,
        textDirection: TextDirection.rtl,
      ),
    );
    final align = tester.widget<Align>(
      find.byKey(ZWhiteExamSessionView.navigationAlignmentKey),
    );
    expect(align.alignment, AlignmentDirectional.centerEnd);
  });

  test('le widget ne contient ni texte visible ni couleur littérale', () {
    // P0b : scan sur la source DÉ-COMMENTÉE — cette garde n'appliquait
    // AUCUN strip, alors que les motifs bannis ici (`EdgeInsets.only(left:`,
    // `Colors.`…) sont EXACTEMENT ceux qu'une dartdoc légitime cite pour
    // expliquer la règle RTL (cf. CLAUDE.md lui-même). Sans strip, un simple
    // paragraphe de doc suffisait à faire rougir la garde à tort.
    final source = strippedSource(
      File('lib/src/presentation/z_white_exam_session_view.dart'),
    );
    expect(RegExp(r'''Text\s*\(\s*['"]''').hasMatch(source), isFalse);
    expect(source.contains('Colors.'), isFalse);
    expect(source.contains('Color(0x'), isFalse);
    expect(source.contains('EdgeInsets.only(left:'), isFalse);
    expect(source.contains('EdgeInsets.only(right:'), isFalse);
    expect(source.contains('minWidth: 48, minHeight: 48'), isTrue);
  });
}

ZWhiteExamSessionEngine _engine() => ZWhiteExamSessionEngine(
  queue: const <ZSessionItem>[
    ZSessionItem(flashcardId: 'id', folderId: 'folder'),
  ],
);

Widget _app({
  required ZWhiteExamSessionController controller,
  required ValueNotifier<Duration> timer,
  VoidCallback? onQuestionBuild,
  TextDirection textDirection = TextDirection.ltr,
}) => MaterialApp(
  home: Directionality(
    textDirection: textDirection,
    child: Scaffold(
      body: ZWhiteExamSessionView(
        controller: controller,
        remaining: timer,
        labels: _labels,
        questionBuilder: (context, question) {
          onQuestionBuild?.call();
          return Column(
            children: <Widget>[
              const Text('Question hôte'),
              TextButton(
                key: const ValueKey<String>('answer'),
                onPressed: () => question.onAnswer(5),
                child: const Text('Réponse hôte'),
              ),
            ],
          );
        },
        correctionBuilder: (context, state) => const Text('Correction hôte'),
        resultBuilder: (context, state) => const Text('Résultat hôte'),
      ),
    ),
  ),
);

const ZWhiteExamSessionLabels _labels = ZWhiteExamSessionLabels(
  startAction: _startLabel,
  submitAction: _submitLabel,
  timerSemanticsLabel: _timerLabel,
  questionSemanticsLabel: _questionLabel,
  navigationSemanticsLabel: _navigationLabel,
);

Widget _startLabel(BuildContext context) => const Text('Démarrage hôte');
Widget _submitLabel(BuildContext context) => const Text('Soumission hôte');
String _timerLabel(Duration value) => 'Temps hôte';
String _questionLabel(ZWhiteExamSessionViewState state) => 'Question hôte';
String _navigationLabel(ZWhiteExamSessionViewState state) => 'Navigation hôte';

class _RebuildingHost extends StatefulWidget {
  const _RebuildingHost({
    required this.controller,
    required this.timer,
    super.key,
  });

  final ZWhiteExamSessionController controller;
  final ValueNotifier<Duration> timer;

  @override
  State<_RebuildingHost> createState() => _RebuildingHostState();
}

class _RebuildingHostState extends State<_RebuildingHost> {
  ZWhiteExamSessionController? controllerSeen;

  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    controllerSeen = widget.controller;
    return _app(controller: widget.controller, timer: widget.timer);
  }
}
