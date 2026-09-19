/// Retour pédagogique d'une réponse, indépendant de son rendu.
class ZLearningFeedback {
  /// Construit le retour associé au palier affiché.
  const ZLearningFeedback({
    required this.quality,
    required this.message,
    this.explanation,
  });

  /// Palier proposé ou sélectionné.
  final int quality;

  /// Message principal.
  final String message;

  /// Explication complémentaire facultative.
  final String? explanation;
}
