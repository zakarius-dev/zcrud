# Story 5.3: Patron offline-first LWW + soft-delete + `ZSyncMeta`

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a intégrateur backend de zcrud,
I want un **dépôt offline-first** `ZOfflineFirstRepository<T>` (dans `zcrud_firestore`) qui **compose** le `ZLocalStore<T>` (Hive, source de vérité) livré en E5-2 avec le `ZRemoteStore<T>` (Firestore, fire-and-forget) — lectures/écritures **local-first autoritaires**, propagation distante **best-effort**, et une méthode `sync()` qui réalise un **pull one-shot + merge Last-Write-Wins sur `updatedAt`** (tombstones inclus), avec **soft-delete `is_deleted` hors-entité standardisé `ZSyncMeta`** et une **propagation bornée ≤ 450 écritures/lot**,
so that la donnée d'étude (E9) et les apps consommatrices disposent d'un CRUD qui **fonctionne hors-ligne** (le local fait toujours autorité), **converge** au retour du réseau **sans perte ni résurrection accidentelle** de données supprimées, et **sans** qu'aucun type `hive`/`cloud_firestore` ne fuite dans `zcrud_core` — l'orchestration du *quand* (login/reconnexion débouncée) restant à E5-4.

## Contexte épic (E5)

**E5 — Backend Firestore & offline-first (`zcrud_firestore`).** Objectif : adaptateur Firestore débogué + patron offline-first. Couvre FR-12/FR-13. AD-5/AD-9/AD-10/AD-11.
Phase : **E5-1/E5-2 = MVP** (repo Firestore + `ZLocalStore`/`ZRemoteStore`, requis par E7/E8) ; **E5-3/E5-4 = v1.x** — leur consommateur est la **donnée d'étude E9** (aucun écran MVP ne les requiert ; harnais de validation livré avec E9-4). [Source: epics.md#E5, ligne 96]

E5-3 est **l'avant-dernière story d'E5**. Elle assemble en un **patron offline-first cohérent** les deux moitiés bas-niveau livrées séparément :
- **E5-1 (done)** — `FirebaseZRepositoryImpl<T>` : adaptateur Firestore du port `ZRepository<T>` ; `_encode`/`_decode` défensif ; soft-delete hors-entité (`ZSyncMeta`, `is_deleted`/`updated_at` ISO-8601) ; invariant **corps `id`** (le corps porte toujours `id == doc.id`) ; `_isVisible(data)=data['is_deleted']==false` cohérent get/getAll/watch ; isolation Firebase prouvée.
- **E5-2 (done)** — ports neutres `ZLocalStore<T>` / `ZRemoteStore<T>` (`zcrud_core`) + adaptateurs `HiveZLocalStore<T>` (local source de vérité, JSON, décodage défensif, soft-delete par drapeau — **jamais** `box.delete`) et `FirestoreZRemoteStore<T>` (distant fire-and-forget, **composition** sur E5-1).

> **Frontière que E5-3 franchit — assumée en toutes lettres par E5-2 :** *« la composition « local autoritaire ↔ distant fire-and-forget », le **merge Last-Write-Wins** sur `updatedAt` et la cascade bornée sont l'affaire d'**E5-3/E5-4** — hors de ce port »*. [Source: packages/zcrud_core/lib/src/domain/ports/z_local_store.dart:20-23 ; z_remote_store.dart:21-24]

## Frontière de portée — E5-3 vs E5-4 (NON négociable)

| | E5-3 (cette story) | E5-4 (suivante) |
|---|---|---|
| **Le *comment*** ✅ | composition local+distant ; merge LWW `updatedAt` ; propagation soft-delete ; `sync()` par dépôt ; `Right(unit)` si déconnecté ; cascade/lot ≤ 450 | — |
| **Le *quand*** ❌ | **PAS ici** | `ZSyncOrchestrator` : déclenche `sync()` d'un **ensemble de dépôts enregistrés** sur login + reconnexion **débouncée ~400 ms**, best-effort, **échec partiel toléré** (un dépôt échoue → les autres continuent) |

E5-3 n'introduit **aucun** débounce, **aucun** registre multi-dépôts, **aucune** écoute de connectivité temps-réel. `sync()` est un **appel one-shot** ; c'est E5-4 qui décidera *quand* l'appeler et sur *quels* dépôts. [Source: epics.md#E5 Story E5-4, ligne 101 ; architecture.md#AD-9, ligne 100]

## Constat de conception préalable — pourquoi de nouveaux contrats sont nécessaires (à lire AVANT de coder)

Le merge LWW **ne peut pas** se faire à travers les lectures existantes, et ce constat dicte les AC ci-dessous :

1. **Les lectures actuelles excluent les tombstones.** `ZLocalStore.getAll()` / `ZRemoteStore.pull()` ne renvoient que les **visibles** (`is_deleted==false`). Or un merge LWW correct doit voir, de **chaque côté**, l'`updatedAt` **et** l'`is_deleted` de **toutes** les entrées **y compris soft-deletées** — sinon une suppression distante (tombstone) ne peut jamais se propager au local, et inversement. → E5-3 introduit une **voie de lecture de synchronisation** qui **inclut** les soft-deletés + leur méta (`syncEntries()`), sur les DEUX ports + DEUX adaptateurs.

2. **`put()`/`save()`/`push()` réestampillent `updated_at = now()`.** [Source: hive_z_local_store.dart:179-183 (`_encode`) ; firebase_z_repository_impl.dart:194-198 (`_encode`)]. Si l'on **adopte** un gagnant distant en le réécrivant localement via `put()`, son `updated_at` deviendrait `now()` → le local paraîtrait toujours le plus récent → **le LWW ne converge jamais** (ping-pong / « local gagne toujours »). → E5-3 introduit une **écriture qui PRÉSERVE la méta** (`applyMerged(entry)` : écrit l'entité + le `ZSyncMeta` **verbatim**, **sans** `now()`), **réservée** à l'application d'un résultat de merge. Les écritures utilisateur normales (`save`) continuent, elles, d'estampiller `now()` (vraie mutation).

