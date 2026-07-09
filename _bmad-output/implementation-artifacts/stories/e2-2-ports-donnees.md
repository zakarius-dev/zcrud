---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.2 : Ports données (ZRepository<T>, ZDataRequest incl. curseur, ZDataState, ZAcl)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du cœur `zcrud_core`**,
je veux **poser les ports de la couche données — le contrat `ZRepository<T extends ZEntity>` (CRUD + flux `Stream<List<T>>` nus + count + softDelete/restore), le value object neutre de requête `ZDataRequest` (filtres/tri/recherche + pagination **curseur** opaque), le modèle d'état `ZDataState<T>` (loading/data/empty/error) et le port d'autorisation `ZAcl` — le tout en Dart pur, backend-agnostique, sans qu'aucun type `cloud_firestore` (`Timestamp`/`Filter`/`FirebaseException`/`DocumentSnapshot`) ne fuite dans le domaine**,
afin que **les adaptateurs de persistance (E5 `zcrud_firestore` : `FirebaseZRepositoryImpl`, traduction `ZDataRequest→Filter`, curseur `startAfter`), la liste dynamique (E4 : filtres/tri/pagination/actions ACL) et les modèles canoniques (E9/E10) se branchent sur des contrats stables, testables en pur-Dart, sans jamais réintroduire un couplage backend ni violer la convention de nommage `Z` (finding readiness #15).**

## Contexte & valeur

**E2-1 est `done`** : les contrats fondateurs vivent sous `packages/zcrud_core/lib/src/domain/` — `ZEntity` (identité `String?` opaque + `isEphemeral`), `ZNode`, `ZSyncable` (clé LWW `updatedAt`), `ZSyncMeta` (sync hors-entité), et la hiérarchie `ZFailure` (`abstract`, non-`sealed`) + `DomainFailure`/`CacheFailure`/`NotFoundFailure`/`ServerFailure` + le typedef `ZResult<T> = Either<ZFailure, T>`. `dartz ^0.10.1` est câblé et re-exporté **curaté** par le barrel (`show Either, Left, Right, Unit, unit`). Tests en **`package:test` pur-Dart** (pas `flutter_test`). Graphe AD-1 acyclique, `zcrud_core` out-degree 0.

**E2-2 construit DESSUS**, sans rien recréer : `ZRepository<T>` est borné `T extends ZEntity` (E2-1), renvoie `ZResult<...>` (E2-1) sur ses opérations, et `ZDataState.error` porte un `ZFailure` (E2-1). Ordre intra-épic verrouillé : **E2-1 → E2-2 → E2-7 → E2-9** avant E2-4/E2-5 (codegen). E2-2 débloque **E4** (liste : `ZDataRequest`, pagination, ACL), **E5** (`FirebaseZRepositoryImpl<T>` + traduction `ZDataRequest→Filter` + curseur `startAfter`), **E9/E10** (repos flashcard/mindmap).

**Ce que cette story matérialise (issu du schéma canonique porté de lex_douane, §7) :**
- Le **contrat repository de référence** (`StudyFoldersRepository`/`FlashcardsRepository`/`MindmapsRepository`/`RepetitionRepository`) généralisé en `ZRepository<T>` : flux temps réel **nus**, CRUD via `Either`, `softDelete` (`is_deleted=true`), matérialisation de l'éphémère **portée par le repo** (AD-14).
- La **pagination par curseur dans le contrat neutre** (AD-16, résout OQ-9) : `startAfter`/`limit` opaques exprimés dans `ZDataRequest`, **repli in-memory documenté**, implémentation Firestore différée à E5.
- Le **port `ZAcl`** (AD-16) : contrôle d'accès fourni par l'app, **aucune règle métier dans le cœur** ; consommé par E4-4 (actions ligne filtrées par ACL).

**Finding readiness #15 (À TRAITER dans cette story) — nommage :** l'inventaire relève que `DataRequest`/`ZQuery`/`DataState` **ne sont pas préfixés `Z`** (auto-violation de la convention zcrud) et signale un **double nom redondant `DataRequest`/`ZQuery`**. Recommandation readiness #11 : « fixer un nom canonique (`ZDataRequest`/`ZDataState`) ». **Décision tranchée dans cette story** (voir Dev Notes « Décision de nommage ») : types canoniques **`ZDataRequest`** et **`ZDataState`** ; **`ZQuery` est fusionné dans `ZDataRequest`** (un seul value object de requête, aucune prolifération `DataRequest`+`ZQuery`). L'architecture AD-5/AD-16 écrit `ZQuery`/`DataRequest` en **synonymes séparés par un slash** — la story tranche pour **un seul type préfixé `Z`**.

**Ce qui rendra la story vérifiable :** le domaine reste **Dart pur** (grep prouve zéro `cloud_firestore`/`Timestamp`/`Filter`/`FirebaseException`/`firebase`/`hive`/Flutter/gestionnaire d'état) ; **aucune** méthode de `ZRepository` n'enveloppe un flux dans `Either` (les `Stream<List<T>>` sont **nus**, AD-11) ; le curseur est **neutre** (aucun `DocumentSnapshot`) ; un **fake in-memory** implémente le contrat complet en pur-Dart (preuve de suffisance et de neutralité) ; tous les types publics sont **préfixés `Z`** ; `analyze` RC=0 et `test` RC=0.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ `ZRepository<T extends ZEntity>` : **contrat abstrait** (interface) — CRUD (`getAll`/`getById`/`save`), flux **nus** (`watchAll`/`watch(ZDataRequest)`), `count`, `softDelete`/`restore`, `dispose`. Méthodes non-flux → `ZResult<...>` / `ZResult<Unit>` pour void.
- ✅ `ZDataRequest` : value object neutre immuable — `filters: List<ZFilter>`, `sorts: List<ZSort>`, `search: String?`, **pagination curseur** (`limit: int?`, `startAfter: ZCursor?`), `==`/`hashCode`/`copyWith`.
- ✅ `ZFilter` (`field`/`op`/`value`) + enum `ZFilterOp` ; `ZSort` (`field`/`direction`) + enum `ZSortDirection`. Value objects neutres.
- ✅ `ZCursor` : **curseur opaque neutre** — valeurs de clé d'ordre (`List<Object?>`) + `id` stable optionnel ; `==`/`hashCode`. Mapping documenté (Firestore `startAfter` **et** repli in-memory).
- ✅ `ZDataState<T>` : **`sealed`** (ensemble **fermé** de 4 états UI) — `ZDataLoading<T>`, `ZDataLoaded<T>` (items + `nextCursor`/`hasMore`), `ZDataEmpty<T>`, `ZDataError<T>` (porte `ZFailure`). Neutre (pur-Dart, aucun Flutter).
- ✅ `ZAcl` : **port abstrait** d'autorisation neutre — `bool can(ZCrudAction, {ZEntity? target, String? collectionId})` ; enum `ZCrudAction` (camelCase) ; impl par défaut `ZAllowAllAcl` (permissive, zéro-config).
- ✅ Exports du barrel + docstrings d'origine `fichier:ligne` lex (traçabilité re-portage, canonique §6.6).
- ❌ **Pas** d'`impl` de repository ni de traduction `ZDataRequest→Filter` ni de curseur `startAfter` concret (→ **E5** `zcrud_firestore` ; les `Filter`/`startAfter` Firestore vivent LÀ, jamais ici).
- ❌ **Pas** de `ZLocalStore`/`ZRemoteStore` : ces ports **bas-niveau orientés adaptateur** sont introduits **avec** l'adaptateur offline-first en **E5** (canonique §7 « à abstraire derrière `ZLocalStore`/`ZRemoteStore` »). Documenté comme frontière de portée.
- ❌ **Pas** de `sync()` / `ZSyncOrchestrator` / merge LWW (→ **E5** offline-first ; sémantique non figée ici).
- ❌ **Pas** de contrats spécialisés (`RepetitionRepository.reviewCard`/`initRepetition`, `StudyFoldersRepository.saveFolder` invariant 2 niveaux, `EducationGenerationRepository`) → **E9/E8** ; `ZRepository` reste le contrat **générique** de base.
- ❌ **Pas** de `ZPublishedDocRepository` (contenu publié cache-first + checksum) — modèle distinct, différé (canonique §7, → v1.x).
- ❌ **Pas** de `ZExtension`/`extra`/registre (→ E2-3) ; **pas** de `ZFieldSpec`/modèles concrets ; **pas** de `ZFormController`/réactivité (→ E2-7).
- ❌ **Ne PAS** ajouter de dépendance : `dartz` suffit (déjà présent E2-1) ; **aucun** `zcrud_*`, aucun backend (AD-1 out-degree 0 préservé).
- ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur). **Ne PAS** committer de `*.g.dart` (aucun modèle annoté ici).
- ❌ **Ne PAS** supprimer/renommer les types E2-1 ni `ZCoreApi` — le barrel continue de les exporter.

## Acceptance Criteria

1. **Pureté & neutralité backend du domaine (AD-5, AD-1, AD-14).** Aucun fichier introduit par cette story sous `packages/zcrud_core/lib/src/domain/` n'importe `package:cloud_firestore/*`, une quelconque `package:firebase*`, `package:hive*`, `package:flutter/*`, `dart:ui`, ni un gestionnaire d'état (`flutter_riverpod`/`riverpod`/`package:get/`/`package:provider/`). **Aucune** occurrence textuelle des types backend `Timestamp`, `Filter`, `FirebaseException`, `DocumentSnapshot`, `QuerySnapshot`, `CollectionReference` dans les fichiers de la story (vérifiable par grep — voir Stratégie de tests). Seuls imports externes autorisés : `dart:core` (implicite) et `package:dartz/dartz.dart`. `packages/zcrud_core/pubspec.yaml` reste **inchangé** (aucune nouvelle dépendance ; `dartz` déjà déclaré en E2-1) → out-degree 0 préservé (graph_proof `CORE OUT=0`).

2. **Nommage 100 % préfixé `Z` (finding readiness #15).** Tous les types publics introduits sont préfixés `Z` : `ZRepository`, `ZDataRequest`, `ZFilter`, `ZFilterOp`, `ZSort`, `ZSortDirection`, `ZCursor`, `ZDataState`, `ZDataLoading`, `ZDataLoaded`, `ZDataEmpty`, `ZDataError`, `ZAcl`, `ZCrudAction`, `ZAllowAllAcl`. **Aucun** type nommé `DataRequest`, `DataState`, ni **`ZQuery`** n'est déclaré (0 occurrence comme identifiant de type). La **décision de nommage** (ZQuery fusionné dans ZDataRequest) est consignée en Dev Notes.

3. **`ZRepository<T extends ZEntity>` — contrat neutre, `Either` sur les opérations, flux NUS (AD-11).** Un `abstract` (interface) `ZRepository<T extends ZEntity>` déclare **au minimum** :
   - `Stream<List<T>> watchAll()` — flux temps réel **nu** (jamais enveloppé dans `Either`), équivalent du `dataChanges` canonique (seed immédiat puis broadcast, sémantique portée par l'impl E5) ;
   - `Stream<List<T>> watch(ZDataRequest request)` — flux dérivé filtré, **nu** ;
   - `Future<ZResult<List<T>>> getAll({ZDataRequest? request})` — exclut les soft-deleted ;
   - `Future<ZResult<T>> getById(String id)` — `Left(NotFoundFailure)` si absent/soft-deleted ;
   - `Future<ZResult<T>> save(T item, {String? collectionId})` — la **matérialisation de l'éphémère** (attribution d'`id`) et le rejet `Left(DomainFailure)` si cible manquante sont **portés par le repository** (AD-14), documentés dans la docstring du contrat ;
   - `Future<ZResult<Unit>> softDelete(String id)` — `is_deleted=true` (hors-entité `ZSyncMeta`) ;
   - `Future<ZResult<Unit>> restore(String id)` — annule le soft-delete (corbeille, E4-4) ;
   - `Future<ZResult<int>> count({ZDataRequest? request})` ;
   - `void dispose()`.
   **Invariant vérifiable :** aucune signature ne retourne un `Stream` enveloppé dans `Either` (grep : pas de `Either<..., Stream` ni `ZResult<Stream`).

4. **`ZDataRequest` — requête neutre immuable.** `ZDataRequest` est un value object immuable (`final` + constructeur `const`) portant : `List<ZFilter> filters` (défaut `const []`), `List<ZSort> sorts` (défaut `const []`), `String? search`, `int? limit`, `ZCursor? startAfter`. Il fournit `==`/`hashCode` (égalité de valeur profonde, listes comparées élément par élément) et `copyWith` (avec sentinelle permettant de remettre `search`/`limit`/`startAfter` à `null`). Un `ZDataRequest()` par défaut (aucun filtre/tri/curseur) est valide et représente « tout, non paginé ». `ZFilter(field, op, value)` + enum `ZFilterOp { eq, neq, lt, lte, gt, gte, contains, isIn, isNull }` (valeurs **camelCase**) et `ZSort(field, direction)` + enum `ZSortDirection { asc, desc }` sont neutres (aucun type backend).

5. **Pagination curseur NEUTRE (AD-16, OQ-9).** `ZCursor` est un value object **opaque et neutre** : il porte `List<Object?> values` (les valeurs des clés d'ordre de l'élément d'ancrage, alignées sur `ZDataRequest.sorts`) et `String? id` (ancre stable de départage / repli in-memory) ; `==`/`hashCode`/`toString`. **Aucun** type Firestore (`DocumentSnapshot`) n'y apparaît. La docstring documente explicitement le **double mapping** : (a) adaptateur Firestore (E5) → `query.startAfter(cursor.values)` ; (b) **repli in-memory** (AD-16 « repli in-memory documenté ») → parcours filtré/trié puis saut jusqu'à `id`/`values` avant de prendre `limit`. Le consommateur ne construit/relit **jamais** un type backend pour paginer.

6. **`ZDataState<T>` — ensemble d'états FERMÉ (`sealed`).** `ZDataState<T>` est une classe **`sealed`** (ensemble **fermé** de 4 états, exhaustivité compilateur souhaitée pour l'UI) avec : `ZDataLoading<T>`, `ZDataLoaded<T>` (`List<T> items`, `ZCursor? nextCursor`, `bool hasMore`), `ZDataEmpty<T>` (chargé mais vide, **distinct** de loading), `ZDataError<T>` (`ZFailure failure`). Un `switch` exhaustif sur `ZDataState` **compile sans branche `default`** (test de compilation). **Décision d'architecture consignée** (Dev Notes) : `sealed` est **approprié ici** (ensemble fermé intra-package, non destiné à l'extension inter-package) — à l'inverse de `ZFailure` qui est `abstract`/ouvert (AD-4). `ZDataState` est **dérivé par la présentation/le controller** à partir du flux nu + de l'`Either` ; il **n'est pas** un type de retour de `ZRepository` (préserve AD-11 « flux nu »). Neutre (pur-Dart, zéro Flutter).

7. **`ZAcl` — port d'autorisation neutre (AD-16).** `ZAcl` est un `abstract` (interface) exposant `bool can(ZCrudAction action, {ZEntity? target, String? collectionId})` — décision synchrone, **aucune règle métier dans le cœur** (fournie par l'app). L'enum `ZCrudAction { view, create, update, delete, restore }` a des valeurs **camelCase**. Une implémentation par défaut `ZAllowAllAcl` (`const`, `can(...) => true`) est fournie pour le zéro-config. Documenté : ACL **asynchrone** différée (le contrat synchrone couvre le filtrage d'actions ligne d'E4-4).

