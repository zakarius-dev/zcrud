import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/list_demo_data.dart';
import 'package:zcrud_example/demos/offline_demo_screen.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

import 'support/pump_helpers.dart';

void main() {
  // ── AC7 (a) — CRUD offline RÉEL via HiveZLocalStore (port ZLocalStore) ──────
  // Hive réel + temp-dir hermétique prouve la persistance offline-first (AD-9).
  group('Hive réel (CRUD complet)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zcrud_offline_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk(HiveZLocalStore.boxNameFor('demoRecord'));
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
        'AC7 — CRUD offline via ZLocalStore (create/softDelete/restore/clear)',
        () async {
      final ZLocalStore<DemoRecord> store =
          await HiveZLocalStore.openBox<DemoRecord>(
        kind: 'demoRecord',
        fromMap: DemoRecord.fromMap,
        toMap: (r) => r.toMap(),
      );

      final record = DemoRecord(
        recordId: 'r1',
        name: 'Article offline',
        category: 'materiel',
        quantity: 3,
        unitPrice: 12.5,
        createdAt: DateTime(2026, 3, 1),
        active: true,
      );

      List<DemoRecord> read(ZResult<List<DemoRecord>> r) =>
          r.fold((_) => const <DemoRecord>[], (v) => v);

      await store.put(record);
      var all = read(await store.getAll());
      expect(all.map((r) => r.recordId), contains('r1'));
      expect(all.single.name, 'Article offline');

      await store.softDelete('r1');
      all = read(await store.getAll());
      expect(all, isEmpty);

      await store.restore('r1');
      all = read(await store.getAll());
      expect(all.map((r) => r.recordId), contains('r1'));

      await store.clear();
      all = read(await store.getAll());
      expect(all, isEmpty);
    });
  });

  // ── AC7 (b) — l'écran reflète l'état du store local ─────────────────────────
  // Le widget test tourne sous FakeAsync (l'IO fichier Hive ne se résout pas) :
  // on injecte un `ZLocalStore` in-memory hermétique (ambiguïté #4 option (b)) ;
  // l'écran est construit CONTRE LE PORT, donc ce fake exerce exactement le même
  // contrat neutre que `HiveZLocalStore`.
  testWidgets('AC7 — écran Offline : create/list/delete reflètent le store',
      (tester) async {
    final store = _InMemoryLocalStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      wrapForTest(OfflineDemoScreen(storeFactory: () async => store)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OfflineDemoScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('offlineEmpty')), findsOneWidget);

    // Créer → la liste affiche un enregistrement.
    await tester.tap(find.byKey(const ValueKey<String>('offlineCreate')));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('Enregistrement #1'), findsOneWidget);

    // Supprimer (soft-delete) → la liste redevient vide.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('offlineEmpty')), findsOneWidget);
  });

  // ── AC7 (c) — RESTAURATION exerçable À LA MAIN via l'UI (Finding MEDIUM-1) ───
  // Supprimer expose un SnackBar « Annuler » rappelant `store.restore(id)` :
  // taper supprimer → taper Annuler → l'enregistrement RÉAPPARAÎT (le CRUD
  // offline complet create/softDelete/restore est prouvé PAR L'UI, plus seulement
  // au niveau port). AD-9 : le soft-delete est un drapeau, restaurable.
  testWidgets('AC7 — écran Offline : soft-delete puis restaurer via « Annuler »',
      (tester) async {
    final store = _InMemoryLocalStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      wrapForTest(OfflineDemoScreen(storeFactory: () async => store)),
    );
    await tester.pumpAndSettle();

    // Créer un enregistrement.
    await tester.tap(find.byKey(const ValueKey<String>('offlineCreate')));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('Enregistrement #1'), findsOneWidget);

    // Soft-delete → la liste se vide ET un SnackBar « Annuler » apparaît.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump(); // déclenche soft-delete + montage du SnackBar.
    // Laisse l'animation d'entrée du SnackBar se terminer (il glisse depuis le
    // bas) SANS `pumpAndSettle` (le timer d'auto-dismiss 4 s ne « settle » jamais)
    // pour que l'action « Annuler » soit dans les bornes de l'écran (hit-test).
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byKey(const ValueKey<String>('offlineEmpty')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('offlineUndo')), findsOneWidget);

    // Restaurer via l'UI → l'enregistrement RÉAPPARAÎT (voie restore() du port).
    await tester.tap(find.byKey(const ValueKey<String>('offlineUndo')));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('Enregistrement #1'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('offlineEmpty')), findsNothing);
  });
}

/// Fake in-memory du port `ZLocalStore<DemoRecord>` (hermétique, sans IO) —
/// soft-delete `is_deleted` hors-entité (AD-9), flux nu diffusé. N'expose aucun
/// type Hive/Firestore : prouve que l'écran ne dépend QUE du contrat neutre.
class _InMemoryLocalStore implements ZLocalStore<DemoRecord> {
  final Map<String, DemoRecord> _records = <String, DemoRecord>{};
  final Set<String> _deleted = <String>{};
  final StreamController<List<DemoRecord>> _changes =
      StreamController<List<DemoRecord>>.broadcast();

  List<DemoRecord> get _visible => <DemoRecord>[
        for (final e in _records.entries)
          if (!_deleted.contains(e.key)) e.value,
      ];

  void _emit() {
    if (!_changes.isClosed) _changes.add(_visible);
  }

  @override
  Stream<List<DemoRecord>> watchAll() async* {
    yield _visible; // seed immédiat
    yield* _changes.stream;
  }

  @override
  Future<ZResult<List<DemoRecord>>> getAll() async =>
      Right<ZFailure, List<DemoRecord>>(_visible);

  @override
  Future<ZResult<DemoRecord>> getById(String id) async {
    final r = _records[id];
    return r == null || _deleted.contains(id)
        ? Left<ZFailure, DemoRecord>(NotFoundFailure('DemoRecord', id: id))
        : Right<ZFailure, DemoRecord>(r);
  }

  @override
  Future<ZResult<DemoRecord>> put(DemoRecord item) async {
    final id = item.recordId;
    _records[id] = item;
    _deleted.remove(id);
    _emit();
    return Right<ZFailure, DemoRecord>(item);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    _deleted.add(id);
    _emit();
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    _deleted.remove(id);
    _emit();
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> clear() async {
    _records.clear();
    _deleted.clear();
    _emit();
    return const Right<ZFailure, Unit>(unit);
  }

  // ── Voies de sync (E5-3, ZLocalStore) — non exercées par ces tests d'écran,
  // implémentations minimales COHÉRENTES avec le contrat pour satisfaire
  // l'interface (fake hermétique, sans backend). ────────────────────────────

  @override
  Future<ZResult<List<ZSyncEntry<DemoRecord>>>> syncEntries() async =>
      Right<ZFailure, List<ZSyncEntry<DemoRecord>>>(<ZSyncEntry<DemoRecord>>[
        for (final e in _records.entries)
          ZSyncEntry<DemoRecord>(
            entity: e.value,
            meta: ZSyncMeta(isDeleted: _deleted.contains(e.key)),
          ),
      ]);

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<DemoRecord> entry) async {
    final id = entry.entity.recordId;
    _records[id] = entry.entity;
    if (entry.meta.isDeleted) {
      _deleted.add(id);
    } else {
      _deleted.remove(id);
    }
    _emit();
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() => unawaited(_changes.close());
}
