# Code Review — Story E2-4 : Annotations (@ZcrudModel / @ZcrudField / @ZcrudId) + `EditionFieldType`

- **Skill** : `bmad-code-review` (chemin pris : tool `Skill` → skill chargé ; step-files `steps/step-01..03` suivis).
- **Cible** : story `_bmad-output/implementation-artifacts/stories/e2-4-annotations.md` (11 ACs, statut `review`).
- **Baseline** : `baseline_commit: 8f28755` (fichiers de la story tous *untracked* — revue du contenu complet des nouveaux fichiers).
- **Mode** : `full` (Acceptance Auditor actif — spec fournie).
- **Reviewer** : Opus 4.8 (mono-session, 3 couches internalisées : Blind Hunter / Edge Case Hunter / Acceptance Auditor).
- **Date** : 2026-07-09.

---

## Verdict : **APPROVED**

La surface d'autorité est **complète, `const`-pure, sans dépendance runtime lourde**, et l'astuce d'entrée pure `package:zcrud_core/edition.dart` **fonctionne réellement** (annotations exécutées sous `dart test`, Flutter non tiré). Aucun finding HIGH/MAJEUR ni MEDIUM. Quelques trous de couverture LOW (nits), non bloquants.

---

## Vérifications RÉELLES rejouées sur disque

