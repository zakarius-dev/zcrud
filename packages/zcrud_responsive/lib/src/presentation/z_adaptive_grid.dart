import 'package:flutter/widgets.dart';

import '../domain/compute_cross_axis_count.dart';

/// Grille d'items **adaptative** dont le nombre de colonnes est calculé par la
/// fonction pure [computeCrossAxisCount] à partir de la **largeur LOCALE** du
/// conteneur (mesurée par un `LayoutBuilder`), garantissant **au moins 1
/// colonne** et gardant le cas `children` vide.
///
/// **Nom `ZAdaptiveGrid` — JAMAIS `ZResponsiveGrid`** (AD-31) : `ZResponsiveGrid`
/// est réservé à la grille **12 colonnes de formulaire** de `zcrud_core`. Cette
/// grille-ci dispose des **cartes d'items** (une colonne par tranche de
/// [minItemWidth]), notion distincte.
///
/// **Largeur LOCALE (AD-31 / D2)** : `availableWidth = constraints.maxWidth` du
/// `LayoutBuilder` — **jamais** `Get.width`, **jamais** `MediaQuery.sizeOf` /
/// `MediaQuery.of(context).size` (écran global). Mesurer le conteneur (et non la
/// fenêtre) donne le bon nombre de colonnes en **split-view**, **master-detail**,
/// **bottom-sheet partiel** ou toute colonne d'une `Row`.
///
/// **Garde vide (AD-10)** : `children` vide → `const SizedBox.shrink()` **avant**
/// tout `LayoutBuilder`/`GridView` — jamais de grille fantôme ni de division par
/// zéro.
///
/// **Aspect déduit (D4)** : les items s'étirent pour remplir la largeur (largeur
/// d'item déduite `itemWidth = (maxWidth − spacing·(n − 1)) / n`). Si [itemHeight]
/// est fourni (`> 0`), `childAspectRatio = itemWidth / itemHeight` ; sinon
/// `aspectRatio ?? 1.0`.
///
/// **Sans état, RTL-neutre (AD-2 / AD-15 / AD-13)** : `StatelessWidget` pur —
/// aucun gestionnaire d'état/routeur, aucun `setState`. [padding] est
/// `EdgeInsetsGeometry?` (accepte `EdgeInsetsDirectional`) ; le nombre de colonnes
/// est **identique** sous `Directionality.ltr` et `.rtl` à largeur égale.
///
/// **Rendu paresseux (NFR-U4)** : `GridView.builder` (`itemCount` +
/// `itemBuilder`) — jamais `GridView.count(children:)`/`GridView(children:)`. La
/// grille ne scrolle pas d'elle-même (`shrinkWrap` + `NeverScrollableScrollPhysics`) :
/// c'est le parent qui scrolle.
class ZAdaptiveGrid extends StatelessWidget {
  /// Crée une grille adaptative. Seuls [children] et [minItemWidth] sont requis.
  const ZAdaptiveGrid({
    required this.children,
    required this.minItemWidth,
    this.spacing = 8.0,
    this.runSpacing,
    this.itemHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    super.key,
  });

  /// Items à disposer. **Vide → `SizedBox.shrink()`** (garde AD-10).
  final List<Widget> children;

  /// Largeur minimale d'un item (dp) : pilote le nombre de colonnes
  /// (`largeur locale / minItemWidth`, borné). Remplace le ternaire `300/350`
  /// codé en dur d'iffd/dodlp.
  final double minItemWidth;

  /// Espacement **inter-colonnes** (dp), aussi défaut de l'espacement
  /// **inter-lignes** si [runSpacing] est `null`.
  final double spacing;

  /// Espacement **inter-lignes** (dp). `null` → reprend [spacing].
  final double? runSpacing;

  /// Hauteur cible d'un item (dp). Fournie (`> 0`) → `childAspectRatio` recalculé
  /// sur la largeur d'item déduite ; sinon repli sur [aspectRatio].
  final double? itemHeight;

  /// Ratio largeur/hauteur explicite des items. **Ignoré si [itemHeight] fourni**
  /// (`> 0`). `null` → `1.0`.
  final double? aspectRatio;

  /// Plancher de colonnes (**remonté à 1** si `< 1`, AD-10).
  final int minColumns;

  /// Plafond de colonnes. `null` → illimité (borne haute pratique = `floor`).
  final int? maxColumns;

  /// Marge interne de la grille — `EdgeInsetsGeometry?` (accepte
  /// `EdgeInsetsDirectional`, RTL-safe AD-13).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Garde vide AD-10 : jamais de LayoutBuilder/GridView fantôme.
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Padding horizontal résolu **directionnellement** (AC9 / AD-13) : il est
        // retranché de la largeur pour le calcul des colonnes ET de la largeur
        // d'item, mais reste appliqué au GridView pour l'espace visuel (jamais
        // double-compté).
        final double horizontalPadding =
            padding?.resolve(Directionality.of(context)).horizontal ?? 0;

        final int n = computeCrossAxisCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: minItemWidth,
          minColumns: minColumns,
          maxColumns: maxColumns,
          spacing: spacing,
          horizontalPadding: horizontalPadding,
        );

        // Largeur d'item déduite sur la MÊME base cohérente que le calcul des
        // colonnes (largeur utile = maxWidth − padding horizontal ; les items
        // remplissent la largeur, gouttières comprises, pas de reste).
        final double effectiveWidth = constraints.maxWidth - horizontalPadding;
        final double rawItemWidth =
            (effectiveWidth - spacing * (n - 1)) / n;
        // AD-10 (défensif, jamais de throw) : `spacing > minItemWidth` (n ≥ 2 →
        // largeur négative) ou une contrainte infinie peuvent produire une largeur
        // ≤ 0 / non finie qui violerait l'assertion `childAspectRatio > 0` du
        // delegate. On retombe alors sur `minItemWidth`.
        final double itemWidth =
            (rawItemWidth.isFinite && rawItemWidth > 0) ? rawItemWidth : minItemWidth;

        final double? height = itemHeight;
        double ratio = (height != null && height > 0)
            ? itemWidth / height
            : (aspectRatio ?? 1.0);
        // Plancher défensif ultime : le delegate exige `childAspectRatio > 0` fini
        // (AD-10) — couvre aussi un `aspectRatio`/`minItemWidth` dégénéré fourni.
        if (!ratio.isFinite || ratio <= 0) ratio = 1.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: runSpacing ?? spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, i) => children[i],
        );
      },
    );
  }
}
