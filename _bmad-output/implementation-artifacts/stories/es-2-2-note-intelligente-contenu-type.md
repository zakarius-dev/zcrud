---
baseline_commit: 709406ddf1ea40c15c4f638ff9a84fcab1dcc789
---

# Story ES-2.2 : Note intelligente à contenu typé (`ZSmartNote`, `zcrud_note`)

Status: review

- **Clé sprint-status** : `es-2-2-note-intelligente-contenu-type`
- **Epic** : ES-2 (Domaine canonique éducatif + codegen)
- **Taille** : **M**
- **Parallélisation** : ✅ **PARALLÉLISABLE** avec `ES-2.1` (`zcrud_document`) et `ES-2.6` (`zcrud_exam`).
  **Packages écrits** : `packages/zcrud_note/` (**NOUVEAU**), `tool/reserved_keys_gate/`, `pubspec.yaml` racine.
  ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_study_kernel`** — c'est la **condition** de la parallélisation (garde-fou n°2 de CLAUDE.md). Si le dev découvre qu'un symbole DOIT remonter au kernel ou au cœur, il **ARRÊTE** et le signale (cf. **D9**).
- **Couvre** : **FR-S5** · AD-3, AD-4, AD-7, AD-10, AD-17, AD-19 (+19.1/.a/.b/.c), AD-26, AD-27, **AD-28** · NFR-S3, NFR-S4, NFR-S8, NFR-S10 · SM-S5, SM-S6, SM-S7.
- **Dépend de** : **ES-1** (complet) + **ES-2.0** (`done`) + **ES-2.1** (`review` — ses règles de gate **(f)/(g1)/(g2)/(h)** s'appliquent **intégralement** ici).

> ✅ **Périmètre VÉRIFIÉ dans le PRD** (`prd-zcrud-study-2026-07-12/prd.md` l. 155-159 + table de traçabilité l. 477) : **FR-S5 = « Note intelligente à contenu typé » = `ZSmartNote` = ES-2.2**. C'est bien cette story qui la couvre (ES-2.1 l'avait explicitement rendue). **Aucune ligne de `ZStudyDocument`/`ZExam` ne doit être écrite ici.**

---

## Story

**As a** développeur intégrant zcrud dans une app d'étude (lex_douane, IFFD),
**I want** modéliser une note riche (`ZSmartNote`) dans un package `zcrud_note` dédié, dont le **contenu est typé** (ops Delta neutres) et **jamais une `String` ambiguë**,
**so that** l'ambiguïté markdown / Delta-JSON ne soit **plus jamais** résolue par une heuristique regex dispersée dans l'UI (AD-28), que l'audio reste un **slot additif optionnel** (AD-4), et qu'**aucun horodatage métier ne collisionne avec les clés du store** (AD-19).

---

## ⚠️ LE PATRON ES-2 (établi par ES-2.0, **durci par ES-2.1**) — à respecter DÈS LA NAISSANCE

`zcrud_generator` **et** `gate:reserved-keys` imposent désormais, **PAR MACHINE**, sur toute classe `@ZcrudModel` :

1. **Décodeur de domaine obligatoire** — `Xxx.fromMap(Map<String, dynamic> map)` (factory ou statique ; paramètres optionnels supplémentaires autorisés). **Absent ⇒ ÉCHEC DE BUILD** (`_requireDomainFromMap`).
2. **Si la classe est `ZExtensible`** (y compris **transitivement**) — sa `fromMap` **ne doit PAS déléguer nuement** à `_$XxxFromMap` (détecté à l'**AST du corps** ⇒ **BUILD ROUGE**). Elle doit peupler `extra` : `extra: _extraFrom(map)`.
3. **Garde RUNTIME** (`_$zRequireExtraPreserved`) émis dans le `.g.dart` de toute classe `ZExtensible` : il **décode une sonde et exige que la clé hors-schéma survive au round-trip COMPLET** (`fromMap` **ET** `toMap`). Il n'est **pas** sous `assert` ⇒ il mord **en release**, à l'enregistrement.
4. 🔴 **(g1) / (g2) — CANAUX HORS-CODEGEN, désormais tenus PAR MACHINE** (code-review ES-2.1 / H1). Tout champ d'instance d'une classe `@ZcrudModel` `ZExtensible` qui n'est **ni** `@ZcrudField`/`@ZcrudId`, **ni** `extra`/`extension`, **EST** un canal hors-codegen. Le gate exige, pour sa clé persistée — **le snake_case de son nom de champ** (contrainte **normative** : c'est ce qui la rend dérivable par machine) :
   - **(g1)** elle figure dans les **clés réservées** déclarées par la classe (`_reservedKeys`) ;
   - **(g2)** elle figure dans **`kProbeBodies[kind]`** du harnais, **non vide**.
   - **(f)** (volet A, comportementale) : `entity.extra.keys ∩ kProbeBodies[kind].keys == ∅`.
   ⇒ **`content` de cette story EST un canal hors-codegen** (**D3**). Les trois règles mordent dessus.
5. 🔴 **(h) — POLITIQUE `hide` DES EXTENSIONS GÉNÉRÉES, tenue par machine.** Aucune extension générée `XxxZcrud` d'une entité `ZExtensible` ne peut être exportée par un point d'entrée public : son `copyWith` **généré** remet `extra`/`extension`/**canaux hors-codegen** à leurs défauts ⇒ **destruction silencieuse** (c'était le finding **H3** d'ES-2.1 : `ZFlashcardZcrud` était exportée, sous 1000+ tests verts). ⇒ **`hide ZSmartNoteZcrud` OBLIGATOIRE** dans le barrel.

**Le patron de référence à COPIER, sur disque** :
- `ZExtensible` + **canal hors-codegen** : `packages/zcrud_document/lib/src/domain/z_document_reading_state.dart` — **le jumeau direct** (`kLearningKey` const · `fromMap` défensive câblant le canal à la main · `_reservedKeys` = `{...$FieldSpecs, 'extension', kLearningKey, ...ZSyncMeta.reservedKeys}` · `toMap()` = `{...extra, ...généré, canal}` · `copyWith` **à sentinelle** couvrant le canal · `==`/`hashCode` avec `_mapEquals`/`_mapHash`).
- `ZExtensible` + `ZEntity` : `packages/zcrud_document/lib/src/domain/z_study_document.dart`.
- `ZExtensible` **exemplaire d'AD-19.1** : `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart`.
- **Canal hors-codegen d'origine** : `ZFlashcard.source` (`z_flashcard.dart` l. 121, 236-238).

---

## ⚠️ Décisions de conception — CHAQUE prescription est CONFRONTÉE AU CODE RÉEL (R4 / R-G)

> **Leçon R-G** : *en ES-1.2, ES-1.4 et ES-2.1, les défauts venaient de la **STORY**.* Les décisions ci-dessous sont **fermées** — le dev ne les rejoue pas — **mais il DOIT les remettre en cause si le code réel les contredit, et le dire en Completion Notes.**

### D1 — Schéma canonique = **lex**, pas IFFD. Sources LUES, fichier par fichier.

| Élément | Source canonique (LUE) | Source secondaire (LUE) |
|---|---|---|
| `ZSmartNote` | `lex_douane/packages/lex_core/lib/domain/entities/education/smart_note.dart` | `iffd/lib/src/domain/models/smart_note_model.dart` |
| Contrat de dépôt / LWW | `lex_douane/packages/lex_core/lib/domain/repositories/smart_notes_repository.dart` | — |
| Ambiguïté du `content` | `iffd/lib/data_crud/rich_text_editor_screen.dart` **l. 206, 607** · `rich_text_editor/delta_to_markdown_helper.dart` **l. 39** · `rich_text_editor/editors/markdown_edition_field.dart` **l. 68** | `iffd/.../smartnotes/widgets/note_selector_dropdown.dart` **l. 204** |

**Pourquoi lex** : `SmartNoteModel` (IFFD) **importe `cloud_firestore`** (l. 1) et hérite de `FolderContentModel` (qui décode des `Timestamp`) — violation frontale de **NFR-S3/SM-S5**. lex est déjà pur-Dart, `fieldRename: snake`, ISO-8601. **IFFD est un cas de MIGRATION (ES-11.2), jamais une source de forme.**

### D2 — 🔴 **R-C EST RÉALISÉ DANS LA SOURCE** : `SmartNote.updatedAt` est inline. On le SUPPRIME.

Constat de disque, **littéral** :
- `smart_note.dart` (lex) l. 41-42 : `/// Dernière mise à jour.` `final DateTime updatedAt;` — **le geste NATUREL que R-C nomme** (« dernière édition »).
- `smart_notes_repository.dart` (lex) l. 12-16, **aveu explicite de la source** : *« **LWW `updated_at` hors-entité (AC4)** : la fraîcheur du merge est portée par une clé **hors-entité** `updated_at` … **bumpée à chaque mutation et maintenue cohérente avec le champ `updatedAt` de `SmartNote`** »*.

⇒ lex maintient **DEUX** copies de la même clé (une hors-entité, une dans le corps) **à la main**. Dans zcrud, le store écrit `ZSyncMeta` **APRÈS** le corps à chaque `put` (`hive_z_local_store.dart` `_encode` ; `firebase_z_repository_impl.dart` `_encode`/`_mergedMap`) ⇒ un champ métier sous `updated_at` est **écrasé silencieusement**, sans erreur ni test rouge.

