/// Tests de `ZAnnotationPanel` (ES-8.2) — LAZY `ListView.builder` (AC9),
/// entrées accessibles (AC6/AC7), défensif AD-10 (AC12), canal non-coloré (D5).
/// Pouvoir discriminant (R12) : le lazy est prouvé en MESURANT que < N entrées
/// sont construites dans une fenêtre bornée.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';

Widget _wrap(Widget child, {ZcrudLabels? labels}) => MaterialApp(
      home: ZcrudScope(
        labels: labels,
        child: Scaffold(
          // Fenêtre bornée : le lazy ne peut construire qu'un sous-ensemble.
          body: SizedBox(height: 300, width: 400, child: child),
        ),
      ),
    );

List<ZDocumentAnnotation> _many(int n) => <ZDocumentAnnotation>[
      for (var i = 0; i < n; i++)
        ZDocumentAnnotation(
          id: 'a$i',
          docId: 'doc-1',
          page: i + 1,
          kind: i.isEven
              ? ZDocumentAnnotationKind.highlight
              : ZDocumentAnnotationKind.stickyNote,
          colorKey: 'primary',
          text: 'note $i',
        ),
    ];

Finder _entryFinder() => find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key as ValueKey<String>)
              .value
              .startsWith(kAnnotationPanelEntryKeyPrefix),
    );

void main() {
  group('AC9 — ListView.builder LAZY + onSelect remonte la BONNE annotation',
      () {
    testWidgets('200 annotations ⇒ seul un sous-ensemble est construit',
        (tester) async {
      final annotations = _many(200);
      await tester.pumpWidget(_wrap(
        ZAnnotationPanel(annotations: annotations, onSelect: (_) {}),
      ));
      final built = _entryFinder().evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(200),
          reason:
              'un ListView(children:[...]) construirait les 200 (INJ R3-7)');
      // Preuve de structure : c'est bien un ListView.builder (childrenDelegate
      // paresseux), pas une liste explicite.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets('taper une entrée visible remonte CETTE annotation',
        (tester) async {
      final annotations = _many(200);
      final captured = <ZDocumentAnnotation>[];
      await tester.pumpWidget(_wrap(
        ZAnnotationPanel(annotations: annotations, onSelect: captured.add),
      ));
      await tester.tap(find.byKey(
        const ValueKey<String>('${kAnnotationPanelEntryKeyPrefix}a0'),
      ));
      await tester.pump();
      expect(captured.single, annotations.first,
          reason: 'onSelect doit remonter l\'annotation tapée, pas une autre');
    });
  });

  group('AC6/AC7 — entrées : cible ≥ 48 dp + Semantics (kind + page)', () {
    testWidgets('chaque entrée visible ≥ 48 dp de haut et porte kind+page',
        (tester) async {
      final handle = tester.ensureSemantics();
      final annotations = _many(5);
      await tester.pumpWidget(_wrap(
        ZAnnotationPanel(annotations: annotations, onSelect: (_) {}),
      ));
      final entryKey =
          const ValueKey<String>('${kAnnotationPanelEntryKeyPrefix}a0');
      expect(tester.getSize(find.byKey(entryKey)).height,
          greaterThanOrEqualTo(48));
      final node = tester.getSemantics(find.byKey(entryKey));
      expect(node, containsSemantics(isButton: true));
      // Le canal texte porte kind + page (jamais la couleur seule, D5).
      expect(node.label, isNotEmpty);
      expect(node.value, contains('1'),
          reason: 'la page (1-based) figure dans le canal texte');
      handle.dispose();
    });
  });

  group('AC9(b) — onSelect null ⇒ entrée NON tapable (AD-4)', () {
    testWidgets('sans onSelect, aucune InkWell tapable n\'est câblée',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZAnnotationPanel(annotations: _many(3)),
      ));
      expect(tester.takeException(), isNull);
      final node = tester.getSemantics(find.byKey(
        const ValueKey<String>('${kAnnotationPanelEntryKeyPrefix}a0'),
      ));
      expect(node, containsSemantics(isButton: false),
          reason: 'onSelect null ⇒ entrée non tapable');
    });
  });

  group('AC12 — AD-10 : défensif (text null / colorKey vide / liste vide)', () {
    testWidgets('annotation à contenu vide ⇒ rendu propre, jamais de throw',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZAnnotationPanel(
          annotations: const <ZDocumentAnnotation>[
            ZDocumentAnnotation(id: 'x', docId: 'd', text: null, colorKey: ''),
          ],
          onSelect: (_) {},
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('${kAnnotationPanelEntryKeyPrefix}x')),
        findsOneWidget,
      );
    });

    testWidgets('liste vide ⇒ empty-state (jamais un ListView vide en erreur)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ZAnnotationPanel(annotations: <ZDocumentAnnotation>[]),
      ));
      expect(tester.takeException(), isNull);
      expect(_entryFinder(), findsNothing);
      expect(find.byType(ListView), findsNothing,
          reason: 'liste vide ⇒ empty-state, pas un ListView vide');
    });

    testWidgets('empty-state surchargeable', (tester) async {
      await tester.pumpWidget(_wrap(
        const ZAnnotationPanel(
          annotations: <ZDocumentAnnotation>[],
          emptyState: Text('AUCUNE'),
        ),
      ));
      expect(find.text('AUCUNE'), findsOneWidget);
    });
  });
}
