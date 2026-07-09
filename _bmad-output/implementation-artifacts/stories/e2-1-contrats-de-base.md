---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.1 : Contrats de base (ZEntity / ZNode / ZSyncable / ZSyncMeta / ZFailure)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du cœur `zcrud_core`**,
je veux **poser les contrats de domaine fondateurs — `ZEntity` (identité opaque + éphémère), `ZNode` (nœud d'arbre), `ZSyncable` (clé LWW), `ZSyncMeta` (métadonnées de sync hors-entité) et la hiérarchie d'erreurs maison `ZFailure` — en Dart pur, et câbler `dartz` (`Either`/`Unit`) au barrel**,
afin que **toutes les stories aval (E2-2 ports données, E2-3 registre, E5 firestore, E9 flashcard, E10 mindmap…) construisent leurs contrats et adaptateurs sur des abstractions stables, backend-agnostiques, testées à l'égalité de valeur, sans jamais réintroduire un couplage Flutter/Firebase ni un gestionnaire d'état dans le domaine.**

## Contexte & valeur

E1 est **done** : le workspace melos (14 packages, `resolution: workspace`), les gates CI (lint anti-`reflectable`, scan de secrets, contrôle codegen), et la preuve d'acyclicité AD-1 sont en place. À ce stade `zcrud_core` est un **squelette pur-Dart** : barrel `lib/zcrud_core.dart` → `lib/src/domain/z_core_api.dart` (`ZCoreApi`, placeholder E1-2). **Aucune dépendance déclarée** dans `packages/zcrud_core/pubspec.yaml` (pas encore de `dartz`).

E2-1 est la **fondation intra-épic** : l'ordre verrouillé est **E2-1 → E2-2 → E2-7 → E2-9** avant E2-4/E2-5 (codegen). E2-2 (ports `ZRepository<T>`/`DataRequest`/`ZAcl`) **dépend directement** des types posés ici : `ZEntity` (borne générique `T extends ZEntity`), `ZFailure` (`Either<ZFailure,T>` sur chaque méthode), `ZSyncMeta` (soft-delete hors-entité). E9 (`ZFlashcard`), E10 (`ZMindmap`/`ZMindmapNode`) et E5 (firestore) implémenteront ces contrats.

**Ce que cette story matérialise (issu du schéma canonique porté de lex_douane) :**
- L'**identité `String` opaque** (nullable pour l'éphémère, invariant de matérialisation par le repo — porté de `Flashcard.isEphemeral`).
- La **séparation données/sync** : métadonnées de sync **hors-entité** standardisées en `ZSyncMeta` (`updated_at`/`is_deleted`), porté de la divergence `Mindmap` (hors-entité) vs `StudyFolder` (in-entité) — OQ-3 tranchée par AD-16 en faveur du standard hors-entité.
- La **hiérarchie `ZFailure` maison** (`DomainFailure`/`CacheFailure`/`NotFoundFailure`/`ServerFailure`) avec `==`/`hashCode` à la main (porté de `Failure` lex + `Object.hash`), consommée via `Either<ZFailure,T>` (dartz) / `Unit` pour void, **flux `Stream<List<T>>` nus** (AD-11).

