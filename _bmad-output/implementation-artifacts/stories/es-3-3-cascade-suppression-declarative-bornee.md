---
baseline_commit: 8c0cf418a5a6861d8b042d6e0df43d08ceefcd5e
---

# Story ES-3.3 : Cascade de suppression déclarative et bornée

Status: review

<!-- Epic ES-3 : Ports & couche data offline-first bi-topologie. -->
<!-- FR-S14 · NFR-S9 · AD-21 (cascade déclarative bornée) / AD-9 / AD-16 / AD-19 / AD-5 / AD-11 / AD-20 / AD-1 / AD-17 · SM-S5/SM-S6. -->
<!-- Dépend d'ES-3.0 (done : ZDecodeContext), ES-3.1 (done : ZStudyRepository<T>), ES-3.2 (done : ZOfflineFirstBoxRepository + ZFirestorePathResolver). -->
<!-- SÉQUENTIELLE dans ES-3 : écrit `zcrud_study_kernel` (registre PUR) + `zcrud_firestore` (batcher). Ne touche PAS `zcrud_core`, ni le sprint-status. -->

## Story

As a **développeur intégrateur** (qui va câbler la suppression réelle d'un dossier d'étude — nettoyer sa descendance sous-dossiers → cartes → répétitions → notes → mindmaps → documents → annotations → examens — sur DEUX topologies Firestore, flat IFFD et nested lex, sans jamais dépasser la limite d'écritures par lot),
I want **un registre déclaratif des relations parent→enfant `ZCascadeRegistry` dans `zcrud_study_kernel` (neutre, PUR, chaque arête tagguée par son package propriétaire, anti two-owners) PLUS un `ZFirestoreCascadeBatcher` dans `zcrud_firestore` qui exécute le soft-delete en cascade en lots BORNÉS à ≤ 450 écritures/lot avec flush automatique — la topologie concrète (flat vs nested) étant résolue par `ZFirestorePathResolver` (ES-3.2), et le soft-delete restant strictement hors-entité (`is_deleted`/`updated_at` via `ZSyncMeta`, jamais dans le corps métier)**,
so that **supprimer un dossier volumineux (901 documents) découpe l'écriture en 3 lots sûrs au lieu de tenter un unique lot > 500 (échec Firestore garanti), sans qu'aucune arête ne soit codée en dur ni résolue par réflexion (`runtimeType`/`toString` bannis), qu'un enfant déclaré ne soit JAMAIS oublié, qu'une panne de lot ne soit JAMAIS avalée (remonte `Left`), et que la topologie IFFD puisse différer de lex sans toucher au domaine (AD-21)**.

---

## Contexte & problème mesuré

### La cascade réelle à factoriser (origine lex, MESURÉE sur disque)

`lex_douane` porte la cascade de suppression de dossier **inlinée à la main** dans un seul repository, avec un batching Firestore borné et un snapshot des ids **avant** soft-delete. Mesuré :

- `lex_douane/packages/lex_data/lib/data/repositories/study_folders_repository_impl.dart` :
  - **Borne de lot** (`_batchLimit`, l.50-51) : *« Borne de sécurité des batchs Firestore (limite dure = 500 writes). »* → `static const int _batchLimit = 450;` — **la limite Firestore est 500 ; la marge retenue est 450** (identique à `FirebaseZRepositoryImpl.kMaxBatchWrites`, `firebase_z_repository_impl.dart:246`).
  - **La cascade** (`deleteFolder`, l.241-293) : calcule `impactedFolderIds = {id, ...subFolderIds}` (l.248-249), puis `cardIds`, `repetitionKeys`, `cardIdsByFolder`, `noteIdsByFolder`, `mindmapIdsByFolder` (l.250-260) — **snapshot AVANT soft-delete** (fix F1, l.253-256 : *« sinon les helpers filtrent les entrées désormais `is_deleted` et la cascade Firestore laisserait des orphelins »*). Puis (1) purge Hive locale (l.262-278), (2) `_cascadeFirestore` bornée (l.280-287).
  - **Le batcher borné** (`_cascadeFirestore`, l.390-461) : `WriteBatch batch = _firestore.batch();` + `var ops = 0;` + `flushIfNeeded()` (l.407-413) : *`if (ops >= _batchLimit) { await batch.commit(); batch = _firestore.batch(); ops = 0; }`* — **découpage en lots ≤ 450 avec flush automatique**. Chaque écriture = `batch.set(ref.doc(id), softDelete, SetOptions(merge: true))` (l.428/436/444) où `softDelete = {'is_deleted': true, 'updated_at': FieldValue.serverTimestamp()}` (l.415-418) — **HORS-ENTITÉ, `merge:true`** (le corps métier de l'enfant n'est **pas** réécrit). Commit final si `ops > 0` (l.453-455).
  - **Relation parent→enfant CODÉE EN DUR** : `folder → subfolders` via `parent_id` (`_subFolderIds`, l.296-306), `folder → flashcards` via `folder_id` (`_cardIdsByFolder`, l.324-335), `folder → notes|mindmaps` via `folder_id` (`_childIdsByFolder`, l.354-365), `card|folder → repetition` via `flashcard_id`|`folder_id` (l.369-388). **Chaque relation est ré-inlinée** — non déclarative, non portable, non extensible par un package tiers.
- **Topologie nested lex** : `foldersRef = userRef.collection('study_folders')` puis `foldersRef.doc(entry.key).collection(subCollection)` (l.401, l.426) — les enfants vivent en **sous-collection sous le dossier** ⇒ aucune requête FK n'est nécessaire (le chemin embarque le parentId).
- **Topologie flat IFFD** — `iffd/lib/src/utils/functions/databases_functions.dart:8-9` : `getFirebaseCollectionName<T>` = `collectionName ?? FIREBASE_COLLECTION_NAMES[T] ?? T.toString();` → **collection = nom de classe par réflexion**, à BANNIR (esprit AD-3/NFR-S8). En flat, les enfants sont top-level avec un champ FK (`folder_id`) ⇒ la cascade doit interroger `where(folder_id == parentId)`.

**Le point d'AD-21** : cette cascade est aujourd'hui (1) **codée en dur** (chaque arête ré-inlinée), (2) **non portable** (nested-only chez lex, flat chez IFFD), (3) **non extensible** (un package tiers `zcrud_document`/`zcrud_exam` ne peut pas déclarer SON arête). ES-3.3 la rend **déclarative** (registre kernel neutre), **portable** (résolution par `ZFirestorePathResolver`), et **à propriété d'arête unique** (anti two-owners).

### Ce qui existe DÉJÀ dans le repo (à COMPOSER, PAS à dupliquer — AD-4)

- **`ZFirestorePathResolver`** (ES-3.2, `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart`) : `resolveCollection({required String kind, String? userId, String? parentId}) → ZResult<String>` — chemin `String` neutre, topologies `flatTopLevel`/`nestedUnderParent`/`globalTopLevel` via `ZFirestorePathRule` **littérales** ; `Left(DomainFailure)` explicite si kind inconnu / nested sans parentId / user-scopé sans userId. **C'est LUI qui absorbe la différence flat↔nested** — le batcher ne code aucun chemin.
- **`FirebaseZRepositoryImpl`** (E5-1/ES-3.0, `.../firebase_z_repository_impl.dart`) : patrons de confinement à réutiliser — `kMaxBatchWrites = 450` (l.242-246, *« la limite Firestore est 500 ; la borne canonique retenue est 450 »*) ; **le patron de découpage par lot borné** `applyMergedAll` (l.821-851) : `for (var start = 0; start < entries.length; start += kMaxBatchWrites) { ... final batch = _firestore.batch(); ... await batch.commit(); }` — chaque lot ≤ 450, committé atomiquement ; `_guard` (`FirebaseException → ServerFailure`, jamais `catch(_){}`).
- **`ZSyncMeta`** (`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`) : clés **hors-entité** `kUpdatedAt='updated_at'` / `kIsDeleted='is_deleted'`, `reservedKeys`, `stripReserved(map)`. Le soft-delete de cascade écrit **exactement** ces deux clés en `merge:true`.
- **`ZOfflineFirstBoxRepository`** (ES-3.2, `.../z_offline_first_box_repository.dart`) : `softDelete(id)` = `local.softDelete` (autoritaire, hors-entité) + propagation distante fire-and-forget. **C'est l'arme LOCALE offline-first** ; ES-3.3 fournit l'**arme distante bornée** de la cascade (AD-9 : local autoritaire + distant fire-and-forget en lots).
- **`ZStudyRepository<T>`** (ES-3.1, kernel) : Template Method `save = validate→persist`. La cascade n'y touche pas (elle opère au niveau collection/doc, pas au niveau agrégat).

### La continuité offline-first (AD-9) — où s'insère le batcher

Une suppression de dossier COMPLÈTE en offline-first = **deux arms coordonnés** (parité lex `deleteFolder` l.262-287) :
1. **arm LOCAL autoritaire** : soft-delete Hive de chaque entité impactée — c'est `ZOfflineFirstBoxRepository.softDelete` (ES-3.2), **déjà livré**, coordonné par le caller/orchestrateur ;
2. **arm DISTANT fire-and-forget BORNÉ** : soft-delete Firestore de toute la descendance en lots ≤ 450 — **c'est le livrable d'ES-3.3** (`ZFirestoreCascadeBatcher`).

ES-3.3 livre l'**arm distant borné** + le **registre déclaratif** qui décrit *quoi* casser. La coordination des deux arms (quand/dans quel ordre) est une préoccupation d'orchestration (ES-3.4/intégration ES-5), hors périmètre ici — mais le batcher est conçu pour être appelable en fire-and-forget par le store, exactement comme lex appelle `_cascadeFirestore` sans `await` bloquant (l.281).

### Le piège à contrer (motif dominant — R12/DW-ES25-1)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Risques spécifiques de CETTE story, chacun avec sa garde discriminante (AC + injection R3) :
1. un batcher qui **prétend** borner mais **tente un unique lot > 450** sans qu'aucun test ne rougisse (901 documents → 1 lot au lieu de 3) ;
2. une cascade « déclarative » où un **enfant déclaré n'est jamais supprimé** (arête ignorée silencieusement) ;
3. un soft-delete qui **fuit `is_deleted`/`updated_at` dans le corps métier** de l'enfant (au lieu de rester hors-entité `merge:true`) ;
4. une résolution d'arête/chemin par **`runtimeType`/`toString`** (réflexion IFFD ressuscitée) ;
5. une **panne de lot AVALÉE** (`catch → Right`) laissant un état à moitié appliqué signalé comme succès ;
6. une **arête à deux propriétaires** (two-owners) déclarée par deux packages concurremment sans détection ;
7. un **cycle** (self-edge `folder → folder` des sous-dossiers) faisant boucler la traversée à l'infini.

### Ce que cette story NE fait PAS

- **Pas de coordination LOCAL+DISTANT** ni de câblage `example`/app : le *quand* de l'arm local (offline-first `softDelete` par store) et l'ordre des deux arms = orchestration (ES-3.4 / intégration ES-5). ES-3.3 livre l'arm distant borné + le registre.
- **Pas de placement PHYSIQUE des const d'arêtes** dans `zcrud_document`/`zcrud_exam` ni de **composition unique par `zcrud_study`** : `zcrud_study` **n'existe pas encore** (créé en ES-5) et `zcrud_exam` **ne dépend pas encore du kernel** (arête à ajouter → hors périmètre « écrit kernel + zcrud_firestore »). ES-3.3 livre le **MÉCANISME** d'ownership (arête tagguée `owner` + garde anti two-owners, prouvée), et l'ensemble d'arêtes canonique est **fixture de test** miroir de lex. Le placement physique + composition unique = **DW-ES33-1** (aval, ES-5). Voir Dépendances/dettes.
- **Aucun orchestrateur multi-dépôts débouncé** = ES-3.4. **Aucun codec camelCase↔snake_case legacy** = ES-3.5.
- **Aucune écriture de `zcrud_core`** (ports/`ZSyncMeta` déjà livrés — R9).
- **Ne rouvre pas DW-ES25-1** (spike R4 des VO-à-invariant : séparé, non bloquant) **ni DW-ES32-1** (normalisation `Timestamp` méta de `_decodeCloud`, HORS-SYSTÈME, à solder seulement si un writer tiers `Timestamp` est introduit en ES-3.5).

---

## Décisions structurantes (tranchées par lecture lex/IFFD + AD-21 + ES-3.2/ES-3.0)

**D1 — `ZCascadeRegistry` + `ZCascadeEdge` vivent dans `zcrud_study_kernel`, PURS, ZÉRO backend, ZÉRO chemin (AD-21/AD-20/AD-1).**
Le registre est une **structure de données déclarative neutre** : une liste d'arêtes `parentKind → childKind` où chaque segment est un **`String` littéral** et chaque arête porte le **champ FK côté enfant** (`childParentRef`, ex. `'folder_id'`, `'parent_id'`) et son **package propriétaire** (`owner`, ex. `'zcrud_document'`). Il **ne connaît aucun chemin Firestore** (résolus par `ZFirestorePathResolver` côté `zcrud_firestore`) ni aucun type backend. Le kernel **ne gagne AUCUNE arête sortante** (référence uniquement `dart:core` — pas même `zcrud_core` n'est requis, mais l'import du barrel reste homogène si utile). CORE OUT=0 et acyclicité **inchangés** (le registre est du pur-Dart au kernel qui dépend déjà uniquement de `zcrud_core`/`zcrud_annotations`). **Rejeté : loger le registre dans `zcrud_firestore`** → il fuirait la topologie dans un seul adapter, non partageable IFFD↔lex, non déclarable par un package enfant (viole AD-21).

**D2 — `ZCascadeEdge` : arête tagguée `owner`, anti two-owners appliqué à la COMPOSITION (AD-21 ownership).**
Chaque arête `(parentKind, childKind)` a un **propriétaire unique**. `ZCascadeRegistry(List<ZCascadeEdge>)` **REJETTE à la construction** (lève `ArgumentError`/`StateError` explicite) deux arêtes de **même `(parentKind, childKind)`** déclarées avec des **`owner` différents** — c'est la garde machine « anti two-owners » d'AD-21 (*« aucun package ne déclare l'arête d'un autre »*). Un doublon **strictement identique** (même owner) est toléré/dédupliqué (idempotence de composition). Le registre ne peut pas contrôler *qui* écrit le code, mais il **garantit l'unicité du propriétaire par arête** — c'est le mécanisme qui rend la règle exécutable. **Rejeté : `owner` optionnel/ignoré** → la règle resterait de la prose (le two-owners passerait, R12).

**D3 — Traversée déterministe BORNÉE avec garde de cycle (self-edge `folder → folder`).**
`descendantEdges(String rootKind)` produit la **fermeture transitive** des arêtes atteignables depuis `rootKind`, dans un **ordre déterministe** (BFS stable sur l'ordre de déclaration), **en visitant chaque `kind` au plus une fois** (`Set<String> visited`) — de sorte que le **self-edge `folder → folder`** (sous-dossiers, présent chez lex `_subFolderIds`) **ne fait PAS boucler** la traversée de kinds. (La récursion sur les **instances** de sous-dossiers — 2 niveaux max, AD-18 — est faite à l'exécution par le batcher sur les ids, pas par la traversée de kinds.) **Rejeté : traversée sans `visited`** → self-edge = boucle infinie / stack overflow (AC5/R3-g).

**D4 — `ZFirestoreCascadeBatcher` (adapter `zcrud_firestore`) : exécution bornée ≤ 450 écritures/lot avec flush automatique (AD-9/AD-16/NFR-S9).**
Le batcher **compose** `ZCascadeRegistry` (le *quoi*) + `ZFirestorePathResolver` (le *où*) + une instance `FirebaseFirestore` (SEULE couture backend, confinée AD-5/AD-11). `deleteCascade({required String rootKind, required String rootId, String? userId})` : (1) traverse le registre (`descendantEdges`) ; (2) **énumère les ids d'instances impactées** (root + descendance) en interrogeant Firestore par arête selon la topologie ; (3) **soft-delete tout en lots ≤ `kMaxBatchWrites` (450)** via une boucle de flush (patron `applyMergedAll` l.828-848 / lex `flushIfNeeded` l.407-413). Retourne `ZResult<ZCascadeReport>` où `ZCascadeReport {int batchCount, int writeCount}` — **observable de bornage** (901 writes ⇒ `batchCount == 3`). `kMaxBatchWrites` réutilisé de `FirebaseZRepositoryImpl` (ne pas redéfinir un `450` en dur — AD-4). **Rejeté : un unique `batch.commit()`** → au-delà de 500 la limite dure Firestore fait échouer TOUTE la cascade (le bug exact que la borne 450 prévient).

**D5 — Bi-topologie résolue par `ZFirestorePathResolver`, JAMAIS codée dans le batcher (AD-20/AD-21).**
Pour chaque arête `parent → child`, le batcher **résout le chemin de collection enfant** via `resolver.resolveCollection(kind: childKind, userId:, parentId: <id du parent>)` :
- **nested** (lex) → le chemin embarque le parentId (`users/{uid}/study_folders/{parentId}/flashcards`) ⇒ **tous les docs de la collection** sont enfants (aucune requête FK) ;
- **flat** (IFFD) → chemin top-level ⇒ **`where(childParentRef, isEqualTo: parentId)`** filtre les enfants par leur champ FK déclaré.
Le batcher **choisit la stratégie d'énumération selon la topologie de la règle** (exposée par le resolver), **sans coder aucun chemin**. **La différence IFFD↔lex vit entièrement dans la table de topologie du resolver** (AD-21 : *« la topologie IFFD (flat) peut différer de lex (nested) sans toucher au domaine »*).

**D6 — Soft-delete STRICTEMENT hors-entité : `{is_deleted:true, updated_at}` en `merge:true` (AD-16/AD-19).**
Chaque écriture de cascade = `batch.set(ref.doc(id), {ZSyncMeta.kIsDeleted: true, ZSyncMeta.kUpdatedAt: <serverTimestamp|now>}, SetOptions(merge: true))` — **exactement les deux clés réservées `ZSyncMeta.reservedKeys`**, `merge:true` pour **ne PAS réécrire le corps métier** de l'enfant (parité lex `softDelete` l.415-418). Le batcher **ne sérialise JAMAIS l'entité enfant** (il ne la décode même pas — il n'a besoin que de l'`id`) ⇒ **aucun champ métier n'est touché**, `is_deleted`/`updated_at` ne peuvent pas fuir dans le corps (AC9). **Rejeté : `batch.set(ref, fullEntityMap)` sans merge** → clobbe le corps ET risque d'injecter les clés réservées dans le body (R3-c).

**D7 — Anti-réflexion : arêtes et chemins dérivés de `String` littéraux, JAMAIS de `runtimeType`/`toString` (AD-3/NFR-S8).**
`ZCascadeEdge` ne porte **aucun `Type`/générique** — uniquement des `String` (`parentKind`/`childKind`/`childParentRef`/`owner`). La traversée et la résolution de chemin n'appellent **jamais** `.toString()`/`runtimeType` pour dériver un segment (bannissement IFFD `databases_functions.dart:9`). Couvert par `z_kernel_purity_test.dart` (scan disque du kernel) + un grep d'assertion sur le batcher.

**D8 — Panne de lot NON avalée : un `FirebaseException` sur un `commit()` remonte `Left(ServerFailure)` (AD-5/AD-10).**
Le batcher enveloppe chaque `commit()` dans le patron `_guard` (parité `firebase_z_repository_impl.dart`) : une panne remonte **`Left(ServerFailure)`** avec le nombre de lots déjà committés dans un log — **jamais** un `catch(_){}` qui rendrait `Right`. ⚠️ **Divergence VOLONTAIRE de lex** : `_cascadeFirestore` (l.456-460) **avale** l'exception (`catch (e) { debugPrint(...) }`) car lex l'appelle en fire-and-forget local-first (la donnée locale fait foi). ES-3.3 **remonte** l'échec (`Left`) pour que le caller (store/orchestrateur) puisse **retenter** la propagation distante ; le choix fire-and-forget (avaler au niveau appelant) reste possible côté caller via `unawaited` + `.fold`, mais le batcher lui-même **ne ment jamais** sur un succès partiel (AC10). Documenté explicitement (jamais une divergence implicite — AD-27 esprit).

**D9 — Web/gates : registre kernel = pur-Dart web-safe ; batcher `zcrud_firestore` = Flutter, HORS `gate:web-determinism` ; `reserved-keys` intouché ; graphe inchangé.**
- Le test du registre (`z_cascade_registry_test.dart`) est **pur Dart, web-safe** (VM **et** node, PAS de `@TestOn('vm')`) — parité `z_study_repository_test.dart` (ES-3.1).
- Le test du batcher (`z_firestore_cascade_batcher_test.dart`) tourne sous `flutter test` (VM) avec `fake_cloud_firestore` ; `zcrud_firestore` **exclu** de `gate_web_determinism.dart` (package Flutter, l.40-42).
- **Aucun `@ZcrudModel`** ajouté (registre = classe simple, batcher = adapter) ⇒ **aucun** `.g.dart` neuf, **aucun** `registerZ…`, `gate_reserved_keys.dart` VERT **sans toucher** `tool/reserved_keys_gate/**`.
- **Graphe INCHANGÉ** : le registre kernel ne gagne aucune arête ; `zcrud_firestore → zcrud_study_kernel` existe **déjà** (ES-3.2) — le batcher réutilise cette arête pour importer `ZCascadeRegistry`. `graph_proof` ACYCLIQUE + CORE OUT=0 **inchangés** (aucune nouvelle arête).

**D10 — Propagation du `hide` de surface flashcard (D7/ES-1.1, gate `z_kernel_surface_guard_test.dart`).**
`ZCascadeEdge` et `ZCascadeRegistry` sont des symboles publics **nouveaux** du barrel kernel, **hors surface flashcard** ⇒ à **ajouter à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`, sinon `z_kernel_surface_guard_test.dart` ÉCHOUE (anti-fuite silencieuse — précédent `ZStudyRepository` d'ES-3.1/AC10).

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (R12) : le test associé **ROUGIT par le retrait de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli. L'orchestrateur **rejoue chaque injection R3** (retirer la garde → ROUGE **par cette garde**) et **restaure par édition ciblée** (`diff` vide — R13, JAMAIS `git checkout`). Backend de test batcher : `fake_cloud_firestore` (dev-dep existante). **Tête d'ordre : le bornage ≤ 450 (AC8) — 450/451/900/901.**

**AC1 — `ZCascadeEdge` + `ZCascadeRegistry` existent dans le kernel, PURS (zéro backend), exportés + classés au `hide` flashcard.**
`class ZCascadeEdge` (champs `String parentKind`, `String childKind`, `String childParentRef`, `String owner` — **tous `String`**, aucun `Type`/générique) et `class ZCascadeRegistry` sont déclarés dans `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart`, exportés par le barrel `zcrud_study_kernel.dart`, et ajoutés au `hide` de `zcrud_flashcard`. Le fichier ne contient **aucun** `Timestamp`/`Filter`/`Box`/`WriteBatch`/`FirebaseFirestore`/`Color`/`IconData` ni import de `cloud_firestore`/`hive`/`flutter`/`dart:ui`.
_Test :_ instanciation compile ; `z_kernel_purity_test.dart` scanne le nouveau fichier (VERT) ; `z_kernel_surface_guard_test.dart` VERT (symboles classés).

**AC2 — Registre DÉCLARATIF : `descendantEdges(rootKind)` restitue la fermeture transitive déterministe des arêtes déclarées ; un enfant déclaré y APPARAÎT.** _(discriminant déclaratif kernel)_
Étant donné un registre miroir de lex (`study_folder → study_folder` [sous-dossiers], `study_folder → flashcard`, `flashcard → repetition_info`, `study_folder → smart_note`, `study_folder → mindmap`, `study_folder → study_document`, `study_document → document_annotation`, `study_folder → exam`), `descendantEdges('study_folder')` contient **toutes** ces arêtes (y compris la transitive `flashcard → repetition_info` et `study_document → document_annotation`), dans un ordre **déterministe et stable** (2 appels ⇒ même liste).
_Injection R3-b (partie kernel) :_ retirer une arête de la fermeture (ex. filtrer `study_document → document_annotation` de la traversée) → l'annotation déclarée disparaît du plan ⇒ ce test ROUGIT. ⇒ la complétude de la traversée est PROUVÉE.

**AC3 — Anti two-owners : composer deux arêtes `(parentKind, childKind)` de propriétaires DIFFÉRENTS est REJETÉ à la construction.** _(discriminant ownership AD-21)_
Étant donné `ZCascadeEdge(parentKind:'study_folder', childKind:'exam', owner:'zcrud_exam')` **et** `ZCascadeEdge(parentKind:'study_folder', childKind:'exam', owner:'zcrud_intrus')`, construire `ZCascadeRegistry([...])` avec les deux **lève une erreur explicite** (message citant `study_folder→exam` + les deux owners). Un doublon **identique** (même owner) est toléré (idempotence). Une arête à owner unique passe.
_Injection R3-f :_ retirer la garde anti two-owners (accepter le second silencieusement) → la construction réussit avec une arête à deux propriétaires ⇒ ce test ROUGIT. ⇒ *« aucun package ne déclare l'arête d'un autre »* est exécutoire, pas de la prose.

**AC4 — Anti-réflexion : arêtes et chemins dérivés de `String` littéraux ; ZÉRO `runtimeType`/`toString` dans la traversée ou la dérivation de chemin (AD-3/NFR-S8).** _(discriminant réflexion)_
`ZCascadeEdge` n'expose **aucun** `Type`/générique `T` ; `ZCascadeRegistry.descendantEdges`/`childrenOf` et le batcher dérivent les segments **exclusivement** des `String` d'arête + de `ZFirestorePathResolver` (règles littérales). Aucun `.toString()`/`runtimeType` n'entre dans la résolution d'un `kind`/chemin.
_Test :_ grep d'assertion (absence de `runtimeType`/`.toString()` dans la dérivation de kind/chemin de `z_cascade_registry.dart` et `z_firestore_cascade_batcher.dart`) ; le registre ne compile avec **aucun** paramètre `Type`.
_Injection R3-d :_ router la résolution d'un `childKind` via `child.runtimeType.toString()` au lieu du `String` littéral d'arête → grep ROUGE (token interdit) **et** (si couplé au batcher) chemin incorrect résolu ⇒ ROUGIT.

**AC5 — Self-edge `study_folder → study_folder` (sous-dossiers) : la traversée de kinds ne BOUCLE PAS.** _(discriminant cycle)_
Étant donné un registre incluant le self-edge `study_folder → study_folder` (+ un éventuel cycle `a→b→a` de test), `descendantEdges('study_folder')` **termine** (chaque `kind` visité au plus une fois), retourne un résultat fini et déterministe, **sans** débordement de pile ni doublon d'arête.
_Injection R3-g :_ retirer la garde `visited` (Set de kinds visités) de la traversée → le self-edge/cycle fait **boucler à l'infini** (StackOverflow / timeout) ⇒ ce test ROUGIT. ⇒ la borne de traversée est PROUVÉE nécessaire.

**AC6 — `ZFirestoreCascadeBatcher` existe dans `zcrud_firestore` ; `deleteCascade` → `ZResult<ZCascadeReport>` ; ZÉRO type backend dans une signature publique (AD-5/AD-11).**
`class ZFirestoreCascadeBatcher` (`packages/zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart`) : construit avec `ZCascadeRegistry registry`, `ZFirestorePathResolver resolver`, `FirebaseFirestore firestore` (SEULE couture, injectée), logger neutre optionnel. `Future<ZResult<ZCascadeReport>> deleteCascade({required String rootKind, required String rootId, String? userId})`. `ZCascadeReport {int batchCount, int writeCount}`. **Aucune** signature publique n'expose `FirebaseFirestore`/`CollectionReference`/`WriteBatch`/`Query`/`Timestamp`/`DocumentSnapshot` — tout reste `ZResult<…>`/`String`/types du cœur. Barrel exporte `ZFirestoreCascadeBatcher` + `ZCascadeReport` (pas de type backend).
_Test :_ instanciation compile ; inspection statique (le barrel n'exporte aucun type backend).

**AC7 — Cascade complète : une suppression de dossier soft-delete TOUS les descendants déclarés ; un frère NON déclaré n'est PAS touché.** _(discriminant cascade)_
Fixture (fake Firestore seedé) : un `study_folder` root `f1` + 1 sous-dossier `f2` + cartes/notes/mindmaps/documents/annotations/examens rattachés (via topologie de test) **ET** une collection sœur non déclarée (ex. `unrelated`). Après `deleteCascade(rootKind:'study_folder', rootId:'f1')` : **chaque** descendant déclaré porte `is_deleted == true` (root, sous-dossier, et tous les enfants transitifs) ; la collection `unrelated` reste **intacte** (aucun `is_deleted`).
_Injection R3-b (partie batcher) :_ omettre une arête de l'exécution (skip un `childKind`) → un enfant déclaré (ex. les annotations) reste actif ⇒ ce test ROUGIT. ⇒ aucune arête déclarée n'est silencieusement oubliée.

**AC8 — BORNAGE ≤ 450 écritures/lot avec flush automatique : 450→1 lot, 451→2 lots, 900→2 lots, 901→3 lots (`report.batchCount`).** _(CŒUR discriminant — NFR-S9/AD-9)_
Fixtures ISOLÉES par cardinalité de descendance (seed exact d'enfants d'un unique parent) :
  (a) **450** enfants → `deleteCascade` ⇒ `report.batchCount == 1`, `report.writeCount == 451` (450 enfants + le dossier) — ou une cardinalité choisie pour tomber pile à 450/lot ;
  (b) **451** → `report.batchCount == 2` ;
  (c) **900** → `report.batchCount == 2` ;
  (d) **901** → `report.batchCount == 3`.
Chaque lot committé porte **≤ 450** écritures (invariant structurel de la boucle de flush).
_Injection R3-a :_ retirer le découpage (remplacer la boucle de flush par un unique `batch.commit()`) → pour 451 : `report.batchCount == 1` (au lieu de 2) ⇒ la fixture (b)/(d) ROUGIT. ⇒ le bornage est PROUVÉ (avec un vrai Firestore, un lot > 500 échouerait ; `fake_cloud_firestore` n'impose pas la limite, d'où la nécessité d'observer `batchCount` — pas de faux vert).

**AC9 — Soft-delete HORS-ENTITÉ : le batcher n'écrit QUE `{is_deleted, updated_at}` en `merge:true` ; le corps métier de l'enfant est PRÉSERVÉ, aucune clé réservée n'y fuit.** _(discriminant hors-entité AD-16/AD-19)_
Fixture : un enfant seedé avec un corps métier (ex. `{title:'x', folder_id:'f1'}`). Après cascade : le doc porte `is_deleted == true` **et** conserve `title == 'x'` (corps intact, `merge:true`) ; le batcher **ne relit/ne réécrit jamais** le corps de l'entité (il n'écrit que la map méta à 2 clés). Le corps métier ne contient **aucune** valeur `is_deleted`/`updated_at` provenant du batcher au-delà de l'enveloppe méta.
_Injection R3-c :_ faire écrire au batcher la map complète de l'entité (avec `is_deleted` embarqué dans le body) **sans** `merge:true`/**avec** les clés dans le corps → une garde d'assertion (« le corps métier reste `{title:'x',...}` sans réécriture ; les clés réservées ne fuitent pas dans le body ») ROUGIT.

**AC10 — Panne de lot NON avalée : un `commit()` qui échoue remonte `Left(ServerFailure)`, jamais un `Right` masquant un succès partiel.** _(discriminant échec de lot AD-5/AD-10)_
Étant donné un `_ThrowingFirestore` (parité E5) dont `batch().commit()` lève `FirebaseException` (au 1er ou au N-ième lot), `deleteCascade` renvoie **`Left(ServerFailure)`** (message exploitable, nb de lots committés loggé) — **jamais** `Right`. (Divergence documentée de lex qui avale — D8.)
_Injection R3-e :_ envelopper le `commit()` dans un `catch (_) {}` retournant `Right(report)` → la panne est masquée ⇒ ce test ROUGIT (attendait `Left`). ⇒ le batcher ne ment jamais sur un succès partiel.

**AC11 — Bi-topologie résolue par `ZFirestorePathResolver` : nested (lex, sous-collection sous parent) ET flat (IFFD, top-level + `where(childParentRef==parentId)`).** _(discriminant topologie AD-20/AD-21)_
Fixtures ISOLÉES :
  (a) **nested** : la table de topologie place les enfants sous `users/{uid}/study_folders/{parentId}/flashcards` ⇒ tous les docs de la sous-collection sont enfants (aucune requête FK) ; cascade les soft-delete ;
  (b) **flat** : table top-level `flashcards` ⇒ le batcher filtre `where('folder_id', isEqualTo: parentId)` ; seuls les enfants du bon parent sont soft-deletés (un doc `folder_id:'autre'` reste intact).
Aucun chemin n'est codé dans le batcher (tout vient du resolver).
_Injection R3 (topologie) :_ pointer la règle `nested` sur le chemin flat (ou inverser la stratégie d'énumération) → les enfants ne sont pas trouvés au bon chemin ⇒ la cascade laisse des orphelins ⇒ ROUGIT (réutilise l'esprit R3-h d'ES-3.2).

**AC12 — Vérif verte REPO-WIDE (R9), graphe INCHANGÉ.**
`melos run generate` OK (**aucun nouveau `.g.dart`**) → `melos run analyze` **RC=0** → `dart test` de `zcrud_study_kernel` (VM) **et** `dart test -p node` (JS) **RC=0** → `flutter test` de `zcrud_firestore` **RC=0** → `melos run test` **RC=0** → `dart run scripts/ci/gate_reserved_keys.dart` VERT (**inchangé**) → `dart run scripts/ci/gate_web_determinism.dart` VERT (`zcrud_firestore` exclu ; registre kernel web-safe) → `melos run verify` VERT (`codegen-distribution`, `graph_proof` **ACYCLIQUE + CORE OUT=0 SANS nouvelle arête**, `secrets`, `reflectable`) → `z_kernel_surface_guard_test.dart` VERT.

---

## Tasks / Subtasks

- [x] **T1 — `ZCascadeEdge` + `ZCascadeRegistry` (kernel, PUR) — D1, D2, D3, D7.** (AC1, AC2, AC3, AC4, AC5)
  - [x] Créer `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart` : `class ZCascadeEdge` (`const`, champs `String parentKind/childKind/childParentRef/owner`, `==`/`hashCode` sur le quadruplet) + `class ZCascadeRegistry`.
  - [x] Constructeur `ZCascadeRegistry(List<ZCascadeEdge> edges)` : **garde anti two-owners** (deux arêtes de même `(parentKind, childKind)` à `owner` différents → `ArgumentError` explicite citant l'arête + les owners ; doublon identique dédupliqué). Indexation `parentKind → List<ZCascadeEdge>` non modifiable.
  - [x] `List<ZCascadeEdge> childrenOf(String parentKind)` ; `List<ZCascadeEdge> descendantEdges(String rootKind)` : BFS déterministe (ordre de déclaration) avec `Set<String> visited` de kinds (garde de cycle/self-edge). **Aucun `Type`/`runtimeType`/`.toString()`.**
  - [x] Dartdoc : AD-21 (déclaratif, ownership anti two-owners, topologie résolue ailleurs), origine lex (`study_folders_repository_impl.dart:296-388` relations inlinées), bannissement réflexion (esprit AD-3/NFR-S8).

- [x] **T2 — Exporter le registre + propager le `hide` flashcard (D10).** (AC1, AC12)
  - [x] `export 'src/domain/z_cascade_registry.dart';` dans `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (commentaire ES-3.3/FR-S14 ; placement pour `directives_ordering`).
  - [x] Ajouter `ZCascadeEdge`, `ZCascadeRegistry` à la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` ; `z_kernel_surface_guard_test.dart` VERT.

- [x] **T3 — `ZFirestoreCascadeBatcher` (adapter) — D4, D5, D6, D8.** (AC6, AC7, AC8, AC9, AC10, AC11)
  - [x] Créer `packages/zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart` : `class ZFirestoreCascadeBatcher` (ctor : `ZCascadeRegistry registry`, `ZFirestorePathResolver resolver`, `FirebaseFirestore firestore`, logger optionnel) + `class ZCascadeReport {int batchCount; int writeCount}`.
  - [x] `deleteCascade({required String rootKind, required String rootId, String? userId})` : (1) `registry.descendantEdges(rootKind)` ; (2) **énumération des ids impactés** — par arête, résoudre le chemin enfant via `resolver.resolveCollection(kind: childKind, userId:, parentId:)` ; nested → tous les docs de la sous-collection ; flat → `where(childParentRef, isEqualTo: parentId)` ; propager récursivement sur les ids de sous-dossiers (self-edge, bornée 2 niveaux AD-18) ; (3) collecter `(collectionPath, docId)` de root + descendance.
  - [x] **Boucle de flush bornée** (patron `applyMergedAll` l.828-848 / lex `flushIfNeeded`) : `WriteBatch` accumulé, flush automatique dès `ops == kMaxBatchWrites` (**450**, réutilisé de `FirebaseZRepositoryImpl.kMaxBatchWrites` — NE PAS redéfinir), écriture = `batch.set(ref, {ZSyncMeta.kIsDeleted:true, ZSyncMeta.kUpdatedAt: FieldValue.serverTimestamp()}, SetOptions(merge:true))`. Commit final si `ops > 0`. Incrémenter `batchCount`/`writeCount`.
  - [x] `_guard` autour des `commit()` (parité E5) : `FirebaseException → Left(ServerFailure)` (nb lots committés loggé) — **jamais** `catch(_){}→Right` (D8, divergence lex documentée).

- [x] **T4 — Exporter le batcher (barrel).** (AC6)
  - [x] `export 'src/data/z_firestore_cascade_batcher.dart';` dans `packages/zcrud_firestore/lib/zcrud_firestore.dart` (commentaire ES-3.3/FR-S14 ; signatures NUES, aucun type backend exporté).

- [x] **T5 — Tests kernel à pouvoir discriminant (registre).** (AC1-AC5)
  - [x] Créer `packages/zcrud_study_kernel/test/z_cascade_registry_test.dart` (pur Dart, web-safe, PAS de `@TestOn('vm')`, VM+node).
  - [x] Fixtures ISOLÉES : fermeture transitive complète (AC2), anti two-owners rejet + idempotence (AC3), anti-réflexion/`String`-only (AC4), self-edge/cycle termine (AC5). Commentaires R3 (b-kernel/f/d/g).

- [x] **T6 — Tests batcher à pouvoir discriminant.** (AC6-AC11)
  - [x] Créer `packages/zcrud_firestore/test/z_firestore_cascade_batcher_test.dart` (`flutter test` VM ; `fake_cloud_firestore` ; `_ThrowingFirestore` pour la panne — parité E5).
  - [x] Fixtures ISOLÉES : cascade complète + frère non touché (AC7), **bornage 450/451/900/901 en TÊTE** (AC8), hors-entité `merge:true` corps préservé (AC9), panne de lot → `Left` (AC10), bi-topologie nested/flat (AC11). Commentaires R3 (a/b-batcher/c/e/topologie) : quel retrait fait ROUGIR.

- [x] **T7 — Rejouer les injections R3 (orchestrateur).** (AC2, AC3, AC4, AC5, AC7, AC8, AC9, AC10)
  - [x] R3-a (bornage), R3-b (kernel+batcher), R3-c, R3-d, R3-e, R3-f, R3-g exécutées puis restaurées par **édition ciblée** (`diff` vide) ; consigner le message rouge exact de chaque garde.

- [x] **T8 — Vérif verte REPO-WIDE (R9), graphe inchangé.** (AC12)
  - [x] `melos run generate` (0 `.g.dart` neuf) → `melos run analyze` RC=0 → kernel `dart test` VM + `-p node` RC=0 → `flutter test` zcrud_firestore RC=0 → `melos run test` RC=0 → `gate_reserved_keys` VERT (registrars **inchangé**) → `gate_web_determinism` VERT → `melos run verify` VERT (graph ACYCLIQUE + CORE OUT=0, **SANS nouvelle arête**) → surface-guard flashcard VERT.

---

## Dev Notes

### Patrons d'architecture & contraintes (AD)

- **AD-21 (cascade déclarative bornée)** — registre `kind → enfants` **neutre** au kernel (sans chemin) ; ownership d'arête (chaque arête un propriétaire unique, anti two-owners) ; résolution concrète des chemins via `ZFirestorePathResolver` (topologie IFFD flat ≠ lex nested) ; batcher borné **≤ 450 écritures/lot** avec flush auto. [Source: `architecture.md#AD-21` l.223-226]
- **AD-9 / AD-16 / AD-19 (offline-first, soft-delete hors-entité)** — soft-delete cascade `is_deleted`/`updated_at` **hors-entité** (`ZSyncMeta`, `merge:true`), jamais dans l'agrégat ; distant fire-and-forget (l'arm local autoritaire = `ZOfflineFirstBoxRepository.softDelete` d'ES-3.2) ; cascade **≤ 450 écritures/lot**. [Source: `z_sync_meta.dart` ; lex `study_folders_repository_impl.dart:262-461` ; `firebase_z_repository_impl.dart:242-246,821-851`]
- **AD-5 / AD-11 (backend-agnostique)** — `cloud_firestore` confiné à `zcrud_firestore` ; aucune signature publique n'expose un type backend ; `deleteCascade → ZResult<ZCascadeReport>` ; `_guard` (`FirebaseException → ServerFailure`, jamais `catch(_){}`). [Source: `firebase_z_repository_impl.dart:9-13` ; `z_firestore_path_resolver.dart`]
- **AD-20 (aucun chemin en dur dans le domaine)** — le registre kernel ne connaît **aucun** chemin ; le batcher **ne code aucun chemin** (tout via `ZFirestorePathResolver`). [Source: `z_firestore_path_resolver.dart` ; epics ES-3.3 AC l.544-554]
- **AD-3 / NFR-S8 (anti-réflexion)** — arêtes/segments = `String` littéraux ; `runtimeType`/`toString` **bannis** (bug IFFD `databases_functions.dart:9` : `collection = T.toString()`). [Source: iffd `databases_functions.dart:8-9`]
- **AD-1 / AD-17 (acyclique, CORE OUT=0) — SANS nouvelle arête** — registre kernel pur-Dart (aucune arête sortante neuve) ; le batcher réutilise l'arête `zcrud_firestore → zcrud_study_kernel` **déjà posée en ES-3.2**. `graph_proof` INCHANGÉ. [Source: `scripts/dev/graph_proof.py` ; es-3-2 (arête ajoutée)]
- **AD-4 (COMPOSE-not-DUPLICATE)** — réutiliser `kMaxBatchWrites` (ne pas redéfinir 450), `ZFirestorePathResolver`, `ZSyncMeta.reservedKeys`, le patron de flush `applyMergedAll` ; **ne PAS** ré-inliner les relations (le point d'AD-21). [Source: `firebase_z_repository_impl.dart:246,821-851` ; `z_sync_meta.dart`]
- **AD-18 (2 niveaux max de dossiers)** — la récursion instance sur sous-dossiers (self-edge) est **bornée à 2 niveaux** (`validatePlacement`, `z_study_folder_hierarchy.dart`) ; la garde `visited` de kinds évite en plus toute boucle de traversée. [Source: `z_study_folder_hierarchy.dart` ; lex `_subFolderIds` l.296-306]

### Divergence VOLONTAIRE de lex (documentée, jamais implicite — AD-27 esprit)

- lex `_cascadeFirestore` (l.456-460) **AVALE** l'exception (`catch (e) { debugPrint(...) }`) — approprié pour son appel fire-and-forget local-first. **ES-3.3 REMONTE** l'échec (`Left(ServerFailure)`, D8/AC10) : le batcher ne ment jamais sur un succès partiel ; le caller (store/orchestrateur) reste libre d'appeler en fire-and-forget (`unawaited` + `.fold`), mais il DÉCIDE d'avaler — le batcher, lui, dit la vérité.

### Source tree — fichiers à toucher

- **NEW** `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart` — registre + arête (PUR).
- **NEW** `packages/zcrud_study_kernel/test/z_cascade_registry_test.dart` — tests discriminants (web-safe).
- **NEW** `packages/zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart` — batcher borné + `ZCascadeReport`.
- **NEW** `packages/zcrud_firestore/test/z_firestore_cascade_batcher_test.dart` — tests discriminants (Flutter/fake).
- **UPDATE** `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` — `export` du registre.
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — `hide` de `ZCascadeEdge`/`ZCascadeRegistry` (D10).
- **UPDATE** `packages/zcrud_firestore/lib/zcrud_firestore.dart` — `export` du batcher + `ZCascadeReport`.
- **⛔ NE PAS TOUCHER** : `zcrud_core`, `tool/reserved_keys_gate/**` (AC12/D9), tout `*.g.dart`, `zcrud_document`/`zcrud_exam`/`zcrud_study` (placement physique des arêtes + composition = DW-ES33-1, aval), le sprint-status (orchestrateur), `z_offline_first_repository.dart` (E5-3) / `z_offline_first_box_repository.dart` (ES-3.2).

### Fichiers UPDATE — état actuel & ce qui doit être préservé

- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` : barrel avec exports + politique `hide` documentée. **Préserver** l'ordre/les commentaires ; ajouter une ligne `export` (commentaire ES-3.3/FR-S14). Ne pas altérer les `hide`/exports existants.
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : ré-exporte le barrel kernel via `hide`. **Préserver** intégralement la surface E9 + les `hide` existants (dont `ZStudyRepository` d'ES-3.1) ; **ajouter** `ZCascadeEdge`, `ZCascadeRegistry` au `hide`.
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` : barrel exportant E5/ES-3.2. **Préserver** tous les exports + le dartdoc d'isolation AD-5 ; **ajouter** une ligne `export` (commentaire ES-3.3). Ne rien retirer, aucun type backend exporté.

### Injections R3 prévues (à rejouer par l'orchestrateur, restaurées par édition ciblée)

> **TÊTE : bornage ≤ 450 (R3-a) — 450/451/900/901.**

- **R3-a** (AC8, bornage) : remplacer la boucle de flush par un unique `batch.commit()` → 451 enfants ⇒ `report.batchCount == 1` au lieu de `2` (et 901 ⇒ 1 au lieu de 3) → ROUGE.
- **R3-b** (AC2 kernel + AC7 batcher) : retirer une arête de `descendantEdges` (kernel) / skip un `childKind` à l'exécution (batcher) → enfant déclaré non soft-deleté → ROUGE.
- **R3-c** (AC9) : écrire la map complète de l'entité (corps + `is_deleted` embarqué) sans `merge:true` → corps métier clobbé / clé réservée fuitée → ROUGE.
- **R3-d** (AC4) : résoudre un `childKind`/chemin via `runtimeType`/`.toString()` → grep ROUGE + chemin incorrect → ROUGE.
- **R3-e** (AC10) : `catch (_) { return Right(report); }` autour du `commit()` → panne masquée → ROUGE (attendait `Left`).
- **R3-f** (AC3) : retirer la garde anti two-owners → arête à deux propriétaires acceptée → ROUGE.
- **R3-g** (AC5) : retirer le `Set<String> visited` de la traversée → self-edge `folder→folder`/cycle boucle à l'infini (StackOverflow/timeout) → ROUGE.

### Testing standards

- Kernel : `dart test` (VM) **et** `dart test -p node` (JS) — le test du registre est pur Dart web-safe (aucun `dart:io`, PAS de `@TestOn('vm')`), parité `z_study_repository_test.dart` (ES-3.1/AC11).
- `zcrud_firestore` = package **Flutter** ⇒ `flutter test` (VM), **pas** de `@TestOn('vm')`, **exclu** de `gate_web_determinism` (D9). Backend : `fake_cloud_firestore` (dev-dep existante) + `_ThrowingFirestore` pour la panne (parité E5).
- **Pouvoir discriminant (R12)** : chaque garde naît avec sa **fixture d'échec isolée (R2)** ; le bornage se PROUVE par `report.batchCount` observé (pas par « ça n'a pas throw » — `fake_cloud_firestore` n'impose pas la limite 500, donc un test « n'a pas throw » serait POWERLESS). Seeds de cardinalité exacte (450/451/900/901) par écriture directe dans le fake.
- **Pas de test POWERLESS** : ne PAS « prouver » la cascade en lisant directement le registre sans exécuter `deleteCascade` ; ne PAS « prouver » le bornage par l'absence d'exception. AC8 **doit** observer `report.batchCount`. AC7 **doit** relire `is_deleted` sur chaque enfant réel après cascade.

### Points d'attention dev

1. **`kMaxBatchWrites` réutilisé** : importer/référencer `FirebaseZRepositoryImpl.kMaxBatchWrites` (450) — **ne PAS** hardcoder un second `450` (AD-4 ; un drift de constante serait un bug latent).
2. **`fake_cloud_firestore` n'impose PAS la limite 500** : d'où l'observable `report.batchCount` — sans lui, un bornage cassé passerait « vert » (faux vert). C'est le piège central d'AC8.
3. **Snapshot des ids AVANT soft-delete** (fix lex F1, l.253-256) : énumérer les enfants **avant** de commencer à écrire `is_deleted` — sinon une ré-lecture filtrerait les entrées déjà marquées et laisserait des orphelins. Le batcher collecte d'abord tous les `(path, id)`, puis batche.
4. **Self-edge folder→folder** : la traversée de **kinds** est bornée par `visited` (AC5) ; la récursion sur les **instances** de sous-dossiers est bornée par AD-18 (2 niveaux). Ne pas confondre les deux niveaux de bornage.
5. **Divergence lex (avaler vs remonter)** (D8/AC10) : documenter explicitement dans le dartdoc du batcher — c'est un choix, pas un oubli.
6. **Aucun décodage d'entité** : le batcher n'a besoin que des `id` (et du `parentId` pour la topologie flat via FK). Il **ne décode jamais** l'entité enfant ⇒ pas de `ZDecodeContext` ici (contrairement à ES-3.2), pas de risque DW-ES14-2, et `is_deleted` ne peut structurellement pas fuir dans un corps (AC9).
7. **`hide` flashcard** (D10) : piège d'inertie le plus probable — oublier de classer `ZCascadeEdge`/`ZCascadeRegistry` fait ÉCHOUER `z_kernel_surface_guard_test.dart` (pas `analyze`). Le lancer après T2.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-3.3` (l.534-554), FR-S14 (l.118), objectif ES-3 (l.485-487)]
- [Source: `architecture.md#AD-21` (l.223-226) — cascade déclarative bornée, ownership anti two-owners, ≤ 450/lot ; `#AD-9/AD-16/AD-19` (l.48,99-149) — soft-delete hors-entité universel ; `#AD-20` — aucun chemin en dur]
- [Source: `es-3-2-helper-offline-first-path-resolver.md` + `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart` — `resolveCollection`, topologies flat/nested/global, `Left` explicite ; `z_offline_first_box_repository.dart` — `softDelete` local autoritaire (arm local)]
- [Source: `es-3-1-depot-etude-generique.md` — `ZStudyRepository<T>` ; test web-safe VM+node (patron du test kernel)]
- [Source: `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:242-246` (`kMaxBatchWrites=450`, *« limite Firestore 500, marge 450 »*), `:821-851` (`applyMergedAll` — patron de découpage par lot borné), `_guard` (`FirebaseException→ServerFailure`)]
- [Source: `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart` — `kIsDeleted`/`kUpdatedAt`/`reservedKeys`/`stripReserved` (hors-entité)]
- [Source: lex `/home/zakarius/DEV/lex_douane/packages/lex_data/lib/data/repositories/study_folders_repository_impl.dart:50-51` (`_batchLimit=450`), `:241-293` (`deleteFolder` snapshot+cascade), `:296-388` (relations inlinées parent→enfant), `:390-461` (`_cascadeFirestore` batch+flush+soft-delete merge, catch qui AVALE l.456-460)]
- [Source: iffd `/home/zakarius/DEV/iffd/lib/src/utils/functions/databases_functions.dart:8-9` — `collection = T.toString()` (réflexion À BANNIR, AD-3/NFR-S8)]
- [Source: `packages/zcrud_study_kernel/test/z_kernel_purity_test.dart` (scan disque SM-S5), `z_kernel_resolution_test.dart` (acyclicité), `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (guard `hide`)]
- [Source: `epic-es-2-retrospective.md` — R2 (fixture d'échec isolée), R9 (vérif REPO-WIDE), R10 (garde dérivée du disque), R11 (patron en tête), R12 (test POWERLESS), R13 (édition ciblée) ; DW-ES25-1]
- [Source: `scripts/dev/graph_proof.py` (acyclicité + CORE OUT=0) ; `scripts/ci/gate_web_determinism.dart:40-42` (packages Flutter exclus)]

### Project Structure Notes

- Chemins conformes à l'épic (`z_cascade_registry.dart` sous kernel `lib/src/domain/` ; `z_firestore_cascade_batcher.dart` sous `zcrud_firestore/lib/src/data/`) et aux conventions (barrels, `Z…`, snake_case, tests `*_test.dart`). Aucune variance.
- Registre = membre **`domain`** du kernel (contrat/structure pure) — cohérent avec `z_study_repository.dart`/`z_study_folder_hierarchy.dart`. Batcher = membre **`data`** (adapter) — cohérent avec `firebase_z_repository_impl.dart`/`z_offline_first_box_repository.dart`.

### Dépendances / dettes

- **Dépend de** ES-3.0 (done), ES-3.1 (done), ES-3.2 (done : `ZFirestorePathResolver` + arête `zcrud_firestore → zcrud_study_kernel`). ES-3.3 **réutilise** l'arête et le resolver ; **n'écrit PAS** `zcrud_core`.
- **DW-ES33-1 (NOUVELLE, ouverte par cette story — aval, non bloquante)** : le **placement physique** des const d'arêtes dans le package enfant propriétaire (`zcrud_document` déclare `folder→document→annotation` ; `zcrud_exam` déclare `folder→exam` — nécessite d'ajouter l'arête `zcrud_exam → zcrud_study_kernel`) **et** la **composition en registre unique par `zcrud_study`** (créé en ES-5) sont **déférés** : `zcrud_study` n'existe pas encore et le périmètre d'ES-3.3 est « kernel + zcrud_firestore ». ES-3.3 livre le **MÉCANISME** d'ownership (arête tagguée `owner` + garde anti two-owners, prouvée AC3) ; l'ensemble d'arêtes canonique est **fixture de test**. À câbler physiquement à l'intégration ES-5.
- **DW-ES25-1 (rappel, NON traité ici)** : prototype R4 de la garde `(h)` des VO-à-invariant, **encore dû dans ES-3** (spike séparé, non bloquant — rétro ES-2 §7 pt.3). ES-3.3 ne l'ouvre pas.
- **DW-ES32-1 (rappel, ouverte, NON traité ici)** : `_decodeCloud` (`z_offline_first_box_repository.dart`) normalise `updated_at` sur une copie non utilisée pour la méta ; HORS-SYSTÈME (le `_cloudMap` écrit toujours de l'ISO), à solder **seulement si** un writer tiers `Timestamp` est introduit (ES-3.5, interop legacy). ES-3.3 ne le touche pas.
- **Aval** : `ES-3.4` (orchestrateur multi-dépôts débouncé — coordonne les arms local+distant, dont la cascade), `ES-3.5` (codec camelCase↔snake_case IFFD legacy).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

**Vérif verte REPO-WIDE rejouée sur disque (AC12) :**

| Étape | Commande | Résultat |
|-------|----------|----------|
| generate | `dart run melos run generate` | SUCCESS — **0 `.g.dart` neuf** (`git status` : aucun) |
| analyze REPO-WIDE | `dart run melos run analyze` | SUCCESS — `zcrud_study_kernel`/`zcrud_firestore`/`zcrud_flashcard` : **No issues found!** (2 infos pré-existantes dans `zcrud_document`, package parallèle hors périmètre) |
| kernel VM | `dart test` (zcrud_study_kernel) | **+294 All tests passed!** (dont registre +11) |
| kernel JS | `dart test -p node` (zcrud_study_kernel) | **+280 All tests passed!** (web-safe) |
| firestore | `flutter test` (zcrud_firestore) | **+131 All tests passed!** (dont batcher +12) |
| reserved-keys | `dart run scripts/ci/gate_reserved_keys.dart` | **OK** (118 tests) — `registrars` INCHANGÉ |
| web-determinism | `dart run scripts/ci/gate_web_determinism.dart` | **OK** — `zcrud_firestore` (Flutter) exclu, registre kernel JS-safe |
| graph_proof | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** — 34 arêtes / 18 nœuds, **SANS nouvelle arête** (registre pur-Dart ; batcher réutilise `zcrud_firestore → zcrud_study_kernel` d'ES-3.2) |
| prove_gates | `dart run scripts/ci/prove_gates.dart` | **41 OK, 0 FAIL** |
| surface-guard | `flutter test test/z_kernel_surface_guard_test.dart` (zcrud_flashcard) | **+5 All tests passed!** (`ZCascadeEdge`/`ZCascadeRegistry` classés au `hide`) |
| verify | `dart run melos run verify` | voir Completion Notes (codegen-distribution + graph + secrets + reflectable) |

**Point d'extension public ajouté (signalé) :** `ZFirestorePathResolver.topologyOf(String kind) → ZResult<ZFirestoreTopology>` — le resolver ES-3.2 n'exposait PAS la topologie déclarée (seulement `kinds`/`resolveCollection`). Le batcher en a besoin pour choisir sa stratégie d'énumération (nested = sous-collection ; flat/global = `where(FK)`) sans coder de chemin. Ajout **additif** (aucune signature existante modifiée), conforme à l'autorisation « point d'extension public manquant, à signaler ». Aucune modification de `z_offline_first_box_repository.dart`/`z_offline_first_repository.dart`.

**Injections R3 rejouées RÉELLEMENT (message ROUGE exact ; restaurées par édition ciblée → re-vert prouvé) :**

- **R3-a** (AC8, bornage) — retiré la garde `&& ops < _maxBatchWrites` de la boucle de flush → « writeCount 451 ⇒ batchCount 2 [E] **Expected: <2> Actual: <1>** ». RESTAURÉ → vert.
- **R3-b (batcher)** (AC7) — `if (edge.childKind == 'document_annotation') continue;` dans l'énumération → « tous les descendants… [E] **Expected: true Actual: <false>** · transitive document→annotation » (`a1` resté actif). RESTAURÉ → vert.
- **R3-b (kernel)** (AC2) — même skip dans `descendantEdges` → « toutes les arêtes déclarées apparaissent [E] **Expected: contains all of […] Actual: Set:[…]** » (arête absente du plan). RESTAURÉ → vert.
- **R3-c** (AC9, hors-entité) — retiré `SetOptions(merge: true)` du `batch.set` → « le corps métier `title` survit [E] **Expected: 'x' Actual: <null>** » (doc remplacé, corps clobbé). RESTAURÉ → vert.
- **R3-d** (AC4, anti-réflexion) — `final reflected = edge.childKind.runtimeType.toString();` dans le batcher → grep « …ne dérive aucun kind/chemin [E] **Expected: false Actual: <true>** · `runtimeType` banni (AD-3/NFR-S8) ». RESTAURÉ → vert.
- **R3-e** (AC10, panne avalée) — `try { await batch.commit(); } catch (_) {}` → « commit() qui échoue ⇒ Left(ServerFailure) [E] **Expected: true Actual: <false>** » (Right au lieu de Left). RESTAURÉ → vert.
- **R3-f** (AC3, anti two-owners) — désactivé la garde (`if (false && …)`) → « owners DIFFÉRENTS ⇒ ArgumentError [E] **Expected: throws <ArgumentError>… Actual: <Closure: () => ZCascadeRegistry>** » (aucun throw). RESTAURÉ → vert.
- **R3-g** (AC5, cycle) — remplacé `if (!visited.add(kind)) continue;` par `visited.add(kind);` → self-edge `study_folder→study_folder` boucle à l'infini : **`dart test` RC=124 (timeout 40s)**, « Waiting for current test(s) to finish » (jamais terminé). RESTAURÉ → vert (+11).

### Completion Notes List

- **Conception registre (kernel, PUR)** : `ZCascadeEdge` = quadruplet de `String` (`parentKind`/`childKind`/`childParentRef`/`owner`), `==`/`hashCode` sur le tuple, **aucun `Type`/générique**. `ZCascadeRegistry(List<ZCascadeEdge>)` indexe `parentKind → arêtes` (listes non modifiables) ; le constructeur applique la **garde anti two-owners** (deux arêtes de même `(parentKind, childKind)` à `owner` différents → `ArgumentError` explicite ; doublon strictement identique dédupliqué). `descendantEdges(rootKind)` = **BFS déterministe** (ordre de déclaration) avec `Set<String> visited` de kinds (garde de cycle : le self-edge `folder→folder` termine). Zéro backend, zéro chemin, zéro `runtimeType`/`.toString()`. Web-safe (dart:core seul).
- **Conception batcher (adapter `zcrud_firestore`)** : `ZFirestoreCascadeBatcher` compose `ZCascadeRegistry` (quoi) + `ZFirestorePathResolver` (où) + `FirebaseFirestore` (SEULE couture, injectée). `deleteCascade` : (1) **énumère d'abord** toutes les cibles `(chemin, id)` (root + descendance) — snapshot AVANT soft-delete (fix lex F1) — par BFS d'instances bornée par un `Set` de couples `kind id` (garde de cycle sur les sous-dossiers) ; la **stratégie d'énumération est pilotée par `topologyOf`** (nested = tous les docs de la sous-collection ; flat/global = `where(childParentRef == parentId)`) ; (2) **flush borné** : double boucle `while (start < len) { … while (… && ops < _maxBatchWrites) …; commit; batchCount++ }`, chaque écriture = `set({is_deleted:true, updated_at:serverTimestamp}, merge:true)` — **hors-entité**, l'entité n'est jamais décodée.
- **Bornage** : `_maxBatchWrites = FirebaseZRepositoryImpl.kMaxBatchWrites` **réutilisé** (450, jamais re-hardcodé). Observable via `ZCascadeReport {batchCount, writeCount}` : writeCount 450→1, 451→2, 900→2, 901→3 lots (prouvé, `fake_cloud_firestore` n'imposant PAS la limite 500).
- **Divergence VOLONTAIRE de lex** : `_guard` remonte `Left(ServerFailure)` sur panne de `commit()` — **jamais** `catch(_){}→Right` (lex avale ; ES-3.3 dit la vérité). Documenté dans le dartdoc du batcher.
- **AD-11** : aucune signature publique n'expose `FirebaseFirestore`/`WriteBatch`/`Query`/`Timestamp` (retour `ZResult<ZCascadeReport>`) ; le constructeur injecte `FirebaseFirestore` (couture assumée, précédent `FirebaseZRepositoryImpl`).
- **Surface** : `ZCascadeEdge`/`ZCascadeRegistry` exportés au barrel kernel (placement alphabétique `directives_ordering`) et **ajoutés au `hide`** de `zcrud_flashcard` (D10, `z_kernel_surface_guard_test.dart` vert). `ZFirestoreCascadeBatcher`/`ZCascadeReport` exportés au barrel `zcrud_firestore`.
- **DW-ES33-1 (aval, non bloquante)** : placement physique des const d'arêtes dans les packages propriétaires + composition unique par `zcrud_study` déférés à ES-5 ; ici l'ensemble d'arêtes canonique est **fixture de test**. Mécanisme d'ownership prouvé (AC3).

### File List

- **NEW** `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart`
- **NEW** `packages/zcrud_study_kernel/test/z_cascade_registry_test.dart`
- **NEW** `packages/zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart`
- **NEW** `packages/zcrud_firestore/test/z_firestore_cascade_batcher_test.dart`
- **UPDATE** `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` — `export` du registre (placement alphabétique).
- **UPDATE** `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — `hide ZCascadeEdge, ZCascadeRegistry` (D10).
- **UPDATE** `packages/zcrud_firestore/lib/zcrud_firestore.dart` — `export` du batcher (placement alphabétique).
- **UPDATE** `packages/zcrud_firestore/lib/src/data/z_firestore_path_resolver.dart` — **ajout ADDITIF** `topologyOf(String kind)` (point d'extension public manquant, signalé).
