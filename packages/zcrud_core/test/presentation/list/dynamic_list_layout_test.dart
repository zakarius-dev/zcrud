// AC5 (E4-2, AD-8/SM-5) : les TROIS variantes de vue de `DynamicList` :
// `dataGrid` (délègue via faux renderer), `builder` (`ListView.builder` DANS le
// cœur), `custom` (widget arbitraire). Les vues `builder`/`custom` se rendent
// ENTIÈREMENT dans `zcrud_core` — ce test n'importe JAMAIS `zcrud_list` ni
// Syncfusion (démonstration exécutable SM-5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _CapturingRenderer extends ZListRenderer {
  ZListRenderRequest? captured;

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    captured = request;
    return const SizedBox(key: ValueKey('rendered'));
  }
}

const _fields = [
  ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
  ZFieldSpec(name: 'age', type: EditionFieldType.number),
];
const _rows = [
  ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
  ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
];

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox(height: 600, child: child))),
  );
}

void main() {
  testWidgets('dataGrid (défaut) délègue au renderer, colonnes dérivées (AC5)',
      (tester) async {
    final fake = _CapturingRenderer();
    await _pump(
      tester,
      DynamicList.rows(_fields, _rows, renderer: fake),
    );
    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured!.columns, equals(deriveColumns(_fields)));
  });

  testWidgets('builder → ListView.builder DANS le cœur (sans renderer) (AC5)',
      (tester) async {
    List<ZListColumn>? seenColumns;
    await _pump(
      tester,
      DynamicList(
        fields: _fields,
        state: const ZListReady(_rows),
        layout: ZListBuilderLayout(
          itemBuilder: (context, row, columns) {
            seenColumns = columns;
            return Text('${row.cells['name']}');
          },
        ),
        // AUCUN renderer fourni : la vue builder se rend seule.
      ),
    );
    expect(find.byKey(const ValueKey('zListBuilder')), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    // itemBuilder reçoit bien les colonnes dérivées.
    expect(seenColumns, equals(deriveColumns(_fields)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom → widget arbitraire (sans renderer) (AC5)',
      (tester) async {
    await _pump(
      tester,
      DynamicList(
        fields: _fields,
        state: const ZListReady(_rows),
        layout: ZListCustomLayout(
          customView: (context, request) => Text(
            'custom:${request.rows.length}:${request.columns.length}',
          ),
        ),
      ),
    );
    // 2 lignes, 2 colonnes dérivées.
    expect(find.text('custom:2:2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builder avec 0 ligne → ListView vide sans crash (AC5)',
      (tester) async {
    await _pump(
      tester,
      DynamicList(
        fields: _fields,
        state: const ZListReady(<ZListRow>[]),
        layout: ZListBuilderLayout(
          itemBuilder: (context, row, columns) => Text(row.id),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('zListBuilder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
