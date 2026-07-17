/// Tests SU-12 de l'adaptateur d'édition riche `ZMindmapMarkdownEditField`
/// (AC2). Objet PROPRE de l'adaptateur : (1) SEED depuis le slot AD-4, (2) voie
/// d'écriture qui pousse les ops NEUTRES dans le MÊME slot que lit le rendu
/// (symétrie round-trip R22), (3) slot-par-kind (label ⇄ content sans collision),
/// (4) verrou-source : zéro type Quill/Delta/math dans une signature publique.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

const String _slot = 'rich_delta';

List<Map<String, dynamic>> _ops() => <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Bonjour '},
      <String, dynamic>{
        'insert': 'gras',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: ZcrudScope(
            child: SizedBox(width: 500, height: 400, child: child),
          ),
        ),
      ),
    );

/// Nettoyage de l'éditeur Quill inline (annule les Timers avant démontage).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

/// Construit un contexte de slot d'édition manuel avec des espions de voie.
ZMindmapEditFieldContext _ctx(
  ZMindmapNode node,
  ZMindmapEditFieldKind kind, {
  required void Function(String, List<Map<String, dynamic>>) onWriteRich,
}) {
  return ZMindmapEditFieldContext(
    node: node,
    kind: kind,
    controller: TextEditingController(),
    value: kind == ZMindmapEditFieldKind.label ? node.label : (node.content ?? ''),
    onChanged: (_) {},
    writeRichSlot: onWriteRich,
    hint: 'hint',
    config: const ZMindmapViewConfig(),
    theme: const ZcrudTheme(),
  );
}

