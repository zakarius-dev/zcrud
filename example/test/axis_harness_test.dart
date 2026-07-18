import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/showcase/axis_harness.dart';
import 'package:zcrud_example/demos/showcase/showcase_data.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC6/AC5 — OSSATURE : fp-3-2 bascule les axes 2/3/4 de `upcoming` à `mvp` ⇒
  // les 6 axes sont MVP, chacun peuplé (aucun axe « à venir » ne subsiste).
  test('AC5 — ossature : 6 axes MVP peuplés, aucun à venir, ≥ 6 formulaires', () {
    final mvp =
        ShowcaseData.axes.where((a) => a.status == AxisStatus.mvp).toList();
    final upcoming = ShowcaseData.axes
        .where((a) => a.status == AxisStatus.upcoming)
        .toList();

    // Les 6 axes sont MVP, chacun avec au moins un formulaire.
    expect(mvp.map((a) => a.id).toSet(),
        <String>{'axis-1', 'axis-2', 'axis-3', 'axis-4', 'axis-5', 'axis-6'});
    for (final a in mvp) {
      expect(a.forms, isNotEmpty, reason: '${a.id} MVP doit être peuplé');
    }
    // Plus aucun axe « à venir ».
    expect(upcoming, isEmpty);

    // ≥ 6 formulaires répliqués (dont les 6 DODLP).
    final totalForms =
        ShowcaseData.axes.fold<int>(0, (n, a) => n + a.forms.length);
    expect(totalForms, greaterThanOrEqualTo(6));

    // Le banc SM-1 est porté par un formulaire intensif (axe 1).
    final axis1 = ShowcaseData.axes.firstWhere((a) => a.id == 'axis-1');
    expect(axis1.forms.first.intensiveFieldName, isNotNull);
  });

  // AC6 — le harnais rend les 6 axes MVP navigables (aucun « à venir »).
  testWidgets('AC5 — harnais : 6 axes MVP navigables, aucun à venir',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTest(const AxisHarnessScreen(axes: ShowcaseData.axes)),
    );
    await tester.pumpAndSettle();

    // 6 chips « MVP », aucun « à venir ».
    expect(find.widgetWithText(Chip, 'MVP'), findsNWidgets(6));
    expect(find.widgetWithText(Chip, 'à venir'), findsNothing);

    // Un formulaire MVP (axe 1, sans satellite) est navigable → AxisFormScreen.
    final tile = find.byKey(const ValueKey<String>('axis-form-axis1-dense'));
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AxisFormScreen), findsOneWidget);
  });
}
