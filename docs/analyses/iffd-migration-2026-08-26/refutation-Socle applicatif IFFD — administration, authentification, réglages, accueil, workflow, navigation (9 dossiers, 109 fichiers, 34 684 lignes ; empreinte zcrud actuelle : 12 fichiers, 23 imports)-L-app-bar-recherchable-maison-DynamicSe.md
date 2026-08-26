# Réfutation — « le socle sait déjà faire l'app-bar recherchable maison »

**Domaine** : Socle applicatif IFFD — administration, authentification, réglages, accueil,
workflow, navigation.
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZPageScaffold` / `ZPageShellBody` /
`ZSearchableAppBar` / `ZAppBarAction` + `ZAppBarSearchConfig` ».
**Gain annoncé** : ~443 lignes d'hôte supprimées.

## VERDICT : **RÉFUTÉE**

Les quatre canaux **existent** et sont **atteignables**. Mais ils ne couvrent qu'une **partie** du
besoin réel, et le mécanisme central de l'affirmation — « ZSearchableAppBar détient l'état, ce qui
fait disparaître les 13 sous-classes » — est **démenti par le site que l'hôte a DÉJÀ migré**, sur
disque, dans ce même dépôt. Le gain de 443 lignes n'est pas atteignable, et rien de mesurable ne
l'est depuis ce périmètre.

---

## 1. Ce qui RÉSISTE (à porter au crédit de l'affirmation)

### 1.1 Les canaux existent, aux lignes citées

| Canal cité | Vérifié |
|---|---|
| `zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:46` | ✅ `class ZPageScaffold extends StatefulWidget` — ligne 46 exactement |
| `z_page_shell_body.dart:36` | ✅ `class ZPageShellBody extends StatefulWidget` — ligne 36 exactement |
| `z_searchable_app_bar.dart:14` | ✅ `class ZSearchableAppBar extends StatefulWidget implements PreferredSizeWidget` — ligne 14 exactement |
| `zcrud_ui_kit/lib/src/domain/z_app_bar_action.dart:15` | ✅ `class ZAppBarAction {` — ligne 15 exactement |
| `z_app_bar_search_config.dart` | ✅ `class ZAppBarSearchConfig` (16 l. de champs, `@immutable`) |

### 1.2 Ils sont atteignables

* Les trois widgets sont des `part of 'z_page_shell.dart'` (`z_page_shell.dart:38-40`), et
  `z_page_shell.dart` est **exporté par le barrel** (`lib/zcrud_ui_kit.dart`, ligne
  `export 'src/presentation/z_page_shell.dart';`). `z_app_bar_action.dart` et
  `z_app_bar_search_config.dart` sont exportés nominativement.
* `zcrud_ui_kit` est une **dépendance déclarée** d'IFFD : `/home/zakarius/DEV/iffd/pubspec.yaml:440`
  (bloc `dependencies:` qui commence en ligne 10, `dev_dependencies:` en 533) — `ref: v3.21.0`, plus
  un `dependency_overrides` en ligne 700.
* IFFD importe déjà le paquet dans **2 fichiers** (`grep -rln "package:zcrud_ui_kit" lib/` ⇒ 2) et
  consomme déjà `ZAppBarAction` et `ZAppBarSearchConfig`.

### 1.3 Le corps tient une partie de sa dartdoc

Lu, pas cru sur parole :
* `_ZSearchController` (`z_page_shell.dart:55-140`) détient réellement `isSearching`, `query`,
  `TextEditingController` et `FocusNode`, créés une fois, `dispose`és une fois.
* Rebuild granulaire : `ValueListenableBuilder<bool>` sur `isSearching` seul
  (`z_searchable_app_bar.dart:187-189`) ; la frappe ne rebâtit pas l'app-bar.
* `Échap ⇒ fermeture` : **réellement câblé**, `CallbackShortcuts` +
  `SingleActivator(LogicalKeyboardKey.escape) : controller.close` (`z_page_shell.dart:417-421`).
  Ce n'est pas une promesse de dartdoc — c'est du code.
* `ZAppBarAction` en données : `_zBuildActions` (`z_page_shell.dart:560-620`) ne rend un `IconButton`
  que pour une action déclarée ; le débordement passe par `PopupMenuButton<ZAppBarAction>` résolu
  **par identité**, pas par index.
* Les 10 créneaux `Scaffold` de `ZPageScaffold` existent (`z_page_scaffold.dart:67-77` :
  `floatingActionButton`, `floatingActionButtonLocation`, `persistentFooterButtons`, `drawer`,
  `endDrawer`, `bottomNavigationBar`, `bottomSheet`, `backgroundColor`, `resizeToAvoidBottomInset`,
  `extendBody`/`extendBodyBehindAppBar`), ainsi que `aboveTabBar` (:61), `aboveTabBarHeight` (:62)
  et `aboveTabViews` (:63).

**Jusqu'ici l'affirmation tient.** Ce qui suit la démonte.

---

## 2. RÉFUTATION 1 — `ZPageScaffold` et `ZPageShellBody` sont INAPPLICABLES aux 6 sites du périmètre

Les 6 sites du périmètre alimentent tous le créneau `appBar:` d'un `Scaffold` **détenu par l'hôte** :

| Site | Consommé par |
|---|---|
| `lib/src/presentation/features/administration/pages/user_role_page.dart:72` | `AppScaffold(appBar: PreferredSize(...))` (`:68-72`) |
| `.../administration/pages/ai_experts_page.dart:56` | `PreferredSize buildAppbar()` (`:52`) → `appBar:` en `:1241`, `:1257`, `:1298` |
| `.../administration/pages/auditeurs_pages.dart:82` | `PreferredSize buildAppbar()` (`:78`) → `appBar:` en `:1193`, `:1209`, `:1249` |
| `.../home/pages/dashbord_page.dart:446` | `_DashboardAppBar` (`:409`, `implements PreferredSizeWidget`) → `appBar:` en `:207` |
| `.../home/pages/dashbord_page.dart:456` (`FoldersAppBarBuilder`) | idem |
| `.../home/pages/dashbord_page.dart:472` | idem |

`ZPageScaffold` **construit** son propre `Scaffold` ; `ZPageShellBody` est un **corps à slivers** à
poser dans le `body:` de l'hôte. Aucun des deux ne peut occuper un créneau `appBar:`. Sur ce
périmètre, **le seul canal réellement candidat est `ZSearchableAppBar`** — et c'est justement celui
qui a le moins de surface. Citer les quatre canaux ensemble surévalue la couverture.

De plus, `_DashboardAppBar.preferredSize` (`dashbord_page.dart:435-441`) est **dépendante de la
route** (`kToolbarHeight * 1` ou `* 2`) : la hauteur est décidée par l'hôte, pas par le socle.

---

## 3. RÉFUTATION 2 — le mécanisme annoncé est DÉMENTI par le site déjà migré de l'hôte

L'affirmation dit : « `ZSearchableAppBar` DÉTIENT l'état de recherche […] **ce qui fait disparaître
les 13 sous-classes** ».

IFFD a **déjà** migré un site vers `ZAppBarSearchConfig`
(`lib/src/presentation/features/folders/pages/folder_details_page.dart:844`). Résultat mesuré, dans
le commentaire écrit par l'hôte lui-même (`:829-837`) :

> « ⚠️ Cette écoute est ce qui fait VIVRE la recherche et le filtre : les sections sont
> reconstruites quand `searchController` notifie. **Sans elle, taper une requête ne changeait RIEN à
> l'écran** »

Le contrôleur n'a **pas** disparu : il a fallu l'**envelopper** dans un `ListenableBuilder`
(`:829-831`) et lui **réécrire** la query à la main :

```dart
search: ZAppBarSearchConfig(
  hintLabel: 'Recherche',
  onQueryChanged: (String q) =>
      searchController.searchQuery =
          unaccentedText(q)!.replaceAll(' ', '').toLowerCase(),
),
```

La raison est structurelle, et elle est chiffrable :

* **58 occurrences** de `searchQuery` dans `lib/` (`grep -rn "searchQuery" lib/ | wc -l`). La query
  n'est **pas** lue par l'app-bar : elle est lue par le **corps de liste**, dans un autre sous-arbre
  (`user_role_page.dart:84`, `ai_experts_page.dart:94`, `auditeurs_pages.dart:226`,
  `subjects_page.dart:103`, `folders_page.dart:188`, `folder_study_tools_page.dart:422/442/864`…).
  `ZAppBarSearchConfig` n'expose qu'un `ValueChanged<String>` : l'hôte doit **reconstruire** le
  canal vers le corps. Il lui faut donc toujours un porteur par page.
* **30 occurrences** de `listFilter` / `flashcardsListFilter` hors du fichier de contrôleurs. Ce
  champ (`dynamic_list_search_controller.dart:10,14,26-29`) n'a **aucun** équivalent dans le socle :
  `ZAppBarSearchConfig` ne porte que `onQueryChanged`, `hintLabel`, `initialQuery`,
  `hidesHostActions`. **Dans le périmètre**, `AuditeursIffdSearchController` s'en sert en
  `auditeurs_pages.dart:105`, `:197`, `:227`, `:228`, `:231`, `:235` — la sous-classe ne peut donc
  pas disparaître de ce site.

**Grep négatif montré** — aucun paquet du socle n'expose l'état de recherche à l'hôte hors de
`zcrud_ui_kit` :

```
$ grep -rn "isSearching" zcrud_core/lib zcrud_screen/lib zcrud_study/lib zcrud_responsive/lib
RC=1   (aucune occurrence)
```

Le seul crochet est `ZAppBarSearchConfig.hidesHostActions` (tout ou rien).

### Chiffrage du fichier de contrôleurs — l'affirmation se trompe aussi sur les nombres

`grep -c "^class "` ⇒ **16 classes** (pas 15). Corps strictement vides (`{}`) ⇒ **14** (pas 13) :
lignes 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 69, 71. Deux classes portent un corps réel :
`DynamicListSearchController` (`:5-33`, 29 l.) et `FolderDetailsSearchController` (`:59-66`).

---

## 4. RÉFUTATION 3 — le champ de recherche PERSISTANT sur grand écran n'existe nulle part dans le socle

C'est l'écart fonctionnel le plus lourd, et il est **invisible** dans l'affirmation.

`DynamicSearcheableAppBar` a **deux** rendus, séparés par un point de rupture
(`responsive_builder`) :

* **grand écran** (`!infos.isMobile`, `:264-282`) : un champ de recherche **toujours visible**, posé
  dans `actions`, largeur animée `300 → 350` dp selon que la query est vide ou non — **et aucune
  loupe** (`:292-296` rend `const SizedBox()` quand `!isSmall`). Le titre reste affiché.
* **petit écran** (`:243-248`) : le titre morphe en champ, et une loupe/croix apparaît
  (`:308-322`).

`ZSearchableAppBar` n'a **qu'un seul** rendu : loupe toujours présente dès que `search != null`
(`z_page_shell.dart:610-620`), champ **uniquement** dans le créneau titre et **uniquement** quand
`searching == true` (`:415-431`).

**Grep négatif montré** — le paquet entier ne connaît aucune notion de largeur :

```
$ cd packages/zcrud_ui_kit && grep -rniE "responsive|breakpoint|isMobile|isSmall|MediaQuery" lib/
RC=1   (aucune occurrence)

$ grep -rni "search" packages/zcrud_responsive/lib/
RC=1   (aucune occurrence)
```

IFFD cible **six plateformes** (`ls -d android ios linux macos web windows` ⇒ les six existent).
Sur web/desktop, la migration ferait **disparaître un champ de saisie visible en permanence** et
imposerait un clic préalable, en escamotant le titre. Ce n'est pas un détail de style : c'est une
régression de parcours, sur 5 des 6 sites du périmètre (tous sauf `dashbord_page.dart:446`, qui
passe `allowSearching: false`).

---

## 5. RÉFUTATION 4 — trois autres surfaces sans équivalent, sur ce périmètre

### 5.1 `tabs: List<String>` et son `TabBar` stylé (4 des 6 sites)

`ZSearchableAppBar` **n'a pas** de créneau `tabs` — seulement `bottom: PreferredSizeWidget?`
(`z_searchable_app_bar.dart:134`). **Grep négatif montré** :

```
$ grep -nE "backgroundColor|List<String>|indicatorColor|tabAlignment" \
      packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart
RC=1   (aucune occurrence)
```

Aujourd'hui l'hôte obtient **gratuitement** un `TabBar` complet (`dynamic_searcheable_app_bar.dart:
331-367`, ~37 lignes) : bordure basse `outline @ .2`, `indicatorColor: primary`, `indicatorWeight:
3`, `labelColor: primary`, `unselectedLabelColor: onSurface @ .6`, `labelStyle/unselectedLabelStyle`
dérivés de `titleSmall`, `isScrollable`, `tabAlignment: TabAlignment.start`, `Tab(height: 48)`.
Après migration vers `ZSearchableAppBar`, **l'hôte doit le réécrire**. Le `_zTabBar` du socle
(`z_page_shell.dart:207-250`) n'est pas une échappatoire : il est **privé**, il n'expose ni
`indicatorColor`/`indicatorWeight`/`labelColor`, et il exige des `ZPageTab` dont `contentBuilder`
est **requis** (`z_page_tab.dart:17-21`) parce qu'il construit aussi le `TabBarView` — ce que ces
pages ne veulent pas (leur corps est un `StreamBuilder` + `ListenableBuilder` séparé).

Sites concernés dans le périmètre : `ai_experts_page.dart:59`, `auditeurs_pages.dart:85`,
`dashbord_page.dart:448`, `dashbord_page.dart:474`.

### 5.2 Normalisation de la requête — piège à régression SILENCIEUSE

Aujourd'hui, l'app-bar normalise **à la source** (`dynamic_searcheable_app_bar.dart:162-163`) :
`unaccentedText(s).replaceAll(" ","").toLowerCase()`. `ZAppBarSearchConfig` documente l'inverse,
et le code le tient : `controller.onChanged` (`z_page_shell.dart:96-99`) émet le texte **brut**.

Or les filtres du corps comparent contre du texte **déjà normalisé** —
`user_role_page.dart:89-93` : `unaccentedText(el.name).replaceAll(" ","").toLowerCase().contains(searchQuery.toLowerCase())`.
Migrer sans réinjecter la normalisation dans chaque `onQueryChanged` donne un filtre qui **ne
rougit pas** et **ne trouve rien** dès qu'il y a un espace ou un accent. L'hôte l'a déjà rencontré :
c'est exactement ce qu'il a dû réécrire à la main en `folder_details_page.dart:846-850`.

### 5.3 Animations — absentes

**Grep négatif montré** :

```
$ grep -rnE "AnimatedSwitcher|FadeTransition|ScaleTransition|AnimationController|AnimatedContainer|Tween" \
    lib/src/presentation/z_page_shell.dart lib/src/presentation/z_searchable_app_bar.dart \
    lib/src/presentation/z_page_scaffold.dart lib/src/presentation/z_page_shell_body.dart
RC=1   (aucune occurrence)
```

L'hôte en a cinq : `AnimationController` 300 ms (`:55-58`), `_fadeAnimation` easeInOut (`:59-62`),
`_scaleAnimation` Tween 0.8→1.0 easeOutBack (`:63-68`), `AnimatedSwitcher` 200 ms sur le titre
(`:249`) et sur la loupe (`:297-307`), `AnimatedContainer` 300 ms sur la largeur du champ desktop
(`:270-275`). Régression cosmétique — mais réelle, et non signalée.

---

## 6. CONDITION CACHÉE — `gradientKey` ne rend rien sans injection (hors périmètre, mais à signaler)

`ZSearchableAppBar.gradientKey` passe par `zResolveGradient`
(`zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:129-135`), dont le **corps** est :

```dart
return ZcrudScope.maybeOf(context)?.gradientResolver?.call(scheme, gradientKey);
```

Sans `ZcrudScope.gradientResolver` injecté par l'hôte ⇒ `null` ⇒ **ni `flexibleSpace` ni
`foregroundColor`**. Le legacy, lui, prend une **`Color` brute** (`baseGradientColor`,
`dynamic_searcheable_app_bar.dart:21`) et en dérive 4 arrêts (α .15/.10/.05/.02, `:216-219`). L'hôte
s'est déjà cogné à ce piège et l'a écrit : *« `gradientKey` était bien passé depuis CR-IFFD-34 […]
le résolveur est **opt-in** — nous ne l'avions jamais branché, donc la clé ne résolvait rien »*
(`folder_detail_zcrud.dart:265-275`). **Aucun des 6 sites du périmètre** n'utilise
`baseGradientColor` (seul `folder_details_page.dart:1069` le fait) — l'écart est donc hors
périmètre, mais il invalide toute généralisation de l'affirmation aux 16 sites.

Même remarque pour `backgroundColor` : `DynamicSearcheableAppBar` l'expose (`:19`),
`ZSearchableAppBar` **pas** (grep négatif §5.1). Aucun des 6 sites du périmètre ne l'utilise.

---

## 7. RÉFUTATION 5 — le chiffrage et le gain

### 7.1 « réécrite 25 fois dans 16 fichiers »

Mesuré : `grep -rn "DynamicSearcheableAppBar" lib/` ⇒ **24 occurrences**, dont **6** dans le fichier
de définition, **1** en dartdoc (`folder_detail_zcrud.dart:282`), **1** en code commenté
(`public_folders_page.dart:191`) et **1** `extends` (`folders_page.dart:1456`).

⇒ **16 instanciations réelles**, réparties sur **13 fichiers**, plus **1 sous-classe hôte**
(`FoldersAppBarBuilder`, `folders_page.dart:1456-1520+`). Ni 25, ni 16 fichiers.

Le « 6/6 dans le périmètre » **résiste** : les 6 sites sont bien
`user_role_page.dart:72`, `ai_experts_page.dart:56`, `auditeurs_pages.dart:82`,
`dashbord_page.dart:446`, `dashbord_page.dart:456` (`FoldersAppBarBuilder`),
`dashbord_page.dart:472`.

### 7.2 « ~443 lignes d'hôte supprimées »

`wc -l` ⇒ 372 + 71 = **443**. Le gain annoncé est donc *exactement* « supprimer les deux fichiers ».
Or :

* `dynamic_searcheable_app_bar.dart` (372 l.) ne peut être supprimé qu'après migration des **16**
  sites, dont **10 sont hors périmètre** (folders ×4, subjects ×2, flashcards ×1, accounting ×3).
  Migrer les 6 du périmètre supprime **0 ligne** de ce fichier.
* `dynamic_list_search_controller.dart` (71 l.) ne peut pas être supprimé : 58 lectures de
  `searchQuery` et 30 de `listFilter`/`flashcardsListFilter` en dépendent, et le socle ne modélise
  pas `listFilter` (§3).
* À l'inverse, la migration **ajoute** du code hôte : `TabBar` stylé à réécrire (~37 l. × 4 sites,
  ou un helper hôte), normalisation à réinjecter (6 × ~4 l.), porteur de query par page.

**Le gain net sur ce périmètre n'est pas ~443 lignes ; il est plausiblement négatif.**

---

## 8. Ce qui reste vrai malgré tout

* Le **socle est un bon point de départ** : `ZAppBarAction` (données), `hidesHostActions` (couvre
  exactement `FoldersAppBarBuilder`'s `controller.isSearching ? [] : [...]`,
  `folders_page.dart:1481-1482`), `Échap`, rebuild granulaire, `PopupMenuButton` résolu par
  identité, 10 créneaux `Scaffold` — tout cela est réel et supérieur au legacy.
* Le manque est **nommable en une CR** : un mode de recherche **persistant** paramétrable
  (`ZAppBarSearchConfig.persistentAbove: double?` ou équivalent), un créneau `tabs` sur
  `ZSearchableAppBar`, un `backgroundColor`, et une **couleur** de dégradé en plus de la clé.
  Sans cela, l'affirmation « le socle sait déjà le faire » est **une couverture partielle présentée
  comme totale** — donc, par la règle de ce travail, réfutée.
