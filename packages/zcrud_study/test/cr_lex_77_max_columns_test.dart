// CR-LEX-77 — `ZStudyToolsSectionSpec` n'exposait AUCUN plafond de colonnes,
// alors que la primitive `computeCrossAxisCount` (et donc `ZAdaptiveGrid` /
// `ZReorderableAdaptiveGrid`) acceptait DÉJÀ `maxColumns` : seul le câblage
// spec → grille manquait — même motif que CR-IFFD-11 §2 sur le paramètre voisin.
//
// ⚠️ Ce que lex a signalé et que ces gardes matérialisent : la perte serait
// SILENCIEUSE. Aucun test d'écran ne pompait au-dessus de 600 dp, largeur à
// laquelle le plafond NE MORD JAMAIS. Chaque garde de plafond pompe donc à
// 1200 dp (où il mord), et un CONTRÔLE POSITIF à 600 dp prouve qu'aucune de ces
// gardes ne passe par accident (à 600 dp, plafond ou pas, le compte est le même).
//
// Les TROIS chemins de grille sont gardés SÉPARÉMENT (eager / virtualisé /
// réordonnable) : couper le câblage d'un seul doit faire rougir SA garde et elle
// seule — c'est exactement l'écart « qui ne se verrait qu'à l'usage ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Mesure lex : `minItemWidth: 220`, plafond `3`. À 1200 dp ⇒ 3 colonnes avec
/// plafond, 5 sans (plafond porté à 99).
const double kMinItemWidth = 220;
const int kItemCount = 12;

/// Nombre d'items partageant la PREMIÈRE ligne rendue = nombre de colonnes.
///
/// Mesuré sur des **ordonnées réelles** (`getTopLeft().dy`), jamais sur une
/// présence : un plafond non honoré change le compte, pas la présence.
int _columnsOnFirstRow(WidgetTester tester) {
  final List<double> ys = <double>[];
  for (var i = 0; i < kItemCount; i++) {
    // `.first` : en mode réordonnable la cellule du socle porte la MÊME clé que
    // l'item (wrapper + enfant) — même origine, un seul point mesuré.
    final finder = find.byKey(ValueKey<String>('item_$i')).first;
    if (finder.evaluate().isEmpty) continue; // virtualisé : hors viewport
    ys.add(tester.getTopLeft(finder).dy);
  }
  expect(ys, isNotEmpty, reason: 'aucun item rendu : garde inopérante');
  final double first = ys.reduce((a, b) => a < b ? a : b);
  return ys.where((y) => (y - first).abs() < 0.5).length;
}

ZStudyToolsSectionSpec _spec({
  int? maxColumns,
  bool virtualized = false,
  bool reorderable = false,
}) {
  final ids = <String>[for (var i = 0; i < kItemCount; i++) 'item_$i'];
  return ZStudyToolsSectionSpec(
    id: 'docs',
    title: 'Documents',
    itemCount: kItemCount,
    itemBuilder: (context, i) => SizedBox(
      key: ValueKey<String>('item_$i'),
      child: Center(child: Text('$i')),
    ),
    emptyState: const Text('vide'),
    crossAxisMinItemWidth: kMinItemWidth,
    crossAxisItemHeight: 60,
    crossAxisMaxColumns: maxColumns,
    crossAxisVirtualized: virtualized,
    crossAxisViewportHeight: virtualized ? 400 : null,
    itemIds: reorderable ? ids : null,
    onReorder: reorderable ? (_, _) {} : null,
  );
}

