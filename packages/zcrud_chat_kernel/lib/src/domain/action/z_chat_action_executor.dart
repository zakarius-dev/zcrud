/// Port d'**effet** des actions de message — `ZChatActionExecutor`.
///
/// CHAT-0b, décision **D5**. Forme canonique d'un port du dépôt :
/// `abstract interface class` + un `Future` de `ZResult` sur **chaque** membre
/// (AD-5/AD-11).
/// Aucune mécanique de transport (HTTP, Firestore, `CancelToken`,
/// `StreamSubscription`) ne fuit dans le domaine.
///
/// ## 🔴 INVARIANT CENTRAL DE LA STORY — un verbe, un seul site d'appel
///
/// Ces sept membres **ne sont invoqués que depuis
/// `z_chat_action_dispatcher.dart`**. Toute autre occurrence en position
/// d'appel dans `packages/*/lib` est une **VIOLATION**, détectée par la garde
/// **G-U1** (`z_chat_action_contract_guard_test.dart`).
///
/// C'est *elle* qui empêche la récidive quand CHAT-2 (`ZChatController`) et
/// CHAT-7 construiront dessus : un controller qui court-circuiterait le
/// répartiteur — la « surface B » d'IFFD, `chatbot_conversation_screen.dart`
/// ≈ l.3600-4120 — fait rougir la garde **en nommant le fichier fautif**.
///
/// 🚫 **Ne jamais** appeler ces membres depuis un widget, un controller, un
/// repository ou un second dispatcher. Passer par
/// `ZChatActionDispatcher.prepare` puis `.execute`.
///
/// ## Verbe non supporté
///
/// Un hôte qui n'implémente pas un verbe rend
/// `Left(ZUnsupportedOperationFailure(…, operation: '<membre>'))` — **type
/// EXISTANT réutilisé** (D9) — pour que l'appelant puisse **masquer** l'action
/// sans parser de chaîne. Jamais `throw`, jamais `null` (AD-10).
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_action.dart';
import 'z_chat_action_plan.dart';

/// Effets réels des verbes, implémentés par l'app hôte.
abstract interface class ZChatActionExecutor {
  /// Chiffre l'impact d'une action **AVANT** toute destruction (D6).
  ///
  /// Patron `deleteMessagesAfter` de lex, qui **retourne le compte** : une
  /// cascade non annoncée devient inexprimable.
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action);

  /// Remplace le texte d'un message et relance la génération.
  ///
  /// Rend les identités des messages touchés — **jamais** `Unit` là où un
  /// compte est disponible (leçon `deleteMessagesAfter`, AD-5).
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  });

  /// Régénère la réponse d'un message ; rend les identités touchées.
  Future<ZResult<List<String>>> regenerate({required String messageId});

  /// 🔴 **Seul** membre de retrait du contrat, et il est **SOFT** (D7, AD-9).
  ///
  /// Le contrat n'expose **aucun** membre de suppression dure : ni
  /// `hardDelete`, ni `purge`, ni `deleteForever` (garde **G-S1**). lex et IFFD
  /// font tous deux un hard delete et **divergent d'AD-9** — zcrud prime.
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  });

  /// Annule la requête **désignée par [requestId]** — jamais « la courante »
  /// (D4 : aucun jeton d'instance partagé).
  ///
  /// 🚫 Une implémentation qui supprimerait un message ici réintroduirait le
  /// défaut IFFD `chatbot_conversation_screen.dart:3618-3672` (annuler =
  /// supprimer la question tapée).
  Future<ZResult<Unit>> cancelRequest(String requestId);

  /// Rend le contenu d'un message pour la copie (lecture seule).
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  });

  /// Exécute un verbe d'hôte (variant ouvert AD-4) ; rend les identités
  /// touchées.
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action);
}
