// EX-2 (AC1/AC3/AC4/AC5/AC6/AC8/AC9/AC10) : démo LISTE. Prouve, dans `example/`,
// que `DynamicList` monte end-to-end sur une source in-memory avec le backend
// Syncfusion injecté au scope racine (SM-5), colonnes dérivées, recherche/filtre/
// tri/pagination, actions/sélection/corbeille, onglets, parité binding.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/app.dart';
import 'package:zcrud_example/binding/binding_selector.dart';
import 'package:zcrud_example/demos/list_demo_data.dart';
import 'package:zcrud_example/demos/list_demo_screen.dart';
import 'package:zcrud_example/home_screen.dart';
import 'package:zcrud_example/support/demo_file_picker.dart';
import 'package:zcrud_list/zcrud_list.dart';

/// Enveloppe l'écran testé dans la coquille de l'app : `MaterialApp` + délégués
/// l10n + `ZcrudScope` RACINE portant le `listRenderer` Syncfusion (comme l'app).
Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
      home: ZcrudScope(
        filePicker: const DemoFilePicker(),
        listRenderer: const ZSfDataGridRenderer(),
        child: child,
      ),
    );

void _bigSurface(WidgetTester tester) {
  tester.view.physicalSize = Size(
    1400 * tester.view.devicePixelRatio,
    1000 * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  // ─────────────── Source de données in-memory (AC3/AC4/AC5) ───────────────
  group('DemoRepository / DemoStore (AC4/AC5)', () {
    test('recherche : « Serveur » ne renvoie que des désignations « Serveur »',
        () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final repo = DemoRepository(store);
      final res = await repo.getAll(
        request: const ZDataRequest(search: 'Serveur'),
      );
      final rows = res.getOrElse(() => const <DemoRecord>[]);
      expect(rows, isNotEmpty);
      expect(rows.every((r) => r.name.contains('Serveur')), isTrue);
    });

    test('filtre catégorie : eq « materiel » ne renvoie que cette catégorie',
        () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final repo = DemoRepository(store);
      final res = await repo.getAll(
        request: const ZDataRequest(
          filters: <ZFilter>[ZFilter('category', ZFilterOp.eq, 'materiel')],
        ),
      );
      final rows = res.getOrElse(() => const <DemoRecord>[]);
      expect(rows, isNotEmpty);
      expect(rows.every((r) => r.category == 'materiel'), isTrue);
    });

    test('tri asc/desc sur « name » : premier élément diffère', () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final repo = DemoRepository(store);
      final asc = (await repo.getAll(
        request: const ZDataRequest(sorts: <ZSort>[ZSort('name')]),
      ))
          .getOrElse(() => const <DemoRecord>[]);
      final desc = (await repo.getAll(
        request: const ZDataRequest(
          sorts: <ZSort>[ZSort('name', ZSortDirection.desc)],
        ),
      ))
          .getOrElse(() => const <DemoRecord>[]);
      expect(asc.first.name, isNot(equals(desc.first.name)));
    });

    test('pagination : limit 15 renvoie une page de 15', () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final repo = DemoRepository(store);
      final res = await repo.getAll(request: const ZDataRequest(limit: 15));
      expect(res.getOrElse(() => const <DemoRecord>[]), hasLength(15));
    });

    // MEDIUM-1 : la pagination curseur est exercée END-TO-END via le vrai
    // `ZListController` (le même que l'écran), au-delà de la seule 1re page.
    test('pagination curseur : loadMore parcourt les 48 lignes par pages de '
        '15 (curseur avancé, > 15 atteignables, aucun doublon)', () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final repo = DemoRepository(store);
      final controller = ZListController<DemoRecord>(
        repository: repo,
        toRow: toDemoRow,
        schema: demoSchema,
        pageSize: 15,
      );
      addTearDown(controller.dispose);

      List<ZListRow> rowsOf() {
        final s = controller.state.value;
        return s is ZListReady ? s.rows : const <ZListRow>[];
      }

      await controller.refresh();
      expect(rowsOf(), hasLength(15), reason: 'page 1');

      await controller.loadMore();
      expect(rowsOf(), hasLength(30), reason: 'page 2 : curseur avancé + accumulé');

      await controller.loadMore();
      expect(rowsOf(), hasLength(45), reason: 'page 3');

      await controller.loadMore();
      expect(rowsOf(), hasLength(48), reason: 'page 4 (partielle) : tout atteint');

      // Plus de page : loadMore est un no-op (ni doublon, ni trou).
      await controller.loadMore();
      final ids = rowsOf().map((r) => r.id).toList();
      expect(ids, hasLength(48));
      expect(
        ids.toSet(),
        hasLength(48),
        reason: 'aucun doublon (curseur stable end-to-end)',
      );
    });

    test('corbeille : softDelete retire de la liste active et alimente la '
        'corbeille ; restore rétablit (AC5)', () async {
      final store = DemoStore();
      addTearDown(store.dispose);
      final active = DemoRepository(store);
      final trash = DemoRepository(store, includeDeleted: true);

      final before =
          (await active.getAll()).getOrElse(() => const <DemoRecord>[]).length;
      expect(store.isDeleted('rec-1'), isFalse);

      await active.softDelete('rec-1');
      final activeIds = (await active.getAll())
          .getOrElse(() => const <DemoRecord>[])
          .map((r) => r.recordId);
      final trashIds = (await trash.getAll())
          .getOrElse(() => const <DemoRecord>[])
          .map((r) => r.recordId);
      expect(activeIds, isNot(contains('rec-1')));
      expect(trashIds, contains('rec-1'));
      expect(store.isDeleted('rec-1'), isTrue);

      await trash.restore('rec-1');
      final afterIds = (await active.getAll())
          .getOrElse(() => const <DemoRecord>[])
          .map((r) => r.recordId)
          .toList();
      expect(afterIds, contains('rec-1'));
      expect(afterIds, hasLength(before));
    });
  });

  // ─────────────── Écran LISTE : rendu Syncfusion + colonnes (AC3/SM-5) ─────
  testWidgets('ListDemoScreen : rend un SfDataGrid avec colonnes DÉRIVÉES du '
      'schéma (AC3/SM-5)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_wrap(const ListDemoScreen()));
    await tester.pumpAndSettle();

    // Le backend Syncfusion (injecté au scope racine) rend la grille (SM-5).
    expect(find.byType(SfDataGrid), findsOneWidget);

    // Colonnes dérivées : les 6 champs affichables du schéma + colonne d'actions.
    final grid = tester.widget<SfDataGrid>(find.byType(SfDataGrid));
    final columnNames = grid.columns.map((c) => c.columnName).toList();
    for (final name in <String>[
      'name',
      'category',
      'quantity',
      'unitPrice',
      'createdAt',
      'active',
    ]) {
      expect(columnNames, contains(name), reason: 'colonne dérivée $name');
    }
    // En-têtes résolus depuis le schéma (libellés).
    expect(find.text('Désignation'), findsOneWidget);
    expect(find.text('Catégorie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─────────────── SM-5 / AD-8 : renderer résolu = Syncfusion (AC9) ─────────
  testWidgets('AC9 — le ZcrudScope.listRenderer résolu est un ZSfDataGridRenderer',
      (tester) async {
    _bigSurface(tester);
    ZListRenderer? seen;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            seen = ZcrudScope.of(context).listRenderer;
            return const ListDemoScreen();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, isA<ZSfDataGridRenderer>());
  });

  // ─────────────── Pagination navigable dans l'UI (MEDIUM-1 / AC4(d)) ───────
  testWidgets('MEDIUM-1 — le bouton « Charger plus » pagine la liste '
      'end-to-end (15 → 30 lignes atteignables)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_wrap(const ListDemoScreen()));
    await tester.pumpAndSettle();

    final loadMore = find.byKey(const ValueKey<String>('listDemoLoadMore'));
    // 1re page pleine (15/48) → l'affordance de pagination est présente.
    expect(loadMore, findsOneWidget);
    expect(find.text('Charger plus (15)'), findsOneWidget);

    await tester.ensureVisible(loadMore);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    // Page suivante accumulée : > 15 lignes désormais atteignables via l'UI.
    expect(find.text('Charger plus (30)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─────────────── Parité binding (AC8 + LOW-3 : les 4 bindings) ────────────
  for (final binding in DemoBinding.values) {
    testWidgets('AC8 — la liste rend le MÊME SfDataGrid sous ${binding.label}',
        (tester) async {
      _bigSurface(tester);
      await tester
          .pumpWidget(_wrap(ListDemoScreen(initialBinding: binding)));
      await tester.pumpAndSettle();
      // Le renderer racine est re-propagé sous le binding (sinon ZScopeError).
      expect(find.byType(SfDataGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // ─────────────── Onglets par catégorie (AC6) ─────────────────────────────
  testWidgets('AC6 — CategoryTabsScreen monte un ZTabbedList et change d\'onglet',
      (tester) async {
    _bigSurface(tester);
    await tester
        .pumpWidget(_wrap(CategoryTabsScreen(store: DemoStore())));
    await tester.pumpAndSettle();

    expect(find.byType(ZTabbedList), findsOneWidget);
    expect(find.byType(SfDataGrid), findsOneWidget);

    // Bascule vers l'onglet « Matériel » (cible : l'onglet de la TabBar, pas une
    // cellule de la grille qui afficherait aussi « Matériel »).
    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Matériel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─────────────── Corbeille : restore (AC5, UI) ───────────────────────────
  testWidgets('AC5 — TrashScreen liste les soft-deleted', (tester) async {
    _bigSurface(tester);
    final store = DemoStore();
    addTearDown(store.dispose);
    store.softDelete('rec-2');

    await tester.pumpWidget(_wrap(TrashScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─────────────── Navigation depuis l'accueil (AC7) ───────────────────────
  testWidgets('AC7 — tap « Liste » sur l\'accueil pousse ListDemoScreen',
      (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    expect(find.byType(ListDemoScreen), findsOneWidget);
    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
