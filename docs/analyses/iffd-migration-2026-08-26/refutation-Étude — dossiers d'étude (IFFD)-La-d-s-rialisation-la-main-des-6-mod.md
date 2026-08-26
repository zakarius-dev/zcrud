# Réfutation — « le socle sait déjà (dé)sérialiser les 6 modèles de dossier IFFD »

**Domaine** : Étude — dossiers d'étude (IFFD) : `lib/src/presentation/features/folders/**` (36 f. / 18 333 l),
`features/documents/**` (12 f. / 6 420 l), 6 modèles de dossier (1 310 l), sécurité/ACL (8 f. / 1 582 l),
6 adaptateurs `z_backed_*` (4 648 l).
**Besoin hôte** : (dé)sérialisation à la main des 6 modèles de dossier.
**Affirmation attaquée** : `@ZcrudModel` + `@ZcrudField(persistAs:)` + `@ZcrudId` + `@ZcrudIgnore`
→ `_$XxxFromMap` / `extension XxxZcrud{toMap, copyWith}` / `$XxxFieldSpecs` / `registerXxx` /
`$XxxTimestampFields`. **Gain annoncé : ~639 lignes d'hôte supprimées.**

- Hôte : `/home/zakarius/DEV/iffd` @ `65d1af9` (`feat/migration-zcrud`) — **vérifié**.
- Socle : `/home/zakarius/DEV/zcrud` @ `cc276c154` (v3.21.0) — **vérifié**.

---

## VERDICT : **DÉMENTIE**

Le canal existe, fait ce qu'on lui prête, et est atteignable. **Mais il ne couvre pas le besoin
réel de l'hôte.** Mesuré : **24 des 76 clés persistées (31,6 %) sont impossibles à émettre** par le
générateur, **8 classes sur 8** portent au moins un bloqueur, **0 classe sur 8** est migrable telle
quelle, et **205 des 583 lignes** visées (35 %) sont du `copyWith` que l'extension générée **ne peut
structurellement pas remplacer**. Le gain de 639 lignes est un plafond théorique qu'aucune des
8 classes n'atteint.

---

## 1. Ce qui RÉSISTE (à ne pas rejouer)

Toutes les preuves avancées sont exactes. Vérifiées une par une :

| Preuve citée | État |
|---|---|
| `zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151` | ✅ `class ZcrudModel {` — `kind`, `fieldRename` présents (:157-165) |
| `zcrud_field.dart:52` | ✅ `class ZcrudField {` |
| `zcrud_field.dart:140` | ✅ `final ZPersistAs persistAs;` |
| `zcrud_id.dart:16` | ✅ `class ZcrudId {` |
| `zcrud_ignore.dart:62` | ✅ `class ZcrudIgnore {` |
| `z_persist_as.dart:16-26` | ✅ `enum ZPersistAs { iso8601, timestamp }` |
| `zcrud_model_generator.dart:7-17` | ✅ les 4 émissions documentées |
| Émissions :978 / :1184 / :1208 / :1237 | ✅ `_emitExtension`, `_emitRegister`, `_emitTimestampFields` |
| Échec sur champ non annoté non sérialisable :722-724 | ✅ `_rejectSilentlyLostFields`, `InvalidGenerationSourceError` |

**Contrôle par le code émis, pas par la dartdoc** — `packages/zcrud_document/lib/src/domain/z_annotation_bounds.g.dart`
contient réellement `_$ZAnnotationBoundsFromMap`, `extension ZAnnotationBoundsZcrud` (toMap +
copyWith à sentinelle `_$undefined`), `$ZAnnotationBoundsFieldSpecs`, `registerZAnnotationBounds`,
`$ZAnnotationBoundsTimestampFields`. Le canal n'est pas inerte.

**Atteignabilité** : `packages/zcrud_annotations/lib/zcrud_annotations.dart` exporte les 5 fichiers
(`z_persist_as`, `zcrud_field`, `zcrud_id`, `zcrud_ignore`, `zcrud_model`). ✅

