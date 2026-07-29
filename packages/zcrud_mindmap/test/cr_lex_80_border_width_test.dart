/// CR-LEX-80 — l'épaisseur du trait de la carte de nœud est injectable.
///
/// `ZMindmapViewConfig.borderWidth` / `.selectedBorderWidth` (`double?`) pilotent
/// respectivement l'état **non sélectionné** et l'état **sélectionné**. Défauts
/// `1` / `2` ⇒ rendu strictement inchangé quand l'hôte n'injecte rien.
///
/// Gardes (discipline R3 — chacune rougit sous sa régression exacte) :
/// - G1 : `borderWidth` injectée réellement appliquée (état NON sélectionné) ;
/// - G2 : `selectedBorderWidth` injectée réellement appliquée (état SÉLECTIONNÉ) ;
/// - G3 : défauts `1`/`2` préservés quand rien n'est injecté ;
/// - G4 : la distinction sélectionné ⇄ non sélectionné reste observable au défaut ;
/// - G5 : chemin `config → carte` réel (via `ZMindmapListView`, sélection vive) ;
/// - G6 : largeur absurde (négative) ⇒ `AssertionError` (convention du fichier).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

ZMindmapNode _node([String id = 'n1']) =>
    ZMindmapNode(id: id, label: 'Node $id');

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
      ),
    );

/// Épaisseur du trait de la carte enveloppant le texte [label].
double _borderWidthOf(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  final decoration = box.decoration as BoxDecoration;
  return decoration.border!.top.width;
}

Widget _card({
  required bool isSelected,
  ZMindmapViewConfig config = const ZMindmapViewConfig(),
  String id = 'n1',
}) =>
    ZMindmapNodeCard(
      node: _node(id),
      contentBuilder: (context, node) => Text(node.label),
      isSelected: isSelected,
      config: config,
    );

void main() {
  group('CR-LEX-80 — épaisseur de trait injectable', () {
    testWidgets('G1 — borderWidth injectée s\'applique à l\'état NON sélectionné',
        (tester) async {
      await tester.pumpWidget(
        _host(
          _card(
            isSelected: false,
            config: const ZMindmapViewConfig(borderWidth: 5),
          ),
        ),
      );
      expect(_borderWidthOf(tester, 'Node n1'), 5);
    });

    testWidgets(
        'G2 — selectedBorderWidth injectée s\'applique à l\'état SÉLECTIONNÉ',
        (tester) async {
      await tester.pumpWidget(
        _host(
          _card(
            isSelected: true,
            config: const ZMindmapViewConfig(selectedBorderWidth: 7),
          ),
        ),
      );
      expect(_borderWidthOf(tester, 'Node n1'), 7);
    });

    testWidgets('G3 — défauts 1 / 2 préservés quand rien n\'est injecté',
        (tester) async {
      await tester.pumpWidget(_host(_card(isSelected: false)));
      expect(_borderWidthOf(tester, 'Node n1'), 1,
          reason: 'défaut non sélectionné = 1 (rendu historique)');

      await tester.pumpWidget(_host(_card(isSelected: true)));
      expect(_borderWidthOf(tester, 'Node n1'), 2,
          reason: 'défaut sélectionné = 2 (rendu historique)');
    });

    testWidgets(
        'G4 — au défaut, l\'épaisseur reste un canal de distinction de sélection',
        (tester) async {
      await tester.pumpWidget(_host(_card(isSelected: false)));
      final unselected = _borderWidthOf(tester, 'Node n1');
      await tester.pumpWidget(_host(_card(isSelected: true)));
      final selected = _borderWidthOf(tester, 'Node n1');
      expect(selected, greaterThan(unselected));
    });

    testWidgets(
        'G5 — chemin config → carte réel : ZMindmapListView propage les deux',
        (tester) async {
      final selected = ValueNotifier<String?>('a');
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapListView(
            roots: ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
              ZMindmapNode(id: 'a', label: 'Alpha'),
              ZMindmapNode(id: 'b', label: 'Beta'),
            ]),
            contentBuilder: (context, node) => Text(node.label),
            selectedListenable: selected,
            config: const ZMindmapViewConfig(
              borderWidth: 3,
              selectedBorderWidth: 6,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_borderWidthOf(tester, 'Alpha'), 6, reason: 'Alpha sélectionné');
      expect(_borderWidthOf(tester, 'Beta'), 3, reason: 'Beta non sélectionné');
    });

    test('G6 — largeur négative rejetée par assert (convention du fichier)', () {
      final negative = -1.0 * DateTime.now().year.sign;
      expect(
        () => ZMindmapViewConfig(borderWidth: negative),
        throwsAssertionError,
      );
      expect(
        () => ZMindmapViewConfig(selectedBorderWidth: negative),
        throwsAssertionError,
      );
    });
  });
}
