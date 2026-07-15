// COMBLEMENT ES-6.2 (SM-S4) — couture NEUTRE `zTableEmbedOp`/`kTableEmbedType` :
//  - AC1 : fabrique d'op embed tableau NEUTRE, JSON-safe, non modifiable, type
//          = kTableEmbedType, barrel exempt de tout symbole Quill ;
//  - AC9 : PARITÉ builder — l'op produite par `zTableEmbedOp` est rendue par
//          `ZTableEmbedBuilder` (E6-4) exactement comme le contrat natif.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
// Import CIBLÉ de l'impl interne (même package) pour PROUVER la parité de rendu :
// le barrel n'exporte PAS `ZTableEmbedBuilder` (isolation AD-1).
import 'package:zcrud_markdown/src/presentation/z_table_embed.dart';
// Surface PUBLIQUE testée : la couture neutre passe par le barrel.
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

/// Rend en LECTURE (readOnly) un document composé des [ops] via l'`EmbedBuilder`
/// RÉEL d'E6-4 — voie exacte de rendu du tableau natif.
Future<void> _pumpOps(
  WidgetTester tester,
  List<Map<String, dynamic>> ops,
) async {
  // Round-trip JSON : preuve que les ops sont JSON-safe ET maps mutables pour
  // `Document.fromJson`.
  final decoded = (jsonDecode(jsonEncode(ops)) as List).cast<Object?>();
  final controller = QuillController(
    document: Document.fromJson(decoded),
    selection: const TextSelection.collapsed(offset: 0),
  )..readOnly = true;
  addTearDown(controller.dispose);
  await tester.pumpWidget(_host(
    QuillEditor.basic(
      controller: controller,
      config: const QuillEditorConfig(
        embedBuilders: <EmbedBuilder>[ZTableEmbedBuilder()],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AC1 — fabrique d\'op embed tableau NEUTRE (JSON-safe, type unique)', () {
    test('structure EXACTE {insert:{table:{rows,columns,cells}}}', () {
      final op = zTableEmbedOp(cells: const <List<String>>[
        <String>['a', 'b'],
        <String>['1', '2'],
      ]);
      expect(
        op,
        equals(<String, dynamic>{
          'insert': <String, dynamic>{
            kTableEmbedType: <String, dynamic>{
              'rows': 2,
              'columns': 2,
              'cells': <List<String>>[
                <String>['a', 'b'],
                <String>['1', '2'],
              ],
            },
          },
        }),
      );
    });

    test('kTableEmbedType == "table" (contrat E6-4 conservé)', () {
      expect(kTableEmbedType, 'table');
    });

    test('JSON-safe : jsonDecode(jsonEncode(op)) égal en profondeur', () {
      final op = zTableEmbedOp(cells: const <List<String>>[
        <String>['x'],
      ]);
      final roundTrip = jsonDecode(jsonEncode(op));
      expect(roundTrip, equals(op));
    });

    test('valeur NON MODIFIABLE (gel profond)', () {
      final op = zTableEmbedOp(cells: const <List<String>>[
        <String>['a', 'b'],
      ]);
      expect(() => op['insert'] = 'x', throwsUnsupportedError);
      final table = (op['insert'] as Map)[kTableEmbedType] as Map;
      final cells = table['cells'] as List;
      expect(() => (cells.first as List).add('z'), throwsUnsupportedError);
    });

    test('lignes jagged → PADDÉES (op toujours rectangulaire, jamais jagged)', () {
      final op = zTableEmbedOp(cells: const <List<String>>[
        <String>['a', 'b', 'c'],
        <String>['1'],
      ]);
      final table = (op['insert'] as Map)[kTableEmbedType] as Map;
      expect(table['columns'], 3);
      expect(table['rows'], 2);
      expect(
        table['cells'],
        equals(<List<String>>[
          <String>['a', 'b', 'c'],
          <String>['1', '', ''],
        ]),
      );
    });

    test('⛔ le barrel n\'exporte AUCUN symbole Quill interne (isolation AD-1)',
        () {
      // Le barrel n'expose QUE la couture neutre : `zTableEmbedOp` /
      // `kTableEmbedType`. Aucun `ZTableEmbed`/`ZTableEmbedBuilder`. (Épinglé
      // aussi par `quill_signature_isolation_test.dart` sur le TEXTE du barrel.)
      // Ici on prouve la présence des symboles neutres à la COMPILATION.
      expect(zTableEmbedOp, isA<Function>());
      expect(kTableEmbedType, isA<String>());
    });
  });

  group('AC9 — PARITÉ builder : l\'op de zTableEmbedOp est rendue par E6-4', () {
    testWidgets('cellules affichées, aucun placeholder d\'erreur', (tester) async {
      await _pumpOps(tester, <Map<String, dynamic>>[
        zTableEmbedOp(cells: const <List<String>>[
          <String>['a', 'b'],
          <String>['c', 'd'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(find.byType(Table), findsOneWidget,
          reason: 'l\'op produite DOIT être rendable par ZTableEmbedBuilder.');
      for (final t in const <String>['a', 'b', 'c', 'd']) {
        expect(find.text(t), findsOneWidget, reason: 'cellule "$t" manquante');
      }
      expect(find.byIcon(Icons.error_outline), findsNothing,
          reason: 'op rectangulaire valide ⇒ jamais le placeholder d\'erreur.');
    });

    testWidgets('op issue de lignes jagged : paddée ⇒ rendue (pas placeholder)',
        (tester) async {
      await _pumpOps(tester, <Map<String, dynamic>>[
        zTableEmbedOp(cells: const <List<String>>[
          <String>['a', 'b'],
          <String>['1'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      // Paddée à 2 colonnes ⇒ `_parseTable` l'accepte (rectangulaire).
      expect(find.byType(Table), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
