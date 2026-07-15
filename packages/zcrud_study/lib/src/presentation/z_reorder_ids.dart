/// `zReorderIds` — helper PUR de présentation (ES-5.3) : calcule le nouvel ordre
/// d'une liste d'ids après un déplacement `oldIndex → newIndex`.
///
/// Opération **DISTINCTE** d'`applyOrder<T>` (ES-1.2) : c'est un **déplacement**
/// (`removeAt`/`insert`), jamais un tri stable partiel. `applyOrder` réordonne
/// une collection selon un ordre personnel ; `zReorderIds` PRODUIT ce nouvel
/// ordre personnel à partir d'un drag. Les deux sont complémentaires (jamais un
/// doublon) : le rendu applique l'ordre (`applyOrder`/`applyTo`), le drag le
/// mute (`zReorderIds`), puis l'appelant persiste le résultat dans
/// `ZFolderContentsOrder.copyWith(sectionOrders: …)`.
///
/// Fonction **pure** (ne mute pas [ids], retourne une nouvelle liste) et
/// **totale** (AD-10) : indices hors bornes **clampés**, jamais de throw. La
/// convention d'indices est `removeAt(oldIndex)` PUIS `insert(newIndex)` dans la
/// liste **après retrait** — c'est la convention normalisée que le layout passe
/// à `ZStudyToolsSectionSpec.onReorder` (l'ajustement `newIndex -= 1` propre à
/// `ReorderableListView` pour les déplacements vers le bas est déjà appliqué en
/// amont par le layout).
library;

/// Déplace l'id situé à [oldIndex] vers [newIndex] et retourne la **nouvelle**
/// liste ordonnée (l'ordre relatif des autres ids est préservé).
///
/// - `zReorderIds(['a','b','c'], 0, 2)` → `['b','c','a']` (a en fin) ;
/// - `zReorderIds(['a','b','c'], 1, 0)` → `['b','a','c']` (b remonte) ;
/// - liste vide ⇒ liste vide ; indices hors bornes ⇒ **clampés** (jamais de
///   throw — AD-10).
List<String> zReorderIds(List<String> ids, int oldIndex, int newIndex) {
  final list = List<String>.of(ids);
  if (list.isEmpty) return list;
  // Clamp défensif de l'index source dans les bornes de la liste d'origine.
  final from = oldIndex.clamp(0, list.length - 1);
  final moved = list.removeAt(from);
  // Après retrait, `insert` accepte [0, list.length] (== length ⇒ ajout en fin).
  final to = newIndex.clamp(0, list.length);
  list.insert(to, moved);
  return list;
}
