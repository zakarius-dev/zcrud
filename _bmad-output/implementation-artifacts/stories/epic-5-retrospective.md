# Rétrospective — Epic E5 : Backend Firestore & offline-first (`zcrud_firestore` + ports sync `zcrud_core`)

- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill` ; `SKILL.md` chargé, workflow exécuté par l'orchestrateur en mode non-interactif — dialogue party-mode transposé en artefact écrit).
- **Date** : 2026-07-10
- **Statut epic** : **COMPLET** — E5-1, E5-2, E5-3, E5-4 tous `done`.
- **Couvre** : FR-12, FR-13 · **AD-5** (isolation backend), **AD-9** (offline-first LWW), **AD-11** (Either / Stream nu / ZFailure).
- **Dépendants** : E7 (intégration DODLP), **E9** (données d'étude / flashcards offline-first — consommateur réel de E5-3/E5-4).

> **Note d'historique** : la slice MVP (E5-1 + E5-2 = repo Firestore + `ZLocalStore`/`ZRemoteStore`) a été livrée en premier ; E5-3 (merge LWW + soft-delete + `ZSyncMeta`) et E5-4 (`ZSyncOrchestrator`) étaient planifiés **v1.x** et livrés dans un lot ultérieur (epic rouvert). Cette rétro consolide **les quatre** stories.

---

## 1. Livré

### E5-1 — `FirebaseZRepositoryImpl<T>` + traduction `ZDataRequest → Query`
Adaptateur Firestore réel du **port neutre** `ZRepository<T>` (gelé en E2-2) :
- `withConverter<T>` pour la relecture de `save` ; lectures liste/flux en `Map` brute + `_decode` défensif (AD-10).
- Traduction `ZDataRequest → Query` par **chaînage immuable réaffecté** (`q = q.where/orderBy/limit/startAfter`) — corrige le bug historique #1 des 3 apps (clause perdue par non-réassignation), mapping exhaustif des `ZFilterOp`, tri, `limit`, curseur `startAfter` (AD-16).
- Soft-delete / restore **hors-entité** (`ZSyncMeta`, `is_deleted`/`updated_at` ISO-8601), `count`, streams **nus** `Stream<List<T>>`.
- Enveloppe d'erreurs unique `_guard` (`FirebaseException → ServerFailure`, `null ≠ erreur → NotFoundFailure`) — **zéro** `catch(_){}` (corrige bugs historiques #3/#4).
- **Isolation Firebase prouvée** (AD-5) : aucun des 6 types `cloud_firestore` interdits (Query/CollectionReference/DocumentSnapshot/Timestamp/Filter/FirebaseException) en signature publique.

### E5-2 — Ports `ZLocalStore` / `ZRemoteStore` + adaptateurs Hive / Firestore
- Création des deux **ports neutres** dans `zcrud_core` (Dart pur, `dartz show Unit` uniquement) — E2-2 les avait différés à E5.
- `HiveZLocalStore` : store local **source de vérité** (JSON sur disque réel, box par kind sans TypeAdapter), `_isVisible` cohérent get/getAll/watch, décodage défensif AD-10, soft-delete hors-entité (jamais `box.delete`), invariant clé↔corps `id`, `_guard → CacheFailure`.
- `FirestoreZRemoteStore` : store distant **fire-and-forget** par **composition** (pas héritage, AD-4) sur E5-1 ; n'importe même pas `cloud_firestore`.
- Abstraction permettant Isar/Drift ultérieur (déféré). CORE OUT=0 maintenu.

### E5-3 — Patron offline-first LWW + soft-delete + `ZSyncMeta`
- `ZOfflineFirstRepository` : store local source de vérité, distant **fire-and-forget**, merge **Last-Write-Wins sur `updatedAt`** (`ZLwwResolver` déterministe), `applyMerged` écrit la méta **verbatim** (anti-ping-pong prouvé), cascade bornée `kMaxBatchWrites=450` **locale à `zcrud_firestore`** (jamais dans le cœur).
- Contrats sync purs dans `zcrud_core` (`z_offline_first_repository` façade + `z_sync_entry`, `z_lww_resolver`, `z_syncable_repository`) — Dart pur, isolation AD-5 re-vérifiée.

### E5-4 — `ZSyncOrchestrator`
- Orchestrateur pur-Dart `zcrud_core` : registre de `ZSyncableRepository`, **débounce trailing** avec coalescence N→1, **échec partiel** (un dépôt échoue → les autres continuent, tracé, jamais d'arrêt global, AD-9), **best-effort** (`syncNow()` renvoie toujours `Right(ZSyncRunReport)`), gate `enabled`, `dispose()` idempotent (ne dispose PAS les dépôts).
- Testabilité sans `Timer` réel (`ZSyncTimerFactory` + `flushPending()` awaitable) ; couture `isConnected` = point d'injection réseau.
- Contrainte « pubspec gelé + `domain_purity` » → `foundation`/`meta` bannis : `@visibleForTesting`/`@immutable`/`listEquals` remplacés par docstrings + `_listEquals` maison (équivalent admis AC2, vérifié correct).

**Vérif verte finale (rejouée sur disque)** : `dart analyze` core & firestore RC=0 · `flutter test` core **606** / firestore **74** · `graph_proof` **CORE OUT=0 / ACYCLIQUE** · 14 packages.

---

## 2. Ce qui a bien marché

1. **Apprentissage adversarial cumulatif d'une story à l'autre.** E5-1 a révélé le piège « le fake masque la sémantique prod » (seeding `_seedRaw` injectant toujours `id`/`is_deleted`). E5-2 a explicitement adopté ce mode (« learning E5-1 »), utilisé Hive **sur disque réel** et repéré le même défaut de cycle de vie de flux — **corrigé en parité sur les deux adaptateurs** plutôt qu'en silo. La revue a fait progresser la qualité de façon composée.
2. **Isolation backend AD-5 tenue de bout en bout.** Les 6 types Firestore interdits absents de toute signature publique, `CORE OUT=0` prouvé par `graph_proof` à chaque story, `zcrud_core` reste Dart pur même pour la façade offline-first et l'orchestrateur. E5-1 a ajouté un **test de signature de barrel** (anti-régression future).
3. **Correction des bugs historiques des 3 apps, prouvée par test.** Réassignation `limit`/clauses (#1), batch cohérents (#2), plus de `catch(_){}` (#3), `null ≠ erreur` (#4) — tous couverts. C'était l'objectif nommé de l'epic (« adaptateur Firestore débogué »).
4. **Désérialisation défensive AD-10 exercée sur cas réels** (JSON tronqué, types incorrects, N-1 sans throw + logs) — E5-1, E5-2, E5-3.
5. **Édition strictement additive en E5-4** (2 src + 2 tests + 2 exports), zéro régression sur les contrats E5-1/2/3.
6. **La revue, pas la vérif verte, a attrapé le risque de perte de données prod** — validation du cycle BMAD adversarial (les 2 MAJEUR d'E5-1 et le MAJEUR-1 d'E5-3 passaient tous les tests verts).

---

## 3. Points de friction

1. **Reprise après plantage d'agent en E5-1** (« finie via REPRISE après plantage — vigilance raccourcis »). C'est dans ce contexte que le raccourci `orderBy('id')` (MAJEUR-1) a été introduit : troquer une incompatibilité *fake* contre un **risque de perte de données silencieuse en prod**. Illustre le risque de surveillance des sous-agents (CLAUDE.md).
2. **Le fake (`fake_cloud_firestore`) ne réplique pas la sémantique prod.** `orderBy(field)` / `where(field==x)` **excluent** les docs sans le champ en prod ; le fake non. Deux MAJEUR en E5-1 (docs sans `id` / sans `is_deleted` invisibles), masqués par le seeding. Voie (a) `FieldPath.documentId` **prouvée infaisable** sur le fake → repli voie (b) invariant « collection zcrud-native » exécutoire + dette de migration legacy renvoyée à E7.
3. **`fire-and-forget` mal implémenté en E5-3 (MAJEUR-1).** `save`/`softDelete`/`restore` **awaitaient** la propagation distante → en hors-ligne « propre » (timeout 30-60 s), l'appelant bloquait le temps du timeout, exactement la latence que AD-9 promet d'éviter. **Le test ne l'attrapait pas** (`_ThrowingFirestore.collection()` throw *synchrone* → échec instantané, indistinguable awaited/non-awaited). Corrigé par `unawaited(...)` + retour immédiat + **test de non-blocance** (`_SlowRemote` derrière un `Completer`).
4. **Assimilation `ServerFailure` distant → « offline » → `Right(unit)`** (E5-3 MEDIUM-2, ré-apparue en E5-4 AC10). Toute erreur distante (permission-denied, quota, misconfig) traitée comme déconnexion → `sync()` **rapporte un succès sans jamais converger**. Choix AD-9/Ambiguïté #4 assumé mais masquant une vraie panne serveur. Atténué en E5-3 (log renforcé ⚠️ + dette E5-4) ; en E5-4 le `Left(ServerFailure)` est désormais **compté `failed` + collecté**, jamais noyé — mais la **distinction fine réseau/serveur reste une dette ouverte**.
5. **Couture app qui `throw` non protégée** (E5-4 MEDIUM-1). `await isConnected()` hors try/catch → sur la voie débouncée (`unawaited`), un throw = **unhandled asynchronous error** (crash debug Flutter), violant « aucune exception ne s'échappe ». Corrigé (try/catch + `_safeLog` pour un logger défaillant + 2 tests).
6. **Contrainte « pubspec gelé + `domain_purity` »** a forcé le retrait de `@visibleForTesting`/`@immutable`/`listEquals` en E5-4 → perte d'enforcement analyseur (membres test-only publics gardés par docstring seule).

---

## 4. Findings récurrents (patterns transverses)

| Pattern | Stories | Nature |
|---|---|---|
| **Le fake masque la sémantique prod** | E5-1 (2 MAJEUR), E5-2 (MEDIUM-2 réouverture box), E5-3 (LOW-2 fire-and-forget synchrone) | Trou de fidélité test → risque prod invisible |
| **Cycle de vie de flux non borné** (`StreamController`/`subscription` libérés au seul `dispose()`, pas à l'annulation) | E5-1 & E5-2 (corrigé en **parité**) | Fuite mémoire sur store long-vécu |
| **`ServerFailure` distant = offline** (masque permission/quota/misconfig) | E5-3 (MEDIUM-2) → E5-4 (AC10) | Dette réseau/serveur non résolue |
| **`put`/`save` ressuscite une entité soft-deletée** (`_encode` réécrit `is_deleted=false`) | E5-1 (LOW-4), E5-2 (LOW-3) | Documenté, cohérent, LWW = E5-3 |
| **Couture/callback app qui throw échappe au best-effort** | E5-2 (LOW-1 listener), E5-4 (MEDIUM-1 `isConnected`/logger) | Robustesse best-effort |

**Bilan findings** : E5-1 = 2 MAJEUR + 2 MEDIUM + 5 LOW (tous traités) · E5-2 = 2 MEDIUM + 3 LOW · E5-3 = 1 MAJEUR + 2 MEDIUM + 3 LOW · E5-4 = 1 MEDIUM + 2 LOW. **Zéro HIGH/MAJEUR/MEDIUM ouvert à la clôture.**

---

## 5. Suivi de la rétro précédente (E4)

Le mode adversarial de E4 (« le rendu Syncfusion peut masquer un contrat ») a été **appliqué et généralisé** en E5 sous la forme « le fake backend masque la prod » — la vigilance a directement produit la détection des 2 MAJEUR d'E5-1 et le choix Hive-sur-disque-réel d'E5-2. Continuité de discipline confirmée.

---

## 6. Action items

| # | Action | Catégorie | Owner | Statut |
|---|---|---|---|---|
| A1 | **Distinguer « réseau injoignable » vs « erreur serveur applicative »** (permission/quota/misconfig ne doivent PAS être avalés en `Right(unit)`) — typer la connectivité et remonter les erreurs applicatives au lieu de les assimiler à offline. | technique / AD-9 | E9-4 / évolution `ZSyncOrchestrator` | open |
| A2 | **Traduction requête → cache local** : `watch(request)`/`getAll({request})`/`count({request})` de `ZOfflineFirstRepository` **droppent** filtres/tri/pagination (loggé, pas silencieux). Implémenter le filtrage local (ou étendre `ZLocalStore`) pour le consommateur E9. | technique | E9 | open |
| A3 | **Garde de ré-entrance de cycle** dans `ZSyncOrchestrator` (flag `_running` coalesçant/ignorant un cycle si un est en vol) — éviter le double `repo.sync()` parallèle qui martèle le backend et fausse les rapports concurrents. | technique | E9-4 (si martèlement réel) | open |
| A4 | **Migration/backfill des collections legacy** (docs sans corps `id` / sans `is_deleted`) : l'invariant « collection zcrud-native » est exécutoire mais les collections DODLP existantes doivent être backfillées avant branchement. | technique / onboarding | E7 | open |
| A5 | **Harnais de fidélité fake→prod** : systématiser un test « réouverture / doc à champ absent / latence asynchrone » sur tout nouvel adaptateur backend, pour ne plus laisser le fake masquer la sémantique prod. | process / test | tout adaptateur v1.x | open |

---

## 7. Leçons pour les epics v1.x restantes (E9, E10, E11b)

1. **E9 (flashcards offline-first) hérite de deux dettes explicitement tracées** : A1 (distinction réseau/serveur) et A2 (traduction requête→cache local). E9-4 est le **consommateur réel** du patron E5-3/E5-4 — c'est là que ces dettes se paient ou explosent. Prévoir l'invariant SRS top-level séparé de la carte (canonique §2.7, AD-9) dès la conception du dépôt.
2. **Ne jamais laisser un fake dicter un choix prod** (leçon MAJEUR-1 E5-1). Quand un backend de test refuse une API sûre en prod (`FieldPath.documentId`), rendre l'**invariant exécutoire** + le tester avec un cas *négatif* (doc à champ absent, latence asynchrone) plutôt que d'adopter le raccourci que le fake tolère. Généraliser via A5.
3. **`fire-and-forget` = tester la non-blocance, pas seulement le résultat** (leçon E5-3). Un échec *synchrone* ne prouve pas l'asynchronicité ; injecter une latence (`Completer`/`Future.delayed`) et asserter que l'appelant rend la main avant. Applicable à toute écriture best-effort de E9/E10.
4. **Toute couture injectée par l'app (connectivité, logger, storage) doit être supposée capable de `throw`** — l'envelopper (voie await ET voie fire-and-forget/`unawaited`), sinon unhandled async error. Vaut pour les embeds E10 (mindmap) et les providers géo/intl E11b.
5. **Vigilance sous-agents** (CLAUDE.md) : le raccourci E5-1 est né d'une reprise après plantage d'agent. Rejouer la vérif verte réelle + relire les diffs de reprise avec suspicion accrue ; ne jamais faire confiance au `review`/`done` d'un agent mort.
6. **Contrainte pubspec gelé / `domain_purity`** : anticiper que `foundation`/`meta` restent bannis du cœur ; prévoir les équivalents maison (`_listEquals`, docstrings) dès la conception plutôt qu'en remédiation.

---

## 8. Synthèse

Epic E5 **complet et vert**, objectif « adaptateur Firestore débogué + patron offline-first standardisé » atteint : bugs historiques des 3 apps corrigés et testés, isolation AD-5 tenue (CORE OUT=0), merge LWW anti-ping-pong, orchestrateur best-effort à échec partiel. Le fil rouge des frictions — **le fake masque la sémantique prod** et **la frontière réseau/serveur reste floue** — a été maîtrisé par correction mais laisse **deux dettes tracées vers E9** (A1, A2) et une vers E7 (A4). La discipline adversariale cumulative story-à-story et les corrections en **parité cross-adaptateur** sont les acquis les plus réutilisables pour la suite v1.x.

---

## 9. Transition de statut

- `epic-5-retrospective` : `done` (édition ciblée du sprint-status par l'orchestrateur — **non modifié par cette rétro**, conformément aux contraintes dures).
- Action items A1..A5 à consigner dans la section `action_items` du sprint-status par l'orchestrateur.
