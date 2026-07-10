---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 9.4 : Dépôt offline-first `ZFlashcard` + invariant SRS top-level (`zcrud_flashcard`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud (lex_douane « Étude », puis DODLP)**,
I want **un dépôt flashcard **offline-first** (`ZFlashcardRepository`) qui compose les **ports neutres** d'E5 (`ZSyncableRepository<ZFlashcard>` pour la carte) et un canal SRS **séparé** (`ZRepetitionStore` pour `ZRepetitionInfo`), matérialise l'éphémère (UUID + `folderId` + dates), refuse une carte éphémère sans dossier cible (`Left(DomainFailure)`), et fait progresser l'état SRS par l'**unique** voie `reviewCard() → ZSrsScheduler.apply` — l'état SRS étant persisté **top-level** (`study_repetitions/{cardId}`), **jamais** dans le sous-arbre partageable de la carte**,
so that **je puisse persister/synchroniser des flashcards zéro-perte et rétro-compatibles, préserver l'historique SRS d'autrui au partage/duplication (invariant canonique §2.7/§7, AD-9), et brancher plus tard un backend Firestore/Hive réel **sans** que `zcrud_flashcard` ne tire jamais Firebase (AD-1) et **sans** modifier `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

Quatrième story de l'**epic E9 — Flashcards (`zcrud_flashcard`)**, et **premier consommateur réel** du patron offline-first livré en **E5** (`ZOfflineFirstRepository`, `ZLocalStore`/`ZRemoteStore`, `ZSyncOrchestrator`, merge LWW). Elle pose la **couche `data/`** du package (aujourd'hui il n'y a que `domain/`).

E9-1 (done) a posé `ZFlashcard` (entité `ZEntity` codegen, portant déjà `folderId`/`subFolderId`, `createdAt`/`updatedAt`, **et AUCUN champ SRS**). E9-2 (done) a posé `ZRepetitionInfo` (contenant pur **SANS `id`/`ZEntity`**, clé de jointure `flashcardId`) + `ZSrsScheduler`/`ZSm2Scheduler`/`ZSrsConfig` (voie d'avancement pure `apply`/`initial`, **sans dépôt ni `reviewCard` branché**). E9-3 (done) a posé `ZStudyFolder`/`ZReviewMode`/`ZStudySessionConfig` + primitives pures de validation de hiérarchie et de sélection de session.

**Cette story branche enfin :** (1) la **persistance** offline-first des cartes via les **ports E5** ; (2) le `reviewCard()` **réel** (délègue à `apply`) écrivant l'état SRS dans un canal **séparé top-level** ; (3) la **matérialisation de l'éphémère** et la garde `folderId` obligatoire.

### Invariants d'architecture applicables

- **AD-9 (offline-first + état SRS séparé + voie d'écriture UNIQUE)** [Source: architecture.md#AD-9] : patron = **store local source de vérité** + **distant fire-and-forget** + merge **Last-Write-Wins sur `updatedAt`** + soft-delete `is_deleted` **hors-entité** (`ZSyncMeta`) + cascade bornée. **« L'état SRS (`ZRepetitionInfo`) est séparé de `ZFlashcard` ; seule voie d'écriture = `reviewCard() → ZSrsScheduler.apply` (aucun setter brut). »** Le *quand* (débounce multi-dépôts) reste le `ZSyncOrchestrator` (E5-4).
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `zcrud_flashcard` dépend de `zcrud_core` (+ `markdown`/`export`/`annotations`) et **réutilise ses ports**. **CONTRAINTE DURE : ne PAS faire dépendre `zcrud_flashcard` de `zcrud_firestore` / Firebase / Hive** (aucun `import 'package:cloud_firestore/…'`, `hive`, `firebase_core`). Le dépôt s'appuie **exclusivement** sur les **ports neutres** du cœur + le domaine flashcard. La concrétude backend est **injectée** (composition root). **CONTRAINTE DURE : ne PAS modifier `zcrud_core`** — tous les briques (`ZSyncableRepository`, `ZLocalStore`, `ZRemoteStore`, `ZSyncEntry`/`ZSyncMeta`, `ZLwwResolver`, `ZResult`, `DomainFailure`, `Unit`/`unit`) existent déjà.
- **AD-14 (matérialisation de l'éphémère)** [Source: architecture.md#AD-14 ; z_entity.dart] : l'entité n'attribue **jamais** d'`id` ; c'est le **repository/store** qui matérialise (attribution d'un `id` opaque à l'écriture, corps portant **toujours** son `id`). `isEphemeral == (id == null)`.
- **AD-10 (désérialisation défensive)** [Source: architecture.md#AD-10] : un état SRS absent/corrompu au chargement **ne fait jamais échouer** `reviewCard` — repli sur `ZSrsScheduler.initial()` (état neuf) ; `vide ≠ erreur`.
- **AD-5/AD-11 (backend-agnostique + `Either`/flux nus)** [Source: architecture.md#AD-5,#AD-11] : toutes les signatures publiques retournent `ZResult<T>` (`Either<ZFailure,T>`) / `ZResult<Unit>` / `Stream<List<T>>` **nus** ; **jamais** de `try-catch` nu ; aucun type `cloud_firestore`/`hive` dans une signature.

### Décision d'architecture (à valider — placement du dépôt & arêtes de dépendance)

> **Signalé à l'orchestrateur.** Choix retenu et **argumenté vs AD-1** — n'introduit **aucune** arête interdite, **aucune** édition de `zcrud_core`.

- **Placement (option (a) retenue) :** le dépôt `ZFlashcardRepository` vit **dans `zcrud_flashcard`** (`lib/src/data/`), bâti **uniquement** sur les **ports neutres** de `zcrud_core`. Il **ne réutilise pas par import** la classe concrète `ZOfflineFirstRepository<T>` (qui vit dans `zcrud_firestore`) : il en reçoit une instance **par injection** typée sur le port neutre `ZSyncableRepository<ZFlashcard>`. Ainsi `zcrud_flashcard → zcrud_core` reste la **seule** arête concernée (déjà existante) ; **aucune** arête `zcrud_flashcard → zcrud_firestore` n'est créée → `zcrud_flashcard` **ne tire jamais Firebase/Hive** (AD-1 respecté). Rejet de l'option « import direct de `ZOfflineFirstRepository` » qui tirerait `zcrud_firestore`+Firebase dans le graphe flashcard.
- **Friction structurelle à résoudre — `ZRepetitionInfo` n'est PAS un `ZEntity`** (clé `flashcardId`, sans `id`). Il **ne peut donc pas** transiter par `ZSyncableRepository<T extends ZEntity>` / `ZLocalStore<T>` / `ZRemoteStore<T>` **directement**. **Résolution retenue :** définir un **port flashcard-local** `ZRepetitionStore` (dans `zcrud_flashcard`, `lib/src/data/` ou `lib/src/domain/ports/`), adressé par `flashcardId`, dont la sémantique offline-first (local autoritaire + distant best-effort + LWW **via `ZSyncMeta` hors-entité**, car `ZRepetitionInfo` n'a pas de champ `updatedAt`) **mime** E5 mais reste **neutre**. Ce port est **dans le package flashcard, pas dans `zcrud_core`** → **aucune** édition du cœur. Alternative écartée (documentée) : promouvoir `ZRepetitionInfo` en `ZEntity` (changerait l'identité E9-2, plus invasif) ; ou emballer dans un `ZEntity` wrapper (code superflu).
- **Backend réel = DÉFÉRÉ / hors E9-4.** E9-4 livre le **coordinateur + le port `ZRepetitionStore` + des fakes/tests en mémoire** — testables **entièrement dans `zcrud_flashcard`**, sans Firebase. L'**adaptateur concret** offline-first de `ZRepetitionStore` (Hive/Firestore) et le câblage de `ZOfflineFirstRepository<ZFlashcard>` sont un **travail de composition root** (app / E7 / E9-5), OU un petit adaptateur ultérieur côté `zcrud_firestore`. **⚠️ Si une story ultérieure choisit d'implémenter cet adaptateur dans `zcrud_firestore`, cela crée une arête `zcrud_firestore → zcrud_flashcard`** (acyclique — flashcard ne dépend pas de firestore — mais rend firestore entité-spécifique) : **décision à valider à ce moment-là**, hors E9-4. E9-4 **ne requiert ni cette arête ni aucune autre**.

### Dettes héritées d'E5 (retro epic-5 — pertinentes pour E9-4)

- **A1 (réseau vs serveur)** [epic-5-retrospective.md#A1] : le patron E5 assimile un `Left(ServerFailure)` distant à « offline » → `Right(unit)`, masquant permission/quota/misconfig. E9-4 en **hérite** via les ports composés : **documenter** la dette (ne pas la « corriger » ici — c'est une évolution `ZSyncOrchestrator`/typage connectivité, hors flashcard). Ne rien ré-assimiler de neuf.
- **A2 (traduction requête→cache)** [epic-5-retrospective.md#A2] : `ZOfflineFirstRepository.watch/getAll/count({request})` **droppent** filtre/tri/pagination (loggé). E9-4 est le **consommateur** : les requêtes de **session** (`getDue`, filtre dossier) sont donc **filtrées EN MÉMOIRE** sur le snapshot du store SRS (dette assumée, loggée) — ne pas prétendre à une requête backend.
- **A3 (ré-entrance de cycle)** [epic-5-retrospective.md#A3] : pertinent seulement si `ZFlashcardRepository.sync()` peut être ré-entrant. Prévoir une **garde `_syncing`** coalesçant un cycle si un est déjà en vol (ou déléguer entièrement au `ZSyncOrchestrator`). À traiter uniquement si un `sync()` propre est exposé.

## Acceptance Criteria

1. **Dépôt flashcard offline-first via ports E5 (neutres).** `zcrud_flashcard/lib/src/data/z_flashcard_repository.dart` définit `ZFlashcardRepository`, composé **par injection** d'un `ZSyncableRepository<ZFlashcard>` (port `zcrud_core`, pour la collection cartes) **et** d'un `ZRepetitionStore` (port flashcard-local, pour l'état SRS) **et** d'un `ZSrsScheduler` (défaut `ZSm2Scheduler`). Aucun singleton ; tout injecté (testabilité). Le barrel `zcrud_flashcard.dart` exporte l'API publique (`ZFlashcardRepository`, `ZRepetitionStore`). *Test : construction du dépôt avec fakes en mémoire ; lectures/écritures passent par les ports injectés.*
2. **INVARIANT SRS top-level — jamais dans le sous-arbre de la carte.** L'état `ZRepetitionInfo` est persisté **exclusivement** via `ZRepetitionStore` (canal séparé, chemin logique top-level `study_repetitions/{cardId}`), **jamais** dans le corps/`toMap` de la carte. *Test : après `save(card)` **et** `reviewCard(card, q)`, la map persistée de la carte (relue via le repo carte) ne contient **AUCUNE** clé SRS (`interval`, `repetitions`, `ease_factor`, `next_review_date`, `learned_at`, `last_quality`, `repetition_info`) ; l'état SRS n'est lisible que via `ZRepetitionStore` keyed by `flashcardId`.*
3. **Jamais dupliqué dedans (partage/duplication préserve l'historique d'autrui).** Dupliquer/partager une carte = copier **le corps carte** ; cela n'emporte **pas** le `ZRepetitionInfo` (qui vit dans le store SRS, adressé par `flashcardId`). *Test : une carte B « dupliquée » depuis A (même corps, nouvel `id`) n'a **aucun** état SRS hérité ; l'état SRS de A reste intact et distinct.*
4. **Voie d'écriture SRS UNIQUE — `reviewCard() → ZSrsScheduler.apply` (AD-9).** `reviewCard({required String flashcardId, required String folderId, required int quality, DateTime? now})` est la **SEULE** méthode publique du dépôt qui fait progresser l'état SRS ; elle charge l'état courant (via `ZRepetitionStore`) ou `scheduler.initial(...)` si absent, applique **exactement** `scheduler.apply(current, quality, now: now)`, persiste le nouvel état via `ZRepetitionStore`, et le renvoie (`ZResult<ZRepetitionInfo>`). `initRepetition(...)` (état neuf, délègue à `scheduler.initial`) est le **seul** autre write SRS autorisé. Aucune autre API publique n'écrit un état SRS **avancé**. *Test : `reviewCard` produit `== apply(current, quality)` ; deux `reviewCard` successifs donnent une courbe SM-2 cohérente ; il n'existe pas d'autre chemin public pour avancer l'état.*
5. **Matérialisation de l'éphémère (UUID + `folderId` + dates).** `save(ZFlashcard card)` d'une carte **éphémère** (`id == null`, `folderId != null && folderId non vide`) délègue au port carte, qui matérialise l'`id` opaque (UUID, AD-14) ; le résultat porte **toujours** `id != null`, conserve `folderId`/`subFolderId`, et l'`updated_at` est renseigné (clé LWW, `ZSyncMeta`). *Test : `save` d'une carte éphémère avec `folderId` renvoie `Right(card')` avec `card'.id != null`, `folderId` conservé.*
6. **Carte éphémère sans dossier cible → `Left(DomainFailure)`.** `save`/matérialisation d'une carte **éphémère** dont `folderId` est `null` **ou** vide (`''`) retourne `Left(DomainFailure(...))` (message explicite « dossier cible requis »), **sans** rien écrire (le port carte n'est **jamais** appelé) et **sans** throw. *Test : `save(ephemeral, folderId=null)` → `Left(DomainFailure)` ; `save(ephemeral, folderId='')` → `Left(DomainFailure)` ; le fake carte ne reçoit **aucun** appel `put`.* *(Une carte **déjà matérialisée** — `id != null` — sans `folderId` peut suivre la règle d'écriture normale ou la même garde ; **documenter le choix retenu** ; par défaut : garde appliquée uniquement à la matérialisation de l'éphémère, cf. libellé de l'epic « carte éphémère sauvegardée sans dossier ».)*
7. **Respect AD-1 sur le graphe (flashcard ne tire pas Firebase).** `zcrud_flashcard/pubspec.yaml` **n'ajoute pas** `zcrud_firestore`/`cloud_firestore`/`hive`/`firebase_core` ; `grep -R "cloud_firestore\|package:hive\|firebase_core\|zcrud_firestore" packages/zcrud_flashcard/lib` = **0**. Le graphe reste **acyclique** (`melos list`/résolution inchangés côté deps runtime). *Test/gate : scan d'imports = 0 ; `melos run analyze` RED impossible pour dette cross-package introduite ici.*
8. **Défensif (AD-10) + `Either`/flux nus (AD-11).** Toutes les signatures publiques renvoient `ZResult<…>` / `Stream<List<…>>` nus ; **aucun** `try-catch` nu (toute exception → `Left(ZFailure)`) ; un état SRS **absent** au chargement retombe sur `initial()` (`reviewCard` réussit), un état SRS **corrompu** est reconstruit défensivement via `ZRepetitionInfo.fromMap` (jamais throw) ; lectures `vide ≠ erreur` (`Right([])`). *Test : `reviewCard` sur une carte jamais révisée = premier `apply` sur `initial()` ; store SRS vide → `getDue` = `Right([])`.*
9. **`reviewCard` : cycle complet & pureté de la persistance.** `reviewCard` **ne touche jamais** la carte (aucun `put` carte). L'état persisté est **la map telle quelle** (`ZRepetitionInfo.toMap()`), sans recalcul à la (dé)sérialisation ; la sync SRS merge par **LWW sur `ZSyncMeta.updatedAt`** (hors-entité, estampillé à l'écriture par le store), jamais en dérivant l'état. *Test : après `reviewCard`, le fake carte n'a reçu aucun `put` ; l'état relu via `ZRepetitionStore` `==` l'état renvoyé.*
10. **Sélection de session `getDue` (filtrage local — dette A2 assumée).** `getDue({required DateTime now, String? folderId})` retourne (`ZResult<List<ZRepetitionInfo>>`) les états **dus** (`nextReviewDate == null` ⇒ jamais révisé, dû ; sinon `nextReviewDate <= now`), filtrés **en mémoire** sur le snapshot du store SRS (+ filtre `folderId` si fourni, sur `ZRepetitionInfo.folderId`) ; le drop de traduction requête→backend est **loggé** (jamais silencieux). `vide ≠ erreur`. *Test : mix d'états dus/non-dus/jamais-révisés → seuls les dus remontent ; filtre `folderId` respecté.*
11. **Offline-first hérité E5 pour la carte + `sync()` best-effort.** Les écritures carte (`save`/`softDelete`/`restore`) délèguent au port `ZSyncableRepository<ZFlashcard>` (local autoritaire + distant best-effort). `ZFlashcardRepository.sync()` délègue au `sync()` du repo carte **et** au `sync()` du `ZRepetitionStore` (best-effort ; `Right(unit)` si offline ; échec partiel toléré et **loggé**, jamais d'arrêt global — cf. E5-4). Garde de **ré-entrance** (A3) si un `sync()` est en vol. *Test : `sync()` avec store distant injoignable (couture `isConnected=false` des fakes) → `Right(unit)`, local intact.*

## Tasks / Subtasks

- [x] **T1. Poser la couche `data/` + le port SRS flashcard-local** (AC1, AC2, décision archi)
  - [x] Créer `packages/zcrud_flashcard/lib/src/data/`.
  - [x] Définir le **port** `ZRepetitionStore` (neutre, adressé par `flashcardId`) : `getByCard(String flashcardId) → ZResult<ZRepetitionInfo?>` (`Right(null)` si absent, `vide ≠ erreur`), `put(ZRepetitionInfo) → ZResult<ZRepetitionInfo>` (estampille `ZSyncMeta.updatedAt`), `getAll() → ZResult<List<ZRepetitionInfo>>`, `sync() → ZResult<Unit>` (best-effort), `dispose()`. Documenté : LWW **via `ZSyncMeta` hors-entité** (l'état n'a pas de champ `updatedAt`).
  - [x] Exporter `ZFlashcardRepository` + `ZRepetitionStore` au barrel `zcrud_flashcard.dart`.
- [x] **T2. `ZFlashcardRepository` — coordinateur offline-first** (AC1, AC5, AC6, AC8, AC11)
  - [x] Constructeur injectant `ZSyncableRepository<ZFlashcard> cards`, `ZRepetitionStore reps`, `ZSrsScheduler scheduler = const ZSm2Scheduler()` (const réel d'E9-2 vérifié), logger neutre optionnel `ZFlashcardRepositoryLog` (défaut no-op).
  - [x] `save(card)` : si `card.isEphemeral` **et** (`folderId == null || folderId.isEmpty`) → `Left(DomainFailure)` **sans** appeler `cards` ; sinon déléguer à `cards.save(card)` (matérialisation AD-14).
  - [x] `softDelete(id)`/`restore(id)` : délégation au port carte.
  - [x] `sync()` : déléguer `cards.sync()` + `reps.sync()`, best-effort/échec partiel toléré + loggé ; garde de ré-entrance `_syncing` (A3, `try/finally` sans `catch`).
- [x] **T3. Voie d'écriture SRS unique** (AC4, AC9, AC2)
  - [x] `initRepetition({flashcardId, folderId})` → `scheduler.initial(...)` puis `reps.put(...)`.
  - [x] `reviewCard({flashcardId, folderId, quality, now})` : charger l'état (`reps.getByCard`) ou `scheduler.initial(...)` si absent (AD-10) → `scheduler.apply(current, quality, now: now)` → `reps.put(next)` → `Right(next)`. **Aucun** accès `cards` (vérifié par espion `saveCount==0`).
  - [x] Aucune autre méthode publique n'écrit un état SRS avancé (seuls `reviewCard`/`initRepetition` appellent `reps.put`).
- [x] **T4. Sélection de session** (AC10)
  - [x] `getDue({now, folderId})` : `reps.getAll()` → filtre en mémoire (dû + `folderId`) → `Right(list)` ; drop requête→backend loggé (A2).
- [x] **T5. Fakes en mémoire pour tests** (AC1, tous) — `test/support/fakes.dart`
  - [x] Fake `ZSyncableRepository<ZFlashcard>` en mémoire (matérialise l'`id` à `save`, estampille `updatedAt`, couture `connected`), + espions `saveCount`/`syncCount`.
  - [x] Fake `ZRepetitionStore` en mémoire (keyed by `flashcardId`, estampille `ZSyncMeta`, persiste la map telle quelle + relit via `fromMap` — `injectRaw` pour le corrompu, couture `connected`/`failSync`).
- [x] **T6. Tests** — `test/z_flashcard_repository_test.dart` (18 tests) : invariant top-level, non-duplication, voie unique, matérialisation, `folderId` manquant, offline-first, défensif, `getDue`.
- [x] **T7. Gates** : `grep` anti-Firebase/Hive/firestore dans `lib/` = **0** (AC7) ; `build_runner` (aucun nouveau `@ZcrudModel`) → `dart analyze` RC=0 → `flutter test` RC=0 (135 tests, 117 baseline + 18) → `graph_proof` ACYCLIQUE + flashcard ne tire pas firestore.

## Dev Notes

### Ports E5 réutilisés **verbatim** (aucune réécriture)
- `ZSyncableRepository<T extends ZEntity>` [z_syncable_repository.dart] : `ZRepository<T>` + `sync()` one-shot (best-effort, `Right(unit)` si offline). Pour la carte : injecter une instance de `ZOfflineFirstRepository<ZFlashcard>` (E5-3, `zcrud_firestore`) **typée sur ce port** — jamais importée par flashcard.
- `ZOfflineFirstRepository<T>` [z_offline_first_repository.dart] : composition local autoritaire + distant fire-and-forget, `save` **fire-and-forget strict** (`unawaited` du push), `sync()` = pull + LWW + push borné ; **A1** (ServerFailure=offline) et **A2** (request drop `watch/getAll/count`) y sont tracées.
- `ZLocalStore<T>`/`ZRemoteStore<T>` [z_local_store.dart / z_remote_store.dart] : `put` **matérialise l'éphémère** (UUID) + `is_deleted:false`/`updated_at` ; `applyMerged`/`applyMergedAll` = écriture **préservant `ZSyncMeta`** (jamais `now()`) réservée au merge ; borne ≤ 450 **backend-spécifique** (dans `zcrud_firestore`).
- `ZLwwResolver` / `ZSyncEntry<T>` / `ZSyncMeta{updatedAt,isDeleted}` [sync/*.dart] : `updatedAt null` = plus ancien ; **égalité** → **local fait foi** ; méta **hors-entité** — c'est cette méta qui porte la clé LWW du SRS (l'état `ZRepetitionInfo` n'a **pas** de champ `updatedAt`).

### Domaine flashcard (E9-1/2/3) — source tree touché / réutilisé
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — ajouter les exports `data/` (préserver les `hide ZRepetitionInfoZcrud`/`ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` existants).
- **NEW** `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart`, `.../z_repetition_store.dart`.
- **REUSE (ne pas modifier)** : `ZFlashcard` [z_flashcard.dart] — `ZEntity`, `id: String?` (`@ZcrudId`), `folderId`/`subFolderId`, `createdAt`/`updatedAt`, **zéro champ SRS** (l'invariant top-level est **déjà** garanti côté modèle : `toMap()` carte ne peut pas contenir de SRS). `ZRepetitionInfo` [z_repetition_info.dart] — **pas de `ZEntity`**, clé `flashcardId`+`folderId`, `nextReviewDate`, `toMap()`/`fromMap` défensif « map telle quelle » **sans** scheduler ; **pas de `copyWith` SRS public** (voie unique). `ZSrsScheduler.apply/initial/simulate` [z_srs_scheduler.dart], `ZSm2Scheduler` [z_sm2_scheduler.dart], `ZSrsConfig`.
- **CONTRAINTE DURE** : ne PAS toucher `zcrud_core` ni les modèles E9-1/2/3. Tout le neuf vit dans `zcrud_flashcard/lib/src/data/`.

### Invariant SRS top-level — comment il est **tenu**
1. **Côté modèle (déjà) :** `ZFlashcard` ne porte aucun champ SRS → `card.toMap()` ne peut jamais sérialiser d'état SRS (E9-1, vérifié).
2. **Côté dépôt (cette story) :** `reviewCard`/`initRepetition` écrivent **uniquement** via `ZRepetitionStore` (canal séparé) ; **jamais** via `cards`. Le chemin logique cible est `study_repetitions/{cardId}` (canonique §7, l.305-306 : « le SRS va en top-level `users/{uid}/study_repetitions/{cardId}` — jamais dans le sous-arbre partageable »).
3. **Preuve par test :** map carte relue = 0 clé SRS (AC2) ; duplication ne propage pas l'état (AC3).

### Pièges LLM à éviter
- **NE PAS** ajouter `zcrud_firestore`/`cloud_firestore`/`hive` au pubspec flashcard (AD-1) — injecter les ports.
- **NE PAS** importer/instancier `ZOfflineFirstRepository` directement dans `zcrud_flashcard` — le recevoir typé `ZSyncableRepository<ZFlashcard>`.
- **NE PAS** ajouter un champ SRS à `ZFlashcard`, ni un `copyWith` SRS public à `ZRepetitionInfo` (casse la voie unique AD-9).
- **NE PAS** recalculer l'état SRS à la (dé)sérialisation ou au merge (map telle quelle ; LWW via `ZSyncMeta`).
- **NE PAS** `try-catch` nu ni throw sur état corrompu → `Left`/`fromMap` défensif/`initial()`.
- **NE PAS** ré-assimiler de nouvelles erreurs applicatives à « offline » (A1) — se contenter d'hériter/loguer.
- **NE PAS** modifier `zcrud_core` — si un besoin core **réel** émerge (ex. port SRS générique), **STOP** et signaler à l'orchestrateur.

### Project Structure Notes
- Alignement : `zcrud_<domaine>` ; API publique = barrel `lib/<pkg>.dart` ; impl sous `lib/src/{domain,data}`. E9-4 introduit `lib/src/data/` (premier de ce package).
- Aucun conflit détecté avec la structure unifiée ; le port SRS **flashcard-local** est un ajout légitime (le cœur reste minimal, AD-1).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E9] — Story E9-4 : offline-first (E5) ; invariant SRS top-level (canonique §2.7/§7) ; carte éphémère sans dossier → `Left(DomainFailure)`.
- [Source: architecture.md#AD-9] — offline-first LWW + état SRS séparé + voie unique `reviewCard()→ZSrsScheduler.apply`.
- [Source: architecture.md#AD-1] — acyclicité/isolation ; `zcrud_flashcard` ne tire pas Firebase.
- [Source: architecture.md#AD-14] — matérialisation de l'éphémère par le repository.
- [Source: architecture.md#AD-10,#AD-11] — désérialisation défensive ; `Either`/flux nus.
- [Source: docs/canonical-schema.md#6] (l.299) — `initRepetition{flashcardId,folderId}` (seul write hors `apply`) ; `reviewCard(current,quality,{now})` applique `apply` en interne (voie unique) ; `getDue({now})`.
- [Source: docs/canonical-schema.md#7] (l.305-306) — Firestore fire-and-forget ; SRS **top-level** `study_repetitions/{cardId}`, **jamais** dans le sous-arbre partageable.
- [Source: z_offline_first_repository.dart / z_syncable_repository.dart / z_local_store.dart / z_remote_store.dart / sync/*.dart] — ports & patron E5 réutilisés.
- [Source: z_flashcard.dart / z_repetition_info.dart / z_srs_scheduler.dart] — modèles E9-1/2 réutilisés (SRS hors carte, voie unique).
- [Source: stories/e5-3-offline-first-lww-soft-delete.md, e5-4-zsyncorchestrator.md, epic-5-retrospective.md#A1,#A2,#A3] — patron offline-first + dettes héritées.
- [Source: stories/e9-2-srs-pluggable-zsrsscheduler.md] — `reviewCard()` réel + persistance top-level = E9-4 (annoncé).

### Testing
Framework : `flutter test` (le package tire Flutter via `zcrud_core`). Fichiers `*_test.dart` sous `packages/zcrud_flashcard/test/`. Fakes **en mémoire** (pas de Firebase). Cas obligatoires :
- **Invariant top-level (AC2)** : après `save` + `reviewCard`, la map carte relue = **0 clé SRS** ; l'état n'est lisible que via `ZRepetitionStore`.
- **Non-duplication (AC3)** : carte dupliquée (nouvel `id`, même corps) → aucun état SRS hérité ; état source intact.
- **Voie d'écriture SRS unique (AC4/AC9)** : `reviewCard == apply(current,quality)` ; deux `reviewCard` = courbe SM-2 cohérente ; le fake carte ne reçoit **aucun** `put` pendant `reviewCard` ; aucun autre chemin public n'avance l'état.
- **Matérialisation éphémère (AC5)** : `save(ephemeral, folderId)` → `id != null`, `folderId` conservé, `updatedAt` renseigné.
- **`folderId` manquant (AC6)** : `save(ephemeral, folderId=null)` **et** `folderId=''` → `Left(DomainFailure)` ; fake carte **jamais** appelé ; pas de throw.
- **Défensif (AC8)** : `reviewCard` sur carte jamais révisée = premier `apply` sur `initial()` ; état SRS corrompu reconstruit via `fromMap` sans throw ; `getDue` store vide → `Right([])`.
- **`getDue` (AC10)** : mix dus/non-dus/jamais-révisés → seuls les dus ; filtre `folderId` respecté.
- **Offline-first / `sync()` (AC11)** : couture `isConnected=false` → `sync()` = `Right(unit)`, local intact ; échec partiel d'un port → l'autre continue, loggé, pas d'arrêt global.
- **Gate AD-1 (AC7)** : test/CI `grep` = 0 pour `cloud_firestore`/`hive`/`firebase_core`/`zcrud_firestore` sous `packages/zcrud_flashcard/lib`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, tool Skill — pas de fallback disque).

### Debug Log References

- 1 échec initial du test AC2 : `folder_id` (champ **légitime** de la carte) inclus par erreur dans l'ensemble des clés SRS interdites. Corrigé — l'ensemble AC2 ne retient que les clés SRS-spécifiques (`interval`/`repetitions`/`ease_factor`/`next_review_date`/`learned_at`/`last_quality`/`repetition_info`).
- 2 infos `prefer_initializing_formals` (faux positifs : champs privés exposés en paramètres nommés publics — `this._x` interdit par Dart). Neutralisés par `// ignore_for_file: prefer_initializing_formals`, à l'identique du dépôt offline-first d'E5.

### Completion Notes List

- **Décision d'architecture respectée (AD-1)** : le dépôt vit dans `zcrud_flashcard/lib/src/data/`, bâti **uniquement** sur les ports neutres de `zcrud_core` (`ZSyncableRepository<ZFlashcard>`, `ZResult`, `DomainFailure`, `Unit`, `ZSyncMeta`). `ZOfflineFirstRepository` **jamais** importé — reçu par injection typée sur le port neutre. **Aucune** arête `zcrud_flashcard → zcrud_firestore` créée (graph_proof : flashcard → {annotations, core, export, generator, markdown} seulement).
- **Friction `ZRepetitionInfo` non-`ZEntity` résolue** par le port flashcard-local `ZRepetitionStore` (adressé par `flashcardId`, LWW via `ZSyncMeta` hors-entité). **Aucune** édition de `zcrud_core`.
- **Invariant SRS top-level (AC2)** tenu à deux niveaux : (1) côté modèle `ZFlashcard` ne porte aucun champ SRS (E9-1) ; (2) côté dépôt `reviewCard`/`initRepetition` n'écrivent **que** via `ZRepetitionStore` — jamais `cards`. Test : 0 clé SRS dans la map carte relue après `save` + `reviewCard`.
- **Voie d'écriture SRS unique (AC4/AC9)** : `reviewCard → scheduler.apply` est le seul chemin d'avancement ; `initRepetition → scheduler.initial` le seul autre write ; `reviewCard` ne touche jamais la carte (espion `saveCount == 0`).
- **Défensif (AD-10)** : état absent → `Right(null)` → repli `initial()` ; état corrompu → `ZRepetitionInfo.fromMap` (jamais de throw) ; `getDue` store vide → `Right([])`.
- **Dettes E5 héritées & documentées** (A1 ServerFailure=offline hérité via ports ; A2 `getDue` filtré en mémoire + loggé ; A3 garde de ré-entrance `_syncing` sur `sync()`).
- **Choix AC6 documenté** : la garde `folderId` obligatoire ne s'applique qu'à la **matérialisation de l'éphémère** (`id == null`) ; une carte déjà matérialisée sans `folderId` suit l'écriture normale.
- **Vérif verte réelle** : `dart analyze packages/zcrud_flashcard` RC=0 ; `flutter test packages/zcrud_flashcard` = **135 tests OK** (117 baseline E9-1/2/3 + 18 nouveaux) ; `grep` AD-1 = 0 ; `graph_proof` ACYCLIQUE OK + CORE OUT=0.

### File List

- **NEW** `packages/zcrud_flashcard/lib/src/data/z_repetition_store.dart` — port SRS flashcard-local neutre.
- **NEW** `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart` — coordinateur offline-first + voie d'écriture SRS unique.
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — exports `data/` (`ZFlashcardRepository`, `ZRepetitionStore`).
- **NEW** `packages/zcrud_flashcard/test/support/fakes.dart` — fakes en mémoire (`FakeCardRepository`, `FakeRepetitionStore`).
- **NEW** `packages/zcrud_flashcard/test/z_flashcard_repository_test.dart` — 18 tests (AC1–AC11).
