# Code-review epic SUF — lentille **Adversariale**

**Date** : 2026-07-26 · **Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2/SUF-3 (`zcrud_study`), SUF-4 (`zcrud_session` + démo assemblée).
**Hors périmètre** (non revu, non touché) : `packages/zcrud_markdown/` (workstream parallèle).
**Verdict global : BLOQUANT** — 2 défauts CONFIRMÉS par exécution (dont un crash), 2 contradictions doc/code prouvées par grep négatif.

> Méthode : chaque affirmation ci-dessous est adossée soit à une **exécution** (`flutter test` sur un repro jetable écrit hors `lib/` et hors `test/`, dans un répertoire `.review_adv/` **supprimé après coup** — `git status | grep -c review_adv` → `0`), soit à un **grep négatif avec son RC**. Aucun finding « supposé ».

---

## Contexte de la lentille

La lentille adversariale cherche **deux lectures conformes mais incompatibles d'une même règle**, et les **angles morts entre stories** : SUF-1 fournit le shell, SUF-3 le consomme ; SUF-2 fournit une carte, SUF-3 un `itemBuilder` de sous-dossier. Les quatre findings ci-dessous sont tous à ces coutures — aucun n'est visible en lisant une story isolément, ce qui explique qu'ils aient traversé les revues par story.

---

## F1 — HIGH — `ZPageScaffold` : changer `mode` de `fixed` vers un mode sliver **crashe** (`Null check operator used on a null value`)

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:75` (création conditionnelle) et `:146` (déréférencement `_controller!`).

### Les deux lectures incompatibles

* **Lecture A (celle du code)** : « le propriétaire de l'état de recherche dépend du mode » — en `fixed`, c'est `ZSearchableAppBar` qui détient son `_ZSearchController` (`z_searchable_app_bar.dart:63`) ; en sliver, c'est `_ZPageScaffoldState` (`z_page_scaffold.dart:75`, gardé par `if (_isSliver)`).
* **Lecture B (celle de l'API publique)** : `mode` est une **prop déclarative** d'un widget immuable (`final ZPageAppBarMode mode;`, `z_page_scaffold.dart:54`), donc modifiable d'un build à l'autre comme n'importe quelle autre prop — c'est même l'usage naturel d'un shell adaptatif (`fixed` en compact, `floating` en large).

Les deux lectures sont défendables ; leur intersection est un **crash**. Le propriétaire de l'état est figé dans `initState()` alors que le critère qui le désigne (`_isSliver`) est une prop **variable**. Aucun `didUpdateWidget` ne rattrape la transition :

```
$ grep -n "didUpdateWidget" lib/src/presentation/z_page_shell.dart \
      lib/src/presentation/z_page_scaffold.dart \
      lib/src/presentation/z_searchable_app_bar.dart
RC=1        # aucune occurrence
```

### Preuve d'exécution (repro jetable, supprimé)

```dart
Widget page(ZPageAppBarMode mode) => MaterialApp(
      home: ZPageScaffold(title: 'T', mode: mode, body: const SizedBox(height: 10)),
    );
await tester.pumpWidget(page(ZPageAppBarMode.fixed));
await tester.pumpWidget(page(ZPageAppBarMode.floating));   // même élément
expect(tester.takeException(), isNull);
```

```
$ flutter test .review_adv/adv_repro_test.dart --plain-name "R1"
Expected: null
  Actual: _TypeError:<Null check operator used on a null value>
