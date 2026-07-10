/// Tests widget de `ZMindmapView` / `ZMindmapListView` (Story E10-2).
///
/// Couvre AC1..AC6 : rendu graphe (multi-racine, forêt vide), vue liste indentée
/// a11y, injection `nodeContentBuilder`, thème injecté consommé, RTL directionnel,
/// cibles ≥ 48 dp, réactivité par callback.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Forêt mono-racine à 3 niveaux (0,1,2) : Root → {Child1 → Grand1, Child2}.
List<ZMindmapNode> _forest() => ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(
        id: 'r',
        label: 'Root',
        children: <ZMindmapNode>[
          ZMindmapNode(
            id: 'c1',
            label: 'Child1',
            children: <ZMindmapNode>[
              ZMindmapNode(id: 'g1', label: 'Grand1'),
            ],
          ),
          ZMindmapNode(id: 'c2', label: 'Child2'),
        ],
      ),
    ]);

/// Forêt multi-racine : Alpha ; Beta → BetaChild.
List<ZMindmapNode> _multiRoot() =>
    ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(id: 'a', label: 'Alpha'),
      ZMindmapNode(
        id: 'b',
        label: 'Beta',
        children: <ZMindmapNode>[ZMindmapNode(id: 'b1', label: 'BetaChild')],
      ),
    ]);

/// Enveloppe une vue dans un `MaterialApp`/`Scaffold` borné (+ scope optionnel).
Widget _host(
  Widget child, {
  ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
}) {
  Widget scoped = SizedBox(width: 800, height: 600, child: child);
  scoped = ZcrudScope(theme: theme, child: scoped);
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: scoped),
    ),
  );
}

