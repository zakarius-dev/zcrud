# Réfutation — M2 : « 823 lignes d'adaptateur Firestore, le socle sait déjà le faire »

Domaine : Moteur de formulaires et listes historique, et la bascule en cours (IFFD)
Date : 2026-08-26 · Méthode : lecture de corps (jamais de dartdoc seule), grep négatifs montrés.
Dépôts en LECTURE SEULE : `/home/zakarius/DEV/iffd`. Aucun test lancé. Aucun secret cité.

## VERDICT : **RÉFUTÉE**

Le canal existe et la mesure de duplication est exacte. Mais **les trois affirmations
qui rendent la migration « sûre » sont fausses**, et la principale est *inversée* :
le piège du parc legacy non backfillé ne « ne s'applique pas » — **c'est exactement
le cas d'IFFD**.

---

## 1. Ce qui RÉSISTE (vérifié à l'octet)

| Affirmation | Vérification | Statut |
|---|---|---|
| `FirebaseZRepositoryImpl<T extends ZEntity>` à `firebase_z_repository_impl.dart:156` | `156:class FirebaseZRepositoryImpl<T extends ZEntity> extends ZRepository<T>` | ✅ |
| ctor `:159-170`, `fromMap`/`toMap` **paramètres requis** | `159:  FirebaseZRepositoryImpl({` … `required T Function(Map<String, dynamic> map) fromMap,` / `required Map<String, dynamic> Function(T value) toMap,` — aucun `ZcrudRegistry` requis (la voie registre est une **factory séparée**, `:261`) | ✅ |
| `omitNullFields`, `timestampFields`, `deletionSemantics`, `legacyDeletedKey` | tous présents au ctor `:166-170` | ✅ |
| Exporté par le barrel | `packages/zcrud_firestore/lib/zcrud_firestore.dart:22 → export 'src/data/firebase_z_repository_impl.dart';` | ✅ |
| Atteignable depuis IFFD | `iffd/pubspec.yaml:310-314` (`dependencies`) **et** `:622-626` (`dependency_overrides`) | ✅ |
| Duplication : 6 blocs = **823 lignes** | folder `379-516`=**138** · flashcard `373-509`=**137** · exam `474-610`=**137** · document `312-448`=**137** · mindmap `409-545`=**137** · note `272-408`=**137** → **823** | ✅ |
| exam vs note : 12 lignes de diff sur 137 → 131/137 = **95,6 %** | `diff` rejoué : 12 lignes `^[<>]`, soit **6 lignes changées** (nom de classe ×2, `kDefaultCollection`, `ZBacked*Mapper.kId` ×3). 137−6 = 131 → **95,62 %** | ✅ |
| `ZSmartNote extends ZEntity` à `zcrud_note/lib/src/domain/z_smart_note.dart:78`, `fromMap :124`, `toMap :285` | les trois coordonnées confirmées ; barrel `zcrud_note.dart:105` l'exporte | ✅ |
| Les 5 autres entités existent aussi | `ZStudyFolder` (study_kernel `:77`), `ZStudyDocument` (document `:74`), `ZFlashcard` (`:64`), `ZExam` (`:72`), `ZMindmap` (`:41`) — tous `extends ZEntity` | ✅ (bonus non revendiqué) |
| RÉSERVE `hardDelete` sans pendant socle | `grep -rn "hardDelete" packages/zcrud_firestore/lib/` → **0 ligne** | ✅ |

Le socle est réel, atteignable, et la douleur de l'hôte est correctement chiffrée.
**C'est tout ce qui tient.**

---

## 2. RÉFUTATION 1 — la sémantique de suppression est l'**INVERSE** de ce qui est affirmé

L'affirmation dit : *« ses lectures filtrent `isNotEqualTo: true` (:364) — c'est mot pour
mot `ZDeletionSemantics.strict`, le défaut. Le piège du parc legacy non backfillé NE
S'APPLIQUE DONC PAS. »*

`:364` est **`asyncCount` — une méthode sur huit**. Les **trois chemins de lecture réels**
(`streamAll`, `streamOne`, `streamByIds`) ne portent **aucune clause serveur** ; ils
filtrent en client par un prédicat identique dans les **6 fichiers** :

```
z_backed_smart_note_repository.dart:291      (idem folder:398, flashcard:392,
  bool _isDeleted(Map<String, dynamic> data) =>   exam:493, document:331, mindmap:428)
      data[ZSyncMeta.kIsDeleted] == true;
```

Un document **sans** `is_deleted` → `null == true` → `false` → **`!_isDeleted` = vrai → VISIBLE**.
C'est la définition littérale de **`absentMeansAlive`**, pas de `strict`.

