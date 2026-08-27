/// **La persistance du brouillon** — un port, parce que persister est une
/// décision d'hôte.
///
/// Domaine PUR (aucun Flutter, aucun stockage, aucune dépendance nouvelle).
///
/// ## Les trois règles normatives portées par ce fichier
///
/// 1. **Le socle ne persiste rien : il délègue.** Où le brouillon vit
///    (mémoire, fichier, base locale, compte distant), combien de temps il
///    survit et s'il traverse les appareils sont des choix d'application. Le
///    socle transporte un [ZChatDraftStore] et n'embarque aucun moteur de
///    stockage.
/// 2. **Un brouillon absent n'est pas une panne.** `Right(null)` dit « rien
///    d'enregistré » ; seul un `Left` signale une panne du stockage
///    (invariant AD-5). Confondre les deux ferait clignoter une erreur à
///    chaque première ouverture d'une conversation.
/// 3. **Le port par défaut est inerte, jamais absent.** Sans store déclaré,
///    lire rend « rien », écrire réussit sans effet : la saisie continue,
///    aucun appelant n'a besoin d'un chemin d'exception (invariant AD-10).
library;

import 'package:zcrud_core/domain.dart';

import '../action/z_chat_action.dart';

/// Le port par lequel l'hôte **conserve** la saisie en cours d'une
/// conversation.
abstract interface class ZChatDraftStore {
  /// Rend le brouillon de [conversationId], ou `Right(null)` si aucun n'est
  /// enregistré. Un `Left` signale une panne du stockage, pas une absence.
  Future<ZResult<ZChatDraft?>> read(String conversationId);

  /// Enregistre [draft] pour [conversationId].
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft);

  /// Efface le brouillon de [conversationId].
  ///
  /// Effacer ce qui n'existe pas **réussit** : l'appelant qui vient d'envoyer
  /// son message n'a pas à savoir s'il y avait quelque chose à effacer.
  Future<ZResult<Unit>> clear(String conversationId);
}

/// Store **inerte** : il ne conserve rien et n'échoue jamais.
///
/// C'est le défaut d'un hôte qui ne veut pas de brouillon persistant. La
/// saisie vit alors le temps de la session, ce qui est un choix légitime — et
/// aucun appelant n'a de chemin d'erreur à écrire pour l'obtenir.
class ZChatNullDraftStore implements ZChatDraftStore {
  /// Construit le store inerte.
  const ZChatNullDraftStore();

  @override
  Future<ZResult<ZChatDraft?>> read(String conversationId) async =>
      const Right<ZFailure, ZChatDraft?>(null);

  @override
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> clear(String conversationId) async =>
      const Right<ZFailure, Unit>(unit);
}

/// Store **en mémoire**, cloisonné par conversation.
///
/// Il ne survit pas au processus : c'est une commodité de test et une base de
/// démarrage pour un hôte, **pas** une persistance. Un brouillon vide (ni
/// texte, ni pièce jointe) est traité comme un effacement : conserver le vide
/// ferait ressusciter une saisie que l'utilisateur a effacée.
class ZChatInMemoryDraftStore implements ZChatDraftStore {
  /// Construit le store mémoire.
  ZChatInMemoryDraftStore();

  final Map<String, ZChatDraft> _drafts = <String, ZChatDraft>{};

  @override
  Future<ZResult<ZChatDraft?>> read(String conversationId) async =>
      Right<ZFailure, ZChatDraft?>(_drafts[conversationId]);

  @override
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft) async {
    if (draft.text.isEmpty && draft.attachmentIds.isEmpty) {
      _drafts.remove(conversationId);
    } else {
      _drafts[conversationId] = draft;
    }
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> clear(String conversationId) async {
    _drafts.remove(conversationId);
    return const Right<ZFailure, Unit>(unit);
  }
}
