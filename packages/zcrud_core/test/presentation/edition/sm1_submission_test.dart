// E3-6 — SM-1 re-prouvé sur la voie de soumission/dirty/reseed (AC14) : taper
// 100 caractères ne reconstruit QUE le champ courant ; 0 build voisin, 0 build
// du chrome de soumission (bouton + bannière dirty au-delà du flip unique) ;
// focus + curseur conservés ; Form findsNothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '_reference_form.dart';

void main() {
  testWidgets('AC14 — 100 frappes : 0 build voisin / 0 build chrome soumission, focus+curseur conservés',
      (tester) async {
    useTallSurface(tester);
    final form = ReferenceForm();
    addTearDown(form.dispose);

    final submit = ZEditionSubmitController<Unit>(
      controller: form.controller,
      fields: form.fields,
      onSubmit: (values) async => Right<ZFailure, Unit>(unit),
    );
    addTearDown(submit.dispose);

    var stateNotifs = 0;
    submit.state.addListener(() => stateNotifs++);
    var dirtyBuilds = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(child: form.buildForm()),
            // Bannière dirty : n'écoute QUE le canal dédié.
            ValueListenableBuilder<bool>(
              valueListenable: form.controller.isDirty,
              builder: (context, dirty, _) {
                dirtyBuilds++;
                return Text(dirty ? 'dirty' : 'clean');
              },
            ),
            ZSubmitButton<Unit>(controller: submit, label: 'Enregistrer'),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final target = fieldName(0, 0);
    final neighbour = fieldName(0, 1);
    final neighbourBuilds0 = form.fieldBuilds[neighbour] ?? 0;
    final formBuilds0 = form.formBuilds;
    final dirtyBuilds0 = dirtyBuilds;

    await tester.tap(editableOf(target));
    await tester.pump();

    // 100 frappes incrémentales.
    var text = '';
    for (var i = 0; i < 100; i++) {
      text += 'a';
      await tester.enterText(editableOf(target), text);
      await tester.pump();
    }

    // Voisin JAMAIS reconstruit.
    expect(form.fieldBuilds[neighbour] ?? 0, neighbourBuilds0,
        reason: 'aucun rebuild voisin sur la frappe (SM-1)');
    // Formulaire (chrome structurel) inchangé.
    expect(form.formBuilds, formBuilds0);
    // Chrome de soumission : l'état ne bouge pas ⇒ 0 notification / rebuild bouton.
    expect(stateNotifs, 0, reason: 'la frappe ne touche pas l’état de soumission');
    // Bannière dirty : au plus UN rebuild (flip unique au 1er écart).
    expect(dirtyBuilds - dirtyBuilds0, lessThanOrEqualTo(1));
    expect(form.controller.isDirty.value, isTrue);

    // Focus + curseur (fin) conservés.
    final editable = tester.widget<EditableText>(editableOf(target));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, text);
    expect(editable.controller.selection.baseOffset, text.length);

    // Aucun Form/FormBuilder global sur toute la surface.
    expect(find.byType(Form), findsNothing);
  });
}
