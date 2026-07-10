import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/edition_demo_screen.dart';
import 'package:zcrud_example/support/demo_file_picker.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';

Widget _hostScreen(RebuildLog log) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
      home: ZcrudScope(
        filePicker: const DemoFilePicker(),
        child: EditionDemoScreen(rebuildLog: log),
      ),
    );

void main() {
  testWidgets(
      'AC6/SM-1 — taper 100 caractères ne reconstruit QUE le champ courant, '
      'focus conservé, aucun Form global', (tester) async {
    tester.view.physicalSize =
        Size(1200 * tester.view.devicePixelRatio, 6000 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final log = RebuildLog();
    await tester.pumpWidget(_hostScreen(log));
    await tester.pumpAndSettle();

    // Aucun Form/FormBuilder global (AD-2 / objectif produit n°1).
    expect(find.byType(Form), findsNothing);

    final fullNameField = find.descendant(
      of: find.byKey(const ValueKey<String>('fullName')),
      matching: find.byType(EditableText),
    );
    final nickField = find.descendant(
      of: find.byKey(const ValueKey<String>('nickname')),
      matching: find.byType(EditableText),
    );
    expect(fullNameField, findsOneWidget);
    expect(nickField, findsOneWidget);

    final baseFull = log.countOf('fullName');
    final baseNick = log.countOf('nickname');

    // Frappe de 100 caractères, un par un (100 événements de saisie).
    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('a');
      await tester.enterText(fullNameField, buffer.toString());
      await tester.pump();
    }

    // (i) Seul le champ courant se reconstruit.
    expect(log.countOf('fullName') - baseFull, greaterThanOrEqualTo(100),
        reason: 'Le champ courant doit se reconstruire à chaque frappe');
    expect(log.countOf('nickname'), baseNick,
        reason: 'Le champ voisin ne doit JAMAIS se reconstruire (SM-1)');

    // (ii) Focus et position du curseur conservés.
    final editable = tester.widget<EditableText>(fullNameField);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'Focus perdu');
    expect(editable.controller.text, 'a' * 100);
    expect(editable.controller.selection.baseOffset, 100,
        reason: 'Curseur non conservé en fin de saisie');
  });
}
