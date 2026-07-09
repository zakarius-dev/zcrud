# Code Review — Story E2-3 : Registre & extensibilité (ZcrudRegistry / ZTypeRegistry / ZSourceRegistry / ZExtension / extra)

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, chemin pris = **skill réel**, step-file architecture `.claude/skills/bmad-code-review/steps/step-01..04`).
- **Date** : 2026-07-09
- **Reviewer** : agent BMAD adversarial (effort high)
- **Story** : `_bmad-output/implementation-artifacts/stories/e2-3-registre-extensibilite.md` (12 ACs, statut `review`)
- **Baseline** : `8f2875559aee498774eca8590744e816f8a5c93f` — fichiers **tous nouveaux** (untracked) sous `packages/zcrud_core/`
- **Mode** : `full` (spec fournie)
- **Verdict** : **APPROVED** ✅ (0 HIGH, 0 MAJEUR, 0 MEDIUM ; 3 LOW/nits)

---

## 1. Périmètre revu

**Source (`packages/zcrud_core/lib/src/domain/`)**
- `registry/z_registry_error.dart` — `ZUnregisteredTypeError`, `ZDuplicateRegistrationError` (sous-types de `Error`)
- `registry/z_codec_registry.dart` — container générique interne `ZCodecRegistry<T>`
- `registry/zcrud_registry.dart` — `ZModelCodec` (+ `ZFromMap`/`ZToMap`) + `ZcrudRegistry`
- `registry/z_open_registry.dart` — `ZValueCodec` (+ `ZFromJson`/`ZToJson`) + base abstraite `ZOpenRegistry`
- `registry/z_type_registry.dart` — `ZTypeRegistry`
- `registry/z_source_registry.dart` — `ZSourceRegistry`
- `extension/z_extension.dart` — `ZExtension` (+ `guard`)
- `extension/z_extensible.dart` — mixin `ZExtensible` (+ helper `zExtraRead`)
- `lib/zcrud_core.dart` — barrel (+8 exports, ordre alphabétique)

**Tests (`packages/zcrud_core/test/`)**
- `domain/registry/zcrud_registry_test.dart`
- `domain/registry/z_type_source_registry_test.dart`
- `domain/extension/z_extension_test.dart`
- `domain/extension/z_extensible_test.dart`
- `purity/domain_purity_test.dart` (existant — couvre les nouveaux dossiers, resté vert)

---

## 2. Vérif verte REJOUÉE réellement sur disque

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyze | `dart run melos run analyze` | **SUCCESS — 14 packages, 0 issue** (RC=0) |
| Tests | `dart run melos run test` | **SUCCESS — zcrud_core : 140 tests, All tests passed** (RC=0) |
| Verify | `dart run melos run verify` | **RC=0** |
| Graphe AD-1 | `graph_proof.py` | `total arêtes = 17` ; `out-degree(zcrud_core) = 0` ; **ACYCLIQUE OK** ; **CORE OUT=0 OK** |
| Pureté domaine | grep imports interdits sous `registry/`+`extension/` | **0 hit** ; `domain_purity_test.dart` vert |
| melos list | `dart run melos list` | **14 packages** |

Conforme aux nombres attendus par la story (140 tests, out-degree 0, 14 packages).

---

## 3. Audit des invariants adversariaux (grounding architecture.md / canonical-schema.md)

### Dualité d'erreur AD-3 (throw) vs AD-10 (null) — **CONFORME**
- `ZcrudRegistry.codecFor(kind)` sur kind inconnu → `throw ZUnregisteredTypeError` (frontière modèle stricte, `z_codec_registry.dart:50-56` via `entryFor`). ✅
- `ZUnregisteredTypeError`/`ZDuplicateRegistrationError` **étendent `Error`**, PAS `ZFailure` (`z_registry_error.dart:25,52`). Test `zcrud_registry_test.dart:114-118` prouve `isA<Error>()` **et** `isNot(isA<ZFailure>())` → un bug de config n'est jamais `fold`é dans un `Either`. ✅
- `tryCodecFor(kind)` / `tryEntryFor(kind)` → `null` défensif (`z_codec_registry.dart:60`, `zcrud_registry.dart:89`). ✅
- `ZExtension.guard<T>` (`z_extension.dart:45-51`) : `try { parse() } catch (_) { null }` — **bare `catch`** (capte `Exception` **ET** `Error`). Point subtil correct : le cast `json['formatVersion'] as int` sur `'x'` lève un `TypeError` (sous-type de `Error`) ; si le dev avait écrit `on Exception`, l'AC7 (« type inattendu → null ») aurait crashé le parent. Le `catch (_)` nu est donc **requis** par AD-10, pas un anti-pattern ici. Test `z_extension_test.dart:59-64` verrouille explicitement « capture aussi les Error ». ✅
- Test mental payloads corrompus : `null`, clés manquantes, `formatVersion:'x'` (type faux), `formatVersion:99` (version future inconnue) → **`null` à chaque fois, `returnsNormally`** (`z_extension_test.dart:67-101`). **Aucun chemin trouvé où une extension corrompue fait crasher le parent.** Le cœur ne fournit que `guard` ; le `fromJsonSafe` concret est satellite, prouvé via `FakeExt`. ✅ (pas de violation AD-10)

