// AC5 — Assemblage `DynamicEdition` : N champs distincts rendus, chacun lié à
// sa tranche ; en-têtes de section visuels ; changement de `visibleFields`
// (canal STRUCTUREL) reflété sans toucher les tranches de valeur des champs
// restants.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '_reference_form.dart';

void main() {
  testWidgets('rend N champs distincts + en-têtes de section (AC5)',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    // N champs (dispatcher `ZFieldWidget`) distincts montés (surface haute).
    expect(find.byType(ZFieldWidget), findsNWidgets(form.fieldCount));

    // Les 3 en-têtes de section sont présents.
    for (final title in sectionTitles) {
      expect(find.text(title), findsOneWidget);
    }

    // Chaque champ est lié à sa tranche : écrire sur l'un met à jour SON slice.
    form.controller.setValue(fieldName(0, 0), 'x');
    await tester.pump();
    expect(form.controller.valueOf(fieldName(0, 0)), 'x');
    expect(form.controller.valueOf(fieldName(1, 0)), '');
  });

  testWidgets(
      'ListView.builder : montage paresseux, seuls les champs visibles construits',
      (tester) async {
    // Surface par défaut (petite) : tous les champs ne tiennent pas → montage
    // paresseux du `ListView.builder` (jamais `ListView(children:)`).
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pump();

    final mounted = find.byType(ZFieldWidget).evaluate().length;
    expect(mounted, lessThan(form.fieldCount),
        reason: 'ListView.builder ne monte QUE les champs visibles');
    expect(mounted, greaterThan(0));
  });

  testWidgets(
      'changement de visibleFields reflété sans toucher les tranches restantes (AC5)',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    // Pré-remplir deux champs restants.
    form.controller.setValue(fieldName(0, 0), 'garde-moi');
    form.controller.setValue(fieldName(0, 1), 'moi-aussi');
    await tester.pump();

    // Retrait STRUCTUREL d'un champ (canal visibleFields).
    final removed = fieldName(2, 0);
    final next = <String>[
      for (final f in form.fields)
        if (f.name != removed) f.name,
    ];
    form.controller.setVisibleFields(next);
    await tester.pumpAndSettle();

    // Le champ retiré n'est plus rendu ; les autres restent, valeurs intactes.
    expect(find.byKey(const ValueKey<String>('f_2_0')), findsNothing);
    expect(form.controller.valueOf(fieldName(0, 0)), 'garde-moi');
    expect(form.controller.valueOf(fieldName(0, 1)), 'moi-aussi');
    expect(find.byType(ZFieldWidget), findsNWidgets(form.fieldCount - 1));
  });

  testWidgets('liste plate sans sections (en-têtes optionnels)', (tester) async {
    final controller = ZFormController(
      initialValues: const <String, Object?>{'a': '', 'b': ''},
      visibleFields: const <String>['a', 'b'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text),
              ZFieldSpec(name: 'b', type: EditionFieldType.text),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ZFieldWidget), findsNWidgets(2));
    // Chaque champ porte bien sa place stable ValueKey(name) via KeyedSubtree
    // (garde L3/AC7 côté `DynamicEdition._buildField`).
    expect(find.byKey(const ValueKey<String>('a')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('b')), findsOneWidget);
  });
}
