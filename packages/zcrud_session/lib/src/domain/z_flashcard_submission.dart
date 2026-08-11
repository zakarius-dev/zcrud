/// Soumission advisory d'une réponse (`ZFlashcardSubmission`).
///
/// La surface de saisie n'écrit jamais l'état SRS elle-même : ce
/// value-object est émis à l'hôte (`onSubmitted`) comme un simple fait —
/// « voici ce qui a été répondu » — et c'est l'hôte qui branche l'écriture
/// SRS sur le seam `ZSessionReviewer`, l'unique voie d'écriture du dépôt
/// (invariant AD-9). Émettre un fait plutôt qu'écrire un état garde la
/// surface de saisie pure et testable, et laisse l'hôte seul maître de la
/// persistance.
///
/// Pur-Dart : aucun import Flutter. Ce fichier vit sous `lib/src/domain/`,
/// que la garde de pureté du paquet scanne comme « runtime sans widget » —
/// `Duration` relève de `dart:core`, aucune dépendance supplémentaire n'est
/// requise.
library;

/// Fait immuable d'une réponse soumise (value-object, `==`/`hashCode` par
/// valeur).
class ZFlashcardSubmission {
  /// Construit une soumission advisory.
  const ZFlashcardSubmission({
    required this.quality,
    required this.timeTaken,
    required this.hintsUsed,
    this.isCorrect,
    this.feedback,
  });

  /// Qualité finale, déjà clampée et plafonnée.
  ///
  /// Elle a traversé la voie unique d'attribution, dans l'ordre imposé :
  /// `config.clampQuality(...)` puis `zApplyHintCeiling(...)`. L'hôte la
  /// consomme telle quelle : re-clamper ou re-plafonner en aval appliquerait
  /// une seconde pénalité par erreur.
  final int quality;

  /// Temps de réponse mesuré, toujours renseigné — y compris quand le
  /// minuteur est `ZTimerDisplay.hidden` : l'affichage n'est pas la mesure.
  final Duration timeTaken;

  /// Nombre d'indices consommés pour cette carte.
  final int hintsUsed;

  /// Verdict du barème, ou `null` s'il ne se prononce pas ou n'est pas
  /// sollicité.
  final bool? isCorrect;

  /// Retour pédagogique à afficher (prose du barème, ou repli l10n en cas
  /// d'échec du port), ou `null`.
  final String? feedback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardSubmission &&
          quality == other.quality &&
          timeTaken == other.timeTaken &&
          hintsUsed == other.hintsUsed &&
          isCorrect == other.isCorrect &&
          feedback == other.feedback;

  @override
  int get hashCode =>
      Object.hash(quality, timeTaken, hintsUsed, isCorrect, feedback);

  @override
  String toString() => 'ZFlashcardSubmission(quality: $quality, '
      'timeTaken: $timeTaken, hintsUsed: $hintsUsed, isCorrect: $isCorrect)';
}
