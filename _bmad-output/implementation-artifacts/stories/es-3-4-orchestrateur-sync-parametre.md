---
baseline_commit: 8c0cf418a5a6861d8b042d6e0df43d08ceefcd5e
---

# Story ES-3.4 : Orchestrateur de synchronisation paramétré (liste injectée)

Status: review

<!-- Epic ES-3 : Ports & couche data offline-first bi-topologie. -->
<!-- FR-S15 · AD-9 / AD-20 / AD-5 / AD-11 / AD-1 / AD-17 / AD-4 · NFR-S3/NFR-S9. -->
<!-- Dépend d'ES-3.1 (port ZStudyRepository<T> ⊂ ZSyncableRepository) + ES-3.2 (ZOfflineFirstBoxRepository = les repos concrets à orchestrer). -->
<!-- COMPOSE l'orchestrateur E5-4 (`zcrud_core`, register/unregister/débounce/best-effort déjà livrés). -->
<!-- Le CÂBLAGE (liste injectée depuis l'app) est la substance NEUVE, dans `zcrud_firestore`. Micro-ajout ADDITIF `registerAll` dans `zcrud_core`. -->
<!-- Ne touche PAS `zcrud_study_kernel`, ni le sprint-status. -->

## Story

As a **développeur intégrateur** (qui doit déclencher la synchronisation offline→online d'un **ensemble** de dépôts d'étude — flat IFFD *et* nested lex — sans re-coder à la main la liste des repos, ni recopier le patron `StudySyncManager` de lex accroché à Riverpod/`firebase_auth`/`connectivity_plus`),
I want **assembler un `ZSyncOrchestrator` (E5-4, `zcrud_core`) à partir d'une LISTE de dépôts synchronisables INJECTÉE par l'app (jamais des imports/une liste codés en dur), best-effort — un dépôt en panne n'arrête pas les autres — et débouncé ~400 ms (paramétrable) pour coalescer les rafales login/reconnexion sans jamais bloquer le thread UI**,
so that **brancher le même *quand* de synchronisation sur les deux topologies via un seul point de câblage neutre (`zcrud_firestore`), en éliminant le doublon `lex_data/data/services/study_sync_manager.dart` (11 repos + 11 imports codés en dur, l.9-19 & 98-112) — le *comment* (`sync()` one-shot par dépôt) restant dans `ZOfflineFirstBoxRepository` (ES-3.2) et le *quand* restant l'orchestrateur E5-4 que cette story NE ré-implémente PAS (AD-4 composer)**.

---

## Contexte & problème mesuré

### Le doublon « liste de repos synchronisés codée en dur » (origine lex)

`lex_data/data/services/study_sync_manager.dart` (mesuré sur disque, `/home/zakarius/DEV/lex_douane/`) est **l'artefact exact à paramétrer** :

- **11 imports de `*_repository_impl.dart` codés en dur** (l.9-19) : `exams`, `flashcards`, `mindmaps`, `repetition`, `document_annotations`, `document_reading_state`, `study_documents`, `study_sharing`, `podcast`, `smart_notes`, `study_folders`.
- **La liste `_syncAll()` codée en dur** (l.98-112) : un `List<Future<void> Function()>` de **11 lambdas** `() async => _runSync(ref.read(<xxx>RepositoryProvider).sync())`. **Ajouter un dépôt = éditer cette liste** ⇒ couplage en dur, non portable IFFD↔lex.
- **Débounce 400 ms** (l.55 `_debounceDelay = Duration(milliseconds: 400)`, l.81-84 `_debouncedSyncAll`) : réarme un `Timer` à chaque reconnexion pour collapser les rafales `connectivity_plus`.
- **Best-effort** (l.86-124) : boucle `for (final run in syncs) { try { await run(); } catch (e) { … } }` — *« un échec isolé n'arrête jamais les autres repos »* (l.118). Le repo wrappe déjà toute erreur en `Left` (l.127), donc aucune n'est propagée globalement.
- **Couplage manager** : `@Riverpod(keepAlive: true)`, `ref.listen(studySyncAuthStateProvider…)` (login, l.65-69) + `ref.listen(appNetworkStatusProvider…)` (reconnexion, l.72-78), `firebase_auth` (l.3). **Tout ce couplage Riverpod/firebase_auth/connectivity_plus est app-spécifique** — il ne doit JAMAIS remonter dans un package zcrud (AD-15).

### Ce qui existe DÉJÀ dans le repo (à COMPOSER, PAS à dupliquer — AD-4)

Toute la **mécanique du *quand*** est déjà livrée par **E5-4** — cette story n'en réécrit AUCUNE ligne :

- **`ZSyncOrchestrator`** (`packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart`, PUR-DART) expose DÉJÀ :
  - **injection dynamique** `register(ZSyncableRepository<dynamic>)` / `unregister(...)` — registre `Set` **par identité**, idempotent, no-op après `dispose` (l.177-186) ;
  - **débounce paramétrable** `kZSyncDefaultDebounce = 400 ms` (l.110), surchargeable au constructeur (`debounce:`, l.135) ; `_schedule()` **annule + réarme** (coalescence trailing N→1, l.218-227) ;
  - **déclencheurs sémantiques** `onLogin()` / `onReconnected()` (l.209-212) — planifient un cycle débouncé ;
  - **best-effort intégral tolérant à l'échec partiel** `_runCycle()` (l.283-340) : itère une **copie** du registre, isole **chaque** `repo.sync()` (`try/catch` + garde du `Left`), **compte** `failed`/`failures`, **loggue** (AD-11, jamais `catch(_){}` muet), **n'interrompt jamais** la boucle, **aucune** exception ne s'échappe ;
  - **`syncNow()`** (cycle immédiat) renvoie **`Right(ZSyncRunReport)`** même en échec partiel (l.243-246) — jamais un `Left` global ;
  - **couture de connectivité** `isConnected` optionnelle (cycle sauté proprement si `false`/throw, l.286-303) ; **gate** `enabled` (l.200-204) ;
  - **couture de fabrique de timer** `ZSyncTimerFactory` / `ZCancelableTimer` (l.78-89) → tests **sans horloge murale** + `flushPending()` (test only, l.258-263) ;
  - **`dispose()` NON-propriétaire** : annule le timer, **vide** le registre, mais **ne dispose PAS** les dépôts enregistrés (leur cycle de vie appartient à l'app/binding, l.42-45 & 349-354).
- **`ZSyncableRepository<T extends ZEntity>`** (`packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart`) : le sur-port `sync(): Future<ZResult<Unit>>`, best-effort (`Right(unit)` si déconnecté, l.30-39). C'est **le seul contrat** que l'orchestrateur appelle.
- **`ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>`** (ES-3.2, `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart`) et **`ZStudyRepository<T> extends ZSyncableRepository<T>`** (ES-3.1, kernel, l.68-69) : **les repos concrets à orchestrer**. Chacun **EST** un `ZSyncableRepository` (transitivement), donc **directement** `register`-able dans l'orchestrateur E5-4. C'est la **liste** de ceux-là que l'app injecte.

### Le décalage à combler (ce qui MANQUE réellement)

L'orchestrateur E5-4 injecte les dépôts **un par un** (`register`) et son câblage E5 (`e5-4-zsyncorchestrator.md`) suppose que **l'app** appelle `register()`/`onLogin()`. Il **n'existe encore AUCUN** :

1. **API « liste en lot »** : `register` prend UN dépôt ; le AC ES-3.4 demande explicitement que l'orchestrateur *« prend une **liste injectée** »* (epics l.568). Un `registerAll(Iterable<…>)` est le miroir first-class, nommé et **testable** de cette exigence (garde d'itération : « aucun repo oublié »).
2. **Point de câblage neutre côté adapters** qui **REMPLACE** `study_sync_manager.dart` : une fabrique de `zcrud_firestore` qui reçoit la **liste injectée** de `ZSyncableRepository` de l'app, construit un `ZSyncOrchestrator` et l'assemble — **sans** importer/construire un seul repo concret, **sans** Riverpod/`firebase_auth`/`connectivity_plus`.

### Le piège à contrer (motif dominant — R12/DW-ES25-1)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Risques spécifiques de CETTE story, chacun avec sa garde discriminante (AC + injection R3) :
1. une « liste injectée » qui **oublie d'itérer** un dépôt (un `registerAll`/assembleur qui `register` seulement le premier) sans qu'aucun test ne rougisse — un repo jamais synchronisé en prod ;
2. un « best-effort » **décoratif** où la panne d'UN dépôt **court-circuite** la sync des autres (ou remonte un `Left` global) ;
3. un « débounce » **inerte** où N déclencheurs rapprochés lancent **N** cycles au lieu d'**un** coalescé ;
4. un `dispose` qui **s'approprie** les dépôts injectés (les `dispose`) alors que l'app en est propriétaire ;
5. une fabrique qui **ré-importe/re-code en dur** des repos (re-produisant `study_sync_manager.dart:9-19,98-112`).

### Ce que cette story NE fait PAS

- **Ne ré-implémente PAS** l'orchestrateur E5-4 (débounce, best-effort, registre, gate, `isConnected`, `dispose` non-propriétaire, `syncNow`/`flushPending`) — **composé tel quel** (AD-4). Aucune de ces mécaniques n'est recopiée.
- **N'importe PAS** Riverpod / `firebase_auth` / `connectivity_plus` dans un package zcrud (le couplage `StudySyncManager` reste app-spécifique — AD-15). Login/reconnexion sont pilotés par l'app qui appelle `onLogin()`/`onReconnected()` ; la connectivité est une **couture** `Future<bool> Function()?` déjà offerte par E5-4.
- **Ne touche PAS** le `sync()` par dépôt (le *comment*, ES-3.2/E5-3) ni la cascade (ES-3.3) ni le codec legacy IFFD (ES-3.5).
- **N'écrit PAS** `zcrud_study_kernel` (les ports sont livrés) ni le sprint-status (orchestrateur).
- **Ne rouvre pas** DW-ES25-1 / DW-ES32-1 / DW-ES33-1 (voir Dépendances/dettes).

---

## Décision structurante : qu'ajoute ES-3.4 **vs** le `register`/`unregister` existant ?

**Constat de départ (mesuré) :** le mécanisme d'injection dynamique **existe déjà** (register/unregister + débounce paramétrable + best-effort + `onLogin`/`onReconnected` + gate + `isConnected` + `dispose` non-propriétaire). ES-3.4 **ne le recrée pas**. La substance neuve = **le câblage « liste injectée depuis l'app »** + une **API en lot** first-class. Répartition tranchée :

### D1 — Micro-ajout ADDITIF `registerAll(Iterable<ZSyncableRepository<dynamic>>)` dans `zcrud_core` (E5-4). **Additif pur, jamais une rupture de signature.**

Le AC ES-3.4 exige que l'orchestrateur *« prend une **liste injectée** »* (epics l.568). `register` (un dépôt) existe ; `registerAll` (une **liste**) est le miroir **first-class, nommé, testable** de l'exigence — et le **foyer naturel de la garde d'itération** (« aucun repo oublié »). Implémentation minimale : **boucle `register`** (réutilise l'idempotence/`dispose`-safety existantes), **no-op après `dispose`**, **pur-Dart** (aucun import Flutter/backend — la couche `lib/src/domain` reste PUR-DART, garde `domain_purity_test`). **Rien d'autre n'est modifié dans E5-4** : ni le constructeur, ni `register`/`unregister`/`_schedule`/`_runCycle`/`dispose`, ni les signatures publiques. **C'est l'unique édition de `zcrud_core`** (une seule story touche core, additive).
**Rejeté — un paramètre `repositories:` au constructeur** : casserait le contrat E5 « registre alimenté après construction / avant `onLogin` », introduirait une seconde voie d'injection (constructeur *et* `register`) et toucherait la signature du constructeur (moins additif). `registerAll` est **strictement additif** et compose la voie existante.
**Rejeté — faire la boucle uniquement dans la fabrique `zcrud_firestore`** (sans `registerAll` core) : possible, mais prive core de la garde d'itération nommée/unitaire et éloigne l'API « liste injectée » de l'endroit où vit l'orchestrateur. `registerAll` (trivial, additif, web-safe) porte la garde au bon niveau.

