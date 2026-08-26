# Confrontation carte IFFD ↔ API réelle du socle zcrud
## Domaine « Administration · Authentification · Réglages · Accueil · Navigation »

> **Dépôts lus** : `/home/zakarius/DEV/iffd` (LECTURE SEULE, aucune écriture),
> `/home/zakarius/DEV/zcrud/packages/` (41 paquets), et pour comparaison inter-hôtes
> `/home/zakarius/DEV/{dodlp-otr,dlcfti-otr,lex_douane}` (lecture seule).
> **Écriture** : ce seul fichier.
> **Date** : 2026-08-25. **Aucun test lancé.** Méthode : `grep`, `sed`, `wc`, `diff`, `find`.
> Toute affirmation d'ABSENCE porte son grep négatif, montré en §7.

---

## 1. Deux constats de la carte que la mesure INFIRME

La carte a été revérifiée sur disque. Deux de ses conclusions structurantes sont fausses,
et toutes deux ferment à tort une porte grande ouverte.

### 1.1 « `ZAcl` (4 opérations) » — FAUX : `ZCrudAction` en porte **11**, exactement les mêmes

La carte écrit en §7 et §8.6 : *« Migrer `RessourceACL` (11 opérations) vers `ZAcl` (4 opérations)
demande un arbitrage : `archive`, `publish`, `clear`, `validate`, `history`, `copy`, `restore`
n'ont pas d'équivalent connu. »*

Mesuré — `packages/zcrud_core/lib/src/domain/ports/z_acl.dart:28-61` :

| `RessourceACL` (IFFD, `ressource_acl.dart:2-12`) | `ZCrudAction` (socle, `z_acl.dart:28-61`) |
|---|---|
| `read` | `view` |
| `create` | `create` |
| `update` | `update` |
| `delete` | `delete` |
| `copy` | `copy` |
| `restore` | `restore` |
| `archive` | `archive` |
| `publish` | `publish` |
| `clear` | `clear` |
| `validate` | `validate` |
| `history` | `history` |

**Onze contre onze, bijection totale.** Aucun arbitrage n'est requis : l'adaptateur
`RessourceACL → ZAcl` est un `switch` de onze branches.

Nuance réelle, elle : c'est l'enum `Crud` d'IFFD (`crud.dart:6-26`) qui compte **17** valeurs —
les 11 ci-dessus plus `move` et six opérations d'IA (`aiGenerate`, `aiSummary`, `aiMindMap`,
`aiFlashCard`, `aiExplain`, `aiChat`). Ces sept-là n'ont pas d'équivalent `ZCrudAction`
(§7 grep 12). Mais `RessourceACL` — la structure réellement persistée et testée — ne les porte
**pas** : elle s'arrête aux onze. L'arbitrage porte sur `Crud`, pas sur l'ACL.

### 1.2 « `zcrud_list` exige Syncfusion ^34, IFFD est en ^32 » — PÉRIMÉ : IFFD est en ^34.1.31

`iffd/pubspec.yaml:292` porte encore ce blocage en commentaire. Mesuré :

| | Contrainte |
|---|---|
| `iffd/pubspec.yaml:141-149` | `syncfusion_flutter_*: ^34.1.31` (neuf entrées) |
| `packages/zcrud_list/pubspec.yaml:36` | `syncfusion_flutter_datagrid: ^34.1.31` |

Le blocage documenté **n'existe plus**. `zcrud_list` et `zcrud_export` sont adoptables aujourd'hui.
Le commentaire du pubspec décrit un état antérieur au bump 32→34 côté hôte.

> Et le point qui compte davantage : **`ZCrudScreen` n'a pas besoin de `zcrud_list`.**
> `ZListGridLayout.forEntity<T>` (`zcrud_core/…/z_list_layout.dart:175,195`) rend une grille de
> cartes sans jamais toucher le backend Syncfusion. C'est exactement la forme que les six écrans
> d'administration d'IFFD composent à la main.

---

## 2. DÉJÀ MIGRÉ

Ce que l'hôte consomme réellement du socle dans ce domaine.

| # | Capacité / bloc | Canal zcrud consommé | Site hôte (vérifié) |
|---|---|---|---|
| A1 | Édition déclarative de 5 entités d'administration | `presentFormEdition` (`zcrud_screen`) | `…/administration/dialogs/auditeur_account_zcrud_edition.dart:42`, `annee_accademique_zcrud_edition.dart:50`, `app_user_role_zcrud_edition.dart:40`, `auditeur_iffd_zcrud_edition.dart:41`, `…/zcrud/ai_expert_zcrud_edition.dart:68` — **les 5 imports de `zcrud_screen` du dépôt entier** |
| A2 | Formulaire sans présentation (corps nu) | `ZFormOnly` / `ZFormOnlyController` | mêmes 4 fichiers (`show ZFormOnly, ZFormOnlyController, presentFormEdition`) |
| A3 | Déclaration des champs | `ZFieldSpec`, `ZValidatorSpec`, `ZFieldChoice`, `ZDateConfig`, `ZTextConfig`, `ZSubListConfig` (`zcrud_core`) | **53 `ZFieldSpec`** dans l'administration |
| A4 | Formulaire à étapes | `ZEditionStep` / `ZStepperEdition` | `annee_accademique_zcrud_edition.dart`, `ai_expert_zcrud_edition.dart` |
| A5 | Registre de widgets de champ + scope unique | `ZcrudScope`, `ZWidgetRegistry`, `ZFieldWidgetBuilder` | `presentation/shared/zcrud/z_iffd_field_registry.dart:78-207`, monté une fois en `main.dart:270` |
| A6 | Codec rich-text (préserve ~11 400 valeurs markdown) | `ZCodec` via `registerZMarkdownFields` (`zcrud_markdown`) | `z_iffd_field_registry.dart:19-23` |
| A7 | Téléphone international | `ZPhoneFieldWidget` (`zcrud_intl`) | `z_iffd_field_registry.dart:159-165` |
| A8 | Présentateur de sélection | `ZSmartSelectPresenter` (`zcrud_select`) | `z_iffd_field_registry.dart:53` |
| A9 | Sources de relation (`crudDataSelect` porté) | `ZRelationSourceRegistry` | `exam_zcrud_edition.dart:278`, `app_user_role_zcrud_edition.dart:117` |
| A10 | Ports de formatage / thème / dégradés | `ZNumberDisplayFormatter`, `ZDateDisplayFormatter`, `gradientResolver`, `iconResolver`, `colorKeyResolver` | `z_iffd_field_registry.dart:~380-392` |
| A11 | Présentation adaptative d'un formulaire | `presentEdition`, `ZEditionPresentation`, `ZSheetFrameSpec` (`zcrud_navigation`) | `utils/functions/forms_utils.dart:32-38` |
| A12 | Migration/codec legacy Firestore | `ZLegacyStudyMigrator`, `zcrud_firestore` | `data/migration/z_*.dart` (4 fichiers), `z_backed_folder_document_repository.dart:39` |
| A13 | Un seul portage réellement ALLUMÉ | `kAiRouterEditionUseZcrudDefault = true` | `…/ai_routers/zcrud/ai_router_zcrud_edition.dart:91` |

