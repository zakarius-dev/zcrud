---
baseline_commit: 868438a73868c75a837e71f8cb443dd75ed24fa8
---

# Story 4.3 : Recherche (sans accents), filtres, tri & pagination curseur de la liste (branchement `ZDataRequest`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP puis lex_douane)**,
je veux **que la `DynamicList` sache RECHERCHER sans accents sur les champs `searchable` du schéma, FILTRER et TRIER via un `ZDataRequest` neutre poussé au repository, et PAGINER par CURSEUR (`ZCursor` opaque, boucle `nextCursor → startAfter`) — avec, en cas de curseur invalide OU de backend sans support curseur, un REPLI IN-MEMORY documenté qui trie/filtre/pagine en mémoire sans jamais crasher (AD-16), et le MAPPING explicite `empty` vs `noResults` (0 donnée sans filtre → `empty` ; 0 résultat après filtre → `noResults`)**,
afin que **la liste devienne réellement interrogeable (recherche/filtre/tri/pagination) de bout en bout, que le curseur et les prédicats restent NEUTRES dans le cœur (aucun type backend, aucun Syncfusion — SM-5), que l'app hôte ne subisse jamais un crash sur un backend sans curseur (repli in-memory prouvé), et que l'utilisateur voie un message DISTINCT selon qu'il n'y a « aucune donnée » ou « aucun résultat pour ce filtre »**.

**Contexte produit.** Troisième story d'**E4** (moteur `DynamicList`, dépend d'E2 ; couvre FR-6..FR-8 · AD-8, AD-11, AD-13, AD-16). Elle **branche** la liste sur les ports de données déjà construits en **E2-2** :

- **E2-2 (`review`, prouvé)** a posé `ZDataRequest` (filtres `List<ZFilter>` + tri `List<ZSort>` + `search: String?` + pagination `limit`/`startAfter: ZCursor?`), les enums `ZFilterOp{eq,neq,lt,lte,gt,gte,contains,isIn,isNull}` / `ZSortDirection{asc,desc}`, le curseur opaque neutre **`ZCursor`** (`List<Object?> values` + `String? id`), le contrat `ZRepository<T extends ZEntity>` (`watch(ZDataRequest)`, `getAll({request})`, `count({request})`, `watchAll()`, `softDelete`/`restore`), l'état domaine `ZDataState<T>` (`loading`/`loaded(items,nextCursor,hasMore)`/`empty`/`error`) et le port `ZAcl`. **Le repli in-memory a déjà été PROUVÉ** dans le fake de référence `_InMemoryZRepository` (E2-2 tâche 7 + remédiation M2/M3) : filtre → tri multi-clés → **saut par `values`** (comparaison positionnelle alignée sur `sorts`, `id` en départage) → `take(limit)`, **curseur invalide sans crash** (ancre introuvable → saut piloté par `values`, pagination au-delà de la fin → `[]`). E4-3 **productionise** cette logique de test en un moteur neutre RÉUTILISABLE.
- **E2-4 (`done`)** a posé `ZFieldSpec.searchable` (`bool`, défaut `false`) — la source de vérité des champs sur lesquels la recherche opère.
- **E4-1 / E4-2 (`done`)** ont posé `ZListRenderer`/`ZListRenderRequest{columns: List<ZListColumn>, rows: List<ZListRow>}`, `deriveColumns`, la `DynamicList` pilotée par **`ZListViewState`** (`ZListLoading`/`ZListEmpty`/`ZListNoResults`/`ZListError(ZFailure)`/`ZListReady(rows)`) et les **3 vues** (`dataGrid`/`builder`/`custom`). E4-2 **rend** `noResults` distinctement d'`empty` mais **a explicitement DÉFÉRÉ à E4-3 le CALCUL du filtre et la DÉCISION `empty` vs `noResults`** (mapping `ZDataState → ZListViewState`).

