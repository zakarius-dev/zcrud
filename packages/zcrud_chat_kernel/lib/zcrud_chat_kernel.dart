/// Barrel d'API publique de `zcrud_chat_kernel`.
///
/// Noyau de conversation IA — **source UNIQUE** du modèle neutre de chat,
/// RELOCALISÉ depuis `zcrud_core` par CHAT-0r (AD-1) :
/// - `ZChatConversation` / `ZChatMessage` : entités `ZEntity` + `ZExtensible`,
///   (dé)sérialisation ÉCRITE À LA MAIN (aucun codegen — D1 de CHAT-0) ;
/// - `ZContentBlock` : famille OUVERTE de blocs de contenu (`String kind`,
///   JAMAIS `sealed` — AD-4) ;
/// - `ZChatSource` / `ZChatSourceFreshness` / `ZChatResponseConfidence` /
///   `ZChatSuggestion` / `ZChatThinkingStep` / `ZChatAttachment` /
///   `ZChatQuotaSnapshot` : value objects purs ;
/// - `ZChatRole`, `ZChatResponseLength`, … : enums neutres ;
/// - `action/` (CHAT-0b) : contrat d'ACTION de message — intentions SCELLÉES
///   (`ZChatAction`), plan (`ZChatActionPlan`), exécuteur (`ZChatActionExecutor`)
///   et répartiteur UNIQUE (`ZChatActionDispatcher`). « Un verbe = un seul site
///   d'appel » : les membres d'effet de l'exécuteur ne sont invocables que depuis
///   `z_chat_action_dispatcher.dart` (garde G-U1).
///
/// Dépend UNIQUEMENT de `zcrud_core` (surface pur-Dart `domain.dart`) —
/// AUCUNE arête entrante vers le cœur (CORE OUT = 0, graphe ACYCLIQUE).
///
/// 🔴 Les primitives de lecture JSON défensive (`z_json_read.dart`) et la
/// hiérarchie `ZFailure` (dont `ZQuotaExceededFailure`) restent dans
/// `zcrud_core` : elles sont TRANSVERSES et préexistent au chat.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// CHAT-0b — contrat d'ACTION de message : intentions scellées + répartiteur
// UNIQUE (garde G-U1).
export 'src/domain/action/z_chat_action.dart';
export 'src/domain/action/z_chat_action_executor.dart';
export 'src/domain/action/z_chat_action_failure.dart';
export 'src/domain/action/z_chat_action_outcome.dart';
// 🔴 `z_chat_action_dispatcher.dart` n'a PAS d'export à lui : il est un
// `part` de `z_chat_action_plan.dart` depuis que le constructeur du plan est
// privé (la portée du privé est la BIBLIOTHÈQUE). `ZChatActionDispatcher` reste
// donc exporté — par la ligne ci-dessous.
export 'src/domain/action/z_chat_action_plan.dart';
// CHAT-1 — ports IA de la conversation : génération UNIQUE paramétrée par
// style OUVERT, streaming `Stream<Either<ZFailure, ZChatStreamEvent>>` (forme
// de lex), contexte d'étude, jeton d'annulation PAR REQUÊTE, familles d'échec
// IA (`ZQuotaExceededFailure` du cœur est CÂBLÉE, pas redéclarée).
export 'src/domain/ai/z_chat_ai_failure.dart';
export 'src/domain/ai/z_chat_compute_effort.dart';
export 'src/domain/ai/z_chat_context_port.dart';
export 'src/domain/ai/z_chat_generation_port.dart';
export 'src/domain/ai/z_chat_generation_style.dart';
export 'src/domain/ai/z_chat_quota_metadata.dart';
export 'src/domain/ai/z_chat_request_token.dart';
export 'src/domain/ai/z_chat_stream_event.dart';
export 'src/domain/z_chat_attachment.dart';
export 'src/domain/z_chat_conversation.dart';
export 'src/domain/z_chat_enums.dart';
export 'src/domain/z_chat_extension_parser.dart';
export 'src/domain/z_chat_message.dart';
export 'src/domain/z_chat_quota_snapshot.dart';
export 'src/domain/z_chat_response_confidence.dart';
export 'src/domain/z_chat_source.dart';
export 'src/domain/z_chat_source_freshness.dart';
export 'src/domain/z_chat_suggestion.dart';
export 'src/domain/z_chat_thinking_step.dart';
export 'src/domain/z_content_block.dart';
