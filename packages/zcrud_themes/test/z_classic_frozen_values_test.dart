library;

// TABLE FIGÉE. Les valeurs attendues sont écrites ICI, recopiées à la main
// depuis le code de référence avec leur `fichier:ligne` d'origine. Elles ne
// sont JAMAIS relues depuis les fichiers de référence du paquet : une garde
// qui lit sa propre source ne compare que le fichier à lui-même et reste verte
// quoi qu'on y change.
//
// Origine (lue sur la branche `main` du code de référence, en lecture seule,
// via `git show main:<chemin>` — le checkout local est sur une autre branche) :
//   lib/src/domain/models/flashcard_repetition_info.dart:116-122
//   lib/src/presentation/features/flashcards/widgets/
//     flashcard_widgets.dart:149-160
//   lib/src/presentation/features/flashcards/widgets/
//     interactive_flashcard_repetition_card.dart:424, :682-692
//   lib/src/presentation/features/flashcards/pages/
//     folder_flashcards_repetitions_page.dart:239, :274-279, :282, :1056, :1097
//   lib/src/presentation/features/flashcards/pages/
//     flashcards_learning_celebration_page.dart:126-131, :249, :260
//
// Les quatre dégradés par type sont ceux de la carte de GRILLE/LISTE, la table
// que le socle retient — et non ceux de la carte de répétition, qui inverse
// `openQuestion` et `exercise`.
//
// TROIS teintes de palier divergent volontairement de la source : elles y
// échouaient le plancher de contraste 3.0:1 sur le fond clair du thème. La
// valeur figée ici est la valeur CORRIGÉE, et le commentaire porte l'originale.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;
import 'package:zcrud_themes/zcrud_themes.dart';

