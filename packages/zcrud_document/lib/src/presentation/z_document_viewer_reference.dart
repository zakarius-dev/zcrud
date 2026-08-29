/// Référence auditée du **chrome** du lecteur de document : des SCALAIRES,
/// et rien d'autre.
///
/// ## Zéro couleur, par construction
///
/// Ce fichier ne porte **aucune** couleur — ni littéral, ni rôle, ni jeton. Il
/// n'est pas exempté des gardes anti-couleurs du paquet, et n'a pas à l'être :
/// les couleurs d'annotation vivent dans l'unique fichier de référence couleur
/// (`z_annotation_palette_reference.dart`). Séparer les deux garde l'exemption
/// nominative **étroite** : une géométrie de référence ne doit jamais servir
/// de porte d'entrée à un hex.
///
/// ## Ce que ces valeurs font, et ne font pas
///
/// Elles sont le **dernier maillon** d'une chaîne de priorité
/// **paramètre > référence**, arbitré par [zDocumentLegacyOrNeutral] :
///
/// * sous `ZReferenceProfile.legacy`, opt-in de l'hôte, le socle peint la
///   valeur de référence ;
/// * sous `ZReferenceProfile.neutral` — **le défaut** — il peint la valeur
///   qu'il peignait auparavant : l'arbre produit est alors **strictement**
///   celui d'avant l'introduction de cette référence, nœud pour nœud ;
/// * un paramètre non nul l'emporte **dans les deux profils**.
///
/// ## Le plancher tactile domine la référence
///
/// [minTouchTarget] n'est pas une valeur de référence : c'est le plancher
/// d'accessibilité (AD-13). La référence de barre est plus basse que ce que
/// trois cibles de 48 dp exigent ; elle est donc appliquée comme une **hauteur
/// minimale**, jamais comme une hauteur imposée. Aucune valeur de ce fichier
/// ne peut faire descendre une cible interactive sous [minTouchTarget].
library;

import 'package:zcrud_core/zcrud_core.dart'
    show ZReferenceProfile, zLegacyOrIn;

/// Scalaires de référence du chrome de lecture et de la palette d'annotation.
///
/// Chaque valeur est figée : la changer change ce que voient tous les hôtes
/// qui n'ont posé aucun paramètre. Une garde compare cette table à une copie
/// indépendante et rougit à la moindre dérive.
abstract final class ZDocumentViewerReference {
  /// Hauteur d'une section de barre — appliquée comme **minimum**.
  //
  // Legacy IFFD (branche `main`),
  // `lib/src/presentation/features/documents/widgets/document_viewer/` :
  // `bottom_toolbar.dart:44` (`static const double _toolBarSectionHeight =
  // 56.0`), consommée `:167` ; même valeur en dur dans
  // `annotation_toolbar.dart:173` (`height: 56`).
  static const double barHeight = 56;

  /// Taille de glyphe d'une action de barre.
  //
  // Legacy `bottom_toolbar.dart:135` (et `:142`, `:149`, `:156`) ;
  // `annotation_toolbar.dart:199`.
  static const double barIconSize = 20;

  /// Côté d'une pastille de couleur d'annotation.
  ///
  /// Plus petite que [minTouchTarget] : c'est la **pastille peinte**, pas la
  /// cible. La cible reste dimensionnée par [minTouchTarget], et la pastille
  /// est centrée dedans.
  //
  // Legacy `color_palette.dart:302-303` (`ToolbarItem(height: 40, width: 40)`)
  // ; même dimension pour les boutons de barre, `bottom_toolbar.dart:187-188`.
  static const double swatchSize = 40;

  /// Épaisseur d'un filet de séparation.
  //
  // Legacy `bottom_toolbar.dart:174-176` (`thickness: 1, height: 1`).
  static const double dividerThickness = 1;

  /// Rayon des coins du panneau d'annotation.
  //
  // Legacy `color_palette.dart:108` (`BorderRadius.circular(12)`, branche
  // Material 3 — la branche Material 2 vaut 2, non retenue : le socle est M3).
  static const double panelCornerRadius = 12;

  /// Plancher d'une cible interactive (AD-13) — **pas** une valeur de
  /// référence, et jamais remplaçable par elle.
  static const double minTouchTarget = 48;
}

/// Arbitre un **scalaire** entre la référence auditée et la valeur historique
/// du socle, à partir d'un profil déjà résolu.
///
/// Rend [legacy] uniquement si [profile] vaut `ZReferenceProfile.legacy`,
/// sinon [current]. Un profil **nul** vaut `ZReferenceProfile.neutral` — le
/// défaut du socle — et rend donc [current].
///
/// Fonction **pure** : elle ne lit aucun contexte.
///
/// Le repli de profil n'est pas décidé ici : cette fonction **délègue** à
/// `zLegacyOrIn`, arbitre unique du socle. Recopier `profile ?? …` ferait
/// diverger le défaut de ce paquet de celui de tous les autres.
///
/// À ne pas confondre avec l'usage habituel de `zLegacyOrIn`, qui arbitre les
/// membres **couleur** et rend un `T?` (le profil neutre y vaut « aucune
/// couleur »). Ici le profil neutre vaut « la valeur d'avant », qui n'est pas
/// forcément nulle : c'est ce qui rend l'inertie du profil neutre **exacte**
/// plutôt qu'approchée.
T zDocumentLegacyOrNeutral<T>(
  ZReferenceProfile? profile,
  T legacy,
  T current,
) =>
    zLegacyOrIn<T>(profile, legacy, current) as T;
