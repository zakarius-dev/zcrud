/// Garde d'autorisation pure des champs de contrôle d'un dossier d'étude
/// partagé.
///
/// Un partage correctement conçu sépare deux préoccupations : quels champs
/// gouvernent le partage (propriété, visibilité publique, invitation, rôle,
/// révocation) et qui a le droit de les modifier. Cette garde répond à la
/// seconde question, de façon pure et testable :
///
/// - les champs de contrôle vivent dans des entités contrôlées par le
///   propriétaire (`ZShareLink.ownerUid`/`revoked`, `ZStudyMembership.role`,
///   `ZPublicStudyFolder.ownerUid`/`listedAt`) plutôt que dans le sous-arbre
///   librement synchronisable du dossier ;
/// - [canMutateControl] est le prédicat d'autorisation : seul le
///   propriétaire (ou un rôle explicitement habilité) peut muter un champ de
///   contrôle. Un contributeur, un lecteur ou un acteur inconnu ne le peut
///   pas. Les ports de partage et de modération consomment cette garde —
///   une mutation de contrôle tentée par un non-propriétaire remonte
///   `Left(ZFailure)`, jamais un `Right` silencieux.
///
/// La révocation étant elle-même un champ de contrôle (`revoked`), un
/// contributeur ne peut pas la remettre à `false` : la révocation d'un lien
/// est **monotone**.
///
/// Cette garde couvre la partie domaine du problème. L'**application hôte**
/// reste responsable de répliquer [canMutateControl] dans ses propres règles
/// de sécurité serveur (invariant AD-5 : domaine backend-agnostique,
/// invariant AD-12 : zéro secret ni backend en dur) — la garde locale seule
/// ne protège pas un store distant contre une écriture forgée hors de
/// l'application.
///
/// [ZStudySharingAcl] est pur, total et déterministe : jamais de `throw`,
/// jamais d'entrée/sortie, jamais de `DateTime.now()`.
library;

import 'z_study_membership.dart';

/// Garde ACL pure des champs de contrôle d'un dossier partagé.
///
/// Ne porte aucun état : toutes les décisions sont dérivées de ses
/// arguments. Exposée comme classe (et non comme fonctions libres) pour
/// offrir une surface stable que les ports et les règles serveur de
/// l'application répliquent.
abstract final class ZStudySharingAcl {
  /// Ensemble figé des clés de champ de contrôle (persistées en snake_case).
  ///
  /// Couvre : propriété (`owner_id`/`owner_uid`), listing public
  /// (`is_public`/`listed_at`), partage par lien
  /// (`can_be_joined_with_link`/`joinable_with_link`,
  /// `share_id`/`share_link_id`), invitation
  /// (`co_workers_can_invite_others`/`co_owners_can_invite`), membres
  /// partagés (`shared_with`), rôle d'adhésion (`role`) et révocation
  /// (`revoked`/`revoked_at`) — y compris les variantes de nommage héritées
  /// d'un schéma antérieur, pour que la garde couvre aussi un payload
  /// legacy.
  static const Set<String> controlFields = <String>{
    // Propriété
    'owner_id',
    'owner_uid',
    // Listing public
    'is_public',
    'listed_at',
    // Partage par lien
    'can_be_joined_with_link',
    'joinable_with_link',
    'share_id',
    'share_link_id',
    // Invitation
    'co_workers_can_invite_others',
    'co_owners_can_invite',
    // Membres partagés
    'shared_with',
    // Rôle d'adhésion
    'role',
    // Révocation (monotone)
    'revoked',
    'revoked_at',
  };

  /// `true` si [key] est un champ de contrôle réservé au propriétaire.
  ///
  /// Pur et total : toute clé hors [controlFields] retourne `false`.
  static bool isControlField(String key) => controlFields.contains(key);

  /// Le prédicat d'autorisation central de ce paquet.
  ///
  /// Retourne `true` uniquement si l'acteur est propriétaire : soit
  /// explicitement par [role] == [ZMembershipRole.owner], soit parce que son
  /// [actorUid] non vide correspond à l'[ownerUid] du sujet. Un
  /// contributeur, un lecteur ou un acteur inconnu qui n'est pas le
  /// propriétaire retourne `false` : il ne peut muter aucun champ de
  /// contrôle (propriété, révocation, listing, invitation, rôle).
  ///
  /// Conséquence directe : un contributeur ne peut pas dé-révoquer un lien
  /// (`revoked` est un champ de contrôle) — la révocation est monotone.
  ///
  /// Pur, total, déterministe : jamais de `throw`, d'entrée/sortie ni de
  /// `DateTime.now()`.
  static bool canMutateControl({
    required String actorUid,
    required String ownerUid,
    required ZMembershipRole role,
  }) {
    final isOwnerByRole = role == ZMembershipRole.owner;
    final isOwnerByIdentity = actorUid.isNotEmpty && actorUid == ownerUid;
    return isOwnerByRole || isOwnerByIdentity;
  }
}
