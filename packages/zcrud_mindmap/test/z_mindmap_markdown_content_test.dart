/// Tests ES-7.2 du seam rich-text opt-in `ZMindmapMarkdownContent` (AC8, OQ-S5).
///
/// ⚠️ **R20** : l'objet PROPRE à l'adaptateur est (1) la **résolution du payload
/// depuis le slot AD-4**, (2) le **repli plain-text**, (3) l'**identité du codec**
/// passé à `ZMarkdownReader`. On NE teste PAS les protections internes de
/// `ZMarkdownReader` (ce serait POWERLESS). **R22** : round-trip discriminant
/// prouvant l'absence de perte (payload rendu == payload stocké). Verrou-source :
/// zéro `implements ZCodec`, zéro heuristique markdown-vs-Delta.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

const String _slot = 'rich_delta';

/// Ops Delta neutres de test (le payload rich stocké dans le slot AD-4).
List<Map<String, dynamic>> _ops() => <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Bonjour '},
      <String, dynamic>{
        'insert': 'gras',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];

Widget _host(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: ZcrudScope(
          child: SizedBox(width: 400, height: 200, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('AC8 — résolution du payload depuis le slot AD-4 (objet propre R20)',
      () {
    test('ZDeltaCodec est IDENTITÉ (propriété du codec — round-trip sans perte)',
        () {
      // PROPRIÉTÉ du codec seul (decode(encode(ops)) == ops) : légitime mais NON
      // discriminante sur le CHOIX de codec de l'adaptateur (ce test construit son
      // propre codec). La preuve que l'ADAPTATEUR compose bien CE codec sur SA
      // valeur est portée par le test widget « rendu rich-text » (round-trip ancré
      // sur `reader.codec`) — c'est lui qui rougirait sur un swap de codec.
      final ops = _ops();
      const codec = ZDeltaCodec();
      final roundTripped = codec.decode(codec.encode(ops));
      expect(roundTripped, equals(ops));
    });

    testWidgets('nœud avec payload AD-4 ⇒ rendu rich-text via ZMarkdownReader',
        (tester) async {
      final node = ZMindmapNode(
        id: 'n',
        label: 'Titre',
        content: 'texte brut', // reste texte brut (OQ-S5)
        extra: <String, dynamic>{_slot: _ops()},
      );
      await tester.pumpWidget(
        _host(ZMindmapMarkdownContent(node: node, slotKey: _slot)),
      );
      await tester.pump();
      // L'adaptateur compose le lecteur RÉUTILISÉ (aucun lecteur réinventé).
      final reader = tester.widget<ZMarkdownReader>(find.byType(ZMarkdownReader));
      // R20 : on assert l'OBJET PROPRE à l'adaptateur — (1) la valeur rendue EST
      // le payload résolu depuis le slot AD-4 (identité, pas de transformation) ;
      // (2) le codec passé est ZDeltaCodec IDENTITÉ. PAS le rendu interne du
      // lecteur (ce serait POWERLESS).
      expect(reader.value, equals(_ops()));
      expect(reader.codec, isA<ZDeltaCodec>());
      // 🔴 R22 DISCRIMINANT ANCRÉ SUR LE CODEC RÉEL DE L'ADAPTATEUR (MEDIUM/LOW-1) :
      // round-trip par le codec que l'ADAPTATEUR a composé (`reader.codec`), pas un
      // codec local — si l'adaptateur composait un codec ré-encodant/à perte, ce
      // round-trip perdrait attributs/embeds ⇒ ROUGE. Prouve l'ABSENCE DE PERTE de
      // la voie effectivement empruntée par la donnée.
      final adapterCodec = reader.codec!;
      final value = reader.value! as List<Map<String, dynamic>>;
      expect(adapterCodec.decode(adapterCodec.encode(value)), equals(_ops()));
      // Le titre du nœud alimente la sémantique (label), le content reste brut.
      expect(reader.label, 'Titre');
    });

    testWidgets(
        'INJ-7 (repli) : slot ABSENT ⇒ repli plain-text (label), PAS de rendu '
        'rich vide', (tester) async {
      final node = ZMindmapNode(id: 'n', label: 'BrutSeul', content: 'corps');
      await tester.pumpWidget(
        _host(ZMindmapMarkdownContent(node: node, slotKey: _slot)),
      );
      await tester.pump();
      // 🔴 GARDE (INJ-7) : sans repli, un nœud sans payload rendrait un lecteur
      // rich VIDE ; ici on exige le défaut plain-text (label visible).
      expect(find.byType(ZMarkdownReader), findsNothing);
      expect(find.text('BrutSeul'), findsOneWidget);
    });

    testWidgets('slot MAL FORMÉ (non-liste) ⇒ repli plain-text (défensif AD-10)',
        (tester) async {
      final node = ZMindmapNode(
        id: 'n',
        label: 'Brut',
        extra: <String, dynamic>{_slot: 'pas une liste dops'},
      );
      await tester.pumpWidget(
        _host(ZMindmapMarkdownContent(node: node, slotKey: _slot)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull); // jamais de throw
      expect(find.byType(ZMarkdownReader), findsNothing);
      expect(find.text('Brut'), findsOneWidget);
    });

    testWidgets('slot liste avec élément non-map ⇒ repli plain-text',
        (tester) async {
      final node = ZMindmapNode(
        id: 'n',
        label: 'Brut2',
        extra: <String, dynamic>{
          _slot: <dynamic>[42, 'x'],
        },
      );
      await tester.pumpWidget(
        _host(ZMindmapMarkdownContent(node: node, slotKey: _slot)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZMarkdownReader), findsNothing);
      expect(find.text('Brut2'), findsOneWidget);
    });

    testWidgets(
        'AC8 : le nodeContentBuilder PAR DÉFAUT de la vue reste texte brut '
        '(autres apps non forcées)', (tester) async {
      // Sans nodeContentBuilder rich, un nœud portant un payload AD-4 n'est PAS
      // rendu en rich : aucun ZMarkdownReader n'est instancié.
      final roots = <ZMindmapNode>[
        ZMindmapNode(
          id: 'r',
          label: 'Racine',
          extra: <String, dynamic>{_slot: _ops()},
        ),
      ];
      await tester.pumpWidget(
        _host(ZMindmapView(roots: roots, mode: ZMindmapViewMode.list)),
      );
      await tester.pump();
      expect(find.byType(ZMarkdownReader), findsNothing);
      expect(find.text('Racine'), findsOneWidget);
    });

    testWidgets('builder() branché en nodeContentBuilder ⇒ rich-text opt-in',
        (tester) async {
      final roots = <ZMindmapNode>[
        ZMindmapNode(
          id: 'r',
          label: 'Racine',
          extra: <String, dynamic>{_slot: _ops()},
        ),
      ];
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: roots,
            mode: ZMindmapViewMode.list,
            nodeContentBuilder:
                ZMindmapMarkdownContent.builder(slotKey: _slot),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ZMarkdownReader), findsOneWidget);
    });
  });

  group('AC8 — verrou-source (scan machine, R21) : aucun nouveau codec', () {
    test(
        'zcrud_mindmap : zéro `implements ZCodec`, zéro heuristique, import '
        'zcrud_markdown obligatoire dans l\'adaptateur', () {
      final adapter = _srcFile('z_mindmap_markdown_content.dart');
      final src = _stripComments(adapter.readAsStringSync());

      // Import obligatoire de l'API markdown réutilisée (pas de réinvention).
      expect(src.contains('package:zcrud_markdown/zcrud_markdown.dart'), isTrue,
          reason: 'l\'adaptateur DOIT composer l\'API zcrud_markdown existante');

      // 🔴 GARDE (INJ-6) : aucun nouveau codec, aucune heuristique de format.
      final libSources = _allLibSources();
      for (final f in libSources) {
        final s = _stripComments(f.readAsStringSync());
        expect(RegExp(r'implements\s+ZCodec').hasMatch(s), isFalse,
            reason: 'nouveau codec interdit dans ${f.path}');
        expect(RegExp(r'extends\s+ZCodec').hasMatch(s), isFalse,
            reason: 'nouveau codec interdit dans ${f.path}');
        // Heuristiques markdown-vs-Delta bannies (on lit un slot typé, pas une
        // devinette de format).
        expect(s.contains("startsWith('[')"), isFalse,
            reason: 'heuristique de format interdite dans ${f.path}');
        expect(s.contains('"insert"'), isFalse,
            reason: 'heuristique de format interdite dans ${f.path}');
      }
    });
  });
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

List<File> _allLibSources() {
  const roots = <String>['lib', 'packages/zcrud_mindmap/lib'];
  for (final r in roots) {
    final dir = Directory(r);
    if (dir.existsSync()) {
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }
  }
  return const <File>[];
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