3. **`ZRepository<T>` n'a pas de `sync()`.** [Vérifié : z_repository.dart n'expose pas `sync`]. Le canonique §7 place `sync()` au contrat de dépôt. → E5-3 introduit un **sur-port** `ZSyncableRepository<T> extends ZRepository<T>` ajoutant `Future<ZResult<Unit>> sync()`, que **E5-4** consommera pour piloter un ensemble de dépôts. `FirebaseZRepositoryImpl` (distant pur) **n'implémente pas** ce sur-port et reste inchangé (ajout **additif**, non cassant).

## Acceptance Criteria

### Contrats de synchronisation (dans `zcrud_core`, Dart pur — AD-5/AD-9/AD-11)

1. **`ZSyncEntry<T extends ZEntity>` — entrée de synchronisation (méta incluse).** Nouveau fichier `packages/zcrud_core/lib/src/domain/sync/z_sync_entry.dart`, exporté par le barrel. Value object **immuable**, Dart pur (aucun import backend) : `{ T entity, ZSyncMeta meta }`, avec accès dérivés `String? get id => entity.id`, `DateTime? get updatedAt => meta.updatedAt`, `bool get isDeleted => meta.isDeleted` ; `==`/`hashCode`/`toString`. Il **transporte les tombstones** : une entrée soft-deletée reste un `ZSyncEntry` valide (`isDeleted == true`, `entity` décodée). *(AD-5, AD-9)*

2. **`ZLwwResolver` — résolveur Last-Write-Wins PUR.** Nouveau fichier `packages/zcrud_core/lib/src/domain/sync/z_lww_resolver.dart`, exporté par le barrel. Fonction/`class` **pure** (aucun I/O, aucune horloge, aucun type backend) : `ZLwwDecision<T> resolve<T extends ZEntity>(ZSyncEntry<T>? local, ZSyncEntry<T>? remote)`. Règles **déterministes et testées** :
   - `local` seul (absent du distant) → **`pushLocalToRemote(local)`** ;
   - `remote` seul (absent du local) → **`adoptRemoteIntoLocal(remote)`** ;
   - les deux présents → **le plus grand `updatedAt` gagne** ; distant plus récent → `adoptRemoteIntoLocal(remote)` ; local plus récent → `pushLocalToRemote(local)` ;
   - **`updatedAt` `null`** = **le plus ancien** (perd contre toute date non-`null`) ;
   - **égalité stricte** de `updatedAt` (y compris deux `null`) → **le LOCAL fait foi** (source de vérité, AD-9) : `noop` si les états sont **identiques** (même corps + même `is_deleted`), sinon `pushLocalToRemote(local)` (le local, autoritaire, réaligne le distant). *(La précédence-tombstone en cas d'égalité est une alternative consignée en Ambiguïtés — trancher en code-review.)*
   Le résultat est un `ZLwwDecision<T>` = `{ ZLwwAction action, ZSyncEntry<T>? entry }` avec `enum ZLwwAction { noop, adoptRemoteIntoLocal, pushLocalToRemote }`. *(AD-9)*

3. **Voie de lecture de sync `syncEntries()` ajoutée aux DEUX ports.** `ZLocalStore<T>` et `ZRemoteStore<T>` reçoivent (ajout **additif**) `Future<ZResult<List<ZSyncEntry<T>>>> syncEntries()` : renvoie **toutes** les entrées **y compris soft-deletées**, chacune avec son `ZSyncMeta` (`updatedAt`/`isDeleted`). Contraste **documenté** avec `getAll()`/`pull()` (qui excluent les tombstones). Décodage **défensif** (AD-10) : une entrée non décodable est écartée + loggée, jamais de throw. *(AD-9, AD-10, AD-11)*

4. **Écriture préservant la méta `applyMerged()` ajoutée aux DEUX ports.** `ZLocalStore<T>` et `ZRemoteStore<T>` reçoivent `Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry)` : écrit l'entité **et** son `ZSyncMeta` **verbatim** — `updated_at` et `is_deleted` **préservés tels quels**, **jamais** réestampillés `now()`. Dartdoc explicite : `applyMerged` est **réservé** à l'application d'un résultat de merge (défaire l'estampille `now()` de `put`/`save` casserait le LWW) ; il **n'est pas** une voie d'écriture utilisateur. Écrire une entrée `isDeleted:true` via `applyMerged` **propage un tombstone** (soft-delete). *(AD-9)*

5. **Sur-port `ZSyncableRepository<T extends ZEntity> extends ZRepository<T>`.** Nouveau fichier `packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart`, exporté par le barrel. Ajoute **une seule** méthode : `Future<ZResult<Unit>> sync()` (dartdoc : merge one-shot ; `Right(unit)` si déconnecté ; le *quand* et le multi-dépôts appartiennent à E5-4). Ajout **additif** : `FirebaseZRepositoryImpl` (qui implémente `ZRepository`) **n'est pas** modifié et n'a **pas** à porter `sync()`. *(AD-9)*

6. **`zcrud_core` reste Dart pur & sans backend.** Aucune dépendance `hive`/`cloud_firestore`/`firebase_core` ajoutée à `packages/zcrud_core/pubspec.yaml`. Le gate `graph_proof.py` (`CORE OUT=0`) et le `dry-run` de compat (FR-25) restent **verts**. Aucun `ZSyncEntry`/`ZLwwResolver`/port n'expose de type backend (uniquement `T`, `ZSyncMeta`, `Either`/`Unit`). *(AD-1, AD-5)*

### Dépôt offline-first (dans `zcrud_firestore`)

7. **`ZOfflineFirstRepository<T extends ZEntity>` implémente `ZSyncableRepository<T>`.** Nouveau fichier `packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart`, exporté par le barrel. **Composition** (pas héritage — AD-4) : reçoit en injection un `ZLocalStore<T>` (**autoritaire**), un `ZRemoteStore<T>` (**best-effort**), le `ZLwwResolver` (défaut = résolveur canonique), un `Future<bool> Function()? isConnected` **optionnel** (couture connectivité — défaut `null`), et un log injectable no-op. **Aucun** type `hive`/`cloud_firestore` en signature publique (isolation héritée E5-1/E5-2, re-vérifiée). *(AD-4, AD-5)*

