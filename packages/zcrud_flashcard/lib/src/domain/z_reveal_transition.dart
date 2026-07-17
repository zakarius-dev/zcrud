/// Transition de révélation question→réponse d'une carte (SU-2, AC2 — FR-SU1).
///
/// **ENUM, jamais un booléen** (convention du spine « enums > booléens », AD-4) :
/// un `bool flip` n'aurait pas pu accueillir une troisième transition sans
/// changement d'API cassant, et ne nomme pas ce qu'il commute.
///
/// ⚠️ **Reduce Motion PRIME sur cette valeur** (AC3/NFR-SU3, AD-13) : quand
/// `MediaQuery.disableAnimationsOf(context)` est vrai, la révélation est
/// **instantanée** — y compris sous [flip3d]. Cette valeur exprime la transition
/// *souhaitée*, jamais une garantie d'animation.
///
/// Le rendu de chaque valeur est un `switch` **exhaustif sans `default`** dans
/// `ZFlashcardReviewCard` : ajouter une valeur ici casse la **compilation**
/// (jamais un repli silencieux à l'exécution).
library;

/// Transition de révélation d'une carte de révision (FR-SU1).
enum ZRevealTransition {
  /// Flip 3D **MAISON** : `Matrix4` à perspective + `rotateY`, bascule de face à
  /// mi-course, contre-rotation de la face arrière.
  ///
  /// **Aucune dépendance tierce** (`flip_card` est **interdite** — FR-SU1 et
  /// contre-métrique du PRD : aucune dépendance au-delà des trois décidées).
  flip3d,

  /// Fondu court, **aucune rotation** : la face sortante s'efface, l'entrante
  /// apparaît.
  fade,
}
