// Gardes du DOMAINE et de la NORMALISATION de la recherche de liste :
// `ZSearchScope` (colonnes interrogées) et `ZSearchFolding` (ce qui est ignoré
// en comparant), portés par `ZDataRequest` et servis par le moteur in-memory.
//
// Trois propriétés y sont mesurées, dans cet ordre :
//   1. NON-RÉGRESSION DU DÉFAUT — sans rien déclarer, le domaine reste les
//      seuls champs `searchable` et les blancs restent significatifs ;
//   2. `allColumns` retrouve le domaine des moteurs de liste historiques —
//      une valeur d'une colonne NON `searchable` devient trouvable ;
//   3. `diacriticsAndSpaces` fait correspondre « SARL U » et « sarlu ».
//
// Aucun import de renderer : moteur neutre uniquement.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Schéma de référence : `name` est cherchable, `siren` et `qty` ne le sont
/// PAS — c'est cette asymétrie que le domaine fait bouger.
const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'siren', type: EditionFieldType.text),
  ZFieldSpec(name: 'qty', type: EditionFieldType.integer),
];

ZListRow _row(String id, String name, String siren, int qty) => ZListRow(
      id: id,
      cells: <String, Object?>{'name': name, 'siren': siren, 'qty': qty},
    );

final List<ZListRow> _rows = <ZListRow>[
  _row('a', 'SOCIETE X SARL U', 'RC-2024-118', 3),
  _row('b', 'Comptoir Général', 'RC-2019-742', 7),
  _row('c', 'Établissements Müller', 'RC-2001-005', 93),
];

List<String> _ids(ZDataRequest request) => <String>[
      for (final row in zApplyListRequest(_rows, request, schema: _schema).rows)
        row.id,
    ];

class _Item implements ZEntity {
  const _Item(this._id);
  final String _id;
  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

/// Dépôt enregistreur : trace chaque `ZDataRequest` reçue et applique le moteur
/// neutre (donc honore le domaine et la normalisation portés par la requête).
class _RecordingRepo implements ZRepository<_Item> {
  final List<ZDataRequest> requests = <ZDataRequest>[];

  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    final page = zApplyListRequest(_rows, req, schema: _schema);
    return Right(<_Item>[for (final row in page.rows) _Item(row.id)]);
  }

  @override
  Stream<List<_Item>> watchAll() => const Stream<List<_Item>>.empty();
  @override
  Stream<List<_Item>> watch(ZDataRequest request) =>
      const Stream<List<_Item>>.empty();
  @override
  Future<ZResult<_Item>> getById(String id) async =>
      Left(ZNotFoundFailure('n/a', id: id));
  @override
  Future<ZResult<_Item>> save(_Item item, {String? collectionId}) async =>
      Right(item);
  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);
  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_rows.length);
  @override
  void dispose() {}
}

ZListController<_Item> _controller({
  ZSearchScope? scope,
  ZSearchFolding? folding,
  required _RecordingRepo repo,
}) =>
    ZListController<_Item>(
      repository: repo,
      toRow: (item) => _rows.firstWhere((row) => row.id == item.id),
      schema: _schema,
      searchScope: scope ?? ZSearchScope.searchableFields,
      searchFolding: folding ?? ZSearchFolding.diacritics,
    );

