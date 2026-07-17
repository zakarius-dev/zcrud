/// Mode d'**affichage** du minuteur `ZTimerDisplay` (Story SU-3, AC7 — FR-SU4).
///
/// 🔒 **ENUM, jamais un booléen** (convention du spine : « enums > booléens »).
/// Un `bool showTimer` ne saurait pas distinguer *croissant* de *décroissant*, et
/// une troisième intention forcerait soit un second booléen (états impossibles
/// représentables : `showTimer: false, countdown: true`), soit un refactor de
/// surface publique.
///
/// 🔒 **L'affichage n'est PAS la mesure** (AC7) : le temps est **TOUJOURS
/// mesuré** (`Stopwatch`) et transmis en `timeTaken` au port d'évaluation — y
/// compris en [hidden]. Masquer le minuteur est un choix d'**UI** (ne pas mettre
/// l'apprenant sous pression), jamais un choix de **télémétrie** : un barème qui
/// tient compte du temps doit fonctionner dans les trois modes.
library;

/// Modes d'affichage du minuteur d'une carte (3 valeurs).
///
/// Tout `switch` sur cet enum est **exhaustif SANS `default`** : une 4ᵉ valeur
/// doit casser la **compilation** des call-sites, pas retomber silencieusement
/// dans une branche par défaut.
enum ZTimerDisplay {
  /// **Défaut** (FR-SU4) : aucun widget de minuteur dans l'arbre.
  ///
  /// 🔒 Le temps reste **mesuré** (`Stopwatch`), mais **aucun ticker n'est
  /// armé** : rien n'étant affiché, un tick périodique ne ferait que réveiller
  /// l'arbre pour rien (SM-1).
  hidden,

  /// Temps **écoulé**, croissant depuis le début de la carte.
  elapsed,

  /// Temps **restant**, décroissant depuis `timeLimit`.
  ///
  /// 🔒 Sans `timeLimit`, **dégrade en [elapsed]** (AD-10 : jamais d'exception,
  /// jamais un rebours depuis `null`). Épuisé, s'arrête à **zéro** (jamais de
  /// négatif) et la saisie **reste possible** : su-3 n'impose aucune soumission
  /// forcée (aucun AC ne l'exige — l'inventer serait du périmètre volé).
  countdown,
}
