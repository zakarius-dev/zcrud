/// Requête **neutre** de rendu d'une collection réordonnable (AD-57).
///
/// Décrit *quoi* réordonner, jamais *comment* : aucun type de paquet tiers,
/// aucun geste, aucune stratégie de dépôt. C'est le renderer injecté qui
/// choisit l'implémentation (repli SDK maison, paquet de l'écosystème, ou une
/// implémentation propre à l'hôte).
///
/// Imports limités à `package:flutter/widgets.dart` : AUCUNE dépendance lourde
/// (garde `presentation_purity_test.dart`).
library;

import 'package:flutter/widgets.dart';

/// Description neutre d'une collection réordonnable disposée en grille.
///
/// **L'ordre est LINÉAIRE** (`0..itemIds.length - 1`) et la grille n'en est
/// qu'une *projection* : déposer en position *k* signifie « index *k* », quelle
/// que soit la ligne. Tout renderer doit respecter cette convention — c'est elle
/// qui rend les implémentations interchangeables.
@immutable
class ZReorderRenderRequest {
  /// Construit une requête de rendu réordonnable.
  const ZReorderRenderRequest({
    required this.itemIds,
    required this.itemBuilder,
    required this.onReorder,
    required this.minItemWidth,
    this.spacing = 8.0,
    this.runSpacing,
    this.itemHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    this.moveBeforeSemanticLabel,
    this.moveAfterSemanticLabel,
  });

  /// Identités **stables** des items, dans l'ordre affiché. Une clé stable est
  /// requise : sans elle, un réordonnancement recycle les états d'item.
  final List<String> itemIds;

  /// Construit la cellule d'index [int] (position linéaire courante).
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Notifié avec des index **linéaires**. L'appelant persiste ; le renderer
  /// n'est jamais la source de vérité de l'ordre.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Largeur minimale d'une cellule — pilote le nombre de colonnes.
  final double minItemWidth;

  /// Gouttière principale entre cellules.
  final double spacing;

  /// Gouttière entre lignes (repli : [spacing]).
  final double? runSpacing;

  /// Hauteur fixe de cellule. Prime sur [aspectRatio] si les deux sont fournis
  /// (plus déterministe).
  final double? itemHeight;

  /// Ratio largeur/hauteur de cellule, si [itemHeight] est absent.
  final double? aspectRatio;

  /// Plancher du nombre de colonnes.
  final int minColumns;

  /// Plafond du nombre de colonnes (`null` = aucun).
  final int? maxColumns;

  /// Marge interne de la grille.
  final EdgeInsetsGeometry? padding;

  /// Libellé de l'action sémantique « déplacer avant » (AD-13).
  ///
  /// **Obligation d'accessibilité, pas un ornement** : un appui long est
  /// inatteignable au lecteur d'écran. Tout renderer DOIT offrir une voie
  /// non-gestuelle. `null` ⇒ le renderer applique son repli localisé.
  final String? moveBeforeSemanticLabel;

  /// Libellé de l'action sémantique « déplacer après » (AD-13). Cf.
  /// [moveBeforeSemanticLabel].
  final String? moveAfterSemanticLabel;
}
