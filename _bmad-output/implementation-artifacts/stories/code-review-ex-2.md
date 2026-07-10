# Code-review — EX-2 : démo LISTE (`DynamicList`) dans l'app exemple

Statut story : `review` · Revue adversariale (bmad-code-review, effort high) · Baseline `fe203b90`
Skill : `Skill(bmad-code-review)` (chemin pris : tool `Skill`, step-file architecture ; script `resolve_customization.py` OK).

## Périmètre revu (tous sous `example/`)

- `example/lib/demos/list_demo_data.dart` (nouveau) — `DemoRecord`/`DemoStore`/`DemoRepository` + `demoSchema` + `toDemoRow`
- `example/lib/demos/list_demo_screen.dart` (nouveau) — `ListDemoScreen`/`TrashScreen`/`CategoryTabsScreen`/`_DemoAcl`
- `example/lib/app.dart` (modifié) — `listRenderer: const ZSfDataGridRenderer()` au scope racine
- `example/lib/home_screen.dart` (modifié) — entrée « Liste » activée
- `example/pubspec.yaml` (modifié) — `zcrud_list` + override ; `syncfusion_flutter_datagrid` dev_dep ; `uses-material-design`
- `example/test/list_demo_test.dart` (nouveau, 12 tests) + `example/test/boundary_deps_test.dart` (frontière EX-2)
- `packages/zcrud_*` : LECTURE SEULE (vérif de l'API consommée)

## Verdicts

| Contrôle | Verdict | Preuve |
|---|---|---|
| SM-5 isolation (app tire Syncfusion via `zcrud_list`, pas via `zcrud_core`) | **OUI** | `import 'package:zcrud_list/zcrud_list.dart'` uniquement dans `app.dart`/test ; renderer injecté au scope racine ; `zcrud_core` non modifié |
| `packages/**` non touché par EX-2 | **OUI** | `git status -- packages/` ne liste que `zcrud_geo`/`zcrud_markdown` (E11a/E6 parallèles) ; aucun fichier EX-2 |
| No-secret / no-license committée | **OUI** | grep `registerLicense|SyncfusionLicense|api_key|badCertificate` → NONE dans `example/` |
| Parité 4 bindings réelle | **OUI (runtime)** / partielle (test) | `wrapWithBinding(rootScope:)` + `KeyedSubtree(ValueKey)` sous les 4 ; `_BindingSeamForwarder` re-propage `root.listRenderer` ; nested `ZcrudScope` recopie **les 8 seams** ; test = scope+riverpod (2/4, autorisé AC8 « ≥2 ») |
| dispose / AD-2 | **OUI** | `ZListController` stable (`initState`/`dispose`), unique tranche `state` via `ValueListenableBuilder` ; dispose sélection (dépendante) AVANT controller (MAJEUR-1 EX-1) au switch ET en fin de vie |
| Frontière EX-2/EX-3 | **OUI** | seul `zcrud_list` ajouté ; firestore/markdown/geo/intl/export interdits (boundary test étendu) ; entrées d'accueil EX-3 « à venir » |
| Invariant « 14 packages » / lock racine | **OUI** (déclaré) | app hors `workspace:`/`packages/**` ; lock propre `example/pubspec.lock` ; `git diff pubspec.lock` racine sans ligne EX-2 |

## Findings

### MEDIUM-1 — Pagination non navigable dans l'UI (`loadMore()` jamais invoqué)
- **Fichier** : `example/lib/demos/list_demo_screen.dart` (aucun appel `loadMore` dans tout `example/lib/`).
- **Preuve** : `pageSize: 15` sur `ListDemoScreen` et l'onglet « Toutes » (`CategoryTabsScreen`), source seedée de **48** lignes. `DynamicList` n'expose **aucun** hook `onLoadMore`/scroll-end, `ZListController.loadMore()` n'est appelé nulle part, et `zcrud_list`/`SfDataGrid` n'ont pas de `loadMoreViewBuilder`. Résultat : seuls 15/48 enregistrements de la liste active (et de l'onglet « Toutes ») sont atteignables ; le chemin curseur/`loadMore` n'est **jamais exercé end-to-end dans l'app**.
- **Impact** : AC4(d) / T4 « contrôle/scroll de pagination » partiellement non tenu. La couche données supporte le curseur et est testée (`limit: 15 → 15 lignes`), mais l'affordance UI manque — ce qui contredit le but « validation end-to-end » du harnais. Pas de crash, données seedées partiellement inaccessibles.
- **Remède** : câbler un contrôle « Charger plus » (ou détection de fin de scroll) appelant `_controller.loadMore()` quand `state` (`ZListReady`) indique `hasMore`, et l'exercer par un test (page 2 atteinte). À défaut, justifier par écrit le report en documentant que la pagination reste validée à la couche données uniquement.

### LOW-1 — `DemoRepository.watch()/watchAll()` ignorent `includeDeleted` et le `request`
- **Fichier** : `example/lib/demos/list_demo_data.dart:217-220`.
- **Preuve** : les deux flux retournent `store.changes` qui émet toujours `visible(includeDeleted: false)` — même pour la vue corbeille (`includeDeleted: true`). Pas de bug vivant : `ZListController` n'utilise l'émission que comme **déclencheur** (`watchAll().listen((_) => _runQuery())`) et lit réellement les données via `getAll` (qui, lui, honore `includeDeleted`). C'est donc un piège sémantique **latent** : si un jour un consommateur lit directement le flux de la vue corbeille, il recevrait les actifs.
- **Remède** : faire émettre à `_emit()`/aux flux la vue correspondant à `includeDeleted`, ou documenter explicitement que le flux est un simple signal de mutation.

### LOW-2 — `syncfusion_flutter_datagrid` déclaré en dev_dependency **directe** de l'app
- **Fichier** : `example/pubspec.yaml` (bloc `dev_dependencies`).
- **Preuve** : ajout de `syncfusion_flutter_datagrid: ^32.1.19` pour l'import de test (`find.byType(SfDataGrid)`), justifié par `depend_on_referenced_packages`. Introduit une arête Syncfusion **directe** côté app, légère entorse au « l'app tire Syncfusion **exclusivement** via `zcrud_list` » (AC9). Test-only ; le runtime reste transitivement via `zcrud_list`.
- **Remède** : acceptable (test-only) ; à défaut, asserter le type de rendu via une abstraction du cœur plutôt que par le type Syncfusion concret.

### LOW-3 — Test de parité limité à 2 bindings sur 4
- **Fichier** : `example/test/list_demo_test.dart:180` (`<DemoBinding>[scope, riverpod]`).
- **Preuve** : la parité liste n'est testée que sous `scope` + `riverpod`. `get` et `provider` sont montés au runtime (`BindingSelector`) mais non couverts par un test. Conforme à AC8 (« ≥ 2 wraps »), mais l'extension à 4 est triviale et durcirait la garantie de re-propagation du renderer sous get/provider.
- **Remède** : étendre la liste paramétrée aux 4 `DemoBinding`.

## Vérif verte (rejouée par l'orchestrateur, hors périmètre agent)
- `example/` : `flutter analyze` 0 issue · `flutter test` 30 tests OK · lock propre · `packages/` non pollué par EX-2 · lock racine non pollué.

## Finding le plus grave
**MEDIUM-1** : la pagination n'est pas navigable dans l'UI (`loadMore()` jamais appelé, aucun contrôle de scroll) — seuls 15/48 enregistrements sont atteignables et le chemin curseur n'est jamais exercé end-to-end, tenant AC4(d)/T4 seulement à la couche données.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MEDIUM | ✅ **corrigé** | L'API publique de zcrud_list n'expose pas de hook scroll-end → voie sanctionnée = bouton. Widget `_LoadMoreBar` (écoute la seule tranche `state`, AD-2, ≥48dp) → `ZListController.loadMore()`, câblé sous la liste + l'onglet « Toutes ». **Pagination navigable end-to-end testée** : (a) controller 48 lignes par pages de 15 (15→30→45→48, 48 ids uniques, 0 doublon, curseur avancé) ; (b) UI tap « Charger plus » (>15 lignes atteignables). |
| 2 | LOW-1 | ✅ corrigé | `watchAll()`→`store.changes.map((_)=>_data)` (honore includeDeleted) ; `watch(request)`→`_applyRequest(request)` ; `getAll` refactoré DRY. |
| 3 | LOW-3 | ✅ corrigé | Parité étendue aux **4 bindings** (scope/get/riverpod/provider) → même SfDataGrid. |
| 4 | LOW-2 | 🟡 conservé | `syncfusion_flutter_datagrid` dev-dep test-only déjà justifié ; aucune licence committée. |

**Vérif verte rejouée (orchestrateur, ciblée example/)** : `flutter analyze` **0 issue** · `flutter test` **34/34** (12→16 sur list_demo) · `flutter build web` RC=0 · `packages/` inchangé par EX-2.

**Verdict final** : 1 MEDIUM + 3 LOW traités. Story EX-2 → **done**.
