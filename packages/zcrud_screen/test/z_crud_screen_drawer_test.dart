// Gardes de la NAVIGATION DE L'APPLICATION portée par l'écran assemblé
// (CR DODLP « l'écran assemblé ne peut pas porter la navigation »).
//
// 🔴 MOTIF — `ZPageScaffold` accepte `drawer`/`endDrawer` et les passe à son
// `Scaffold`, mais `ZCrudScreen` ne les exposait pas : sur les 28 écrans
// migrés du parc hôte, l'agent n'avait plus AUCUN moyen d'atteindre le menu
// de l'application (ni bouton, ni glissement — le `Scaffold` de l'écran capte
// le geste et n'a pas de tiroir). Il devait quitter l'app pour changer de
// module. Motif connu : *le socle sait faire, l'écran ne relaie pas*.
//
// Ce fichier affirme les six faces de la règle :
//   (1) `drawer:` déclaré → ouverture par le bouton d'`AppBar` **et** par
//       glissement depuis le bord ;
//   (2) sans `drawer:` → écran identique à avant : **aucun** bouton de menu,
//       **aucun** tiroir (assertion d'ABSENCE) ;
//   (3) `endDrawer` suit la même règle (déclaré ⇒ ouvrable ; absent ⇒ rien) ;
//   (4) un `leading` déclaré par l'hôte **prime** sur le bouton de menu
//       (comportement natif de Material, gardé et non réimplémenté) — le
//       tiroir reste atteignable par glissement ;
//   (5) l'état **« accès refusé »** porte lui aussi le tiroir — c'est l'écran
//       où la navigation manque le plus (ni contenu, ni sortie) ;
//   (6) la **vue corbeille** impose son bouton de retour : le bouton de menu y
//       est masqué (décision figée), le glissement reste offert.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZErrorState;

import 'support/fixtures.dart';

/// Contenu identifiable du tiroir de tête (le « menu de l'application »).
const Widget _menu = Drawer(
  child: Center(child: Text('MENU MODULES', key: ValueKey('hostMenu'))),
);

/// Contenu identifiable du tiroir de queue.
const Widget _endMenu = Drawer(
  child: Center(child: Text('PANNEAU LATÉRAL', key: ValueKey('hostEndMenu'))),
);

Finder get _menuContent => find.byKey(const ValueKey('hostMenu'));
Finder get _endMenuContent => find.byKey(const ValueKey('hostEndMenu'));

/// Le bouton « hamburger » **inséré par Material** quand un tiroir existe et
/// que la place du `leading` est libre. Ce n'est PAS un widget de zcrud : la
/// garde vérifie que le socle laisse Material faire son travail.
Finder get _drawerButton => find.byType(DrawerButton);

/// Glissement depuis le bord de tête (ouverture native du tiroir).
Future<void> _dragFromStartEdge(WidgetTester tester) async {
  await tester.dragFrom(const Offset(0, 400), const Offset(320, 0));
  await tester.pumpAndSettle();
}

/// Glissement depuis le bord de queue (ouverture native de l'`endDrawer`).
Future<void> _dragFromEndEdge(WidgetTester tester) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  await tester.dragFrom(Offset(width - 1, 400), const Offset(-320, 0));
  await tester.pumpAndSettle();
}

