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
    final changed = base.copyWith(gapM: 42, errorColor: const Color(0xFF000001));
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

  testWidgets('of() : scope.theme l\'emporte (AC5-a)', (tester) async {
    final custom = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ZcrudScope(
          theme: custom,
          child: Builder(builder: (context) {
            resolved = ZcrudTheme.of(context);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(identical(resolved, custom), isTrue);
  });

  testWidgets('of() : sans scope-theme → ThemeData.extension (AC5-b)',
      (tester) async {
    final ext = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[ext]),
        home: ZcrudScope(
          child: Builder(builder: (context) {
            resolved = ZcrudTheme.of(context);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(identical(resolved, ext), isTrue);
  });

  testWidgets('of() : ni scope ni extension → fallback dérivé (AC5-c)',
      (tester) async {
    late ZcrudTheme resolved;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ZcrudScope(
          child: Builder(builder: (context) {
            theme = Theme.of(context);
            resolved = ZcrudTheme.of(context);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(resolved.surfaceColor, theme.colorScheme.surface);
    expect(resolved.errorColor, theme.colorScheme.error);
  });
}