8. **Lectures = LOCAL source de vérité, tombstones exclus.** `watchAll()`, `watch(req)`, `getAll({request})`, `getById(id)`, `count({request})` **délèguent au store LOCAL** (jamais au distant : le local fait autorité offline-first). `getById(id)` d'un id **absent OU soft-deleté** → `Left(NotFoundFailure)` (exclusion des soft-deletés **héritée** de `HiveZLocalStore`, cohérente get/getAll/watch). Un test prouve que `getById` d'un id soft-deleté → `NotFoundFailure`, et que `getAll`/`watchAll` **excluent** les soft-deletés. *(AD-9, AD-16)*

9. **Écritures = LOCAL-first autoritaire + distant FIRE-AND-FORGET.** `save(item)` : écrit **d'abord** au local (`ZLocalStore.put` — matérialise l'éphémère, estampille `updated_at=now()`, `is_deleted:false`), renvoie `Right(localResult)` **dès** le succès local ; **puis** propage au distant en **fire-and-forget** (`ZRemoteStore.push`) — un **échec distant** est **loggé** et **n'invalide PAS** le succès local (`ServerFailure` distant ≠ échec de `save`). `softDelete(id)`/`restore(id)` : local d'abord (bascule `is_deleted` hors-entité), puis propagation best-effort (`remoteDelete`/push). Un test **hors-ligne** (remote qui renvoie `Left(ServerFailure)`) prouve que `save`/`softDelete` **réussissent** (`Right`) et que la donnée est **lisible localement**. *(AD-9)*

10. **`sync()` = pull one-shot + merge LWW (tombstones inclus).** `sync()` : (a) lit `local.syncEntries()` **et** `remote.syncEntries()` (méta + tombstones des deux côtés) ; (b) **indexe par `id`** et calcule, pour **l'union des id**, une `ZLwwDecision` via `ZLwwResolver` ; (c) **applique** : `adoptRemoteIntoLocal` → `local.applyMerged(entry)` (préserve la méta distante) ; `pushLocalToRemote` → accumulé puis **propagé par lot borné** (AC12) via `remote.applyMerged` ; `noop` → rien. Un test **multi-cas** prouve la convergence : (i) distant plus récent adopté localement ; (ii) local plus récent poussé au distant ; (iii) **tombstone distant plus récent** → l'entité devient soft-deletée **localement** (disparaît des lectures visibles) ; (iv) **tombstone local plus récent** → propagé au distant ; (v) `updatedAt` égal + états identiques → **aucune écriture** (`noop`, pas de ping-pong). *(AD-9)*

11. **`Right(unit)` si déconnecté — jamais d'échec « offline ».** `sync()` renvoie `Right(unit)` **sans erreur** quand le distant est **injoignable** : soit `isConnected?.call() == false` (court-circuit avant réseau), soit `remote.syncEntries()`/la propagation distante renvoie `Left(ServerFailure)` (traité comme offline, **best-effort**, avalé **en `Right(unit)`** et loggé). En revanche, une **erreur LOCALE** (`Left(CacheFailure)` sur `local.syncEntries()`/`applyMerged`) est une **vraie panne** → `sync()` renvoie `Left(CacheFailure)` (jamais avalée). Un test prouve les deux branches : remote `ServerFailure` → `Right(unit)` ; local `CacheFailure` → `Left(CacheFailure)`. *(AD-9, AD-11)*

12. **Cascade/propagation bornée ≤ 450 écritures/lot (AD-9).** La propagation distante d'un **changeset** (ensemble des `pushLocalToRemote` d'un `sync()`, et/ou une suppression multi-entités) est **découpée en lots atomiques de ≤ 450 écritures** (borne canonique sûre sous la limite Firestore de 500). Le découpage (constante `450`) vit **côté adaptateur `zcrud_firestore`** (limite **backend-spécifique** — jamais dans `zcrud_core`, AD-5) : `FirestoreZRemoteStore` expose une application **par lot** (`WriteBatch` chunké ≤ 450, chaque lot **committé atomiquement**). Un test avec **451 entrées** prouve **2 lots** (450 + 1), chacun committé, aucune écriture partielle non-commit. *(AD-9)*

13. **Soft-delete `is_deleted` hors-entité standardisé, bout-en-bout.** Sur **toute** la chaîne (local, distant, merge, propagation), la suppression est un **drapeau `is_deleted` hors-entité** (`ZSyncMeta`, clés snake_case `is_deleted`/`updated_at`, `updated_at` **ISO-8601**, **jamais** `Timestamp` — AD-5) ; **aucun** champ métier n'est touché ; **jamais** de purge physique (`box.delete`/`doc.delete`) dans la voie de suppression. La méta LWW et le tombstone transitent **verbatim** via `ZSyncEntry`/`applyMerged`. Un test prouve qu'un soft-delete puis un merge conservent le corps métier intact et ne fixent que `is_deleted`/`updated_at`. *(AD-9, AD-16)*

### Isolation & vérif

14. **ISOLATION AD-5 — aucun type backend ne fuit.** Aucune signature publique de `ZOfflineFirstRepository<T>` (retours, params exposés hors `zcrud_firestore`) n'expose `Box`/`HiveObject`/`HiveInterface`/`Timestamp`/`Filter`/`Query`/`DocumentSnapshot`/`CollectionReference`/`FirebaseException` ni aucun symbole `hive`/`cloud_firestore`. Retours `ZResult<…>` / `Stream<List<T>>` **nus**. Le gate de signatures publiques (miroir E5-1 AC13 / E5-2 AC10) couvre le nouveau fichier. *(AD-5)*

