// CHAÎNE `paramètre > jeton > référence` de `ZCollapsibleSection`.
//
// Ce que cette garde mesure : la valeur **peinte** au site de rendu, jamais le
// passage du jeton. Chaque jeton porte donc trois assertions —
//  1. sans jeton posé, la valeur de RÉFÉRENCE (inertie) ;
//  2. jeton posé, la valeur DU JETON ;
//  3. spec ET jeton posés, la valeur de la SPEC (le paramètre prime).
//
// Les valeurs d'épreuve sont choisies DISTINCTES de la référence : un jeton
// qui vaudrait déjà la référence rendrait l'assertion vacante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _host({
  ZcrudTheme theme = const ZcrudTheme(),
  ZCollapsibleSectionSpec? spec,
  bool expanded = true,
  int? count = 3,
  IconData? leadingIcon = Icons.calendar_month_rounded,
}) =>
    ZcrudScope(
      theme: theme,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZCollapsibleSection(
              title: 'T',
              count: count,
              leadingIcon: leadingIcon,
              initiallyExpanded: expanded,
              spec: spec,
              child: const SizedBox(height: 20),
            ),
          ),
        ),
      ),
    );

Material _mat(WidgetTester tester, Key key) =>
    tester.widget<Material>(find.byKey(key));

RoundedRectangleBorder _headerShape(WidgetTester tester) =>
    _mat(tester, ZCollapsibleSection.headerKey).shape!
        as RoundedRectangleBorder;

BoxDecoration _bodyDeco(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(ZCollapsibleSection.bodyKey)).decoration!
        as BoxDecoration;

BoxDecoration _pillDeco(WidgetTester tester) => tester
    .widget<Container>(
      find.ancestor(of: find.text('3'), matching: find.byType(Container)).first,
    )
    .decoration! as BoxDecoration;

BoxDecoration _discDeco(WidgetTester tester) => tester
    .widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.calendar_month_rounded),
            matching: find.byType(Container),
          )
          .first,
    )
    .decoration! as BoxDecoration;

double _topRadius(RoundedRectangleBorder shape) =>
    shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;

