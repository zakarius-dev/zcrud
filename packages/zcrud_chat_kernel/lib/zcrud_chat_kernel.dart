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
// Lot K1 — CAPACITÉS booléennes vérifiables : recherche web TYPÉE + canal
// OUVERT (`ZChatGenerationSettings.capabilities`, clés opaques — AD-4), et le
// bouclage anti-repli-muet `auditCapabilities` → `ZChatCapabilityAudit`
// (pendant exact de `ZChatCorpusScope.audit`).
export 'src/domain/ai/z_chat_capability_audit.dart';
export 'src/domain/ai/z_chat_compute_effort.dart';
export 'src/domain/ai/z_chat_context_port.dart';
// Lot β — PORTÉE documentaire VÉRIFIABLE : la portée s'exprime en CLÉS stables
// sur la requête (`ZChatCorpusScope`), et `ZChatCorpusScope.audit` confronte
// les sources RENDUES à la portée DEMANDÉE. Sans ce bouclage lecture/écriture,
// une restriction ne vaudrait rien : `ZChatSource.corpus` n'est qu'un libellé,
// c'est `ZChatSource.corpusKey` (lot β) qui se compare.
export 'src/domain/ai/z_chat_corpus_scope.dart';
export 'src/domain/ai/z_chat_generation_port.dart';
// Lot β — PORTEUR de réglages neutre, transportable sur la requête ET sur
// `ZChatRegenerateAction` (ce qui rend `ZChatLengthBias` atteignable sur son
// propre cas d'usage). Il COMPOSE les types existants, n'en redéclare AUCUN.
export 'src/domain/ai/z_chat_generation_settings.dart';
export 'src/domain/ai/z_chat_generation_style.dart';
export 'src/domain/ai/z_chat_quota_metadata.dart';
export 'src/domain/ai/z_chat_request_token.dart';
// CHAT-7 — carte OUVERTE de fin de réponse : les VERDICTS déjà calculés par le
// serveur (scores, garde-citations, couverture, fraîcheur des datasets)
// traversent le socle sans être perdus ni inventés. `ZChatResponseConfidence`
// et `ZChatSourceFreshness` (CHAT-0) y sont CÂBLÉS, jamais redéclarés.
export 'src/domain/ai/z_chat_response_metadata.dart';
export 'src/domain/ai/z_chat_stream_event.dart';
// CHAT-10 — saisie ASSISTÉE (dictée, OCR) : des PORTS (AD-57), et la relecture
// obligatoire rendue STRUCTURELLE — `ZUnreviewedText` n'expose AUCUNE `String`,
// son unique sortie est un dépôt `void` dans une surface éditable.
export 'src/domain/capture/z_chat_capture_port.dart';
// CHAT-9 — gestion de conversation en PORTS (AD-11) : recherche, épinglage
// (un seul verbe), partage en lecture seule, et cycle de vie **SOFT** — le
// `batch.delete` de `delete_messages_after` de lex est refusé, pas porté.
export 'src/domain/conversation/z_chat_conversation_ports.dart';
// CHAT-9 — diffusion vocale : la chaîne de repli de lex devient une DONNÉE
// (`ZChatSpeechChain`), site unique du repli, échecs conservés.
export 'src/domain/diffusion/z_chat_speech_port.dart';
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
