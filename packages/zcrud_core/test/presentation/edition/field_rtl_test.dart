// AC6a — RTL PAR WIDGET (AD-13) : chaque famille rend correctement sous
// `Directionality(textDirection: rtl)` — aucun overflow, aucune exception, les
// contrôles restent montés. (AC6b — 0 usage non directionnel — est prouvé par
// `style_purity_test.dart`.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '_family_form.dart';

void main() {
  testWidgets('formulaire des 6 familles rendu sous RTL sans overflow (AC6a)',
      (tester) async {
    useTallFamilySurface(tester);
    final controller = familyController();
    addTearDown(controller.dispose);
    controller.setValue('bool', true);
    controller.setValue('sel', 'a');
    controller.setValue('rad', 'b');
    controller.setValue('texte', 'شيء');

    await tester.pumpWidget(familyApp(controller, textDirection: TextDirection.rtl));
    await tester.pumpAndSettle();

    // Aucune exception de layout (overflow ⇒ exception en test).
    expect(tester.takeException(), isNull);

    // La direction ambiante est bien RTL au niveau des champs.
    final dir = Directionality.of(
      tester.element(find.byType(ZTextFieldWidget).first),
    );
    expect(dir, TextDirection.rtl);

    // Chaque famille de base est montée sous RTL.
    expect(find.byType(ZTextFieldWidget), findsWidgets);
    expect(find.byType(ZNumberFieldWidget), findsWidgets);
    expect(find.byType(ZDateFieldWidget), findsWidgets);
    expect(find.byType(ZBooleanFieldWidget), findsWidgets);
    expect(find.byType(ZSelectFieldWidget), findsWidgets);
    expect(find.byType(ZRelationFieldWidget), findsWidgets);
  });

  testWidgets('bascule LTR→RTL sans exception (chaque famille) (AC6a)',
      (tester) async {
    final controller = familyController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(familyApp(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(familyApp(controller, textDirection: TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
