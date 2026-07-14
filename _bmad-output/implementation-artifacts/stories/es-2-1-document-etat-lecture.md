# Story ES-2.1 : Document d'étude + état de lecture personnel (`zcrud_document`)

Status: review

- **Clé sprint-status** : `es-2-1-document-etat-lecture`
- **Epic** : ES-2 (Domaine canonique éducatif + codegen)
- **Taille** : **M**
- **Parallélisation** : ✅ **PARALLÉLISABLE** avec `ES-2.2` (`zcrud_note`) et `ES-2.6` (`zcrud_exam`).
  **Packages écrits** : `packages/zcrud_document/` (**NOUVEAU**), `tool/reserved_keys_gate/`, `pubspec.yaml` racine.
  ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_study_kernel`** — c'est la **condition** de la parallélisation (garde-fou n°2 de CLAUDE.md). Si le dev découvre qu'un symbole DOIT remonter au kernel, la story **redevient séquentielle** : il **arrête** et le signale (cf. **D9**).
- **Couvre** : **FR-S4** · AD-3, AD-4, AD-10, AD-17, AD-19 (+19.1/.a/.b/.c), AD-26, AD-27 · NFR-S3, NFR-S4, NFR-S8, NFR-S10 · SM-S5, SM-S6.
- **Dépend de** : **ES-1** (complet) + **ES-2.0** (`done` — le contrat `fromMap` de domaine est **le patron** de cette story).

> ⚠️ **CORRECTION DE PÉRIMÈTRE (vérifiée dans le PRD).** Le périmètre annoncé « FR-S4/FR-S5 » est **faux** : le PRD (`prd-zcrud-study-2026-07-12/prd.md` l. 155-159) mappe **FR-S5 = « Note intelligente à contenu typé » = `ZSmartNote`**, qui est le périmètre d'**ES-2.2** (`zcrud_note`, AD-28). **ES-2.1 couvre FR-S4 SEUL.** Aucune ligne de `ZSmartNote`/`ZCodec` ne doit être écrite ici.

---

## Story

**As a** développeur intégrant zcrud dans une app d'étude (lex_douane, IFFD),
**I want** modéliser un document rattaché à un dossier (`ZStudyDocument`) et son état de lecture **personnel** (`ZDocumentReadingState` / `ZDocumentLearningInfo`) dans un package `zcrud_document` dédié,
**so that** une app puisse persister des documents et leur progression de lecture **sans colocaliser l'état personnel avec le contenu partageable** (AD-26) et **sans qu'aucun horodatage/soft-delete métier ne collisionne avec les clés du store** (AD-19).

---

## ⚠️ LE PATRON ES-2 (établi par ES-2.0) — à respecter DÈS LA NAISSANCE

`zcrud_generator` impose désormais, **PAR MACHINE**, sur toute classe `@ZcrudModel` :

1. **Décodeur de domaine obligatoire** — `Xxx.fromMap(Map<String, dynamic> map)` (factory **ou** méthode statique ; paramètres optionnels supplémentaires autorisés). **Absent ⇒ ÉCHEC DE BUILD** (`_requireDomainFromMap`, `zcrud_model_generator.dart:167`).
2. **Si la classe est `ZExtensible`** (y compris **transitivement**) — sa `fromMap` **ne doit PAS déléguer nuement** à `_$XxxFromMap`. Une délégation nue est détectée **à l'AST du corps** ⇒ **BUILD ROUGE** (`_rejectNakedCodegenDelegation`). Elle doit peupler `extra` : `extra: _extraFrom(map)`.
3. **Garde RUNTIME** (`_$zRequireExtraPreserved`) émis dans le `.g.dart` de toute classe `ZExtensible` : il **décode une sonde et exige que la clé hors-schéma survive au round-trip COMPLET** (`fromMap` **ET** `toMap`). Il n'est **pas** sous `assert` ⇒ il mord **en release**, à l'enregistrement.

⇒ **Les entités de cette story naissent conformes.** Le dev ne « corrige » rien après coup : il écrit directement la forme qui marche.

**Le patron de référence à COPIER, sur disque** :
- `ZExtensible` : `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` — **l'exemplaire d'AD-19.1** (`fromMap` défensive + `_reservedKeys` + `_extraFrom` + `toMap` qui étale `...extra` + `==`/`hashCode` avec `_mapEquals`/`_mapHash`).
- **NON**-`ZExtensible` (value object) : `packages/zcrud_flashcard/lib/src/domain/z_choice.dart` — délégation nue **autorisée** (aucun slot `extra` à détruire).
- **Canal HORS-CODEGEN** (un champ que le générateur ne sait pas traiter) : `ZFlashcard.source` (`z_flashcard.dart` l. 121, 236-238, 332-335) — décodé/réémis **à la main**, sa clé ajoutée à `_reservedKeys`. **C'est le patron de `learning`** (cf. **D4**).

---

## ⚠️ Décisions de conception — CHAQUE prescription est CONFRONTÉE AU CODE RÉEL (R4 / R-G)

> **Leçon R-G de la rétro ES-1** : *« en ES-1.2 et ES-1.4, les défauts venaient de la STORY, pas du dev ; en ES-2.0 la spec figée s'est brisée deux fois sur `ZChoice` »*. Les décisions ci-dessous sont **fermées** — le dev ne les rejoue pas — **mais il DOIT les remettre en cause si le code réel les contredit, et le dire en Completion Notes.**

### D1 — Schéma canonique = **lex**, pas IFFD. Source vérifiée fichier par fichier.

| Entité zcrud | Source canonique (LUE) | Source secondaire (LUE) |
|---|---|---|
| `ZStudyDocument` | `lex_douane/packages/lex_core/lib/domain/entities/education/study_document.dart` | `iffd/lib/src/domain/models/folder_document.dart` |
| `ZDocumentReadingState` + `ZDocumentViewerPrefs` | `lex_douane/.../education/document_reading_state.dart` | `iffd/lib/src/domain/models/folder_document_reading.dart` |
| `ZDocumentLearningInfo` | `lex_douane/.../education/document_learning_info.dart` | `iffd/lib/src/domain/models/folder_document_learning_info.dart` |
| `ZDocumentStatus` | `lex_douane/packages/lex_core/lib/domain/enums/document_status.dart` | `FolderDocumentStatus` (IFFD, **6 états**) |
| `ZDocumentScrollDirection` / `ZDocumentPageLayout` | `lex_douane/.../enums/education/document_viewer_prefs.dart` | *(IFFD : Syncfusion — **rejeté**, cf. D6)* |
| `ZDocPageQuality` | `lex_douane/.../enums/education/doc_page_quality.dart` | `FlashcardRepetitionQuality` (IFFD) |

**Pourquoi lex** : IFFD **importe `cloud_firestore` et `package:flutter/material.dart` (`Color`) dans son modèle de domaine** (`folder_document.dart` l. 3-4) et **Syncfusion dans son état de lecture** (`folder_document_reading.dart` l. 4). C'est exactement ce que **NFR-S3/SM-S5** interdisent. lex est déjà pur-Dart, snake_case, défensif. **Le canonique est lex ; IFFD est un cas de migration (ES-11.2), jamais une source de forme.**

### D2 — 🔴 **R-C EST RÉALISÉ DANS LA SOURCE** : lex porte `updatedAt`/`isDeleted` **inline**. On les SUPPRIME.

Constat de disque, **littéral** :
- `StudyDocument` (lex) : `final DateTime updatedAt;` **+** `@JsonKey(defaultValue: false) final bool isDeleted;` — les **deux** clés réservées, inline.
- `DocumentReadingState` (lex) : `/// Clé LWW (dernière écriture).` `final DateTime updatedAt;` — c'est **littéralement** la clé d'autorité du merge, **dans l'entité**.

⇒ **Un portage verbatim reproduirait EXACTEMENT le défaut qu'AD-19.1.a décrit** : le store écrit la méta **APRÈS** le corps à chaque `put` (`hive_z_local_store.dart` `_encode` ; `firebase_z_repository_impl.dart` `_encode`/`_mergedMap`) ⇒ **écrasement silencieux**, sans erreur ni test rouge.

**RÈGLE, sans exception :**
- ⛔ **AUCUNE** des 3 entités ne déclare `updatedAt` ni `isDeleted` (ni sous ces noms, ni sous les clés `updated_at`/`is_deleted`). L'autorité LWW et le soft-delete vivent **hors-entité** dans `ZSyncMeta` (AD-19).
- ✅ `createdAt` est **conservé** sur `ZStudyDocument` (clé `created_at` — **distincte**, jamais réservée). Précédent sur disque : `ZStudyFolder.archivedAt` (`archived_at`).
- ✅ **Aucune** entrée nouvelle dans `kLegacyUpdatedAtMirrors` : ces entités sont **neuves**, pas des miroirs legacy. Le **test de verrou** du harnais rend toute croissance de cet ensemble **ROUGE** — c'est voulu.

