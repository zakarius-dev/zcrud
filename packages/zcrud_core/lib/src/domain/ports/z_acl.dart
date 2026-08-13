/// Port d'**autorisation** neutre du domaine `zcrud_core`.
///
/// Aucune règle métier ne vit dans le cœur : l'ACL est fournie par l'app
/// hôte (AD-16, `ZAcl` app-supplied).
library;

import '../contracts/z_entity.dart';

/// Action CRUD soumise à autorisation. Valeurs en **camelCase** (canonique §5).
///
/// **Ordre ADDITIF, jamais réordonné/renommé** : les actions étendues
/// (`copy`…`history`) sont ajoutées **après** les cinq actions historiques
/// (`view`/`create`/`update`/`delete`/`restore`) pour couvrir des besoins
/// applicatifs plus riches (dupliquer, archiver, publier, vider, valider,
/// consulter l'historique) tout en gardant une rétro-compatibilité stricte.
///
/// **Sérialisation (posture additive/défensive — AD-3/AD-10)** : cet enum n'est
/// sérialisé **nulle part** aujourd'hui (aucun `@JsonKey`, aucun `toJson/fromJson`)
/// ⇒ aucune migration de données. **S'il** devenait sérialisé, la (dé)sérialisation
/// DOIT être défensive (`@JsonKey(unknownEnumValue: …)` ou `fromJsonSafe → null`),
/// les valeurs restant en **camelCase** (canonique §5) et l'évolution **additive
/// seulement** (nouvelles valeurs en fin d'enum).
///
/// **Consommateurs non exhaustifs** : les call-sites (`ZAcl.can`, le champ
/// `ZCrudAction? requiredPermission`) ne font AUCUN `switch` exhaustif — l'ajout
/// n'invalide aucune exhaustivité. Tout futur `switch (action)` DOIT porter une
/// branche `default` défensive (AD-10).
enum ZCrudAction {
  /// Consulter / lister.
  view,

  /// Créer une entité.
  create,

  /// Modifier une entité.
  update,

  /// Supprimer (soft-delete) une entité.
  delete,

  /// Restaurer une entité soft-deleted (corbeille).
  restore,

  /// Dupliquer une entité.
  copy,

  /// Archiver une entité.
  archive,

  /// Publier une entité.
  publish,

  /// Vider / réinitialiser une entité.
  clear,

  /// Valider une entité.
  validate,

  /// Consulter l'historique d'une entité.
  history,
}

/// Classification **lecture / écriture** d'une action CRUD.
///
/// Un formulaire en mode **lecture seule** doit couper toutes les actions
/// d'**écriture** sans couper les actions de lecture (une consultation reste
/// légitime) : filtrer uniquement sur l'ACL ne suffit pas, il faut aussi une
/// classification explicite de la nature de chaque action.
///
/// Pur-Dart (couche `domain`) : aucune dépendance Flutter.
extension ZCrudActionMutation on ZCrudAction {
  /// `true` si l'action **modifie** la donnée (donc interdite en lecture seule).
  ///
  /// Seules [ZCrudAction.view] et [ZCrudAction.history] sont des actions de
  /// **lecture**. Toutes les autres écrivent — y compris [ZCrudAction.copy]
  /// (crée une entité), [ZCrudAction.validate] et [ZCrudAction.publish] (font
  /// transiter un état persisté).
  bool get mutatesData => switch (this) {
        ZCrudAction.view || ZCrudAction.history => false,
        ZCrudAction.create ||
        ZCrudAction.update ||
        ZCrudAction.delete ||
        ZCrudAction.restore ||
        ZCrudAction.copy ||
        ZCrudAction.archive ||
        ZCrudAction.publish ||
        ZCrudAction.clear ||
        ZCrudAction.validate =>
          true,
      };
}

/// Port d'autorisation **synchrone** fourni par l'application hôte.
///
/// **Aucune règle métier** ne vit dans le cœur (AD-16) : l'implémentation
/// concrète (rôles, ACL par collection…) est fournie par l'app. Consommé
/// notamment pour filtrer les actions de ligne d'une liste.
///
/// Une ACL **asynchrone** (décision distante) est **différée** : le contrat
/// synchrone couvre le besoin immédiat (filtrage d'actions ligne).
abstract class ZAcl {
  /// Retourne `true` si [action] est autorisée sur la [target] optionnelle
  /// (ou la collection [collectionId]), `false` sinon. Décision **synchrone**.
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId});
}

/// Implémentation **permissive** : autorise tout, sans condition.
///
/// ⚠️ Ce n'est **plus** le repli par défaut du socle (voir [ZDenyAllAcl]) :
/// c'est un **choix explicite** de développement, de prototype ou de test.
/// L'oubli d'une ACL ne doit jamais ouvrir tous les gestes ; la déclarer
/// permissive, si.
///
/// À déclarer nommément, au scope ou à l'écran :
///
/// ```dart
/// ZcrudScope(acl: const ZAllowAllAcl(), child: monEcran);
/// ZCrudScreen<Dossier>(acl: const ZAllowAllAcl(), /* … */);
/// ```
///
/// En production, remplacez-la par votre propre implémentation de [ZAcl]
/// (rôles, droits par collection…) : aucune règle métier ne vit dans le socle.
class ZAllowAllAcl implements ZAcl {
  /// Construit l'ACL permissive (`const`).
  const ZAllowAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => true;
}

