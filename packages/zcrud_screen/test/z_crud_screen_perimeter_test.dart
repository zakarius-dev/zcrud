// Gardes du PÉRIMÈTRE NON REQUÊTABLE d'un écran assemblé : post-filtre
// (`ZListQueryPolicy.itemFilter`, `ZListTab.itemFilter`) et disjonctions
// (`baseFilterGroups`).
//
// Ce que ces gardes tiennent :
//   * 🔴 « cet état OU ce champ absent » : l'entité dont le champ n'a jamais
//     été renseigné apparaît bien dans l'onglet d'entrée du workflow ;
//   * un post-filtre RESTREINT : jamais une ligne de plus que la voie `items`
//     où l'application filtrait elle-même ;
//   * 🔴 déclarer un post-filtre BASCULE le listing sur le chemin mémoire —
//     l'assertion porte sur ce qui est réellement demandé au dépôt
//     (`request.limit`), pas sur l'affichage ;
//   * un écran SANS post-filtre garde exactement le comportement d'avant,
//     pagination serveur comprise (contre-témoin) ;
//   * le post-filtre s'applique AVANT la pagination : la page reste pleine ;
//   * la gouvernance par ligne continue de restreindre sans élargir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dépôt **enregistreur** : le fake neutre des fixtures, plus la trace de
/// chaque `ZDataRequest` reçue.
class _RecordingRepo extends FakeItemRepo {
  _RecordingRepo(super.seed);

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

/// L'**état** métier d'un rapport, encodé dans `qty` faute d'un champ dédié
/// dans la fixture partagée : `1` = en attente, `2` = clos, `0` = **jamais
/// renseigné** (le rapport vient d'être déposé, personne ne l'a encore touché).
String? _etat(Item item) => switch (item.qty) {
      1 => 'enAttente',
      2 => 'clos',
      _ => null,
    };

/// Schéma de liste portant la colonne `etat`, absente de la fixture partagée.
const _specs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'etat', type: EditionFieldType.text),
];

/// Projection en cellules : `etat` vaut `null` pour le rapport jamais touché.
Map<String, Object?> _cells(Item item) => <String, Object?>{
      'id': item.id,
      'name': item.name,
      'etat': _etat(item),
    };

/// « En attente », c'est l'état déclaré **ou** l'absence d'état.
const _enAttente = <ZFilterGroup>[
  ZFilterGroup.any(<ZFilter>[
    ZFilter('etat', ZFilterOp.eq, 'enAttente'),
    ZFilter('etat', ZFilterOp.isNull),
  ]),
];

const _seed = <Item>[
  Item(id: 'r1', name: 'Alpha', qty: 1), // en attente
  Item(id: 'r2', name: 'Bravo', qty: 2), // clos
  Item(id: 'r3', name: 'Charlie'), // état JAMAIS renseigné
];

/// Règle métier que nulle clause n'exprime : ce que l'application seule sait.
bool _pasBravo(Item item) => item.name != 'Bravo';

/// Seconde règle, pour la cascade écran → onglet.
bool _pasCharlie(Item item) => item.name != 'Charlie';

Widget _screen(
  ZRepository<Item> repo, {
  ZListQueryPolicy query = const ZListQueryPolicy(),
  List<ZListTab>? tabs,
  ZRowAclResolver<Item>? rowAcl,
}) =>
    ZCrudScreen<Item>(
      title: 'Rapports',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      listFields: _specs,
      cellsOf: _cells,
      rowAcl: rowAcl,
      canDuplicate: false,
      query: query,
      tabs: tabs,
    );

