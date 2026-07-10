// AC4/AC5/AC6/AC9/AC10 (E4-5, AD-8/AD-2/AD-15/AD-13/SM-5) : `ZTabbedList` —
// onglets de catégorisation où CHAQUE onglet est une liste indépendante
// (catégorie via `baseFilters`) ; état (recherche/sélection) PRÉSERVÉ au switch
// (contrôleurs NON recréés, `AutomaticKeepAliveClientMixin`) ; sélections
// INDÉPENDANTES par onglet ; a11y (`Tab` label l10n résolu, onglet actif
// `selected`, ≥ 48 dp). Chrome pur-Flutter Material + listes en layout `builder`
// (SM-5 exécutable SANS `zcrud_list`/Syncfusion).
import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Collecte les `SemanticsData` du sous-arbre satisfaisant [test] (racine non
/// dépréciée via `getSemantics`) — patron a11y du dépôt.
List<SemanticsData> _collectSemantics(
  WidgetTester tester,
  Finder root,
  bool Function(SemanticsData) test,
) {
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (test(data)) out.add(data);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(root));
  return out;
}

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'status', type: EditionFieldType.text),
];

class _Item implements ZEntity {
  const _Item(this._id, this.status);
  final String _id;
  final String status;
  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

ZListRow _toRow(_Item it) => ZListRow(
      id: it.id!,
      cells: <String, Object?>{'name': it.id, 'status': it.status},
    );

/// Compteur GLOBAL de créations de contrôleur par catégorie (prouve « contrôleur
/// non recréé au switch » = keep-alive, AC5). Réinitialisé par chaque test.
final Map<String, int> _initCounts = <String, int>{};

class _CategoryRepo implements ZRepository<_Item> {
  _CategoryRepo(this._data);
  final List<_Item> _data;
  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    final rows = <ZListRow>[for (final it in _data) _toRow(it)];
    final page = zApplyListRequest(rows, req, schema: _schema);
    final byId = <String, _Item>{for (final it in _data) it.id!: it};
    return Right(<_Item>[for (final r in page.rows) byId[r.id]!]);
  }

  @override
  Stream<List<_Item>> watchAll() => const Stream<List<_Item>>.empty();
  @override
  Stream<List<_Item>> watch(ZDataRequest request) =>
      const Stream<List<_Item>>.empty();
  @override
  Future<ZResult<_Item>> getById(String id) async =>
      Left(NotFoundFailure('n/a', id: id));
  @override
  Future<ZResult<_Item>> save(_Item item, {String? collectionId}) async =>
      Right(item);
  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);
  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);
  @override
  void dispose() {}
}

/// Vue d'un onglet-catégorie : possède SON `ZListController` (baseFilters =
/// filtre de catégorie) créé UNE fois dans `initState` (compté), rend une
/// `DynamicList` builder avec la [selection] fournie (indépendante par onglet)
/// et une barre de recherche.
class _CategoryPane extends StatefulWidget {
  const _CategoryPane({
    required this.repo,
    required this.category,
    required this.filter,
    required this.selection,
    super.key,
  });
  final _CategoryRepo repo;
  final String category;
  final ZFilter filter;
  final ZListSelectionController selection;

  @override
  State<_CategoryPane> createState() => _CategoryPaneState();
}

class _CategoryPaneState extends State<_CategoryPane> {
  late final ZListController<_Item> _controller;

