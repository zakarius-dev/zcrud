---
baseline_commit: 3adf49dbec2d04e00d45c871d38544d2696756a3
---

# Story ES-10.2 : Intégration lex_douane repo-par-repo — surface zcrud (providers concrets typés + adapter firestore folder-scopé)

Status: review

> ⚠️ **CORPS PARTIELLEMENT SUPERSEDED (2026-07-16)** — le plan initial (providers concrets typés DANS `zcrud_riverpod` + 4 arêtes d'entités, cible 49 arêtes) a été **RÉVISÉ** : le binding reste **GÉNÉRIQUE** (aucune dep d'entité), les providers typés sont **app-side** (DW-ES102-1). **La section faisant foi est « 🔴 DÉCISION D'ARCHITECTURE — RÉVISION ORCHESTRATEUR (Option B) » en fin de document.** Les AC1/AC5/AC7 « providers typés / 49 arêtes » et les tâches T1/T2/T6 (`z_study_entity_providers`) sont **caduques** ; seuls l'adapter firestore (B), l'isolation backend (AC2) et les invariants de graphe (révisés à 45) restent valides.

<!-- Créée par bmad-create-story (skill réel bmad-create-story, tool Skill). Cycle BMAD strict. NE PAS éditer le sprint-status ici (orchestrateur). -->

## ⚠️ Re-scope IMPÉRATIF (consigne utilisateur, PRIME sur l'intitulé de l'epic)

L'epic ES-10.2 s'intitule *« remplacement progressif des repos education lex »*. **Le branchement RÉEL dans `lex_douane` est DÉFÉRÉ à une session dédiée `lex_douane`.** Cette story ne produit **QUE la surface zcrud** que lex consommera — **AUCUN fichier de `lex_douane`/`iffd`/`dodlp-otr` n'est lu-pour-modification ni écrit**. Périmètre strict : packages `zcrud_riverpod` (providers CONCRETS typés) et `zcrud_firestore` (adapter folder-scopé concret). La migration/cutover lex est une **dette de portage tracée `DW-ES102-1`** (§ *Frontière zcrud-side / lex-side*).

---

## Story

As a **développeur-mainteneur (Zakarius) préparant l'intégration lex_douane**,
I want **matérialiser DANS les packages zcrud la surface CONCRÈTE que lex consommera pour remplacer ses repos « education » un par un — (A) des providers Riverpod TYPÉS par entité (`ZStudyFolder`, `ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcard`) instanciant la fabrique générique d'ES-10.1 sur le port `ZStudyRepository<T>` résolu par seam, et (B) un adapter `zcrud_firestore` folder-scopé concret composant les briques offline-first d'ES-3 pour la topologie imbriquée `users/{uid}/{parent}/{parentId}/{collection}`**,
So that **la session `lex_douane` n'ait plus qu'à ENREGISTRER ces providers/adapters au seam de son `ProviderScope` (aucun assemblage à ré-écrire, aucun repo générique à ré-typer), en migrant repo par repo sans big-bang — le tout sans qu'aucun package zcrud ne connaisse Riverpod hors `zcrud_riverpod`, ni ne laisse fuiter `cloud_firestore` hors `zcrud_firestore`, ni n'introduise de cycle (AD-1/AD-15/AD-5)**.

---

## Contexte & état réel validé sur disque (le 2026-07-16)

> **Ne rien réinventer, ne rien casser (R21).** Le générique EXISTE déjà — côté binding (ES-10.1) ET côté firestore (ES-3). Cette story n'ajoute QUE la **spécialisation typée** et la **fabrique de composition folder-scopée** ; elle ne recrée ni la fabrique de providers, ni le port, ni l'adapter offline-first.

### Acquis ES-10.1 (`zcrud_riverpod/lib/src/study/`) — à RÉUTILISER tel quel
- `zStudyRepositoryProvider<T>()` — **seam générique** : `Provider` qui **throw `ZScopeError` actionnable** (message nommant le `Type`) tant que non surchargé. **C'est le point d'injection du repo** (jamais un import concret).
- `zStudyWatchAllProvider<T>({required ProviderListenable<ZStudyRepository<T>> repo})` → `AutoDisposeStreamProvider<List<T>>` — **fabrique générique** émettant la `Stream<List<T>>` **NUE** du port (aucune transformation, AD-5). **auto-dispose** (patron `zFormControllerProvider`).
- `ZSessionConfigKey` + `zStudySessionSelectorProvider` (family clée par `ZSessionConfigKey`, égalité profonde AU BINDING, AD-24) — **DÉJÀ livrés, NE PAS retoucher** (config/session = clos en 10.1).
- Barrel `lib/zcrud_riverpod.dart`. Garde `test/purity/idiom_isolation_test.dart` (scan récursif `lib/` — couvre tout nouveau `lib/src/study/*` **automatiquement**).
- **Dépendances `zcrud_*` actuelles du binding : `zcrud_core` + `zcrud_study_kernel` UNIQUEMENT** (pubspec). ⇒ les providers typés introduisent les **premières arêtes de fan-in vers les packages d'entités** (§ Graphe). **Le binding ne dépend PAS de `zcrud_firestore`** — l'adapter est **injecté au seam par lex**, jamais importé par le binding (invariant CRUCIAL, § AC).

