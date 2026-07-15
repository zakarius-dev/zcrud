/// Intégrité référentielle des tags — primitive PURE de **détection** des
/// références orphelines (ES-2.3, FR-S6, AC5 — décision D5).
///
/// **Détection, PAS purge.** Un tag supprimé peut rester référencé par les
/// `tagIds` de cartes ; [orphanTagIds] **détecte** ce sous-ensemble orphelin.
/// La **purge** (retirer l'`id` des `tagIds` de toutes les cartes) est le travail
/// du **repository** (`StudyTagsRepository.deleteTag` chez lex) — **ES-8.1 / ES-3,
/// hors périmètre** de cette story (aucun widget, aucun repository ici).
///
/// **Découplage AD-1/AD-17** : la primitive prend des clés `String` **neutres**
/// (mêmes clés opaques que `ZSessionCandidate.tagIds`, leçon L2 d'ES-2.1). Elle
/// n'importe **AUCUN** symbole de `zcrud_flashcard` — le kernel ne dépend d'aucun
/// satellite. L'appelant agrège lui-même `referencedTagIds` (ex. les `tagIds` de
/// ses `ZFlashcard`) et `existingTagIds` (ex. les `ZFlashcardTag.id` vivants).
library;

/// Sous-ensemble des [referencedTagIds] qui ne correspondent à **AUCUN** tag de
/// [existingTagIds] — les **références orphelines**.
///
/// PURE · TOTALE · déterministe · ne throw **JAMAIS** (AD-10). Ordre d'entrée
/// **préservé** (l'itérable retourné est un `LinkedHashSet`) et **dédoublonné**.
///
/// - [referencedTagIds] vide → `{}` ;
/// - [existingTagIds] vide → **tous** les référencés sont orphelins ;
/// - doublons dans [referencedTagIds] → une seule occurrence dans le résultat ;
/// - `''` est traité comme n'importe quelle clé opaque (orphelin s'il n'existe
///   pas dans [existingTagIds]).
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
