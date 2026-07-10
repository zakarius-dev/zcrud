// AC5/AC6 (E4-1, AD-8/AD-13) : `ZSfDataGridRenderer` rend un `SfDataGrid` réel
// depuis un `ZListRenderRequest` neutre — N colonnes (en-têtes = labels), N
// lignes, hauteur ≥ 48 dp. C'est le SEUL package zcrud qui importe Syncfusion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

void main() {
  const fields = [
    ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
    ZFieldSpec(name: 'age', type: EditionFieldType.number),
  ];
  const rows = [
    ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
    ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
    ZListRow(id: '3', cells: {'name': 'Chloé', 'age': 41}),
  ];
  // E4-2 : colonnes DÉRIVÉES (`ZListColumn`) via fromSchema.
  final request = ZListRenderRequest.fromSchema(fields, rows);

  testWidgets('rend un SfDataGrid avec en-têtes = labels et N lignes (AC5)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 800,
              height: 600,
              child: const ZSfDataGridRenderer().build(context, request),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Le widget de grille Syncfusion est présent.
    expect(find.byType(SfDataGrid), findsOneWidget);

    // En-têtes : `label ?? name` → 'Nom' (label) + 'age' (name, pas de label).
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('age'), findsOneWidget);

    // Cellules des lignes rendues (valeur brute toString).
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('hauteur de ligne/en-tête ≥ 48 dp (AC6, AD-13)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 800,
              height: 600,
              child: const ZSfDataGridRenderer().build(context, request),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<SfDataGrid>(find.byType(SfDataGrid));
    expect(grid.rowHeight, greaterThanOrEqualTo(48.0));
    expect(grid.headerRowHeight, greaterThanOrEqualTo(48.0));
    // Colonnes 1:1 depuis le ZFieldSpec[].
    expect(grid.columns.length, equals(fields.length));
    expect(grid.columns[0].columnName, equals('name'));
    expect(grid.columns[1].columnName, equals('age'));
  });

  testWidgets('const-constructible et injectable comme ZListRenderer (AC5)',
      (tester) async {
    // Prouve l'implémentation du port neutre (typage statique).
    const ZListRenderer renderer = ZSfDataGridRenderer();
    expect(renderer, isA<ZListRenderer>());
  });

  // ─────────────────── L3 (code-review E4-1) : bords ────────────────────────

  testWidgets('L3 : 0 ligne (rows == []) rend une grille sans crash',
      (tester) async {
    final emptyRows =
        ZListRenderRequest.fromSchema(fields, const <ZListRow>[]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 800,
              height: 600,
              child: const ZSfDataGridRenderer().build(context, emptyRows),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SfDataGrid), findsOneWidget);
    final grid = tester.widget<SfDataGrid>(find.byType(SfDataGrid));
    expect(grid.columns.length, equals(fields.length));
    // En-têtes présents, aucune cellule de données.
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('L3 : colonnes vides (columns == []) rend sans crash',
      (tester) async {
    final noCols = ZListRenderRequest.fromSchema(
      const <ZFieldSpec>[],
      const [ZListRow(id: '1', cells: {'name': 'Alice'})],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 800,
              height: 600,
              child: const ZSfDataGridRenderer().build(context, noCols),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SfDataGrid), findsOneWidget);
    final grid = tester.widget<SfDataGrid>(find.byType(SfDataGrid));
    expect(grid.columns, isEmpty);
  });

  testWidgets('L3 : noms de colonnes DUPLIQUÉS rendent sans crash '
      '(comportement défini : 1 GridColumn par ZFieldSpec)', (tester) async {
    const dupFields = [
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'A'),
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'B'),
    ];
    final dupRequest = ZListRenderRequest.fromSchema(
      dupFields,
      const [ZListRow(id: '1', cells: {'name': 'Alice'})],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 800,
              height: 600,
              child: const ZSfDataGridRenderer().build(context, dupRequest),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SfDataGrid), findsOneWidget);
    // Projection 1:1 : deux GridColumn même si columnName identique.
    final grid = tester.widget<SfDataGrid>(find.byType(SfDataGrid));
    expect(grid.columns.length, equals(2));
    expect(grid.columns.every((c) => c.columnName == 'name'), isTrue);
  });

  // ─────────────── L2 (E4-4, AC5) : statefulness scroll/sélection ────────────

  Widget frame(ZListRenderRequest req, {ZListInteraction? interaction}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox(
            width: 800,
            height: 600,
            child: const ZSfDataGridRenderer()
                .build(context, req, interaction: interaction),
          ),
        ),
      ),
    );
  }

  SfDataGrid grid(WidgetTester tester) =>
      tester.widget<SfDataGrid>(find.byType(SfDataGrid));

  testWidgets('AC5 : source MÉMOÏSÉE — même instance au rebuild (equal request)',
      (tester) async {
    await tester.pumpWidget(frame(request));
    await tester.pumpAndSettle();
    final source1 = grid(tester).source;

    // Rebuild avec une requête VALEUR-ÉGALE mais instance différente.
    final req2 = ZListRenderRequest.fromSchema(fields, rows);
    await tester.pumpWidget(frame(req2));
    await tester.pumpAndSettle();
    final source2 = grid(tester).source;

    expect(identical(source1, source2), isTrue,
        reason: 'la DataGridSource ne doit JAMAIS être recréée par build (L2)');
  });

  testWidgets('AC5 : source mise à jour EN PLACE quand les lignes changent',
      (tester) async {
    await tester.pumpWidget(frame(request));
    await tester.pumpAndSettle();
    final source1 = grid(tester).source;

    const newRows = [
      ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
      ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
      ZListRow(id: '3', cells: {'name': 'Chloé', 'age': 41}),
      ZListRow(id: '4', cells: {'name': 'Dan', 'age': 50}),
    ];
    await tester.pumpWidget(frame(ZListRenderRequest.fromSchema(fields, newRows)));
    await tester.pumpAndSettle();

    // MÊME instance de source (mise à jour en place), nouvelle ligne rendue.
    expect(identical(source1, grid(tester).source), isTrue);
    expect(find.text('Dan'), findsOneWidget);
  });

  testWidgets('AC5 : DataGridController PERSISTANT (identique au rebuild)',
      (tester) async {
    const interaction = ZListInteraction(mode: ZListSelectionMode.multiple);
    await tester.pumpWidget(frame(request, interaction: interaction));
    await tester.pumpAndSettle();
    final controller1 = grid(tester).controller;

    await tester.pumpWidget(frame(
      ZListRenderRequest.fromSchema(fields, rows),
      interaction: interaction,
    ));
    await tester.pumpAndSettle();

    expect(controller1, isNotNull);
    expect(identical(controller1, grid(tester).controller), isTrue);
  });

  testWidgets('AC5 : selectionMode dérivé de interaction.mode', (tester) async {
    await tester.pumpWidget(frame(
      request,
      interaction: const ZListInteraction(mode: ZListSelectionMode.multiple),
    ));
    await tester.pumpAndSettle();
    expect(grid(tester).selectionMode, SelectionMode.multiple);

    await tester.pumpWidget(frame(
      request,
      interaction: const ZListInteraction(mode: ZListSelectionMode.single),
    ));
    await tester.pumpAndSettle();
    expect(grid(tester).selectionMode, SelectionMode.single);
  });

  testWidgets('AC5 : onSelectionChanged remonte les id STABLES sélectionnés',
      (tester) async {
    Set<String>? captured;
    final interaction = ZListInteraction(
      mode: ZListSelectionMode.multiple,
      onSelectionChanged: (ids) => captured = ids,
    );
    await tester.pumpWidget(frame(request, interaction: interaction));
    await tester.pumpAndSettle();

    final g = grid(tester);
    // Simule une sélection Syncfusion de la 2ᵉ ligne (id '2') via le controller
    // persistant, puis déclenche le callback de la grille.
    g.controller!.selectedRows = <DataGridRow>[g.source.rows[1]];
    g.onSelectionChanged!(<DataGridRow>[g.source.rows[1]], <DataGridRow>[]);

    expect(captured, <String>{'2'});
  });

  // ───── MEDIUM-1 (perf, code-review E4-4) : mémoïsation L2 vs sélection ─────

  List<ZResolvedRowAction> sampleActions(ZListRow row) => <ZResolvedRowAction>[
        ZResolvedRowAction(
          id: 'del',
          labelKey: 'delete',
          enabled: true,
          onInvoke: () {},
        ),
      ];

  // Reproduit `DynamicList._buildInteraction` : chaque build recrée une closure
  // `actionsFor` d'IDENTITÉ DIFFÉRENTE (instable), tout en gardant les mêmes
  // données. C'est cette instabilité qui, avant le correctif, forçait
  // `_source.update()` (efface/reconstruit TOUS les DataGridRow) à chaque tick.
  ZListInteraction interactionWith(Set<String> selectedIds) => ZListInteraction(
        mode: ZListSelectionMode.multiple,
        selectedIds: selectedIds,
        onSelectionChanged: (_) {},
        actionsFor: (row) => sampleActions(row),
      );

  testWidgets(
      'MEDIUM-1 : un changement de SÉLECTION ne reconstruit PAS la source '
      '(0 rebuild), un changement de LIGNES la reconstruit (1)', (tester) async {
    await tester.pumpWidget(frame(request, interaction: interactionWith(const {})));
    await tester.pumpAndSettle();
    // Instance de la 1re DataGridRow : proxy de « la source a été reconstruite »
    // (update() efface _dataRows et recrée des instances fraîches).
    final firstRowBefore = grid(tester).source.rows.first;

    // (1) Changement de SÉLECTION uniquement : nouvelle closure actionsFor,
    // MÊME request/données → AUCUNE reconstruction de source attendue.
    await tester
        .pumpWidget(frame(request, interaction: interactionWith(const {'1'})));
    await tester.pumpAndSettle();
    expect(
      identical(grid(tester).source.rows.first, firstRowBefore),
      isTrue,
      reason: 'cocher une case NE DOIT PAS effacer/reconstruire les DataGridRow '
          '(MEDIUM-1) : mémoïsation L2 préservée',
    );

    // (2) Vrai changement de LIGNES → la source EST reconstruite (1 rebuild).
    const newRows = [
      ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
      ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
      ZListRow(id: '3', cells: {'name': 'Chloé', 'age': 41}),
      ZListRow(id: '4', cells: {'name': 'Dan', 'age': 50}),
    ];
    await tester.pumpWidget(frame(
      ZListRenderRequest.fromSchema(fields, newRows),
      interaction: interactionWith(const {'1'}),
    ));
    await tester.pumpAndSettle();
    expect(
      identical(grid(tester).source.rows.first, firstRowBefore),
      isFalse,
      reason: 'un vrai changement de lignes DOIT reconstruire la source',
    );
    expect(find.text('Dan'), findsOneWidget);
  });

  testWidgets(
      'MEDIUM-1 : apparition/disparition d\'actions (null↔non-null) '
      'reconstruit la source (nombre de cellules par ligne change)',
      (tester) async {
    // Sans actions au départ.
    await tester.pumpWidget(frame(
      request,
      interaction: const ZListInteraction(mode: ZListSelectionMode.multiple),
    ));
    await tester.pumpAndSettle();
    final firstRowBefore = grid(tester).source.rows.first;
    expect(grid(tester).columns.length, equals(2));

    // Les actions APPARAISSENT → colonne d'actions ajoutée, source reconstruite.
    await tester.pumpWidget(frame(request, interaction: interactionWith(const {})));
    await tester.pumpAndSettle();
    expect(identical(grid(tester).source.rows.first, firstRowBefore), isFalse);
    expect(grid(tester).columns.length, equals(3));
  });

  // ───── LOW-1 (code-review E4-4) : persistance VISUELLE de la sélection L2 ─────

  testWidgets(
      'LOW-1 : la sélection L2 PERSISTE (controller.selectedRows) au rebuild '
      'parent', (tester) async {
    await tester.pumpWidget(frame(
      request,
      interaction: const ZListInteraction(
        mode: ZListSelectionMode.multiple,
        selectedIds: {'2'},
      ),
    ));
    await tester.pumpAndSettle();
    final g1 = grid(tester);
    // La ligne d'id '2' (index 1) est bien la ligne sélectionnée du controller.
    expect(g1.controller!.selectedRows, contains(g1.source.rows[1]));
    expect(g1.controller!.selectedRows.length, equals(1));

    // Rebuild parent : nouvelle instance de request VALEUR-ÉGALE, même sélection.
    await tester.pumpWidget(frame(
      ZListRenderRequest.fromSchema(fields, rows),
      interaction: const ZListInteraction(
        mode: ZListSelectionMode.multiple,
        selectedIds: {'2'},
      ),
    ));
    await tester.pumpAndSettle();
    final g2 = grid(tester);
    // Round-trip : la sélection VISUELLE survit (re-mappée sur les instances
    // fraîches par id stable), toujours 1 ligne, toujours la 2ᵉ (id '2').
    expect(g2.controller!.selectedRows, contains(g2.source.rows[1]));
    expect(g2.controller!.selectedRows.length, equals(1));
  });

  testWidgets('AC5 : colonne d\'actions rendue depuis interaction.actionsFor',
      (tester) async {
    final interaction = ZListInteraction(
      actionsFor: (row) => <ZResolvedRowAction>[
        ZResolvedRowAction(
          id: 'del',
          labelKey: 'delete',
          enabled: true,
          onInvoke: () {},
        ),
      ],
    );
    await tester.pumpWidget(frame(request, interaction: interaction));
    await tester.pumpAndSettle();

    // Colonne d'actions ajoutée (au-delà des 2 colonnes de données).
    expect(grid(tester).columns.length, equals(3));
    expect(find.widgetWithText(TextButton, 'Delete'), findsWidgets);
  });
}
