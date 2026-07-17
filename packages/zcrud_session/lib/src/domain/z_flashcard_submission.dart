/// Soumission **ADVISORY** d'une réponse `ZFlashcardSubmission`
/// (Story SU-3, AC2 — AD-33/AD-35).
///
/// 🔒 **su-3 n'écrit RIEN** (AD-33). Ce VO est **émis** à l'hôte
/// (`onSubmitted`) ; c'est **su-4** qui branchera l'écriture SRS sur le seam
/// `ZSessionReviewer` — **unique** voie d'écriture du repo. Émettre un fait
/// (« voici ce qui a été répondu ») au lieu d'écrire un état garde la surface de
/// saisie **pure** et testable, et laisse l'hôte seul maître de la persistance.
///
/// 🔒 **Pur-Dart : AUCUN import Flutter** (AD-2/NFR-S5). Ce fichier vit sous
/// `lib/src/domain/`, que la garde `test/z_purity_test.dart` scanne en
/// « runtime widget-free » : un import `flutter/material` ici la ferait ROUGIR.
/// `Duration` relève de `dart:core` — aucune dépendance requise.
library;

/// Fait **immuable** d'une réponse soumise (value-object, `==`/`hashCode` par
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

  /// Qualité **finale** — 🔒 **déjà clampée ET plafonnée** (AC2/AC6).
  ///
  /// Elle a traversé la voie **unique** d'attribution, dans l'ordre imposé :
  /// `config.clampQuality(...)` **puis** `zApplyHintCeiling(...)`. L'hôte la
  /// consomme telle quelle : re-clamper ou re-plafonner en aval serait une
  /// **seconde pénalité**.
  final int quality;

  /// Temps de réponse mesuré — 🔒 **toujours renseigné**, y compris quand le
  /// minuteur est `ZTimerDisplay.hidden` (AC7 : l'affichage n'est pas la mesure).
  final Duration timeTaken;

  /// Nombre d'indices consommés pour cette carte (AC5/AC6).
  final int hintsUsed;

  /// Verdict du barème, ou `null` s'il ne se prononce pas / n'est pas sollicité
  /// (`isCorrect?` d'AD-35).
  final bool? isCorrect;

  /// Retour pédagogique à afficher (prose du barème, ou repli l10n en cas
  /// d'échec du port — AC3), ou `null`.
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
