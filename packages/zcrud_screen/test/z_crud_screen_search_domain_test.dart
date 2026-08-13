// Gardes du DOMAINE et de la NORMALISATION de la recherche déclarés sur
// l'écran (`ZCrudScreen.query` → `ZListQueryPolicy.searchScope` /
// `searchFolding`).
//
// Ce que ces gardes mesurent :
//   (a) NON-RÉGRESSION DU DÉFAUT — sans déclaration, la recherche interroge
//       les seuls champs `searchable` et compte les blancs, et la requête
//       émise est EXACTEMENT celle d'avant ;
//   (b) `allColumns` retrouve le domaine des moteurs de liste historiques —
//       une valeur d'une colonne NON `searchable` devient trouvable ;
//   (c) `diacriticsAndSpaces` fait correspondre « SARL U » et « sarlu » ;
//   (d) la recherche élargie COMPOSE avec les filtres permanents, la vue
//       corbeille et les filtres d'onglet ;
//   (e) élargir le domaine ne coûte AUCUNE reconstruction supplémentaire du
//       corps (AD-2).
//
// Les assertions portent sur ce qui est RENDU et sur les `ZDataRequest`
// réellement émises, jamais sur la seule déclaration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dépôt enregistreur : le fake neutre des fixtures (qui applique le moteur du
/// cœur, donc honore le domaine porté par la requête), plus la trace des
/// requêtes reçues.
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

/// Page d'onglet **de l'application** : elle possède son contrôleur et hérite
/// de la sémantique de recherche déclarée par l'écran, en plus des filtres.
class SearchTabPage extends StatefulWidget {
  const SearchTabPage({
    required this.repo,
    required this.categoryFilters,
    super.key,
  });

  /// Dépôt propre à la page.
  final ZRepository<Item> repo;

  /// Filtres de catégorie de l'onglet.
  final List<ZFilter> categoryFilters;

  @override
  State<SearchTabPage> createState() => _SearchTabPageState();
}

class _SearchTabPageState extends State<SearchTabPage> {
  ZListController<Item>? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = ZListQueryPolicy.of(context);
    _controller ??= ZListController<Item>(
      repository: widget.repo,
      toRow: (item) => ZListRow(
        id: item.id!,
        cells: <String, Object?>{'name': item.name, 'qty': item.qty},
      ),
      schema: itemSpecs,
      baseFilters: policy.baseFilters,
      searchScope: policy.searchScope,
      searchFolding: policy.searchFolding,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// `name` est searchable, `qty` ne l'est PAS (cf. `itemSpecs`) : c'est cette
// asymétrie que le domaine déplace.
const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'SOCIETE X SARL U', qty: 742),
  Item(id: 'b', name: 'Comptoir Général', qty: 15),
  Item(id: 'c', name: 'Établissements Muller', qty: 93),
];

