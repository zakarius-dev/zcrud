// Gardes de l'ONGLET ASSEMBLÉ : un onglet qui ne déclare que sa catégorie
// (`ZListTab.baseFilters`) et, s'il y a lieu, ses droits (`ZListTab.acl`),
// reçoit de l'écran la MÊME liste que le mode sans onglets — actions de ligne
// comprises.
//
// Ce que ces gardes tiennent :
//   * les gestes de ligne (corbeille, modifier, consulter) existent sur une
//     ligne d'onglet, et sont gouvernés par `delete` / `update` / `view` ;
//   * la barre de recherche est UNIQUE et ne filtre que l'onglet ACTIF ;
//   * la corbeille garde la MÊME catégorisation que la vue vivante ;
//   * 🔴 ADVERSARIALE — l'ACL d'un onglet RETIRE un geste, sans jamais en
//     ajouter un que l'écran refuse ;
//   * 🔴 CONTRE-TÉMOIN — un onglet qui fournit son `builder` reste opaque :
//     aucun geste assemblé, aucune recherche, corbeille non catégorisée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// ACL autorisant tout — la plus permissive exprimable, celle qui rendrait
/// visible un élargissement s'il existait.
class _AllowAll implements ZAcl {
  const _AllowAll();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => true;
}

const _seed = <Item>[
  Item(id: 'a1', name: 'Alpha', qty: 1),
  Item(id: 'a2', name: 'Alfred', qty: 1),
  Item(id: 'b1', name: 'Beta', qty: 2),
];

const _categorieUn = <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)];
const _categorieDeux = <ZFilter>[ZFilter('qty', ZFilterOp.eq, 2)];

/// Deux onglets ASSEMBLÉS (aucun `builder`), partitionnant la même collection.
List<ZListTab> _assembledTabs({ZAcl? aclUn, ZAcl? aclDeux}) => <ZListTab>[
      ZListTab(labelKey: 'Un', baseFilters: _categorieUn, acl: aclUn),
      ZListTab(labelKey: 'Deux', baseFilters: _categorieDeux, acl: aclDeux),
    ];

Widget _screen(
  FakeItemRepo repo, {
  required List<ZListTab> tabs,
  ZAcl? acl,
  bool detailsEnabled = true,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      acl: acl,
      detailsEnabled: detailsEnabled,
      canDuplicate: false,
      tabs: tabs,
    );

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

Finder get _searchIcon =>
    find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.search));

/// Ligne portant [name] **dans le corps** — jamais la saisie de recherche, qui
/// vit dans l'app-bar et porte le même texte.
Finder _row(String name, {bool skipOffstage = true}) => find.descendant(
      of: find.byType(TabBarView, skipOffstage: false),
      matching: find.text(name, skipOffstage: skipOffstage),
      skipOffstage: skipOffstage,
    );

