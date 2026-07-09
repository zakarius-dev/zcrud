# Code Review — E2-6 : Adaptateurs de schéma existant (`ZModelAdapter` / `JsonSerializableAdapter` / `ReflectableCodec`)

- **Story** : `_bmad-output/implementation-artifacts/stories/e2-6-adaptateurs-schema-existant.md` (9 ACs, statut `review`)
- **Baseline** : `8f2875559aee498774eca8590744e816f8a5c93f`
- **Reviewer** : bmad-code-review (skill réel, chemin pris : tool `Skill{bmad-code-review}` → step-01/02 chargés)
- **Date** : 2026-07-09
- **Enjeu central** : confinement de l'unique exception `reflectable` (AD-3).

## Verdict : **APPROVED**

0 HIGH · 0 MAJEUR · 1 MEDIUM (justifié/déféré) · 2 LOW. Aucune fuite `reflectable` hors chemin allowlisté, aucun `*.reflectable.dart` sous `packages/`, tous les gates verts. Les findings n'exigent aucune correction bloquante dans le périmètre E2-6.

---

## Résultats de vérification RÉELLEMENT rejoués sur disque

| Contrôle | Résultat |
|---|---|
| `grep -rl 'package:reflectable/' packages/` | **1 seul fichier** : `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart` (ligne 22 import + ligne 8 docstring) — rien d'autre ✅ |
| `find packages -name '*.reflectable.dart'` | **0** ✅ |
| `dart run scripts/ci/gate_reflectable.dart` | `gate:reflectable OK` — **RC=0** ✅ |
| `zcrud_core` importe reflectable/json_serializable/json_annotation ? | **0** (flutter uniquement dans `presentation`, conforme AD-2 ChangeNotifier/ValueListenable) ✅ |
| `zcrud_core/lib/src/data/**` imports | **pur-Dart** : uniquement `../../domain/…` (z_field_spec, zcrud_registry) ✅ |
| `melos run analyze` | **SUCCESS**, 0 issue / 14 pkgs ✅ |
| `melos run test` | **SUCCESS** — total **241** (dart 38 : annotations 8 + generator 30 ; flutter 203 : core 170 + get 17 + provider 8 + riverpod 8) ✅ |
| `gate:graph` | **CORE OUT=0**, 14 nœuds, 17 arêtes, ACYCLIQUE OK ✅ |
| `gate:melos` | OK (13 scripts identiques) ✅ |
| `gate:compat` | OK (voie manifeste verte, analyzer 8.4.1) ✅ |
| `gate:codegen` | OK (1 modèle `@ZcrudModel`, 0 `.g.dart` manquant) ✅ |
| `gate:secrets` | OK ✅ |
| `verify` | **RC=0** (slot `verify:serialization` no-op documenté jusqu'à E2-10) ✅ |
| `.g.dart` / `.reflectable.dart` suivis par git | **0** ✅ |
| `melos list` | **14** ✅ |

---

## Couverture des Acceptance Criteria

| AC | Statut | Preuve |
|----|--------|--------|
| **AC1** Contrat `ZModelAdapter<T extends Object>` pur-Dart, `registerInto` → `register<T>(kind, fromMap:, toMap:, fieldSpecs:)` | ✅ | `z_model_adapter.dart:78-85` ; purity OK ; gate:reflectable inchangé |
| **AC2** `JsonSerializableAdapter` expose un `@JsonSerializable` sans builder zcrud | ✅ | `json_serializable_adapter.dart` enveloppe `fromJson`/`toJson` injectés ; round-trip via registre `..._test.dart:73-87` |
| **AC3** freezed non requis / reflectable non imposé à lex | ✅ | modèle de test `final`+`const`, 0 dep freezed/reflectable au cœur |
| **AC4** `ReflectableCodec` au chemin EXACT + réflexion injectée | ✅ | port `ZReflectionCapability` injecté (seam AD-6) ; testable sans `initializeReflectable()` |
| **AC5** `fieldSpecs` fournis, pas inférés | ✅ | défaut `const []` ; transmis tel quel ; `..._test.dart:116-133` (avec/sans specs) |
| **AC6** Round-trips via registre + gate vert | ✅ | lex + DODLP `decode(encode(x))==x` ; `ZUnregisteredTypeError`/`ZDuplicateRegistrationError` ; gate RC=0 ; garde `*.reflectable.dart`=0 |
| **AC7** Désérialisation défensive (AD-10) | ✅ | `fromMapSafe → null` ; map valide → identique, map corrompue → null (`..._test.dart:135-164`) |
| **AC8** Barrels & docstrings FR | ✅ | `zcrud_core.dart:19-20`, `zcrud_get.dart:15` ; docstring « seule exception AD-3 » présente |
| **AC9** Vérif verte bout en bout | ✅ | cf. tableau ci-dessus |

---

## Findings (triage adversarial)

### MEDIUM-1 — La voie défensive `fromMapSafe` (AD-10) n'est pas atteignable via `ZcrudRegistry`, l'interface aval documentée pour E5 *(justifié / déféré)*
- **Fichiers** : `packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart:63-69` ; contrat `registry.decode` (`zcrud_registry.dart:125-131`).
- **Constat** : `registerInto` n'enregistre au registre que la voie **stricte** (`fromMap`). `registry.decode(kind, map)` — présenté par la story comme l'alimentation aval de E5 (« chaîne de valeur : E5 Firestore : `registry.decode(kind, map)` ») — délègue donc au `fromMap` **strict** et **lève** sur une map corrompue. Le mode défensif `fromMapSafe` ne vit que sur l'instance d'adaptateur ; or E5, ne détenant que le `ZcrudRegistry` (qui stocke un `ZModelCodec` sans slot défensif), ne peut pas l'atteindre. La capacité AD-10 est correcte et testée au niveau adaptateur, mais **orpheline** côté registre.
- **Pourquoi non bloquant en E2-6** : c'est une décision **explicitement tranchée** par la story (Ambiguïté #4 : « le registre enregistre la voie stricte ; `fromMapSafe` est l'entrée tolérante côté frontière E5 ») ; le contrat `ZcrudRegistry` (E2-3) est **gelé** ; AC7 n'exige que l'offre + le test du mode défensif sur l'adaptateur — satisfait. Rien à corriger dans le périmètre E2-6 sans toucher un contrat hors-périmètre.
- **Action recommandée (à porter en E5/E8-1)** : soit E5 conserve les références d'adaptateur pour invoquer `fromMapSafe` sur données non fiables, soit exposer additivement une `decodeSafe(kind, map) → Object?` sur `ZcrudRegistry`. **À consigner dans la story E5** pour que la frontière défensive AD-10 soit réellement câblée là où les documents corrompus arrivent.

