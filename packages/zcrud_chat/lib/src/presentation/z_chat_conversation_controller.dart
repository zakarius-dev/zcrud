/// Contrôleur d'une **conversation simple** — `ZChatConversationController`.
///
/// ## Le pendant du fil de travail
///
/// Une conversation sans artefact a les mêmes fonctionnalités de base qu'un
/// fil de travail : un [ZChatController] qui tient le fil et les tours, et la
/// **persistance du fil** par un [ZChatTranscriptPort]. Ce contrôleur
/// **compose** les deux, exactement comme `ZChatNotebookController` — la
/// mécanique de transcript ([ZChatTranscriptBinding]) est la même pièce,
/// écrite une fois.
///
/// Il ne rend aucun pixel, n'importe aucun gestionnaire d'état (invariants
/// AD-2/AD-15) et ne réimplémente **aucun** cycle de flux : envoyer, arrêter,
/// éditer, régénérer restent les verbes du [ZChatController] composé,
/// accessible par [chat].
///
/// ## Avec ou sans dépôt
///
/// * [transcript] **fourni** : le fil vient du dépôt (premier instantané =
///   amorce, abonnement tenu jusqu'à [dispose]) et chaque tour y est écrit ;
///   `initialMessages` n'est pas lu.
/// * [transcript] **absent** : `initialMessages` est la source du fil, rien
///   n'est persisté — le contrôleur de conversation est celui qu'un hôte
///   construirait à la main avec les mêmes ports.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_controller.dart';
import 'z_chat_live_labels.dart';
import 'z_chat_transcript_binding.dart';

/// Le contrôleur de conversation simple : une conversation composée, un fil
/// persisté quand un dépôt est fourni.
class ZChatConversationController extends ChangeNotifier {
  /// Construit un contrôleur de conversation pour [conversationId].
  ///
  /// Port **requis** : [streamPort] (génération des réponses).
  ///
  /// Ports et réglages **optionnels, à défaut inerte** :
  /// * [transcript] — lecture et écriture du fil ; absent, [initialMessages]
  ///   est la source et rien n'est persisté ;
  /// * [initialMessages] — le fil initial, lu seulement sans [transcript] ;
  /// * [actionExecutor] — défaut [ZChatUnsupportedActionExecutor] ;
  /// * [confirm] — défaut [zChatConfirmWithoutDialog] : un verbe destructeur
  ///   est **refusé** tant qu'un dialogue n'est pas branché ;
  /// * [newRequestId] — défaut [ZChatSequentialRequestIds] ;
  /// * [buildRequest] — défaut [ZChatDraftRequestBuilder] sur le style
  ///   `converse`, copiant tout le brouillon ;
  /// * [lifecycle], [routeResolver], [liveLabels], [maxResumeAttempts] —
  ///   relayés au contrôleur de conversation.
  ZChatConversationController({
    required ZChatStreamPort streamPort,
    required String conversationId,
    ZChatTranscriptPort? transcript,
    List<ZChatMessage> initialMessages = const <ZChatMessage>[],
    ZChatActionExecutor actionExecutor = const ZChatUnsupportedActionExecutor(),
    ZChatConfirm confirm = zChatConfirmWithoutDialog,
    ZChatRequestIdFactory? newRequestId,
    ZChatRequestBuilder? buildRequest,
    ZChatConversationLifecyclePort? lifecycle,
    ZChatRouteResolver? routeResolver,
    ZChatLiveLabels liveLabels = ZChatLiveLabels.none,
    int maxResumeAttempts = 2,
  }) : _conversationId = conversationId {
    chat = ZChatController(
      streamPort: streamPort,
      actionExecutor: actionExecutor,
      confirm: confirm,
      newRequestId:
          newRequestId ?? ZChatSequentialRequestIds(conversationId).call,
      buildRequest: buildRequest ??
          ZChatDraftRequestBuilder(
            style: ZChatGenerationStyle.converse,
            conversationId: conversationId,
          ).call,
      lifecycle: lifecycle,
      routeResolver: routeResolver,
      liveLabels: liveLabels,
      maxResumeAttempts: maxResumeAttempts,
      conversationId: conversationId,
      // Avec un dépôt, le fil vient de lui : l'amorce remplace tout fil
      // initial, qui n'est donc pas lu.
      initialMessages:
          transcript == null ? initialMessages : const <ZChatMessage>[],
    );
    // Sans dépôt, aucune pièce de transcript : le contrôleur composé est
    // strictement celui des briques.
    if (transcript != null) {
      _binding = ZChatTranscriptBinding(
        transcript: transcript,
        chat: chat,
        conversationId: conversationId,
      );
    }
  }

  /// Le contrôleur de conversation composé — celui que les vues reçoivent.
  late final ZChatController chat;

  final String _conversationId;
  ZChatTranscriptBinding? _binding;

  /// Tranche inerte, pour un contrôleur sans dépôt : toujours `null`.
  final ValueNotifier<ZFailure?> _noFailure = ValueNotifier<ZFailure?>(null);

  /// Identité de la conversation.
  String get conversationId => _conversationId;

  /// `true` si le fil est tenu par un dépôt.
  bool get isPersisted => _binding != null;

  /// Dernier échec d'**écriture du fil** au dépôt, ou `null` — toujours
  /// `null` sans dépôt. Les échecs de tour sont sur `chat.lastFailure`.
  ValueListenable<ZFailure?> get lastFailure =>
      _binding?.lastFailure ?? _noFailure;

  /// Le message [messageId] du fil, ou `null`.
  ZChatMessage? messageById(String messageId) => chat.messageById(messageId);

  /// Le message apparié à [messageId], ou `null` (cf.
  /// [ZChatController.replyToOf]).
  ZChatMessage? replyToOf(String messageId) => chat.replyToOf(messageId);

  /// Le texte brut de [messageId], ou `null`.
  String? contentOf(String messageId) => chat.contentOf(messageId);

  @override
  void dispose() {
    // L'abonnement au fil d'abord : rien ne doit plus entrer.
    _binding?.dispose();
    _binding = null;
    _noFailure.dispose();
    chat.dispose();
    super.dispose();
  }
}