### D3 — 🔴 **Le générateur ne supporte AUCUN type `Map`** ⇒ `ZDocumentLearningInfo` est **écrite à la main**

**Preuve de disque** — `zcrud_model_generator.dart` `_classify` (l. 437-480) accepte **exactement** : `String`, `int`, `double`, `num`, `bool`, `DateTime`, **enum**, sous-modèle `@ZcrudModel`, et `List<` de ces types. **Tout le reste** :

```dart
throw InvalidGenerationSourceError(
  'Type de champ non (dé)sérialisable "${type.getDisplayString()}" sur ${field.name} : '
  'ni scalaire supporté, ni enum, ni @ZcrudModel annoté.', element: field);
```

Il **n'existe aucune branche `isDartCoreMap`**. ⇒ `qualityByPage: Map<int, int>` **NE PEUT PAS** être un `@ZcrudField`. **Annoter `ZDocumentLearningInfo` en `@ZcrudModel` fait ÉCHOUER LE BUILD.**

**Confirmation indépendante** : dans lex, `document_learning_info.dart` est **la seule** des trois entités document **sans `@JsonSerializable`** — elle est écrite à la main, `fromJson`/`toJson` compris. lex a rencontré la même contrainte.

⇒ **`ZDocumentLearningInfo` = value-object PUR écrit à la main** (aucune annotation, aucun `.g.dart`, aucun `kind`).
⇒ **Conséquence gate (à ne PAS sur-appliquer)** : elle n'est **ni `ZExtensible` ni enregistrée** ⇒ elle sort de `E_disk` **et** de `R_disk` ⇒ **AUCUN câblage `manual_probes.dart` n'est requis** pour elle. `manual_probes.dart` est réservé aux entités **hand-written ET `ZExtensible`** (cas `ZMindmap`/`ZMindmapNode`). L'y ajouter serait une erreur.

### D4 — `learning` est un **canal HORS-CODEGEN** de `ZDocumentReadingState` (patron `ZFlashcard.source`)

Corollaire de **D3** : `ZDocumentLearningInfo` n'étant pas `@ZcrudModel`, le générateur **rejette** un champ `final ZDocumentLearningInfo learning;` (catégorie `subModel` exige `_modelChecker.hasAnnotationOf(el)`, l. 471).

⇒ **`learning` n'est PAS un `@ZcrudField`.** Il est câblé **exactement** comme `ZFlashcard.source` :
1. décodé **manuellement** dans `ZDocumentReadingState.fromMap` (défensif, jamais de throw) ;
2. réémis **manuellement** dans `toMap()` ;
3. sa clé `'learning'` est **ajoutée à `_reservedKeys`** (sinon elle atterrirait dans `extra` **et** serait réémise en double → AD-4 violé, `==` cassé entre une instance mémoire et la même relue du store).

### D5 — 🔴 **L'ORDRE DE DÉCLARATION DE L'ENUM EST NORMATIF** (piège écrit nulle part)

**Preuve de disque** — `_fallback` (l. 559) : le repli défensif d'un enum **non-nullable sans `defaultValue`** est **`T.values.first`**, et le décodage est `_$enumFromName(T.values, m)` (par **NOM**, l. 515).

⇒ **La première constante déclarée EST le défaut défensif d'une valeur inconnue/corrompue.** Déclarer `ZDocumentStatus` dans un autre ordre change silencieusement le comportement AD-10.

**Décision** : `enum ZDocumentStatus { uploading, validating, ready, rejected }` — `uploading` **en premier**, donc défaut d'une valeur inconnue.
**Justification du choix de défaut** (les 3 replis possibles ne sont pas équivalents) :
- `ready` ⇒ **mentirait** sur la disponibilité d'un document non prêt (ouverture cassée) ;
- `rejected` ⇒ lex documente cet état comme *« transitoire jamais persisté »*, la carte optimiste étant **purgée** (`discardRejected`) ⇒ **perte de donnée d'affichage** ;
- `uploading` ⇒ affiche « Traitement… », **ne détruit rien, ne ment sur rien**. C'est aussi le défaut de lex (`DocumentStatus.fromJson`).

### D6 — Les enums de préférences de lecture sont **pur-Dart** — jamais Syncfusion (NFR-S3)

IFFD persiste `PdfPageLayoutMode`/`PdfScrollDirection` (**enums Syncfusion**) **dans son modèle de domaine** (`folder_document_reading.dart` l. 4, 18-19). C'est une **violation directe de NFR-S3/SM-S5** (scan CI : zéro `Timestamp`/`Box`/`Color`/`IconData` — et *a fortiori* zéro widget-lib dans un `zcrud_study*`).

⇒ On porte **les enums pur-Dart de lex** : `ZDocumentScrollDirection { vertical, horizontal }` et `ZDocumentPageLayout { continuous, single }` (défauts = **premières constantes**, cf. **D5**). Le mapping vers les enums Syncfusion vit **uniquement en presentation**, côté app — **hors de ce package**.

### D7 — 🔴 La dégradation du statut legacy IFFD est **ÉPINGLÉE PAR UN TEST**, jamais affirmée en prose

`FolderDocumentStatus` (IFFD) a **6** états : `uploading, uploaded, converting, converted, embedding, embedded`. Le canonique en a **4**. Il n'y a **pas** de bijection.

Avec **D5**, un document IFFD réel portant `status: 'embedded'` (donc **prêt**, `readyForChat`) décode sur **`uploading`** ⇒ affiché « Traitement… » **pour toujours**. **C'est une dégradation RÉELLE et CONNUE.**

**Pourquoi ne PAS la corriger ici** : AD-27 est explicite — *« le mapping bidirectionnel snake_case ↔ camelCase (clés historiques IFFD) se fait **uniquement dans le codec `zcrud_firestore`**, jamais dans le domaine »*. Le repli 6→4 états est du **mapping legacy** : il appartient à l'**adapter** (ES-3.5 / ES-11.2), pas à `zcrud_document`.

**Ce que la story EXIGE quand même** (motif central de la rétro : *« un artefact déclaré sûr sur la base de sa prose »*) :
- un **test qui ÉPINGLE le comportement actuel** (`status: 'embedded'` ⇒ `ZDocumentStatus.uploading`), portant en commentaire la dette nommée ;
- une **dette ouverte `DW-ES21-1`** consignée en Completion Notes : *« mapping legacy IFFD 6 états → canonique 4 états, dû dans l'adapter (ES-3.5/ES-11.2) ; jusque-là un document IFFD `converted`/`embedded`/`uploaded` se lit `uploading` »*.
- Le mapping **connu et déterministe** à consigner pour l'adapter : `uploading→uploading` · `converting|embedding→validating` · `uploaded|converted|embedded→ready`.

⚠️ **Interdit** : ajouter les 6 états IFFD au canonique « pour être large ». Le cycle de vie **conversion/embedding IA** est un concern **app-spécifique** (comme `assistantFileId`, `cloudUrl`, `content`, `contentLength`, `type`) : il passe par `extra`/`ZExtension` (**AD-4**), pas par le schéma partagé.

### D8 — `ZDocumentReadingState` **n'est PAS un `ZEntity`** — elle est clé par `docId` (patron `ZRepetitionInfo`)

lex : `DocumentReadingState.docId` (`id == docId`, aucune réconciliation). Le repo a **exactement** ce patron : `ZRepetitionInfo` **n'étend pas `ZEntity`** et est clé par `flashcardId` (jointure 1↔1). ⇒ `ZDocumentReadingState` **n'étend pas `ZEntity`**, clé = `docId`.
`ZStudyDocument`, elle, **étend `ZEntity`** (`@ZcrudId() final String? id;` — reproduire l'annotation de `ZStudyFolder` l. 137-139).

### D9 — **Aucune écriture du kernel** — et ce qu'il faut faire si ce n'est plus vrai (R-F)

Le périmètre d'ES-2.1 ne requiert **aucun** symbole de `zcrud_study_kernel` : le dossier est référencé par `folderId` (clé neutre `String`), exactement comme `zcrud_mindmap` le fait (architecture l. 87).

⇒ **Aucun symbole n'est ajouté au barrel du kernel** ⇒ `z_kernel_surface_guard_test.dart` et la liste `hide` de `zcrud_flashcard` **restent intacts** ⇒ **R-F sans objet** ⇒ **la parallélisation avec ES-2.2/ES-2.6 est préservée**.

**L'arête `zcrud_document → zcrud_study_kernel` est néanmoins DÉCLARÉE** dans le pubspec (AD-17 : les satellites dépendent du kernel), parce que les stories **suivantes du même package** en ont besoin (`ES-2.5` : `colorKey`/`ZColorPalette` ; `ES-3.3` : registre de cascade `folder → document → annotation`, dont `zcrud_document` est le **propriétaire d'arête** — AD-21). Elle ne crée **aucun cycle** (kernel → core uniquement) et n'est vérifiée par aucun gate d'« import inutilisé ».

