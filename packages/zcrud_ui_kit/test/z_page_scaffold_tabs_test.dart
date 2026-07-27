import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  testWidgets('CR-57 — aboveTabViews est rendu entre TabBar et TabBarView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZPageScaffold(
          title: 'T',
          aboveTabViews: const SizedBox(
            height: 40,
            child: Text('BANNIERE_TRANSVERSE'),
          ),
          tabs: <ZPageTab>[
            ZPageTab(label: 'Un', contentBuilder: (_) => const Text('VUE_UN')),
            ZPageTab(
              label: 'Deux',
              contentBuilder: (_) => const Text('VUE_DEUX'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // GARDE MORDANTE : ignorer `aboveTabViews` dans la branche tabs rend cette
    // assertion rouge ; l'ordre mesure bien le slot entre barre et vues.
    final tabBarY = tester.getBottomLeft(find.byType(TabBar)).dy;
    final bannerY = tester.getTopLeft(find.text('BANNIERE_TRANSVERSE')).dy;
    final viewY = tester.getTopLeft(find.text('VUE_UN')).dy;
    expect(bannerY, greaterThanOrEqualTo(tabBarY));
    expect(bannerY, lessThan(viewY));
  });

  // AC9 — tabs rendent le bon contenu ; bascule change le contenu.
  testWidgets('AC9: onglet sélectionné affiche son contenu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    expect(find.text('CONTENU_A'), findsOneWidget);
    expect(find.text('CONTENU_B'), findsNothing);

    await tester.tap(find.text('Deux'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENU_B'), findsOneWidget);
    expect(find.text('CONTENU_A'), findsNothing);
  });

  // AC10 — TabBar scrollable + absent si non fourni.
  testWidgets('AC10: pas de TabBar si tabs null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZPageScaffold(title: 'T', body: const Text('BODY')),
      ),
    );
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('AC10: TabBar scrollable ; 8 onglets sans overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
  });
}
