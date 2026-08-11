/// Port d'**effet** des actions de message — `ZChatActionExecutor`.
///
/// Forme canonique d'un port du dépôt : `abstract interface class` + un
/// `Future` de `ZResult` sur **chaque** membre (invariants AD-5, AD-11).
/// Aucune mécanique de transport (HTTP, Firestore, `CancelToken`,
/// `StreamSubscription`) ne fuit dans le domaine.
///
/// ## Un verbe, un seul site d'appel
///
/// Ces sept membres **ne sont invoqués que depuis
/// `ZChatActionDispatcher`**. Un controller ou un widget qui appellerait ce
/// port directement court-circuiterait le protocole de confirmation en deux
/// temps décrit sur [ZChatActionPlan].
///
/// **Ne jamais** appeler ces membres depuis un widget, un controller, un
/// repository ou un second dispatcher. Passer par
/// `ZChatActionDispatcher.prepare` puis `.execute`.
///
/// ## Verbe non supporté
///
/// Un hôte qui n'implémente pas un verbe rend
/// `Left(ZUnsupportedOperationFailure(…, operation: '<membre>'))` — **type
/// existant réutilisé** — pour que l'appelant puisse **masquer** l'action
/// sans parser de chaîne. Jamais `throw`, jamais `null` (invariant AD-10).
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_action.dart';
import 'z_chat_action_plan.dart';

/// Effets réels des verbes, implémentés par l'app hôte.
abstract interface class ZChatActionExecutor {
  /// Chiffre l'impact d'une action **AVANT** toute destruction.
  ///
  /// Rendre le compte des messages touchés est la garantie qui rend une
  /// cascade non annoncée inexprimable.
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action);

  /// Remplace le texte d'un message et relance la génération.
  ///
  /// Rend les identités des messages touchés — **jamais** `Unit` là où un
  /// compte est disponible (invariant AD-5).
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  });

  /// Régénère la réponse d'un message ; rend les identités touchées.
  Future<ZResult<List<String>>> regenerate({required String messageId});

  /// **Seul** membre de retrait du contrat, et il est **soft** (invariant
  /// AD-9).
  ///
  /// Le contrat n'expose **aucun** membre de suppression dure : ni
  /// `hardDelete`, ni `purge`, ni `deleteForever`.
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  });

  /// Annule la requête **désignée par [requestId]** — jamais « la courante »
  /// (aucun jeton d'instance partagé).
  ///
  /// Une implémentation qui supprimerait un message ici réintroduirait un
  /// défaut classique d'annulation : effacer la question tapée au lieu de
  /// simplement interrompre la génération.
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

/// **Extension optionnelle** du port d'effet.
///
/// ## Pourquoi une seconde interface, et non un paramètre de plus
///
/// `ZChatRegenerateAction` porte des réglages et une portée documentaire. Il
/// fallait qu'ils **atteignent l'hôte** — un réglage transmis à l'appel puis
/// jeté sans signal serait un repli muet.
///
/// Mais ajouter un paramètre — **même optionnel** — à
/// [ZChatActionExecutor.regenerate] aurait invalidé **toutes** les
/// implémentations existantes : en Dart, un override doit accepter tous les
/// paramètres nommés de la déclaration qu'il redéfinit — rendre un paramètre
/// obligatoire sur une méthode déjà surchargée ailleurs casse ces
/// implémentations à la compilation.
///
/// ⇒ Le port historique est **intouché**. Un hôte qui veut recevoir les
/// réglages d'une régénération implémente **en plus** cette interface :
///
/// ```dart
/// class MonExecutor implements ZChatActionExecutor,
///     ZChatSettingsAwareActionExecutor { … }
/// ```
///
/// ## La règle du répartiteur — jamais un abandon silencieux
///
/// | Action | Executor | Chemin |
/// |---|---|---|
/// | `settings`/`corpusScope` **absents** | quelconque | `regenerate(messageId:)` — **inchangé**, à l'identique d'avant le lot |
/// | présents | implémente cette interface | [regenerateWithSettings] — l'action **entière** est remise |
/// | présents | ne l'implémente **pas** | `Left(ZUnsupportedOperationFailure)` — **jamais** un repli muet |
///
/// La troisième ligne est la propriété qui compte : un hôte ne peut pas
/// **croire** avoir restreint le corpus alors que sa demande a été jetée.
abstract interface class ZChatSettingsAwareActionExecutor {
  /// Régénère en recevant l'action **complète** (donc ses réglages et sa
  /// portée) ; rend les identités touchées.
  ///
  /// Même règle que les sept membres ci-dessus : invocable **uniquement**
  /// depuis `z_chat_action_dispatcher.dart`.
  Future<ZResult<List<String>>> regenerateWithSettings(
    ZChatRegenerateAction action,
  );
}
