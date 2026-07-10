# Rétrospective — Epic E5 : Backend Firestore & offline-first (`zcrud_firestore`)

- **Skill** : `bmad-retrospective` (invoqué via tool `Skill` ; SKILL.md chargé + workflow exécuté).
- **Date** : 2026-07-10
- **Périmètre** : slice MVP de E5 = **e5-1** + **e5-2** (`done`). e5-3 (merge LWW soft-delete) et e5-4 (`ZSyncOrchestrator`) = **backlog v1.x** (différés hors MVP 0.1.0).
- **Prochaine étape MVP** : **E6 — Markdown & rich text** (`zcrud_markdown`).

---

## 1. Livré (slice MVP)

### e5-1 — `FirebaseZRepositoryImpl<T>` + traduction `ZDataRequest → Query`
Adaptateur Firestore réel du **port neutre** `ZRepository<T>` (gelé en E2-2) :
- `withConverter<T>` round-trip pour `save` ; lectures liste/flux en `Map` brute + `_decode` défensif.
- Traduction `ZDataRequest → Query` par **chaînage immuable réaffecté** (corrige le bug historique #1 des 3 apps — clause perdue), mapping exhaustif des `ZFilterOp`, tri, `limit`, curseur `startAfter` (AD-16).
- Soft-delete / restore **hors-entité** (`ZSyncMeta`, `is_deleted`/`updated_at` ISO-8601), `count` via agrégation, streams **nus** `Stream<List<T>>`.
- Enveloppe d'erreurs unique `_guard` (`FirebaseException → ServerFailure`, `null ≠ erreur → NotFoundFailure`) — **zéro** `catch(_){}` (corrige bugs historiques #3/#4).
- **Isolation Firebase prouvée** (AD-5) : aucun des 6 types `cloud_firestore` interdits en signature publique.

### e5-2 — Ports `ZLocalStore` / `ZRemoteStore` + adaptateurs Hive/Firestore
- **Création des deux ports neutres** dans `zcrud_core` (Dart pur, `import dartz show Unit` uniquement) — E2-2 les avait explicitement différés à E5 (hypothèse d'entrée corrigée par vérification disque).
- `HiveZLocalStore<T>` : store local **source de vérité** offline-first, stockage JSON (box par kind, sans TypeAdapter), décodage défensif AD-10, soft-delete par drapeau (jamais `box.delete`), invariant clé↔corps `id`, `_isVisible` cohérent get/getAll/watch, `_guard → CacheFailure`.
- `FirestoreZRemoteStore<T>` : store distant **fire-and-forget** par **composition** (pas héritage, AD-4) sur `FirebaseZRepositoryImpl<T>` d'e5-1 ; n'importe même pas `cloud_firestore`.

### Capacités acquises
Un agrégat zcrud peut être **persisté sur Cloud Firestore** et **caché en local (Hive)** avec la **même sémantique de clé et de soft-delete** des deux côtés — les deux moitiés de l'offline-first existent (la SYNC entre elles reste v1.x).

### Métriques réelles (rejouées sur disque)
| Contrôle | Résultat |
|---|---|
| Tests `zcrud_firestore` | **58** OK (0 échec) |
| Tests `zcrud_core` | **562** OK (aucune régression) |
| `melos run analyze` | **RC=0** (14 packages, 0 issue) |
| `melos run verify` | **RC=0** (gate:melos / reflectable / secrets / codegen / compat / verify:serialization) |
| Graphe de dépendances | ACYCLIQUE OK · **CORE OUT=0 OK** |
| `melos list` | **14** packages |

---

## 2. Ce qui a bien marché

- **Isolation AD-5 prouvée, pas seulement affirmée.** 0 fuite de type backend (`Query`/`Timestamp`/`Filter`/`DocumentSnapshot`/`CollectionReference`/`FirebaseException`) en signature publique, ports Dart pur, `CORE OUT=0` re-vérifié. e5-2 a même ajouté un test de signature au niveau package (absorbe le MEDIUM-2 d'e5-1).
- **Défensif AD-10 exercé sur des cas RÉELS** — pas un seed propre. e5-2 sème 3 entrées corrompues réelles (JSON tronqué, type non-String, `count` mal typé) parmi 2 valides → N-1 conservés sans throw, logs non vides. Hive **sur disque réel** (`Hive.init(tmpdir)` + `jsonEncode/Decode`) : la sérialisation prod est vraiment traversée.
- **Réutilisation, pas réinvention.** e5-2 délègue au traducteur Firestore d'e5-1 (composition) au lieu d'un second traducteur — moins de surface, invariants partagés.
- **Revue adversariale efficace.** Elle a démasqué des raccourcis que la vérif verte laissait passer (voir §3). C'est la revue, pas les tests verts, qui a attrapé le risque de perte de données prod.

---

## 3. Incidents & leçons (cœur de la rétro)

### (a) Plantage de l'agent dev-story e5-1 (API error) → reprise sur état disque
L'agent dev-story d'e5-1 a **planté** (API error) en laissant un travail partiel **non fini et bugué** (`_typedCollection` non câblé → `unused_element` bloquant). La reprise s'est faite sur l'**état réel vérifié sur disque** (analyze/tests rejoués), **jamais** sur le rapport de l'agent mort.
**Leçon** : ne jamais enchaîner sur la foi d'un `review`/`done` laissé par un agent planté ; confirmer l'état git/analyze/tests d'abord. (Conforme à la consigne « surveillance des sous-agents ».)

### (b) Raccourcis de reprise démasqués par la revue — 2 MAJEUR (perte de données silencieuse en prod)
La revue e5-1 a trouvé **2 MAJEUR** que le harnais de test masquait :
- **MAJEUR-1** : tie-break `orderBy('id')` sur un champ de **corps** → en prod, tout document sans champ `id` (données héritées, docs hors zcrud, migrés) **disparaît silencieusement** de toute requête triée/paginée. Masqué par `_seedRaw` qui injecte toujours `id`.
- **MAJEUR-2** : filtre serveur `where('is_deleted', isEqualTo: false)` → un doc **sans** le champ est exclu au serveur, alors que le filtre applicatif le gardait → **divergence get vs getAll/watch** pour le même doc. Masqué par un seed écrivant toujours `is_deleted`.

Correctifs : invariant « collection zcrud-native » rendu **exécutoire** (`save`/`_encode` écrivent toujours `id == doc.id`) + dartdoc fort ; `_isVisible` unifié et cohérent sur les 3 chemins ; migration des collections legacy **actée pour E7**.
**Leçon centrale** : **le fake / le Hive-en-mémoire ne prouvent pas la sémantique prod.** Un seed « propre » garantit toujours des données bien formées et cache les vrais cas limites. Il faut tester l'entrée corrompue, le champ absent, le close→reopen **RÉELS**.

### (c) Défaut de fuite `watchAll` sans `onCancel` — présent en e5-1 ET e5-2 (parité)
La revue e5-2 (MEDIUM-1) a trouvé qu'un `StreamController` sans `onCancel` ne libère abonnement + contrôleur qu'au `dispose()` → **croissance non bornée** sur un store singleton ré-abonné à chaque build. Le **même défaut existait en e5-1** (déjà passé en revue). Corrigé **des deux côtés** (parité) avec tests anti-fuite (`activeSourceSubscriptions`/`activeStreamControllers → 0` après cancel ; 5 cycles → 0).
**Leçon** : un défaut trouvé dans un adaptateur doit être cherché **par parité** dans les adaptateurs jumeaux, même déjà « done ».

### Bilan findings
| Story | HIGH/MAJEUR | MEDIUM | LOW | Statut final |
|---|---|---|---|---|
| e5-1 | 2 corrigés (+ tests) | 2 corrigés | 5 traités | done |
| e5-2 | 0 | 2 corrigés (dont parité e5-1) | 3 traités | done |

---

## 4. Action items portés en avant (E6 et v1.x)

| ID | Libellé | Portée |
|---|---|---|
| **AI-E5-1** | Invariant zcrud-native (`id` et `is_deleted` **toujours** écrits en corps) à **revalider lors de la migration réelle E7** ; prévoir backfill/onboarding des collections DODLP legacy (le fake ne prouve pas l'exclusion prod des docs à champ absent). | E7 |
| **AI-E5-2** | **e5-3 (merge LWW `updatedAt`, cascade ≤450, soft-delete standardisé) + e5-4 (`ZSyncOrchestrator`, débounce ~400 ms)** à implémenter en **v1.x** — pré-requis d'un offline-first COMPLET (les stores existent, la sync non). | v1.x |
| **AI-E5-3** | **Pattern de test non-négociable** : toujours exercer entrée **corrompue** / champ **absent** / **close→reopen**, jamais seulement le happy-path seedé. À appliquer dès E6 (codecs Markdown/ZCodec : entrée Delta/Markdown corrompue). | E6+ (tous) |
| **AI-E5-4** | Chercher **par parité** tout défaut de cycle de vie de flux (`onCancel`) dans les futurs adaptateurs à streams (E4 liste, E6). | E6+ |

---

## 5. Dette v1.x explicite

L'**offline-first n'est PAS complet.** e5-1 + e5-2 livrent les **deux moitiés** (local source de vérité + distant fire-and-forget) mais **aucune sync entre elles** :

- **e5-3** (`backlog`, v1.x) : merge **Last-Write-Wins** sur `updatedAt`, cascade bornée **≤ 450** écritures/lot, soft-delete `is_deleted` **standardisé** composé.
- **e5-4** (`backlog`, v1.x) : `ZSyncOrchestrator` (débounce ~400 ms, best-effort silencieux, `Right(unit)` si déconnecté, échec partiel toléré) — sépare le « quand » du « comment ».

Tant que e5-3/e5-4 ne sont pas livrés, un consommateur ne doit **pas** supposer une réconciliation local↔distant automatique. Consommateur cible de la voie complète = donnée d'étude (E9). Décision MVP confirmée : différer est correct — E7 (DODLP) et E8 (lex_douane) n'ont besoin que du repo Firestore + du store local, déjà livrés.

---

## 6. Préparation E6 (Markdown & rich text)

- **Aucune dépendance bloquante** de E6 sur la dette e5-3/e5-4 : E6 (`zcrud_markdown` : Quill + `ZCodec` + embeds LaTeX/tables) est un package satellite indépendant du backend.
- **Portage direct des learnings** : `ZCodec` pluggable (Delta/Markdown/HTML) doit appliquer **AI-E5-3** dès sa conception — décodage défensif sur Delta/Markdown corrompu ou tronqué (ne jamais casser sur un document mal formé), champ rich-text à controller isolé conforme AD-2.
- Pas de découverte E5 invalidant le plan E6.

---

## 7. Transition de statut

- `epic-5-retrospective` : `optional` → **done** (édition ciblée du sprint-status par l'orchestrateur — non modifié par cette rétro).
- Action items AI-E5-1..4 à consigner dans la section `action_items` du sprint-status par l'orchestrateur.
