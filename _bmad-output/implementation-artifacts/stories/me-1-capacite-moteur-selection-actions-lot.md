---
baseline_commit: de0ea05764ccb55c9ac364590e14af1fe4ad20af
---

# Story 2.1: Capacité moteur de sélection et d'actions de lot (me-1)

Status: review

<!-- Epic E-MULTI-EDIT — story 2.1. SEUL epic autorisé à écrire dans zcrud_core. Une story à la fois : AUCUNE autre story n'écrit dans zcrud_core en parallèle. -->

## Story

As a développeur d'app CRUD,
I want sélectionner plusieurs éléments d'une liste zcrud et leur appliquer une action en lot (supprimer, déplacer, éditer un champ commun, ou une action personnalisée),
so that mes utilisateurs gèrent leurs données par paquets, sur n'importe quel modèle, sans que le cœur connaisse ni les flashcards ni un backend.

**Couvre :** FR-SU19 (capacité moteur). **PAS** le multi-éditeur flashcard (me-2), **PAS** le branchement sur `ZFlashcardListView` (me-3).

## ⚠️ Contexte critique : cette story ÉCRIT DANS `zcrud_core` — le cœur

- **AD-1 (CORE OUT=0, le plus critique)** : `zcrud_core` ne dépend d'**AUCUN** autre package zcrud, ni de Firebase / Syncfusion / Quill / gestionnaire d'état. La capacité de sélection + actions de lot est **générique** ⇒ elle vit dans `zcrud_core` (présentation/domaine) + `zcrud_list`. **Interdit absolu** : référencer `ZCascadeRegistry`/`ZCascadeEdge` (ils vivent dans `zcrud_study_kernel`, en AVAL du cœur — une arête retour créerait un cycle), un `ZFlashcard`, un `folderId` codé en dur, ou un type Syncfusion.
- **AD-2/AD-15 (réactivité Flutter-native)** : la sélection est un `Listenable`/`ChangeNotifier` **pur-Flutter**. **Propriétaire UNIQUE** (AD-44) : la LISTE détient le contrôleur ; il est **passé** aux barres/menus, jamais redéclaré par un widget d'action.
- **Leçon E-STUDY-UI (RISQUE N°1 de cette story)** : « deux sources / deux curseurs divergents = perte de données » (su-8 réordonner sous filtre effaçait les non-visibles ; su-10 note SRS sautée). **Une seule source de vérité pour la sélection**, keyée par **`id` STABLE** — **jamais** par index/position.

## Réalité sur disque (vérifiée — ne PAS réinventer)

**La primitive de sélection existe déjà (E4-4).** `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart` porte `ZListSelectionController` (`ChangeNotifier` + `ValueNotifier<Set<String>>`, modes `none/single/multiple`, `toggle/selectAll/setSelection/clearSelection/selectRange`, `Set` non modifiables, keyé par `id` stable, `dispose`-safe). Déjà **exporté** (`zcrud_core.dart:140`) et déjà **branché par la grille** (`packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` aligne `controller.selectedRows` sur `interaction.selectedIds`, keyé par `id`). **me-1 ÉTEND cette primitive — ne la duplique pas, ne crée pas de 2e contrôleur.**

**Le pont liste↔renderer existe.** `z_list_interaction.dart` (`ZListInteraction`) porte `mode`, `selectedIds`, `onSelectionChanged`, `actionsFor` (par ligne). `z_list_renderer.dart` (`ZListRenderer.build(..., {ZListInteraction? interaction})`) est rétro-compatible.

**Les actions déclarées en données existent — mais en `zcrud_study`, PAS en core.** `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart` (`ZItemAction`/`ZItemActionKind`/`ZItemActionsMenu`, patron `onSelected == null ⇒ action ABSENTE`) est le patron de référence AD-44, mais il vit en AVAL du cœur. **me-1 crée le pendant GÉNÉRIQUE de LOT dans `zcrud_core`** (impossible de réutiliser celui de study : ce serait une arête core→study, cycle AD-1).

**Les validateurs se dérivent déjà du `ZFieldSpec`.** `ZFieldSpec.validators : List<ZValidatorSpec>` (`z_field_spec.dart:69`) → `ZValidatorCompiler.compile(specs) : FormFieldValidator<String>?` (`z_validator_compiler.dart:50`, exporté `zcrud_core.dart:102`). **me-1 RÉUTILISE `ZValidatorCompiler` pour l'édition de champ commun — jamais une 2e implémentation de validation** (AD-44 : « mêmes validateurs que le formulaire unitaire »).

