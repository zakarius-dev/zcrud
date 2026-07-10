// AC7 — EDGE CASE UJ-2 (perte de connexion pendant la saisie).
//
// Pendant une saisie EN COURS (texte partiel), un rebuild EXTERNE de l'ancêtre
// (bascule online→offline via un `ValueListenable<bool>` de connectivité) NE
// doit :
//   - NI recréer/reconstruire le `ZFormController` (identité stable) ;
//   - NI perdre la saisie en cours (`valueOf` + texte affiché préservés) ;
//   - NI recréer l'`Element`/`State`/`TextEditingController` du champ
//     (compteur d'`initState` reste == 1, grâce à `ValueKey(name)`) ;
//   - NI perdre le focus.
//
// Le `ZFormController` est CRÉÉ HORS du sous-arbre reconstruit (détenu par le
// harnais, référence stable) — anti-pattern proscrit : le recréer dans un
// `build`, omettre la `ValueKey`, ou ré-injecter `.text=` au rebuild.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_reference_form.dart';

void main() {
  testWidgets(
      'UJ-2 : rebuild externe (bascule connexion) pendant saisie → controller '
      'identique, saisie préservée, State/TextEditingController non recréés, focus gardé',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    // Signal externe de connectivité, DÉTENU hors du formulaire.
    final connectivity = ValueNotifier<bool>(true);
    addTearDown(connectivity.dispose);

    // L'ancêtre reconstruit son sous-arbre à chaque bascule de connectivité,
    // MAIS le `ZFormController` (form.controller) est stable (jamais recréé).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: connectivity,
            builder: (context, online, child) => Column(
              children: <Widget>[
                // Bannière dépendant de l'état externe : force un vrai rebuild.
                Text(online ? 'EN LIGNE' : 'HORS LIGNE'),
                Expanded(child: form.buildForm()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = fieldName(1, fieldsPerSection ~/ 2);
    final other = fieldName(0, 0);
    final targetEditable = editableOf(target);

    // Référence du controller AVANT + preuve State monté une seule fois.
    final controllerBefore = form.controller;
    expect(form.fieldInits[target], 1, reason: 'State monté une fois');

    // Pré-remplir un autre champ, puis saisie PARTIELLE dans la cible.
    await tester.enterText(editableOf(other), 'AUTRE');
    await tester.pump();

    await tester.tap(targetEditable);
    await tester.pump();
    const partial = '0123456789';
    await tester.enterText(targetEditable, partial);
    await tester.pump();

    var editable = tester.widget<EditableText>(targetEditable);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, partial);

    // ── BASCULE EXTERNE online→offline (simule perte de connexion) ──────────
    connectivity.value = false;
    await tester.pump();

    // Bannière effectivement rebâtie (le sous-arbre ancêtre a bien reconstruit).
    expect(find.text('HORS LIGNE'), findsOneWidget);

    // (1) `ZFormController` : MÊME instance (jamais reconstruit).
    expect(identical(controllerBefore, form.controller), isTrue);

    // (2) Saisie en cours préservée dans le controller.
    expect(form.controller.valueOf(target), partial);
    expect(form.controller.valueOf(other), 'AUTRE');

    // (3) Texte partiel toujours affiché ; autres champs intacts.
    editable = tester.widget<EditableText>(targetEditable);
    expect(editable.controller.text, partial);
    expect(tester.widget<EditableText>(editableOf(other)).controller.text, 'AUTRE');

    // (4) State/TextEditingController NON recréés (initState toujours == 1).
    expect(form.fieldInits[target], 1,
        reason: 'ValueKey(name) → Element/State réutilisés, pas de ré-init');
    expect(form.fieldInits[other], 1);

    // (5) Focus conservé après le rebuild externe.
    expect(editable.focusNode.hasFocus, isTrue);

    // Poursuite de la saisie après reconnexion : curseur cohérent, pas de reset.
    connectivity.value = true;
    await tester.pump();
    await tester.enterText(targetEditable, '${partial}ABC');
    await tester.pump();
    editable = tester.widget<EditableText>(targetEditable);
    expect(editable.controller.text, '${partial}ABC');
    expect(editable.controller.selection.baseOffset, '${partial}ABC'.length);
    expect(form.fieldInits[target], 1, reason: 'toujours pas de ré-init');
  });
}
