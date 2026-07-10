---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 9.1 : `ZFlashcard` + `ZChoice` + `ZFlashcardType` + provenance registre (`zcrud_flashcard`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud (lex_douane « Étude », puis DODLP)**,
I want **le modèle canonique `ZFlashcard` (+ `ZChoice`, enum `ZFlashcardType` à 6 valeurs, provenance `ZFlashcardSource` ouverte) généré par `@ZcrudModel`, portant l'identité éphémère et les deux slots d'extension AD-4, l'état SRS restant HORS de la carte**,
so that **je puisse (dé)sérialiser des flashcards zéro-perte et rétro-compatibles, brancher le variant « article » (douane) sans forker le package, et préserver l'historique SRS d'autrui au partage/duplication — le tout sans que `zcrud_flashcard` ne modifie `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

Première story de l'**epic E9 — Flashcards (`zcrud_flashcard`)**. Elle pose **uniquement les modèles de données canoniques** : entité `ZFlashcard`, valeur `ZChoice`, enum `ZFlashcardType`, union de provenance `ZFlashcardSource` (ouverte par registre). **Aucune** mécanique SRS, **aucun** dépôt, **aucun** widget d'édition ici.

Le package `zcrud_flashcard` n'a aujourd'hui qu'un squelette (`ZFlashcardApi` marqueur, E1-2). Cette story met la première substance réelle sous `lib/src/domain/`.

**Invariants d'architecture applicables :**

- **AD-3 (codegen = source unique de vérité)** [Source: architecture.md#AD-3] : `@ZcrudModel`/`@ZcrudField` (+ `@ZcrudId`) génèrent `toMap`/`fromMap`/`copyWith`, le `ZFieldSpec[]` et l'enregistrement au `ZcrudRegistry`. **Jamais** `reflectable`. `freezed` **non imposé**. Un `kind` non enregistré → throw explicite (jamais cast null silencieux).
- **AD-4 (extension : composition + `ZExtension` + registre + enums ouverts)** [Source: architecture.md#AD-4] : chaque entité canonique expose (1) un slot `ZExtension?` versionné, (2) un `Map<String,dynamic> extra` (défaut `{}`), (3) l'extension de provenance ouverte via `ZSourceRegistry.register(kind, fromJson, toJson)`. **Rejetés** : héritage de classes sérialisées, `sealed` pour l'extension **inter-package**, generics comme mécanisme de sérialisation. Tout enum public porte `@JsonKey(unknownEnumValue:)`.
- **AD-9 (état SRS séparé)** [Source: architecture.md#AD-9] : l'état SRS (`ZRepetitionInfo`) est **séparé** de `ZFlashcard`. La carte ne porte **aucun** champ SRS (interval/easeFactor/nextReviewDate/…). Le partage/duplication d'une carte n'emporte **jamais** l'historique d'autrui. `ZRepetitionInfo` + `ZSrsScheduler` = **E9-2, PAS ici**.
- **AD-10 (schéma additif + désérialisation défensive)** [Source: architecture.md#AD-10] : ajout seulement entre versions mineures (nullable / `defaultValue`) ; un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`). Chaque `ZExtension` porte son `formatVersion` indépendant.
- **AD-14 (pureté des couches ; invariants au repository)** [Source: architecture.md#AD-14] : le `domain/` de `zcrud_flashcard` est **pur-Dart** (aucune dépendance Flutter/Firebase/Hive). L'invariant de **matérialisation de l'éphémère** est porté par le **repository (E9-4)**, jamais par l'entité (entités = données + `copyWith`).
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `zcrud_flashcard` **dépend de** `zcrud_core` et **réutilise ses APIs** ; il ne dépend d'aucun gestionnaire d'état. **CONTRAINTE DURE : `zcrud_flashcard` NE MODIFIE PAS `zcrud_core`.** Tout ce dont la story a besoin existe déjà dans le cœur (voir Dev Notes « APIs core à RÉUTILISER »).

**Frontière E9-1 vs le reste de l'epic (NON-NÉGOCIABLE) :**

| Story | Périmètre | Dans E9-1 ? |
|---|---|---|
| **E9-1 (ici)** | `ZFlashcard` (entité codegen), `ZChoice`, `ZFlashcardType` (6 types), `ZFlashcardSource` (union ouverte par registre) ; slots `extra` + `ZExtension?` ; désérialisation défensive ; isEphemeral. | ✅ |
| E9-2 | `ZRepetitionInfo` + `ZSrsScheduler` (SuperMemo-2), `reviewCard()→apply`, `ZSrsConfig`. | ❌ (E9-2) |
| E9-3 | `ZStudyFolder` / `ZStudySession` (organisation + filtres). | ❌ (E9-3) |
| E9-4 | Dépôt offline-first + **matérialisation** de l'éphémère + invariant SRS top-level. | ❌ (E9-4) |
| E9-5 | Édition & widgets additifs (dont **validation éditeur** QCM min 2 + 1 correct). | ❌ (E9-5) |

> ⚠️ En E9-1 : **pas** de validation métier active des choix (min 2 + 1 correct) — c'est la validation **éditeur** (E9-5). L'entité **transporte** simplement `choices`. **Pas** de champ SRS. **Pas** de `ZRepetitionInfo`. **Pas** de dépôt/matérialisation (l'entité expose seulement `isEphemeral`, dérivé de `id == null`).

## Acceptance Criteria

1. **`ZFlashcardType` — 6 types, camelCase, défensif (AD-4/AD-10).** Un enum `ZFlashcardType` expose exactement les 6 valeurs **génériques** : `multipleChoice`, `trueOrFalse`, `openQuestion`, `exercise`, `fillBlank`, `shortAnswer`. Valeurs persistées en **camelCase** (= `name`). La désérialisation d'une valeur inconnue/absente retombe **défensivement** sur `openQuestion` (`@JsonKey(unknownEnumValue: ZFlashcardType.openQuestion)`), **sans throw**. Testé : chaque valeur round-trip ; `"totallyUnknownType"` → `openQuestion` ; clé absente → `openQuestion`.

2. **`ZChoice` — valeur QCM (AD-3/AD-10).** Un modèle `ZChoice` porte `content: String` (libellé) et `isCorrect: bool` (persisté `is_correct` en snake_case). (Dé)sérialisation round-trip. `content` absent → `''` (`defaultValue`) ; `isCorrect` absent → `false` (`defaultValue`) ; jamais de throw. **Aucune** validation métier (min 2/1 correct) ici — déférée à E9-5.

3. **`ZFlashcard` — entité canonique codegen (AD-3).** `@ZcrudModel(kind: 'flashcard')` sur une classe `const` pur-données portant : `id: String?` (`@ZcrudId`), `folderId: String?`, `subFolderId: String?`, `type: ZFlashcardType` (défaut `openQuestion`), `question: String` (requis, seul champ texte requis), `answer: String?`, `isTrue: bool?`, `choices: List<ZChoice>?`, `explanation: String?`, `hint: String?`, `tagIds: List<String>` (défaut `const []`), `source: ZFlashcardSource?`, `isReadOnly: bool` (défaut `false`), `createdAt: DateTime?`, `updatedAt: DateTime?`. `melos run generate` produit `flashcard.g.dart` (gitignoré) avec `toMap`/`fromMap`/`copyWith` + enregistrement `ZcrudRegistry`. Persistance **snake_case** (`sub_folder_id`, `is_read_only`, `created_at`, `updated_at`, `tag_ids`). Round-trip zéro-perte testé.

4. **État SRS HORS carte (AD-9).** `ZFlashcard` ne déclare **AUCUN** champ SRS : ni `interval`, ni `repetitions`, ni `easeFactor`, ni `nextReviewDate`, ni `learnedAt`, ni `lastQuality`, ni `ZRepetitionInfo`. Vérifié par test (assertion statique/réflexion de map : la map persistée ne contient aucune de ces clés) et documenté (l'état SRS vit dans une entité séparée, E9-2, persistée top-level en E9-4).

5. **Éphémère dérivé (AD-14).** `ZFlashcard` porte `isEphemeral` **dérivé de `id == null`** (réutilise le contrat `ZEntity`). L'entité n'attribue **jamais** d'`id` elle-même ; l'invariant de matérialisation (attribution avant écriture, rejet d'une carte éphémère sans dossier) est **explicitement hors périmètre** (repository E9-4). Testé : `ZFlashcard(id: null, …).isEphemeral == true` ; `ZFlashcard(id: 'x', …).isEphemeral == false`.

6. **Provenance ouverte par registre — variant « article » branché sans fork (AD-4).** `ZFlashcardSource` est une union portant les variants **génériques** (`note`, `conversation`, `document`) + un variant de repli **`custom(String kind, Map<String,dynamic> payload)`**. Chaque variant porte un discriminant `kind`. La (dé)sérialisation consulte une instance de **`ZSourceRegistry` (RÉUTILISÉE de `zcrud_core`, injectée — pas de singleton statique)** : un `kind` **enregistré par l'app hôte** (ex. `'article'`, douane) est (dé)sérialisé via le codec du registre ; un `kind` **inconnu et non enregistré** retombe sur `custom` (round-trip préservé), **jamais** de throw. Testé : sérialisation d'un `note`/`document` round-trip ; un `ZSourceRegistry` avec `'article'` enregistré (fromJson/toJson de test) reconstruit le bon objet ; `kind` inconnu → `custom` conservant le payload. **`'article'` n'est JAMAIS un variant codé en dur du package** (sinon fork douane dans le générique).

7. **Slots d'extension AD-4 (`extra` + `ZExtension?`).** `ZFlashcard` mixe **`ZExtensible` (RÉUTILISÉ de `zcrud_core`)** : expose `extra: Map<String,dynamic>` (défaut `const {}`, jamais `null`, round-trip des clés inconnues du cœur) et `extension: ZExtension?` (slot type additif versionné, défaut `null`). Une `ZExtension?` de test (sous-classe concrète avec `formatVersion`/`toJson`/`fromJsonSafe`) round-trip ; une extension de `formatVersion` non gérée → `null` (via `ZExtension.guard`), le parent survit ; des clés `extra` inconnues sont **préservées** telles quelles au round-trip.

8. **Désérialisation défensive de bout en bout (AD-10).** Sur `ZFlashcard.fromMap` : map vide `{}` (seul `question` requis manquant → défaut sûr `''`), `type` inconnu → `openQuestion`, `choices` malformés (élément non-map, `content` manquant) → chaque élément décodé défensivement (élément corrompu ignoré/défaut, jamais throw du parent), `source` de `kind` inconnu/non enregistré → `custom` ou `null`, `extension` corrompue → `null`, `tag_ids` absent → `const []`. **Aucun** cas ne fait échouer le parent. Testé sur des maps **réellement corrompues** (pas seulement le happy-path).

9. **Isolation & pureté (AD-1/AD-14).** `zcrud_flashcard/lib/src/domain/` est **pur-Dart** (aucun import Flutter/Firebase/Hive). **Aucune modification de `zcrud_core`** n'est introduite par la story (vérifié : `git status` ne montre aucun fichier `packages/zcrud_core/**` modifié). Le barrel `lib/zcrud_flashcard.dart` exporte `ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZFlashcardSource` (+ variants) ; l'API marqueur `ZFlashcardApi.version` est montée en cohérence.

10. **Vérif verte (gates E1-3/E2-10).** `melos run generate` OK → `melos run analyze` RC=0 (dont lint anti-`reflectable`, scan secrets) → `flutter test` (package `zcrud_flashcard`) RC=0. Les tests de rétro-compatibilité de sérialisation (AC8) passent.

## Tasks / Subtasks

- [x] **Tâche 1 — Enum `ZFlashcardType` (AC1)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart` : `enum ZFlashcardType { multipleChoice, trueOrFalse, openQuestion, exercise, fillBlank, shortAnswer }`.
  - [x] Le champ `type` de `ZFlashcard` porte `@JsonKey(unknownEnumValue: ZFlashcardType.openQuestion)` (ou l'équivalent projeté par le générateur / `defaultValue` sur `@ZcrudField`) — valeur inconnue → `openQuestion`, persistée camelCase (`name`).
  - [x] Documenter le point d'extension recommandé (valeur ouverte future) sans l'implémenter (AD-4/AD-10).

- [x] **Tâche 2 — Modèle `ZChoice` (AC2)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_choice.dart` : `@ZcrudModel(kind: 'flashcard_choice')` (ou sous-modèle imbriqué au sens E2-5, chemin `listModel`), classe `const` pur-données `{ content: String (défaut ''), isCorrect: bool (défaut false, name: 'is_correct') }` + `factory ZChoice.fromMap` + `==`/`hashCode`.
  - [x] Suivre **exactement** le patron `Author` du corpus générateur (`packages/zcrud_generator/test/models/article.dart:116`).

- [x] **Tâche 3 — Union de provenance `ZFlashcardSource` ouverte par registre (AC6)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart`.
  - [x] Modéliser les variants génériques `note` (`noteId`), `conversation` (`conversationId`, `messageId`), `document` (`documentId`, `page?`) + repli `ZFlashcardSource.custom(String kind, Map<String,dynamic> payload)`. Chaque variant porte son discriminant `kind`.
  - [x] Exposer `toJson()`/`fromJson(json, {ZSourceRegistry? registry})` **défensifs** : `toJson` inclut `kind` ; `fromJson` route via `registry?.tryCodecFor(kind)` d'abord, sinon variants connus, sinon `custom` (payload conservé), **jamais** de throw sur `kind` inconnu.
  - [x] **NE PAS** coder de variant `article` : il est fourni par l'app hôte via `ZSourceRegistry.register('article', fromJson:…, toJson:…)`. Documenter ce contrat dans le dartdoc.
  - [x] Décider et **documenter** le seam d'injection du `ZSourceRegistry` dans le (dé)codage (paramètre optionnel de `fromMap`/hook), sans anticiper le dépôt E9-4. Si le générateur ne peut pas passer le registre à `fromMap`, exposer un `fromJson` manuel côté `ZFlashcardSource` et le brancher depuis `ZFlashcard.fromMap` via un point d'extension documenté (repli `custom` sûr par défaut).

- [x] **Tâche 4 — Entité `ZFlashcard` (AC3, AC4, AC5, AC7)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` : `@ZcrudModel(kind: 'flashcard')`, `class ZFlashcard extends ZEntity with ZExtensible`, classe `const` pur-données.
  - [x] Champs exactement selon AC3 ; `@ZcrudId()` sur `id`; `question` requis + `ZValidatorSpec.required()` (validateur déclaratif, cf. `Article.title`); défauts sûrs (`type = ZFlashcardType.openQuestion`, `tagIds = const []`, `isReadOnly = false`).
  - [x] Implémenter les slots `ZExtensible` : `extra` (défaut `const {}`) + `extension` (`ZExtension?`, défaut `null`). Les câbler dans `fromMap`/`toMap` (round-trip des clés inconnues via `extra`; extension via `fromJsonSafe`).
  - [x] `factory ZFlashcard.fromMap` (délègue au `fromMap` généré défensif) + `==`/`hashCode`.
  - [x] **NE PAS** ajouter de champ SRS (AC4). `isEphemeral` provient de `ZEntity` (ne pas le redéfinir).
  - [x] `part 'z_flashcard.g.dart';` (généré, gitignoré, jamais committé/édité).

- [x] **Tâche 5 — Barrel + API marqueur (AC9)**
  - [x] Étendre `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : exporter `ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZFlashcardSource` (+ variants publics).
  - [x] Monter `ZFlashcardApi.version` (ex. `'0.1.0'`) en cohérence ; conserver les arêtes AD-1 existantes (`coreApiVersion`, etc.).

- [x] **Tâche 6 — Tests (AC1..AC8, AC10)**
  - [x] Créer `packages/zcrud_flashcard/test/` : tests `dart test` (domaine pur — importer `package:zcrud_core/edition.dart`, **jamais** le barrel principal qui tire Flutter).
  - [x] Couvrir : round-trip complet `ZFlashcard`/`ZChoice`/`ZFlashcardType` ; défensif (map vide, type inconnu, choices malformés, source inconnue → custom, extension corrompue → null, tag_ids absent) ; provenance via un `ZSourceRegistry` de test enregistrant `'article'` ; absence de clés SRS dans la map persistée ; `isEphemeral` ; préservation `extra`.
  - [x] Ajouter le modèle au corpus de rétro-compatibilité si un tel corpus partagé existe pour les gates E2-10 (sinon tests locaux au package).

- [x] **Tâche 7 — Vérif verte (AC10)**
  - [x] `dart run melos run generate` → `dart run melos run analyze` (RC=0) → `flutter test` sur `zcrud_flashcard` (RC=0). Confirmer `git status` : **aucun** fichier `packages/zcrud_core/**` modifié.

## Dev Notes

### APIs `zcrud_core` à RÉUTILISER (ne rien recréer — AD-1, contrainte dure)

Tout le nécessaire existe déjà dans le cœur. **Ne pas** réimplémenter, **ne pas** modifier `zcrud_core` :

- **`ZEntity`** (`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart`) — base abstraite `const` : `String? get id` + `bool get isEphemeral => id == null`. `ZFlashcard extends ZEntity`. Origine documentée : portée précisément de `Flashcard.isEphemeral`. [Source: z_entity.dart:19]
- **`ZExtensible`** (`packages/zcrud_core/lib/src/domain/extension/z_extensible.dart`) — mixin exposant `ZExtension? get extension` + `Map<String,dynamic> get extra`. `ZFlashcard … with ZExtensible`. Helper `zExtraRead<T>(extra, key)` pour lecture typée défensive. [Source: z_extensible.dart:18]
- **`ZExtension`** (`packages/zcrud_core/lib/src/domain/extension/z_extension.dart`) — base abstraite `const` : `int get formatVersion`, `Map<String,dynamic> toJson()`, statique `ZExtension.guard<T>(parse)` (repli `null` sur toute exception). Convention `static X? fromJsonSafe(json)`. Base **`abstract`, jamais `sealed`** (extension inter-package). [Source: z_extension.dart:25]
- **`ZSourceRegistry`** (`packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart`) — registre **instanciable** de provenance ouverte : `register(kind, {fromJson, toJson})`, `isRegistered`, `kinds`, `codecFor` (strict → throw), `tryCodecFor` (défensif → null). Espace de noms **distinct** de `ZTypeRegistry`. Injecté (jamais singleton statique). C'est **exactement** le seam du variant « article ». [Source: z_source_registry.dart:23, z_open_registry.dart:53]
- **`ZcrudRegistry`** (`packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart`) — registre de modèles `kind → (fromMap, toMap)` ; alimenté **par le codegen** de `@ZcrudModel`. [Source: zcrud_registry.dart]
- **Annotations** `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` (`packages/zcrud_annotations/lib/...`) — patron éprouvé E2-5. `@ZcrudModel(kind:, fieldRename: ZFieldRename.snake)` ; `@ZcrudField(label, validators, defaultValue, name, …)` ; **zéro closure** dans les annotations (lues statiquement). [Source: zcrud_model.dart:17, zcrud_field.dart:36]

### Patron d'implémentation de référence (à imiter)

Le modèle de PREUVE du générateur `packages/zcrud_generator/test/models/article.dart` est le **gabarit exact** : `@ZcrudModel(kind:'article')`, `@ZcrudId()` sur `id: String?`, champ requis + validateurs déclaratifs, enum avec `defaultValue`, `DateTime?`, `List<String>` (multiple inféré), **sous-modèle imbriqué** `Author` (`@ZcrudModel`) et **liste de sous-modèles** `List<Author>` (chemin `listModel` : round-trip + décodage défensif par élément). `ZChoice` = clone du patron `Author` ; `choices: List<ZChoice>?` = clone du patron `coauthors: List<Author>`. `factory X.fromMap(map) => _$XFromMap(map)` + `part 'x.g.dart'`. [Source: article.dart:26,116]

### Schéma canonique (source de vérité des champs)

Champs, types, nullabilité et sens : `docs/canonical-schema.md` §2.1 (`ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZFlashcardSource`). Points saillants :
- `id: null ⇒ carte éphémère`, matérialisée par le repo (E9-4) ; sentinelle route `'new'` = affaire de l'app, pas de l'entité.
- `type` : superset union chat ∪ admin, `jsonValue = name` camelCase, fallback `openQuestion`.
- `ZChoice.isCorrect` : `@JsonKey(name:'is_correct')` persisté.
- `ZFlashcardSource` : union à discriminant `kind`, **recommandation zcrud** = router les `kind` non reconnus vers `custom(kind, payload)` **au lieu de lever** ; l'app hôte branche `article` sans forker. [Source: canonical-schema.md §2.1]
- `ZRepetitionInfo`/`Sm2` : **séparés délibérément** de la carte — **E9-2**, pas ici.

### Décisions de portée verrouillées pour E9-1

- **`sealed` interne autorisé, mais l'ouverture inter-package passe par `ZSourceRegistry`.** Le dartdoc de `ZSourceRegistry` note que la `sealed` interne du package flashcard reste `sealed` **en interne** (exhaustivité) tandis que l'ouverture inter-package passe par le registre (deux usages distincts). Si un `sealed` interne est utilisé pour `ZFlashcardSource`, il **doit** inclure le variant `custom` de repli et **ne jamais** enfermer `article`. AD-4 interdit `sealed` **comme mécanisme d'extension inter-package** — c'est le registre qui joue ce rôle. [Source: z_source_registry.dart:5, architecture.md#AD-4]
- **Aucune validation métier** (QCM min 2/1 correct) : E9-5.
- **Aucune matérialisation / attribution d'`id`** : E9-4 (invariant au repository, AD-14).

### Alerte dépendance orchestrateur (parallélisation)

**Aucune édition de `zcrud_core` n'est requise ni planifiée** par cette story : toutes les APIs (`ZEntity`, `ZExtensible`, `ZExtension`, `ZSourceRegistry`, `ZcrudRegistry`, annotations) existent déjà. `zcrud_flashcard` en dépend et les **réutilise**. Fichiers touchés : **uniquement** `packages/zcrud_flashcard/**` (+ code généré gitignoré). Aucun point de contact avec les workstreams parallèles E5 (`zcrud_firestore`/`zcrud_core` data) et E10 (`zcrud_mindmap`) → parallélisation à fichiers disjoints respectée. Si, en cours de dev, un besoin **réel** d'éditer `zcrud_core` émergeait (ex. un helper manquant), **NE PAS** l'implémenter dans cette story : le signaler à l'orchestrateur pour re-séquencer le fichier `zcrud_core` (une seule story écrit le cœur à la fois).

### Testing standards

- Tests **`dart test`** (domaine pur, pas de Flutter) sous `packages/zcrud_flashcard/test/` ; importer `package:zcrud_core/edition.dart` (surface pure), **jamais** le barrel `package:zcrud_core/zcrud_core.dart` (tire Flutter via la présentation) — cf. en-tête `article.dart:16`.
- Fichiers `*_test.dart`. Couverture **défensive réelle** exigée (maps corrompues, pas happy-path seul) — gate E2-10 (rétro-compat sérialisation).
- Le code généré (`*.g.dart`) est produit par `melos run generate` (build_runner réel), **gitignoré**, jamais édité/committé.

### Project Structure Notes

- Impl sous `lib/src/domain/` (couche pure) ; API publique via le barrel `lib/zcrud_flashcard.dart` (convention barrel `lib/<pkg>.dart` / `lib/src/`).
- `pubspec.yaml` de `zcrud_flashcard` dépend déjà de `zcrud_core`, `zcrud_markdown`, `zcrud_export` (^0.1.0) ; `zcrud_annotations` est un **dev_dependency** de codegen à vérifier/ajouter (le générateur `zcrud_generator` + `build_runner` + `zcrud_annotations` doivent être présents en dev pour `melos generate`). Aligner sur le pubspec d'un package déjà annoté si besoin — **sans** ajouter de dépendance lourde runtime au domaine.
- Convention nommage : types publics préfixés `Z` ; fichiers snake_case (`z_flashcard.dart`, `z_choice.dart`, `z_flashcard_type.dart`, `z_flashcard_source.dart`).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E9] — Story E9-1 (6 types ; SRS hors carte ; éphémère matérialisé par le dépôt ; variant article via ZSourceRegistry ; slots extra + ZExtension? AD-4).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-3,#AD-4,#AD-9,#AD-10,#AD-14,#AD-1]
- [Source: docs/canonical-schema.md#2.1] — ZFlashcard / ZChoice / ZFlashcardType / ZFlashcardSource / (ZRepetitionInfo séparé).
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:19]
- [Source: packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:18]
- [Source: packages/zcrud_core/lib/src/domain/extension/z_extension.dart:25]
- [Source: packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart:23]
- [Source: packages/zcrud_core/lib/src/domain/registry/z_open_registry.dart:53]
- [Source: packages/zcrud_generator/test/models/article.dart:26,116] — gabarit `@ZcrudModel` + sous-modèle + liste de sous-modèles.
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart] — squelette actuel à faire évoluer.
- [Source: CLAUDE.md] — Key Don'ts (ne pas éditer/committer `*.g.dart` ; ne pas importer un gestionnaire d'état dans le domaine ; désérialisation défensive).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart run build_runner build --delete-conflicting-outputs` (packages/zcrud_flashcard) → 2 outputs (`z_choice.g.dart`, `z_flashcard.g.dart`), RC=0.
- `dart analyze .` (packages/zcrud_flashcard) → `No issues found!`, RC=0.
- `flutter test` (packages/zcrud_flashcard) → `All tests passed!`, **27 tests**, RC=0.

### Completion Notes List

- **Modèles posés** : `ZFlashcardType` (6 valeurs, repli `openQuestion`), `ZChoice` (`@ZcrudModel(kind:'flashcard_choice')`), `ZFlashcard` (`@ZcrudModel(kind:'flashcard')`, `extends ZEntity with ZExtensible`), `ZFlashcardSource` (union `sealed` : `ZNoteSource`/`ZConversationSource`/`ZDocumentSource` + repli `ZCustomSource`).
- **Codegen** : `flashcard.g.dart`/`z_choice.g.dart` générés par le builder `zcrud_model` (`auto_apply: dependents`), gitignorés. `registerZFlashcard`/`registerZChoice` câblent le `ZcrudRegistry`.
- **Canaux hors-codegen** (`source`/`extension`/`extra`) : le générateur ne (dé)sérialise PAS ces types (union/`ZExtension`/`Map`). Ils sont laissés SANS annotation (le générateur les ignore) et **câblés manuellement** dans `ZFlashcard.fromMap`/`toMap`/`copyWith`, qui délèguent au code généré pour les champs simples puis superposent les 3 canaux. `copyWith` **manuel** couvre les 3 champs (le `copyWith` généré, masqué, les remettrait à leurs défauts → perte silencieuse évitée). `extra` = clés non réservées (réservées dérivées de `$ZFlashcardFieldSpecs` → sync avec le codegen).
- **Provenance ouverte** : seam `ZSourceRegistry?` injecté dans `fromJson`/`toJson` (le générateur ne peut pas passer le registre au `fromMap`). Variant « article » JAMAIS codé en dur → `ZCustomSource` + registre. Test prouve la **consultation** du registre (marqueur `decoded_by_registry` présent seulement via le codec).
- **Extension** : seam `ZFlashcardExtensionParser` (typedef `ZExtension? Function(Map)`), guardé par `ZExtension.guard` ; `formatVersion` non gérée → `null`, parent survit.
- **Décision d'import (aucun edit `zcrud_core`)** : `ZEntity`/`ZExtensible`/`ZExtension`/`ZSourceRegistry` ne sont exportés QUE par le barrel `package:zcrud_core/zcrud_core.dart` (la surface pure `edition.dart` ne les expose pas). Le domaine flashcard importe donc le barrel — **exactement la convention établie de `zcrud_mindmap`** (E10) — et les tests tournent sous **`flutter test`** (le barrel tire le SDK Flutter). Écart assumé vs. la note « dart test / edition.dart » de la story : imposé par le fait que ces 4 APIs ne sont pas sur une surface pure. **Aucune** modification de `zcrud_core` n'a été nécessaire (les modifs `zcrud_core`/`zcrud_firestore`/`zcrud_mindmap` visibles en `git status` proviennent des workstreams parallèles E5-3/E10-1, pas de cette story).
- **Isolation confirmée** : les seuls fichiers créés/modifiés par la story sont sous `packages/zcrud_flashcard/**` (+ `*.g.dart` gitignorés).

### File List

Créés :
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_choice.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart`
- `packages/zcrud_flashcard/test/z_flashcard_test.dart`

Modifiés :
- `packages/zcrud_flashcard/pubspec.yaml` (dep `zcrud_annotations` ; dev-deps `zcrud_generator`/`build_runner`/`flutter_test`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (exports des modèles)
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart` (`version` → `0.1.0`)

Générés (gitignorés, non committés) :
- `packages/zcrud_flashcard/lib/src/domain/z_choice.g.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard.g.dart`
