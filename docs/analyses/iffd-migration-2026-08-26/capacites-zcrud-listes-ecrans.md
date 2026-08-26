# Capacités zcrud — aire « Listes, écrans assemblés, navigation, export »

**Relevé du 2026-08-26.** zcrud à **v3.21.0** (tag du 2026-08-25 13:24 UTC), 41 paquets.
Périmètre : 11 paquets. Racine mesurée : `/home/zakarius/DEV/zcrud/packages/`.

> **Ce document est un CATALOGUE DE L'OFFRE, pas un plan de migration.** Il dit ce que le socle
> sait faire aujourd'hui, `fichier:ligne` à l'appui. Il ne dit pas ce qu'IFFD doit faire.

## Méthode et unité de compte

Un **canal public** = un symbole de premier niveau atteignable depuis le barrel du paquet
(classe, enum, typedef, fonction ou constante de premier niveau). Les **ré-exports d'autres
paquets** ne sont pas comptés au paquet qui les relaie (sinon `zcrud_export` compterait deux fois
les 25 symboles de `zcrud_export_pdf`). Les **paramètres nommés** des grands assemblages sont
comptés à part, en dessous du tableau du paquet.

| Paquet | Version | fichiers `lib/` | LOC `lib/` | fichiers `test/` | canaux publics |
|---|---|---|---|---|---|
| `zcrud_screen` | 3.21.0 | 18 | 7 515 | 39 | **37** |
| `zcrud_list` | 3.21.0 | 3 | 1 652 | 5 | **4** |
| `zcrud_navigation` | 3.21.0 | 13 | 2 177 | 16 | **23** |
| `zcrud_menu` | 3.21.0 | 12 | 1 448 | 8 | **20** |
| `zcrud_ui_kit` | 3.21.0 | 22 | 3 380 | 31 | **29** |
| `zcrud_responsive` | 3.21.0 | 9 | 1 392 | 9 | **8** |
| `zcrud_reorder` | 3.21.0 | 3 | 459 | 5 | **3** |
| `zcrud_dnd` | 3.21.0 | 4 | 662 | 2 | **8** |
| `zcrud_export` | 3.21.0 | 6 | 358 | 6 | **4** |
| `zcrud_export_pdf` | 3.21.0 | 19 | 2 278 | 8 | **25** |
| `zcrud_export_ui` | 3.21.0 | 5 | 299 | 2 | **4** |
| **Total** | | **114** | **21 620** | **131** | **165** |

## Ce que l'hôte consomme déjà de ces 11 paquets — mesuré

`grep -rlnw <symbole> /home/zakarius/DEV/iffd/lib/` — nombre de fichiers hôtes citant le symbole :

| Symbole | fichiers IFFD | Symbole | fichiers IFFD |
|---|---|---|---|
| `presentFormEdition` | **29** | `ZCrudScreen` | **0** |
| `ZFormOnly` | **12** | `ZCrudSource` | **0** |
| `presentEdition` | 2 | `ZListQueryPolicy` | **0** |
| `ZResponsiveLayout` | 2 | `ZExportPolicy` | **0** |
| `ZAppBarAction` | 2 | `ZSfDataGridRenderer` | **0** |
| `ZPageScaffold` | 1 | `ZPageShellBody` / `ZSearchableAppBar` | **0** |
| `ZAdaptiveGrid` | 1 | `ZActionMenu` / `ZContextMenuRegion` / `ZMenuEntry` | **0** |
| `ZReorderableAdaptiveGrid` | 1 | `ZEmptyState`/`ZErrorState`/`ZLoadingState`/`ZContentStateView` | **0** |
| `ZEditionChrome` | 1 | `ZConfirmDialog` / `showZConfirmDialog` | **0** |
| | | `ZDiscardChangesGuard` / `ZToaster` | **0** |
| | | `ZAlphabetIndexBar` / `ZCountBadge` / `zPageRoute` | **0** |
| | | `ZExporter` / `ZPdfPreview` / `ZFileSaver` | **0** |
| | | `ZFlashcardPdfTemplate` / `ZPdfExportOptions` | **0** |
| | | `ZNativeDropRegionRenderer` / `ZPackageReorderRenderer` | **0** |

Contre-poids maison mesuré côté hôte (`grep -rn … /home/zakarius/DEV/iffd/lib/`) :
**60** fichiers avec `Scaffold(`, **47** avec `AppBar(`, **25** occurrences de `AlertDialog(`,
**25** de `PopupMenuButton`, **16** de `PopScope(`, **49** de `CircularProgressIndicator`,
**8** de `ScaffoldMessenger`, **15** de `SfDataGrid`/`DataTable(`.

