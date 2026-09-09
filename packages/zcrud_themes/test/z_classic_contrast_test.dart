library;

// CONTRASTE RECALCULÉ, jamais recopié. La garde n'affirme pas « la valeur est
// celle du fichier » : elle refait le calcul WCAG avec `zContrastRatio` du
// socle et compare aux DEUX planchers (3.0:1 élément graphique, 4.5:1 texte).
//
// Elle mesure aussi la conclusion : le premier plan retenu doit être le
// MEILLEUR des deux candidats achromatiques. Une garde qui vérifierait
// seulement « le ratio est bon » resterait verte si le fichier retenait le
// mauvais candidat mais assez contrasté par chance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZGradientSpec,
        kZNonTextMinContrast,
        kZTextMinContrast,
        zContrastRatio,
        zSignatureForegroundFor,
        zSignatureMidBand;
import 'package:zcrud_session/zcrud_session.dart' show ZAnswerInputReference;
import 'package:zcrud_themes/zcrud_themes.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

void main() {
  group('paliers SRS', () {
    test('le premier plan tient le plancher TEXTE (4.5:1) sur les cinq', () {
      for (final ZClassicSrsStep step in ZClassicSrsPaletteReference.steps) {
        final double ratio = zContrastRatio(step.onColor, step.color);
        expect(
          ratio,
          greaterThanOrEqualTo(kZTextMinContrast),
          reason: '${step.name} : ${ratio.toStringAsFixed(2)}:1 sur '
              '${step.color} — sous le plancher texte.',
        );
      }
    });

    test('le premier plan retenu est le MEILLEUR des deux candidats', () {
      for (final ZClassicSrsStep step in ZClassicSrsPaletteReference.steps) {
        final Color best =
            zContrastRatio(_white, step.color) >= zContrastRatio(_black, step.color)
                ? _white
                : _black;
        expect(step.onColor, best, reason: step.name);
      }
    });

    test('le cran se VOIT sur les deux fonds du thème (3.0:1)', () {
      for (final Color surface in <Color>[
        ZClassicSurfaceReference.lightBackground,
        ZClassicSurfaceReference.darkBackground,
      ]) {
        for (final ZClassicSrsStep step in ZClassicSrsPaletteReference.steps) {
          final double ratio = zContrastRatio(step.color, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(kZNonTextMinContrast),
            reason: '${step.name} sur $surface : '
                '${ratio.toStringAsFixed(2)}:1 — sous le plancher graphique.',
          );
        }
      }
    });
  });

  group('dégradés par type', () {
    Iterable<ZGradientSpec> specs() => <ZGradientSpec>[
          ...ZClassicCardGradientsReference.typeGradients.values,
          ZClassicSurfaceReference.heroGradientDark,
          ZClassicSurfaceReference.heroGradientLight,
          ZClassicCelebrationReference.badgeGradient,
        ];

    test('le premier plan tient 3.0:1 sur la bande médiane', () {
      for (final ZGradientSpec spec in specs()) {
        final List<Color> stops = (spec.gradient as LinearGradient).colors;
        final Color mid = zSignatureMidBand(stops.first, stops.last);
        final double ratio = zContrastRatio(spec.onGradient, mid);
        expect(
          ratio,
          greaterThanOrEqualTo(kZNonTextMinContrast),
          reason: '$stops : ${ratio.toStringAsFixed(2)}:1 sur $mid.',
        );
      }
    });

    test('le premier plan retenu est celui que la MESURE désigne', () {
      for (final ZGradientSpec spec in specs()) {
        final List<Color> stops = (spec.gradient as LinearGradient).colors;
        expect(
          spec.onGradient,
          zSignatureForegroundFor(stops),
          reason: '$stops',
        );
      }
    });
  });

  group('fond de la carte de flashcard', () {
    // Le jeton `flashcardCardBackgroundColor` peint la plus grande surface de
    // l'écran de révision : tout le texte de la carte s'y pose. Le plancher
    // exigé est donc celui du TEXTE (4.5:1), et non celui d'un élément
    // graphique.
    //
    // 🔴 Le premier plan mesuré est celui que l'hôte peint RÉELLEMENT :
    // `onSurface` (corps) et `onSurfaceVariant` (secondaire), pris du
    // `ColorScheme` par défaut de la luminosité. Le thème ne pose aucun de ces
    // deux rôles : ils restent ceux de l'hôte, et c'est bien contre eux que la
    // surface doit tenir.
    //
    // ⚠️ Ce que la garde s'interdit de mesurer : le « meilleur des deux
    // candidats achromatiques ». Vérifié par balayage du cube RGB entier, ce
    // maximum ne descend JAMAIS sous 4.583:1 — une assertion écrite ainsi
    // serait vraie pour toute couleur imaginable, donc verte sans rien
    // mesurer.
    for (final Brightness brightness in Brightness.values) {
      test('le texte de l\'hôte tient 4.5:1 sur le fond ${brightness.name}',
          () {
        final ColorScheme scheme =
            ThemeData(brightness: brightness).colorScheme;
        final Color surface = ZClassicSurfaceReference.cardFor(brightness);
        for (final MapEntry<String, Color> fg in <String, Color>{
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
        }.entries) {
          final double ratio = zContrastRatio(fg.value, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(kZTextMinContrast),
            reason: '${fg.key} ${fg.value} sur $surface : '
                '${ratio.toStringAsFixed(2)}:1 — sous le plancher texte.',
          );
        }
      });
    }

    test('la surface mesurée EST celle que le thème pose vraiment', () {
      // Non-vacuité : sans elle, la garde mesurerait le contraste d'une
      // constante que le thème aurait cessé de poser — verte, et muette sur
      // la couleur réellement peinte.
      for (final Brightness b in Brightness.values) {
        expect(
          ZClassicTheme.forTheme(ThemeData(brightness: b))
              .flashcardCardBackgroundColor
              ?.toARGB32(),
          ZClassicSurfaceReference.cardFor(b).toARGB32(),
          reason: '$b : le contraste vérifié ne porte pas sur la surface que '
              'le thème pose.',
        );
      }
    });

    test('le fond de carte se DISTINGUE du fond de page, dans les deux modes',
        () {
      // Non-vacuité de la mesure précédente : si carte et page portaient la
      // même couleur, le jeton ne peindrait rien de neuf et les deux tests
      // ci-dessus mesureraient la surface déjà en place.
      for (final Brightness b in Brightness.values) {
        expect(
          ZClassicSurfaceReference.cardFor(b).toARGB32(),
          isNot(ZClassicSurfaceReference.backgroundFor(b).toARGB32()),
          reason: '$b : carte et page confondues.',
        );
      }
    });

    test('la carte NE tient PAS 3.0:1 sur sa page — et c\'est le rendu voulu',
        () {
      // Le code de référence sépare la carte de sa page par l'OMBRE et par la
      // bande d'accent de tête, jamais par un écart de luminance. La garde
      // fige ce constat : exiger 3.0:1 ici ferait diverger le thème de sa
      // référence sans qu'aucune règle ne le demande. Le jour où la valeur
      // change au point de tenir le plancher, ce test rougit et l'arbitrage
      // est à refaire — plutôt que de rester tacite.
      expect(
        zContrastRatio(
          ZClassicSurfaceReference.darkCard,
          ZClassicSurfaceReference.darkBackground,
        ),
        lessThan(kZNonTextMinContrast),
      );
    });
  });

  group('surface de saisie — les formes posées par le thème', () {
    // La disposition en tuile et les contrôles à contour introduisent un fond
    // et des traits. Le fond est celui que le thème pose (`surfaceColor`) ; les
    // traits sont des RÔLES de l'hôte, qu'aucun jeton de ce thème n'atteint.
    // La garde mesure les six combinaisons réelles, sépare celles qui portent
    // de l'INFORMATION de celles qui ne font que grouper, et fige l'arbitrage
    // des secondes plutôt que de le laisser tacite.

    /// Le fond réellement lu par la tuile et par les contrôles à contour :
    /// `theme.surfaceColor`, que le thème pose.
    Color fillFor(Brightness b) {
      final Color? posed = ZClassicTheme
          .forTheme(ThemeData(brightness: b))
          .surfaceColor;
      expect(posed, isNotNull,
          reason: '$b : le thème ne pose plus le fond que la tuile lit — la '
              'mesure porterait sur une couleur qui n\'est plus peinte.');
      return posed!;
    }

    for (final Brightness brightness in Brightness.values) {
      test('le TEXTE d\'une tuile tient 4.5:1 en ${brightness.name}', () {
        final ColorScheme scheme = ThemeData(brightness: brightness).colorScheme;
        final Color fill = fillFor(brightness);
        for (final MapEntry<String, Color> fg in <String, Color>{
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
        }.entries) {
          final double ratio = zContrastRatio(fg.value, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(kZTextMinContrast),
            reason: '${fg.key} sur $fill : ${ratio.toStringAsFixed(2)}:1.',
          );
        }
      });

      test('le liseré SÉLECTIONNÉ tient 3.0:1 en ${brightness.name}', () {
        // C'est LUI qui porte l'information : il désigne la ligne choisie.
        final ColorScheme scheme = ThemeData(brightness: brightness).colorScheme;
        final Color fill = fillFor(brightness);
        final double ratio = zContrastRatio(scheme.primary, fill);
        expect(
          ratio,
          greaterThanOrEqualTo(kZNonTextMinContrast),
          reason: 'primary sur $fill : ${ratio.toStringAsFixed(2)}:1 — la '
              'sélection ne se voit plus.',
        );
      });
    }

    test('la sélection reste portée par une FORME, pas par la seule teinte', () {
      // Non-vacuité de l'arbitrage ci-dessous : si l'épaisseur ne changeait
      // pas, la teinte serait le seul canal, et un liseré sous le plancher
      // deviendrait un défaut d'accessibilité au lieu d'un choix de rendu.
      expect(
        ZAnswerInputReference.choiceTileSelectedBorderWidth,
        greaterThan(ZAnswerInputReference.choiceTileBorderWidth),
      );
    });

    test('les traits de GROUPEMENT restent sous 3.0:1 — arbitrage figé', () {
      // Trois traits ne portent aucune information : le pourtour d'une tuile
      // non sélectionnée et les deux pourtours des contrôles d'aide. Ce qui
      // identifie ces éléments est ailleurs — le libellé du contrôle (≥ 9:1
      // mesuré ci-dessus) et, pour la sélection, l'épaisseur du trait.
      //
      // Aucun jeton de ce thème ne les atteint : la tuile lit
      // `scheme.outlineVariant` NU, et les deux contrôles retombent sur des
      // rôles CONTENEUR (pastel par construction, faits pour être des fonds).
      // Le rendu de référence est d'ailleurs plus faible encore sur ce même
      // trait (~1.1:1). Le jour où ces rôles passent le plancher, ce test
      // rougit et l'arbitrage est à refaire — plutôt que de rester tacite.
      for (final Brightness b in Brightness.values) {
        final ColorScheme scheme = ThemeData(brightness: b).colorScheme;
        final Color fill = fillFor(b);
        for (final MapEntry<String, Color> trait in <String, Color>{
          'outlineVariant': scheme.outlineVariant,
          'tertiaryContainer': scheme.tertiaryContainer,
          'errorContainer': scheme.errorContainer,
        }.entries) {
          expect(
            zContrastRatio(trait.value, fill),
            lessThan(kZNonTextMinContrast),
            reason: '$b ${trait.key} : le trait tient désormais le plancher — '
                'ré-arbitrer, la note ci-dessus ne décrit plus le rendu.',
          );
        }
      }
    });
  });

  group('médaille de célébration', () {
    test('le BLANC d\'origine échouait bel et bien le plancher', () {
      // Le calcul qui a motivé la correction, refait ici : si un jour le
      // dégradé change au point que le blanc redevienne acceptable, cette
      // assertion rougit et la correction sera à ré-arbitrer — plutôt que de
      // rester en place sans plus rien mesurer.
      final List<Color> stops =
          (ZClassicCelebrationReference.badgeGradient.gradient as LinearGradient)
              .colors;
      final Color mid = zSignatureMidBand(stops.first, stops.last);
      expect(zContrastRatio(_white, mid), lessThan(kZNonTextMinContrast));
    });
  });
}