**Ce que E4-3 matérialise (le « chaînon manquant » interrogeable) :**
1. **Recherche SANS ACCENTS** — un helper de normalisation diacritique **pur, neutre** (`zFoldDiacritics`) + un prédicat de recherche sur les champs `searchable` du `ZFieldSpec[]` (repli des cellules `ZListRow.cells[field.name]` en texte, pliage diacritique + casse, `contains`). « café » ≈ « cafe », « e » matche « é ».
2. **Filtres / tri via `ZDataRequest`** — l'intention UI (terme de recherche, prédicats, clés de tri) est exprimée en `ZFilter`/`ZSort` portés par un `ZDataRequest` **poussé au repository** (chemin backend) **et** évaluable **en mémoire** (repli) sur `ZListRow.cells`.
3. **Pagination CURSEUR** — `ZDataRequest.startAfter` (`ZCursor`) + `limit` ; dérivation du `nextCursor` à partir de la dernière ligne de page (valeurs des clés de tri alignées sur `sorts` + `id`) ; **boucle `loadMore()` : `nextCursor → startAfter`**, accumulation des pages, `hasMore`.
4. **Cas d'erreur (AD-16)** — **curseur invalide** OU **backend sans support curseur** → **repli in-memory documenté** (filtre/tri/saut/take en mémoire, réutilise la logique E2-2) — **PAS de crash**.
5. **Mapping `empty` vs `noResults`** (déféré d'E4-2) — 0 donnée sans filtre/recherche actif → `ZListEmpty` ; 0 résultat **avec** filtre/recherche actif → `ZListNoResults`.

**Frontière (NE PAS déborder).** E4-3 est **HEADLESS côté UI** : elle fournit la LOGIQUE (normalisation, moteur in-memory, contrôleur d'état exposant un `ValueListenable<ZListViewState>`) et **réutilise telles quelles** les 4 vues d'état d'E4-2 — **aucun nouveau widget d'affichage**, la boîte de recherche/les contrôles de filtre étant fournis par l'app (qui appelle `controller.setSearch(...)`/`setFilters(...)`). Les **actions ligne + `ZAcl`**, la **sélection multiple**, la **corbeille** (soft-delete/restore) et la **statefulness de la grille (L2 : `DataGridSource` mémoïsée / `StatefulWidget`)** sont **E4-4**. Les **sous-listes/relations & onglets** sont **E4-5**. Voir la section **Frontière** détaillée.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **Normalisation diacritique neutre** `zFoldDiacritics(String) → String` (pur-Dart, table Latin documentée + minuscule) + prédicat `zMatchesSearch(...)` — dans le cœur, réutilisable (l'adaptateur Firestore E5 pourra s'y référer).
- ✅ **Moteur in-memory neutre** `zApplyListRequest(List<ZListRow> rows, ZDataRequest request, {required List<ZFieldSpec> schema}) → ZListPage` : applique **filtres** (`ZFilterOp`) sur `cells`, **recherche** sans accents sur les champs `searchable`, **tri** multi-clés (`ZSort`, direction), **saut curseur** (`startAfter`) et `take(limit)`, et **dérive** `nextCursor`/`hasMore`. Productionise le repli prouvé en E2-2.
- ✅ **`ZListPage`** : value object neutre `{List<ZListRow> rows, ZCursor? nextCursor, bool hasMore}` (`==`/`hashCode`).
- ✅ **`ZListController<T extends ZEntity>`** (`ChangeNotifier`, expose `ValueListenable<ZListViewState> state`) : détient le `ZDataRequest` courant, méthodes `setSearch`/`setFilters`/`setSort`/`loadMore`/`refresh`/`dispose`, mappe le résultat → `ZListViewState` (dont **`empty` vs `noResults`**), gère la **pagination curseur** et le **repli in-memory** (AD-16). Réactivité **Flutter-native** (AD-2/AD-15) — aucun gestionnaire d'état.
- ✅ **`ZListPaginationMode { backendCursor, inMemory }`** : sélecteur de stratégie de pagination (backend curseur natif vs repli in-memory total).
- ✅ **Mapping `empty` vs `noResults`** (déféré d'E4-2) câblé dans le contrôleur.
- ✅ Exports du barrel + docstrings d'origine/frontière.
- ❌ **Pas** de nouveau **widget d'affichage** (boîte de recherche, chips de filtre, bouton « charger plus » : fournis par l'app ; l'app câble `ValueListenableBuilder<ZListViewState>` → `DynamicList(state:)`, ou nos vues E4-2). E4-3 = **logique**, pas chrome.
- ❌ **Pas** d'**implémentation Firestore** du curseur (`query.startAfter([...])`/`Filter`) → **E5** `zcrud_firestore`. E4-3 pousse un `ZDataRequest` neutre et sait **replier en mémoire**.
- ❌ **Pas** d'**actions ligne / `ZAcl` / sélection multiple / corbeille** → **E4-4**. Le port `ZAcl` existe (E2-2) mais n'est **pas** consommé ici.
- ❌ **Pas** de traitement de la **statefulness de la grille (L2)** — la `DataGridSource` reste recréée par build (déféré E4-4). E4-3 ne touche **pas** `ZSfDataGridRenderer`.
- ❌ **Pas** de **sous-listes/relations/onglets** → **E4-5**.
- ❌ **Pas** de **formatage locale-aware** des nombres/dates/booléens (déféré d'E4-2) : **hors périmètre recherche/tri** (le tri compare les **valeurs brutes**, pas leur rendu ; la recherche plie le `toString` brut). Reste déféré (hook de format / labels) — **documenté**, non implémenté ici.
- ❌ **Ne PAS** toucher `sprint-status.yaml` (orchestrateur). **Ne PAS** ajouter de dépendance (`package:collection`/`intl`/backend/état) — rester `zcrud_core` out-degree 0 (AD-1).
- ❌ **Ne PAS** importer/tirer `zcrud_list`/Syncfusion dans le nouveau code (SM-5).

## Acceptance Criteria

> Tous les ACs sont **testables** : unit `flutter_test` (helpers + moteur purs) et widget `flutter_test` (contrôleur → `ValueListenableBuilder` → `DynamicList`, via un **fake `ZRepository` avec/sans curseur**). Les enjeux headline : **recherche sans accents**, **repli in-memory sans crash** (AD-16) et **mapping `empty`/`noResults`**.

1. **AC1 — Normalisation diacritique NEUTRE et PURE (recherche sans accents).** Un helper top-level pur `String zFoldDiacritics(String input)` (dans `packages/zcrud_core/lib/src/domain/data/z_search_text.dart`) retourne une forme **repliée** : minuscule + suppression des diacritiques Latin courants via une **table documentée** couvrant au minimum le français et les langues latines usuelles (`à â ä á ã å → a`, `ç → c`, `è é ê ë → e`, `ì í î ï → i`, `ñ → n`, `ò ó ô ö õ → o`, `ù ú û ü → u`, `ý ÿ → y`, `œ → oe`, `æ → ae`, `ß → ss`, + variantes majuscules). **Pur-Dart** : aucun `BuildContext`, aucun widget, aucun `dart:ui`, aucune dépendance (pas de `package:intl`), déterministe (même entrée → même sortie), ne lève jamais (chaîne vide → chaîne vide). Testable : `zFoldDiacritics('Café')=='cafe'`, `zFoldDiacritics('ÉÈÊË')=='eeee'`, `zFoldDiacritics('Œuvre')=='oeuvre'`, idempotence sur une chaîne déjà repliée.

2. **AC2 — Prédicat de recherche SANS ACCENTS sur les champs `searchable`.** Un prédicat pur `bool zMatchesSearch(ZListRow row, String term, {required List<ZFieldSpec> schema})` (même fichier ou `z_list_query.dart`) : (a) `term` vide/`null`/blanc → **match tous** (`true`) ; (b) sinon, replie le `term` (`zFoldDiacritics`) et teste `contains` sur le texte replié de **chaque champ `searchable == true`** du schéma (valeur brute `row.cells[field.name]` coercée en `String` — `null → ''`, `Iterable →` éléments joints — puis pliée). Un champ **non** `searchable` n'est **jamais** interrogé. Testable : schéma avec `name`(searchable) + `code`(non-searchable) ; recherche `'e'` matche une ligne dont `name=='Élève'` ; recherche `'cafe'` matche `name=='Café'` ; une valeur présente uniquement dans `code` (non-searchable) **ne matche pas**.

3. **AC3 — Filtres via `ZDataRequest`/`ZFilter` appliqués (tous les `ZFilterOp`).** Le moteur applique les `request.filters` (conjonction) sur `row.cells[filter.field]` pour **chaque** `ZFilterOp` : `eq`/`neq` (égalité), `lt`/`lte`/`gt`/`gte` (comparaison `Comparable`), `contains` (sous-chaîne repliée **ou** appartenance d'élément si la cellule est `Iterable`), `isIn` (`value` est une `List`, appartenance), `isNull` (cellule `== null`). Une comparaison sur des types **non comparables** ne lève pas (retombe sur « ne matche pas », désérialisation défensive AD-10). Testable : jeu de lignes filtré par chaque opérateur → sous-ensemble attendu ; opérateur sur valeur incompatible → 0 crash.

4. **AC4 — Tri via `ZDataRequest`/`ZSort` appliqué (multi-clés, direction).** Le moteur trie par `request.sorts` **dans l'ordre** (1re clé, puis départage par la 2e, etc.), en respectant `ZSortDirection.asc`/`desc`, sur les **valeurs brutes** `row.cells[sort.field]` (comparaison `Comparable`, `null` ordonné de façon **stable et documentée** — p. ex. `null` en dernier). Le tri est **stable** (deux lignes égales conservent l'ordre d'entrée). **Aucun formatage locale-aware** n'intervient dans la comparaison (les valeurs brutes sont comparées ; le rendu locale-aware reste déféré). Testable : tri `age asc` puis tie-break `name asc` ; `age desc` ; stabilité sur clés égales.

5. **AC5 — Pagination CURSEUR : `ZListPage` + dérivation `nextCursor` + boucle `loadMore`.** Le moteur produit un `ZListPage{List<ZListRow> rows, ZCursor? nextCursor, bool hasMore}` : après filtre+recherche+tri, il **saute** au-delà de `request.startAfter` (comparaison positionnelle par `ZCursor.values` alignées sur `sorts`, `id` en départage — logique E2-2) puis prend `request.limit` lignes (ou tout si `limit == null`). `nextCursor` est **dérivé** de la **dernière** ligne prise (`values` = valeurs des clés `sorts` de cette ligne, `id` = `row.id`) **ssi** il reste des lignes après (sinon `null`) ; `hasMore = nextCursor != null`. Le `ZListController` réinjecte `nextCursor` dans `ZDataRequest.startAfter` lors de `loadMore()` et **accumule** les lignes. Testable : N=5 lignes, `limit:2`, `sorts:[age asc]` → page 1 (2 lignes, `hasMore:true`, `nextCursor` non nul) ; `loadMore()` (startAfter=nextCursor) → page 2 (2 lignes) ; `loadMore()` → page 3 (1 ligne, `hasMore:false`, `nextCursor:null`) ; l'accumulé = les 5 lignes triées, sans doublon ni trou.

6. **AC6 — Repli IN-MEMORY sur curseur invalide / backend sans curseur (AD-16), SANS crash.** Deux déclencheurs, un même repli neutre : **(a) backend sans curseur** — `ZListPaginationMode.inMemory` : le contrôleur récupère le jeu **non paginé** (`repository.getAll(ZDataRequest(filters,sorts,search))` ou `watchAll()`), projette en `ZListRow`, puis **pagine entièrement en mémoire** via `zApplyListRequest` ; **(b) curseur invalide en mode `backendCursor`** — si le repository renvoie un échec lié au curseur (`Left(ZFailure)`), le contrôleur **bascule** sur le repli in-memory pour cette requête **au lieu de propager un crash/une erreur fatale** (documenté AD-16). De plus, un `ZCursor` dont l'**ancre est introuvable** (`values`/`id` ne correspondant à aucune ligne) est géré **gracieusement** par le moteur (saut piloté par `values`, pagination au-delà de la fin → `[]`) — **jamais** d'exception (réutilise le comportement prouvé E2-2 M2/M3). Testable : fake `ZRepository` **sans** honorer `limit`/`startAfter` (mode `inMemory`) → pagination correcte en mémoire ; fake renvoyant `Left(ServerFailure)` sur curseur → contrôleur en `ZListReady` via repli (pas `ZListError`), sans exception ; `ZCursor(values:[9999], id:'absent')` → page vide, 0 throw.

7. **AC7 — `ZListController` : cycle de requête + `ValueListenable<ZListViewState>` (réactivité Flutter-native, AD-2/AD-15).** `ZListController<T extends ZEntity>` (`ChangeNotifier`) expose `ValueListenable<ZListViewState> get state` et :
   - `setSearch(String? term)`, `setFilters(List<ZFilter>)`, `setSort(List<ZSort>)` → reconstruisent le `ZDataRequest`, **réinitialisent** la pagination (`startAfter=null`, accumulé vidé) et **re-interrogent** ;
   - `loadMore()` → si `hasMore`, `startAfter=_nextCursor`, page suivante **appended** ;
   - `refresh()` → relance la requête courante ; `dispose()` → annule l'abonnement au flux et libère le `ValueNotifier`.
   Le contrôleur **n'importe AUCUN** gestionnaire d'état (ni `zcrud_list`/Syncfusion) — seulement `package:flutter/foundation.dart` (`ChangeNotifier`/`ValueListenable`/`ValueNotifier`) + types `zcrud_core`. Il pousse le `ZDataRequest` au `repository` (`watch`/`getAll`) et projette `T → ZListRow` via un `ZListRow Function(T) toRow` fourni. Testable : un `ValueListenableBuilder<ZListViewState>` alimenté par le contrôleur reflète chaque transition (`loading → ready → …`) ; `setSearch` déclenche une nouvelle émission ; `dispose()` n'émet plus.

8. **AC8 — Mapping `empty` vs `noResults` (déféré d'E4-2, TRANCHÉ ici).** Le contrôleur mappe le résultat → `ZListViewState` : échec (non replié) → `ZListError(failure)` ; en cours → `ZListLoading` ; accumulé **non vide** → `ZListReady(rows)` ; accumulé **vide** → **`ZListNoResults` SI une recherche/un filtre est actif** (`request.search` non vide **ou** `request.filters` non vide), **sinon `ZListEmpty`**. Le discriminant est la **présence d'un filtre/recherche actif**, pas la taille du jeu sous-jacent (décision tranchée ; cas-limite « filtre actif + jeu total aussi vide → `noResults` » documenté). Testable : jeu non vide + `setSearch('zzz')` (0 match) → `ZListNoResults` (pas `ZListEmpty`) ; jeu vide + aucun filtre → `ZListEmpty` ; jeu vide + filtre actif → `ZListNoResults`.

9. **AC9 — SM-5 / neutralité préservés (AD-8, AD-1).** Tous les nouveaux fichiers de `zcrud_core` (`z_search_text.dart`, `z_list_query.dart`, `z_list_controller.dart`) importent **uniquement** `package:flutter/foundation.dart` (pour `ChangeNotifier`/`ValueListenable`/`@immutable`) + types `zcrud_core` — **zéro** `package:syncfusion`, **zéro** `cloud_firestore`/`firebase`/`hive`, **zéro** gestionnaire d'état, **zéro** dépendance ajoutée (`pubspec.yaml` inchangé ; out-degree 0 préservé). Les gardes `presentation_purity_test`/`no_heavy_file_dep_test`/`domain_purity_test` restent **vertes** ; le **test de graphe SM-5** de `zcrud_list` reste **vert** (`ZSfDataGridRenderer` **non modifié** demeure la seule arête Syncfusion). Le contrôleur/le moteur/la normalisation se testent **sans** importer `zcrud_list`.

10. **AC10 — Barrels, exports & vérif verte.** Les nouveaux types publics (`zFoldDiacritics`, `zMatchesSearch`, `zApplyListRequest`, `ZListPage`, `ZListController`, `ZListPaginationMode`) sont exportés par `packages/zcrud_core/lib/zcrud_core.dart` (ordre `directives_ordering`). `melos run generate` OK → `melos run analyze` RC=0 (14 packages) → `flutter test` RC=0 sur `zcrud_core` **et** `zcrud_list` → `melos run verify` RC=0 (pureté + graphe SM-5 + secrets + codegen). Non-régression : les ACs E4-1/E4-2 restent satisfaits (`DynamicList`/vues/états inchangés dans leur contrat ; E4-3 les **alimente**, ne les casse pas).

## Tasks / Subtasks

- [x] **Tâche 1 — Normalisation diacritique + prédicat de recherche (AC1, AC2, AC9)**
  - [x] Créer `packages/zcrud_core/lib/src/domain/data/z_search_text.dart` : `String zFoldDiacritics(String input)` (table Latin documentée + `toLowerCase()`), pur-Dart, ne lève jamais. Docstring « recherche sans accents ; réutilisable par l'adaptateur E5 ».
  - [x] Ajouter `bool zMatchesSearch(ZListRow row, String term, {required List<ZFieldSpec> schema})` (placé dans `z_list_query.dart` car il dépend de `ZListRow` — couche présentation) : term blanc → `true` ; sinon `contains` du terme replié sur le texte replié de chaque champ `searchable`. Coercition neutre `Object? → String` (`null→''`, `Iterable→` join).
  - [x] Garde de pureté : aucun `dart:ui`/widget/dépendance ; déterministe.
- [x] **Tâche 2 — `ZListPage` + moteur in-memory `zApplyListRequest` (AC3, AC4, AC5, AC6)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_query.dart` : `@immutable class ZListPage { final List<ZListRow> rows; final ZCursor? nextCursor; final bool hasMore; ... }` (égalité de valeur profonde, helpers pur-Dart réutilisés).
  - [x] `ZListPage zApplyListRequest(List<ZListRow> rows, ZDataRequest request, {required List<ZFieldSpec> schema})` : (1) **filtre** `request.filters` par `ZFilterOp` (comparaisons défensives `_tryCompare`, AD-10) ; (2) **recherche** `zMatchesSearch` sur `searchable` ; (3) **tri** multi-clés STABLE (décoration par index, direction, `null` en dernier) ; (4) **saut curseur** `request.startAfter` (comparaison positionnelle par `values`, `id` départage, ancre introuvable gracieuse) ; (5) `take(limit)` ; (6) **dérive** `nextCursor`/`hasMore`.
  - [x] Fonctions internes de comparaison/saut factorisées et **documentées** comme la productionisation du fake `_InMemoryZRepository` (E2-2). Helper public `zDeriveCursor` partagé moteur ↔ contrôleur.
- [x] **Tâche 3 — `ZListController` + mapping `ZListViewState` + pagination/repli (AC5, AC6, AC7, AC8)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/list/z_list_controller.dart` : `class ZListController<T extends ZEntity> extends ChangeNotifier` avec `ValueListenable<ZListViewState> get state`, constructeur `{required ZRepository<T> repository, required ZListRow Function(T) toRow, required List<ZFieldSpec> schema, int? pageSize, ZListPaginationMode mode, bool watchMutations}`.
  - [x] `enum ZListPaginationMode { backendCursor, inMemory }`.
  - [x] `setSearch`/`setFilters`/`setSort` (reconstruisent `_request`, reset pagination + accumulé, re-query) ; `loadMore()` (startAfter=nextCursor, append) ; `refresh()` ; `dispose()`.
  - [x] **Cycle de requête** : `backendCursor` → `getAll(request-avec-limit-startAfter)` ; succès → projeter `T→ZListRow`, dériver `nextCursor`/`hasMore` (`_commitBackendPage` via `zDeriveCursor`), accumuler. `Left` **avec curseur** → **repli in-memory**. Mode `inMemory` → non paginé + `zApplyListRequest`. `Left` **1re page (sans curseur)** → `ZListError`.
  - [x] **Mapping `empty`/`noResults`** : accumulé vide + `_hasActiveQuery` → `ZListNoResults` ; sinon `ZListEmpty` ; non vide → `ZListReady`.
  - [x] (Option réactivité) `watchMutations` s'abonne à `repository.watchAll()` pour relancer la requête ; abonnement annulé dans `dispose()` (garde `_disposed`).
- [x] **Tâche 4 — Exports barrel (AC10)**
  - [x] Éditer `packages/zcrud_core/lib/zcrud_core.dart` : exporter `src/domain/data/z_search_text.dart`, `src/presentation/list/z_list_query.dart`, `src/presentation/list/z_list_controller.dart` (ordre `directives_ordering`). Exports existants conservés.
- [x] **Tâche 5 — Tests + vérif verte (tous ACs)**
  - [x] `zcrud_core` unit : `z_search_text_test.dart` (pliage diacritique, casse, idempotence, chaîne vide) ; `z_list_query_test.dart` (recherche sans accents sur `searchable` uniquement ; chaque `ZFilterOp` + type incompatible sans crash ; tri multi-clés stable + direction ; pagination `ZListPage`/`nextCursor`/`hasMore` sur N pages ; curseur invalide/ancre absente sans crash).
  - [x] `zcrud_core` widget : `z_list_controller_test.dart` — via **fake `ZRepository`** : (a) `backendCursor` → pagination backend + `loadMore` accumule ; (b) `inMemory` (fake ignorant `limit`/`startAfter`) → repli correct ; (c) `Left` curseur → repli sans `ZListError`/sans crash ; (d) `setSearch('zzz')` → `ZListNoResults` ; jeu vide sans filtre → `ZListEmpty` ; vide + filtre → `ZListNoResults` ; (e) `ValueListenableBuilder<ZListViewState>` + `DynamicList(state:)` (layout `builder`, SM-5) reflète les transitions ; `dispose()` coupe les émissions. **Aucun import `zcrud_list`**.
  - [x] Vérif verte rejouée réellement : `melos run analyze` RC=0 (14 pkgs) → `flutter test` RC=0 (`zcrud_core` 510 + `zcrud_list` 11) → `melos run test` RC=0 (642 total) → `melos run verify` RC=0 (CORE OUT=0, SM-5 graphe, secrets, codegen, reflectable, compat). 0 `.g.dart` suivi ; `melos list` = 14.

## Dev Notes

### Décisions tranchées

- **Moteur in-memory = productionisation du fake E2-2 (AC5/AC6).** Le repli in-memory a déjà été **prouvé** dans `test/domain/z_repository_contract_test.dart` (`_InMemoryZRepository._applyRequest` + `_compareToAnchor`, remédiation M2/M3 : saut par `values`, ancre introuvable sans crash, tie-break multi-clés). E4-3 **extrait** cette logique en un moteur **neutre, public et réutilisable** `zApplyListRequest`, opérant sur `ZListRow.cells` (au lieu des entités `T` du fake). Bénéfice : (1) une seule implémentation du repli, testée ; (2) le contrôleur et (plus tard) tout backend « sans curseur » la partagent ; (3) cohérence stricte avec le comportement déjà validé du fake. **Ne pas réinventer** l'algorithme de saut/tri : reprendre la sémantique E2-2 (`values` positionnelles alignées sur `sorts`, `id` en départage, `id:null` légitime).
- **Recherche sur la valeur BRUTE repliée (pas le rendu locale-aware).** `zMatchesSearch` plie `row.cells[field.name].toString()` (neutre, déterministe), **pas** `ZListColumn.format(...)` (qui reste locale-neutre en E4-2 mais dont l'évolution locale-aware est déférée). Ainsi la recherche est **stable et sans dépendance l10n**. Rechercher sur les **libellés de choix** (`select`/`radio`) ou sur le texte formaté est une **extension future** (documentée, non faite ici) — cohérent avec le report du formatage locale-aware.
- **`empty` vs `noResults` discriminé par « requête active », pas par le jeu sous-jacent (AC8).** Conforme à l'énoncé epics (« après un filtre → noResults ; sans filtre + 0 donnée → empty »). Éviter d'exiger un « comptage du jeu total non filtré » (coûteux, ambigu offline) : le signal `request.search`/`request.filters` non vides est **local, déterministe, suffisant**. Cas-limite (filtre actif alors que le jeu total est aussi vide) → `noResults` par la règle de requête active — **documenté**, acceptable (l'utilisateur a un filtre posé).
- **Contrôleur `ChangeNotifier` exposant `ValueListenable<ZListViewState>` (AD-2/AD-15).** Aligné sur `ZFormController` (E2-7) : réactivité **Flutter-native**, aucun gestionnaire d'état dans le cœur. Un widget d'app écoute la **seule** tranche `state` via `ValueListenableBuilder` et rend `DynamicList(state: value)` (réutilise E4-2). Le code spécifique à un manager (Riverpod/GetX) vivra dans les **bindings** (`zcrud_riverpod`/`zcrud_get`), jamais ici.
- **Pagination : `getAll(request)` + dérivation consommateur du `nextCursor`.** `ZRepository.getAll` renvoie `ZResult<List<T>>` (pas de curseur ; `ZDataLoaded.nextCursor` d'E2-2 est un type d'**état** non retourné par le contrat, AD-11). Le `nextCursor` est donc **dérivé côté consommateur** (contrôleur/moteur) à partir de la dernière ligne de page (valeurs des clés `sorts` + `id`), exactement comme prévu en E2-2 (« le consommateur E4-3 obtient le `nextCursor` … et le repasse dans `ZDataRequest.startAfter` — boucle fermée sans type backend »). C'est `zApplyListRequest` qui centralise cette dérivation.

### Cohérence avec l'existant (patrons à réutiliser, ne pas réinventer)

- **`ZListRow` / `ZListRenderRequest`** (`presentation/list/z_list_render_request.dart`) : `ZListRow{String id, Map<String,Object?> cells}` — c'est la surface neutre sur laquelle filtre/recherche/tri opèrent (`cells[field.name]`). Réutiliser les helpers d'égalité pur-Dart (`_listEquals`/`_mapEquals`) pour `ZListPage`.
- **`ZDataRequest`/`ZFilter`/`ZFilterOp`/`ZSort`/`ZSortDirection`/`ZCursor`** (`domain/data/`) : **ne rien modifier** — E4-3 les **consomme**. La sémantique du curseur (`values` alignées sur `sorts`, `id` départage, `id:null` légitime, ancre introuvable gracieuse) est **déjà documentée** dans `z_cursor.dart`.
- **`ZListViewState`** (`presentation/list/z_list_view_state.dart`) : `ZListLoading`/`ZListEmpty`/`ZListNoResults`/`ZListError(ZFailure)`/`ZListReady(rows)` — **cible** du mapping. E4-2 a déjà câblé leur **rendu** distinct (`empty` ≠ `noResults`, `liveRegion` sur `loading`/`error`). E4-3 fournit seulement le **calcul** de l'état.
- **`ZDataState<T>`** (`domain/data/z_data_state.dart`) : pendant **domaine** (loading/loaded/empty/error). Le contrôleur mappe `résultat repo → ZListViewState` (présentation) ; il peut s'appuyer conceptuellement sur `ZDataState` mais **projette** en `ZListViewState` (qui seul porte `noResults`). Ne **pas** ajouter `noResults` à `ZDataState` (distinction UI).
- **`ZFieldSpec.searchable`** (`domain/edition/z_field_spec.dart:73`) : source de vérité des champs interrogeables. **Ne pas** ajouter d'annotation (E2-4 gelé).
- **`ZFormController`** (`presentation/z_form_controller.dart`) : patron `ChangeNotifier` + `ValueNotifier`/`ValueListenable` mémoïsé + `dispose()` — modèle du `ZListController`.
- **Repli in-memory de référence** : `test/domain/z_repository_contract_test.dart` (`_applyRequest`, `_compareToAnchor`) — **algorithme à porter** dans `zApplyListRequest`.

### Frontière E4-3 ↔ E4-4 ↔ E4-5 (NE PAS déborder)

- **E4-3 (cette story)** : recherche sans accents (`searchable`), filtres/tri via `ZDataRequest`, pagination curseur + **repli in-memory** (AD-16), mapping `empty`/`noResults`. **HEADLESS** (logique : normalisation + moteur + contrôleur). **STOP** ici.
- **E4-4** : **actions ligne filtrées par `ZAcl`** (le port existe, consommé LÀ), **sélection multiple** (bug corrigé), **corbeille** (soft-delete/restore via `ZRepository.softDelete`/`restore`), et **statefulness de la grille (L2)** — `DataGridSource` mémoïsée / passage `StatefulWidget` (sélection/scroll persistants). E4-3 **ne touche pas** `ZSfDataGridRenderer` ni `ZAcl`.
- **E4-5** : sous-listes/relations & onglets (`ZSubListScreen`).

> Tentation d'ajouter `ZAcl`/actions/sélection/corbeille, de modifier `ZSfDataGridRenderer` (statefulness L2), ou d'ajouter des widgets de recherche/chips : **STOP**, c'est E4-4+ ou de la responsabilité app. E4-3 = recherche/filtre/tri/pagination **neutres et headless**.

### Standards de test

- **Helpers & moteur** : unit `flutter_test` **purs** (aucun widget) — `zFoldDiacritics`, `zMatchesSearch` (searchable-only), `zApplyListRequest` (filtres par opérateur, tri multi-clés stable, pagination N pages, curseur invalide sans crash).
- **Contrôleur** : widget `flutter_test` avec **fake `ZRepository<T>`** inline (deux variantes : honore le curseur / l'ignore) + un `FakeEntity implements ZEntity` + `toRow` ; asserts sur les transitions `ValueListenable<ZListViewState>` (via `ValueListenableBuilder` + `find` sur les états E4-2), `loadMore` accumule, repli sans `ZListError`, `dispose` coupe. **Aucun import `zcrud_list`** (SM-5 exécutable).
- **Pureté/graphe** : gardes `presentation_purity`/`no_heavy_file_dep`/`domain_purity` vertes sur les nouveaux fichiers ; graphe SM-5 `zcrud_list` vert (renderer inchangé).

### Project Structure Notes

- Neuf du cœur : `domain/data/z_search_text.dart` (normalisation neutre, réutilisable E5), `presentation/list/z_list_query.dart` (`ZListPage` + `zApplyListRequest` + `zMatchesSearch`), `presentation/list/z_list_controller.dart` (`ZListController` + `ZListPaginationMode`). API publique = barrel `lib/zcrud_core.dart`.
- `zcrud_list` **non modifié** (renderer/tests intacts) ; `melos list` = 14 ; aucun nouveau package.
- `pubspec.yaml` **inchangé** — out-degree 0 (AD-1) : pas de `package:collection`/`intl`/backend. Comparaisons/égalités écrites à la main (cohérent E2-2/E4-2).
- Aucun conflit de structure. `EditionFieldType`/`ZFieldSpec`/`ZDataRequest`/`ZCursor`/`ZRepository` déjà en place.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E4 — Moteur DynamicList] (Story E4-3 : « recherche sans accents sur champs `searchable` ; filtres/tri via `DataRequest` ; pagination curseur (AD-16) ; cas d'erreur : curseur invalide ou backend sans curseur → repli in-memory documenté, pas de crash » ; frontière E4-4/E4-5)
- [Source: architecture.md#AD-16] (pagination par **curseur** — `startAfter`/curseur opaque — exprimée dans le contrat neutre `DataRequest`/`ZQuery`, **repli in-memory documenté** ; `ZAcl` app-supplied ; impl Firestore en `zcrud_firestore`, résout OQ-9)
- [Source: architecture.md#AD-8] (liste dérivée du schéma derrière `ZListRenderer` ; Syncfusion isolé dans `zcrud_list` ; le cœur n'expose que l'abstraction — recherche/filtre/tri/curseur restent **neutres** dans le cœur)
- [Source: architecture.md#AD-11] (`Either<ZFailure,T>` sur les opérations, **flux nus** ; `ZDataState`/`ZListViewState` **dérivés** par la présentation ; l'état `error` porte la `ZFailure`)
- [Source: architecture.md#AD-2 / AD-15] (réactivité **Flutter-native** `ChangeNotifier`/`ValueListenable` ; **aucun** gestionnaire d'état dans le cœur ; code manager-spécifique dans les bindings)
- [Source: architecture.md#AD-10] (désérialisation/évaluation **défensive** : une comparaison/valeur incompatible ne fait jamais planter)
- [Source: architecture.md#AD-13] (a11y/RTL — les surfaces de rendu (états E4-2) sont réutilisées ; E4-3 headless n'ajoute pas de chrome)
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#SM-5] (isolation des dépendances ; recherche/filtre/tri/curseur = logique **neutre** dans le cœur, Syncfusion cantonné à `zcrud_list`)
- [Source: packages/zcrud_core/lib/src/domain/data/z_data_request.dart] (`ZDataRequest`/`ZFilter`/`ZFilterOp`/`ZSort`/`ZSortDirection` — consommés, non modifiés)
- [Source: packages/zcrud_core/lib/src/domain/data/z_cursor.dart] (`ZCursor` opaque : `values` alignées sur `sorts`, `id` départage, `id:null` légitime, ancre introuvable gracieuse — **double mapping** Firestore/repli in-memory documenté)
- [Source: packages/zcrud_core/lib/src/domain/data/z_data_state.dart] (`ZDataState<T>` — pendant domaine ; ne pas y ajouter `noResults`)
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart] (`ZRepository<T extends ZEntity>` : `watch(ZDataRequest)`/`getAll({request})`/`count`/`watchAll` — source du contrôleur)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_view_state.dart] (cible du mapping : `ZListEmpty`/`ZListNoResults` distincts, rendus par E4-2 ; **décision `empty` vs `noResults` = E4-3**)
- [Source: packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart] (hôte E4-2 piloté par `ZListViewState` — alimenté ici via `ValueListenableBuilder`, non modifié dans son contrat)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart] (`ZListRow{id,cells}` — surface neutre du filtre/recherche/tri ; helpers d'égalité pur-Dart)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart#searchable] (`searchable` : champs interrogés par la recherche — E2-4 gelé)
- [Source: packages/zcrud_core/test/domain/z_repository_contract_test.dart] (`_InMemoryZRepository._applyRequest`/`_compareToAnchor` — **repli in-memory prouvé E2-2** à productioniser en `zApplyListRequest`)
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart] (patron `ChangeNotifier`/`ValueNotifier`/`ValueListenable` + `dispose` — modèle du `ZListController`)
- [Source: _bmad-output/implementation-artifacts/stories/e4-2-colonnes-derivees-vues-etats.md] (E4-2 : DÉFÈRE à E4-3 le calcul du filtre + décision `empty`/`noResults` + formatage locale-aware ; états rendus prêts)
- [Source: _bmad-output/implementation-artifacts/stories/e2-2-ports-donnees.md] (E2-2 : `ZDataRequest`/`ZCursor`/`ZRepository`/`ZDataState` + preuve du repli in-memory)
- [Source: CLAUDE.md#Critical Patterns] (recherche sans accents ; réactivité Flutter-native ; aucun style/état manager dans le cœur ; `ListView.builder`)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- `melos run analyze` → SUCCESS (14 packages, 0 issue).
- `flutter test` (zcrud_core) → +510 (dont +31 nouveaux) ; (zcrud_list) → +11.
- `melos run test` (workspace) → RC=0, total **642** (annotations 8 · generator 80 · get 17 · provider 8 · riverpod 8 · list 11 · core 510).
- `melos run verify` → RC=0 : `CORE OUT=0 OK`, `ACYCLIQUE OK`, `gate:melos OK`, `gate:reflectable OK`, `gate:secrets OK`, `gate:codegen OK` (0 `.g.dart` manquant), `gate:compat OK`, corpus `verify:serialization` vert.
- SM-5 : `zcrud_list/test/sm5_syncfusion_isolation_graph_test.dart` vert (fermeture zcrud_core SANS syncfusion) ; `ZSfDataGridRenderer` NON modifié ; tests cœur sans import `zcrud_list`.
- `git status` : 0 `.g.dart` suivi/non-suivi ; `melos list` = 14.

#### Remédiation code-review (M-1 + 3 LOW) — 2026-07-10, statut reste `review`

- **M-1 (garde anti-réponse-obsolète, `_generation`)** — `z_list_controller.dart` : ajout d'un compteur `int _generation` incrémenté à CHAQUE (re)lancement de requête (`++_generation` en tête de `_runQuery`, donc couvre `setSearch`/`setFilters`/`setSort`/`refresh`/`loadMore`/mutation `watchAll`). La génération est capturée avant l'`await` de `repository.getAll`, puis `_runQuery` ET `_runInMemory` (signature élargie `_runInMemory(request, gen, {append})`) **rejettent tout commit/émission** si `_disposed || gen != _generation`. Effet : une réponse en retard n'écrase jamais un état plus récent ; un `setX` pendant un `loadMore` en vol ne laisse ni doublon ni trou.
- **L-4 (`contains` opérande null/vide)** — `z_list_query.dart` `_matchesFilter` : le chemin texte replie l'opérande d'abord ; si `needle.isEmpty` → `return false` (filtre indéfini → ne matche RIEN), supprimant le faux positif `text.contains('')`. Chemin `Iterable` inchangé.
- **L-1 (page finale sur multiple exact)** — décision : **documenté comme bénin** (docstring `_commitBackendPage`). Aucun correctif à surcoût nul possible : trancher `hasMore` avec certitude sur un multiple exact de `pageSize` exige une sonde backend (`limit+1`/`count()`) → déféré à l'adaptateur Firestore E5. Comportement actuel : une requête « à blanc » se corrige gracieusement (page vide → `hasMore=false`), jamais de doublon/trou.
- **L-2 / L-3 (consignés)** — L-2 : limite NFD/marques combinantes documentée dans `z_search_text.dart` (extension future sans dépendance : stripping U+0300–U+036F). L-3 : tie-break `id` au raccord `backendCursor→repli` documenté dans `_compareToAnchor` (à garantir côté adaptateur E5 via dernier `orderBy(id)`).
- **Tests ajoutés (+4)** : 3 tests de CONCURRENCE à complétion contrôlée (`_ControlledRepo` + `Completer`) dans `z_list_controller_test.dart` — (1) 2 `setSearch` rapides → seule la 2ᵉ réponse commit, la 1re en retard ignorée ; (2) `setFilters` pendant un `loadMore` en vol → page loadMore obsolète rejetée (ni doublon ni trou), état final = nouveau filtre ; (3) `dispose` pendant une requête en vol → aucun commit après dispose (0 exception). +1 test L-4 dans `z_list_query_test.dart` (`contains` opérande null/vide → aucun match ; non-régression opérande réel).
- **Vérif verte REJOUÉE** : `melos run analyze` **RC=0** (14 pkgs, « No issues found! ») ; `flutter test` zcrud_core **RC=0 = 514** (510 → **+4**) ; zcrud_list **RC=0 = 11** (SM-5 graphe vert, `ZSfDataGridRenderer` non modifié) ; `melos run verify` **RC=0** (`CORE OUT=0 OK`, `ACYCLIQUE OK`, `gate:melos/reflectable/secrets/codegen/compat OK`). `melos list` = 14 ; 0 `.g.dart` suivi. Non-régression E4-1/E4-2/E4-3 + E1/E2/E3 verte.

### Completion Notes List

- **AC1/AC2 (recherche sans accents)** : `zFoldDiacritics` (domaine pur, table Latin documentée + ligatures œ/æ/ß) et `zMatchesSearch` (prédicat sur les champs `searchable` uniquement, coercition neutre `null→''`/`Iterable→join`). « café »≈« cafe », « e »≈« é » prouvés.
- **AC3/AC4/AC5 (moteur in-memory)** : `zApplyListRequest` productionise le repli E2-2 — filtres (tous `ZFilterOp`, comparaisons défensives sans crash AD-10), tri multi-clés STABLE (décoration par index d'origine — `List.sort` de Dart n'étant pas stable), pagination curseur (`ZListPage`/`nextCursor`/`hasMore`, dérivation via `zDeriveCursor`).
- **AC6 (repli AD-16 sans crash)** : deux déclencheurs — mode `inMemory` (backend sans curseur) ET `Left` sur requête portant un `startAfter` en mode `backendCursor` → bascule sur `_runInMemory` (récupère non paginé + `zApplyListRequest`). Ancre introuvable / au-delà de la fin → page vide, jamais d'exception. Le discriminant du repli est la présence d'un `startAfter` (échec 1re page sans curseur = vraie erreur → `ZListError`).
- **AC7 (Flutter-native, AD-2/AD-15)** : `ZListController` `ChangeNotifier` exposant l'unique tranche `ValueListenable<ZListViewState>` (interne `ValueNotifier`) ; garde `_disposed` empêchant toute émission après `dispose()`. Aucun gestionnaire d'état, aucun import `zcrud_list`.
- **AC8 (empty vs noResults)** : discriminé par `_hasActiveQuery` (search non-blanc OU filtres non vides), signal local déterministe — cas-limite « vide + filtre actif → noResults » assumé et documenté.
- **AC9/AC10 (SM-5 / barrels)** : nouveaux fichiers importent uniquement `package:flutter/foundation.dart` (pour `@immutable`/`ChangeNotifier`) + types `zcrud_core` ; `pubspec.yaml` inchangé (out-degree 0). Barrel enrichi (ordre `directives_ordering`). Gardes pureté/graphe vertes.
- **Décisions d'ambiguïté** : (1) `zMatchesSearch` vit dans `z_list_query.dart` (présentation) et non dans `z_search_text.dart` (domaine) car il dépend de `ZListRow` (couche présentation) — respecte le sens des couches ; seul `zFoldDiacritics` (sans dépendance à `ZListRow`) reste dans le domaine. (2) Tri : `null` traité comme la plus grande valeur (dernier en ascendant ; la négation `desc` le place en tête) — choix documenté et stable. (3) `hasMore` backend dérivé par heuristique `rows.length >= pageSize` (au pire une page vide finale en cas de division exacte). (4) `zDeriveCursor` exposé publiquement pour partager la dérivation entre moteur (repli) et contrôleur (backend).
- **Frontière respectée** : aucune action/`ZAcl`/sélection/corbeille (E4-4), aucune statefulness grille L2 / `ZSfDataGridRenderer` intact (E4-4), aucune sous-liste (E4-5), aucun formatage locale-aware (déféré) ; `sprint-status.yaml` NON touché (orchestrateur).

### File List

**Nouveaux (code) :**
- `packages/zcrud_core/lib/src/domain/data/z_search_text.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_query.dart`
- `packages/zcrud_core/lib/src/presentation/list/z_list_controller.dart`

**Nouveaux (tests) :**
- `packages/zcrud_core/test/domain/data/z_search_text_test.dart`
- `packages/zcrud_core/test/presentation/list/z_list_query_test.dart`
- `packages/zcrud_core/test/presentation/list/z_list_controller_test.dart`

**Modifiés :**
- `packages/zcrud_core/lib/zcrud_core.dart` (exports barrel : `z_search_text`, `z_list_query`, `z_list_controller`)

## Change Log

| Date | Version | Description | Auteur |
|------|---------|-------------|--------|
| 2026-07-10 | 0.1 | Implémentation E4-3 : recherche sans accents (`zFoldDiacritics`/`zMatchesSearch`), moteur in-memory neutre (`ZListPage`/`zApplyListRequest`/`zDeriveCursor`), `ZListController` (pagination curseur + repli in-memory AD-16 + mapping empty/noResults). +31 tests. Vérif verte rejouée (analyze/test/verify RC=0, SM-5 vert). Status → review. | dev-story (claude-opus-4-8) |
| 2026-07-10 | 0.2 | Remédiation code-review : M-1 (garde `_generation` anti-réponse-obsolète — `setX`/`refresh`/`loadMore` estampillés, commit rejeté si génération obsolète) ; L-4 (`contains` opérande null/vide → aucun match) ; L-1 documenté bénin ; L-2/L-3 consignés. +4 tests (3 concurrence contrôlée + 1 L-4). Vérif verte rejouée (analyze RC=0 ; core 514 ; list 11 ; verify RC=0 — CORE OUT=0, SM-5). Status reste `review`. | dev-story (claude-opus-4-8) |
