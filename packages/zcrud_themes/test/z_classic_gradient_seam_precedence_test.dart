library;

// PRÉCÉDENCE `seam > jeton` sur les dégradés par type de carte.
//
// Le jeton `ZcrudTheme.flashcardTypeGradients` que le thème pose est un REPLI :
// les cartes consultent d'abord `ZcrudScope.gradientResolver`. Un hôte qui
// branche son résolveur doit donc voir LE SIEN peindre, thème posé ou non.
//
// La garde mesure le dégradé RÉELLEMENT PEINT — la décoration du liseré monté
// dans l'arbre — et jamais le passage d'un jeton : un jeton peut transiter sans
// atteindre un pixel, et une garde qui le suivrait resterait verte sur une
// régression de rendu.
//
// ⚠️ Le liseré n'existe qu'avec une hauteur (`accentHeight`, ou le jeton
// `ZcrudTheme.accentBarHeight` que ce thème ne pose PAS). La garde la passe en
// paramètre et asserte que le liseré est bien monté : sans cette assertion de
// non-vacuité, les trois cas rendraient « aucun dégradé » et la garde serait
// verte pour rien.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_themes/zcrud_themes.dart';

/// Carte de type `openQuestion` — le type dont le thème connaît le dégradé.
const ZFlashcard _card = ZFlashcard(
  id: 'c1',
  question: 'q',
  answer: 'a',
);

/// Dégradé sentinelle d'un hôte : une valeur qu'aucun autre maillon ne peut
/// produire, de sorte que la voir prouve d'où elle vient.
const ZGradientSpec _sentinel = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFF010203), Color(0xFF040506)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

/// Résolveur d'hôte qui répond à la clé de type préfixée, et à elle seule.
ZGradientSpec? _hostResolver(ColorScheme scheme, String key) =>
    key == '$kZFlashcardReviewTypeGradientKeyPrefix${_card.type.name}'
        ? _sentinel
        : null;

/// Le dégradé du type de carte selon la table posée par le thème.
List<Color> get _classicStops =>
    (ZClassicCardGradientsReference.typeGradients[_card.type.name]!.gradient
            as LinearGradient)
        .colors;

/// Monte la carte sous le thème Classic et rend les couleurs du dégradé
/// **peint** par le liseré.
///
/// Lève si le liseré n'est pas monté ou ne porte pas de dégradé : une garde qui
/// rendrait une liste vide ne mesurerait plus rien.
Future<List<Color>> _paintedStops(
  WidgetTester tester, {
  ZGradientResolver? resolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          theme: ZClassicTheme.forTheme(ThemeData.light()),
          gradientResolver: resolver,
          child: const ZFlashcardReviewCard(
            card: _card,
            accentHeight: ZClassicSurfaceReference.cardAccentHeight,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));

  final Finder bar = find.byKey(ZFlashcardReviewCard.gradientAccentKey);
  if (bar.evaluate().isEmpty) {
    throw StateError(
      'Liseré non monté : la garde ne mesure aucun dégradé peint.',
    );
  }
  final Container box = tester.widget<Container>(bar);
  final Decoration? decoration = box.decoration;
  if (decoration is! BoxDecoration || decoration.gradient == null) {
    throw StateError('Liseré sans dégradé : rien à mesurer.');
  }
  return decoration.gradient!.colors;
}

void main() {
  testWidgets('THÈME SEUL — le jeton peint (le résolveur se tait)',
      (WidgetTester tester) async {
    final List<Color> painted = await _paintedStops(tester);
    expect(painted, _classicStops);
    // Non-vacuité : un dégradé vide passerait l'égalité ci-dessus si la table
    // du thème venait à se vider.
    expect(painted, hasLength(greaterThanOrEqualTo(2)));
  });

  testWidgets('THÈME + RÉSOLVEUR D\'HÔTE — c\'est le résolveur qui peint',
      (WidgetTester tester) async {
    final List<Color> painted =
        await _paintedStops(tester, resolver: _hostResolver);
    expect(
      painted,
      (_sentinel.gradient as LinearGradient).colors,
      reason: 'Le jeton du thème a battu le résolveur de l\'hôte : la chaîne '
          '`seam > jeton` est inversée.',
    );
    // STRICT : la sentinelle ne « coïncide » pas avec le jeton, elle le
    // remplace. Sans cette assertion, deux valeurs égales par hasard
    // laisseraient la garde verte.
    expect(painted, isNot(_classicStops));
  });

  testWidgets('THÈME + RÉSOLVEUR CLASSIC — les deux maillons concordent',
      (WidgetTester tester) async {
    // Adopter le thème EN ENTIER (jeton + résolveur) ne change donc rien au
    // dégradé peint : c'est ce qui rend le changement d'ordre indolore pour un
    // hôte qui suit la ligne d'adoption du paquet.
    final List<Color> painted =
        await _paintedStops(tester, resolver: ZClassicTheme.gradients);
    expect(painted, _classicStops);
  });

  testWidgets('un résolveur qui se tait sur CETTE clé laisse le jeton peindre',
      (WidgetTester tester) async {
    // Contre-preuve du cas précédent : le résolveur est branché, mais muet sur
    // la clé demandée. `null` est une réponse fonctionnelle — elle rend la main
    // au jeton, elle n'efface pas le dégradé.
    final List<Color> painted = await _paintedStops(
      tester,
      resolver: (ColorScheme scheme, String key) => null,
    );
    expect(painted, _classicStops);
  });

  testWidgets('sans hauteur, aucun liseré — la garde le SAIT',
      (WidgetTester tester) async {
    // Ce que la non-vacuité protège : le thème ne pose pas `accentBarHeight`,
    // donc sans le paramètre la carte ne monte aucun liseré. Une garde écrite
    // sans lui aurait mesuré « rien » dans les trois cas.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            theme: ZClassicTheme.forTheme(ThemeData.light()),
            child: const ZFlashcardReviewCard(card: _card),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(ZFlashcardReviewCard.gradientAccentKey), findsNothing);
  });
}
