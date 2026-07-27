// AC5/AC6 : `ZcrudTheme` (ThemeExtension) résolu via scope > extension >
// fallback dérivé ; copyWith/lerp ; repli dérivé de ColorScheme (light≠dark).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZcrudTheme _custom() => const ZcrudTheme(
  fieldBorderColor: Color(0xFF112233),
  errorColor: Color(0xFF445566),
  labelColor: Color(0xFF778899),
  surfaceColor: Color(0xFFAABBCC),
);

void main() {
  test('fallback DÉRIVE tout du ColorScheme (light ≠ dark, AC5/AC6)', () {
    final light = ZcrudTheme.fallback(ThemeData.light());
    final dark = ZcrudTheme.fallback(ThemeData.dark());
    // Dérivation prouvée : les couleurs changent avec le ColorScheme.
    expect(light.surfaceColor, ThemeData.light().colorScheme.surface);
    expect(dark.surfaceColor, ThemeData.dark().colorScheme.surface);
    expect(light.surfaceColor, isNot(dark.surfaceColor));
    expect(light.errorColor, ThemeData.light().colorScheme.error);
    expect(light.fieldBorderColor, ThemeData.light().colorScheme.outline);
    expect(light.fieldBorderColor, isNot(dark.fieldBorderColor));
  });

  test('copyWith : identité + surcharge ciblée (AC5)', () {
    final base = _custom();
    expect(base.copyWith().fieldBorderColor, base.fieldBorderColor);
    expect(base.copyWith().gapM, base.gapM);
    expect(base.copyWith().badgeRadius, base.badgeRadius);
    final changed = base.copyWith(
      gapM: 42,
      errorColor: const Color(0xFF000001),
    );
    expect(changed.gapM, 42);
    expect(changed.errorColor, const Color(0xFF000001));
    expect(changed.fieldBorderColor, base.fieldBorderColor);
  });

  test('lerp(a,b,0) == a sur tokens clés ; lerp(a,b,1) == b (AC5)', () {
    final a = _custom();
    final b = a.copyWith(gapM: 100, surfaceColor: const Color(0xFF010101));
    final at0 = a.lerp(b, 0);
    final at1 = a.lerp(b, 1);
    expect(at0.gapM, a.gapM);
    expect(at0.surfaceColor, a.surfaceColor);
    expect(at1.gapM, b.gapM);
    expect(at1.surfaceColor, b.surfaceColor);
    expect(a.lerp(null, 0.5).gapM, a.gapM); // other non ZcrudTheme → this
  });

  test('G1/G2/G3 : tokens VIS opt-in, héritage lerp et extrêmes', () {
    const base = ZcrudTheme();
    final changed = base.copyWith(
      accentBarHeight: 6,
      gradientBegin: AlignmentDirectional.topStart,
      gradientEnd: AlignmentDirectional.bottomEnd,
      cardShadowBlurRadius: 12,
      cardShadowOffset: const Offset(1, 2),
      cardShadowAlpha: .3,
      cardTintAlpha: .2,
      iconContainerSize: 48,
      iconContainerRadius: const Radius.circular(9),
      countPillPadding: const EdgeInsetsDirectional.all(5),
      countPillRadius: const Radius.circular(7),
      countPillIconSize: 18,
      celebrationDuration: const Duration(milliseconds: 300),
      celebrationCurve: Curves.easeIn,
      flipDuration: const Duration(milliseconds: 180),
      flipCurve: Curves.easeOut,
    );
    expect(base.accentBarHeight, isNull);
    expect(base.gradientBegin, isNull);
    expect(base.cardShadowOffset, isNull);
    expect(base.countPillPadding, isNull);
    expect(base.celebrationCurve, isNull);
    expect(base.copyWith().flipDuration, isNull);
    final inherited = base.lerp(const ZcrudTheme(gapM: 10), .5);
    expect(inherited.iconContainerRadius, isNull);
    expect(inherited.accentBarHeight, isNull);
    expect(inherited.gradientBegin, isNull);
    expect(inherited.gradientEnd, isNull);
    expect(inherited.cardShadowBlurRadius, isNull);
    expect(inherited.cardShadowOffset, isNull);
    expect(inherited.cardShadowAlpha, isNull);
    expect(inherited.cardTintAlpha, isNull);
    expect(inherited.iconContainerSize, isNull);
    expect(inherited.countPillPadding, isNull);
    expect(inherited.countPillRadius, isNull);
    expect(inherited.countPillIconSize, isNull);
    expect(inherited.celebrationDuration, isNull);
    expect(inherited.celebrationCurve, isNull);
    expect(inherited.flipDuration, isNull);
    expect(inherited.flipCurve, isNull);
    // Une DIMENSION absente peut légitimement partir de zéro : une barre
    // d'accent qui « grandit depuis rien » est un rendu plausible.
    expect(base.lerp(changed, 0).accentBarHeight, isZero);
    expect(base.lerp(changed, 1).accentBarHeight, changed.accentBarHeight);

    // 🔴 GARDE MAJEUR-1 (CR epic VIS) — une DURÉE, elle, ne doit JAMAIS être
    // matérialisée à zéro. `Duration.zero` n'est pas une absence : c'est une
    // valeur INVALIDE (animation dégénérée ; `ConfettiController` lève sur une
    // durée non strictement positive). MESURÉ avant correction : `t=0.0`
    // rendait `0:00:00.000000`, si bien qu'un thème animé vers un préréglage
    // traversait un instant où toute célébration construite plantait.
    // Un côté `null` signifie « le consommateur applique SON défaut » — valeur
    // que le thème ignore : on rend donc l'autre côté, seul réellement connu.
    for (final double t in <double>[0.0, 0.25, 0.5, 1.0]) {
      expect(
        base.lerp(changed, t).celebrationDuration,
        changed.celebrationDuration,
        reason: 'durée nulle d\'un côté ⇒ jamais zéro, jamais interpolée (t=$t)',
      );
      expect(base.lerp(changed, t).flipDuration, changed.flipDuration);
      expect(
        changed.lerp(base, t).celebrationDuration,
        changed.celebrationDuration,
        reason: 'symétrique : l\'absence côté cible ne doit pas non plus valoir 0',
      );
    }
    // `null` des deux côtés reste `null` (héritage préservé).
    expect(
      base.lerp(const ZcrudTheme(), .5).celebrationDuration,
      isNull,
    );
    expect(base.lerp(changed, 1).gradientEnd, changed.gradientEnd);
    expect(base.lerp(changed, 1).countPillPadding, changed.countPillPadding);
    expect(base.lerp(changed, 1).flipCurve, changed.flipCurve);
  });

  testWidgets('of() : scope.theme l\'emporte (AC5-a)', (tester) async {
    final custom = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ZcrudScope(
          theme: custom,
          child: Builder(
            builder: (context) {
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(identical(resolved, custom), isTrue);
  });

  testWidgets('of() : sans scope-theme → ThemeData.extension (AC5-b)', (
    tester,
  ) async {
    final ext = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[ext]),
        home: ZcrudScope(
          child: Builder(
            builder: (context) {
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(identical(resolved, ext), isTrue);
  });

  testWidgets('of() : ni scope ni extension → fallback dérivé (AC5-c)', (
    tester,
  ) async {
    late ZcrudTheme resolved;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ZcrudScope(
          child: Builder(
            builder: (context) {
              theme = Theme.of(context);
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolved.surfaceColor, theme.colorScheme.surface);
    expect(resolved.errorColor, theme.colorScheme.error);
  });
}
