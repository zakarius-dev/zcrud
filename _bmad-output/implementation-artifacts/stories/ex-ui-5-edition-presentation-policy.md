# Story EX-UI.5 : [TÊTE P2] Scaffolding `zcrud_navigation` (dépend de `zcrud_core` + `zcrud_responsive`) + politique de présentation PURE (`ZEditionPresentation` + `ZPresentationPolicy`)

Status: review

- **Clé sprint-status** : `ex-ui-5-edition-presentation-policy`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **M** (1 package neuf **dépendant de `zcrud_core` + `zcrud_responsive`** ; 2 (ou 3) fichiers domaine NEUFS + scaffolding ; 0 codegen, 0 entité persistée, 0 widget)
- **Parallélisation** : ⛔ **SÉQUENTIELLE — PREMIÈRE STORY DE P2 (nav).** Dépend d'**EX-UI.1** (`done` — fournit `ZWindowSizeClass`). **Précède EX-UI.6** (`ZFormPresenter` + `ZAdaptivePresenter`, **même package**, séquentiel). Parallélisable avec le workstream **P3** (`zcrud_ui_kit`, EX-UI.7..10) car packages disjoints.
- **Package écrit (disjoint)** : `packages/zcrud_navigation/` (NEW) + 1 ligne dans le bloc `workspace:` du **`pubspec.yaml` racine**. ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_responsive`** — il **les CONSOMME** en dépendances runtime.
- **AD delta** : **AD-30** (politique de présentation dérivée du breakpoint ; `enum ZEditionPresentation` ; `ZPresentationPolicy` injectable — **le maillon manquant**). **AD hérités** : AD-1 (acyclique, `CORE OUT=0` — les arêtes `zcrud_navigation → {zcrud_core, zcrud_responsive}` sont **SORTANTES**, aucune n'entre dans ce package), AD-6 (injectable/seam), AD-4 (jamais `sealed`), AD-2/AD-15 (Flutter-native, **aucun** gestionnaire d'état **ni routeur**), AD-5/AD-14 (pureté testable **sans `BuildContext`**), AD-10 (défaut sûr, jamais de throw), AD-12 (zéro secret).

---

## ⚠️ Périmètre — CE QUI EST DANS / HORS de cette story

> **DANS EX-UI.5** — scaffolding du package `zcrud_navigation` + **politique PURE de domaine** :
> - `enum ZEditionPresentation { page, sheet, dialog }` (valeurs camelCase) ;
> - `enum ZFormWeight { light, heavy }` (critère de poids de formulaire — **un enum, jamais un `bool`**, NFR-U7) ;
> - `ZPresentationPolicy` : dérive **PUREMENT** un `ZEditionPresentation` d'un `ZWindowSizeClass` (+ `ZFormWeight`), **injectable/surchargeable** (jamais une constante figée), **testable sans `BuildContext`**.
>
> **HORS EX-UI.5 (→ EX-UI.6, même package, story suivante — NE PAS CRÉER ICI)** :
> - le **port `ZFormPresenter`** ;
> - le présentateur par défaut pur-Flutter **`ZAdaptivePresenter`** (`Navigator.push` / `showModalBottomSheet` / `showDialog`) ;
> - le **câblage du seam `ZcrudScope`** de résolution du présentateur effectif.
>
> **HORS EX-UI (→ EX-UI.11 / bindings, plus tard)** : présentateurs manager GetX (`zcrud_get`) / go_router (`zcrud_riverpod`).
>
> ⚠️ **L'épic EX-UI.5 (epics.md l.242, `binds AD-30/AD-6`) mentionne `port ZFormPresenter` dans le `domain/` du package** ; **cette story tranche que le port relève d'EX-UI.6** (cf. `Capability → Story Map` l.66-67 : EX-UI.5 = `ZEditionPresentation + ZPresentationPolicy`, EX-UI.6 = `port ZFormPresenter + ZAdaptivePresenter`) — conforme au commentaire sprint-status `ex-ui-5 … ZEditionPresentation + ZPresentationPolicy` / `ex-ui-6 … port ZFormPresenter`. **EX-UI.5 ne livre QUE la politique + les enums.** Le dossier `lib/src/presentation/` est **créé vide** (peuplé par EX-UI.6) ; **aucun** placeholder inutile.

---

## Story

**As a** développeur intégrateur préparant l'infrastructure de navigation UI transverse,
**I want** créer le package `zcrud_navigation` **dépendant de `zcrud_core` + `zcrud_responsive`** et y poser **le maillon de politique manquant** — un enum de mode d'édition (`ZEditionPresentation { page, sheet, dialog }`), un enum de poids de formulaire (`ZFormWeight { light, heavy }`) et une **politique PURE injectable** (`ZPresentationPolicy`) qui **dérive** le mode d'un `ZWindowSizeClass` (fourni par `zcrud_responsive`, EX-UI.1) — dérivable **sans `BuildContext`**,
**so that** le mode d'édition soit **calculé automatiquement à partir du breakpoint** (le câblage qu'**aucune** app ne fait — chacune fige `dialog: isWebOrDesktop` au call-site), au lieu d'être codé en dur, et que ce mode soit **surchargeable par app** sans modifier le package (AD-30/AD-6), en préparant EX-UI.6 (port `ZFormPresenter` + `ZAdaptivePresenter`) qui consommera cette politique.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ce qu'`EX-UI.1` (`done`) FOURNIT DÉJÀ et que cette story CONSOMME

`packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` (exporté par le barrel `packages/zcrud_responsive/lib/zcrud_responsive.dart`) déclare **publiquement** :

| Symbole `zcrud_responsive` (EX-UI.1) | Nature | Détail (lu sur disque) |
|---|---|---|
| **`ZWindowSizeClass`** | **enum** `{ compact, medium, expanded }` | seuils M3 600/840. **← ENTRÉE de `ZPresentationPolicy.resolve`** |
| `ZWindowSizeClass.fromWidth(double)` | méthode statique **pure** | résolution `width → classe`, défaut sûr `compact`, jamais de throw |
| `ZWindowSizeClass.of(BuildContext)` | méthode statique | helper `MediaQuery.sizeOf` — **NON utilisé en EX-UI.5** (la politique est pure, sans `BuildContext`) ; il servira au présentateur EX-UI.6 |

⛔ **`ZWindowSizeClass` n'est PAS redéclaré** dans `zcrud_navigation` : `import 'package:zcrud_responsive/zcrud_responsive.dart';` et **consommer** l'enum tel quel.

### Le « maillon manquant » (source AD-30) — pourquoi cette story existe

Aucune des 4 apps ne **dérive** le mode de présentation du breakpoint : chacune le fige au call-site (`showPushedDialog(dialog: isWebOrDesktop)` — dodlp `forms_utils.dart` ~331-394, iffd `forms_utils.dart:631-739`), lex_douane n'a **pas** de présentation adaptative. EX-UI.5 pose la **politique** (`breakpoint → mode`) qui n'existe nulle part. Les call-sites des apps utilisent **2 bools** (`fullscreenDialog`/`dialog`) — **remplacés** par l'`enum ZEditionPresentation` (NFR-U7 « enums > booléens », AD-30).

### Best-of-breed apps (LECTURE SEULE — à neutraliser/concevoir, PAS copier)

- **dodlp** `lib/modules/data_crud/utils/forms_utils.dart` (~331-394) & **iffd** `forms_utils.dart:631-739` — *cœur* de `showPushedDialog` : montrent les **tailles/branches** (fullscreen vs dialog) et le critère `isWebOrDesktop`. **À NEUTRALISER** : le critère `isWebOrDesktop` (couplage largeur globale) devient une **dérivation du `ZWindowSizeClass`** ; les 2 bools deviennent l'`enum ZEditionPresentation`. **Aucune** logique de présentation (`Navigator`/`showDialog`) ici — c'est EX-UI.6.

### Point de déclaration du package dans le workspace (vérifié)

- **`pubspec.yaml` racine → bloc `workspace:`** = **SEUL** point de déclaration (commentaire du fichier : *« CE BLOC `workspace:` est le SEUL point de déclaration d'un nouveau package produit »*). ⇒ **ajouter `- packages/zcrud_navigation`**.
- **`melos.yaml`** = glob `packages/**` (n'énumère aucun package) → **rien à y ajouter** ; ⛔ **ne PAS toucher son bloc `scripts:`** (le gate `gate:melos` compare `pubspec.yaml`↔`melos.yaml`).
- **`melos list`** passe de **N** à **N+1**. Le dev **mesure N sur disque** avant/après (`melos list`, ou compte des `- packages/` du root pubspec = **21 actuellement**) et consigne le chiffre exact — ⛔ **ne PAS coder en dur** dans le code.

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — `zcrud_navigation` DÉPEND de `zcrud_core:^0.2.0` + `zcrud_responsive:^0.2.0`

`pubspec.yaml` déclare `dependencies: { flutter: {sdk: flutter}, zcrud_core: ^0.2.0, zcrud_responsive: ^0.2.0 }`. Versions **`0.2.0`** confirmées sur disque (`packages/zcrud_core/pubspec.yaml:10`, `packages/zcrud_responsive/pubspec.yaml:18`). ⛔ **AUCUN gestionnaire d'état** (`get`/`flutter_riverpod`/`provider`), ⛔ **AUCUN routeur** (`go_router`), ⛔ **aucun tiers responsive**, ⛔ **aucun `dartz`** (inutile ici — la politique ne retourne pas d'`Either`). Les arêtes `zcrud_navigation → zcrud_core` et `zcrud_navigation → zcrud_responsive` sont **SORTANTES** ⇒ **`CORE OUT=0` reste intact** (le cœur ne gagne aucune arête sortante) ; `graph_proof.py` doit rester **ACYCLIQUE** (`zcrud_navigation → zcrud_responsive → zcrud_core` + `zcrud_navigation → zcrud_core` : DAG, aucun cycle).

> **Note dépendance transitive :** `zcrud_responsive` ré-exporte `ZBreakpoint`/`ZResponsiveBreakpoints`/`ZResponsiveSpan` de `zcrud_core`, mais **`flutter` reste requis** dans le `pubspec` (l'import `package:flutter/...` de `zcrud_responsive` ne rend pas `flutter` transitif pour la déclaration ; le déclarer explicitement est correct et attendu du gabarit). La politique elle-même **n'importe pas `flutter`** (domaine pur-Dart) ; `flutter` reste dans le `pubspec` pour `flutter_test` et pour EX-UI.6.

### D2 — `ZEditionPresentation` : enum 3 modes, remplace les 2 bools des apps (NFR-U7)

`enum ZEditionPresentation { page, sheet, dialog }` (valeurs **camelCase**, `lib/src/domain/z_edition_presentation.dart`). **Unique** type de mode exposé — **aucun** `bool` `fullscreenDialog`/`dialog`/`isWebOrDesktop` dans l'API publique. **Non persisté** a priori (choix runtime UI) ⇒ **pas de `@JsonKey`** ; le dartdoc **documente** que si l'enum devenait un jour sérialisé (ex. préférence utilisateur), il devrait alors porter `@JsonKey(unknownEnumValue:)` (AD-10) — hors périmètre.

### D3 — `ZFormWeight` : enum de poids, PAS un `bool` (NFR-U7)

Le critère « poids du formulaire » qui départage `expanded → dialog|page` (AD-30) est modélisé par `enum ZFormWeight { light, heavy }` (`lib/src/domain/z_form_weight.dart`), **jamais** un `bool isHeavy`/`isLong`. `light` = formulaire court (peu de champs) ; `heavy` = formulaire long/riche méritant une page pleine sur grand écran. **Défaut = `ZFormWeight.light`** (le cas courant → `dialog` sur `expanded`).

### D4 — `ZPresentationPolicy` : classe PURE injectable, jamais `sealed`, jamais figée (AD-30/AD-6/AD-4)

- **API** : `ZEditionPresentation resolve(ZWindowSizeClass sizeClass, {ZFormWeight formWeight = ZFormWeight.light})`.
- **Injectable/surchargeable (AD-6)** : `ZPresentationPolicy` **N'EST PAS** une constante ni une fonction top-level figée. Forme retenue — **classe non-`sealed`** (AD-4) avec :
  - un **constructeur `const` par défaut** portant le mapping Material 3 (`ZPresentationPolicy()` ou `const ZPresentationPolicy.material()`),
  - une **fabrique déléguant à une fonction** pour l'injection légère : `ZPresentationPolicy.from(ZEditionPresentation Function(ZWindowSizeClass, {ZFormWeight formWeight}) resolver)` — permet à une app de fournir sa règle **sans** sous-classer,
  - `resolve()` **non-`final` overridable** (une app peut aussi **sous-classer** — le port n'est **jamais `sealed`**, AD-4/NFR-U9).
  > Le dev peut retenir une variante équivalente (typedef `ZPresentationResolver` + classe wrapper) **à condition** de préserver : (1) pureté sans `BuildContext`, (2) injection sans modifier le package, (3) non-`sealed`, (4) défaut fourni **et** surchargeable. Documenter le choix.
- **Défaut documenté (mapping Material 3)** :

  | `ZWindowSizeClass` | `ZFormWeight` | → `ZEditionPresentation` |
  |---|---|---|
  | `compact` | (indifférent) | `sheet` |
  | `medium` | (indifférent) | `dialog` |
  | `expanded` | `light` | `dialog` |
  | `expanded` | `heavy` | `page` |

  Justification : petit écran → **bottom-sheet** (ergonomie tactile) ; écran moyen → **dialog** modal centré ; grand écran → **dialog** pour un formulaire léger, **page** pleine (`fullscreenDialog`) pour un formulaire lourd. C'est **exactement** le maillon AD-30 (`compact → sheet`, `medium → dialog`, `expanded → dialog|page selon poids`).

### D5 — Défaut sûr, exhaustif, jamais de `throw` (AD-10)

`resolve()` est un **switch exhaustif** sur les enums (`ZWindowSizeClass` × `ZFormWeight`) : le compilateur garantit l'exhaustivité, **aucune branche `default` throw**, **déterministe**. Aucune entrée « aberrante » n'est possible (les enums bornent le domaine) ⇒ le défaut sûr est **structurel**. **Aucun `throw`** dans le package.

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZEditionPresentation`, `ZFormWeight`, `ZPresentationPolicy` sont **domaine pur**, **non persistés**, **aucun `@ZcrudModel`/`@JsonSerializable`/`@JsonKey`**. ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concerné**, anti-`reflectable` sans objet. **Confirmer** le no-op au 1er `melos run generate` (AC6).

### D7 — Aucun `BuildContext`, aucun `flutter/widgets` dans la politique (AD-5/AD-14)

`z_presentation_policy.dart`, `z_edition_presentation.dart`, `z_form_weight.dart` sont **pur-Dart** : **aucun** `import 'package:flutter/...'`, **aucun** `BuildContext`. La liaison `context → largeur → ZWindowSizeClass` se fait en amont (via `ZWindowSizeClass.of(context)` d'EX-UI.1) **par l'appelant** (le présentateur EX-UI.6), **jamais** par la politique.

---

## Acceptance Criteria

### AC1 — Scaffolding du package `zcrud_navigation` (dépend de `zcrud_core` + `zcrud_responsive`)
**Given** l'absence du package,
**When** on crée `packages/zcrud_navigation/`,
**Then** il contient :
- `pubspec.yaml` : `name: zcrud_navigation`, `version: 0.2.0`, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2` (aligné sur `zcrud_core`/`zcrud_responsive`), `dependencies` = **`flutter: {sdk: flutter}` + `zcrud_core: ^0.2.0` + `zcrud_responsive: ^0.2.0`** (⛔ **aucun autre `zcrud_*`**, ⛔ **aucun gestionnaire d'état** `get`/`flutter_riverpod`/`provider`, ⛔ **aucun routeur** `go_router`, ⛔ **aucun** `dartz`, ⛔ **aucun tiers responsive**), `dev_dependencies` = `flutter_test: {sdk: flutter}`, plus `description`/`homepage`/`repository`/`issue_tracker`/`topics` sur le patron de `packages/zcrud_responsive/pubspec.yaml` ;
- `analysis_options.yaml` : `include: ../../analysis_options.yaml` (baseline de lint partagée) ;
- barrel `lib/zcrud_navigation.dart` (dartdoc d'API + exports des fichiers domaine neufs) ;
- arbo `lib/src/domain/` (les fichiers neufs). `lib/src/presentation/` est **créée vide** (peuplée par EX-UI.6) — ⛔ **pas** de `.gitkeep` ni placeholder (retiré comme en EX-UI.2) ; si l'arbo vide n'est pas suivie par git, la créer sera fait par EX-UI.6 — **ne pas bloquer** dessus ;
- `README.md` minimal (rôle, dépendances `zcrud_core` + `zcrud_responsive`, 1 exemple d'usage de la politique, mention monorepo, patron `packages/zcrud_responsive/README.md`).
**And** `- packages/zcrud_navigation` est ajouté au bloc **`workspace:` du `pubspec.yaml` racine** (à sa place logique, après les packages EX-UI existants ; ne pas réordonner le reste) ; **`melos.yaml` inchangé** (glob `packages/**`).

### AC2 — `ZEditionPresentation` (enum 3 modes) — remplace les 2 bools des apps (D2)
**Given** le besoin de modéliser le mode d'édition,
**When** on définit `enum ZEditionPresentation { page, sheet, dialog }` (`lib/src/domain/z_edition_presentation.dart`, valeurs **camelCase**),
**Then** c'est l'**unique** type de mode exposé — **aucun** `bool` multi-état (`fullscreenDialog`/`dialog`/`isWebOrDesktop`) dans l'API publique (NFR-U7),
**And** l'enum est **domaine pur** (aucun `import flutter`), **non sérialisé** (D6) ⇒ **pas de `@JsonKey`** ; le dartdoc documente le fallback `@JsonKey(unknownEnumValue:)` **si** une sérialisation future était requise (AD-10, hors périmètre).

### AC3 — `ZFormWeight` (enum de poids) — jamais un `bool` (D3, NFR-U7)
**Given** le critère de poids de formulaire qui départage `expanded → dialog|page`,
**When** on définit `enum ZFormWeight { light, heavy }` (`lib/src/domain/z_form_weight.dart`, camelCase),
**Then** il est un **enum** (jamais un `bool isHeavy`/`isLong`), **domaine pur**, avec un dartdoc explicitant `light` (formulaire court → dialog) vs `heavy` (formulaire long → page sur grand écran) et le **défaut `light`**.

### AC4 — `ZPresentationPolicy.resolve()` : PURE, sans `BuildContext`, mapping M3 documenté, jamais de throw (D4/D5/D7)
**Given** un `ZWindowSizeClass` (de `zcrud_responsive`) + un `ZFormWeight`,
**When** on appelle `ZEditionPresentation resolve(ZWindowSizeClass sizeClass, {ZFormWeight formWeight = ZFormWeight.light})` de la politique **par défaut**,
**Then** elle retourne, de façon **déterministe** et via **switch exhaustif** (jamais de throw, AD-10/D5) :
- `compact` → `sheet` (quel que soit `formWeight`),
- `medium` → `dialog` (quel que soit `formWeight`),
- `expanded` + `light` → `dialog`,
- `expanded` + `heavy` → `page`,
**And** `resolve()` est **PURE**, **testable sans `BuildContext`** (NFR-U6/AD-5/AD-14) — aucun `import 'package:flutter/...'` dans les fichiers de politique/enum (D7),
**And** le mode n'est **jamais** dérivé d'un flag `isWebOrDesktop` en dur ni d'une largeur globale `Get.width` (AD-30/NFR-U2) — l'entrée est **toujours** un `ZWindowSizeClass`.

### AC5 — `ZPresentationPolicy` injectable/surchargeable, jamais `sealed`, défaut fourni (D4, AD-6/AD-4)
**Given** une app voulant une autre règle que le défaut M3,
**When** elle fournit sa politique,
**Then** `ZPresentationPolicy` est **injectable/surchargeable** — au minimum (1) une **fabrique fonction** `ZPresentationPolicy.from(resolver)` **et/ou** (2) la possibilité de **sous-classer** (`resolve` non-`final`) — **jamais** une constante figée ni une fonction top-level non substituable (AD-30/AD-6),
**And** le type est **pluggable, jamais `sealed`** (AD-4/NFR-U9) : une politique custom définie **hors** du package compile et se substitue au défaut,
**And** un **défaut** prêt à l'emploi existe (`ZPresentationPolicy()` / `const ZPresentationPolicy.material()`) portant le mapping M3 d'AC4.
> Le **câblage du seam `ZcrudScope`** (résolution du présentateur/politique effectif dans l'arbre de widgets) est **HORS périmètre** → EX-UI.6. Ici « injectable » = la politique est un **objet substituable passé en paramètre**, prouvé par un test d'injection d'une politique custom.

### AC6 — Graphe, gates verts repo-wide, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** le package `zcrud_navigation`,
**When** on inspecte le graphe et rejoue les gates,
**Then** `zcrud_navigation` a **exactement deux** arêtes `zcrud_*` **sortantes** (`→ zcrud_core`, `→ zcrud_responsive`) et **zéro** entrante ; `zcrud_core` **ne gagne aucune** arête sortante (`CORE OUT=0` intact) ; `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** (`zcrud_navigation → zcrud_responsive → zcrud_core` + `zcrud_navigation → zcrud_core` = DAG),
**And** `melos run generate` est un **no-op** pour ce package (aucun `@ZcrudModel` — NFR-U11 confirmée), gate `codegen-distribution` **non concerné** (aucun `part`/`*.g.dart`),
**And** `melos run analyze` **RC=0** et `melos run verify` **RC=0** **repo-wide** (délégués au gate de commit d'epic de l'orchestrateur ; le dev fournit au minimum `dart analyze packages/zcrud_navigation` RC=0),
**And** `melos list` = **N+1** (valeur N **mesurée sur disque** et consignée ; les 2 harnais `tool/` restent ignorés).

---

## Tasks / Subtasks

- [ ] **T1 — Scaffolding du package** (AC1, AC6) — `packages/zcrud_navigation/`
  - [ ] T1.1 `pubspec.yaml` : `flutter` + **`zcrud_core: ^0.2.0`** + **`zcrud_responsive: ^0.2.0`** (+ `flutter_test` dev) ; `version: 0.2.0` ; `publish_to: none` ; `resolution: workspace` ; `sdk: ^3.12.2` ; `description`/`homepage`/`repository`/`issue_tracker`/`topics` calqués sur `zcrud_responsive`.
  - [ ] T1.2 `analysis_options.yaml` (`include: ../../analysis_options.yaml`).
  - [ ] T1.3 Arbo `lib/src/domain/` (+ `lib/src/presentation/` vide, non exportée en EX-UI.5 ; sans placeholder).
  - [ ] T1.4 Ajouter `- packages/zcrud_navigation` au bloc **`workspace:` du `pubspec.yaml` racine**. ⛔ **Ne PAS toucher `melos.yaml`.**
  - [ ] T1.5 `README.md` minimal (dépendances `zcrud_core` + `zcrud_responsive`, exemple `ZPresentationPolicy().resolve(ZWindowSizeClass.compact) == ZEditionPresentation.sheet`).
  - [ ] T1.6 `dart pub get` racine (bootstrap workspace) → résolution OK.

- [ ] **T2 — Domaine pur : enums de présentation** (AC2, AC3)
  - [ ] T2.1 `z_edition_presentation.dart` : `enum ZEditionPresentation { page, sheet, dialog }` + dartdoc (« enums > bools », remplace `fullscreenDialog`/`dialog`/`isWebOrDesktop` des apps, fallback `@JsonKey` si sérialisé un jour). **Aucun** `import flutter`.
  - [ ] T2.2 `z_form_weight.dart` : `enum ZFormWeight { light, heavy }` + dartdoc (light→dialog, heavy→page sur grand écran ; défaut `light`). **Aucun** `import flutter`.

- [ ] **T3 — Domaine pur : `ZPresentationPolicy`** (AC4, AC5)
  - [ ] T3.1 `z_presentation_policy.dart` : `import 'package:zcrud_responsive/zcrud_responsive.dart'` (pour `ZWindowSizeClass`) ; `ZPresentationPolicy` **classe non-`sealed`** avec constructeur défaut `const` (mapping M3), fabrique `ZPresentationPolicy.from(resolver)`, `resolve(ZWindowSizeClass, {ZFormWeight formWeight = ZFormWeight.light})` **overridable**, **switch exhaustif** (jamais de throw). **Aucun** `import 'package:flutter/...'`. Dartdoc du mapping M3 (tableau D4) + justification AD-30.

- [ ] **T4 — Barrel + documentation d'API** (AC1)
  - [ ] T4.1 `lib/zcrud_navigation.dart` : dartdoc de barrel (rôle « politique de présentation dérivée du breakpoint — le maillon manquant AD-30 », **dépend de `zcrud_core` + `zcrud_responsive`**, port `ZFormPresenter`/présentateur = **EX-UI.6**) + exports des 3 fichiers domaine (`z_edition_presentation.dart`, `z_form_weight.dart`, `z_presentation_policy.dart`).

- [ ] **T5 — Tests** (AC4, AC5)
  - [ ] T5.1 `test/z_presentation_policy_test.dart` (**pur-Dart, sans `BuildContext`**) : **table de vérité** de la politique par défaut — `compact` (light ET heavy) → `sheet` ; `medium` (light ET heavy) → `dialog` ; `expanded`+`light` → `dialog` ; `expanded`+`heavy` → `page`. **Déterminisme** : deux appels identiques → même résultat. Défaut `formWeight` omis → `light` (donc `expanded` → `dialog`).
  - [ ] T5.2 `test/z_presentation_policy_injection_test.dart` (pur) : une **politique custom** (via `ZPresentationPolicy.from(...)` **et/ou** sous-classe) qui inverse/modifie le mapping (ex. `compact → dialog`) est **respectée** par `resolve()` — prouve la substituabilité (AD-6) et le non-`sealed` (AD-4).
  - [ ] T5.3 (optionnel) `test/z_edition_presentation_test.dart` : `ZEditionPresentation.values` = `{page, sheet, dialog}` ; `ZFormWeight.values` = `{light, heavy}` (garde-fou contre un ajout non intentionnel).

- [ ] **T6 — Vérif verte + graphe** (AC6)
  - [ ] T6.1 `melos run generate` (no-op pour le package : aucun `build_runner`, 0 `.g.dart`) → SUCCESS.
  - [ ] T6.2 `dart analyze packages/zcrud_navigation` RC=0 (0 issue). `melos run analyze`/`verify` **repo-wide** → délégués à l'orchestrateur (gate de commit d'epic).
  - [ ] T6.3 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE / CORE OUT=0** (arêtes `zcrud_navigation→zcrud_core` et `zcrud_navigation→zcrud_responsive` sortantes).
  - [ ] T6.4 `flutter test packages/zcrud_navigation` → tous verts (nb consigné).
  - [ ] T6.5 `melos list` = **N+1** (N mesuré avant, consigné).

---

## Dev Notes

### Fichiers à créer (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_navigation/pubspec.yaml` | NEW — `flutter` + `zcrud_core: ^0.2.0` + `zcrud_responsive: ^0.2.0` |
| `packages/zcrud_navigation/analysis_options.yaml` | NEW — `include: ../../analysis_options.yaml` |
| `packages/zcrud_navigation/README.md` | NEW — minimal |
| `packages/zcrud_navigation/lib/zcrud_navigation.dart` | NEW — barrel |
| `packages/zcrud_navigation/lib/src/domain/z_edition_presentation.dart` | NEW — pur-Dart |
| `packages/zcrud_navigation/lib/src/domain/z_form_weight.dart` | NEW — pur-Dart |
| `packages/zcrud_navigation/lib/src/domain/z_presentation_policy.dart` | NEW — pur-Dart, importe `zcrud_responsive` |
| `packages/zcrud_navigation/test/z_presentation_policy_test.dart` | NEW — table de vérité |
| `packages/zcrud_navigation/test/z_presentation_policy_injection_test.dart` | NEW — substituabilité |
| `packages/zcrud_navigation/test/z_edition_presentation_test.dart` | NEW (optionnel) — garde-fou enums |
| `pubspec.yaml` (racine) | **UPDATE** — 1 ligne dans le bloc `workspace:` |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**`, `packages/zcrud_responsive/**` (consommés, jamais réécrits ni redéclarés), `melos.yaml` (glob `packages/**` ; `gate:melos` compare son `scripts:` à `pubspec.yaml`). ⛔ **NE PAS CRÉER** ici `ZFormPresenter`/`ZAdaptivePresenter` (= EX-UI.6).

### Invariants AD applicables (rappel ciblé)

- **AD-30 (delta)** : politique de présentation **dérivée** du `ZWindowSizeClass` (breakpoint), `enum ZEditionPresentation`, `ZPresentationPolicy` **injectable** (jamais figée). Le port/présentateur = EX-UI.6.
- **AD-1 / NFR-U1** : `zcrud_navigation` a **2 arêtes sortantes** (`→ zcrud_core`, `→ zcrud_responsive`), **0 entrante** ; `CORE OUT=0` intact (arêtes **entrantes** au cœur/vers responsive). `graph_proof.py` ne compte que les `zcrud_*` ; `flutter` n'ajoute rien. **Acyclicité** préservée.
- **AD-6** : politique **résolvable/substituable par seam** — ici via objet injecté (`.from` / sous-classe) ; câblage `ZcrudScope` = EX-UI.6.
- **AD-4 / NFR-U9** : `ZPresentationPolicy` **jamais `sealed`** — extensible hors package (prouvé par test d'injection).
- **AD-2 / AD-15 / NFR-U2** : **aucun** gestionnaire d'état/routeur importé (`get`/`flutter_riverpod`/`provider`/`go_router`).
- **AD-5 / AD-14 / NFR-U6** : `resolve()` **pure**, testable **sans `BuildContext`** ; aucun `import flutter` dans la politique/les enums.
- **AD-10 / NFR-U10** : switch exhaustif, **jamais de throw**, défaut structurel (enums bornent le domaine).
- **AD-12 / NFR-U8** : zéro secret (`gate:secrets` reste vert).
- **NFR-U7 (enums > booléens)** : `ZEditionPresentation` **remplace** `fullscreenDialog`/`dialog`/`isWebOrDesktop` ; `ZFormWeight` **remplace** un `bool isHeavy`.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- Le package suit `lib/<pkg>.dart` (barrel) + `lib/src/{domain,presentation}` comme tous les packages du monorepo. En EX-UI.5, **seul `domain/`** est peuplé ; `presentation/` attend EX-UI.6.
- Le seul ajout de déclaration hors package est **1 ligne** dans le bloc `workspace:` du `pubspec.yaml` racine (`melos.yaml` = glob).

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.5 débloque **EX-UI.6** (`ZFormPresenter` + `ZAdaptivePresenter` pur-Flutter — **même package** `zcrud_navigation`, dossier `presentation/`), qui **consomme** `ZPresentationPolicy` (résout le mode) et `ZEditionPresentation` (exécute le mode via `Navigator.push`/`showModalBottomSheet`/`showDialog`). EX-UI.6 précède ensuite EX-UI.11 (binding GetX).

### References

- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § **AD-30** (l.94-97, politique dérivée du breakpoint, enum + policy injectable, présentateur = seam) ; § Consistency Conventions « Présentation » (l.117), « Enums > booléens » (l.118), « Pureté & seams » (l.119) ; § Structural Seed (l.146-149, `zcrud_navigation → zcrud_core + zcrud_responsive`, domain = `ZEditionPresentation`/`ZPresentationPolicy`) ; § Câblage mermaid (l.161-168, `ZWindowSizeClass → ZPresentationPolicy.resolve → ZEditionPresentation`)]
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.5 (l.236-266) — ACs, périmètre `zcrud_navigation/domain`, sources `showPushedDialog` ; § Capability→Story Map (l.66-67, EX-UI.5=policy / EX-UI.6=port) ; § Séquencement (l.99, EX-UI.5 précède EX-UI.6)]
- [Source: `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` (enum `ZWindowSizeClass { compact, medium, expanded }`, `fromWidth`/`of` — **ENTRÉE** de la politique) ; `packages/zcrud_responsive/lib/zcrud_responsive.dart` (barrel exportant `ZWindowSizeClass`)]
- [Source: `packages/zcrud_responsive/pubspec.yaml` (**GABARIT** du nouveau pubspec : `version: 0.2.0`, `publish_to: none`, `resolution: workspace`, `sdk: ^3.12.2`, homepage/topics) ; `packages/zcrud_core/pubspec.yaml:10` (`version: 0.2.0`)]
- [Source: `pubspec.yaml` racine (bloc `workspace:` = **SEUL** point de déclaration ; **21** membres `- packages/` actuellement — N à mesurer) ; `melos.yaml` (glob `packages/**`, miroir `scripts:` — `gate:melos`)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-4/AD-13), naming préfixe `Z`, enums camelCase, gates CI]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Domaine pur** (sans `BuildContext`) | `resolve()` table de vérité : compact→sheet, medium→dialog, expanded+light→dialog, expanded+heavy→page ; défaut `formWeight`=light ; déterminisme | AC4, D4/D5 |
| **Domaine pur** | Injection d'une politique custom (`.from`/sous-classe) respectée par `resolve()` | AC5, AD-6/AD-4 |
| **Domaine pur** (optionnel) | `ZEditionPresentation.values` / `ZFormWeight.values` figés | AC2, AC3 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (2 arêtes sortantes) ; `analyze` RC=0 ; `generate` no-op ; `melos list` = N+1 | AC6, NFR-U1/U11 |

**Definition of Done** : AC1→AC6 verts · `pubspec.yaml` = `flutter` + `zcrud_core: ^0.2.0` + `zcrud_responsive: ^0.2.0` **uniquement** (aucun autre `zcrud_*`, aucun gestionnaire d'état/routeur/`dartz`) · **aucun** `ZFormPresenter`/`ZAdaptivePresenter` créé (réservés EX-UI.6) · **aucun** `import 'package:flutter/...'` dans la politique/les enums (pureté D7) · `ZPresentationPolicy` **non-`sealed`** et **injectable** (test d'injection vert) · `resolve()` **jamais de throw** (switch exhaustif) · `melos run generate` (no-op) + `dart analyze` RC=0 (repo-wide délégué à l'orchestrateur) · `graph_proof` ACYCLIQUE/CORE OUT=0 · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- `dart pub get` (workspace + example) → RC=0.
- `melos run generate` → SUCCESS ; `zcrud_navigation` absent de la liste des packages générés (aucun `build_runner` en dev-dep) ⇒ **no-op** confirmé (AC6/NFR-U11).
- `dart analyze packages/zcrud_navigation` → **No issues found!** (RC=0, zéro warning).
- `flutter test packages/zcrud_navigation` → **All tests passed!** — **14 tests** verts.
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK** ; arêtes `zcrud_navigation -> zcrud_core` + `zcrud_navigation -> zcrud_responsive` (2 sortantes, 0 entrante) ; 22 nœuds triés.
- `dart run melos list` → **22** (N=21 avant → N+1), `zcrud_navigation` présent 1×.

### Completion Notes List

- Package `zcrud_navigation` créé : `pubspec.yaml` (`flutter` + `zcrud_core:^0.2.0` + `zcrud_responsive:^0.2.0` uniquement ; aucun gestionnaire d'état/routeur/dartz), `analysis_options.yaml`, barrel, README, 3 fichiers domaine, 3 fichiers de test.
- `ZEditionPresentation { page, sheet, dialog }` + `ZFormWeight { light, heavy }` : enums pur-Dart, camelCase, non sérialisés (dartdoc du fallback `@JsonKey` documenté).
- `ZPresentationPolicy` : classe **non-`sealed`**, constructeur défaut `const`, alias `const .material()`, fabrique `.from(resolver)` (typedef `ZPresentationResolver`), `resolve()` **non-`final` overridable** via **switch expression exhaustif** (jamais de `throw`, AD-10/D5). Mapping M3 : compact→sheet, medium→dialog, expanded+light→dialog, expanded+heavy→page. Aucun `import 'package:flutter/...'` (les 3 occurrences de `package:flutter` sont dans les dartdocs).
- `zcrud_core`/`zcrud_responsive`/`melos.yaml` **non modifiés** ; seul ajout hors package = 1 ligne au bloc `workspace:` du `pubspec.yaml` racine.
- `lib/src/presentation/` non créé (dir vide non suivie par git ; peuplé par EX-UI.6) — sans placeholder, conforme AC1.

### File List

- `packages/zcrud_navigation/pubspec.yaml` (NEW)
- `packages/zcrud_navigation/analysis_options.yaml` (NEW)
- `packages/zcrud_navigation/README.md` (NEW)
- `packages/zcrud_navigation/lib/zcrud_navigation.dart` (NEW)
- `packages/zcrud_navigation/lib/src/domain/z_edition_presentation.dart` (NEW)
- `packages/zcrud_navigation/lib/src/domain/z_form_weight.dart` (NEW)
- `packages/zcrud_navigation/lib/src/domain/z_presentation_policy.dart` (NEW)
- `packages/zcrud_navigation/test/z_presentation_policy_test.dart` (NEW)
- `packages/zcrud_navigation/test/z_presentation_policy_injection_test.dart` (NEW)
- `packages/zcrud_navigation/test/z_edition_presentation_test.dart` (NEW)
- `pubspec.yaml` (racine, UPDATE — 1 ligne workspace)
