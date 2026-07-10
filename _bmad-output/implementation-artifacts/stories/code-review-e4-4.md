# Code Review — Story E4-4 : Actions de ligne + ZAcl, sélection multiple, corbeille soft-delete/restore

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, chemin pris = skill réel, PAS le fallback disque).
- **Date** : 2026-07-10
- **Reviewer** : agent adversarial (Blind Hunter + Edge Case Hunter + Acceptance Auditor)
- **Baseline** : `868438a7` (= HEAD ; tout E4 est en working tree). Diff revu = fichiers E4-4 de la File List.
- **Verdict** : **APPROVED** (0 HIGH, 0 MAJEUR ; 1 MEDIUM + 3 LOW ci-dessous — le MEDIUM est une régression de performance à corriger de préférence dans le périmètre, sinon à justifier par écrit selon CLAUDE.md).

---

## Vérif verte rejouée RÉELLEMENT sur disque

| Contrôle | Résultat |
|---|---|
| `melos run analyze` | **RC=0** — 14 packages, « No issues found », SUCCESS |
| `flutter test` (`zcrud_core`) | **RC=0** — **544 tests** passés |
| `flutter test` (`zcrud_list`) | **RC=0** — **17 tests** passés (dont L2/AC5 : source mémoïsée, update en place, controller persistant, selectionMode, onSelectionChanged, colonne actions) |
| `graph_proof.py` (SM-5/AD-1) | **CORE OUT=0 OK** + **ACYCLIQUE OK** — 14 nœuds, 17 arêtes ; `out-degree(zcrud_core)=0` |
| SM-5 graphe (`sm5_syncfusion_isolation_graph_test.dart`) | **vert** — (a) core sans syncfusion, (b) markdown sans syncfusion, (c) contrôle positif list AVEC syncfusion, (d) acyclicité |
| `gate:reflectable` | **OK** — 0 usage hors allowlist (AD-3) |
| `gate:secrets` | **OK** — aucun secret (AD-12) |
| `melos list` | **14** |
| `git ls-files '*.g.dart' '*.freezed.dart'` | **0** |
| `melos run verify` (agrégat) | **N'a PAS renvoyé RC=0** dans mon run : le sous-gate **`verify:serialization`** trébuche sur `zcrud_riverpod` (`No tests match tag selectors: serialization-compat`). **Pré-existant, HORS diff E4-4** (aucun code de sérialisation touché ; documenté « no-op » dans les Dev Notes). Tous les gates *pertinents* pour E4-4 (analyze, tests, graph, reflectable, secrets) sont verts individuellement. Voir LOW-4. |

---

## Vérification adversariale des points de vigilance

### 1. Sélection stable = bug historique (AC4) — **CORRIGÉ, confirmé**
- **Cœur (L1)** : l'état vit dans `ZListSelectionController` (`ChangeNotifier`+`ValueNotifier`), keyé par `ZListRow.id` **stable** (`z_list_selection.dart`), **hors** renderer. `DynamicList._buildReady` écoute la seule tranche `selectedIds` via `ValueListenableBuilder` (rebuild ciblé, AD-2). `dynamic_list_selection_test.dart` rejoué : sélection préservée au **rebuild parent** (nouvelle instance `DynamicList`, mêmes id), au **loadMore** (3→5 lignes, un nouveau `ZListReady`), et au **tap** ; a11y `Semantics(selected:)` vérifiée. **Aucun chemin de perte trouvé côté cœur.**
- **L2 (`zcrud_list`)** : `SfDataGrid.source` ET `.controller` conservent leur **identité** au rebuild — prouvé par `AC5 : source MÉMOÏSÉE (identical)` et `AC5 : DataGridController PERSISTANT (identical)`. Source **mise à jour en place** via `didUpdateWidget → _source.update()` (jamais recréée par `build`). Ligne supprimée puis re-sélectionnée : `_syncControllerFromInteraction` reconstruit `controller.selectedRows` à partir des **id** (pas des instances `DataGridRow`), après `update()` — donc les instances fraîches sont re-mappées correctement. **Pas de perte de sélection confirmée.** Réserve de couverture : voir LOW-1.

### 2. Actions filtrées ZAcl (AD-16) — **conforme**
- `DynamicList._resolveActions` lit `ZcrudScope.maybeOf(context)?.acl ?? const ZAllowAllAcl()` et calcule `allowed = permission == null || acl.can(permission, target: entity, collectionId:)`. Mode **`hide`** (défaut) → `continue` (action omise) ; mode **`disable`** → action incluse avec `enabled=false`, `onPressed=null` (non cliquable). `dynamic_list_actions_acl_test.dart` rejoué : deny `delete` → masquée (hide) / grisée non cliquable (disable) ; `ZAllowAllAcl` → toutes présentes ; action **custom sans permission** toujours présente.
- **Renderer aveugle à `T` et `ZAcl`** : le pont `ZListInteraction.actionsFor` renvoie `List<ZResolvedRowAction>` (sans `T`, `enabled`/`onInvoke` déjà liés). `z_sf_data_grid_renderer.dart` et `z_list_renderer.dart` n'importent ni `ZAcl` ni `T`. **Confirmé.**
- **Ligne sans entité** (`entityFor→null`) → `_resolveActions` renvoie `const []` (actions omises). Confirmé dans le code ; **non testé** (LOW-2).

