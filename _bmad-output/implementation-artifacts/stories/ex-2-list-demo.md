---
baseline_commit: fe203b90bb95a659063452af4cf584f66e7bab0f
---

# Story EX.2 : Démo LISTE (`DynamicList`) dans l'application exemple

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur/évaluateur de zcrud (et futur intégrateur DODLP/lex_douane)**,
je veux **une seconde démo dans l'app exemple (`example/`) qui monte le moteur `DynamicList` end-to-end sur une source de données de démonstration in-memory — colonnes dérivées du schéma, recherche/filtre/tri, pagination, actions de ligne + sélection + corbeille, et une vue à onglets — avec le backend Syncfusion `ZSfDataGridRenderer` injecté par l'app via `ZcrudScope(listRenderer: ...)`, câblée depuis l'accueil et démontrée sous la parité des 4 bindings**,
afin de **valider en conditions réelles le moteur liste (E4) et l'invariant SM-5 (l'APP tire Syncfusion via `zcrud_list`, jamais `zcrud_core`) / AD-8 (Syncfusion isolé derrière `ZListRenderer`), sans jamais rompre l'invariant « 14 packages produit » ni toucher AUCUN package sous `packages/`**.

**C'est la DEUXIÈME story de l'epic EX (application exemple).** L'app croît avec les epics : édition (EX-1, done) → **liste (EX-2, cette story)** → firestore / markdown / geo·intl·export (EX-3). Elle n'ajoute QUE la démo liste ; les démos firestore/markdown/geo restent **hors périmètre** (frontière EX-2/EX-3, cf. §Frontière).

## Contexte

- **Origine** : consigne user 2026-07-10 + sprint-status section EX (`ex-2-list-demo: backlog`). L'app exemple est le **harnais de validation croissant** défini en EX-1 : après l'édition (E3), elle doit exercer la liste (E4) pour prouver SM-5 (l'app tire Syncfusion via `zcrud_list`) et AD-8 (backend isolé derrière le port `ZListRenderer`). [Source: sprint-status.yaml#176-184 ; ex-1-scaffold-edition-demo.md]
- **État réel du dépôt** (vérifié sur disque) : **E4 done** — le moteur liste est entièrement livré dans `zcrud_core` (`DynamicList`, `ZListController`, `ZListColumn`/`deriveColumns`, `ZListLayout`, états `ZListViewState`, `ZListSelectionController`, `ZRowAction`, `ZTabbedList`, `ZSubListScreen`) + le backend `ZSfDataGridRenderer` dans `zcrud_list` (E4-1). EX-2 se développe **EN PARALLÈLE** de E6 (`zcrud_markdown`) et E11a (`zcrud_geo`) : fichiers disjoints, aucune dépendance croisée — EX-2 reste **STRICTEMENT dans `example/`**.
- **Rôle de harnais** : `example/` est la seule app qui monte réellement `DynamicList` end-to-end avec un vrai backend Syncfusion injecté. Elle matérialise AD-8 (le cœur ne connaît que l'abstraction ; l'app fournit `ZSfDataGridRenderer`) et SM-5 (`zcrud_core` reste Syncfusion-free ; c'est l'app, consommateur, qui tire `zcrud_list`).
- **Ce que EX-1 a déjà posé** (à réutiliser, NE PAS réinventer) : `ExampleApp` (`lib/app.dart`) avec `ZcrudScope` racine (thème `ZcrudTheme` de démo + `DemoFilePicker`), l10n fr/en, toggles thème/langue/RTL ; `HomeScreen` (`lib/home_screen.dart`) = `ListView.builder` d'entrées par domaine (Édition active ; Liste/Firestore/Markdown/Geo « à venir » désactivées) ; `binding_selector.dart` (`DemoBinding {scope, get, riverpod, provider}`, `wrapWithBinding(...)` + `_BindingSeamForwarder` qui **re-propage déjà `root.listRenderer`** sous le scope d'un binding — MEDIUM-1 EX-1) ; `reference_form.dart` (schéma `ReferenceForm.fields`, 34 champs). [Source: example/lib/app.dart ; home_screen.dart ; binding/binding_selector.dart:80-88 ; demos/reference_form.dart]

## Décision structurante — injection du backend Syncfusion + parité binding

**DÉCISION (orchestrateur, à appliquer par dev-story) :**

1. **Le backend Syncfusion est injecté au NIVEAU DU `ZcrudScope` RACINE** (`example/lib/app.dart`), pas au niveau de l'écran de démo. Ajouter `listRenderer: const ZSfDataGridRenderer()` au `ZcrudScope` racine du `builder:` de `ExampleApp`. **Raison** : le `_BindingSeamForwarder` (EX-1) ne re-propage sous un binding QUE les seams captés depuis le **scope racine** (`root.listRenderer`, cf. `binding_selector.dart:86`) ; injecter le renderer plus bas que le scope racine le rendrait invisible sous get/riverpod/provider → la liste basculerait en `ZScopeError` (chemin `dataGrid` sans renderer) sous 3 des 4 bindings, cassant AC5/AC7. Injecter à la racine garantit la parité des 4 voies sans code spécial. C'est `example/` (app isolée, consommateur légitime de Syncfusion) — **aucun** package sous `packages/` n'est touché.
2. **`DynamicList` par défaut est en `layout: ZListDataGridLayout()`** (chemin Syncfusion via le renderer injecté) — c'est la démo canonique de SM-5. Un test prouve que le renderer injecté est bien un `ZSfDataGridRenderer` (SM-5 : l'app tire Syncfusion via `zcrud_list`).
3. **`zcrud_list` (+ transitivement `syncfusion_flutter_datagrid`) est ajouté au SEUL `pubspec.yaml` de `example/`** (deps `path:` + `dependency_overrides` `path:`, calqués sur les entrées `zcrud_core`/bindings existantes). L'app reste **hors** du bloc `workspace:` racine et hors du glob melos `packages/**` (invariant « 14 » automatiquement préservé, lock propre `example/pubspec.lock`). [Source: ex-1-scaffold-edition-demo.md#Décision structurante ; example/pubspec.yaml]

