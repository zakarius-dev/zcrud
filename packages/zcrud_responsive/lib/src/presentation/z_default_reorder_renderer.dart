/// Repli **zéro-dépendance** du port `ZReorderRenderer` (AD-57).
///
/// Bâti sur le seul SDK Flutter (`LongPressDraggable`/`DragTarget`/`Scrollable`)
/// via [ZReorderableAdaptiveGrid], et délégant le calcul de colonnes à
/// `ZAdaptiveGrid`/`computeCrossAxisCount`.
///
/// **Son rôle est d'être le plancher, pas l'idéal.** AD-57 exige qu'un
/// consommateur qui n'installe aucun satellite garde une capacité
/// *fonctionnelle* : c'est ce renderer qui l'assure. Un hôte qui veut une
/// ergonomie plus riche (aperçu de dépôt, animations inter-lignes, glisser
/// multi-sélection) injecte un satellite adossé à un paquet de l'écosystème,
/// ou sa propre implémentation — sans que le socle change.
///
/// Historique, parce qu'il explique la forme du code : cette grille a d'abord
/// été écrite à la main au motif — **erroné** — qu'un paquet tiers serait
/// « refusé par AD-1 ». AD-1 ne contraint que `zcrud_core`. Le travail n'est
/// pas perdu : il devient le repli garanti.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_reorderable_adaptive_grid.dart';

/// Implémentation de repli de [ZReorderRenderer], sans aucune dépendance
/// au-delà du SDK Flutter.
class ZDefaultReorderRenderer extends ZReorderRenderer {
  /// Construit le renderer de repli. `const` : il peut être injecté tel quel.
  const ZDefaultReorderRenderer({
    this.autoScrollEdgeExtent = 64.0,
    this.autoScrollStep = 24.0,
  });

  /// Épaisseur de la bande, près des bords verticaux, qui déclenche
  /// l'autoscroll pendant un glissement.
  final double autoScrollEdgeExtent;

  /// Pas de défilement appliqué à chaque tick d'autoscroll.
  final double autoScrollStep;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    return ZReorderableAdaptiveGrid(
      itemIds: request.itemIds,
      itemBuilder: request.itemBuilder,
      onReorder: request.onReorder,
      minItemWidth: request.minItemWidth,
      // AD-13 — la voie non-gestuelle est OBLIGATOIRE (cf. le contrat du port) :
      // un repli localisé s'applique si l'hôte n'a pas fourni de libellé, plutôt
      // que de laisser l'action sémantique sans nom, donc inutilisable.
      moveBeforeSemanticLabel:
          request.moveBeforeSemanticLabel ?? 'Déplacer avant',
      moveAfterSemanticLabel: request.moveAfterSemanticLabel ?? 'Déplacer après',
      spacing: request.spacing,
      runSpacing: request.runSpacing,
      itemHeight: request.itemHeight,
      aspectRatio: request.aspectRatio,
      minColumns: request.minColumns,
      maxColumns: request.maxColumns,
      padding: request.padding,
      autoScrollEdgeExtent: autoScrollEdgeExtent,
      autoScrollStep: autoScrollStep,
    );
  }
}
