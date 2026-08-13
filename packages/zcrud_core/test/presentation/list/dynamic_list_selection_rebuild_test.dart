// Coût d'un changement de sélection (AD-2).
//
// Cocher une case ne doit pas reconstruire les TUILES de la liste : la tuile
// d'une ligne ne dépend pas de l'ensemble sélectionné, seule sa case en dépend.
// Ces gardes comptent les constructions de tuile réellement provoquées par un
// `toggle`, sur les deux vues rendues DANS le cœur (`builder` et `grid`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

List<ZListRow> _rows(int n) => <ZListRow>[
      for (var i = 1; i <= n; i++)
        ZListRow(id: '$i', cells: {'name': 'Item $i'}),
    ];

void main() {
  testWidgets('vue builder : un toggle ne reconstruit AUCUNE tuile',
      (tester) async {
    final selection = ZListSelectionController();
    addTearDown(selection.dispose);
    var tileBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicList.rows(
            _fields,
            _rows(5),
            selection: selection,
            layout: ZListBuilderLayout(
              itemBuilder: (context, row, columns) {
                tileBuilds++;
                return Text('cell-${row.cells['name']}');
              },
            ),
          ),
        ),
      ),
    );
    final afterFirstRender = tileBuilds;
    expect(afterFirstRender, greaterThan(0));

    selection.toggle('1');
    await tester.pump();

    // La case de la ligne 1 a bien suivi…
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('zListRow_1')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    // … et aucune tuile n'a été reconstruite pour autant.
    expect(
      tileBuilds - afterFirstRender,
      0,
      reason: 'un toggle ne doit reconstruire que les cases, pas les tuiles',
    );
  });

  testWidgets('vue grille : un toggle ne reconstruit AUCUNE tuile',
      (tester) async {
    final selection = ZListSelectionController();
    addTearDown(selection.dispose);
    var tileBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicList.rows(
            _fields,
            _rows(5),
            selection: selection,
            layout: ZListGridLayout(
              itemBuilder: (context, row, columns) {
                tileBuilds++;
                return Text('cell-${row.cells['name']}');
              },
            ),
          ),
        ),
      ),
    );
    final afterFirstRender = tileBuilds;
    expect(afterFirstRender, greaterThan(0));

    selection.toggle('1');
    await tester.pump();

    expect(
      tileBuilds - afterFirstRender,
      0,
      reason: 'un toggle ne doit reconstruire que les cases, pas les tuiles',
    );
  });
}
