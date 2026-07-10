---
baseline_commit: 868438a73868c75a837e71f8cb443dd75ed24fa8
---

# Story 4.4 : Actions de ligne filtrées par `ZAcl`, sélection multiple (bug historique corrigé) & corbeille soft-delete/restore — statefulness de grille (L2)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP puis lex_douane)**,
je veux **que la `DynamicList` porte des ACTIONS DE LIGNE (édition / suppression / restauration / custom) FILTRÉES par le port `ZAcl` (AD-16 : une action non autorisée est masquée/désactivée), une SÉLECTION MULTIPLE dont l'état vit HORS du renderer (keyé par l'`id` STABLE de la ligne) et qui NE SE PERD PLUS au rebuild / au scroll / à la pagination (le « bug de sélection » historique des 3 apps — `DataGridController` commenté + `DataGridSource` recréée à chaque build, L2 — enfin CORRIGÉ), et une CORBEILLE soft-delete (`ZRepository.softDelete` bascule `is_deleted` hors-entité `ZSyncMeta`, les supprimés disparaissent de la vue normale) avec RESTORE (`ZRepository.restore`)**,
afin que **la liste devienne réellement ACTIONNABLE de bout en bout tout en restant NEUTRE dans le cœur (SM-5 : logique actions/ACL/sélection/corbeille pur-Flutter dans `zcrud_core`, statefulness de la grille Syncfusion cantonnée à `zcrud_list`), que l'ACL de l'app gouverne seule les permissions (aucune règle métier dans le cœur, AD-16), et que le bug de sélection qui a miné IFFD/DODLP/DLCFTI soit prouvé corrigé par un test de rebuild/scroll/pagination**.

**Contexte produit.** Quatrième story d'**E4** (moteur `DynamicList`, dépend d'E2 ; couvre FR-6..FR-8 · AD-8, AD-11, AD-13, AD-16, AD-9). Elle **branche** les ports déjà construits en E2 sur la surface de liste construite en E4-1/E4-2/E4-3 :

- **E2-2 (`review`, prouvé)** a posé le port **`ZAcl`** (`bool can(ZCrudAction action, {ZEntity? target, String? collectionId})`, décision **synchrone**), l'enum **`ZCrudAction { view, create, update, delete, restore }`** (valeurs camelCase) et l'implémentation permissive par défaut **`ZAllowAllAcl`** (`packages/zcrud_core/lib/src/domain/ports/z_acl.dart`). Il a aussi posé le contrat **`ZRepository<T extends ZEntity>`** avec **`Future<ZResult<Unit>> softDelete(String id)`** et **`Future<ZResult<Unit>> restore(String id)`** (`packages/zcrud_core/lib/src/domain/ports/z_repository.dart:58,61`) — documentés « basculent le drapeau `is_deleted` **hors-entité** (`ZSyncMeta`, AD-16) ; les lectures excluent les soft-deleted ».
- **E2-1 (`done`)** a posé **`ZSyncMeta`** (`updatedAt` / `isDeleted`, hors-entité, `is_deleted` en snake_case, désérialisation défensive) — la **source du soft-delete** (`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`).
- **`ZcrudScope`** (E2-8/E4-1) expose déjà le seam **`acl` (défaut `ZAllowAllAcl`)** et le seam **`listRenderer`** (`packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:62,94`) résolus via `ZcrudScope.of` / `ZcrudScope.maybeOf`.
- **E4-1 (`done`)** a posé le port **`ZListRenderer`** (`Widget build(BuildContext, ZListRenderRequest)`) + le backend **`ZSfDataGridRenderer`** (SEULE arête Syncfusion, `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart`). Sa revue a explicitement identifié **L2** : `_ZListDataGridSource` est **recréé à chaque `build()`** (`DynamicList`/renderer `StatelessWidget`) → **perte d'état grille (scroll/sélection) au rebuild** — « à traiter en E4-2/E4-3 » → **échoit à E4-4** (la sélection multiple l'exige).
- **E4-2 (`done`)** a posé **`ZListRenderRequest.fromSchema`** / `deriveColumns` / `ZListColumn` (format neutre partagé) et les 4 vues d'état ; **`DynamicList`** (hôte mince, `StatelessWidget`) dispatchant sur `ZListLayout` (`dataGrid` / `builder` / `custom`).
- **E4-3 (`review`)** a posé **`ZListController<T extends ZEntity>`** (`ChangeNotifier` exposant `ValueListenable<ZListViewState>`), la recherche sans accents, le moteur in-memory et la pagination curseur + repli. E4-4 **s'appuie** sur ce contrôleur (source des entités `T` → l'endroit naturel où l'`id` de ligne et l'entité `T` coexistent, indispensables au filtrage ACL row-level et au keying stable de la sélection).