### D2 — La SUBSTANCE (câblage « liste injectée depuis l'app ») vit dans `zcrud_firestore` : fabrique `assembleZStudySyncOrchestrator(...)`.

C'est le **remplaçant neutre et portable de `study_sync_manager.dart`** : une **fonction de fabrique** (pas une classe à état — l'état vit dans le `ZSyncOrchestrator` retourné) qui **reçoit la liste injectée** de dépôts et rend un orchestrateur **assemblé** :

```
ZSyncOrchestrator assembleZStudySyncOrchestrator({
  required Iterable<ZSyncableRepository<dynamic>> repositories, // ← LISTE INJECTÉE (app)
  Duration debounce = kZSyncDefaultDebounce,                    // ~400 ms (paramétrable)
  ZSyncTimerFactory? timerFactory,        // couture test (fake clock) — typedef core
  Future<bool> Function()? isConnected,   // couture réseau app (défaut null)
  bool enabled = true,                    // gate d'activation
  ZSyncOrchestratorLog? logger,           // journal neutre
})
```

Corps : `final orchestrator = ZSyncOrchestrator(debounce:…, timerFactory:…, isConnected:…, enabled:…, logger:…); orchestrator.registerAll(repositories); return orchestrator;`. **AUCUN** repo concret n'est importé/construit dans ce fichier — la liste **vient de l'app** (qui injecte ses `ZOfflineFirstBoxRepository`). Login/reconnexion : l'app appelle `orchestrator.onLogin()` / `orchestrator.onReconnected()` (le pont vers `authStateChanges`/`connectivity_plus` reste dans l'app, AD-15).
**Placement `zcrud_firestore`** (et non core) : `zcrud_firestore` **possède** `ZOfflineFirstBoxRepository` (les objets orchestrés) et est le foyer des adapters ; core doit rester **agnostique de la liste** (aucune connaissance des repos study). C'est l'analogue portable de `study_sync_manager.dart` **sans** son couplage Riverpod/firebase_auth/connectivity_plus.
**Rejeté — une classe `ZStudySyncManager` à état/lifecycle** : réintroduirait un mini-orchestrateur concurrent de E5-4 (l'état de débounce/registre est DÉJÀ dans `ZSyncOrchestrator`). La fabrique **compose**, elle ne détient rien.

### D3 — `zcrud_firestore` = package **Flutter** ⇒ HORS `gate:web-determinism` ; `registerAll` core = PUR-DART web-safe ; `reserved-keys` intouché.

`zcrud_firestore` déclare `flutter:` ⇒ **exclu** de `gate_web_determinism.dart` (packages pur-Dart uniquement, cf. ES-3.2 D9) ; ses tests tournent sous `flutter_test` (VM), **pas** de `@TestOn('vm')`, **pas** de run `-p node`. Le micro-ajout `registerAll` vit dans `packages/zcrud_core/lib/src/domain/sync/` (**PUR-DART** — aucun import Flutter/backend) : il **doit** rester web-safe (garde `domain_purity_test` du kernel/core). **Aucun** `@ZcrudModel` n'est ajouté ⇒ **aucun** `.g.dart` neuf, **aucun** `registerZ…`, `gate_reserved_keys.dart` reste **VERT sans toucher** `tool/reserved_keys_gate/**`.

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (R12) : le test associé **ROUGIT par le retrait de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli (pas de test POWERLESS). L'orchestrateur rejoue chaque **injection R3** (retirer/inverser la garde → ROUGE **par cette garde**) et **restaure par édition ciblée** (`diff` vide — R13, JAMAIS `git checkout`). Backend de test : **dépôts espions** comptant leurs `sync()` (`_SpyRepo` implémentant `ZSyncableRepository`, parité `z_sync_orchestrator_test.dart:55-85`) + **fabrique de timer contrôlable** (`_FakeTimer`/`_FakeTimerFactory`, l.19-46) — **aucun `Timer` réel ni `Future.delayed`**.

**AC1 — `registerAll(Iterable<ZSyncableRepository<dynamic>>)` existe dans `ZSyncOrchestrator` (additif, PUR-DART) et enregistre CHAQUE dépôt de la liste.** _(garde d'itération)_
`registerAll` est déclaré sur `ZSyncOrchestrator` (fichier E5-4), **boucle `register`** (idempotent par identité), **no-op après `dispose`**. Après `registerAll([r1, r2, r3])`, `registeredCount == 3` ; `registerAll` re-appelé avec la même liste ⇒ toujours `3` (idempotence héritée) ; `registerAll` après `dispose` ⇒ `registeredCount == 0` (no-op). Le constructeur, `register`/`unregister`, `_schedule`, `_runCycle`, `dispose` sont **inchangés** (édition strictement additive).
_Injection R3-a :_ remplacer la boucle par `register(repos.first)` (n'itère qu'un dépôt) → `registeredCount == 1` au lieu de `3` ⇒ ROUGE **par la garde d'itération**. ⇒ « aucun repo oublié » est LOAD-BEARING.

**AC2 — Liste injectée bout-en-bout via la fabrique `zcrud_firestore` : un cycle synchronise TOUS les dépôts injectés, exactement une fois.** _(discriminant liste injectée × spies)_
Étant donné `assembleZStudySyncOrchestrator(repositories: [spyA, spyB, spyC], timerFactory: fake)`, quand on `onLogin()` **puis** `flushPending()` (ou `fire()` du fake timer), alors `spyA.syncCalls == 1 && spyB.syncCalls == 1 && spyC.syncCalls == 1` — **chaque** dépôt injecté est synchronisé (aucun oublié, aucun doublé).
_Injection R3-a (rejouée bout-en-bout) :_ casser le `registerAll`/la boucle de la fabrique (n'assembler que `repositories.first`) → `spyB.syncCalls == 0` (ou `spyC`) ⇒ ROUGE. ⇒ la liste injectée est réellement itérée jusqu'au bout (comptée par les spies, pas par l'existence de la fabrique — R12).

**AC3 — AUCUNE liste/import de repos codés en dur : la fabrique reçoit une `Iterable` neutre et n'importe/ne construit AUCUN repo concret (AD-20/FR-S15).** _(discriminant anti-doublon `study_sync_manager`)_
La signature de `assembleZStudySyncOrchestrator` prend `required Iterable<ZSyncableRepository<dynamic>> repositories` ; le fichier `z_study_sync_orchestrator.dart` **n'importe aucun** `*_repository_impl.dart` et **ne construit aucun** dépôt (`new`/factory de repo) — miroir de l'éradication de `study_sync_manager.dart:9-19,98-112`. Aucun `runtimeType`/`T.toString()`/réflexion pour dériver un dépôt.
_Test :_ garde statique (grep d'assertion : le fichier fabrique ne contient ni `RepositoryImpl`, ni `ZOfflineFirstBoxRepository(`, ni construction de dépôt ; sa seule source de dépôts est le paramètre `repositories`). Ajouter un dépôt = **passer une liste plus longue à l'appel**, jamais éditer la fabrique.

**AC4 — Best-effort : la panne d'UN dépôt N'ARRÊTE PAS les autres et ne remonte AUCUN `Left` global.** _(cœur discriminant best-effort)_
Étant donné `assemble(repositories: [okA, boom, okB])` où `boom.sync()` **lève** (ou renvoie `Left(ServerFailure)`), quand un cycle s'exécute (`syncNow()` **ou** débouncé), alors : `okA.syncCalls == 1 && okB.syncCalls == 1` (les deux sains sont synchronisés **malgré** la panne du milieu), l'échec est **loggé + compté** (`report.failed >= 1`), et `syncNow()` renvoie **`Right(ZSyncRunReport)`** — **jamais** un `Left` global, **jamais** une exception échappée.
_Injection R3-b :_ dans `_runCycle`, retirer le `try/catch` par-dépôt / **rethrow** au premier échec (court-circuit) → `okB.syncCalls == 0` (le dépôt après la panne n'est pas atteint) **ou** `syncNow()` retourne `Left`/throw ⇒ ROUGE. ⇒ la tolérance à l'échec partiel est PROUVÉE sur la liste injectée.

**AC5 — Débounce ~400 ms (paramétrable) : N déclencheurs rapprochés coalescent en UN seul cycle.** _(discriminant coalescence, fake clock)_
Étant donné `assemble(repositories: [spy], debounce: D, timerFactory: fake)`, quand on appelle **N fois** rapprochées `onLogin()`/`onReconnected()` (chacune **avant** l'échéance), alors le fake timer est **réarmé** (les précédents `isCancelled`), **un seul** cycle s'exécute au `fire()` final : `spy.syncCalls == 1` (**pas** `N`). La fenêtre est **paramétrable** : le fake timer capture `duration == D` ; sans override, `duration == kZSyncDefaultDebounce` (400 ms).
_Injection R3-c :_ retirer le `_cancelPending()` du `_schedule` (pas de réarmement) → N timers **non annulés** `fire()` → `spy.syncCalls == N` ⇒ ROUGE. ⇒ la coalescence trailing N→1 est PROUVÉE (par compteur + fake clock, sans horloge murale).

**AC6 — Thread UI jamais bloqué : les déclencheurs retournent immédiatement ; un dépôt lent/qui throw ne se propage jamais synchroniquement.** _(garde non-blocage NFR-S9)_
`onLogin()`/`onReconnected()` sont **synchrones `void`** et retournent **avant** tout `await sync()` (le cycle est planifié via timer, exécuté `unawaited`). Un dépôt dont `sync()` est lent/throw **n'émet aucune exception** hors de `onLogin()`/`onReconnected()` (voie débouncée = fire-and-forget loggé, parité E5-4). `syncNow()` (voie awaitable explicite) reste `Right(report)` même si un dépôt throw.
_Test :_ `onLogin()` retourne sans attendre (un spy à `sync()` « pendante » ne bloque pas l'appelant) ; aucun `throw` ne franchit `onLogin()`/`onReconnected()` même avec `[boom]`.

**AC7 — `dispose` NON-propriétaire : l'orchestrateur assemblé vide son registre et annule le timer, mais NE dispose PAS les dépôts injectés (l'app en est propriétaire).** _(discriminant propriété AD-15)_
Étant donné `final o = assemble(repositories: [spy])`, quand `o.dispose()`, alors `o.registeredCount == 0` (registre vidé), un cycle ultérieur est inerte (`ZSyncRunReport.empty`, aucun `sync()`), **et** `spy.disposed == false` (le dépôt injecté n'est **pas** disposé). `dispose` est idempotent.
_Injection R3-d :_ faire `dispose()` itérer et appeler `repo.dispose()` sur le registre → `spy.disposed == true` ⇒ ROUGE. ⇒ la non-propriété des dépôts injectés est PROUVÉE.

**AC8 — Signatures NUES / AD-11 : aucun type backend n'apparaît dans la fabrique ni au barrel.**
`assembleZStudySyncOrchestrator` n'expose **aucun** type `cloud_firestore`/`hive` (`FirebaseFirestore`/`CollectionReference`/`Query`/`Timestamp`/`Box`/`HiveInterface`) : entrées = `Iterable<ZSyncableRepository<dynamic>>` + coutures du cœur (`Duration`, `ZSyncTimerFactory`, `Future<bool> Function()?`, `bool`, `ZSyncOrchestratorLog`) ; sortie = `ZSyncOrchestrator` (type du cœur). Le barrel `zcrud_firestore.dart` exporte la fabrique **sans** ré-exporter un type backend.
_Test :_ inspection statique (le barrel n'exporte aucun type backend ; la signature de la fabrique est nue) — parité de la garde d'isolation ES-3.2 (AC11).

**AC9 — Vérif verte REPO-WIDE (R9).**
`melos run generate` OK (**aucun nouveau `.g.dart`** attendu) → `melos run analyze` **RC=0** → `flutter test` de `zcrud_firestore` **RC=0** → `flutter test`/`dart test` de `zcrud_core` **RC=0** (dont `registerAll` + `domain_purity_test` verts) → `melos run test` **RC=0** → `dart run scripts/ci/gate_reserved_keys.dart` VERT (**inchangé**) → `dart run scripts/ci/gate_web_determinism.dart` VERT (`registerAll` pur-Dart web-safe ; `zcrud_firestore` **exclu**, Flutter) → `melos run verify` VERT (`codegen-distribution`, `graph_proof` **ACYCLIQUE + CORE OUT=0** — **aucune arête ajoutée** : `zcrud_firestore` dépend déjà de `zcrud_core`, `secrets`, `reflectable`).

---

## Tasks / Subtasks

- [x] **T1 — Micro-ajout ADDITIF `registerAll` dans `ZSyncOrchestrator` (D1).** (AC1, AC9)
  - [x] `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` : ajouté `void registerAll(Iterable<ZSyncableRepository<dynamic>> repos)` — **boucle `register(repo)`**, no-op après `dispose`. Dartdoc conforme. Constructeur/`register`/`unregister`/`_schedule`/`_runCycle`/`dispose` **inchangés** (`git diff` = seul l'ajout registerAll). PUR-DART.
  - [x] Export confirmé : `registerAll` visible via `package:zcrud_core/zcrud_core.dart` (orchestrateur exporté par `domain.dart:95`). Aucun ajout de barrel.

- [x] **T2 — Fabrique de câblage `assembleZStudySyncOrchestrator` (D2, AC2, AC3, AC8).**
  - [x] Créé `packages/zcrud_firestore/lib/src/data/z_study_sync_orchestrator.dart`. Corps : construit `ZSyncOrchestrator(...)`, `registerAll(repositories)`, retourne l'instance. Seul import = `package:zcrud_core/zcrud_core.dart` ; **aucun** repo concret importé/construit ; **aucun** type backend en signature.
  - [x] Dartdoc : remplaçant neutre de `study_sync_manager.dart` ; login/reconnexion pilotés par l'app (AD-15) ; best-effort + débounce hérités E5-4 (AD-4).

- [x] **T3 — Exporter la fabrique au barrel (AC2, AC8).**
  - [x] `export 'src/data/z_study_sync_orchestrator.dart';` ajouté dans `packages/zcrud_firestore/lib/zcrud_firestore.dart` (commentaire ES-3.4/FR-S15 ; signature NUE). Rien retiré.

- [x] **T4 — Tests core `registerAll` à pouvoir discriminant (R12).** (AC1)
  - [x] Group `registerAll (ES-3.4)` ajouté : `registeredCount==3` ; idempotence (re-appel + doublon dans la liste → 3) ; no-op après `dispose` (→ 0) ; cycle → chaque spy `syncCalls==1`. Helpers existants réutilisés.

- [x] **T5 — Tests fabrique `zcrud_firestore` à pouvoir discriminant (R12).** (AC2-AC8)
  - [x] Créé `packages/zcrud_firestore/test/z_study_sync_orchestrator_test.dart` (`flutter_test` ; `_SpyRepo`/`_PendingSpyRepo` comptant `sync()`/`disposed` ; `_FakeTimerFactory`/`_FakeTimer`). Aucun `fake_cloud_firestore`/Hive.
  - [x] Fixtures ISOLÉES par AC (AC2 tout-synchronisé ; AC3 signature `Iterable` + garde statique disque comments-stripped + import unique ; AC4 `[ok,boom,ok]` ; AC5 N→1 + `duration==D`/défaut 400 ms ; AC6 `onLogin` sync-void + `[boom]` sans throw ; AC7 `spy.disposed==false` ; AC8 sortie nue).
  - [x] Commentaires R3-a..R3-d dans les tests concernés.

- [x] **T6 — Rejouer les injections R3 (orchestrateur).** (AC1, AC2, AC4, AC5, AC7)
  - [x] R3-a/R3-b/R3-c/R3-d exécutées → ROUGE observé, **restaurées par édition ciblée** (`git diff z_sync_orchestrator.dart` = seul l'ajout registerAll). Messages rouges consignés dans Completion Notes.

- [x] **T7 — Vérif verte REPO-WIDE (R9).** (AC9)
  - [x] `melos run generate` (0 `.g.dart` neuf) → `melos run analyze` RC=0 → `flutter test` zcrud_firestore RC=0 (11) → `flutter test` zcrud_core RC=0 (931, dont registerAll) → `melos run test` RC=0 → gates (reserved-keys, web-determinism, graph ACYCLIQUE + CORE OUT=0, +7 gates chaîne verify) VERTS → `prove_gates` 41 OK.

---

## Dev Notes

### Patrons d'architecture & contraintes (AD)

- **AD-9 (offline-first best-effort, débounce ~400 ms)** — un dépôt déconnecté/en panne renvoie `Right(unit)` par son `sync()` ; l'orchestrateur ne remonte **jamais** de `Left` global (`syncNow → Right(report)`), un échec par-dépôt est **compté + loggé** sans arrêter les autres ; débounce coalesce les rafales login/reconnexion. [Source: `z_sync_orchestrator.dart:110,218-340` ; `z_syncable_repository.dart:30-39` ; lex `study_sync_manager.dart:55,86-124`]
- **AD-20 (aucune liste/chemin en dur ; générique IFFD↔lex)** — la liste de dépôts synchronisés vient d'une **injection** (`Iterable` passée à la fabrique), jamais d'imports codés en dur ; éradique `study_sync_manager.dart:9-19,98-112`. [Source: epics ES-3.4 l.564-568 ; architecture AD-20 l.221]
- **AD-4 (COMPOSE-not-DUPLICATE)** — l'orchestrateur E5-4 (débounce/best-effort/registre/gate/`dispose`) est **composé**, jamais recopié ; `registerAll` **boucle `register`** (ne duplique pas l'idempotence) ; la fabrique **compose** `ZSyncOrchestrator` (n'ajoute aucun état). [Source: `z_sync_orchestrator.dart` ; `z_study_repository.dart:22`]
- **AD-5 / AD-11 (backend-agnostique, `Either`/`Unit`, aucun try-catch nu)** — `sync(): Future<ZResult<Unit>>` ; `syncNow(): Future<ZResult<ZSyncRunReport>>` (`Right` même en échec partiel) ; aucune signature publique n'expose un type backend ; le best-effort par-dépôt isole chaque `sync()` (`try/catch` + garde `Left`, jamais `catch(_){}` muet). [Source: `z_sync_orchestrator.dart:243-340` ; `z_syncable_repository.dart`]
- **AD-1 / AD-17 (acyclique, CORE OUT=0)** — `registerAll` est PUR-DART (in `zcrud_core`, out-degree inchangé = 0) ; la fabrique vit dans `zcrud_firestore` qui **dépend déjà** de `zcrud_core` (**aucune arête ajoutée**) ; `graph_proof` inchangé sur les invariants. [Source: `scripts/dev/graph_proof.py:74-97` ; `packages/zcrud_firestore/pubspec.yaml`]
- **AD-15 (isolation gestionnaire d'état)** — **aucun** import Riverpod/GetX/provider/`firebase_auth`/`connectivity_plus` dans un package zcrud ; login/reconnexion pilotés par l'app via `onLogin()`/`onReconnected()` ; connectivité = couture `Future<bool> Function()?`. [Source: `z_sync_orchestrator.dart:31-40` ; CLAUDE.md Key Don'ts]
- **E5-4 (le *quand*)** — `register`/`unregister`/`onLogin`/`onReconnected`/`syncNow`/`flushPending`/`enabled`/`isConnected`/`dispose` non-propriétaire **déjà livrés** ; `registerAll` est le seul additif. [Source: `z_sync_orchestrator.dart:119-354` ; `e5-4-zsyncorchestrator.md`]
- **ES-3.1 / ES-3.2 (les repos orchestrés)** — `ZStudyRepository<T> extends ZSyncableRepository<T>` ; `ZOfflineFirstBoxRepository<T> extends ZStudyRepository<T>` ⇒ chacun **EST** un `ZSyncableRepository` `register`-able. [Source: `z_study_repository.dart:68-69` ; `z_offline_first_box_repository.dart`]

### Source tree — fichiers à toucher

- **UPDATE (additif)** `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` — ajouter `registerAll` (boucle `register`, PUR-DART). **Unique** édition de core.
- **UPDATE** `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart` — group `registerAll (ES-3.4)`.
- **NEW** `packages/zcrud_firestore/lib/src/data/z_study_sync_orchestrator.dart` — fabrique `assembleZStudySyncOrchestrator` (câblage liste injectée).
- **NEW** `packages/zcrud_firestore/test/z_study_sync_orchestrator_test.dart` — tests discriminants (spies + fake timer).
- **UPDATE** `packages/zcrud_firestore/lib/zcrud_firestore.dart` — `export` de la fabrique.
- **⛔ NE PAS TOUCHER** : `zcrud_study_kernel` (ports livrés — R9), `tool/reserved_keys_gate/**` (AC9/D3), tout `*.g.dart`, `z_offline_first_box_repository.dart` (ES-3.2) / `z_offline_first_repository.dart` (E5-3) / `z_firestore_cascade_batcher.dart` (ES-3.3), le sprint-status (orchestrateur). **NE PAS** modifier le constructeur/`register`/`_runCycle`/`dispose` de E5-4 (additif seulement).

### Fichiers UPDATE — état actuel & ce qui doit être préservé

- `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` : orchestrateur E5-4 complet (registre `Set` par identité l.167-186, débounce l.218-232, best-effort `_runCycle` l.283-340, `dispose` non-propriétaire l.349-354). **Préserver TOUT** ; **ajouter uniquement** `registerAll` (boucle `register`). Aucune signature existante modifiée. `pubspec.yaml` **inchangé**.
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` : barrel exportant E5 + ES-3.2/ES-3.3. **Préserver** tous les exports + le dartdoc d'isolation AD-5 ; **ajouter** une ligne `export` (commentaire ES-3.4/FR-S15). Ne rien retirer.
- `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart` : suite E5-4 (spies `_SpyRepo` l.55-85, `_FakeTimerFactory` l.36-46). **Préserver** ; **ajouter** un group `registerAll`. Réutiliser les helpers existants (ne pas re-déclarer `_SpyRepo`/`_FakeTimer`).

### Injections R3 prévues (à rejouer par l'orchestrateur, restaurées par édition ciblée)

- **R3-a** (AC1, AC2) : `registerAll` boucle → `register(repos.first)` (n'itère qu'un dépôt) → `registeredCount==1` / `spyB.syncCalls==0` → ROUGE (garde d'itération « aucun repo oublié »).
- **R3-b** (AC4) : `_runCycle` retire le `try/catch` par-dépôt / rethrow au 1er échec → `okB.syncCalls==0` ou `syncNow→Left`/throw → ROUGE (best-effort).
- **R3-c** (AC5) : `_schedule` retire `_cancelPending()` (pas de réarmement) → N timers `fire()` → `spy.syncCalls==N` → ROUGE (coalescence débounce).
- **R3-d** (AC7) : `dispose()` itère et `repo.dispose()` les dépôts injectés → `spy.disposed==true` → ROUGE (non-propriété).

### Testing standards

- `zcrud_firestore` = package **Flutter** ⇒ tests `flutter test` (VM). **Pas** de `@TestOn('vm')`, **pas** de run `-p node` (exclu de `gate_web_determinism`, D3). `zcrud_core` = **pur-Dart** ⇒ `registerAll` testé sous `dart test`/`flutter_test`, garde `domain_purity_test` VERTE (aucun import Flutter/backend introduit).
- **Fabrique de timer contrôlable OBLIGATOIRE** (`_FakeTimer`/`_FakeTimerFactory`) : **aucun `Timer` réel ni `Future.delayed`** dans la suite débounce (parité E5-4) ; le temps est piloté par `fire()`/`flushPending()`.
- **Spies comptant `sync()`** : la garde « liste injectée » et « best-effort » se prouvent par des **compteurs `syncCalls`** observés (jamais par l'existence de la fabrique — R12/DW-ES25-1). `_SpyRepo` doit lever `UnimplementedError` sur toute méthode ≠ `sync()`/`dispose()` (preuve que l'orchestrateur n'appelle QUE `sync()`).
- **Pas de test POWERLESS** : ne PAS « prouver » l'injection en lisant `registeredCount` seul sans déclencher un cycle réel (AC2 **doit** faire `onLogin()`+`flush` et compter les `sync()` de CHAQUE spy). Ne PAS « prouver » le best-effort par un chemin qui n'exécute pas le dépôt en panne.

### Points d'attention dev

1. **`registerAll` est STRICTEMENT additif** : boucle `register`, rien d'autre. Ne PAS toucher le constructeur/`_runCycle`/`dispose` — une seule story touche core, en additif (AD-4/R9).
2. **La fabrique ne détient AUCUN état** : c'est une fonction ; tout l'état (registre, débounce) vit dans le `ZSyncOrchestrator` retourné. Ne PAS créer une classe `ZStudySyncManager` (mini-orchestrateur concurrent).
3. **Aucun repo importé dans la fabrique** : la liste vient **exclusivement** du paramètre `repositories`. Ajouter un dépôt = passer une liste plus longue à l'appel (côté app), jamais éditer la fabrique (AC3 — l'anti-doublon).
4. **Login/reconnexion = app** : la fabrique **n'abonne rien** à `authStateChanges`/`connectivity_plus` (AD-15) ; l'app câble ses transitions sur `orchestrator.onLogin()`/`onReconnected()`. La connectivité optionnelle passe par la couture `isConnected` (déjà E5-4).
5. **`syncNow` vs voie débouncée** : `syncNow()` (awaitable, `Right(report)`) sert aux tests/login-forcé ; la voie `onLogin`/`onReconnected` est fire-and-forget loggée (non bloquante — AC6). Ne pas confondre.
6. **Aucun `.g.dart` neuf** : `registerAll`/la fabrique sont du code plain (aucun `@ZcrudModel`) ⇒ `melos run generate` ne produit rien de nouveau ; `gate_reserved_keys` reste VERT sans toucher `tool/reserved_keys_gate/**`.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-3.4` (l.556-572), FR-S15 (l.119), objectif ES-3 (l.485-487)]
- [Source: architecture `architecture-zcrud-study-2026-07-12/architecture.md#AD-20` (l.218-221 : « `ZSyncOrchestrator` (E5) paramétré par une liste injectée… best-effort… débounce ~400 ms »), AD-9 (l.48)]
- [Source: `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` — E5-4 : registre (l.167-186), débounce/coalescence (l.108-110, 218-232), best-effort `_runCycle` (l.283-340), `syncNow` (l.243-246), `dispose` non-propriétaire (l.349-354), coutures timer (l.78-106)]
- [Source: `packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart` — sur-port `sync(): Future<ZResult<Unit>>`, best-effort `Right(unit)` offline]
- [Source: `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart` — `_SpyRepo` (l.55-85), `_FakeTimer`/`_FakeTimerFactory` (l.19-46), `_LogSink` (l.89+)]
- [Source: `es-3-1-depot-etude-generique.md` — `ZStudyRepository<T> extends ZSyncableRepository<T>` (Template Method save→validate→persist)]
- [Source: `es-3-2-helper-offline-first-path-resolver.md` — `ZOfflineFirstBoxRepository<T>` = les repos concrets orchestrés ; D9 `zcrud_firestore` Flutter hors gate:web ; barrel isolation AD-5]
- [Source: lex `/home/zakarius/DEV/lex_douane/packages/lex_data/lib/data/services/study_sync_manager.dart` — DOUBLON à paramétrer : imports en dur (l.9-19), liste `_syncAll` 11 repos (l.98-112), débounce 400 ms (l.55,81-84), best-effort (l.86-124), couplage Riverpod/firebase_auth/connectivity_plus (l.3,50,65-78)]
- [Source: `scripts/dev/graph_proof.py:74-97` (acyclicité + CORE OUT=0) ; `scripts/ci/gate_web_determinism.dart` (packages Flutter exclus) ; `gate_reserved_keys.dart`]
- [Source: `epic-es-2-retrospective.md` — R2 (fixture d'échec isolée), R9 (vérif REPO-WIDE), R10 (garde dérivée du disque), R12 (test POWERLESS), R13 (édition ciblée) ; DW-ES25-1]

### Project Structure Notes

- Chemins conformes : fabrique sous `packages/zcrud_firestore/lib/src/data/z_study_sync_orchestrator.dart` (adapters), test sous `packages/zcrud_firestore/test/`, additif core sous `packages/zcrud_core/lib/src/domain/sync/`. Nommage `Z…`/`assembleZ…`, snake_case, tests `*_test.dart`. Aucune variance détectée.
- **Aucune arête de graphe ajoutée** : `zcrud_firestore → zcrud_core` existe déjà (E5) ; `registerAll` reste dans `zcrud_core` (out-degree 0). `graph_proof` inchangé.

### Dépendances / dettes

- **Dépend de** ES-3.1 (port `ZStudyRepository<T>`) et **ES-3.2** (`ZOfflineFirstBoxRepository<T>` = les repos concrets à orchestrer) — l'orchestrateur ne fait que `register`/`sync()` ces `ZSyncableRepository`. Statuts amont à confirmer **`done` et verts** sur disque par l'orchestrateur avant le `dev-story`.
- **Aval** : `ES-3.5` (codec camelCase↔snake_case IFFD legacy + gate CI rétro-compat) — indépendant de cette story.
- **DW-ES25-1** (rappel, **NON traité ici**) : spike R4 des VO-à-invariant (garde de surface machine) — séparé, non bloquant (rétro ES-2). ES-3.4 ne l'ouvre pas.
- **DW-ES32-1** (rappel, **NON traité ici**) : normalisation `Timestamp` méta de `_decodeCloud` — HORS-SYSTÈME, à solder seulement si un writer tiers `Timestamp` est introduit (ES-3.5). ES-3.4 ne le touche pas.
- **DW-ES33-1** (rappel, **NON traité ici**) : placement physique des const d'arêtes de cascade dans les packages propriétaires + composition unique par `zcrud_study` (créé en ES-5) — aval, non bloquant. ES-3.4 ne le touche pas.
- **Dette possible (à consigner si rencontrée, pas à imposer)** : si l'app nécessite un pont `onLogin`/`onReconnected` réutilisable (au-delà de la simple fabrique), le NOTER comme candidat binding `zcrud_riverpod`/`zcrud_get` (FR-S33/FR-S34, aval) — **hors** périmètre « zcrud_firestore + additif core ».

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

Vérif verte REPO-WIDE rejouée réellement sur disque (RC observés) :

| Étape | Commande | Résultat |
|-------|----------|----------|
| Codegen | `dart run melos run generate` | SUCCESS · **0 `.g.dart` neuf** (aucun `@ZcrudModel` ajouté) |
| Analyze repo-wide | `dart run melos run analyze` | RC=0 · No issues found (tous packages) |
| Test core | `flutter test` zcrud_core | RC=0 · **931 passed** (dont group `registerAll (ES-3.4)`) |
| Test firestore | `flutter test` zcrud_firestore/z_study_sync_orchestrator_test.dart | RC=0 · **11 passed** |
| Test repo-wide | `dart run melos run test` | RC=0 · All tests passed (tous packages SUCCESS) |
| Gate reserved-keys | `gate_reserved_keys.dart` | RC=0 · VERT (inchangé, aucune édition `tool/reserved_keys_gate/**`) |
| Gate web-determinism | `gate_web_determinism.dart` | RC=0 · VERT (`registerAll` pur-Dart web-safe ; firestore Flutter exclu) |
| Graph proof | `graph_proof.py` | RC=0 · **ACYCLIQUE OK · CORE OUT=0 OK** · 34 arêtes (INCHANGÉ, aucune arête ajoutée) |
| prove_gates | `prove_gates.dart` | RC=0 · **41 OK, 0 FAIL** |
| Gates chaîne verify | melos-divergence, reflectable, secret-scan, codegen, codegen-distribution, compat-resolution, verify:serialization | tous RC=0 · VERTS |

Note : `melos run verify` (chaîne unique) dépasse 2 min de wall-clock (web-determinism `dart test -p node` recompile) ; les **10 gates** de la chaîne ont été rejoués **individuellement** verts (équivalent au STEP unique CI).

### Completion Notes

Story ES-3.4 implémentée en composant (AD-4) l'orchestrateur E5-4 sans le ré-implémenter.

**Conception :**
- **D1 — `registerAll` additif dans `zcrud_core`** : `void registerAll(Iterable<ZSyncableRepository<dynamic>> repos)` = simple **boucle `register(repo)`** (idempotence par identité + no-op après `dispose` hérités). `git diff z_sync_orchestrator.dart` = **exclusivement** cet ajout — constructeur/`register`/`unregister`/`_schedule`/`_runCycle`/`dispose` **octet-pour-octet inchangés**. PUR-DART (aucun import Flutter/backend).
- **D2 — Fabrique `assembleZStudySyncOrchestrator` dans `zcrud_firestore`** : fonction sans état (le remplaçant neutre de `study_sync_manager.dart`). Reçoit la **liste injectée** `repositories`, construit `ZSyncOrchestrator(debounce, timerFactory, isConnected, enabled, logger)`, appelle `registerAll(repositories)`, retourne l'instance. **Aucun** repo concret importé/construit (seul import = `package:zcrud_core/zcrud_core.dart`) ; **aucun** Riverpod/firebase_auth/connectivity_plus ; signature NUE (sortie = type du cœur `ZSyncOrchestrator`). Login/reconnexion = l'app appelle `onLogin()`/`onReconnected()` (AD-15).

**Pouvoir discriminant (R12) — les 4 injections R3 exécutées RÉELLEMENT, message ROUGE EXACT capturé, puis restaurées par édition ciblée (diff vide) :**
- **R3-a** (`registerAll` boucle → `register(repos.first)`) → core `registeredCount` `Expected: <3> / Actual: <1>` + cycle spy `Expected: <1> / Actual: <0>` ; firestore AC2 `Expected: <3> / Actual: <1>`. ⇒ garde d'itération « aucun repo oublié » LOAD-BEARING.
- **R3-b** (`_runCycle` per-repo `catch` → `rethrow` au 1er échec) → firestore AC4 `Bad state: boom` (StateError échappe, `syncNow` throw au lieu de `Right`, `okB` jamais atteint). ⇒ best-effort tolérant à l'échec partiel LOAD-BEARING.
- **R3-c** (`_schedule` sans `_cancelPending()`) → firestore AC5 `created[0].isCancelled` `Expected: true / Actual: <false>` (timers non réarmés). ⇒ coalescence trailing N→1 LOAD-BEARING.
- **R3-d** (`dispose()` itère et `repo.dispose()` le registre) → firestore AC7 `spy.disposed` `Expected: false / Actual: <true>`. ⇒ non-propriété des dépôts injectés LOAD-BEARING.

**Invariants tenus :** AD-1/AD-17 (graphe INCHANGÉ, aucune arête ajoutée, CORE OUT=0), AD-4 (compose, pas de duplication), AD-5/AD-11 (signatures nues, `Either`/`Unit`, aucun try-catch nu), AD-9 (best-effort + débounce 400 ms), AD-15 (aucun gestionnaire d'état/backend concret). `zcrud_study_kernel`, `tool/reserved_keys_gate/**`, tout `.g.dart` et le sprint-status : **intouchés**.

### File List

- **UPDATE (additif)** `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` (ajout `registerAll`)
- **UPDATE** `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart` (group `registerAll (ES-3.4)`)
- **NEW** `packages/zcrud_firestore/lib/src/data/z_study_sync_orchestrator.dart` (fabrique `assembleZStudySyncOrchestrator`)
- **NEW** `packages/zcrud_firestore/test/z_study_sync_orchestrator_test.dart` (tests discriminants spies + fake timer)
- **UPDATE** `packages/zcrud_firestore/lib/zcrud_firestore.dart` (export de la fabrique)