void main() {
  group('paliers SRS — flashcard_repetition_info.dart:116-122', () {
    test('cinq paliers, dans l\'ordre croissant de qualité', () {
      expect(
        ZClassicSrsPaletteReference.steps.map((s) => s.quality).toList(),
        <int>[1, 2, 3, 4, 5],
      );
      expect(
        ZClassicSrsPaletteReference.steps.map((s) => s.name).toList(),
        <String>['fail', 'hard', 'good', 'easy', 'perfect'],
      );
    });

    test('teintes figées (dont les trois corrigées pour contraste)', () {
      expect(ZClassicSrsPaletteReference.fail.color,
          const Color(0xFFF44336)); // :116 Colors.red, repris à l'octet
      expect(ZClassicSrsPaletteReference.hard.color,
          const Color(0xFFE65100)); // :117 Colors.orange #FF9800 → corrigé
      expect(ZClassicSrsPaletteReference.good.color,
          const Color(0xFF1E88E5)); // :119 Colors.blue #2196F3 → corrigé
      expect(ZClassicSrsPaletteReference.easy.color,
          const Color(0xFF009688)); // :120 Colors.teal, repris à l'octet
      expect(ZClassicSrsPaletteReference.perfect.color,
          const Color(0xFF388E3C)); // :122 Colors.green #4CAF50 → corrigé
    });

    test('glyphes figés', () {
      expect(ZClassicSrsPaletteReference.fail.icon, Icons.close); // :116
      expect(ZClassicSrsPaletteReference.hard.icon,
          Icons.sentiment_very_dissatisfied); // :117
      expect(ZClassicSrsPaletteReference.good.icon,
          Icons.sentiment_satisfied); // :119
      expect(ZClassicSrsPaletteReference.easy.icon,
          Icons.sentiment_very_satisfied); // :120-121
      expect(ZClassicSrsPaletteReference.perfect.icon, Icons.check); // :122
    });

    test('les clés sont des clés, jamais un libellé', () {
      expect(ZClassicSrsPaletteReference.colorKeyFor(1), 'zcrud.classic.srs.fail');
      expect(ZClassicSrsPaletteReference.labelKeyFor(5),
          'zcrud.srs.quality.classic.perfect');
      expect(ZClassicSrsPaletteReference.previewKeyFor(3),
          'zcrud.srs.preview.classic.good');
    });

    test('hors échelle : borné, jamais une exception (AD-10)', () {
      expect(ZClassicSrsPaletteReference.byQuality(0), isNull);
      expect(ZClassicSrsPaletteReference.byQuality(9), isNull);
      expect(ZClassicSrsPaletteReference.colorKeyFor(-7),
          'zcrud.classic.srs.fail');
      expect(ZClassicSrsPaletteReference.colorKeyFor(99),
          'zcrud.classic.srs.perfect');
    });
  });

  // Les quatre paires viennent de la carte de GRILLE/LISTE — la table que le
  // socle (`ZFlashcardCardReference`) réplique. Le code de référence en porte
  // une seconde, dans la carte de répétition, inversée sur `openQuestion` et
  // `exercise` : ce n'est PAS celle-ci. L'égalité stricte avec le socle est
  // gardée à part (`z_socle_gradient_parity_test.dart`).
  group('dégradés par type — flashcard_widgets.dart:149-160', () {
    List<Color> stops(ZGradientSpec s) =>
        (s.gradient as LinearGradient).colors;

    test('les quatre paires d\'arrêts, à l\'octet', () {
      expect(stops(ZClassicCardGradientsReference.multipleChoice),
          <Color>[const Color(0xFF667EEA), const Color(0xFF764BA2)]); // :153
      expect(stops(ZClassicCardGradientsReference.trueOrFalse),
          <Color>[const Color(0xFF11998E), const Color(0xFF38EF7D)]); // :155
      expect(stops(ZClassicCardGradientsReference.openQuestion),
          <Color>[const Color(0xFF4FACFE), const Color(0xFF00F2FE)]); // :157
      expect(stops(ZClassicCardGradientsReference.exercise),
          <Color>[const Color(0xFFF093FB), const Color(0xFFF5576C)]); // :159
    });

    test('la table est indexée par NOM de type et borne les types connus', () {
      expect(
        ZClassicCardGradientsReference.typeGradients.keys.toSet(),
        <String>{'multipleChoice', 'trueOrFalse', 'openQuestion', 'exercise'},
      );
      // Un type absent retombe sur l'accent uni du socle (AD-10).
      expect(ZClassicCardGradientsReference.typeGradients['fillBlank'], isNull);
      expect(ZClassicCardGradientsReference.typeGradients['shortAnswer'], isNull);
    });

    test('sens DIRECTIONNEL des quatre dégradés (AD-13)', () {
      for (final ZGradientSpec s
          in ZClassicCardGradientsReference.typeGradients.values) {
        final LinearGradient g = s.gradient as LinearGradient;
        expect(g.begin, AlignmentDirectional.centerStart);
        expect(g.end, AlignmentDirectional.centerEnd);
      }
    });
  });

  group('surfaces — folder_flashcards_repetitions_page.dart', () {
    test('fonds figés', () {
      expect(ZClassicSurfaceReference.darkBackground,
          const Color(0xFF0D1117)); // :239
      expect(ZClassicSurfaceReference.lightBackground,
          const Color(0xFFF8FAFC)); // :239
      // interactive_flashcard_repetition_card.dart:424
      expect(ZClassicSurfaceReference.darkCard, const Color(0xFF1A1F2E));
      expect(ZClassicSurfaceReference.lightCard, const Color(0xFFFFFFFF));
    });

    test('rayons figés', () {
      expect(ZClassicSurfaceReference.heroRadius,
          const Radius.circular(20)); // :282
      expect(ZClassicSurfaceReference.cardRadius,
          const Radius.circular(14)); // :1097
      expect(ZClassicSurfaceReference.tileRadius,
          const Radius.circular(12)); // :1056
      // interactive_flashcard_repetition_card.dart:411, :421, :425 — la carte
      // de révision porte le même rayon à ses trois sites de coin.
      expect(ZClassicSurfaceReference.flashcardCardRadius,
          const Radius.circular(20));
      // Le rayon de la carte de révision et celui des autres cartes sont deux
      // valeurs distinctes du relevé : les confondre reviendrait à n'en avoir
      // relevé qu'une.
      expect(ZClassicSurfaceReference.flashcardCardRadius,
          isNot(ZClassicSurfaceReference.cardRadius));
    });

    test('bandeaux de tête figés', () {
      expect(
        (ZClassicSurfaceReference.heroGradientDark.gradient as LinearGradient)
            .colors,
        <Color>[const Color(0xFF1E3A5F), const Color(0xFF2D5A87)], // :274-275
      );
      expect(
        (ZClassicSurfaceReference.heroGradientLight.gradient as LinearGradient)
            .colors,
        <Color>[const Color(0xFF667EEA), const Color(0xFF764BA2)], // :278-279
      );
    });

    test('la cible tactile est un PLANCHER, jamais réduite (AD-13)', () {
      expect(ZClassicSurfaceReference.minTapTarget, greaterThanOrEqualTo(48.0));
    });

    test('liseré de carte figé — interactive_..._card.dart:430-433', () {
      // `Container(height: 4, …)` coiffant le corps de la carte, peint du
      // dégradé du type. Valeur PUBLIÉE pour la voie paramètre, jamais posée
      // sur le jeton global `ZcrudTheme.accentBarHeight` (cf.
      // `z_classic_unposed_tokens_test.dart`, qui mesure pourquoi).
      expect(ZClassicSurfaceReference.cardAccentHeight, 4);
    });

    test('sélection par luminosité', () {
      expect(ZClassicSurfaceReference.backgroundFor(Brightness.dark),
          ZClassicSurfaceReference.darkBackground);
      expect(ZClassicSurfaceReference.backgroundFor(Brightness.light),
          ZClassicSurfaceReference.lightBackground);
      expect(ZClassicSurfaceReference.cardFor(Brightness.dark),
          ZClassicSurfaceReference.darkCard);
      expect(ZClassicSurfaceReference.heroGradientFor(Brightness.light),
          ZClassicSurfaceReference.heroGradientLight);
    });
  });

  group('célébration — flashcards_learning_celebration_page.dart', () {
    test('six confettis, dans leur ordre d\'origine (:126-131)', () {
      expect(ZClassicCelebrationReference.confetti, <Color>[
        const Color(0xFF667EEA),
        const Color(0xFFFF6B6B),
        const Color(0xFF4ECDC4),
        const Color(0xFFFFE66D),
        const Color(0xFF95E1D3),
        const Color(0xFFF38181),
      ]);
    });

    test('médaille : dégradé à l\'octet (:249), glyphe figé (:260)', () {
      expect(
        (ZClassicCelebrationReference.badgeGradient.gradient as LinearGradient)
            .colors,
        <Color>[const Color(0xFFFFD700), const Color(0xFFFFA500)],
      );
      expect(ZClassicCelebrationReference.badgeIcon, Icons.emoji_events_rounded);
    });

    test('le premier plan de la médaille est CORRIGÉ (le blanc d\'origine '
        'mesurait 1.66:1)', () {
      expect(ZClassicCelebrationReference.badgeGradient.onGradient,
          const Color(0xFF000000));
      expect(ZClassicCelebrationReference.badgeGradient.onGradient,
          isNot(const Color(0xFFFFFFFF))); // :262 — la valeur d'origine
    });
  });

  group('emphase des crans — interactive_..._card.dart:682-692', () {
    test('opacités et épaisseurs figées', () {
      expect(ZClassicTheme.qualityEmphasis.opacityFor(selected: false),
          closeTo(8 / 255, 1e-9));
      expect(ZClassicTheme.qualityEmphasis.opacityFor(selected: true),
          closeTo(20 / 255, 1e-9));
      expect(ZClassicTheme.qualityEmphasis.borderWidthFor(selected: false), 1);
      expect(ZClassicTheme.qualityEmphasis.borderWidthFor(selected: true), 2);
    });
  });
}
