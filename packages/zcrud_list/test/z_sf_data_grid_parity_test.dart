// Lot « parité de rendu » (CR DODLP) : largeur de colonnes RESPONSIVE, pager
// numéroté, long-press → copie de la valeur FORMATÉE, swipe révélant les
// actions de ligne DÉJÀ résolues, en-têtes multi-lignes, dimensionnement par
// colonne, hauteur de ligne adaptative.
//
// Chaque famille porte (1) sa garde de comportement et (2) son CONTRE-TÉMOIN
// de non-régression (renderer par défaut : aucun de ces réglages n'est posé).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

void main() {
  // Schéma à 2 colonnes de DONNÉES dont un `select` : la valeur BRUTE
  // ('DRAFT') diffère du texte FORMATÉ affiché ('Brouillon') — c'est ce qui
  // rend la garde de copie discriminante.
  const fields = <ZFieldSpec>[
    ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
    ZFieldSpec(
      name: 'status',
      type: EditionFieldType.select,
      label: 'Statut',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'DRAFT', label: 'Brouillon'),
        ZFieldChoice(value: 'DONE', label: 'Terminé'),
      ],
    ),
  ];
  const rows = <ZListRow>[
    ZListRow(id: '1', cells: {'name': 'Alice', 'status': 'DRAFT'}),
    ZListRow(id: '2', cells: {'name': 'Bob', 'status': 'DONE'}),
    ZListRow(id: '3', cells: {'name': 'Chloé', 'status': 'DRAFT'}),
    ZListRow(id: '4', cells: {'name': 'David', 'status': 'DONE'}),
    ZListRow(id: '5', cells: {'name': 'Eve', 'status': 'DRAFT'}),
  ];
  final request = ZListRenderRequest.fromSchema(fields, rows);

  Widget frameWith(
    ZSfDataGridRenderer renderer,
    ZListRenderRequest req, {
    ZListInteraction? interaction,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox(
            width: 800,
            height: 600,
            child: renderer.build(context, req, interaction: interaction),
          ),
        ),
      ),
    );
  }

  SfDataGrid gridOf(WidgetTester tester) =>
      tester.widget<SfDataGrid>(find.byType(SfDataGrid));

  GridColumn columnNamed(WidgetTester tester, String name) =>
      gridOf(tester).columns.firstWhere((c) => c.columnName == name);

  // ───────────────────────── 1. LARGEUR RESPONSIVE ─────────────────────────
  group('largeur de colonnes dérivée (plateforme × colonnes visibles)', () {
    test('RÈGLE legacy — web/desktop : > 3 colonnes ⇒ auto, sinon fill', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          ZSfDataGridRenderer.responsiveColumnWidthMode(
            visibleColumnCount: 3,
            platform: platform,
          ),
          equals(ColumnWidthMode.fill),
          reason: '$platform : 3 colonnes reste sous le seuil desktop',
        );
        expect(
          ZSfDataGridRenderer.responsiveColumnWidthMode(
            visibleColumnCount: 4,
            platform: platform,
          ),
          equals(ColumnWidthMode.auto),
          reason: '$platform : 4 colonnes franchit le seuil desktop',
        );
      }
      // Le web suit la règle desktop QUELLE QUE SOIT la plateforme hôte.
      expect(
        ZSfDataGridRenderer.responsiveColumnWidthMode(
          visibleColumnCount: 3,
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        equals(ColumnWidthMode.fill),
      );
      expect(
        ZSfDataGridRenderer.responsiveColumnWidthMode(
          visibleColumnCount: 4,
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        equals(ColumnWidthMode.auto),
      );
    });

    test('RÈGLE legacy — mobile : > 1 colonne ⇒ auto, sinon fill', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          ZSfDataGridRenderer.responsiveColumnWidthMode(
            visibleColumnCount: 1,
            platform: platform,
          ),
          equals(ColumnWidthMode.fill),
          reason: '$platform : 1 colonne reste sous le seuil mobile',
        );
        expect(
          ZSfDataGridRenderer.responsiveColumnWidthMode(
            visibleColumnCount: 2,
            platform: platform,
          ),
          equals(ColumnWidthMode.auto),
          reason: '$platform : 2 colonnes franchissent le seuil mobile',
        );
      }
    });

    testWidgets('CONFIG A (peu de colonnes) : 1 colonne mobile ⇒ fill',
        (tester) async {
      const oneField = <ZFieldSpec>[
        ZFieldSpec(name: 'name', type: EditionFieldType.text),
      ];
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          ZListRenderRequest.fromSchema(oneField, rows),
        ),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).columnWidthMode, equals(ColumnWidthMode.fill));
    });

    testWidgets('CONFIG B (beaucoup de colonnes) : 2 colonnes mobile ⇒ auto',
        (tester) async {
      await tester.pumpWidget(
        frameWith(const ZSfDataGridRenderer(), request),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).columnWidthMode, equals(ColumnWidthMode.auto));
    });

    testWidgets('CONFIG B bis (desktop) : 2 colonnes ⇒ fill (seuil plus haut)',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          request,
          platform: TargetPlatform.linux,
        ),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).columnWidthMode, equals(ColumnWidthMode.fill));
    });

    testWidgets('ÉCHAPPATOIRE : une valeur explicite écrase la dérivation',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          // 2 colonnes sur mobile ⇒ la dérivation dirait `auto`.
          const ZSfDataGridRenderer(columnWidthMode: ColumnWidthMode.fill),
          request,
        ),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).columnWidthMode, equals(ColumnWidthMode.fill));
    });
  });

  // ─────────────────────────── 2. PAGER NUMÉROTÉ ───────────────────────────
  group('pager numéroté (opt-in)', () {
    testWidgets('CONTRE-TÉMOIN : aucun pager par défaut', (tester) async {
      await tester.pumpWidget(frameWith(const ZSfDataGridRenderer(), request));
      await tester.pumpAndSettle();
      expect(find.byType(SfDataPager), findsNothing);
      // La grille reste la RACINE du rendu (aucune Column interposée par nous).
      expect(
        find.ancestor(
          of: find.byType(SfDataGrid),
          matching: find.byType(SfDataPager),
        ),
        findsNothing,
      );
      // Toutes les lignes sont dans la source.
      expect(gridOf(tester).source.rows.length, equals(rows.length));
    });

    testWidgets('rend N pages et NAVIGUE (page 2 ⇒ lignes 3-4)',
        (tester) async {
      await tester.pumpWidget(
        frameWith(const ZSfDataGridRenderer(rowsPerPage: 2), request),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SfDataPager), findsOneWidget);
      final pager = tester.widget<SfDataPager>(find.byType(SfDataPager));
      // 5 lignes / 2 par page ⇒ 3 pages.
      expect(pager.pageCount, equals(3));

      final source = gridOf(tester).source;
      // Page 1 : seules les 2 premières lignes sont rendues.
      expect(source.rows.length, equals(2));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Chloé'), findsNothing);

      // Navigation vers la page 2 (index 1) par le chemin `DataPagerDelegate`.
      await source.handlePageChange(0, 1);
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Chloé'), findsOneWidget);
      expect(find.text('David'), findsOneWidget);

      // Dernière page : la tranche est PARTIELLE (5 = 2 + 2 + 1).
      await source.handlePageChange(1, 2);
      await tester.pumpAndSettle();
      expect(source.rows.length, equals(1));
      expect(find.text('Eve'), findsOneWidget);
    });

    testWidgets('la grille reste VIRTUALISÉE (aucune ListView de lignes)',
        (tester) async {
      await tester.pumpWidget(
        frameWith(const ZSfDataGridRenderer(rowsPerPage: 2), request),
      );
      await tester.pumpAndSettle();
      // Le rendu du pager n'introduit pas de `Column` de lignes de données :
      // la grille reste seule responsable des lignes (virtualisation native).
      expect(find.byType(SfDataGrid), findsOneWidget);
      expect(gridOf(tester).source.rows.length, equals(2));
    });
  });

  // ───────────────── 3. LONG-PRESS → COPIE DE LA VALEUR FORMATÉE ────────────
  group('long-press d\'une cellule : copie de la valeur FORMATÉE', () {
    late List<String> copied;

    setUp(() {
      copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text'] as String,
          );
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('CONTRE-TÉMOIN : aucun onCellLongPress par défaut',
        (tester) async {
      await tester.pumpWidget(frameWith(const ZSfDataGridRenderer(), request));
      await tester.pumpAndSettle();
      expect(gridOf(tester).onCellLongPress, isNull);
    });

    testWidgets(
        'copie le LIBELLÉ affiché (« Brouillon »), JAMAIS la clé brute '
        '(« DRAFT »), et toaste', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(copyCellOnLongPress: true),
          request,
        ),
      );
      await tester.pumpAndSettle();

      final g = gridOf(tester);
      expect(g.onCellLongPress, isNotNull);
      g.onCellLongPress!(
        DataGridCellLongPressDetails(
          // rowIndex 0 = en-tête ⇒ la 1re ligne de données est à l'index 1.
          rowColumnIndex: RowColumnIndex(1, 1),
          column: columnNamed(tester, 'status'),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();

      expect(copied, equals(<String>['Brouillon']),
          reason: 'la valeur COPIÉE est le texte formaté affiché');
      expect(copied, isNot(contains('DRAFT')),
          reason: 'la clé technique brute ne doit JAMAIS partir au '
              'presse-papiers');
      // Retour visuel : le toaster par défaut de zcrud_ui_kit est un SnackBar.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('la ligne d\'EN-TÊTE ne copie rien (no-op, aucun throw)',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(copyCellOnLongPress: true),
          request,
        ),
      );
      await tester.pumpAndSettle();
      gridOf(tester).onCellLongPress!(
        DataGridCellLongPressDetails(
          rowColumnIndex: RowColumnIndex(0, 0),
          column: columnNamed(tester, 'name'),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('une colonne TECHNIQUE (#) ne copie rien', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(
            copyCellOnLongPress: true,
            withOrderNumber: true,
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();
      gridOf(tester).onCellLongPress!(
        DataGridCellLongPressDetails(
          rowColumnIndex: RowColumnIndex(1, 0),
          column: columnNamed(tester, ZListOrdinal.columnName),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
    });

    testWidgets('avec PAGER : copie la ligne de la PAGE COURANTE',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(
            copyCellOnLongPress: true,
            rowsPerPage: 2,
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();
      await gridOf(tester).source.handlePageChange(0, 1);
      await tester.pumpAndSettle();

      gridOf(tester).onCellLongPress!(
        DataGridCellLongPressDetails(
          rowColumnIndex: RowColumnIndex(1, 0),
          column: columnNamed(tester, 'name'),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(copied, equals(<String>['Chloé']),
          reason: 'l\'index de ligne est relatif à la TRANCHE visible');
    });
  });

  // ──────────────────────────────── 4. SWIPE ───────────────────────────────
  group('swipe d\'une ligne : révèle les actions DÉJÀ résolues', () {
    var invoked = <String>[];

    ZListInteraction interactionWith({bool editEnabled = true}) {
      return ZListInteraction(
        actionsFor: (row) => <ZResolvedRowAction>[
          ZResolvedRowAction(
            id: 'edit',
            labelKey: 'edit',
            enabled: editEnabled,
            icon: Icons.edit,
            onInvoke: () => invoked.add('edit:${row.id}'),
          ),
          ZResolvedRowAction(
            id: 'delete',
            labelKey: 'delete',
            enabled: true,
            destructive: true,
            icon: Icons.delete,
            onInvoke: () => invoked.add('delete:${row.id}'),
          ),
        ],
      );
    }

    setUp(() => invoked = <String>[]);

    testWidgets('CONTRE-TÉMOIN : aucun swipe par défaut', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(),
          request,
          interaction: interactionWith(),
        ),
      );
      await tester.pumpAndSettle();
      final g = gridOf(tester);
      expect(g.allowSwiping, isFalse);
      expect(g.onSwipeStart, isNull);
      expect(g.startSwipeActionsBuilder, isNull);
      // Défaut Syncfusion strictement conservé.
      expect(g.swipeMaxOffset, equals(200.0));
    });

    testWidgets('sans actionsFor, le swipe reste DÉSACTIVÉ même à true',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(swipeToRevealActions: true),
          request,
        ),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).allowSwiping, isFalse);
    });

    testWidgets('actif : sens start→end SEUL, offset dérivé du nb d\'actions',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(swipeToRevealActions: true),
          request,
          interaction: interactionWith(),
        ),
      );
      await tester.pumpAndSettle();
      final g = gridOf(tester);
      expect(g.allowSwiping, isTrue);
      expect(
        g.onSwipeStart!(
          DataGridSwipeStartDetails(
            rowIndex: 1,
            swipeDirection: DataGridRowSwipeDirection.startToEnd,
          ),
        ),
        isTrue,
      );
      expect(
        g.onSwipeStart!(
          DataGridSwipeStartDetails(
            rowIndex: 1,
            swipeDirection: DataGridRowSwipeDirection.endToStart,
          ),
        ),
        isFalse,
        reason: 'parité legacy : seul le sens start→end révèle les actions',
      );
      // 2 actions × 56 dp (plancher tactile AD-13) + 12 de marge.
      expect(g.swipeMaxOffset, equals(2 * 56.0 + 12.0));
    });

    testWidgets('le builder de swipe rend les MÊMES actions et les invoque',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(swipeToRevealActions: true),
          request,
          interaction: interactionWith(),
        ),
      );
      await tester.pumpAndSettle();

      final g = gridOf(tester);
      final swipeWidget = g.startSwipeActionsBuilder!(
        tester.element(find.byType(SfDataGrid)),
        g.source.rows.first,
        0,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: swipeWidget)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete));
      expect(invoked, equals(<String>['delete:1']),
          reason: 'le swipe réutilise les callbacks déjà liées à l\'entité');
    });

    testWidgets('ACL : une action désactivée en amont reste NON cliquable',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(swipeToRevealActions: true),
          request,
          interaction: interactionWith(editEnabled: false),
        ),
      );
      await tester.pumpAndSettle();

      final g = gridOf(tester);
      final swipeWidget = g.startSwipeActionsBuilder!(
        tester.element(find.byType(SfDataGrid)),
        g.source.rows.first,
        0,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: swipeWidget)),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull,
          reason: 'l\'ACL appliquée EN AMONT doit rester la seule autorité');
      await tester.tap(find.byIcon(Icons.edit));
      expect(invoked, isEmpty);
    });

    testWidgets('avec PAGER : l\'offset dérivé suit la PAGE COURANTE',
        (tester) async {
      // Pages d'UNE ligne, portant un nombre d'actions DIFFÉRENT : la ligne
      // « Alice » en a une, toutes les autres en ont trois. L'offset dérivé
      // doit donc changer d'une page à l'autre — sinon le swipe de la page
      // suivante serait tronqué (offset trop court) ou trop large.
      final interaction = ZListInteraction(
        actionsFor: (row) => <ZResolvedRowAction>[
          for (var i = 0; i < (row.id == '1' ? 1 : 3); i++)
            ZResolvedRowAction(
              id: 'action$i',
              labelKey: 'edit',
              enabled: true,
              icon: Icons.edit,
              onInvoke: () {},
            ),
        ],
      );
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(
            rowsPerPage: 1,
            swipeToRevealActions: true,
          ),
          request,
          interaction: interaction,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        gridOf(tester).swipeMaxOffset,
        equals(1 * 56.0 + 12.0),
        reason: 'page 1 : une seule action à révéler',
      );

      await gridOf(tester).source.handlePageChange(0, 1);
      await tester.pumpAndSettle();
      expect(
        gridOf(tester).swipeMaxOffset,
        equals(3 * 56.0 + 12.0),
        reason: 'page 2 : trois actions à révéler, offset recalculé',
      );

      // Retour en arrière : l'offset REDESCEND (jamais figé sur le maximum
      // atteint).
      await gridOf(tester).source.handlePageChange(1, 0);
      await tester.pumpAndSettle();
      expect(gridOf(tester).swipeMaxOffset, equals(1 * 56.0 + 12.0));
    });
  });

  // ───────────────── 5. EN-TÊTES MULTI-LIGNES (STACKED HEADERS) ─────────────
  group('en-têtes multi-lignes', () {
    testWidgets('CONTRE-TÉMOIN : aucune ligne empilée par défaut',
        (tester) async {
      await tester.pumpWidget(frameWith(const ZSfDataGridRenderer(), request));
      await tester.pumpAndSettle();
      expect(gridOf(tester).stackedHeaderRows, isEmpty);
    });

    testWidgets('un groupe couvre N colonnes et rend son libellé',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(
            stackedHeaders: <List<ZSfStackedHeader>>[
              <ZSfStackedHeader>[
                ZSfStackedHeader(
                  labelKey: 'Identité',
                  columnNames: <String>['name', 'status'],
                ),
              ],
            ],
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();

      final stacked = gridOf(tester).stackedHeaderRows;
      expect(stacked.length, equals(1));
      expect(stacked.first.cells.length, equals(1));
      expect(
        stacked.first.cells.first.columnNames,
        equals(<String>['name', 'status']),
      );
      expect(find.text('Identité'), findsOneWidget);
      // Les en-têtes de colonnes restent rendus SOUS la ligne empilée.
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Statut'), findsOneWidget);
    });
  });

  // ───────────────────── 6. DIMENSIONNEMENT PAR COLONNE ────────────────────
  group('dimensionnement par colonne', () {
    testWidgets('CONTRE-TÉMOIN : min/max non contraints par défaut',
        (tester) async {
      await tester.pumpWidget(frameWith(const ZSfDataGridRenderer(), request));
      await tester.pumpAndSettle();
      final col = columnNamed(tester, 'name');
      expect(col.minimumWidth.isNaN, isTrue);
      expect(col.maximumWidth.isNaN, isTrue);
      expect(col.columnWidthMode, equals(ColumnWidthMode.none));
      expect(gridOf(tester).allowColumnsResizing, isFalse);
    });

    testWidgets('width/min/max/mode appliqués À LA COLONNE VISÉE seulement',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(
            columnSizing: <String, ZSfColumnSizing>{
              'name': ZSfColumnSizing(
                width: 190,
                minimumWidth: 180,
                maximumWidth: 200,
                widthMode: ColumnWidthMode.fitByCellValue,
              ),
            },
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();

      final sized = columnNamed(tester, 'name');
      expect(sized.width, equals(190.0));
      expect(sized.minimumWidth, equals(180.0));
      expect(sized.maximumWidth, equals(200.0));
      expect(sized.columnWidthMode, equals(ColumnWidthMode.fitByCellValue));

      // La colonne NON visée garde ses valeurs d'origine.
      final other = columnNamed(tester, 'status');
      expect(other.minimumWidth.isNaN, isTrue);
      expect(other.columnWidthMode, equals(ColumnWidthMode.none));
    });

    testWidgets(
        'redimensionnement interactif : largeur PERSISTÉE sans recréer la '
        'source (AD-2)', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(allowColumnResizing: true),
          request,
        ),
      );
      await tester.pumpAndSettle();

      final g = gridOf(tester);
      expect(g.allowColumnsResizing, isTrue);
      expect(g.onColumnResizeUpdate, isNotNull);
      final sourceBefore = g.source;

      final accepted = g.onColumnResizeUpdate!(
        ColumnResizeUpdateDetails(
          column: columnNamed(tester, 'name'),
          columnIndex: 0,
          width: 321,
        ),
      );
      expect(accepted, isTrue);
      await tester.pumpAndSettle();

      expect(columnNamed(tester, 'name').width, equals(321.0));
      expect(identical(gridOf(tester).source, sourceBefore), isTrue,
          reason: 'la source mémoïsée ne doit JAMAIS être recréée par un '
              'redimensionnement (scroll/sélection préservés)');
    });
  });

  // ────────────────── 6 bis. STYLE CONDITIONNEL PAR CELLULE ────────────────
  group('style conditionnel par cellule', () {
    Container cellOf(WidgetTester tester, String text) => tester.widget(
          find
              .ancestor(
                of: find.text(text).first,
                matching: find.byType(Container),
              )
              .first,
        );

    testWidgets('CONTRE-TÉMOIN : aucun style par défaut', (tester) async {
      await tester.pumpWidget(frameWith(const ZSfDataGridRenderer(), request));
      await tester.pumpAndSettle();
      expect(cellOf(tester, 'Brouillon').color, isNull);
      expect(
        tester.widget<Text>(find.text('Brouillon').first).textAlign,
        equals(TextAlign.start),
      );
      expect(find.byType(DefaultTextStyle), findsWidgets);
    });

    testWidgets('le style ne frappe QUE les cellules ciblées par la condition',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          ZSfDataGridRenderer(
            // Condition MÉTIER : seul le statut « DRAFT » est mis en avant.
            cellStyleBuilder: (row, column) {
              if (column.name != 'status') return null;
              if (row.cells['status'] != 'DRAFT') return null;
              return const ZSfCellStyle(
                backgroundColor: Color(0xFFFFE0B2),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              );
            },
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();

      // Cellule CIBLÉE (statut DRAFT).
      expect(cellOf(tester, 'Brouillon').color, equals(const Color(0xFFFFE0B2)));
      expect(
        tester.widget<Text>(find.text('Brouillon').first).textAlign,
        equals(TextAlign.end),
      );
      final styled = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Brouillon').first,
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(styled.style.fontWeight, equals(FontWeight.bold));

      // Cellule NON ciblée (statut DONE) : rendu par défaut intact.
      expect(cellOf(tester, 'Terminé').color, isNull);
      expect(
        tester.widget<Text>(find.text('Terminé').first).textAlign,
        equals(TextAlign.start),
      );
      // Autre colonne de la MÊME ligne : intacte elle aussi.
      expect(cellOf(tester, 'Alice').color, isNull);
    });

    testWidgets(
        'cohabitation : le fond de cellStyleBuilder PRIME, sinon repli sur '
        'cellColorBuilder', (tester) async {
      await tester.pumpWidget(
        frameWith(
          ZSfDataGridRenderer(
            cellColorBuilder: (row, column) => const Color(0xFF00FF00),
            cellStyleBuilder: (row, column) => column.name == 'status'
                ? const ZSfCellStyle(backgroundColor: Color(0xFFFF0000))
                : const ZSfCellStyle(textStyle: TextStyle(fontSize: 20)),
          ),
          request,
        ),
      );
      await tester.pumpAndSettle();

      expect(cellOf(tester, 'Brouillon').color, equals(const Color(0xFFFF0000)),
          reason: 'le fond du style conditionnel prime');
      expect(cellOf(tester, 'Alice').color, equals(const Color(0xFF00FF00)),
          reason: 'un style SANS fond retombe sur cellColorBuilder '
              '(rétro-compatibilité)');
    });
  });

  // ─────────────────── 7. HAUTEUR DE LIGNE ADAPTATIVE ──────────────────────
  group('hauteur de ligne adaptative', () {
    const longFields = <ZFieldSpec>[
      ZFieldSpec(name: 'designation', type: EditionFieldType.text),
    ];
    final longRows = <ZListRow>[
      const ZListRow(
        id: '1',
        cells: <String, Object?>{
          'designation': 'Autres meubles en bois et leurs parties, y compris '
              'les sièges transformables en lits, présentés démontés ou non '
              'montés, destinés à l\'ameublement des habitations',
        },
      ),
    ];
    final longRequest = ZListRenderRequest.fromSchema(longFields, longRows);

    testWidgets('CONTRE-TÉMOIN : hauteur fixe + ellipse par défaut',
        (tester) async {
      await tester.pumpWidget(
        frameWith(const ZSfDataGridRenderer(), longRequest),
      );
      await tester.pumpAndSettle();
      expect(gridOf(tester).onQueryRowHeight, isNull);
      final text = tester.widget<Text>(find.textContaining('Autres meubles'));
      expect(text.overflow, equals(TextOverflow.ellipsis));
      expect(text.softWrap, isFalse);
    });

    testWidgets('active : les cellules PASSENT À LA LIGNE et la ligne grandit',
        (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(adaptiveRowHeight: true),
          longRequest,
        ),
      );
      await tester.pumpAndSettle();

      expect(gridOf(tester).onQueryRowHeight, isNotNull);
      final text = tester.widget<Text>(find.textContaining('Autres meubles'));
      expect(text.softWrap, isTrue,
          reason: 'sans passage à la ligne, la hauteur intrinsèque resterait '
              'celle d\'une ligne unique et le réglage serait INERTE');
      expect(text.overflow, isNot(equals(TextOverflow.ellipsis)));

      // La cellule occupe RÉELLEMENT plus que le plancher de 48 dp.
      final cellHeight = tester
          .getSize(
            find
                .ancestor(
                  of: find.textContaining('Autres meubles'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .height;
      expect(cellHeight, greaterThan(48.0));
    });

    testWidgets('maxRowHeight PLAFONNE la hauteur', (tester) async {
      await tester.pumpWidget(
        frameWith(
          const ZSfDataGridRenderer(adaptiveRowHeight: true, maxRowHeight: 72),
          longRequest,
        ),
      );
      await tester.pumpAndSettle();

      final cellHeight = tester
          .getSize(
            find
                .ancestor(
                  of: find.textContaining('Autres meubles'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .height;
      expect(cellHeight, lessThanOrEqualTo(72.0));
      expect(cellHeight, greaterThan(48.0));
    });
  });
}