**La cascade AD-21 est un mécanisme STUDY, hors du cœur.** `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart` (`ZCascadeRegistry`/`ZCascadeEdge`, ES-3.3, traversée **bornée** anti-cycle, ownership à propriétaire unique). Le **placement des arêtes concrètes + la composition** sont déférés (DW-ES33-1). Le chemin d'écriture physique (lot Firestore ≤ 450) est résolu dans `zcrud_firestore`. **⇒ me-1 dans le cœur NE référence PAS `ZCascadeRegistry`** : il définit un **seam de suppression par lot GÉNÉRIQUE** (un supprimeur par racine INJECTÉ, `await`é par racine, agrégé en rapport AD-39). La borne ≤ 450 et la cascade réelle sont une **propriété de l'implémentation injectée** (study/firestore), pas du cœur.

**Le port de persistance.** `z_repository.dart` : `softDelete(id) : Future<ZResult<Unit>>` (`ZResult = Either<ZFailure, T>`), `save(item)`, aucun `deleteMany`/`cascade` (grep négatif ci-dessous). L'actuel `ZListSelectionController.softDeleteSelected` (l.134-158) est **best-effort per-id** (callbacks `onFailure`/`onSuccess`) — il n'`await` PAS une cascade et ne produit PAS le **rapport structuré au grain de la racine** exigé par AD-39. me-1 ajoute cette voie ; `softDeleteSelected` reste (rétro-compat) ou est marqué `@Deprecated` pointant vers la nouvelle voie.

### Greps de réalité (commande + verdict)

```
grep -rln "class ZListSelectionController" packages/*/lib
  → packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart   [existe, E4-4]
grep -rln "ZBatchAction\|BatchAction\|ZBatchDeletion\|BatchDeletionReport\|applyCommonField" packages/*/lib ; echo $?
  → (aucune sortie) RC=1                                                   [ABSENT — à créer par me-1]
grep -rn "deleteMany\|batchDelete\|cascade\|deleteWithCascade" packages/zcrud_core/lib/src/domain/ports/z_repository.dart ; echo $?
  → (aucune sortie) RC=1                                                   [le port ne connaît PAS la cascade — seam injecté]
grep -rln "ZCascadeRegistry\|ZCascadeEdge" packages/zcrud_core/lib ; echo $?
  → (aucune sortie) RC=1                                                   [le cœur N'importe PAS la cascade study — CORE OUT=0 à préserver]
grep -n "z_list_selection\|z_validator_compiler\|z_list_interaction" packages/zcrud_core/lib/zcrud_core.dart
  → lignes 102/135/140                                                     [déjà exportés]
```

> Discipline de réalité (NON-NÉGOCIABLE) : toute **absence** invoquée dans un AC ou un test se prouve par un **grep négatif** (commande + RC dans la note de dev/le test). Pièges avérés : `grep … | head; echo $?` rend le RC de `head` ⇒ **`grep -q` sans pipe** ; `$` est un métacaractère BRE ⇒ **`grep -qF`** ; `melos run test` **se BLOQUE** ⇒ **`flutter test` par package**.

## Acceptance Criteria

**AC1 — Sélection à propriétaire UNIQUE (AD-44), tout-sélectionner + badge compteur**
**Given** une liste zcrud
**When** l'utilisateur active la sélection multiple (long-press / cases à cocher)
**Then** l'état de sélection a **un seul propriétaire** : le `ZListSelectionController` (pur `Listenable`, AD-2) **détenu par la surface de liste** et **passé** aux barres/menus — jamais redéclaré par un widget d'action
**And** « tout sélectionner » (sur l'ensemble des `id` de la vue courante) et un **badge compteur** (`selectedCount`, tranche réactive) sont disponibles
**And** aucun 2e contrôleur de sélection n'est introduit (grep négatif prouvant l'unicité).

**AC2 — La sélection survit aux changements de liste par `id` STABLE (RISQUE N°1)**
**Given** une sélection non vide
**When** la liste change (filtre, tri, item supprimé, item ajouté)
**Then** la sélection reste associée aux **`id` stables**, **jamais** à un index/une position (leçon su-4 D2 / su-7)
**And** une action de lot ne s'applique **jamais** au mauvais item : un `id` sélectionné dont l'item a disparu de la source est soit ignoré sans effet, soit rapporté en échec — **jamais** appliqué à un autre item réoccupant sa position
**And** réordonner/filtrer ne fait perdre **aucun** `id` sélectionné non visible (anti-régression su-8).