ZCrudScreen<Item> _screen(
  FakeItemRepo repo, {
  Widget? drawer,
  Widget? endDrawer,
  Widget? leading,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      drawer: drawer,
      endDrawer: endDrawer,
      leading: leading,
    );

void main() {
  testWidgets(
      '(1) `drawer:` déclaré : ouvert par le bouton d\'AppBar, refermé, puis '
      'rouvert par GLISSEMENT depuis le bord', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo, drawer: _menu));

    // L'écran a bien son contenu, et le tiroir n'est pas encore monté.
    expect(find.text('Alpha'), findsOneWidget);
    expect(_menuContent, findsNothing);

    // (a) Ouverture par le bouton que Material insère dans l'app-bar.
    expect(_drawerButton, findsOneWidget);
    await tester.tap(_drawerButton);
    await tester.pumpAndSettle();
    expect(_menuContent, findsOneWidget);

    // Fermeture (tap sur la barrière modale), puis…
    await tester.tapAt(const Offset(1200, 400));
    await tester.pumpAndSettle();
    expect(_menuContent, findsNothing);

    // (b) …ouverture par GLISSEMENT depuis le bord : c'est le geste que le
    // `Scaffold` de l'écran captait sans jamais rien ouvrir.
    await _dragFromStartEdge(tester);
    expect(_menuContent, findsOneWidget);

    repo.dispose();
  });

  testWidgets(
      '(2) sans `drawer:` : écran IDENTIQUE à avant — aucun bouton de menu, '
      'et le glissement depuis le bord n\'ouvre RIEN', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo));

    expect(find.text('Alpha'), findsOneWidget);
    // Assertion d'ABSENCE : ni bouton inséré par Material, ni tiroir dans
    // l'arbre — le rendu est celui d'avant l'introduction du paramètre.
    expect(_drawerButton, findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byType(Drawer), findsNothing);

    // Le `Scaffold` n'a pas de tiroir : le geste ne monte rien, et la liste
    // reste celle qu'on voyait.
    await _dragFromStartEdge(tester);
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);

    repo.dispose();
  });

  testWidgets(
      '(3) `endDrawer` suit la même règle : déclaré ⇒ ouvrable par glissement '
      'depuis le bord de queue ; absent ⇒ rien ne s\'ouvre', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo, endDrawer: _endMenu));

    expect(_endMenuContent, findsNothing);
    await _dragFromEndEdge(tester);
    expect(_endMenuContent, findsOneWidget);
    repo.dispose();
  });

  testWidgets('(3 bis) sans `endDrawer` : le bord de queue n\'ouvre rien',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo));

    await _dragFromEndEdge(tester);
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      '(3 ter) les deux tiroirs coexistent : chacun s\'ouvre par SON bord, '
      'et un tiroir de tête déclaré n\'en monte pas un de queue',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      _screen(repo, drawer: _menu, endDrawer: _endMenu),
    );

    await _dragFromStartEdge(tester);
    expect(_menuContent, findsOneWidget);
    expect(_endMenuContent, findsNothing);
    await tester.tapAt(const Offset(1200, 400));
    await tester.pumpAndSettle();

    await _dragFromEndEdge(tester);
    expect(_endMenuContent, findsOneWidget);
    expect(_menuContent, findsNothing);
    repo.dispose();
  });

  testWidgets(
      '(4) le `leading` de l\'hôte PRIME sur le bouton de menu (Material, non '
      'réimplémenté) — le tiroir reste ouvrable par glissement',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      _screen(
        repo,
        drawer: _menu,
        leading: IconButton(
          key: const ValueKey('hostLeading'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
      ),
    );

    // Le leading de l'hôte occupe la place ; Material n'insère donc PAS le
    // bouton de menu (c'est son comportement natif — on le garde tel quel).
    expect(find.byKey(const ValueKey('hostLeading')), findsOneWidget);
    expect(_drawerButton, findsNothing);

    // Le tiroir existe pourtant bel et bien : le bord l'ouvre.
    await _dragFromStartEdge(tester);
    expect(_menuContent, findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      '(4 bis) RECHERCHE OUVERTE : le bouton de fermeture occupe le leading — '
      'même règle que (4), le tiroir reste ouvrable par glissement',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo, drawer: _menu));
    expect(_drawerButton, findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.search)),
    );
    await tester.pumpAndSettle();
    // Le socle pose son bouton de fermeture : Material ne peut plus insérer
    // le bouton de menu. Documenté, donc gardé.
    expect(_drawerButton, findsNothing);

    await _dragFromStartEdge(tester);
    expect(_menuContent, findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      '(5) ACCÈS REFUSÉ : l\'écran de refus porte lui aussi la navigation — '
      'bouton de menu et tiroir ouvrable', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    // `ZDenyAllAcl` : `view` refusé ⇒ état « accès refusé », aucun listing.
    await pumpScreen(
      tester,
      _screen(repo, drawer: _menu),
      acl: const ZDenyAllAcl(),
    );

    expect(find.byType(ZErrorState), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Sans ce relais, l'usager serait enfermé : ni contenu, ni sortie.
    expect(_drawerButton, findsOneWidget);
    await tester.tap(_drawerButton);
    await tester.pumpAndSettle();
    expect(_menuContent, findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      '(5 bis) ACCÈS REFUSÉ sans `drawer:` : aucun bouton de menu n\'apparaît',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo), acl: const ZDenyAllAcl());

    expect(find.byType(ZErrorState), findsOneWidget);
    expect(_drawerButton, findsNothing);
    expect(find.byType(Drawer), findsNothing);
    repo.dispose();
  });

  testWidgets(
      '(6) CORBEILLE : le bouton de retour du socle occupe le leading — le '
      'bouton de menu y est MASQUÉ (décision figée), le glissement reste offert',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(tester, _screen(repo, drawer: _menu));

    // Vue vivante : le bouton de menu est là.
    expect(_drawerButton, findsOneWidget);

    // Bascule corbeille : le socle impose son bouton de sortie.
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zCrudTrashBack')), findsOneWidget);
    // Sortir de la corbeille prime sur changer de module : Material ne peut
    // pas insérer son bouton là où le retour est posé. Comportement VOULU.
    expect(_drawerButton, findsNothing);

    // Le tiroir n'est pas perdu pour autant : le bord l'ouvre.
    await _dragFromStartEdge(tester);
    expect(_menuContent, findsOneWidget);
    await tester.tapAt(const Offset(1200, 400));
    await tester.pumpAndSettle();

    // Retour aux vivants : le bouton de menu revient de lui-même.
    await tester.tap(find.byKey(const ValueKey('zCrudTrashBack')));
    await tester.pumpAndSettle();
    expect(_drawerButton, findsOneWidget);
    repo.dispose();
  });
}
