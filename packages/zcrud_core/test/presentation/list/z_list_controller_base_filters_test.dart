// AC2/AC10 (E4-5, AD-2/AD-16) : `baseFilters` PERSISTANTS sur `ZListController`.
//
// Le socle `baseFilters` est TOUJOURS ANDé EN TÊTE des filtres utilisateur dans
// CHAQUE `ZDataRequest` émis (première page + `loadMore`, via `_buildRequest`
// unique). `setFilters`/`setSearch`/`setSort` composent EN PLUS — jamais
// n'écrasent la relation/catégorie. Rétro-compatibilité stricte : `baseFilters`
// vide ⇒ requêtes IDENTIQUES à E4-3. Fake `ZRepository` enregistrant les
// `ZDataRequest`. AUCUN import `zcrud_list`/Syncfusion (SM-5 exécutable).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'status', type: EditionFieldType.text),
  ZFieldSpec(name: 'parentId', type: EditionFieldType.text),
];

class _Item implements ZEntity {
  const _Item(this._id);
  final String _id;
  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

ZListRow _toRow(_Item it) =>
    ZListRow(id: it.id!, cells: <String, Object?>{'name': it.id});

/// Fake enregistrant chaque `ZDataRequest` reçu (`requests`) et honorant la
/// pagination (retourne des pages pour prouver la composition sur `loadMore`).
class _RecordingRepo implements ZRepository<_Item> {
  _RecordingRepo(this._total);

  final int _total;
  final List<ZDataRequest> requests = <ZDataRequest>[];

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    // Honore la pagination pour permettre un `loadMore` (page pleine).
    final limit = req.limit;
    final items = <_Item>[for (var i = 0; i < _total; i++) _Item('p$i')];
    if (limit == null) return Right(items);
    final start = req.startAfter == null ? 0 : limit; // 2 pages max, simplifié
    final page = items.skip(start).take(limit).toList();
    return Right(page);
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
  Future<ZResult<int>> count({ZDataRequest? request}) async => Right(_total);
  @override
  void dispose() {}
}

const _relation = ZFilter('parentId', ZFilterOp.eq, 'p1');

void main() {
  group('baseFilters PERSISTANTS (E4-5, AC2)', () {
    test('la relation est ANDée EN TÊTE dès la première requête', () async {
      final repo = _RecordingRepo(3);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        baseFilters: const <ZFilter>[_relation],
      );
      await pumpEventQueue();
      expect(repo.requests, isNotEmpty);
      expect(repo.requests.last.filters, <ZFilter>[_relation]);
      ctrl.dispose();
    });

    test('setFilters COMPOSE avec baseFilters (ne remplace pas la relation)',
        () async {
      final repo = _RecordingRepo(3);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        baseFilters: const <ZFilter>[_relation],
      );
      await pumpEventQueue();
      const userFilter = ZFilter('status', ZFilterOp.eq, 'open');
      ctrl.setFilters(const <ZFilter>[userFilter]);
      await pumpEventQueue();
      // base d'abord, filtre utilisateur ensuite.
      expect(repo.requests.last.filters, <ZFilter>[_relation, userFilter]);
      ctrl.dispose();
    });

    test('setSearch/setSort CONSERVENT baseFilters', () async {
      final repo = _RecordingRepo(3);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        baseFilters: const <ZFilter>[_relation],
      );
      await pumpEventQueue();
      ctrl.setSearch('x');
      await pumpEventQueue();
      expect(repo.requests.last.filters, <ZFilter>[_relation]);
      expect(repo.requests.last.search, 'x');

      ctrl.setSort(const <ZSort>[ZSort('name')]);
      await pumpEventQueue();
      expect(repo.requests.last.filters, <ZFilter>[_relation]);
      expect(repo.requests.last.sorts, const <ZSort>[ZSort('name')]);
      ctrl.dispose();
    });

    test('loadMore CONSERVE baseFilters sur la page suivante', () async {
      final repo = _RecordingRepo(4);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        pageSize: 2,
        baseFilters: const <ZFilter>[_relation],
      );
      await pumpEventQueue();
      await ctrl.loadMore();
      await pumpEventQueue();
      // Une requête avec startAfter (page 2) doit encore porter la relation.
      final paged =
          repo.requests.where((r) => r.startAfter != null).toList();
      expect(paged, isNotEmpty);
      for (final r in paged) {
        expect(r.filters, <ZFilter>[_relation]);
      }
      ctrl.dispose();
    });

    test('setFilters COMPOSE aussi en mode inMemory (repli honoré)', () async {
      final repo = _RecordingRepo(3);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        mode: ZListPaginationMode.inMemory,
        baseFilters: const <ZFilter>[_relation],
      );
      await pumpEventQueue();
      const userFilter = ZFilter('status', ZFilterOp.eq, 'open');
      ctrl.setFilters(const <ZFilter>[userFilter]);
      await pumpEventQueue();
      // Le repli in-memory reçoit le MÊME `ZDataRequest` composé (filtres portés).
      expect(
        repo.requests.any(
          (r) => r.filters.length == 2 &&
              r.filters.first == _relation &&
              r.filters.last == userFilter,
        ),
        isTrue,
      );
      ctrl.dispose();
    });
  });

  group('Rétro-compatibilité E4-3 (baseFilters vide, AC2)', () {
    test('sans baseFilters : requêtes IDENTIQUES aux filtres utilisateur seuls',
        () async {
      final repo = _RecordingRepo(3);
      final ctrl = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
      );
      await pumpEventQueue();
      // Première requête : aucun filtre (comme E4-3).
      expect(repo.requests.last.filters, isEmpty);

      const userFilter = ZFilter('status', ZFilterOp.eq, 'open');
      ctrl.setFilters(const <ZFilter>[userFilter]);
      await pumpEventQueue();
      // setFilters REMPLACE (E4-3) : exactement le filtre utilisateur, rien de plus.
      expect(repo.requests.last.filters, const <ZFilter>[userFilter]);
      ctrl.dispose();
    });
  });
}
