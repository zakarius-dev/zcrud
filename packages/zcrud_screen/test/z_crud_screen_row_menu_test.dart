// Gardes de la PRÉSENTATION des actions de ligne : en ligne (défaut), en menu
// de débordement, en menu contextuel (clic droit / appui long), adaptatif.
//
// Ce que ces gardes tiennent :
//   * le DÉFAUT est strictement inchangé — sans déclaration, les actions
//     restent des boutons dans la ligne, et aucun menu n'est monté ;
//   * clic droit et appui long ouvrent le menu, et l'invocation atteint
//     l'entité de LA ligne visée (pas la première venue) ;
//   * l'arbitrage de l'appui long est DÉCLARÉ : quand la liste le réclame, le
//     menu contextuel ne s'ouvre plus qu'au clic droit ;
//   * une action refusée par l'ACL est absente ou inerte-avec-motif selon le
//     mode d'ACL déclaré, jamais invocable ;
//   * l'action reste atteignable SANS geste contextuel (invariant AD-13) ;
//   * le renderer employé est celui du `ZMenuScope` ambiant.
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_menu/zcrud_menu.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Renderer OBSERVABLE : compte les deux voies et délègue au rendu par défaut.
class SpyRenderer extends ZMenuRenderer {
  SpyRenderer();

  int builds = 0;
  int opens = 0;

  @override
  Widget build(BuildContext context, ZMenuRequest request) {
    builds++;
    return const ZDefaultMenuRenderer().build(context, request);
  }

  @override
  Future<void> openAt(
    BuildContext context,
    ZMenuRequest request,
    Offset globalPosition,
  ) {
    opens++;
    return zShowZMenuAt(context, request, globalPosition);
  }
}

