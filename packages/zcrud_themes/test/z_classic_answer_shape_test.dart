@TestOn('vm')
library;

// LES FORMES DE LA SURFACE DE SAISIE, mesurées au RENDU.
//
// Trois formes sont posées par le thème (tuile, contrôles côte à côte,
// soumission pleine largeur) et une quatrième est DÉLIBÉRÉMENT laissée vide.
// La garde mesure les quatre de la même façon : la tuile réellement montée
// (sa `shape`, ses épaisseurs de trait), les rectangles réellement occupés par
// les contrôles, la clé réellement présente — jamais le passage d'un jeton.
//
// Chaque forme est mesurée DEUX FOIS : sous le thème, et sous le repli du
// socle. Sans le second montage, la garde ne saurait pas distinguer « le thème
// pose la forme » de « la forme était déjà là ».
//
// 🔴 La quatrième — le moment d'apparition de la rangée de paliers — est un
// changement d'ORDRE DES GESTES, pas une forme. La garde prouve son absence au
// jeton ET au rendu, et prouve dans la foulée que la rangée EST atteignable par
// paramètre : une absence mesurée sur un sujet inatteignable ne mesure rien.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZAnswerActionsLayout,
        ZAnswerChoiceLayout,
        ZAnswerGradingVisibility,
        ZAnswerSubmitWidth,
        ZcrudScope,
        ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZChoice, ZFlashcard, ZFlashcardType, ZReviewMode;
import 'package:zcrud_session/zcrud_session.dart'
    show ZAnswerInputReference, ZFlashcardAnswerInput;
import 'package:zcrud_themes/zcrud_themes.dart';

/// Clés de la surface de saisie, recopiées de ses `static const` privées.
///
/// Recopiées et non importées : elles ne sont pas publiques. Une clé qui
/// dériverait rendrait les `find` vides, donc la garde rouge — jamais
/// silencieuse.
abstract final class ZK {
  /// Clé du contrôle de soumission.
  static const ValueKey<String> submit = ValueKey<String>('zSubmit');

  /// Clé du contrôle « je ne sais pas ».
  static const ValueKey<String> dontKnow = ValueKey<String>('zDontKnow');

  /// Clé du contrôle « indice ».
  static const ValueKey<String> hint = ValueKey<String>('zHintButton');

  /// Clé de la ligne de choix d'indice [i].
  static ValueKey<String> choice(int i) => ValueKey<String>('zAnswerChoice_$i');

  /// Clé du palier de notation [q].
  static ValueKey<String> quality(int q) => ValueKey<String>('zSrsQuality_$q');
}

/// QCM à un seul correct, porteur d'un indice STOCKÉ — c'est lui qui rend le
/// contrôle « indice » disponible sans port d'indice.
ZFlashcard zQcm() => const ZFlashcard(
  question: 'q',
  type: ZFlashcardType.multipleChoice,
  hint: 'h',
  choices: <ZChoice>[
    ZChoice(content: 'a'),
    ZChoice(content: 'b', isCorrect: true),
    ZChoice(content: 'c'),
  ],
);

/// Monte la surface de saisie sous [theme], à la luminosité [brightness].
Widget zInputHost({
  required ZcrudTheme theme,
  Brightness brightness = Brightness.light,
  ZAnswerGradingVisibility? gradingVisibility,
  void Function(int quality)? onQualitySelected,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: ZcrudScope(
    theme: theme,
    child: Scaffold(
      body: SingleChildScrollView(
        child: ZFlashcardAnswerInput(
          card: zQcm(),
          mode: ZReviewMode.learn,
          gradingVisibility: gradingVisibility,
          onQualitySelected: onQualitySelected,
        ),
      ),
    ),
  ),
);

/// Le thème Classic pour [brightness].
ZcrudTheme zClassic(Brightness brightness) =>
    ZClassicTheme.forTheme(ThemeData(brightness: brightness));

/// Le repli du socle pour [brightness] — le rendu d'avant le thème.
ZcrudTheme zFallback(Brightness brightness) =>
    ZcrudTheme.fallback(ThemeData(brightness: brightness));

/// Les cadres de tuile réellement montés sous la ligne de choix [index].
///
/// Un cadre de tuile est une `Material` À `shape` : c'est ce que la disposition
/// en tuile ajoute, et rien d'autre.
Iterable<Material> zTileFrames(WidgetTester tester, int index) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byKey(ZK.choice(index)),
        matching: find.byType(Material),
      ),
    )
    .where((Material m) => m.shape != null);

