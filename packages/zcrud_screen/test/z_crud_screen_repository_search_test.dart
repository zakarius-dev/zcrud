// Gardes de la RECHERCHE SUR LA VOIE DÉPÔT quand la source ne sait pas
// chercher (`ZDelegatesSearch`), et du mode de pagination déclaré
// (`ZListQueryPolicy.paginationMode`).
//
// Ce que ces gardes mesurent, sur ce qui est RENDU et sur les `ZDataRequest`
// réellement émises :
//   (a) un terme présent dans un champ `searchable` ne laisse que les lignes
//       correspondantes ;
//   (b) un terme absent rend la liste VIDE (`ZListNoResults`), et non la
//       totalité — le défaut mesuré chez l'hôte ;
//   (c) le pliage diacritique tient (« elephant » trouve « Éléphant ») ;
//   (d) la portée reste celle des champs `searchable` ;
//   (e) la voie `items` ne change EN RIEN (contre-témoin) ;
//   (f) la corbeille d'un tel dépôt cherche elle aussi ;
//   (g) sans recherche active, la voie curseur reste le chemin nominal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dépôt **aveugle à la recherche**, qui le DÉCLARE : il honore filtres, tri,
/// portée de suppression, limite et curseur, mais ignore
/// `ZDataRequest.search` — le comportement de l'adaptateur Firestore, sans
/// Firestore.
class BlindSearchRepo extends FakeItemRepo with ZDelegatesSearch<Item> {
  BlindSearchRepo(super.seed);

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  /// Dernière requête reçue.
  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    // Le terme est REÇU puis ignoré : c'est là tout le défaut.
    return super.getAll(request: req.copyWith(search: null));
  }
}

/// Le même dépôt SANS la capacité — il honore la recherche, comme n'importe
/// quel dépôt en mémoire. Contre-témoin de la bascule.
class ServingSearchRepo extends FakeItemRepo {
  ServingSearchRepo(super.seed);

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

const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'Éléphant', qty: 1),
  Item(id: 'b', name: 'Girafe', qty: 2),
  Item(id: 'c', name: 'Zèbre', qty: 3),
];

