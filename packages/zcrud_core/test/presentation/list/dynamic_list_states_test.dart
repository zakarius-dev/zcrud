// AC6/AC8 (E4-2, AD-11/AD-13) : `DynamicList` rend QUATRE états UI accessibles
// et DISTINCTS (`loading`/`empty`/`noResults`/`error`). `empty` ≠ `noResults`
// (clés + textes distincts) ; `loading` et `error` portent `liveRegion: true`.
// Aucun import `zcrud_list`/Syncfusion (SM-5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = [ZFieldSpec(name: 'name', type: EditionFieldType.text)];

Future<void> _pump(WidgetTester tester, ZListViewState state) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DynamicList(fields: _fields, state: state),
      ),
    ),
  );
}

void main() {
  testWidgets('loading → indicateur de progression + liveRegion (AC6/AC8)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ZListLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Loading the list…'));
    expect(node.flagsCollection.isLiveRegion, isTrue,
        reason: 'loading doit être annoncé (liveRegion)');
    handle.dispose();
  });

  testWidgets('empty → message vide neutre (AC6)', (tester) async {
    await _pump(tester, const ZListEmpty());
    expect(find.byKey(const ValueKey('zListEmpty')), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
    // Le renderer n'est pas requis : aucune ZScopeError.
    expect(tester.takeException(), isNull);
  });

  testWidgets('noResults → message DISTINCT d\'empty (AC6)', (tester) async {
    await _pump(tester, const ZListNoResults());
    expect(find.byKey(const ValueKey('zListNoResults')), findsOneWidget);
    expect(find.text('No results match your filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty et noResults sont DISTINCTS (clés + textes) (AC6)',
      (tester) async {
    await _pump(tester, const ZListEmpty());
    expect(find.byKey(const ValueKey('zListEmpty')), findsOneWidget);
    expect(find.byKey(const ValueKey('zListNoResults')), findsNothing);
    final emptyText = 'No data yet';

    await _pump(tester, const ZListNoResults());
    expect(find.byKey(const ValueKey('zListNoResults')), findsOneWidget);
    expect(find.byKey(const ValueKey('zListEmpty')), findsNothing);
    final noResultsText = 'No results match your filters';

    expect(emptyText, isNot(equals(noResultsText)),
        reason: 'les deux états doivent porter des messages différents');
    expect(find.text(emptyText), findsNothing,
        reason: 'le message empty ne doit PAS apparaître en état noResults');
  });

  testWidgets('error → message de la ZFailure + liveRegion (AC6/AD-11)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ZListError(DomainFailure('boom réseau')));

    expect(find.byKey(const ValueKey('zListError')), findsOneWidget);
    expect(find.text('boom réseau'), findsOneWidget);
    expect(find.text('Failed to load the list'), findsOneWidget);

    final node =
        tester.getSemantics(find.byKey(const ValueKey('zListError')));
    expect(node.flagsCollection.isLiveRegion, isTrue,
        reason: 'l\'erreur doit être annoncée (liveRegion, AD-11)');
    expect(node.label, contains('boom réseau'));
    handle.dispose();
  });

  testWidgets('les états ne nécessitent AUCUN renderer (AC7)', (tester) async {
    for (final state in const <ZListViewState>[
      ZListLoading(),
      ZListEmpty(),
      ZListNoResults(),
      ZListError(DomainFailure('x')),
    ]) {
      await _pump(tester, state);
      expect(tester.takeException(), isNull,
          reason: 'état ${state.runtimeType} rendu sans renderer');
    }
  });
}
