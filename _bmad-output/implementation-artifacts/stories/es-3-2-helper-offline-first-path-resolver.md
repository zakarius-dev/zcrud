---
baseline_commit: 8c0cf418a5a6861d8b042d6e0df43d08ceefcd5e
---

# Story ES-3.2 : Helper offline-first + résolveur de chemins Firestore bi-topologie

Status: review

<!-- Epic ES-3 : Ports & couche data offline-first bi-topologie. -->
<!-- FR-S13 · AD-1/AD-5/AD-9/AD-10/AD-11/AD-14/AD-16/AD-19/AD-20 · SM-S5. -->
<!-- Dépend d'ES-3.0 (done : registre + ZDecodeContext) et d'ES-3.1 (review : port ZStudyRepository<T> Template Method). -->
<!-- SÉQUENTIELLE dans ES-3 : écrit `zcrud_firestore`. Ne touche PAS `zcrud_core`, ni `zcrud_study_kernel`, ni le sprint-status. -->

## Story

As a **développeur intégrateur** (qui va brancher le même domaine d'étude sur DEUX topologies Firestore réelles — flat IFFD et nested lex — puis porter les ~15 repos offline-first quasi identiques),
I want **une base réutilisable `ZOfflineFirstBoxRepository<T>` dans `zcrud_firestore` qui implémente le point d'extension `persist` d'`ZStudyRepository<T>` (ES-3.1) en offline-first — store local autoritaire, Firestore fire-and-forget, merge Last-Write-Wins sur `updated_at` hors-entité, filtrage `hasPendingWrites` des échos locaux, upload de rattrapage local-only — PLUS un `ZFirestorePathResolver` configurable qui résout le chemin de collection/document bi-topologie SANS coder aucun chemin en dur dans le domaine et SANS fuiter un type Firestore dans sa signature d'entrée**,
so that **consommer le même CRUD offline-first sur les deux topologies sans dupliquer le patron 15× ni ré-inliner un chemin `users/{uid}/study_folders/{folderId}/…` dans le domaine — un `validate` qui REJETTE bloque réellement l'écriture (Template Method ES-3.1), une panne réseau ne casse jamais le succès local (AD-9), et l'`extension` typée d'une entité extensible SURVIT au round-trip cloud→merge→local (ES-3.0 threadée)**.

---

## Contexte & problème mesuré

### Le doublon offline-first à factoriser (origine lex + IFFD)

lex_core/lex_data portent **~15 repos offline-first quasi identiques** — chacun re-inline **le même patron Hive+Firestore**. Mesuré sur disque :

- `lex_douane/packages/lex_data/lib/data/repositories/study_folders_repository_impl.dart` :
  - `_StoredEntry {map, isDeleted}` (l.697-702) + `_readEntry(Box, key)` (l.621-631) : décode le JSON Hive + le flag **hors-entité** `is_deleted` (défensif : un JSON corrompu → `null`, jamais `throw`).
  - `_softDeleteInBox(Box, key)` (l.612-619) : bascule `is_deleted=true` + `updated_at=now` **sans** toucher aux champs métier.
  - `_mergeSnapshotWithLocal(docs)` (l.515-553) : boucle **LWW cloud→Hive** sur la clé `updated_at` **hors-entité** (`_timeFromRaw` accepte `Timestamp`/`DateTime`/String, l.564-569) — le cloud n'écrase le local **que** s'il est **strictement plus récent** ; **PUIS** upload de rattrapage des entrées **local-only non supprimées** (l.541-552).
  - filtrage `hasPendingWrites` (l.502) : `if (snapshot.metadata.hasPendingWrites) return;` — **ignore les échos** d'une écriture locale re-notifiée par le SDK (sinon un merge ré-adopterait une donnée que le local vient juste de dépasser).
  - Firestore **nested** : `users/{uid}` (l.71) → `.collection('study_folders')` (l.75) → `.doc(folderId).collection('flashcards'|'notes'|'mindmaps')` (l.426, cascade).
- `lex_douane/.../mindmaps_repository_impl.dart` : **`Mindmap` n'a PAS de `updatedAt` propre** (dartdoc l.27-31) → *« la clé LWW `updated_at` est **obligatoirement** hors-entité »* (l.278 : `map['updated_at'] = updatedAt.toIso8601String()`). Un merge qui lirait `T.updatedAt` casserait pour `ZMindmap`.
- `lex_douane/.../education/study_sharing_repository_impl.dart` : collection **globale top-level** `study_share_links` (l.71 : `_firestore.collection('study_share_links')`) — **hors** `users/{uid}` (l.28-30). Toutes les autres sont sous `users/{uid}`.
- `iffd/lib/src/data/repositories/firebase_crud_repository_impl.dart` + `iffd/lib/src/utils/functions/databases_functions.dart` : topologie **flat top-level by type** ET le **CRUD quasi-réflexif** à BANNIR — `getFirebaseCollectionName<T>` (l.8-9) : `var name = collectionName ?? FIREBASE_COLLECTION_NAMES[T] ?? T.toString();` → **collection = nom de classe** par réflexion. Le résolveur bi-topologie (l.23-24, l.45-46) : `parentPath != null ? db.doc(parentPath).collection(name) : db.collection(name)` — c'est **l'essence bi-topologie** (flat quand `parentPath==null`, nested sinon), mais avec un `T.toString()` réflexif **interdit** (esprit AD-3/NFR-S8 : la résolution doit être **explicite et statique**).

### Ce qui existe DÉJÀ dans le repo (à COMPOSER, PAS à dupliquer — AD-4)

ES-3.2 **compose** la couche E5 déjà livrée dans `zcrud_firestore` — elle n'en réécrit AUCUNE :

- **`ZStudyRepository<T extends ZEntity>`** (ES-3.1, kernel, `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart`) : **Template Method** — `save` concret appelle `validate(item)` PUIS, seulement si `Right`, l'écriture protégée **`@protected Future<ZResult<T>> persist(T item, {String? collectionId})`** (abstraite). **`persist` est LE point d'extension qu'ES-3.2 implémente** ; `validate` reste un hook overridable (défaut no-op succès). **Ne PAS re-déclarer `save`** (hérité concret).
- **`ZLocalStore<T>`** (port core) + **`HiveZLocalStore<T>`** (`packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart`) : store local **autoritaire** — `put` (matérialise l'éphémère AD-14, réécrit `is_deleted:false`/`updated_at`), `watchAll` (flux nu seedé), `getById`/`getAll` (excluent les tombstones), `softDelete`/`restore` (hors-entité), `syncEntries` (tombstones INCLUS, appariés à `ZSyncMeta`), `applyMerged` (écriture **verbatim** sans `now()`), `clear`, `dispose`. **Tout le `_StoredEntry`/`_readEntry`/décodage défensif Hive est DÉJÀ ici.**
- **`ZLwwResolver`** (`packages/zcrud_core/lib/src/domain/sync/z_lww_resolver.dart`) : `resolve<T>(local?, remote?) → ZLwwDecision` (`noop`/`adoptRemoteIntoLocal`/`pushLocalToRemote`) — merge symétrique déterministe, égalité de foi → `noop` (local autoritaire AD-9).
- **`ZSyncMeta`** (`.../sync/z_sync_meta.dart`) : clés **hors-entité** `kUpdatedAt='updated_at'` / `kIsDeleted='is_deleted'`, `reservedKeys`, `stripReserved(map)`, `fromJson` défensif (`updated_at` absent/mal formé → `null` ; `is_deleted` non-bool → `false`), `updatedAt: DateTime?` / `isDeleted: bool`. **`ZSyncEntry<T> {entity, meta}`** apparie une entité à sa méta.
- **`FirebaseZRepositoryImpl<T>`** (`.../firebase_z_repository_impl.dart`, E5-1/ES-3.0) : patrons de confinement à réutiliser — `_guard` (`FirebaseException→ServerFailure`, jamais `catch(_){}`), `_normalizeIsoInPlace` (`Timestamp`/`DateTime`/`{_seconds,_nanoseconds}`→ISO), fusion `ZSyncMeta` hors-entité dans `_encode`, `kMaxBatchWrites=450`, factory **`.fromRegistry`** (voie recommandée : `registry.decode/encode` thread le `ZDecodeContext` d'ES-3.0).
- **`ZOfflineFirstRepository<T>`** (E5-3, `.../z_offline_first_repository.dart`) : dépôt offline-first composant `ZLocalStore`+`ZRemoteStore` derrière `ZSyncableRepository`, `sync()` **one-shot** pull+merge LWW. **DISTINCT d'ES-3.2** (cf. D2) : pas de listener temps réel, pas de `hasPendingWrites`, pas de résolveur bi-topologie, extends `ZSyncableRepository` (pas le Template Method `ZStudyRepository`).

### La continuité ES-3.0 (DW-ES14-2 soldée, à THREADER ici)

ES-3.0 (done) a rendu `ZcrudRegistry.decode(kind, map)` **context-aware** : un `ZDecodeContext` (câblé au bootstrap, champ du registre) reconstruit l'`extension` **TYPÉE** (`ZNoteAudio` sur `ZSmartNote`) + la provenance `source`. **ES-3.2 est le premier store qui décode réellement des documents cloud** → il **DOIT** décoder par la voie registre context-portée (`FirebaseZRepositoryImpl.fromRegistry` / une fonction `decode` qui thread le contexte). **Un décodage cloud par un `fromMap` nu re-produirait exactement DW-ES14-2** : l'`extension` typée serait détruite au premier merge (`ZOpaqueNoteExtension` au lieu de `ZNoteAudio`). C'est le défaut EXACT soldé en ES-3.0 — ES-3.2 ne doit pas le ré-ouvrir sur la voie store.

### Le piège à contrer (motif dominant — R12/DW-ES25-1)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Risques spécifiques de CETTE story, chacun avec sa garde discriminante (AC + injection R3) :
1. un merge LWW **décoratif** dont la comparaison `updated_at` serait inversée sans qu'aucun test ne rougisse (un écrit ancien écraserait un récent) ;
2. un « offline-first » où une **panne distante ferait échouer `save`** (le local doit rester autoritaire) ;
3. un décodage cloud qui **ne thread PAS `ZDecodeContext`** (extension typée perdue — DW-ES14-2) ;
4. un `is_deleted`/`updated_at` qui **fuit dans l'agrégat sérialisé** (au lieu de rester hors-entité) ;
5. un résolveur qui **résout le mauvais chemin** (flat vs nested) sans détection.

### Ce que cette story NE fait PAS

- **Pas de cascade de suppression** déclarative bornée (registre parent/enfant + `ZFirestoreCascadeBatcher`) = **ES-3.3**.
- **Pas d'orchestrateur multi-dépôts** débouncé = **ES-3.4** (le *quand* ; ES-3.2 n'expose qu'un `sync()` one-shot + un listener temps réel de CE dépôt).
- **Pas de codec camelCase↔snake_case IFFD legacy + gate CI de rétro-compat** = **ES-3.5**.
- **Aucune écriture de `zcrud_core`** ni de `zcrud_study_kernel** (ports déjà livrés — R9 : `zcrud_firestore` est le seul package écrit).
- **Ne rouvre pas DW-ES25-1** (spike R4 des VO-à-invariant : séparé, non bloquant — voir Dépendances/dettes).

---

## Décisions structurantes (tranchées par lecture lex/IFFD + AD + ES-3.1/ES-3.0)

**D1 — `ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>` (kernel), et implémente `persist`.**
ES-3.2 fournit **l'implémentation offline-first du point d'extension `persist`** d'ES-3.1. Étendre `ZStudyRepository<T>` (et non directement `ZSyncableRepository<T>`) est **imposé par le contrat ES-3.1** : `persist` n'existe QUE sur `ZStudyRepository` ; c'est le seul moyen d'hériter le Template Method `save = validate→persist`. **Conséquence graphe** : `zcrud_firestore` gagne une **arête `→ zcrud_study_kernel`** (nouvelle dép directe). **Acyclique-safe** : `zcrud_firestore → zcrud_study_kernel → zcrud_core` est un DAG (le kernel ne dépend QUE de `zcrud_core`) ; `graph_proof.py` ne contrôle qu'**acyclicité + CORE OUT=0** — l'arête ajoutée ne touche NI `zcrud_core` (out-degree inchangé = 0) NI ne crée de cycle. Plusieurs satellites dépendent déjà du kernel (`zcrud_document`/`zcrud_flashcard`/`zcrud_exam`/`zcrud_note`). **Rejeté : extends `ZSyncableRepository`** (ce que fait E5-3) → n'a pas le hook `validate` du Template Method, l'invariant métier (2 niveaux, cible requise) ne serait pas branchable, et `persist` n'existerait pas.

**D2 — COMPOSE la couche E5, n'en DUPLIQUE rien (AD-4). La substance NEUVE = 4 briques.**
`ZOfflineFirstBoxRepository` **compose** un `ZLocalStore<T>` **autoritaire** (défaut `HiveZLocalStore`, injecté) — d'où viennent `_StoredEntry`/`_readEntry`/`_softDeleteInBox`/décodage défensif Hive **déjà écrits** — et un accès Firestore résolu par `ZFirestorePathResolver`. Ce qu'ES-3.2 **ajoute** par-dessus E5-3 (et qui justifie un fichier distinct) :
  1. **listener temps réel** `snapshots(includeMetadataChanges:true)` cross-device (E5-3 n'a qu'un `sync()` one-shot) ;
  2. **filtrage `hasPendingWrites`** des échos locaux (inexistant en E5-3) ;
  3. **`ZFirestorePathResolver`** bi-topologie (flat/nested/global) — E5-3 est mono-topologie (un `collectionPath` fixe) ;
  4. **merge-key hors-entité** paramétrable pour les entités **sans `T.updatedAt`** (`ZMindmap`).
**Rejeté : renommer/étendre `ZOfflineFirstRepository` (E5-3)** → il extends `ZSyncableRepository`, pas le Template Method, et son merge symétrique via deux ports ne porte ni listener ni `hasPendingWrites`. **Rejeté : re-détenir un `Box` Hive brut** dans la classe (comme lex) → dupliquerait `_readEntry`/`_softDeleteInBox`/décodage défensif déjà dans `HiveZLocalStore` (viole AD-4 COMPOSE-not-DUPLICATE). Le `Box` est injecté **via** `HiveZLocalStore`.

**D3 — `ZFirestorePathResolver` : entrée NEUTRE, sortie chemin `String` ; ZÉRO type Firestore dans sa signature ; config explicite/statique.**
La signature d'entrée n'accepte **aucun** type `cloud_firestore` : `resolve({required String kind, String? parentId, String? userId})` (ou un petit descripteur neutre) et **retourne un `String` de chemin** (ex. `'users/u1/study_folders/f1/flashcards'`). Le dépôt fait `_firestore.collection(path)` **en interne** (type `CollectionReference` **confiné**, AD-5/AD-11). La **topologie** est une config **explicite et statique** injectée à la construction (map `kind → règle`) : `flatTopLevel` (IFFD, ex. `flashcards` ou `users/{uid}/flashcards`), `nestedUnderParent` (lex, ex. `users/{uid}/study_folders/{parentId}/flashcards`), `globalTopLevel` (ex. `study_share_links`, **hors** `users/{uid}`). **Le CRUD quasi-réflexif `collection = T.toString()` (IFFD `databases_functions.dart:9`) est BANNI** : aucune dérivation par `runtimeType`/réflexion ; chaque `kind` a un segment de collection **littéral déclaré**. **Aucun chemin en dur dans le domaine** (AD-20) : le domaine (kernel/entités) n'importe jamais le résolveur ; il vit dans `zcrud_firestore`.

**D4 — Merge Last-Write-Wins sur `updated_at` HORS-ENTITÉ (jamais `T.updatedAt`).**
Le comparateur LWW lit `updated_at` **de la méta hors-entité** (`ZSyncMeta.updatedAt`, côté local via `syncEntries` ; côté cloud via `_timeFromRaw(cloudMap['updated_at'])` — tolérant `Timestamp`/`DateTime`/String/`{_seconds,_nanoseconds}`, AD-10), **jamais** d'un champ `updatedAt` interne à `T`. Le cloud n'écrase le local **que si strictement plus récent** (`cloudTime.isAfter(localTime)` ; local absent → adopté ; cloud sans horodatage → **jamais** adopté). Support **obligatoire** des entités **sans `updatedAt`** (`ZMindmap`, cf. lex `mindmaps_repository_impl.dart:27-31`). Réutilise `ZLwwResolver` là où la forme `ZSyncEntry` est disponible (voie `syncEntries` locale) ; la comparaison cloud brute réutilise la même sémantique (« strictement plus récent »).

**D5 — `persist` offline-first : local d'ABORD (autoritaire), Firestore fire-and-forget.**
`persist(item, {collectionId})` = (1) `local.put(item)` — **matérialise l'éphémère** (attribution d'`id` opaque, AD-14) et réécrit `is_deleted:false`/`updated_at=now` (`ZSyncMeta`) ; (2) renvoie le **résultat local DÈS son succès** (`unawaited` sur la propagation distante — ne jamais bloquer sur un timeout réseau, parité E5-3 MAJEUR-1) ; (3) pousse au Firestore résolu en **fire-and-forget** — un échec distant est **loggé** puis **avalé** (AD-9/AD-11), **jamais** propagé au résultat `persist`. `validate` (hérité, overridable) est appelé **avant** `persist` par le `save` Template Method d'ES-3.1 : un `validate→Left` **bloque** `persist` (donc l'écriture) — garanti par ES-3.1, re-prouvé ici bout-en-bout.

**D6 — Filtrage `hasPendingWrites` : ignorer les échos locaux.**
Le listener temps réel (`snapshots(includeMetadataChanges:true)`) **skip** tout snapshot dont `metadata.hasPendingWrites == true` (parité lex `study_folders_repository_impl.dart:502`). Sans ce filtre, une écriture locale re-notifiée par le SDK (avant confirmation serveur) déclencherait un merge qui **ré-adopterait la donnée que le local vient de produire/dépasser** — bruit et risque de régression LWW.

**D7 — Décodage cloud CONTEXTUALISÉ (ES-3.0 threadé).**
Le décodage des documents cloud (merge, listener, `sync`) passe par une fonction `decode` **qui thread le `ZDecodeContext`** — voie recommandée `FirebaseZRepositoryImpl.fromRegistry` (`registry.decode(kind, map)`, contexte = champ du registre câblé au bootstrap) OU un `decode`/`fromMap` explicitement construit sur `registry.decode`. **Interdit** : un `fromMap` nu (tear-off) sur la voie cloud → détruirait l'`extension` typée (DW-ES14-2, soldée ES-3.0). Le décodage reste **défensif** (AD-10) : un document corrompu est **écarté + loggé**, jamais un `throw` qui casse le flux/la page.

**D8 — `is_deleted`/`updated_at` HORS-ENTITÉ (`ZSyncMeta.reservedKeys`), jamais dans l'agrégat.**
Aux frontières d'écriture (local `put`/`applyMerged`, Firestore `set`), `updated_at`/`is_deleted` sont **fusionnés séparément** dans l'enveloppe stockée (Hive JSON + doc Firestore), **jamais** injectés dans le corps sérialisé de `T` (`toMap`) : `ZSyncMeta.stripReserved`/le patron `_encode` d'E5-1 garantissent qu'aucun champ métier n'est touché par `softDelete`/`restore` (AD-16/AD-19). En lecture, ces clés sont **retirées** avant `fromMap` (elles ne sont pas des champs d'entité).

**D9 — Web/gates : `zcrud_firestore` est un package FLUTTER ⇒ HORS périmètre `gate:web-determinism` ; `reserved-keys` intouché.**
`zcrud_firestore` déclare `flutter:` (Firebase/Hive) ⇒ **exclu** de `gate_web_determinism.dart` (qui ne cible que les packages **pur-Dart**, cf. l.40-42). Ses tests tournent sous **`flutter_test` (VM uniquement)** ; `@TestOn('vm')` n'est **PAS** requis (contrairement au kernel pur-Dart) et **aucun run `-p node`** ne s'applique — les tests E5 existants importent d'ailleurs `dart:io` **sans** `@TestOn('vm')`. Aucun **`@ZcrudModel`** n'est ajouté (adapters, pas des modèles) ⇒ **aucun** `.g.dart` neuf, **aucun** `registerZ…`, `gate_reserved_keys.dart` reste **VERT sans toucher** `tool/reserved_keys_gate/**`.

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (R12) : le test associé **ROUGIT par le retrait de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli. L'orchestrateur **rejoue chaque injection R3** (retirer la garde → ROUGE **par cette garde**) et **restaure par édition ciblée** (`diff` vide — R13, JAMAIS `git checkout`). Backend de test : `fake_cloud_firestore` (déjà dev-dep) + `HiveZLocalStore` réel sur box mémoire/tmpdir (parité tests E5).

**AC1 — `ZOfflineFirstBoxRepository<T>` existe, extends `ZStudyRepository<T>`, et implémente `persist` (le point d'extension ES-3.1).**
`class ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>` est déclaré dans `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart` et exporté par le barrel. Il implémente `persist` + les membres hérités abstraits (`watchAll`/`watch`/`getAll`/`getById`/`softDelete`/`restore`/`count`/`sync`/`dispose`) et **NE re-déclare PAS `save`** (Template Method hérité concret). `validate` reste overridable (défaut hérité).
_Test :_ instanciation compile ; `save` (hérité) délègue à `validate` puis `persist` ; le type expose `Stream<List<T>>` nu (non `Stream<Either<…>>`) sur `watchAll`.

**AC2 — Template Method bout-en-bout : `validate→Left` BLOQUE l'écriture (aucun `put` local, aucun push Firestore).** _(discriminant Template Method × ES-3.2)_
Étant donné un `ZOfflineFirstBoxRepository` dont `validate` est overridé `Left(DomainFailure('rejet'))`, quand on `save(item)`, alors : le résultat est ce `Left` exact ; **aucune** écriture locale (le local `getById(item.id)` reste introuvable) **et aucune** écriture Firestore (la collection résolue reste vide).
_Injection R3-a :_ neutraliser l'appel `validate` dans le `save` d'ES-3.1 **OU** faire écrire `persist` avant de vérifier `validate` → ce test ROUGIT (entité écrite malgré le rejet). ⇒ la garde métier est LOAD-BEARING jusqu'au store.

**AC3 — Offline-first : `persist` réussit et le local fait autorité MÊME quand Firestore est en panne (fire-and-forget).** _(discriminant offline)_
Étant donné un Firestore **injecté qui lève** `FirebaseException` à toute écriture (`_ThrowingFirestore`, parité E5) et un `validate` par défaut, quand on `save(item)`, alors `persist` renvoie **`Right(T)`** (matérialisé), `local.getById` retrouve l'entité, et l'échec distant est **loggé** — **jamais** propagé.
_Injection R3-b :_ rendre la propagation Firestore **`await`ée et bloquante** (retirer le fire-and-forget / propager son `Left`) → `save` retourne `Left`/timeout ⇒ ce test ROUGIT. ⇒ le local est prouvé autoritaire.

**AC4 — Matérialisation de l'éphémère dans `persist` (AD-14) — l'`id` opaque est attribué ICI, pas dans le port.**
Étant donné un `item` **éphémère** (`id == null`, `isEphemeral`), quand on `save(item)`, alors le `Right(T)` retourné porte un `id` **non nul** opaque, le corps persisté (local ET Firestore) porte **toujours** ce même `id` (invariant clé↔corps), et une relecture `getById(id)` restitue l'entité.
_Test :_ deux `save` d'items éphémères distincts produisent deux `id` distincts ; l'`id` du corps == l'`id` de la clé de document.

**AC5 — Merge Last-Write-Wins sur `updated_at` HORS-ENTITÉ : le cloud n'écrase que s'il est STRICTEMENT plus récent.** _(cœur discriminant LWW)_
Fixtures ISOLÉES via écriture **verbatim** (méta précise, jamais un seed « propre ») :
  (a) cloud `updated_at` **postérieur** au local → après `sync()`/listener, le local **adopte** le cloud ;
  (b) cloud `updated_at` **antérieur** au local → le local est **conservé** (cloud **ignoré**) ;
  (c) entrée **local-only** (absente du cloud), non supprimée → **upload de rattrapage** vers Firestore ;
  (d) entrée **cloud-only** → adoptée localement.
_Injection R3-c :_ **inverser** la comparaison (`isAfter` → `isBefore`, ou `<` → `>`) dans le merge → la fixture (b) ROUGIT (un écrit ancien écrase un récent). ⇒ le sens du LWW est PROUVÉ.

**AC6 — Merge-key hors-entité fonctionne pour une entité SANS `T.updatedAt` (cas `ZMindmap`).**
Étant donné une entité de test **sans champ `updatedAt`** (miroir `ZMindmap`), quand on merge, alors la clé LWW est lue **exclusivement** de `ZSyncMeta.updated_at` (méta hors-entité) — le merge (a)/(b) d'AC5 reste correct **sans** jamais accéder à un `T.updatedAt` inexistant.
_Injection R3-d :_ router la clé de comparaison vers un getter `T.updatedAt` → **échec de compilation/rejet** pour l'entité sans ce champ (ou merge dégénéré) ⇒ ROUGIT. ⇒ le merge-key hors-entité est prouvé nécessaire.

**AC7 — Filtrage `hasPendingWrites` : un écho local ne déclenche PAS de merge.**
Étant donné le listener temps réel actif, quand un snapshot arrive avec `metadata.hasPendingWrites == true` (écho d'une écriture locale non encore confirmée serveur), alors **aucun merge** n'est appliqué (le local n'est pas ré-adopté depuis son propre écho) ; un snapshot **confirmé** (`hasPendingWrites == false`) déclenche le merge normal.
_Injection R3-e :_ retirer le `if (hasPendingWrites) return;` → un écho local re-merge et une régression LWW/bruit observable apparaît ⇒ ROUGIT.

**AC8 — Décodage cloud CONTEXTUALISÉ (ES-3.0) : l'`extension` typée SURVIT au round-trip cloud→merge→local.** _(discriminant DW-ES14-2)_
Étant donné une entité extensible de test dont l'`extension` est **typée** quand décodée AVEC un `ZDecodeContext` (et opaque sans), quand un document cloud portant cette extension est mergé puis relu (`getById`), alors l'entité restituée porte l'**extension TYPÉE** (pas l'opaque).
_Injection R3-f :_ construire le dépôt avec un `decode` **nu** (sans threader le `ZDecodeContext` / registre sans contexte) → l'extension revient **opaque** ⇒ ce test ROUGIT. ⇒ le threading ES-3.0 sur la voie store est prouvé LOAD-BEARING (le défaut exact soldé en ES-3.0 est re-gardé côté adapter).

**AC9 — Soft-delete/`updated_at` HORS-ENTITÉ : `is_deleted`/`updated_at` ne fuient PAS dans l'agrégat sérialisé.** _(discriminant hors-entité)_
Après `save`/`softDelete`, le corps **métier** sérialisé de `T` (via `toMap`) **ne contient NI** `is_deleted` **NI** `updated_at` — ces clés vivent **uniquement** dans l'enveloppe Hive/le doc Firestore (`ZSyncMeta`, hors-entité). `softDelete(id)` bascule `is_deleted=true` sans toucher un champ métier ; `restore(id)` l'inverse ; les lectures visibles excluent les tombstones (cohérent get/getAll/watch).
_Injection R3-g :_ injecter `is_deleted`/`updated_at` dans le corps `toMap` (retirer `stripReserved`/la séparation méta) → une garde d'assertion (le corps métier contient une clé réservée) ROUGIT.

**AC10 — `ZFirestorePathResolver` bi-topologie : flat (IFFD), nested-under-parent (lex), global (share links).** _(discriminant chemin)_
Fixtures ISOLÉES :
  (a) `flatTopLevel` → `resolve(kind:'flashcards', userId:'u1')` == chemin flat déclaré (ex. `users/u1/flashcards` ou `flashcards` selon config) ;
  (b) `nestedUnderParent` → `resolve(kind:'flashcards', userId:'u1', parentId:'f1')` == `users/u1/study_folders/f1/flashcards` ;
  (c) `globalTopLevel` → `resolve(kind:'study_share_links')` == `study_share_links` (**hors** `users/{uid}`) ;
  (d) un `nested` **sans `parentId`** → `Left`/erreur explicite (jamais un chemin muet incorrect).
_Injection R3-h :_ échanger les branches flat↔nested (ou faire pointer `nested` sur le chemin flat) → la fixture (b) résout le mauvais chemin, `save` écrit dans la mauvaise collection et `getById` par la topologie correcte échoue ⇒ ROUGIT.

**AC11 — Anti-réflexion & backend-agnostique : aucun `T.toString()`/`runtimeType` pour le chemin ; ZÉRO type Firestore/Hive dans une signature publique (AD-5/AD-11/NFR-S8).**
`ZFirestorePathResolver` dérive le segment de collection d'une **config littérale déclarée** par `kind`, **jamais** de `T.toString()`/`runtimeType` (bannissement IFFD `databases_functions.dart:9`). Aucune signature publique de `ZOfflineFirstBoxRepository`/`ZFirestorePathResolver` n'expose `FirebaseFirestore`/`CollectionReference`/`Query`/`Timestamp`/`DocumentSnapshot`/`WriteBatch`/`Box`/`HiveInterface` — tout reste `ZResult<…>`/`Stream<List<T>>`/`String`/types du cœur. L'injection d'une instance `FirebaseFirestore` et d'un `ZLocalStore` est la SEULE couture.
_Test :_ inspection statique via un miroir de type (le barrel n'exporte aucun type backend ; les signatures publiques sont nues) ; un `grep` d'assertion sur l'absence de `runtimeType`/`.toString()` dans la dérivation de chemin.

**AC12 — `sync()` best-effort : `Right(unit)` si déconnecté/panne distante ; le local n'est jamais invalidé.**
`sync()` one-shot : pull du snapshot serveur au chemin résolu → merge LWW cloud→local + upload de rattrapage local-only → `Right(unit)`. Une **panne distante** (`FirebaseException`, injectée) est assimilée à « offline » → **`Right(unit)`** (loggé), le local intact. (Le *quand*/débounce multi-dépôts reste ES-3.4.)
_Test :_ Firestore en panne → `sync()` == `Right(unit)`, l'état local inchangé ; Firestore sain avec un doc plus récent → `sync()` adopte + `Right(unit)`.

**AC13 — Vérif verte REPO-WIDE (R9).**
`melos run generate` OK (**aucun nouveau `.g.dart`** attendu) → `melos run analyze` **RC=0** → `flutter test` de `zcrud_firestore` **RC=0** → `melos run test` **RC=0** → `dart run scripts/ci/gate_reserved_keys.dart` VERT (**inchangé**) → `dart run scripts/ci/gate_web_determinism.dart` VERT (`zcrud_firestore` **exclu**, Flutter) → `melos run verify` VERT (`codegen-distribution`, `graph_proof` **ACYCLIQUE + CORE OUT=0** avec la **nouvelle arête `zcrud_firestore→zcrud_study_kernel`**, `secrets`, `reflectable`).

---

## Tasks / Subtasks

- [x] **T1 — Ajouter l'arête `zcrud_firestore → zcrud_study_kernel` (D1).** (AC1, AC13)
  - [x] `packages/zcrud_firestore/pubspec.yaml` : ajouter `zcrud_study_kernel: ^0.1.0` sous `dependencies` ; mettre à jour le commentaire d'arêtes AD-1 (l'arête `zcrud_core` **et** `zcrud_study_kernel`, DAG). `dart pub get`/`melos bootstrap`.
  - [x] Vérifier `graph_proof.py` : ACYCLIQUE + CORE OUT=0 restent VERTS avec l'arête ajoutée.

- [x] **T2 — `ZFirestorePathResolver` (D3, AC10, AC11).**
  - [x] Créer `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart` : config **explicite statique** (map `kind → règle` : `flatTopLevel`/`nestedUnderParent`/`globalTopLevel` avec segments **littéraux**). `String resolveCollection({required String kind, String? userId, String? parentId})` (+ `resolveDoc(...id)` si utile) → **chemin `String` neutre** ; `Left`/exception explicite si `nested` sans `parentId` (AC10-d). **Aucun** `T.toString()`/`runtimeType`. **Aucun** type Firestore en signature.
  - [x] Dartdoc : bi-topologie (flat IFFD / nested lex / global share-links), bannissement de la réflexion (esprit AD-3/NFR-S8), aucun chemin en dur dans le domaine (AD-20).

- [x] **T3 — `ZOfflineFirstBoxRepository<T>` : `persist` + lectures offline-first (D1, D2, D5, D8).** (AC1-AC4, AC9)
  - [x] Créer `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart` : `class ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>`. Injection : `ZLocalStore<T> local` (défaut `HiveZLocalStore`), `FirebaseFirestore firestore`, `ZFirestorePathResolver resolver`, `String kind`, `T Function(Map) decode` **context-portée** (D7) + `Map Function(T) encode`, comparateur/merge-key LWW hors-entité, `Future<bool> Function()? isConnected`, logger neutre optionnel. **NE PAS re-déclarer `save`.**
  - [x] `@override @protected persist(item, {collectionId})` : `local.put(item)` (matérialise l'éphémère) → renvoie le résultat local DÈS succès → `unawaited` push Firestore fire-and-forget au chemin résolu (échec loggé + avalé, AD-9). `is_deleted`/`updated_at` fusionnés **hors-entité** (`ZSyncMeta`, jamais dans `toMap`).
  - [x] Lectures = **local autoritaire** : `watchAll`/`watch`/`getAll`/`getById`/`count` délèguent au `local` (flux nus) ; `softDelete`/`restore` = `local.*` + propagation distante fire-and-forget (parité E5-3). `dispose` ferme listener + local.

- [x] **T4 — Merge LWW cloud→local + listener temps réel + `hasPendingWrites` + rattrapage (D4, D6, D7).** (AC5-AC8, AC12)
  - [x] `_mergeSnapshotWithLocal(docs)` : pour chaque doc, décoder **contextuellement** (D7, défensif AD-10), comparer `ZSyncMeta.updated_at` cloud (via `_timeFromRaw`, tolérant `Timestamp`/`DateTime`/`{_seconds,_nanoseconds}`/String) vs local (`syncEntries`) ; adopter (`local.applyMerged`, **verbatim** sans `now()`) **ssi** cloud **strictement plus récent** ou local absent ; **upload de rattrapage** des locaux non supprimés absents du cloud.
  - [x] Listener `snapshots(includeMetadataChanges:true)` : **skip** `hasPendingWrites==true` (D6) ; sinon merge. Erreurs routées vers le log/canal (jamais un `throw` non géré, parité E5-1 MEDIUM-1). Tracé pour `dispose`.
  - [x] `sync()` one-shot : `get(serverAndCache)` au chemin résolu → merge → rattrapage → `Right(unit)` ; `FirebaseException` → « offline » → `Right(unit)` (loggé) ; `isConnected==false` → `Right(unit)` (court-circuit).

- [x] **T5 — Exporter + barrel (AC1).**
  - [x] `export 'src/data/z_firestore_path_resolver.dart';` et `export 'src/data/z_offline_first_box_repository.dart';` dans `packages/zcrud_firestore/lib/zcrud_firestore.dart` (commentaire ES-3.2/FR-S13 ; signatures NUES, aucun type backend exporté).

- [x] **T6 — Tests à pouvoir discriminant (R2, R12).** (AC1-AC12)
  - [x] Créer `packages/zcrud_firestore/test/z_offline_first_box_repository_test.dart` et `packages/zcrud_firestore/test/z_firestore_path_resolver_test.dart` (`flutter_test`, VM ; `fake_cloud_firestore` + `HiveZLocalStore` réel ; `_ThrowingFirestore` pour la panne).
  - [x] Fixtures ISOLÉES par AC : Template Method bloquant (AC2), offline autoritaire (AC3), matérialisation éphémère (AC4), LWW (a)/(b)/(c)/(d) (AC5), merge-key sans `T.updatedAt` (AC6), `hasPendingWrites` (AC7), extension typée round-trip cloud (AC8, entité extensible de test + `ZDecodeContext`), hors-entité non fuité (AC9), résolveur (a)/(b)/(c)/(d) (AC10), anti-réflexion/signatures nues (AC11), `sync` best-effort (AC12).
  - [x] Commentaires R3 dans chaque test : quelle inversion/retrait fait ROUGIR (a→h).

- [x] **T7 — Rejouer les injections R3 (orchestrateur).** (AC2, AC3, AC5, AC6, AC7, AC8, AC9, AC10)
  - [x] R3-a..R3-h exécutées puis restaurées par **édition ciblée** (`diff` vide) ; consigner le message rouge exact de chaque garde.

- [x] **T8 — Vérif verte REPO-WIDE (R9).** (AC13)
  - [x] `melos run generate` (0 `.g.dart` neuf) → `melos run analyze` RC=0 → `flutter test` zcrud_firestore RC=0 → `melos run test` RC=0 → `gate_reserved_keys` VERT (registrars **inchangé**) → `gate_web_determinism` VERT → `melos run verify` VERT (graph ACYCLIQUE + CORE OUT=0 avec l'arête ajoutée).

---

## Dev Notes

### Patrons d'architecture & contraintes (AD)

- **AD-1 / AD-17 (acyclique, CORE OUT=0)** — nouvelle arête `zcrud_firestore → zcrud_study_kernel` (D1) : DAG (`→ zcrud_core` only pour le kernel), `graph_proof` inchangé sur les invariants. [Source: `scripts/dev/graph_proof.py:74-97` ; kernel `packages/zcrud_study_kernel/pubspec.yaml:32`]
- **AD-5 / AD-11 (backend-agnostique, `Either`/flux nus)** — `cloud_firestore`/`hive` confinés à `zcrud_firestore` ; aucune signature publique n'expose un type backend ; opérations `ZResult<…>`, flux `Stream<List<T>>` **nus**, chemins `String` neutres. [Source: `firebase_z_repository_impl.dart:9-13` ; ports `z_local_store.dart`/`z_remote_store.dart`]
- **AD-9 / AD-16 / AD-19 (offline-first)** — local autoritaire, distant fire-and-forget, merge LWW sur `updated_at` **hors-entité** (`ZSyncMeta`), soft-delete `is_deleted` hors-entité, `sync()` best-effort (`Right(unit)` si déconnecté). [Source: `z_offline_first_repository.dart:114-281` ; `z_sync_meta.dart:27-73` ; lex `study_folders_repository_impl.dart:515-553`]
- **AD-10 (défensif)** — décodage cloud tolérant (doc corrompu → écarté + loggé, jamais `throw`) ; `ZSyncMeta.fromJson` défauts sûrs ; `_normalizeIsoInPlace`/`_timeFromRaw` tolèrent `Timestamp`/`DateTime`/`{_seconds,_nanoseconds}`/String. [Source: `firebase_z_repository_impl.dart:304-402` ; `z_sync_meta.dart:70-73`]
- **AD-14 (matérialisation de l'éphémère)** — attribution d'`id` opaque dans `persist` (via `local.put`), pas dans le port ES-3.1 (AC5 ES-3.1). Le corps porte toujours son `id` (invariant clé↔corps). [Source: `z_local_store.dart:60-63` ; `firebase_z_repository_impl.dart:724-748`]
- **AD-20 (aucun chemin en dur dans le domaine)** — la topologie vit dans le résolveur (`zcrud_firestore`) ; le kernel/les entités n'importent jamais un chemin de collection. [Source: epics ES-3.2 AC l.522-528]
- **AD-4 (COMPOSE-not-DUPLICATE)** — composer `ZLocalStore`/`HiveZLocalStore` + `ZLwwResolver` + `ZSyncMeta` ; ne PAS re-détenir un `Box` brut ni ré-écrire `_readEntry`/`_softDeleteInBox`. [Source: `hive_z_local_store.dart` ; `z_lww_resolver.dart`]
- **ES-3.1 (Template Method)** — `persist` est le `@protected` abstrait ; `save = validate→persist` hérité concret, **NE PAS le re-déclarer** ; `validate→Left` bloque `persist`. [Source: `es-3-1-depot-etude-generique.md` D1/D2 ; `z_study_repository.dart`]
- **ES-3.0 (ZDecodeContext)** — décoder le cloud par `registry.decode`/`.fromRegistry` (contexte câblé au bootstrap) pour préserver l'`extension` typée. [Source: `es-3-0-registre-preserve-extension-immuabilite.md` ; `firebase_z_repository_impl.dart:134-200`]

### Source tree — fichiers à toucher

- **NEW** `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart` — la base offline-first (implémente `persist`).
- **NEW** `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart` — le résolveur bi-topologie.
- **NEW** `packages/zcrud_firestore/test/z_offline_first_box_repository_test.dart` — tests discriminants.
- **NEW** `packages/zcrud_firestore/test/z_firestore_path_resolver_test.dart` — tests résolveur.
- **UPDATE** `packages/zcrud_firestore/lib/zcrud_firestore.dart` — `export` des deux fichiers.
- **UPDATE** `packages/zcrud_firestore/pubspec.yaml` — dép `zcrud_study_kernel` (D1) + commentaire AD-1.
- **⛔ NE PAS TOUCHER** : `zcrud_core`, `zcrud_study_kernel` (ports/port ES-3.1 déjà livrés — R9), `tool/reserved_keys_gate/**` (AC13/D9), tout `*.g.dart`, `z_offline_first_repository.dart` (E5-3, DISTINCT — D2), le sprint-status (orchestrateur).

### Fichiers UPDATE — état actuel & ce qui doit être préservé

- `packages/zcrud_firestore/lib/zcrud_firestore.dart` : barrel exportant E5-1/E5-2/E5-3. **Préserver** tous les exports existants + le dartdoc d'isolation AD-5 ; **ajouter** deux lignes `export` (commentaire ES-3.2/FR-S13). Ne rien retirer.
- `packages/zcrud_firestore/pubspec.yaml` : **préserver** toutes les dépendances (flutter, cloud_firestore, firebase_core, hive, hive_flutter, zcrud_core, fake_cloud_firestore) ; **ajouter** `zcrud_study_kernel: ^0.1.0` ; adapter le commentaire d'arêtes AD-1 (désormais `zcrud_core` **et** `zcrud_study_kernel`). Ne PAS ajouter de secret/endpoint.

### Injections R3 prévues (à rejouer par l'orchestrateur, restaurées par édition ciblée)

- **R3-a** (AC2) : neutraliser l'appel `validate` du `save` Template Method → entité écrite malgré le rejet → ROUGE.
- **R3-b** (AC3) : rendre le push Firestore `await`é/bloquant (retirer `unawaited`/propager son `Left`) → `save` échoue en panne réseau → ROUGE.
- **R3-c** (AC5) : inverser la comparaison LWW (`isAfter`→`isBefore`) → fixture (b) (cloud ancien écrase local récent) → ROUGE.
- **R3-d** (AC6) : router la clé LWW vers `T.updatedAt` → entité sans ce champ → merge dégénéré/compile-fail → ROUGE.
- **R3-e** (AC7) : retirer `if (hasPendingWrites) return;` → écho local re-mergé → ROUGE.
- **R3-f** (AC8) : décoder le cloud par un `fromMap` nu (sans `ZDecodeContext`) → extension opaque au lieu de typée → ROUGE.
- **R3-g** (AC9) : injecter `is_deleted`/`updated_at` dans `toMap` → garde « corps métier contient clé réservée » → ROUGE.
- **R3-h** (AC10) : échanger les branches flat↔nested du résolveur → mauvais chemin → `getById` échoue → ROUGE.

### Testing standards

- `zcrud_firestore` = package **Flutter** ⇒ tests `flutter test` (VM). **Pas** de `@TestOn('vm')` requis, **pas** de run `-p node` (exclu de `gate_web_determinism` — packages pur-Dart uniquement, D9). Parité : les tests E5 importent `dart:io` sans `@TestOn`.
- **Pouvoir discriminant (R12)** : chaque garde naît avec sa **fixture d'échec isolée (R2)** ; seeds LWW par écriture **verbatim** (méta précise via `applyMerged`/doc Firestore direct), **jamais** un seed « propre » qui masque la sémantique LWW (parité `z_offline_first_repository_test.dart`).
- **Pas de test powerless** : ne PAS « prouver » l'offline-first ou le LWW par un chemin qui ne dépend pas de la garde (ex. lire directement le local sans passer par `save`/`sync`). Le test AC8 **doit** faire un vrai round-trip cloud→merge→`getById` et observer le **type** de l'extension (pas seulement « le contexte a été passé »).
- **Backend** : `fake_cloud_firestore` (dev-dep existante) + `HiveZLocalStore` réel (box mémoire/tmpdir, parité E5-2/E5-3) ; `_ThrowingFirestore` pour la panne distante.

### Points d'attention dev

1. **Ne PAS re-déclarer `save`** : c'est le Template Method hérité d'ES-3.1 — l'override casserait la garde `validate→persist`. Implémenter **uniquement** `persist` + les membres hérités abstraits.
2. **`persist` `@protected`** : la signature doit matcher **exactement** `ZStudyRepository.persist(T item, {String? collectionId})` (sinon override invalide). `meta` est déjà transitif via le kernel.
3. **`collectionId` vs `ZFirestorePathResolver`** : `persist` reçoit un `collectionId?` (compat port) ; la topologie réelle (parentId/userId → chemin) est résolue par le résolveur. Clarifier la sémantique : `collectionId` peut porter le `parentId` (nested) ou être ignoré (flat/global) — documenter le mapping dans le dartdoc.
4. **Décodage cloud = voie registre context-portée** (D7) : préférer `FirebaseZRepositoryImpl.fromRegistry` OU un `decode` construit sur `registry.decode`. **Jamais** un tear-off `Xxx.fromMap` nu sur le cloud (DW-ES14-2).
5. **`hasPendingWrites`** : c'est le piège offline-first le plus subtil — sans le filtre, le listener re-merge l'écho local et peut annuler une écriture plus fraîche. Le tester explicitement (AC7).
6. **Merge-key hors-entité** : lire `updated_at` de `ZSyncMeta`/du map cloud brut, **jamais** d'un getter `T.updatedAt` (ZMindmap n'en a pas). C'est un invariant, pas un détail (AC6).
7. **Isolation E5-3** : ne pas confondre avec `ZOfflineFirstRepository` (E5-3) — fichier, sur-port et rôle DISTINCTS (D2). Ne pas le modifier.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-3.2` (l.508-532), FR-S13 (l.117), objectif ES-3 (l.485-487)]
- [Source: `es-3-1-depot-etude-generique.md` — port `ZStudyRepository<T>` (Template Method `save→validate→persist`), `persist` `@protected`, AC5 matérialisation admise]
- [Source: `es-3-0-registre-preserve-extension-immuabilite.md` — `ZDecodeContext`, DW-ES14-2 soldée, voie registre du store]
- [Source: `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` — confinement Firestore, `_guard`, `_normalizeIsoInPlace`, `.fromRegistry` (l.181-200), `kMaxBatchWrites=450`]
- [Source: `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart` — store local autoritaire (put/syncEntries/applyMerged/softDelete)]
- [Source: `packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart` — E5-3 offline-first composé (DISTINCT), fire-and-forget MAJEUR-1, `Right(unit)` offline]
- [Source: `packages/zcrud_core/lib/src/domain/sync/{z_lww_resolver.dart,z_sync_meta.dart,z_sync_entry.dart}` — LWW, méta hors-entité, appariement]
- [Source: `packages/zcrud_core/lib/src/domain/ports/{z_local_store.dart,z_remote_store.dart}` — ports neutres offline-first]
- [Source: lex `packages/lex_data/lib/data/repositories/study_folders_repository_impl.dart` — `_StoredEntry`/`_readEntry` (l.621-702), `_softDeleteInBox` (l.612-619), `_mergeSnapshotWithLocal` (l.515-553), `hasPendingWrites` (l.502), nested `users/{uid}/study_folders/…` (l.68-75)]
- [Source: lex `packages/lex_data/lib/data/repositories/mindmaps_repository_impl.dart:27-31,278` — merge-key hors-entité obligatoire (Mindmap sans updatedAt)]
- [Source: lex `packages/lex_data/lib/data/repositories/education/study_sharing_repository_impl.dart:28-30,71` — collection globale `study_share_links` hors `users/{uid}`]
- [Source: iffd `lib/src/data/repositories/firebase_crud_repository_impl.dart:30-49` + `lib/src/utils/functions/databases_functions.dart:8-9,23-24,45-46` — bi-topologie flat/nested via `parentPath` + CRUD quasi-réflexif `T.toString()` À BANNIR]
- [Source: `scripts/dev/graph_proof.py:74-97` (acyclicité + CORE OUT=0) ; `scripts/ci/gate_web_determinism.dart:40-42` (packages Flutter exclus)]
- [Source: `epic-es-2-retrospective.md` — R2 (fixture d'échec isolée), R9 (vérif REPO-WIDE), R10 (garde dérivée du disque), R12 (test powerless), R13 (édition ciblée) ; DW-ES25-1]

### Project Structure Notes

- Chemins conformes à l'épic (`z_offline_first_box_repository.dart`, `z_firestore_path_resolver.dart` sous `lib/src/data/`) et à la convention `zcrud_firestore` (barrel `lib/zcrud_firestore.dart`, impl `lib/src/data/`). Nommage `Z…`, snake_case, tests `*_test.dart`. Aucune variance détectée.
- Membres **`data`** (adapters) — cohérents avec `firebase_z_repository_impl.dart`/`hive_z_local_store.dart`/`z_offline_first_repository.dart` déjà dans `lib/src/data/`.

### Dépendances / dettes

- **Dépend de** ES-3.0 (done) et **ES-3.1** (statut `review` au moment de la création : le port `ZStudyRepository<T>`/`persist` doit être **`done` et vert** avant le `dev-story` d'ES-3.2 — l'orchestrateur le confirme sur disque). ES-3.2 **n'écrit PAS** le kernel.
- **DW-ES25-1** (rappel, **NON traité ici**) : le prototype R4 de la garde `(h)` des VO-à-invariant reste **dû dans ES-3** (spike séparé, non bloquant — rétro ES-2 §7 pt.3). ES-3.2 ne l'ouvre pas.
- **Aval** : `ES-3.3` (cascade déclarative bornée), `ES-3.4` (orchestrateur multi-dépôts débouncé — le *quand* du `sync`), `ES-3.5` (codec camelCase↔snake_case IFFD legacy + gate CI rétro-compat). ES-3.2 pose la base ; ces trois s'y branchent.
- **Dette possible (à consigner si rencontrée, pas à imposer)** : si `persist({collectionId})` du port ES-3.1 s'avère trop pauvre pour porter à la fois `userId` + `parentId` bi-topologie, NOTER le besoin d'un descripteur de contexte neutre côté port (kernel) **sans** l'imposer dans cette story (R9 : une seule story écrit le kernel).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

Vérif verte REPO-WIDE rejouée réellement sur disque (RC observés) :

| Vérification | Résultat | RC |
|---|---|---|
| `melos run generate` | build_runner SUCCESS ; **0 `.g.dart` neuf/modifié** (adapters, aucun `@ZcrudModel`) | 0 |
| `dart analyze` (zcrud_firestore) | No issues found! | 0 |
| `flutter test` (zcrud_firestore) | **119 tests passés** (29 neufs ES-3.2 + 90 E5 pré-existants) | 0 |
| `melos run analyze` (repo-wide, 18 pkgs) | SUCCESS | 0 |
| `melos run test` (repo-wide) | SUCCESS (zcrud_core 927 + tous membres) | 0 |
| `graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** · nouvelle arête `zcrud_firestore → zcrud_study_kernel` présente (34 arêtes) | 0 |
| `gate_reserved_keys.dart` | OK (volet A+B+couverture) — **inchangé** (aucun `tool/reserved_keys_gate/**` touché) | 0 |
| `gate_web_determinism.dart` | OK (`zcrud_firestore` Flutter → EXCLU, D9) | 0 |
| `prove_gates.dart` | **41 OK, 0 FAIL** | 0 |
| `melos run verify` (miroir CI) | tous gates verts (graph_proof, melos, reflectable, secrets, codegen, codegen-distribution, compat, web, reserved-keys) | 0 |

### Completion Notes List

**Conception (comment persist/merge/resolver sont câblés).**
- `ZOfflineFirstBoxRepository<T extends ZEntity> extends ZStudyRepository<T>` (D1) : `save` **hérité concret** (Template Method `@nonVirtual` d'ES-3.1) **non re-déclaré** ; seul `persist` (`@protected @override`) + les membres hérités abstraits sont implémentés. Nouvelle arête `zcrud_firestore → zcrud_study_kernel` (pubspec) — DAG (kernel→core only), CORE OUT=0 préservé.
- **persist (D5)** : `local.put(item)` (matérialise l'éphémère AD-14, réécrit méta) → renvoie le résultat local DÈS succès → `unawaited(_bestEffortPushFresh(...))` fire-and-forget (échec loggé + avalé, jamais propagé). `collectionId` du port surcharge le `parentId` de topologie nested (Dev Notes #3).
- **merge LWW (D4)** : `_mergeSnapshotWithLocal(id→map)` compare `updated_at` **hors-entité** — cloud (`_timeFromRaw`, tolérant `Timestamp`/`DateTime`/`{_seconds,_nanoseconds}`/String) vs local (`ZSyncEntry.updatedAt`, méta) ; adopte (`local.applyMerged` verbatim) SSI cloud **strictement plus récent** OU local absent ; PUIS upload de rattrapage des locaux non supprimés absents du cloud. **Jamais `T.updatedAt`** (compile-fail structurel — AC6/R3-d).
- **listener (D6)** : `snapshots(includeMetadataChanges:true)` → `handleCloudSnapshot(docs, hasPendingWrites)` **skip** les échos locaux (`hasPendingWrites==true`) puis merge. Seam `@visibleForTesting` à signature **NEUTRE** (`List<MapEntry<String,Map>>`, aucun type Firestore) — testabilité de `hasPendingWrites` sans dépendre de la métadonnée du fake.
- **décodage cloud (D7)** : voie `decode` **threadée au `ZDecodeContext`** (registry.decode) — l'`extension` typée survit au round-trip cloud→merge→local (AC8, anti DW-ES14-2). Défensif (AD-10) : doc corrompu écarté + loggé.
- **hors-entité (D8)** : `_cloudMap` écrit `id`/méta PUIS le corps **stripé** (`ZSyncMeta.stripReserved`) épandu **en dernier** — garde LOAD-BEARING : sans strip, un corps fuité clobbererait la méta autoritaire (AC9/R3-g).
- **sync() (AC12)** : best-effort — `isConnected==false`/`FirebaseException`/chemin non résolu → `Right(unit)` (loggé, local intact) ; panne LOCALE de merge → `Left`.
- **`ZFirestorePathResolver` (D3)** : table `kind → ZFirestorePathRule` littérale ; `resolveCollection/resolveDoc` → chemin `String` neutre (flat / nested / global) ou `Left(DomainFailure)` explicite (kind inconnu, nested sans `parentId`, user-scopé sans `userId`). **Aucun `T`/`runtimeType`/`.toString()`** — le CRUD quasi-réflexif IFFD est structurellement impossible (AC11).

**Pouvoir discriminant (R12) — 8 injections R3 rejouées RÉELLEMENT sur disque, puis restaurées par édition ciblée (`diff==0` re-vérifié, tests re-verts). Messages ROUGES EXACTS capturés :**

| Inj. | AC | Garde retirée | Message ROUGE exact |
|---|---|---|---|
| **R3-a** | AC2 | `validate` neutralisé dans le `save` Template Method (probe KERNEL transitoire, restauré `diff==0`) | `AC2 … [E]  Expected: true  Actual: <false>` (le rejet n'est plus bloquant : `res.isLeft()` devient faux, l'entité est écrite) |
| **R3-b** | AC3 | push Firestore **awaité + propagé** (retrait `unawaited` + try/catch de `_bestEffortSet`) | `AC3 … [E]  [firestore/unavailable] null` (la `FirebaseException` remonte hors de `save` — le succès offline est cassé) |
| **R3-c** | AC5 | LWW inversé `isAfter → isBefore` | `AC5 … [E]  Expected: 'cloud-a'  Actual: 'local-a'` (le cloud plus récent n'est plus adopté ; un ancien écraserait un récent) |
| **R3-d** | AC6 | clé LWW routée vers `T.updatedAt` (`localEntry?.entity.updatedAt`) | `dart analyze [E]  The getter 'updatedAt' isn't defined for the type 'T'. … undefined_getter` (compile-fail : la merge-key DOIT être hors-entité) |
| **R3-e** | AC7 | `if (hasPendingWrites) return;` retiré | `AC7 … [E]  Expected: 'local'  Actual: 'cloud'` (l'écho local re-merge) |
| **R3-f** | AC8 | dépôt construit avec un registre **sans** `ZDecodeContext` (decode nu) | `AC8 … [E]  Expected: <Instance of '_TypedExt'>  Actual: <Instance of '_OpaqueExt'>` (extension revient opaque — DW-ES14-2) |
| **R3-g** | AC9 | `ZSyncMeta.stripReserved` retiré de `_cloudMap` | `AC9 R3-g … [E]  Expected: false  Actual: <true>` (le corps fuité `is_deleted:true` clobbe la méta autoritaire) |
| **R3-h** | AC10 | branche `nested` du résolveur pointée sur le chemin flat | `AC10 (b) … [E]  Expected: 'users/u1/study_folders/f1/flashcards'  Actual: 'users/u1/flashcards'` (mauvaise collection résolue) |

Aucun test POWERLESS : chaque garde rougit **par le retrait de la garde exacte** qu'elle prouve. Restauration vérifiée (kernel `git diff` vide ; resolver/repo/tests re-verts).

**Notes.**
- **Hors périmètre strict, nécessaire** : `example/pubspec.yaml` (app STANDALONE, HORS melos/graph_proof) a reçu 2 overrides CONSOMMATEUR `path` (`zcrud_study_kernel`, `zcrud_annotations` transitif) — sinon la nouvelle dép transitive `^0.1.0` était cherchée sur pub.dev et `dart pub get` de l'exemple échouait. Aucun package sous `packages/` autre que `zcrud_firestore` n'a été modifié. `example/pubspec.lock` reste EXCLU du commit (CLAUDE.md).
- `zcrud_core`, `zcrud_study_kernel` (déliverable), `tool/reserved_keys_gate/**`, `z_offline_first_repository.dart` (E5-3) : **INTOUCHÉS**. Aucun `.g.dart` régénéré/modifié.

### File List

**NEW**
- `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart`
- `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart`
- `packages/zcrud_firestore/test/z_firestore_path_resolver_test.dart`
- `packages/zcrud_firestore/test/z_offline_first_box_repository_test.dart`

**UPDATE**
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (exports ES-3.2, tri alphabétique préservé)
- `packages/zcrud_firestore/pubspec.yaml` (arête `zcrud_study_kernel: ^0.1.0` + commentaire AD-1/AD-17)
- `example/pubspec.yaml` (overrides consommateur `zcrud_study_kernel`/`zcrud_annotations` — hors périmètre packages, requis pour `dart pub get`)