**AC3 — Actions de lot DÉCLARÉES en données (AD-44)**
**Given** des actions de lot configurées
**When** la barre d'actions de lot est construite
**Then** les actions sont **déclarées en données** dans un type GÉNÉRIQUE de `zcrud_core` (patron `ZItemActionsMenu` : `onSelected == null` ⇒ action **ABSENTE**, jamais un bouton grisé/no-op)
**And** `delete` et `move` sont des natures intégrées, plus un **slot d'actions personnalisées** (`custom`) enregistrables par l'app
**And** la nature est un **enum** (pas un booléen), extensible additivement (AD-4).

**AC4 — Suppression par lot : cascade AD-21 **awaited** + rapport au grain de la racine (AD-39/AD-10)**
**Given** une suppression par lot
**When** elle s'exécute
**Then** elle passe par un **seam de suppression INJECTÉ** (`Future<ZResult<Unit>> Function(String rootId)` ou équivalent), **`await`é par racine** — jamais fire-and-forget
**And** chaque élément racine sélectionné est une **unité de rapport** (réussi / échoué + **cause** `ZFailure`) ; l'appelant reçoit **toujours** la liste des racines échouées — **jamais** de lot silencieusement partiel
**And** le cœur ne connaît ni la borne ≤ 450 ni le graphe de cascade (propriété de l'impl injectée, `zcrud_study_kernel`/`zcrud_firestore`)
**And** **aucune exception ne franchit la surface** (AD-10) : un `throw` du supprimeur injecté est capté et converti en racine échouée.

**AC5 — Déplacer : champ de rattachement DÉCLARÉ par le modèle, destination injectée**
**Given** l'action « Déplacer »
**When** l'utilisateur choisit une destination
**Then** l'action réaffecte le **champ de rattachement déclaré par le modèle** (nom de champ paramétrique, ex. `folder_id`/`parent_id`) — **jamais** un `folderId` codé en dur
**And** la destination provient d'un **sélecteur INJECTÉ** par l'app (le cœur ne fournit aucun sélecteur de dossier)
**And** l'application est **par élément**, avec rapport d'échecs (même contrat AC4).

**AC6 — Édition de champ commun DÉRIVÉE du `ZFieldSpec` (mêmes validateurs)**
**Given** une édition de champ commun
**When** l'utilisateur applique une valeur à N éléments
**Then** l'éditeur et les validateurs sont **dérivés du `ZFieldSpec`** via `ZValidatorCompiler.compile` — **exactement les mêmes** que le formulaire unitaire, jamais une seconde implémentation de validation
**And** une valeur invalide au regard des validateurs est **rejetée avant** toute écriture (aucune racine touchée)
**And** l'application est **par élément**, avec rapport d'échecs par élément (même contrat AC4).

**AC7 — CORE OUT=0 (AD-1) + gate REPO-WIDE**
**Given** cette story touche `zcrud_core`
**When** elle est en cours
**Then** **aucune autre story n'écrit dans `zcrud_core`** en parallèle
**And** `zcrud_core` ne gagne **aucune** dépendance tierce (pubspec inchangé côté deps lourdes ; garde `presentation_purity_test`/`domain_purity_test` verte)
**And** `dart run melos run analyze` **ET** `dart run melos run verify` **REPO-WIDE** sont **verts** avant `done` (une régression cross-package d'un symbole cœur n'est PAS vue par une vérif ciblée — cf. `ZExportApi` supprimé en E11a-3 cassant `zcrud_flashcard`).

> **Précision garde (code-review me-1, D-LOW)** : un **leak import-only** (un `import 'package:zcrud_*'`/tiers ajouté dans `zcrud_core/lib/**` **sans** toucher le pubspec) n'est **PAS** rattrapé par `melos run verify` (= `graph_proof` + gates reflectable/secrets/codegen, qui lisent le **pubspec**, pas les `import` Dart) ni par `melos run analyze` (l'import résout en workspace melos, lint `info` non fatal). Le **gardien réel** de ce leak est le **`presentation_purity_test`/`domain_purity_test`** (whitelist stricte des imports admis sous `lib/src/**`), exécuté par `flutter test` (target `test`). L'invariant CORE OUT=0 reste **effectivement enforced** car dev + CI rejouent la suite complète (946 tests) — mais la preuve d'AD-1 au niveau des **imports** est le test de pureté, pas `verify`.