void main() {
  group('AC2 — seed depuis le slot AD-4 (voie de lecture de l\'adaptateur)', () {
    testWidgets('content : la valeur SEED == ops du slot `slotKey`',
        (tester) async {
      final node = ZMindmapNode(
        id: 'n',
        label: 'T',
        extra: <String, dynamic>{_slot: _ops()},
      );
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.content,
              onWriteRich: (_, __) {}),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      final field = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
      // La valeur portée par la tranche EST le payload résolu du slot (identité).
      expect(field.ctx!.value, equals(_ops()));
      // Codec IDENTITÉ composé par l'adaptateur (round-trip R22 sans perte).
      expect(field.codec, isA<ZDeltaCodec>());
      await _settle(tester);
    });

    testWidgets('slot ABSENT ⇒ seed = liste vide (défensif AD-10, aucun throw)',
        (tester) async {
      final node = ZMindmapNode(id: 'n', label: 'T');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.content,
              onWriteRich: (_, __) {}),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final field = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
      expect(field.ctx!.value, isEmpty);
      await _settle(tester);
    });
  });

  group('AC2 — voie d\'ÉCRITURE (comportement, pas présence de paramètre)', () {
    testWidgets(
        'onChanged de la tranche ⇒ writeRichSlot(slotKey, ops) — MÊME slot que '
        'le rendu (symétrie R22)', (tester) async {
      String? wroteSlot;
      List<Map<String, dynamic>>? wroteOps;
      final node = ZMindmapNode(id: 'n', label: 'T');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.content, onWriteRich: (s, o) {
            wroteSlot = s;
            wroteOps = o;
          }),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      // On actionne la VOIE RÉELLE que l'adaptateur a câblée (le `onChanged`
      // value-in-slice construit par l'adaptateur), avec une valeur neutre.
      final field = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
      field.ctx!.onChanged(_ops());
      // Rougit si l'adaptateur écrivait un AUTRE slot ou perdait writeRichSlot.
      expect(wroteSlot, _slot);
      expect(wroteOps, equals(_ops()));
      await _settle(tester);
    });

    test('controller.editRichSlot écrit extra[slot], label/content INCHANGÉS',
        () {
      final controller =
          ZMindmapOutlineController(initialForest: <ZMindmapNode>[
        ZMindmapNode(id: 'n', label: 'Titre', content: 'corps brut'),
      ]);
      addTearDown(controller.dispose);
      controller.editRichSlot('n', _slot, _ops());
      final node = controller.forest.first;
      // Slot AD-4 écrit…
      expect(node.extra[_slot], equals(_ops()));
      // …mais label/content restent TEXTE BRUT (OQ-S5/AD-28).
      expect(node.label, 'Titre');
      expect(node.content, 'corps brut');
    });

    testWidgets(
        'SYMÉTRIE round-trip : editRichSlot(slot) ⇒ ZMindmapMarkdownContent(slot) '
        'REND ces ops', (tester) async {
      final controller =
          ZMindmapOutlineController(initialForest: <ZMindmapNode>[
        ZMindmapNode(id: 'n', label: 'Titre'),
      ]);
      addTearDown(controller.dispose);
      controller.editRichSlot('n', _slot, _ops());
      final node = controller.forest.first;
      await tester.pumpWidget(
        _host(ZMindmapMarkdownContent(node: node, slotKey: _slot)),
      );
      await tester.pump();
      final reader = tester.widget<ZMarkdownReader>(find.byType(ZMarkdownReader));
      // Le rendu LIT exactement ce que l'édition a ÉCRIT (même slot, mêmes ops).
      expect(reader.value, equals(_ops()));
      await _settle(tester);
    });
  });

  group('AC2 — slot-par-kind : label ⇄ content sans collision', () {
    test('content → baseSlot ; label → `\${baseSlot}__label`', () {
      expect(
        ZMindmapMarkdownEditField.slotKeyFor(_slot, ZMindmapEditFieldKind.content),
        _slot,
      );
      expect(
        ZMindmapMarkdownEditField.slotKeyFor(_slot, ZMindmapEditFieldKind.label),
        '${_slot}__label',
      );
      // Les deux slots sont DISTINCTS ⇒ jamais d'écrasement content↔label.
      expect(
        ZMindmapMarkdownEditField.slotKeyFor(_slot, ZMindmapEditFieldKind.label),
        isNot(equals(
          ZMindmapMarkdownEditField.slotKeyFor(
              _slot, ZMindmapEditFieldKind.content),
        )),
      );
    });

    testWidgets('éditer le label écrit `__label`, pas le slot content',
        (tester) async {
      String? wroteSlot;
      final node = ZMindmapNode(id: 'n', label: 'T');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.label,
              onWriteRich: (s, _) => wroteSlot = s),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      final field = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
      field.ctx!.onChanged(_ops());
      expect(wroteSlot, '${_slot}__label');
      await _settle(tester);
    });
  });

  group('AD-13 (D1) — le contrôle FOCUSABLE porte le label a11y ET ≥ 48 dp', () {
    testWidgets(
        'le label a11y ATTEINT le nœud `Semantics(textField)` réel (pas fantôme)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final node = ZMindmapNode(id: 'n', label: 'T');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.content,
              onWriteRich: (_, __) {}),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      // Le VRAI contrôle focusable/tappable = le nœud sémantique `textField`.
      final field = _textFieldSemantics(tester);
      // Rougit si l'adaptateur perdait le label (ex. bascule sur `field.name`
      // technique `zmindmap-…` ou nœud fantôme sans label — su-8/9).
      expect(field.label, 'hint',
          reason: 'le label a11y doit atteindre le contrôle focusable réel');
      handle.dispose();
      await _settle(tester);
    });

    testWidgets(
        'la zone éditable focusable atteint la cible tactile ≥ minTapTarget (AD-13)',
        (tester) async {
      final handle = tester.ensureSemantics();
      const config = ZMindmapViewConfig();
      final node = ZMindmapNode(id: 'n', label: 'T');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownEditField(
          ctx: _ctx(node, ZMindmapEditFieldKind.content,
              onWriteRich: (_, __) {}),
          baseSlotKey: _slot,
        )),
      );
      await tester.pump();
      // Mesure la hauteur RENDUE du contrôle focusable (le point d'interaction).
      final size = _textFieldSemanticsSize(tester);
      // Rougit si l'adaptateur retombait à `minLines: 1` (~37 dp) — régression
      // AD-13 sous le défaut `TextField` (`minHeight: config.minTapTarget`).
      expect(size.height, greaterThanOrEqualTo(config.minTapTarget),
          reason: 'cible tactile de la zone éditable < 48 dp (AD-13)');
      handle.dispose();
      await _settle(tester);
    });
  });

  group('AC2 — verrou-source (R21) : zéro type Quill/Delta/math public', () {
    test('l\'adaptateur compose zcrud_markdown ; aucun symbole Quill exposé', () {
      final adapter = _srcFile('z_mindmap_markdown_edit_field.dart');
      final src = _stripComments(adapter.readAsStringSync());
      // Compose bien l'API markdown réutilisée (pas de réinvention).
      expect(src.contains('package:zcrud_markdown/zcrud_markdown.dart'), isTrue);
      // Aucun type Quill/Delta/math dans le fichier (ni signature, ni corps) —
      // l'isolation AD-7 passe par la valeur NEUTRE (ops Delta JSON).
      expect(src.contains('QuillController'), isFalse,
          reason: 'aucun type Quill dans l\'adaptateur (AD-7)');
      expect(RegExp(r'\bDelta\b').hasMatch(src), isFalse,
          reason: 'aucun type Delta Quill dans l\'adaptateur (AD-7)');
      expect(src.contains('flutter_quill'), isFalse);
      expect(src.contains('flutter_math_fork'), isFalse);
    });
  });
}

/// Finder du **contrôle focusable réel** : le `Semantics` portant le flag
/// `textField` (le vrai point d'interaction éditable, PAS un nœud fantôme).
Finder _textFieldFinder() => find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.textField ?? false),
    );

/// Propriétés sémantiques du contrôle focusable (label a11y inclus).
SemanticsProperties _textFieldSemantics(WidgetTester tester) {
  final finder = _textFieldFinder();
  expect(finder, findsWidgets,
      reason: 'aucun nœud Semantics(textField) — contrôle focusable introuvable');
  return tester.widget<Semantics>(finder.first).properties;
}

/// Taille RENDUE du contrôle focusable (mesure de la cible tactile).
Size _textFieldSemanticsSize(WidgetTester tester) {
  final finder = _textFieldFinder();
  expect(finder, findsWidgets,
      reason: 'aucun nœud Semantics(textField) — contrôle focusable introuvable');
  return tester.getSize(finder.first);
}

File _srcFile(String name) {
  const roots = <String>[
    'lib/src/presentation',
    'packages/zcrud_mindmap/lib/src/presentation',
  ];
  for (final r in roots) {
    final f = File('$r/$name');
    if (f.existsSync()) return f;
  }
  return File('${roots.first}/$name');
}

String _stripComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('///') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('*')) {
      continue;
    }
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}
