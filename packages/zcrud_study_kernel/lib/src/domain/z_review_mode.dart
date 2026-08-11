/// Mode de session d'étude `ZReviewMode` — six valeurs génériques, persistées
/// en camelCase (le `name` Dart de chaque valeur, ex. `"whiteExam"`), avec
/// désérialisation défensive vers [spaced] (invariant AD-10).
///
/// Une valeur inconnue ou absente à la désérialisation retombe sur [spaced]
/// via le `defaultValue` déclaré sur le champ `ZStudySessionConfig.mode` (le
/// générateur émet un `fromMap` défensif : `_$enumFromName(...) ??
/// ZReviewMode.spaced`, jamais de `throw`).
///
/// Seuls [spaced] et [learn] écrivent de l'état de répétition espacée ; les
/// modes [list]/[test]/[whiteExam]/[cramming] parcourent les cartes **sans**
/// faire avancer la répétition espacée. Cette règle relève du flux de
/// révision, hors du périmètre de ce kernel.
library;

/// Modes de session d'étude supportés.
///
/// Point d'extension recommandé pour un mode ouvert futur (invariant AD-4/
/// AD-10) : ajouter une valeur en conservant le repli défensif vers [spaced].
enum ZReviewMode {
  /// Répétition espacée (SRS) — valeur de repli défensive. Écrit du SRS.
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
