// Story 5.3 — `ZGeoShapeStylePicker` : toolbar de style fill/stroke/épaisseur
// réutilisant le seam couleur du cœur (AD-1 CORE OUT=0), avec association
// picker→modèle PROUVÉE (R3 : bon champ + voisins préservés), défensif AD-10
// (seam défaillant → aucune écriture ; style null → défaut sûr), a11y ≥48dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

/// Monte le picker sous `MaterialApp` + `ZcrudScope`, avec un [colorPicker] seam
/// optionnel injecté. `dir` permet d'exercer le RTL.
Widget _app({
  required ZGeoShapeStyle? style,
  required ValueChanged<ZGeoShapeStyle> onChanged,
  ZColorPicker? colorPicker,
  bool readOnly = false,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          colorPicker: colorPicker,
          child: Scaffold(
            body: ZGeoShapeStylePicker(
              style: style,
              onChanged: onChanged,
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );

/// Seam retournant un ARGB fixe (simule un picker host qui renvoie [argb]).
ZColorPicker _seamReturning(int argb) => (
      BuildContext context, {
      required int? initialArgb,
      required bool enableAlpha,
      required List<int> recentColors,
    }) async =>
        argb;

/// Seam qui lève une exception (AD-10 : aucune écriture attendue).
ZColorPicker get _seamThrowing => (
      BuildContext context, {
      required int? initialArgb,
      required bool enableAlpha,
      required List<int> recentColors,
    }) async =>
        throw Exception('seam en échec');

void main() {
  const base = ZGeoShapeStyle(
    fillColorArgb: 0xFFAAAAAA,
    strokeColorArgb: 0xFFBBBBBB,
    strokeWidth: 5,
  );

  group('AC3 — association picker → ZGeoShapeStyle (R3 : bon champ + voisins)',
      () {
    testWidgets('remplissage : fillColorArgb ← exact, stroke/width préservés',
        (tester) async {
      const pickedArgb = 0xFF112233;
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: base,
        colorPicker: _seamReturning(pickedArgb),
        onChanged: (s) => emitted = s,
      ));

      await tester.tap(find.text('Remplissage'));
      await tester.pumpAndSettle();

      expect(emitted, isNotNull);
      // Champ ciblé changé vers la valeur EXACTE choisie.
      expect(emitted!.fillColorArgb, pickedArgb);
      // Voisins PRÉSERVÉS (rougit si copyWith écrase / mauvais champ).
      expect(emitted!.strokeColorArgb, base.strokeColorArgb);
      expect(emitted!.strokeWidth, base.strokeWidth);
    });

    testWidgets('trait : strokeColorArgb ← exact, fill/width préservés',
        (tester) async {
      const pickedArgb = 0xFF445566;
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: base,
        colorPicker: _seamReturning(pickedArgb),
        onChanged: (s) => emitted = s,
      ));

      await tester.tap(find.text('Trait'));
      await tester.pumpAndSettle();

      expect(emitted, isNotNull);
      expect(emitted!.strokeColorArgb, pickedArgb);
      expect(emitted!.fillColorArgb, base.fillColorArgb);
      expect(emitted!.strokeWidth, base.strokeWidth);
    });
  });

  group('AC4 — épaisseur bornée, couleurs préservées', () {
    testWidgets('incrément : strokeWidth +1, couleurs inchangées',
        (tester) async {
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: base,
        onChanged: (s) => emitted = s,
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.strokeWidth, base.strokeWidth + 1);
      expect(emitted!.fillColorArgb, base.fillColorArgb);
      expect(emitted!.strokeColorArgb, base.strokeColorArgb);
    });

    testWidgets('décrément borné : jamais sous 0 (contrôle désactivé à 0)',
        (tester) async {
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: const ZGeoShapeStyle(strokeWidth: 0),
        onChanged: (s) => emitted = s,
      ));

      // Le bouton « diminuer » est désactivé à 0 → aucune émission.
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(emitted, isNull);
    });

    testWidgets('incrément borné : jamais au-dessus du max (désactivé au max)',
        (tester) async {
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: const ZGeoShapeStyle(strokeWidth: 20),
        onChanged: (s) => emitted = s,
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(emitted, isNull);
    });
  });

  group('AC8 — défensif AD-10', () {
    testWidgets('seam qui throw → AUCUNE émission onChanged, pas de crash',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_app(
        style: base,
        colorPicker: _seamThrowing,
        onChanged: (_) => called = true,
      ));

      await tester.tap(find.text('Remplissage'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('style null → monte sans throw, part de ZGeoShapeStyle()',
        (tester) async {
      ZGeoShapeStyle? emitted;
      await tester.pumpWidget(_app(
        style: null,
        onChanged: (s) => emitted = s,
      ));
      expect(tester.takeException(), isNull);

      // Incrément part du défaut (strokeWidth 3) → 4, couleurs restent null.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(emitted, isNotNull);
      expect(emitted!.strokeWidth, 4);
      expect(emitted!.fillColorArgb, isNull);
      expect(emitted!.strokeColorArgb, isNull);
    });
  });

  group('AC2 — repli built-in quand aucun seam injecté', () {
    testWidgets('sans colorPicker : tap fill ouvre le ZColorPickerDialog du cœur',
        (tester) async {
      await tester.pumpWidget(_app(
        style: base,
        onChanged: (_) {},
      ));

      await tester.tap(find.text('Remplissage'));
      await tester.pumpAndSettle();

      // Le repli est le built-in NEUTRE du cœur (aucun 2e picker écrit ici).
      expect(find.byType(ZColorPickerDialog), findsOneWidget);
    });
  });

  group('AC6 — a11y / RTL (AD-13)', () {
    testWidgets('cibles ≥ 48 dp + un seul Semantics porteur par cible',
        (tester) async {
      await tester.pumpWidget(_app(
        style: base,
        onChanged: (_) {},
      ));

      // Cibles couleur ≥ 48 dp (via l'InkWell porteur).
      final fillTap =
          find.ancestor(of: find.text('Remplissage'), matching: find.byType(InkWell));
      expect(tester.getSize(fillTap).height, greaterThanOrEqualTo(48));
      final strokeTap =
          find.ancestor(of: find.text('Trait'), matching: find.byType(InkWell));
      expect(tester.getSize(strokeTap).height, greaterThanOrEqualTo(48));

      // Cibles épaisseur ≥ 48 dp.
      final incTap =
          find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(SizedBox));
      expect(tester.getSize(incTap.first).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(incTap.first).height, greaterThanOrEqualTo(48));

      // Un seul Semantics porteur par cible (pas de double annonce fill/stroke).
      expect(find.bySemanticsLabel('Remplissage'), findsOneWidget);
      expect(find.bySemanticsLabel('Trait'), findsOneWidget);
    });

    testWidgets('monte en RTL sans exception', (tester) async {
      await tester.pumpWidget(_app(
        style: base,
        onChanged: (_) {},
        dir: TextDirection.rtl,
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(ZGeoShapeStylePicker), findsOneWidget);
    });
  });

  group('AC5 — cadre neutre du thème délimitant la vignette d\'aperçu', () {
    // Clé du cadre extérieur neutre (miroir de `_StylePreview.outerFrameKey`).
    const outerFrameKey = ValueKey('z_geo_style_preview_frame');

    testWidgets(
        'trait == couleur de fond ⇒ la vignette garde un cadre neutre visible '
        '(borderColor du thème, DISTINCT du stroke)', (tester) async {
      // Fond de la vignette (remplissage) ET trait IDENTIQUES : sans cadre
      // neutre extérieur, la vignette se fondrait dans son propre fond.
      const collision = 0xFF123456;
      await tester.pumpWidget(_app(
        style: const ZGeoShapeStyle(
          fillColorArgb: collision,
          strokeColorArgb: collision,
          strokeWidth: 2,
        ),
        onChanged: (_) {},
      ));

      // Couleur neutre attendue, résolue depuis le thème réel (FR-26).
      final ctx = tester.element(find.byType(ZGeoShapeStylePicker));
      final expectedNeutral =
          ZcrudTheme.of(ctx).fieldBorderColor ?? Theme.of(ctx).colorScheme.outline;

      // Le cadre EXTÉRIEUR existe et porte la couleur neutre du thème.
      final frame = find.byKey(outerFrameKey);
      expect(frame, findsOneWidget);
      final frameDecoration =
          tester.widget<Container>(frame).decoration! as BoxDecoration;
      final Border frameBorder = frameDecoration.border! as Border;
      expect(frameBorder.top.color, expectedNeutral,
          reason: 'le cadre extérieur doit être NEUTRE (thème), pas le stroke');
      // Cadre neutre DISTINCT du trait (donnée) ⇒ contraste garanti (AC5).
      expect(frameBorder.top.color, isNot(const Color(collision)));

      // Le liseré INTÉRIEUR rend bien le trait choisi (la donnée), inchangé.
      final inner = find.byKey(const ValueKey('z_geo_style_preview_swatch'));
      expect(inner, findsOneWidget);
      final innerDecoration =
          tester.widget<DecoratedBox>(inner).decoration as BoxDecoration;
      expect((innerDecoration.border! as Border).top.color,
          const Color(collision));
    });
  });

  group('AC1 — readOnly : aucune écriture', () {
    testWidgets('readOnly désactive les contrôles (aucune émission)',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_app(
        style: base,
        readOnly: true,
        onChanged: (_) => called = true,
      ));

      await tester.tap(find.text('Remplissage'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(called, isFalse);
    });
  });
}
