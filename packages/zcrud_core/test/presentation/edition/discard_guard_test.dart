// E3-6 — Confirmation d'abandon si dirty (AC9). ZDiscardGuard = PopScope-like,
// seam onConfirmDiscard, aucune dépendance routing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _harness(GlobalKey<NavigatorState> nav) {
  return MaterialApp(
    navigatorKey: nav,
    home: const Scaffold(body: Center(child: Text('home'))),
  );
}

Future<void> _pushGuarded(
  WidgetTester tester,
  GlobalKey<NavigatorState> nav,
  ZFormController c,
  ZConfirmDiscard onConfirm,
) async {
  unawaited(nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: ZDiscardGuard(
          controller: c,
          onConfirmDiscard: onConfirm,
          child: const Center(child: Text('form')),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC9 — non-dirty ⇒ pop immédiat, seam JAMAIS appelé', (tester) async {
    final c = ZFormController(initialValues: <String, Object?>{'a': ''});
    addTearDown(c.dispose);
    final nav = GlobalKey<NavigatorState>();
    var seam = false;

    await tester.pumpWidget(_harness(nav));
    await _pushGuarded(tester, nav, c, () async {
      seam = true;
      return true;
    });
    expect(find.text('form'), findsOneWidget);

    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('form'), findsNothing, reason: 'pop autorisé sans dirty');
    expect(seam, isFalse, reason: 'seam jamais appelé si non-dirty');
  });

  testWidgets('AC9 — dirty : seam=false ⇒ pas de pop ; seam=true ⇒ pop', (tester) async {
    final c = ZFormController(initialValues: <String, Object?>{'a': ''});
    addTearDown(c.dispose);
    final nav = GlobalKey<NavigatorState>();
    var allow = false;
    var seamCalls = 0;

    await tester.pumpWidget(_harness(nav));
    await _pushGuarded(tester, nav, c, () async {
      seamCalls++;
      return allow;
    });

    // Rendre le formulaire dirty ⇒ canPop bascule à false.
    c.setValue('a', 'modifié');
    await tester.pump();

    // Tentative 1 : seam refuse ⇒ pas de pop.
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(seamCalls, 1);
    expect(find.text('form'), findsOneWidget, reason: 'refus ⇒ reste sur le formulaire');

    // Tentative 2 : seam accepte ⇒ pop.
    allow = true;
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(seamCalls, 2);
    expect(find.text('form'), findsNothing, reason: 'accord ⇒ pop effectif');
  });
}
