library;

// PRIORITÉ paramètre > jeton > référence, prouvée sur le champ
// `signaturePalette` — le seul des trois maillons à être observable de bout en
// bout depuis ce paquet (la chaîne complète vit dans `zResolveGradient`).
//
// La preuve est ORDONNÉE et STRICTE : à chaque niveau on vérifie non seulement
// que la valeur attendue gagne, mais qu'elle DIFFÈRE de celle du niveau
// inférieur. Sans cette seconde assertion, une garde resterait verte alors que
// les trois niveaux rendent par hasard la même chose — et ne mesurerait rien.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_themes/zcrud_themes.dart';

/// Sentinelle du niveau « paramètre » : une valeur qu'aucun autre niveau ne
/// peut produire, de sorte que la voir prouve d'où elle vient.
const ZGradientSpec _sentinel = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFF010203), Color(0xFF040506)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

ZGradientSpec? _sentinelResolver(ColorScheme scheme, String key) => _sentinel;

void main() {
  const String identity = 'Analyse'; // identité arbitraire mais FIXE
  final String key = zSignatureKey(identity);

  Future<ZGradientSpec?> resolve(
    WidgetTester tester, {
    required ZcrudTheme theme,
    ZGradientResolver? resolver,
  }) async {
    ZGradientSpec? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: ZcrudScope(
          theme: theme,
          gradientResolver: resolver,
          child: Builder(
            builder: (BuildContext context) {
              seen = zResolveGradient(context, key);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('niveau RÉFÉRENCE : sans jeton ni seam, la référence du socle',
      (WidgetTester tester) async {
    final ZcrudTheme bare = ZcrudTheme.fallback(ThemeData.light())
        .copyWith(referenceProfile: ZReferenceProfile.legacy);
    final ZGradientSpec? seen = await resolve(tester, theme: bare);
    expect(seen, isNotNull);
    expect(ZSignaturePaletteReference.gradients, contains(seen));
  });

  testWidgets('niveau JETON : le thème Classic écrase la référence du socle',
      (WidgetTester tester) async {
    final ZcrudTheme bare = ZcrudTheme.fallback(ThemeData.light())
        .copyWith(referenceProfile: ZReferenceProfile.legacy);
    final ZGradientSpec? reference = await resolve(tester, theme: bare);

    final ZcrudTheme classic = ZClassicTheme.forTheme(ThemeData.light());
    final ZGradientSpec? token = await resolve(tester, theme: classic);

    expect(token, isNotNull);
    expect(classic.signaturePalette, contains(token));
    // STRICT : le jeton ne « coïncide » pas avec la référence, il la remplace.
    expect(token, isNot(reference));
  });

  testWidgets('niveau PARAMÈTRE : le seam de l\'hôte écrase le jeton',
      (WidgetTester tester) async {
    final ZcrudTheme classic = ZClassicTheme.forTheme(ThemeData.light());
    final ZGradientSpec? token = await resolve(tester, theme: classic);
    final ZGradientSpec? param = await resolve(
      tester,
      theme: classic,
      resolver: _sentinelResolver,
    );

    expect(param, _sentinel);
    expect(param, isNot(token));
  });

  testWidgets('l\'ordre complet est paramètre > jeton > référence',
      (WidgetTester tester) async {
    final ThemeData td = ThemeData.light();
    final ZcrudTheme bare = ZcrudTheme.fallback(td)
        .copyWith(referenceProfile: ZReferenceProfile.legacy);
    final ZcrudTheme classic = ZClassicTheme.forTheme(td);

    final ZGradientSpec? reference = await resolve(tester, theme: bare);
    final ZGradientSpec? token = await resolve(tester, theme: classic);
    final ZGradientSpec? param =
        await resolve(tester, theme: classic, resolver: _sentinelResolver);

    // Trois valeurs DISTINCTES : chaque maillon est réellement traversé.
    expect(<ZGradientSpec?>{reference, token, param}, hasLength(3));
    expect(param, _sentinel);
  });

  testWidgets('le thème remplit le jeton des dégradés par type de carte',
      (WidgetTester tester) async {
    final ZcrudTheme classic = ZClassicTheme.forTheme(ThemeData.dark());
    expect(
      classic.flashcardTypeGradients,
      ZClassicCardGradientsReference.typeGradients,
    );
  });

  testWidgets('le thème ne descend JAMAIS la cible tactile sous 48 dp (AD-13)',
      (WidgetTester tester) async {
    for (final ThemeData td in <ThemeData>[
      ThemeData.light(),
      ThemeData.dark(),
    ]) {
      expect(
        ZClassicTheme.forTheme(td).studySessionMinTarget,
        greaterThanOrEqualTo(48.0),
      );
    }
  });
}
