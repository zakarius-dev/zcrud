/// Barrel d'API publique de `zcrud_chat_kernel`.
///
/// Noyau de conversation IA, Dart pur — **source unique** du modèle neutre de
/// chat :
/// - `ZChatConversation` / `ZChatMessage` : entités `ZEntity` + `ZExtensible`,
///   (dé)sérialisation écrite à la main (aucun codegen sur ce paquet) ;
/// - `ZContentBlock` : famille ouverte de blocs de contenu (`String kind`,
///   jamais `sealed` — invariant AD-4) ;
/// - `ZChatSource` / `ZChatSourceFreshness` / `ZChatResponseConfidence` /
///   `ZChatSuggestion` / `ZChatThinkingStep` / `ZChatAttachment` /
///   `ZChatQuotaSnapshot` : value objects purs ;
/// - `ZChatRole`, `ZChatResponseLength`, … : enums neutres ;
/// - `action/` : contrat d'action de message — intentions scellées
///   (`ZChatAction`), plan (`ZChatActionPlan`), exécuteur (`ZChatActionExecutor`)
///   et répartiteur unique (`ZChatActionDispatcher`). Un verbe correspond à un
///   seul site d'appel : les membres d'effet de l'exécuteur ne sont invocables
///   que depuis le répartiteur.
///
/// Dépend uniquement de `zcrud_core` (surface pur-Dart) — aucune arête
/// entrante vers le cœur (graphe acyclique, invariant AD-1).
///
/// Les primitives de lecture JSON défensive et la hiérarchie `ZFailure`
/// (dont `ZQuotaExceededFailure`) restent dans `zcrud_core` : elles sont
/// transverses et préexistent au chat.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Contrat d'action de message : intentions scellées et répartiteur unique.
export 'src/domain/action/z_chat_action.dart';
export 'src/domain/action/z_chat_action_executor.dart';
export 'src/domain/action/z_chat_action_failure.dart';
export 'src/domain/action/z_chat_action_outcome.dart';
// `z_chat_action_dispatcher.dart` n'a PAS d'export à lui : il est un
// `part` de `z_chat_action_plan.dart` depuis que le constructeur du plan est
// privé (la portée du privé est la BIBLIOTHÈQUE). `ZChatActionDispatcher` reste
// donc exporté — par la ligne ci-dessous.
export 'src/domain/action/z_chat_action_plan.dart';
// Ports IA de la conversation : génération unique paramétrée par un style
// ouvert, streaming `Stream<Either<ZFailure, ZChatStreamEvent>>`, contexte
// d'étude, jeton d'annulation par requête, familles d'échec IA
// (`ZQuotaExceededFailure` du cœur est câblée, pas redéclarée).
export 'src/domain/ai/z_chat_ai_failure.dart';
// Capacités booléennes vérifiables : recherche web typée et canal ouvert
// (`ZChatGenerationSettings.capabilities`, clés opaques — invariant AD-4), et
// le bouclage anti-repli-muet `auditCapabilities` → `ZChatCapabilityAudit`
// (pendant exact de `ZChatCorpusScope.audit`).
export 'src/domain/ai/z_chat_capability_audit.dart';
export 'src/domain/ai/z_chat_compute_effort.dart';
export 'src/domain/ai/z_chat_context_port.dart';
// Portée documentaire vérifiable : la portée s'exprime en clés stables sur
// la requête (`ZChatCorpusScope`), et `ZChatCorpusScope.audit` confronte les
// sources rendues à la portée demandée. Sans ce bouclage lecture/écriture,
// une restriction ne vaudrait rien : `ZChatSource.corpus` n'est qu'un libellé,
// c'est `ZChatSource.corpusKey` qui se compare.
export 'src/domain/ai/z_chat_corpus_scope.dart';
export 'src/domain/ai/z_chat_generation_port.dart';
// Porteur de réglages neutre, transportable sur la requête et sur
// `ZChatRegenerateAction` (ce qui rend `ZChatLengthBias` atteignable sur son
// propre cas d'usage). Il compose les types existants, n'en redéclare aucun.
export 'src/domain/ai/z_chat_generation_settings.dart';
export 'src/domain/ai/z_chat_generation_style.dart';
export 'src/domain/ai/z_chat_quota_metadata.dart';
export 'src/domain/ai/z_chat_request_token.dart';
// Carte ouverte de fin de réponse : les verdicts déjà calculés par le
// serveur (scores, garde-citations, couverture, fraîcheur des datasets)
// traversent le socle sans être perdus ni inventés. `ZChatResponseConfidence`
// et `ZChatSourceFreshness` y sont câblés, jamais redéclarés.
export 'src/domain/ai/z_chat_response_metadata.dart';
export 'src/domain/ai/z_chat_stream_event.dart';
// Saisie assistée (dictée, OCR) : des ports, et la relecture obligatoire
// rendue structurelle — `ZUnreviewedText` n'expose aucune `String`, son
// unique sortie est un dépôt `void` dans une surface éditable.
export 'src/domain/capture/z_chat_capture_port.dart';
// Gestion de conversation en ports (invariant AD-11) : recherche, épinglage
// (un seul verbe), partage en lecture seule, et cycle de vie **soft** — la
// suppression définitive en lot est refusée, seul le retrait réversible est
// porté.
export 'src/domain/conversation/z_chat_conversation_ports.dart';
// Diffusion vocale : la chaîne de repli devient une donnée
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