**Ce qui rendra la story vérifiable :** le domaine reste **Dart pur** (grep prouve zéro import Flutter/Firebase/Hive/gestionnaire d'état) ; l'égalité de valeur de `ZFailure` et `ZSyncMeta` est testée (réflexive, symétrique, `hashCode` cohérent, discrimination par type/champ) ; `Either<ZFailure,T>` et `Unit` sont utilisables et re-exportés par le barrel ; `dartz ^0.10.1` est déclaré ; `analyze` RC=0 et `flutter test` RC=0.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ `ZEntity` : contrat abstrait d'entité canonique (identité `String?` opaque, `isEphemeral`).
- ✅ `ZNode` : contrat abstrait **fin** de nœud d'arbre (identité `String` non-null) — **sans** committer la topologie (nesting vs flat = OQ-4, différée à E9/E10).
- ✅ `ZSyncable` : contrat exposant la **clé LWW** (`updatedAt`), agnostique quant à l'emplacement (in-entité ou via `ZSyncMeta`).
- ✅ `ZSyncMeta` : value object de sync **hors-entité** (`updatedAt`, `isDeleted`) + `==`/`hashCode` + fabriques `fromJson`/`toJson` défensives (clés snake_case `updated_at`/`is_deleted`).
- ✅ Hiérarchie `ZFailure` : base abstraite **extensible inter-package** (NON `sealed`) + 4 sous-classes canoniques, `==`/`hashCode`.
- ✅ Câblage `dartz` : ajout `dartz ^0.10.1` aux `dependencies` de `zcrud_core` ; re-export **curaté** (`Either`/`Left`/`Right`/`Unit`/`unit`) par le barrel ; typedef ergonomique `ZResult<T> = Either<ZFailure, T>`.
- ✅ Exports du barrel + doc d'origine `fichier:ligne` lex en commentaire (traçabilité re-portage, canonique §6.6).
- ❌ **Pas** de `ZRepository<T>`/`DataRequest`/`ZQuery`/`ZAcl`/`ZDataState` (→ **E2-2**).
- ❌ **Pas** de `ZExtension`/`extra`/registre (`ZTypeRegistry`/`ZSourceRegistry`) (→ **E2-3/E2-4**).
- ❌ **Pas** de modèles canoniques concrets (`ZFlashcard`, `ZMindmapNode`, `ZStudyFolder`…) ni de `ZFieldSpec` (→ E9/E10/E2-suite).
- ❌ **Pas** de `ZFormController`/réactivité/seams (→ **E2-7**).
- ❌ **Pas** d'adaptateurs de persistance (Hive/Firestore) ni de `@JsonSerializable`/codegen sur ces contrats (le domaine reste techno-neutre ; les fabriques JSON de `ZSyncMeta` sont **écrites à la main**, sans build_runner).
- ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur).
- ❌ **Ne PAS** supprimer/renommer `ZCoreApi` (placeholder référencé par les satellites) — le barrel continue de l'exporter.

## Acceptance Criteria

1. **Pureté Dart du domaine (AD-14, AD-1).** Aucun fichier sous `packages/zcrud_core/lib/src/domain/` introduit par cette story n'importe `package:flutter/*`, `dart:ui`, `package:cloud_firestore/*`, toute `package:firebase*`, `package:hive*`, ni un gestionnaire d'état (`package:flutter_riverpod/*`, `riverpod*`, `package:get/*`, `package:provider/*`). Les seuls imports externes autorisés sont `dart:core` (implicite) et `package:dartz/dartz.dart`. Vérifiable par grep (voir Stratégie de tests). `packages/zcrud_core/pubspec.yaml` ne déclare **aucune** dépendance `zcrud_*` (AD-1, out-degree 0 préservé).

2. **`ZEntity` — identité opaque + éphémère.** Un contrat abstrait `ZEntity` expose `String? get id` (identité **opaque**, aucune sémantique de position/tri) et un getter dérivé `bool get isEphemeral => id == null`. `id` est **nullable** pour représenter l'entité éphémère non encore matérialisée (porté de `Flashcard.isEphemeral`, canonique §2.1) ; l'invariant de matérialisation (attribution d'un `id` avant écriture) est **porté par le repository**, jamais par l'entité (AD-14). `ZEntity` est un **contrat pur** (aucune (dé)sérialisation dans la base — AD-4 : base abstraite fine sans sérialisation autorisée, héritage de classes sérialisées rejeté).

3. **`ZNode` — contrat de nœud d'arbre.** Un contrat abstrait `ZNode` expose `String get id` (non-null : un nœud matérialisé possède toujours une clé de réconciliation). Le contrat **ne fige pas** la topologie (ni `children` par nesting, ni `parentId`/`sortOrder`/`depth` par adjacence) : ces représentations concrètes sont différées (`ZMindmapNode` nesting → E10 ; `ZHierarchyNode` flat → E9/hiérarchie), conformément à l'OQ-4 non tranchée. Documenté explicitement en Dev Notes comme choix de portée.

4. **`ZSyncable` — clé LWW abstraite.** Un contrat abstrait `ZSyncable` expose `DateTime? get updatedAt` (clé de merge **Last-Write-Wins**, AD-9). Le contrat est **agnostique** quant à l'emplacement de la métadonnée (dans l'entité comme `StudyFolder`, ou hors-entité via `ZSyncMeta` comme `Mindmap`) : il exprime seulement *qu'une* valeur LWW existe. Aucune logique de merge ici (portée par le repository/orchestrateur, E5).