  @override
  void initState() {
    super.initState();
    _initCounts.update(widget.category, (v) => v + 1, ifAbsent: () => 1);
    _controller = ZListController<_Item>(
      repository: widget.repo,
      toRow: _toRow,
      schema: _schema,
      baseFilters: <ZFilter>[widget.filter],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          key: ValueKey<String>('search_${widget.category}'),
          onChanged: _controller.setSearch,
        ),
        Expanded(
          child: ValueListenableBuilder<ZListViewState>(
            valueListenable: _controller.state,
            builder: (context, state, _) => DynamicList<_Item>(
              fields: _schema,
              state: state,
              selection: widget.selection,
              layout: ZListBuilderLayout(
                itemBuilder: (context, row, columns) =>
                    Text('item-${row.id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _host({
  required _CategoryRepo repo,
  required Map<String, ZListSelectionController> selections,
}) {
  ZListTab tab(String category, String status) => ZListTab.category(
        labelKey: 'tab.$category',
        filters: <ZFilter>[ZFilter('status', ZFilterOp.eq, status)],
        buildList: (context, filters) => _CategoryPane(
          key: ValueKey<String>('pane_$category'),
          repo: repo,
          category: category,
          filter: filters.first,
          selection: selections[category]!,
        ),
      );

  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        labels: ZcrudLabels(<String, String>{
          'tab.open': 'Ouverts',
          'tab.closed': 'Fermés',
          'tab.archived': 'Archivés',
        }),
        child: ZTabbedList(
          tabs: <ZListTab>[
            tab('open', 'open'),
            tab('closed', 'closed'),
            tab('archived', 'archived'),
          ],
        ),
      ),
    ),
  );
}

final _data = <_Item>[
  const _Item('o1', 'open'),
  const _Item('o2', 'open'),
  const _Item('x1', 'closed'),
  const _Item('a1', 'archived'),
];

Map<String, ZListSelectionController> _mkSelections() =>
    <String, ZListSelectionController>{
      'open': ZListSelectionController(),
      'closed': ZListSelectionController(),
      'archived': ZListSelectionController(),
    };

void main() {
  setUp(_initCounts.clear);

  testWidgets('AC4 — chaque onglet affiche SON sous-ensemble catégorisé',
      (tester) async {
    final repo = _CategoryRepo(_data);
    final sels = _mkSelections();
    await tester.pumpWidget(_host(repo: repo, selections: sels));
    await tester.pumpAndSettle();

    // Onglet actif = open : o1, o2 ; pas x1/a1.
    expect(find.text('item-o1'), findsOneWidget);
    expect(find.text('item-o2'), findsOneWidget);
    expect(find.text('item-x1'), findsNothing);

    // Passe à « closed ».
    await tester.tap(find.text('Fermés'));
    await tester.pumpAndSettle();
    expect(find.text('item-x1'), findsOneWidget);
    expect(find.text('item-o1'), findsNothing);

    // Passe à « archived ».
    await tester.tap(find.text('Archivés'));
    await tester.pumpAndSettle();
    expect(find.text('item-a1'), findsOneWidget);
    for (final c in sels.values) {
      c.dispose();
    }
  });

  testWidgets('AC5 — recherche & sélection PRÉSERVÉES A→B→A, contrôleur non recréé',
      (tester) async {
    final repo = _CategoryRepo(_data);
    final sels = _mkSelections();
    await tester.pumpWidget(_host(repo: repo, selections: sels));
    await tester.pumpAndSettle();
    expect(_initCounts['open'], 1);

    // Recherche 'o1' dans l'onglet open + sélection de o1.
    await tester.enterText(find.byKey(const ValueKey('search_open')), 'o1');
    await tester.pumpAndSettle();
    expect(find.text('item-o1'), findsOneWidget);
    expect(find.text('item-o2'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('zListRow_o1')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(sels['open']!.selectedIds.value, <String>{'o1'});

    // A→B→A.
    await tester.tap(find.text('Fermés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouverts'));
    await tester.pumpAndSettle();

    // Recherche toujours appliquée, sélection intacte, contrôleur PAS recréé.
    expect(find.text('item-o1'), findsOneWidget);
    expect(find.text('item-o2'), findsNothing);
    expect(sels['open']!.selectedIds.value, <String>{'o1'});
    expect(_initCounts['open'], 1);
    for (final c in sels.values) {
      c.dispose();
    }
  });

  testWidgets('AC6 — sélections INDÉPENDANTES par onglet', (tester) async {
    final repo = _CategoryRepo(_data);
    final sels = _mkSelections();
    await tester.pumpWidget(_host(repo: repo, selections: sels));
    await tester.pumpAndSettle();

    // Sélectionne o1 dans open.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('zListRow_o1')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    // Va dans closed : sélection vide, sélectionne x1.
    await tester.tap(find.text('Fermés'));
    await tester.pumpAndSettle();
    expect(sels['closed']!.selectedIds.value, isEmpty);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('zListRow_x1')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    // Retour open : sélection = {o1} (pas {x1}).
    await tester.tap(find.text('Ouverts'));
    await tester.pumpAndSettle();
    expect(sels['open']!.selectedIds.value, <String>{'o1'});
    expect(sels['closed']!.selectedIds.value, <String>{'x1'});
    for (final c in sels.values) {
      c.dispose();
    }
  });

  testWidgets('AC9 — a11y : libellés l10n résolus, onglet actif selected, ≥ 48 dp',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = _CategoryRepo(_data);
    final sels = _mkSelections();
    await tester.pumpWidget(_host(repo: repo, selections: sels));
    await tester.pumpAndSettle();

    // Libellés résolus via le seam l10n (ZcrudLabels), aucune chaîne codée en dur.
    expect(find.text('Ouverts'), findsOneWidget);
    expect(find.text('Fermés'), findsOneWidget);
    expect(find.text('Archivés'), findsOneWidget);

    // Onglet actif annoncé `selected: true` (le seul onglet sélectionné).
    final selected = _collectSemantics(
      tester,
      find.byType(TabBar),
      (d) => d.flagsCollection.isSelected == Tristate.isTrue &&
          d.label.isNotEmpty,
    );
    expect(
      selected.where((d) => d.label.contains('Ouverts')),
      isNotEmpty,
      reason: 'l\'onglet actif « Ouverts » est annoncé sélectionné',
    );
    expect(
      selected.where((d) => d.label.contains('Fermés')),
      isEmpty,
      reason: 'seul l\'onglet actif est annoncé sélectionné',
    );

    // Cible tactile ≥ 48 dp.
    final tabSize = tester.getSize(find.byType(Tab).first);
    expect(tabSize.height, greaterThanOrEqualTo(48.0));

    handle.dispose();
    for (final c in sels.values) {
      c.dispose();
    }
  });
}
