# Story 4.4: `ZColorConfig.multiple` natif au cœur

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Story key: fp-4-4-color-multiple-coeur · Source: epics-zcrud-form-parity-2026-07-18/epics.md → Epic 4, Story 4.4 · SPINE AD-52 -->

## Story

As a développeur consommateur,
I want sélectionner **plusieurs** couleurs via une variante native `ZColorConfig.multiple` (valeur `List<int>` ARGB),
so that je couvre la variante `color` **multiple** de DODLP (`color_picker_field`) **sans forker** un package tiers peu maintenu ni introduire de dépendance lourde au cœur.

## Contexte & cadrage (lire avant de coder)

**Marquage epic :** `[Média-rich]` · **CORE-SÉRIALISÉE** — cette story est le **seul écrivain** de `zcrud_core` pendant sa fenêtre. Elle **ne touche AUCUN satellite, ni l'exemple/showcase, ni un binding.** Binds **FR-20** ; **AD-52** ; **NFR-5/6** ; contribue FR-40.

**Ce qui existe déjà (NE PAS réinventer — étendre/dupliquer proprement) :**
- Le champ `color` **simple** est **natif** et complet dans `packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart` : `ZColorFieldWidget` (palette dérivée + aperçu + bouton « couleur personnalisée »), le picker built-in NEUTRE **public** `ZColorPickerDialog` (`@visibleForTesting`, sliders HSV + opacité + hex défensif + récents, 100 % Flutter), et le seam injectable `ZColorPicker` (`ZcrudScope.colorPicker`). La couleur simple = **`int` ARGB 32 bits** (`0xAARRGGBB`) en tranche.
- `ZColorConfig` (`packages/zcrud_core/lib/src/domain/edition/z_field_config.dart:111`) : config `const` additive `{enableAlpha, showPalette, showRecent, recentColors}`. Helper `_listEquals` déjà présent dans le fichier.
- Dispatch : `EditionFieldType.color` → `EditionFamily.color` (`edition_field_family.dart:165`) → `ZColorFieldWidget` monté dans `z_field_widget.dart:573` avec `onChanged: (argb) => controller.setValue(field.name, argb)` (int).
- Lecture : `z_read_only_value.dart:100` (`_colorValue`) rend la pastille + code pour `color`.
- l10n : clés `selectColor` / `customColor` / `colorHue` / `colorSaturation` / `colorBrightness` / `colorOpacity` / `colorHex` / `colorRecent` / `apply` / `cancel` dans `z_localizations.dart` (maps `en` **et** `fr`).
- Tests de référence du patron : `packages/zcrud_core/test/presentation/edition/dp17_color_picker_test.dart` (palette, seam prioritaire, hex défensif, récents, `showPalette=false`).

