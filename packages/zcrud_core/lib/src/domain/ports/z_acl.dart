/// Port d'**autorisation** neutre du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — contrôle d'accès fourni par l'app
/// (aucune règle métier dans le cœur). Canonique §7 ; AD-16 (`ZAcl` app-supplied).
library;

import '../contracts/z_entity.dart';

/// Action CRUD soumise à autorisation. Valeurs en **camelCase** (canonique §5).
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
