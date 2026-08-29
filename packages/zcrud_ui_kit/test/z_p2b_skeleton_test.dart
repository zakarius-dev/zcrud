/// `ZSkeleton` / `ZSkeletonList` : rôles du thème, animation bornée, silence
/// sémantique.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

const Color _seed = Color(0xFF3366AA);

ColorScheme get _scheme => ColorScheme.fromSeed(seedColor: _seed);

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(useMaterial3: true, colorSchemeSeed: _seed),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

/// Couleurs effectivement peintes par les formes du squelette.
List<Color?> _painted(WidgetTester tester, Type root) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(root),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((DecoratedBox b) => (b.decoration as BoxDecoration).color)
    .toList();

/// Vrai si un nœud de l'arbre sémantique se comporte en zone défilable.
bool _hasScrollableNode(WidgetTester tester) {
  bool found = false;
  void visit(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    if (data.flagsCollection.hasImplicitScrolling ||
        data.hasAction(SemanticsAction.scrollUp)) {
      found = true;
    }
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(MaterialApp)));
  return found;
}

void main() {
  group('P2-B — ZSkeleton peint des RÔLES, jamais une couleur', () {
    testWidgets('la teinte de départ est surfaceContainerHighest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZSkeleton.line()));
      expect(_painted(tester, ZSkeleton), <Color>[
        _scheme.surfaceContainerHighest,
      ]);
    });

    testWidgets('tile : un carré de tête + une barre par ligne demandée', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZSkeleton.tile(lines: 3)));
      expect(_painted(tester, ZSkeleton).length, 4);
    });
  });

  group('P2-B — animation bornée', () {
    testWidgets('actif ⇒ des frames sont demandées, et la teinte BOUGE', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZSkeleton.line()));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final Color? start = _painted(tester, ZSkeleton).single;
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painted(tester, ZSkeleton).single, isNot(start));
      // Ne pas laisser l'animation tourner à la fin du test.
      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('inactif ⇒ AUCUNE frame demandée, la forme reste peinte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZSkeleton.line(active: false)));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painted(tester, ZSkeleton), <Color>[
        _scheme.surfaceContainerHighest,
      ]);
    });

    testWidgets('retiré de l\'arbre ⇒ plus aucune frame en vol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZSkeleton.line()));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('Réduire les animations ⇒ aucune frame, forme TOUJOURS '
        'visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZSkeleton.box(height: 40), disableAnimations: true),
      );
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painted(tester, ZSkeleton), <Color>[
        _scheme.surfaceContainerHighest,
      ]);
    });
  });

  group('P2-B — ZSkeletonList', () {
    testWidgets('count ⇒ autant de lignes', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZSkeletonList(count: 5, active: false)),
      );
      expect(find.byType(ZSkeleton), findsNWidgets(5));
    });

    testWidgets('count négatif ⇒ liste vide, jamais une exception', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const ZSkeletonList(count: -3, active: false)),
      );
      expect(find.byType(ZSkeleton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemBuilder substitue la forme d\'une ligne', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZSkeletonList(
            count: 2,
            active: false,
            itemBuilder: (BuildContext context, int index) =>
                const ZSkeleton.line(active: false),
          ),
        ),
      );
      expect(find.byType(ZSkeleton), findsNWidgets(2));
      // Une ligne = une seule forme peinte ; une tuile en aurait trois.
      expect(_painted(tester, ZSkeletonList).length, 2);
    });

    testWidgets('MUETTE : aucune zone défilable annoncée au lecteur d\'écran', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const ZSkeletonList(count: 30, active: false)),
      );
      expect(_hasScrollableNode(tester), isFalse);
      handle.dispose();
    });

    testWidgets('témoin : une liste ÉQUIVALENTE non protégée annonce bien '
        'une zone défilable', (WidgetTester tester) async {
      // Sans ce témoin, la garde précédente pourrait être verte parce que le
      // scénario est hors d'atteinte plutôt que parce que la protection tient.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ListView.builder(
            itemCount: 30,
            itemBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 40),
          ),
        ),
      );
      expect(_hasScrollableNode(tester), isTrue);
      handle.dispose();
    });
  });
}
