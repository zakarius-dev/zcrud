/// Type canonique d'une flashcard.
///
/// Les six valeurs sont toutes génériques. Persistées en camelCase (le `name`
/// Dart de chaque valeur). Une valeur inconnue ou absente à la
/// désérialisation retombe sur [ZFlashcardType.openQuestion] via le
/// `defaultValue` déclaré sur le champ `ZFlashcard.type` (le générateur émet
/// un décodeur défensif — jamais d'exception, invariant AD-10).
library;

/// Types de flashcard supportés (six valeurs génériques).
///
/// Point d'extension recommandé pour un besoin de type ouvert futur : ajouter
/// une valeur dédiée en conservant le repli défensif vers [openQuestion]
/// (invariants AD-4/AD-10). L'ouverture par type de champ, si nécessaire,
/// passe par le registre de type du cœur, hors périmètre de ce paquet.
enum ZFlashcardType {
  /// Question à choix multiples (QCM) : voir `ZChoice`.
  multipleChoice,

  /// Vrai/Faux : réponse portée par `ZFlashcard.isTrue`.
  trueOrFalse,

  /// Question ouverte (réponse libre) — valeur de repli défensive.
  openQuestion,

  /// Exercice (réponse libre évaluée).
  exercise,

  /// Texte à trous.
  fillBlank,

  /// Réponse courte.
  shortAnswer,
}
