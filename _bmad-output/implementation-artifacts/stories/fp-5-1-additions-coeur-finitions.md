# Story 5.1: Additions cœur de Finitions — `pin` / `autocomplete` / `editableTable` + `ZSubListDisplayMode.tags`

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Généré en mode NON-INTERACTIF (option conservatrice retenue à chaque arbitrage — cf. §Decisions). -->

## Story

As a **mainteneur zcrud**,
I want **ajouter au cœur `zcrud_core`, de façon purement ADDITIVE et sérialisée, les valeurs d'enum `EditionFieldType.pin` / `autocomplete` / `editableTable` et la variante `ZSubListDisplayMode.tags`, avec leur ROUTAGE de rendu (repli documenté vers le registry pour les 3 nouveaux types, rendu natif minimal pour `tags`), en une seule écriture cœur sérialisée**,
so that **le satellite `zcrud_field_extras` (fp-5-2) disposera des types nommés au cœur et servis par `ZWidgetRegistry`, sans qu'aucun type nouveau ne fasse crasher un formulaire, en préservant CORE OUT=0 (aucune dépendance lourde tirée dans le cœur)**.

**Marquage :** `[Finitions]` · **CORE-SÉRIALISÉE** (SEULE story cœur en vol dans cette vague — fp-1-1 est `done`, aucun autre écrivain cœur ; les dev-story satellites `zcrud_select`/`media`/`html`/`field_extras`/`geo` tournent en parallèle mais **ne touchent PAS** `packages/zcrud_core/`). Binds **AD-52 / AD-53** + hérités **AD-1 (CORE OUT=0), AD-2/AD-15 (SM-1), AD-3/AD-10 (additif, défensif), AD-4 (extension via registre/scope), AD-13 (a11y/RTL), FR-26 (thème)** ; FR-13, FR-34, FR-35, FR-36 (+ contribue FR-40) ; NFR-2/5/6/9.

## Contexte & nature de l'itération