> ⚠️ **Réserve mesurée, et elle est décisive.** Le dépôt porte **35** constantes
> `k…UseZcrudDefault` : **1** vaut `true`, **34** valent `false` (§7 grep 13). Dans mon domaine,
> **6 sur 6 valent `false`** (`app_user_role_zcrud_edition.dart:61`, `exam_zcrud_edition.dart:77`,
> `auditeur_iffd_zcrud_edition.dart:61`, `annee_accademique_zcrud_edition.dart:74`,
> `auditeur_account_zcrud_edition.dart:58`, `ai_expert_zcrud_edition.dart:87`).
> **A1–A10 sont donc écrits et compilés, mais rien de ce qui s'affiche en administration ne les
> traverse.** 2 559 lignes de jumeaux zcrud cohabitent avec ~2 630 lignes de legacy actif.

---

## 3. MIGRABLE AUJOURD'HUI — la catégorie la plus lourde

**Le fait central : `ZCrudScreen` n'est appelé NULLE PART dans IFFD** (§7 grep 1 : aucun
`ZCrudScreen(` dans `lib/`), alors que `zcrud_screen` est une **dépendance directe déclarée**
depuis W-quelque-chose (`iffd/pubspec.yaml:524`). Les 4 428 lignes d'assemblage du socle sont
payées, téléchargées, compilées — et ignorées. Les six écrans de liste d'administration
(5 017 lignes) recomposent à la main ce que cet assemblage rend en une déclaration.

### 3.1 Le levier d'entrée : une ligne

`DynamicModel` (`iffd/lib/src/domain/models/dynamic_model.dart:3-6`) déclare
`final String? id` et un constructeur `const`. `ZEntity`
(`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:17-25`) déclare `const ZEntity()`
et `String? get id`, avec `isEphemeral` par défaut.

⇒ `abstract class DynamicModel extends ZEntity` est **une ligne** qui rend
**24 modèles IFFD** (`grep -c "extends DynamicModel"` = 24) éligibles à `ZCrudScreen<T>`,
`ZRepository<T>`, `ZListController<T>` et `ZCrudSource<T>`. C'est le verrou de tout §3.

### 3.2 Tableau

