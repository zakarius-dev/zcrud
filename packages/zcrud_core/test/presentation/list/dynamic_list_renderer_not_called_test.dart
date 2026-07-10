// AC7 (E4-2, SM-5/AD-11) : PREUVE que les états vivent dans le WRAPPER, pas dans
// le contrat. Avec un faux `ZListRenderer` comptant ses appels, `DynamicList` en
// état `loading`/`empty`/`noResults`/`error` n'invoque JAMAIS le renderer ; il
// n'est appelé que pour `ready` + `ZListDataGridLayout`. Aucun import
// `zcrud_list`/Syncfusion (le cœur rend états ET vue liste sans backend).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _CountingRenderer extends ZListRenderer {
  int count = 0;

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    count++;
    return const SizedBox(key: ValueKey('rendered'));
  }
}

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];
const _rows = [ZListRow(id: '1', cells: {'name': 'Alice'})];

Future<void> _pump(
  WidgetTester tester,
  ZListViewState state,
  ZListRenderer renderer,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DynamicList(fields: _fields, state: state, renderer: renderer),
      ),
    ),
  );
}

void main() {
  testWidgets('renderer NON invoqué pour loading/empty/noResults/error (AC7)',
      (tester) async {
    for (final state in const <ZListViewState>[
      ZListLoading(),
      ZListEmpty(),
      ZListNoResults(),
      ZListError(ServerFailure('down')),
    ]) {
      final fake = _CountingRenderer();
      await _pump(tester, state, fake);
      expect(fake.count, equals(0),
          reason: 'renderer ne doit PAS être invoqué en état '
              '${state.runtimeType}');
      expect(find.byKey(const ValueKey('rendered')), findsNothing);
    }
  });

  testWidgets('renderer invoqué EXACTEMENT pour ready + dataGrid (AC7)',
      (tester) async {
    final fake = _CountingRenderer();
    await _pump(tester, const ZListReady(_rows), fake);
    expect(fake.count, equals(1));
    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
  });
}