**Le « PIÈGE LU » de l'affirmation est exact** — `zcrud_field.dart:125-140` dit littéralement :
« le code émis écrit une `String` ISO-8601 pour **tout** champ date, quel que soit `persistAs` ».
L'affirmation ne se trompe pas là-dessus. Elle se trompe sur ce que ça coûte (§3.3).

**Préconditions de dépendance** (addables, non bloquantes) :
- `grep -n "zcrud_generator" /home/zakarius/DEV/iffd/pubspec.yaml` → **RC=1** (absent).
- `zcrud_annotations` n'apparaît qu'à la ligne **577**, dans `dependency_overrides` (débute :552),
  **pas** dans `dependencies` (:10-532). Il n'arrive que par la fermeture transitive de
  `zcrud_study_kernel`.
- `build_runner: ^2.15.1` est bien en `dev_dependencies` ✅.
- `grep -rn '@ZcrudModel' lib` → **RC=1** ; `grep -rn 'zcrud_annotations' lib` → **RC=1**.

---

## 2. LE BLOQUEUR STRUCTUREL — `id` est un champ **HÉRITÉ**, et le générateur ne collecte pas l'héritage

C'est le point qui casse **les 8 classes**, sans exception.

### 2.1 Le générateur ne regarde que les champs DÉCLARÉS

`packages/zcrud_generator/lib/src/zcrud_model_generator.dart:465-474` :

```dart
List<_Field> _collectFields(ClassElement element, ZFieldRename rename) {
  final fields = <_Field>[];
  ...
  for (final field in element.fields) {          // ← DÉCLARÉS uniquement
```

Aucune remontée de `supertype`. Le générateur le dit lui-même, :646-649 :

> « Un champ déclaré dans une classe de base **n'est pas collecté par le générateur** »

La seule traversée d'héritage du fichier est `_collectInheritedSilentlyLost` (:663-706), qui
**contrôle** les champs hérités pour refuser le build — elle n'en **sérialise** aucun.

### 2.2 Comment le socle contourne ça chez lui

`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:17-23` :

```dart
abstract class ZEntity {
  const ZEntity();
  String? get id;        // ← un GETTER ABSTRAIT, aucun champ
```

Chaque entité `@ZcrudModel` du socle **re-déclare `id` localement**. Exemple mesuré,
`packages/zcrud_document/lib/src/domain/z_document_annotation.dart:137-140` :

```dart
@override
@ZcrudId()
final String? id;
```

Idem `z_study_document.dart:144`. Le socle a conçu `ZEntity` **sans champ** précisément pour que
chaque sous-classe puisse porter son propre `id` annotable.

### 2.3 IFFD fait l'inverse — grep négatif MONTRÉ

`/home/zakarius/DEV/iffd/lib/src/domain/models/dynamic_model.dart:3-6` :

```dart
abstract class DynamicModel {
  final String? id;          // ← un CHAMP CONCRET, pas un getter
  const DynamicModel({this.id});
```

```
$ grep -n "final String? id" lib/src/domain/models/{folder_model,folder_document,\
folder_document_annotation,folder_invitation,folder_document_reading,\
folder_document_learning_info}.dart
RC=1                                    ← AUCUNE des 6 ne re-déclare `id`
```

```
$ grep -cn "super.id" <les 6 mêmes fichiers>
folder_document.dart:1   folder_model.dart:3   folder_document_reading.dart:1
folder_document_annotation.dart:1   folder_document_learning_info.dart:1
folder_invitation.dart:1            → 8 occurrences, une par classe
```

**Conséquence mesurée** : les 8 classes reçoivent `id` par `super.id`. Le `toMap()` généré
**omettrait `'id'`** pour les 8 — or `'id'` est une clé de leurs 8 `toMap()` actuels
(`folder_model.dart:114`, `:291`, `:384` ; `folder_document_annotation.dart:69` ;
`folder_invitation.dart:39` ; `folder_document_reading.dart:47` ;
`folder_document_learning_info.dart:44` ; `folder_document.dart` via `...super.toMap()`).

