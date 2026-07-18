import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/showcase/axis_harness.dart';
import 'package:zcrud_example/demos/showcase/showcase_data.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';

import 'support/pump_helpers.dart';

/// Banc **SM-1 falsifiable** (fp-3-1, AC5) sur le formulaire dense de l'axe 1 du
/// harnais. Le compteur `RebuildLog` est GRANULAIRE (un badge scellé sur la
/// tranche de CHAQUE champ) : taper dans un champ ne reconstruit QUE lui.
///
/// **Falsifiabilité (R3)** : le test exige l'INVARIANCE des voisins — il
/// rougirait si un `setState` de niveau formulaire (ou un `Form`/`FormBuilder`
/// global) réintroduisait un rebuild large. Un test qui n'exigerait que
/// `countOf(champ) > 0` serait tautologique.
void main() {
  testWidgets(
      'AC5/SM-1 — 100 caractères ⇒ seul le champ courant rebuild, voisins '
      'inchangés, focus conservé, aucun Form', (tester) async {
    useTallSurface(tester);

    // Formulaire INTENSIF de l'axe 1 (ossature réutilisable — même AxisFormScreen
    // que fp-3-2), instrumenté par un RebuildLog injecté.
    final axis1 = ShowcaseData.axes.firstWhere((a) => a.id == 'axis-1');
    final form = axis1.forms.first;
    final log = RebuildLog();

    await tester.pumpWidget(
      wrapForTest(AxisFormScreen(form: form, rebuildLog: log)),
    );
    await tester.pumpAndSettle();

    // Aucun Form/FormBuilder global (AD-2 / objectif produit n°1).
    expect(find.byType(Form), findsNothing);

    final intensive = form.intensiveFieldName!;
    const neighbor = 'a1Text2';

    final intensiveField = find.descendant(
      of: find.byKey(ValueKey<String>(intensive)),
      matching: find.byType(EditableText),
    );
    final neighborField = find.descendant(
      of: find.byKey(const ValueKey<String>(neighbor)),
      matching: find.byType(EditableText),
    );
    expect(intensiveField, findsOneWidget);
    expect(neighborField, findsOneWidget);

    final baseIntensive = log.countOf(intensive);
    final baseNeighbor = log.countOf(neighbor);

    // Frappe de 100 caractères, un par un.
    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('a');
      await tester.enterText(intensiveField, buffer.toString());
      await tester.pump();
    }

    // (i) Seul le champ courant se reconstruit.
    expect(log.countOf(intensive) - baseIntensive, greaterThanOrEqualTo(100),
        reason: 'Le champ courant doit se reconstruire à chaque frappe');
    // (ii) Le voisin ne bouge JAMAIS (invariance falsifiable — R3).
    expect(log.countOf(neighbor), baseNeighbor,
        reason: 'Un champ voisin ne doit JAMAIS se reconstruire (SM-1)');

    // (iii) Focus et curseur conservés ; contrôleur non recréé.
    final editable = tester.widget<EditableText>(intensiveField);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'Focus perdu');
    expect(editable.controller.text, 'a' * 100);
    expect(editable.controller.selection.baseOffset, 100,
        reason: 'Curseur non conservé en fin de saisie');
  });
}
