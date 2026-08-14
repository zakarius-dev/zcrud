// Gardes du POST-FILTRE (`ZListController.itemFilter`) et des DISJONCTIONS
// persistantes (`baseFilterGroups`) du contrôleur de liste.
//
// Ce que ces gardes tiennent :
//   * 🔴 déclarer un post-filtre (ou une disjonction non inerte) BASCULE le
//     listing sur le chemin mémoire — l'assertion porte sur ce qui est
//     RÉELLEMENT demandé au dépôt (`request.limit`), pas sur l'affichage : une
//     déclaration ignorée par la pagination curseur montrerait à l'usager plus
//     que ce que l'écran a autorisé ;
//   * le post-filtre s'applique AVANT la pagination : une page pleine reste
//     pleine ;
//   * il ne peut que RESTREINDRE : jamais une ligne de plus que sans lui ;
//   * un listing qui n'en déclare pas garde la pagination serveur, à
//     l'identique (contre-témoin).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'etat', type: EditionFieldType.text),
];

class _Item implements ZEntity {
  const _Item(this._id, this.name, {this.etat, this.confidentiel = false});
  final String _id;
  final String name;
  final String? etat;

  /// Ce que seule l'application sait : aucune clause ne l'exprime.
  final bool confidentiel;

  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

ZListRow _toRow(_Item item) => ZListRow(
      id: item.id!,
      cells: <String, Object?>{'name': item.name, 'etat': item.etat},
    );

/// Cinq éléments, dont **un** que le métier écarte.
const _seed = <_Item>[
  _Item('p0', 'P0'),
  _Item('p1', 'P1', confidentiel: true),
  _Item('p2', 'P2'),
  _Item('p3', 'P3'),
  _Item('p4', 'P4'),
];

/// Dépôt **enregistreur** honorant la requête via le moteur du socle, sauf les
/// disjonctions : un adaptateur qui ne sait pas les traduire les ignore, et
/// c'est bien ce cas-là qu'il faut mesurer.
class _RecordingRepo implements ZRepository<_Item> {
  _RecordingRepo(this._data);

  final List<_Item> _data;
  final StreamController<List<_Item>> _changes =
      StreamController<List<_Item>>.broadcast();

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    final page = zApplyListRequest(
      <ZListRow>[for (final item in _data) _toRow(item)],
      req.copyWith(filterGroups: const <ZFilterGroup>[]),
      schema: _schema,
    );
    final byId = <String, _Item>{for (final item in _data) item.id!: item};
    return Right(<_Item>[for (final row in page.rows) byId[row.id]!]);
  }

  @override
  Stream<List<_Item>> watchAll() => _changes.stream;

  @override
  Stream<List<_Item>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

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
  void dispose() => unawaited(_changes.close());
}

/// Prédicat métier : ce que la source ne sait pas dire.
bool _nonConfidentiel(_Item item) => !item.confidentiel;

List<String> _ids(ZListController<_Item> controller) {
  final state = controller.state.value;
  return state is ZListReady
      ? <String>[for (final row in state.rows) row.id]
      : const <String>[];
}

ZListController<_Item> _controller(
  _RecordingRepo repo, {
  int? pageSize,
  bool Function(_Item item)? itemFilter,
  List<ZFilterGroup> baseFilterGroups = const <ZFilterGroup>[],
}) =>
    ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: pageSize,
      itemFilter: itemFilter,
      baseFilterGroups: baseFilterGroups,
    );

