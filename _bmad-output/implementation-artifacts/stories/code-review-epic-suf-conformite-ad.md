# Code-review epic SUF — lentille « Conformité AD »

**Date** : 2026-07-26
**Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2/SUF-3 (`zcrud_study`), SUF-4 (`zcrud_session`) + `example/test/offline_demo_test.dart`.
**Hors périmètre** : `packages/zcrud_markdown/` (workstream parallèle — non lu, non revu).
**Verdict** : **BLOQUANT** — 2 défauts HIGH **reproduits empiriquement** (un crash dur, une perte silencieuse d'entrée utilisateur), tous deux dans `zcrud_ui_kit/lib/src/presentation/z_page_shell.dart` / `z_page_scaffold.dart`.

---

## 0. Preuves de graphe (AD-1) — REJOUÉES

### `python3 scripts/dev/graph_proof.py` → **RC=0**

Sortie réelle (extraits pertinents, sortie intégrale de 69 arêtes) :

```
zcrud_session -> zcrud_core
zcrud_session -> zcrud_flashcard
zcrud_session -> zcrud_study_kernel
zcrud_session -> zcrud_ui_kit
zcrud_study -> zcrud_annotations
zcrud_study -> zcrud_core
zcrud_study -> zcrud_exam
zcrud_study -> zcrud_flashcard
zcrud_study -> zcrud_mindmap
zcrud_study -> zcrud_responsive
zcrud_study -> zcrud_session      <-- arête AJOUTÉE par SUF-3
zcrud_study -> zcrud_study_kernel
zcrud_study -> zcrud_ui_kit
zcrud_ui_kit -> zcrud_core
total arêtes = 69
out-degree(zcrud_core) = 0 (runtime)
noeuds = 31, triés = 31
ACYCLIQUE OK
CORE OUT=0 OK
```

**Conclusions vérifiées** :
* `ACYCLIQUE OK` / `CORE OUT=0 OK` → **AD-1 tenu**.
* L'arête `zcrud_study -> zcrud_session` est bien la **seule** arête nouvelle ; le compte annoncé dans le pubspec (« Graphe : 68 → 69 arêtes ») est **exact** (69 mesuré).
* **Pas de réciproque** : aucune arête `zcrud_session -> zcrud_study` dans la sortie ⇒ aucun cycle introduit. `zcrud_ui_kit` conserve sa seule arête sortante `-> zcrud_core` (AD-29 tenu).

### Arête `zcrud_study → zcrud_session` — RÉELLEMENT consommée ?

```
$ grep -n "ZStudyProgressRings\|ZProgressRingsData" packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart
40:    show ZProgressRingsData, ZStudyProgressRings;
154:  final ZProgressRingsData? progressData;
370:            ZStudyProgressRings(data: data),
```
→ **Oui**, l'arête est justifiée par une consommation effective (import `show`-restreint, aucune réimplémentation de l'anneau). Conforme à la règle « arête ajoutée par la première story qui la consomme réellement ».

### Grep NÉGATIFS d'invariants

```
$ grep -rn "package:get/\|flutter_riverpod\|package:provider/\|go_router\|package:riverpod" \
    packages/zcrud_ui_kit/lib packages/zcrud_study/lib packages/zcrud_session/lib
```
→ **RC=0 mais AUCUN import réel** : les 12 occurrences sont **toutes** dans des commentaires/dartdoc (`z_page_shell.dart:13`, `z_study_folder_detail.dart:24`, `z_transitions.dart:4/10/65`, etc.). Aucune ligne ne commence par `import`. **AD-2/AD-15 tenu.**

```
$ grep -rn "cloud_firestore\|Timestamp\|FirebaseException" \
    packages/zcrud_ui_kit/lib packages/zcrud_study/lib packages/zcrud_session/lib
RC=1
```
→ **Grep négatif prouvé** : aucun type `cloud_firestore` dans ces trois packages. **AD-11/AD-16 tenu.**

```
$ grep -nE "EdgeInsets\.only\((left|right)|Alignment\.center(Left|Right)|Positioned\((left|right)|TextAlign\.(left|right)" <17 fichiers du périmètre>
z_session_progress_indicator.dart:284:   // Directionnel (AD-13) — jamais `EdgeInsets.only(left:)`.
z_session_progress_indicator.dart:464:   // Directionnel (AD-13) — jamais `Alignment.centerLeft/Right`.
```
→ Les 2 seules occurrences sont des **commentaires**. Aucune construction non directionnelle. **AD-13 (RTL) tenu.**

