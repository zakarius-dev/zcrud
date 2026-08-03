import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// CR-IFFD-45 — créneau `aboveTabBar` entre l'app-bar et la barre d'onglets.
///
/// 🔴 Ces gardes mesurent la **GÉOMÉTRIE**, jamais la présence. Une garde
/// « le créneau est dans l'arbre » resterait VERTE avec le chevauchement de
/// 10 dp mesuré sur la voie `subtitle` — c'est précisément le défaut à empêcher.
/// On assert donc : (1) l'app-bar **grandit** de la hauteur déclarée, (2) le
/// **bord bas** du créneau est au-dessus du **bord haut** du `TabBar`, (3) rien
/// ne sort de l'écran par le haut.

const Key _slotKey = Key('CR45_SLOT');
const Key _subtitleKey = Key('CR45_SUBTITLE');

/// Taille d'écran des mesures de la CR (500×800).
const Size _screen = Size(500, 800);

List<ZPageTab> _tabs() => <ZPageTab>[
  ZPageTab(label: 'Un', contentBuilder: (_) => const Text('VUE_UN')),
  ZPageTab(label: 'Deux', contentBuilder: (_) => const Text('VUE_DEUX')),
  ZPageTab(label: 'Trois', contentBuilder: (_) => const Text('VUE_TROIS')),
];

Widget _fixedHost({
  Widget? aboveTabBar,
  double? aboveTabBarHeight,
  Widget? subtitle,
  bool withTabs = true,
}) => MaterialApp(
  home: ZPageScaffold(
    title: 'TITRE',
    subtitle: subtitle,
    aboveTabBar: aboveTabBar,
    aboveTabBarHeight: aboveTabBarHeight,
    tabs: withTabs ? _tabs() : null,
    body: withTabs ? null : const Text('BODY'),
  ),
);

Widget _sliverHost({
  required ZPageAppBarMode mode,
  Widget? aboveTabBar,
  double? aboveTabBarHeight,
}) => MaterialApp(
  home: ZPageScaffold(
    title: 'TITRE',
    mode: mode,
    aboveTabBar: aboveTabBar,
    aboveTabBarHeight: aboveTabBarHeight,
    body: const SizedBox(height: 2000, child: Text('LONG_BODY')),
  ),
);

Future<void> _setScreen(WidgetTester tester) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

double _appBarHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AppBar)).height;

