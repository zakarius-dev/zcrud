// CR-52 — voie « ne pas posséder le `Scaffold` » : [ZPageShellBody] apporte la
// valeur du shell (app-bar morphante repliable + onglets) SANS construire de
// `Scaffold`. L'hôte garde le sien, donc TOUS ses slots — présents et futurs.
//
// Gardes : (1) aucun `Scaffold` construit par le widget ; (2) les slots de
// l'hôte restent fonctionnels autour de lui (FAB tapable, tiroir ouvrable) ;
// (3) la recherche est détenue par le widget (AD-2) ; (4) un corps non fourni
// est structurellement absent ; (5) `fixed` se replie sur `pinned` sans lever.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

List<ZPageTab> _tabs() => <ZPageTab>[
      ZPageTab(label: 'A', contentBuilder: (_) => const Text('CONTENU_A')),
      ZPageTab(label: 'B', contentBuilder: (_) => const Text('CONTENU_B')),
    ];

/// Hôte réaliste : c'est LUI qui possède le `Scaffold` et ses slots.
Widget _hostScaffold({
  required Widget shellBody,
  Widget? floatingActionButton,
  Widget? drawer,
  Widget? bottomNavigationBar,
}) =>
    MaterialApp(
      home: Scaffold(
        floatingActionButton: floatingActionButton,
        drawer: drawer,
        bottomNavigationBar: bottomNavigationBar,
        body: shellBody,
      ),
    );

void main() {
  testWidgets('ZPageShellBody ne construit AUCUN `Scaffold`', (tester) async {
    await tester.pumpWidget(
      _hostScaffold(
        shellBody: const ZPageShellBody(
          title: 'TITRE',
          body: Text('CORPS'),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget,
        reason: 'le seul Scaffold de l\'arbre doit être celui de l\'HÔTE');
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('TITRE'), findsOneWidget);
    expect(find.text('CORPS'), findsOneWidget);
  });

  testWidgets('les slots de l\'HÔTE restent fonctionnels autour du shell',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _hostScaffold(
        shellBody: const ZPageShellBody(
          title: 'TITRE',
          body: SizedBox(height: 1200, child: Text('CORPS')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => taps++,
          child: const Icon(Icons.add),
        ),
        drawer: const Drawer(child: Text('TIROIR')),
        bottomNavigationBar: const SizedBox(height: 56, child: Text('BARRE')),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('BARRE'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('TIROIR'), findsOneWidget);
  });

  testWidgets('onglets : NestedScrollView + bascule de contenu', (tester) async {
    await tester.pumpWidget(
      _hostScaffold(
        shellBody: ZPageShellBody(title: 'TITRE', tabs: _tabs()),
      ),
    );

    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.text('CONTENU_A'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENU_B'), findsOneWidget);
  });

  testWidgets('la recherche est DÉTENUE par le widget (aucun contrôleur '
      'externe)', (tester) async {
    final recu = <String>[];
    await tester.pumpWidget(
      _hostScaffold(
        shellBody: ZPageShellBody(
          title: 'TITRE',
          search: ZAppBarSearchConfig(onQueryChanged: recu.add),
          body: const Text('CORPS'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    expect(recu, <String>['abc']);
  });

  testWidgets('corps non fourni ⇒ aucun sliver de contenu (absence '
      'structurelle)', (tester) async {
    await tester.pumpWidget(
      _hostScaffold(shellBody: const ZPageShellBody(title: 'TITRE')),
    );
    // `skipOffstage: false` obligatoire : un sliver d'extension nulle est
    // « offstage » et échapperait au finder par défaut (garde non mordante).
    expect(find.byType(SliverToBoxAdapter, skipOffstage: false), findsNothing);
    final scrollView =
        tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(scrollView.slivers.length, 1,
        reason: 'seule l\'app-bar doit être déclarée');
  });

  testWidgets('mode `fixed` ⇒ repli sur `pinned`, jamais de throw',
      (tester) async {
    await tester.pumpWidget(
      _hostScaffold(
        shellBody: const ZPageShellBody(
          title: 'TITRE',
          mode: ZPageAppBarMode.fixed,
          body: SizedBox(height: 1200, child: Text('CORPS')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.pinned, isTrue,
        reason: '`fixed` dans un corps défilant doit rester visible en tête');
    expect(bar.floating, isFalse);

    // Repli fidèle : l'app-bar ne quitte pas le champ au défilement.
    await tester.drag(find.text('CORPS'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('TITRE'), findsOneWidget);
  });

  testWidgets('modes sliver : floating/pinned transmis tels quels',
      (tester) async {
    for (final (mode, floating, pinned) in <(ZPageAppBarMode, bool, bool)>[
      (ZPageAppBarMode.floating, true, false),
      (ZPageAppBarMode.pinned, false, true),
      (ZPageAppBarMode.floatingPinned, true, true),
    ]) {
      await tester.pumpWidget(
        _hostScaffold(
          shellBody: ZPageShellBody(
            title: 'TITRE',
            mode: mode,
            body: const SizedBox(height: 1200, child: Text('CORPS')),
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.floating, floating, reason: 'mode $mode');
      expect(bar.pinned, pinned, reason: 'mode $mode');
    }
  });
}