void main() {
  /// Action de ligne CUSTOM (aucune permission requise) qui enregistre
  /// l'entité atteinte — c'est elle qui prouve que l'invocation ne se trompe
  /// pas de ligne.
  ZRowAction<Item> pingAction(List<String> touched, {ZCrudAction? permission}) =>
      ZRowAction<Item>(
        id: 'ping',
        labelKey: 'ping',
        icon: Icons.bolt,
        requiredPermission: permission,
        onInvoke: (context, entity) => touched.add(entity.name),
      );

  Widget screen({
    required FakeItemRepo repo,
    required List<String> touched,
    ZRowActionsPresentation presentation = ZRowActionsPresentation.inline,
    ZRowLongPressOwner longPressOwner = ZRowLongPressOwner.contextMenu,
    ZActionAclMode aclMode = ZActionAclMode.hide,
    ZCrudAction? pingPermission,
    ZAcl? acl,
  }) =>
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        acl: acl,
        actionAclMode: aclMode,
        rowActionsPresentation: presentation,
        longPressOwner: longPressOwner,
        rowActions: <ZRowAction<Item>>[
          pingAction(touched, permission: pingPermission),
        ],
      );

  const seed = <Item>[
    Item(id: 'i1', name: 'Alpha'),
    Item(id: 'i2', name: 'Beta'),
  ];

  /// Ouvre le menu de la ligne [name] par le geste demandé.
  Future<void> gestureOn(
    WidgetTester tester,
    String name, {
    required bool secondary,
  }) async {
    final row = find.ancestor(
      of: find.textContaining(name),
      matching: find.byType(ZRowActionsMenu),
    );
    if (secondary) {
      await tester.tapAt(tester.getCenter(row), buttons: kSecondaryButton);
    } else {
      await tester.longPressAt(tester.getCenter(row));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('DÉFAUT inchangé : boutons en ligne, aucun menu monté',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(tester, screen(repo: repo, touched: touched));

    // Les actions assemblées ET l'action de l'app sont des boutons visibles.
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.bolt), findsNWidgets(2));
    // Rien du monde « menu » n'est monté.
    expect(find.byType(ZRowActionsMenu), findsNothing);
    expect(find.byType(ZActionMenu), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // CONTRE-TÉMOIN : la déclaration, elle, change bien le rendu.
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.menu,
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.bolt), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    repo.dispose();
  });

  testWidgets('clic droit : ouvre le menu, et l\'invocation atteint LA ligne',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.contextMenu,
      ),
    );
    await gestureOn(tester, 'Beta', secondary: true);
    expect(find.text('ping'), findsOneWidget);

    await tester.tap(find.text('ping'));
    await tester.pumpAndSettle();
    expect(touched, <String>['Beta'], reason: 'la SECONDE ligne, une seule fois');
    repo.dispose();
  });

  testWidgets('appui long : même menu, même entité', (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.contextMenu,
      ),
    );
    await gestureOn(tester, 'Beta', secondary: false);
    expect(find.text('ping'), findsOneWidget);
    await tester.tap(find.text('ping'));
    await tester.pumpAndSettle();
    expect(touched, <String>['Beta']);
    repo.dispose();
  });

  testWidgets(
      'arbitrage DÉCLARÉ : l\'appui long rendu à la liste, le clic droit reste',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.contextMenu,
        longPressOwner: ZRowLongPressOwner.list,
      ),
    );
    await gestureOn(tester, 'Beta', secondary: false);
    expect(find.text('ping'), findsNothing, reason: 'geste rendu à la liste');

    await gestureOn(tester, 'Beta', secondary: true);
    expect(find.text('ping'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('AD-13 : l\'action reste atteignable SANS geste contextuel',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.contextMenu,
      ),
    );
    // Le déclencheur visible est rendu, et suffit : aucun clic droit ici.
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ping'));
    await tester.pumpAndSettle();
    expect(touched, <String>['Beta']);
    repo.dispose();
  });

  testWidgets('ACL « masquer » : l\'action refusée est ABSENTE du menu',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.menu,
        // Permission qu'AUCUNE action assemblée ne réclame : le refus mesuré
        // est bien celui de l'action de l'app, pas un effet de bord.
        pingPermission: ZCrudAction.archive,
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.archive}),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('ping'), findsNothing);
    expect(find.text('Edit'), findsOneWidget, reason: 'les autres demeurent');
    repo.dispose();
  });

  testWidgets('ACL « désactiver » : présente, INERTE, motif annoncé',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.menu,
        aclMode: ZActionAclMode.disable,
        // Permission qu'AUCUNE action assemblée ne réclame : le refus mesuré
        // est bien celui de l'action de l'app, pas un effet de bord.
        pingPermission: ZCrudAction.archive,
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.archive}),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('ping'), findsOneWidget);
    // Le motif est RENDU, pas seulement supposé.
    expect(find.text('You are not allowed to do this'), findsOneWidget);

    // L'inertie est portée par la SURFACE, pas seulement par l'effet nul :
    // l'entrée refusée n'est même pas tappable. Sans cette assertion, le
    // `touched` vide ci-dessous serait vrai d'avance — `ZMenuEntry` interdit
    // par construction qu'une entrée à motif porte un effet, donc rien de ce
    // que la présentation ferait ne pourrait le rendre invocable.
    final refusee = tester.widget<PopupMenuItem<ZMenuEntry>>(
      find.ancestor(
        of: find.text('ping'),
        matching: find.byType(PopupMenuItem<ZMenuEntry>),
      ),
    );
    expect(refusee.enabled, isFalse);

    await tester.tap(find.text('ping'));
    await tester.pumpAndSettle();
    expect(touched, isEmpty, reason: 'inerte : jamais invocable');
    repo.dispose();
  });

  testWidgets('adaptatif : peu d\'actions ⇒ en ligne, plus le geste',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        // Consultation verrouillée : la seule action offerte est celle de
        // l'app — sous le seuil, donc rendue en ligne.
        mode: ZScreenMode.locked,
        rowActionsPresentation: ZRowActionsPresentation.auto,
        rowActions: <ZRowAction<Item>>[pingAction(touched)],
      ),
    );
    expect(find.byIcon(Icons.bolt), findsNWidgets(2));
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // Le geste contextuel s'ajoute quand même.
    await gestureOn(tester, 'Beta', secondary: true);
    expect(find.text('ping'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('adaptatif : au-delà du seuil ⇒ déclencheur de menu',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    await pumpScreen(
      tester,
      screen(
        repo: repo,
        touched: touched,
        presentation: ZRowActionsPresentation.auto,
      ),
    );
    // Édition + duplication + corbeille + action de l'app : au-delà de 2.
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    expect(find.byIcon(Icons.bolt), findsNothing);
    repo.dispose();
  });

  testWidgets('le renderer du ZMenuScope ambiant sert les deux voies',
      (tester) async {
    final repo = FakeItemRepo(seed);
    final touched = <String>[];
    final spy = SpyRenderer();
    await pumpScreen(
      tester,
      ZMenuScope(
        renderer: spy,
        child: screen(
          repo: repo,
          touched: touched,
          presentation: ZRowActionsPresentation.contextMenu,
        ),
      ),
    );
    expect(spy.builds, greaterThan(0), reason: 'déclencheur : scope employé');
    await gestureOn(tester, 'Beta', secondary: true);
    expect(spy.opens, 1, reason: 'geste contextuel : scope employé');
    repo.dispose();
  });
}
