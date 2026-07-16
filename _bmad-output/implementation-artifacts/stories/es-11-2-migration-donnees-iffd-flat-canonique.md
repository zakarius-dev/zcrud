---
baseline_commit: 448616b4a9f982fa017737f5dd4898fb9cc938d8
---

# Story ES-11.2 : Migration IFFD flat→canonique — mécanique de migration RÉUTILISABLE (zcrud-side) + `ZSyncMeta` additif, sans perte

Status: review

<!-- Créée par bmad-create-story (skill réel `bmad-create-story`, tool Skill). Cycle BMAD strict. NE PAS éditer le sprint-status ici (ressort de l'orchestrateur). -->

## Story

As a **développeur IFFD (hôte GetX) préparant la bascule de ses données historiques top-level plates vers le canonique zcrud**,
I want **une MÉCANIQUE DE MIGRATION PURE, DÉFENSIVE et IDEMPOTENTE — `ZLegacyStudyMigrator` — qui transforme un corpus de documents LEGACY FLAT IFFD (camelCase, `Timestamp`/`int` millis, `audioText`, statuts à 6 valeurs, champs de contrôle inline, AUCUNE méta de sync) vers la forme CANONIQUE (snake_case, enums camelCase à 4 valeurs, `ZSyncMeta` ajouté de façon ADDITIVE hors-entité), en RÉUTILISANT `ZStudyLegacyCodec` (ES-3.5) et en produisant un RAPPORT de migration auditable, le tout confiné à l'adapter `zcrud_firestore` (AD-27) et prouvé SANS PERTE sur des FIXTURES SYNTHÉTIQUES**,
So that **la session IFFD dédiée pourra brancher cette mécanique sur ses collections Firestore réelles et exécuter la bascule repo-par-repo sans big-bang ni perte de donnée métier (R26), un document legacy corrompu ne cassant JAMAIS la migration (AD-10) — SANS qu'aucun fichier IFFD/lex/dodlp ne soit touché dans cette story (frontière de périmètre : l'exécution sur données réelles est DÉFÉRÉE, dette DW-ES112-1)**.

---

## 🔴 Frontière de périmètre (NON-NÉGOCIABLE — consigne utilisateur)

> **Cette session ne touche QUE des packages `zcrud_*` du monorepo.** **AUCUN** fichier `lex_douane`/`iffd`/`dodlp-otr` n'est lu, importé ou modifié. La story ES-11.2 de l'épic décrit la migration des **données IFFD réelles** ; ici on ne produit **QUE la mécanique de migration réutilisable côté zcrud + des tests sur fixtures SYNTHÉTIQUES**. Aucune donnée IFFD réelle n'est importée dans ce repo.

| Zone | Statut dans CETTE story | Portée |
|---|---|---|
| **ZCRUD-SIDE (livré ici)** | ✅ MÉCANIQUE RÉUTILISABLE | `ZLegacyStudyMigrator` (pur, défensif, idempotent) + `ZLegacyMigrationReport` dans `zcrud_firestore` (adapter, AD-27) ; réutilise `ZStudyLegacyCodec` (ES-3.5) ; tests sur **fixtures synthétiques** `test/fixtures/iffd_legacy/*.json`. |
| **IFFD-SIDE (DÉFÉRÉ)** | ⏸️ dette **DW-ES112-1** | Câblage de la mécanique sur les **collections Firestore RÉELLES** IFFD ; **write-back** batché de la forme canonique ; cutover repo-par-repo ; validation sur corpus RÉEL. **Session IFFD dédiée**, aucun fichier touché ici. |

**Confirmation exigée en clôture** : `git status` ne montre AUCUN fichier hors `packages/zcrud_firestore/**` + ce fichier story. Aucun autre repo touché.

---

## Contexte & état réel validé sur disque (le 2026-07-16)

> **Ne rien réinventer.** La brique de (dé)normalisation **PAR DOCUMENT** existe déjà : `ZStudyLegacyCodec` (livré ES-3.5, `packages/zcrud_firestore/lib/src/data/z_study_codec.dart`, **exporté** par le barrel). Cette story **compose PAR-DESSUS** un migrateur **de CORPUS** — elle ne réécrit NI le codec NI son mapping de casse/valeur.

### Ce qui EXISTE (à réutiliser tel quel, ne pas dupliquer)

