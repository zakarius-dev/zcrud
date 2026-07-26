# Code-review epic SUF — lentille « SM-1 / perf »

**Date** : 2026-07-26
**Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2 / SUF-3 (`zcrud_study`), SUF-4 (`zcrud_session`)
**Hors périmètre (non revu, non touché)** : `packages/zcrud_markdown/`
**Mode** : lecture seule — aucun fichier de `lib/` ni de `test/` modifié par cette revue.

**Verdict global : RÉSERVES** — 1 HIGH (crash reproductible), 1 MAJEUR (dispatch sur un
callback périmé), 2 MEDIUM (rebuilds non granulaires contredisant la dartdoc), 1 LOW.

---

## Méthode et contrainte de preuve

Toute affirmation ci-dessous est soit un extrait de disque avec numéro de ligne, soit un
grep dont le RC est donné, soit une exécution réelle.

### Sondes exécutées (fichiers HORS de l'arbre du dépôt, jamais committés)

Les sondes vivent dans le scratchpad de session et sont exécutées avec le `package_config`
du workspace :

```
/tmp/claude-1000/-home-zakarius-DEV-zcrud/39909dce-.../scratchpad/uikit_probe_test.dart
/tmp/claude-1000/-home-zakarius-DEV-zcrud/39909dce-.../scratchpad/uikit_probe2_test.dart
/tmp/claude-1000/-home-zakarius-DEV-zcrud/39909dce-.../scratchpad/sm1_probe_test.dart
```

### Limite déclarée : `zcrud_study` NON compilable au moment de la revue

La sonde SM-1 destinée à mesurer les rebuilds d'items pendant le drag de redimensionnement
(`sm1_probe_test.dart`) **n'a pas pu être exécutée** :

```
$ cd packages/zcrud_study && flutter test <scratchpad>/sm1_probe_test.dart
../zcrud_markdown/lib/src/data/z_markdown_codec.dart:1:11: Error: Expected a declaration, but got ''image''.
../zcrud_markdown/lib/src/domain/z_markdown_bridge.dart:23:1: Error: The non-ASCII character '↔' ...
```

`zcrud_study` dépend (transitivement) de `zcrud_markdown`, dont l'état transitoire est
**explicitement hors périmètre** (workstream parallèle). Les findings F3/F4/F5 sont donc
prouvés **structurellement** (code + source du SDK Flutter), pas empiriquement — c'est
signalé sur chacun.

### Suite `zcrud_ui_kit` rejouée

```
$ cd packages/zcrud_ui_kit && flutter test
00:09 +108 -1: Some tests failed.
Failing tests:
  .../test/zz_tmp_ad_probe_test.dart: loading .../zz_tmp_ad_probe_test.dart
```

108 tests verts. Le seul échec est `zz_tmp_ad_probe_test.dart`, **fichier temporaire d'un
autre agent de revue** (absent du `git status` initial, non listé au périmètre SUF-1) — pas
un finding de cette lentille, mais à supprimer avant le gate de commit d'epic.

---

## Ce qui est CONFORME (vérifié, pas supposé)

| Point de la lentille | État | Preuve |
|---|---|---|
| 3 `ValueNotifier` de `ZStudyFolderDetail` créés en `initState` | ✅ | `z_study_folder_detail.dart:180-185` |
| … et disposés en `dispose` | ✅ | `z_study_folder_detail.dart:187-193` (les 3, avant `super.dispose()`) |
| État de recherche de `ZSearchableAppBar` créé une fois | ✅ | `z_page_shell.dart:57-64` (`ZSearchableAppBarState.initState`) |
| … et disposé (notifiers + `TextEditingController` + `FocusNode`) | ✅ | `z_page_shell.dart:87-92` |
| `_ZSearchController` de `ZPageScaffold` disposé | ✅ | `z_page_scaffold.dart:78-82` |
| Aucun `setState` dans les widgets du périmètre | ✅ | `grep -rn "setState" packages/zcrud_ui_kit/lib .../z_study_folder_detail.dart .../z_subfolder*.dart .../z_folder_card.dart` → seul hit = un **commentaire** (`z_study_folder_detail.dart:25`) |
| Aucun `ListView(children:)` | ✅ | `grep -rn "ListView("` sur les fichiers du périmètre → seuls hits = **commentaires** (`z_subfolder_compact_selector.dart:57`, `z_session_quality_breakdown.dart:15`, `z_session_summary_view.dart:432`) |
| Frappe ⇒ ne reconstruit pas le corps d'onglet | ✅ | `z_page_shell_sm1_test.dart` vert (mordant : le compteur `bodyBuilds` est vérifié `> 0` avant la frappe) |
| Liste des sous-dossiers virtualisée (sidebar) | ✅ | `z_subfolder_sidebar.dart:197` / `:221` — `ReorderableListView.builder` / `ListView.builder` |
| `ValueListenableBuilder` en tête de `slivers` (`ZPageScaffold`) | ✅ non-défaut | `ValueListenableBuilder` est un `ComponentElement` : transparent pour le `Viewport`, qui descend jusqu'au premier `RenderObject` (= le `RenderSliver` de `SliverAppBar`). Confirmé par `z_page_scaffold_sliver_test.dart` vert (3 modes sliver). |
| SUF-4 (`zcrud_session`) : props additives, aucun état ajouté | ✅ | `git diff packages/zcrud_session/` — les 4 fichiers n'ajoutent que des champs `final` sur des `StatelessWidget` + un pass-through ; aucun controller, aucun notifier, aucune boucle. |

