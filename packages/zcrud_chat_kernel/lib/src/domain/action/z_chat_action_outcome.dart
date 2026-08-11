/// Issue d'une action exécutée — `ZChatActionOutcome`.
///
/// ## Aucun texte libre où une exception pourrait se déguiser en réponse
///
/// Un texte d'exception brut affiché comme contenu de réponse est le défaut
/// que ce type ferme structurellement : il ne porte **aucun** champ de texte
/// libre susceptible d'alimenter une bulle, à **une** exception explicitement
/// demandée : [copyPayload], alimenté **uniquement** par un `ZChatCopyAction`.
/// Un échec est un `Left(ZFailure)` — jamais une issue.
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

  /// `true` **uniquement** pour un retrait, qui est **toujours** un
  /// soft-delete (invariant AD-9). Le contrat n'expose aucun membre de
  /// suppression dure.
  ///
  /// Le drapeau `is_deleted` lui-même appartient à `ZSyncMeta`, **hors
  /// entité** : ce contrat **nomme** la sémantique, il ne persiste rien.
  final bool softDeleted;

  /// Saisie **restituée intacte** — jamais `null` pour un verbe dont
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
