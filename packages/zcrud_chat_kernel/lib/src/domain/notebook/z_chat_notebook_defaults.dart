/// Défauts **prêts à brancher** pour les trois seams triviaux d'un
/// contrôleur de conversation : la traduction brouillon → requête
/// ([ZChatDraftRequestBuilder]), la fabrique d'identités de requête
/// ([ZChatSequentialRequestIds]) et la confirmation sans dialogue
/// ([zChatConfirmWithoutDialog]).
///
/// Chacun est remplaçable par l'hôte ; chacun rend **inexprimable** un
/// défaut que l'écriture à la main autorise :
///
/// * un brouillon traduit champ par champ **oublie** un champ — les pièces
///   jointes partent vides alors que l'utilisateur les voit attachées ;
/// * une fabrique d'identités improvisée produit des collisions entre
///   conversations ;
/// * une confirmation écrite `async => true` **cesse de demander** le jour où
///   un verbe destructeur apparaît.
library;

import '../action/z_chat_action.dart';
import '../action/z_chat_action_plan.dart';
import '../ai/z_chat_corpus_scope.dart';
import '../ai/z_chat_generation_port.dart';
import '../ai/z_chat_generation_style.dart';

/// Traduit un [ZChatDraft] en [ZChatGenerationRequest] en copiant
/// **intégralement** le brouillon — texte **et** pièces jointes.
///
/// Les paramètres fixes (style, conversation, sujet, langue, modèle,
/// consigne, portée) sont donnés une fois à la construction ; le brouillon
/// est le seul variable. Une instance est assignable à un
/// `ZChatGenerationRequest Function(ZChatDraft)` par son [call].
class ZChatDraftRequestBuilder {
  /// Construit le traducteur.
  const ZChatDraftRequestBuilder({
    required this.style,
    this.conversationId,
    this.subject = '',
    this.languageTag,
    this.modelId,
    this.instructions,
    this.corpusScope,
  });

  /// Style appliqué à chaque requête.
  final ZChatGenerationStyle style;

  /// Conversation concernée, ou `null`.
  final String? conversationId;

  /// Sujet appliqué à chaque requête.
  final String subject;

  /// Étiquette de langue, ou `null`.
  final String? languageTag;

  /// Identifiant de modèle opaque, ou `null`.
  final String? modelId;

  /// Consigne neutre, ou `null`.
  final String? instructions;

  /// Portée documentaire, ou `null`.
  final ZChatCorpusScope? corpusScope;

  /// La requête pour [draft] : `notes` reçoit le texte, `attachmentIds`
  /// reçoit **toutes** les pièces jointes.
  ZChatGenerationRequest call(ZChatDraft draft) => ZChatGenerationRequest(
        style: style,
        subject: subject,
        notes: draft.text,
        conversationId: conversationId,
        attachmentIds: draft.attachmentIds,
        languageTag: languageTag,
        modelId: modelId,
        instructions: instructions,
        corpusScope: corpusScope,
      );
}

/// Fabrique **déterministe** d'identités de requête :
/// `<conversationId>:<n>`, `n` croissant à partir de [start].
///
/// Une instance par conversation ; l'identité est unique **dans cet
/// espace** — c'est à l'hôte de garantir que deux conversations n'ont pas le
/// même identifiant. Assignable à un `String Function()` par son [call].
class ZChatSequentialRequestIds {
  /// Construit la fabrique pour [conversationId], en démarrant à [start].
  ZChatSequentialRequestIds(this.conversationId, {int start = 0})
      : _next = start;

  /// Espace d'identités.
  final String conversationId;

  int _next;

  /// Prochaine valeur qui sera émise.
  int get next => _next;

  /// Émet une identité neuve.
  String call() => '$conversationId:${_next++}';
}

/// Confirmation **sans dialogue** : accepte un plan qui n'exige aucune
/// confirmation, **refuse** tout plan qui en exige une.
///
/// C'est le défaut sûr d'un hôte qui n'a encore aucun verbe destructeur :
/// rien ne lui est demandé aujourd'hui, et le jour où un verbe destructeur
/// apparaît, il est **refusé** tant qu'un vrai dialogue n'est pas branché —
/// jamais exécuté sans question. Assignable à un
/// `Future<bool> Function(ZChatActionPlan)`.
Future<bool> zChatConfirmWithoutDialog(ZChatActionPlan plan) async =>
    !plan.requiresConfirmation;
