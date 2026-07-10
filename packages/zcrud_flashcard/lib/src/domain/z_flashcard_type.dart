/// Type canonique d'une flashcard (Story E9-1, AC1).
///
/// origine: lex_core (module « Étude ») — `flashcard_type.dart:13` : superset
/// union chat ∪ admin, `jsonValue = name` (camelCase), désérialisation
/// **défensive** vers `openQuestion` (AD-4/AD-10).
///
/// Les 6 valeurs sont **toutes génériques**. Persistées en **camelCase** (= le
/// `name` Dart de chaque valeur). Une valeur inconnue/absente à la
/// désérialisation retombe sur [openQuestion] via le `defaultValue` déclaré sur
/// le champ `ZFlashcard.type` (le générateur émet un `fromMap` défensif :
/// `_$enumFromName(...) ?? ZFlashcardType.openQuestion`, **jamais** de throw).
library;

/// Types de flashcard supportés (6 valeurs génériques — AC1).
///
/// **Point d'extension recommandé (non implémenté ici, AD-4/AD-10)** : pour un
/// besoin de type ouvert futur, ajouter une valeur `custom`/`unknown` en
/// conservant le repli défensif vers [openQuestion]. L'ouverture par type de
/// champ passe sinon par `ZTypeRegistry` (cœur), hors périmètre E9-1.
enum ZFlashcardType {
  /// Question à choix multiples (QCM) : voir `ZChoice`.
  multipleChoice,

  /// Vrai/Faux : réponse portée par `ZFlashcard.isTrue`.
  trueOrFalse,

  /// Question ouverte (réponse libre) — **valeur de repli défensive**.
  openQuestion,

  /// Exercice (réponse libre évaluée).
  exercise,

  /// Texte à trous.
  fillBlank,

  /// Réponse courte.
  shortAnswer,
}