**AC8 — Robustesse (AD-10) : jamais d'exception sur les cas limites**
**Given** les cas limites
**When** l'un survient — sélection **vide**, **tout** sélectionné, action sur **0/1/N/tous**, lot **> 450**, item **supprimé pendant** l'action, cascade **partielle**, modèle **sans** champ de rattachement, `id` sélectionné **absent** de la source
**Then** aucune exception ne franchit la surface ; chaque cas produit un **résultat défini** (no-op documenté ou racine échouée rapportée), jamais un crash ni une écriture sur le mauvais item.

## Tasks / Subtasks

- [x] **T1 — Ratifier + étendre la sélection à propriétaire unique** (AC1, AC2, AC8)
  - [x] Vérifié sur disque : `ZListSelectionController` reste l'unique propriétaire (aucun 2e contrôleur — la barre `ZBatchActionBar` REÇOIT le contrôleur, ne le crée/dispose jamais). Contrat de propriété documenté dans `z_batch_action.dart`.
  - [x] Badge compteur (`selectedCount`) explicité via la tranche `selectedIds` ; « tout sélectionner » exposé par `ZBatchActionBar.onSelectAll` (`selectAll(ids)` existant, bouton ABSENT si callback null).
  - [x] Survie aux changements de liste prouvée (tests AC2) : un item supprimé décalant les positions ⇒ le lot vise le BON `id` (`spy.received == ['B']`, jamais `'C'` réoccupant) ; réordonner/filtrer ne perd aucun `id` non visible.
- [x] **T2 — Créer le modèle GÉNÉRIQUE d'actions de lot dans `zcrud_core`** (AC3)
  - [x] `z_batch_action.dart` : `ZBatchAction` (`kind` + `label`/`icon` INJECTÉS + `onSelected`) et `ZBatchActionKind` (`delete`, `move`, `custom` ; enum extensible AD-4). Patron `onSelected == null ⇒ ABSENTE`.
  - [x] `ZBatchActionBar` neutre : lit la tranche `selectedIds`/`selectedCount` (`ValueListenableBuilder`, rebuild ciblé), rend actions déclarées + badge compteur + « tout sélectionner ». ≥ 48 dp, label a11y via `tooltip` (pas de double-`Semantics` — leçon SU-8/AC20), directionnel (`EdgeInsetsDirectional`/`TextAlign.start`), thème INJECTÉ (`ZcrudTheme.of`).
  - [x] Exportés dans `zcrud_core.dart`.
- [x] **T3 — Suppression par lot : seam injecté, awaited, rapport AD-39** (AC4, AC8)
  - [x] `z_batch_deletion_report.dart` : value object `ZBatchReport` (racines réussies + `Map<rootId, ZFailure>`), `hasFailures`/`failedRootIds`/`succeededCount`, collections non modifiables, égalité de valeur. `typedef ZBatchDeletionReport = ZBatchReport` (nom demandé, contrat générique réutilisé T4/T5).
  - [x] `batchApply` (workhorse générique) + `batchDelete({deleteRoot})` : `await` **par racine**, `try/catch` capte tout `throw` (AD-10 → `ServerFailure`), succès retirés de la sélection, échecs conservés. Cascade/borne ≤ 450 = propriété du seam injecté (documenté).
  - [x] `softDeleteSelected` marqué `@Deprecated` pointant vers `batchDelete`.
- [x] **T4 — Déplacer : champ de rattachement déclaré + destination injectée** (AC5, AC8)
  - [x] `batchMove({attachmentField, destination, moveRoot})` : réaffecte un **nom de champ paramétrique** (jamais `folderId` en dur), destination via seam INJECTÉ. Application par élément + rapport (contrat T3). `attachmentField` null/vide ⇒ chaque racine échouée (`DomainFailure`), AUCUNE écriture, aucun throw.
- [x] **T5 — Édition de champ commun dérivée du `ZFieldSpec`** (AC6, AC8)
  - [x] `applyCommonField({field, value, writeRoot})` : dérive les validateurs via `ZValidatorCompiler.compile(field.validators)` (RÉUTILISE — aucune 2e validation). Valeur invalide ⇒ REJETÉE avant écriture (writeRoot jamais appelé, toutes racines échouées `DomainFailure`). Valide ⇒ application par élément + rapport.