### 3. Soft-delete corbeille (AD-9) — **conforme, aucune suppression dure**
- `ZRowAction.softDelete` / `ZListSelectionController.softDeleteSelected` appellent **uniquement** le port `repository.softDelete(id)` ; le cœur ne touche jamais l'entité ni `ZSyncMeta` → **aucune fuite de `is_deleted` dans l'entité**, **aucune suppression physique** dans le code du cœur. `dynamic_list_trash_test.dart` rejoué : `softDelete('a')` exclut `a` de `getAll` mais `store.containsKey('a')` reste vrai ; `restore('a')` ré-inclut ; lot `softDeleteSelected({a,b})` exclut a et b et vide la sélection.
- **Best-effort / `Left` non fatal (AD-11)** : `result.fold(onFailure, onSuccess)` — 0 `try-catch` nu, 0 throw. Test `Left(ServerFailure)` → `onFailure` reçoit la failure, `repo.deleted` reste vide, `tester.takeException()==null`. `softDeleteSelected` retire seulement les succès, `onSuccess` si `allOk`. **Confirmé.**

### 4. DynamicList générique `<T>` — **non-régression confirmée**
- Défaut `T=ZEntity` ; `_interactive = selection != null || rowActions != null`. Seams `null` → `_dispatch(context, request, null, {})` = chemin E4-1/E4-2 intact (`_renderViaBackend(request, null)` / `_ZListBuilderView`). Fabrique `DynamicList.rows` conservée. Port `ZListRenderer.build(..., {ZListInteraction? interaction})` élargi par **paramètre nommé optionnel** → rétro-compatible ; les fakes de test adaptés ; analyze RC=0 sur les 14 packages prouve la non-casse des sites existants.

