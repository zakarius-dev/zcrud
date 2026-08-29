/// Rendu de référence des cartes d'item d'étude par défaut, centralisé en un
/// seul endroit — les valeurs de référence entrent comme défauts de
/// jetons/rôles documentés, jamais comme constantes éparpillées dans les
/// widgets.
///
/// ## La gouvernance
///
/// Le rendu de référence est la référence visuelle du socle : les trois
/// cartes par défaut (document, note, carte mentale) doivent le répliquer
/// sans aucun réglage — un défaut se juge à ce qu'il donne sans aucun
/// réglage. Un rendu antérieur (tuile colorée) reste atteignable par réglage
/// ([ZStudyCardHierarchy.tintedTile]) et sa restitution exacte est gardée
/// par test — mais c'est un réglage, plus un défaut.
///
/// ## Priorité de résolution, partout
///
/// paramètre de carte > jeton `ZcrudTheme.studyCard*` > défaut-référence
/// (les défauts-référence sont les constantes de [ZStudyCardReference]).
///
/// ## Invariant FR-26 — matière en rôles, toujours
///
/// Aucune couleur ici : les seules valeurs figées sont des dimensions et des
/// scalaires (opacité, graisse). Chaque couleur du rendu de référence est un
/// rôle du `ColorScheme` courant, résolu au rendu par [zStudyCardChromeOf] :
/// tuile `surface`, glyphe neutre/sous-titre `onSurfaceVariant`, liseré
/// `outlineVariant` (à [ZStudyCardReference.borderOpacity]).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZStudyCardHierarchy, ZcrudTheme;

/// Les valeurs de référence (mesurées sur le rendu historique du socle) — le
/// point d'audit unique. Modifier une valeur ici change le défaut des trois
/// cartes.
abstract final class ZStudyCardReference {
  /// Côté de la tuile d'icône de tête (48 dp).
  static const double iconTileSize = 48;

  /// Rayon de la tuile d'icône (12).
  static const Radius iconTileRadius = Radius.circular(12);

  /// Rayon de la carte (16).
  ///
  /// **Le rayon de la famille « cartes d'outils » est 16, et non 12.** Le 12
  /// dominant ailleurs appartient à d'autres familles (chips, dialogues,
  /// badges, carte de dossier — dont le rayon de référence est bien 12, cf.
  /// `ZFolderCardReference.cardRadius`). Confondre les deux alignerait la
  /// carte d'outils sur le vécu d'une famille voisine.
  static const Radius cardRadius = Radius.circular(16);

  /// Padding interne de la carte (12, directionnel — invariant AD-13).
  static const EdgeInsetsGeometry contentPadding =
      EdgeInsetsDirectional.all(12);

  /// Écart entre la tuile d'icône de tête et le titre (16 — mesuré sur le
  /// rendu historique).
  ///
  /// Distinct du padding de carte (12) : les deux ridaient le même jeton
  /// `gapM`, donc aucune valeur ne pouvait satisfaire les deux. Mesuré : la
  /// carte par défaut rendait `gapM` (8 en thème nu, 12 sous un thème plus
  /// dense) là où la référence pose 16.
  static const double leadingGap = 16;

  /// Élévation Material de la carte (0 — mesurée sur le rendu historique).
  ///
  /// Ce que ce défaut corrige, mesuré : sans élévation explicite, `Card`
  /// retombe sur le défaut Material 3 (1.0) et porte une ombre portée
  /// que la référence n'a pas. Capture de pixels comparée (carte par défaut vs
  /// réplique littérale du rendu historique) : les deux rendus étaient
  /// byte-identiques sur toute la face de la carte — la seule divergence
  /// était la bande de 1 dp juste hors de la face, noire à la carte par
  /// défaut, transparente au rendu historique. C'est cette ombre qui
  /// assombrit les pixels autour de la tête de carte, et non un accent
  /// (l'accent n'existe que dans la hiérarchie `tintedTile`, jamais au
  /// défaut — mesuré par absence de clé dans l'arbre).
  static const double cardElevation = 0;

