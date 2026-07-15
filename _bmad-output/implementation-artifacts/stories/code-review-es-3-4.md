# Code Review — Story ES-3.4 : Orchestrateur de synchronisation paramétré (liste injectée)

- **Skill** : `bmad-code-review` (invoqué via le tool Skill — PAS de fallback disque).
- **Mode** : full (spec = `es-3-4-orchestrateur-sync-parametre.md`, `baseline_commit: 8c0cf418`).
- **Runners** : `flutter test` pour `zcrud_core` ET `zcrud_firestore` (gotcha runner respecté) ; `graph_proof.py`.
- **Verdict** : ✅ **APPROVED** — 0 HIGH, 0 MAJEUR, 0 MEDIUM. 2 LOW (nits, non bloquants).

---

## Vérif verte réelle (rejouée sur disque, bon runner)

| Vérif | Commande | Résultat |
|-------|----------|----------|
| Test firestore | `flutter test test/z_study_sync_orchestrator_test.dart` | **RC=0 · 11 passed** |
| Test core (orchestrateur) | `flutter test test/domain/sync/z_sync_orchestrator_test.dart` | **RC=0 · 26 passed** (dont group `registerAll (ES-3.4)`) |
| Analyze périmètre | `dart analyze packages/zcrud_core packages/zcrud_firestore` | **No issues found** |
| Graph proof | `graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK · 34 arêtes (INCHANGÉ)** |
| Diff core vs baseline | `git diff --stat` | **1 file, +17, -0** (purement additif, orchestrateur seul) |

---

## Additivité stricte du core (D1) — VÉRIFIÉE

`git diff 8c0cf418 -- z_sync_orchestrator.dart` = **+17 insertions, 0 suppression**. Le seul ajout est `registerAll(Iterable<ZSyncableRepository<dynamic>>)` (l.198-203) : garde `if (_disposed) return;` puis boucle `register(repo)`. Constructeur, `register`/`unregister`, `_schedule`, `_runCycle`, `dispose` **octet-pour-octet inchangés** (relus l.160-372). `registerAll` **compose** `register` → hérite l'idempotence par identité (Set) et le no-op après dispose. Aucune 2e voie d'injection, aucun état ajouté. Pur-Dart (aucun import). **Conforme.**

## Pouvoir discriminant (R12) — RE-PROUVÉ par injection réelle

Injection **R3-a** rejouée réellement (`registerAll` boucle → `register(repos.first)`) :
- firestore AC2 `Expected: <3> / Actual: <1>` ; AC3 `Expected: <4> / Actual: <1>` ; AC4 `okB.syncCalls Expected: <1> / Actual: <0>`.
- ⇒ la garde d'itération « aucun repo oublié » est **LOAD-BEARING** (pas un test POWERLESS).
- **Restaurée par édition ciblée** (JAMAIS `git checkout`) → `git diff` core re-montre **+17 uniquement** ; suite firestore **11/11 verte** après restauration.

Les autres gardes sont couvertes par des injections annotées R3-b/c/d dans les tests, et vérifiées structurellement sur le code composé (E5-4) :
- **R3-b best-effort** : `_runCycle` (l.328-349) isole **chaque** `repo.sync()` (`try/catch` + `fold` du `Left`), incrémente `failed`, loggue (AD-11, jamais `catch(_){}` muet), **ne rethrow jamais**, poursuit la boucle. `syncNow` renvoie toujours `Right(report)` (l.260-263). Test AC4 `[okA, boom, okB]` → `okA/okB.syncCalls==1`, `Right`, `failed>=1`. Discriminant.
- **R3-c débounce** : `_schedule` (l.235-244) `_cancelPending()` + réarme ; test AC5 vérifie `created[0/1].isCancelled==true`, `[2]==false`, `syncCalls==1` (pas N), `duration==D` / défaut 400 ms. Fake clock, aucun `Timer` réel. Discriminant.
- **R3-d dispose non-propriétaire** : `dispose` (l.366-371) annule timer + `_repos.clear()`, **ne dispose PAS** les repos ; test AC7 `spy.disposed==false`, `registeredCount==0`, cycle ultérieur inerte, idempotent. Discriminant.

## Fabrique neutre (D2, AD-15/AD-11/AD-5) — VÉRIFIÉE

`z_study_sync_orchestrator.dart` : **seul import = `package:zcrud_core/zcrud_core.dart`** (garde statique disque AC3, imports == exactement cette ligne). Fonction sans état, corps = `ZSyncOrchestrator(...) → registerAll(repositories) → return`. Aucun repo concret importé/construit (garde disque : ni `repository_impl`, ni `ZOfflineFirstBoxRepository`, ni `ZOfflineFirstRepository`, ni `firebase_auth`/`connectivity_plus`/`riverpod`). Signature **NUE** : entrées = `Iterable<ZSyncableRepository<dynamic>>` + coutures cœur ; sortie = `ZSyncOrchestrator`. Liste **exclusivement injectée** (« ajouter un repo = passer une liste plus longue », prouvé par AC3 1-repo puis 4-repos). Login/reconnexion délégués à l'app. **Conforme.**

## AD-1/AD-17 / AD-4 — VÉRIFIÉES

Graphe **34 arêtes INCHANGÉ**, acyclique, `CORE OUT=0`. `registerAll` reste dans `zcrud_core` (out-degree 0) ; la fabrique vit dans `zcrud_firestore` qui dépend déjà de `zcrud_core` (aucune arête ajoutée). Compose E5-4 sans le ré-implémenter (AD-4).

## Couverture des 9 ACs — COMPLÈTE

AC1→group core `registerAll` (4 tests) · AC2→firestore AC2 · AC3→firestore AC3 (dynamique + garde disque) · AC4→firestore AC4 (throw + Left) · AC5→firestore AC5 (coalescence + fenêtre) · AC6→firestore AC6 (sync-void + throw) · AC7→firestore AC7 · AC8→firestore AC8 (+ garde imports AC3) · AC9→vérif verte ci-dessus. Chaque AC a un test à pouvoir discriminant réel.

---

## Findings

### LOW-1 — AC8 : la neutralité du *barrel* n'est prouvée qu'indirectement
`packages/zcrud_firestore/test/z_study_sync_orchestrator_test.dart:381-392`. Le test AC8 vérifie le **type de retour** (`ZSyncOrchestrator`) et la garde AC3 vérifie les **imports du fichier fabrique**, mais aucun test n'inspecte directement `zcrud_firestore.dart` pour affirmer que la ligne `export` n'introduit pas de type backend. En pratique la garantie tient structurellement (le fichier exporté n'importe que `zcrud_core`, donc ne peut rien réexporter de backend), donc **aucun défaut réel** — simple asymétrie de couverture. Correction optionnelle : une assertion disque sur le barrel (parité ES-3.2 AC11). Non bloquant.

### LOW-2 — `_runCycle` : une exception (throw) est comptée dans `failed` mais absente de `failures`
`packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart:340-348`. Le `on Object catch` incrémente `failed` et loggue, mais n'ajoute pas de `ZFailure` à `failures` (contrairement au chemin `Left`). Un consommateur lisant `report.failures` ne « voit » donc pas les dépôts ayant *levé* (seulement ceux ayant renvoyé `Left`). **Comportement pré-existant E5-4, HORS PÉRIMÈTRE additif ES-3.4** (le test AC4 throw n'assert que `failed>=1`, ce qui est correct). Consigné pour visibilité ; pas de correction dans cette story (ne pas modifier E5-4 — R9/D1).

---

## Conclusion
Story **verte**, additivité core stricte (+17, 0 suppression), fabrique neutre et sans état, best-effort/débounce/dispose non-propriétaire composés (non dupliqués), graphe inchangé. Les 4 gardes centrales sont LOAD-BEARING (R3-a re-prouvée rouge puis restaurée par édition ciblée). Aucun finding HIGH/MAJEUR/MEDIUM. **Prêt pour `done`.**