🔴 **SI** le dev découvre qu'un type DOIT être **ajouté au barrel du kernel** : il **ARRÊTE**, ne l'écrit pas, et le signale — la story deviendrait **séquentielle** vis-à-vis d'ES-2.3/2.4/2.7/2.8 (une seule story écrit le kernel à la fois).

### D10 — Déclaration du package : **root `pubspec.yaml` SEULEMENT** (pas `melos.yaml`)

**Vérifié** : `melos.yaml` déclare `packages: - packages/**` (**glob**) — il n'énumère **aucun** package. Le seul point de déclaration est le bloc `workspace:` du root `pubspec.yaml` (pub workspaces).
⇒ **`melos.yaml` n'est PAS modifié.** Le gate `gate:melos` ne compare que les blocs `scripts:` ⇒ **non impacté**.
⇒ `melos list` passe **15 → 16** automatiquement. Mettre à jour le **commentaire** du root pubspec (« Les 15 packages PRODUIT… ») → **16**. Aucun gate ne compte les packages (vérifié) ; `graph_proof.py` itère `packages/*/pubspec.yaml` ⇒ le nouveau package est pris **automatiquement** (il doit rester **ACYCLIQUE / CORE OUT=0**).

---

## Schéma canonique retenu (clés persistées **snake_case**, enums **camelCase**)

### `ZStudyDocument` — `@ZcrudModel(kind: 'study_document')` · `extends ZEntity with ZExtensible` · **contenu PARTAGEABLE**

| Champ Dart | Type | Clé persistée | Défaut / défensif | Source lex |
|---|---|---|---|---|
| `id` | `String?` | `id` | `null` (éphémère) — `@ZcrudId()` | `id` (== `documentId`) |
| `folderId` | `String` | `folder_id` | `''` | `folderId` |
| `fileName` | `String` | `file_name` | `''` | `fileName` |
| `status` | `ZDocumentStatus` | `status` | `uploading` (**D5**) | `status` |
| `storagePath` | `String` | `storage_path` | `''` | `storagePath` |
| `pageCount` | `int?` | `page_count` | `null` ; **≤ 0 ⇒ `null`** (R-H) | `pageCount?` |
| `sizeBytes` | `int` | `size_bytes` | `0` ; **< 0 ⇒ `0`** (R-H) | `sizeBytes` |
| `createdAt` | `DateTime?` | `created_at` | `null` | `createdAt` |
| `extension` | `ZExtension?` | `extension` | hors-codegen | — |
| `extra` | `Map<String,dynamic>` | *(clés non réservées)* | hors-codegen | — |
| ⛔ ~~`updatedAt`~~ | — | — | **SUPPRIMÉ — AD-19 / D2** | `updatedAt` |
| ⛔ ~~`isDeleted`~~ | — | — | **SUPPRIMÉ — AD-16/AD-19 / D2** | `isDeleted` |

`_reservedKeys = { ...$ZStudyDocumentFieldSpecs.name, 'extension', ...ZSyncMeta.reservedKeys }`

### `ZDocumentViewerPrefs` — `@ZcrudModel(kind: 'document_viewer_prefs')` · **NON-`ZExtensible`** (patron `ZChoice`)

| Champ | Type | Clé | Défaut / défensif |
|---|---|---|---|
| `zoomLevel` | `double` | `zoom_level` | `1.0` ; **non-fini ou ≤ 0 ⇒ `1.0`**, sinon **clamp `[kMinZoom, kMaxZoom]`** (R-H, cf. AC4) |
| `scrollDirection` | `ZDocumentScrollDirection` | `scroll_direction` | `vertical` (1ʳᵉ constante — **D5**) |
| `pageLayout` | `ZDocumentPageLayout` | `page_layout` | `continuous` (1ʳᵉ constante — **D5**) |

