---
baseline_commit: 868438a73868c75a837e71f8cb443dd75ed24fa8
---

# Story 4.2 : Colonnes dérivées du schéma + vues (liste / DataGrid / custom) + états UI accessibles

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP puis lex_douane)**,
je veux **que la liste dérive FINEMENT ses colonnes du `ZFieldSpec[]` (visibilité en liste, format d'affichage par type, libellé, ordre/largeur), qu'elle offre des VARIANTES DE VUE sélectionnables (liste `itemBuilder` / DataGrid Syncfusion / `customView`), et qu'elle rende quatre ÉTATS UI ACCESSIBLES et DISTINCTS (`loading`, `empty`, `no-results-après-filtre`, `error`)**,
afin que **le tableau/liste ne soit plus un mapping brut 1:1 mais une projection utile et lisible du schéma, que l'intégrateur choisisse le rendu adapté à son écran, et que chaque état de chargement soit annoncé aux lecteurs d'écran — le tout SANS que la dérivation de colonnes ni les états ne contaminent le cœur avec Syncfusion (AD-8, SM-5) : les vues `itemBuilder`/`customView` et les 4 états se rendent ENTIÈREMENT dans `zcrud_core`, Material-free, zéro Syncfusion**.

**Contexte produit.** Deuxième story d'**E4** (moteur `DynamicList`, dépend d'E2 ; couvre FR-6..FR-8 · AD-8, AD-11, AD-13, AD-16). **E4-1 (done/review)** a posé l'ossature : port neutre `ZListRenderer`, contrat `ZListRenderRequest{columns: List<ZFieldSpec>, rows: List<ZListRow>}`, hôte mince `DynamicList` (cœur, délègue), backend `ZSfDataGridRenderer` (zcrud_list, mapping **basique 1:1** : `GridColumn` par champ, cellule `cells[name]?.toString() ?? ''`), et la **preuve SM-5** (isolation Syncfusion sur 3 plans). E4-1 a **explicitement déféré à E4-2** : la dérivation fine des colonnes, les vues alternatives et les états UI.

E4-2 apporte donc trois briques, toutes ancrées dans le cœur neutre :
1. **Dérivation FINE des colonnes** — un helper **PUR** `schéma → colonnes` (`deriveColumns`) qui, à partir du `ZFieldSpec[]`, décide **quels champs sont affichés en liste** (visibilité), **comment formater chaque cellule par `EditionFieldType`**, le **libellé**, l'**ordre** et une **largeur** indicative. Pur-Dart-présentation, aucun `BuildContext`, déterministe.
2. **Variantes de VUE** — `DynamicList` gagne un sélecteur `ZListLayout` : `dataGrid` (délègue au renderer injecté = chemin E4-1 Syncfusion), `builder(itemBuilder)` (rendu `ListView.builder` **dans le cœur**, Material-free) et `custom(customView)` (widget arbitraire). Les vues `builder`/`custom` prouvent qu'un consommateur rend une liste **sans `zcrud_list`** (renforce SM-5).
3. **États UI ACCESSIBLES** — `DynamicList` rend quatre états **distincts** via un type d'état neutre `ZListViewState` : `loading` (spinner + `Semantics` `liveRegion`), `empty` (aucune donnée), `no-results-après-filtre` (**distinct** d'`empty`), `error` (message dérivé de `ZFailure`, `Semantics(liveRegion: true)`, AD-11). Ces états vivent dans le **wrapper `DynamicList`** (cœur), **PAS** dans `ZListRenderRequest` (décision tranchée ci-dessous).

**Frontière (NE PAS déborder).** E4-2 **rend** l'état `no-results-après-filtre` de façon distincte, mais **ne calcule PAS** le filtre : la recherche sans accents, les filtres/tri via `ZDataRequest` et la pagination curseur sont **E4-3**. Les actions ligne + `ZAcl`, la sélection multiple et la corbeille sont **E4-4**. Les sous-listes/onglets sont **E4-5**. Voir la section **Frontière** détaillée.

## Acceptance Criteria

> Tous les ACs sont **testables** (unit tests `package:test` pour la dérivation pure ; widget tests `flutter_test` pour les vues et états ; gardes de pureté/graphe pour SM-5). L'isolation Syncfusion (SM-5) et la **distinction des 4 états** sont les deux enjeux headline de cette story.

