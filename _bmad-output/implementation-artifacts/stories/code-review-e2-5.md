# Code-review adversariale — Story E2-5 (Générateur build_runner, cœur codegen AD-3 + défensif AD-10)

- **Story :** `_bmad-output/implementation-artifacts/stories/e2-5-generateur-build-runner.md`
- **Statut à l'entrée :** `review` — 11 ACs, baseline `8f2875559aee498774eca8590744e816f8a5c93f`
- **Chemin skill pris :** tool `Skill(bmad-code-review)` chargé OK (step-file architecture `.claude/skills/bmad-code-review/steps/step-01..02`). Mode subagent autonome : cible déjà spécifiée (story + baseline + spec), pas de HALT interactif. Couches jouées mentalement : Blind Hunter (correctness), Edge-Case Hunter (AD-10/corruption), Acceptance Auditor (11 ACs).
- **Date :** 2026-07-09

## Verdict : ⚠️ CHANGES REQUESTED

1 HIGH/MAJEUR (AD-10, **empiriquement prouvé**) + 2 MEDIUM + 2 LOW. Le HIGH est une brèche démontrée du contrat central de la story (« LE point critique » — désérialisation défensive AD-10). Correction attendue avant `done` (fix trivial, une helper partagée).

---

## Résultats de vérification REJOUÉS réellement sur disque

| Vérif | Résultat |
|---|---|
| `melos run generate` | **RC=0** — `article.g.dart` (6.3 ko) régénéré sur disque |
| `melos run analyze` | **RC=0** — `No issues found` sur les 14 packages (`.g.dart` inclus) |
| `melos run test` | **RC=0** — **222 tests** (core 160, generator 26, get 12, annotations 8, riverpod 8, provider 8) |
| `melos run verify` | **RC=0** — dont `verify:serialization` (2 tests taggés `serialization-compat`) |
| `prove_gates` | **22 OK / 0 FAIL** |
| `gate:codegen` nominal | **RC=0** (`1 modèle @ZcrudModel, 0 .g.dart manquant`) |
| `gate:codegen` fixture (`.g.dart` retiré) | **RC=1** — échoue correctement, `VIOLATION AD-3` sur `article.dart`, régénéré → RC=0 |
| `gate:reflectable` | **RC=0** — `0 usage de reflectable hors allowlist`. `grep reflectable packages/**` = uniquement docstrings/commentaires (« banni »), **0 import** |
| `gate:compat` | **RC=0** — voie manifeste résout `analyzer 7.7.1`, `flutter_quill 11.5.1`, `awesome_select 6.0.0` |
| graph proof (`scripts/dev/graph_proof.py`) | **ACYCLIQUE OK, CORE OUT=0 OK**, 14 nœuds, 17 arêtes ; `zcrud_generator → zcrud_core` (+ `zcrud_annotations`), aucune arête interdite |
| `.g.dart` committés | **0** (`git ls-files | grep -c '\.g\.dart$'` = 0 ; gitignoré, régénéré) |
| `melos list` | **14** packages |

Toolchain codegen (`analyzer 8.4.1` / `source_gen 4.2.3` / `build 3.1.0` / `build_runner 2.7.1`) confinée à `zcrud_generator` — ne fuit pas dans le cœur.

---

## Findings

### 🔴 HIGH / MAJEUR — H1 : `fromMap` d'un sous-objet à clés non-`String` CASSE le parent (violation AD-10, AC3)

- **Fichier :** `packages/zcrud_generator/lib/src/zcrud_model_generator.dart:253` (`_Cat.subModel`) et `:266` (`_Cat.listModel`).
- **Code émis** (`article.g.dart:63-65`) :
  ```dart
  author: map['author'] is Map
      ? Author.fromMap(Map<String, dynamic>.from(map['author'] as Map))
      : null,
  ```
- **Défaut :** `Map<String, dynamic>.from(x)` **jette** un `TypeError` dès que la map corrompue porte une clé non-`String`. Le garde `is Map` laisse passer un `Map<dynamic,dynamic>{1: …}`, puis `.from` casse — et l'exception **remonte au parent**, qui ne se construit jamais. C'est exactement le scénario que l'AC3 interdit (« sous-objet imbriqué corrompu → parsing défensif ; le parent se construit quand même ») et le patron Dev Notes §fromMap-défensif (`map['k'] is Map ? _safeFromMap(...) : null`, « **sans** propager au parent ») n'est PAS respecté : `_safeFromMap` (capture du parsing malformé) n'a jamais été implémenté ; on appelle directement le `fromMap` du sous-modèle sur une conversion non gardée.
- **Preuve empirique rejouée** :
  ```
  Article.fromMap({'title':'T','author':{1:'x','name':'y'}})
  → _TypeError: type 'int' is not a subtype of type 'String' in type cast   (parent NON construit)
  ```
