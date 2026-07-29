// CR-LEX-79 — l'affordance de réordonnancement manquait ENTIÈREMENT sur le
// chemin GRILLE, et le glyphe de la poignée du chemin LISTE n'était pas
// injectable.
//
// ⚠️ Ce que ces gardes matérialisent, c'est le caractère SILENCIEUX de la perte
// mesurée par lex : ajouter `crossAxisMinItemWidth` à une section déjà
// réordonnable faisait disparaître poignée + `Semantics` + cible 48 dp SANS
// aucune erreur ni assert, et le glisser continuait de passer en test. Une
// garde de « le drag fonctionne » ne peut donc PAS attraper ce défaut : chaque
// garde ci-dessous mesure l'AFFORDANCE (présence du glyphe, libellé porté,
// taille rendue), jamais la seule mécanique du geste.
//
// ⚠️ Piège de surface (mesuré en CR-LEX-77) : la surface de test fait 800 dp,
// donc un `SizedBox(width: 1200)` y serait ÉCRASÉ. Les gardes qui dépendent de
// la bascule liste/grille pompent une VRAIE fenêtre (`tester.view.physicalSize`)
// — sinon elles testeraient autre chose que ce qu'elles croient.
//
// Gardes :
//   G1 : chemin GRILLE — une poignée VISIBLE par cellule (le manque du §1) ;
//   G2 : chemin GRILLE — le libellé sémantique INJECTÉ est réellement PORTÉ ;
//   G3 : chemin GRILLE — cible ≥ 48 dp (AD-13) ;
//   G4 : `reorderHandleIcon` injecté rendu sur les DEUX chemins (§2) ;
//   G5 : DÉFAUT `Icons.drag_handle` préservé sur les DEUX chemins ;
//   G6 : chemin LISTE non régressé (`ReorderableDragStartListener` + drag réel) ;
//   G7 : CONTRÔLE NÉGATIF — une grille NON réordonnable ne gagne aucune poignée.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

const String kHandleLabel = 'REORDONNER-XYZ';
const IconData kInjectedIcon = Icons.drag_handle_rounded;
const double kMinItemWidth = 220;

/// Ids des items rendus (4 ⇒ 2 lignes à 1200 dp / 220 dp plafonné à 3).
const List<String> kIds = <String>['a', 'b', 'c', 'd'];

ZStudyToolsSectionSpec _spec({
  required bool reorderable,
  double? crossAxisMinItemWidth,
  String? handleLabel,
  IconData? handleIcon,
}) =>
    ZStudyToolsSectionSpec(
      id: 'docs',
      title: 'Documents',
      itemCount: kIds.length,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item_${kIds[i]}'),
        child: Center(child: Text(kIds[i])),
      ),
      emptyState: const Text('vide'),
      itemIds: reorderable ? kIds : null,
      onReorder: reorderable ? (_, _) {} : null,
      reorderHandleSemanticLabel: handleLabel,
      reorderHandleIcon: handleIcon,
      crossAxisMinItemWidth: crossAxisMinItemWidth,
      crossAxisItemHeight: 80,
    );

