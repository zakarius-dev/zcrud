// CR-LIST (corbeille sans repository) : fabriques à callback
// `ZRowAction.softDeleteWith` / `restoreWith` — la corbeille reste disponible
// quand la liste est encore alimentée par les flux de l'app hôte (aucun
// `ZRepository`), et l'ACL reste appliquée EXACTEMENT comme pour les fabriques
// à repository.
//
// Gardes :
// 1. le handler fourni est invoqué avec le contexte + l'entité de la ligne ;
// 2. permissions/style identiques aux fabriques nominales (`delete` destructif,
//    `restore`) ;
// 3. via `DynamicList` + `ZAcl` refusant `delete`/`restore` : les actions à
//    callback sont FILTRÉES (masquées) — l'absence de repository n'ouvre aucune
//    porte dérobée dans la corbeille ;
// 4. entité éphémère (`id == null`) : TRANSMISE au handler (contrat documenté,
//    différent de la fabrique à repository qui l'ignore).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _FakeEntity extends ZEntity {
  const _FakeEntity(this._id, this.name);
  final String? _id;
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
        ),
      ),
    ),
  );
}

void main() {
  test('softDeleteWith : permission delete + destructif ; restoreWith : restore',
      () {
    final del = ZRowAction<_FakeEntity>.softDeleteWith((_, _) {});
    expect(del.id, 'delete');
    expect(del.labelKey, 'delete');
    expect(del.requiredPermission, ZCrudAction.delete);
    expect(del.destructive, isTrue);

    final res = ZRowAction<_FakeEntity>.restoreWith((_, _) {});
    expect(res.id, 'restore');
    expect(res.labelKey, 'restore');
    expect(res.requiredPermission, ZCrudAction.restore);
    expect(res.destructive, isFalse);
  });

  testWidgets('softDeleteWith invoque le handler avec l\'entité de la ligne',
      (tester) async {
    final deleted = <_FakeEntity>[];
    await tester.pumpWidget(
      _harness(
        acl: const ZAllowAllAcl(),
        actions: [
          ZRowAction<_FakeEntity>.softDeleteWith(
            (context, entity) => deleted.add(entity),
          ),
        ],
      ),
    );
    // Une action par ligne, aucune invocation avant le tap.
    expect(find.text('Delete'), findsNWidgets(2));
    expect(deleted, isEmpty);

    await tester.tap(find.text('Delete').first);
    await tester.pump();
    expect(deleted.map((e) => e.id), ['1']);
  });

  testWidgets('restoreWith invoque le handler avec l\'entité de la ligne',
      (tester) async {
    final restored = <_FakeEntity>[];
    await tester.pumpWidget(
      _harness(
        acl: const ZAllowAllAcl(),
        actions: [
          ZRowAction<_FakeEntity>.restoreWith(
            (context, entity) => restored.add(entity),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Restore').last);
    await tester.pump();
    expect(restored.map((e) => e.id), ['2']);
  });

  testWidgets(
      'ACL refusant delete/restore → actions à callback MASQUÉES, handler '
      'jamais invoqué (aucune porte dérobée sans repository)', (tester) async {
    var invoked = 0;
    await tester.pumpWidget(
      _harness(
        acl: const _DenyAcl({ZCrudAction.delete, ZCrudAction.restore}),
        actions: [
          ZRowAction<_FakeEntity>.softDeleteWith((_, _) => invoked++),
          ZRowAction<_FakeEntity>.restoreWith((_, _) => invoked++),
        ],
      ),
    );
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Restore'), findsNothing);
    expect(invoked, 0);
  });

  testWidgets('entité éphémère (id == null) : TRANSMISE au handler',
      (tester) async {
    const ephemeral = _FakeEntity(null, 'Brouillon');
    final rows = [ZListRow(id: ZListRow.ephemeralKey(0), cells: const {})];
    final received = <_FakeEntity>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicList<_FakeEntity>.rows(
            _fields,
            rows,
            layout: ZListBuilderLayout(
              itemBuilder: (context, row, columns) => const Text('draft'),
            ),
            rowActions: [
              ZRowAction<_FakeEntity>.softDeleteWith(
                (context, entity) => received.add(entity),
              ),
            ],
            entityFor: (_) => ephemeral,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pump();
    // Contrairement à softDelete(repository), l'éphémère atteint le handler :
    // l'app, propriétaire du chemin de données, décide.
    expect(received, hasLength(1));
    expect(received.single.id, isNull);
  });
}