Migrer impose donc de **modifier `DynamicModel`** (champ → getter abstrait) et de re-déclarer `id`
dans **toutes** ses sous-classes du dépôt — pas seulement les 6 du domaine. Sinon, la re-déclaration
locale masque le champ de base tout en le laissant vivre (deux emplacements de stockage pour `id`,
avec `DynamicModelExtension.copyWithId` (`dynamic_model.dart:75-79`) qui lit lequel ?).
**Ce n'est pas une passe d'annotation, c'est un refactor de hiérarchie.**

### 2.4 Et ce n'est pas que `id`

`FolderContentModel extends SubjectContentModel` (`subject_model.dart:170-173` : `subjectId`,
`creatorId`, `createdAt`) et `FolderDocument extends FolderContentModel`. Les clés héritées,
non collectables :

| Classe | clés persistées | dont HÉRITÉES (non collectables) |
|---|---|---|
| `FolderContentModel` (folder_model.dart:256) | 6 | **4** — `id`, `subjectId`, `creatorId`, `createdAt` |
| `FolderDocument` (folder_document.dart:71) | 15 | **6** — + `folderId`, `subFolderId` |

`FolderDocument.toMap()` (:106-108) compose par héritage — `{...super.toMap(), ...{…}}` — un motif
que le générateur n'émet nulle part : il émet un `toMap()` **plat** des seuls champs locaux.

---

## 3. Les types que le générateur REFUSE — et que l'hôte persiste

`_classify` (`zcrud_model_generator.dart:534-848`) est la **seule** autorité de sérialisabilité
(le générateur le dit :620-625). Types acceptés, exhaustivement :

`List<T>` (:536), `String` (:820), `int` (:821), `double` (:822), `num` (:823), `bool` (:824),
tout `enum` (:827), `DateTime` (:828), `ZDateRange` (:834), classe `@ZcrudModel` (:838).

**Rien d'autre.** :841-847 → `InvalidGenerationSourceError` : « ni scalaire supporté, ni enum,
ni @ZcrudModel annoté ». **Il n'existe AUCUNE catégorie `Map`.**

### 3.1 `Color` — 2 sites, aucun remède sans perte

- `folder_model.dart:18` `final Color? color;` → persisté `color?.toARGB32().toString()` (**String**, :119),
  décodé avec repli `randomColor()` (:137-139, :152).
- `folder_document_annotation.dart:18` `final Color? color;` → persisté `color?.toARGB32()` (**int**, :75).

`Color` est une classe `dart:ui` : ni scalaire, ni enum, ni annotable `@ZcrudModel` (elle
appartient au SDK). Les trois remèdes du message d'erreur (:733-748) :
1. changer le type → refactor de tout le code d'affichage ;
2. annoter le type → **impossible pour un type du SDK**, le message le dit explicitement :
   « Impossible pour un type du SDK (`Map`, `Set`, fonction…) » ;
3. `@ZcrudIgnore` → **le champ n'est plus persisté**, perte de données.

Non annoté, `_isSilentlyLost` (:632-644) le classe perdu et **le build ROUGIT** (:715-750).
Le socle l'a d'ailleurs reconnu chez lui : `z_annotation_bounds.dart:20-22` — « Les `double` sont
codegen-ables » — et a créé `ZAnnotationBounds` (4 `double`) **parce qu'un `Rect` ne l'est pas**.

### 3.2 Trois autres familles de types refusées

