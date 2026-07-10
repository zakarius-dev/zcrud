# Code Review — Sous-story E3-3b-1 : `ZWidgetRegistry` + feuilles simples + relâchement L-2

- **Story** : `_bmad-output/implementation-artifacts/stories/e3-3b-familles-avancees-sous-listes.md` (périmètre **-1** uniquement ; ACs `[→ -1]` : 1,2,3,4,5,6,7,12,13-harnais,14-base,15-préservé,16)
- **Reviewer** : BMAD code-review adversarial (skill `bmad-code-review`, chemin pris : **tool `Skill` OK** — étapes step-01/02/03 suivies ; revue exécutée en un seul agent, layers Blind Hunter / Edge Case Hunter / Acceptance Auditor joués en interne)
- **Baseline** : `acc6a2138a437fd3d1c53886246fa3340c0b540f` (== HEAD ; travail E3-1/E3-2/E3-3a/E3-3b-1 en arbre non commité — répertoire `edition/` non suivi). Diff isolé au **périmètre -1** (registre + 5 feuilles + L-2 + configs/l10n/barrel/tests).
- **Date** : 2026-07-10
- **Verdict** : ✅ **APPROVED** — **0 HIGH · 0 MAJEUR · 0 MEDIUM · 7 LOW/nits**. Aucune régression, tous les gates verts, tous les ACs `[→ -1]` satisfaits. Les subItems/dynamicItem (-2) et signature/widget (-3) restent `unsupported` par conception — **non jugés manquants**.

---

## 1. Vérification verte rejouée RÉELLEMENT sur disque

