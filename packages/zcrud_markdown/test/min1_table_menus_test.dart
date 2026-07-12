// MIN-1 — Éditeur de tableau enrichi : menus LIGNE / COLONNE (insérer / supprimer)
// au-delà des seuls steppers de fin. Prouve : insertion/suppression ciblée d'une
// ligne et d'une colonne via les menus, préservation du texte des cellules
// conservées, bornes min respectées (pas de suppression sous le minimum),
// round-trip de la structure JSON-safe.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _pressTableButton(WidgetTester tester) {
  final btn = tester
      .widgetList<QuillToolbarCustomButton>(find.byType(QuillToolbarCustomButton))
      .firstWhere((b) => b.options.tooltip == 'Insérer un tableau');
  btn.options.onPressed!.call();
}

Future<void> _selectMenu(WidgetTester tester, Key menuKey, Key itemKey) async {
  await tester.tap(find.byKey(menuKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(itemKey).last);
  await tester.pumpAndSettle();
}

const _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

// Seed d'un tableau 2×2 rempli, pour ouvrir le dialogue en édition.
List<Map<String, dynamic>> _tableSeed() => <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{
          'table': <String, dynamic>{
            'rows': 2,
            'columns': 2,
            'cells': <List<String>>[
              <String>['a', 'b'],
              <String>['c', 'd'],
            ],
          },
        },
      },
      <String, dynamic>{'insert': '\n'},
    ];

Future<void> _openTableEditor(WidgetTester tester, ZFormController c) async {
  await tester.pumpWidget(_host(ZMarkdownField(
    key: const ValueKey('notes'),
    controller: c,
    field: _field,
  )));
  await tester.pump(const Duration(milliseconds: 50));
  final quill =
      tester.widget<QuillEditor>(find.byType(QuillEditor).first).controller;
  quill.updateSelection(
    const TextSelection.collapsed(offset: 1),
    ChangeSource.local,
  );
  await tester.pump();
  _pressTableButton(tester);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _submittedStructure(ZFormController c) {
  final value = c.valueOf('notes')! as List<Map<String, dynamic>>;
  final op = value.firstWhere(
      (op) => op['insert'] is Map && (op['insert'] as Map)['table'] is Map);
  return Map<String, dynamic>.from((op['insert'] as Map)['table'] as Map);
}

void main() {
  testWidgets('menus ligne + colonne présents dans le dialogue', (tester) async {
    final c = ZFormController(
        initialValues: <String, Object?>{'notes': _tableSeed()});
    addTearDown(c.dispose);
    await _openTableEditor(tester, c);

    expect(find.byKey(const ValueKey('ztable-row-menu-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ztable-row-menu-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('ztable-col-menu-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ztable-col-menu-1')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _settle(tester);
  });

  testWidgets('insérer une ligne en-dessous → 3 lignes, texte préservé',
      (tester) async {
    final c = ZFormController(
        initialValues: <String, Object?>{'notes': _tableSeed()});
    addTearDown(c.dispose);
    await _openTableEditor(tester, c);

    await _selectMenu(tester, const ValueKey('ztable-row-menu-0'),
        const ValueKey('ztable-row-insert-below'));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final struct = _submittedStructure(c);
    expect(struct['rows'], 3);
    final cells = (struct['cells'] as List).cast<List<dynamic>>();
    expect(cells.length, 3);
    // Ligne 0 conservée, nouvelle ligne vide insérée en position 1.
    expect(cells[0].cast<String>(), <String>['a', 'b']);
    expect(cells[1].cast<String>(), <String>['', '']);
    expect(cells[2].cast<String>(), <String>['c', 'd']);
    await _settle(tester);
  });

  testWidgets('supprimer une colonne → 1 colonne, bonne colonne retirée',
      (tester) async {
    final c = ZFormController(
        initialValues: <String, Object?>{'notes': _tableSeed()});
    addTearDown(c.dispose);
    await _openTableEditor(tester, c);

    await _selectMenu(tester, const ValueKey('ztable-col-menu-0'),
        const ValueKey('ztable-col-delete'));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final struct = _submittedStructure(c);
    expect(struct['columns'], 1);
    final cells = (struct['cells'] as List).cast<List<dynamic>>();
    // Colonne 0 (a/c) supprimée → il reste b/d.
    expect(cells[0].cast<String>(), <String>['b']);
    expect(cells[1].cast<String>(), <String>['d']);
    await _settle(tester);
  });

  testWidgets('suppression de ligne bloquée au minimum (1×1)', (tester) async {
    final c = ZFormController();
    addTearDown(c.dispose);
    // Ouvre un dialogue VIERGE (2×2 par défaut).
    await tester.pumpWidget(_host(ZMarkdownField(
      key: const ValueKey('notes'),
      controller: c,
      field: _field,
    )));
    await tester.pump(const Duration(milliseconds: 50));
    _pressTableButton(tester);
    await tester.pumpAndSettle();

    // Réduit à 1×1 via les steppers de fin existants.
    await tester.tap(find.byKey(const ValueKey('ztable-rows-dec')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ztable-columns-dec')));
    await tester.pumpAndSettle();

    // L'item « supprimer la ligne » doit être désactivé au minimum.
    await tester.tap(find.byKey(const ValueKey('ztable-row-menu-0')));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('ztable-row-delete')).last);
    expect(item.enabled, isFalse);

    // Referme le menu puis le dialogue.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _settle(tester);
  });
}