| # | Bloc hôte (carte) | API zcrud EXACTE (`fichier:ligne`) | Dépendance | Lignes hôte supprimées |
|---:|---|---|---|---:|
| M1 | Les 6 écrans de liste d'admin, composés `StreamBuilder` + `Wrap` + carte à la main (`accademic_years_page.dart` 692, `user_role_page.dart` 632, `auditeurs_pages.dart` 1 227, `ai_experts_page.dart` 1 330, `ai_routers_page.dart` 803, `exams_page.dart` 333) | `ZCrudScreen<T>` — `zcrud_screen/lib/src/presentation/z_crud_screen.dart:180` (61 paramètres, seuls `title` + `source` requis) | **déjà déclarée** (`pubspec.yaml:524`) | ~4 100 (estimé, cf. §5.2) |
| M2 | Le pont « je garde mes flux Riverpod / Firestore » | `ZCrudSource.items(List<T>, {onSave, onSoftDelete, onRestore, onPurge, isDeleted})` — `z_crud_source.dart:100` — voie « cohabitation », explicitement prévue pour un hôte dont les données arrivent déjà chargées | idem | 0 (c'est ce qui rend M1 **non bloquant** : aucune migration de dépôt requise) |
| M3 | §5.2 — état vide « premium », 5 sites au périmètre (`:154-297`, `:104-250`, `:237-387`, `:131-286`, `:141-285`) | rendu par `DynamicList` (`zcrud_core/…/dynamic_list.dart:186`, clés `list.empty` / `list.noResults`) | `zcrud_core` | **743** ⚠️ mais **régression visuelle** — voir X2 |
| M4 | §5.4 — onglets par filière + ACL par onglet + FAB conditionnel (`auditeurs_pages.dart:1112-1220`, `ai_experts_page.dart:1214-1330`) | `ZListTab(labelKey, baseFilters, itemFilter, acl, canCreate, defaultItemBuilder, titles, countOf)` — `zcrud_core/…/z_list_tab.dart:66-80` ; branché par `ZCrudScreen.tabs` (`z_crud_screen.dart:348`) et `_tabScopedAcl` (`:1499`, cascade **restrictive**) | `zcrud_core` | **226** |
| M5 | §5.4 — filtre `arrayContains` par onglet (`auditeurs_pages.dart:1119-1124`) | `ZFilterOp.contains` — `z_data_request.dart:33` — traduit en `arrayContains` par l'adaptateur (`zcrud_firestore/…/firebase_z_repository_impl.dart:721`) | `zcrud_core` | inclus M4 |
| M6 | §5.10 — 14 sous-classes de contrôleur VIDES + le filtre désaccentué réécrit **22 fois dans 12 fichiers** (`unaccentedText(x).replaceAll(" ","").toLowerCase().contains(q)`) | `ZListQueryPolicy.legacySearch()` — `zcrud_screen/…/z_list_query_policy.dart:167-171` — soit exactement `searchScope: allColumns` + `searchFolding: ZSearchFolding.diacriticsAndSpaces` (`zcrud_core/…/z_search_text.dart:44-49`, « casse abaissée, diacritiques repliés **et tous les blancs supprimés** ») | `zcrud_core` + `zcrud_screen` | **~40** au périmètre (~90 dépôt-wide) |
| M7 | §5.13 — bloc « Accès Restreint », 2 sites (`accademic_years_page.dart:77-125`, `ai_routers_page.dart:75-123`), **absent des 4 autres écrans d'admin** | `ZCrudScreen._buildAccessDenied` — `z_crud_screen.dart:3686-3701` : `ZPageScaffold` + `ZErrorState(icon: lock_outline)`, déclenché par `ZCrudAction.view` refusé (`:1509`, `:3712`), **avant toute interrogation de la source**, et **relaie `drawer`/`endDrawer`** pour ne pas faire un cul-de-sac | `zcrud_screen` | **~100**, et l'incohérence entre 6 écrans disparaît |
| M8 | L'ACL est posée à `ZAllowAllAcl` par défaut et **jamais surchargée** (`z_iffd_field_registry.dart:230`, `main.dart:270` n'en passe aucune) — donc `ZcrudScope.acl` ne gouverne rien | adaptateur `RessourceACL → ZAcl` : `abstract class ZAcl { bool can(ZCrudAction, {ZEntity? target, String? collectionId}); }` — `zcrud_core/…/z_acl.dart:101-104` ; **bijection 11↔11** (§1.1) ; primitives `ZRestrictedAcl` (`:210`) et `zRestrictAcl` pour la cascade par onglet | `zcrud_core` | ~30 écrites, mais **débloque M4, M7, M9, M10** |
| M9 | §5.9 — feuilles d'actions « Modifier / Supprimer » au périmètre (`exam_actions_dialog_widget.dart` 76, `app_user_role_actions_dialog_widget.dart` 56) — dont la **divergence mesurée** : le groupe d'utilisateurs se supprime **sans confirmation** (`:44-48`) | `ZRowAction` + `ZCrudScreen.rowActions` / `rowActionsPresentation` / `inlineActionLimit` / `longPressOwner` (`z_crud_screen.dart` params 43,55,56,57) et **`confirmDestructive = true` par défaut** (param 58) sur `showZConfirmDialog` (`zcrud_ui_kit/…/z_confirm_dialog.dart:129`, `title` optionnel depuis 2.4.0) | `zcrud_screen` | **132**, et la divergence est corrigée par construction |
| M10 | `popup_menu_helpers.dart` (**1 016 l**), `zcrud_menu` déclaré (`pubspec.yaml:340`) mais **importé une seule fois** dans tout le dépôt | `ZMenuEntry` / `ZActionMenu` / `ZMenuEntryTile` / `ZContextMenuRegion` / `ZGridMenuRenderer` / `ZMenuScope` (barrel `zcrud_menu/lib/zcrud_menu.dart:45-55`) ; conversion prête : `ZRowActionMenu` (`zcrud_screen/…/z_row_action_menu.dart`) | **déjà déclarée** | jusqu'à ~1 016 (hors périmètre pour l'essentiel) |
| M11 | §5.11 — `buildAppBar()` / `buildAppbar({tabs})` redéclarée dans le `build()` de 5 écrans ; + `DynamicSearcheableAppBar<C>` (372 l) | `ZPageScaffold(title, subtitle, gradientKey, search: ZAppBarSearchConfig, tabs, actions: List<ZAppBarAction>, floatingActionButton, drawer, bottomNavigationBar…)` — `zcrud_ui_kit/…/z_page_scaffold.dart` (377 l, 36 paramètres) ; `ZAppBarSearchConfig` — `…/z_app_bar_search_config.dart:16-26` (le shell **détient** l'état de recherche, `Échap` ferme) | **déjà déclarée** (`pubspec.yaml:440`) | **~112** au périmètre (+372 si l'app-bar maison est retirée) |
| M12 | §5.8 — calcul de grille responsive à la main, **6 sites au périmètre / 16 dans `lib/`**, en **deux variantes incompatibles** (`Get.width` vs `constraints.maxWidth`) | `computeCrossAxisCount({availableWidth, minItemWidth, minColumns, maxColumns, spacing, horizontalPadding})` — `zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart:42` (pure, ≥ 1 colonne garantie, jamais de `throw`) ; widget `ZAdaptiveGrid` / `.builder` — `…/z_adaptive_grid.dart:57,90` | ⚠️ `zcrud_responsive` est **en override seul**, à promouvoir en dépendance directe (`pubspec.yaml:682`) | **~42** au périmètre (~110 dépôt-wide) |
| M13 | §5.3 — palette de dégradés déclarée **4 fois**, 6 paires identiques à l'octet ; `0xFF667eea` apparaît **38 fois** dans 8 fichiers | `ZGradientResolver` + `ZGradientSpec{gradient, onGradient}` (`zcrud_core/…/z_gradient_resolver.dart:40-48`) — **déjà posé au scope** par IFFD (A10) mais non consommé par les écrans de liste ; `ZColorCycle` / `zColorCycleAt(palette, progress)` (`…/z_color_cycle.dart:75`) ; `ZPageScaffold.gradientKey` | `zcrud_core` | **~30** au périmètre |
| M14 | §5.5 — post-traitement CRUD d'un dialogue, **14 sites / ~266 l**, dont 5 au périmètre, et qui **diverge** (`exames_dialogs.dart` n'attribue pas d'`id`, `annee_accademique_modal_dialogs.dart:79` passe `merge: false`) | la voie de sauvegarde de `ZCrudScreen` : `onSave` → `source.onSave` → `repository.save` (`z_crud_screen.dart:_persist`, `:1516-1547`), avec **matérialisation de l'`id` par le repository** (invariant AD-14, `ZLocalStore.put`) — plus `beforeSubmit` (`ZCrudBeforeSubmit<T>`, livré en 3.14.0 le 2026-08-24) pour la transformation avant décodage | `zcrud_screen` | **~95** au périmètre |
| M15 | §4.2 — sérialisation manuelle : table `fromMap<T>` de **44 entrées** (`data_functions.dart:314-414`) qui rend `null` casté en `T` sur un type absent (`:412`), `toMap<T>` en `try/catch` vide (`:242`), 24 modèles à `toMap`/`fromMap`/`copyWith`/`props` écrits à la main (~160 l pour `AppUser` seul) | `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` (`zcrud_annotations`) + `zcrud_generator` (dev_dependency) qui émet `_$XxxFromMap`, l'extension `XxxZcrud` (`toMap`/`copyWith`), `$XxxFieldSpecs` et `registerXxx(ZcrudRegistry)` (`zcrud_generator/README.md:12-22`) | `zcrud_annotations` (déjà en override, `pubspec.yaml:577`) + `zcrud_generator` en dev_dependency (**à ajouter**) | ~220 (table) + le gros des ~3 800 l de plomberie des 24 modèles |
| M16 | §4.4 — **0 des 26 `StreamBuilder`** du périmètre ne teste `snapshot.hasError` ; une erreur Firestore rend une liste vide indiscernable d'une base vide | `ZListError(failure)` / `ZDisplayState` (`zcrud_core/…/dynamic_list.dart:193`), `ZErrorState(message, retryLabel, onRetry)` (`zcrud_ui_kit/…/z_state_widgets.dart:127-151`), et tout `ZRepository` rend `Either<ZFailure,T>` (`z_repository.dart:179-197`) | `zcrud_core` | 0 supprimée — **capacité gagnée** (⚠️ changement de comportement visible) |
| M17 | §4.3 — aucun cache local, aucune synchro hors ligne (ni Hive, ni `persistenceEnabled`, ni `connectivity`) | `ZOfflineFirstRepository<T>` (`zcrud_firestore/…/z_offline_first_repository.dart:57`) + `HiveZLocalStore<T>` (`…/hive_z_local_store.dart:68`) + `ZSyncOrchestrator` / `ZLwwResolver` (`zcrud_core/domain.dart:146-152`) | **déjà déclarée** (`pubspec.yaml:310`) | 0 — capacité gagnée |
| M18 | Aucun export des listes d'administration | `ZCrudScreen.export` + `ZExportPolicy{exporters, onExported, fileBaseName}` (`zcrud_screen/…/z_export_policy.dart:74-90`) ; `zcrud_list`/`zcrud_export` désormais compatibles (§1.2) | `zcrud_list`, `zcrud_export` (**à ajouter**, blocage Syncfusion levé) | 0 — capacité gagnée |
| M19 | `RessourceACL.history` est décoratif : aucun écran n'offre d'historique | `ZCrudScreen.history` + `ZHistorySheet` (`zcrud_screen/…/z_history_sheet.dart`) + port `ZEntityHistorySource` (`zcrud_core/domain.dart:108`) | `zcrud_screen` | 0 — capacité gagnée |
| M20 | Aucune sélection multiple, aucune action de masse, aucune corbeille | `ZCrudScreen.selection` (`ZSelectionPolicy`, `z_selection_policy.dart:38`), `batchActions` (`ZBatchAction`, `zcrud_core/…/z_batch_action.dart`), `trash` / `ZTrashMode` / `ZTrashPolicy` (`z_crud_screen.dart:105-115`, params 25-27) | `zcrud_screen` | 0 — capacité gagnée |
| M21 | `DynamicListScreen` (1 753 l) n'est plus utilisée que 2 fois ; `DynamicEditionScreen` (4 038 l) reste l'ancêtre actif | `ZCrudScreen` + `DynamicEdition` — le retrait suit mécaniquement la bascule des 6 flags du périmètre | — | ~2 630 (jumeaux legacy des 6 flags) |

