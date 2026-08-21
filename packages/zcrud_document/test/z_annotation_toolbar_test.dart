/// Tests de `ZAnnotationToolbar` (ES-8.2) — **pouvoir discriminant** (R12) sur le
/// CŒUR WCAG (AD-13) : couleur jamais seul canal (AC3), marqueur STRUCTUREL de
/// sélection (AC4), contraste MESURÉ (AC5), cibles ≥ 48 dp (AC6), `Semantics`
/// explicites (AC7), isolation SM-1 (AC8), RTL (AC10), injection couleur/libellé
/// (AC11), défensif (AC12). Les ACs a11y assèrent des propriétés STRUCTURELLES
/// OBSERVABLES (nœuds `Semantics` RÉELS, contraste CALCULÉ, tailles MESURÉES,
/// clés STRUCTURELLES) — jamais la seule présence d'un widget (R20/R24).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Helper LOCAL (D6) : ratio de contraste WCAG 2.1 (luminance relative via
/// `Color.computeLuminance`). Résultat dans `[1, 21]`.
///
/// Oracle INDÉPENDANT du socle : il délègue au SDK là où `zContrastRatio`
/// linéarise lui-même. Il reste ici — et seulement ici, dans `test/` — pour
/// que les assertions de contraste ne soient pas tautologiques.
double wcagContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _wrap(
  Widget child, {
  ZcrudLabels? labels,
  ZColorKeyResolver? colorKeyResolver,
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: ZcrudScope(
          labels: labels,
          colorKeyResolver: colorKeyResolver,
          child: Scaffold(body: child),
        ),
      ),
    );

ValueKey<String> _swatchKey(String colorKey) =>
    ValueKey<String>('$kAnnotationSwatchKeyPrefix$colorKey');
ValueKey<String> _swatchFillKey(String colorKey) =>
    ValueKey<String>('$kAnnotationSwatchFillKeyPrefix$colorKey');
ValueKey<String> _kindKey(ZDocumentAnnotationKind kind) =>
    ValueKey<String>('$kAnnotationKindKeyPrefix${kind.name}');