| Gate | Commande | Résultat |
|---|---|---|
| Analyze | `melos run analyze` | **RC=0** — « No issues found » (14 packages) |
| Tests | `melos run test` (flutter) | **SUCCESS** — `zcrud_core` 155 (dont pureté domaine + presentation) ; total workspace **191** (annotations 8, get 12, riverpod 8, provider 8) |
| **AC pivot** | `dart test` dans `packages/zcrud_annotations` | **8/8 passés sous `dart test`** (VM Dart pure) → prouve que la surface d'autorité ne tire **pas** Flutter transitivement |
| Graph | `scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, 14 nœuds ; arête `zcrud_annotations → zcrud_core` présente (17 arêtes) |
| Verify | chaîne `verify` (graph + gates melos/reflectable/secrets/codegen/compat/serialization) | **RC=0** (gate anti-`reflectable` vert, scan secrets vert, codegen vert) |
| Melos | `melos list` | **14** packages |
| Pureté | grep flutter/firebase/riverpod/get/provider/syncfusion/quill sous `domain/edition/` + `edition.dart` + `z_core_api.dart` | **NONE** — 0 import lourd ; `edition.dart` pur |

---

## Analyse adversariale par point de vigilance

### 1. Surface complète (AC2/AC3/AC4) — **CONFORME**
- `@ZcrudField` expose les **12 paramètres** requis : `label`, `type`, `validators`, `config`, `choices`, `condition`, `searchable`, `defaultValue`, `readOnly`, `showIfNull`, `name`, `multiple` — tous `final`, tous optionnels, défauts sûrs (`searchable=false`, `readOnly=false`, `showIfNull=true`, `multiple=false`). Test de couverture instancie **chaque paramètre simultanément** en `const`.
- `@ZcrudModel` : `kind` (`String?`) + `fieldRename` (`ZFieldRename`, défaut `snake`) ✓.
- `@ZcrudId` : marqueur `const` sans paramètre ✓.

### 2. `EditionFieldType` (AC5) — **CONFORME, parité exacte**
- **39 valeurs = 38 parité + `custom`**. Comparaison ligne-à-ligne avec `technical-inventory.md §3` : les 38 valeurs correspondent **exactement** au tableau de parité (variantes `timestamp→dateTime`, `crudDataSelect→relation`, `RichText→richText`, `addressSearchField→address` correctement fusionnées ; `multiple` correctement traité comme **flag `@ZcrudField`** et non comme valeur d'enum). **Aucun doublon, aucun manque.**
- camelCase vérifié par test (0 `_`, 0 `-`, initiale minuscule) → discipline `@JsonKey(unknownEnumValue: custom)` cohérente (AD-4).
- Cas limites documentés dans les docstrings : `icon` (hors MVP), `password` (text+validateur), `hidden` (non rendu), `widget` (closure attachée runtime, hors annotation).

### 3. Aucune dépendance runtime lourde (AC1, pivot) — **CONFORME, structurellement prouvé**
- `zcrud_annotations/pubspec.yaml` : `dependencies: {zcrud_core}` **seule** arête `zcrud_*` ; unique ajout `dev_dependencies: {test}`. Aucun `build_runner`/`source_gen`/`analyzer`/gestionnaire d'état/Firebase/Syncfusion/Quill/Maps.
- Les 3 annotations sont des classes **`const` pur-données** : champs `final`, constructeur `const`, **zéro méthode à comportement, zéro closure**. `reflectable` inutile (gate CI vert).
- **L'astuce d'import pur tient** : `zcrud_model/field/id.dart` + `z_annotations_api.dart` importent `package:zcrud_core/edition.dart` (barrel curaté pur), **jamais** le barrel principal (qui ré-exporte la couche presentation Flutter). Preuve empirique : les 8 tests d'annotations **tournent sous `dart test`** (échoueraient à la compilation si `dart:ui` fuyait).

### 4. const-correctness (AC11) — **CONFORME**
- Toutes les annotations et types-valeur instanciés `const` avec tous les params (analyze RC=0 = validité `const` prouvée par le compilateur).
- **Correctif `ZCondition.not` validé** : le combinateur `not` porte un champ dédié `operand` (`ZCondition?`), distinct de `operands` (`List<ZCondition>?` pour `and`/`or`). `not(ZCondition operand)` compile en `const` — le contournement de l'`invalid_constant` (une `List` littérale dans un initialiseur `const` de combinateur) est correct. `==`/`hashCode` gèrent les deux champs (deep-equals via `_listEquals` pur-Dart, sans `package:collection` → AD-1 respecté).

### 5. Alignement E2-5 / anti-empiètement — **CONFORME**
- La surface (le *quoi*) est intégralement projetable par `ConstantReader` (tous les params `const`-lisibles). Table de correspondance `@ZcrudField → ZFieldSpec` documentée en docstring.
- **Pas d'empiètement E2-5** : aucune classe `ZFieldSpec`, aucun `TypeChecker`, aucune émission de code, aucun `register(fieldSpecs:)`. Le slot `fieldSpecs` du `ZcrudRegistry` (E2-3) reste intouché, réservé additivement.
- Ambiguïtés #2/#3/#4 tranchées et documentées (22 variantes `ZValidatorKind`, 3 configs triviales, `ZAnnotationsApi` conservé).

### 6. Pureté (AC10) — **CONFORME**
- 0 import Flutter/lourd sous `packages/zcrud_core/lib/src/domain/edition/*` ; `edition.dart` et `z_core_api.dart` purs ; `domain_purity_test.dart` vert.

---

## Findings

### HIGH / MAJEUR
_Aucun._

### MEDIUM
_Aucun._

### LOW (nits — optionnels, consignés)

- **[LOW-1] Couverture partielle du portage de payload par variante (AC11).** `edition_field_type_test.dart` prouve la `const`-constructibilité de **toutes** les variantes `ZValidatorSpec` (via `containsAll(ZValidatorKind.values)`), mais n'asserte le portage fin des getters que pour `minLength`/`minKey`/`equal`/`pattern`. Les payloads de `maxKey` (`refKey`), `max`/`min` (`bound`), `match` (`refKey`), `notEqual` (`value`) ne sont pas vérifiés individuellement. Risque réel faible (constructeurs symétriques, analyze couvre la validité). *Fichier : `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart`.*

- **[LOW-2] Branches de `ZCondition._listEquals` / égalité `not` non couvertes.** Le test d'égalité profonde n'exerce que `and([truthy])`. L'inégalité (longueurs différentes, éléments différents) et l'égalité/inégalité sur le champ `operand` du combinateur `not` ne sont pas testées. `_listEquals` a des branches (null, length-mismatch, element-mismatch) non exercées. *Fichier : idem.*

- **[LOW-3] `@ZcrudField.config` testé en annotation avec `ZTextConfig` seul.** `ZNumberConfig`/`ZDateConfig` sont testés isolément mais jamais imbriqués dans une annotation `const` — couverture croisée annotation×config incomplète (cosmétique). *Fichier : `packages/zcrud_annotations/test/annotations_const_test.dart`.*

- **[LOW-4] Fusion `match`/`matchKey` de l'inventaire en un seul `ZValidatorSpec.match(refKey)`.** L'inventaire §3 liste `match` **et** `matchKey` ; l'implémentation n'expose que `match(refKey)` (⇒ `matchKey`). Le `match` littéral est couvert par `equal`. Conforme à l'ambiguïté #2 (« exhaustivité fine itérable ») — signalé pour traçabilité, pas un défaut.

---

## Trous de couverture détectés (synthèse)
- Portage de payload non asserté pour ~6 variantes `ZValidatorSpec` (LOW-1).
- Branches d'inégalité de `ZCondition`/`_listEquals` + égalité du champ `operand` (`not`) non testées (LOW-2).
- Pas de test annotation×`ZNumberConfig`/`ZDateConfig` (LOW-3).

Aucun de ces trous n'affecte un AC bloquant : la `const`-constructibilité (objectif AC11, lisibilité `ConstantReader`) est prouvée pour **toutes** les variantes ; les valeurs d'enum sont **toutes** exercées (`containsAll` sur `EditionFieldType`, `ZValidatorKind`, `ZFieldRename` ; chaque `ZConditionOp` construit).

---

## Recommandation
**APPROVED.** Story prête pour `done`. Les LOW peuvent être adressés opportunément (renforcement de tests triviaux) ou consignés — aucun ne justifie de bloquer la transition. Aucun MEDIUM à corriger ou justifier.
