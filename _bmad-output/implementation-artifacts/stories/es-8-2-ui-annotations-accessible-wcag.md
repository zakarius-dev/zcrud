---
baseline_commit: e8e94b380a8081f0674f69f1b817b1508a4ea4ea
---

# Story ES-8.2 : UI d'annotations accessible (WCAG) — `ZAnnotationToolbar` / `ZAnnotationPanel` (`zcrud_document/presentation`)

Status: review

- **Clé sprint-status** : `es-8-2-ui-annotations-accessible-wcag`
- **Epic** : ES-8 (Tags & annotations — UI). ES-8.2 est la **branche `zcrud_document`** de l'epic (la branche `zcrud_study` = ES-8.1, tags UI).
- **Taille** : **M**
- **Parallélisation** : ✅ **PARALLÉLISABLE avec ES-8.1** — packages **DISJOINTS** (`zcrud_document/presentation` vs `zcrud_study/presentation`).
  **Packages écrits** : `packages/zcrud_document/` **UNIQUEMENT** (nouveau dossier `lib/src/presentation/`, `pubspec.yaml`, barrel, `test/`).
  ⛔ **N'écrit NI `zcrud_study` NI `zcrud_core` NI `zcrud_study_kernel` NI `zcrud_annotations`.** Le seul point de contact possible entre stories en vol = `zcrud_core` (garde-fou n°2 CLAUDE.md), qu'**aucune** des deux n'écrit ici.
