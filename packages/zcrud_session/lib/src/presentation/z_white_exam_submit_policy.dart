/// Politique de soumission d'un examen blanc.
///
/// Value-object pur : il décide **quand** une soumission demande une
/// confirmation, et **ce que compte** une copie rendue incomplète. Il ne rend
/// rien à l'écran et n'appelle aucun moteur.
library;

import 'package:flutter/foundation.dart' show immutable;

/// Règles de confirmation et de comptage à la soumission.
///
/// Un examen soumis est **irréversible** : la phase soumise n'a aucune
/// transition sortante. La confirmation par défaut porte donc sur le seul cas
/// où le candidat perd quelque chose sans l'avoir vu — des questions restées
/// sans réponse.
@immutable
class ZWhiteExamSubmitPolicy {
  /// Construit une politique de soumission.
  const ZWhiteExamSubmitPolicy({
    this.confirmWhenIncomplete = true,
    this.confirmWhenComplete = false,
    this.countUnansweredAsIncorrect = true,
  });

  /// Politique sans aucune confirmation : la soumission part au premier
  /// geste. Le comptage des questions sans réponse reste réglable.
  const ZWhiteExamSubmitPolicy.immediate({
    this.countUnansweredAsIncorrect = true,
  }) : confirmWhenIncomplete = false,
       confirmWhenComplete = false;

  /// Demander confirmation quand des questions restent sans réponse.
  final bool confirmWhenIncomplete;

  /// Demander confirmation même quand toutes les questions sont répondues.
  final bool confirmWhenComplete;

  /// Une question restée sans réponse compte-t-elle **fausse** ?
  ///
  /// `true` (défaut) : la copie est notée sur **toutes** les questions de
  /// l'épreuve — une question blanche pèse comme une réponse fausse, au même
  /// titre qu'un « je ne sais pas ». `false` : seules les réponses
  /// enregistrées sont notées, et la copie est notée sur elles seules.
  final bool countUnansweredAsIncorrect;

  /// La soumission demande-t-elle une confirmation, sachant [unanswered]
  /// questions sans réponse ?
  bool requiresConfirmation({required int unanswered}) =>
      unanswered > 0 ? confirmWhenIncomplete : confirmWhenComplete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZWhiteExamSubmitPolicy &&
          runtimeType == other.runtimeType &&
          confirmWhenIncomplete == other.confirmWhenIncomplete &&
          confirmWhenComplete == other.confirmWhenComplete &&
          countUnansweredAsIncorrect == other.countUnansweredAsIncorrect;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    confirmWhenIncomplete,
    confirmWhenComplete,
    countUnansweredAsIncorrect,
  );

  @override
  String toString() =>
      'ZWhiteExamSubmitPolicy(confirmWhenIncomplete: $confirmWhenIncomplete, '
      'confirmWhenComplete: $confirmWhenComplete, '
      'countUnansweredAsIncorrect: $countUnansweredAsIncorrect)';
}
