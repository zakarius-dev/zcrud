import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  // AC9 — tabs rendent le bon contenu ; bascule change le contenu.
  testWidgets('AC9: onglet sélectionné affiche son contenu', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ZPageScaffold(
        title: 'T',
        tabs: [
          ZPageTab(
            label: 'Un',
            contentBuilder: (_) => const Text('CONTENU_A'),
          ),
          ZPageTab(
            label: 'Deux',
            contentBuilder: (_) => const Text('CONTENU_B'),
          ),
        ],
      ),
    ));
    expect(find.text('CONTENU_A'), findsOneWidget);
    expect(find.text('CONTENU_B'), findsNothing);

    await tester.tap(find.text('Deux'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENU_B'), findsOneWidget);
    expect(find.text('CONTENU_A'), findsNothing);
  });

  // AC10 — TabBar scrollable + absent si non fourni.
  testWidgets('AC10: pas de TabBar si tabs null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ZPageScaffold(
        title: 'T',
        body: const Text('BODY'),
      ),
    ));
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('AC10: TabBar scrollable ; 8 onglets sans overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ZPageScaffold(
        title: 'T',
        tabs: [
          for (var i = 0; i < 8; i++)
            ZPageTab(
              label: 'Onglet numéro $i',
              contentBuilder: (_) => Text('C$i'),
            ),
        ],
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
  });
}
