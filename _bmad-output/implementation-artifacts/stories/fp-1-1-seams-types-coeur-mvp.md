# Story 1.1: Seams & types cœur MVP — `dateRange`, tokens d'aération, `ZSelectPresenter`

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Généré en mode NON-INTERACTIF (option conservatrice retenue à chaque arbitrage — cf. §Decisions). -->

## Story

As a **mainteneur zcrud**,
I want **ajouter au cœur `zcrud_core` le type de champ `dateRange` (valeur `ZDateRange`), les tokens d'aération `ZcrudTheme` et le seam `ZSelectPresenter`, en une seule écriture cœur sérialisée**,
so that **tous les adaptateurs MVP et Média-rich disposent du substrat cœur (type + tokens + abstraction de sélection) sans se marcher dessus, en préservant CORE OUT=0**.

**Marquage :** `[MVP]` · **CORE-SÉRIALISÉE** (regroupe 3 écritures cœur — **une seule story touche `zcrud_core` à la fois** ; aucune autre story en vol ne doit écrire le cœur pendant fp-1-1). Binds **AD-47 / AD-48 / AD-54** + hérités **AD-1, AD-2/AD-15, AD-3/AD-10, AD-4, AD-6, AD-8, AD-13, FR-26** ; FR-5, FR-38 ; NFR-1/2/3/4/5/6.

## Acceptance Criteria

### Bloc A — `dateRange` natif au cœur (FR-5, AD-47)

**AC-A1 — Enum additif.** `EditionFieldType.dateRange` est ajouté (camelCase, **près de `dateTime`/`time`**) dans `edition_field_type.dart`. L'ajout est **purement additif** (aucune valeur existante renommée/supprimée/réordonnée de façon cassante — évolution additive AD-3/AD-10). La compilation reste verte **après** avoir classé la nouvelle valeur dans `familyOf` (le `switch` exhaustif sans `default:` de `edition_field_family.dart` **casse la compilation** tant que `dateRange` n'est pas classé — garde voulue, à satisfaire, jamais contournée par un `default:`).

**AC-A2 — Valeur `ZDateRange` domaine-pur, ISO-8601, invariant `end >= start`.** Un type de valeur `ZDateRange{ DateTime start, DateTime end }` vit dans `lib/src/domain/edition/` (pur-Dart, **aucun** import Flutter/Material — garde `domain_purity_test.dart`). Il sérialise en **ISO-8601** (`start`/`end` en `toIso8601String()`), valide l'invariant **`end >= start`** (une plage `start > end` n'est jamais construite/retournée valide — soit rejetée en `null` à la désérialisation, soit normalisée de façon documentée et déterministe ; l'option retenue est **rejet → `null`**, cf. §Decisions D1).

**AC-A3 — Désérialisation DÉFENSIVE (AD-10) — falsifiable.** `ZDateRange.fromJsonSafe(Object? json)` ne **throw JAMAIS** : entrée `null`, non-map, clés absentes, valeurs non-`String`, dates non-ISO, ou `start > end` → **`null`** (repli sûr). Un **modèle parent** portant un champ `ZDateRange?` **survit** à une entrée corrompue (parse du parent ne throw pas ; les autres champs conservent leurs valeurs). Prouvé par un **corpus corrompu** (≥ 6 entrées listées en §Testing), avec **injection R3** : retirer la garde (`fromJsonSafe` re-throw / `fromJson` brut) doit faire **rougir** le test par le comportement (parent throw / exception observée), pas seulement `takeException isNull`.

**AC-A4 — Widget natif `ZDateRangeFieldWidget` sous `ZFieldListenableBuilder`, `showDateRangePicker`, CORE OUT=0.** Une **famille de widget native** `z_date_range_field_widget.dart` (patron **strict** de `z_date_field_widget.dart`) est montée par le dispatcher (`z_field_widget.dart`) via le même chemin `ZFieldListenableBuilder` que les autres familles (rebuild granulaire par tranche, SM-1 ; **aucun** `TextEditingController` ; `StatelessWidget` pur ne recevant **jamais** le `ZFormController`). Elle ouvre **`showDateRangePicker`** (primitive Material — directionnelle par construction, AD-13), déclencheur ≥ 48 dp, `Semantics` bouton + libellé + valeur, croix d'effacement optionnelle (patron MIN-2 de la famille date). **Aucune** dépendance `table_calendar`/`date_time_picker`/autre paquet lourd : **CORE OUT=0** préservé, prouvé par grep négatif sur `packages/zcrud_core/pubspec.yaml` **et** `python3 scripts/dev/graph_proof.py` (RC=0, out-degree `zcrud_core` inchangé).

**AC-A5 — Génération `ZFieldSpec` + (dé)sérialisation + rétro-compat.** `zcrud_generator` reconnaît un champ de type `ZDateRange` (nouvelle catégorie de (dé)sérialisation, patron de `_Cat.dateTimeType`) : il **infère `EditionFieldType.dateRange`**, émet le `ZFieldSpec`, et produit un `fromMap`/`toMap` **défensif** (`fromMap` via un helper `_$asDateRange(...)` bâti sur `ZDateRange.fromJsonSafe` → jamais de throw ; `toMap` via `.toJson()`, `null` toléré si le champ est optionnel). Les `*.g.dart` de `packages/*/lib/` sont **régénérés ET commités** (distribution en dép. git — gate `codegen-distribution`). Le **test de rétro-compat de sérialisation** (`serialization_corpus`) reste **vert** et couvre le nouveau type.