- **Couvre** : **FR-S28** (UI annotations accessible WCAG) · **AD-13** (RTL/a11y : directionnel, ≥ 48 dp, `Semantics`, **couleur JAMAIS seul canal** — CŒUR de la story) · **AD-2/AD-15** (réactivité Flutter-native, controller isolé, **aucun** gestionnaire d'état, `ZcrudScope`) · **AD-1** (graphe acyclique, CORE OUT=0) · **AD-4** (extensibilité, `String` opaque, callback `null` = action absente) · **AD-10** (décodage/rendu défensif) · **FR-26** (thème + libellés + couleurs **injectés**, jamais codés en dur) · **NFR-S6** (a11y & RTL, `ListView.builder`, couleur jamais seul canal) · **NFR-S10** (domaine `zcrud_document` reste importable/pur-Dart).
- **Dépend de** : **ES-2.5** (`done` — `ZDocumentAnnotation`, `ZAnnotationBounds`, `ZDocumentAnnotationKind` livrés) + **ES-1.2/ES-2.3** (`done` — `ZColorPalette`, `remapColorKey` livrés dans `zcrud_study_kernel`, déjà arête entrante de `zcrud_document`). Réutilise l'**existant livré** de `zcrud_core` (`ZcrudScope`, `ZColorKeyResolver`, `ZcrudLabels`).

> ✅ **Périmètre VÉRIFIÉ sur disque** : epics l. 906-922 (Story ES-8.2, ACs « couleur jamais seul canal » + « ≥ 48 dp, `Semantics`, directionnel ») ; sprint-status l. 397 (`[M][∥ — zcrud_document/presentation] ZAnnotationToolbar/Panel (WCAG)`) ; fichiers cibles epics l. 912 : `packages/zcrud_document/lib/src/presentation/{z_annotation_toolbar.dart, z_annotation_panel.dart}`. **Aucune ligne de domaine/persistance n'est écrite ici** — la persistance des annotations relève d'ES-3.x (store).

---

## ⚠️ LE FAIT STRUCTURANT #1 : les modèles d'annotation sont DÉJÀ livrés — cette story ne modélise RIEN

Mesuré sur disque (`packages/zcrud_document/lib/src/domain/`), livrés et testés en **ES-2.5** :

| Modèle | Surface consommée par l'UI (ES-8.2) |
|---|---|
| `ZDocumentAnnotation` (`z_document_annotation.dart`) | `id?`, `docId`, `page` (1-based), `kind` (`ZDocumentAnnotationKind`), `colorKey` (**`String` BRUTE**, jamais clampée — la borne est **palette-dépendante, résolue À L'AFFICHAGE**, cf. dartdoc l. 48-51/169-173), `bounds` (`ZAnnotationBounds`), `rects?`, `text?`, `createdAt?`, `extension?`, `extra`. |
| `ZAnnotationBounds` (`z_annotation_bounds.dart`) | `x/y/width/height` fractions **`[0,1]`** (clampées `sanitizeCoord`). **`dart:ui`/`Rect` REJETÉS (D3)** : la conversion fraction↔pixels a besoin de la **taille de page mesurée par le viewer** ⇒ c'est un **seam de présentation** — ES-8.2 n'ancre PAS d'annotations sur une page réelle (pas de viewer PDF ici), elle **édite/liste** kind + couleur + texte. |
| `ZDocumentAnnotationKind` (`z_document_annotation_kind.dart`) | enum `{ highlight, stickyNote }` — repli défensif `highlight` (1ʳᵉ constante). |

⇒ **ES-8.2 = pure PRÉSENTATION** : une **toolbar** (choix du `kind` + palette de `colorKey`) et un **panel** (liste des annotations existantes) accessibles, bâtis **au-dessus** de ces modèles. **Aucun `@ZcrudModel`, aucun `.g.dart`, aucun codegen** n'est touché (⇒ `melos run generate` reste un no-op pour ce package).

## ⚠️ LE FAIT STRUCTURANT #2 : `zcrud_document` est PUR-DART → BASCULE FLUTTER (précédent EXACT ES-6.1)

Mesuré (`packages/zcrud_document/pubspec.yaml`) : `zcrud_document` ne déclare **AUCUN** `sdk: flutter`, ses tests tournent sous **`dart test`**, il n'importe que la **surface pur-Dart** de `zcrud_core` (`domain.dart`/`edition.dart`). Une UI a besoin de widgets Flutter et de `ZcrudScope` (presentation de `zcrud_core`) ⇒ **`zcrud_document` doit basculer en package Flutter** — **exactement** comme `zcrud_note` en ES-6.1 (D2/D4).

**Conséquences ASSUMÉES et ANNONCÉES (à consigner) :**
- Le package devient **FLUTTER** → ses tests de **présentation** tournent sous **`flutter test`** (R14) ; les tests de **domaine** existants (`z_document_annotation_test.dart`, `z_annotation_bounds_test.dart`, …) **restent verts** sous `flutter test` (un package Flutter exécute aussi les suites pur-Dart).
- 🔴 **`gate:web` (perte de couverture — DW-ES82-1, jumeau de DW-ES-6.1-1).** `scripts/ci/gate_web_determinism.dart` (l. 103-118) **EXCLUT** tout package portant `flutter: sdk: flutter` dans `dependencies:`. La bascule sort `zcrud_document` de `gate:web` : les matrices de **coercition JSON déterministe** du domaine (bornes `[0,1]` de `ZAnnotationBounds`, `sanitizePage`, `sanitizeExtra`) **cessent d'être rejouées sous `dart test -p node`**. **Aucune régression de test** (tout tourne sous VM), mais **perte d'un filet cross-runtime** → à **consigner** (`architecture.md § Deferred` + memlog, édition documentaire hors périmètre code — cf. Dn/D-DOC).
- 🔴 **AUCUNE NOUVELLE ARÊTE DE GRAPHE** (contraste avec ES-6.1 qui créait `zcrud_note → zcrud_markdown`). L'arête `zcrud_document → zcrud_core` **existe déjà** ; la story ne fait qu'utiliser sa **surface Flutter** (`package:zcrud_core/zcrud_core.dart` au lieu de `domain.dart`). L'arête `zcrud_document → zcrud_study_kernel` (pour `ZColorPalette`/`remapColorKey`) **existe déjà** aussi (déclarée d'emblée, pubspec l. « zcrud_study_kernel: arête DÉCLARÉE d'emblée »). ⇒ `graph_proof.py` : **0 nouvelle arête**, ACYCLIQUE conservé, CORE OUT=0 conservé, `melos list` inchangé (20 packages). *(Ajouter `flutter` en `dependencies` n'ajoute pas de nœud `zcrud_*`.)*

---

## ⚠️ LE FAIT STRUCTURANT #3 : la couleur vient d'un SEAM INJECTÉ, jamais d'un hex codé en dur

`colorKey` est une **`String` symbolique**. La résolution `colorKey → Color` est **déjà** un seam livré (mesuré) :
- `zcrud_study_kernel` : `ZColorPalette` (registre borné/ordonné de `colorKey`, `resolveKey`/`indexOf`) + `remapColorKey(palette, rawColorKey, seedTitle)` — **pur-Dart, ZÉRO `Color`** (l. 20-22 : *« PAS de `Color` … la résolution `colorKey → Color` est un seam de présentation de `zcrud_core` (`ZcrudScope.colorKeyResolver`) »*).
- `zcrud_core` : `ZcrudScope.colorKeyResolver` (`typedef ZColorKeyResolver = Color? Function(String key)`, `zcrud_scope.dart` l. 162) + `ZcrudScope.labels` (`ZcrudLabels`, l. 78) + `ZcrudScope.of(context)` (l. 168).

⇒ **La toolbar/panel résolvent chaque `colorKey` via `ZcrudScope.of(context).colorKeyResolver`**, avec **repli dérivé du `ColorScheme` courant** quand le resolver rend `null` (AD-10) — **jamais un hex codé en dur** (FR-26/AD-13/NFR-S7). Les **libellés** (kind, actions) viennent de `ZcrudScope.labels` (surchargeables), jamais de chaînes FR en dur (précédent `ZSrsQualityButtons` AC4). La **palette de `colorKey` proposée** est un **paramètre injecté** (défaut recommandé : `ZColorPalette.defaultStudy()`, clés neutres) — le widget ne connaît aucune couleur concrète.

---

## 🔴 LE CŒUR WCAG — « couleur JAMAIS seul canal » exige un pouvoir discriminant STRUCTUREL (leçons R12/R20/R24)

**Le motif dominant du repo** (`epic-es-6-retrospective.md` §4, `epic-es-7-retrospective.md` §4) : *« un artefact de vérification valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé »*. Pour une story WCAG c'est le **piège n°1** : un test qui vérifie seulement qu'un widget de swatch/bouton **existe** (ou qu'un **libellé** est présent) est **POWERLESS** — il ne prouve NI que la couleur n'est pas le seul canal, NI que la cible fait ≥ 48 dp, NI que le nœud `Semantics` réel porte l'info.

**Règles internalisées pour CETTE story (non-négociables sur les ACs a11y) :**
- **R24 — ancrer sur la LIGNE DE PROD, pas sur un artefact adjacent.** Toute garde de branche/état conditionnel (ex. « la swatch SÉLECTIONNÉE porte un marqueur non-coloré ») s'ancre sur une **clé structurelle** `ValueKey(...)` posée sur le widget que la branche produit, assertée par `find.byKey` **présence/absence** — **jamais** sur un libellé qui survit dans les deux branches. Prouver par **injection qui NEUTRALISE la branche** (retirer le marqueur) ⇒ RC=1.
- **R20 — un test d'ADAPTATEUR ancre sur l'objet PROPRE à l'adaptateur.** L'invariant AD-2 « controller créé UNE FOIS / jamais recréé / disposé » s'assère en **capturant l'identité du controller de la toolbar AVANT la tempête de rebuilds et en assérant `identical(...)` APRÈS** — jamais en se fiant à un `late final` qui *throw* (artefact de langage).
- **WCAG observable, pas décoratif.** Les ACs a11y **mesurent** : `tester.getSize(finder)` (≥ 48 dp), `tester.getSemantics(finder)` (`node.label`/`node.value`/`SemanticsProperties.button` NON vides et **distincts** entre options), et — pour le contraste — **lisent les `Color` réellement rendus** et **calculent le ratio de contraste WCAG** numériquement (helper de test `wcagContrastRatio`), assertant un seuil. Un test « la swatch est là » sans ces mesures est **REJETÉ en revue**.

---

## Contexte fichiers EXISTANTS lus (état AVANT — à préserver / réutiliser)

### `zcrud_document` (ÉTAT AVANT — package PUR-DART à FAIRE BASCULER)
- `lib/src/domain/z_document_annotation.dart`, `z_annotation_bounds.dart`, `z_document_annotation_kind.dart` — **domaine pur, INCHANGÉ** (aucune ligne modifiée par ES-8.2).
- `lib/zcrud_document.dart` (barrel) — exporte le domaine (avec `hide *Zcrud`) ; **à ÉTENDRE** des 2 widgets de présentation (`show`).
- `pubspec.yaml` — déclare `zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations`, dev-deps `zcrud_generator`/`build_runner`/`test` ; **pas de `sdk: flutter`**. **À MODIFIER** (bascule Flutter : `flutter: sdk` en `dependencies`, `flutter_test: sdk` en dev — le `test` reste pour les suites pur-Dart de domaine, comme `zcrud_note`).
- `test/` — suites de **domaine pur-Dart** (`z_document_annotation_test.dart`, `z_annotation_bounds_test.dart`, `ad_26_registry_test.dart`, …). **Restent vertes** sous `flutter test`. **Aucune garde de pureté `source_policy` n'existe encore** (grep : aucun `*polic*`/`*pure*`/`*source*` dans `test/`) ⇒ la story **AJOUTE** une garde de pureté (NFR-S10) — cf. AC12.

### `zcrud_study_kernel` (RÉUTILISÉ tel quel — NE PAS MODIFIER)
- `lib/src/domain/z_color_palette.dart` — `ZColorPalette({keys, fallbackKey, hash})`, `ZColorPalette.defaultStudy()` (8 clés neutres), `resolveKey`/`indexOf`. **Zéro `Color`.**
- `lib/src/domain/remap_color_key.dart` — `remapColorKey({palette, rawColorKey, seedTitle})` : clé **toujours ∈ `palette.keys`**, jamais throw (AD-10).

### `zcrud_core` (RÉUTILISÉ tel quel — NE PAS MODIFIER)
- `lib/src/presentation/zcrud_scope.dart` — `ZcrudScope` (`InheritedWidget`) : `colorKeyResolver` (`ZColorKeyResolver = Color? Function(String)`), `labels` (`ZcrudLabels`), `theme`, `ZcrudScope.of(context)`. **Le seam d'injection couleur/libellé/thème** (FR-26/AD-13).

### Référence de patron a11y (à imiter — `zcrud_session`)
- `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` — patron DISCRIMINANT déjà éprouvé : `tester.ensureSemantics()`, `tester.getSize(finder)` ≥ 48, `tester.getSemantics(finder).value/label`, `SemanticsProperties.button`, libellé **injecté** via `ZcrudScope.labels` (INJ-4), `Semantics.value` comme **canal non-coloré redondant** (« ok »/« lapse »). **Réutiliser ce patron.**

---

## 🔴 DÉCISIONS DE CONCEPTION (D1..D10)

- **D1 — Deux widgets de PRÉSENTATION, aucun modèle touché.** `ZAnnotationToolbar` (édition : sélection kind + palette colorKey) et `ZAnnotationPanel` (liste accessible des annotations existantes). Entrées/sorties **neutres** : `ZDocumentAnnotation`, `ZDocumentAnnotationKind`, `String colorKey`, callbacks. **Aucun** type Flutter/`Color` ne fuit dans le domaine ; **aucun** `dart:ui`/`Rect` (D3 d'ES-2.5 respecté — pas d'ancrage sur page pixel ici).

- **D2 — Bascule Flutter (AD-1), ZÉRO nouvelle arête.** `pubspec.yaml` : `flutter: {sdk: flutter}` en `dependencies`, `flutter_test: {sdk: flutter}` en dev (conserver `test` pour les suites domaine, patron `zcrud_note`). L'import passe de `package:zcrud_core/domain.dart` à `package:zcrud_core/zcrud_core.dart` (surface Flutter) **uniquement dans `lib/src/presentation/`**. Le domaine (`lib/src/domain/`) **n'importe toujours QUE** la surface pur-Dart. `graph_proof.py` : **0 nouvelle arête** (les arêtes `→ zcrud_core` et `→ zcrud_study_kernel` préexistent), ACYCLIQUE + CORE OUT=0 conservés, `melos list`=20.

- **D3 — Réactivité Flutter-native, controller ISOLÉ, AUCUN gestionnaire d'état (AD-2/AD-15, SM-1).** L'état mutable de la toolbar = `{ kind sélectionné, colorKey sélectionnée }`. Il vit dans un **`ZAnnotationToolController`** *(nom indicatif)* — un `ChangeNotifier`/`Listenable` **pur-Flutter** exposant **une `ValueListenable` par tranche** (`selectedKind`, `selectedColorKey`). Patron **owned/injected** (précédent ES-7.1) : créé en `initState` **ssi** non injecté, disposé **ssi** possédé, **jamais recréé** au rebuild. **Chaque tranche est scopée** par `ValueListenableBuilder`/`ListenableBuilder` ⇒ sélectionner une couleur **ne reconstruit PAS** la rangée des kinds, et inversement (SM-1). ⛔ **Interdits** : `setState` à l'échelle de la toolbar ; `ConsumerWidget`/`Get.find`/`Provider.of` ; import d'un gestionnaire d'état. Sélection **à sens unique** : un tap ⇒ mutation de la tranche + `onKindSelected`/`onColorSelected` (callback), **jamais** de ré-injection écrasant l'état pendant l'interaction.

- **D4 — Couleur = seam injecté, JAMAIS un hex (FR-26/AD-13).** La `Color` d'une swatch = `ZcrudScope.of(context).colorKeyResolver?.call(colorKey)` **avec repli sur le `ColorScheme` courant** si `null` (AD-10). La **palette de `colorKey`** proposée est un **paramètre** `ZColorPalette` (défaut `ZColorPalette.defaultStudy()`). ⛔ **Interdit** : tout littéral `Color(0x…)`/`Colors.*` concret dans `lib/` (scan AC13).

- **D5 — 🔴 CŒUR WCAG : couleur JAMAIS seul canal (NFR-S6/AD-13).** CHAQUE swatch et CHAQUE option de kind porte **au moins un canal NON-coloré redondant** :
  1. un **`Semantics` explicite** avec `label` **NON vide et DISTINCT** par option (la clé sémantique de couleur — ex. le `colorKey` résolu / son libellé injecté — et le nom du kind) ;
  2. la sélection est signalée par un **marqueur STRUCTUREL non-coloré** — une icône « coché » / une forme — porté par un `ValueKey(kAnnotationSelectedMarkerKey)` (R24), **jamais** par la seule couleur d'un anneau ;
  3. les kinds portent **icône + libellé texte** (jamais couleur seule).
  ⇒ deux options qui ne diffèrent QUE par la couleur restent **distinguables sans la voir** (Semantics label distinct + marqueur structurel). C'est l'invariant que les ACs D5-a/D5-b **mesurent** et que les injections **neutralisent**.

- **D6 — Contraste WCAG MESURÉ, pas décoratif (AD-13).** Le **marqueur de sélection / le foreground des libellés** dessiné **sur** une swatch colorée doit avoir un **ratio de contraste ≥ 3.0:1** (WCAG 2.1, composant non-textuel/UI) **contre la couleur résolue de la swatch** — la couleur du marqueur est **dérivée** (on-color contrastant du `ColorScheme`/luminance de la swatch), **jamais fixée** (`Colors.white` en dur). Le foreground d'un libellé texte sur fond de panel vise **≥ 4.5:1** (texte normal). L'AC D6 **lit les `Color` réellement rendus** et **calcule** le ratio (helper `wcagContrastRatio`). Injection : marqueur en `Colors.white` fixe contre une swatch claire ⇒ ratio < 3 ⇒ RC=1.

- **D7 — Cibles ≥ 48 dp + `Semantics` explicites + directionnel (AD-13).** Chaque cible interactive (bouton kind, swatch, entrée de panel) **mesure ≥ 48×48 dp** (`tester.getSize`) et expose un **nœud `Semantics` réel** (`button: true`, `label` non vide ; entrée de panel : `label`/`value` portant kind + page + extrait). Rendu **directionnel** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start|end` — **jamais** `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `Positioned(left/right)`, `TextAlign.left/right` (scan AC13 + test de rendu RTL AC10).

- **D8 — `ZAnnotationPanel` = `ListView.builder` (NFR-S6).** Liste **lazy** des `List<ZDocumentAnnotation>` injectées (jamais `ListView(children: [...])`). Chaque entrée : icône+libellé de kind, swatch (avec canal non-coloré redondant D5), extrait `text`/`page`, `onSelect(annotation)` (callback ; `null` = non tapable, AD-4). Ordre stable. `Key: ValueKey(annotation.id ?? index)` par entrée.

- **D9 — Défensif (AD-10).** Panel alimenté d'annotations à `text == null`/`colorKey == ''`/`kind` par défaut ⇒ **rendu propre, jamais de throw** (colorKey vide → repli resolver/`ColorScheme` ; text nul → extrait vide/placeholder ; `page` toujours ≥ 1 garanti par le domaine). `annotations == const []` ⇒ **empty-state** (jamais un `ListView` vide en erreur). `colorKeyResolver == null` (ZcrudScope permissif) ⇒ repli `ColorScheme`, jamais de throw.

- **D10 — Nouvelle garde de PURETÉ du domaine (NFR-S10, R13 « retarget/ajout, jamais suppression »).** Comme `zcrud_document` n'a **aucune** garde de pureté existante, la story **AJOUTE** `test/source_policy_test.dart` : `lib/src/domain/` **n'importe AUCUN** `package:flutter/*`/`dart:ui` ; la présentation (`lib/src/presentation/`) **est autorisée** à importer Flutter/`zcrud_core` (surface presentation). Consigne aussi la bascule (pubspec `sdk: flutter`) et la perte `gate:web` (DW-ES82-1). *(Structurel, à `@TestOn('vm')`.)*

---

## Acceptance Criteria (à POUVOIR DISCRIMINANT — R12 ; les ACs a11y assèrent des propriétés STRUCTURELLES OBSERVABLES — R20/R24)

**AC1 — `ZAnnotationToolbar` : sélection de `kind` (highlight / stickyNote) via boutons réutilisant les modèles.**
**Given** une toolbar montée sous `ZcrudScope` avec `onKindSelected`
**When** on tape le bouton d'un `kind` donné
**Then** l'arbre contient **exactement un** bouton par constante de `ZDocumentAnnotationKind.values` (via `ValueKey('${kAnnotationKindKeyPrefix}<name>')`), et taper le bouton `k` appelle **`onKindSelected(k)`** — pour **chaque** `k ∈ {highlight, stickyNote}`.
> **Discrimine** : rougit si un kind manque, si le mapping bouton→kind est inversé, ou si un kind est codé en dur au lieu d'itérer `values`.

**AC2 — `ZAnnotationToolbar` : palette de `colorKey` issue de la `ZColorPalette` injectée, sélection remontée BRUTE.**
**Given** une toolbar avec `palette: ZColorPalette.defaultStudy()` et `onColorSelected`
**When** on tape la swatch de `colorKey == 'warning'`
**Then** il y a **exactement une** swatch par `palette.keys` (via `ValueKey('${kAnnotationSwatchKeyPrefix}<colorKey>')`), et `onColorSelected('warning')` est appelé avec la **clé BRUTE `String`** (jamais un index, jamais un `Color`, jamais une clé remappée) — cohérent avec `colorKey` stockée VERBATIM par le domaine (ES-2.5 D6).
> **Discrimine** : rougit si le nombre de swatches ≠ `palette.keys.length`, si le callback fuit un `Color`/index, ou si la clé est remappée avant remontée.

**AC3 — 🔴 CŒUR WCAG : la couleur n'est JAMAIS le seul canal — chaque swatch porte un `Semantics.label` DISTINCT et NON vide (NFR-S6/AD-13).**
**Given** une toolbar dont le `colorKeyResolver` rend **la MÊME `Color`** (ex. gris) pour **DEUX** `colorKey` différentes (`'primary'`, `'secondary'`)
**When** on lit les nœuds `Semantics` des deux swatches (`tester.getSemantics`)
**Then** chaque swatch a un **`label` NON vide** et `label(primary) != label(secondary)` — les deux restent **distinguables SANS voir la couleur** (le canal texte/sémantique est redondant).
> **Discrimine (LOAD-BEARING)** : rougit **exactement** si l'implémentation véhicule la distinction par la seule couleur (labels vides / identiques). **Injection R3-1** : vider/uniformiser le `Semantics.label` des swatches ⇒ RC=1.

**AC4 — 🔴 CŒUR WCAG : la SÉLECTION est signalée par un marqueur STRUCTUREL non-coloré (R24, pas un anneau de couleur).**
**Given** une toolbar dont `selectedColorKey == 'success'`
**When** on inspecte l'arbre
**Then** un marqueur `find.byKey(ValueKey(kAnnotationSelectedMarkerKey))` (icône « coché »/forme) est présent **UNIQUEMENT** dans la swatch sélectionnée (`findsOneWidget`, descendant de la swatch `success`), **absent** des autres ; **et** le `Semantics` de la swatch sélectionnée porte `selected: true` (les autres `selected: false`).
> **Discrimine (LOAD-BEARING, R24)** : rougit si la sélection n'est signalée que par la couleur d'un anneau. **Injection R3-2** : supprimer le marqueur structurel (ne garder que l'anneau coloré) ⇒ `find.byKey` → 0 ⇒ RC=1.

**AC5 — 🔴 CŒUR WCAG : contraste MESURÉ du marqueur/foreground sur la swatch (≥ 3.0:1, AD-13).**
**Given** une toolbar dont `colorKeyResolver('success')` rend une couleur **claire connue** (ex. `#EEEEEE`) et `selectedColorKey == 'success'`
**When** on lit la `Color` réellement rendue du marqueur de sélection **et** la `Color` résolue de la swatch, puis on calcule `wcagContrastRatio(marker, swatch)`
**Then** le ratio est **≥ 3.0** (composant UI non-textuel WCAG 2.1) — la couleur du marqueur est **dérivée** de la swatch/scheme, jamais fixe.
> **Discrimine (LOAD-BEARING)** : rougit si le marqueur est `Colors.white` en dur (invisible sur swatch claire). **Injection R3-3** : fixer la couleur du marqueur à blanc constant ⇒ ratio < 3 ⇒ RC=1.

**AC6 — 🔴 WCAG : cibles interactives ≥ 48 dp (AD-13).**
**Given** la toolbar (boutons kind + swatches) **et** le panel (entrées) montés
**When** on **mesure** `tester.getSize(finder)` de chaque cible interactive
**Then** `width ≥ 48 && height ≥ 48` pour **chaque** bouton kind, **chaque** swatch, **chaque** entrée de panel tapable.
> **Discrimine** : rougit si une cible est sous-dimensionnée. **Injection R3-4** : contraindre une swatch à 24×24 dp ⇒ RC=1.

**AC7 — 🔴 WCAG : `Semantics` explicites, boutons annoncés (AD-13).**
**Given** la toolbar montée (avec `tester.ensureSemantics()`)
**When** on lit `tester.getSemantics(finder)` de chaque cible
**Then** chaque bouton kind/swatch expose un nœud `Semantics` **réel** avec `SemanticsProperties.button == true` (ou action tap) et un `label` **non vide** ; les entrées de panel exposent un `label`/`value` portant **kind + page** (canal texte).
> **Discrimine** : rougit si un contrôle n'a pas de `Semantics` explicite (lecteur d'écran muet). **Injection R3-5** : retirer le wrapper `Semantics` d'un contrôle ⇒ `getSemantics` sans `button`/label ⇒ RC=1.

**AC8 — SM-1 / AD-2 : sélection granulaire, controller ISOLÉ jamais recréé, voisinage non reconstruit.**
**Given** la toolbar montée ; on capture `final controllerBefore = <identité du ZAnnotationToolController de la toolbar>` et un **compteur de rebuild d'un widget témoin frère** hors tranche `selectedColorKey` (ex. la rangée des kinds)
**When** on change la `colorKey` sélectionnée **10 fois** successivement
**Then** le controller est **le même objet** (`identical(controllerAfter, controllerBefore)`, jamais recréé au build) et le **compteur de rebuild du témoin frère reste à sa valeur initiale** (aucun rebuild global).
> **Discrimine (LOAD-BEARING, R20)** : rougit si le controller est recréé dans `build` (identité changée) ou si un `setState` d'échelle toolbar reconstruit la rangée des kinds. **Injection R3-6** : lifter la sélection en `setState` de la toolbar ⇒ le témoin frère se reconstruit ⇒ RC=1. **Injection R3-6b** : recréer le controller dans `build` ⇒ `identical` faux ⇒ RC=1. *(Ancrer sur l'identité du controller PROPRE à la toolbar — R20 — jamais sur une garantie d'un sous-widget réutilisé.)*

**AC9 — `ZAnnotationPanel` : `ListView.builder` lazy, entrées accessibles, sélection remontée.**
**Given** un panel alimenté d'une **longue** `List<ZDocumentAnnotation>` (ex. 200) et `onSelect`
**When** on rend le panel dans une fenêtre bornée
**Then** le panel utilise `ListView.builder` (seul **un sous-ensemble** d'entrées est construit — `find.byType(<entrée>)` < 200, preuve du lazy) ; taper une entrée visible appelle `onSelect(<cette annotation>)` ; chaque entrée montre kind (icône+libellé) + swatch (canal non-coloré D5) + `page`.
> **Discrimine** : rougit si `ListView(children: [...])` construit tout (les 200 entrées trouvées), si `onSelect` remonte la mauvaise annotation, ou si une entrée réduit l'info à la couleur. **Injection R3-7** : remplacer par `ListView(children:)` ⇒ 200 entrées construites ⇒ RC=1.

**AC10 — RTL : rendu directionnel effectif (AD-13).**
**Given** la toolbar montée sous `Directionality(TextDirection.rtl)`
**When** on compare les positions de la **première** et de la **dernière** swatch
**Then** l'ordre visuel est **mirroré** (la première swatch de `palette.keys` est du côté **droit** en RTL, gauche en LTR) — le layout suit la direction, aucun bord codé en dur.
> **Discrimine** : rougit si un `EdgeInsets.only(left:)`/`Row` non-directionnel fige l'ordre indépendamment de la direction. **Injection R3-8** : remplacer un `EdgeInsetsDirectional.only(start:)` par `EdgeInsets.only(left:)` ⇒ le test RTL (et le scan AC13) rougissent.

**AC11 — FR-26 : couleurs ET libellés INJECTÉS, jamais en dur.**
**Given** une toolbar montée avec un `ZcrudScope` fournissant `colorKeyResolver: (k) => k == 'warning' ? const Color(0xFFABCDEF) : null` **et** `labels` surchargeant le libellé d'un kind
**When** on lit la `Color` rendue de la swatch `'warning'` et le texte du kind surchargé
**Then** la swatch `'warning'` rend **exactement `Color(0xFFABCDEF)`** (couleur injectée honorée) et le libellé du kind est **le texte surchargé** (jamais une chaîne FR en dur).
> **Discrimine** : rougit si une couleur/un libellé est codé en dur (l'override est ignoré). **Injection R3-9** : coder en dur la couleur d'une swatch ⇒ l'override est ignoré ⇒ RC=1 (jumeau de `ZSrsQualityButtons` AC4).

**AC12 — AD-10 : rendu défensif, jamais de throw.**
**Given** un panel alimenté d'une annotation à `text == null`, `colorKey == ''`, `kind` par défaut — **et** séparément `annotations == const []`, **et** un `ZcrudScope` sans `colorKeyResolver`
**When** on rend panel + toolbar
**Then** aucun `throw` ; l'entrée à contenu vide rend un extrait/placeholder propre + une swatch de repli (`ColorScheme`) ; la liste vide rend l'**empty-state** ; le resolver absent retombe sur le `ColorScheme` courant.
> **Discrimine** : rougit si un `colorKey` vide/`resolver null` fait planter le rendu.

**AC13 — Isolation, pureté du domaine, anti-hardcode (AD-1/AD-7, NFR-S10, FR-26 — scan machine).**
**Given** `lib/` de `zcrud_document`
**Then** un scan confirme : (a) `lib/src/domain/` **n'importe AUCUN** `package:flutter/*`/`dart:ui` (pureté préservée — garde AJOUTÉE `source_policy_test.dart`) ; (b) la présentation **est autorisée** à importer Flutter/`zcrud_core` ; (c) **aucun** `EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `Positioned(left:|right:)`, `TextAlign.left|right` dans `lib/src/presentation/` (directionnel) ; (d) **aucun** littéral `Color(0x…)`/`Colors.<name>` concret dans `lib/src/presentation/` (couleur injectée) ; (e) le barrel `zcrud_document.dart` n'expose **aucun** type Flutter/`Color` dans la signature publique des 2 widgets.
> **Discrimine** : chaque sous-scan rougit sur injection ciblée (import Flutter en domaine ; `EdgeInsets.only(left:)` ; `Colors.red` en présentation).

**AC14 — Graphe & runner (AD-1, R14).**
**Given** le workspace après bascule Flutter
**Then** `graph_proof.py` prouve l'acyclicité et `out-degree(zcrud_core)==0` **AVEC 0 nouvelle arête** (les arêtes `zcrud_document → {zcrud_core, zcrud_study_kernel, zcrud_annotations}` préexistent) ; `melos list` inchangé (**20** packages) ; `zcrud_document` est routé vers **`flutter test`** (bascule D2) ; le domaine reste couvert (suites existantes vertes sous `flutter test`).

---

## Deliverables (D1..Dn)

- **D1** `packages/zcrud_document/lib/src/presentation/z_annotation_tool_controller.dart` — `ZAnnotationToolController extends ChangeNotifier` : `ValueListenable<ZDocumentAnnotationKind> selectedKind`, `ValueListenable<String> selectedColorKey`, mutateurs `selectKind`/`selectColorKey`, `dispose()`. **Aucun** import de gestionnaire d'état. *(Constantes de clés : `kAnnotationKindKeyPrefix`, `kAnnotationSwatchKeyPrefix`, `kAnnotationSelectedMarkerKey`, `kAnnotationPanelEntryKeyPrefix` — exposées pour les tests, R24.)*
- **D2** `packages/zcrud_document/lib/src/presentation/z_annotation_toolbar.dart` — `ZAnnotationToolbar({ ZAnnotationToolController? controller, ZColorPalette palette = const ZColorPalette.defaultStudy(), ValueChanged<ZDocumentAnnotationKind>? onKindSelected, ValueChanged<String>? onColorSelected, Key? key })` : `StatefulWidget` owned/injected du controller (initState/dispose ssi possédé), rangée des kinds (`ValueListenableBuilder` sur `selectedKind`) + palette (`ValueListenableBuilder` sur `selectedColorKey`), swatch = `Color` via `ZcrudScope.colorKeyResolver` (repli `ColorScheme`), **canal non-coloré D5** (Semantics label distinct + marqueur structurel keyé), cibles ≥ 48 dp, directionnel, libellés via `ZcrudScope.labels`.
- **D3** `packages/zcrud_document/lib/src/presentation/z_annotation_panel.dart` — `ZAnnotationPanel({ required List<ZDocumentAnnotation> annotations, ValueChanged<ZDocumentAnnotation>? onSelect, ZColorPalette palette = const ZColorPalette.defaultStudy(), Widget? emptyState, Key? key })` : `ListView.builder`, entrée accessible (kind icône+libellé, swatch canal-non-coloré, extrait `text`/`page`, ≥ 48 dp, `Semantics`), `onSelect` (`null` = non tapable, AD-4), empty-state, défensif AD-10.
- **D4** `packages/zcrud_document/lib/zcrud_document.dart` — barrel ÉTENDU : `export 'src/presentation/z_annotation_toolbar.dart' show ZAnnotationToolbar, ZAnnotationToolController, kAnnotation*;` + `export 'src/presentation/z_annotation_panel.dart' show ZAnnotationPanel;` (aucun type Flutter/`Color` en signature publique).
- **D5** `packages/zcrud_document/pubspec.yaml` — bascule Flutter : `flutter: {sdk: flutter}` (deps), `flutter_test: {sdk: flutter}` (dev, `test` conservé) ; commentaires d'arête mis à jour (bascule + **0 nouvelle arête** + perte `gate:web` DW-ES82-1).
- **D6** `packages/zcrud_document/test/z_annotation_toolbar_test.dart` — AC1, AC2, **AC3/AC4/AC5 (CŒUR WCAG)**, AC6, AC7, **AC8 (SM-1)**, AC10 (RTL), AC11 (injection couleur/libellé), AC12 (défensif). Helper `wcagContrastRatio` local (calcul luminance relative WCAG 2.1).
- **D7** `packages/zcrud_document/test/z_annotation_panel_test.dart` — AC6/AC7 (entrées), AC9 (lazy `ListView.builder` + `onSelect`), AC12 (défensif : `text null`/`colorKey ''`/liste vide), canal non-coloré des entrées.
- **D8** `packages/zcrud_document/test/source_policy_test.dart` — **NOUVELLE garde** (D10) : pureté `lib/src/domain/` (aucun Flutter/`dart:ui`) ; présentation autorisée ; AC13 (scans directionnel + anti-hardcode couleur + isolation barrel) ; note bascule Flutter + `gate:web` (DW-ES82-1). `@TestOn('vm')`.
- **D-DOC** `architecture.md § Deferred` + memlog — **DW-ES82-1** (perte couverture `gate:web` après bascule Flutter de `zcrud_document`). *(Édition documentaire hors code ; à appliquer par l'orchestrateur/code-review — cf. précédent DW-ES-6.1-1.)*

---

## Tâches (T1..Tn)

- **T1** — `pubspec.yaml` (D5) : bascule Flutter (`flutter`/`flutter_test`, conserver `test`), commentaires d'arête (0 nouvelle arête + `gate:web`) ; `dart pub get` (workspace) **VERT**.
- **T2** — `ZAnnotationToolController` (D1) : `ChangeNotifier` + `ValueListenable` par tranche + constantes de clés. Aucun gestionnaire d'état.
- **T3** — `ZAnnotationToolbar` (D2) : owned/injected, tranches scopées (`ValueListenableBuilder`), swatch via `ZcrudScope.colorKeyResolver` (repli `ColorScheme`), **canal non-coloré D5** (Semantics distinct + marqueur keyé), ≥ 48 dp, directionnel, libellés injectés.
- **T4** — `ZAnnotationPanel` (D3) : `ListView.builder`, entrée accessible + canal non-coloré, `onSelect` (`null`=non tapable), empty-state, défensif.
- **T5** — Barrel (D4) : exports `show`, aucun type Flutter/`Color` en surface.
- **T6** — Tests toolbar (D6) + panel (D7) : **AC3/AC4/AC5 (WCAG couleur/contraste), AC8 (SM-1), AC9 (lazy)** en priorité (pouvoir discriminant). Helper `wcagContrastRatio`.
- **T7** — `source_policy_test.dart` (D8) : garde de pureté domaine AJOUTÉE + scans AC13 + note `gate:web`.
- **T8** — DW-ES82-1 (D-DOC) : consigner la perte `gate:web` (pubspec + `source_policy_test`) ; escalade `architecture.md § Deferred` **par l'orchestrateur/code-review**.
- **T9** — Vérif verte (cf. section) : `flutter test` (zcrud_document) + `graph_proof.py` + `melos analyze` ciblé.

---

## Injections R3 prévues (preuve NON-POWERLESS — chaque garde WCAG rougit quand on la neutralise)

> 🔴 **Spécial WCAG** : les injections ci-dessous **neutralisent la LIGNE DE PROD que l'AC protège** (Semantics, marqueur structurel, contraste, taille de cible), **jamais** un artefact adjacent. Une garde a11y qui ne rougit pas ici est **POWERLESS** (motif dominant R12/R24) et doit être ré-ancrée avant `done`.

1. **AC3 (couleur ≠ seul canal)** : uniformiser/vider le `Semantics.label` des swatches (distinction par la seule couleur) ⇒ `label(A) == label(B)`/vides ⇒ **ROUGE**. Rétablir.
2. **AC4 (marqueur structurel de sélection)** : supprimer le widget `ValueKey(kAnnotationSelectedMarkerKey)` (ne garder que l'anneau coloré) ⇒ `find.byKey` → 0 ⇒ **ROUGE** (R24). Rétablir.
3. **AC5 (contraste mesuré)** : fixer la couleur du marqueur à `Colors.white` constant ⇒ sur swatch claire `#EEEEEE`, `wcagContrastRatio < 3` ⇒ **ROUGE**. Rétablir.
4. **AC6 (≥ 48 dp)** : contraindre une swatch/bouton à 24×24 dp ⇒ `getSize < 48` ⇒ **ROUGE**. Rétablir.
5. **AC7 (Semantics explicite)** : retirer le wrapper `Semantics` d'un contrôle ⇒ nœud sans `button`/label ⇒ **ROUGE**. Rétablir.
6. **AC8 (SM-1)** : (a) lifter la sélection en `setState` d'échelle toolbar ⇒ le témoin frère (rangée kinds) se reconstruit ⇒ **ROUGE** ; (b) recréer le `ZAnnotationToolController` dans `build` ⇒ `identical` faux ⇒ **ROUGE** (R20). Rétablir.
7. **AC9 (lazy)** : remplacer `ListView.builder` par `ListView(children:)` ⇒ 200 entrées construites ⇒ **ROUGE**. Rétablir.
8. **AC10/AC13 (directionnel)** : remplacer un `EdgeInsetsDirectional.only(start:)` par `EdgeInsets.only(left:)` ⇒ test RTL + scan directionnel ⇒ **ROUGE**. Rétablir.
9. **AC11 (couleur/libellé injectés)** : coder en dur la couleur d'une swatch (`Colors.amber`) ⇒ l'override `colorKeyResolver` est ignoré ⇒ **ROUGE** ; + scan anti-hardcode AC13(d) ⇒ **ROUGE**. Rétablir.

> **R13 — restauration par édition CIBLÉE** : chaque injection est retirée après observation du rouge ; aucune garde n'est laissée neutralisée.

---

## Vérif verte à rejouer RÉELLEMENT (RC capturé HORS pipe — R15 ; runner selon Flutter/pur-Dart — R14)

```bash
# 1) Résolution workspace après bascule Flutter de zcrud_document
dart pub get   # RC=0

# 2) Runner FLUTTER (R14 — zcrud_document est DÉSORMAIS un package Flutter ;
#    NE PAS lancer `dart test` ici — un package Flutter le refuse)
cd packages/zcrud_document && flutter test ; echo "RC=$?"   # RC=0, N tests
#    (les suites de DOMAINE pur-Dat existantes restent vertes sous flutter test)

# 3) Graphe : acyclicité + CORE OUT=0, ZÉRO nouvelle arête (toutes préexistent)
cd ../../ && python3 scripts/dev/graph_proof.py ; echo "RC=$?"   # RC=0

# 4) Analyse ciblée (repo-wide au gate de commit d'epic, cf. CLAUDE.md)
dart run melos exec --scope="zcrud_document" -- dart analyze ; echo "RC=$?"   # RC=0

# 5) Inventaire packages inchangé
dart run melos list ; echo "RC=$?"   # 20 packages
```

> ⚠️ **RC hors pipe** (R15) : `cmd ; echo "RC=$?"`, jamais `cmd | tee` (le RC d'un pipe est celui de `tee`).
> ⚠️ **Bascule Flutter (R14)** : après D5, `zcrud_document` s'exécute sous **`flutter test`** ; `dart test` est refusé. Le `@TestOn('vm')` de `source_policy_test.dart` reste valide sous `flutter test`.
> ⚠️ **`gate:web`** : `zcrud_document` **sort** de sa cible (Flutter) — c'est **attendu** (DW-ES82-1), **pas** une régression. Aucune suite ne casse (tout tourne sous VM).
> ⚠️ **Gate de commit d'epic** (workstreams au repos) : rejouer `melos run analyze` **ET** `melos run verify` **REPO-WIDE** — la bascule Flutter ajoute une surface Flutter au package ; une régression cross-package n'est visible que repo-wide (leçon `ZExportApi`). Un `graph_proof` vert NE remplace PAS `melos analyze`.

---

## Dépendances & séquencement

- **Dépend de** : **ES-2.5** (`done`), **ES-1.2/ES-2.3** (`done` — `ZColorPalette`/`remapColorKey`), + l'existant livré de `zcrud_core` (`ZcrudScope`/`ZColorKeyResolver`/`ZcrudLabels`).
- **∥ PARALLÉLISABLE avec ES-8.1** (`zcrud_study` — `ZTagEditor`/`ZTagChips`) : packages **DISJOINTS** ; seul point de contact possible = `zcrud_core` (qu'**aucune** des deux n'écrit).
  🔴 **DÉPENDANCE envers ES-8.1 : NON — vérifiée sur disque.** ES-8.1 écrit `zcrud_study/presentation` (tags), consomme `ZFlashcardTag`/`normalizeTagTitle` (`zcrud_study_kernel`) ; ES-8.2 écrit `zcrud_document/presentation` (annotations), consomme `ZDocumentAnnotation`/`ZColorPalette`. **Aucune arête `zcrud_study ↔ zcrud_document`** (graphe), **aucun** symbole partagé hors `zcrud_core`/`zcrud_study_kernel` (déjà `done`). ⇒ **parallélisation classique à packages indépendants** (PAS le cas « dépendant ∥ dépendance » R23). Les deux stories ne co-écrivent **jamais** `zcrud_core`.
- ⛔ **Ne jamais** mettre ES-8.2 en vol avec une story écrivant aussi `zcrud_document`.
- **Sprint-status** : la transition `es-8-2-…` `backlog → ready-for-dev` est appliquée par **l'orchestrateur** (édition ciblée) — **cette story NE touche PAS `sprint-status.yaml`**.

---

## Invariants AD applicables (rappel — s'appliquent à CHAQUE tâche)

AD-1 (acyclique, CORE OUT=0, **0 nouvelle arête**) · AD-2/AD-15 (Flutter-native, controller isolé owned/injected, `ValueListenable` par tranche, **aucun** gestionnaire d'état, `ZcrudScope`, SM-1) · AD-4 (`String colorKey` opaque, callback `null` = action absente, extension par injection) · AD-10 (rendu défensif, jamais de throw) · **AD-13** (directionnel, `Semantics` explicites, ≥ 48 dp, **couleur JAMAIS seul canal** — CŒUR) · FR-26 (couleurs/libellés/thème injectés via `ZcrudScope`, aucun hex en dur) · NFR-S6 (a11y & RTL, `ListView.builder`) · NFR-S10 (domaine `zcrud_document` reste pur-Dart — garde AJOUTÉE).

---

## Findings / dettes anticipés

- **DW-ES82-1 (jumeau DW-ES-6.1-1) — perte de couverture `gate:web` après bascule Flutter.** ANTICIPÉE et ASSUMÉE (D2/D10). Le domaine pur-Dart de `zcrud_document` (bornes `[0,1]`, `sanitizePage`, `sanitizeExtra`) n'est plus rejoué sous `dart test -p node`. **Aucune régression de test.** Correctif futur possible : extraire un sous-package `zcrud_document_domain` pur-Dart OU étendre `gate:web` aux packages Flutter via runner web dédié — **hors périmètre M** (réécrirait l'architecture des packages). À escalader `architecture.md § Deferred` (orchestrateur/code-review).
- **FINDING-ANTICIPÉ (motif dominant WCAG)** : le risque n°1 de cette story est un **AC a11y powerless** (vérifie l'existence d'un widget, pas son `Semantics`/contraste/taille). Mitigé par ancrage STRUCTUREL (D5/D6/R24) + injections R3-1..R3-5 qui neutralisent la ligne de prod. **Le code-review DOIT rejouer ces injections** et refuser tout AC a11y qui reste vert sous neutralisation.
- **Périmètre d'ancrage géométrique DÉFÉRÉ (hors story)** : l'édition d'annotations **ancrées sur une page PDF réelle** (fraction↔pixel via `ZAnnotationBounds` + taille de page mesurée) est un seam viewer (`dart:ui`/`Rect` rejetés en domaine — ES-2.5 D3) **hors périmètre ES-8.2** : cette story édite/liste kind + couleur + texte, elle n'ancre pas sur un rendu de page. Si un hôte réel exige l'ancrage géométrique, ouvrir une story dédiée (viewer). Consigner comme note, pas comme dette bloquante.
- **`ZAnnotationToolController` exporté** : léger élargissement de surface publique (nécessaire pour le patron owned/injected AD-15 et les tests SM-1). Cohérent avec le précédent `ZMindmapOutlineController` (ES-7.1). Non bloquant.

---

## Questions / clarifications (non bloquantes)

1. **DW-ES82-1 (perte `gate:web`)** : accepter la perte documentée pour ES-8.2, ou planifier une extraction `zcrud_document_domain` pur-Dart ? *Recommandation story : accepter + déférer (précédent DW-ES-6.1-1 ; l'extraction réécrirait l'architecture des packages, hors périmètre M).*
2. **Surface de `ZAnnotationToolbar`** : édite-t-elle aussi le **texte** d'une sticky-note (champ texte), ou uniquement kind + couleur ? *Recommandation : ES-8.2 = kind + palette de couleur + (optionnel) déclenchement d'édition de texte via callback ; le champ texte riche est un `ZMarkdownField`/champ standard câblé côté hôte (patron ES-6.1), hors périmètre du **toolbar**.* — **Décision d'implémentation : kind + couleur** ; le `text` est affiché (lecture) dans le **panel**, son édition est déléguée à l'hôte.

---

## Dev Agent Record

**Skill réel invoqué** : `bmad-dev-story` (tool `Skill`, chargé avec succès — pas de fallback disque).

### Implementation Plan (résumé)
Deux widgets de PRÉSENTATION + un controller isolé, bâtis AU-DESSUS des modèles ES-2.5 (aucun modèle/`.g.dart`/codegen touché). Bascule Flutter du package (précédent ES-6.1). Couleurs/libellés injectés via `ZcrudScope` ; couleur JAMAIS seul canal (Semantics label distinct + marqueur structurel keyé + contraste dérivé mesuré) ; réactivité Flutter-native à tranches (`ValueListenableBuilder` par slice, controller owned/injected).

### Tâches (T1..T9) — toutes complètes
- [x] **T1** pubspec bascule Flutter (`flutter`/`flutter_test`, `test` conservé) + commentaires d'arête (0 nouvelle arête + `gate:web`) ; `dart pub get` VERT.
- [x] **T2** `ZAnnotationToolController` (`ChangeNotifier` pur-Flutter, `ValueListenable` par tranche, constantes de clés).
- [x] **T3** `ZAnnotationToolbar` (owned/injected, tranches scopées, swatch via `zResolveColorKeyOrSlot`, canal non-coloré D5, marqueur dérivé contrasté, ≥48 dp, directionnel, libellés injectés).
- [x] **T4** `ZAnnotationPanel` (`ListView.builder`, entrées accessibles + canal non-coloré, `onSelect` `null`=non tapable, empty-state, défensif AD-10).
- [x] **T5** Barrel étendu (`show`, aucun type Flutter/`Color` en surface publique).
- [x] **T6** Tests toolbar + panel (AC1..AC12) — pouvoir discriminant, helper `wcagContrastRatio` local.
- [x] **T7** `source_policy_test.dart` (garde pureté domaine AJOUTÉE + scans AC13 + note `gate:web`).
- [x] **T8** DW-ES82-1 consignée (pubspec + source_policy) ; escalade `architecture.md § Deferred` DÉLÉGUÉE à l'orchestrateur/code-review.
- [x] **T9** Vérif verte rejouée (voir ci-dessous).

### Preuves R3 (injections — chaque garde WCAG rougit sous neutralisation)
Chaque injection neutralise la LIGNE DE PROD protégée (jamais un artefact adjacent) ; `flutter test <fichier> --name "<AC>"` capturé HORS pipe ; restauration ciblée ensuite (fichiers restaurés PROPRES, `diff` vide).

| # | AC | Neutralisation | Résultat |
|---|----|----|----|
| R3-1 | AC3 | `Semantics.label` swatch → `''` (uniformisé) | RED (assertion : label distinct) |
| R3-2 | AC4 | clé du marqueur structurel neutralisée | RED (`find.byKey` → 0) |
| R3-3 | AC5 | marqueur figé `Color(0xFFFFFFFF)` | RED (ratio < 3 sur swatch claire) |
| R3-4 | AC6 | cibles contraintes à 24 dp | RED (`getSize` < 48) |
| R3-5 | AC7 | `Semantics.button=false`, `label=''` | RED (nœud sans button/label) |
| R3-6 | AC8a | rangée kinds écoute `selectedColorKey` | RED (`kindRowBuilds` 1 → 11) |
| R3-6b | AC8b | controller recréé dans `build` | RED (`identical` faux) |
| R3-7 | AC9 | `ListView(children: List.generate)` | RED (200 construits + delegate non-builder) |
| R3-8 | AC13c | `TextAlign.start` → `TextAlign.left` | RED (scan directionnel) |
| R3-9 | AC11 | couleur swatch codée en dur | RED (override `colorKeyResolver` ignoré) |

> R3-6/R3-7 ont d'abord été rejoués car leurs 1ʳᵉ formulations échouaient à la COMPILATION (proof powerless) ; reformulés en neutralisations COMPILANTES ⇒ échec sur l'ASSERTION (RED réel).

### Vérif verte rejouée RÉELLEMENT (RC hors pipe — R15 ; runner Flutter — R14)
- `dart pub get` (workspace, après bascule Flutter) → **RC=0**
- `flutter test` (zcrud_document, suite COMPLÈTE domaine + présentation) → **RC=0, 195 tests** (dont 25 nouveaux : toolbar+panel+source_policy)
- `python3 scripts/dev/graph_proof.py` → **RC=0** — ACYCLIQUE OK, CORE OUT=0 OK, **20 nœuds**, arêtes `zcrud_document → {zcrud_core, zcrud_annotations, zcrud_generator, zcrud_study_kernel}` = **les 4 préexistantes (0 nouvelle arête)**
- `dart run melos list` → **20 packages**
- `dart run melos exec --scope=zcrud_document -- dart analyze` → **RC=0** (SUCCESS)

### DW-ES82-1 (à ESCALADER par l'orchestrateur/code-review)
Bascule Flutter ⇒ `zcrud_document` sort de `gate:web` (`gate_web_determinism.dart` exclut les packages `sdk: flutter`) : les matrices de coercition JSON déterministe du domaine (`ZAnnotationBounds [0,1]`, `sanitizePage`, `sanitizeExtra`) ne sont plus rejouées sous `dart test -p node`. AUCUNE régression (tout tourne sous VM). Consigné dans `pubspec.yaml` + `source_policy_test.dart`. **Escalade `architecture.md § Deferred` déléguée** (jumeau DW-ES-6.1-1). `architecture.md` NON modifié par cette story.

### File List (tous ABSOLUS, tous dans `packages/zcrud_document/`)
Créés :
- `packages/zcrud_document/lib/src/presentation/z_annotation_tool_controller.dart`
- `packages/zcrud_document/lib/src/presentation/z_annotation_toolbar.dart`
- `packages/zcrud_document/lib/src/presentation/z_annotation_panel.dart`
- `packages/zcrud_document/test/z_annotation_toolbar_test.dart`
- `packages/zcrud_document/test/z_annotation_panel_test.dart`
- `packages/zcrud_document/test/source_policy_test.dart`

Modifiés :
- `packages/zcrud_document/lib/zcrud_document.dart` (barrel étendu — exports `show` de la présentation)
- `packages/zcrud_document/pubspec.yaml` (bascule Flutter : `flutter`/`flutter_test`, `test` conservé)

### Change Log
- 2026-07-15 — ES-8.2 implémentée : `ZAnnotationToolbar`/`ZAnnotationPanel`/`ZAnnotationToolController` accessibles WCAG (AD-13), bascule Flutter de `zcrud_document`, 25 tests à pouvoir discriminant (9+1 injections R3 prouvées). Status ready-for-dev → review.