### Acquis ES-3 (`zcrud_firestore/lib/src/data/`) — à COMPOSER, jamais dupliquer
- `ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>` — base **offline-first bi-topologie** (local autoritaire Hive + Firestore fire-and-forget, merge LWW hors-entité, listener temps réel, filtrage `hasPendingWrites`). Constructeur : `{required ZLocalStore<T> local, required FirebaseFirestore firestore, required ZFirestorePathResolver resolver, required String kind, required T Function(Map) decode, required Map Function(T) encode, String? userId, String? parentId, ...}`. **Signatures publiques NUES** (aucun type `cloud_firestore`/Hive exporté).
- `ZFirestorePathResolver(Map<String, ZFirestorePathRule> rules)` + `ZFirestorePathRule.nestedUnderParent({required String collection, required String parentCollection, bool userScoped = true})` / `.flatTopLevel` / `.globalTopLevel`. `resolveCollection({kind, userId, parentId})` → chemin `String` **ou** `Left(DomainFailure)` explicite si : kind inconnu ; nested **sans** `parentId` ; user-scopé **sans** `userId`. **Anti-réflexion prouvé** (aucun `T.toString()`/`runtimeType`).
- `FirebaseZRepositoryImpl<T>.fromRegistry({...})` — voie recommandée de (dé)sérialisation via `ZcrudRegistry` (décodage contextualisé ES-3.0). `ZStudyLegacyCodec` (camelCase↔snake, mapping legacy) branchable **en amont** au câblage DI.
- `ZFirestoreCascadeBatcher` (cascade bornée ≤ 450), `assembleZStudySyncOrchestrator` (câblage neutre). **Non modifiés par cette story.**

### Entités study canoniques (packages disjoints, ES-2) — cibles des providers typés
| Entité | Package | `kind` (`@ZcrudModel`) | Nature |
|---|---|---|---|
| `ZStudyFolder` | `zcrud_study_kernel` | `study_folder` | dossier organisateur (arête kernel **déjà présente**) |
| `ZStudyDocument` | `zcrud_document` | `study_document` | contenu partageable |
| `ZSmartNote` | `zcrud_note` | `smart_note` | note à corps typé (⚠️ slot `ZNoteAudio`, cf. DW-ES14-2) |
| `ZExam` | `zcrud_exam` | `exam` | examen daté |
| `ZFlashcard` | `zcrud_flashcard` | `flashcard` | carte (état SRS HORS carte, AD-9) |

### Graphe — baseline mesurée **le 2026-07-16**
`python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 45`**, **20 nœuds**. Arêtes `zcrud_*` actuelles du binding : `zcrud_riverpod → zcrud_core`, `zcrud_riverpod → zcrud_study_kernel`.

---

## Frontière zcrud-side / lex-side — dette de portage `DW-ES102-1` (NON-NÉGOCIABLE)

> Le titre de l'epic parle de « remplacement des repos lex » ; **ce remplacement N'EST PAS fait ici** (aucun accès `lex_douane`).

**LIVRÉ zcrud-side (cette story) :**
- **(A)** Providers Riverpod **typés concrets** par entité (folder/document/note/exam/flashcard) dans `zcrud_riverpod/lib/src/study/`, adossés au seam `zStudyRepositoryProvider<T>` + fabrique `zStudyWatchAllProvider<T>` d'ES-10.1.
- **(B)** Fabrique d'adapter **folder-scopé concret** `buildFolderScopedStudyRepository<T>(…)` dans `zcrud_firestore/lib/src/data/`, composant `ZOfflineFirstBoxRepository<T>` + une règle `nestedUnderParent` — **générique-par-topologie** (paramètres `collection`/`parentCollection` `String`, aucun nom de consommateur codé en dur, aucune arête vers un package d'entité).

**DÉFÉRÉ à la session `lex_douane` (dette `DW-ES102-1`, tracée, NON exécutée ici) :**
1. **Enregistrement au seam** : `ZcrudRiverpodScope(seams: { zStudyRepositoryProvider<ZStudyDocument>: Provider((ref) => buildFolderScopedStudyRepository<ZStudyDocument>(firestore: …, local: …, collection: 'study_documents', parentCollection: 'study_folders', userId: uid, folderId: …)) , … })` dans le composition-root lex.
2. **Cutover repo par repo** : remplacer `smart_notes_repository` / `study_documents_repository` / `study_folders_repository` / `exams_repository` / `flashcards_repository` lex, **un par un**, par la lecture des providers typés — **aucun big-bang**.
3. **Injection `FirebaseFirestore` + `userId`/`folderId`** depuis l'auth lex ; instanciation des `ZLocalStore` Hive lex.
4. **Parité écran + parité SRS SM-2** validée sur données lex vivantes (SM-S1 : source SM-2 unique inchangée).
5. Choix/branchement éventuel de `ZStudyLegacyCodec` si des documents lex historiques divergent du canonique.

**Marqueur** : chaque déliverable de cette story porte en dartdoc une note `DW-ES102-1` pointant l'étape lex-side qu'il débloque. La dette est **OUVERTE, non bloquante** pour le `done` de ES-10.2 (le zcrud-side est complet et prouvé isolément).

---

## Décision d'architecture — invariants structurants (NON-NÉGOCIABLES)