**Ce que E4-4 matérialise (la liste ACTIONNABLE) :**
1. **Actions de ligne** — un **modèle d'action NEUTRE** `ZRowAction<T>` (id + clé de libellé + icône + `ZCrudAction? requiredPermission` + handler `onInvoke(context, entity)` + `destructive`), résolu **par ligne** en une vue neutre `ZResolvedRowAction` (sans `T`) que le renderer consomme sans jamais voir `T`.
2. **Filtrage par `ZAcl` (AD-16)** — une action portant `requiredPermission` n'est **rendue** (ou est **désactivée**) que si `ZcrudScope.acl.can(requiredPermission, target: entity, collectionId: …)` == `true`. Défaut `ZAllowAllAcl` → tout visible. **Aucune règle métier dans le cœur** : la décision vit dans l'ACL de l'app.
3. **Sélection multiple neutre** — un `ZListSelectionController` (`ChangeNotifier`, `ValueListenable<Set<String>>`) détient l'ensemble des **`id` sélectionnés** (identité STABLE `ZListRow.id`), **hors** du renderer ; `toggle` / `selectAll` / `clearSelection` / `selectRange` / `isSelected`.
4. **Bug de sélection CORRIGÉ (L1/L2)** — le bug historique = (a) IFFD : `_dataGridController` commenté (sélection Syncfusion non branchée, `dynamic_list_screen.dart:1094,1100`, « buggy ») **et** (b) L2 : `DataGridSource` recréée à chaque build → l'état de sélection interne à la grille est **remis à zéro** au moindre rebuild/scroll. **Correctif** : l'état de sélection vit dans le contrôleur neutre (keyé par `id`), et la grille devient **STATEFUL/MÉMOÏSÉE** (source mise à jour **en place**, jamais recréée ; `DataGridController` Syncfusion persistant lié bidirectionnellement à l'état neutre). → sélection stable au rebuild / scroll / `loadMore`.
5. **Corbeille soft-delete + restore (AD-9/AD-16)** — action `delete` → `repository.softDelete(id)` (bascule `is_deleted` hors-entité, **pas** de suppression dure) ; action `restore` → `repository.restore(id)` ; les supprimés **n'apparaissent plus** en vue normale (le repository les exclut déjà). Suppression **en lot** sur la sélection. Échecs `Left(ZFailure)` **non fatals** (AD-11), surfacés par un hook neutre.

**Frontière (NE PAS déborder).** E4-4 s'arrête à une **liste unique actionnable**. Les **sous-listes / relations imbriquées (`ZSubListScreen`) & les onglets de catégorisation** sont **E4-5**. La **vue « corbeille » LISTANT les items supprimés** (par opposition aux ACTIONS soft-delete/restore) n'est **pas** exprimable par le contrat E2-2 gelé (`getAll`/`watchAll` **excluent** les soft-deleted, aucun `trashOnly`/`includeDeleted`) → **déférée** (extension additive `ZDataRequest` ou adaptateur E5) ; voir **Ambiguïtés**. Le **formatage locale-aware** reste déféré (E4-2/E4-3). Voir la section **Frontière** détaillée.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **Modèle d'action ligne NEUTRE** `ZRowAction<T>` (nouveau `packages/zcrud_core/lib/src/presentation/list/z_row_action.dart`) : `{String id; String labelKey; IconData? icon; ZCrudAction? requiredPermission; bool destructive; FutureOr<void> Function(BuildContext, T entity) onInvoke}`. **Fabriques standard** de corbeille : `ZRowAction.softDelete<T>(ZRepository<T>, {void Function(ZFailure)? onFailure})` et `ZRowAction.restore<T>(...)`, plus `ZRowAction.edit<T>(...)` (handler app). Imports **`package:flutter/widgets.dart`** (pour `IconData`/`BuildContext`) + types core — **zéro** Syncfusion/backend/gestionnaire d'état.
- ✅ **Vue résolue neutre** `ZResolvedRowAction` (même fichier) : `{String id; String labelKey; IconData? icon; bool destructive; bool enabled; VoidCallback onInvoke}` — **débarrassée de `T`** (le renderer ne voit jamais `T`). Résolue **par ligne** à partir de `ZRowAction<T>` + entité `T` + `ZAcl`.
- ✅ **Sélection multiple neutre** `ZListSelectionController` (`ChangeNotifier`, nouveau `z_list_selection.dart`) exposant `ValueListenable<Set<String>> selectedIds` + `ZListSelectionMode { none, single, multiple }` ; `toggle`/`selectAll`/`clearSelection`/`selectRange`/`isSelected`/`dispose`. État keyé par `ZListRow.id` **stable**. Réactivité **Flutter-native** (AD-2/AD-15).
- ✅ **Pont neutre renderer** : élargir le port `ZListRenderer.build` d'un paramètre **nommé optionnel** `{ZListInteraction? interaction}` (rétro-compatible) — `ZListInteraction` = objet neutre `{ZListSelectionMode mode; Set<String> selectedIds; void Function(Set<String>)? onSelectionChanged; List<ZResolvedRowAction> Function(ZListRow row)? actionsFor}`. La grille consomme l'`interaction` ; `builder`/`custom` la consomment **dans le cœur** (sélection/actions rendues sans Syncfusion).
- ✅ **Câblage `DynamicList`** : accepte `ZListSelectionController? selection`, `List<ZRowAction<T>>? rowActions`, un résolveur `T? Function(ZListRow)? entityFor` (ou une map `id → T`) pour l'ACL row-level, lit `ZcrudScope.acl`, **filtre/désactive** les actions par ACL, construit l'`interaction` neutre, la passe au renderer (chemin `dataGrid`) **ou** rend actions+sélection **dans le cœur** (chemins `builder`/`custom`).
- ✅ **L2 (statefulness grille) DANS `zcrud_list`** : `ZSfDataGridRenderer` devient **`StatefulWidget`** (ou détient un `State` mémoïsant `_ZListDataGridSource` + un `DataGridController`) : la source est **mise à jour en place** quand `rows` change (jamais recréée) ; `selectionMode`/`onSelectionChanged` du `SfDataGrid` liés **bidirectionnellement** à `ZListInteraction.selectedIds`/`onSelectionChanged`. Scroll & sélection **persistants** au rebuild. **Reste la SEULE arête Syncfusion** (SM-5).
- ✅ **Corbeille** : les fabriques `softDelete`/`restore` déplient `ZResult<Unit>` (AD-11), `Left(ZFailure)` → `onFailure(failure)` (jamais de throw) ; suppression **en lot** sur `selection.selectedIds` (helper `ZListSelectionController` → itère `softDelete`).
- ✅ **a11y** (AD-13) : boutons d'action `Semantics(label: label(context, action.labelKey), button: true)`, cibles ≥ 48 dp, directionnels ; état sélectionné annoncé (`Semantics(selected: …)`).
- ✅ Exports du barrel `zcrud_core.dart` + docstrings d'origine/frontière ; `ZSfDataGridRenderer` re-exporté par `zcrud_list.dart`.
- ❌ **Pas** de **sous-listes/relations/onglets** (`ZSubListScreen`, `DynamicTab`) → **E4-5**.
- ❌ **Pas** de **vue LISTANT la corbeille** (items supprimés) : le contrat E2-2 (`getAll`/`watchAll`) **exclut** les soft-deleted et n'a **pas** de `trashOnly`. E4-4 fournit les **ACTIONS** soft-delete/restore (testables via fake repo) ; le **listing des supprimés** est **déféré** (extension additive `ZDataRequest` ou E5). Voir **Ambiguïtés**.
- ❌ **Ne PAS** modifier le contrat `ZRepository`/`ZDataRequest`/`ZAcl`/`ZSyncMeta` (E2 gelé). E4-4 les **consomme**.
- ❌ **Pas** d'**implémentation Firestore** du soft-delete/restore/ACL → **E5** `zcrud_firestore`. E4-4 appelle les ports neutres.
- ❌ **Pas** de **formatage locale-aware** (déféré E4-2/E4-3).
- ❌ **Ne PAS** toucher `sprint-status.yaml` (orchestrateur). **Ne PAS** ajouter de dépendance à `zcrud_core` (out-degree 0, AD-1). **Ne PAS** importer/tirer `zcrud_list`/Syncfusion dans le nouveau code du cœur (SM-5).

## Acceptance Criteria

> Tous les ACs sont **testables** : unit `flutter_test` (modèles/sélection purs) et widget `flutter_test` (`DynamicList` + fake `ZAcl` restrictif + fake `ZRepository` ; `ZSfDataGridRenderer` via un pump réel). Les enjeux headline : **actions filtrées par `ZAcl`**, **sélection stable au rebuild/scroll/pagination (bug corrigé)** et **soft-delete/restore sans crash**.

1. **AC1 — Modèle d'action ligne NEUTRE `ZRowAction<T>` + résolution `ZResolvedRowAction`.** `ZRowAction<T>` (dans `packages/zcrud_core/lib/src/presentation/list/z_row_action.dart`) porte `{String id; String labelKey; IconData? icon; ZCrudAction? requiredPermission; bool destructive; FutureOr<void> Function(BuildContext, T entity) onInvoke}`. Une méthode/fonction de **résolution par ligne** produit un `ZResolvedRowAction` neutre `{String id; String labelKey; IconData? icon; bool destructive; bool enabled; VoidCallback onInvoke}` en liant l'entité `T` et l'ACL — **sans exposer `T`** au renderer. Imports **uniquement** `package:flutter/widgets.dart` + types core ; **zéro** Syncfusion / backend / gestionnaire d'état. Testable : construire un `ZRowAction<FakeEntity>`, le résoudre pour une ligne → `ZResolvedRowAction.onInvoke()` appelle `onInvoke(context, entity)`.

2. **AC2 — Actions FILTRÉES par `ZAcl` (AD-16) : non autorisée → masquée (défaut) ou désactivée.** Une action dont `requiredPermission != null` n'est **incluse** dans les actions résolues d'une ligne que si `acl.can(requiredPermission, target: entity, collectionId: …)` == `true` (ACL lue via `ZcrudScope.of(context).acl`, défaut `ZAllowAllAcl` → tout autorisé). Une action dont `requiredPermission == null` (custom) est **toujours** incluse. Le mode par défaut est **masquer** ; un mode **désactiver** (`enabled == false`, action grisée) est disponible (paramètre de `DynamicList`, ex. `actionAclMode: hide | disable`). Testable : fake `ZAcl` refusant `ZCrudAction.delete` → l'action `delete` **n'apparaît pas** (mode hide) / est **grisée & non cliquable** (mode disable) ; `ZAllowAllAcl` → toutes présentes/cliquables ; une action custom (sans permission) est toujours présente.

3. **AC3 — Sélection multiple : état NEUTRE keyé par `id`, HORS renderer.** `ZListSelectionController` (`ChangeNotifier`, `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart`) expose `ValueListenable<Set<String>> get selectedIds` et : `toggle(String id)`, `selectAll(Iterable<String> ids)`, `clearSelection()`, `selectRange(List<String> orderedIds, String anchorId, String targetId)`, `bool isSelected(String id)`, `dispose()`. L'état est un `Set<String>` d'**`id` de ligne stables** ; le contrôleur **n'importe AUCUN** renderer/Syncfusion (seulement `package:flutter/foundation.dart`). `ZListSelectionMode { none, single, multiple }` (en mode `single`, `toggle` remplace ; en `none`, no-op). Testable : `toggle('a')` puis `toggle('b')` → `{a,b}` émis 2 fois ; `selectAll` ; `clearSelection` → `{}` ; `selectRange` sur une liste ordonnée → plage inclusive ; `isSelected` cohérent ; `dispose()` n'émet plus.

4. **AC4 — BUG DE SÉLECTION CORRIGÉ : stabilité au rebuild / scroll / pagination.** La sélection **survit** à un rebuild du parent (nouvelle instance `DynamicList` sur des lignes de mêmes `id`), à un scroll de la grille et à un `loadMore()` (pagination) : les `id` sélectionnés restent sélectionnés (l'état vit dans le contrôleur, keyé par `id`, jamais recréé). Testable (widget) : monter `DynamicList` (layout `dataGrid`) + `ZListSelectionController`, sélectionner 2 lignes → `pumpWidget(...)` (rebuild du parent) → **toujours** 2 sélectionnées ; ajouter des lignes via un nouveau `ZListReady` (simulacre de `loadMore`) → sélection préservée ; le finder de l'état sélectionné (case cochée / `Semantics(selected: true)`) reste vrai. **Contrôle négatif documenté** : sans le correctif (source recréée / état dans la grille) le test échouerait.

5. **AC5 — L2 : `DataGridSource` STATEFUL/MÉMOÏSÉE dans `zcrud_list` (statefulness scroll/sélection).** `ZSfDataGridRenderer` est refactoré en **`StatefulWidget`** (ou équivalent portant un `State`) : `_ZListDataGridSource` est **construite une fois** puis **mise à jour en place** (`notifyDataSourceListeners` / mutation de `rows` + `notifyListeners`) quand `ZListRenderRequest.rows` change — **plus jamais recréée par `build`** ; un `DataGridController` **persistant** porte la sélection Syncfusion, liée **bidirectionnellement** à `ZListInteraction.selectedIds` (init depuis l'état, `onSelectionChanged` → `interaction.onSelectionChanged`). **Reste la SEULE arête Syncfusion** (SM-5 : graphe vert, `zcrud_core` out-degree 0). Testable (`zcrud_list`) : pump du renderer, rebuild du parent → **la même instance** de source est réutilisée (pas de recréation — vérifiable via un compteur/identité) ; sélection Syncfusion préservée au rebuild ; graphe SM-5 vert.

6. **AC6 — Corbeille : soft-delete (bascule `is_deleted` hors-entité, PAS de suppression dure).** La fabrique `ZRowAction.softDelete<T>(repository, {onFailure})` (et la suppression **en lot** sur la sélection) invoque `repository.softDelete(id)` → l'item est marqué `is_deleted` **hors-entité** (`ZSyncMeta`, AD-9), **jamais** supprimé physiquement ; après succès, un `refresh` (contrôleur E4-3) le fait **disparaître de la vue normale** (le repository exclut les soft-deleted). Testable : fake `ZRepository` maintenant un `Set` de `deleted` → après `softDelete('x')`, `getAll` ne renvoie plus `x` (mais `x` existe toujours dans le store fake) ; suppression en lot sur `{a,b}` → `a` et `b` exclus.

7. **AC7 — Corbeille : restore ré-inclut l'item.** La fabrique `ZRowAction.restore<T>(repository, {onFailure})` invoque `repository.restore(id)` → l'item soft-deleted **réapparaît** en vue normale. `ZCrudAction.restore` est la permission requise (filtrée par `ZAcl`). Testable : après `softDelete('x')` puis `restore('x')`, `getAll` renvoie de nouveau `x`.

8. **AC8 — Mutations : `Either<ZFailure,Unit>` déplié, `Left` NON fatal (AD-11).** Les invocations `softDelete`/`restore` déplient `ZResult<Unit>` : sur `Right(unit)` → succès (déclenche le `refresh` / retire de la sélection) ; sur `Left(ZFailure)` → appelle `onFailure(failure)` (hook neutre fourni par l'app) **sans** lever d'exception ni corrompre l'état de sélection. Aucun `try-catch` nu ; aucune fuite d'exception. Testable : fake renvoyant `Left(ServerFailure('x'))` sur `softDelete` → `onFailure` reçoit la `ZFailure`, **0 throw**, la sélection reste cohérente.

9. **AC9 — a11y actions & sélection (AD-13).** Chaque bouton d'action expose `Semantics(button: true, label: label(context, action.labelKey), enabled: action.enabled)` avec une cible tactile **≥ 48 dp** et des primitives **directionnelles** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`) ; l'état sélectionné d'une ligne est **annoncé** (`Semantics(selected: isSelected)`). Les libellés passent par le seam l10n `label(context, key)` (aucune chaîne codée en dur). Testable : finder `Semantics` sur les boutons (label résolu, `enabled` reflète l'ACL) ; contrainte de taille ≥ 48 ; case de sélection annoncée `selected`.

10. **AC10 — SM-5 / neutralité + barrels + vérif verte.** Les nouveaux fichiers du cœur (`z_row_action.dart`, `z_list_selection.dart`, `z_list_interaction.dart`, l'élargissement de `z_list_renderer.dart`, le câblage de `dynamic_list.dart`) importent **uniquement** `package:flutter/{widgets,foundation,material}.dart` + types `zcrud_core` — **zéro** `package:syncfusion`, **zéro** `cloud_firestore`/`firebase`/`hive`, **zéro** gestionnaire d'état, **zéro** dépendance ajoutée (`pubspec.yaml` inchangé, out-degree 0). La **statefulness de grille (L2)** vit **UNIQUEMENT** dans `zcrud_list` (`ZSfDataGridRenderer`). Les gardes `presentation_purity_test`/`no_heavy_file_dep_test`/`domain_purity_test` restent **vertes** ; le **test de graphe SM-5** de `zcrud_list` reste **vert** (`ZSfDataGridRenderer` demeure la seule arête Syncfusion). Barrels : `zcrud_core.dart` exporte `ZRowAction`/`ZResolvedRowAction`/`ZListSelectionController`/`ZListSelectionMode`/`ZListInteraction` (ordre `directives_ordering`). `melos run generate` OK → `melos run analyze` RC=0 (14 pkgs) → `flutter test` RC=0 (`zcrud_core` **et** `zcrud_list`) → `melos run verify` RC=0. Non-régression E4-1/E4-2/E4-3 (contrats inchangés ; `ZListRenderer.build` élargi par param **optionnel** rétro-compatible).

## Tasks / Subtasks

- [x] **Tâche 1 — Modèle d'action ligne neutre + fabriques corbeille (AC1, AC6, AC7, AC8, AC10)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_row_action.dart` : `@immutable class ZRowAction<T extends ZEntity>` (`id`, `labelKey`, `IconData? icon`, `ZCrudAction? requiredPermission`, `bool destructive`, `FutureOr<void> Function(BuildContext, T) onInvoke`) + `class ZResolvedRowAction` neutre (`id`, `labelKey`, `icon`, `destructive`, `enabled`, `VoidCallback onInvoke`) + `enum ZActionAclMode { hide, disable }`.
  - [x] Fabriques : `ZRowAction.softDelete<T>(ZRepository<T> repo, {onFailure, onSuccess, labelKey})` (handler : `repo.softDelete(entity.id!)` → déplie `ZResult`, `Left` → `onFailure`, `Right` → `onSuccess` ; entité éphémère `id==null` ignorée), `ZRowAction.restore<T>(...)` (`repo.restore`), `ZRowAction.edit<T>({required onInvoke, ...})`. `requiredPermission` : `delete`/`restore`/`update` respectifs. Méthode `resolve(context, entity, {enabled})` → `ZResolvedRowAction`.
  - [x] Docstring : origine (IFFD `CrudActionsButons`+`RessourceACL`, `dynamic_list_screen.dart:73-342`, `1272`), frontière E4-5, AD-16/AD-9/AD-11.
- [x] **Tâche 2 — Sélection multiple neutre `ZListSelectionController` (AC3, AC4, AC10)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart` : `enum ZListSelectionMode { none, single, multiple }` ; `class ZListSelectionController extends ChangeNotifier` détenant un `ValueNotifier<Set<String>>` (interne) exposé en `ValueListenable<Set<String>> get selectedIds` ; `toggle`/`selectAll`/`setSelection`/`clearSelection`/`selectRange(orderedIds, anchor, target)`/`isSelected`/`selectedCount`/`dispose`. `single` : `toggle`/`setSelection` remplacent ; `none` : no-op.
  - [x] Émettre des `Set` **non modifiables** (`Set.unmodifiable`, invariant de mode centralisé dans `_commit`) ; garde `_disposed`.
  - [x] Helper de suppression en lot : `softDeleteSelected<T>(repo, {onFailure, onSuccess})` itère `selectedIds` → `softDelete` chacun, retire les succès de la sélection, `onSuccess` si tout réussit (atomicité best-effort documentée ; échecs collectés via `onFailure`).
- [x] **Tâche 3 — Pont neutre renderer + élargissement du port (AC1, AC5, AC10)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_interaction.dart` : `@immutable class ZListInteraction` (`ZListSelectionMode mode`, `Set<String> selectedIds`, `void Function(Set<String>)? onSelectionChanged`, `List<ZResolvedRowAction> Function(ZListRow row)? actionsFor`). **Hors** `ZListRenderRequest` (préserve l'égalité de valeur E4-1/E4-2).
  - [x] Élargir `z_list_renderer.dart` : `Widget build(BuildContext, ZListRenderRequest, {ZListInteraction? interaction})` — paramètre **nommé optionnel** (rétro-compatible ; les 4 fakes de test adaptés sans casse fonctionnelle).
- [x] **Tâche 4 — Câblage `DynamicList` (ACL + sélection + actions dans le cœur) (AC2, AC4, AC9)**
  - [x] Éditer `dynamic_list.dart` : `DynamicList<T extends ZEntity>` (défaut `ZEntity`) + `selection`, `rowActions`, `entityFor`, `actionAclMode = hide`, `onSelectionChanged`, `collectionId`. Non-régression E4-1/E4-2 (`.rows`/primaire conservés, seams `null` → chemin d'origine).
  - [x] Construire `interaction` : par ligne, résoudre `rowActions` → `ZResolvedRowAction` en filtrant/désactivant via `ZcrudScope.maybeOf(context).acl.can(...)` (défaut `ZAllowAllAcl`). Passer `interaction` au renderer (chemin `dataGrid`).
  - [x] Chemin `builder` interactif : `_ZListInteractiveBuilderView` rend case (`Semantics(selected:)`) keyée par `row.id` + actions résolues (`Semantics(button, enabled, label)`) **dans le cœur** (SANS Syncfusion), cibles ≥ 48 dp (AC9).
  - [x] Écoute de `selection.selectedIds` via `ValueListenableBuilder` (rebuild ciblé, AD-2).
- [x] **Tâche 5 — L2 : statefulness `ZSfDataGridRenderer` (AC5) — DANS `zcrud_list`**
  - [x] Refactorer `z_sf_data_grid_renderer.dart` : `build` retourne un `StatefulWidget` interne `_ZSfDataGrid` ; `_ZListDataGridSource` **mémoïsée** dans le `State`, **mise à jour en place** (`didUpdateWidget` → `update()` + `notifyListeners`), **plus recréée** par `build`.
  - [x] `DataGridController` **persistant** ; `selectionMode` dérivé de `interaction.mode` ; init/sync de la sélection depuis `interaction.selectedIds` (keyé par `id`, `_syncingSelection` anti-boucle) ; `onSelectionChanged` → `interaction.onSelectionChanged`. Colonne d'actions rendue via `interaction.actionsFor(row)`.
  - [x] `ZSfDataGridRenderer` reste la **seule** arête Syncfusion (graphe SM-5 vert).
- [x] **Tâche 6 — Exports barrel (AC10)**
  - [x] `zcrud_core.dart` : exporte `z_row_action.dart`, `z_list_selection.dart`, `z_list_interaction.dart` (ordre `directives_ordering`). Exports existants conservés. `zcrud_list.dart` inchangé.
- [x] **Tâche 7 — Tests + vérif verte (tous ACs)**
  - [x] `zcrud_core` unit : `z_row_action_test.dart` (7) ; `z_list_selection_test.dart` (12).
  - [x] `zcrud_core` widget : `dynamic_list_actions_acl_test.dart` (4, layout `builder`, SM-5) ; `dynamic_list_selection_test.dart` (4, stabilité rebuild/loadMore/tap/a11y).
  - [x] `zcrud_core` widget : `dynamic_list_trash_test.dart` (6, soft-delete/restore/lot/`Left`→onFailure).
  - [x] `zcrud_list` widget : `z_sf_data_grid_renderer_test.dart` étendu (+7 : source mémoïsée, mise à jour en place, controller persistant, selectionMode, onSelectionChanged, colonne actions) ; graphe SM-5 vert.
  - [x] Vérif verte rejouée réellement : `melos run analyze` RC=0 (14 pkgs) → `melos run test` RC=0 (workspace) → `melos run verify` RC=0 (CORE OUT=0, SM-5 graphe, secrets, codegen, reflectable, compat). 0 `.g.dart` suivi ; `melos list` = 14.

## Dev Notes

### Décisions tranchées

- **`T` reste dans le cœur, JAMAIS dans le renderer (AC1).** L'ACL row-level exige l'entité `T` (`acl.can(action, target: entity)`) ; or le renderer ne connaît que `ZListRow` (id+cells). Solution : la résolution `ZRowAction<T>` → `ZResolvedRowAction` (neutre, sans `T`, avec `enabled`/`onInvoke` déjà liés) se fait **dans `DynamicList`** (où `T` et `ZcrudScope.acl` coexistent), et le renderer reçoit des actions **déjà résolues** via `ZListInteraction.actionsFor(row)`. Le renderer n'importe donc jamais `ZAcl` ni `T`. Ceci respecte SM-5 (logique ACL/actions **neutre dans le cœur**) et garde `ZSfDataGridRenderer` bête.
- **Pont `ZListInteraction` SÉPARÉ, PAS dans `ZListRenderRequest` (AC5).** `ZListRenderRequest` a une **égalité de valeur** (E4-1/E4-2) exploitée par les tests et le rendu ; y ajouter des callbacks (`onSelectionChanged`, `actionsFor`) la casserait (fonctions non comparables). D'où un objet `ZListInteraction` **distinct**, passé en **paramètre nommé optionnel** de `ZListRenderer.build` — additif et **rétro-compatible** (les renderers E4-1 ignorent le param). Alternative rejetée : élargir `ZListRenderRequest` (casse `==`) ; ou changer la signature en positionnel (casse l'API du port).
- **Bug de sélection historique — nature EXACTE et correctif (AC4/AC5).** Le bug des 3 apps a **deux** causes cumulées, documentées à l'inventaire : (a) IFFD — le `_dataGridController` (Syncfusion `DataGridController`) est **commenté** (`docs/technical-inventory.md:58` : « Selection multiple (**bug**: `_dataGridController` commente) », `dynamic_list_screen.dart:1094,1100`, statut **buggy**) : la sélection Syncfusion n'était pas branchée à un état applicatif ; (b) **L2** (code-review E4-1) — `_ZListDataGridSource` **recréée à chaque `build()`** (renderer/hôte `StatelessWidget`) : même si la sélection avait été branchée, tout rebuild/scroll **repartait de zéro** (nouvelle source ⇒ `DataGridController` désynchronisé). **Correctif E4-4** : (1) l'état de sélection vit dans `ZListSelectionController` **hors** de la grille, keyé par l'`id` **stable** de `ZListRow` (jamais par index/position) ; (2) la grille devient **STATEFUL** : source **mémoïsée** + `DataGridController` **persistant** + liaison bidirectionnelle. → la sélection est **immunisée** contre rebuild/scroll/pagination. **Ne pas** stocker la sélection dans la `DataGridSource` ni par index de ligne.
- **Filtrage ACL : masquer par défaut, désactiver en option (AC2).** Conforme à l'énoncé epics (« actions filtrées par `ZAcl` »). Défaut = **masquer** (l'utilisateur ne voit pas une action interdite — comportement le plus courant IFFD). Un mode **désactiver** (grisé) est fourni pour les UX qui préfèrent la découvrabilité. Le discriminant est `acl.can(requiredPermission, …)` **synchrone** (le port est synchrone, E2-2 ; une ACL asynchrone/distante est **différée**, documentée sur `ZAcl`). Une action **sans** `requiredPermission` (custom) échappe au filtre.
- **Granularité ACL : row-level via `entityFor`, sinon collection-level (AC2).** `acl.can` accepte `target: ZEntity?` **et** `collectionId: String?`. Si `DynamicList` reçoit un `entityFor(row)` (ou une map `id→T`), le filtrage est **row-level** (`target: entity`). Sinon, filtrage **collection-level** (`target: null, collectionId`). Les deux sont neutres et testables ; le row-level est recommandé quand le contrôleur E4-3 fournit déjà les `T`.
- **Corbeille = ACTIONS soft-delete/restore, PAS listing des supprimés (frontière).** Le contrat `ZRepository` E2-2 est **gelé** : `getAll`/`watchAll` **excluent** les soft-deleted et n'exposent **aucun** `trashOnly`/`includeDeleted`. E4-4 livre donc les **actions** (softDelete bascule `is_deleted` hors-entité ; restore ; exclusion automatique en vue normale) — **entièrement testables** via un fake repo. Le **listing** de la corbeille (voir les items supprimés pour les restaurer) exigerait une **extension additive** (flag `ZDeletedScope`/`includeDeleted` sur `ZDataRequest`, AD-10) honorée par l'adaptateur E5 — **déféré**, voir **Ambiguïtés**. Restore reste utile sans listing (ex. « annuler » juste après une suppression).
- **Réactivité Flutter-native (AD-2/AD-15).** `ZListSelectionController` calque `ZFormController`/`ZListController` : `ChangeNotifier` + `ValueNotifier`/`ValueListenable` mémoïsé, `dispose()` propre, **aucun** gestionnaire d'état. Un widget écoute la **seule** tranche `selectedIds` via `ValueListenableBuilder` (rebuild ciblé). Le code Riverpod/GetX vit dans les **bindings**, jamais ici.

### Cohérence avec l'existant (patrons à réutiliser, ne pas réinventer)

- **`ZAcl` / `ZCrudAction` / `ZAllowAllAcl`** (`domain/ports/z_acl.dart`) : **consommés, non modifiés**. `can` synchrone ; `ZCrudAction` a déjà `delete` **et** `restore` (le commentaire `restore` cite explicitement « corbeille, E4-4 »). Défaut `ZAllowAllAcl` déjà câblé sur `ZcrudScope.acl`.
- **`ZRepository.softDelete`/`restore`** (`domain/ports/z_repository.dart:58,61`) : `Future<ZResult<Unit>>` ; docstring « basculent `is_deleted` hors-entité `ZSyncMeta` ; les lectures excluent les soft-deleted ». **Ne pas** réimplémenter la logique de suppression : appeler le port.
- **`ZSyncMeta`** (`domain/sync/z_sync_meta.dart`) : `isDeleted` hors-entité — **source** conceptuelle du soft-delete. E4-4 ne le manipule pas directement (le repository le fait) mais s'y réfère dans la doc.
- **`ZcrudScope`** (`presentation/zcrud_scope.dart`) : `acl` (défaut `ZAllowAllAcl`) et `listRenderer` résolus via `of`/`maybeOf`. Réutiliser le patron `maybeOf` (cf. `dynamic_list.dart:116`, correctif L1 E4-1) pour un message actionnable.
- **`ZListController`** (`presentation/list/z_list_controller.dart`, E4-3) : détient les entités `T` et expose `refresh()` — l'endroit naturel pour brancher `entityFor`/`softDelete`+`refresh`. **Ne pas** dupliquer la pagination/mapping.
- **`ZListRenderRequest`/`ZListRow`/`ZListColumn`** (`presentation/list/z_list_render_request.dart`, `z_list_column.dart`) : surface neutre ; `ZListRow.id` = **clé stable** de la sélection. `col.format` (format neutre partagé) déjà utilisé par le renderer.
- **`DynamicList`** (`presentation/list/dynamic_list.dart`, E4-2) : hôte à élargir (générique `<T>` + seams sélection/actions). Conserver le dispatch `ZListLayout` et les 4 vues d'état intacts.
- **`ZSfDataGridRenderer`** (`zcrud_list/.../z_sf_data_grid_renderer.dart`) : **cible du L2** ; sa docstring annonce déjà « L2 (déféré) … statefulness = E4-3/E4-4 ». Réutiliser `col.format` et les primitives directionnelles/`_kMinRowHeight` (≥ 48 dp) déjà en place.
- **`ZFormController`** (`presentation/z_form_controller.dart`) : patron `ChangeNotifier`/`ValueNotifier`/`dispose` — modèle du `ZListSelectionController`.

### Frontière E4-4 ↔ E4-5 (NE PAS déborder)

- **E4-4 (cette story)** : actions ligne filtrées `ZAcl`, sélection multiple stable (bug corrigé), corbeille soft-delete/restore (actions), statefulness grille L2. **STOP** ici.
- **E4-5** : **sous-listes / relations imbriquées** (`ZSubListScreen`, mini-CRUD) & **onglets de catégorisation** (`DynamicTab`). E4-4 **ne touche pas** aux relations ni aux onglets.
- **Déféré (hors E4)** : **listing de la corbeille** (voir les supprimés) → extension additive `ZDataRequest` (`includeDeleted`/`ZDeletedScope`) + honneur E5 `zcrud_firestore` ; **formatage locale-aware** (E4-2/E4-3) ; **ACL asynchrone/distante** (documenté sur `ZAcl`).

> Tentation d'ajouter un `ZSubListScreen`, des onglets, un flag `trashOnly` à `ZRepository`/`ZDataRequest`, ou de faire fuiter Syncfusion dans le cœur : **STOP**. E4-4 = actions/ACL/sélection/corbeille **neutres** dans le cœur + statefulness grille **dans `zcrud_list`**.

### Ambiguïtés détectées (à trancher par le dev / signalées)

1. **Listing de la corbeille non exprimable (contrat E2-2 gelé).** `getAll`/`watchAll` **excluent** les soft-deleted, sans `trashOnly`. → E4-4 livre les **actions** (softDelete/restore) ; le **listing des supprimés** est **déféré** (extension additive `ZDataRequest` ou E5). **Recommandation** : ne PAS modifier E2-2 dans cette story ; documenter l'extension. Restore reste testé via fake.
2. **`DynamicList` doit-il devenir générique `<T>` ?** Pour résoudre les actions (handler `onInvoke(context, T)`) et l'ACL row-level (`target: T`), il faut l'entité. **Recommandation** : rendre `DynamicList` générique `DynamicList<T extends ZEntity>` avec `rowActions: List<ZRowAction<T>>?` + `entityFor: T? Function(ZListRow)?`. Impact : les sites E4-1/E4-2 (`DynamicList` non paramétré) doivent rester compilables (défaut `T = ZEntity`, seams `null`). Vérifier la non-régression des usages `DynamicList.rows(...)`.
3. **Masquer vs désactiver par défaut (AC2).** Retenu : **masquer** par défaut, **désactiver** en option (`actionAclMode`). Si l'orchestrateur/PO préfère l'inverse, ajuster le défaut (les deux chemins restent testés).
4. **Suppression en lot : atomicité.** Best-effort (itère `softDelete`, collecte les `Left` via `onFailure`, `clearSelection` sur succès). Une transaction atomique multi-doc est **backend-spécifique** (E5) → non garantie ici ; documenté.

### Standards de test

- **Modèles & sélection** : unit `flutter_test` **purs** — `ZRowAction`/résolution (handler appelé, fabriques déplient `ZResult`, `Left`→`onFailure`), `ZListSelectionController` (toggle/selectAll/clear/range/modes/dispose).
- **`DynamicList`** : widget `flutter_test` avec **fake `ZAcl`** (refuse `delete`) via `ZcrudScope(acl:)` + **fake `ZRepository`** (Set `deleted`) + `FakeEntity implements ZEntity` + `toRow`/`entityFor` ; asserts : action interdite masquée/grisée, sélection stable au rebuild (`pumpWidget`) & au loadMore, soft-delete exclut/restore réinclut, `Left`→`onFailure` sans throw, a11y `Semantics`. **Layout `builder`** pour prouver le rendu sélection/actions **sans `zcrud_list`** (SM-5 exécutable).
- **`ZSfDataGridRenderer`** : widget `flutter_test` dans `zcrud_list` — source **mémoïsée** (identité stable au rebuild), sélection Syncfusion préservée, `onSelectionChanged` propagée ; graphe SM-5 vert (`ZSfDataGridRenderer` seule arête Syncfusion).
- **Pureté/graphe** : gardes `presentation_purity`/`no_heavy_file_dep`/`domain_purity` vertes sur les nouveaux fichiers ; graphe SM-5 `zcrud_list` vert.

### Project Structure Notes

- Neuf du cœur : `presentation/list/z_row_action.dart` (`ZRowAction<T>` + `ZResolvedRowAction` + fabriques corbeille), `presentation/list/z_list_selection.dart` (`ZListSelectionController` + `ZListSelectionMode`), `presentation/list/z_list_interaction.dart` (`ZListInteraction` neutre). Modifiés : `z_list_renderer.dart` (build élargi), `dynamic_list.dart` (générique + seams sélection/actions/ACL), `zcrud_core.dart` (barrel).
- `zcrud_list` : `z_sf_data_grid_renderer.dart` refactoré (StatefulWidget + source mémoïsée + `DataGridController` + consommation `ZListInteraction`). **Seule** arête Syncfusion inchangée dans son principe.
- `pubspec.yaml` **inchangé** — out-degree 0 (AD-1) : pas de nouvelle dépendance. `melos list` = 14 ; aucun nouveau package.
- Aucun conflit de structure. `ZAcl`/`ZCrudAction`/`ZRepository`/`ZSyncMeta`/`ZcrudScope`/`ZListRow` déjà en place.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E4 — Moteur DynamicList] (Story E4-4 : « actions filtrées par `ZAcl` (AD-16) ; sélection multiple fonctionnelle (**bug corrigé**) ; corbeille soft-delete » ; frontière E4-5 sous-listes/onglets)
- [Source: architecture.md#AD-16] (le contrôle d'accès passe par un port **`ZAcl` fourni par l'app** — **aucune règle métier dans le cœur** ; soft-delete `is_deleted` hors-entité dans le contrat neutre ; impl backend en `zcrud_firestore`)
- [Source: architecture.md#AD-9] (offline-first : store local source de vérité, **soft-delete `is_deleted` hors-entité standardisé `ZSyncMeta`**, LWW sur `updatedAt`, cascade bornée)
- [Source: architecture.md#AD-8] (liste dérivée du schéma derrière `ZListRenderer` ; **Syncfusion isolé dans `zcrud_list`** ; le cœur n'expose que l'abstraction — actions/sélection/ACL restent **neutres** dans le cœur)
- [Source: architecture.md#AD-11] (`Either<ZFailure,Unit>` sur les mutations `softDelete`/`restore` ; jamais de `try-catch` nu ; `Left` déplié, non fatal)
- [Source: architecture.md#AD-2 / AD-15] (réactivité **Flutter-native** `ChangeNotifier`/`ValueListenable` pour la sélection ; **aucun** gestionnaire d'état dans le cœur)
- [Source: architecture.md#AD-13] (a11y/RTL : `Semantics` boutons d'action, cibles ≥ 48 dp, primitives directionnelles ; état sélectionné annoncé)
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#SM-5] (isolation des dépendances : logique actions/ACL/sélection/corbeille **neutre** dans le cœur ; **statefulness Syncfusion cantonnée à `zcrud_list`**)
- [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart] (`ZAcl.can(action, {target, collectionId})` synchrone ; `ZCrudAction{view,create,update,delete,restore}` ; `ZAllowAllAcl` défaut — **consommés, non modifiés**)
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart:58,61] (`softDelete(id)`/`restore(id)` → `ZResult<Unit>` ; bascule `is_deleted` hors-entité ; lectures excluent les soft-deleted)
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart] (`ZSyncMeta.isDeleted` hors-entité, `is_deleted` snake_case, désérialisation défensive — source du soft-delete)
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:62,94] (seams `acl` (défaut `ZAllowAllAcl`) & `listRenderer` ; `of`/`maybeOf`)
- [Source: packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart] (hôte E4-2 à élargir ; dispatch `ZListLayout` + 4 vues d'état à préserver ; patron `maybeOf` L1)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart] (port `ZListRenderer.build` à élargir d'un `{ZListInteraction? interaction}` rétro-compatible)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart] (`ZListRow{id,cells}` — `id` = clé stable de la sélection ; `ZListRenderRequest` égalité de valeur à **préserver**)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_controller.dart] (E4-3 : détient `T` + `refresh()` — branchement `entityFor`/soft-delete+refresh)
- [Source: packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart] (**cible L2** : `_ZListDataGridSource` recréée par `build` → à mémoïser dans un `State` + `DataGridController` persistant ; seule arête Syncfusion)
- [Source: _bmad-output/implementation-artifacts/stories/code-review-e4-1.md#L2] (« `_ZListDataGridSource` recréé à chaque `build()` → perte d'état grille (scroll/sélection) sur rebuild ; à traiter en E4-2/E4-3 » → **E4-4**)
- [Source: docs/technical-inventory.md:58,60,63] (bug sélection IFFD `_dataGridController` commenté `dynamic_list_screen.dart:1094,1100` **buggy** ; actions CRUD+ACL `CrudActionsButons`+`RessourceACL` `:73-342` mature ; corbeille `trashOnly` `:1272` mature)
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart] (patron `ChangeNotifier`/`ValueNotifier`/`dispose` — modèle du `ZListSelectionController`)
- [Source: _bmad-output/implementation-artifacts/stories/e4-3-recherche-filtres-tri-pagination.md] (E4-3 : `ZListController` + refresh ; frontière déférant explicitement actions/`ZAcl`/sélection/corbeille + **statefulness L2** à E4-4)
- [Source: _bmad-output/implementation-artifacts/stories/e2-2-ports-donnees.md] (E2-2 : `ZAcl`/`ZCrudAction`/`ZAllowAllAcl` + `ZRepository.softDelete`/`restore` posés)
- [Source: CLAUDE.md#Key Don'ts] (jamais de règle métier ACL dans le cœur ; jamais de `try-catch` nu — `Either` ; jamais Syncfusion dans le cœur ; directionnels ≥ 48 dp)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story)

### Debug Log References

- `melos run analyze` → RC=0 (14 packages, « No issues found » ; SUCCESS).
- `melos run test` → RC=0 (SUCCESS ; `zcrud_core` 545 tests, `zcrud_list` 20 tests dont graphe SM-5 a/b/c/d).
- `melos run verify` → RC=0 : `graph_proof` **CORE OUT=0 OK** + **ACYCLIQUE OK** ; `gate:melos` OK ; `gate:reflectable` OK ; `gate:secrets` OK ; `gate:codegen` OK (1 modèle, 0 `.g.dart` manquant) ; `gate:compat` OK (voie manifeste) ; `verify:serialization` RC=0 (SKIP lisibles).
- `melos list` = 14 ; `git ls-files '*.g.dart' '*.freezed.dart'` = 0.

### Remédiation code-review (passe post-review, 2026-07-10)

Corrige les findings du rapport `code-review-e4-4.md`. Status reste `review`.

- **MEDIUM-1 (perf) — CORRIGÉ.** `z_sf_data_grid_renderer.dart:90-118` (`didUpdateWidget`) : le rebuild lourd de la source (`_source.update()`, qui efface/reconstruit TOUS les `DataGridRow`) est désormais gaté sur le seul changement de **données** (`widget.request != old.request`) OU la **présence** d'actions (null↔non-null, qui modifie le nombre de cellules). Quand SEULE la closure `actionsFor` change d'identité (recréée à chaque `build` de `DynamicList._buildInteraction`, ex. à chaque cocher-case) alors que les données sont inchangées, on appelle le nouveau `_ZListDataGridSource.refreshActions()` (`z_sf_data_grid_renderer.dart:266-283`) qui rafraîchit la référence de résolution SANS reconstruire les lignes (l'actions-cell est résolue paresseusement dans `buildRow`). Résultat : cocher une case NE reconstruit plus la source de grille (mémoïsation L2 préservée). Test PERF ajouté (`z_sf_data_grid_renderer_test.dart`) : un changement de sélection ⇒ 0 reconstruction (identité `source.rows.first` conservée) ; un changement de lignes ⇒ 1 (identité perdue) ; + apparition/disparition d'actions ⇒ reconstruction (colonne d'actions).
- **LOW-1 — COUVERT.** Test `zcrud_list` : `interaction.selectedIds={'2'}` → `controller.selectedRows` mappe la 2ᵉ ligne, et la sélection VISUELLE survit au rebuild parent (re-mappée par id stable).
- **LOW-2 — COUVERT.** Test `zcrud_core` (`dynamic_list_actions_acl_test.dart`) : `entityFor: (_) => null` ⇒ actions omises pour toutes les lignes, aucune exception, cellules toujours rendues.
- **LOW-4 — CORRIGÉ.** `scripts/ci/verify_serialization.dart` : un package retournant exit 79 (« no tests ran ») affiche désormais `verify:serialization — <pkg> : SKIP (aucun test serialization-compat)` au lieu de relayer le stderr trompeur « ERROR: No tests match the requested tag selectors ». Sémantique du gate inchangée (79 toléré, RC global 0). Prouvé : sortie SKIP pour provider/annotations/get/core/list/riverpod ; `zcrud_generator` exécute réellement ses tests serialization-compat (52 passés) ; RC=0.
- **LOW-3 — DÉFÉRÉ (documenté).** L'élagage de la sélection aux lignes réellement visibles après filtre/recherche relève de l'**interaction E4-3↔E4-4↔E4-5** (sous-listes/onglets). Comportement retenu pour l'instant : « sélection persistante par id » (les lignes ré-apparaissent sélectionnées après levée d'un filtre). À trancher lors du câblage E4-5 ; hors périmètre de la remédiation. `softDeleteSelected` élague déjà correctement les id supprimés.

### Completion Notes List

- **Décision (ambiguïté #2) — `DynamicList` générique `<T extends ZEntity>`** (défaut `ZEntity`, seams `null`). Non-régression stricte E4-1/E4-2 : `.rows`/constructeur primaire conservés, chemin d'origine emprunté quand ni `selection` ni `rowActions`. Les 4 fakes `ZListRenderer` de test (delegation/layout/renderer_not_called/scope) adaptés au paramètre nommé optionnel `{ZListInteraction? interaction}` (rétro-compat prouvée : leur comportement fonctionnel est inchangé).
- **Décision — `rowActions` requiert `entityFor`.** Le handler `onInvoke(context, T)` et l'ACL row-level (`target: entity`) ont besoin de l'entité ; une ligne dont `entityFor` renvoie `null` voit ses actions **omises** (défensif). Le filtrage collection-level reste possible via `collectionId` (l'ACL peut ignorer `target`).
- **Décision (ambiguïté #3) — masquer par défaut, désactiver en option** via `actionAclMode` (les deux chemins testés).
- **Décision (ambiguïté #1) — listing corbeille DÉFÉRÉ.** Contrat E2-2 gelé (aucun `trashOnly`) : E4-4 ne livre que les **actions** soft-delete/restore (testées via fake repo `Set deleted` : `getAll` exclut, restore ré-inclut, aucune suppression dure).
- **Bug historique de sélection CORRIGÉ (AC4).** État dans `ZListSelectionController` keyé par `id` STABLE, HORS renderer → prouvé stable au rebuild du parent / au loadMore (ajout de lignes) / au tap, en layout `builder` **sans Syncfusion** (SM-5 exécutable). Côté grille (L2), `ZSfDataGridRenderer` devient `StatefulWidget` : `DataGridSource` **mémoïsée** (identité `SfDataGrid.source` conservée au rebuild) + `DataGridController` **persistant** (identité conservée) + liaison bidirectionnelle `selectedIds`↔`onSelectionChanged` (id stables).
- **SM-5 maintenue.** Logique actions/ACL/sélection/corbeille 100 % neutre dans le cœur (0 syncfusion) ; `ZListInteraction` hors `ZListRenderRequest` (égalité de valeur préservée) ; statefulness Syncfusion cantonnée à `zcrud_list` ; graphe SM-5 (a) `zcrud_core` sans syncfusion, (b) `zcrud_markdown` idem, (c) contrôle positif `zcrud_list`, (d) acyclicité — **vert**. Gardes de pureté (`presentation_purity`/`no_heavy_file_dep`/`domain_purity`/`style_purity`) vertes.
- **a11y (AC9)** : boutons d'action `Semantics(button, enabled, label)` + cibles ≥ 48 dp + directionnels ; case de sélection `Semantics(selected:)`. Libellés via seam l10n `label(context, key)` (ajout des clés `restore` en/fr).
- Aucune dépendance ajoutée (`pubspec.yaml` inchangés, out-degree 0). Aucun finding critique/majeur ouvert.

### File List

**Créés (`zcrud_core`)**
- `packages/zcrud_core/lib/src/presentation/list/z_row_action.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_interaction.dart`
- `packages/zcrud_core/test/presentation/list/z_row_action_test.dart`
- `packages/zcrud_core/test/presentation/list/z_list_selection_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_actions_acl_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_selection_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_trash_test.dart`

**Modifiés (`zcrud_core`)**
- `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart` (générique `<T>` + seams sélection/actions/ACL + vues interactives)
- `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart` (port `build` élargi `{ZListInteraction? interaction}`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clés `restore` en/fr)
- `packages/zcrud_core/lib/zcrud_core.dart` (barrel : 3 exports)
- `packages/zcrud_core/test/presentation/zcrud_scope_test.dart` (fake renderer adapté)
- `packages/zcrud_core/test/presentation/list/dynamic_list_delegation_test.dart` (fake renderer adapté)
- `packages/zcrud_core/test/presentation/list/dynamic_list_layout_test.dart` (fake renderer adapté)
- `packages/zcrud_core/test/presentation/list/dynamic_list_renderer_not_called_test.dart` (fake renderer adapté)

**Modifiés (`zcrud_list`)**
- `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` (L2 : StatefulWidget + source mémoïsée + `DataGridController` persistant + consommation `ZListInteraction` ; **remédiation MEDIUM-1** : gate rebuild source sur données/présence-actions + `refreshActions()` sans reconstruction)
- `packages/zcrud_list/test/z_sf_data_grid_renderer_test.dart` (+7 tests L2/AC5 ; **remédiation** : +3 tests PERF MEDIUM-1 / LOW-1 → 20 tests)

**Modifiés (remédiation code-review)**
- `packages/zcrud_core/test/presentation/list/dynamic_list_actions_acl_test.dart` (+1 test LOW-2 `entityFor→null`)
- `scripts/ci/verify_serialization.dart` (LOW-4 : SKIP lisible au lieu du stderr « ERROR: No tests match »)

## Change Log

| Date | Version | Description | Auteur |
|------|---------|-------------|--------|
| 2026-07-10 | 0.1 | Création story E4-4 (create-story) : actions ligne neutres `ZRowAction<T>`/`ZResolvedRowAction` filtrées par `ZAcl` (AD-16), sélection multiple neutre `ZListSelectionController` (bug historique `_dataGridController`+L2 corrigé — état keyé par `id` hors renderer + grille stateful/mémoïsée dans `zcrud_list`), corbeille soft-delete/restore via `ZRepository` (AD-9/AD-11), pont neutre `ZListInteraction` (port `build` élargi rétro-compatible). 10 ACs, 7 tâches. Frontière E4-5 (sous-listes/onglets) + listing corbeille déféré. Status → ready-for-dev. | create-story (claude-opus-4-8) |
| 2026-07-10 | 0.2 | Implémentation E4-4 (dev-story) : `ZRowAction<T>`/`ZResolvedRowAction`/`ZActionAclMode` + fabriques corbeille ; `ZListSelectionController`/`ZListSelectionMode` (+ `softDeleteSelected` en lot) ; `ZListInteraction` neutre ; port `ZListRenderer.build` élargi ; `DynamicList<T>` générique + câblage ACL/sélection/actions + vues interactives `builder` ; L2 `ZSfDataGridRenderer` StatefulWidget (source mémoïsée + `DataGridController` persistant). +33 tests cœur, +7 tests `zcrud_list`. Vérif verte rejouée : analyze RC=0 (14), test RC=0 (workspace), verify RC=0 (CORE OUT=0, SM-5 graphe, gates). Bug de sélection prouvé corrigé (rebuild/loadMore/tap). Status → review. | dev-story (claude-opus-4-8) |
| 2026-07-10 | 0.3 | Remédiation code-review E4-4 : MEDIUM-1 (perf) corrigé — la source de grille n'est plus reconstruite au changement de sélection (gate rebuild sur données/présence-actions + `refreshActions()`) ; LOW-1/LOW-2 couverts par tests ; LOW-4 corrigé — `verify:serialization` affiche SKIP (plus « ERROR: No tests match ») ; LOW-3 déféré (interaction filtre/E4-5, documenté). +3 tests `zcrud_list` (20), +1 test cœur (545). Vérif verte rejouée : analyze RC=0 (14), test RC=0, verify RC=0 (CORE OUT=0, ACYCLIQUE, SM-5, gates). Status reste review. | dev-story remédiation (claude-opus-4-8) |
