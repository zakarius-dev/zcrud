/// **CR-IFFD-57** — le RENDU DE RÉFÉRENCE de la carte de flashcard par défaut,
/// centralisé en UN SEUL endroit (patron [ZStudyCardReference], CR-IFFD-56).
///
/// ## ⚠️ Exception FR-26 ENCADRÉE (arbitrage owner, 2026-08-04)
///
/// Ce fichier est le **SEUL** du package autorisé à porter des couleurs
/// littérales : les **quatre paires de dégradé par type** de la référence
/// legacy IFFD (`flashcard_widgets.dart:143-156`, vérifiées SUR PIÈCES) ne
/// sont **pas dérivables** d'un `ColorScheme` — « un dégradé n'est pas un rôle
/// de `ColorScheme` » (CR-IFFD-57). Les trois conditions de l'exception :
///
/// 1. **Centralisation** : toutes les valeurs vivent ici, dans l'unique
///    fichier de référence audité de la famille « carte de flashcard » ;
/// 2. **Remplaçabilité** : chaque dégradé est remplaçable par **paramètre**
///    (`ZDefaultFlashcardCard.typeColors`) ET par **thème** (jeton
///    `ZcrudTheme.flashcardTypeGradients`, puis seam
///    `ZcrudScope.gradientResolver`) — priorité paramètre > jeton > seam >
///    référence ;
/// 3. **Exemption nominative** : la garde de source anti-couleurs
///    (`z_widgets_hardcode_scan_test.dart`) exempte CE fichier et lui seul,
///    par chemin exact — jamais un motif large.
///
/// Toute couleur **dérivable** de la référence reste un RÔLE (CR-48) : fond de
/// carte `scaffoldBackgroundColor`, liseré `outline`, ombre `shadow` — aucun
/// hex ici pour elles.
///
/// ## `onGradient` — CHOISI par mesure, jamais deviné
///
/// Le premier plan posé sur chaque dégradé est celui des deux candidats
/// (blanc/noir) dont le **contraste WCAG minimal sur les DEUX extrémités** est
/// le plus élevé — les dégradés étant des constantes, la mesure vaut dans les
/// deux luminosités. Ratios mesurés (relative luminance WCAG 2.x) :
///
/// | type           | blanc (min des 2 stops) | noir (min) | choisi |
/// |----------------|-------------------------|------------|--------|
/// | multipleChoice | **3.66**                | 3.30       | blanc  |
/// | trueOrFalse    | 1.52                    | **5.97**   | noir   |
/// | openQuestion   | 1.39                    | **8.66**   | noir   |
/// | exercise       | 2.04                    | **6.46**   | noir   |
///
/// Le pire cas retenu (3.66) satisfait le seuil WCAG **3.0** (texte large /
/// composants) ; la garde `cr_iffd57_flashcard_card_test.dart` recalcule ces
/// luminances et rougit si une valeur d'ici cesse de le satisfaire.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;

/// Les valeurs de RÉFÉRENCE de la carte de flashcard (mesurées chez IFFD,
/// `flashcard_widgets.dart:88-156, 265-340` — CR-IFFD-57), le point d'audit
/// unique. Modifier une valeur ici change le défaut de la carte partout.
abstract final class ZFlashcardCardReference {
  // ── Dégradés par type (exception FR-26 encadrée — cf. dartdoc de tête) ────