| Champ | fichier:ligne | type | forme persistée | verdict |
|---|---|---|---|---|
| `bounds` | `folder_document_annotation.dart:19` | `Rect?` (dart:ui) | Map imbriquée de 4 doubles (:77-85) | **refusé** — pas de catégorie Map, `Rect` non annotable |
| `textLines` | `folder_document_annotation.dart:23` | `List<PdfTextLine>` | List de Maps imbriquées (:86-99) | **refusé** — `PdfTextLine` appartient à `syncfusion_flutter_pdfviewer`, non annotable |
| `subFlashcardsIds`, `subDocumentsIds`, `subNotesIds`, `subMindmapsIds` | `folder_model.dart:336-339` | `Map<String, List<String>>` ×4 | Maps nues (:386-389) | **refusés** — aucune catégorie `Map` dans `_classify` |

### 3.3 Formats de date : l'hôte en utilise DEUX, le socle en offre UN et demi

Le générateur écrit **toujours** de l'ISO-8601 ; `$XxxTimestampFields` n'est qu'un `Set<String>`
neutre, à passer à `FirebaseZRepositoryImpl.timestampFields`. Grep négatif sur l'hôte :

```
$ grep -rn "FirebaseZRepositoryImpl" lib   → RC=1
$ grep -rn "timestampFields"        lib   → RC=1
```

L'hôte écrit par `lib/src/data/repositories/firebase_crud_repository_impl.dart:18`
(`class FirebaseCrudRepositoryImpl<T extends DynamicModel>`), qui n'a jamais entendu parler de
`$XxxTimestampFields`. Et l'hôte n'a pas **un** format hérité, il en a **deux** :

| Forme sur disque | Sites | Couvert par le socle ? |
|---|---|---|
| `Timestamp` natif | `folder_model.dart:127-130` — `createdAt`, `updatedAt`, `archivedAt`, `sharedAt` | `ZPersistAs.timestamp` — **mais uniquement via `FirebaseZRepositoryImpl`, non utilisé ici** |
| **`int` millisecondes** | `folder_invitation.dart:44-52` (`sentAt`, `acceptedAt`, `rejectedAt`) ; `folder_model.dart:296-298` (`FolderContentModel.createdAt`) | **NON — `ZPersistAs` n'a que `iso8601` et `timestamp`** (`z_persist_as.dart:16-26`) |

Migrer sans toucher au repository ferait écrire des `String` ISO là où le parc contient des
`Timestamp` et des `int` — le générateur lui-même avertit de cette classe d'échec
(`zcrud_field.dart:136-140`). **4 dates deviennent silencieusement illisibles pour l'ancien
décodeur, et 4 autres n'ont même pas de mode.**

### 3.4 Un enum persisté par un membre, pas par `.name`

`folder_document_learning_info.dart:12` : `final FlashcardRepetitionQuality? quality;`
Persisté `quality?.value` (:46) — un **int 1..5** (`flashcard_repetition_info.dart:181-190`,
`fail(1,…) … perfect(5,…)`, `final int value;`), décodé par comparaison sur `.value` (:57-59).

Le générateur encode tout enum par `.name` (:1026-1027 pour `listEnum`, même règle pour `enumType`)
et décode par `_$enumFromName` (comparaison sur `value.name`). **Aucun hook `persistAs`
n'existe pour les enums** — `ZPersistAs` ne concerne que les dates. Le format change de `3` à
`"good"`. Rupture de lecture du parc.

### 3.5 Sémantique de décodage de liste d'enum, modifiée

`folder_model.dart:143-149` : valeur inconnue → **repli `douanesSuperieur`, élément CONSERVÉ**,
puis `.toSet().toList()` (dédoublonnage).
Généré, :892-896 : `.map((e) => _$enumFromName(T.values, e)).whereType<T>().toList()` — valeur
inconnue → **élément SUPPRIMÉ**, aucun dédoublonnage. La liste raccourcit en silence.

### 3.6 Bilan chiffré des clés