void main() {
  group('élévations', () {
    testWidgets('référence : 8 déplié / 0 replié', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(_mat(tester, ZCollapsibleSection.headerKey).elevation, 8);
      expect(_mat(tester, ZCollapsibleSection.containerKey).elevation, 0);
    });

    testWidgets('jeton : les deux élévations suivent', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionExpandedElevation: 3,
          collapsibleSectionCollapsedElevation: 1,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_mat(tester, ZCollapsibleSection.headerKey).elevation, 3);
      expect(_mat(tester, ZCollapsibleSection.containerKey).elevation, 1);
    });

    testWidgets('paramètre > jeton', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionExpandedElevation: 3,
          collapsibleSectionCollapsedElevation: 1,
        ),
        spec: const ZCollapsibleSectionSpec(
          expandedElevation: 12,
          collapsedElevation: 2,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_mat(tester, ZCollapsibleSection.headerKey).elevation, 12);
      expect(_mat(tester, ZCollapsibleSection.containerKey).elevation, 2);
    });
  });

  group('rayon et filet du contour', () {
    testWidgets('référence : rayon 12, filet à 0,6 de `dividerColor`',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final RoundedRectangleBorder shape = _headerShape(tester);
      expect(_topRadius(shape), 12);
      final BuildContext context = tester.element(find.text('T'));
      expect(
        shape.side.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.6),
      );
    });

    testWidgets('jeton : rayon et opacité du filet suivent',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionCornerRadius: 4,
          collapsibleSectionBorderAlpha: 0.25,
        ),
      ));
      await tester.pumpAndSettle();
      final RoundedRectangleBorder shape = _headerShape(tester);
      expect(_topRadius(shape), 4);
      final BuildContext context = tester.element(find.text('T'));
      expect(
        shape.side.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.25),
      );
    });

    testWidgets('paramètre > jeton', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionCornerRadius: 4,
          collapsibleSectionBorderAlpha: 0.25,
        ),
        spec: const ZCollapsibleSectionSpec(
          cornerRadius: 20,
          borderAlpha: 0.9,
        ),
      ));
      await tester.pumpAndSettle();
      final RoundedRectangleBorder shape = _headerShape(tester);
      expect(_topRadius(shape), 20);
      final BuildContext context = tester.element(find.text('T'));
      expect(
        shape.side.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.9),
      );
    });
  });

  group('corps', () {
    testWidgets('référence : coins bas 10, filet supérieur à 0,2',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final BoxDecoration deco = _bodyDeco(tester);
      expect(
        (deco.borderRadius! as BorderRadius).bottomLeft,
        const Radius.circular(10),
      );
      final BuildContext context = tester.element(find.text('T'));
      expect(
        deco.border!.top.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.2),
      );
    });

    testWidgets('jeton : coins bas et filet supérieur suivent',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionBodyCornerRadius: 2,
          collapsibleSectionBodyBorderAlpha: 0.8,
        ),
      ));
      await tester.pumpAndSettle();
      final BoxDecoration deco = _bodyDeco(tester);
      expect(
        (deco.borderRadius! as BorderRadius).bottomLeft,
        const Radius.circular(2),
      );
      final BuildContext context = tester.element(find.text('T'));
      expect(
        deco.border!.top.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.8),
      );
    });

    testWidgets('paramètre > jeton', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionBodyCornerRadius: 2,
          collapsibleSectionBodyBorderAlpha: 0.8,
        ),
        spec: const ZCollapsibleSectionSpec(
          bodyCornerRadius: 30,
          bodyBorderAlpha: 0.05,
        ),
      ));
      await tester.pumpAndSettle();
      final BoxDecoration deco = _bodyDeco(tester);
      expect(
        (deco.borderRadius! as BorderRadius).bottomLeft,
        const Radius.circular(30),
      );
      final BuildContext context = tester.element(find.text('T'));
      expect(
        deco.border!.top.color,
        Theme.of(context).dividerColor.withValues(alpha: 0.05),
      );
    });
  });

  group('durée du chevron', () {
    testWidgets('référence : 200 ms', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedRotation>(find.byKey(ZCollapsibleSection.chevronKey))
            .duration,
        const Duration(milliseconds: 200),
      );
    });

    testWidgets('jeton, puis paramètre', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionChevronDuration: Duration(milliseconds: 90),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedRotation>(find.byKey(ZCollapsibleSection.chevronKey))
            .duration,
        const Duration(milliseconds: 90),
      );

      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionChevronDuration: Duration(milliseconds: 90),
        ),
        spec: const ZCollapsibleSectionSpec(
          chevronDuration: Duration(milliseconds: 450),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedRotation>(find.byKey(ZCollapsibleSection.chevronKey))
            .duration,
        const Duration(milliseconds: 450),
      );
    });
  });

  group('disque de tête', () {
    testWidgets('référence : glyphe 20, fond à 0,1 de `primary`',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.text('T'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.calendar_month_rounded))
            .size,
        20,
      );
      expect(_discDeco(tester).color, scheme.primary.withValues(alpha: 0.1));
    });

    testWidgets('jeton : taille et opacité du fond suivent',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionLeadingIconSize: 33,
          collapsibleSectionLeadingBackgroundAlpha: 0.55,
        ),
      ));
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.text('T'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).size,
        33,
      );
      expect(_discDeco(tester).color, scheme.primary.withValues(alpha: 0.55));
    });

    testWidgets('paramètre > jeton', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(
          collapsibleSectionLeadingIconSize: 33,
          collapsibleSectionLeadingBackgroundAlpha: 0.55,
        ),
        spec: const ZCollapsibleSectionSpec(
          leadingIconSize: 14,
          leadingBackgroundAlpha: 0.2,
        ),
      ));
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.text('T'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).size,
        14,
      );
      expect(_discDeco(tester).color, scheme.primary.withValues(alpha: 0.2));
    });
  });

  group('pastille de compte', () {
    testWidgets('référence : rayon 12', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(
        (_pillDeco(tester).borderRadius! as BorderRadius).topLeft,
        const Radius.circular(12),
      );
    });

    testWidgets('jeton, puis paramètre', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(collapsibleSectionCountCornerRadius: 3),
      ));
      await tester.pumpAndSettle();
      expect(
        (_pillDeco(tester).borderRadius! as BorderRadius).topLeft,
        const Radius.circular(3),
      );

      await tester.pumpWidget(_host(
        theme: const ZcrudTheme(collapsibleSectionCountCornerRadius: 3),
        spec: const ZCollapsibleSectionSpec(countCornerRadius: 25),
      ));
      await tester.pumpAndSettle();
      expect(
        (_pillDeco(tester).borderRadius! as BorderRadius).topLeft,
        const Radius.circular(25),
      );
    });
  });

  group('inertie', () {
    testWidgets(
        'aucun jeton posé : chaque valeur peinte vaut celle de la référence',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(_mat(tester, ZCollapsibleSection.headerKey).elevation,
          ZCollapsibleSectionReference.expandedElevation);
      expect(_mat(tester, ZCollapsibleSection.containerKey).elevation,
          ZCollapsibleSectionReference.collapsedElevation);
      expect(_topRadius(_headerShape(tester)),
          ZCollapsibleSectionReference.cornerRadius);
      expect(
        (_bodyDeco(tester).borderRadius! as BorderRadius).bottomLeft,
        Radius.circular(ZCollapsibleSectionReference.bodyCornerRadius),
      );
      expect(
        (_pillDeco(tester).borderRadius! as BorderRadius).topLeft,
        Radius.circular(ZCollapsibleSectionReference.countCornerRadius),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).size,
        ZCollapsibleSectionReference.leadingIconSize,
      );
      expect(
        tester
            .widget<AnimatedRotation>(find.byKey(ZCollapsibleSection.chevronKey))
            .duration,
        ZCollapsibleSectionReference.chevronDuration,
      );
    });
  });

  group('ZCollapsibleSectionSpec — algèbre', () {
    test('`merge` donne la priorité à l\'autre, sans matérialiser de `null`',
        () {
      const ZCollapsibleSectionSpec base =
          ZCollapsibleSectionSpec(cornerRadius: 4, borderAlpha: 0.3);
      const ZCollapsibleSectionSpec over =
          ZCollapsibleSectionSpec(cornerRadius: 9);
      final ZCollapsibleSectionSpec merged = base.merge(over);
      expect(merged.cornerRadius, 9);
      expect(merged.borderAlpha, 0.3);
      expect(merged.bodyCornerRadius, isNull);
      expect(base.merge(null), same(base));
    });

    test('`copyWith` ne remet jamais un champ à `null`', () {
      const ZCollapsibleSectionSpec base =
          ZCollapsibleSectionSpec(cornerRadius: 4);
      expect(base.copyWith().cornerRadius, 4);
      expect(base.copyWith(cornerRadius: 7).cornerRadius, 7);
    });

    test('égalité structurelle', () {
      expect(
        const ZCollapsibleSectionSpec(cornerRadius: 4),
        const ZCollapsibleSectionSpec(cornerRadius: 4),
      );
      expect(
        const ZCollapsibleSectionSpec(cornerRadius: 4).hashCode,
        const ZCollapsibleSectionSpec(cornerRadius: 4).hashCode,
      );
      expect(
        const ZCollapsibleSectionSpec(cornerRadius: 4),
        isNot(const ZCollapsibleSectionSpec(cornerRadius: 5)),
      );
    });
  });

  group('jetons de thème — les 4 sites', () {
    test('`copyWith` transporte les dix jetons', () {
      const ZcrudTheme empty = ZcrudTheme();
      final ZcrudTheme full = empty.copyWith(
        collapsibleSectionExpandedElevation: 1,
        collapsibleSectionCollapsedElevation: 2,
        collapsibleSectionCornerRadius: 3,
        collapsibleSectionBorderAlpha: 0.4,
        collapsibleSectionBodyBorderAlpha: 0.5,
        collapsibleSectionBodyCornerRadius: 6,
        collapsibleSectionChevronDuration: const Duration(milliseconds: 7),
        collapsibleSectionLeadingIconSize: 8,
        collapsibleSectionLeadingBackgroundAlpha: 0.9,
        collapsibleSectionCountCornerRadius: 10,
      );
      expect(full.collapsibleSectionExpandedElevation, 1);
      expect(full.collapsibleSectionCollapsedElevation, 2);
      expect(full.collapsibleSectionCornerRadius, 3);
      expect(full.collapsibleSectionBorderAlpha, 0.4);
      expect(full.collapsibleSectionBodyBorderAlpha, 0.5);
      expect(full.collapsibleSectionBodyCornerRadius, 6);
      expect(full.collapsibleSectionChevronDuration,
          const Duration(milliseconds: 7));
      expect(full.collapsibleSectionLeadingIconSize, 8);
      expect(full.collapsibleSectionLeadingBackgroundAlpha, 0.9);
      expect(full.collapsibleSectionCountCornerRadius, 10);
    });

    test('`lerp` interpole, et `null`↔`null` reste `null`', () {
      const ZcrudTheme a = ZcrudTheme(
        collapsibleSectionCornerRadius: 0,
        collapsibleSectionChevronDuration: Duration.zero,
      );
      const ZcrudTheme b = ZcrudTheme(
        collapsibleSectionCornerRadius: 10,
        collapsibleSectionChevronDuration: Duration(milliseconds: 100),
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.collapsibleSectionCornerRadius, 5);
      expect(mid.collapsibleSectionChevronDuration,
          const Duration(milliseconds: 50));
      // Aucun jeton posé des deux côtés : la référence du consommateur n'est
      // JAMAIS matérialisée par une transition de thème.
      expect(
        const ZcrudTheme().lerp(const ZcrudTheme(), 0.5).collapsibleSectionCornerRadius,
        isNull,
      );
    });
  });
}
