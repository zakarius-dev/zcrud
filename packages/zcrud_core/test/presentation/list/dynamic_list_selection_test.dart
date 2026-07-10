// AC4/AC9 (E4-4, AD-2/AD-13) : BUG DE SÉLECTION HISTORIQUE CORRIGÉ.
//
// L'état de sélection vit dans `ZListSelectionController` (keyé par `id` STABLE),
// HORS du renderer → il SURVIT au rebuild du parent et à l'ajout de lignes
// (loadMore simulé). Layout `builder` (SM-5 : aucun import `zcrud_list`).
//
// CONTRÔLE NÉGATIF (documenté) : sans le correctif (état dans la vue, recréé à
// chaque build / keyé par index), la sélection serait remise à zéro au rebuild —
// ces tests échoueraient.
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
  required List<ZListRow> rows,
  void Function(Set<String>)? onSelectionChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DynamicList.rows(
        _fields,
        rows,
        selection: selection,
        onSelectionChanged: onSelectionChanged,
        layout: ZListBuilderLayout(
          itemBuilder: (context, row, columns) =>
              Text('cell-${row.cells['name']}'),
        ),
      ),
    ),
  );
}

Checkbox _checkboxOfRow(WidgetTester tester, String id) => tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(ValueKey('zListRow_$id')),
        matching: find.byType(Checkbox),
      ),
    );

void main() {
  testWidgets('sélection préservée au REBUILD du parent (bug corrigé, AC4)',
      (tester) async {
    final selection = ZListSelectionController();
    await tester.pumpWidget(_app(selection: selection, rows: _rows(3)));

    // Sélectionne 2 lignes (via le contrôleur neutre, keyé par id).
    selection
      ..toggle('1')
      ..toggle('2');
    await tester.pump();
    expect(_checkboxOfRow(tester, '1').value, isTrue);
    expect(_checkboxOfRow(tester, '2').value, isTrue);
    expect(_checkboxOfRow(tester, '3').value, isFalse);

    // REBUILD du parent : NOUVELLE instance DynamicList sur des id identiques.
    await tester.pumpWidget(_app(selection: selection, rows: _rows(3)));
    expect(selection.selectedIds.value, <String>{'1', '2'});
    expect(_checkboxOfRow(tester, '1').value, isTrue);
    expect(_checkboxOfRow(tester, '2').value, isTrue);
    expect(_checkboxOfRow(tester, '3').value, isFalse);

    selection.dispose();
  });

  testWidgets('sélection préservée à l\'AJOUT de lignes (loadMore simulé, AC4)',
      (tester) async {
    final selection = ZListSelectionController()
      ..selectAll(<String>['1', '2']);
    await tester.pumpWidget(_app(selection: selection, rows: _rows(3)));
    expect(_checkboxOfRow(tester, '1').value, isTrue);

    // loadMore : le jeu passe de 3 → 5 lignes (nouveau ZListReady).
    await tester.pumpWidget(_app(selection: selection, rows: _rows(5)));
    expect(find.byKey(const ValueKey('zListRow_5')), findsOneWidget);
    expect(selection.selectedIds.value, <String>{'1', '2'});
    expect(_checkboxOfRow(tester, '1').value, isTrue);
    expect(_checkboxOfRow(tester, '2').value, isTrue);
    expect(_checkboxOfRow(tester, '5').value, isFalse);

    selection.dispose();
  });

  testWidgets('tap sur une case bascule la sélection + notifie onSelectionChanged',
      (tester) async {
    final selection = ZListSelectionController();
    Set<String>? notified;
    await tester.pumpWidget(
      _app(
        selection: selection,
        rows: _rows(3),
        onSelectionChanged: (ids) => notified = ids,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('zListRow_3')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();

    expect(selection.selectedIds.value, <String>{'3'});
    expect(notified, <String>{'3'});
    expect(_checkboxOfRow(tester, '3').value, isTrue);

    selection.dispose();
  });

  testWidgets('AC9 : case de sélection annoncée Semantics(selected:)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final selection = ZListSelectionController()..toggle('1');
    await tester.pumpWidget(_app(selection: selection, rows: _rows(2)));

    final wrappers = tester.widgetList<Semantics>(
      find.descendant(
        of: find.byKey(const ValueKey('zListRow_1')),
        matching: find.byType(Semantics),
      ),
    );
    expect(wrappers.any((s) => s.properties.selected == true), isTrue,
        reason: 'la case de la ligne sélectionnée doit exposer selected: true');

    handle.dispose();
    selection.dispose();
  });
}
