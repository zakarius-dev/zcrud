/// Transition de révélation question→réponse d'une carte.
///
/// Enum, jamais un booléen : un `bool flip` n'aurait pas pu accueillir une
/// troisième transition sans rupture d'API, et ne nomme pas ce qu'il
/// commute.
///
/// Le réglage d'accessibilité « réduire les animations » prime sur cette
/// valeur (invariant AD-13) : quand il est actif, la révélation est
/// instantanée, y compris sous [flip3d]. Cette valeur exprime la transition
/// souhaitée, jamais une garantie d'animation.
///
/// Le rendu de chaque valeur est un `switch` exhaustif sans `default` dans
/// `ZFlashcardReviewCard` : ajouter une valeur ici casse la compilation,
/// jamais un repli silencieux à l'exécution.
library;

/// Transition de révélation d'une carte de révision.
enum ZRevealTransition {
  /// Flip 3D maison : matrice à perspective et rotation, bascule de face à
  /// mi-course, contre-rotation de la face arrière.
  ///
  /// Aucune dépendance tierce : ce paquet n'introduit pas de package de flip
  /// card externe.
  flip3d,

  /// Fondu court, aucune rotation : la face sortante s'efface, l'entrante
  /// apparaît.
  fade,
}