🔴 **Deux commentaires de `pubspec.yaml` de l'hôte sont PÉRIMÉS et gouvernent des absences.**
1. `pubspec.yaml:292` : « `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34, IFFD est en ^32 ».
   IFFD est aujourd'hui sur **`syncfusion_flutter_core/datagrid/pdf: ^34.1.31`**
   (`pubspec.yaml:141-149`). Le paquet `zcrud_list` demande `syncfusion_flutter_datagrid: ^34.1.31`
   (`zcrud_list/pubspec.yaml`), `zcrud_export` demande `xlsio`+`pdf` `^34.1.31`. **Le blocage n'existe plus.**
2. `pubspec.yaml:326` : « la chaîne `zcrud_flashcard -> zcrud_export -> syncfusion_flutter_pdf` ».
   GREP NÉGATIF MONTRÉ : `grep -n 'zcrud_export' packages/zcrud_flashcard/pubspec.yaml` → **RC=1**,
   aucune ligne. L'unique occurrence dans `zcrud_flashcard/lib` est un commentaire qui dit
   l'inverse (`z_flashcard_api.dart:21` : « Ce paquet ne dépend pas de `zcrud_export` »).
   **L'export n'arrive donc plus transitivement** : le déclarer est un choix explicite.

---

## 1. `zcrud_screen` — l'écran CRUD assemblé (37 canaux)

Barrel : `packages/zcrud_screen/lib/zcrud_screen.dart:24-40` (17 exports).
**Le paquet le plus actif du périmètre : 17 releases touchant `lib/` entre le 13 et le 24 août.**

### 1.1 `ZCrudScreen` — `z_crud_screen.dart:180`

`ZCrudScreen<T extends ZEntity>` ; constructeur `z_crud_screen.dart:182`, **54 paramètres nommés**
(dont `super.key`), 53 champs `final` de `:246` à `:1003`.

> Un hôte qui veut un écran liste + recherche + création + édition + corbeille + ACL écrit
> `ZCrudScreen(title: …, source: …, registry: …)` et rien d'autre : les champs de liste, ceux du
> formulaire, la projection en cellules et la reconstruction d'entité se dérivent du
> `ZcrudRegistry`. Chaque dérivation reste remplaçable par un paramètre.

| Canal | `fichier:ligne` | Ce qu'il permet (phrase de consommateur) | Défaut |
|---|---|---|---|
| `title` | `:246` | Titre de l'écran. | requis |
| `source` | `:249` | La source : dépôt, dépôt en lecture seule, ou liste en mémoire. | requis |
| `registry` | `:255` | Fournit le schéma généré ⇒ colonnes, formulaire, encode/decode dérivés. | `null` |
| `kind` | `:259` | Force la clé de type au registre au lieu de la déduire. | `null` |
| `listFields` | `:262` | Remplace les colonnes dérivées. | `null` |
| `formFields` | `:266` | Remplace les champs de formulaire dérivés. | `null` |
| `cellsOf` | `:270` | Remplace la projection entité → cellules. | `null` |
| `acl` | `:280` | ACL de l'écran ; sinon celle du `ZcrudScope` ambiant. | `null` |
| `policy` | `:283` | Politique de présentation de l'édition (page/feuille/dialogue). | `const ZPresentationPolicy()` |
| `formWeight` | `:286` | Départage `expanded → dialog\|page`. | `ZFormWeight.light` |
| `layout` | `:302` | Choisit la disposition : grille de données, liste, cartes, vue entière. | `null` |
| `itemBuilder` | `:310` | Tuile recevant **l'entité `T`**, pas la ligne neutre. | `null` |
| `tabs` | `:348` | Onglets de catégorisation ; le bouton de création lit l'onglet actif. | `null` |
| `tabsScrollable` | `:357` | Onglets défilants. | `false` |
| `tabsStore` | `:396` | **Persiste l'onglet actif ET un offset de défilement PAR onglet.** | `null` |
| `tabsScopeKey` | `:409` | Force la clé de portée (sinon dérivée type + écran + jeu d'onglets). | `null` |
| `query` | `:454` | Tri, filtres de base, groupes de filtres, filtre mémoire, pagination, portée et pliage de recherche. | `const ZListQueryPolicy()` |
| `header` | `:458` | Bandeau libre au-dessus de la liste. | `null` |
| `canCreate` | `:462` | Offre la création. | `true` |
| `canDuplicate` | `:472` | Offre la duplication. | `true` |
| `titles` | `:477` | Intitulés de la surface d'édition (type ré-exporté du cœur, `z_crud_titles.dart:13`). | `null` |
| `trash` | `:480` | Corbeille : `auto` / `none` / … (`enum ZTrashMode`, `:93`). | `ZTrashMode.auto` |
| `trashPolicy` | `:496` | Gouverne restaurer / purger, **et depuis v2.5.0 l'accès à la VUE corbeille**. | `ZTrashPolicy.full` |
| `trashCount` | `:526` | Compteur d'éléments en corbeille, notifié. | `null` |
| `mode` | `:547` | `full` / `details` / `locked` (`enum ZScreenMode`, `z_screen_mode.dart:27`). | `ZScreenMode.full` |
| `detailsEnabled` | `:592` | Ouvre la fiche de détail en lecture. | `false` |
| `rowColor` | `:628` | Teinte de ligne **avec libellé accessible** (`ZRowTint`, `z_row_tint.dart:49`). | `null` |
| `readOnly` | `:653` | 🔴 **`@Deprecated`** (annotation du paramètre `:210-214`, du champ `:649-652`) — remplacé par `mode`. | `false` |
| `searchEnabled` | `:657` | Recherche intégrée. | `true` |
| `onSave` | `:661` | Écriture, voie `items`. | `null` |
| `beforeSubmit` | `:671` | 🆕 **Crochet après validation, avant décodage** — création, édition, duplication. | `null` |
| `editionBuilder` | `:675` | Surface d'édition entièrement fournie par l'hôte. | `null` |
| `defaultItemBuilder` | `:680` | Entité pré-remplie à la création. | `null` |
| `history` | `:684` | Journal d'entité avec **diff entre versions**, gouverné par `ZCrudAction.history`. | `null` |
| `rowActions` | `:694` | Actions de ligne. | `null` |
| `trashRowActions` | `:702` | Actions de ligne **spécifiques à la vue corbeille**. | `null` |
| `columnPolicy` | `:705` | Politique de colonnes (type du cœur, `z_list_column.dart:424`). | `null` |
| `collectionId` | `:719` | Collection cible des écritures. | `null` |
| `actions` | `:727` | Actions d'app-bar **en données** (`ZAppBarAction`). | `const []` |
| `actionsBuilder` | `:760` | Actions d'app-bar **dépendantes de l'état** (ACL restreinte à l'onglet, index, compte, corbeille, vacuité). | `null` |
| `appBarActions` | `:782` | Échappatoire : widgets bruts d'app-bar. | `const []` |
| `leading` | `:786` | `leading` de l'app-bar. | `null` |
| `drawer` | `:826` | **Tiroir de navigation de l'hôte**, relayé aussi à l'écran « accès refusé ». | `null` |
| `endDrawer` | `:840` | Idem, côté fin. | `null` |
| `rowAcl` | `:866` | Permissions **par ligne** (`ZRowAclResolver`, cœur `z_row_governance.dart:164`). | `null` |
| `actionAclMode` | `:874` | Action refusée : masquée ou désactivée (`enum` cœur `z_row_action.dart:53`). | `ZActionAclMode.hide` |
| `rowActionsPresentation` | `:895` | En ligne ou en menu (`z_row_actions_presentation.dart:16`). | `inline` |
| `inlineActionLimit` | `:900` | Bascule en débordement au-delà de N. | `2` |
| `longPressOwner` | `:912` | Qui possède l'appui long (`z_row_actions_presentation.dart:59`). | `contextMenu` |
| `confirmDestructive` | `:930` | Confirmation des gestes destructifs. | `true` |
| `selection` | `:984` | Sélection multiple, « tout sélectionner », compte rendu (`z_selection_policy.dart:38`). | `null` |
| `batchActions` | `:990` | Actions de masse (`typedef` `z_selection_policy.dart:88`). | `null` |
| `export` | `:1003` | Export intégré (`ZExportPolicy`, `z_export_policy.dart:74`). | `null` |

### 1.2 Les autres canaux du paquet

| Canal | `fichier:ligne` | Ce qu'il permet | Piège / défaut |
|---|---|---|---|
| `ZCrudSource.repository` | `z_crud_source.dart:53` | Dépôt complet : lecture, écriture, corbeille. | — |
| `ZCrudSource.readOnlyRepository` | `z_crud_source.dart:93` | **Ressource immuable servie par un dépôt** : pagination, tri, recherche serveur conservés ; `canWrite`/`supportsTrash`/`supportsPurge` tous `false`, dépôt `ZPurgeable` compris. | Ce n'est **pas** une ACL : le geste n'est offert à personne, pas même sous ACL tout-accordée. |
| `ZCrudSource.items` | `z_crud_source.dart:109` | Liste en mémoire ; l'absence de rappel = absence de geste. | Champs `:124-154` |
| `presentFormEdition` | `present_form_edition.dart:234` | **22 paramètres** (`:236-256`). Prend un catalogue de champs et rend la map **validée** (ou `null`). Remplace `Scaffold`+`AppBar`+bouton+`ZEditionSubmitController` montés à la main. | cf. §1.3 |
| `steps` / `stepperConfig` | `present_form_edition.dart:249-250` | Assistant **multi-étapes** ; `steps` est une liste ordinaire, donc le nombre d'étapes peut dépendre des données. | Un champ du catalogue qu'aucune étape ne nomme est **validé sans être affiché** ⇒ fenêtre insoumissible sans message. Signalé en debug (`:368-383`). |
| `bodyBuilder` | `present_form_edition.dart:251` (typedef `:54`) | Corps composé par l'appelant, avec **le même contrôleur** que la soumission lira. | Exclusif de `steps` et `sections` — assertions `:258`, `:264`, `:270`. Préséance en prod : `bodyBuilder` > `steps` > plat. |
| `bodyFit` | `present_form_edition.dart:252` | Déclare comment le corps veut être placé. | `null` ⇒ **dérivé** : `intrinsic` (plat/bodyBuilder), `scrollable` (assistant). |
| `collapseStore` / `formId` | `present_form_edition.dart:255-256` | **Repli des sections qui SURVIT à la fermeture** ; le stockage appartient à l'app. | 🔴 **Délibérément NON relayés par `ZCrudScreen`** — justification au point de montage, `z_crud_screen.dart:4352`. |
| `ZFormOnly` | `z_form_only.dart:178` | Le formulaire **sans chrome**, à poser où l'on veut. 14 champs `:208-271`. | — |
| `ZFormOnlyController` | `z_form_only.dart:52` | Contrôleur partagé entre le corps composé et la soumission. | — |
| `ZListQueryPolicy` | `z_list_query_policy.dart:111` | `sort` `:181`, `baseFilters` `:216`, `baseFilterGroups` `:248`, `itemFilter` `:295`, `pageSize` `:305`, `searchScope` `:322`, `searchFolding` `:332`, `paginationMode` `:375`. | fabrique `.legacySearch` `:162` |
| `ZListQueryScope` | `z_list_query_policy.dart:534` | Diffuse la politique de requête par `InheritedWidget`. | — |
| `ZCrudScreenActions` | `z_crud_screen_actions.dart:85` | **Piloter l'écran depuis l'extérieur** : `openCreation` `:171`, `openEdition` `:103`, `openDetails` `:130`, `openUpdate` `:157`, `sortBy` `:185`, `filterBy` `:194`. | interface **implémentée par l'écran**, jamais par l'app |
| `entitiesInView` | `z_crud_screen_actions.dart:238` | **Lire ce que l'écran liste** — ordre peint, portée, onglet actif, recherche, filtres, pages chargées. | Écran vide/en erreur ⇒ lecture **vide**, jamais le rendu précédent |
| `entitiesInViewListenable` | `:266` | La même lecture, notifiée **seulement si le contenu diffère**. | n'entraîne pas le corps de l'écran |
| `entitiesSelectedOrInView` | `:278` | Les cochées si la sélection porte, les listées sinon — la règle exacte de l'export intégré. | — |
| `ZCrudScreenScope` | `:287` | `maybeOf(context)` `:309` pour atteindre les actions. | — |
| `zCrudEditionOpener` / `zCrudDetailsOpener` | `:326` / `:139` | Fabrique un `ZCrudOpener?` (`typedef :58`) pour un bouton maison. | `null` si le geste n'est pas permis |
| `ZCrudEditionScope` | `z_crud_edition_scope.dart:47` | `readOnlyOf` `:94` / `onEditOf` `:102` : une tuile sait si elle est en lecture seule et comment rouvrir l'édition. | — |
| `ZAppBarActionsBuilder` | `z_app_bar_actions_builder.dart:55` | Rend des `ZAppBarAction`, **jamais des widgets** : la conditionnalité sans perdre libellé, sémantique, cible tactile. | **Exclusif avec `actions`**, assertion posée dans `initState` |
| `ZAppBarActionsContext` | `:83` | ACL déjà restreinte à l'onglet actif, index, compte, corbeille, vacuité. | — |
| `ZExportPolicy` | `z_export_policy.dart:74` | `exporters` `:94`, `onExported` `:97`, `fileBaseName` `:101`. | `exporters` vide ⇒ **aucune entrée d'export** |
| `ZSelectionPolicy` | `z_selection_policy.dart:38` | `mode` `:60`, `showSelectAll` `:63`, `onReport` `:67`. | `multiple` / `true` / `null` |
| `ZRowTint` | `z_row_tint.dart:49` | Teinte **+ `semanticLabel`** : la couleur n'est jamais le seul canal. | — |
| `ZListTabsStore` | `z_list_tabs_store.dart:59` | Port : `loadTabIndex` `:65`, `saveTabIndex` `:69`, `loadScrollOffset` `:73`, `saveScrollOffset` `:78`. | Lecture tolérante : index hors bornes ⇒ repli ; store qui lève ⇒ traité comme absent |
| `ZInMemoryListTabsStore` | `:86` | Impl mémoire fournie. | — |
| `showZEntityHistory` | `z_history_sheet.dart:8` | Feuille de journal, date / opération / auteur + diff. | 🔴 **Le socle ne trie pas** : l'ordre antichronologique est une obligation de l'hôte. Entrée sans date **ignorée**. |
| `ZRowActionsMenu` | `z_row_action_menu.dart:101` | Menu d'actions de ligne prêt à poser. | — |
| `zMenuEntryOfRowAction` / `zMenuEntriesOfRowActions` | `:56` / `:81` | Convertit des `ZRowAction` en entrées `zcrud_menu`. | — |

### 1.3 Pièges mesurés — `zcrud_screen`

- 🔴 **`itemBuilder` est INERTE sous `ZListDataGridLayout`.** Dartdoc `z_crud_screen.dart:299-301` :
  « La grille de données n'a pas de tuile — elle rend des cellules — et n'invoque donc pas
  `itemBuilder` ». Les sous-types de `ZListLayout` sont dans le cœur :
  `z_list_layout.dart:98` (`DataGrid`), `:116` (`Builder`), `:175` (`Grid`), `:306` (`Custom`).
- 🔴 **`ZFilter.servedBySource` est une PROMESSE, pas une garantie.** Déclaré cœur
  `z_data_request.dart:137`, sauté à la ré-application `z_list_query.dart:137`. Devant un dépôt
  qui ne la sert pas — **ou sur la voie `ZCrudSource.items`, où il n'y a pas de source à qui
  adresser la promesse** — la clause ne filtre **rien**, sans erreur ni avertissement.
- 🔴 **`collapseStore`/`formId` : atteignables par `presentFormEdition`, PAS par `ZCrudScreen`.**
  GREP MONTRÉ : `grep -n 'collapseStore\|formId' z_crud_screen.dart` → **une seule ligne**, `:4352`,
  et c'est le commentaire qui explique l'absence.
- 🟡 **`readOnly` est déprécié** (`z_crud_screen.dart:210-214` et `:649-652`, « Sera retiré en 1.0 ») mais le paquet est **en 3.21.0** :
  soupçon d'annotation dont l'échéance est périmée — à ne pas lire comme un retrait imminent.
- 🟡 **En vue corbeille, le bouton de retour occupe le `leading`** : Material n'insère pas le bouton
  de menu du `drawer`, qui reste ouvrable **par glissement depuis le bord** seulement.

---

## 2. `zcrud_list` — le backend Syncfusion (4 canaux)

Barrel : `packages/zcrud_list/lib/zcrud_list.dart:25-29`. **Seule arête Syncfusion du graphe (AD-8).**
Injecté par `ZcrudScope.listRenderer` (cœur `zcrud_scope.dart:208`).

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZSfDataGridRenderer` | `z_sf_data_grid_renderer.dart:133` | **17 réglages** (`:197-364`) : le `SfDataGrid` derrière le port neutre. | ctor `:135` |
| `onLoadMore` | `:197` | Pagination incrémentale. | `null` |
| `headerRowHeight` | `:204` | Hauteur de l'en-tête. | — |
| `columnWidthMode` | `:216` | Répartition des largeurs (`ColumnWidthMode` ré-exporté, barrel `:25`). | `null` |
| `withOrderNumber` / `orderColumnHeader` | `:232` / `:239` | Colonne de numérotation. | `false` |
| `cellColorBuilder` | `:249` | Couleur de cellule pilotée par ligne + colonne. | `null` |
| `rowsPerPage` | `:264` | Pagination Syncfusion. | `null` |
| `copyCellOnLongPress` / `copiedMessageKey` | `:276` / `:283` | Copie d'une cellule à l'appui long + retour visuel par `zToast` **injecté**. | `false` |
| `swipeToRevealActions` / `swipeMaxOffset` | `:293` / `:300` | Actions révélées au balayage. | `false` |
| `stackedHeaders` | `:310` | En-têtes **empilés** (`ZSfStackedHeader`, `z_sf_grid_customization.dart:106`). | `const []` |
| `columnSizing` | `:320` | Dimensionnement par colonne (`ZSfColumnSizing`, `:145` — `width`, `minimumWidth`, `maximumWidth`, `widthMode`, `autoFitPadding`). | `const {}` |
| `allowColumnResizing` | `:330` | Redimensionnement par l'utilisateur. | `false` |
| `adaptiveRowHeight` / `maxRowHeight` | `:342` / `:346` | Hauteur de ligne adaptative bornée. | `false` |
| `ZSfCellStyle` (builder `:364`) | `z_sf_grid_customization.dart:33` | Style par cellule : fond, `TextStyle`, alignement, padding, `textAlign`, `maxLines`. | tous `null` |

