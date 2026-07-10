// AC12 (E3-3b-1, L-2) — comportemental : le champ nombre porte des
// `inputFormatters` PURS (`FilteringTextInputFormatter`) qui FILTRENT la saisie
// non numérique (aucun caractère non-numérique transitoire), en plus du parsing
// typé défensif de la tranche.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _controller(String name) => ZFormController(
      initialValues: <String, Object?>{name: null},
      visibleFields: <String>[name],
    );

Widget _app(ZFormController controller, ZFieldSpec field) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: <ZFieldSpec>[field]),
      ),
    );

void main() {
  testWidgets('integer : la saisie non-numérique est filtrée (digitsOnly)',
      (tester) async {
    final controller = _controller('n');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'n', type: EditionFieldType.integer, label: 'N');

    await tester.pumpWidget(_app(controller, field));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'a1b2c3');
    await tester.pump();

    // Texte affiché filtré → uniquement les chiffres.
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller!.text, '123');
    // Valeur typée en tranche.
    expect(controller.valueOf('n'), 123);
  });

  testWidgets('float : chiffres + point conservés, lettres filtrées',
      (tester) async {
    final controller = _controller('f');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'f', type: EditionFieldType.float, label: 'F');

    await tester.pumpWidget(_app(controller, field));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '12x.5y');
    await tester.pump();

    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller!.text, '12.5');
    expect(controller.valueOf('f'), 12.5);
  });
}
