---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.5 : Générateur build_runner (cœur du codegen AD-3) — `toMap`/`fromMap`/`copyWith` + `ZFieldSpec[]` + enregistrement

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du socle codegen de `zcrud`**,
je veux **implémenter le vrai builder `source_gen`/`build_runner` de `zcrud_generator` (dev_dependency) qui, à partir des annotations `const` `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` (E2-4) lues STATIQUEMENT via `analyzer`/`ConstantReader` (jamais `reflectable`, jamais d'exécution), émet dans un `part '<model>.g.dart'` : (1) `fromMap`/`toMap` DÉFENSIFS (AD-10 : champ absent → `defaultValue`, enum inconnu → `unknownEnumValue`, sous-objet corrompu → n'entraîne jamais l'échec du parent), (2) un `copyWith` À SENTINELLE (reset-`null` distinct de « non fourni »), (3) le `List<ZFieldSpec>` projeté depuis `@ZcrudField` (label/type/validators/config/choices/condition/searchable + extras), et (4) une fonction d'enregistrement `register(ZcrudRegistry)` câblant `kind → (fromMap, toMap, fieldSpecs)` — avec ÉCHEC EXPLICITE de build (message clair) si un type référencé n'est pas annotable/enregistrable**,
afin que **le modèle annoté devienne l'unique source de vérité (AD-3), que le premier vrai `.g.dart` active de bout en bout `gate:codegen` et le round-trip `toMap→fromMap` idempotent, et que la désérialisation défensive (AD-10) soit prouvée sur JSON tronqué / enum inconnu / champ manquant — le tout sans jamais réintroduire `reflectable` (banni, `gate:reflectable`) ni imposer `freezed`, et en préservant l'acyclicité AD-1 (`zcrud_generator → {zcrud_core, zcrud_annotations}`, cœur OUT=0 inchangé).**

## Contexte & valeur

**Position dans l'épic E2 (cœur + codegen + bindings).** Ordre intra-épic verrouillé (epics.md:61) : `E2-1 → E2-2 → E2-7 → E2-9` (contrats, ports, réactivité, injection — **done**) **avant** `E2-4/E2-5` (codegen complet). **E2-4 (done)** a livré la **surface d'autorité** (le *quoi*) : les 3 annotations `const` `@ZcrudModel`/`@ZcrudField`/`@ZcrudId`, l'enum `EditionFieldType` (39 valeurs), les types-valeur `const` `ZValidatorSpec`/`ZFieldChoice`/`ZCondition`/`ZFieldConfig`/`ZFieldRename`, et l'**entrée publique pure** `package:zcrud_core/edition.dart` (sans Flutter transitif). **E2-5 (cette story)** livre le *comment* : le **projecteur/générateur** (le builder) qui lit cette surface et **émet du code**. E3/E4 seront les *interprètes runtime* du `ZFieldSpec` émis.

**Ce que cette story matérialise — le CŒUR du codegen (AD-3).** C'est ici que se referme la boucle « modèle = source unique de vérité » :
- **Sérialisation** : `@ZcrudModel` → `fromMap`/`toMap` (persistance `fieldRename: snake`, enums camelCase avec `unknownEnumValue`) → alimente `ZcrudRegistry.register` (E2-3) → habilite les repositories/adapters (E2-2, E2-6, E5).
- **Schéma déclaratif** : `@ZcrudField` → `List<ZFieldSpec>` (projection 1:1 de la table de correspondance E2-4) → pilote formulaire (`DynamicEdition`, E3) **et** liste (`DynamicList`, E4) depuis le MÊME schéma.
- **Enregistrement** : `register(ZcrudRegistry)` généré → « type non enregistré → throw explicite » (AD-3) devient effectif au runtime, et le `.g.dart` produit **active `gate:codegen`** (qui, jusqu'ici, comptait « 0 modèle » — voir Dev Notes « Activation des gates »).

**Chaîne de valeur aval (consommateurs de E2-5) :**
- **E2-6 (adaptateurs de schéma existant)** : `ZCodec`/`JsonSerializableAdapter`/`ReflectableCodec` exposent une entité `@JsonSerializable` (lex) ou reflectable (DODLP) comme `ZcrudModel` — s'appuie sur le contrat de (dé)sérialisation posé ici.
- **E2-10 (gate rétro-compat sérialisation)** : fournit le **corpus complet** de tests `serialization-compat` ; E2-5 pose et **prouve** le contrat défensif (AD-10) que ce corpus étendra (voir « Activation des gates »).
- **E3 (édition granulaire)** : interprète chaque `ZFieldSpec` (type→widget, validators→`FormBuilderValidators`, condition→sélecteur de visibilité — AD-2).
- **E4 (liste)** : dérive colonnes + filtre depuis `ZFieldSpec.searchable`.
- **E5/E7 (Firestore/DODLP)** : `register` généré injecté au bootstrap (`ZcrudScope`/binding) → décodage `kind`-discriminé.

**Pourquoi « statique, jamais `reflectable` » est structurant (AD-3, pas décoratif).** Le builder lit les annotations **à froid** via `analyzer` (`ClassElement`/`FieldElement`) + `source_gen` (`GeneratorForAnnotation<ZcrudModel>` + `TypeChecker`) + `ConstantReader` (valeurs `const` compile-time — c'est précisément ce que E2-4 a garanti en rendant toute la surface `const`-constructible). Aucune annotation n'est jamais **instanciée ni exécutée**. `reflectable` (introspection runtime, banni par `gate:reflectable`) est donc inutile *par conception*. Le seul package où `analyzer`/`source_gen`/`build`/`build_runner` sont autorisés est **`zcrud_generator`** (dev_dependency, AD-1) : ils ne fuient jamais dans `zcrud_core` ni chez les consommateurs runtime.

## Périmètre strict de CETTE story (anti-empiètement)

**DANS le périmètre :**
- **`zcrud_generator`** (dev_dependency) : le vrai builder `source_gen` (remplace le squelette `ZGeneratorApi`), la config `build.yaml`, l'émission de `fromMap`/`toMap`/`copyWith`/`ZFieldSpec[]`/`register`, l'échec explicite de build, et le modèle de test annoté + tests (golden + round-trip + défensif).
- **`zcrud_core`** (couche `domain`, pur-Dart) : **création de la classe runtime `ZFieldSpec`** (explicitement déférée par E2-4 à E2-5 : « E2-5 génère le `ZFieldSpec` dans le modèle » ; E2-4 n'a livré que la *surface* que `ZFieldSpec` projette) sous `lib/src/domain/edition/z_field_spec.dart` + export via `edition.dart` **et** `zcrud_core.dart`.
- **`zcrud_core`** — extension **additive** de `ZcrudRegistry.register` : ajout du paramètre **optionnel** `fieldSpecs` (slot réservé par E2-3, `zcrud_registry.dart:43-53`) **sans casser** la signature `register<T>(kind, {fromMap, toMap})` (AD-10 additif).

**HORS périmètre (empiètement interdit) :**
- ❌ **Interprétation runtime** du `ZFieldSpec` : composition `FormBuilderValidators`, rendu widget par type, évaluation de `ZCondition` contre l'état, dérivation de colonnes → **E3 / E4**. E2-5 émet la **donnée** `ZFieldSpec`, ne l'interprète pas.
- ❌ **Adaptateurs de schéma existant** (`JsonSerializableAdapter`/`ReflectableCodec`/`ZCodec` nommés persistance vs chat) → **E2-6**. E2-5 pose le codegen natif zcrud, pas les ponts vers les schémas hérités.
- ❌ **Corpus complet de rétro-compat sérialisation** (fixtures historiques multi-versions taggées `serialization-compat`, migration additive multi-champs) → **E2-10**. E2-5 **prouve** le contrat défensif AD-10 sur un modèle de test et **peut** semer le premier test taggé (voir « Activation des gates »), sans porter le corpus complet.
- ❌ **Uniformisation de casse camelCase↔snake inter-entités** (OQ-12/OQ mindmap, canonique §7) → tranché *ici* uniquement pour le contrat par défaut (`fieldRename: snake`, enums camelCase) ; la réconciliation des frontières mindmap/education via `ZCodec` reste E6/E2-6.
- ❌ **`freezed`** : non imposé (AD-3) ; E2-5 émet un `copyWith`/`toMap`/`fromMap` **maison** sans dépendre de `freezed`.
- ❌ Création d'un **15e package produit** pour héberger le modèle de test : interdit. Le modèle annoté de preuve vit **test-only** dans `zcrud_generator/test/` (voir AC7 + Dev Notes « Où vit le modèle de test »).
- ❌ Toute écriture de `sprint-status.yaml` par le dev (l'orchestrateur gère les transitions).

## Acceptance Criteria

1. **Builder statique `source_gen`, zéro `reflectable`, zéro exécution d'annotation (AC pivot AD-3).** `zcrud_generator` déclare un `Builder` `build_runner` réel : un `GeneratorForAnnotation<ZcrudModel>` (ou équivalent `TypeChecker`) qui lit `ClassElement`/`FieldElement` via `analyzer` et les valeurs d'annotation via `ConstantReader` — **jamais** par instanciation/exécution. Aucun import de `reflectable` nulle part (le `gate:reflectable` reste **vert** ; `analyzer`/`source_gen`/`build`/`build_runner` sont confinés à `zcrud_generator` en `dependencies`/`dev_dependencies`, jamais dans `zcrud_core`/`zcrud_annotations` — AD-1). Le squelette `ZGeneratorApi` est remplacé ou conservé comme marqueur de version **sans** casser le barrel `zcrud_generator.dart`.

2. **`build.yaml` déclaratif.** `zcrud_generator/build.yaml` déclare le builder (`import`, `builder_factories`, `build_extensions: {'.dart': ['.g.dart']}`, `build_to: source`, `auto_apply: dependents`, `applies_builders`) de façon à ce qu'un package **consommateur** annoté génère son `part '<model>.g.dart'` par `dart run build_runner build --delete-conflicting-outputs`. La convention cible confirmée avec E2-4/`gate:codegen` est respectée : **`@ZcrudModel` sur la classe + `part '<file>.g.dart';`** dans le fichier source, `.g.dart` **gitignoré** (régénéré). `zcrud_generator/pubspec.yaml` ajoute `build`/`source_gen`/`analyzer` (+ `dev: build_runner`, +`dart_style`/`code_builder` si retenus) — versions alignées `architecture.md` (build_runner ^2.4.x, source_gen, analyzer ^7) et **compatibles** avec la résolution workspace (`gate:compat` vert).

3. **`fromMap` DÉFENSIF (AD-10) — un champ absent/corrompu ne casse JAMAIS le parent.** Le `fromMap` généré :
   - **champ scalaire absent** → applique `@ZcrudField.defaultValue` si fourni, sinon `null` pour un champ nullable, sinon une valeur sûre documentée (jamais un throw de parsing) ;
   - **enum inconnu / valeur hors domaine** → retombe sur la valeur `unknownEnumValue` (discipline `@JsonKey(unknownEnumValue:)` AD-4 ; pour `EditionFieldType`/enums ouverts : `custom`) — **jamais** de `StateError` de `values.byName` ;
   - **sous-objet imbriqué corrompu** (map malformée d'un `ZExtension`/sous-modèle) → parsing défensif façon `fromJsonSafe → null` : le sous-champ vaut `null`/défaut, le parent se construit quand même ;
   - **types tolérants** documentés là où le canonique l'exige (ex. numéro accepté `int|String`, cf. canonique §5 `_parseHierarchyNumero`).
   Prouvé par des tests sur JSON **tronqué**, **enum inconnu**, **champ manquant** (AC8).

4. **`toMap` conforme aux conventions de persistance.** Le `toMap` généré émet des clés **snake_case** (`fieldRename` du `@ZcrudModel`, défaut `snake` ; override par `@ZcrudField.name`), des **valeurs d'enum camelCase** (`jsonValue = name`), dates **ISO-8601**, `id` = `String` opaque (nullable pour l'éphémère — canonique §5/§257). `explicitToJson`-équivalent pour les sous-objets (récursion `toMap`). Round-trip **idempotent** `toMap → fromMap → toMap` prouvé (AC8).

5. **`copyWith` À SENTINELLE (reset-`null` possible).** Le `copyWith` généré distingue **« argument non fourni »** de **« explicitement remis à `null` »** via une sentinelle (p.ex. `Object? x = _undefined` avec `const _undefined = Object()`, ou wrapper d'option) — corrigeant explicitement la limitation lex/DODLP « `x ?? this.x` sans sentinelle → impossible de remettre un nullable à `null` » (canonique §254, OQ §319). Prouvé : `model.copyWith(champNullable: null)` met bien le champ à `null`, tandis que `model.copyWith()` le préserve (AC8).

6. **`List<ZFieldSpec>` projeté depuis `@ZcrudField` (schéma déclaratif).** La classe **`ZFieldSpec`** est créée dans `zcrud_core/domain/edition` (pur-Dart, `const`, `==`/`hashCode` si l'égalité de valeur est utile) portant au minimum : `name` (clé persistée), `label`, `type: EditionFieldType`, `validators: List<ZValidatorSpec>`, `config: ZFieldConfig?`, `choices: List<ZFieldChoice>`, `condition: ZCondition?` (displayCondition), `searchable`, `defaultValue`, `readOnly`, `showIfNull`, `multiple`, `isId` (dérivé de `@ZcrudId`). Le générateur émet un `List<ZFieldSpec>` **projetant 1:1** la table de correspondance E2-4 (story E2-4 §« Table de correspondance »), avec **inférence de `type`** quand `@ZcrudField.type == null` (règle documentée en E2-4, **implémentée ici** : `String→text`, `int→integer`, `double→float`/`number`, `bool→boolean`, `DateTime→dateTime`, `enum→select`, `List<…>→` variante `multiple`, sous-`ZcrudModel→subItems`/`relation` — table complète documentée en Dev Notes). Le test de pureté domaine (`domain_purity_test.dart`) reste **vert** (`z_field_spec.dart` pur-Dart).

7. **Enregistrement `register(ZcrudRegistry)` généré + slot `fieldSpecs` additif.** Le générateur émet une fonction (p.ex. `void registerXxx(ZcrudRegistry registry)` ou une extension) appelant `registry.register<Xxx>(kind, fromMap: _$XxxFromMap, toMap: (m) => m.toMap(), fieldSpecs: $XxxFieldSpecs)`. `ZcrudRegistry.register` (E2-3, `zcrud_registry.dart`) est étendu **additivement** d'un paramètre **optionnel** `fieldSpecs` (List<ZFieldSpec>` ; défaut `const []`), stocké dans une seconde map interne exposée via un accesseur (`fieldSpecsFor(kind)` / `tryFieldSpecsFor(kind)`), **sans** modifier la signature existante ni casser les appels/tests E2-3. `kind` dérive de `@ZcrudModel.kind` ou, si `null`, du nom de classe (règle documentée). Le modèle de test annoté vit **test-only** (AC7-bis) — voir « Où vit le modèle de test ».

8. **Round-trip + désérialisation défensive + sentinelle prouvés par tests réels.** Sous `zcrud_generator/test/`, un **modèle de test annoté** (`@ZcrudModel`/`@ZcrudField`/`@ZcrudId` couvrant scalaires + enum ouvert + nullable + sous-objet + liste) génère son `.g.dart` **par `build_runner build` réel** (pas un golden en dur), et des tests asservissent :
   - **round-trip idempotent** : `fromMap(toMap(x)) == x` et `toMap(fromMap(m)) == m` (map canonique) ;
   - **défensif** : `fromMap({})` (tout absent) → défauts sûrs, pas de throw ; `fromMap` avec **enum inconnu** → `unknownEnumValue`/`custom` ; avec **champ manquant** → `defaultValue` ; avec **sous-objet tronqué** → parent construit, sous-champ `null`/défaut ;
   - **copyWith sentinelle** : reset-`null` vs préservation (AC5) ;
   - **`ZFieldSpec[]`** : la projection porte les bons `name/type/validators/…` (AC6) ;
   - **enregistrement** : `register(registry)` puis `registry.encode/decode(kind, …)` OK, et `registry.codecFor("kind-inexistant")` **throw** `ZUnregisteredTypeError` (AD-3, E2-3).
   Complément **golden/in-memory** admis (`source_gen_test`/`build_test`) pour asserter le code émis **en plus** du build réel (jamais à la place — le `.g.dart` réel est requis pour AC9).

9. **Échec de build EXPLICITE (message clair).** Le générateur **échoue le build** (`InvalidGenerationSourceError` avec message actionnable + `element` fautif) — jamais un cast `null` silencieux — quand : (a) un champ référence un **type non (dé)sérialisable** et non enregistrable (ni scalaire supporté, ni enum, ni `ZcrudModel` annoté, ni `ZExtension`/`extra`) ; (b) `@ZcrudModel` sans `part '<file>.g.dart';` ; (c) collision de `kind`/de `name` de champ. Le message oriente vers la correction (annoter le type, ajouter la directive `part`, désambiguïser). **Documenté** (Dev Notes) + prouvé par un **test de build en échec** (fixture invalide, assertion sur le message/type d'erreur).

10. **Activation `gate:codegen` de bout en bout + slot `verify:serialization`.** Après `melos run generate`, le modèle de test annoté possède son `.g.dart` **présent sur disque** → `gate:codegen` (scan `packages/**`, `scripts/ci/gate_codegen.dart`) rapporte **≥1 modèle @ZcrudModel, 0 .g.dart manquant** et **passe** (il comptait « 0 modèle » jusqu'ici). E2-5 **peut** semer le premier test `@Tags(['serialization-compat'])` (round-trip/défensif) pour **allumer** le slot `verify:serialization` (aujourd'hui no-op vert) — le **corpus complet** restant à E2-10. La convention de branchement stable (`verify_serialization.dart`, runner `dart`/`flutter` par package) n'est **pas** modifiée.

11. **Vérif verte de bout en bout (rejouée réellement — CLAUDE.md).** `melos run generate` OK (produit le `.g.dart` du modèle de test, gitignoré) → `dart/flutter analyze` **RC=0** (zéro warning nouveau ; lints stricts E1-3 ; le `.g.dart` généré passe l'analyse — `implicit-casts`/`public_member_api_docs` gérés via en-tête `// GENERATED CODE - DO NOT MODIFY BY HAND` + exclusion d'analyse conventionnelle du généré) → `flutter test`/`melos run test` **RC=0** (round-trip/défensif/sentinelle/registre/build-échec verts) → **`melos run verify`** (graph_proof `ACYCLIQUE`/`CORE OUT=0`, `gate:reflectable`, `gate:secrets`, **`gate:codegen`** avec le modèle annoté, `gate:compat`) **RC=0** → **pureté domaine verte** (`z_field_spec.dart` pur-Dart).

## Tasks / Subtasks

- [x] **T1 — Classe runtime `ZFieldSpec` (zcrud_core/domain, pur-Dart)** (AC: #6)
  - [x] Créer `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` : `ZFieldSpec` `const` (name/label/type/validators/config/choices/condition/searchable/defaultValue/readOnly/showIfNull/multiple/isId), docstrings API (lint E1-3), `==`/`hashCode` (égalité de valeur + listes profondes).
  - [x] Exporter depuis `edition.dart` (surface pure) **et** `zcrud_core.dart` (barrel).
  - [x] Vérifier `test/purity/domain_purity_test.dart` reste vert (fichier pur-Dart — inclus dans les 160 tests zcrud_core verts).
- [x] **T2 — Extension additive `ZcrudRegistry` (slot `fieldSpecs`)** (AC: #7)
  - [x] Étendre `register<T>` d'un paramètre optionnel `fieldSpecs` (défaut `const []`), seconde map interne, accesseurs `fieldSpecsFor`/`tryFieldSpecsFor` ; signature E2-3 intacte, tests E2-3 verts.
  - [x] Docstrings ; tests de non-régression du registre (register sans/avec fieldSpecs, `fieldSpecsFor`/`tryFieldSpecsFor` strict vs défensif).
- [x] **T3 — Builder `source_gen`/`build_runner` (zcrud_generator)** (AC: #1, #2, #9)
  - [x] `pubspec.yaml` : `dependencies: {analyzer ^8, source_gen ^4, build ^3}` + `dev_dependencies: {build_runner ^2.5, build_test ^3, test ^1.25}` ; versions **co-résolues** avec le workspace (`gate:compat` vert). Variance analyzer ^8 (au lieu de ^7) documentée : imposée par la résolution partagée flutter_test/test.
  - [x] `build.yaml` : `SharedPartBuilder` (`.dart → .zcrud.g.part` + `combining_builder → .g.dart`), `auto_apply: dependents`, `targets.$default` limité à `test/models/**` (génération du fixture).
  - [x] `lib/src/zcrud_model_generator.dart` : `ZcrudModelGenerator extends GeneratorForAnnotation<ZcrudModel>` (lecture `ClassElement`/`FieldElement` + `ConstantReader`/`TypeChecker.typeNamed` ; **zéro reflectable/exécution**) + `lib/builder.dart` (factory). `ZGeneratorApi`/barrel conservés intacts.
  - [x] Émission : `_$XxxFromMap` (défensif), extension publique `XxxZcrud` (`toMap()` snake/camelCase/ISO + `copyWith` sentinelle), `$XxxFieldSpecs` (`List<ZFieldSpec>` + inférence de type), `registerXxx(ZcrudRegistry)`.
  - [x] Échec explicite `InvalidGenerationSourceError` (type non sérialisable ; collision de clé persistée) avec message actionnable + `element`.
- [x] **T4 — Modèle de test annoté + génération réelle (test-only, PAS un 15e package)** (AC: #7, #8, #10)
  - [x] `packages/zcrud_generator/test/models/article.dart` : `@ZcrudModel` + `part` ; `@ZcrudId` + scalaires + enum ouvert + nullable + sous-objet (`Author @ZcrudModel`) + `List<String>`.
  - [x] Mécanique retenue : `SharedPartBuilder` + `targets.$default.generate_for: test/models/**` sur zcrud_generator lui-même → `dart run build_runner build` génère `article.g.dart` **sur disque** (gitignoré, prouvé).
  - [x] Fixtures **invalides** en mémoire (type `Uri` non sérialisable ; collision de clé) pour le test de build en échec (AC9), via `resolveSource` (aucun fichier disque → invisible pour `gate:codegen`).
- [x] **T5 — Tests (round-trip / défensif / sentinelle / registre / build-échec)** (AC: #3, #4, #5, #8, #9)
  - [x] Round-trip idempotent (`fromMap(toMap(x))==x`, `toMap(fromMap(m))==m`) + `ZFieldSpec[]` projeté correct.
  - [x] Défensif : `{}`, enum inconnu, champ manquant, sous-objet non-map/tronqué, int|String, liste corrompue → jamais de throw parent.
  - [x] `copyWith` sentinelle : reset-`null` vs préservation.
  - [x] Registre : `register` → `encode/decode` OK ; `fieldSpecsFor` ; `codecFor(kind-absent)` → `ZUnregisteredTypeError`.
  - [x] Build en échec : `throwsA(isA<InvalidGenerationSourceError>())` sur fixtures invalides.
  - [x] 1er test `@Tags(['serialization-compat'])` (round-trip + doc tronqué) allumant le slot `verify:serialization` (corpus complet = E2-10).
- [x] **T6 — Vérif verte rejouée** (AC: #10, #11)
  - [x] `melos run generate` OK (produit `article.g.dart`) ; `melos run analyze` RC=0 (0 issue) ; `melos run test` RC=0 (222 tests) ; `melos run verify` RC=0 (**`gate:codegen`** 1 modèle 0 manquant, `gate:reflectable`/`gate:secrets`/`gate:compat`, graph ACYCLIQUE + CORE OUT=0) ; pureté domaine verte ; `prove_gates` 22 OK.

## Dev Notes

### Découpage E2-4 vs E2-5 (anti-empiètement) — ce qui bascule ici

- **E2-4 (done)** = **surface d'autorité** (le *quoi*, lisible par `ConstantReader`) : annotations `const`, `EditionFieldType`, types-valeur, `edition.dart` pur. Elle a **explicitement déféré** à E2-5 : (a) la **classe `ZFieldSpec`** (« E2-5 génère le `ZFieldSpec` dans le modèle » — E2-4 §HORS périmètre) ; (b) le **builder** (`TypeChecker`, émission, `copyWith` sentinelle, round-trip) ; (c) l'**implémentation** de l'inférence `type=null` (E2-4 la *documente* « implémentée en E2-5 »).
- **E2-5 (cette story)** = **projection** : crée `ZFieldSpec`, câble le slot `fieldSpecs` du registre (réservé par E2-3), et **émet** `fromMap`/`toMap`/`copyWith`/`ZFieldSpec[]`/`register`.

### Conception du builder (contrat d'émission)

**Entrée** : un fichier avec `@ZcrudModel(...) class Xxx { @ZcrudId? final String? id; @ZcrudField(...) final ... champ; }` + `part 'xxx.g.dart';`.
**Lecture (statique, AD-3)** : `GeneratorForAnnotation<ZcrudModel>` + `TypeChecker` sur `@ZcrudField`/`@ZcrudId` ; chaque `FieldElement` → nom Dart, type statique, `ConstantReader` de l'annotation (label/type/validators/config/choices/condition/searchable/defaultValue/readOnly/showIfNull/name/multiple). **Aucune** instanciation/exécution d'annotation ; **aucun** `reflectable`.
**Sortie (dans `xxx.g.dart`, en-tête `// GENERATED CODE - DO NOT MODIFY BY HAND`)** :

| Émis | Forme | Détail clé |
|---|---|---|
| `_$XxxFromMap(Map<String,dynamic>)` | fonction/factory | **défensif** : `map['k'] ?? defaultValue` ; enum via helper `_enumFromName(values, name, fallback: unknownEnumValue)` ; sous-objet via `fromMap` tolérant (corruption → `null`/défaut) ; jamais de throw parent (AD-10). |
| `toMap()` | méthode/extension | clés **snake** (`fieldRename`/`name`) ; enum `.name` (**camelCase**) ; `DateTime.toIso8601String()` ; récursion `toMap` sous-objets. |
| `copyWith({...})` | méthode/extension | **sentinelle** `const _undefined = Object()` : `x: identical(x,_undefined) ? this.x : x as T?` → reset-`null` possible (AC5). |
| `$XxxFieldSpecs` | `const List<ZFieldSpec>` (ou getter) | projection 1:1 de `@ZcrudField` ; **inférence de type** si `type==null` (table ci-dessous). |
| `registerXxx(ZcrudRegistry)` | fonction | `registry.register<Xxx>(kind, fromMap:, toMap:, fieldSpecs: $XxxFieldSpecs)`. |

**Table d'inférence `type==null`** (Dart statique → `EditionFieldType`) : `String→text` ; `int→integer` ; `double→float` (ou `number` — trancher, documenter) ; `bool→boolean` ; `DateTime→dateTime` ; `enum→select` ; `List<T>→` variante avec `multiple=true` (type dérivé de `T`) ; sous-`@ZcrudModel→subItems` (relation câblée au runtime) ; type inconnu → **échec explicite AC9**. Toute inférence est **documentée** et testée.

### `fromMap` défensif — patrons AD-10 (canonique §5/§258, guideline #15)

- **Scalaire absent** → `map['k'] as T? ?? defaultValue`.
- **Enum** → helper : `EditionFieldType.values.asNameMap()[s] ?? unknownEnumValue` (jamais `byName` nu qui throw).
- **Sous-objet** → `map['k'] is Map ? _safeFromMap(map['k']) : null` ; `_safeFromMap` capture le parsing malformé → `null` (façon `fromJsonSafe`), **sans** propager au parent.
- **Types tolérants** documentés là où canonique l'exige (numéro `int|String`).

### `copyWith` sentinelle — pourquoi (canonique §254/§319)

lex/DODLP écrivent `copyWith` à la main en `x ?? this.x` **sans sentinelle** → un champ nullable **ne peut pas** être remis à `null` (limitation assumée dans `StudyFolder.copyWith`). zcrud tranche l'OQ §319 : **générer un `copyWith` à sentinelle** distinguant « non fourni » de « `null` explicite ». C'est un AC dur d'épic (epics.md:67 « copyWith avec sentinelle (reset-null possible) »).

### Où vit le modèle de test annoté (décision — PAS un 15e package produit)

**Décision : `packages/zcrud_generator/test/models/<fixture>.dart` (test-only).** Justification :
- Le builder doit prouver un `.g.dart` **réel** produit par `build_runner` (AC8/AC10) ; un golden en dur ne suffit pas à activer `gate:codegen`.
- Créer un 15e package produit (`packages/zcrud_example`) est **interdit** (contrainte tâche + ne fait pas partie des 14 packages de l'architecture). L'`example/` d'un package publiable serait aussi scanné par `gate:codegen` mais alourdit l'API publique ; **test-only** est le bon niveau.
- **Mécanique de génération** : par défaut `build_runner` traite `lib/`. Pour générer un `part` sous `test/`, deux options (trancher au dev, documenter) : (a) `build.yaml` de zcrud_generator avec `targets: $default: builders: zcrud_generator: generate_for: ['test/**']` + `auto_apply: root_package` pour que le builder s'applique **à zcrud_generator lui-même** ; (b) `source_gen_test`/`build_test` pour la partie golden **plus** un run `build_runner build` ciblant le fixture. Le `.g.dart` du fixture reste **gitignoré** (régénéré ; jamais édité à la main — Key Don'ts).
- **Conséquence `gate:codegen`** : `scripts/ci/gate_codegen.dart` scanne `packages/**` (donc `packages/zcrud_generator/test/**`), repère `@ZcrudModel`, exige le `.g.dart` co-localisé. Après `melos run generate`, le fixture a son `.g.dart` → **gate passe** (≥1 modèle, 0 manquant). C'est **l'activation attendue** du gate (il comptait « 0 modèle »).

### Activation des gates (état réel → après E2-5)

- **`gate:codegen`** (`scripts/ci/gate_codegen.dart`) : aujourd'hui « 0 modèle @ZcrudModel » (aucune annotation posée sur une classe). E2-5 y introduit le **premier** `@ZcrudModel` (fixture) + son `.g.dart` → le gate **exerce réellement** son chemin nominal (≥1 modèle, 0 orphelin). Un fichier annoté **sans** `.g.dart` ferait échouer le gate (garde correcte).
- **`verify:serialization`** (`scripts/ci/verify_serialization.dart`) : slot no-op vert tant qu'aucun test taggé `serialization-compat` n'existe. E2-5 **peut** poser le **premier** tel test (round-trip/défensif) pour allumer le slot ; le **corpus complet** (fixtures historiques, montée de version) reste **E2-10** (anti-empiètement). Convention de branchement (runner `dart`/`flutter`) **non modifiée**.
- **`gate:reflectable`** : reste **vert** — le builder lit via `analyzer`, jamais via `reflectable`.

### `ZcrudRegistry.register` — extension additive (E2-3 §slot réservé)

`zcrud_registry.dart:43-53` **réserve** l'association `kind → List<ZFieldSpec>` : « ajoutée additivement en E2-4/E2-5 (paramètre optionnel `fieldSpecs` sur register, ou seconde map interne), sans casser la signature actuelle ». E2-5 exécute exactement cela : `register<T>(kind, {required fromMap, required toMap, List<ZFieldSpec> fieldSpecs = const []})` + seconde map + accesseurs. Les tests E2-3 (throw `ZUnregisteredTypeError`/`ZDuplicateRegistrationError`, `encode`/`decode`) doivent rester **verts** sans modification.

### Project Structure Notes

- `zcrud_core` : +`lib/src/domain/edition/z_field_spec.dart` ; barrels `edition.dart` + `zcrud_core.dart` étendus ; `zcrud_registry.dart` étendu (additif). Cohérent avec le layout `domain/edition/*` (E2-4) et `domain/registry/*` (E2-3).
- `zcrud_generator` : `pubspec.yaml` (+codegen deps), `build.yaml` (nouveau), `lib/src/…` (builder réel remplaçant/complétant `z_generator_api.dart`), `test/models/*` (fixtures) + tests. Reste **dev_dependency** ; ses deps lourdes (`analyzer`/`source_gen`/`build_runner`) **ne fuient pas** (AD-1) — `graph_proof` inchangé (le générateur dépend de core+annotations ; personne ne dépend de lui en runtime).
- **Variance assumée** : le `.g.dart` généré doit passer `analyze` (en-tête `GENERATED CODE` + conventions d'exclusion du généré côté `analysis_options`) — vérifier que la config E1-3 exclut/ignore correctement les `*.g.dart` ou que le code émis satisfait les lints stricts.

### Conventions à respecter (canonique §5 + AD)

- **Persistance** : `fieldRename: snake` ; **valeurs d'enum camelCase** (`jsonValue = name`) même sous clés snake (« toute divergence de casse = bug de contrat », canonique §253) ; dates ISO-8601 ; `id` `String` opaque nullable pour l'éphémère.
- **Défensif systématique** (AD-10) : `unknownEnumValue`, `defaultValue`, `fromJsonSafe → null` ; évolution **additive** seulement.
- **Jamais `reflectable`** (AD-3, `gate:reflectable`) ; **jamais `freezed` imposé** ; **jamais éditer/committer un `.g.dart`** (gitignoré, régénéré — Key Don'ts).
- **Nommage** : `ZFieldSpec` (préfixe `Z`) ; `EditionFieldType` garde son nom canonique historique.
- **Pureté domaine** : `z_field_spec.dart` pur-Dart (garde `domain_purity_test.dart`).
- **Échec explicite** (AD-3) : type non enregistré/non sérialisable → `throw`/`InvalidGenerationSourceError`, **jamais** cast `null` silencieux.

### References

- [Source: epics-zcrud-2026-07-09/epics.md:67 #Story E2-5] — AC : `toMap/fromMap/copyWith` + `ZFieldSpec[]` + enregistrement ; zéro reflectable ; enums `unknownEnumValue` ; snake/camelCase ; **copyWith sentinelle** ; round-trip (AD-3, AD-10) ; **échec explicite si type non enregistré**.
- [Source: architecture.md#AD-3] — générateur `@ZcrudModel`/`@ZcrudField` → `toMap/fromMap/copyWith` + `ZFieldSpec[]` + enregistrement `ZcrudRegistry` ; `reflectable` banni ; `freezed` non imposé ; type non enregistré → throw explicite (jamais cast null).
- [Source: architecture.md#AD-10] — évolution additive + désérialisation défensive (`unknownEnumValue`/`defaultValue`/`fromJsonSafe→null` ; champ absent/corrompu ne casse jamais le parent).
- [Source: architecture.md:157,184] — stack : build_runner ^2.4.x / source_gen / analyzer ^7 ; `zcrud_generator` = builder dev_dependency.
- [Source: architecture.md#AD-1] — cœur OUT=0 ; `zcrud_generator → {zcrud_core, zcrud_annotations}` ; codegen confiné au générateur.
- [Source: docs/canonical-schema.md:6,253,254,258,319] — désérialisation défensive (guideline #15) ; conventions `@JsonSerializable` snake/enum camelCase ; `copyWith` manuel sans sentinelle (limitation) ; OQ « copyWith sentinelle vs manuel ».
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart:43-53,62-75] — slot `fieldSpecs` réservé additivement ; `register<T>` ; throw `ZUnregisteredTypeError`.
- [Source: packages/zcrud_core/lib/src/domain/registry/z_registry_error.dart] — `ZUnregisteredTypeError`/`ZDuplicateRegistrationError`.
- [Source: packages/zcrud_core/lib/edition.dart] — entrée publique pure (E2-4) ; `ZFieldSpec` s'y ajoute.
- [Source: stories/e2-4-annotations.md #Table de correspondance] — mapping `@ZcrudField` → `ZFieldSpec` que E2-5 émet ; inférence `type=null` documentée « implémentée en E2-5 ».
- [Source: scripts/ci/gate_codegen.dart] — scan `packages/**` : `@ZcrudModel` sans `<file>.g.dart` → échec ; convention `part '<file>.g.dart';`.
- [Source: scripts/ci/verify_serialization.dart] — slot `serialization-compat` (runner `dart`/`flutter`) ; no-op vert tant qu'aucun test taggé ; corpus = E2-10.

### Ambiguïtés détectées (à valider par l'orchestrateur/architecte — ne bloquent pas le dev)

1. **`double` → `float` vs `number`.** `EditionFieldType` porte `number`, `float`, `integer`. L'inférence `double→?` doit être tranchée (proposé : `double→float`, `int→integer`, `num→number`). À confirmer ; documenter la règle finale.
2. **Génération sous `test/` (mécanique).** `build_runner` traite `lib/` par défaut ; générer un `part` sous `zcrud_generator/test/` exige `auto_apply: root_package` + `generate_for: ['test/**']` **ou** un builder golden (`source_gen_test`). Décision dev, à documenter ; ne pas créer de package produit.
3. **Analyse du `.g.dart`.** Vérifier que la config lint E1-3 (`analysis_options`) **exclut** les `*.g.dart` ou que le code émis satisfait les lints stricts (`public_member_api_docs`, `implicit-casts`) via en-tête `GENERATED CODE` — sinon `analyze` RC≠0. Ajuster l'exclusion si nécessaire (variance à flaguer).
4. **Portée du 1er test `serialization-compat`.** E2-5 peut allumer le slot `verify:serialization` avec un test taggé, ou tout déférer à E2-10. Proposé : semer **un** test minimal (round-trip défensif) pour prouver le branchement, corpus complet = E2-10. À confirmer (anti-empiètement).
5. **`kind` par défaut.** Si `@ZcrudModel.kind == null`, dériver du nom de classe — casse/normalisation à fixer (proposé : nom de classe brut, ou snake). Documenter ; cohérent avec la stratégie de discrimination du registre.
6. **Sous-objets & relation.** Un champ `@ZcrudModel` imbriqué : inféré `subItems` vs `relation` ; la source de données d'une `relation` est câblée au runtime (E4/ports), pas dans le `.g.dart`. E2-5 émet la (dé)sérialisation structurelle ; le câblage repository reste aval.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- Résolution : analyzer forcé à `^8` (workspace flutter_test/test ⇒ analyzer >=8) ; source_gen `3.1.0` cassé avec analyzer 8 (`DartObjectImpl.getInvocation` absent) → **source_gen `^4.0.0`** (4.2.3) + build `^3` + build_runner `^2.5` + build_test `^3`.
- API analyzer 8.4.1 : modèle d'élément unifié (`ClassElement`/`FieldElement`/`EnumElement`, getters `fields`/`constructors`) ; source_gen 4.2.3 : `generateForAnnotatedElement(Element, …)`, `TypeChecker.typeNamed`.
- Bug d'émission corrigé : enum via `revive().accessor` renvoyait `Enum.value` → double préfixe `ArticleStatus.ArticleStatus.draft` ⇒ on ne garde que le dernier segment. Suppression du `?? null` mort pour les champs nullables.
- AC9 : `testBuilder` avale l'exception du générateur (log de build) et le résolveur en mémoire ne const-évalue pas l'annotation cross-package ⇒ bascule sur `resolveSource(..., readAllSourcesFromFilesystem: true)` + `generateForModel` (cœur d'émission sans `BuildStep`).
- `gate:codegen` faux positif sur `build_failure_test.dart` (`@ZcrudModel` littéral en début de ligne dans les sources en mémoire) ⇒ annotations **interpolées** (`$_model()`), le gate ne voit plus de faux modèle.

#### Remédiation code-review E2-5 (2026-07-09)

- **H1 (HIGH, AD-10) — sous-objet/liste à clés non-`String` cassait le parent.** L'émission `Map<String, dynamic>.from($m as Map)` jetait un `_TypeError` sur une `Map<dynamic,dynamic>` à clé non-`String` (Hive / doc forgé), remontant au parent (violation AD-10). Corrigé dans `zcrud_model_generator.dart` : deux helpers défensifs émis dans `_sharedHelpers` — `_$asStringMap(Object?)` (coerce toute Map en `Map<String,dynamic>` en convertissant les clés via `'${e.key}'`, `null` si non-Map ou anomalie, **sans jamais throw**) et `_$decodeModel<T>(Object?, T Function(Map))` (coerce puis `fromMap` sous `try/catch` → `null` sur anomalie). Sous-objet : `_fromMapExpr` `_Cat.subModel` émet `_$decodeModel($m, $T.fromMap)` (+ `?? $def` si non-nullable). Liste : `_Cat.listModel` émet `.map((e) => _$decodeModel(e, $T.fromMap)).whereType<$T>().toList()` (éléments corrompus filtrés). Le parent survit désormais TOUJOURS. Preuve : nouveaux tests `sous-objet à clés NON-String → parent survit` (author récupéré par coercion) + `liste de sous-modèles corrompue → parent survit, valides conservés` — ÉCHOUAIENt avec l'ancien code (`_TypeError`), PASSENT après.
- **M2 (MEDIUM) — chemin `List<@ZcrudModel>` non couvert.** Ajout du champ `List<Author> coauthors` au fixture `article.dart` (+ `==`/`hashCode`/`_authorListEq`). Nouveaux tests : round-trip liste de sous-modèles + décodage défensif par élément (non-map / clés non-`String` / scalaire / null filtrés). Couvert par le helper H1.
- **M1 (MEDIUM) — manifeste `gate:compat` périmé (analyzer ^7 vs toolchain réelle ^8).** `tool/compat_check/pubspec.yaml` réconcilié sur la toolchain RÉELLE du générateur : `analyzer ^8.0.0` + `source_gen ^4.0.0` + `build ^3.0.0` + `build_runner ^2.5.0` (aligné `packages/zcrud_generator`), co-résolu avec `flutter_quill ^11.5` + `awesome_select ^6`. `gate:compat` résout désormais **analyzer 8.4.1** (au lieu de 7.7.1) — prouve la chaîne réellement exécutée (FR-25 honnête). README compat mis à jour (justification `^7` périmée retirée, table = toolchain réelle).
- **LOW (consignés, sans changement)** : L1 (`copyWith(champNonNullable: null)` → `_TypeError` de cast opaque : comportement acceptable — on ne peut nuller un non-nullable ; restructurer l'émission pour un `ArgumentError` parlant n'est pas justifié dans le périmètre) ; L2 (coercions lossy : `_$asInt` tronque `double`, enum sans `defaultValue` → `values.first` : conforme au contrat « types tolérants » canonique §5, documenté dans les helpers ; le seul enum du fixture — `status` — déclare déjà `defaultValue`).
- **Vérif verte rejouée (remédiation)** : `melos run generate` RC=0 (helpers `_$asStringMap`/`_$decodeModel` + décode `author`/`coauthors` défensif dans `article.g.dart`) · `melos run analyze` RC=0 (0 issue) · `melos run test` RC=0 (**226 tests** : generator **30**, +4 vs 26) · `melos run verify` RC=0 · `gate:compat` RC=0 (analyzer résolu **8.4.1**) · `prove_gates` 22 OK/0 FAIL · `gate:codegen`/`gate:reflectable` RC=0 · graph_proof ACYCLIQUE + CORE OUT=0 · `melos list`=14 · 0 `.g.dart` committé.

### Completion Notes List

- **AD-3** : générateur `source_gen` statique (`TypeChecker.typeNamed` + `ConstantReader`), **zéro reflectable**, zéro exécution d'annotation. Type non (dé)sérialisable / collision de clé → `InvalidGenerationSourceError` (jamais cast null).
- **AD-10** : `fromMap` défensif prouvé (map vide, enum inconnu → `defaultValue`, sous-objet non-map/tronqué → parent survit, int|String tolérant, liste filtrée `whereType`). `copyWith` à sentinelle (`_$undefined`) : reset-`null` distinct de « non fourni ».
- **AD-1** : toolchain codegen (`analyzer`/`build`/`source_gen`) confinée à `zcrud_generator` (dev_dependency) ; graph_proof **ACYCLIQUE**, **CORE OUT=0** inchangés ; `melos list`=14 ; 0 `.g.dart` suivi par git (gitignoré, régénéré).
- **Génération RÉELLE prouvée** : `melos run generate` produit `article.g.dart` (6.3 ko) ; `gate:codegen` passe au chemin nominal (1 modèle, 0 manquant) et **échoue** si le `.g.dart` est retiré (fixture éphémère rejouée : RC=1 → régénéré → RC=0).
- **Slot `verify:serialization` amorcé** : premier test `@Tags(['serialization-compat'])` (round-trip + doc historique tronqué). Corpus complet reste E2-10.
- **Décisions d'ambiguïté** (Dev Notes §Ambiguïtés) : (1) `double→float`, `int→integer`, `num→number` ; (2) génération sous `test/` via `SharedPartBuilder` + `targets.$default.generate_for: test/models/**` (pas de 15e package) ; (4) 1 test `serialization-compat` semé, corpus = E2-10 ; (5) `kind` par défaut = **nom de classe brut** ; (6) sous-modèle imbriqué → `subItems`, (dé)sérialisation structurelle émise, câblage relation au runtime.
- **Décision d'API** : `edition.dart` (surface pure) exporte désormais aussi `ZFieldSpec` et les types **purs** du registre (`ZcrudRegistry`/`ZModelCodec`/erreurs) — additif, non cassant — afin que le code émis (`register*`) compile chez un consommateur pur-Dart (le fixture, sous `dart test`) sans tirer Flutter via le barrel principal.
- **Vérif verte rejouée réellement** : `generate` OK · `analyze` RC=0 (0 issue) · `test` RC=0 (**222 tests** : core 160, generator 26, get 12, annotations/riverpod/provider 8) · `verify` RC=0 · `prove_gates` 22 OK/0 FAIL (inchangé).

### File List

**Créés :**
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart`
- `packages/zcrud_core/test/domain/edition/z_field_spec_test.dart`
- `packages/zcrud_generator/lib/builder.dart`
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart`
- `packages/zcrud_generator/build.yaml`
- `packages/zcrud_generator/dart_test.yaml`
- `packages/zcrud_generator/test/models/article.dart`
- `packages/zcrud_generator/test/zcrud_model_generator_test.dart`
- `packages/zcrud_generator/test/serialization_compat_test.dart`
- `packages/zcrud_generator/test/build_failure_test.dart`

**Modifiés :**
- `packages/zcrud_core/lib/edition.dart` (export `ZFieldSpec` + registre pur)
- `packages/zcrud_core/lib/zcrud_core.dart` (export `ZFieldSpec`)
- `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart` (slot additif `fieldSpecs` + `fieldSpecsFor`/`tryFieldSpecsFor`)
- `packages/zcrud_core/test/domain/registry/zcrud_registry_test.dart` (tests slot `fieldSpecs`)
- `packages/zcrud_generator/pubspec.yaml` (deps codegen : analyzer/build/source_gen + build_runner/build_test/test)

**Modifiés (remédiation code-review E2-5) :**
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (H1 : helpers `_$asStringMap`/`_$decodeModel` + émission défensive `subModel`/`listModel`)
- `packages/zcrud_generator/test/models/article.dart` (M2 : champ `List<Author> coauthors` + égalité)
- `packages/zcrud_generator/test/zcrud_model_generator_test.dart` (tests H1/M2 : sous-objet clés non-`String`, liste de sous-modèles round-trip + défensif)
- `tool/compat_check/pubspec.yaml` (M1 : analyzer ^8 + source_gen ^4 + build ^3 + build_runner ^2.5)
- `tool/compat_check/README.md` (M1 : table compat = toolchain réelle ^8)

**Générés (gitignorés, NON committés, régénérés par `melos run generate`) :**
- `packages/zcrud_generator/test/models/article.g.dart`

**Non-source (env, hors commit) :** `pubspec.lock` (racine, mis à jour par la résolution).
