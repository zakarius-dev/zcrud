// AC2/AC9 (E4-4, AD-16/AD-13) : actions de ligne FILTRÉES par `ZAcl`.
//
// Layout `builder` (SM-5 : rendu sélection/actions DANS le cœur, aucun import
// `zcrud_list`/Syncfusion). Fake `ZAcl` refusant `delete` → action `delete`
// masquée (mode hide) puis grisée (mode disable) ; `ZAllowAllAcl` → toutes
// présentes ; action custom (sans permission) toujours présente ; a11y Semantics.
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

/// Refuse les actions de [denied] ; autorise le reste.
class _DenyAcl implements ZAcl {
  const _DenyAcl(this.denied);
  final Set<ZCrudAction> denied;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !denied.contains(action);
}

class _NoopRepo implements ZRepository<_FakeEntity> {
  @override
  Future<ZResult<Unit>> softDelete(String id) async =>
      Right<ZFailure, Unit>(unit);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

const _entities = <_FakeEntity>[
  _FakeEntity('1', 'Alice'),
  _FakeEntity('2', 'Bob'),
];
const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];
final _rows = <ZListRow>[
  for (final e in _entities) ZListRow(id: e.id!, cells: {'name': e.name}),
];

_FakeEntity? _entityFor(ZListRow row) {
  for (final e in _entities) {
    if (e.id == row.id) return e;
  }
  return null;
}

Widget _harness({
  required ZAcl acl,
  required List<ZRowAction<_FakeEntity>> actions,
  ZActionAclMode mode = ZActionAclMode.hide,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        acl: acl,
        child: DynamicList<_FakeEntity>.rows(
          _fields,
          _rows,
          layout: ZListBuilderLayout(
            itemBuilder: (context, row, columns) =>
                Text('cell-${row.cells['name']}'),
          ),
          rowActions: actions,
          entityFor: _entityFor,
          actionAclMode: mode,
        ),
      ),
    ),
  );
}

void main() {
  final repo = _NoopRepo();
  List<ZRowAction<_FakeEntity>> actions() => <ZRowAction<_FakeEntity>>[
        ZRowAction<_FakeEntity>.edit(onInvoke: (_, __) {}),
        ZRowAction<_FakeEntity>.softDelete(repo),
        // Action custom SANS permission requise → jamais filtrée.
        ZRowAction<_FakeEntity>(
          id: 'archive',
          labelKey: 'archiveX',
          onInvoke: (_, __) {},
        ),
      ];

  testWidgets('ZAllowAllAcl → toutes les actions présentes (edit/delete/custom)',
      (tester) async {
    await tester.pumpWidget(
      _harness(acl: const ZAllowAllAcl(), actions: actions()),
    );
    expect(find.text('Edit'), findsNWidgets(2));
    expect(find.text('Delete'), findsNWidgets(2));
    expect(find.text('archiveX'), findsNWidgets(2));
  });

  testWidgets('deny delete (mode hide) → action delete MASQUÉE, autres présentes',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        acl: const _DenyAcl({ZCrudAction.delete}),
        actions: actions(),
      ),
    );
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Edit'), findsNWidgets(2));
    expect(find.text('archiveX'), findsNWidgets(2)); // custom toujours là
  });

  testWidgets('deny delete (mode disable) → delete PRÉSENTE mais grisée',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        acl: const _DenyAcl({ZCrudAction.delete}),
        actions: actions(),
        mode: ZActionAclMode.disable,
      ),
    );
    expect(find.text('Delete'), findsNWidgets(2));
    final deleteButtons =
        tester.widgetList<TextButton>(find.widgetWithText(TextButton, 'Delete'));
    expect(deleteButtons.every((b) => b.onPressed == null), isTrue,
        reason: 'delete refusée doit être non cliquable (enabled=false)');
    // edit reste cliquable.
    final editButtons =
        tester.widgetList<TextButton>(find.widgetWithText(TextButton, 'Edit'));
    expect(editButtons.every((b) => b.onPressed != null), isTrue);
  });

  testWidgets('AC9 : boutons d\'action exposent un Semantics(button, label)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(acl: const ZAllowAllAcl(), actions: actions()),
    );
    expect(find.bySemanticsLabel('Edit'), findsWidgets);
    expect(find.bySemanticsLabel('Delete'), findsWidgets);
    handle.dispose();
  });

  // LOW-2 (code-review E4-4) : une ligne sans entité (entityFor→null) voit ses
  // actions OMISES (impossible de lier onInvoke/ACL row-level), SANS crash.
  testWidgets('LOW-2 : entityFor→null → actions OMISES pour la ligne, pas de '
      'crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            acl: const ZAllowAllAcl(),
            child: DynamicList<_FakeEntity>.rows(
              _fields,
              _rows,
              layout: ZListBuilderLayout(
                itemBuilder: (context, row, columns) =>
                    Text('cell-${row.cells['name']}'),
              ),
              rowActions: actions(),
              // Aucune entité résolue pour AUCUNE ligne.
              entityFor: (_) => null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pas d'exception, la liste reste rendue…
    expect(tester.takeException(), isNull);
    expect(find.text('cell-Alice'), findsOneWidget);
    expect(find.text('cell-Bob'), findsOneWidget);
    // …mais AUCUNE action (edit/delete/custom) n'est rendue.
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('archiveX'), findsNothing);
  });
}
