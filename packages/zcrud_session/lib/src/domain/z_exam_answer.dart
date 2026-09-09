/// Réponse d'examen blanc, rangée sous l'index de sa question.
///
/// Value-object pur-Dart, immuable, sans identité ni horloge. Il ne porte
/// aucune règle de notation : il porte le **fait** (le candidat a répondu, a
/// déclaré ne pas savoir, n'a rien enregistré) et, dans le seul cas d'une
/// réponse donnée, la qualité que le barème lui a attribuée.
///
/// La conversion vers la note qui entre au scoring est
/// [ZExamAnswer.scoredQuality] — une fonction totale, sans exception.
library;

import 'package:flutter/foundation.dart' show immutable;

/// Nature d'une [ZExamAnswer] — trois états, et un seul porte une note.
enum ZExamAnswerKind {
  /// Le candidat a répondu : [ZExamAnswer.quality] porte la note du barème.
  answered,

  /// Le candidat a déclaré ne pas savoir. La question est **répondue** (elle
  /// compte dans le nombre de réponses) et **fausse** (elle entre au scoring
  /// à la borne basse de l'échelle déclarée).
  dontKnow,

  /// Aucune réponse enregistrée. La question ne compte pas comme répondue.
  /// Elle n'entre au scoring que si la soumission compte les questions sans
  /// réponse comme fausses.
  unanswered,
}

/// Réponse enregistrée pour une question d'examen blanc.
///
/// ## Règle de comptage
///
/// - **réponse donnée** : compte répondue, et entre au scoring avec sa
///   [quality] ;
/// - **« je ne sais pas »** : compte répondue **et fausse** — elle entre au
///   scoring à la borne basse de l'échelle (`ZSrsConfig.minQuality`), qui est
///   par construction strictement inférieure au seuil de réussite ;
/// - **sans réponse** : ne compte pas répondue. Elle n'entre au scoring que
///   sur une soumission qui compte les questions sans réponse comme fausses,
///   auquel cas elle y entre à la même borne basse.
@immutable
class ZExamAnswer {
  /// Réponse donnée, notée [quality] par le barème.
  const ZExamAnswer.answered(this.quality) : kind = ZExamAnswerKind.answered;

  /// Le candidat déclare ne pas savoir : répondue, et fausse.
  const ZExamAnswer.dontKnow()
    : kind = ZExamAnswerKind.dontKnow,
      quality = null;

  /// Aucune réponse enregistrée.
  const ZExamAnswer.unanswered()
    : kind = ZExamAnswerKind.unanswered,
      quality = null;

  /// Nature de cette réponse.
  final ZExamAnswerKind kind;

  /// Note du barème, non-`null` uniquement pour [ZExamAnswerKind.answered].
  ///
  /// Ce champ n'est pas la note portée au scoring : « je ne sais pas » et
  /// « sans réponse » n'en portent aucune et sont notés à la borne basse par
  /// [scoredQuality].
  final int? quality;

  /// `true` si la question compte comme répondue — donné **ou** « je ne sais
  /// pas », jamais « sans réponse ».
  bool get isAnswered => kind != ZExamAnswerKind.unanswered;

  /// Note portée au scoring, [incorrectQuality] servant de borne basse pour
  /// « je ne sais pas » et « sans réponse ».
  ///
  /// Fonction totale : elle ne lève jamais et ne rend jamais `null`.
  int scoredQuality({required int incorrectQuality}) =>
      quality ?? incorrectQuality;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExamAnswer &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(runtimeType, kind, quality);

  @override
  String toString() => 'ZExamAnswer(kind: $kind, quality: $quality)';
}
