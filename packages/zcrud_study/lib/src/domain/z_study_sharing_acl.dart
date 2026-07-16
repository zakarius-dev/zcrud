/// 🔴🔴 Garde ACL de partage `ZStudySharingAcl` — **CŒUR de la story ES-9.4**
/// (AC5, NFR-S11 : dette de sécurité lex CORRIGÉE PAR CONCEPTION).
///
/// ## La dette héritée de lex (à ne PAS répéter)
///
/// Dans lex, un **contributeur** d'un dossier partagé pouvait modifier des
/// **champs de contrôle** (`isPublic`/`sharedWith`/`canBeJoinedWithLink`/
/// `coWorkersCanInviteOthers`/`shareId`/`ownerId`) : le partage était **baked**
/// dans l'entité dossier, et le merge **LWW** (AD-9) faisait « le dernier
/// écrivain gagne » **sans autorité** — un contributeur réécrivait ces champs, et
/// la **révocation** d'un lien ne prenait effet **qu'à la prochaine sync**.
///
/// ## La correction ES-9.4 — DEUX voies, in-domaine
///
/// 1. **Séparation structurelle** — les champs de contrôle vivent dans des
///    entités **owner-contrôlées** (`ZShareLink.ownerUid`/`revoked`,
///    `ZStudyMembership.role`, `ZPublicStudyFolder.ownerUid`/`listedAt`), **jamais**
///    routés par le sous-arbre partageable du dossier. Le bloc V2c de
///    `ZStudyFolder` reste **inerte**.
/// 2. **Prédicat d'autorisation PUR** — [canMutateControl] : **seul l'owner**
///    (ou un rôle explicitement habilité) mute un champ de contrôle ; un
///    **contributeur/viewer/inconnu** ne le peut **PAS**. Les ports
///    (`activateSharing`/`revokeShareLink`/`grantMembership`/`publish`)
///    **consomment** cette garde — une mutation de contrôle par un non-owner
///    remonte `Left(ZFailure)`, **jamais** un `Right` silencieux.
///
/// La **révocation** étant un champ de contrôle (`revoked`), un contributeur ne
/// peut **pas** la remettre à `false` : la « dé-révocation LWW » de lex est
/// **fermée** au niveau de l'autorisation domaine (révocation **monotone**).
///
/// ## 🔴 DW-ES94-1 — dette RÉSIDUELLE DOCUMENTÉE (jamais silencieuse)
///
/// L'**enforcement SERVEUR** (règles backend rejetant à la SOURCE une écriture
/// non autorisée, et l'atténuation du résiduel LWW « la garde locale ne bloque
/// pas une écriture forgée côté store distant ») est **HORS DOMAINE**
/// (backend-agnostique, AD-11/AD-12 ; le backend de partage est **fourni par
/// l'app**, AD-26). Le domaine fait **sa part** : séparation structurelle +
/// prédicat d'autorisation **pur, testable, consommé par les ports**, que les
/// **règles serveur de l'app DOIVENT répliquer**. Cette responsabilité résiduelle
/// est **DW-ES94-1** : elle satisfait NFR-S11 (« corrigée OU documentée
/// explicitement, jamais héritée en silence ») en faisant **les deux** — corrigée
/// in-domaine ET documentée ici comme obligation serveur non couverte par ce
/// package. **NE PAS** croire que la garde locale suffit à sécuriser un store
/// distant partagé : l'app doit répliquer [canMutateControl] côté règles backend.
///
/// [ZStudySharingAcl] est **pur, total, déterministe** : jamais de throw, jamais
/// d'IO, jamais de `DateTime.now()`.
library;

import 'z_study_membership.dart';

/// Garde ACL **pure** des champs de contrôle d'un dossier partagé (AC5).
///
/// Ne porte aucun état : toutes les décisions sont dérivées de ses arguments.
/// Exposée comme classe (et non fonctions libres) pour offrir une surface stable
/// que les ports et les règles serveur de l'app répliquent.
abstract final class ZStudySharingAcl {
  /// Ensemble **figé** des clés de **champ de contrôle** (persistées snake_case).
  ///
  /// Couvre : propriété (`owner_id`/`owner_uid`), listing public (`is_public`/
  /// `listed_at`), partage par lien (`can_be_joined_with_link`/
  /// `joinable_with_link`, `share_id`/`share_link_id`), invitation
  /// (`co_workers_can_invite_others`/`co_owners_can_invite`), membres partagés
  /// (`shared_with`), rôle d'adhésion (`role`) et **révocation** (`revoked`/
  /// `revoked_at`) — y compris les clés du bloc V2c **inerte** de `ZStudyFolder`
  /// (héritage lex) pour que la garde couvre AUSSI un payload legacy.
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

  /// `true` si [key] est un **champ de contrôle** owner-only (AC5).
  ///
  /// Pur et total : toute clé hors [controlFields] ⇒ `false`.
  static bool isControlField(String key) => controlFields.contains(key);

  /// 🔴 **Le prédicat d'autorisation load-bearing** (AC5, CŒUR).
  ///
  /// Retourne `true` **uniquement** si l'acteur est **owner** : soit
  /// explicitement par [role] == [ZMembershipRole.owner], soit parce que son
  /// [actorUid] **non vide** correspond à l'[ownerUid] du sujet. Un
  /// **contributeur/viewer/inconnu** qui n'est pas l'owner ⇒ `false` : il ne peut
  /// muter **aucun** champ de contrôle (propriété, révocation, listing,
  /// invitation, rôle).
  ///
  /// Conséquence directe (AC5 pt.3) : un contributeur ne peut **pas** dé-révoquer
  /// un lien (`revoked` est un champ de contrôle) — révocation **monotone**.
  ///
  /// Pur, total, déterministe : jamais de throw / IO / `DateTime.now()`.
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
