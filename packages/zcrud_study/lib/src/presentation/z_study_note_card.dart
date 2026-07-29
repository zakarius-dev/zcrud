/// Carte de note d'étude, composée sur le chrome commun des outils.
library;

import 'package:flutter/material.dart';

import 'z_study_tools_item_card.dart';

/// Représentation compacte d'une note dans les outils d'étude.
///
/// Cette façade ne connaît aucune entité note : elle délègue le chrome et le
/// nœud [Semantics] explicite à [ZStudyToolsItemCard].
class ZStudyNoteCard extends StatelessWidget {
  const ZStudyNoteCard({
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