- **`ZStudyLegacyCodec`** (`z_study_codec.dart`) — normaliseur **PUR, par `Map<String,dynamic>`, bidirectionnel, DÉFENSIF** (jamais de throw) :
  - `toCanonical(legacy)` : `camelToSnake` des clés, `valueMappers` de valeur (ex. `mapDocumentStatus` **6→4**), interop dates `int` millis→ISO-8601 (clés `_at`), préservation de granularité legacy sous `_legacy_<snake>` (`preserveLegacyUnder`, AD-4), **ajout ADDITIF** `is_deleted:false` via `putIfAbsent` (jamais d'écrasement), `updated_at` **laissé absent** (défaut LWW « jamais synchronisé »). Les clés réservées `ZSyncMeta.reservedKeys` passent **telles quelles**.
  - `toLegacy(canonical)` : `snakeToCamel` (round-trip d'interop). Clés réservées / `_legacy_…` intactes.
  - `mapDocumentStatus(Object?)` **6→4** : `uploading`→`uploading` ; `converting`/`embedding`→`validating` ; `uploaded`/`converted`/`embedded`→`ready` ; **absent/null/inconnu/non-String → `uploading` (défaut sûr)**.
- **`ZSyncMeta`** vit dans **`zcrud_core`** (`lib/src/domain/sync/z_sync_meta.dart`) : `kUpdatedAt`/`kIsDeleted`/`reservedKeys` (`{'updated_at','is_deleted'}`). Le codec les consomme (pas de littéral redéclaré, DW-ES13-1 soldée).
- **Fixtures synthétiques legacy existantes** (`test/fixtures/iffd_legacy/`) : `document_converting.json`, `document_embedded.json`, `document_unknown_status.json`, `document_corrupt.json`, `document_created_at_iso.json`, `document_with_sync_meta.json`. **À ÉTENDRE** (multi-documents, idempotence, champs DW-ES22-2 `audioText`/`audioTextHash`).
- **`zcrud_firestore`** est un package **Flutter** (`flutter: sdk` + `cloud_firestore` + `hive`) ⇒ **R14 : tests via `flutter test`, JAMAIS `dart test`.** Deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` (déjà présentes) ⇒ **aucune nouvelle arête de graphe requise** par cette story.
- **Barrel** `lib/zcrud_firestore.dart` exporte déjà `src/data/z_study_codec.dart` (ES-3.5). ES-11.2 **ajoute** l'export du migrateur.

### Le TRAP central que la migration doit franchir (idempotence — vérifié sur code)

> **`ZStudyLegacyCodec.toCanonical` N'EST PAS idempotent sur le champ `status`.** `mapDocumentStatus` ne connaît QUE les 6 valeurs legacy ; une valeur **déjà canonique** (`ready`/`validating`) tombe dans le `default` → **`uploading`**. Donc `toCanonical(toCanonical(doc))` **RÉTROGRADE** un statut déjà migré (`ready` → `uploading`) — perte silencieuse à la ré-exécution.

Une migration de corpus RÉEL est **ré-exécutée** (reprise après interruption, bascule progressive) ⇒ elle **DOIT être IDEMPOTENTE** (point fixe : `migrate(migrate(x)) == migrate(x)`). C'est la garde structurante d'ES-11.2 — elle n'existe PAS au niveau du codec ES-3.5 (qui est un shim d'interop de LECTURE, pas un migrateur ré-entrant).

---

## Décisions d'architecture centrales

> **[Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-27, #AD-19, #AD-10 ; architecture-zcrud-2026-07-09#AD-1/AD-5 ; stories/epic-es-9-retrospective.md#R26 ; stories/epic-es-10-retrospective.md#R27.4/R28]**

### AD-27 — mapping legacy dans l'ADAPTER, jamais dans le domaine ; `ZSyncMeta` additif ; migration = CHANTIER prouvé sans perte
Le mapping bidirectionnel snake↔camelCase et la restructuration flat→canonique vivent **EXCLUSIVEMENT** dans `zcrud_firestore` (jamais dans le kernel/entités). L'ajout de `ZSyncMeta` est **additif rétro-compatible** (un doc legacy sans méta se lit sur des défauts sûrs). La restructuration flat→canonique est un **chantier explicite** (pas un renommage), prouvé **sans perte** ; **gate CI** de désérialisation défensive sur corpus legacy. ⇒ `ZLegacyStudyMigrator` vit dans `zcrud_firestore`, signature **`Map<String,dynamic>` UNIQUEMENT** (AD-5 : aucun `Timestamp`/`Query`/`FirebaseException` dans une signature publique).

### AD-19 — `ZSyncMeta` HORS-ENTITÉ, universel
`updated_at`/`is_deleted` ne vivent **JAMAIS** dans le corps canonique ni dans `extra` : ils sont portés hors-entité par `ZSyncMeta` (merge LWW sur `updated_at`). ⇒ le migrateur **ajoute `is_deleted` de façon additive** (visibilité adapter) et **laisse `updated_at` absent** ; après décodage par l'entité, **aucune** de ces deux clés ne doit polluer `extra`/le corps (huitième-occurrence-du-motif ES-2.1 H1 : une clé de sync capturée dans `extra` et réémise = régression).

### AD-10 — DÉFENSIF partout : jamais de throw
Un champ legacy absent/corrompu/mal typé ⇒ **défaut sûr**, jamais d'exception qui casserait la migration du corpus. `mapDocumentStatus` défend déjà (`default → uploading`) ; le migrateur ne doit **jamais** ré-introduire de throw au-dessus.

### R26 — PRÉSERVATION EXACTE du contenu métier (leçon ES-9)
> **[Source: epic-es-9-retrospective.md#R26]** Round-trip flat→canonique→(re-lecture) **PRÉSERVE** les champs métier EXACTEMENT. Un mapping qui **DROPPE** un champ doit **ROUGIR**. La garde n'est pas « le canonique existe » mais « **AUCUNE clé métier legacy n'a disparu** » — census discriminant, pas assertion d'existence (R12/R18/R20).

### R27.4 / R28 — le verrou vise le SYMBOLE PUBLIC ; l'adapter reste générique
> **[Source: epic-es-10-retrospective.md#R27.4/R28]** Le test à rouge provoqué exerce le **symbole PUBLIC** exporté par le barrel (`ZLegacyStudyMigrator.migrateDocument`/`migrateCorpus`), pas un helper interne. Le migrateur reste **GÉNÉRIQUE par `Map`** : il ne dépend **d'AUCUN** package d'entité (`zcrud_document`/`zcrud_note`/…) — aucune arête de fan-in neuve (cf. AC8).

---

## Acceptance Criteria

> Chaque AC est **discriminant** (R12) et, quand il pose une garde, **co-livré avec un test à rouge provoqué** (R27, injections §*Injections R3 prévues*). **Runner = `flutter test` (R14) ; RC capturé HORS pipe (R15).** Fixtures **SYNTHÉTIQUES** uniquement — aucune donnée IFFD réelle.

### AC1 — Migrateur de corpus PUR, DÉFENSIF, confiné à l'adapter (AD-27/AD-5/AD-10)

**Given** la brique par-document `ZStudyLegacyCodec` (ES-3.5) et un besoin de migration de CORPUS ré-entrant
**When** on fournit `ZLegacyStudyMigrator` (`packages/zcrud_firestore/lib/src/data/z_study_migrator.dart`, **NOUVEAU**, exporté par le barrel)
**Then** il expose (a) `ZDocumentMigrationOutcome migrateDocument(Map<String,dynamic> legacy)` et (b) `ZLegacyMigrationReport migrateCorpus(Iterable<Map<String,dynamic>> corpus)` — signatures **`Map<String,dynamic>` UNIQUEMENT** : **aucun** type `cloud_firestore` (`Timestamp`/`Query`/`DocumentSnapshot`/`FirebaseException`) ni `hive` (`Box`) n'apparaît dans une signature publique (AD-5).
**Then** le migrateur **compose** `ZStudyLegacyCodec` (injecté par constructeur ou construit avec la config IFFD `valueMappers:{'status': mapDocumentStatus}`, `preserveLegacyUnder:{'status'}`) — il **ne réimplémente NI** `camelToSnake` NI le mapping de statut.
**Then** `migrateDocument`/`migrateCorpus` **ne lèvent JAMAIS** (AD-10), quel que soit l'input.

**Discriminant** — une signature exposant un type backend, ou un migrateur qui `throw` sur un input dégénéré, échoue (garde de surface AC8 + fixture corrompue AC5). *(Le test drive le symbole public exporté, R27.4.)*

### AC2 — R26 : PRÉSERVATION EXACTE du contenu métier (census, pas existence)

**Given** un document legacy flat portant N clés métier (ex. `subjectId`, `folderId`, `creatorId`, `name`, `contentLength`, `pageCount`, `cloudPath`, `assistantFileId`, `status`, `createdAt`)
**When** on le migre
**Then** **CHAQUE** clé métier legacy est **retrouvable** dans la sortie canonique — soit renommée en snake_case (`subjectId`→`subject_id`), soit préservée **à l'identique** sous `_legacy_<snake>` (`preserveLegacyUnder`, ex. `status` legacy exact conservé sous `_legacy_status` AVANT remap 6→4, AD-4) — **aucune clé métier n'est silencieusement perdue**.
**Then** un **census** (ensemble des clés métier d'entrée → ensemble des clés canoniques + `_legacy_`) prouve la **couverture totale** : `businessKeysIn.length == coveredKeysOut` (les clés de sync `is_deleted`/`updated_at` sont **exclues** du census — elles sont hors-corps, AC4).

**Discriminant (R26)** — un mapping qui **droppe** une clé (ex. le migrateur oublie `assistantFileId`, ou écrase deux clés camelCase collidant en une seule snake) fait **chuter** le compte de couverture ⇒ le test **rougit** (injection `R3-I1`). Le test **nomme chaque clé** attendue, jamais un simple « la map n'est pas vide ».

### AC3 — IDEMPOTENCE : `migrate ∘ migrate = migrate` (point fixe — franchit le TRAP `status`)

**Given** un document legacy et sa forme canonique `c = migrateDocument(legacy).canonical`
**When** on **re-migre** la forme déjà canonique : `c2 = migrateDocument(c).canonical`
**Then** `c2` est **STRICTEMENT ÉGAL** à `c` (point fixe, `mapEquals` profond) — en particulier **`status` n'est PAS rétrogradé** (`ready` reste `ready`, `validating` reste `validating`), `is_deleted` n'est **pas** ré-écrasé, aucune clé snake n'est re-transformée, aucune date ISO n'est re-normalisée.
**Then** l'outcome d'une re-migration porte le drapeau **`alreadyCanonical == true`** (le corpus réel mêle docs migrés et non-migrés lors d'une reprise).

**Discriminant (TRAP central)** — un migrateur **naïf** qui ré-applique aveuglément `codec.toCanonical` (sans garde « déjà canonique » **ni** rendre `mapDocumentStatus` idempotent sur ses valeurs canoniques) **rétrograde** `ready`→`uploading` au 2ᵉ passage ⇒ `c2 != c` ⇒ le test **rougit** (injection `R3-I2`). *(Implémentation au choix du dev, documentée : détection « déjà canonique » — présence de `is_deleted` **et** aucune clé camelCase — OU value-mapper étendu acceptant les 4 valeurs canoniques comme points fixes. La garde d'idempotence, quelle qu'elle soit, doit être co-livrée avec ce test.)*

### AC4 — `ZSyncMeta` HORS-CORPS : additif, jamais dans `extra`/le corps (AD-19)

**Given** un document legacy **sans** métadonnée de sync
**When** on le migre puis on **décode** la forme canonique par une entité study (double de test défensif, aucune arête neuve — cf. `_LegacyDoc` d'ES-3.5)
**Then** le canonique porte `is_deleted:false` **ajouté de façon ADDITIVE** (`putIfAbsent` — jamais d'écrasement d'un `is_deleted` déjà présent) et **`updated_at` reste ABSENT** (→ `ZSyncMeta.updatedAt = null`, LWW « jamais synchronisé »).
**Then** après décodage, **NI `updated_at` NI `is_deleted`** n'apparaissent dans `extra` ni dans le corps de l'entité (ils sont **hors-entité**, filtrés par `ZSyncMeta.reservedKeys`) — ils ne « fuient » pas et ne sont pas réémis par `toMap()`.
**Given** un document legacy portant **déjà** `is_deleted:true` (soft-deleted côté IFFD)
**Then** la migration **PRÉSERVE** `is_deleted:true` (jamais réécrit à `false`).

**Discriminant (motif ES-2.1 H1, huitième occurrence)** — un migrateur qui **injecte** `updated_at`/`is_deleted` dans le CORPS canonique (au lieu de les laisser hors-entité) fait apparaître ces clés dans `extra` après round-trip `fromMap(toMap())` ⇒ le test « clés de sync absentes d'`extra` » **rougit** (injection `R3-I3`). Un migrateur qui **force** `is_deleted:false` sur un doc soft-deleted rougit le cas « préserve `true` ».

### AC5 — DÉFENSIF : champ corrompu/absent/mal typé ⇒ défaut sûr, JAMAIS de throw (AD-10)

**Given** un corpus contenant des documents **dégénérés** (fixtures synthétiques) : `status` `null`/inconnu/non-String ; `createdAt` `int` hors bornes plausibles (année ∉ [1970,9999]) ou type inattendu ; clés en double après snakeisation ; `Map` vide `{}` ; valeurs `null`
**When** on migre le corpus
**Then** **AUCUN throw** ne remonte (`expect(() => migrator.migrateCorpus(corpus), returnsNormally)`) ; chaque outcome porte un **défaut sûr** : `status` illisible → `uploading` (1ʳᵉ constante, AD-10) ; `createdAt` implausible → **valeur laissée intacte** (jamais une date fausse fabriquée) ; document vide → canonique `{is_deleted:false}` sans crash.
**Then** les **défauts appliqués sont COMPTÉS** dans le rapport (traçabilité de la dégradation, AC6) — jamais avalés en silence.

**Discriminant** — remplacer un défaut sûr par un `throw`/`!`/cast dur (ex. `value as int`, `DateTime.parse` non gardé) fait **rougir** la fixture corrompue (injection `R3-I4` : `expect(returnsNormally)` casse). *(Fixture `document_corrupt.json` réutilisée + étendue.)*

### AC6 — RAPPORT de migration auditable + DRY-RUN (write-back DÉFÉRÉ, DW-ES112-1)

**Given** un corpus mixte (docs legacy + docs déjà canoniques + docs dégénérés)
**When** on appelle `migrateCorpus`
**Then** il retourne un **`ZLegacyMigrationReport`** immuable exposant au minimum : `total`, `migrated`, `alreadyCanonical`, `defaultsApplied` (nombre de défauts défensifs), la **liste des `canonicalDocuments`** produits, et un **census de préservation** agrégé (aucune clé métier perdue sur l'ensemble). Le rapport permet un **audit sans perte** avant toute écriture.
**Then** la mécanique est un **DRY-RUN par construction** : `migrateCorpus` **CALCULE** la forme canonique **sans muter** l'input ni écrire nulle part — **le write-back Firestore batché est DÉFÉRÉ** à la session IFFD (dette **DW-ES112-1**). Aucun accès I/O, aucun `FirebaseFirestore`, aucun `WriteBatch` dans cette story.

**Discriminant** — un `migrateCorpus` qui **mute** un `Map` d'entrée (au lieu de produire une copie) fait rougir le test « input inchangé après migration » ; des compteurs de rapport incohérents (`migrated + alreadyCanonical != total - errors`) rougissent l'assertion d'invariant du rapport (injection `R3-I5`). Le test asserte **chaque** compteur nommément.

### AC7 — DW-ES22-2 : champs legacy IFFD spécifiques préservés sans perte (fixtures synthétiques)

**Given** un document legacy portant les champs DW-ES22-2 : `audioText` (String), `audioTextHash` (**`int`**, une empreinte — PAS une date), `subjectId`, `creatorId`, `subFolderId`
**When** on le migre
**Then** `audioText`→`audio_text` (valeur String **intacte**), `subjectId`→`subject_id`, `creatorId`→`creator_id`, `subFolderId`→`sub_folder_id`, et **`audioTextHash`→`audio_text_hash` conserve son `int` INTACT** — la clé ne finit **PAS** par `_at` donc la normalisation de date `int`→ISO **ne s'applique PAS** (un hash n'est pas une date). Round-trip `toLegacy` restitue les clés camelCase.

**Discriminant** — un migrateur qui coercerait `audioTextHash` en date (parce qu'`int`) ou dropperait `audioText` rougit le test de valeur exacte (injection `R3-I6`). *(Fixture synthétique DW-ES22-2 **fabriquée**, jamais un document IFFD réel.)*

### AC8 — Graphe INCHANGÉ (46 arêtes, CORE OUT=0) + confinement AD-27/AD-5 (aucun backend, aucune entité)

**Given** le graphe de dépendances (baseline mesurée **46 arêtes / 20 nœuds**, CORE OUT=0 — après ES-11.1) et le confinement adapter
**When** on rejoue `python3 scripts/dev/graph_proof.py` **et** les gardes de surface
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 46` (delta = 0)**, 20 nœuds : le migrateur vit dans `zcrud_firestore` (qui dépend **déjà** de `zcrud_core` + `zcrud_study_kernel`) et **n'ajoute AUCUNE** arête — en particulier **aucune** vers un package d'ENTITÉ (`zcrud_document`/`note`/`exam`/`session`/`flashcard`/`mindmap`), le migrateur étant **générique par `Map`** (R28).
**Then** **`dart run melos run analyze` ET `dart run melos run verify` REPO-WIDE = VERT** (`gate:reserved-keys`, `gate:secrets`, `gate:web`, `codegen-distribution`, `verify:serialization`, frontière EX-3) ; le nouveau corpus de migration s'exécute sous le tag `serialization-compat` du gate `verify:serialization`.

**Discriminant (R28/AD-5)** — ajouter dans `z_study_migrator.dart` un `import 'package:cloud_firestore/…'`/`package:hive/…` (en CODE, hors dartdoc) ou une dep d'entité au pubspec ⇒ la garde de surface **rougit** et/ou `graph_proof` diverge / `melos verify` casse (injection `R3-I7`).

---

## Tasks / Subtasks

- [x] **T1 — `ZLegacyStudyMigrator` : migrateur de corpus pur/défensif/idempotent** — `packages/zcrud_firestore/lib/src/data/z_study_migrator.dart` (**NOUVEAU**) (AC1/AC2/AC3/AC5)
  - [x] `migrateDocument(Map<String,dynamic> legacy) → ZDocumentMigrationOutcome` : **détecte « déjà canonique »** (présence de `is_deleted` **ET** aucune clé camelCase) → passe **inchangé** (`alreadyCanonical:true`, AC3) ; sinon **compose** `ZStudyLegacyCodec.toCanonical` (config IFFD `valueMappers:{'status': ZStudyLegacyCodec.mapDocumentStatus}`, `preserveLegacyUnder:{'status'}`). **Jamais de throw** (AD-10, défensif PAR CONSTRUCTION — aucun blanket catch). **Ne mute pas** l'input (copie défensive).
  - [x] Garantir l'**idempotence** (AC3) : point fixe `migrate(migrate(x)) == migrate(x)`. **Stratégie retenue : garde « déjà canonique »** (`is_deleted` présent ET aucune clé camelCase) → traversée inchangée. Le codec ES-3.5 reste INCHANGÉ (son test reste vert).
  - [x] `migrateCorpus(Iterable<Map>) → ZLegacyMigrationReport` : itère, agrège compteurs + census + docs canoniques ; **aucune I/O**.
  - [x] Signatures **`Map<String,dynamic>` uniquement** (AD-5) — aucun type `cloud_firestore`/`hive`.
  - [x] Dartdoc : confinement AD-27 ; DRY-RUN (write-back déféré DW-ES112-1) ; TRAP idempotence `status` explicité.

- [x] **T2 — Types de rapport immuables** — `ZDocumentMigrationOutcome`, `ZLegacyMigrationReport` (mêmes fichier/lib) (AC2/AC5/AC6)
  - [x] `ZDocumentMigrationOutcome` : `canonical` (`Map<String,dynamic>`), `alreadyCanonical` (`bool`), `defaultsApplied` (`List<String>` des champs dégradés), census par-doc (`businessKeysIn`/`coveredBusinessKeys`/`isPreservationComplete`/`lostBusinessKeys`).
  - [x] `ZLegacyMigrationReport` : `total`, `migrated`, `alreadyCanonical`, `defaultsApplied`, `canonicalDocuments`, census agrégé (`preservedAllBusinessKeys`/`lostBusinessKeys`) ; invariant `isConsistent` = `migrated + alreadyCanonical == total` ; `const`/immuable.

- [x] **T3 — Barrel** — `lib/zcrud_firestore.dart` (AC1)
  - [x] `export 'src/data/z_study_migrator.dart';` (à côté de l'export existant `z_study_codec.dart`). Exports ES-3.5 inchangés.

- [x] **T4 — Fixtures synthétiques étendues** — `packages/zcrud_firestore/test/fixtures/iffd_legacy/` (**AUCUNE donnée IFFD réelle**) (AC2/AC3/AC5/AC7)
  - [x] `document_flat_full.json` : doc legacy « riche » (toutes les clés métier de l'AC2) — census R26.
  - [x] `document_dw_es22_2.json` : `audioText`/`audioTextHash:int`/`subFolderId` — AC7.
  - [x] `document_soft_deleted.json` : `is_deleted:true` legacy — AC4 (préservation `true`).
  - [x] Réutiliser `document_corrupt.json`/`document_unknown_status.json` + fixtures inline (int date hors bornes, `{}` vide, `null`) pour AC5.

- [x] **T5 — Tests `flutter test` (R14)** — `packages/zcrud_firestore/test/z_study_migrator_test.dart` (**NOUVEAU**, tag `@Tags(['serialization-compat'])` pour le gate `verify:serialization`)
  - [x] **AC2 (R26 census)** : chaque clé métier nommée → présente (snake ou `_legacy_`) ; couverture totale ; drop d'une clé ⇒ RED (R3-I1 PROUVÉ).
  - [x] **AC3 (idempotence)** : `migrateDocument(c).canonical == c` (point fixe, `_deepEquals`) ; `status ready` non rétrogradé ; `alreadyCanonical:true` ; naïf ⇒ RED (R3-I2 PROUVÉ).
  - [x] **AC4 (ZSyncMeta hors-corps)** : `is_deleted:false` additif ; `updated_at` absent ; décode via double `_StudyDouble` défensif → ni `updated_at` ni `is_deleted` dans `extra`/corps après `fromMap(toMap())` ; `is_deleted:true` préservé ; force `false` ⇒ RED (R3-I3 PROUVÉ).
  - [x] **AC5 (défensif)** : corpus dégénéré ⇒ `returnsNormally` ; défauts sûrs comptés ; hard cast ⇒ RED (R3-I4 PROUVÉ).
  - [x] **AC6 (rapport/dry-run)** : compteurs nommés cohérents ; input **non muté** ; mutation ⇒ RED (R3-I5 PROUVÉ).
  - [x] **AC7 (DW-ES22-2)** : `audio_text` String intacte, `audio_text_hash` **int intact** (pas de coercion date), round-trip camelCase ; drop ⇒ RED (R3-I6 PROUVÉ).

- [x] **T6 — Garde de surface backend/entité (AC8)** — `packages/zcrud_firestore/test/z_study_migrator_isolation_test.dart` (**NOUVEAU**)
  - [x] Scan de `lib/src/data/z_study_migrator.dart` (commentaires strippés) : **aucun** symbole backend (`cloud_firestore`/`FirebaseFirestore`/`WriteBatch`/`hive`/`Box`) en code ; scan pubspec : aucune dep entité neuve. Import backend en code ⇒ RED (R3-I7 PROUVÉ).

- [x] **T7 — Vérif verte rejouée** + MAJ File List / Dev Agent Record / Change Log. Suites ES-3.5 (`z_study_legacy_codec_test.dart`) et tout `zcrud_firestore/test/*` restent **VERTES** (codec non touché) — 209 tests verts.

---

## Injections R3 prévues (mutation → AC rouge → restauration) — verrous LOAD-BEARING

> **R27** : chaque garde est **co-livrée** avec le test qui rougit sous sa neutralisation. **R27.4** : les injections visent le **symbole public** exporté (`ZLegacyStudyMigrator.migrateDocument`/`migrateCorpus`), pas un helper interne.

- **R3-I1 (AC2 — R26 census)** — dans `migrateDocument`, dropper une clé métier (ex. filtrer `assistantFileId`, ou fusionner deux clés en écrasant) ⇒ le census de couverture chute ⇒ le test R26 rougit.
- **R3-I2 (AC3 — idempotence, TRAP `status`)** — retirer la garde « déjà canonique » **et** ne pas rendre le status-mapper idempotent ⇒ `migrate(migrate(x))` rétrograde `ready`→`uploading` ⇒ le test de point fixe rougit.
- **R3-I3 (AC4 — ZSyncMeta hors-corps)** — injecter `updated_at`/`is_deleted` dans le corps canonique (au lieu de les laisser hors-entité) ⇒ après `fromMap(toMap())` du double d'entité, ces clés apparaissent dans `extra` ⇒ le test « clés de sync absentes d'`extra` » rougit. Variante : forcer `is_deleted:false` ⇒ le cas « préserve `true` » rougit.
- **R3-I4 (AC5 — défensif)** — remplacer un défaut sûr par un `throw`/cast dur (`value as int`, `DateTime.parse` non gardé) ⇒ la fixture corrompue casse `returnsNormally`.
- **R3-I5 (AC6 — rapport/dry-run)** — muter le `Map` d'entrée dans `migrateCorpus` (au lieu d'une copie) ⇒ le test « input inchangé » rougit ; fausser un compteur ⇒ l'invariant `migrated+alreadyCanonical==total` rougit.
- **R3-I6 (AC7 — DW-ES22-2)** — coercer `audioTextHash` (int) en date, ou dropper `audioText` ⇒ le test de valeur exacte rougit.
- **R3-I7 (AC8 — confinement/graphe)** — ajouter `import 'package:cloud_firestore/…'` (en code) dans le migrateur, ou une dep entité au pubspec ⇒ la garde de surface rougit / `graph_proof` diverge (≠ 46) / `melos verify` casse.

---

## Dev Notes

### Forme d'API retenue (guardrail — éviter la sur-ingénierie ET le sous-dimensionnement)

- **Composer, pas réécrire** : `ZLegacyStudyMigrator` **utilise** `ZStudyLegacyCodec` (injecté ou construit avec la config IFFD). Il n'ajoute QUE (1) la **garde d'idempotence** (détection « déjà canonique »), (2) le **census R26**, (3) l'**agrégation en rapport**, (4) le **DRY-RUN**. La casse/valeur reste au codec (AD-27).
- **Détection « déjà canonique »** (recommandée, générique) : un doc est déjà canonique s'il porte `is_deleted` **et** n'a **aucune** clé camelCase (majuscule interne). Robuste au-delà du seul `status`. Alternative/complément : rendre `mapDocumentStatus` **idempotent** en acceptant `ready`/`validating`/`uploading`/`rejected` comme **points fixes** (additif, sûr) — utile si un doc partiellement migré porte un statut canonique mais des clés camelCase. **Documenter le choix.**
- **DRY-RUN par construction** : `migrateCorpus` **calcule** sans écrire. Le **write-back** (lecture Firestore → `WriteBatch` ≤ 450/lot → `serverTimestamp` pour `updated_at`) est **DÉFÉRÉ** (DW-ES112-1) : il vit côté session IFFD, PAS ici. Ne PAS ajouter d'I/O ni de `FirebaseFirestore` dans cette story.
- **Double d'entité de test** : réutiliser le patron `_LegacyDoc` d'ES-3.5 (`z_study_legacy_codec_test.dart`) — décodeur **défensif** vivant ENTIÈREMENT dans le test, **aucune** arête runtime neuve (les statuts sont assertés par **noms d'enum String**, pas d'import `ZDocumentStatus`).

### Invariants AD applicables (rappel, NON-NÉGOCIABLES)

- **AD-1** — graphe acyclique, CORE OUT=0 ; **baseline 46 arêtes, delta = 0** (migrateur dans `zcrud_firestore`, deps déjà présentes) ; **R28 : aucune entité** (générique par `Map`).
- **AD-5** — aucun type backend (`cloud_firestore`/`hive`) dans une signature publique ; migrateur = `Map<String,dynamic>` in/out.
- **AD-10** — DÉFENSIF : jamais de throw ; champ corrompu → défaut sûr, tracé au rapport.
- **AD-19** — `ZSyncMeta` hors-entité : `is_deleted` additif, `updated_at` absent, jamais dans `extra`/le corps.
- **AD-27** — mapping legacy dans l'ADAPTER (`zcrud_firestore`), jamais dans le domaine ; migration = chantier prouvé sans perte ; gate CI corpus legacy.
- **R26** — préservation exacte du contenu métier (census discriminant).
- **R14/R15** — `zcrud_firestore` est **Flutter** ⇒ `flutter test` ; RC capturé **hors pipe** (`; echo "RC=$?"`).

### Ne rien réinventer / ne rien casser (régression)

- Réutiliser `ZStudyLegacyCodec` (ES-3.5) **tel quel** — le migrateur s'ajoute, il ne modifie NI le codec NI son test (`z_study_legacy_codec_test.dart` reste VERT). Si le status-mapper doit devenir idempotent (option AC3), **étendre** additivement (nouveaux points fixes) **sans** casser les cas 6→4 existants — le test ES-3.5 doit rester vert.
- Le migrateur ne touche PAS `firebase_z_repository_impl.dart`/`firestore_z_remote_store.dart`/`hive_z_local_store.dart` (write-path/I/O) — chantier write-back déféré.

### Project Structure Notes

- **NOUVEAUX (lib)** : `packages/zcrud_firestore/lib/src/data/z_study_migrator.dart`.
- **NOUVEAUX (test)** : `test/z_study_migrator_test.dart`, `test/z_study_migrator_isolation_test.dart`, fixtures `test/fixtures/iffd_legacy/{document_flat_full,document_dw_es22_2,document_soft_deleted}.json`.
- **MODIFIÉS** : `lib/zcrud_firestore.dart` (1 export), éventuellement `z_study_codec.dart` **si** l'option « status-mapper idempotent » est retenue (extension additive uniquement).
- **INCHANGÉS** (ne pas toucher) : tout `lib/src/data/*` d'I/O, `zcrud_core/*`, `zcrud_study_kernel/*`, tout autre package. **AUCUN** fichier hors `zcrud_firestore`.
- Aucune `@ZcrudModel`/`@JsonSerializable` nouvelle ⇒ **aucun `*.g.dart` nouveau** attendu (rejouer `melos run generate` par prudence).

### Dette anticipée

- **DW-ES112-1 (session IFFD dédiée)** — exécution de la mécanique sur les **données IFFD RÉELLES** : (1) lecture des collections Firestore flat top-level IFFD ; (2) **write-back** batché (`WriteBatch` ≤ 450/lot, AD-9) de la forme canonique produite par `ZLegacyStudyMigrator` ; (3) normalisation d'horloge (`serverTimestamp()` pour `updated_at` à l'écriture) ; (4) cutover repo-par-repo + validation sur corpus RÉEL + audit du `ZLegacyMigrationReport`. **Aucun fichier IFFD touché dans ES-11.2** (frontière de périmètre). Marqueur dartdoc `DW-ES112-1` sur le migrateur.
- **DW-ES22-2 (rappelée, à l'adapter)** — mapping legacy IFFD (camelCase/`Timestamp`/`audioText`/`audioTextHash:int`) : soldée côté mécanique par AC7 sur fixtures synthétiques ; l'application au corpus réel relève de DW-ES112-1.

### References

- [Source: epics-zcrud-study-2026-07-12/epics.md#Epic-ES-11 / Story-ES-11.2] — FR-S34 (migration IFFD flat→canonique + `ZSyncMeta` additif), dépend d'ES-10/ES-11.1, mapping camelCase↔snake **uniquement** dans le codec `zcrud_firestore` (AD-20/AD-27).
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-27] — migration flat→canonique = chantier explicite prouvé **sans perte** ; mapping dans l'adapter, jamais le domaine ; `ZSyncMeta` additif rétro-compatible ; gate CI corpus legacy défensif.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-19] — `ZSyncMeta` hors-entité universel ; merge LWW sur `updated_at` ; `is_deleted` extrait hors-corps.
- [Source: architecture-zcrud-2026-07-09/architecture.md#AD-10/AD-5/AD-1] — désérialisation défensive (jamais de throw) ; domaine backend-agnostique (aucun type `cloud_firestore` en signature) ; graphe acyclique CORE OUT=0.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#Dettes / DW-ES22-2] — mapping legacy IFFD (camelCase, `Timestamp`, `audioText`, `subjectId`/`creatorId`, `audioTextHash:int`) dû à l'adapter (ES-3.5/ES-11.2), jamais au domaine.
- [Source: epic-es-9-retrospective.md#R26] — préservation exacte du contenu métier ; un mapping qui droppe un champ doit rougir (census discriminant, pas existence).
- [Source: epic-es-10-retrospective.md#R27.4/R28] — le verrou vise le symbole public consommé ; l'adapter/migrateur reste générique (aucune entité).
- [Source: packages/zcrud_firestore/lib/src/data/z_study_codec.dart] — `ZStudyLegacyCodec` (ES-3.5) : `toCanonical`/`toLegacy`/`mapDocumentStatus`/`camelToSnake`/`snakeToCamel` — brique par-document à COMPOSER (TRAP idempotence `status` documenté).
- [Source: packages/zcrud_firestore/test/z_study_legacy_codec_test.dart] — patron de test corpus (`@Tags(['serialization-compat'])`, fixtures `iffd_legacy/*.json`, double `_LegacyDoc` défensif sans arête neuve).
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart] — `ZSyncMeta` (`kUpdatedAt`/`kIsDeleted`/`reservedKeys`) : source unique des clés de sync (DW-ES13-1 soldée).

---

## Vérif verte à rejouer (avant tout `review`/`done`) — RC HORS pipe (R15)

> Rejouée **réellement sur disque** par l'orchestrateur, jamais sur la foi du rapport dev.

1. **Codegen** — `dart run melos run generate` (aucun nouveau `*.g.dart` attendu ; confirme que rien n'est cassé).
2. **Analyze ciblé** — `dart analyze packages/zcrud_firestore` → **RC=0** (0 issue).
3. **Tests (R14)** — `flutter test packages/zcrud_firestore; echo "RC=$?"` → **RC=0**. Attendu : suites ES-3.5 existantes (codec, corpus legacy) **inchangées vertes** + 2 nouvelles suites (migrateur : census R26, idempotence, ZSyncMeta hors-corps, défensif, rapport/dry-run, DW-ES22-2 ; isolation backend/entité).
4. **Graphe (AC8)** — `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 46` (delta = 0)**, 20 nœuds ; **aucune** arête neuve (surtout pas vers une entité).
5. **`dart run melos list`** — sanity (20 packages).
6. **Gates repo-wide (AC8, NON-NÉGOCIABLE R28/R9)** — `dart run melos run analyze` **ET** `dart run melos run verify` REPO-WIDE → **VERT** (`gate:reserved-keys`, `gate:secrets`, `gate:web`, `codegen-distribution`, `verify:serialization` — le nouveau corpus de migration s'y exécute sous le tag `serialization-compat` ; frontière EX-3 : `example/` résout, aucune entité déférée tirée). La vérif ciblée d'un package NE détecte PAS une régression cross-package.
7. **Frontière de périmètre** — `git status` : AUCUN fichier hors `packages/zcrud_firestore/**` + ce fichier story ; aucun fichier IFFD/lex/dodlp ; aucun autre repo touché.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill réel invoqué via tool Skill).

### Debug Log References

- Injections R3 rejouées réellement (mutation source → AC ciblé RED RC=1 → restauration `diff` identique) : R3-I1 (census, AC2), R3-I2 (idempotence TRAP `status`, AC3), R3-I3 (ZSyncMeta hors-corps, AC4), R3-I4 (défensif hard-cast, AC5), R3-I5 (mutation input DRY-RUN, AC6), R3-I6 (drop `audioText`, AC7), R3-I7 (import backend, isolation AC8). Les 7 gardes sont LOAD-BEARING.

### Completion Notes List

- **`ZLegacyStudyMigrator`** (NOUVEAU, `lib/src/data/z_study_migrator.dart`) COMPOSE `ZStudyLegacyCodec` (ES-3.5, INCHANGÉ) ; ajoute uniquement (1) garde d'idempotence, (2) census R26, (3) rapport auditable, (4) DRY-RUN. Signatures `Map<String,dynamic>` uniquement (AD-5).
- **Stratégie d'idempotence** : détection « déjà canonique » = `is_deleted` présent ET aucune clé camelCase → traversée inchangée. Franchit le TRAP `mapDocumentStatus('ready') → default 'uploading'` sans modifier le codec (option « garde », pas « value-mapper étendu » — le codec ES-3.5 reste intact, son test 64→reste vert).
- **Défensif PAR CONSTRUCTION** (aucun blanket try/catch) : le migrateur ne throw jamais (helpers type-gardés + codec non-throwant), ce qui PRÉSERVE le pouvoir discriminant de R3-I4 (un hard-cast injecté remonte réellement → RED).
- **Census R26** calculé sur l'entrée ORIGINALE non mutée → tout drop dans le pipeline reste détectable.
- `ZDocumentMigrationOutcome` / `ZLegacyMigrationReport` immuables (compteurs + census + `canonicalDocuments` ; write-back DÉFÉRÉ DW-ES112-1).
- **DW-ES112-1 à ESCALADER** (orchestrateur) : exécution sur collections Firestore RÉELLES IFFD + write-back batché — hors périmètre (aucun fichier IFFD/lex/dodlp touché ; marqueur dartdoc posé sur le migrateur).
- Aucun `*.g.dart` nouveau (aucune annotation neuve). Graphe INCHANGÉ (46 arêtes / 20 nœuds, CORE OUT=0, delta=0).

### File List

**NOUVEAUX (lib)**
- `packages/zcrud_firestore/lib/src/data/z_study_migrator.dart`

**NOUVEAUX (test)**
- `packages/zcrud_firestore/test/z_study_migrator_test.dart`
- `packages/zcrud_firestore/test/z_study_migrator_isolation_test.dart`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_flat_full.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_dw_es22_2.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_soft_deleted.json`

**MODIFIÉS**
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (1 export ajouté)

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-16 | 0.1 | Story créée (bmad-create-story, skill réel) — mécanique de migration RÉUTILISABLE zcrud-side (`ZLegacyStudyMigrator` composant `ZStudyLegacyCodec`) ; R26 census / idempotence (TRAP `status`) / ZSyncMeta hors-corps / défensif / rapport dry-run / DW-ES22-2 ; exécution données réelles DÉFÉRÉE (DW-ES112-1) ; graphe delta=0 — statut ready-for-dev | create-story |
| 2026-07-16 | 0.2 | Implémentation (bmad-dev-story, skill réel) — `ZLegacyStudyMigrator` + `ZDocumentMigrationOutcome`/`ZLegacyMigrationReport` (composent le codec ES-3.5 inchangé), garde d'idempotence « déjà canonique », census R26, rapport DRY-RUN, 3 fixtures synthétiques, 2 suites de tests (migrateur + isolation). 7 injections R3 prouvées LOAD-BEARING. Vérif verte : `dart analyze` 0 issue ; `flutter test` zcrud_firestore 209 verts (ES-3.5 codec inclus) ; `graph_proof` 46 arêtes/20 nœuds delta=0 ; `melos run analyze` + `melos run verify` REPO-WIDE VERTS (migrateur exécuté sous `verify:serialization`). Confinement `zcrud_firestore` seul ; aucun fichier IFFD/lex/dodlp. Statut → review | dev-story |
