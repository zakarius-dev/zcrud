// Le contrôleur de liste sait NAÎTRE TRIÉ (`initialSorts`).
//
// La PREMIÈRE requête — celle que la construction émet — porte le tri déclaré.
// Sans ce seam, seul `setSort` existait : appelé après coup, il laissait partir
// une première requête non triée puis en émettait une seconde (une lecture de
// source pour rien, et un premier rendu dans le mauvais ordre).
//
// CONTRE-TÉMOIN : sans déclaration, la requête est celle d'avant à l'identique.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
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

class _RecordingRepo implements ZRepository<_Item> {
  final List<ZDataRequest> requests = <ZDataRequest>[];

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    requests.add(request ?? const ZDataRequest());
    return const Right(<_Item>[_Item('a'), _Item('b')]);
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
  Future<ZResult<int>> count({ZDataRequest? request}) async => const Right(2);
  @override
  void dispose() {}
}

const _byName = ZSort('name');
const _byNameDesc = ZSort('name', ZSortDirection.desc);

void main() {
  test('la PREMIÈRE requête porte le tri déclaré', () async {
    final repo = _RecordingRepo();
    final ctrl = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      initialSorts: const <ZSort>[_byName],
    );
    await pumpEventQueue();

    expect(repo.requests, isNotEmpty);
    expect(
      repo.requests.first.sorts,
      <ZSort>[_byName],
      reason: 'la toute première lecture de la source doit déjà être triée',
    );
    expect(
      repo.requests.length,
      1,
      reason: 'naître trié ne coûte pas une seconde requête',
    );
    ctrl.dispose();
  });

  test('un tri demandé plus tard REMPLACE le tri de naissance', () async {
    final repo = _RecordingRepo();
    final ctrl = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      initialSorts: const <ZSort>[_byName],
    );
    await pumpEventQueue();

    ctrl.setSort(const <ZSort>[_byNameDesc]);
    await pumpEventQueue();

    expect(repo.requests.last.sorts, <ZSort>[_byNameDesc]);
    ctrl.dispose();
  });

  test('le socle de filtres reste ANDé en tête d\'une requête triée', () async {
    final repo = _RecordingRepo();
    final ctrl = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      baseFilters: const <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
      initialSorts: const <ZSort>[_byName],
    );
    await pumpEventQueue();

    expect(repo.requests.first.sorts, <ZSort>[_byName]);
    expect(
      repo.requests.first.filters,
      <ZFilter>[const ZFilter('archive', ZFilterOp.eq, false)],
    );
    ctrl.dispose();
  });

  test('CONTRE-TÉMOIN — sans déclaration, la requête est celle d\'avant',
      () async {
    final repo = _RecordingRepo();
    final ctrl = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
    );
    await pumpEventQueue();

    expect(repo.requests.first, const ZDataRequest());
    ctrl.dispose();
  });
}