8. **Barrel & emplacements.** Les nouveaux types vivent sous `packages/zcrud_core/lib/src/domain/{data,ports}/` (mapping en Dev Notes) ; l'API publique passe **uniquement** par le barrel `lib/zcrud_core.dart` (aucune déclaration d'impl dans le barrel). Le barrel exporte tous les types de l'AC2, **conserve** les exports E2-1 (`ZEntity`/`ZNode`/`ZSyncable`/`ZSyncMeta`/`ZFailure`+sous-classes/`ZResult`) et `ZCoreApi`, et garde le re-export **curaté** dartz (aucun export global). Ordre alphabétique des directives (`directives_ordering`).

9. **Contrat implémentable en pur-Dart (preuve de suffisance & neutralité).** Un **fake in-memory** `_InMemoryZRepository` (dans `test/`) implémente **l'intégralité** de `ZRepository<T>` en pur-Dart (aucun backend) : `save` matérialise l'éphémère (attribue un `id`), `getById`/`getAll` **excluent** les soft-deleted, `softDelete`/`restore` basculent l'état, `watchAll`/`watch` émettent un `Stream<List<T>>` **nu** re-broadcasté à chaque mutation, `count` respecte `ZDataRequest`, et la **pagination curseur** fonctionne via le **repli in-memory** (`limit` + `startAfter`). Ceci prouve que le contrat est neutre et suffisant sans fuite backend.

