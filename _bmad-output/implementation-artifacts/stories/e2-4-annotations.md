---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.4 : Annotations (@ZcrudModel / @ZcrudField / @ZcrudId) + enum `EditionFieldType`

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du socle codegen de `zcrud`**,
je veux **poser les trois annotations d'autorité `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` (classes `const` pur-métadonnées, sans aucune dépendance runtime lourde) dans `zcrud_annotations`, et le catalogue de champs canonique `EditionFieldType` (+ les types-valeur d'autorité `ZValidatorSpec` / `ZFieldChoice` / `ZCondition` / `ZFieldConfig`) dans `zcrud_core`**,
afin que **`@ZcrudField` couvre TOUTE la surface du futur `ZFieldSpec` — `label` / `type` / `validators` / `config` / `choices` / `condition` (displayCondition) / `searchable` (+ `defaultValue` / `readOnly` / `showIfNull` / `name` / `multiple`) — de manière STATIQUE et lisible par `ConstantReader`, pour que le générateur E2-5 émette `toMap`/`fromMap`/`copyWith` + `ZFieldSpec[]` + l'enregistrement au `ZcrudRegistry` SANS jamais exécuter ni réfléchir (AD-3, `reflectable` banni), et que le modèle annoté reste l'unique source de vérité (AD-3) tout en préservant l'acyclicité (AD-1 : `zcrud_annotations → zcrud_core`, out-degree du cœur = 0).**

## Contexte & valeur

**Position dans l'épic E2 (cœur + codegen + bindings).** Ordre intra-épic verrouillé (epics.md:61) : `E2-1 → E2-2 → E2-7 → E2-9` (réactivité/injection, **done**) **avant** `E2-4/E2-5` (codegen complet). E2-3 (registre & extensibilité : `ZcrudRegistry`/`ZTypeRegistry`/`ZSourceRegistry`/`ZExtension`/`extra`) est **done** — le `ZcrudRegistry` existe déjà et **réserve explicitement** le slot `ZFieldSpec` en le déférant à E2-4/E2-5 :

> « **Slot `ZFieldSpec` différé (dépendance E2-4/E2-5)** : `ZFieldSpec` n'existe pas avant E2-4/E2-5. Cette version porte `fromMap`/`toMap` **seulement** ; l'association `kind → List<ZFieldSpec>` sera ajoutée **additivement** en E2-4/E2-5 (paramètre optionnel `fieldSpecs` sur `register`, ou seconde map interne), **sans casser** la signature actuelle. » — `zcrud_registry.dart:43-53`

**Ce que cette story matérialise.** E2-4 est la **surface d'autorité** (authoring surface) du moteur déclaratif : un même schéma de champs pilote formulaire (`DynamicEdition`, E3) **et** tableau (`DynamicList`, E4). Les annotations sont le *quoi* déclaratif ; E2-5 est le *comment* (codegen) ; E3/E4 sont les *interprètes runtime*. Cette story livre le **quoi**.

**Chaîne de valeur aval (consommateurs de E2-4) :**
- **E2-5 (générateur build_runner)** : `TypeChecker` sur `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` ; lit chaque champ d'annotation via `ConstantReader` (valeurs **compile-time**, jamais exécutées) ; émet `ZFieldSpec(name, label, type, validators, config, choices, condition, searchable, …)` + `toMap`/`fromMap`/`copyWith` (**avec sentinelle**, reset-null) + `registry.register<T>(kind, fromMap:, toMap:, fieldSpecs:)`. « type non enregistré → throw explicite » (AD-3) s'appuie sur `ZcrudRegistry` (E2-3).
- **E3 (édition granulaire)** : interprète `EditionFieldType`/`ZFieldConfig` → widget de champ ; **compose** `ZValidatorSpec[]` → `FormBuilderValidators` (`AutovalidateMode.onUserInteraction` par champ, validateurs mémoïsés — AD-2) ; **évalue** `ZCondition` (displayCondition) dans un **sélecteur de visibilité dédié** (seul un changement de visibilité reconstruit la LISTE, place stable pour champs conditionnels — AD-2).
- **E4 (liste)** : dérive les colonnes du `ZFieldSpec[]` ; `searchable` alimente le filtre/recherche.
- **E11a / E7 (parité DODLP)** : `EditionFieldType` = le **catalogue de parité SM-2** (référence unique = tableau technical-inventory §3) ; les types dont le widget vit hors-cœur (`markdown`→E6, `geoArea`/`phoneNumber`→E11a) sont servis via `ZTypeRegistry` (E2-3 / E3-3b).

**Pourquoi « aucune dépendance runtime » est structurant (pas décoratif).** Le générateur E2-5 lit les annotations **statiquement** (`analyzer` / `source_gen` / `ConstantReader`) : il n'instancie ni n'exécute jamais une annotation. Les annotations DOIVENT donc être des **classes `const` pur-données** (champs `final`, constructeur `const`, **aucune méthode à comportement**, **aucune closure**). C'est exactement ce qui rend `reflectable` inutile (AD-3, banni par gate CI E1-3) et garantit un schéma lisible à froid. Tout ce qui EXIGE une closure (builder `widget` libre, `stateValidators`, `displayCondition` dynamique dépendant du CRUD runtime) **n'entre pas** dans l'annotation : c'est **attaché au runtime** via la config de champ / `ZTypeRegistry` (voir « Frontière statique vs runtime »).