---

## FINDINGS

### F1 — HIGH — `ZPageScaffold` **crashe** quand `mode` passe de `fixed` à un mode sliver

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:146`

Le contrôleur de recherche n'est instancié **qu'à `initState`, et seulement si le mode
initial est sliver** :

```dart
// z_page_scaffold.dart:72-76
@override
void initState() {
  super.initState();
  if (_isSliver) _controller = _ZSearchController(widget.search);
}
```

`_sliverAppBar` le déréférence en `!` sans repli :

```dart
// z_page_scaffold.dart:145-146
return ValueListenableBuilder<bool>(
  valueListenable: _controller!.isSearching,
```

Il n'existe **aucun** `didUpdateWidget` dans le package :

```
$ grep -rn "didUpdateWidget" packages/zcrud_ui_kit/lib/
RC=1        (aucun hit)
```

⇒ si un hôte fait vivre le même `ZPageScaffold` et change `mode` (cas d'usage direct : app-bar
sliver en mobile / fixe en desktop, exactement le genre de bascule que `ZResponsiveLayout`
encourage ailleurs dans le dépôt), `_controller` vaut `null` au `build` et le shell explose.

**Preuve d'exécution** (sonde `uikit_probe2_test.dart`, `flutter test` depuis
`packages/zcrud_ui_kit`) :

```
PROBE C2 ERR: Null check operator used on a null value
#0      _ZPageScaffoldState._sliverAppBar (package:zcrud_ui_kit/src/presentation/z_page_scaffold.dart:146:35)
#1      _ZPageScaffoldState._buildSliver  (package:zcrud_ui_kit/src/presentation/z_page_scaffold.dart:192:11)
#2      _ZPageScaffoldState.build         (package:zcrud_ui_kit/src/presentation/z_page_scaffold.dart:86:19)
PROBE C2 nbErreurs=1
```

Le sens inverse (sliver → fixed) est sain : `PROBE D err=null`.

**Correctif suggéré (à l'orchestrateur)** : créer le contrôleur paresseusement dans
`_sliverAppBar` (`_controller ??= _ZSearchController(widget.search)`) ou l'instancier
inconditionnellement en `initState` — le coût est un `ValueNotifier` + un
`TextEditingController` inutilisés en mode fixe, ce qui est négligeable devant un crash.

---

### F2 — MAJEUR — la config de recherche est **gelée à `initState`** : la frappe est émise vers un callback mort

**Fichiers** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:44,51,63` et
`z_page_scaffold.dart:75`

`_ZSearchController` capture la config **par valeur, une fois** :

```dart
// z_page_shell.dart:43-51
class _ZSearchController {
  _ZSearchController(this._config)
      : _isSearching = ValueNotifier<bool>(false),
        query = ValueNotifier<String>(_config?.initialQuery ?? ''),
        ...
  final ZAppBarSearchConfig? _config;
```

et `onChanged` émet vers **ce** `_config` :

```dart
// z_page_shell.dart:70-73
void onChanged(String text) {
  query.value = text;
  _config?.onQueryChanged(text);
}
```

Comme il n'existe aucun `didUpdateWidget` (grep RC=1 ci-dessus), un rebuild du parent avec une
nouvelle `ZAppBarSearchConfig` laisse le contrôleur branché sur l'ancienne.

**Aggravant — incohérence interne** : le *rendu* suit la config **fraîche**, l'*émission* suit
la config **périmée**, parce que `_zBuildTitle` lit `search.hintLabel` sur `widget.search`
(`z_page_shell.dart:141-142`) alors que `onChanged` passe par `controller._config`. L'app-bar
affiche donc le placeholder du nouvel écran tout en envoyant la frappe à l'ancien handler.

**Preuve d'exécution** (sonde `uikit_probe_test.dart`) :

```
PROBE A vieux=[a, ab] neuf=[]     <- 'ab' tapé APRÈS remplacement de la config
PROBE B hint=H2                   <- le hint, lui, a bien suivi la nouvelle config
```

`initialQuery` de la nouvelle config est ignorée pour la même raison.

Le chemin est réel dans l'epic : `ZStudyFolderDetail` re-transmet `widget.search` à chaque
`build` (`z_study_folder_detail.dart:214`) ; tout hôte dont le callback capture de l'état
(`(q) => _filter(folderId, q)`) perd la frappe dès que cet état change.

**Correctif suggéré** : soit lire la config au moment de l'émission
(`_ZSearchController` reçoit un `ZAppBarSearchConfig? Function()` / le `State` appelle
`widget.search?.onQueryChanged(text)`), soit ajouter un `didUpdateWidget` qui réaffecte la
config (champ non-`final`).

---

### F3 — MEDIUM — le drag de redimensionnement reconstruit **toute** la sidebar, pas « le chrome »

**Fichier** : `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:329-348`

La dartdoc du fichier affirme :

```dart
// z_study_folder_detail.dart:20-22
/// - `_sidebarWidth` (`ValueNotifier<double>`) : la largeur ne reconstruit QUE
///   le chrome de la sidebar.
```

Le code ne tient pas cette promesse. Le `ValueListenableBuilder<double>` **n'utilise pas** son
paramètre `child` (`builder: (context, width, _)`) et reconstruit l'intégralité du sous-arbre à
chaque frame de drag :

```dart
// z_study_folder_detail.dart:329-348
return ValueListenableBuilder<double>(
  valueListenable: _sidebarWidth,
  builder: (context, width, _) {
    final clamped = width.clamp(...).toDouble();
    return SizedBox(
      width: clamped,
      child: ZSubfolderSidebar( ... ),   // <- nouvelle instance à CHAQUE frame
    );
  },
);
```

Chaîne de propagation, vérifiée sur disque :

1. `ZSubfolderSidebar` est un `StatelessWidget` (`z_subfolder_sidebar.dart:51`) : nouvelle
   instance ⇒ `build()` rejoué ⇒ `_buildExpanded` (`:136`) ⇒ `_list()` (`:194`).
2. `_list()` retourne un **nouveau** `ListView.builder` / `ReorderableListView.builder`
   (`:197`, `:221`), donc un **nouveau** `SliverChildBuilderDelegate`.
3. Le SDK force alors le rebuild de **tous** les enfants montés :

```
$ grep -rn "shouldRebuild" /home/zakarius/flutter/packages/flutter/lib/src/widgets/scroll_delegate.dart
579:  bool shouldRebuild(covariant SliverChildBuilderDelegate oldDelegate) => true;

/home/zakarius/flutter/packages/flutter/lib/src/widgets/sliver.dart:945-956
void update(covariant SliverMultiBoxAdaptorWidget newWidget) { ...
  if (newDelegate != oldDelegate && (... || newDelegate.shouldRebuild(oldDelegate))) {
    performRebuild();
  }
}
```

4. `itemBuilder` est donc ré-invoqué pour chaque item visible, ce qui reconstruit chaque
   `_SubfolderRow` **et** rappelle le `spec.itemBuilder` **injecté par l'hôte**
   (`z_subfolder_sidebar.dart:339-343`) — un builder dont zcrud ne contrôle pas le coût.

À 60 fps, redimensionner la sidebar rejoue donc N `itemBuilder` d'hôte par frame. C'est
exactement le motif de jank que l'objectif produit n°1 combat.

**Aucun test ne couvre ce chemin** — grep négatif sur la suite SM-1 :

```
$ grep -rn "resizeHandleKey" packages/zcrud_study/test/z_study_folder_detail_sm1_test.dart
RC=1        (aucun hit)
```

`z_subfolder_sidebar_test.dart:15-47` exerce bien le drag, mais uniquement pour vérifier le
**clamp** des bornes — jamais un compteur de rebuild. L'AC14 « rebuilds granulaires » n'est
donc prouvée que pour la sélection et le repli, pas pour la largeur.

**Statut de preuve** : structurelle (code + source SDK). La vérification empirique est
bloquée par la non-compilation de `zcrud_markdown` (cf. limite déclarée).

**Correctif suggéré** : passer la sidebar en `child:` du `ValueListenableBuilder<double>` et
n'y laisser que le `SizedBox` ; la largeur dont `_resizeHandle` a besoin
(`z_subfolder_sidebar.dart:280`) peut être fournie en `ValueListenable<double>` plutôt qu'en
`double`, ce qui scope le rebuild à la seule poignée. À défaut, la dartdoc `:20-22` doit être
corrigée pour ne plus affirmer un invariant que le code ne tient pas.

---

### F4 — MEDIUM — sélection : **tous** les items rebuild, pas « les items concernés »

**Fichiers** : `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:335` et
`z_subfolder_compact_selector.dart:84`

La dartdoc de la sidebar affirme :

```dart
// z_subfolder_sidebar.dart:11-13
/// La surbrillance est scopée **par item**
/// (`ValueListenableBuilder` sur la seule tranche `selected`) : changer la
/// sélection ne reconstruit QUE les items concernés, jamais la structure.
```

La seconde moitié est vraie (la structure ne bouge pas), la **première est fausse**. Chaque
`_SubfolderRow` abonne son propre `ValueListenableBuilder<String?>` au **même** notifier
partagé `selected` (`z_subfolder_sidebar.dart:335`, notifier injecté depuis
`z_study_folder_detail.dart:315`/`:341`). `ValueListenableBuilder` rebâtit son `builder` à
**chaque** notification, sans comparer la valeur *dérivée* (`current == selectionId`) : les N
items montés rebuild à chaque changement de sélection, et non les 2 concernés (l'ancien et le
nouveau). Même schéma pour les puces du sélecteur compact (`z_subfolder_compact_selector.dart:84`).

Le coût réel reste borné par le nombre d'items **montés** (la liste est virtualisée, F3 mis à
part), donc l'impact est modéré — mais l'invariant écrit dans la dartdoc n'est pas tenu, et
c'est précisément le genre d'affirmation non vérifiée que la revue traque. Le test SM-1 ne
contredit pas ce finding : il compte les rebuilds de la tranche **Progression** et les appels
de `materialSectionsBuilder` (`z_study_folder_detail_sm1_test.dart:51-59`), jamais les items
de la sidebar.

