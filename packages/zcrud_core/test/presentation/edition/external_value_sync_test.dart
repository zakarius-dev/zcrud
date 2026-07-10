// AC2 — SYNCHRONISATION GUARDÉE valeur→champ, sans clobber de sélection (FR-1).
//   (a) champ NON focalisé + `setValue` externe ⇒ le champ reflète la nouvelle
//       valeur (réflexion externe utile : defaultValue, valeur programmatique) ;
//   (b) champ FOCALISÉ (édition en cours) + `setValue` externe ⇒ sélection/
//       curseur ET texte en cours PRÉSERVÉS INTACTS — AUCUN write-back (la
//       réflexion différée à la perte de focus est acceptable ; le clobber
//       pendant le focus est INTERDIT). Voisins jamais touchés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets('(a) champ NON focalisé : setValue externe se reflète dans le champ',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(0, 0);
    // Aucun focus sur la cible : mutation EXTERNE de la tranche.
    form.controller.setValue(target, 'EXTERNE');
    await tester.pump();

    final ctrl = tester.widget<EditableText>(editableOf(target)).controller;
    expect(ctrl.text, 'EXTERNE', reason: 'réflexion externe hors focus');
    expect(find.text('EXTERNE'), findsOneWidget);
    // Le curseur est posé en fin (collapsed) — cohérent, pas de position sale.
    expect(ctrl.selection.baseOffset, 'EXTERNE'.length);
  });

  testWidgets(
      '(b) champ FOCALISÉ : setValue externe NE clobber PAS la saisie/sélection',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);
    final neighbour = fieldName(0, 1);

    // Pré-remplir un voisin (doit rester intact).
    form.controller.setValue(neighbour, 'VOISIN');
    await tester.pump();

    // Focaliser la cible et y saisir un texte PARTIEL.
    await tester.tap(editableOf(target));
    await tester.pump();
    await tester.enterText(editableOf(target), 'partiel');
    await tester.pump();

    var editable = tester.widget<EditableText>(editableOf(target));
    expect(editable.focusNode.hasFocus, isTrue);
    final selBefore = editable.controller.selection;
    expect(editable.controller.text, 'partiel');

    // ── Mutation EXTERNE de la tranche PENDANT l'édition (focus actif) ──────
    form.controller.setValue(target, 'ECRASEMENT_EXTERNE');
    await tester.pump();

    editable = tester.widget<EditableText>(editableOf(target));
    // (1) Texte en cours PRÉSERVÉ (aucun write-back pendant le focus).
    expect(editable.controller.text, 'partiel',
        reason: 'aucun clobber du texte pendant le focus (FR-1)');
    // (2) Sélection/curseur INCHANGÉS.
    expect(editable.controller.selection, selBefore,
        reason: 'sélection préservée (aucune ré-injection)');
    // (3) Focus toujours actif.
    expect(editable.focusNode.hasFocus, isTrue);
    // (4) Le controller DÉTIENT bien la valeur externe (réflexion différée OK).
    expect(form.controller.valueOf(target), 'ECRASEMENT_EXTERNE');

    // (5) Voisin jamais touché.
    expect(
      tester.widget<EditableText>(editableOf(neighbour)).controller.text,
      'VOISIN',
    );
  });
}
