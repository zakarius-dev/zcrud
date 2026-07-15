# Code-review ES-3.2 — Helper offline-first + résolveur de chemins Firestore bi-topologie

Revue **adversariale** (effort high). Skill `bmad-code-review` invoqué (voie Skill, pas de fallback disque).
Périmètre : `z_offline_first_box_repository.dart`, `z_firestore_path_resolver.dart`, leurs tests, barrel + pubspec `zcrud_firestore`, `example/pubspec.yaml`.

## Verdict : APPROUVÉ — prêt pour `done`

13 ACs couverts par des tests à **pouvoir discriminant réel** (R12). Aucun finding HIGH / MAJEUR / MEDIUM.
**1 finding LOW** (edge foreign-writer, non bloquant). Story **verte** bout-en-bout.

## Vérif verte REPO-WIDE rejouée RÉELLEMENT sur disque (par l'orchestrateur de revue)

| Vérification | Résultat | RC |
|---|---|---|
| `dart analyze packages/zcrud_firestore` | No issues found! | 0 |
| `flutter test` (zcrud_firestore) | **119 tests passés** (29 ES-3.2 + 90 E5) | 0 |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** · arête `zcrud_firestore→zcrud_study_kernel` présente (34 arêtes, 18 nœuds) | 0 |
| `dart run scripts/ci/gate_reserved_keys.dart` | `[gate:reserved-keys] OK` (A+B+couverture) | 0 |
| `dart run scripts/ci/gate_web_determinism.dart` | `[gate:web] OK` (`zcrud_firestore` Flutter → exclu, D9) | 0 |
| `git status \| grep .g.dart` | **AUCUN** `.g.dart` modifié (adapters, 0 `@ZcrudModel`) | — |

## Injection adversariale rejouée par le reviewer (garde cœur, la plus critique)

- **R3-c (AC5 — LWW `isAfter`→`isBefore`)** : injectée par édition ciblée → `flutter test AC5` **ROUGE**
  (`AC5 … Actual: 'local-a'` attendu `'cloud-a'` ; **et** `AC6 … AC5 (a)/(b)`). La comparaison LWW est donc
  **LOAD-BEARING et discriminante** — un cloud plus ancien n'écrase jamais un local récent, un cloud plus récent est
  bien adopté. **Restaurée par copie du backup pré-injection** (`isAfter` re-vérifié en place) → `flutter test`
  **119/119 vert**. Aucune trace résiduelle (fichier UNTRACKED, ré-identique).

## Axes adversariaux (traque du pouvoir discriminant, R12)

1. **Offline-first réel (AD-9/AC3)** — `persist` : `local.put` → `fold` → renvoie `Right(saved)` **immédiatement**,
   push distant en `unawaited(_bestEffortPushFresh(...))`. **Aucun `await` caché** sur la voie distante. Une panne
   Firestore (`_ThrowingFirestore`) ne casse pas `save` (AC3 vert). ✔ Discriminant (R3-b compile/rougit si `await`é).
2. **Merge LWW hors-entité (AD-19/AC5/AC6)** — `adopt = localEntry==null || (cloudTime!=null && (localTime==null ||
   cloudTime.isAfter(localTime)))` : égalité stricte → **pas** d'adoption (isAfter faux), cloud plus ancien → **pas**
   d'adoption, cloud sans horodatage sur local présent → jamais adopté. Clé lue de `ZSyncEntry.updatedAt` (méta) et
   `_timeFromRaw(map[ZSyncMeta.kUpdatedAt])`, **jamais** `T.updatedAt`. Entité `_Note` **sans** `updatedAt` (miroir
   `ZMindmap`) prouve la nécessité de la clé hors-entité (compile-fail structurel R3-d). ✔ Discriminant (injection réelle).
3. **hasPendingWrites (AC7)** — `if (hasPendingWrites) return;` en tête de `handleCloudSnapshot` : l'écho local (`true`)
   ne merge pas, le snapshot confirmé (`false`) merge. Garde load-bearing (R3-e). ✔
4. **Décodage contextualisé ES-3.0 (AC8/DW-ES14-2)** — voie `_decode = registry.decode` threadée au `ZDecodeContext`.
   Round-trip cloud→`sync()`→merge→`getById` restitue `_TypedExt` **avec** contexte, `_OpaqueExt` **sans** (deux tests,
   R3-f). Extension typée survit réellement. ✔ Discriminant (pas powerless — observe le TYPE, pas « le contexte est passé »).
5. **Zéro-fuite backend (AD-11/AC11)** — aucune signature publique n'expose `FirebaseFirestore`/`CollectionReference`/
   `Timestamp`/`WriteBatch`/`QuerySnapshot`/`Box`/`FirebaseException` (`handleCloudSnapshot` = seam `@visibleForTesting`
   à signature **neutre** `List<MapEntry<String,Map>>`). Barrel n'exporte aucune lib firestore/hive/firebase_core (test
   directives + scan de signatures). Seule couture = injection `FirebaseFirestore`/`ZLocalStore` au constructeur. ✔
6. **AD-5 (AC12)** — `ZResult` partout, `Unit` pour void, `watchAll` = `Stream<List<T>>` **nu**. Aucun `try-catch` nu :
   `_decodeCloud`/`_bestEffortSet`/`sync` **loggent** avant d'avaler ; `sync` → `Right(unit)` sur `FirebaseException`/
   `isConnected==false`/chemin non résolu, panne **locale** de merge → `Left` (jamais avalée). ✔