5. **`ZSyncMeta` — métadonnées de sync hors-entité.** Un value object `ZSyncMeta` porte `DateTime? updatedAt` et `bool isDeleted` (défaut `false`), immuable (`final` + constructeur `const`). Il fournit :
   - `factory ZSyncMeta.fromJson(Map<String,dynamic>)` **défensive** : clés absentes/corrompues → défauts sûrs (`isDeleted` absent → `false` ; `updated_at` absent/mal formé → `null`), **jamais** de throw (AD-10) ;
   - `Map<String,dynamic> toJson()` émettant les clés **snake_case** `updated_at` (ISO-8601 ou `null`) et `is_deleted` ;
   - `copyWith` (avec sentinelle permettant de remettre `updatedAt` à `null` si pertinent) ;
   - `==`/`hashCode` **à la main** (égalité de valeur sur `updatedAt` + `isDeleted`).
   Aucun champ métier de l'entité ne fuit dans `ZSyncMeta` (séparation stricte, canonique §2.2 note d'invariant Story 5.4).

6. **Hiérarchie `ZFailure` extensible inter-package (NON `sealed`).** Une base abstraite `ZFailure` (déclarée `abstract class`/`abstract base class`, **jamais `sealed`**) est **extensible depuis un autre package** (ex. `FlashcardGenerationFailure` en `zcrud_flashcard`, ou une failure applicative). Elle porte au minimum `String get message` et implémente `==`/`hashCode` de base sur `(runtimeType, message)`. Quatre sous-classes canoniques concrètes existent : `DomainFailure`, `CacheFailure`, `NotFoundFailure`, `ServerFailure` — chacune `const`, `final`, avec `==`/`hashCode` incluant tout champ propre (ex. `NotFoundFailure` peut porter un `id`/`entity` optionnel). **Décision d'architecture consignée** (voir Dev Notes « Ambiguïté tranchée ») : `sealed` est **rejeté ici** précisément parce que AD-4 interdit `sealed` pour l'extension **inter-package** — les satellites (E9) et les apps hôtes doivent pouvoir ajouter leurs propres `ZFailure` sans forker le cœur.

7. **Égalité de valeur de `ZFailure` testée.** Pour chaque sous-classe : deux instances aux mêmes champs sont **égales** (`==` vrai, `hashCode` identique) ; deux instances de champs différents sont **inégales** ; deux instances de **sous-classes différentes** mais de même `message` sont **inégales** (discrimination par `runtimeType`) ; l'égalité est réflexive et symétrique. `ZFailure` n'est **pas** `Equatable` (0 occurrence d'`Equatable`, convention canonique §5) — `==`/`hashCode` manuels via `Object.hash`.

8. **`dartz` câblé + re-export curaté.** `dartz: ^0.10.1` est ajouté aux `dependencies` de `packages/zcrud_core/pubspec.yaml`. Le barrel `lib/zcrud_core.dart` re-exporte un **sous-ensemble curaté** de dartz : `export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;` (pas d'export global, pour ne pas polluer l'API publique). Un typedef ergonomique `typedef ZResult<T> = Either<ZFailure, T>;` est fourni et exporté. Un test de fumée démontre `ZResult<int>` (`Right(1)` / `Left(DomainFailure(...))`) et `Either<ZFailure, Unit>` (`Right(unit)`) — **sans** importer `package:dartz` directement dans le test (preuve que le barrel suffit).

9. **Emplacements & barrel.** Les nouveaux types vivent sous `packages/zcrud_core/lib/src/domain/` selon le mapping décidé (voir Dev Notes) ; l'API publique passe **uniquement** par le barrel `lib/zcrud_core.dart` (aucune déclaration d'impl dans le barrel). Le barrel exporte `ZEntity`, `ZNode`, `ZSyncable`, `ZSyncMeta`, `ZFailure` + les 4 sous-classes, `ZResult`, et le sous-ensemble dartz ; il continue d'exporter `ZCoreApi`.