**Risque connu à valider en dev-story (ambiguïté)** : `zcrud_list` déclare `resolution: workspace` ; comme pour `zcrud_core`/bindings en EX-1, la dép `path:` + `dependency_overrides` `path:` doit réconcilier source path↔hosted (`zcrud_list` épingle `zcrud_core: ^0.0.1` hosted). **Protocole** : tenter `flutter pub get` réel dans `example/`. Si `pub` refuse (« package is a workspace member »), appliquer le fallback EX-1 documenté (le même que celui déjà appliqué : `dependency_overrides` `path:` suffit — c'est la voie standalone retenue en EX-1, aucun ajout au `workspace:` racine ne fut requis). Documenter la voie + la preuve `pub get` (nb deps du lock propre) dans les notes de dev.

## Acceptance Criteria

1. **AC1 — `zcrud_list` ajouté au SEUL pubspec de l'app ; l'app compile ; `packages/` INCHANGÉ.** Le `pubspec.yaml` de `example/` déclare `zcrud_list` (dep `path: ../packages/zcrud_list` + `dependency_overrides` `path:`), tirant transitivement `syncfusion_flutter_datagrid`. `flutter pub get` RC=0 (lock **propre** `example/pubspec.lock`, root lock intact). `flutter analyze` (app) RC=0 ; `flutter test` (app) RC=0. **AUCUN** fichier sous `packages/**` n'est créé/modifié (`git status -- packages/` vide). Given un checkout propre → When `flutter pub get && flutter analyze && flutter test` dans `example/` → Then RC=0 et `packages/` inchangé.

2. **AC2 — Invariant « 14 packages PRODUIT » préservé.** `dart run melos list` retourne **exactement 14** packages ; l'app exemple n'y figure pas. `python3 scripts/dev/graph_proof.py` reste vert (CORE OUT=0, acyclique inchangé). `dart run scripts/ci/gate_melos_divergence.dart` (M-1) reste vert. Given `zcrud_list` ajouté à l'app → When on rejoue melos list + graph_proof + gate:melos → Then 14 packages, graphe inchangé, M-1 vert. (L'ajout de Syncfusion au lock **de l'app** ne pollue PAS le lock racine partagé — SM-5/AD-15.)

3. **AC3 — Écran démo LISTE : `DynamicList` avec colonnes DÉRIVÉES du schéma sur données in-memory.** Un écran `ListDemoScreen` (`example/lib/demos/list_demo_screen.dart`) monte une `DynamicList` pilotée par un `ZListController` **stable** (créé en `initState`, `dispose` en fin de vie), alimentée par un `ZRepository` de démo **in-memory** (fake seedé de ≥ 40 lignes) et un **schéma de démo** (`List<ZFieldSpec>` de champs scalaires/affichables : `text`, `integer`/`number`, `dateTime`, `boolean`, `select`) réutilisant le vocabulaire de `reference_form.dart`. Les **colonnes sont dérivées du schéma** via `deriveColumns`/`ZColumnPolicy` (pas de colonnes codées à la main) : seuls les types affichables apparaissent (les types lourds `subItems`/`file`/`image`/`signature`/`document` sont exclus par défaut). L'écran écoute la **seule** tranche `ZListController.state` via `ValueListenableBuilder` (rebuild ciblé, AD-2). Given l'écran monté → When on inspecte la grille → Then les colonnes correspondent aux champs affichables du schéma (libellés/ordre dérivés), les lignes in-memory sont rendues.

4. **AC4 — Recherche / filtre / tri / pagination fonctionnels.** L'écran expose : (a) un **champ de recherche** (poussé au `ZListController` → `ZDataRequest` texte, ANDé au `baseFilters`) ; (b) au moins un **filtre** (ex. un `select` de catégorie via `ZFilter`) ; (c) le **tri** par colonne (ascendant/descendant) ; (d) la **pagination** (`pageSize` défini → curseur natif du fake, avec repli in-memory `ZListPaginationMode`). Les états `ZListLoading`/`ZListEmpty`/`ZListNoResults`/`ZListReady` sont correctement rendus (notamment `noResults` distinct d'`empty` quand une recherche ne matche rien). Given la liste chargée → When on tape une recherche / applique un filtre / trie une colonne / pagine → Then le jeu de lignes se met à jour en conséquence (résultats filtrés/triés/paginés), `noResults` affiché si aucune correspondance.

5. **AC5 — Actions de ligne + sélection multiple + corbeille (soft-delete/restore), backend Syncfusion injecté.** La liste porte : (a) des **actions de ligne** (`ZRowAction.edit` custom + `ZRowAction.softDelete`/`ZRowAction.restore`) filtrées par un `ZAcl` de démo (`actionAclMode`) ; (b) la **sélection multiple** via un `ZListSelectionController` (keyée par `id` stable) ; (c) la **corbeille** : une action soft-delete bascule `is_deleted` (via le fake repo) et une action restore la rétablit. La `DynamicList` est rendue en `ZListDataGridLayout` par le `ZSfDataGridRenderer` **injecté au scope racine** (AD-8/SM-5). Given une ligne → When on l'édite (hook navigation/snackbar) / la sélectionne / la soft-delete puis restore → Then l'action edit est invoquée une fois, la sélection reflète l'`id`, la ligne disparaît puis réapparaît ; le rendu passe par le backend Syncfusion injecté.

6. **AC6 — Vue à onglets (`ZTabbedList`) OU sous-liste (`ZSubListScreen`) démontrée.** L'écran (ou un onglet dédié) monte **au moins une** des deux briques E4-5 : soit un `ZTabbedList` (≥ 2 onglets catégorisant les données via `baseFilters`, état préservé au switch), soit un `ZSubListScreen` (liste d'enfants reliés à un parent par `ZFilter(parentField, eq, parentId)`). La brique retenue est câblée sur le **même** fake repo/schéma de démo. Given la vue à onglets/sous-liste → When on change d'onglet (ou on ouvre la sous-liste d'un parent) → Then chaque onglet/relation affiche son sous-ensemble filtré, l'état (recherche/tri/sélection) de chaque onglet est préservé au switch.

