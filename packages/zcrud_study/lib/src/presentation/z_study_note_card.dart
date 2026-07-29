/// Carte de note d'étude, composée sur le chrome commun des outils.
library;

import 'package:flutter/material.dart';

import 'z_study_tools_item_card.dart';

/// Représentation compacte d'une note dans les outils d'étude.
///
/// Cette façade ne connaît aucune entité note : elle délègue le chrome et le
/// nœud [Semantics] explicite à [ZStudyToolsItemCard].
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
/// 🔴 **Tout nouveau slot ajouté à [ZStudyToolsItemCard] DOIT être répercuté
/// ici** — sinon la façade redevient **plus pauvre** que la voie directe, et
/// l'hôte qui l'adopte perd silencieusement une capacité.
///
/// C'est exactement ce qui s'est produit entre CR-LEX-67 et CR-LEX-70..75 : la
/// façade répondait à la demande telle qu'elle était écrite, les CR suivantes
/// ont déplacé la cible, et personne n'est revenu vérifier que la première
/// réponse tenait encore. Une garde de source (`cr_lex_78_*_test.dart`) compare
/// désormais la surface des deux façades à celle du socle et **rougit** au
/// premier slot oublié : ne la contourne pas, complète la façade.
class ZStudyNoteCard extends StatelessWidget {
  /// Construit une carte de note ; seul [title] est requis.
  const ZStudyNoteCard({
    required this.title,
    this.leading,
    this.subtitle,
    this.belowSubtitle,
    this.metadata,
    this.actions,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.borderSide,
    this.accent,
    this.semanticLabel,
    this.contentPadding,
    this.margin,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    super.key,
  });

  /// Titre de la note. Voir [ZStudyToolsItemCard.title].
  final String title;

  /// Icône ou vignette de tête. Voir [ZStudyToolsItemCard.leading].
  final Widget? leading;

  /// Libellé secondaire. Voir [ZStudyToolsItemCard.subtitle].
  final String? subtitle;

  /// Contenu rendu sous [subtitle]. Voir [ZStudyToolsItemCard.belowSubtitle].
  final Widget? belowSubtitle;

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

  /// Contour explicite. Voir [ZStudyToolsItemCard.borderSide].
  final BorderSide? borderSide;

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

  /// Style du sous-titre. Voir [ZStudyToolsItemCard.subtitleStyle].
  final TextStyle? subtitleStyle;

  /// Nombre maximal de lignes du titre. Voir
  /// [ZStudyToolsItemCard.titleMaxLines].
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) => ZStudyToolsItemCard(
    title: title,
    leading: leading,
    subtitle: subtitle,
    belowSubtitle: belowSubtitle,
    badge: metadata,
    trailing: actions,
    progress: progress,
    progressMaxWidth: progressMaxWidth,
    hidesTrailingWhileBusy: hidesTrailingWhileBusy,
    onTap: onTap,
    borderSide: borderSide,
    accent: accent,
    semanticLabel:
        semanticLabel ?? (subtitle == null ? title : '$title, $subtitle'),
    contentPadding: contentPadding,
    margin: margin,
    titleStyle: titleStyle,
    subtitleStyle: subtitleStyle,
    titleMaxLines: titleMaxLines,
  );
}
