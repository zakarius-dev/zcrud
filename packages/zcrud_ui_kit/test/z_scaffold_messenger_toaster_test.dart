import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Monte un bouton qui déclenche `ZScaffoldMessengerToaster.show(...)`.
Widget _harness({
  required ZToastSeverity severity,
  required ThemeData theme,
  String message = 'msg',
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => const ZScaffoldMessengerToaster()
              .show(context, message: message, severity: severity),
          child: const Text('GO'),
        ),
      ),
    ),
  );
}

/// Couleur de fond attendue pour une sévérité (dérivée du `ColorScheme`).
Color _expectedBackground(ZToastSeverity severity, ColorScheme scheme) {
  switch (severity) {
    case ZToastSeverity.info:
      return scheme.primary;
    case ZToastSeverity.success:
      return scheme.tertiary;
    case ZToastSeverity.warning:
      return scheme.secondary;
    case ZToastSeverity.error:
      return scheme.error;
  }
}

/// Icône attendue pour une sévérité (canal non-couleur).
IconData _expectedIcon(ZToastSeverity severity) {
  switch (severity) {
    case ZToastSeverity.info:
      return Icons.info_outline;
    case ZToastSeverity.success:
      return Icons.check_circle_outline;
    case ZToastSeverity.warning:
      return Icons.warning_amber_outlined;
    case ZToastSeverity.error:
      return Icons.error_outline;
  }
}

void main() {
  for (final theme in <(String, ThemeData)>[
    ('light', ThemeData.light()),
    ('dark', ThemeData.dark()),
  ]) {
    final label = theme.$1;
    final data = theme.$2;
    for (final severity in ZToastSeverity.values) {
      testWidgets(
        '[$label] $severity → SnackBar colorée par le bon rôle ColorScheme',
        (tester) async {
          await tester.pumpWidget(
            _harness(severity: severity, theme: data),
          );
          await tester.tap(find.text('GO'));
          await tester.pump(); // insère la SnackBar

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(
            snackBar.backgroundColor,
            _expectedBackground(severity, data.colorScheme),
            reason: 'couleur dérivée du ColorScheme, jamais un hex',
          );

          // Couleur JAMAIS seul canal : icône de sévérité + texte présents.
          expect(find.byIcon(_expectedIcon(severity)), findsOneWidget);
          expect(find.text('msg'), findsOneWidget);
        },
      );
    }
  }

  testWidgets(
      'error → override ZcrudTheme.errorColor prioritaire sur scheme.error '
      '(branche porteuse, code-review M1)', (tester) async {
    const customError = Color(0xFFAB1234);
    final themed = ThemeData.light().copyWith(
      extensions: const <ThemeExtension<dynamic>>[
        ZcrudTheme(errorColor: customError),
      ],
    );
    await tester.pumpWidget(
      _harness(severity: ZToastSeverity.error, theme: themed),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    // Le fond DOIT être l'`errorColor` injecté (idiome `ZcrudTheme.of(context)
    // .errorColor ?? scheme.error`). Sans le préfixe d'override du code de prod,
    // ce test rougirait → branche d'override désormais PORTEUSE.
    expect(snackBar.backgroundColor, customError);
    expect(snackBar.backgroundColor, isNot(themed.colorScheme.error));
  });
}
