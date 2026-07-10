# Story 5.1: FirebaseZRepositoryImpl&lt;T&gt; + traduction DataRequest→Filter

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a intégrateur backend de zcrud,
I want un adaptateur Firestore `FirebaseZRepositoryImpl<T>` qui implémente le port neutre `ZRepository<T>` de `zcrud_core` (withConverter, streams nus, count, softDelete/restore, traduction `ZDataRequest → Query` avec curseur `startAfter`),
so that les consommateurs (E7 DODLP, E8 lex_douane) persistent leurs agrégats sur Cloud Firestore **sans jamais** voir fuiter un type `cloud_firestore` dans le domaine, avec les **bugs historiques des 3 apps corrigés** (réassignation de `limit`, `catch(_){}`, `null` traité comme erreur) et une désérialisation **défensive** qui ne casse pas sur un document corrompu.

## Contexte épic (E5)

**E5 — Backend Firestore & offline-first (`zcrud_firestore`).** Objectif : adaptateur Firestore débogué + patron offline-first. Couvre FR-12/FR-13. AD-5/AD-9/AD-11.
Phase : **E5-1/E5-2 = MVP** (repo Firestore + `ZLocalStore`, requis par E7/E8) ; **E5-3/E5-4 = v1.x** (offline-first LWW + orchestrateur ; consommateur = donnée d'étude E9).

Cette story est **la première de l'epic E5**. Elle transforme le squelette `zcrud_firestore` (marqueur `ZFirestoreApi` posé en E1-2) en un adaptateur réel branché sur le port neutre gelé en E2-2.

## Acceptance Criteria

1. **withConverter round-trip.** `FirebaseZRepositoryImpl<T>` construit sa `CollectionReference<T>` via `collection.withConverter<T>(fromFirestore:…, toFirestore:…)` où `fromFirestore` délègue au décodeur du modèle (codec/registre) et `toFirestore` à l'encodeur. Un `save(item)` suivi d'un `getById(id)` restitue une entité **égale** (round-trip fidèle, `id` inclus). *(AD-5, AD-3)*

2. **Streams NUS.** `watchAll()` et `watch(request)` retournent des `Stream<List<T>>` **nus** — jamais enveloppés dans un `Either` (AD-11). Le flux émet un seed immédiat puis les mutations ; les documents **soft-deleted** (`is_deleted == true`) sont **exclus** des lectures/flux.

3. **`getAll` filtré/trié/paginé.** `getAll({request})` applique `request` (filtres + tri + curseur + limit) et retourne `Right(List<T>)` ; exclut les soft-deleted. `getAll()` sans requête retourne tout le non-soft-deleted.

4. **`count`.** `count({request})` retourne `Right(int)` en s'appuyant sur l'agrégation Firestore (`AggregateQuery.count()`), en appliquant les mêmes filtres que `getAll` et en excluant les soft-deleted.

5. **softDelete / restore hors-entité.** `softDelete(id)` bascule `is_deleted = true` et `restore(id)` bascule `is_deleted = false` dans les **métadonnées hors-entité** (`ZSyncMeta`, clés `is_deleted`/`updated_at`), **sans** toucher aux champs métier de l'entité. Retour `Right(unit)`. Un `id` inexistant → `Left(NotFoundFailure)`.

6. **Traduction `ZDataRequest → Query` fidèle.** La traduction couvre : chaque `ZFilter(field, op, value)` → `where(field, …)` (mapping complet des `ZFilterOp`), chaque `ZSort(field, direction)` → `orderBy(field, descending:)`, `limit` → `.limit(n)`, `startAfter` → `.startAfter(cursor.values)`. La `Query` est construite par **chaînage immuable** (voir AC7). Une requête vide (`ZDataRequest()`) produit une `Query` sans clause (tout, non paginé).

7. **BUG HISTORIQUE #1 corrigé — réassignation de `limit`/immutabilité de `Query`.** La construction de la requête **n'ignore jamais** une clause : `Query` étant **immuable**, chaque `where/orderBy/limit/startAfter` est **ré-affecté** (`query = query.where(...)`). Un test prouve qu'une requête `filtre + tri + limit` produit bien les 3 clauses (aucune perdue par réassignation manquée — le bug des 3 apps).

8. **BUG HISTORIQUE #2 corrigé — batch/transaction cohérents.** Toute opération multi-écriture (ex. soft-delete en cascade si applicable au périmètre, ou write+meta) passe par un `WriteBatch`/`runTransaction` **atomique et committé** ; aucune écriture partielle laissée non-commit. *(La cascade bornée ≤ 450 écritures est spécifiée AD-9 mais reste E5-3 ; ici on garantit seulement la cohérence commit/rollback des écritures effectuées.)*

9. **BUG HISTORIQUE #3 corrigé — JAMAIS `catch(_){}`.** Aucun `try`/`catch` nu ni `catch(_){}` silencieux. Toute opération Firestore est enveloppée : `on FirebaseException catch (e)` → `Left(ServerFailure(e.message ...))` ; les autres erreurs sont mappées vers un `ZFailure` typé approprié. Un test injecte une `FirebaseException` et vérifie `Left(ServerFailure)` (jamais une exception qui remonte, jamais un `Left` muet). *(AD-11)*

10. **BUG HISTORIQUE #4 corrigé — `null ≠ erreur`.** Un document **absent** (`getById` sur un `id` inconnu, ou `snapshot.exists == false`) retourne `Left(NotFoundFailure(id:…, entity:…))` — **pas** une exception, **pas** un `ServerFailure`. Un flux sur une collection vide émet `[]` (liste vide), **pas** une erreur. *(AD-11)*

11. **Décodage DÉFENSIF (absorbe E2-6 MEDIUM-1).** Un document **corrompu/tronqué** (champ manquant, enum inconnu, type invalide) **ne casse pas** la lecture : le décodage passe par la **voie défensive** du modèle (`fromMapSafe`/`decodeSafe → null`), et un document qui échoue au décodage est **filtré** du résultat (loggé via le port `ZLogger`) sans faire échouer la page/le flux entier. Un test avec 1 document corrompu parmi N valides retourne N-1 entités **sans throw**. *(AD-10 ; câble la frontière défensive recommandée par le code-review E2-6.)*

12. **Tie-break `id` garanti côté adaptateur (absorbe E4-3 LOW-3).** Toute `Query` triée termine par un `orderBy(FieldPath.documentId)` (ou le champ `id` logique) **implicite** ajouté par l'adaptateur, garantissant un ordre **total et stable** aux clés de tri égales, cohérent avec le contrat `ZCursor` (départage par `id`). Le curseur `startAfter(cursor.values)` inclut la valeur d'`id` en dernière position quand un tie-break est requis. Un test avec deux lignes à clé de tri égale prouve un ordre déterministe et une pagination sans doublon/saut à la frontière.

13. **ISOLATION AD-5 — aucun type Firestore ne fuit.** Aucune signature publique de `FirebaseZRepositoryImpl<T>` (ni type de retour, ni paramètre exposé hors `zcrud_firestore`) n'expose `Timestamp`, `Filter`, `Query`, `DocumentSnapshot`, `CollectionReference`, `FirebaseException` ni aucun symbole `cloud_firestore`. Les retours restent `ZResult<…>` / `Stream<List<T>>` **nus**. Un test/gate vérifie qu'aucun symbole `cloud_firestore` n'apparaît dans une signature publique du package.

14. **`zcrud_core` ne tire PAS `cloud_firestore`.** `cloud_firestore`/`firebase_core` sont ajoutés au **SEUL** `pubspec.yaml` de `zcrud_firestore`. Un contrôle (grep de dépendances / `pub deps`) prouve que `zcrud_core` ne dépend d'aucun paquet Firebase (invariant AD-1/AD-5 déjà établi, re-vérifié ici). Le `dry-run` de compat (FR-25) reste vert.

15. **Recherche accent-insensible — limite documentée (absorbe E4-3 LOW-2).** Firestore ne supporte pas nativement la recherche plein-texte accent-insensible ; le comportement de `ZDataRequest.search` côté adaptateur est **documenté explicitement** (table de pliage précomposée, aucune normalisation NFD ; option d'un champ de recherche normalisé pré-calculé). Aucune exigence d'implémenter la recherche full-text ici : la limite est **consignée** pour E4/E7, pas silencieusement ignorée.

16. **Vérif verte.** `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0 ; gates CI (anti-`reflectable`, scan de secrets, codegen) verts.

## Tasks / Subtasks

- [x] **T1. Dépendances & barrel** (AC: 14, 16)
  - [x] Ajouter `cloud_firestore` (firestore ^6) et `firebase_core` (^4) au **seul** `packages/zcrud_firestore/pubspec.yaml` ; ne rien ajouter à `zcrud_core`.
  - [x] Exporter `FirebaseZRepositoryImpl` (+ types de config nécessaires) depuis `lib/zcrud_firestore.dart` (barrel) ; conserver `ZFirestoreApi` (marqueur AD-1).
  - [x] `melos bootstrap` + `dart pub get --dry-run` (gate FR-25) verts.
- [x] **T2. Squelette `FirebaseZRepositoryImpl<T extends ZEntity>`** (AC: 1, 13)
  - [x] Classe générique dans `lib/src/data/firebase_z_repository_impl.dart` implémentant `ZRepository<T>`.
  - [x] Injection : `FirebaseFirestore` instance, `String collectionPath`, `String kind` (+ `ZcrudRegistry` ou codec `fromMap/toMap`), `ZLogger`, sélecteur d'`id` logique, accès aux métadonnées `ZSyncMeta`.
  - [x] `withConverter<T>` : `fromFirestore` → décodage défensif (T11), `toFirestore` → `encode`.
  - [x] Tous les types Firestore restent **privés** au fichier/package (AC13).
- [x] **T3. Traducteur `ZDataRequest → Query`** (AC: 3, 6, 7, 12)
  - [x] Fonction/‑classe privée `_buildQuery(Query base, ZDataRequest req)` construite par **chaînage immuable** (réaffectation systématique — corrige bug #1).
  - [x] Mapping exhaustif `ZFilterOp → where` : `eq→isEqualTo`, `neq→isNotEqualTo`, `lt→isLessThan`, `lte→isLessThanOrEqualTo`, `gt→isGreaterThan`, `gte→isGreaterThanOrEqualTo`, `contains→arrayContains` (ou substring documenté), `isIn→whereIn`, `isNull→isEqualTo:null`.
  - [x] `ZSort → orderBy(field, descending: dir==desc)` ; **ajout systématique** du tie-break `orderBy(documentId)` final (T12).
  - [x] `startAfter(cursor.values)` + `limit(n)` chaînés en dernier ; exclusion `is_deleted != true`.
- [x] **T4. Lectures : `watchAll`, `watch`, `getAll`, `getById`, `count`** (AC: 2, 3, 4, 10, 11)
  - [x] `watchAll`/`watch` : `snapshots().map((s) => …)` → `Stream<List<T>>` nu, seed immédiat, exclusion soft-deleted, décodage défensif.
  - [x] `getById` : `snapshot.exists == false` → `Left(NotFoundFailure)` (T10) ; sinon `Right(T)`.
  - [x] `getAll` : `Right(List<T>)` via `_buildQuery` ; `count` via `AggregateQuery.count()`.
- [x] **T5. Écritures : `save`, `softDelete`, `restore`, `dispose`** (AC: 1, 5, 8, 9, 10)
  - [x] `save` : matérialisation de l'éphémère (attribution d'`id` opaque si `isEphemeral`), écriture atomique (entité + `ZSyncMeta.updated_at`), rejet cible manquante → `Left(DomainFailure)`.
  - [x] `softDelete`/`restore` : bascule `is_deleted` hors-entité via batch/transaction cohérent (T8) ; `id` inconnu → `Left(NotFoundFailure)`.
  - [x] `dispose` : ferme les abonnements/`StreamController`.
- [x] **T6. Enveloppe d'erreurs unique** (AC: 9, 10, 11)
  - [x] Helper `_guard<R>(Future<R> Function())` : `on FirebaseException → Left(ServerFailure)`, `on Object → Left(...)` typé ; **zéro** `catch(_){}`.
  - [x] `null`/absent → `NotFoundFailure`/liste vide (jamais erreur).
- [x] **T7. Décodage défensif au niveau adaptateur** (AC: 11)
  - [x] Router le décodage document→T via la voie défensive (`fromMapSafe`/`decodeSafe → null`) ; document non décodable → **écarté** + log `ZLogger`, jamais throw. Consigner l'option `decodeSafe(kind, map)` additive sur `ZcrudRegistry` (frontière E2-6).
- [x] **T8. Tests** (AC: tous)
  - [x] `fake_cloud_firestore` (ou mock) : round-trip, DataRequest→Query fidèle (chaque op), tie-break/curseur, softDelete/restore, count, document corrompu (pas de crash), document absent (null≠erreur), `FirebaseException → ServerFailure`.
  - [x] Test/gate d'isolation : aucun symbole `cloud_firestore` dans une signature publique ; `zcrud_core` sans dépendance Firebase.
- [x] **T9. Documentation** (AC: 15)
  - [x] Dartdoc de l'adaptateur : mapping des ops, tie-break `id`, limite de recherche accent-insensible (précomposé, pas de NFD), frontière E5-1/E5-2/E5-3/E5-4.

## Dev Notes

### Contexte architectural (à respecter absolument)

- **AD-5 (domaine backend-agnostique).** Les ports `ZRepository<T>`, `ZDataRequest`/`ZFilter`/`ZSort`/`ZCursor`, `ZSyncMeta` vivent dans `zcrud_core` **sans type backend**. L'adaptateur concret vit **exclusivement** dans `zcrud_firestore`. Aucun `Timestamp`/`Filter`/`DocumentSnapshot`/`FirebaseException` ne traverse le port. [Source: architecture.md#AD-5]
- **AD-11 (erreurs).** Contrat repository → `ZResult<T> = Either<ZFailure, T>` ; `ZResult<Unit>` pour void ; **flux nus** `Stream<List<T>>`. Hiérarchie `ZFailure` : `DomainFailure`/`CacheFailure`/`NotFoundFailure`/`ServerFailure`. Jamais `try/catch` nu → toujours envelopper ; `null ≠ erreur`. [Source: architecture.md#AD-11]
- **AD-16 (curseur neutre).** Pagination par curseur `startAfter`/opaque exprimée dans `ZDataRequest`/`ZCursor` ; implémentation `startAfter(cursor.values)` dans l'adaptateur ; départage par `id`. [Source: architecture.md#AD-16 ; z_cursor.dart]
- **AD-9 (offline-first).** Soft-delete `is_deleted` **hors-entité** (`ZSyncMeta`), LWW sur `updated_at`. Ici on n'implémente que soft-delete/restore + write cohérente ; le merge LWW et l'orchestrateur sont E5-3/E5-4. [Source: architecture.md#AD-9]
- **AD-10 (désérialisation défensive).** Un champ absent/corrompu ne fait jamais échouer le parent. L'adaptateur doit router le décodage par la voie tolérante. [Source: architecture.md#AD-10]
- **AD-14.** Les invariants métier (matérialisation de l'éphémère) sont portés par le **repository**, jamais par l'entité. [Source: architecture.md#AD-14]

### Conception de `FirebaseZRepositoryImpl<T extends ZEntity>`

Implémente le port **déjà gelé** en E2-2 (`z_repository.dart`), signatures exactes à respecter :

```
Stream<List<T>> watchAll();
Stream<List<T>> watch(ZDataRequest request);
Future<ZResult<List<T>>> getAll({ZDataRequest? request});
Future<ZResult<T>> getById(String id);
Future<ZResult<T>> save(T item, {String? collectionId});
Future<ZResult<Unit>> softDelete(String id);
Future<ZResult<Unit>> restore(String id);
Future<ZResult<int>> count({ZDataRequest? request});
void dispose();
```

**withConverter (AC1) :** `firestore.collection(path).withConverter<T>(fromFirestore: (snap, _) => _decode(snap), toFirestore: (value, _) => _encode(value))`. `_decode` passe par la voie **défensive** (T11) ; l'`id` du document (`snap.id`) est injecté dans le map avant décodage (le doc Firestore ne stocke pas forcément `id` dans le corps). `_encode` = `registry.encode(kind, value)` (+ `ZSyncMeta.toJson()` fusionné).

**Injection :** l'adaptateur reçoit une `FirebaseFirestore` (pas de singleton statique — testabilité, cf. E2-3 registre instanciable), le `collectionPath`, le `kind` + le `ZcrudRegistry` (ou un couple `fromMap/toMap` typé), un `ZLogger` (port), et le mode de décodage (défensif par défaut).

### Table de traduction `ZDataRequest → Query` (AC6)

| Source neutre (`z_data_request.dart`) | Cible Firestore | Note |
|---|---|---|
| `ZFilterOp.eq` | `where(f, isEqualTo: v)` | |
| `ZFilterOp.neq` | `where(f, isNotEqualTo: v)` | |
| `ZFilterOp.lt/lte/gt/gte` | `isLessThan / isLessThanOrEqualTo / isGreaterThan / isGreaterThanOrEqualTo` | |
| `ZFilterOp.contains` | `arrayContains: v` (champ collection) ou substring documentée | limite Firestore : pas de `LIKE` |
| `ZFilterOp.isIn` | `whereIn: v` (v = `List`) | max 30 valeurs (limite Firestore, documenter) |
| `ZFilterOp.isNull` | `where(f, isEqualTo: null)` | |
| `ZSort(f, asc/desc)` | `orderBy(f, descending: dir==desc)` | + **tie-break `orderBy(documentId)`** final (AC12) |
| `ZDataRequest.limit` | `.limit(n)` | **réaffecté** (AC7) |
| `ZDataRequest.startAfter` | `.startAfter(cursor.values)` | `values` alignés positionnellement sur `sorts` + id en tie-break |
| exclusion soft-deleted | `where('is_deleted', isNotEqualTo: true)` (ou filtre applicatif si conflit d'index) | AC2 |

> **CRUCIAL (bug #1 / AC7).** `Query` est **immuable** en `cloud_firestore` : `q.where(...)` retourne une **nouvelle** `Query`. Le bug des 3 apps venait d'un `q.limit(n);` (ou `.where`) dont le retour n'était pas réaffecté → clause perdue. Le traducteur DOIT faire `q = q.where(...)` / `q = q.limit(...)` à chaque étape. Un test asserte que les 3 clauses coexistent.

### Bugs historiques (les 3 apps DODLP/IFFD/DLCFTI) — corrections explicites

1. **Réassignation de `limit`/clause perdue** → chaînage immuable réaffecté (AC7, T3).
2. **Batch/transaction incohérents** (écritures partielles non committées) → `WriteBatch`/`runTransaction` atomique committé (AC8, T5).
3. **`catch(_){}` silencieux** → enveloppe `_guard` unique, `FirebaseException → ServerFailure`, jamais avalé (AC9, T6).
4. **`null` traité comme erreur** (document absent levant/retournant `ServerFailure`) → `NotFoundFailure`/liste vide (AC10).

### Décodage défensif — frontière E2-6 MEDIUM-1 (ABSORBÉ)

Le code-review E2-6 a relevé que la voie défensive `fromMapSafe` du modèle **n'est pas atteignable via `ZcrudRegistry.decode`** (qui délègue au `fromMap` strict et **lève** sur map corrompue). Recommandation portée **ici** : E5-1 route le décodage document→T par la voie tolérante — soit en conservant une référence à l'adaptateur de codec exposant `fromMapSafe`, soit en ajoutant **additivement** un `decodeSafe(kind, map) → Object?` sur `ZcrudRegistry` (AD-10 additif, sans casser le contrat gelé E2-3). Un document non décodable est **écarté + loggé**, jamais propagé en throw (AC11). *Si l'ajout `decodeSafe` sur `ZcrudRegistry` est retenu, c'est une extension additive rétro-compatible — à valider en code-review.* [Source: code-review-e2-6.md#MEDIUM-1]

### Tie-break `id` — E4-3 LOW-3 (ABSORBÉ)

Le code-review E4-3 signale que la cohérence du raccord de pagination (repli in-memory ↔ backend) **dépend du tie-break `id`** : « à garantir côté adaptateur E5 (dernier `orderBy(id)`) ». → AC12/T3 : l'adaptateur ajoute **systématiquement** `orderBy(documentId)` en dernière clé d'ordre, cohérent avec `ZCursor` (départage `id`). [Source: code-review-e4-3.md#L-3 ; z_cursor.dart]

### Recherche accent-insensible — E4-3 LOW-2 (ABSORBÉ / documenté)

Firestore n'a pas de full-text/`LIKE` natif ni de pliage diacritique. Le pliage in-memory de E4-3 est **précomposé uniquement** (pas de normalisation NFD). Côté Firestore, `ZDataRequest.search` ne peut être servi qu'en préfixe/égalité ou via un champ normalisé pré-calculé. → **documenter la limite** (AC15/T9) sans l'implémenter dans E5-1. [Source: code-review-e4-3.md#L-2]

### Isolation Firebase — comment elle est PROUVÉE (AD-5)

1. **Dépendance** : `cloud_firestore`/`firebase_core` uniquement dans `packages/zcrud_firestore/pubspec.yaml` ; `zcrud_core` n'en dépend pas (grep `pub deps` / gate AD-1 déjà en place — AC14).
2. **Signatures** : toutes les méthodes publiques retournent `ZResult<…>`/`Stream<List<T>>` **nus** ; les types `cloud_firestore` (`Query`, `Timestamp`, `DocumentSnapshot`, `FirebaseException`, `Filter`) restent **locaux** (variables privées, params privés). Test/gate : aucun symbole `cloud_firestore` dans une signature exportée (AC13).
3. **Conversion des dates** : `updated_at` sérialisé/désérialisé en **ISO-8601 String** (jamais `Timestamp`) via `ZSyncMeta` — cohérent AD-5. Si des documents historiques stockent un `Timestamp`, le décodage défensif le convertit dans l'adaptateur, sans laisser fuiter le type.

### Frontière de story (ne PAS déborder)

- **E5-1 (cette story)** : `FirebaseZRepositoryImpl<T>` + traduction `ZDataRequest→Query` + curseur + soft-delete/restore + count + décodage défensif + isolation.
- **E5-2** : `ZLocalStore` (Hive) + `ZRemoteStore` (store local source de vérité). **Hors périmètre ici.**
- **E5-3** : patron offline-first LWW (merge `updatedAt`) + cascade bornée ≤450. **Hors périmètre** (ici : seulement soft-delete hors-entité + write cohérente).
- **E5-4** : `ZSyncOrchestrator`. **Hors périmètre.**
- **CloudStorageRepository** (fichiers, E3-3c) : impl Firebase Storage — **hors périmètre** de cette story (séparé).

### Project Structure Notes

- Nouveau : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (+ helpers privés éventuels `_query_translator.dart`).
- Export ajouté au barrel `packages/zcrud_firestore/lib/zcrud_firestore.dart` (conserver l'export existant `z_firestore_api.dart`).
- Tests : `packages/zcrud_firestore/test/firebase_z_repository_impl_test.dart` (+ éventuel `query_translator_test.dart`).
- `pubspec.yaml` de `zcrud_firestore` : ajouter `cloud_firestore`, `firebase_core`, `dartz` (déjà transitif via core mais déclarer si usage direct de `Unit`/`Either`), dev_dep `fake_cloud_firestore`. **Ne rien ajouter à `zcrud_core`.**
- Alignement nommage : type public préfixé `Z`/descriptif (`FirebaseZRepositoryImpl`) ; fichiers snake_case ; impl sous `lib/src/data/`.

### Testing standards

- Framework : `flutter_test` + `fake_cloud_firestore` (fidélité suffisante pour withConverter, where/orderBy/limit/startAfter, snapshots, agrégation count selon support ; sinon mock ciblé pour `count`/`FirebaseException`).
- Couverture obligatoire (mappée aux ACs) : round-trip (AC1), stream nu + exclusion soft-deleted (AC2), getAll filtré (AC3), count (AC4), softDelete/restore hors-entité (AC5), traduction fidèle par op (AC6), 3 clauses non perdues (AC7), batch atomique (AC8), `FirebaseException→ServerFailure` sans catch nu (AC9), document absent→NotFound / vide→`[]` (AC10), document corrompu→N-1 sans throw (AC11), tie-break/curseur déterministe sans doublon (AC12), isolation signatures (AC13), `zcrud_core` sans Firebase (AC14).
- Gates CI (E1-3/E2-10) : anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation — verts avant `review`.

### References

- [Source: architecture.md#AD-5] domaine backend-agnostique, ports, adapters dans zcrud_firestore.
- [Source: architecture.md#AD-9] soft-delete `is_deleted` hors-entité, LWW `updated_at`.
- [Source: architecture.md#AD-11] `Either<ZFailure,T>`, flux nus, hiérarchie ZFailure, null≠erreur.
- [Source: architecture.md#AD-16] curseur `startAfter` neutre, départage `id`.
- [Source: architecture.md#AD-10] désérialisation défensive.
- [Source: architecture.md#Stack] `cloud_firestore` firestore ^6 / `firebase_core` core ^4.
- [Source: epics.md#E5] objectif épic + Story E5-1 (bugs à corriger, curseur AD-16).
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart] signatures du port à implémenter.
- [Source: packages/zcrud_core/lib/src/domain/data/z_data_request.dart] `ZDataRequest`/`ZFilter`/`ZSort`/`ZFilterOp`/`ZSortDirection`.
- [Source: packages/zcrud_core/lib/src/domain/data/z_cursor.dart] `ZCursor` (values + id, double-mapping Firestore/in-memory).
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart] `ZFailure`/`ServerFailure`/`NotFoundFailure`/`DomainFailure`/`ZResult`.
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart] `ZSyncMeta` (updated_at/is_deleted, ISO-8601, défensif).
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart] `ZcrudRegistry.decode/encode/codecFor/tryCodecFor` (frontière décodage défensif).
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_entity.dart] `ZEntity.id`/`isEphemeral` (matérialisation).
- [Source: code-review-e2-6.md#MEDIUM-1] frontière défensive `fromMapSafe`/`decodeSafe` à câbler en E5.
- [Source: code-review-e4-3.md#L-2, #L-3] NFD documenté ; tie-break `id` côté adaptateur.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, **reprise** après plantage de l'agent précédent : travail partiel bugué finalisé et rendu vert).

### Debug Log References

Vérif verte rejouée réellement sur disque :

- `flutter analyze` (packages/zcrud_firestore) → **No issues found!** (0 warning, 0 info).
- `flutter test` (packages/zcrud_firestore) → **All tests passed** : **22/22**, 0 échec.
- `dart run melos run analyze` → **RC=0** (14 packages, No issues found).
- `dart run melos run verify` → **RC=0** (graph `CORE OUT=0 OK` ; gate:melos OK ; gate:reflectable OK ; gate:secrets OK ; gate:codegen OK ; gate:compat OK ; verify:serialization OK).
- `melos list` → **14 packages**. Isolation : `cloud_firestore`/`firebase_core` **uniquement** dans `packages/zcrud_firestore/pubspec.yaml` ; `zcrud_core` sans dépendance Firebase.

**Remédiation code-review E5-1 (rejouée réellement sur disque) :**

- `flutter analyze` (packages/zcrud_firestore) → **No issues found!** (0 issue).
- `flutter test` (packages/zcrud_firestore) → **All tests passed** : **31/31** (22 + 9 nouveaux), 0 échec.
- `dart run melos run analyze` → **RC=0** (14 packages, No issues found).
- `dart run melos run verify` → **RC=0** (`graph_proof.py` : `noeuds=14, triés=14`, `ACYCLIQUE OK`, `CORE OUT=0 OK`).
- `melos list` → **14 packages**.

### Completion Notes List

Reprise ciblée (l'implémentation de base posée par l'agent planté était presque complète mais **non finie et buguée**). Corrections apportées :

- **`_typedCollection` (withConverter) câblé** (corrige `unused_element`, warning bloquant) : `save` relit désormais l'entité persistée via la **collection typée `withConverter<T>`** (`fromFirestore` re-décode) — round-trip AC1 réellement exercé. Les lectures de liste/flux restent sur la voie `Map` brute + `_decode` **défensif** (un `withConverter` ne peut pas renvoyer `null` pour écarter un document corrompu — AD-10).
- **AC12 (tie-break + curseur) corrigé** : `FieldPath.documentId` est **incompatible** avec le calcul de curseur du backend de test (`doc.get(FieldPath.documentId)` lève « key must be String or FieldPath but found FieldPathType »). L'AC12 autorisant explicitement « `orderBy(FieldPath.documentId)` **ou le champ `id` logique** », le tie-break utilise le **champ `id` logique** (stocké dans le corps de chaque document par `_encode`/`save`). Pagination `startAfter([...values, id])` positionnellement alignée → page1=[idA,idB], page2=[idC], **aucun doublon, couverture totale**.
- **AC9 (FirebaseException → ServerFailure) corrigé** : `_guard` mappait déjà correctement ; le vrai blocage était le **harnais de test**. `fake_cloud_firestore` renvoie une **nouvelle** instance de collection/requête à chaque appel et `mock_exceptions` indexe par **identité d'objet** → impossible d'injecter sur l'objet requête construit EN INTERNE par le repo. Remplacé par un `_ThrowingFirestore` (sous-classe) qui lève une **vraie `FirebaseException`** à la frontière d'accès Firestore ; `getAll` → `Left(ServerFailure)` prouvé (jamais avalée, jamais remontée).
- **Nettoyages analyze** : `prefer_initializing_formals` = **faux positif** (champs privés en paramètres nommés — `this._x` nommé privé interdit par Dart) → `// ignore_for_file` documenté. Import `dartz` retiré du test (`Right` réexporté par `zcrud_core`) + import `mock_exceptions` retiré (plus utilisé).
- **Invariants respectés** : AD-5 (aucun type `cloud_firestore` dans une signature publique — `Query`/`CollectionReference` restent sur des membres privés `_`), AD-11 (`Either`, jamais de `catch(_){}`, `null≠erreur`), AD-16 (curseur `startAfter`), AD-10 (décodage défensif : 1 corrompu parmi N → N-1 sans throw).

### Remédiation des findings du code-review E5-1

Périmètre strictement limité à `packages/zcrud_firestore/`.

- **MAJEUR-1 (tie-break curseur) — CORRIGÉ, voie (b) invariant (option (a) PROUVÉE infaisable).** Option (a) `orderBy(FieldPath.documentId)` + `startAfter([...values, id])` **testée** sur `fake_cloud_firestore` : l'ORDER par `documentId` fonctionne mais `startAfter` **lève** `Invalid argument(s): key must be String or FieldPath but found FieldPathType` (le fake appelle en interne `doc.get(FieldPath.documentId)` durant l'évaluation du curseur — hors de notre contrôle). AC12 devient donc infaisable sous (a). → Bascule **(b)** : tie-break sur le champ `id` de **corps**, sous **précondition « collection zcrud-native »** rendue EXPLICITE et EXÉCUTOIRE (`save`/`_encode` écrivent TOUJOURS le corps `id`). Documentée fortement en dartdoc de classe + `_buildQuery`. Constat honnête : le fake **n'imite pas** l'exclusion prod d'un doc sans corps `id` (il le classe `null`), donc un test ne peut prouver l'exclusion prod ; les 2 tests MAJEUR-1 prouvent l'**invariant** (`save` écrit toujours `id==doc.id`) qui neutralise le risque en prod.
- **MAJEUR-2 (filtre soft-delete) — CORRIGÉ (cohérence des 2 couches et des 2 chemins).** Filtre serveur `where('is_deleted', isEqualTo:false)` conservé ; helper `_isVisible(data) = (is_deleted == false)` introduit et appliqué **et** dans `_decodeDocs` (getAll/watch) **et** dans `getById` → un doc SANS `is_deleted` est désormais exclu de façon **COHÉRENTE** sur les 3 chemins (plus de divergence get vs getAll/watch). Précondition « collection zcrud-native » documentée. Test seedant un doc sans `is_deleted` prouvant l'exclusion cohérente get/getAll/watch (le fake réplique ici la sémantique prod de l'égalité).
- **MEDIUM-1 (AC9 chemins flux) — CORRIGÉ.** `watch`/`watchAll` passent désormais un **builder** `Query Function()` à `_watchQuery` ; la construction (`collection(...)`) + l'abonnement sont enveloppés dans un `try/catch` DANS `onListen` qui pousse l'erreur dans le `StreamController` via `addError(_toFailure(e))`. Aucun throw synchrone ne remonte à l'appelant. Helper `_toFailure` (miroir de `_guard`). 2 tests (watch + watchAll via `_ThrowingFirestore`) prouvent l'arrivée de l'erreur `ServerFailure` **par le canal du stream**.
- **MEDIUM-2 (AC13/AC14 non testés) — CORRIGÉ.** AC13 : test scannant le barrel (aucun ré-export `package:cloud_firestore`/`firebase_core`) + les fichiers exportés (aucun des 6 types Firestore interdits dans une **signature de membre public**, avec contrôle positif anti-faux-vert). AC14 : test lisant `packages/zcrud_core/pubspec.yaml` (lecture seule) et prouvant l'absence de toute dépendance `firebase*`/`cloud_firestore`.
- **LOW-1 — CORRIGÉ.** `mock_exceptions` retiré du `pubspec.yaml` (dev_dep morte) + commentaire d'en-tête du test corrigé (approche `_ThrowingFirestore`).
- **LOW-2 — CORRIGÉ.** Test du mapping `ZFilterOp.isNull → where(isNull:true)`.
- **LOW-3 — DOCUMENTÉ.** Dartdoc de `_typedCollection` acte que `toFirestore` n'est jamais invoqué et que les listes/flux lisent en `Map` brute + `_decode` défensif (converter réservé au round-trip de `save`, AD-10).
- **LOW-4 — DOCUMENTÉ + TESTÉ.** Dartdoc de `save` acte l'overwrite total « ressuscitant » (`is_deleted=false` réécrit) et que le merge LWW est E5-3 ; test prouvant la résurrection intentionnelle.
- **LOW-5 — DOCUMENTÉ.** Dartdoc de `_buildQuery` documente les index composites requis EN PROD (masqués par le fake) et renvoie à la config de déploiement E7.

