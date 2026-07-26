// CR-52 (lex_douane) — `ZPageScaffold` construit le `Scaffold` mais n'en
// exposait AUCUN slot : ni FAB, ni tiroir, ni barre basse. 8 écrans lex portent
// un FAB, 21 un `Scaffold` non trivial ⇒ le shell leur était INADOPTABLE
// (l'adopter aurait supprimé la navigation).
//
// Ces gardes prouvent, pour les TROIS branches de construction (fixe, sliver
// sans onglets, sliver avec onglets) :
//   1. chaque slot fourni est RENDU et FONCTIONNEL (FAB tapable, tiroir
//      ouvrable, barre/pied/feuille présents, couleur et géométrie appliquées) ;
//   2. chaque slot NON fourni est absent STRUCTURELLEMENT (pas de boîte vide) ;
//   3. le mode sliver+onglets ne DUPLIQUE pas les slots (un seul `Scaffold`,
//      un seul FAB, un seul tiroir) — le `NestedScrollView` n'est pas un
//      `Scaffold` imbriqué.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Les trois branches de construction du shell, nommées pour les rapports.
const _branches = <String, (ZPageAppBarMode, bool)>{
  'fixe': (ZPageAppBarMode.fixed, false),
  'sliver sans onglets': (ZPageAppBarMode.pinned, false),
  'sliver avec onglets': (ZPageAppBarMode.pinned, true),
};

List<ZPageTab> _tabs() => <ZPageTab>[
      ZPageTab(label: 'A', contentBuilder: (_) => const Text('CONTENU_A')),
      ZPageTab(label: 'B', contentBuilder: (_) => const Text('CONTENU_B')),
    ];

Widget _host({
  required ZPageAppBarMode mode,
  required bool withTabs,
  Widget? floatingActionButton,
  FloatingActionButtonLocation? floatingActionButtonLocation,
  List<Widget>? persistentFooterButtons,
  Widget? drawer,
  Widget? endDrawer,
  Widget? bottomNavigationBar,
  Widget? bottomSheet,
  Color? backgroundColor,
  bool? resizeToAvoidBottomInset,
  bool extendBody = false,
  Widget? body,
}) =>
    MaterialApp(
      home: ZPageScaffold(
        title: 'TITRE',
        mode: mode,
        tabs: withTabs ? _tabs() : null,
        body: withTabs ? null : body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        persistentFooterButtons: persistentFooterButtons,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
      ),
    );

Scaffold _scaffoldOf(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold));