### REJETS AD-4 — **CONFORME**
- `ZCodecRegistry<T extends Object>` est un générique de **CONTENEUR** (`Map<String,T>`), documenté explicitement `z_codec_registry.dart:7-11` comme « PAS un generic de sérialisation ». `T` = type de l'entrée stockée (un codec), jamais un mécanisme (dé)sérialisant via le paramètre de type. ✅
- Pas de `sealed` inter-package : `ZExtension` = `abstract class` (`z_extension.dart:25`), `ZOpenRegistry` = `abstract class` (`z_open_registry.dart:52`), `ZFailure` inchangé. Extensibilité inter-package préservée (constructeurs `const`, aucun modificateur `base`/`final`/`interface`). ✅
- Pas d'héritage de **classes sérialisées** : `ZTypeRegistry`/`ZSourceRegistry extends ZOpenRegistry` — mais `ZOpenRegistry` ne porte **aucune** (dé)sérialisation propre (seul le câblage register/lookup), point adressé en docstring `z_open_registry.dart:49-51`. Le rejet AD-4 vise l'héritage de classes **sérialisées**, pas le partage d'une base de comportement. ✅

### Registre injectable — **CONFORME**
- Aucun singleton statique global mutable : `ZcrudRegistry()`, `ZTypeRegistry()`, `ZSourceRegistry()` sont des **instances** (constructeurs publics, état `_entries`/`_codecs` d'instance privé). Isolation inter-instance **testée** (`zcrud_registry_test.dart:150-156`, `z_type_source_registry_test.dart:97-103`). ✅
- Collision de kind → `throw ZDuplicateRegistrationError` (pas de last-wins silencieux) : check `containsKey` **avant** insertion (`z_codec_registry.dart:38-43`), donc l'entrée existante n'est jamais écrasée. Testé pour les 3 registres. ✅

### ZExtensible — **CONFORME**
- `mixin ZExtensible` (`z_extensible.dart:18-26`) déclare `ZExtension? get extension` + `Map<String,dynamic> get extra` (type **non-nullable** → `null` impossible au niveau type). **NON mixé dans `ZEntity`** (E2-1 intact, non touché). Défaut `const {}` porté par l'implémentation (`FakeEntity` test `z_extensible_test.dart:19`), documenté. ✅

### Consommabilité E2-5 (AC11) — **CONFORME**
- `registerFakeModel(ZcrudRegistry r)` (`zcrud_registry_test.dart:33-39`) prend une **instance** en paramètre → prouve que le codegen E2-5 émettra des `registerXxx(ZcrudRegistry r)` injectables. Round-trip complet `decode(encode(model)) == model` (`:72-77`). ✅
- Slot `ZFieldSpec` différé : `ZcrudRegistry` v1 porte `fromMap`/`toMap` seulement ; point d'extension additif documenté (`zcrud_registry.dart:43-48`), **aucun `Object?` non typé pré-câblé** (pas de fuite d'API). ✅

### Pureté domaine (AD-1/AD-14) — **CONFORME**
- Grep imports interdits sous `registry/`+`extension/` = **0**. `zcrud_core` out-degree 0 préservé (aucune dép `zcrud_*`/backend/manager ajoutée). ✅

---

## 4. Findings (triage par sévérité)

### HIGH — aucun
### MAJEUR — aucun
### MEDIUM — aucun

### LOW / nits

**LOW-1 — Docstring obsolète : `ZOpenRegistry` déclarée « non exportée » alors qu'elle EST exportée.**
`z_open_registry.dart:45-47` affirme : « *Base fine des registres ouverts. **Non exportée telle quelle** : les apps hôtes utilisent les sous-types nommés* ». Or le barrel `zcrud_core.dart:40` fait `export 'src/domain/registry/z_open_registry.dart';`, qui expose bien `ZOpenRegistry` **et** `ZValueCodec` dans l'API publique. L'export est en réalité **nécessaire** (le test `z_type_source_registry_test.dart` importe `ZOpenRegistry` via le barrel pour paramétrer type+source). La docstring est donc factuellement fausse.
- **Route** : patch trivial. Corriger la docstring (« exposée via le barrel comme base fine ; les apps utilisent de préférence les sous-types nommés ») OU, si l'intention était de garder la base hors API, exporter uniquement `ZValueCodec` et faire importer le test depuis `src/`. Recommandation : **corriger la docstring** (l'export est justifié par la paramétrisation des tests + cohérence avec `ZModelCodec`).
- **Fichier** : `packages/zcrud_core/lib/src/domain/registry/z_open_registry.dart:45`