15. **Vérif verte + gates CI.** `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0 (packages touchés **et** repo-wide). Gates CI (anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation, graphe `CORE OUT=0`, gate:compat) **verts** avant `review`. Aucune régression des tests E5-1 (`FirebaseZRepositoryImpl`) ni E5-2 (`HiveZLocalStore`/`FirestoreZRemoteStore`) — les ajouts de méthodes aux ports/adaptateurs sont **additifs**. *(Stack ; AD-1)*

## Tasks / Subtasks

- [x] **T1. Contrats de sync purs dans `zcrud_core`** (AC: 1, 2, 6)
  - [x] Créer `z_sync_entry.dart` : `class ZSyncEntry<T extends ZEntity> { final T entity; final ZSyncMeta meta; ... }` (immuable, `id`/`updatedAt`/`isDeleted` dérivés, `==`/`hashCode`/`toString`).
  - [x] Créer `z_lww_resolver.dart` : `enum ZLwwAction`, `class ZLwwDecision<T>`, `ZLwwResolver` (fonction pure `resolve`). Aucune horloge, aucun I/O, aucun type backend.
  - [x] Exporter les deux depuis le barrel `zcrud_core.dart` (ordre alpha).
  - [x] Ne **rien** ajouter à `zcrud_core/pubspec.yaml` ; re-jouer `CORE OUT=0`.
- [x] **T2. Extension additive des ports `ZLocalStore`/`ZRemoteStore`** (AC: 3, 4, 6)
  - [x] Ajouter `Future<ZResult<List<ZSyncEntry<T>>>> syncEntries();` (méta + tombstones inclus ; dartdoc contraste avec `getAll`/`pull`).
  - [x] Ajouter `Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry);` (préserve la méta **verbatim** ; dartdoc « réservé au merge — ne réestampille PAS `now()` »).
  - [x] Vérifier que **seuls** `HiveZLocalStore`/`FirestoreZRemoteStore` implémentent ces ports (monorepo) → ajout additif sans casser d'autre implémenteur.
- [x] **T3. Sur-port `ZSyncableRepository<T>`** (AC: 5)
  - [x] Créer `z_syncable_repository.dart` : `abstract class ZSyncableRepository<T extends ZEntity> extends ZRepository<T> { Future<ZResult<Unit>> sync(); }`, exporté au barrel. Dartdoc : one-shot ; `Right(unit)` si déconnecté ; *quand*/multi-dépôts = E5-4.
- [x] **T4. Implémenter `syncEntries`/`applyMerged` dans `HiveZLocalStore`** (AC: 3, 4, 8, 13)
  - [x] `syncEntries()` : itérer les clés de la box, `_rawMap`/décodage **défensif** (réutiliser `_decodeEntity`, PAS `_isVisible`), construire `ZSyncEntry(entity, ZSyncMeta.fromJson(map))` **y compris** les `is_deleted==true`. Enveloppe `_guard` → `Left(CacheFailure)`.
  - [x] `applyMerged(entry)` : `box.put(id, map)` où `map = toMap(entity)` fusionné avec `entry.meta.toJson()` (`updated_at`/`is_deleted` **préservés**, PAS `now()`) + corps `id` **toujours** écrit (invariant clé↔corps). Réémet sur le flux `watchAll`.
- [x] **T5. Implémenter `syncEntries`/`applyMerged` + lot ≤ 450 dans le distant** (AC: 3, 4, 12, 13)
  - [x] Ajouter (additif) `FirebaseZRepositoryImpl.syncEntriesAll()` : lecture **sans** filtre `is_deleted` (tous docs), retour `List<ZSyncEntry<T>>` (méta depuis le corps du doc). `FirestoreZRemoteStore.syncEntries()` **délègue**.
  - [x] `FirestoreZRemoteStore.applyMerged(entry)` : écriture préservant la méta via l'adaptateur E5-1 (nouvelle voie `writeMerged`/`setRaw` additive côté `FirebaseZRepositoryImpl` qui écrit le map **sans** réestampiller `now()`).
  - [x] Application **par lot borné** : `applyMergedAll(List<ZSyncEntry<T>>)` (ou boucle de chunk `_chunk(entries, 450)`) → un `WriteBatch` par lot, **committé atomiquement** ; constante `450` **locale à `zcrud_firestore`** (documentée : limite Firestore 500).
- [x] **T6. `ZOfflineFirstRepository<T>`** (AC: 7, 8, 9, 10, 11, 12, 14)
  - [x] Classe dans `lib/src/data/z_offline_first_repository.dart` implémentant `ZSyncableRepository<T>` ; injection `ZLocalStore`/`ZRemoteStore`/`ZLwwResolver`/`isConnected?`/`logger`.
  - [x] Lectures → **délégation LOCAL** (watchAll/watch/getAll/getById/count).
  - [x] Écritures → **local d'abord** (autoritaire) puis distant **fire-and-forget** (échec distant loggé, jamais propagé au retour ; `save`/`softDelete`/`restore`).
  - [x] `sync()` : union par `id` de `local.syncEntries()`+`remote.syncEntries()` → `resolve` → appliquer (`applyMerged` local / `applyMergedAll` distant borné). `isConnected==false` ou `ServerFailure` distant → `Right(unit)` ; `CacheFailure` local → `Left`.
- [x] **T7. Barrel + isolation** (AC: 6, 14)
  - [x] Exporter `ZOfflineFirstRepository` depuis `lib/zcrud_firestore.dart` (conserver les exports existants).
  - [x] Étendre le gate de signatures publiques (miroir E5-1 AC13 / E5-2 AC10) au nouveau fichier.
- [x] **T8. Tests** (AC: tous)
  - [x] **Core (unitaires purs)** : `ZLwwResolver` — local seul→push ; remote seul→adopt ; distant récent→adopt ; local récent→push ; `null` = plus ancien ; égalité états identiques→`noop` ; égalité états différents→push local. `ZSyncEntry` (dérivés `id`/`updatedAt`/`isDeleted`, `==`).
  - [x] **Local Hive** : `syncEntries()` inclut les tombstones (N total dont soft-deletés) ; `applyMerged` **préserve** `updated_at` (pas de `now()`) + corps `id` ; 1 corrompu parmi N → N-1 sans throw.
  - [x] **Distant** (`fake_cloud_firestore`) : `syncEntries` inclut tombstones ; `applyMerged` préserve la méta ; **451 entrées → 2 lots (450+1)** atomiques (AC12).
  - [x] **Offline repo** : lectures délèguent au local + `getById` soft-deleté→`NotFound` (AC8) ; write hors-ligne réussit + lisible local (AC9) ; `sync()` 5 cas de convergence dont tombstones (AC10) ; `Right(unit)` si `ServerFailure`/`isConnected==false`, `Left(CacheFailure)` si erreur locale (AC11) ; soft-delete bout-en-bout conserve le corps (AC13) ; isolation signatures (AC14).
  - [x] **Non-régression** : rejouer les tests E5-1/E5-2 (aucune régression des ajouts additifs).
- [x] **T9. Documentation & frontière** (AC: 5, 11, 12)
  - [x] Dartdoc des 3 nouveaux types core + du dépôt : rôle, `applyMerged` réservé au merge (anti-ping-pong), `Right(unit)` si offline vs `Left(CacheFailure)` local, lot ≤ 450 (limite backend), **frontière E5-3 (comment) vs E5-4 (quand : débounce/multi-dépôts)**.

## Dev Notes

### Contexte architectural (à respecter absolument)

- **AD-9 (offline-first standardisé).** *« patron offline-first = store local source de vérité + distant fire-and-forget, merge **Last-Write-Wins sur `updatedAt`**, soft-delete `is_deleted` (hors-entité standardisé `ZSyncMeta`), cascade bornée. `ZSyncOrchestrator` sépare le *quand* du *comment*. »* E5-3 = **le *comment*** (composition + merge + soft-delete + lot ≤ 450) ; E5-4 = **le *quand*** (orchestrateur). [Source: architecture.md#AD-9, lignes 97-100]
- **AD-5 (domaine backend-agnostique).** Ports + `ZSyncEntry`/`ZLwwResolver`/`ZSyncableRepository` vivent dans `zcrud_core` **sans** type backend ; la constante de lot `450` (limite Firestore) et les `WriteBatch` vivent **exclusivement** dans `zcrud_firestore`. Aucun `Box`/`Timestamp`/`Filter` ne traverse un port ; dates en **ISO-8601** (jamais `Timestamp`). [Source: architecture.md#AD-5, lignes 79-80]
- **AD-10 (désérialisation défensive).** `syncEntries()` décode par la **voie tolérante** (`fromMapSafe → null`) : une entrée corrompue est **écartée + loggée**, jamais de throw. [Source: architecture.md#AD-10]
- **AD-11 (erreurs & flux nus).** `ZResult<T> = Either<ZFailure,T>` ; `ZResult<Unit>` pour void ; **flux nus** `Stream<List<T>>`. Local = **cache** → `CacheFailure` ; distant → `ServerFailure`. **Distinction critique de `sync()`** : `ServerFailure` distant = **offline** → avalé en `Right(unit)` ; `CacheFailure` local = **panne** → `Left`. Jamais `catch(_){}` ; `null ≠ erreur`. [Source: architecture.md#AD-11]
- **AD-16 (soft-delete hors-entité).** `is_deleted`/`updated_at` standardisés hors-entité via `ZSyncMeta` ; soft-delete par drapeau, **jamais** de purge physique. [Source: z_sync_meta.dart ; architecture.md#AD-16]
- **AD-4 (extensibilité, anti-héritage).** `ZOfflineFirstRepository` = **composition** de `ZLocalStore`+`ZRemoteStore`, **pas** héritage de classes sérialisées. [Source: architecture.md#AD-4]

### Signatures EXACTES à réutiliser (citées depuis le disque)

**`ZSyncMeta`** (`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`) — méta hors-entité **déjà défensive**, `copyWith` à **sentinelle** (permet `updatedAt=null`) :
```
class ZSyncMeta {
  const ZSyncMeta({this.updatedAt, this.isDeleted = false});
  final DateTime? updatedAt;      // clé LWW
  final bool isDeleted;           // soft-delete
  factory ZSyncMeta.fromJson(Map<String,dynamic> json);  // ne throw jamais
  Map<String,dynamic> toJson();   // {'updated_at': iso|null, 'is_deleted': bool}
  ZSyncMeta copyWith({Object? updatedAt = _unset, bool? isDeleted});
}
```
> Réutiliser `ZSyncMeta.fromJson`/`toJson` pour lire/écrire la méta ; **ne pas** réinventer le parsing ISO-8601.

**`ZSyncable`** (`packages/zcrud_core/lib/src/domain/contracts/z_syncable.dart`) — contrat `DateTime? get updatedAt` **déjà présent** : la clé LWW. `ZSyncEntry`/`ZLwwResolver` s'appuient sur la valeur portée par `ZSyncMeta` (hors-entité), cohérente avec ce contrat. [Source: z_syncable.dart]

**`ZEntity`** (`.../contracts/z_entity.dart`) : `String? get id` (nullable = éphémère), `bool get isEphemeral => id == null`. La matérialisation de l'éphémère au `save` reste portée par le **store** (AD-14), déjà implémentée par `HiveZLocalStore.put`.

**Port `ZRepository<T>`** (`z_repository.dart`) — surface à **conserver** puis **étendre** par `ZSyncableRepository` : `watchAll()`, `watch(req)`, `getAll({request})`, `getById(id)`, `save(item,{collectionId})`, `softDelete(id)`, `restore(id)`, `count({request})`, `dispose()`. **Ne pas modifier ce port** ; `sync()` va sur le **sur-port**.

**`ZLocalStore<T>`** (`z_local_store.dart`) — déjà : `watchAll/getAll/getById/put/softDelete/restore/clear/dispose`. **Ajouter** `syncEntries()` + `applyMerged()`. `put` **estampille `now()`** (à NE PAS utiliser pour appliquer un merge). [Source: z_local_store.dart:44-79]

**`ZRemoteStore<T>`** (`z_remote_store.dart`) — déjà : `push/remoteDelete/pull/watchAll/dispose`. **Ajouter** `syncEntries()` + `applyMerged()` (+ application par lot borné côté impl). [Source: z_remote_store.dart:34-54]

### Réutilisation E5-1/E5-2 (à imiter/déléguer, PAS réinventer)

- **`HiveZLocalStore<T>`** (`.../data/hive_z_local_store.dart`) : réutiliser `_encode`/`_decodeEntity`/`_rawMap`/`_guard`/`_kIsDeleted`/`_kUpdatedAt`/`_isVisible`, le typedef `ZLocalStoreLog` + `_noopLog`. **`syncEntries` NE PASSE PAS par `_isVisible`** (il inclut les tombstones) ; **`applyMerged` NE PASSE PAS par `_encode`** (qui force `now()`/`is_deleted:false`) mais fusionne `entry.meta.toJson()` **verbatim** + le corps `id`. [Source: hive_z_local_store.dart:179-183, 217-247, 266-289, 390]
- **`FirebaseZRepositoryImpl<T>`** (`.../data/firebase_z_repository_impl.dart`) : `getAll` filtre `is_deleted==false` → pour `syncEntries` il faut une **lecture sans ce filtre** (méthode additive `syncEntriesAll`). `save`/`_encode` estampillent `now()` → pour `applyMerged` il faut une **écriture brute préservant la méta** (méthode additive). Réutiliser `_guard`/`_toFailure`, `_kId`, `_isVisible`. [Source: firebase_z_repository_impl.dart:194-198, 235-265]
- **`FirestoreZRemoteStore<T>`** (`.../data/firestore_z_remote_store.dart`) : **composition** sur `FirebaseZRepositoryImpl` (`push→save`, `remoteDelete→softDelete`, `pull→getAll`, `watchAll→watchAll`) ; **compléter** avec `syncEntries→syncEntriesAll` et `applyMerged`/`applyMergedAll` (lot ≤ 450). N'importe toujours **pas** `cloud_firestore`. [Source: firestore_z_remote_store.dart:41-64]

### Le piège LWW n°1 — anti-ping-pong (learning à ancrer)

`put`/`save` **réestampillent** `updated_at = DateTime.now().toUtc()` à **chaque** écriture. Appliquer un gagnant de merge via `put`/`save` réestampillerait `now()` → le côté qui vient d'« adopter » paraîtrait le plus récent au tour suivant → **oscillation perpétuelle**. C'est **la** raison d'être de `applyMerged` (écriture **verbatim**, méta préservée). **Un test doit prouver** qu'après `sync()`, l'`updated_at` du gagnant est **inchangé** des deux côtés (pas de dérive vers `now()`). *(Miroir du soin E5-1/E5-2 : « le fake/test ne doit pas masquer la sémantique prod ».)*

### Le piège LWW n°2 — tombstones invisibles

`getAll`/`pull`/`watchAll` **excluent** les soft-deletés → un merge basé dessus **ne verrait jamais** une suppression. `sync()` **doit** lire via `syncEntries()` (tombstones + méta inclus) des **deux** côtés, sinon une suppression distante ne se propage jamais au local (et inversement). Test obligatoire : tombstone distant plus récent → l'entité **disparaît des lectures visibles locales** après `sync()`.

### Détection « déconnecté » (AC11) — pas de port connectivité en E5-3

Deux voies, **sans** introduire de port `ZConnectivity` (hors périmètre) :
1. `isConnected?.call() == false` (couture optionnelle injectée) → court-circuit `Right(unit)` avant tout accès réseau.
2. Sinon, un `Left(ServerFailure)` sur `remote.syncEntries()` ou sur la propagation distante est **interprété comme offline** → avalé en `Right(unit)` + loggé (best-effort).
> **Ne jamais** avaler un `Left(CacheFailure)` **local** : c'est une vraie panne (`Left`). E5-4 fournira la vraie source de connectivité (login/reconnexion débouncée).

### Cascade/lot ≤ 450 (AC12) — où vit la borne

La limite `500` écritures/`WriteBatch` est **Firestore-spécifique** ; le canonique fige la borne **sûre `450`**. Elle vit donc **uniquement** dans `zcrud_firestore` (jamais `zcrud_core`, AD-5). Le dépôt offline-first passe le **changeset complet** ; c'est `FirestoreZRemoteStore`/`FirebaseZRepositoryImpl` qui **chunk** en lots atomiques de ≤ 450. Au niveau **générique** (mono-entité) il n'y a pas de cascade parent→enfants : celle-ci (dossier→cartes) est **domaine-spécifique E9**. E5-3 livre la **primitive de lot borné** réutilisée par E9. [Source: canonical-schema.md#§7 « cascade bornée 450 writes/batch » ; architecture.md#AD-9]

### Frontière de story (ne PAS déborder)

- **E5-3 (cette story)** : `ZSyncEntry`/`ZLwwResolver`/`ZSyncableRepository` (core) + `syncEntries`/`applyMerged` (ports+adaptateurs) + `ZOfflineFirstRepository` (compose local+distant, merge LWW, soft-delete propagé, lot ≤ 450, `Right(unit)` si offline).
- **E5-4** : `ZSyncOrchestrator` (déclenche `sync()` d'un **ensemble** de dépôts enregistrés sur login/reconnexion **débouncée ~400 ms**, best-effort, **échec partiel toléré**). **Hors périmètre** — E5-3 n'a **ni** débounce **ni** registre multi-dépôts.
- **E9** : cascade **parent→enfants** domaine (dossier→cartes) + invariant SRS top-level. **Hors périmètre** (E5-3 livre la primitive de lot générique).
- **`CloudStorageRepository`** (fichiers, E3-3c) : **hors périmètre** (séparé).

### Project Structure Notes

- **Nouveaux (core)** : `packages/zcrud_core/lib/src/domain/sync/z_sync_entry.dart`, `.../sync/z_lww_resolver.dart`, `.../ports/z_syncable_repository.dart` ; exports au barrel `zcrud_core.dart` (ordre alpha).
- **Modifiés (core)** : `.../ports/z_local_store.dart` + `.../ports/z_remote_store.dart` (ajout `syncEntries`/`applyMerged`).
- **Nouveaux (firestore)** : `packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart` ; export au barrel `zcrud_firestore.dart`.
- **Modifiés (firestore)** : `hive_z_local_store.dart`, `firestore_z_remote_store.dart`, `firebase_z_repository_impl.dart` (méthodes additives `syncEntries*`/`applyMerged*`/lot).
- **Tests** : `packages/zcrud_core/test/.../z_lww_resolver_test.dart`, `.../z_sync_entry_test.dart` ; `packages/zcrud_firestore/test/z_offline_first_repository_test.dart` (+ compléments aux tests hive/remote existants).
- **Aucun** ajout de dépendance à `zcrud_core/pubspec.yaml`. Nommage : types publics préfixés `Z` ; fichiers snake_case ; impl sous `lib/src/`.

### Testing standards

- Framework : `flutter_test` ; **core** = tests unitaires purs (résolveur/entry, aucune I/O) ; **firestore** = Hive sur tmpdir (`Hive.init`+`tearDown`) ou `hive_test`, `fake_cloud_firestore` pour le distant (réutiliser les harnais E5-1/E5-2, y compris `_ThrowingFirestore` pour injecter `ServerFailure`).
- Couverture obligatoire mappée aux ACs : résolveur LWW (AC2), `syncEntries` tombstones (AC3), `applyMerged` préserve la méta / anti-`now()` (AC4), lectures local + `getById` soft-deleté→NotFound (AC8), write offline réussit (AC9), `sync()` 5 cas de convergence dont tombstones (AC10), `Right(unit)` offline vs `Left(CacheFailure)` local (AC11), **451→2 lots** (AC12), soft-delete bout-en-bout (AC13), isolation signatures (AC14).
- Gates CI (E1-3/E2-10) : anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation, graphe `CORE OUT=0`, gate:compat — **verts avant `review`** ; `melos run analyze` **ET** `flutter test` **repo-wide** (une régression cross-package d'un ajout de port ne se voit que repo-wide).

### References

- [Source: epics.md#E5 Story E5-3 (ligne 100)] merge LWW sur `updatedAt` ; `is_deleted` hors-entité standardisé ; cascade bornée (AD-9).
- [Source: epics.md#E5 Story E5-4 (ligne 101)] frontière : orchestrateur = *quand* (débounce/multi-dépôts/échec partiel), hors E5-3.
- [Source: architecture.md#AD-9 (lignes 97-100)] offline-first standardisé, LWW `updatedAt`, soft-delete hors-entité, cascade bornée, séparation quand/comment.
- [Source: architecture.md#AD-5 (lignes 79-80)] domaine backend-agnostique ; borne `450`/`WriteBatch` restent dans `zcrud_firestore`.
- [Source: architecture.md#AD-10] désérialisation défensive (`syncEntries`).
- [Source: architecture.md#AD-11] `Either`/flux nus ; `CacheFailure` local vs `ServerFailure` distant (clé de `sync()` offline).
- [Source: architecture.md#AD-16 ; packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart] `ZSyncMeta` (`updated_at`/`is_deleted`, ISO-8601, défensif, `copyWith` à sentinelle).
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_syncable.dart] `updatedAt` = clé LWW.
- [Source: packages/zcrud_core/lib/src/domain/ports/z_local_store.dart:20-79] port local + frontière « merge = E5-3/E5-4 ».
- [Source: packages/zcrud_core/lib/src/domain/ports/z_remote_store.dart:21-54] port distant + frontière cascade ≤450/débounce.
- [Source: packages/zcrud_core/lib/src/domain/ports/z_repository.dart:34-67] surface à étendre par `ZSyncableRepository`.
- [Source: packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart] `_encode`(now)/`_decodeEntity`/`_isVisible`/`_guard`/`ZLocalStoreLog` à réutiliser ; base de `syncEntries`/`applyMerged`.
- [Source: packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart] filtre `is_deleted` de `getAll` ; `_encode`(now) — voies additives sans filtre / brutes pour la sync.
- [Source: packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart:41-64] composition à compléter (`syncEntries`/`applyMerged`/lot).
- [Source: docs/canonical-schema.md#§4 offline-first (lignes 166, 205)] Hive source de vérité, LWW `updated_at`, soft-delete hors-entité, `StudySyncManager` quand/comment.
- [Source: docs/canonical-schema.md#§7 (lignes 287-309)] contrat `sync() → Right(unit)` si déconnecté ; cascade `450 writes/batch` ; `ZLocalStore`/`ZRemoteStore` ; merge la map telle quelle (jamais `Sm2.apply` à la sync).
- [Source: stories/e5-1-firebase-zrepository-impl.md] patron `_encode`/`_decode`/`_isVisible`, invariant corps `id`, `_ThrowingFirestore` (injection `ServerFailure`), isolation.
- [Source: stories/e5-2-zlocalstore-zremotestore.md] ports/adaptateurs composés ; soft-delete par drapeau ; frontière explicite « merge LWW = E5-3 ».

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, tool Skill)

### Debug Log References

- `dart analyze` zcrud_core → RC=0 (No issues found).
- `dart analyze` zcrud_firestore → RC=0 (No issues found).
- `flutter test` zcrud_core → RC=0, **580 tests** (562 antérieurs + 18 sync neufs), aucune régression.
- `flutter test` zcrud_firestore → RC=0, **73 tests** (58 antérieurs E5-1/E5-2 + 15 offline-first neufs), aucune régression.
- `graph_proof.py` → **CORE OUT=0 OK**, ACYCLIQUE OK. Aucune dépendance ajoutée à `zcrud_core/pubspec.yaml`.
- Codegen : ni `zcrud_core` ni `zcrud_firestore` n'utilisent `build_runner` (fichiers écrits à la main, aucun `*.g.dart`) — `melos run generate` sans effet sur ces packages.

### Completion Notes List

- **Décisions de conception appliquées (story)** : `ZOfflineFirstRepository` placé dans `zcrud_firestore` ; tie-break LWW « local fait foi » à `updatedAt` égal (noop si états identiques, sinon push local) ; `applyMerged` préserve `ZSyncMeta` verbatim (jamais `now()`) — anti-ping-pong ; `syncEntries()` inclut les tombstones ; cascade bornée ≤ 450/lot via la constante `kMaxBatchWrites` **locale à `zcrud_firestore`** (jamais dans le cœur).
- **Invariants respectés** : `zcrud_core` reste Dart pur (aucun import `hive`/`cloud_firestore`, aucun type backend en signature publique) ; tous les contrats retournent `Either<ZFailure,T>` ; désérialisation défensive AD-10 (entrée corrompue écartée + loggée, jamais de throw) ; soft-delete `is_deleted` hors-entité ; `Right(unit)` si déconnecté (isConnected==false OU ServerFailure distant), `Left(CacheFailure)` si panne locale.
- **`sync()` bidirectionnel** (pull one-shot + merge LWW + propagation bornée des gagnants locaux) — union par `id`, adopt local immédiat, push distant accumulé puis chunké.
- **Port `ZRemoteStore` étendu de `applyMergedAll`** (en plus de `syncEntries`/`applyMerged`) : la primitive de lot borné vit dans le port distant, la borne `450` reste dans l'adaptateur (AD-5).
- **Dette / écart mineur** : les lectures request-portées du dépôt (`getAll({request})`, `watch(req)`, `count({request})`) délèguent au **snapshot local visible** sans traduire filtres/tri (le port `ZLocalStore` n'expose pas de requête ; pas de schéma disponible côté dépôt générique). Documenté en code — la traduction requête→cache local est hors périmètre E5-3 (composition offline-first + merge LWW).

### File List

**Créés (zcrud_core)**
- `packages/zcrud_core/lib/src/domain/sync/z_sync_entry.dart`
- `packages/zcrud_core/lib/src/domain/sync/z_lww_resolver.dart`
- `packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart`
- `packages/zcrud_core/test/domain/sync/z_sync_entry_test.dart`
- `packages/zcrud_core/test/domain/sync/z_lww_resolver_test.dart`

**Modifiés (zcrud_core)**
- `packages/zcrud_core/lib/src/domain/ports/z_local_store.dart` (ajout `syncEntries`/`applyMerged`)
- `packages/zcrud_core/lib/src/domain/ports/z_remote_store.dart` (ajout `syncEntries`/`applyMerged`/`applyMergedAll`)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports barrel)

**Créés (zcrud_firestore)**
- `packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart`
- `packages/zcrud_firestore/test/z_offline_first_repository_test.dart`

**Modifiés (zcrud_firestore)**
- `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart` (ajout `syncEntries`/`applyMerged`)
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (ajout `syncEntriesAll`/`writeMerged`/`applyMergedAll` + const `kMaxBatchWrites`)
- `packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart` (délégation `syncEntries`/`applyMerged`/`applyMergedAll`)
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (export barrel)

## Questions / Ambiguïtés détectées (pour dev-story / code-review)

1. **Placement de `ZOfflineFirstRepository` : `zcrud_firestore` (retenu) vs `zcrud_core`.** Comme il **compose uniquement des ports neutres** + un résolveur pur, il pourrait vivre dans `zcrud_core`. **Retenu : `zcrud_firestore`**, cohérent avec la structure de packages (*« zcrud_firestore … (offline-first) »*, architecture.md ligne 189) et avec la borne `450` (limite Firestore) qui, elle, ne peut **pas** vivre dans le cœur (AD-5). À confirmer en dev-story ; si placé en core, la primitive de lot ≤450 **doit rester** côté `zcrud_firestore`.
2. **Tie-break LWW à `updatedAt` égal : local-fait-foi (retenu) vs précédence-tombstone.** Retenu : **le local (source de vérité, AD-9) l'emporte** à égalité stricte, `noop` si états identiques. Alternative défendable : **le tombstone gagne** les égalités (éviter de ressusciter une suppression). Impact faible (égalité à la milliseconde rare) mais à **trancher explicitement en code-review** + test.
3. **`updatedAt == null` traité comme « plus ancien » (retenu).** Une entité jamais synchronisée (`updatedAt null`, autorisé par `ZSyncable`/`ZSyncMeta`) **perd** contre toute date. Deux `null` → égalité → local fait foi. À confirmer (alternative : `null` = à pousser inconditionnellement).
4. **`sync()` : `ServerFailure` distant = offline → `Right(unit)`.** On **assimile** toute erreur distante à « déconnecté » (best-effort). Risque : masquer une vraie erreur serveur (permissions, quota) en `Right(unit)`. Atténuation : **loggée** systématiquement ; E5-4 pourra distinguer via une vraie source de connectivité. À valider (option : ne `Right(unit)` que sur un sous-ensemble d'erreurs réseau).
5. **Nouvelles méthodes de port (`syncEntries`/`applyMerged`) : ajout aux ports E5-2 (retenu) vs interface de sync séparée.** Retenu : **enrichir** `ZLocalStore`/`ZRemoteStore` (additif, seuls implémenteurs = adaptateurs du monorepo). Alternative : un mixin/port `ZSyncSource<T>` distinct (ports E5-2 gelés inchangés). Retenu = moins de surface ; à confirmer que geler les ports E5-2 n'est pas une contrainte forte.
6. **`sync()` bidirectionnel (pull+push) vs pull-seul.** L'épic dit « pull one-shot + merge LWW » ; un merge complet **doit aussi pousser** les gagnants locaux (sinon le distant ne converge jamais). Retenu : **bidirectionnel** (pull + merge + push borné). À confirmer que « pull one-shot » n'excluait pas la propagation des gagnants locaux (interprétation : le *pull* est one-shot, la *propagation* accompagne le merge).
7. **Voie d'écriture brute additive sur `FirebaseZRepositoryImpl` (E5-1).** `applyMerged`/`syncEntries` requièrent une écriture **sans `now()`** et une lecture **sans filtre `is_deleted`** — méthodes **additives** sur l'impl E5-1. À confirmer que modifier `firebase_z_repository_impl.dart` (ajout additif, non cassant, tests E5-1 rejoués) est acceptable dans le périmètre E5-3.

<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->
