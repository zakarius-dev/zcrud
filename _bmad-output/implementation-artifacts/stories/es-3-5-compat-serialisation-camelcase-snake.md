---
baseline_commit: 8c0cf418a5a6861d8b042d6e0df43d08ceefcd5e
---

# Story ES-3.5 : Compat de sérialisation camelCase↔snake_case + `ZSyncMeta` additif + gate CI ENFORCED (corpus IFFD legacy)

Status: review

<!-- Epic ES-3 : Ports & couche data offline-first bi-topologie. DERNIÈRE story d'ES-3. -->
<!-- FR-S16 · NFR-S4 · AD-27 / AD-10 / AD-3 / AD-5 / AD-11 / AD-4 / AD-9 · SM-S6. -->
<!-- Solde DW-ES21-1 (mapping legacy IFFD 6 statuts → 4 canoniques, AD-27). -->
<!-- COMPOSE le décodage contextualisé ES-3.0 (ZDecodeContext) + l'adaptateur E5-1/ES-3.2 (FirebaseZRepositoryImpl `_inject`/`_normalizeIsoInPlace`). -->
<!-- Package : zcrud_firestore (codec `z_study_codec.dart` + fixtures + corpus). Test-only additif : zcrud_study_kernel (corpus — hook déjà déclaré). Micro-ajustement SIGNALÉ : scripts/ci/verify_serialization.dart (population = tag-declarers). Wiring CI : melos.yaml + pubspec.yaml (env var). -->
<!-- Ne touche PAS le LIB de zcrud_core/kernel ; ne touche PAS le sprint-status. -->

## Story

As a **développeur intégrateur IFFD** (qui doit lire des documents Firestore **historiques** écrits par l'app IFFD legacy — clés **camelCase**, statuts d'un cycle de vie **conversion/embedding** à 6 valeurs, dates en `Timestamp` natif **ou** en `int` millis, **aucune** métadonnée de sync `updated_at`/`is_deleted` — et les décoder dans les entités canoniques zcrud **sans perte ni exception**, le mapping de casse ne fuyant **jamais** dans le domaine),
I want **un codec/normaliseur d'adaptateur dans `zcrud_firestore` (`ZStudyLegacyCodec`, `z_study_codec.dart`) qui fait le mapping bidirectionnel camelCase↔snake_case, réconcilie le mapping legacy IFFD 6 statuts → 4 canoniques (DW-ES21-1), ajoute `ZSyncMeta` de façon additive rétro-compatible, normalise l'asymétrie d'horloge et les dates bi-format — le tout DÉFENSIF (AD-10 : jamais un throw, jamais une destruction), plus le CORPUS de fixtures historiques réelles taggé `@Tags(['serialization-compat'])` qui ARME le gate `verify:serialization` (aujourd'hui à vide → warning bruyant)**,
so that **migrer/lire des documents IFFD legacy bascule sur défauts sûrs sans perte ni throw, que le gate CI de rétro-compatibilité passe de WARNING à ENFORCED sous `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` (le corpus PROUVANT réellement son pouvoir discriminant), et que la dette DW-ES21-1 soit soldée avec un mapping déterministe, documenté et testé exhaustivement (les 6 entrées → la bonne sortie, + inconnu → défaut sûr).**

---

## Contexte & problème mesuré

### 1. La divergence de forme entre le legacy IFFD et le canonique zcrud (MESURÉE sur disque)

L'entité IFFD de référence est **`FolderDocument`** (`/home/zakarius/DEV/iffd/lib/src/domain/models/folder_document.dart`) :

