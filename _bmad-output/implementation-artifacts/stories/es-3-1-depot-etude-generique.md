# Story ES-3.1: Dépôt d'étude générique (`ZStudyRepository<T>`)

Status: review

<!-- Epic ES-3 : Ports & couche data offline-first bi-topologie. -->
<!-- FR-S12 · AD-5/AD-11/AD-9/AD-16/AD-14/AD-1 · SM-S5. Dépend d'ES-3.0 (done). -->
<!-- SÉQUENTIELLE : écrit `zcrud_study_kernel` (PORT). Ne touche PAS `zcrud_core`, ni `zcrud_firestore` (= ES-3.2), ni le sprint-status. -->

## Story

As a **développeur intégrateur** (qui s'apprête à câbler le premier store offline-first d'étude en ES-3.2, puis à porter les ~15 repos lex/IFFD),
I want **un contrat de dépôt d'étude générique `ZStudyRepository<T>` dans `zcrud_study_kernel` — flux nu `Stream<List<T>>`, opérations `Either<ZFailure,·>` héritées des ports `zcrud_core`, PLUS un hook de validation métier par _override_ garanti d'être exécuté avant toute persistance**,
so that **consommer/fournir le même CRUD offline-first sans le dupliquer 15×, avec les invariants métier (hiérarchie 2 niveaux des dossiers, matérialisation éphémère des flashcards, cible requise) branchables par override — et qu'un override qui REJETTE bloque RÉELLEMENT l'écriture (pas un hook décoratif ignorable)**.

---

## Contexte & problème mesuré

### Le doublon à factoriser (origine lex)

lex_core porte **~15 repositories quasi identiques** (`FlashcardsRepository`, `StudyFoldersRepository`, `RepetitionRepository`, `SmartNotesRepository`, `MindmapsRepository`, `StudyDocumentsRepository`, `DocumentAnnotationsRepository`, `ExamsRepository`, `PodcastRepository`, …). Chacun redéclare la **même forme** :
- un flux nu `Stream<List<T>>` (nommé au cas par cas `dataChanges` / `foldersStream` / `repetitionsStream` / `cardsStream`) ;
- `get*`/`save`/`delete`/`sync` en `Either<Failure,·>` (jamais un flux enveloppé) ;
- des **invariants métier inlinés dans chaque `save*`** — jamais factorisés. Exemples MESURÉS sur disque lex :
  - `study_folders_repository_impl.dart:141-165` — invariant « 2 niveaux max » : un `parentId` dont le parent a lui-même un parent → `Left(DomainFailure(...))` ; un dossier ayant déjà des sous-dossiers ne peut devenir sous-dossier → `Left(DomainFailure(...))`. **La validation est écrite AVANT toute écriture Hive/Firestore, et un `Left` court-circuite l'écriture.**
  - `flashcards_repository.dart:14-20` (dartdoc) + impl — matérialisation de l'éphémère : `card.isEphemeral` reçoit un `id`/`folderId` cible **avant** écriture ; une carte éphémère **sans dossier cible** → `Left(DomainFailure)`.

Ces invariants sont **le point de FR-S12** : le contrat générique doit **prévoir un hook overridable** où chaque agrégat branche SA règle, au lieu de la ré-inliner dans chaque impl.

### Ce qui existe déjà dans `zcrud_core` (À COMPOSER, PAS À DUPLIQUER — AD-4, R-G)

ES-3.1 **compose** avec les ports déjà livrés — elle n'en réécrit AUCUNE méthode :