| Contrôle | Commande | Résultat RÉEL |
|---|---|---|
| Analyse | `flutter analyze lib test` (zcrud_core) | **RC=0** — « No issues found! » |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0** — **287** passed (+27 vs 260 baseline E3-3a) |
| Gates de merge | `dart run melos run verify` | **EXIT_CODE=0** — graph_proof · gate_melos · gate_reflectable · gate_secret_scan · gate_codegen · gate_compat · verify_serialization tous OK. Les `ERROR: No tests match tag serialization-compat` sur les packages sans corpus sont **tolérés** (exit 0 global). |
| Graphe | `graph_proof.py` | **out-degree(zcrud_core) = 0 (runtime)** · **ACYCLIQUE OK** · **CORE OUT=0 OK** · **nœuds = 14** |
| Packages | `melos list` | **14** |
| `.g.dart` committés | `git ls-files '*.g.dart'` | **0** |
| Agnosticité cœur | `grep` satellite imports sous `lib/` | **NONE** (aucun `flutter_quill`/`syncfusion`/`firebase`/`hive`/`google_maps`/`zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/gestionnaire d'état) |

Non-régression SM-1/UJ-2 : `sm1_full_form`, `sm1_with_validation`, `uj2_external_rebuild`, `uj2_dispatch_nontext`, `controller_stability`, `mid_cursor`, `external_value_sync`, `keyed_subtree_guard`, `l4_focus_change` présents et **verts** dans les 287 (rejoués à travers le dispatcher étendu).

---

## 2. Vérification adversariale des points de vigilance

### 2.1 — Registre agnostique (AD-1 / AD-4) — VÉRIFIÉ ✅
- `ZWidgetRegistry` (`z_widget_registry.dart`) est **DISTINCT** de `ZTypeRegistry`/`ZOpenRegistry` (codecs, `domain/` pur-Dart) : il vit en `presentation/`, renvoie des `Widget Function(BuildContext, ZFieldWidgetContext)`, et n'importe que `flutter/widgets` + specs internes. Aucun détournement du registre de codecs.
- **INSTANCIABLE, non-singleton** : constructeur `ZWidgetRegistry()`, état d'instance (`final Map _builders`), **aucun champ/membre statique mutable** (seul statique = `_name` const). Test `instanciable / non-singleton : deux instances sont indépendantes (AD-4)` prouve l'isolation d'état.
- **Injection** : nouveau champ optionnel `ZcrudScope.widgetRegistry` (défaut `null`), `updateShouldNotify` par **identité** (`!identical(widgetRegistry, ...)`), documenté « défaut null → repli ». Aucune arête de package ajoutée (`graph_proof` CORE OUT=0 inchangé).
- **Résolution dans la slice (value-in-slice, pas de rebuild global)** : `_dispatchRegistry` est appelé **sous** le `builder:` de `ZFieldListenableBuilder` (frontière AD-2 inchangée) ; `ZcrudScope.maybeOf(context)` établit sa dépendance sur le contexte du ListenableBuilder → un changement de scope rebuild **le slice**, jamais le formulaire. `onChanged → setValue(field.name, v)`. Un `find.byType(Form) → findsNothing` sous le catalogue confirme l'absence de `Form` global.
- **Type externe servi sans que le cœur le connaisse** : test `kind externe enregistré → widget hôte rendu, lit/écrit la tranche` monte un `_DemoFieldWidget` défini **dans le test** (kind `'markdown'`), rendu/lu/écrit sans que `zcrud_core` importe E6/E11a. `custom` résolu par nom d'enum (`'custom'`), testé.
- **CORE OUT=0 préservé** : confirmé (cf. §1). `widgetRegistry` n'ajoute aucune arête `zcrud_*`.

### 2.2 — Garde L-2 bidirectionnelle (critique) — VÉRIFIÉ ✅
- `presentation_purity_test.dart` : `services.dart` **retiré** de `_forbiddenPresentation` et traité en amont par `_servicesImportAllowed` — autorisé **UNIQUEMENT** avec `show` restreint à l'allowlist `{TextInputFormatter, FilteringTextInputFormatter, TextInputType}` ; `null`/`show` vide (nu) → **rejeté** ; symbole hors allowlist → **rejeté** (`symbols.every(allowlist.contains)`).
- **Rejeu adversarial de la garde** (test `L-2 : … garde bidirectionnelle`, cas a/b/c/d) : (a) `show TextInputFormatter` → `isTrue` ; (b) `services.dart` **nu** → `isFalse` ; (c) `show Clipboard` **et** `show TextInputFormatter, Clipboard` → `isFalse` ; (d) non-services → `null`. Vérifié aussi que `hide` (aucune clause `show`) tombe en « nu → rejeté ». Parseur robuste au **multi-ligne** (`_joinStatement` jusqu'au `;`) — nécessaire car l'import réel du champ nombre porte son `show` sur la 2e ligne.
- **Import réel scopé** : `z_number_field_widget.dart` importe `package:flutter/services.dart' show FilteringTextInputFormatter, TextInputFormatter;` — les 2 symboles sont dans l'allowlist. Conforme.
- **Filtrage comportemental prouvé** : `number_input_formatter_test` — integer `'a1b2c3' → '123'` (tranche `123`), float `'12x.5y' → '12.5'` (tranche `12.5`). Le formatter s'applique EN PLUS du parse défensif (`tryParse → null`).

### 2.3 — Feuilles a11y / RTL (AD-13 / FR-26) — VÉRIFIÉ ✅
- **Catalogue de référence** (`catalogue_a11y_test`) : 5 feuilles + 1 type registre (démo) → `meetsGuideline(androidTapTargetGuideline)` **et** `meetsGuideline(textContrastGuideline)` verts, `SemanticsHandle` disposé, rendu RTL sans overflow (`Directionality.of` == rtl aux champs).
- **Cibles ≥ 48 dp** : tags (`IconButton` add/remove), rating (`IconButton` étoiles), rowChips (`ChoiceChip` `materialTapTargetSize: padded`), color (`SizedBox 48×48` par swatch), slider (natif). Vérifié par le guideline.
- **RTL directionnel exclusif** : tous les insets sont `EdgeInsetsDirectional.fromSTEB`, `Wrap`/`Row` suivent la `Directionality` ; `style_purity_test` reste **vert** (0 inset/alignement non directionnel, 0 couleur littérale).
- **`color` = int ARGB sérialisable stable** (`0xAARRGGBB`, documenté) ; palette **DÉRIVÉE HSV** (`HSVColor.fromAHSV(...).toColor().toARGB32()`) — **aucun littéral de couleur de charte** (FR-26 respecté ; les swatches sont des données). Encodage vérifié par `z_advanced_leaves_test` (tranche `isA<int>()`).

### 2.4 — 0 default (AC2 / AC14) — VÉRIFIÉ ✅
- `familyOf` (`edition_field_family.dart`) reste un `switch` **exhaustif SANS clause `default:`** sur les 39 valeurs (les occurrences « default: » sont des commentaires de rubrique). Un futur type non classé **casse la compilation** (switch exhaustif Dart 3).
- **Partition 39 re-vérifiée** par `z_field_dispatch_test` : **13 base + 1 hidden + 5 feuilles + 12 registryOrFallback + 8 unsupported = 39** (`all.length == 39`, `== EditionFieldType.values.toSet()`, aucun doublon). `stepper`/`file`/`image`/`document` + `subItems`/`dynamicItem`/`signature`/`widget` **restent `unsupported`** (asserté). Feuilles jamais en repli (`isNot(EditionFamily.unsupported)`).

### 2.5 — SM-1 / UJ-2 préservés (AD-2, objectif n°1) — VÉRIFIÉ ✅
- Toutes les feuilles sont rendues **sous l'unique** `ZFieldListenableBuilder` ; le dispatch n'échange que le sous-arbre interne. Aucune famille -1 n'introduit de `setState` de formulaire ni de `Form` global.
- Suite E3-3a rejouée verte à travers le dispatcher étendu (cf. §1) ; `find.byType(Form) → findsNothing` sous le catalogue avancé.

### 2.6 — Stabilité E3-2 (`tags` contrôleur local) — VÉRIFIÉ ✅
- `familyUsesTextController` **inchangé** (text/number) → l'hôte `ZFieldWidget` n'alloue **aucun** contrôleur pour `tags`. Le `TextEditingController _add` + `FocusNode _addFocus` de `ZTagsFieldWidget` sont `late final`, créés **1×** en `initState`, `dispose` propre, **jamais recréés** (State persistant sur rebuild de tranche). Aucune fuite, aucune régression de stabilité. Taper dans la saisie d'ajout n'écrit PAS la tranche (write uniquement à la validation d'une étiquette).

---

## 3. Findings (triage sévérité)

**Aucun HIGH / MAJEUR / MEDIUM.** Les critères MEDIUM du mandat (garde L-2 contournable, registre-singleton, feuille interactive sans a11y) sont **tous absents**. Findings LOW/nits ci-dessous — optionnels, consignés pour -2/-3 ou évolution additive.

| # | Sévérité | Fichier | Constat | Recommandation |
|---|---|---|---|---|
| L-1 | LOW (a11y) | `families/z_slider_field_widget.dart` | Seule feuille **sans** nœud `Semantics(container, label:)` : le `Text(resolvedLabel)` n'est pas associé sémantiquement au `Slider`. Le Slider annonce sa **valeur** (AC6 satisfait) mais pas le **nom** du champ, à la différence de tags/rowChips/rating/color. | Envelopper le slider dans `Semantics(container:true, label: resolvedLabel)` pour homogénéité a11y. |
| L-2 | LOW (cosmétique) | `z_slider_field_widget.dart:67` | `label: current.toStringAsFixed(config.divisions == null ? 2 : 0)` suppose que « divisions ⇒ plage entière ». Pour un `ZSliderConfig(divisions:10)` avec la plage par défaut `0..1`, la bulle affiche `"0"` pour 0.1–0.4. | Dériver le nombre de décimales de la plage (`max-min`) plutôt que de la présence de `divisions`. |
| L-3 | LOW (robustesse) | `z_number_field_widget.dart:67` | `FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))` laisse passer des chaînes malformées (`"1.2.3"`, `"-1-2"`, `"--"`). Le parse défensif renvoie `null` (pas de crash) et le validateur signale — filtre « en plus », jamais en remplacement (conforme au design). | Optionnel : formatter interdisant les points/signes multiples si une UX plus stricte est souhaitée. |
| L-4 | LOW (cohérence) | `z_rating_field_widget.dart:86` | Re-toucher l'étoile active écrit `0` (documenté « 0 = aucune ») et non `null` — conflate « non noté » et « zéro », à la différence de `rowChips` qui écrit `null` à la désélection. | Documenter/aligner le contrat vide (`null` vs `0`) si une note optionnelle doit distinguer les deux. |
| L-5 | LOW (couverture) | `test/presentation/edition/` | Trous de couverture : (a) aucun test **`readOnly: true`** sur les feuilles avancées (le code désactive pourtant `onRemove`/`onSelected`/`onPressed`/`onTap`/`onChanged`) ; (b) aucun test **defensif** `color` hors-gamme (valeur non-`int`) ni `rating` hors-borne (`_current` clampé `0..max`). | Ajouter 2-3 tests (readOnly + valeurs défensives) — cheap, durcit la partition. |
| L-6 | LOW (limitation documentée) | `z_field_widget.dart:253` | `kind` = `field.type.name` : tous les champs `custom` se résolvent au **même** kind `'custom'` → impossible de servir deux widgets `custom` distincts en -1. Documenté (ambiguïté #6, évolution additive future). | Prévoir un discriminant fin (`field.config`/`extra`) quand un besoin réel émerge. |
| L-7 | LOW (durcissement) | `test/purity/presentation_purity_test.dart:185` | La branche `services.dart` n'est activée que si `_importUri(première ligne) == services`. Un import dont l'URI serait sur une ligne séparée de `import` (formatage improbable, jamais produit par `dart format`) serait **ignoré** (non flaggé) au lieu d'être évalué. | Optionnel : reconstruire l'instruction avant d'extraire l'URI. Risque réel négligeable. |

---

## 4. Conclusion

Périmètre **-1** livré conforme : registre **instanciable/agnostique** (AD-1/AD-4) distinct du registre de codecs, injecté via `ZcrudScope`, résolu dans la slice sans élargir la frontière de rebuild (AD-2) ; garde L-2 **bidirectionnelle prouvée** (nu et hors-allowlist rejetés) avec `inputFormatters` purs filtrant réellement le non-numérique ; 5 feuilles value-in-slice **a11y/RTL/FR-26** conformes ; exhaustivité **0-default** préservée (partition 39) ; SM-1/UJ-2 **verts**. Vérif verte réelle : analyze RC=0 · 287 tests · verify EXIT=0 · CORE OUT=0 · 14 pkgs · 0 `.g.dart`.

**Verdict : ✅ APPROVED.** Les 7 LOW sont optionnels (aucun MEDIUM à justifier). Les feuilles -2/-3 et le durcissement L-1/L-5 peuvent être repris dans les sous-stories suivantes.
