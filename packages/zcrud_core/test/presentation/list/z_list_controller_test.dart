// AC5..AC8 (E4-3, AD-2/AD-11/AD-15/AD-16) : `ZListController` — cycle de requête
// + `ValueListenable<ZListViewState>` (Flutter-native), pagination curseur backend
// + loadMore accumule, REPLI in-memory (mode inMemory + Left curseur) SANS crash,
// mapping empty/noResults. Fakes `ZRepository` AVEC et SANS curseur. AUCUN import
// `zcrud_list`/Syncfusion (SM-5 exécutable).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'age', type: EditionFieldType.number),
];

class _Item implements ZEntity {
  const _Item(this._id, this.name, this.age);
  final String _id;
  final String name;
  final int age;
  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

ZListRow _toRow(_Item it) => ZListRow(
      id: it.id!,
      cells: <String, Object?>{'name': it.name, 'age': it.age},
    );

List<_Item> _items(int n) =>
    <_Item>[for (var i = 0; i < n; i++) _Item('p$i', 'P$i', 20 + i)];

/// Fake `ZRepository` paramétrable :
/// - [honorRequest] : honore filtres/tri/recherche/limit/curseur via
///   `zApplyListRequest` (backend « intelligent »). Si `false`, retourne le jeu
///   BRUT non paginé (backend « sans curseur » → repli in-memory attendu).
/// - [failOnCursor] : renvoie `Left(ServerFailure)` dès qu'un `startAfter` est
///   présent (curseur non honoré → repli attendu, AD-16).
/// - [failAlways] : renvoie toujours `Left` (vraie erreur → `ZListError`).
class _FakeRepo implements ZRepository<_Item> {
  _FakeRepo(
    this._data, {
    this.honorRequest = true,
    this.failOnCursor = false,
    this.failAlways = false,
  });

  final List<_Item> _data;
  final bool honorRequest;
  final bool failOnCursor;
  final bool failAlways;
  final StreamController<List<_Item>> _changes =
      StreamController<List<_Item>>.broadcast();

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    if (failAlways) return const Left(ServerFailure('backend en panne'));
    if (failOnCursor && request?.startAfter != null) {
      return const Left(ServerFailure('curseur non supporté'));
    }
    if (!honorRequest) return Right(List<_Item>.of(_data));
    final req = request ?? const ZDataRequest();
    final rows = <ZListRow>[for (final it in _data) _toRow(it)];
    final page = zApplyListRequest(rows, req, schema: _schema);
    final byId = <String, _Item>{for (final it in _data) it.id!: it};
    return Right(<_Item>[for (final r in page.rows) byId[r.id]!]);
  }

  @override
  Stream<List<_Item>> watchAll() => _changes.stream;

  @override
  Stream<List<_Item>> watch(ZDataRequest request) => _changes.stream;

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
  void dispose() => _changes.close();
}

/// Récupère les lignes de l'état courant (ou `null` si non `ZListReady`).
List<ZListRow>? _readyRows(ZListViewState s) =>
    s is ZListReady ? s.rows : null;

/// Fake `ZRepository` à **complétion CONTRÔLÉE** (M-1) : chaque `getAll` enregistre
/// un `Completer` que le test résout MANUELLEMENT, permettant d'**entrelacer** des
/// réponses backend async (hors-ordre) et de prouver la garde anti-réponse-obsolète
/// (`_generation`). `requests[i]` conserve la `ZDataRequest` du i-ᵉ appel.
class _ControlledRepo implements ZRepository<_Item> {
  final List<Completer<ZResult<List<_Item>>>> _pending =
      <Completer<ZResult<List<_Item>>>>[];
  final List<ZDataRequest?> requests = <ZDataRequest?>[];
  final StreamController<List<_Item>> _changes =
      StreamController<List<_Item>>.broadcast();

  int get callCount => _pending.length;

  /// Résout le i-ᵉ appel `getAll` en cours avec [items] (succès).
  void completeWith(int i, List<_Item> items) =>
      _pending[i].complete(Right<ZFailure, List<_Item>>(List<_Item>.of(items)));

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) {
    requests.add(request);
    final completer = Completer<ZResult<List<_Item>>>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Stream<List<_Item>> watchAll() => _changes.stream;

  @override
  Stream<List<_Item>> watch(ZDataRequest request) => _changes.stream;

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
  Future<ZResult<int>> count({ZDataRequest? request}) async => const Right(0);

  @override
  void dispose() => _changes.close();
}

