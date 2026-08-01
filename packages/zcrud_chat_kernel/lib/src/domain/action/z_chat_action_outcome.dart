/// Issue d'une action exécutée — `ZChatActionOutcome`.
///
/// CHAT-0b, décisions **D5** et **D7**.
///
/// ## 🔴 Aucun texte libre où une exception pourrait se déguiser en réponse
///
/// Défaut IFFD n°4 : le **texte d'exception brut affiché comme contenu de
/// réponse**. Ce type ne porte donc **aucun** champ de texte libre susceptible
/// d'alimenter une bulle, à **une** exception explicitement demandée :
/// [copyPayload], alimenté **uniquement** par un `ZChatCopyAction`. Un échec
/// est un `Left(ZFailure)` — jamais une issue (garde **G-E2**).
library;

import 'z_chat_action.dart';

/// Ce qu'une action a réellement produit.
class ZChatActionOutcome {
  /// Construit une issue.
  const ZChatActionOutcome({
    required this.verb,
    this.affectedMessageIds = const <String>[],
    this.softDeleted = false,
    this.preservedDraft,
    this.copyPayload,
  });

  /// Verbe exécuté (technique, jamais un libellé traduisible).
  final String verb;

  /// Identités opaques des messages réellement touchés.
  final List<String> affectedMessageIds;

  /// 🔴 `true` **uniquement** pour un retrait, qui est **toujours** un
  /// soft-delete (D7, AD-9).
  ///
  /// ⚠️ lex (`chat_repository_impl.dart:408-424`) et IFFD
  /// (`FirebaseCrudRepositoryImpl.delete()`) font tous deux un **hard delete**
  /// et **divergent d'AD-9** : **zcrud prime** sur ses deux sources. Le contrat
  /// n'expose aucun membre de suppression dure (garde **G-S1**).
  ///
  /// ⚠️ Le drapeau `is_deleted` lui-même appartient à `ZSyncMeta`, **hors
  /// entité** (AD-16/AD-19) : ce contrat **nomme** la sémantique, il ne persiste
  /// rien.
  final bool softDeleted;

  /// Saisie **restituée intacte** (D3) — jamais `null` pour un verbe dont
  /// `preservesDraft` est vrai.
  final ZChatDraft? preservedDraft;

  /// Rendu de copie — **seul** texte libre du type, et seulement pour
  /// `ZChatCopyAction`.
  final String? copyPayload;

  @override
  String toString() => 'ZChatActionOutcome($verb, affected: '
      '${affectedMessageIds.length}, softDeleted: $softDeleted, '
      'draft: ${preservedDraft != null}, copy: ${copyPayload != null})';
}