  /// Marge externe de la carte (4, directionnelle — invariant AD-13).
  static const EdgeInsetsGeometry margin = EdgeInsetsDirectional.all(4);

  /// Opacité du liseré `outlineVariant` (50 %).
  static const double borderOpacity = 0.5;

  /// Épaisseur du liseré (1).
  static const double borderWidth = 1;

  /// Taille de fonte du titre (15, sur `titleMedium`).
  static const double titleFontSize = 15;

  /// Graisse du titre (`w600`).
  static const FontWeight titleFontWeight = FontWeight.w600;

  /// Nombre de lignes du titre (référence : une ligne).
  static const int titleMaxLines = 1;

  /// Taille du glyphe dans la tuile (28 — mesurée sur le rendu historique ;
  /// pas la taille ambiante de 24).
  static const double glyphSize = 28;

  /// Padding du badge d'extension (4 / 2, directionnel — mesuré sur le rendu
  /// historique).
  static const EdgeInsetsGeometry badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 2);

  /// Taille de fonte du badge d'extension (8, bold — mesurée sur le rendu
  /// historique, appliquée sur `labelSmall` pour hériter de la famille de
  /// l'hôte).
  static const double badgeFontSize = 8;

  /// Graisse du badge d'extension (`bold` — mesurée sur le rendu
  /// historique).
  static const FontWeight badgeFontWeight = FontWeight.bold;

  // ── En-tête de section d'étude ────────────────────────────────────────────
  //
  // Ces trois valeurs sont les MÊMES que les défauts des jetons
  // `ZcrudTheme.sectionHeader*` du cœur : un en-tête de section d'étude et un
  // en-tête de section de formulaire ne doivent pas diverger d'un pixel quand
  // aucun jeton n'est posé. Elles sont répétées ici comme repli explicite —
  // le jeton, lui, reste la voie de remplacement.

  /// Hauteur de la bande d'accent d'un en-tête de section (**3**).
  static const double sectionAccentHeight = 3;

  /// Côté de la tuile d'icône d'un en-tête de section (**36**).
  static const double sectionIconTileSize = 36;

  /// Rayon de la tuile d'icône d'un en-tête de section (**10**).
  static const double sectionIconTileRadius = 10;

  // ── Ombre TEINTÉE d'une surface en dégradé ────────────────────────────────
  //
  // Aucune couleur ici : seuls l'opacité, le flou et le décalage sont figés.
  // La TEINTE est celle du dégradé courant, donc nulle sous un profil qui ne
  // peint aucun dégradé — l'ombre disparaît alors avec lui.

  /// Opacité de l'ombre teintée d'une surface en dégradé (**0.4**).
  static const double tintedShadowAlpha = 0.4;

  /// Flou de l'ombre teintée (**20**).
  static const double tintedShadowBlurRadius = 20;

  /// Décalage de l'ombre teintée (**0, 8**).
  static const Offset tintedShadowOffset = Offset(0, 8);
}

/// Chrome de référence résolu pour une carte d'étude par défaut : chaque champ
/// applique la priorité paramètre > jeton `studyCard*` > référence et les
/// rôles du `ColorScheme` courant. Produit par [zStudyCardChromeOf].
@immutable
class ZStudyCardChrome {
  /// Construit un chrome résolu (usage interne aux cartes par défaut).
  const ZStudyCardChrome({
    required this.borderSide,
    required this.borderRadius,
    required this.contentPadding,
    required this.margin,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.iconTileSize,
    required this.iconTileRadius,
    required this.tileColor,
    required this.neutralGlyphColor,
    required this.badgeRadius,
    required this.glyphSize,
    required this.leadingGap,
    required this.elevation,
  });

  /// Liseré effectif de la carte.
  final BorderSide borderSide;

  /// Rayon effectif de la carte.
  final Radius borderRadius;

  /// Padding interne effectif.
  final EdgeInsetsGeometry contentPadding;

  /// Marge externe effective.
  final EdgeInsetsGeometry margin;

  /// Style effectif du titre.
  final TextStyle? titleStyle;