/// Titres des tuiles rendues, dans l'ordre.
List<String> _rendered(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  group('NON-RÉGRESSION DU DÉFAUT — aucune déclaration', () {
    testWidgets(
      'la valeur d\'une colonne NON searchable reste introuvable, et la '
      'requête émise est EXACTEMENT celle d\'avant',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
          ),
        );
        await tester.pumpAndSettle();

        await searchInAppBar(tester, '742');
        await tester.pumpAndSettle();

        expect(_rendered(tester), <String>[], reason: 'domaine historique');
        expect(
          repo.last,
          const ZDataRequest(search: '742'),
          reason: 'égalité de VALEUR avec la requête d\'avant : les deux '
              'champs additifs sont à leur défaut',
        );
        expect(repo.last.searchScope, ZSearchScope.searchableFields);
        expect(repo.last.searchFolding, ZSearchFolding.diacritics);
      },
    );

    testWidgets(
      '« sarlu » ne trouve pas « SARL U », « sarl u » si (contre-épreuve)',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
          ),
        );
        await searchInAppBar(tester, 'sarlu');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>[]);

        await searchInAppBar(tester, 'sarl u');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>['SOCIETE X SARL U']);
      },
    );

    testWidgets(
      'voie items : même domaine historique sans déclaration',
      (tester) async {
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: const ZCrudSource<Item>.items(_seed),
            registry: buildItemRegistry(),
          ),
        );
        await searchInAppBar(tester, '742');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>[]);
      },
    );
  });

  group('allColumns — le domaine des moteurs de liste historiques', () {
    testWidgets(
      'une valeur d\'une colonne NON searchable devient trouvable',
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
              searchScope: ZSearchScope.allColumns,
            ),
          ),
        );
        await searchInAppBar(tester, '742');
        await tester.pumpAndSettle();

        expect(_rendered(tester), <String>['SOCIETE X SARL U']);
        expect(repo.last.searchScope, ZSearchScope.allColumns);
      },
    );

    testWidgets(
      'voie items : le domaine élargi vaut aussi pour une liste en mémoire',
      (tester) async {
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: const ZCrudSource<Item>.items(_seed),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(
              searchScope: ZSearchScope.allColumns,
            ),
          ),
        );
        await searchInAppBar(tester, '93');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>['Établissements Muller']);
      },
    );
  });

  group('diacriticsAndSpaces — la normalisation historique', () {
    testWidgets('« sarlu » trouve « SOCIETE X SARL U »', (tester) async {
      final repo = RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          query: const ZListQueryPolicy(
            searchFolding: ZSearchFolding.diacriticsAndSpaces,
          ),
        ),
      );
      await searchInAppBar(tester, 'sarlu');
      await tester.pumpAndSettle();

      expect(_rendered(tester), <String>['SOCIETE X SARL U']);
      expect(repo.last.searchFolding, ZSearchFolding.diacriticsAndSpaces);
    });

    testWidgets(
      'le raccourci legacySearch pose les DEUX réglages',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy.legacySearch(),
          ),
        );
        await searchInAppBar(tester, 'sarlu');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>['SOCIETE X SARL U']);
        expect(repo.last.searchScope, ZSearchScope.allColumns);
        expect(repo.last.searchFolding, ZSearchFolding.diacriticsAndSpaces);
      },
    );
  });

  group('COMPOSITION — le domaine élargi cherche DANS ce qui reste', () {
    testWidgets(
      'FILTRE PERMANENT : une recherche élargie ne rouvre pas ce qu\'un '
      'filtre permanent a fermé',
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
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.lt, 100)],
              searchScope: ZSearchScope.allColumns,
            ),
          ),
        );
        await searchInAppBar(tester, '742');
        await tester.pumpAndSettle();

        expect(
          _rendered(tester),
          <String>[],
          reason: 'la ligne est trouvable par son qty, mais le filtre '
              'permanent l\'exclut',
        );
        expect(
          repo.last.filters,
          <ZFilter>[const ZFilter('qty', ZFilterOp.lt, 100)],
        );
        expect(repo.last.searchScope, ZSearchScope.allColumns);
        // Le vide ci-dessus n'est pas un moteur muet : le MÊME terme, avec le
        // MÊME domaine mais sans filtre permanent, rend la ligne — c'est la
        // garde « une valeur d'une colonne NON searchable devient trouvable ».
      },
    );

    testWidgets(
      'CORBEILLE : la requête corbeille porte la sémantique de recherche ET '
      'sa portée de suppression',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        await repo.softDelete('a');
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy.legacySearch(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
        await tester.pumpAndSettle();
        await searchInAppBar(tester, 'sarlu');
        await tester.pumpAndSettle();

        final trash = repo.requests.where(
          (r) => r.deletedScope == ZDeletedScope.deletedOnly,
        );
        expect(trash, isNotEmpty, reason: 'la corbeille reste la corbeille');
        expect(trash.last.searchScope, ZSearchScope.allColumns);
        expect(trash.last.searchFolding, ZSearchFolding.diacriticsAndSpaces);
        expect(
          _rendered(tester),
          <String>['SOCIETE X SARL U'],
          reason: 'la ligne EN CORBEILLE est retrouvée par la normalisation '
              'élargie, et elle seule',
        );
      },
    );

    testWidgets(
      'ONGLET : la page d\'onglet hérite du domaine ET garde son filtre de '
      'catégorie',
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
              searchScope: ZSearchScope.allColumns,
              searchFolding: ZSearchFolding.diacriticsAndSpaces,
            ),
            tabs: <ZListTab>[
              ZListTab.category(
                labelKey: 'active',
                filters: const <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
                buildList: (context, categoryFilters) => SearchTabPage(
                  repo: tabRepo,
                  categoryFilters: categoryFilters,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tabRepo.requests, isNotEmpty);
        expect(tabRepo.last.searchScope, ZSearchScope.allColumns);
        expect(
          tabRepo.last.searchFolding,
          ZSearchFolding.diacriticsAndSpaces,
        );
        expect(
          tabRepo.last.filters,
          <ZFilter>[
            const ZFilter('archive', ZFilterOp.eq, false),
            const ZFilter('qty', ZFilterOp.gt, 1),
          ],
          reason: 'la sémantique de recherche n\'a rien déplacé des filtres',
        );
      },
    );

    testWidgets(
      'ONGLET : une déclaration de recherche SEULE est quand même offerte '
      'aux pages d\'onglet',
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
            // Rien d'autre que la sémantique de recherche : c'est bien elle
            // seule qui doit rendre la politique visible aux descendants.
            query: const ZListQueryPolicy.legacySearch(),
            tabs: <ZListTab>[
              ZListTab.category(
                labelKey: 'active',
                filters: const <ZFilter>[],
                buildList: (context, categoryFilters) => SearchTabPage(
                  repo: tabRepo,
                  categoryFilters: categoryFilters,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tabRepo.requests, isNotEmpty);
        expect(tabRepo.last.searchScope, ZSearchScope.allColumns);
        expect(
          tabRepo.last.searchFolding,
          ZSearchFolding.diacriticsAndSpaces,
        );
      },
    );
  });

  group('COÛT — élargir le domaine ne reconstruit rien de plus (AD-2)', () {
    testWidgets(
      'le nombre de constructions de tuiles est le MÊME avec et sans domaine '
      'élargi, pour la même séquence de gestes',
      (tester) async {
        Future<int> buildsFor(ZListQueryPolicy policy) async {
          var builds = 0;
          // Démonte complètement l'arbre précédent : sans cela, la seconde
          // mesure hériterait de l'état de la première (mêmes éléments
          // réutilisés) et ne mesurerait plus la configuration déclarée.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          final repo = RecordingRepo(_seed);
          addTearDown(repo.dispose);
          await pumpScreen(
            tester,
            ZCrudScreen<Item>(
              title: 'Items',
              source: ZCrudSource<Item>.repository(repo),
              registry: buildItemRegistry(),
              query: policy,
              itemBuilder: (context, item, columns) {
                builds++;
                return Text('ligne-${item.name}');
              },
            ),
          );
          await tester.pumpAndSettle();
          // Une frappe qui laisse les trois lignes en place dans les DEUX
          // configurations (« e » est présent dans les trois libellés) : seule
          // la sémantique de recherche change entre les deux mesures.
          await searchInAppBar(tester, 'e');
          await tester.pumpAndSettle();
          return builds;
        }

        final withoutScope = await buildsFor(const ZListQueryPolicy());
        final withScope = await buildsFor(
          const ZListQueryPolicy(searchScope: ZSearchScope.allColumns),
        );

        expect(withoutScope, greaterThan(0), reason: 'la sonde a bien compté');
        expect(
          withScope,
          withoutScope,
          reason: 'élargir le domaine change ce que la recherche COMPARE, pas '
              'ce que l\'écran RECONSTRUIT',
        );
      },
    );

    testWidgets(
      'déclarer la seule sémantique de recherche N\'AJOUTE PAS de requête',
      (tester) async {
        Future<int> requestsFor(ZListQueryPolicy policy) async {
          // Démonte complètement l'arbre précédent : sans cela, la seconde
          // mesure hériterait de l'état de la première (mêmes éléments
          // réutilisés) et ne mesurerait plus la configuration déclarée.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          final repo = RecordingRepo(_seed);
          addTearDown(repo.dispose);
          await pumpScreen(
            tester,
            ZCrudScreen<Item>(
              title: 'Items',
              source: ZCrudSource<Item>.repository(repo),
              registry: buildItemRegistry(),
              query: policy,
            ),
          );
          await tester.pumpAndSettle();
          await searchInAppBar(tester, 'e');
          await tester.pumpAndSettle();
          return repo.requests.length;
        }

        expect(
          await requestsFor(
            const ZListQueryPolicy(searchScope: ZSearchScope.allColumns),
          ),
          await requestsFor(const ZListQueryPolicy()),
          reason: 'même nombre de lectures de la source : aucune passe '
              'supplémentaire',
        );
      },
    );
  });
}
