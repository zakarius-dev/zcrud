/// Carte de document d'étude, composée sur le chrome commun des outils.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZStudyCardContentAlignment;

import 'z_study_tools_item_card.dart';

/// Représentation compacte d'un document dans les outils d'étude.
///
/// Les données métier, les icônes, les libellés localisés et les droits restent
/// chez l'hôte. Cette façade délègue intégralement le chrome et son accessibilité
/// à [ZStudyToolsItemCard].
///
/// ## C'est un **passe-plat**, et rien d'autre (CR-LEX-78)
///
/// Chaque paramètre est transmis **tel quel** à [ZStudyToolsItemCard] : aucune
/// logique, aucune valeur par défaut inventée ici. La seule valeur ajoutée est
/// le repli de [semanticLabel] ([title], complété de [subtitle] quand il est
/// fourni). Les défauts de [progressMaxWidth], [hidesTrailingWhileBusy] et
/// [titleMaxLines] sont **recopiés à l'identique** de ceux du socle, pour que
/// passer par la façade et passer par la voie directe rendent la même chose.
///
/// **Tout nouveau slot ajouté à [ZStudyToolsItemCard] DOIT être répercuté
/// ici** — sinon la façade redevient **plus pauvre** que la voie directe, et
/// l'hôte qui l'adopte perd silencieusement une capacité.
///
/// C'est exactement ce qui s'est produit entre CR-LEX-67 et CR-LEX-70..75 : la
/// façade répondait à la demande telle qu'elle était écrite, les CR suivantes
/// ont déplacé la cible, et personne n'est revenu vérifier que la première
/// réponse tenait encore. Une garde de source (`cr_lex_78_*_test.dart`) compare
/// désormais la surface des deux façades à celle du socle et **rougit** au
/// premier slot oublié : ne la contourne pas, complète la façade.
class ZStudyDocumentCard extends StatelessWidget {
  /// Construit une carte de document ; seul [title] est requis.
  const ZStudyDocumentCard({
    required this.title,
    this.leading,
    this.aboveTitle,
    this.subtitle,
    this.belowSubtitle,
    this.metadata,
    this.actions,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.onLongPress,
    this.borderSide,
    this.borderRadius,
    this.color,
    this.defaultShadow,
    this.accent,
    this.semanticLabel,
    this.contentPadding,
    this.margin,
    this.titleWidget,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    this.leadingGap,
    this.elevation,
    this.contentAlignment,
    super.key,
  });

  /// Titre du document. Voir [ZStudyToolsItemCard.title].
  final String title;

  /// Icône ou vignette de tête. Voir [ZStudyToolsItemCard.leading].
  final Widget? leading;

  /// Libellé secondaire. Voir [ZStudyToolsItemCard.subtitle].
  final String? subtitle;

  /// Contenu rendu sous [subtitle]. Voir [ZStudyToolsItemCard.belowSubtitle].
  final Widget? belowSubtitle;

  /// Contenu au-dessus du titre (CR-IFFD-47). Voir
  /// [ZStudyToolsItemCard.aboveTitle] — passe-plat, aucun défaut local.
  final Widget? aboveTitle;

  /// Qualificatif court, transmis à [ZStudyToolsItemCard.badge].
  final Widget? metadata;

  /// Zone d'actions, transmise à [ZStudyToolsItemCard.trailing].
  final Widget? actions;

  /// Indicateur de traitement. Voir [ZStudyToolsItemCard.progress].
  final Widget? progress;

  /// Largeur maximale du slot [progress]. Voir
  /// [ZStudyToolsItemCard.progressMaxWidth].
  final double progressMaxWidth;

  /// Politique d'éviction de [actions] pendant un traitement. Voir
  /// [ZStudyToolsItemCard.hidesTrailingWhileBusy].
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. Voir [ZStudyToolsItemCard.onTap].
  final VoidCallback? onTap;

  /// Appui long (CR-IFFD-47). Voir [ZStudyToolsItemCard.onLongPress] —
  /// passe-plat, aucun défaut local.
  final VoidCallback? onLongPress;

  /// Contour explicite. Voir [ZStudyToolsItemCard.borderSide].
  final BorderSide? borderSide;

  /// Rayon d'angle explicite (CR-IFFD-56). Voir
  /// [ZStudyToolsItemCard.borderRadius] — passe-plat, aucun défaut local.
  final Radius? borderRadius;

  /// Passe-plat du fond explicite du socle (CR-IFFD-57 / CR-LEX-78).
  final Color? color;

  /// Passe-plat de l'ombre de repli du socle (CR-IFFD-57 / CR-LEX-78).
  final BoxDecoration? defaultShadow;

  /// Décor d'accent superposé. Voir [ZStudyToolsItemCard.accent].
  final Widget? accent;

  /// Libellé sémantique de la carte entière. `null` ⇒ [title], complété de
  /// [subtitle] quand il est fourni.
  final String? semanticLabel;

  /// Marge intérieure. Voir [ZStudyToolsItemCard.contentPadding].
  final EdgeInsetsGeometry? contentPadding;

  /// Marge extérieure. Voir [ZStudyToolsItemCard.margin].
  final EdgeInsetsGeometry? margin;

  /// Style du titre. Voir [ZStudyToolsItemCard.titleStyle].
  final TextStyle? titleStyle;

  /// Rendu RICHE du titre (passe-plat `ZStudyToolsItemCard.titleWidget`,
  /// CR-IFFD-59) — `title` reste la source sémantique.
  final Widget? titleWidget;

  /// Style du sous-titre. Voir [ZStudyToolsItemCard.subtitleStyle].
  final TextStyle? subtitleStyle;

  /// Nombre maximal de lignes du titre. Voir
  /// [ZStudyToolsItemCard.titleMaxLines].
  final int titleMaxLines;

  /// Écart tuile→titre (CR-IFFD-61 ①). Voir
  /// [ZStudyToolsItemCard.leadingGap] — passe-plat, aucun défaut local.
  final double? leadingGap;

  /// Élévation Material (CR-IFFD-61 ②). Voir
  /// [ZStudyToolsItemCard.elevation] — passe-plat, aucun défaut local.
  final double? elevation;

  /// [ZStudyToolsItemCard.contentAlignment] — passe-plat, aucun défaut local
  /// (**CR-IFFD-62 ④**). `null` ⇒ rendu strictement inchangé ; sans hauteur
  /// imposée, ce slot n'a de toute façon aucun effet.
  final ZStudyCardContentAlignment? contentAlignment;

  @override
  Widget build(BuildContext context) => ZStudyToolsItemCard(
    title: title,
    leading: leading,
    subtitle: subtitle,
    aboveTitle: aboveTitle,
    belowSubtitle: belowSubtitle,
    badge: metadata,
    trailing: actions,
    progress: progress,
    progressMaxWidth: progressMaxWidth,
    hidesTrailingWhileBusy: hidesTrailingWhileBusy,
    onTap: onTap,
    onLongPress: onLongPress,
    borderSide: borderSide,
    borderRadius: borderRadius,
    color: color,
    defaultShadow: defaultShadow,
    accent: accent,
    semanticLabel:
        semanticLabel ?? (subtitle == null ? title : '$title, $subtitle'),
    contentPadding: contentPadding,
    margin: margin,
    titleWidget: titleWidget,
    titleStyle: titleStyle,
    subtitleStyle: subtitleStyle,
    titleMaxLines: titleMaxLines,
    leadingGap: leadingGap,
    elevation: elevation,
    contentAlignment: contentAlignment,
  );
}