  /// Style effectif du sous-titre.
  final TextStyle? subtitleStyle;

  /// Côté effectif de la tuile d'icône.
  final double iconTileSize;

  /// Rayon effectif de la tuile d'icône.
  final Radius iconTileRadius;

  /// Fond de la tuile neutre (rôle `surface`).
  final Color tileColor;

  /// Premier plan d'un glyphe neutre (rôle `onSurfaceVariant`).
  final Color neutralGlyphColor;

  /// Rayon effectif du badge d'extension (surimpression).
  final Radius badgeRadius;

  /// Taille effective du glyphe dans la tuile (référence : 28).
  final double glyphSize;

  /// Écart effectif tuile→titre (référence : 16).
  final double leadingGap;

  /// Élévation Material effective de la carte (référence : 0 — aucune ombre
  /// portée, liseré seul).
  final double elevation;
}

/// Résout le chrome de référence depuis le contexte (rôles du `ColorScheme`)
/// et les jetons `ZcrudTheme.studyCard*`, avec surcharge ponctuelle par les
/// paramètres de la carte. Toute couleur est un rôle dérivé (invariant
/// FR-26).
ZStudyCardChrome zStudyCardChromeOf(
  BuildContext context, {
  BorderSide? borderSide,
  Radius? borderRadius,
  EdgeInsetsGeometry? contentPadding,
  EdgeInsetsGeometry? margin,
  TextStyle? titleStyle,
  TextStyle? subtitleStyle,
  double? leadingGap,
  double? elevation,
}) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  final ThemeData material = Theme.of(context);
  final ColorScheme scheme = material.colorScheme;
  final TextTheme text = material.textTheme;
  return ZStudyCardChrome(
    borderSide: borderSide ??
        theme.studyCardBorderSide ??
        BorderSide(
          color: scheme.outlineVariant
              .withValues(alpha: ZStudyCardReference.borderOpacity),
          width: ZStudyCardReference.borderWidth,
        ),
    borderRadius: borderRadius ??
        theme.studyCardRadius ??
        ZStudyCardReference.cardRadius,
    contentPadding: contentPadding ??
        theme.studyCardContentPadding ??
        ZStudyCardReference.contentPadding,
    // La marge du `CardTheme` de l'hôte reste atteignable — elle s'intercale
    // entre le jeton et le défaut-référence.
    margin: margin ??
        theme.studyCardMargin ??
        CardTheme.of(context).margin ??
        ZStudyCardReference.margin,
    titleStyle: titleStyle ??
        theme.studyCardTitleStyle ??
        text.titleMedium?.copyWith(
          fontWeight: ZStudyCardReference.titleFontWeight,
          fontSize: ZStudyCardReference.titleFontSize,
        ),
    subtitleStyle: subtitleStyle ??
        theme.studyCardSubtitleStyle ??
        text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    iconTileSize:
        theme.studyCardIconTileSize ?? ZStudyCardReference.iconTileSize,
    iconTileRadius:
        theme.studyCardIconTileRadius ?? ZStudyCardReference.iconTileRadius,
    tileColor: scheme.surface,
    neutralGlyphColor: scheme.onSurfaceVariant,
    badgeRadius: theme.studyCardBadgeRadius ?? theme.radiusS,
    glyphSize: theme.studyCardGlyphSize ?? ZStudyCardReference.glyphSize,
    // L'écart tuile→titre cesse de rider `gapM`. La primitive de base garde
    // `gapM` (neutralité pour les hôtes qui la composent eux-mêmes) ; c'est
    // le chrome des cartes par défaut qui porte la référence, parce que
    // « le défaut est la référence » ne vaut que des cartes par défaut.
    leadingGap: leadingGap ??
        theme.studyCardLeadingGap ??
        ZStudyCardReference.leadingGap,
    // Élévation 0 = référence (liseré seul). Le défaut antérieur laissait
    // `Card` retomber sur l'élévation M3 (1.0), donc sur une ombre portée
    // absente du rendu historique.
    elevation: elevation ??
        theme.studyCardElevation ??
        ZStudyCardReference.cardElevation,
  );
}
