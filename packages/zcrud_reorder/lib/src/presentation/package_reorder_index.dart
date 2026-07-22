/// Normalisation des **conventions d'index** du paquet tiers vers la convention
/// LINÉAIRE du port `ZReorderRenderer` (AD-57, condition 2 : le tiers est une
/// implémentation, jamais le contrat).
///
/// **Aucun import du paquet tiers ici** : ce fichier est de l'arithmétique pure,
/// testable sans surface widget (et donc réellement mordant — discipline R3).
library;

/// Résultat d'une normalisation : un couple d'index **linéaires** en convention
/// `removeAt(oldIndex)` puis `insert(newIndex)`, ou `null` si le mouvement est
/// un **no-op** (rien à notifier à l'hôte).
typedef ZLinearMove = ({int oldIndex, int newIndex});

/// Convertit le couple `(oldIndex, newIndex)` **brut** émis par
/// `reorderable_grid_view` en un mouvement LINÉAIRE conforme au port.
///
/// ## Convention réelle du paquet tiers (vérifiée dans sa source, v2.2.8)
///
/// `ReorderableGridStateMixin` appelle `widget.onReorder(_dragIndex, _dropIndex)`
/// où `_dropIndex` est calculé par `_calcDropIndex` : c'est l'**index de l'item
/// actuellement survolé** par le centre du glissement, dans l'ordre d'affichage
/// courant. C'est donc **déjà** un index de destination `0..n-1` en convention
/// `removeAt`/`insert` — exactement ce que documente l'exemple du paquet
/// (`data.removeAt(oldIndex); data.insert(newIndex, element);`).
///
/// ## Le piège, énoncé explicitement
///
/// La convention du SDK (`ReorderableListView`) est **différente** : elle passe
/// un `newIndex` **NON ajusté** (index d'insertion calculé *avant* le retrait),
/// que l'appelant doit décrémenter quand `newIndex > oldIndex`. Appliquer cet
/// ajustement ici serait un **bug silencieux** : glisser le premier item sur le
/// dernier le déposerait une case trop tôt. Le paquet tiers ayant déjà l'index
/// ajusté, la normalisation consiste à **ne pas** le ré-ajuster — et à borner.
///
/// ## Ce que la normalisation fait réellement (AD-10 — jamais de `throw`)
///
/// * `length <= 0` ⇒ `null` (rien à réordonner) ;
/// * index hors bornes (le paquet peut émettre un index d'item démonté) ⇒
///   **clampés** dans `0..length - 1` plutôt que propagés ;
/// * `oldIndex == newIndex` après clamp ⇒ `null` : le paquet notifie aussi les
///   dépôts sur place (`_onDragEnd` appelle `onReorder` même sans mouvement),
///   que l'hôte ne doit **pas** voir comme une écriture.
ZLinearMove? normalizePackageReorder({
  required int rawOldIndex,
  required int rawNewIndex,
  required int length,
}) {
  if (length <= 0) return null;
  final int oldIndex = rawOldIndex.clamp(0, length - 1);
  // 🔴 PAS de `- 1` quand `rawNewIndex > oldIndex` : ce serait la convention
  // `ReorderableListView`, pas celle de `reorderable_grid_view`.
  final int newIndex = rawNewIndex.clamp(0, length - 1);
  if (oldIndex == newIndex) return null;
  return (oldIndex: oldIndex, newIndex: newIndex);
}

/// Applique un mouvement LINÉAIRE `removeAt(from)` / `insert(to)` sur [ids].
///
/// Total et non mutant (indices clampés, jamais de `throw` — AD-10). C'est
/// **exactement** la transformation de référence du repli
/// `ZDefaultReorderRenderer`, dupliquée ici parce que la frontière de paquets
/// l'impose (elle est privée dans `zcrud_responsive`) — verrouillée par le test
/// d'interchangeabilité.
List<String> applyLinearMove(List<String> ids, int from, int to) {
  final List<String> list = List<String>.of(ids);
  if (list.isEmpty) return list;
  final int source = from.clamp(0, list.length - 1);
  final String moved = list.removeAt(source);
  final int target = to.clamp(0, list.length);
  list.insert(target, moved);
  return list;
}

/// Égalité positionnelle de deux listes d'ids (ordre-sensible).
bool listOrderEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
