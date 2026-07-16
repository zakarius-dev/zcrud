# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**zcrud** est un **monorepo Flutter (melos) de packages CRUD riches réutilisables**, extrait et consolidé à partir d'un moteur déclaratif dupliqué à l'identique dans trois applications — **DODLP**, **IFFD**, **DLCFTI**. Un même schéma de champs (`ZFieldSpec`) génère à la fois les **formulaires d'édition** (`DynamicEdition`) et les **tableaux de liste** (`DynamicList`). Le package fournit aussi l'édition/lecture **Markdown** riche (Quill + embeds LaTeX/tables), les **flashcards** (SRS), les **cartes mentales** (mindmaps), et des champs spécialisés (géo, téléphone, pays).

**Objectif produit n°1** : corriger par conception le bug historique de **rafraîchissement global du formulaire** à chaque frappe (jank, perte de focus) → **rebuilds réactifs granulaires**.

**Consommateurs cibles** : **DODLP** (prioritaire, GetX) puis **lex_douane** (Riverpod). Le schéma canonique est porté des modèles les plus avancés de lex_douane (module « Étude »).

**Communication et documentation en français.**

---

## Continuation autonome (consigne utilisateur)

Si à la fin d'une étape je propose au user de continuer (ex. « Continue vers l'architecture ? » / « J'enchaîne `/dev-story` ? ») et que le user **ne répond pas dans la minute**, je **continue automatiquement** avec l'étape proposée — sans nouvelle question. Cela s'applique au cycle BMAD de planification (brief → PRD → architecture → epics → readiness) **et** au cycle BMAD strict d'implémentation (`create-story` → `dev-story` → `code-review` → next story).

## Résumé après chaque étape du cycle BMAD (NON-NÉGOCIABLE)

**Après CHAQUE étape** (planification ou implémentation), fournir au user un **résumé concis** — sans attendre qu'il le redemande :
- ✅ L'étape et le **skill réel** invoqué.
- ✅ Ce qui a été produit (fichiers créés/modifiés, ACs, tâches).
- ✅ Les **résultats de vérification rejoués réellement sur disque** (`melos run generate`, `dart/flutter analyze`, `flutter test` RC + nb de tests) — jamais sur la seule foi du rapport d'un agent.
- ✅ Les **findings** de code-review (HIGH/MAJEUR/MEDIUM/LOW + statut corrigé/justifié).
- ✅ La **transition de statut** appliquée (édition ciblée du sprint-status).

## Délégation des étapes BMAD via Workflow + effort par étape (NON-NÉGOCIABLE)

Chaque étape BMAD est exécutée via le tool **`Workflow`** — pour régler le niveau d'**effort par étape** (impossible via le tool `Agent`). **`create-story` / `dev-story` / `retrospective`** utilisent un **script à agent unique** (un seul `agent()` invoquant le vrai skill `bmad-*`). **`code-review` est l'exception : il est MULTI-AGENT** (cf. section dédiée ci-dessous).

- ✅ **L'orchestrateur (boucle principale) reste le pilote** : entre chaque étape il **vérifie l'état réel sur disque** (`git status`, statut de la story, tests réels), **rejoue lui-même la vérif verte** via bash, édite le sprint-status de façon **ciblée et sérialisée** (jamais deux écritures parallèles), produit le **résumé d'étape**, arme le `ScheduleWakeup`. Le Workflow n'absorbe aucune de ces responsabilités.
- ✅ **Effort par étape** :

  | Étape | Effort |
  |-------|--------|
  | `create-story` | **medium** par défaut, **`high` si la story est jugée complexe** (choix orchestrateur : multi-couches/packages, nouvelle entité/modèle, règles métier non triviales, ACs nombreux, story L/XL) |
  | `dev-story` | **high** |
  | `code-review` | **high** |
  | `retrospective` | **medium** |