- `ZRepository<T extends ZEntity>` (`packages/zcrud_core/lib/src/domain/ports/z_repository.dart`) : `Stream<List<T>> watchAll()` / `watch(request)` **NUS** ; `Future<ZResult<List<T>>> getAll({request})` ; `Future<ZResult<T>> getById(String id)` ; `Future<ZResult<T>> save(T item, {String? collectionId})` ; `Future<ZResult<Unit>> softDelete(String id)` ; `restore(String id)` ; `Future<ZResult<int>> count({request})` ; `void dispose()`. **`watchAll()` EST le `dataChanges` canonique** (dartdoc l.35-40 : « Équivalent du `dataChanges` canonique »).
- `ZSyncableRepository<T> extends ZRepository<T>` (`.../ports/z_syncable_repository.dart`) : ajoute `Future<ZResult<Unit>> sync()` (pull + merge LWW borné ; `Right(unit)` si déconnecté ; `Left(CacheFailure)` sur panne locale).
- `ZResult<T> = Either<ZFailure, T>` + hiérarchie `ZFailure` (`DomainFailure`/`CacheFailure`/`NotFoundFailure`/`ServerFailure`) — `.../failures/z_failure.dart`.
- `ZEntity` (`id: String?` opaque, `isEphemeral`) — `.../contracts/z_entity.dart`.
- `ZSyncable` (clé LWW **lisible** `updatedAt`, **jamais** l'autorité de merge — AD-19) — `.../contracts/z_syncable.dart`.
- `ZDataRequest` (pagination **curseur** neutre) — `.../data/z_data_request.dart`.

> **`ZStudyRepository<T>` n'ajoute donc QU'UNE chose au-dessus de `ZSyncableRepository<T>` : le _hook de validation métier par override_, garanti d'être exécuté avant `save`.** Tout le reste (flux nus, `Either`, `sync`, curseur) est **hérité**.

### Le piège à contrer (motif dominant du projet — R12/DW-ES25-1)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Le risque spécifique de CETTE story : livrer un hook `validate(T)` **décoratif** — une méthode overridable que **rien n'oblige `save` à appeler**. Un tel hook passerait tous les tests d'« existence » (« la méthode est là, elle est overridable, le défaut renvoie succès ») **tout en étant totalement ignorable** par une impl : un override qui rejette laisserait quand même passer l'écriture. Ce serait le jumeau exact du **test AC13 POWERLESS d'ES-2.5** (finding retro §9) : un filet qui « prouve » par un chemin qui ne dépend pas de ce qu'il garde.

**Contre-mesure structurante (voir Décision D1 ci-dessous)** : le port n'expose pas un hook nu ; il expose un **patron Template Method** — `save` est **concret et non-overridable par contrat**, il appelle `validate(item)` PUIS, seulement si `Right`, l'écriture protégée abstraite `persist(item)`. Ainsi un override de `validate` qui renvoie `Left` **empêche mécaniquement** l'appel à `persist` — **prouvable dans le kernel SANS aucun store** (fake `persist`-espion). Retirer l'appel `validate(...)` du template fait **ROUGIR** le test discriminant. C'est le cœur de la valeur d'ES-3.1.

### Ce que cette story NE fait PAS

- **Aucun câblage de store / adapter** : `ZOfflineFirstBoxRepository<T>` + `ZFirestorePathResolver` = **ES-3.2** (`zcrud_firestore`). ES-3.1 ne fournit **aucune** implémentation persistante concrète (au plus une `_Fake` de test in-memory pour le pouvoir discriminant).
- **Aucune cascade de suppression** (= ES-3.3), **aucun orchestrateur** (= ES-3.4), **aucun mapping legacy IFFD** (DW-ES21-1 = ES-3.5).
- **Aucune écriture de `zcrud_core`** (les ports y sont déjà — R9 : le kernel est le seul point de contact ; ES-3.1 reste strictement dans `zcrud_study_kernel`).
- **Ne rouvre pas DW-ES25-1** (spike R4 des VO-à-invariant : séparé, non bloquant).

---

## Décisions structurantes (tranchées par lecture lex + AD + R-G)

**D1 — `ZStudyRepository<T>` = classe abstraite à _Template Method_, PAS un validateur injecté.**
L'épic dit littéralement « hook de validation métier **par override** » (epics.md l.492, l.499). Le mot _override_ désigne le patron **méthode overridable**, pas une composition d'un collaborateur injecté au constructeur. AD-4 privilégie la composition **pour les classes SÉRIALISÉES** (héritage de modèles rejeté) — `ZStudyRepository<T>` est un **PORT de comportement**, pas un modèle sérialisé : le Template Method (GoF) y est idiomatique et **AD-4-safe** (generics autorisés pour un PORT ; interdits pour la sérialisation). **Rejeté : validateur injecté** (`ZStudyValidator<T>` passé au ctor) → n'aurait aucun POUVOIR DISCRIMINANT testable dans ce story (le port ne garantirait pas son appel), reproduisant le hook décoratif (R12). **Rejeté : hook nu overridable sans template `save`** → même défaut (rien ne force l'appel).

**D2 — `save` est un Template Method concret ; `persist` est le nouveau point d'extension abstrait.**
```
abstract class ZStudyRepository<T extends ZEntity> extends ZSyncableRepository<T> {
  /// Hook métier OVERRIDABLE. Défaut = no-op succès (right(unit)). PUR, TOTAL,
  /// déterministe. Appelé par [save] AVANT [persist]. Un Left BLOQUE l'écriture.
  ZResult<Unit> validate(T item) => right(unit);

  /// Écriture protégée réelle (Hive/merge/Firestore) — implémentée par l'adapter
  /// offline-first (ES-3.2). JAMAIS appelée si [validate] renvoie Left.
  @protected
  Future<ZResult<T>> persist(T item, {String? collectionId});

  /// TEMPLATE (non overridable par contrat) : valide PUIS persiste.
  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) async =>
      validate(item).fold(
        (f) async => left<ZFailure, T>(f),
        (_) => persist(item, collectionId: collectionId),
      );
}
```
`save` **override** la déclaration abstraite héritée de `ZRepository` — une sous-classe fournit un corps concret d'une méthode héritée abstraite (légal). `persist` devient l'unique point d'écriture que l'adapter ES-3.2 implémente. `@protected` (package `meta`, déjà transitif) documente que `persist` n'est pas de la surface publique consommateur.

**D3 — `Either<ZFailure,·>` sur TOUTES les opérations ; flux `Stream<List<T>>` NUS ; `validate → ZResult<Unit>`.** (AD-5/AD-11). Aucune méthode ne renvoie un `Stream` enveloppé dans un `Either`. `validate` renvoie `ZResult<Unit>` (`right(unit)` succès / `Left(DomainFailure)` rejet) — cohérent avec le retour de `save`/`softDelete`.