`factory ZDocumentViewerPrefs.fromMap(Map<String, dynamic> map)` — **peut** déléguer, mais **doit** sanitiser `zoomLevel` (donc corps non-nu, ce qui est **autorisé** : la délégation nue n'est *interdite* que sur les `ZExtensible`).

### `ZDocPageQuality` — enum **pur domaine**, ⛔ **JAMAIS un `@ZcrudField`**

`toReview(0)` · `mastered(2)` — persisté en **entier** (ordinal extensible, valeur intermédiaire future possible).
🔴 **Le générateur sérialise les enums par NOM** (`_$enumFromName`, l. 515) — il **ne sait pas** persister un enum en `int`. Cet enum ne vit **que** dans la map hand-written `qualityByPage` (valeurs `int`), avec `fromJson(Object?) → ZDocPageQuality` / `toJson() → int` **manuels** (portés de lex). **L'annoter en champ serait un contresens silencieux.**

### `ZDocumentLearningInfo` — **VO écrit à la main** (aucune annotation — **D3**)

- `qualityByPage: Map<int, int>` (défaut `const {}`), **statique `empty`**.
- Persisté **imbriqué** : `{"quality_by_page": {"1": 2, "3": 0}}` — clés **String** (JSON/Firestore valides), valeurs `int`.
- **Invariants R-H** (chacun naît avec son test) : page **1-based ⇒ `page < 1` REJETÉE** ; clé non-parsable **rejetée** ; valeur non-`num` **rejetée** ; map absente/non-map ⇒ **`empty`** — **jamais de throw** (AD-10).
- API portée de lex : `masteredCount`, `qualityOf(page)`, `isMastered(page)`, `mark(page, q)`, `toggle(page)`, `copyWith`.
- `==`/`hashCode` **ordre-indépendants** (lex combine par **somme** commutative — porter **verbatim**, c'est correct et le contrat `==`/`hashCode` en dépend).

### `ZDocumentReadingState` — `@ZcrudModel(kind: 'document_reading_state')` · `with ZExtensible` · **état PERSONNEL** · **PAS un `ZEntity`** (**D8**)

| Champ | Type | Clé | Défaut / défensif |
|---|---|---|---|
| `docId` | `String` | `doc_id` | `''` (clé d'identité, jointure 1↔1) |
| `currentPage` | `int` | `current_page` | `1` ; **1-based ⇒ `< 1` ou corrompu ⇒ `1`** (R-H) |
| `pageCount` | `int?` | `page_count` | `null` ; **≤ 0 ⇒ `null`** (R-H) |
| `prefs` | `ZDocumentViewerPrefs` | `prefs` | `const ZDocumentViewerPrefs()` ; **map corrompue ⇒ défaut** (repli généré : `ZDocumentViewerPrefs.fromMap(const {})`) |
| `learning` | `ZDocumentLearningInfo` | `learning` | ⚠️ **HORS-CODEGEN (D4)** — `ZDocumentLearningInfo.empty` ; jamais de throw |
| `extension` | `ZExtension?` | `extension` | hors-codegen |
| `extra` | `Map<String,dynamic>` | *(non réservées)* | hors-codegen |
| ⛔ ~~`updatedAt`~~ | — | — | **SUPPRIMÉ — c'était LITTÉRALEMENT la clé LWW de lex (D2)** |

`_reservedKeys = { ...$ZDocumentReadingStateFieldSpecs.name, 'extension', 'learning', ...ZSyncMeta.reservedKeys }`

---

## Acceptance Criteria

### AC1 — Package `zcrud_document` créé, déclaré, acyclique

**Given** le monorepo melos à 15 packages
**When** on crée `packages/zcrud_document/`
**Then** son `pubspec.yaml` déclare `resolution: workspace`, `version: 0.1.0`, `publish_to: none` et **exactement** `dependencies: zcrud_core ^0.1.0, zcrud_study_kernel ^0.1.0, zcrud_annotations ^0.1.0` — **aucune dép lourde**, **aucun** gestionnaire d'état, **aucun** `cloud_firestore`, **aucun** SDK Flutter (patron `packages/zcrud_study_kernel/pubspec.yaml`) ; `dev_dependencies: zcrud_generator, build_runner, test`
**And** le package est ajouté au bloc `workspace:` du **root `pubspec.yaml`** (et le commentaire « 15 packages » → **16**) — **`melos.yaml` n'est PAS modifié** (glob `packages/**`, **D10**)
**And** l'API publique est le barrel `lib/zcrud_document.dart`, l'implémentation sous `lib/src/domain/` ; le barrel **masque** les extensions générées des entités `ZExtensible` (`hide ZStudyDocumentZcrud`, `hide ZDocumentReadingStateZcrud` — patron du barrel kernel : leur `copyWith` généré remettrait `extra`/`extension` aux défauts ⇒ **perte silencieuse**), et **n'en masque aucune** pour `ZDocumentViewerPrefs` (patron `ZChoice`, rien à perdre)
**And** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** et `melos list` rend **16**.

### AC2 — `ZStudyDocument` conforme AD-19 dès la naissance, round-trip stable

**Given** la source lex `study_document.dart`
**When** on modélise `ZStudyDocument` selon le tableau canonique
**Then** l'entité est `@ZcrudModel(kind: 'study_document')`, `extends ZEntity with ZExtensible`, et **ne déclare NI `updatedAt` NI `isDeleted`** (D2)
**And** le round-trip `toMap()` → `fromMap()` → `toMap()` est **stable** (idempotent) sur une instance pleine **et** sur une instance minimale
**And** l'entité ne contient **aucun** `Timestamp`/`Color`/`IconData`/type `cloud_firestore` (NFR-S3/SM-S5).

### AC3 — `ZDocumentStatus` défensif, ordre normatif, dégradation IFFD **épinglée**

**Given** un `status` absent, `null`, non-`String`, ou de valeur inconnue
**When** on décode
**Then** on obtient **`ZDocumentStatus.uploading`** (1ʳᵉ constante — **D5**), **jamais** de throw
**And** un test **épingle explicitement** la dégradation legacy IFFD : `status: 'embedded'` ⇒ `uploading`, avec le commentaire nommant la dette **DW-ES21-1** (**D7**)
**And** le mapping cible 6→4 (`uploading→uploading` · `converting|embedding→validating` · `uploaded|converted|embedded→ready`) est **consigné en Completion Notes** comme obligation de l'**adapter** (ES-3.5/ES-11.2), **jamais implémenté dans le domaine** (AD-27).

### AC4 — `ZDocumentViewerPrefs` : value-object non-`ZExtensible` + invariant de zoom gardé

**Given** des préférences persistées
**When** on modélise `ZDocumentViewerPrefs` (`@ZcrudModel(kind: 'document_viewer_prefs')`, **sans** `ZExtensible`, patron `ZChoice`)
**Then** `scrollDirection`/`pageLayout` retombent sur leur **1ʳᵉ constante** (`vertical`/`continuous`) pour toute entrée inconnue
**And** `zoomLevel` est **borné** : une valeur **non finie** (`NaN`/`Infinity`), **≤ 0**, ou non numérique ⇒ **`1.0`** ; toute autre valeur est **clampée** dans `[kMinZoomLevel, kMaxZoomLevel]` — deux **constantes publiques nommées** du package, avec dartdoc justifiant les bornes
> 🔵 **Décision de story (assumée, absente de lex)** : lex **ne borne pas** `zoomLevel` — un `zoom_level: -5` ou `1e9` persisté casse le viewer. **R-H/R1** exige qu'un invariant de valeur naisse avec sa garde. Bornes proposées : `kMinZoomLevel = 0.25`, `kMaxZoomLevel = 10.0` (le dev **peut** les ajuster **s'il les justifie par écrit**) ; le domaine ne garantit qu'une valeur **finie et strictement positive** — les bornes d'IHM réelles restent au viewer (presentation, **hors périmètre**).

### AC5 — `ZDocumentLearningInfo` : VO hand-written, invariants de page gardés

**Given** que le générateur **ne supporte aucun type `Map`** (**D3**, `_classify` l. 474-479)
**When** on modélise `ZDocumentLearningInfo`
**Then** elle est **écrite à la main** — **aucune** annotation `@ZcrudModel`, **aucun** `.g.dart`, **aucun** `kind`
**And** la persistance est `{"quality_by_page": {"<page>": <int>}}` (clés String), le round-trip est stable
**And** la désérialisation est **défensive** : map absente / non-map / clé non-parsable / **page `< 1`** / valeur non-`num` ⇒ **entrée ignorée**, jamais de throw ; cas dégénéré ⇒ `ZDocumentLearningInfo.empty`
**And** `==`/`hashCode` sont **ordre-indépendants** (deux instances égales construites dans des ordres d'insertion différents ont le **même** `hashCode` — test explicite).

### AC6 — `ZDocumentReadingState` : `learning` hors-codegen, zéro clé LWW interne

**Given** la source lex `document_reading_state.dart` (qui porte `updatedAt` comme **clé LWW inline**)
**When** on modélise `ZDocumentReadingState`
**Then** l'entité est `@ZcrudModel(kind: 'document_reading_state') with ZExtensible`, **n'étend PAS `ZEntity`** (clé = `docId`, **D8**), et **ne déclare AUCUN `updatedAt`/`isDeleted`** (**D2**)
**And** `learning` est un **canal HORS-CODEGEN** (patron `ZFlashcard.source`, **D4**) : décodé à la main dans `fromMap`, réémis à la main dans `toMap()`, **et sa clé `'learning'` figure dans `_reservedKeys`**
**And** la désérialisation **imbriquée** est défensive (AD-10/NFR-S4) : `prefs: 42`, `learning: "x"`, `current_page: "abc"`, `page_count: -1`, map **vide** ⇒ **défauts sûrs**, **jamais** de throw ; `currentPage ≥ 1` **toujours**.

### AC7 — Séparation **état personnel / contenu partageable** prouvée par machine (AD-26)

**Given** l'invariant AD-26 (« l'état personnel n'est **jamais** colocalisé dans le sous-arbre partageable »)
**When** on inspecte les schémas générés
**Then** un test **machine** prouve la non-colocation par construction : `$ZStudyDocumentFieldSpecs` ne contient **aucune** des clés d'état de lecture (`current_page`, `prefs`, `learning`, `quality_by_page`, `page_count` **de lecture**) et `ZStudyDocument` **n'imbrique** ni `ZDocumentReadingState` ni `ZDocumentLearningInfo`
**And** la dartdoc de `ZDocumentReadingState` nomme explicitement son statut d'**état personnel** (jamais emporté par le partage — AD-26), la **résolution de collection** restant du ressort de `ZFirestorePathResolver` (**ES-3.2, hors périmètre**).

### AC8 — Conformité au patron ES-2.0, **observée** (pas seulement déclarée)

**Given** le contrat machine du générateur (3 filets)
**When** `melos run generate` s'exécute
**Then** les 3 classes `@ZcrudModel` déclarent chacune un **décodeur de domaine `fromMap`** ; les **deux** `ZExtensible` (`ZStudyDocument`, `ZDocumentReadingState`) **peuplent `extra`** (`extra: _extraFrom(map)`) et **ne délèguent PAS nuement** — le build **passerait ROUGE** sinon
**And** leurs `toMap()` d'instance **étalent `...extra`** (le `toMap()` **généré** ne le fait pas) ⇒ le **garde runtime** `_$zRequireExtraPreserved` (émis dans leur `.g.dart`) **passe à l'enregistrement**
**And** un test prouve le **round-trip `extra`** : une clé hors-schéma (`zz_cle_inconnue`) survit à `registry.decode` **ET** à `registry.encode`.

### AC9 — R-A / R-C : les deux contrôles d'AD-19, **explicitement testés par entité**

**Given** l'oubli de `...ZSyncMeta.reservedKeys` s'est produit **2 fois sur 4** en ES-1.3, **sous 1193 tests verts**
**When** on teste chacune des 3 entités `@ZcrudModel`
**Then** **(R-A)** `_reservedKeys ⊇ ZSyncMeta.reservedKeys` pour les deux `ZExtensible` — prouvé **comportementalement** : une sonde `{...corps, 'updated_at': …, 'is_deleted': true, 'zz_cle_inconnue': 'gardee'}` décodée donne `extra.keys ∩ ZSyncMeta.reservedKeys == {}` **et** `extra['zz_cle_inconnue'] == 'gardee'`, et `toMap()` **ne réémet NI `updated_at` NI `is_deleted`**
**And** **(R-C)** `$XxxFieldSpecs.map((s) => s.name).toSet().intersection(ZSyncMeta.reservedKeys)` est **VIDE** pour **chacune** des 3 entités — assertion écrite **explicitement**, entité par entité (AD-19.1.a ; le gate ne le couvre **pas** directement)
**And** **(AD-19.1.b)** **aucun** `@ZcrudField(persistAs: ZPersistAs.timestamp)` sur une clé réservée (aucun `persistAs: timestamp` n'est requis par cette story).
> *Le groupe de tests est calqué sur « AD-19 — clés de sync hors-entité » de `packages/zcrud_flashcard/test/z_repetition_info_test.dart` — le reproduire, pas le réinventer.*

### AC10 — R-B / R8 : câblage du harnais **dans LA MÊME story** (sinon le gate est vert pour rien)

**Given** qu'une entité non câblée **n'est pas sondée** — le gate serait alors un **faux vert par omission**
**When** on ajoute les 3 nouveaux `kind` (`study_document`, `document_reading_state`, `document_viewer_prefs`)
**Then** `tool/reserved_keys_gate/pubspec.yaml` gagne `zcrud_document: ^0.1.0`
**And** `tool/reserved_keys_gate/lib/src/registrars.dart` est complété : **`kRegistrars`** += `registerZStudyDocument`, `registerZDocumentReadingState`, `registerZDocumentViewerPrefs` ; **`kProbeBodies`** += un **corps minimal valide** par kind (dont une clé `learning` **non vide** pour `document_reading_state`, sans quoi le canal hors-codegen serait affirmé « préservé » **sans qu'aucune machine ne l'observe** — c'est exactement le **finding H2** d'ES-2.0, à ne pas rejouer) ; **`kNonExtensibleKinds`** += `document_viewer_prefs`
**And** **`kLegacyUpdatedAtMirrors` reste INCHANGÉ** (`{study_folder, flashcard}`) — le **test de verrou** l'exige
**And** **aucune** entrée n'est ajoutée à `manual_probes.dart` (**D3** : `ZDocumentLearningInfo` n'est ni `ZExtensible` ni enregistrée ⇒ hors `E_disk`/`R_disk`)
**And** `dart run scripts/ci/gate_reserved_keys.dart` est **VERT** (contrôle de couverture `R_disk \ R_wired` compris).

### AC11 — R-H / AD-10 : chaque invariant de valeur naît **avec sa garde ET son cas corrompu**

**Given** que ces invariants sont, aujourd'hui, de la **prose**
**When** on les implémente
**Then** **chacun** porte (1) un test de **garde** sur la valeur légale et (2) un test de **désérialisation corrompue** prouvant le **défaut sûr, sans throw** :

| Invariant | Garde | Cas corrompu (jamais de throw) |
|---|---|---|
| `currentPage` **1-based ≥ 1** | `1`, `42` conservés | `0`, `-3`, `"abc"`, absent, `null` ⇒ **`1`** |
| `pageCount` **≥ 1 ou `null`** | `12` conservé | `0`, `-1`, `"x"` ⇒ **`null`** |
| `sizeBytes` **≥ 0** | `1024` conservé | `-1`, `"x"` ⇒ **`0`** |
| `zoomLevel` **fini > 0**, clampé | `1.5` conservé | `NaN`, `-5`, `0`, `1e9`, `"x"` ⇒ **`1.0` ou borne** |
| `qualityByPage` pages **1-based** | `{"1": 2}` conservé | `{"0":2}`, `{"-3":2}`, `{"abc":2}`, `{"1":"x"}`, `"pas une map"` ⇒ **entrée ignorée / `empty`** |
| enums (3) | valeur connue conservée | valeur inconnue / `null` / non-`String` ⇒ **1ʳᵉ constante** |

**And** `Xxx.fromMap(const <String, dynamic>{})` **ne throw pour aucune** des 3 entités (map vide).

### AC12 — R3 : **injection de régression** — le filet est vu ROUGIR (aucun gate n'est `done` sans ça)

**Given** *« un filet qu'on n'a pas vu échouer n'est pas un filet »* (rétro ES-1, §7)
**When** on retire `...ZSyncMeta.reservedKeys` de `_reservedKeys` d'**UNE** des deux nouvelles entités `ZExtensible`
**Then** `dart run scripts/ci/gate_reserved_keys.dart` passe **ROUGE** — la **sortie brute est collée** dans les Completion Notes
**And** on restaure **à l'octet près** (`git diff` **vide**) et le gate repasse **VERT**
**And** l'orchestrateur **rejoue lui-même** la séquence (le rapport de l'agent ne vaut **pas** preuve — R9).

### AC13 — R9 : vérif verte **repo-wide**, codegen **committé**

**Given** les gates de merge
**When** on clôt la story
**Then** `melos run generate` OK · `melos run analyze` **repo-wide** RC=0 · `melos run test` RC=0 (aucune régression : nb de tests ≥ avant) · `melos run verify` RC=0 (dont `gate:graph`, `gate:codegen`, **`gate:codegen-distribution`**, `gate:reserved-keys`)
**And** les `*.g.dart` de `packages/zcrud_document/lib/` sont **suivis par git** (le `.gitignore` porte déjà `!packages/*/lib/**/*.g.dart`) et **présents dans l'arbre** — `gate:codegen-distribution` échouerait sinon (un consommateur en dépendance git obtiendrait un `part` manquant).

### AC14 — Périmètre : **aucune** écriture hors du package (parallélisation préservée)

**Given** les garde-fous de parallélisation (CLAUDE.md)
**When** on inspecte le diff
**Then** les **seuls** fichiers modifiés hors `packages/zcrud_document/` sont : root `pubspec.yaml` (bloc `workspace:` + commentaire), `tool/reserved_keys_gate/pubspec.yaml`, `tool/reserved_keys_gate/lib/src/registrars.dart`
**And** **AUCUNE** ligne de `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_firestore` n'est modifiée
**And** **aucun** fichier de `/home/zakarius/DEV/lex_douane` ni `/home/zakarius/DEV/iffd` n'est touché (lecture seule)
**And** **aucune** ligne de `ZSmartNote`/`ZCodec` (FR-S5 = **ES-2.2**) ni de `ZDocumentAnnotation` (**ES-2.5**) n'est écrite.

---

## Tasks / Subtasks

- [x] **T1 — Squelette du package** (AC1, AC14)
  - [x] `packages/zcrud_document/pubspec.yaml` (calquer `zcrud_study_kernel/pubspec.yaml` : `resolution: workspace`, deps core+kernel+annotations, dev generator/build_runner/test ; **zéro Flutter**)
  - [x] Root `pubspec.yaml` : ajouter `- packages/zcrud_document` au bloc `workspace:` ; commentaire « 15 » → « 16 »
  - [x] `lib/zcrud_document.dart` (barrel, `hide` des extensions générées des `ZExtensible`) ; `lib/src/domain/`
  - [x] `dart pub get` puis `python3 scripts/dev/graph_proof.py` (ACYCLIQUE / CORE OUT=0) ; `melos list` = 16
- [x] **T2 — Enums pur-Dart** (AC3, AC4, AC5, AC11 — **D5** : l'ordre est normatif)
  - [x] `z_document_status.dart` : `ZDocumentStatus { uploading, validating, ready, rejected }`
  - [x] `z_document_viewer_prefs.dart` (enums) : `ZDocumentScrollDirection { vertical, horizontal }`, `ZDocumentPageLayout { continuous, single }`
  - [x] `z_doc_page_quality.dart` : `ZDocPageQuality { toReview(0), mastered(2) }` + `fromJson(Object?)`/`toJson() → int` **manuels** (⛔ jamais un `@ZcrudField`)
- [x] **T3 — `ZDocumentViewerPrefs`** (AC4, AC11) — `@ZcrudModel`, **non-`ZExtensible`** (patron `ZChoice`) ; `fromMap` sanitise `zoomLevel` ; constantes `kMinZoomLevel`/`kMaxZoomLevel` documentées
- [x] **T4 — `ZDocumentLearningInfo`** (AC5, AC11) — VO **hand-written** (aucune annotation) ; `fromJson`/`toJson` défensifs ; pages **1-based** ; `==`/`hashCode` **commutatifs** ; API portée de lex
- [x] **T5 — `ZStudyDocument`** (AC2, AC8, AC9) — `@ZcrudModel` + `ZEntity` + `ZExtensible` ; patron `ZRepetitionInfo` **intégral** (`fromMap` défensive → `extra: _extraFrom(map)`, `_reservedKeys` **avec** `...ZSyncMeta.reservedKeys`, `toMap()` qui étale `...extra`, `==`/`hashCode`) ; **zéro `updatedAt`/`isDeleted`**
- [x] **T6 — `ZDocumentReadingState`** (AC6, AC8, AC9) — `@ZcrudModel` + `ZExtensible`, **sans `ZEntity`** ; `learning` en **canal hors-codegen** (patron `ZFlashcard.source`) ; `'learning'` **dans `_reservedKeys`** ; **zéro `updatedAt`**
- [x] **T7 — Codegen** — `melos run generate` ; **committer** les `*.g.dart` de `packages/zcrud_document/lib/` (AC13)
- [x] **T8 — Câblage du harnais du gate (R8 — MÊME story)** (AC10)
  - [x] `tool/reserved_keys_gate/pubspec.yaml` : `zcrud_document: ^0.1.0`
  - [x] `registrars.dart` : `kRegistrars` (+3), `kProbeBodies` (+3, dont `learning` **non vide**), `kNonExtensibleKinds` (+`document_viewer_prefs`) ; `kLegacyUpdatedAtMirrors` **INCHANGÉ**
  - [x] ⛔ **Ne PAS** toucher `manual_probes.dart`
- [x] **T9 — Tests** (AC2..AC11) — `packages/zcrud_document/test/` (pur Dart, `dart test`) : round-trips ; groupe **« AD-19 — clés de sync hors-entité »** par entité (copier celui de `z_repetition_info_test.dart`) ; `$FieldSpecs ∩ reservedKeys == {}` × 3 ; matrice **AC11** complète ; test AD-26 (**AC7**) ; test **DW-ES21-1** (`'embedded'` ⇒ `uploading`)
- [x] **T10 — Injection de régression (R3)** (AC12) — retirer `...ZSyncMeta.reservedKeys` ⇒ **ROUGE** (coller la sortie brute) ⇒ restaurer (`git diff` vide) ⇒ **VERT**
- [x] **T11 — Vérif verte repo-wide** (AC13) — `generate` → `analyze` → `test` → `verify`
- [x] **T12 — Completion Notes** — dette **DW-ES21-1** (mapping statut IFFD 6→4, dû ES-3.5/ES-11.2) ; justification des bornes de zoom ; toute décision D remise en cause

---

## Dev Notes

### Fichiers à LIRE avant d'écrire une ligne (patrons à copier, pas à réinventer)

| Fichier | Pourquoi |
|---|---|
| `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` | **Patron intégral** d'une entité `ZExtensible` conforme AD-19.1 (**l'exemplaire de référence**) |
| `packages/zcrud_flashcard/lib/src/domain/z_choice.dart` | Patron d'un sous-modèle **non-`ZExtensible`** (délégation nue autorisée) |
| `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` (l. 121, 236-238, 332-335) | Patron du **canal hors-codegen** (`source`) ⇒ **c'est `learning`** |
| `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` (l. 137-139) | Annotation `@ZcrudId()` sur `id` ; `archivedAt` = précédent d'horodatage métier à **clé distincte** |
| `packages/zcrud_flashcard/test/z_repetition_info_test.dart` | Groupe de tests **« AD-19 — clés de sync hors-entité »** à reproduire |
| `packages/zcrud_study_kernel/pubspec.yaml` + `lib/zcrud_study_kernel.dart` | Patron de pubspec + barrel (politique de `hide`) |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | Contrat d'extension du gate (**2 lignes/entité**) |
| `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart` | **Le contrat `fromMap` de domaine**, en dartdoc |

### Imports (vérifiés sur disque — ne pas improviser)

- Entités `ZExtensible` (besoin de `ZExtensible`, `ZExtension`, `ZSyncMeta`, `ZEntity`, `ZcrudRegistry`, `ZFieldSpec`) : `import 'package:zcrud_core/domain.dart';` (surface **pur-Dart** — patron `z_repetition_info.dart`).
- Value-object simple : `import 'package:zcrud_core/edition.dart';` suffit (patron `z_choice.dart`).
- ⛔ **Jamais** le barrel principal `package:zcrud_core/zcrud_core.dart` (il tire Flutter et casserait `dart test`).

### Pièges spécifiques à cette story

1. 🔴 **Le portage verbatim de lex EST le bug** : `updatedAt` + `isDeleted` sont **dans** les entités lex. Les recopier = **R-C réalisé** (perte de valeur métier à chaque `put`).
2. 🔴 **`Map<int,int>` ne compile pas en `@ZcrudField`** — build rouge, message « Type de champ non (dé)sérialisable ». C'est **prévu** (D3), pas un accident à contourner.
3. 🔴 **L'ordre des constantes d'enum change le comportement défensif** (D5). Aucune doc ne le dit — seul `_fallback` (l. 559) le dit.
4. 🔴 **Un `kProbeBodies` sans clé `learning`** rendrait le canal hors-codegen « préservé » **par prose** — c'est le finding **H2** d'ES-2.0, tel quel.
5. 🟡 Le `toMap()` **généré** n'étale **pas** `extra` — l'entité **doit** définir son `toMap()` d'instance (il gagne sur l'extension). Idem `copyWith` à sentinelle si exposé.
6. 🟡 `ZDocumentReadingState.pageCount` (lecture, **autorité** consolidée au chargement réel du PDF) et `ZStudyDocument.pageCount` (ingestion, best-effort) sont **deux champs distincts, volontairement dupliqués** — c'est le design lex, à conserver ; le documenter en dartdoc pour qu'une revue ne le prenne pas pour une redondance à supprimer.

### Ce que cette story ne fait PAS (frontières explicites)

- ⛔ `ZDocumentAnnotation`/`ZAnnotationBounds` → **ES-2.5** (même package, story suivante).
- ⛔ `ZSmartNote`/`ZCodec` (**FR-S5**) → **ES-2.2** (`zcrud_note`).
- ⛔ Chemins/collections, `ZStudyRepository`, offline-first, cascade → **ES-3** (`ZFirestorePathResolver`, AD-20/AD-21).
- ⛔ Mapping legacy IFFD (casse + statuts 6→4 + repliage `learning` 1 ligne/page → map) → **adapter**, ES-3.5/ES-11.2 (AD-27).
- ⛔ UI viewer / annotations (WCAG) → **ES-8.2**.
- ⛔ `ZDocumentUploadPipeline` (storage) → seam fourni par l'app (AD-12/AD-26).

### Divergences IFFD consignées pour ES-11.2 (à ne PAS traiter ici)

| Aspect | IFFD | Canonique (lex) | Chantier |
|---|---|---|---|
| Statuts | 6 (`uploading…embedded`) | 4 (`uploading…rejected`) | Mapping **adapter** — **DW-ES21-1** |
| Learning | **1 ligne par page** (`documentId`+`documentPage`+`quality`) | **map colocalisée** `qualityByPage` | Repliage **adapter** (ES-11.2) |
| Prefs | enums **Syncfusion** dans le domaine | enums **pur-Dart** | Rejeté (NFR-S3) — mapping en presentation |
| Casse | camelCase, top-level plat | snake_case, nested | **AD-27**, codec `zcrud_firestore` |
| Champs IFFD sans équivalent | `type`, `content`, `contentLength`, `cloudUrl`, `assistantFileId`, `subjectId`, `subFolderId`, `creatorId` | — | **`extra`/`ZExtension`** (AD-4) — **jamais** au schéma partagé |

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-2.1`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md#FR-S4`] · [NFR-S3, NFR-S4, NFR-S8, NFR-S10 / SM-S5, SM-S6]
- [Source: `.../architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-17, AD-19, AD-19.1, AD-19.1.a, AD-19.1.b, AD-19.1.c, AD-26, AD-27`]
- [Source: `.../architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1, AD-3, AD-4, AD-5, AD-10, AD-16`]
- [Source: `_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md#§3 R1..R9, §6 R-A..R-H`]
- [Source: `_bmad-output/implementation-artifacts/stories/es-2-0-registry-decode-preserve-extra.md`] + [`code-review-es-2-0.md#H1, H2`]
- [Source: `docs/study-integration-inventory.md` l. 96, 106-108, 316]
- [Source (READ-ONLY)] `lex_douane/packages/lex_core/lib/domain/entities/education/{study_document,document_reading_state,document_learning_info}.dart` ; `.../enums/{document_status,education/document_viewer_prefs,education/doc_page_quality}.dart`
- [Source (READ-ONLY)] `iffd/lib/src/domain/models/{folder_document,folder_document_reading,folder_document_learning_info}.dart`

