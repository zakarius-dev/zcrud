# Story EX-UI.3 : `ZAdaptiveGrid` + `computeCrossAxisCount` — grille d'items best-of-breed (clamp ≥ 1, largeur LOCALE, garde vide)

Status: review

- **Clé sprint-status** : `ex-ui-3-adaptive-grid`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **M** (1 fonction PURE domaine NEUVE + 1 widget `presentation` NEUF + tests ; 0 codegen, 0 entité persistée, 0 nouveau package)
- **Parallélisation** : **PARALLÉLISABLE intra-P1 après EX-UI.1** (fichiers disjoints dans le **même** package `zcrud_responsive` — cohabite avec EX-UI.2 `ZResponsiveLayout`). ⛔ **SÉQUENTIELLE vis-à-vis d'EX-UI.2 au niveau du barrel** `lib/zcrud_responsive.dart` (seul point de contact partagé — deux stories qui ajoutent des lignes d'`export` : sérialiser l'édition du barrel, ne jamais l'écrire en parallèle). Dépend de **EX-UI.1** (`done`/`review` — même package, primitives déjà scaffoldées).
- **Package écrit (disjoint)** : `packages/zcrud_responsive/` uniquement — 1 fichier `domain` pur neuf + 1 fichier `presentation` neuf + 2 lignes d'`export` au barrel + tests. ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`). ⛔ **Ne touche PAS** `z_window_size_class.dart` / `z_breakpoint_value.dart` (EX-UI.1) ni `z_responsive_layout.dart` (EX-UI.2).
- **AD delta** : **AD-31** (grille responsive : **clamp ≥ 1**, largeur locale via `LayoutBuilder`, garde `children.isEmpty → SizedBox.shrink()`, nom **`ZAdaptiveGrid` — JAMAIS `ZResponsiveGrid`**), **AD-29 (AMENDÉ)** (paquet UI pur `zcrud_responsive` dépendant de `zcrud_core`), **AD-13** (RTL / a11y — variantes directionnelles), **AD-14** (calcul déterministe). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — aucune nouvelle arête `zcrud_*`), **AD-2 / AD-15** (Flutter-native, **aucun** gestionnaire d'état — le `ConsumerWidget`/`ref` mort de lex est **retiré**), **AD-5 / AD-10** (défaut sûr : jamais de division par zéro, jamais de grille vide/fantôme), **AD-12** (zéro secret), **NFR-U6** (domaine pur testable **sans `BuildContext`**), **NFR-U7** (enums > booléens), **NFR-U11** (pas de codegen).

---

## Story

**As a** utilisateur sur écran étroit / panneau réduit / dialog (et développeur intégrateur d'une grille de cartes),
**I want** une grille dynamique dont le nombre de colonnes est calculé par une **fonction pure** `computeCrossAxisCount` garantissant **au moins 1 colonne**, à partir de la **largeur locale** mesurée par `LayoutBuilder`, et un widget `ZAdaptiveGrid` paramétrable (largeur-min d'item, espacement, hauteur/aspect) qui garde le cas vide,
**so that** je ne tombe **jamais** sur une grille vide ni sur une division par zéro (bug iffd `min(3, Get.width ~/ itemMinWidth)` **sans clamp bas**), y compris en **split-view** ou **bottom-sheet partiel** où la largeur allouée ≠ largeur écran.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ce que `zcrud_responsive` EXPOSE DÉJÀ (EX-UI.1 + EX-UI.2 — base, consommée en lecture)

Lu sur disque (`packages/zcrud_responsive/lib/zcrud_responsive.dart` + arbo `lib/src/`) :

| Symbole | Package d'origine | Détail (lu) |
|---|---|---|
| `ZBreakpoint` / `ZResponsiveBreakpoints` / `ZResponsiveSpan` | **`zcrud_core`** (ré-exportés par confort) | 5 paliers Bootstrap (576/768/992/1200) + grille 12-col **de formulaire** `ZResponsiveGrid`. **← NE PAS réutiliser ici** (grille de formulaire ≠ grille d'items). |
| `ZWindowSizeClass` + `ZWindowSizeThresholds` | `zcrud_responsive` (EX-UI.1) | 3 classes M3 (600/840). **← NON requis par cette story** (la grille d'items se pilote par `minItemWidth`, pas par classe d'écran). |
| `ZBreakpointValue<T>` | `zcrud_responsive` (EX-UI.1) | Valeur générique par palier. **← NON requis ici.** |
| `ZResponsiveLayout` | `zcrud_responsive` (EX-UI.2) | Aiguilleur 3 builders. Fichier voisin **à ne pas toucher**. |

⛔ **Aucun de ces symboles n'est redéclaré ni modifié.** Cette story n'ajoute que le **strictement nouveau** : `computeCrossAxisCount` (domaine pur) + `ZAdaptiveGrid` (presentation).

### ⚠️ Nom `ZAdaptiveGrid` — IMPÉRATIF (AD-31), JAMAIS `ZResponsiveGrid`

`grep` sur `packages/` : `zcrud_core` déclare **déjà** `ZResponsiveGrid` (`packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart`, grille **12 colonnes de formulaire**, ré-exporté via le barrel `zcrud_responsive`). ⇒ **collision totale** si on réutilise ce nom. **AD-31 tranche : la grille d'items d'EX-UI.3 s'appelle `ZAdaptiveGrid` — jamais `ZResponsiveGrid`.**

> **Reconciliation de nom de fichier** : l'épic EX-UI.3 (l.182) mentionne encore `z_responsive_grid.dart` comme fichier cible — **périmé**. AD-31 (postérieur, Amendement de réconciliation E3-4) impose le nom **`ZAdaptiveGrid`**. Le fichier presentation est donc **`z_adaptive_grid.dart`** (et non `z_responsive_grid.dart`). Cette story applique AD-31 (source de vérité la plus récente).

### Base best-of-breed (LECTURE SEULE — à neutraliser, PAS copier)

- **lex_ui** `packages/lex_ui/lib/presentation/widgets/responsive_grid.dart` (~74 LOC) — `ResponsiveGrid` : `LayoutBuilder` → `crossAxisCount = (width / minItemWidth).floor().clamp(1, maxColumns)` → largeur d'item déduite (`availableWidth = width − spacing·(n−1)`) → `childAspectRatio` recalculé si `itemHeight` fourni → garde `children.isEmpty → SizedBox.shrink()`. **Le plus mûr** (floor + clamp + garde vide). **À neutraliser** : `ConsumerWidget → StatelessWidget` (le `ref` est **mort**, jamais lu — dette de migration Riverpod cosmétique). Tests lex `responsive_grid_test.dart` (floor, clamp, empty→shrink) **portables quasi tels quels**.
- **iffd** `lib/douanes_togolaises/screens/tec_cedeao_screen.dart` (l.662, 781) — **LA SOURCE DU BUG** : `crossAxisCount = min(3, Get.width ~/ itemMinWidth)` puis `itemWidth = Get.width / crossAxisCount`. **Deux défauts corrigés ici** : (1) **`~/` sans clamp bas** → `crossAxisCount == 0` possible si `Get.width < itemMinWidth` (écran étroit / panneau réduit) → **division par zéro** au calcul de `itemWidth` + `GridView` vide ; (2) **`Get.width`** (largeur écran globale GetX) **casse en dialog / split-view / bottom-sheet partiel** (largeur du conteneur ≠ largeur écran). ⇒ clamp `≥ 1` + largeur **locale** `LayoutBuilder`.

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — `computeCrossAxisCount` : fonction PURE domaine, testable sans `BuildContext`, `minColumns ≥ 1` GARANTI (NFR-U6, AD-31, AD-10)

Fichier : `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart` (**top-level function**, aucun `BuildContext`, aucun import Flutter widgets — au plus `dart:math`/`dart:ui` non requis). Signature **retenue** (alignée sur la formulation littérale de la tâche + AD-31) :

```dart
/// Nombre de colonnes d'une grille d'items pour [availableWidth], borné à au
/// moins [minColumns] (≥ 1 garanti) et au plus [maxColumns] (illimité si `null`).
///
/// Formule : `(availableWidth / minItemWidth).floor().clamp(lo, hi)` où
/// `lo = max(1, minColumns)` et `hi = maxColumns ?? infini`.
///
/// **Défauts sûrs (AD-10 / NFR-U10) — jamais de throw, jamais de division par
/// zéro** : `minItemWidth <= 0` ou `NaN`, `availableWidth <= 0` / `NaN`, ou
/// `availableWidth` infini avec `maxColumns == null` → retombe sur `lo` (le
/// plancher garanti ≥ 1). `minColumns < 1` est **remonté** à 1. Si un
/// `maxColumns` fourni est `< lo`, il est **remonté** à `lo` (clamp toujours
/// valide, jamais `RangeError`).
int computeCrossAxisCount({
  required double availableWidth,
  required double minItemWidth,
  int minColumns = 1,
  int? maxColumns,
});
```

**Points de vigilance d'implémentation (défauts sûrs — chacun testé) :**
1. **`lo = max(1, minColumns)`** — `minColumns ≤ 0` ⇒ `1` (corrige le cœur du bug iffd : jamais 0 colonne).
2. **Garde `minItemWidth`** : `minItemWidth <= 0` OU `minItemWidth.isNaN` ⇒ retourner `lo` **avant** toute division (jamais `x/0` ⇒ jamais `Infinity`/`NaN` propagé).
3. **Garde `availableWidth`** : `availableWidth <= 0` OU `availableWidth.isNaN` ⇒ `lo`. Cas `availableWidth == double.infinity` : `(inf/minW).floor()` lève / donne un résultat non borné → si `maxColumns != null` retourner `hi`, sinon `lo` (pas de grille « infinie »).
4. **`clamp` toujours valide** : calculer `hi = maxColumns == null ? <grand> : max(lo, maxColumns)` de sorte que `lo <= hi` **toujours** (sinon `num.clamp` lève `ArgumentError`). Ne **jamais** appeler `clamp(lo, hi)` avec `hi < lo`.
5. Le résultat de `.floor()` sur un `double` fini est un `int` ; `clamp` retourne un `num` → **caster/retourner un `int`** (`.toInt()` ou `clamp` sur `int` après `floor`).

> **Reconciliation signature** : AD-31 (l.102) écrit `int maxColumns` (non nullable) ; la tâche EX-UI.3 impose `int? maxColumns` avec défaut « illimité » (`clamp(minColumns, maxColumns ?? infini)`). **Retenu : `int? maxColumns` (nullable, illimité par défaut)** — strictement plus général (un appelant peut ne pas plafonner), et c'est la formulation explicite de la story. Documenter ce choix dans les Completion Notes.

### D2 — `ZAdaptiveGrid` : largeur LOCALE via `LayoutBuilder`, JAMAIS `Get.width`/`MediaQuery` écran (AD-31, NFR-U2)

Fichier : `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart`, `class ZAdaptiveGrid extends StatelessWidget`, ctor `const`. Le widget **enveloppe son rendu dans un `LayoutBuilder`** et lit `constraints.maxWidth` comme `availableWidth` passée à `computeCrossAxisCount`. **Jamais** `Get.width`, **jamais** `MediaQuery.of(context).size.width` / `MediaQuery.sizeOf` (écran global). Justification : identique à EX-UI.2/D1 — split-view, master-detail, bottom-sheet partiel, colonne d'une `Row` ⇒ largeur du conteneur ≠ largeur écran.

### D3 — API paramétrable (fin des ternaires `300/350` dupliqués) ; enums > booléens (NFR-U7)

Signature **retenue** :

```dart
const ZAdaptiveGrid({
  required this.children,
  required this.minItemWidth,
  this.spacing = 8.0,
  this.runSpacing,          // défaut = spacing si null
  this.itemHeight,          // si fourni → childAspectRatio recalculé (cf. D4)
  this.aspectRatio,         // childAspectRatio explicite (ignoré si itemHeight fourni)
  this.minColumns = 1,
  this.maxColumns,
  this.padding,             // EdgeInsetsGeometry? (directionnel — AD-13)
  super.key,
});

final List<Widget> children;
final double minItemWidth;
final double spacing;
final double? runSpacing;
final double? itemHeight;
final double? aspectRatio;
final int minColumns;
final int? maxColumns;
final EdgeInsetsGeometry? padding;
```

- `minItemWidth`, `spacing`, `itemHeight`/`aspectRatio`, `maxColumns` = **paramètres nommés** ⇒ suppression du ternaire `Get.width >= 840 ? 350 : 300` dupliqué dans iffd/dodlp.
- **Enums > booléens (NFR-U7)** : **aucun** `bool` de configuration multi-état exposé (pas de `isDense`, `isMobile`…). L'espacement inter-lignes vs inter-colonnes est piloté par des **valeurs** (`spacing`/`runSpacing`), pas par un flag. (Aucune bascule 2-états pertinente n'apparaît ici ; si l'implémentation en fait émerger une, préférer un `enum` dédié plutôt qu'un `bool` — consigner le choix.)
- **Directionnel (AD-13)** : `padding` est `EdgeInsetsGeometry?` (accepte `EdgeInsetsDirectional`) ; **aucun** `EdgeInsets.only(left:/right:)`, **aucun** `Alignment.centerLeft/Right`, **aucun** `TextAlign.left/right`, **aucun** `Positioned(left:/right:)` dans le fichier.

### D4 — Garde vide + `childAspectRatio` recalculé sur largeur d'item déduite (AD-10, AD-31, AC4/AC5)

- **Garde vide (AD-10)** : `if (children.isEmpty) return const SizedBox.shrink();` **avant** d'instancier le moindre `GridView`/`LayoutBuilder` productif — jamais de grille fantôme.
- **Aspect** : dans le `LayoutBuilder`, `n = computeCrossAxisCount(availableWidth: constraints.maxWidth, minItemWidth: minItemWidth, minColumns: minColumns, maxColumns: maxColumns)`. Largeur d'item déduite : `itemWidth = (constraints.maxWidth − spacing·(n − 1)) / n` (les items s'étirent pour remplir la largeur, comme lex/iffd — pas d'espace résiduel). Puis `childAspectRatio` = `itemHeight != null ? itemWidth / itemHeight : (aspectRatio ?? 1.0)`. **Garde numérique** : si `itemHeight` fourni, `itemHeight > 0` requis pour éviter `itemWidth/0` (sinon retomber sur `aspectRatio ?? 1.0`) — cohérent AD-10.

### D5 — Rendu paresseux `GridView.builder` (jamais `children:[...]` non paresseux — AD-13/NFR-U4)

Rendre via **`GridView.builder`** avec `itemCount: children.length` et `itemBuilder: (_, i) => children[i]`, sous `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n, mainAxisSpacing: runSpacing ?? spacing, crossAxisSpacing: spacing, childAspectRatio: ratio)`. ⇒ **layout paresseux** des cellules (seules les cellules visibles sont montées) tout en gardant l'ergonomie `children` (garde vide native, AC4). **Jamais** `GridView.count(children: [...])` ni `GridView(children: [...])` matérialisant tout l'arbre. Défaut embarquable dans un parent scrollable : `shrinkWrap: true` + `physics: const NeverScrollableScrollPhysics()` (parité lex — la grille ne scrolle pas d'elle-même, le parent scrolle). *(Si un besoin de grille scrollante autonome émerge, l'exposer par un `enum` de mode plutôt qu'un `bool` — hors périmètre ici, consigner.)*

### D6 — Aucun gestionnaire d'état ; `StatelessWidget` (ConsumerWidget/ref mort de lex retiré) — AD-2/AD-15/NFR-U2

`ZAdaptiveGrid extends StatelessWidget`. **Aucun** `ConsumerWidget`/`WidgetRef`/`ref`, **aucun** import `get`/`flutter_riverpod`/`provider`/`go_router`, **aucun** `setState`. Le fichier presentation n'importe que `package:flutter/widgets.dart` (ou `material.dart` si strictement requis) + l'import relatif de `compute_cross_axis_count.dart`. Le domaine `compute_cross_axis_count.dart` n'importe **rien de Flutter** (pur Dart). ⇒ **aucune** nouvelle arête `zcrud_*` (CORE OUT=0 intact).

### D7 — Aucun codegen, aucune sérialisation (NFR-U11)

Fonction pure + widget UI, **non** persistés, **aucun** `@ZcrudModel`/`@JsonSerializable`/`part`. ⇒ pas de `*.g.dart`, `melos run generate` **no-op**, gate `codegen-distribution` **non concerné**.

---

## Acceptance Criteria

### AC1 — `computeCrossAxisCount` : fonction pure, formule floor+clamp, `minColumns ≥ 1` GARANTI (jamais 0)
**Given** `int computeCrossAxisCount({required double availableWidth, required double minItemWidth, int minColumns = 1, int? maxColumns})` dans `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart`,
**When** on l'évalue avec des entrées normales,
**Then** il retourne `(availableWidth / minItemWidth).floor()` **borné** par `clamp(max(1, minColumns), maxColumns ?? illimité)`,
**And** pour `availableWidth < minItemWidth` (écran étroit / panneau réduit) le résultat est **≥ 1** — **jamais 0** (corrige le bug iffd `~/` sans clamp bas),
**And** la fonction est **top-level pure**, **sans `BuildContext`** ni import de widgets Flutter (NFR-U6) — testable en `test/` Dart pur.

### AC2 — Défauts sûrs : jamais de throw, jamais de division par zéro (AD-10 / NFR-U10)
**Given** des entrées dégénérées,
**When** `computeCrossAxisCount` est appelée,
**Then** elle **ne lève jamais** (`RangeError`/`ArgumentError`) et **ne divise jamais par zéro** :
- `minItemWidth <= 0` ⇒ retourne `max(1, minColumns)` (aucune division),
- `minItemWidth` = `double.nan` ⇒ `max(1, minColumns)`,
- `availableWidth <= 0` ou `double.nan` ⇒ `max(1, minColumns)`,
- `availableWidth == double.infinity` ⇒ `maxColumns` si fourni, sinon `max(1, minColumns)` (jamais non borné),
- `minColumns <= 0` ⇒ plancher **remonté à 1**,
- `maxColumns` fourni `< max(1, minColumns)` ⇒ **remonté** à `max(1, minColumns)` (clamp valide, aucun `RangeError`).

### AC3 — Frontières & clamp haut (AD-14)
**Given** la fonction de calcul,
**When** on la teste aux frontières,
**Then** elle est **déterministe** : `availableWidth == minItemWidth → 1` ; `availableWidth == 2·minItemWidth → 2` ; `availableWidth == 2·minItemWidth − 1 → 1` (`floor`) ; `availableWidth == ½·minItemWidth → 1` (clamp bas) ; très grande largeur avec `maxColumns: k` → **`k`** (clamp haut) ; `maxColumns: null` → non plafonné (borne haute pratique = `floor`).

### AC4 — `ZAdaptiveGrid` : garde `children` vide → `SizedBox.shrink()` (AD-10 / NFR-U10)
**Given** `ZAdaptiveGrid` (`packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart`, `StatelessWidget`, ctor `const`),
**When** `children` est **vide**,
**Then** `build` retourne **`const SizedBox.shrink()`** et **n'instancie aucun** `GridView`/cellule fantôme (garde évaluée avant le `LayoutBuilder` productif).

### AC5 — Largeur LOCALE via `LayoutBuilder` + colonnes effectives correctes (AD-31 / NFR-U2 / D2)
**Given** `ZAdaptiveGrid` placé dans un conteneur de largeur `w`,
**When** il se construit avec `children` non vides,
**Then** il dérive `availableWidth` **uniquement** de `LayoutBuilder.constraints.maxWidth` — **jamais** `Get.width`, **jamais** `MediaQuery.sizeOf`/`MediaQuery.of(...).size` (écran global),
**And** le nombre de colonnes effectif rendu = `computeCrossAxisCount(availableWidth: constraints.maxWidth, minItemWidth, minColumns, maxColumns)` (ex. conteneur 1000 dp, `minItemWidth 300` → **3 colonnes** ; conteneur 250 dp, `minItemWidth 300` → **1 colonne**),
**And** placé dans un panneau étroit (`SizedBox(width: 250)`) sous un écran large (`MediaQuery` 1400) → **1 colonne** (prouve l'indépendance vis-à-vis de l'écran — D2, anti-bug iffd `Get.width`).

### AC6 — Paramétrable + `childAspectRatio` recalculé sur largeur d'item déduite (AD-31 / D3 / D4)
**Given** `minItemWidth`/`spacing`/`runSpacing`/`itemHeight`/`aspectRatio`/`maxColumns`/`padding` en **paramètres nommés**,
**When** la grille se compose avec `itemHeight` fourni,
**Then** l'aspect est recalculé sur la **largeur d'item déduite** `itemWidth = (constraints.maxWidth − spacing·(n − 1)) / n`, `childAspectRatio = itemWidth / itemHeight` (`itemHeight > 0` requis, sinon repli `aspectRatio ?? 1.0` — garde AD-10),
**And** sans `itemHeight`, `childAspectRatio = aspectRatio ?? 1.0`,
**And** **aucun** ternaire `300/350` codé en dur : la largeur-min est le paramètre `minItemWidth`.

### AC7 — `StatelessWidget` sans manager, `GridView.builder`, RTL-safe, directionnel (AD-2/AD-15/AD-13/NFR-U4)
**Given** la base lex `ResponsiveGrid` (`ConsumerWidget` `ref` mort),
**When** on porte le widget,
**Then** `ZAdaptiveGrid` est un **`StatelessWidget`** pur — **aucun** `ConsumerWidget`/`WidgetRef`/`ref`, **aucun** import `get`/`flutter_riverpod`/`provider`/`go_router`, **aucun** `setState`,
**And** le rendu passe par **`GridView.builder`** (`itemCount` + `itemBuilder`) — **jamais** `GridView.count(children:[...])`/`GridView(children:[...])` non paresseux (NFR-U4),
**And** le widget est **directionnellement neutre** (RTL-safe, AD-13) : `padding` = `EdgeInsetsGeometry?`, **aucun** `EdgeInsets.only(left:/right:)`/`Alignment.centerLeft/Right`/`TextAlign.left/right`/`Positioned(left:/right:)` ; à largeur égale, le nombre de colonnes est **identique** sous `Directionality.ltr` et `.rtl`.

### AC8 — Export au barrel (sérialisé) + gates verts, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** les deux nouveaux fichiers,
**When** on met à jour le barrel et rejoue les gates,
**Then** `lib/zcrud_responsive.dart` **exporte** `src/domain/compute_cross_axis_count.dart` **et** `src/presentation/z_adaptive_grid.dart` (ajout **ciblé** de lignes d'`export`, sans réordonner/altérer les exports existants ni les ré-exports de confort `zcrud_core` ; respecter `directives_ordering`),
**And** ⚠️ l'édition du barrel est **sérialisée** avec EX-UI.2 (jamais deux écritures concurrentes de `lib/zcrud_responsive.dart`),
**And** `melos run generate` est **no-op** (aucun `@ZcrudModel`) ; gate `codegen-distribution` **non concerné** (aucun `part`/`*.g.dart`),
**And** `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** (aucune nouvelle arête `zcrud_*` ; `melos list` **inchangé**),
**And** `dart analyze packages/zcrud_responsive` **RC=0** ; `melos run analyze` **ET** `melos run verify` **repo-wide** RC=0 (délégués au **gate de commit d'epic de l'orchestrateur** ; le dev consigne son `analyze` ciblé vert).

### AC9 — Le calcul des colonnes prend en compte le **padding** du conteneur et l'**espacement** inter-items (change-request 2026-07-16)
**Given** que la largeur brute du conteneur inclut le padding/marge horizontal ET que `n` colonnes impliquent `n-1` gouttières de largeur `spacing`,
**When** on calcule le nombre de colonnes,
**Then** `computeCrossAxisCount` accepte deux paramètres additionnels **`double spacing = 0`** (gouttière inter-items) et **`double horizontalPadding = 0`** (padding/marge horizontal total à retrancher), et applique la formule **`n = ⌊(effectiveWidth + spacing) / (minItemWidth + spacing)⌋`** avec **`effectiveWidth = availableWidth − horizontalPadding`** — de sorte que chaque item fait **au moins** `minItemWidth` **une fois les gouttières et le padding déduits** (fini la surestimation qui écrasait les items sous `minItemWidth`),
**And** les défauts sûrs (AD-10) couvrent les nouveaux cas dégénérés : `spacing` négatif/NaN → traité comme `0` ; `horizontalPadding` négatif/NaN → `0` ; `effectiveWidth ≤ 0` (padding ≥ largeur) → `minColumns` ; `minItemWidth + spacing ≤ 0` → `minColumns` ; **jamais** de throw ni de division par zéro,
**And** `ZAdaptiveGrid` **passe** son propre `spacing` et son `padding` **résolu directionnellement** (`padding?.resolve(Directionality.of(context)).horizontal ?? 0`, AD-13) à `computeCrossAxisCount`, et déduit la largeur d'item sur la **même** base (`effectiveWidth`, gouttières comprises) pour un `childAspectRatio` cohérent,
**And** des tests couvrent : padding qui réduit `n` d'au moins 1 ; spacing qui réduit `n` d'au moins 1 ; padding ≥ largeur → `minColumns` ; rétro-compatibilité (`spacing:0, horizontalPadding:0` ⇒ mêmes résultats qu'avant).

---

## Tasks / Subtasks

- [x] **T1 — Fonction pure `computeCrossAxisCount`** (AC1, AC2, AC3, D1) — `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart`
  - [x] T1.1 Fichier Dart **pur** : aucun import Flutter widgets (au plus `dart:math` si besoin de `max`). Dartdoc complet (formule, défauts sûrs, garantie `≥ 1`, anti-bug iffd).
  - [x] T1.2 `int computeCrossAxisCount({required double availableWidth, required double minItemWidth, int minColumns = 1, int? maxColumns})`.
  - [x] T1.3 Calcul robuste dans l'ordre : (a) `lo = minColumns < 1 ? 1 : minColumns` ; (b) gardes `minItemWidth <= 0 || minItemWidth.isNaN` → `lo` ; (c) gardes `availableWidth <= 0 || availableWidth.isNaN` → `lo` ; (d) `availableWidth.isInfinite` → `maxColumns != null ? max(lo, maxColumns) : lo` ; (e) `raw = (availableWidth / minItemWidth).floor()` ; (f) `hi = maxColumns == null ? null : max(lo, maxColumns)` ; (g) retourner `raw < lo ? lo : (hi != null && raw > hi ? hi : raw)` (⇒ jamais de `RangeError`).
- [x] **T2 — Widget `ZAdaptiveGrid`** (AC4, AC5, AC6, AC7, D2, D3, D4, D5, D6) — `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart`
  - [x] T2.1 `import 'package:flutter/widgets.dart';` + `import '../domain/compute_cross_axis_count.dart';`. ⛔ aucun import gestionnaire d'état/routeur.
  - [x] T2.2 `class ZAdaptiveGrid extends StatelessWidget` ctor `const` avec les champs de D3. Dartdoc de classe + dartdoc par champ.
  - [x] T2.3 `build` : `if (children.isEmpty) return const SizedBox.shrink();` **d'abord** (AC4), puis `LayoutBuilder` → `n = computeCrossAxisCount(...)` → `itemWidth = (constraints.maxWidth − spacing*(n-1)) / n` → `ratio = itemHeight != null && itemHeight! > 0 ? itemWidth / itemHeight! : (aspectRatio ?? 1.0)`.
  - [x] T2.4 Rendu `GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: padding, itemCount: children.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(...), itemBuilder: (_, i) => children[i])`. ⛔ jamais `GridView.count`/`GridView(children:)`.
- [x] **T3 — Barrel** (AC8) — `packages/zcrud_responsive/lib/zcrud_responsive.dart`
  - [x] T3.1 Ajout **ciblé** de `export 'src/domain/compute_cross_axis_count.dart';` (bloc domaine) **et** `export 'src/presentation/z_adaptive_grid.dart';` (bloc presentation), tri alphabétique `directives_ordering` respecté ; ré-exports `zcrud_core` et exports EX-UI.1/EX-UI.2 intacts.
- [x] **T4 — Tests unit PURS `computeCrossAxisCount`** (AC1, AC2, AC3) — `packages/zcrud_responsive/test/compute_cross_axis_count_test.dart`
  - [x] T4.1 Frontières + clamp haut + `maxColumns:null` non plafonné.
  - [x] T4.2 Clamp bas ≥ 1 (anti-bug iffd) : `w=100,minW=300→1` ; `minColumns:0/-5→1`.
  - [x] T4.3 Défauts sûrs — aucun throw (`returnsNormally`) : `minW≤0/NaN`, `w≤0/NaN/∞`, `maxColumns<minColumns`.
- [x] **T5 — Tests widget `ZAdaptiveGrid`** (AC4, AC5, AC6, AC7) — `packages/zcrud_responsive/test/z_adaptive_grid_test.dart`
  - [x] T5.1 Garde vide → `SizedBox` présent, `GridView` absent.
  - [x] T5.2 Colonnes effectives (harness `OverflowBox`) : 1000→3, 250→1, 650+maxColumns:2→2.
  - [x] T5.3 Largeur LOCALE : `SizedBox(width:250)` sous `MediaQuery` 1400 → 1 colonne.
  - [x] T5.4 `childAspectRatio` recalculé avec `itemHeight` ; replis `aspectRatio ?? 1.0` et `itemHeight<=0`.
  - [x] T5.5 RTL → même `crossAxisCount` qu'en LTR.
  - [x] T5.6 Vérif statique : import `flutter` + domaine ; `StatelessWidget` ; `GridView.builder` (`shrinkWrap`/`NeverScrollableScrollPhysics`).
- [x] **T6 — Vérif verte ciblée + graphe** (AC8)
  - [x] T6.1 `dart analyze packages/zcrud_responsive` → RC=0 (No issues found).
  - [x] T6.2 `flutter test packages/zcrud_responsive` → 82 tests verts (49 anciens + 33 neufs).
  - [x] T6.3 `dart run melos run generate` → SUCCESS (no-op, 0 outputs pour zcrud_responsive).
  - [x] T6.4 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK** ; `melos list` inchangé.

---

## Dev Notes

### Fichiers (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart` | **NEW** — fonction pure `computeCrossAxisCount` (Dart pur, sans Flutter widgets) |
| `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` | **NEW** — widget `ZAdaptiveGrid` (`StatelessWidget`) |
| `packages/zcrud_responsive/lib/zcrud_responsive.dart` | **UPDATE** — 2 lignes `export` (domaine + presentation), édition ciblée, **sérialisée** avec EX-UI.2 |
| `packages/zcrud_responsive/test/compute_cross_axis_count_test.dart` | **NEW** — tests unit PURS (sans `BuildContext`) |
| `packages/zcrud_responsive/test/z_adaptive_grid_test.dart` | **NEW** — tests widget |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**` (aucune écriture du cœur — la grille 12-col `ZResponsiveGrid` y reste, on ne la réutilise pas) ; `z_window_size_class.dart` / `z_breakpoint_value.dart` (EX-UI.1) ; `z_responsive_layout.dart` (EX-UI.2) ; `pubspec.yaml` (racine/package — aucune nouvelle dépendance) ; `melos.yaml`. **Coordination barrel** : si EX-UI.2 est en vol en parallèle, **sérialiser** l'édition de `lib/zcrud_responsive.dart`.

### Références de code (best-of-breed, LECTURE SEULE — à neutraliser, PAS copier)

- **lex_ui** `packages/lex_ui/lib/presentation/widgets/responsive_grid.dart` (74 LOC) — patron `ResponsiveGrid` (`floor()+clamp`, largeur d'item déduite, garde vide). **Neutraliser** : `ConsumerWidget → StatelessWidget` (ref mort), renommer **`ZAdaptiveGrid`**, `GridView.count → GridView.builder`, largeur locale confirmée. Tests lex `responsive_grid_test.dart` portables.
- **iffd** `lib/douanes_togolaises/screens/tec_cedeao_screen.dart` (l.662, 781) — **anti-modèle** : `min(3, Get.width ~/ itemMinWidth)` sans clamp bas (0 colonne possible → `x/0`) + `Get.width` (casse en dialog/split). **Corrigé** par clamp `≥ 1` + `LayoutBuilder`.

### Invariants AD applicables (rappel ciblé)

- **AD-31** : **clamp minimum 1** (`minColumns ≥ 1` garanti) ; largeur **locale** `LayoutBuilder.constraints.maxWidth` (jamais `Get.width`/écran figé) ; garde `children.isEmpty → SizedBox.shrink()` ; `spacing`/`itemHeight`/`aspectRatio` paramétrables ; `childAspectRatio` recalculé sur largeur d'item déduite ; **nom `ZAdaptiveGrid`, JAMAIS `ZResponsiveGrid`** (réservé à la grille 12-col de formulaire de `zcrud_core`).
- **AD-1 / NFR-U1** : aucune nouvelle arête `zcrud_*` (domaine = Dart pur ; presentation = `flutter` + import relatif du domaine) ; `CORE OUT=0` intact ; `graph_proof.py` ACYCLIQUE ; `melos list` inchangé.
- **AD-29 (AMENDÉ)** : les deux fichiers vivent sous `lib/src/{domain,presentation}/`, exposés par le barrel ; **aucune** écriture de `zcrud_core` (on n'y réutilise même pas `ZResponsiveGrid`).
- **AD-2 / AD-15 / NFR-U2** : `StatelessWidget`, **aucun** gestionnaire d'état/routeur, **aucun** `setState`.
- **AD-5 / AD-14 / NFR-U6** : calcul délégué à la fonction **pure** `computeCrossAxisCount`, testable **sans `BuildContext`**, déterministe.
- **AD-10 / NFR-U10** : **défauts sûrs** — jamais de division par zéro, jamais de throw, jamais de grille vide/fantôme.
- **AD-13 / NFR-U4** : directionnel (RTL-safe) — `EdgeInsetsGeometry`, `GridView.builder` (jamais `children:[...]` non paresseux).
- **AD-12 / NFR-U8** : zéro secret. **NFR-U7** : enums > booléens (aucun `bool` de config multi-état). **NFR-U11** : pas de codegen.

### Project Structure Notes

- Domaine pur en `lib/src/domain/` (fonction top-level, pas de classe requise) ; widget en `lib/src/presentation/` — convention monorepo. Barrel `lib/<pkg>.dart` = seule API publique.
- **Largeur d'item déduite** (les items s'étirent pour remplir la largeur, pas d'espace résiduel) = parité intentionnelle avec lex/iffd, ≠ `SliverGridDelegateWithMaxCrossAxisExtent` (qui laisserait un reste). C'est pourquoi on passe par `computeCrossAxisCount` + `SliverGridDelegateWithFixedCrossAxisCount` (colonnes fixes calculées), pas par le delegate à extent max.
- Leçon EX-UI.2 (Debug Log) : la surface de test par défaut 800×600 **bride** un `SizedBox(width > 800)` ; pour tester les grandes largeurs utiliser `OverflowBox(minWidth: w, maxWidth: w)` (contrainte tight locale indépendante de la surface).

### Dépendances aval (ce que cette story débloque)

Aucune story EX-UI n'a `ZAdaptiveGrid`/`computeCrossAxisCount` en dépendance dure — **feuille** du graphe EX-UI (parallélisable intra-P1 avec EX-UI.2). Adoption réelle in-app (remplacement des ~24 grilles dupliquées) **déférée** (DW-EXUI-1, sessions app dédiées — aucun fichier d'app touché ici).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.3 (l.176-206 — signature `computeCrossAxisCount`, 5 ACs, garde vide, clamp, bug iffd) ; § CAP-3 (l.41) ; § Séquencement (l.98, parallélisable intra-P1)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-31 (l.99-102 — formule EXACTE, clamp ≥ 1, `ZAdaptiveGrid` jamais `ZResponsiveGrid`, largeur locale) ; § Amendement de réconciliation E3-4 (l.86-87 — grille d'items `ZAdaptiveGrid` distincte de la grille 12-col core) ; § Consistency (l.115-116) ; § À neutraliser (l.200) ; § Stack interdits (l.133)]
- [Source: `packages/zcrud_responsive/lib/zcrud_responsive.dart` (barrel à étendre) ; `packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart` (voisin EX-UI.2, ne pas toucher) ; `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart` (`ZResponsiveGrid` existant — collision de nom à éviter)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-2-responsive-layout.md` (modèle de format + Debug Log harness `OverflowBox`)]
- [Source: exploration best-of-breed `scratchpad/explore/lex.md` (Capacité 1 — `ResponsiveGrid`, `floor()+clamp`+garde vide, `ConsumerWidget` mort) ; `scratchpad/explore/iffd.md` (Capacité 1 — bug `~/` sans clamp bas + `Get.width`)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-13 : `GridView.builder`, variantes directionnelles, pas de gestionnaire d'état dans les packages purs), naming préfixe `Z`, gates CI, vérif verte]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Unit pur (sans `BuildContext`)** | Frontières `w=minW/2·minW/2·minW−1/½·minW`, clamp haut `maxColumns`, `maxColumns:null` non plafonné | AC1, AC3 |
| **Unit pur** | Clamp bas ≥ 1 : `w=100,minW=300→1` ; `minColumns:0/-5→1` | AC1 (anti-bug iffd) |
| **Unit pur** | Défauts sûrs sans throw : `minW≤0/NaN`, `w≤0/NaN/∞`, `maxColumns<minColumns` → jamais `RangeError`, jamais `x/0` | AC2 |
| **Widget** | `children:[]` → `SizedBox.shrink`, aucun `GridView` | AC4 |
| **Widget** | `crossAxisCount` effectif du delegate à largeurs de conteneur forcées (1000/250/650+maxColumns) | AC5, AC6 |
| **Widget** | Largeur LOCALE : `SizedBox(width:250)` sous `MediaQuery` 1400 → 1 colonne | AC5 (anti-`Get.width`) |
| **Widget** | `childAspectRatio` recalculé avec `itemHeight` ; repli `aspectRatio ?? 1.0` | AC6 |
| **Widget** | `Directionality.rtl` → même `crossAxisCount` qu'en LTR | AC7, AD-13 |
| **Statique / revue** | Aucun import `get`/`flutter_riverpod`/`provider`/`go_router` ; `StatelessWidget` ; `GridView.builder` (pas `.count`) ; nom `ZAdaptiveGrid` | AC7 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 ; `analyze` RC=0 ; `generate` no-op ; `melos list` inchangé | AC8 |

**Definition of Done** : AC1→AC8 verts · `computeCrossAxisCount` = fonction **pure** (sans `BuildContext`) avec **`minColumns ≥ 1` garanti** (jamais 0), **aucun throw**, **aucune division par zéro** · `ZAdaptiveGrid` = `StatelessWidget` sans manager, largeur **locale** (`LayoutBuilder`), garde `children` vide → `SizedBox.shrink`, `GridView.builder`, `childAspectRatio` déduit, RTL testé, nom **`ZAdaptiveGrid`** (jamais `ZResponsiveGrid`) · barrel étendu (édition ciblée, **sérialisée** avec EX-UI.2) · `dart analyze` ciblé RC=0 + `flutter test` verts + `melos generate` no-op + `graph_proof` ACYCLIQUE/CORE OUT=0 · `melos run analyze`/`verify` repo-wide RC=0 (gate de commit d'epic orchestrateur) · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high)

### Debug Log References

- Harness widget calqué sur EX-UI.2 (`OverflowBox minWidth/maxWidth = w`) pour forcer une largeur locale tight indépendante de la surface de test 800×600 — permet de tester les grandes largeurs sans overflow.
- Lecture du `crossAxisCount`/`childAspectRatio` effectif via `tester.widget<GridView>(...).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount`.

### Completion Notes List

- ✅ **AC1–AC3** : `computeCrossAxisCount` fonction pure top-level (import unique `dart:math` pour `max`), aucun `BuildContext`. Gardes explicites avant toute division (jamais `x/0`), plancher `lo = max(1, minColumns)`, plafond `hi = max(lo, maxColumns)` — clamp toujours valide, jamais de `RangeError`.
- ✅ **AC4–AC7** : `ZAdaptiveGrid extends StatelessWidget` ctor `const`, garde `children.isEmpty → SizedBox.shrink()` avant tout `LayoutBuilder`, largeur LOCALE `constraints.maxWidth`, `GridView.builder` (`shrinkWrap` + `NeverScrollableScrollPhysics`), `padding` = `EdgeInsetsGeometry?` (RTL-safe), aucun import gestionnaire d'état/routeur.
- ✅ **AC8** : barrel étendu par 2 exports ciblés (tri `directives_ordering`), ré-exports `zcrud_core` et exports EX-UI.1/EX-UI.2 intacts. `melos generate` no-op, graphe ACYCLIQUE / CORE OUT=0.
- **Choix de spec (Q2)** : signature retenue `int? maxColumns` (nullable, illimité par défaut, conforme story) au lieu du `int maxColumns` d'AD-31 l.102 — strictement plus général. Fichier presentation `z_adaptive_grid.dart` / classe `ZAdaptiveGrid` (jamais `ZResponsiveGrid`, réservé grille 12-col core), conforme AD-31 (source la plus récente).
- **Garde AD-10 additionnelle** : `itemHeight <= 0` → repli `aspectRatio ?? 1.0` (évite `itemWidth/0`), testée.
- Vérifs rejouées : `dart analyze` RC=0 (No issues) · `flutter test` 82 verts (49+33) · `melos generate` SUCCESS no-op · `graph_proof` ACYCLIQUE/CORE OUT=0 · `dart pub get` RC=0.

### File List

- `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart` (NEW)
- `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` (NEW)
- `packages/zcrud_responsive/lib/zcrud_responsive.dart` (UPDATE — 2 exports ciblés)
- `packages/zcrud_responsive/test/compute_cross_axis_count_test.dart` (NEW)
- `packages/zcrud_responsive/test/z_adaptive_grid_test.dart` (NEW)

### Questions pour l'orchestrateur (remontées, non bloquantes)

1. **Sérialisation du barrel avec EX-UI.2** : EX-UI.2 et EX-UI.3 ajoutent chacune des lignes d'`export` à `lib/zcrud_responsive.dart`. Si les deux sont en vol, sérialiser l'édition (une story écrit, l'autre rebase) — jamais en parallèle sur ce fichier.
2. **Reconciliation signature `maxColumns`** : la story retient `int? maxColumns` (nullable, illimité par défaut) au lieu du `int maxColumns` non-nullable écrit dans AD-31 (l.102), conformément à la formulation explicite de la story EX-UI.3 (`maxColumns ?? infini`). Choix strictement plus général — signalé pour cohérence de spec.
3. **Nom de fichier presentation** : `z_adaptive_grid.dart` (classe `ZAdaptiveGrid`) et **non** `z_responsive_grid.dart` mentionné (périmé) dans l'épic l.182 — application d'AD-31 (source la plus récente, interdit `ZResponsiveGrid`).