```
$ grep -nE "Color\(0x|Colors\.[a-z]" <11 fichiers de présentation du périmètre>
z_folder_card.dart:27, z_session_progress_indicator.dart:447,
z_session_summary_view.dart:694, z_srs_quality_buttons.dart:15
```
→ Les 4 occurrences sont des **commentaires** (« aucune `Color(0x…)` », tableau de parité). **Aucune couleur en dur.** Thème injecté (`ZcrudTheme` / `zResolveColorKeyOrSlot` / `Theme.of`). **FR-26 tenu.**

RTL du redimensionnement de sidebar (SUF-3), vérifié :
```
z_subfolder_sidebar.dart:268  final textDir = Directionality.of(context);
z_subfolder_sidebar.dart:277  final signed = textDir == TextDirection.rtl ? -details.delta.dx : details.delta.dx;
```

### Analyse statique du périmètre

```
$ dart analyze packages/zcrud_ui_kit packages/zcrud_study packages/zcrud_session example
$ ... | grep -cE "^ *(error|warning) -"   →  0
```
→ **0 error, 0 warning** (92 `info` de style, dont ~90 préexistants). Le périmètre compile.

---

## 1. HIGH — `ZPageScaffold` : crash `Null check operator used on a null value` au changement de `mode` à chaud

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:75` (création) et `:146/:152/:159/:167` (déréférencement `_controller!`).

Le contrôleur de recherche n'est instancié qu'**une fois**, dans `initState`, et **seulement si** le mode est sliver :

```dart
// z_page_scaffold.dart:72-76
@override
void initState() {
  super.initState();
  if (_isSliver) _controller = _ZSearchController(widget.search);
}
```

`build` réévalue `_isSliver` **à chaque frame** (`:86`), mais `_controller` n'est jamais (re)créé :

```dart
// z_page_scaffold.dart:145-146
return ValueListenableBuilder<bool>(
  valueListenable: _controller!.isSearching,   // <-- null si le mode était `fixed` à l'init
```

Preuve d'absence de rattrapage :
```
$ grep -n "didUpdateWidget" packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart \
    packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart \
    packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart
RC=1     (aucun didUpdateWidget dans les trois fichiers)
```

**Reproduction empirique** (sonde temporaire `packages/zcrud_ui_kit/test/zz_tmp_ad_probe_test.dart`, exécutée puis **SUPPRIMÉE** — `git status` du package revérifié propre après suppression) :

```dart
await t.pumpWidget(app(ZPageAppBarMode.fixed));
await t.pumpWidget(app(ZPageAppBarMode.pinned));
print('P3 exception=${t.takeException()}');
```
```
00:00 +2: P3 — ZPageScaffold mode fixed -> pinned
P3 exception=Null check operator used on a null value
```

**Pourquoi c'est atteignable en vrai** : `mode` est une **prop publique** ré-exposée jusqu'en haut de la pile SUF — `ZStudyFolderDetail` la passe telle quelle (`z_study_folder_detail.dart:215 → mode: widget.mode`). Une page qui choisit son mode par point de rupture (`fixed` en compact, `pinned` en large) — exactement l'usage que ce shell encourage — crashe à la rotation ou au redimensionnement de fenêtre.

**Violation** : AD-10 (défensif : jamais d'exception là où un repli est exigé) ; AD-2 (état détenu par le widget mais dont le cycle de vie ne suit pas ses props).

**Correctif suggéré (hors périmètre de cette revue)** : créer le contrôleur inconditionnellement (le coût est nul : deux `ValueNotifier` + un `TextEditingController`), ou le (re)créer paresseusement dans `_sliverAppBar` / via `didUpdateWidget`.

---

## 2. HIGH — `_ZSearchController` fige `widget.search` à l'`initState` : la frappe part dans le callback PÉRIMÉ (ou dans le vide)

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:44-52` et `:70-73`.

```dart
// z_page_shell.dart:44-51
_ZSearchController(this._config)
    : _isSearching = ValueNotifier<bool>(false),
      query = ValueNotifier<String>(_config?.initialQuery ?? ''),
      ...
final ZAppBarSearchConfig? _config;      // capturé UNE fois

// z_page_shell.dart:70-73
void onChanged(String text) {
  query.value = text;
  _config?.onQueryChanged(text);          // <-- config de l'INIT, jamais rafraîchie
}
```

Créé une seule fois (`z_searchable_app_bar.dart:61-64` et `z_page_scaffold.dart:75`), **sans `didUpdateWidget`** (grep négatif RC=1 ci-dessus).

**Incohérence interne mesurable** : la *même* frappe est traitée par **deux** sources de config différentes. Le hint et l'icône loupe lisent la config **fraîche** (`_zBuildTitle` reçoit `widget.search` en argument → `search.hintLabel`, `z_page_shell.dart:142` ; `_zBuildActions` teste `search != null`, `:208`), tandis que l'émission lit la config **figée**. Le widget affiche donc une recherche pilotée par la config N et émet vers la config N-1.

**Reproduction empirique** (même sonde temporaire, supprimée après exécution) :

```
00:00 +0: P1 — config de recherche remplacée : callback PÉRIMÉ
P1 oldHits=[abc] newHits=[]
00:00 +1: P2 — search null -> non-null : frappe non émise
P2 hits=[]
```

* **P1** : le parent rebuild avec une **nouvelle** `ZAppBarSearchConfig` (même position dans l'arbre) ; la saisie `abc` est délivrée à l'**ancien** `onQueryChanged` — le nouveau ne reçoit **rien**.
* **P2** : `search: null` puis `search: <config>` ; la loupe **s'affiche** (elle lit `widget.search` frais), le champ **s'ouvre et accepte la saisie**, mais `_config` vaut `null` ⇒ **`hits` est vide** : la frappe de l'utilisateur est **silencieusement perdue**. Aucun `Left`, aucun log, aucun signal.

**Portée réelle dans l'epic** : `ZStudyFolderDetail` passe `search: widget.search` sans médiation (`z_study_folder_detail.dart:214`) — toute app SUF-3 qui active/désactive la recherche selon l'onglet ou qui reconstruit sa config avec une valeur capturée hérite du défaut.

**Violation** : AD-2 (état à **propriétaire unique** : ici le propriétaire garde une copie divergente de sa source déclarative) ; AD-10 (perte silencieuse au lieu d'un repli explicite).

---

## 3. MEDIUM — Justification de l'arête SUF-3 factuellement FAUSSE : `zcrud_study` tire désormais `confetti` + `flutter_card_swiper` en transitif

**Fichier** : `packages/zcrud_study/pubspec.yaml` (bloc de commentaire `- zcrud_session :`, ligne ajoutée par le diff SUF-3) — affirmation :

> « ZÉRO dépendance tierce nouvelle (`zcrud_session` est un package zcrud). »

**Contre-preuve sur disque** :

```
$ cd packages/zcrud_study && flutter pub deps --style=compact | grep -nE "confetti|flutter_card_swiper|zcrud_session"
106:- zcrud_session 0.18.0 [confetti flutter flutter_card_swiper zcrud_core zcrud_flashcard zcrud_study_kernel zcrud_ui_kit]
 85:- confetti 0.8.0 [flutter vector_math]
 87:- flutter_card_swiper 7.2.0 [flutter]
```

L'arête fait entrer **deux paquets tiers** dans le graphe de dépendances effectif de `zcrud_study` (et de tout consommateur de `zcrud_study`). Les précédents cités dans le même commentaire (`zcrud_responsive` SU-8, `zcrud_ui_kit` ME-2) étaient, eux, **réellement** à zéro tiers — le pubspec de `zcrud_ui_kit` ne déclare que `zcrud_core` + SDK Flutter (vérifié).

**Pourquoi rien ne l'attrape** : le garde de confinement NFR-SU7 (`packages/zcrud_session/test/z_third_party_confinement_test.dart`) scanne, de son propre aveu (dartdoc `:26-35`), « les `pubspec.yaml` de tous les `packages/*` » c'est-à-dire la **DÉCLARATION** — or `zcrud_study` ne déclare pas ces paquets, il les hérite. Et `graph_proof.py` ne connaît que les arêtes inter-`zcrud_*` (aucune allowlist tierce : `grep "third\|ALLOW\|confin" scripts/dev/graph_proof.py` → RC=1, revérifié en lisant le script intégralement). Le trou est donc **structurel**, pas une négligence de la story.

**Statut AD** : ce n'est **pas** une violation d'AD-1 (le graphe reste acyclique, CORE OUT=0) ni du garde de confinement tel qu'il est écrit. C'est une **justification d'arête inexacte** — et dans ce dépôt la justification écrite au pubspec *est* le document de conformité de l'arête. Deux corrections possibles :
1. corriger le commentaire pour dire la vérité (« +2 tiers TRANSITIFS, hérités de `zcrud_session`, confinés à ses seuls fichiers propriétaires ») ;
2. ou, si l'empreinte est jugée inacceptable pour `zcrud_study`, relocaliser `ZStudyProgressRings`/`ZProgressRingsData` (qui ne dépendent d'aucun tiers) vers un package plus léger — mais c'est une décision d'architecture, hors périmètre d'une revue.

Recommandation de cette lentille : **option 1** (le commentaire), qui suffit à rétablir l'honnêteté du dossier de conformité.

---

## 4. LOW — dimension d'espacement en dur dans le menu de débordement

`packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:200` :
```dart
const SizedBox(width: 12),
```
Aucun token de thème (`ZcrudTheme.gapS`) n'est consommé dans ce fichier :
```
$ grep -c "theme.gap\|ZcrudTheme.of" packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart
0
```
**Atténuation** : c'est le **patron existant** du package (`z_state_widgets.dart:96/267/275/298`, `z_scaffold_messenger_toaster.dart:64` font pareil) — SUF-1 n'introduit pas la dérive, il la suit. Nit ; à corriger si un passage de fond sur les tokens `ZcrudTheme` est fait dans `zcrud_ui_kit`.

---

## 5. LOW — `prefer_const_constructors` sur le fake corrigé par l'orchestrateur

`example/test/offline_demo_test.dart:228` :
```
info - test/offline_demo_test.dart:228:7 - Use 'const' with the constructor to improve performance. - prefer_const_constructors
```
Le `Left<ZFailure, DemoRecord>(const ZCacheFailure(...))` peut être `const` en entier. `info` seulement (RC=0), aucun impact fonctionnel. Le reste de l'ajout (`purge` idempotente, `putMerged` en `Left` explicite plutôt qu'un faux merge) est **conforme AD-10** et correctement documenté.

---

## 6. Ce qui a été vérifié et jugé CONFORME

| Invariant | Preuve |
|---|---|
| AD-1 acyclicité / CORE OUT=0 | `graph_proof.py` RC=0, `ACYCLIQUE OK`, `CORE OUT=0 OK`, 69 arêtes |
| AD-1 arête `study→session` justifiée & sans réciproque | arête consommée (`z_study_folder_detail.dart:40/370`) ; aucune arête `session→study` dans la sortie du gate |
| AD-29 isolation `zcrud_ui_kit` | pubspec : `zcrud_core` + SDK Flutter uniquement ; graphe : `zcrud_ui_kit -> zcrud_core` seule arête sortante |
| AD-2 aucun gestionnaire d'état | grep : 12 occurrences, **toutes** en commentaire ; aucun `import` |
| AD-11/AD-16 aucun type `cloud_firestore` | grep négatif RC=1 |
| AD-13 RTL directionnel | grep négatif sur les 4 motifs interdits (seuls 2 commentaires) ; RTL du drag résolu par `Directionality.of` (`z_subfolder_sidebar.dart:268-279`) |
| FR-26 thème injecté | grep négatif `Color(0x`/`Colors.` (4 commentaires) ; couleurs via `zResolveColorKeyOrSlot`/`ZcrudTheme` |
| AD-2 rebuilds granulaires (lecture de code) | `ValueListenableBuilder` scopés : `_materialBody` (`:292`), `_sidebarRegion` (`:304/:329`), `ZSearchableAppBarState.build` (`:81`) — la frappe ne rebâtit que la tranche app-bar |
| AD-2 controllers non recréés au rebuild | `_ZSearchController`, `_selected`/`_collapsed`/`_sidebarWidth` : `late final` créés en `initState`, `dispose`és une fois (le **défaut inverse** — jamais rafraîchis — est le finding §2) |
| AD-4 extensions additives (SUF-4) | `ZSessionProgressStyle.linear`, `ZQualityBreakdownCoverage`, `ZSrsQualityEmphasis` : valeurs/paramètres **additifs**, défauts = comportement historique strictement inchangé |
| AD-10 défensif (SUF-4) | `resolvedLinearValue` (`total <= 0 ⇒ 0`), `resolvedLinearThickness` (non finie/≤0 ⇒ token thème), `opacityFor`/`borderWidthFor` (bornés) |
| Compilation | `dart analyze` sur les 3 packages + `example` : **0 error, 0 warning** |

---

## 7. Note de procédure

La sonde de reproduction (`packages/zcrud_ui_kit/test/zz_tmp_ad_probe_test.dart`) a été créée, exécutée (`flutter test`, 3/3 pass, sorties `print` citées ci-dessus), puis **supprimée**. `git status --porcelain packages/zcrud_ui_kit/` revérifié après suppression : aucun résidu. Aucun fichier de `lib/` ni de `test/` du périmètre n'a été modifié par cette revue.

Le répertoire `packages/zcrud_ui_kit/.review_adv/` apparu en non-suivi dans `git status` **n'est pas** produit par cette lentille (probable artefact d'un agent de revue parallèle) — à nettoyer avant le commit d'epic.