- ✅ **Modèle** : hérité de l'orchestrateur → paramètre `model` **OMIS** sur les `agent()` BMAD (planification **et** développement). Les tâches **hors BMAD** (exploration read-only, remédiations massives) → `model:'sonnet'`.
- ✅ **Un seul stage `agent()` par étape** (sauf `code-review`, multi-agent). Jusqu'à **3 étapes en vol simultanément**, mais UNIQUEMENT si elles relèvent de **stories/epics parallélisables à fichiers disjoints** (cf. règle parallélisation ci-dessous) ; jamais deux écritures concurrentes du sprint-status (sérialisées par l'orchestrateur).
- ✅ Si le tool `Skill` n'est pas invocable dans l'agent de Workflow, bascule explicite sur le **fallback disque** (`.claude/skills/bmad-*/SKILL.md` + fichiers annexes), signalée dans le rapport. **Ne jamais simuler une étape de mémoire.**

## Code-review = Workflow MULTI-AGENT à lentilles (NON-NÉGOCIABLE)

**Opt-in permanent du owner** : le `code-review` de chaque story s'exécute comme un **Workflow multi-agent** dont les lentilles couvrent **toutes les facettes** de la story, en parallèle. C'est ce qui rend tenables des **stories volumineuses (découpées par livrable)** : la couverture vient du **nombre de lentilles**, pas de la finesse du découpage.

- ✅ **L'orchestrateur est AUTONOME** sur le dimensionnement : il **choisit seul** le nombre et la nature des agents de revue (une seule lentille sur une story triviale, un large éventail adversarial sur une story lourde), **sans demander l'autorisation**. Il calibre sur la story réelle : surface touchée, packages, criticité des invariants en jeu, densité d'ACs.
- ✅ **Lentilles de référence** (à composer, jamais un catalogue figé) :

  | Lentille | Ce qu'elle traque |
  |---|---|
  | Conformité AD | violations des invariants hérités et du spine de l'epic |
  | Tests porteurs | tests tautologiques (qui ne rougissent pas quand la logique casse) — discipline R3 |
  | A11y / RTL | `Semantics`, ≥ 48 dp, variantes directionnelles, Reduce Motion |
  | L10n / thème | libellé ou couleur codés en dur |
  | SM-1 / perf | rebuilds non granulaires, controllers recréés, listes non virtualisées |
  | Isolation deps | dépendance qui fuit hors de son satellite ; CORE OUT ≠ 0 |
  | Robustesse | chemin d'exception là où un repli est exigé (AD-10) |
  | Adversariale | deux lectures conformes mais **incompatibles** d'une même règle |
  | Réalité du code | affirmation jamais vérifiée sur disque — **toute « absence » doit être prouvée par un grep négatif** |

- ✅ **Chaque agent écrit son rapport complet dans un fichier** et ne retourne qu'un **résumé compact** (verdict + 2-5 findings + chemin) — le contexte de l'orchestrateur ne porte jamais le texte intégral des revues.
- ✅ **L'orchestrateur vérifie lui-même sur disque** tout finding structurant avant de l'appliquer — un rapport d'agent n'est **jamais** une preuve (cf. surveillance des sous-agents).
- ✅ Le triage des findings reste inchangé (HIGH/MAJEUR obligatoires, MEDIUM par défaut, LOW consignés) et la **vérif verte est rejouée par l'orchestrateur** avant tout `done`.

## Surveillance des sous-agents en arrière-plan (NON-NÉGOCIABLE)

Les sous-agents/Workflows lancés en arrière-plan peuvent **planter ou se figer silencieusement** sans notifier.
- ✅ **Health-check périodique** tant qu'un agent est censé tourner : mesurer l'inactivité de son transcript ; **seuil ~5 min (300 s)** sans résultat → considéré planté, ne pas attendre davantage.
- ✅ En cas de plantage : **vérifier l'état réel sur disque** (statut story, `git status/log`, tests réels) **sans faire confiance** au `review`/`done` laissé par l'agent mort, puis relancer un agent de reprise.
- 🚫 Ne **jamais** enchaîner sur la foi du seul rapport d'un agent : confirmer d'abord l'état git/tests réel.
- 🚫 Ne **jamais** faire écrire le même `sprint-status.yaml` par deux agents en parallèle — écritures **sérialisées et ciblées** par l'orchestrateur (jamais de réécriture globale du YAML).

## Réveil de sécurité (heartbeat)

