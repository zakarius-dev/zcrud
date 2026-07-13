/// `applyOrder<T>` — tri **stable** d'une collection selon un ordre personnel
/// **partiel** (`List<String>` d'ids), avec position **déterministe** des
/// items dont l'id est absent de l'ordre (ES-1.2, FR-S2, AC4).
///
/// Générique de **collection** (`T` + `idOf`), **sans dépendance métier** —
/// aucun type study dans sa signature (AD-3 : générique de collection autorisé,
/// jamais un générique de (dé)sérialisation). Usage prévu : `ZFolderContentsOrder`
/// (FR-S7) — ordre manuel d'un dossier d'étude — mais réutilisable pour tout
/// tri à ordre personnalisé partiel.
///
/// Fonction **pure** : ne mute ni `items` ni `order`, retourne une **nouvelle**
/// `List<T>`. **Défensive** (AD-10) : aucun des cas dégradés ne throw.
library;

/// Où placer les items dont l'id est **absent** de l'ordre personnel.
enum ZUnorderedPlacement {
  /// Après les items ordonnés (défaut).
  end,

  /// Avant les items ordonnés.
  start,
}

/// Applique [order] (liste d'ids, **partielle** possible) à [items] :
/// - les items dont `idOf(item)` figure dans [order] sortent **dans l'ordre
///   de [order]** ;
/// - les items **absents** de [order] gardent une position déterministe —
///   à la fin par défaut ([ZUnorderedPlacement.end]) ou au début
///   ([ZUnorderedPlacement.start]) — en préservant leur **ordre relatif
///   d'entrée** (tri **stable**) ;
/// - `order` **vide** → l'ordre d'entrée de [items] est intégralement
///   préservé ;
/// - un id de [order] qui ne correspond à **aucun** item est simplement
///   ignoré ;
/// - un id **dupliqué** dans [order] → la **1re** occurrence fait foi pour la
///   position ;
/// - des ids **dupliqués** dans [items] sont tous conservés, dans leur ordre
///   relatif d'entrée.
///
/// Ne mute ni [items] ni [order] ; retourne une **nouvelle** `List<T>`.
List<T> applyOrder<T>(
  Iterable<T> items,
  List<String> order, {
  required String Function(T item) idOf,
  ZUnorderedPlacement unordered = ZUnorderedPlacement.end,
}) {
  // Position de chaque id dans `order` — 1re occurrence gagne (AC4).
  final position = <String, int>{};
  for (var i = 0; i < order.length; i++) {
    position.putIfAbsent(order[i], () => i);
  }

  // Partition en UN SEUL passage, préservant l'ordre d'entrée dans chaque
  // sous-liste (nécessaire à la stabilité du tri final).
  final entries = items.toList(growable: false);
  final ordered = <_Indexed<T>>[];
  final unorderedItems = <T>[];
  for (var i = 0; i < entries.length; i++) {
    final item = entries[i];
    final pos = position[idOf(item)];
    if (pos != null) {
      ordered.add(_Indexed(pos, i, item));
    } else {
      unorderedItems.add(item);
    }
  }

  // Tri **stable** par construction : la clé secondaire (index d'entrée
  // d'origine) départage tout ex-aequo sur la position — indépendant de la
  // stabilité (non garantie) de `List.sort` du SDK.
  ordered.sort((a, b) {
    final byPosition = a.position.compareTo(b.position);
    return byPosition != 0 ? byPosition : a.entryIndex.compareTo(b.entryIndex);
  });
  final orderedItems = ordered.map((e) => e.item).toList(growable: false);

  return switch (unordered) {
    ZUnorderedPlacement.end => <T>[...orderedItems, ...unorderedItems],
    ZUnorderedPlacement.start => <T>[...unorderedItems, ...orderedItems],
  };
}

/// Item enveloppé de sa position dans `order` et de son index d'entrée
/// d'origine (départage stable).
class _Indexed<T> {
  const _Indexed(this.position, this.entryIndex, this.item);

  final int position;
  final int entryIndex;
  final T item;
}
