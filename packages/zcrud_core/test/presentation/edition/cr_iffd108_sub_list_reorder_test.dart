// La sous-liste réordonne par GLISSER-DÉPOSER à poignée via le port
// `ZReorderRenderer` — les flèches monter/descendre ont disparu des DEUX
// modes (`inline` et `compact`), remplacées, jamais doublées.
//
// Couvre :
//  - plus AUCUNE flèche d'ordre dans la sous-liste, dans aucun mode ;
//  - le glisser-déposer déplace RÉELLEMENT (ordre agrégé persisté) en
//    `compact` ET en `inline`, sans renderer injecté (repli interne) ;
//  - compact réordonnable : les lignes vivent HORS de la table de résumé
//    (une `Table` fige ses lignes), les en-têtes de colonnes restent ;
//  - la poignée est une cible ≥ 48 dp (invariant AD-13) ;
//  - un renderer injecté au scope est CONSULTÉ (itemIds, libellés
//    sémantiques, `onReorder` qui persiste) ;
//  - adversarial : `reorderable: false` (ou lecture seule) + renderer
//    injecté ⇒ le port n'est PAS consulté, aucune poignée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZFieldSpec _compactField({bool? reorderable, bool readOnly = false}) =>
    ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      readOnly: readOnly,
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: reorderable,
        summaryFields: const <String>['f1'],
      ),
    );

const _inlineField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.inline,
  ),
);

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
  <String, dynamic>{'f1': 'B'},
  <String, dynamic>{'f1': 'C'},
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

List<String> _values(List<Map<String, dynamic>> list) =>
    <String>[for (final it in list) it['f1'] as String];

/// Glisse la poignée [from] jusqu'au centre de la poignée [to] (+ un léger
/// dépassement) — le geste réel du repli interne (`SliverReorderableList` +
/// `ReorderableDragStartListener` : glissement immédiat depuis la poignée).
Future<void> _dragHandle(WidgetTester tester, int from, int to) async {
  final handles = find.byIcon(Icons.drag_indicator_rounded);
  final start = tester.getCenter(handles.at(from));
  final end = tester.getCenter(handles.at(to)) + const Offset(0, 24);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 100));
  // Progression en PALIERS pompés : le suivi de cible du glissement est
  // recalculé à chaque frame, pas sur un saut unique.
  final step = Offset(0, (end.dy - start.dy) / 3);
  for (var i = 0; i < 3; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Renderer d'hôte factice : enregistre la requête reçue et rend une simple
/// colonne — assez pour mesurer que le port est consulté et que le contrat
/// (`itemIds`, libellés, `onReorder`) lui est servi.
class _RecordingReorderRenderer extends ZReorderRenderer {
  ZReorderRenderRequest? lastRequest;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    lastRequest = request;
    return Column(
      children: <Widget>[
        for (var i = 0; i < request.itemIds.length; i++)
          request.itemBuilder(context, i),
      ],
    );
  }
}

void main() {
  testWidgets('plus AUCUNE flèche d\'ordre — compact réordonnable ET inline',
      (tester) async {
    await tester.pumpWidget(_host(Column(
      children: <Widget>[
        ZSubListFieldWidget(
          field: _compactField(reorderable: true),
          initialValue: _seed,
          acl: const ZAllowAllAcl(),
          onChanged: (_) {},
        ),
        ZSubListFieldWidget(
          field: _inlineField,
          initialValue: _seed,
          onChanged: (_) {},
        ),
      ],
    )));
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    // Les deux modes offrent la poignée à la place : 3 lignes chacun.
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(6));
  });

  testWidgets(
      'compact : le glisser-déposer déplace RÉELLEMENT — ordre agrégé '
      'persisté (repli interne, aucun renderer injecté)', (tester) async {
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(reorderable: true),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (list) => captured = list,
    )));
    await tester.pump();
    await _dragHandle(tester, 0, 1);
    expect(captured, isNotNull);
    expect(_values(captured!), <String>['B', 'A', 'C']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline : le glisser-déposer déplace RÉELLEMENT — ordre agrégé persisté',
      (tester) async {
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _inlineField,
      initialValue: _seed,
      onChanged: (list) => captured = list,
    )));
    await tester.pump();
    await _dragHandle(tester, 0, 1);
    expect(captured, isNotNull);
    expect(_values(captured!), <String>['B', 'A', 'C']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact réordonnable : les lignes vivent HORS de la table de résumé, '
      'les en-têtes de colonnes restent', (tester) async {
    // Étalon : non réordonnable ⇒ la table de résumé est rendue.
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byType(Table), findsOneWidget);

    // Réordonnable ⇒ une `Table` figerait ses lignes : liste de lignes à
    // poignée, l'en-tête de colonne (`F1`) est conservé.
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(reorderable: true),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byType(Table), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('la poignée est une cible ≥ 48 dp (invariant AD-13)',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(reorderable: true),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    final box = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.drag_indicator_rounded).first,
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
      'un renderer injecté au scope est CONSULTÉ : itemIds, libellés '
      'sémantiques, et son onReorder persiste l\'ordre', (tester) async {
    final renderer = _RecordingReorderRenderer();
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: renderer,
      child: ZSubListFieldWidget(
        field: _compactField(reorderable: true),
        initialValue: _seed,
        onChanged: (list) => captured = list,
      ),
    )));
    await tester.pump();
    final request = renderer.lastRequest;
    expect(request, isNotNull, reason: 'le port n\'a pas été consulté');
    expect(request!.itemIds, hasLength(3));
    expect(request.maxColumns, 1);
    // Voie non gestuelle : les libellés des actions sémantiques traversent la
    // requête (contrat du port — la suppression des flèches ne se paie pas
    // d\'une régression d\'accessibilité).
    expect(request.moveBeforeSemanticLabel, isNotNull);
    expect(request.moveAfterSemanticLabel, isNotNull);

    request.onReorder(0, 2);
    await tester.pump();
    expect(captured, isNotNull);
    expect(_values(captured!), <String>['B', 'C', 'A']);
  });

  testWidgets(
      'adversarial : reorderable: false + renderer injecté ⇒ port NON '
      'consulté, aucune poignée', (tester) async {
    final renderer = _RecordingReorderRenderer();
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: renderer,
      child: ZSubListFieldWidget(
        field: _compactField(reorderable: false),
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(renderer.lastRequest, isNull);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });

  testWidgets(
      'adversarial : lecture seule + renderer injecté ⇒ port NON consulté, '
      'aucune poignée', (tester) async {
    final renderer = _RecordingReorderRenderer();
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: renderer,
      child: ZSubListFieldWidget(
        field: _compactField(reorderable: true, readOnly: true),
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(renderer.lastRequest, isNull);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });
}
