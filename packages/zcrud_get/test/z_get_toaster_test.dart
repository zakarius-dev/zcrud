// EX-UI.11 AC2 — `ZGetToaster implements ZToaster` mappe les 4 `ZToastSeverity`
// sur `Get.snackbar` : `backgroundColor` = rôle `ColorScheme` attendu (JAMAIS un
// hex), icône dédiée + texte (couleur jamais seul canal), action SSI
// actionLabel+onAction. Harnais D8 : `Get.testMode` + `GetMaterialApp` + Builder.
//
// Harnais GetSnackBar : l'animation de `Get.snackbar` s'appuie sur un
// `AnimationController` piloté par l'overlay `GetMaterialApp`. Pour l'exercer
// sans fuite de ticker (dispose de l'overlay avec un ticker actif) ni assertion
// `elapsedInSeconds >= 0.0`, on (1) pompe une frame nue AVANT la frame temporisée
// (démarre l'animation à t=0), puis (2) referme le snackbar et `pumpAndSettle`
// en fin de test (dispose propre du ticker).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Thème de test à `ColorScheme` déterministe (rôles distincts) pour comparer le
/// `backgroundColor` du snackbar à un RÔLE, jamais à un littéral hex.
final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

/// Monte le harnais : capture un `BuildContext` sous le thème et déclenche
/// `toaster.show(...)`. [capture] permet au test de lire la couleur/icône
/// attendues à partir du MÊME contexte (rôle `ColorScheme`, jamais hex).
Widget _harness({
  required ZToastSeverity severity,
  String? actionLabel,
  VoidCallback? onAction,
  void Function(BuildContext context)? capture,
}) {
  const toaster = ZGetToaster();
  return GetMaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              capture?.call(context);
              toaster.show(
                context,
                message: 'coucou',
                severity: severity,
                actionLabel: actionLabel,
                onAction: onAction,
              );
            },
            child: const Text('toast'),
          ),
        ),
      ),
    ),
  );
}

/// Déclenche le toast et laisse l'animation d'entrée se dérouler à t=0 (frame
/// nue) puis se terminer (frame temporisée) — évite l'assertion `elapsedInSeconds`.
Future<void> _pumpToast(WidgetTester tester) async {
  await tester.tap(find.text('toast'));
  await tester.pump(); // planifie l'overlay + démarre l'animation à t=0
  await tester.pump(); // 1re frame animée
  await tester.pump(const Duration(milliseconds: 500)); // fin d'animation d'entrée
}

/// Referme le snackbar et draine son animation de sortie (dispose du ticker).
Future<void> _dismiss(WidgetTester tester) async {
  Get.closeAllSnackbars();
  await tester.pumpAndSettle();
}

GetSnackBar _snack(WidgetTester tester) =>
    tester.widget<GetSnackBar>(find.byType(GetSnackBar));

void main() {
  setUp(() => Get.testMode = true);

  final cases = <(ZToastSeverity, Color Function(ColorScheme), IconData)>[
    (ZToastSeverity.info, (s) => s.primary, Icons.info_outline),
    (ZToastSeverity.success, (s) => s.tertiary, Icons.check_circle_outline),
    (ZToastSeverity.warning, (s) => s.secondary, Icons.warning_amber_outlined),
  ];

  for (final (severity, roleOf, icon) in cases) {
    testWidgets('sévérité $severity → couleur de rôle + icône + texte (AC2)',
        (tester) async {
      await tester.pumpWidget(_harness(severity: severity));
      await _pumpToast(tester);

      expect(Get.isSnackbarOpen, isTrue);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text('coucou'), findsWidgets);
      // Couleur dérivée du rôle `ColorScheme` — JAMAIS un hex codé en dur.
      expect(_snack(tester).backgroundColor, roleOf(_scheme));

      await _dismiss(tester);
    });
  }

  testWidgets('sévérité error → errorColor??scheme.error + error_outline (AC2)',
      (tester) async {
    Color? expectedBg;
    await tester.pumpWidget(
      _harness(
        severity: ZToastSeverity.error,
        capture: (context) {
          final scheme = Theme.of(context).colorScheme;
          expectedBg = ZcrudTheme.of(context).errorColor ?? scheme.error;
        },
      ),
    );
    await _pumpToast(tester);

    expect(Get.isSnackbarOpen, isTrue);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(_snack(tester).backgroundColor, expectedBg);

    await _dismiss(tester);
  });

  testWidgets('action affichée SSI actionLabel+onAction, tap → callback (AC2)',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _harness(
        severity: ZToastSeverity.info,
        actionLabel: 'ANNULER',
        onAction: () => tapped = true,
      ),
    );
    await _pumpToast(tester);

    expect(find.text('ANNULER'), findsOneWidget);
    await tester.tap(find.text('ANNULER'));
    await tester.pump();
    expect(tapped, isTrue);

    await _dismiss(tester);
  });

  testWidgets('sans action → aucun mainButton (AC2)', (tester) async {
    await tester.pumpWidget(_harness(severity: ZToastSeverity.info));
    await _pumpToast(tester);

    expect(_snack(tester).mainButton, isNull);

    await _dismiss(tester);
  });
}