**RÈGLE, sans exception :**
- ⛔ `ZSmartNote` ne déclare **NI `updatedAt` NI `isDeleted`** (ni sous ces noms, ni sous les clés `updated_at`/`is_deleted`). L'autorité LWW et le soft-delete vivent **hors-entité** (`ZSyncMeta`, AD-16/AD-19).
- ✅ `createdAt` est **conservé** (clé `created_at` — **distincte**, jamais réservée). Précédents : `ZStudyDocument.createdAt`, `ZStudyFolder.archivedAt`.
- 🔵 **Si** une app a besoin d'une « dernière édition » **métier** (distincte de la fraîcheur de sync), la clé est **`edited_at`** (table de décision AD-19.1.a : `edited_at`/`published_at`/`reviewed_at`). **Cette story ne l'ajoute PAS** : aucune source (lex ni IFFD) n'expose un « édité le » **distinct** de l'horodatage de sync — l'ajouter serait inventer un besoin. *(Si le dev trouve le contraire sur disque, il le dit et l'ajoute sous `edited_at`.)*
- ✅ **Aucune** entrée nouvelle dans `kLegacyUpdatedAtMirrors` (`{study_folder, flashcard}`) : `ZSmartNote` est **neuve**, pas un miroir legacy. Le **test de verrou** rend toute croissance **ROUGE** — c'est voulu.

### D3 — 🔴 **LE CŒUR DE LA STORY** : `content` = **ops Delta neutres**, canal **HORS-CODEGEN**

**Type Dart retenu** : `List<Map<String, dynamic>> content` (ops Delta neutres, défaut `const []`), clé persistée **`content`**.

**Trois preuves de disque, dans l'ordre :**

**(1) Le générateur ne peut PAS le sérialiser ⇒ canal hors-codegen, obligatoirement.**
`zcrud_model_generator.dart` `_classify` (l. 440-481) : `List<T>` **récurse sur `T`** (l. 442-458) ; `Map` n'a **aucune branche** (`isDartCoreMap` absent) et n'est **pas** annotable `@ZcrudModel` ⇒ `List<Map<String,dynamic>>` tombe dans `throw InvalidGenerationSourceError('Type de champ non (dé)sérialisable …')` ⇒ **BUILD ROUGE** si annoté `@ZcrudField`.
⇒ `content` est un **canal HORS-CODEGEN** (patron **exact** de `ZDocumentReadingState.learning` / `ZFlashcard.source`) : décodé et réémis **à la main**, sa clé `'content'` **dans `_reservedKeys`** (**g1**) **et** dans `kProbeBodies['smart_note']`, **non vide** (**g2**). La contrainte normative « clé = snake_case du nom de champ » est satisfaite trivialement (`content` → `content`).

**(2) Pourquoi PAS une `String` de Delta JSON (l'alternative REJETÉE).**
`ZDeltaCodec.encode` (`z_delta_codec.dart:25`) rend une **`String`** (`jsonEncode`) — un `content: String` **serait** codegen-able (le générateur gère `String`). **REJETÉ** : sur le fil, une `String` de Delta JSON est **indistinguable** d'une `String` markdown. C'est **exactement** l'état d'IFFD — et IFFD s'en sort par une **heuristique textuelle**, présente **4 fois** sur disque, **verbatim** :
```dart
if (trimmedValue.startsWith('[') && trimmedValue.contains('"insert"')) { … }
// rich_text_editor_screen.dart:206 · :607 · delta_to_markdown_helper.dart:39
// · editors/markdown_edition_field.dart:68
```
Un `content` **typé `List<Map>`** rend l'ambiguïté **structurellement impossible** : le **type** dit le format. C'est le *Prevents* d'AD-28 tenu **par construction**, pas par convention. *(Coût assumé : le canal hors-codegen — mécanique déjà éprouvée et tenue par machine depuis ES-2.1.)*

**(3) Le pont avec `zcrud_markdown` est une IDENTITÉ — aucune conversion, aucun codec.**
La « valeur neutre » de `ZMarkdownField`/`ZCodec` **EST** `List<Map<String, dynamic>>` (`delta_neutral_ops.dart` l. 19-21 ; `z_codec.dart` l. 14-16). Le type du domaine **est déjà** celui que l'éditeur parle. ⇒ ES-6.1 branche `note.content` sur l'éditeur **sans transformer quoi que ce soit**.

### D4 — 🔴 **PRESCRIPTION DE L'EPIC INVALIDÉE** : `zcrud_note` **NE DÉPEND PAS** de `zcrud_markdown`

L'epic prescrit *« dépend de `zcrud_markdown` (`ZCodec`) »* (epics.md l. 366). **Cette prescription ne tient pas** — trois constats de disque :

1. **`zcrud_markdown` est un package FLUTTER** (`pubspec.yaml` : `flutter: sdk: flutter`, `flutter_quill ^11.5.0`, `markdown`, `markdown_quill`, `vsc_quill_delta_to_html`, `flutter_quill_delta_from_html`, `flutter_math_fork`). L'arête ferait de `zcrud_note` — **package de domaine pur** — un package Flutter tirant **Quill + LaTeX + 2 convertisseurs HTML**, et ses tests basculeraient de `dart test` à `flutter test`. Contraire au patron ES-2 (`zcrud_document` : pur-Dart, `dart test`) et à l'esprit de **NFR-S10/SM-S7**.
2. **Le domaine n'a AUCUN besoin du `ZCodec`.** Le `ZCodec` convertit **ops neutres ↔ format persisté** (`z_codec.dart` l. 18-21). Le format persisté canonique de la note **EST** le Delta (AD-28) ⇒ le codec applicable est `ZDeltaCodec`, **codec identité** (`z_delta_codec.dart` l. 17 : *« Round-trip IDENTITÉ »*). **Un codec identité au milieu du domaine n'apporte rien** — il rendrait juste la `String` de (2)/D3.
3. **`DeltaNeutralOps` (le décodeur défensif d'ops) est PRIVÉ** : il vit sous `lib/src/data/`, importe `flutter_quill` et **n'est PAS exporté par le barrel** (`zcrud_markdown.dart` — vérifié : `delta_neutral_ops.dart` absent des `export`). ⇒ **même avec l'arête**, `zcrud_note` **ne pourrait pas** le réutiliser.

⇒ **Décision** : `zcrud_note` = **pur-Dart**, `dependencies: zcrud_core, zcrud_annotations` **UNIQUEMENT**. L'arête `zcrud_note → zcrud_markdown` naîtra en **ES-6.1**, avec le **premier widget** (`z_smart_note_editor.dart` sous `lib/src/presentation/`) — **là où elle a un sens**, et où `zcrud_note` deviendra légitimement un package Flutter.

**AD-28 (« aucun nouveau codec, jamais dupliqué ») est RESPECTÉ** : la coercition défensive de **D5** n'est **PAS un codec** — elle ne convertit **entre aucun format** ; elle **coerce une valeur persistée vers la forme canonique du champ**, exactement comme `_$asInt`/`_asStringMap`/`ZDocumentLearningInfo.fromJsonSafe` le font pour leurs champs. Aucune classe `implements ZCodec` n'est créée. **Le recouvrement résiduel avec `DeltaNeutralOps.asDeltaOps` (~20 lignes pur-Dart) est consigné en dette `DW-ES22-1`** (cf. § Dettes).

### D5 — 🔴 Coercition défensive du `content` : **JAMAIS `[]` sur un texte legacy** (AD-10 + préservation)

`DeltaNeutralOps.asDeltaOps` rend **`null`** pour une `String` non-JSON (l. 34 : `jsonDecode` throw ⇒ capté ⇒ `decodeDefensiveOps` rend `[]`). **Transposer ça tel quel dans l'entité serait DESTRUCTEUR** : une note lex (dont le `content` **EST** une `String` markdown — `smart_note.dart` l. 26-27 : *« Contenu (markdown) »*) décoderait sur **`[]`**, et le **premier `put` persisterait le vide** ⇒ **perte irréversible du corps de la note**. Ce qui est correct dans une **tranche de formulaire** (aucun corpus legacy) est **catastrophique** dans une **entité** adossée à un store.

**Règles de `_contentFrom(Object? raw)` — total, déterministe, ne throw JAMAIS :**

| Entrée persistée | Résultat | Raison |
|---|---|---|
| absente / `null` | `const []` | défaut sûr (AD-10) |
| `List` d'ops valides (chaque élément = `Map` portant `insert`) | **ops verbatim** (clés coercées en `String`) | forme canonique ; **identité** — embeds opaques (LaTeX/table) **préservés** |
| `String` qui **parse** en JSON `List` d'ops valides | ops | compat avec `ZDeltaCodec.encode` / `ZMarkdownField.persistedValueOf` (qui rendent une **`String`** JSON) **et** avec le corpus Delta d'IFFD |
| `String` **non-Delta** (markdown lex, sticky-note IFFD, texte plat) — **non vide** | **`[{'insert': '<raw>'}]`**, `'\n'` final garanti | 🔴 **le texte SURVIT VERBATIM.** C'est l'*« upgrade des sticky-notes (texte plat) vers `ZCodec` »* qu'ES-6.2 exige, au coût zéro et **sans perte** ; le rendu riche (markdown → Delta) reste le travail **explicite** d'ES-6.2, jamais une devinette |
| `String` vide / blanche | `const []` | — |
| tout le reste (`int`, `Map`, `List` malformée, op sans `insert`…) | `const []` | défensif |

- ⚠️ **Ce n'est PAS une heuristique** (au sens d'AD-28) : aucune devinette **markdown vs Delta** n'est faite pour **décider du rendu**. La fonction est **totale** — « si ce n'est pas du Delta, c'est du texte » — et **ne détruit rien**. La détection Delta est **STRUCTURELLE** (`jsonDecode` + forme `List<Map>` portant `insert`), **jamais textuelle** (⛔ pas de `startsWith('[')`, R5).
- ✅ **Normalisation idempotente** : `toMap()` réémet **toujours** la `List` native ⇒ après un premier cycle, le fil ne porte plus que la forme canonique. `fromMap(toMap(x)) == x` (round-trip **stable**), et `fromMap` d'une `String` legacy est **stable au second passage**.
- ✅ **`toMap()` émet TOUJOURS `content`** (même vide, `[]`) — round-trip idempotent, patron `learning`.

### D6 — Audio : **hors-schéma**, en `extra` **et** `ZExtension` (FR-S5, AD-4)

FR-S5 est explicite : *« Les champs audio (`audioUrl`/`audioPath`/`audioTextHash`) vivent en `ZExtension`/`extra` ; une note sans audio se désérialise **sur le défaut** »*.

⇒ **`ZSmartNote` ne déclare AUCUN champ audio.** Deux voies, **les deux testées** :
1. **`extra` (voie par défaut, zéro code)** — une note dont le store porte `audio_url`/`audio_path`/`audio_text_hash` **au top-level** voit ces clés **inconnues** atterrir dans `extra` et **round-tripper** (AD-4 pt.2). Rien à écrire ; il faut le **prouver**.
2. **`ZNoteAudio implements ZExtension` (voie TYPÉE, opt-in)** — slot `extension` versionné (AD-4 pt.1) : `formatVersion` (= `1`), `toJson()`, `static ZNoteAudio? fromJsonSafe(Object? json)` bâti sur `ZExtension.guard` (`null` si absent/corrompu/version non gérée — **jamais** de throw). Injecté via `ZSmartNote.fromMap(map, extensionParser: ZNoteAudio.fromJsonSafe)`.
   - Champs : `url: String?`, `path: String?`, `textHash: String?`.
   - 🔴 **Divergence de type RÉELLE, trouvée sur disque** : `audioTextHash` est `String?` chez lex (`smart_note.dart` l. 36) et **`int?`** chez IFFD (`smart_note_model.dart` l. 11, décodé par `int.tryParse(...toString())`). ⇒ `fromJsonSafe` **coerce défensivement** `String` **ou** `num` → `String?` (jamais de throw). *(IFFD porte en plus `audioText: String?` — sans équivalent lex : il tombe dans `extra`, cf. ES-11.2.)*
   - 🔵 **`ZNoteAudio` est le PREMIER `ZExtension` CONCRET du repo** (vérifié : `grep -r "implements ZExtension" packages/*/lib` ⇒ **zéro**). AD-4 pt.1 n'a donc **jamais été exercé concrètement** — c'est un filet qu'on n'a jamais vu mordre (motif de la rétro ES-1). Cette story lui donne son premier cas réel **et son test**.
   - ⚠️ `ZNoteAudio` n'est **ni `@ZcrudModel` ni `ZExtensible`** ⇒ hors `E_disk`/`R_disk` ⇒ **AUCUN câblage `manual_probes.dart`** (même raisonnement que `ZDocumentLearningInfo`, D3 d'ES-2.1 — l'y ajouter serait une erreur).

### D7 — **Pas de dépendance `zcrud_study_kernel`** (leçon L2 d'ES-2.1)

ES-2.1 a déclaré l'arête kernel « pour les stories suivantes » et a écopé d'un **finding LOW (L2)** : *« dépendance DÉCLARÉE, aucun import »*. `ZSmartNote` référence son dossier par `folderId` (**clé neutre `String`**, exactement comme `zcrud_mindmap` et `ZFlashcard`) : **aucun symbole du kernel n'est importé**.
⇒ `dependencies: zcrud_core ^0.1.0, zcrud_annotations ^0.1.0`. **Rien d'autre.** L'arête kernel sera déclarée **quand un import réel l'exigera** (ES-3.3, registre de cascade).

### D8 — `ZSmartNote` **EST** un `ZEntity` (contrairement à `ZDocumentReadingState`)

C'est un **contenu partageable** top-level, à identité propre (lex : `final String id`). ⇒ `@ZcrudModel(kind: 'smart_note') class ZSmartNote extends ZEntity with ZExtensible`, `@ZcrudId() final String? id;` (nullable ⇒ **éphémère** AD-14, patron `ZStudyDocument`/`ZStudyFolder` — l'entité n'attribue **jamais** d'`id` ; la matérialisation est au repository, **ES-3**).

### D9 — **Aucune écriture du kernel ni du cœur** — et quoi faire si ce n'est plus vrai (R-F / R-E)

Le périmètre ne requiert **aucun** symbole nouveau de `zcrud_study_kernel` ni de `zcrud_core` ⇒ le barrel du kernel, `z_kernel_surface_guard_test.dart` et la liste `hide` de `zcrud_flashcard` **restent intacts** ⇒ **la parallélisation avec ES-2.1/ES-2.6 est préservée**.

🔴 **SI** le dev conclut qu'un type doit **remonter** au kernel ou au cœur (p. ex. « le décodeur défensif d'ops Delta devrait vivre dans `zcrud_core` ») : il **ARRÊTE**, **ne l'écrit pas**, et le **SIGNALE** — cela **resérialiserait** les autres stories ES-2 en vol. La dette **DW-ES22-1** est le canal prévu pour ça.

