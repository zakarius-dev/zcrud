// Gardes des ONGLETS GOUVERNÉS au niveau de l'écran assemblé : la cascade
// d'autorisations onglet > écran > scope (et son NON-ÉLARGISSEMENT), puis les
// intitulés de formulaire propres à l'onglet actif.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// ACL n'autorisant que la consultation et les actions de [allowed].
class ViewPlusAcl implements ZAcl {
  const ViewPlusAcl(this.allowed);

  final Set<ZCrudAction> allowed;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action == ZCrudAction.view || allowed.contains(action);
}

Finder get createButton => find.byKey(const ValueKey('zCrudCreate'));

String openedTitle(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('zCrudFormTitle')))
    .data!;

/// Écran à deux onglets, dont le premier peut porter une restriction et des
/// intitulés propres.
Future<FakeItemRepo> pumpTabbedScreen(
  WidgetTester tester, {
  required ZAcl scopeAcl,
  ZAcl? screenAcl,
  ZAcl? firstTabAcl,
  ZCrudTitles? screenTitles,
  ZCrudTitles? firstTabTitles,
  ZCrudTitles? secondTabTitles,
}) async {
  final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
  addTearDown(repo.dispose);
  await pumpScreen(
    tester,
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      acl: screenAcl,
      titles: screenTitles,
      tabs: <ZListTab>[
        ZListTab(
          labelKey: 'Dossiers',
          acl: firstTabAcl,
          titles: firstTabTitles,
          builder: (_) => const Center(child: Text('page-1')),
        ),
        ZListTab(
          labelKey: 'Pièces',
          titles: secondTabTitles,
          builder: (_) => const Center(child: Text('page-2')),
        ),
      ],
    ),
    acl: scopeAcl,
  );
  return repo;
}

void main() {
  group('Cascade d\'autorisations onglet > écran > scope', () {
    testWidgets(
        'niveau ONGLET : l\'onglet actif retire la création que l\'écran '
        'accordait', (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ZAllowAllAcl(),
        screenAcl: const ZAllowAllAcl(),
        firstTabAcl: const ViewPlusAcl(<ZCrudAction>{}),
      );
      expect(createButton, findsNothing);
    });

    testWidgets(
        'niveau ÉCRAN : ADVERSARIAL — un onglet TOUT PERMISSIF ne rouvre pas '
        'la création refusée par l\'écran', (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ZAllowAllAcl(),
        screenAcl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.update}),
        firstTabAcl: const ZAllowAllAcl(),
      );
      expect(
        createButton,
        findsNothing,
        reason: 'la déclaration de l\'onglet a ÉLARGI un droit refusé par '
            'l\'écran',
      );
    });

    testWidgets(
        'niveau SCOPE : ADVERSARIAL — un onglet TOUT PERMISSIF ne rouvre pas '
        'la création refusée par le scope', (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.update}),
        firstTabAcl: const ZAllowAllAcl(),
      );
      expect(
        createButton,
        findsNothing,
        reason: 'la déclaration de l\'onglet a ÉLARGI un droit refusé par le '
            'scope',
      );
    });

    testWidgets(
        'la restriction suit l\'onglet ACTIF : refusée ici, offerte à côté',
        (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ZAllowAllAcl(),
        firstTabAcl: const ViewPlusAcl(<ZCrudAction>{}),
      );
      expect(createButton, findsNothing);

      await tester.tap(find.text('Pièces'));
      await tester.pumpAndSettle();
      expect(createButton, findsOneWidget);
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans acl d\'onglet, la création reste offerte '
        '(comportement strictement antérieur)', (tester) async {
      await pumpTabbedScreen(tester, scopeAcl: const ZAllowAllAcl());
      expect(createButton, findsOneWidget);
    });
  });

  group('Intitulés de formulaire par onglet', () {
    testWidgets('chaque onglet ouvre la création sous SON intitulé',
        (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ZAllowAllAcl(),
        screenTitles: const ZCrudTitles(create: 'Nouvel élément'),
        firstTabTitles: const ZCrudTitles(create: 'Nouveau dossier'),
        secondTabTitles: const ZCrudTitles(create: 'Nouvelle pièce'),
      );
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(openedTitle(tester), 'Nouveau dossier');
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pièces'));
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(openedTitle(tester), 'Nouvelle pièce');
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans intitulé d\'onglet, celui de l\'écran s\'applique',
        (tester) async {
      await pumpTabbedScreen(
        tester,
        scopeAcl: const ZAllowAllAcl(),
        screenTitles: const ZCrudTitles(create: 'Nouvel élément'),
      );
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(openedTitle(tester), 'Nouvel élément');
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();
    });
  });
}
