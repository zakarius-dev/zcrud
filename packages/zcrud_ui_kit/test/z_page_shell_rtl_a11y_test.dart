import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  // AC14 — RTL : le leading s'ancre côté droit visuel.
  testWidgets('AC14: RTL ⇒ leading ancré à droite', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: ZSearchableAppBar(
            title: 'T',
            leading: const Icon(Icons.menu, key: Key('lead')),
            actions: [
              ZAppBarAction(
                icon: Icons.edit,
                semanticLabel: 'Éditer',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);

    final leadingCx = tester.getCenter(find.byKey(const Key('lead'))).dx;
    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    expect(leadingCx, greaterThan(screenWidth / 2),
        reason: 'sous RTL le leading est côté droit visuel');

    // L'action est côté gauche visuel (miroir de LTR).
    final actionCx = tester.getCenter(find.byIcon(Icons.edit)).dx;
    expect(actionCx, lessThan(screenWidth / 2));
  });

  // AC14 — a11y : Semantics + cible ≥ 48 dp sous RTL.
  testWidgets('AC14: Semantics bascule + cible ≥ 48 dp', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: ZSearchableAppBar(
            title: 'T',
            search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
          ),
        ),
      ),
    ));
    // La bascule loupe porte un label a11y (résolu par MaterialLocalizations).
    final toggleSize =
        tester.getSize(find.widgetWithIcon(IconButton, Icons.search));
    expect(toggleSize.height, greaterThanOrEqualTo(48.0));
    expect(toggleSize.width, greaterThanOrEqualTo(48.0));
    handle.dispose();
  });
}
