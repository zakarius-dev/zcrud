/// Clés de référence d'un catalogue d'artefacts de notebook.
///
/// Ce sont des **jetons ouverts** : le socle ne génère aucun de ces
/// artefacts et n'interprète pas leur contenu. L'hôte branche son backend
/// sur la clé qu'il reconnaît. `flashcards` et `mindmap` nomment les
/// artefacts déjà produits par les ports dédiés des satellites d'étude ;
/// ils ne sont pas des styles de génération de texte.
library;

/// Catalogue de référence, additif.
abstract final class ZNotebookArtifactKind {
  /// Résumé.
  static const String summary = 'summary';

  /// Questionnaire.
  static const String quiz = 'quiz';

  /// Guide d'étude.
  static const String studyGuide = 'study_guide';

  /// Foire aux questions.
  static const String faq = 'faq';

  /// Script audio.
  static const String podcast = 'podcast';

  /// Paquet de cartes, produit par le port d'étude dédié.
  static const String flashcards = 'flashcards';

  /// Carte mentale, produite par le port d'étude dédié.
  static const String mindmap = 'mindmap';

  /// Les clés de référence, dans l'ordre d'affichage d'une palette vide
  /// d'hôte.
  static const List<String> reference = <String>[
    summary,
    quiz,
    studyGuide,
    faq,
    podcast,
    flashcards,
    mindmap,
  ];
}
