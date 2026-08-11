/// Contrat de nœud d'arbre du domaine `zcrud_core`.
library;

/// Contrat abstrait **fin** d'un nœud d'arbre.
///
/// Un nœud matérialisé possède toujours une **clé de réconciliation** : [id]
/// est donc **non-null** (contrairement à `ZEntity.id`, nullable pour
/// l'éphémère).
///
/// Ce contrat **ne fige pas** la topologie. Il n'expose ni `children`
/// (représentation par *nesting*), ni `parentId`/`sortOrder`/`depth`
/// (représentation par *adjacency list*). Ces représentations concrètes sont
/// laissées aux types concrets qui implémentent ce contrat — un nœud de
/// carte mentale (nesting) ou un nœud de hiérarchie plate (adjacency).
///
/// Garder ce contrat minimal évite de committer prématurément une topologie que
/// des consommateurs distincts implémenteront différemment.
abstract class ZNode {
  /// Constructeur `const` pour permettre des sous-classes immuables.
  const ZNode();

  /// Clé de réconciliation opaque du nœud (toujours présente : non-null).
  String get id;
}
