/// Rendu de référence de la carte de flashcard par défaut, centralisé en un
/// seul endroit (même patron que [ZStudyCardReference]).
///
/// ## Exception invariant FR-26 encadrée
///
/// Ce fichier est le seul du package autorisé à porter des couleurs
/// littérales : les quatre paires de dégradé par type du rendu de
/// référence historique (vérifiées sur pièces) ne sont pas dérivables
/// d'un `ColorScheme` — un dégradé n'est pas un rôle de `ColorScheme`. Les
/// trois conditions de l'exception :
///
/// 1. Centralisation : toutes les valeurs vivent ici, dans l'unique
///    fichier de référence audité de la famille « carte de flashcard » ;
/// 2. Remplaçabilité : chaque dégradé est remplaçable par paramètre
///    (`ZDefaultFlashcardCard.typeColors`) et par thème (jeton
///    `ZcrudTheme.flashcardTypeGradients`, puis seam
///    `ZcrudScope.gradientResolver`) — priorité paramètre > jeton > seam >
///    référence ;
/// 3. Exemption nominative : la garde de source anti-couleurs
///    exempte ce fichier et lui seul, par chemin exact — jamais un motif
///    large.
///
/// Toute couleur dérivable de la référence reste un rôle : fond de
/// carte `scaffoldBackgroundColor`, liseré `outline`, ombre `shadow` — aucun
/// hex ici pour elles.
///
/// ## `onGradient` — choisi par mesure, jamais deviné
///
/// Le premier plan posé sur chaque dégradé est celui des deux candidats
/// (blanc/noir) dont le contraste WCAG minimal sur les deux extrémités est
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
/// Le pire cas retenu (3.66) satisfait le seuil WCAG 3.0 (texte large /
/// composants) ; une garde dédiée recalcule ces luminances et rougit si une
/// valeur d'ici cesse de le satisfaire.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, ZStudyCardContentAlignment;

/// Les valeurs de référence de la carte de flashcard (mesurées sur le rendu
/// historique du socle), le point d'audit unique. Modifier une valeur ici
/// change le défaut de la carte partout.
abstract final class ZFlashcardCardReference {
  // ── Dégradés par type (exception FR-26 encadrée — cf. dartdoc de tête) ────

