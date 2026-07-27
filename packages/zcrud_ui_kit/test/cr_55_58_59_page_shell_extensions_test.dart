import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  testWidgets('CR-55 — la config peut masquer les actions hôte en recherche', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZPageScaffold(
          title: 'Titre',
          actions: <ZAppBarAction>[
            ZAppBarAction(icon: Icons.settings, semanticLabel: 'ACTION_HOTE'),
          ],
          search: ZAppBarSearchConfig(
            onQueryChanged: (_) {},
            hidesHostActions: true,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('ACTION_HOTE'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // GARDE MORDANTE : supprimer la condition sur `hidesHostActions` laisse
    // l'action dans l'arbre et fait rougir cette absence structurelle.
    expect(
      find.bySemanticsLabel('ACTION_HOTE', skipOffstage: false),
      findsNothing,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('CR-58 — une action widget est rendue, accessible et tapable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ZPageScaffold(
          title: 'Titre',
          actions: <ZAppBarAction>[
            ZAppBarAction.widget(
              semanticLabel: 'PROFIL',
              onPressed: () => taps++,
              child: const CircleAvatar(child: Text('ZD')),
            ),
          ],
        ),
      ),
    );

    // GARDE MORDANTE : rétablir `Icon(action.icon)` ne peut ni exprimer ni
    // rendre `CircleAvatar`; ce marqueur disparaît et le test est rouge.
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.bySemanticsLabel('PROFIL'), findsOneWidget);
    await tester.tap(find.byType(CircleAvatar));
    expect(taps, 1);
  });

  testWidgets('CR-59 — tabAlignment est transmis au TabBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZPageScaffold(
          title: 'Titre',
          tabAlignment: TabAlignment.start,
          tabs: <ZPageTab>[
            ZPageTab(label: 'Un', contentBuilder: (_) => const SizedBox()),
            ZPageTab(label: 'Deux', contentBuilder: (_) => const SizedBox()),
          ],
        ),
      ),
    );

    // GARDE MORDANTE : ne pas transmettre le paramètre laisse `null` ici.
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).tabAlignment,
      TabAlignment.start,
    );
  });
}