10. **Vérif verte (AD-5/AD-11/AD-16 respectés).** `dart run melos run generate` OK (no-op, aucun modèle annoté) ; `dart analyze`/`melos run analyze` RC=0 (zéro warning, `public_member_api_docs` satisfait si actif) ; `melos run test`/`dart test` RC=0 avec les tests ajoutés ; `melos run verify` RC=0 (graph_proof `CORE OUT=0`, ACYCLIQUE, gates reflectable/secrets/codegen OK). Grep de pureté/neutralité **0 occurrence** (AC1). `ZCoreApi` + types E2-1 toujours exportés (non-régression E2-1/E1-2).

## Tasks / Subtasks

- [x] **Tâche 1 — Value objects de requête : `ZDataRequest`/`ZFilter`/`ZSort` (AC: 1, 2, 4)**
  - [x] Créer `lib/src/domain/data/z_data_request.dart` : `ZDataRequest` immuable (`const`, `final`), champs `filters`/`sorts`/`search`/`limit`/`startAfter` (défauts `const []`/`null`), `==`/`hashCode` (comparaison de listes profonde — helper `_listEquals` ou `const DeepCollectionEquality`… **non** : rester pur-Dart sans `collection` ; écrire un comparateur de liste à la main), `copyWith` avec sentinelle pour reset-null.
  - [x] Dans le même fichier (ou `z_filter.dart`/`z_sort.dart`) : `ZFilter(field, op, value)` + `enum ZFilterOp { eq, neq, lt, lte, gt, gte, contains, isIn, isNull }` ; `ZSort(field, direction)` + `enum ZSortDirection { asc, desc }`. `==`/`hashCode` de valeur. Docstring d'origine (canonique §7, `DataRequest`).