Future<void> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[spec]),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // ── § 1 — l'affordance sur le chemin GRILLE ────────────────────────────────
  group('CR-LEX-79 §1 — chemin GRILLE', () {
    testWidgets('G1 : une poignée VISIBLE par cellule (0 auparavant)',
        (tester) async {
      await _pump(
        tester,
        _spec(reorderable: true, crossAxisMinItemWidth: kMinItemWidth),
      );
      // Le rendu EST bien la grille (et non la liste) : aucune poignée de
      // `ReorderableListView` n'est montée — sans ce contrôle, la garde
      // passerait sur le chemin liste et ne prouverait rien.
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(
        find.byIcon(Icons.drag_handle),
        findsNWidgets(kIds.length),
        reason: 'mesure lex : « Found 0 widgets with icon » sur ce chemin',
      );
    });

    testWidgets('G2 : le libellé sémantique INJECTÉ est réellement PORTÉ',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _spec(
          reorderable: true,
          crossAxisMinItemWidth: kMinItemWidth,
          handleLabel: kHandleLabel,
        ),
      );
      expect(find.bySemanticsLabel(kHandleLabel), findsNWidgets(kIds.length));
      handle.dispose();
    });

    testWidgets('G2b : sans libellé injecté, repli documenté sur le TITRE',
        (tester) async {
      final handle = tester.ensureSemantics();
      // Le titre de section est aussi porté ailleurs (en-tête) : on mesure donc
      // le DELTA entre grille réordonnable et grille ordinaire — seul le delta
      // est imputable aux poignées.
      await _pump(
        tester,
        _spec(reorderable: false, crossAxisMinItemWidth: kMinItemWidth),
      );
      final int baseline = find.bySemanticsLabel('Documents').evaluate().length;
      await _pump(
        tester,
        _spec(reorderable: true, crossAxisMinItemWidth: kMinItemWidth),
      );
      expect(
        find.bySemanticsLabel('Documents').evaluate().length - baseline,
        kIds.length,
        reason: 'une poignée par cellule, repliée sur le titre',
      );
      handle.dispose();
    });

    testWidgets('G3 : cible de la poignée ≥ 48 dp (AD-13)', (tester) async {
      await _pump(
        tester,
        _spec(reorderable: true, crossAxisMinItemWidth: kMinItemWidth),
      );
      final Size size = tester.getSize(find.byIcon(Icons.drag_handle).first);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('G7 : CONTRÔLE NÉGATIF — grille NON réordonnable inchangée',
        (tester) async {
      // Prouve que la décoration est confinée au chemin réordonnable : une
      // grille ordinaire ne gagne AUCUNE poignée (rendu strictement d'avant).
      await _pump(
        tester,
        _spec(reorderable: false, crossAxisMinItemWidth: kMinItemWidth),
      );
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.byIcon(kInjectedIcon), findsNothing);
    });
  });

  // ── § 2 — glyphe INJECTABLE, sur les DEUX chemins ──────────────────────────
  group('CR-LEX-79 §2 — reorderHandleIcon', () {
    testWidgets('G4a : glyphe injecté rendu — chemin GRILLE', (tester) async {
      await _pump(
        tester,
        _spec(
          reorderable: true,
          crossAxisMinItemWidth: kMinItemWidth,
          handleIcon: kInjectedIcon,
        ),
      );
      expect(find.byIcon(kInjectedIcon), findsNWidgets(kIds.length));
      expect(find.byIcon(Icons.drag_handle), findsNothing,
          reason: 'le glyphe injecté REMPLACE le repli, il ne s\'y ajoute pas');
    });

    testWidgets('G4b : glyphe injecté rendu — chemin LISTE', (tester) async {
      await _pump(tester, _spec(reorderable: true, handleIcon: kInjectedIcon));
      expect(find.byType(ReorderableDragStartListener),
          findsNWidgets(kIds.length));
      expect(find.byIcon(kInjectedIcon), findsNWidgets(kIds.length));
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('G5 : DÉFAUT `Icons.drag_handle` préservé (les DEUX chemins)',
        (tester) async {
      // Non-régression stricte : un hôte qui n'injecte rien voit EXACTEMENT le
      // rendu d'avant CR-LEX-79 sur le chemin liste.
      await _pump(tester, _spec(reorderable: true));
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(kIds.length));
      expect(find.byIcon(kInjectedIcon), findsNothing);

      await _pump(
        tester,
        _spec(reorderable: true, crossAxisMinItemWidth: kMinItemWidth),
      );
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(kIds.length));
      expect(find.byIcon(kInjectedIcon), findsNothing);
    });
  });

  // ── Non-régression du chemin LISTE ─────────────────────────────────────────
  group('CR-LEX-79 — chemin LISTE non régressé', () {
    testWidgets('G6 : poignée SDK conservée et drag réel toujours notifié',
        (tester) async {
      final List<List<int>> moves = <List<int>>[];
      final spec = ZStudyToolsSectionSpec(
        id: 'docs',
        title: 'Documents',
        itemCount: kIds.length,
        itemBuilder: (context, i) => SizedBox(
          key: ValueKey<String>('item_${kIds[i]}'),
          height: 60,
          child: Center(child: Text(kIds[i])),
        ),
        emptyState: const Text('vide'),
        itemIds: kIds,
        onReorder: (o, n) => moves.add(<int>[o, n]),
        reorderHandleSemanticLabel: kHandleLabel,
      );
      await _pump(tester, spec);
      expect(find.byType(ReorderableDragStartListener),
          findsNWidgets(kIds.length));

      // Glisser DEPUIS LA POIGNÉE (et non depuis la cellule) : c'est la
      // propriété propre au chemin liste, qui doit survivre à CR-LEX-79.
      final Finder firstHandle = find.byIcon(Icons.drag_handle).first;
      final gesture = await tester.startGesture(tester.getCenter(firstHandle));
      await tester.pump(kLongPressTimeout);
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, isNotEmpty, reason: 'le drag depuis la poignée doit notifier');
    });
  });
}
