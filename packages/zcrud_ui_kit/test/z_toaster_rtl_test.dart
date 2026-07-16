import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _rtlHarness() {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => const ZScaffoldMessengerToaster().show(
              context,
              message: 'message rtl',
              severity: ZToastSeverity.error,
              actionLabel: 'ACTION',
              onAction: () {},
            ),
            child: const Text('GO'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('SnackBar rendue sous Directionality.rtl sans exception',
      (tester) async {
    await tester.pumpWidget(_rtlHarness());
    await tester.tap(find.text('GO'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Semantics du message présent (a11y AD-13)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_rtlHarness());
    await tester.tap(find.text('GO'));
    await tester.pump();

    expect(find.bySemanticsLabel('message rtl'), findsOneWidget);
    handle.dispose();
  });
}
