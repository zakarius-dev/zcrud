import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _harness({
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => const ZScaffoldMessengerToaster().show(
            context,
            message: 'msg',
            severity: ZToastSeverity.success,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          child: const Text('GO'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('actionLabel + onAction → SnackBarAction présent, tap déclenche',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _harness(actionLabel: 'ANNULER', onAction: () => tapped++),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBarAction), findsOneWidget);
    expect(find.text('ANNULER'), findsOneWidget);

    await tester.tap(find.text('ANNULER'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('cible tactile de l\'action ≥ 48 dp (tap target Material)',
      (tester) async {
    await tester.pumpWidget(
      _harness(actionLabel: 'ANNULER', onAction: () {}),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();

    // Le tap target Material (materialTapTargetSize.padded par défaut) garantit
    // une hauteur de hit-test ≥ 48 dp autour du bouton de l'action.
    final actionButton = find.descendant(
      of: find.byType(SnackBarAction),
      matching: find.byType(TextButton),
    );
    expect(actionButton, findsOneWidget);
    final size = tester.getSize(actionButton);
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('sans actionLabel/onAction → aucune SnackBarAction (repli sûr)',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('GO'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
  });
}
