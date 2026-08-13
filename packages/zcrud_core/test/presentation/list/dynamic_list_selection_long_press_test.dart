// La sélection s'OUVRE à l'appui long (parité du motif tactile usuel).
//
// « Ouverte » n'est pas un état conservé à part : c'est « la sélection n'est pas
// vide ». Rien ne peut donc s'en désynchroniser — un vidage venu d'ailleurs
// (action de lot, bascule de vue) referme la sélection de lui-même.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

List<ZListRow> _rows(int n) => <ZListRow>[
      for (var i = 1; i <= n; i++)
        ZListRow(id: '$i', cells: {'name': 'Item $i'}),
    ];

Widget _app({
  required ZListSelectionController selection,
  required ZListSelectionActivation activation,
  ZListLayout? layout,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DynamicList.rows(
        _fields,
        _rows(3),
        selection: selection,
        selectionActivation: activation,
        layout: layout ??
            ZListBuilderLayout(
              itemBuilder: (context, row, columns) =>
                  Text('cell-${row.cells['name']}'),
            ),
      ),
    ),
  );
}

void main() {
  testWidgets('vue builder : aucune case tant que rien n\'est sélectionné, '
      'l\'appui long ouvre la sélection', (tester) async {
    final selection = ZListSelectionController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _app(
        selection: selection,
        activation: ZListSelectionActivation.longPress,
      ),
    );

    expect(
      find.byType(Checkbox),
      findsNothing,
      reason: 'sélection fermée : la ligne n\'est pas encombrée',
    );

    await tester.longPress(find.text('cell-Item 2'));
    await tester.pump();

    expect(selection.selectedIds.value, <String>{'2'});
    expect(
      find.byType(Checkbox),
      findsNWidgets(3),
      reason: 'sélection ouverte : chaque ligne porte sa case',
    );

    // Elle se referme d'elle-même quand la sélection se vide.
    selection.clearSelection();
    await tester.pump();
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('vue grille : même geste, même ouverture', (tester) async {
    final selection = ZListSelectionController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _app(
        selection: selection,
        activation: ZListSelectionActivation.longPress,
        layout: ZListGridLayout(
          itemBuilder: (context, row, columns) =>
              Text('cell-${row.cells['name']}'),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNothing);
    await tester.longPress(find.text('cell-Item 1'));
    await tester.pump();
    expect(selection.selectedIds.value, <String>{'1'});
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets('CONTRE-TÉMOIN — par défaut, cases d\'emblée et aucun geste posé',
      (tester) async {
    final selection = ZListSelectionController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _app(selection: selection, activation: ZListSelectionActivation.always),
    );

    expect(find.byType(Checkbox), findsNWidgets(3));
    await tester.longPress(find.text('cell-Item 2'));
    await tester.pump();
    expect(
      selection.selectedIds.value,
      isEmpty,
      reason: 'aucun appui long n\'est capté quand il n\'a pas été déclaré',
    );
  });
}
