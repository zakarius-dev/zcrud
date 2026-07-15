---
baseline_commit: 6d8694227a8134f0f0ddac4f8dc6a98338da7701
---

# Story ES-2.8 : Podcast content-addressed (`ZStudyPodcast` + invalidation par `sourceHash`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur du domaine study zcrud**,
I want **modéliser dans le noyau `zcrud_study_kernel` une entité `ZStudyPodcast` (`ZEntity` + `ZExtensible`, `@ZcrudModel`) — référence *content-addressed* d'un podcast généré, rattachée à une source d'étude (note / dossier / document) et à un mode de synthèse — dont l'identité est déterministe (`{sourceId}_{mode}`) et dont l'invalidation de cache repose EXCLUSIVEMENT sur la comparaison PURE de son `sourceHash` (fourni par l'appelant, JAMAIS calculé par le kernel) contre le hash de la source courante**,
so that **le cache de podcast soit invalidable de façon TOTALE, PURE et DÉTERMINISTE (`isStale(currentSourceHash)` / `ZPodcastFreshness`) sans que le kernel n'acquière AUCUNE dépendance crypto (fermeture transitive minimale `{zcrud_core, zcrud_annotations}` — NFR-S10/SM-S7), sans horodatage de sync inline (AD-19), et sans switch enum figé — le port de GÉNÉRATION du podcast restant un seam d'app (FR-S31 / ES-9.3).**

## Contexte & source de vérité

- **FR couverte** : **FR-S11** — « Podcast content-addressed (`ZStudyPodcast`), invalidation par `sourceHash`. » [Source: epics-zcrud-study-2026-07-12/epics.md#FR-S11 l.468-482, table de traçabilité l.115]
- **Épic** : **ES-2** (Domaine canonique éducatif + codegen). **DERNIÈRE story de l'epic ES-2.** **Dépend de** : ES-1 (kernel + `ZSyncMeta` + `gate:web` default-ON + AST purity harness), ES-2.0 (`registry.decode` préserve `extra` — socle codegen des entités `ZExtensible`), ES-2.2b (gardes `extra` systémiques MESURÉES — patron `ZExtensible` INTÉGRAL), ES-2.6 (`ZExam` : précédent enum + `DateTime?` ISO-8601 codegen-able + entité `ZExtensible` livrée). [Source: epics.md l.336 ; sprint-status.yaml l.256-266 ; séquencement l.144-172]
- **Package cible** : **kernel existant** `packages/zcrud_study_kernel/` (pur-Dart, comme ES-2.3/2.4/2.7). Fichiers NEUFS : `lib/src/domain/{z_study_podcast.dart, z_podcast_source_kind.dart, z_podcast_mode.dart, z_podcast_status.dart, z_podcast_freshness.dart}` + `z_study_podcast.g.dart` (**généré**, committé) + tests + mise à jour du barrel + `hide` `zcrud_flashcard` + surface-guard + câblage du gate `reserved-keys`. [Source: epics.md l.474 « `packages/zcrud_study_kernel/lib/src/domain/z_study_podcast.dart` »]
- **Parallélisation** : **SÉQUENTIELLE — la story ÉCRIT le kernel** (`zcrud_study_kernel`). Aucune fenêtre de parallélisation avec une autre story touchant le kernel. Elle N'écrit PAS `zcrud_core` (elle consomme uniquement `package:zcrud_core/domain.dart`). Elle touche le **harnais partagé** `tool/reserved_keys_gate/` (registrars/probe/writers — R8) mais **PAS** deux écritures concurrentes. **NE TOUCHE PAS au sprint-status** (édition ciblée réservée à l'orchestrateur). [Source: sprint-status.yaml l.266 « [S][SÉQ — écrit kernel] ZStudyPodcast (sourceHash) » ; CLAUDE.md « Règles générales »]
- **Taille** : **S** (une entité codegen-able « plate » + 3 enums de faible cardinalité + 1 enum de fraîcheur + une méthode d'invalidation PURE ; aucun canal hors-codegen à câbler — voir D5).

### 🔴 Source lex PORTÉE (et à DIVERGER) — lecture RÉELLE du disque (R4/R-G)

`lex_douane` est **présent** sur ce poste. La forme canonique est portée de `lex_core` (module « Étude », story lex 17.2 / FR-55), LUE réellement :

1. **`StudyPodcast`** (`packages/lex_core/lib/domain/entities/education/study_podcast.dart` l.21-112) : `@JsonSerializable(fieldRename: snake)`, champs `{id, sourceKind: PodcastSourceKind, sourceId, folderId, mode: PodcastMode, sourceHash, resultRef, status: PodcastStatus, createdAt: DateTime, updatedAt: DateTime, isDeleted: bool}`, `copyWith` manuel, `static String buildId(sourceId, mode) => '${sourceId}_${mode.name}'`. Dartdoc lex : *« Content-addressed : l'identité repose sur le couple (sourceId, mode) ; `sourceHash = sha256(normalizeAudio(sourceContent))` est la clé d'invalidation (un `sourceHash` différent ⇒ podcast obsolète). Seul un podcast `ready` est persisté. »*
2. **Enums** — `PodcastSourceKind {note, folder, document}` (fallback défensif `note`), `PodcastMode {simple, dialogue}` (fallback `simple`), `PodcastStatus {pending, processing, ready, failed, stale}` (**`fromJson` défensif → `ready`**), et `PodcastFreshness {absent, fresh, stale}`. [Source: enums/podcast_source_kind.dart, podcast_mode.dart, podcast_status.dart]
3. **`podcastFreshness(...)`** (`utils/podcast_audio_access.dart` l.144-158) : fonction **PURE** — `{required String? storedHash, required String currentSourceContent}` → `PodcastFreshness`. Contrat : `storedHash` null/vide → `absent` ; sinon `computePodcastSourceHash(currentSourceContent) == storedHash ? fresh : stale`. **Le hash de la source courante est calculé APP-SIDE** (`computeAudioTextHash`, miroir SHA-256 du backend `podcast_service.compute_source_hash`), puis **COMPARÉ** au hash mémorisé. *« Dérive PodcastFreshness purement du hash. »*

**⚠️ DÉCISION STRUCTURANTE CENTRALE (R4/R-G) — le kernel COMPARE, ne CALCULE JAMAIS le hash.** lex calcule `sourceHash` par **SHA-256** (backend `compute_source_hash`, miroir app `computeAudioTextHash`). Le prompt d'orchestration et NFR-S10/SM-S7 **INTERDISENT `package:crypto`/SHA-256 dans le kernel** (précédent verrouillé : `ZColorPalette`/`remapColorKey` d'ES-2.3 rejette `package:crypto` — *« ⛔ jamais `package:crypto` dans le kernel »*). ⇒ Le kernel adopte l'option **(a)** du prompt : **`sourceHash` est un `String` OPAQUE FOURNI par l'appelant** (calculé en amont par le seam de génération / le binding — SHA-256 côté lex, préservant la parité backend SANS que le kernel n'acquière crypto). L'invalidation est une **COMPARAISON PURE** (`podcast.sourceHash != currentSourceHash`). Le kernel **ne hashe rien** — ni `crypto`, ni `zFnv1a32` : il n'y a **aucun calcul de hash dans cette story**. Le hashing du contenu source est un **seam de présentation/data** (ES-9.3 `ZPodcastGenerationPort` / ES-10 binding), pas un concern du domaine (AD-4 : extension par injection).

### 🔴 DIVERGENCES vs source lex (portées, documentées)

- **AD-19 — `updated_at` / `is_deleted` EXTRAITS hors-entité** (comme ES-2.5 `ZDocumentAnnotation` a extrait son `isDeleted` inline). lex porte `updatedAt`/`isDeleted` **INLINE** dans l'entité ; zcrud les **RETIRE** : la fraîcheur LWW et le soft-delete vivent dans `ZSyncMeta` (STORE, hors-entité). `createdAt` reste une clé **MÉTIER** distincte. `_reservedKeys ⊇ ZSyncMeta.reservedKeys`. [Source: es-2-5, AD-16/AD-19 ; canonical-schema.md §2.3 « Mindmap : metadonnees de sync HORS-ENTITE »]
- **Enum defensif via codegen** — zcrud n'écrit pas de `fromJson` manuel sur l'enum : le générateur émet `_$enumFromName(T.values, raw) ?? T.values.first` pour un champ enum non-nullable sans `defaultValue` (précédent `ZDocumentStatus`/`ZStudyDocument.status`). **⇒ le fallback défensif est la 1ʳᵉ constante déclarée** — l'ordre de déclaration est **NORMATIF** (D3).
- **`id` nullable (AD-14)** — lex a `id` **required non-null** (déterministe `{sourceId}_{mode}`). zcrud garde `id: String?` `@ZcrudId` (jamais assigné par l'entité, matérialisé au repository) **et** fournit le helper PUR `ZStudyPodcast.buildId(sourceId, mode)` que le repo appelle pour matérialiser l'identité *content-addressed* (D2).

### Ce que cette story ne livre PAS

- **Aucun calcul de hash** (ni `crypto`, ni `zFnv1a32`) : le kernel COMPARE des `String` opaques (décision centrale). [Source: NFR-S10/SM-S7 ; z_color_palette.dart D2]
- **Aucun port de génération, aucun TTS, aucun accès audio** : `ZPodcastGenerationPort` / la résolution du blob audio (`resultRef → URL`) sont **ES-9.3** (seam FR-S31). Cette story livre la **référence** *content-addressed* + son invalidation PURE, rien de la génération. [Source: epics.md ES-9.3 l.369 ; FR-S31]
- **Aucun widget, aucun provider Riverpod/GetX, aucun player** : la surface podcast (mode-sheet, player) est **ES-5/ES-9/ES-10**. [Source: AD-2/AD-15]
- **Aucune persistance / repository / cascade** : la persistance de `ZStudyPodcast` (sous-collection `study_podcasts`, LWW, soft-delete) est **ES-3.x**. Cette story livre le **round-trip `Map` in-memory** (`toMap`/`fromMap`) + le câblage `registry.decode`, rien de plus. [Source: epics.md ES-3]
- **Aucun `ZTypeRegistry`/registre de variants** : `sourceKind`/`mode`/`status` sont des enums FERMÉS de faible cardinalité (parité lex) ; l'ouverture éventuelle passe par `@JsonKey(unknownEnumValue)` + `extra`/`ZExtension` (AD-4), pas par un registre de variants.
- **Aucune modification de `ZExam`/`zcrud_exam`/`zcrud_flashcard`** au-delà de la mise à jour de la **liste `hide`** + surface-guard de `zcrud_flashcard` (obligatoire, D6).

## Décisions structurantes (tranchées PAR LECTURE — R4/R-G)

- **D1 — `ZStudyPodcast` = `ZEntity` + `ZExtensible`, `@ZcrudModel(kind: 'study_podcast')`, patron ES-2.2b INTÉGRAL.** C'est un **contenu personnel top-level à identité propre** (référence de podcast persistable, comme `ZExam`/`ZStudyDocument`) ⇒ entité codegen `ZExtensible`, PAS un value-object pur (contraste `ZStudySessionResult` d'ES-2.7). Patron ES-2.2b **jumeau strict de `ZExam`/`ZFlashcardTag`** : constructeur `const` qui **ne filtre RIEN** (`: _extra = extra`), slot brut `_extra` **lu nulle part ailleurs**, accesseur `extra` **normalisant** (`zNormalizeExtra`, le SEUL point traversé par TOUTES les voies), garde partagée `_sanitizeExtra` (`fromMap` **ET** `copyWith`), `toMap()` étalant l'**ACCESSEUR** `...extra` (jamais `_extra` brut), `copyWith` **à sentinelle** couvrant TOUS les champs (y compris `extension`/`extra` que le `copyWith` **généré** remettrait aux défauts → perte silencieuse H3), égalité **PROFONDE** `zJsonEquals`/`zJsonHash` sur `extra`. `fromMap` **NON-déléguante-nue** (délègue à `_$ZStudyPodcastFromMap` pour les champs de schéma PUIS câble `extension` + `extra`). [Source: z_exam.dart l.78-294 ; z_flashcard_tag.dart ; z_study_document.dart]
- **D2 — Identité *content-addressed* : `id: String?` nullable (AD-14) + helper PUR `buildId`.** `id` reste `@ZcrudId final String? id` (jamais assigné par l'entité, matérialisé au repository ES-3/ES-9.3). L'identité déterministe `{sourceId}_{mode}` est exposée par un **static PUR, TOTAL, DÉTERMINISTE** `static String ZStudyPodcast.buildId(String sourceId, ZPodcastMode mode) => '${sourceId}_${mode.name}'` (parité lex `buildId`). **Pouvoir discriminant OBSERVÉ** (R2) : `(s1, simple)` ≠ `(s1, dialogue)` ≠ `(s2, simple)` produisent trois ids distincts. [Source: study_podcast.dart l.77-79 ; canonical-schema.md « IDs = String opaques ; nullable pour l'éphémère »]
- **D3 — Trois enums FERMÉS, ordre de déclaration NORMATIF (fallback = `T.values.first`).** `ZPodcastSourceKind {note, folder, document}`, `ZPodcastMode {simple, dialogue}`, `ZPodcastStatus {ready, pending, processing, failed, stale}`. Le générateur zcrud décode un enum non-nullable **par NOM** avec repli `_$enumFromName(T.values, raw) ?? T.values.first` (précédent `ZDocumentStatus` : *« L'ORDRE DE DÉCLARATION EST NORMATIF … la 1ʳᵉ constante déclarée EST le défaut »*). ⇒ la **1ʳᵉ constante = le fallback défensif** :
  - `ZPodcastSourceKind` : **`note` en tête** (parité lex `fromJson → note`) ;
  - `ZPodcastMode` : **`simple` en tête** (parité lex `fromJson → simple`, mode par défaut du contrat backend) ;
  - `ZPodcastStatus` : **`ready` en tête** (⚠️ DIVERGE de l'ordre lex `pending, processing, ready, …` MAIS PRÉSERVE la sémantique de repli lex `fromJson → ready`). Rationale (comme le D5 de `ZDocumentStatus`, mais fallback inversé) : **seul un podcast `ready` est persisté durablement** (`failed`/`stale`/`pending`/`processing` sont transitoires) ⇒ toute valeur inconnue/corrompue lue depuis le store est, par construction, une référence *ready*. Replier sur `pending`/`processing` afficherait un spinner perpétuel ; sur `failed` masquerait un podcast valide ; sur `stale` déclencherait une régénération inutile ; **`ready` ne ment ni ne détruit rien** et colle à lex. **Réordonner ces enums change SILENCIEUSEMENT le comportement défensif** → chaque enum porte cette dartdoc + un test épinglant le fallback.
- **D4 — Invalidation = COMPARAISON PURE, jamais de calcul (décision centrale).** Le kernel NE hashe RIEN. Deux surfaces PURES, TOTALES, DÉTERMINISTES :
  - **méthode d'instance** `bool ZStudyPodcast.isStale(String currentSourceHash) => sourceHash != currentSourceHash` — `true` ssi les deux empreintes diffèrent ;
  - **enum de fraîcheur** `ZPodcastFreshness {absent, fresh, stale}` (parité lex) + fonction **top-level PURE** `ZPodcastFreshness podcastFreshness({String? storedHash, String? currentSourceHash})` : `storedHash` null/vide → `absent` ; sinon `storedHash == currentSourceHash ? fresh : stale`. **Politique documentée et TOTALE** pour les bords (jamais de throw, jamais de `null!`) : `currentSourceHash` null/vide avec un `storedHash` non vide → `stale` (empreintes différentes) ; deux vides → `absent`. **Aucune horloge, aucun `DateTime.now()`** (contraste `ZExam` : l'invalidation *content-addressed* ne dépend PAS du temps — c'est le point de FR-S11). [Source: podcast_audio_access.dart l.144-158 ; podcast_status.dart `PodcastFreshness`]
- **D5 — AUCUN canal hors-codegen (contraste ES-2.2/2.4/2.6).** **TOUS** les champs de `ZStudyPodcast` sont **codegen-ables** : 3 `String` (`sourceId`/`sourceHash`/`resultRef`), 1 `folderId` `String`, 3 enums (`select`), 1 `DateTime?` ISO-8601 (`createdAt`). **Aucun `Map`/sous-modèle typé** (pas de `content`/`learning`/`section_orders`/`reminderTime`). ⇒ la règle **(g1)/(g2)** du gate `reserved-keys` (canal hors-codegen non réservé) **ne s'applique PAS** ici (comme `ZDocumentAnnotation` d'ES-2.5, tous champs codegen-ables). `_reservedKeys = {champs de $ZStudyPodcastFieldSpecs} ∪ {'extension'} ∪ ZSyncMeta.reservedKeys`. **⚠️ Piège à éviter** : n'introduire **AUCUN champ non annoté** (`@ZcrudField`/`@ZcrudId`) — un champ nu serait détecté par la règle (g) comme canal hors-codegen non réservé et ferait ROUGIR le gate.
- **D6 — Surface publique : `hide ZStudyPodcastZcrud` (règle (h)) + `hide` côté `zcrud_flashcard` + surface-guard.** L'extension GÉNÉRÉE `ZStudyPodcastZcrud` (son `copyWith`/`toMap` remettrait `extra`/`extension` aux défauts → perte silencieuse H3) est **masquée** dans le barrel kernel : `export 'src/domain/z_study_podcast.dart' hide ZStudyPodcastZcrud;`. Les enums (`ZPodcastSourceKind`/`ZPodcastMode`/`ZPodcastStatus`/`ZPodcastFreshness`) et la fonction `podcastFreshness` sont **exportés SANS `hide`** (enums purs, aucune extension générée — précédent `ZReviewMode`). Tous ces symboles sont **study-niveau, NON pertinents flashcard** ⇒ **ajoutés à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (précédent EXACT `ZFolderContentsOrder`/ES-2.7) et **classés NON-flashcard** dans `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (un symbole kernel non classé fait ÉCHOUER ce test — fuite silencieuse impossible). [Source: zcrud_flashcard.dart l.57-80 ; z_kernel_surface_guard_test.dart]
- **D7 — Câblage du gate `reserved-keys` DANS LA MÊME STORY (R8) — contrat « 3 lignes » (registrar + probe + writers).** Dans `tool/reserved_keys_gate/lib/src/registrars.dart` :
  1. `kRegistrars += registerZStudyPodcast` ;
  2. `kProbeBodies['study_podcast']` = corps métier **minimal valide** (voir AC12) ;
  3. `kExtraWriters['study_podcast'] = [ZExtraWriter(voie:'ctor', write:_ctorStudyPodcast, eagerlyNormalized:false), ZExtraWriter(voie:'copyWith', write:_copyWithStudyPodcast, eagerlyNormalized:true)]` + les fonctions `_ctorStudyPodcast`/`_copyWithStudyPodcast` transmettant `extra` **VERBATIM** (règle (k)).
  `ZStudyPodcast` **EST `ZExtensible`** ⇒ **PAS** dans `kNonExtensibleKinds`, **PAS** dans `kExtensionPayloadPreservers` (elle n'utilise pas de `ZExtension` concret), **PAS** dans `kNoValueEqualityProbes` (elle a un `==` de valeur profond). ⛔ **NE TOUCHE PAS `kLegacyUpdatedAtMirrors`** (`ZStudyPodcast` n'émet JAMAIS `updated_at` — AD-19). Le pubspec du gate dépend **déjà** du kernel (aucun ajout). Le `import 'package:zcrud_study_kernel/...'` est déjà présent. [Source: registrars.dart l.65-529 ; gate_reserved_keys.dart]
- **D8 — `gate:web` DEFAULT-ON + littéraux JS-safe, ZÉRO `dart:io` non annoté.** Les tests kernel tournent sous `dart test` **ET** `dart test -p node` (`melos run verify`). Construire tout `DateTime` de test via `DateTime.utc(2026, 7, 20)` (arguments explicites, JS-safe) — **jamais** `DateTime.now()`. **Aucune fonction horloge-dépendante n'est introduite** (l'invalidation est *content-addressed*, sans temps) ⇒ **aucun nouveau gate anti-`DateTime.now()` requis** pour cette story ; le harnais kernel existant (`no_datetime_now_test.dart`, ES-2.7, `@TestOn('vm')`) scanne déjà `lib/**` et DOIT rester vert (ne pas introduire de `DateTime.now()`). [Source: z_color_palette.dart D2 ; es-2-7 D8/D9]
- **D9 — Défensif TOTAL (AD-10), jamais de throw.** `ZStudyPodcast.fromMap(const <String,dynamic>{})` **ne throw JAMAIS** : `source_id`/`folder_id`/`source_hash`/`result_ref` absents → `''` ; enums inconnus/absents → fallback D3 ; `created_at` illisible → `null` ; `id` absent → `null` ; `extension` corrompue → `null` (`ZExtension.guard`) ; `extra` = clés non réservées. `buildId` totale (jamais de `null!`). `isStale`/`podcastFreshness` totales (bords documentés D4). **AUCUN `assert` dans le constructeur `const`** (le décodeur généré l'appelle avec des valeurs BRUTES — un `assert` ferait échouer la désérialisation d'une donnée corrompue, violation frontale AD-10). Les gardes vivent **exclusivement aux frontières** `fromMap`/`copyWith`, garde `extra` = **MÊME fonction nommée** `_sanitizeExtra` (leçon H2). [Source: AD-10 ; z_exam.dart l.79-92]

## Acceptance Criteria

> **Motif dominant du projet à contrer** : « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. Aucune quantité de vert ne détecte un faux vert ; seul un rouge provoqué le peut. » ⇒ Chaque garde/gate naît avec **sa fixture d'échec ISOLÉE (R2)** + son **injection de régression rejouable (R3)**. AST, jamais regex naïf (R5). Aucune dégradation silencieuse (R6). **⚠️ Leçons fraîches** : (ES-2.3) un golden de hash peut PASSER PAR COÏNCIDENCE ⇒ prouver que `isStale`/`podcastFreshness` **dépendent RÉELLEMENT des deux empreintes** (source A ≠ source B ⇒ invalidation, PROUVÉ, pas fortuit) ; (ES-2.5/DW-ES25-1) **aucun test de non-export powerless** — le surface-guard doit ROUGIR quand on retire le symbole du `hide` ; (ES-2.6) hash/horloge injecté jamais `crypto`/`DateTime.now()` — **ici le kernel ne hashe NI ne lit l'horloge du tout**, à PROUVER par la fermeture de dépendances + l'absence de `DateTime.now()`.

### `ZStudyPodcast` — entité `ZExtensible` codegen, round-trip défensif

**AC1.** `ZStudyPodcast` est une classe `@ZcrudModel(kind: 'study_podcast')` dans `lib/src/domain/z_study_podcast.dart`, **`extends ZEntity with ZExtensible`** (D1), au patron ES-2.2b INTÉGRAL (jumeau `ZExam`). Constructeur nominal **`const`** `: _extra = extra` (aucun filtre, aucun `assert`). Champs déclarés (tous **`@ZcrudField`/`@ZcrudId`** — D5, **aucun champ nu**) : `@ZcrudId final String? id` (défaut `null`) ; `final ZPodcastSourceKind sourceKind` (défaut `ZPodcastSourceKind.note`) ; `final String sourceId` (défaut `''`) ; `final String folderId` (défaut `''`, **clé NEUTRE — aucun import kernel/satellite**) ; `final ZPodcastMode mode` (défaut `ZPodcastMode.simple`) ; `final String sourceHash` (défaut `''`, **empreinte OPAQUE, jamais calculée ici**) ; `final String resultRef` (défaut `''`) ; `final ZPodcastStatus status` (défaut `ZPodcastStatus.ready`) ; `final DateTime? createdAt` (défaut `null`, clé MÉTIER ISO-8601, **DISTINCTE de toute clé de sync**) ; `final ZExtension? extension` ; `final Map<String,dynamic> _extra` (accesseur `extra` normalisant). L'entité **n'importe QUE** `package:zcrud_annotations/zcrud_annotations.dart` + `package:zcrud_core/domain.dart` + ses enums relatifs — **aucun Flutter, aucun `dart:ui`, aucun satellite** (NFR-S3/SM-S5).

**AC2.** **`factory ZStudyPodcast.fromMap(Map<String,dynamic> map, {ZStudyPodcastExtensionParser? extensionParser})` défensive, TOTALE, NON-déléguante-nue (AD-10, D1/D9)** : délègue à `_$ZStudyPodcastFromMap(map)` pour les champs de schéma (défauts sûrs), PUIS câble `extension: _decodeExtension(map['extension'], extensionParser)` (repli `null`, `ZExtension.guard`) et `extra: _extraFrom(map)` (clés non réservées). `ZStudyPodcast.fromMap(const <String,dynamic>{})` **ne throw JAMAIS** et rend les défauts (`id==null`, `sourceKind==note`, `mode==simple`, `status==ready`, `sourceId/folderId/sourceHash/resultRef==''`, `createdAt==null`, `extra=={}`). Corps **NON NU** obligatoire (le build REFUSE une délégation nue via `_rejectNakedCodegenDelegation` ; le garde runtime `_$zRequireExtraPreserved` lèverait à l'enregistrement).
  - **Fixture d'échec ISOLÉE (R2)** : `fromMap({'source_kind':'zzz','mode':'zzz','status':'zzz','created_at':'pas-une-date'})` → `sourceKind==note, mode==simple, status==ready, createdAt==null` (aucun throw).
  - **Injection de régression (R3)** : remplacer le repli enum par un cast dur (`map['status'] as ...`) ⇒ `fromMap({'status':'zzz'})` throw, un test ROUGIT.

**AC3.** **`toMap()` zéro-perte (snake_case, enums camelCase `name`)** réutilise `ZStudyPodcastZcrud(this).toMap()` puis superpose `...extra` (l'**ACCESSEUR** qui NORMALISE, jamais `_extra` brut) et `extension` (`if (extension != null) map['extension'] = extension!.toJson()`). **Round-trip idempotent** : `ZStudyPodcast.fromMap(p.toMap()) == p` (égalité de valeur profonde). `toMap()` ne produit **JAMAIS** `updated_at`/`is_deleted` (garanti : `_reservedKeys ⊇ ZSyncMeta.reservedKeys` — AD-16/AD-19).
  - **Pouvoir discriminant OBSERVÉ (anti-golden-fortuit, R2)** : fixture `sourceKind: document, mode: dialogue, sourceHash: 'h-A', status: failed, createdAt: DateTime.utc(2026,7,20)` — round-trip `==`. **Faire VARIER `sourceHash` → 'h-B'** rend les deux instances **INÉGALES** (prouve que `==` dépend RÉELLEMENT de `sourceHash`, pas un `true` fortuit).
  - **Injection de régression (R3)** : omettre `source_hash` de la sérialisation généré/round-trip ⇒ le round-trip perd l'empreinte, un test ROUGIT.

**AC4.** **`copyWith` à sentinelle (`_$undefined`)** couvre **TOUS** les champs (`id, sourceKind, sourceId, folderId, mode, sourceHash, resultRef, status, createdAt, extension, extra`). Un argument omis préserve la valeur ; `null` explicite remet à `null` (pour les nullables `id`/`createdAt`/`extension`). `extra` passe par **`_sanitizeExtra`** — la **MÊME fonction nommée** qu'en `fromMap` (H2 : `copyWith` ne peut pas ROUVRIR le filtre des clés réservées). Le `copyWith` **généré** (`ZStudyPodcastZcrud`) est **masqué** (D6).
  - **Fixture d'échec ISOLÉE (R2)** : `p.copyWith(sourceHash: 'h-B')` change `sourceHash` et **préserve** tout le reste (`id`/`mode`/`extra`) ; `p.copyWith(createdAt: null)` remet `createdAt` à `null`.
  - **Injection de régression (R3)** : dans `copyWith`, passer `extra` VERBATIM (retirer `_sanitizeExtra`) ⇒ `p.copyWith(extra: {'is_deleted': true})` laisse fuiter `is_deleted` dans `extra`/`toMap`, un test ROUGIT.

**AC5.** **Gardes `extra` ES-2.2b MESURÉES (patron `ZExam`/`ZFlashcardTag`)** : l'accesseur `extra` **NORMALISE** (`zNormalizeExtra(_extra, _reservedKeys)`) sur **TOUTES** les voies, y compris le constructeur `const` (seule voie incapable de filtrer). `_reservedKeys` = `{spec.name for $ZStudyPodcastFieldSpecs} ∪ {'extension'} ∪ ZSyncMeta.reservedKeys`. Égalité **PROFONDE** `zJsonEquals(extra, other.extra)` / `zJsonHash(extra)` (JSON imbriqué — DW-ES22-4). `==`/`hashCode` couvrent tous les champs métier + `extension` + `extra`.
  - **Fixture d'échec ISOLÉE (R2)** : `ZStudyPodcast(sourceId:'s', extra: {'updated_at':'X','k':1}).extra == {'k':1}` (clé réservée filtrée MÊME née du ctor `const`) ; `ZStudyPodcast(sourceId:'s', extra:{'a':{'b':1}}) == ZStudyPodcast(sourceId:'s', extra:{'a':{'b':1}})` (égalité profonde sur `extra` imbriqué).
  - **Injection de régression (R3)** : dans `toMap`, étaler `..._extra` (brut) au lieu de `...extra` ⇒ une instance née du ctor `const` avec `extra` pollué réémet `updated_at`, un test ROUGIT.

### `buildId` — identité *content-addressed* PURE

**AC6.** `static String ZStudyPodcast.buildId(String sourceId, ZPodcastMode mode) => '${sourceId}_${mode.name}'` est **PURE, TOTALE, DÉTERMINISTE** (D2). Le champ `id` n'est **jamais** assigné par l'entité (AD-14).
  - **Pouvoir discriminant OBSERVÉ (R2)** : `buildId('s1', ZPodcastMode.simple) == 's1_simple'` ; `buildId('s1', ZPodcastMode.dialogue) == 's1_dialogue'` (≠) ; `buildId('s2', ZPodcastMode.simple) == 's2_simple'` (≠). Deux (sourceId, mode) distincts ⇒ ids distincts.
  - **Injection de régression (R3)** : figer `buildId` à un littéral constant (`=> 'x'`) ⇒ les 3 cas ci-dessus collisionnent, un test ROUGIT.

### Invalidation *content-addressed* — COMPARAISON PURE (le cœur de FR-S11)

**AC7.** `bool ZStudyPodcast.isStale(String currentSourceHash) => sourceHash != currentSourceHash` est **PURE, TOTALE, DÉTERMINISTE** (D4) — **aucun calcul de hash, aucune horloge**. `isStale` dépend **RÉELLEMENT des DEUX empreintes** (pas un golden fortuit — leçon ES-2.3).
  - **Pouvoir discriminant OBSERVÉ (R2)** : podcast `sourceHash: 'h-A'` ⇒ `isStale('h-B') == true` (source changée) ET `isStale('h-A') == false` (source inchangée). **Faire VARIER l'empreinte stockée** : podcast `sourceHash: 'h-B'` ⇒ `isStale('h-A') == true` (prouve que la sortie dépend AUSSI de `sourceHash`, symétrie observée).
  - **Injection de régression (R3)** : remplacer `!=` par `false` (« jamais obsolète ») ⇒ `isStale('h-B')` sur `'h-A'` devient `false`, un test ROUGIT ; remplacer par `true` (« toujours obsolète ») ⇒ `isStale('h-A')` sur `'h-A'` devient `true`, un test ROUGIT. **Les DEUX injections mordent** (pouvoir bidirectionnel).

**AC8.** `enum ZPodcastFreshness {absent, fresh, stale}` + `ZPodcastFreshness podcastFreshness({String? storedHash, String? currentSourceHash})` **PURE, TOTALE** (parité lex `PodcastFreshness`/`podcastFreshness`, D4) : `storedHash` null/vide → `absent` ; sinon `storedHash == currentSourceHash ? fresh : stale`. Bords documentés & testés : `(storedHash:'h', currentSourceHash:null)` → `stale` ; `(storedHash:null, currentSourceHash:'h')` → `absent` ; `(storedHash:'', currentSourceHash:'')` → `absent` ; `(storedHash:'h', currentSourceHash:'h')` → `fresh`. **Aucun throw, aucun `null!`.**
  - **Fixture d'échec ISOLÉE (R2)** : les 4 bords ci-dessus + `('h-A','h-B') → stale`.
  - **Injection de régression (R3)** : retirer la garde `storedHash null/vide → absent` (comparer directement) ⇒ `(null, 'h')` retournerait `stale` au lieu de `absent`, un test ROUGIT.

### Enums — fallback défensif NORMATIF (ordre de déclaration)

**AC9.** `ZPodcastSourceKind {note, folder, document}`, `ZPodcastMode {simple, dialogue}`, `ZPodcastStatus {ready, pending, processing, failed, stale}` — chacun avec la dartdoc « ORDRE NORMATIF » (D3). Décodés via `ZStudyPodcast.fromMap`, une valeur **absente / `null` / non-`String` / inconnue** retombe sur la **1ʳᵉ constante** (`note` / `simple` / `ready`), **jamais** de throw. Persistance en **camelCase** (`name`).
  - **Fixture d'échec ISOLÉE (R2)** : `fromMap({'source_kind':'inconnu'}).sourceKind == note` ; `fromMap({'mode':42}).mode == simple` ; `fromMap({'status':null}).status == ready` ; `fromMap({'status':'stale'}).status == stale` (valeur connue préservée — anti-golden : prouve que le décodage n'est pas « toujours le défaut »).
  - **Injection de régression (R3)** : réordonner `ZPodcastStatus` pour mettre `pending` en tête ⇒ `fromMap({'status':'inconnu'}).status` devient `pending`, le test de fallback `== ready` ROUGIT (le comportement défensif est bien porté par l'ordre).

### Gate `reserved-keys` + surface publique (R8, D6/D7)

**AC10.** Le barrel `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` exporte `z_study_podcast.dart` **`hide ZStudyPodcastZcrud`** (règle (h), extension générée masquée — sinon son `copyWith`/`toMap` détruirait `extra`/`extension`), et exporte les 4 enums + `podcastFreshness` **sans `hide`**. `ZStudyPodcast`, `ZStudyPodcastExtensionParser`, `ZPodcastSourceKind`, `ZPodcastMode`, `ZPodcastStatus`, `ZPodcastFreshness`, `podcastFreshness` sont **ajoutés à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (study-niveau, NON pertinents flashcard) et **classés NON-flashcard** dans `z_kernel_surface_guard_test.dart`.
  - **Injection de régression (R3, anti-DW-ES25-1)** : retirer `ZStudyPodcast` (ou `podcastFreshness`) de la liste `hide` de `zcrud_flashcard` ⇒ `z_kernel_surface_guard_test` **ROUGIT** (`FUITE POTENTIELLE … {ZStudyPodcast}`). **Ce test de non-export DOIT avoir un pouvoir observé** (pas powerless — leçon ES-2.5).

**AC11.** Le gate `reserved-keys` (volet A comportemental `flutter test --tags reserved-keys` **ET** volet B `scripts/ci/gate_reserved_keys.dart` `R_disk \ R_wired == ∅`) est **VERT** avec `study_podcast` câblé (D7) : `registerZStudyPodcast` ∈ `kRegistrars`, `kProbeBodies['study_podcast']` présent & non trivial, `kExtraWriters['study_podcast']` = **2 voies** (`ctor` + `copyWith`) transmettant `extra` **VERBATIM** (règle (k)). `study_podcast` **absent** de `kNonExtensibleKinds`/`kExtensionPayloadPreservers`/`kNoValueEqualityProbes`/`kLegacyUpdatedAtMirrors`.
  - **Injection de régression (R3)** : (a) retirer `registerZStudyPodcast` de `kRegistrars` ⇒ `gate_reserved_keys.dart` ROUGIT (`R_disk \ R_wired ≠ ∅`) ; (b) rendre `_ctorStudyPodcast` **auto-sanitisant** (pré-filtrer `extra`) ⇒ l'assertion (i.3)/(k) « writer VERBATIM » ROUGIT (writer menteur poli, MAJEUR-2) ; (c) retirer `...ZSyncMeta.reservedKeys` de `_reservedKeys` ⇒ la sonde polluée par `updated_at` fait réémettre la clé, l'assertion (c)/(d) ROUGIT.

**AC12.** `kProbeBodies['study_podcast']` est un corps métier **minimal valide et représentatif** (règle : un kind sans corps fait ROUGIR le harnais) — p.ex. `{'id':'p','source_kind':'folder','source_id':'s','folder_id':'f','mode':'dialogue','source_hash':'h','result_ref':'r','status':'ready'}`. **Aucun canal hors-codegen à démontrer** (D5) ⇒ contrairement à `smart_note`/`exam`/`folder_contents_order`, la sonde ne porte **aucune clé `Map` hors-codegen** (aucune règle (g2) « canal non vide » ne s'applique). Le round-trip de la sonde polluée (par `updated_at`/`is_deleted` + une clé inconnue) prouve : (c) la clé inconnue est **préservée** dans `extra`, (e) les clés de sync **n'atterrissent PAS** dans `extra` et ne sont **PAS réémises** par `toMap`.

### Invariants transverses (AD, NFR-S)

**AC13.** **AD-1/AD-17 — acyclicité & fermeture minimale.** `z_study_podcast.dart` + ses enums n'importent **AUCUN** satellite (`zcrud_flashcard`/`zcrud_exam`/`zcrud_document`/…) ni Flutter/`dart:ui`/`cloud_firestore` ni **`package:crypto`**. La fermeture transitive du kernel reste `{zcrud_core, zcrud_annotations}` (NFR-S10/SM-S7). `graph_proof` **ACYCLIQUE + CORE OUT=0** repo-wide. `folderId`/`sourceId` sont des `String` neutres (aucun import de `ZStudyFolder`). [Source: AD-1/AD-17 ; z_exam.dart l.150-156 « dépendance DÉCLARÉE, aucun import »]
  - **Test (R2)** : test AST/lecture-source vérifiant l'absence de `import 'package:crypto` et `import 'package:flutter` dans `packages/zcrud_study_kernel/lib/src/domain/z_podcast*.dart` + `z_study_podcast.dart` (ou s'appuyer sur `z_kernel_purity_test.dart` existant s'il couvre déjà `dart:ui`/`Color` ; ajouter la clause `crypto` si absente). **PROUVER par un rouge provoqué** : un `import 'package:crypto/crypto.dart';` inséré fait ROUGIR (kernel crypto-free observé).

**AC14.** **AD-3 codegen** : `melos run generate` émet `z_study_podcast.g.dart` (`_$ZStudyPodcastFromMap`, `ZStudyPodcastZcrud`, `$ZStudyPodcastFieldSpecs`, `registerZStudyPodcast`, `_$zRequireExtraPreserved`), **committé** (gate `codegen-distribution`). `@JsonSerializable` pur, `fieldRename: snake` (via `@ZcrudModel`), enums camelCase, `id` opaque `String?`, `createdAt` ISO-8601. **Aucun `*.g.dart` édité à la main.**

**AC15.** **`gate:web` DEFAULT-ON (D8)** : tous les tests kernel de cette story passent sous `dart test` **ET** `dart test -p node` (aucun `dart:io` non annoté `@TestOn('vm')`, tous les `DateTime` construits en `DateTime.utc(...)` explicite, aucun `DateTime.now()`). Le `no_datetime_now_test.dart` existant (ES-2.7) reste **VERT** (aucun `DateTime.now()` introduit).

**AC16.** **Vérif verte rejouée réellement (avant `review`)** : `melos run generate` OK → `melos run analyze` **repo-wide** RC=0 → `melos run test` (kernel + flashcard surface-guard) RC=0 → gate `reserved-keys` (A+B) RC=0 → `melos run verify` (dont `test:js`) RC=0. Nombre de tests kernel **≥** avant la story (non-régression, aucun test supprimé).

## Tasks / Subtasks

- [x] **T1 — Enums (D3).** Créer `z_podcast_source_kind.dart` (`{note, folder, document}`), `z_podcast_mode.dart` (`{simple, dialogue}`), `z_podcast_status.dart` (`{ready, pending, processing, failed, stale}`) — chacun avec la dartdoc « ORDRE NORMATIF, fallback = 1ʳᵉ constante » (rationale `ready`-first pour le status). Créer `z_podcast_freshness.dart` (`enum ZPodcastFreshness {absent, fresh, stale}` + fonction top-level PURE `podcastFreshness({String? storedHash, String? currentSourceHash})`). *(AC8/AC9)*
- [x] **T2 — Entité `ZStudyPodcast` (D1/D2/D5/D9).** Créer `z_study_podcast.dart` : `@ZcrudModel(kind:'study_podcast')`, `extends ZEntity with ZExtensible`, patron ES-2.2b INTÉGRAL (structure copiée de `z_document_annotation.dart`/`z_exam.dart` : ctor `const` `: _extra=extra`, `fromMap` NON-nue, accesseur `extra` normalisant, `_sanitizeExtra` partagé, `toMap` `...extra`, `copyWith` sentinelle, `==`/`hashCode` profonds, `_reservedKeys ⊇ ZSyncMeta.reservedKeys`, `typedef ZStudyPodcastExtensionParser`, `_decodeExtension`, `_asStringMap`). Tous les champs `@ZcrudField`/`@ZcrudId` (D5 — **aucun champ nu**). `static String buildId(...)`. `bool isStale(String currentSourceHash)`. *(AC1-AC7)*
- [x] **T3 — Codegen.** `part 'z_study_podcast.g.dart';` puis `build_runner` ; **staged** `z_study_podcast.g.dart` (git add, sans commit). Vérifié : `registerZStudyPodcast`/`$ZStudyPodcastFieldSpecs`/`ZStudyPodcastZcrud` + décodage enums `?? T.values.first` émis. *(AC14)*
- [x] **T4 — Barrel kernel + `hide` flashcard + surface-guard (D6).** Barrel `zcrud_study_kernel.dart` : `export '...z_study_podcast.dart' hide ZStudyPodcastZcrud;` + exports des 4 enums / `podcastFreshness` (sans `hide`). 7 symboles ajoutés à la liste `hide` de `zcrud_flashcard.dart`. Classés NON-flashcard (via `hide`, PAS `_flashcardAllowlist`) — surface-guard vert + rouge provoqué. *(AC10)*
- [x] **T5 — Câblage gate `reserved-keys` (R8, D7).** `registrars.dart` : `registerZStudyPodcast` → `kRegistrars` ; `kProbeBodies['study_podcast']` (AC12) ; `_ctorStudyPodcast`/`_copyWithStudyPodcast` (VERBATIM, règle (k)) + `kExtraWriters['study_podcast'] = [ctor, copyWith]`. NON ajouté à `kNonExtensibleKinds`/`kExtensionPayloadPreservers`/`kNoValueEqualityProbes`/`kLegacyUpdatedAtMirrors`. *(AC11/AC12)*
- [x] **T6 — Tests à pouvoir discriminant (R2/R3).** `z_study_podcast_test.dart` (round-trip idempotent + anti-golden `sourceHash`, `fromMap(const {})`, gardes `extra` ES-2.2b, `copyWith` sentinelle, `buildId` discriminant, `isStale` bidirectionnel, `podcastFreshness` 5 bords), `z_podcast_status_test.dart` / `z_podcast_mode_test.dart` / `z_podcast_source_kind_test.dart` (fallback NORMATIF + valeur connue préservée). Clause `crypto` ajoutée au test de pureté kernel (AC13, rouge provoqué). *(AC2-AC9, AC13)*
- [x] **T7 — Vérif verte repo-wide (AC16).** `build_runner` → `melos run analyze` repo-wide RC=0 → tests kernel (267) + flashcard surface-guard → gate `reserved-keys` (A+B) RC=0 → `prove_gates` (41/0) → `graph_proof` (ACYCLIQUE + CORE OUT=0) → `melos run verify` RC=0 (dont `gate:web`/`test:js` + codegen-distribution). Nb tests kernel ≥ avant.

## Dev Notes

### Fichiers de référence à COPIER (patron), pas à réinventer
- **Patron entité `ZExtensible` INTÉGRAL** : `packages/zcrud_exam/lib/src/domain/z_exam.dart` (jumeau le plus proche — entité `ZExtensible` avec enum absent, `DateTime?` ISO-8601, `_reservedKeys ⊇ ZSyncMeta.reservedKeys`, méthodes pures). **Différence** : `ZExam` a un canal hors-codegen (`reminderTime`) ; `ZStudyPodcast` **n'en a AUCUN** (D5) — donc **PAS** de `kXxxKey`, **PAS** de câble hors-codegen dans `fromMap`/`toMap`, plus simple.
- **Enum + fallback normatif** : `packages/zcrud_document/lib/src/domain/z_document_status.dart` (dartdoc « ORDRE NORMATIF, 1ʳᵉ constante = défaut ») + `z_study_document.dart` (champ enum `status` + décodage `_$enumFromName(...) ?? T.values.first` dans le `.g.dart`).
- **Value/pureté & hash-free** : `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart` (D2 : « ⛔ jamais `package:crypto` … réutiliser `zFnv1a32` injectable » — ICI on va plus loin : **aucun hash du tout**, comparaison de `String` opaques).
- **Câblage gate** : `tool/reserved_keys_gate/lib/src/registrars.dart` (contrat « 3 lignes » ; voir `exam`/`document_annotation` — ce dernier est le plus proche : **entité `ZExtensible` SANS canal hors-codegen**, câblage `ctor`+`copyWith` seul).
- **Surface-guard** : `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` + le bloc `hide` de `zcrud_flashcard.dart` l.57-80 (précédent `ZFolderContentsOrder`/ES-2.7 littéral).

### Invariants AD applicables (NON-NÉGOCIABLES)
- **AD-1/AD-17** : kernel ne dépend d'aucun satellite ; `graph_proof` acyclique + CORE OUT=0 ; ⛔ jamais `crypto`/Flutter. `folderId`/`sourceId` = `String` neutres (dépendance conceptuelle, **aucun import**).
- **AD-3** : `@ZcrudModel`/`@JsonSerializable` pur, `fieldRename: snake`, enums camelCase, `@ZcrudId String?`. `.g.dart` **committé** (gate `codegen-distribution`), jamais édité main.
- **AD-4** : `ZExtensible` (slot `ZExtension?` versionné + `extra` + registre). Enums fermés + `@JsonKey(unknownEnumValue)` (via fallback généré) = ouverture défensive. Le hashing du contenu source = extension par **injection** au consommateur (jamais dans le domaine).
- **AD-10** : désérialisation défensive, jamais throw ; AUCUN `assert` dans le ctor `const` ; `fromMap(const {})` sûr ; enums/`DateTime`/`extension` illisibles → fallback/`null` ; `isStale`/`podcastFreshness`/`buildId` **TOTALES**.
- **AD-14** : `id` nullable (éphémère), jamais assigné par l'entité (matérialisé au repo via `buildId`).
- **AD-16/AD-19** : `updated_at`/`is_deleted` = STORE hors-entité, jamais inline (DIVERGE de lex qui les avait inline) ; `sourceHash`/`createdAt` = clés MÉTIER distinctes ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}`.

### Rétro ES-1 (R1–R9) & leçons ES-2.0→2.7 à INTÉGRER
- **R2** (fixture d'échec isolée) / **R3** (injection rejouée par l'orchestrateur) : chaque garde critique (`isStale`, `podcastFreshness`, fallback enum, gate, surface-guard) naît avec son rouge provoqué.
- **R4/R-G** : décisions tranchées par **lecture réelle** de lex (faite : `study_podcast.dart` + 3 enums + `podcast_audio_access.dart`), pas de mémoire.
- **R5** : AST/tokenisé, jamais grep naïf (test de pureté `crypto`/`flutter`).
- **R6** : aucune dégradation silencieuse (byte-perte, clé avalée).
- **R8** : gate `reserved-keys` câblé **dans la même story** (registrar + probe + writers), les 3 dimensions.
- **Leçon ES-2.3 (golden de hash fortuit)** : `isStale`/`podcastFreshness` prouvés **bidirectionnellement** (varier les DEUX empreintes) — un test qui passerait avec un `sourceHash` figé est POWERLESS.
- **Leçon ES-2.5 / DW-ES25-1** : le surface-guard de non-export a un **pouvoir OBSERVÉ** (retirer le symbole du `hide` ⇒ ROUGE) — pas un test d'existence.
- **Leçon ES-2.6** : ⛔ jamais `crypto`/`DateTime.now()` ; **ici, ZÉRO hash & ZÉRO horloge** (l'invalidation *content-addressed* est atemporelle — c'est le point de FR-S11).
- **Leçon ES-2.2b** : les gardes `extra` sont une **MACHINE** (writer `ctor` + `copyWith` VERBATIM au gate), pas une discipline.

### Pièges spécifiques à cette story
1. **Ne PAS calculer de hash** (ni `crypto`, ni `zFnv1a32`) : `sourceHash` est OPAQUE, FOURNI, COMPARÉ. Le seul « pouvoir discriminant » à prouver est celui de la **comparaison** (`!=`), pas d'un algo de hash.
2. **Ne PAS introduire de champ nu** (non `@ZcrudField`/`@ZcrudId`) : la règle (g) le prendrait pour un canal hors-codegen non réservé → gate ROUGE (D5).
3. **`ZPodcastStatus` : `ready` en 1ʳᵉ constante** (DIVERGE de l'ordre lex) — sinon le fallback défensif défensif change silencieusement (parité sémantique lex `fromJson → ready`).
4. **Ne PAS toucher `kLegacyUpdatedAtMirrors`** : `ZStudyPodcast` n'émet jamais `updated_at` (AD-19) — l'y ajouter ferait ROUGIR le test de verrou.
5. **`updated_at`/`is_deleted` inline de lex : à RETIRER** (extraits hors-entité, comme ES-2.5 l'a fait pour `isDeleted`).

## Change Log

| Date | Version | Description | Auteur |
|------|---------|-------------|--------|
| 2026-07-15 | 0.1 | Création de la story ES-2.8 (create-story, effort medium) — dernière story ES-2 | bmad-create-story |
| 2026-07-15 | 0.2 | Implémentation (dev-story, effort high) : entité `ZStudyPodcast` + 3 enums + `ZPodcastFreshness`/`podcastFreshness` + barrel/hide/surface-guard + câblage gate `reserved-keys` (R8). 8 injections R3 rejouées (RC≠0) puis restaurées. Vérif verte repo-wide. Status → review. | bmad-dev-story |

## Dev Agent Record

### Implementation Plan
Structure copiée du jumeau `ZDocumentAnnotation` (entité `ZExtensible` SANS canal
hors-codegen) + `ZExam` (enum + `DateTime?` ISO-8601). Décision centrale D4 tenue :
`sourceHash` est un `String` OPAQUE COMPARÉ — le kernel ne hashe RIEN, aucune
dépendance crypto ni `zFnv1a32`. Invalidation atemporelle pure (`isStale` /
`podcastFreshness`). Tous les champs codegen-ables (D5) ⇒ aucun `kXxxKey`, aucune
règle (g2), câblage gate = jumeau `document_annotation` (ctor + copyWith VERBATIM).

### Completion Notes
- **Décisions D remises en cause** : aucune. Toutes les prescriptions fermées de
  la story sont cohérentes avec le code réel (jumeaux `ZExam`/`ZDocumentAnnotation`
  vérifiés sur disque). Le générateur émet bien `_$enumFromName(...) ?? T.values.first`
  (D3 confirmé), `fieldRename: snake` est le défaut de `@ZcrudModel` (confirmé).
- **AC13 crypto-free PROUVÉ** : clause `package:crypto` ajoutée au scan de pureté
  kernel (`z_kernel_purity_test.dart`) ; rouge provoqué (`import 'package:crypto...'`
  ⇒ purity `+6 -1`). `graph_proof` : deps kernel = `{annotations, core, generator}`,
  0 crypto, ACYCLIQUE + CORE OUT=0. `pubspec.yaml` kernel INCHANGÉ (aucune dép).
- **`isStale`/`podcastFreshness` prouvés BIDIRECTIONNELLEMENT** (leçon ES-2.3) :
  varier `sourceHash` stocké OU `currentSourceHash` change la sortie ; injections
  R3 `=> false` (3 tests rouges) et suppression garde `absent` (2 tests rouges).
- **8 injections R3 rejouées réellement (RC≠0), restaurées par édition ciblée** :
  (A) `import crypto` → purity RED ; (B) `isStale => false` → 3 tests RED ;
  (C) garde `absent` retirée → freshness RED ; (D) `registerZStudyPodcast` retiré
  → gate `R_disk\R_wired={study_podcast}` RED ; (E) voie `ctor` retirée → gate
  règle (j) RED ; (F) `hide ZStudyPodcastZcrud` retiré → gate règle (h) RED ;
  (G) `...ZSyncMeta.reservedKeys` retiré → gate (a) `{updated_at,is_deleted}` RED ;
  (H) `ZStudyPodcast` retiré du `hide` flashcard → surface-guard `FUITE` RED.
  Working-tree restauré et re-vérifié VERT après chaque.
- **Dettes ouvertes** : aucune neuve. DW-ES14-2 (slot `extension` jamais typé par
  le registre) reste ouverte comme pour toutes les entités `ZExtensible` — non
  aggravée (podcast n'utilise pas de `ZExtension` concret, absente de
  `kExtensionPayloadPreservers`).
- **Fallback disque** : NON. Le skill `bmad-dev-story` a été invoqué via le tool
  `Skill` (chargé normalement).

### Vérif verte réelle (rejouée sur disque)
- `build_runner` (kernel) OK — `z_study_podcast.g.dart` généré + staged (git add).
- `melos run analyze` **repo-wide** RC=0 (2 infos pré-existantes `zcrud_document`).
- Tests kernel `dart test` : **267 passed** (dont ~39 neufs podcast/enums) ; JS
  `dart test -p node` : 253 passed (VM-only skippés).
- Surface-guard `zcrud_flashcard` : 5 passed.
- `gate_reserved_keys.dart` (A+B) RC=0 — 16 registrars, 25 voies d'écriture.
- `prove_gates.dart` : **41 OK, 0 FAIL**.
- `graph_proof.py` : ACYCLIQUE OK, CORE OUT=0 OK.
- `melos run verify` RC=0 (reflectable/secrets/codegen/codegen-distribution/compat/
  gate:web/reserved-keys). `no_datetime_now_test` (ES-2.7) reste vert.

### File List
**Créés (kernel `zcrud_study_kernel`)** :
- `lib/src/domain/z_podcast_source_kind.dart`
- `lib/src/domain/z_podcast_mode.dart`
- `lib/src/domain/z_podcast_status.dart`
- `lib/src/domain/z_podcast_freshness.dart`
- `lib/src/domain/z_study_podcast.dart`
- `lib/src/domain/z_study_podcast.g.dart` (généré, staged)
- `test/z_study_podcast_test.dart`
- `test/z_podcast_status_test.dart`
- `test/z_podcast_mode_test.dart`
- `test/z_podcast_source_kind_test.dart`

**Modifiés** :
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (barrel : exports +
  `hide ZStudyPodcastZcrud`)
- `packages/zcrud_study_kernel/test/z_kernel_purity_test.dart` (clause `package:crypto`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (7 symboles ajoutés au `hide`)
- `tool/reserved_keys_gate/lib/src/registrars.dart` (registrar + probe + 2 writers)

### Definition of Done
- [x] AC1–AC16 satisfaits, tests à **pouvoir discriminant OBSERVÉ** (R2 + R3 rejouées).
- [x] Codegen OK, `z_study_podcast.g.dart` **staged dans l'arbre** (git add, sans commit — commit d'epic réservé à l'orchestrateur).
- [x] `melos run analyze` **repo-wide** RC=0 ; tests kernel RC=0 ; gate `reserved-keys` (A+B) RC=0 ; `melos run verify` (dont `test:js`) RC=0.
- [x] `graph_proof` acyclique + CORE OUT=0 ; kernel **crypto-free & Flutter-free** (prouvé par rouge provoqué AC13).
- [x] `hide` `zcrud_flashcard` + surface-guard à jour ; `no_datetime_now_test` (ES-2.7) reste vert.
- [x] Nombre de tests kernel ≥ avant la story (non-régression).
- [ ] Findings code-review HIGH/MAJEUR/MEDIUM corrigés ou justifiés par écrit. *(étape `bmad-code-review` à venir)*