void main() {
  // ---------------------------------------------------------------------------
  // 1. NEUTRALITÉ STRICTE — `aboveTabBar` nul ⇒ arbre inchangé.
  // ---------------------------------------------------------------------------

  testWidgets(
    'CR-IFFD-45 — neutralité (mode fixe) : sans créneau, le bottom: reste le '
    'TabBar nu ; sans onglets il reste null',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(_fixedHost());
      await tester.pumpAndSettle();

      final ZSearchableAppBar bar = tester.widget<ZSearchableAppBar>(
        find.byType(ZSearchableAppBar),
      );
      // GARDE MORDANTE : envelopper inconditionnellement le bottom dans une
      // `PreferredSize` (wrapper inerte) rend cette assertion ROUGE.
      expect(
        bar.bottom,
        isA<TabBar>(),
        reason: 'sans aboveTabBar, le bottom: doit être le TabBar LUI-MÊME',
      );
      expect(find.byType(PreferredSize), findsNothing);

      await tester.pumpWidget(_fixedHost(withTabs: false));
      await tester.pumpAndSettle();
      final ZSearchableAppBar bare = tester.widget<ZSearchableAppBar>(
        find.byType(ZSearchableAppBar),
      );
      expect(bare.bottom, isNull);
      expect(find.byType(PreferredSize), findsNothing);
    },
  );

  testWidgets(
    'CR-IFFD-45 — neutralité (mode sliver) : sans créneau, le bottom: de la '
    'SliverAppBar reste le TabBar nu / null',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ZPageShellBody(
            title: 'TITRE',
            tabs: _tabs(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).bottom,
        isA<TabBar>(),
      );

      await tester.pumpWidget(
        _sliverHost(mode: ZPageAppBarMode.pinned),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).bottom,
        isNull,
      );
    },
  );

  // ---------------------------------------------------------------------------
  // 2. GÉOMÉTRIE — l'app-bar grandit, ZÉRO chevauchement du TabBar.
  // ---------------------------------------------------------------------------

  testWidgets(
    'CR-IFFD-45 — 48 dp : l\'app-bar grandit de 48 et le créneau est '
    'ENTIÈREMENT au-dessus du TabBar',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(_fixedHost());
      await tester.pumpAndSettle();
      final double baseline = _appBarHeight(tester);
      final double tabBarHeight = tester.getSize(find.byType(TabBar)).height;

      await tester.pumpWidget(
        _fixedHost(
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
          aboveTabBarHeight: 48,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // (1) L'app-bar GRANDIT réellement de la hauteur déclarée.
      expect(
        _appBarHeight(tester),
        closeTo(baseline + 48, 0.5),
        reason: 'l\'app-bar doit croître de la hauteur du créneau',
      );

      final Rect slot = tester.getRect(find.byKey(_slotKey));
      final Rect tabBar = tester.getRect(find.byType(TabBar));
      final Rect appBar = tester.getRect(find.byType(AppBar));

      // (2) Hauteur RÉELLE du créneau = hauteur DÉCLARÉE.
      expect(slot.height, closeTo(48, 0.5));
      // (3) ZÉRO chevauchement : bord bas du créneau ≤ bord haut du TabBar.
      expect(
        slot.bottom,
        lessThanOrEqualTo(tabBar.top + 0.5),
        reason: 'le créneau ne doit JAMAIS recouvrir le TabBar',
      );
      // (4) Le TabBar garde sa hauteur et reste DANS l'app-bar.
      expect(tabBar.height, closeTo(tabBarHeight, 0.5));
      expect(tabBar.bottom, lessThanOrEqualTo(appBar.bottom + 0.5));
      // (5) Rien ne sort par le haut.
      expect(slot.top, greaterThanOrEqualTo(-0.5));
      // (6) Largeur pleine préservée pour le TabBar (CrossAxisAlignment.stretch).
      expect(tabBar.width, closeTo(_screen.width, 0.5));
    },
  );

  testWidgets(
    'CR-IFFD-45 — 96 dp : aucune sortie d\'écran, aucun chevauchement '
    '(le cas qui DÉBORDAIT via subtitle)',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(_fixedHost());
      await tester.pumpAndSettle();
      final double baseline = _appBarHeight(tester);

      await tester.pumpWidget(
        _fixedHost(
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
          aboveTabBarHeight: 96,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(_appBarHeight(tester), closeTo(baseline + 96, 0.5));
      final Rect slot = tester.getRect(find.byKey(_slotKey));
      final Rect tabBar = tester.getRect(find.byType(TabBar));
      expect(slot.height, closeTo(96, 0.5));
      expect(
        slot.top,
        greaterThanOrEqualTo(-0.5),
        reason: '96 dp ne doit PAS déborder hors de l\'écran par le haut',
      );
      expect(slot.bottom, lessThanOrEqualTo(tabBar.top + 0.5));
      expect(tabBar.bottom, lessThanOrEqualTo(_appBarHeight(tester) + 0.5));
    },
  );

  testWidgets(
    'CR-IFFD-45 — hauteur par défaut : PreferredSizeWidget ⇒ sa preferredSize, '
    'sinon kToolbarHeight',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(_fixedHost());
      await tester.pumpAndSettle();
      final double baseline = _appBarHeight(tester);

      // Widget quelconque, aucune hauteur déclarée ⇒ kToolbarHeight.
      await tester.pumpWidget(
        _fixedHost(
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
        ),
      );
      await tester.pumpAndSettle();
      expect(_appBarHeight(tester), closeTo(baseline + kToolbarHeight, 0.5));
      expect(
        tester.getRect(find.byKey(_slotKey)).height,
        closeTo(kToolbarHeight, 0.5),
      );

      // `PreferredSizeWidget` ⇒ c'est LUI qui déclare sa hauteur.
      await tester.pumpWidget(
        _fixedHost(
          aboveTabBar: const PreferredSize(
            preferredSize: Size.fromHeight(72),
            child: Center(key: _slotKey, child: Text('CONTEXTE')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_appBarHeight(tester), closeTo(baseline + 72, 0.5));
      expect(tester.getRect(find.byKey(_slotKey)).height, closeTo(72, 0.5));
    },
  );

  testWidgets(
    'CR-IFFD-45 — sans onglets, le créneau devient à lui seul le bottom: de '
    'l\'app-bar',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(_fixedHost(withTabs: false));
      await tester.pumpAndSettle();
      final double baseline = _appBarHeight(tester);
      expect(find.byType(TabBar), findsNothing);

      await tester.pumpWidget(
        _fixedHost(
          withTabs: false,
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
          aboveTabBarHeight: 60,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TabBar), findsNothing);
      expect(_appBarHeight(tester), closeTo(baseline + 60, 0.5));

      final Rect slot = tester.getRect(find.byKey(_slotKey));
      final Rect appBar = tester.getRect(find.byType(AppBar));
      expect(slot.height, closeTo(60, 0.5));
      // Le créneau occupe le BAS de l'app-bar (le bottom:), pas la toolbar.
      expect(slot.bottom, closeTo(appBar.bottom, 0.5));
      // Le corps commence SOUS l'app-bar agrandie (aucun recouvrement).
      expect(
        tester.getTopLeft(find.text('BODY')).dy,
        greaterThanOrEqualTo(appBar.bottom - 0.5),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // 3. MODE SLIVER — pinned garde la surface visible, floating la replie.
  // ---------------------------------------------------------------------------

  testWidgets('CR-IFFD-45 — sliver pinned : le créneau reste visible au scroll', (
    tester,
  ) async {
    await _setScreen(tester);
    await tester.pumpWidget(
      _sliverHost(
        mode: ZPageAppBarMode.pinned,
        aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
        aboveTabBarHeight: 48,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final Rect before = tester.getRect(find.byKey(_slotKey));
    expect(before.height, closeTo(48, 0.5));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(
      find.byKey(_slotKey),
      findsOneWidget,
      reason: 'pinned ⇒ le bottom: de la SliverAppBar reste épinglé',
    );
    final Rect after = tester.getRect(find.byKey(_slotKey));
    expect(after.top, closeTo(before.top, 0.5));
    expect(after.height, closeTo(48, 0.5));
    // Toujours DANS l'écran.
    expect(after.top, greaterThanOrEqualTo(-0.5));
    expect(after.bottom, lessThanOrEqualTo(_screen.height + 0.5));
  });

  testWidgets(
    'CR-IFFD-45 — sliver floating : le créneau se replie AVEC l\'app-bar',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(
        _sliverHost(
          mode: ZPageAppBarMode.floating,
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
          aboveTabBarHeight: 48,
        ),
      );
      await tester.pumpAndSettle();
      final Rect before = tester.getRect(find.byKey(_slotKey));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final Finder slot = find.byKey(_slotKey);
      final bool gone = slot.evaluate().isEmpty;
      expect(
        gone || tester.getRect(slot).top < before.top,
        isTrue,
        reason: 'floating ⇒ la surface se replie avec l\'app-bar',
      );
    },
  );

  testWidgets(
    'CR-IFFD-45 — sliver floatingPinned : la toolbar se replie, le créneau '
    'reste épinglé en tête',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(
        _sliverHost(
          mode: ZPageAppBarMode.floatingPinned,
          aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
          aboveTabBarHeight: 48,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_slotKey)).top, closeTo(56, 0.5));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final Rect after = tester.getRect(find.byKey(_slotKey));
      // Le créneau reste VISIBLE, remonté en tête d'écran (toolbar repliée).
      expect(after.top, closeTo(0, 0.5));
      expect(after.height, closeTo(48, 0.5));
    },
  );

  testWidgets(
    'CR-IFFD-45 — sliver avec onglets : le créneau est au-dessus du TabBar',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ZPageShellBody(
            title: 'TITRE',
            tabs: _tabs(),
            aboveTabBar: const Center(key: _slotKey, child: Text('CONTEXTE')),
            aboveTabBarHeight: 48,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Rect slot = tester.getRect(find.byKey(_slotKey));
      final Rect tabBar = tester.getRect(find.byType(TabBar));
      expect(slot.height, closeTo(48, 0.5));
      expect(
        slot.bottom,
        lessThanOrEqualTo(tabBar.top + 0.5),
        reason: 'en sliver aussi, aucun recouvrement du TabBar',
      );
      expect(slot.top, greaterThanOrEqualTo(-0.5));
      // Les vues d'onglets commencent SOUS le TabBar.
      expect(
        tester.getTopLeft(find.text('VUE_UN')).dy,
        greaterThanOrEqualTo(tabBar.bottom - 0.5),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // 4. TRIPWIRE — le défaut MESURÉ de la voie `subtitle` (pourquoi un créneau
  //    distinct). Si Flutter changeait ce comportement, cette garde rougirait
  //    et signalerait que l'argumentaire de la CR doit être re-mesuré.
  // ---------------------------------------------------------------------------

  testWidgets(
    'CR-IFFD-45 (constat) — subtitle NE fait PAS grandir l\'app-bar et '
    'recouvre le TabBar, SANS aucune exception',
    (tester) async {
      await _setScreen(tester);
      await tester.pumpWidget(
        _fixedHost(subtitle: const Text('COURT', key: _subtitleKey)),
      );
      await tester.pumpAndSettle();
      final double withShortText = _appBarHeight(tester);

      await tester.pumpWidget(
        _fixedHost(subtitle: const SizedBox(key: _subtitleKey, height: 48)),
      );
      await tester.pumpAndSettle();

      // Le défaut est SILENCIEUX : aucune exception de layout.
      expect(tester.takeException(), isNull);
      // L'app-bar ne grandit PAS (toolbar de 56 dp à hauteur fixe).
      expect(
        _appBarHeight(tester),
        closeTo(withShortText, 0.5),
        reason: 'subtitle vit dans le title: — la toolbar ne s\'agrandit pas',
      );
      // …et la bande RECOUVRE le TabBar.
      final Rect subtitle = tester.getRect(find.byKey(_subtitleKey));
      final Rect tabBar = tester.getRect(find.byType(TabBar));
      expect(
        subtitle.bottom,
        greaterThan(tabBar.top),
        reason: 'chevauchement mesuré : c\'est le défaut que aboveTabBar évite',
      );
    },
  );
}