**`color` simple = déjà NATIF ; `color` multiple = ABSENT** (`ZColorConfig` strictement mono aujourd'hui) — matrice `docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md` ligne #28b / P1 : *« `zcrud_core` natif (picker built-in en boucle + case à cocher) — recommandé ; `color_picker_field` peu maintenu — répliquer en Flutter pur, ne pas forker. »*

**Aucun nouvel `EditionFieldType`.** `color` existe déjà. La variante multiple est portée par la **config** (`ZColorConfig.multiple`), pas par un nouvel enum → **pas** de nouvelle valeur `@JsonKey(unknownEnumValue:)` à ajouter ici. Le volet « additif enum » d'AD-52 ne s'active pas pour cette story (à distinguer de FR-5 `dateRange`). Le codegen reste rejoué et tout `*.g.dart` régénéré est commité, mais aucune émission d'enum nouvelle n'est attendue.

## Décisions tranchées (écarts résolus par la story)

1. **Surface API `ZColorConfig.multiple`.** Ajouter au `ZColorConfig` existant un champ `final bool multiple` (défaut **`false`** ⇒ rétro-compat stricte : un `ZColorConfig` ou un `color` sans config reste mono, `int` ARGB) **et** un constructeur nommé `const ZColorConfig.multiple({...})` qui pose `multiple = true`. Cela matérialise la surface littérale `ZColorConfig.multiple` exigée par AD-52 tout en gardant la sémantique **additive** (aucun champ retiré/renommé). Étendre `operator ==`/`hashCode` au nouveau champ.
2. **Forme de valeur.** Mode simple = `int` ARGB (inchangé). Mode multiple = **`List<int>` ARGB**. Aucune autre forme.
3. **Widget.** Créer un widget dédié `ZColorMultiFieldWidget` (nouveau fichier `families/z_color_multi_field_widget.dart`) plutôt que de surcharger la signature `ValueChanged<int>` de `ZColorFieldWidget` (qui doit rester **intacte**, rétro-compat). Il **réutilise** le picker built-in public `ZColorPickerDialog` (boucle « ajouter une couleur ») et une palette dérivée à **cases à cocher** (multi-sélection). Signature `onChanged: ValueChanged<List<int>>`. Zéro duplication du picker : on réemploie `ZColorPickerDialog` tel quel.
4. **Dispatch.** Dans `z_field_widget.dart`, la branche `EditionFamily.color` teste `field.config` : si c'est un `ZColorConfig` avec `multiple == true` → monter `ZColorMultiFieldWidget` (`onChanged: (list) => controller.setValue(field.name, list)`), **sinon** conserver exactement le montage actuel de `ZColorFieldWidget` (int). `EditionFamily` reste dérivée du seul type `color` (aucun nouvel enum de famille).
5. **Lecture (read-only).** Étendre `_colorValue` (`z_read_only_value.dart`) pour rendre **plusieurs** pastilles quand la valeur est une `List<int>` (parité DODLP), sans casser le rendu simple `int`. Parse défensif identique.
6. **Showcase / matrice « ABSENT → livré ».** L'AC d'epic mentionne une démonstration showcase et le flip matrice. **Hors périmètre de cette story cœur-sérialisée** (le showcase/exemple et les bindings sont d'autres axes, fichiers disjoints). Le cœur **prouve** la variante par des **tests widget porteurs** ; la démonstration showcase et le flip de la ligne #28b sont **délégués** à l'axe binding/exemple (E2.2 / example harness). Écart consigné ici, pas silencieux.
7. **Roue HSV riche (`flex_color_picker`).** Reste **côté binding** via `ZcrudScope.colorPicker` (AD-52). **Interdit** au cœur. Le seam injecté peut être réutilisé pour « ajouter une couleur » en mode multiple, mais son absence retombe sur `ZColorPickerDialog` built-in — comme en simple.

## Acceptance Criteria

1. **Given** `ZColorConfig` du cœur *(FR-20 / AD-52)*
   **When** on ajoute la variante `multiple`
   **Then** il existe un champ `final bool multiple` (défaut `false`) **et** un constructeur nommé `const ZColorConfig.multiple({...})` (pose `multiple = true`) ; `operator ==`/`hashCode` couvrent le nouveau champ ; deux `ZColorConfig()` simples restent égaux et un `ZColorConfig.multiple()` en diffère. **Test porteur** : égalité/hash + injection R3 (retirer `multiple` de `==` fait rougir un test qui distingue simple↔multiple).

2. **Given** un champ `color` déclaré avec `ZColorConfig.multiple(...)` *(FR-20)*
   **When** il est monté dans `DynamicEdition`
   **Then** le dispatch (`z_field_widget.dart`, branche `EditionFamily.color`) monte `ZColorMultiFieldWidget` ; l'ajout/retrait d'une couleur émet `onChanged` avec une **`List<int>` ARGB** (jamais un `int` seul) écrite via `controller.setValue`. **Test porteur** : ajouter 2 couleurs → la tranche vaut `[argbA, argbB]` ; injection R3 (forcer le dispatch sur le widget simple en mode multiple fait rougir le test de forme de valeur).

3. **Given** un champ `color` **sans** config, ou avec `ZColorConfig()` (mono) *(rétro-compat NFR-5)*
   **When** il est monté et manipulé
   **Then** le comportement E3-3b-1/DP-17 est **inchangé au pixel de contrat** : `ZColorFieldWidget` monté, `onChanged` reçoit un **`int`** ARGB, palette + « couleur personnalisée » + seam fonctionnent. **Test porteur** : le test `dp17_color_picker_test.dart` reste vert **sans modification** ; un test de non-régression assert que le mode par défaut émet un `int`, pas une `List`.

4. **Given** un `ZColorMultiFieldWidget` avec une valeur d'entrée **corrompue** — `null`, un scalaire, une `List<dynamic>` mêlant `int`, `String`, `double`, `null` *(AD-10, parse défensif)*
   **When** le widget lit la valeur pour l'afficher
   **Then** un parseur défensif (ex. `List<int> _parseArgbList(Object?)`) **conserve uniquement les entrées `int` valides**, **ignore** silencieusement les autres, et retombe sur `const <int>[]` pour toute entrée non-liste ; le widget **rend** les seules couleurs valides et le formulaire **ne throw jamais**. **Test porteur (pas seulement `takeException` isNull)** : entrée `['x', 0xFF112233, null, 2.5, 0xFF445566]` ⇒ le widget affiche **exactement** 2 pastilles ARGB `[0xFF112233, 0xFF445566]` (assertion sur le **contenu filtré**, pas la seule absence d'exception) **et** `tester.takeException()` est `null`. Injection R3 : remplacer le filtre défensif par un cast direct `value as List<int>` fait rougir ce test (crash sur entrée mêlée).

5. **Given** un `DynamicEdition` parent contenant un champ multiple à valeur corrompue *(AD-10, survie du parent)*
   **When** le formulaire se construit
   **Then** le parent rend intégralement ses autres champs (le champ corrompu ne fait pas échouer la construction), `tester.takeException()` est `null`. **Test porteur** : monter un form à ≥ 2 champs dont le color-multiple corrompu, assert la présence d'un autre champ + aucune exception.

6. **Given** la sélection multiple rendue *(AD-13 a11y/RTL, FR-26 thème)*
   **When** on affiche palette à cases, pastilles sélectionnées, bouton « ajouter » et retrait
   **Then** chaque cible interactive est **≥ 48 dp**, porte un `Semantics` (`button`/`selected`/label incluant le hex), le layout est **directionnel** (`Wrap` sous `Directionality`, `EdgeInsetsDirectional`, `AlignmentDirectional` ; **aucun** `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`), la bordure de sélection dérive de `ZcrudTheme`/`ColorScheme` (**aucune** `Color(0xFF…)` littérale ; les swatches sont des **données** ARGB dérivées HSV). **Greps négatifs** joués sur le nouveau fichier (voir Tâche 6). **Test porteur** : `find.bySemanticsLabel` sur une pastille sélectionnée + assertion de taille ≥ 48 dp.

7. **Given** des libellés du mode multiple *(FR-26 L10n, aucun texte codé en dur)*
   **When** on ajoute les clés nécessaires (ex. `colorAddColor`, `colorSelectedCount` ou équivalent, `removeColor`)
   **Then** elles sont ajoutées dans **les deux** maps `en` **et** `fr` de `z_localizations.dart`, résolues via `label(context, key)` (jamais de littéral UI dans le widget). **Test porteur / grep** : `grep` négatif d'un `Text('...')` littéral non-l10n dans le nouveau widget ; test que la clé fr existe.

8. **Given** le cœur `zcrud_core` *(AD-1, CORE OUT=0, NFR-6)*
   **When** la story est terminée
   **Then** `pubspec.yaml` de `zcrud_core` n'a **aucune** dépendance nouvelle (ni `color_picker_field`, ni `flex_color_picker`, ni aucune dep lourde) — 100 % Flutter/Material ; `scripts/dev/graph_proof.py` reste **CORE OUT=0**, le graphe **acyclique**. `melos run generate` rejoué, tout `*.g.dart` de `packages/*/lib/` régénéré est **commité** (aucune émission d'enum nouvelle attendue), test rétro-compat de (dé)sérialisation **vert**. **Preuve** : `grep -q` négatif de `color_picker_field|flex_color_picker` dans `packages/zcrud_core/pubspec.yaml` + sortie `graph_proof`.

## Tasks / Subtasks

- [x] **Tâche 1 — `ZColorConfig.multiple` (domaine)** (AC: 1)
  - [x] Dans `z_field_config.dart`, ajouter `final bool multiple` (défaut `false`) à `ZColorConfig` + constructeur nommé `const ZColorConfig.multiple({enableAlpha, showPalette, showRecent, recentColors})` posant `multiple: true`.
  - [x] Étendre `operator ==` et `hashCode` au champ `multiple`. Documenter la rétro-compat (défaut `false`) dans la docstring.
  - [x] Test unité domaine (nouveau `test/domain/edition/z_color_config_multiple_test.dart`) : égalité simple↔simple, différence simple↔multiple, hash cohérent.

- [x] **Tâche 2 — Widget multi-sélection natif** (AC: 2, 4, 6, 7)
  - [x] Créer `families/z_color_multi_field_widget.dart` : `ZColorMultiFieldWidget` (`StatelessWidget`) `{field, value, onChanged: ValueChanged<List<int>>}`.
  - [x] Parseur défensif `static List<int> _parseArgbList(Object? value)` : `List` ⇒ ne garder que les `int` ; toute autre entrée ⇒ `const <int>[]`.
  - [x] Palette dérivée à **cases** (données dérivées HSV dupliquées proprement de `_palette()` — aucun littéral couleur ; case cochée via `Icon(Icons.check)`). Toggle d'un swatch = add/remove dans la liste, émet `onChanged(nouvelleListe)`.
  - [x] Bouton « ajouter une couleur » ⇒ réutilise le seam `ZcrudScope.colorPicker` s'il existe, sinon `showDialog<int>(ZColorPickerDialog(...))` built-in ; la valeur retournée est **ajoutée** (append, dédup). Défensif : seam qui throw ⇒ aucune écriture (`try/catch` → `null`).
  - [x] Retrait par pastille (`_RemovableSwatch`), cible ≥ 48 dp, `Semantics(button/selected/label hex)`, `EdgeInsetsDirectional`/`AlignmentDirectional`/`Wrap` directionnel.

- [x] **Tâche 3 — l10n** (AC: 7)
  - [x] Clés `colorAddColor` + `removeColor` ajoutées dans les maps `en` **et** `fr` de `z_localizations.dart`. Résolues via `label(context, key)`.

- [x] **Tâche 4 — Dispatch édition** (AC: 2, 3)
  - [x] Dans `z_field_widget.dart`, branche `EditionFamily.color` : si `field.config is ZColorConfig && multiple` ⇒ `ZColorMultiFieldWidget(onChanged: (l) => controller.setValue(field.name, l))` ; **sinon** montage `ZColorFieldWidget` **inchangé**.
  - [x] `ZColorMultiFieldWidget` exporté dans le barrel `zcrud_core.dart`.

- [x] **Tâche 5 — Lecture (read-only)** (AC: 5)
  - [x] `_colorValue` (`z_read_only_value.dart`) étendu : valeur `List` ⇒ N pastilles (parse défensif int), sinon rendu simple `int` inchangé (helper `_colorChip`).

- [x] **Tâche 6 — Tests porteurs + preuves disque** (AC: 1–8)
  - [x] `test/presentation/edition/color_multiple_test.dart` : (a) add 2 couleurs → liste ; (b) entrée corrompue mêlée → **exactement** les pastilles ARGB valides + `takeException` null ; (c) parent multi-champ corrompu survit ; (d) mode défaut émet un `int` ; (e) a11y ≥ 48 dp + Semantics.
  - [x] `dp17_color_picker_test.dart` reste vert **sans édition** (12 tests couleur verts).
  - [x] Greps négatifs sur le nouveau fichier : styles interdits ⇒ **vide** (seul match = docstring l.28) ; `Text('` ⇒ **vide** ; `color_picker_field|flex_color_picker` dans pubspec ⇒ **absent**.

- [x] **Tâche 7 — Vérif verte + codegen** (AC: 8)
  - [x] `dart run melos run generate` OK ; **aucune** diff `*.g.dart` (attendu : aucune émission d'enum).
  - [x] `dart analyze packages/zcrud_core` RC=0 (2 infos pré-existantes non liées dans `z_batch_action_test.dart`).
  - [x] `flutter test packages/zcrud_core` RC=0 — **1007 tests** verts.
  - [x] `python3 scripts/dev/graph_proof.py` ⇒ **CORE OUT=0**, **ACYCLIQUE**.

## Dev Notes

### Fichiers à toucher (tous sous `packages/zcrud_core/` — CORE-SÉRIALISÉE, aucun satellite)
- **UPDATE** `lib/src/domain/edition/z_field_config.dart` — champ `multiple` + ctor `.multiple` sur `ZColorConfig` (l.111). Préserver les 4 champs existants et `_listEquals`.
- **NEW** `lib/src/presentation/edition/families/z_color_multi_field_widget.dart` — widget multi + `_parseArgbList` défensif ; **réutilise** `ZColorPickerDialog` (public, `@visibleForTesting`) et le seam `ZColorPicker` du fichier simple.
- **UPDATE** `lib/src/presentation/edition/z_field_widget.dart` (l.573, branche `EditionFamily.color`) — dispatch conditionnel simple/multiple. Préserver la branche simple intacte.
- **UPDATE** `lib/src/presentation/edition/z_read_only_value.dart` (`_colorValue`, l.100) — rendu multi-pastilles défensif.
- **UPDATE** `lib/src/presentation/l10n/z_localizations.dart` — clés multiple (maps `en` + `fr`).
- **UPDATE** `lib/zcrud_core.dart` — export du nouveau widget.
- **NEW** tests : `test/domain/edition/z_color_config_multiple_test.dart`, `test/presentation/edition/color_multiple_test.dart`.

### Invariants AD applicables (NON-NÉGOCIABLES)
- **AD-1 / NFR-6** : `zcrud_core` sans dépendance lourde ; **CORE OUT=0**. Roue HSV riche = binding via `ZcrudScope.colorPicker`, jamais au cœur. `color_picker_field` **interdit** (peu maintenu — ne pas forker, répliquer en Flutter pur).
- **AD-2 / SM-1** : le widget est monté sous la granularité de rebuild par tranche existante ; `onChanged → controller.setValue` ; **pas** de `TextEditingController` pour la palette ; le builder ne reçoit que `value`/`onChanged`, jamais le `ZFormController`.
- **AD-10** : parse défensif `List<int>` — entrée corrompue ignorée entrée par entrée, jamais un throw ; parent survit. Preuve par **contenu filtré**, pas seulement `takeException isNull`.
- **AD-13** : cibles ≥ 48 dp, `Semantics`, directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`Wrap`), contraste bordure via thème.
- **FR-26** : couleurs = **données** ARGB dérivées ; bordure/sélection du `ZcrudTheme`/`ColorScheme` ; aucun littéral couleur, aucun libellé codé en dur.
- **AD-52** : variante native additive ; **une story cœur à la fois** (respectée : cette story est le seul écrivain cœur). Pas de nouvel `EditionFieldType` ⇒ le volet `@JsonKey(unknownEnumValue:)` ne s'active pas ici.

### Forme de valeur & (dé)sérialisation
La valeur du champ (`List<int>` ARGB) transite par le `toMap/fromMap` du **modèle consommateur** (généré), pas par la config. La config `ZColorConfig` est `const` **authored** (jamais désérialisée depuis JSON dans le cœur). Le « parse défensif » de cette story porte donc sur la **lecture de la valeur de tranche** au rendu (widget + read-only), pas sur une `fromJson` de config. Le test rétro-compat de sérialisation existant doit rester vert (aucune valeur d'enum ajoutée).

### Pièges à éviter (défauts de review anticipés)
- **La prose ment** : ne pas affirmer « défensif » sans un test qui **rougit** au cast direct. Prouver le filtrage par le **contenu** rendu.
- **Contraste/48 dp** : ne pas réduire la cible sous 48 dp au motif d'un layout compact multi-couleurs.
- **Rétro-compat** : ne **jamais** changer la signature `ValueChanged<int>` de `ZColorFieldWidget` ni son montage par défaut ; le mode simple est le défaut.
- **Duplication** : réutiliser `ZColorPickerDialog` (déjà public) plutôt que recopier le picker ; factoriser la palette dérivée si trivial.

### Testing standards
- `flutter_test` widget tests + tests domaine ; `find.bySemanticsLabel`, `tester.takeException()`. Tests porteurs (R3) : chaque AC a un test qui **rougit** quand la logique casse (cast direct, dispatch inversé, `==` amputé). Fichiers `*_test.dart` sous `packages/zcrud_core/test/`.

### Project Structure Notes
- Emplacement conforme : famille sous `presentation/edition/families/`, config sous `domain/edition/`, barrel `lib/zcrud_core.dart`, l10n sous `presentation/l10n/`. Aucun conflit avec la structure hexagonale ; aucune arête sortante nouvelle (CORE OUT=0).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story 4.4]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-52]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-form-parity-2026-07-18/prd.md#FR-20]
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md#28b] (P1 : natif Flutter pur, ne pas forker `color_picker_field`)
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart] (patron simple : palette, `ZColorPickerDialog`, seam)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_config.dart#L111] (`ZColorConfig` à étendre)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart#L573] (dispatch `EditionFamily.color`)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_read_only_value.dart#L100] (`_colorValue` read-only)
- [Source: packages/zcrud_core/test/presentation/edition/dp17_color_picker_test.dart] (patron de tests couleur)

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `bmad-dev-story` (fallback disque `.claude/skills/bmad-dev-story/SKILL.md`).

