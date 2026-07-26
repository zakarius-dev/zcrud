---
baseline_commit: 1cb21070d907b864a9605d2d280b9e1750a44cd0
---

# Story SUF-1 : `ZPageScaffold` / `ZSearchableAppBar` — page-shell déclaratif (FONDATION)

Status: review

<!-- Source : plan approuvé /home/zakarius/.claude/plans/tingly-brewing-cake.md § Stories › SUF-1 -->
<!-- Epic : epic-suf (E-STUDY-UI : Folders & Page-shell) — sprint-status.yaml:508-513 -->

## Story

As a **développeur d'une appli hôte de zcrud (étude, codes, home)**,
I want **un moteur de page-shell déclaratif (titre + actions en données + recherche intégrée + onglets + mode sliver optionnel), neutre et thémable**,
so that **je cesse de dupliquer le motif `SliverAppBar`/app-bar-recherchable écran par écran et j'obtiens une app-bar cohérente, RTL-safe et réactive-granulaire sans écrire de gestionnaire d'état**.

**Couvre :** exigence user n°2 du plan (« porter le système de gestion de pages / app-bars d'IFFD dans zcrud, flexible/abstrait/complet ») · **Taille :** L · **Package :** `zcrud_ui_kit` · **Dépend de :** rien (FONDATION, tête de l'epic SUF) · **Débloque :** SUF-3 (`ZStudyFolderDetail` consomme ce shell + ses tabs).

---

## 🔴 Décisions tranchées AVANT dev (vérifiées sur disque, pas sur la prose)

Chaque verdict porte sa preuve. Deux affirmations de la consigne ont été **re-vérifiées** contre le disque ; l'une est corrigée.

### D1 — Le page-shell vit dans `zcrud_ui_kit` (UI transverse), PAS dans `zcrud_navigation`

`zcrud_navigation` est le foyer de la **présentation de formulaires** (stepper/wizard), pas des pages génériques. `zcrud_ui_kit` est le kit de widgets **transverses** déjà en place (états de contenu, dialogs, toaster, index alpha, transitions) — barrel `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart`. Le shell y a exactement sa place et hérite de la contrainte d'isolation AD-29 déjà tenue par le package :

```
$ grep -A4 '^dependencies:' packages/zcrud_ui_kit/pubspec.yaml
dependencies:
  zcrud_core: ^0.18.0        ← seule arête zcrud_* (ENTRANTE au cœur)
  flutter: { sdk: flutter }
```