| Classe | fichier:ligne | clés persistées | clés IMPOSSIBLES | clés dont le FORMAT change |
|---|---|---|---|---|
| `FolderModel` | folder_model.dart:13 | 19 | 2 (`id`, `color`) | 4 dates + `filieresEtCycles` |
| `FolderContentModel` | folder_model.dart:256 | 6 | 4 (héritées) | `createdAt` (ms) |
| `FolderContentsOrders` | folder_model.dart:332 | 7 | 5 (`id` + 4 Map) | — |
| `FolderDocument` | folder_document.dart:71 | 15 | 6 (héritées) | `createdAt` (ms) |
| `FolderDocumentAnnotation` | folder_document_annotation.dart:12 | 10 | 4 (`id`,`color`,`bounds`,`textLines`) | — |
| `FolderInvitation` | folder_invitation.dart:18 | 8 | 1 (`id`) | 3 dates (ms) |
| `FolderDocumentReading` | folder_document_reading.dart:9 | 6 | 1 (`id`) | — |
| `FolderDocumentLearningInfo` | folder_document_learning_info.dart:8 | 5 | 1 (`id`) | `quality` (int → name) |
| **TOTAL** | | **76** | **24 (31,6 %)** | **~11** |

**Classes sans aucun bloqueur : 0 / 8.**
**Classes dont le seul bloqueur est `id` : 1 / 8** (`FolderDocumentReading`).

---

## 4. Le `copyWith` généré est INATTEIGNABLE — 205 lignes qui ne partent pas

`dynamic_model.dart:8-13` déclare **trois membres abstraits** :

```dart
Map<String, dynamic> toMap();
DynamicModel copyWith({String? id});
List<Object?> get props;
```

Le générateur émet `toMap` et `copyWith` dans une **extension** (`_emitExtension`, :948-985 —
confirmé dans `z_annotation_bounds.g.dart` : `extension ZAnnotationBoundsZcrud on …`).
En Dart, **un membre d'extension n'implémente pas un membre abstrait de superclasse**, et il est
**masqué** par tout membre d'instance de même nom. Deux conséquences :

1. Chaque classe doit **garder un `toMap()` d'instance**. Le socle le prescrit lui-même,
   `zcrud_model_generator.dart:1489` :
   `Map<String, dynamic> toMap() => {...extra, ...${className}Zcrud(this).toMap()};`
   → délégation d'une ligne, acceptable.
2. Chaque classe doit **garder un `copyWith({String? id, …})` d'instance** — la signature abstraite
   l'exige, et la signature générée est incompatible (`Object? x = _$undefined` pour chaque champ,
   au lieu de types nominaux). Un `copyWith` délégant devrait **re-déclarer les 19 paramètres**
   de `FolderModel` : zéro ligne économisée. Et sa sémantique diffère —
   hôte : `x ?? this.x` (null = conserver) ; généré : sentinelle (null explicite = **remettre à
   null**). **256 sites d'appel `.copyWith(` mesurés dans `lib/`** basculeraient de sémantique.

Cas aggravé : `folder_document_learning_info.dart:22-38`, dont le `copyWith` prend `int? quality`
alors que le champ est `FlashcardRepetitionQuality?` — conversion faite dans le corps (:33-35).
La sentinelle générée ne peut pas reproduire ça (`quality as FlashcardRepetitionQuality?`).

Et le `fromMap` ne disparaît pas non plus : le contrat `_requireDomainFromMap` (:202-250) **exige**
une factory de domaine `Xxx.fromMap` déclarée par la classe. Elle se réduit à une ligne — pas à zéro.

---

## 5. Le chiffre de 639 lignes ne se reproduit pas

Mesure des spans `toMap` / `fromMap` / `copyWith` (comptage par accolades, `@override` inclus) :

| Fichier | total | lignes de triplet | dont `copyWith` |
|---|---|---|---|
| `folder_model.dart` | 490 | **248** (annoncé 273) | 83 |
| `folder_document.dart` | 247 | **80** (annoncé 96) | 38 |
| `folder_document_annotation.dart` | 260 | **104** (annoncé 112) | 26 |
| `folder_invitation.dart` | 130 | **69** (annoncé 77) | 22 |
| `folder_document_reading.dart` | 106 | **42** (annoncé 42 ✅) | 18 |
| `folder_document_learning_info.dart` | 83 | **40** (annoncé 39 ≈) | 18 |
| **TOTAL** | 1 316 | **583** (annoncé **639**) | **205** |