**Piège.** Le barrel ré-exporte **un seul** type Syncfusion, `ColumnWidthMode`
(`zcrud_list.dart:25-26`), et le dit explicitement. Tout le reste (`SfDataGrid`, `DataGridRow`,
`GridColumn`) reste interne : un hôte qui voudrait un réglage non exposé n'a **aucune** voie
publique — il n'y a pas d'échappatoire « widget brut » sur ce renderer.

---

## 3. `zcrud_navigation` — la politique de présentation (23 canaux)

Barrel : `packages/zcrud_navigation/lib/zcrud_navigation.dart:44-55`. Le domaine est **pur-Dart**
(aucun import `package:flutter/…` dans `lib/src/domain/`).

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZEditionPresentation` | `domain/z_edition_presentation.dart:22` | Le mode en **enum** (`page`/`sheet`/`dialog`) — remplace les booléens `fullscreenDialog`/`dialog`/`isWebOrDesktop`. | — |
| `ZFormWeight` | `domain/z_form_weight.dart:14` | `light`/`heavy` — départage `expanded → dialog\|page`. | — |
| `ZPresentationPolicy` | `domain/z_presentation_policy.dart:53` | Dérive **PUREMENT** (sans `BuildContext`) un mode d'une `ZWindowSizeClass`. Non-`sealed` (AD-4). | `const ZPresentationPolicy()` |
| `ZPresentationResolver` | `:25` | Typedef pour surcharger la politique par une fonction. | — |
| `presentEdition` | `presentation/present_edition.dart:155` | **14 paramètres** (`:157-169`) : `builder`, `formWeight`, `policy`, `presenter`, `maxWidth`, `maxHeight`, `useSafeArea`, `barrierDismissible`, `isDismissible`, `chrome`, `forcedMode`, `sheetFrame`, `bodyFit`. Le maillon `largeur → breakpoint → politique → mode → surface`. | — |
| `forcedMode` | `present_edition.dart:167` | **Court-circuit TOTAL** : ni lecture de la classe de fenêtre, ni consultation de la politique (`:174-178`). | `null` |
| `ZFormPresenter` | `presentation/z_form_presenter.dart:39` | Port pluggable, **form-agnostique**. | — |
| `ZAdaptivePresenter` | `presentation/z_adaptive_presenter.dart:46` | Présentateur par défaut **pur-Flutter** — aucun `get`/`go_router`. | `const` |
| `ZAdaptivePresenterDefaults` | `:29` | Les valeurs de repli, lisibles. | — |
| `ZFormPresenterScope` | `presentation/z_form_presenter_scope.dart:25` | Seam de substitution du présentateur. | défaut `const ZAdaptivePresenter()` |
| `ZImplicitDismissControl` | `presentation/z_implicit_dismiss_control.dart:46` | Capacité **optionnelle** : contrôler les fermetures implicites. | — |
| `ZEditionChrome` | `presentation/z_edition_chrome.dart:192` | Titre `:210`, `submitLabel` `:214`, `discardLabel` `:217`, `onSubmit` `:221`, `onDiscard` `:225`, `submitController` `:229`, `formController` `:234`, `onConfirmDiscard` `:237`, `extraActions` `:253`, `showDragHandle` `:257`. | — |
| `ZEditionChromeMetrics` / `zEditionChromeMetricsOf` | `:89` / `:145` | Métriques du chrome, résolues depuis `ZcrudTheme`. | `ZEditionChromeReference` `:48` |
| `ZEditionScaffold` | `presentation/z_edition_scaffold.dart:67` | Le corps + le chrome + le mode, sans `presentEdition`. | — |
| `ZDiscardGuardHost` | `:385` | Garde d'abandon isolé du scaffold. | — |
| `ZEditionBodyFit` | `presentation/z_edition_body_fit.dart:56` | `intrinsic` / `scrollable`. | — |
| `ZSheetFrameSpec` / `ZSheetFrameMode` | `presentation/z_sheet_frame.dart:143` / `:80` | Feuille **contrainte/encadrée** : `mode`, `widthRatio`, `maxWidth`, `borderColor`, `borderWidth` (`:154-166`). | jeton `ZcrudTheme.editionSheetFrameMode` |
| `zSheetFrameModeFromToken` | `:203` | Jeton de thème → mode. | 🟡 jeton **inconnu** ⇒ `null` ⇒ la référence décide, jamais d'exception (AD-10) |
| `ZSheetFrameMetrics` / `zSheetFrameMetricsOf` | `:219` / `:290` | Métriques résolues. | `ZSheetFrameReference` `:101` |

### Pièges — `zcrud_navigation`

- 🔴 **« Inertie DÉCLARÉE » : tout paramètre est soit honoré sur une surface, soit déclaré inerte
  sur elle.** `useSafeArea` est **ignoré** en mode `page` ; `maxWidth`/`maxHeight` aussi
  (`z_form_presenter.dart:51-58`). La table complète n'est pas dans la dartdoc : elle est **mesurée**
  par `zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md`
  (garde `test/z_presenter_parameter_matrix_test.dart`).
- 🟡 **`unlessChrome` se résout dans `presentEdition`, pas dans le presenter** (`present_edition.dart:181-200`) :
  un hôte qui appelle un `ZFormPresenter` directement **n'obtient pas** ce collapse.
- 🟡 **Une implémentation TIERCE du port n'est tenue par aucune de ces gardes** — dit explicitement
  `z_form_presenter.dart:77-79`.

---

## 4. `zcrud_menu` — menus à déclencheur et contenu découplés (20 canaux)

Barrel : `packages/zcrud_menu/lib/zcrud_menu.dart:45-55`. **ZÉRO dépendance tierce.**
`lib/` **inchangé depuis le 2026-08-13**.

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZMenuEntry` | `domain/z_menu_entry.dart:36` | `id` `:81`, `label` `:84`, `icon` `:87`, `onSelected` `:90`, `disabledReason` `:93`, `isDestructive` `:96`, `permitted` `:99`. | ctor `:64` |
| — règle d'absence | `:99` + barrel `:14-22` | **Ni actionnable ni désactivée ⇒ ABSENTE** ; `permitted: false` ⇒ ABSENTE, sans que l'appelant traduise quoi que ce soit. | AD-4 |
| `ZMenuEntryIds` | `:150` | Identifiants canoniques (`delete`, `share`…). | — |
| `zVisibleMenuEntries` | `:194` | La règle d'absence, applicable seule. | — |
| `ZMenuTrigger` | `domain/z_menu_trigger.dart:20` | Déclencheur : `icon` `:51` **ou** `child` `:54` (`ZMenuTrigger.widget` `:39`), `semanticLabel` `:57` **requis**, `tooltip` `:60`. | — |
| `ZActionMenu` | `presentation/z_action_menu.dart:18` | > Un hôte qui veut un menu contextuel écrit `ZActionMenu(trigger:, entries:)` — au lieu d'un `PopupMenuButton` maison. | ctor `:33` |
| `ZContextMenuRegion` | `presentation/z_context_menu_region.dart:30` | Le même menu **sur une région** : `secondaryTap` `:76`, `longPress` `:79`. | — |
| `ZMenuRenderer` | `presentation/z_menu_renderer.dart:44` | Port : l'hôte branche SON paquet de menus. Non-`sealed`. | — |
| `ZDefaultMenuRenderer` | `presentation/z_default_menu_renderer.dart:39` | Repli Material seul, pleinement fonctionnel. | `const` |
| `ZGridMenuRenderer` | `presentation/z_grid_menu_renderer.dart:59` | Menu **en grille** : `columns` `:85`, `tileExtent` `:88`, `width` `:91`, `spacing` `:94`, `padding` `:97`. | `kZGridMenuColumns = 3` (`:53`) |
| `ZMenuScope` / `zResolveMenuRenderer` | `presentation/z_menu_scope.dart:34` / `:66` | Seam d'injection + résolution, repli `zFallbackMenuRenderer` (`:28`). | — |
| `ZMenuEntryTile` | `presentation/z_menu_entry_tile.dart:31` | Tuile d'entrée, `direction` `:57`, cible ≥ `kZMenuMinTapTarget = 48.0` (`:27`). | — |
| `zMenuPopupItems` / `zShowZMenuAt` / `ZMenuPanelEntry` | `presentation/z_menu_surface.dart:34` / `:67` / `:102` | Surfaces bas-niveau pour un renderer maison. | — |
| `ZMenuRequest` / `ZMenuContentBuilder` | `presentation/z_menu_request.dart:75` / `:29` | Ce que reçoit un renderer ; `select` `:98` applique déjà la règle d'absence (`zMenuSelectFor` `:52`). | — |