### 5. SM-5 maintenue — **confirmée**
- Cœur 0 syncfusion (imports vérifiés : `z_row_action` = `dart:async`+`flutter/widgets`+core ; `z_list_selection` = `flutter/foundation`+core ; `z_list_interaction` = `flutter/foundation`+core ; `dynamic_list` = `flutter/material`+core). `ZListInteraction` vit **hors** `ZListRenderRequest` (préserve l'égalité de valeur E4-1/E4-2 — les callbacks non comparables ne polluent pas le value object). Statefulness Syncfusion **cantonnée** à `_ZSfDataGrid`/`_ZListDataGridSource` dans `zcrud_list`. Graphe SM-5 (a/b/c/d) + graph_proof CORE OUT=0 verts. **Aucune fuite de statefulness L2 dans le cœur.**

### 6. Réactivité (AD-2/AD-15) — **conforme**
- `ZListSelectionController` = `ChangeNotifier` exposant `ValueListenable<Set<String>>` (Flutter-native, calque `ZFormController`). Émet des `Set.unmodifiable`. Rebuild ciblé sur `selectedIds` (`ValueListenableBuilder`). `dispose()` libère le `ValueNotifier` + garde `_disposed` (mutations post-dispose = no-op ; testé). Aucun gestionnaire d'état.

---

## Findings (triage sévérité)

### MEDIUM-1 — La source Syncfusion est reconstruite (`update()`) à CHAQUE rebuild dès qu'il y a des actions → mémoïsation partiellement défaite (perf)
- **Fichiers** : `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart:196` (closure `actionsFor`) + `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart:95-103` (`didUpdateWidget`).
- **Cause** : `_buildInteraction` crée une **nouvelle** closure `actionsFor: (row) => _resolveActions(context, row)` à chaque `build`. Dans `didUpdateWidget`, la garde
  `if (widget.request != old.request || !identical(widget.interaction?.actionsFor, old.interaction?.actionsFor))`
  est donc **toujours vraie** quand des actions sont présentes (`identical(closureA, closureB)` == false), déclenchant `_source.update()` — qui **efface et reconstruit TOUS les `DataGridRow`** + `notifyListeners()` — à chaque rebuild parent.
- **Impact concret** : dans une liste **actionnable** (le cas nominal d'E4-4), **cocher une seule case** rebuild l'`interaction` (via `ValueListenableBuilder`) → reconstruit **toutes** les lignes de la grille + re-render complet. L'**identité** de la source est bien préservée (AC5 littéral vert), mais l'**intention** de mémoïsation d'AC5 (« mise à jour en place seulement quand les lignes changent ») est contournée dès qu'`actionsFor != null`. Aucune perte de sélection/scroll (la sélection est re-synchronisée juste après, le scroll vit dans l'état de `SfDataGrid`) → **régression de performance, pas de correction fonctionnelle**.
- **Reco** : gater `_source.update()` sur le seul changement de **données** (`widget.request != old.request`), et traiter le changement d'`actionsFor` sans reconstruire les lignes (l'actions-cell est déjà résolue paresseusement dans `buildRow` via `_actionsFor`, il suffit d'assigner `_actionsFor` + `notifyListeners()` sans `_dataRows.clear()`), **ou** mémoïser la closure `actionsFor` dans `DynamicList` (stable tant que `rowActions`/`entityFor`/`acl` sont stables). Ajouter un test de non-reconstruction des `DataGridRow` au rebuild sélection-only-avec-actions.
- **Statut** : à corriger de préférence dans le périmètre (MEDIUM, CLAUDE.md) ; sinon justifier — n'invalide aucun AC testé.

### LOW-1 — Persistance visuelle de la sélection L2 non assertée directement (trou de couverture)
- Les tests `zcrud_list` prouvent l'identité (source/controller) et le mapping `onSelectionChanged→id`, mais **aucun** ne pose une `interaction.selectedIds={'2'}`, rebuild, puis n'assert que `controller.selectedRows` mappe toujours l'id `'2'` (round-trip `_syncControllerFromInteraction`). La stabilité côté cœur est prouvée (layout builder) ; la persistance **visuelle Syncfusion** au rebuild est inférée de l'identité + sync, non directement vérifiée. Ajouter ce test durcirait la preuve du bug corrigé au niveau L2.

### LOW-2 — Omission d'actions pour une ligne sans entité (`entityFor→null`) non testée
- `_resolveActions` renvoie `const []` quand `entityFor` renvoie `null` (comportement défensif documenté en Dev Notes). Aucun test ne le couvre. Ajouter un cas `entityFor: (_) => null` → 0 bouton d'action rendu.

### LOW-3 — La sélection n'est pas élaguée sur les lignes réellement visibles (edge filtre/refresh)
- `ZListSelectionController.selectedIds` conserve des `id` même si la ligne correspondante disparaît via **filtre/recherche** (E4-3, pas via delete — `softDeleteSelected` retire bien les supprimés). Conséquence : sélectionner, puis filtrer (masque des lignes), puis lever le filtre ⇒ les lignes ré-apparaissent **sélectionnées**. Peut surprendre pour un « select-all puis filtre ». Comportement acceptable/déférable, mais non documenté ni testé côté concurrence E4-3. À trancher (garder = « sélection persistante par id » ; ou élaguer aux id visibles au refresh).

### LOW-4 — L'agrégat `melos run verify` ne renvoie pas RC=0 (cause pré-existante hors E4-4)
- Le sous-gate `verify:serialization` échoue sur `zcrud_riverpod` (`No tests match tag selectors: serialization-compat`). Indépendant du diff E4-4 (aucun code de sérialisation), documenté « no-op » dans les Dev Notes, mais l'affirmation « `melos run verify` RC=0 » des Dev Notes n'est **pas reproductible** telle quelle. Les gates E4-4-pertinents passent isolément. À corriger au niveau infra CI (hors story) ou à requalifier l'assertion des Dev Notes.

---

## Couverture des trous demandés (edge cases)
- **sélection → suppression → restore** : `softDeleteSelected` retire les id supprimés de la sélection (testé) ; `restore` ne re-sélectionne pas (correct). OK.
- **action custom sans permission** : toujours incluse (testé, `archiveX`). OK.
- **select-all sur page paginée** : `selectAll(ids)` = union des id **fournis** (lignes chargées) ; les items non encore paginés ne sont pas sélectionnés (sémantique « sélection du visible », attendue). Non explicitement testé sur données paginées → cf. LOW-3 pour l'interaction filtre.
- **sélection + reseed/refresh (concurrence E4-3)** : id stables ⇒ survie au reseed (loadMore testé) ; interaction avec filtre non couverte (LOW-3).

---

## Conclusion
Les quatre risques adversariaux majeurs sont **écartés** : (1) la sélection **ne se perd plus** au rebuild/scroll/loadMore/tap (cœur prouvé, L2 par identité source+controller) ; (2) une action non autorisée est **réellement** masquée/désactivée et le renderer **ne voit ni `T` ni `ZAcl`** ; (3) le soft-delete **ne supprime jamais en dur** et n'écrit que via le port (best-effort, `Left` non fatal) ; (4) **aucune fuite Syncfusion** dans le cœur (SM-5/CORE OUT=0 verts). Non-régression E4-1/E4-2/E4-3 confirmée (analyze 14/14, 544+17 tests). Reste **1 MEDIUM** (reconstruction de source à chaque rebuild avec actions — perf, à corriger de préférence) et **3 LOW** (trous de couverture / edge filtre / agrégat verify pré-existant).

**Verdict : APPROVED.**