void main() {
  group('NON-RÉGRESSION DU DÉFAUT — rien de déclaré, rien de changé', () {
    test('une requête par défaut porte le domaine et le pliage historiques',
        () {
      const request = ZDataRequest();
      expect(request.searchScope, ZSearchScope.searchableFields);
      expect(request.searchFolding, ZSearchFolding.diacritics);
    });

    test('le pliage par défaut CONSERVE les blancs (texte exact)', () {
      expect(zFoldDiacritics('SARL U'), 'sarl u');
      expect(zFoldDiacritics('  Comptoir  Général  '), '  comptoir  general  ');
    });

    test(
      'une valeur d\'une colonne NON searchable n\'est PAS trouvable',
      () {
        // `siren` et `qty` ne sont pas `searchable` : leur contenu reste hors
        // du domaine de recherche.
        expect(_ids(const ZDataRequest(search: 'RC-2019')), <String>[]);
        expect(_ids(const ZDataRequest(search: '742')), <String>[]);
        // Contre-épreuve dans le même test : la colonne searchable, elle,
        // répond — le vide ci-dessus n'est pas un moteur muet.
        expect(_ids(const ZDataRequest(search: 'comptoir')), <String>['b']);
      },
    );

    test('« sarlu » ne trouve PAS « SARL U » par défaut', () {
      expect(_ids(const ZDataRequest(search: 'sarlu')), <String>[]);
      expect(_ids(const ZDataRequest(search: 'sarl u')), <String>['a']);
    });

    test(
      'un contrôleur sans réglage émet EXACTEMENT la requête d\'avant',
      () async {
        final repo = _RecordingRepo();
        final ctrl = _controller(repo: repo);
        addTearDown(ctrl.dispose);
        await Future<void>.delayed(Duration.zero);

        expect(repo.requests, isNotEmpty);
        expect(
          repo.requests.first,
          const ZDataRequest(),
          reason: 'égalité de VALEUR avec la requête neutre : les deux champs '
              'additifs sont à leur défaut',
        );
        expect(repo.requests.first.searchScope, ZSearchScope.searchableFields);
        expect(repo.requests.first.searchFolding, ZSearchFolding.diacritics);
      },
    );

    test('la valeur des deux réglages entre dans l\'égalité de la requête', () {
      expect(
        const ZDataRequest(searchScope: ZSearchScope.allColumns),
        isNot(const ZDataRequest()),
      );
      expect(
        const ZDataRequest(searchFolding: ZSearchFolding.diacriticsAndSpaces),
        isNot(const ZDataRequest()),
      );
      expect(
        const ZDataRequest(searchScope: ZSearchScope.allColumns)
            .copyWith(search: 'x')
            .searchScope,
        ZSearchScope.allColumns,
        reason: 'copyWith transporte le domaine (repli in-memory, loadMore)',
      );
    });
  });

  group('allColumns — le domaine des moteurs de liste historiques', () {
    test(
      'une valeur d\'une colonne NON searchable devient trouvable',
      () {
        expect(
          _ids(const ZDataRequest(
            search: 'RC-2019',
            searchScope: ZSearchScope.allColumns,
          )),
          <String>['b'],
        );
      },
    );

    test('une colonne non textuelle entre aussi dans le domaine', () {
      expect(
        _ids(const ZDataRequest(
          search: '93',
          searchScope: ZSearchScope.allColumns,
        )),
        <String>['c'],
      );
    });

    test('les colonnes searchable restent interrogées (rien n\'est perdu)', () {
      expect(
        _ids(const ZDataRequest(
          search: 'comptoir',
          searchScope: ZSearchScope.allColumns,
        )),
        <String>['b'],
      );
    });

    test('zMatchesSearch porte le domaine par paramètre', () {
      final row = _rows.first;
      expect(
        zMatchesSearch(row, 'RC-2024', schema: _schema),
        isFalse,
      );
      expect(
        zMatchesSearch(
          row,
          'RC-2024',
          schema: _schema,
          scope: ZSearchScope.allColumns,
        ),
        isTrue,
      );
    });
  });

  group('diacriticsAndSpaces — la normalisation des moteurs historiques', () {
    test('« sarlu » trouve « SOCIETE X SARL U »', () {
      expect(
        _ids(const ZDataRequest(
          search: 'sarlu',
          searchFolding: ZSearchFolding.diacriticsAndSpaces,
        )),
        <String>['a'],
      );
    });

    test('« SARL U » trouve une valeur écrite « sarlu » (les deux sens)', () {
      final row = ZListRow(
        id: 'z',
        cells: const <String, Object?>{'name': 'sarlu', 'siren': '', 'qty': 0},
      );
      expect(
        zMatchesSearch(
          row,
          'SARL U',
          schema: _schema,
          folding: ZSearchFolding.diacriticsAndSpaces,
        ),
        isTrue,
      );
    });

    test('les accents restent pliés, la ponctuation reste significative', () {
      expect(
        zFoldDiacritics(
          'Établissements  Müller',
          folding: ZSearchFolding.diacriticsAndSpaces,
        ),
        'etablissementsmuller',
      );
      expect(
        zFoldDiacritics(
          'RC-2019-742',
          folding: ZSearchFolding.diacriticsAndSpaces,
        ),
        'rc-2019-742',
      );
    });

    test('tabulation, saut de ligne et espace insécable sont des blancs', () {
      expect(
        zFoldDiacritics(
          'A\tB\nC D',
          folding: ZSearchFolding.diacriticsAndSpaces,
        ),
        'abcd',
      );
    });

    test('un terme fait de blancs seuls matche tout (aucun filtrage)', () {
      expect(
        _ids(const ZDataRequest(
          search: '   ',
          searchFolding: ZSearchFolding.diacriticsAndSpaces,
        )),
        <String>['a', 'b', 'c'],
      );
    });

    test('le pliage reste idempotent dans les deux modes', () {
      const input = 'Établissements  SARL U';
      for (final folding in ZSearchFolding.values) {
        final once = zFoldDiacritics(input, folding: folding);
        expect(zFoldDiacritics(once, folding: folding), once);
      }
    });
  });

  group('COMPOSITION — le domaine élargi cherche DANS ce qui reste', () {
    test('un filtre reste opposable à une recherche sur toutes colonnes', () {
      // Sans filtre, le domaine élargi trouve la ligne `b` par son `siren`.
      expect(
        _ids(const ZDataRequest(
          search: 'RC-2019',
          searchScope: ZSearchScope.allColumns,
        )),
        <String>['b'],
      );
      // Le filtre l'exclut : élargir le domaine ne fait pas rouvrir ce qu'un
      // filtre a fermé.
      expect(
        _ids(const ZDataRequest(
          filters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 8)],
          search: 'RC-2019',
          searchScope: ZSearchScope.allColumns,
        )),
        <String>[],
      );
    });

    test('le tri s\'applique au résultat élargi', () {
      expect(
        _ids(const ZDataRequest(
          search: 'RC-20',
          searchScope: ZSearchScope.allColumns,
          sorts: <ZSort>[ZSort('qty', ZSortDirection.desc)],
        )),
        <String>['c', 'b', 'a'],
      );
    });

    test(
      'un contrôleur déclarant porte les deux réglages dans CHAQUE requête, '
      'y compris après une recherche',
      () async {
        final repo = _RecordingRepo();
        final ctrl = _controller(
          repo: repo,
          scope: ZSearchScope.allColumns,
          folding: ZSearchFolding.diacriticsAndSpaces,
        );
        addTearDown(ctrl.dispose);
        await Future<void>.delayed(Duration.zero);
        ctrl.setSearch('sarlu');
        await Future<void>.delayed(Duration.zero);

        for (final request in repo.requests) {
          expect(request.searchScope, ZSearchScope.allColumns);
          expect(request.searchFolding, ZSearchFolding.diacriticsAndSpaces);
        }
        expect(repo.last.search, 'sarlu');
        // Et le résultat rendu suit le domaine : la ligne est retrouvée.
        final state = ctrl.state.value;
        expect(state, isA<ZListReady>());
        expect(
          <String>[for (final row in (state as ZListReady).rows) row.id],
          <String>['a'],
        );
      },
    );

    test(
      'la portée corbeille survit au domaine élargi (copyWith conserve les '
      'deux)',
      () {
        const request = ZDataRequest(
          deletedScope: ZDeletedScope.deletedOnly,
          searchScope: ZSearchScope.allColumns,
          searchFolding: ZSearchFolding.diacriticsAndSpaces,
        );
        final derived = request.copyWith(search: 'sarlu');
        expect(derived.deletedScope, ZDeletedScope.deletedOnly);
        expect(derived.searchScope, ZSearchScope.allColumns);
        expect(derived.searchFolding, ZSearchFolding.diacriticsAndSpaces);
      },
    );
  });
}