**D4 — Réconciliation du nom `dataChanges` : PAS de doublon.** L'AC épic exige « expose `dataChanges: Stream<List<T>>` nu ». Cette exigence est **déjà satisfaite** par `watchAll()` hérité (« équivalent du `dataChanges` canonique », dartdoc `z_repository.dart` l.37). ⇒ **NE PAS** ajouter un getter `dataChanges` redondant (dupliquerait la surface core — viole AD-4 « COMPOSE, ne DUPLIQUE pas »). La dartdoc de `ZStudyRepository` **documente explicitement** que `watchAll()` EST le `dataChanges`/`foldersStream`/`repetitionsStream` des ~15 repos lex, unifiés. (Point d'attention : l'AC de vérification porte sur l'EXISTENCE d'un flux nu hérité, pas sur un membre nommé `dataChanges`.)

**D5 — Le port vit dans `zcrud_study_kernel`, PAS dans `zcrud_core`.** Fixé par l'épic (chemin `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart`). Cohérent avec AD-1 : `ZRepository`/`ZSyncableRepository` **génériques** vivent au cœur ; `ZStudyRepository` est la **spécialisation _étude_** (hook métier d'étude) → au kernel, qui dépend UNIQUEMENT de `zcrud_core`. Le kernel **ne gagne AUCUNE arête sortante** vers un satellite (`zcrud_firestore`/`zcrud_flashcard`) : CORE OUT=0 et acyclicité préservés (le port ne référence que `zcrud_core`).

**D6 — Aucune entité `@ZcrudModel`, donc AUCUN câblage du gate `reserved-keys` (anti-inertie R3, précédent ES-2.7/AC14).** `ZStudyRepository<T>` est un **PORT abstrait** : pas de `@ZcrudModel`, pas de `@JsonSerializable`, pas de `.g.dart`, pas de `registerZ…`. ⇒ **NE PAS toucher** `tool/reserved_keys_gate/**`. Prouvé, pas supposé (AC dédié).

**D7 — Propagation du `hide` de surface (D3/ES-1.2, gate `z_kernel_surface_guard_test.dart`).** Tout nouveau symbole public du barrel kernel qui n'est **pas** pertinent flashcard doit être **classé** (ajouté au `hide` de `zcrud_flashcard` OU à l'allowlist du guard), sinon `z_kernel_surface_guard_test.dart` ÉCHOUE (anti-fuite silencieuse). `ZStudyRepository` est un **port data générique** (pas la surface flashcard historique) ⇒ à **ajouter à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`. (Symbole unique : `persist`/`validate` sont des membres, pas des top-level ; seul `ZStudyRepository` est exporté.)

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (R12) : le test associé doit **ROUGIR par le retrait de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli, un import interne, ou une coïncidence de valeur. L'orchestrateur **rejoue chaque injection R3** (retirer la garde → ROUGE **par cette garde**), et **restaure par édition ciblée** (`diff` vide — R13, JAMAIS `git checkout`).

**AC1 — Le port existe, est générique sur `ZEntity`, et hérite de `ZSyncableRepository`.**
`ZStudyRepository<T extends ZEntity> extends ZSyncableRepository<T>` est déclaré dans `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` et exporté par le barrel `zcrud_study_kernel.dart`. Il **n'ajoute AUCUNE re-déclaration** des membres hérités (`watchAll`/`watch`/`getAll`/`getById`/`softDelete`/`restore`/`count`/`sync`/`dispose`) — vérifiable : la surface publique héritée reste intacte, seuls `validate`, `persist` et l'override `save` sont propres à ce port.
_Test :_ un `_Fake extends ZStudyRepository<_FakeEntity>` compile en n'implémentant QUE `persist` (+ les flux/getters hérités abstraits) et expose `watchAll()`/`sync()` sans redéclaration.

**AC2 — `save` est un Template Method : `validate` PUIS `persist` ; un `validate → Left` BLOQUE `persist`.** _(cœur discriminant)_
Étant donné un `ZStudyRepository` dont `validate` est overridé pour renvoyer `Left(DomainFailure('rejet'))`, quand on appelle `save(item)`, alors :
1. le résultat est `Left(DomainFailure('rejet'))` (le rejet exact remonte, non avalé, non transformé) ;
2. **`persist` n'est JAMAIS appelé** (prouvé par un espion : compteur d'appels `persist` == 0).
_Injection R3 :_ retirer/neutraliser l'appel `validate(item)` dans le template `save` (le rendre inconditionnellement `persist(...)`) fait **ROUGIR** ce test (persist appelé + `Right` remonté). ⇒ pouvoir discriminant PROUVÉ : un hook décoratif serait attrapé.

**AC3 — `validate → Right(unit)` laisse `save` persister ; défaut = no-op succès.**
Étant donné un `ZStudyRepository` **sans** override de `validate` (défaut), quand on appelle `save(item)`, alors `validate` renvoie `right(unit)`, `persist` **est** appelé exactement une fois avec `item` (et `collectionId` threadé tel quel), et le `Right(T)` de `persist` remonte inchangé. Le défaut `validate` est **PUR/TOTAL/déterministe** (aucune I/O, aucun `DateTime.now()`, aucune exception).
_Test discriminant :_ deux appels successifs avec le même `item` produisent le même verdict de `validate` (déterminisme) ; `persist` reçoit le `collectionId` fourni.

**AC4 — Un override réaliste d'invariant métier bloque l'écriture (fixture d'échec ISOLÉE — R2).**
Un `ZStudyRepository` de test réimplémente l'invariant lex « 2 niveaux max » dans `validate` (ex. `item.parentId != null && parentHasParent → Left(DomainFailure)`), reproduisant `study_folders_repository_impl.dart:141-165`. Étant donné un item violant l'invariant, `save` renvoie `Left(DomainFailure)` et n'écrit pas ; étant donné un item conforme, `save` persiste. **Chaque cas (rejet / acceptation) est une fixture isolée**, pas un test unique multi-assert.

**AC5 — Contrat de matérialisation éphémère ADMIS par le port (documenté, non implémenté ici).**
La dartdoc de `save`/`validate` documente que la **matérialisation de l'éphémère** (`item.isEphemeral` → attribution d'`id` par l'impl) et le **rejet d'une cible manquante** (`Left(DomainFailure)`) sont portés par `persist`/`validate` de l'adapter (ES-3.2, précédent `flashcards_repository.dart`), **jamais** par l'entité. Le port **admet** ce contrat sans le figer (aucun `id` généré dans le kernel).
_Test :_ un `_Fake` peut matérialiser dans `persist` (assigner un `id`) et rejeter dans `validate` une cible manquante — le port ne l'empêche ni ne l'impose.

**AC6 — Flux NUS, `Either` partout, `sync` best-effort (AD-5/AD-11/AD-9) — hérités, non enveloppés.**
Le port n'expose **aucun** `Stream` enveloppé dans un `Either` (les flux `watchAll()`/`watch()` restent `Stream<List<T>>` NUS, hérités) et **aucune** opération non-flux qui ne renvoie pas un `ZResult<·>` (`Future<ZResult<T>>`/`Future<ZResult<Unit>>`/`Future<ZResult<int>>`). `sync()` reste hérité tel quel (best-effort AD-9).
_Test discriminant :_ un test de type/signature (miroir statique via un `_Fake`) affirme `watchAll` retourne `Stream<List<T>>` (non `Stream<Either<...>>`) et que `save`/`validate` retournent des `Either`.

**AC7 — Backend-agnostique : ZÉRO type backend dans le fichier port (NFR-S3/SM-S5).**
`z_study_repository.dart` ne contient **aucun** `Timestamp`, `Filter`, `Box`, `WriteBatch`, `DocumentSnapshot`, `Color`, `IconData`, `Colors`, ni import de `cloud_firestore`/`hive`/`flutter`/`dart:ui`. Couvert **automatiquement et de façon dérivée du disque (R10)** par `z_kernel_purity_test.dart` (il scanne **TOUT** `lib/**/*.dart` du kernel, code compris — pas une allowlist artisanale).
_Injection R3 :_ introduire un token interdit (ex. `// Color(` → `Color(` réel, ou `import 'package:cloud_firestore/...'`) fait ROUGIR `z_kernel_purity_test.dart` (scan) **et** `analyze` (import interdit — le kernel ne dépend pas de Flutter/Firebase). Restauration par édition ciblée (`diff` vide).