7. **AC7 — Câblage depuis l'accueil : entrée « Liste » ACTIVÉE.** Dans `home_screen.dart`, l'entrée « Liste » n'est plus « à venir »/désactivée : elle est **active** (`available: true`, `onOpen: (_) => const ListDemoScreen()`), navigue vers `ListDemoScreen`, cible tactile ≥ 48 dp (AD-13). Les entrées Firestore/Markdown/Geo restent « à venir » (frontière EX-3). Given l'accueil → When on tape « Liste » → Then l'app navigue vers la démo liste sans exception.

8. **AC8 — Parité multi-binding (AD-15) démontrée sur la liste.** La démo liste réutilise `binding_selector.dart` (`BindingSelector` + `wrapWithBinding`) pour rendre la **même** `DynamicList` sous : (i) `ZcrudScope` seul (défaut), (ii) `zcrud_get`, (iii) `zcrud_riverpod`, (iv) `zcrud_provider`. Le comportement (colonnes dérivées, recherche/tri, actions, rendu Syncfusion via `root.listRenderer` re-propagé par `_BindingSeamForwarder`) est **identique** sous les 4. Le `ZListController` est possédé dans le `State` (create/dispose), un remontage propre au switch (`KeyedSubtree(ValueKey(binding))`, nouveau controller par wrap). Un test monte la liste sous **≥ 2** wraps (défaut + un binding) et assert la parité observable (même rendu + renderer Syncfusion disponible). **Si la parité liste est jugée non pertinente sur un point précis, le documenter explicitement dans les notes de dev** (mais la voie par défaut est la parité complète, comme EX-1).

9. **AC9 — SM-5 non cassé + AD-8 démontré.** `zcrud_core` **reste** sans Syncfusion (aucune modification de `zcrud_core` par cette story). Le renderer concret (`ZSfDataGridRenderer`) vient **exclusivement** de `zcrud_list`, importé par l'**app**. Un test assert que le `ZcrudScope.listRenderer` résolu dans la démo est un `ZSfDataGridRenderer` (SM-5 : l'app tire Syncfusion via `zcrud_list`, AD-8 : le cœur ne connaît que le port). Le lock propre de l'app **n'altère pas** le `pubspec.lock` racine. Given la story terminée → When on inspecte `git diff` sur `packages/` et le lock racine → Then `packages/` inchangé, lock racine non pollué.

