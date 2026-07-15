/// État IMMUABLE d'une session (`ZSessionState`) — ES-4.2, D1 (value-object).
///
/// Le moteur (`ZStudySessionEngine`) détient un `ZSessionState` **immuable** et
/// l'expose en lecture seule ; les transitions passent par un **reducer PUR**
/// (`reduceGrade`, cf. `z_study_session_engine.dart`) qui **retourne un nouvel
/// état** (jamais de mutation en place). Value-object : `==`/`hashCode`
/// **profonds** (égalité de file) ⇒ le moteur ne `notifyListeners()` que si
/// l'état a **réellement** changé (granularité AD-2, AC8).
///
/// La [queue] contient les cartes **encore à réviser**, dans l'ordre courant ;
/// [cursor] est l'index de la carte **courante**. Une carte réussie (`q ≥
/// passThreshold`) **quitte** la file ; une carte en lapse est **réinsérée**
/// plus loin (offset +2/+4, D2) — elle reste donc `remaining` jusqu'à réussite.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:zcrud_core/domain.dart' show ZFailure;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_session_item.dart';

/// Instantané immuable de la file de session + compteurs dérivés.
class ZSessionState {
  /// Constructeur bas-niveau (usage interne du reducer). Préférer
  /// [ZSessionState.initial] pour amorcer une session.
  const ZSessionState({
    required this.queue,
    required this.cursor,
    required this.reviewed,
    required this.lapses,
    required this.mode,
    this.error,
  });

  /// Amorce une session à partir d'une file **déjà sélectionnée** (le moteur ne
  /// re-sélectionne pas — la sélection est portée par `ZStudySessionSelector`,
  /// kernel). Curseur en tête, compteurs à zéro, aucune erreur.
  factory ZSessionState.initial(
    List<ZSessionItem> items, {
    ZReviewMode mode = ZReviewMode.spaced,
  }) =>
      ZSessionState(
        queue: List<ZSessionItem>.unmodifiable(items),
        cursor: 0,
        reviewed: 0,
        lapses: 0,
        mode: mode,
        error: null,
      );

  /// File des cartes **encore à réviser**, dans l'ordre courant (les cartes en
  /// lapse y sont réinsérées ; les cartes réussies en sont retirées).
  final List<ZSessionItem> queue;

  /// Index de la carte **courante** dans [queue].
  final int cursor;

  /// Nombre de cartes **réussies** (consommées via `q ≥ passThreshold`). Un
  /// lapse ne l'incrémente **jamais** (la carte reste `remaining`, AC7).
  final int reviewed;

  /// Nombre d'événements de **lapse** (grades `q < passThreshold`).
  final int lapses;

  /// Mode de session (défaut `spaced`).
  final ZReviewMode mode;

  /// Dernier échec de review **exposé** (jamais avalé, AD-5/R6) ; `null` si la
  /// dernière transition a réussi ou n'a rien fait.
  final ZFailure? error;

  /// Carte courante, ou `null` si la file est vide ([isComplete]).
  ZSessionItem? get current =>
      cursor >= 0 && cursor < queue.length ? queue[cursor] : null;

  /// `true` quand toutes les cartes ont été consommées **et** qu'aucune n'attend
  /// une réinsertion (file vide).
  bool get isComplete => queue.isEmpty;

  /// Nombre de cartes restant à réviser (cartes encore en file, réinsertions
  /// comprises).
  int get remaining => queue.length;

  /// Copie avec surcharge ciblée. [error] : passer `clearError: true` pour le
  /// remettre à `null` (une valeur `null` seule est ambiguë avec « inchangé »).
  ZSessionState copyWith({
    List<ZSessionItem>? queue,
    int? cursor,
    int? reviewed,
    int? lapses,
    ZReviewMode? mode,
    ZFailure? error,
    bool clearError = false,
  }) =>
      ZSessionState(
        queue: queue ?? this.queue,
        cursor: cursor ?? this.cursor,
        reviewed: reviewed ?? this.reviewed,
        lapses: lapses ?? this.lapses,
        mode: mode ?? this.mode,
        error: clearError ? null : (error ?? this.error),
      );

  /// État identique mais portant [failure] comme erreur exposée (file
  /// **inchangée** — utilisé quand le seam de review renvoie `Left`, D5/AC6).
  ZSessionState withError(ZFailure failure) => copyWith(error: failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSessionState &&
          runtimeType == other.runtimeType &&
          cursor == other.cursor &&
          reviewed == other.reviewed &&
          lapses == other.lapses &&
          mode == other.mode &&
          error == other.error &&
          listEquals(queue, other.queue);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        cursor,
        reviewed,
        lapses,
        mode,
        error,
        Object.hashAll(queue),
      );

  @override
  String toString() => 'ZSessionState(queue: $queue, cursor: $cursor, '
      'reviewed: $reviewed, lapses: $lapses, remaining: $remaining, '
      'isComplete: $isComplete, mode: $mode, error: $error)';
}
