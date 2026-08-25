/// Repli **zéro-dépendance** du port `ZReorderRenderer`.
///
/// Bâti sur le seul SDK Flutter (`LongPressDraggable`/`DragTarget`/`Scrollable`)
/// via [ZReorderableAdaptiveGrid], et délégant le calcul de colonnes à
/// `ZAdaptiveGrid`/`computeCrossAxisCount`.
///
/// **Son rôle est d'être le plancher, pas l'idéal.** Un consommateur qui
/// n'installe aucun satellite garde une capacité de réordonnancement
/// *fonctionnelle* : c'est ce renderer qui l'assure. Un hôte qui veut une
/// ergonomie plus riche (aperçu de dépôt, animations inter-lignes, glisser
/// multi-sélection) injecte un satellite adossé à un paquet de l'écosystème,
/// ou sa propre implémentation — sans que le socle change. L'invariant AD-1
/// ne contraint que `zcrud_core` : rien n'empêche un satellite comme celui-ci
/// de s'appuyer uniquement sur le SDK Flutter par choix de conception.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_reorder_handle_scope.dart';
import 'z_reorderable_adaptive_grid.dart';

/// Implémentation de repli de [ZReorderRenderer], sans aucune dépendance
/// au-delà du SDK Flutter.
///
/// Elle **honore la capacité de poignée** du port : une poignée soumise à
/// [buildDragHandle] devient un déclencheur de glissement **immédiat** — pas
/// d'appui long à tenir sur elle — qui alimente exactement la machinerie du
/// geste de cellule : même aperçu flottant à la taille mesurée, même autoscroll
/// de bord, même ordre optimiste, même restauration si l'hôte échoue. Le geste
/// propre à la cellule et la voie non gestuelle restent disponibles.
///
/// C'est ce qui rend la poignée utile sur des items **denses** : une ligne qui
/// porte des sous-champs éditables ne peut pas se glisser par un appui long,
/// ce geste appartenant déjà à ses champs.
class ZDefaultReorderRenderer extends ZReorderRenderer {
  /// Construit le renderer de repli. `const`: il peut être injecté tel quel.
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
      // AD-13 — la voie non-gestuelle est OBLIGATOIRE (cf. le contrat du port):
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
      // Canal d'habillage de l'aperçu, relayé TEL QUEL (`null` compris ⇒
      // identité). Ce satellite est bâti sur `package:flutter/widgets.dart`
      // seul : il ne peut pas poser lui-même une feuille Material autour d'un
      // aperçu, et n'a pas à deviner ce dont les cellules de l'appelant ont
      // besoin. Le relais couvre les DEUX déclencheurs — geste de cellule et
      // glissement parti d'une poignée — puisque la grille les sert depuis un
      // aperçu unique.
      dragPreviewWrapper: request.dragPreviewWrapper,
    );
  }

  @override
  Widget buildDragHandle(BuildContext context, int index, Widget handle) {
    final scope = ZReorderHandleScope.maybeOf(context);
    if (scope == null) {
      // Hors d'une cellule de ce chassis (contexte étranger, aperçu flottant
      // monté dans l'overlay, appel du port en dehors d'un rendu) : défaut du
      // port — la poignée est rendue telle quelle et rien ne lève (AD-10).
      return handle;
    }
    return Draggable<int>(
      // 🔴 La donnée du glissement est la POSITION AFFICHÉE portée par le
      // canal, JAMAIS l'`index` reçu du port. Ce dernier est l'index SOURCE de
      // l'item (celui de la liste que l'hôte a poussée) tandis que tout le
      // chassis — cible de dépôt, rappel d'ordre, actions sémantiques —
      // raisonne en position affichée. Les deux coïncident tant que l'ordre
      // optimiste local n'a pas permuté l'affichage; passé ce point, les
      // confondre réordonnerait la mauvaise ligne, en silence. L'`index` est
      // donc reçu et délibérément non consommé.
      data: scope.position,
      // Une cellule à la fois : deux glissements concurrents partis de la même
      // poignée n'auraient pas de sens pour une permutation linéaire.
      maxSimultaneousDrags: 1,
      // TOUTE la boîte soumise est le déclencheur, pas seulement ce qu'elle
      // peint. Une poignée est typiquement un glyphe de ~24 dp centré dans une
      // cible tactile de 48 dp : au défaut `deferToChild`, la moitié de la
      // cible exigée par AD-13 serait transparente au geste et l'appui
      // atterrirait sur l'item. Cela ne change ni la taille, ni la marge, ni
      // la décoration, ni la sémantique de la poignée — la garantie « rendre
      // inchangé » porte sur le rendu, pas sur la surface sensible.
      hitTestBehavior: HitTestBehavior.opaque,
      // L'aperçu suit le pointeur : la poignée est une petite cible en tête
      // d'item, ancrer l'aperçu sur elle le décalerait de toute sa largeur.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragUpdate: scope.onDragUpdate,
      onDragEnd: (_) => scope.onDragStopped(),
      onDraggableCanceled: (_, _) => scope.onDragStopped(),
      onDragCompleted: scope.onDragStopped,
      feedback: scope.buildFeedback(),
      // Garantie du port : la poignée soumise est rendue INCHANGÉE. `Draggable`
      // n'impose aucune contrainte, ne peint rien et n'ajoute aucun nœud
      // sémantique — la cible tactile et le libellé restent ceux de l'appelant.
      child: handle,
    );
  }
}
