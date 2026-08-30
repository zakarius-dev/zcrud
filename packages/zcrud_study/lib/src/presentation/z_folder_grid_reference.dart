/// Les valeurs de RÉFÉRENCE de la **grille** de cartes de dossier, centralisées
/// en UN SEUL endroit — pendant, à l'échelle de la grille, de ce que
/// `ZFolderCardReference` est à l'échelle de la carte.
///
/// `ZFolderCardReference` fige le rendu d'UNE carte ; la disposition qui pose
/// ces cartes (largeur minimale d'item, hauteur de cellule, espacements) reste
/// à l'appelant, qui n'a aucun moyen de la déduire. Ce fichier est le point
/// d'audit unique de ces quatre nombres.
///
/// ## Ce n'est PAS un widget de grille
///
/// La grille elle-même reste `ZAdaptiveGrid` (`zcrud_responsive`) : cette
/// classe n'expose que des **jetons** et la règle de palier, de sorte qu'un
/// appelant compose sans réécrire ni la grille ni le seuil :
///
/// ```dart
/// ZAdaptiveGrid.builder(
///   itemCount: folders.length,
///   itemBuilder: (context, i) => ZDefaultFolderCard(/* … */),
///   minItemWidth: ZFolderGridReference.minItemWidthFor(width),
///   itemHeight: ZFolderGridReference.cellHeight,
///   spacing: ZFolderGridReference.spacing,
/// )
/// ```
///
/// où [minItemWidthFor] applique le palier `ZWindowSizeThresholds.expandedMinWidth`
/// (840 dp) — le seuil du socle, jamais un littéral de l'appelant :
///
/// ```dart
/// width >= ZWindowSizeThresholds.expandedMinWidth
///     ? ZFolderGridReference.minItemWidthExpanded
///     : ZFolderGridReference.minItemWidth
/// ```
///
/// ## FR-26 — ce fichier n'a PAS besoin de l'exception encadrée
///
/// Il ne porte **aucune couleur** : les quatre valeurs sont exclusivement des
/// dimensions. Comme `ZFolderCardReference`, il n'est donc **PAS** inscrit dans
/// l'exemption nominative de la garde de source anti-couleurs — l'y inscrire
/// serait une exemption inutile.
///
/// ## Rendu
///
/// Ces jetons ne sont **posés par aucun widget du socle** : ils décrivent la
/// grille que l'appelant construit. Fournir une valeur différente à
/// `ZAdaptiveGrid` reste la voie normale — la référence est un défaut
/// documenté, jamais une contrainte.
library;

import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZWindowSizeThresholds;

/// Les valeurs de RÉFÉRENCE de la grille de cartes de dossier, le point
/// d'audit unique.
abstract final class ZFolderGridReference {
  // Les quatre valeurs sont relevées dans le dépôt hôte IFFD (branche `main`),
  // jamais choisies ici :
  //   • lib/src/presentation/features/folders/pages/folders_page.dart:450
  //       final itemMinWidth = Get.width >= 840 ? 350 : 300.0;
  //     ⇒ minItemWidth = 300, minItemWidthExpanded = 350, palier = 840
  //       (= ZWindowSizeThresholds.expandedMinWidth, que l'hôte réécrit en dur)
  //   • lib/src/presentation/features/folders/pages/folders_page.dart:652
  //       childAspectRatio: itemWidth / 250   ⇒ cellHeight = 250
  //   • lib/src/presentation/features/folders/pages/folders_page.dart:648-649
  //       mainAxisSpacing: 8, crossAxisSpacing: 8   ⇒ spacing = 8
  // Le même triplet 300/350/840 se relit sur six autres pages du même hôte
  // (auditeurs_pages.dart:394, exams_page.dart:147, user_role_page.dart:262,
  // folder_flashcards_list_page.dart:494, folder_progress_page.dart:111,
  // tec_cedeao_screen.dart:662) : c'est une convention d'hôte, pas un réglage
  // d'écran.

  /// Largeur minimale (dp) d'un item de grille de dossiers (**300**), en
  /// dessous du palier `expanded`.
  static const double minItemWidth = 300;

  /// Largeur minimale (dp) d'un item de grille de dossiers (**350**) au
  /// palier `expanded` (largeur de fenêtre ≥ 840 dp).
  static const double minItemWidthExpanded = 350;

  /// Hauteur (dp) d'une cellule de grille de dossiers (**250**).
  ///
  /// Se donne telle quelle à `ZAdaptiveGrid.itemHeight` : la grille en dérive
  /// elle-même le rapport d'aspect, l'appelant n'a pas à le calculer.
  static const double cellHeight = 250;

  /// Espacement (dp) entre cellules, **dans les deux axes** (**8**).
  static const double spacing = 8;

  /// La largeur minimale d'item pour une fenêtre de [width] dp : applique le
  /// palier `expanded` du socle (`ZWindowSizeThresholds.expandedMinWidth`).
  ///
  /// Pure — aucun `BuildContext`, donc testable et utilisable dans un
  /// `LayoutBuilder` comme depuis un `MediaQuery`. Une [width] non finie ou
  /// négative retombe sur [minItemWidth], le régime le plus étroit (AD-10 —
  /// jamais de throw).
  static double minItemWidthFor(double width) {
    if (!width.isFinite) return minItemWidth;
    return width >= ZWindowSizeThresholds.expandedMinWidth
        ? minItemWidthExpanded
        : minItemWidth;
  }
}
