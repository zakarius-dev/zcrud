import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/reference_form.dart';

import 'support/pump_helpers.dart';

void main() {
  test('AC4 — le formulaire de référence a ≥30 champs / ≥3 sections', () {
    expect(ReferenceForm.fields.length, greaterThanOrEqualTo(30));
    expect(ReferenceForm.sections.length, greaterThanOrEqualTo(3));
  });

  test('AC4 — les familles E3 requises sont couvertes par le schéma', () {
    final types = ReferenceForm.fields.map((f) => f.type).toSet();
    const required = <EditionFieldType>{
      EditionFieldType.text,
      EditionFieldType.multiline,
      EditionFieldType.number,
      EditionFieldType.integer,
      EditionFieldType.float,
      EditionFieldType.boolean,
      EditionFieldType.checkbox,
      EditionFieldType.dateTime,
      EditionFieldType.time,
      EditionFieldType.select,
      EditionFieldType.radio,
      EditionFieldType.relation,
      EditionFieldType.tags,
      EditionFieldType.rowChips,
      EditionFieldType.rating,
      EditionFieldType.slider,
      EditionFieldType.color,
      EditionFieldType.signature,
      EditionFieldType.file,
      EditionFieldType.image,
      EditionFieldType.document,
      EditionFieldType.subItems,
    };
    expect(types.containsAll(required), isTrue,
        reason: 'Manquants : ${required.difference(types)}');
  });

  testWidgets(
      'AC4 — chaque champ de référence est rendu par un widget de famille dédié '
      '(aucun ZUnsupportedFieldWidget)', (tester) async {
    for (final field in ReferenceForm.fields) {
      final controller = ZFormController(
        initialValues: <String, Object?>{field.name: null},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapForTest(ZFieldWidget(controller: controller, field: field)),
      );
      await tester.pump();

      expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
          reason: 'Champ ${field.name} (${field.type}) rendu non supporté');
    }
  });

  testWidgets('AC4 — familles représentatives rendues via DynamicEdition',
      (tester) async {
    useTallSurface(tester);
    final controller =
        ZFormController(initialValues: ReferenceForm.initialValues());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapForTest(
        DynamicEdition(
          controller: controller,
          fields: ReferenceForm.fields,
          sections: ReferenceForm.sections,
        ),
      ),
    );
    await tester.pump();

    // Un échantillon de familles est présent dans la première fenêtre.
    expect(find.byType(ZTextFieldWidget), findsWidgets);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    // Aucun Form/FormBuilder global dans le moteur (SM-1 / AD-2).
    expect(find.byType(Form), findsNothing);
  });
}
