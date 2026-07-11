// DP-17 (M17) — nombre : formatage devise/pourcentage NEUTRE.
//
// Couvre :
//  - suffixe `%` en édition quand `isPercentage` ;
//  - symbole monétaire (config `currencySymbol` prioritaire, sinon repli l10n
//    `currencySuffix`) en édition quand `isCurrency` ;
//  - AUCUN suffixe sans config (rétro-compat E3-3a) ;
//  - formatage LECTURE (mode `readMode`) : « 42 % » / « 42 <symbole> ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

ZFieldWidget _field(ZFieldSpec spec,
        {Object? value, bool readMode = false}) =>
    ZFieldWidget(
      controller: ZFormController(
        initialValues: <String, Object?>{spec.name: value},
        visibleFields: <String>[spec.name],
      ),
      field: spec,
      readMode: readMode,
    );

void main() {
  group('DP-17 M17 — suffixe édition', () {
    testWidgets('isPercentage → suffixe %', (tester) async {
      await tester.pumpWidget(_host(_field(const ZFieldSpec(
        name: 'p',
        type: EditionFieldType.number,
        label: 'Taux',
        config: ZNumberConfig(isPercentage: true),
      ))));
      await tester.pump();
      expect(find.text('%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isCurrency + currencySymbol → symbole fourni (neutre)',
        (tester) async {
      await tester.pumpWidget(_host(_field(const ZFieldSpec(
        name: 'prix',
        type: EditionFieldType.number,
        label: 'Prix',
        config: ZNumberConfig(isCurrency: true, currencySymbol: '€'),
      ))));
      await tester.pump();
      expect(find.text('€'), findsOneWidget);
    });

    testWidgets('isCurrency sans symbole → repli l10n currencySuffix',
        (tester) async {
      await tester.pumpWidget(_host(_field(const ZFieldSpec(
        name: 'prix',
        type: EditionFieldType.number,
        label: 'Prix',
        config: ZNumberConfig(isCurrency: true),
      ))));
      await tester.pump();
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('sans config → aucun suffixe (rétro-compat)', (tester) async {
      await tester.pumpWidget(_host(_field(const ZFieldSpec(
        name: 'n',
        type: EditionFieldType.number,
        label: 'N',
      ))));
      await tester.pump();
      expect(find.text('%'), findsNothing);
      expect(find.text(r'$'), findsNothing);
    });
  });

  group('DP-17 M17 — formatage lecture (readMode)', () {
    testWidgets('pourcentage → « 42 % »', (tester) async {
      await tester.pumpWidget(_host(_field(
        const ZFieldSpec(
          name: 'p',
          type: EditionFieldType.number,
          label: 'Taux',
          config: ZNumberConfig(isPercentage: true),
        ),
        value: 42,
        readMode: true,
      )));
      await tester.pump();
      expect(find.text('42 %'), findsOneWidget);
    });

    testWidgets('devise → « 42 € »', (tester) async {
      await tester.pumpWidget(_host(_field(
        const ZFieldSpec(
          name: 'prix',
          type: EditionFieldType.number,
          label: 'Prix',
          config: ZNumberConfig(isCurrency: true, currencySymbol: '€'),
        ),
        value: 42,
        readMode: true,
      )));
      await tester.pump();
      expect(find.text('42 €'), findsOneWidget);
    });
  });
}