### LOW-1 — Le chemin DODLP ne teste pas la transmission des `fieldSpecs`
- **Fichier** : `packages/zcrud_get/test/data/codecs/reflectable_codec_test.dart`.
- **Constat** : aucun test ne construit un `ReflectableCodec` avec `fieldSpecs` non vides + `registry.fieldSpecsFor`. Le chemin lex le couvre (`json_serializable_adapter_test.dart:128-132`) et le comportement est **hérité à l'identique** de `ZModelAdapter.registerInto` — gap trivial, aucun risque de régression.

### LOW-2 — La capacité réflexive de PRODUCTION `ReflectableMirrorCapability` a une couverture 0 *(inhérent / déféré E7-2)*
- **Fichier** : `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart:80-108`.
- **Constat** : le SEUL code runtime qui touche réellement `reflectable` (`_reflector.reflect(value).invokeGetter(field)`) n'est exercé par aucun test — les preuves passent par le double `FakeDossierReflection`. C'est **inhérent** à la contrainte du gate (exercer le vrai reflector exigerait un `*.reflectable.dart` sous `packages/`, que le gate rejetterait) et **explicitement déféré à E7-2** (câblage sur le vrai reflector DODLP, hors `packages/`), ce qui est documenté dans le fichier et la story. À accepter tel quel ; le risque de régression sur `toMap` par introspection ne se matérialisera qu'au câblage E7-2 — **à couvrir là-bas**.

---

## Points de vigilance adversariaux — vérifiés OK

- **Confinement reflectable (CRITIQUE)** : import `package:reflectable/` présent dans **exactement** le fichier allowlisté ; le cœur n'est jamais exempté (`_neverExemptPackages=['zcrud_core']`) ; gate RC=0 ; 0 `.reflectable.dart`. **Aucune fuite.**
- **Réflexion réellement injectée (seam, pas `initializeReflectable()` caché)** : `ReflectableCodec` ne dépend que du port `ZReflectionCapability` ; aucun appel `initializeReflectable()` dans `packages/`. Seam AD-6 respecté.
- **Sans réécriture (FR-11)** : `JsonSerializableAdapter` consomme les `fromJson`/`toJson` **fournis** ; round-trip prouvé **via le registre** (`decode(encode(x))==x`) ; 0 dep freezed/json_serializable ajoutée au cœur (modèle de test hermétique, `fromJson`/`toJson` à la main).
- **Défensif (AD-10)** : `fromMapSafe` capture `on Object` — choix **correct et load-bearing** : un cast raté (`json['annee'] as int` sur `'NaN'`) lève un `TypeError` (sous-type d'`Error`, pas `Exception`) ; un `on Exception` l'aurait manqué et fait remonter au parent. Le test `..._test.dart:158-162` le prouve. Aucune corruption silencieuse d'une map valide.
- **Registre (E2-3)** : `registerInto` délègue à la signature gelée ; collision → `ZDuplicateRegistrationError`, kind absent → `ZUnregisteredTypeError` — testés sur les deux chemins.
- **Pureté & graphe** : `lib/src/data/**` n'importe que `domain` ; `reflectable`/`get`/`get_it` uniquement dans `zcrud_get` (non `zcrud_*` → CORE OUT=0 préservé, 14 nœuds/17 arêtes inchangés).
- **Version `reflectable: ^5.2.3`** : justifiée (4.x épingle `build ^2.x`, incompatible avec `build ^3.0.0` du `zcrud_generator`) ; `gate:compat` vert ; ajoutée à `zcrud_get` uniquement.
