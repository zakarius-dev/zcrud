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

/// Implémentation **permissive** par défaut (zéro-config) : autorise tout.
///
/// Utile comme valeur par défaut tant que l'app n'injecte pas d'ACL réelle.
class ZAllowAllAcl implements ZAcl {
  /// Construit l'ACL permissive (`const`).
  const ZAllowAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => true;
}