**Statut de preuve** : structurelle (sémantique documentée de `ValueListenableBuilder` +
notifier partagé lisible sur disque). Empirique bloquée (cf. limite déclarée).

**Correctif suggéré** : soit un `Selector`/`ValueListenableBuilder` filtrant (comparer
`current == selectionId` et court-circuiter), soit corriger la dartdoc pour dire ce que le
code fait réellement (« la structure n'est jamais reconstruite »).

---

### F5 — LOW — `ZSubfolderCompactSelector` : rangée **eager**, non virtualisée, sur une liste injectée non bornée

**Fichier** : `packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart:56-73`

```dart
// :56-57
// `Column`). `ListView(children:)` interdit (AD-13) — d'où `Row`.
...
// :67-68
for (final ref in spec.subfolders)
  _chip(context, theme, id: ref.id, label: ref.label),
```

Le commentaire respecte la **lettre** de l'interdit AD-13 (`ListView(children:)`) tout en
reproduisant le comportement qu'il vise : un `SingleChildScrollView` + `Row` construit
**toutes** les puces, y compris hors champ. `spec.subfolders` est une donnée injectée sans
borne déclarée (`z_subfolder_nav_spec.dart`), donc l'hypothèse « peu d'items » du commentaire
`:55` n'est garantie par rien dans le code.

Impact faible en pratique (une puce est légère, et un dossier a rarement 200 sous-dossiers),
d'où le LOW. Si l'orchestrateur veut fermer proprement : `SizedBox(height: <cible 48 dp>)` +
`ListView.builder(scrollDirection: Axis.horizontal)`.

---

## Hors findings — à traiter au gate d'epic

- `packages/zcrud_ui_kit/test/zz_tmp_ad_probe_test.dart` : fichier temporaire d'un autre
  workstream, présent pendant mon exécution de la suite (`Some tests failed` sur le seul
  `loading`) — **supprimé depuis** par son auteur (`ls` → RC=2 en fin de revue). Les 108 tests
  SUF-1/`zcrud_ui_kit` étaient verts ; l'orchestrateur doit néanmoins rejouer la suite lui-même.
- `packages/zcrud_session` : suite non rejouée à la fin de cette revue (contention de lock
  `flutter test` avec plusieurs workstreams concurrents). Le diff SUF-4 étant purement additif
  sur des `StatelessWidget`, aucun risque perf identifié à la lecture — mais l'orchestrateur
  doit rejouer la vérif verte lui-même, conformément à sa règle.