**Limite déclarée, pas un piège.** Barrel `:37-42` : un menu qui vit **dans le cœur** (le débordement
d'une barre d'actions par lot) **ne peut pas** être injecté via ce paquet — `zcrud_core` ne peut
dépendre d'aucun satellite (AD-1). Il faudrait déplacer la couture dans `ZcrudScope.menuRenderer`.

---

## 5. `zcrud_ui_kit` — page-shell, états, confirmation, toast (29 canaux)

Barrel : `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart:142-159`.
`ZPageScaffold` / `ZPageShellBody` / `ZSearchableAppBar` sont des **`part`** de
`z_page_shell.dart` (`:38-40`).

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZPageScaffold` | `presentation/z_page_scaffold.dart:46` | **29 champs** (`:89-240`). > Un hôte qui veut app-bar + recherche + onglets + tous les slots `Scaffold` écrit `ZPageScaffold(title:, tabs:, body:)`. **Un seul `Scaffold` construit** quel que soit le mode. | ctor `:52` |
| — slots pass-through | `:163-195` | `floatingActionButton`(+`Location`), `persistentFooterButtons`, `drawer`, `endDrawer`, `bottomNavigationBar`, `bottomSheet`, `backgroundColor`, `resizeToAvoidBottomInset`, `extendBody`, `extendBodyBehindAppBar`. | défauts `Scaffold` |
| — `aboveTabBar` / `aboveTabBarHeight` / `aboveTabViews` | `:139` / `:147` / `:151` | Bandeaux insérés autour de la `TabBar`. | `null` |
| `ZPageShellBody` | `presentation/z_page_shell_body.dart:36` | **19 champs.** La même valeur **sans posséder de `Scaffold`** — à préférer dès que l'hôte enveloppe son `Scaffold` (`PopScope`…) ou en aiguille plusieurs. | — |
| `ZSearchableAppBar` | `presentation/z_searchable_app_bar.dart:14` | App-bar recherchable `PreferredSizeWidget`, **état de recherche détenu**, rebuild granulaire, `Échap` ⇒ fermeture. Pour un app-bar **fixe** dans `Scaffold(appBar:)`. | — |
| `ZPageAppBarMode` | `domain/z_page_app_bar_mode.dart:14` | `fixed`/`floating`/`pinned`/`floatingPinned` — jamais un couple de `bool`. | — |
| `ZAppBarAction` | `domain/z_app_bar_action.dart:15` | Action **en données** : `icon` `:37`, `semanticLabel` `:43`, `onPressed` `:46`, `tooltip` `:49`, `isOverflow` `:53` ; `.widget` `:28`. | Une action non déclarée est **structurellement absente** |
| `ZAppBarSearchConfig` | `domain/z_app_bar_search_config.dart:16` | `onQueryChanged` `:29`, `hintLabel` `:32`, `initialQuery` `:35`, `hidesHostActions` `:41`. Le shell **détient** l'état. | — |
| `ZPageTab` | `domain/z_page_tab.dart:13` | `label` `:23`, `icon` `:26`, `contentBuilder` `:29`. | — |
| `gradientKey` | `z_page_scaffold.dart:100` | Dégradé d'app-bar résolu par le seam `ZcrudScope.gradientResolver`. | `null` ⇒ aucun dégradé (`z_page_shell.dart:551-553`) |
| `titleTextStyle` / `subtitleTextStyle` / `tabLabelStyle` / `tabUnselectedLabelStyle` | `z_page_scaffold.dart:204`, `:209`, `:234`, + `:238` | > Un hôte qui veut changer deux textes d'en-tête n'a plus à envelopper sa page dans un `Theme` réécrivant `AppBarTheme`/`TabBarTheme`. Priorité **paramètre > jeton `ZcrudTheme.pageHeader*` > défaut**. | `null` ⇒ **aucune** enveloppe de style n'entre dans l'arbre |
| `ZContentState` + `ZContentStateView` | `domain/z_content_state.dart:13` + `presentation/z_state_widgets.dart:180` | `idle`/`loading`/`empty`/`error`/`success` + aiguilleur `switch` exhaustif à replis sûrs. > Remplace les combinaisons `isLoading`/`hasError`/`isEmpty`. | `successBuilder` `:197` requis |
| `ZEmptyState` / `ZLoadingState` / `ZErrorState` | `z_state_widgets.dart:31` / `:75` / `:127` | Widgets d'état `const`, couleurs **dérivées du `ColorScheme`**, textes injectés, `Semantics`, ≥ 48 dp. | — |
| `ZConfirmDialog` + `showZConfirmDialog` | `presentation/z_confirm_dialog.dart:36` / `:129` | Retourne `Future<bool>`, labels via `MaterialLocalizations`, **sans** gestionnaire d'état. `title` est **optionnel** (`:51`). | `ZConfirmTone.neutral` (`domain/z_confirm_tone.dart:12`) |
| `ZDiscardChangesGuard` | `presentation/z_discard_changes_guard.dart:50` | > Un hôte qui veut « ne pas perdre la saisie » enveloppe son corps et passe `isDirty` (`:74`, canoniquement `ZFormController.isDirty`). **Rebuild ciblé** : seul le `PopScope` est reconstruit, jamais le `child`. | réutilise `showZConfirmDialog` en ton destructif |
| `ZToaster` + `ZToastSeverity` | `domain/z_toaster.dart:23` + `domain/z_toast_severity.dart:14` | Port de notification + sévérité en enum — remplace `showError`/`showSuccess`/`showInfo`. | — |
| `ZScaffoldMessengerToaster` | `presentation/z_scaffold_messenger_toaster.dart:31` | Impl par défaut pur-Flutter, couleur dérivée du `ColorScheme`, **icône + texte** (couleur jamais seul canal). | `const` |
| `ZToasterScope` + `zToast` | `presentation/z_toaster_scope.dart:23` / `:59` | Seam de substitution, repli sûr, jamais de throw (AD-10). | — |
| `ZAlphabetIndexBar` | `presentation/z_alphabet_index_bar.dart:39` | Index A→Z cliquable, `enableScrub` `:70`, jeu injectable (`kZDefaultAlphabet` `:30`). **Le widget émet la lettre ; l'appelant scrolle** (aucun `ScrollController` interne). | ≥ 48 dp (`:23`) |
| `ZCountBadge` | `presentation/z_count_badge.dart:43` | `count` `:60`, `semanticsLabel` `:67`, `child` `:74`, `onTap` `:79`, `tooltip` `:82`, `showZero` `:89`, `maxDisplayed` `:94`. | — |
| `zPageRoute` + `ZPageTransitionsBuilder` + `zSlideBeginOffset` | `presentation/z_transitions.dart:69` / `:97` / `:33` | Transitions **RTL-aware découplées de tout routeur** : le signe du slide s'inverse en RTL (AD-13). | `ZRouteTransition` `domain/z_route_transition.dart:22` |

### Piège mesuré — `zcrud_ui_kit`

🔴 **La COULEUR d'un `TextStyle` fourni est délibérément IGNORÉE** —
`_zResolveHeaderStyle` (`z_page_shell.dart:181`) délègue à `_zMetricsOnly` : **métriques seules**.
Pour le titre parce que la couleur doit rester héritée du `foregroundColor` ; pour les onglets parce
que `TabBar` dérive sa sélection de `labelStyle?.color` et qu'un style coloré **supprimerait** la
distinction sélectionné/non-sélectionné. Un hôte qui passe une couleur ici la verra **disparaître
sans erreur**. Neutralisation associée, mesurée et commentée `z_page_shell.dart:194-203` : ne régler
que `labelStyle` rendait les onglets non sélectionnés gras eux aussi.

---

## 6. `zcrud_responsive` — mesure et grilles (8 canaux)

Barrel : `packages/zcrud_responsive/lib/zcrud_responsive.dart:48-67`.
**Dernier changement `lib/` : 2026-08-25** (le plus récent du périmètre avec `zcrud_reorder`).

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZWindowSizeClass` | `domain/z_window_size_class.dart:49` | Classe de fenêtre **Material 3**, 3 paliers, seuils 600/840 (`ZWindowSizeThresholds` `:36`). | `of(context)` `:70` |
| `ZBreakpointValue<T>` | `domain/z_breakpoint_value.dart:35` | Valeur générique par palier **Bootstrap** (`xs` `:56` … `xl` `:68`), cascade mobile-first ; `.all` `:48`. | — |
| `computeCrossAxisCount` | `domain/compute_cross_axis_count.dart:42` | Nombre de colonnes borné, **clamp ≥ 1** (`:51`). Fonction pure. | — |
| `ZResponsiveLayout` | `presentation/z_responsive_layout.dart:38` | 3 builders `compact` `:51` / `medium` `:55` / `expanded` `:60`, cascade descendante, mesure **locale** par `LayoutBuilder`. | seuls `compact` requis |
| `ZAdaptiveGrid` | `presentation/z_adaptive_grid.dart:57` | Grille par largeur-min : `minItemWidth` `:122`, `spacing` `:126`, `runSpacing` `:129`, `itemHeight` `:133`, `aspectRatio` `:137`, `minColumns` `:140`, `maxColumns` `:143`, `padding` `:147`. | vide ⇒ `SizedBox.shrink()` |
| **`ZAdaptiveGrid.builder`** | `presentation/z_adaptive_grid.dart:89` | 🔴 **La grille VIRTUALISÉE, publique.** `itemCount` ≤ 0 ⇒ `shrink()` (AD-10). Exclusivité avec le ctor `children:` **par construction**, jamais par `assert`. | — |
| `ZReorderableAdaptiveGrid` | `presentation/z_reorderable_adaptive_grid.dart:96` | **16 champs.** La MÊME grille, réordonnable par appui long **OU par glissement immédiat depuis une poignée**, + actions sémantiques a11y, autoscroll de bord (`autoScrollEdgeExtent` `:166`, `autoScrollStep` `:169`), ordre **linéaire inter-lignes**. Zéro paquet tiers. | `moveBeforeSemanticLabel` `:137`, `moveAfterSemanticLabel` `:140` |
| `dragPreviewWrapper` | `z_reorderable_adaptive_grid.dart:184` | 🆕 L'aperçu flotté accepte **l'habillage déclaré par l'appelant**. | `null` |
| `ZDefaultReorderRenderer` | `presentation/z_default_reorder_renderer.dart:36` | Repli **zéro-dépendance** du port `ZReorderRenderer` (cœur), qui **honore sa capacité de poignée** : `autoScrollEdgeExtent` `:45`, `autoScrollStep` `:48`. | `const` |
| `ZReorderHandleScope` | `presentation/z_reorder_handle_scope.dart:21` | 🆕 Le seam par lequel un item **soumet** sa poignée : `position` `:39`, `width`/`height` `:42`/`:45`, `onDragUpdate` `:48`, `onDragStopped` `:51`, `buildFeedback` `:55`. | non exporté par le barrel — **interne** |

