import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'home_screen.dart';
import 'support/demo_file_picker.dart';

/// Design-tokens injectés (FR-26/AD-6) : on ne fixe QUE des espacements ; les
/// couleurs restent `null` → repli `Theme.of` (aucun style/couleur codé en dur).
const ZcrudTheme _demoZcrudTheme = ZcrudTheme(gapM: 10, gapL: 20);

/// Coquille de l'application exemple (EX-1, AC1/AC3). `MaterialApp` +
/// `ZcrudScope` racine (thème `ZcrudTheme` de démo, `ZFilePicker` de démo),
/// l10n zcrud (fr/en) câblée, et bascules thème / langue / sens (RTL — AD-13).
class ExampleApp extends StatefulWidget {
  /// Construit l'application exemple.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Locale _locale = const Locale('fr');
  bool _rtl = false;
  bool _dark = false;

  void _toggleLocale() => setState(
        () => _locale = _locale.languageCode == 'fr'
            ? const Locale('en')
            : const Locale('fr'),
      );

  void _toggleRtl() => setState(() => _rtl = !_rtl);

  void _toggleDark() => setState(() => _dark = !_dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zcrud example',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // l10n zcrud (fr/en) + délégués Material/Widgets/Cupertino (AC3).
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
      // `ZcrudScope` racine : injection thème/filePicker sous le contexte Material.
      // Bascule RTL via un `Directionality` directionnel explicite (AD-13).
      builder: (context, child) {
        final scoped = ZcrudScope(
          theme: _demoZcrudTheme,
          filePicker: const DemoFilePicker(),
          child: child ?? const SizedBox.shrink(),
        );
        return _rtl
            ? Directionality(textDirection: TextDirection.rtl, child: scoped)
            : scoped;
      },
      home: HomeScreen(
        locale: _locale,
        rtl: _rtl,
        dark: _dark,
        onToggleLocale: _toggleLocale,
        onToggleRtl: _toggleRtl,
        onToggleDark: _toggleDark,
      ),
    );
  }
}