### Debug Log References

- Échec initial des 5 tests widget : `SingleChildScrollView` autour de `DynamicEdition` (qui scrolle déjà) ⇒ viewport vertical non borné. Corrigé en retirant le wrapper (patron `file_field_a11y_rtl_test.dart`). Après correction : 5/5 verts.

### Completion Notes List

- **Mode multiple additif** : `ZColorConfig` gagne `final bool multiple` (défaut `false`) + ctor `const ZColorConfig.multiple({...})` (pose `multiple: true`). `==`/`hashCode` couvrent le champ. Constructeur par défaut public **inchangé** (aucun nouveau paramètre exposé — rétro-compat stricte).
- **Widget dédié Flutter pur** `ZColorMultiFieldWidget` (`ValueChanged<List<int>>`) : palette dérivée HSV à cases cochables (`_CheckSwatch`), pastilles retirables (`_RemovableSwatch`), bouton « ajouter » réutilisant **tel quel** `ZColorPickerDialog` public + seam `ZColorPicker` (`ZcrudScope.colorPicker`). **Zéro duplication du picker** ; roue HSV riche reste côté binding (AD-52). Valeur en tranche = `List<int>` ARGB, jamais un `int` seul.
- **Rétro-compat prouvée** : `dp17_color_picker_test.dart` reste vert **sans aucune édition** ; test (d) assert que le mode défaut émet un `int` (pas une `List`). Dispatch `z_field_widget.dart` : mono intact, multi seulement si `ZColorConfig.multiple`.
- **Défensif AD-10 par le CONTENU + injection R3** : `_parseArgbList` conserve **exactement** les entrées `int` d'une liste, retombe sur `const <int>[]` hors-liste. Test (b) : `['x', 0xFF112233, null, 2.5, 0xFF445566]` ⇒ **exactement 2 pastilles** `#FF112233`/`#FF445566` (assertion sur le contenu filtré) + `takeException` null. Test (c) : parent multi-champ survit (voisin `TextField` rendu). Un cast direct `as List<int>` cracherait sur l'entrée mêlée (R3).
- **Read-only** `_colorValue` étendu : `List` ⇒ N pastilles (parse défensif) ; `int` ⇒ rendu simple inchangé.
- **a11y/RTL/thème** : cibles ≥ 48 dp (`meetsGuideline(androidTapTargetGuideline)` vert), `Semantics(button/selected/label hex)`, `Wrap`/`EdgeInsetsDirectional`/`AlignmentDirectional`, couleurs = données ARGB, bordures via `ZcrudTheme`/`ColorScheme`. l10n `colorAddColor`/`removeColor` en `en`+`fr`.
- **CORE OUT=0** : `graph_proof.py` ⇒ `out-degree(zcrud_core) = 0`, ACYCLIQUE ; `grep` négatif `color_picker_field|flex_color_picker` dans `pubspec.yaml`. Aucune dépendance ajoutée.
- **Périmètre CORE-SÉRIALISÉE respecté** : seuls des fichiers `packages/zcrud_core/` modifiés ; aucun satellite/binding touché ; API publique existante (`ZColorFieldWidget`, `ZColorConfig()`, `ZColorPickerDialog`) inchangée.
- **Écart consigné (décision #6)** : showcase/exemple + flip matrice ligne #28b **hors périmètre** de cette story cœur — délégués à l'axe binding/exemple.
- **RC réels rejoués** : `dart analyze packages/zcrud_core` RC=0 (2 infos pré-existantes non liées) · `flutter test packages/zcrud_core` = **1007 passed** · `melos run generate` OK, **aucune diff `*.g.dart`** · `graph_proof` CORE OUT=0 / ACYCLIQUE.

#### Corrections code-review (fp-4-4) — 2026-07-18

- **MED-1 (contraste dark-theme, vrai bug UX)** : la couleur du glyphe coche/croix peint sur la pastille était choisie via `onPrimary/onSurface` — couleurs du **thème de l'app** (axe indépendant de la pastille) ⇒ en `ThemeData.dark()`, glyphe sombre-sur-pastille-sombre (croix quasi invisible). Corrigé par un helper partagé `_glyphOn(int argb)` : contraste piloté par la **luminosité de la PASTILLE** (`ThemeData.estimateBrightnessForColor`), blanc/noir **dérivés par HSV** (`HSVColor.fromAHSV` — pur-données, respecte la garde FR-26 qui bannit `Colors.`/`Color(0x…)`). Appliqué à `_CheckSwatch` (coche) ET `_RemovableSwatch` (croix). **Rouge-avant prouvé** : sous l'ancien heuristique, tests (f)+(g) échouent (-2).
- **MED-2 (trou de test `_addColor`)** : ajout de 3 tests porteurs actionnant réellement le bouton « ajouter » — (h) seam picker retournant une couleur ⇒ ajoutée à la tranche ; (i) seam retournant une couleur déjà présente ⇒ **dédup** (pas de doublon) ; (j) seam qui **throw** ⇒ **aucune écriture**, aucun crash (AD-10). **Rouge-avant prouvé** : sans le garde `!current.contains(picked)`, (i) échoue ; sans le `try/catch`, (j) échoue.
- **LOW (double annonce du libellé)** : retrait du `label:` sur le `Semantics(container: true)` — le `Text(resolvedLabel)` visible fournit déjà le nom accessible (motif fp-5-1). Test (k) : le libellé apparaît **une seule fois** dans l'arbre sémantique. **Rouge-avant prouvé** : réintroduire `label:` fait échouer (k). *Dette pré-existante signalée (non corrigée) : `z_color_field_widget.dart` mono porte le même motif `Semantics(container:true, label:) + Text`.*
- **RC réels post-correction** : `dart analyze packages/zcrud_core` RC=0 · `flutter test packages/zcrud_core` = **1013 passed** (1007 + 6 nouveaux tests f/g/h/i/j/k) · `graph_proof` CORE OUT=0 / ACYCLIQUE · `style_purity_test` vert (aucun littéral `Colors.`). **API publique inchangée.**

### File List

- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` (UPDATE — `ZColorConfig.multiple` + champ `multiple` + `==`/`hashCode`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_color_multi_field_widget.dart` (NEW — `ZColorMultiFieldWidget` + `_parseArgbList` défensif ; UPDATE code-review : helper `_glyphOn` contraste-pastille MED-1, retrait `label:` conteneur LOW)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (UPDATE — dispatch conditionnel simple/multiple + import)
- `packages/zcrud_core/lib/src/presentation/edition/z_read_only_value.dart` (UPDATE — `_colorValue` multi-pastilles + helper `_colorChip`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (UPDATE — clés `colorAddColor`/`removeColor` en+fr)
- `packages/zcrud_core/lib/zcrud_core.dart` (UPDATE — export du widget multi)
- `packages/zcrud_core/test/domain/edition/z_color_config_multiple_test.dart` (NEW)
- `packages/zcrud_core/test/presentation/edition/color_multiple_test.dart` (NEW ; UPDATE code-review : tests (f)+(g) MED-1 contraste dark-theme, (h)+(i)+(j) MED-2 `_addColor`/dédup/seam-throw, (k) LOW libellé unique)
