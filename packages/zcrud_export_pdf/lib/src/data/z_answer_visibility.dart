/// Mode d'affichage des réponses dans le gabarit PDF flashcards — **ENUM**,
/// jamais un booléen (su-11, Conventions spine « enums > booléens »).
///
/// origine: su-11 (FR-SU16). Un `bool showAnswers` serait ambigu au site d'appel
/// (`true`/`false` illisible) et non extensible ; l'enum nomme l'intention et
/// laisse la porte ouverte à un futur mode (ex. `answersOnSeparateSheet`) sans
/// casser les appelants (AD-4, additif).
library;

/// Contrôle la présence des éléments **réponse** dans le PDF généré par
/// `ZFlashcardPdfTemplate`.
enum ZAnswerVisibility {
  /// Rendu **complet** : énoncé + badge + choix marqués ✓/✗ + réponse +
  /// `isTrue` (V/F) + explication.
  withAnswers,

  /// Rendu **révision** : énoncé + badge + libellés de choix **non marqués**
  /// uniquement. Aucun élément réponse (réponse / ✓·✗ / `isTrue` / explication)
  /// n'apparaît — ni en texte, ni en bitmap.
  withoutAnswers,
}
