// AC5 — A11y PAR WIDGET (AD-13/FR-23) : sur un formulaire couvrant les 6
// familles de base, (a) toutes les cibles tactiles interactives respectent
// `androidTapTargetGuideline` (≥ 48 dp) ; (b) des libellés sémantiques sont
// présents (libellé de champ + état pour booléen/select).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_family_form.dart';

void main() {
  testWidgets('cibles tactiles ≥ 48 dp sur les contrôles interactifs (AC5)',
      (tester) async {
    useTallFamilySurface(tester);
    final handle = tester.ensureSemantics();
    final controller = familyController();
    addTearDown(controller.dispose);
    // Pré-remplir le booléen (état sémantique testable) + une sélection.
    controller.setValue('bool', true);
    controller.setValue('sel', 'a');

    await tester.pumpWidget(familyApp(controller));
    await tester.pumpAndSettle();

    // (a) Guideline de taille de cible tactile Android (≥ 48 dp).
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    // Guideline de contraste de texte du thème.
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets('libellés + état sémantiques (booléen switch, select) (AC5)',
      (tester) async {
    useTallFamilySurface(tester);
    final handle = tester.ensureSemantics();
    final controller = familyController();
    addTearDown(controller.dispose);
    controller.setValue('bool', true);

    await tester.pumpWidget(familyApp(controller));
    await tester.pumpAndSettle();

    // Libellé de champ présent (texte).
    expect(find.text('Texte'), findsWidgets);

    // Le booléen expose un rôle `switch` COCHÉ (état sémantique — AC5).
    final toggled = find.byWidgetPredicate((w) {
      if (w is! Semantics) return false;
      final p = w.properties;
      return p.toggled == true;
    });
    expect(toggled, findsWidgets,
        reason: 'le switch booléen expose son état coché (Semantics.toggled)');

    // Le libellé du booléen est rendu (fusionné dans le ListTile).
    expect(find.text('Actif'), findsWidgets);

    handle.dispose();
  });
}