### Bloc B — Tokens d'aération `ZcrudTheme` + 3 écarts tranchés (FR-38, AD-54)

**AC-B1 — Écart #1 : gouttière asymétrique → `ZResponsiveGrid.runGutter` additif.** `ZResponsiveGrid` reçoit un paramètre **optionnel additif** `double? runGutter` (défaut `null`) posé en `Wrap.runSpacing` **replié sur `gutter` si `null`** (API **non-cassante** : un appel existant sans `runGutter` conserve le comportement symétrique exact). Le binding pourra poser `gutter: 16, runGutter: 8` (parité DODLP `horizontalSpacing:16 / verticalSpacing:8`). Directionnel (mesures dp, `Wrap` suit `Directionality`).

**AC-B2 — Écart #2 : spacer inter-champ conservé.** Le spacer inter-champ **reste** `zFieldGapAfter()` (projection existante « espace les blocs ») ; **aucun** changement de sémantique. Le paramètre `DynamicEdition.interFieldGap` existe déjà (défaut `0`, rétro-compat stricte) ; la story **ne le modifie pas** — c'est le binding (fp-2-x) qui posera `interFieldGap: 12`. La divergence d'ordre en séquence mixte compact↔bloc est **assumée** (parité fonctionnelle, pas pixel — §4.2 de l'étude aération).

**AC-B3 — Écart #3 : `ZcrudTheme.formPadding` consommé par `DynamicEdition`.** Un token **directionnel** `ZcrudTheme.formPadding` (type `EdgeInsetsDirectional`, **défaut `EdgeInsetsDirectional.all(12)`** — parité DODLP) est ajouté à `z_theme.dart` (avec `copyWith`/`lerp`/doc, sur le patron des tokens existants `fieldPadding`/`readPadding`). `DynamicEdition` le **consomme quand `padding == null`** (aujourd'hui `padding` nullable sans défaut → aucun repli). Le repli est `ZcrudTheme.of(context).formPadding` (jamais une constante littérale). **Aucune couleur** ajoutée ; **aucune `Color(0xFF…)` littérale** portée de DODLP. Header de section : **rendu sobre thémé existant conservé** (`_SectionHeader`/`_CollapsibleSectionHeader`) — la parité visuelle stricte « boîte grise » est **OQ-1, NON implémentée** ici.

