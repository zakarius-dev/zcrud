// AC6 — CURSEUR AU MILIEU préservé (comble L2 du code-review E3-1) + focus.
//
// PIÈGE (Dev Notes) : `tester.enterText` REMPLACE tout le texte et repositionne
// le caret EN FIN — inutilisable pour prouver « caret médian préservé ». On
// utilise l'IME simulé `tester.testTextInput.updateEditingValue(...)` pour poser
// un caret AU MILIEU, insérer au caret, puis prouver que :
//   - l'insertion se fait à la position MÉDIANE (pas d'append en fin), caret +1 ;
//   - un rebuild STRUCTUREL caret-au-milieu NE réinitialise PAS la sélection
//     (offset médian conservé), NE recrée PAS le State/controller (initState==1),
//     et conserve `hasFocus == true`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets(
      'caret AU MILIEU : insertion médiane + rebuild structurel ne réinitialise '
      'pas la sélection (initState==1, focus gardé) (AC6)', (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);
    TextEditingController ctrl() =>
        tester.widget<EditableText>(editableOf(target)).controller;
    FocusNode focus() =>
        tester.widget<EditableText>(editableOf(target)).focusNode;

    expect(form.fieldInits[target], 1, reason: 'State monté une seule fois');

    // Focaliser le champ (ouvre la connexion IME simulée).
    await tester.tap(editableOf(target));
    await tester.pump();
    expect(focus().hasFocus, isTrue);

    // Poser 'ABCDEF' avec un caret AU MILIEU (offset 3), via l'IME simulé.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ABCDEF',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(ctrl().text, 'ABCDEF');
    expect(ctrl().selection.baseOffset, 3, reason: 'caret médian posé');

    // Insérer 'X' AU CARET (offset 3 → 'ABCXDEF', caret 4) — pas un append en fin.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ABCXDEF',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    // (1) Insertion MÉDIANE (X en position 3), caret avancé de 1 (médian, pas 7).
    expect(ctrl().text, 'ABCXDEF');
    expect(ctrl().selection.baseOffset, 4,
        reason: 'caret médian +1, jamais recollé en fin');
    // (2) `setValue` reçoit le texte médian correct (sens unique onChanged).
    expect(form.controller.valueOf(target), 'ABCXDEF');

    // ── REBUILD STRUCTUREL caret-au-milieu (réordonnancement visibleFields) ──
    // Permutation des deux DERNIERS champs (loin de la cible) : rebuild
    // structurel RÉEL laissant la cible en place (le grand déplacement relèverait
    // du recyclage de viewport de `ListView.builder`, hors périmètre E3-2).
    final reordered = List<String>.from(form.fields.map((f) => f.name));
    final last = reordered.length - 1;
    final tmp = reordered[last];
    reordered[last] = reordered[last - 1];
    reordered[last - 1] = tmp;
    form.controller.setVisibleFields(reordered);
    await tester.pumpAndSettle();

    // (3) Sélection INCHANGÉE (offset médian 4 conservé) — aucune ré-injection.
    expect(ctrl().text, 'ABCXDEF');
    expect(ctrl().selection.baseOffset, 4,
        reason: 'rebuild structurel ne réinitialise pas le caret médian');
    // (4) State/controller NON recréés.
    expect(form.fieldInits[target], 1,
        reason: 'ValueKey(name) → pas de ré-init au rebuild structurel');
    // (5) Focus conservé.
    expect(focus().hasFocus, isTrue);
  });
}