### File List

- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (modifié — remédiation : précondition zcrud-native en dartdoc classe ; `_isVisible` (MAJEUR-2) ; `getById` aligné ; `_watchQuery` builder + `_toFailure` (MEDIUM-1) ; dartdoc `_buildQuery`/`_baseQuery`/`save`/`_typedCollection` (MAJEUR-1/LOW-3/4/5))
- `packages/zcrud_firestore/test/firebase_z_repository_impl_test.dart` (modifié — remédiation : +9 tests (MAJEUR-1×2, MAJEUR-2, MEDIUM-1×2, LOW-2, LOW-4, AC13, AC14) ; locators `_pkgDir`/`_coreDir` ; en-tête corrigé)
- `packages/zcrud_firestore/lib/src/data/z_firestore_api.dart` (marqueur AD-1, inchangé)
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (barrel, export de l'impl, inchangé)
- `packages/zcrud_firestore/pubspec.yaml` (modifié — remédiation LOW-1 : `mock_exceptions` retiré)

## Questions / Ambiguïtés détectées (pour dev-story / code-review)

1. **`decodeSafe` sur `ZcrudRegistry` ?** Le contrat E2-3 est gelé et n'expose que `decode` (strict). Pour câbler la voie défensive (AC11), deux options : (a) l'adaptateur détient une référence au codec/adaptateur exposant `fromMapSafe` ; (b) ajout **additif** `decodeSafe(kind, map) → Object?` sur `ZcrudRegistry`. **Recommandation** : (b) si additif et rétro-compatible — à trancher en dev-story/code-review. *(Absorbe E2-6 MEDIUM-1.)*
2. **`is_deleted` : filtre serveur vs applicatif.** `where('is_deleted', isNotEqualTo: true)` impose des index composites et interdit certains `orderBy`. Repli possible : filtrer les soft-deleted **côté application** après lecture. À décider selon les contraintes d'index Firestore ; documenter.
3. **`count` avec `fake_cloud_firestore`.** Le support de `AggregateQuery.count()` par le fake peut être partiel → repli test via `getAll().length` ou mock dédié. À confirmer en dev-story.
4. **`contains` (substring)** : Firestore n'offre pas de recherche de sous-chaîne ; `ZFilterOp.contains` est mappé à `arrayContains` (appartenance à un champ collection). La sémantique « sous-chaîne texte » n'est **pas** supportée nativement — documenter (lien AC15).
5. **Emplacement de `ZSyncMeta`** : dans le même document (champs `is_deleted`/`updated_at` fusionnés au corps) ou sous-document séparé ? La convention canonique dit « hors-entité » logiquement ; l'implémentation la plus simple fusionne les clés snake_case dans le document tout en gardant `ZSyncMeta` séparé côté modèle. À confirmer avec E5-2/E5-3.

<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->
