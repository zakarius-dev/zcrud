import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/binding/binding_selector.dart';
import 'package:zcrud_example/demos/edition_demo_screen.dart';
import 'package:zcrud_example/support/demo_file_picker.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';

Widget _host(DemoBinding binding, RebuildLog log) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
      home: ZcrudScope(
        filePicker: const DemoFilePicker(),
        child: EditionDemoScreen(initialBinding: binding, rebuildLog: log),
      ),
    );

void main() {
  // AC7 : le MÊME formulaire se comporte à l'identique sous chaque wrap. On
  // couvre les 4 mécanismes (défaut + 3 bindings) ; le minimum requis est ≥ 2.
  for (final binding in DemoBinding.values) {
    testWidgets('AC7 — parité de rendu + granularité sous ${binding.label}',
        (tester) async {
      tester.view.physicalSize = Size(
          1200 * tester.view.devicePixelRatio, 6000 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final log = RebuildLog();
      await tester.pumpWidget(_host(binding, log));
      await tester.pumpAndSettle();

      // Mêmes familles rendues, aucun champ non supporté, aucun Form global.
      expect(find.byType(EditionDemoScreen), findsOneWidget);
      expect(find.byType(ZTextFieldWidget), findsWidgets);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(find.byType(Form), findsNothing);

      // Rebuild granulaire identique : taper dans fullName n'affecte pas nickname.
      final fullNameField = find.descendant(
        of: find.byKey(const ValueKey<String>('fullName')),
        matching: find.byType(EditableText),
      );
      expect(fullNameField, findsOneWidget);
      final baseNick = log.countOf('nickname');
      final baseFull = log.countOf('fullName');

      await tester.enterText(fullNameField, 'abcde');
      await tester.pump();

      expect(log.countOf('fullName'), greaterThan(baseFull));
      expect(log.countOf('nickname'), baseNick,
          reason: 'Granularité SM-1 non préservée sous ${binding.label}');
      expect(tester.takeException(), isNull);
    });
  }

  // MEDIUM-1 (code-review EX-1) : le scope racine (filePicker/thème/l10n) doit
  // rester résolu SOUS chaque binding (sinon familles file/image/document
  // inertes). On sonde `ZcrudScope.of(context).filePicker` à l'intérieur du
  // sous-arbre enveloppé par `wrapWithBinding`, pour les 4 voies.
  for (final binding in DemoBinding.values) {
    testWidgets('MEDIUM-1 — filePicker racine résolu sous ${binding.label}',
        (tester) async {
      ZFilePicker? seen;
      const picker = DemoFilePicker();
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            filePicker: picker,
            child: Builder(
              builder: (rootContext) {
                final root = ZcrudScope.maybeOf(rootContext);
                return wrapWithBinding(
                  binding,
                  Builder(
                    builder: (inner) {
                      seen = ZcrudScope.of(inner).filePicker;
                      return const SizedBox.shrink();
                    },
                  ),
                  rootScope: root,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(seen, isNotNull,
          reason: 'filePicker racine masqué sous ${binding.label}');
      expect(identical(seen, picker), isTrue,
          reason: 'filePicker forwardé doit être l\'instance racine '
              '(${binding.label})');
    });
  }

  testWidgets('AC7 — changer de binding remonte proprement le formulaire',
      (tester) async {
    tester.view.physicalSize = Size(
        1200 * tester.view.devicePixelRatio, 6000 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(DemoBinding.scope, RebuildLog()));
    await tester.pumpAndSettle();

    // Bascule vers le binding provider via le sélecteur segmenté.
    await tester.tap(find.text(DemoBinding.provider.label));
    await tester.pumpAndSettle();

    expect(find.byType(ZTextFieldWidget), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
