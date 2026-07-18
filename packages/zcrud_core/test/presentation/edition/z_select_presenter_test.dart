// AD-48 — Seam `ZSelectPresenter` : DÉLÉGATION des familles `select`/`relation`
// au présentateur injecté au scope (via DTO NEUTRE `ZSelectPresentation`, jamais
// le controller — AD-2) ; défaut `null` → rendu natif STRICTEMENT conservé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Présentateur ESPION : capture les présentations reçues et rend un marqueur.
class _SpyPresenter extends ZSelectPresenter {
  _SpyPresenter(this.captured);

  final List<ZSelectPresentation> captured;

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    captured.add(presentation);
    return Text('PRESENTER:${presentation.field.name}',
        textDirection: TextDirection.ltr);
  }
}

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  ZSelectPresenter? presenter,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        selectPresenter: presenter,
        child: DynamicEdition(controller: controller, fields: fields),
      ),
    ),
  );
}

void main() {
  const selectField = ZFieldSpec(
    name: 's',
    type: EditionFieldType.select,
    label: 'Choix',
    choices: <ZFieldChoice>[
      ZFieldChoice(value: 'a', label: 'Alpha'),
      ZFieldChoice(value: 'b', label: 'Beta'),
    ],
  );
  const relationField = ZFieldSpec(
    name: 'r',
    type: EditionFieldType.relation,
    label: 'Relation',
    choices: <ZFieldChoice>[ZFieldChoice(value: 'x', label: 'X')],
  );

  testWidgets('select : présentateur injecté est APPELÉ (pas de rendu natif)',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'s': 'a'},
      visibleFields: <String>['s'],
    );
    addTearDown(controller.dispose);
    final captured = <ZSelectPresentation>[];
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[selectField],
      presenter: _SpyPresenter(captured),
    ));
    await tester.pump();

    // Le présentateur a été appelé AVANT tout rendu (espion capté).
    expect(captured, hasLength(greaterThanOrEqualTo(1)));
    expect(find.text('PRESENTER:s'), findsOneWidget);
    // Rendu natif ÉVINCÉ (aucun dropdown Material).
    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);

    // DTO NEUTRE : options/selected/label présents, controller JAMAIS exposé.
    final p = captured.first;
    expect(p.options.map((c) => c.value), <Object?>['a', 'b']);
    expect(p.selected, 'a');
    expect(p.multiple, isFalse);
    expect(p.label, 'Choix');
  });

  testWidgets('relation : présentateur injecté est APPELÉ', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'r': 'x'},
      visibleFields: <String>['r'],
    );
    addTearDown(controller.dispose);
    final captured = <ZSelectPresentation>[];
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[relationField],
      presenter: _SpyPresenter(captured),
    ));
    await tester.pump();
    expect(find.text('PRESENTER:r'), findsOneWidget);
    // Rendu natif ÉVINCÉ pour `relation` aussi (symétrie avec select) : sous
    // l'injection retirant le `return` de z_relation_field_widget.dart:169
    // (double rendu presenter+natif), ce dropdown natif réapparaîtrait → rouge.
    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    expect(captured.first.options.single.value, 'x');
  });

  testWidgets('checkbox → présentation multiple = true', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'c': <Object?>[]},
      visibleFields: <String>['c'],
    );
    addTearDown(controller.dispose);
    const checkboxField = ZFieldSpec(
      name: 'c',
      type: EditionFieldType.checkbox,
      label: 'Cases',
      choices: <ZFieldChoice>[ZFieldChoice(value: 'a', label: 'A')],
    );
    final captured = <ZSelectPresentation>[];
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[checkboxField],
      presenter: _SpyPresenter(captured),
    ));
    await tester.pump();
    expect(captured.first.multiple, isTrue);
  });

  testWidgets('onChanged du DTO écrit bien la tranche (jamais le controller)',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'s': null},
      visibleFields: <String>['s'],
    );
    addTearDown(controller.dispose);
    final captured = <ZSelectPresentation>[];
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[selectField],
      presenter: _SpyPresenter(captured),
    ));
    await tester.pump();
    captured.first.onChanged('b');
    expect(controller.valueOf('s'), 'b');
  });

  testWidgets('DÉFAUT null : rendu natif conservé (aucune régression)',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'s': 'a'},
      visibleFields: <String>['s'],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[selectField],
    ));
    await tester.pump();
    // Sans présentateur → dropdown natif présent, aucun marqueur.
    expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
    expect(find.textContaining('PRESENTER:'), findsNothing);
  });
}
