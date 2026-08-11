/// Mode d'affichage du minuteur (`ZTimerDisplay`).
///
/// Un enum plutôt qu'un booléen : un simple `bool showTimer` ne saurait pas
/// distinguer croissant de décroissant, et une troisième intention
/// forcerait soit un second booléen (états impossibles représentables :
/// `showTimer: false, countdown: true`), soit un refactor de surface
/// publique.
///
/// L'affichage n'est pas la mesure : le temps est toujours mesuré
/// (`Stopwatch`) et transmis en `timeTaken` au port d'évaluation — y
/// compris en [hidden]. Masquer le minuteur est un choix d'UI (ne pas
/// mettre l'apprenant sous pression), jamais un choix de télémétrie : un
/// barème qui tient compte du temps doit fonctionner dans les trois modes.
library;

/// Modes d'affichage du minuteur d'une carte (3 valeurs).
///
/// Tout `switch` sur cet enum est exhaustif sans `default` : une quatrième
/// valeur doit casser la compilation des sites d'appel, pas retomber
/// silencieusement dans une branche par défaut.
enum ZTimerDisplay {
  /// Défaut : aucun widget de minuteur dans l'arbre.
  ///
  /// Le temps reste mesuré (`Stopwatch`), mais aucun ticker n'est armé :
  /// rien n'étant affiché, un tick périodique ne ferait que réveiller
  /// l'arbre pour rien.
  hidden,

  /// Temps écoulé, croissant depuis le début de la carte.
  elapsed,

  /// Temps restant, décroissant depuis `timeLimit`.
  ///
  /// Sans `timeLimit`, dégrade en [elapsed] (invariant AD-10 : jamais
  /// d'exception, jamais un rebours depuis `null`). Épuisé, s'arrête à zéro
  /// (jamais de négatif) et la saisie reste possible : aucune soumission
  /// forcée n'est imposée à l'échéance.
  countdown,
}