- [x] **Tâche 2 — Curseur opaque neutre `ZCursor` (AC: 1, 5)**
  - [x] Créer `lib/src/domain/data/z_cursor.dart` : `ZCursor` immuable (`const`, `final`), `List<Object?> values` + `String? id`, `==`/`hashCode` (comparaison profonde de `values`), `toString`. Docstring du **double mapping** (Firestore `startAfter` en E5 **et** repli in-memory AD-16). **Zéro** type Firestore.
- [x] **Tâche 3 — États `ZDataState<T>` sealed (AC: 1, 2, 6)**
  - [x] Créer `lib/src/domain/data/z_data_state.dart` : `sealed class ZDataState<T>` + `ZDataLoading<T>`, `ZDataLoaded<T>({required List<T> items, ZCursor? nextCursor, bool hasMore})`, `ZDataEmpty<T>`, `ZDataError<T>(ZFailure failure)`. `const` où possible ; `==`/`hashCode` (au moins sur `ZDataError`/`ZDataLoaded`). Docstring : `sealed` (fermé, exhaustif) vs `ZFailure` `abstract` (ouvert AD-4) ; dérivé par la présentation, pas retourné par le repo (AD-11).
- [x] **Tâche 4 — Port `ZAcl` + `ZCrudAction` + `ZAllowAllAcl` (AC: 1, 2, 7)**
  - [x] Créer `lib/src/domain/ports/z_acl.dart` : `abstract class ZAcl { bool can(ZCrudAction action, {ZEntity? target, String? collectionId}); }` ; `enum ZCrudAction { view, create, update, delete, restore }` ; `class ZAllowAllAcl implements ZAcl { const ZAllowAllAcl(); ... => true; }`. Docstring : app-supplied, aucune règle métier dans le cœur (AD-16) ; ACL async différée.
- [x] **Tâche 5 — Contrat `ZRepository<T>` (AC: 1, 3)**
  - [x] Créer `lib/src/domain/ports/z_repository.dart` : `abstract class ZRepository<T extends ZEntity>` avec la surface de l'AC3 (import du barrel interne / des fichiers E2-1 pour `ZEntity`/`ZResult`/`ZFailure` et de `data/z_data_request.dart`). Docstrings : matérialisation éphémère portée par le repo (AD-14), flux **nus** (AD-11), soft-delete hors-entité (AD-16). Origine canonique §7 (`ZRepository<T extends ZEntity>`).
- [x] **Tâche 6 — Barrel (AC: 8)**
  - [x] Étendre `lib/zcrud_core.dart` : ajouter `export 'src/domain/data/z_data_request.dart';`, `export 'src/domain/data/z_cursor.dart';`, `export 'src/domain/data/z_data_state.dart';`, `export 'src/domain/ports/z_acl.dart';`, `export 'src/domain/ports/z_repository.dart';` — **ordre alphabétique** ; conserver exports E2-1 + `z_core_api.dart` + re-export curaté dartz.