void main() {
  group('🔴 ÉQUIVALENCE — le calculateur privé supprimé rendait EXACTEMENT ce '
      'que rend le socle', () {
    // Le fichier portait un `_wcagContrastRatio` privé bâti sur
    // `Color.computeLuminance()` ; il a été supprimé au profit de
    // `zContrastRatio` (zcrud_core). Cette garde est ce qui AUTORISE la
    // suppression : sans elle, « rendu inchangé » serait une affirmation.
    // L'oracle est `wcagContrastRatio` ci-dessus, copie mot à mot du supprimé.
    test('bit à bit sur un échantillon couvrant les DEUX côtés du plancher',
        () {
      final List<Color> tints = <Color>[
        for (int r = 0; r <= 255; r += 15)
          for (int g = 0; g <= 255; g += 51)
            for (int b = 0; b <= 255; b += 85) Color.fromARGB(255, r, g, b),
        const Color(0xFFFF9800),
        const Color(0xFFFFFF00),
        const Color(0xFF667EEA),
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        const Color(0xFF080808),
        const Color(0xFF0A0A0A),
        const Color(0x80FF9800),
      ];
      const List<Color> surfaces = <Color>[
        Color(0xFFFFFFFF),
        Color(0xFFFEF7FF),
        Color(0xFF1C1B1F),
        Color(0xFF000000),
      ];
      double worstDelta = 0;
      int compared = 0;
      int below = 0;
      int above = 0;
      int floorDisagreements = 0;
      for (final Color tint in tints) {
        for (final Color surface in surfaces) {
          compared++;
          final double sdk = wcagContrastRatio(tint, surface);
          final double core = zContrastRatio(tint, surface);
          final double delta = (sdk - core).abs();
          if (delta > worstDelta) worstDelta = delta;
          if (sdk < kZNonTextMinContrast) {
            below++;
          } else {
            above++;
          }
          for (final double floor in <double>[
            kZNonTextMinContrast,
            kZTextMinContrast,
          ]) {
            if ((sdk >= floor) != (core >= floor)) floorDisagreements++;
          }
        }
      }
      // L'échantillon DOIT couvrir les deux côtés du plancher, sinon la
      // comparaison ne dirait rien de la décision qui en dépend.
      expect(below, greaterThan(50),
          reason: '🔴 ÉCHANTILLON DÉGÉNÉRÉ : rien sous le plancher');
      expect(above, greaterThan(50),
          reason: '🔴 ÉCHANTILLON DÉGÉNÉRÉ : rien au-dessus du plancher');
      expect(compared, greaterThan(500));
      expect(worstDelta, 0.0,
          reason: '🔴 DIVERGENCE : `Color.computeLuminance()` et '
              '`zRelativeLuminance` ne rendent plus le même chiffre '
              '(écart max $worstDelta sur $compared couples) — la suppression '
              'du calculateur privé changerait alors le rendu.');
      expect(floorDisagreements, 0,
          reason: '🔴 les deux implémentations ne classent plus les mêmes '
              'couples du même côté du plancher');
    });

    test('la luminance relative elle-même coïncide, canal par canal', () {
      double worst = 0;
      int compared = 0;
      for (int v = 0; v <= 255; v++) {
        for (final Color c in <Color>[
          Color.fromARGB(255, v, 0, 0),
          Color.fromARGB(255, 0, v, 0),
          Color.fromARGB(255, 0, 0, v),
          Color.fromARGB(255, v, v, v),
        ]) {
          compared++;
          final double d = (c.computeLuminance() - zRelativeLuminance(c)).abs();
          if (d > worst) worst = d;
        }
      }
      expect(compared, 1024);
      expect(worst, 0.0,
          reason: '🔴 la linéarisation sRGB du socle a divergé de celle du '
              'SDK (écart max $worst) — dont le seuil 0.03928 et l\'exposant '
              '2.4.');
    });
  });

  group('AC1 — sélection de kind : un bouton par constante + mapping exact', () {
    testWidgets('taper le bouton k appelle onKindSelected(k) — pour chaque k',
        (tester) async {
      final captured = <ZDocumentAnnotationKind>[];
      await tester.pumpWidget(_wrap(
        ZAnnotationToolbar(onKindSelected: captured.add),
      ));
      // Exactement un bouton par constante (jamais un kind codé en dur).
      for (final kind in ZDocumentAnnotationKind.values) {
        expect(find.byKey(_kindKey(kind)), findsOneWidget);
      }
      for (final kind in ZDocumentAnnotationKind.values) {
        await tester.tap(find.byKey(_kindKey(kind)));
        await tester.pump();
        expect(captured.last, kind,
            reason: 'le bouton $kind doit noter le kind $kind (mapping D1)');
      }
      expect(captured, ZDocumentAnnotationKind.values);
    });
  });

  group('AC2 — palette de colorKey injectée, remontée BRUTE', () {
    testWidgets('une swatch par palette.keys ; onColorSelected(clé BRUTE)',
        (tester) async {
      const palette = ZColorPalette.defaultStudy();
      final captured = <String>[];
      await tester.pumpWidget(_wrap(
        ZAnnotationToolbar(palette: palette, onColorSelected: captured.add),
      ));
      for (final key in palette.keys) {
        expect(find.byKey(_swatchKey(key)), findsOneWidget);
      }
      // Nombre de swatches == palette.keys.length (ni plus, ni moins).
      expect(find.byKey(_swatchFillKey('warning')), findsOneWidget);
      await tester.tap(find.byKey(_swatchKey('warning')));
      await tester.pump();
      expect(captured.single, 'warning',
          reason: 'la clé BRUTE String est remontée (jamais index/Color/remap)');
    });
  });

  group('AC3 — CŒUR WCAG : Semantics.label DISTINCT et NON vide par swatch', () {
    testWidgets('deux couleurs identiques restent distinguables sans la voir',
        (tester) async {
      // Le resolver rend la MÊME Color (gris) pour DEUX colorKey différentes.
      const grey = ZColorPair(
        color: Color(0xFF808080),
        onColor: Color(0xFF000000),
      );
      await tester.pumpWidget(_wrap(
        const ZAnnotationToolbar(),
        colorKeyResolver: (scheme, key) =>
            (key == 'primary' || key == 'secondary') ? grey : null,
      ));
      final handle = tester.ensureSemantics();
      final labelPrimary =
          tester.getSemantics(find.byKey(_swatchKey('primary'))).label;
      final labelSecondary =
          tester.getSemantics(find.byKey(_swatchKey('secondary'))).label;
      expect(labelPrimary, isNotEmpty);
      expect(labelSecondary, isNotEmpty);
      expect(labelPrimary, isNot(equals(labelSecondary)),
          reason:
              'la distinction ne doit PAS passer par la seule couleur (INJ R3-1)');
      handle.dispose();
    });
  });

  group('AC4 — CŒUR WCAG : marqueur STRUCTUREL non-coloré de sélection (R24)',
      () {
    testWidgets('marqueur keyé présent UNIQUEMENT dans la swatch sélectionnée',
        (tester) async {
      final controller = ZAnnotationToolController(initialColorKey: 'success');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(
        ZAnnotationToolbar(controller: controller),
      ));
      final marker =
          find.byKey(const ValueKey<String>(kAnnotationSelectedMarkerKey));
      expect(marker, findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_swatchKey('success')), matching: marker),
        findsOneWidget,
        reason: 'le marqueur vit dans la swatch sélectionnée',
      );
      expect(
        find.descendant(of: find.byKey(_swatchKey('primary')), matching: marker),
        findsNothing,
      );
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.byKey(_swatchKey('success'))),
          containsSemantics(isSelected: true));
      expect(tester.getSemantics(find.byKey(_swatchKey('primary'))),
          containsSemantics(isSelected: false));
      handle.dispose();
    });
  });

  group('AC5 — CŒUR WCAG : contraste MESURÉ du marqueur sur la swatch ≥ 3.0',
      () {
    testWidgets('marqueur dérivé : ratio ≥ 3 même sur une swatch CLAIRE',
        (tester) async {
      final controller = ZAnnotationToolController(initialColorKey: 'success');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(
        ZAnnotationToolbar(controller: controller),
        // Swatch claire connue.
        colorKeyResolver: (scheme, key) => key == 'success'
            ? const ZColorPair(
                color: Color(0xFFEEEEEE), onColor: Color(0xFF111111))
            : null,
      ));
      final swatchColor =
          tester.widget<ColoredBox>(find.byKey(_swatchFillKey('success'))).color;
      final markerColor = tester
          .widget<Icon>(
              find.byKey(const ValueKey<String>(kAnnotationSelectedMarkerKey)))
          .color!;
      expect(swatchColor, const Color(0xFFEEEEEE));
      expect(wcagContrastRatio(markerColor, swatchColor),
          greaterThanOrEqualTo(3.0),
          reason: 'un marqueur Colors.white en dur rougirait ici (INJ R3-3)');
    });
  });

  group('AC6 — WCAG : cibles interactives ≥ 48 dp', () {
    testWidgets('chaque bouton kind et chaque swatch mesure ≥ 48×48 dp',
        (tester) async {
      const palette = ZColorPalette.defaultStudy();
      await tester.pumpWidget(_wrap(const ZAnnotationToolbar(palette: palette)));
      for (final kind in ZDocumentAnnotationKind.values) {
        final size = tester.getSize(find.byKey(_kindKey(kind)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      for (final key in palette.keys) {
        final size = tester.getSize(find.byKey(_swatchKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: 'swatch $key < 48');
        expect(size.height, greaterThanOrEqualTo(48), reason: 'swatch $key < 48');
      }
    });
  });

  group('AC7 — WCAG : Semantics explicites (button + label non vide)', () {
    testWidgets('chaque cible expose un nœud Semantics button avec label',
        (tester) async {
      final handle = tester.ensureSemantics();
      const palette = ZColorPalette.defaultStudy();
      await tester.pumpWidget(_wrap(const ZAnnotationToolbar(palette: palette)));
      for (final kind in ZDocumentAnnotationKind.values) {
        final finder = find.byKey(_kindKey(kind));
        expect(tester.getSemantics(finder), containsSemantics(isButton: true));
        expect(tester.getSemantics(finder).label, isNotEmpty);
      }
      for (final key in palette.keys) {
        final finder = find.byKey(_swatchKey(key));
        expect(tester.getSemantics(finder), containsSemantics(isButton: true));
        expect(tester.getSemantics(finder).label, isNotEmpty);
      }
      handle.dispose();
    });
  });

  group('AC8 — SM-1 / AD-2 : controller isolé, voisinage non reconstruit', () {
    testWidgets('changer la couleur 10× ne reconstruit PAS la rangée des kinds',
        (tester) async {
      final controller = ZAnnotationToolController(initialColorKey: 'primary');
      addTearDown(controller.dispose);
      var kindRowBuilds = 0;
      await tester.pumpWidget(_wrap(
        ZAnnotationToolbar(
          controller: controller,
          onDebugKindRowBuild: () => kindRowBuilds++,
        ),
      ));
      expect(kindRowBuilds, 1);
      for (var i = 0; i < 10; i++) {
        controller.selectColorKey(i.isEven ? 'secondary' : 'success');
        await tester.pump();
      }
      expect(kindRowBuilds, 1,
          reason: 'un setState d\'échelle toolbar rougirait ici (INJ R3-6)');
    });

    testWidgets('le controller possédé n\'est jamais recréé au build (R20/R3-6b)',
        (tester) async {
      final built = <ZAnnotationToolController>[];
      final rebuild = ValueNotifier<int>(0);
      addTearDown(rebuild.dispose);
      await tester.pumpWidget(_wrap(
        ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, __) =>
              ZAnnotationToolbar(onDebugBuild: built.add),
        ),
      ));
      final first = built.single;
      for (var i = 0; i < 5; i++) {
        rebuild.value++;
        await tester.pump();
      }
      expect(built.length, greaterThan(1),
          reason: 'les rebuilds ont bien eu lieu');
      expect(built.every((c) => identical(c, first)), isTrue,
          reason: 'recréer le controller dans build rougirait (INJ R3-6b)');
    });
  });

  group('AC10 — RTL : rendu directionnel effectif', () {
    testWidgets('l\'ordre des swatches est mirroré entre LTR et RTL',
        (tester) async {
      const palette = ZColorPalette.defaultStudy();
      final firstKey = _swatchKey(palette.keys.first);
      final lastKey = _swatchKey(palette.keys.last);

      await tester.pumpWidget(_wrap(const ZAnnotationToolbar(palette: palette)));
      final ltrFirst = tester.getTopLeft(find.byKey(firstKey)).dx;
      final ltrLast = tester.getTopLeft(find.byKey(lastKey)).dx;
      expect(ltrFirst, lessThan(ltrLast), reason: 'LTR : première à gauche');

      await tester.pumpWidget(_wrap(
        const ZAnnotationToolbar(palette: palette),
        textDirection: TextDirection.rtl,
      ));
      final rtlFirst = tester.getTopLeft(find.byKey(firstKey)).dx;
      final rtlLast = tester.getTopLeft(find.byKey(lastKey)).dx;
      expect(rtlFirst, greaterThan(rtlLast),
          reason: 'RTL : première à droite (INJ R3-8 rougirait)');
    });
  });

  group('AC11 — FR-26 : couleurs ET libellés INJECTÉS', () {
    testWidgets('la swatche honore la Color injectée et le libellé kind surchargé',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ZAnnotationToolbar(),
        colorKeyResolver: (scheme, key) => key == 'warning'
            ? const ZColorPair(
                color: Color(0xFFABCDEF), onColor: Color(0xFF000000))
            : null,
        labels: ZcrudLabels(<String, String>{
          'zcrud.annotation.kind.stickyNote': 'PENSE-BÊTE',
        }),
      ));
      final fill =
          tester.widget<ColoredBox>(find.byKey(_swatchFillKey('warning'))).color;
      expect(fill, const Color(0xFFABCDEF),
          reason: 'couleur injectée honorée (INJ R3-9 rougirait)');
      expect(find.text('PENSE-BÊTE'), findsOneWidget,
          reason: 'libellé kind INJECTÉ (jamais en dur)');
    });
  });

  group('AC12 — AD-10 : rendu défensif, jamais de throw', () {
    testWidgets('sans colorKeyResolver, la toolbar rend sans throw (repli scheme)',
        (tester) async {
      const palette = ZColorPalette.defaultStudy();
      await tester.pumpWidget(_wrap(const ZAnnotationToolbar(palette: palette)));
      expect(tester.takeException(), isNull);
      for (final key in palette.keys) {
        expect(find.byKey(_swatchFillKey(key)), findsOneWidget);
      }
    });
  });
}