/// Titres des tuiles rendues, dans l'ordre.
List<String> _rendered(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  group('voie dépôt — une source qui ne sait pas chercher est filtrée par le '
      'socle', () {
    testWidgets('un terme présent ne laisse que les lignes correspondantes',
        (tester) async {
      final repo = BlindSearchRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      await searchInAppBar(tester, 'Girafe');
      await tester.pumpAndSettle();

      expect(_rendered(tester), <String>['Girafe']);
    });

    testWidgets(
      'un terme ABSENT rend la liste vide, et non la totalité',
      (tester) async {
        final repo = BlindSearchRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
          ),
        );
        await searchInAppBar(tester, 'xyzzy-introuvable');
        await tester.pumpAndSettle();

        expect(
          _rendered(tester),
          <String>[],
          reason: 'une barre inerte laisserait les 3 lignes en place',
        );
      },
    );

    testWidgets('pliage diacritique : « elephant » trouve « Éléphant »',
        (tester) async {
      final repo = BlindSearchRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      await searchInAppBar(tester, 'elephant');
      await tester.pumpAndSettle();

      expect(_rendered(tester), <String>['Éléphant']);
    });

    testWidgets(
      'la portée reste celle des champs searchable : une valeur d\'une colonne '
      'NON searchable reste introuvable',
      (tester) async {
        final repo = BlindSearchRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
          ),
        );
        // `qty` n'est pas `searchable` (cf. `itemSpecs`).
        await searchInAppBar(tester, '3');
        await tester.pumpAndSettle();

        expect(_rendered(tester), <String>[]);
      },
    );

    testWidgets(
      'CORBEILLE : la vue corbeille d\'un tel dépôt cherche elle aussi',
      (tester) async {
        final repo = BlindSearchRepo(_seed);
        addTearDown(repo.dispose);
        await repo.softDelete('a');
        await repo.softDelete('b');
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
          ),
        );
        await openTrashView(tester);
        await searchInAppBar(tester, 'elephant');
        await tester.pumpAndSettle();

        expect(
          _rendered(tester),
          <String>['Éléphant'],
          reason: 'la corbeille reste la corbeille, et elle filtre',
        );
      },
    );

    testWidgets(
      'sans recherche active, la voie curseur reste le chemin nominal',
      (tester) async {
        final repo = BlindSearchRepo(_seed);
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

        expect(
          repo.last.limit,
          2,
          reason: 'aucune lecture du jeu entier tant que rien n\'est cherché',
        );

        await searchInAppBar(tester, 'elephant');
        await tester.pumpAndSettle();
        expect(
          repo.last.limit,
          isNull,
          reason: 'la recherche — et elle seule — fait partir la requête NON '
              'paginée',
        );

        await searchInAppBar(tester, '');
        await tester.pumpAndSettle();
        expect(
          repo.last.limit,
          2,
          reason: 'terme effacé : retour immédiat au chemin paginé',
        );
      },
    );
  });

  group('CONTRE-TÉMOIN — rien ne change là où rien n\'était cassé', () {
    testWidgets(
      'voie items : la recherche se comporte exactement comme avant',
      (tester) async {
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: const ZCrudSource<Item>.items(_seed),
            registry: buildItemRegistry(),
          ),
        );
        await searchInAppBar(tester, 'elephant');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>['Éléphant']);

        await searchInAppBar(tester, 'xyzzy-introuvable');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>[]);

        await searchInAppBar(tester, '');
        await tester.pumpAndSettle();
        expect(
          _rendered(tester),
          <String>['Éléphant', 'Girafe', 'Zèbre'],
          reason: 'terme effacé : la liste entière revient',
        );
      },
    );

    testWidgets(
      'dépôt qui SERT la recherche : sa requête part paginée, terme compris',
      (tester) async {
        final repo = ServingSearchRepo(_seed);
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
        await searchInAppBar(tester, 'elephant');
        await tester.pumpAndSettle();

        expect(repo.last.search, 'elephant');
        expect(
          repo.last.limit,
          2,
          reason: 'aucune bascule : le dépôt sait chercher',
        );
        expect(_rendered(tester), <String>['Éléphant']);
      },
    );
  });

  group('paginationMode déclaré — l\'échappatoire immédiate', () {
    testWidgets(
      'inMemory : filtres, tri et recherche redeviennent exacts sur une source '
      'qui n\'en sert aucun',
      (tester) async {
        final repo = BlindSearchRepo(_seed);
        addTearDown(repo.dispose);
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            // La taille de page est déclarée EN MÊME TEMPS : c'est ce qui
            // rend le mode observable — sans lui, une requête non paginée ne
            // prouverait rien (elle l'est déjà par défaut).
            query: const ZListQueryPolicy(
              pageSize: 2,
              paginationMode: ZListPaginationMode.inMemory,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          repo.last.limit,
          isNull,
          reason: 'le mode déclaré lit le jeu entier dès la première requête, '
              'et pagine ensuite en mémoire',
        );
        expect(
          _rendered(tester).length,
          2,
          reason: 'la pagination reste servie — en mémoire',
        );

        await searchInAppBar(tester, 'zebre');
        await tester.pumpAndSettle();
        expect(_rendered(tester), <String>['Zèbre']);
      },
    );

    testWidgets(
      'une politique qui ne déclare QUE le mode par défaut ne déclare rien',
      (tester) async {
        expect(
          const ZListQueryPolicy(
            paginationMode: ZListPaginationMode.backendCursor,
          ).declaresNothing,
          isTrue,
        );
        expect(
          const ZListQueryPolicy(
            paginationMode: ZListPaginationMode.inMemory,
          ).declaresNothing,
          isFalse,
        );
        expect(
          const ZListQueryPolicy(
                paginationMode: ZListPaginationMode.inMemory,
              ) ==
              const ZListQueryPolicy(),
          isFalse,
          reason: 'le mode entre dans l\'égalité de valeur',
        );
      },
    );
  });
}