- **Portée réelle (calibrage honnête) :** un pipeline JSON (`jsonDecode`) ou Firestore livre toujours des clés `String` → non exposé sur ce chemin. L'exposition réelle est la voie **Hive / données forgées / documents étrangers** (offline-first AD-9 : store local source de vérité) où une map `Map<dynamic,dynamic>` à clé non-`String` peut survenir. AD-10 est néanmoins **catégorique** (« ne fait *jamais* échouer le parent ») et la story désigne ce contrat comme son cœur ; le fix est trivial → traité en MAJEUR.
- **Même racine, chemin non couvert :** `_Cat.listModel` (`:266`, `List<@ZcrudModel>`) réutilise `Map<String, dynamic>.from(e)` par élément et jettera de même — mais aucun test ne l'exerce (cf. M2).
- **Correction proposée :** helper partagé défensif, p.ex.
  ```dart
  Map<String, dynamic>? _$asStringMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) { try { return v.map((k, val) => MapEntry(k.toString(), val)); } catch (_) { return null; } }
    return null;
  }
  ```
  puis émettre `final _a = _$asStringMap(map['author']); author: _a != null ? Author.fromMap(_a) : $def;` (idem pour `listModel` : `.map(_$asStringMap).whereType<Map<String,dynamic>>().map(T.fromMap)`). Ajouter un test « sous-objet à clé non-String → parent survit ».

### 🟠 MEDIUM — M1 : le manifeste `gate:compat` épingle `analyzer ^7` alors que le codegen tourne sous `analyzer ^8` → FR-25 ne prouve pas la vraie toolchain

- **Fichiers :** `tool/compat_check/pubspec.yaml` (`analyzer: ^7.0.0`, `build_runner: ^2.4.0`, `json_serializable: ^6.11.0`, résout **7.7.1**) vs `packages/zcrud_generator/pubspec.yaml:30-32` (`analyzer: ^8.0.0`, `source_gen: ^4.0.0`, `build: ^3.0.0`, résout **8.4.1** dans le workspace réel).
- **Défaut :** le manifeste justifie explicitement `analyzer ^7` comme « **compatible source_gen/build_runner du codegen E2-5** » et « analyzer ↔ build_runner/source_gen doivent co-résoudre ». Cette justification est désormais **périmée** : le codegen E2-5 n'utilise pas `analyzer ^7`, il a été **forcé à ^8** (résolution partagée `flutter_test/test → analyzer ≥8`, cf. Debug Log de la story). `gate:compat` prouve donc un triplet (`analyzer 7.7.1`) qui **diverge de la version sous laquelle le générateur s'exécute réellement** (`8.4.1`). Vis-à-vis de FR-25, la garantie de co-résolution de la toolchain codegen **n'est pas exercée** — le gate reste vert en testant autre chose que la réalité (fausse confiance).
- **Impact :** pas de bug runtime ; risque = régression de compat non détectée sur la vraie chaîne (`analyzer ^8`/`source_gen ^4`). Un breaking d'`analyzer 9.x`/`source_gen 5.x` passerait le gate (qui teste ^7) alors que le codegen casserait.
- **Jugement (point de vigilance « variance analyzer » de la mission) :** **incohérence à réconcilier**, classée **MEDIUM**. Deux options acceptables :
  1. **Aligner sur la réalité** — bumper le manifeste à `analyzer: ^8.0.0` (+ `source_gen: ^4.0.0`, `build: ^3.0.0`, `build_runner: ^2.5.0`) pour que `gate:compat` prouve la toolchain réellement utilisée. Recommandé.
  2. **Scinder les cibles** — si `analyzer ^7` est délibérément la cible de compat *applicative* lex_douane (distincte de la toolchain *dev* du générateur), le documenter comme tel et **retirer** la justification trompeuse « compatible … codegen E2-5 » du manifeste ; ajouter alors une branche `analyzer ^8` prouvant la toolchain du générateur.
  En l'état, la variance est *documentée dans le pubspec du générateur* mais **non réconciliée** côté manifeste FR-25.

### 🟠 MEDIUM — M2 : chemin d'émission `List<@ZcrudModel>` (`_Cat.listModel`) jamais couvert par un test

- **Fichier :** `zcrud_model_generator.dart:263-267` ; fixture `test/models/article.dart` (aucun champ `List<Author>`).
- **Défaut :** l'émission de liste de sous-modèles est du **code livré** (branche `_Cat.listModel` + fallback `:297`), mais le modèle de preuve `Article`/`Author` ne l'exerce pas — ni round-trip, ni défensif. Ce chemin partage la brèche H1 (`Map<String,dynamic>.from(e)`) et pourrait masquer d'autres bugs d'émission (`whereType<Map>()` + `.from`, `.map((e)=>e.toMap())` en `toMap`).
- **Correction proposée :** ajouter un champ `List<Author> coauthors` (ou une seconde fixture) couvrant : round-trip liste de sous-modèles + élément corrompu (non-map / map tronquée / clé non-String) → parent survit, éléments corrompus filtrés/défautés.

