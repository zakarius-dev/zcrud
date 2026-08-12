// CR-LIST (grille neutre) : layout `ZListGridLayout` — grille de cartes
// RESPONSIVE rendue `GridView.builder` DANS le cœur (virtualisée, sans
// Syncfusion, sans renderer, directionnelle RTL).
//
// Gardes :
// 1. N items rendus via itemBuilder (GridView.builder, clé `zListGrid`) ;
// 2. virtualisation : un item hors viewport n'est PAS construit ;
// 3. responsivité : largeur 700 → 2 colonnes ; largeur 300 → 1 colonne
//    (`maxCrossAxisExtent` = 350) ;
// 4. directionnalité : en RTL la première tuile est ANCRÉE côté droit
//    (miroir du LTR) — aucune direction absolue ;
// 5. interaction : actions de ligne résolues rendues au pied de tuile,
//    filtrées par l'ACL (mêmes briques que la vue `builder`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _FakeEntity extends ZEntity {
  const _FakeEntity(this._id);
  final String _id;
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

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

List<ZListRow> _rows(int count) => [
      for (var i = 0; i < count; i++)
        ZListRow(id: '$i', cells: {'name': 'item$i'}),
    ];

ZListGridLayout _grid({double? mainAxisExtent = 100}) => ZListGridLayout(
      maxCrossAxisExtent: 350,
      mainAxisExtent: mainAxisExtent,
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      itemBuilder: (context, row, columns) =>
          Text('card-${row.cells['name']}'),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget list, {
  double width = 700,
  TextDirection direction = TextDirection.ltr,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: width, height: 600, child: list),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rend les items via GridView.builder (sans renderer) (garde 1)',
      (tester) async {
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(4), layout: _grid()),
    );
    expect(find.byKey(const ValueKey('zListGrid')), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.text('card-item$i'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('virtualisée : un item hors viewport n\'est PAS construit '
      '(garde 2)', (tester) async {
    // 2 colonnes × tuiles de 100 dp dans 600 dp de haut → ~12-14 tuiles
    // construites ; la 60ᵉ est très loin sous la ligne de flottaison.
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(60), layout: _grid()),
    );
    expect(find.text('card-item0'), findsOneWidget);
    expect(find.text('card-item59'), findsNothing);
  });

  testWidgets('responsive : 700 dp → 2 colonnes ; 300 dp → 1 colonne '
      '(garde 3)', (tester) async {
    // Largeur 700, maxCrossAxisExtent 350 → 2 colonnes : les tuiles 0 et 1
    // partagent la même ligne (même dy, dx distincts).
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(4), layout: _grid()),
    );
    final wide0 = tester.getTopLeft(find.text('card-item0'));
    final wide1 = tester.getTopLeft(find.text('card-item1'));
    expect(wide0.dy, wide1.dy);
    expect(wide0.dx, isNot(wide1.dx));

    // Largeur 300 → 1 colonne : la tuile 1 passe SOUS la tuile 0.
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(4), layout: _grid()),
      width: 300,
    );
    final narrow0 = tester.getTopLeft(find.text('card-item0'));
    final narrow1 = tester.getTopLeft(find.text('card-item1'));
    expect(narrow1.dy, greaterThan(narrow0.dy));
    expect(narrow1.dx, narrow0.dx);
  });

  testWidgets('RTL : la première tuile est ancrée côté DROIT (miroir du LTR) '
      '(garde 4)', (tester) async {
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(4), layout: _grid()),
    );
    final ltr0 = tester.getTopLeft(find.text('card-item0'));
    final ltr1 = tester.getTopLeft(find.text('card-item1'));

    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(4), layout: _grid()),
      direction: TextDirection.rtl,
    );
    final rtl0 = tester.getTopLeft(find.text('card-item0'));
    final rtl1 = tester.getTopLeft(find.text('card-item1'));
    // En LTR la tuile 0 est à gauche de la tuile 1 ; en RTL c'est l'inverse.
    expect(ltr0.dx, lessThan(ltr1.dx));
    expect(rtl0.dx, greaterThan(rtl1.dx));
  });

  testWidgets('interaction : actions rendues au pied de tuile, filtrées ACL '
      '(garde 5)', (tester) async {
    final deleted = <String?>[];
    Widget harness(ZAcl acl) => ZcrudScope(
          acl: acl,
          child: DynamicList<_FakeEntity>.rows(
            _fields,
            _rows(2),
            layout: _grid(mainAxisExtent: 180),
            rowActions: [
              ZRowAction<_FakeEntity>.softDeleteWith(
                (context, entity) => deleted.add(entity.id),
              ),
            ],
            entityFor: (row) => _FakeEntity(row.id),
          ),
        );

    await _pump(tester, harness(const ZAllowAllAcl()));
    expect(find.text('Delete'), findsNWidgets(2));
    await tester.tap(find.text('Delete').first);
    await tester.pump();
    expect(deleted, ['0']);

    // ACL refusant delete → aucune action rendue dans la grille.
    await _pump(tester, harness(const _DenyAcl({ZCrudAction.delete})));
    expect(find.text('Delete'), findsNothing);
  });
}
