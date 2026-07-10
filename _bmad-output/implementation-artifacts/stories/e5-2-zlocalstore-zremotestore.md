---
baseline_commit: 8f2569b4b023f26b3f6c281e614f7af3eb4f4e47
---

# Story 5.2: `ZLocalStore` (Hive) + `ZRemoteStore`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a intégrateur backend de zcrud,
I want les **deux ports neutres** `ZLocalStore<T>` / `ZRemoteStore<T>` définis dans `zcrud_core` (Dart pur, backend-agnostiques) **et** leurs adaptateurs concrets dans `zcrud_firestore` — un `HiveZLocalStore<T>` (store local **source de vérité** offline-first, JSON, décodage défensif, soft-delete hors-entité) et un `FirestoreZRemoteStore<T>` (store distant **fire-and-forget** s'appuyant sur l'adaptateur Firestore E5-1),
so that le patron offline-first à venir (E5-3 merge LWW / E5-4 orchestrateur) puisse composer un « local qui fait autorité » avec un « distant best-effort » **sans** qu'aucun type `hive`/`cloud_firestore` ne fuite dans le domaine, et avec les mêmes invariants de clé et de soft-delete que l'adaptateur Firestore déjà débogué.

## Contexte épic (E5)

**E5 — Backend Firestore & offline-first (`zcrud_firestore`).** Objectif : adaptateur Firestore débogué + patron offline-first. Couvre FR-12/FR-13. AD-5/AD-9/AD-10/AD-11.
Phase : **E5-1/E5-2 = MVP** (repo Firestore + `ZLocalStore`, requis par E7/E8) ; **E5-3/E5-4 = v1.x** (offline-first LWW + orchestrateur ; consommateur = donnée d'étude E9).

E5-1 (**done**) a livré `FirebaseZRepositoryImpl<T>` : l'adaptateur Firestore du port neutre `ZRepository<T>`, avec voie de décodage **défensive** (`_decode` → `fromMapSafe`), soft-delete **hors-entité** (`ZSyncMeta`, clés `is_deleted`/`updated_at` ISO-8601), invariant de **corps `id`** (le corps du document porte toujours `id == doc.id`) et isolation Firebase prouvée (aucun des 6 types `cloud_firestore` en signature publique). E5-2 pose maintenant les **deux stores bas-niveau** qui, en E5-3/E5-4, seront **composés** pour réaliser l'offline-first.

## Frontière de portée — les ports N'EXISTENT PAS ENCORE (à créer ici)

⚠️ **Correction d'hypothèse.** Contrairement à ce qu'on pourrait croire, `ZLocalStore`/`ZRemoteStore` **ne sont PAS définis en E2-2**. E2-2 a **explicitement différé** leur définition à E5 :

> *« ❌ Pas de `ZLocalStore`/`ZRemoteStore` : ces ports bas-niveau orientés adaptateur sont introduits **avec** l'adaptateur offline-first en **E5** (canonique §7 “à abstraire derrière `ZLocalStore`/`ZRemoteStore`”). Documenté comme frontière de portée. »*
> [Source: stories/e2-2-ports-donnees.md#Frontière de portée]

Vérifié sur disque : `packages/zcrud_core/lib/src/domain/ports/` ne contient que `z_repository.dart`, `z_acl.dart`, `cloud_storage_repository.dart`. **Aucun** `ZLocalStore`/`ZRemoteStore`. **E5-2 CRÉE donc ces deux ports** (dans `zcrud_core`, Dart pur, sans type backend) **puis** les implémente (dans `zcrud_firestore`).

## Acceptance Criteria

### Ports neutres (dans `zcrud_core`, Dart pur — AD-5)

1. **Port `ZLocalStore<T extends ZEntity>` défini dans `zcrud_core`.** Nouveau fichier `packages/zcrud_core/lib/src/domain/ports/z_local_store.dart`, exporté par le barrel `zcrud_core.dart`. **Dart pur** : aucun import Flutter/Hive/Firebase. Backend-agnostique (AD-5) : aucune signature n'expose de type `hive` (`Box`, `HiveObject`, `HiveInterface`). Toutes les opérations retournent `ZResult<…>` (`Either<ZFailure,T>`) / `ZResult<Unit>` ; les **flux** sont des `Stream<List<T>>` **NUS** (AD-11). Le dartdoc établit le rôle **source de vérité offline-first** et l'abstraction permettant un backend **Isar/Drift/SQLite ultérieur** (déféré). Signatures minimales : `watchAll()`, `getAll()`, `getById(String id)`, `put(T item)`, `softDelete(String id)`, `restore(String id)`, `clear()` (optionnel, documenté), `dispose()`. *(AD-5, AD-11)*

2. **Port `ZRemoteStore<T extends ZEntity>` défini dans `zcrud_core`.** Nouveau fichier `packages/zcrud_core/lib/src/domain/ports/z_remote_store.dart`, exporté par le barrel. **Dart pur**, backend-agnostique : aucune signature n'expose de type `cloud_firestore`. Le dartdoc établit la sémantique **fire-and-forget / best-effort** (le distant n'est jamais la source de vérité ; la composition local↔distant et le merge LWW **appartiennent à E5-3/E5-4**, hors de ce port). Signatures neutres pour pousser/tirer un agrégat : `push(T item)`, `remoteDelete(String id)` (propagation soft-delete), `pull({ZDataRequest? request})` (lecture best-effort), `watchAll()`. Retours `ZResult<…>` / `Stream<List<T>>` nus (AD-11). *(AD-5, AD-9, AD-11)*

3. **`zcrud_core` ne tire NI Hive NI Firebase.** Aucune dépendance `hive`/`hive_flutter`/`cloud_firestore`/`firebase_core` ajoutée à `packages/zcrud_core/pubspec.yaml`. Le gate melos (`graph_proof.py` : `CORE OUT=0`) et le `dry-run` de compat (FR-25) restent verts. Un contrôle (lecture `pubspec.yaml`) prouve l'absence de dépendance backend. *(AD-1, AD-5)*

### Adaptateur local Hive (dans `zcrud_firestore`)

4. **`HiveZLocalStore<T extends ZEntity>` implémente `ZLocalStore<T>`.** Nouveau fichier `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart`, exporté par le barrel `zcrud_firestore.dart`. Stockage Hive **une box par entité/kind** (nom de box dérivé du `kind`). Un `put(item)` suivi d'un `getById(id)` restitue une entité **égale** (round-trip fidèle, `id` inclus). *(AD-5)*

5. **(Dé)sérialisation JSON via codec injecté + décodage DÉFENSIF (AD-10).** L'encodage passe par le codec/registre (`ZcrudRegistry.encode`/`ZModelCodec.toMap`) ; le décodage passe par la **voie tolérante** — un `fromMapSafe` injecté (ex. `ZModelAdapter.fromMapSafe`) comme en E5-1. Une **entrée de cache corrompue/tronquée** (champ manquant, enum inconnu, type inattendu) **ne casse jamais** la lecture : l'entrée non décodable est **écartée + loggée** (log injectable, no-op par défaut), le flux/la page continue. Un test avec **1 entrée corrompue parmi N** retourne **N-1** entités **sans throw**. *(AD-10 ; learning E5-1 : le fake/test ne doit pas masquer la sémantique prod → l'entrée corrompue est un cas RÉEL exercé.)*

6. **Soft-delete hors-entité + cohérence des lectures (learning E5-1 MAJEUR-2).** `softDelete(id)` bascule `is_deleted = true` et `restore(id)` `is_deleted = false` dans les métadonnées **hors-entité** (`ZSyncMeta`, clés `is_deleted`/`updated_at` ISO-8601), **sans** toucher aux champs métier. La suppression locale est un **soft-delete** (drapeau), **pas** un `box.delete` physique (la propagation au distant est gérée en E5-3). Un helper `_isVisible(map) = (map['is_deleted'] == false)` est appliqué de façon **cohérente** sur `getById` **et** `getAll`/`watchAll` (aucune divergence get vs getAll). Un `id` inexistant → `Left(NotFoundFailure)`. *(AD-9, AD-16)*

7. **Invariant de clé — corps `id` toujours écrit (learning E5-1 MAJEUR-1).** `put`/`_encode` écrivent **toujours** le champ `id` dans le corps sérialisé, **égal à la clé de box** (`box.put(id, map)` avec `map['id'] == id`). Cohérence local/remote garantie sur la clé **et** sur `is_deleted`/`updated_at`. Une entité **éphémère** (`isEphemeral`) reçoit une identité opaque à l'écriture (matérialisation portée par le store, AD-14) ; une cible manquante requise → `Left(DomainFailure)`. Un test prouve `getById(id).id == id` et l'égalité clé↔corps. *(AD-14)*

8. **`watchAll()` local émet les changements.** Le flux local (`box.watch()` → `Stream<List<T>>` nu) émet un **seed immédiat** puis ré-émet la liste des visibles à chaque `put`/`softDelete`/`restore`. Un test prouve qu'après un `put` (puis un `softDelete`) le flux émet la liste mise à jour (élément ajouté, puis retiré des visibles). *(AD-11)*

9. **Enveloppe d'erreurs — `Either`/`CacheFailure`, jamais de catch nu (AD-11).** Toute opération Hive est enveloppée : une erreur d'accès au store (box fermée/corrompue, I/O) → `Left(CacheFailure(...))` (pas `ServerFailure` : le local est un **cache**). **Zéro** `try`/`catch` nu ni `catch(_){}`. Un `getById` sur clé absente → `Left(NotFoundFailure)` (`null ≠ erreur`), une box vide → `Right(<T>[])`. Un test injecte une erreur d'accès et prouve `Left(CacheFailure)` (jamais d'exception qui remonte). *(AD-11)*

10. **ISOLATION AD-5 — aucun type Hive ne fuit.** Aucune **signature publique de méthode** de `HiveZLocalStore<T>` (retours, params exposés hors `zcrud_firestore`) n'expose `Box`, `HiveObject`, `HiveInterface` ni aucun symbole `hive`/`hive_flutter`. Les retours restent `ZResult<…>` / `Stream<List<T>>` **nus**. La couture DI (constructeur pouvant recevoir une `Box`/`HiveInterface` pour la testabilité) est **admise** — comme en E5-1 le constructeur reçoit `FirebaseFirestore` (couture DI voulue, hors des types interdits en signature de méthode publique) — mais un `factory` documenté (ex. `HiveZLocalStore.openBox(kind, ...)`) offre une entrée sans exposer Hive. Un test/gate vérifie qu'aucun symbole `hive` n'apparaît dans une **signature de membre public** exporté. *(AD-5 ; miroir E5-1 AC13)*

### Adaptateur distant (dans `zcrud_firestore`)

11. **`FirestoreZRemoteStore<T extends ZEntity>` implémente `ZRemoteStore<T>`.** Nouveau fichier `packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart`, exporté par le barrel. Il **s'appuie sur / délègue** au `FirebaseZRepositoryImpl<T>` d'E5-1 (réutilisation — pas de second traducteur Firestore) : `push → save`, `remoteDelete → softDelete`, `pull → getAll`, `watchAll → watchAll`. **Même sémantique de clé** (corps `id`) **et de soft-delete** (`is_deleted`/`updated_at` hors-entité) que l'adaptateur E5-1. Un round-trip `push`/`pull` restitue l'entité (via `fake_cloud_firestore`). *(AD-5, AD-9)*

12. **Fire-and-forget best-effort (borné E5-2).** La sémantique **fire-and-forget** du port (le distant n'est jamais la source de vérité ; échec distant ≠ échec du store local) est **documentée** ; l'impl E5-2 se contente de **déléguer** à l'adaptateur E5-1 et de propager son `ZResult` (les erreurs restent typées `ServerFailure`, jamais avalées). L'**orchestration** (débounce, best-effort silencieux, `Right(unit)` si déconnecté, cascade ≤ 450) **appartient à E5-4** et n'est **PAS** implémentée ici — frontière **explicite** en dartdoc. Aucun type `cloud_firestore` ne fuit (isolation héritée d'E5-1, re-vérifiée). *(AD-9 ; frontière E5-4)*

### Frontière & vérif

13. **Frontière E5-2 vs E5-3/E5-4 — PAS de merge ni d'orchestrateur.** E5-2 livre **les deux stores et leurs ports** uniquement. Le **merge Last-Write-Wins** sur `updatedAt`, la **composition** « local source de vérité + distant fire-and-forget », la cascade bornée ≤ 450 et le `ZSyncOrchestrator` (débounce ~400 ms) sont **hors périmètre** (E5-3/E5-4, v1.x). Aucune méthode `sync()`/merge n'est ajoutée en E5-2 ; la frontière est **documentée** en dartdoc des deux ports et des deux adaptateurs. *(AD-9)*

14. **Dépendance Hive au SEUL pubspec de `zcrud_firestore` + vérif verte.** `hive` (^2.2.3) et `hive_flutter` (^1.1.0) ajoutés **uniquement** à `packages/zcrud_firestore/pubspec.yaml` (jamais à `zcrud_core`) ; dev-dep de test pour Hive (`hive_test` ou init tmpdir). `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0 ; gates CI (anti-`reflectable`, scan de secrets, codegen, rétro-compat sérialisation, graphe `CORE OUT=0`) **verts** avant `review`. *(Stack ; AD-1)*

## Tasks / Subtasks

- [x] **T1. Ports neutres dans `zcrud_core`** (AC: 1, 2, 3)
  - [x] Créer `packages/zcrud_core/lib/src/domain/ports/z_local_store.dart` : `abstract class ZLocalStore<T extends ZEntity>` (Dart pur, `import 'package:dartz/dartz.dart' show Unit;` + contrats internes seulement) ; dartdoc rôle source de vérité + abstraction Isar/Drift différée.
  - [x] Créer `packages/zcrud_core/lib/src/domain/ports/z_remote_store.dart` : `abstract class ZRemoteStore<T extends ZEntity>` ; dartdoc fire-and-forget + frontière E5-3/E5-4.
  - [x] Exporter les deux depuis `packages/zcrud_core/lib/zcrud_core.dart` (barrel).
  - [x] Ne **rien** ajouter à `zcrud_core/pubspec.yaml` ; re-jouer le gate `CORE OUT=0` (`melos run verify`).
- [x] **T2. `HiveZLocalStore<T>` — squelette + DI** (AC: 4, 7, 10)
  - [x] Classe générique dans `lib/src/data/hive_z_local_store.dart` implémentant `ZLocalStore<T>`.
  - [x] Injection (miroir E5-1) : le `kind`, le codec (`encode`/`toMap`) + un `fromMapSafe` injecté (défensif), un log injectable `ZFirestoreLog`-like (no-op par défaut — réutiliser/partager le typedef local d'E5-1), un sélecteur d'`id`, et la **box** (via `factory openBox` ou `Box` injectée pour tests).
  - [x] `_encode` fusionne les métadonnées `ZSyncMeta` (`updated_at` ISO-8601, `is_deleted:false`) + écrit **toujours** le corps `id` (invariant clé↔corps).
  - [x] Types Hive (`Box`, `HiveInterface`) restent **privés** aux membres/DI (aucune signature de méthode publique).
- [x] **T3. Écritures locales : `put`, `softDelete`, `restore`, `clear`, `dispose`** (AC: 6, 7, 9)
  - [x] `put` : matérialisation éphémère (id opaque si `isEphemeral`), `box.put(id, _encode(item))`, cible manquante → `Left(DomainFailure)`.
  - [x] `softDelete`/`restore` : relire la map, basculer `is_deleted` hors-entité, réécrire ; `id` absent → `Left(NotFoundFailure)`.
  - [x] Toutes enveloppées : `on HiveError`/erreur d'accès → `Left(CacheFailure)` ; **zéro** `catch(_){}`.
- [x] **T4. Lectures locales : `getById`, `getAll`, `watchAll` + décodage défensif** (AC: 5, 6, 8, 9)
  - [x] `_decode(id, map)` défensif : `fromMapSafe` → `null` écarté + loggé, jamais throw (miroir E5-1 `_decode`).
  - [x] `_isVisible(map) = map['is_deleted'] == false` appliqué **cohéremment** get/getAll/watch.
  - [x] `getById` absent → `Left(NotFoundFailure)` ; box vide → `Right([])`.
  - [x] `watchAll` : seed immédiat + `box.watch()` → `Stream<List<T>>` nu (visibles + décodés + tri stable par `id`).
- [x] **T5. `FirestoreZRemoteStore<T>`** (AC: 11, 12)
  - [x] Classe dans `lib/src/data/firestore_z_remote_store.dart` implémentant `ZRemoteStore<T>`, **déléguant** à un `FirebaseZRepositoryImpl<T>` (composition, pas d'héritage) : `push→save`, `remoteDelete→softDelete`, `pull→getAll`, `watchAll→watchAll`.
  - [x] Dartdoc : fire-and-forget best-effort ; orchestration/merge/débounce = E5-4 (frontière explicite) ; isolation Firestore héritée d'E5-1.
- [x] **T6. Barrel + pubspec** (AC: 3, 14)
  - [x] Exporter `HiveZLocalStore`, `FirestoreZRemoteStore` depuis `lib/zcrud_firestore.dart`.
  - [x] Ajouter `hive`/`hive_flutter` au **seul** `packages/zcrud_firestore/pubspec.yaml` ; dev-dep test Hive.
  - [x] `melos bootstrap` + `dart pub get --dry-run` (gate FR-25) verts.
- [x] **T7. Tests** (AC: tous)
  - [x] Hive en tmpdir (`Hive.init(Directory.systemTemp...)` + `tearDown` de nettoyage) **ou** `hive_test`/`setUpTestHive()`.
  - [x] Local : round-trip put/getById (AC4), 1 corrompu parmi N → N-1 sans throw (AC5), soft-delete/restore cohérent get/getAll/watch + doc sans `is_deleted` exclu de façon cohérente (AC6), invariant clé↔corps + matérialisation éphémère (AC7), `watchAll` émet put puis softDelete (AC8), erreur d'accès → `Left(CacheFailure)` + absent → `NotFoundFailure` + vide → `[]` (AC9), isolation signatures (AC10).
  - [x] Remote : round-trip push/pull via `fake_cloud_firestore` (AC11), délégation soft-delete/watch (AC11/12).
  - [x] Gate : `zcrud_core` sans Hive/Firebase (AC3), aucun symbole `hive`/`cloud_firestore` en signature publique (AC10/12).
- [x] **T8. Documentation** (AC: 12, 13)
  - [x] Dartdoc des 2 ports + 2 adaptateurs : rôle, sémantique fire-and-forget, invariant clé↔corps, décodage défensif, et **frontière E5-2 vs E5-3 (merge LWW) vs E5-4 (orchestrateur)**.

## Dev Notes

### Contexte architectural (à respecter absolument)

- **AD-5 (domaine backend-agnostique).** *« les ports `ZRepository<T>`, `ZLocalStore`, `ZRemoteStore`, `ZQuery`/`DataRequest`, `ZDataState` vivent dans `zcrud_core` sans type backend. Les adapters concrets (Firestore, Hive) vivent dans `zcrud_firestore`. »* Aucun `Box`/`HiveObject`/`Timestamp`/`Filter` ne traverse un port. [Source: architecture.md#AD-5, lignes 79-80]
- **AD-9 (offline-first).** *« patron offline-first = store local source de vérité + distant fire-and-forget, merge Last-Write-Wins sur `updatedAt`, soft-delete `is_deleted` (hors-entité standardisé `ZSyncMeta`), cascade bornée. `ZSyncOrchestrator` sépare le quand du comment. »* **E5-2 = les deux moitiés (local + distant)** ; le **merge LWW + cascade + orchestrateur = E5-3/E5-4**. [Source: architecture.md#AD-9, ligne 100]
- **AD-10 (désérialisation défensive).** Une entrée de cache absente/corrompue ne fait **jamais** échouer le parent : décodage par la voie tolérante (`fromMapSafe → null`), entrée écartée + loggée. [Source: architecture.md#AD-10]
- **AD-11 (erreurs).** Contrat store → `ZResult<T> = Either<ZFailure,T>` ; `ZResult<Unit>` pour void ; **flux nus** `Stream<List<T>>`. Local = **cache** → `CacheFailure` ; distant → `ServerFailure`. Jamais `catch(_){}` ; `null ≠ erreur`. [Source: architecture.md#AD-11]
- **AD-14.** Invariant de matérialisation de l'éphémère porté par le **store/repository**, jamais par l'entité. [Source: z_entity.dart ; architecture.md#AD-14]
- **AD-16.** Soft-delete `is_deleted` **hors-entité** standardisé (`ZSyncMeta`, `updated_at`/`is_deleted`, ISO-8601). [Source: z_sync_meta.dart]

### Signatures EXACTES à réutiliser / respecter (citées depuis le disque)

**`ZEntity`** (`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart`) — base des deux ports :
```
abstract class ZEntity {
  const ZEntity();
  String? get id;              // opaque, nullable = éphémère
  bool get isEphemeral => id == null;
}
```

**`ZSyncMeta`** (`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`) — méta hors-entité à fusionner :
```
class ZSyncMeta {
  const ZSyncMeta({this.updatedAt, this.isDeleted = false});
  final DateTime? updatedAt;   // clé LWW (E5-3), ISO-8601 en persistance
  final bool isDeleted;        // soft-delete
  factory ZSyncMeta.fromJson(Map<String, dynamic> json);   // DÉFENSIF, ne throw jamais
  Map<String, dynamic> toJson(); // {'updated_at': iso|null, 'is_deleted': bool}
}
```
> Clés de persistance : `'updated_at'`, `'is_deleted'` (snake_case). `updated_at` = ISO-8601 String, **jamais** `Timestamp` (AD-5).

**Port de référence `ZRepository<T>`** (`z_repository.dart`) — **modèle de style** pour les nouveaux ports (résultats `ZResult`, flux nus, dartdoc invariants) : `watchAll()`, `watch(req)`, `getAll({request})`, `getById(id)`, `save(item)`, `softDelete(id)`, `restore(id)`, `count()`, `dispose()`. **Ne pas modifier ce port.** [Source: z_repository.dart]

**Registre / codec** (`zcrud_registry.dart`) — encodage via `encode(kind, value)` / `codecFor(kind).toMap(value)` ; `decode` est **STRICT** (throw sur map corrompue). La voie **défensive** vient de `ZModelAdapter.fromMapSafe` (`packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart:63`) → l'adaptateur Hive **injecte** un `fromMapSafe` comme le fait E5-1 (`FirebaseZRepositoryImpl` constructeur `fromMapSafe:`). [Source: zcrud_registry.dart ; z_model_adapter.dart]

### Réutilisation d'E5-1 (à imiter, pas réinventer)

`FirebaseZRepositoryImpl<T>` (`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart`) fournit le **patron** exact à répliquer côté local et à **déléguer** côté distant :
- Constructeur avec `fromMapSafe: T? Function(Map<String,dynamic>)?` + `logger: ZFirestoreLog?` (no-op par défaut `_noopLog`). **Réutiliser le même typedef de log** (le partager, ou un équivalent local — il n'existe **pas** de port `ZLogger` dans `zcrud_core` ; ne pas en inventer un ici, hors périmètre).
- `_encode(value)` fusionne `ZSyncMeta(updatedAt: now, isDeleted:false).toJson()` + écrit le corps `id` (`_kId = 'id'`).
- `_decode(id, data)` : `fromMapSafe` s'il existe, sinon `try { fromMap } catch → null` ; document `null` **écarté + loggé**, jamais throw.
- `_isVisible(data) = data['is_deleted'] == false` appliqué **cohéremment** `getById` **et** `getAll`/`watch` (correction MAJEUR-2).
- Invariant **corps `id`** (`map['id'] == key`) rendu exécutoire par `save`/`_encode` (correction MAJEUR-1).

> **`FirestoreZRemoteStore<T>` = composition** (contient un `FirebaseZRepositoryImpl<T>`), **pas** héritage — l'héritage de classes sérialisées est rejeté (AD-4) et la composition garde le port distant mince.

### Learnings E5-1 à ABSORBER (non-négociables)

1. **Le fake/test ne doit pas masquer la sémantique prod.** Les ACs de test **exercent les cas limites RÉELS** : entrée Hive corrompue (AC5 → N-1), clé absente (AC9 → `NotFoundFailure`), type inattendu (AC5), doc sans `is_deleted` (AC6 → exclusion cohérente). Ne pas se contenter d'un seed « propre » qui garantit toujours des données bien formées (piège MAJEUR-1/MAJEUR-2 d'E5-1).
2. **Invariant zcrud-native — corps `id` toujours écrit** (AC7) et **cohérence local/remote** sur la clé + sur `is_deleted`/`updated_at`. Le local (`box.put(id, map['id']==id)`) et le distant (E5-1) partagent la MÊME convention → un même agrégat a la même identité et le même drapeau de suppression des deux côtés (pré-requis du merge E5-3).

### Choix Hive & sérialisation

- **Version** : `hive: ^2.2.3` + `hive_flutter: ^1.1.0` — conforme à la Stack de l'architecture (*« hive (ZLocalStore par défaut) | ^2.x »*, [Source: architecture.md ligne 165]). *(Alternative `hive_ce` non retenue : l'architecture fige `hive ^2.x`.)*
- **Stockage sans TypeAdapter** : stocker le **JSON de l'entité** (map sérialisée par le codec, ou `jsonEncode` en `Box<String>`) keyé par `id` — **pas** de `TypeAdapter`/codegen Hive (évite un couplage codegen supplémentaire et reste « JSON » comme dit l'épic : *« store local source de vérité (JSON) »*). Le décodage relit la map et passe par `_decode` défensif.
- **Init/box** : la box est ouverte via un `factory` (`HiveZLocalStore.openBox(kind, ...)`) en prod (`Hive.initFlutter()` côté app), et **injectée** directement en test (box ouverte sur tmpdir) pour la testabilité sans binding Flutter.

### Frontière de story (ne PAS déborder)

- **E5-2 (cette story)** : ports `ZLocalStore`/`ZRemoteStore` (création) + `HiveZLocalStore` + `FirestoreZRemoteStore` + décodage défensif + soft-delete hors-entité + isolation.
- **E5-3** : patron offline-first LWW (merge `updatedAt`) + cascade bornée ≤ 450 + `is_deleted` standardisé composé. **Hors périmètre** (E5-2 ne fait **aucun merge**).
- **E5-4** : `ZSyncOrchestrator` (débounce ~400 ms, best-effort, `Right(unit)` si déconnecté, échec partiel toléré). **Hors périmètre.**
- **`CloudStorageRepository`** (fichiers, E3-3c / Firebase Storage) : **hors périmètre** (séparé).

### Project Structure Notes

- Nouveaux (core) : `packages/zcrud_core/lib/src/domain/ports/z_local_store.dart`, `.../z_remote_store.dart` ; exports au barrel `zcrud_core.dart`.
- Nouveaux (firestore) : `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart`, `.../firestore_z_remote_store.dart` ; exports au barrel `zcrud_firestore.dart` (conserver les exports existants `firebase_z_repository_impl.dart`, `z_firestore_api.dart`).
- Tests : `packages/zcrud_firestore/test/hive_z_local_store_test.dart`, `.../firestore_z_remote_store_test.dart`.
- `pubspec.yaml` de `zcrud_firestore` : ajouter `hive`, `hive_flutter` ; dev-dep test Hive. **Ne rien ajouter à `zcrud_core`.**
- Nommage : types publics préfixés `Z` (ports) / descriptifs (`HiveZLocalStore`, `FirestoreZRemoteStore`) ; fichiers snake_case ; impl sous `lib/src/data/`.

### Testing standards

- Framework : `flutter_test` + Hive sur tmpdir (`Hive.init(dir)` + nettoyage `tearDown`) **ou** `hive_test` (`setUpTestHive`/`tearDownTestHive`) ; `fake_cloud_firestore` pour le remote (réutiliser le harnais E5-1).
- Couverture obligatoire (mappée aux ACs) : round-trip local (AC4), défensif N-1 (AC5), soft-delete cohérent + doc sans `is_deleted` (AC6), invariant clé↔corps + éphémère (AC7), `watchAll` émet (AC8), `CacheFailure`/`NotFoundFailure`/`[]` (AC9), isolation signatures Hive (AC10), round-trip remote + délégation (AC11/12), `zcrud_core` sans Hive/Firebase (AC3), frontière documentée (AC13).
- Gates CI (E1-3/E2-10) : anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation, graphe `CORE OUT=0` — **verts avant `review`**.

### References

- [Source: architecture.md#AD-5 (lignes 79-80)] ports `ZLocalStore`/`ZRemoteStore` neutres dans zcrud_core ; adapters Firestore/Hive dans zcrud_firestore.
- [Source: architecture.md#AD-9 (ligne 100)] offline-first : local source de vérité + distant fire-and-forget, merge LWW `updatedAt`, soft-delete hors-entité, orchestrateur (quand/comment).
- [Source: architecture.md#AD-10] désérialisation défensive.
- [Source: architecture.md#AD-11] `Either<ZFailure,T>`, flux nus, hiérarchie ZFailure (CacheFailure pour le local).
- [Source: architecture.md ligne 165] Stack : `hive ^2.x` (ZLocalStore par défaut).
- [Source: architecture.md ligne 250] `ZLocalStore` alternatifs (Isar/Drift/SQLite) — port prévu, impl différée ; Hive-JSON par défaut.
- [Source: epics.md#E5 Story E5-2] store local source de vérité (JSON) ; abstraction permettant Isar/Drift ultérieur (déféré) (AD-5).
- [Source: stories/e2-2-ports-donnees.md#Frontière de portée] `ZLocalStore`/`ZRemoteStore` **différés à E5** (ne sont PAS définis en E2-2).
- [Source: stories/e5-1-firebase-zrepository-impl.md] patron `_encode`/`_decode`/`_isVisible`, invariant corps `id`, injection `fromMapSafe`/`logger`, isolation.
- [Source: code-review-e5-1.md#MAJEUR-1, #MAJEUR-2] learnings : invariant corps `id` ; cohérence `_isVisible` get/getAll/watch ; le seed « propre » masque la sémantique prod.
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart] style de port à imiter (résultats `ZResult`, flux nus).
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart] `ZSyncMeta` (updated_at/is_deleted, ISO-8601, défensif).
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_entity.dart] `ZEntity.id`/`isEphemeral`.
- [Source: packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart:63] `fromMapSafe` (voie défensive AD-10).
- [Source: packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart] adaptateur E5-1 à déléguer (remote) et à imiter (local).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story)

### Debug Log References

- `dart run melos run generate` → RC=0 (zcrud_generator SUCCESS ; aucun `@ZcrudModel` de test ajouté).
- `dart run melos run analyze` → RC=0, **0 issue** sur les 10 packages Flutter/Dart analysés.
- `flutter test` (zcrud_firestore) → **55 tests** OK (dont 24 nouveaux E5-2 : 20 Hive + 4 gates/isolation + remote).
- `flutter test` (zcrud_core) → **562 tests** OK (aucune régression sur les ports ajoutés au barrel).
- `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, **CORE OUT=0 OK** ; `melos list` = **14**.
- `dart run melos run verify` → RC=0 (graph, gate:melos, gate:reflectable, gate:secrets, gate:codegen, gate:compat, verify:serialization — tous verts).

**Remédiation code-review (2026-07-10) — rejeu vert réel :**
- `dart run melos run analyze` → RC=0, **0 issue** (14 packages).
- `flutter test` (zcrud_firestore) → **58 tests** OK (dont 3 nouveaux : close→reopen disque MEDIUM-2 + 2 anti-fuite `onCancel` MEDIUM-1) ; test `openBox` désormais synchronisé sur `closedForTest` (plus de `sleep(100ms)`).
- `flutter test --plain-name MAJEUR` (firebase E5-1) → OK (parité `onCancel` firestore ne régresse PAS les tests watch/dispose d'E5-1).
- `dart run melos run verify` → RC=0, **CORE OUT=0 OK**, ACYCLIQUE OK, `melos list`=14.

### Completion Notes List

- **Ports neutres créés** (AC1/AC2/AC3) : `ZLocalStore<T>` (watchAll/getAll/getById/put/softDelete/restore/clear/dispose) et `ZRemoteStore<T>` (push/remoteDelete/pull/watchAll/dispose) dans `zcrud_core`, Dart pur (import `dartz show Unit` + contrats internes uniquement). Aucun ajout de dépendance à `zcrud_core/pubspec.yaml` (gate `CORE OUT=0` reste vert ; test AC3 le prouve).
- **`HiveZLocalStore<T>`** (AC4-AC10) : store local source de vérité, stockage **JSON** (`jsonEncode`, box par kind `zcrud_<kind>`, sans TypeAdapter). `_encode` fusionne `ZSyncMeta` + écrit **toujours** le corps `id` == clé (invariant MAJEUR-1). `_rawMap`/`_decodeEntity` défensifs (AD-10) : entrée non-String / JSON tronqué / JSON non-objet / champ manquant → écartés + loggés, jamais de throw (test : 3 corrompus RÉELS parmi 5 → 2 conservés). `_isVisible(map)=map['is_deleted']==false` appliqué **cohéremment** get/getAll/watch (MAJEUR-2 ; entrée sans `is_deleted` exclue partout). Soft-delete par drapeau (jamais `box.delete`). `_guard` → `Left(CacheFailure)` sur `HiveError`, `NotFoundFailure` sur clé absente, `[]` sur box vide ; zéro `catch(_){}`.
- **`FirestoreZRemoteStore<T>`** (AC11/AC12) : **composition** sur `FirebaseZRepositoryImpl<T>` d'E5-1 (`push→save`, `remoteDelete→softDelete`, `pull→getAll`, `watchAll→watchAll`) ; n'importe **même pas** `cloud_firestore` (test le prouve). Fire-and-forget documenté ; orchestration/merge = E5-3/E5-4 (frontière explicite en dartdoc).
- **Isolation (AC10)** : couture DI `Box<dynamic>` admise au **constructeur** (indent 4) et `openBox` factory sans exposer Hive ; gate de signatures publiques (miroir E5-1 AC13) prouve 0 symbole Hive dans une déclaration de membre public exporté.
- **Frontière E5-2 respectée** : aucune méthode `sync()`/`merge()`, aucun débounce, aucune cascade ≤450, aucun LWW — documenté en dartdoc des 2 ports + 2 adaptateurs (AC13).
- **Ambiguïtés (6) confirmées** : #1 ports créés en E5-2 ✓ ; #2 composition (pas alias) ✓ ; #3 soft-delete (pas hard) ✓ ; #4 typedef log local `ZLocalStoreLog` (pas de port ZLogger) ✓ ; #5 `hive ^2.2.3`+`hive_flutter ^1.1.0` ✓ ; #6 générique + codec/`fromMapSafe` injecté ✓.
- **Note test** : `dispose()` étant `void` (contrat de port), la fermeture d'une box **possédée** (`openBox`) est fire-and-forget. Depuis la remédiation, `dispose()` capture le Future de fermeture dans `closedForTest` (`@visibleForTesting`) : le test `openBox` s'y synchronise DÉTERMINISTIQUEMENT (plus de `sleep(100ms)` fragile). Aucune incidence prod (l'app dispose au shutdown).

- **Remédiation code-review E5-2 (2026-07-10)** — 5 findings traités, périmètre limité à `packages/zcrud_firestore/` (ports `zcrud_core` gelés, non touchés) :
  - **MEDIUM-1 (fuite `watchAll`)** — CORRIGÉ dans **hive_z_local_store.dart** ET (parité E5-1) **firebase_z_repository_impl.dart** : ajout d'un `onCancel` au `StreamController` qui annule l'abonnement source (`box.watch()` / `snapshots()`), le retire de `_subs`, retire le contrôleur de `_controllers` et le ferme — libération à l'annulation du flux, plus seulement au `dispose()`. Idempotent avec `dispose()`. 2 tests anti-fuite ajoutés (getters `@visibleForTesting activeSourceSubscriptions`/`activeStreamControllers` : après `cancel()` → 0 ; 5 cycles subscribe/cancel → 0).
  - **MEDIUM-2 (persistance disque)** — CORRIGÉ : test `put → box.close() → réouverture même nom → getById/getAll` prouve le round-trip JSON **persistant** réel (relecture du fichier `.hive`), pas seulement le cache en-session.
  - **LOW-1 (exception dans le callback listener)** — CORRIGÉ (hive + parité firestore) : le corps du `listen` est enveloppé d'un `try/catch` qui pousse `controller.addError(_toFailure(...))` (miroir du `onError`).
  - **LOW-2 (`dispose():void` non attendable)** — DOCUMENTÉ en dartdoc (fermeture fire-and-forget) + `sleep(100ms)` du test remplacé par une attente déterministe sur `closedForTest`. Contrat de port `void` inchangé.
  - **LOW-3 (résurrection soft-delete par `put`)** — DOCUMENTÉ en dartdoc de `put`/`_encode` (`is_deleted` forcé `false` → re-`put` ressuscite ; cohérent E5-1, merge LWW = E5-3).

### File List

**Créés — `zcrud_core`**
- `packages/zcrud_core/lib/src/domain/ports/z_local_store.dart`
- `packages/zcrud_core/lib/src/domain/ports/z_remote_store.dart`

**Modifiés — `zcrud_core`**
- `packages/zcrud_core/lib/zcrud_core.dart` (exports des 2 ports, ordre alpha)

**Créés — `zcrud_firestore`**
- `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart`
- `packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart`
- `packages/zcrud_firestore/test/hive_z_local_store_test.dart`
- `packages/zcrud_firestore/test/firestore_z_remote_store_test.dart`

**Modifiés — `zcrud_firestore`**
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (exports des 2 adaptateurs, ordre alpha)
- `packages/zcrud_firestore/pubspec.yaml` (ajout `hive: ^2.2.3` + `hive_flutter: ^1.1.0`)

**Modifiés — `zcrud_firestore` (remédiation code-review 2026-07-10)**
- `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart` (MEDIUM-1 `onCancel` + LOW-1 try/catch listener + LOW-2 `closedForTest`/dartdoc dispose + LOW-3 dartdoc `put`/`_encode` + getters `@visibleForTesting` anti-fuite)
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (MEDIUM-1 parité E5-1 : `onCancel` + LOW-1 try/catch listener dans `_watchQuery`)
- `packages/zcrud_firestore/test/hive_z_local_store_test.dart` (tests MEDIUM-1 anti-fuite + MEDIUM-2 close/reopen disque + LOW-2 attente déterministe)

**Modifiés — story**
- `_bmad-output/implementation-artifacts/stories/e5-2-zlocalstore-zremotestore.md` (frontmatter baseline_commit, Status, tâches, Dev Agent Record)

## Questions / Ambiguïtés détectées (pour dev-story / code-review)

1. **Les ports n'existaient pas (hypothèse d'entrée corrigée).** La consigne initiale supposait `ZLocalStore`/`ZRemoteStore` « définis en E2-2 » ; **vérification disque** : ils **n'existent pas** (E2-2 les a explicitement différés à E5). → **E5-2 les CRÉE** dans `zcrud_core`. Résolu dans les AC1/AC2, mais à confirmer que la création des ports appartient bien à E5-2 (et non à un E5-0 séparé). *(Recommandation : oui — canonique §7 « introduits AVEC leur adaptateur ».)*
2. **Forme de `ZRemoteStore` vs délégation à `FirebaseZRepositoryImpl`.** Choix retenu : un port distant **mince** (`push`/`remoteDelete`/`pull`/`watchAll`) **implémenté par composition** sur l'adaptateur `ZRepository` d'E5-1. Alternative rejetée : faire de `ZRemoteStore` un simple alias de `ZRepository` (perdrait la sémantique fire-and-forget distincte). À valider en dev-story.
3. **Suppression locale : soft (drapeau) vs hard (`box.delete`).** Retenu : **soft-delete** (drapeau `is_deleted`, pas de suppression physique) pour permettre la propagation au distant en E5-3. Une purge physique (`clear`/compaction) serait une opération distincte E5-3/E5-4. À confirmer.
4. **Pas de port `ZLogger` dans `zcrud_core`.** E5-1 utilise un typedef de log **local** au package (`ZFirestoreLog` + `_noopLog`). E5-2 réutilise/partage ce patron **sans** introduire de port `ZLogger` dans le cœur (hors périmètre). À confirmer (un `ZLogger` core serait une story d'infra séparée).
5. **Version Hive : `hive ^2.x` (architecture) vs `hive_ce` (fork communautaire).** Retenu : `hive ^2.2.3` + `hive_flutter ^1.1.0` (fidèle à la Stack figée). Si l'équipe préfère `hive_ce` (maintenu), c'est un changement de Stack à acter au niveau architecture — **non** décidé unilatéralement ici.
6. **Généricité `<T extends ZEntity>` + codec injecté** (vs stores orientés `Map` bruts). Retenu : générique comme `ZRepository`, codec + `fromMapSafe` injectés (cohérence E5-1). À confirmer.

<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->