---

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8` — skill BMAD **`bmad-dev-story` réellement invoqué** via le tool `Skill` (aucun fallback disque).

### Debug Log References

- **Injection R3 n° 1** (`...ZSyncMeta.reservedKeys` retiré de `ZDocumentReadingState._reservedKeys`) : `gate:reserved-keys` **RC=1**, **2 violations** (volet **B** syntaxique/AST **et** volet **A** comportemental) + **4 tests de package** rouges.
- **Injection R3 n° 2** (`kLearningKey` retiré de `_reservedKeys`) : le **gate reste VERT** (il n'observe pas le canal hors-codegen) — **4 tests de package** rouges, dont l'anti-H2. *C'est la démonstration que le câblage du harnais ne suffit pas et que le filet de package est nécessaire.*
- **Injection R3 n° 3** (`...extra` retiré de `ZStudyDocument.toMap()`) : le **garde runtime** `_$zRequireExtraPreserved` (ES-2.0) **lève** un `StateError` DW-ES14-1 **à l'enregistrement**.
- Codegen : les **3** registrars émettent `fromMap: ZXxx.fromMap` (domaine) ; le **garde runtime** est émis pour les **2** `ZExtensible` **et pas** pour `document_viewer_prefs`.

### Completion Notes List

#### 1. AC12 / R3 — INJECTIONS DE RÉGRESSION, sorties BRUTES

**(1a) ROUGE** — `...ZSyncMeta.reservedKeys` retiré de `ZDocumentReadingState._reservedKeys` :

```
$ dart run scripts/ci/gate_reserved_keys.dart
[gate:reserved-keys] ÉCHEC : ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1)
  — fichier: packages/zcrud_document/lib/src/domain/z_document_reading_state.dart
