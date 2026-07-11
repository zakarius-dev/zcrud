// DP-19 (M18/M19) — sous-liste : soft-delete/restore + gabarits + defaultNewItem
// + createNewText ; item dynamique : defaultNewItem + createNewText +
// subItemsFormFieldsBuilder(state).
//
// Additionne SANS régresser DP-6 (mode compact/ACL/dialog) ni l'inline E3-3b-2.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.text, label: 'F2'),
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('DP-19 M18 — soft-delete / restore (compact)', () {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.compact,
        summaryFields: <String>['f1'],
        softDelete: true,
      ),
    );

    testWidgets('delete → item exclu de l\'agrégation mais restaurable',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: field,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          <String, dynamic>{'f1': 'Beta', 'f2': 'b'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Agrégation : 1 item restant (Alpha exclu).
      expect(captured, isNotNull);
      expect(captured!.length, 1);
      expect(captured!.single['f1'], 'Beta');
      // La ligne soft-deleted reste visible avec badge + action restaurer.
      expect(find.text('(deleted)'), findsOneWidget);
      expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);

      // Restaurer → l'item réintègre l'agrégation.
      await tester.tap(find.byIcon(Icons.restore_from_trash));
      await tester.pumpAndSettle();
      expect(captured!.length, 2);
    });

    testWidgets('softDelete=false (défaut) → suppression définitive',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: const ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            displayMode: ZSubListDisplayMode.compact,
            summaryFields: <String>['f1'],
          ),
        ),
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(captured, isEmpty);
      expect(find.byIcon(Icons.restore_from_trash), findsNothing);
    });
  });

  group('DP-19 M18 — gabarits de création (popUpMenuOptions)', () {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.compact,
        summaryFields: <String>['f1'],
        creationTemplates: <ZSubListItemTemplate>[
          ZSubListItemTemplate(labelKey: 'tplA', defaults: <String, Object?>{'f1': 'A'}),
          ZSubListItemTemplate(labelKey: 'tplB', defaults: <String, Object?>{'f1': 'B'}),
        ],
      ),
    );

    testWidgets('add → menu de gabarits ; sélection pré-remplit le dialog',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: field,
        initialValue: null,
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('tplA'), findsOneWidget);
      expect(find.text('tplB'), findsOneWidget);

      await tester.tap(find.text('tplA'));
      await tester.pumpAndSettle();
      // Le dialog s'ouvre avec f1 pré-rempli à « A ».
      expect(find.text('A'), findsWidgets);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(captured!.single['f1'], 'A');
    });
  });

  group('DP-19 M19 — defaultNewItem / createNewText', () {
    testWidgets('inline : defaultNewItem amorce le nouvel item', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: const ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            defaultNewItem: <String, Object?>{'f1': 'D'},
            createNewTextKey: 'create',
          ),
        ),
        initialValue: null,
        onChanged: (_) {},
      )));
      await tester.pump();
      // Libellé de bouton personnalisé (createNewTextKey='create' → « Create »).
      expect(find.text('Create'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      // Le sous-champ f1 est pré-rempli à « D ».
      expect(find.text('D'), findsWidgets);
    });

    testWidgets('dynamicItem : defaultNewItem + createNewText', (tester) async {
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: const ZFieldSpec(
          name: 'item',
          type: EditionFieldType.dynamicItem,
          label: 'Item',
          config: ZSubListConfig(
            itemFields: _itemFields,
            defaultNewItem: <String, Object?>{'f1': 'X'},
            createNewTextKey: 'create',
          ),
        ),
        initialValue: null,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.text('Create'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('X'), findsWidgets);
    });
  });

  group('DP-19 M19 — subItemsFormFieldsBuilder(state)', () {
    testWidgets('resolver → sous-ensemble de champs rendu', (tester) async {
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: const ZFieldSpec(
          name: 'item',
          type: EditionFieldType.dynamicItem,
          label: 'Item',
          config: ZSubListConfig(itemFields: _itemFields),
        ),
        initialValue: const <String, dynamic>{'f1': '', 'f2': ''},
        // f1 vide → ne rend QUE f2.
        fieldsResolver: (state) => <ZFieldSpec>[
          for (final f in _itemFields)
            if (f.name == 'f2') f,
        ],
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('F2'), findsWidgets);
      expect(find.text('F1'), findsNothing);
    });

    testWidgets('resolver défaillant → repli config (défensif)', (tester) async {
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: const ZFieldSpec(
          name: 'item',
          type: EditionFieldType.dynamicItem,
          label: 'Item',
          config: ZSubListConfig(itemFields: _itemFields),
        ),
        initialValue: const <String, dynamic>{'f1': '', 'f2': ''},
        fieldsResolver: (state) => throw StateError('boom'),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });
}
