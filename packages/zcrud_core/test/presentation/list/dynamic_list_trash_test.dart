// AC6/AC7/AC8 (E4-4, AD-9/AD-16/AD-11) : corbeille soft-delete / restore.
//
// Fake `ZRepository` avec store + Set `deleted` : softDelete exclut de getAll
// SANS suppression dure ; restore ré-inclut ; suppression EN LOT sur sélection ;
// `Left(ServerFailure)` → onFailure, 0 throw. Wiring via `DynamicList` (layout
// `builder`, SM-5) : tap sur l'action delete appelle le port.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _FakeEntity extends ZEntity {
  const _FakeEntity(this._id, this.name);
  final String _id;
  final String name;
  @override
  String? get id => _id;
}

/// Store fake : soft-delete = ajout au Set `deleted` (jamais retiré du store).
class _StoreRepo implements ZRepository<_FakeEntity> {
  _StoreRepo(this.store);
  final Map<String, _FakeEntity> store;
  final Set<String> deleted = <String>{};
  ZFailure? failWith;

  @override
  Future<ZResult<List<_FakeEntity>>> getAll({ZDataRequest? request}) async {
    return Right<ZFailure, List<_FakeEntity>>(<_FakeEntity>[
      for (final e in store.values)
        if (!deleted.contains(e.id)) e,
    ]);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    final failure = failWith;
    if (failure != null) return Left<ZFailure, Unit>(failure);
    deleted.add(id);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    deleted.remove(id);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<List<String>> _visibleIds(_StoreRepo repo) async {
  final result = await repo.getAll();
  return result.getOrElse(() => const <_FakeEntity>[]).map((e) => e.id!).toList();
}

void main() {
  const fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

  Map<String, _FakeEntity> newStore() => <String, _FakeEntity>{
        'a': const _FakeEntity('a', 'Alice'),
        'b': const _FakeEntity('b', 'Bob'),
        'c': const _FakeEntity('c', 'Chloé'),
      };

  test('AC6 : softDelete exclut de getAll SANS suppression dure', () async {
    final store = newStore();
    final repo = _StoreRepo(store);
    expect(await _visibleIds(repo), <String>['a', 'b', 'c']);

    await repo.softDelete('a');
    expect(await _visibleIds(repo), <String>['b', 'c']);
    // Pas de suppression physique : l'entité existe toujours dans le store.
    expect(store.containsKey('a'), isTrue);
  });

  test('AC7 : restore ré-inclut l\'item soft-deleted', () async {
    final repo = _StoreRepo(newStore());
    await repo.softDelete('a');
    expect(await _visibleIds(repo), <String>['b', 'c']);
    await repo.restore('a');
    expect(await _visibleIds(repo), <String>['a', 'b', 'c']);
  });

  test('AC6 : suppression EN LOT via softDeleteSelected (sélection)', () async {
    final repo = _StoreRepo(newStore());
    final selection = ZListSelectionController()
      ..selectAll(<String>['a', 'b']);
    await selection.softDeleteSelected(repo);
    expect(repo.deleted, <String>{'a', 'b'});
    expect(await _visibleIds(repo), <String>['c']);
    expect(selection.selectedIds.value, isEmpty);
    selection.dispose();
  });

  testWidgets('AC6 : tap sur l\'action delete appelle repo.softDelete + refresh',
      (tester) async {
    final store = newStore();
    final repo = _StoreRepo(store);
    final rows = <ZListRow>[
      for (final e in store.values) ZListRow(id: e.id!, cells: {'name': e.name}),
    ];
    var refreshed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicList<_FakeEntity>.rows(
            fields,
            rows,
            layout: ZListBuilderLayout(
              itemBuilder: (context, row, columns) =>
                  Text('cell-${row.cells['name']}'),
            ),
            entityFor: (row) => store[row.id],
            rowActions: <ZRowAction<_FakeEntity>>[
              ZRowAction<_FakeEntity>.softDelete(
                repo,
                onSuccess: () => refreshed++,
              ),
            ],
          ),
        ),
      ),
    );

    // Tap le bouton delete de la 1ʳᵉ ligne ('a').
    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pump();

    expect(repo.deleted.contains('a'), isTrue);
    expect(refreshed, 1);
    expect(await _visibleIds(repo), <String>['b', 'c']);
  });

  testWidgets('AC8 : Left(ServerFailure) sur softDelete → onFailure, 0 throw',
      (tester) async {
    final store = newStore();
    final repo = _StoreRepo(store)..failWith = const ServerFailure('nope');
    final rows = <ZListRow>[
      ZListRow(id: 'a', cells: {'name': 'Alice'}),
    ];
    ZFailure? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicList<_FakeEntity>.rows(
            fields,
            rows,
            layout: ZListBuilderLayout(
              itemBuilder: (context, row, columns) => Text('cell-${row.id}'),
            ),
            entityFor: (row) => store[row.id],
            rowActions: <ZRowAction<_FakeEntity>>[
              ZRowAction<_FakeEntity>.softDelete(
                repo,
                onFailure: (f) => captured = f,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pump();

    expect(captured, isA<ServerFailure>());
    expect(repo.deleted, isEmpty); // rien supprimé
    expect(tester.takeException(), isNull); // 0 throw
  });
}
