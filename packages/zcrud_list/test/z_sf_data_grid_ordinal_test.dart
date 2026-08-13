// Colonne de **numéro d'ordre** de la grille : elle numérote ce qui est
// AFFICHÉ (tri appliqué, page courante), jamais l'ordre d'origine des données.
//
// Chaque famille porte (1) sa garde de comportement et (2) son contre-témoin
// de non-régression (sans ordinal déclaré, le rendu est strictement inchangé).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

void main() {
  const fields = <ZFieldSpec>[
    ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
  ];
  // Ordre d'ORIGINE volontairement non alphabétique : un tri par « Nom » le
  // remanie, ce qui rend la garde discriminante.
  const rows = <ZListRow>[
    ZListRow(id: '1', cells: {'name': 'Alice'}),
    ZListRow(id: '2', cells: {'name': 'Bob'}),
    ZListRow(id: '3', cells: {'name': 'Chloé'}),
    ZListRow(id: '4', cells: {'name': 'David'}),
    ZListRow(id: '5', cells: {'name': 'Eve'}),
  ];

  ZListRenderRequest requestWith(ZListOrdinal ordinal) =>
      ZListRenderRequest.fromSchema(
        fields,
        rows,
        policy: ZColumnPolicy(ordinal: ordinal),
      );

  Widget frameWith(ZSfDataGridRenderer renderer, ZListRenderRequest req) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox(
            width: 800,
            height: 600,
            child: renderer.build(context, req),
          ),
        ),
      ),
    );
  }

  SfDataGrid gridOf(WidgetTester tester) =>
      tester.widget<SfDataGrid>(find.byType(SfDataGrid));

  /// Texte porté par une cellule construite par `buildRow` (le widget que
  /// Syncfusion peint réellement).
  String textOf(Widget widget) {
    var current = widget;
    while (true) {
      if (current is Text) return current.data ?? '';
      if (current is Container) {
        final child = current.child;
        if (child == null) return '';
        current = child;
        continue;
      }
      return '';
    }
  }

  /// Paires (numéro d'ordre, nom) **dans l'ordre où la grille les peint**.
  ///
  /// `DataGridSource.effectiveRows` EST la séquence rendue : Syncfusion y
  /// applique le tri (en place) et le générateur de lignes l'indexe pour
  /// peindre. On y relit donc exactement ce que l'utilisateur voit.
  List<List<String>> paintedRows(WidgetTester tester) {
    final source = gridOf(tester).source;
    return <List<String>>[
      for (final row in source.effectiveRows)
        <String>[
          for (final cell in source.buildRow(row)!.cells) textOf(cell),
        ],
    ];
  }

  Future<void> sortByName(WidgetTester tester) async {
    final source = gridOf(tester).source;
    source.sortedColumns
      ..clear()
      ..add(const SortColumnDetails(
        name: 'name',
        sortDirection: DataGridSortDirection.descending,
      ));
    await source.sort();
    await tester.pumpAndSettle();
  }

  // ─────────────────────────── 1. TRI ───────────────────────────
  group('la numérotation suit l\'AFFICHAGE, pas l\'ordre d\'origine', () {
    testWidgets('après un tri, la colonne « # » affiche 1, 2, 3… dans '
        'l\'ordre affiché', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          requestWith(const ZListOrdinal(enabled: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['1', 'Alice'],
          <String>['2', 'Bob'],
          <String>['3', 'Chloé'],
          <String>['4', 'David'],
          <String>['5', 'Eve'],
        ]),
        reason: 'sans tri, la numérotation suit déjà l\'affichage',
      );

      await sortByName(tester);

      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['1', 'Eve'],
          <String>['2', 'David'],
          <String>['3', 'Chloé'],
          <String>['4', 'Bob'],
          <String>['5', 'Alice'],
        ]),
        reason: 'le numéro décrit la POSITION à l\'écran : la première ligne '
            'affichée porte 1, quel que soit son rang d\'origine',
      );
    });

    testWidgets('le réglage historique withOrderNumber suit lui aussi '
        'l\'affichage après un tri', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(withOrderNumber: true),
          ZListRenderRequest.fromSchema(fields, rows),
        ),
      );
      await tester.pumpAndSettle();
      await sortByName(tester);

      expect(
        paintedRows(tester).map((cells) => cells.first).toList(),
        equals(<String>['1', '2', '3', '4', '5']),
      );
      expect(
        paintedRows(tester).map((cells) => cells.last).toList(),
        equals(<String>['Eve', 'David', 'Chloé', 'Bob', 'Alice']),
      );
    });
  });

  // ────────────────────────── 2. PAGINATION ──────────────────────────
  group('pagination : le décalage est DÉCLARÉ, jamais deviné', () {
    testWidgets('sans décalage déclaré, chaque page est numérotée à partir '
        'de 1', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(rowsPerPage: 2),
          requestWith(const ZListOrdinal(enabled: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['1', 'Alice'],
          <String>['2', 'Bob'],
        ]),
      );

      final source = gridOf(tester).source as DataPagerDelegate;
      await source.handlePageChange(0, 1);
      await tester.pumpAndSettle();

      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['1', 'Chloé'],
          <String>['2', 'David'],
        ]),
        reason: 'pageOffset vaut 0 : la page rendue est numérotée à partir '
            'de 1',
      );
    });

    testWidgets(
        'numérotation CONTINUE sous le pager interne : la page 2 enchaîne',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(rowsPerPage: 2),
          requestWith(
            const ZListOrdinal(enabled: true, continuousAcrossPages: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['1', 'Alice'],
          <String>['2', 'Bob'],
        ]),
      );

      final source = gridOf(tester).source as DataPagerDelegate;
      await source.handlePageChange(0, 1);
      await tester.pumpAndSettle();

      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['3', 'Chloé'],
          <String>['4', 'David'],
        ]),
        reason: 'l\'index de page est privé au rendu : c\'est LUI qui le '
            'transmet à la règle du cœur, l\'hôte ne pouvait pas le connaître',
      );
    });

    testWidgets('un décalage déclaré prolonge la numérotation', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(rowsPerPage: 2),
          requestWith(const ZListOrdinal(enabled: true, pageOffset: 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['3', 'Alice'],
          <String>['4', 'Bob'],
        ]),
      );
    });
  });

  // ───────────────────── 3. CONTRE-TÉMOIN ─────────────────────
  group('contre-témoin : sans ordinal déclaré, rendu strictement inchangé',
      () {
    testWidgets('aucune colonne « # » n\'est ajoutée', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          ZListRenderRequest.fromSchema(fields, rows),
        ),
      );
      await tester.pumpAndSettle();

      final grid = gridOf(tester);
      expect(grid.columns.length, equals(1));
      expect(grid.columns.single.columnName, equals('name'));
      expect(find.text('#'), findsNothing);
      expect(
        paintedRows(tester),
        equals(<List<String>>[
          <String>['Alice'],
          <String>['Bob'],
          <String>['Chloé'],
          <String>['David'],
          <String>['Eve'],
        ]),
      );
    });

    testWidgets('une déclaration désactivée reste sans effet', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          requestWith(const ZListOrdinal(header: 'N°')),
        ),
      );
      await tester.pumpAndSettle();

      expect(gridOf(tester).columns.length, equals(1));
      expect(find.text('N°'), findsNothing);
    });
  });

  // ───────────────────── 4. DÉCLARATION DU CŒUR ─────────────────────
  testWidgets('l\'en-tête et la largeur déclarés au cœur sont honorés',
      (tester) async {
    await tester.pumpWidget(
      frameWith(
        const ZSfDataGridRenderer(),
        requestWith(const ZListOrdinal(enabled: true, header: 'N°', width: 72)),
      ),
    );
    await tester.pumpAndSettle();

    final column = gridOf(tester).columns.first;
    expect(column.columnName, equals(ZListOrdinal.columnName));
    expect(column.width, equals(72.0));
    expect(find.text('N°'), findsOneWidget);
  });
}