Armer un `ScheduleWakeup` de sécurité (délai **1 h / 3600 s**) pour garantir que le cycle BMAD ne meurt jamais silencieusement. Simple filet : la reprise principale reste pilotée par la complétion réelle des étapes.

## Findings MEDIUM du code-review

- ✅ **HIGH/MAJEUR/critiques** : correction **obligatoire** avant `done`.
- ✅ **MEDIUM** : correction **par défaut** si possible dans le périmètre de la story sans régression ; un MEDIUM reporté doit être **justifié par écrit** dans `code-review-<story>.md`.
- 🟡 **LOW/nits** : optionnels (corrigés si triviaux, sinon consignés).
- ✅ Story reste **verte** après correction des MEDIUM, avant `done`.

## Skills BMAD (noms canoniques)

Invoquer via le tool `Skill` (préfixe `bmad-*`). Fallback disque : `.claude/skills/<nom>/SKILL.md`.

| Étape | Skill | Rôle |
|-------|-------|------|
| Product brief | `bmad-product-brief` | Brief produit |
| PRD | `bmad-prd` (`bmad-create-prd`) | Exigences |
| Architecture | `bmad-architecture` (`bmad-create-architecture`) | Spine d'architecture |
| Epics & Stories | `bmad-create-epics-and-stories` | Backlog |
| Readiness | `bmad-check-implementation-readiness` | Contrôle de complétude |
| Sprint planning | `bmad-sprint-planning` | Génère le sprint-status |
| Sprint status | `bmad-sprint-status` | Suivi |
| create-story | `bmad-create-story` | Story enrichie (specs + ACs + tests) |
| dev-story | `bmad-dev-story` | Implémentation |
| code-review | `bmad-code-review` | Revue adversariale |
| retrospective | `bmad-retrospective` | Rétro d'epic |

En cas de doute sur un nom exact, **lister `.claude/skills/bmad-*` avant d'invoquer.**

---

## Build & Development Commands (monorepo melos)

> **Code généré : SUIVI par git sous `packages/*/lib/`** (depuis ES-1). Le `.gitignore` ignore
> les `*.g.dart` / `*.freezed.dart` **partout SAUF** `packages/*/lib/**` (négation explicite).
> Raison : les packages sont consommés en **dépendance git** — un consommateur clone l'arbre au
> tag et **ne régénère PAS** le code d'une dépendance ; un `part` manquant casserait son build.
> Le gate `codegen-distribution` (`melos run verify`) échoue si un `part` d'un `packages/*/lib/`
> vise un fichier gitignoré.
>
> Conséquences : après avoir modifié une annotation `@ZcrudModel`/`@JsonSerializable` **ou le
> générateur**, régénérer (`melos run generate`) **et committer les `*.g.dart` régénérés** — les
> omettre laisserait dans git un code généré périmé (ex. un registrar câblé sur l'ancienne
> factory). Le codegen reste exécuté par la CI avant analyze/test/build.

```bash
# Bootstrap du workspace (resolution: workspace)
dart pub get            # ou: melos bootstrap

# Régénérer le code de TOUS les packages
dart run melos run generate     # (build_runner sur chaque package annoté)
# Ou par package :
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch     # mode watch

# Analyse
dart run melos run analyze      # ou: dart analyze / flutter analyze

# Tests (tout le workspace)
dart run melos run test         # ou: flutter test  (par package)

# Gate de compatibilité (dry-run vs workspace lex_douane, cf. FR-25/E1-4)
dart pub get --dry-run
```

**Vérif verte (à rejouer réellement avant tout `done`)** : `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0. La CI exécute le codegen avant analyze/test.

---

## Architecture

**Paradigme : monorepo melos + hexagonal (ports & adapters) sur couches `domain` / `data` / `presentation`.** Source de vérité complète : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` (**16 décisions AD-1..AD-16, NON-NÉGOCIABLES**).

### Structure des packages (14)

