// Gardes de la politique de requête déclarée (`ZCrudScreen.query`) : tri par
// défaut, filtres permanents, taille de page — et leurs COMPOSITIONS avec la
// corbeille, les onglets et la recherche.
//
// Toutes les assertions portent sur les `ZDataRequest` RÉELLEMENT émises vers
// le dépôt (dépôt enregistreur), pas sur la déclaration : c'est la requête qui
// décide de ce que l'usager voit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dépôt de test **enregistreur** : le fake neutre des fixtures, plus la trace
/// de chaque `ZDataRequest` reçue.
class RecordingRepo extends FakeItemRepo {
  RecordingRepo(super.seed);

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  /// Dernière requête reçue.
  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) {
    requests.add(request ?? const ZDataRequest());
    return super.getAll(request: request);
  }
}

/// Sonde posée DANS l'écran (via `header:`) : elle capte les gestes de l'écran
/// et la politique de requête offerte à ses descendants.
class QueryProbe extends StatelessWidget {
  const QueryProbe({required this.sink, super.key});

  /// Réceptacle des relevés.
  final QuerySink sink;

  @override
  Widget build(BuildContext context) {
    sink
      ..actions = ZCrudScreenScope.maybeOf(context)
      ..policy = ZListQueryPolicy.maybeOf(context);
    return const SizedBox.shrink();
  }
}

/// Relevés de la [QueryProbe].
class QuerySink {
  /// Gestes de l'écran englobant.
  ZCrudScreenActions? actions;

  /// Politique offerte aux descendants, ou `null` si aucune n'est déclarée.
  ZListQueryPolicy? policy;
}

/// Page d'onglet **de l'application** : elle possède son contrôleur et compose
/// les filtres permanents de l'écran avec ceux de sa catégorie.
class TabPage extends StatefulWidget {
  const TabPage({
    required this.repo,
    required this.categoryFilters,
    this.search,
    super.key,
  });

  /// Terme cherché par la page dès sa construction (`null` = aucune recherche).
  final String? search;

  /// Dépôt propre à la page.
  final ZRepository<Item> repo;