**AC8 — Acyclicité / CORE OUT=0 préservés : le kernel ne gagne AUCUNE arête sortante.**
Le port n'importe que des symboles de `package:zcrud_core/…` (`ZEntity`, `ZResult`/`ZFailure`, `ZSyncableRepository`, `ZDataRequest` si utile) + `package:meta` (`@protected`) + `package:dartz` (`Unit`/`right`/`left`, déjà dep transitive via core). **Aucun** import d'un satellite (`zcrud_firestore`/`zcrud_flashcard`/`zcrud_document`/…).
_Vérif :_ `z_kernel_resolution_test.dart` (fermeture transitive `zcrud_*` ⊆ `{zcrud_core, zcrud_annotations}`) reste VERT **inchangé** ; `melos run verify` (`graph_proof`/acyclicité) VERT ; `dart pub deps` du kernel n'ajoute aucune arête.

**AC9 — Anti-inertie du gate `reserved-keys` PROUVÉE (D6, R3, précédent ES-2.7/AC14).**
Aucun livrable n'est un `@ZcrudModel` ⇒ **aucun** `registerZ…` généré, **aucun** nouveau `.g.dart` sous `packages/zcrud_study_kernel/lib/`, **aucune** entrée à ajouter dans `tool/reserved_keys_gate/lib/src/registrars.dart`. `dart run scripts/ci/gate_reserved_keys.dart` reste **VERT sans aucune modification du gate**. `git status` ne montre **aucun** nouveau `.g.dart` du kernel. **⛔ NE PAS toucher `tool/reserved_keys_gate/**`.**
_Filet automatique :_ si un `@ZcrudModel` s'était glissé, un `registerZ…` apparaîtrait sur disque et le gate ROUGIRAIT (`R_disk \ R_wired ≠ ∅`).