Future<void> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  required double width,
}) async {
  // ⚠️ La surface de test fait 800 dp par défaut : un `SizedBox(width: 1200)`
  // y serait ÉCRASÉ à 800 et le plafond ne mordrait jamais — c'est exactement
  // l'angle mort que lex a signalé. On pompe donc une VRAIE fenêtre large.
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
  // ── Chemin 1/3 — grille EAGER ───────────────────────────────────────────────
  group('CR-LEX-77 — chemin EAGER', () {
    testWidgets('🔴 plafond 3 MORD à 1200 dp (sans lui : 5 colonnes)',
        (tester) async {
      await _pump(tester, _spec(maxColumns: 3), width: 1200);
      expect(_columnsOnFirstRow(tester), 3);
    });

    testWidgets('sans plafond (99), la MÊME largeur donne bien plus de colonnes',
        (tester) async {
      // Prouve que le 3 ci-dessus vient du PLAFOND, pas de la largeur.
      await _pump(tester, _spec(maxColumns: 99), width: 1200);
      expect(_columnsOnFirstRow(tester), 5);
    });

    testWidgets('null (défaut) ⇒ ILLIMITÉ, rendu strictement inchangé',
        (tester) async {
      await _pump(tester, _spec(), width: 1200);
      final int unlimited = _columnsOnFirstRow(tester);
      expect(unlimited, greaterThan(3), reason: 'défaut = aucun plafond');
      await _pump(tester, _spec(maxColumns: 99), width: 1200);
      expect(_columnsOnFirstRow(tester), unlimited);
    });

    testWidgets('CONTRÔLE POSITIF — à 600 dp le plafond NE MORD PAS',
        (tester) async {
      // Largeur à laquelle les tests d'écran de lex pompaient : le plafond y est
      // inopérant. Si cette garde échouait, les gardes à 1200 dp passeraient par
      // accident.
      await _pump(tester, _spec(), width: 600);
      final int withoutCap = _columnsOnFirstRow(tester);
      await _pump(tester, _spec(maxColumns: 3), width: 600);
      expect(_columnsOnFirstRow(tester), withoutCap);
      expect(withoutCap, lessThan(3));
    });

    testWidgets('AD-10 — plafond absurde (0 / négatif) ⇒ repli PLANCHER (1)',
        (tester) async {
      // Aligné sur `computeCrossAxisCount` : `maxColumns < minColumns` est
      // REMONTÉ au plancher. Jamais de grille vide, jamais de throw.
      for (final int absurd in <int>[0, -7]) {
        await _pump(tester, _spec(maxColumns: absurd), width: 1200);
        expect(_columnsOnFirstRow(tester), 1, reason: 'maxColumns=$absurd');
        expect(find.byKey(const ValueKey<String>('item_0')), findsOneWidget,
            reason: 'grille NON vide (AD-10)');
      }
    });
  });

  // ── Chemin 2/3 — grille VIRTUALISÉE ─────────────────────────────────────────
  group('CR-LEX-77 — chemin VIRTUALISÉ', () {
    testWidgets('🔴 plafond 3 MORD à 1200 dp', (tester) async {
      await _pump(tester, _spec(maxColumns: 3, virtualized: true), width: 1200);
      expect(_columnsOnFirstRow(tester), 3);
    });

    testWidgets('sans plafond (99) ⇒ plus de colonnes à la même largeur',
        (tester) async {
      await _pump(tester, _spec(maxColumns: 99, virtualized: true), width: 1200);
      expect(_columnsOnFirstRow(tester), 5);
    });

    testWidgets('CONTRÔLE POSITIF — à 600 dp le plafond NE MORD PAS',
        (tester) async {
      await _pump(tester, _spec(virtualized: true), width: 600);
      final int withoutCap = _columnsOnFirstRow(tester);
      await _pump(tester, _spec(maxColumns: 3, virtualized: true), width: 600);
      expect(_columnsOnFirstRow(tester), withoutCap);
      expect(withoutCap, lessThan(3));
    });
  });

  // ── Chemin 3/3 — grille RÉORDONNABLE ────────────────────────────────────────
  group('CR-LEX-77 — chemin RÉORDONNABLE', () {
    testWidgets('🔴 plafond 3 MORD à 1200 dp', (tester) async {
      await _pump(tester, _spec(maxColumns: 3, reorderable: true), width: 1200);
      expect(_columnsOnFirstRow(tester), 3);
    });

    testWidgets('sans plafond (99) ⇒ plus de colonnes à la même largeur',
        (tester) async {
      await _pump(tester, _spec(maxColumns: 99, reorderable: true), width: 1200);
      expect(_columnsOnFirstRow(tester), 5);
    });

    testWidgets('CONTRÔLE POSITIF — à 600 dp le plafond NE MORD PAS',
        (tester) async {
      await _pump(tester, _spec(reorderable: true), width: 600);
      final int withoutCap = _columnsOnFirstRow(tester);
      await _pump(tester, _spec(maxColumns: 3, reorderable: true), width: 600);
      expect(_columnsOnFirstRow(tester), withoutCap);
      expect(withoutCap, lessThan(3));
    });
  });
}