### D10 — Déclaration du package : **root `pubspec.yaml` SEULEMENT**

**Vérifié** : `melos.yaml` déclare `packages: - packages/**` (**glob**) — il n'énumère aucun package. Le seul point de déclaration est le bloc `workspace:` du root `pubspec.yaml`.
⇒ **`melos.yaml` n'est PAS modifié** ; `gate:melos` (qui ne compare que les blocs `scripts:`) **non impacté** ; `melos list` passe **16 → 17** automatiquement ; le commentaire d'en-tête du root pubspec (« Les **16** packages PRODUIT… », l. 3-4) passe à **17** (+ mention `zcrud_note` en ES-2.2). `graph_proof.py` itère `packages/*/pubspec.yaml` ⇒ le nouveau package est pris **automatiquement** et doit rester **ACYCLIQUE / CORE OUT=0**.

### D11 — Conséquence assumée : `content` **n'a pas de `ZFieldSpec`**

Un canal hors-codegen ne produit **aucun** `ZFieldSpec` ⇒ `content` **n'apparaîtra pas** dans un formulaire `DynamicEdition` généré. **C'est déjà le cas** de `ZFlashcard.source` et `ZDocumentReadingState.learning`. L'éditeur de note (**ES-6.1**) ajoute son `ZMarkdownField` **explicitement**, câblé sur `note.content` (identité de type, **D3(3)**). À **documenter en dartdoc** pour qu'une revue ne le prenne pas pour un oubli.

---

## Schéma canonique retenu (clés persistées **snake_case**, enums **camelCase**)

### `ZSmartNote` — `@ZcrudModel(kind: 'smart_note')` · `extends ZEntity with ZExtensible` · contenu **PARTAGEABLE**

| Champ Dart | Type | Clé persistée | Défaut / défensif | Source lex |
|---|---|---|---|---|
| `id` | `String?` | `id` | `null` (éphémère) — `@ZcrudId()` | `id` (`String` requis) |
| `folderId` | `String` | `folder_id` | `''` | `folderId` |
| `subFolderId` | `String?` | `sub_folder_id` | `null` | `subFolderId?` |
| `title` | `String` | `title` | `''` | `title` |
| **`content`** | **`List<Map<String,dynamic>>`** | **`content`** | 🔴 **HORS-CODEGEN (D3)** — `const []` ; coercition **D5** ; **jamais de throw** | `content` (**`String` markdown**) |
| `createdAt` | `DateTime?` | `created_at` | `null` | `createdAt` |
| `extension` | `ZExtension?` | `extension` | hors-codegen ; `ZNoteAudio.fromJsonSafe` injectable (**D6**) | — |
| `extra` | `Map<String,dynamic>` | *(clés non réservées)* | hors-codegen ; **porte l'audio top-level legacy** | — |
| ⛔ ~~`updatedAt`~~ | — | — | **SUPPRIMÉ — AD-19 / D2** (le piège R-C, **réalisé** dans lex) | `updatedAt` |
| ⛔ ~~`audioUrl`/`audioPath`/`audioTextHash`~~ | — | — | **HORS-SCHÉMA — FR-S5 / D6** (`extra` ou `ZNoteAudio`) | `audioUrl?`/`audioPath?`/`audioTextHash?` |

`_reservedKeys = { for (s in $ZSmartNoteFieldSpecs) s.name, 'extension', kContentKey, ...ZSyncMeta.reservedKeys }`
*(`kContentKey = 'content'` — **const déclarée une seule fois**, consommée par `fromMap` / `toMap` / `_reservedKeys` : zéro littéral dupliqué, patron `kLearningKey`.)*