**AC10 — Propagation du `hide` de surface : `z_kernel_surface_guard_test.dart` reste VERT (D7).**
`ZStudyRepository` est ajouté au bon versant du guard (liste `hide` de `zcrud_flashcard` — c'est un port data générique, hors surface flashcard historique). `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` reste VERT (symbole **classé**, pas de fuite silencieuse ni de surface flashcard cassée).
_Test discriminant (existant) :_ oublier de classer `ZStudyRepository` fait ÉCHOUER le guard (symbole kernel non classé) — filet outillé déjà en place.

**AC11 — Déterminisme web (gate:web) : les tests du port tournent sous VM ET node.**
Le test du port (`z_study_repository_test.dart`) est **pur Dart, web-safe** (aucun `dart:io`, aucun `@TestOn('vm')`) : il s'exécute sous `dart test` **et** `dart test -p node` (RC=0). `dart run scripts/ci/gate_web_determinism.dart` reste VERT.

**AC12 — Vérif verte REPO-WIDE (R9).**
`melos run generate` OK (**aucun nouveau `.g.dart`** attendu) → `melos run analyze` **RC=0** → `melos run test` **RC=0** → `dart test` de `zcrud_study_kernel` (VM) **et** `dart test -p node` (JS) **RC=0** → `dart run scripts/ci/gate_reserved_keys.dart` VERT (**inchangé**) → `dart run scripts/ci/gate_web_determinism.dart` VERT → `melos run verify` (`codegen-distribution`, `graph_proof`/acyclicité **CORE OUT=0**, `secrets`) VERT.

---

## Tasks / Subtasks

- [x] **T1 — Écrire le port `ZStudyRepository<T>` (Template Method).** (AC1, AC2, AC3, AC5, AC6, D1-D5)
  - [x] Créer `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` : `abstract class ZStudyRepository<T extends ZEntity> extends ZSyncableRepository<T>`.
  - [x] `ZResult<Unit> validate(T item) => const Right<ZFailure, Unit>(unit);` — dartdoc : PUR/TOTAL/déterministe, no-op par défaut, appelé AVANT `persist`, un `Left` bloque l'écriture. **R-G** : `right(unit)` (fonction dartz) N'EST PAS exportée par `package:zcrud_core/domain.dart` (seul `show Either, Left, Right, Unit, unit`) ; on utilise le **constructeur** `Right<ZFailure,Unit>(unit)` — idiome EXACT du précédent `z_study_folder_hierarchy.dart`.
  - [x] `@protected Future<ZResult<T>> persist(T item, {String? collectionId});` — abstrait, point d'extension ES-3.2.
  - [x] `@override Future<ZResult<T>> save(...)` concret = `validate(item).fold((f) => Future.value(Left(f)), (_) => persist(...))` (thread `collectionId`).
  - [x] Dartdoc en-tête : origine lex (~15 repos), réconciliation `dataChanges`↔`watchAll()` (D4), contrat de matérialisation éphémère admis (AC5), COMPOSE-not-DUPLICATE (AD-4), backend-agnostique (AD-5/AD-11).
  - [x] Imports **minimaux** : `package:zcrud_core/domain.dart` + `package:meta/meta.dart` (`@protected`). **R-G** : `package:dartz/dartz.dart` NON importé directement (tout — `ZResult`/`ZFailure`/`Unit`/`unit`/`Left`/`Right`/`ZEntity`/`ZSyncableRepository` — vient du seul barrel `domain.dart`, évitant `depend_on_referenced_packages`). `meta` ajouté en dép directe (léger, pur-Dart, sans effet sur la fermeture transitive du gate de résolution).
- [x] **T2 — Exporter le port + propager le `hide` de surface.** (AC1, AC10, D7)
  - [x] `export 'src/domain/z_study_repository.dart';` dans `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (commentaire ES-3.1/FR-S12 ; placé alphabétiquement entre `z_study_podcast` et `z_study_session_config` pour `directives_ordering`).
  - [x] Ajouter `ZStudyRepository` à la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (port data générique, hors surface flashcard) ; `z_kernel_surface_guard_test.dart` VERT (5/5).
- [x] **T3 — Test à pouvoir discriminant du Template Method.** (AC2, AC3, AC4, AC5, AC6, R2, R12)
  - [x] Créer `packages/zcrud_study_kernel/test/z_study_repository_test.dart` (pur Dart, web-safe, PAS de `@TestOn('vm')`).
  - [x] `_FakeEntity implements ZEntity` (id opaque) ; `_SpyRepo extends ZStudyRepository<_FakeEntity>` avec `persist` **espion** (compteur d'appels + capture args) + flux/getters hérités stubés minimalement.
  - [x] Fixtures ISOLÉES : (a) `validate→Left` ⇒ `save` = ce `Left`, `persist` count==0 ; (b) `validate` défaut ⇒ `persist` count==1, `collectionId` threadé, `Right` remonté ; (c) override « 2 niveaux max » réaliste (rejet + acceptation, cas séparés) ; (d) déterminisme du défaut ; (e) miroir de type flux NU / `Either`. **10 tests, VM + node.**
  - [x] Commentaire R3 dans le test : « retirer l'appel `validate` du template `save` fait ROUGIR (a) — pouvoir discriminant ».
- [x] **T4 — Vérifs de garde dérivées du disque (R10) — confirmer VERTES sans câblage.** (AC7, AC8, AC9, AC11)
  - [x] `z_kernel_purity_test.dart` scanne le nouveau fichier (VERT) ; `z_kernel_resolution_test.dart` VERT inchangé (fermeture `{zcrud_core, zcrud_annotations}`, `meta` ignoré car non-`zcrud_*`).
  - [x] AUCUN `.g.dart` neuf du kernel (`git status`) ; `gate_reserved_keys.dart` VERT **sans** toucher `registrars.dart` ; `gate_web_determinism.dart` VERT.
- [x] **T5 — Rejouer les injections R3 (orchestrateur).** (AC2, AC7)
  - [x] R3-a : neutraliser `validate(...)` dans `save` → AC2 (+ AC4-violant/AC5-cible) ROUGE (`persistCount` attendu 0, obtenu 1) → restauré par édition ciblée → re-VERT 10/10.
  - [x] R3-b : retirer `ZStudyRepository` du `hide` flashcard → surface-guard ROUGE (`FUITE POTENTIELLE: {ZStudyRepository}`) → restauré → re-VERT.
  - [x] R3-c : `import 'package:flutter/material.dart'` dans le port → `purity` ROUGE (token `package:flutter`) ; `analyze` le signale via `depend_on_referenced_packages` (info — flutter résolvable en workspace, d'où la valeur du scan de pureté comme filet dur) → restauré → re-VERT.
- [x] **T6 — Vérif verte REPO-WIDE (R9).** (AC12)
  - [x] `melos run generate` OK (0 nouveau `.g.dart`) → `melos run analyze` RC=0 → kernel `dart test` VM (283) + `dart test -p node` (269) RC=0 → `gate_reserved_keys` + `gate_web_determinism` VERTS → `prove_gates` 41 OK → `melos run verify` exit 0 (graph ACYCLIQUE + CORE OUT=0, reflectable, secrets, codegen, codegen-distribution, web).

---

## Dev Notes

### Patrons d'architecture & contraintes (AD)

- **AD-5 / AD-11 (CŒUR)** — `Either<ZFailure,T>` (dartz) sur toute opération, `ZResult<Unit>` pour void, flux `Stream<List<T>>` **NUS**. `ZStudyRepository` **hérite** ces garanties de `ZSyncableRepository`/`ZRepository` — ne les redéclare pas. `validate` renvoie `ZResult<Unit>` par cohérence. [Source: `packages/zcrud_core/lib/src/domain/ports/z_repository.dart`, `.../ports/z_syncable_repository.dart`, `.../failures/z_failure.dart`]
- **AD-11 backend-agnostique / NFR-S3 / SM-S5** — aucun type `cloud_firestore`/Hive/Flutter dans le port ; la traduction `ZDataRequest → Filter`, le curseur concret, le `Box`, le `WriteBatch` vivent dans l'adapter ES-3.2. Garde outillée : `z_kernel_purity_test.dart` (scan disque, R10). [Source: `z_repository.dart` l.18-25 ; `z_kernel_purity_test.dart`]
- **AD-14 (invariants métier au repository)** — les invariants (2 niveaux, matérialisation, cible requise) sont **portés par l'impl**, exposés ici par le hook `validate` overridable. lex les inline dans chaque `save*` ; ES-3.1 factorise le POINT D'ACCROCHE. [Source: `study_folders_repository_impl.dart:141-165` ; `flashcards_repository.dart:14-20`]
- **AD-9 / AD-16 (offline-first, admis non décidé)** — le port **admet** store local source de vérité + merge LWW sur `ZSyncMeta.updatedAt` (hors-entité, AD-19) + soft-delete `is_deleted` hors-entité, via `sync()`/`softDelete()`/`restore()` hérités. Il ne **décide** aucune topologie (= ES-3.2). [Source: `z_syncable_repository.dart` ; `z_syncable.dart` l.9-31 ; `z_sync_meta`]
- **AD-10 (défensif)** — `validate` par défaut ne throw jamais (no-op succès) ; `save`/`persist` enveloppent en `Either` (jamais de `try-catch` nu ni d'exception nue qui traverse — l'exception concrète est absorbée par l'adapter ES-3.2). [Source: `z_failure.dart`]
- **AD-1 / AD-17 (acyclique, CORE OUT=0)** — `ZStudyRepository` vit au kernel qui dépend UNIQUEMENT de `zcrud_core` ; aucune arête sortante vers un satellite. `graph_proof` reste ACYCLIQUE. [Source: `packages/zcrud_study_kernel/pubspec.yaml` ; `z_kernel_resolution_test.dart`]
- **AD-4 (extensibilité, COMPOSE-not-DUPLICATE)** — generics autorisés pour un **PORT** (pas pour la sérialisation) ; **jamais `sealed`** inter-package (le port est `abstract class`, pas `sealed`) ; hook par override (Template Method), pas héritage de modèle. [Source: architecture AD-4 ; `z_failure.dart` l.10-17 « jamais `sealed` »]

### Continuité ES-3.0 (dépendance directe)

ES-3.0 (done) a soldé DW-ES14-2 : `ZcrudRegistry` + `ZDecodeContext` (`extensionParser`/`sourceRegistry`) reconstruisent désormais l'`extension` TYPÉE + la provenance sur la **voie registre — la SEULE qu'un store offline-first emprunte**. ES-3.2 (l'adapter) décodera via `registry.decode(kind, map)` en **passant le `ZDecodeContext`** câblé au bootstrap. **Le PORT ES-3.1 ne décode rien** (aucun registre référencé) — il déclare le contrat ; le décodage contextualisé est une préoccupation de l'adapter. À garder à l'esprit pour ES-3.2 mais **hors périmètre ES-3.1**. [Source: `es-3-0-registre-preserve-extension-immuabilite.md` ; `packages/zcrud_core/lib/src/domain/registry/z_decode_context.dart`]

### Source tree — fichiers à toucher

- **NEW** `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` — le port.
- **NEW** `packages/zcrud_study_kernel/test/z_study_repository_test.dart` — test discriminant (web-safe).
- **UPDATE** `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` — `export` du port.
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — ajout de `ZStudyRepository` à la liste `hide` (D7/AC10).
- **⛔ NE PAS TOUCHER** : `zcrud_core` (ports déjà livrés — R9, kernel seul point de contact), `tool/reserved_keys_gate/**` (AC9), tout `*.g.dart`, `zcrud_firestore` (= ES-3.2), le sprint-status (édité par l'orchestrateur).

### Fichiers UPDATE — état actuel & ce qui doit être préservé

- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` : barrel avec `export` + politique `hide` documentée (règle D3). **Préserver** l'ordre/les commentaires existants ; ajouter une seule ligne `export` avec commentaire ES-3.1. Ne PAS altérer les `hide` existants des extensions générées.
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : ré-exporte le barrel kernel via une liste `hide` (jamais `show`) pour préserver la surface E9. **Préserver** intégralement les symboles flashcard historiques ; **ajouter** `ZStudyRepository` au `hide` (le guard test l'exige — sinon un port data fuiterait dans la surface flashcard OU casserait le guard). Vérifier que rien de la surface E9 n'est retiré.

### Testing standards

- Kernel : `dart test` (VM) **et** `dart test -p node` (JS) — le test du port **doit** passer sur les deux (web-safe, AC11). Réserver `@TestOn('vm')` aux seuls tests lisant `dart:io` (purity/resolution) — le nouveau test n'en est PAS.
- **Pouvoir discriminant (R12)** : chaque garde naît avec sa **fixture d'échec isolée (R2)** ; l'orchestrateur rejoue l'injection R3 (retirer la garde → ROUGE **par cette garde**), restaure par **édition ciblée** (`diff` vide — R13, JAMAIS `git checkout`).
- **Pas de test powerless** (R12/DW-ES25-1) : ne PAS « prouver » le hook par un chemin qui ne dépend pas du template `save` (ex. appeler `validate` directement sans passer par `save` prouverait seulement que la méthode existe, pas qu'elle est LOAD-BEARING). Le test AC2 **doit** passer par `save` et observer le compteur `persist`.
- **Machine dérivée du disque (R10)** : ne PAS ajouter de garde artisanale énumérant à la main les tokens backend — s'appuyer sur `z_kernel_purity_test.dart` (déjà dérivé du disque, scanne tout `lib/**`).

### Points d'attention dev

1. **Surface publique exacte de `zcrud_core`** : vérifier le barrel exporté (`package:zcrud_core/domain.dart` ou équivalent) qui expose `ZSyncableRepository`, `ZEntity`, `ZResult`/`ZFailure`, `ZDataRequest`, `Unit`/`right`/`left`. Le kernel importe la **surface pur-Dart** (pas le SDK Flutter). Ne pas importer un chemin `src/` privé.
2. **`@protected` sur `persist`** : nécessite `package:meta`. Vérifier qu'il est déclaré (dép directe ou transitive via core) ; l'ajouter en dépendance si `analyze` le réclame (dep légère, pur-Dart, AD-1-safe). Sinon, à défaut, documenter par dartdoc sans annotation (moindre choix).
3. **`save` override d'une méthode abstraite héritée** : légal, mais confirmer que la signature (`{String? collectionId}`) matche **exactement** `ZRepository.save` (sinon override invalide). Idem `persist` ne doit PAS entrer en collision de nom avec un membre core existant.
4. **Ne PAS ajouter `dataChanges`** (D4) : redondant avec `watchAll()`. L'AC épic « expose `dataChanges` » est satisfaite par héritage — documenté, pas re-déclaré.
5. **Guard de surface flashcard (AC10)** : c'est le piège d'inertie le plus probable — oublier le `hide` fait ÉCHOUER `z_kernel_surface_guard_test.dart` (pas `analyze`). Le lancer explicitement après T2.
6. **Ne rien décoder** : le port ne référence NI `ZcrudRegistry` NI `ZDecodeContext` (ES-3.0/ES-3.2). S'il le faisait, il gagnerait une préoccupation d'adapter (fuite de couche).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-3.1` (l.489-505), FR-S12 (l.45), traçabilité (l.116)]
- [Source: `packages/zcrud_core/lib/src/domain/ports/z_repository.dart` — surface héritée, `watchAll`=`dataChanges`]
- [Source: `packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart` — `sync()` best-effort AD-9]
- [Source: `packages/zcrud_core/lib/src/domain/failures/z_failure.dart` — `ZResult`/`ZFailure`, « jamais `sealed` » AD-4]
- [Source: `packages/zcrud_core/lib/src/domain/contracts/z_entity.dart` — `ZEntity`/`isEphemeral` ; `.../z_syncable.dart` — LWW hors-entité AD-19]
- [Source: lex `packages/lex_data/lib/data/repositories/study_folders_repository_impl.dart:141-165` — invariant 2 niveaux inliné (à factoriser en hook)]
- [Source: lex `packages/lex_core/lib/domain/repositories/flashcards_repository.dart:14-20` — matérialisation éphémère ; `repetition_repository.dart`, `study_folders_repository.dart` — forme `dataChanges`+`Either`+`sync`]
- [Source: `packages/zcrud_study_kernel/test/z_kernel_purity_test.dart` (scan disque SM-S5), `z_kernel_resolution_test.dart` (acyclicité), `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (guard `hide`)]
- [Source: `es-2-7-resultat-session-agregation-quotidienne.md` AC14 — précédent anti-inertie `reserved-keys`]
- [Source: `epic-es-2-retrospective.md` — R10 (garde dérivée du disque), R11 (patron en tête), R12 (test powerless), R13 (édition ciblée) ; DW-ES25-1]
- [Source: `es-3-0-registre-preserve-extension-immuabilite.md` — `ZDecodeContext` (voie registre du futur store)]

### Project Structure Notes

- Chemin conforme à l'épic (`z_study_repository.dart` sous `lib/src/domain/`) et à la convention kernel (barrel `lib/zcrud_study_kernel.dart`, impl `lib/src/`). Nommage `Z…`, snake_case, test `*_test.dart`. Aucune variance détectée.
- Le port est un **membre `domain`** (contrat) — cohérent avec `z_session_candidate.dart`/`z_study_folder_hierarchy.dart` déjà dans `lib/src/domain/`. Pas de couche `data` dans le kernel (l'adapter est en `zcrud_firestore`, ES-3.2).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- Vérif verte rejouée réellement sur disque : kernel `dart analyze` RC=0 ; kernel `dart test` VM = **283 pass**, `dart test -p node` = **269 pass** ; flashcard `dart analyze` RC=0 ; surface-guard flashcard 5/5 ; `gate_reserved_keys` VERT (registrars INCHANGÉ) ; `graph_proof` ACYCLIQUE + CORE OUT=0 ; `gate_web_determinism` VERT ; `prove_gates` 41 OK/0 FAIL ; `melos run generate` OK (0 `.g.dart` neuf) ; `melos run analyze` repo-wide RC=0 ; `melos run verify` **exit 0**.
- Injections R3 (exécutées puis restaurées par édition ciblée) : (a) `validate` neutralisé dans `save` → AC2 ROUGE (`persistCount` 0→1) ; (b) `ZStudyRepository` retiré du `hide` → surface-guard ROUGE (`{ZStudyRepository}`) ; (c) `import package:flutter/material.dart` → purity ROUGE (`package:flutter`).
- Note d'exploitation : `prove_gates` (fixture ES-1.4/AC6) injecte transitoirement `packages/zcrud_study_kernel/bin/__gate_proof_reflectable_probe.dart` ; un `melos run verify` lancé pendant/juste après peut le voir (gate:reflectable). Relancé sur arbre propre → exit 0. Non lié au livrable ES-3.1.

### Completion Notes List

- **D1/D2 (cœur)** : `ZStudyRepository<T>` livré en **Template Method** — `save` concret appelle `validate` PUIS `persist` seulement si `Right`. `validate` = hook overridable, défaut no-op succès ; `persist` = point d'extension `@protected` abstrait (impl = ES-3.2). Pouvoir discriminant PROUVÉ par espion : `validate→Left` ⇒ `persistCount==0`.
- **AD-4 COMPOSE-not-DUPLICATE** : n'ajoute QUE `validate`/`persist`/override `save` au-dessus de `ZSyncableRepository` ; flux nus, `Either`, `sync`, curseur tous HÉRITÉS. **D4 respectée** : aucun getter `dataChanges` redondant (`watchAll()` EST le flux canonique).
- **D6 anti-inertie** : aucun `@ZcrudModel`, aucun `.g.dart`, `registrars.dart` NON touché, `gate_reserved_keys` VERT.
- **AD-1** : `zcrud_study_kernel` ne gagne aucune arête satellite ; fermeture `{zcrud_core, zcrud_annotations}` inchangée ; CORE OUT=0.
- **R-G (prescriptions remises en cause)** : (1) le sample D2 utilise `right(unit)`/`left(...)` (fonctions dartz) — NON exportées par `domain.dart` ; remplacé par les constructeurs `Right<ZFailure,Unit>(unit)`/`Left<ZFailure,T>(f)` (idiome EXACT de `z_study_folder_hierarchy.dart`), sans import direct de `dartz`. (2) T1 listait `package:dartz/dartz.dart` en import ; écarté (tout vient du barrel `domain.dart` → évite `depend_on_referenced_packages`). `meta` ajouté en dép directe pour `@protected`.
- **Dette / suivi ES-3.2** : `persist` reste abstrait (aucune impl persistante ici) ; matérialisation éphémère + décodage contextualisé (`ZDecodeContext`, ES-3.0) sont hors périmètre, portés par l'adapter offline-first.

### File List

- **NEW** `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` — le port `ZStudyRepository<T>` (Template Method).
- **NEW** `packages/zcrud_study_kernel/test/z_study_repository_test.dart` — test discriminant web-safe (10 tests).
- **UPDATE** `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` — `export` du port (placé alphabétiquement).
- **UPDATE** `packages/zcrud_study_kernel/pubspec.yaml` — ajout de la dép directe `meta: ^1.15.0` (`@protected`).
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — ajout de `ZStudyRepository` à la liste `hide` (D7/AC10).