```
packages/
  zcrud_core/        # domaine pur (Dart) + moteur édition + ports + ZFieldSpec + l10n + ZcrudScope. AUCUNE dep lourde.
  zcrud_annotations/ # @ZcrudModel / @ZcrudField / @ZcrudId
  zcrud_generator/   # builder build_runner (dev_dependency) : (dé)sérialisation + ZFieldSpec + registre
  zcrud_markdown/    # Quill + ZCodec + embeds LaTeX/tables
  zcrud_list/        # DynamicList Syncfusion (ZListRenderer par défaut)
  zcrud_mindmap/     # ZMindmap + ZMindmapTreeOps + ZMindmapView (graphite)
  zcrud_flashcard/   # ZFlashcard + ZRepetitionInfo + ZSrsScheduler + sessions
  zcrud_firestore/   # adapters Firestore + Hive (offline-first)
  zcrud_geo/         # champs géo (adapters Google/OSM optionnels)
  zcrud_intl/        # téléphone/pays/devise (assets)
  zcrud_export/      # PDF/Excel (Syncfusion)
  zcrud_riverpod/    # binding état/injection <-> Riverpod (optionnel)  ← lex_douane/IFFD
  zcrud_get/         # binding état/injection <-> GetX + get_it (optionnel)  ← DODLP
  zcrud_provider/    # binding état/injection <-> provider (optionnel)
```

**Direction de dépendance (AD-1) : acyclique.** `zcrud_core` ne dépend **d'aucun** autre package zcrud ni de Firebase/Syncfusion/Quill/Maps ni d'un gestionnaire d'état. Tout satellite dépend de `zcrud_core` ; jamais l'inverse. Chaque package : API publique = `lib/<pkg>.dart` (barrel), impl sous `lib/src/{domain,data,presentation}`.

---

## Critical Patterns (invariants d'architecture)

### Réactivité Flutter-native — PAS de gestionnaire d'état dans le cœur (AD-2, AD-15)

> ⚠️ **Diffère de lex_douane.** Ici le **cœur `zcrud_core` n'importe AUCUN gestionnaire d'état** (ni Riverpod, ni GetX, ni provider).

- L'état du formulaire vit dans un `ZFormController` **`ChangeNotifier`/`Listenable` pur-Flutter**, exposant une `ValueListenable` par champ.
- **Un champ = un widget qui n'écoute que sa tranche** via `ValueListenableBuilder`/`ListenableBuilder` (rebuild ciblé) — jamais un `ConsumerWidget` dans le cœur.
- Interdits : `setState` à l'échelle du formulaire ; construction des champs dans une closure de `build()` ; recréation de `TextEditingController` au rebuild ; ré-injection de valeur écrasant la sélection.
- Obligatoires : controller stable (create/dispose), `ValueKey(field.name)`, validateurs mémoïsés, `AutovalidateMode.onUserInteraction` par champ, place stable pour les champs conditionnels.
- **Multi-gestionnaire par bindings** : injection/lifecycle branchés via `ZcrudScope` (défaut, `InheritedWidget`, zéro-dépendance) **ou** un binding (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`). Le code spécifique à un manager vit **uniquement** dans son package de binding.

### Serialisation — codegen, `reflectable` banni, `freezed` NON imposé (AD-3)

- Le générateur zcrud (`@ZcrudModel`/`@ZcrudField`) produit `toMap/fromMap/copyWith` + le `ZFieldSpec[]` + l'enregistrement au `ZcrudRegistry`. **Modèle = source unique de vérité.**
- **Jamais `reflectable`** (sauf l'adaptateur `ReflectableCodec` pour DODLP). **`freezed` n'est pas imposé** : zcrud partage structure + invariants, pas la mécanique de (dé)sérialisation.
- Conventions : `@JsonSerializable` pur, `fieldRename: snake` en persistance, **valeurs d'enum en camelCase**, `@JsonKey(unknownEnumValue:)` sur tout enum public.
- **Désérialisation défensive** (AD-10) : un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`). Évolution de schéma **additive seulement**.

### Extensibilité (AD-4)

Chaque entité canonique expose : (1) un slot `ZExtension?` typé additif **versionné** (`formatVersion`, `fromJsonSafe`) ; (2) `extra: Map<String,dynamic>` ; (3) l'extension de type/provenance via `ZTypeRegistry`/`ZSourceRegistry.register(kind, fromJson, toJson)`. **Rejetés** : héritage de classes sérialisées, `sealed` pour l'extension inter-package, generics pour la sérialisation.