**LOW-2 — Sur-export vs liste AC10 (`ZOpenRegistry`/`ZValueCodec` non listés).**
AC10 énumère les exports attendus (`ZcrudRegistry`+`ZModelCodec`, `ZTypeRegistry`, `ZSourceRegistry`, les 2 erreurs, `ZExtension`, `ZExtensible`, « `ZCodecRegistry` si jugé public ») sans mentionner `ZOpenRegistry`/`ZValueCodec`. Le dev les exporte (barrel `:39-40`). Déviation mineure et **justifiée** (base de comportement partagée + type codec parallèle à `ZModelCodec`, requis par les tests paramétrés). À consigner, pas bloquant.
- **Fichier** : `packages/zcrud_core/lib/zcrud_core.dart:39-40`

**LOW-3 — Divergence terminologique story↔impl (`implements` vs `extends`).**
La stratégie de tests de la story (`e2-3-…md:238`) décrit `FakeExt implements ZExtension` ; l'impl utilise `class FakeExt extends ZExtension` (`z_extension_test.dart:10`) et `_Ext extends ZExtension`. Immatériel (mêmes garanties, `ZExtension` n'a que des membres abstraits + un `static` + un ctor `const`), mais souligne que l'usage canonique de sous-typage de `ZExtension` gagnerait à être fixé (extends OU implements) pour les satellites E9/E10.
- **Fichier** : `packages/zcrud_core/test/domain/extension/z_extension_test.dart:10`

---

## 5. Trous de couverture examinés

| Piste adversariale | Statut |
|---|---|
| Collision de kind non testée | **Couverte** — testée pour `ZcrudRegistry`, `ZTypeRegistry`, `ZSourceRegistry` |
| `guard` sur exception non-`FormatException` | **Couverte** — `StateError` + `ArgumentError` (Error) testés (`z_extension_test.dart:51-64`) |
| Round-trip d'une version future inconnue | **Couverte** — `formatVersion:99 → null` (`:83-88`) |
| Isolation inter-instance / espaces de noms séparés (OQ-6) | **Couverte** — `:150-156`, `:107-116` |
| `ZUnregisteredTypeError` non-`ZFailure` | **Couverte** — `:114-118` |
| **`encode(kind, valeurDeMauvaisType)`** → `toMap(value as T)` (`zcrud_registry.dart:72`) lève un `TypeError` | **Non testé** — comportement acceptable (un `Error` sur mauvais type au bootstrap, cohérent avec « erreurs de config = Error »), mais ni documenté ni couvert. Gap **mineur** (LOW), non bloquant — le codegen produit toujours des couples typés cohérents. |

Aucun trou de couverture bloquant. La cible ~140 tests est atteinte (140).

---

## 6. Audit des 12 ACs

| AC | Verdict | Preuve |
|---|---|---|
| AC1 Pureté domaine | ✅ | grep 0 hit ; `domain_purity_test` vert ; out-degree 0 |
| AC2 `ZcrudRegistry` API complète | ✅ | `zcrud_registry.dart:62-99` ; tests `:42-56` |
| AC3 Kind inconnu → throw `Error` | ✅ | `:85` ; tests `:80-118` |
| AC4 Collision → throw | ✅ | `z_codec_registry.dart:38-43` ; tests `:133-147` |
| AC5 `ZTypeRegistry`/`ZSourceRegistry` | ✅ | `z_open_registry.dart` ; tests paramétrés type+source |
| AC6 `ZExtension` abstract versionné + `guard` | ✅ | `z_extension.dart` |
| AC7 `fromJsonSafe`/`guard` ne throw jamais | ✅ | tests `:67-101` (incl. capture `Error`) |
| AC8 Round-trip + `extra` préservé | ✅ | `z_extension_test.dart:103-116` ; `z_extensible_test.dart:44-56` |
| AC9 `ZExtensible` non mixé dans `ZEntity` | ✅ | mixin fin ; `ZEntity` non touché |
| AC10 Barrel & exports | ✅ (LOW-1/LOW-2) | ordre alphabétique OK (analyze RC=0) ; sur-export mineur |
| AC11 Consommabilité E2-5 | ✅ | `registerFakeModel(r)` + round-trip via registre |
| AC12 Vérif verte | ✅ | analyze/test/verify/graph tous verts (§2) |

**12/12 ACs satisfaits.**

---

## 7. Verdict

**APPROVED** ✅

Les deux régimes d'erreur (AD-3 throw / AD-10 null) sont encodés sans ambiguïté et verrouillés par des tests ciblés. Aucune violation AD-4 (générique de conteneur documenté, pas de `sealed` inter-package, pas d'héritage de classe sérialisée), AD-10 (aucun chemin d'extension corrompue qui casse le parent), ni AD-1 (pureté + out-degree 0). Registres injectables (instances, isolation testée), collision → throw. Vérif verte réellement rejouée sur disque (analyze 14 pkg / test 140 / verify RC=0 / CORE OUT=0 / 14 packages).

Les 3 findings LOW (docstring `ZOpenRegistry` obsolète, sur-export mineur vs AC10, terminologie extends/implements) sont **optionnels** et non bloquants ; LOW-1 est un patch trivial recommandé pour éviter une docstring trompeuse. Aucun HIGH/MAJEUR/MEDIUM à corriger avant `done`.