- [x] **T6 — Isolation + gate REPO-WIDE** (AC7)
  - [x] `pubspec.yaml` de `zcrud_core` INCHANGÉ (aucune dep lourde/tierce). Gardes `presentation_purity_test`/`domain_purity_test` vertes (946 tests). Aucun import concret de cascade/study/repo (grep : uniquement docstrings).
  - [x] `flutter test` par package : `zcrud_core` 946 (+15), `zcrud_list` 20, reverse-deps `zcrud_flashcard` 541, `zcrud_study` 411.
  - [x] Gate final REPO-WIDE : `melos run analyze` RC=0 · `melos run verify` RC=0 (ACYCLIQUE OK, **CORE OUT=0 OK**).

## Dev Notes

### Placement (vérifié sur disque)
- Sélection (existant, à étendre) : `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart`.
- Pont liste↔renderer (existant) : `z_list_interaction.dart` / `z_list_renderer.dart` ; binding grille : `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart`.
- Nouveaux (me-1) : `z_batch_action.dart`, barre d'actions de lot, `z_batch_deletion_report.dart`, édition de champ commun — tous sous `packages/zcrud_core/lib/src/presentation/list/` (ou `.../edition/` pour l'édition de champ commun) + exports `zcrud_core.dart`.
- Validation à réutiliser : `z_validator_compiler.dart` (`ZValidatorCompiler.compile`).

### Frontières (NON-NÉGOCIABLE)
me-1 = **capacité moteur GÉNÉRIQUE** uniquement. **PAS** de `ZMultiFlashcardEditor` (me-2), **PAS** de branchement dans `ZFlashcardListView` (me-3), **PAS** d'UI ni de type spécifique flashcard, **PAS** de référence à `ZCascadeRegistry`/`ZCascadeEdge` (study, aval). Le supprimeur de cascade et le sélecteur de destination sont **injectés** par l'appelant.

