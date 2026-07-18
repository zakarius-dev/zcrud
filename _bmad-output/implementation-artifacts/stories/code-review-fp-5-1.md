# Code Review — fp-5-1 (Additions cœur de Finitions : `pin`/`autocomplete`/`editableTable` + `ZSubListDisplayMode.tags`)

Périmètre de correction : **`packages/zcrud_core/` UNIQUEMENT** (+ prose story). Aucun changement d'API/enum public. Aucun autre package touché.

## Findings × statut × preuve

| # | Finding | Sévérité | Statut | Preuve (rejouée sur disque) |
|---|---|---|---|---|
| MED-1 | Double annonce du libellé de section : `Semantics(container: true, label: resolvedLabel)` englobe SANS `excludeSemantics`/`MergeSemantics` un `Text(resolvedLabel)` visible → le lecteur d'écran annonce le libellé DEUX FOIS. Motif présent en **tags** (~696), **inline** (~334) et **compact** (~604). | MEDIUM (a11y, AD-13) | **Corrigé (3 modes)** | Correctif : `label:` retiré des 3 `Semantics(container:)` ; le `container: true` conserve la frontière sémantique (groupement), le `Text` visible fournit le nom accessible unique. Test porteur (`fp_5_1_tags_mode_test.dart`, groupe MED-1) : `find.bySemanticsLabel('Items')` → **ROUGE avant** (`Found 0 widgets` : avec `label:` le nœud fusionne en `Items\nItems`, aucun nœud exactement « Items »), **VERT après** (`findsOneWidget`). |
| MED-2 | `InputChip` du mode tags n'épingle pas `materialTapTargetSize` → sous un thème `materialTapTargetSize: shrinkWrap` la puce (et son `onDeleted`) tombe < 48 dp. | MEDIUM (AD-13) | **Corrigé** | Correctif : `materialTapTargetSize: MaterialTapTargetSize.padded` épinglé sur l'`InputChip` (indépendant du thème ambiant). Test porteur (groupe MED-2) : montage sous `MaterialApp(theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))` avec 1 item → `getSize(InputChip).height >= 48` : **ROUGE avant** (`Actual: <false>`), **VERT après**. Couvre aussi LOW #1 (la puce est désormais mesurée, pas seulement le bouton add). |
| LOW-3 | Prose AC-A3 fausse : affirme qu'un champ `List<Map<String,dynamic>>?` round-trippe via le chemin `List<T>` — FAUX (build_runner lève sur `Map` ; le champ a été retiré du corpus). | LOW (prose) | **Corrigé (prose)** | AC-A3 + §« Preuve générateur NON touché » réécrites : `editableTable` est **nommé + routé (`registryOrFallback`) + repli-testé** (dispatch → `ZUnsupportedFieldWidget`), mais sa (dé)sérialisation `List<Map>` **n'est PAS supportée par le générateur** (limite préexistante : `_classify` récurse sur `Map`, aucune branche → `InvalidGenerationSourceError`) ⇒ à couvrir par un **type de valeur dédié + codec** dans une story ultérieure. |
| LOW-4 | Prose « git diff générateur vide » (~97) et attribution du `+23` à « fp-4-x » (~178) — FAUX : le `+23` (`_Cat.dateRangeType`/`_$asDateRange`) vient de **fp-1-1 (dateRange)**. | LOW (prose) | **Corrigé (prose)** | §Preuve + Completion Notes réécrites : fp-5-1 n'a **ajouté aucune ligne** au générateur `lib/` (D1 respecté, grep négatif), mais le diff générateur **n'est pas vide** dans l'arbre partagé — il porte l'apport dateRange de **fp-1-1** (story antérieure), **pas** fp-4-x. La preuve exacte est « fp-5-1 n'ajoute aucune `_Cat`/helper », non « diff générateur vide ». |

## Contrainte API/enum public

**Aucun changement d'API publique ni d'enum de `zcrud_core`.** Les corrections MED-1/MED-2 sont des internals a11y (`Semantics`/`materialTapTargetSize`) dans `z_sub_list_field_widget.dart` (widget de présentation) ; les signatures publiques (`ZSubListFieldWidget`, `ZSubListDisplayMode`, `EditionFieldType`) sont inchangées — les dépendants qui compilent contre le cœur en parallèle ne sont pas impactés.

## Vérif verte rejouée (sur disque)

- `flutter test packages/zcrud_core` → **RC=0, 996 tests** (994 initiaux + 2 porteurs code-review).
- `dart test` (CWD `packages/zcrud_generator`) → **RC=0, 127 tests**.
- `dart analyze packages/zcrud_core` → **RC=0** (3 `info` de dépréciation préexistants dans `z_batch_action_test.dart`, hors périmètre ; le fichier de test modifié est **`No issues found`**).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK + CORE OUT=0 OK** (out-degree `zcrud_core` inchangé = 0).

## Red-before / green-after (discipline R3)

Les 2 tests porteurs ont été prouvés **falsifiables** : reversion temporaire des correctifs de production (via édition, aucun `git checkout`) → les 2 tests rougissent (MED-1 `Found 0`, MED-2 `height < 48`) ; réapplication → verts. Aucun test existant n'a été affaibli.