00:00 +13 -1: … document_reading_state : sonde polluée → decode/encode REGISTRE propres (a→e) [E]
  Expected: empty
    Actual: Set:['updated_at', 'is_deleted']
  [document_reading_state] (a) AD-19.1 VIOLÉ : les clés réservées {updated_at, is_deleted}
  ont été capturées dans `extra`.
00:00 +42 -1: Some tests failed.
[gate:reserved-keys] 2 violation(s) — AD-19.1.
RC INJECTION 1 = 1
```
`dart test` (zcrud_document) : `00:00 +108 -4: Some tests failed.` (groupe **AD-19** de `z_document_reading_state_test.dart`).

**(1b) RESTAURATION à l'octet près** : `diff -q` → `RESTAURATION À L'OCTET PRÈS ✅` ; `git status --short` sur le fichier → **vide**.

**(1c) VERT** : `[gate:reserved-keys] OK — volet (A) + volet (B) + couverture (AD-19.1.c).` **RC=0** ; `dart test` → `+112: All tests passed!`.

---

**Injection n° 2 — 🔴 LE RÉSULTAT LE PLUS IMPORTANT DE LA STORY (anti-H2)** : `kLearningKey` retiré de `_reservedKeys` :

```
$ dart run scripts/ci/gate_reserved_keys.dart
[gate:reserved-keys] OK — clés de sync réservées : volet (A) + volet (B) + couverture (AD-19.1.c).
GATE RC=0                       ⛔ LE GATE RESTE VERT

$ dart test   (packages/zcrud_document)
  test/ad_26_registry_test.dart: anti-H2 — canal `learning` : round-trip REGISTRE OBSERVÉ
    `learning` survit à `registry.decode` → `registry.encode`          ⛔ ROUGE
  test/z_document_reading_state_test.dart 50/65/115 …                  ⛔ ROUGE (== et idempotence)
00:00 +108 -4: Some tests failed.
```
**Ce que ça prouve** : **aucune** des assertions (a)…(e) du gate ne regarde `learning`. Le câblage de `kProbeBodies` (AC10) place la clé dans la sonde, mais **rien dans le harnais ne l'observe** — c'est *exactement* le finding **H2** d'ES-2.0. Le seul filet qui mord est le test de package `anti-H2` (`ad_26_registry_test.dart`), **écrit pour ça**. Restauré à l'octet ⇒ `+112: All tests passed!`.

