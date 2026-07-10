// AC1 — CONTRAT DE STABILITÉ du `TextEditingController` (généralisé, testé de
// premier ordre). Le controller (et le `State`) sont créés EXACTEMENT UNE FOIS
// et jamais recréés au rebuild — y compris après N rebuilds STRUCTURELS de
// `DynamicEdition` via `setVisibleFields` (réordonnancement/refresh sans retirer
// le champ). Garde textuelle : la voie de frappe reste sens unique (aucun
// `_text.text =` ; le seul write-back `_text.value =` est GARDÉ par `!hasFocus`).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets(
      'controller/State créés 1× : inchangés après N setVisibleFields '
      '(réordonnancement structurel sans retrait du champ) (AC1)', (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);
    final other = fieldName(0, 0);
    expect(form.fieldInits[target], 1, reason: 'State monté une seule fois');

    // Capture l'instance exacte du TextEditingController rendu.
    TextEditingController controllerOf(String name) =>
        tester.widget<EditableText>(editableOf(name)).controller;
    final ctrlBefore = controllerOf(target);

    // Saisie partielle (état de saisie qui doit survivre aux rebuilds).
    await tester.enterText(editableOf(target), 'ABC');
    await tester.pump();
    expect(controllerOf(target).text, 'ABC');

    // N rebuilds STRUCTURELS : on RÉ-ORDONNE l'ensemble visible (jamais retirer
    // la cible). Chaque `setVisibleFields` déclenche `notifyListeners()` global →
    // `DynamicEdition` reconstruit structurellement ; `ValueKey(name)` réutilise
    // l'`Element`/`State` → aucune ré-init. On permute les DEUX DERNIERS champs
    // (loin de la cible) en alternance : réordonnancement RÉEL (la liste diffère,
    // donc pas un no-op) qui laisse la position de la cible inchangée — isole
    // l'invariant « rebuild ⇒ pas de recréation » du recyclage de viewport
    // inhérent à `ListView.builder` sur un GRAND déplacement (hors périmètre).
    final base = List<String>.from(form.fields.map((f) => f.name));
    for (var n = 0; n < 8; n++) {
      final reordered = List<String>.from(base);
      final last = reordered.length - 1;
      if (n.isOdd) {
        final tmp = reordered[last];
        reordered[last] = reordered[last - 1];
        reordered[last - 1] = tmp;
      }
      form.controller.setVisibleFields(reordered);
      await tester.pumpAndSettle();
    }

    // (1) `initState` toujours == 1 (State/controller NON recréés).
    expect(form.fieldInits[target], 1,
        reason: 'ValueKey(name) → State réutilisé après N rebuilds structurels');
    expect(form.fieldInits[other], 1);

    // (2) MÊME instance de `TextEditingController` (identité stable).
    expect(identical(controllerOf(target), ctrlBefore), isTrue,
        reason: 'TextEditingController jamais recréé');

    // (3) État de saisie préservé à travers tous les rebuilds structurels.
    expect(controllerOf(target).text, 'ABC');
  });

  test('garde textuelle : voie de frappe sens unique + write-back GARDÉ (AC1)',
      () {
    // Localise le fichier source quel que soit le CWD.
    File srcFile() {
      for (final base in <String>['', 'packages/zcrud_core/']) {
        final f = File(
            '${base}lib/src/presentation/edition/z_edition_field.dart');
        if (f.existsSync()) return f;
      }
      fail('z_edition_field.dart introuvable depuis ${Directory.current.path}');
    }

    final src = srcFile().readAsStringSync();

    // Voie de frappe = sens unique : onChanged délègue à setValue.
    expect(src.contains('setValue(widget.field.name, v)'), isTrue,
        reason: 'la frappe passe par controller.setValue (sens unique)');

    // JAMAIS de ré-injection par `.text =` (interdit AD-2).
    expect(src.contains('_text.text ='), isFalse,
        reason: 'aucune écriture `_text.text =` (ré-injection interdite)');

    // Le SEUL write-back autorisé (`_text.value =`) DOIT être précédé d'une garde
    // de focus `!_focus.hasFocus` (sync guardée hors édition — FR-1).
    final writeBack = src.indexOf('_text.value =');
    if (writeBack >= 0) {
      final guard = src.indexOf('!_focus.hasFocus');
      expect(guard >= 0 && guard < writeBack, isTrue,
          reason: 'le write-back `_text.value =` doit être gardé par !hasFocus');
    }
  });
}
