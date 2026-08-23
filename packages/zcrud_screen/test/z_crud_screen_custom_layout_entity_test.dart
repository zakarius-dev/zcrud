// Le résolveur `ligne → entité` que l'écran tient en privé (`_entities`)
// atteint TOUS les layouts déclarés par l'application : les layouts à tuiles
// (`ZListGridLayout`, `ZListBuilderLayout`, cf.
// `z_crud_screen_item_builder_layout_test.dart`) ET la vue personnalisée
// (`ZListCustomLayout.forEntity`), qui reçoit le résolveur lui-même. Une
// application n'a plus aucune raison de reconstruire cet index ni d'en
// recopier la convention de clé.
//
// Gardes :
// 1. vue personnalisée typée : le résolveur rend l'ENTITÉ de l'écran (qty
//    n'est lisible que sur l'objet) ;
// 2. entité ÉPHÉMÈRE (créée en mémoire, `id == null`) : résolue elle aussi —
//    la clé suit `ZListRow.keyOf`, jamais une formule recopiée par l'hôte ;
// 3. étalon hôte passif : sans `layout` ni `itemBuilder`, la liste rendue est
//    une `ZListBuilderLayout` dont la tuile appartient à l'écran (aucune tuile
//    d'entité injectée), `ListTile` keyée, hauteur ≥ 48 dp, annoncée aux
//    lecteurs d'écran ;
// 4. `ZListDataGridLayout` + `itemBuilder` : la grille de données n'a pas de
//    tuile — le layout reste celui déclaré, le renderer est appelé, aucune
//    exception, et le builder n'est pas invoqué (comportement fixé, documenté
//    sur `ZCrudScreen.layout`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

class _CapturingRenderer extends ZListRenderer {
  final List<ZListRenderRequest> captured = <ZListRenderRequest>[];

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    captured.add(request);
    return Text('grille:${request.rows.length}');
  }
}

void main() {
  testWidgets(
      'garde 1 — vue personnalisée typée : le résolveur rend l\'entité de '
      'l\'écran', (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha', qty: 3),
      Item(id: 'i2', name: 'Beta', qty: 7),
    ]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        layout: ZListCustomLayout.forEntity<Item>(
          (context, request, entityFor) => Column(
            children: <Widget>[
              for (final row in request.rows)
                Text(
                  'vue-${entityFor(row)?.name ?? '?'}-'
                  '${entityFor(row)?.qty ?? '?'}',
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('vue-Alpha-3'), findsOneWidget);
    expect(find.text('vue-Beta-7'), findsOneWidget);
    expect(find.textContaining('?'), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde 2 — entité éphémère (id null) : résolue par la clé publique '
      'ZListRow.keyOf, sans formule recopiée', (tester) async {
    const draft = Item(name: 'Brouillon', qty: 9);
    expect(draft.id, isNull);
    final seenKeys = <String>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: const ZCrudSource<Item>.items(<Item>[draft]),
        registry: buildItemRegistry(),
        layout: ZListCustomLayout.forEntity<Item>(
          (context, request, entityFor) => Column(
            children: <Widget>[
              for (final row in request.rows)
                Builder(builder: (context) {
                  seenKeys.add(row.id);
                  final item = entityFor(row);
                  return Text('vue-${item?.name ?? '?'}-${item?.qty ?? '?'}');
                }),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('vue-Brouillon-9'), findsOneWidget);
    expect(seenKeys, <String>[ZListRow.keyOf(draft)]);
    expect(ZListRow.isEphemeralKey(seenKeys.single), isTrue);
  });

  testWidgets(
      'garde 3 — étalon hôte passif : sans layout ni itemBuilder, liste '
      'verticale à tuile de l\'écran, ListTile keyée ≥ 48 dp, annoncée',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    final list = tester.widget<DynamicList<Item>>(
      find.byType(DynamicList<Item>),
    );
    final layout = list.layout;
    expect(layout, isA<ZListBuilderLayout>());
    layout as ZListBuilderLayout;
    expect(layout.itemBuilder, isNotNull);
    expect(layout.entityBuilder, isNull);
    // L'entité de la ligne est résolue par l'écran lui-même.
    expect(list.entityFor, isNotNull);
    expect(
      list.entityFor!(const ZListRow(id: 'i1', cells: <String, Object?>{})),
      isA<Item>().having((i) => i.name, 'name', 'Alpha'),
    );
    final tile = find.byKey(const ValueKey<String>('zCrudTile_i1'));
    expect(tile, findsOneWidget);
    expect(tester.widget(tile), isA<ListTile>());
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(tile).label, contains('Alpha'));
    handle.dispose();
    repo.dispose();
  });

  testWidgets(
      'garde 4 — grille de données + itemBuilder : layout conservé, renderer '
      'appelé, aucune exception, builder non invoqué', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final renderer = _CapturingRenderer();
    var builderCalls = 0;
    await pumpScreen(
      tester,
      ZcrudScope(
        acl: const ZAllowAllAcl(),
        listRenderer: renderer,
        child: ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          layout: const ZListDataGridLayout(),
          itemBuilder: (context, item, columns) {
            builderCalls++;
            return Text('carte-${item.name}');
          },
        ),
      ),
      acl: null,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('grille:1'), findsOneWidget);
    expect(renderer.captured, isNotEmpty);
    expect(builderCalls, 0);
    expect(
      tester.widget<DynamicList<Item>>(find.byType(DynamicList<Item>)).layout,
      isA<ZListDataGridLayout>(),
    );
    repo.dispose();
  });
}
