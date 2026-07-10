---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 9.3 : Dossiers & sessions d'étude — `ZStudyFolder` + `ZStudySession` (`zcrud_flashcard`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud (lex_douane « Étude », puis DODLP)**,
I want **les modèles canoniques d'organisation `ZStudyFolder` (container générique multi-type, rattachement INVERSE, hiérarchie 2 niveaux) et `ZStudySessionConfig` (filtres mode/tags/types/count), générés par `@ZcrudModel`, portant les slots d'extension AD-4, accompagnés des primitives PURES qui matérialisent leurs invariants — la validation de profondeur (≥3 niveaux rejeté) et la sélection filtrée des cartes de session — sans qu'une seule ligne de `zcrud_core` ne soit modifiée**,
so that **je puisse ranger mes cartes/notes/mindmaps dans des dossiers zéro-perte et rétro-compatibles, empêcher par conception une hiérarchie à plus de 2 niveaux au moment de l'écriture (repo E9-4), lancer une session filtrée (dossier + étiquettes + types + plafond) de façon déterministe et testable, et brancher les métadonnées douane/collaboration additives sans forker le package.**

## Contexte & cadrage (à lire avant de coder)

Troisième story de l'**epic E9 — Flashcards (`zcrud_flashcard`)**. Elle pose **uniquement les modèles d'organisation + leurs primitives d'invariant PURES** : entité `ZStudyFolder`, config persistée `ZStudySessionConfig`, enum `ZReviewMode` (6 modes), une primitive **pure-Dart** de validation de hiérarchie (2 niveaux max) et une primitive **pure-Dart** de sélection de session (filtres). **Aucun** dépôt, **aucune** persistance offline-first, **aucun** widget/état runtime de session ici.

E9-1 (done) a posé `ZFlashcard`/`ZChoice`/`ZFlashcardType`/`ZFlashcardSource` et **confirmé le patron hors-codegen** (câblage manuel de `extra`/`extension`/`source` autour du `toMap`/`fromMap` généré + `copyWith` à sentinelle `_$undefined`). E9-2 (done) a posé `ZRepetitionInfo`/`ZSrsScheduler`/`ZSm2Scheduler`/`ZSrsConfig`. **`ZFlashcard` porte déjà `folderId` + `subFolderId`** (E9-1) : le rattachement inverse est **déjà** côté carte ; E9-3 pose le **dossier** qui les reçoit et l'invariant de profondeur qui les encadre.

**Invariants d'architecture applicables :**