## Périmètre strict de CETTE story (anti-empiètement)

**DANS le périmètre :**
- `zcrud_annotations` : les 3 annotations `const` `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` + barrel.
- `zcrud_core` (couche `domain`, **pur-Dart**) : l'enum `EditionFieldType` (catalogue de parité + `custom`) **et** les types-valeur d'autorité `const` référencés par la surface `@ZcrudField` : `ZValidatorSpec` (+ variantes déclaratives), `ZFieldChoice`, `ZCondition` (+ combinateurs déclaratifs), `ZFieldConfig` (base d'extension abstraite). Ces types sont **partagés** entre l'annotation (authoring) et le futur `ZFieldSpec` (runtime) → **source unique**.

**HORS périmètre (empiètement interdit) :**
- ❌ La **classe runtime `ZFieldSpec`** elle-même et son émission → **E2-5** (« E2-5 génère le `ZFieldSpec` dans le modèle »). E2-4 définit la **surface** que `ZFieldSpec` devra projeter (paramètres d'annotation + types-valeur), pas la classe projetée. *(Voir Dev Notes « Découpage E2-4 vs E2-5 » pour la justification et l'alternative écartée.)*
- ❌ Le **générateur build_runner** (`TypeChecker`, émission de code, `copyWith` sentinelle, round-trip) → **E2-5**.
- ❌ Toute **interprétation runtime** : composition `FormBuilderValidators`, rendu de widget par type, évaluation de `ZCondition` contre l'état, dérivation de colonnes → **E3 / E4**.
- ❌ Les **configs concrètes par type** riches (`GeoFieldConfig`→E11a/zcrud_geo, `FileFieldConfig`→E-fichier, `RichTextToolbarConfig`→E6, `StepperConfig`→E3) : E2-4 ne livre que la **base abstraite `ZFieldConfig`** (point d'extension AD-4) + éventuellement les configs **triviales pur-cœur** communes (voir AC5). Les configs lourdes restent à leurs packages/stories.
- ❌ Toute écriture de `sprint-status.yaml` par le dev (l'orchestrateur gère les transitions).

## Acceptance Criteria

1. **Aucune dépendance runtime lourde (AC pivot de l'épic).** `packages/zcrud_annotations/pubspec.yaml` ne déclare **aucune** dépendance vers `build_runner`, `source_gen`, `analyzer`, `build`, un gestionnaire d'état (`flutter_riverpod`/`get`/`provider`), Firebase, Syncfusion, Quill, Maps. Sa **seule** arête `zcrud_*` est `zcrud_core` (AD-1, out-degree cœur = 0 préservé — le graphe reste acyclique : `zcrud_annotations → zcrud_core`, jamais l'inverse). Les 3 annotations sont des classes **`const` pur-données** : tous champs `final`, un constructeur `const`, **zéro méthode à comportement**, **zéro closure**. *(Vérifié : inspection pubspec + `graph_proof` inchangé vert + test d'instanciation `const`.)*

2. **`@ZcrudModel` (annotation de classe).** Classe `const` annotable sur une classe, exposant au minimum : `kind` (`String?`, discriminant du `ZcrudRegistry` ; `null` ⇒ le générateur dérive du nom de classe), `fieldRename` (`ZFieldRename`, défaut `snake` — aligne AD-3 : persistance snake_case). Instanciable `const` avec valeurs par défaut sûres **et** tous paramètres fournis.

3. **`@ZcrudField` couvre TOUTE la surface AC (label/type/validators/config/choices/condition/searchable).** Classe `const` annotable sur un champ d'instance, exposant **tous** les paramètres suivants, chacun `final`, tous **optionnels avec défaut sûr** :
   - `label` (`String?`) — libellé d'affichage (clé l10n ou littéral ; résolu côté UI).
   - `type` (`EditionFieldType?`) — `null` ⇒ le générateur **infère** depuis le type statique Dart du champ (`String`→`text`, `int`→`integer`, `bool`→`boolean`, `DateTime`→`dateTime`, `enum`→`select`, etc. ; règle d'inférence documentée, **implémentée en E2-5**).
   - `validators` (`List<ZValidatorSpec>?`) — validateurs **déclaratifs** (voir AC6).
   - `config` (`ZFieldConfig?`) — config spécialisée par type (base d'extension, voir AC5).
   - `choices` (`List<ZFieldChoice>?`) — options statiques `select`/`radio`/`checkbox`.
   - `condition` (`ZCondition?`) — `displayCondition` **déclarative** (voir AC7 ; jamais une closure).
   - `searchable` (`bool`, défaut `false`) — participation à la recherche/filtre liste (E4).
   - `defaultValue` (`Object?`) — valeur par défaut si absente.
   - `readOnly` (`bool`, défaut `false`) — champ non éditable (mode lecture, DODLP `readOnly`).
   - `showIfNull` (`bool`, défaut `true`) — en mode lecture, afficher le champ si la valeur est `null` (DODLP `showIfNull`).
   - `name` (`String?`) — override de la clé persistée ; `null` ⇒ dérivée du nom Dart via `fieldRename`.
   - `multiple` (`bool`, défaut `false`) — multi-sélection (`multiple=true`, cf. inventaire).
   Instanciable `const` **avec chaque paramètre** simultanément (test de couverture de surface).

4. **`@ZcrudId` (marqueur d'identifiant).** Classe `const` marqueur annotable sur un champ, sans paramètre requis ; consommée par E2-5 pour identifier le champ `id` (`String` opaque, nullable pour l'éphémère — cf. schéma canonique §5). Instanciable `const`.

5. **`EditionFieldType` défini dans `zcrud_core` (couche `domain`, pur-Dart) — catalogue de parité + enum ouvert.** L'enum énumère le **catalogue de parité DODLP** (référence unique = technical-inventory §3, tableau « Type ») : `text`, `multiline`, `number`, `integer`, `float`, `boolean`, `dateTime`, `time`, `select`, `radio`, `checkbox`, `relation` (crudDataSelect), `rowChips`, `tags`, `subItems`, `dynamicItem`, `file`, `image`, `document`, `location`, `geoArea`, `phoneNumber`, `country`, `address`, `rating`, `slider`, `signature`, `color`, `icon`, `markdown`, `inlineMarkdown`, `html`, `inlineHtml`, `richText`, `stepper`, `password`, `hidden`, `widget` — **plus `custom`** (valeur ouverte AD-4, avec discipline `@JsonKey(unknownEnumValue: custom)` documentée pour toute future (dé)sérialisation d'introspection). Le fichier de l'enum est **pur-Dart** : le test de pureté `test/purity/domain_purity_test.dart` reste **vert** (aucun import Flutter/Firebase/gestionnaire d'état). Cas limites documentés : `icon` = **hors parité MVP** (déclaré, fallback) ; `password` = `text` + validateur (valeur d'enum distincte mais pas de widget dédié) ; `hidden` = non rendu ; `widget` = builder libre **attaché au runtime** (la closure n'est pas dans l'annotation). Les types dont le widget vit hors-cœur (`markdown`, `geoArea`, `phoneNumber`, …) sont **servis via `ZTypeRegistry`** (E3-3b) — l'enum les **nomme**, la résolution du widget est déférée.

6. **Types-valeur d'autorité `const` dans `zcrud_core/domain` (source unique annotation ↔ `ZFieldSpec`).**
   - `ZValidatorSpec` : type-valeur `const` **déclaratif** (aucune closure, aucune exécution) couvrant l'ensemble transverse de l'inventaire (§3, ligne validators) : `required`, `minLength`, `maxLength`, `min`/`max` (littéral **ou** `minValueKey`/`maxValueKey` référençant un autre champ), `equal`/`notEqual`, `match`/`matchKey`, `email`, `url`, `ip`, `creditCard`, `phone`, `numeric`, `integer`, `dateString`, `address`, `percentage`, `password`, `pattern(regex)`. Forme : famille de variantes `const` (constructeurs de fabrique nommés ou petites sous-classes `const`). **La composition en `FormBuilderValidators` est E3** ; E2-4 ne livre que la **donnée déclarative**.
   - `ZFieldChoice` : `const { Object value, String label }` (option statique). *(Nom distinct de `ZChoice` flashcard — concept différent : option de champ, pas choix QCM.)*
   - `ZCondition` : type-valeur `const` **déclaratif** pour `displayCondition` (voir AC7).
   - `ZFieldConfig` : **base abstraite `const`** (point d'extension AD-4) ; les configs concrètes lourdes sont additives et appartiennent à leurs packages/stories. E2-4 peut livrer les configs **triviales pur-cœur** communes si utiles (ex. `ZTextConfig{minLines,maxLines,inputType}`, `ZNumberConfig{minValueKey,maxValueKey,isCurrency,isPercentage}`, `ZDateConfig{firstDateKey,lastDateKey}`) — **sans** tirer de dépendance lourde ; sinon documenter leur report. Toute config concrète reste `const` et pur-données.
   Ces types vivent dans `zcrud_core` (pas `zcrud_annotations`) car **le runtime les interprète** et **`zcrud_core` ne peut importer aucun `zcrud_*`** (AD-1, OUT=0) : les placer dans l'annotation forcerait `zcrud_core → zcrud_annotations` (cycle interdit). L'annotation les **référence** via l'unique arête `zcrud_annotations → zcrud_core`.

7. **`ZCondition` déclarative (jamais une closure) — habilite AD-2.** `ZCondition` exprime la visibilité conditionnelle sous forme **de données** : au minimum `equals(field, value)`, `notEquals(field, value)`, `isNull(field)`, `notNull(field)`, `truthy(field)`, et combinateurs `and([...])` / `or([...])` / `not(cond)`. L'**évaluation** contre l'état de formulaire est E3 (sélecteur de visibilité dédié). Justification AD-2 : « séparer structure vs valeurs — la visibilité (`displayCondition`) dérivée dans un sélecteur dédié ; seul un changement de visibilité reconstruit la LISTE » ; une closure `(item,state,crud)` (patron lex/DODLP, cause historique du focus perdu, cf. inventaire §4.1(a)) **ne peut ni être `const` ni être lue par `ConstantReader`** → proscrite dans l'annotation.

8. **Frontière statique vs runtime documentée + mapping 1:1 vers `ZFieldSpec`.** La story documente (Dev Notes) : (a) la **table de correspondance** paramètre `@ZcrudField` → champ `ZFieldSpec` (que E2-5 émettra) ; (b) la liste explicite de ce qui **n'entre pas** dans l'annotation car exigeant une closure/valeur runtime (builder `widget`, `stateValidators`, `displayCondition` dynamique dépendant du CRUD, `choiceItemsRepository` relation) et **comment** c'est attaché au runtime (config de champ / `ZTypeRegistry` / `ZFormController`). Aucun paramètre d'annotation n'exige de closure.

9. **Barrels & exports.** `zcrud_annotations.dart` exporte les 3 annotations ; `zcrud_core.dart` exporte `EditionFieldType` + les types-valeur d'autorité (`ZValidatorSpec`, `ZFieldChoice`, `ZCondition`, `ZFieldConfig`, configs triviales éventuelles) et `ZFieldRename`. Le placeholder `ZAnnotationsApi` (marqueur de version E1-2) est soit conservé comme marqueur de version, soit retiré au profit des vraies annotations — décision dev, **sans** casser l'export du barrel.

10. **Vérif verte de bout en bout.** `melos run generate` OK (aucune régénération requise par cette story, mais le workspace reste générable) → `dart/flutter analyze` **RC=0** (zéro warning nouveau, lints stricts E1-3 respectés — notamment **anti-`reflectable`** et docstrings d'API publique) → `flutter test` / `melos run test` **RC=0** → **test de pureté domaine vert** → **`graph_proof` vert** (arête `zcrud_annotations → zcrud_core` conforme, cœur OUT=0).

11. **Test de couverture de surface (const).** Un test instancie **en `const`** : chaque annotation avec **tous** ses paramètres renseignés simultanément (couvrant chaque item de la surface AC3), et chaque variante de `ZValidatorSpec` / `ZCondition` / `ZFieldChoice` ; il asserte que les valeurs sont bien portées (getters `final`). Objectif : prouver que la surface est **entièrement `const`-constructible** (donc lisible par `ConstantReader` en E2-5) et couvre label/type/validators/config/choices/condition/searchable + extras canoniques.

## Tasks / Subtasks

- [x] **T1 — Enum `EditionFieldType` (zcrud_core/domain, pur-Dart)** (AC: #5)
  - [x] Créer `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` : enum ouvert avec le catalogue de parité + `custom` ; docstrings d'API (lint E1-3) ; commentaire d'origine `technical-inventory §3` + cas limites (`icon` hors MVP, `password`, `hidden`, `widget`).
  - [x] Exporter depuis `zcrud_core.dart`.
  - [x] Vérifier que `test/purity/domain_purity_test.dart` reste vert (fichier pur-Dart).
- [x] **T2 — Types-valeur d'autorité `const` (zcrud_core/domain, pur-Dart)** (AC: #6, #7)
  - [x] `z_validator_spec.dart` : `ZValidatorSpec` déclaratif + variantes de l'ensemble transverse (inventaire §3).
  - [x] `z_field_choice.dart` : `ZFieldChoice{value,label}` `const`.
  - [x] `z_condition.dart` : `ZCondition` déclaratif (equals/notEquals/isNull/notNull/truthy + and/or/not).
  - [x] `z_field_config.dart` : base abstraite `const` `ZFieldConfig` (point d'extension AD-4) + configs triviales pur-cœur (texte/nombre/date).
  - [x] `z_field_rename.dart` (ou co-localisé) : enum `ZFieldRename { snake, none, kebab, pascal }` (aligne AD-3 ; défaut `snake`).
  - [x] Exports depuis `zcrud_core.dart` ; docstrings API ; `==`/`hashCode` seulement si l'égalité de valeur est requise (convention canonique §5).
- [x] **T3 — Annotations `const` (zcrud_annotations)** (AC: #1, #2, #3, #4)
  - [x] `lib/src/domain/annotations/zcrud_model.dart` : `@ZcrudModel({kind, fieldRename})`.
  - [x] `lib/src/domain/annotations/zcrud_field.dart` : `@ZcrudField({label, type, validators, config, choices, condition, searchable, defaultValue, readOnly, showIfNull, name, multiple})` — tous `final`, tous optionnels, défauts sûrs, constructeur `const`.
  - [x] `lib/src/domain/annotations/zcrud_id.dart` : `@ZcrudId()` marqueur `const`.
  - [x] Barrel `zcrud_annotations.dart` : exporter les 3 annotations ; `ZAnnotationsApi` **conservé** comme marqueur de version.
  - [x] `pubspec.yaml` : `dependencies: zcrud_core` **seule** arête `zcrud_*` ; **aucune** dep lourde/runtime/codegen (seul ajout : `dev_dependencies: test`).
- [x] **T4 — Frontière statique/runtime + mapping (documentation dans la story/dev notes + docstrings)** (AC: #8)
  - [x] Docstrings sur `@ZcrudField` : table de correspondance param → `ZFieldSpec` (E2-5) ; inférence `type=null` documentée « implémentée en E2-5 ».
  - [x] Documenté (docstrings) ce qui est **attaché au runtime** (builder `widget`, `stateValidators`, relation `choiceItemsRepository`, `displayCondition` dynamique) et par quel canal (`ZTypeRegistry`/config/`ZFormController`).
- [x] **T5 — Tests** (AC: #1, #11)
  - [x] `packages/zcrud_annotations/test/annotations_const_test.dart` : instanciation `const` de chaque annotation avec **tous** les paramètres ; assertions sur les getters.
  - [x] `packages/zcrud_annotations/test/no_runtime_dep_test.dart` : inspection pubspec (seule arête zcrud_core, 0 dep lourde) + grep imports `lib/` (0 import lourd/Flutter).
  - [x] `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart` : enum (38 parité + `custom` = 39) + couverture des variantes `ZValidatorSpec`/`ZCondition`/`ZFieldChoice`/`ZFieldConfig`.
- [x] **T6 — Vérif verte rejouée** (AC: #10)
  - [x] `melos run generate` OK ; `melos run analyze` RC=0 ; `melos run test` RC=0 ; pureté domaine verte ; `melos run verify` (graph_proof + gates) RC=0.

## Dev Notes

### Décision d'architecture — OÙ vit `EditionFieldType` (et pourquoi) — **tranché : `zcrud_core`**

**Décision : `EditionFieldType` (et `ZValidatorSpec`/`ZFieldChoice`/`ZCondition`/`ZFieldConfig`) vivent dans `zcrud_core` (couche `domain`, pur-Dart). `zcrud_annotations` les référence via l'unique arête `zcrud_annotations → zcrud_core`.** Ce n'est pas un choix libre : l'architecture le **mandate** de trois côtés convergents :

1. **Component/Responsibility map (architecture.md:232)** : « **Catalogue de champs (FR-2) → `zcrud_core` (+ registre)** ». Le catalogue de champs = `EditionFieldType`.
2. **Naming table (architecture.md:141)** : « enum canonique des champs = **`EditionFieldType`** » (singulier, un seul enum, préfixe `Z` non requis pour cet enum historiquement nommé).
3. **AD-1 diagramme (architecture.md:38)** : arête explicite `ANN[zcrud_annotations] --> CORE[zcrud_core]`. Les annotations **dépendent** du cœur ; jamais l'inverse (cœur OUT=0).

**Alternative écartée (et pourquoi).** Placer `EditionFieldType` dans `zcrud_annotations` (pour une pureté « à la `json_annotation` ») **forcerait** `zcrud_core → zcrud_annotations` (le runtime `ZFieldSpec.type` et le moteur d'édition E3 en ont besoin). Or **AD-1 interdit toute arête sortante du cœur vers un `zcrud_*`** (OUT=0, prouvé par `graph_proof.py`). Cette alternative est donc **structurellement impossible**. Dupliquer l'enum des deux côtés violerait « source unique de vérité » (AD-3) et créerait une dérive de contrat. → `zcrud_core` est le seul emplacement cohérent.

### Nuance à flaguer — `zcrud_annotations` tire **transitivement le SDK Flutter** (conséquence acceptée + ambiguïté remontée)

Depuis l'**inflexion E2-7 (AD-14)**, `zcrud_core` déclare `dependencies.flutter: {sdk: flutter}` (`ChangeNotifier`/`ValueListenable`/`InheritedWidget` de `foundation`/`widgets`). Comme `zcrud_annotations → zcrud_core`, `zcrud_annotations` devient **transitivement** un package Flutter. **Lecture de l'AC « aucune dépendance runtime » retenue :** l'AC vise l'absence de dépendance **lourde/comportementale ajoutée** (codegen `build_runner`/`source_gen`/`analyzer`, gestionnaire d'état, Firebase, Syncfusion, Quill, Maps) **et** le fait que les annotations soient des **`const` pur-données** ; l'arête `→ zcrud_core` est **sanctionnée par le diagramme AD-1** et ne compte **aucune** arête `zcrud_*` sortante du cœur (`graph_proof` inchangé). La transitivité Flutter est une **conséquence de E2-7**, pas une dépendance runtime que la story introduit. **Ambiguïté remontée à l'architecte** (voir « Ambiguïtés »), avec mitigation future possible **hors périmètre** (extraire un noyau pur-Dart `zcrud_kernel` portant `EditionFieldType` si une pureté stricte des annotations devient exigée par un consommateur non-Flutter du seul package d'annotations). **Ne pas** implémenter cette extraction en E2-4.

### Découpage E2-4 vs E2-5 (anti-empiètement)

- **E2-4 (cette story)** = **surface d'autorité** : les annotations (`quoi`) + `EditionFieldType` + types-valeur d'autorité. C'est ce que le générateur **lira**.
- **E2-5** = **projection** : la classe runtime `ZFieldSpec` + son émission `List<ZFieldSpec>` + `toMap/fromMap/copyWith` (sentinelle) + `register(..., fieldSpecs:)`. C'est ce que le générateur **émettra**.
- **Justification du non-report de `EditionFieldType` en E2-5** : `@ZcrudField.type` en a besoin *maintenant* (sinon la surface n'est pas `const`-complète, AC3/AC11). `ZFieldSpec` la classe, elle, n'est pas requise pour que l'annotation soit `const`-constructible → laissée à E2-5 (« E2-5 génère le `ZFieldSpec` dans le modèle »). Les types-valeur (`ZValidatorSpec`…) suivent `EditionFieldType` par le même raisonnement (référencés par les params d'annotation).

### Table de correspondance `@ZcrudField` → `ZFieldSpec` (que E2-5 émettra)

| `@ZcrudField` (E2-4, authoring) | `ZFieldSpec` (E2-5, runtime) | Interprète |
|---|---|---|
| `name` (ou dérivé du champ Dart via `fieldRename`) | `name` (clé persistée) | E2-5 |
| `label` | `label` | E3/E4 (résolution l10n) |
| `type` (`null` ⇒ inféré du type Dart) | `type: EditionFieldType` | E3 (widget), E4 (colonne) |
| `validators: List<ZValidatorSpec>` | `validators` | **E3** compose → `FormBuilderValidators` |
| `config: ZFieldConfig?` | `config` | E3 (config par type) |
| `choices: List<ZFieldChoice>?` | `choices` | E3 (select/radio/checkbox) |
| `condition: ZCondition?` | `condition` (displayCondition) | **E3** évalue (sélecteur visibilité, AD-2) |
| `searchable` | `searchable` | **E4** (filtre/recherche) |
| `defaultValue` | `defaultValue` | E3/E2-5 (`fromMap` défaut) |
| `readOnly` / `showIfNull` | `readOnly` / `showIfNull` | E3 (mode lecture) |
| `multiple` | `multiple` | E3 (multi-select) |

### Frontière statique (annotation) vs runtime (attaché ailleurs)

**N'entre PAS dans l'annotation** (exige une closure/valeur runtime, illisible par `ConstantReader`) :
- **builder `widget` libre** (`(state, readOnly, …) → Widget`) → `EditionFieldType.widget` **nomme** le type ; la closure est fournie au runtime via config de champ / `ZTypeRegistry`.
- **`stateValidators`** (validateurs dépendant de l'état du formulaire) → attachés au `ZFormController` (E3), pas au schéma statique.
- **`displayCondition` dynamique dépendant du CRUD** (`(item, state, crud) → bool`) → remplacé par `ZCondition` déclaratif (cas courants) ; les cas irréductiblement dynamiques passent par une surcouche runtime (E3), **jamais** par l'annotation.
- **relation dynamique** (`choiceItemsRepository`/`RequestBuilder` de `crudDataSelect`) → `EditionFieldType.relation` nomme le type ; la source (repository/stream) est câblée au runtime (E4/ports E2-2), pas dans l'annotation `const`.

### Conventions à respecter (canonique §5 + AD)

- **Classes d'annotation** : `final` + constructeur `const` + zéro comportement (AC1). Docstrings d'API publique obligatoires (lint E1-3, `public_member_api_docs`).
- **Enum ouvert** (AD-4) : `EditionFieldType` porte `custom` ; discipline `@JsonKey(unknownEnumValue: custom)` documentée pour toute introspection future (l'enum lui-même n'est pas persisté en E2-4, mais la discipline est posée).
- **Nommage** (AD Naming) : préfixe `Z` pour les types-valeur (`ZValidatorSpec`, `ZFieldChoice`, `ZCondition`, `ZFieldConfig`, `ZFieldRename`) ; `EditionFieldType` conserve son nom canonique historique (architecture.md:141) sans préfixe. Corriger tout typo hérité (pas d'alias legacy).
- **Pureté domaine** : les fichiers `zcrud_core/lib/src/domain/edition/*.dart` sont **pur-Dart** (garde `domain_purity_test.dart`).
- **RTL/a11y, thème** : sans objet ici (pas de widget dans cette story).

### Project Structure Notes

- `zcrud_annotations` : ajoute `lib/src/domain/annotations/{zcrud_model,zcrud_field,zcrud_id}.dart` ; barrel étendu. Conforme au patron « barrel `lib/<pkg>.dart` + impl `lib/src/` » (AD Naming). Pubspec **inchangé** côté dépendances (l'arête `zcrud_core` existe déjà depuis le squelette E1-2).
- `zcrud_core` : ajoute `lib/src/domain/edition/{edition_field_type,z_validator_spec,z_field_choice,z_condition,z_field_config,z_field_rename}.dart` (nouveau sous-dossier `edition/` sous `domain/`) ; barrel `zcrud_core.dart` étendu. Cohérent avec le layout existant (`domain/{contracts,data,extension,failures,ports,registry,sync}`).
- **Variance assumée** : le slot `fieldSpecs` du `ZcrudRegistry` (réservé additivement, `zcrud_registry.dart:43`) n'est **pas** câblé ici — il l'est en E2-5 (émission du `ZFieldSpec[]`). E2-4 ne touche pas au registre.

### References

- [Source: epics-zcrud-2026-07-09/epics.md#Story E2-4] — « couvrent label/type/validators/config/choices/condition/`searchable` ; aucune dépendance runtime ».
- [Source: epics-zcrud-2026-07-09/epics.md:61,67] — ordre intra-E2 ; E2-5 consomme les annotations (codegen, sentinelle, throw si type non enregistré).
- [Source: architecture.md#AD-3] — codegen `@ZcrudModel`/`@ZcrudField` → `toMap/fromMap/copyWith` + `ZFieldSpec[]` + enregistrement ; `reflectable` banni ; `freezed` non imposé.
- [Source: architecture.md#AD-4] — enums ouverts (`custom` + `unknownEnumValue`), extension par composition + registre.
- [Source: architecture.md#AD-1] — cœur OUT=0 ; diagramme `zcrud_annotations → zcrud_core`.
- [Source: architecture.md:141,232] — `EditionFieldType` = enum canonique des champs ; catalogue de champs → `zcrud_core`.
- [Source: architecture.md#AD-2] — displayCondition dérivée dans un sélecteur ; place stable pour champs conditionnels (justifie `ZCondition` déclaratif).
- [Source: docs/technical-inventory.md:197-232] — catalogue de parité `EditionFieldTypes` DODLP (référence unique) + ensemble transverse `validators` + `readOnly`/`showIfNull`/`displayCondition`.
- [Source: docs/canonical-schema.md:5,§5] — désérialisation défensive, IDs `String` opaques, conventions `@JsonSerializable` pur / enums camelCase.
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart:43-53] — slot `ZFieldSpec`/`fieldSpecs` réservé additivement à E2-4/E2-5.
- [Source: packages/zcrud_core/pubspec.yaml] — cœur tire le SDK Flutter (AD-14, E2-7) → transitivité Flutter des annotations.

### Ambiguïtés détectées (à valider par l'orchestrateur/architecte — ne bloquent pas le dev)

1. **Transitivité Flutter des annotations.** `zcrud_annotations → zcrud_core (Flutter, AD-14/E2-7)` rend `zcrud_annotations` transitivement Flutter. Acceptée ici (AC lu comme « aucune dep **lourde ajoutée** ») ; à trancher si un consommateur non-Flutter du seul package d'annotations émerge → extraction future d'un `zcrud_kernel` pur-Dart (hors périmètre E2-4).
2. **`validators` : profondeur de la surface `ZValidatorSpec`.** L'inventaire liste ~20 validateurs. E2-4 vise la **couverture déclarative** ; l'exhaustivité fine (paramétrage de chaque validateur) peut être itérée. Décision retenue : livrer l'ensemble transverse nommé, la composition restant E3.
3. **Configs concrètes par type.** E2-4 livre la **base `ZFieldConfig`** ; les configs triviales pur-cœur (texte/nombre/date) sont livrables ou reportées selon le coût, les lourdes (géo/fichier/rich-text/stepper) restent à leurs packages (AD-4). À confirmer : livrer les triviales maintenant ou tout déférer.
4. **`ZAnnotationsApi` (placeholder E1-2).** Conserver comme marqueur de version ou retirer ? Décision dev, sans casser le barrel.
5. **Inférence `type=null`.** La table d'inférence (Dart type → `EditionFieldType`) est **documentée** en E2-4 mais **implémentée** en E2-5 ; s'assurer que la doc de l'annotation ne promet pas un comportement non encore livré (marquer « inféré par E2-5 »).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD `dev-story`, effort high).

### Debug Log References

- `melos run analyze` → RC=0 (14 packages, « No issues found »).
- `melos run test` → RC=0. Totaux : `zcrud_annotations` 8 (dart test), `zcrud_core` 155, `zcrud_get` 12, `zcrud_riverpod` 8, `zcrud_provider` 8 → **191 tests**. +15 nouveaux tests d'édition dans `zcrud_core`, +8 dans `zcrud_annotations`.
- `melos run verify` → RC=0 : `ACYCLIQUE OK`, `CORE OUT=0 OK`, `gate:melos OK` (13 scripts), `gate:reflectable OK`, `gate:secrets OK`, `gate:codegen OK` (0 modèle `@ZcrudModel`, 0 `.g.dart` manquant), `gate:compat OK`. `verify:serialization` reste le no-op E2-10 documenté (gate vert).
- `melos run generate` → SUCCESS ; `melos list` = **14** ; **0** `.g.dart` sous `packages/**` ; `test/purity/domain_purity_test.dart` vert (les 6 fichiers `domain/edition/*.dart` sont pur-Dart).

### Completion Notes List

- **Décisions d'ambiguïté (story §Ambiguïtés) tranchées :**
  - **(2) Profondeur `ZValidatorSpec`** : livré l'**ensemble transverse nommé** de l'inventaire §3 (`ZValidatorKind` 22 variantes : required, minLength, maxLength, min/minKey, max/maxKey, equal, notEqual, match, email, url, ip, creditCard, phone, numeric, integer, dateString, address, percentage, password, pattern) sous forme de constructeurs de fabrique `const` (paramètres littéraux OU clé de champ). Composition `FormBuilderValidators` laissée à E3.
  - **(3) Configs concrètes** : livré la **base abstraite `ZFieldConfig`** (extension AD-4) **+ les 3 configs triviales pur-cœur** (`ZTextConfig`, `ZNumberConfig`, `ZDateConfig`). Les configs lourdes (géo/fichier/rich-text/stepper) restent déférées à leurs packages/stories.
  - **(4) `ZAnnotationsApi`** : **conservé** comme marqueur de version (`version` + `coreApiVersion`), désormais adossé à la surface pure `package:zcrud_core/edition.dart`.
  - **(1)/(5) Transitivité Flutter & inférence** : voir décision d'entrée pure ci-dessous ; l'inférence `type=null` est **documentée** (docstring) et explicitement **« implémentée en E2-5 »** (rien promis en E2-4).
- **Décision structurante — entrée publique pure `package:zcrud_core/edition.dart` :** le barrel principal `zcrud_core.dart` ré-exporte la couche `presentation` (E2-7) qui tire le SDK Flutter (`dart:ui`). Comme `zcrud_annotations` doit rester **pur-données et exécutable sous `dart test`** (melos le classe `--no-flutter`), les annotations importent une **entrée publique ciblée** (`lib/edition.dart`) exposant uniquement le catalogue + types-valeur + `ZCoreApi`, **sans** charger transitivement Flutter. L'arête AD-1 `zcrud_annotations → zcrud_core` (pubspec) est **inchangée** ; seule la granularité d'import l'est. `EditionFieldType` & co restent aussi exportés par le barrel principal (AC9). Cette approche évite l'extraction d'un futur `zcrud_kernel` (ambiguïté #1) pour le périmètre courant.
- **Catalogue `EditionFieldType`** : 38 valeurs de parité (technical-inventory §3) + `custom` (AD-4) = **39** ; valeurs camelCase (discipline `@JsonKey(unknownEnumValue: custom)` documentée). Cas limites documentés (`icon` hors MVP, `password`, `hidden`, `widget`).
- **`ZCondition`** : le combinateur `not` porte un champ dédié `operand` (`List<ZCondition>[operand]` n'est **pas** une constante valide dans un initialiseur `const` — corrigé après échec analyzer `invalid_constant`).
- **Aucune dépendance runtime lourde ajoutée** (AC1) : `zcrud_annotations/pubspec.yaml` conserve `dependencies: {zcrud_core}` seul ; ajout unique `dev_dependencies: {test}`. Prouvé par `no_runtime_dep_test.dart` (pubspec + grep imports `lib/`) et par `graph_proof` (CORE OUT=0, acyclique).

### File List

**Créés — `zcrud_core` (couche domain, pur-Dart) :**
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`
- `packages/zcrud_core/lib/src/domain/edition/z_validator_spec.dart`
- `packages/zcrud_core/lib/src/domain/edition/z_field_choice.dart`
- `packages/zcrud_core/lib/src/domain/edition/z_condition.dart`
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart`
- `packages/zcrud_core/lib/src/domain/edition/z_field_rename.dart`
- `packages/zcrud_core/lib/edition.dart` (entrée publique pure — authoring surface sans Flutter)
- `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart`

**Créés — `zcrud_annotations` :**
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart`
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart`
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_id.dart`
- `packages/zcrud_annotations/test/annotations_const_test.dart`
- `packages/zcrud_annotations/test/no_runtime_dep_test.dart`

**Modifiés :**
- `packages/zcrud_core/lib/zcrud_core.dart` (exports de la surface d'édition)
- `packages/zcrud_annotations/lib/zcrud_annotations.dart` (exports des 3 annotations)
- `packages/zcrud_annotations/lib/src/domain/z_annotations_api.dart` (import → `edition.dart`)
- `packages/zcrud_annotations/pubspec.yaml` (ajout `dev_dependencies: test`)