### `ZNoteAudio` — `implements ZExtension` · **hand-written** · aucune annotation, aucun `.g.dart`, aucun `kind`

| Champ | Type | Clé (dans la map `extension`) | Défensif |
|---|---|---|---|
| `formatVersion` | `int` (`= 1`) | `format_version` | version non gérée ⇒ **`fromJsonSafe` rend `null`** (jamais de throw) |
| `url` | `String?` | `url` | non-`String` ⇒ `null` |
| `path` | `String?` | `path` | non-`String` ⇒ `null` |
| `textHash` | `String?` | `text_hash` | **`String` OU `num`** ⇒ `String?` (divergence lex/IFFD, **D6**) |

---

## Acceptance Criteria

### AC1 — Package `zcrud_note` créé, déclaré, acyclique, **pur-Dart**

**Given** le monorepo melos à **16** packages
**When** on crée `packages/zcrud_note/`
**Then** son `pubspec.yaml` déclare `resolution: workspace`, `version: 0.1.0`, `publish_to: none` et **exactement** `dependencies: zcrud_core ^0.1.0, zcrud_annotations ^0.1.0` — ⛔ **PAS `zcrud_markdown`** (**D4**), ⛔ **PAS `zcrud_study_kernel`** (**D7**, leçon L2), **aucune** dép lourde, **aucun** gestionnaire d'état, **aucun** `cloud_firestore`, **aucun** SDK Flutter ; `dev_dependencies: zcrud_generator, build_runner, test`
**And** le package est ajouté au bloc `workspace:` du **root `pubspec.yaml`** (commentaire « 16 » → « **17** ») — **`melos.yaml` n'est PAS modifié** (**D10**)
**And** l'API publique est le barrel `lib/zcrud_note.dart`, l'implémentation sous `lib/src/domain/` ; les tests tournent sous **`dart test`**
**And** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** et `melos list` rend **17**.

### AC2 — 🔴 (h) — Le barrel **masque** l'extension générée

**Given** le finding **H3** d'ES-2.1 (`ZFlashcardZcrud` **exportée**, sous 1000+ tests verts : son `copyWith` généré **détruit** `extra`/`extension`/canaux)
**When** on écrit le barrel
**Then** `export 'src/domain/z_smart_note.dart' hide ZSmartNoteZcrud;` — **l'extension générée n'est PAS exportée**
**And** la règle **(h)** de `scripts/ci/gate_reserved_keys.dart` est **verte** sur `zcrud_note`
**And** si la surface publique a besoin de `toMap()`, il est **promu en méthode d'instance** (patron `ZDocumentViewerPrefs.toMap`) — jamais réexposé via l'extension.

### AC3 — 🔴 `content` typé, canal hors-codegen, **ambiguïté impossible** (AD-28 / FR-S5)

**Given** que le générateur **ne supporte aucun type `Map`** (`_classify`, l. 440-481 — **D3(1)**)
**When** on modélise `ZSmartNote.content`
**Then** son type Dart est **`List<Map<String, dynamic>>`** (ops Delta neutres) — **jamais** `String?` (AD-28), et il **n'est PAS** un `@ZcrudField`
**And** il est câblé **exactement** comme `ZDocumentReadingState.learning` : décodé à la main dans `fromMap`, réémis **toujours** (même vide) dans `toMap()`, sa clé `kContentKey = 'content'` **dans `_reservedKeys`** (**g1**)
**And** un test **machine** prouve que `content` **n'est PAS** dans `$ZSmartNoteFieldSpecs` (canal, pas champ — **D11**)
**And** un test prouve l'**identité de type avec la valeur neutre de `ZCodec`/`ZMarkdownField`** : `note.content` est **directement** une `List<Map<String,dynamic>>` d'ops (aucune conversion requise en ES-6.1) — **aucune classe `implements ZCodec` n'est créée dans `zcrud_note`** (AD-28).

### AC4 — 🔴 D5 — Coercition du `content` : **aucun texte legacy n'est détruit**, aucun throw

**Given** le corpus réel (lex : `content` = **`String` markdown** · IFFD : `String?` **Delta OU markdown**, désambiguïsé par heuristique en **4 sites**)
**When** on décode
**Then** la **matrice D5 complète** est testée, cas par cas :

| Entrée | Attendu |
|---|---|
| absente / `null` | `[]` |
| `[{'insert':'a\n'}]` (List native) | **identité** (ops verbatim) |
| `[{'insert':{'formula':'x^2'}}]` (embed opaque) | **identité** — l'embed **survit** |
| `'[{"insert":"a\\n"}]'` (String JSON Delta) | ops décodées |
| `'# Titre\n**gras**'` (markdown lex) | 🔴 **`[{'insert':'# Titre\n**gras**\n'}]`** — **texte VERBATIM, jamais `[]`** |
| `'note collante'` (sticky IFFD, texte plat) | `[{'insert':'note collante\n'}]` |
| `''` / `'   '` | `[]` |
| `42` · `{'a':1}` · `[1,2]` · `[{'retain':1}]` (op sans `insert`) | `[]` |

**And** **aucune** entrée ne fait **throw** (AD-10) — y compris `ZSmartNote.fromMap(const <String, dynamic>{})`
**And** la **normalisation est idempotente** : `fromMap(toMap(fromMap(m))) == fromMap(m)` pour **chaque** ligne de la matrice
**And** la détection Delta est **STRUCTURELLE** (`jsonDecode` + `List<Map>` portant `insert`), **jamais textuelle** — ⛔ **aucun `startsWith('[')` / `contains('"insert"')`** dans `zcrud_note` (R5 ; c'est **littéralement** le code d'IFFD qu'on refuse).

### AC5 — Audio hors-schéma : `extra` **ET** `ZNoteAudio` (FR-S5 / AD-4 / D6)

**Given** FR-S5 (« les champs audio vivent en `ZExtension`/`extra` ; une note sans audio se désérialise sur le défaut »)
**When** on modélise
**Then** `ZSmartNote` **ne déclare AUCUN** champ audio (`$ZSmartNoteFieldSpecs` ne contient ni `audio_url`, ni `audio_path`, ni `audio_text_hash` — assertion **machine**)
**And** **voie `extra`** : une map de store portant `audio_url`/`audio_path`/`audio_text_hash` au top-level les voit **atterrir dans `extra`** et **survivre** à `toMap()` (round-trip AD-4)
**And** **voie typée** : `ZNoteAudio implements ZExtension` (`formatVersion = 1`, `toJson`, `static fromJsonSafe`) round-trippe via `extension` quand `extensionParser: ZNoteAudio.fromJsonSafe` est injecté
**And** **note sans audio** ⇒ `extension == null`, `extra` sans clé audio — **le défaut**, jamais un throw
**And** `fromJsonSafe` est **défensif** : `null`, non-map, `format_version` inconnue (`99`), champs corrompus ⇒ **`null`** ou champ `null` — **jamais** de throw
**And** `textHash` accepte **`String` (lex)** *et* **`num` (IFFD)** et rend une `String?` (**divergence réelle**, D6).

### AC6 — AD-19 dès la naissance : **zéro** clé de sync dans l'entité (R-C)

**Given** que lex porte `updatedAt` **inline** ET maintient une copie hors-entité **à la main** (`smart_notes_repository.dart` l. 12-16 — **D2**)
**When** on modélise `ZSmartNote`
**Then** l'entité **ne déclare NI `updatedAt` NI `isDeleted`**, ni sous ces noms, ni sous les clés `updated_at`/`is_deleted`
**And** **(R-C)** `$ZSmartNoteFieldSpecs.map((s) => s.name).toSet().intersection(ZSyncMeta.reservedKeys)` est **VIDE** — assertion écrite **explicitement** *(ES-2.1 l'avait oubliée sur sa 3ᵉ entité — finding **M1** ; ne pas rejouer)*
**And** **(AD-19.1.b)** **aucun** `@ZcrudField(persistAs: ZPersistAs.timestamp)` sur une clé réservée
**And** `createdAt` est bien sous `created_at` (clé **distincte**, jamais réservée)
**And** `kLegacyUpdatedAtMirrors` reste **INCHANGÉ** (`{study_folder, flashcard}`) — le **test de verrou** l'exige.

### AC7 — R-A : `_reservedKeys ⊇ ZSyncMeta.reservedKeys`, prouvé **COMPORTEMENTALEMENT**

**Given** que l'oubli s'est produit **2 fois sur 4** en ES-1.3, **sous 1193 tests verts**
**When** on décode une **sonde de STORE** : `{...corpsMinimal, 'content': <ops>, 'updated_at': '2026-01-01T00:00:00.000Z', 'is_deleted': true, 'zz_cle_inconnue': 'gardee'}`
**Then** `extra.keys.toSet().intersection(ZSyncMeta.reservedKeys)` est **VIDE**
**And** `extra['zz_cle_inconnue'] == 'gardee'` (anti-vacuité : on ne « passe » pas en vidant `extra`)
**And** `extra` **ne contient PAS `content`** (règle **(f)** : une clé du corps de sonde dans `extra` **PROUVE** un canal oublié dans `_reservedKeys`)
**And** `toMap()` **ne réémet NI `updated_at` NI `is_deleted`**, **ne réémet `content` qu'UNE fois** (pas de doublon `...extra` + câblage manuel)
> *Groupe de tests calqué sur « AD-19 — clés de sync hors-entité » de `z_repetition_info_test.dart` / `z_document_reading_state_test.dart` — le reproduire, pas le réinventer.*

### AC8 — Conformité au patron ES-2.0, **observée** (pas déclarée)

**Given** les 3 filets machine du générateur
**When** `melos run generate` s'exécute
**Then** `ZSmartNote` déclare un **décodeur de domaine `fromMap`** qui **peuple `extra`** (`extra: _extraFrom(map)`) et **ne délègue PAS nuement** à `_$ZSmartNoteFromMap` — le build **passerait ROUGE** sinon
**And** son `toMap()` d'instance **étale `...extra`** et le canal `content` ⇒ le **garde runtime** `_$zRequireExtraPreserved` (émis dans `z_smart_note.g.dart`) **passe à l'enregistrement**
**And** un test prouve le round-trip **par le REGISTRE** : `registry.decode('smart_note', sonde)` puis `registry.encode` **préservent** `zz_cle_inconnue` **ET** le `content` (assertion **(e)** du gate)
**And** `copyWith` est **à sentinelle** et couvre **TOUS** les champs, **y compris `content`, `extension`, `extra`** (le `copyWith` **généré** les remettrait aux défauts — perte silencieuse ; patron `ZDocumentReadingState.copyWith`).

### AC9 — 🔴 Leçon **H2 d'ES-2.1** : la garde de valeur est **PARTAGÉE** par `fromMap` **ET** `copyWith`

**Given** le finding H2 d'ES-2.1 (`ZStudyDocument.copyWith` **rouvrait** l'invariant `sizeBytes >= 0` que `fromMap` fermait, alors que la dartdoc promettait « jamais négative »)
**When** on implémente la coercition du `content`
**Then** elle est **extraite dans une fonction nommée unique** (`_contentFrom` / `normalizeNoteContentOps`), **appelée par `fromMap` ET par `copyWith`** — aucune voie d'écriture ne la contourne
**And** un test prouve qu'elle **ne se rouvre pas via `copyWith`** : `note.copyWith(content: [{'retain': 1}])` (op invalide) ⇒ ops **normalisées** (`[]`), **jamais** persistées telles quelles
**And** ⛔ **le constructeur `const` n'est PAS gardé** (aucun `assert`) : le décodeur **généré** l'appelle avec les valeurs **BRUTES** — un `assert` y ferait **échouer la désérialisation d'une donnée corrompue** (**violation d'AD-10**). La garde vit **exclusivement** aux frontières `fromMap`/`copyWith`.