10. **Vérif verte (AD-11/AD-5/AD-16 respectés).** `dart run melos run generate` OK (aucun codegen requis par cette story mais le pipeline reste vert), `dart analyze`/`melos run analyze` RC=0 (zéro warning bloquant, `public_member_api_docs` satisfait si activé pour le cœur), `flutter test`/`melos run test` RC=0 avec les tests unitaires ajoutés. Aucun type backend (`Timestamp`/`Filter`/`FirebaseException`) n'apparaît (AD-5) ; aucune méthode de contrat ne renvoie un flux enveloppé dans `Either` (AD-11 — non applicable ici, aucun `Stream` introduit, mais l'invariant est documenté pour E2-2).

## Tasks / Subtasks

- [x] **Tâche 1 — Dépendance dartz + re-export barrel (AC: 1, 8, 9)**
  - [x] Ajouter `dartz: ^0.10.1` sous `dependencies:` dans `packages/zcrud_core/pubspec.yaml` (dépendance **pur-Dart** autorisée dans le cœur ; ne viole ni AD-1 — ce n'est pas un `zcrud_*` — ni AD-14/AD-15 — dartz n'est ni Flutter ni un gestionnaire d'état).
  - [x] `dart pub get` racine (workspace) RC=0 ; vérifier lockfile racine unique intact (non-régression E1-1).
  - [x] Ajouter au barrel `lib/zcrud_core.dart` : `export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;` + exports des nouveaux fichiers `src/domain/…`.
- [x] **Tâche 2 — `ZEntity` + `ZNode` + `ZSyncable` (AC: 2, 3, 4)**
  - [x] Créer `lib/src/domain/contracts/z_entity.dart` : `abstract class ZEntity { const ZEntity(); String? get id; bool get isEphemeral => id == null; }` + docstring d'origine (`// origine: lex_core/…/flashcard.dart (isEphemeral)`).
  - [x] Créer `lib/src/domain/contracts/z_node.dart` : `abstract class ZNode { const ZNode(); String get id; }` + docstring de portée (topologie différée OQ-4).
  - [x] Créer `lib/src/domain/contracts/z_syncable.dart` : `abstract class ZSyncable { DateTime? get updatedAt; }` + docstring LWW (AD-9).
- [x] **Tâche 3 — `ZSyncMeta` value object (AC: 1, 5)**
  - [x] Créer `lib/src/domain/sync/z_sync_meta.dart` : classe immuable (`final`, `const`), champs `updatedAt`/`isDeleted`.
  - [x] `fromJson` défensive (défauts sûrs, parse ISO-8601 tolérant, jamais throw) ; `toJson` clés `updated_at`/`is_deleted`.
  - [x] `copyWith` avec sentinelle pour reset-null de `updatedAt` ; `==`/`hashCode` via `Object.hash(updatedAt, isDeleted)` ; `toString` lisible.
- [x] **Tâche 4 — Hiérarchie `ZFailure` (AC: 6, 7)**
  - [x] Créer `lib/src/domain/failures/z_failure.dart` : base `abstract class ZFailure { const ZFailure(this.message); final String message; @override bool operator ==(...) ; @override int get hashCode ...; }` (égalité de base `runtimeType`+`message`).
  - [x] Sous-classes `DomainFailure`, `CacheFailure`, `NotFoundFailure`, `ServerFailure` (`const`, `final`), chacune surchargeant `==`/`hashCode` pour tout champ propre (`NotFoundFailure(super.message, {this.id, this.entity})`).
  - [x] Typedef `typedef ZResult<T> = Either<ZFailure, T>;` (dans `z_failure.dart`), exporté par le barrel.
- [x] **Tâche 5 — Tests unitaires (AC: 1, 5, 7, 8, 10)**
  - [x] `test/domain/z_failure_test.dart` : égalité réflexive/symétrique, discrimination type/champ, cohérence `hashCode`, usage dans `Set`/`Map`, sous-classe tierce (extensibilité AC6).
  - [x] `test/domain/z_sync_meta_test.dart` : round-trip `toJson`/`fromJson`, parsing défensif (clés absentes/corrompues → défauts, jamais throw), égalité de valeur, `copyWith` reset-null.
  - [x] `test/domain/z_result_test.dart` : `ZResult<int>`/`Either<ZFailure,Unit>` via **barrel seul** (aucun import `package:dartz`).
  - [x] `test/domain/z_contracts_test.dart` : `ZEntity.isEphemeral` (AC2), `ZNode.id` non-null (AC3), `ZSyncable.updatedAt` (AC4).
  - [x] `test/purity/domain_purity_test.dart` : test prouvant l'absence d'import Flutter/Firebase/Hive/gestionnaire d'état sous `lib/src/domain/`.
- [x] **Tâche 6 — Vérif verte & traçabilité (AC: 10)**
  - [x] `dart run melos run generate` OK, `dart analyze`/`melos run analyze` RC=0, `melos run test` RC=0 (`package:test`, pur-Dart — pas `flutter_test`).
  - [x] Vérifier que `ZCoreApi` reste exporté (non-régression E1-2) et que le graphe AD-1 reste acyclique / cœur out-degree 0 (17 arêtes, CORE OUT=0).

## Dev Notes

### Emplacements décidés (sous `packages/zcrud_core/lib/src/domain/`)

| Type | Fichier | Nature |
|---|---|---|
| `ZEntity` | `contracts/z_entity.dart` | contrat abstrait pur (id opaque nullable, `isEphemeral`) |
| `ZNode` | `contracts/z_node.dart` | contrat abstrait fin (id non-null ; topologie différée) |
| `ZSyncable` | `contracts/z_syncable.dart` | contrat abstrait (clé LWW `updatedAt`) |
| `ZSyncMeta` | `sync/z_sync_meta.dart` | value object hors-entité (`updated_at`/`is_deleted`), `==`/`hashCode`, JSON manuel défensif |
| `ZFailure` (+ 4 sous-classes) | `failures/z_failure.dart` | base abstraite extensible + `DomainFailure`/`CacheFailure`/`NotFoundFailure`/`ServerFailure` |
| `ZResult<T>` | `failures/z_failure.dart` (ou `failures/z_result.dart`) | `typedef ZResult<T> = Either<ZFailure, T>` |

Le barrel `lib/zcrud_core.dart` ajoute les `export 'src/domain/…';` correspondants + le re-export curaté dartz, et **conserve** `export 'src/domain/z_core_api.dart';`.

### Ambiguïté tranchée — `sealed` vs `abstract` pour `ZFailure`

Le schéma canonique (§4, tableau des mécanismes) et **AD-4** rejettent explicitement `sealed` **pour l'extension inter-package** : « `sealed` pour la provenance extensible : fermé à l'extension inter-package. DODLP/IFFD ne peuvent pas ajouter un variant à une `sealed` d'un autre package. » Or `ZFailure` **doit** être extensible depuis les satellites : lex porte déjà `FlashcardGenerationFailure` (`kind`/`retryAfter`/`quota`) hors du jeu de base, destiné à `zcrud_flashcard` (E9), et une app hôte peut vouloir ses propres failures. **Décision : `ZFailure` est une `abstract class` (extensible), PAS `sealed`.** On renonce donc à l'exhaustivité compilateur d'un `switch` sur les failures — acceptable car le traitement d'erreur se fait par `fold`/`is`/message, pas par pattern-matching exhaustif inter-package. (AD-4 autorise « une base abstraite FINE sans sérialisation » — c'est exactement `ZFailure`, non sérialisée.) Cette décision est cohérente avec le fait que `ZFlashcardSource`, elle, RESTE `sealed` **en interne** au package flashcard (ensemble fermé), avec un variant `custom` + registre pour l'ouverture inter-package — deux usages distincts à ne pas confondre.

### Invariants d'architecture applicables (rappel dev)

- **AD-1** : `zcrud_core` = puits du graphe, **aucune** arête `zcrud_*` sortante. `dartz` n'est pas un `zcrud_*` → OK.
- **AD-5** : backend-agnostique — **aucun** `Timestamp`/`Filter`/`FirebaseException`. Les dates sont des `DateTime` Dart, sérialisées ISO-8601 par `ZSyncMeta.toJson`.
- **AD-10** : désérialisation défensive — `ZSyncMeta.fromJson` ne throw jamais ; champ absent → défaut sûr. Évolution additive seulement.
- **AD-11** : `Either<ZFailure,T>` (dartz), `Unit` pour void, **flux `Stream<List<T>>` nus** (aucun flux enveloppé). Ici aucun `Stream` n'est introduit ; l'invariant cadre E2-2.
- **AD-14** : domaine pur-Dart ; invariants métier (matérialisation de l'éphémère, merge LWW, cascade) portés par le **repository** (E2-2/E5), **pas** par ces contrats.
- **AD-16** : `ZSyncMeta` (`updated_at`/`is_deleted`) est le standard hors-entité (tranche OQ-3 en faveur du hors-entité). Le port `ZAcl`/pagination curseur relève de **E2-2** (hors périmètre ici).

### Conventions de code (canonique §5)

- `@JsonSerializable` **non requis** pour `ZSyncMeta` : fabriques `fromJson`/`toJson` **écrites à la main** (le codegen zcrud n'existe pas avant E2-5, et ces contrats de base restent techno-neutres). Pas de `part '*.g.dart'`.
- **`Equatable` jamais** (0 occurrence) — `==`/`hashCode` manuels via `Object.hash`.
- **`freezed` non imposé** — classes `final` + constructeur `const`.
- IDs = `String` **opaques** ; `ZEntity.id` **nullable** (éphémère), `ZNode.id` **non-null** ; dates **ISO-8601**.
- Traçabilité : chaque type porte un commentaire d'origine `lex_core/…:ligne` (canonique §6.6) pour le re-portage.

### Source tree à toucher

```
packages/zcrud_core/
  pubspec.yaml                         # + dependencies: dartz ^0.10.1
  lib/zcrud_core.dart                  # + exports (contracts, sync, failures) + re-export curaté dartz
  lib/src/domain/
    z_core_api.dart                    # (inchangé — reste exporté)
    contracts/z_entity.dart            # NEW
    contracts/z_node.dart              # NEW
    contracts/z_syncable.dart          # NEW
    sync/z_sync_meta.dart              # NEW
    failures/z_failure.dart            # NEW (base + 4 sous-classes + typedef ZResult)
  test/
    domain/z_failure_test.dart         # NEW
    domain/z_sync_meta_test.dart       # NEW
    domain/z_result_test.dart          # NEW
    purity/domain_purity_test.dart     # NEW (ou script grep)
```

### Project Structure Notes

- `zcrud_core` **autorise Flutter** au niveau package (moteur d'édition, E2-7+), mais la **couche `domain/`** reste **pur-Dart** (AD-14) : ces contrats n'importent que `dart:core` + `package:dartz`. Ne pas ajouter `flutter` au pubspec pour cette story.
- `flutter test` fonctionne sur un package pur-Dart via `flutter_test` si le package le déclare en dev_dependency ; sinon utiliser `dart test`. Vérifier ce que E1 a posé (le squelette n'a pas encore de `dev_dependencies` test) — ajouter `test:` (dev) si absent, **pas** `flutter_test` tant que le domaine reste pur-Dart. Décision dev : privilégier `package:test` (pur-Dart) pour ne pas tirer Flutter dans le cœur au stade contrats.
- Ne pas régénérer/committer de `*.g.dart` (aucun modèle annoté ici).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E2] — objectif E2, ordre intra-épic E2-1→E2-2→E2-7→E2-9, AC Story E2-1.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-11] — `Either<ZFailure,T>` dartz, `Unit`, `Stream` nu, hiérarchie `ZFailure` avec `==`/`hashCode`.
- [Source: architecture.md#AD-5] — domaine backend-agnostique, ports neutres.
- [Source: architecture.md#AD-16] — `ZSyncMeta` hors-entité (`updated_at`/`is_deleted`), tranche OQ-3.
- [Source: architecture.md#AD-4] — extension par composition ; **`sealed` rejeté pour l'extension inter-package** (fonde la décision `ZFailure` non-`sealed`).
- [Source: architecture.md#AD-14] — pureté des couches ; invariants métier au repository.
- [Source: architecture.md#AD-1] — `zcrud_core` puits du graphe, out-degree 0.
- [Source: architecture.md#Stack] — `dartz ^0.10.1`.
- [Source: architecture.md#Consistency Conventions] — id `String` opaque (nullable éphémère), ISO-8601, enums camelCase, `ZSyncMeta` hors-entité.
- [Source: docs/canonical-schema.md#2.1] — `Flashcard.isEphemeral` (id nullable, matérialisation par repo).
- [Source: docs/canonical-schema.md#2.2] — note d'invariant sync hors-entité (`updated_at`/`is_deleted`) Story 5.4.
- [Source: docs/canonical-schema.md#4] — mécanismes d'extension ; rejet de `sealed` inter-package ; base abstraite fine autorisée.
- [Source: docs/canonical-schema.md#5] — conventions : `Equatable` jamais, `==`/`hashCode` manuels, `freezed` non imposé, `Either<Failure,T>`/`Unit`/`Stream` nu, id `String` opaque.
- [Source: packages/zcrud_core/lib/zcrud_core.dart] — barrel actuel (exporte `ZCoreApi`, à étendre).
- [Source: packages/zcrud_core/pubspec.yaml] — pubspec actuel (aucune dépendance ; ajouter `dartz`).

## Stratégie de tests

- **Égalité `ZFailure` (`z_failure_test.dart`)** : pour chaque sous-classe — `a == a` (réflexif), `a == b ⇒ b == a` (symétrique), champs égaux ⇒ égal + `hashCode` identique, champs différents ⇒ inégal, `DomainFailure('x') != CacheFailure('x')` (discrimination `runtimeType`), insertion dans un `Set`/clé de `Map` cohérente. Vérifier qu'une **sous-classe tierce fictive** (déclarée dans le test) compile en étendant `ZFailure` (preuve d'extensibilité inter-package — AC6).
- **`ZSyncMeta` (`z_sync_meta_test.dart`)** : round-trip `toJson→fromJson` (clés `updated_at`/`is_deleted`) ; `fromJson({})` → `updatedAt==null`, `isDeleted==false`, **sans throw** ; `fromJson({'updated_at':'garbage'})` → `updatedAt==null` sans throw (défensif AD-10) ; `fromJson({'is_deleted':'true'})`/type inattendu → défaut sûr ; égalité de valeur ; `copyWith` reset-null de `updatedAt`.
- **dartz via barrel (`z_result_test.dart`)** : `import 'package:zcrud_core/zcrud_core.dart';` **seul** ; construire `ZResult<int> r = right(1);` / `left(const DomainFailure('e'))` ; `Either<ZFailure, Unit> u = right(unit);` ; `fold` sur les deux branches. Interdit d'importer `package:dartz` dans ce test (prouve que le barrel réexporte le nécessaire — AC8).
- **Pureté (`domain_purity_test.dart` ou script)** : lire tous les `.dart` sous `lib/src/domain/`, asserter qu'aucun ne contient un import `package:flutter`, `dart:ui`, `package:cloud_firestore`, `package:firebase`, `package:hive`, `package:flutter_riverpod`, `package:riverpod`, `package:get/`, `package:provider` (AC1). Réutiliser/étendre l'extracteur de graphe/lint AD-1 posé en E1-2/E1-3 si disponible.
- **Vérif verte finale** : `melos run generate` OK → `dart analyze`/`melos run analyze` RC=0 → `flutter test`/`melos run test` RC=0.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story` chargé via fallback disque `.claude/skills/bmad-dev-story/SKILL.md`).

### Debug Log References

- `dart pub get` (workspace) RC=0 — dartz résolu (transitif → runtime de zcrud_core), `test` en dev_dep. Lockfile racine unique intact (`./pubspec.lock`, aucun lock parasite de package).
- `dart run melos run generate` RC=0 (SUCCESS, no-op propre — aucun modèle annoté).
- `dart run melos run analyze` RC=0 (14 packages, « No issues found! »). 2 lints corrigés en cours de route : `directives_ordering` (exports du barrel triés alphabétiquement) et `equal_elements_in_set` (test de dédup Set reconstruit à l'exécution depuis une liste).
- `dart run melos run test` RC=0 — `zcrud_core`: **34 tests** passés (« All tests passed! »).
- `dart run melos run verify` RC=0 — graph_proof: **17 arêtes**, CORE OUT=0, ACYCLIQUE OK ; gate:melos OK ; gate:reflectable OK ; gate:secrets OK ; gate:codegen OK (0 modèle) ; gate:compat OK (voie manifeste) ; verify:serialization no-op documenté.
- Preuve de pureté (grep `packages/zcrud_core/lib/`): 0 occurrence de `package:flutter|dart:ui|cloud_firestore|package:firebase|package:hive|flutter_riverpod|package:riverpod|package:get/|package:provider/`. Seul import externe du domaine : `package:dartz/dartz.dart` (dans `failures/z_failure.dart`).
- Non-régression : `melos list` = 14 ; 0 `.g.dart` suivi par git.

### Completion Notes List

- **10/10 ACs satisfaits.** Contrats posés en Dart pur sous `lib/src/domain/` ; barrel étendu avec re-export **curaté** dartz (`show Either, Left, Right, Unit, unit`, PAS d'export global) + `ZResult<T>` ; `ZCoreApi` conservé (non-régression E1-2).
- **AC6 (décision `abstract` vs `sealed`)** appliquée : `ZFailure` est `abstract class` (extensible inter-package, cf. AD-4). Extensibilité prouvée par une sous-classe tierce `_AppSpecificFailure` déclarée dans le test.
- **AC8** : `z_result_test.dart` n'importe QUE le barrel (aucun `package:dartz`) → prouve que le re-export suffit. Note : le sous-ensemble curaté expose les constructeurs `Right`/`Left` (pas les helpers `right()`/`left()` minuscules) ; les tests utilisent `Right(...)`/`Left(...)` conformément au libellé principal de l'AC8.
- **AD-10** : `ZSyncMeta.fromJson` défensive (map vide, `updated_at` corrompu/typé, `is_deleted` non-bool → défauts sûrs, jamais de throw).
- Test `dart test` via `package:test` (pur-Dart) — `flutter_test` volontairement écarté pour ne pas tirer Flutter dans le cœur au stade contrats (Dev Notes).
- **Observation hors périmètre (à traiter par l'orchestrateur, pas un blocage dev-story)** : au commit baseline `8f28755`, l'infrastructure E1 (`packages/`, `scripts/`, `tool/`, `melos.yaml`, `pubspec.yaml` racine, `analysis_options.yaml`, `.github/workflows/`) est présente sur disque et pleinement fonctionnelle mais **non suivie par git** (seuls les artefacts de planification + `CLAUDE.md` sont committés). Le futur commit de fin d'epic devra inclure ces fichiers E1 en plus des livrables E2-1.

### File List

**Nouveaux fichiers (code source) :**
- `packages/zcrud_core/lib/src/domain/contracts/z_entity.dart`
- `packages/zcrud_core/lib/src/domain/contracts/z_node.dart`
- `packages/zcrud_core/lib/src/domain/contracts/z_syncable.dart`
- `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`
- `packages/zcrud_core/lib/src/domain/failures/z_failure.dart`

**Nouveaux fichiers (tests) :**
- `packages/zcrud_core/test/domain/z_failure_test.dart`
- `packages/zcrud_core/test/domain/z_sync_meta_test.dart`
- `packages/zcrud_core/test/domain/z_result_test.dart`
- `packages/zcrud_core/test/domain/z_contracts_test.dart`
- `packages/zcrud_core/test/purity/domain_purity_test.dart`

**Fichiers modifiés :**
- `packages/zcrud_core/pubspec.yaml` (+ `dependencies: dartz ^0.10.1`, + `dev_dependencies: test ^1.25.0`)
- `packages/zcrud_core/lib/zcrud_core.dart` (barrel : re-export curaté dartz + exports domaine)
- `pubspec.lock` (racine, régénéré par `dart pub get` — non committé)
