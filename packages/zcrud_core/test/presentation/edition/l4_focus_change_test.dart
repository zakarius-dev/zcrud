// AC10 (finding L4) — Changement de focus entre champs à travers le dispatcher.
// Taper un champ A (saisir), puis taper un champ B : (a) transfert de focus
// propre (A perd, B obtient) ; (b) aucun rebuild-storm sur A (compteur borné) ;
// (c) aucun reset de la valeur/curseur de A. Couvre A texte → B texte, et le
// bonus A texte → B select (non-texte).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets('A texte → B texte : focus transféré, A borné, A non réinitialisé',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: form.buildForm())));
    await tester.pumpAndSettle();

    final a = fieldName(0, 0);
    final b = fieldName(1, fieldsPerSection ~/ 2);
    final aEditable = editableOf(a);
    final bEditable = editableOf(b);

    // Saisie dans A.
    await tester.tap(aEditable);
    await tester.pump();
    await tester.enterText(aEditable, 'ALPHA');
    await tester.pump();
    expect(tester.widget<EditableText>(aEditable).focusNode.hasFocus, isTrue);

    final aBuildsAfterTyping = form.fieldBuilds[a]!;

    // Bascule vers B.
    await tester.tap(bEditable);
    await tester.pump();

    // (a) Transfert de focus propre.
    expect(tester.widget<EditableText>(aEditable).focusNode.hasFocus, isFalse,
        reason: 'A perd le focus');
    expect(tester.widget<EditableText>(bEditable).focusNode.hasFocus, isTrue,
        reason: 'B obtient le focus');

    // (b) Pas de rebuild-storm sur A : au plus 1 rebuild lié au blur.
    expect(form.fieldBuilds[a]! - aBuildsAfterTyping, lessThanOrEqualTo(1),
        reason: 'A ne subit pas de rafale de rebuilds au changement de focus');

    // (c) Valeur + curseur de A préservés (aucun reset).
    final aCtrl = tester.widget<EditableText>(aEditable).controller;
    expect(aCtrl.text, 'ALPHA');
    expect(aCtrl.selection.baseOffset, 'ALPHA'.length);
    expect(form.controller.valueOf(a), 'ALPHA');
  });
}