### Invariants AD applicables
AD-1 (CORE OUT=0, acyclique) · AD-2/AD-15 (Listenable pur, rebuild ciblé, zéro gestionnaire d'état) · AD-4 (enum extensible, slot custom, `onSelected==null ⇒ absent`) · AD-10 (jamais d'exception, `Either<ZFailure,T>`, replis définis) · AD-13 (RTL, ≥ 48 dp, `Semantics`, thème/l10n injectés) · AD-21 (cascade bornée — propriété de l'impl injectée) · AD-39 (suppression persistée : cascade **awaited**, rapport au grain de la racine) · AD-44 (sélection à propriétaire unique, actions déclarées, lot dérivé du `ZFieldSpec`).

### Discipline de test (R3 — tests porteurs, leçons E-STUDY-UI)
- Chaque AC : **fichier réel** + **test porteur** rougissant **par le COMPORTEMENT** (injection R3), pas par une tautologie.
- Défauts à NE PAS reproduire : la **prose ment** (asserter le comportement réel, pas la dartdoc) ; **test infalsifiable** (espion prouvé captant AVANT l'appel ; corpus qui ne rend pas l'assertion vraie quel que soit le code) ; **présence ≠ association** (asserter que l'action agit sur les BONS `id`, pas juste que la barre existe) ; une garde `takeException() isNull` **ne prouve pas la justesse** — asserter le RÉSULTAT (rapport AD-39 : quelles racines réussies/échouées) ; **jamais** deux gardes qui se contredisent.
- **Perte de données par voie non anticipée = RISQUE N°1** : test explicite « filtrer/réordonner puis agir » prouvant qu'aucun `id` non visible n'est perdu et qu'aucune action ne touche un item réoccupant une position.
- 🚫 **On ne modifie JAMAIS un test pour taire un défaut réel.**

### Vérif verte (à rejouer réellement avant `review`/`done`)
`dart run melos run generate` (si annotation/générateur touché) → `dart run melos run analyze` RC=0 → `flutter test` par package (`zcrud_core`, `zcrud_list`) → gate final **REPO-WIDE** `dart run melos run analyze` **ET** `dart run melos run verify` RC=0. `melos run test` **se bloque** : utiliser `flutter test` par package pendant le dev.

### Baseline (epic SU committé, repo-wide vert)
24/24 packages, **4694 tests** · `zcrud_core` **931** · `zcrud_list` **20**. me-1 ajoute des tests ; aucun test existant ne doit rougir.

### Project Structure Notes
Alignement conforme : API publique via barrel `lib/zcrud_core.dart`, impl sous `lib/src/presentation/list/` ; types préfixés `Z` ; `*_test.dart`. Aucune nouvelle entité `@ZcrudModel` attendue (pas de codegen à régénérer sauf si un modèle est annoté — improbable ici). Variance assumée : le modèle d'actions de lot est **dupliqué** (pas partagé) avec `ZItemAction` de `zcrud_study` — c'est **voulu** (AD-1 interdit l'arête core→study) et non une redondance à factoriser.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 2.1]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-44] (multi-édition), #AD-39 (suppression awaited/rapport racine), #AD-21 (cascade bornée), #AD-1/AD-2/AD-10/AD-13
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU19]
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart] (primitive E4-4 à étendre)
- [Source: packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart] (patron actions déclarées, à répliquer en core)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart] (validation à réutiliser)
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart] (cascade study — NE PAS importer dans le cœur)
- [Source: CLAUDE.md] (Key Don'ts, invariants AD)

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `bmad-dev-story` (skill réel invoqué).

### Debug Log References

- Vérif verte REPO-WIDE rejouée : `melos run analyze` RC=0 (seules des `info` pré-existantes dans les tests `zcrud_study` — deprecated/depend_on_referenced_packages, hors fichiers touchés) ; `melos run verify` RC=0 (`ACYCLIQUE OK`, `CORE OUT=0 OK`, gates reflectable/secrets/codegen/codegen-distribution/compat/reserved-keys/serialization tous OK).
- Tests par package : `zcrud_core` 946, `zcrud_list` 20, `zcrud_flashcard` 541, `zcrud_study` 411.
- **Preuve R3 (2 injections, rouge PAR COMPORTEMENT puis restaurées via `cp` + `sha256sum -c`)** :
  1. `batchApply` — retrait du `try/catch` ⇒ test « throw du seam CAPTÉ » RED (`Bad state: boom-a` non capté). Restauré (SHA OK).
  2. `applyCommonField` — court-circuit de la garde de validation ⇒ test « valeur INVALIDE rejetée avant écriture » RED (`spy.received` attendu vide, obtenu non-vide : writeRoot appelé). Restauré (SHA OK).

### Completion Notes List

- **CORE OUT=0 (AD-1) préservé** : `zcrud_core/pubspec.yaml` inchangé ; la cascade AD-21, le repository et le sélecteur de destination sont des **seams INJECTÉS** (`Future<ZResult<Unit>> Function(...)`), jamais des imports concrets. Aucune référence à `ZCascadeRegistry`/`ZCascadeEdge`/`zcrud_study` hors docstrings. Gate `graph_proof` : `CORE OUT=0 OK` + `ACYCLIQUE OK`.
- **AD-39/AD-10** : rapport `ZBatchReport` fidèle au grain de la racine (réussies + `Map<rootId, ZFailure>`), best-effort (échec sur 1/3 ⇒ 2 réussies + 1 `ZFailure`, les 2 autres traitées), `await` par racine, tout `throw` capté (jamais d'exception franchissant la surface).
- **RISQUE N°1 (perte de données)** : sélection keyée par `id` STABLE ; test porteur prouve qu'après suppression/décalage de positions le lot vise le bon `id` (jamais l'item réoccupant la position).
- **AD-44** : propriétaire UNIQUE (barre reçoit le contrôleur) ; `applyCommonField` réutilise `ZValidatorCompiler.compile` (mêmes validateurs que l'édition unitaire, une seule source de validation).
- **Variance assumée (AD-1)** : `ZBatchAction`/`ZBatchActionBar` dupliquent le patron de `ZItemActionsMenu` (`zcrud_study`) sans partager de type — une arête core→study serait un cycle.
- **Écart tranché** : `softDeleteSelected` (E4-4) conservé mais `@Deprecated` vers `batchDelete` (rétro-compat, aucun consommateur cassé).

### File List

- `packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart` (nouveau — `ZBatchAction`/`ZBatchActionKind`/`ZBatchActionBar`)
- `packages/zcrud_core/lib/src/presentation/list/z_batch_deletion_report.dart` (nouveau — `ZBatchReport` + `typedef ZBatchDeletionReport`)
- `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart` (modifié — `batchApply`/`batchDelete`/`batchMove`/`applyCommonField` ; `@Deprecated` sur `softDeleteSelected`)
- `packages/zcrud_core/lib/zcrud_core.dart` (modifié — exports des 2 nouveaux fichiers)
- `packages/zcrud_core/test/presentation/list/z_batch_action_test.dart` (nouveau — 15 tests porteurs AC1..AC8)