### AC10 — R-B / R8 : câblage du harnais **DANS LA MÊME STORY** (sinon le gate est vert pour rien)

**Given** qu'une entité **non câblée n'est pas sondée** — le gate serait un **faux vert par omission**
**When** on ajoute le kind `smart_note`
**Then** `tool/reserved_keys_gate/pubspec.yaml` gagne `zcrud_note: ^0.1.0`
**And** `tool/reserved_keys_gate/lib/src/registrars.dart` est complété : **`kRegistrars`** += `registerZSmartNote` ; **`kProbeBodies['smart_note']`** = corps minimal valide **portant une clé `content` NON VIDE** (**g2** — sans quoi (f) serait inerte : c'est le finding **H1** d'ES-2.1, à ne pas rejouer)
**And** `kNonExtensibleKinds` **INCHANGÉ** (`ZSmartNote` **EST** `ZExtensible`) ; `kLegacyUpdatedAtMirrors` **INCHANGÉ** ; **aucune** entrée dans `manual_probes.dart` (**D6** : `ZNoteAudio` n'est ni `ZExtensible` ni enregistrée ⇒ hors `E_disk`/`R_disk`)
**And** `dart run scripts/ci/gate_reserved_keys.dart` est **VERT** — contrôle de couverture (`R_disk \ R_wired`), règles **(g1)/(g2)/(h)** comprises.

### AC11 — R-H / AD-10 : chaque invariant naît **avec sa garde ET son cas corrompu**

**Given** que ces invariants sont, aujourd'hui, de la **prose**
**When** on les implémente
**Then** **chacun** porte (1) un test de **garde** sur la valeur légale et (2) un test de **désérialisation corrompue** prouvant le **défaut sûr, sans throw** :

| Invariant | Garde | Cas corrompu (jamais de throw) |
|---|---|---|
| `content` = ops Delta valides | ops + embed opaque conservés **à l'identique** | matrice **AC4** complète ⇒ `[]` **ou** texte préservé — **jamais** de throw |
| `content` **jamais détruit** sur un texte legacy | `'# T'` ⇒ `[{'insert':'# T\n'}]` | — (c'est **le** cas destructeur que D5 ferme) |
| `title` / `folderId` | valeurs conservées | absent / non-`String` ⇒ `''` |
| `subFolderId` | valeur conservée | absent / non-`String` ⇒ `null` |
| `createdAt` ISO-8601 | date conservée | `'pas-une-date'` / `42` / absent ⇒ `null` |
| `ZNoteAudio.formatVersion` | `1` géré | `99` / absent / non-map ⇒ **`null`** (pas de throw) |
| `ZNoteAudio.textHash` | `'abc'` (lex) | `12345` (**int**, IFFD) ⇒ `'12345'` ; `[]` ⇒ `null` |

**And** `ZSmartNote.fromMap(const <String, dynamic>{})` **ne throw pas** (map vide).

### AC12 — R3 : **injection de régression** — les filets sont vus **ROUGIR**

**Given** *« un filet qu'on n'a pas vu échouer n'est pas un filet »* (rétro ES-1, §7)
**When** on injecte, **une par une** (restauration **à l'octet près** entre chaque, `git diff` vide) :
1. retrait de `...ZSyncMeta.reservedKeys` de `ZSmartNote._reservedKeys` **(R-A)**
2. retrait de `kContentKey` de `ZSmartNote._reservedKeys` **(g1 + f)** — *l'injection exacte qui laissait le gate **VERT** avant le correctif H1 d'ES-2.1*
3. retrait de la clé `content` de `kProbeBodies['smart_note']` **(g2)**
4. export de `ZSmartNoteZcrud` (retrait du `hide`) **(h)**

**Then** `dart run scripts/ci/gate_reserved_keys.dart` passe **ROUGE (RC=1)** dans **LES QUATRE** cas — la **sortie brute** de chacun est **collée** dans les Completion Notes
**And** chaque restauration rend le gate **VERT**
**And** l'orchestrateur **rejoue lui-même** la séquence (le rapport de l'agent ne vaut **pas** preuve — R9).

### AC13 — R9 : vérif verte **repo-wide**, codegen **committé**

**Given** les gates de merge
**When** on clôt la story
**Then** `melos run generate` OK · `melos run analyze` **repo-wide** RC=0 · `melos run test` RC=0 (aucune régression : nb de tests ≥ avant) · `melos run verify` RC=0 (dont `gate:graph`, `gate:codegen`, **`gate:codegen-distribution`**, **`gate:reserved-keys`**)
**And** les `*.g.dart` de `packages/zcrud_note/lib/` sont **suivis par git** (le `.gitignore` porte déjà `!packages/*/lib/**/*.g.dart`) et **présents dans l'arbre** — `gate:codegen-distribution` échouerait sinon.

### AC14 — Périmètre : **aucune** écriture hors du package (parallélisation préservée)

**Given** les garde-fous de parallélisation (CLAUDE.md)
**When** on inspecte le diff
**Then** les **seuls** fichiers modifiés hors `packages/zcrud_note/` sont : root `pubspec.yaml` (bloc `workspace:` + commentaire), `tool/reserved_keys_gate/pubspec.yaml`, `tool/reserved_keys_gate/lib/src/registrars.dart`
**And** **AUCUNE** ligne de `zcrud_core`, `zcrud_study_kernel`, `zcrud_document`, `zcrud_flashcard`, `zcrud_markdown`, `zcrud_mindmap`, `zcrud_firestore` n'est modifiée
**And** **aucun** fichier de `/home/zakarius/DEV/lex_douane` ni `/home/zakarius/DEV/iffd` n'est touché (**lecture seule**)
**And** **aucun widget**, **aucune** `presentation/` (ES-6.1), **aucun** adaptateur de migration de tables (ES-6.2), **aucun** port/dépôt (ES-3) n'est écrit.

---

## Tasks / Subtasks

- [x] **T1 — Squelette du package** (AC1, AC14)
  - [x] `packages/zcrud_note/pubspec.yaml` (calquer `zcrud_document/pubspec.yaml`, **MOINS** `zcrud_study_kernel` — **D7** ; **zéro Flutter**, **zéro `zcrud_markdown`** — **D4**)
  - [x] Root `pubspec.yaml` : `- packages/zcrud_note` dans `workspace:` ; commentaire « 16 » → « **17** »
  - [x] `lib/zcrud_note.dart` (barrel, **`hide ZSmartNoteZcrud`** — AC2) ; `lib/src/domain/`
  - [x] `dart pub get` → `python3 scripts/dev/graph_proof.py` (**ACYCLIQUE / CORE OUT=0**) ; `melos list` = **17**
- [x] **T2 — `ZNoteAudio`** (AC5, AC11 — **D6**) — `implements ZExtension`, **hand-written** ; `formatVersion = 1` ; `toJson()` ; `static ZNoteAudio? fromJsonSafe(Object?)` sur `ZExtension.guard` ; `textHash` coerce **`String` | `num`** ; `==`/`hashCode`
- [x] **T3 — Coercition du contenu** (AC3, AC4, AC9 — **D5**) — fonction **nommée, unique, pur-Dart** (`_contentFrom` / `normalizeNoteContentOps`), **totale**, **jamais de throw**, détection **STRUCTURELLE** (⛔ zéro regex/`startsWith`) ; `const kContentKey = 'content';`
- [x] **T4 — `ZSmartNote`** (AC3, AC6, AC7, AC8, AC9) — `@ZcrudModel(kind: 'smart_note')`, `extends ZEntity with ZExtensible` ; patron **`ZDocumentReadingState` intégral** : `fromMap` défensive (canal `content` à la main + `extension` + `extra: _extraFrom(map)`), `_reservedKeys` **avec `kContentKey` ET `...ZSyncMeta.reservedKeys`**, `toMap()` = `{...extra, ...généré, kContentKey: content}` (+ `extension` si non nul), `copyWith` **à sentinelle** appelant **la même** coercition, `==`/`hashCode` ; ⛔ **zéro `updatedAt`/`isDeleted`**, **zéro champ audio**
- [x] **T5 — Codegen** — `melos run generate` ; **committer** `packages/zcrud_note/lib/**/*.g.dart` (AC13)
- [x] **T6 — Câblage du harnais (R8 — MÊME story)** (AC10)
  - [x] `tool/reserved_keys_gate/pubspec.yaml` : `zcrud_note: ^0.1.0`
  - [x] `registrars.dart` : `kRegistrars` += `registerZSmartNote` ; `kProbeBodies['smart_note']` = `{'id':'p', 'folder_id':'f', 'title':'t', 'content': [{'insert':'sonde\n'}]}` (**`content` NON VIDE — g2**)
  - [x] ⛔ **Ne PAS** toucher `kNonExtensibleKinds`, `kLegacyUpdatedAtMirrors`, `manual_probes.dart`
- [x] **T7 — Tests** (AC2..AC11) — `packages/zcrud_note/test/` (**`dart test`**) : matrice **D5/AC4** complète · round-trips (pleine + minimale + idempotence) · groupe **« AD-19 — clés de sync hors-entité »** (copier `z_document_reading_state_test.dart`) · `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` · `content ∉ $FieldSpecs` · audio ∉ `$FieldSpecs` · `extra` ∌ `content` · les **deux** voies audio (`extra` **et** `ZNoteAudio`) · `copyWith` ne rouvre pas la garde (**AC9**) · « aucune entrée ne fait THROW » · `fromMap(const {})`
- [x] **T8 — Injections de régression (R3)** (AC12) — **4 injections** (`ZSyncMeta.reservedKeys` · `kContentKey` · sonde `content` · `hide`) ⇒ **ROUGE** à chaque fois (coller la **sortie brute**) ⇒ restaurer (`git diff` vide) ⇒ **VERT**
- [x] **T9 — Vérif verte repo-wide** (AC13) — `generate` → `analyze` → `test` → `verify`
- [x] **T10 — Completion Notes** — dette **DW-ES22-1** (recouvrement `asDeltaOps`) · **DW-ES22-2** (mapping IFFD) · justification de la coercition D5 (et de toute décision **D** remise en cause) · confirmation que **rien** du kernel/cœur n'a été écrit

---

## Dev Notes

### Fichiers à LIRE avant d'écrire une ligne (patrons à copier, pas à réinventer)

| Fichier | Pourquoi |
|---|---|
| `packages/zcrud_document/lib/src/domain/z_document_reading_state.dart` | 🔴 **LE JUMEAU** : `ZExtensible` + **canal hors-codegen** (`kLearningKey`) — `fromMap`/`toMap`/`copyWith`/`_reservedKeys`/`_extraFrom`/`==` |
| `packages/zcrud_document/lib/src/domain/z_study_document.dart` | `ZEntity` + `ZExtensible` + `@ZcrudId()` |
| `packages/zcrud_document/lib/zcrud_document.dart` | Barrel : politique **`hide`** de **toutes** les extensions générées (M2/H3) |
| `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` | Exemplaire d'AD-19.1 |
| `packages/zcrud_core/lib/src/domain/extension/z_extension.dart` | Contrat `ZExtension` (`formatVersion`/`toJson`/`guard`) — **D6** |
| `packages/zcrud_markdown/lib/src/domain/z_codec.dart` + `src/data/z_delta_codec.dart` + `src/data/delta_neutral_ops.dart` | **LIRE, NE PAS IMPORTER** : forme de la valeur neutre (`List<Map<String,dynamic>>`) ; `asDeltaOps` (l. 29-49) = la coercition à **reprendre en pur-Dart**, en **corrigeant** le repli destructeur (**D5**) |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | Contrat d'extension du gate (**2 lignes/entité**) |
| `scripts/ci/gate_reserved_keys.dart` (l. 79-120, 812-905) | Règles **(g1)/(g2)/(h)** — celles qui **mordront** sur `content` et sur le barrel |
| `packages/zcrud_document/test/z_document_reading_state_test.dart` | Groupe « AD-19 — clés de sync hors-entité » à reproduire |

### Imports (vérifiés sur disque — ne pas improviser)

- `import 'package:zcrud_annotations/zcrud_annotations.dart';` (annotations `const`)
- `import 'package:zcrud_core/domain.dart';` — surface **pur-Dart** (`ZEntity`, `ZExtensible`, `ZExtension`, `ZSyncMeta`, `ZcrudRegistry`, `ZFieldSpec`)
- ⛔ **Jamais** `package:zcrud_core/zcrud_core.dart` (tire Flutter ⇒ casse `dart test`) · ⛔ **jamais** `package:zcrud_markdown/…` (**D4**)
- `dart:convert` (`jsonDecode`) pour la coercition **D5** — pur-Dart, aucune dépendance.

### Pièges spécifiques à cette story

1. 🔴 **Le portage verbatim de lex EST le bug — DEUX FOIS** : `updatedAt` **inline** (**D2**, R-C réalisé) **et** `content: String` markdown (**D3**, l'ambiguïté d'AD-28).
2. 🔴 **Le repli défensif « naturel » (`[]`) DÉTRUIT le corpus lex** : une note markdown lirait `[]` et le **premier `put` persisterait le vide**. **D5 l'interdit.** C'est la décision la plus importante de la story.
3. 🔴 **`List<Map<String,dynamic>>` en `@ZcrudField` ⇒ BUILD ROUGE** (aucune branche `Map` dans `_classify`). C'est **prévu** (D3), pas un accident à contourner.
4. 🔴 **`kProbeBodies['smart_note']` SANS clé `content`** ⇒ le canal serait « préservé » **par prose** : (f) inerte, (g2) **ROUGE**. C'est le finding **H1** d'ES-2.1.
5. 🔴 **Oublier `hide ZSmartNoteZcrud`** ⇒ **(h) ROUGE** — et, sans le gate, ç'aurait été le finding **H3** (un `copyWith` d'extension qui **détruit** `content`/`extra`/`extension`).
6. 🔴 **Ne PAS mettre d'`assert` dans le constructeur `const`** : le décodeur généré l'appelle avec les valeurs **brutes** ⇒ throw sur donnée corrompue ⇒ **AD-10 violé** (AC9).
7. 🟡 Le `toMap()` **généré** n'étale **pas** `extra` **ni** le canal `content` — l'entité **doit** définir son `toMap()` d'instance.
8. 🟡 `content` **n'aura pas de `ZFieldSpec`** ⇒ absent d'un formulaire généré (**D11**) — le documenter, sinon une revue le prendra pour un oubli.

### Ce que cette story ne fait PAS (frontières explicites)

- ⛔ Édition/lecture (`ZSmartNoteEditor`/`Reader` sur `ZMarkdownField`) → **ES-6.1** (c'est **là** que naît l'arête `zcrud_note → zcrud_markdown`, avec le premier widget).
- ⛔ Migration des tables markdown IFFD + upgrade **riche** des sticky-notes (markdown → Delta **formaté**) → **ES-6.2**. *(D5 garantit seulement que le **texte survit** ; le formatage reste le travail d'ES-6.2.)*
- ⛔ Chemins/collections, `ZStudyRepository`, offline-first, cascade `folder → note` → **ES-3** (AD-20/AD-21).
- ⛔ Mapping legacy IFFD (camelCase, `Timestamp`, `audioText`, `subjectId`/`creatorId`) → **adapter** `zcrud_firestore`, ES-3.5/ES-11.2 (AD-27).
- ⛔ Seam de résumé/audio IA (`ZNoteSummaryPort`) → **ES-9** (port neutre, app-spécifique).

### Divergences IFFD consignées pour ES-11.2 (à ne PAS traiter ici) — **DW-ES22-2**

| Aspect | IFFD | Canonique (lex/zcrud) | Chantier |
|---|---|---|---|
| `content` | `String?` — **Delta JSON OU markdown**, désambiguïsé par heuristique (4 sites) | **ops Delta typées** (`List<Map>`) | **D5** absorbe les deux formes **sans perte** ; rendu riche du markdown ⇒ **ES-6.2** |
| `audioTextHash` | **`int?`** | `String?` (lex) | Coercition `String`\|`num` dans `ZNoteAudio` (**D6**) |
| `audioText` | `String?` | *(absent de lex)* | ⇒ **`extra`** (AD-4) — jamais au schéma partagé |
| `subjectId` / `creatorId` | hérités de `FolderContentModel` | *(absents)* | ⇒ **`extra`** / `ZExtension` |
| Casse & dates | camelCase + `Timestamp` Firestore | snake_case + ISO-8601 | **AD-27** — codec `zcrud_firestore` (faille M3 d'ES-1.3 déjà corrigée) |

### Dettes ouvertes créées par cette story

- **DW-ES22-1 — recouvrement `normalizeNoteContentOps` ↔ `DeltaNeutralOps.asDeltaOps`.** ~20 lignes de coercition pur-Dart existent **deux fois** : dans `zcrud_markdown` (privé, Flutter/Quill, repli **destructeur** `[]`) et dans `zcrud_note` (public, pur-Dart, repli **préservant**). **Ce n'est pas une duplication de CODEC** (AD-28 est respecté : aucune classe `implements ZCodec` n'est créée) mais d'une **primitive de coercition**. **Correctif de fond possible** : hisser la primitive neutre dans `zcrud_core` (pur-Dart, zéro dépendance) et faire consommer `zcrud_markdown` — ⛔ **hors périmètre** (écrit `zcrud_core`, **casserait la parallélisation ES-2**, **D9**). **À statuer en ES-6.1** (quand l'arête `zcrud_note → zcrud_markdown` existera et que les deux repliages devront de toute façon être réconciliés).
- **DW-ES22-2 — mapping legacy IFFD** (table ci-dessus) — dû dans l'**adapter** (ES-3.5/ES-11.2), **jamais** dans le domaine (AD-27).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-2.2`] *(dont la prescription « dépend de `zcrud_markdown` » — **INVALIDÉE**, cf. **D4**)*
- [Source: `_bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md#FR-S5`] (l. 155-159) + table de traçabilité (l. 477) · [NFR-S3, NFR-S4, NFR-S8, NFR-S10 / SM-S5, SM-S6, SM-S7]
- [Source: `.../architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-17, AD-19, AD-19.1, AD-19.1.a, AD-19.1.b, AD-19.1.c (règles (f)/(g1)/(g2)/(h)), AD-26, AD-27, AD-28`]
- [Source: `.../architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1, AD-3, AD-4, AD-5, AD-7, AD-10, AD-16`]
- [Source: `_bmad-output/implementation-artifacts/stories/es-2-1-document-etat-lecture.md`] + [`code-review-es-2-1.md#H1, H2, H3, M1, M2, L2`] — **le précédent direct**
- [Source: `_bmad-output/implementation-artifacts/stories/es-2-0-registry-decode-preserve-extra.md`] + [`code-review-es-2-0.md#H1, H2`]
- [Source: `_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md#§3 R1..R9, §6 R-A..R-H`]
- [Source: `docs/study-integration-inventory.md` l. 101 (schéma de note), l. 191 (heuristique `content`), l. 211, l. 271]
- [Source (READ-ONLY)] `lex_douane/packages/lex_core/lib/domain/entities/education/smart_note.dart` ; `.../domain/repositories/smart_notes_repository.dart`
- [Source (READ-ONLY)] `iffd/lib/src/domain/models/smart_note_model.dart` ; `iffd/lib/data_crud/rich_text_editor_screen.dart` (l. 206, 607) ; `iffd/lib/data_crud/rich_text_editor/delta_to_markdown_helper.dart` (l. 39) ; `.../editors/markdown_edition_field.dart` (l. 68)

---

## Completion Notes

### Résultat

**14/14 ACs satisfaits.** Package `zcrud_note` créé (**17ᵉ** package, pur-Dart), `ZSmartNote` + `ZNoteAudio` + `normalizeNoteContentOps`, harnais du gate câblé **dans la même story**. **104 tests** dans le nouveau package. Vérif verte **repo-wide** : `generate` OK · `analyze` RC=0 · `verify` RC=0 · `prove_gates` **41 OK / 0 FAIL** · `graph_proof` **ACYCLIQUE / CORE OUT=0** · `melos list` = **17**. **Aucune baseline régressée.**

### 🔴 Où j'ai dû REMETTRE LA STORY EN CAUSE

**Une découverte, non anticipée par la story — et attrapée par une machine, pas par moi.**

**`gate:web` (`scripts/ci/gate_web_determinism.dart`) est `default-ON` et découvre `zcrud_note` À SA CRÉATION.** Il rejoue sous `dart test -p node` la suite de **tout** package `packages/*` pur-Dart possédant un `test/`. La story ne le mentionne **nulle part** (ni dans les Dev Notes, ni dans la liste des gates d'AC13, ni dans les fichiers « à LIRE »). Mes trois tests de **politique de source** (grep de `lib/` : anti-`startsWith('[')`, anti-`implements ZCodec`, anti-imports lourds) importent `dart:io` ⇒ **`melos run verify` ROUGE** au premier passage :

```
[gate:web] ÉCHEC : la suite de zcrud_note ne passe pas en JS.
[gate:web] Piste n°2 : un test a-t-il réintroduit `dart:io` sans `@TestOn('vm')` ?
```

Le gate avait **écrit d'avance** la conduite à tenir (« *soit le test est taggé `@TestOn('vm')`, soit le package sort de la cible pour une raison ÉCRITE. On n'ajoute PAS d'opt-out de confort* »). **Correctif appliqué — et il RENFORCE la story** : les 3 tests de source sont **extraits** dans `test/source_policy_test.dart` (`@TestOn('vm')`), ce qui laisse `z_note_content_test.dart` **libre de `dart:io`** ⇒ **la matrice de coercition D5 est désormais rejouée EN JS**. Ça a une valeur réelle et non prévue : `normalizeNoteContentOps` repose sur `jsonDecode`, dont le comportement web est maintenant **observé**, pas supposé.

> ⚠️ **Pour la revue / le prochain `create-story` d'ES-2** : `gate:web` doit figurer dans les gates listés par l'AC de vérif verte, et « un test pur-Dart qui lit le disque doit être `@TestOn('vm')` et **isolé** » doit devenir une note de patron. `ES-2.6` (`zcrud_exam`, pur-Dart) **rejouera exactement ce rouge** sinon.

**Deux auto-morsures de mes propres filets** (signalées parce qu'elles sont instructives) :
1. Le test anti-heuristique (`startsWith('[')`) et le test anti-`implements ZCodec` ont **mordu sur ma propre DARTDOC** — celle-ci **cite verbatim** le code d'IFFD qu'elle interdit, pour expliquer pourquoi zcrud le refuse. ⇒ le grep **dépouille désormais les commentaires** (`_stripComments`), c'est documenté dans le test.
2. `git checkout --` ne restaure **pas** un fichier d'un package **neuf** (non suivi par git) : les injections R3 ont dû être sauvegardées/restaurées par **copie d'octets** (`cp` + `diff -q`). À savoir pour toute story qui crée un package.

**Aucune décision D n'a été contredite par le code réel.** Les trois preuves prescrites ont été **re-vérifiées sur disque** avant d'écrire : lex `smart_note.dart` l. 42 porte bien `final DateTime updatedAt;` **inline** (D2/R-C réalisé) ; lex l. 26-27 persiste `content` en **`String` markdown** (D3/D5) ; IFFD `smart_note_model.dart` l. 1 importe **`cloud_firestore`** et l. 11 déclare `audioTextHash` en **`int?`** (D1/D6). **Aucune source (lex ni IFFD) n'expose une « dernière édition » distincte de l'horodatage de sync** ⇒ conformément à D2, **aucun `edited_at` n'a été inventé**.

### AC12 / R3 — INJECTIONS DE RÉGRESSION : sorties BRUTES (les 4 filets VUS ROUGIR)

Baseline : `dart run scripts/ci/gate_reserved_keys.dart` → **RC=0** (`OK — clés de sync réservées : volet (A) + volet (B) + couverture`).
Restauration par **copie d'octets** (`diff -q` ⇒ **DIFF VIDE**) ; gate **RC=0** re-vérifié après **chacune**.

**① Retrait de `...ZSyncMeta.reservedKeys` de `ZSmartNote._reservedKeys` (R-A)** — **RC=1**, rouge sur les **DEUX** volets :
```
[gate:reserved-keys] ÉCHEC : ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1) — fichier: packages/zcrud_note/lib/src/domain/z_smart_note.dart
  [smart_note] (a) AD-19.1 VIOLÉ : les clés réservées {updated_at, is_deleted} ont été capturées dans `extra`.
00:00 +48 -1: Some tests failed.
[gate:reserved-keys] 2 violation(s) — AD-19.1.
```

**② Retrait de `kContentKey` de `_reservedKeys` (g1 + f)** — *l'injection exacte qui laissait le gate **VERT** avant le correctif H1 d'ES-2.1* — **RC=1**, rouge par **(g1) AST ET (f) comportementale** :
```
[gate:reserved-keys] ÉCHEC : (g1) CANAL HORS-CODEGEN NON RÉSERVÉ : `ZSmartNote.content`
  (packages/zcrud_note/lib/src/domain/z_smart_note.dart) … Sa clé persistée `content` DOIT figurer
  dans les clés RÉSERVÉES de la classe (`_reservedKeys`) …
  [smart_note] (f) CANAL HORS-CODEGEN OUBLIÉ : la/les clé(s) {content} du CORPS DE SONDE ont été
  capturées dans `extra`.
[gate:reserved-keys] 2 violation(s) — AD-19.1.
```

**③ Retrait de la clé `content` de `kProbeBodies['smart_note']` (g2)** — **RC=1** :
```
[gate:reserved-keys] ÉCHEC : (g2) CANAL DÉCLARÉ, JAMAIS SONDÉ : `ZSmartNote.content` … est un canal
  hors-codegen de clé `content`, mais `kProbeBodies['smart_note']` NE LA PORTE PAS
  (tool/reserved_keys_gate/lib/src/registrars.dart).
[gate:reserved-keys] 1 violation(s) — AD-19.1.
```

**④ Export de `ZSmartNoteZcrud` (retrait du `hide`) (h)** — **RC=1** :
```
[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : `ZSmartNoteZcrud` est exposée par le
  point d'entrée public `packages/zcrud_note/lib/zcrud_note.dart` (`export 'src/domain/z_smart_note.dart';`
  sans `hide`), alors que `ZSmartNote` est `ZExtensible`.
[gate:reserved-keys] 1 violation(s) — AD-19.1.
```

**Restauration finale vérifiée** : les 3 fichiers touchés sont **identiques à l'octet** à leur sauvegarde, gate **RC=0**.

### Vérif verte repo-wide (rejouée réellement)

| Contrôle | Résultat |
|---|---|
| `melos run generate` | **SUCCESS** |
| `melos run analyze` (repo-wide) | **SUCCESS**, RC=0 |
| `melos run verify` (tous les gates) | **RC=0** — dont `gate:graph`, `gate:codegen`, `gate:codegen-distribution`, **`gate:web`**, **`gate:reserved-keys`** |
| `scripts/ci/prove_gates.dart` | **41 OK, 0 FAIL** (aucune régression) |
| `scripts/dev/graph_proof.py` | 17 nœuds — **ACYCLIQUE OK / CORE OUT=0 OK** |
| `melos list` | **17** (16 → 17) |
| `gate:codegen-distribution` | `zcrud_note` listé, **0 gitignoré** — le `.g.dart` est **suivi par git** |

**Compteurs de tests — aucune baseline régressée :**

| Package | Avant | Après |
|---|---|---|
| `zcrud_note` | — | **104** (nouveau) |
| `tool/reserved_keys_gate` | 46 | **49** (+3 : les boucles génériques par kind ont pris `smart_note` — **zéro test écrit à la main**, c'est (f)/(g) qui font le travail) |
| `zcrud_document` | 129 | **129** |
| `zcrud_generator` | 102 | **102** |
| `zcrud_flashcard` | 189 | **189** |
| `zcrud_study_kernel` | 108 | **108** |
| `zcrud_core` | 911 | **911** |
| `zcrud_firestore` | 90 | **90** |
| `zcrud_mindmap` | 110 | **110** |

### Confirmation de périmètre (AC14 — parallélisation PRÉSERVÉE)

✅ **Aucune ligne de `zcrud_core`, `zcrud_study_kernel`, `zcrud_document`, `zcrud_flashcard`, `zcrud_markdown`, `zcrud_mindmap`, `zcrud_firestore` n'a été écrite.**
✅ Les **seuls** fichiers touchés hors `packages/zcrud_note/` : root `pubspec.yaml` (bloc `workspace:` + commentaire 16→17), `tool/reserved_keys_gate/pubspec.yaml`, `tool/reserved_keys_gate/lib/src/registrars.dart` — **exactement** ce qu'autorise AC14.
✅ `kNonExtensibleKinds` **inchangé** · `kLegacyUpdatedAtMirrors` **inchangé** (`{study_folder, flashcard}`, verrou vert) · `manual_probes.dart` **non touché** (D6 : `ZNoteAudio` n'est ni `@ZcrudModel` ni `ZExtensible` ⇒ hors `E_disk`/`R_disk`).
✅ `melos.yaml` **non modifié** (D10 — glob `packages/**`) ; `gate:melos` vert.
✅ **Lecture seule** sur `lex_douane` et `iffd` (aucun fichier touché).
✅ **Aucun widget, aucune `presentation/`, aucun port/dépôt, aucun adaptateur de migration.**

### Dettes

- **DW-ES22-1 — recouvrement `normalizeNoteContentOps` ↔ `DeltaNeutralOps.asDeltaOps` : OUVERTE, non soldée (délibérément).** ~20 lignes de coercition pur-Dart existent deux fois : dans `zcrud_markdown` (privé, Flutter/Quill, repli **destructeur** `[]`) et dans `zcrud_note` (public, pur-Dart, repli **préservant**). **Ce n'est pas une duplication de CODEC** — **AD-28 est respecté** : aucune classe `implements ZCodec` n'est créée (**assertion machine**, `source_policy_test.dart`). Le correctif de fond (hisser la primitive dans `zcrud_core`) **écrirait `zcrud_core`** ⇒ **casserait la parallélisation ES-2** ⇒ **D9 : je me suis ARRÊTÉ et je le SIGNALE**, je ne l'ai pas fait. **À statuer en ES-6.1.**
- **DW-ES22-2 — mapping legacy IFFD** (camelCase, `Timestamp`, `audioText`, `subjectId`/`creatorId`, `audioTextHash: int`) : dû dans l'**adapter** (`zcrud_firestore`, ES-3.5/ES-11.2), **jamais** dans le domaine (AD-27). La divergence de type `audioTextHash` (`String` lex / `int` IFFD) est **absorbée dès aujourd'hui** par `ZNoteAudio._asTextHash` (`String` | `num` → `String?`), testée.

### Notes de conception (pour la revue)

- **`ZNoteAudio` est le premier `ZExtension` concret du repo** (AD-4 pt.1 n'avait **jamais** été exercé). Le filet a été **fait mordre** : `fromJsonSafe` est testée sur `null`, non-map, `format_version` absente / `99` / non numérique, champs individuellement corrompus, map à clés non-`String` — **jamais de throw, jamais de perte silencieuse**, et le **parent survit toujours**.
- **`content` n'a PAS de `ZFieldSpec`** (D11) : c'est **assumé et documenté en dartdoc** (assertion machine dans le test), pour qu'une revue ne le prenne pas pour un oubli. L'éditeur d'ES-6.1 ajoutera son `ZMarkdownField` **explicitement** — **sans conversion** (identité de type avec la valeur neutre de `ZCodec`, prouvée par test).
- **AC9 / H2 tenu** : `normalizeNoteContentOps` est **la même fonction nommée** appelée par `fromMap` **ET** `copyWith`. Test dédié : `note.copyWith(content: [{'retain': 1}])` ⇒ ops normalisées (`[]`), **jamais persistées telles quelles**. **Aucun `assert` dans le constructeur `const`** (AD-10 : le décodeur généré l'appelle avec les valeurs brutes).

---

## File List

**Nouveaux — `packages/zcrud_note/` (17ᵉ package, pur-Dart) :**
- `packages/zcrud_note/pubspec.yaml`
- `packages/zcrud_note/lib/zcrud_note.dart` *(barrel — `hide ZSmartNoteZcrud`)*
- `packages/zcrud_note/lib/src/domain/z_smart_note.dart`
- `packages/zcrud_note/lib/src/domain/z_smart_note.g.dart` *(**généré**, suivi par git)*
- `packages/zcrud_note/lib/src/domain/z_note_content.dart`
- `packages/zcrud_note/lib/src/domain/z_note_audio.dart`
- `packages/zcrud_note/test/z_smart_note_test.dart`
- `packages/zcrud_note/test/z_note_content_test.dart`
- `packages/zcrud_note/test/z_note_audio_test.dart`
- `packages/zcrud_note/test/source_policy_test.dart` *(`@TestOn('vm')`)*

**Modifiés (les SEULS hors du package — AC14) :**
- `pubspec.yaml` *(racine : bloc `workspace:` + commentaire 16 → 17)*
- `tool/reserved_keys_gate/pubspec.yaml` *(`zcrud_note: ^0.1.0`)*
- `tool/reserved_keys_gate/lib/src/registrars.dart` *(`kRegistrars` += `registerZSmartNote` ; `kProbeBodies['smart_note']` avec `content` **NON VIDE**)*

## Change Log

| Date | Changement |
|---|---|
| 2026-07-13 | ES-2.2 implémentée : `zcrud_note` (17ᵉ package, **pur-Dart**), `ZSmartNote` à **contenu TYPÉ** (ops Delta neutres, canal hors-codegen), `normalizeNoteContentOps` (**coercition D5 préservante — le texte legacy n'est JAMAIS détruit**), `ZNoteAudio` (**1er `ZExtension` concret du repo**). Harnais `reserved-keys` câblé **dans la même story** (R8). 4 injections de régression **vues rougir** puis restaurées. Statut → `review`. |
| 2026-07-13 | Correctif non prévu par la story : `gate:web` (default-ON) rejoue la suite pur-Dart en JS ⇒ tests `dart:io` **extraits** dans `source_policy_test.dart` (`@TestOn('vm')`) — la matrice D5 est désormais **rejouée en JS**. |

