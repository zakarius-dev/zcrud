// CR tabbed-list (recherche & état, 2026-08-12) : `ZListGridLayout.maxColumns`
// — plafond optionnel du nombre de colonnes de la grille responsive.
//
// Gardes :
// 1. plafonné : écran large (800 dp, extent 250 → 4 colonnes dérivées) avec
//    `maxColumns: 2` → EXACTEMENT 2 colonnes, et les tuiles S'ÉLARGISSENT
//    au-delà de `maxCrossAxisExtent` pour occuper la largeur (contrat dartdoc) ;
// 2. contre-témoin : SANS plafond, même largeur → le nombre de colonnes
//    responsive natif est INCHANGÉ (4 colonnes, tuiles ≤ extent) ;
// 3. `maxColumns` invalide (< 1) refusé par assert au constructeur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

List<ZListRow> _rows(int count) => [
      for (var i = 0; i < count; i++)
        ZListRow(id: '$i', cells: {'name': 'item$i'}),
    ];

ZListGridLayout _grid({int? maxColumns}) => ZListGridLayout(
      maxCrossAxisExtent: 250,
      mainAxisExtent: 100,
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      maxColumns: maxColumns,
      itemBuilder: (context, row, columns) =>
          Text('card-${row.cells['name']}'),
    );

Future<void> _pump(WidgetTester tester, Widget list) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 800, height: 600, child: list),
      ),
    ),
  );
}

Offset _tileTopLeft(WidgetTester tester, int i) =>
    tester.getTopLeft(find.byKey(ValueKey('zListGridTile_$i')));

void main() {
  testWidgets('maxColumns: 2 plafonne à 2 colonnes sur écran large ; les '
      'tuiles s\'élargissent au-delà de maxCrossAxisExtent (garde 1)',
      (tester) async {
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(5), layout: _grid(maxColumns: 2)),
    );

    // 2 colonnes : tuiles 0 et 1 sur la même ligne, la 2 passe DESSOUS.
    expect(_tileTopLeft(tester, 0).dy, _tileTopLeft(tester, 1).dy);
    expect(
      _tileTopLeft(tester, 2).dy,
      greaterThan(_tileTopLeft(tester, 0).dy),
      reason: 'la 3e tuile ouvre une nouvelle ligne : colonnes = plafond (2)',
    );

    // Les tuiles occupent la largeur : 800 / 2 = 400 dp > extent (250 dp).
    final tileWidth =
        tester.getSize(find.byKey(const ValueKey('zListGridTile_0'))).width;
    expect(tileWidth, 400.0,
        reason: 'plafonnée, la tuile s\'élargit au-delà de maxCrossAxisExtent');
  });

  testWidgets('contre-témoin : SANS maxColumns, le responsive natif est '
      'inchangé (4 colonnes à 800 dp / extent 250) (garde 2)', (tester) async {
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows(5), layout: _grid()),
    );

    // ceil(800 / 250) = 4 colonnes : tuiles 0..3 sur la même ligne, la 4
    // passe dessous — dérivation native, aucune influence du seam.
    final dy0 = _tileTopLeft(tester, 0).dy;
    for (var i = 1; i <= 3; i++) {
      expect(_tileTopLeft(tester, i).dy, dy0,
          reason: 'sans plafond, 4 colonnes dérivées de la largeur');
    }
    expect(_tileTopLeft(tester, 4).dy, greaterThan(dy0));

    // Tuile = 800 / 4 = 200 dp : jamais élargie au-delà de l'extent.
    final tileWidth =
        tester.getSize(find.byKey(const ValueKey('zListGridTile_0'))).width;
    expect(tileWidth, 200.0);
  });

  test('maxColumns < 1 refusé par assert (garde 3)', () {
    expect(
      () => ZListGridLayout(
        maxCrossAxisExtent: 250,
        maxColumns: 0,
        itemBuilder: (context, row, columns) => const SizedBox.shrink(),
      ),
      throwsAssertionError,
    );
  });
}
