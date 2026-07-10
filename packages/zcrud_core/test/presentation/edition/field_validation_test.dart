// AC3/AC5 — VALIDATION CIBLÉE PAR CHAMP (jamais globale) + validateurs mémoïsés.
//   - `TextFormField` AUTONOME : AUCUN `Form` ancêtre (validation par champ, pas
//     d'agrégateur global — AD-2) ;
//   - `AutovalidateMode.onUserInteraction` : un champ `required` invalidé sur
//     interaction affiche SON message d'erreur sous CE champ ; un voisin valide
//     n'affiche RIEN ; corriger fait DISPARAÎTRE le message ;
//   - la (dé)validation d'un champ ne reconstruit QUE ce champ (isolation SM-1) ;
//   - le `validator` mémoïsé a une IDENTITÉ STABLE entre builds (`identical`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '_reference_form.dart';

void main() {
  ReferenceForm buildRequiredForm() => ReferenceForm(
        validatorsByField: <String, List<ZValidatorSpec>>{
          fieldName(1, fieldsPerSection ~/ 2): const <ZValidatorSpec>[
            ZValidatorSpec.required(errorText: 'REQUIS'),
          ],
        },
      );

  testWidgets('aucun Form ancêtre : validation par champ, pas globale (AC3)',
      (tester) async {
    useTallSurface(tester);
    final form = buildRequiredForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    // Un `TextFormField` autonome ne crée AUCUN `Form` (agrégateur global).
    expect(find.byType(Form), findsNothing,
        reason: 'validation ciblée par champ, sans Form/FormBuilder global');
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets(
      'required invalidé → message sous CE champ ; voisin valide → aucune erreur '
      '; correction → disparition ; isolation du rebuild (AC5)', (tester) async {
    useTallSurface(tester);
    final form = buildRequiredForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);
    final neighbour = fieldName(0, 0);

    // Pas d'erreur avant interaction.
    expect(find.text('REQUIS'), findsNothing);
    final neighbourBuildsBefore = form.fieldBuilds[neighbour];

    // Interaction rendant la valeur INVALIDE : saisir puis vider.
    await tester.enterText(editableOf(target), 'x');
    await tester.pump();
    await tester.enterText(editableOf(target), '');
    await tester.pump();

    // Message d'erreur affiché SOUS le champ cible.
    expect(find.text('REQUIS'), findsOneWidget,
        reason: 'onUserInteraction : required vide → erreur affichée');
    // Localisé sous le champ cible (descendant de sa place stable).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('f_1_6')),
        matching: find.text('REQUIS'),
      ),
      findsOneWidget,
    );

    // Le voisin valide n'affiche AUCUNE erreur ET n'a pas reconstruit
    // (validation ISOLÉE par tranche — non-régression SM-1).
    expect(form.fieldBuilds[neighbour], neighbourBuildsBefore,
        reason: 'la validation du champ cible ne reconstruit PAS le voisin');

    // Correction : le message disparaît (sur interaction).
    await tester.enterText(editableOf(target), 'ok');
    await tester.pump();
    expect(find.text('REQUIS'), findsNothing,
        reason: 'valeur valide → message effacé');
  });

  testWidgets('validateur mémoïsé : identité STABLE entre builds (AC4)',
      (tester) async {
    useTallSurface(tester);
    final form = buildRequiredForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);

    FormFieldValidator<String>? validatorOf() => tester
        .widget<TextFormField>(find.descendant(
          of: find.byKey(const ValueKey<String>('f_1_6')),
          matching: find.byType(TextFormField),
        ))
        .validator;

    final v1 = validatorOf();
    expect(v1, isNotNull, reason: 'un champ required a un validateur');

    // Rebuild de la TRANCHE (setValue) → le validateur ne doit PAS être recréé.
    form.controller.setValue(target, 'a');
    await tester.pump();
    final v2 = validatorOf();

    // Rebuild STRUCTUREL (setVisibleFields réordonné, permutation des deux
    // derniers champs, loin de la cible) → toujours identique.
    final reordered = List<String>.from(form.fields.map((f) => f.name));
    final last = reordered.length - 1;
    final tmp = reordered[last];
    reordered[last] = reordered[last - 1];
    reordered[last - 1] = tmp;
    form.controller.setVisibleFields(reordered);
    await tester.pumpAndSettle();
    final v3 = validatorOf();

    expect(identical(v1, v2), isTrue,
        reason: 'validateur mémoïsé identique après rebuild de tranche');
    expect(identical(v1, v3), isTrue,
        reason: 'validateur mémoïsé identique après rebuild structurel');
  });

  testWidgets('champ SANS validateur → validator == null (aucune surcharge) (AC4)',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm(); // aucun validateur
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.descendant(
      of: find.byKey(const ValueKey<String>('f_0_0')),
      matching: find.byType(TextFormField),
    ));
    expect(field.validator, isNull);
  });
}
