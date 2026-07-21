// AC1/AC3/AC7/AC8 (E4-5, AD-8/AD-16/AD-2/AD-13/SM-5) : `ZSubListScreen<T>` —
// sous-liste d'entités RELIÉES filtrée par la relation neutre `ZFilter(parentField,
// eq, parentId)` PERSISTANTE (jamais fuitée vers un autre parent, même après une
// recherche/un filtre utilisateur) ; mini-CRUD réutilisant E4-3/E4-4 (recherche
// sans accents, actions `ZAcl`, corbeille soft-delete/restore, sélection) ;
// sémantique de sélection tranchée (persistance intra-relation, reset sur
// changement de parent). Layout `builder` (SM-5 : AUCUN `zcrud_list`/Syncfusion).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'parentId', type: EditionFieldType.text),
];

class _Child implements ZEntity {
  const _Child(this._id, this.parentId, this.name);
  final String _id;
  final String parentId;
  final String name;
  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

ZListRow _toRow(_Child c) => ZListRow(
      id: c.id!,
      cells: <String, Object?>{'name': c.name, 'parentId': c.parentId},
    );

/// Fake `ZRepository` NEUTRE : applique les filtres/recherche du `ZDataRequest`
/// via `zApplyListRequest`, exclut les soft-deleted, et émet sur `watchAll` à
/// chaque mutation (pilote `watchMutations`).
class _FakeChildRepo implements ZRepository<_Child> {
  _FakeChildRepo(this._data);

  final List<_Child> _data;
  final Set<String> _deleted = <String>{};
  final StreamController<List<_Child>> _changes =
      StreamController<List<_Child>>.broadcast();

  List<_Child> get _live =>
      <_Child>[for (final c in _data) if (!_deleted.contains(c.id)) c];

  @override
  Future<ZResult<List<_Child>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    final rows = <ZListRow>[for (final c in _live) _toRow(c)];
    final page = zApplyListRequest(rows, req, schema: _schema);
    final byId = <String, _Child>{for (final c in _live) c.id!: c};
    return Right(<_Child>[for (final r in page.rows) byId[r.id]!]);
  }

  @override
  Stream<List<_Child>> watchAll() => _changes.stream;
  @override
  Stream<List<_Child>> watch(ZDataRequest request) => _changes.stream;
  @override
  Future<ZResult<_Child>> getById(String id) async {
    for (final c in _live) {
      if (c.id == id) return Right(c);
    }
    return Left(ZNotFoundFailure('n/a', id: id));
  }

  @override
  Future<ZResult<_Child>> save(_Child item, {String? collectionId}) async =>
      Right(item);
  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    _deleted.add(id);
    _changes.add(_live);
    return const Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    _deleted.remove(id);
    _changes.add(_live);
    return const Right(unit);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_live.length);
  @override
  void dispose() => _changes.close();
}

/// Refuse les actions de [denied] ; autorise le reste.
class _DenyAcl implements ZAcl {
  const _DenyAcl(this.denied);
  final Set<ZCrudAction> denied;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !denied.contains(action);
}

final _all = <_Child>[
  const _Child('c1', 'p1', 'Apple'),
  const _Child('c2', 'p1', 'Banana'),
  const _Child('c3', 'p2', 'Cherry'),
  const _Child('c4', 'p2', 'Date'),
];

_Child? _entityFor(List<_Child> live, ZListRow row) {
  for (final c in live) {
    if (c.id == row.id) return c;
  }
  return null;
}

ZListBuilderLayout _builderLayout() => ZListBuilderLayout(
      itemBuilder: (context, row, columns) =>
          Text('child-${row.cells['name']}'),
    );