void main() {
  group('CR-52 — slots fournis : rendus et fonctionnels', () {
    _branches.forEach((nom, cas) {
      final (mode, withTabs) = cas;

      testWidgets('[$nom] le FAB est rendu ET tapable', (tester) async {
        var taps = 0;
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          floatingActionButton: FloatingActionButton(
            onPressed: () => taps++,
            child: const Icon(Icons.add),
          ),
        ));

        expect(find.byType(FloatingActionButton), findsOneWidget,
            reason: 'le FAB déclaré doit atteindre le Scaffold du shell');
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(taps, 1, reason: 'le FAB doit être réellement actionnable');
      });

      testWidgets('[$nom] le tiroir est rendu ET ouvrable', (tester) async {
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          drawer: const Drawer(child: Text('TIROIR')),
        ));

        final state = tester.state<ScaffoldState>(find.byType(Scaffold));
        expect(state.hasDrawer, isTrue);
        expect(find.text('TIROIR'), findsNothing,
            reason: 'un tiroir fermé ne doit pas être affiché');
        state.openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('TIROIR'), findsOneWidget,
            reason: 'le tiroir doit s\'ouvrir sur le Scaffold du shell');
      });

      testWidgets('[$nom] le tiroir de fin est rendu ET ouvrable',
          (tester) async {
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          endDrawer: const Drawer(child: Text('TIROIR_FIN')),
        ));

        final state = tester.state<ScaffoldState>(find.byType(Scaffold));
        expect(state.hasEndDrawer, isTrue);
        state.openEndDrawer();
        await tester.pumpAndSettle();
        expect(find.text('TIROIR_FIN'), findsOneWidget);
      });

      testWidgets('[$nom] barre basse / pied persistant / feuille rendus',
          (tester) async {
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          bottomNavigationBar: const SizedBox(height: 56, child: Text('BARRE')),
          persistentFooterButtons: const <Widget>[Text('PIED')],
          bottomSheet: const SizedBox(height: 40, child: Text('FEUILLE')),
        ));

        expect(find.text('BARRE'), findsOneWidget);
        expect(find.text('PIED'), findsOneWidget);
        expect(find.text('FEUILLE'), findsOneWidget);
      });

      testWidgets('[$nom] couleur de fond / insets / extendBody transmis',
          (tester) async {
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          backgroundColor: const Color(0xFF123456),
          resizeToAvoidBottomInset: false,
          extendBody: true,
        ));

        final scaffold = _scaffoldOf(tester);
        expect(scaffold.backgroundColor, const Color(0xFF123456));
        expect(scaffold.resizeToAvoidBottomInset, isFalse);
        expect(scaffold.extendBody, isTrue);
      });

      testWidgets('[$nom] la position du FAB est réellement appliquée',
          (tester) async {
        Future<double> centerX(FloatingActionButtonLocation? loc) async {
          await tester.pumpWidget(_host(
            mode: mode,
            withTabs: withTabs,
            floatingActionButtonLocation: loc,
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ));
          await tester.pumpAndSettle();
          return tester.getCenter(find.byType(FloatingActionButton)).dx;
        }

        final parDefaut = await centerX(null);
        final auDebut = await centerX(FloatingActionButtonLocation.startFloat);
        expect(auDebut, lessThan(parDefaut),
            reason: 'startFloat doit déplacer le FAB vers le début (LTR) — '
                'sinon la position déclarée est ignorée');
      });
    });
  });

  group('CR-52 — slots non fournis : absence STRUCTURELLE', () {
    _branches.forEach((nom, cas) {
      final (mode, withTabs) = cas;

      testWidgets('[$nom] aucun slot déclaré ⇒ aucun slot construit',
          (tester) async {
        await tester.pumpWidget(_host(mode: mode, withTabs: withTabs));

        final scaffold = _scaffoldOf(tester);
        expect(scaffold.floatingActionButton, isNull);
        expect(scaffold.floatingActionButtonLocation, isNull);
        expect(scaffold.persistentFooterButtons, isNull);
        expect(scaffold.drawer, isNull);
        expect(scaffold.endDrawer, isNull);
        expect(scaffold.bottomNavigationBar, isNull);
        expect(scaffold.bottomSheet, isNull);
        expect(scaffold.backgroundColor, isNull);
        expect(scaffold.resizeToAvoidBottomInset, isNull);
        expect(scaffold.extendBody, isFalse);
        expect(scaffold.extendBodyBehindAppBar, isFalse);

        // Absence dans l'ARBRE, pas seulement dans la déclaration.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.byType(Drawer), findsNothing);
        final state = tester.state<ScaffoldState>(find.byType(Scaffold));
        expect(state.hasDrawer, isFalse);
        expect(state.hasEndDrawer, isFalse);
      });
    });

    testWidgets('[fixe] corps non fourni ⇒ `Scaffold.body` NUL (pas de boîte '
        'vide)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ZPageScaffold(title: 'TITRE')),
      );
      expect(_scaffoldOf(tester).body, isNull,
          reason: 'un corps non déclaré doit être structurellement absent');
    });

    testWidgets('[sliver] corps non fourni ⇒ aucun sliver de contenu',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZPageScaffold(title: 'TITRE', mode: ZPageAppBarMode.pinned),
        ),
      );
      // ⚠️ `skipOffstage: false` est REQUIS : un sliver d'extension nulle est
      // « offstage » pour le finder par défaut, qui déclarerait donc absente
      // une boîte vide bel et bien construite (garde non mordante).
      expect(find.byType(SliverToBoxAdapter, skipOffstage: false), findsNothing,
          reason: 'aucun SizedBox.shrink inerte ne doit être emballé');
      final scrollView =
          tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(scrollView.slivers.whereType<SliverToBoxAdapter>(), isEmpty);
      expect(scrollView.slivers.length, 1,
          reason: 'seule l\'app-bar doit être déclarée');
    });

    testWidgets('[sliver] corps fourni ⇒ le sliver de contenu EST déclaré',
        (tester) async {
      await tester.pumpWidget(_host(
        mode: ZPageAppBarMode.pinned,
        withTabs: false,
        body: const Text('CORPS'),
      ));
      final scrollView =
          tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(scrollView.slivers.length, 2);
      expect(find.text('CORPS'), findsOneWidget);
    });
  });

  group('CR-52 — un seul `Scaffold` porteur : aucune duplication', () {
    _branches.forEach((nom, cas) {
      final (mode, withTabs) = cas;

      testWidgets('[$nom] les slots ne sont portés qu\'UNE fois',
          (tester) async {
        await tester.pumpWidget(_host(
          mode: mode,
          withTabs: withTabs,
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          drawer: const Drawer(child: Text('TIROIR')),
          bottomNavigationBar: const SizedBox(height: 56, child: Text('BARRE')),
        ));

        expect(find.byType(Scaffold), findsOneWidget,
            reason: 'le shell ne doit construire QU\'UN Scaffold');
        expect(find.byType(FloatingActionButton), findsOneWidget,
            reason: 'un FAB dupliqué serait un bouton fantôme');
        expect(find.text('BARRE'), findsOneWidget);

        tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget,
            reason: 'un tiroir dupliqué ouvrirait deux panneaux');
      });
    });

    testWidgets('[sliver avec onglets] le NestedScrollView cohabite avec les '
        'slots sans les absorber', (tester) async {
      await tester.pumpWidget(_host(
        mode: ZPageAppBarMode.pinned,
        withTabs: true,
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ));

      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
      // Le FAB est HORS de la zone défilante : il survit au défilement.
      await tester.drag(find.text('CONTENU_A'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  // Le rendu par défaut est INCHANGÉ : les slots sont additifs et optionnels.
  group('CR-52 — non-régression du rendu par défaut', () {
    testWidgets('fixe : app-bar + titre + corps, sans slot', (tester) async {
      await tester.pumpWidget(_host(
        mode: ZPageAppBarMode.fixed,
        withTabs: false,
        body: const Text('CORPS'),
      ));
      expect(find.byType(ZSearchableAppBar), findsOneWidget);
      expect(find.text('TITRE'), findsOneWidget);
      expect(find.text('CORPS'), findsOneWidget);
      expect(find.byType(SliverAppBar), findsNothing);
    });

    testWidgets('sliver : SliverAppBar + corps, sans slot', (tester) async {
      await tester.pumpWidget(_host(
        mode: ZPageAppBarMode.pinned,
        withTabs: false,
        body: const Text('CORPS'),
      ));
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('TITRE'), findsOneWidget);
      expect(find.text('CORPS'), findsOneWidget);
    });
  });
}