🔴 **Une affirmation de l'hôte est FAUSSE aujourd'hui.**
`iffd/lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart:68-69` écrit :
« `ZAdaptiveGrid.builder` (virtualisé) **n'est pas exposé** ». Il l'est :
`z_adaptive_grid.dart:89`, constructeur public d'une classe exportée par le barrel
(`zcrud_responsive.dart:61`). Livré par `de0ea0576` du **2026-07-17**, présent dès **v0.10.0** —
donc **antérieur** à la fenêtre 3.13→3.21 : c'est un canal *ancien* que l'hôte croit absent, pas un
canal récent. (L'hôte ajoute une décision propre — virtualisation désactivée, corpus ≤ 21 items —
qui reste valable ; c'est le constat d'absence qui ne l'est plus.)

---

## 7. `zcrud_reorder` — le renderer tiers, OPT-IN (3 canaux)

Barrel : `packages/zcrud_reorder/lib/zcrud_reorder.dart:32-36`.

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZPackageReorderRenderer` | `presentation/z_package_reorder_renderer.dart:82` | Renderer adossé à `reorderable_grid_view`, injecté par `ZcrudScope.reorderRenderer` : `dragStartDelay` `:128`, `dragEnabled` `:133`. | ctor `:84` |
| `kDefaultMoveBeforeLabel` | `:32` | Libellé de repli de l'action sémantique. | 🔴 `'Déplacer avant'` |
| `kDefaultMoveAfterLabel` | `:36` | Idem. | 🔴 `'Déplacer après'` |

### Pièges — `zcrud_reorder`

- 🔴 **Les deux libellés sont des constantes EN FRANÇAIS, non traduites** (`:32`, `:36`). Leur dartdoc
  les annonçait « localisés » ; corrigé en 3.3.1 (2026-08-21). **Une application multilingue doit
  fournir les siens.**
- 🔴 **Ce renderer n'honore PAS le contrat de poignée, et c'est mesuré** (CHANGELOG 3.19.0). Le châssis
  tiers réinstalle son propre reconnaisseur après tout déclencheur externe ; la seule configuration
  qui marcherait exigerait de **confisquer** le geste de l'item. La poignée y reste une **affordance
  visible**, le glissement s'amorce **par l'appui long**. **Pour une poignée qui amorce le geste :
  `ZDefaultReorderRenderer` de `zcrud_responsive`.** Deux tripwires figent le constat
  (`test/drag_handle_contract_test.dart`, 307 lignes ; `test/z_package_drag_preview_surface_test.dart`, 155 lignes).
- 🟡 **L'habillage d'aperçu de l'appelant n'est pas relayé ici** (il l'est dans `zcrud_responsive`) :
  le point d'extension tiers **remplace** le proxy `Material` au lieu de l'envelopper.

---

## 8. `zcrud_dnd` — glisser-déposer NATIF, OPT-IN (8 canaux)

Barrel : `packages/zcrud_dnd/lib/zcrud_dnd.dart:48-58`. **`lib/` inchangé depuis le 2026-08-11 :
le plus ancien du périmètre.**

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZNativeDropRegionRenderer` | `presentation/z_native_drop_region_renderer.dart:40` | > Un hôte qui veut recevoir un fichier glissé **depuis le système ou une autre app** écrit `ZcrudScope(dropRegionRenderer: const ZNativeDropRegionRenderer(), …)`. | `const` |
| `ZDropItemSource` | `domain/z_drop_kind_mapping.dart:26` | Abstraction d'un item déposé, testable sans plateforme. | — |
| `zBuildDroppedItems` | `:219` | Construit les `ZDroppedItem` neutres du cœur. | — |
| `zCandidateDropKinds` / `zSelectDropKind` / `zMimeTypeForFormats` | `:175` / — / `:124` | Résolution du type déposé. | `kZDropKindPriority` `:61` |
| `ZDropReadFailure` | `domain/z_drop_read_failure.dart:17` | Échec de lecture, `message` `:22`. | — |

**Deux avertissements portés par le barrel, à connaître AVANT d'ajouter la dépendance.**
① « Natif » **exclut** le réordonnancement interne — cela relève de `ZReorderRenderer`, et la
séparation est délibérée (`zcrud_dnd.dart:8-13`). ② `super_drag_and_drop` **embarque du code natif
(Rust) et télécharge des binaires précompilés à la construction** ; zcrud étant distribué en
dépendance git, **ce coût s'impose au build de l'application consommatrice** (`:15-21`).
Sans ce satellite, le port a un défaut zéro-dépendance (`ZNoDropRegionRenderer`, cœur) : la zone
rend son contenu inchangé et n'accepte aucun dépôt — **dégradé, jamais absent**.

---

## 9–11. Les trois paquets d'export (4 + 25 + 4 canaux)

Frontière de paquet **délibérée** : Dart n'ayant pas de dépendance optionnelle, seule une frontière
peut écarter le tableur. **Un hôte PDF-seul dépend de `zcrud_export_pdf`** et perd
`syncfusion_flutter_xlsio`, `syncfusion_officecore`, `jiffy` (`zcrud_export_pdf.dart:1-9`).
`zcrud_export` le **ré-exporte intégralement** (`zcrud_export.dart:33`) et n'ajoute que l'Excel.

### 9. `zcrud_export` — 4 canaux propres

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZExporter` | `data/z_exporter.dart:37` | Excel (`:51`) et PDF (`:70`) depuis une `ZExportTable`. Sorties `Uint8List` neutres. | `const` |
| `ZXlsxListExporter` | `data/z_xlsx_list_exporter.dart:37` | Réalise le port `ZListExporter` du cœur (`z_list_exporter.dart:77`) ⇒ branchable sur `ZExportPolicy.exporters`. | `const` |
| `ZCsvListExporter` | `data/z_csv_list_exporter.dart:42` | Idem en CSV : `delimiter` `:52`, `byteOrderMark` `:57`. | — |
| `ZExportApi` | `data/z_export_api.dart:11` | 🟡 **Marqueur d'arête AD-1 sans substance** : deux `static const String` (`version = '0.3.0'`, `coreApiVersion`). Aucune valeur consommateur. | — |

### 10. `zcrud_export_pdf` — 25 canaux

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZPdfExportOptions` | `data/z_pdf_export_options.dart:119` | `orientation` `:131`, `title` `:134`, `header` `:139`, `repeatHeader` `:142`, `latexEnabled` `:155`. Mise en page **anti-rognage**. | ctor `:122` |
| `ZPdfHeaderSpec` | `:48` | `logoBytes` `:61`, `logoWidth`/`Height` `:64`/`:67`, `organizationLines` `:71`, `subtitle` `:75`. | — |
| `ZPdfOrientation` | `:25` | Portrait / paysage. | — |
| `ZExportTable` | `data/z_export_table.dart:26` | `headers` `:65`, `rows` `:69` — table neutre. | — |
| `buildPdfBytes` | `data/z_pdf_exporter.dart:44` | Table → `Uint8List`. | — |
| `ZPdfListExporter` | `data/z_pdf_list_exporter.dart:45` | Port `ZListExporter` en PDF ; `effectiveOptions` `:71`. | `options` `:51` |
| `ZPdfCreationService` | `data/z_pdf_creation_service.dart:19` | **Assemblage images → PDF** (`buildImagesPdf` `z_pdf_document_builder.dart:41`). | `const` |
| `ZFileSaver` / `ZFileSaveResult` | `data/z_file_saver.dart:30` / `data/z_file_save_result.dart:12` | **Sauvegarde cross-platform** : impls `_io` `:20`, `_web` `:26` (via `package:web`, `dart:html` banni AD-12), `_stub` `:17`. `fileName` `:21`, `path` `:25`, `success` `:28`. | — |
| `ZExportedFile` | `data/z_exported_file.dart:14` | `bytes` `:23`, `fileName` `:26`, `mimeType` `:29`. | — |
| `ZFlashcardPdfTemplate` | `data/z_flashcard_pdf_template.dart:51` | 🔴 **Un gabarit PDF de flashcards complet** : `rasterizer` `:62`, `fontProvider` `:71`, `fallbackFontProviders` `:99`, `options` `:102`, `build` `:146`, pré-rastérisation LaTeX `:198`. | — |
| `ZFlashcardPdfInput` / `Card` / `Choice` / `Labels` | `data/z_flashcard_pdf_input.dart:59`, `:43`, `:103` | Entrée neutre : `typeKey` `:72`, `question` `:75`, `answer` `:78`, `isTrue` `:81`, `choices` `:84`, `hint` `:94`, `explanation` `:97`. Six types : `kFlashcardPdfType*` `:24-39`. | libellés injectés |
| `ZAnswerVisibility` | `data/z_answer_visibility.dart:12` | Réponses visibles ou non à l'export. | — |
| `ZLatexRasterizer` | `domain/z_latex_rasterizer.dart:39` | Port pur : `rasterize(latex, {logicalWidth})` `:41`. | impl dans `zcrud_export_ui` |
| `ZPdfFontProvider` | `domain/z_pdf_font_provider.dart:46` | Port de police TrueType : `loadFont` `:50`. | 🔴 cf. piège |
| `ZFontCoverage` | `domain/z_font_coverage.dart:45` | `parse` `:61`, `covers` `:131`, `coversAll` `:141`, `missingIn` `:151` : savoir **avant** l'export quels glyphes manquent. | — |

### 11. `zcrud_export_ui` — 4 canaux (les maillons de plateforme)

| Canal | `fichier:ligne` | Ce qu'il permet | Défaut |
|---|---|---|---|
| `ZFlutterMathLatexRasterizer` | `data/z_flutter_math_latex_rasterizer.dart:33` | Impl concrète du port pur : rendu `flutter_math_fork` hors écran → PNG. `pixelRatio` `:46`, `textColor` `:49`, `fontSize` `:52`. | — |
| `ZPdfShareService` | `data/z_pdf_share_service.dart:20` | `share` `:26`, `printDocument` `:36` — via `printing`, **confiné**. | `const` |
| `ZPdfPreview` | `presentation/z_pdf_preview.dart:26` | > Un hôte qui veut prévisualiser/imprimer/partager des bytes PDF écrit `ZPdfPreview(bytes:)`. `semanticsLabel` `:40`, `canPrint` `:43`, `canShare` `:46`. | — |
| `ZExportUiApi` | `data/z_export_ui_api.dart:12` | 🟡 Marqueur d'arêtes AD-1, sans substance. | — |

### Pièges — export

- 🔴 **Sans `ZPdfFontProvider`, tout Unicode hors WinAnsi est réduit en `?` à l'export** — arabe, grec,
  CJK, emoji. Dit sans détour par le barrel : `zcrud_export_pdf.dart:41-44`, « le fournir est le seul
  contournement possible, le gabarit n'exposant aucun autre point d'injection ».
- 🔴 **`latexEnabled` (`z_pdf_export_options.dart:155`) ne suffit pas** : sans `ZLatexRasterizer`
  injecté (donc sans `zcrud_export_ui`, ou sans impl maison), il n'y a rien pour rastériser.
  Deux canaux qui doivent être armés **ensemble**.
- 🟡 **`ZExportApi` / `ZExportUiApi` ne sont pas des capacités.** Ce sont des marqueurs d'arête AD-1
  portant deux `static const String`. Les compter comme de l'offre serait une erreur de lecture :
  **la substance est `ZExporter`, les exporteurs de liste et `ZFlashcardPdfTemplate`.**
- 🟡 **`ZFileSaver` sur le web** passe par `package:web` en compilation conditionnelle
  (`z_file_saver_web.dart`) : le stub `z_file_saver_stub.dart:17` est ce qui s'exécute là où ni
  `dart:io` ni `js_interop` ne sont disponibles — **soupçon** à vérifier avant de promettre une
  sauvegarde sur une cible exotique ; je n'ai pas mesuré son comportement de repli.

---

# Livré récemment, probablement inconnu de l'hôte

## Le cadrage exact de « récent »

Les tags 3.13 → 3.21 couvrent **une fenêtre de 28 heures** : v3.13.0 le 2026-08-24 09:13 UTC,
v3.21.0 le 2026-08-25 13:24 UTC. Mesuré sur `git diff --stat v3.12.0..HEAD` restreint aux 11
paquets : **1 974 insertions, 25 fichiers**, dont **seulement 3 paquets** ont un `lib/` modifié
(`zcrud_screen`, `zcrud_responsive`, `zcrud_reorder`) — les 8 autres n'ont que des bumps de
`pubspec.yaml`.

La fenêtre « 13 → 25 août » est bien plus large et bien plus riche. Activité réelle sur `lib/` :

| Paquet | dernier changement `lib/` | commits `lib/` depuis 13/08 | dont depuis 24/08 (v3.13+) |
|---|---|---|---|
| `zcrud_screen` | 2026-08-24 | **17** | 1 |
| `zcrud_ui_kit` | 2026-08-21 | 3 | 0 |
| `zcrud_list` | 2026-08-21 | 2 | 0 |
| `zcrud_navigation` | 2026-08-21 | 2 | 0 |
| `zcrud_reorder` | 2026-08-25 | 2 | 1 |
| `zcrud_responsive` | 2026-08-25 | 1 | 1 |
| `zcrud_menu` | 2026-08-13 | 1 | 0 |
| `zcrud_export` | 2026-08-13 | 1 | 0 |
| `zcrud_export_pdf` | 2026-08-13 | 1 | 0 |
| `zcrud_dnd` | 2026-08-11 | 0 | 0 |
| `zcrud_export_ui` | 2026-08-11 | 0 | 0 |

## A. Strictement 3.13 → 3.21 (24–25 août) — trois canaux

1. **`ZCrudScreen.beforeSubmit`** — `z_crud_screen.dart:671`, typedef `ZCrudBeforeSubmit<T>`.
   v3.14.0, 2026-08-24. Appelé **après validation, avant décodage**, sur la création, l'édition
   **et la duplication** ; `original` nul en création. Absent ⇒ chemin strictement inchangé (même
   instance de map). Une levée échoue proprement par le canal d'échec, **sans écriture**.
   🔴 L'hôte le sait déjà : `iffd/pubspec.yaml:512-515` le nomme comme ce qui « débloque CR-IFFD-103 ».
2. **La poignée qui amorce vraiment le geste** — `ZDefaultReorderRenderer`
   (`zcrud_responsive/…/z_default_reorder_renderer.dart:36`) + le seam `ZReorderHandleScope`
   (`z_reorder_handle_scope.dart:21`). v3.19.0, 2026-08-24/25. Un glissement parti de la poignée
   réorganise **sans appui long** ; l'appui long sur la cellule **reste** disponible. Corrigé au
   passage : une ligne portant un `TextField` ne fait plus lever l'aperçu (perte de l'ancêtre
   `Material` dans l'`Overlay`), et la zone sensible couvre **toute** la cible tactile — au défaut,
   seule sa part peinte l'était.
3. **`dragPreviewWrapper`** — `z_reorderable_adaptive_grid.dart:184`. v3.19.0. L'aperçu flotté
   accepte l'habillage déclaré par l'appelant. **Non relayé côté `zcrud_reorder`**, délibérément.

## B. 13 → 23 août — le gros du volume, et le plus invisible

**`zcrud_screen` a encaissé 17 releases en 12 jours, presque toutes issues de CR DODLP.** C'est
mécaniquement le corpus qu'un hôte IFFD ne peut pas connaître : il n'a jamais lu ces CR, et
`grep -rlnw ZCrudScreen /home/zakarius/DEV/iffd/lib/` rend **0**.

| Canal | `fichier:ligne` | Version / date |
|---|---|---|
| `ZCrudSource.readOnlyRepository` — dépôt en lecture seule, pagination et recherche serveur conservées | `z_crud_source.dart:93` | 1.0.0, 14/08 |
| `ZFilter.servedBySource` — la clause que seule la base sait trancher | cœur `z_data_request.dart:137` | 1.0.0, 14/08 |
| `steps` + `stepperConfig` — l'assistant à étapes atteignable depuis `presentFormEdition` | `present_form_edition.dart:249-250` | 1.1.0, 16/08 |
| `bodyBuilder` + `bodyFit` — corps composé par l'appelant, même contrôleur | `present_form_edition.dart:251-252` | 1.1.0, 16/08 |
| `entitiesInView` / `entitiesInViewListenable` / `entitiesSelectedOrInView` | `z_crud_screen_actions.dart:238`, `:266`, `:278` | 1.3.0, 16/08 |
| `drawer` / `endDrawer` sur l'écran assemblé, **relayés aussi à l'écran « accès refusé »** | `z_crud_screen.dart:826`, `:840` | 1.6.0, 16/08 |
| `collapseStore` / `formId` relayés par les présentateurs de formulaire | `present_form_edition.dart:255-256` | 1.7.0, 16/08 |
| `actionsBuilder` + `ZAppBarActionsContext` — actions d'app-bar dépendantes de l'état | `z_app_bar_actions_builder.dart:55`, `:83` | 2.1.0, 17/08 |
| `tabsStore` + `ZInMemoryListTabsStore` — **un offset par onglet**, pas un offset global | `z_list_tabs_store.dart:59`, `:86` | 2.1.0, 17/08 |
| `history` + `showZEntityHistory` — journal d'entité **avec diff entre versions** | `z_crud_screen.dart:684`, `z_history_sheet.dart:8` | 2.2.0, 17/08 |
| `ZTrashPolicy` porte une condition d'accès à la **vue** corbeille | cœur `z_trash_policy.dart:40` | 2.5.0, 18/08 |
| `title` optionnel sur la confirmation | `z_confirm_dialog.dart:51` | 2.4.0, 17/08 |
| `layout` : tous les layouts reçoivent `entityFor` ; `ZListCustomLayout.forEntity<T>` | cœur `z_list_layout.dart:306` | 3.8.0, 23/08 |
| Typographie d'en-tête atteignable sans réécrire le thème (4 créneaux + 4 jetons) | `z_page_scaffold.dart:204`, `:209`, `:234`, `:238` | 3.3.0, 21/08 |
| Libellés de repli du réordonnancement : dartdoc corrigée, ils **ne sont pas localisés** | `z_package_reorder_renderer.dart:32`, `:36` | 3.3.1, 21/08 |

## C. Ce qui n'est pas récent mais que l'hôte croit absent ou inaccessible

Trois constats d'absence de l'hôte que la mesure contredit **aujourd'hui**. Ils produiront du
« migrable » sans qu'aucun canal neuf soit en cause :

1. **`ZAdaptiveGrid.builder` est public** (`z_adaptive_grid.dart:89`), livré le 2026-07-17.
   L'hôte écrit « n'est pas exposé » (`study_tools_zcrud_adapter.dart:69`).
2. **Le blocage Syncfusion a disparu.** IFFD est en `^34.1.31` (`pubspec.yaml:141-149`) ;
   `zcrud_list` et `zcrud_export` demandent `^34.1.31`. Le commentaire `pubspec.yaml:292` décrit
   un état où IFFD était en `^32`.
3. **`zcrud_export` n'arrive plus transitivement** par `zcrud_flashcard` (grep négatif montré
   plus haut, RC=1) : c'est désormais un choix explicite, dans un sens comme dans l'autre.

