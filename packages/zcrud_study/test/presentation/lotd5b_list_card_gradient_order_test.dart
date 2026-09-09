/// **Ordre de résolution du dégradé par type sur la carte de flashcard de
/// liste** — `seam > jeton`, l'ordre du socle.
///
/// ## Le défaut visé
///
/// Le socle applique partout `seam > jeton > référence`
/// (`zResolveGradient`) : un résolveur d'hôte qui répond l'emporte sur une
/// table que le thème pose. Cette carte-ci consultait le jeton
/// `ZcrudTheme.flashcardTypeGradients` **avant** le seam. Un thème du socle
/// qui pose ce jeton — c'est le cas du thème « Classic » — rendait donc le
/// résolveur de l'application **inopérant sans aucun signal** : le seam était
/// bien interrogé, sa réponse était bien reçue, et elle était simplement
/// jetée.
///
/// ## Ce que ces gardes mesurent
///
/// La décoration réellement remise au moteur de rendu pour la bande d'accent
/// de la carte — jamais une valeur passée à un constructeur, jamais une
/// rastérisation (`toImage()` pend sous ce harnais).
///
/// ## Ce qui NE change pas — et qui est mesuré ici pour cela
///
/// Les deux maillons qui précèdent la paire seam/jeton gardent leur place
/// exacte :
/// 1. une entrée `typeColors` pour le type de la carte gagne toujours, même
///    face à un `colorKey` explicite (paramètre spécifique à la surface) ;
/// 2. un `colorKey` explicite, sans entrée `typeColors`, coupe l'axe type
///    **entièrement** : ni seam, ni jeton, ni référence ne peignent — la
///    bande est unie, dérivée de l'axe identité.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientResolver, ZGradientSpec, ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardType;
import 'package:zcrud_study/zcrud_study.dart';

ZFlashcard _card() => const ZFlashcard(
      id: 'a',
      question: 'Question ?',
      type: ZFlashcardType.openQuestion,
    );

const String _kTypeKey = 'flashcard.type.openQuestion';

ZGradientSpec _spec(int a, int b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[Color(a), Color(b)]),
      onGradient: const Color(0xFFFFFFFF),
    );

/// Trois dégradés deux à deux DISTINCTS : aucune égalité ne peut être vraie
/// par coïncidence, et aucun n'est celui de la référence.
final ZGradientSpec kSeam = _spec(0xFF101010, 0xFF202020);
final ZGradientSpec kToken = _spec(0xFF303030, 0xFF404040);
final ZGradientSpec kParam = _spec(0xFF505050, 0xFF606060);

ZGradientSpec? _resolver(ColorScheme scheme, String key) =>
    key == _kTypeKey ? kSeam : null;

Widget _host(
  Widget child, {
  ZcrudTheme? tokens,
  ZGradientResolver? gradientResolver,
}) {
  final ThemeData base = ThemeData();
  final Widget app = MaterialApp(
    theme: tokens == null
        ? base
        : base.copyWith(extensions: <ThemeExtension<dynamic>>[tokens]),
    home: Scaffold(
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
  if (gradientResolver == null) return app;
  return ZcrudScope(gradientResolver: gradientResolver, child: app);
}

BoxDecoration _accent(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(ZDefaultFlashcardCard.accentKey),
        matching: find.byType(DecoratedBox),
      ),
    )
    .decoration as BoxDecoration;

/// Le jeton de thème posant [kToken] pour le type de la carte.
ZcrudTheme _tokens() => ZcrudTheme(
      flashcardTypeGradients: <String, ZGradientSpec>{'openQuestion': kToken},
    );

List<Color> _colorsOf(ZGradientSpec spec) =>
    (spec.gradient as LinearGradient).colors;

List<Color> _painted(WidgetTester tester) =>
    (_accent(tester).gradient! as LinearGradient).colors;

void main() {
  test('les trois dégradés de test sont deux à deux DISTINCTS', () {
    expect(_colorsOf(kSeam), isNot(_colorsOf(kToken)));
    expect(_colorsOf(kSeam), isNot(_colorsOf(kParam)));
    expect(_colorsOf(kToken), isNot(_colorsOf(kParam)));
  });

  group('🎨 seam > jeton — l\'ordre du socle', () {
    testWidgets('jeton SEUL ⇒ c\'est le jeton qui peint', (tester) async {
      await tester.pumpWidget(
        _host(ZDefaultFlashcardCard(card: _card()), tokens: _tokens()),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kToken));
    });

    testWidgets('seam SEUL ⇒ c\'est le seam qui peint', (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(card: _card()),
          gradientResolver: _resolver,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kSeam));
    });

    testWidgets('jeton ET seam posés ⇒ c\'est le SEAM qui peint',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(card: _card()),
          tokens: _tokens(),
          gradientResolver: _resolver,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kSeam),
          reason: '🔴 un résolveur d\'hôte qui répond l\'emporte sur le jeton '
              'du thème : sinon un thème du socle rend le résolveur de '
              'l\'application inopérant, sans aucun signal');
    });

    testWidgets('le seam MUET laisse le jeton peindre', (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(card: _card()),
          tokens: _tokens(),
          gradientResolver: (ColorScheme scheme, String key) => null,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kToken),
          reason: '🔴 le seam ne PRIME que quand il RÉPOND — son silence ne '
              'doit jamais effacer le jeton');
    });

    testWidgets('ni seam ni jeton ⇒ la RÉFÉRENCE peint', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card())));
      await tester.pumpAndSettle();
      expect(
        _accent(tester).gradient,
        ZFlashcardCardReference.typeGradients['openQuestion']!.gradient,
      );
    });
  });

  group('🔒 les maillons AMONT gardent leur place exacte', () {
    testWidgets('`typeColors` pour le type bat le seam ET le jeton',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(
            card: _card(),
            typeColors: <String, ZGradientSpec>{'openQuestion': kParam},
          ),
          tokens: _tokens(),
          gradientResolver: _resolver,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kParam));
    });

    testWidgets('`typeColors` bat même un `colorKey` explicite',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(
            card: _card(),
            colorKey: 'tertiary',
            typeColors: <String, ZGradientSpec>{'openQuestion': kParam},
          ),
          tokens: _tokens(),
          gradientResolver: _resolver,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester), _colorsOf(kParam));
    });

    testWidgets('`colorKey` explicite coupe l\'axe type ENTIER — seam compris',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFlashcardCard(card: _card(), colorKey: 'tertiary'),
          tokens: _tokens(),
          gradientResolver: _resolver,
        ),
      );
      await tester.pumpAndSettle();
      final BoxDecoration deco = _accent(tester);
      expect(deco.gradient, isNull,
          reason: '🔴 un choix d\'IDENTITÉ posé par l\'hôte n\'est écrasé par '
              'AUCUN défaut de l\'axe type — le seam n\'y fait pas exception');
      expect(deco.color, isNotNull);
    });
  });
}
