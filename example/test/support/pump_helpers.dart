import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/support/demo_file_picker.dart';

/// Enveloppe [child] dans un `MaterialApp` + `ZcrudScope` racine (thème/l10n/
/// filePicker de démo) reproduisant la coquille de l'app pour les tests unités.
Widget wrapForTest(Widget child) {
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      ZcrudLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
    home: ZcrudScope(
      filePicker: const DemoFilePicker(),
      child: Scaffold(body: child),
    ),
  );
}

/// Comme [wrapForTest] mais injecte AUSSI un `widgetRegistry` au `ZcrudScope`
/// racine (EX-3) — nécessaire pour que les champs géo/intl servis par le registre
/// se résolvent (sinon `ZUnsupportedFieldWidget`). Reproduit le point d'injection
/// racine de `app.dart`.
Widget wrapForTestWithRegistry(
  Widget child, {
  required ZWidgetRegistry registry,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      ZcrudLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
    builder: (context, home) => Directionality(
      textDirection: textDirection,
      child: ZcrudScope(
        filePicker: const DemoFilePicker(),
        widgetRegistry: registry,
        child: home ?? const SizedBox.shrink(),
      ),
    ),
    home: Scaffold(body: child),
  );
}

/// Étire la fenêtre de test pour maximiser le nombre de champs construits par le
/// `ListView.builder` de `DynamicEdition`. Restaure automatiquement en teardown.
void useTallSurface(WidgetTester tester, {double height = 6000}) {
  tester.view.physicalSize = Size(1200 * tester.view.devicePixelRatio,
      height * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