⇒ **Verdict** : nouveaux fichiers sous `packages/zcrud_ui_kit/lib/src/{domain,presentation}/`, exportés par le barrel. **Aucune** nouvelle dépendance (ni gestionnaire d'état, ni routeur, ni tiers). `CORE OUT=0` reste intact, graphe acyclique.

### D2 — La consigne dit « lex duplique `SliverAppBar` sur ~6 écrans » ; la réalité disque = **11 écrans** dans `packages/lex_ui/`

```
$ grep -rln "SliverAppBar" /home/zakarius/DEV/lex_douane/packages/lex_ui/lib | wc -l
11
```

(le `lib/` racine de lex n'en a aucun — tout est sous `packages/lex_ui/lib/presentation/`, dont `codes_screen.dart:79` `SliverAppBar(pinned: true, …)`, `favorites_screen.dart`, `study_comparison_screen.dart`, `playlist_details_screen.dart`, …). La duplication à factoriser est **plus large** que la consigne ne le dit — argument renforcé pour le shell, pas affaibli. **Lecture seule stricte** sur ces dépôts : aucune écriture lex/IFFD.

### D3 — Référence IFFD `DynamicSearcheableAppBar` = source d'inspiration, PAS de portage littéral (AD-2 impose une refonte de l'état)

`/home/zakarius/DEV/iffd/lib/src/presentation/core/widgets/dynamic_searcheable_app_bar.dart` (lecture seule) délègue l'état de recherche à un `DynamicListSearchController` **externe** (`controller.isSearching`, `controller.searchQuery`, `controller.searchInpuCtrl`) — c'est un gestionnaire d'état injecté depuis l'app. **Interdit ici (AD-2/AD-15)** : le cœur zcrud ne connaît aucun manager. Le shell zcrud **détient lui-même** l'état de recherche (`ValueNotifier` internes, propriétaire unique) et n'émet que via un callback `onQueryChanged`. De même le couplage `responsive_builder`/`ResponsiveBuilder` d'IFFD n'est **pas** repris : la bascule mobile/desktop du champ de recherche reste dans le shell, sans dépendance tierce (le `LayoutBuilder` de Flutter suffit ; `zcrud_responsive` n'est PAS tiré par `zcrud_ui_kit` — hors périmètre SUF-1, c'est SUF-3 côté `zcrud_study`).

---

## Acceptance Criteria

> Convention de test R3 (**NON-NÉGOCIABLE**) : chaque AC vérifiée par une garde **prouvée mordante** — le dev doit, pour chaque garde, **ré-injecter la régression correspondante** (ligne exacte + effet), constater le **rouge**, puis restaurer, et consigner l'injection (fichier:ligne + comportement observé) dans le Dev Agent Record. Une garde qui ne rougit pas quand on casse la logique est **tautologique et rejetée** (discipline R3).

### API déclarative & structure

**AC1 — Titre + leading.** `ZPageScaffold`/`ZSearchableAppBar` acceptent `title` (`Widget`, ou `String` → `Text`) et un slot `leading` (`Widget?`). Le titre est rendu ; `leading` est rendu **si et seulement si** fourni (absent structurellement sinon, aucun placeholder).
_R3 :_ passer `leading: null` ⇒ aucun widget leading dans l'arbre ; le fournir ⇒ présent. Régression ré-injectée : forcer un `SizedBox` placeholder quand `leading==null` → la garge « absent » rougit.

**AC2 — Actions DÉCLARÉES EN DONNÉES, absentes si non fournies.** `actions: List<ZAppBarAction>` (défaut `const []`). Chaque `ZAppBarAction` (`icon`, `semanticLabel`, `onPressed`, `tooltip?`, `isOverflow?`) rend **un** `IconButton` (ou une entrée de menu de débordement si `isOverflow`). Une action **non déclarée est structurellement absente** — pas de bouton fantôme.
_R3 :_ liste à 2 actions ⇒ exactement 2 icônes dans l'arbre ; retirer une entrée ⇒ son icône + son `semanticLabel` disparaissent. Régression ré-injectée : rendre un `IconButton` fixe non piloté par les données → le compte d'icônes ne suit plus la liste → rouge.

**AC3 — Action : a11y, cible ≥ 48 dp, callback.** Chaque action porte un `Semantics`/`semanticLabel` explicite (jamais nul), une cible tactile ≥ 48 dp, et `onPressed` de la **bonne** action est invoqué au tap.
_R3 :_ taper l'action d'index 1 invoque le callback d'index 1 (et pas d'index 0). Régression ré-injectée : câbler tous les boutons sur `actions.first.onPressed` → le tap sur index 1 déclenche le mauvais callback → rouge.

### Recherche intégrée (AD-2 — état détenu par le widget)

**AC4 — Bascule recherche : morphe l'app-bar en champ.** Quand `search: ZAppBarSearchConfig?` est non nul, une icône de bascule (loupe) est présente ; la taper **morphe** l'app-bar en champ de recherche (le `TextField` apparaît, autofocus) ; re-bascule / `Échap` restaure l'app-bar normale (titre re-rendu, champ retiré).
_R3 :_ tap bascule ⇒ `TextField` trouvable ; second tap ⇒ `TextField` absent + titre re-rendu. Régression ré-injectée : figer `_isSearching=false` → le champ n'apparaît jamais → rouge.

**AC5 — Émission de la query.** Saisir du texte dans le champ met à jour la `ValueListenable<String>` **détenue par le widget** ET invoque `onQueryChanged(text)` avec la valeur exacte.
_R3 :_ `enterText('abc')` ⇒ dernière valeur émise == `'abc'` ET `queryListenable.value == 'abc'`. Régression ré-injectée : ne pas rebrancher `onChanged` du `TextField` → la valeur émise reste `''` → rouge.

**AC6 — Query = propriétaire unique + rebuild GRANULAIRE (AD-2/SM-1).** L'état de recherche (`isSearching`, `query`) est détenu par un `ValueNotifier`/`ChangeNotifier` **interne** au widget — **aucun** gestionnaire d'état importé, **aucun** contrôleur externe requis. La frappe reconstruit **seulement** la tranche app-bar (via `ValueListenableBuilder`), **jamais** le corps des onglets.
_R3 :_ compteur de rebuild dans le `builder` d'un onglet ⇒ inchangé pendant qu'on tape 20 caractères dans la recherche. Régression ré-injectée : remonter la query dans un `setState` à l'échelle du scaffold → le compteur du corps s'incrémente → rouge. (garde SM-1)

**AC7 — Fermeture/Échap restaure ET vide.** Fermer la recherche (icône close, `Échap`, ou `leading` retour) **vide** le champ, remet `query=''`, émet `onQueryChanged('')` et restaure le titre.
_R3 :_ après saisie puis close ⇒ `query==''`, dernière émission `''`, titre visible. Régression ré-injectée : close sans reset de la query → `query` conserve l'ancien texte → rouge.

**AC8 — Recherche absente si non configurée.** `search == null` ⇒ aucune icône de bascule, aucun champ possible, jamais.
_R3 :_ `search:null` ⇒ finder icône loupe = `findsNothing`. Régression ré-injectée : rendre la loupe inconditionnellement → rouge.

### Onglets

**AC9 — Tabs rendent le bon contenu.** `tabs: List<ZPageTab>?` (`label`, `icon?`, `contentBuilder`) ⇒ un `TabBar` de N onglets + un `TabBarView` affichant le contenu de l'onglet sélectionné ; basculer d'onglet affiche l'autre contenu.
_R3 :_ contenu A visible à l'index 0 ; tap onglet 1 ⇒ contenu B visible, A absent. Régression ré-injectée : câbler tous les onglets sur `tabs.first.contentBuilder` → le tap sur l'onglet 1 laisse A → rouge.

**AC10 — TabBar scrollable + tabs absents si non fournis.** `TabBar` en `isScrollable: true` (jeu d'onglets large sans overflow) ; `tabs` null/vide ⇒ **aucun** `TabBar` dans l'arbre.
_R3 :_ `tabs:null` ⇒ `find.byType(TabBar) == findsNothing` ; 8 onglets ⇒ pas d'exception d'overflow. Régression ré-injectée : rendre un `TabBar` vide quand `tabs==null` → rouge.

### Mode SliverAppBar vs fixe

**AC11 — Mode sliver se replie ; mode fixe ne se replie pas.** Un `mode` déclaratif (enum `ZPageAppBarMode { fixed, floating, pinned, floatingPinned }`) : en mode `floating`/`pinned`/`floatingPinned` le shell rend un `SliverAppBar` dans un `CustomScrollView`/`NestedScrollView` qui **se replie au défilement** (extent décroît) ; `pinned`/`floatingPinned` gardent l'app-bar visible ; `fixed` rend une app-bar Material classique **sans repli**.
_R3 :_ mesurer l'extent de l'app-bar avant/après un scroll : en `floating` l'extent **diminue** ; en `fixed` il **reste constant** (et aucun `SliverAppBar` dans l'arbre). Régression ré-injectée : forcer `pinned:true, floating:false` en mode `floating` → l'extent ne diminue plus → la garde « se replie » rougit ; inversement, injecter un `SliverAppBar` en mode `fixed` → la garde « pas de sliver en fixe » rougit.

### Neutralité / thème / l10n / a11y-RTL (AD-13, AD-29)

**AC12 — Neutre thémable, zéro couleur codée en dur.** Toutes les couleurs/typo dérivent de `Theme.of(context)`/`ColorScheme` ou du thème injecté `ZcrudTheme.of(context)` (repli `Theme.of`). **Aucun** littéral `Color(0x…)`/`Colors.<x>` (hors `Colors.transparent`) dans les fichiers de la story.
_R3 :_ garde statique (scan source du dossier de la story) : `grep` de `Color(0x`/`Colors.` (sauf `transparent`) ⇒ 0 hit. Régression ré-injectée : coder un `Colors.blue` en dur → la garde statique rougit. + garde runtime : rendu identique light/dark piloté par le `ColorScheme` fourni.

**AC13 — l10n par labels injectés.** Le `hintLabel` du champ de recherche et les tooltips (loupe/close/back) sont résolus par la chaîne **`ZcrudScope.maybeOf(context)?.labels?.maybeResolve(<clé>)` → `ZcrudLocalizations.maybeOf(context)?.maybeResolve(<clé>)` → repli `MaterialLocalizations`** (clés réutilisées : `'search'`, `'close'` — déjà présentes, `z_localizations.dart:35,54,126,145`). `ZAppBarSearchConfig.hintLabel` (surcharge explicite optionnelle) prime si fourni. Jamais de chaîne codée en dur.
_R3 :_ injecter `ZcrudLabels({'search':'ZZZ'})` via `ZcrudScope` ⇒ le hint affiche `ZZZ`. Régression ré-injectée : coder `'Rechercher'` en dur dans le `hintText` → l'override `ZZZ` n'apparaît plus → rouge.

**AC14 — RTL + a11y (AD-13).** Sous `Directionality(textDirection: TextDirection.rtl)`, le shell se miroite correctement : insets/positions **directionnels** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) — **jamais** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right`. Toutes les cibles interactives ≥ 48 dp ; `Semantics` explicites sur bascule et actions ; `const` partout où l'immuabilité le permet.
_R3 :_ (a) garde statique : scan source ⇒ 0 hit des formes non directionnelles interdites ; (b) garde runtime : sous RTL le `leading` s'ancre côté droit visuel (position mesurée). Régression ré-injectée : remplacer un `EdgeInsetsDirectional.only(start:)` par `EdgeInsets.only(left:)` → la garde statique + la garde de position RTL rougissent.

### Isolation & non-régression du package

**AC15 — Isolation deps (AD-1/AD-29) + barrel.** `packages/zcrud_ui_kit/pubspec.yaml` reste inchangé côté dépendances (seul `zcrud_core` + `flutter`) ; aucun `import` de gestionnaire d'état / routeur / tiers UI / `dartz` dans les nouveaux fichiers ; les nouveaux types publics (`ZPageScaffold`, `ZSearchableAppBar`, `ZAppBarAction`, `ZAppBarSearchConfig`, `ZPageTab`, `ZPageAppBarMode`) sont exportés par `lib/zcrud_ui_kit.dart` et **rien de `zcrud_core` n'est redéclaré/ré-exporté**. `graph_proof` reste ACYCLIQUE, `CORE OUT=0`.
_R3 :_ garde d'import (scan des nouveaux fichiers) ⇒ 0 hit de `package:get/`, `flutter_riverpod`, `provider`, `go_router`, `dartz`, etc. ; `melos run verify` / `graph_proof` verts. Régression ré-injectée : `import 'package:get/get.dart';` dans un fichier de la story → la garde d'import rougit (et `analyze` casse).

---

## Tasks / Subtasks

- [x] **T1 — Value objects déclaratifs** (AC1, AC2, AC9, AC11)
  - [x] `lib/src/domain/z_app_bar_action.dart` : `@immutable class ZAppBarAction` (`IconData icon`, `String semanticLabel`, `VoidCallback? onPressed`, `String? tooltip`, `bool isOverflow = false`) + `==`/`hashCode` par contenu.
  - [x] `lib/src/domain/z_app_bar_search_config.dart` : `@immutable class ZAppBarSearchConfig` (`ValueChanged<String> onQueryChanged`, `String? hintLabel`, `String initialQuery = ''`).
  - [x] `lib/src/domain/z_page_tab.dart` : `@immutable class ZPageTab` (`String label`, `IconData? icon`, `WidgetBuilder contentBuilder`).
  - [x] `lib/src/domain/z_page_app_bar_mode.dart` : `enum ZPageAppBarMode { fixed, floating, pinned, floatingPinned }` (jamais un couple de `bool` — NFR-U7).
- [x] **T2 — `ZSearchableAppBar` (StatefulWidget, état détenu)** (AC1–AC8, AC12–AC14)
  - [x] `lib/src/presentation/z_searchable_app_bar.dart` : `_ZSearchController` (dans `z_page_shell.dart`) possède `ValueNotifier<bool> _isSearching`, `ValueNotifier<String> query`, `TextEditingController` + `FocusNode` (créés en `initState`, `dispose`és). État de test exposé en lecture via `ZSearchableAppBarState.queryListenable`.
  - [x] Rendu via `ValueListenableBuilder` (tranche app-bar seule) : titre ↔ champ ; loupe/close/back en `IconButton` ≥ 48 dp + `Semantics` ; actions mappées depuis `List<ZAppBarAction>` (débordement → `PopupMenuButton`) ; hint/tooltips par labels injectés ; insets directionnels.
  - [x] `implements PreferredSizeWidget` pour l'usage `Scaffold(appBar:)` en mode `fixed`.
  - [x] `Échap` (`CallbackShortcuts` + `SingleActivator(LogicalKeyboardKey.escape)`) + close ⇒ reset query + collapse + `onQueryChanged('')`.
- [x] **T3 — `ZPageScaffold` (assemblage + tabs + modes)** (AC9–AC11)
  - [x] `lib/src/presentation/z_page_scaffold.dart` : compose `title`/`leading`/`actions`/`search`/`tabs`/`body`/`mode`. Propriétaire du `TabController` (via `DefaultTabController` interne) sauf `tabController` injecté.
  - [x] Mode `fixed` : `Scaffold(appBar: ZSearchableAppBar(...), body: TabBarView | body)`.
  - [x] Modes sliver : `NestedScrollView` (avec onglets) / `CustomScrollView` (sans) + `SliverAppBar(floating/pinned selon mode, bottom: TabBar)` + corps `TabBarView`.
  - [x] Rendu titre/actions/recherche **factorisé** entre `ZSearchableAppBar` et le `SliverAppBar` via `_zBuildLeading`/`_zBuildTitle`/`_zBuildActions` + `_ZSearchController` (fonctions privées de la même bibliothèque `z_page_shell.dart`, partagées par `part`).
- [x] **T4 — Barrel & pubspec** (AC15)
  - [x] Exporté les 6 types dans `lib/zcrud_ui_kit.dart` (+ dartdoc de tête cohérente avec le style du barrel existant).
  - [x] `pubspec.yaml` inchangé côté deps (`zcrud_core` + `flutter` seuls) ; scan d'imports interdits vert.
- [x] **T5 — Tests R3** (toutes ACs) — 22 tests ajoutés.
  - [x] `test/z_searchable_app_bar_test.dart` (AC1–AC5, AC7, AC8, AC13), `test/z_page_scaffold_tabs_test.dart` (AC9–AC10), `test/z_page_scaffold_sliver_test.dart` (AC11), `test/z_page_shell_rtl_a11y_test.dart` (AC14), `test/z_page_shell_sm1_test.dart` (AC6 rebuild granulaire), `test/z_page_shell_source_guard_test.dart` (AC12/AC14 statique + AC15 imports).
  - [x] Pour CHAQUE AC : injection de régression jouée, rouge capturé, restauration, consigné dans le Dev Agent Record (verdicts R3 ci-dessous).
- [x] **T6 — Vérif verte rejouée** : `dart analyze packages/zcrud_ui_kit` RC=0 → `flutter test` (package) RC=0 (109/109) → `graph_proof.py` ACYCLIQUE, `CORE OUT=0`. (`melos run generate` non requis : aucune annotation `@ZcrudModel` — widgets Flutter purs, aucun `*.g.dart`.)

---

## Dev Notes

### Patrons EXISTANTS à réutiliser (ne rien réinventer)

- **Résolution de label** (copier le patron exact de `z_state_widgets.dart:88-91`) :
  ```dart
  ZcrudScope.maybeOf(context)?.labels?.maybeResolve('search')
    ?? ZcrudLocalizations.maybeOf(context)?.maybeResolve('search')
    ?? MaterialLocalizations.of(context).searchFieldLabel;
  ```
  Clés déjà présentes : `'search'` (`z_localizations.dart:35`/`:126`), `'close'` (`:54`/`:145`), `'clear'`, `'cancel'`. Ne PAS ajouter de clé si une existante convient.
- **Thème injecté** : `ZcrudTheme.of(context)` avec repli `Theme.of(context)` (patron `z_state_widgets.dart:156`). Le shell n'a a priori pas besoin de token custom ⇒ `ColorScheme`/`textTheme` suffisent.
- **Style du barrel & dartdoc** : aligner sur `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (dartdoc de tête décrivant chaque type + rappel AD-2/AD-29).
- **Garde RTL/a11y existante** : `packages/zcrud_ui_kit/test/z_rtl_a11y_test.dart` — étendre ou dupliquer son approche (scan des formes non-directionnelles + assertions de position).

