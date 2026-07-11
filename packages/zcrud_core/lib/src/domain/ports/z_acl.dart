/// Port d'**autorisation** neutre du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — contrôle d'accès fourni par l'app
/// (aucune règle métier dans le cœur). Canonique §7 ; AD-16 (`ZAcl` app-supplied).
library;

import '../contracts/z_entity.dart';

/// Action CRUD soumise à autorisation. Valeurs en **camelCase** (canonique §5).
///
/// **Ordre ADDITIF, jamais réordonné/renommé** (DP-14) : les 6 actions étendues
/// (`copy`…`history`) sont ajoutées **après** les 5 historiques
/// (`view`/`create`/`update`/`delete`/`restore`) pour couvrir les 11 flags du
/// `RessourceACL` DODLP (`copy/archive/publish/clear/validate/history`) tout en
/// gardant une rétro-compatibilité stricte. Le mapping DODLP est **documentaire**
/// (aucune dépendance de code au cœur — AD-1).
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

  /// Restaurer une entité soft-deleted (corbeille, E4-4).
  restore,

  /// Dupliquer une entité (miroir de `RessourceACL.copy` DODLP).
  copy,

  /// Archiver une entité (miroir de `RessourceACL.archive` DODLP).
  archive,

  /// Publier une entité (miroir de `RessourceACL.publish` DODLP).
  publish,

  /// Vider / réinitialiser une entité (miroir de `RessourceACL.clear` DODLP).
  clear,

  /// Valider une entité (miroir de `RessourceACL.validate` DODLP).
  validate,

  /// Consulter l'historique d'une entité (miroir de `RessourceACL.history`
  /// DODLP).
  history,
}

/// Port d'autorisation **synchrone** fourni par l'application hôte.
///
/// **Aucune règle métier** ne vit dans le cœur (AD-16) : l'implémentation
/// concrète (rôles, ACL par collection…) est fournie par l'app. Consommé par
/// E4-4 pour filtrer les actions de ligne d'une liste.
///
/// Une ACL **asynchrone** (décision distante) est **différée** : le contrat
/// synchrone couvre le besoin immédiat (filtrage d'actions ligne).
abstract class ZAcl {
  /// Retourne `true` si [action] est autorisée sur la [target] optionnelle
  /// (ou la collection [collectionId]), `false` sinon. Décision **synchrone**.
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId});
}

/// Implémentation **permissive** par défaut (zéro-config) : autorise tout.
///
/// Utile comme valeur par défaut tant que l'app n'injecte pas d'ACL réelle.
class ZAllowAllAcl implements ZAcl {
  /// Construit l'ACL permissive (`const`).
  const ZAllowAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => true;
}