### 3.3 Ce qui a changé récemment côté socle et qu'IFFD ne peut pas savoir

Trois canaux livrés **après** la dernière vague d'adoption d'IFFD, lus dans les CHANGELOGs :

| Canal | Livré | Où |
|---|---|---|
| `ZCrudScreen.beforeSubmit` (`(values, original) → map`, appelé après validation, avant décodage, sur création/édition/duplication) | **3.14.0 — 2026-08-24** | `zcrud_screen/CHANGELOG.md:6-9` |
| `ZTrashPolicy` porte une **condition d'accès** qui remplace le critère codé en dur `restore \|\| clear` | 2.5.0 — 2026-08-18 | `zcrud_screen/CHANGELOG.md` |
| `showZConfirmDialog` : `title` devenu **optionnel** — `title: null` ⇒ **aucun `AlertDialog.title` dans l'arbre**, aucun défaut inventé (c'est exactement le comportement de la confirmation legacy, dont le titre était commenté) | 2.4.0 — 2026-08-17 | `zcrud_ui_kit/CHANGELOG.md` |

---

## 4. MANQUE AU SOCLE

Preuve d'absence en §7. Pour chacun : la **forme** du canal, le **paquet** où il vivrait, et
**pourquoi l'hôte ne peut pas s'en passer**.