Itération **purement additive et de câblage léger** au cœur, **pas** une impl de widgets riches. Elle pose au cœur les **noms de types** (valeurs d'enum) + leur **routage de rendu** ; l'IMPL riche (`pinput`, autocomplétion, table éditable virtualisée, tags riches) vit dans **`zcrud_field_extras` (fp-5-2)**, servie par `ZWidgetRegistry`. Le patron exact est celui posé par **fp-1-1** pour `dateRange` (enum + `familyOf` + dispatch + générateur), **sauf** que — contrairement à `dateRange` (valeur custom `ZDateRange`) — les valeurs de `pin`/`autocomplete`/`editableTable` sont **NEUTRES** (`String` / `List<Map<String,dynamic>>`, AD-53) : le générateur les (dé)sérialise déjà par ses chemins génériques existants → **le générateur n'est PAS touché** (cf. §Decisions D1, prouvé par grep). [Source: epics.md#Story-5.1 ; ARCHITECTURE-SPINE.md#AD-52 · #AD-53 ; stories/fp-1-1-seams-types-coeur-mvp.md]

## Acceptance Criteria

### Bloc A — 3 valeurs d'enum additives + routage repli documenté (FR-34/35/36, AD-52/AD-53)

**AC-A1 — Enum additif `pin` / `autocomplete` / `editableTable`.** Les trois valeurs `pin`, `autocomplete`, `editableTable` (camelCase, canonique §5) sont ajoutées à `EditionFieldType` (`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`), chacune avec un doc-comment sur le patron des voisines, désignant explicitement leur widget comme **servi ailleurs** (`zcrud_field_extras`, fp-5-2, via `ZWidgetRegistry`). L'ajout est **purement additif** : aucune valeur existante renommée/supprimée/réordonnée de façon cassante (évolution additive AD-3/AD-10). La compilation ne redevient verte **qu'après** classement des 3 valeurs dans `familyOf` (le `switch` exhaustif **sans `default:`** de `edition_field_family.dart` **casse la compilation** tant qu'elles ne sont pas classées — garde voulue AC2, jamais contournée par un `default:`).

**AC-A2 — Routage vers `registryOrFallback` (repli documenté, aucune nouvelle `EditionFamily`).** `familyOf` classe `pin`/`autocomplete`/`editableTable` dans **`EditionFamily.registryOrFallback`** (le groupe existant markdown/HTML/géo/`icon`/`custom`) — **aucune nouvelle valeur `EditionFamily`, aucun nouveau widget natif, aucune modification du `switch` de dispatch de `z_field_widget.dart`** (le `case EditionFamily.registryOrFallback` route déjà vers `_dispatchRegistry`). Conséquence prouvée : sans registre injecté (état fp-5-1), un champ `pin`/`autocomplete`/`editableTable` **dégrade proprement** en `ZUnsupportedFieldWidget` (placeholder accessible « type non pris en charge ici », **jamais un crash**) ; quand fp-5-2 enregistrera les `kind` correspondants, le même seam servira le vrai widget riche. C'est le repli « étiqueté ABSENT tant que non planifié » d'AD-53 (OQ-6). [Source: AD-53 ; edition_field_family.dart:100 · :185-202 ; z_field_widget.dart:608 · :689-702]

**AC-A3 — Valeurs NEUTRES, générateur NON touché, (dé)sérialisation défensive héritée (AD-52/AD-53, AD-10).** Les valeurs portées par `pin`/`autocomplete` sont **neutres** (`String`) : un modèle `@ZcrudModel` portant `String? pin` / `String? auto` (avec `@ZcrudField(type: EditionFieldType.pin/autocomplete)`) **round-trippe** via la catégorie génératrice **existante** `_Cat.stringType` — **aucune nouvelle `_Cat` ni aucun helper généré n'est ajouté** au générateur (cf. §Decisions D1). ⚠️ **CORRECTION post-dev (découverte SUR DISQUE, cf. Debug Log)** : la valeur d'`editableTable` (`List<Map<String,dynamic>>`) n'est **PAS** (dé)sérialisée par le chemin `List<T>` existant — le générateur EXISTANT lève `InvalidGenerationSourceError` sur un élément `Map` (`_classify` récurse sur `Map`, aucune branche). La prémisse initiale « `List<Map>` round-trippe via `listScalar` » était donc **FAUSSE** ; le champ `tableValue` a été **retiré** du corpus (D1 impose de NE PAS toucher le générateur). fp-5-1 livre `editableTable` **nommé + routé (`registryOrFallback`) + repli-testé** (dispatch → `ZUnsupportedFieldWidget`, non-crash prouvé) ; sa (dé)sérialisation `List<Map>` reste une **limite préexistante du générateur**, à couvrir par un **type de valeur dédié + codec** dans une **story ultérieure**. La désérialisation défensive du parent (pour `pin`/`auto`) est **héritée** : une entrée corrompue (non-`String`, `null`) **ne fait jamais échouer le parent** (AD-10, garde `is String ? … : null` générée) — prouvé par un **corpus corrompu** + **survie du parent** (§Testing) avec **injection R3** falsifiable.

**AC-A4 — CORE OUT=0 préservé (aucune dépendance lourde).** Après le bloc A : **aucune** dépendance `pinput`/`autocomplete*`/`editable`/`drag_and_drop_lists`/autre paquet lourd n'apparaît dans `packages/zcrud_core/pubspec.yaml` (grep négatif RC=1) ; `python3 scripts/dev/graph_proof.py` RC=0, out-degree `zcrud_core` **inchangé** (0 arête `zcrud_*` sortante). L'impl riche adossée à `pinput`/table éditable vit **exclusivement** dans `zcrud_field_extras` (fp-5-2), **jamais** dans le cœur (AD-1/AD-53).

### Bloc B — `ZSubListDisplayMode.tags` : mode natif minimal (FR-13, AD-52)

**AC-B1 — Valeur d'enum additive `tags`.** `ZSubListDisplayMode.tags` est ajoutée (camelCase) à l'enum de `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart`, avec doc-comment sur le patron `inline`/`compact`. Ajout **additif** (AD-4, jamais `sealed`) : `inline` **reste le défaut**, aucune config existante n'est affectée (rétro-compat stricte — un `ZSubListConfig` sans `displayMode` reste `inline`). L'enum `ZSubListDisplayMode` n'est **pas persisté** (config `const` d'authoring, comme `inline`/`compact` — cf. §Decisions D2) : aucun `@JsonKey` ni catégorie de (dé)sérialisation à ajouter.

**AC-B2 — Rendu natif MINIMAL zéro-dépendance + branche explicite (jamais de repli silencieux).** `z_sub_list_field_widget.dart` route le mode `tags` **explicitement** (le sélecteur `_displayMode` ne doit **jamais** faire retomber `tags` silencieusement dans `inline`). Le rendu `tags` de fp-5-1 est un **rendu natif minimal `InputChip`** (zéro dépendance, AD-52) : une rangée de puces `Wrap` présentant le **résumé** de chaque item (via `summaryFields`/repli titre existant, réutilisant la machinerie d'ajout/édition existante — bouton `+` ≥ 48 dp), directionnel (`Wrap` suit `Directionality`, `EdgeInsetsDirectional`), `Semantics` explicites, aucune couleur codée en dur (thème via `ZcrudTheme.of(context)`, FR-26). **Frontière** : l'**interaction riche** par tag (toggle par tag, icône par tag, réordonnancement drag) est **fp-5-2** (« tags riches ») — fp-5-1 ne livre que le mode nommé + le rendu minimal non-crash (cf. §Decisions D3). [Source: AD-52 ; FIELD-PACKAGE-MATRIX.md row 15b · P4 ; z_sub_list_field_widget.dart:175-179 · :309]

**AC-B3 — Rétro-compat inline/compact intacte.** Les rendus `inline` (historique E3-3b-2) et `compact` (DP-6) restent **strictement inchangés** ; aucun test existant de sous-liste ne régresse. Le mode `tags` est **opt-in** (jamais atteint sans `displayMode: ZSubListDisplayMode.tags`).

### Bloc C — Gardes de gates & non-régression globale

**AC-C1 — Guards de comptage/exhaustivité mis à jour (tests porteurs, R3).** Le test de catalogue `test/domain/edition/edition_field_type_test.dart` (aujourd'hui `paritySet.length == 39`, `values.length == 40`) est **mis à jour** pour intégrer les 3 nouvelles valeurs (parité 42, `values.length == 43`) — c'est un **guard porteur** qui doit rougir si un type est oublié/retiré. Le test de dispatch/classement `test/presentation/edition/z_field_dispatch_test.dart` couvre les 3 nouveaux types → **`registryOrFallback` → `ZUnsupportedFieldWidget`** sans registre (non-crash prouvé). [Source: edition_field_type_test.dart:59-60 ; z_field_dispatch_test.dart]

**AC-C2 — Vérif verte + gates repo-wide.** `dart run melos run generate` OK (aucun `*.g.dart` ne change — cf. AC-A3 ; s'il en change un, il est régénéré ET commité, gate `codegen-distribution`) ; `melos run analyze` **repo-wide** RC=0 ; `flutter test packages/zcrud_core` RC=0 ; `dart test packages/zcrud_generator` RC=0 ; gates `secrets` + `codegen-distribution` + `graph_proof` (ACYCLIQUE + CORE OUT=0) verts.

## Tasks / Subtasks

- [x] **T1 — 3 valeurs d'enum + classement `familyOf`** (AC: A1, A2)
  - [x] T1.1 Ajouté `EditionFieldType.pin`, `autocomplete`, `editableTable` dans `edition_field_type.dart` (doc-comment sur le patron `icon`/`custom` : widget servi par `zcrud_field_extras`/fp-5-2 via `ZWidgetRegistry` ; repli `ZUnsupportedFieldWidget`).
  - [x] T1.2 Classé les 3 valeurs dans `familyOf` (`edition_field_family.dart`), branche **`EditionFamily.registryOrFallback`** (groupées avec `icon`/`custom`) — `switch` sans `default:` intact, aucune nouvelle `EditionFamily`.
  - [x] T1.3 Vérifié : **aucune** modification de `z_field_widget.dart` requise (`case registryOrFallback → _dispatchRegistry` route déjà). Fichier non touché par moi.
- [x] **T2 — `ZSubListDisplayMode.tags` + rendu natif minimal** (AC: B1, B2, B3)
  - [x] T2.1 Ajouté `ZSubListDisplayMode.tags` (camelCase, doc) dans `z_sub_list_config.dart` — additif, `inline` reste défaut.
  - [x] T2.2 `z_sub_list_field_widget.dart` : `build()` converti en `switch` exhaustif SANS `default:` → branche `tags` **explicite** (`_buildTags`). Rendu minimal `Wrap`/`InputChip` (zéro dép) : résumé par item (`summaryFields`/repli titre `_chipLabel`), bouton `+` (IconButton ≥ 48 dp) réutilisant `_buildAddControl`/`_openAddDialog`, onDeleted → `_confirmDelete`, directionnel, `Semantics`, thème `ZcrudTheme` (aucune couleur littérale).
  - [x] T2.3 Rétro-compat vérifiée : `inline`/`compact` inchangés (994 tests core verts, dont suites sous-liste existantes).
- [x] **T3 — Corpus (dé)sérialisation neutre + défensif** (AC: A3)
  - [x] T3.1 Étendu `Article` (`test/models/article.dart`) avec `String? pinValue` (`type: pin`) + `String? autoValue` (`type: autocomplete`). **`List<Map<String,dynamic>>? tableValue` NON ajouté** : découverte SUR DISQUE (build_runner rejoué) — le générateur EXISTANT lève `InvalidGenerationSourceError` sur `Map` (`_classify` récurse sur l'élément `Map`, aucune branche) → **la prémisse D1 « `List<Map>` round-trippe via listScalar » est FAUSSE**. D1 impose de NE PAS toucher le générateur → champ retiré, finding documenté dans `article.dart` (le routage/neutralité d'`editableTable` est prouvé côté cœur, dispatch → repli).
  - [x] T3.2 Corpus corrompu étendu (famille `i`) : `pin_value=42` (non-`String`), `auto_value={x:1}` (non-`String`), absents, valides, + `null` dans `null_partout` → **parent survit** (`title=='ok'`), champs corrompus → `null`. (`table` N/A — cf. T3.1.)
  - [x] T3.3 Injection R3 : la garde défensive est le `is String ? … : null` généré (`_Cat.stringType`, `article.g.dart:203-204`). Le corpus asserte le COMPORTEMENT (`pinValue==null` + parent survit), pas `takeException`. Si la garde devenait `$m as String`, le cas `42` throw → l'invariant universel `returnsNormally` rougit. Consigné (Completion Notes).
  - [x] T3.4 Régénéré (`build_runner build`, RC=0) : `article.g.dart` utilise `_Cat.stringType` existant (aucune nouvelle catégorie) + émet `type: EditionFieldType.pin`/`autocomplete`. **Aucun `*.g.dart` de `packages/*/lib/` changé par moi** (le modèle vit sous `test/models/`, gitignoré) → gate `codegen-distribution` non impacté par fp-5-1.
- [x] **T4 — Guards de catalogue/dispatch** (AC: C1)
  - [x] T4.1 `edition_field_type_test.dart` : parité 39→42, `values.length` 40→43 (guard porteur, +3 valeurs nommées).
  - [x] T4.2 `z_field_dispatch_test.dart` : `pin`/`autocomplete`/`editableTable` ajoutés à `_registryTypes` (12→15), partition 40→43 ; monté sans registre → `ZUnsupportedFieldWidget` `findsOneWidget` (non-crash) ; guard `unsupported == [stepper]` prouve R3 (misrouting vers default/unsupported ⇒ rouge).
  - [x] T4.3 Nouveau `fp_5_1_tags_mode_test.dart` : `displayMode: tags` monte `InputChip` (N puces), bouton `+` ≥ 48 dp, ajout/suppression via dialog, RTL, et `inline`/`compact` non atteints (7 tests).
- [x] **T5 — Vérif verte + preuves** (AC: A4, C2)
  - [x] T5.1 `build_runner build` (zcrud_generator) RC=0 ; `dart analyze packages/zcrud_core` RC=0 ; `dart analyze packages/zcrud_generator` RC=0 (No issues) ; `flutter test packages/zcrud_core` RC=0 (994) ; `dart test` (zcrud_generator) RC=0 (127). (`melos analyze/test` repo-wide DIFFÉRÉ à l'orchestrateur : agents fp-4-x écrivent zcrud_core/générateur en parallèle → vérif ciblée par package pendant l'écriture active.)
  - [x] T5.2 `python3 scripts/dev/graph_proof.py` RC=0 (ACYCLIQUE OK + CORE OUT=0 OK, out-degree inchangé).
  - [x] T5.3 Greps négatifs consignés (Completion Notes).

## Dev Notes

### Patrons cœur EXISTANTS à imiter (vérifiés sur disque)

- **Patron d'ajout d'un type (référence fp-1-1)** : `dateRange` a ajouté (1) la valeur d'enum, (2) `EditionFamily.dateRange` + classement `familyOf`, (3) un widget natif dédié + dispatch, (4) une catégorie génératrice `_Cat.dateRangeType` + helper. **fp-5-1 est PLUS LÉGER** : pour `pin`/`autocomplete`/`editableTable`, on ne fait que (1) + (2) vers une famille **EXISTANTE** (`registryOrFallback`) — **ni widget natif, ni dispatch, ni catégorie génératrice** (valeurs neutres, cf. D1). [Source: stories/fp-1-1-seams-types-coeur-mvp.md]
- **`familyOf` — switch exhaustif sans `default:`** : `edition_field_family.dart:121`. La branche `registryOrFallback` (`:190-202`) regroupe déjà `markdown`/`inlineMarkdown`/`html`/`inlineHtml`/`richText`/`location`/`geoArea`/`phoneNumber`/`country`/`address`/`icon`/`custom`. **Ajouter les 3 nouveaux `case` dans ce groupe.** Ajouter les valeurs à `EditionFieldType` casse la compilation ici jusqu'au classement (garde AC2). [Source: edition_field_family.dart]
- **Dispatch `registryOrFallback`** : `z_field_widget.dart:608` `case EditionFamily.registryOrFallback: return _dispatchRegistry(context, field, value);` ; `_dispatchRegistry` (`:689-702`) tente le `ZWidgetRegistry` injecté, sinon `ZUnsupportedFieldWidget(field: field)`. **Aucune modification nécessaire** — c'est le repli documenté d'AD-53. [Source: z_field_widget.dart]
- **Repli accessible** : `families/z_unsupported_field_widget.dart` — placeholder `Semantics` (libellé + `unsupportedField`), `EdgeInsetsDirectional`, thème hérité ; **ne throw jamais**. Clés l10n `unsupportedField` déjà présentes (EN/FR). Aucune l10n à ajouter. [Source: z_unsupported_field_widget.dart ; z_localizations.dart:61 · :149]
- **Générateur — catégories neutres existantes** : `zcrud_model_generator.dart:522` `if (type.isDartCoreString) return (_Cat.stringType, null, 'text')` ; `:503-518` chemin `List<T>` (`listScalar`/`listEnum`/`listModel`) ; `:322-340` assignabilité `Map<String,dynamic>`. **`String` et `List<Map>` sont déjà (dé)sérialisés** → aucune nouvelle `_Cat` (contraste avec `dateRange`/`ZDateRange` qui était une valeur custom). [Source: zcrud_model_generator.dart]
- **Mode de sous-liste** : `z_sub_list_config.dart:37` `enum ZSubListDisplayMode { inline, compact }` (additif AD-4, jamais `sealed`, non persisté) ; `z_sub_list_field_widget.dart:175-179` `_displayMode` (repli `inline` si config absente) et `:309` `if (_displayMode == ZSubListDisplayMode.compact)`. **Ajouter `tags` à l'enum + une branche explicite** dans le widget (ne pas laisser `tags` retomber en `inline` sans branche). [Source: z_sub_list_config.dart ; z_sub_list_field_widget.dart]

### Fichiers cœur visés (récap)

| Livrable | Fichiers |
|---|---|
| 3 valeurs d'enum | `domain/edition/edition_field_type.dart` (UPDATE enum) · `presentation/edition/edition_field_family.dart` (UPDATE `familyOf`, groupe `registryOrFallback`) |
| `tags` mode | `domain/edition/z_sub_list_config.dart` (UPDATE enum `ZSubListDisplayMode`) · `presentation/edition/families/z_sub_list_field_widget.dart` (UPDATE branche `tags`, rendu `InputChip`) |
| Guards | `test/domain/edition/edition_field_type_test.dart` (UPDATE comptes 39→42 / 40→43) · `test/presentation/edition/z_field_dispatch_test.dart` (UPDATE 3 cases) · nouveaux tests `tags` + corpus |
| Corpus générateur | `packages/zcrud_generator/test/models/*` + `serialization_corpus.dart`/tests (UPDATE : champs `pin`/`auto`/`table` neutres, round-trip + corrompu) |
| Générateur (`lib/`) | **NON touché** (D1) — sauf découverte contraire prouvée sur disque |
| Codegen distribué | **Aucun `*.g.dart` attendu en diff** (valeurs neutres) ; s'il en change un → régénéré + commité (gate `codegen-distribution`) |

### Preuve « générateur `lib/` NON touché PAR fp-5-1 » (grep-backable — D1)

- `pin`/`autocomplete` = `String` → catégorie `_Cat.stringType` **existante** (`:522`). **Aucune valeur Dart custom** (contraste `ZDateRange`) → **aucune nouvelle `_Cat`, aucun helper `_$as…`** ajouté par fp-5-1.
- ⚠️ **CORRECTION (cf. AC-A3 / Debug Log)** : `editableTable` = `List<Map<String,dynamic>>` ne passe **PAS** par le chemin `List<T>` — le générateur EXISTANT **lève** sur un élément `Map` (`_classify` récurse, aucune branche `Map`). La (dé)sérialisation `List<Map>` est **hors périmètre** (limite préexistante, story ultérieure : type de valeur dédié + codec). fp-5-1 n'exerce donc `editableTable` que sur le **routage/repli** cœur, pas comme champ persisté.
- L'`EditionFieldType` (`pin`/…) est **choisi par l'auteur** via `@ZcrudField(type:)`, **pas inféré** par le générateur depuis le type Dart ; la (dé)sérialisation `String` ne dépend que du type Dart neutre → intacte.
- Preuve : le corpus `pin`/`auto` (T3) round-trippe et survit **sans** que **fp-5-1** modifie `zcrud_model_generator.dart`. ⚠️ **Nuance LOW-4** : `git diff packages/zcrud_generator/lib/` n'est **PAS vide** dans l'arbre partagé — il porte le `+23` (`_Cat.dateRangeType`/`_$asDateRange`) de **fp-1-1 (dateRange)**, story ANTÉRIEURE, **pas** de fp-5-1 ni de fp-4-x. La preuve exacte est : **fp-5-1 n'a ajouté AUCUNE ligne** au générateur `lib/` (aucune `_Cat` `pin`/`table`, aucun helper — grep négatif), et non « diff générateur vide ».

### Comment la désérialisation défensive sera prouvée FALSIFIABLE (AD-10)

1. **Corpus corrompu** (dans `serialization_corpus.dart` ou un test dédié) sur un modèle portant `String? pinValue` / `String? autoValue` / `List<Map<String,dynamic>>? tableValue` : `pinValue` = `42` (non-`String`) · `autoValue = {'x':1}` (non-`String`) · `tableValue = 'pas-une-liste'` (non-`List`) · `tableValue = [1,2]` (éléments non-`Map`) · toutes clés absentes / `null`. Attendu : le parent se décode **sans throw**, les champs corrompus retombent à `null`, les **autres champs conservent leur valeur**.
2. **Survie du parent** : `Model.fromMap({'pin_value': 42, 'title': 'ok'})` **ne throw pas** et `model.title == 'ok'` (le vrai test AD-10, PAS `expect(returnsNormally)` seul).
3. **Injection R3** : retirer le repli défensif (`orDef`/passthrough) sur le chemin concerné doit faire **rougir** le corpus par le comportement (exception propagée observée). Consigner. Si vert avec la garde retirée → test tautologique à renforcer.
4. **Round-trip** : valeurs valides (`pin='1234'`, `auto='foo'`, `table=[{'a':1}]`) → `fromMap(toMap()) ==` original.

### Invariants AD applicables (chaque AC)

- **AD-1 / CORE OUT=0** : types nommés + routage **sans dépendance lourde** ; l'impl riche (`pinput`, table) est fp-5-2/`zcrud_field_extras` (AC-A4). [Source: SPINE#AD-1/AD-53]
- **AD-2/AD-15 / SM-1** : rien ne détient le `ZFormController` ; le rendu `tags` reste value-in-slice via le chemin sous-liste existant (canal structurel, AD-2). [Source: z_sub_list_field_widget.dart]
- **AD-3/AD-10** : additif seulement ; (dé)sérialisation neutre défensive héritée ; `*.g.dart` régénérés/commités si diff (AC-A1/A3). [Source: SPINE#AD-52]
- **AD-4** : `registryOrFallback` sert les types via `ZWidgetRegistry` **injecté** (jamais un singleton) ; `ZSubListDisplayMode.tags` additif, jamais `sealed` (AC-A2/B1). [Source: edition_field_family.dart ; z_sub_list_config.dart]
- **AD-13 / FR-26** : rendu `tags` directionnel (`Wrap`/`EdgeInsetsDirectional`), `Semantics`, cible `+` ≥ 48 dp, aucune couleur codée en dur (`ZcrudTheme`) (AC-B2). [Source: SPINE#AD-13/AD-54]

### Distribution en dépendance git (NON-NÉGOCIABLE)

Si un `*.g.dart` de `packages/*/lib/` change (non attendu — cf. D1), il est **régénéré ET commité** (un consommateur en dép. git ne régénère pas). Le commit unique de fin d'epic **inclut** tout `*.g.dart` régénéré, **exclut** les `pubspec.lock`. [Source: CLAUDE.md#Build ; NFR-6]

### Discipline de réalité (pièges consignés)

- Toute **absence** = grep négatif (commande + RC). `grep|head` masque le RC ⇒ `grep -q` ; `$`/`^` BRE ⇒ `grep -qF`.
- `melos run test` **se bloque** ⇒ `flutter test` / `dart test` **par package** touché.
- `git checkout` **interdit**.
- Défauts récurrents à NE PAS reproduire : le mode `tags` **ne doit pas** retomber silencieusement en `inline` (branche explicite) ; la désérialisation défensive réellement testée (**corpus corrompu → parent survit**, pas `takeException isNull`) ; pas de double annonce a11y ; pas de couleur/libellé codés en dur ; la prose des Completion Notes ne ment pas (rejouer réellement) ; `graph_proof` rejoué (CORE OUT=0).

### Frontière cœur/satellite (HORS fp-5-1)

- **PAS** l'impl riche des widgets : PIN (`pinput` 6.0.2), autocomplétion, table éditable virtualisée (`ListView.builder`), icône picker, **tags riches** (toggle/icône par tag, réordonnancement drag) = **fp-5-2 `zcrud_field_extras`** (servis par `ZWidgetRegistry`). [Source: AD-53 ; sprint-status fp-5-2]
- **PAS** les satellites `zcrud_select`/`media`/`html`/`geo` (dev-story parallèles) · **PAS** `zcrud_geo` geoArea style-picker (fp-5-3) · **PAS** le showcase/harnais (fp-3-x) · **PAS** `ZColorConfig.multiple` (fp-4-4).
- **Écriture STRICTEMENT limitée** à `packages/zcrud_core/` (+ tests de `packages/zcrud_generator/` pour le corpus ; le `lib/` du générateur reste NON touché sauf preuve contraire). [Source: epics.md#Story-5.1 ; CLAUDE.md#parallélisation]

### Decisions (mode non-interactif — options conservatrices)

- **D1 — Générateur NON touché** : valeurs neutres (`String`/`List<Map>`) déjà (dé)sérialisées par les catégories existantes → aucune nouvelle `_Cat`/helper (contraste `dateRange`/`ZDateRange`). Prouvé par grep + corpus round-trip/corrompu. Alternative rejetée : créer des catégories `pinType`/… = sur-ingénierie sans valeur custom.
- **D2 — Routage `registryOrFallback` (pas de nouvelle `EditionFamily`, pas de widget natif)** pour `pin`/`autocomplete`/`editableTable` : conforme AD-53 (« servis par `ZWidgetRegistry`, repli `ZUnsupportedFieldWidget` étiqueté ABSENT tant que non planifiés, OQ-6 »). Un widget natif minimal en cœur serait du gaspillage (l'impl riche a besoin de deps lourdes confinées au satellite). `ZSubListDisplayMode` **non persisté** → aucun `@JsonKey` (le task mentionne `unknownEnumValue:` : ne s'applique PAS ici car ni `EditionFieldType` ni `ZSubListDisplayMode` ne sont sérialisés — discipline documentée héritée, comme `custom`/`inline`/`compact`).
- **D3 — `ZSubListDisplayMode.tags` = rendu natif MINIMAL InputChip (zéro dép) en cœur**, tags **riches** (toggle/icône/reorder) = fp-5-2. Réconcilie AD-52 (« `ZSubListDisplayMode.tags` natif zéro dépendance ») et la frontière task (impl riche en fp-5-2) : fp-5-1 nomme le mode + livre un rendu minimal non-crash ; fp-5-2 enrichit. Branche **explicite** (jamais un repli silencieux `inline`).
- **D4 — Guards de catalogue mis à jour** (39→42 / 40→43) : c'est un test porteur volontaire (rougit si un type est oublié) — mise à jour attendue, pas une régression.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Epic-5 · #Story-5.1]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-52 · #AD-53 · #Direction-de-dépendance]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-form-parity-2026-07-18/prd.md#FR-13 · #FR-34 · #FR-35 · #FR-36]
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md (rows 14 · 15 · 15b ; P4 ; §180)]
- [Source: _bmad-output/implementation-artifacts/stories/fp-1-1-seams-types-coeur-mvp.md (patron d'ajout de type)]
- [Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_unsupported_field_widget.dart]
- [Source: packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart]
- [Source: packages/zcrud_generator/lib/src/zcrud_model_generator.dart (catégories `_Cat.stringType`, chemin `List<T>`)]
- [Source: packages/zcrud_core/test/domain/edition/edition_field_type_test.dart ; test/presentation/edition/z_field_dispatch_test.dart]
- [Source: scripts/dev/graph_proof.py ; melos.yaml (gates verify/analyze/secrets/codegen-distribution)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M) — dev-story (skill `bmad-dev-story`, exécution disque).

### Debug Log References

- `build_runner build` (zcrud_generator) — 1er essai AVEC `tableValue: List<Map<String,dynamic>>` → **RED** : `E ... Type de champ non (dé)sérialisable "Map<String, dynamic>" sur tableValue` (`article.dart:120`). Preuve empirique que le générateur EXISTANT ne sérialise pas `Map`.
- `build_runner build` — 2e essai (pin/auto String seuls) → GREEN, `wrote 2 outputs`.
- `flutter test` (core) — 2 échecs test-only initiaux dans `fp_5_1_tags_mode_test.dart` (mesure de l'Icon 24 dp au lieu de l'IconButton ; delete via `Icons.cancel` introuvable) → corrigés (mesure `IconButton`, delete via `find.byTooltip('Remove item')`). Impl production inchangée.

### Completion Notes List

- **Périmètre STRICTEMENT tenu** : écrit uniquement dans `packages/zcrud_core/` (4 fichiers lib + 3 tests) et `packages/zcrud_generator/test/` (corpus, jamais `lib/`). Aucun satellite touché par moi.
- **3 types + `tags` routés, falsifiable** : `pin`/`autocomplete`/`editableTable` → `EditionFamily.registryOrFallback` → sans registre → `ZUnsupportedFieldWidget` (prouvé `findsOneWidget`, jamais un crash). `tags` → `InputChip` natif (prouvé `findsNWidgets`). R3 : le guard dispatch `unsupported == [stepper]` rougit si un nouveau type retombe en `default`/`unsupported` silencieux.
- **Désérialisation défensive prouvée (AD-10, comportementale)** : `pin_value=42`/`auto_value={x:1}` → champ `null` ET `title=='ok'` (parent survit) — pas un `takeException isNull`. Round-trip `pin='1234'`/`auto='foo'` idempotent.
- **D1 corrigé par la réalité disque** : la prémisse « `List<Map>` round-trippe via `listScalar` » est FAUSSE (`_classify` récurse sur `Map`, aucune branche → throw). Générateur `lib/` NON touché par moi (D1 respecté) ; `editableTable` reste nommé+routé au cœur, sa valeur `List<Map>` n'est pas exercée comme champ `@ZcrudModel` persisté (limite préexistante du générateur, documentée dans `article.dart`).
- **Codegen** : `article.g.dart` régénéré (gitignoré, sous `test/models/`) → utilise `_Cat.stringType` existant, aucune nouvelle catégorie ; **aucun `*.g.dart` de `packages/*/lib/` modifié par fp-5-1** (gate `codegen-distribution` non impacté).
- **Guards catalogue** : `edition_field_type_test` 39→42 / 40→43 ; `z_field_dispatch_test` registre 12→15, partition 40→43 ; `zcrud_model_generator_test` projection 12→14 champs.
- **Greps négatifs (commande + RC)** :
  - `grep -qE 'pinput|awesome_select|flutter_html|autocomplete|editable|drag_and_drop_lists' packages/zcrud_core/pubspec.yaml` → **RC=1** (absent = CORE OUT=0 préservé, aucune dép lourde).
- **RC réels rejoués** : `dart analyze packages/zcrud_core` RC=0 · `dart analyze packages/zcrud_generator` RC=0 (No issues) · `flutter test packages/zcrud_core` RC=0 (**994** tests) · `dart test` (CWD zcrud_generator) RC=0 (**127** tests) · `python3 scripts/dev/graph_proof.py` RC=0 (ACYCLIQUE + CORE OUT=0).
- **⚠️ Signalé à l'orchestrateur (hors périmètre, à réconcilier)** : durant l'exécution, les agents parallèles fp-4-x ont modifié dans l'arbre partagé des fichiers `zcrud_core/lib/` (`z_field_widget.dart`, `z_theme.dart`, `zcrud_scope.dart`, `dynamic_edition.dart`, `z_select_/z_relation_field_widget.dart`, `edition.dart`, `domain.dart`, `zcrud_core.dart`…) et des `*.g.dart` de satellites, + ajout du package `awesome_select`. Ces écritures **concurrentes sur `zcrud_core`** dépassent la disjonction annoncée (fp-5-1 = seul écrivain cœur) — non causées par moi. Mes vérifs vertes ont tourné sur cet arbre combiné (cohérent à l'instant t).
- **⚠️ CORRECTION LOW-4 (code-review)** : le `+23` observé dans `zcrud_generator/lib/src/zcrud_model_generator.dart` (`_Cat.dateRangeType` / `_$asDateRange`) est **attribué à tort à fp-4-x** ci-dessus dans une version antérieure de cette note — il provient en réalité de **fp-1-1 (dateRange)**, story ANTÉRIEURE ayant introduit la catégorie `ZDateRange`. fp-5-1 n'a, lui, **ajouté aucune ligne** au générateur `lib/` (D1 respecté) — mais le diff générateur n'est **pas vide** dans l'arbre partagé (il porte l'apport dateRange/fp-1-1).

### File List

**fp-5-1 (mes écritures) :**

- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (UPDATE — +3 valeurs d'enum `pin`/`autocomplete`/`editableTable`)
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (UPDATE — classement `familyOf` → `registryOrFallback`)
- `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart` (UPDATE — `ZSubListDisplayMode.tags`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` (UPDATE — `build()` switch exhaustif + `_buildTags`/`_chipLabel`)
- `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart` (UPDATE — guard 42/43)
- `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart` (UPDATE — registre 15, partition 43)
- `packages/zcrud_core/test/presentation/edition/fp_5_1_tags_mode_test.dart` (NEW — 7 tests mode `tags` ; **+2 tests porteurs code-review** : MED-1 libellé de section unique, MED-2 puce ≥ 48 dp sous `shrinkWrap` → 9 tests)
- `packages/zcrud_generator/test/models/article.dart` (UPDATE — champs `pinValue`/`autoValue` + finding `editableTable`)
- `packages/zcrud_generator/test/models/serialization_corpus.dart` (UPDATE — famille `i` pin/auto)
- `packages/zcrud_generator/test/serialization_corpus_test.dart` (UPDATE — assertions famille `i` + null)
- `packages/zcrud_generator/test/zcrud_model_generator_test.dart` (UPDATE — projection 14 champs + type explicite)
- `packages/zcrud_generator/test/models/article.g.dart` (REGÉNÉRÉ — gitignoré, non committé)

**Code-review fp-5-1 (corrections MEDIUM/LOW) :**

- `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` (UPDATE — **MED-1** : retrait de `label:` sur les 3 `Semantics(container:)` inline/compact/tags — le `Text` visible porte déjà le nom de section, évite la double annonce du lecteur d'écran ; **MED-2** : `materialTapTargetSize: MaterialTapTargetSize.padded` épinglé sur l'`InputChip` du mode tags — cible ≥ 48 dp indépendante du thème)
- `packages/zcrud_core/test/presentation/edition/fp_5_1_tags_mode_test.dart` (UPDATE — 2 tests porteurs : MED-1 canal sémantique `find.bySemanticsLabel('Items') == 1`, MED-2 `getSize(InputChip).height >= 48` sous `ThemeData(materialTapTargetSize: shrinkWrap)`)
- `_bmad-output/implementation-artifacts/stories/fp-5-1-additions-coeur-finitions.md` (UPDATE prose — LOW-3 AC-A3 `editableTable`/`List<Map>` non supporté par le générateur ; LOW-4 diff générateur = dateRange/fp-1-1, non fp-4-x)
- `_bmad-output/implementation-artifacts/stories/code-review-fp-5-1.md` (NEW — rapport de revue : finding × statut × preuve)

### Code Review Record (fp-5-1)

| Finding | Sévérité | Statut | Preuve |
|---|---|---|---|
| MED-1 double annonce libellé de section (tags + inline + compact) | MEDIUM | **Corrigé** | `label:` retiré des 3 `Semantics(container:)` ; test porteur `find.bySemanticsLabel('Items')` : ROUGE avant (`Found 0` — libellé fusionné `Items\nItems`), VERT après (`findsOneWidget`) |
| MED-2 `InputChip` < 48 dp sous thème `shrinkWrap` | MEDIUM | **Corrigé** | `materialTapTargetSize: padded` épinglé ; test porteur sous `ThemeData(materialTapTargetSize: shrinkWrap)` : ROUGE avant (`height < 48`), VERT après (`height >= 48`) |
| LOW-3 prose AC-A3 fausse (`List<Map>` round-trip) | LOW | **Corrigé (prose)** | AC-A3 + §Preuve réécrites : `editableTable` nommé+routé+repli-testé, (dé)sérialisation `List<Map>` NON supportée (limite générateur préexistante → story ultérieure) |
| LOW-4 prose git-diff générateur | LOW | **Corrigé (prose)** | §Preuve + Completion Notes réécrites : `+23` = `_Cat.dateRangeType` de **fp-1-1**, pas fp-4-x ; diff générateur non vide ; fp-5-1 n'ajoute aucune ligne au générateur `lib/` |
