// AC6 — TEST SM-1 COMPLET (headline) : OBJECTIF PRODUIT N°1, plein formulaire.
//
// Sur un formulaire de référence (≥ 30 champs, ≥ 3 sections), taper 100
// caractères caractère-par-caractère dans un champ CENTRAL :
//   - le compteur de build du champ courant augmente (≈ 1 par frappe) ;
//   - le compteur de build de CHAQUE autre champ reste STRICTEMENT inchangé ;
//   - le compteur de build de niveau formulaire reste inchangé (0 rebuild global) ;
//   - le `FocusNode` du champ courant garde `hasFocus == true` d'un bout à l'autre ;
//   - la sélection/curseur n'est jamais réinitialisée (curseur en fin après frappe).
//
// PIÈGE (Dev Notes) : `enterText` REMPLACE tout le texte et repositionne le
// curseur ; on saisit donc une chaîne CUMULATIVE (substring 0..i) pour simuler
// une frappe incrémentale et prouver « zéro perte de curseur » côté NOTRE code
// (aucune ré-injection `.text=`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets(
      'SM-1 plein formulaire : 100 frappes ne reconstruisent QUE le champ courant '
      '(voisins + formulaire inchangés, focus + curseur préservés)',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    // ≥ 30 champs / ≥ 3 sections.
    expect(form.fieldCount, greaterThanOrEqualTo(30));
    expect(form.sections.length, greaterThanOrEqualTo(3));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    // Champ CENTRAL (section du milieu, index médian).
    final target = fieldName(1, fieldsPerSection ~/ 2);
    final targetEditable = editableOf(target);
    expect(targetEditable, findsOneWidget);

    // Baselines APRÈS montage : chaque champ monté a construit exactement 1 fois.
    final base = Map<String, int>.from(form.fieldBuilds);
    final baseForm = form.formBuilds;
    expect(base[target], 1, reason: 'le champ cible est monté une fois');
    expect(baseForm, 1, reason: 'le builder structurel s\'exécute une fois au montage');

    // Focus explicite sur le champ cible.
    await tester.tap(targetEditable);
    await tester.pump();
    var editable = tester.widget<EditableText>(targetEditable);
    expect(editable.focusNode.hasFocus, isTrue);

    // 100 frappes INCRÉMENTALES (chaîne cumulative).
    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26))); // a..z cyclique
      await tester.enterText(targetEditable, buffer.toString());
      await tester.pump();
      // Focus JAMAIS perdu pendant la saisie.
      editable = tester.widget<EditableText>(targetEditable);
      expect(editable.focusNode.hasFocus, isTrue,
          reason: 'focus conservé à la frappe $i');
    }

    final typed = buffer.toString();
    expect(typed.length, total);

    // (1) Champ courant reconstruit ≈ 1 par frappe (baseline + 100).
    expect(form.fieldBuilds[target], base[target]! + total,
        reason: 'le champ courant reconstruit une fois par frappe');

    // (2) TOUT autre champ monté : compteur STRICTEMENT inchangé.
    for (final entry in base.entries) {
      if (entry.key == target) continue;
      expect(form.fieldBuilds[entry.key], entry.value,
          reason: 'voisin ${entry.key} ne doit JAMAIS reconstruire');
    }

    // (3) Compteur de niveau formulaire inchangé (0 rebuild global).
    expect(form.formBuilds, baseForm,
        reason: 'aucun rebuild global (notifyListeners) sur frappe');

    // (4) Focus conservé jusqu'au bout.
    editable = tester.widget<EditableText>(targetEditable);
    expect(editable.focusNode.hasFocus, isTrue);

    // (5) Curseur en fin de texte (non réinitialisé), texte final = 100 char.
    final textCtrl = editable.controller;
    expect(textCtrl.text, typed);
    expect(textCtrl.text.length, total);
    expect(textCtrl.selection.baseOffset, total);
    expect(textCtrl.selection.extentOffset, total);

    // Valeur propagée au controller (sens unique onChanged → setValue).
    expect(form.controller.valueOf(target), typed);
  });
}
