import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _view(ZContentState state, {Widget? idle, Widget? loading, Widget? empty, Widget? error}) {
  return MaterialApp(
    home: Scaffold(
      body: ZContentStateView(
        state: state,
        idle: idle,
        loading: loading,
        empty: empty,
        error: error,
        successBuilder: (_) => const Text('CONTENU'),
      ),
    ),
  );
}

void main() {
  testWidgets('success → successBuilder', (tester) async {
    await tester.pumpWidget(_view(ZContentState.success));
    expect(find.text('CONTENU'), findsOneWidget);
  });

  testWidgets('aiguille chaque tranche fournie', (tester) async {
    await tester.pumpWidget(_view(
      ZContentState.idle,
      idle: const Text('IDLE'),
    ));
    expect(find.text('IDLE'), findsOneWidget);

    await tester.pumpWidget(_view(
      ZContentState.loading,
      loading: const Text('LOADING'),
    ));
    expect(find.text('LOADING'), findsOneWidget);

    await tester.pumpWidget(_view(
      ZContentState.empty,
      empty: const Text('EMPTY'),
    ));
    expect(find.text('EMPTY'), findsOneWidget);

    await tester.pumpWidget(_view(
      ZContentState.error,
      error: const Text('ERROR'),
    ));
    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('loading absent → repli ZLoadingState', (tester) async {
    await tester.pumpWidget(_view(ZContentState.loading));
    expect(find.byType(ZLoadingState), findsOneWidget);
  });

  testWidgets('idle/empty/error absents → repli SizedBox.shrink (aucun throw)',
      (tester) async {
    for (final state in <ZContentState>[
      ZContentState.idle,
      ZContentState.empty,
      ZContentState.error,
    ]) {
      await tester.pumpWidget(_view(state));
      expect(find.text('CONTENU'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