---

**Injection n° 3 (bonus, AC8)** — `...extra` retiré de `ZStudyDocument.toMap()` :
```
Bad state: zcrud/DW-ES14-1 (AD-4) : `ZStudyDocument.fromMap` préserve bien `extra`, mais
`ZStudyDocument.toMap()` NE LE RÉÉMET PAS — la clé hors-schéma est DÉTRUITE à l'ENCODAGE.
  → dès `registerZStudyDocument(r)` (garde runtime, PAS sous `assert`)
```
⇒ le garde machine d'ES-2.0 **mord réellement** sur les entités neuves. Restauré à l'octet ⇒ vert.

#### 2. DETTE OUVERTE — **DW-ES21-1** (obligation de l'ADAPTER, jamais du domaine)

> **DW-ES21-1** — *mapping legacy IFFD **6 états → 4 canoniques**, dû dans l'**adapter** `zcrud_firestore` (**ES-3.5 / ES-11.2**, AD-27). Jusque-là, un document IFFD `uploaded`/`converting`/`converted`/`embedding`/`embedded` **se lit `uploading`** — donc affiché « Traitement… » **pour toujours**, y compris quand il est réellement **PRÊT**.*

**Mapping cible à implémenter dans le codec** (déterministe, connu) :
`uploading → uploading` · `converting | embedding → validating` · `uploaded | converted | embedded → ready`.

La dégradation **n'est pas affirmée en prose** : elle est **ÉPINGLÉE PAR 8 TESTS** (`z_document_status_test.dart`, groupe *« DW-ES21-1 »*), dont le cas emblématique `status: 'embedded'` ⇒ `uploading`. ⛔ Élargir le canonique aux 6 états IFFD est **interdit** (le cycle conversion/embedding IA est app-spécifique ⇒ `extra`/`ZExtension`, AD-4) — un test verrouille `ZDocumentStatus.values.length == 4`.

#### 3. Justification des bornes de zoom (AC4 — décision assumée, absente de lex)

`kMinZoomLevel = 0.25` · `kMaxZoomLevel = 10.0` · `kDefaultZoomLevel = 1.0` — **retenues telles que proposées**.
- Le **domaine** ne garantit qu'une valeur **finie et strictement positive** ; les bornes d'**IHM réelles** restent au viewer (presentation, hors périmètre).
- `0.25` (dézoom ×4) : plancher au-delà duquel une page A4 devient illisible sur tout écran (~4 pages par hauteur d'écran) — ordre de grandeur du plancher des viewers PDF courants.
- `10.0` (×10) : couvre la lecture d'un scan de mauvaise qualité, tout en écartant les valeurs manifestement corrompues (`1e9`, qui ferait exploser la mémoire de rendu).
- **Trou refermé au-delà de la lettre de l'AC** : la sanitisation ne pouvait pas vivre **uniquement** dans `fromMap` — le `copyWith` **généré** (non masqué, puisque `ZDocumentViewerPrefs` n'est pas `hide` du barrel) aurait accepté `zoomLevel: -5` **sans broncher**, rouvrant l'invariant que `fromMap` ferme. J'ai donc déclaré un **`copyWith` d'INSTANCE** (qui *masque* celui de l'extension) et une `sanitizeZoomLevel` **publique** : l'invariant tient aux **deux** frontières (désérialisation **et** mutation applicative). Testé.

#### 4. Points où j'ai dû REMETTRE LA STORY EN CAUSE (R-G)