### Référence IFFD (LECTURE SEULE) — quoi garder, quoi refuser

`iffd/.../dynamic_searcheable_app_bar.dart` :
- **Garder l'idée** : morphing titre↔champ (`AnimatedSwitcher`), bascule mobile (icône loupe/close) vs champ desktop toujours visible, `TabBar` `isScrollable` en `bottom:`, `centerTitle:false`.
- **Refuser** (AD-2/AD-15) : l'état de recherche porté par un `DynamicListSearchController` **externe** (`controller.isSearching/searchQuery/searchInpuCtrl`) → **détenir l'état dans le widget** ; le tiers `responsive_builder`/`ResponsiveBuilder` → utiliser `LayoutBuilder` de Flutter ; `unaccentedText(...)` (util IFFD) → hors périmètre (l'app normalise si besoin, le shell émet le texte brut).

### Référence lex_douane (LECTURE SEULE) — motif à factoriser

11 écrans sous `packages/lex_ui/lib/presentation/` dupliquent `SliverAppBar` (ex. `codes_screen.dart:79` `SliverAppBar(pinned:true, …)` avec `bottom:` filtres). Le mode sliver de SUF-1 doit couvrir ce cas (pinned + bottom widget). **Aucune écriture dans lex** — l'adoption (bridge) est app-side, hors périmètre (cf. plan § Hors périmètre).

### Contraintes AD (rappels NON-NÉGOCIABLES applicables ici)

- **AD-2/AD-15** : aucun gestionnaire d'état dans le widget ; état de recherche/onglets = propriétaire **unique** (le widget) ; rebuilds **granulaires** (`ValueListenableBuilder` sur la seule tranche app-bar) ; `TextEditingController`/`FocusNode`/`TabController` créés une fois (create/dispose), jamais recréés au rebuild ; `ValueKey` stable pour les zones conditionnelles (titre vs champ, `key: ValueKey(isSearching)`).
- **AD-13** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start-end` uniquement ; `Semantics` explicites ; cibles ≥ 48 dp ; `const` où possible.
- **AD-29** : `zcrud_ui_kit` dépend **uniquement** de `zcrud_core` (+ flutter) ; ne redéclare/ré-exporte **aucun** symbole de `zcrud_core` ; **aucun** tiers/routeur/manager/`dartz`.
- **AD-10** : replis sûrs, jamais de `throw` sur un scope/label absent (chaîne de repli jusqu'à `MaterialLocalizations`).

### Discipline de test R3 (falsifiabilité)

Un test qui ne rougit pas quand la logique casse est **rejeté**. Pour AC6 (SM-1) attention au piège documenté en SU-8 (Dev Agent Record su-8, « test SM-1 infalsifiable ») : compter les rebuilds du **corps d'onglet** (pas de l'app-bar) et prouver qu'il **reste constant** pendant la frappe, ET que l'injection `setState`-global le fait bien monter. Chaque injection consignée : chemin\:ligne modifié + symptôme rouge observé.

### Project Structure Notes

- Nouveaux fichiers uniquement sous `packages/zcrud_ui_kit/lib/src/{domain,presentation}/` + `test/`. **Aucune** écriture `zcrud_core` (l'epic SUF n'en écrit aucun — plan §36-37, §135). Aucun `*.g.dart` attendu (pas d'annotation `@ZcrudModel` — widgets Flutter purs) ⇒ `melos run generate` ne doit rien changer pour ce package.
- Bump de version restreint aux `zcrud_*` en fin d'epic (géré par l'orchestrateur, PAS dans cette story).

### References

- [Source: /home/zakarius/.claude/plans/tingly-brewing-cake.md#SUF-1] — spec déclarative complète.
- [Source: packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart] — barrel & style dartdoc à suivre.
- [Source: packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:88-91,156] — patron résolution label + thème injecté.
- [Source: packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:35,54,126,145] — clés `search`/`close`.
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:51,205,218] — `ZcrudScope.of/maybeOf`, `labels`, `theme`.
- [Source: packages/zcrud_core/lib/src/presentation/l10n/z_labels.dart] — `ZcrudLabels.maybeResolve` (injection de test AC13).
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/core/widgets/dynamic_searcheable_app_bar.dart] — référence LECTURE SEULE (inspiration, pas portage).
- [Source: /home/zakarius/DEV/lex_douane/packages/lex_ui/lib/presentation/screens/codes_screen.dart:79] — motif `SliverAppBar` dupliqué (11 écrans) à factoriser.
- [Source: packages/zcrud_ui_kit/test/z_rtl_a11y_test.dart] — garde RTL/a11y existante à étendre.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (agent BMAD `bmad-dev-story`, skill réel invoqué via le tool `Skill`).

### Debug Log References

- `ValueListenable` non surfacé par `package:flutter/material.dart` dans ce contexte → import explicite `package:flutter/foundation.dart show ValueListenable` ajouté à `z_page_shell.dart`.
- Mesure du repli de la `SliverAppBar` (AC11) : la lecture directe du `RenderSliver` via `find.byType(SliverAppBar)` devient ambiguë (`Iterable.single`) une fois l'app-bar `floating` sortie du champ. Remplacé par une mesure **stable** de la position verticale du titre (`getTopLeft(...).dy`, `null` si hors arbre) — `floating` : 14.0 → `null` (replié) ; `pinned`/`floatingPinned` : 14.0 → 14.0 (visible).
- Architecture de partage : `z_searchable_app_bar.dart` et `z_page_scaffold.dart` sont des `part of 'z_page_shell.dart'` — le contrôleur d'état `_ZSearchController` et les constructeurs de tranches `_zBuild*` restent **library-private** (underscore) tout en étant partagés entre le mode fixe et le mode sliver (aucune re-duplication du motif app-bar). Barrel : `export 'src/presentation/z_page_shell.dart'` (les deux widgets + leurs types).

### Completion Notes List

**Discipline R3 — garde mordante prouvée pour CHAQUE AC** (injection exacte → ROUGE observé → restauration → VERT) :

| AC | Régression injectée (fichier) | Effet observé (ROUGE) |
|----|-------------------------------|-----------------------|
| AC1 | `_zBuildLeading` : `return leading` → `return leading ?? const SizedBox.shrink()` (`z_page_shell.dart`) | `AppBar.leading` non nul quand `leading==null` → test AC1 rouge |
| AC2 | `_zBuildActions` : ajout d'un `IconButton` fixe non piloté par les données | compte d'icônes 2→3 → test AC2 rouge |
| AC3 | `_zBuildActions` : `onPressed: action.onPressed` → `inline.first.onPressed` | tap index 1 déclenche callback 0 → test AC3 rouge |
| AC4 | `_ZSearchController.open()` → no-op (isSearching figé à false) | `TextField` n'apparaît jamais → test AC4 rouge |
| AC5 | `_zBuildTitle` : retrait de `onChanged: controller.onChanged` | valeur émise reste `''` → test AC5 rouge |
| AC6 (SM-1) | `_buildFixed` : `onQueryChanged` enveloppé d'un `setState(() {})` à l'échelle du scaffold | corps d'onglet reconstruit à chaque frappe (compteur ↑) → test SM-1 rouge (falsifiabilité prouvée, piège SU-8 évité) |
| AC7 | `_ZSearchController.close()` : retrait du reset (`clear`/`query=''`/émission) | `query` conserve l'ancien texte → test AC7 rouge |
| AC8 | `_zBuildActions` : `if (search != null)` → `if (search != null || true)` | loupe rendue inconditionnellement → test AC8 rouge |
| AC9 | `_buildTabBarView` : tous les onglets sur `tabs.first.contentBuilder` | tap onglet 1 laisse contenu A → test AC9 rouge |
| AC10 | `_buildFixed` : `TabBar` vide rendu quand `tabs==null` (dans un `DefaultTabController`) | `find.byType(TabBar)` non vide → test AC10 rouge |
| AC11 | `_sliverAppBar` : `floating=false, pinned=true` forcés en mode `floating` | app-bar ne se replie plus (titre reste) → test AC11 floating rouge |
| AC12 | `_zBuildActions` : `color: Colors.blue` codé en dur | garde statique `Colors.<x>` → test AC12 rouge |
| AC13 | `_zBuildTitle` : `hintText` codé `'Rechercher'` | override `ZZZ`/`hintLabel` ignoré → tests AC13 rouges |
| AC14 | `_zBuildTitle` : `TextAlign.start` → `TextAlign.left` | garde statique non-directionnelle → test AC14 rouge |
| AC15 | `z_page_shell.dart` : `import 'package:get/get.dart'` | garde d'imports interdits → test AC15 rouge |

Toutes les régressions **restaurées** ; suite **verte** après restauration (109/109).

**Vérif verte réelle rejouée sur disque** :
- `dart analyze packages/zcrud_ui_kit` (lib + test) → **RC=0**, "No issues found!".
- `flutter test` (package `zcrud_ui_kit`) → **RC=0**, **109/109** (dont **22 nouveaux** tests SUF-1).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK** ; unique arête sortante `zcrud_ui_kit -> zcrud_core`.
- `pubspec.yaml` du package **inchangé** côté dépendances (`zcrud_core` + `flutter` seuls) ; **aucun** `*.g.dart` généré/attendu (widgets Flutter purs, aucune annotation).

**Décisions de conception notables** :
- `title` typé `Object` avec `assert(title is Widget || title is String)` → satisfait AC1 (« `Widget`, ou `String` → `Text` ») sans double constructeur.
- État de recherche 100 % détenu par le widget (`_ZSearchController`), aucun contrôleur externe requis (AD-2/AD-15). Rebuild **plus** granulaire qu'exigé : la frappe ne reconstruit **ni** le corps **ni** l'app-bar (seule la bascule `isSearching` reconstruit la tranche app-bar).
- `ZSearchableAppBarState` rendu public **uniquement** comme seam de test R3 (`@visibleForTesting ValueListenable<String> get queryListenable`) — aucune mutation exposée ; la surface déclarative reste les 6 types de l'AC15.

### File List

**Créés :**
- `packages/zcrud_ui_kit/lib/src/domain/z_app_bar_action.dart`
- `packages/zcrud_ui_kit/lib/src/domain/z_app_bar_search_config.dart`
- `packages/zcrud_ui_kit/lib/src/domain/z_page_tab.dart`
- `packages/zcrud_ui_kit/lib/src/domain/z_page_app_bar_mode.dart`
- `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart` (bibliothèque + `_ZSearchController` + `_zBuild*`)
- `packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart` (`part of z_page_shell.dart`)
- `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart` (`part of z_page_shell.dart`)
- `packages/zcrud_ui_kit/test/z_searchable_app_bar_test.dart`
- `packages/zcrud_ui_kit/test/z_page_scaffold_tabs_test.dart`
- `packages/zcrud_ui_kit/test/z_page_scaffold_sliver_test.dart`
- `packages/zcrud_ui_kit/test/z_page_shell_sm1_test.dart`
- `packages/zcrud_ui_kit/test/z_page_shell_rtl_a11y_test.dart`
- `packages/zcrud_ui_kit/test/z_page_shell_source_guard_test.dart`

**Modifiés :**
- `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (barrel : dartdoc SUF-1 + 6 exports)