Widget _host({
  required _FakeChildRepo repo,
  required Object parentId,
  ZAcl acl = const ZAllowAllAcl(),
  List<ZRowAction<_Child>>? rowActions,
  ZListSelectionController? selection,
  bool showSearch = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        acl: acl,
        child: ZSubListScreen<_Child>(
          repository: repo,
          parentField: 'parentId',
          parentId: parentId,
          toRow: _toRow,
          schema: _schema,
          layout: _builderLayout(),
          rowActions: rowActions,
          entityFor: (row) => _entityFor(repo._live, row),
          selection: selection,
          showSearch: showSearch,
          watchMutations: true,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('AC1 — affiche SEULEMENT les enfants du parent p1 (relation neutre)',
      (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    await tester.pumpWidget(_host(repo: repo, parentId: 'p1'));
    await tester.pumpAndSettle();

    expect(find.text('child-Apple'), findsOneWidget); // p1
    expect(find.text('child-Banana'), findsOneWidget); // p1
    expect(find.text('child-Cherry'), findsNothing); // p2 (exclu)
    expect(find.text('child-Date'), findsNothing); // p2 (exclu)
    repo.dispose();
  });

  testWidgets('AC3a/AC7 — recherche masque les non-correspondants SANS fuiter p2',
      (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    await tester
        .pumpWidget(_host(repo: repo, parentId: 'p1', showSearch: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('zSubListSearch')), 'App');
    await tester.pumpAndSettle();

    expect(find.text('child-Apple'), findsOneWidget); // matche
    expect(find.text('child-Banana'), findsNothing); // masqué par la recherche
    expect(find.text('child-Cherry'), findsNothing); // p2 : jamais visible
    repo.dispose();
  });

  testWidgets('AC3b — ACL refusant delete masque l\'action delete', (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    final deleteAction = ZRowAction<_Child>.softDelete(repo, icon: Icons.delete);
    await tester.pumpWidget(_host(
      repo: repo,
      parentId: 'p1',
      acl: const _DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      rowActions: <ZRowAction<_Child>>[deleteAction],
    ));
    await tester.pumpAndSettle();

    // Action delete filtrée (mode hide) → aucun bouton delete rendu.
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.text('child-Apple'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('AC3c — softDelete exclut de la vue parent-filtrée, restore réinclut',
      (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    final deleteAction = ZRowAction<_Child>.softDelete(repo, icon: Icons.delete);
    await tester.pumpWidget(_host(
      repo: repo,
      parentId: 'p1',
      rowActions: <ZRowAction<_Child>>[deleteAction],
    ));
    await tester.pumpAndSettle();
    expect(find.text('child-Apple'), findsOneWidget);

    // Supprime c1 (Apple) : premier bouton delete.
    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();
    expect(find.text('child-Apple'), findsNothing); // exclu (soft-delete)
    expect(find.text('child-Banana'), findsOneWidget); // relation intacte

    // Restore c1 : re-inclus (via watchMutations → refresh).
    await repo.restore('c1');
    await tester.pumpAndSettle();
    expect(find.text('child-Apple'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('AC3d — sélection de 2 enfants stable au rebuild', (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    final selection = ZListSelectionController();
    await tester.pumpWidget(_host(
      repo: repo,
      parentId: 'p1',
      selection: selection,
    ));
    await tester.pumpAndSettle();

    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(2)); // 2 enfants de p1
    await tester.tap(boxes.at(0));
    await tester.tap(boxes.at(1));
    await tester.pumpAndSettle();
    expect(selection.selectedIds.value, <String>{'c1', 'c2'});

    // Rebuild (pump) : la sélection (état hors renderer) survit.
    await tester.pump();
    expect(selection.selectedIds.value, <String>{'c1', 'c2'});
    selection.dispose();
    repo.dispose();
  });

  testWidgets('AC8a — même relation : la sélection persiste au filtre/défiltre',
      (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    final selection = ZListSelectionController();
    await tester.pumpWidget(_host(
      repo: repo,
      parentId: 'p1',
      selection: selection,
      showSearch: true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // c1
    await tester.pumpAndSettle();
    expect(selection.selectedIds.value, <String>{'c1'});

    // Filtre masquant c1 : la sélection persiste par `id` (cohérent E4-4).
    await tester.enterText(
        find.byKey(const ValueKey('zSubListSearch')), 'Banana');
    await tester.pumpAndSettle();
    expect(find.text('child-Apple'), findsNothing);
    expect(selection.selectedIds.value, <String>{'c1'});

    // Défiltre : c1 réapparaît toujours sélectionné.
    await tester.enterText(find.byKey(const ValueKey('zSubListSearch')), '');
    await tester.pumpAndSettle();
    expect(find.text('child-Apple'), findsOneWidget);
    expect(selection.selectedIds.value, <String>{'c1'});
    selection.dispose();
    repo.dispose();
  });

  testWidgets('AC8b — changement de parentId VIDE la sélection (collection diff.)',
      (tester) async {
    final repo = _FakeChildRepo(List<_Child>.of(_all));
    final selection = ZListSelectionController();
    var parentId = 'p1';
    late StateSetter setOuter;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return ZSubListScreen<_Child>(
                  repository: repo,
                  parentField: 'parentId',
                  parentId: parentId,
                  toRow: _toRow,
                  schema: _schema,
                  layout: _builderLayout(),
                  selection: selection,
                  entityFor: (row) => _entityFor(repo._live, row),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // sélectionne c1 (p1)
    await tester.pumpAndSettle();
    expect(selection.selectedIds.value, <String>{'c1'});

    // Change le parent → didUpdateWidget vide la sélection + recrée le contrôleur.
    setOuter(() => parentId = 'p2');
    await tester.pumpAndSettle();
    expect(selection.selectedIds.value, isEmpty);
    expect(find.text('child-Cherry'), findsOneWidget); // enfants de p2
    expect(find.text('child-Apple'), findsNothing);
    selection.dispose();
    repo.dispose();
  });
}
