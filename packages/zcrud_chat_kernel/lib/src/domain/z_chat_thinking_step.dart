/// Étape de raisonnement exposée par l'assistant — `ZChatThinkingStep`.
///
/// (dé)sérialisation écrite à la main : aucun codegen dans ce paquet.
library;

import 'package:zcrud_core/domain.dart';

/// Une étape de raisonnement (« quel agent a fait quoi »), immuable.
///
/// [timestamp] est **nullable** plutôt que requis : un décodage généré qui
/// exige une date lève sur une date absente ou corrompue et emporte tout le
/// message. L'invariant AD-10 l'interdit.
class ZChatThinkingStep {
  /// Construit une étape (immuable, `const`).
  const ZChatThinkingStep({
    this.agent = '',
    this.content = '',
    this.timestamp,
  });

  /// Identifiant de l'agent/outil ayant produit l'étape.
  final String agent;

  /// Contenu textuel de l'étape.
  final String content;

  /// Horodatage ISO-8601, ou `null` si absent/illisible.
  final DateTime? timestamp;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatThinkingStep? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatThinkingStep(
      agent: zJsonString(map['agent']),
      content: zJsonString(map['content']),
      timestamp: zJsonDate(map['timestamp']),
    );
  }

  /// Sérialise en clés snake_case ; [timestamp] omis s'il est `null`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'agent': agent,
        'content': content,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  /// Copie modifiée (champs omis conservés).
  ZChatThinkingStep copyWith({
    String? agent,
    String? content,
    DateTime? timestamp,
  }) =>
      ZChatThinkingStep(
        agent: agent ?? this.agent,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatThinkingStep &&
          agent == other.agent &&
          content == other.content &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(agent, content, timestamp);

  @override
  String toString() => 'ZChatThinkingStep(agent: $agent)';
}
