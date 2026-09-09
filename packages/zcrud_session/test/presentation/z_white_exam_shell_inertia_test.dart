/// Inertie de la coquille « une question à la fois ».
///
/// La surface en liste, l'état par index et les libellés supplémentaires sont
/// **additifs** : une application qui n'en utilise aucun doit obtenir
/// exactement l'arbre qu'elle obtenait auparavant. Cette garde gèle cet arbre,
/// phase par phase, et rougit sur le moindre nœud ajouté, retiré ou déplacé.
///
/// L'arbre est élagué aux feuilles `TextButton`/`Text` : au-delà commencent
/// les entrailles de Material, dont les clés globales changent à chaque run —
/// un gel qui les inclurait serait instable, donc inutilisable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Arbre gelé, mesuré sur la coquille **avant** l'ajout de la surface en
/// liste.
const String _frozenSetup = '''
ZWhiteExamSessionView
  Column
    _TimerRegion
      ValueListenableBuilder<Duration>
        Semantics [zWhiteExamTimer]
          Text
    ValueListenableBuilder<ZWhiteExamSessionViewState>
      _ExamStateRegion
        _Navigation
          Semantics [zWhiteExamNavigation]
            Align [zWhiteExamNavigationAlignment]
              _ActionButton [zWhiteExamStart]
                ConstrainedBox
                  TextButton
''';

const String _frozenRunning = '''
ZWhiteExamSessionView
  Column
    _TimerRegion
      ValueListenableBuilder<Duration>
        Semantics [zWhiteExamTimer]
          Text
    ValueListenableBuilder<ZWhiteExamSessionViewState>
      _ExamStateRegion
        Column
          Semantics [zWhiteExamQuestion]
            Column
              Text
              TextButton [answer]
          _Navigation
            Semantics [zWhiteExamNavigation]
              Align [zWhiteExamNavigationAlignment]
                _ActionButton [zWhiteExamSubmit]
                  ConstrainedBox
                    TextButton
''';

const String _frozenSubmitted = '''
ZWhiteExamSessionView
  Column
    _TimerRegion
      ValueListenableBuilder<Duration>
        Semantics [zWhiteExamTimer]
          Text
    ValueListenableBuilder<ZWhiteExamSessionViewState>
      _ExamStateRegion
        Column
          Text
          Text
''';

void main() {
  testWidgets('la coquille rend l\'arbre gelé, phase par phase', (
    tester,
  ) async {
    final timer = ValueNotifier<Duration>(const Duration(seconds: 5));
    final engine = ZWhiteExamSessionEngine(
      queue: const <ZSessionItem>[
        ZSessionItem(flashcardId: 'id', folderId: 'folder'),
      ],
    );
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(_dump(tester), _frozenSetup);

    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    expect(_dump(tester), _frozenRunning);

    await tester.tap(find.byKey(const ValueKey<String>('answer')));
    await tester.pump();
    await tester.tap(find.byKey(ZWhiteExamSessionView.submitKey));
    await tester.pump();
    expect(_dump(tester), _frozenSubmitted);
  });

  testWidgets('le minuteur à rebours garde son rendu au chiffre près', (
    tester,
  ) async {
    final timer = ValueNotifier<Duration>(const Duration(minutes: 2));
    final engine = ZWhiteExamSessionEngine(
      queue: const <ZSessionItem>[
        ZSessionItem(flashcardId: 'id', folderId: 'folder'),
      ],
    );
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(find.text('02:00'), findsOneWidget);

    timer.value = const Duration(minutes: 1, seconds: 59);
    await tester.pump();
    expect(find.text('01:59'), findsOneWidget);
  });

  testWidgets('l\'état par index reste vide sous la coquille', (tester) async {
    final timer = ValueNotifier<Duration>(Duration.zero);
    final engine = ZWhiteExamSessionEngine(
      queue: const <ZSessionItem>[
        ZSessionItem(flashcardId: 'id', folderId: 'folder'),
      ],
    );
    final controller = ZWhiteExamSessionController(engine: engine);
    addTearDown(() {
      timer.dispose();
      controller.dispose();
      engine.dispose();
    });

    await tester.pumpWidget(_app(controller: controller, timer: timer));
    expect(controller.state.value.answers, isEmpty);
    expect(controller.state.value.marked, isEmpty);

    await tester.tap(find.byKey(ZWhiteExamSessionView.startKey));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('answer')));
    await tester.pump();

    // La coquille répond sous le curseur : l'état par index la suit, et le
    // compteur de réponses reste celui qu'elle a toujours publié.
    expect(controller.state.value.answered, 1);
    expect(controller.state.value.answeredCount, 1);
    expect(controller.state.value.marked, isEmpty);
  });
}

/// Arbre élagué : type de widget, et clé de valeur quand il y en a une.
String _dump(WidgetTester tester) {
  const leaves = <String>{'TextButton', 'Text'};
  final buffer = StringBuffer();
  void walk(Element element, int depth) {
    final widget = element.widget;
    final key = widget.key;
    final type = widget.runtimeType.toString();
    buffer.writeln(
      '${'  ' * depth}$type'
      '${key is ValueKey<String> ? ' [${key.value}]' : ''}',
    );
    if (leaves.contains(type)) return;
    element.visitChildren((child) => walk(child, depth + 1));
  }

  walk(tester.element(find.byType(ZWhiteExamSessionView)), 0);
  return buffer.toString();
}

Widget _app({
  required ZWhiteExamSessionController controller,
  required ValueNotifier<Duration> timer,
}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(
      body: ZWhiteExamSessionView(
        controller: controller,
        remaining: timer,
        labels: _labels,
        questionBuilder: (context, question) => Column(
          children: <Widget>[
            const Text('Question hôte'),
            TextButton(
              key: const ValueKey<String>('answer'),
              onPressed: () => question.onAnswer(5),
              child: const Text('Réponse hôte'),
            ),
          ],
        ),
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