- [x] **Tâche 7 — Tests pur-Dart (AC: 1, 3, 4, 5, 6, 7, 9)**
  - [x] `test/domain/z_data_request_test.dart` : égalité de valeur (filtres/sorts profonds), `copyWith` reset-null, `ZFilter`/`ZSort` égalité, défauts.
  - [x] `test/domain/z_cursor_test.dart` : égalité profonde `values`, `id`, `toString` ; neutralité (pas d'API backend requise pour construire).
  - [x] `test/domain/z_data_state_test.dart` : **switch exhaustif compile sans `default`** (les 4 variants) ; `ZDataError.failure` porte un `ZFailure` ; `ZDataLoaded.hasMore`/`nextCursor`.
  - [x] `test/domain/z_acl_test.dart` : `ZAllowAllAcl().can(...)==true` pour toutes les `ZCrudAction` ; un fake `ZAcl` restrictif refuse `delete` — preuve du filtrage d'action.
  - [x] `test/domain/z_repository_contract_test.dart` : `_InMemoryZRepository` (fake pur-Dart) implémentant TOUT le contrat ; scénarios : `save` matérialise l'`id` (éphémère→persisté) ; `getById` post-`softDelete` → `Left(NotFoundFailure)` ; `restore` réinclut ; `watchAll` émet un `Stream<List<T>>` **nu** re-broadcasté à la mutation ; `count` respecte un `ZDataRequest` (filtre) ; **pagination curseur** via repli in-memory (`limit`+`startAfter` → page suivante correcte).
  - [x] Étendre `test/purity/domain_purity_test.dart` (ou script grep) : asserter 0 occurrence de `cloud_firestore`/`firebase`/`hive`/Flutter/état + 0 occurrence textuelle de `Timestamp`/`Filter`/`FirebaseException`/`DocumentSnapshot` sous les nouveaux fichiers ; asserter 0 identifiant de type `DataRequest`/`DataState`/`ZQuery` (finding #15).
- [x] **Tâche 8 — Vérif verte & traçabilité (AC: 10)**
  - [x] `dart run melos run generate` OK, `dart analyze`/`melos run analyze` RC=0, `melos run test`/`dart test` RC=0, `melos run verify` RC=0 (`CORE OUT=0`, ACYCLIQUE).
  - [x] Confirmer non-régression : `ZCoreApi` + types E2-1 toujours exportés ; `pubspec.yaml` inchangé ; 0 `.g.dart` suivi.

## Dev Notes

### Décision de nommage — finding readiness #15 (À CONSIGNER, TRANCHÉE)

L'inventaire relève `DataRequest`/`ZQuery`/`DataState` **non préfixés `Z`** (auto-violation de la convention « types publics préfixés `Z` », architecture.md#Consistency Conventions / CLAUDE.md) et un **double nom redondant `DataRequest`/`ZQuery`**. L'architecture elle-même écrit `ZQuery`/`DataRequest` en **synonymes séparés par `/`** (AD-5, AD-16) — signal qu'il s'agit d'**un seul concept nommé deux fois**.

**Décision (recommandation readiness #11) :**
- **`ZDataRequest`** = le value object canonique de requête (filtres + tri + recherche + **pagination curseur**). Remplace `DataRequest`.
- **`ZDataState`** = le modèle d'état canonique. Remplace `DataState`.
- **`ZQuery` N'EST PAS créé** : son rôle (spécifier une requête) est **entièrement absorbé** par `ZDataRequest`. On évite ainsi la prolifération `DataRequest`+`ZQuery` (findings #15/#11). Si un besoin futur d'une « requête compilée/optimisée » distincte émerge, il sera introduit explicitement à ce moment — pas de type fantôme spéculatif aujourd'hui (YAGNI).

Cette décision aligne 100 % des types data sur le préfixe `Z` et résout finding #15.

### Décision — `sealed` (`ZDataState`) vs `abstract` (`ZFailure`)

Deux mécanismes d'ensemble, **deux usages distincts** (cf. E2-1 Dev Notes et AD-4) :
- **`ZDataState<T>` = `sealed`** : ensemble **fermé** de 4 états UI, **intra-package**, où l'exhaustivité d'un `switch` (sans `default`) est un **atout** (la présentation traite tous les cas). L'extension inter-package n'a **aucun** sens ici (un satellite n'ajoute pas un 5ᵉ état de chargement). AD-4 autorise `sealed` pour un ensemble fermé interne — c'est exactement le cas (miroir de `ZFlashcardSource` sealed en interne, E2-1).
- **`ZFailure` = `abstract` (non `sealed`)** : ensemble **ouvert**, les satellites (`FlashcardGenerationFailure`, E9) et apps hôtes doivent pouvoir ajouter leurs failures — AD-4 **interdit** `sealed` pour l'extension inter-package. (Décision E2-1, inchangée.)

Ne pas confondre : `sealed` = fermé exhaustif (états) ; `abstract` = ouvert extensible (erreurs).

### Frontière de portée — pourquoi PAS `ZLocalStore`/`ZRemoteStore`/`sync()` ici

AD-5 liste aussi `ZLocalStore`/`ZRemoteStore`, mais ce sont des ports **bas-niveau orientés adaptateur** : le canonique §7 les introduit « à abstraire **derrière** » l'impl offline-first (Hive source de vérité + Firestore fire-and-forget). Ils n'ont de sens qu'**avec** leur adaptateur (E5) ; les poser à vide ici serait spéculatif. De même `sync()`/`ZSyncOrchestrator`/merge LWW (AD-9) portent une **sémantique** (LWW sur `updated_at`, `Right(unit)` si déconnecté, cascade 450 writes/batch) qui appartient à E5. **E2-2 = les ports consommés par la LISTE (E4) et implémentés par l'ADAPTATEUR (E5)** : `ZRepository`/`ZDataRequest`/`ZCursor`/`ZDataState`/`ZAcl`. Frontière documentée pour éviter le sur-engineering.

### Conception de la pagination curseur neutre (AD-16, OQ-9)

Contrainte : le curseur doit (a) mapper vers Firestore `query.startAfter([...])` **sans** exposer `DocumentSnapshot`, et (b) supporter un **repli in-memory** (backend sans curseur natif). Conception retenue :
- `ZCursor(values: List<Object?>, id: String?)` — `values` = les valeurs des **clés d'ordre** (`ZDataRequest.sorts`) de l'élément d'ancrage (dernier de la page précédente) ; `id` = clé stable de départage / ancre du repli in-memory.
- **Firestore (E5)** : `query.orderBy(...).startAfter(cursor.values).limit(request.limit)` — l'adaptateur reconstruit `values` depuis le dernier document ou les reçoit du consommateur. Aucun `DocumentSnapshot` ne traverse le port.
- **Repli in-memory (E5/fake)** : filtrer → trier selon `sorts` → sauter jusqu'à l'ancre (`id` ou `values`) → prendre `limit`. Documenté dans la docstring `ZCursor` (« repli in-memory documenté », AD-16).
- Le consommateur (liste E4-3) obtient le `nextCursor` via `ZDataLoaded.nextCursor` (produit par l'impl) et le repasse dans `ZDataRequest.startAfter` — boucle fermée **sans** type backend. E4-3 précise le **cas d'erreur** : curseur invalide / backend sans curseur → **repli in-memory documenté, pas de crash**.

### Invariants d'architecture applicables (rappel dev)

- **AD-1** : `zcrud_core` puits du graphe — **aucune** dépendance `zcrud_*`/backend ajoutée. `dartz` déjà là (E2-1). `CORE OUT=0`.
- **AD-5** : backend-agnostique — **zéro** `Timestamp`/`Filter`/`FirebaseException`/`DocumentSnapshot`. `ZDataRequest`/`ZCursor` neutres ; traduction en E5.
- **AD-11** : `ZResult<T> = Either<ZFailure,T>` sur les opérations, `Unit` pour void, **flux `Stream<List<T>>` NUS** (jamais `Either<_, Stream>`). `ZDataState` **dérivé** par la présentation, pas retourné par le repo.
- **AD-14** : invariants métier (matérialisation éphémère, cascade, 2 niveaux) portés par le **repository** (impl E5), **jamais** dans le contrat/l'entité. Le contrat les **documente** sans les implémenter.
- **AD-16** : `ZAcl` app-supplied (aucune règle métier dans le cœur) ; pagination curseur dans le **contrat neutre** `ZDataRequest`/`ZCursor` (résout OQ-9) ; repli in-memory documenté.
- **AD-4** : `sealed` uniquement pour ensemble **fermé intra-package** (`ZDataState`) ; `abstract`/composition pour l'extension inter-package.

### Conventions de code (canonique §5)

- **`Equatable` jamais** (0 occurrence) — `==`/`hashCode` manuels via `Object.hash`. Comparaison de listes (`filters`/`sorts`/`values`) : helper interne à la main (rester pur-Dart, **ne pas** tirer `package:collection` dans le cœur au stade contrats).
- **`freezed` non imposé** — value objects `final` + `const`.
- **Enums en camelCase** (`ZFilterOp.isIn`, `ZSortDirection.asc`, `ZCrudAction.view`) — persistance camelCase (canonique §5).
- IDs = `String` **opaques** ; `ZRepository` borné `T extends ZEntity` (id nullable éphémère E2-1).
- **`@JsonSerializable` non requis** (contrats/ports techno-neutres, pas de codegen ici) — aucun `part '*.g.dart'`.
- Traçabilité : docstring d'origine `study_folders_repository.dart:…`/`data_request` (canonique §6.6, §7) sur chaque type re-porté.
- Tests : **`package:test` pur-Dart** (pas `flutter_test`) — cohérent E2-1.

### Emplacements décidés (sous `packages/zcrud_core/lib/src/domain/`)

| Type | Fichier | Nature |
|---|---|---|
| `ZDataRequest`, `ZFilter`, `ZFilterOp`, `ZSort`, `ZSortDirection` | `data/z_data_request.dart` | value objects de requête neutres |
| `ZCursor` | `data/z_cursor.dart` | curseur opaque neutre (AD-16) |
| `ZDataState<T>` (+ `ZDataLoading`/`ZDataLoaded`/`ZDataEmpty`/`ZDataError`) | `data/z_data_state.dart` | `sealed` — états UI fermés |
| `ZAcl`, `ZCrudAction`, `ZAllowAllAcl` | `ports/z_acl.dart` | port d'autorisation neutre (AD-16) |
| `ZRepository<T extends ZEntity>` | `ports/z_repository.dart` | contrat repository (AD-5/AD-11) |

### Source tree à toucher

```
packages/zcrud_core/
  lib/zcrud_core.dart                       # + exports (data/*, ports/*), ordre alpha ; E2-1 + ZCoreApi conservés
  lib/src/domain/
    data/z_data_request.dart                # NEW (ZDataRequest + ZFilter/ZSort + enums)
    data/z_cursor.dart                      # NEW (ZCursor opaque neutre)
    data/z_data_state.dart                  # NEW (ZDataState sealed + 4 variants)
    ports/z_acl.dart                        # NEW (ZAcl + ZCrudAction + ZAllowAllAcl)
    ports/z_repository.dart                 # NEW (ZRepository<T extends ZEntity>)
  test/
    domain/z_data_request_test.dart         # NEW
    domain/z_cursor_test.dart               # NEW
    domain/z_data_state_test.dart           # NEW (switch exhaustif compile)
    domain/z_acl_test.dart                  # NEW
    domain/z_repository_contract_test.dart  # NEW (_InMemoryZRepository fake pur-Dart)
    purity/domain_purity_test.dart          # UPDATE (élargir aux nouveaux fichiers + interdits Timestamp/Filter/… + noms non-Z)
```

### Project Structure Notes

- `pubspec.yaml` **inchangé** : `dartz` (E2-1) suffit ; **ne pas** ajouter `flutter`/`collection`/backend. Rester pur-Dart (AD-14) au stade contrats.
- Les nouveaux `test/domain/*` réutilisent `package:test` + le barrel `package:zcrud_core/zcrud_core.dart` (jamais `package:dartz` direct — cohérent E2-1 AC8).
- Étendre l'extracteur de pureté E2-1 (`domain_purity_test.dart`) plutôt que d'en recréer un.
- Aucun `*.g.dart` (aucun modèle annoté).

### References

- [Source: epics.md#E2] — Story E2-2 : contrats neutres backend-agnostiques ; aucun type `cloud_firestore` (AD-5) ; `Stream<List<T>>` nus ; pagination curseur + `ZAcl` dans le contrat neutre (AD-16). Ordre intra-épic E2-1→E2-2.
- [Source: epics.md#E4] — E4-3 (recherche/filtres/tri/pagination curseur via `DataRequest`, repli in-memory, cas curseur invalide) ; E4-4 (actions ligne filtrées par `ZAcl`, corbeille soft-delete) — **consommateurs** de ces ports.
- [Source: epics.md#E5] — E5-1 `FirebaseZRepositoryImpl<T>` + traduction `DataRequest→Filter` + curseur `startAfter` — **implémenteur** de ces ports (bugs à corriger : réassignation `limit`, `null≠erreur`, pas de `catch(_){}`).
- [Source: architecture.md#AD-5] — ports `ZRepository<T>`/`ZLocalStore`/`ZRemoteStore`/`ZQuery`/`DataRequest`/`ZDataState` dans `zcrud_core` sans type backend ; adapters en `zcrud_firestore`.
- [Source: architecture.md#AD-11] — `Either<ZFailure,T>`/`Unit`, **flux `Stream<List<T>>` nus**, hiérarchie `ZFailure`.
- [Source: architecture.md#AD-16] — `ZAcl` app-supplied (aucune règle métier dans le cœur) ; pagination curseur (`startAfter`/opaque) dans le contrat neutre `DataRequest`/`ZQuery`, repli in-memory documenté (résout OQ-9).
- [Source: architecture.md#AD-14] — invariants métier au repository, domaine pur-Dart.
- [Source: architecture.md#AD-4] — `sealed` = ensemble fermé interne ; `abstract`/composition pour l'extension inter-package.
- [Source: architecture.md#Consistency Conventions] — types publics préfixés `Z` ; enums camelCase ; id `String` opaque.
- [Source: implementation-readiness-report-2026-07-09.md#9] — finding #15 (nommage `DataRequest`/`ZQuery`/`DataState` non préfixés Z, double nom) ; recommandation #11 (fixer `ZDataRequest`/`ZDataState`).
- [Source: docs/canonical-schema.md#7] — contrat `ZRepository<T extends ZEntity>` de référence (`dataChanges`/`streamByContainer`/`getAll`/`getById`/`save`/`softDelete`/`sync`/`dispose`), matérialisation éphémère, soft-delete, `ZLocalStore`/`ZRemoteStore` derrière l'impl.
- [Source: docs/canonical-schema.md#5] — `Either<Failure,T>`/`Unit`/`Stream` nu ; `Equatable` jamais ; `Generics <T extends ZEntity>` réservés au typage des repositories.
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart] — `ZResult<T>`/`ZFailure`/`NotFoundFailure`/`DomainFailure` (E2-1, consommés ici).
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_entity.dart] — `ZEntity` (borne générique de `ZRepository`).
- [Source: packages/zcrud_core/lib/zcrud_core.dart] — barrel actuel (E2-1 + `ZCoreApi`, à étendre).

## Stratégie de tests

- **`ZDataRequest`/`ZFilter`/`ZSort` (`z_data_request_test.dart`)** : égalité de valeur avec listes profondes (`filters`/`sorts` identiques ⇒ égal + `hashCode` identique ; un élément différent ⇒ inégal) ; `copyWith` conserve/écrase/reset-null (`search`/`limit`/`startAfter`) ; `ZDataRequest()` par défaut (listes vides, tout `null`) ; `ZFilter`/`ZSort` égalité + enums.
- **`ZCursor` (`z_cursor_test.dart`)** : égalité profonde `values` + `id` ; `toString` lisible ; **construction sans aucune API backend** (preuve de neutralité) ; deux curseurs `values` différents ⇒ inégaux.
- **`ZDataState` (`z_data_state_test.dart`)** : un `switch (state) { case ZDataLoading(): … case ZDataLoaded(): … case ZDataEmpty(): … case ZDataError(): … }` **compile sans `default`** (preuve `sealed` exhaustif — AC6) ; `ZDataError(failure).failure is ZFailure` ; `ZDataLoaded(items:[…], hasMore:true, nextCursor: ZCursor(...))` ; `ZDataEmpty` distinct de `ZDataLoading`.
- **`ZAcl` (`z_acl_test.dart`)** : `const ZAllowAllAcl().can(a)` == `true` pour **chaque** `ZCrudAction` ; un fake `_DenyDeleteAcl implements ZAcl` refuse `ZCrudAction.delete` et accepte le reste (preuve du filtrage d'action E4-4).
- **Contrat `ZRepository` (`z_repository_contract_test.dart`)** : `_InMemoryZRepository implements ZRepository<FakeEntity>` (`FakeEntity implements ZEntity`, `id` nullable). Scénarios : `save(ephemeral)` → `Right(entity avec id non-null)` (matérialisation) ; `save` sans cible attendue → contrat documenté (le fake choisit un comportement, on teste la surface, pas la règle métier E5) ; `softDelete(id)` puis `getById(id)` → `Left(NotFoundFailure)` ; `restore(id)` → réinclus dans `getAll` ; `watchAll()` renvoie un `Stream<List<T>>` (typage **nu**, jamais `Either`) qui émet à chaque mutation ; `count(ZDataRequest(filters:[…]))` respecte le filtre ; **pagination** : insérer N items, `getAll(ZDataRequest(sorts:[…], limit:2))` → page 1 ; repasser `nextCursor` dans `startAfter` → page 2 correcte (repli in-memory).
- **Pureté & nommage (`domain_purity_test.dart` étendu)** : sur les 5 nouveaux fichiers `lib/src/domain/{data,ports}/*.dart` — asserter **0** import `package:flutter`/`dart:ui`/`cloud_firestore`/`firebase`/`hive`/`flutter_riverpod`/`riverpod`/`package:get/`/`package:provider/` ; **0** occurrence textuelle de `Timestamp`/`Filter`/`FirebaseException`/`DocumentSnapshot`/`QuerySnapshot`/`CollectionReference` (AD-5) ; **0** identifiant de type `DataRequest`/`DataState`/`ZQuery` (finding #15) ; seul import externe autorisé `package:dartz`.
- **Vérif verte finale** : `melos run generate` OK → `dart analyze`/`melos run analyze` RC=0 → `melos run test`/`dart test` RC=0 → `melos run verify` RC=0 (`CORE OUT=0`, ACYCLIQUE, gates OK).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

#### Remédiation code-review E2-2 (MEDIUM M1/M2/M3 + LOW) — 2026-07-09

Correctifs de couverture/robustesse du fake de référence (`_InMemoryZRepository`) + clarification docstring `ZCursor`. **Aucune dégradation du code de production APPROVED** (seul changement prod = docstring `z_cursor.dart`, doc-only, sémantique neutre inchangée).

- **M2 (repli curseur par `values`)** — `test/domain/z_repository_contract_test.dart` : réécriture de la branche curseur de `_applyRequest` (ex-`indexWhere(p.id == cursor.id)` qui ignorait `values` et retombait en page 1 sur `id: null`/id introuvable). Nouveau : ajout de `_compareToAnchor(p, cursor, sorts)` (comparaison positionnelle `cursor.values` ↔ clés d'ordre, sens de tri respecté, `id` en départage seul) ; le saut = `where(_compareToAnchor > 0)`, indépendant de la présence de `cursor.id`. Cas `sorts` vide → repli dégénéré par `id` (page 1 si ancre introuvable). Docstring `lib/src/domain/data/z_cursor.dart` clarifiée (repli par `values`, `id` départage, `id: null` légitime, curseur invalide sans crash) — lève l'ambiguïté « [id] puis [values] » relevée en M2, sans changer la sémantique neutre du value object. Tests prouvant : `pagination par values avec ZCursor(id: null)` ; `départage par id à valeurs d ordre égales`.
- **M1 (`watch(ZDataRequest)` exercé)** — nouveau test `watch(request) émet la liste FILTRÉE+TRIÉE à chaque mutation (AC9/M1)` : abonnement au flux NU `watch()` avec filtre `age>=18` + tri `age asc`, mutations successives, vérifie que chaque réémission applique filtre+tri (distinct de `watchAll`). Ferme AC9.
- **M3 (branches non couvertes)** — 3 tests : `tri multi-clés : tie-break sur la 2e clé` (atteint `compare==0` sur la 1re clé `age`, départage par `name`) ; `curseur invalide (id inexistant) : pas de crash, saut par values` (comportement défini : saut piloté par `values`, aucune exception) ; `pagination au-delà de la fin → liste vide` (curseur = dernier élément → `[]`, pas d'erreur).
- **LOW L2 (`ZDataLoaded` items vides)** — **décision : NE PAS ajouter d'`assert(items.isNotEmpty)`.** `ZDataState` est un value object neutre pur-Dart ; forcer l'invariant côté modèle casserait `const ZDataLoaded(items: [])` en debug et empiéterait sur la responsabilité de dérivation de la présentation (le controller/UI **doit** router un résultat vide vers `ZDataEmpty`). La convention « non vide sinon `ZDataEmpty` » reste documentée dans la docstring. Aucun changement de code (évite de toucher un fichier de prod APPROVED sans nécessité).
- **LOW L1/L3 (`_listEquals` superficiel/dupliqué)** — **consignés, non actionnés** : `ZCursor.values` porte des clés d'ordre **scalaires** (String/int/date) ; aucune liste imbriquée réaliste → aucun bug d'égalité réel. Duplication assumée pour préserver AD-1 (out-degree 0, pas de `package:collection`). Le contrat hash/== reste cohérent.

**Vérif verte rejouée réellement sur disque (post-remédiation) :**
- `packages/zcrud_core > dart test` → RC=0, **80 tests** (74 → 80, +6 : M1×1, M2×2, M3×3).
- `packages/zcrud_core > dart analyze .` → RC=0, « No issues found! ».
- `melos run analyze` → RC=0 (14 packages).
- `melos run test` → RC=0 (zcrud_core SUCCESS, 80 tests).
- `melos run verify` → RC=0 : `graph_proof` **17 arêtes, 14 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** ; gates melos/reflectable/secrets/codegen/compat OK ; `verify:serialization` no-op toléré.
- `melos list` = **14** ; `git ls-files '*.g.dart'` = **0**.
- Pureté préservée : seul fichier prod touché = `z_cursor.dart` (docstring), aucun import backend ajouté.

#### Développement initial

- `dart pub get` (racine) → RC=0.
- `packages/zcrud_core > dart analyze .` → RC=0, « No issues found! ».
- `packages/zcrud_core > dart test` → RC=0, **74 tests passés** (14 nouveaux + 60 E2-1).
- `melos run analyze` → RC=0 (14 packages, « No issues found! »).
- `melos run generate` → RC=0 (no-op propre : 0 modèle `@ZcrudModel`, 0 `.g.dart`).
- `melos run verify` → RC=0 : `graph_proof` **17 arêtes, 14 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** ; gates melos/reflectable/secrets/codegen/compat OK ; `verify:serialization` no-op (exit 79 toléré).
- Greps de pureté sous `packages/zcrud_core/lib/` : imports interdits = **0**, types backend en code (`Timestamp`/`FirebaseException`/`DocumentSnapshot`/`QuerySnapshot`/`CollectionReference`) = **0**, identifiants non-Z (`DataRequest`/`DataState`/`ZQuery`) = **0**.
- `git ls-files '*.g.dart'` = **0** (aucun code généré suivi).
- `melos list` = **14** packages (non-régression).

### Completion Notes List

- **Décision de nommage (finding #15) appliquée** : types canoniques `ZDataRequest` (fusionne l'ancien `DataRequest`+`ZQuery`) et `ZDataState` ; **`ZQuery` n'est pas créé**. 100 % des types publics sont préfixés `Z`. Un test de pureté dédié (`domain_purity_test.dart`) asserte 0 identifiant `DataRequest`/`DataState`/`ZQuery` (hors commentaires) — le check strippe les commentaires pour autoriser les docstrings qui mentionnent ces noms à titre documentaire.
- **AD-11 (flux nus)** : `ZRepository.watchAll()`/`watch()` retournent `Stream<List<T>>` **nu**, jamais `Either<_, Stream>`. `ZDataState` est **dérivé** côté présentation (prouvé par le contrat), jamais renvoyé par le repo.
- **AD-5 (backend-agnostique)** : `ZCursor` opaque (`List<Object?> values` + `String? id`), aucun `DocumentSnapshot`. Double mapping (Firestore `startAfter` / repli in-memory) documenté dans la docstring, implémenté seulement en E5 ; le **repli in-memory** est prouvé fonctionnel par le fake `_InMemoryZRepository`.
- **AD-4 (`sealed` vs `abstract`)** : `ZDataState` est `sealed` (ensemble fermé intra-package, `switch` exhaustif sans `default` — testé à la compilation) ; `ZFailure` reste `abstract`/ouvert (E2-1, inchangé).
- **AD-16** : `ZAcl.can(...)` synchrone app-supplied, `ZAllowAllAcl` const permissive ; aucune règle métier dans le cœur.
- **AD-1 (pureté du graphe)** : `pubspec.yaml` **inchangé** (aucune dépendance ajoutée) ; comparaisons de listes écrites à la main (pas de `package:collection`). `CORE OUT=0` préservé.
- **AD-14** : la matérialisation de l'éphémère et le soft-delete hors-entité sont **documentés** dans le contrat mais implémentés seulement dans l'adaptateur (E5) ; le fake de test en fournit une implémentation de référence.
- **Frontière de portée respectée** : ni `ZLocalStore`/`ZRemoteStore`, ni `sync()`/merge LWW, ni contrats spécialisés (→ E5/E8/E9).
- **Non-régression E2-1** : barrel conserve tous les exports E2-1 + `ZCoreApi` + re-export curaté dartz ; les 60 tests E2-1 restent verts.

### File List

**Créés (lib) :**
- `packages/zcrud_core/lib/src/domain/data/z_cursor.dart`
- `packages/zcrud_core/lib/src/domain/data/z_data_request.dart` (`ZDataRequest` + `ZFilter`/`ZFilterOp` + `ZSort`/`ZSortDirection`)
- `packages/zcrud_core/lib/src/domain/data/z_data_state.dart` (`ZDataState` sealed + 4 variants)
- `packages/zcrud_core/lib/src/domain/ports/z_acl.dart` (`ZAcl` + `ZCrudAction` + `ZAllowAllAcl`)
- `packages/zcrud_core/lib/src/domain/ports/z_repository.dart` (`ZRepository<T extends ZEntity>`)

**Créés (test) :**
- `packages/zcrud_core/test/domain/z_data_request_test.dart`
- `packages/zcrud_core/test/domain/z_cursor_test.dart`
- `packages/zcrud_core/test/domain/z_data_state_test.dart`
- `packages/zcrud_core/test/domain/z_acl_test.dart`
- `packages/zcrud_core/test/domain/z_repository_contract_test.dart` (fake `_InMemoryZRepository`)

**Modifiés :**
- `packages/zcrud_core/lib/zcrud_core.dart` (barrel : +5 exports, ordre alphabétique ; E2-1 + `ZCoreApi` conservés)
- `packages/zcrud_core/test/purity/domain_purity_test.dart` (garde élargie : types backend + noms non-Z)
