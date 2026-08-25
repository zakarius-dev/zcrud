/// Requête **neutre** de rendu d'une collection réordonnable.
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

/// Habille l'**aperçu flottant** d'un glissement : reçoit l'aperçu déjà
/// construit et retourne l'aperçu enveloppé.
///
/// L'aperçu d'un glisser-déposer est monté dans l'`Overlay`, donc **hors** du
/// sous-arbre de l'écran : ce qu'un descendant y trouvait par héritage
/// (une feuille Material, un `DefaultTextStyle`, un `Theme` d'hôte…) n'y est
/// plus. Une cellule dont le contenu dépend d'un tel ancêtre doit donc le
/// remettre autour de l'aperçu — c'est ce que cette fonction fait.
///
/// **Contrat** :
/// 1. **enveloppe, ne remplace pas** : [preview] doit apparaître tel quel dans
///    le sous-arbre retourné ;
/// 2. **n'impose aucune géométrie** : l'aperçu est déjà dimensionné à la taille
///    mesurée de la cellule ; une enveloppe qui contraint, décale ou aligne le
///    ferait sauter ;
/// 3. **l'aperçu seulement** : la cellule rendue **en place** n'est jamais
///    concernée.
///
/// Aucun contexte n'est fourni : une enveloppe qui a besoin d'en lire un pose
/// un `Builder`.
typedef ZReorderDragPreviewWrapper = Widget Function(Widget preview);

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
    this.dragPreviewWrapper,
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

  /// Enveloppe de l'**aperçu flottant** du glissement — `null` ⇒ **identité**,
  /// l'aperçu est rendu tel que le renderer l'a construit.
  ///
  /// À remplir par l'appelant quand les cellules portent des widgets qui
  /// exigent un ancêtre absent de l'`Overlay` : un `TextField` (ou tout autre
  /// widget de la bibliothèque Material) lève `No Material widget found` dans
  /// un aperçu dépourvu de feuille. Le socle ne peut pas le poser à la place de
  /// l'appelant — les renderers de repli sont volontairement sans dépendance
  /// Material ; l'appelant, lui, sait ce que ses cellules contiennent.
  ///
  /// ```dart
  /// dragPreviewWrapper: (preview) =>
  ///     Material(type: MaterialType.transparency, child: preview),
  /// ```
  ///
  /// **Un renderer n'est pas tenu de la consulter** : celui dont l'aperçu offre
  /// déjà l'ancêtre requis la laisse de côté sans manquer au contrat du port.
  /// Cf. [ZReorderDragPreviewWrapper] pour ce qu'une enveloppe doit garantir.
  final ZReorderDragPreviewWrapper? dragPreviewWrapper;
}