void main() {
  // ── 1. Geste « mettre à la corbeille », gouverné par `delete` ─────────────

  testWidgets(
      'ONGLET ASSEMBLÉ — le geste « mettre à la corbeille » est présent sur '
      'une ligne d\'onglet, et gouverné par `delete`', (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);

    await pumpScreen(tester, _screen(repo, tabs: _assembledTabs()));
    expect(
      find.text('Alpha'),
      findsOneWidget,
      reason: 'l\'onglet assemblé liste bien SA catégorie',
    );
    expect(
      find.text('Beta'),
      findsNothing,
      reason: 'la catégorie de l\'onglet est un socle : rien d\'autre n\'entre',
    );
    expect(
      find.byIcon(Icons.delete_outline),
      findsNWidgets(2),
      reason: 'un geste de corbeille par ligne de l\'onglet',
    );

    // Le geste ÉCRIT réellement (une action rendue mais inerte ne vaut rien).
    await softDeleteFirstRow(tester);
    expect(repo.softDeleted, <String>['a1']);

    // 🔴 Gouvernance : l'écran refuse `delete` ⇒ le geste disparaît.
    final autre = FakeItemRepo(_seed);
    addTearDown(autre.dispose);
    await pumpScreen(
      tester,
      _screen(
        autre,
        tabs: _assembledTabs(),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      ),
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(
      find.byIcon(Icons.edit_outlined),
      findsNWidgets(2),
      reason: 'CONTRE-TÉMOIN : seul `delete` est retiré, la ligne vit encore',
    );
  });

  // ── 2. Gestes « modifier » et « détails », gouvernés par update / view ────

  testWidgets(
      'ONGLET ASSEMBLÉ — « modifier » et « détails » sont présents, et '
      'gouvernés par `update` / `view`', (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);

    await pumpScreen(tester, _screen(repo, tabs: _assembledTabs()));
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));

    // `update` refusé par l'écran ⇒ « modifier » part, « détails » reste.
    final sansUpdate = FakeItemRepo(_seed);
    addTearDown(sansUpdate.dispose);
    await pumpScreen(
      tester,
      _screen(
        sansUpdate,
        tabs: _assembledTabs(),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.update}),
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(
      find.byIcon(Icons.visibility_outlined),
      findsNWidgets(2),
      reason: 'consulter n\'est pas modifier : `view` gouverne seul la fiche',
    );

    // `view` refusé par l'ONGLET ⇒ « détails » part de CET onglet, l'édition
    // reste (la fiche relève de `view`, l'édition de `update`).
    final sansView = FakeItemRepo(_seed);
    addTearDown(sansView.dispose);
    await pumpScreen(
      tester,
      _screen(
        sansView,
        tabs: _assembledTabs(
          aclUn: const DenyAcl(<ZCrudAction>{ZCrudAction.view}),
        ),
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    await _tapTab(tester, 'Deux');
    expect(
      find.byIcon(Icons.visibility_outlined),
      findsOneWidget,
      reason: 'la restriction est celle de l\'ONGLET, pas de l\'écran',
    );
  });

  // ── 3. Barre de recherche unique, filtrant l'onglet ACTIF ────────────────

  testWidgets(
      'ONGLET ASSEMBLÉ — une barre de recherche UNIQUE filtre l\'onglet ACTIF, '
      'et lui seul', (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await pumpScreen(tester, _screen(repo, tabs: _assembledTabs()));

    expect(
      _searchIcon,
      findsOneWidget,
      reason: 'des onglets tous assemblés RENDENT la recherche possible',
    );

    // On monte la page du second onglet, puis on revient au premier : les deux
    // pages sont vivantes (keep-alive), l'une visible, l'autre hors écran.
    await _tapTab(tester, 'Deux');
    expect(find.text('Beta'), findsOneWidget);
    await _tapTab(tester, 'Un');

    await searchInAppBar(tester, 'Alfred');
    expect(
      _row('Alpha'),
      findsNothing,
      reason: 'l\'onglet ACTIF est bien filtré',
    );
    expect(_row('Alfred'), findsOneWidget);
    expect(
      _row('Beta', skipOffstage: false),
      findsOneWidget,
      reason: 'l\'onglet INACTIF garde sa liste entière : la barre ne se '
          'diffuse pas à tous les onglets',
    );

    // La recherche SUIT l'onglet : en changeant d'onglet, c'est le nouveau
    // qui est filtré — et l'ancien qui est relâché.
    await _tapTab(tester, 'Deux');
    expect(
      _row('Beta'),
      findsNothing,
      reason: 'le terme visible dans la barre filtre l\'onglet devenu actif',
    );
    expect(
      _row('Alpha', skipOffstage: false),
      findsOneWidget,
      reason: 'l\'onglet quitté retrouve sa liste entière',
    );
  });

  // ── 4. Corbeille catégorisée ─────────────────────────────────────────────

  testWidgets(
      'ONGLET ASSEMBLÉ — la corbeille garde la MÊME catégorisation que la vue '
      'vivante', (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await repo.softDelete('a1');
    await repo.softDelete('b1');

    await pumpScreen(tester, _screen(repo, tabs: _assembledTabs()));
    await openTrashView(tester);

    expect(
      find.widgetWithText(Tab, 'Un'),
      findsOneWidget,
      reason: 'les onglets survivent à la bascule vers la corbeille',
    );
    expect(
      find.text('Alpha'),
      findsOneWidget,
      reason: 'la partition supprimée porte les MÊMES filtres de catégorie',
    );
    expect(
      find.text('Beta'),
      findsNothing,
      reason: 'Beta appartient à l\'autre catégorie, corbeille comprise',
    );

    await _tapTab(tester, 'Deux');
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  // ── 5. 🔴 ADVERSARIALE — la cascade RETIRE, elle n'ajoute jamais ─────────

  testWidgets(
      '🔴 ADVERSARIALE — l\'ACL d\'un onglet retire un geste, et n\'en ajoute '
      'JAMAIS un que l\'écran refuse', (tester) async {
    // (a) L'onglet retire : `delete` refusé par l'ONGLET seul.
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      _screen(
        repo,
        tabs: _assembledTabs(
          aclUn: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
        ),
      ),
    );
    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason: 'l\'onglet RETIRE le geste de sa propre vue',
    );
    await _tapTab(tester, 'Deux');
    expect(
      find.byIcon(Icons.delete_outline),
      findsOneWidget,
      reason: 'CONTRE-TÉMOIN : l\'onglet voisin, lui, le garde',
    );

    // (b) 🔴 L'onglet n'ajoute pas : ACL d'onglet la plus permissive
    // exprimable, sous un écran qui refuse `delete`.
    final verrouille = FakeItemRepo(_seed);
    addTearDown(verrouille.dispose);
    await pumpScreen(
      tester,
      _screen(
        verrouille,
        tabs: _assembledTabs(aclUn: const _AllowAll()),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      ),
    );
    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason: 'la composition est une CONJONCTION : un onglet généreux ne '
          'rouvre rien de ce que l\'écran refuse',
    );
    expect(
      find.byIcon(Icons.edit_outlined),
      findsNWidgets(2),
      reason: 'CONTRE-TÉMOIN : la garde ne passe pas au vert parce que la '
          'liste serait vide ou sans aucune action',
    );
  });

  // ── 6. 🔴 CONTRE-TÉMOIN — l'onglet à builder est inchangé ────────────────

  testWidgets(
      '🔴 CONTRE-TÉMOIN — un onglet qui fournit son `builder` rend exactement '
      'ce qu\'il rendait : aucun geste assemblé, aucune recherche',
      (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      _screen(
        repo,
        tabs: <ZListTab>[
          ZListTab(
            labelKey: 'Libre',
            baseFilters: _categorieUn,
            builder: (_) => const Center(child: Text('page-libre')),
          ),
          ZListTab(
            labelKey: 'Aussi',
            baseFilters: _categorieDeux,
            builder: (_) => const Center(child: Text('page-aussi')),
          ),
        ],
      ),
    );

    expect(find.text('page-libre'), findsOneWidget);
    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason: 'l\'écran n\'accroche rien à une vue qu\'il ne connaît pas',
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(
      _searchIcon,
      findsNothing,
      reason: 'un onglet opaque retire la barre de recherche partagée',
    );

    // La corbeille d'un écran à onglets opaques reste le LISTING UNIQUE.
    await repo.softDelete('a1');
    await openTrashView(tester);
    expect(find.widgetWithText(Tab, 'Libre'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets(
      '🔴 CONTRE-TÉMOIN — un SEUL onglet opaque suffit à retirer la recherche '
      'partagée et les onglets de corbeille', (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      _screen(
        repo,
        tabs: <ZListTab>[
          ZListTab(labelKey: 'Un', baseFilters: _categorieUn),
          ZListTab(
            labelKey: 'Opaque',
            builder: (_) => const Center(child: Text('page-opaque')),
          ),
        ],
      ),
    );
    expect(
      find.byIcon(Icons.delete_outline),
      findsNWidgets(2),
      reason: 'l\'onglet assemblé, lui, reçoit bien ses gestes',
    );
    expect(_searchIcon, findsNothing);

    await repo.softDelete('a1');
    await openTrashView(tester);
    expect(find.widgetWithText(Tab, 'Un'), findsNothing);
  });

  // ── Barre défilante ──────────────────────────────────────────────────────

  testWidgets('`tabsScrollable` atteint bien la barre d\'onglets',
      (tester) async {
    final repo = FakeItemRepo(_seed);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        tabsScrollable: true,
        tabs: _assembledTabs(),
      ),
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);

    // CONTRE-TÉMOIN : le défaut reste la barre fixe.
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        tabs: _assembledTabs(),
      ),
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
  });
}