## D. Zones où le socle offre une capacité que l'hôte réalise à la main — non consommée à 0 fichier

Ces rapprochements sont des **pistes mesurées**, pas des verdicts de migrabilité :

- **Export PDF de flashcards.** Le socle porte `ZFlashcardPdfTemplate`
  (`z_flashcard_pdf_template.dart:51`), `ZFlashcardPdfInput` (`:59` de `z_flashcard_pdf_input.dart`),
  `ZAnswerVisibility`, `ZPdfPreview`, `ZPdfShareService`. L'hôte a
  `iffd/lib/src/presentation/features/flashcards/widgets/export_flashcards_to_pdf.dart`,
  **390 lignes**, qui importe `printing` **directement** et `get` (GetX), et porte le drapeau QA
  `exportPdfOptions` avec ses options `withAnswers` / `withLatex` (`:55-56`).
  ⚠️ **Soupçon, non mesuré** : ce fichier importe aussi `dio` et `ai_repository`, ce qui suggère une
  génération **distante**. Si c'est le cas, `ZFlashcardPdfTemplate` (génération locale) n'est
  **pas** un remplaçant direct. À trancher par l'agent de confrontation, pas ici.
- **Menus contextuels.** 25 occurrences de `PopupMenuButton` chez l'hôte, `ZActionMenu` /
  `ZContextMenuRegion` / `ZMenuEntry` à **0** fichier.
