// Garde des CAS EXPRIMABLES PAR DÉCLARATION (point 2 du CR) : `canCreate:
// false`, `trash: ZTrashMode.none`, `readOnly: true`, ACL refusante, source
// `.items` sans callbacks (lecture seule EFFECTIVE) — chacun se déclare, ne se
// contourne jamais.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets('canCreate: false masque le bouton « + » malgré une ACL permissive',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        canCreate: false,
      ),
    );
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    // Le reste de l'écran vit toujours (liste + édition).
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'trash: ZTrashMode.none — aucune bascule corbeille, aucune action '
      'soft-delete, malgré une source qui la supporte', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        trash: ZTrashMode.none,
      ),
    );
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'readOnly: true — consultation pure (ni « + », ni édition, ni corbeille)',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        readOnly: true,
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'ACL refusante : create refusé ⇒ « + » absent ; delete+restore refusés '
      '⇒ ni action corbeille ni bascule (mode hide)', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        acl: const DenyAcl(<ZCrudAction>{
          ZCrudAction.create,
          ZCrudAction.delete,
          ZCrudAction.restore,
        }),
      ),
    );
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // update reste autorisé : l'édition demeure.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'source .items SANS callbacks = lecture seule EFFECTIVE (aucun « + », '
      'aucune action de ligne) — le journal immuable se DÉCLARE', (tester) async {
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Journal',
        source: const ZCrudSource<Item>.items(<Item>[
          Item(id: 'i1', name: 'Alpha'),
          Item(id: 'i2', name: 'Beta'),
        ]),
        registry: buildItemRegistry(),
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
  });

  testWidgets(
      'source .items AVEC callbacks : onSave alimente la création, la '
      'corbeille callback partitionne par isDeleted', (tester) async {
    final items = <Item>[
      const Item(id: 'i1', name: 'Alpha'),
      const Item(id: 'i2', name: 'Beta'),
    ];
    final deletedIds = <String>{};
    final savedNames = <String>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.items(
          items,
          onSave: (item) async => savedNames.add(item.name),
          onSoftDelete: (item) => deletedIds.add(item.id!),
          onRestore: (item) => deletedIds.remove(item.id!),
          isDeleted: (item) => deletedIds.contains(item.id),
        ),
        registry: buildItemRegistry(),
      ),
    );
    // Création via onSave (aucun repository).
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();
    final nameField = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField.first, 'Gamma');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();
    expect(savedNames, <String>['Gamma']);

    // Soft-delete callback : Alpha quitte les vivants…
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(deletedIds, <String>{'i1'});
    expect(find.text('Alpha'), findsNothing);
    // …et se retrouve dans la corbeille (partition isDeleted), restaurable.
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.restore_from_trash).first);
    await tester.pumpAndSettle();
    expect(deletedIds, isEmpty);
    expect(find.text('Alpha'), findsNothing); // corbeille redevenue vide
  });
}
