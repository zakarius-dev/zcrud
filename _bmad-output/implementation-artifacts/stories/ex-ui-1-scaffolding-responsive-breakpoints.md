# Story EX-UI.1 (v2) : [TÊTE BLOQUANTE EX-UI] Scaffolding `zcrud_responsive` (dépend de `zcrud_core`) + breakpoints NOUVEAUX (`ZWindowSizeClass` M3 · `ZBreakpointValue<T>` générique)

Status: review

- **Clé sprint-status** : `ex-ui-1-scaffolding-responsive-breakpoints`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **S/M** (1 package neuf **dépendant de `zcrud_core`** ; 2 fichiers domaine NEUFS + scaffolding ; 0 codegen, 0 entité persistée)
- **Parallélisation** : ⛔ **SÉQUENTIELLE — STORY DE TÊTE BLOQUANTE.** Bloque **EX-UI.2** (`ZResponsiveLayout`, consomme `ZWindowSizeClass`), **EX-UI.3** (`ZAdaptiveGrid` + `computeCrossAxisCount`) et **EX-UI.5** (politique de présentation P2, dérive du `ZWindowSizeClass`). Aucune autre story EX-UI ne démarre avant que celle-ci soit `done`.
- **Package écrit (disjoint)** : `packages/zcrud_responsive/` (NEW) + 1 ligne dans le bloc `workspace:` du **`pubspec.yaml` racine**. ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`) — il **le CONSOMME** en dépendance runtime.
- **AD delta** : **AD-29** (paquets UI purs — **AMENDÉ** : `zcrud_responsive` **dépend de `zcrud_core`** et n'est plus une feuille basse `flutter`-seule), **AD-31** (breakpoints M3 centralisés). **AD hérités** : AD-1 (acyclique, `CORE OUT=0` — l'arête `zcrud_responsive → zcrud_core` est **ENTRANTE au cœur**, licite), AD-2/AD-15 (Flutter-native, aucun gestionnaire d'état), AD-5/AD-14 (pureté testable sans `BuildContext`), AD-13 (RTL/a11y), AD-10 (défauts sûrs), AD-12 (zéro secret).

---

## ⚠️ Note de révision — CETTE v2 CORRIGE UNE PRÉMISSE FAUSSE de la v1

> La v1 de cette story reposait sur une **prémisse fausse** : elle prescrivait de **redéclarer** dans `zcrud_responsive` des symboles `ZBreakpoint` (classe de seuils M3) / une grille 12-col / un span — en **assumant un « overlap de nom » toléré** avec `zcrud_core`, `zcrud_responsive` étant supposé « feuille basse `flutter`-seule sans import du cœur ».
>
> **La décision d'architecture qui fait désormais autorité** — **« Amendement de réconciliation E3-4 », Option A, tranchée par l'utilisateur** — inverse ce postulat :
> - **`zcrud_core` POSSÈDE DÉJÀ** (E3-4, `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart`, **exporté** par le barrel à la ligne 83) : l'enum **`ZBreakpoint { xs, sm, md, lg, xl }`** (5 paliers Bootstrap 576/768/992/1200) + **`ZResponsiveBreakpoints.of(width)`** ; **`ZResponsiveSpan`** (span 1..12 par breakpoint, cascade mobile-first) ; **`ZResponsiveGrid`** (grille 12-col de **formulaire**).
> - **`zcrud_responsive` DÉPEND de `zcrud_core` et RÉUTILISE ces primitives.** ⛔ **INTERDICTION ABSOLUE de redéclarer** `ZBreakpoint`, `ZResponsiveBreakpoints`, `ZResponsiveSpan` ou `ZResponsiveGrid` (collision de nom **réelle**, cette fois, puisqu'on importe le barrel du cœur). **AUCUNE écriture dans `zcrud_core`.**
>
> **Conséquences sur le périmètre v2 :**
> - **Le seul code neuf** de cette story = **deux types** : `ZWindowSizeClass` (enum M3) et `ZBreakpointValue<T>` (générique, bâti **sur** le `ZBreakpoint` de core).
> - **SUPPRIMÉE** : toute redéclaration `ZBreakpoint`/`ZResponsiveBreakpoints`. La classe de seuils M3 de la v1 est remplacée par une **résolution `width → ZWindowSizeClass`** co-localisée avec l'enum (nom neuf, aucune collision).
> - **HORS PÉRIMÈTRE** (autres stories) : `ZAdaptiveGrid` + `computeCrossAxisCount` = **EX-UI.3** (nommé **`ZAdaptiveGrid`**, **JAMAIS** `ZResponsiveGrid` — nom pris par le cœur) ; `ZResponsiveLayout` = **EX-UI.2** ; **grille 12-col de formulaire = SUPPRIMÉE de l'epic EX-UI** (déjà dans `zcrud_core` — ex-EX-UI.4 caduque).

---

## Story

**As a** développeur-mainteneur (Zakarius) préparant l'infrastructure UI transverse,
**I want** créer le package `zcrud_responsive` **dépendant de `zcrud_core`** et y poser **deux primitives de mesure pures NEUVES** — une classe de fenêtre Material 3 en enum (`ZWindowSizeClass`, seuils 600/840) et une valeur-par-breakpoint générique multi-paliers (`ZBreakpointValue<T>`) **bâtie sur l'enum `ZBreakpoint` à 5 paliers déjà fourni par `zcrud_core`** — dérivables **sans `BuildContext`**,
**so that** toute la responsivité aval (layout EX-UI.2, grille adaptative EX-UI.3, politique de présentation EX-UI.5) repose sur des seuils **uniques, réutilisés du cœur** (jamais recodés ad hoc) et une classe de fenêtre **en enum** (jamais un `bool isMobile/isTablet/isDesktop`), sans dépendre d'une largeur globale type `Get.width`.

---

## Contexte — vérifié sur disque (pas sur la foi de l'épic)

### Ce que `zcrud_core` EXPOSE DÉJÀ (lu — c'est la base réutilisée)

`packages/zcrud_core/lib/zcrud_core.dart:83` exporte `src/presentation/edition/z_responsive_grid.dart`, qui déclare **publiquement** :

| Symbole `zcrud_core` (E3-4) | Nature | Détail (lu sur disque) |
|---|---|---|
| **`ZBreakpoint`** | **enum** `{ xs, sm, md, lg, xl }` | 5 paliers Bootstrap. **← RÉUTILISÉ par `ZBreakpointValue<T>`** |
| **`ZResponsiveBreakpoints`** | `abstract final class` | seuils `sm=576, md=768, lg=992, xl=1200` + `static ZBreakpoint of(double width)`. **← RÉUTILISÉ pour `ZBreakpointValue.resolve(width)`** |
| **`ZResponsiveSpan`** | `@immutable class` | `xs=12` défaut + `sm/md/lg/xl?`, cascade mobile-first `spanAt(bp)`, bornage `[1,12]`, `==`/`hashCode`. **← PATRON à généraliser** (`ZBreakpointValue<T>` = sa version générique `T`) |
| **`ZResponsiveGrid`** | `StatelessWidget` | grille 12-col de **formulaire** (`LayoutBuilder` + `Wrap`, place stable). **← NON touché ; la grille adaptative EX-UI.3 s'appellera `ZAdaptiveGrid`** |

⛔ **Aucun de ces 4 symboles n'est redéclaré dans `zcrud_responsive`.** `zcrud_responsive` `import 'package:zcrud_core/zcrud_core.dart';` et **réutilise** `ZBreakpoint` (comme axe de `ZBreakpointValue<T>`) et `ZResponsiveBreakpoints.of` (pour résoudre une largeur en `ZBreakpoint`).

### Ce qui existe dans les apps (best-of-breed, LECTURE SEULE — à neutraliser, pas copier)

- **lex** `packages/lex_ui/lib/core/utils/breakpoints.dart` (zéro-dép, `MediaQuery.sizeOf`, bools `isMobile/isTablet/isDesktop`, seuils `mobile=600/tablet=1200`) → patron du helper `of(context)` ; **retirer** les bools au profit de `ZWindowSizeClass`.
- **dodlp** `lib/modules/data_crud/utils/responsive_utils.dart` : `enum ScreenBreakpoint {xs..xl}` (déjà couvert par `ZBreakpoint` du cœur) + `class BreakpointValue<T>` (générique, cascade `getValueForWidth`, `Get.width`) → patron de `ZBreakpointValue<T>` ; **remplacer** `Get.width` par une largeur passée en argument (pur).
- **4 impls concurrentes** de seuils dans les apps (`600/800/840/900`) — incohérentes. Convention unique Material 3 = **`600 / 840`** pour `ZWindowSizeClass`.

### Point de déclaration du package dans le workspace (vérifié)

- **`pubspec.yaml` racine → bloc `workspace:`** = **SEUL** point de déclaration (commentaire du fichier : *« CE BLOC `workspace:` est le SEUL point de déclaration d'un nouveau package produit »*). ⇒ **ajouter `- packages/zcrud_responsive`**.
- **`melos.yaml`** = glob `packages/**` (n'énumère aucun package nommément) → **rien à y ajouter** ; il picore le nouveau dossier. ⛔ **Ne PAS toucher son bloc `scripts:`** (le gate `gate:melos` compare `pubspec.yaml`↔`melos.yaml` — n'y touche pas si tu ne touches pas l'autre).
- **`melos list`** passe de **N** à **N+1** (les 2 harnais `tool/` restent dans `melos.ignore`). Le dev **mesure N sur disque** avant/après et consigne le chiffre exact (le commentaire « reste 15 » du root pubspec peut être périmé — **ne PAS coder en dur**).

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — `zcrud_responsive` DÉPEND de `zcrud_core:^0.2.0` (Amendement E3-4, Option A)

`pubspec.yaml` déclare `dependencies: { flutter: {sdk: flutter}, zcrud_core: ^0.2.0 }`. Version **`0.2.0`** confirmée sur disque (`packages/zcrud_core/pubspec.yaml:10`). ⛔ **Aucun gestionnaire d'état** (`get`/`flutter_riverpod`/`provider`), **aucun routeur** (`go_router`), **aucun tiers responsive** (`responsive_builder`), **aucun `dartz`** (inutile ici). L'arête `zcrud_responsive → zcrud_core` est **ENTRANTE au cœur** ⇒ **`CORE OUT=0` reste intact** ; `graph_proof.py` doit rester **ACYCLIQUE**.

### D2 — `ZBreakpointValue<T>` = généralisation générique de `ZResponsiveSpan`, bâtie SUR `ZBreakpoint` (core)

`ZResponsiveSpan` du cœur est un `ZBreakpointValue<int>` **spécialisé et borné `[1,12]`**. `ZBreakpointValue<T>` en est la **version générique** : même **enum d'axe** (`ZBreakpoint` de `zcrud_core`, 5 paliers), même **cascade mobile-first** (repli vers le palier inférieur renseigné), sans le bornage int. **API :**
- palier de base **`xs` requis** (`T`) + `sm`/`md`/`lg`/`xl` **optionnels** (`T?`) ;
- **`T valueAt(ZBreakpoint bp)`** — résolution avec cascade `xl→lg→md→sm→xs` (identique à `spanAt`, sans clamp) ;
- **`T resolve(double width)`** — helper largeur : `valueAt(ZResponsiveBreakpoints.of(width))` (⇒ **réutilise** la table de seuils du cœur, **jamais** de seuils recopiés) ;
- `@immutable`, `==`/`hashCode` par valeur (patron `ZResponsiveSpan` du cœur).

**Justification du découplage `ZBreakpointValue<T>` (5 paliers) ↔ `ZWindowSizeClass` (3 paliers)** : deux notions orthogonales — l'une porte une *valeur d'authoring par palier fin* (Bootstrap, réutilisé du cœur), l'autre classe la *fenêtre* pour un choix de présentation (M3). Les fusionner forcerait soit une perte de granularité, soit une politique à 5 branches. **Coexistence documentée** dans le dartdoc.

### D3 — `ZWindowSizeClass` : enum M3 à 3 paliers, seuils 600/840 NEUFS (distincts du cœur)

`enum ZWindowSizeClass { compact, medium, expanded }` (valeurs **camelCase**). Résolution **pure** `width → ZWindowSizeClass` co-localisée (fonction/méthode statique), avec ses **propres** constantes de seuils M3 (`mediumMinWidth = 600`, `expandedMinWidth = 840`) — **nom neuf**, **aucune** collision avec `ZResponsiveBreakpoints` du cœur (qui porte 576/768/992/1200). C'est **délibérément** une seconde table de seuils, sémantiquement distincte (M3 vs Bootstrap), et le dartdoc l'énonce.

### D4 — Défaut sûr, jamais de `throw` (AD-10)

Les deux résolutions (`width → ZWindowSizeClass` et `ZBreakpointValue.resolve(width)`) **ne lèvent JAMAIS** : `0`, négatif, `double.infinity`, `double.nan`. Pour `NaN`, toute comparaison `NaN >= seuil` est `false` ⇒ la cascade retombe **naturellement** sur le palier de base (`compact` / `xs`) — défaut sûr voulu (AD-10). **Tester explicitement `NaN`, `-1`, `0`, `infinity`.** (Note : `ZResponsiveBreakpoints.of` du cœur retourne déjà `xs` pour `NaN`/négatif — vérifié l. 79-85 ; `resolve` en hérite.)

### D5 — Enums > booléens (NFR-U7)

**Aucune** API publique n'expose de `bool` multi-état de classe d'écran (`isMobile`/`isTablet`/`isDesktop` **interdits**). `ZWindowSizeClass` est l'**unique** type de classe de fenêtre.

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZWindowSizeClass` et `ZBreakpointValue<T>` sont **UI-pure**, **non persistés**, **aucun `@ZcrudModel`/`@JsonSerializable`**. ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concerné**, **aucun `@JsonKey(unknownEnumValue:)`** requis (l'enum n'est jamais sérialisé). **Confirmer** le no-op au 1er `melos run generate` (AC6). Si un besoin de sérialisation émergeait plus tard, l'enum devrait alors porter `@JsonKey(unknownEnumValue:)` (AD-10) — hors périmètre.

---

## Acceptance Criteria

### AC1 — Scaffolding du package `zcrud_responsive` (dépend de `zcrud_core`)
**Given** l'absence du package,
**When** on crée `packages/zcrud_responsive/`,
**Then** il contient :
- `pubspec.yaml` : `name: zcrud_responsive`, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2` (aligné sur `zcrud_core`), `dependencies` = **`flutter: {sdk: flutter}` + `zcrud_core: ^0.2.0`** (⛔ **aucun autre `zcrud_*`**, ⛔ **aucun gestionnaire d'état** `get`/`flutter_riverpod`/`provider`, ⛔ **aucun routeur** `go_router`, ⛔ **aucun** `dartz`, ⛔ le tiers `responsive_builder`), `dev_dependencies` = `flutter_test: {sdk: flutter}`, plus `homepage`/`repository`/`issue_tracker`/`topics` sur le patron de `zcrud_core/pubspec.yaml` ;
- `analysis_options.yaml` : `include: ../../analysis_options.yaml` (baseline de lint partagée) ;
- barrel `lib/zcrud_responsive.dart` (dartdoc d'API + exports des 2 fichiers domaine neufs ; **peut** ré-exporter au besoin `ZBreakpoint`/`ZResponsiveBreakpoints` de `zcrud_core` pour le confort du consommateur, **ou** documenter explicitement qu'ils proviennent de `zcrud_core` — jamais les **redéclarer**) ;
- arbo `lib/src/domain/` (les 2 fichiers neufs). `lib/src/presentation/` est **créée mais vide** en EX-UI.1 (peuplée par EX-UI.2/3) — pas de placeholder inutile ;
- `README.md` minimal (rôle, dépendance à `zcrud_core`, 1 exemple, mention monorepo, patron `zcrud_core/README.md`).
**And** `- packages/zcrud_responsive` est ajouté au bloc **`workspace:` du `pubspec.yaml` racine** (à sa place logique ; ne pas réordonner le reste) ; **`melos.yaml` inchangé** (glob `packages/**`).

### AC2 — `ZWindowSizeClass` (enum M3, 3 paliers) — remplace les bools
**Given** le besoin de classer la fenêtre,
**When** on définit `enum ZWindowSizeClass { compact, medium, expanded }` (`lib/src/domain/z_window_size_class.dart`, valeurs **camelCase**),
**Then** c'est l'**unique** type de classe d'écran exposé — **aucun** `bool` multi-état (`isMobile`/`isTablet`/`isDesktop`) dans l'API publique (NFR-U7 « enums > booléens »),
**And** l'enum est **UI-pure**, **non sérialisé** (D6) ⇒ **pas de `@JsonKey`**.

### AC3 — Résolution `width → ZWindowSizeClass` : PURE (sans `BuildContext`), seuils M3 centralisés, défensive
**Given** les 4 impls concurrentes (`600/800/840/900`),
**When** on implémente la résolution pure (fonction/méthode statique co-localisée, ex. `ZWindowSizeClass fromWidth(double width)`), avec les seuils **Material 3** centralisés en constantes (`mediumMinWidth = 600`, `expandedMinWidth = 840`, **nom neuf**, distinct de `ZResponsiveBreakpoints` du cœur),
**Then** elle est **pure**, **testable sans `BuildContext`** (NFR-U6/AD-14), déterministe, et retourne :
- `width < 600` → `compact` (inclut `0`, négatif, `NaN` → **défaut sûr `compact`**, **jamais de throw** — AD-10/D4),
- `600 ≤ width < 840` → `medium`,
- `width ≥ 840` → `expanded`,
**And** aucun des nombres `600`/`840` n'est redéclaré ailleurs dans le package,
**And** le dartdoc explicite que cette table M3 (600/840) **coexiste délibérément** avec la table Bootstrap (576/768/992/1200) de `ZResponsiveBreakpoints`/`ZBreakpoint` **réutilisée du cœur** — sans la remplacer.

### AC4 — `ZBreakpointValue<T>` : générique, bâti SUR `ZBreakpoint` (core), cascade, `valueAt` + `resolve`
**Given** un besoin de valeur dépendante du palier fin (span, padding, colonnes…),
**When** on définit `ZBreakpointValue<T>` (`lib/src/domain/z_breakpoint_value.dart`) avec `import 'package:zcrud_core/zcrud_core.dart'`, palier de base **`xs` requis** (`T`) + `sm`/`md`/`lg`/`xl` **optionnels** (`T?`),
**Then** **`T valueAt(ZBreakpoint bp)`** (l'enum `ZBreakpoint` **provient de `zcrud_core`**, non redéclaré) retourne la valeur du palier `bp` **ou, à défaut, celle du palier inférieur le plus proche renseigné** (cascade `xl→lg→md→sm→xs`), de façon **déterministe et pure**,
**And** **`T resolve(double width)`** délègue à **`ZResponsiveBreakpoints.of(width)`** (de `zcrud_core`) puis `valueAt` — **réutilise** la table de seuils du cœur, **jamais** de seuils recopiés ; **pur**, **jamais de throw** (`NaN`/négatif → `xs` via le cœur — D4),
**And** l'échelle 5-paliers reste **découplée** de `ZWindowSizeClass` (3 paliers) — coexistence énoncée dans le dartdoc (D2),
**And** `ZBreakpointValue` est `@immutable` avec `==`/`hashCode` par valeur (patron `ZResponsiveSpan` du cœur, sans le clamp `[1,12]`),
**And** **aucun** des symboles `ZBreakpoint`/`ZResponsiveBreakpoints`/`ZResponsiveSpan`/`ZResponsiveGrid` n'est **redéclaré** dans `zcrud_responsive`.

### AC5 — Helper contextuel via `MediaQuery.sizeOf`, jamais `Get.width` (NFR-U2/AD-31), RTL-safe
**Given** un besoin de dériver la classe d'écran depuis un `BuildContext`,
**When** on expose un helper `of(BuildContext context) → ZWindowSizeClass` (méthode statique ou extension),
**Then** il lit la largeur **toujours** via **`MediaQuery.sizeOf(context)`** (pas `MediaQuery.of(context).size`, pour ne se réabonner qu'à la taille) et délègue à la résolution pure d'AC3 — **jamais** `Get.width`/`MediaQueryData` figée, **jamais** d'import de gestionnaire d'état (NFR-U2/AD-2/AD-15),
**And** le helper reste correct sous `Directionality.rtl` (la mesure de largeur est directionnellement neutre — AD-13/NFR-U4) — **testé**.

### AC6 — Graphe, gates verts repo-wide, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** le package `zcrud_responsive`,
**When** on inspecte le graphe et rejoue les gates,
**Then** `zcrud_responsive` a **exactement une** arête `zcrud_*` **sortante** (`→ zcrud_core`) et **zéro** entrante ; `zcrud_core` **n'a aucune arête vers lui** (`CORE OUT=0` intact) ; `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0**,
**And** `melos run generate` est un **no-op** pour ce package (aucun `@ZcrudModel` — NFR-U11 confirmée), gate `codegen-distribution` **non concerné** (aucun `part`/`*.g.dart`),
**And** `melos run analyze` **RC=0** et `melos run verify` **RC=0** **repo-wide**,
**And** `melos list` = **N+1** (valeur N **mesurée sur disque** et consignée ; les 2 harnais `tool/` restent ignorés).

---

## Tasks / Subtasks

- [x] **T1 — Scaffolding du package** (AC1, AC6) — `packages/zcrud_responsive/`
  - [x] T1.1 `pubspec.yaml` : `flutter` + **`zcrud_core: ^0.2.0`** (+ `flutter_test` dev) ; `publish_to: none` ; `resolution: workspace` ; `sdk: ^3.12.2` ; `homepage`/`repository`/`issue_tracker`/`topics` calqués sur `zcrud_core`.
  - [x] T1.2 `analysis_options.yaml` (`include: ../../analysis_options.yaml`).
  - [x] T1.3 Arbo `lib/src/domain/` (+ `lib/src/presentation/` vide, non exportée en EX-UI.1).
  - [x] T1.4 Ajouter `- packages/zcrud_responsive` au bloc **`workspace:` du `pubspec.yaml` racine**. ⛔ **Ne PAS toucher `melos.yaml`.**
  - [x] T1.5 `README.md` minimal (mentionne la dépendance à `zcrud_core` et la réutilisation de `ZBreakpoint`).
  - [x] T1.6 `dart pub get` racine (bootstrap workspace) → résolution OK (`zcrud_core` résolu en dépendance de chemin/workspace).

- [x] **T2 — Domaine pur : les 2 primitives NEUVES** (AC2, AC3, AC4, AC5)
  - [x] T2.1 `z_window_size_class.dart` : `enum ZWindowSizeClass { compact, medium, expanded }` + constantes M3 (`mediumMinWidth=600`, `expandedMinWidth=840`) + résolution pure `fromWidth(double)` (défaut sûr `compact`, jamais de throw) + helper `of(BuildContext)` via `MediaQuery.sizeOf`. Dartdoc « enums > bools » + coexistence M3/Bootstrap.
  - [x] T2.2 `z_breakpoint_value.dart` : `import 'package:zcrud_core/zcrud_core.dart'` ; `ZBreakpointValue<T>` (`@immutable`, `xs` requis + `sm/md/lg/xl?`, `valueAt(ZBreakpoint)` cascade pure, `resolve(double)` via `ZResponsiveBreakpoints.of`, `==`/`hashCode`). Dartdoc du **découplage** D2 + mention explicite « `ZBreakpoint` réutilisé de `zcrud_core`, non redéclaré ».

- [x] **T3 — Barrel + documentation d'API** (AC1, D1, D2)
  - [x] T3.1 `lib/zcrud_responsive.dart` : dartdoc de barrel (rôle, **dépend de `zcrud_core`**, AD-29 amendé) + exports des 2 fichiers neufs + note de **réutilisation** de `ZBreakpoint`/`ZResponsiveBreakpoints` (ré-export de confort `show ZBreakpoint, ZResponsiveBreakpoints, ZResponsiveSpan`) + note de **coexistence** des 2 échelles (D2/D3).

- [x] **T4 — Tests** (AC2, AC3, AC4, AC5)
  - [x] T4.1 `test/z_window_size_class_test.dart` (pur-Dart, **sans `BuildContext`**) : bornes **599 → compact**, **600 → medium**, **839 → medium**, **840 → expanded** ; défauts sûrs **`0` → compact**, **`-1` → compact**, **`NaN` → compact**, **`double.infinity` → expanded**.
  - [x] T4.2 `test/z_breakpoint_value_test.dart` (pur) : `valueAt` par palier exact ; **cascade** (ex. `sm`/`lg` absents → hérite `xs`/`md`) ; `resolve(width)` aux bornes Bootstrap (575/576/1199/1200) ; `NaN`/négatif → `xs` ; `==`/`hashCode`.
  - [x] T4.3 `test/z_window_size_class_context_test.dart` (**widget test**) : `ZWindowSizeClass.of(context)` sous `MediaQuery` simulée (500/700/1000 → compact/medium/expanded) **et** sous `Directionality.rtl` (résultat inchangé).

- [x] **T5 — Vérif verte repo-wide + graphe** (AC6)
  - [x] T5.1 `melos run generate` (no-op pour le package : aucun `build_runner`, 0 `.g.dart`) → SUCCESS.
  - [~] T5.2 `dart analyze packages/zcrud_responsive` RC=0 (0 issue). `melos run analyze`/`verify` **repo-wide** → délégués à l'orchestrateur (gate de commit d'epic).
  - [x] T5.3 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE / CORE OUT=0** (arête `zcrud_responsive→zcrud_core` entrante au cœur) ; `melos list` = **21** (N=20 mesuré avant, N+1).
  - [x] T5.4 `flutter test` du package → **35 tests** verts.

---

## Dev Notes

### Fichiers à créer (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_responsive/pubspec.yaml` | NEW — `flutter` + `zcrud_core: ^0.2.0` |
| `packages/zcrud_responsive/analysis_options.yaml` | NEW — `include: ../../analysis_options.yaml` |
| `packages/zcrud_responsive/README.md` | NEW — minimal |
| `packages/zcrud_responsive/lib/zcrud_responsive.dart` | NEW — barrel |
| `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` | NEW |
| `packages/zcrud_responsive/lib/src/domain/z_breakpoint_value.dart` | NEW |
| `packages/zcrud_responsive/test/z_window_size_class_test.dart` | NEW |
| `packages/zcrud_responsive/test/z_breakpoint_value_test.dart` | NEW |
| `packages/zcrud_responsive/test/z_window_size_class_context_test.dart` | NEW |
| `pubspec.yaml` (racine) | **UPDATE** — 1 ligne dans le bloc `workspace:` |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**` (ses primitives sont **réutilisées**, jamais réécrites ni redéclarées), `melos.yaml` (glob `packages/**` — rien à ajouter ; `gate:melos` compare son `scripts:` à `pubspec.yaml`).

### Références de code (best-of-breed, lecture seule — À RÉUTILISER/NEUTRALISER, pas copier)

- **`zcrud_core`** `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart` — **source RÉUTILISÉE** : `ZBreakpoint` (enum axe de `ZBreakpointValue<T>`), `ZResponsiveBreakpoints.of` (délégation de `resolve`), `ZResponsiveSpan` (**patron** de cascade `spanAt` + `==`/`hashCode` à généraliser en `T`). **IMPORTER** ce barrel ; **ne rien redéclarer.**
- **lex** `packages/lex_ui/lib/core/utils/breakpoints.dart` — patron `MediaQuery.sizeOf` pour `of(context)`. **Retirer** les bools `isMobile/...` → `ZWindowSizeClass`.
- **dodlp** `lib/modules/data_crud/utils/responsive_utils.dart` — patron `BreakpointValue<T>` (cascade). **Remplacer** `Get.width` par la largeur en argument (pur) ; conserver la cascade.

### Invariants AD applicables (rappel ciblé)

- **AD-1 / NFR-U1** : `zcrud_responsive` a **1 arête sortante** (`→ zcrud_core`), **0 entrante** ; `CORE OUT=0` intact (l'arête est **entrante** au cœur). `graph_proof.py` ne compte que les arêtes `zcrud_*` ; `flutter` n'en ajoute aucune. **Acyclicité** préservée (le cœur ne dépend de personne).
- **AD-29 (AMENDÉ)** : `zcrud_responsive` n'est **plus** une feuille `flutter`-seule — il **dépend de `zcrud_core`** et **réutilise** ses primitives responsives (décision « réconciliation E3-4 », Option A). Aucun autre `zcrud_*`.
- **AD-31** : breakpoints M3 (`ZWindowSizeClass`) centralisés ; mesure via `MediaQuery.sizeOf`, **jamais** `Get.width`.
- **AD-2 / AD-15 / NFR-U2** : **aucun** gestionnaire d'état/routeur importé.
- **AD-5 / AD-14 / NFR-U6** : dérivations **pures**, testables **sans `BuildContext`** (seuls `of(context)` et le widget test en ont besoin).
- **AD-10 / NFR-U10** : défaut sûr `compact`/`xs`, **jamais de throw** (`0`/négatif/`NaN`/`infinity`).
- **AD-13 / NFR-U4** : helper correct sous `Directionality.rtl` (mesure directionnellement neutre) — testé.
- **AD-12 / NFR-U8** : zéro secret (`gate:secrets` reste vert).
- **NFR-U7 (enums > booléens)** : `ZWindowSizeClass` **remplace** tout `bool` de classe d'écran.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- Le package suit `lib/<pkg>.dart` (barrel) + `lib/src/{domain,presentation}` comme tous les packages du monorepo.
- **Variance vs l'ancien AD-29 (documentée) :** `zcrud_responsive` **dépend de `zcrud_core`** (n'est plus feuille `flutter`-seule) — assumé par l'Amendement de réconciliation E3-4 (Option A), qui **supprime** la redéclaration de breakpoints/grille au profit de la **réutilisation** des primitives du cœur.
- `melos.yaml` n'énumère aucun package (glob) ; **le seul ajout de déclaration est dans `pubspec.yaml` racine (`workspace:`)**.

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.1 débloque : **EX-UI.2** (`ZResponsiveLayout`, consomme `ZWindowSizeClass`), **EX-UI.3** (`ZAdaptiveGrid` + `computeCrossAxisCount` — **nommé `ZAdaptiveGrid`**, jamais `ZResponsiveGrid`), **EX-UI.5** (`ZPresentationPolicy`, dérive le mode de `ZWindowSizeClass`). *(L'ex-EX-UI.4 « grille 12-col de formulaire » est **caduque** — déjà fournie par `zcrud_core` — `ZResponsiveGrid`/`ZResponsiveSpan`.)*

### References

- [Source: **Amendement de réconciliation E3-4 (Option A, tranché par l'utilisateur)** — `zcrud_responsive` dépend de `zcrud_core` et réutilise `ZBreakpoint`/`ZResponsiveBreakpoints`/`ZResponsiveSpan`/`ZResponsiveGrid` ; interdiction de redéclarer ; aucune écriture dans `zcrud_core`]
- [Source: `packages/zcrud_core/lib/zcrud_core.dart:81-83` (export `z_responsive_grid.dart`) ; `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart:44-163` (`ZBreakpoint` enum, `ZResponsiveBreakpoints.of` l.79-85, `ZResponsiveSpan.spanAt` l.131-148 — PATRON de cascade)]
- [Source: `packages/zcrud_core/pubspec.yaml:10` (`version: 0.2.0`), `:24-25` (`sdk: ^3.12.2`), `:14-22` (homepage/topics — patron)]
- [Source: `pubspec.yaml` racine (bloc `workspace:` = seul point de déclaration, l.20+) ; `melos.yaml` (glob `packages/**`, miroir `scripts:` — `gate:melos`)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-29 (amendé), AD-31 ; § Open questions (réconciliation d'échelle — tranchée D2/D3)]
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.1 (périmètre v2) ; § Séquencement]
- [Source: `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-13), naming préfixe `Z`, gates CI]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Domaine pur** (sans `BuildContext`) | `fromWidth` : bornes 599/600/839/840 + `0`/`-1`/`NaN`/`infinity` | AC3, D4 |
| **Domaine pur** | `ZBreakpointValue` : `valueAt` par palier + cascade + `resolve` aux bornes Bootstrap (575/576/1199/1200) + `NaN`/négatif → `xs` + `==`/`hashCode` | AC4, D2 |
| **Widget** | `ZWindowSizeClass.of(context)` sous `MediaQuery` (500/700/1000) **et** `Directionality.rtl` | AC5, AD-13 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (1 arête entrante au cœur) ; `analyze`+`verify` repo-wide RC=0 ; `generate` no-op ; `melos list` = N+1 | AC6, NFR-U1/U11 |

**Definition of Done** : AC1→AC6 verts · `pubspec.yaml` = `flutter` + `zcrud_core: ^0.2.0` **uniquement** (aucun autre `zcrud_*`, aucun gestionnaire d'état/routeur) · **aucun symbole `ZBreakpoint`/`ZResponsiveBreakpoints`/`ZResponsiveSpan`/`ZResponsiveGrid` redéclaré** (réutilisés de `zcrud_core`) · `melos run generate` (no-op) + `melos run analyze` **ET** `melos run verify` **repo-wide** RC=0 · `graph_proof` ACYCLIQUE/CORE OUT=0 · coexistence M3/Bootstrap documentée · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- `dart pub get` (workspace) → RC=0.
- `dart run melos run generate` → SUCCESS (no-op pour `zcrud_responsive` : pas de `build_runner`, 0 `.g.dart`).
- `dart analyze packages/zcrud_responsive` → RC=0, « No issues found! » (après correction du seul lint `directives_ordering` : ré-export `package:` placé avant les exports relatifs dans le barrel).
- `flutter test packages/zcrud_responsive` → 35 tests, tous verts.
- `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK / CORE OUT=0 OK (arête `zcrud_responsive -> zcrud_core` entrante au cœur).
- `melos list` = 21 (mesuré N=20 avant, N+1 après).

### Completion Notes List

- **AD-29 amendé respecté** : `zcrud_responsive` dépend de `zcrud_core` et **réutilise** `ZBreakpoint` / `ZResponsiveBreakpoints` / `ZResponsiveSpan` — aucun de ces 4 symboles n'est redéclaré. `ZResponsiveGrid` n'est pas touché.
- **Q1 tranchée dans le sens recommandé** : ré-export de confort explicite via `export 'package:zcrud_core/zcrud_core.dart' show ZBreakpoint, ZResponsiveBreakpoints, ZResponsiveSpan;` (types toujours définis dans `zcrud_core`).
- **Périmètre** : aucune écriture dans `packages/zcrud_core/**` ni `melos.yaml` (vérifié `git status` vide pour ces chemins). Seul ajout hors package = 1 ligne (+ commentaire) dans le bloc `workspace:` du `pubspec.yaml` racine.
- **Défaut sûr (AD-10)** : `fromWidth` et `resolve` ne lèvent jamais (`NaN`/négatif/0 → `compact`/`xs` ; `infinity` → `expanded`/`xl`) — testé explicitement.
- **NFR-U7** : `ZWindowSizeClass` est l'unique type de classe d'écran (aucun `bool isMobile/isTablet/isDesktop`).
- **T5.2** : `dart analyze` ciblé RC=0 ; les gates `melos run analyze`/`verify` **repo-wide** relèvent du gate de commit d'epic de l'orchestrateur (réservé). Aucun `.g.dart`/`part` ⇒ gate `codegen-distribution` non concerné.

### File List

**NEW**
- `packages/zcrud_responsive/pubspec.yaml`
- `packages/zcrud_responsive/analysis_options.yaml`
- `packages/zcrud_responsive/README.md`
- `packages/zcrud_responsive/lib/zcrud_responsive.dart`
- `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart`
- `packages/zcrud_responsive/lib/src/domain/z_breakpoint_value.dart`
- `packages/zcrud_responsive/lib/src/presentation/.gitkeep` (dossier créé vide en EX-UI.1, peuplé par EX-UI.2/3)
- `packages/zcrud_responsive/test/z_window_size_class_test.dart`
- `packages/zcrud_responsive/test/z_breakpoint_value_test.dart`
- `packages/zcrud_responsive/test/z_window_size_class_context_test.dart`

**UPDATE**
- `pubspec.yaml` (racine) — 1 ligne (`- packages/zcrud_responsive`) + commentaire dans le bloc `workspace:`.

### Questions pour l'orchestrateur (remontées, non bloquantes pour le dev)

1. **Ré-export de confort vs renvoi documenté** (AC1/T3.1) : le barrel `zcrud_responsive` peut **ré-exporter** `ZBreakpoint`/`ZResponsiveBreakpoints` de `zcrud_core` (un seul import pour le consommateur) **ou** simplement documenter leur provenance. Le premier facilite EX-UI.2/3 mais crée un point d'export dupliqué. **Recommandation : ré-export de confort explicite** (les types restent **définis** dans `zcrud_core`, jamais redéclarés). À valider.
2. **`ZAdaptiveGrid` (EX-UI.3)** : confirmer le nom **`ZAdaptiveGrid`** (jamais `ZResponsiveGrid`, pris par le cœur) pour la grille adaptative aval — cohérent avec l'Amendement E3-4 (le cœur garde SA grille 12-col de formulaire ; EX-UI fournit une grille adaptative distincte).
