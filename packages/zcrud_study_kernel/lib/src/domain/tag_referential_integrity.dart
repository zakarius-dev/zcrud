/// Intégrité référentielle des tags — primitive pure de **détection** des
/// références orphelines.
///
/// **Détection, pas purge.** Un tag supprimé peut rester référencé par les
/// `tagIds` de cartes ; [orphanTagIds] détecte ce sous-ensemble orphelin. La
/// **purge** (retirer l'`id` des `tagIds` de toutes les cartes) est le
/// travail du repository — hors périmètre de ce kernel (aucun widget, aucun
/// repository ici).
///
/// La primitive prend des clés `String` neutres (mêmes clés opaques que
/// `ZSessionCandidate.tagIds`). Elle n'importe aucun symbole d'un satellite
/// — le kernel ne dépend d'aucun satellite (invariant AD-1). L'appelant
/// agrège lui-même `referencedTagIds` (ex. les `tagIds` de ses cartes) et
/// `existingTagIds` (ex. les identifiants des tags vivants).
library;

/// Sous-ensemble des [referencedTagIds] qui ne correspondent à **aucun** tag
/// de [existingTagIds] — les références orphelines.
///
/// Pure, totale, déterministe, ne lève **jamais** (invariant AD-10). Ordre
/// d'entrée préservé (l'itérable retourné est un `LinkedHashSet`) et
/// dédoublonné.
///
/// - [referencedTagIds] vide → `{}` ;
/// - [existingTagIds] vide → tous les référencés sont orphelins ;
/// - doublons dans [referencedTagIds] → une seule occurrence dans le
///   résultat ;
/// - `''` est traité comme n'importe quelle clé opaque (orphelin s'il
///   n'existe pas dans [existingTagIds]).
Set<String> orphanTagIds({
  required Iterable<String> referencedTagIds,
  required Iterable<String> existingTagIds,
}) {
  final existing = existingTagIds.toSet();
  final orphans = <String>{}; // LinkedHashSet : ordre d'insertion préservé.
  for (final id in referencedTagIds) {
    if (!existing.contains(id)) orphans.add(id);
  }
  return orphans;
}