List<String> _titres(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  group('🔴 « cet état OU ce champ absent »', () {
    testWidgets(
        'l\'onglet d\'entrée du workflow montre le rapport dont le champ n\'a '
        'JAMAIS été renseigné', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          tabs: const <ZListTab>[
            ZListTab(labelKey: 'En attente', baseFilterGroups: _enAttente),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(_titres(tester), <String>['Alpha', 'Charlie']);
      expect(find.text('Bravo'), findsNothing);
    });

    testWidgets(
        'CONTRE-TÉMOIN : la même catégorie en simple égalité perd le rapport '
        'au champ absent', (tester) async {
      // Voie `items` : les deux formulations sont comparées sur le MÊME jeu et
      // le même moteur, la seule variable étant conjonction vs disjonction.
      await pumpScreen(
        tester,
        const ZCrudScreen<Item>(
          title: 'Rapports',
          source: ZCrudSource<Item>.items(_seed),
          listFields: _specs,
          cellsOf: _cells,
          query: ZListQueryPolicy(
            baseFilters: <ZFilter>[ZFilter('etat', ZFilterOp.eq, 'enAttente')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _titres(tester),
        <String>['Alpha'],
        reason: 'c\'est la disparition silencieuse que la disjonction corrige',
      );

      await pumpScreen(
        tester,
        const ZCrudScreen<Item>(
          title: 'Rapports',
          source: ZCrudSource<Item>.items(_seed),
          listFields: _specs,
          cellsOf: _cells,
          query: ZListQueryPolicy(baseFilterGroups: _enAttente),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _titres(tester),
        <String>['Alpha', 'Charlie'],
        reason: 'la voie items sert la disjonction, comme la voie dépôt',
      );
    });

    testWidgets('la disjonction est déclarable sur l\'écran entier',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, query: const ZListQueryPolicy(baseFilterGroups: _enAttente)),
      );
      await tester.pumpAndSettle();

      expect(_titres(tester), <String>['Alpha', 'Charlie']);
    });
  });

  group('Le post-filtre RESTREINT, il n\'élargit jamais', () {
    testWidgets(
        'voie dépôt + post-filtre = voie items où l\'application filtrait '
        'elle-même', (tester) async {
      // Voie `items` : l'application remet une liste DÉJÀ constituée.
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Rapports',
          source: ZCrudSource<Item>.items(
            <Item>[for (final item in _seed) if (_pasBravo(item)) item],
          ),
          listFields: _specs,
          cellsOf: _cells,
        ),
      );
      await tester.pumpAndSettle();
      final parItems = _titres(tester);
      expect(parItems, <String>['Alpha', 'Charlie']);

      // Voie dépôt : le jeu complet, et la MÊME règle déclarée.
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasBravo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(_titres(tester), parItems);
      expect(_titres(tester).length, lessThanOrEqualTo(parItems.length));
    });

    testWidgets('jamais plus de lignes que sans post-filtre', (tester) async {
      final repoSans = _RecordingRepo(_seed);
      addTearDown(repoSans.dispose);
      await pumpScreen(tester, _screen(repoSans));
      await tester.pumpAndSettle();
      final sans = _titres(tester);

      final repoAvec = _RecordingRepo(_seed);
      addTearDown(repoAvec.dispose);
      await pumpScreen(
        tester,
        _screen(
          repoAvec,
          query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasBravo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(_titres(tester).length, lessThan(sans.length));
      expect(sans.toSet().containsAll(_titres(tester)), isTrue);
    });

    testWidgets('l\'onglet ne peut que retirer davantage que l\'écran',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasBravo)),
          tabs: <ZListTab>[
            ZListTab(
              labelKey: 'Restreint',
              itemFilter: ZItemFilter.of(_pasCharlie),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _titres(tester),
        <String>['Alpha'],
        reason: 'les deux post-filtres s\'appliquent : l\'onglet retire, il ne '
            'rouvre pas ce que l\'écran a écarté',
      );
    });
  });

  group('🔴 Ce qui est réellement demandé au dépôt', () {
    testWidgets('déclarer un post-filtre retire la pagination de la requête',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: ZListQueryPolicy(
            pageSize: 2,
            itemFilter: ZItemFilter.of(_pasBravo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.requests, isNotEmpty);
      expect(
        repo.last.limit,
        isNull,
        reason: 'sans cette bascule, le post-filtre serait silencieusement '
            'ignoré par la pagination curseur',
      );
    });

    testWidgets('déclarer une disjonction bascule de même', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: const ZListQueryPolicy(
            pageSize: 2,
            baseFilterGroups: _enAttente,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.last.limit, isNull);
      expect(repo.last.filterGroups, _enAttente);
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans post-filtre ni disjonction, la pagination '
        'serveur est intacte', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, query: const ZListQueryPolicy(pageSize: 2)),
      );
      await tester.pumpAndSettle();

      expect(repo.requests.first.limit, 2);
      expect(repo.requests.first.filterGroups, isEmpty);
      expect(find.byType(ListTile), findsNWidgets(2));
    });
  });

  group('Le post-filtre s\'applique AVANT la pagination', () {
    testWidgets(
        'pageSize 2 et un élément retiré sur cinq ⇒ la première page en '
        'contient 2, pas 1', (tester) async {
      const cinq = <Item>[
        Item(id: 'i1', name: 'Un'),
        Item(id: 'i2', name: 'Bravo'), // le seul écarté
        Item(id: 'i3', name: 'Trois'),
        Item(id: 'i4', name: 'Quatre'),
        Item(id: 'i5', name: 'Cinq'),
      ];
      final repo = _RecordingRepo(cinq);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: ZListQueryPolicy(
            pageSize: 2,
            sort: const <ZSort>[ZSort('id')],
            itemFilter: ZItemFilter.of(_pasBravo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _titres(tester),
        <String>['Un', 'Trois'],
        reason: 'l\'écarté n\'occupe pas une place dans la page',
      );
    });
  });

  group('Non-régression de la gouvernance par ligne', () {
    testWidgets(
        'une ligne verrouillée le reste sous un post-filtre — il restreint, '
        'il ne rouvre rien', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasBravo)),
          rowAcl: (item) => item.name == 'Charlie'
              ? const ZRowPermissions.locked(reasonKey: 'Dossier clôturé')
              : const ZRowPermissions.unrestricted(),
        ),
      );
      await tester.pumpAndSettle();

      expect(_titres(tester), <String>['Alpha', 'Charlie']);
      expect(
        find.byIcon(Icons.edit_outlined),
        findsOneWidget,
        reason: 'Alpha reste modifiable, Charlie non : la gouvernance par '
            'ligne n\'a pas bougé',
      );
    });
  });

  group('Règles de composition, isolées', () {
    test('filterGroupsWith ajoute, itemFilterWith compose en conjonction', () {
      final ecran = ZListQueryPolicy(
        baseFilterGroups: _enAttente,
        itemFilter: ZItemFilter.of(_pasBravo),
      );
      const autre = ZFilterGroup.any(<ZFilter>[
        ZFilter('name', ZFilterOp.eq, 'Alpha'),
      ]);

      expect(
        ecran.filterGroupsWith(const <ZFilterGroup>[autre]),
        <ZFilterGroup>[..._enAttente, autre],
      );
      expect(
        ecran.filterGroupsWith(const <ZFilterGroup>[]),
        ecran.baseFilterGroups,
      );

      final compose = ecran.itemFilterWith(ZItemFilter.of(_pasCharlie))!;
      expect(compose.keeps(const Item(id: 'x', name: 'Alpha')), isTrue);
      expect(compose.keeps(const Item(id: 'x', name: 'Bravo')), isFalse);
      expect(compose.keeps(const Item(id: 'x', name: 'Charlie')), isFalse);
      expect(
        const ZListQueryPolicy().itemFilterWith(null),
        isNull,
        reason: 'rien de déclaré, rien de composé',
      );
    });

    test('une politique qui ne déclare que ces réglages ne déclare pas RIEN',
        () {
      expect(const ZListQueryPolicy().declaresNothing, isTrue);
      expect(
        const ZListQueryPolicy(baseFilterGroups: _enAttente).declaresNothing,
        isFalse,
      );
      expect(
        ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasBravo))
            .declaresNothing,
        isFalse,
      );
    });

    test('égalité de valeur : deux politiques identiques ne reconstruisent '
        'rien', () {
      final a = ZListQueryPolicy(
        baseFilterGroups: _enAttente,
        itemFilter: ZItemFilter.of(_pasBravo),
      );
      final b = ZListQueryPolicy(
        baseFilterGroups: _enAttente,
        itemFilter: ZItemFilter.of(_pasBravo),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(ZListQueryPolicy(itemFilter: ZItemFilter.of(_pasCharlie))),
      );
      expect(a.copyWith(pageSize: 10).itemFilter, a.itemFilter);
      expect(a.toString(), contains('baseFilterGroups'));
    });
  });
}