  /// `multipleChoice` : `#667eea → #764ba2` (violet). Premier plan blanc
  /// (contraste min mesuré 3.66 contre 3.30 pour le noir).
  static const ZGradientSpec multipleChoiceGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    onGradient: Color(0xFFFFFFFF),
  );

  /// `trueOrFalse` : `#11998e → #38ef7d` (vert). Premier plan noir
  /// (contraste min mesuré 5.97 contre 1.52 pour le blanc).
  static const ZGradientSpec trueOrFalseGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// `openQuestion` : `#4facfe → #00f2fe` (cyan). Premier plan noir
  /// (contraste min mesuré 8.66 contre 1.39 pour le blanc).
  static const ZGradientSpec openQuestionGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// `exercise` : `#f093fb → #f5576c` (rose). Premier plan noir
  /// (contraste min mesuré 6.46 contre 2.04 pour le blanc).
  static const ZGradientSpec exerciseGradient = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFF093FB), Color(0xFFF5576C)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// Table de référence `ZFlashcardType.name → dégradé` — le dernier maillon
  /// de la chaîne de résolution (paramètre > jeton > seam > ici). Une clé
  /// inconnue (type futur) rend `null` : la carte replie alors sur l'accent
  /// uni dérivé de `colorKey`/`palette` (chaîne totale, invariant AD-10).
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

  /// Hauteur fixe de la carte (200 — mesurée sur le rendu historique).
  /// C'est elle qui rend la grille régulière et confortable : toutes les
  /// cartes d'une rangée ont la même hauteur, quel que soit leur contenu.
  /// `ZDefaultFlashcardCard.height: null` la désactive (hauteur intrinsèque).
  static const double cardHeight = 200;

  /// Rayon de la carte (12 — distinct du 16 des cartes d'étude).
  static const Radius cardRadius = Radius.circular(12);

  /// Épaisseur du liseré (1 ; couleur = rôle `outline`, jamais un hex).
  static const double borderWidth = 1;

  /// Flou de l'ombre douce (8).
  static const double shadowBlurRadius = 8;

  /// Décalage de l'ombre douce (0, 2).
  static const Offset shadowOffset = Offset(0, 2);

  /// Opacité de l'ombre en thème clair (0.06 ; couleur = rôle `shadow`).
  static const double shadowAlphaLight = 0.06;

  /// Opacité de l'ombre en thème sombre (0.2).
  static const double shadowAlphaDark = 0.2;

  // ── Tuile d'icône ─────────────────────────────────────────────────────────

  /// Côté de la tuile d'icône (32 — mesuré sur le rendu historique, pas le
  /// 48 des cartes d'étude).
  static const double iconTileSize = 32;

  /// Rayon de la tuile d'icône (8).
  static const Radius iconTileRadius = Radius.circular(8);

  /// Opacité de la teinte de la tuile (15 % de la couleur primaire du type).
  static const double iconTileTintAlpha = 0.15;

  /// Taille du glyphe dans la tuile (18).
  static const double glyphSize = 18;

  /// Glyphe de référence de la carte (`flash_on_rounded` — mesuré sur le
  /// rendu historique).
  static const IconData glyph = Icons.flash_on_rounded;

  // ── Pastille de type en pied (point + libellé teintés) ────────────────────

  /// Padding de la pastille (6 / 3, directionnel — invariant AD-13).
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

  /// Graisse du libellé de type (`w500` — mesurée sur le rendu historique).
  static const FontWeight typeLabelFontWeight = FontWeight.w500;

  // ── Énoncé (13/w600, hauteur bornée, rendu riche) ─────────────────────────

  /// Corps de l'énoncé (13 — mesuré sur le rendu historique). Appliqué au
  /// rendu riche par mise à l'échelle
  /// (`questionFontSize / quillBaseFontSize`) composée avec le
  /// `TextScaler` ambiant — jamais un `fontSize:` littéral (a11y).
  static const double questionFontSize = 13;

  /// Graisse de l'énoncé (`w600` — mesurée sur le rendu historique).
  static const FontWeight questionFontWeight = FontWeight.w600;

  /// Hauteur maximale de l'énoncé (`kToolbarHeight × 0.65` — mesurée sur le
  /// rendu historique). C'est la borne de hauteur du rendu historique
  /// (jamais un `maxLines` : le rendu riche n'a pas de notion de ligne).
  static const double questionMaxHeight = kToolbarHeight * 0.65;

  /// Étendue du fondu de continuation appliqué au bas de l'énoncé quand
  /// il déborde sa borne (12 dp).
  ///
  /// Ce n'est pas une valeur du rendu historique : celui-ci ne signalait
  /// rien (le texte était coupé net en milieu de ligne). C'est une valeur de
  /// socle, choisie ≈ à la hauteur d'une ligne du corps de référence
  /// (13 × 1.15 ≈ 15) pour que l'effacement porte sur la dernière ligne
  /// visible et se lise comme « ça continue », sans manger une ligne
  /// entière. Réglable par paramètre de carte.
  static const double questionFadeExtent = 12;

  /// Alignement vertical de référence du contenu de la carte : `spread` —
  /// l'énoncé absorbe l'espace libre du cadre et pousse la pastille de
  /// type au bas de la carte. C'est la cascade des deux `Expanded` du rendu
  /// historique.
  static const ZStudyCardContentAlignment contentAlignment =
      ZStudyCardContentAlignment.spread;

  /// Corps de paragraphe de base du moteur rich-text (Quill fixe 16,
  /// mesuré sur pièces). Sert uniquement de dénominateur à la mise à
  /// l'échelle vers [questionFontSize].
  static const double quillBaseFontSize = 16;

  // ── Aperçu de réponse ──────────────────────────────────────────

  /// Hauteur du `Divider` qui sépare l'énoncé de l'aperçu (12 — mesurée sur
  /// le rendu historique ; couleur = rôle `outlineVariant`).
  static const double answerDividerHeight = 12;

  /// Largeur du tampon « Vrai »/« Faux » (200 — mesurée sur le rendu
  /// historique).
  static const double stampWidth = 200;

  /// Hauteur du tampon (40 — mesurée sur le rendu historique).
  static const double stampHeight = 40;

  /// Rotation du tampon en radians (−0.45 — mesurée sur le rendu
  /// historique).
  static const double stampRotationRadians = -0.45;

  /// Translation verticale du tampon, appliquée après la rotation (40 —
  /// mesurée sur le rendu historique).
  static const double stampTranslationY = 40;

  /// Opacité du fond du tampon (mesurée sur le rendu historique, 100/255).
  static const double stampBackgroundAlpha = 100 / 255;

  /// Rayon du tampon (12 — mesuré sur le rendu historique).
  static const Radius stampRadius = Radius.circular(12);

  // ── Liseré teinté par type ──────────────────────────────

  /// Opacité du liseré teinté par type de la carte (au lieu d'une bordure
  /// grise entière, une bordure très fine légèrement colorée en fonction du
  /// type — la bande épaisse de tête reste). Le rendu historique peignait
  /// une couleur grise neutre ; ici la couleur primaire du type à cette
  /// opacité, surchargeable par `ZDefaultFlashcardCard.borderSide`.
  static const double borderTintAlpha = 0.35;

  /// Couleur de neutralisation du liseré de champ du lecteur rich-text
  /// (alpha 0 — aucune couleur « nouvelle » : elle ne peint rien). Le lecteur
  /// `ZMarkdownReader` dessine toujours un liseré de champ ; dans la carte,
  /// l'énoncé n'est pas un champ — ce jeton l'éteint sans toucher au layout
  /// (le `DecoratedBox` du lecteur ne réserve aucune place au trait).
  static const Color neutralizedFieldBorder = Color(0x00000000);
}
