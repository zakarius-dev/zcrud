/// Carte de document d'étude, composée sur le chrome commun des outils.
library;

import 'package:flutter/material.dart';

import 'z_study_tools_item_card.dart';

/// Représentation compacte d'un document dans les outils d'étude.
///
/// Les données métier, les icônes, les libellés localisés et les droits restent
/// chez l'hôte. Cette façade délègue intégralement le chrome et son accessibilité
/// à [ZStudyToolsItemCard].
class ZStudyDocumentCard extends StatelessWidget {
  const ZStudyDocumentCard({
    required this.title,
    this.subtitle,
    this.metadata,
    this.actions,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? metadata;
  final Widget? actions;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ZStudyToolsItemCard(
    title: title,
    subtitle: subtitle,
    badge: metadata,
    trailing: actions,
    onTap: onTap,
    semanticLabel:
        semanticLabel ?? (subtitle == null ? title : '$title, $subtitle'),
  );
}
