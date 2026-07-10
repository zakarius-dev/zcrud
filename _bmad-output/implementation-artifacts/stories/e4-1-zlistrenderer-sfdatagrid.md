---
baseline_commit: 868438a73868c75a837e71f8cb443dd75ed24fa8
---

# Story 4.1: `ZListRenderer` (port) + backend `SfDataGrid` par défaut

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP en priorité, puis lex_douane)**,
je veux **un port de rendu de liste (`ZListRenderer`) exposé UNIQUEMENT comme abstraction par `zcrud_core`, avec un backend `SfDataGrid` par défaut vivant DANS `zcrud_list`**,
afin que **le tableau/DataGrid riche soit disponible par défaut SANS que Syncfusion (licence commerciale + poids) ne contamine le cœur — un consommateur qui n'importe pas `zcrud_list` (ex. `zcrud_markdown` seul) ne tire AUCUNE dépendance Syncfusion (AD-8, SM-5), et un backend Material `DataTable` reste implémentable sur le même port**.

**Contexte produit.** Première story d'**E4** (moteur `DynamicList`, dépend d'E2 ; couvre FR-6..FR-8 · AD-8, AD-11, AD-16). E4-1 pose **l'ossature** : (1) le **port neutre** `ZListRenderer` + les **modèles de liste Material-free** dans `zcrud_core` ; (2) l'**injection** du renderer via le seam existant `ZcrudScope` (comme `widgetRegistry`/`filePicker`/`cloudStorage` d'E2-8/E3-3c) ; (3) le **backend concret** `ZSfDataGridRenderer` dans `zcrud_list` (première et seule arête vers `syncfusion_flutter_datagrid`) ; (4) la **preuve d'isolation SM-5** (statique + graphe de dépendances). La **richesse** (colonnes dérivées finement du schéma, vues liste/custom, états UI `loading`/`empty`/`error`, recherche/filtre/tri/pagination, actions+`ZAcl`, sous-listes) est **explicitement DÉFÉRÉE** à E4-2..E4-5 — voir la section **Frontière**. E4-1 rend un DataGrid **basique mais réel** (colonnes 1:1 depuis le `ZFieldSpec[]`, N lignes) suffisant à prouver que le port fonctionne de bout en bout et que Syncfusion est isolé.

## Acceptance Criteria

> Tous les ACs sont **testables** (widget/unit tests `flutter_test`/`package:test` + gardes de pureté/graphe). L'isolation Syncfusion (SM-5) est l'**enjeu headline** de cette story et se prouve par des tests, pas par revue seule.

1. **AC1 — Port neutre dans `zcrud_core`, ZÉRO Syncfusion.** Un port `ZListRenderer` (abstraction) est défini sous `packages/zcrud_core/lib/src/presentation/list/` : `abstract class ZListRenderer { Widget build(BuildContext context, ZListRenderRequest request); }`. Il n'importe **que** des URIs Flutter autorisées sous `presentation/` (`foundation`/`widgets`/`material`) + types `zcrud_core` — **aucun** `package:syncfusion*`, **aucune** dépendance lourde, **aucun** gestionnaire d'état. La garde `presentation_purity_test.dart` (qui bannit déjà TEXTUELLEMENT `package:syncfusion` dans tout `lib/`) reste **verte** sur les nouveaux fichiers.

2. **AC2 — Modèles de liste neutres et immuables.** Le port consomme un `ZListRenderRequest` **neutre, immuable, `const`, pur-Dart-présentation** (Material-free) portant : `final List<ZFieldSpec> columns` (colonnes = projection du schéma ; en E4-1 fournies telles quelles par l'appelant, la dérivation fine est E4-2) et `final List<ZListRow> rows`, où `ZListRow` porte `final String id` (identité opaque) + `final Map<String, Object?> cells` (`field.name → valeur brute`, opaque). Égalité de **valeur** (`==`/`hashCode`) sur `ZListRenderRequest`/`ZListRow` (cohérent avec `ZFieldSpec`/`ZDataRequest`). **Aucune** projection `T → ZListRow` n'est imposée par le port (c'est l'affaire de l'appelant/E4-2). Les états `loading`/`empty`/`error` ne sont **pas** portés ici (E4-2).

3. **AC3 — Injection via `ZcrudScope` (seam), défaut sûr.** `ZcrudScope` gagne un seam `final ZListRenderer? listRenderer;` (défaut `null`), ajouté au constructeur et à `updateShouldNotify` **à l'identique** des seams existants (`widgetRegistry`/`filePicker`/`cloudStorage`). `zcrud_core` **ne fournit AUCUNE** implémentation concrète du renderer (défaut `null`) : le rendu concret est **toujours** injecté par l'app/binding. Aucun singleton statique mutable.

4. **AC4 — `DynamicList` : hôte mince dans le cœur, délègue au port injecté.** Un widget public `DynamicList` sous `presentation/list/` prend `{ required List<ZFieldSpec> fields, required List<ZListRow> rows, ZListRenderer? renderer }`. Il résout `renderer ?? ZcrudScope.of(context).listRenderer` et **délègue** à `renderer.build(context, ZListRenderRequest(columns: fields, rows: rows))`. Si **aucun** renderer n'est disponible → lève une `ZScopeError` au **message actionnable** (« Aucun `ZListRenderer` fourni. Ajoutez `zcrud_list` et injectez `ZSfDataGridRenderer` via `ZcrudScope(listRenderer: ...)`, ou fournissez votre propre backend »). `DynamicList` **n'importe PAS** `zcrud_list` ni Syncfusion : il ne connaît que l'abstraction — c'est le socle prouvant SM-5.

5. **AC5 — Backend `ZSfDataGridRenderer` dans `zcrud_list` (SEULE arête Syncfusion).** `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` définit `class ZSfDataGridRenderer implements ZListRenderer` (const-constructible) utilisant `syncfusion_flutter_datagrid`. `build()` construit un `SfDataGrid` : une `GridColumn` par entrée de `request.columns` (en-tête = `field.label ?? field.name` ; clé de mapping = `field.name`) et un `DataGridSource` mappant chaque `ZListRow.cells[field.name]` en cellule (rendu texte via `?.toString() ?? ''`). Rendu **basique mais réel** : N colonnes, N lignes affichées. `syncfusion_flutter_datagrid: ^32.1.x` (Stack de l'architecture) est ajouté au **seul** `pubspec.yaml` de `zcrud_list` (+ SDK Flutter, `zcrud_list` devenant un package Flutter). **Aucune clé/licence Syncfusion committée dans le package** (l'enregistrement de licence est une config plateforme de l'app — Key Don'ts « never de secret dans un package »).

6. **AC6 — a11y/RTL de base sur le backend.** Le `SfDataGrid` rendu expose une **sémantique de base** (les cellules restent lisibles par lecteur d'écran ; en-têtes annoncés) ; hauteur de ligne **≥ 48 dp** (cibles tactiles, AD-13) ; tout padding/alignement éventuel utilise les variantes **directionnelles** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`) — jamais `left`/`right` (AD-13). *(L'a11y riche — tri annoncé, focus clavier avancé, états — relève d'E4-2/E4-3.)*

7. **AC7 — SM-5 prouvé : isolation Syncfusion (headline, testable).** L'isolation est prouvée par **trois** contrôles automatisés, pas par revue :
   - **(a) Statique cœur** : 0 occurrence TEXTUELLE (hors commentaires) de `package:syncfusion`/`SfDataGrid` dans `zcrud_core/lib/` — assuré par la garde existante `presentation_purity_test.dart` (reste verte) ; et `zcrud_core/pubspec.yaml` **ne déclare aucune** dépendance `syncfusion*` (test type `no_heavy_file_dep_test.dart`, étendu ou nouveau).
   - **(b) Graphe de dépendances** : un test de **résolution/graphe** prouve que la **fermeture transitive** de `zcrud_core` — ET d'un satellite qui ne dépend PAS de `zcrud_list` (ex. `zcrud_markdown`, ancrage PRD SM-5) — **ne contient AUCUN** package `syncfusion*` ; **contrôle positif** : la fermeture de `zcrud_list` **contient** bien `syncfusion_flutter_datagrid` (sinon le test est un faux vert). Implémentable en pur-Dart offline (parcours des `pubspec.yaml` du workspace) ou via `dart pub deps --json`.
   - **(c) Acyclicité (AD-1)** : `zcrud_list → zcrud_core` est la seule arête ; `zcrud_core` n'a **aucune** arête sortante vers `zcrud_list` (assuré par (a) + absence d'import ; le graphe reste acyclique).

8. **AC8 — Le cœur reste testable et rendable SANS Syncfusion.** Un widget test dans `zcrud_core` pompe `DynamicList` avec un **faux `ZListRenderer`** (implémenté dans le test, zéro Syncfusion) injecté via `ZcrudScope(listRenderer: fake, child: ...)` et prouve : (i) `DynamicList` **délègue** (le faux reçoit le `ZListRenderRequest` attendu : `columns == fields`, `rows` transmis) ; (ii) sans renderer injecté ni paramètre → `ZScopeError` actionnable levée. Ce test **n'importe jamais** `zcrud_list` — démonstration exécutable que le cœur se rend derrière l'abstraction seule.

9. **AC9 — Pureté par couche, barrels, vérif verte.** Les nouveaux types publics du cœur (`ZListRenderer`, `ZListRenderRequest`, `ZListRow`, `DynamicList`) sont exportés par `packages/zcrud_core/lib/zcrud_core.dart`. `ZSfDataGridRenderer` est exporté par `packages/zcrud_list/lib/zcrud_list.dart` (le placeholder `ZListApi` peut être conservé ou retiré, mais l'arête AD-1 `zcrud_list → zcrud_core` reste tangible). Gardes de pureté (`presentation_purity_test`, `style_purity_test`, `no_heavy_file_dep_test`) **vertes**. `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 sur `zcrud_core` **et** `zcrud_list`.

## Tasks / Subtasks

- [x] **Tâche 1 — Port + modèles neutres dans `zcrud_core` (AC1, AC2)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart` : `ZListRow` (`const`, `{required String id, required Map<String,Object?> cells}`, `==`/`hashCode` de valeur avec égalité profonde de la map) + `ZListRenderRequest` (`const`, `{required List<ZFieldSpec> columns, required List<ZListRow> rows}`, `==`/`hashCode` de valeur avec égalité profonde des listes — s'inspirer du helper d'égalité de `z_data_request.dart`).
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart` : `abstract class ZListRenderer { const ZListRenderer(); Widget build(BuildContext context, ZListRenderRequest request); }`. Imports limités à `package:flutter/widgets.dart` + types core.
  - [x] Docstrings « origine / AD-8 / SM-5 / neutre Material-free » dans le style des fichiers voisins (cf. `z_data_state.dart`, `z_acl.dart`).
- [x] **Tâche 2 — Injection via `ZcrudScope` (AC3)**
  - [x] Éditer `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` : ajouter `final ZListRenderer? listRenderer;` (docstring seam, défaut `null` → repli explicite documenté), au constructeur (`this.listRenderer`), et à `updateShouldNotify` (`!identical(listRenderer, oldWidget.listRenderer)`). Ajouter l'import relatif `list/z_list_renderer.dart`.
- [x] **Tâche 3 — `DynamicList` hôte mince dans le cœur (AC4, AC8)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart` : `StatelessWidget` `{required List<ZFieldSpec> fields, required List<ZListRow> rows, ZListRenderer? renderer, Key? key}`. `build` : `final r = renderer ?? ZcrudScope.of(context).listRenderer;` → si `null`, `throw ZScopeError('... ajoutez zcrud_list + ZSfDataGridRenderer via ZcrudScope(listRenderer:) ...')` ; sinon `return r.build(context, ZListRenderRequest(columns: fields, rows: rows));`. **Aucun** import `zcrud_list`/Syncfusion.
  - [x] Exporter les 4 types dans `packages/zcrud_core/lib/zcrud_core.dart` (ordre alphabétique des `export`, `directives_ordering`).
- [x] **Tâche 4 — Backend `ZSfDataGridRenderer` dans `zcrud_list` (AC5, AC6)**
  - [x] Ajouter à `packages/zcrud_list/pubspec.yaml` : `flutter: sdk: flutter` (dependencies) + `syncfusion_flutter_datagrid: ^32.1.19` (Stack `^32.1.x` → résout 32.2.9) ; conserver `zcrud_core: ^0.0.1`. `flutter_test: sdk: flutter` en `dev_dependencies` + `flutter: uses-material-design: true` (icônes Syncfusion).
  - [x] Créer `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` : `class ZSfDataGridRenderer implements ZListRenderer { const ZSfDataGridRenderer(); @override Widget build(...) { ... } }`. Construire `List<GridColumn>` depuis `request.columns` (header via `Text(field.label ?? field.name)`) + un `DataGridSource` (sous-classe privée) produisant les `DataGridRow`/`DataGridCell` depuis `request.rows` ; `rowHeight >= 48`. Alignements/paddings **directionnels**.
  - [x] Mettre à jour `packages/zcrud_list/lib/zcrud_list.dart` : exporter `src/presentation/z_sf_data_grid_renderer.dart` ; arête AD-1 vers `zcrud_core` matérialisée par l'import du renderer → `ZListApi`/`z_list_api.dart` **retirés proprement**.
  - [x] **Ne PAS** committer de clé/licence Syncfusion ; documenté (docstring) que l'enregistrement de licence relève de la plateforme de l'app.
- [x] **Tâche 5 — Preuve SM-5 + tests (AC7, AC8, AC9)**
  - [x] `zcrud_core` : test widget `dynamic_list_delegation_test.dart` (faux `ZListRenderer` local, capture du `ZListRenderRequest` ; cas délégation param + seam + priorité + cas `ZScopeError` sans renderer). Aucun import `zcrud_list`. + `z_list_render_request_test.dart` (==/hashCode AC2) + seam `listRenderer` dans `zcrud_scope_test.dart`.
  - [x] `zcrud_core` : garde pubspec étendue — `no_heavy_file_dep_test.dart` bannit désormais `syncfusion` (pubspec + imports lib).
  - [x] Test de **graphe SM-5** dans `zcrud_list/test/sm5_syncfusion_isolation_graph_test.dart` : (a) fermeture transitive de `zcrud_core` et de `zcrud_markdown` sans `syncfusion*` ; (b) **contrôle positif** : fermeture de `zcrud_list` **avec** `syncfusion_flutter_datagrid` ; (c) acyclicité `zcrud_list → zcrud_core`, cœur out-degree 0. Pur-Dart offline (lecture line-based des `pubspec.yaml`, aligné sur `graph_proof.py`).
  - [x] `zcrud_list` : `z_sf_data_grid_renderer_test.dart` — pompe `ZSfDataGridRenderer().build(context, request)` avec 2 colonnes + 3 lignes ; asserte `SfDataGrid` présent, en-têtes = labels (`label ?? name`), N lignes, `rowHeight`/`headerRowHeight` ≥ 48, colonnes 1:1.
  - [x] Rejouer la **vérif verte** : `melos run generate` SUCCESS → `analyze` RC=0 (14 pkgs, 0 issue) → `flutter test` RC=0 (`zcrud_core` 444 + `zcrud_list` 7 ; workspace total 572), `melos run verify` RC=0, gardes de pureté vertes.

## Dev Notes

### Conception retenue (port neutre + backend isolé + injection)

- **Séparation port/impl (AD-8).** `zcrud_core` n'expose que l'**abstraction** `ZListRenderer` + les **modèles Material-free** (`ZListRenderRequest`/`ZListRow`) + l'**hôte mince** `DynamicList`. Le **rendu Syncfusion** (`ZSfDataGridRenderer` + `SfDataGrid`) vit **exclusivement** dans `zcrud_list`. Un **backend Material `DataTable`** (ou tout autre) reste implémentable sur le même port sans toucher le cœur — c'est le sens de l'abstraction.
- **Injection par seam `ZcrudScope`.** On réutilise **exactement** le patron des seams déjà en place (`widgetRegistry`, `filePicker`, `cloudStorage` : champ nullable + défaut `null` + repli explicite + `updateShouldNotify`). L'app fait simplement `ZcrudScope(listRenderer: const ZSfDataGridRenderer(), child: ...)`. Aucun code manager-spécifique ; aucun singleton statique mutable.
- **Port non-générique, cellules opaques.** Le port ne porte **pas** de `T` : `ZListRow.cells` est une `Map<String,Object?>` (`field.name → valeur brute`). La projection `T → ZListRow` (via `toMap`/`ZFieldSpec`) est l'affaire de l'appelant et sera **outillée par E4-2** (colonnes dérivées + formatage cellule). Cela évite la fuite de génér1cité au point d'injection et colle au `DataGridSource` de Syncfusion (lignes de cellules).
- **`DynamicList` dans le cœur (et pas dans `zcrud_list`).** L'hôte mince vit dans `zcrud_core` **parce qu'il ne connaît que l'abstraction** : il délègue au `ZListRenderer` injecté et n'importe jamais Syncfusion. C'est précisément ce qui rend SM-5 **exécutable** (le cœur possède `DynamicList` mais **zéro** Syncfusion). Si aucun renderer n'est fourni, il lève une `ZScopeError` actionnable (même philosophie que `ZDependencyResolver.throwing` / `ZcrudScope.of`).

### Preuve SM-5 (isolation des dépendances Syncfusion) — comment elle tient

SM-5 (PRD §, ancrage `prd.md:384`) : « importer `zcrud_markdown` seul n'ajoute ni Firebase, ni Syncfusion, ni Google Maps au graphe ». E4-1 en couvre la **facette Syncfusion**, prouvée sur **trois** plans :
1. **Statique cœur** — la garde **existante** `packages/zcrud_core/test/purity/presentation_purity_test.dart` bannit **déjà** `package:syncfusion` (et Firebase/Hive/Quill/Maps) TEXTUELLEMENT sur **tout** `zcrud_core/lib/` ; elle doit rester **verte** avec les nouveaux fichiers. + `zcrud_core/pubspec.yaml` sans dépendance `syncfusion*`.
2. **Graphe** — nouveau test : fermeture transitive de `zcrud_core` **et** `zcrud_markdown` **sans** `syncfusion*`, avec **contrôle positif** sur `zcrud_list` (qui doit, lui, contenir `syncfusion_flutter_datagrid`) pour éviter le faux vert.
3. **Acyclicité (AD-1)** — `zcrud_list → zcrud_core` uniquement ; aucune arête retour. Cohérent avec le puits de graphe qu'est `zcrud_core`.

### Frontière avec E4-2..E4-5 (NE PAS déborder)

- **E4-1 (cette story)** : port `ZListRenderer` + modèles neutres + injection `ZcrudScope` + `DynamicList` mince + backend `SfDataGrid` **basique** (colonnes 1:1, N lignes) + **preuve SM-5**. Rendu **volontairement minimal**.
- **E4-2** : **colonnes dérivées finement du `ZFieldSpec[]`** (visibilité, formatage/cellule par type, largeur…), **vues** (liste / DataGrid / `customView`/`itemBuilder`), et **états UI accessibles** `loading`/`empty`/`no-results-après-filtre`/`error`. ⇒ ces états **ne** sont **pas** dans `ZListRenderRequest` en E4-1.
- **E4-3** : recherche sans accents (champs `searchable`), **filtres/tri via `ZDataRequest`**, **pagination curseur** (AD-16), repli in-memory documenté.
- **E4-4** : **actions ligne + `ZAcl`** (port `ZAcl` déjà présent, `ZCrudAction`), sélection multiple, corbeille (soft-delete/restore).
- **E4-5** : **sous-listes/relations & onglets** (`ZSubListScreen`).

> En cas de tentation d'ajouter tri/filtre/états/actions/dérivation fine ici : **STOP**, c'est E4-2+. E4-1 prouve le **port** et l'**isolation**, pas la richesse.

### Source tree à toucher

- **NEW** `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart`
- **NEW** `packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart`
- **NEW** `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart`
- **UPDATE** `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (seam `listRenderer`)
- **UPDATE** `packages/zcrud_core/lib/zcrud_core.dart` (exports)
- **NEW** `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart`
- **UPDATE** `packages/zcrud_list/pubspec.yaml` (flutter + `syncfusion_flutter_datagrid: ^32.1.x`)
- **UPDATE** `packages/zcrud_list/lib/zcrud_list.dart` (export renderer)
- **NEW tests** : `zcrud_core/test/presentation/list/dynamic_list_delegation_test.dart` ; `zcrud_list/test/z_sf_data_grid_renderer_test.dart` ; test de graphe SM-5 ; garde pubspec (nouveau ou extension `no_heavy_file_dep_test.dart`).

### État actuel des fichiers UPDATE (à préserver)

- `zcrud_scope.dart` : `InheritedWidget` const, seams `resolver`/`acl`/`labels`/`theme`/`widgetRegistry`/`filePicker`/`cloudStorage`, `of`/`maybeOf`, `updateShouldNotify` par `identical`. **Préserver** tous les seams existants ; **ajouter** `listRenderer` **sans** changer la signature des autres (paramètre nommé optionnel, défaut `null`).
- `zcrud_list.dart` : barrel exportant le placeholder `z_list_api.dart` (`ZListApi` référence `ZCoreApi.version` pour matérialiser l'arête AD-1). En le retirant, **conserver** une arête tangible `zcrud_list → zcrud_core` (le nouveau renderer importe `package:zcrud_core/zcrud_core.dart`, ce qui suffit).
- `zcrud_list/pubspec.yaml` : squelette `resolution: workspace`, dep `zcrud_core: ^0.0.1`. Passe à package **Flutter** (ajout `flutter` sdk).

### Standards de test

- `flutter_test` (widget) pour `DynamicList` (délégation + erreur) et pour `ZSfDataGridRenderer` (rendu SfDataGrid). `package:test` (pur-fichiers/graphe) pour les gardes SM-5, dans le style de `presentation_purity_test.dart` / `no_heavy_file_dep_test.dart`.
- Le test de délégation du cœur **n'importe jamais** `zcrud_list` (sinon il casse la preuve SM-5) : il définit un **faux** `ZListRenderer` inline.
- Contrôle positif obligatoire sur le test de graphe (prouver que `zcrud_list` **tire** bien Syncfusion) pour écarter le faux vert.

### Project Structure Notes

- Nouveau sous-dossier `presentation/list/` dans `zcrud_core` (cohérent avec `presentation/edition/`, `presentation/theme/`, `presentation/l10n/`). API publique = barrel `lib/zcrud_core.dart` ; impl sous `lib/src/` (invariant de structure).
- Aucun conflit détecté avec la structure existante. `zcrud_list` reste **satellite** dépendant de `zcrud_core` (AD-1, puits de graphe préservé).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E4 — Moteur DynamicList] (Story E4-1 : « `zcrud_core` n'expose que l'abstraction ; rendu Syncfusion dans `zcrud_list` ; sans `zcrud_list` → pas de Syncfusion (AD-8, SM-5) » ; frontière E4-2..E4-5)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-8] (Rule : `zcrud_core` n'expose que l'abstraction `ZListRenderer` + modèles Material-free ; `SfDataGrid` par défaut dans `zcrud_list` ; consommateur sans `zcrud_list` ne tire pas Syncfusion ; backend Material `DataTable` implémentable sur le même port)
- [Source: architecture.md#AD-1] (graphe acyclique ; `zcrud_core` puits sans dépendance Syncfusion ; toute arête satellite→core, jamais l'inverse)
- [Source: architecture.md#Stack] (`syncfusion_flutter_datagrid / _pdf / _xlsio` → `^32.1.x`, portée `zcrud_list`/`zcrud_export`)
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#SM-5] (Isolation des dépendances : `zcrud_markdown` seul n'ajoute ni Firebase, ni Syncfusion, ni Google Maps — test de résolution ; valide FR-24)
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] (patron de seam nullable + défaut + `updateShouldNotify` à réutiliser pour `listRenderer`)
- [Source: packages/zcrud_core/test/purity/presentation_purity_test.dart] (garde existante : `package:syncfusion` déjà banni textuellement dans tout `zcrud_core/lib/` — pilier statique de SM-5)
- [Source: packages/zcrud_core/test/purity/no_heavy_file_dep_test.dart] (patron de garde pubspec/lib à répliquer pour `syncfusion`)
- [Source: packages/zcrud_core/lib/src/domain/data/z_data_request.dart] (helper d'égalité de valeur profonde à imiter pour `ZListRenderRequest`/`ZListRow`)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart] (`ZFieldSpec` = source des colonnes ; `label`/`name`/`searchable`)
- [Source: CLAUDE.md#Critical Patterns AD-8] (Liste : Syncfusion `SfDataGrid` par défaut dans `zcrud_list` derrière `ZListRenderer` ; le cœur n'expose que l'abstraction)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `dart pub get` → RC=0 ; `syncfusion_flutter_datagrid 32.2.9` + `syncfusion_flutter_core 32.2.9` résolus (Stack `^32.1.x` via `^32.1.19`, Flutter 3.44.4).
- `melos run analyze` → RC=0, **14 packages**, `No issues found!` partout (après correction `directives_ordering` sur `zcrud_scope.dart` et bascule de l'import du test de graphe vers `flutter_test`).
- `melos run test` → RC=0 : `zcrud_core` 444, `zcrud_list` 7, `zcrud_generator` 80, `zcrud_get` 17, `zcrud_annotations` 8, `zcrud_provider` 8, `zcrud_riverpod` 8 → **total 572** (`SUCCESS`).
- `melos run verify` → RC=0 (graph_proof `ACYCLIQUE OK` / `CORE OUT=0 OK` ; melos-divergence, reflectable, secrets, codegen, compat, serialization : verts).
- `melos run generate` → `SUCCESS` (build_runner ; `zcrud_list` sans annotation = no-op) ; **0 `.g.dart` suivi par git**.

#### Remédiation code-review E4-1 (M1 + L1 + L3 + L4) — 2026-07-10

- **M1 (MEDIUM, résolu — durcissement SM-5).** La preuve de graphe `sm5_syncfusion_isolation_graph_test.dart` est **refondée sur la résolution RÉELLE** via `dart pub deps --json` (mode PRIMAIRE), dont le graphe inclut les **transitives EXTERNES** — l'angle mort exact signalé. Une contamination `syncfusion*` tirée transitivement par un tiers depuis `zcrud_core` fait désormais échouer (a)/(b). **Contrôle positif renforcé (c)** : la fermeture de `zcrud_list` doit contenir AUSSI `syncfusion_flutter_core`, qui n'est **PAS** une dépendance directe de `zcrud_list` mais est tiré transitivement par `syncfusion_flutter_datagrid` (arête externe→externe) — **preuve auto-validante** que le parcours suit les transitives externes. **Fallback documenté** (mode LOCAL, pubspecs uniquement) si `dart pub deps --json` est indisponible : couvre les vecteurs directs/locaux, n'affirme PAS la garantie externe-transitive (commentaire d'en-tête réécrit, **sur-vente supprimée**).
  - **Preuve live du vecteur externe-transitif (rejouée sous `flutter test`)** : `dart pub deps --json` → exit 0 ; `closure(zcrud_list)` contient `syncfusion_flutter_core` avec `directDependencies` de `zcrud_list` = `[flutter, syncfusion_flutter_datagrid, zcrud_core]` (donc `syncfusion_flutter_core` **atteint uniquement transitivement-externellement**). CQFD : la fermeture traverse bien les arêtes externes, une contamination transitive-externe de `zcrud_core` SERAIT captée par (a)/(b).
- **L1 (nit, résolu).** `DynamicList.build` résout le seam via `ZcrudScope.maybeOf(context)?.listRenderer` (au lieu de `of`) → le message d'erreur reste **list-spécifique et actionnable même SANS ancêtre `ZcrudScope`** (avant : `ZScopeError` générique « aucun scope »). Test de bord ajouté.
- **L3 (couverture, résolu).** Tests de bord ajoutés — `DynamicList` (cœur) avec `fields == []`, `rows == []`, **noms de colonnes dupliqués** (délégation sans crash, colonnes transmises telles quelles) ; `ZSfDataGridRenderer` (zcrud_list) avec **0 ligne**, **0 colonne**, **colonnes dupliquées** (rendu `SfDataGrid` sans crash, `takeException() == null`).
- **L2 (nit, DÉFÉRÉ).** `_ZListDataGridSource` recréé à chaque `build()` (perte d'état grille sur rebuild) → **pertinent E4-2/E4-3** (passage à un `StatefulWidget` avec état de grille) ; hors périmètre du rendu basique E4-1, consigné.
- **L4 (nit, CONSIGNÉ).** Double `toString` de cellule conservé **volontairement** : la valeur est stockée `String` dans `DataGridCell<String>`, et le `?.toString() ?? ''` de `buildRow` reste une lecture **défensive** (le contrat `getCells()` expose `Object?`) — redondance inoffensive, pas de risque, non modifiée pour ne pas fragiliser le cast.
- **Vérif verte rejouée réellement** : `melos run analyze` RC=0 (`No issues found!`, 14 pkgs) ; `melos run test` RC=0 — `zcrud_core` **448** (+4), `zcrud_list` **11** (+4), **total workspace 580** ; `melos run verify` RC=0 (graph_proof `CORE OUT=0 OK`/`ACYCLIQUE OK` 17 arêtes, melos-divergence, reflectable, secrets, codegen, compat verts). `melos list` = 14, 0 `.g.dart` suivi, `zcrud_core` toujours 0 import/dép syncfusion. Status reste `review`.

### Completion Notes List

- **Port neutre + isolation SM-5 (headline).** `zcrud_core` n'expose que l'abstraction `ZListRenderer` + les modèles Material-free `ZListRenderRequest`/`ZListRow` (cellules opaques `Map<String,Object?>`, égalité de valeur profonde) + l'hôte mince `DynamicList`. Le rendu Syncfusion (`ZSfDataGridRenderer` + `SfDataGrid`) vit **exclusivement** dans `zcrud_list`.
- **PREUVE SM-5 sur 3 plans, rejouée réellement :**
  1. **Statique (cœur)** — `presentation_purity_test` (bannit `package:syncfusion` textuellement) reste vert ; `no_heavy_file_dep_test` étendu bannit `syncfusion` dans le pubspec **et** les imports lib du cœur (vert). `grep` : 0 import syncfusion dans `zcrud_core/lib` ; seules 2 occurrences textuelles du token `ZSfDataGridRenderer` — dans la **string du message d'erreur actionnable** de `DynamicList`, pas un import. `zcrud_core/pubspec.yaml` sans dépendance syncfusion.
  2. **Graphe** — `sm5_syncfusion_isolation_graph_test.dart` : fermeture transitive de `zcrud_core` ET `zcrud_markdown` **sans** `syncfusion*` ; **contrôle POSITIF** : fermeture de `zcrud_list` **contient** `syncfusion_flutter_datagrid` (écarte le faux vert). Vert.
  3. **Acyclicité (AD-1)** — `graph_proof.py` : `CORE OUT=0 OK`, `ACYCLIQUE OK` (17 arêtes) ; le test de graphe asserte `zcrud_list → zcrud_core` sans arête retour, cœur out-degree zcrud_* = 0.
- **`DynamicList` délègue** au renderer résolu (`renderer` param prioritaire, sinon `ZcrudScope.of(context).listRenderer`) et lève une `ZScopeError` **actionnable** (mentionne `zcrud_list` + `ZSfDataGridRenderer` + `ZcrudScope`) si aucun renderer — prouvé par widget test (faux renderer inline, zéro import `zcrud_list`).
- **Backend basique mais réel** : `GridColumn` 1:1 depuis `ZFieldSpec[]` (header `label ?? name`), `DataGridSource` privé mappant `cells[field.name]?.toString() ?? ''`, `rowHeight`/`headerRowHeight` = 48 (AD-13), paddings/alignements **directionnels** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`).
- **Aucune clé/licence Syncfusion committée** (scan `registerLicense`/`licenseKey` = 0 hors docstring d'usage). `flutter: uses-material-design: true` ajouté à `zcrud_list` (icônes Syncfusion).
- **`melos list` = 14** (invariant produit préservé) ; placeholder `z_list_api.dart` retiré proprement (arête AD-1 portée par l'import du renderer).
- **Non-régression** : E1/E2/E3 verts (444 tests `zcrud_core`, gates `verify` verts) ; aucun seam existant modifié (ajout `listRenderer` en paramètre nommé optionnel défaut `null`).
- **Ambiguïté tranchée** : Stack pinné `^32.1.x` ; `^32.1.19` retenu (plus petite 32.1.x existante) → résolution 32.2.9 compatible Flutter 3.44.4 et `dart pub get` RC=0.

### File List

**Créés (zcrud_core) :**
- `packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart`
- `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart`
- `packages/zcrud_core/test/presentation/list/z_list_render_request_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_delegation_test.dart`

**Modifiés (zcrud_core) :**
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (seam `listRenderer`)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports des 3 types + `DynamicList`)
- `packages/zcrud_core/test/purity/no_heavy_file_dep_test.dart` (bannit `syncfusion`)
- `packages/zcrud_core/test/presentation/zcrud_scope_test.dart` (couverture seam `listRenderer`)

**Créés (zcrud_list) :**
- `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart`
- `packages/zcrud_list/test/z_sf_data_grid_renderer_test.dart`
- `packages/zcrud_list/test/sm5_syncfusion_isolation_graph_test.dart`

**Modifiés (zcrud_list) :**
- `packages/zcrud_list/pubspec.yaml` (Flutter SDK + `syncfusion_flutter_datagrid: ^32.1.19` + `flutter_test` + `uses-material-design`)
- `packages/zcrud_list/lib/zcrud_list.dart` (export du renderer)

**Supprimés (zcrud_list) :**
- `packages/zcrud_list/lib/src/presentation/z_list_api.dart` (placeholder retiré ; arête AD-1 portée par l'import du renderer)

**Racine :**
- `pubspec.lock` (lockfile workspace mis à jour par la résolution)

### Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-07-10 | 0.1 | E4-1 implémentée : port `ZListRenderer` + modèles neutres + seam `ZcrudScope.listRenderer` + `DynamicList` mince (cœur, zéro Syncfusion) + backend `ZSfDataGridRenderer` (zcrud_list) + preuve SM-5 3 plans. analyze/test/verify verts (572 tests). Status → review. |
| 2026-07-10 | 0.2 | Remédiation code-review : M1 (preuve SM-5 refondée sur `dart pub deps --json` → fermeture transitive COMPLÈTE incl. externe ; contrôle positif externe-transitif `syncfusion_flutter_core` ; fallback local documenté, sur-vente supprimée) + L1 (`maybeOf` → message list-spécifique hors scope) + L3 (tests de bord columns/rows vides + colonnes dupliquées, renderer 0 ligne). L2 déféré E4-2, L4 consigné. analyze/test/verify RC=0 (580 tests, core 448 / list 11). Status reste `review`. |
