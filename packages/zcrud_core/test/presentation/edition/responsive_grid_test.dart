// AC12..AC14 — Grille responsive 12 colonnes. Span par breakpoint, reflow au
// dépassement de 12, défaut pleine largeur, directionnel/RTL.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZResponsiveSpan (cascade mobile-first + bornage)', () {
    test('défaut = 12 partout', () {
      const s = ZResponsiveSpan();
      for (final bp in ZBreakpoint.values) {
        expect(s.spanAt(bp), 12);
      }
    });

    test('cascade : un cran non fourni hérite du cran inférieur', () {
      const s = ZResponsiveSpan(xs: 12, md: 6, xl: 3);
      expect(s.spanAt(ZBreakpoint.xs), 12);
      expect(s.spanAt(ZBreakpoint.sm), 12); // hérite xs
      expect(s.spanAt(ZBreakpoint.md), 6);
      expect(s.spanAt(ZBreakpoint.lg), 6); // hérite md
      expect(s.spanAt(ZBreakpoint.xl), 3);
    });

    test('bornage défensif dans [1, 12]', () {
      expect(const ZResponsiveSpan(xs: 0).spanAt(ZBreakpoint.xs), 1);
      expect(const ZResponsiveSpan(xs: 99).spanAt(ZBreakpoint.xs), 12);
    });
  });

  group('ZResponsiveBreakpoints.of (seuils Bootstrap)', () {
    test('résolution par seuil', () {
      expect(ZResponsiveBreakpoints.of(500), ZBreakpoint.xs);
      expect(ZResponsiveBreakpoints.of(576), ZBreakpoint.sm);
      expect(ZResponsiveBreakpoints.of(768), ZBreakpoint.md);
      expect(ZResponsiveBreakpoints.of(992), ZBreakpoint.lg);
      expect(ZResponsiveBreakpoints.of(1200), ZBreakpoint.xl);
      expect(ZResponsiveBreakpoints.of(1400), ZBreakpoint.xl);
    });
  });

  // Trois champs de 6 colonnes chacun : 6+6 tiennent sur une ligne (=12), le 3e
  // reflow. On mesure la largeur des cellules aux 5 breakpoints.
  const fields = <ZFieldSpec>[
    ZFieldSpec(name: 'g0', type: EditionFieldType.text, label: 'G0'),
    ZFieldSpec(name: 'g1', type: EditionFieldType.text, label: 'G1'),
    ZFieldSpec(name: 'g2', type: EditionFieldType.text, label: 'G2'),
  ];

  // Fixe la largeur RÉELLE de la surface de test (le conteneur `LayoutBuilder`
  // de la grille lit `constraints.maxWidth` = largeur d'écran ici). Un `SizedBox`
  // serait sinon écrêté par la surface par défaut (800 dp).
  void setWidth(WidgetTester tester, double width, [double height = 2000]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(
    ZFormController controller, {
    required Map<String, ZResponsiveSpan> layout,
    TextDirection textDirection = TextDirection.ltr,
    double gutter = 0,
  }) =>
      MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: fields,
              shrinkWrap: true,
              layout: layout,
              gridGutter: gutter,
            ),
          ),
        ),
      );

  ZFormController ctrl() => ZFormController(
        initialValues: const <String, Object?>{'g0': '', 'g1': '', 'g2': ''},
        visibleFields: const <String>['g0', 'g1', 'g2'],
      );

  double cellWidth(WidgetTester tester, String name) =>
      tester.getSize(find.byKey(ValueKey<String>(name))).width;

  testWidgets('AC12 — span 6/12 ⇒ demi-largeur ; reflow au-delà de 12 '
      '(gutter 0)', (tester) async {
    final controller = ctrl();
    addTearDown(controller.dispose);
    const layout = <String, ZResponsiveSpan>{
      'g0': ZResponsiveSpan.all(6),
      'g1': ZResponsiveSpan.all(6),
      'g2': ZResponsiveSpan.all(6),
    };
    // Largeur 1000 → breakpoint lg. gutter 0 ⇒ colonne = 1000/12.
    setWidth(tester, 1000);
    await tester.pumpWidget(app(controller, layout: layout));
    await tester.pumpAndSettle();

    final expected = 1000.0 / 12 * 6; // 500
    expect(cellWidth(tester, 'g0'), closeTo(expected, 0.5));
    expect(cellWidth(tester, 'g1'), closeTo(expected, 0.5));

    // Reflow : g0+g1 = 12 colonnes sur la 1re ligne ; g2 passe à la ligne 2.
    final y0 = tester.getTopLeft(find.byKey(const ValueKey<String>('g0'))).dy;
    final y2 = tester.getTopLeft(find.byKey(const ValueKey<String>('g2'))).dy;
    expect(y2, greaterThan(y0), reason: 'g2 reflow sous la 1re ligne');
  });

  testWidgets('AC12 — span responsif par breakpoint (xs..xl)', (tester) async {
    final controller = ctrl();
    addTearDown(controller.dispose);
    // g0 : pleine largeur en xs, demi en md, tiers en xl.
    const layout = <String, ZResponsiveSpan>{
      'g0': ZResponsiveSpan(xs: 12, md: 6, xl: 4),
    };

    // 5 largeurs, une par breakpoint (gutter 0 pour une mesure exacte).
    final cases = <ZBreakpoint, double>{
      ZBreakpoint.xs: 500,
      ZBreakpoint.sm: 600,
      ZBreakpoint.md: 800,
      ZBreakpoint.lg: 1000,
      ZBreakpoint.xl: 1300,
    };
    final expectedSpan = <ZBreakpoint, int>{
      ZBreakpoint.xs: 12,
      ZBreakpoint.sm: 12, // hérite xs
      ZBreakpoint.md: 6,
      ZBreakpoint.lg: 6, // hérite md
      ZBreakpoint.xl: 4,
    };

    for (final entry in cases.entries) {
      final width = entry.value;
      setWidth(tester, width);
      await tester.pumpWidget(app(controller, layout: layout));
      await tester.pumpAndSettle();
      final span = expectedSpan[entry.key]!;
      final expected = width / 12 * span;
      expect(cellWidth(tester, 'g0'), closeTo(expected, 0.6),
          reason: 'breakpoint ${entry.key.name} (w=$width) ⇒ span $span');
    }
  });

  testWidgets('AC13 — champ sans span déclaré = pleine largeur (12)',
      (tester) async {
    final controller = ctrl();
    addTearDown(controller.dispose);
    // layout non vide (active la grille) mais g0 non listé ⇒ défaut 12.
    const layout = <String, ZResponsiveSpan>{
      'g1': ZResponsiveSpan.all(6),
    };
    setWidth(tester, 1000);
    await tester.pumpWidget(app(controller, layout: layout));
    await tester.pumpAndSettle();
    expect(cellWidth(tester, 'g0'), closeTo(1000.0, 0.5),
        reason: 'défaut = pleine largeur');
  });

  testWidgets('AC14 — grille RTL sans overflow/exception + ordre de lecture',
      (tester) async {
    final controller = ctrl();
    addTearDown(controller.dispose);
    const layout = <String, ZResponsiveSpan>{
      'g0': ZResponsiveSpan.all(6),
      'g1': ZResponsiveSpan.all(6),
    };
    setWidth(tester, 1000);
    await tester.pumpWidget(app(
      controller,
      layout: layout,
      textDirection: TextDirection.rtl,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Sous RTL, la 1re cellule (g0) est du côté DROIT (start = droite).
    final x0 = tester.getTopLeft(find.byKey(const ValueKey<String>('g0'))).dx;
    final x1 = tester.getTopLeft(find.byKey(const ValueKey<String>('g1'))).dx;
    expect(x0, greaterThan(x1),
        reason: 'RTL : g0 (start) à droite de g1 (suivant)');

    // Bascule LTR : g0 repasse à gauche (aucune exception).
    await tester.pumpWidget(app(controller, layout: layout));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final x0Ltr = tester.getTopLeft(find.byKey(const ValueKey<String>('g0'))).dx;
    final x1Ltr = tester.getTopLeft(find.byKey(const ValueKey<String>('g1'))).dx;
    expect(x0Ltr, lessThan(x1Ltr), reason: 'LTR : g0 (start) à gauche');
  });
}
