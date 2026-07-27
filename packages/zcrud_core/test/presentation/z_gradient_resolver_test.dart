import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  final light = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  );
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );

  testWidgets(
    'G4/G5 : le seam gagne, son `null` est RESPECTÉ, et rien ne lève',
    (tester) async {
      const distinctive = ZGradientSpec(
        gradient: LinearGradient(colors: <Color>[Color(1), Color(2)]),
        onGradient: Color(3),
      );
      ZGradientSpec? host(ColorScheme scheme, String key) =>
          key == 'host' ? distinctive : null;

      late ZGradientSpec? fromHost;
      late ZGradientSpec? hostSaidNull;
      late ZGradientSpec? fromEmpty;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light),
          home: ZcrudScope(
            gradientResolver: host,
            child: Builder(
              builder: (context) {
                fromHost = zResolveGradient(context, 'host');
                hostSaidNull = zResolveGradient(context, 'autre');
                fromEmpty = zResolveGradient(context, '');
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(fromHost, distinctive);
      // 🔴 GARDE DE L'ARBITRAGE VIS-1 (AC4 contre AC9). Le premier jet chaînait
      // `seam ?? zDerivedGradientResolver(...)`. Comme le repli rend un dégradé
      // pour TOUTE clé non vide, le `null` de l'hôte — qui signifie « accent
      // uni pour cette clé » — était ÉCRASÉ et devenait inexprimable.
      expect(
        hostSaidNull,
        isNull,
        reason:
            'le `null` de l\'hôte doit rester `null` : sa décision fait foi, '
            'aucun repli ne doit la recouvrir',
      );
      expect(fromEmpty, isNull);
    },
  );

  testWidgets(
    'G9bis : SANS injection, la résolution rend `null` — invariant de '
    'non-régression de l\'epic VIS (AC9)',
    (tester) async {
      late ZGradientSpec? sansScope;
      late ZGradientSpec? scopeSansResolver;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light),
          home: Builder(
            builder: (context) {
              sansScope = zResolveGradient(context, 'dossier-42');
              return ZcrudScope(
                child: Builder(
                  builder: (inner) {
                    scopeSansResolver = zResolveGradient(inner, 'dossier-42');
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      // MESURÉ avant correction : les deux rendaient un dégradé dérivé, ce qui
      // aurait fait diverger le rendu par défaut dès le premier consommateur
      // (VIS-2) — alors que l'epic garantit un rendu identique au pixel près
      // tant que rien n'est injecté.
      expect(sansScope, isNull);
      expect(scopeSansResolver, isNull);
    },
  );

  test('G6/G7 : spec structurelle et repli réellement dérivé du scheme', () {
    const a = ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[Color(1), Color(2)]),
      onGradient: Color(3),
    );
    const b = ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[Color(1), Color(2)]),
      onGradient: Color(4),
    );
    expect(a, isNot(b));
    expect(a.hashCode, isNot(b.hashCode));
    expect(a.onGradient, isNotNull);

    final lightSpec = zDerivedGradientResolver(light, 'key')!;
    final darkSpec = zDerivedGradientResolver(dark, 'key')!;
    expect(lightSpec.gradient, isA<LinearGradient>());
    expect(lightSpec.gradient.colors, isNot(darkSpec.gradient.colors));
    expect(lightSpec.onGradient, isNot(darkSpec.onGradient));

    // 🔴 GARDE ANTI-DÉGRADÉ PLAT. Le premier jet dérivait
    // `primaryContainer` → `secondaryContainer`, deux rôles trop voisins dans
    // un `ColorScheme.fromSeed` : le « dégradé » était un aplat. MESURÉ (écart
    // RGB cumulé, thème clair) : 0,039 pour primary/secondary contre 0,212 pour
    // primary/tertiary. Le seuil ci-dessous (0,05) sépare exactement les deux
    // cas — il a été RÉGLÉ SUR LA MESURE, pas choisi au jugé, et l'injection de
    // `secondaryContainer` le fait bien rougir.
    for (final ZGradientSpec spec in <ZGradientSpec>[lightSpec, darkSpec]) {
      final List<Color> colors = spec.gradient.colors;
      final double ecart =
          (colors.first.r - colors.last.r).abs() +
          (colors.first.g - colors.last.g).abs() +
          (colors.first.b - colors.last.b).abs();
      expect(
        ecart,
        greaterThan(0.05),
        reason:
            'les deux extrémités du dégradé dérivé doivent être visuellement '
            'distinctes (écart RGB cumulé mesuré : $ecart)',
      );
    }
  });

  testWidgets('AD-13 : le dégradé dérivé est DIRECTIONNEL (survit au RTL)', (
    tester,
  ) async {
    final LinearGradient g =
        zDerivedGradientResolver(light, 'key')!.gradient as LinearGradient;
    // Un `Alignment` physique figerait le sens du dégradé en arabe/hébreu.
    expect(g.begin, isA<AlignmentDirectional>());
    expect(g.end, isA<AlignmentDirectional>());
  });

  testWidgets(
    'G10 : zéro-config est tolérant et un seam stable ne notifie pas',
    (tester) async {
      late ZGradientSpec? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = zResolveGradient(context, 'key');
              return const SizedBox();
            },
          ),
        ),
      );
      // Zéro-config : aucune exception, et `null` (accent uni conservé).
      expect(result, isNull);

      // Le repli dérivé reste disponible, mais en OPT-IN explicite.
      expect(zDerivedGradientResolver(light, 'key'), isNotNull);

      ZGradientSpec? stable(ColorScheme scheme, String key) => null;
      final a = ZcrudScope(gradientResolver: stable, child: const SizedBox());
      final b = ZcrudScope(gradientResolver: stable, child: const SizedBox());
      expect(a.updateShouldNotify(b), isFalse);
    },
  );

  test('G11 : les fichiers VIS restent sans couleurs littérales ni kernel', () {
    final root = Directory.current.path;
    final files = <String>[
      '$root/lib/src/presentation/theme/z_theme.dart',
      '$root/lib/src/presentation/theme/z_gradient_resolver.dart',
      '$root/lib/src/presentation/zcrud_scope.dart',
    ];
    for (final file in files) {
      final source = File(file).readAsStringSync();
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('Colors.')));
      expect(
        RegExp(
          "^import .*zcrud_study_kernel",
          multiLine: true,
        ).hasMatch(source),
        isFalse,
      );
    }
  });
}
