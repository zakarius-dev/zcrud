---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 9.2 : SRS pluggable — `ZRepetitionInfo` + `ZSrsScheduler` (SuperMemo-2 par défaut) (`zcrud_flashcard`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud (lex_douane « Étude », puis DODLP)**,
I want **l'état SRS canonique `ZRepetitionInfo` généré par `@ZcrudModel` et SÉPARÉ de la carte, avancé par une SEULE voie (`ZSrsScheduler.apply`) derrière une interface REMPLAÇABLE, avec l'algorithme SuperMemo-2 comme implémentation par défaut paramétrée par `ZSrsConfig`**,
so that **je puisse planifier des révisions espacées zéro-perte et rétro-compatibles, préserver l'historique SRS d'autrui au partage/duplication (état hors carte), brancher plus tard FSRS/Leitner sans toucher les modèles, et laisser la synchro merger l'état SRS TEL QUEL (jamais recalculé) — le tout sans que `zcrud_flashcard` ne modifie `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

Deuxième story de l'**epic E9 — Flashcards (`zcrud_flashcard`)**. Elle pose **uniquement le sous-système SRS pur-Dart** : l'entité d'état `ZRepetitionInfo` (séparée de `ZFlashcard`), l'interface `ZSrsScheduler` (remplaçable), son implémentation par défaut SuperMemo-2, et la configuration `ZSrsConfig`. **Aucun** dépôt, **aucune** persistance top-level effective, **aucun** widget de session ici.

E9-1 (livrée, statut `review`) a posé `ZFlashcard`/`ZChoice`/`ZFlashcardType`/`ZFlashcardSource` et a **confirmé par construction et par test que la carte ne porte AUCUN champ SRS** (`interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`learnedAt`/`lastQuality`). Cette story fournit **le contenant séparé** de cet état et **l'algorithme** qui le fait avancer. Le branchement au dépôt offline-first et la persistance en collection **top-level** (`study_repetitions`) sont **E9-4**.

**Invariants d'architecture applicables :**

- **AD-9 (état SRS séparé, voie d'écriture UNIQUE)** [Source: architecture.md#AD-9] : l'état SRS (`ZRepetitionInfo`) est **séparé** de `ZFlashcard` ; **seule voie d'écriture = `reviewCard() → ZSrsScheduler.apply`** — **aucun setter brut** sur les champs SRS. Prévient la perte d'historique au partage/duplication et les avancements incohérents. Dans le périmètre E9-2 (domaine pur, sans dépôt), l'invariant se matérialise ainsi : `ZRepetitionInfo` est un **contenant immuable sans copyWith exposant les champs SRS** ; l'**unique** transformation qui produit un état avancé est `ZSrsScheduler.apply()` (fonction pure retournant une **nouvelle** instance). `reviewCard()` (dépôt, E9-4) **déléguera** à `apply()`.
- **AD-10 (schéma additif + désérialisation défensive)** [Source: architecture.md#AD-10] : ajout seulement entre versions mineures (nullable / `defaultValue`) ; un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`). Chaque `ZExtension` porte son `formatVersion` indépendant. **Conséquence SRS clé** : `ZRepetitionInfo` (dé)sérialise l'**état complet zéro-perte** afin que la synchro (E9-4) puisse **merger la map telle quelle** (LWW sur `updatedAt`) **sans jamais rappeler `apply`** (canonique §7 : « `RepetitionInfo` merge la map **telle quelle**, jamais `Sm2.apply` à la sync »).
- **AD-4 (extension : composition + `ZExtension` + `extra` + registre + enums ouverts)** [Source: architecture.md#AD-4] : chaque entité canonique expose (1) un slot `ZExtension?` versionné, (2) un `Map<String,dynamic> extra` (défaut `const {}`). `ZRepetitionInfo` mixe `ZExtensible` (RÉUTILISÉ du cœur), comme `ZFlashcard`. **Rejetés** : héritage de classes sérialisées, `sealed` pour l'extension inter-package, generics comme mécanisme de sérialisation.
- **AD-14 (pureté des couches ; invariants au repository)** [Source: architecture.md#AD-14] : le `domain/` de `zcrud_flashcard` est **pur-Dart** (aucune dépendance Flutter/Firebase/Hive dans la logique SRS). `ZSrsScheduler`/`ZSm2Scheduler`/`ZSrsConfig`/`ZRepetitionInfo` sont pur-Dart, horloge **injectée** (`now`), **sans état mutable** ni I/O.
- **AD-3 (codegen = source unique de vérité)** [Source: architecture.md#AD-3] : `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` génèrent `toMap`/`fromMap` + `ZFieldSpec[]` + l'enregistrement au `ZcrudRegistry`. **Jamais** `reflectable`. `freezed` **non imposé**.
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `ZSrsScheduler` est prévu **dans `zcrud_flashcard`** (cf. structure des packages : `zcrud_flashcard/ # ZFlashcard + ZRepetitionInfo + ZSrsScheduler + sessions`). **CONTRAINTE DURE : `zcrud_flashcard` NE MODIFIE PAS `zcrud_core`.** Toutes les APIs nécessaires (`ZEntity`, `ZExtensible`, `ZExtension`, annotations, `ZcrudRegistry`) existent déjà et sont **réutilisées**.

**Frontière E9-2 vs le reste de l'epic (NON-NÉGOCIABLE) :**

| Story | Périmètre | Dans E9-2 ? |
|---|---|---|
| E9-1 (livrée) | `ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZFlashcardSource` ; slots `extra` + `ZExtension?` ; SRS hors carte confirmé. | ❌ (livrée) |
| **E9-2 (ici)** | `ZRepetitionInfo` (état SRS séparé, codegen, défensif) ; `ZSrsScheduler` (interface remplaçable) ; `ZSm2Scheduler` (SuperMemo-2 par défaut) ; `ZSrsConfig`. Voie d'avancement unique = `apply()`. | ✅ |
| E9-3 | `ZStudyFolder` / `ZStudySession` (organisation + filtres). | ❌ (E9-3) |
| E9-4 | Dépôt offline-first ; **persistance top-level `study_repetitions`** ; `reviewCard()` réel (délègue à `apply`) ; merge LWW « map telle quelle » ; matérialisation éphémère. | ❌ (E9-4) |
| E9-5 | Édition & widgets additifs (sessions, `previewLabel` localisé). | ❌ (E9-5) |

> ⚠️ En E9-2 : **pas** de dépôt, **pas** de `reviewCard()` branché sur une persistance (l'invariant « voie unique » se prouve au niveau du type : pas de setter SRS, `apply()` seule transformation). **Pas** de libellés localisés (`previewLabel` FR : app-spécifique, E9-5). **Pas** de `Sm2QualityLevel` francophone codé en dur (libellés = app-spécifiques, canonique §5) : la qualité générique est un **`int` 0..5**.

## Acceptance Criteria

1. **`ZRepetitionInfo` — état SRS canonique SÉPARÉ, codegen (AD-9/AD-3).** `@ZcrudModel(kind: 'repetition_info', fieldRename: ZFieldRename.snake)` sur une classe `const` pur-données portant **exactement** : `flashcardId: String` (clé de jointure 1↔1, requis), `folderId: String` (dossier dénormalisé pour requêtes de session, requis), `interval: int` (défaut `0`), `repetitions: int` (défaut `0`), `easeFactor: double` (défaut = `ZSrsConfig.defaultEaseFactor`, càd `2.5`), `nextReviewDate: DateTime?`, `learnedAt: DateTime?`, `lastQuality: int?`. `melos run generate` produit `z_repetition_info.g.dart` (gitignoré) avec `_$…FromMap`/`toMap` + enregistrement `ZcrudRegistry`. Persistance **snake_case** (`flashcard_id`, `folder_id`, `ease_factor`, `next_review_date`, `learned_at`, `last_quality`). **Contenant pur, AUCUNE formule** (l'algorithme vit dans `ZSrsScheduler`). Round-trip zéro-perte testé. Ce modèle est SÉPARÉ de `ZFlashcard` (fichier distinct, jamais un champ de la carte).

2. **Slots d'extension AD-4 (`extra` + `ZExtension?`).** `ZRepetitionInfo` mixe **`ZExtensible` (RÉUTILISÉ de `zcrud_core`)** : expose `extra: Map<String,dynamic>` (défaut `const {}`, jamais `null`, round-trip des clés inconnues préservé) et `extension: ZExtension?` (slot type additif versionné, défaut `null`, parsé défensivement via un `ZRepetitionInfoExtensionParser` injecté + `ZExtension.guard`). Même patron de câblage hors-codegen que `ZFlashcard` (E9-1) : `extra`/`extension` superposés autour du `toMap`/`fromMap` généré, `copyWith` **de reconstruction interne** couvrant ces canaux pour éviter toute perte silencieuse. Testé : `extra` inconnu préservé ; `extension` de `formatVersion` non gérée → `null`, parent survit.

3. **`ZSrsScheduler` — interface abstraite REMPLAÇABLE (AD-9/FR-17).** Une interface `abstract`/`abstract interface class ZSrsScheduler` (jamais `sealed` — extension inter-package, AD-4) expose au minimum :
   - `ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now})` — **unique voie d'avancement** : fonction pure retournant une **nouvelle** `ZRepetitionInfo` (jamais de mutation en place), horloge injectée (`now` défaut = `DateTime.now()` **au sein de l'impl**, jamais capturée à la construction).
   - `ZRepetitionInfo simulate(ZRepetitionInfo current, int quality, {DateTime? now})` — prévisualise le prochain état **sans** le persister (peut simplement déléguer à `apply`, sémantique « projection »).
   - `ZRepetitionInfo initial({required String flashcardId, required String folderId})` — état neuf déterministe (le SEUL autre write autorisé hors `apply`, cf. canonique `initRepetition`). Aucune méthode ne dépend d'un état mutable interne (schedulers **sans état**, réutilisables/thread-safe). Testé : un scheduler ALTERNATIF de test (ex. Leitner/fixe) implémentant l'interface est substitué à `ZSm2Scheduler` et produit un planning **différent** — **prouve la remplaçabilité** (FR-17 : « remplaçable sans toucher les modèles »).

4. **`ZSm2Scheduler` — implémentation SuperMemo-2 par défaut, bornes validées (FR-17).** `ZSm2Scheduler implements ZSrsScheduler`, pure et sans état, paramétrée par un `ZSrsConfig` injecté (défaut `const ZSrsConfig()`). `apply(current, quality, {now})` implémente SM-2 :
   - **Réussite** (`quality >= config.passThreshold`, càd `>= 3`) : `repetitions == 0 → interval = 1` ; `repetitions == 1 → interval = 6` ; sinon `interval = round(interval * easeFactor * config.defaultIntervalModifier)` ; `repetitions += 1`.
   - **Lapse** (`quality < 3`) : `repetitions = 0` ; `interval = 1`.
   - `easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))`, **borné `[config.minEaseFactor (1.3) ; config.maxEaseFactor (2.5)]`** (clamp des DEUX bornes — variante IFFD canonique).
   - `nextReviewDate = now + interval jours` ; `learnedAt` = fixé à la **première** réussite (`quality >= 3` et `learnedAt == null`), **jamais remis à `null`** sur lapse ultérieur ; `lastQuality = quality`.
   Bornes **validées par tests** : suite de `quality=5` → `easeFactor` croît puis **plafonne à 2.5** ; suite de `quality=3` (limite basse de réussite) → `easeFactor` **décroît** et **plancher à 1.3** ; l'`interval` croît de façon monotone tant qu'il y a réussite. `overdueBonusFactor` (config, défaut `0.5`) documenté comme point d'extension du calcul d'échéance en retard (peut rester non appliqué au MVP si non testable simplement — le noter explicitement).

5. **`ZSrsConfig` — constantes injectables paramétrables (FR-17).** `class ZSrsConfig` `const`, immuable, exposant (avec défauts canoniques) : `minEaseFactor = 1.3`, `maxEaseFactor = 2.5`, `defaultEaseFactor = 2.5`, `defaultIntervalModifier = 1.0`, `overdueBonusFactor = 0.5`, `passThreshold = 3`. `ZSm2Scheduler` lit **toutes** ses constantes depuis le `ZSrsConfig` injecté (aucune constante SM-2 codée en dur dans l'algorithme). Testé : un `ZSrsConfig(defaultIntervalModifier: 2.0)` (ou `maxEaseFactor` abaissé) **change** le planning produit par `apply`, prouvant l'injection effective.

6. **Qualité `0..5` défensive (AD-10).** La qualité est un **`int` générique 0..5** (pas d'enum francophone app-spécifique dans le cœur générique). `apply`/`simulate` **clampent défensivement** toute valeur hors bornes (`quality < 0 → 0`, `quality > 5 → 5`) **sans throw**. Testé : `apply(info, -3)` équivaut à `apply(info, 0)` (lapse) ; `apply(info, 99)` équivaut à `apply(info, 5)` (réussite maximale) ; aucun `RangeError`/exception. Le seuil de réussite reste `config.passThreshold` (3).

7. **Voie d'écriture UNIQUE — aucun setter brut (AD-9).** `ZRepetitionInfo` **n'expose AUCUN** moyen public de muter/reconstruire arbitrairement ses champs SRS (`interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`learnedAt`/`lastQuality`) : **pas de setter**, **pas de `copyWith` public** exposant ces champs. L'**unique** transformation qui produit un `ZRepetitionInfo` avancé est `ZSrsScheduler.apply()` ; l'**unique** création d'un état neuf est `ZSrsScheduler.initial()` (+ `fromMap` pour la reconstruction persistée). Documenté et vérifié : la reconstruction interne nécessaire à `apply`/`fromMap` reste **privée/de bas niveau** (ex. constructeur nommé utilisé uniquement par l'algo et la désérialisation), jamais une API d'avancement publique concurrente. Testé : deux `apply` successifs simulant un flux `reviewCard` produisent une courbe SM-2 cohérente ; il n'existe pas d'autre chemin public pour avancer l'état.

8. **Synchro = merge « map telle quelle », jamais recalculée (AD-9/AD-10, canonique §7).** `ZRepetitionInfo.fromMap`/`toMap` (dé)sérialisent l'**état complet zéro-perte** (`fromMap(toMap(x)) == x`) **sans jamais invoquer `ZSrsScheduler.apply`** : la désérialisation reconstruit l'état persisté **tel quel** (aucun recalcul d'`interval`/`easeFactor`/échéance). Ceci permet à la synchro E9-4 de merger la map par LWW sur `updatedAt` sans dériver l'état. Testé : round-trip identité sur un état non trivial (`repetitions=7`, `easeFactor=1.87`, `nextReviewDate` fixée) ; un test-espion/contrat garantit que `fromMap` ne passe **pas** par un scheduler (l'état désérialisé est byte-identique à l'état source, y compris des valeurs « impossibles » qu'un `apply` aurait normalisées).

9. **Désérialisation défensive de bout en bout (AD-10).** `ZRepetitionInfo.fromMap` sur des maps **réellement corrompues** : map `{}` (champs requis absents → défauts sûrs : `flashcardId=''`, `folderId=''`, `interval=0`, `repetitions=0`, `easeFactor=defaultEaseFactor`), `ease_factor` non-numérique → défaut, `interval` négatif/non-int → défaut sûr, `next_review_date`/`learned_at` illisibles → `null`, `last_quality` hors 0..5 → conservé tel quel ou `null` défensif (documenter le choix), `extension` corrompue → `null`, clés inconnues → `extra`. **Aucun** cas ne fait échouer le parent. Testé sur maps corrompues (pas seulement happy-path) — gate E2-10 (rétro-compat sérialisation).

10. **Isolation & pureté (AD-1/AD-14/AD-3).** La logique SRS (`ZRepetitionInfo` domaine, `ZSrsScheduler`, `ZSm2Scheduler`, `ZSrsConfig`) est **pur-Dart** (aucun import Flutter/Firebase/Hive dans les fichiers d'algorithme ; l'entité `ZRepetitionInfo` réutilise le cœur via le barrel `package:zcrud_core/zcrud_core.dart` comme `ZFlashcard`, testée sous `flutter test`). **Aucune modification de `zcrud_core`** (vérifié : `git status` ne montre aucun `packages/zcrud_core/**` modifié par la story). Le barrel `lib/zcrud_flashcard.dart` exporte `ZRepetitionInfo`, `ZSrsScheduler`, `ZSm2Scheduler`, `ZSrsConfig`. `ZFlashcardApi.version` monté en cohérence (ex. `0.2.0`) en conservant les arêtes AD-1.

11. **Vérif verte (gates E1-3/E2-10).** `melos run generate` OK → `melos run analyze` RC=0 (dont lint anti-`reflectable`, scan secrets) → `flutter test` (package `zcrud_flashcard`) RC=0. Les tests SRS (courbe SM-2 multi-révisions, bornes easeFactor, clamp qualité, remplaçabilité de l'interface, round-trip défensif) passent.

## Tasks / Subtasks

- [x] **Tâche 1 — `ZSrsConfig` (AC5)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` : `class ZSrsConfig` `const`, champs `minEaseFactor`/`maxEaseFactor`/`defaultEaseFactor`/`defaultIntervalModifier`/`overdueBonusFactor`/`passThreshold` avec défauts canoniques (`1.3`/`2.5`/`2.5`/`1.0`/`0.5`/`3`). `==`/`hashCode`. **Pas** de codegen (config pur-Dart, pas une entité persistée).
  - [x] Dartdoc : chaque constante + son rôle SM-2 ; injectable pour FSRS/Leitner. + `static const kDefaultEaseFactor = 2.5` (const utilisable dans l'annotation codegen du modèle).

- [x] **Tâche 2 — Entité `ZRepetitionInfo` (AC1, AC2, AC7, AC8, AC9)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` : `@ZcrudModel(kind: 'repetition_info')` (fieldRename snake = défaut), `class ZRepetitionInfo with ZExtensible` (pas d'`id`/`ZEntity` : la clé est `flashcardId` 1↔1 ; documenté). Classe `const` pur-données, champs exactement selon AC1 + slots `extra`/`extension` (AC2).
  - [x] Câbler les 2 canaux hors-codegen (`extra`, `extension`) manuellement autour du `toMap`/`fromMap` généré — patron `ZFlashcard` (E9-1) : `_reservedKeys` dérivées de `$ZRepetitionInfoFieldSpecs`, `extra` = clés non réservées, `extension` via parser injecté + `ZExtension.guard`.
  - [x] **AC7 — pas de setter brut** : aucun `copyWith` public ; l'extension générée `ZRepetitionInfoZcrud` (qui porte un `copyWith`) est **masquée du barrel via `hide`**. La reconstruction (`apply`/`fromMap`) passe par le constructeur `const` public réservé (primitif de bas niveau sans formule SRS). Documenté : `apply()` seule voie d'avancement publique.
  - [x] **AC8 — round-trip sans recalcul** : `factory ZRepetitionInfo.fromMap(map, {extensionParser})` délègue au généré défensif, **sans** scheduler. `toMap()` réutilise le généré + superpose `extra`/`extension`.
  - [x] `part 'z_repetition_info.g.dart';` (généré, gitignoré).

- [x] **Tâche 3 — Interface `ZSrsScheduler` (AC3)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_srs_scheduler.dart` : `abstract interface class ZSrsScheduler` avec `apply`, `simulate`, `initial` (signatures AC3). Dartdoc : voie d'avancement unique (AD-9), horloge injectée, sans état, remplaçable.
  - [x] **PAS** `sealed` (AD-4 : ouverture inter-package).

- [x] **Tâche 4 — Implémentation `ZSm2Scheduler` (AC4, AC6)**
  - [x] Créer `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart` : `class ZSm2Scheduler implements ZSrsScheduler`, `final ZSrsConfig config` (défaut `const ZSrsConfig()`), pure/sans état.
  - [x] Algorithme SM-2 selon AC4 (réussite/lapse, formule easeFactor, clamp `[min;max]`, `learnedAt` 1re réussite jamais reset, `nextReviewDate = now + interval j`, `lastQuality`). Toutes les constantes lues depuis `config`.
  - [x] **AC6 — clamp qualité** `0..5` défensif en tête d'`apply` (`quality.clamp(0, 5)`), aucun throw.
  - [x] `initial({flashcardId, folderId})` → état neuf (`interval=0`, `repetitions=0`, `easeFactor=config.defaultEaseFactor`, dates `null`).
  - [x] `overdueBonusFactor` documenté (point d'extension d'échéance en retard) — laissé **inerte** au MVP (noté dans le dartdoc de `ZSrsConfig`).

- [x] **Tâche 5 — Barrel + API marqueur (AC10)**
  - [x] Étendre `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : exporter `z_repetition_info.dart` (`hide ZRepetitionInfoZcrud`), `z_sm2_scheduler.dart`, `z_srs_config.dart`, `z_srs_scheduler.dart`.
  - [x] `ZFlashcardApi.version` → `'0.2.0'` ; arêtes AD-1 conservées.

- [x] **Tâche 6 — Tests (AC1..AC10, AC11)**
  - [x] `packages/zcrud_flashcard/test/z_repetition_info_test.dart` + `packages/zcrud_flashcard/test/z_srs_scheduler_test.dart` (`flutter test`, horloge `DateTime.utc(2026,1,1)` injectée).
  - [x] **Courbe SM-2 multi-révisions** `q=5` : `interval` = 1, 6, 15, 38 ; `easeFactor` croît puis **plafonne à 2.5** ; `nextReviewDate = now + interval`.
  - [x] **Lapse & bornes** : `q=3` répété → `easeFactor` **décroît** au plancher `1.3` ; `q<3` → `repetitions=0`, `interval=1`, `learnedAt` **préservé**.
  - [x] **Qualité 0..5** : `apply(info,-3)` == `apply(info,0)` ; `apply(info,99)` == `apply(info,5)` ; aucun throw.
  - [x] **Config injectée** : `defaultIntervalModifier: 2.0`, `maxEaseFactor: 2.0`, `passThreshold: 4` changent le planning.
  - [x] **Interface remplaçable (AC3)** : `_FixedStepScheduler implements ZSrsScheduler` substitué → planning différent (prouve FR-17).
  - [x] **Sérialisation (AC8/AC9)** : round-trip identité (état non trivial + extension) ; désérialisation défensive (map vide, `ease_factor` non-numérique, `interval` négatif/non-int, dates illisibles, `extension` corrompue, `extra` préservé) ; preuve non-recalcul (`easeFactor=9.9`/`interval=999` conservés).
  - [x] **Voie unique (AC7)** : `apply` seul chemin d'avancement (immuabilité, nouvelle instance à chaque appel ; `copyWith` généré masqué).

- [x] **Tâche 7 — Vérif verte (AC11)**
  - [x] `build_runner build` OK → `dart analyze .` RC=0 → `flutter test` RC=0 (59 tests dont 32 E9-2). `git status` : **aucun** fichier `packages/zcrud_core/**` modifié par la story (les changements core/firestore/mindmap sont des workstreams parallèles E5/E10).

## Dev Notes

### APIs `zcrud_core` à RÉUTILISER (ne rien recréer — AD-1, contrainte dure)

Tout le nécessaire existe déjà. **Ne pas** réimplémenter, **ne pas** modifier `zcrud_core` :

- **`ZExtensible`** (`packages/zcrud_core/lib/src/domain/extension/z_extensible.dart`) — mixin `ZExtension? get extension` + `Map<String,dynamic> get extra`. `ZRepetitionInfo … with ZExtensible`. Helper `zExtraRead<T>(extra, key)`. [Source: z_extensible.dart:18]
- **`ZExtension`** (`packages/zcrud_core/lib/src/domain/extension/z_extension.dart`) — base `abstract const`, `int get formatVersion`, `Map<String,dynamic> toJson()`, statique `ZExtension.guard<T>(parse)` (repli `null`). Convention `static X? fromJsonSafe(json)`. **Jamais `sealed`**. [Source: z_extension.dart:25]
- **Annotations** `@ZcrudModel(kind:, fieldRename: ZFieldRename.snake)` / `@ZcrudField(defaultValue:, name:, …)` / `@ZcrudId()` (`packages/zcrud_annotations`) — patron E2-5 ; zéro closure dans les annotations. [Source: zcrud_model.dart:17, zcrud_field.dart:36]
- **`ZcrudRegistry`** — alimenté par le codegen (`registerZRepetitionInfo`). [Source: zcrud_registry.dart]
- **`ZSrsScheduler` n'existe PAS dans le cœur** : il est **prévu dans `zcrud_flashcard`** (structure des packages, architecture.md:188). On le **crée ici**, pas dans `zcrud_core`.

### Patron d'implémentation de référence (à imiter)

- **`ZFlashcard` (E9-1, livrée)** `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` est le **gabarit exact** du câblage hors-codegen des canaux `extra`/`extension` autour du `toMap`/`fromMap` généré : `_reservedKeys` dérivées de `$ZFlashcardFieldSpecs`, `_extraFrom(map)` (non-modifiable), `_decodeExtension(raw, parser)` via `ZExtension.guard`, `copyWith` manuel couvrant les canaux hors-codegen. `ZRepetitionInfo` **clone ce patron** — **mais SANS `copyWith` public** (AC7 : pas de setter SRS ; la reconstruction reste privée). [Source: z_flashcard.dart:93,200,281,293]
- **`ZMindmapTreeOps` (E10-1, livrée)** `packages/zcrud_mindmap/lib/src/domain/z_mindmap_tree_ops.dart` est le **précédent d'une classe d'algorithme pure** du monorepo : fonctions pures, immuables, sans état, retournant de **nouvelles** structures. `ZSm2Scheduler` suit le même esprit (pur, sans état, horloge injectée). [Source: z_mindmap_tree_ops.dart:24]

### Schéma canonique (source de vérité des champs & de l'algorithme)

`docs/canonical-schema.md` §2.1 :
- **`ZRepetitionInfo`** [canonical §2.1, l.62-73] : `flashcardId`, `folderId`, `interval`, `repetitions`, `easeFactor` (borné `[1.3;2.5]`), `nextReviewDate?`, `learnedAt?` (1re réussite, jamais reset sur lapse), `lastQuality?` (0-5). « Contenant pur, aucune formule (l'algo vit dans `Sm2`). »
- **`ZSrs`/`Sm2`** [canonical §2.1, l.75] : pur, sans état mutable, **horloge injectée (`now`)**. Constantes via `ZSrsConfig` : `minEaseFactor`/`maxEaseFactor` (1.3/2.5), `defaultEaseFactor` (2.5), `defaultIntervalModifier` (1.0), `overdueBonusFactor` (0.5), `passThreshold` (3). Expose `apply()`, `simulate()`, `previewLabel()`. **Voie d'écriture UNIQUE** : `reviewCard() → Sm2.apply`. Enum `Sm2QualityLevel` (`complique(1)…tresFacile(5)`) = **libellés app-spécifiques** (l.218) → **hors zcrud générique** : qualité = `int` 0..5. Interface cible `ZSrsScheduler.apply/simulate` pour brancher FSRS/Leitner.
- **Sync** [canonical §7, l.306] : « `Mindmap`/`RepetitionInfo` **merge la map telle quelle** (jamais `Sm2.apply` à la sync) » ; SRS persisté **top-level** `study_repetitions/{cardId}`, **jamais dans le sous-arbre partageable** (l.305) — **effectif en E9-4**, mais `ZRepetitionInfo` doit (dé)sérialiser zéro-perte pour le permettre (AC8).
- **Repo `reviewCard`** [canonical §6, l.299] : `initRepetition{flashcardId,folderId}` (seul write hors `apply`, état neuf) ; `reviewCard(current, quality, {now})` applique `apply` en interne (voie unique). → `initial()` + `apply()` sont les briques ; le `reviewCard` réel est **E9-4**.

### Décisions de portée verrouillées pour E9-2

- **Qualité = `int` 0..5 générique** (pas d'enum francophone `Sm2QualityLevel` : app-spécifique, canonique §5/§8). Clamp défensif, seuil de réussite = `config.passThreshold` (3).
- **`easeFactor` clampé aux DEUX bornes `[minEaseFactor; maxEaseFactor]`** (variante IFFD canonique), pas seulement au plancher 1.3 du SM-2 d'origine.
- **`ZRepetitionInfo` SANS `id`/`ZEntity`** : sa clé d'identité est `flashcardId` (jointure 1↔1) ; il n'est pas éphémère au sens carte. Documenter (diffère de `ZFlashcard`).
- **Pas de `copyWith` public SRS** (AC7) : reconstruction privée réservée à `apply`/`fromMap`. C'est l'application au niveau du type de « aucun setter brut » (AD-9).
- **`previewLabel`** (libellés de prévisualisation localisés) = **E9-5** (app-spécifique, l10n). `simulate()` retourne l'**état** projeté, pas un libellé.
- **`reviewCard()` réel + persistance top-level** = **E9-4** (repository). Ici, seule la **mécanique pure** (`initial`/`apply`/`simulate`).

### Alerte dépendance orchestrateur (parallélisation)

**Aucune édition de `zcrud_core` n'est requise ni planifiée** : toutes les APIs (`ZExtensible`, `ZExtension`, annotations, `ZcrudRegistry`) existent déjà et sont **réutilisées** ; `ZSrsScheduler` se crée **dans `zcrud_flashcard`** (structure prévue AD-1). Fichiers touchés : **uniquement** `packages/zcrud_flashcard/**` (+ code généré gitignoré). Aucun point de contact avec les workstreams parallèles E5 (`zcrud_firestore`/`zcrud_core` data) et E10 (`zcrud_mindmap`) → parallélisation à fichiers disjoints respectée. Si un besoin **réel** d'éditer `zcrud_core` émergeait (helper manquant), **NE PAS** l'implémenter ici : le signaler à l'orchestrateur pour re-séquencer le fichier `zcrud_core` (une seule story écrit le cœur à la fois).

### Testing standards

- Tests sous `packages/zcrud_flashcard/test/`, `*_test.dart`, exécutés via **`flutter test`** (le domaine flashcard importe `package:zcrud_core/zcrud_core.dart` qui tire le SDK Flutter — convention établie E9-1/E10-1).
- **Horloge injectée fixée** (`now: DateTime.utc(2026, 1, 1)`) pour un déterminisme total des `nextReviewDate`.
- Couverture **défensive réelle** exigée (maps corrompues, qualité hors bornes, easeFactor non-numérique) — gate E2-10 (rétro-compat sérialisation).
- Le code généré (`*.g.dart`) est produit par `melos run generate` (build_runner réel), **gitignoré**, jamais édité/committé.

### Project Structure Notes

- Impl sous `lib/src/domain/` (couche pure) ; API publique via le barrel `lib/zcrud_flashcard.dart`.
- Nouveaux fichiers : `z_repetition_info.dart` (+ `z_repetition_info.g.dart` généré), `z_srs_scheduler.dart`, `z_sm2_scheduler.dart`, `z_srs_config.dart`. Convention : types publics préfixés `Z` ; fichiers snake_case.
- `pubspec.yaml` de `zcrud_flashcard` a déjà toute la toolchain codegen en dev (`zcrud_generator`/`build_runner`/`flutter_test`) et la dep `zcrud_annotations` (E9-1) — **rien à ajouter** ; ne PAS ajouter de dépendance runtime lourde.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E9] — Story E9-2 (`ZRepetitionInfo` séparé ; seule voie `reviewCard()→apply` ; `ZSrsConfig` ; interface remplaçable, FR-17).
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#FR-17] — SuperMemo-2 par défaut derrière `ZSrsScheduler.apply/simulate` + `ZSrsConfig` ; voie unique `reviewCard()→apply` ; remplaçable sans toucher les modèles.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-9,#AD-10,#AD-4,#AD-14,#AD-3,#AD-1] — SRS séparé, voie unique ; défensif ; extension ; pureté ; codegen ; isolation. `zcrud_flashcard/ # … + ZSrsScheduler` (l.188). Interface FSRS/Leitner prévue (l.253).
- [Source: docs/canonical-schema.md#2.1] — `ZRepetitionInfo` (champs l.62-73) ; `ZSrs`/`Sm2` + `ZSrsConfig` (l.75).
- [Source: docs/canonical-schema.md#6,#7] — `reviewCard`/`initRepetition` voie unique (l.299) ; merge « map telle quelle », persistance top-level `study_repetitions` (l.305-306).
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:93,200,281,293] — patron câblage `extra`/`extension` hors-codegen (E9-1).
- [Source: packages/zcrud_mindmap/lib/src/domain/z_mindmap_tree_ops.dart:24] — précédent classe d'algorithme pure/sans état.
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart] — API marqueur à monter en `0.2.0`.
- [Source: CLAUDE.md] — Key Don'ts (pas d'édition/commit `*.g.dart` ; pas de gestionnaire d'état dans le domaine ; désérialisation défensive ; enums camelCase / `JsonSerializable`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, sous-agent dev orchestré).

### Debug Log References

- Codegen : `dart run build_runner build --delete-conflicting-outputs` (zcrud_flashcard) — 2 outputs générés (`z_repetition_info.g.dart`), gitignorés.
- Correctif codegen : `defaultEaseFactor` étant un membre d'**instance** de `ZSrsConfig`, il ne pouvait servir de `defaultValue` `const` dans l'annotation `@ZcrudField` ni de défaut de constructeur. Ajout d'un `static const double kDefaultEaseFactor = 2.5` sur `ZSrsConfig`, référencé par le modèle → le généré émet `ease_factor` repli `2.5` (au lieu de `0.0`), conforme AC1/AC9.
- `dart analyze .` (lib + test) : RC=0, « No issues found! ».
- `flutter test` : RC=0, **59 tests passés** (32 nouveaux E9-2 : 20 scheduler + 12 repetition_info ; 27 hérités E9-1).

### Completion Notes List

- **AC1** ✅ `ZRepetitionInfo` codegen `@ZcrudModel(kind:'repetition_info')`, champs exacts, snake_case, contenant pur (aucune formule), séparé de `ZFlashcard`, sans `id`/`ZEntity` (clé = `flashcardId`). Round-trip zéro-perte testé.
- **AC2** ✅ Mixe `ZExtensible` (cœur réutilisé) : `extra` (const {}, non-modifiable, round-trip clés inconnues) + `extension` (parser injecté + `ZExtension.guard`). Câblage hors-codegen calqué sur `ZFlashcard`.
- **AC3** ✅ `abstract interface class ZSrsScheduler` (`apply`/`simulate`/`initial`), jamais `sealed`, horloge injectée, sans état. Remplaçabilité prouvée par `_FixedStepScheduler` de test (planning différent, modèle inchangé).
- **AC4** ✅ `ZSm2Scheduler` SM-2 : réussite 1/6/round(i·ef·mod), lapse (rep=0, interval=1), formule easeFactor clampée `[1.3;2.5]`, `learnedAt` 1re réussite jamais reset, `nextReviewDate=now+interval`. Bornes validées (plafond 2.5 sur q=5, plancher 1.3 sur q=3). `overdueBonusFactor` documenté inerte.
- **AC5** ✅ `ZSrsConfig` const injectable, toutes constantes SM-2 lues depuis config (aucune en dur dans l'algo). Injection prouvée (`defaultIntervalModifier`/`maxEaseFactor`/`passThreshold` custom changent le planning).
- **AC6** ✅ Qualité `int 0..5`, clamp défensif (`quality.clamp(0,5)`), aucun throw ; `apply(-3)==apply(0)`, `apply(99)==apply(5)`.
- **AC7** ✅ Voie unique : aucun `copyWith`/setter SRS public ; l'extension générée `ZRepetitionInfoZcrud` (avec `copyWith`) est **masquée du barrel via `hide`**. Reconstruction = constructeur `const` réservé (sans formule) + `fromMap`. `apply` seul chemin d'avancement (nouvelle instance immuable à chaque appel).
- **AC8** ✅ `fromMap`/`toMap` zéro-perte SANS scheduler : valeurs « impossibles » (`easeFactor=9.9`, `interval=999`) conservées telles quelles (preuve de non-recalcul) → sync « map telle quelle » E9-4 permise.
- **AC9** ✅ Désérialisation défensive : map vide → défauts sûrs, `ease_factor` non-numérique → 2.5, `interval`/`repetitions` négatifs → 0 (sanitisés), dates illisibles → null, `last_quality` hors 0..5 → **conservé tel quel** (choix documenté : pas de perte à la sync ; clamp uniquement à `apply`), `extension` corrompue → null. Aucun throw parent.
- **AC10** ✅ Pur-Dart (aucun import Flutter/Firebase/Hive dans l'algo). **Aucune modification de `zcrud_core`** (vérifié `git status`). Barrel exporte les 4 nouveaux types. `ZFlashcardApi.version = '0.2.0'`, arêtes AD-1 conservées.
- **AC11** ✅ Vérif verte : build_runner OK → `dart analyze .` RC=0 → `flutter test` RC=0 (59 tests).

**Alerte orchestrateur** : aucun besoin d'éditer `zcrud_core` n'a émergé — toutes les APIs (`ZExtensible`/`ZExtension`/annotations/`ZcrudRegistry`) existantes ont suffi.

### File List

**Créés (zcrud_flashcard) :**
- `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_srs_scheduler.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart`
- `packages/zcrud_flashcard/test/z_repetition_info_test.dart`
- `packages/zcrud_flashcard/test/z_srs_scheduler_test.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.g.dart` (généré, gitignoré, non committé)

**Modifiés (zcrud_flashcard) :**
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (barrel : exports E9-2 + `hide ZRepetitionInfoZcrud`)
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart` (version → 0.2.0)