  /// `multipleChoice` : `#667eea → #764ba2` (violet). Premier plan **blanc**
  /// (contraste min mesuré 3.66 contre 3.30 pour le noir).
  static const ZGradientSpec multipleChoiceGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    onGradient: Color(0xFFFFFFFF),
  );

  /// `trueOrFalse` : `#11998e → #38ef7d` (vert). Premier plan **noir**
  /// (contraste min mesuré 5.97 contre 1.52 pour le blanc).
  static const ZGradientSpec trueOrFalseGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// `openQuestion` : `#4facfe → #00f2fe` (cyan). Premier plan **noir**
  /// (contraste min mesuré 8.66 contre 1.39 pour le blanc).
  static const ZGradientSpec openQuestionGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// `exercise` : `#f093fb → #f5576c` (rose). Premier plan **noir**
  /// (contraste min mesuré 6.46 contre 2.04 pour le blanc).
  static const ZGradientSpec exerciseGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFF093FB), Color(0xFFF5576C)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// Table de référence `ZFlashcardType.name → dégradé` — le DERNIER maillon
  /// de la chaîne de résolution (paramètre > jeton > seam > **ici**). Une clé
  /// inconnue (type futur) rend `null` : la carte replie alors sur l'accent
  /// uni dérivé de `colorKey`/`palette` (chaîne TOTALE, AD-10).
  static const Map<String, ZGradientSpec> typeGradients =
      <String, ZGradientSpec>{
    'multipleChoice': multipleChoiceGradient,
    'trueOrFalse': trueOrFalseGradient,
    'openQuestion': openQuestionGradient,
    'exercise': exerciseGradient,
  };

  // ── Chrome de carte (dimensions et scalaires — jamais des couleurs) ───────

  /// Hauteur de la bande dégradée de tête (4).
  static const double accentBandHeight = 4;

  /// Hauteur FIXE de la carte (200 — legacy `SizedBox(height: 200)`,
  /// `flashcard_widgets.dart:196`). C'est elle qui rend la grille régulière et
  /// confortable : toutes les cartes d'une rangée ont la même hauteur, quel
  /// que soit leur contenu. `ZDefaultFlashcardCard.height: null` la désactive
  /// (hauteur intrinsèque).
  static const double cardHeight = 200;

  /// Rayon de la carte (12 — distinct du 16 des cartes d'étude CR-IFFD-56).
  static const Radius cardRadius = Radius.circular(12);

  /// Épaisseur du liseré (1 ; couleur = rôle `outline`, jamais un hex).
  static const double borderWidth = 1;

  /// Flou de l'ombre douce (8).
  static const double shadowBlurRadius = 8;

  /// Décalage de l'ombre douce (0, 2).
  static const Offset shadowOffset = Offset(0, 2);

  /// Opacité de l'ombre en thème CLAIR (0.06 ; couleur = rôle `shadow`).
  static const double shadowAlphaLight = 0.06;

  /// Opacité de l'ombre en thème SOMBRE (0.2).
  static const double shadowAlphaDark = 0.2;

  // ── Tuile d'icône ─────────────────────────────────────────────────────────

  /// Côté de la tuile d'icône (32 — legacy, PAS le 48 des cartes d'étude).
  static const double iconTileSize = 32;

  /// Rayon de la tuile d'icône (8).
  static const Radius iconTileRadius = Radius.circular(8);

  /// Opacité de la teinte de la tuile (15 % de la couleur primaire du type).
  static const double iconTileTintAlpha = 0.15;

  /// Taille du glyphe dans la tuile (18).
  static const double glyphSize = 18;

  /// Glyphe de référence de la carte (`flash_on_rounded` — legacy).
  static const IconData glyph = Icons.flash_on_rounded;

  // ── Pastille de type en pied (point + libellé teintés) ────────────────────

  /// Padding de la pastille (6 / 3, directionnel — AD-13).
  static const EdgeInsetsGeometry typePillPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 3);

  /// Opacité du fond de la pastille (10 % de la couleur primaire du type).
  static const double typePillBackgroundAlpha = 0.10;

  /// Rayon de la pastille (6).
  static const Radius typePillRadius = Radius.circular(6);

  /// Diamètre du point dégradé de la pastille (6).
  static const double typePillDotSize = 6;

  /// Espace entre le point et le libellé (4).
  static const double typePillGap = 4;

  /// Graisse du libellé de type (`w500` — legacy).
  static const FontWeight typeLabelFontWeight = FontWeight.w500;
}