- **AD-3 (codegen = source unique de vérité)** [Source: architecture.md#AD-3] : `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` génèrent `toMap`/`fromMap`/`copyWith`, le `ZFieldSpec[]` et l'enregistrement au `ZcrudRegistry`. **Jamais** `reflectable`. `freezed` **non imposé**. Enums en **camelCase**, `@JsonKey(unknownEnumValue:)` (ou `defaultValue` sur `@ZcrudField`). Persistance **snake_case**.
- **AD-4 (extension : composition + `ZExtension` + `extra` + enums ouverts)** [Source: architecture.md#AD-4] : chaque entité canonique expose (1) un slot `ZExtension?` versionné, (2) un `Map<String,dynamic> extra` (défaut `const {}`). `ZStudyFolder` **ET** `ZStudySessionConfig` mixent `ZExtensible` (RÉUTILISÉ du cœur), comme `ZFlashcard`/`ZRepetitionInfo`. **Rejetés** : héritage de classes sérialisées, `sealed` inter-package, generics comme mécanisme de sérialisation.
- **AD-10 (schéma additif + désérialisation défensive)** [Source: architecture.md#AD-10] : ajout seulement entre versions mineures (nullable / `defaultValue`) ; un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`). Évolution **additive seulement**.
- **AD-14 (pureté des couches ; invariants au REPOSITORY, jamais dans l'entité)** [Source: architecture.md#AD-14 ; canonical-schema.md ligne 130, 263] : le `domain/` de `zcrud_flashcard` est **pur-Dart** (aucune dépendance Flutter/Firebase/Hive). **L'entité `ZStudyFolder` ne s'auto-valide JAMAIS** (elle est données + `copyWith`). L'invariant « 2 niveaux max » est une **primitive PURE réutilisable** (`ZResult<Unit>`) que le **repository (E9-4)** compose ; il n'est ni un assert de constructeur, ni un throw d'entité.
- **AD-5/AD-11 (erreurs = `Either<ZFailure,T>`)** [Source: architecture.md#AD-5,#AD-11] : la primitive de validation retourne un **`ZResult<Unit>` (= `Either<ZFailure, Unit>`)** ; violation de profondeur → **`Left(DomainFailure)`** (canonique : « `saveFolder` valide l'invariant 2 niveaux (`Left(DomainFailure)` si `depth>=3`, sans écrire) »). `Unit`/`unit` et `DomainFailure` sont **RÉUTILISÉS** du cœur.
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `zcrud_flashcard` **dépend de** `zcrud_core` et **réutilise ses APIs**. **CONTRAINTE DURE : `zcrud_flashcard` NE MODIFIE PAS `zcrud_core`.** Toutes les APIs nécessaires (`ZEntity`, `ZExtensible`, `ZExtension`, `ZResult`, `DomainFailure`, `Unit`/`unit`, annotations, `ZcrudRegistry`) existent déjà.

**Frontière E9-3 vs le reste de l'epic (NON-NÉGOCIABLE) :**

| Story | Périmètre | Dans E9-3 ? |
|---|---|---|
| E9-1 (done) | `ZFlashcard` (porte déjà `folderId`/`subFolderId`), `ZChoice`, `ZFlashcardType`, `ZFlashcardSource`. | ❌ (done) |
| E9-2 (done) | `ZRepetitionInfo` + `ZSrsScheduler`/`ZSm2Scheduler`/`ZSrsConfig`. | ❌ (done) |
| **E9-3 (ici)** | `ZStudyFolder` (entité codegen, extensible) ; `ZReviewMode` (6 modes) ; `ZStudySessionConfig` (filtres mode/tags/types/count, extensible) ; **primitive PURE** de validation de hiérarchie 2 niveaux (`ZResult<Unit>`, `Left(DomainFailure)` si `depth>=3`) ; **primitive PURE** de sélection filtrée de session. `archivedAt` soft-archive distinct du soft-delete. | ✅ |
| E9-4 | Dépôt offline-first des dossiers/cartes ; **appel** de la primitive de validation dans `saveFolder` (Left si depth≥3, sans écrire) ; cascade soft-delete bornée 450/batch ; `is_deleted` hors-entité `ZSyncMeta` ; matérialisation éphémère ; SRS top-level. | ❌ (E9-4) |
| E9-5 | Édition & widgets additifs ; **état runtime de session** (`queue`/`phase`/histogramme/réinsertion/`dues` vs `ahead`) ; libellés localisés. | ❌ (E9-5) |

> ⚠️ En E9-3 : **pas** de dépôt/persistance (offline-first, cascade, `is_deleted`, matérialisation = E9-4). **Pas** d'état runtime de session (`ZStudySessionState`, réinsertion, scopes `dues`/`ahead` = E9-5). **Pas** de widget/UI. **Pas** d'auto-validation dans l'entité (invariant = primitive pure appelée par le repo, AD-14). Le bloc partage V2c (`isPublic`…) est **déclaré mais INERTE** (défauts sûrs, aucune logique de partage active).

## Acceptance Criteria

1. **`ZReviewMode` — 6 modes, camelCase, défensif (AD-3/AD-10).** Un enum `ZReviewMode` expose exactement les 6 valeurs **génériques** : `spaced`, `learn`, `list`, `test`, `whiteExam`, `cramming`. Valeurs persistées en **camelCase** (= `name`, ex. `"whiteExam"`). Une valeur inconnue/absente retombe **défensivement** sur `spaced` (`@JsonKey(unknownEnumValue: ZReviewMode.spaced)` ou `defaultValue: ZReviewMode.spaced` sur le champ `mode`), **sans throw**. Documenter (sans l'implémenter ici) que « seuls `spaced`/`learn` écrivent du SRS » — c'est le flux de révision E9-4/E9-5, hors périmètre. Testé : chaque valeur round-trip ; `"totallyUnknownMode"` → `spaced` ; clé absente → `spaced`.

2. **`ZStudyFolder` — entité canonique codegen (AD-3), container générique multi-type.** `@ZcrudModel(kind: 'study_folder', fieldRename: ZFieldRename.snake)` sur une classe `const` pur-données `class ZStudyFolder extends ZEntity with ZExtensible` portant : `id: String?` (`@ZcrudId`, nullable pour l'éphémère, jamais attribué par l'entité), `title: String` (requis, `ZValidatorSpec.required()`), `colorKey: String` (défaut `''`, clé de thème libre résolue côté UI), `parentId: String?` (`null` = racine ; profondeur validée au repo), `ownerId: String` (défaut `''` ; uid Firebase ou `'local'` hors-ligne — attribué par l'app, jamais par l'entité), `archivedAt: DateTime?` (soft-archive réversible — AC5), `createdAt: DateTime?`, `updatedAt: DateTime?` (clé LWW, **DANS l'entité** — cf. AC6), + bloc partage V2c inerte (AC4) + slots d'extension (AC3). `melos run generate` produit `z_study_folder.g.dart` (gitignoré) avec `_$…FromMap`/`toMap` + enregistrement `ZcrudRegistry`. Persistance **snake_case** (`color_key`, `parent_id`, `owner_id`, `archived_at`, `created_at`, `updated_at`). `isEphemeral` provient de `ZEntity` (`id == null`), non redéfini. **Rattachement INVERSE** documenté : le dossier **ne liste JAMAIS** ses items ; chaque item (carte `folderId`/`subFolderId`, note, mindmap) porte sa clé de rattachement. Round-trip zéro-perte testé.

3. **Slots d'extension AD-4 (`extra` + `ZExtension?`) sur les DEUX entités.** `ZStudyFolder` **et** `ZStudySessionConfig` mixent **`ZExtensible` (RÉUTILISÉ de `zcrud_core`)** : `extra: Map<String,dynamic>` (défaut `const {}`, jamais `null`, round-trip des clés inconnues préservé, rendu **non-modifiable**) + `extension: ZExtension?` (slot type additif versionné, défaut `null`, parsé défensivement via un parser injecté + `ZExtension.guard`). **Même patron de câblage hors-codegen que `ZFlashcard` (E9-1)** : `extra`/`extension` superposés autour du `toMap`/`fromMap` généré ; `copyWith` **à sentinelle `_$undefined`** couvrant ces canaux (le `copyWith` généré, masqué, les remettrait à leurs défauts → perte silencieuse évitée). Clés réservées dérivées de `$ZStudyFolderFieldSpecs`/`$ZStudySessionConfigFieldSpecs` (+ `extension`) pour rester synchrones avec le codegen. Testé : `extra` inconnu préservé au round-trip ; `extension` de `formatVersion` non gérée → `null`, parent survit.

4. **Bloc partage V2c déclaré mais INERTE (canonique, discipline « figer tôt »).** `ZStudyFolder` déclare les champs de collaboration V2c avec **défauts sûrs, sans aucune logique active** : `isPublic: bool` (défaut `false`), `sharedWith: List<String>` (défaut `const []`), `canBeJoinedWithLink: bool` (défaut `false`), `coWorkersCanInviteOthers: bool` (défaut `false`), `shareId: String?` (défaut `null`). Persistés snake_case (`is_public`, `shared_with`, `can_be_joined_with_link`, `co_workers_can_invite_others`, `share_id`). Ils **round-trip** mais ne déclenchent **aucun** comportement (pas de partage réel en E9-3). Les métadonnées libres `relatedTopics`/`folderExplanation` (génériques) et `countryCode` (douane-spécifique) **NE sont PAS des champs de première classe** : elles transitent par **`extra`** (canonique les annote « à pousser dans `extra` ») — leur préservation au round-trip est couverte par le mécanisme `extra` (AC3), sans polluer le schéma générique. Testé : round-trip du bloc V2c avec valeurs non-défaut ; `countryCode`/`relatedTopics` présents dans une map d'entrée ressortent via `extra`.

5. **`archivedAt` — soft-archive réversible, DISTINCT du soft-delete (canonique).** Le soft-**archive** (`archivedAt: DateTime?`) est un champ **DANS l'entité**, réversible : archiver = poser `archivedAt` (via `copyWith`) ; désarchiver = le remettre à `null` (sentinelle). Un getter dérivé **`bool get isArchived => archivedAt != null`** est exposé. Le soft-**delete** (`is_deleted`) est une métadonnée **hors-entité** (`ZSyncMeta`, E5/E9-4) : `ZStudyFolder` **ne déclare AUCUN** champ `isDeleted`/`is_deleted` (vérifié par test : la map persistée ne contient pas cette clé). Archiver un dossier **ne le supprime pas** et inversement. Testé : `archivedAt` fixée ⇒ `isArchived == true`, round-trip ; `copyWith(archivedAt: null)` ⇒ `isArchived == false` (réversibilité par sentinelle) ; absence de clé `is_deleted` dans `toMap`.

6. **`updatedAt` DANS l'entité (clé LWW) — divergence documentée.** `ZStudyFolder.updatedAt` est un **champ de première classe** de l'entité (contrairement à `ZMindmap` qui le porte hors-entité `ZSyncMeta`). C'est la **clé de merge LWW** (E9-4). La story documente explicitement cette divergence assumée (canonique : « `updatedAt` ; ici DANS l'entité (divergence vs Mindmap) »). Aucune standardisation `ZSyncMeta` universelle n'est tranchée ici (open question canonique #3) — E9-3 reste fidèle à `StudyFolder`. Testé : `updatedAt` round-trip zéro-perte.

7. **`ZStudySessionConfig` — filtres persistés codegen (FR-18, AD-3).** `@ZcrudModel(kind: 'study_session_config', fieldRename: ZFieldRename.snake)` sur une classe `const` pur-données `class ZStudySessionConfig with ZExtensible` (pas de `ZEntity` : pas d'`id` — c'est une config de valeur) portant **exactement** : `mode: ZReviewMode` (défaut `spaced`, AC1), `folderId: String?` (`null` = **toutes** les cartes éligibles, pas de filtre dossier), `tagIds: List<String>?` (`null` = pas de filtre étiquettes ; sinon filtre par intersection — AC8), `types: List<ZFlashcardType>?` (`null` = pas de filtre type ; sinon filtre par appartenance — AC8), `count: int?` (`null` = illimité ; sinon plafond du nombre de cartes) + slots d'extension (AC3). Persistance snake_case (`folder_id`, `tag_ids`). `melos run generate` produit `z_study_session_config.g.dart`. **NOTE codegen** : si le générateur ne (dé)sérialise pas nativement `List<ZFlashcardType>?` (liste d'enum), câbler `types` **hors-codegen** (comme `source` en E9-1) : décoder chaque élément défensivement en `ZFlashcardType` (valeur inconnue → ignorée ou repli `openQuestion`, documenter le choix), sérialiser en liste de `name` camelCase — vérifier le comportement réel via `melos run generate` et adopter le repli manuel si nécessaire (AD-10, jamais de throw). Round-trip zéro-perte testé (dont un `mode` inconnu → `spaced`, `types` inconnu défensif).

8. **Sélection de session = primitive PURE filtrée (FR-18, AD-14).** Une primitive **pure-Dart sans état** applique les filtres d'une `ZStudySessionConfig` à une collection de `ZFlashcard` candidates et retourne la sélection. Choix d'API (au dev, documenté) : soit un prédicat `bool matches(ZFlashcard card)` sur la config + une fonction `List<ZFlashcard> selectFrom(Iterable<ZFlashcard> candidates)`, soit une classe utilitaire dédiée (`ZStudySessionSelector`). Sémantique **exacte et testée** :
   - `folderId == null` ⇒ aucun filtre dossier ; sinon ne retenir que les cartes dont `card.folderId == config.folderId` **ou** `card.subFolderId == config.folderId` (le dossier cible couvre ses sous-dossiers — cf. rattachement inverse 2 niveaux).
   - `tagIds == null` (ou vide ⇒ documenter : traité comme « pas de filtre ») ⇒ aucun filtre étiquettes ; sinon ne retenir que les cartes ayant **au moins une** étiquette en commun (`card.tagIds ∩ config.tagIds ≠ ∅`).
   - `types == null` (ou vide) ⇒ aucun filtre type ; sinon ne retenir que les cartes dont `config.types.contains(card.type)`.
   - `count == null` ⇒ illimité ; sinon **tronquer** la sélection filtrée à `count` éléments max (`count <= 0` ⇒ documenter : sélection vide, sans throw). L'ordre d'entrée est préservé (déterministe ; aucune notion de `dues`/`ahead`/mélange — E9-5).
   Les filtres se **composent en ET** (dossier ∧ tags ∧ types) puis le plafond `count` s'applique. Pure, déterministe, **aucun** I/O ni horloge. Testé : chaque filtre isolément, la composition, `count` (troncature + `null` illimité + `<=0`), et le cas « config vide » (tout `null`) ⇒ toutes les cartes retournées telles quelles.

9. **Validation de hiérarchie 2 niveaux = primitive PURE `ZResult<Unit>` (canonique, AD-5/AD-11/AD-14).** Une primitive **pure-Dart** encode l'invariant « **2 niveaux max** » que le repository E9-4 appellera dans `saveFolder` (jamais l'entité). Signature recommandée (au dev, documentée) :
   `ZResult<Unit> validatePlacement({required String? parentId, ZStudyFolder? parent, String? selfId})`
   Sémantique **exacte et testée** (profondeur 1-indexée, racine = niveau 1) :
   - `parentId == null` ⇒ dossier **racine** (niveau 1) ⇒ **`Right(unit)`**.
   - `parentId != null` **et** `parent != null` **et** `parent.parentId == null` ⇒ le parent est une racine, l'enfant est **niveau 2** ⇒ **`Right(unit)`**.
   - `parentId != null` **et** `parent != null` **et** `parent.parentId != null` ⇒ placer sous un enfant créerait un **niveau 3** ⇒ **`Left(DomainFailure(...))`** (message explicite « profondeur 2 niveaux max »), **sans** rien écrire.
   - Garde d'intégrité : `selfId != null && parentId == selfId` (dossier son propre parent) ⇒ **`Left(DomainFailure)`**.
   - `parentId != null` **et** `parent == null` (parent introuvable/non résolu) ⇒ **`Left(DomainFailure)`** (rattachement à un parent inexistant refusé ; le repo résout le parent avant d'appeler). Documenter ce contrat.
   `Unit`/`unit`/`DomainFailure`/`ZResult` sont **RÉUTILISÉS** du cœur (aucun nouveau type de failure). Pure, sans I/O. Testé : racine OK ; enfant de racine OK (niveau 2) ; petit-enfant rejeté (niveau 3, `Left(DomainFailure)`) ; auto-parent rejeté ; parent manquant rejeté. **L'entité `ZStudyFolder` ne contient AUCUN de ces contrôles** (vérifié : constructeur sans assert de profondeur, aucun throw — AD-14).

10. **Désérialisation défensive de bout en bout (AD-10, gate E2-10).** `ZStudyFolder.fromMap` et `ZStudySessionConfig.fromMap` sur des maps **réellement corrompues** : map `{}` (requis absents → défauts sûrs : `title=''`, `owner_id=''`, `color_key=''`, booléens V2c `false`, listes `const []`) ; `parent_id`/`archived_at`/`created_at`/`updated_at` illisibles → `null` ; `shared_with` non-liste → `const []` ; `mode` inconnu → `spaced` ; `types` avec élément inconnu → décodé défensivement (ignoré/repli) ; `count`/`tag_ids` absents → `null` ; `extension` corrompue → `null` ; clés inconnues → `extra`. **Aucun** cas ne fait échouer le parent. Testé sur maps corrompues (pas seulement happy-path).

11. **Isolation, barrel & vérif verte (gates E1-3/E2-10, AD-1).** `zcrud_flashcard/lib/src/domain/` reste **pur-Dart** ; **aucune modification de `zcrud_core`** (vérifié : `git status` ne montre aucun fichier `packages/zcrud_core/**` modifié par la story). Le barrel `lib/zcrud_flashcard.dart` exporte `ZStudyFolder`, `ZReviewMode`, `ZStudySessionConfig`, la primitive de sélection et la primitive de validation (en **masquant** toute extension générée qui rouvrirait une voie d'écriture concurrente, à l'image du `hide ZRepetitionInfoZcrud` d'E9-2 — masquer `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` si leur `copyWith`/`toMap` générés doivent rester internes). `melos run generate` OK → `melos run analyze` RC=0 (lint anti-`reflectable`, scan secrets) → `flutter test` (package `zcrud_flashcard`) RC=0. Les tests de rétro-compat (AC10) passent.

## Tasks / Subtasks

- [x] **Tâche 1 — Enum `ZReviewMode` (AC1)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_review_mode.dart` : `enum ZReviewMode { spaced, learn, list, test, whiteExam, cramming }`.
  - [x] Le champ `mode` de `ZStudySessionConfig` porte `@ZcrudField(defaultValue: ZReviewMode.spaced)` (ou `@JsonKey(unknownEnumValue:)` projeté par le générateur) — inconnu → `spaced`, persisté camelCase (`name`).
  - [x] Documenter (dartdoc) « seuls `spaced`/`learn` écrivent du SRS » comme note de flux (E9-4/E9-5), sans l'implémenter.

- [x] **Tâche 2 — Entité `ZStudyFolder` (AC2, AC3, AC4, AC5, AC6)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_study_folder.dart` : `@ZcrudModel(kind: 'study_folder', fieldRename: ZFieldRename.snake)`, `class ZStudyFolder extends ZEntity with ZExtensible`, classe `const` pur-données.
  - [x] Champs exactement selon AC2 + bloc V2c inerte AC4 ; `@ZcrudId()` sur `id` ; `title` requis + `ZValidatorSpec.required()` ; défauts sûrs (`colorKey=''`, `ownerId=''`, `isPublic=false`, `sharedWith=const []`, etc.).
  - [x] Getter dérivé `bool get isArchived => archivedAt != null` (AC5). **NE PAS** déclarer `isDeleted`/`is_deleted` (AC5).
  - [x] Implémenter les slots `ZExtensible` (`extra` défaut `const {}` + `extension` `ZExtension?`) et les **câbler manuellement** dans `fromMap`/`toMap`/`copyWith` autour du code généré — **calquer exactement `z_flashcard.dart`** (helpers `_extraFrom`, `_reservedKeys` dérivées de `$ZStudyFolderFieldSpecs` + `'extension'`, `_decodeExtension`, sentinelle `_$undefined`, `==`/`hashCode`).
  - [x] `factory ZStudyFolder.fromMap(map, {ZFolderExtensionParser? extensionParser})` (délègue au `_$ZStudyFolderFromMap` généré défensif puis superpose `extra`/`extension`).
  - [x] `part 'z_study_folder.g.dart';` (généré, gitignoré, jamais committé/édité).

- [x] **Tâche 3 — Enum + config `ZStudySessionConfig` (AC1, AC3, AC7)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_study_session_config.dart` : `@ZcrudModel(kind: 'study_session_config', fieldRename: ZFieldRename.snake)`, `class ZStudySessionConfig with ZExtensible`, classe `const` pur-données.
  - [x] Champs exactement selon AC7 (`mode`/`folderId`/`tagIds`/`types`/`count`) + slots d'extension AC3 (même patron hors-codegen).
  - [x] Gérer `types: List<ZFlashcardType>?` : d'abord tenter le codegen (`melos run generate`) ; **si** la liste d'enum n'est pas (dé)sérialisée nativement, câbler `types` **hors-codegen** (décodage défensif par élément → `ZFlashcardType`, encodage en `name` camelCase). Documenter le chemin retenu dans le dartdoc + Completion Notes.
  - [x] `factory ZStudySessionConfig.fromMap` défensif + `copyWith` à sentinelle + `==`/`hashCode`.

- [x] **Tâche 4 — Primitive PURE de sélection de session (AC8)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_study_session_selector.dart` (ou méthodes sur `ZStudySessionConfig`) : `matches(ZFlashcard)` + `selectFrom(Iterable<ZFlashcard>) → List<ZFlashcard>`.
  - [x] Implémenter la sémantique EXACTE d'AC8 (folder couvre sous-dossier ; tags = intersection non vide ; types = appartenance ; composition ET ; `count` troncature ; `null`/vide = pas de filtre ; `count<=0` = vide ; ordre préservé). **Pur, sans I/O ni horloge.**

- [x] **Tâche 5 — Primitive PURE de validation de hiérarchie 2 niveaux (AC9)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_study_folder_hierarchy.dart` : `ZResult<Unit> validatePlacement({required String? parentId, ZStudyFolder? parent, String? selfId})`.
  - [x] Implémenter la sémantique EXACTE d'AC9 (racine OK ; enfant-de-racine OK ; petit-enfant `Left(DomainFailure)` ; auto-parent `Left` ; parent manquant `Left`). Réutiliser `unit`/`DomainFailure`/`ZResult` du cœur. **NE PAS** mettre cette logique dans l'entité (AD-14).

- [x] **Tâche 6 — Barrel + isolation (AC11)**
  - [x] Étendre `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : exporter `ZStudyFolder`, `ZReviewMode`, `ZStudySessionConfig`, la primitive de sélection et la primitive de validation ; **masquer** (`hide`) toute extension générée rouvrant une voie d'écriture concurrente (aligné sur `hide ZRepetitionInfoZcrud`).
  - [x] Confirmer `git status` : **aucun** fichier `packages/zcrud_core/**` modifié.

- [x] **Tâche 7 — Tests (AC1..AC10)**
  - [x] Créer les tests sous `packages/zcrud_flashcard/test/` (`*_test.dart`). Importer le barrel `package:zcrud_core/zcrud_core.dart` là où `ZEntity`/`ZExtensible`/`ZExtension` sont requis (comme E9-1/E9-2 : tests sous `flutter test`) ; `package:zcrud_core/edition.dart` suffit pour la surface pure.
  - [x] Couvrir : `ZReviewMode` round-trip + repli `spaced` ; `ZStudyFolder` round-trip complet + `isArchived` + réversibilité archive + absence de `is_deleted` + bloc V2c + `extra`/`extension` défensifs + `relatedTopics`/`countryCode` via `extra` ; `ZStudySessionConfig` round-trip + `types` défensif ; **sélection** (chaque filtre, composition, `count`, config vide) ; **validation hiérarchie** (racine/niveau 2/niveau 3 rejeté/auto-parent/parent manquant) ; désérialisation défensive sur maps corrompues (AC10, gate E2-10).

- [x] **Tâche 8 — Vérif verte (AC11)**
  - [x] `dart run melos run generate` → `dart run melos run analyze` (RC=0) → `flutter test` sur `zcrud_flashcard` (RC=0). Confirmer `git status` : **aucun** fichier `packages/zcrud_core/**` modifié.

## Dev Notes

### APIs `zcrud_core` à RÉUTILISER (ne rien recréer — AD-1, contrainte dure)

Tout le nécessaire existe déjà. **Ne pas** réimplémenter, **ne pas** modifier `zcrud_core` :

- **`ZEntity`** (`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:19`) — base `const` : `String? get id` + `bool get isEphemeral => id == null`. `ZStudyFolder extends ZEntity`.
- **`ZExtensible`** (`packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:18`) — mixin `ZExtension? get extension` + `Map<String,dynamic> get extra`. Helper `zExtraRead<T>(extra, key)` pour lecture typée défensive (utile si l'app relit `countryCode`/`relatedTopics` d'`extra`).
- **`ZExtension`** (`packages/zcrud_core/lib/src/domain/extension/z_extension.dart:25`) — base `abstract const` : `int get formatVersion`, `Map<String,dynamic> toJson()`, statique `ZExtension.guard<T>(parse)` (repli `null`). Base **`abstract`, jamais `sealed`**.
- **`ZResult<T>` / `DomainFailure` / `Unit` / `unit`** — `ZResult<T> = Either<ZFailure, T>` (`packages/zcrud_core/lib/src/domain/failures/z_failure.dart:93`) ; `DomainFailure extends ZFailure` (l.44) ; `Either`/`Left`/`Right`/`Unit`/`unit` réexportés curatés par le barrel `package:zcrud_core/zcrud_core.dart:11`. **C'est exactement le contrat de retour de la primitive de validation (AC9).**
- **`ZcrudRegistry`** (`packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart`) — alimenté **par le codegen** de `@ZcrudModel`.
- **Annotations** `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` (`packages/zcrud_annotations/lib/...`) — patron E2-5 ; `@ZcrudModel(kind:, fieldRename: ZFieldRename.snake)` ; **zéro closure** dans les annotations.

### Patron d'implémentation de référence (à imiter à la lettre)

- **`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` (E9-1) = LE gabarit hors-codegen.** Reproduire **exactement** : la factory `fromMap` qui délègue à `_$…FromMap` puis superpose les canaux hors-codegen ; le `toMap({...})` qui étale `extra` avant le `toMap()` généré ; le `copyWith` **à sentinelle `_$undefined`** couvrant tous les champs (y compris `extra`/`extension`) ; `_reservedKeys` dérivées de `$…FieldSpecs` + `'extension'` ; `_extraFrom` rendu **non-modifiable** ; `_decodeExtension` guardé ; `==`/`hashCode` avec `_listEquals`/`_mapEquals`/`_mapHash`. La sentinelle `_$undefined` est **générée dans le `.g.dart`** de chaque modèle (cf. `z_flashcard.g.dart:10`) — disponible dans le fichier `part`.
- **`packages/zcrud_flashcard/lib/src/domain/z_choice.dart` (E9-1)** — patron du sous-modèle `@ZcrudModel` simple (`fromMap` = `_$…FromMap`, `==`/`hashCode`).
- **`packages/zcrud_flashcard/lib/zcrud_flashcard.dart`** — le barrel masque déjà `ZRepetitionInfoZcrud` (E9-2) : même stratégie `hide` pour les extensions générées qu'on veut garder internes.
- **`ZFlashcardType`** (E9-1, `z_flashcard_type.dart`) — patron exact de l'enum défensif (`ZReviewMode` en est le clone : 6 valeurs, repli sur une valeur sûre).

### Schéma canonique (source de vérité des champs)

`docs/canonical-schema.md` §2.3 (`ZStudyFolder`, `FolderContentCount`, `ZStudySessionConfig`, `ZStudySessionState`, enums de session). Points saillants :
- **`ZStudyFolder`** : container **générique multi-type** (un dossier, N types hétérogènes : cartes, notes, mindmaps) ; **rattachement INVERSE** (l'item porte `folder_id`/`sub_folder_id`, le dossier ne liste jamais) ; **2 niveaux max**, invariant **porté par le repository** (ligne 130, 263, 300 : `saveFolder` → `Left(DomainFailure)` si `depth>=3`, sans écrire) ; `archivedAt` = soft-archive **distinct** du soft-delete ; `updatedAt` **DANS l'entité** (divergence vs Mindmap, ligne 143 & open question #3) ; bloc partage V2c **déclaré mais inerte** (learning #1, #275) ; `relatedTopics`/`folderExplanation`/`countryCode` → **`extra`** (lignes 145-146).
- **`ZStudySessionConfig`** : `mode`/`folderId`/`tagIds`/`types`/`count` ; `mode` défensif → `spaced` ; `folderId==null` = toutes cartes ; `count==null` = illimité (lignes 152-160).
- **`ZStudySessionState`** (runtime) : `queue`/`phase`/histogramme/réinsertion/`dues` vs `ahead` = **E9-5**, PAS ici (ligne 162).
- **Offline-first** (`is_deleted` hors-entité, cascade 450/batch, LWW `updated_at`, `StudySyncManager`) = **E9-4**, PAS ici (ligne 166, 300-305).

### Décisions de portée verrouillées pour E9-3

- **Invariant 2 niveaux = primitive PURE `ZResult<Unit>`, jamais dans l'entité (AD-14).** Le canonique le place « au repository » ; E9-3 le livre comme **fonction pure réutilisable et testable maintenant** (sans Firebase), que le dépôt E9-4 compose dans `saveFolder`. C'est fidèle à AD-14 (entité = données ; invariant = repo) tout en rendant la règle unit-testable dès E9-3. **Ne PAS** en faire un `assert`/throw de constructeur.
- **Profondeur 1-indexée** (racine = niveau 1) : niveaux 1 et 2 autorisés, niveau ≥ 3 rejeté (`depth >= 3` du canonique). Un dossier enfant valide a un parent **racine** (`parent.parentId == null`).
- **Bloc partage V2c = déclaré mais INERTE** (défauts sûrs, aucune logique) : discipline « figer tôt » du canonique (évite une migration de schéma quand la collaboration sera branchée). `relatedTopics`/`folderExplanation`/`countryCode` **NON** first-class → `extra` (schéma générique lean, `countryCode` étant douane-spécifique).
- **`ZStudySessionConfig` sans `ZEntity`** : config de valeur sans `id` (mixe seulement `ZExtensible`), comme `ZRepetitionInfo` (E9-2) qui porte `flashcardId` et non `id`.
- **Pas d'état runtime de session** (queue/phase/réinsertion/scopes `dues`/`ahead`) : E9-5. E9-3 ne fournit que la **config** persistée + la **sélection** pure et déterministe.
- **`types` (liste d'enum) codegen incertain** : vérifier le support réel du générateur ; repli hors-codegen défensif si nécessaire (AC7/Tâche 3). Documenter le chemin retenu.

### Alerte dépendance orchestrateur (parallélisation)

**Aucune édition de `zcrud_core` n'est requise ni planifiée.** Toutes les APIs (`ZEntity`, `ZExtensible`, `ZExtension`, `ZResult`/`DomainFailure`/`unit`, annotations, `ZcrudRegistry`) existent et sont **réutilisées**. Fichiers touchés : **uniquement** `packages/zcrud_flashcard/**` (+ code généré gitignoré). Aucun point de contact avec les workstreams parallèles E5 (`zcrud_firestore`) et E10 (`zcrud_mindmap`) → parallélisation à fichiers disjoints respectée. Si un besoin **réel** d'éditer `zcrud_core` émergeait (ex. un helper manquant), **NE PAS** l'implémenter : le **signaler à l'orchestrateur** pour re-séquencer le fichier `zcrud_core` (une seule story écrit le cœur à la fois).

### Testing standards

- Fichiers `*_test.dart` sous `packages/zcrud_flashcard/test/`. Les modèles réutilisant `ZEntity`/`ZExtensible`/`ZExtension` (non exposés par `edition.dart`) importent le barrel `package:zcrud_core/zcrud_core.dart` → tests sous **`flutter test`** (convention établie E9-1/E9-2). Les primitives pures peuvent se tester avec `edition.dart` seul.
- Couverture **défensive réelle** exigée (maps corrompues, pas happy-path seul) — gate E2-10.
- Le code généré (`*.g.dart`) est produit par `melos run generate` (build_runner réel), **gitignoré**, jamais édité/committé.

### Project Structure Notes

- Impl sous `lib/src/domain/` (couche pure) ; API via le barrel `lib/zcrud_flashcard.dart`.
- Fichiers snake_case : `z_review_mode.dart`, `z_study_folder.dart`, `z_study_session_config.dart`, `z_study_session_selector.dart`, `z_study_folder_hierarchy.dart` (noms indicatifs ; le dev peut regrouper sélecteur/validateur si cohérent, tant que le barrel exporte l'API publique).
- `pubspec.yaml` de `zcrud_flashcard` a déjà les deps/dev-deps nécessaires (E9-1/E9-2 : `zcrud_core`, `zcrud_annotations`, `zcrud_generator`, `build_runner`, `flutter_test`). Aucune dépendance lourde runtime à ajouter au domaine.

### References

- [Source: epics.md#E9] — Story E9-3 (ZStudyFolder rattachement inverse 2 niveaux validés au repo ; ZStudySession filtres mode/tags/types/count FR-18 ; ZStudyFolder porte extra + ZExtension? AD-4).
- [Source: architecture.md#AD-1,#AD-3,#AD-4,#AD-5,#AD-10,#AD-11,#AD-14]
- [Source: docs/canonical-schema.md#2.3] — ZStudyFolder / FolderContentCount / ZStudySessionConfig / ZStudySessionState / enums de session ; lignes 130 (2 niveaux au repo), 141 (archivedAt distinct), 143 (updatedAt dans l'entité), 145-146 (relatedTopics/countryCode → extra), 152-160 (config filtres), 263 & 300 (invariant au repo, Left(DomainFailure) si depth≥3).
- [Source: docs/canonical-schema.md learnings #1, #263, #275] — figer tôt (V2c inerte) ; invariants au repository ; discipline de schéma.
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart] — gabarit hors-codegen (extra/extension/copyWith sentinelle/reservedKeys/==/hashCode).
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart] — patron enum défensif (clone pour ZReviewMode).
- [Source: packages/zcrud_flashcard/lib/src/domain/z_choice.dart] — patron sous-modèle @ZcrudModel.
- [Source: packages/zcrud_flashcard/lib/zcrud_flashcard.dart] — barrel + stratégie `hide` des extensions générées.
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart:44,93] — DomainFailure, ZResult.
- [Source: packages/zcrud_core/lib/zcrud_core.dart:11] — réexport curaté Either/Left/Right/Unit/unit.
- [Source: _bmad-output/implementation-artifacts/stories/e9-1-zflashcard-zchoice-type-provenance.md, e9-2-srs-pluggable-zsrsscheduler.md] — patrons établis (câblage hors-codegen, tests défensifs, isolation zcrud_core).
- [Source: CLAUDE.md] — Key Don'ts (ne pas éditer/committer `*.g.dart` ; désérialisation défensive ; pas de gestionnaire d'état dans le domaine ; enums camelCase).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `dart run build_runner build --delete-conflicting-outputs` (packages/zcrud_flashcard) : 8 outputs, RC=0 — `z_study_folder.g.dart` + `z_study_session_config.g.dart` générés.
- `dart analyze packages/zcrud_flashcard` : `No issues found!`, RC=0.
- `flutter test` (packages/zcrud_flashcard) : `All tests passed!`, RC=0, **117 tests** (59 baseline E9-1/E9-2 + 58 nouveaux E9-3, non-régression OK).

### Completion Notes List

- **`ZReviewMode` (AC1)** : enum 6 valeurs génériques (`spaced`/`learn`/`list`/`test`/`whiteExam`/`cramming`), persisté camelCase (`name`), repli défensif `spaced` via `@ZcrudField(defaultValue: ZReviewMode.spaced)` sur `mode`. Note de flux « seuls spaced/learn écrivent du SRS » documentée (non implémentée).
- **`ZStudyFolder` (AC2/AC4/AC5/AC6)** : `@ZcrudModel(kind:'study_folder', fieldRename: ZFieldRename.snake)`, `extends ZEntity with ZExtensible`, `const` pur-données. `isArchived` getter dérivé ; **aucun** champ `is_deleted` (vérifié par test). `updatedAt` DANS l'entité (LWW). Bloc V2c inerte (défauts sûrs, round-trip). `relatedTopics`/`folderExplanation`/`countryCode` via `extra` (non first-class), préservés au round-trip.
- **`ZStudySessionConfig` (AC7)** : `with ZExtensible` (pas de `ZEntity`, config de valeur). `types: List<ZFlashcardType>?` géré **NATIVEMENT** par le générateur (catégorie `listEnum`) — décodage défensif par élément (inconnu ignoré via `whereType`), encodage en `name` camelCase ; **aucun** câblage hors-codegen requis (chemin natif retenu après vérif `melos run generate`).
- **Slots AD-4 (AC3)** : `extra`/`extension` câblés hors-codegen sur les deux entités (patron `ZFlashcard` E9-1 : sentinelle `_$undefined`, `_reservedKeys` dérivées des `$…FieldSpecs`+`'extension'`, `_extraFrom` non-modifiable, `_decodeExtension` guardé, `==`/`hashCode`).
- **`ZStudySessionSelector` (AC8)** : primitive pure — `matches` (filtres dossier∧tags∧types) + `selectFrom` (filtres puis plafond `count`). Dossier couvre sous-dossier ; tags = intersection non vide ; types = appartenance ; `count==null` illimité, `count<=0` vide, troncature ordre-préservé. Sans I/O ni horloge.
- **`validatePlacement` (AC9)** : primitive pure `ZResult<Unit>` — auto-parent (Left) → racine (Right) → parent manquant (Left) → parent.parentId!=null ⇒ niveau 3 (Left) → parent racine ⇒ niveau 2 (Right). Réutilise `DomainFailure`/`unit`/`ZResult` du cœur. **Aucune** logique de profondeur dans l'entité (AD-14, vérifié par test).
- **Isolation (AC11)** : **aucune modification de `zcrud_core`** — toutes les APIs (`ZEntity`/`ZExtensible`/`ZExtension`/`ZResult`/`DomainFailure`/`unit`/annotations/`ZcrudRegistry`) réutilisées. Barrel masque `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` (extensions générées) comme `hide ZRepetitionInfoZcrud` (E9-2). Aucun besoin `zcrud_core` détecté.

### File List

**Créés (source, `packages/zcrud_flashcard/`) :**
- `lib/src/domain/z_review_mode.dart`
- `lib/src/domain/z_study_folder.dart`
- `lib/src/domain/z_study_session_config.dart`
- `lib/src/domain/z_study_session_selector.dart`
- `lib/src/domain/z_study_folder_hierarchy.dart`
- `test/z_study_folder_test.dart`
- `test/z_study_session_config_test.dart`
- `test/z_study_session_selector_test.dart`
- `test/z_study_folder_hierarchy_test.dart`

**Modifiés :**
- `lib/zcrud_flashcard.dart` (barrel : exports E9-3 + `hide` des extensions générées)

**Générés (gitignorés, non committés) :**
- `lib/src/domain/z_study_folder.g.dart`
- `lib/src/domain/z_study_session_config.g.dart`
