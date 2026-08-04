/// **CR-IFFD-56** — le RENDU DE RÉFÉRENCE des cartes d'item d'étude par
/// défaut, centralisé en UN SEUL endroit (directive owner : « les valeurs de
/// référence IFFD entrent comme DÉFAUTS de jetons/rôles documentés, jamais
/// comme constantes éparpillées dans les widgets »).
///
/// ## La gouvernance (précédent CR-IFFD-41)
///
/// Le design d'IFFD est la référence visuelle du socle : les trois cartes par
/// défaut (document, note, carte mentale) doivent le répliquer **sans aucun
/// réglage** — « un défaut se juge à ce qu'il donne sans aucun réglage ».
/// Le rendu v0.43.0 (tuile colorée) reste **atteignable par réglage**
/// ([ZStudyCardHierarchy.tintedTile]) et sa restitution exacte est gardée par
/// test — mais c'est un réglage, plus un défaut.
///
/// ## Priorité de résolution, partout
///
/// **paramètre de carte > jeton `ZcrudTheme.studyCard*` > défaut-référence**
/// (les défauts-référence sont les constantes de [ZStudyCardReference]).
///
/// ## FR-26 — matière en rôles, toujours (CR-48)
///
/// AUCUNE couleur ici : les seules valeurs figées sont des DIMENSIONS et des
/// scalaires (opacité, graisse). Chaque couleur du rendu de référence est un
/// rôle du `ColorScheme` courant, résolu au rendu par [zStudyCardChromeOf] :
/// tuile `surface`, glyphe neutre/sous-titre `onSurfaceVariant`, liseré
/// `outlineVariant` (à [ZStudyCardReference.borderOpacity]).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZStudyCardHierarchy, ZcrudTheme;

/// Les valeurs de RÉFÉRENCE (mesurées chez IFFD, CR-IFFD-56) — le point
/// d'audit unique. Modifier une valeur ici change le défaut des TROIS cartes.
abstract final class ZStudyCardReference {
  /// Côté de la tuile d'icône de tête (48 dp).
  static const double iconTileSize = 48;

  /// Rayon de la tuile d'icône (12).
  static const Radius iconTileRadius = Radius.circular(12);

  /// Rayon de la carte (16).
  static const Radius cardRadius = Radius.circular(16);

  /// Padding interne de la carte (12, directionnel — AD-13).
  static const EdgeInsetsGeometry contentPadding =
      EdgeInsetsDirectional.all(12);

  /// Marge externe de la carte (4, directionnelle — AD-13).
  static const EdgeInsetsGeometry margin = EdgeInsetsDirectional.all(4);

  /// Opacité du liseré `outlineVariant` (50 %).
  static const double borderOpacity = 0.5;

  /// Épaisseur du liseré (1).
  static const double borderWidth = 1;

  /// Taille de fonte du titre (15, sur `titleMedium`).
  static const double titleFontSize = 15;

  /// Graisse du titre (`w600`).
  static const FontWeight titleFontWeight = FontWeight.w600;

  /// Nombre de lignes du titre (référence : UNE ligne).
  static const int titleMaxLines = 1;

  /// Taille du glyphe dans la tuile (28 — `kStudyToolsLeadingIconSize` du
  /// legacy IFFD ; PAS la taille ambiante de 24).
  static const double glyphSize = 28;

  /// Padding du badge d'extension (4 / 2, directionnel — legacy IFFD).
  static const EdgeInsetsGeometry badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 2);

  /// Taille de fonte du badge d'extension (8, bold — legacy IFFD, appliquée
  /// sur `labelSmall` pour hériter de la famille de l'hôte).
  static const double badgeFontSize = 8;

  /// Graisse du badge d'extension (`bold` — legacy IFFD).
  static const FontWeight badgeFontWeight = FontWeight.bold;
}

/// Chrome de référence RÉSOLU pour une carte d'étude par défaut : chaque champ
/// applique la priorité **paramètre > jeton `studyCard*` > référence** et les
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

  /// Fond de la tuile NEUTRE (rôle `surface`).
  final Color tileColor;

  /// Premier plan d'un glyphe NEUTRE (rôle `onSurfaceVariant`).
  final Color neutralGlyphColor;

  /// Rayon effectif du badge d'extension (surimpression).
  final Radius badgeRadius;

  /// Taille effective du glyphe dans la tuile (référence : 28).
  final double glyphSize;
}

/// Résout le chrome de référence depuis le contexte (rôles du `ColorScheme`)
/// et les jetons `ZcrudTheme.studyCard*`, avec surcharge ponctuelle par les
/// paramètres de la carte. Toute couleur est un RÔLE dérivé (FR-26).
ZStudyCardChrome zStudyCardChromeOf(
  BuildContext context, {
  BorderSide? borderSide,
  Radius? borderRadius,
  EdgeInsetsGeometry? contentPadding,
  EdgeInsetsGeometry? margin,
  TextStyle? titleStyle,
  TextStyle? subtitleStyle,
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
    // Leçon CR-LEX-73 : la marge du `CardTheme` de l'hôte reste ATTEIGNABLE —
    // elle s'intercale entre le jeton et le défaut-référence.
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
  );
}