- Écart brut : **−56 lignes (−8,8 %)**.
- **205 lignes (35 %) sont du `copyWith`** : irréductible (§4).
- Reste **378 lignes** de `toMap`/`fromMap`, dont il faut **retrancher** les délégations conservées
  (8 `toMap` + 8 `fromMap` ≈ 30 l) **et** les branches manuelles à maintenir pour les
  **24 clés impossibles** (`color`, `bounds`, `textLines`, 4 `Map`, 10 clés héritées…).
- Plafond réaliste : **nettement sous 350 lignes**, et **conditionné** à un refactor de
  `DynamicModel` + à la migration du repository d'écriture.

**Inventaire repo-wide contesté aussi.** L'affirmation annonce « 35 triplets sur 17 fichiers ».
Mesuré sur `/home/zakarius/DEV/iffd/lib` (hors `*.g.dart`) :
`Map<String, dynamic> toMap()` → **64** déclarations sur **53 fichiers** ;
`fromMap(` (factory/static) → **74** ; ` copyWith({` → **59**. Le chiffre avancé sous-estime la
surface d'environ **2×**.

---

## 6. La condition cachée : le socle a déjà répondu, mais AUTREMENT

`packages/zcrud_document/lib/src/domain/` contient déjà `z_study_document`, `z_document_annotation`,
`z_annotation_bounds`, `z_document_reading_state`, `z_document_viewer_prefs` — **les équivalents
exacts** de `FolderDocument`, `FolderDocumentAnnotation`, `FolderDocumentReading`. Et
`ZAnnotationBounds` n'existe que parce que `Rect` n'est pas codegen-able.

⇒ La voie prévue par le socle pour ce domaine est **l'adoption des entités `zcrud_document`**, pas
l'annotation en place des modèles IFFD. L'affirmation attaquée décrit un chemin que le socle
n'emprunte pas lui-même, et qui bute sur les six murs ci-dessus.

---

## 7. Ce qui est vrai à la place

> Le générateur `@ZcrudModel` du socle est réel, complet et exporté, mais il est conçu pour des
> entités **dont l'`id` est déclaré localement** (patron `ZEntity` : getter abstrait) et **dont
> tous les champs persistés sont scalaires, enums, `DateTime`, `ZDateRange` ou `@ZcrudModel`**.
> Les 6 modèles de dossier IFFD ne satisfont **aucune** de ces deux conditions : les 8 classes
> tiennent `id` par `super.id` d'un `DynamicModel` à champ concret, et **24 des 76 clés persistées
> (31,6 %)** portent des types que `_classify` refuse (`Color` ×2, `Rect`, `List<PdfTextLine>`,
> `Map<String,List<String>>` ×4) ou vivent dans une classe de base. Par ailleurs `ZPersistAs`
> n'offre pas le format **`int` millisecondes** qu'IFFD emploie sur 4 dates, ni de hook pour un
> enum persisté par un membre (`FlashcardRepetitionQuality.value`).
> Enfin, `copyWith` étant **abstrait** dans `DynamicModel:11`, l'extension générée est masquée :
> **205 des 583 lignes** visées (35 %) ne peuvent pas partir, et sa sémantique à sentinelle diffère
> de celle de l'hôte sur **256 sites d'appel**.
>
> Gain réellement accessible : **très inférieur à 639 lignes**, et **conditionné** à
> (a) transformer `DynamicModel.id` en getter abstrait puis re-déclarer `id` dans toutes ses
> sous-classes, (b) migrer l'écriture vers `FirebaseZRepositoryImpl` (absent : grep RC=1) pour que
> `$XxxTimestampFields` serve à quelque chose, (c) conserver un canal manuel pour les 24 clés
> refusées. Une seule classe sur huit (`FolderDocumentReading`) n'a d'autre obstacle que `id`.