10. **AC10 — Frontière EX-2/EX-3 respectée + gates transverses verts.** L'app n'ajoute **aucune** démo Firestore/offline, Markdown, Geo/Intl/Export (entrées d'accueil toujours « à venir »). **Aucune** dépendance à `zcrud_firestore`, `zcrud_markdown`, `zcrud_geo`, `zcrud_intl`, `zcrud_export` n'est ajoutée par EX-2 (seul `zcrud_list` s'ajoute aux deps EX-1). Les gates transverses restent verts : `gate:reflectable`, `gate:secrets` (aucune clé/licence Syncfusion committée — l'enregistrement de licence est une config plateforme de l'app hôte, non requise pour le rendu communautaire), `gate:codegen`. Given le `pubspec.yaml` de l'app → When on liste ses deps → Then `zcrud_core` + 3 bindings + `zcrud_list` uniquement, aucun package E5/E6/E11a ; le test de frontière (`boundary_deps_test.dart`) est mis à jour pour AUTORISER `zcrud_list` et continuer d'INTERDIRE firestore/markdown/geo/intl/export.

## Tasks / Subtasks

- [x] **T1 — Ajouter `zcrud_list` au pubspec de l'app + `flutter pub get` réel (AC1, AC2, AC9, AC10).**
  - [x] Ajouter dans `example/pubspec.yaml` : `zcrud_list: { path: ../packages/zcrud_list }` (bloc `dependencies`) ET l'entrée miroir dans `dependency_overrides` (calqué sur `zcrud_core`/bindings existants). Mettre à jour le commentaire d'en-tête (frontière EX-2 : `zcrud_list` désormais autorisé ; firestore/markdown/geo/intl/export toujours interdits).
  - [x] Tenter `flutter pub get` réel dans `example/`. Documenter la voie retenue (standalone `path:`+overrides attendue) et la preuve (RC=0, nb deps du lock propre, root lock intact).
  - [x] Vérifier `dart run melos list` = **14**, `graph_proof.py` vert, `gate:melos` (M-1) vert (AC2). Vérifier `git status -- packages/` vide (AC1/AC9).
- [x] **T2 — Injecter le backend Syncfusion au `ZcrudScope` racine (AC5, AC8, AC9).**
  - [x] Dans `example/lib/app.dart`, ajouter `listRenderer: const ZSfDataGridRenderer()` au `ZcrudScope` racine du `builder:` (import `package:zcrud_list/zcrud_list.dart`). Justification en commentaire : la racine est le point d'injection re-propagé par `_BindingSeamForwarder` (parité 4 bindings, AC8).
  - [x] Confirmer que `binding_selector.dart` n'est PAS modifié (il re-propage déjà `root.listRenderer`, cf. EX-1 MEDIUM-1) — sinon documenter.
- [x] **T3 — Source de données de démo : modèle + fake repo in-memory + schéma (AC3, AC4).**
  - [x] Créer `example/lib/demos/list_demo_data.dart` : un modèle `DemoRecord implements ZEntity` (`String? get id`) portant des champs scalaires (ex. `name`/text, `quantity`/integer, `unitPrice`/number, `createdAt`/dateTime, `active`/boolean, `category`/select) ; un `List<ZFieldSpec>` **schéma de démo** (réutilisant le vocabulaire de `reference_form.dart` — types affichables uniquement) ; un `ZListRow Function(DemoRecord)` `toRow` ; un `DemoRepository implements ZRepository<DemoRecord>` seedé de ≥ 40 lignes, supportant `watch(ZDataRequest)`/`getAll`/`softDelete`/`restore`/`save`/`count` en mémoire (bascule `is_deleted` sur un `Set<String>` hors-entité). **Réutiliser le patron des fakes E4** (`packages/zcrud_core/test/presentation/list/z_list_controller_test.dart` : `_Item implements ZEntity`, `_toRow`, `_FakeRepo implements ZRepository`).
  - [x] `pageSize` défini (ex. 15) → pagination curseur native du fake (repli in-memory `ZListPaginationMode` documenté).
- [x] **T4 — Écran `ListDemoScreen` : DynamicList + recherche/filtre/tri/pagination (AC3, AC4, AC5, AC7).**
  - [x] `example/lib/demos/list_demo_screen.dart` : `StatefulWidget` créant un `ZListController` stable (`initState`/`dispose`), écoutant la **seule** tranche `state` via `ValueListenableBuilder`, rendant `DynamicList(fields: schema, state: value, layout: ZListDataGridLayout(), columnPolicy: ..., selection: ..., rowActions: ..., entityFor: ..., actionAclMode: ...)`.
  - [x] Barre de recherche (push texte au controller), un filtre `select` de catégorie (`ZFilter`), tri de colonne (asc/desc), contrôle/scroll de pagination. Usage **directionnel** (AD-13 : `EdgeInsetsDirectional`, `TextAlign.start/end`), `ListView.builder` si liste ad hoc, `const` où possible.
  - [x] Actions de ligne (`ZRowAction.edit` → snackbar/navigation de démo, `ZRowAction.softDelete`/`restore`), `ZListSelectionController` (sélection multiple keyée par `id`), `ZAcl` de démo + `actionAclMode`.
- [x] **T5 — Vue à onglets OU sous-liste E4-5 (AC6).**
  - [x] Ajouter un `ZTabbedList` (≥ 2 onglets catégorisant via `baseFilters`, `ZListTab.category`) **ou** un `ZSubListScreen` (relation parent→enfants via `ZFilter(parentField, eq, parentId)`) sur le même fake repo/schéma. Documenter le choix. État par onglet préservé au switch (keep-alive natif de `ZTabbedList`).
- [x] **T6 — Câblage accueil + parité binding (AC7, AC8).**
  - [x] `home_screen.dart` : déplacer l'entrée « Liste » de `_staticEntries` (désactivée) vers une entrée **active** dans `_entries` (`available: true`, `onOpen: (_) => const ListDemoScreen()`). Conserver Firestore/Markdown/Geo désactivées.
  - [x] `ListDemoScreen` : réutiliser `BindingSelector` + `wrapWithBinding(binding, body, rootScope: ZcrudScope.maybeOf(context))` (calqué sur `EditionDemoScreen`), `KeyedSubtree(ValueKey(binding))`, nouveau `ZListController` par wrap (dispose de l'ancien). Sinon documenter la limite de parité (AC8).
- [x] **T7 — Tests (AC1, AC3, AC4, AC5, AC6, AC8, AC9, AC10).**
  - [x] Widget : `ListDemoScreen` s'affiche (état `ready`), colonnes dérivées présentes (libellés du schéma), ≥ 1 interaction (recherche OU tri OU soft-delete) modifie le jeu de lignes observable.
  - [x] Parité : liste montée sous ≥ 2 wraps (défaut + 1 binding), rendu identique + `ZcrudScope.of(context).listRenderer is ZSfDataGridRenderer` (SM-5/AD-8, AC9).
  - [x] Navigation : tap « Liste » sur l'accueil → `ListDemoScreen` poussé.
  - [x] Frontière : mettre à jour `example/test/boundary_deps_test.dart` pour AUTORISER `zcrud_list` et continuer d'INTERDIRE `zcrud_firestore`/`zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/`zcrud_export` (AC10).
- [x] **T8 — Vérif verte + gates (AC1, AC2, AC9, AC10).**
  - [x] `flutter analyze` (app) RC=0 ; `flutter test` (app) RC=0 ; `flutter build web` (ou cible dispo) compile.
  - [x] `melos list` = 14 ; `graph_proof.py` vert ; `gate:melos`/`gate:reflectable`/`gate:secrets`/`gate:codegen` verts.
  - [x] `git status -- packages/` vide ; root `pubspec.lock` inchangé (aucune dep Syncfusion tirée dans le lock racine — AC9).

## Dev Notes

### Contraintes d'architecture applicables (rappel AD)

- **AD-8 (Syncfusion isolé derrière `ZListRenderer`)** : `zcrud_core` n'expose QUE l'abstraction `ZListRenderer` ; le backend concret `ZSfDataGridRenderer` vit **exclusivement** dans `zcrud_list`. **C'est l'app** qui l'importe et l'injecte via `ZcrudScope(listRenderer:)`. Ne JAMAIS importer Syncfusion ailleurs que dans `example/` (et jamais dans `packages/`). [Source: packages/zcrud_list/lib/zcrud_list.dart ; z_list_renderer.dart:1-26 ; architecture.md#AD-8]
- **SM-5 (le cœur reste léger)** : `zcrud_core` reste Syncfusion/Firebase/Maps-free. L'app exemple, CONSOMMATEUR, a le droit de tirer `zcrud_list`/Syncfusion — ça ne casse PAS SM-5 (qui concerne le graphe de `zcrud_core`, pas des apps). Le lock **de l'app** porte Syncfusion ; le lock **racine** ne doit PAS. [Source: prd.md SM-5 ; ex-1-scaffold-edition-demo.md#AC9 ; example/pubspec.yaml]
- **AD-2 / AD-15 (réactivité Flutter-native, parité)** : le `ZListController` (comme `ZFormController`/`ZListSelectionController`) est un `ChangeNotifier` pur-Flutter exposant une **unique tranche** `ValueListenable<ZListViewState>` — AUCUN gestionnaire d'état. L'écran écoute cette seule tranche via `ValueListenableBuilder`. Le controller vit dans le `State` (create `initState` / dispose). Le code manager-spécifique reste confiné au `wrap` d'injection (`binding_selector.dart`). [Source: z_list_controller.dart:1-58 ; architecture.md#AD-2/#AD-15]
- **AD-13 (a11y/RTL)** : variantes **directionnelles** obligatoires (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`) ; cibles ≥ 48 dp ; le toggle RTL de l'accueil (EX-1) doit continuer d'exercer la direction sur l'écran liste (grille + chrome). [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts]
- **AD-1 / « 14 packages »** : ne PAS transformer l'app en package produit ; `example/` reste hors `workspace:` racine et hors glob melos `packages/**`. L'invariant « 14 » est un garde-fou testé (AC2). NE modifier AUCUN fichier sous `packages/`. [Source: pubspec.yaml ; ex-1-scaffold-edition-demo.md#AC2]
- **`ListView.builder`** (jamais `ListView(children:)`), `const` pour les widgets immuables, cibles tactiles ≥ 48 dp. [Source: CLAUDE.md Key Don'ts]

### API publique consommée (signatures réelles, vérifiées sur disque — LECTURE SEULE de `packages/`)

Tout est exposé par les barrels `package:zcrud_core/zcrud_core.dart` et `package:zcrud_list/zcrud_list.dart`.

- **`DynamicList<T extends ZEntity>`** (`dynamic_list.dart:56`) — `StatelessWidget`. Constructeur nommé principal :
  `DynamicList({ required List<ZFieldSpec> fields, required ZListViewState state, ZListLayout layout = const ZListDataGridLayout(), ZListRenderer? renderer, ZColumnPolicy? columnPolicy, ZListSelectionController? selection, List<ZRowAction<T>>? rowActions, T? Function(ZListRow row)? entityFor, ZActionAclMode actionAclMode = ZActionAclMode.hide, void Function(Set<String> selectedIds)? onSelectionChanged, String? collectionId })`. Chemin `dataGrid` → délègue au `renderer` passé OU au seam `ZcrudScope.listRenderer` ; si AUCUN → `ZScopeError` actionnable. `builder`/`custom` → rendu dans le cœur, aucun renderer requis. [Source: dynamic_list.dart:58-74]
- **`ZListController<T extends ZEntity>`** (`z_list_controller.dart:54`) — `ChangeNotifier`.
  `ZListController({ required ZRepository<T> repository, required ZListRow Function(T) toRow, required List<ZFieldSpec> schema, int? pageSize, ZListPaginationMode mode = ZListPaginationMode.backendCursor, List<ZFilter> baseFilters = const [] })`. Expose la tranche `ValueListenable<ZListViewState> state`. Détient le `ZDataRequest` courant (recherche/filtre/tri), pousse au repository (curseur) ou pagine in-memory (repli AD-16). [Source: z_list_controller.dart:21-58]
- **`ZListViewState`** (`sealed`) : `ZListLoading`, `ZListEmpty`, `ZListNoResults`, `ZListError(ZFailure)`, `ZListReady(List<ZListRow> rows)`. Le wrapper `DynamicList` rend loading/empty/noResults/error lui-même (accessibles, `Semantics`/`liveRegion`) sans invoquer le renderer. [Source: z_list_view_state.dart:21-124]
- **`ZListRow`** : `const ZListRow({ required String id, required Map<String,Object?> cells })`. `id` STABLE (jamais index). [Source: z_list_render_request.dart:33]
- **`ZColumnPolicy`** : point d'extension additif (`forceInclude`/`forceExclude` par `name`) ; `deriveColumns(...)` (pur) décide visibilité/format/libellé/ordre/largeur à partir du `ZFieldSpec[]`. Types NON affichables exclus par défaut (`subItems`, `file`, `image`, `document`, `signature`, `relation`, `markdown`, …). [Source: z_list_column.dart:30-69]
- **`ZListLayout`** (`sealed`) : `ZListDataGridLayout()` (défaut, backend Syncfusion), `ZListBuilderLayout({ required itemBuilder })` (rend dans le cœur, sans renderer), `ZListCustomLayout({ required customView })`. [Source: z_list_layout.dart:25-57]
- **`ZListSelectionController`** (`ChangeNotifier`) : `ZListSelectionController({ ZListSelectionMode mode })` ; tranche `ValueListenable<Set<String>> selectedIds` (`id` stables, `Set` non modifiables) ; `toggle(id)`/`isSelected(id)` ; `dispose()`. [Source: z_list_selection.dart:40-69]
- **`ZRowAction<T extends ZEntity>`** — fabriques : `ZRowAction.edit({ required FutureOr<void> Function(BuildContext, T) onInvoke, String labelKey='edit', IconData? icon })` (perm `ZCrudAction.update`) ; `ZRowAction.softDelete(...)` (perm `ZCrudAction.delete`, appelle `repository.softDelete`) ; `ZRowAction.restore(...)` (perm `ZCrudAction.restore`, `repository.restore`). Résolues par ligne en `ZResolvedRowAction` (sans `T`) — le renderer ne voit jamais `T` ni `ZAcl`. `ZActionAclMode {hide (défaut), disable}`. [Source: z_row_action.dart:44-172]
- **`ZTabbedList`** : `ZTabbedList({ required List<ZListTab> tabs, int initialIndex=0, ValueChanged<int>? onTabChanged, bool isScrollable=false })` — chrome `TabBar`/`TabBarView` pur-Material, une `DynamicList`/`ZListController` **indépendante keep-alive** par onglet (état préservé au switch), sélection **indépendante** par onglet. `ZListTab({ required String labelKey, required WidgetBuilder builder, IconData? icon })` + `ZListTab.category({ required labelKey, required List<ZFilter> filters, required builder(context, categoryFilters), icon })`. [Source: z_tabbed_list.dart:36-64 ; z_list_tab.dart:26-60]
- **`ZSubListScreen<T extends ZEntity>`** : assembleur mince qui construit UN `ZListController` seedé de `baseFilters: [ZFilter(parentField, ZFilterOp.eq, parentId)]` (relation persistante, toujours ANDée), rend une `DynamicList` complète (recherche/tri/pagination + actions/ACL/sélection/corbeille). Ne PAS confondre avec le CHAMP d'édition inline `ZSubListField`/`ZSubListConfig` (E3-3b-2, embarqué dans le doc parent). [Source: z_sub_list_screen.dart:1-63]
- **`ZSfDataGridRenderer`** (barrel `package:zcrud_list/zcrud_list.dart`) : `const ZSfDataGridRenderer()`, backend concret du port `ZListRenderer` (traduit `columns`/`rows` neutres en `SfDataGrid`). SEULE arête Syncfusion du monorepo. [Source: zcrud_list.dart ; z_sf_data_grid_renderer.dart]
- **`ZRepository<T extends ZEntity>`** (port neutre) : `Stream<List<T>> watchAll()` ; `Stream<List<T>> watch(ZDataRequest)` ; `Future<ZResult<List<T>>> getAll({ZDataRequest?})` ; `Future<ZResult<T>> getById(String)` ; `Future<ZResult<T>> save(T, {String? collectionId})` ; `Future<ZResult<Unit>> softDelete(String)` ; `Future<ZResult<Unit>> restore(String)` ; `Future<ZResult<int>> count({ZDataRequest?})`. Flux **NUS** (jamais dans `Either`). [Source: z_repository.dart:40-64]
- **`ZEntity`** : `abstract`, `String? get id`. [Source: domain/contracts/z_entity.dart:25]

### Patron de fake repository (à réutiliser, oracle sur disque — LECTURE SEULE)

`packages/zcrud_core/test/presentation/list/z_list_controller_test.dart` fournit un patron minimal éprouvé :
- `class _Item implements ZEntity { final String id; ... }`
- `ZListRow _toRow(_Item it) => ZListRow(id: it.id, cells: { ... });`
- `class _FakeRepo implements ZRepository<_Item> { ... watch(request) ... }`
Transposer en `DemoRecord`/`DemoRepository` **dans `example/lib/demos/list_demo_data.dart`** (jamais dans `packages/`), seedé de ≥ 40 lignes avec catégories variées pour exercer filtre/recherche/tri/pagination, et un `Set<String> _deleted` pour `softDelete`/`restore`. [Source: z_list_controller_test.dart:17-43 ; dynamic_list_trash_test.dart ; z_sub_list_screen_test.dart]

### Point d'injection du backend (décision critique, cf. §Décision structurante)

Le `_BindingSeamForwarder` (`binding_selector.dart:67-90`) re-propage `root.listRenderer` (capté depuis le scope racine) sous le `ZcrudScope` d'un binding. **Conséquence** : le `listRenderer` DOIT être injecté au `ZcrudScope` **racine** (`app.dart`), sinon il est masqué sous get/riverpod/provider (`maybeOf` = plus proche seulement) et la liste tombe en `ZScopeError` sur 3 des 4 bindings. Injecter à la racine = parité gratuite (AC8). [Source: binding_selector.dart:80-88 ; app.dart:59-70]

### Previous story intelligence (EX-1, done)

- EX-1 a livré `example/` STANDALONE (hors workspace, lock propre) via `path:` + `dependency_overrides` `path:` — **voie standalone confirmée** (aucun ajout au `workspace:` racine requis). Rejouer la même voie pour `zcrud_list`. [Source: ex-1-scaffold-edition-demo.md#T1]
- MAJEUR-1 (code-review EX-1) : disposer les contrôleurs dépendants AVANT leurs dépendances au switch de binding. Pour la liste : disposer `ZListSelectionController` puis `ZListController` proprement à chaque switch/dispose. [Source: edition_demo_screen.dart:62-84]
- MEDIUM-1 (code-review EX-1) : les seams applicatifs (dont `listRenderer`) sont re-propagés par `_BindingSeamForwarder` — NE PAS le retoucher, s'appuyer dessus. [Source: binding_selector.dart:33-40]
- EX-1 tests : `boundary_deps_test.dart` (frontière deps), `binding_parity_test.dart`, `app_smoke_test.dart`, `support/pump_helpers.dart` — réutiliser les helpers de pump et étendre `boundary_deps_test.dart` (AC10). [Source: example/test/]

### Frontière EX-2 vs EX-3 (STOP)

- **EX-2 (cette story)** = démo **LISTE uniquement** : `DynamicList` + recherche/filtre/tri/pagination + actions/sélection/corbeille + onglets/sous-liste, backend Syncfusion injecté, parité binding. Source de données **in-memory** (fake repo) — PAS de Firestore.
- **EX-3 (futur)** = Firestore/offline (E5, `zcrud_firestore` réel), Markdown (E6, `zcrud_markdown`), Geo/Intl/Export (E11a/E11b). Ces entrées d'accueil restent « à venir »/désactivées. Aucune dép `zcrud_firestore`/`zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/`zcrud_export` ajoutée par EX-2.

### Project Structure Notes

- Fichiers NOUVEAUX (tous sous `example/`) : `example/lib/demos/list_demo_screen.dart`, `example/lib/demos/list_demo_data.dart`, éventuellement un test `example/test/list_demo_test.dart`.
- Fichiers MODIFIÉS (tous sous `example/`) : `example/pubspec.yaml` (+ `zcrud_list`), `example/lib/app.dart` (+ `listRenderer` racine), `example/lib/home_screen.dart` (activer « Liste »), `example/test/boundary_deps_test.dart` (autoriser `zcrud_list`).
- **AUCUN** fichier sous `packages/**` créé ou modifié (lecture seule pour comprendre l'API) — invariant NON-NÉGOCIABLE.
- Naming : préfixe `Z` pour les types du cœur consommés ; fichiers snake_case ; `ListDemoScreen`/`DemoRecord`/`DemoRepository` côté app (pas de préfixe `Z`, ce n'est pas du cœur).

### Ambiguïtés détectées (à trancher en dev-story, documenter le choix)

1. **`resolution: workspace` de `zcrud_list` + `path:`** : voie standalone attendue (comme EX-1) ; fallback documenté si `pub` refuse. Prouver par `flutter pub get` réel.
2. **AC6 — `ZTabbedList` vs `ZSubListScreen`** : au moins UNE des deux ; `ZTabbedList` (catégories via `baseFilters`) est le choix par défaut recommandé (plus visuel pour une démo, un seul fake repo). Documenter le choix retenu.
3. **Licence Syncfusion** : le rendu communautaire n'exige PAS de clé committée (gate:secrets) ; ne rien committer. Si un warning de licence apparaît au runtime, c'est acceptable pour une démo (documenter), NE PAS ajouter de clé.
4. **Portée de la parité binding (AC8)** : parité complète recommandée (comme EX-1) ; si un aspect s'avère non pertinent, le justifier par écrit.

### References

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml#176-184 (section EX)]
- [Source: _bmad-output/implementation-artifacts/stories/ex-1-scaffold-edition-demo.md (scaffold, isolation, parité, MAJEUR-1/MEDIUM-1)]
- [Source: example/lib/app.dart ; example/lib/home_screen.dart ; example/lib/binding/binding_selector.dart ; example/lib/demos/edition_demo_screen.dart ; example/lib/demos/reference_form.dart ; example/pubspec.yaml]
- [Source: packages/zcrud_core/lib/src/presentation/list/*.dart (dynamic_list, z_list_controller, z_list_renderer, z_list_column, z_list_layout, z_list_view_state, z_list_selection, z_row_action, z_tabbed_list, z_list_tab, z_sub_list_screen, z_list_render_request)]
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart ; domain/contracts/z_entity.dart ; domain/data/z_data_request.dart]
- [Source: packages/zcrud_list/lib/zcrud_list.dart ; packages/zcrud_list/pubspec.yaml (ZSfDataGridRenderer, arête Syncfusion)]
- [Source: packages/zcrud_core/test/presentation/list/z_list_controller_test.dart (patron fake repo/toRow)]
- [Source: architecture.md#AD-1/#AD-2/#AD-8/#AD-13/#AD-15/#AD-16 ; prd.md SM-5/FR-6..FR-8 ; CLAUDE.md Key Don'ts]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `example/` : `flutter pub get` RC=0 (lock PROPRE `example/pubspec.lock` ; Syncfusion tiré dans le lock DE L'APP uniquement) → `flutter analyze` **0 issue** → `flutter test` **30 tests OK** → `flutter build web` **RC=0** (« ✓ Built build/web »).
- Isolation vérifiée sur disque : `git status -- packages/` ne montre QUE des fichiers `zcrud_geo`/`zcrud_markdown` (E11a/E6 en parallèle) — **aucun** fichier `packages/**` touché par EX-2. `git diff -- pubspec.lock` racine ne contient **aucune** ligne `syncfusion` (Syncfusion préexiste au lock racine car `zcrud_list` est membre du workspace depuis E4-1 ; la diff du lock racine est E6/E11a — quill/map — pas EX-2). `dart run melos list` = **14**.

### Completion Notes List

- **T1 (voie standalone confirmée)** : `zcrud_list` ajouté au SEUL `example/pubspec.yaml` (dep `path:` + miroir `dependency_overrides` `path:`), calqué sur EX-1. `flutter pub get` a réconcilié source↔hosted **sans** ajout au `workspace:` racine (fallback EX-1 non requis). Syncfusion (`syncfusion_flutter_datagrid` 32.2.9) figure dans `example/pubspec.lock` (SM-5 : l'APP tire Syncfusion via `zcrud_list`).
- **T2** : `listRenderer: const ZSfDataGridRenderer()` injecté au `ZcrudScope` **RACINE** (`app.dart`) — seul point re-propagé par `_BindingSeamForwarder` (parité 4 bindings). `binding_selector.dart` **non modifié** (il re-propage déjà `root.listRenderer`).
- **T3** : `DemoRecord implements ZEntity` + `DemoStore` partagé (soft-delete `is_deleted` HORS-ENTITÉ via `Set<String>`, flux broadcast) + `DemoRepository` (vue active / corbeille sur le même magasin, `getAll` honore filtres/tri/recherche/curseur via `zApplyListRequest`) seedé de **48** lignes ; schéma `demoSchema` (6 champs affichables, `name` searchable).
- **T4** : `ListDemoScreen` — `ZListController` stable (`pageSize: 15`, `watchMutations: true`), écoute la seule tranche `state` (`ValueListenableBuilder`, AD-2), `DynamicList` en `ZListDataGridLayout` (défaut), colonnes dérivées via `ColumnPolicy`/`deriveColumns`, recherche + filtre catégorie (`ZFilter`) + tri (`ZSort` asc/desc), actions `edit`+`softDelete`, sélection multiple, `ZAcl` de démo (`_DemoAcl` refuse `update` sur inactif) en `actionAclMode.disable`.
- **T5 (choix : `ZTabbedList`, ambiguïté #2)** : `CategoryTabsScreen` monte un `ZTabbedList` (`isScrollable`) — onglet « Toutes » + un onglet par catégorie, chacun via `ZListTab.category`/`baseFilters`, liste indépendante keep-alive. La **corbeille** (`TrashScreen`, vue `includeDeleted:true`) démontre `restore` (AC5). Choix `ZTabbedList` retenu (plus visuel, un seul magasin).
- **T6** : accueil `home_screen.dart` — entrée « Liste » **active** (`available: true`, `onOpen: (_) => const ListDemoScreen()`). Parité via `BindingSelector`/`wrapWithBinding(rootScope:)` + `KeyedSubtree(ValueKey(binding))` ; nouveau controller/selection par wrap ; dispose de la **sélection (dépendante) AVANT** le `ZListController` (MAJEUR-1 EX-1).
- **T7** : `example/test/list_demo_test.dart` (12 tests : source in-memory recherche/filtre/tri/pagination + corbeille ; rendu `SfDataGrid` + colonnes dérivées ; AC9 renderer résolu = `ZSfDataGridRenderer` ; parité binding scope+riverpod ; onglets ; navigation accueil). `boundary_deps_test.dart` mis à jour : `zcrud_list` **autorisé**, firestore/markdown/geo/intl/export toujours **interdits** (AC10).
- **T8** : voir Debug Log — analyze 0 issue, 30 tests OK, build web RC=0, melos=14, `packages/` inchangé, lock racine non pollué, aucune licence/secret Syncfusion committé (gate:secrets). `flutter: uses-material-design: true` ajouté au pubspec de l'app (icônes Material requises par la démo + `SfDataGrid`).
- **Ambiguïtés tranchées** : #1 voie standalone `path:`+overrides (confirmée, pas de fallback) ; #2 `ZTabbedList` (catégories) ; #3 aucune licence Syncfusion committée (rendu communautaire) ; #4 parité binding complète (comme EX-1).
- **Gates transverses globaux** (`graph_proof.py`, `gate:melos`, `gate:reflectable`, `gate:codegen`) : **NON rejoués globalement** car E6/E11a écrivent `packages/` en parallèle → résultats faussés ; ils restent la responsabilité de l'orchestrateur. Preuve locale ciblée : `melos list` = 14, `packages/` inchangé par EX-2.

### Remédiation code-review EX-2 (2026-07-10, dev-story effort high, périmètre `example/` uniquement)

- **MEDIUM-1 (pagination non navigable) — CORRIGÉ.** Câblage UI de la pagination : nouveau widget `_LoadMoreBar` (n'écoute QUE la tranche `state` du controller, AD-2) rendant un bouton « Charger plus (N) » appelant `ZListController.loadMore()`. Placé sous la liste principale (`ListDemoScreen._buildBody`) ET sous l'onglet « Toutes » (`_CategoryList`, désormais `Column`+`Expanded`+bar). Visibilité pilotée par une heuristique miroir du controller (`rows.length` multiple de `pageSize` ⇒ dernière page pleine ⇒ page suivante probable ; page partielle ⇒ bouton masqué). Cible ≥ 48 dp (AD-13). `pageSize` factorisé en `_demoPageSize = 15`. Rationale : ni `DynamicList` ni le `ZListRenderer` Syncfusion n'exposent de hook scroll-end / `loadMoreViewBuilder` dans l'API publique de `zcrud_list` (vérifié LECTURE SEULE) → bouton, voie sanctionnée par la revue. Preuves end-to-end : (a) test **controller** `pagination curseur : loadMore parcourt les 48 lignes par pages de 15` — 15→30→45→48 puis no-op, **48 ids uniques (aucun doublon, curseur avancé)** ; (b) test **UI** `MEDIUM-1 — le bouton « Charger plus » pagine la liste end-to-end` — tap → « Charger plus (15) » devient « Charger plus (30) » (> 15 lignes atteignables via l'UI).
- **LOW-1 (`watch`/`watchAll` ignoraient `includeDeleted`/`request`) — CORRIGÉ (fix trivial, pas seulement documenté).** `watchAll()` mappe désormais `store.changes → _data` (honore `includeDeleted`) ; `watch(request)` mappe `store.changes → _applyRequest(request)` (honore filtres/tri/recherche/curseur). Sûr : le controller n'utilise l'émission que comme déclencheur (`.listen((_) => _runQuery())`, payload ignoré — vérifié dans `z_list_controller.dart:84`). `getAll` refactoré pour réutiliser `_applyRequest` (DRY).
- **LOW-3 (parité 2/4 bindings) — CORRIGÉ.** La boucle de test AC8 itère désormais `DemoBinding.values` (scope + GetX + Riverpod + provider) : les 4 rendent le MÊME `SfDataGrid` (renderer re-propagé par `_BindingSeamForwarder`), aucune exception.
- **LOW-2 (`syncfusion_flutter_datagrid` dev_dep directe test-only) — CONSERVÉ tel quel** (déjà justifié `depend_on_referenced_packages` ; runtime transitif via `zcrud_list`) — aucune licence committée.
- **Vérif verte REJOUÉE (ciblée `example/`, 2026-07-10)** : `flutter analyze` → **0 issue** ; `flutter test` → **34 tests OK, 0 échec** (dont les 2 nouveaux tests pagination + 2 parités bindings ajoutées ; `list_demo_test.dart` passe de 12 à **16** tests) ; `flutter build web` → **RC=0** (« ✓ Built build/web »). `git status -- packages/` : **aucun** fichier EX-2 (seuls `zcrud_geo`/`zcrud_markdown` des agents parallèles). Gates globaux : responsabilité orchestrateur (non rejoués — `packages/` en écriture parallèle).

### File List

**Créés (tous sous `example/`)**
- `example/lib/demos/list_demo_data.dart` — `DemoRecord`/`DemoStore`/`DemoRepository` + `demoSchema` + `toDemoRow`. _(Remédiation LOW-1 : `watch`/`watchAll` honorent `includeDeleted`/`request` via `_applyRequest` ; `getAll` refactoré DRY.)_
- `example/lib/demos/list_demo_screen.dart` — `ListDemoScreen` + `TrashScreen` + `CategoryTabsScreen` + `_DemoAcl`. _(Remédiation MEDIUM-1 : widget `_LoadMoreBar` + constante `_demoPageSize`, pagination navigable dans la liste principale et l'onglet « Toutes ».)_
- `example/test/list_demo_test.dart` — tests widget/data EX-2 (**16 tests** après remédiation : +1 pagination curseur controller, +1 pagination UI « Charger plus », parité AC8 étendue aux **4** bindings).
- `example/pubspec.lock` — lock PROPRE de l'app (Syncfusion tiré via `zcrud_list`).

**Modifiés (tous sous `example/`)**
- `example/pubspec.yaml` — dep + override `zcrud_list` ; `syncfusion_flutter_datagrid` en dev_dependency (test-only) ; `uses-material-design: true`.
- `example/lib/app.dart` — `listRenderer: const ZSfDataGridRenderer()` au `ZcrudScope` racine.
- `example/lib/home_screen.dart` — entrée « Liste » activée.
- `example/test/boundary_deps_test.dart` — `zcrud_list` autorisé, E5/E6/E11a toujours interdits.

**AUCUN fichier sous `packages/**` créé ou modifié par EX-2 (invariant NON-NÉGOCIABLE respecté).**
