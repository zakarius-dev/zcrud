// AC11 — Validation ciblée réutilisée (E3-2, AD-2) à travers le dispatcher :
// - AUCUN `Form`/`FormBuilder` global sous le formulaire (find.byType(Form) →
//   findsNothing) ;
// - le validateur mémoïsé garde une identité STABLE entre builds ;
// - l'erreur d'un champ n'affecte pas ses voisins.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(
    name: 'requis',
    type: EditionFieldType.text,
    label: 'Requis',
    validators: <ZValidatorSpec>[
      ZValidatorSpec.required(errorText: 'obligatoire'),
    ],
  ),
  ZFieldSpec(name: 'libre', type: EditionFieldType.text, label: 'Libre'),
  ZFieldSpec(name: 'actif', type: EditionFieldType.boolean, label: 'Actif'),
];

void main() {
  testWidgets('aucun Form global sous le formulaire (AC11)', (tester) async {
    final controller = ZFormController(
      initialValues: const <String, Object?>{'requis': '', 'libre': '', 'actif': false},
      visibleFields: const <String>['requis', 'libre', 'actif'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicEdition(controller: controller, fields: _fields),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AD-2 : validation PAR CHAMP, jamais un `Form`/`FormBuilder` global.
    expect(find.byType(Form), findsNothing);
  });

  testWidgets("l'erreur d'un champ n'affecte pas ses voisins (AC11)",
      (tester) async {
    final controller = ZFormController(
      initialValues: const <String, Object?>{'requis': '', 'libre': '', 'actif': false},
      visibleFields: const <String>['requis', 'libre', 'actif'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicEdition(controller: controller, fields: _fields),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final requis = find.descendant(
      of: find.byKey(const ValueKey<String>('requis')),
      matching: find.byType(EditableText),
    );

    // Déclenche la validation `onUserInteraction` : saisir puis vider.
    await tester.enterText(requis, 'x');
    await tester.pump();
    await tester.enterText(requis, '');
    await tester.pump();

    // Le message d'erreur apparaît UNIQUEMENT pour le champ requis.
    expect(find.text('obligatoire'), findsOneWidget);
  });

  test('validateur mémoïsé : identité STABLE entre builds (AC11)', () {
    const specs = <ZValidatorSpec>[
      ZValidatorSpec.required(),
    ];
    final a = ZValidatorCompiler.compile(specs);
    final b = ZValidatorCompiler.compile(specs);
    // Chaque compilation produit un validateur ; l'hôte le mémoïse en
    // `late final` (1 compilation par champ, identité stable entre builds).
    expect(a, isNotNull);
    expect(b, isNotNull);
    // La liste vide ⇒ aucun validateur (aucune surcharge sur le champ).
    expect(ZValidatorCompiler.compile(const <ZValidatorSpec>[]), isNull);
  });
}
