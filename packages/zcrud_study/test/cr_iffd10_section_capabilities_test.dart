// CR-IFFD-10 — quatre capacités de `folder_study_tools_page.dart` (la page dont
// `ZStudyToolsPage` a été PORTÉE) manquaient à `ZStudyToolsSectionSpec`.
//
// Deux d'entre elles n'avaient AUCUN contournement app-side : les sections
// repliables et la grille multi-colonnes exigeaient de réimplémenter le layout
// côté hôte — ce qu'AD-4 proscrit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

ZStudyToolsSectionSpec _spec({
  int itemCount = 3,
  bool collapsible = false,
  bool initiallyExpanded = true,
  double? crossAxisMinItemWidth,
  int? headerCount,
  VoidCallback? secondaryAction,
  VoidCallback? addAction,
}) =>
    ZStudyToolsSectionSpec(
      id: 'docs',
      title: 'Documents',
      itemCount: itemCount,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item_$i'),
        height: 40,
        child: Text('Item $i'),
      ),
      emptyState: const Text('Aucun document'),
      collapsible: collapsible,
      initiallyExpanded: initiallyExpanded,
      crossAxisMinItemWidth: crossAxisMinItemWidth,
      headerCount: headerCount,
      secondaryAction: secondaryAction,
      addAction: addAction,
    );

Future<void> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  double width = 400,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[spec]),
          ),
        ),
      ),
    );

void main() {
  group('§1 — sections repliables', () {
    testWidgets('🔴 collapsible + initiallyExpanded:false ⇒ corps MASQUÉ',
        (tester) async {
      await _pump(tester, _spec(collapsible: true, initiallyExpanded: false));
      expect(find.byKey(const ValueKey<String>('item_0')), findsNothing);
    });

    testWidgets('bascule : déplie puis replie', (tester) async {
      await _pump(tester, _spec(collapsible: true, initiallyExpanded: false));
      final toggle = find.byKey(const ValueKey<String>('section:docs:collapse'));
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('item_0')), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('item_0')), findsNothing);
    });

    testWidgets('collapsible:false (défaut) ⇒ AUCUN bouton, rendu inchangé',
        (tester) async {
      await _pump(tester, _spec());
      expect(find.byKey(const ValueKey<String>('section:docs:collapse')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('item_0')), findsOneWidget);
    });
  });

  group('§2 — grille multi-colonnes', () {
    testWidgets('🔴 largeur suffisante ⇒ items SUR LA MÊME LIGNE',
        (tester) async {
      // 900 / 300 = 3 colonnes : les 3 items partagent une ligne.
      await _pump(tester, _spec(crossAxisMinItemWidth: 300), width: 900);
      final y0 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_0'))).dy;
      final y1 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_1'))).dy;
      expect(y1, y0, reason: 'même ligne ⇒ même ordonnée');
    });

    testWidgets('largeur insuffisante ⇒ repli mono-colonne', (tester) async {
      await _pump(tester, _spec(crossAxisMinItemWidth: 300), width: 320);
      final y0 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_0'))).dy;
      final y1 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_1'))).dy;
      expect(y1, greaterThan(y0), reason: 'empilé');
    });

    testWidgets('null (défaut) ⇒ mono-colonne même en grand écran',
        (tester) async {
      await _pump(tester, _spec(), width: 1200);
      final y0 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_0'))).dy;
      final y1 = tester.getTopLeft(find.byKey(const ValueKey<String>('item_1'))).dy;
      expect(y1, greaterThan(y0), reason: 'rétro-compatibilité stricte');
    });
  });

  group('§3 — action d\'en-tête secondaire', () {
    testWidgets('secondaryAction ET addAction coexistent', (tester) async {
      var seen = 0;
      var added = 0;
      await _pump(
        tester,
        _spec(secondaryAction: () => seen++, addAction: () => added++),
      );
      final secondary =
          find.byKey(const ValueKey<String>('section:docs:secondaryAction'));
      expect(secondary, findsOneWidget);

      await tester.tap(secondary);
      await tester.pump();
      expect(seen, 1);
      expect(added, 0, reason: 'les deux actions sont DISTINCTES');
    });

    testWidgets('null ⇒ action absente (AD-4)', (tester) async {
      await _pump(tester, _spec(addAction: () {}));
      expect(find.byKey(const ValueKey<String>('section:docs:secondaryAction')),
          findsNothing);
    });

    testWidgets('a11y — cible ≥ 48 dp (AD-13)', (tester) async {
      await _pump(tester, _spec(secondaryAction: () {}));
      final size = tester.getSize(
        find.byKey(const ValueKey<String>('section:docs:secondaryAction')),
      );
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });

  group('§4 — compteur d\'en-tête découplé', () {
    testWidgets('🔴 headerCount affiche le TOTAL, le rail reste tronqué',
        (tester) async {
      // Patron d'origine : badge = 42, rail = take(10).
      await _pump(tester, _spec(itemCount: 10, headerCount: 42));
      expect(find.text('42'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('item_9')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('item_10')), findsNothing);
    });

    testWidgets('null (défaut) ⇒ le badge suit itemCount', (tester) async {
      await _pump(tester, _spec(itemCount: 3));
      expect(find.text('3'), findsOneWidget);
    });
  });
}