- **AD-1 (graphe acyclique, CORE OUT=0, fan-in SORTANT)** — les providers typés (A) **importent les types d'entité** ⇒ arêtes SORTANTES `zcrud_riverpod → {zcrud_document, zcrud_note, zcrud_exam, zcrud_flashcard}` (folder = kernel, arête déjà là). **Delta attendu = +4** (45 → **49**), 20 nœuds inchangés. Toutes SORTANTES : **aucun** package d'entité ne dépend de `zcrud_riverpod` (le binding reste un **PUITS**). L'adapter (B) reste **générique-par-topologie** ⇒ **0 nouvelle arête** dans `zcrud_firestore` (aucun import d'entité).
- **AD-15 / AD-2 / NFR-S5 (Riverpod confiné)** — `flutter_riverpod` n'apparaît QUE dans `zcrud_riverpod`. Symétriquement, **`zcrud_riverpod` NE DOIT PAS dépendre de `zcrud_firestore`** : le repo concret est **résolu par seam** (fourni par lex), jamais importé par le binding. Garanti structurellement par le graphe (aucune arête `zcrud_riverpod → zcrud_firestore`).
- **AD-5 / AD-11 (flux nus + `Either`)** — `zStudy<Entity>Provider` **ré-émet exactement** la `Stream<List<T>>` nue du port (aucune transformation/tri/reverse). Écritures `save`/`softDelete` = `Future<ZResult<T>>` **non ré-enveloppé**.
- **AD-9 / AD-10 (offline-first défensif, backend-agnostique)** — (B) ne laisse **aucun** type `cloud_firestore` fuir dans une signature publique ; une résolution impossible (folderId manquant sur nested) remonte un `Left(DomainFailure)` **explicite** (contrat resolver réutilisé), **jamais** un chemin muet.
- **AD-6 (seams throw)** — repo absent ⇒ `ZScopeError` actionnable (réutilise `zStudyRepositoryProvider<T>` d'ES-10.1), jamais `null` silencieux.
- **AD-14 / AD-19** — le hook `validate` (2 niveaux max, matérialisation de l'éphémère) reste porté par `ZStudyRepository`/`ZOfflineFirstBoxRepository` ; merge LWW sur `ZSyncMeta` hors-entité. (B) n'introduit **aucune** convention de sync nouvelle.

---

## Acceptance Criteria

> Chaque AC est **discriminant** (R12) ; **chaque garde est co-livrée avec un test à rouge provoqué** (R27, leçon centrale ES-9). Les injections sont listées § *Injections R3 prévues*. Frontière R20 déclarée honnêtement là où un AC s'appuie sur du code déjà testé (ES-10.1/ES-3).

### AC1 — Providers TYPÉS par entité, adossés au seam générique (A)

**Given** la fabrique générique `zStudyWatchAllProvider<T>` et le seam `zStudyRepositoryProvider<T>` (ES-10.1)
**When** on ajoute, sous `lib/src/study/`, un bundle par entité study
**Then** pour **chacune** des 5 entités (`ZStudyFolder`, `ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcard`), `zcrud_riverpod` expose : (a) un **seam typé** `zStudy<Entity>RepositoryProvider` = `zStudyRepositoryProvider<Entity>()` (throw `ZScopeError` nommant le **Type concret** tant que non surchargé) ; (b) un **flux typé** `zStudy<Entity>sProvider` (ou `…Provider`) = `zStudyWatchAllProvider<Entity>(repo: zStudy<Entity>RepositoryProvider)` → `AutoDisposeStreamProvider<List<Entity>>` **émettant la `Stream<List<Entity>>` nue** du repo résolu.
**Then** les deux sont **exportés par le barrel** `lib/zcrud_riverpod.dart`.

**Discriminant** — un provider typé qui **transforme** le flux (`.map`, `.reversed`, tri) échoue le test de ré-émission exacte (ordre + contenu). Un provider `ZStudyDocument` dont le seam résout en réalité un `ZStudyRepository<ZSmartNote>` (mauvais type) **ne compile pas** (garde compile-time) — et le message de `ZScopeError` d'un seam absent **nomme le Type demandé** (asserté). *(R20 déclarée : la mécanique auto-dispose/flux-nu/seam-throw est déjà prouvée POWERFUL en ES-10.1 ; l'apport propre d'ES-10.2 est le **typage correct par entité** et le **câblage bundle**, testés ici pour AU MOINS 2 entités distinctes afin d'exclure un copier-coller mono-type.)*

### AC2 — Le binding NE dépend PAS du backend (isolement AD-15/AD-5)

**Given** l'ajout des bundles typés dans `zcrud_riverpod`
**When** on inspecte le `pubspec.yaml` et les imports de `lib/`
**Then** `zcrud_riverpod` gagne **exactement** les 4 dépendances `zcrud_document`, `zcrud_note`, `zcrud_exam`, `zcrud_flashcard` (folder via `zcrud_study_kernel` déjà présent) — **et RIEN d'autre** ; en particulier **AUCUNE** dépendance `zcrud_firestore`, `cloud_firestore`, `hive`, ni un autre gestionnaire d'état.
**Then** aucun symbole `cloud_firestore`/`FirebaseFirestore`/`Box` n'apparaît dans `zcrud_riverpod/lib/` (le repo concret est **injecté au seam** par lex, jamais importé).

**Discriminant** — ajouter par erreur `zcrud_firestore` au pubspec du binding (pour « instancier directement » un adapter) fait diverger le compte de graphe (§ AC7) **et** casse l'inversion de dépendance : un test de surface (scan des imports de `lib/`) rougit sur toute occurrence `cloud_firestore`/`FirebaseFirestore`.

### AC3 — Fabrique d'adapter folder-scopé CONCRÈTE, backend confiné (B)

**Given** les briques ES-3 (`ZOfflineFirstBoxRepository<T>`, `ZFirestorePathResolver`, `ZFirestorePathRule.nestedUnderParent`)
**When** on ajoute `buildFolderScopedStudyRepository<T extends ZEntity>({required FirebaseFirestore firestore, required ZLocalStore<T> local, required String kind, required String collection, required String parentCollection, required T Function(Map<String,dynamic>) decode, required Map<String,dynamic> Function(T) encode, String? userId, required String folderId, bool userScoped = true, ...})` dans `zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart`
**Then** la fabrique compose **une** règle `nestedUnderParent(collection: collection, parentCollection: parentCollection, userScoped: userScoped)` dans un `ZFirestorePathResolver({kind: rule})` et retourne un `ZOfflineFirstBoxRepository<T>` câblé (`parentId: folderId`, `userId`) — **type de retour public = `ZStudyRepository<T>`** (port neutre), **aucun** type `cloud_firestore` en signature publique **hors** le paramètre d'injection `FirebaseFirestore` (seule couture voulue, AD-5).
**Then** le chemin résolu pour une écriture est **exactement** `{userSegment}/{userId}/{parentCollection}/{folderId}/{collection}` (topologie imbriquée lex) — vérifié par un test.

**Discriminant** — un test compose la fabrique avec `(collection: 'study_documents', parentCollection: 'study_folders', userId: 'u1', folderId: 'f1')` et asserte que le resolver interne rend `users/u1/study_folders/f1/study_documents`. **Muter** `parentCollection`→`collection` (ou intervertir parent/enfant) fait rougir l'assertion de chemin. La neutralité de signature est prouvée par un test de surface (`z_firestore_backend_isolation` esprit AD-5) : aucun `cloud_firestore` exporté par le barrel pour ce nouveau symbole.

### AC4 — folderId manquant ⇒ `Left(DomainFailure)` explicite, jamais un chemin muet (B, AD-10)

**Given** la fabrique folder-scopée (topologie `nestedUnderParent`, qui exige un `parentId`)
**When** une opération est tentée avec un `folderId` **vide** (`''`)
**Then** la résolution de chemin remonte un `Left(DomainFailure)` **explicite** (message nommant le `kind` et l'exigence `parentId`/folderId), **jamais** un chemin silencieusement tronqué qui écrirait dans la mauvaise collection.

**Discriminant** — le test asserte `isLeft` avec un message contenant `parentId`/le `kind` ; **neutraliser** la propagation du `Left` (ex. défaut `folderId = ''` avalé, ou fabrique qui construit malgré tout un chemin plat) fait rougir le test. *(R20 déclarée : le garde `parentId manquant → Left` vit dans le resolver ES-3 déjà testé ; l'apport propre d'ES-10.2 est de **prouver que la fabrique folder-scopée le PROPAGE** au lieu de le contourner.)*

### AC5 — Auto-dispose des providers typés (aucune fuite, AD-2)

**Given** un provider typé `zStudy<Entity>sProvider` (`AutoDisposeStreamProvider`)
**When** plus personne n'écoute (fin d'écoute d'un abonnement dans un conteneur toujours vivant)
**Then** la souscription au flux du repo est **annulée** (`onCancel` du `StreamController` du fake repo est appelé) — aucune souscription pendante.

**Discriminant** — retirer `.autoDispose` (ou passer par un `StreamProvider` non-auto-dispose) laisse `onCancel` non appelé : le test rougit. *(Réutilise le patron de test AC5 d'ES-10.1 ; ici sur AU MOINS un provider typé concret pour prouver que le bundle n'a pas « perdu » l'auto-dispose au moment de typer.)*

### AC6 — Sélection de session réutilisée telle quelle (config/session close en ES-10.1)

**Given** `zStudySessionSelectorProvider` (family clée par `ZSessionConfigKey`, AD-24) livré en ES-10.1
**When** on assemble la surface ES-10.2
**Then** aucune 2ᵉ forme d'égalité de config n'est ajoutée (kernel/cœur inchangés) ; les providers de session/config d'ES-10.1 sont **réutilisés tels quels**, non redéclarés.

**Discriminant** — `git status` prouve que `z_session_config_key.dart` et le bloc session de `z_study_providers.dart` (ES-10.1) **ne sont pas modifiés** ; aucune classe `ZSessionConfigKey`-bis n'apparaît (grep). Un doublon d'égalité de config est un finding bloquant.

### AC7 — Graphe : fan-in SORTANT borné, acyclique, CORE OUT=0 (AD-1)

**Given** la baseline **45 arêtes / 20 nœuds** (mesurée le 2026-07-16, CORE OUT=0)
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 49`** (**delta = +4** : `zcrud_riverpod → zcrud_document`, `→ zcrud_note`, `→ zcrud_exam`, `→ zcrud_flashcard` — toutes SORTANTES), **20 nœuds inchangés**. **AUCUNE** arête `zcrud_riverpod → zcrud_firestore` ni `zcrud_firestore → {entité}` (l'adapter B reste générique). Le commentaire d'invariant du `pubspec.yaml` de `zcrud_riverpod` est **mis à jour** (il énumère aujourd'hui « `zcrud_core` + `zcrud_study_kernel` » — devenu incomplet).

**Discriminant** — un delta ≠ +4, une arête vers `zcrud_firestore`/`cloud_firestore`, ou tout cycle (fatal) fait échouer `graph_proof` / diverger le compte (injection `R3-I7`). `flutter_riverpod` n'est pas un `zcrud_*` ⇒ hors compte.

### AC8 — Isolement d'idiome & vérif verte repo-wide (NFR-S2/NFR-S5)

**Given** la garde `test/purity/idiom_isolation_test.dart` (scan récursif `lib/`) et les gates `melos run verify`
**When** on ajoute `lib/src/study/*` (riverpod) et `lib/src/data/z_folder_scoped_study_repository.dart` (firestore)
**Then** la garde d'idiome reste **verte** (aucun `Get.put`/`Provider.of`/`get_it` dans `zcrud_riverpod/lib/`) ; `melos run analyze` **ET** `melos run verify` sont **VERTS repo-wide** (reserved-keys, secrets, codegen-distribution, isolement, compat sérialisation).

**Discriminant** — la vérif ciblée par package NE détecte PAS une régression cross-package (leçon `ZExportApi` E11a-3) : le gate `melos run verify` **repo-wide** est rejoué réellement (§ Vérif verte), non substitué par un `graph_proof`/`melos list` vert.

---

## Tasks / Subtasks

- [ ] **T1 — `zcrud_riverpod/pubspec.yaml` : 4 arêtes de fan-in typé + MAJ invariant** (AC2/AC7)
  - [ ] Ajouter dans `dependencies:` : `zcrud_document: ^0.1.0`, `zcrud_note: ^0.1.0`, `zcrud_exam: ^0.1.0`, `zcrud_flashcard: ^0.1.0` (à côté de `zcrud_core` + `zcrud_study_kernel`). **NE PAS** ajouter `zcrud_firestore`/`cloud_firestore`/`hive`.
  - [ ] Mettre à jour le **commentaire d'invariant** : « deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` + entités study (`zcrud_document`/`zcrud_note`/`zcrud_exam`/`zcrud_flashcard`, fan-in SORTANT ES-10.2) ; toujours AUCUN backend (`zcrud_firestore`/`cloud_firestore`/`hive`) ; `flutter_riverpod` reste le seul manager ; CORE OUT=0 ; binding = PUITS ».
  - [ ] `dart pub get` (workspace, R25) RC=0, résolution `workspace`, sans conflit ni warning nouveau.

- [ ] **T2 — Providers typés par entité** — `zcrud_riverpod/lib/src/study/z_study_entity_providers.dart` (**NOUVEAU**) (AC1/AC5)
  - [ ] Pour `ZStudyFolder`, `ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcard` : `zStudy<Entity>RepositoryProvider = zStudyRepositoryProvider<Entity>()` (seam typé) + `zStudy<Entity>sProvider = zStudyWatchAllProvider<Entity>(repo: zStudy<Entity>RepositoryProvider)`.
  - [ ] **Réutiliser** la fabrique + le seam d'ES-10.1 (ne rien réimplémenter) ; imports d'entité depuis les barrels (`package:zcrud_document/zcrud_document.dart`, etc.).
  - [ ] Dartdoc par bundle : note `DW-ES102-1` (« lex enregistre ce seam au `ProviderScope` avec `buildFolderScopedStudyRepository<Entity>` »).

- [ ] **T3 — Barrel `zcrud_riverpod`** — `lib/zcrud_riverpod.dart` (AC1)
  - [ ] `export 'src/study/z_study_entity_providers.dart';`.

- [ ] **T4 — Fabrique d'adapter folder-scopé** — `zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart` (**NOUVEAU**) (AC3/AC4)
  - [ ] `ZStudyRepository<T> buildFolderScopedStudyRepository<T extends ZEntity>({...})` composant `ZFirestorePathRule.nestedUnderParent` + `ZFirestorePathResolver({kind: rule})` + `ZOfflineFirstBoxRepository<T>(parentId: folderId, userId: userId, resolver: resolver, kind: kind, decode: decode, encode: encode, local: local, firestore: firestore)`.
  - [ ] **Type de retour public = `ZStudyRepository<T>`** (port neutre) ; seul `FirebaseFirestore` en paramètre est une couture backend (AD-5).
  - [ ] Dartdoc : générique-par-topologie (aucun nom lex codé en dur), exemple de câblage lex commenté (`DW-ES102-1`), note « la matérialisation de l'éphémère + le hook `validate` restent portés par `ZOfflineFirstBoxRepository`/`ZStudyRepository` — non redéclarés ici ».

- [ ] **T5 — Export barrel `zcrud_firestore`** — `lib/zcrud_firestore.dart` (AC3)
  - [ ] `export 'src/data/z_folder_scoped_study_repository.dart';` (signature publique NUE — vérifier aucun type `cloud_firestore` réexporté).

- [ ] **T6 — Tests `zcrud_riverpod` (R14 : `flutter test`)** — `packages/zcrud_riverpod/test/study/` (AC1/AC2/AC5)
  - [ ] `z_study_entity_providers_test.dart` : pour ≥ 2 entités distinctes (ex. `ZStudyDocument` + `ZFlashcard`) — fake `ZStudyRepository<Entity>` + `StreamController` ; **ré-émission exacte** (ordre/contenu) ; seam absent ⇒ `throwsA(isA<ZScopeError>())` **message contenant le Type concret** ; `onCancel` appelé à la fin d'écoute (auto-dispose). Injections `R3-I1/I2/I5` prouvées rouges.
  - [ ] `z_binding_backend_isolation_test.dart` : scan de `lib/` — **aucune** occurrence `cloud_firestore`/`FirebaseFirestore`/`Box` ; le pubspec ne liste pas `zcrud_firestore`. Injection `R3-I3` prouvée rouge.

- [ ] **T7 — Tests `zcrud_firestore` (R14 : `flutter test`)** — `packages/zcrud_firestore/test/` (AC3/AC4)
  - [ ] `z_folder_scoped_study_repository_test.dart` : la fabrique compose le resolver attendu ⇒ chemin résolu **exact** `users/u1/study_folders/f1/study_documents` (via un fake local + un resolver observable, ou en asservant le `resolveCollection` de la règle composée) ; `folderId=''` ⇒ `Left(DomainFailure)` message `parentId`/kind ; type de retour statique = `ZStudyRepository<T>` (garde compile-time). Injections `R3-I4/I6` prouvées rouges.

- [ ] **T8 — Vérif verte rejouée + Dev Agent Record + Change Log** (AC7/AC8)
  - [ ] Rejouer § *Vérif verte* (RC HORS pipe R15) ; renseigner File List, tableau de vérif, injections R3 réelles.

---

## Injections R3 prévues (mutation → AC rouge → restauration R13) — verrous LOAD-BEARING

> **R27** : chaque garde est **co-livrée** avec le test qui rougit sous sa neutralisation. Résidu `grep INJECT lib/` = 0 avant `review`.

- **R3-I1 (AC1 — flux nu exact)** — dans un provider typé, remplacer `zStudyWatchAllProvider` par un flux transformé (`.map((l)=>l.reversed.toList())`) ⇒ `z_study_entity_providers_test` (assertion ordre `[[a],[a,b]]`) **rougit**.
- **R3-I2 (AC1 — seam typé / Type dans l'erreur)** — dégrader le message de `ZScopeError` (ou résoudre le mauvais type) ⇒ l'assertion `throwsA(isA<ZScopeError>())` + message nommant le Type concret **rougit** (le mauvais type est aussi une erreur compile-time).
- **R3-I3 (AC2 — isolement backend)** — ajouter `import 'package:cloud_firestore/...'` (ou `zcrud_firestore` au pubspec) dans `lib/src/study/` ⇒ `z_binding_backend_isolation_test` **rougit** (et `graph_proof` diverge).
- **R3-I4 (AC4 — folderId manquant → Left)** — dans `buildFolderScopedStudyRepository`, avaler le `Left` (défaut `folderId=''` toléré / chemin plat de repli) ⇒ le cas `folderId=''` du test firestore **rougit** (attendait `isLeft`).
- **R3-I5 (AC5 — auto-dispose)** — retirer `.autoDispose` d'un provider typé ⇒ `onCancel` non appelé, test **rougit**.
- **R3-I6 (AC3 — chemin nested exact)** — intervertir `collection`/`parentCollection` dans la règle composée ⇒ l'assertion `users/u1/study_folders/f1/study_documents` **rougit**.
- **R3-I7 (AC7 — graphe)** — ajouter une arête parasite (`zcrud_firestore`/`crypto`/`http` au pubspec du binding) ⇒ `graph_proof` compte ≠ 49 (ou arête interdite `→ zcrud_firestore`) ; tout cycle est fatal.

---

## Dev Notes

### Forme d'API retenue (guardrail, éviter la sur-ingénierie R12/R20)

- **(A) providers typés = instanciations MINCES** de la fabrique générique d'ES-10.1. Riverpod n'a pas de provider générique sur `T` ⇒ un bundle typé par entité est la forme canonique. Ne **PAS** ré-écrire la logique de flux/seam/auto-dispose (déjà POWERFUL en 10.1) — la tester ici prouve le **typage** et le **câblage**, pas la mécanique. Frontière R20 déclarée dans les ACs.
- **(B) fabrique folder-scopée = composition MINCE** des briques ES-3. **Générique-par-topologie** (`collection`/`parentCollection` en `String`) ⇒ **zéro couplage à un consommateur** (pas de nom lex codé en dur) et **zéro arête d'entité** dans `zcrud_firestore`. La valeur propre = assembler resolver+box repo en un appel, et **prouver** la propagation du `Left` folderId-manquant (AC4) + le chemin nested exact (AC3). Ne PAS réimplémenter le merge LWW / listener (portés par `ZOfflineFirstBoxRepository`).
- **Session/config = INTOUCHÉS** : `ZSessionConfigKey` + selector provider = clos en ES-10.1 (AC6). `ZStudySessionEngine` (`zcrud_session`) est un **runtime non persisté** (pas de `ZStudyRepository`) ⇒ **aucun** provider de repo « session ». Ne pas en inventer.
- **Podcast/annotation/tags/mindmap** : hors périmètre providers-repo de cette story (pas listés) ; consommables via la fabrique générique `zStudyWatchAllProvider<T>` d'ES-10.1 si besoin lex, sans nouveau bundle ici (bornage du fan-in à +4).

### Ne rien réinventer / ne rien casser (R21, régression)

- Réutiliser `zStudyRepositoryProvider`, `zStudyWatchAllProvider`, `ZcrudRiverpodScope`, `ZRiverpodResolver` (ES-10.1/E2-9) **tels quels**. Réutiliser `ZOfflineFirstBoxRepository`, `ZFirestorePathResolver`/`Rule`, `FirebaseZRepositoryImpl.fromRegistry`, `ZStudyLegacyCodec` (ES-3) **tels quels**.
- Les suites existantes (`test/study/*` d'ES-10.1, `test/presentation/*`, `test/purity/*`, `zcrud_firestore/test/*`) doivent **rester vertes** — ne pas les modifier.
- ⚠️ **DW-ES14-2 (rappel)** : `ZSmartNote` porte le slot `ZNoteAudio` ; pour typer l'audio, l'app câble `extensionParser: ZNoteAudio.fromJsonSafe` au constructeur nominal (la voie registre ne type pas le slot mais **préserve** le payload via `ZOpaqueNoteExtension`). Non bloquant pour le provider (le flux transporte le `ZSmartNote` tel que décodé par le repo injecté) — mentionner en dartdoc du bundle note.

### Invariants AD applicables (rappel, NON-NÉGOCIABLES)

AD-1 (acyclique, CORE OUT=0, fan-in SORTANT, baseline 45→49) · AD-2/AD-15/NFR-S5 (Riverpod confiné à `zcrud_riverpod` ; binding sans backend) · AD-4 (generics pour un PORT `ZStudyRepository<T>`, jamais pour la sérialisation) · AD-5/AD-11 (flux nus + `Either`, aucun `cloud_firestore` hors `zcrud_firestore`) · AD-6/AD-10 (seams throw actionnable ; folderId manquant → `Left` explicite) · AD-9/AD-14/AD-19 (offline-first, hook `validate`, `ZSyncMeta` hors-entité — portés par les briques ES-3, non redéclarés) · AD-24 (égalité config au binding — close en 10.1, non retouchée).

### Runner & fenêtre pub-get (R14/R15/R25)

- **R14** : `zcrud_riverpod` **ET** `zcrud_firestore` sont des packages **Flutter** → **`flutter test`** (jamais `dart test`).
- **R15** : capturer le **RC HORS pipe** (`flutter test …; echo "RC=$?"`) — jamais `| tail`/`| head` qui masque le code retour.
- **R25** : cette story **ajoute 4 dépendances** au binding ⇒ fenêtre `pub get`/bootstrap sensible : rejouer `dart pub get` (workspace) et confirmer résolution `workspace` sans conflit **avant** analyze/test. Story **SÉQUENTIELLE** (dépend d'ES-10.1, mute le workspace) — aucun autre workstream en vol.

### Project Structure Notes

- **NOUVEAUX** : `zcrud_riverpod/lib/src/study/z_study_entity_providers.dart`, `zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart`, `zcrud_riverpod/test/study/z_study_entity_providers_test.dart`, `zcrud_riverpod/test/study/z_binding_backend_isolation_test.dart`, `zcrud_firestore/test/z_folder_scoped_study_repository_test.dart`.
- **MODIFIÉS** : `zcrud_riverpod/pubspec.yaml` (4 deps + invariant), `zcrud_riverpod/lib/zcrud_riverpod.dart` (1 export), `zcrud_firestore/lib/zcrud_firestore.dart` (1 export).
- **INCHANGÉS (ne pas toucher)** : tout `zcrud_riverpod/lib/src/presentation/*` et `lib/src/study/{z_session_config_key.dart, z_study_providers.dart}` (ES-10.1), `zcrud_core/*`, `zcrud_study_kernel/*`, entités `zcrud_document`/`note`/`exam`/`flashcard` (CONSOMMÉES), briques ES-3 de `zcrud_firestore` (COMPOSÉES).
- Aucune `@ZcrudModel`/`@JsonSerializable` nouvelle ⇒ **aucun `*.g.dart` nouveau** attendu (rejouer `melos run generate` par prudence).
- API publique = barrels ; impl sous `lib/src/`.

### References

- [Source: epics-zcrud-study-2026-07-12/epics.md#Epic-ES-10 / Story-ES-10.2] — remplacement repo-par-repo, providers `ZStudyRepository<T>` + adapters `zcrud_firestore` nested, sans big-bang ni régression (SM-S1).
- [Source: stories/es-10-1-providers-riverpod-egalite-config.md] — fabrique générique `zStudyWatchAllProvider<T>` + seam `zStudyRepositoryProvider<T>` + `ZSessionConfigKey` (AD-24) ; réservation EXPLICITE à ES-10.2 des « providers typés concrets + adapters `zcrud_firestore` nested » ; patrons de test (ré-émission exacte, seam throw, auto-dispose).
- [Source: packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart] — `ZOfflineFirstBoxRepository<T> extends ZStudyRepository<T>` (constructeur, offline-first, backend confiné).
- [Source: packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart] — `ZFirestorePathRule.nestedUnderParent`, `resolveCollection` → chemin `String`/`Left`, garde `parentId` manquant, anti-réflexion.
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart] — port `ZStudyRepository<T>` (Template Method `save = validate→persist`, flux nus).
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-15/AD-24] · [architecture-zcrud-2026-07-09/architecture.md#AD-1/AD-5/AD-6/AD-10/AD-14] — bindings confinés ; graphe acyclique CORE OUT=0 ; flux nus + `Either` ; seams throw ; défensif.
- [Source: stories/epic-es-9-retrospective.md#R27/§5] — garde co-livrée avec test à rouge provoqué ; frontière R20 déclarée honnêtement (composition sur code déjà testé) ; runner R14/R15 ; rapport gate RÉEL.

---

## Vérif verte à rejouer (avant tout `review`/`done`) — RC HORS pipe (R15)

> Rejouée **réellement sur disque** par l'orchestrateur, jamais sur la foi du rapport dev.

1. **Codegen** — `dart run melos run generate` (aucun nouveau `*.g.dart` attendu ; confirme que rien n'est cassé).
2. **Bootstrap** (R25, 4 deps ajoutées) — `dart pub get` (workspace) sans conflit ni warning nouveau.
3. **Analyze** — `dart analyze packages/zcrud_riverpod packages/zcrud_firestore` → **RC=0** (0 issue).
4. **Tests (R14, Flutter)** — `flutter test packages/zcrud_riverpod; echo "RC=$?"` puis `flutter test packages/zcrud_firestore; echo "RC=$?"` → **RC=0** chacun. Attendu : suites ES-10.1/E2-9/ES-3 **inchangées vertes** + nouvelles suites (providers typés ×≥2, isolement backend binding, fabrique folder-scopée chemin+Left).
5. **Graphe (AC7)** — `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 49`** (45 → 49, +4 SORTANTES vers document/note/exam/flashcard ; **aucune** `→ zcrud_firestore`), **20 nœuds**.
6. **`dart run melos list`** — sanity (20 packages).
7. **Gates repo-wide (AC8, NON-NÉGOCIABLE)** — `dart run melos run analyze` **ET** `dart run melos run verify` → **VERTS repo-wide** (reserved-keys, secrets, codegen-distribution, isolement d'idiome, compat sérialisation). La vérif ciblée par package NE remplace PAS cette passe repo-wide.

---

## Dev Agent Record

### Agent Model Used

_(à renseigner par bmad-dev-story — skill réel)_

### Debug Log References

### Completion Notes List

### Vérif verte rejouée (RC HORS pipe, R15)

| Gate | Commande | RC / résultat |
|------|----------|---------------|
| Bootstrap (R25) | `dart pub get` | |
| Codegen | `dart run melos run generate` | |
| Analyze | `dart analyze packages/zcrud_riverpod packages/zcrud_firestore` | |
| Tests riverpod (R14) | `flutter test packages/zcrud_riverpod` | |
| Tests firestore (R14) | `flutter test packages/zcrud_firestore` | |
| Graphe (AC7) | `python3 scripts/dev/graph_proof.py` | |
| Sanity | `dart run melos list` | |
| Gates repo-wide (AC8) | `dart run melos run analyze` + `dart run melos run verify` | |

### File List

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-16 | 0.1 | Story créée (bmad-create-story, skill réel) — re-scope zcrud-side (providers typés + adapter folder-scopé), dette lex `DW-ES102-1` tracée — statut ready-for-dev | create-story |

---

## 🔴 DÉCISION D'ARCHITECTURE — RÉVISION ORCHESTRATEUR (2026-07-16, validée par l'utilisateur)

Le dev-story initial faisait dépendre `zcrud_riverpod` de 4 packages d'entités concrètes (`zcrud_document`/`zcrud_note`/`zcrud_exam`/`zcrud_flashcard`) pour livrer des **providers Riverpod TYPÉS par entité**. Un gate `melos run verify` **RED** a révélé un **conflit d'architecture** (détecté par R9, non masqué) :
- `zcrud_flashcard` est une entité **E9 interdite en v1.x** par la frontière **EX-3** (`example/test/boundary_deps_test.dart`) ; faire dépendre le binding réutilisable de `zcrud_flashcard` force tout consommateur (dont `example/`) à la tirer transitivement ⇒ violation EX-3 + échec de résolution `example/`.

**Décision (validée) : BINDING GÉNÉRIQUE (Option B).**
- ❌ **Retirés** : `z_study_entity_providers.dart` + son test, l'export barrel, et les **4 deps d'entités** de `zcrud_riverpod`. Le binding redevient **thin/générique** (AD-15) : deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` uniquement. Graphe **retour à 45 arêtes** (delta 0), aucun couplage binding→entité.
- ✅ **Conservé (livrable zcrud-side d'ES-10.2)** : `zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart` — fabrique **générique-par-topologie** `buildFolderScopedStudyRepository<T>` (compose les briques ES-3, retour `ZStudyRepository<T>` neutre, aucun `cloud_firestore` en signature). + le test d'isolation backend AC2 de `zcrud_riverpod` (garde de surface).
- ✅ **DÉFÉRÉ CÔTÉ APP (DW-ES102-1)** : les providers TYPÉS par entité deviennent des **one-liners app-side** (`zStudyWatchAllProvider<ZStudyDocument>(repo: …)`), instanciés par l'app hôte (lex/IFFD) dans sa session dédiée — jamais dans le binding réutilisable. Conforme au périmètre (aucun autre repo touché).

**Vérif verte après révision (RC hors pipe — R15)** : `dart pub get` RC=0 (`example` résout) · `flutter test` zcrud_riverpod RC=0/25 · zcrud_firestore RC=0/176 · graph_proof RC=0 (**45 arêtes**, ACYCLIQUE, CORE OUT=0, `zcrud_riverpod → {core, study_kernel}` seulement) · **`melos run verify` REPO-WIDE RC=0** (gate:reserved-keys/secrets/web/serialization OK ; frontière EX-3 respectée). Spot-check orchestrateur R3 sur l'adapter (B) : swap `collection`/`parentCollection` → AC3 chemin nested rougit (`users/u1/study_documents/f1/study_folders`, RC=1) → restauré.

**DW-ES102-2 (résolue par la décision)** : le conflit `example/` (overrides + boundary) disparaît puisque le binding ne tire plus d'entités.
