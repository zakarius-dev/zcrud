/// Erreur de **configuration de scope / seam non résolu** (AD-6).
///
/// origine: matérialisation du principe « seams résolus par binding, défaut
/// throw » — un seam requis mais non fourni doit échouer TÔT et de façon
/// ACTIONNABLE, plutôt que de résoudre silencieusement une valeur magique.
library;

/// Levée lorsqu'un **seam requis n'a pas été fourni** ou qu'aucun `ZcrudScope`
/// n'est présent dans l'arbre.
///
/// C'est une erreur de **programmation/configuration** (pas une condition
/// d'exécution récupérable) : elle étend [Error]. Le [message] doit toujours
/// indiquer QUEL seam manque et COMMENT le fournir (`ZcrudScope(...)` ou un
/// binding E2-9). Fusionne le rôle qu'aurait tenu un `ZMissingBindingError`
/// distinct (décision E2-7 : un seul type d'erreur actionnable suffit).
class ZScopeError extends Error {
  /// Construit l'erreur avec un [message] actionnable.
  ZScopeError(this.message);

  /// Description actionnable (quel seam, comment le fournir).
  final String message;

  @override
  String toString() => 'ZScopeError: $message';
}