void main() {
  group('🔴 Bascule sur le chemin mémoire (ce qui est demandé au dépôt)', () {
    testWidgets('déclarer un post-filtre retire la pagination de la requête',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller =
          _controller(repo, pageSize: 2, itemFilter: _nonConfidentiel);
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.requests, isNotEmpty);
      expect(
        repo.last.limit,
        isNull,
        reason: 'le jeu est lu NON paginé : sinon le post-filtre trouerait '
            'les pages, ou serait purement ignoré',
      );
      expect(repo.last.startAfter, isNull);
    });

    testWidgets('déclarer une disjonction NON INERTE bascule de même',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller = _controller(
        repo,
        pageSize: 2,
        baseFilterGroups: const <ZFilterGroup>[
          ZFilterGroup.any(<ZFilter>[
            ZFilter('etat', ZFilterOp.eq, 'enAttente'),
            ZFilter('etat', ZFilterOp.isNull),
          ]),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.last.limit, isNull);
      expect(
        repo.last.filterGroups,
        isNotEmpty,
        reason: 'le groupe voyage tout de même : un dépôt qui sait le traduire '
            'y gagne',
      );
    });

    testWidgets('une disjonction INERTE ne coûte rien : pagination conservée',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller = _controller(
        repo,
        pageSize: 2,
        baseFilterGroups: const <ZFilterGroup>[ZFilterGroup.any(<ZFilter>[])],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.last.limit, 2);
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans post-filtre ni disjonction, la pagination '
        'serveur est intacte', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller = _controller(repo, pageSize: 2);
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.last.limit, 2);
      expect(_ids(controller), <String>['p0', 'p1']);
    });
  });

  group('Le post-filtre s\'applique AVANT la pagination', () {
    testWidgets(
        'pageSize 2 + un élément retiré sur cinq ⇒ la première page en '
        'contient 2, pas 1', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller =
          _controller(repo, pageSize: 2, itemFilter: _nonConfidentiel);
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        _ids(controller),
        <String>['p0', 'p2'],
        reason: 'p1 est écarté AVANT la découpe en pages : la page reste '
            'pleine, et ne laisse pas un trou à la place de l\'écarté',
      );
    });

    testWidgets('la page suivante enchaîne sans trou ni doublon',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller =
          _controller(repo, pageSize: 2, itemFilter: _nonConfidentiel);
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      await controller.loadMore();
      await tester.pumpAndSettle();
      expect(_ids(controller), <String>['p0', 'p2', 'p3', 'p4']);
    });
  });

  group('Il RESTREINT, il n\'élargit jamais', () {
    testWidgets('jamais plus de lignes qu\'un listing sans post-filtre',
        (tester) async {
      final repoSans = _RecordingRepo(_seed);
      final repoAvec = _RecordingRepo(_seed);
      addTearDown(repoSans.dispose);
      addTearDown(repoAvec.dispose);
      final sans = _controller(repoSans);
      final avec = _controller(repoAvec, itemFilter: _nonConfidentiel);
      addTearDown(sans.dispose);
      addTearDown(avec.dispose);
      await tester.pumpAndSettle();

      expect(_ids(avec).length, lessThanOrEqualTo(_ids(sans).length));
      expect(_ids(sans).toSet().containsAll(_ids(avec)), isTrue);
      expect(_ids(avec), isNot(contains('p1')));
    });

    testWidgets('un post-filtre TOUT PERMISSIF ne retire rien', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller = _controller(repo, itemFilter: (_) => true);
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(_ids(controller).length, _seed.length);
    });

    testWidgets('le prédicat reçoit l\'ENTITÉ, pas la ligne', (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final vus = <_Item>[];
      final controller = _controller(
        repo,
        itemFilter: (item) {
          vus.add(item);
          return true;
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(vus.length, _seed.length);
      expect(
        vus.map((item) => item.confidentiel),
        contains(true),
        reason: 'le prédicat lit une propriété qui n\'existe dans AUCUNE '
            'cellule — c\'est tout l\'objet du post-filtre',
      );
    });
  });

  group('Composition avec le reste de la requête', () {
    testWidgets('les filtres de base et le post-filtre s\'ajoutent',
        (tester) async {
      final repo = _RecordingRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        baseFilters: const <ZFilter>[ZFilter('name', ZFilterOp.neq, 'P4')],
        itemFilter: _nonConfidentiel,
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(_ids(controller), <String>['p0', 'p2', 'p3']);
      expect(
        repo.last.filters,
        <ZFilter>[const ZFilter('name', ZFilterOp.neq, 'P4')],
      );
    });

    testWidgets('la disjonction est appliquée par le socle quand le dépôt '
        'l\'ignore', (tester) async {
      const seed = <_Item>[
        _Item('a', 'A', etat: 'enAttente'),
        _Item('b', 'B', etat: 'clos'),
        _Item('c', 'C'),
      ];
      final repo = _RecordingRepo(seed);
      addTearDown(repo.dispose);
      final controller = _controller(
        repo,
        baseFilterGroups: const <ZFilterGroup>[
          ZFilterGroup.any(<ZFilter>[
            ZFilter('etat', ZFilterOp.eq, 'enAttente'),
            ZFilter('etat', ZFilterOp.isNull),
          ]),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        _ids(controller),
        <String>['a', 'c'],
        reason: 'le dépôt a rendu les trois : c\'est le socle qui tranche',
      );
    });
  });

  group('ZItemFilter — le porteur déclaratif', () {
    test('retient sur l\'entité typée et compose en conjonction', () {
      final pasConfidentiel = ZItemFilter.of<_Item>((item) => !item.confidentiel);
      final commenceParP = ZItemFilter.of<_Item>((item) => item.name.startsWith('P'));
      expect(pasConfidentiel.keeps(const _Item('x', 'X')), isTrue);
      expect(
        pasConfidentiel.keeps(const _Item('x', 'X', confidentiel: true)),
        isFalse,
      );

      final compose = ZItemFilter.every(<ZItemFilter?>[
        pasConfidentiel,
        commenceParP,
      ])!;
      expect(compose.keeps(const _Item('x', 'P9')), isTrue);
      expect(compose.keeps(const _Item('x', 'Q9')), isFalse);
      expect(
        compose.keeps(const _Item('x', 'P9', confidentiel: true)),
        isFalse,
        reason: 'chaque niveau ne peut que retirer',
      );
    });

    test('sans aucun filtre déclaré, la composition est nulle', () {
      expect(ZItemFilter.every(const <ZItemFilter?>[null, null]), isNull);
      final seul = ZItemFilter.of<_Item>(_nonConfidentiel);
      expect(ZItemFilter.every(<ZItemFilter?>[null, seul]), seul);
    });

    test('égalité portée par le prédicat : une fonction nommée reste égale '
        'à elle-même', () {
      expect(
        ZItemFilter.of<_Item>(_nonConfidentiel),
        ZItemFilter.of<_Item>(_nonConfidentiel),
        reason: 'sans quoi le listing se reconstruirait à chaque image',
      );
      expect(
        ZItemFilter.of<_Item>(_nonConfidentiel).hashCode,
        ZItemFilter.of<_Item>(_nonConfidentiel).hashCode,
      );
      expect(
        ZItemFilter.of<_Item>((item) => !item.confidentiel),
        isNot(ZItemFilter.of<_Item>((item) => !item.confidentiel)),
        reason: 'deux lambdas distinctes sont deux prédicats distincts — d\'où '
            'la consigne de les déclarer hors du build',
      );
    });

    test('déclaré sur un autre type que celui du listing : l\'entité est '
        'écartée, et la faute est signalée en développement', () {
      final filtre = ZItemFilter.of<_Item>(_nonConfidentiel);
      expect(() => filtre.keeps('pas une entité'), throwsAssertionError);
    });
  });
}
