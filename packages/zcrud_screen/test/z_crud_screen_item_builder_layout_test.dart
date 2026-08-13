// La tuile déclarée par l'application (`ZCrudScreen.itemBuilder`, qui reçoit
// l'entité) descend DANS le layout choisi par l'application — grille de cartes
// métier comprise. Avant, `itemBuilder` n'était consulté que sur la voie de
// repli : dès qu'un `layout` était fourni, il était ignoré et l'application
// devait reconstruire elle-même l'index `ligne → entité`.
//
// Gardes :
// 1. `ZListGridLayout` nue + `itemBuilder` ⇒ la carte reçoit l'ENTITÉ ;
// 2. `ZListBuilderLayout` nue + `itemBuilder` ⇒ même chose ;
// 3. contre-témoin : sans `itemBuilder`, la tuile générique du paquet est
//    rendue à l'identique ;
// 4. précédence : un layout portant sa propre tuile de ligne la garde.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
      'garde 1 — grille de cartes : itemBuilder reçoit l\'entité (qty n\'est '
      'lisible que sur l\'objet)', (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha', qty: 3),
      Item(id: 'i2', name: 'Beta', qty: 7),
    ]);
    final received = <Item>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        layout: const ZListGridLayout(mainAxisExtent: 120),
        itemBuilder: (context, item, columns) {
          received.add(item);
          return Text('carte-${item.name}-${item.qty}');
        },
      ),
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(received.map((e) => e.id), containsAll(<String>['i1', 'i2']));
    expect(find.text('carte-Alpha-3'), findsOneWidget);
    expect(find.text('carte-Beta-7'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('garde 2 — liste verticale déclarée : itemBuilder reçoit '
      'l\'entité', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        layout: const ZListBuilderLayout(),
        itemBuilder: (context, item, columns) => Text('ligne-${item.name}'),
      ),
    );
    expect(find.text('ligne-Alpha'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde 3 — contre-témoin : sans itemBuilder, la tuile générique du '
      'paquet est rendue à l\'identique', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    // Tuile générique : `ListTile` keyée par l'identité de ligne, titre = 1re
    // colonne dérivée.
    expect(find.byKey(const ValueKey<String>('zCrudTile_i1')), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Alpha'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde 4 — précédence : un layout portant sa propre tuile de ligne la '
      'garde', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        layout: ZListGridLayout(
          mainAxisExtent: 120,
          itemBuilder: (context, row, columns) =>
              Text('brut-${row.cells['name']}'),
        ),
        itemBuilder: (context, item, columns) => Text('carte-${item.name}'),
      ),
    );
    expect(find.text('brut-Alpha'), findsOneWidget);
    expect(find.text('carte-Alpha'), findsNothing);
    repo.dispose();
  });
}