1. **AC1 — Helper de dérivation PUR `schéma → colonnes`, neutre dans le cœur.** Un helper **pur-Dart** (fonction top-level `List<ZListColumn> deriveColumns(List<ZFieldSpec> schema, {ZColumnPolicy? policy})`, dans `packages/zcrud_core/lib/src/presentation/list/`) projette le `ZFieldSpec[]` en une **liste ordonnée** de `ZListColumn`. La dérivation est **PURE** : **aucun** `BuildContext`, **aucun** widget, **aucune** dépendance Flutter d'exécution au-delà de `foundation` (l'immutabilité `@immutable`), **aucun** I/O, **déterministe** (même entrée → même sortie). `ZListColumn` est un value object **neutre, immuable, `const`-compatible, Material-free** portant au minimum : `final String name` (clé de mapping = `field.name`), `final String header` (libellé/clé **non résolu** = `field.label ?? field.name` ; la résolution l10n est faite au **rendu** via `label(context, header)`), `final EditionFieldType type`, `final int order`, `final double? width` (indicative, `null` = laissé au backend), et une **fonction de format pure** `final String Function(Object? raw) format`. Égalité de **valeur** (`==`/`hashCode`) sur les champs de données (la closure `format` étant dérivée du `type`, l'égalité porte sur `name/header/type/order/width`, cohérent avec `ZFieldSpec`). La garde `presentation_purity_test.dart` reste **verte** (0 `package:syncfusion`, 0 dépendance lourde).

2. **AC2 — Format d'affichage par `EditionFieldType` (pur, documenté, testé).** `format(raw)` applique un mapping **pur et locale-neutre** par type, testé cas par cas :
   - `null` → `''` (chaîne vide ; le placeholder visuel « — » éventuel est au rendu, pas dans la donnée) ;
   - `select`/`radio`/`checkbox` → **libellé de choix résolu** depuis `field.choices` (correspondance `raw == choice.value` → `choice.label`), repli `raw.toString()` si non trouvé ;
   - champ **multiple**/`tags`/`rowChips` ou valeur `Iterable` → éléments joints par `', '` (chaque élément formaté récursivement de façon neutre) ;
   - `dateTime`/`time` → chaîne **ISO-8601** si `raw is DateTime` (`toIso8601String()`), sinon `raw.toString()` ;
   - `number`/`integer`/`float` → `raw.toString()` (le **formatage locale-aware** des nombres est **déféré E4-3**/hook injecté) ;
   - `boolean` → `raw.toString()` neutre (mapping ✓/✗ ou oui/non **locale-aware au rendu**, déféré) ;
   - défaut → `raw?.toString() ?? ''`.
   Aucune de ces branches ne lève : une valeur inattendue retombe sur `toString()` (désérialisation défensive, AD-10).

3. **AC3 — Visibilité en liste dérivée par POLITIQUE de type (E2-4 non modifié).** `deriveColumns` **exclut** de la liste : (a) tout champ `isId == true` (identité opaque, non affichée) ; (b) les types **non-tabulaires/lourds** par défaut : `subItems`, `dynamicItem`, `file`, `image`, `document`, `location`, `geoArea`, `address`, `signature` (+ tout type dont le rendu cellulaire n'a pas de sens tabulaire — liste documentée dans le code). Il **inclut** les types scalaires/affichables : `text`, `multiline`, `number`, `integer`, `float`, `boolean`, `dateTime`, `time`, `select`, `radio`, `checkbox`, `tags`, `rowChips`, `country`, `phoneNumber`, `rating`, `slider`, `color`. L'**ordre** des colonnes suit l'ordre du schéma (stable). Un paramètre `ZColumnPolicy?` optionnel permet à l'appelant de **forcer include/exclude** un champ par `name` (point d'extension additif, AD-4) **sans** toucher `ZFieldSpec`/les annotations E2-4 (celles-ci restent gelées : ni `showInList` ni `listWidth` n'y sont ajoutés dans cette story — voir Ambiguïtés). Testable : un schéma mixant tous les types → colonnes dérivées == ensemble inclus attendu, dans l'ordre, `isId` et types lourds absents.

4. **AC4 — Contrat `ZListRenderRequest` ENRICHI par les colonnes dérivées (décision tranchée).** `ZListRenderRequest` porte désormais `final List<ZListColumn> columns` (colonnes **dérivées**, plus `List<ZFieldSpec>`) + `final List<ZListRow> rows`, et gagne une fabrique `ZListRenderRequest.fromSchema(List<ZFieldSpec> fields, List<ZListRow> rows, {ZColumnPolicy? policy})` qui applique `deriveColumns`. Égalité de **valeur profonde** préservée. **Décision tranchée (colonnes)** : la dérivation **enrichit le contrat** — le backend (Syncfusion ou autre) consomme des `ZListColumn` (en-tête, largeur, `format`) au lieu de re-dériver, garantissant un formatage **neutre et partagé** (le code de format vit dans le cœur, jamais dupliqué dans `zcrud_list`). Les **états UI** ne sont **PAS** ajoutés au `ZListRenderRequest` (voir AC7). Testable : `fromSchema` produit les colonnes attendues ; `==`/`hashCode` cohérents ; les fichiers E4-1 (renderer + tests) sont mis à jour pour consommer `ZListColumn` sans casser la vérif verte.

5. **AC5 — Variantes de VUE sélectionnables sur `DynamicList`.** `DynamicList` gagne un paramètre `ZListLayout layout` (sealed, défaut `const ZListDataGridLayout()`), avec **trois** variantes :
   - **`ZListDataGridLayout`** (défaut) → **délègue** au `ZListRenderer` injecté (chemin E4-1) en lui passant le `ZListRenderRequest` **à colonnes dérivées** ;
   - **`ZListBuilderLayout`** portant `Widget Function(BuildContext, ZListRow row, List<ZListColumn> columns) itemBuilder` → rend un **`ListView.builder`** (jamais `ListView(children:)`, Key Don'ts) **dans le cœur**, une entrée par ligne construite par `itemBuilder` ;
   - **`ZListCustomLayout`** portant `Widget Function(BuildContext, ZListRenderRequest request) customView` → rend un widget **arbitraire** fourni par l'app.
   Les vues `builder` et `custom` se rendent **entièrement dans `zcrud_core`** (Material-free) et **n'exigent AUCUN `ZListRenderer` injecté** : elles ne délèguent pas. Testable : widget test par variante ; le test des vues `builder`/`custom` **n'importe PAS** `zcrud_list` (démonstration exécutable qu'une liste se rend sans Syncfusion — SM-5).

6. **AC6 — Quatre états UI ACCESSIBLES et DISTINCTS, rendus par le wrapper.** `DynamicList` est piloté par un état neutre `ZListViewState` (sealed, `presentation/list/`) : `ZListLoading`, `ZListEmpty`, `ZListNoResults`, `ZListError(ZFailure failure)`, `ZListReady(List<ZListRow> rows)`. Le `build` **switch exhaustif** rend :
   - **`loading`** → indicateur de progression **centré** + `Semantics(label: label(context,'list.loading'), liveRegion: true)` ;
   - **`empty`** → message vide neutre (`label(context,'list.empty')`), `Semantics` ;
   - **`noResults`** → message **DISTINCT** d'`empty` (clé `'list.noResults'` ≠ `'list.empty'`, texte différent), `Semantics` — matérialise « aucun résultat **après filtre** » vs « aucune donnée » ;
   - **`error`** → message dérivé de la `ZFailure` (via `label(context,'list.error')` + mapping optionnel de la failure), **`Semantics(liveRegion: true)`** (l'erreur est **annoncée**, AD-11) ;
   - **`ready(rows)`** → dérive les colonnes (`fromSchema`) et dispatch sur `layout` (AC5).
   **Aucune chaîne d'UI codée en dur** (tout via `label(...)`, avec repli `en` ajouté à `_enLabels`) ; **aucune couleur codée en dur** (thème via `Theme.of(context)`/`ZcrudScope`, FR-26). Testable : pump de chaque état → widget attendu présent ; `loading`/`error` portent `liveRegion: true` ; **`empty` et `noResults` sont distincts** (finders/textes différents dans un même test).

7. **AC7 — Les états vivent dans le WRAPPER, pas dans le contrat (décision tranchée, prouvée).** `ZListRenderRequest` **ne porte AUCUN** état `loading`/`empty`/`noResults`/`error` : il reste un **contrat de contenu pur** (colonnes + lignes). Les 4 états sont rendus par `DynamicList` (cœur), en amont du renderer. **Rationale** : (i) une seule implémentation **accessible** des états (Semantics/liveRegion, AD-13) réutilisée par **tous** les backends et **toutes** les vues ; (ii) le renderer reste focalisé sur le rendu tabulaire du contenu ; (iii) SM-5 préservé — les états se rendent **sans** Syncfusion. **Preuve testable** : avec un **faux `ZListRenderer`** enregistrant ses appels, `DynamicList` en état `loading`/`empty`/`noResults`/`error` **n'invoque JAMAIS** le renderer ; il n'est appelé que pour `ready` + `ZListDataGridLayout`. Test dans `zcrud_core`, **sans** import `zcrud_list`.

8. **AC8 — a11y / RTL sur toutes les surfaces (AD-13).** Tous les nouveaux widgets (états + vue `builder`) utilisent les variantes **directionnelles** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional`) — **jamais** `left`/`right` ; `ListView.builder` (jamais `ListView(children:)`) ; `const` partout où c'est immuable ; cibles interactives ≥ 48 dp ; `Semantics` explicites, `liveRegion` sur `loading`/`error`. La garde `style_purity_test.dart` reste **verte** sur les nouveaux fichiers. Le backend `ZSfDataGridRenderer` mis à jour conserve ses insets/alignements directionnels et `rowHeight`/`headerRowHeight` ≥ 48.

9. **AC9 — SM-5 préservé : dérivation + états + vues neutres dans le cœur, Syncfusion isolé.** Tous les nouveaux fichiers de `zcrud_core` (`z_list_column.dart`, deriver, `z_list_layout.dart`, `z_list_view_state.dart`, widgets d'état) importent **uniquement** `package:flutter/{foundation,widgets,material}` + types `zcrud_core` — **zéro** `package:syncfusion`, zéro dépendance lourde, zéro gestionnaire d'état. Les gardes `presentation_purity_test`, `style_purity_test`, `no_heavy_file_dep_test` restent **vertes** ; le test de graphe SM-5 de `zcrud_list` reste **vert** (fermeture `zcrud_core`/`zcrud_markdown` sans `syncfusion*` ; contrôle positif `zcrud_list` **avec** `syncfusion_flutter_datagrid`). `ZSfDataGridRenderer` (zcrud_list), mis à jour pour consommer `ZListColumn` (en-tête via `label(context, col.header)`, `col.width`, cellule via `col.format(row.cells[col.name])`), reste la **SEULE arête Syncfusion**.

10. **AC10 — Barrels, exports, vérif verte.** Les nouveaux types publics (`ZListColumn`, `deriveColumns`, `ZColumnPolicy`, `ZListLayout` + `ZListDataGridLayout`/`ZListBuilderLayout`/`ZListCustomLayout`, `ZListViewState` + `ZListLoading`/`ZListEmpty`/`ZListNoResults`/`ZListError`/`ZListReady`) sont exportés par `packages/zcrud_core/lib/zcrud_core.dart` (ordre `directives_ordering`). `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 sur `zcrud_core` **et** `zcrud_list` ; `melos run verify` RC=0 (gardes de pureté + graphe SM-5 + secrets + codegen). Non-régression : les ACs E4-1 restent satisfaits (renderer + tests adaptés au nouveau `ZListColumn`, comportement de rendu équivalent ou enrichi).

## Tasks / Subtasks

- [x] **Tâche 1 — `ZListColumn` + helper de dérivation PUR (AC1, AC2, AC3)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_column.dart` : `@immutable class ZListColumn { final String name; final String header; final EditionFieldType type; final int order; final double? width; final String Function(Object?) format; ... }` — `const`-compatible, égalité de valeur sur `name/header/type/order/width` (la `format` étant dérivée du `type`). Docstrings « origine E4-2 / neutre Material-free / dérivé de `ZFieldSpec` ».
  - [x] Dans le même fichier, fonction top-level **pure** `List<ZListColumn> deriveColumns(List<ZFieldSpec> schema, {ZColumnPolicy? policy})` : filtre de visibilité (AC3), `header = field.label ?? field.name`, `order = index`, `width` indicative par type (optionnelle), et `format` pure par `EditionFieldType` (AC2, résolution de `choices` pour select/radio/checkbox, join pour multiple/tags/rowChips/Iterable, ISO pour date, `toString` sinon).
  - [x] `ZColumnPolicy` : value object additif (`Set<String> forceInclude`, `Set<String> forceExclude`) — point d'extension AD-4, `const`-compatible, égalité de valeur.
  - [x] Aucune importation Flutter d'exécution au-delà de `package:flutter/foundation.dart` (`@immutable`) ; **aucun** `BuildContext` (garde `presentation_purity` verte).
- [x] **Tâche 2 — Enrichir le contrat `ZListRenderRequest` (AC4)**
  - [x] Éditer `z_list_render_request.dart` : `columns` passe de `List<ZFieldSpec>` à `List<ZListColumn>` ; ajout de la fabrique `ZListRenderRequest.fromSchema(List<ZFieldSpec> fields, List<ZListRow> rows, {ZColumnPolicy? policy})` appelant `deriveColumns`. Égalité de valeur profonde préservée. **Aucun** état UI ajouté au contrat (AC7).
  - [x] Docstring de frontière mise à jour (E4-2 réalise la dérivation ; états dans le wrapper).
- [x] **Tâche 3 — Variantes de vue `ZListLayout` (AC5, AC8)**
  - [x] Créer `z_list_layout.dart` : `sealed class ZListLayout` + `ZListDataGridLayout` (const) / `ZListBuilderLayout({required itemBuilder})` / `ZListCustomLayout({required customView})`.
  - [x] Rendu de la vue `builder` via `ListView.builder` (Material-free, insets directionnels) — widget privé `_ZListBuilderView` dans `dynamic_list.dart`.
- [x] **Tâche 4 — État de liste `ZListViewState` + widgets d'état accessibles (AC6, AC7, AC8)**
  - [x] Créer `z_list_view_state.dart` : `sealed class ZListViewState` + `ZListLoading`/`ZListEmpty`/`ZListNoResults`/`ZListError(ZFailure)`/`ZListReady(List<ZListRow>)` (égalité de valeur).
  - [x] Widgets d'état privés dans `dynamic_list.dart` : `_ZListLoadingView` (progress centré + `Semantics(liveRegion)`), `_ZListMessageView` (empty/noResults, **textes distincts** via clés distinctes), `_ZListErrorView` (message via `label` + `ZFailure.message`, `Semantics(liveRegion: true)`). **Zéro** chaîne/couleur codée en dur (`label(...)` + `Theme.of`).
  - [x] Clés de repli ajoutées à `_enLabels` **et** `_frLabels` (`list.loading`/`list.empty`/`list.noResults`/`list.error`).
- [x] **Tâche 5 — Recâbler `DynamicList` (état + layout + dérivation) (AC5, AC6, AC7, AC10)**
  - [x] Éditer `dynamic_list.dart` : signature `DynamicList({required fields, required state, layout = const ZListDataGridLayout(), renderer, columnPolicy, key})` (constructeur primaire `const`) + fabrique `DynamicList.rows(fields, rows, {...})` (enveloppe `ZListReady(rows)`). `build` : switch exhaustif sur `state` ; pour `ready`, `ZListRenderRequest.fromSchema(...)` puis dispatch sur `layout` (dataGrid → renderer param ou `ZcrudScope.maybeOf().listRenderer`, `ZScopeError` actionnable **uniquement** sur le chemin dataGrid ; builder/custom → rendu cœur, **sans** renderer).
  - [x] Exporter les nouveaux types dans `zcrud_core.dart` (ordre `directives_ordering`).
- [x] **Tâche 6 — Mettre à jour le backend `ZSfDataGridRenderer` (AC4, AC8, AC9)**
  - [x] Éditer `z_sf_data_grid_renderer.dart` : consomme `List<ZListColumn>` — en-tête `Text(label(context, col.header))`, largeur via `col.width` (si non nul → `GridColumn.width`), cellule via `col.format(row.cells[col.name])` (format **neutre partagé**, plus de `toString` brut dupliqué). Insets/alignements directionnels + `rowHeight`/`headerRowHeight` ≥ 48 conservés. **L2 (E4-1)** : `DataGridSource` recréée à chaque `build` (déféré E4-3), pas de régression.
  - [x] Tests E4-1 impactés mis à jour (`z_sf_data_grid_renderer_test.dart`, `dynamic_list_delegation_test.dart`, `z_list_render_request_test.dart`) pour le nouveau `ZListColumn`.
- [x] **Tâche 7 — Tests + vérif verte (tous ACs)**
  - [x] `zcrud_core` unit : `z_list_column_deriver_test.dart` — visibilité (isId + types lourds exclus, scalaires inclus, ordre stable), format par type (select/radio via choices, multiple/tags join, date ISO, number/bool toString, null→''), `ZColumnPolicy` include/exclude + précédence, égalité `ZListColumn`.
  - [x] `zcrud_core` widget : `dynamic_list_states_test.dart` (4 états, `empty` ≠ `noResults`, `liveRegion` sur loading/error) ; `dynamic_list_layout_test.dart` (3 vues, builder/custom **sans import `zcrud_list`**) ; `dynamic_list_renderer_not_called_test.dart` (faux renderer NON invoqué hors ready, AC7).
  - [x] `zcrud_list` : `z_sf_data_grid_renderer_test.dart` mis à jour (colonnes dérivées, en-têtes résolus, format cellule) ; test de graphe SM-5 vert.
  - [x] Vérif verte rejouée : `melos run generate` OK → `melos run analyze` RC=0 (14 packages) → `flutter test` RC=0 (`zcrud_core` 479 + `zcrud_list` 11) → gardes graphe/pureté/style vertes. 0 `.g.dart` suivi, `melos list` = 14.

## Dev Notes

### Décisions tranchées (les deux questions explicites de la story)

- **Dérivation de colonnes → ENRICHIR le contrat (AC4).** La dérivation `schéma → colonnes` produit des `ZListColumn` (en-tête, largeur, `format`) portés par `ZListRenderRequest.columns`. Ainsi le **formatage vit une seule fois dans le cœur** (pur, neutre) et le backend Syncfusion (ou tout autre) ne re-dérive pas et ne duplique pas de logique de format dans `zcrud_list`. C'est cohérent avec SM-5 (le format neutre reste hors Syncfusion) et avec le rôle du port (le backend rend un contenu déjà projeté). Coût : le contrat E4-1 (`columns: List<ZFieldSpec>`) évolue vers `List<ZListColumn>` → mise à jour du renderer + des 3 tests E4-1 (contenue, non régressive).
- **États UI → dans le WRAPPER `DynamicList`, PAS dans `ZListRenderRequest` (AC7).** `ZListRenderRequest` reste un **contrat de contenu pur** (colonnes + lignes). Les états `loading`/`empty`/`noResults`/`error` sont pilotés par `ZListViewState` et rendus par `DynamicList` **en amont** du renderer. Trois raisons : (1) **une seule** implémentation accessible des états (Semantics/liveRegion) réutilisée par tous les backends et toutes les vues (dataGrid/builder/custom) ; (2) le renderer reste focalisé sur le rendu tabulaire ; (3) **SM-5** — les états se rendent **sans** Syncfusion (le renderer n'est même pas invoqué hors `ready`). Mettre les états dans le contrat forcerait chaque backend à ré-implémenter des états accessibles (duplication + risque d'inaccessibilité + couplage Syncfusion).

### Cohérence avec l'existant (patrons à réutiliser, à ne pas réinventer)

- **`ZDataState<T>`** (`domain/data/z_data_state.dart`) est le pendant **domaine** générique (loading/loaded/empty/error) dérivé du flux nu (AD-11). `ZListViewState` est le pendant **présentation** **non générique** (portant des `ZListRow` déjà projetées) **avec** l'état supplémentaire `noResults` que `ZDataState` **n'a pas** (le « no-results-après-filtre » est une distinction UI, pas domaine). On **ne pollue pas** `ZDataState` avec `noResults` : c'est un état de vue. Le mapping `ZDataState → ZListViewState` (dont le choix `empty` vs `noResults` selon qu'un filtre est actif) est câblé par l'appelant/le controller d'**E4-3** ; E4-2 fournit seulement les deux états distincts et leur rendu.
- **Résolution de libellés** : utiliser la fonction top-level `label(context, key, {fallback})` (`presentation/l10n/z_localizations.dart`) qui compose `ZcrudScope.labels` → delegate `ZcrudLocalizations` → table `en` de repli → `fallback` → clé. Ajouter les 4 clés `list.*` à `_enLabels` (et `fr` si présent). **Aucune** chaîne codée en dur.
- **Surface d'erreur accessible** : s'aligner sur le patron existant `z_field_widget.dart:284` / `z_submit_button.dart:61` (`Semantics(liveRegion: true)` + `Text`) pour l'état `error` et `loading`.
- **Seam `ZcrudScope.listRenderer`** + `maybeOf` : réutiliser tel quel (E4-1) pour la vue dataGrid ; le message `ZScopeError` list-spécifique de `dynamic_list.dart` (L1 corrigé E4-1) est conservé et ne se déclenche **que** sur le chemin dataGrid sans renderer.
- **Égalité de valeur profonde** : réutiliser les helpers pur-Dart `_listEquals`/`_mapEquals`/`_mapHash` déjà présents dans `z_list_render_request.dart` / `z_field_spec.dart` (pas de `package:collection`, AD-1 out-degree 0).

### Fichiers UPDATE — état actuel à préserver

- `z_list_render_request.dart` : `ZListRow` (id + cells opaques, égalité valeur) **inchangé** ; `ZListRenderRequest.columns` : **`List<ZFieldSpec>` → `List<ZListColumn>`** + fabrique `fromSchema`. Préserver l'égalité de valeur et les docstrings de frontière (mises à jour).
- `dynamic_list.dart` : actuellement `{fields, rows, renderer}` + résolution `maybeOf` + `ZScopeError` actionnable. **Recâbler** vers `{fields, state, layout, renderer, columnPolicy}` + `DynamicList.rows(...)` de commodité. **Préserver** le message `ZScopeError` list-spécifique (chemin dataGrid uniquement).
- `z_sf_data_grid_renderer.dart` (zcrud_list) : `GridColumn` 1:1 + `_ZListDataGridSource` (`toString` brut). **Migrer** vers `ZListColumn` (en-tête résolu, `col.format`). Conserver directionnalité + `rowHeight` ≥ 48. **L2 déféré** : la `DataGridSource` reste recréée à chaque build (statefulness scroll/sélection = E4-3/E4-4) ; ne pas régresser.
- `zcrud_core.dart` (barrel) : exports `list/*` existants (`dynamic_list`, `z_list_render_request`, `z_list_renderer`) ; **ajouter** `z_list_column`, `z_list_layout`, `z_list_view_state` (+ deriver si fichier séparé), ordre `directives_ordering`.
- `z_localizations.dart` : `_enLabels` (const map) — **ajouter** les 4 clés `list.*` sans casser les clés existantes.

### Preuve SM-5 (comment elle tient en E4-2)

E4-2 **élargit** la surface neutre du cœur (dérivation + états + vues builder/custom) tout en gardant Syncfusion isolé : (1) **statique** — les nouveaux fichiers `presentation/list/*` sont scannés par `presentation_purity_test`/`no_heavy_file_dep_test` (0 `syncfusion`) ; (2) **exécutable** — le test des vues `builder`/`custom` et des 4 états rend une liste **sans** importer `zcrud_list` (le cœur rend des états ET une vue liste complète sans Syncfusion) ; (3) **graphe** — le test SM-5 de `zcrud_list` (fermeture `zcrud_core`/`zcrud_markdown` sans `syncfusion*`, contrôle positif `zcrud_list`) reste vert. La vue `dataGrid` reste la **seule** à déléguer au renderer Syncfusion injecté.

### Frontière E4-2 ↔ E4-3 ↔ E4-4/E4-5 (NE PAS déborder)

- **E4-2 (cette story)** : dérivation fine des colonnes (visibilité/format/ordre/largeur), 3 variantes de vue (liste/DataGrid/custom), **4 états UI accessibles** dont `no-results-après-filtre` (le **rendu** de l'état). **STOP** ici.
- **E4-3** : recherche sans accents (champs `searchable`), **filtres/tri via `ZDataRequest`**, **pagination curseur** (AD-16), repli in-memory documenté. C'est E4-3 qui **calcule** le filtre et **décide** `empty` vs `noResults` (mapping `ZDataState`→`ZListViewState`) ; E4-2 ne fournit que les deux états distincts et leur rendu. Le **formatage locale-aware** des nombres/dates/booléens (déféré ici) peut être branché en E4-3 (hook de format injecté) ou via les labels.
- **E4-4** : **actions ligne + `ZAcl`**, sélection multiple, corbeille (soft-delete/restore) — c'est là que la vue dataGrid gagne de l'**état interactif** (sélection) → traitement de **L2** (passage à une source mémoïsée/`StatefulWidget`).
- **E4-5** : sous-listes/relations & onglets (`ZSubListScreen`).

> Tentation d'ajouter tri/filtre/recherche/pagination/actions/sélection ici : **STOP**, c'est E4-3+. E4-2 = dérivation + vues + états, rien de plus.

### Standards de test

- **Dérivation** : `package:test`/`flutter_test` unit **pur** (aucun widget) — `deriveColumns` déterministe, visibilité, format par type, `ZColumnPolicy`, égalité `ZListColumn`.
- **États & vues** : `flutter_test` widget — pump `DynamicList` par état et par layout ; asserts `Semantics`/`liveRegion` (via `find.bySemanticsLabel`/`tester.getSemantics`) ; **distinction `empty`/`noResults`** dans un test dédié.
- **AC7 (states dans le wrapper)** : faux `ZListRenderer` inline (compteur d'appels) — **non invoqué** hors `ready` ; **aucun import `zcrud_list`** dans les tests du cœur.
- **Contrôle positif SM-5** conservé (test de graphe `zcrud_list`) ; gardes de pureté vertes sur les nouveaux fichiers.

### Project Structure Notes

- Tout le neuf du cœur vit sous `packages/zcrud_core/lib/src/presentation/list/` (cohérent E4-1). API publique = barrel `lib/zcrud_core.dart` ; impl sous `lib/src/`.
- `zcrud_list` reste satellite (AD-1) ; seule modif = `z_sf_data_grid_renderer.dart` (consomme `ZListColumn`) + tests. Aucun nouveau package, `melos list` = 14.
- Aucun conflit de structure détecté. `EditionFieldType` (source des règles de visibilité/format) est déjà dans `domain/edition/edition_field_type.dart`.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E4 — Moteur DynamicList] (Story E4-2 : « colonnes issues du `ZFieldSpec[]` ; `itemBuilder`/`customView` ; états accessibles : `loading`, `empty`, `no-results-après-filtre`, `error` » ; frontière E4-3/E4-4/E4-5)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-8] (liste dérivée du schéma ; `zcrud_core` n'expose que l'abstraction `ZListRenderer` + modèles Material-free ; Syncfusion isolé dans `zcrud_list` ; backend Material `DataTable` implémentable sur le même port)
- [Source: architecture.md#AD-11] (`Either<ZFailure,T>` sur les contrats, flux nus, hiérarchie `ZFailure` ; les états UI dérivés portent la `ZFailure` — état `error` annoncé)
- [Source: architecture.md#AD-13] (RTL/a11y : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start` ; `Semantics` explicites, cibles ≥ 48 dp ; la vue liste sémantique est la surface a11y de référence ; l10n via delegate + registre)
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#SM-5] (isolation des dépendances : `zcrud_markdown` seul ne tire ni Firebase ni Syncfusion ni Maps ; renforcé ici par le rendu liste/états dans le cœur)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart] (contrat E4-1 à enrichir : `columns`/`rows`, égalité de valeur profonde, helpers pur-Dart)
- [Source: packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart] (hôte mince E4-1 à recâbler : résolution `maybeOf` + `ZScopeError` list-spécifique conservée sur le chemin dataGrid)
- [Source: packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart] (backend E4-1 à migrer vers `ZListColumn` ; L2 = `DataGridSource` recréée par build, déféré E4-3/E4-4)
- [Source: packages/zcrud_core/lib/src/domain/data/z_data_state.dart] (`ZDataState` sealed loading/loaded/empty/error — pendant domaine ; `ZListViewState` = pendant présentation + `noResults`)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart] (`ZFieldSpec` = source des colonnes : `name`/`label`/`type`/`choices`/`isId`/`searchable`/`config`)
- [Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart] (catalogue des `EditionFieldType` : base des règles de visibilité et de format)
- [Source: packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart#label] (résolution composée `label(context,key,{fallback})` + `_enLabels` à étendre — aucune chaîne codée en dur)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_submit_button.dart] (patron `Semantics(liveRegion: true)` pour états annoncés, à réutiliser pour `loading`/`error`)
- [Source: _bmad-output/implementation-artifacts/stories/code-review-e4-1.md#L2] (finding L2 : `_ZListDataGridSource` recréé à chaque build → statefulness grille, pertinent E4-2+/E4-3)
- [Source: CLAUDE.md#Critical Patterns AD-8/AD-13] (liste dérivée du schéma derrière `ZListRenderer` ; directionnalité RTL ; `ListView.builder` obligatoire ; thème injecté, aucun style codé en dur)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `melos run analyze` → SUCCESS sur les 14 packages (RC=0).
- `flutter test` `zcrud_core` → **479 tests OK** (dont 48 sous `test/presentation/list/`).
- `flutter test` `zcrud_list` → **11 tests OK** (renderer migré + graphe SM-5 (a)/(b)/(c)/(d)).
- Gardes de pureté `zcrud_core` (`presentation_purity`, `style_purity`, `no_heavy_file_dep`) → **12 tests OK**.
- Graphe AD-1/SM-5 (`graph_proof.py`) → ACYCLIQUE OK, **CORE OUT=0 OK**, 14 nœuds ; `gate:melos`/`gate:reflectable` OK.
- `melos run generate` → SUCCESS ; `melos list` = 14 ; `git ls-files '*.g.dart'` = 0.

### Completion Notes List

- **AC1/AC2/AC3** : `deriveColumns` est un helper **top-level pur** (aucun `BuildContext`/widget/I-O, déterministe). Visibilité par **whitelist** de types tabulaires (`_tabularTypes`) : `isId` et types lourds/non-tabulaires (`subItems`/`dynamicItem`/`file`/`image`/`document`/`location`/`geoArea`/`address`/`signature`) exclus, ainsi que les types non-whitelistés (`hidden`/`markdown`/`relation`/…) — extensible via `ZColumnPolicy.forceInclude` (AD-4). `format` pur par type, ne lève jamais (AD-10).
- **AC4** : `ZListRenderRequest.columns` migré `List<ZFieldSpec>` → `List<ZListColumn>` + fabrique `fromSchema` (dérivation centralisée dans le cœur, format neutre partagé). Égalité de valeur profonde préservée. Aucun état UI dans le contrat.
- **AC5** : `ZListLayout` sealed (dataGrid/builder/custom). `builder` rend un `ListView.builder` **dans le cœur** ; `custom` un widget arbitraire. Prouvé sans import `zcrud_list` (`dynamic_list_layout_test.dart`).
- **AC6/AC7/AC8** : 4 états rendus par le wrapper via un switch exhaustif sur `ZListViewState`. `empty` (`list.empty`, clé `zListEmpty`) ≠ `noResults` (`list.noResults`, clé `zListNoResults`) — textes distincts. `loading`/`error` portent `Semantics(liveRegion: true)` (vérifié via `flagsCollection.isLiveRegion`). Zéro chaîne codée en dur (`label(...)`), zéro couleur codée en dur (`Theme.of(context).colorScheme.error`). Insets directionnels uniquement.
- **AC7 (preuve)** : faux `ZListRenderer` compteur — **non invoqué** pour loading/empty/noResults/error, invoqué **exactement 1×** pour ready+dataGrid (`dynamic_list_renderer_not_called_test.dart`).
- **AC9 (SM-5)** : `zcrud_core` conserve 0 dépendance/import `syncfusion` ; `ZSfDataGridRenderer` reste la **seule** arête Syncfusion ; test de graphe (fermeture core/markdown sans syncfusion + contrôle positif list) vert.
- **Décisions/ambiguïtés tranchées** :
  - `DynamicList.rows(...)` rendu **non-`const`** (l'initialiseur `ZListReady(rows)` sur paramètre runtime n'est pas une constante) ; le **constructeur primaire reste `const`** (test de const-constructibilité migré sur lui).
  - Visibilité implémentée en **whitelist** (types tabulaires listés) plutôt qu'en blocklist : déterministe, sûr pour les types non listés/`custom` (exclus par défaut, réinclus via policy) — conforme à l'esprit d'AC3.
  - `format` **exclue** de `==`/`hashCode` de `ZListColumn` (closure dérivée du type), cohérent avec `ZFieldSpec`.
  - Assertion `liveRegion` migrée de `hasFlag(SemanticsFlag.isLiveRegion)` (déprécié) vers `flagsCollection.isLiveRegion` ; clé posée sur le widget `Semantics` d'erreur pour interroger le nœud via `getSemantics(find.byKey)`.
- **Frontière respectée** : aucun tri/filtre/recherche/pagination ni calcul `empty` vs `noResults` (E4-3) ; aucune action/`ZAcl`/sélection/corbeille (E4-4) ; aucun formatage locale-aware (déféré E4-3, format neutre ici).

### File List

**Créés (zcrud_core) :**
- `packages/zcrud_core/lib/src/presentation/list/z_list_column.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_layout.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_view_state.dart`
- `packages/zcrud_core/test/presentation/list/z_list_column_deriver_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_states_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_layout_test.dart`
- `packages/zcrud_core/test/presentation/list/dynamic_list_renderer_not_called_test.dart`

**Modifiés (zcrud_core) :**
- `packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart` (columns→`ZListColumn` + `fromSchema`)
- `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart` (state/layout/dérivation + widgets d'état privés)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (4 clés `list.*` en/fr)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports `z_list_column`/`z_list_layout`/`z_list_view_state`)
- `packages/zcrud_core/test/presentation/list/dynamic_list_delegation_test.dart` (migration `ZListColumn`/`.rows`)
- `packages/zcrud_core/test/presentation/list/z_list_render_request_test.dart` (migration `fromSchema`/`ZListColumn`)

**Modifiés (zcrud_list) :**
- `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` (consomme `ZListColumn` : header résolu, `col.width`, `col.format`)
- `packages/zcrud_list/test/z_sf_data_grid_renderer_test.dart` (migration `fromSchema`)