void main() {
  group('AC1 — graphe auto-agencé graphite', () {
    testWidgets('rend une forêt à ≥3 niveaux sans exception, labels présents',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapView(roots: _forest())));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Root'), findsWidgets);
      expect(find.text('Child1'), findsWidgets);
      expect(find.text('Grand1'), findsWidgets);
    });

    testWidgets('forêt multi-racine rendue sans crash', (tester) async {
      await tester.pumpWidget(_host(ZMindmapView(roots: _multiRoot())));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Alpha'), findsWidgets);
      expect(find.text('Beta'), findsWidgets);
      expect(find.text('BetaChild'), findsWidgets);
    });

    testWidgets('forêt vide → état vide accessible, aucun crash',
        (tester) async {
      await tester.pumpWidget(
        _host(ZMindmapView(roots: const <ZMindmapNode>[])),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: const <ZMindmapNode>[],
            emptyLabel: 'Carte vide',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Carte vide'), findsOneWidget);
    });

    testWidgets('le graphe est ExcludeSemantics (surface visuelle)',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapView(roots: _forest())));
      await tester.pump();
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });
  });

  group('AC2 — vue liste sémantique indentée', () {
    testWidgets('une entrée par nœud (DFS) via ListView.builder',
        (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      // 4 nœuds → 4 entrées (une par nœud).
      expect(find.byKey(const ValueKey<String>('zmindmap-list-r')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zmindmap-list-c1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zmindmap-list-c2')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zmindmap-list-g1')), findsOneWidget);
    });

    testWidgets('indentation directionnelle croissante avec level',
        (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
            config: const ZMindmapViewConfig(indentStep: 24),
          ),
        ),
      );
      await tester.pump();

      double startOf(String id) {
        final padding = tester.widget<Padding>(
          find.byKey(ValueKey<String>('zmindmap-list-$id')),
        );
        final edge = padding.padding as EdgeInsetsDirectional;
        return edge.start;
      }

      expect(startOf('r'), 0); // level 0
      expect(startOf('c1'), 24); // level 1
      expect(startOf('g1'), 48); // level 2
      expect(startOf('c1') < startOf('g1'), isTrue);
    });

    testWidgets('cibles interactives ≥ 48 dp', (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
            onNodeTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      final tallEnough = find.byWidgetPredicate(
        (w) =>
            w is ConstrainedBox &&
            w.constraints.minHeight >= 48 &&
            w.constraints.minWidth >= 48,
      );
      expect(tallEnough, findsWidgets);
    });

    testWidgets('Semantics explicites label = node.label sur la liste',
        (tester) async {
      final handle = tester.ensureSemantics();
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Root'), findsOneWidget);
      expect(find.bySemanticsLabel('Grand1'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AC3 — nodeContentBuilder injectable', () {
    testWidgets('builder custom utilisé dans le graphe', (tester) async {
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _forest(),
            nodeContentBuilder: (c, n) => Text('SENT-${n.id}'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SENT-r'), findsWidgets);
      expect(find.text('SENT-g1'), findsWidgets);
    });

    testWidgets('builder custom utilisé dans la liste', (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text('SENT-${n.id}'),
            selectedListenable: selected,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SENT-r'), findsOneWidget);
      expect(find.text('SENT-c2'), findsOneWidget);
    });

    testWidgets('défaut sûr affiche label quand builder null', (tester) async {
      await tester.pumpWidget(
        _host(ZMindmapView(roots: _forest(), mode: ZMindmapViewMode.list)),
      );
      await tester.pump();
      expect(find.text('Root'), findsWidgets);
      expect(find.text('Child2'), findsWidgets);
    });
  });

  group('AC5 — thème injecté consommé (FR-26)', () {
    testWidgets('la couleur de surface du nœud dérive du token injecté',
        (tester) async {
      const injected = Color(0xFF112233);
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
          ),
          theme: const ZcrudTheme(surfaceColor: injected),
        ),
      );
      await tester.pump();

      final matching = find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.color == injected;
      });
      expect(matching, findsWidgets);
    });
  });

  group('AC4 — RTL directionnel', () {
    testWidgets('sous RTL, l\'indentation part du côté start (droite)',
        (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
            config: const ZMindmapViewConfig(indentStep: 24),
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pump();

      final padding = tester.widget<Padding>(
        find.byKey(const ValueKey<String>('zmindmap-list-g1')),
      );
      final edge = padding.padding as EdgeInsetsDirectional;
      expect(edge.start, 48);
      // En RTL, `start` se résout côté droit.
      final resolved = edge.resolve(TextDirection.rtl);
      expect(resolved.right, 48);
      expect(resolved.left, 0);
    });
  });

  group('AC6 — réactivité par callback (lecture seule)', () {
    testWidgets('tap sur une entrée déclenche onNodeTap avec le bon nœud',
        (tester) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      ZMindmapNode? tapped;
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
            onNodeTap: (n) {
              tapped = n;
              selected.value = n.id;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('zmindmap-list-c1')));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.id, 'c1');
      expect(selected.value, 'c1');
    });

    testWidgets('ZMindmapView remonte la sélection via onNodeSelected',
        (tester) async {
      ZMindmapNode? selectedNode;
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _forest(),
            mode: ZMindmapViewMode.list,
            onNodeSelected: (n) => selectedNode = n,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('zmindmap-list-c2')));
      await tester.pump();
      expect(selectedNode, isNotNull);
      expect(selectedNode!.id, 'c2');
    });

    testWidgets(
        'H1 — l\'action sémantique d\'activation (lecteur d\'écran) déclenche '
        'onNodeTap', (tester) async {
      final handle = tester.ensureSemantics();
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      ZMindmapNode? tapped;
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: _forest(),
            contentBuilder: (c, n) => Text(n.label),
            selectedListenable: selected,
            onNodeTap: (n) => tapped = n,
          ),
        ),
      );
      await tester.pump();

      // Activer l'entrée via l'ACTION SÉMANTIQUE (≠ tap pointeur) : c'est la
      // voie qu'emprunte un lecteur d'écran. Sans l'action sur le Semantics
      // parent (H1), onNodeTap ne serait jamais appelé (le GestureDetector de
      // la carte est sous ExcludeSemantics).
      final semNode = tester.getSemantics(
        find.byKey(const ValueKey<String>('zmindmap-list-sem-c1')),
      );
      expect(
        semNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'l\'entrée expose une action tap accessible',
      );
      // Le SemanticsOwner portant le nœud ciblé est celui de `pipelineOwner`
      // (l'id provient de `getSemantics`), d'où l'usage assumé du membre déprécié.
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(semNode.id, SemanticsAction.tap);
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.id, 'c1');
      handle.dispose();
    });
  });
}