Le socle en `strict` fait l'exact contraire, dans le corps (pas la dartdoc) :

```
firebase_z_repository_impl.dart:604-613   _matchesScope(...)
  case ZDeletionSemantics.strict:
    case ZDeletedScope.aliveOnly:
      return data[_kIsDeleted] == false;      // absent → null==false → EXCLU
firebase_z_repository_impl.dart:680
      return raw.where(_kIsDeleted, isEqualTo: false);   // absent → EXCLU (serveur)
```

Et le prédicat est appliqué **aussi** à `getById` (`:936-948`), donc sans échappatoire.

### Le parc IFFD n'est PAS backfillé — il n'utilise même pas la bonne clé

Le moteur legacy encore vivant écrit **`deleted`**, jamais `is_deleted` :

```
iffd/lib/src/data/repositories/firebase_crud_repository_impl.dart:350   "deleted": false,
iffd/lib/src/data/repositories/firebase_crud_repository_impl.dart:377   "deleted": true,
```

…dans **les mêmes collections** que le chemin z_backed (`SmartNoteModel`, `ExamModel`,
`FolderModel`, … — cf. `kDefaultCollection`, commentées « Collection **legacy** d'IFFD »).

⇒ Brancher `FirebaseZRepositoryImpl` **au défaut `strict`**, comme l'affirmation le
préconise, **ferait disparaître silencieusement, en prod, tout document du parc
historique** (aucun n'a `is_deleted`). Sans erreur, sans exception — la trappe que la
dartdoc du socle décrit elle-même (`:129-141`) et que l'affirmation déclare inapplicable.

**Le mode correct est `absentMeansAlive` + `legacyDeletedKey: 'deleted'`.** L'affirmation
nomme ces paramètres mais conclut à l'opposé de leur nécessité.

Corollaire non mentionné : en `absentMeansAlive`, `count()` **perd l'agrégat serveur** et
devient un décompte client de toute la collection (`:967-980`). L'hôte, lui, utilise
aujourd'hui l'agrégat serveur (`:364`). C'est une régression de coût, pas neutre sur un
parc legacy.

Note secondaire : l'hôte est **incohérent avec lui-même** (count strict-like vs streams
absent-means-alive). Aucun des deux modes du socle ne reproduit ce mélange à l'identique.

---

## 3. RÉFUTATION 2 — couverture **partielle** : 58 lignes sur 137 n'ont aucun pendant

Découpage exact du bloc de 137 lignes (offsets relevés sur l'extrait `note` `272-408`) :

| Membre | lignes | Pendant socle | Couvert |
|---|---:|---|:---:|
| ctor + champs + `_collection` | 19 | ctor `:159-170` | ✅ |
| `_isDeleted` | 3 | `_matchesScope` (sémantique à corriger, cf. §2) | ⚠️ |
| `_withId` | 4 | `_decode(d.id, data)` | ✅ |
| `streamAll` | 8 | `watchAll()` `:823` | ✅ |
| **`streamOne(id)`** | **10** | **aucun** | ❌ |
| **`streamByIds(ids)`** (`whereIn` chunké ≤30, `FieldPath.documentId`) | **20** | **aucun** | ❌ |
| **`_combine`** (fan-in des flux chunkés) | **26** | **aucun** | ❌ |
| `asyncCount` | 9 | `count()` `:960` | ✅ |
| `put(canonical, {merge})` | 18 | `save(T)` — mais cf. §4 | ⚠️ |
| `softDelete` / `restore` | 18 | `:1036` / `:1040` | ✅ |
| **`hardDelete`** | **2** | **aucun** | ❌ |
| **total** | **137** | | |

Grep négatifs **montrés** :

```
$ grep -rn "watchById\|watchOne\|streamOne\|watchDoc" --include="*.dart" packages/*/lib/
[aucune ligne]

$ grep -rn "chunk\|sublist\|30" packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart
[aucune ligne]

$ grep -rn "hardDelete" packages/zcrud_firestore/lib/
[aucune ligne]
```

- **Pas de lecture réactive d'un document unique** dans *tout* zcrud. Le port
  `ZRepository` (`zcrud_core/lib/src/domain/ports/z_repository.dart:125-200`) expose
  `watchAll`, `watch`, `getAll`, `getById`, `count`, `save`, `softDelete`, `restore`,
  `dispose`. `getById` est un `Future`, pas un `Stream` : il ne remplace pas `streamOne`.
- **`ZFilterOp.isIn` existe** (`_applyFilters :722-729`) mais (a) **ne chunke pas à 30** —
  au-delà, Firestore lève ; (b) porte sur un **champ de corps `String`**, pas sur
  `FieldPath.documentId` que l'hôte utilise. Or l'hôte **retire** `id` du corps sur la voie
  auto-id (`body.remove(ZBackedSmartNoteMapper.kId)` avant `add()`) : ces documents n'ont
  **pas** de corps `id`, donc ni `whereIn` sur `id`, ni le tie-break `orderBy(_kId)` du
  socle (`_buildQuery :781`) ne les atteindraient.

⇒ **58 lignes non couvertes par bloc × 6 blocs = 348 lignes qui RESTENT.**
Gain réel plafond : **823 − 348 = 475 lignes (57,7 %)**, pas 823.

---

## 4. RÉFUTATION 3 — condition cachée : `merge: true` vs écrasement TOTAL

L'hôte écrit en fusion, `merge` **vrai par défaut** :

```
z_backed_smart_note_repository.dart:100-117 (offset bloc)
  Future<String?> put(Map<String, dynamic> canonical, {bool merge = true}) async {
    …
    await _collection.doc(docId).set(body, SetOptions(merge: merge));
```

Le socle n'a **aucune** voie de fusion Firestore :

```
$ grep -n "SetOptions" packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart \
    | grep -v "///"
[aucune ligne — SetOptions n'apparaît QUE dans des dartdoc]
```

et son propre corps + dartdoc l'assument (`:986-993`, `save :1019-1021`) :
« Persiste [item] en **écrasement TOTAL** (`batch.set`, JAMAIS un merge) […] tout champ
hors `_toMap`/`_encode` présent sur le document existant est **écrasé** ».
`writeMerged`/`applyMergedAll` (`:1101`, `:1131`) sont aussi des `batch.set` **sans**
`SetOptions` : « merge » y désigne le LWW applicatif, pas la fusion Firestore.

**Conséquence dans le contexte réel d'IFFD** — cutover *strangler fig*, les deux moteurs
co-écrivent le même document (`z_backed_smart_note_repository.dart:1-9` : « EN PARALLÈLE
de `FirebaseFolderNoteRepositoryImpl`. AUCUNE ligne legacy n'est retirée. Le provider
choisit, derrière un flag Riverpod (défaut = LEGACY) […] **Une régression se corrige en
RE-basculant le flag, PAS en revertant.** ») :

1. Un `save()` socle **efface la clé `deleted`** du document — la clé dont dépend tout le
   chemin legacy encore actif.
2. Il efface tout champ Firestore hors périmètre du mapper.
3. ⇒ **La garantie de rollback documentée est annulée** : re-basculer le flag ne
   restaure pas les clés détruites. C'est une perte de données irréversible, pas une
   régression réversible.

Le paramètre `omitNullFields` ne couvre pas ce cas — sa propre dartdoc (`:333-342`) parle
d'être « sûr pour tout co-écrivain du même parc opérant, lui, en `merge: true` », c'est-à-dire
le cas symétrique, pas celui-ci.

---

## 5. Ce qu'il faudrait pour que l'affirmation devienne vraie

1. Configurer `deletionSemantics: absentMeansAlive` **+** `legacyDeletedKey: 'deleted'`
   (jamais le défaut `strict`) — et accepter la perte de l'agrégat serveur sur `count`.
2. Ajouter au socle, en additif : (a) une lecture réactive d'un document unique
   (`watchById`) ; (b) un `whereIn` **chunké ≤ 30** avec fan-in, adressable par identité
   de document ; (c) une voie d'écriture **fusionnée** (`SetOptions(merge:)`) ou, à défaut,
   interdire explicitement l'usage du socle en co-écriture ; (d) `hardDelete`.
3. Backfiller le corps `id` sur les documents créés par `add()`, sans quoi les lectures
   triées/paginées du socle (`orderBy(_kId)`, `:781`) les excluent en prod.

Tant que (2) n'est pas livré, la migration retire **475 lignes au mieux**, laisse **348
lignes** en place, et **exige** une configuration opposée à celle que l'affirmation avance.

## 6. Chiffres

- Blocs dupliqués : **6** · **823** lignes · similarité **95,62 %** (mesurée, pas estimée).
- Fichiers hôtes concernés : **6** (4 648 lignes au total, dont 823 dans le périmètre).
- Sites où `_isDeleted` implémente `absentMeansAlive` : **6/6**.
- Lignes sans pendant socle : **58/137 par bloc** = **42,3 %** → **348** au total.
- Gain réel plafond : **475 lignes** (57,7 % de l'annoncé).
- Canaux socle manquants : **4** (`watchById`, chunking `whereIn`, écriture fusionnée, `hardDelete`).