1. **AC4 — la garde de zoom prescrite était INCOMPLÈTE** (cf. § 3). La story ne borne le zoom que dans `fromMap`. Sur disque, `ZDocumentViewerPrefs` n'étant **pas** `hide` du barrel (AC1, à raison), son `copyWith` **généré** est **public** et **contourne** la garde. Corrigé par un `copyWith` d'instance sanitisant — **sans** contredire AC1 (rien n'est masqué).
2. **AC10 — « `learning` non vide dans `kProbeBodies` » NE SUFFIT PAS à écarter H2.** La story exige la clé dans la sonde *« sinon on rejoue le finding H2 »*. **Mesuré (injection n° 2) : le gate reste VERT même sans `kLearningKey` dans `_reservedKeys`.** Aucune assertion (a)…(e) ne regarde ce canal — la sonde le **transporte** sans que rien ne l'**observe**. La prescription littérale de la story aurait donc reproduit H2 *sous une sonde conforme*. J'ai ajouté le filet manquant **là où AC14 l'autorise** (`packages/zcrud_document/test/ad_26_registry_test.dart`, groupe *« anti-H2 »*), et **prouvé qu'il mord**.
3. **`prove_gates` reste à 37 OK / 0 FAIL — c'est CORRECT, pas une régression.** La consigne « doit augmenter » ne s'applique pas : **R2** dit *« un gate à N règles exige N fixtures »*, et ES-2.1 **n'ajoute aucune règle de gate** (elle câble des entités dans un gate existant). Les 3 règles de couverture ont **déjà** leurs fixtures isolées depuis ES-1.4 (`fixture-registrar-non-cable` = `R_disk \ R_wired`, `fixture-cablage-mort`, `couverture-forme-1..5`). Ajouter une fixture pour une règle inexistante serait un **artefact décoratif jamais vu supprimer quoi que ce soit** — la faute exacte que la rétro condamne (et que D5 d'ES-2.0 a déjà refusé de commettre). Le pouvoir discriminant du gate sur les 3 nouvelles entités est prouvé par l'**injection réelle** (§ 1), pas par une fixture de plus.
4. **D9 — RIEN n'a dû remonter au kernel.** Confirmé : aucun symbole de `zcrud_study_kernel` n'est consommé (le dossier est référencé par `folderId: String`), son barrel est **intact**, `z_kernel_surface_guard_test.dart` et le `hide` de `zcrud_flashcard` sont **inchangés** ⇒ **R-F sans objet**, parallélisation avec ES-2.2/ES-2.6 **préservée**. L'arête `zcrud_document → zcrud_study_kernel` est néanmoins **déclarée** (AD-17 ; consommée par ES-2.5/ES-3.3) et ne crée **aucun cycle**.

#### 5. Conformité D1..D10 (toutes tenues)

- **D1** ✅ canonique **lex** (IFFD rejeté : `cloud_firestore` + `Color` + Syncfusion dans son domaine).
- **D2** ✅ **zéro `updatedAt`/`isDeleted`** dans les 3 entités — `$XxxFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` **testé entité par entité** ; `createdAt` conservé (clé distincte) ; `kLegacyUpdatedAtMirrors` **INCHANGÉ** (`{study_folder, flashcard}`, test de verrou vert).
- **D3** ✅ `ZDocumentLearningInfo` **hand-written** (aucune annotation, aucun `.g.dart`, aucun `kind`) ; **aucune** entrée `manual_probes.dart` (ni `ZExtensible` ni enregistrée ⇒ hors `E_disk`/`R_disk` — gate vert, couverture confirmée).
- **D4** ✅ `learning` = canal **hors-codegen** (patron `ZFlashcard.source`), clé dans `_reservedKeys`, décodé/réémis à la main, **round-trip OBSERVÉ** (§ 4 pt. 2).
- **D5** ✅ ordre des enums **normatif** — 3 tests de verrou (`values.first` + liste ordonnée).
- **D6** ✅ enums de prefs **pur-Dart** ; **zéro** Syncfusion.
- **D7** ✅ dégradation IFFD **épinglée par test** (8 tests), **jamais** implémentée dans le domaine ; **DW-ES21-1** consignée (§ 2).
- **D8** ✅ `ZDocumentReadingState` **n'est pas** un `ZEntity` (testé) — clé `docId`.
- **D9** ✅ **aucune** écriture du kernel ni du cœur (§ 4 pt. 4).
- **D10** ✅ **root `pubspec.yaml` seulement** ; `melos.yaml` **non modifié** ; `gate:melos` vert (16 scripts) ; `melos list` **15 → 16**.

#### 6. Vérif verte (rejouée, RC réels)

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **SUCCESS** |
| `dart run melos run analyze` (repo-wide) | **RC=0** |
| `dart run melos run verify` (repo-wide, avant-plan) | **RC=0** (10 gates) |
| `dart run scripts/ci/prove_gates.dart` | **37 OK / 0 FAIL** (= baseline ; aucune règle de gate ajoutée — cf. § 4 pt. 3) |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** (**16** nœuds) |
| `dart run melos list` | **16** packages |
| `gate:codegen-distribution` | **16 packages, 3 avec `part`** (`zcrud_document` inclus), **0 gitignoré** |
| `gate:reserved-keys` | **8 registrars sur disque, 8 câblés** (`R_disk \ R_wired = ∅`) |
| `gate:web` | `zcrud_document` **inclus** et vert sous `dart test -p node` (déterminisme JS) |

**Compteurs de tests (avant → après)** : `zcrud_document` **— → 112** (nouveau) · harnais `reserved_keys_gate` **35 → 43** · `zcrud_generator` **102 = 102** · `zcrud_flashcard` **189 = 189** · `zcrud_study_kernel` **108 = 108** · `zcrud_core` **911 = 911** · `zcrud_firestore` **90 = 90** · `zcrud_mindmap` **110 = 110** — **zéro régression**.

**AC14 (périmètre)** : **aucune** ligne de `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_firestore` modifiée par cette story (les `M` visibles sur ces packages et sur `assertions.dart`/`reserved_keys_test.dart` **préexistent** — ce sont ceux d'**ES-2.0**, en vol). **Aucun** fichier de `/home/zakarius/DEV/lex_douane` ni `/home/zakarius/DEV/iffd` touché (lecture seule). **Aucune** ligne de `ZSmartNote`/`ZCodec`/`ZDocumentAnnotation`. **Rien n'a été committé**, `sprint-status.yaml` **non modifié**.

### File List

**Nouveaux — `packages/zcrud_document/`** (16ᵉ package)
- `pubspec.yaml` — deps `zcrud_core` + `zcrud_study_kernel` + `zcrud_annotations` ; **zéro** Flutter / dép lourde / `cloud_firestore`
- `lib/zcrud_document.dart` — barrel (`hide ZStudyDocumentZcrud`, `hide ZDocumentReadingStateZcrud` ; **rien** de masqué pour `ZDocumentViewerPrefs`)
- `lib/src/domain/z_document_status.dart` — enum **4 états**, ordre **normatif** (D5)
- `lib/src/domain/z_doc_page_quality.dart` — enum persisté en **`int`** (⛔ jamais un `@ZcrudField`)
- `lib/src/domain/z_document_viewer_prefs.dart` — enums pur-Dart + `@ZcrudModel` **non-`ZExtensible`** ; `kMin/kMax/kDefaultZoomLevel` + `sanitizeZoomLevel` + `copyWith` d'instance sanitisant
- `lib/src/domain/z_document_learning_info.dart` — **VO hand-written** (D3) ; `fromJson`/`fromJsonSafe`/`toJson` défensifs ; pages **1-based** ; `==`/`hashCode` **commutatifs**
- `lib/src/domain/z_study_document.dart` — `@ZcrudModel` + `ZEntity` + `ZExtensible` ; **zéro `updatedAt`/`isDeleted`** (D2)
- `lib/src/domain/z_document_reading_state.dart` — `@ZcrudModel` + `ZExtensible`, **sans `ZEntity`** (D8) ; `learning` **hors-codegen** (D4) ; **zéro clé LWW interne**
- **Générés (SUIVIS par git — `gate:codegen-distribution`)** : `z_study_document.g.dart`, `z_document_reading_state.g.dart`, `z_document_viewer_prefs.g.dart`
- **Tests (112)** : `z_document_status_test.dart` (AC3 + **DW-ES21-1**), `z_document_viewer_prefs_test.dart` (AC4/AC11), `z_document_learning_info_test.dart` (AC5/AC11), `z_study_document_test.dart` (AC2/AC9/AC11), `z_document_reading_state_test.dart` (AC6/AC9/AC11), `ad_26_registry_test.dart` (**AC7 AD-26** + **AC8** voie registre + **anti-H2 `learning`**)

**Modifiés (les 3 SEULS fichiers hors du package — AC14)**
- `pubspec.yaml` (root) — `packages/zcrud_document` au bloc `workspace:` + commentaire « 15 » → « 16 » (**`melos.yaml` NON modifié** — D10)
- `tool/reserved_keys_gate/pubspec.yaml` — `zcrud_document: ^0.1.0`
- `tool/reserved_keys_gate/lib/src/registrars.dart` — `kRegistrars` **+3** · `kProbeBodies` **+3** (dont `learning` **NON VIDE**) · `kNonExtensibleKinds` **+`document_viewer_prefs`** · `kLegacyUpdatedAtMirrors` **INCHANGÉ** · ⛔ `manual_probes.dart` **non touché**