/// L'unique cadre de tuile de la ligne [index].
RoundedRectangleBorder zTileShape(WidgetTester tester, int index) {
  final Iterable<Material> frames = zTileFrames(tester, index);
  expect(frames, hasLength(1), reason: 'un seul cadre de tuile attendu');
  return frames.single.shape! as RoundedRectangleBorder;
}

void main() {
  group('les trois formes POSÉES atteignent le rendu', () {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('tuile : coins et liseré de référence en ${brightness.name}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          zInputHost(theme: zClassic(brightness), brightness: brightness),
        );
        await tester.pumpAndSettle();

        final RoundedRectangleBorder shape = zTileShape(tester, 0);
        expect(
          shape.borderRadius,
          const BorderRadius.all(ZAnswerInputReference.choiceTileRadius),
        );
        expect(shape.side.width, ZAnswerInputReference.choiceTileBorderWidth);
        expect(
          tester.getSize(find.byKey(ZK.choice(0))).height,
          greaterThanOrEqualTo(48),
          reason: 'la tuile passe sous le plancher tactile (AD-13).',
        );
      });

      testWidgets('contrôles d\'aide côte à côte en ${brightness.name}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          zInputHost(theme: zClassic(brightness), brightness: brightness),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsOneWidget);
        final Rect indice = tester.getRect(find.byKey(ZK.hint));
        final Rect jeNeSaisPas = tester.getRect(find.byKey(ZK.dontKnow));
        expect(indice.top, jeNeSaisPas.top, reason: 'pas la même ligne');
        expect(indice.width, jeNeSaisPas.width, reason: 'parts inégales');
        expect(indice.height, greaterThanOrEqualTo(48));
        expect(jeNeSaisPas.height, greaterThanOrEqualTo(48));
      });

      testWidgets('soumission pleine largeur en ${brightness.name}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          zInputHost(theme: zClassic(brightness), brightness: brightness),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(ZK.submit)).width,
          tester.getSize(find.byType(ZFlashcardAnswerInput)).width,
          reason: 'le contrôle n\'occupe pas la largeur entière de la surface.',
        );
      });
    }

    testWidgets('la SÉLECTION épaissit le trait — une forme, jamais la seule '
        'couleur (AD-13)', (WidgetTester tester) async {
      await tester.pumpWidget(zInputHost(theme: zClassic(Brightness.light)));
      await tester.pumpAndSettle();

      expect(
        zTileShape(tester, 0).side.width,
        ZAnswerInputReference.choiceTileBorderWidth,
      );
      await tester.tap(find.byKey(ZK.choice(0)));
      await tester.pumpAndSettle();
      expect(
        zTileShape(tester, 0).side.width,
        ZAnswerInputReference.choiceTileSelectedBorderWidth,
      );
      expect(
        zTileShape(tester, 1).side.width,
        ZAnswerInputReference.choiceTileBorderWidth,
        reason: 'la tuile voisine ne bouge pas',
      );
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('la matière reste RÉSOLUE en ${brightness.name} — le fond '
          'peint est celui du thème, le trait un rôle', (
        WidgetTester tester,
      ) async {
        // C'est cette mesure qui rattache les ratios de contraste au rendu :
        // sans elle, ils porteraient sur une couleur que la tuile ne lit
        // peut-être pas.
        final ZcrudTheme theme = zClassic(brightness);
        await tester.pumpWidget(
          zInputHost(theme: theme, brightness: brightness),
        );
        await tester.pumpAndSettle();

        final ColorScheme scheme = ThemeData(brightness: brightness).colorScheme;
        expect(
          zTileFrames(tester, 0).single.color?.toARGB32(),
          theme.surfaceColor?.toARGB32(),
          reason: 'la tuile ne peint pas le fond que le thème pose.',
        );
        expect(zTileShape(tester, 0).side.color, scheme.outlineVariant);
        await tester.tap(find.byKey(ZK.choice(0)));
        await tester.pumpAndSettle();
        expect(
          zTileShape(tester, 0).side.color,
          scheme.primary,
          reason: 'une teinte qui ne suit pas le `ColorScheme` serait une '
              'couleur en dur (FR-26).',
        );
      });
    }

    test('les trois jetons portent bien les valeurs mesurées', () {
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme t = zClassic(b);
        expect(t.answerInputChoiceLayout, ZAnswerChoiceLayout.tile, reason: '$b');
        expect(
          t.answerInputActionsLayout,
          ZAnswerActionsLayout.sideBySide,
          reason: '$b',
        );
        expect(t.answerInputSubmitWidth, ZAnswerSubmitWidth.full, reason: '$b');
      }
    });
  });

  group('sans le thème, la surface garde le rendu d\'aujourd\'hui', () {
    testWidgets('aucune tuile, contrôles empilés, soumission au contenu', (
      WidgetTester tester,
    ) async {
      final ZcrudTheme fallback = zFallback(Brightness.light);
      expect(fallback.answerInputChoiceLayout, isNull);
      expect(fallback.answerInputActionsLayout, isNull);
      expect(fallback.answerInputSubmitWidth, isNull);

      await tester.pumpWidget(zInputHost(theme: fallback));
      await tester.pumpAndSettle();

      expect(
        zTileFrames(tester, 0),
        isEmpty,
        reason: 'la ligne de choix est déjà une tuile sans le thème : la '
            'garde de la tuile ne mesurerait alors rien.',
      );
      expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
      expect(find.byKey(ZFlashcardAnswerInput.submitFullWidthKey), findsNothing);
      expect(
        tester.getSize(find.byKey(ZK.submit)).width,
        lessThan(tester.getSize(find.byType(ZFlashcardAnswerInput)).width),
        reason: 'la soumission occupe déjà toute la largeur sans le thème.',
      );
    });
  });

  group('le MOMENT de la notation n\'est PAS une forme — le thème le laisse '
      'vide', () {
    test('le jeton reste `null`, aux deux luminosités', () {
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme t = zClassic(b);
        expect(
          t.answerInputGradingVisibility,
          isNull,
          reason: '$b : le thème impose l\'ordre des gestes d\'une session.',
        );
        // Non-vacuité : sans elle, un thème devenu entièrement vide passerait
        // ce test sans rien prouver.
        expect(t.answerInputChoiceLayout, isNotNull, reason: '$b');
      }
    });

    testWidgets('au RENDU : aucune rangée de paliers avant la réponse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        zInputHost(
          theme: zClassic(Brightness.light),
          onQualitySelected: (int _) {},
        ),
      );
      await tester.pumpAndSettle();

      for (int q = 1; q <= 5; q++) {
        expect(find.byKey(ZK.quality(q)), findsNothing, reason: 'palier $q');
      }
    });

    testWidgets('la rangée EST atteignable par PARAMÈTRE — l\'absence '
        'ci-dessus porte donc sur un sujet réel', (WidgetTester tester) async {
      await tester.pumpWidget(
        zInputHost(
          theme: zClassic(Brightness.light),
          gradingVisibility: ZAnswerGradingVisibility.always,
          onQualitySelected: (int _) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ZK.quality(3)),
        findsOneWidget,
        reason: 'la rangée n\'est atteignable par aucune voie : la garde '
            'd\'absence ne mesurerait rien.',
      );
    });
  });
}