### 🟡 LOW — L1 : `copyWith(champNonNullable: null)` lève un `TypeError` de cast plutôt qu'une erreur explicite

- `article.g.dart:97` : `title: identical(title,_$undefined) ? this.title : title as String`. Passer `null` explicite sur un champ non-nullable fait `null as String` → `_TypeError`. Comportement acceptable (on ne peut pas nuller un non-nullable), mais l'erreur est un cast runtime opaque au lieu d'un `ArgumentError` parlant. Nit — documenter ou garder tel quel.

### 🟡 LOW — L2 : coercitions silencieuses lossy dans les helpers tolérants

- `_$asInt` tronque un `double` (`4.9 → 4` via `v.toInt()`), `_$asDouble`/`_$asNum` acceptent des `String`. Conforme au contrat « types tolérants » (canonique §5), mais la **troncature** double→int est une perte silencieuse ; un enum non-nullable **sans** `defaultValue` retombe sur `values.first` (`_fallback:291`) plutôt que sur une sentinelle « inconnue » dédiée. Acceptable (le modeleur déclare `defaultValue`), à consigner.

---

## Points de vigilance adversariaux — statut

- **Zéro reflectable (AD-3) :** ✅ 100% statique — `GeneratorForAnnotation<ZcrudModel>` + `TypeChecker.typeNamed` + `ConstantReader`/`ClassElement`/`FieldElement`, aucune instanciation/exécution d'annotation. `gate:reflectable` vert, 0 import.
- **`asNameMap`/`whereType` :** ✅ enum via `_$enumFromName` (boucle sur `value.name`, **jamais** `byName` nu), listes via `whereType<T>()` (nulls/corrompus filtrés). Correct — **sauf** la conversion de map de sous-objet (H1).
- **copyWith sentinelle :** ✅ `_$undefined = _ZUndefined()` + `identical(...)` sur **tous** les champs (nullable et non-nullable) ; reset-`null` prouvé (`copyWith(subtitle:null)` → null ; `copyWith()` → préserve).
- **Round-trip :** ✅ `toMap→fromMap` idempotent prouvé (enums camelCase `.name`, dates ISO-8601, sous-objets récursifs, clés snake_case, override `@ZcrudField(name:)` respecté).
- **ZFieldSpec[] & register :** ✅ projection 1:1 fidèle (label/validators/searchable/defaultValue/isId/multiple/inférence de type) ; `register(kind, fromMap, toMap, fieldSpecs)` câblé sur le slot additif E2-3 ; `kind` défaut = nom de classe (décision #5) cohérent ; slot `fieldSpecs` rétro-compatible, tests E2-3 verts.
- **Échec explicite (AC9) :** ✅ `InvalidGenerationSourceError` + `element` sur type non sérialisable (`Uri`) et collision de clé ; prouvé par `build_failure_test.dart` (via `resolveSource`, invisible pour `gate:codegen`).
- **Gates :** ✅ `gate:codegen` nominal RC=0 + échoue (RC=1) si `.g.dart` retiré ; 0 `.g.dart` committé ; analyze RC=0 ; toolchain codegen confinée (graph ACYCLIQUE, CORE OUT=0).

## Trous de couverture identifiés

1. **Sous-objet / liste de sous-objets à clés non-`String`** → non testé, et **casse le parent** (H1, prouvé). Le test « sous-objet corrompu » n'exerce que le cas *non-map* (`author: 'pas une map'`) et *tronqué* (clés valides), jamais la map à clés non-`String`.
2. **`List<@ZcrudModel>`** (`_Cat.listModel`) → aucun test round-trip ni défensif (M2).
3. **Enum non-nullable sans `defaultValue`** → fallback `values.first` non asservi par un test (L2).

## Recommandation

- **Corriger H1** (helper `_$asStringMap` défensif pour `subModel` + `listModel`) + test de non-régression → obligatoire avant `done`.
- **Corriger M1** (réconcilier le manifeste `gate:compat` avec `analyzer ^8`, ou scinder/re-documenter les cibles) et **M2** (couvrir `List<@ZcrudModel>`) — dans le périmètre de la story, sans régression.
- L1/L2 : optionnels (consignés).
- Re-jouer la vérif verte (generate/analyze/test/verify) après correction ; la story reste `review` jusqu'à re-vérif.