/// Implémentation **refusante** : interdit tout, sans condition. C'est le
/// **repli par défaut** du socle quand aucune ACL n'a été déclarée.
///
/// ## Pourquoi un refus par défaut
///
/// Une application qui **oublie** de brancher son ACL doit voir *aucun* geste,
/// jamais *tous* les gestes. Un repli permissif transforme un oubli de câblage
/// en ouverture silencieuse de la création, de la modification, de la mise à la
/// corbeille et de la restauration — sans aucune erreur, sans aucun signal. Le
/// repli refusant transforme le même oubli en absence visible de boutons : le
/// défaut se voit à l'écran, immédiatement, et se corrige en une ligne.
///
/// ## Comment brancher une ACL réelle
///
/// Implémentez [ZAcl] avec vos règles, puis déclarez-la une fois pour tout un
/// sous-arbre :
///
/// ```dart
/// class MonAcl implements ZAcl {
///   const MonAcl(this.role);
///   final String role;
///
///   @override
///   bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
///     if (action == ZCrudAction.view) return true;
///     return role == 'admin';
///   }
/// }
///
/// ZcrudScope(acl: MonAcl(session.role), child: monEcran);
/// ```
///
/// Un écran peut aussi porter la sienne : `ZCrudScreen(acl: MonAcl(...))`
/// l'emporte alors sur celle du scope ambiant, pour ce seul écran.
///
/// ## Comment retrouver l'ancien comportement (développement / prototype)
///
/// Déclarez explicitement l'ACL permissive — c'est le geste que doit faire une
/// application qui s'appuyait, sciemment ou non, sur l'ancien repli :
///
/// ```dart
/// ZcrudScope(acl: const ZAllowAllAcl(), child: monEcran);
/// ```
///
/// Ce geste est **volontaire et lisible** dans le code de l'application : c'est
/// toute la différence avec un repli implicite.
class ZDenyAllAcl implements ZAcl {
  /// Construit l'ACL refusante (`const`).
  const ZDenyAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      false;
}

/// Composition **restrictive** de deux autorisations : un geste n'est offert
/// que si [base] **et** [restriction] l'accordent tous les deux.
///
/// ## À quoi ça sert
///
/// Une autorisation se déclare souvent à plusieurs endroits : au scope de
/// l'application, à l'écran, puis à un onglet d'un écran segmenté. La question
/// est alors : que fait la déclaration la plus proche de l'usager ? Deux
/// réponses sont possibles, et une seule est sûre.
///
/// * *Remplacer* — l'onglet dit le dernier mot. Une déclaration d'onglet
///   trop généreuse **rouvre** alors un geste que l'application avait refusé,
///   sans qu'aucune erreur ne le signale.
/// * *Restreindre* — c'est **ce type**. Une déclaration plus proche ne peut
///   que **retirer** : elle affine un droit déjà accordé, jamais l'inverse.
///
/// L'intersection est la seule composition qui rende un élargissement
/// **inexprimable** : quoi que déclare la restriction, aucun geste refusé par
/// [base] ne peut réapparaître.
///
/// ```dart
/// // L'onglet « Archives » ne rend AUCUN geste : au mieux, il en retire.
/// final aclDeLOnglet = zRestrictAcl(aclDeLEcran, aclDeclareeSurLOnglet);
/// ```
class ZRestrictedAcl implements ZAcl {
  /// Compose [base] (l'autorisation héritée) et [restriction] (la déclaration
  /// la plus proche de l'usager) en **conjonction**.
  const ZRestrictedAcl(this.base, this.restriction);

  /// Autorisation **héritée** — celle du niveau supérieur (scope, écran).
  final ZAcl base;

  /// Autorisation **restreignante** — celle du niveau le plus proche
  /// (onglet, section). Elle ne peut que retirer.
  final ZAcl restriction;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      base.can(action, target: target, collectionId: collectionId) &&
      restriction.can(action, target: target, collectionId: collectionId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRestrictedAcl &&
          other.base == base &&
          other.restriction == restriction;

  @override
  int get hashCode => Object.hash(base, restriction);

  @override
  String toString() => 'ZRestrictedAcl($base ∩ $restriction)';
}

/// Restreint [base] par [restriction], en évitant d'emballer pour rien.
///
/// Retourne [base] tel quel quand aucune restriction n'est déclarée
/// (`restriction == null`) : une déclaration absente ne change rien, ni dans
/// un sens ni dans l'autre. Sinon, retourne la composition **conjonctive**
/// ([ZRestrictedAcl]) — le résultat n'accorde jamais plus que [base].
ZAcl zRestrictAcl(ZAcl base, ZAcl? restriction) =>
    restriction == null ? base : ZRestrictedAcl(base, restriction);