- **Clés camelCase** (`toMap`, l.107-122 + super) : `id`, `subjectId`, `folderId`, `subFolderId`, `creatorId`, `createdAt`, `name`, `type`, `content`, `contentLength`, `pageCount`, `status`, `cloudPath`, `cloudUrl`, `assistantFileId`. Le canonique zcrud persiste en **snake_case** (AD-3 `fieldRename: snake` : `subject_id`, `folder_id`, `sub_folder_id`, `creator_id`, `created_at`, `content_length`, `page_count`, `cloud_path`, `cloud_url`, `assistant_file_id`). **Un document camelCase legacy relu par un `fromMap` généré snake_case ⇒ TOUS les champs renommés reviennent `null`/défaut** (perte silencieuse).
- **`createdAt` bi-format + `int` millis** (`fromMap`, l.141-145) : `Timestamp` natif **OU** `int` (millisecondsSinceEpoch) **OU** repli `DateTime.now()`. Le canonique lit du **ISO-8601 String** (ou `Timestamp` normalisé par l'adaptateur). Le cas **`int` millis** n'est **PAS** couvert par `_normalizeIsoInPlace` (voir §3) — gap DW-ES32-1 adressable ici.
- **Aucune `ZSyncMeta`** : un document IFFD legacy ne porte **ni** `updated_at` **ni** `is_deleted`. Or l'adaptateur canonique **exige** `is_deleted == false` pour la visibilité (filtre serveur + `_isVisible`, cf. `firebase_z_repository_impl.dart:404-411`) : **un document sans `is_deleted` est EXCLU de TOUS les chemins de lecture** (getById/getAll/watch). Sans ajout additif d'`is_deleted:false`, **toute la donnée IFFD legacy est INVISIBLE**.
- **Enum `FolderDocumentStatus` à 6 valeurs** (l.57-63) : `uploading, uploaded, converting, converted, embedding, embedded` — un cycle de vie **conversion / embedding IA app-spécifique**. Le canonique `ZDocumentStatus` (`packages/zcrud_document/lib/src/domain/z_document_status.dart:33-45`) n'en porte **4** : `uploading, validating, ready, rejected`. Le repli 6→4 est du **mapping legacy d'adaptateur** (AD-27), **jamais** dans le domaine (le dartdoc de `ZDocumentStatus`, l.8-10, l'annonce explicitement : « Dette **DW-ES21-1**, épinglée par un test »).

### 2. Le mapping 6→4 déterministe (DW-ES21-1) — dérivé des GETTERS SÉMANTIQUES d'IFFD (mesurés)

`FolderDocumentStatus` porte ses propres invariants sémantiques (l.65-68) :
- `isProcessing => uploading || converting || embedding` (travail backend en cours) ;
- `ready => uploaded || converted || embedded` (consultable) ;
- `readyForChat => embedded` (granularité IA — **app-spécifique**, va dans `extra`/`ZExtension`, AD-4, PAS dans le statut canonique).

Le canonique `ZDocumentStatus` a exactement la même dichotomie (l.47-50 `isProcessing => uploading || validating`). Le mapping **déterministe et documenté** (les 3 replis de `ZDocumentStatus` NE sont PAS équivalents, cf. dartdoc D5 : `uploading` = « Traitement… », ne ment ni ne détruit ; c'est la **1ʳᵉ constante** donc le **défaut défensif** de `T.values.first`) :

| Legacy IFFD (6) | Canonique `ZDocumentStatus` (4) | Justification (getters IFFD) |
|---|---|---|
| `uploading` | `uploading` | envoi d'octets en cours |
| `converting` | `validating` | `isProcessing` (backend en cours) → « Traitement… » |
| `embedding` | `validating` | `isProcessing` (backend en cours) |
| `uploaded` | `ready` | `ready` getter IFFD (consultable) |
| `converted` | `ready` | `ready` getter IFFD |
| `embedded` | `ready` | `ready` getter IFFD (+ `readyForChat` app-spécifique → `extra`) |
| absent / `null` / inconnu / non-`String` | `uploading` | **défaut défensif** = 1ʳᵉ constante `ZDocumentStatus` (AD-10 ; ne ment ni ne détruit ; jamais throw) |

- **4 sorties canoniques** ; `rejected` n'est **jamais** produit par le legacy (état transitoire jamais persisté côté IFFD).
- **Aucune perte** : la valeur legacy exacte (`embedded`, `readyForChat`) — la granularité conversion/embedding — est **préservée** dans `extra` (AD-4) par le codec (clé de survie `_legacy_status` ou équivalent), jamais détruite (AD-10).

### 3. Ce qui existe DÉJÀ (à COMPOSER, PAS à dupliquer — AD-4)

- **`FirebaseZRepositoryImpl._inject` / `_normalizeIsoInPlace`** (`firebase_z_repository_impl.dart:304-348`) : normalise DÉJÀ, **avant tout décodage**, les dates lues en **`Timestamp` natif**, **`DateTime`**, et map **`{_seconds,_nanoseconds}`** → String ISO-8601, pour les clés `ZSyncMeta.reservedKeys` (inconditionnel) + `_timestampFields` (hint B14). **Tolérance bi-format `Timestamp` OU String déjà en place.** ⚠️ **Le cas `int` millis (IFFD `createdAt: int`) N'EST PAS géré** — le codec ES-3.5 le comble (§ D6, DW-ES32-1).
- **`ZSyncMeta`** (`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`) : `fromJson` **défensif** (l.70-75) — `updated_at` absent/mal formé → `updatedAt: null` ; `is_deleted` absent/non-`bool` → `isDeleted: false`. Clés `updated_at`/`is_deleted` (snake, ISO). `stripReserved` (l.52-56) isole le corps métier.
- **`ZDecodeContext` + voie registre `fromRegistry`** (ES-3.0, `firebase_z_repository_impl.dart:181-200`, `z_decode_context.dart`) : la voie `registry.decode(kind, map)` type DÉJÀ `extension`/`source` défensivement. Le codec ES-3.5 se **branche EN AMONT** de `fromMap`/`decode` (normalise la map **avant** le décodage) — il **compose**, il ne re-décode rien.
- **`ZFlashcardSource.fromJson`** (`packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:55-88`) : **diverge volontairement** de la source lex (qui lève `FormatException`) → `kind` inconnu ⇒ `ZCustomSource` conservant le payload ; `kind` absent ⇒ `null` ; **jamais** de throw (AD-10). Cette divergence EST déjà livrée ; ES-3.5 l'**épingle par le corpus** (test, sans toucher son lib).
- **Corpus generator EXISTANT** : `packages/zcrud_generator/test/serialization_compat_test.dart` + `serialization_corpus_test.dart` (`@Tags(['serialization-compat'])`) — la voie codegen défensive est DÉJÀ couverte et VERTE. ES-3.5 **ne la touche pas**.

### 4. Le gate `verify:serialization` — état MESURÉ et ce qu'il exige pour passer à ENFORCED

`scripts/ci/verify_serialization.dart` (lu intégralement) :
- itère **`packages/*/` ayant un dossier `test/`** (18 packages mesurés) ;
- pour chacun, exécute `<runner> test --tags serialization-compat` (`runner` = `flutter` si package Flutter — dont `zcrud_firestore` —, sinon `dart`) ;
- **`exit 79`** (« aucun test taggé ») ⇒ package ajouté à `skipped` (**PROUVÉ empiriquement** : `dart test --tags serialization-compat` dans `zcrud_document` retourne **EXIT=79**) ;
- si `skipped` non vide ⇒ **bannière bruyante** (RC reste 0) — **SAUF** sous `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`, où **tout** package `skipped` fait **RC=1** (`l.150-155`, « Interrupteur ES-3.5 »).

**État courant mesuré** : sur 18 packages avec `test/`, **UN SEUL** (`zcrud_generator`) a un test taggé ; le tag `serialization-compat` est **déclaré** dans `packages/zcrud_generator/dart_test.yaml` **et** `packages/zcrud_study_kernel/dart_test.yaml` (ce dernier dit noir sur blanc : « **ES-3.5 sèmera le corpus** puis activera `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` en CI — sans toucher au script ni au workflow »). Les 17 autres sont `skipped`.

➡️ **Conséquence dure** : tel quel, rendre le gate VERT sous l'interrupteur **repo-wide** imposerait un test taggé dans **CHACUN** des 18 packages — dont 9 **sans aucune entité persistée** (`zcrud_geo`, `zcrud_intl`, `zcrud_list`, `zcrud_mindmap`, `zcrud_export`, `zcrud_get`, `zcrud_riverpod`, `zcrud_provider`, `zcrud_annotations`). Y injecter une fixture serait un **corpus POWERLESS** (ne discrimine RIEN) — **interdit par R12**. La bonne réponse est un **micro-ajustement SIGNALÉ** du gate (§ D7).

### 5. Le piège à contrer (motif dominant — R12 / DW-ES25-1)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Risques spécifiques, chacun avec sa garde discriminante (AC + injection R3) :
1. un codec « camelCase→snake » **inerte** (identité) : le champ renommé revient `null`/défaut sans qu'aucun test ne rougisse — donnée legacy perdue ;
2. un mapping 6→4 où **un** des 6 statuts mappe vers la **mauvaise** sortie (ou l'inconnu vers autre chose qu'`uploading`) sans test rouge ;
3. un « défensif » **décoratif** : un doc corrompu **throw** au lieu de dégrader ;
4. un « ajout additif `ZSyncMeta` » **oublié** : le doc legacy reste **invisible** (`is_deleted` absent) ;
5. un **corpus POWERLESS** (fixture triviale) qui « arme » le gate sans rien discriminer — le gate passe vert même codec cassé ;
6. le gate déclaré « ENFORCED » alors qu'il reste en **warning** (interrupteur jamais posé) — faux vert structurel exact que combat ES-1.4.

### 6. Ce que cette story NE fait PAS

- **Ne mappe JAMAIS la casse dans le domaine** (AD-27/NFR-S3) : le codec vit **exclusivement** dans `zcrud_firestore`. Aucun `@JsonKey` camelCase, aucun renommage dans `zcrud_core`/kernel/entités.
- **Ne ré-implémente PAS** `_inject`/`_normalizeIsoInPlace` (composé) ni le décodage défensif de l'adaptateur ni `ZDecodeContext` (ES-3.0).
- **Ne modifie PAS** le LIB de `zcrud_core`/`zcrud_study_kernel`/`zcrud_document`/`zcrud_flashcard` (leur décodage défensif est déjà livré) — seuls des **tests** additifs y sont éventuellement ajoutés (kernel corpus, § D5).
- **Ne fait PAS** la migration flat→canonique elle-même (chantier ES-11.2) : ES-3.5 fournit le **codec** + le **corpus de validation**, pas l'outil de bascule côté app.
- **Ne RÉÉCRIT PAS** `verify_serialization.dart` : **micro-ajustement SIGNALÉ** uniquement (§ D7).
- **N'écrit PAS** le sprint-status (responsabilité de l'orchestrateur).

---

## Décisions structurantes

### D1 — Le codec `ZStudyLegacyCodec` (`packages/zcrud_firestore/lib/src/data/z_study_codec.dart`) — normaliseur PUR de `Map`, bidirectionnel, DÉFENSIF, confiné adapter (AD-27/AD-5/AD-10)

Une classe **sans état** (ou fonctions pures) opérant **uniquement** sur `Map<String, dynamic>` (aucun type `cloud_firestore` en signature publique — AD-5) :

```
class ZStudyLegacyCodec {
  const ZStudyLegacyCodec({
    Map<String, String Function(Object?)> valueMappers = const {}, // ex. {'status': ZStudyLegacyCodec.mapDocumentStatus}
    Set<String> preserveLegacyUnder = const {},  // clés dont la valeur legacy exacte est conservée dans `extra` (AD-4)
  });

  /// Legacy (camelCase) → canonique (snake_case). DÉFENSIF : jamais throw ; clé
  /// inconnue → transformée + conservée (additif AD-10) ; ajoute is_deleted:false
  /// (+ updated_at si absent) de façon ADDITIVE (ZSyncMeta rétro-compat).
  Map<String, dynamic> toCanonical(Map<String, dynamic> legacy);

  /// Canonique (snake_case) → legacy (camelCase). Round-trip de migration/interop.
  Map<String, dynamic> toLegacy(Map<String, dynamic> canonical);

  /// Mapping DÉTERMINISTE 6→4 (DW-ES21-1) — String legacy → String enum canonique.
  static String mapDocumentStatus(Object? legacy); // voir table §2
}
```

- **Transform de casse GÉNÉRIQUE** (pas une table par entité à maintenir) : `camelToSnake` (insère `_` avant chaque majuscule, minusculise) / `snakeToCamel`. Couvre **automatiquement** les 15 clés IFFD mesurées (§1) et toute clé future, aligné sur `fieldRename: snake` du generator (AD-3). Idempotent sur les mots simples (`name→name`, `status→status`, `id→id`). Défensif : une clé non transformable est **passée telle quelle**, jamais perdue.
- **`valueMappers`** : mapping **valeur** par champ (le seul cas non générique). Pour `FolderDocument` : `{'status': mapDocumentStatus}`. Réutilisable pour d'autres enums legacy plus tard (paramétré, additif).
- **Préservation de la granularité perdue** (AD-4) : la valeur legacy exacte de `status` (`embedded`/`converted`…) est **conservée dans `extra`** avant remap (clé de survie), pour zéro perte de la granularité conversion/embedding app-spécifique.
- **DÉFENSIF (AD-10)** : `toCanonical`/`toLegacy` ne **throw jamais** ; une valeur inattendue (type inconnu, `null`) est **laissée intacte / repliée**, jamais propagée en exception.

### D2 — Le codec se BRANCHE EN AMONT du décodage, par COMPOSITION au call-site DI (aucune réécriture de `FirebaseZRepositoryImpl`)

Le codec normalise la map **avant** `fromMap`/`registry.decode` et **après** `toMap`/`encode` — au **point de câblage** (fabrique DI de l'app/intégration IFFD), **sans** modifier `FirebaseZRepositoryImpl` :

```
final codec = ZStudyLegacyCodec(valueMappers: {'status': ZStudyLegacyCodec.mapDocumentStatus});
final repo = FirebaseZRepositoryImpl<ZStudyDocument>(
  firestore: firestore, collectionPath: path, kind: 'study_document',
  fromMap: (raw) => canonicalFromMap(codec.toCanonical(raw)),   // ← codec EN AMONT
  toMap:   (v)   => codec.toLegacy(canonicalToMap(v)),          // ← bidirectionnel (interop legacy)
  fromMapSafe: (raw) => canonicalFromMapSafe(codec.toCanonical(raw)),
);
```

- **Composition avec `_inject`** : `_inject` (Timestamp→ISO + injection `id`) reste **inchangé** et s'applique côté adaptateur ; le codec traite la casse + les statuts + `int` millis + `ZSyncMeta` additif. Ordre : `_inject` (adaptateur) puis `fromMap`=`toCanonical`+décode (les deux sont commutatifs sur des clés disjointes ; le codec ne touche pas les clés `ZSyncMeta` déjà normalisées par `_inject`).
- **Voie registre** : identique via `fromRegistry` en enveloppant `registry.decode`/`encode` d'un `toCanonical`/`toLegacy` au call-site (la signature gelée `decode(kind, map)` reste **INCHANGÉE**, AD-10 additif).
- **Rejeté — injecter le codec DANS `FirebaseZRepositoryImpl`** (nouveau paramètre) : casserait la frontière « adaptateur backend-neutre » (le codec est IFFD-legacy-spécifique) et alourdirait une signature gelée. La composition au call-site est **strictement additive** et garde l'adaptateur agnostique.

### D3 — Ajout `ZSyncMeta` ADDITIF rétro-compatible (AD-27/AD-9/AD-10)

`toCanonical` **ajoute** `is_deleted: false` si absent (**condition de visibilité** de l'adaptateur — sans quoi le doc legacy est exclu de toute lecture) et **laisse** `updated_at` absent → `ZSyncMeta.fromJson` retombe sur `updatedAt: null` (défaut sûr, LWW « jamais synchronisé »). **Additif** : un doc qui porte déjà `is_deleted`/`updated_at` n'est PAS écrasé. **Asymétrie d'horloge** (soft-delete local `DateTime.now()` vs `serverTimestamp()` distant) : normalisée dans l'adaptateur (`_normalizeIsoInPlace` inconditionnel sur `ZSyncMeta.reservedKeys`, déjà en place) — le codec **n'y touche pas** (les clés réservées ne passent pas par `valueMappers`).

### D4 — DW-ES21-1 SOLDÉE : mapping 6→4 déterministe, documenté, testé EXHAUSTIVEMENT

`mapDocumentStatus` implémente la table §2. Test exhaustif : **les 6** valeurs legacy → la sortie attendue (assertions individuelles), **+** `null`/inconnu/non-`String` → `uploading` (défaut). La granularité (`embedded`→`readyForChat`) est préservée dans `extra`. Le mapping est asserté contre les **noms d'enum canoniques** (String `'uploading'`/`'validating'`/`'ready'`) — pas besoin d'importer `ZDocumentStatus` dans `zcrud_firestore` (évite une arête ; § D8).

### D5 — Corpus test dans DEUX packages tag-declarers (le gate est repo-wide)

Le gate itère tous les packages `test/` mais le **micro-ajustement D7** restreint la population « redevable » aux **tag-declarers** (`dart_test.yaml` déclarant `serialization-compat`). Population après ES-3.5 : `zcrud_generator` (déjà vert), `zcrud_study_kernel` (**hook déjà déclaré** — « ES-3.5 sèmera le corpus »), `zcrud_firestore` (**nouveau** — cette story déclare le tag + sème le corpus). Pour rendre l'interrupteur VERT, ES-3.5 sème donc les corpus de **firestore** ET **kernel** :

- **`packages/zcrud_firestore/test/z_study_legacy_codec_test.dart`** (`@Tags(['serialization-compat'])`) — le corpus IFFD legacy (la substance) : fixtures `test/fixtures/iffd_legacy/*.json` = documents **camelCase réels** (forme `FolderDocument.toMap` mesurée) → `codec.toCanonical` → décodage canonique **sans perte ni throw**. Couvre AC1-AC7. **`zcrud_firestore` = Flutter ⇒ runner `flutter test`** ; **HORS `gate:web-determinism`** (Flutter, cf. ES-3.2 D9) ; pas de `@TestOn('vm')`.
- **`packages/zcrud_study_kernel/test/serialization_corpus_test.dart`** (`@Tags(['serialization-compat'])`) — **test-only, additif, ZÉRO changement de lib kernel** : corpus DOMAINE de documents historiques **snake_case** (kernel ne connaît PAS la casse legacy — AD-27) : `ZSyncMeta` absent, enum inconnu (`ZPodcastStatus`→`ready` défaut), champs manquants → décodage défensif survit (`returnsNormally`), jamais throw. Satisfait le hook déclaré du kernel. (`zcrud_study_kernel` = pur-Dart ⇒ runner `dart test`.)

`dart_test.yaml` **NOUVEAU** dans `zcrud_firestore` déclarant le tag (évite l'avertissement « tag non déclaré » ; opt-in de la population D7).

### D6 — Interop dates IFFD (`int` millis) — DW-ES32-1 adressée dans le codec (additif)

Le codec `toCanonical` normalise **`createdAt` en `int` millis** (cas IFFD `fromMap` l.143) → String ISO-8601, en **complément** de `_normalizeIsoInPlace` (qui gère Timestamp/DateTime/`{_seconds}` mais **pas** `int`). Défensif : un `int` hors bornes ou non-date reconnaissable → laissé intact (jamais throw). Ceci **solde partiellement DW-ES32-1** pour la voie legacy IFFD (un writer legacy `Timestamp` **ET** `int` entrent tous deux dans le corpus). L'interop `Timestamp` pur reste couverte par l'adaptateur existant.

### D7 — Micro-ajustement SIGNALÉ de `verify_serialization.dart` : population redevable = tag-declarers (opt-in) — justifié par R12

**Édit micro, unique, signalé** : filtrer `withTests` aux packages dont le `dart_test.yaml` **déclare** le tag `serialization-compat` (helper additif `_declaresCompatTag(Directory)` : parse textuel d'un bloc `tags:` contenant `serialization-compat:`). Un package avec `test/` mais **sans** cette déclaration n'est **plus** compté `skipped` (il n'est pas « redevable » d'un corpus).

**Pourquoi c'est NÉCESSAIRE et pas cosmétique** : sans lui, l'interrupteur imposerait un test taggé dans 9 packages **sans entité persistée** ⇒ **corpus POWERLESS interdit R12**. Le `dart_test.yaml` **EST déjà** le marqueur d'opt-in de la convention (le kernel l'a posé « prêt pour ES-3.5 »). L'ajustement rend « redevable » ≡ « a déclaré le tag », alignant le gate sur sa propre convention. Population résultante = {generator, kernel, firestore}, **tous verts** après cette story.

- **Alternative documentée (repli)** : allowlist explicite `const _requiredPackages = {'zcrud_firestore','zcrud_generator','zcrud_study_kernel'}`. Rejetée par défaut (moins évolutive : chaque futur package persistant devrait éditer le script ; l'opt-in par `dart_test.yaml` est déclaratif et local au package).
- **Non négociable** : le script n'est **pas réécrit** — un helper + un filtre. Le squelette (itération, runner, exit 79→skip, bannière, interrupteur) est **préservé**.

### D8 — Confinement du graphe (AD-1) : PAS de nouvelle arête runtime ; `.g.dart` intouchés ; `reserved-keys` VERT sans édition

- `zcrud_firestore` dépend en **runtime** de `zcrud_core` + `zcrud_study_kernel` **uniquement** (out-degree du cœur inchangé = 0). Le codec + le corpus **n'ajoutent AUCUNE arête runtime**. Le corpus asserte les statuts par **noms d'enum String** (pas d'import `ZDocumentStatus`) et décode end-to-end dans une entité **kernel** (déjà dispo) — **aucune arête neuve**.
- **Si** le dev veut prouver le décodage 6→4 jusqu'à `ZDocumentStatus` réel : un **`dev_dependency` test-only** `zcrud_document` sur `zcrud_firestore` est **acyclique-safe** (firestore→document, aucune arête retour). ⚠️ `graph_proof.py` scanne AUSSI `dev_dependencies` (l.24) ⇒ **rejouer `melos run graph_proof` VERT** obligatoire. **Préférer l'option sans arête** (assertions par nom String) sauf preuve end-to-end jugée nécessaire.
- **Aucun `@ZcrudModel` neuf** ⇒ **aucun `.g.dart` régénéré**, aucun `registerZ…` ⇒ `gate:reserved-keys` **VERT sans toucher** `tool/reserved_keys_gate/**`. `gate:codegen-distribution` intouché.

### D9 — Wiring CI ENFORCED : `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` dans l'agrégat `verify` (miroir melos.yaml ↔ pubspec.yaml)

Poser l'interrupteur en préfixant la **dernière** commande de l'agrégat `verify` — dans **`melos.yaml` (l.101)** ET **`pubspec.yaml` (miroir)** (le `gate:melos-divergence` **exige** le miroir exact) :
`ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart`.
Ainsi `melos run verify` **enforced en local ET en CI** (parité ; la CI appelle `melos run verify`, `.github/workflows/ci.yml:87`). Le script standalone `verify:serialization` (l.87) reste **non préfixé** (vue warning togglable pour le dev). Le workflow CI n'est **pas** édité (l'env vit dans le script agrégé).

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (R12) : le test associé **ROUGIT par le retrait/l'inversion de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli (aucun test POWERLESS). Chaque **injection R3** est rejouée réellement (garde retirée/inversée → ROUGE **par cette garde**) puis **restaurée par édition ciblée** (`git diff` vide — R13, **JAMAIS `git checkout`**). Fixtures = **documents historiques camelCase RÉELS** (forme `FolderDocument.toMap` mesurée), jamais des maps synthétiques triviales.

**AC1 — camelCase legacy → snake_case canonique, SANS PERTE (bidirectionnel).** _(mapping de casse)_
`codec.toCanonical(legacy)` renomme **chaque** clé camelCase mesurée vers sa snake_case (`subjectId→subject_id`, `createdAt→created_at`, `contentLength→content_length`, `subFolderId→sub_folder_id`, `assistantFileId→assistant_file_id`, …) ; une clé déjà snake/mot simple est inchangée ; une clé inconnue est **transformée + conservée** (jamais perdue). `codec.toLegacy(codec.toCanonical(legacy))` **restitue** la forme camelCase (round-trip, modulo l'ajout additif `ZSyncMeta`). Un document legacy décodé end-to-end restitue les **vraies valeurs** des champs renommés (pas `null`/défaut).
- **R3-1** : neutraliser `camelToSnake` (retour identité) ⇒ le champ `created_at`/`subject_id` revient `null`/défaut au décode ⇒ **ROUGE** (assertion de valeur réelle). Restaurer par édition ciblée.

**AC2 — Mapping legacy IFFD 6 statuts → 4 canoniques, DÉTERMINISTE et EXHAUSTIF (DW-ES21-1 soldée).** _(mapping valeur)_
`mapDocumentStatus` mappe **exactement** (test des 6, assertions individuelles) : `uploading→uploading`, `converting→validating`, `embedding→validating`, `uploaded→ready`, `converted→ready`, `embedded→ready` ; `null`/inconnu/non-`String` → `uploading` (défaut sûr = 1ʳᵉ constante). La granularité legacy exacte est **préservée dans `extra`** (zéro perte). Sortie = **nom d'enum canonique** valide.
- **R3-2** : casser **une** ligne (`converted→uploading`, faux) ⇒ le cas `converted` **ROUGE** ; puis inverser le défaut (`inconnu→ready`) ⇒ le cas inconnu **ROUGE**. Restaurer.

**AC3 — Décodage DÉFENSIF : un document corrompu DÉGRADE, ne throw JAMAIS (AD-10).** _(garde défensive)_
Un doc legacy à champ corrompu/tronqué/type inattendu (`status: 42`, `createdAt: "pas-une-date"`, sous-objet manquant, enum hors domaine) passe par `toCanonical` + décodage et **survit** (`returnsNormally` ; parent non `null` ; champs repliés sur défauts sûrs). `toCanonical`/`toLegacy` ne lèvent **jamais**.
- **R3-3** : introduire un `throw` sur clé/valeur inattendue dans `toCanonical` ⇒ le cas corrompu **ROUGE** (attend `returnsNormally`). Restaurer.

**AC4 — Ajout `ZSyncMeta` ADDITIF rétro-compatible → document legacy VISIBLE (AD-27/AD-9).** _(garde additive)_
Un doc legacy **sans** `is_deleted`/`updated_at` : `toCanonical` **ajoute** `is_deleted:false` (⇒ visible : `_isVisible`/filtre serveur satisfaits) et **laisse** `updated_at` absent ⇒ `ZSyncMeta.fromJson` → `updatedAt:null`, `isDeleted:false`. Un doc portant DÉJÀ ces clés n'est **pas** écrasé (additif). L'asymétrie d'horloge reste normalisée par l'adaptateur (clés réservées non touchées par le codec).
- **R3-4** : retirer l'ajout `is_deleted:false` ⇒ le doc legacy devient **non visible** / `ZSyncMeta` incohérent ⇒ le test de visibilité/round-trip **ROUGE**. Restaurer.

**AC5 — `FlashcardSource` inconnu → variant « custom »/défaut, JAMAIS `FormatException` (AD-10, divergence lex épinglée).** _(garde de divergence, test-only)_
Corpus : un doc flashcard legacy à `source.kind` **inconnu** → `ZFlashcardSource.fromJson` rend `ZCustomSource` conservant le payload (jamais throw) ; `kind` absent → `null`. **Aucune** modification du lib `zcrud_flashcard` (comportement déjà livré ; ES-3.5 l'épingle).
- **R3-5** : dans le test, un `expect(returnsNormally)` sur la voie inconnue ; injection = simuler une source qui lèverait (ex. monkey-patch d'un mapper de test qui throw) ⇒ le test **ROUGE**. (Le lib restant intact, l'injection porte sur un double de test prouvant la garde.)

**AC6 — Interop dates bi-format IFFD (`Timestamp` natif ET `int` millis) → même ISO-8601 canonique (DW-ES32-1 partielle).** _(garde d'interop)_
Deux docs legacy identiques sauf `createdAt` (`Timestamp` vs `int` millis) décodent vers la **même** `DateTime`/ISO. Le codec comble `int` millis (non géré par `_normalizeIsoInPlace`) ; le `Timestamp` reste normalisé par l'adaptateur. Défensif : `int` non-date-plausible → laissé intact, jamais throw.
- **R3-6** : neutraliser la branche `int` millis du codec ⇒ le doc `createdAt:int` revient `null`/défaut ⇒ **ROUGE** (assertion d'égalité des deux formes). Restaurer.

**AC7 — Le corpus ARME réellement le gate : `verify:serialization` passe de WARNING à VERT sous `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` (pouvoir discriminant PROUVÉ).** _(garde d'enforcement)_
Avec le micro-ajustement D7 + les corpus firestore/kernel + le wiring D9 : `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart` **RC=0** (« corpus vert sur tous les packages » sur la population redevable {generator, kernel, firestore}) ; `melos run verify` **RC=0**. Le corpus firestore n'est **pas** POWERLESS.
- **R3-7 (PREUVE D'ENFORCEMENT — obligatoire)** : (a) poser l'env var → gate **VERT** ; (b) **vider** le corpus firestore (ou retirer son tag) → sous l'env var, `zcrud_firestore` redevient `skipped` → gate **RC=1 (ROUGE)** ; (c) restaurer par édition ciblée → **VERT**. Prouve que le corpus discrimine et que l'interrupteur mord. Rejouer aussi **sans** l'env var → **RC=0 + bannière** (warning préservé).

**AC8 — Micro-ajustement SIGNALÉ du gate : population redevable = tag-declarers ; squelette préservé.** _(garde de scoping)_
`verify_serialization.dart` restreint `withTests` aux packages déclarant `serialization-compat` dans `dart_test.yaml` (helper `_declaresCompatTag`). Un package `test/`-only **sans** déclaration (`zcrud_geo`, `zcrud_list`, …) n'est **plus** `skipped`/redevable. Itération, runner (`flutter`/`dart`), `exit 79→skip`, bannière et interrupteur sont **inchangés**.
- **R3-8** : ajouter temporairement une déclaration `serialization-compat` dans le `dart_test.yaml` d'un package **sans** corpus (ex. `zcrud_geo`) → sous l'env var, gate **ROUGE** (geo redevable sans corpus) ⇒ prouve que le filtre est piloté par la déclaration. Retirer par édition ciblée → **VERT**.

**AC9 — Confinement architectural : AD-27 (casse jamais dans le domaine), AD-5 (zéro type backend en signature), AD-1 (graphe), gates verts.** _(garde d'invariants)_
Le mapping de casse/statut **n'existe QUE** dans `zcrud_firestore` (aucun `@JsonKey` camelCase ni renommage dans core/kernel/entités). Signature publique du codec = `Map<String,dynamic>` (aucun `Timestamp`/`Query`/`FirebaseException`). Aucune arête runtime neuve ; aucun `.g.dart` régénéré. `melos run analyze` RC=0 · `graph_proof` VERT · `gate:reserved-keys` VERT (sans édition de `tool/reserved_keys_gate/**`) · `gate:codegen-distribution` VERT.
- **R3-9** : `grep -rn` prouvant qu'aucune clé camelCase legacy n'apparaît dans un `toMap`/`@JsonKey` de `zcrud_core`/kernel/entités (le mapping reste confiné). (Garde d'inspection, pas un test rouge.)

---

## Tasks / Subtasks

- **T1 — Codec (D1/D3/D6)** : créer `packages/zcrud_firestore/lib/src/data/z_study_codec.dart` — `ZStudyLegacyCodec` (`toCanonical`/`toLegacy`, `camelToSnake`/`snakeToCamel` génériques, `valueMappers`, `mapDocumentStatus` 6→4, préservation `extra`, ajout additif `is_deleted:false`, normalisation `int` millis). DÉFENSIF partout (jamais throw). Exporter via le barrel `lib/zcrud_firestore.dart`. (AC1, AC2, AC3, AC4, AC6)
- **T2 — Fixtures corpus IFFD legacy** : `packages/zcrud_firestore/test/fixtures/iffd_legacy/*.json` — documents camelCase RÉELS (forme `FolderDocument.toMap` mesurée) : cas nominal, sans `ZSyncMeta`, statut par les 6 valeurs, statut inconnu, `createdAt` `Timestamp`/`int`, doc corrompu/tronqué, source flashcard inconnue. (AC1-AC6)
- **T3 — Corpus firestore taggé** : `packages/zcrud_firestore/test/z_study_legacy_codec_test.dart` (`@Tags(['serialization-compat'])`) + `packages/zcrud_firestore/dart_test.yaml` (déclaration du tag). Backend décode dans une entité kernel (option sans arête) ; assertions statut par noms String. Chaque AC1-AC6 + ses injections R3. (AC1-AC6, AC7)
- **T4 — Corpus kernel taggé (test-only, additif)** : `packages/zcrud_study_kernel/test/serialization_corpus_test.dart` (`@Tags(['serialization-compat'])`) — décodage défensif DOMAINE (snake_case historique, `ZSyncMeta` absent, enum inconnu → défaut, champs manquants) ; **zéro** changement de lib kernel. (AC7)
- **T5 — Micro-ajustement gate (D7)** : `scripts/ci/verify_serialization.dart` — helper `_declaresCompatTag(Directory)` + filtre de `withTests` sur les tag-declarers. Squelette préservé. Bloc de commentaire SIGNALANT le micro-ajustement (rationale R12 + solde ES-3.5). (AC8)
- **T6 — Wiring CI ENFORCED (D9)** : préfixer `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` sur la dernière commande de l'agrégat `verify` dans `melos.yaml` **et** `pubspec.yaml` (miroir exact — `gate:melos-divergence`). (AC7)
- **T7 — Injections R3 rejouées** : exécuter R3-1..R3-9 réellement (dont R3-7 preuve d'enforcement sous l'env var), restaurer chaque garde par **édition ciblée** (`git diff` vide). Consigner dans les dev notes.
- **T8 — Vérif verte finale** : voir la section dédiée (commandes exactes, avec et sans l'env var).

---

## Injections R3 prévues (récapitulatif — pouvoir discriminant)

| # | Garde | Injection | ROUGE attendu | Restauration |
|---|---|---|---|---|
| R3-1 | camelCase→snake | `camelToSnake` = identité | champ renommé → `null`/défaut (AC1) | édition ciblée |
| R3-2 | mapping 6→4 | `converted→uploading` (faux) ; puis `inconnu→ready` | cas `converted` puis cas inconnu (AC2) | édition ciblée |
| R3-3 | défensif | `throw` sur valeur inattendue dans `toCanonical` | cas corrompu (attend `returnsNormally`, AC3) | édition ciblée |
| R3-4 | `ZSyncMeta` additif | retirer l'ajout `is_deleted:false` | doc legacy non visible (AC4) | édition ciblée |
| R3-5 | divergence FlashcardSource | double de test qui throw sur `kind` inconnu | voie inconnue (AC5) | édition ciblée |
| R3-6 | interop `int` millis | neutraliser la branche `int` du codec | `createdAt:int` → défaut (AC6) | édition ciblée |
| **R3-7** | **enforcement gate** | **vider le corpus firestore sous l'env var** | **gate RC=1** (firestore skipped) — **PREUVE que le corpus arme le gate** (AC7) | **édition ciblée** |
| R3-8 | scoping tag-declarers | déclarer le tag dans `zcrud_geo` (sans corpus) | gate RC=1 (geo redevable) (AC8) | édition ciblée |
| R3-9 | confinement AD-27 | `grep` — aucune clé camelCase dans core/kernel/entités | (inspection, pas un test) (AC9) | — |

**Preuve d'ENFORCEMENT (R3-7) — protocole exact** :
```
# 1. VERT sous l'interrupteur (corpus en place)
ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart ; echo "RC=$?"   # attendu RC=0
# 2. Vider le corpus firestore (ou retirer @Tags) → ROUGE sous l'interrupteur
ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart ; echo "RC=$?"   # attendu RC=1 (firestore skipped)
# 3. Restaurer par ÉDITION CIBLÉE → VERT ; git diff vide
# 4. Sans l'interrupteur → warning préservé (RC=0 + bannière si applicable)
dart run scripts/ci/verify_serialization.dart ; echo "RC=$?"                                        # attendu RC=0
```

---

## Vérif verte à rejouer (réellement, sur disque, avant `review` puis `done`)

```bash
cd /home/zakarius/DEV/zcrud

# 0. (aucun @ZcrudModel neuf ⇒ pas de generate requis ; le rejouer ne DOIT rien changer)
dart run melos run generate                         # RC=0, aucun .g.dart modifié (git status propre)

# 1. Analyse repo-wide (une régression cross-package n'est vue QUE repo-wide)
dart run melos run analyze                          # RC=0

# 2. Tests ciblés des packages touchés
cd packages/zcrud_firestore && flutter test ; echo "RC=$?" ; cd ../..     # RC=0 (dont corpus taggé)
cd packages/zcrud_study_kernel && dart test ; echo "RC=$?" ; cd ../..     # RC=0 (dont corpus taggé)

# 3. Corpus de rétro-compat — vue WARNING (sans l'interrupteur)
dart run scripts/ci/verify_serialization.dart ; echo "RC=$?"              # RC=0 (bannière éventuelle)

# 4. Corpus de rétro-compat — ENFORCED (avec l'interrupteur) — LE cœur d'ES-3.5
ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart ; echo "RC=$?"   # RC=0

# 5. Graphe (dev_dependencies inclus si option end-to-end retenue)
python3 scripts/dev/graph_proof.py ; echo "RC=$?"   # RC=0 (DAG, CORE OUT=0)

# 6. Gate agrégé REPO-WIDE (miroir CI ; inclut désormais l'interrupteur en D9)
dart run melos run verify                           # RC=0 (analyze + tous gates + verify:serialization ENFORCED)
```

**Ordre de gate d'epic (fin ES-3, NON-NÉGOCIABLE)** : `melos run analyze` **ET** `melos run verify` **REPO-WIDE** verts (une vérif par-package ne détecte pas une régression cross-package). `gate:reserved-keys` VERT **sans** édition de `tool/reserved_keys_gate/**`. `gate:codegen-distribution` VERT.

---

## Dépendances & dettes

- **Dépend de** : ES-3.0 (`ZDecodeContext`/voie registre — composé), ES-3.2 (`FirebaseZRepositoryImpl`/`ZOfflineFirstBoxRepository`/`_inject` — composés), ES-2.x (entités `@ZcrudModel` + `ZDocumentStatus`/`ZPodcastStatus` + `ZFlashcardSource`). **Bloque** : rien dans ES-3 (dernière story) ; **prépare** ES-11.2 (migration IFFD sur corpus réel, qui **réutilise** ce codec).
- **DW-ES21-1 (AD-27) — SOLDÉE par cette story** : mapping legacy IFFD 6 statuts → 4 canoniques, déterministe/documenté/testé exhaustivement (AC2, table §2). Épingle le test annoncé par `z_document_status.dart:10`.
- **DW-ES32-1 (LOW, Timestamp interop) — SOLDÉE PARTIELLEMENT** : le codec comble `int` millis (AC6/D6) ; l'interop `Timestamp` pur reste couverte par l'adaptateur (`_normalizeIsoInPlace`). Si un writer legacy `Timestamp` entre dans le corpus (fixture), l'interop complète IFFD est prouvée ici. Reliquat éventuel (autres writers tiers) reste noté.
- **DW-ES25-1 (PROTOTYPER R4 tôt / anti-POWERLESS)** : honoré — chaque AC porte une injection R3 discriminante ; R3-7 prouve l'enforcement réel du gate (pas un vert décoratif).
- **DW-ES33-1 / DW-E54-1** : **NON rouvertes** (hors périmètre additif d'ES-3.5) — rappelées pour mémoire.
- **Dette éventuelle CRÉÉE (à consigner si retenue)** : si l'option end-to-end (dev_dependency `zcrud_document`/`zcrud_flashcard` sur `zcrud_firestore`) est retenue, noter l'arête dev-only acyclique-safe + la re-preuve `graph_proof`. Par défaut, option **sans arête** (assertions par nom String) ⇒ aucune dette.

---

## Dev Notes

- **`FirebaseZRepositoryImpl` (UPDATE lu, NON modifié)** : `_inject`/`_normalizeIsoInPlace` (l.304-348) gèrent Timestamp/DateTime/`{_seconds}`→ISO pour `ZSyncMeta.reservedKeys` (inconditionnel) + `_timestampFields` ; `_isVisible` (l.411) exige `is_deleted==false` ; `fromRegistry` (l.181-200) et le décodage défensif `_decode` (l.382-402) restent le socle. Le codec se compose **au call-site** (D2), pas dans cette classe.
- **`ZSyncMeta` (lu, NON modifié)** : `fromJson` défensif + `reservedKeys` + `stripReserved` — le codec ne touche jamais `updated_at`/`is_deleted` via `valueMappers` (elles restent gérées par l'adaptateur ; le codec ne fait qu'AJOUTER `is_deleted:false` si absent, D3).
- **`ZDocumentStatus` (lu)** : `uploading` = 1ʳᵉ constante = défaut défensif (D5 du dartdoc) ⇒ le mapping inconnu→`uploading` est aligné sur le repli du generator.
- **`ZFlashcardSource.fromJson` (lu, NON modifié)** : divergence lex déjà livrée (unknown→`ZCustomSource`, jamais throw) ; ES-3.5 l'épingle par corpus (AC5), aucun changement lib.
- **Gate `verify_serialization.dart` (lu intégralement)** : exit 79→skip PROUVÉ empiriquement sur `zcrud_document` ; interrupteur `l.150-155`. Micro-ajustement = helper `_declaresCompatTag` + filtre (D7), squelette préservé.
- **Runners** : `zcrud_firestore` = Flutter → `flutter test` ; `zcrud_study_kernel` = pur-Dart → `dart test` ; le gate choisit `runner` par détection `flutter:` (l.36-51). `zcrud_firestore` HORS `gate:web-determinism` (Flutter).
- **R13** : restaurer toute injection R3 par **édition ciblée** (jamais `git checkout` — masquerait un drift). `git diff` vide après restauration.

---

## Questions / clarifications (pour l'orchestrateur — non bloquantes)

1. **Option end-to-end vs sans-arête** (D8) : le dev privilégie l'option **sans nouvelle arête** (assertions statut par noms String + décode dans une entité kernel). Confirmer si une preuve de décodage jusqu'à `ZDocumentStatus` réel (dev_dependency `zcrud_document` acyclique-safe, `graph_proof` re-prouvé) est exigée — sinon rester sans arête.
2. **Micro-ajustement gate** (D7) : opt-in par `dart_test.yaml` (retenu) vs allowlist explicite. L'opt-in est plus évolutif et aligné sur le hook kernel existant ; confirmer.

---

## Dev Agent Record

### Tasks / Subtasks — état

- [x] **T1 — Codec** `ZStudyLegacyCodec` (`toCanonical`/`toLegacy`, `camelToSnake`/`snakeToCamel` génériques, `valueMappers`, `mapDocumentStatus` 6→4, préservation `_legacy_status` dans `extra`, ajout additif `is_deleted:false`, normalisation `int` millis `_at`→ISO). DÉFENSIF (jamais throw). Exporté au barrel. (AC1-AC4, AC6)
- [x] **T2 — Fixtures** IFFD legacy camelCase réelles (6 fichiers : embedded/converting/created_at_iso/unknown_status/corrupt/with_sync_meta).
- [x] **T3 — Corpus firestore taggé** `z_study_legacy_codec_test.dart` + `dart_test.yaml` (déclare le tag). 31 tests, AC1-AC6 + injections R3-1..R3-6.
- [x] **T4 — Corpus kernel taggé** `serialization_corpus_test.dart` (test-only, JS-safe, ZÉRO changement lib). 8 tests (ZStudyFolder défensif + ZPodcastStatus inconnu→ready).
- [x] **T5 — Micro-ajustement gate** `verify_serialization.dart` : helper `_declaresCompatTag` + filtre `withTests` sur tag-declarers ; squelette préservé ; bloc SIGNALÉ (rationale R12).
- [x] **T6 — Wiring CI ENFORCED** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` sur la dernière commande de `verify` (miroir melos.yaml ↔ pubspec.yaml).
- [x] **T7 — Injections R3** rejouées réellement (R3-1..R3-9), restaurées par édition ciblée.
- [x] **T8 — Vérif verte finale** rejouée sur disque (table ci-dessous).

### File List

**NEW**
- `packages/zcrud_firestore/lib/src/data/z_study_codec.dart` (codec)
- `packages/zcrud_firestore/dart_test.yaml` (déclaration du tag)
- `packages/zcrud_firestore/test/z_study_legacy_codec_test.dart` (corpus taggé, 31 tests)
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_embedded.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_converting.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_created_at_iso.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_unknown_status.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_corrupt.json`
- `packages/zcrud_firestore/test/fixtures/iffd_legacy/document_with_sync_meta.json`
- `packages/zcrud_study_kernel/test/serialization_corpus_test.dart` (corpus taggé, 8 tests, test-only)

**UPDATE (tracked)**
- `packages/zcrud_firestore/lib/zcrud_firestore.dart` (export codec)
- `scripts/ci/verify_serialization.dart` (micro-ajustement SIGNALÉ D7)
- `melos.yaml` (wiring D9)
- `pubspec.yaml` (wiring D9, miroir)

**INTOUCHÉS** : lib de `zcrud_core`/kernel/entités (aucun `.g.dart` régénéré), `tool/reserved_keys_gate/**`, sprint-status.

### Completion Notes

- **Décodage cible sans arête** (D8, Q1) : option **sans nouvelle arête** retenue — décodage end-to-end dans un double de test `_LegacyDoc extends ZEntity` (interne au test) ; statuts assertés par **noms d'enum String** (aucun import `ZDocumentStatus`). `graph_proof` reste ACYCLIQUE + CORE OUT=0. AUCUN `dev_dependency` ajouté.
- **Micro-ajustement gate** (D7, Q2) : opt-in par `dart_test.yaml` retenu. Population redevable = {`zcrud_generator`, `zcrud_study_kernel`, `zcrud_firestore`}, toutes vertes.
- **AC5** épinglée par **réplication de contrat** (double `_decodeSourceLikeFlashcard`) : `zcrud_firestore` n'a AUCUNE arête vers `zcrud_flashcard` (AD-1) ; le lib flashcard reste INCHANGÉ. R3-5 prouve la garde (guard retiré → throw remonte).
- **DW-ES21-1 SOLDÉE** : `mapDocumentStatus` 6→4 déterministe, 6 entrées + inconnu/null/non-String testés, granularité préservée dans `_legacy_status`.
- **DW-ES32-1 partielle** : codec comble `int` millis (`_at`→ISO) ; `Timestamp` natif reste normalisé par l'adaptateur (`timestampFields` hinte la clé legacy `createdAt`, `_inject` s'exécute AVANT le codec).

### Vérif verte (rejouée réellement sur disque)

| # | Vérif | RC |
|---|-------|----|
| 0 | `melos run generate` (aucun `.g.dart` neuf) | 0 |
| 1 | `dart analyze` firestore + kernel + script | 0 |
| 2 | firestore `flutter test` corpus taggé (31) | 0 |
| 2b| firestore `flutter test` FULL (173) | 0 |
| 3 | kernel `dart test` corpus taggé (8) | 0 |
| 3b| kernel `dart test` FULL (302) | 0 |
| 4 | `verify_serialization` SANS env var (warning) | 0 |
| 5 | **`verify_serialization` AVEC `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`** (WARNING DISPARU → « corpus vert sur tous les packages ») | **0** |
| 6 | `melos run analyze` repo-wide | 0 |
| 7 | `graph_proof.py` (ACYCLIQUE + CORE OUT=0) | 0 |
| 8 | `gate_reserved_keys.dart` (sans édition tool/) | 0 |
| 9 | `prove_gates.dart` (41 OK, 0 FAIL) | 0 |
| 10| `melos run verify` (agrégat, incl. interrupteur D9 + gate:melos-divergence) | 0 |

### Injections R3 — messages ROUGE EXACTS (pouvoir discriminant, restaurés par édition ciblée)

| # | Injection | Message ROUGE EXACT | RC / restauration |
|---|-----------|---------------------|-------------------|
| **R3-7** | corpus firestore vidé (détaggé) + env var | Bannière `❌ ÉCHEC — CORPUS DE RÉTRO-COMPAT MANQUANT` / `Packages SANS test taggé : packages/zcrud_firestore` | **RC=1** (enforced) ; RC=0 sans env var (warning préservé) → restauré RC=0 |
| R3-8 | tag déclaré dans `zcrud_geo` (sans corpus) + env var | Bannière `❌ ÉCHEC` / `packages/zcrud_geo` | RC=1 → fichier supprimé → RC=0 |
| R3-1 | `camelToSnake` = identité | `Expected: 'subj_math_101'  Actual: <null>` | RED → restauré |
| R3-2a | défaut mapping inversé (inconnu→ready) | `Expected: 'uploading'  Actual: 'ready'` | RED → restauré |
| R3-2b | `converted` retiré du groupe ready | `Expected: 'ready'  Actual: 'uploading'` | RED → restauré |
| R3-3 | `throw StateError` dans `toCanonical` | `Expected: return normally  Which: threw StateError:<Bad state: ★ R3-3 INJECTION>` | RED → restauré |
| R3-4 | ajout additif `is_deleted:false` retiré | map: `Expected: <false>  Actual: <null>` + e2e getAll `Expected: length 1  Actual: []` | RED → restauré |
| R3-5 | guard retiré (double source) | `Expected: return normally  Which: threw FormatException:<app codec boom>` | RED → restauré |
| R3-6 | branche `int` millis neutralisée | `Expected: <Instance of 'String'>  Actual: <1710498600000>` + e2e `Expected: not null  Actual: <null>` | RED → restauré |
| R3-9 | confinement AD-27 (inspection) | `grep` : AUCUNE clé camelCase legacy dans core/kernel/entités ; `camelToSnake`/`mapDocumentStatus`/`ZStudyLegacyCodec` UNIQUEMENT dans `zcrud_firestore` | n/a (inspection) |

### Change Log

- ES-3.5 — Codec `ZStudyLegacyCodec` (camelCase↔snake, mapping 6→4 DW-ES21-1, `ZSyncMeta` additif, interop `int` millis DW-ES32-1) + corpus IFFD legacy taggé (firestore + kernel) + gate `verify:serialization` micro-ajusté (tag-declarers, D7) et ENFORCED (`ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`, D9). Status → review.
