import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

class _Item extends ZEntity {
  const _Item(this.id);
  @override
  final String? id;
}

class _History extends ZEntityHistorySource<_Item> {
  _History(this.entries);
  final List<ZHistoryEntry> entries;
  @override
  Stream<List<ZHistoryEntry>> watchHistory(_Item entity) =>
      Stream<List<ZHistoryEntry>>.value(entries);
}

class _ThrowingHistory extends ZEntityHistorySource<_Item> {
  @override
  Stream<List<ZHistoryEntry>> watchHistory(_Item entity) =>
      throw StateError('source en panne');
}

class _ErrorHistory extends ZEntityHistorySource<_Item> {
  @override
  Stream<List<ZHistoryEntry>> watchHistory(_Item entity) =>
      Stream<List<ZHistoryEntry>>.error(StateError('flux en panne'));
}

class _ItemHistory extends ZEntityHistorySource<Item> {
  @override
  Stream<List<ZHistoryEntry>> watchHistory(Item entity) =>
      const Stream<List<ZHistoryEntry>>.empty();
}

class _Dates extends ZDateDisplayFormatter {
  const _Dates();
  @override
  String? format(
    DateTime value, {
    required ZDateMode mode,
    String? localeTag,
  }) => '17 août 2026';
}

void main() {
  testWidgets('journal : date localisée, opération, auteur et diff complet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ZcrudScope(
        dateDisplayFormatter: const _Dates(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showZEntityHistory<_Item>(
                  context,
                  entity: const _Item('1'),
                  source: _History(<ZHistoryEntry>[
                    ZHistoryEntry(
                      at: DateTime(2026, 8, 17),
                      action: ZCrudAction.update,
                      authorLabel: 'Awa',
                      previousValue: <String, Object?>{
                        'change': 'avant',
                        'removed': 1,
                      },
                    ),
                    ZHistoryEntry(
                      at: DateTime(2026, 8, 16),
                      operationLabel: 'Visa',
                      authorLabel: 'Benoit',
                      previousValue: <String, Object?>{'added': 2},
                    ),
                  ]),
                  currentValue: const <String, Object?>{
                    'change': 'après',
                    'added': 2,
                  },
                ),
                child: const Text('ouvrir'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('17 août 2026'), findsNWidgets(2));
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Visa'), findsOneWidget);
    expect(find.text('change: avant → après'), findsOneWidget);
    expect(find.text('removed: 1'), findsWidgets);
    expect(find.text('added: 2'), findsWidgets);
  });

  testWidgets('source en erreur ou entrée invalide : journal vide', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showZEntityHistory<_Item>(
              context,
              entity: const _Item('1'),
              source: _History(<ZHistoryEntry>[
                ZHistoryEntry(operationLabel: 'sans date'),
              ]),
              currentValue: const <String, Object?>{},
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsNothing);
  });

  testWidgets(
    'source levée ou flux en erreur : aucune exception ne casse la feuille',
    (tester) async {
      Future<void> open(ZEntityHistorySource<_Item> source) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showZEntityHistory<_Item>(
                  context,
                  entity: const _Item('1'),
                  source: source,
                  currentValue: const <String, Object?>{},
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Table), findsNothing);
        expect(find.bySemanticsLabel('History'), findsWidgets);
        Navigator.of(tester.element(find.byType(SafeArea).last)).pop();
        await tester.pumpAndSettle();
      }

      await open(_ThrowingHistory());
      await open(_ErrorHistory());
    },
  );

  testWidgets('une entrée sans date est ignorée, jamais datée maintenant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showZEntityHistory<_Item>(
              context,
              entity: const _Item('1'),
              source: _History(<ZHistoryEntry>[
                ZHistoryEntry(action: ZCrudAction.update, authorLabel: 'Awa'),
              ]),
              currentValue: const <String, Object?>{},
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsNothing);
    expect(find.text('Update'), findsNothing);
  });

  testWidgets('ACL : l’action de journal est absente si history est refusée', (
    tester,
  ) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      _historyScreen(
        repo,
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.history}),
        history: _ItemHistory(),
      ),
    );

    expect(
      find.text('Alpha'),
      findsOneWidget,
      reason: 'ligne effectivement montée',
    );
    expect(find.byIcon(Icons.history_outlined), findsNothing);
  });

  testWidgets(
    'ACL : l’action de journal est présente si history est accordée',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _historyScreen(
          repo,
          acl: const ZAllowAllAcl(),
          history: _ItemHistory(),
        ),
      );

      expect(
        find.text('Alpha'),
        findsOneWidget,
        reason: 'ligne effectivement montée',
      );
      expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'sans source déclarée : aucun bouton d’action de ligne n’est créé',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _historyScreen(repo, acl: const ZAllowAllAcl()));

      expect(
        find.text('Alpha'),
        findsOneWidget,
        reason: 'ligne effectivement montée',
      );
      expect(find.byType(IconButton), findsNWidgets(0));
    },
  );

  testWidgets(
    'diff : modification, ajout et suppression affichent leur texte',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showZEntityHistory<_Item>(
                context,
                entity: const _Item('1'),
                source: _History(<ZHistoryEntry>[
                  ZHistoryEntry(
                    at: DateTime(2026, 8, 17),
                    action: ZCrudAction.update,
                    previousValue: const <String, Object?>{
                      'modified': 'avant',
                      'removed': 'retiré',
                    },
                  ),
                ]),
                currentValue: const <String, Object?>{
                  'modified': 'après',
                  'added': 'ajouté',
                },
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.byType(Table),
        findsOneWidget,
        reason: 'entrée effectivement montée',
      );
      expect(find.text('modified: avant → après'), findsOneWidget);
      expect(find.text('added: ajouté'), findsOneWidget);
      expect(find.text('removed: retiré'), findsOneWidget);
    },
  );

  testWidgets('action de journal : cible déclarée de 48 dp', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    addTearDown(repo.dispose);
    await pumpScreen(
      tester,
      _historyScreen(repo, acl: const ZAllowAllAcl(), history: _ItemHistory()),
    );

    final target = find.ancestor(
      of: find.byIcon(Icons.history_outlined),
      matching: find.byType(SizedBox),
    );
    final declaredTargets = target
        .evaluate()
        .map((element) => element.widget as SizedBox)
        .where((box) => box.width == 48 && box.height == 48);
    expect(declaredTargets, hasLength(1));
  });
}

Widget _historyScreen(
  FakeItemRepo repo, {
  required ZAcl acl,
  ZEntityHistorySource<Item>? history,
}) => ZCrudScreen<Item>(
  title: 'Items',
  source: ZCrudSource<Item>.repository(repo),
  registry: buildItemRegistry(),
  acl: acl,
  mode: ZScreenMode.locked,
  canCreate: false,
  trash: ZTrashMode.none,
  searchEnabled: false,
  history: history,
  layout: ZListBuilderLayout(
    itemBuilder: (context, row, columns) => Text(row.cells['name']! as String),
  ),
);
