// E3-6 — Write-back de valeur externe (AC13 / report c) : reset/reseed re-amorce
// les widgets à buffer interne HORS focus ; une saisie en cours n'est jamais
// écrasée (report différé à la perte de focus, FR-1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _editable(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );

Widget _oneField(ZFormController c) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[
            ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
          ],
        ),
      ),
    );

void main() {
  test('reset/reseed incrémentent reseedRevision', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 'init'});
    addTearDown(c.dispose);
    final r0 = c.reseedRevision.value;
    c.reset();
    expect(c.reseedRevision.value, r0 + 1);
    c.reseed(<String, Object?>{'a': 'x'});
    expect(c.reseedRevision.value, r0 + 2);
  });

  testWidgets('AC13 — champ NON focalisé : reset re-amorce le buffer sur la baseline',
      (tester) async {
    final c = ZFormController(initialValues: <String, Object?>{'a': 'init'});
    addTearDown(c.dispose);

    await tester.pumpWidget(_oneField(c));
    await tester.pumpAndSettle();

    // Mutation externe (hors focus) reflétée dans le champ.
    c.setValue('a', 'modif');
    await tester.pump();
    expect(tester.widget<EditableText>(_editable('a')).controller.text, 'modif');

    // reset ⇒ restaure la baseline dans le buffer (hors focus).
    c.reset();
    await tester.pump();
    expect(tester.widget<EditableText>(_editable('a')).controller.text, 'init');
  });

  testWidgets('AC13 — champ FOCALISÉ : reseed n\'écrase PAS la saisie ; report à la perte de focus',
      (tester) async {
    final c = ZFormController(initialValues: <String, Object?>{'a': 'init'});
    addTearDown(c.dispose);

    await tester.pumpWidget(_oneField(c));
    await tester.pumpAndSettle();

    await tester.tap(_editable('a'));
    await tester.pump();
    await tester.enterText(_editable('a'), 'partiel');
    await tester.pump();
    expect(tester.widget<EditableText>(_editable('a')).focusNode.hasFocus, isTrue);

    // Write-back externe PENDANT le focus.
    c.reseed(<String, Object?>{'a': 'EXTERNE'});
    await tester.pump();

    // La saisie en cours n'est PAS écrasée.
    expect(tester.widget<EditableText>(_editable('a')).controller.text, 'partiel');
    expect(c.valueOf('a'), 'EXTERNE');

    // Perte de focus ⇒ report du re-seed (le buffer reflète la valeur externe).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.widget<EditableText>(_editable('a')).controller.text, 'EXTERNE');
  });
}