| # | Ce qui manque | Forme du canal | Paquet | Pourquoi l'hôte ne peut pas s'en passer |
|---:|---|---|---|---|
| X1 | **Tout le module agenda / rendez-vous / tâches** — `SfCalendar`, récurrence, listes de tâches | **Nouveau paquet d'entités + ports** : `ZAppointment`, `ZTaskList`/`ZTask`, `ZRecurrenceRule` (la seule brique existante est `ZReminderRecurrence`, `zcrud_exam/…/z_reminder_recurrence.dart:42`, et elle ne sert qu'un rappel d'examen) ; port `ZCalendarRenderer` sur le patron exact de `ZListRenderer`, avec le backend Syncfusion isolé dans un satellite `zcrud_workflow_syncfusion` | `zcrud_workflow` (+ satellite de rendu) | **C'est le plus gros gisement du monorepo, et il est TRIPLIQUÉ.** Mesuré : `appointment_editor.dart` fait **7 858 l** dans IFFD, **7 887 l** dans dodlp-otr, **7 903 l** dans dlcfti-otr — et un `diff` insensible aux blancs entre IFFD et dlcfti-otr rend **569 lignes divergentes**, soit **~93 % identiques**. Le module `workflow/` entier pèse **16 930 + 19 904 + 16 664 = 53 498 lignes** sur trois hôtes. À l'intérieur d'IFFD seul, ce fichier contient **trois classes qui éditent le même objet** (`PopUpAppointmentEditor` 703 l, `AppointmentEditorWeb` 3 552 l, `AppointmentEditor` 973 l — §5.1 de la carte, revérifié). Aucun autre bloc du dépôt n'a ce rapport coût/redondance. |
| X2 | **Seam d'état vide (et d'erreur) du listing** | `ZCrudScreen.emptyBuilder` / `DynamicList.emptyBuilder` (`WidgetBuilder`), ou un `ZListStateSpec{empty, noResults, error}` déclaratif ; à défaut, brancher `ZEmptyState(title, message, icon, actionLabel, onAction)` (`zcrud_ui_kit/…/z_state_widgets.dart:31-55`, **déjà écrit, jamais câblé**) sur `DynamicList` | `zcrud_core` (seam) + `zcrud_screen` (paramètre) | **Sans ce seam, M3 est une régression visible.** IFFD a investi **897 lignes** dans un état vide « premium » (cercle 180 dp à dégradé, deux anneaux, `ShaderMask`, bouton d'ajout à dégradé plein) sur 6 écrans ; `DynamicList` ne rend qu'un `_ZListMessageView` sur clé `list.empty` (`dynamic_list.dart:186`), **sans aucun point d'injection** (grep 5 : aucun `emptyBuilder`/`emptyView` dans `zcrud_core`, `zcrud_screen`, `zcrud_list`). L'hôte devrait donc choisir entre adopter `ZCrudScreen` et garder son identité visuelle. C'est le seul vrai frein à M1. |
| X3 | **Coquille d'application** : tiroir permanent ≥ seuil / escamotable, menu dérivé de la déclaration de routes, filtré par ACL | Modèle `ZNavDestination{labelKey, icon, requiredPermissions, children}` + `ZAppShell(destinations, body, breakpoint)` bâti sur `ZBreakpointValue`/`ZWindowSizeClass` (`zcrud_responsive`), rendu par `ZMenuRenderer` (`zcrud_menu`) ; la **lecture des métadonnées de route** (auto_route, go_router) reste à l'hôte, seul le modèle et le rendu montent | `zcrud_navigation` (modèle) + `zcrud_ui_kit` (coquille) | `ZCrudScreen` ne fait que **relayer** `drawer`/`endDrawer` comme un `Widget?` opaque (`z_crud_screen.dart` params 51-52, et jusque dans `_buildAccessDenied:3690-3691`) — le socle n'a **aucun** modèle de navigation (grep 6). IFFD porte **1 197 lignes** (`side_menu_drawer.dart` 415, `menu_item_widget.dart` 359, `side_menu_state.dart` 147, `menu_item_model.dart` 90, `app_scaffold.dart` 186) pour un tiroir auto-généré par récursion sur les routes, avec `checkAccess: [Type…]` filtré contre les permissions (`app_router.dart:32-46`). Chaque hôte réécrit ce bloc. |
| X4 | **Chaîne de gardes d'amorçage** : mise à jour forcée → présentation → connexion → mot de passe → année académique, **dans cet ordre strict** | `ZBootGate(gates: [ZGate(when: …, screen: …), …], child: …)` — une liste ordonnée de prédicats, chacun rendant son écran de blocage ; l'ordre est la donnée, pas le code | `zcrud_ui_kit` (ou un `zcrud_shell` neuf) | L'ordre EST l'invariant, et il est aujourd'hui codé en dur dans 60 lignes de `if` en cascade (`access_controlled_view.dart:76-124`, vérifié : `ForceUpdateScreen` → `PresentationPage` → `LoginPage` → `FirstLoginScreen` → `AccademicYearSelectionPage` → `child`). Le socle n'a aucun concept de garde (grep 7). Une inversion d'ordre est un bug silencieux qu'aucune garde de test ne peut attraper hors de l'hôte. `AccessControlledWrapper` + ses 4 classes = **310 l**, réécrites par hôte. |
| X5 | **Version minimale exigée / écran de mise à jour forcée** | Entité `ZRequiredVersion{minBuild, storeUrl}` + `ZVersionGate` (une garde de X4) + un port `ZAppVersionSource` (l'hôte fournit `packageInfo`) | `zcrud_ui_kit` | Aucun `ForceUpdate`/`requiredVersion` dans le socle (grep 8). IFFD compare sa version à `APP_SETTINGS/required_version` et rend `ForceUpdateScreen` (223 l). C'est de la mécanique d'application pure, identique d'un hôte à l'autre, et personne ne devrait la réécrire. |
| X6 | **Réglages persistés + mode de thème** | Port `ZSettingsStore` (get/set typés, backend `SharedPreferences`/`Hive` chez l'hôte) + `ZThemeModeController` (`ChangeNotifier`, `ValueListenable<ThemeMode>`, conforme AD-2) + assemblage `ZSettingsScreen(sections)` | port dans `zcrud_core`, contrôleur + écran dans `zcrud_ui_kit` | **Triple absence mesurée** : `ThemeMode` n'apparaît **nulle part** dans les 41 paquets (grep 9), `shared_preferences` n'est déclaré par **aucun** pubspec du socle (grep 10), et aucun symbole `ZSettings*` n'existe (grep 11). Côté hôte, il n'y a **aucun écran de réglages** non plus (carte §9 grep 4, revérifié) : trois providers persistés (`settings_providers.dart`, 106 l) et un `AppSettings` GetX (`app.settings.dart:36-59`). Le manque est **des deux côtés** — c'est donc un canal à créer, pas un portage. |
| X7 | **Carrousel d'accueil / onboarding** | `ZOnboardingCarousel(slides: List<ZOnboardingSlide>, onDone:)` — une garde de X4 | `zcrud_ui_kit` | Aucun `PageView` dans les 41 paquets (grep 12). `PresentationPage` (171 l) est une roue réinventée par hôte. Priorité basse (petit volume), mais c'est une garde de la chaîne X4 : sans elle, X4 est incomplet. |
| X8 | **Port d'authentification** | `abstract interface class ZAuthPort { Stream<ZAuthUser?> watchUser(); Future<ZResult<Unit>> signIn(...); signOut(); sendPasswordReset(String email); changePassword(...); }` + `ZLoginScaffold` (champs, validation, messages d'erreur traduits par code) ; adaptateur `zcrud_auth_firebase` isolant `firebase_auth` (AD-5) | port dans `zcrud_core`, écran dans `zcrud_ui_kit`, adaptateur satellite | **Zéro symbole d'authentification dans les 41 paquets** (grep 13). Et les **quatre hôtes** ont leur écran de connexion : `iffd/…/login_page.dart` 727 l + `first_login_screen.dart` 336 l, `dodlp-otr/…/login_screen.dart` 117 l + `first_login_screen.dart` 420 l, `dlcfti-otr/…/first_login_screen.dart` 424 l, `lex_douane/…/auth/login_screen.dart` 236 l — **2 260 lignes** pour le même parcours. Le contenu métier (qui a le droit d'entrer) reste à l'hôte ; la **plomberie** (états, erreurs traduites, changement de mot de passe imposé, réinitialisation) est identique. |
| X9 | **Sept opérations d'ACL sans équivalent** : `move` et les six opérations d'IA | Ouvrir `ZCrudAction` — soit par ajout de valeurs (`move`, et une famille `ai*`), soit par une échappatoire `ZCrudAction.custom(String)` ; `ZBatchActionKind.move` (`zcrud_core/…/z_batch_action.dart:62`) et `ZItemAction.move` (`zcrud_study/…/z_item_actions_menu.dart:78`) existent déjà comme **actions**, mais pas comme **droits** | `zcrud_core` | `Crud` d'IFFD porte 17 valeurs (`crud.dart:6-26`), `ZCrudAction` 11. `aiGenerate`/`aiSummary`/`aiMindMap`/`aiFlashCard`/`aiExplain`/`aiChat` sont **absents du socle entier** (grep 12). Sans eux, la matrice d'autorisations d'IFFD (`kIffdAclMatrixKind`, 262 l, servant **3 formulaires**) ne peut pas être gouvernée par `ZAcl` sur ces sept lignes. Impact **modéré** : `RessourceACL` — la structure persistée — n'en porte aucune (§1.1). |

---

## 5. RESTE À L'HÔTE

Logique métier IFFD, ou glue propre à ses choix techniques. Le socle ne porte pas de règle métier
(AD-16).

| # | Bloc | Lignes | Pourquoi il ne monte pas |
|---:|---|---:|---|
| R1 | Le catalogue des ressources délégables — `PermissionHelpers.generateCrudableObjects(accademicYears:, aiRouters:, tr:, baseCrudableObjects:)` et la matrice **6 filières × 2 cycles** (12 cartes d'autorisations par promotion) | `annee_accademique.dart` 483 + `app_user_permissions.dart` 256 | Le vocabulaire de délégation est propre à l'IFFD. Ce qui monte, c'est le **port** `ZAcl` (M8), jamais son contenu. |
| R2 | Les entités métier : `AnneeAccademique`, `AuditeurIffd`, `AppUserRole`, `AiExpert`, `IffdAiRouterModel`, `FiliereEtCycleIFFD` | ~2 100 | Entités d'application. Elles gagnent `@ZcrudModel` (M15), elles ne montent pas. |
| R3 | §5.7 — le pont `_presenterParLeSocle`, **4 sites, 219 l**, dont 3 contiennent le même appel exact précédé des mêmes deux `.streamAll().first` | 219 | La séquence « lire deux flux → calculer `withPermissions` → présenter → fusionner `{...depart, ...saisie}` » est de la glue IFFD (Riverpod + son catalogue). **Se factorise chez l'hôte** en un helper partagé dans `presentation/shared/zcrud/` — c'est du refactoring d'hôte, pas un canal manquant. |
| R4 | Le routage `auto_route` : `AppRouter` (270 l, dont **61 lignes commentées** décrivant des routes retirées) + `app_router.gr.dart` (2 601 l généré) | 2 871 | Le choix du routeur appartient à l'application (AD-15 : le code manager-spécifique vit dans le binding). Seul le **modèle** de destination monterait (X3). |
| R5 | Les **secrets et la porte dérobée** : l'e-mail codé en dur qui accorde l'administration (`app_user_permissions.dart:19`), l'identifiant client OAuth en dur (`login_page.dart:99-101`), les deux valeurs de repli d'App Check / reCAPTCHA (`env_config.dart:9,16`) | — | Rien de tout cela ne doit exister dans un paquet (règle « never de secret dans un package »). **Valeurs non citées ici** : elles vivent aux lignes indiquées. La porte dérobée est un défaut de sécurité de l'hôte à traiter chez lui, pas une capacité à migrer. |
| R6 | Les règles Firestore autorisant lecture **et écriture** sur tout document à tout utilisateur authentifié (`firestore.rules:5-7`) — toute l'ACL est côté client | — | Configuration de projet. Aucun socle ne peut y remédier ; à signaler avant d'investir dans M8, sous peine de gouverner une porte déjà ouverte. |
| R7 | Les deux schémas de chemins Firestore qui coexistent : `FirestorePaths` multi-tenant (`core/constants/firestore_paths.dart`, 36 l) **non branché**, et le repli `T.toString()` réellement utilisé (`FIREBASE_COLLECTION_NAMES` est vide, `databases.dart:3`) | 36 | Décision d'architecture de données propre à IFFD. Le socle offre `ZFirestorePathResolver`/`ZFirestorePathRule` (`zcrud_firestore/…/z_firestore_path_resolver.dart:64,134`) pour **exprimer** le choix — il ne le prend pas. |
| R8 | Code mort à ne pas migrer : `lib/agents_screens.dart` (535 l, non routé), `lib/cotation/` (772 l, orphelin), `workflow/screens/time_management_page.dart` (**1 octet**), `domain/models/reflector.dart` (entièrement commenté) | 1 307 | À supprimer, pas à porter. |

---

## 6. Chiffrage

### 6.1 Ce que l'adoption supprime — mesuré, bloc par bloc

| Réf. | Bloc | Sites au périmètre | Lignes |
|---|---|---:|---:|
| M3 | État vide « premium » | 5 | 743 |
| M4 | Onglets + ACL par onglet + FAB | 2 | 226 |
| M9 | Feuilles d'actions « Modifier / Supprimer » | 2 | 132 |
| M11 | En-tête à pastille dégradée | 4 | ~112 |
| M7 | Bloc « Accès Restreint » | 2 | ~100 |
| M14 | Post-traitement CRUD d'un dialogue | 5 | ~95 |
| M12 | Calcul de grille responsive | 6 | ~42 |
| M6 | Contrôleurs de recherche vides + filtre désaccentué | 4 + 4 | ~40 |
| M13 | Palettes de dégradés | 3 | ~30 |
| | **Sous-total blocs mesurés** | | **~1 520** |
| M21 | Jumeaux legacy des 6 flags du périmètre (`ai_experts_dialogs` 1 200, `auditeurs_iffd_modal_dialogs` 438, `app_user_role_dialogs` 374, `annee_accademique_modal_dialogs` 306, `exames_dialogs` 282, compte auditeur ~30) | 6 | **2 630** |
| | **Total supprimable, mesuré** | | **≈ 4 150** |
| M15 | Sérialisation manuelle remplacée par `@ZcrudModel` (table 220 + plomberie des 24 modèles) | 25 | ~220 mesurées + ~3 800 estimées |

### 6.2 Estimation au niveau de l'écran (méthode déclarée)

Les six écrans de liste d'administration totalisent **5 017 lignes**
(692 + 632 + 1 227 + 1 330 + 803 + 333, chiffres revérifiés par `wc -l`). Une déclaration
`ZCrudScreen` équivalente = le `ZCrudSource.items(...)`, la liste des `ZListTab`, le
`ZListGridLayout.forEntity` avec sa tuile de carte, la `ZListQueryPolicy.legacySearch()` et
l'ACL — soit de l'ordre de **60 à 150 lignes par écran**, donc **~900 lignes** au total,
la carte de promotion/auditeur/expert restant du code d'hôte à part entière.

⇒ **~4 100 lignes** d'écran, estimation, à ne pas confondre avec les 1 520 mesurées.
Le chiffre retenu pour l'objet structuré est le **mesuré**.

### 6.3 Le gisement inter-hôtes (X1)

| Hôte | Fichiers `workflow/` | Lignes |
|---|---:|---:|
| dodlp-otr | 32 | 19 904 |
| iffd | 39 | 16 930 |
| dlcfti-otr | 34 | 16 664 |
| **Total** | **105** | **53 498** |

Dont `appointment_editor.dart` : **7 887 / 7 858 / 7 903** lignes, **~93 % identiques** entre
deux hôtes (`diff` insensible aux blancs : 569 lignes divergentes sur ~7 880).

---

## 7. Greps négatifs — les preuves d'absence

**1. `ZCrudScreen` n'est appelé nulle part dans IFFD.**
```
$ cd /home/zakarius/DEV/iffd && grep -rn "ZCrudScreen(" lib --include='*.dart'
(aucune sortie)   RC=1
```
Les 4 occurrences de la chaîne `ZCrudScreen` dans `test/` sont des **titres de test et de la
prose** (`test/m0/formulaires_socle_tripwires_test.dart:207`,
`test/w9r/champ_masque_contribue_test.dart:7,104`, `test/m0/sous_liste_defauts_v2_test.dart:8`),
jamais une construction.

**2. Aucun des canaux de liste du socle n'est importé.**
```
$ grep -rn "package:zcrud_responsive" lib test --include='*.dart'   → RC=1
$ grep -rn "package:zcrud_list"       lib test --include='*.dart'   → RC=1
$ grep -rn "ZListQueryPolicy\|legacySearch" lib test --include='*.dart' → RC=1
$ grep -rn "ZListTab\|ZTabbedList"    lib test --include='*.dart'   → RC=1
$ grep -rn "ZRowAction"               lib test --include='*.dart'   → RC=1
$ grep -rn "showZConfirmDialog\|ZToaster\|ZEmptyState\|ZErrorState" lib --include='*.dart' → RC=1
```
`ZPageScaffold` et `ZAdaptiveGrid` n'apparaissent qu'en **commentaires** de deux fichiers du
domaine « dossiers » (`folder_detail_zcrud.dart:111,281` ; `study_tools_zcrud_adapter.dart:44,68,69,73,196,566`),
jamais construits dans mon périmètre.

**3. Aucun port de données du socle n'est consommé, et aucun cache local n'existe.**
```
$ grep -rn "ZRepository\|ZOfflineFirstRepository\|HiveZLocalStore" lib --include='*.dart' → RC=1
$ grep -rn "package:hive" lib --include='*.dart' → RC=1
```

**4. Aucun codegen zcrud dans IFFD.**
```
$ grep -rn "@ZcrudModel"             lib test --include='*.dart' → RC=1
$ grep -rn "package:zcrud_annotations" lib test --include='*.dart' → RC=1
$ grep -rn "ZcrudRegistry"           lib --include='*.dart' → RC=1
$ grep -n "zcrud_generator" pubspec.yaml → (aucune sortie)
```

**5. Aucun seam d'état vide dans le socle.**
```
$ cd /home/zakarius/DEV/zcrud/packages
$ grep -rn "emptyBuilder\|emptyView\|onEmptyAction\|emptyState:" --include='*.dart' \
    zcrud_core/lib zcrud_screen/lib zcrud_list/lib
(aucune sortie)   RC=1
```
`ZEmptyState` existe (`zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:31`) mais n'est
consommé que par `zcrud_chat` (une classe privée `_ZEmptyState` distincte) — jamais par
`DynamicList` ni `ZCrudScreen`.

**6. Aucun modèle de navigation d'application dans le socle.**
```
$ grep -rn "class ZAccessGate\|ZAppGate\|ZBootGate\|ZGuardChain" --include='*.dart' */lib/
(aucune sortie)   RC=1
$ grep -rln "Drawer\|NavigationRail\|ZSideMenu\|ZNavShell\|ZAppShell" --include='*.dart' */lib/
zcrud_ui_kit/lib/zcrud_ui_kit.dart
zcrud_ui_kit/lib/src/presentation/z_page_shell_body.dart
zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart
zcrud_study/lib/src/presentation/z_study_folder_detail.dart
zcrud_study/lib/src/presentation/z_study_session_scaffold.dart
zcrud_screen/lib/src/presentation/z_crud_screen.dart
```
Les six occurrences sont toutes le **paramètre** `drawer`/`endDrawer` relayé au `Scaffold`
(cf. `z_crud_screen.dart:34` : « la navigation de l'application, elle, reste à l'application »).
Aucun modèle de destination, aucun rendu de menu latéral, aucun filtrage par ACL.

**7. Aucune chaîne de gardes d'amorçage dans le socle.** — même grep que 6, `RC=1`.

**8. Aucune notion de version minimale / mise à jour forcée dans le socle.**
```
$ grep -rln "ForceUpdate\|requiredVersion\|ZVersionGate" --include='*.dart' */lib/
(aucune sortie)   RC=1
```

**9. `ThemeMode` n'apparaît dans AUCUN des 41 paquets.**
```
$ grep -rn "ThemeMode" --include='*.dart' */lib/
(aucune sortie)   RC=1
```

**10. `shared_preferences` n'est déclaré par aucun pubspec du socle.**
```
$ grep -rn "shared_preferences" --include='*.yaml' */pubspec.yaml
(aucune sortie)   RC=1
```

**11. Aucun symbole de réglages dans le socle.**
```
$ grep -rn "ZSettings\|ZAppSettings" --include='*.dart' */lib/
(aucune sortie)   RC=1
```

**12. Les sept opérations d'ACL manquantes.**
```
$ grep -rn "aiGenerate\|aiSummary\|aiMindMap\|aiFlashCard\|aiExplain" --include='*.dart' */lib/
(aucune sortie)   RC=1
$ grep -rn "ZCrudAction.move" --include='*.dart' */lib/
(aucune sortie)   RC=1
```
`move` existe comme **action**, jamais comme **droit** : `zcrud_core/…/z_batch_action.dart:62`
(`ZBatchActionKind.move`) et `zcrud_study/…/z_item_actions_menu.dart:78`.

**13. Aucune authentification, aucun onboarding, aucun agenda dans le socle.**
```
$ grep -rln "class ZAuth\|ZSignIn\|ZLogin\|ZCredential" --include='*.dart' */lib/ → RC=1
$ grep -rln "Onboarding\|ZCarousel\|ZIntro"             --include='*.dart' */lib/ → RC=1
$ grep -rln "PageView"                                   --include='*.dart' */lib/ → RC=1
$ grep -rln "class ZTask\|ZTodo\|ZTaskList"              --include='*.dart' */lib/ → RC=1
$ grep -rln "Appointment\|Recurrence\|SfCalendar\|ZAgenda\|ZCalendar" --include='*.dart' */lib/
zcrud_exam/lib/src/domain/z_reminder_recurrence.dart
zcrud_exam/lib/zcrud_exam.dart
zcrud_exam/lib/src/domain/z_exam.dart
```
Les trois seuls fichiers touchant la récurrence servent le **rappel d'un examen**
(`ZReminderRecurrence`, `ZExam.reminderRecurrence` `z_exam.dart:392`), pas un agenda.

**14. L'état de la bascule zcrud dans IFFD.**
```
$ grep -rn "UseZcrudDefault" lib --include='*.dart' | grep -c "= true\|= false"   → 35
$ grep -rcn "UseZcrudDefault = true"  lib --include='*.dart' | ... → 1
$ grep -rcn "UseZcrudDefault = false" lib --include='*.dart' | ... → 34
```
Au périmètre : 6 à `false`, 1 à `true` (`ai_router_zcrud_edition.dart:91`).

---

## 8. Ce qu'il faut retenir

1. **Le socle sait déjà faire l'écran d'administration, et IFFD ne le sait pas.**
   `zcrud_screen` est une dépendance directe déclarée depuis des semaines ; `ZCrudScreen` n'est
   construit **nulle part**. Les 4 428 lignes de l'assemblage sont téléchargées et compilées à
   chaque build pour rien, pendant que 5 017 lignes d'écran les recomposent à la main.
2. **Le verrou est d'une ligne.** `abstract class DynamicModel extends ZEntity` rend 24 modèles
   éligibles. `ZCrudSource.items` — écrit exactement pour ce cas — permet de garder les flux
   Riverpod/Firestore existants : **aucune migration de dépôt n'est requise** pour commencer.
3. **Deux constats de la carte fermaient à tort la porte** : `ZAcl` porte **11** actions et non 4
   (bijection exacte avec `RessourceACL`), et le blocage Syncfusion `^32 vs ^34` **n'existe plus**
   — IFFD est passé en `^34.1.31`.
4. **Un seul vrai frein technique à M1** : l'absence de seam d'état vide (X2). Sans lui, adopter
   `ZCrudScreen` échange 897 lignes d'identité visuelle contre un message générique. C'est le
   canal manquant le plus **rentable** du socle — quelques dizaines de lignes chez nous, 897
   chez l'hôte, et il débloque ~4 100 lignes d'écran.
5. **Le plus gros manque, et de loin, est `workflow/`** : 53 498 lignes sur trois hôtes, un
   éditeur de rendez-vous de ~7 900 lignes **triplé à 93 % d'identité**, zéro contact avec zcrud.
   Aucun autre chantier du monorepo n'a ce rapport coût/redondance.
6. **Le socle est écrit mais éteint** : 34 bascules sur 35 valent `false`. Le coût de migration
   déjà payé ne rend rien tant que la QA n'a pas eu lieu — et **douze de ces bascules changent la
   donnée écrite**, elles ne peuvent donc pas être groupées.

---

*Relevé produit sans exécuter de test, sans écrire une ligne hors de ce fichier,
sans citer aucune valeur de secret.*
