# Réfutation — M-4 « Dépôt Firestore générique » (SmartNotes)

- **Domaine** : Notes intelligentes (SmartNotes) — IFFD @ `65d1af9` vs zcrud @ `cc276c154` (v3.21.0)
- **Affirmation attaquée** : « le socle sait déjà le faire, par `FirebaseZRepositoryImpl<T extends ZEntity>` + `.fromRegistry` + `ZDeletionSemantics` + `timestampFields` ». Gain annoncé : ~137 lignes d'hôte supprimées, voie d'erreur remise sur `Either<ZFailure,T>`.
- **Verdict** : **DÉMENTIE**. Le canal existe et son corps fait bien ce qu'on lui prête, mais **la couverture est présentée comme quasi totale alors qu'elle est partielle**, **le bénéfice « voie d'erreur » est inversé** (le socle *ajoute* de la fabrication de `FirebaseException`, il n'en retire aucune), et **une condition cachée détruit des données** sur la collection partagée du strangler fig.

---

## 1. Ce qui TIENT (vérifié sur disque, ligne à ligne)

Toutes les coordonnées avancées sont **exactes**. `grep -n` sur `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (1 174 lignes) :

| Élément avancé | Ligne réelle | État |
|---|---|---|
| `enum ZDeletionSemantics` | `:57` (`strict` `:63`, `absentMeansAlive` `:80`) | ✅ |
| `class FirebaseZRepositoryImpl<T extends ZEntity> extends ZRepository<T>` | `:156` | ✅ |
| Garde EXÉCUTOIRE `_timestampFields = timestampFields.difference(ZSyncMeta.reservedKeys)` | `:206` | ✅ (hors `assert`, tient en release) |
| `factory FirebaseZRepositoryImpl.fromRegistry` | `:261` | ✅ |
| `_guard<R>` → `ZResult` | `:805` | ✅ (`FirebaseException`→`ZServerFailure`, `ZFailure` repropagé, reste→`ZServerFailure`, **jamais** `catch(_){}`) |
| `watchAll()` / `watch(ZDataRequest)` → `Stream<List<T>>` **nus** | `:823` / `:827` | ✅ |
| `getAll` / `getById` / `count` / `save` / `softDelete` / `restore` | `:913` / `:923` / `:960` / `:1009` / `:1036` / `:1040` | ✅ |

Autres legs vérifiés :

- **Borne générique satisfaite** : `awk 'NR==78'` sur `packages/zcrud_note/lib/src/domain/z_smart_note.dart` rend exactement `class ZSmartNote extends ZEntity with ZExtensible {`. ✅
- **Atteignabilité** : `packages/zcrud_firestore/lib/zcrud_firestore.dart` porte `export 'src/data/firebase_z_repository_impl.dart';` (1ʳᵉ ligne d'export). `zcrud_firestore` est déclaré chez l'hôte : `/home/zakarius/DEV/iffd/pubspec.yaml:310` (`dependencies`) **et** `:622` (`dependency_overrides`). ✅
- **Canal réellement inutilisé chez l'hôte** — *grep négatif montré* :
  ```
  $ grep -rn "FirebaseZRepositoryImpl" /home/zakarius/DEV/iffd/lib /home/zakarius/DEV/iffd/test
  RC=1   (aucune occurrence)
  ```
  IFFD n'importe `package:zcrud_firestore` que dans **5 fichiers de `lib/`** (`z_iffd_date_migration.dart:32`, `z_iffd_legacy_codec.dart:27`, `z_migration_dry_run.dart:29`, `z_deep_census.dart:27`, `z_backed_folder_document_repository.dart:39` — ce dernier `show ZStudyLegacyCodec`) + 5 fichiers de `test/`. Le chiffre « 5 fichiers, jamais `FirebaseZRepositoryImpl` » de l'affirmation est **exact**. ✅
- **`absentMeansAlive` est bien le bon mode** : `SmartNoteModel` ne porte aucun drapeau de suppression — *grep négatif montré* :
  ```
  $ grep -rn "is_deleted\|isDeleted" /home/zakarius/DEV/iffd/lib/src/domain/models/smart_note_model.dart
  RC=1
  ```
  Et `_scopedQuery` (`:671-688`) rend `raw` **sans aucune clause** en `absentMeansAlive`, `_matchesScope` (`:604-626`) filtrant côté client — soit exactement la sémantique de l'hôte (`streamAll` filtre `_isDeleted(m)` en mémoire, `z_backed_smart_note_repository.dart:298-303`). ✅
- **Pas de perte du canal hors-codegen `content`** : le registrar `registerZSmartNote` (`z_smart_note.g.dart:252-263`) enregistre `toMap: (value) => value.toMap()` — le `toMap()` **d'instance** (`z_smart_note.dart:285-298`), qui étale `kContentKey` et `extra`. La voie `fromRegistry` préserve donc `content` et les clés `iffd_*`. ✅
- **Le compte de lignes est juste** : `FirestoreZNoteDataPath` occupe `z_backed_smart_note_repository.dart:272` (`class …`) à `:408` (`}` fermante) = **137 lignes**. ✅

Jusqu'ici, l'affirmation est solide. Elle casse sur cinq points.

---

## 2. R1 — DÉCISIF : la « voie d'erreur remise sur `Either<ZFailure,T>` » est **inversée**

Le contrat public de l'hôte n'est pas `ZResult`. `ZBackedSmartNoteRepository implements FolderNoteRepository` (`:426`), donc `CrudRepository<SmartNoteModel>` : **chaque écriture rend un `FirestoreDataState<T>`**. Et l'échec de ce type porte une contrainte dure :

```
/home/zakarius/DEV/iffd/lib/src/utils/resources/firestore_data_state.dart:22-24
class FirestoreDataFailed<T> extends FirestoreDataState<T> {
  const FirestoreDataFailed(FirebaseException error) : super(error: error);
}
```

`FirebaseException` est **positionnel et non-nullable**. Conséquences mesurées :

- **Aujourd'hui**, 5 méthodes d'écriture attrapent une **vraie** `FirebaseException` remontée par `FirestoreZNoteDataPath` et la passent **verbatim** : `create` (`:477-478`), `update` (`:501-502`), `delete` (`:520-521`), `softDelete` (`:531-532`), `restore` (`:542-543`) — toutes en `on FirebaseException catch (e) { return FirestoreDataFailed(e); }`. Le `code`, le `plugin` et la stack d'origine Firestore **arrivent intacts** à l'UI.
- **Après migration**, `_guard` (`:805-818`) **absorbe** la `FirebaseException` et la réduit à `Left(ZServerFailure(e.message ?? e.code))` — une `String`. L'hôte, tenu par `FirestoreDataFailed(FirebaseException)`, devra **fabriquer** une `FirebaseException` synthétique sur ces 5 sites aussi.

Le compte des sites de `_err` :
```
$ grep -c "_err(" .../z_backed_smart_note_repository.dart
9      (1 déclaration :465 + 8 appels : :473 :485 :509 :516 :527 :538 :579 :585)
```
Sur ces **8 appels**, **6 sont des préconditions d'hôte** (`id null` × 4, exception de mapping × 2) qui n'ont **rien à voir avec le chemin de données** et survivent identiques à la migration ; les 2 autres (`all` `:579`, `find` `:585`) aussi. **Aucun des 8 ne disparaît.** Au contraire : la migration en **ajoute 5**, portant `_err` de 8 à 13 sites, et **dégrade** la qualité de l'échec (perte de `e.code`/`e.plugin`).

⇒ L'affirmation « Supprime … la fabrication d'échecs en `FirebaseException` (`_err`, `:465`), contraire à AD-5 » est **fausse à l'endroit exact où elle est avancée**. AD-5/AD-11 valent pour les paquets zcrud ; le contrat `FirestoreDataState` d'IFFD n'est pas migrable par ce lot, et il **impose** la fabrication.

---

## 3. R2 — La réserve annoncée (« 1 méthode sur 8 ») est fausse : **au moins 3 sur 8**

`ZNoteDataPath` (`:250-263`) déclare 8 méthodes. Bilan réel :

| # | Méthode hôte | Équivalent socle | Verdict |
|---|---|---|---|
| 1 | `streamAll()` | `watchAll()` `:823` en `absentMeansAlive` | ✅ |
| 2 | `streamOne(String id)` | **AUCUN** | ❌ **non signalé** |
| 3 | `streamByIds(List<String>)` | partiel, **cassé au-delà de 30 ids** | ❌ **non signalé** |
| 4 | `asyncCount()` | `count()` `:960` | ✅ (décompte client en `absentMeansAlive`, coût documenté `:965-975`) |
| 5 | `put(canonical, {merge})` | `save()` `:1009` | ❌ **sémantique différente** — cf. R3 |
| 6 | `softDelete(id)` | `softDelete()` `:1036` | ✅ (nuance : `_setDeletedFlag` `:1044-1049` exige `snap.exists` → `Left(NotFound)` ; l'hôte, lui, `set(merge:true)` crée le document) |
| 7 | `restore(id)` | `restore()` `:1040` | ✅ (même nuance) |
| 8 | `hardDelete(id)` | **AUCUN** | ❌ (seul reconnu) |

### 3a. `streamOne` — flux temps réel d'un document unique : pas d'équivalent

*Grep négatif montré*, sur **tous** les paquets :
```
$ grep -rn "watchById\|watchOne\|watchSingle" packages/*/lib/
RC=1   (aucune occurrence)
```
Et le port lui-même n'expose que du pluriel :
```
$ grep -rn "Stream<" packages/zcrud_core/lib/src/domain/ports/z_repository.dart
:65   Stream<List<T>> watchAll();
:73   Stream<List<T>> watch(ZDataRequest request);
:125  Stream<List<T>> watchAll();
:134  Stream<List<T>> watch(ZDataRequest request);
```
`getById` (`:923`) est un **`Future`**, pas un flux. L'hôte s'en sert en flux : `streamOne(id)` (`:562-567`) et `find(id)` (`:582-587`), ce dernier étant une méthode du contrat public `CrudRepository`.

L'émulation évidente — `watch(ZDataRequest(filters: [ZFilter('id', ZFilterOp.eq, id)]))` — **ne marche pas sur ce corpus** : elle exige un champ **de corps** `id` égal à l'identifiant du document, et **aucune des deux voies de création ne l'écrit** :
- voie zcrud-backed : `put` fait `body.remove(ZBackedSmartNoteMapper.kId)` **avant** `_collection.add(body)` (`:379-382`) → document **sans clé `id`** ;
- voie legacy : `firebase_crud_repository_impl.dart:232` fait `collectionReference.add(data)` où `data = model.toMap()` porte `'id': id` avec `id == null` (`folder_model.dart:291`) → document avec **`id: null`**.

### 3b. `streamByIds` — `whereIn` sur `FieldPath.documentId`, chunké par 30

L'hôte (`:316-338`) découpe en tranches de 30 et interroge `FieldPath.documentId`. Le socle ne sait faire ni l'un ni l'autre :
- `ZFilter.field` est typé **`String`** (`packages/zcrud_core/lib/src/domain/data/z_data_request.dart:141`) — un `FieldPath` est **inexprimable** ;
- `_applyFilters`, branche `isIn` (`:722-728`), passe la **liste entière** à `whereIn` sans découpage. Au-delà de la borne Firestore (30), la requête lève.

Le socle sait donc servir `streamByIds` **seulement** pour ≤ 30 ids **et** seulement si les documents portent un champ de corps `id` — condition non remplie (cf. 3a).

---

## 4. R3 — CONDITION CACHÉE : `save` **écrase** le corps legacy de la collection partagée

C'est le point le plus grave, et il n'est mentionné nulle part dans l'affirmation.

`save` écrit en **écrasement TOTAL** :
```
firebase_z_repository_impl.dart:1016-1021
final map = _encode(item)..[_kId] = id;
final batch = _firestore.batch();
batch.set(collection.doc(id), map);   // set NU, aucun SetOptions
await batch.commit();
```
Sa propre dartdoc l'assume (`:1002-1007`) : « tout champ hors `_toMap`/`_encode` présent sur le document existant est **écrasé** … aucune préservation de méta concurrente ».

Or `put` de l'hôte fait l'inverse (`:384`) : `set(body, SetOptions(merge: merge))`, avec `merge` à **`true` par défaut** — utilisé tel quel par `update` (`:499`), `batchSet` (`:620`) et `batchUpdate` (`:648`).

Et ce `merge` **porte quelque chose**. Le cutover est un **strangler fig en parallèle** sur la **même collection** `'SmartNoteModel'` (`:280`) : `FirebaseFolderNoteRepositoryImpl` (`firebase_models_repositories_impls.dart:100`) y écrit toujours, en **camelCase**, via `FirebaseCrudRepositoryImpl.set` → `.set(data, SetOptions(merge: merge))` (`firebase_crud_repository_impl.dart:241-247`) avec `data = model.toMap()` = `{'id', 'subjectId', 'folderId', 'subFolderId', 'creatorId', 'createdAt', 'title', 'content', 'audioText', 'audioUrl', 'audioPath', 'audioTextHash'}` (`smart_note_model.dart:29-42` + `folder_model.dart:289-297`).

`ZBackedSmartNoteMapper.toCanonical` (`:138-171`) ne rend **que** le snake_case du schéma `ZSmartNote` + les clés `iffd_*` de `extra`. Il ne transporte **pas** `folderId`, `subjectId`, `audioUrl`… en camelCase — il n'a aucune raison de le faire, il part d'un `SmartNoteModel` **en mémoire**, pas du document sur disque.

⇒ **Une seule écriture par le socle efface le corps camelCase du document.** Le fichier lui-même désigne le rollback comme filet (`:7-8` : « Une régression se corrige en RE-basculant le flag, PAS en revertant ») — après un `save` zcrud, re-basculer le flag rend un `FirebaseFolderNoteRepositoryImpl` qui lit `map['folderId']`, `map['title']`, `map['content']` **absents**. Le filet de rollback est **détruit silencieusement**, et la donnée avec.

C'est très exactement le motif « hôte qui COMPENSAIT » de `CLAUDE.md` : le `merge: true` n'est pas une négligence de l'hôte, c'est sa **compensation** du parallel-run. La migrer sans le dire transforme un contournement en perte de données.

---

## 5. R4 — `timestampFields` est **inerte** pour ce domaine

L'affirmation avance `timestampFields` comme l'un des quatre canaux porteurs. Pour `ZSmartNote`, le générateur rend un ensemble **vide** :
```
packages/zcrud_note/lib/src/domain/z_smart_note.g.dart:270
const Set<String> $ZSmartNoteTimestampFields = <String>{};
```
Aucun `@ZcrudField` de `ZSmartNote` n'est hinté `persistAs: timestamp` (`grep -n "persistAs" z_smart_note.dart` → aucune occurrence dans le fichier). La garde exécutoire `:206` est réelle et correcte — mais elle soustrait des clés réservées d'un **ensemble vide**. Ce canal ne contribue **rien** à cette migration ; le citer comme preuve gonfle le dossier.

---

## 6. R5 — Prérequis caché : `.fromRegistry` exige un `ZcrudRegistry`, **IFFD n'en a aucun**

La voie « recommandée » de l'affirmation est `FirebaseZRepositoryImpl.fromRegistry` (`:261`). Elle prend `required ZcrudRegistry registry`. *Grep négatif montré* :
```
$ grep -rn "ZcrudRegistry" /home/zakarius/DEV/iffd/lib/
RC=1   (aucune occurrence)
```
Aucun registre n'est instancié ni amorcé côté hôte aujourd'hui. Le canal cité n'est donc **pas appelable en l'état** : il faut d'abord monter un `ZcrudRegistry`, appeler `registerZSmartNote`, et — pour typer `extension`/`source` — câbler un `ZDecodeContext`. Travail additif, certes, mais absent du bilan « ~137 lignes supprimées ».

---

## 7. R6 — Précondition « corps `id` » non remplie (bloque le bénéfice tri/pagination)

Le socle documente (`:123-131`) qu'en **prod** `orderBy('id')` **exclut silencieusement** tout document dépourvu du champ de corps `id`, et que `ZCursor` en dépend. Le déclencheur est `_buildQuery:779-781` (`if (hasSorts || req.startAfter != null) q = q.orderBy(_kId);`).

Aucune des deux voies de création ne pose ce champ (cf. 3a). Aujourd'hui c'est sans effet — l'adaptateur hôte n'utilise jamais de tri serveur (`_decodeList:451-461` ne connaît que `itemFilter` et `limit`, en mémoire). Mais cela signifie que **le tri et la pagination par curseur, principaux bénéfices « gratuits » d'un dépôt générique, restent inaccessibles sans backfill du corpus**. Le gain net est donc plus étroit que « le socle sait déjà le faire ».

---

## 8. R7 — Le chiffre du gain : 137 lignes réelles, mais pas 137 lignes économisées

Les 137 lignes existent (`:272`→`:408`). Elles ne s'évaporent pas : remplacer `FirestoreZNoteDataPath` par `FirebaseZRepositoryImpl` oblige à réécrire, côté hôte, une couche d'adaptation portant au minimum (a) `streamOne` en flux depuis un `Future getById`, (b) `streamByIds` avec découpage par 30 sur `FieldPath.documentId`, (c) `hardDelete`, (d) la sémantique `merge`, (e) un traducteur `ZFailure → FirebaseException` sur ≥ 5 sites, (f) le bootstrap d'un `ZcrudRegistry`. Le solde plausible est nettement inférieur à 137, et négatif sur l'axe erreurs.

Note d'ampleur, à décharge de la CR : le même patron de 137 lignes est **répliqué 4 fois** dans IFFD — `z_backed_flashcard_repository.dart:417`, `z_backed_folder_repository.dart:423`, `z_backed_folder_document_repository.dart:356`, `z_backed_smart_note_repository.dart:316`. Le besoin d'assemblage est donc **réel et plus large** que ce que M-4 décrit. Mais un assemblage qui ne couvre ni le flux unitaire, ni le lot par ids, ni le merge, ni le hard-delete ne les remplacera pas.

---

## 9. Ce qu'il faudrait pour que M-4 tienne

1. Un flux unitaire au socle (`watchById(String id)` sur `ZReadOnlyRepository`, résolu par `doc(id).snapshots()`, **pas** par un filtre de corps) — sinon `streamOne`/`find` restent chez l'hôte.
2. Une voie « par identifiants de documents » (découpage ≥ 30 assumé par l'adaptateur), inexprimable via `ZFilter.field: String`.
3. Un `hardDelete` (déjà tracé en M-11).
4. Un mode d'écriture **fusionnante** explicite (`save(…, merge: true)` ou `patch`), sans lequel tout parc partagé avec un chemin legacy perd son corps au premier `save`.
5. Le dire dans le handoff sous la forme prescrite par `CLAUDE.md` : *l'hôte qui compensait (`merge: true`) doit retirer sa compensation — ou ne pas migrer*.

Tant que 1, 2 et 4 manquent, l'affirmation « le socle sait déjà le faire » n'est pas tenue : il sait faire **la moitié bien mesurable**, et la moitié manquante est celle qui touche à la donnée.

---

### Non vérifiable ici (dit, pas deviné)

- Le contenu réel de la collection Firestore `SmartNoteModel` en production (présence de `is_deleted`, de corps `id`, de clés camelCase orphelines) n'est pas lisible depuis les dépôts. Les conclusions de R3/R6 sont dérivées des **chemins d'écriture lus dans le code**, pas d'un échantillon de documents.
- Aucun test n'a été lancé, dans aucun dépôt (consigne).