  /// Filtres de catégorie de l'onglet.
  final List<ZFilter> categoryFilters;

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> {
  ZListController<Item>? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ZListController<Item>(
      repository: widget.repo,
      toRow: (item) => ZListRow(
        id: item.id!,
        cells: <String, Object?>{'name': item.name, 'qty': item.qty},
      ),
      schema: itemSpecs,
      // LE geste attendu d'une page d'onglet : lire le socle que l'écran a
      // DÉJÀ composé pour cet onglet — ses filtres permanents ET la catégorie
      // déclarée par `ZListTab`. La page ne compose plus rien elle-même.
      baseFilters: ZListQueryPolicy.of(context).baseFilters,
    );
    final term = widget.search;
    if (term != null) _controller!.setSearch(term);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

const List<Item> _seed = <Item>[
  Item(id: 'c', name: 'charlie', qty: 3),
  Item(id: 'a', name: 'alpha', qty: 1),
  Item(id: 'b', name: 'bravo', qty: 2),
];

void main() {
  group('Tri par défaut déclaré', () {
    testWidgets(
      'le tri déclaré est appliqué au PREMIER rendu (requête et ordre rendu)',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: ZListQueryPolicy.sortedBy('name'),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.requests, isNotEmpty);
        expect(
          repo.requests.first.sorts,
          <ZSort>[const ZSort('name')],
          reason: 'la PREMIÈRE requête part déjà triée',
        );
        // L'ordre RENDU, pas seulement l'ordre demandé.
        final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
        expect(
          <String>[for (final tile in tiles) (tile.title! as Text).data!],
          <String>['alpha', 'bravo', 'charlie'],
        );
      },
    );

    testWidgets(
      'un tri demandé ensuite REMPLACE le tri par défaut',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        final sink = QuerySink();
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: ZListQueryPolicy.sortedBy('name'),
            header: QueryProbe(sink: sink),
          ),
        );
        await tester.pumpAndSettle();

        sink.actions!.sortBy(
          <ZSort>[const ZSort('qty', ZSortDirection.desc)],
        );
        await tester.pumpAndSettle();

        expect(
          repo.last.sorts,
          <ZSort>[const ZSort('qty', ZSortDirection.desc)],
          reason: 'le tri demandé remplace le défaut, il ne s\'y ajoute pas',
        );
        final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
        expect(
          <String>[for (final tile in tiles) (tile.title! as Text).data!],
          <String>['charlie', 'bravo', 'alpha'],
        );
      },
    );
  });

  group('Filtres permanents déclarés', () {
    testWidgets(
      'les filtres permanents sont dans CHAQUE requête',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          repo.requests.first.filters,
          <ZFilter>[const ZFilter('qty', ZFilterOp.gt, 1)],
        );
        expect(find.text('alpha'), findsNothing, reason: 'qty 1 est filtré');
        expect(find.text('bravo'), findsOneWidget);
      },
    );

    testWidgets(
      'un filtre demandé ensuite S\'AJOUTE aux permanents, ne les remplace pas',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        final sink = QuerySink();
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
            ),
            header: QueryProbe(sink: sink),
          ),
        );
        await tester.pumpAndSettle();

        sink.actions!.filterBy(
          <ZFilter>[const ZFilter('name', ZFilterOp.eq, 'charlie')],
        );
        await tester.pumpAndSettle();

        expect(
          repo.last.filters,
          <ZFilter>[
            const ZFilter('qty', ZFilterOp.gt, 1),
            const ZFilter('name', ZFilterOp.eq, 'charlie'),
          ],
          reason: 'permanent EN TÊTE, demandé ensuite — jamais l\'un pour '
              'l\'autre',
        );
        // Le filtre permanent tient : un filtre demandé ne peut pas rouvrir
        // ce que l'écran a fermé.
        sink.actions!.filterBy(
          <ZFilter>[const ZFilter('name', ZFilterOp.eq, 'alpha')],
        );
        await tester.pumpAndSettle();
        expect(
          repo.last.filters.first,
          const ZFilter('qty', ZFilterOp.gt, 1),
        );
        expect(find.text('alpha'), findsNothing);
      },
    );
  });

  group('Taille de page déclarée', () {
    testWidgets('la taille de page déclarée est celle des requêtes',
        (tester) async {
      final repo = RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          query: const ZListQueryPolicy(pageSize: 2),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.requests.first.limit, 2);
      expect(
        find.byType(ListTile),
        findsNWidgets(2),
        reason: 'la première page ne rend que sa taille déclarée',
      );
    });
  });

  group('Compositions', () {
    testWidgets(
      'CORBEILLE : la portée de suppression est préservée, tri et filtres '
      'permanents s\'y appliquent EN PLUS',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await repo.softDelete('c');
        await repo.softDelete('a');
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              sort: <ZSort>[ZSort('name')],
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 0)],
              pageSize: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
        await tester.pumpAndSettle();

        final trash = repo.requests.where(
          (r) => r.deletedScope == ZDeletedScope.deletedOnly,
        );
        expect(trash, isNotEmpty, reason: 'la corbeille reste la corbeille');
        expect(trash.last.sorts, <ZSort>[const ZSort('name')]);
        expect(
          trash.last.filters,
          <ZFilter>[const ZFilter('qty', ZFilterOp.gt, 0)],
        );
        expect(trash.last.limit, 10);
      },
    );

    testWidgets(
      'ONGLET : le filtre de catégorie survit aux filtres permanents (les '
      'deux sont dans la requête de la page)',
      (tester) async {
        final screenRepo = RecordingRepo(_seed);
        final tabRepo = RecordingRepo(_seed);
        addTearDown(screenRepo.dispose);
        addTearDown(tabRepo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(screenRepo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
            ),
            tabs: <ZListTab>[
              ZListTab.category(
                labelKey: 'active',
                filters: const <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
                buildList: (context, categoryFilters) => TabPage(
                  repo: tabRepo,
                  categoryFilters: categoryFilters,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tabRepo.requests, isNotEmpty);
        expect(
          tabRepo.last.filters,
          <ZFilter>[
            const ZFilter('archive', ZFilterOp.eq, false),
            const ZFilter('qty', ZFilterOp.gt, 1),
          ],
          reason: 'permanent de l\'écran EN TÊTE, catégorie de l\'onglet '
              'ensuite — la catégorie n\'est jamais annulée',
        );
      },
    );

    testWidgets(
      'ONGLET : la catégorie DÉCLARÉE suffit — l\'écran compose, la page ne '
      'compose plus rien',
      (tester) async {
        final screenRepo = RecordingRepo(_seed);
        final tabRepo = RecordingRepo(_seed);
        addTearDown(screenRepo.dispose);
        addTearDown(tabRepo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(screenRepo),
            registry: buildItemRegistry(),
            // AUCUNE politique d'écran : seul l'onglet déclare son socle.
            tabs: <ZListTab>[
              ZListTab(
                labelKey: 'active',
                baseFilters: const <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
                builder: (context) => TabPage(
                  repo: tabRepo,
                  categoryFilters: const <ZFilter>[],
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tabRepo.requests, isNotEmpty);
        expect(
          tabRepo.last.filters,
          <ZFilter>[const ZFilter('qty', ZFilterOp.gt, 1)],
          reason: 'le socle déclaré par l\'onglet atteint sa page SANS que '
              'celle-ci ait rien à composer',
        );
      },
    );

    testWidgets(
      'ONGLET : chercher dans un onglet n\'en fait jamais sortir',
      (tester) async {
        final screenRepo = RecordingRepo(_seed);
        final tabRepo = RecordingRepo(_seed);
        addTearDown(screenRepo.dispose);
        addTearDown(tabRepo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(screenRepo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
            ),
            tabs: <ZListTab>[
              ZListTab.category(
                labelKey: 'active',
                filters: const <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
                buildList: (context, categoryFilters) => TabPage(
                  repo: tabRepo,
                  categoryFilters: categoryFilters,
                  search: 'alpha',
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tabRepo.last.search, 'alpha');
        expect(
          tabRepo.last.filters,
          <ZFilter>[
            const ZFilter('archive', ZFilterOp.eq, false),
            const ZFilter('qty', ZFilterOp.gt, 1),
          ],
          reason: 'permanent ET catégorie survivent à la recherche',
        );
      },
    );

    testWidgets(
      'RECHERCHE : chercher n\'efface ni les filtres permanents ni le tri',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              sort: <ZSort>[ZSort('name', ZSortDirection.desc)],
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 0)],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await searchInAppBar(tester, 'rav');
        await tester.pumpAndSettle();

        expect(repo.last.search, 'rav');
        expect(
          repo.last.filters,
          <ZFilter>[const ZFilter('qty', ZFilterOp.gt, 0)],
        );
        expect(
          repo.last.sorts,
          <ZSort>[const ZSort('name', ZSortDirection.desc)],
        );
      },
    );
  });

  group('CONTRE-TÉMOIN — sans politique déclarée', () {
    testWidgets(
      'les requêtes émises sont EXACTEMENT celles d\'avant (taille de page '
      'comprise) et aucune politique n\'est offerte aux descendants',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await repo.softDelete('c');
        final sink = QuerySink();
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            header: QueryProbe(sink: sink),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          repo.requests.first,
          const ZDataRequest(),
          reason: 'aucun filtre, aucun tri, AUCUNE limite de page',
        );
        expect(repo.requests.first.limit, isNull);
        expect(sink.policy, isNull);

        await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
        await tester.pumpAndSettle();

        expect(
          repo.last,
          const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
          reason: 'la corbeille émet la requête historique, inchangée',
        );
      },
    );

    testWidgets(
      'voie items : sans politique, la liste entière est rendue ; avec, elle '
      'est filtrée et triée',
      (tester) async {
        await pumpScreen(
          tester,
          const ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.items(_seed),
            listFields: itemSpecs,
            cellsOf: _cellsOfItem,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsNWidgets(3));

        await pumpScreen(
          tester,
          const ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.items(_seed),
            listFields: itemSpecs,
            cellsOf: _cellsOfItem,
            query: ZListQueryPolicy(
              sort: <ZSort>[ZSort('name')],
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
        expect(
          <String>[for (final tile in tiles) (tile.title! as Text).data!],
          <String>['bravo', 'charlie'],
        );
      },
    );
  });

  group('Règles de composition, isolées', () {
    test('filtersWith ajoute, sortFor remplace', () {
      const policy = ZListQueryPolicy(
        sort: <ZSort>[ZSort('name')],
        baseFilters: <ZFilter>[ZFilter('a', ZFilterOp.eq, 1)],
      );
      expect(
        policy.filtersWith(const <ZFilter>[ZFilter('b', ZFilterOp.eq, 2)]),
        <ZFilter>[
          const ZFilter('a', ZFilterOp.eq, 1),
          const ZFilter('b', ZFilterOp.eq, 2),
        ],
      );
      expect(policy.filtersWith(const <ZFilter>[]), policy.baseFilters);
      expect(
        policy.sortFor(const <ZSort>[ZSort('qty')]),
        <ZSort>[const ZSort('qty')],
      );
      expect(policy.sortFor(const <ZSort>[]), policy.sort);
      expect(const ZListQueryPolicy().declaresNothing, isTrue);
      expect(policy.declaresNothing, isFalse);
    });
  });
}

/// Projection d'un [Item] en cellules (voie `items`, sans registre).
Map<String, Object?> _cellsOfItem(Item item) => <String, Object?>{
      'id': item.id,
      'name': item.name,
      'qty': item.qty,
    };
