# Changelog

All notable changes to `zcrud_firestore` are documented in this file.

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