void main() {
  testWidgets('backendCursor : page1 + loadMore accumulent (AC5/AC7)',
      (tester) async {
    final repo = _FakeRepo(_items(5));
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 2,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    expect(_readyRows(controller.state.value)!.map((r) => r.cells['age']),
        [20, 21]);
    expect((controller.state.value as ZListReady).rows, hasLength(2));

    await controller.loadMore();
    await tester.pumpAndSettle();
    expect(_readyRows(controller.state.value), hasLength(4));

    await controller.loadMore();
    await tester.pumpAndSettle();
    final rows = _readyRows(controller.state.value)!;
    expect(rows.map((r) => r.id), ['p0', 'p1', 'p2', 'p3', 'p4']);

    // Plus de page : loadMore est un no-op.
    await controller.loadMore();
    await tester.pumpAndSettle();
    expect(_readyRows(controller.state.value), hasLength(5));
  });

  testWidgets('mode inMemory (backend sans curseur) : pagination correcte en '
      'mémoire (AC6)', (tester) async {
    // honorRequest:false → le fake IGNORE limit/startAfter (renvoie tout brut).
    final repo = _FakeRepo(_items(5), honorRequest: false);
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 2,
      mode: ZListPaginationMode.inMemory,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    // Le repli in-memory a paginé malgré un backend qui ignore la pagination.
    expect(_readyRows(controller.state.value)!.map((r) => r.cells['age']),
        [20, 21]);

    await controller.loadMore();
    await tester.pumpAndSettle();
    expect(_readyRows(controller.state.value)!.map((r) => r.cells['age']),
        [20, 21, 22, 23]);
  });

  testWidgets('Left curseur en backendCursor → repli in-memory, PAS ZListError '
      '(AC6/AD-16)', (tester) async {
    // Première page OK (startAfter null) ; loadMore → Left curseur → repli.
    final repo = _FakeRepo(_items(5), failOnCursor: true);
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 2,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListReady>());

    await controller.loadMore();
    await tester.pumpAndSettle();
    // Repli in-memory : ZListReady (jamais ZListError), sans exception.
    expect(controller.state.value, isA<ZListReady>());
    expect(_readyRows(controller.state.value), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Left NON lié au curseur (1re page) → ZListError (AC6/AC8)',
      (tester) async {
    final repo = _FakeRepo(_items(3), failAlways: true);
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 2,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListError>());
  });

  testWidgets('setSearch("zzz") sur jeu non vide → ZListNoResults (AC8)',
      (tester) async {
    final repo = _FakeRepo(_items(5));
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 10,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListReady>());

    controller.setSearch('zzz');
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListNoResults>());
  });

  testWidgets('jeu vide sans filtre → ZListEmpty ; vide + filtre → ZListNoResults '
      '(AC8)', (tester) async {
    final repo = _FakeRepo(<_Item>[]);
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
    );
    addTearDown(controller.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListEmpty>());

    controller.setFilters(const [ZFilter('age', ZFilterOp.gt, 100)]);
    await tester.pumpAndSettle();
    expect(controller.state.value, isA<ZListNoResults>());
  });

  testWidgets('ValueListenableBuilder + DynamicList reflète les transitions ; '
      'dispose coupe les émissions (AC7)', (tester) async {
    final repo = _FakeRepo(_items(2));
    final controller = ZListController<_Item>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 10,
    );
    addTearDown(repo.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    // La vue « builder » (SM-5 : aucun renderer) rend une entrée par ligne.
    expect(find.text('P0'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);

    controller.dispose();
    // Après dispose : aucune émission, aucune exception.
    controller.setSearch('zzz');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('CONCURRENCE — garde anti-réponse-obsolète (_generation, M-1)', () {
    testWidgets(
        '2 setSearch rapides → seule la réponse de la 2ᵉ requête commit '
        '(la 1re, en retard, est IGNORÉE)', (tester) async {
      final repo = _ControlledRepo();
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
      );
      addTearDown(controller.dispose);
      addTearDown(repo.dispose);
      await tester.pumpWidget(const SizedBox());

      // call[0] = requête initiale (constructeur). On la résout (état stable).
      expect(repo.callCount, 1);
      repo.completeWith(0, _items(1));
      await tester.pump();

      // Deux frappes rapprochées : « a » (lente) puis « b » (rapide).
      controller.setSearch('a'); // call[1], gen supérieur
      controller.setSearch('b'); // call[2], gen encore supérieur
      expect(repo.callCount, 3);

      final aItem = const _Item('A', 'Alpha', 1);
      final bItem = const _Item('B', 'Bravo', 2);

      // La 2ᵉ requête (« b ») revient EN PREMIER et commit.
      repo.completeWith(2, <_Item>[bItem]);
      await tester.pump();
      expect(_readyRows(controller.state.value)!.map((r) => r.id), ['B']);

      // La 1re requête (« a ») revient EN RETARD → doit être IGNORÉE.
      repo.completeWith(1, <_Item>[aItem]);
      await tester.pump();
      expect(_readyRows(controller.state.value)!.map((r) => r.id), ['B'],
          reason: 'réponse obsolète « a » ne doit pas écraser l\'état « b »');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'setFilters PENDANT un loadMore en vol → page loadMore obsolète REJETÉE '
        '(pas de doublon/trou), état final = nouveau filtre', (tester) async {
      final repo = _ControlledRepo();
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        pageSize: 2,
      );
      addTearDown(controller.dispose);
      addTearDown(repo.dispose);
      await tester.pumpWidget(const SizedBox());

      // Page 1 : 2 lignes (== pageSize) → hasMore true, curseur dérivé.
      const p0 = _Item('p0', 'P0', 20);
      const p1 = _Item('p1', 'P1', 21);
      repo.completeWith(0, <_Item>[p0, p1]);
      await tester.pump();
      expect(_readyRows(controller.state.value)!.map((r) => r.id), ['p0', 'p1']);

      // loadMore en vol (call[1], append) — NON résolu pour l'instant.
      unawaited(controller.loadMore());
      expect(repo.callCount, 2);

      // setFilters pendant le loadMore : reset pagination + nouvelle requête
      // (call[2]). L'accumulé est vidé.
      controller.setFilters(const [ZFilter('age', ZFilterOp.gt, 100)]);
      expect(repo.callCount, 3);

      // Le loadMore EN RETARD revient : gen obsolète → page rejetée (aucun
      // addAll → ni doublon ni trou).
      const p2 = _Item('p2', 'P2', 22);
      const p3 = _Item('p3', 'P3', 23);
      repo.completeWith(1, <_Item>[p2, p3]);
      await tester.pump();

      // La requête du nouveau filtre commit (une seule ligne « filtrée »).
      const f = _Item('f', 'Filtered', 200);
      repo.completeWith(2, <_Item>[f]);
      await tester.pump();

      final rows = _readyRows(controller.state.value)!;
      expect(rows.map((r) => r.id), ['f'],
          reason: 'ni p0..p3 (accumulé obsolète), pas de doublon ni trou');
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose PENDANT une requête en vol → aucun commit après dispose',
        (tester) async {
      final repo = _ControlledRepo();
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
      );
      addTearDown(repo.dispose);
      await tester.pumpWidget(const SizedBox());

      // Requête initiale en vol (call[0]) NON résolue.
      expect(repo.callCount, 1);

      controller.dispose();

      // La réponse arrive APRÈS dispose : ne doit rien committer, ni jeter
      // (émission sur un ValueNotifier disposé lèverait — garde `_disposed`).
      repo.completeWith(0, _items(3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Hôte de test : `ValueListenableBuilder<ZListViewState>` → `DynamicList` en
/// layout `builder` (aucun renderer Syncfusion — SM-5).
Widget _host(ZListController<_Item> controller) => MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<ZListViewState>(
          valueListenable: controller.state,
          builder: (context, state, _) => DynamicList(
            fields: _schema,
            state: state,
            layout: ZListBuilderLayout(
              itemBuilder: (context, row, columns) =>
                  Text(row.cells['name'].toString()),
            ),
          ),
        ),
      ),
    );
