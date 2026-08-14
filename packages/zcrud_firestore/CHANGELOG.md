# Changelog

All notable changes to `zcrud_firestore` are documented in this file.

## 0.97.0 — 2026-08-14

### Corrigé

#### La limite de recherche de Firestore n'est plus seulement documentée

`FirebaseZRepositoryImpl` ne sert pas `ZDataRequest.search` (Firestore n'a ni
`LIKE`, ni plein-texte, ni pliage diacritique) : la limite était consignée dans
la documentation, et les listings assemblés au-dessus offraient malgré tout une
barre de recherche inerte.

L'adaptateur applique désormais le mixin `ZDelegatesSearch` de `zcrud_core` :
il **déclare** qu'il délègue la recherche. Un listing du socle filtre alors le
terme saisi par son propre moteur, le temps de la recherche — au prix d'une
lecture non paginée de la collection, et de rien du tout tant qu'aucun terme
n'est saisi. `ZOfflineFirstRepository` et `ZOfflineFirstBoxRepository`, qui
rendent le snapshot local complet sans traduire la requête, le déclarent
également ; le jeu y étant déjà lu en entier, cette voie n'y coûte aucune
lecture de plus.

Aucune signature ne change, et aucune implémentation hôte du port n'est
touchée : la capacité est un mixin, pas un membre de `ZRepository`.

Sur un gros parc, la voie recommandée reste inchangée : un champ de recherche
normalisé pré-calculé, interrogeable par égalité ou par préfixe.

## 0.91.0 — 2026-08-12

### Ajouté

- `FirebaseZRepositoryImpl` (et sa fabrique `fromRegistry`) accepte un nouveau
  paramètre `omitNullFields` (défaut `false` — comportement actuel inchangé,
  les clés nulles restent écrites). À `true`, les clés à `null` sont retirées
  **récursivement** du corps de l'entité avant chaque écriture (`save`,
  `writeMerged`, `applyMergedAll`) — l'équivalent du `compact(true)` des
  moteurs legacy. Les métadonnées de synchronisation (`updated_at`,
  `is_deleted`) ne sont jamais retirées, y compris un `updated_at` verbatim
  `null` sur la voie de merge. Pourquoi : en écriture fusionnée Firestore
  (`merge: true`), une clé **absente** laisse la valeur distante intacte,
  mais une clé présente à **`null` l'efface** — un parc co-écrit en fusion
  doit garantir qu'aucune clé nulle n'atteint le disque.

## 0.1.0

Initial public release.

- Firestore and Hive adapters for zcrud repositories.
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