### Erreurs & data (AD-5, AD-11, AD-16)

- Tout contrat repository retourne **`Either<ZFailure, T>`** (dartz) ; `Unit` pour void ; les flux sont des **`Stream<List<T>>` nus**.
- Hiérarchie `ZFailure` maison (`DomainFailure`, `CacheFailure`, `NotFoundFailure`, `ServerFailure`…).
- **Domaine backend-agnostique** : `cloud_firestore`/Hive (`Timestamp`/`Filter`/`FirebaseException`) ne fuient **jamais** dans `zcrud_core`. Ports `ZRepository<T>`, `ZLocalStore`, `ZRemoteStore`, `ZAcl`, pagination **curseur** dans `DataRequest` neutre ; adapters dans `zcrud_firestore`.
- **Offline-first** (AD-9) : store local source de vérité, distant fire-and-forget, merge **Last-Write-Wins sur `updatedAt`**, soft-delete `is_deleted` (hors-entité `ZSyncMeta`), cascade ≤ 450 écritures/lot, `ZSyncOrchestrator` (débounce ~400 ms). État SRS séparé de la carte ; voie d'écriture unique `reviewCard() → ZSrsScheduler.apply`.

### Rich-text & liste (AD-7, AD-8)

- Éditeur en **Delta** interne (Quill) ; (dé)sérialisation via `ZCodec` pluggable (Delta/Markdown/HTML) choisi par l'app. Champ rich-text à controller isolé (conforme AD-2).
- Liste : **Syncfusion `SfDataGrid` par défaut** dans `zcrud_list`, derrière `ZListRenderer` ; `zcrud_core` n'expose que l'abstraction (un consommateur sans `zcrud_list` ne tire pas Syncfusion).

---

## Naming & Consistency Conventions (AD, Consistency Conventions)

