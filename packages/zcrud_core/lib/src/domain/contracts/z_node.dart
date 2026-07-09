/// Contrat de nœud d'arbre du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — nœuds de `Mindmap` / hiérarchie de
/// dossiers d'étude. Canonique §2 (topologie). OQ-4 (nesting vs flat) NON tranchée.
library;

/// Contrat abstrait **fin** d'un nœud d'arbre.
///
/// Un nœud matérialisé possède toujours une **clé de réconciliation** : [id]
/// est donc **non-null** (contrairement à `ZEntity.id`, nullable pour
/// l'éphémère).
///
/// Choix de portée (Story E2-1) : ce contrat **ne fige pas** la topologie.
/// Il n'expose ni `children` (représentation par *nesting*), ni
/// `parentId`/`sortOrder`/`depth` (représentation par *adjacency list*). Ces
/// représentations concrètes sont **différées** conformément à l'OQ-4 non
/// tranchée :
/// - `ZMindmapNode` (nesting) → E10 ;
/// - nœud de hiérarchie plat (adjacency) → E9/hiérarchie.
///
/// Garder ce contrat minimal évite de committer prématurément une topologie que
/// les deux consommateurs (mindmap, flashcard) implémenteront différemment.
abstract class ZNode {
  /// Constructeur `const` pour permettre des sous-classes immuables.
  const ZNode();

  /// Clé de réconciliation opaque du nœud (toujours présente : non-null).
  String get id;
}
