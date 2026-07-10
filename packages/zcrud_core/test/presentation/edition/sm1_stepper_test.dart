// E3-5 AC10/AC11 — SM-1 re-prouvé DANS le stepper (objectif produit n°1).
//   Sur une étape de référence (≥ 10 champs), taper 100 caractères :
//   - ne reconstruit PAS le chrome du stepper (compteur `onStructuralBuild`
//     inchangé — AC11 : le chrome n'observe que des canaux structurels) ;
//   - ne reconstruit AUCUN champ voisin (seul le champ courant, ~1/frappe) ;
//   - zéro perte de focus / saut de curseur (curseur au milieu inclus).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Étape de référence : 12 champs (≥ 10) + 1 conditionnel + 1 required, sur 2
/// étapes. Instrumente `onStructuralBuild` (chrome) et le build par champ.
class _StepperSm1Form {
  final Map<String, int> fieldBuilds = <String, int>{};
  int chromeBuilds = 0;

  static const int perStep = 12;
  static String s0(int i) => 's0_$i';

  late final List<ZFieldSpec> fields = <ZFieldSpec>[
    for (var i = 0; i < perStep; i++)
      ZFieldSpec(name: s0(i), type: EditionFieldType.text, label: 'A$i'),
    // Un champ conditionnel dans l'étape 0 (garde = s0_0).
    const ZFieldSpec(
      name: 's0_cond',
      type: EditionFieldType.text,
      label: 'Cond',
      condition: ZCondition.truthy('s0_0'),
    ),
    // Étape 1 (non montée pendant le test) avec un required.
    const ZFieldSpec(
      name: 's1_x',
      type: EditionFieldType.text,
      label: 'X',
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'R')],
    ),
  ];

  late final List<ZEditionStep> steps = <ZEditionStep>[
    ZEditionStep(
      title: 'Étape 0',
      fields: <String>[for (var i = 0; i < perStep; i++) s0(i), 's0_cond'],
    ),
    const ZEditionStep(title: 'Étape 1', fields: <String>['s1_x']),
  ];

  late final ZFormController controller = ZFormController(
    initialValues: <String, Object?>{for (final f in fields) f.name: ''},
    visibleFields: <String>[for (final f in fields) f.name],
  );

  Widget build() => MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: controller,
            fields: fields,
            steps: steps,
            onComplete: () {},
            onStructuralBuild: () => chromeBuilds++,
            fieldBuilder: (context, ctrl, field, mode) => ZFieldWidget(
              controller: ctrl,
              field: field,
              autovalidateMode: mode,
              onBuild: () =>
                  fieldBuilds[field.name] = (fieldBuilds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  testWidgets('AC10/AC11 — 100 frappes dans une étape ⇒ 0 build chrome, aucun '
      'voisin reconstruit, focus + curseur préservés', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final form = _StepperSm1Form();
    addTearDown(form.dispose);

    // ≥ 10 champs montés dans l'étape de référence.
    expect(_StepperSm1Form.perStep, greaterThanOrEqualTo(10));

    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    const target = 's0_5';
    final targetEditable = find.descendant(
      of: find.byKey(const ValueKey<String>(target)),
      matching: find.byType(EditableText),
    );
    expect(targetEditable, findsOneWidget);

    final baseChrome = form.chromeBuilds;
    final baseTarget = form.fieldBuilds[target]!;
    final base = Map<String, int>.from(form.fieldBuilds);

    await tester.tap(targetEditable);
    await tester.pump();
    expect(tester.widget<EditableText>(targetEditable).focusNode.hasFocus,
        isTrue);

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26)));
      await tester.enterText(targetEditable, buffer.toString());
      await tester.pump();
      expect(tester.widget<EditableText>(targetEditable).focusNode.hasFocus,
          isTrue,
          reason: 'focus conservé à la frappe $i');
    }

    // (1) AC11 : chrome NON reconstruit pendant la saisie (canaux structurels).
    expect(form.chromeBuilds, baseChrome,
        reason: 'aucun rebuild du chrome sur une frappe (champ non-garde)');

    // (2) AC10 : seul le champ cible reconstruit ; voisins jamais.
    expect(form.fieldBuilds[target], baseTarget + total);
    for (final e in base.entries) {
      if (e.key == target) continue;
      expect(form.fieldBuilds[e.key], e.value,
          reason: 'voisin ${e.key} ne reconstruit pas');
    }

    // (3) Curseur en fin, valeur propagée dans la tranche.
    final ed = tester.widget<EditableText>(targetEditable);
    expect(ed.controller.text, buffer.toString());
    expect(ed.controller.selection.baseOffset, total);
    expect(form.controller.valueOf(target), buffer.toString());
  });

  testWidgets('AC10 — curseur AU MILIEU préservé pendant la saisie', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final form = _StepperSm1Form();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    const target = 's0_3';
    final ed = find.descendant(
      of: find.byKey(const ValueKey<String>(target)),
      matching: find.byType(EditableText),
    );
    await tester.enterText(ed, 'abcdef');
    await tester.pump();

    // Place le curseur au milieu (offset 3) et insère sans le perdre.
    final state = tester.state<EditableTextState>(ed);
    state.updateEditingValue(const TextEditingValue(
      text: 'abcdef',
      selection: TextSelection.collapsed(offset: 3),
    ));
    await tester.pump();
    expect(tester.widget<EditableText>(ed).controller.selection.baseOffset, 3);

    final chromeBefore = form.chromeBuilds;
    state.updateEditingValue(const TextEditingValue(
      text: 'abcXdef',
      selection: TextSelection.collapsed(offset: 4),
    ));
    await tester.pump();

    expect(tester.widget<EditableText>(ed).controller.text, 'abcXdef');
    expect(tester.widget<EditableText>(ed).controller.selection.baseOffset, 4,
        reason: 'curseur au milieu non écrasé');
    expect(form.chromeBuilds, chromeBefore,
        reason: 'saisie médiane ⇒ aucun rebuild chrome');
  });
}