| Élément | Convention | Exemple |
|---|---|---|
| Types publics | Préfixe **`Z`** | `ZFieldSpec`, `ZFlashcard`, `ZRepository` |
| Packages | `zcrud_<domaine>` | `zcrud_markdown` |
| Fichiers Dart | snake_case | `dynamic_edition.dart` |
| API publique / impl | barrel `lib/<pkg>.dart` / `lib/src/` | — |
| Enum des champs | `EditionFieldType` | — |
| `id` | `String` opaque (nullable pour l'éphémère) | — |
| Dates | ISO-8601 | — |
| Persistance | snake_case ; **enums en camelCase** | `created_at`, `type: "openQuestion"` |
| Métadonnées de sync | hors-entité `ZSyncMeta` | `updated_at`, `is_deleted` |
| Tests | `*_test.dart` | — |
| Code généré | `*.g.dart` / `*.freezed.dart` — **suivis par git sous `packages/*/lib/`** (dép. git), ignorés ailleurs | — |

---

## Key Don'ts (zcrud)

- **Never** importer un gestionnaire d'état (`flutter_riverpod`, `get`, `provider`) dans **`zcrud_core`** — réactivité **Flutter-native** (`ChangeNotifier`/`ValueListenable`) ; le code manager-spécifique vit dans les packages de binding.
- **Never** référencer `WidgetRef`, `Get.find`/`Get.put` ni `Provider.of` dans le cœur — passer par `ZcrudScope.of(context)` ou l'API du binding.
- **Never** de `setState` à l'échelle d'un formulaire — cf. AD-2 (objectif produit n°1).
- **Never** `reflectable` dans le moteur (sauf `ReflectableCodec` DODLP). **Never** imposer `freezed`.
- **Never** faire dépendre `zcrud_core` de Firebase / Syncfusion / Quill / Google Maps (isolés dans `zcrud_firestore`/`zcrud_list`/`zcrud_export`/`zcrud_geo`/`zcrud_markdown`).
- **Never** laisser fuiter un type `cloud_firestore` dans le domaine — passer par les ports neutres.
- **Never** `try-catch` nu dans un repository — envelopper en `Either<ZFailure, T>`.
- **Never** de secret dans un package (clé API Google Maps, endpoints) — config plateforme de l'app ; **never** `badCertificateCallback => true`.
- **Never** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right` — utiliser les variantes **directionnelles** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) pour le RTL (AD-13).
- **Never** `ListView(children: [...])` — `ListView.builder`.
- **Never** éditer un `*.g.dart` à la main (généré par build_runner) — mais **TOUJOURS committer** ceux de `packages/*/lib/` après régénération (suivis par git : distribution en dép. git ; cf. gate `codegen-distribution`).
- **Never** style/couleur codé en dur dans un package — thème injecté via `ZcrudScope`/`ThemeExtension` (FR-26), repli `Theme.of(context)`.
- **Always** `const` pour les widgets immuables ; `Semantics` explicites + cibles ≥ 48 dp (AD-13).

---

## Artefacts BMAD — source of truth

| Document | Path |
|---|---|
| Inventaire technique (reconnaissance des 3 `data_crud`) | `docs/technical-inventory.md` |
| Schéma canonique (porté de lex_douane) | `docs/canonical-schema.md` |
| Product Brief (+ addendum, memlog) | `_bmad-output/planning-artifacts/briefs/brief-zcrud-2026-07-09/brief.md` |
| PRD (26 FR) | `_bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md` |
| **Architecture (16 AD)** | `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` |
| Epics & Stories (11 epics) | `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` |
| Readiness Report | `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-09.md` |
| Sprint Status (créé par `bmad-sprint-planning`) | `_bmad-output/implementation-artifacts/sprint-status.yaml` |
| Stories enrichies (au fil de l'eau) | `_bmad-output/implementation-artifacts/stories/` |
| Code-review findings | `_bmad-output/implementation-artifacts/stories/code-review-<story>.md` |
| Rétrospectives | `_bmad-output/implementation-artifacts/stories/epic-N-retrospective.md` |

Config BMAD : `_bmad/bmm/config.yaml` (`user_name: Zakarius`, `communication_language: French`, `planning_artifacts`, `implementation_artifacts`).

---

## Phase de développement courante

**Planification BMAD complète** : brief → inventaire → canonique → PRD → architecture → epics → **readiness (verdict NEEDS WORK, 0 critique, 26/26 FR couvertes, 16/16 AD, 0 OQ bloquante)**. Décisions verrouillées : réactivité Flutter-native + bindings multi-gestionnaire (AD-15), codegen (freezed non imposé), melos, Syncfusion pour la liste, ZCodec pour le rich-text, schéma canonique porté de lex_douane.

**Prochaine étape : implémentation.** Séquencement MVP : **E1** (fondations melos + CI + **E1-5 révocation clé Google Maps**) → **E2** (cœur + codegen + bindings) → (**E3** édition granulaire ∥ **E4** liste ∥ **E5** firestore ∥ **E6** markdown ∥ **E11a** lot parité DODLP) → **E7** intégration DODLP → **E8** rich-forms lex_douane. Flashcards (**E9**) / mindmaps (**E10**) / reste géo-intl-export (**E11b**) en v1.x.

---

## Processus BMAD strict pour l'implémentation (NON-NÉGOCIABLE)

Pour chaque story listée dans `_bmad-output/implementation-artifacts/sprint-status.yaml`, suivre **strictement** le cycle BMAD complet, sans sauter d'étape, avec les **vrais skills**.

### Cycle par Story (ordre séquentiel strict)

| Étape | Action BMAD | Statut après |
|-------|-------------|--------------|
| 1 | **`bmad-create-story`** — fichier story enrichi (specs tech + ACs + tests) dans `stories/` | `ready-for-dev` |
| 2 | **`bmad-dev-story`** — implémente selon les ACs | `in-progress` |
| 3 | **Vérif verte rejouée** (`melos run generate` + `analyze` + `flutter test` RC=0) | `review` |
| 4 | **`bmad-code-review`** — revue adversariale | _(reste `review`)_ |
| 5 | Corriger findings **critiques/majeurs + MEDIUM** (si possible) ; re-vérif verte | _(reste `review`)_ |
| 6 | Édition ciblée du sprint-status | `done` |

### Transitions de statut obligatoires

```
backlog → ready-for-dev → in-progress → review → done
```

**Aucun saut autorisé.** Une story ne passe **jamais** directement de `in-progress` à `done`.

### Cycle par Epic

1. Traiter **chaque story une par une**, dans l'ordre du sprint-status (respecter le **graphe de dépendances** des epics, pas la seule numérotation — ex. **E11a précède E7**).
2. Après la dernière story de l'epic : **`bmad-retrospective`**.
3. Mettre l'epic + la retro à `done` dans le sprint-status.
4. **Commit unique en fin d'epic** — message `feat(<pkg-ou-epic>): <titre>` ; **inclure** les `*.g.dart` régénérés de `packages/*/lib/` (suivis par git — les omettre laisserait du code généré périmé chez un consommateur en dép. git) ; **exclure** les `pubspec.lock` (racine et `example/`) et les fichiers d'env.

### Règles générales (NON-NÉGOCIABLES)

- 🚫 **Jamais** plusieurs stories en parallèle par défaut — une seule à la fois. **Exception encadrée** : jusqu'à **3 stories complètement indépendantes** (epics parallélisables, **fichiers disjoints**, aucune dépendance croisée, **3 max**). En cas de doute → séquentiel. Garde-fous obligatoires quand on parallélise : (1) **packages de code disjoints** entre les stories en vol ; (2) le **seul point de contact possible = `zcrud_core`** — si plus d'une story doit y écrire, **re-séquencer ce fichier précis** (une seule story touche `zcrud_core` à la fois) ; (3) l'orchestrateur rejoue ses **vérifs vertes par package ciblé** pendant qu'un autre workstream écrit (pas de `melos test` global au milieu d'un dev actif), vérif globale seulement quand tous les workstreams sont au repos ; (4) **health-check** de chaque workstream ; (5) **NON-NÉGOCIABLE — à CHAQUE gate de commit d'epic** (workstreams au repos), rejouer **`melos run analyze` ET `melos run verify` REPO-WIDE** (pas seulement par-package) : la vérif ciblée d'un package NE détecte PAS une régression cross-package (ex. un symbole public supprimé dans un package et référencé par un autre — cf. `ZExportApi` supprimé en E11a-3, cassant `zcrud_flashcard`, `melos analyze` resté RED plusieurs commits sans être vu). Un `graph_proof`/`secrets`/`melos list` verts ne remplacent PAS `melos analyze`. Les écritures du sprint-status restent **sérialisées et ciblées par l'orchestrateur** ; les sous-agents `dev-story`/`code-review` ne touchent PAS au sprint-status.
- 🚫 **Jamais** sauter le `code-review` — même pour une story d'un paragraphe.
- 🚫 **Jamais** committer au milieu d'une story — commit en fin d'epic.
- 🚫 **Jamais** ignorer un finding critique/majeur — corriger ou justifier ; les MEDIUM corrigés dès que possible (sinon justifiés).
- ✅ Le sprint-status reflète l'état **réel** à chaque transition (édition **ciblée**, jamais réécriture globale du YAML).
- ✅ **Les 16 règles AD** (`architecture.md`, section *Invariants & Rules*) s'appliquent à **chaque** story.
- ✅ **Gates CI** (E1-3/E2-10) : lint **anti-`reflectable`** dans le moteur, **scan de secrets**, contrôle codegen, tests de **rétro-compatibilité de sérialisation** (désérialisation défensive) — verts avant tout `done`.
- ✅ **SM-1** (objectif n°1) : sur un formulaire de référence, taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus — test widget + profiling.

---

## BMAD-METHOD Integration

BMAD v6.10 installé (`_bmad/`). `/bmad-help` pour découvrir les commandes ; lister `.claude/skills/bmad-*` en cas de doute sur un nom.

| Phase | Focus | Skills |
|-------|-------|--------|
| 1. Analyse | Comprendre | `bmad-product-brief`, `bmad-brainstorming`, `bmad-technical-research` |
| 2. Planification | Définir | `bmad-prd`, `bmad-ux` |
| 3. Solution | Concevoir | `bmad-architecture`, `bmad-create-epics-and-stories`, `bmad-check-implementation-readiness` |
| 4. Implémentation | Construire | `bmad-sprint-planning`, puis cycle strict `bmad-create-story` → `bmad-dev-story` → `bmad-code-review` → `bmad-retrospective` |