7. **Soft-delete hors-entité (AC9)** — `_cloudMap` écrit `id`/méta PUIS `...ZSyncMeta.stripReserved(_encode(entity))`
   **en dernier** : le corps stripé ne peut PAS clobberer la méta autoritaire. Encodeur malveillant (fuite
   `is_deleted:true`/`updated_at:'LEAK'`) neutralisé (R3-g). `toMap` métier ne contient ni `is_deleted` ni `updated_at`. ✔
8. **Anti-réflexion (AC11)** — `ZFirestorePathResolver` = table littérale `kind → ZFirestorePathRule` ; aucun `T`/
   `runtimeType`/`.toString()` ; `Left(DomainFailure)` explicite sur kind inconnu / nested sans `parentId` / user-scopé
   sans `userId`. Le CRUD quasi-réflexif IFFD est **structurellement impossible** (le résolveur ne connaît que des
   `String kind`). ✔
9. **Bi-topologie (AC10)** — flat / flat-user-scopé / nested-under-parent / global correctement distingués ;
   `collectionIdOverride ?? _parentId` surcharge bien le parentId ; branches échangées → mauvais chemin → rougit (R3-h). ✔
10. **AD-1/AD-17** — nouvelle arête `zcrud_firestore→zcrud_study_kernel` : DAG (kernel→core only), CORE OUT=0 préservé,
    `graph_proof` vert. `z_offline_first_repository.dart` (E5-3) **intouché** — distinct de la base ES-3.2. ✔
11. **Couverture 13 ACs** — chaque AC a un test discriminant (comportemental pour AC2-AC10/AC12 ; source-scan pour AC11
    et AC6-test1, mais AC6 est **doublé** d'une re-preuve fonctionnelle + compile-fail structurel). ✔

## Findings

### LOW-1 — Normalisation `updated_at` en voie morte pour la méta d'un doc écrit avec un `Timestamp` natif (foreign/legacy)
**Fichier** : `packages/zcrud_firestore/lib/src/data/z_offline_first_box_repository.dart:168-188, 435`
**Constat** : `_decodeCloud` normalise `updated_at` (`Timestamp`→ISO) sur une **copie** (`final map = {...data, _kId: id}`)
qui n'alimente que `_decode` (décodage d'entité, lequel **ignore** `updated_at`). La voie méta lit le map **brut** :
`cloudMeta = ZSyncMeta.fromJson(map)` (l.435) — or `ZSyncMeta.fromJson` fait `_parseIso` qui **retourne `null` pour
tout non-`String`** (`z_sync_meta.dart:78-80`). La dartdoc de `_normalizeMetaIso` (« pour que `ZSyncMeta.fromJson` …
la relise ») **n'est donc pas câblée** sur le chemin méta.
**Scénario d'échec** : un **client tiers/legacy** écrit `updated_at` en `Timestamp` Firestore natif (pas ISO). À
l'adoption, `cloudTime` (via `_timeFromRaw`, qui gère `Timestamp`) est correct → décision LWW juste ; mais la méta
**stockée localement** devient `updatedAt: null`. Au `sync()` suivant, `localTime==null` ⇒ ré-adoption → **amplification
d'écritures locales idempotentes** (l'entrée ne « se stabilise » jamais). **Pas de corruption ni de perte de donnée.**
**Hors système** : `_cloudMap` écrit **toujours** `updated_at` en ISO (confirmé par `timestamp_hint_test` AC8 :
« updated_at reste String ISO malgré la clé hintée ») — le défaut ne se déclenche **que** pour des docs non écrits par
ce dépôt. D'où LOW.
**Correction proposée (optionnelle, hors story si reportée)** : normaliser le map **une fois** avant d'en tirer À LA FOIS
l'entité et la méta — p.ex. `_normalizeMetaIso(map)` sur `doc.value` en tête de boucle `_mergeSnapshotWithLocal`, ou
parser `cloudMeta` avec `updatedAt: cloudTime` (déjà tolérant) plutôt que `ZSyncMeta.fromJson(rawMap)`. Aligne le code
sur sa propre dartdoc.
**Statut** : LOW / nit — **reporté** (edge foreign-writer, sans impact système, hors AC ; à consigner en dette d'ES-3
si jamais un writer tiers en `Timestamp` natif est introduit).

## Notes de conformité

- **`example/pubspec.yaml`** : 2 overrides CONSOMMATEUR `path` (`zcrud_study_kernel`, `zcrud_annotations` transitif),
  bénins — app standalone hors melos/graph_proof, requis pour `dart pub get` de l'exemple face à la nouvelle dép
  transitive `^0.1.0`. Aucun secret/endpoint. `example/pubspec.lock` reste hors commit (CLAUDE.md). ✔
- **Non touchés** (conformes R9) : `zcrud_core`, `zcrud_study_kernel/lib`, `tool/reserved_keys_gate/**`, tout `.g.dart`,
  `z_offline_first_repository.dart` (E5-3), le sprint-status. ✔
- **Restauration post-injection** : backup pré-injection re-copié, `isAfter` re-vérifié en place, 119/119 tests verts.
  Le fichier étant UNTRACKED, `git diff` ne l'affiche pas — preuve par **retour au vert** (exigé par la consigne). ✔