**AC-B4 — Garde thème (FR-26).** Les mesures ajoutées sont des **tokens dp directionnels** ; aucune valeur d'aération n'est codée en dur dans un widget (toujours lue via `ZcrudTheme.of(context)`). La garde `style_purity`/couleur reste verte (les tokens d'espacement/rayon sont exemptés de la garde couleur, pas les couleurs — aucune couleur ajoutée ici).

### Bloc C — Seam `ZSelectPresenter` (AR-2, AD-48)

**AC-C1 — Abstraction Material-free au cœur.** `zcrud_core` déclare une **abstraction `ZSelectPresenter`** (patron **strict** de `ZListRenderer` : `abstract class` + constructeur `const` + une méthode `present(...)` ; imports limités à `package:flutter/widgets.dart` + types `zcrud_core` ; **aucun** `awesome_select`, **aucune** dépendance lourde — garde `presentation_purity_test.dart`). Le contrat expose au présentateur **uniquement des données neutres** (options `List<ZFieldChoice>`, valeur(s) courante(s), `onChanged`, mode mono/multi, recherche activable, libellé, `readOnly`) — **jamais** le `ZFormController` (AD-2). Le contrat minimal exact est fixé en §Contract.

**AC-C2 — Résolution via `ZcrudScope`, défaut = modal natif.** Un champ optionnel `selectPresenter` (`ZSelectPresenter?`, défaut `null`) est ajouté à `ZcrudScope` (+ ligne dans `updateShouldNotify`, patron identique à `listRenderer`/`iconResolver`). **Défaut `null` ⇒ le rendu natif zcrud actuel est strictement conservé** (aucune régression). L'impl concrète (adossée à `awesome_select`) vivra dans `zcrud_select` (fp-4-1), **jamais** dans le cœur.

**AC-C3 — Délégation des familles de base.** `ZSelectFieldWidget` et `ZRelationFieldWidget` **délèguent** au présentateur injecté **s'il est présent** (`ZcrudScope.maybeOf(context)?.selectPresenter != null`), sinon **conservent leur rendu natif inchangé**. Le `ZWidgetRegistry` n'est **jamais** détourné pour ces familles de base (elles sont pré-routées par `familyOf` **avant** `registryOrFallback` — recon §6, AD-48). Prouvé : un test monte un `ZSelectPresenter` espion et vérifie qu'il est **appelé** pour `select`/`relation` ; sans lui, le rendu natif est celui d'avant (grep/test de non-régression).

**AC-C4 — CORE OUT=0 global.** Après les 3 blocs : `python3 scripts/dev/graph_proof.py` (RC=0), out-degree `zcrud_core` **inchangé** (0 arête `zcrud_*` sortante) ; `melos run analyze` **repo-wide** RC=0 ; `flutter test` des packages touchés RC=0 ; gates `secrets` + `codegen-distribution` verts.

## Tasks / Subtasks

- [x] **T1 — `dateRange` : enum + famille + dispatch** (AC: A1, A4)
  - [x] T1.1 Ajouter `EditionFieldType.dateRange` près de `dateTime`/`time` dans `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (doc-comment sur le patron des voisins).
  - [x] T1.2 Ajouter `EditionFamily.dateRange` + classer `dateRange` dans `familyOf` (`edition_field_family.dart`) — **sans `default:`**, laisser le compilateur guider.
  - [x] T1.3 Créer `packages/zcrud_core/lib/src/presentation/edition/families/z_date_range_field_widget.dart` (patron `z_date_field_widget.dart` : `StatelessWidget`, `Semantics` bouton, ≥ 48 dp, `AlignmentDirectional.centerStart`, croix optionnelle, `showDateRangePicker`, format d'affichage l10n).
  - [x] T1.4 Câbler le dispatch dans `z_field_widget.dart` : `case EditionFamily.dateRange` → `ZDateRangeFieldWidget(field, value, onChanged: (r) => controller.setValue(field.name, r), onCleared: …)` (même chemin `ZFieldListenableBuilder`/`setValue` que la famille date ; `onCleared` seulement si non requis + éditable).
  - [x] T1.5 Exporter les nouveaux symboles publics via le barrel `packages/zcrud_core/lib/zcrud_core.dart`.
- [x] **T2 — Valeur `ZDateRange` défensive** (AC: A2, A3)
  - [x] T2.1 Créer `packages/zcrud_core/lib/src/domain/edition/z_date_range.dart` : classe immuable `const`, `start`/`end`, `==`/`hashCode`, `toJson()` (`{'start': iso, 'end': iso}`), `fromJson`/`fromJsonSafe`, invariant `end >= start`.
  - [x] T2.2 Implémenter `fromJsonSafe` sur la brique `ZExtension.guard<T>` (ou un `try/catch` équivalent générique) : `null`/corrompu/`start>end` → `null`, jamais de throw.
  - [x] T2.3 Exporter `ZDateRange` via le barrel.
- [x] **T3 — Générateur : catégorie `dateRange`** (AC: A5)
  - [x] T3.1 Ajouter `_Cat.dateRangeType` dans `zcrud_model_generator.dart`.
  - [x] T3.2 `_classify` : reconnaître le type `ZDateRange` (via `_typeName(type) == 'ZDateRange'`, patron de la branche `DateTime`) → `(_Cat.dateRangeType, null, 'dateRange')`.
  - [x] T3.3 `_fromMapExpr` : `case _Cat.dateRangeType` → `orDef('_\$asDateRange($m)')` (défensif).
  - [x] T3.4 `_toMapExpr` (branche symétrique) : sérialiser via `?.toJson()`.
  - [x] T3.5 Émettre le helper `_$asDateRange(Object?) → ZDateRange?` (délègue à `ZDateRange.fromJsonSafe`) dans le préambule des helpers générés, à côté de `_$asDateTime`.
  - [x] T3.6 Régénérer (`dart run melos run generate`) et **committer** les `*.g.dart` impactés de `packages/*/lib/`.
  - [x] T3.7 Étendre le corpus `packages/zcrud_generator/test/models/serialization_corpus.dart` + `serialization_corpus_test.dart`/`serialization_compat_test.dart` pour couvrir un champ `ZDateRange` (round-trip + corpus corrompu + rétro-compat).
- [x] **T4 — Tokens d'aération** (AC: B1, B2, B3, B4)
  - [x] T4.1 `z_responsive_grid.dart` : ajouter `double? runGutter` (défaut `null`), poser `runSpacing: runGutter ?? gutter` ; doc « replié sur gutter si null, additif non-cassant ».
  - [x] T4.2 `z_theme.dart` : ajouter `formPadding` (`EdgeInsetsDirectional`, défaut `all(12)`) + champ + doc + `copyWith` + `lerp` (via `EdgeInsetsDirectional.lerp`).
  - [x] T4.3 `dynamic_edition.dart` : consommer `ZcrudTheme.of(context).formPadding` quand `widget.padding == null` (les deux chemins : `SingleChildScrollView` + stepper, cf. étude §2.2/§4.3) ; brancher `runGutter` sur le chemin `gridGutter`/`ZResponsiveGrid` si un paramètre d'authoring l'expose (sinon exposer `DynamicEdition.gridRunGutter` additif).
  - [x] T4.4 Ne PAS toucher `interFieldGap` (reste défaut `0`) ni le header (OQ-1 hors périmètre).
- [x] **T5 — Seam `ZSelectPresenter`** (AC: C1, C2, C3)
  - [x] T5.1 Créer `packages/zcrud_core/lib/src/presentation/edition/z_select_presenter.dart` (abstraction + DTO neutre `ZSelectPresentation`, cf. §Contract).
  - [x] T5.2 `zcrud_scope.dart` : ajouter `final ZSelectPresenter? selectPresenter;` (constructeur + doc patron `listRenderer`) + ligne `updateShouldNotify`.
  - [x] T5.3 `z_select_field_widget.dart` + `z_relation_field_widget.dart` : si `selectPresenter != null` → déléguer ; sinon rendu natif **inchangé**.
  - [x] T5.4 Exporter `ZSelectPresenter`/`ZSelectPresentation` via le barrel.
- [x] **T6 — Vérif verte + preuves** (AC: A4, A5, C4)
  - [x] T6.1 `dart run melos run generate` OK ; `melos run analyze` **repo-wide** RC=0 ; `flutter test` par package touché RC=0.
  - [x] T6.2 `python3 scripts/dev/graph_proof.py` RC=0 (CORE OUT=0 inchangé) ; gates `secrets` + `codegen-distribution` verts.
  - [x] T6.3 Consigner les greps négatifs (commande + RC) dans les Completion Notes.

## Dev Notes

### Contexte & nature de l'itération
Itération **présentationnelle et d'assemblage**, pas une réécriture. Le gros des familles est **déjà natif** dans `zcrud_core`. fp-1-1 est la **1ʳᵉ story de fondation** et la **seule** story CORE-SÉRIALISÉE en vol : elle pose le substrat cœur (type + tokens + seam) dont dépendent tous les epics suivants. [Source: epics.md#Story-1.1 ; ARCHITECTURE-SPINE.md#Design-Paradigm]

### Patrons cœur EXISTANTS à imiter (vérifiés sur disque)
- **Famille date (patron du widget natif)** : `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart` — `StatelessWidget` pur, `Semantics(button, label, value, excludeSemantics)`, `OutlinedButton` `minimumSize: Size.fromHeight(48)`, `AlignmentDirectional.centerStart`, croix d'effacement conditionnelle (MIN-2), déclencheur de picker Material. **`ZDateRangeFieldWidget` doit strictement calquer cette structure** (un seul nœud sémantique cohérent, pas de double annonce). [Source: z_date_field_widget.dart]
- **Dispatch** : `z_field_widget.dart:~443` (`case EditionFamily.date`) montre le câblage `onChanged: (v) => widget.controller.setValue(field.name, v)` + `onCleared` conditionnel. Le tout est déjà sous `ZFieldListenableBuilder` (une tranche = un `ValueListenable`, rebuild ciblé, SM-1). [Source: z_field_widget.dart]
- **Classement de famille** : `edition_field_family.dart:117` `familyOf` — `switch` **exhaustif sans `default:`** ; ajouter `dateRange` à l'enum **cassera la compilation** ici jusqu'à classement (garde voulue). [Source: edition_field_family.dart]
- **Valeur défensive AD-10 (patron `fromJsonSafe`)** : `packages/zcrud_core/lib/src/domain/extension/z_extension.dart` — `static T? guard<T>(T Function() parse){ try { return parse(); } catch(_) { return null; } }`. **Réutiliser cette brique** pour `ZDateRange.fromJsonSafe`. [Source: z_extension.dart]
- **Générateur défensif** : `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` — `_classify` (branche `DateTime` → `_Cat.dateTimeType, 'dateTime'` à la ligne ~530), `_fromMapExpr` (`case _Cat.dateTimeType → orDef('_\$asDateTime($m)')` ~574), enum interne `_Cat` (~1131). **`dateRange` suit exactement ce patron** (nouvelle catégorie + helper `_$asDateRange`). [Source: zcrud_model_generator.dart]
- **Thème (patron de token)** : `z_theme.dart` — `fieldPadding`/`readPadding`/`largePadding` sont des `EdgeInsetsDirectional` avec défaut, doc, `copyWith`, `lerp` (via `EdgeInsetsDirectional.lerp`). **`formPadding` suit ce patron** (aucune couleur). `ZcrudTheme.of(context)` résout scope → extension → `fallback`. [Source: z_theme.dart]
- **Grille** : `z_responsive_grid.dart:183` constructeur `gutter = 8` posé en `spacing` **et** `runSpacing` (l.243-245). Ajouter `runGutter` optionnel, poser `runSpacing: runGutter ?? gutter`. API additive non-cassante. [Source: z_responsive_grid.dart]
- **Seam abstraction (patron `ZSelectPresenter`)** : `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart` — `abstract class ZListRenderer{ const ZListRenderer(); Widget build(...); }`, imports `package:flutter/widgets.dart` + types cœur uniquement, injecté via `ZcrudScope.listRenderer` (défaut `null` → repli). **`ZSelectPresenter` calque ce patron**. [Source: z_list_renderer.dart]
- **Injection scope** : `zcrud_scope.dart` — champs `listRenderer`/`colorPicker`/`iconResolver` : `final T? x;` + doc « défaut null → repli natif » + ligne dans `updateShouldNotify` (`!identical(...)`). **`selectPresenter` s'ajoute exactement ainsi.** [Source: zcrud_scope.dart]

### Fichiers cœur visés (récap)
| Livrable | Fichiers |
|---|---|
| `dateRange` | `domain/edition/edition_field_type.dart` (UPDATE, enum) · `domain/edition/z_date_range.dart` (NEW valeur) · `presentation/edition/edition_field_family.dart` (UPDATE `familyOf`) · `presentation/edition/families/z_date_range_field_widget.dart` (NEW widget) · `presentation/edition/z_field_widget.dart` (UPDATE dispatch) · `zcrud_generator/lib/src/zcrud_model_generator.dart` (UPDATE `_Cat`/`_classify`/`_fromMapExpr`/`_toMapExpr`/helpers) · `lib/zcrud_core.dart` (UPDATE barrel) |
| Tokens aération | `presentation/theme/z_theme.dart` (UPDATE `formPadding` + copyWith/lerp) · `presentation/edition/z_responsive_grid.dart` (UPDATE `runGutter`) · `presentation/edition/dynamic_edition.dart` (UPDATE consommation `formPadding`/`runGutter`) |
| Seam sélection | `presentation/edition/z_select_presenter.dart` (NEW) · `presentation/zcrud_scope.dart` (UPDATE champ + updateShouldNotify) · `presentation/edition/families/z_select_field_widget.dart` + `z_relation_field_widget.dart` (UPDATE délégation) · `lib/zcrud_core.dart` (UPDATE barrel) |
| Codegen distribué | `packages/*/lib/**/*.g.dart` régénérés + **commités** (gate `codegen-distribution`) |

### Contract — `ZSelectPresenter` (contrat minimal fixé)
Abstraction Material-free au cœur, patron `ZListRenderer`. **Contrat retenu (conservateur)** :
```dart
/// DTO NEUTRE présenté au seam (jamais le ZFormController — AD-2).
@immutable
class ZSelectPresentation {
  const ZSelectPresentation({
    required this.field,          // ZFieldSpec (const, déjà neutre)
    required this.options,        // List<ZFieldChoice> résolues (statiques/dynamiques)
    required this.selected,       // valeur(s) courante(s) de la tranche
    required this.onChanged,      // ValueChanged<Object?> — écrit la tranche
    required this.multiple,       // mono vs multi (select/checkbox/multiselect)
    required this.searchable,     // recherche activable (modal S2)
    required this.readOnly,
    this.label,
  });
  // …champs finals…
}

/// Seam de présentation riche des familles de sélection (AD-48).
/// Défaut = null dans ZcrudScope → rendu natif zcrud conservé.
abstract class ZSelectPresenter {
  const ZSelectPresenter();
  Widget present(BuildContext context, ZSelectPresentation presentation);
}
```
- Le présentateur **ne reçoit que** `ZSelectPresentation` (données + callbacks neutres) — **jamais** le controller.
- `ZFieldChoice` est un type cœur existant (utilisé par `z_select_field_widget.dart`) — **le réutiliser**, ne pas en créer un nouveau.
- **Défaut `null`** dans `ZcrudScope` : familles de base rendues nativement (comportement d'avant, prouvé par non-régression).
- L'impl `awesome_select` (`SmartSelect`) est **hors périmètre** (fp-4-1) ; aucun type `awesome_select` ne doit apparaître dans le contrat (AD-40).

### Comment la désérialisation défensive de `ZDateRange` sera prouvée FALSIFIABLE
1. **Corpus corrompu** (≥ 6 entrées, dans `serialization_corpus.dart` ou un test dédié `z_date_range_test.dart`) : `null` · `42` (non-map) · `{'start':'2026-01-02'}` (`end` absent) · `{'start':123,'end':456}` (non-`String`) · `{'start':'pas-une-date','end':'x'}` (non-ISO) · `{'start':'2026-02-01','end':'2026-01-01'}` (`start>end`). Attendu : `ZDateRange.fromJsonSafe(x) == null` pour chacune, **aucune exception**.
2. **Survie du parent** : un modèle `@ZcrudModel` de test portant `ZDateRange? period` — `Model.fromMap({'period': <entrée corrompue>, 'autreChamp': 'ok'})` **ne throw pas** et `model.autreChamp == 'ok'` (le champ corrompu retombe à `null`, le parent survit). C'est le vrai test AD-10 (PAS un simple `expect(() {...}, returnsNormally)`).
3. **Injection R3 (falsifiabilité)** : modifier temporairement `fromJsonSafe` pour **re-`throw`** (ou faire pointer le helper généré `_$asDateRange` sur `ZDateRange.fromJson` brut). Le corpus corrompu **et** la survie du parent doivent **rougir** (exception propagée observée par le comportement). Consigner cette vérification dans les Completion Notes. Si le test reste vert avec la garde retirée → le test est tautologique et doit être renforcé.
4. **Round-trip** : `ZDateRange.fromJson(r.toJson()) == r` pour une plage valide (ISO conservé, `end>=start`).

### Preuve CORE OUT=0 (aucune arête nouvelle)
- `showDateRangePicker`/`showDatePicker` = **Flutter SDK** (déjà tiré par `dependencies.flutter`), n'ajoute **aucune** arête `zcrud_*`.
- `ZSelectPresenter` = **abstraction** (aucune impl, aucun paquet) ; `ZDateRange` = **pur-Dart** ; `formPadding`/`runGutter` = **tokens/params** purs.
- Grep négatif attendu : `grep -nE "table_calendar|date_time_picker|awesome_select|flex_color_picker|html_editor|image_cropper" packages/zcrud_core/pubspec.yaml` → **RC=1** (aucune sortie).
- Preuve structurelle : `python3 scripts/dev/graph_proof.py` (compte les seules arêtes `zcrud_*`, out-degree `zcrud_core` doit rester **0**) → RC=0. [Source: melos.yaml#graph_proof ; ARCHITECTURE-SPINE.md#Direction-de-dépendance]

### Invariants AD applicables (chaque AC)
- **AD-1 / CORE OUT=0** : type + tokens + seam **natifs SANS dépendance lourde** (AC-A4/C4). [Source: SPINE#AD-1/AD-47/AD-48]
- **AD-2/AD-15 / SM-1** : `ZDateRangeFieldWidget` sous `ZFieldListenableBuilder`, `StatelessWidget` pur, jamais le `ZFormController`, jamais de `TextEditingController` (AC-A4). Le seam ne livre que des données neutres (AC-C1). [Source: SPINE#AD-2 ; z_date_field_widget.dart]
- **AD-3/AD-10** : additif seulement ; `fromJsonSafe` défensif ; codegen source-unique + `*.g.dart` commités (AC-A1/A3/A5). [Source: SPINE#AD-3/AD-10]
- **AD-4/AD-6** : registres/seams **injectés via `ZcrudScope`**, jamais un singleton statique (AC-C2). [Source: zcrud_scope.dart]
- **AD-8** : dépendance lourde (future `awesome_select`) isolée derrière l'abstraction cœur `ZSelectPresenter` (patron `ZListRenderer`) (AC-C1). [Source: z_list_renderer.dart ; SPINE#AD-48]
- **AD-13** : `showDateRangePicker` directionnel, ≥ 48 dp, `Semantics`, `EdgeInsetsDirectional` (AC-A4/B1/B3). [Source: SPINE#AD-13]
- **FR-26** : tokens/thème injectés, **aucune couleur codée en dur** (AC-B3/B4). [Source: SPINE#AD-54 ; z_theme.dart]

### Distribution en dépendance git (NON-NÉGOCIABLE)
Le générateur est modifié → **régénérer (`melos run generate`) ET committer les `*.g.dart`** de `packages/*/lib/` (un consommateur en dép. git ne régénère pas ; un `part` périmé casserait son build). Le commit unique de fin d'epic **inclut** les `*.g.dart`, **exclut** les `pubspec.lock`. [Source: CLAUDE.md#Build ; NFR-6]

### Discipline de réalité (pièges consignés)
- Toute **absence** = grep négatif (commande + RC). `grep|head` masque le RC ⇒ `grep -q` ; `$`/`^` BRE ⇒ `grep -qF`.
- `melos run test` **se bloque** ⇒ `flutter test` **par package** touché.
- `git checkout` **interdit**.
- Défauts récurrents à NE PAS reproduire : espion prouvé **capté AVANT** ; désérialisation défensive réellement testée (**corpus corrompu → parent survit**, pas `takeException isNull`) ; pas de double annonce a11y (`excludeSemantics` sur le wrapper) ; pas de libellé/valeur codés en dur (invisibles à la garde) ; la prose des Completion Notes ne ment pas (rejouer réellement).

### Project Structure Notes
- API publique via barrel `lib/zcrud_core.dart` ; impl sous `lib/src/{domain,presentation}`. Domaine pur-Dart (`z_date_range.dart` : **aucun** import Flutter). Widgets/seams sous `presentation/`.
- `dateRange` (camelCase) respecte la convention d'enum ; persistance snake_case, valeur `{'start','end'}` ISO-8601.
- Aucune écriture cœur concurrente autorisée pendant fp-1-1 (verrou CORE-SÉRIALISÉE) : fp-1-2 (satellites) parallélisable **seulement** une fois le cœur au repos.

### Frontières (HORS fp-1-1)
- **PAS** l'impl des satellites ni leurs squelettes (= fp-1-2) · **PAS** le fork `awesome_select` (fp-1-2/fp-4-1) · **PAS** le polish des champs natifs (fp-2-1) · **PAS** le showcase/harnais (fp-3-1) · **PAS** `ZColorConfig.multiple` (fp-4-4) · **PAS** `interFieldGap:12` côté binding (fp-2-x) · **PAS** l'en-tête « boîte grise » de section (OQ-1). [Source: epics.md#Story-1.1 ; NEXT-ITERATION-SCOPE]

### Decisions (mode non-interactif — options conservatrices)
- **D1 — `ZDateRange` `start > end`** → **rejet en `null`** à la désérialisation (plutôt que normalisation par échange) : cohérent avec AD-10 (repli sûr, jamais de valeur métier inventée) et testable sans ambiguïté. Le constructeur public peut `assert(end >= start)` en debug ; `fromJsonSafe` **ne construit jamais** une plage invalide → `null`.
- **D2 — `runGutter`** exposé sur `ZResponsiveGrid` **et** relayé par un paramètre d'authoring additif de `DynamicEdition` (`gridRunGutter`) si aucun n'existe (à vérifier sur disque avant d'en créer un) — API non-cassante, replié sur `gutter`.
- **D3 — `ZSelectPresentation`** minimal (options/selected/onChanged/multiple/searchable/readOnly/label) : suffisant pour `select`/`radio`/`checkbox`/`relation` de fp-4-1 sans sur-spécifier ; extensible additivement plus tard.
- **D4 — Header de section** : rendu sobre existant **conservé** (OQ-1 non implémentée).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-1.1]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-form-parity-2026-07-18/prd.md#FR-5 · #FR-38]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-47 · #AD-48 · #AD-52 · #AD-54 · #Direction-de-dépendance]
- [Source: docs/dodlp-form-integration-study-2026-07-17/06-aeration-layout.md#4.1 · #4.3]
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart]
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart]
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart]
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart]
- [Source: packages/zcrud_core/lib/src/domain/extension/z_extension.dart]
- [Source: packages/zcrud_generator/lib/src/zcrud_model_generator.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart]
- [Source: scripts/dev/graph_proof.py ; melos.yaml (gates verify/analyze/secrets/codegen-distribution)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]` (dev-story, effort high).

### Debug Log References

- `dart run melos run generate` → SUCCESS (build_runner sur tous les packages annotés ; `_$asDateRange` émis dans les helpers partagés, `article.g.dart` régénéré avec `period`/`dateRange`).
- `flutter test` (packages/zcrud_core) → **+986 All tests passed** (baseline 951 ; +35 nouveaux tests). RC=0.
- `dart test` (packages/zcrud_generator) → **+117 All tests passed** (les 2 « échecs de chargement » sous `flutter test` = `dart:mirrors` indisponible sur l'engine Flutter, PRÉ-EXISTANT — ces tests build_runner tournent sous `dart test`). RC=0.
- `dart analyze packages/zcrud_core packages/zcrud_generator` → RC=0 (2 infos `deprecated_member_use` PRÉ-EXISTANTES dans `z_batch_action_test.dart`, hors périmètre).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK**, RC=0.
- `grep -qE "table_calendar|date_time_picker|awesome_select|flex_color_picker|html_editor|image_cropper" packages/zcrud_core/pubspec.yaml` → RC=1 (aucune dépendance lourde ajoutée).
- `dart run scripts/ci/gate_codegen_distribution.dart` → RC=0 (0 `part` gitignoré).

### Completion Notes List

- **Bloc A — `dateRange` (AD-47)** : `EditionFieldType.dateRange` (près de `dateTime`/`time`) ; valeur `ZDateRange{start,end}` pur-Dart (`lib/src/domain/edition/z_date_range.dart`), ISO-8601, invariant `end >= start`. `fromJson` STRICT (lève) / `fromJsonSafe` DÉFENSIF (`ZExtension.guard` → `null`, jamais de throw). Famille `EditionFamily.dateRange` + `ZDateRangeFieldWidget` (patron strict de `z_date_field_widget.dart` : `StatelessWidget` pur, `showDateRangePicker` SDK, Semantics `excludeSemantics`, ≥48 dp, croix MIN-2). Dispatch câblé dans `z_field_widget.dart` (switch exhaustif SANS `default:`). Générateur : `_Cat.dateRangeType` + `_classify` (`ZDateRange` → `dateRange`) + `_fromMapExpr` (`_$asDateRange`) + `_toMapExpr` (`.toJson()`) + helper partagé `_$asDateRange`.
- **AD-10 falsifiable RÉELLEMENT prouvé** : corpus corrompu de **8 entrées** (`z_date_range_test.dart` : null · non-map int · non-map String · end absent · start absent · non-String · non-ISO · start>end) → `fromJsonSafe == null` sans throw. **Survie du parent** prouvée côté générateur : `serialization_corpus.dart` famille (h) — un `Article` avec `period` corrompu se décode, `title` conservé (`serialization_corpus_test.dart`). **Injection R3 (falsifiabilité)** : un groupe de tests dédié assied que `ZDateRange.fromJson` (STRICT) **lève** sur CHACUNE des 8 formes corrompues (`throwsA(anything)` — comportement observé, PAS `takeException isNull`). Brancher le helper `_$asDateRange` sur `fromJson` (au lieu de `fromJsonSafe`) ferait donc rougir corpus + survie du parent.
- **Bloc B — Tokens d'aération (AD-54/FR-26)** : `ZcrudTheme.formPadding` (`EdgeInsetsDirectional`, défaut `all(12)`, + `copyWith`/`lerp`) consommé par `DynamicEdition` quand `padding == null` (via `ZcrudTheme.of(context)`, jamais un littéral) — les DEUX chemins `ListView` (`_buildFlat` + `_buildGrouped`). `ZResponsiveGrid.runGutter` (`double?`, défaut `null` → repli `gutter`, `Wrap.runSpacing`) additif non-cassant, relayé par `DynamicEdition.gridRunGutter`. `interFieldGap` INCHANGÉ (défaut 0). Aucune couleur ajoutée. Note : `responsive_grid_test` reçoit désormais `padding: EdgeInsets.zero` (isole la géométrie de grille du nouveau `formPadding` — la consommation du token est couverte à part par `aeration_tokens_test`).
- **Bloc C — Seam `ZSelectPresenter` (AD-48)** : `abstract class ZSelectPresenter` Material-free (`const` + `present(...)`, patron `ZListRenderer`) + DTO neutre `ZSelectPresentation` (options `List<ZFieldChoice>`/selected/onChanged/multiple/searchable/readOnly/label — **jamais** le `ZFormController`, aucun type `awesome_select`). Champ `ZcrudScope.selectPresenter` (défaut `null` → rendu natif ; + ligne `updateShouldNotify`). Délégation depuis `ZSelectFieldWidget` (checkbox → `multiple=true`) et `ZRelationFieldWidget` (options = choix effectifs). Espion prouvé **capté AVANT tout rendu natif** + non-régression défaut `null` (`z_select_presenter_test.dart`).
- **CORE OUT=0 prouvé** : `graph_proof.py` out-degree `zcrud_core` = 0 (`showDateRangePicker` = SDK, `ZSelectPresenter` = abstraction sans impl, `ZDateRange` = pur-Dart) + grep négatif pubspec RC=1.
- **Codegen distribué** : générateur touché ⇒ régénéré et **inclus dans la File List** — le helper partagé `_$asDateRange` (référence `ZDateRange`, exporté par `domain.dart`/`edition.dart`/`zcrud_core.dart`) apparaît dans TOUS les `*.g.dart` régénérés ; les 5 packages à `part` (document/exam/flashcard/note/study_kernel) analysent RC=0. Gate `codegen-distribution` RC=0.
- **Disjonction fp-1-2** : écriture STRICTEMENT limitée à `packages/zcrud_core/` + `packages/zcrud_generator/` (+ `*.g.dart` régénérés sous `packages/*/lib/`, mandatés par le gate). Le `pubspec.yaml` racine (M) et les nouveaux `packages/{awesome_select,zcrud_select,zcrud_html,zcrud_media,zcrud_field_extras}/` sont l'empreinte de fp-1-2 — **jamais touchés ici**.
- **Décisions D1..D4** appliquées : D1 rejet→null ; D2 `gridRunGutter` additif ; D3 DTO minimal ; D4 header inchangé (OQ-1 hors périmètre). `ZDateRange` non-`const` (l'assert d'invariant `isBefore` n'est pas « potentiellement constant ») — aucun site d'appel n'exige `const`.

### File List

**Créés — `packages/zcrud_core/`**
- `lib/src/domain/edition/z_date_range.dart`
- `lib/src/presentation/edition/families/z_date_range_field_widget.dart`
- `lib/src/presentation/edition/z_select_presenter.dart`
- `test/domain/edition/z_date_range_test.dart`
- `test/presentation/edition/z_date_range_field_widget_test.dart`
- `test/presentation/edition/z_select_presenter_test.dart`
- `test/presentation/edition/aeration_tokens_test.dart`

**Modifiés — `packages/zcrud_core/`**
- `lib/domain.dart` · `lib/edition.dart` · `lib/zcrud_core.dart` (barrels : exports `ZDateRange` / `ZDateRangeFieldWidget` / `ZSelectPresenter`)
- `lib/src/domain/edition/edition_field_type.dart` (enum `dateRange`)
- `lib/src/presentation/edition/edition_field_family.dart` (`EditionFamily.dateRange` + `familyOf`)
- `lib/src/presentation/edition/z_field_widget.dart` (dispatch dateRange)
- `lib/src/presentation/edition/z_read_only_value.dart` (`zReadModeCardable` : dateRange non fiche-able)
- `lib/src/presentation/edition/dynamic_edition.dart` (`gridRunGutter` + consommation `formPadding`)
- `lib/src/presentation/edition/z_responsive_grid.dart` (`runGutter`)
- `lib/src/presentation/theme/z_theme.dart` (`formPadding` + copyWith/lerp)
- `lib/src/presentation/zcrud_scope.dart` (`selectPresenter` + updateShouldNotify)
- `lib/src/presentation/edition/families/z_select_field_widget.dart` (délégation seam)
- `lib/src/presentation/edition/families/z_relation_field_widget.dart` (délégation seam)
- `test/domain/edition/edition_field_type_test.dart` · `test/presentation/edition/responsive_grid_test.dart` · `test/presentation/edition/z_field_dispatch_test.dart` (comptes 39→40, padding zéro)

**Modifiés — `packages/zcrud_generator/`**
- `lib/src/zcrud_model_generator.dart` (`_Cat.dateRangeType`, `_classify`, `_fromMapExpr`, `_toMapExpr`, `_fallback`, helper `_$asDateRange`)
- `test/models/article.dart` (champ `ZDateRange? period`)
- `test/models/serialization_corpus.dart` (famille (h) + `null_partout`)
- `test/serialization_corpus_test.dart` · `test/zcrud_model_generator_test.dart` (assertions (h) + 11→12 champs + inférence dateRange)

**Régénérés (`*.g.dart`, à committer en fin d'epic — gate codegen-distribution)**
- `packages/zcrud_generator/test/models/article.g.dart`
- `packages/zcrud_document/lib/src/domain/*.g.dart` (5) · `packages/zcrud_exam/lib/src/domain/z_exam.g.dart`
- `packages/zcrud_flashcard/lib/src/domain/*.g.dart` (3) · `packages/zcrud_note/lib/src/domain/z_smart_note.g.dart`
- `packages/zcrud_study_kernel/lib/src/domain/*.g.dart` (7)

### Code-review (post-dev) — findings corrigés

Rapport complet : `code-review-fp-1-1.md`. 0 HIGH/MAJEUR. Tous MEDIUM + LOW corrigés (tests
porteurs renforcés R3 + 1 dartdoc), falsifiabilité rejouée réellement (chaque test RED sous
l'injection nommée puis GREEN sur le code correct).

- **MED-1** (corrigé) — `test/presentation/edition/z_date_range_field_widget_test.dart` : nouveau test AC-A4 (tap `OutlinedButton` → picker ouvert → câblage réel `onChanged` écrit un `ZDateRange`). RED sous `z_field_widget.dart:473 → (range)=>{}`.
- **MED-3** (corrigé) — `test/presentation/edition/aeration_tokens_test.dart` : token NON-défaut `formPadding: all(29)` via `ZcrudScope(theme:)`, asserte `list.padding == all(29)`. RED sous `dynamic_edition.dart:576` littéral `all(12)`.
- **MED-4** (corrigé) — `test/presentation/edition/z_select_presenter_test.dart` : éviction natif relation `DropdownButtonFormField findsNothing`. RED sous double-rendu (`z_relation_field_widget.dart:169` sans `return`).
- **LOW-5** (corrigé) — SM-1 pince les deux côtés : `expect(builds['t']!, greaterThan(tBefore))`. RED sous propagation `setValue` morte.
- **LOW-2** (corrigé) — `lib/src/presentation/edition/families/z_date_range_field_widget.dart` : dartdoc de `_formatRange` atténué (format ISO-8601 délibéré assumé, PAS localisé ; comportement inchangé).

**Vérif verte post-review rejouée** : `flutter test packages/zcrud_core` +987 RC=0 ; `dart test` (generator) +117 RC=0 ; `dart analyze packages/zcrud_core` RC=0 ; `graph_proof.py` ACYCLIQUE + CORE OUT=0 RC=0.

**Fichiers modifiés par le code-review** (tous `packages/zcrud_core/`) :
- `test/presentation/edition/z_date_range_field_widget_test.dart`
- `test/presentation/edition/aeration_tokens_test.dart`
- `test/presentation/edition/z_select_presenter_test.dart`
- `lib/src/presentation/edition/families/z_date_range_field_widget.dart`
