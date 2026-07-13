/// Mode de session d'étude `ZReviewMode` (Story E9-3, AC1).
///
/// origine: lex_core (module « Étude ») — enum de mode de révision, aligné sur
/// le schéma canonique §2.3 (`ZStudySessionConfig.mode`). 6 valeurs
/// **génériques**, persistées en **camelCase** (= le `name` Dart de chaque
/// valeur, ex. `"whiteExam"`), désérialisation **défensive** vers [spaced]
/// (AD-3/AD-10).
///
/// Une valeur inconnue/absente à la désérialisation retombe sur [spaced] via le
/// `defaultValue` déclaré sur le champ `ZStudySessionConfig.mode` (le générateur
/// émet un `fromMap` défensif : `_$enumFromName(...) ?? ZReviewMode.spaced`,
/// **jamais** de throw).
///
/// **Note de flux (E9-4/E9-5, NON implémentée ici)** : seuls [spaced] et
/// [learn] écrivent de l'état SRS (`ZRepetitionInfo` via `ZSrsScheduler`) ; les
/// modes [list]/[test]/[whiteExam]/[cramming] parcourent les cartes **sans**
/// faire avancer la répétition espacée. Cette règle relève du flux de révision
/// (E9-4/E9-5) et n'est pas matérialisée en E9-3.
library;

/// Modes de session d'étude supportés (6 valeurs génériques — AC1).
///
/// **Point d'extension recommandé (non implémenté ici, AD-4/AD-10)** : pour un
/// mode ouvert futur, ajouter une valeur en conservant le repli défensif vers
/// [spaced].
enum ZReviewMode {
  /// Répétition espacée (SRS) — **valeur de repli défensive**. Écrit du SRS.
  spaced,

  /// Apprentissage initial (première acquisition). Écrit du SRS.
  learn,

  /// Parcours en liste (revue linéaire, sans SRS).
  list,

  /// Test/quiz d'auto-évaluation (sans SRS).
  test,

  /// Examen blanc (conditions d'examen, sans SRS).
  whiteExam,

  /// Bachotage (révision massée avant échéance, sans SRS).
  cramming,
}