00:01 +0 -1: Some tests failed.
```

Le `_TypeError` vient de `_controller!` (`z_page_scaffold.dart:146`, puis `:152/:159/:167`) : `_controller` vaut `null` puisqu'il n'a jamais été créé sous le mode initial `fixed`.

### Pourquoi ça a échappé aux gardes SUF-1

```
$ grep -n "search" test/z_page_scaffold_sliver_test.dart test/z_page_scaffold_tabs_test.dart
RC=1        # aucun test n'exerce le mode sliver AVEC une recherche
$ grep -n "mode:" test/*.dart
test/z_page_scaffold_sliver_test.dart:8:        mode: mode,     # un seul point d'injection, jamais deux modes successifs
```

Le mode est toujours **fixe pour la durée du test** : la transition n'est jamais jouée. La garde R3 de l'AC11 vérifie le rendu de chaque mode, pas la **commutation** entre eux.

### Aggravation par SUF-3

`ZStudyFolderDetail` **ré-expose** `mode` tel quel (`z_study_folder_detail.dart:88` et `:215`, `mode: widget.mode`). Un hôte qui bascule le mode selon la classe de fenêtre (exactement le geste que l'epic SUF encourage) crashe la page-détail entière.

### Correctifs possibles (au choix de l'orchestrateur)

1. Créer le `_ZSearchController` **inconditionnellement** dans `initState` (coût : un `TextEditingController`/`FocusNode` inutilisé en mode `fixed`) ; ou
2. `didUpdateWidget` : créer/disposer le contrôleur au franchissement de `_isSliver` ; ou
3. Documenter et **imposer** l'immuabilité de `mode` (`assert(oldWidget.mode == widget.mode)` dans `didUpdateWidget`) — mais c'est un invariant non écrit aujourd'hui, donc un piège d'API tant qu'il n'est pas matérialisé.

---

## F2 — MAJEUR — `ZSearchableAppBar`/`ZPageScaffold` : une `ZAppBarSearchConfig` remplacée est **silencieusement ignorée** (callback périmé capturé à vie)

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:44-51` (`_ZSearchController(this._config)`, `final ZAppBarSearchConfig? _config;`), consommé en `:72` et `:81`.

### Les deux lectures incompatibles

* **Lecture A** : `ZAppBarSearchConfig` est un **`@immutable` sans état** (`z_app_bar_search_config.dart:14`, doc `:5-8` « Cette config ne porte donc **pas** d'état ») ⇒ une valeur, remplaçable à chaque build comme n'importe quelle prop de widget. C'est le contrat annoncé.
* **Lecture B** : le shell la **capture une fois** dans `initState` et ne la relit jamais. La config devient donc, de facto, un objet à **durée de vie de State** — l'exact opposé d'une valeur.

Or `ZAppBarSearchConfig` contient un `ValueChanged<String> onQueryChanged` : une **closure**, recréée à chaque `build()` de l'hôte dans l'écrasante majorité des cas (`onQueryChanged: (q) => _filter(q, currentFolderId)`). Toute closure qui capture une variable de build (l'onglet courant, l'id du dossier, une page de pagination) est **gelée sur sa première valeur**.

### Preuve d'exécution (repro jetable, supprimé)

```dart
await tester.pumpWidget(page(ZAppBarSearchConfig(onQueryChanged: vieux.add)));
await tester.pumpWidget(page(ZAppBarSearchConfig(onQueryChanged: neuf.add)));   // config remplacée
await tester.tap(find.byIcon(Icons.search));
await tester.enterText(find.byType(TextField), 'ab');
expect(neuf, <String>['ab']);   // la NOUVELLE config doit recevoir la frappe
expect(vieux, isEmpty);
```

```
$ flutter test .review_adv/adv_repro_test.dart --plain-name "R2"
Expected: ['ab']
  Actual: []
la NOUVELLE config doit recevoir la frappe
00:01 +0 -1: Some tests failed.
```

La frappe est partie dans `vieux` — la config périmée. Aucune erreur, aucun log : **perte silencieuse**, exactement la classe de défaut que ce dépôt traque (cf. CR-LEX-41/42).

Même racine que F1 : `grep -n "didUpdateWidget"` sur les trois fichiers du shell ⇒ **RC=1**.

### Portée

Touche les **deux** propriétaires : `ZSearchableAppBar` (`z_searchable_app_bar.dart:63`) et `ZPageScaffold` en mode sliver (`z_page_scaffold.dart:75`). Et donc `ZStudyFolderDetail`, qui passe `search: widget.search` verbatim (`z_study_folder_detail.dart:214`).

### Correctif

`didUpdateWidget` : si `widget.search != oldWidget.search`, mettre à jour la référence de config détenue par `_ZSearchController` (rendre `_config` non-`final` + setter), **sans** recréer le `TextEditingController`/`FocusNode` (l'invariant AD-2 « pas de controller recréé au rebuild » doit être préservé — il ne s'agit pas de reconstruire l'état de saisie, seulement de rafraîchir le point d'émission).

---

## F3 — MAJEUR — `ZSubfolderNavSpec.itemBuilder` : le seam d'extension est honoré par la **sidebar** et **ignoré** par le **sélecteur compact**, et il **perd la surbrillance de sélection** que sa propre doc garantit (AC8)

C'est la couture SUF-2 ↔ SUF-3 exactement telle que la lentille la vise : le `subfolderItemBuilder` est la mitigation documentée du risque **R-SUF2** (« l'hôte peut brancher un rendu basé `ZFolderCard` sans que SUF-3 se couple à la signature de SUF-2 », story SUF-3 ligne 49, décision **D3** ligne 227). Ce seam est aujourd'hui **cassé sur deux axes**.

### Axe A — le sélecteur compact ignore purement et simplement le builder injecté

```
$ grep -n "itemBuilder\|count\|colorKey" packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart
RC=1        # aucune occurrence des trois
```

`ZSubfolderCompactSelector` consomme le **même** `ZSubfolderNavSpec` (`z_subfolder_compact_selector.dart:43`) mais n'en lit que `allSubfoldersLabel`, `subfolders[].id/.label`, `addAction/addLabel/addIcon`. Il n'appelle **jamais** `spec.itemBuilder`, n'affiche **jamais** `ref.count` ni la pastille `ref.colorKey`.

**Deux lectures incompatibles** : la story (AC7, ligne 87) pose sidebar et sélecteur compact comme **deux présentations de la même navigation** ; l'implémentation en fait **deux navigations aux capacités différentes**. Un hôte qui branche un rendu `ZFolderCard` sur ses sous-dossiers l'obtient à ≥ 600 dp et le perd à < 600 dp — sans le moindre avertissement. Symétriquement, `ZSubfolderRef.colorKey`/`.count`, documentés comme « `null` ⇒ absence structurelle (AD-4) » (`z_subfolder_ref.dart:43,46`), sont **toujours** absents en compact, `null` ou pas : l'absence n'y est plus le signal d'une décision de l'hôte.

### Axe B — dans la sidebar, l'item injecté ne reçoit **aucune** surbrillance

Trois textes affirment le contraire :

* `z_subfolder_sidebar.dart:303-304` : « la **surbrillance de sélection est TOUJOURS appliquée par SUF-3** (fond dérivé du thème — AC8) » ;
* `z_subfolder_nav_spec.dart:84-85` (doc du typedef) : « le widget applique **DÉJÀ** sa propre surbrillance neutre autour de l'item (ce builder n'est donc PAS obligé de la gérer) » ;
* story SUF-3, **AC8** (ligne 90) : « L'item sélectionné est visuellement mis en évidence (fond/contour dérivé du thème) ».

Le code dit l'inverse. Dans `_SubfolderRow.build` (`z_subfolder_sidebar.dart:335-378`), `content` vaut soit la sortie de `spec.itemBuilder`, soit `_defaultContent(...)`, puis est enveloppé **uniquement** par `Semantics` → `InkWell` → `ConstrainedBox` : aucune décoration. Le fond de sélection est calculé et posé **exclusivement dans `_defaultContent`** :

```
$ grep -n "decoration\|BoxDecoration\|color:" packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart
289:              color: scheme.outlineVariant,     # trait de la poignée de resize
401:            color: fg,                          # _defaultContent (texte)
425:      decoration: bg == null                    # _defaultContent (fond de sélection)
427:          : BoxDecoration(
428:              color: bg,
476:      decoration: BoxDecoration(color: pair.color, ...)   # _AccentPastille
500:      decoration: BoxDecoration(                          # _CountPill
```

`bg` (`:384`) n'existe que dans `_defaultContent`. Conclusion : **`itemBuilder` fourni ⇒ AC8 (mise en évidence visuelle) n'est plus satisfait**, alors que le `Semantics(selected:)` (`:362`), lui, reste correct — d'où un écart entre ce que le lecteur d'écran annonce et ce que l'écran montre, précisément le genre de divergence que SUF-4 se félicite d'avoir fermée ailleurs (`z_session_progress_indicator.dart`, doc de `position`).

### Pourquoi aucune garde ne rougit

```
$ grep -rn "itemBuilder:" packages/zcrud_study/test/z_subfolder_*.dart \
        packages/zcrud_study/test/z_study_folder_detail_*.dart \
        packages/zcrud_study/test/suf3_source_guard_test.dart
RC=1        # aucun test n'injecte jamais un itemBuilder non nul
```

Le harnais l'expose bien en paramètre (`test/support/suf3_harness.dart:58` puis `:67`), mais **aucun** test ne le renseigne. La démo assemblée SUF-4 ne l'exerce pas non plus : son unique `itemBuilder` (`test/support/suf4_assembly_demo.dart:230`) est celui de `ZStudyToolsSectionSpec`, et son `ZSubfolderNavSpec` (`:216-222`) ne porte pas d'`itemBuilder`. **Le seam d'extension le plus stratégique de SUF-3 — celui qui justifie l'existence du VO opaque et neutralise R-SUF2 — n'est couvert par zéro ligne de test et est cassé sur ses deux chemins.**

### Correctif

1. Appliquer la surbrillance **hors** de `_defaultContent` (déplacer le `Container` décoré dans `build`, autour de `content`), OU corriger les trois documentations pour dire que l'`itemBuilder` **doit** gérer la sélection (mais alors le paramètre `selected` du typedef devient obligatoire à honorer, et AC8 doit être re-formulé) ;
2. Faire consommer `spec.itemBuilder` par `ZSubfolderCompactSelector`, OU documenter explicitement dans `ZSubfolderNavSpec.itemBuilder` que le champ est **sidebar-only** (piège d'API assumé et écrit) ;
3. Ajouter la garde manquante : injecter un `itemBuilder` marqueur, prouver qu'il est appelé **aux deux tailles d'écran** et que le marqueur sélectionné se distingue visuellement.

---

## F4 — MEDIUM — Angles morts d'API entre SUF-1 et SUF-3 : props figées dans `initState` sans `key` documentée, `tabController` non ré-exposé, ref racine fabriquée

Quatre pièges d'API, tous prouvés, groupés car de même nature (contrats non écrits que l'hôte ne peut pas deviner).

**(a) `ZStudyFolderDetail` fige `initialSelectedSubfolderId` et `initialSidebarWidth` sans jamais les relire.**

```
$ grep -n "didUpdateWidget" packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart
RC=1
```

`initState` (`:182-184`) snapshotte les deux props. Un hôte qui réutilise la même page pour un **autre dossier** à la même position d'arbre (navigation latérale, `PageView`, liste maître-détail) conserve la sélection de l'ancien dossier — et `materialSectionsBuilder(idPérimé)` est alors appelé avec l'id d'un sous-dossier **qui n'existe plus dans `nav.subfolders`**. Aucune doc n'exige une `Key` par dossier. Le nom `initialXxx` suggère la sémantique « seulement au premier build », mais rien ne l'écrit et rien ne l'impose.

**(b) `ZStudyFolderDetail` n'expose pas `tabController`.**

```
$ grep -n "tabController" packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart
RC=1
```

SUF-1 offre explicitement l'injection (`z_page_scaffold.dart:57`, doc `:18-19`) ; SUF-3 ne la transmet pas. Comme `_wrapTabs` (`z_page_scaffold.dart:115-118`) installe **inconditionnellement** un `DefaultTabController` interne quand aucun contrôleur n'est injecté, un hôte qui enveloppe `ZStudyFolderDetail` dans son propre `DefaultTabController` (pour ouvrir la page sur l'onglet Progression depuis un lien profond) voit le sien **masqué en silence** par le contrôleur interne. Capacité offerte par la brique, perdue à la composition, sans diagnostic.

**(c) `ZSubfolderRef` racine fabriquée avec `id: ''`.**

```
$ grep -n "ZSubfolderRef(id: ''" packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart
341:              ref ?? ZSubfolderRef(id: '', label: label),
```

`ZSubfolderRef.id` est documenté « Identifiant **STABLE** et **OPAQUE** […] sert de valeur de sélection ET de clé de réordonnancement » (`z_subfolder_ref.dart:34-36`). Pour l'item racine, la valeur de sélection réelle est `null` (`:334`, `selectionId = ref?.id`), mais l'`itemBuilder` injecté reçoit `''` — une **sentinelle non documentée** ni dans le typedef `ZSubfolderItemBuilder` (`z_subfolder_nav_spec.dart:86-90`) ni dans `ZSubfolderRef`. Un hôte qui écrit `folderById[ref.id]!` sur ce callback (usage naturel d'un id opaque) plante sur la racine ; un hôte qui navigue sur `ref.id` navigue vers un id vide. Le contrat honnête serait `ZSubfolderRef?` (`null` = racine) ou un `bool isRoot` explicite.

**(d) Parité annoncée, dimension divergente.** `z_subfolder_sidebar.dart:41-43` annonce « Diamètre de la pastille d'accent d'un item […] **parité `ZFolderCard`** » puis pose `12.0` ; `z_folder_card.dart:63-65` pose `14`. La parité affirmée est fausse — LOW en soi, mais c'est le même symptôme que F3 : la documentation de SUF-3 décrit un accord avec SUF-2 qui n'a jamais été vérifié.

---

## Points explicitement VÉRIFIÉS et jugés SAINS (pour éviter les faux positifs d'une prochaine passe)

* **Double `TabController`** : non. `ZStudyFolderDetail` ne passe pas de `tabController` ⇒ `_wrapTabs` (`z_page_scaffold.dart:115-118`) crée **un** `DefaultTabController(length: 3)` ; le `TabBar` (`:91`) et le `TabBarView` (`:105`) reçoivent tous deux `widget.tabController` (`null`) et résolvent donc le **même** contrôleur par héritage. Un seul propriétaire.
* **Double propriétaire de l'état de recherche** : non — la création est mutuellement exclusive (`if (_isSliver)` en `:75` vs `z_searchable_app_bar.dart:63`). Le défaut est la **transition** (F1), pas la coexistence.
* **Convention de réordonnancement `onReorderItem` vs actions sémantiques** : cohérente. Le SDK confirme que `onReorderItem` ajuste déjà `newIndex` pour le retrait (`/home/zakarius/flutter/packages/flutter/lib/src/material/reorderable_list.dart:83` : « The onReorderItem callback adjusts the newIndex parameter for a removed item at the oldIndex »), ce qui correspond bien à la convention `removeAt(old)/insert(new)` utilisée par les actions sémantiques `index±1` (`z_subfolder_sidebar.dart:352,357`). Vérifié à la main sur `[A,B,C]` dans les deux sens.
* **Seam de test `queryListenable` non tautologique** : `test/z_searchable_app_bar_test.dart:129-146` assert **à la fois** l'émission réelle vers `onQueryChanged` (`emitted`) et la valeur du seam. Le seam ne remplace pas la preuve de sortie.
* **AC8 côté sélecteur compact** (chemin par défaut) : `ChoiceChip(selected:)` (`z_subfolder_compact_selector.dart:88-91`) porte à la fois la mise en évidence Material et la sémantique `selected` — conforme tant que l'`itemBuilder` n'est pas injecté (cf. F3 axe A).

## Limite de la revue à consigner

Les repros d'exécution ont pu être joués sur **`zcrud_ui_kit`** (F1, F2 confirmés en rouge). Ils n'ont **pas** pu l'être sur `zcrud_study` : le paquet compile via `zcrud_markdown`, qui est dans un état transitoire non compilable du fait du workstream parallèle (`../zcrud_markdown/lib/src/domain/z_markdown_bridge.dart:23:1: Error: The non-ASCII character '↔' …`) — **hors périmètre, ce n'est pas un finding de cette revue**. F3 et F4 sont donc établis par **lecture + greps négatifs** (RC fournis), ce qui est suffisant pour F3 axe A (grep négatif d'appel), F3 axe B (le seul site de décoration est dans `_defaultContent`), F4-a/b (grep négatif), F4-c/d (citation de ligne). Il reste recommandé de **rejouer un repro d'exécution sur F3** dès que `zcrud_markdown` est de nouveau vert.