- **Garde anti-perte de saisie.** 16 occurrences de `PopScope(` chez l'hôte,
  `ZDiscardChangesGuard` à **0** — alors que l'hôte consomme déjà `presentFormEdition` dans
  **29** fichiers, dont le garde d'abandon est justement l'un des trois apports annoncés
  (`iffd/pubspec.yaml:508-510`).
- **États de contenu.** 49 occurrences de `CircularProgressIndicator`, `ZContentStateView` /
  `ZEmptyState` / `ZLoadingState` / `ZErrorState` à **0**.
- **Confirmation.** 25 occurrences de `AlertDialog(`, `showZConfirmDialog` à **0**.
- **Page-shell.** 60 fichiers avec `Scaffold(`, 47 avec `AppBar(` ; `ZPageShellBody` et
  `ZSearchableAppBar` à **0**, `ZPageScaffold` à **1** (atteint indirectement par
  `folder_detail_zcrud.dart:111`, qui le nomme comme « l'ossature »).

## E. Ce que ce catalogue N'A PAS mesuré

À ne pas combler par déduction :

- Le **comportement à l'exécution** d'aucun de ces canaux : aucun test n'a été lancé, dans aucun
  dépôt (consigne). Les propriétés citées viennent des dartdoc, des CHANGELOG et du code lu.
- La **matrice d'inertie paramètre × surface** de `ZAdaptivePresenter` : elle vit dans
  `zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md`, je ne l'ai pas ouverte.
- Le comportement de repli de `ZFileSaver` hors `dart:io` et `js_interop`.
- Les **paramètres nommés** des paquets autres que les six assemblages comptés
  (`ZCrudScreen` 54, `presentFormEdition` 22, `ZPageScaffold` 29, `ZPageShellBody` 19,
  `ZSfDataGridRenderer` 17, `ZReorderableAdaptiveGrid` 16) : le décompte de 165 porte sur les
  symboles de premier niveau, pas sur les réglages.
