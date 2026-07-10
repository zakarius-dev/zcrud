// AC7 — NON-RÉGRESSION SM-1 AVEC VALIDATION ACTIVE (FR-1 complet).
//
// Sur le formulaire de référence (≥ 30 champs, ≥ 3 sections) AVEC
// `AutovalidateMode.onUserInteraction` et validateurs MÉMOÏSÉS actifs, taper 100
// caractères dans un champ central :
//   - le compteur de build du CHAMP COURANT augmente (peut se reconstruire pour
//     (dé)afficher l'erreur — borné à la tranche) ;
//   - le compteur de CHAQUE autre champ reste STRICTEMENT inchangé ;
//   - le compteur de NIVEAU FORMULAIRE reste inchangé (0 rebuild global) ;
//   - `hasFocus == true` d'un bout à l'autre ; curseur jamais réinitialisé ;
//   - `valueOf(cible)` == les 100 caractères saisis.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '_reference_form.dart';

void main() {
  testWidgets(
      'SM-1 + validation : 100 frappes sur un champ VALIDÉ ne reconstruisent que '
      'lui (voisins + formulaire inchangés, focus + curseur préservés)',
      (tester) async {
    useTallSurface(tester);
    final target = fieldName(1, fieldsPerSection ~/ 2);
    // Validateurs champ-locaux MÉMOÏSÉS sur la cible + un voisin (preuve que la
    // validation active ne casse pas l'isolation des rebuilds).
    final form = ReferenceForm(
      validatorsByField: <String, List<ZValidatorSpec>>{
        target: const <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'REQUIS'),
          ZValidatorSpec.minLength(3, errorText: 'TROP COURT'),
        ],
        fieldName(0, 0): const <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'REQUIS-VOISIN'),
        ],
      },
    );
    addTearDown(form.dispose);

    expect(form.fieldCount, greaterThanOrEqualTo(30));
    expect(form.sections.length, greaterThanOrEqualTo(3));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: form.buildForm())),
    );
    await tester.pumpAndSettle();

    final targetEditable = editableOf(target);
    final base = Map<String, int>.from(form.fieldBuilds);
    final baseForm = form.formBuilds;
    expect(base[target], 1);
    expect(baseForm, 1);

    await tester.tap(targetEditable);
    await tester.pump();
    var editable = tester.widget<EditableText>(targetEditable);
    expect(editable.focusNode.hasFocus, isTrue);

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26)));
      await tester.enterText(targetEditable, buffer.toString());
      await tester.pump();
      editable = tester.widget<EditableText>(targetEditable);
      expect(editable.focusNode.hasFocus, isTrue,
          reason: 'focus conservé à la frappe $i (validation active)');
    }

    final typed = buffer.toString();
    expect(typed.length, total);

    // (1) Champ courant reconstruit (borné à la tranche). Au moins 1 par frappe.
    expect(form.fieldBuilds[target]! - base[target]!,
        greaterThanOrEqualTo(total),
        reason: 'le champ courant se reconstruit (au moins) une fois par frappe');

    // (2) TOUT autre champ monté : compteur STRICTEMENT inchangé.
    for (final entry in base.entries) {
      if (entry.key == target) continue;
      expect(form.fieldBuilds[entry.key], entry.value,
          reason: 'voisin ${entry.key} ne doit JAMAIS reconstruire');
    }

    // (3) Niveau formulaire inchangé (0 rebuild global) — malgré la validation.
    expect(form.formBuilds, baseForm,
        reason: 'aucun rebuild global sur frappe, même avec validation active');

    // (4) Focus conservé + (5) valeur valide → AUCUNE erreur affichée.
    editable = tester.widget<EditableText>(targetEditable);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(find.text('REQUIS'), findsNothing);
    expect(find.text('TROP COURT'), findsNothing);

    // (6) Curseur en fin (non réinitialisé), valeur finale = 100 char.
    final textCtrl = editable.controller;
    expect(textCtrl.text, typed);
    expect(textCtrl.selection.baseOffset, total);
    expect(form.controller.valueOf(target), typed);
  });
}
