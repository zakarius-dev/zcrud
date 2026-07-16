# Story ES-9.3 : Podcasts (seam de génération) — `ZPodcastGenerationPort`

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrateur**,
I want **un port neutre `ZPodcastGenerationPort` (`Future<ZResult<ZStudyPodcast>>`) et un value-object `ZPodcastGenerationRequest` immuable portant une source neutre + un `sourceHash` OPAQUE FOURNI**,
so that **je branche mon pipeline TTS/synthèse audio app-specific sans qu'il fuie dans le domaine (aucun SDK/endpoint/clé, aucun calcul de hash), le cache podcast restant *content-addressed* et invalidable par `sourceHash` via `ZStudyPodcast.buildId`/`isStale` (AD-12/AD-26/D4).**

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

Cette story est la **3ᵉ de la chaîne sérielle ES-9.1 → 9.2 → 9.3 → 9.4** qui écrivent TOUTES `zcrud_study` : **une seule en vol**, jamais en parallèle (epics § ES-9 ; sprint-status `es-9-3 [S][SÉQ — écrit zcrud_study, NON ∥ avec 9.1/9.4]`). ES-9.1 et ES-9.2 sont **done**. Aucune parallélisation avec ES-7.1/ES-8.1/ES-9.4 (mêmes fichiers `zcrud_study`).

**Périmètre validé sur disque (ne rien inventer) :**

- `zcrud_study/lib/src/domain/` **EXISTE DÉJÀ** (créé par ES-9.1) et contient les 4 fichiers de seams IA neutres (`z_flashcard_generation_port.dart`, `z_ai_explanation_port.dart`, `z_note_summary_port.dart`, `z_education_quota_info.dart`). ES-9.3 **ajoute UN fichier** dans ce dossier : `z_podcast_generation_port.dart` (+ son request VO). **AUCUN autre package touché.**
- **`ZStudyPodcast` EXISTE DÉJÀ** dans le **kernel** : `packages/zcrud_study_kernel/lib/src/domain/z_study_podcast.dart` (`@ZcrudModel(kind: 'study_podcast')`, `ZEntity` + `ZExtensible`). Il porte `{id?, sourceKind, sourceId, folderId, mode, sourceHash, resultRef, status, createdAt, extension, extra}`, un helper PUR `static ZStudyPodcast.buildId(sourceId, mode) => '${sourceId}_${mode.name}'`, et l'invalidation PURE `bool isStale(String currentSourceHash) => sourceHash != currentSourceHash`. → **NE PAS recréer un modèle de podcast.** ES-9.3 **RÉUTILISE** cette entité comme **type de retour** du port.
- Les enums `ZPodcastSourceKind {note, folder, document}`, `ZPodcastMode {simple, dialogue}`, `ZPodcastStatus {ready, pending, processing, failed, stale}` existent dans le kernel et sont **exportés** par son barrel (`zcrud_study_kernel.dart:82-95`, `z_study_podcast.dart` exporté `hide ZStudyPodcastZcrud`).
- 🔴 **`sourceHash` est OPAQUE, JAMAIS calculé dans le domaine (décision kernel D4, NFR-S10/SM-S7)** : `package:crypto`/SHA-256 est **INTERDIT** dans le kernel ET dans `zcrud_study`. Le hash du contenu source est un **seam de présentation/data** — c'est **précisément ce que livre ES-9.3** : le `sourceHash` transite par le request comme `String` **FOURNI par l'appelant** (calculé app-side / binding : SHA-256 côté lex, parité backend préservée sans que le domaine acquière crypto). Le domaine ne hashe **RIEN**.
- **La provenance par `ZSourceRegistry` d'ES-9.1 n'est PAS pertinente ici** : la nature de source d'un podcast est un **enum FERMÉ** du kernel (`ZPodcastSourceKind`), pas une provenance OUVERTE (contraste explicite avec la flashcard). ⇒ **aucun** `ZSourceRegistry`, **aucun** `switch`/`kind` codé en dur dans `zcrud_study` (le request porte l'enum kernel tel quel). Réutiliser un registre ici serait une sur-ingénierie non justifiée (AD-4 : registre **seulement** pour l'ouverture inter-package, absente ici).

**Arête de graphe (AD-1) — DELTA = 0 (aucune nouvelle arête) :** `zcrud_study → zcrud_study_kernel` est **déjà déclarée** (pubspec `zcrud_study` : « arête DÉCLARÉE d'emblée (AD-17) », et `zcrud_study` importe déjà le kernel dans `z_tag_chips.dart`/`z_exam_reminders.dart`). Consommer `ZStudyPodcast`/`ZPodcastSourceKind`/`ZPodcastMode` **ne crée aucune arête**. Compte `graph_proof` mesuré aujourd'hui : **44 arêtes / 20 nœuds** → **44 arêtes après (delta = 0)**. Le retour du port est `ZStudyPodcast` (kernel), **pas** `List<ZFlashcard>` : ES-9.3 ne touche PAS à l'arête `zcrud_flashcard`.

**Runner (R14) :** `zcrud_study` est un package **Flutter** (`sdk: flutter` en deps — pubspec vérifié). Le nouveau fichier domaine est pur-Dart, mais **les tests se lancent via `flutter test`** (jamais `dart test`). **R25** : aucune mutation du workspace (aucune dépendance ajoutée) ⇒ pas de fenêtre pub-get sensible.

**🔴 Leçon centrale héritée du code-review ES-9.1 (M-1) — À NE PAS RÉPÉTER :** le request VO d'ES-9.1 avait initialement un `extra` **sans** garde AD-19.1, masqué derrière un faux diagnostic ; puis le premier correctif orchestrateur était lui-même un « vœu » (aucun test ne l'exerçait). ES-9.3 livre la garde AD-19.1 **ET son verrou de test package-local DÈS LE DÉPART** — `reserved_keys_gate` **n'importe PAS `zcrud_study`**, donc SEUL un test package-local couvre ce DTO.

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** (R12) : ancré sur la **ligne de prod PROPRE à ES-9.3** (R20/R24), prouvé par une injection qui la neutralise (§ Injections R3). Une garde de filtrage/transformation asserte la **PRÉSERVATION EXACTE**, jamais la seule absence d'anomalie (R26). Toute garde load-bearing (extra AD-19.1, anti-secret, anti-crypto) est **VERROUILLÉE par un test qui rougit sous neutralisation** (M-1).

**AC1 — Port neutre `ZPodcastGenerationPort` (`Either<ZFailure,·>`, AD-5/AD-11/AD-26)**
**Given** une source à convertir en podcast
**When** on définit le port dans `zcrud_study/lib/src/domain/z_podcast_generation_port.dart`
**Then**
- `ZPodcastGenerationPort` expose `Future<ZResult<ZStudyPodcast>> generatePodcast(ZPodcastGenerationRequest request)` ;
- `ZResult<T>` = `Either<ZFailure,T>` (`zcrud_core`, `z_failure.dart:93`) ; retour **enveloppé** — **jamais** un `ZStudyPodcast` nu, **jamais** un `Stream` enveloppé (AD-5) ; `Left(ZFailure)` en cas d'échec (quota/réseau/TTS/parsing), `Right(ZStudyPodcast)` en succès ;
- `ZPodcastGenerationRequest` est un **value-object IMMUABLE** (`==`/`hashCode` par valeur — égalité **profonde** de `extra` via `zJsonEquals`/`zJsonHash`, champs `final`, pas de setter) ;
- le port est `abstract interface class` (AD-4 : `abstract interface`, **jamais `sealed`** — l'app *implements* librement son pipeline TTS, aucune impl de référence dans le package : le port n'a aucun comportement neutre à factoriser).
**Discriminant** — un test de surface (`ZPodcastGenerationPort` implémenté par un fake app-side) vérifie le **type de retour exact** (`ZResult<ZStudyPodcast>`, liaison de type STATIQUE ⇒ rougit à la COMPILATION si la signature devient `Future<ZStudyPodcast>` nue) et l'**égalité par valeur** du request ; injection R3-I1 (retour non enveloppé / request `==` par identité) ⇒ RC=1.

**AC2 — Zéro fuite transport / TTS / prompt / secret (AD-12, Key Don't « never de secret »)**
**Given** que le pipeline TTS / endpoints / prompts / streaming / clés / storage restent **côté app** (AD-26)
**When** on analyse le fichier domaine ES-9.3 + le pubspec de `zcrud_study`
**Then**
- **aucun** littéral d'endpoint/URL (`http(s)://`, `AIza…`, `sk-…`, `Bearer …`, PEM, token) dans `z_podcast_generation_port.dart` ;
- **aucune** dépendance IA/HTTP/TTS/audio/crypto concrète ajoutée au pubspec (`http`, `dio`, `just_audio`, `flutter_tts`, `googleapis`, `crypto`, SDK quelconque) — **aucune** arête ajoutée (delta graphe = 0, AC5) ;
- `dart run scripts/ci/gate_secret_scan.dart` (`gate:secrets`, AD-12) **vert** ; `dart run melos run verify` **vert** (`gate:secrets OK` + `gate:reserved-keys OK`).
**Discriminant** — un test de scan LOCAL au package énumère les `.dart` de `lib/src/domain/` et asserte l'**absence RÉELLE** de tout motif endpoint/clé/token (le test `z_ai_ports_no_secret_test.dart` d'ES-9.1 le fait déjà pour le dossier ⇒ le nouveau fichier est **couvert automatiquement**) ; injection R3-I2 (insérer `const _endpoint = 'https://tts.googleapis.com/v1/text:synthesize'`) ⇒ scan RC=1 **et** `gate:secrets` RC=1.

**AC3 — `extra` du request protégé AD-19.1 (accessor-sanitize, LOAD-BEARING M-1)**
**Given** un `ZPodcastGenerationRequest` porteur d'un `extra` LIBRE (paramètres app-specific neutres)
**When** on lit `request.extra`
**Then**
- le slot brut `_extra` est **privé, non filtré au constructeur `const`** (ES-9.1 : un paramètre nommé ne peut être privé) ; l'accesseur porte la garde : `Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys)` avec `_reservedKeys = <String>{...ZSyncMeta.reservedKeys}` (AD-19.1, **non négociable**) ;
- les clés de sync **réservées** (`updated_at`/`is_deleted`) injectées dans `extra` sont **ÉCARTÉES à la lecture** — jamais réémises — tandis que toute clé app-specific **légitime est PRÉSERVÉE à l'identique** (R26) ;
- `==`/`hashCode` consomment l'**accesseur** sanitisé (deux requests ne différant que par une clé réservée sont **égaux**).
**Discriminant LOAD-BEARING (M-1)** — un **verrou de test package-local** construit un request avec `extra = {updated_at, is_deleted, legit:42}` et asserte : `updated_at`/`is_deleted` **absents**, `legit` **préservé**, `extra.length == 1`. Injection R3-I3 (neutraliser l'accesseur : `get extra => _extra;`) ⇒ le verrou RC=1 (`updated_at` survit). Sans ce test, la garde serait un « vœu » (`reserved_keys_gate` n'importe PAS `zcrud_study`) — **c'est le défaut exact du code-review ES-9.1, à ne pas rejouer.**

**AC4 — Content-addressed : `sourceHash` OPAQUE, JAMAIS calculé dans le domaine (D4, AD-26/AD-12)**
**Given** une source dont l'empreinte est calculée **en amont** (app/binding : SHA-256 côté lex)
**When** on définit le request et le contrat du port
**Then**
- `ZPodcastGenerationRequest` porte `sourceHash` comme **`String` OPAQUE FOURNI** (défaut `''`) — le domaine ne le **calcule pas** : **aucun** `import 'package:crypto/...'`, **aucun** `sha256`/`Hmac`/`Digest`/`zFnv1a32` dans le fichier ES-9.3 (parité kernel D4 : le domaine ne hashe RIEN) ;
- le request porte la **source neutre content-addressable** : `sourceKind` (`ZPodcastSourceKind`, enum kernel FERMÉ), `sourceId` (`String` opaque), `folderId` (`String`), `mode` (`ZPodcastMode`), `content` (`String` source neutre), `languageTag` (`String?`), `sourceHash` (`String` opaque) — **aucun** prompt, **aucun** paramètre de transport ;
- le podcast **produit** par le port (`Right`) est un `ZStudyPodcast` dont l'identité *content-addressed* et l'invalidation reposent sur les helpers **kernel déjà testés** (`ZStudyPodcast.buildId(sourceId, mode)`, `isStale(currentHash)`) — le seam **transporte** `sourceHash`, il ne l'invente pas.
**Discriminant** — (a) un **scan anti-crypto** LOCAL au fichier asserte l'absence de `sha256`/`crypto`/`Digest`/`Hmac` : injection R3-I4 (ajouter `import 'package:crypto/crypto.dart';` + `sha256.convert(...)`) ⇒ RC=1 ; (b) un test de **composition** : un fake port qui estampille `request.sourceHash` dans `ZStudyPodcast.sourceHash` ⇒ le podcast produit est **`isStale('AUTRE_HASH') == true`** et **`isStale(request.sourceHash) == false`**, et `buildId(request.sourceId, request.mode)` compose l'id attendu `'${sourceId}_${mode.name}'` (l'AC prouve que le seam **fait circuler** l'empreinte opaque de bout en bout, pas que le domaine hashe). R20 assumé : `buildId`/`isStale` sont du code kernel **consommé** — l'assertion propre à ES-9.3 est la **circulation** du `sourceHash` fourni + l'**absence de crypto** dans le seam.

**AC5 — Graphe acyclique, ZÉRO arête ajoutée (AD-1/AD-17, CORE OUT=0)**
**Given** que `ZStudyPodcast`/`ZPodcastSourceKind`/`ZPodcastMode` viennent du kernel **déjà en dépendance** de `zcrud_study`
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 44`** (44 → 44, **delta = 0** — aucune nouvelle arête, `zcrud_study → zcrud_study_kernel` préexistante), 20 nœuds inchangés ; le pubspec de `zcrud_study` reste inchangé (aucune dépendance ajoutée). **Aucun** SDK IA/TTS/HTTP/crypto, **aucune** arête `zcrud_flashcard` supplémentaire (le retour est `ZStudyPodcast`, pas `ZFlashcard`).
**Discriminant** — un delta ≠ 0 (ex. `crypto`/`http`/`just_audio` ajouté par erreur) fait diverger le compte ⇒ échec (R3-I5) ; `graph_proof` refuse tout cycle.

## Tasks / Subtasks

- [x] **T1 — `ZPodcastGenerationRequest` (AC1, AC3, AC4)** — **NOUVEAU** dans `packages/zcrud_study/lib/src/domain/z_podcast_generation_port.dart`
  - [x] Value-object immuable `const ZPodcastGenerationRequest({required this.content, this.sourceKind = ZPodcastSourceKind.note, this.sourceId = '', this.folderId = '', this.mode = ZPodcastMode.simple, this.sourceHash = '', this.languageTag, Map<String,dynamic> extra = const {}}) : _extra = extra;` — champs `final`, **aucun** prompt/endpoint/clé.
  - [x] 🔴 **AD-19.1 (M-1) DÈS LE DÉPART** : slot privé `final Map<String,dynamic> _extra;` **lu nulle part ailleurs** ; accesseur `Map<String,dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);` ; `static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};`. Patron IDENTIQUE aux 3 requests ES-9.1 (`z_flashcard_generation_port.dart:57-67`).
  - [x] `==`/`hashCode` **par valeur** consommant l'**accesseur** `extra` (égalité profonde `zJsonEquals`/`zJsonHash`) sur TOUS les champs (`content`, `sourceKind`, `sourceId`, `folderId`, `mode`, `sourceHash`, `languageTag`, `extra`).
  - [x] Dartdoc : `sourceHash` **OPAQUE FOURNI** (jamais calculé ici, D4) ; `sourceKind` = enum kernel FERMÉ (pas de `ZSourceRegistry`, contraste ES-9.1) ; impl TTS/pipeline **côté app** (AD-26/AD-12).

- [x] **T2 — `ZPodcastGenerationPort` (AC1, AC4)** — même fichier
  - [x] `abstract interface class ZPodcastGenerationPort { Future<ZResult<ZStudyPodcast>> generatePodcast(ZPodcastGenerationRequest request); }` — **jamais `sealed`** (AD-4), aucune impl de référence.
  - [x] Dartdoc : `Left(ZFailure)` en échec, `Right(ZStudyPodcast)` en succès ; le contrat exige que l'impl estampille `request.sourceHash` dans `ZStudyPodcast.sourceHash` et matérialise l'id via `ZStudyPodcast.buildId(request.sourceId, request.mode)` (content-addressed, D4) ; le hashing du contenu reste **amont/app-side** (aucun `crypto` ici).
  - [x] `import 'package:zcrud_core/domain.dart';` (ZResult/ZFailure/zSanitizeExtra/ZSyncMeta/zJsonEquals/zJsonHash) + `import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyPodcast, ZPodcastSourceKind, ZPodcastMode;` (arête préexistante, AC5).

- [x] **T3 — Barrel (AC1)** — `packages/zcrud_study/lib/zcrud_study.dart`
  - [x] Exporter `src/domain/z_podcast_generation_port.dart`. **NE PAS** ré-exporter `ZStudyPodcast`/enums (le consommateur importe `package:zcrud_study_kernel/…`, cohérent avec ES-9.1 qui ne ré-exporte pas `ZFlashcard`).

- [x] **T4 — Pubspec INCHANGÉ (AC2, AC5)** — `packages/zcrud_study/pubspec.yaml`
  - [x] **NE RIEN ajouter** : `zcrud_study_kernel` est déjà présent (arête déclarée d'emblée). **AUCUN** `http`/`dio`/`crypto`/`flutter_tts`/`just_audio`/SDK IA. Vérifié `python3 scripts/dev/graph_proof.py` → **44 arêtes** (delta 0), ACYCLIQUE, CORE OUT=0.

- [x] **T5 — Tests `flutter test` (R14) — `packages/zcrud_study/test/`**
  - [x] `z_podcast_generation_port_test.dart` (**NOUVEAU**) :
    - **AC1 surface** : fake `ZPodcastGenerationPort` (l'app *implements*) retournant `Right<ZFailure, ZStudyPodcast>` puis `Left` ; asserte le **type de retour exact** `ZResult<ZStudyPodcast>` (`isA<Either<ZFailure, ZStudyPodcast>>()`) et `==`/`hashCode` **par valeur** du request (deux instances distinctes mais égales ; discrimine un champ qui change, `extra` profond inclus).
    - **AC4 content-addressed (composition)** : fake port estampillant `request.sourceHash` dans `ZStudyPodcast.sourceHash` ⇒ podcast produit `isStale('X') == true`, `isStale(request.sourceHash) == false`, `id`/`buildId(sourceId, mode)` == `'${sourceId}_${mode.name}'` (source `note`+`simple` ≠ `folder`+`dialogue` ⇒ ids distincts, pouvoir discriminant).
  - [x] `z_podcast_request_reserved_keys_test.dart` (**NOUVEAU — verrou M-1, LOAD-BEARING AD-19.1**) : construit `ZPodcastGenerationRequest(content:'c', extra:{updated_at, is_deleted, legit:42})` ⇒ asserte `updated_at`/`is_deleted` **écartés**, `legit` **préservé**, `extra.length == 1`, et deux requests ne différant que par une clé réservée **égaux** (== cohérent). **Rougit** si l'accesseur est neutralisé (R3-I3 prouvé RED au dev, RC=1).
  - [x] `z_podcast_no_crypto_test.dart` (**NOUVEAU — verrou anti-crypto AC4**) : scan LOCAL de `z_podcast_generation_port.dart` asserant l'**absence** de `import 'package:crypto`, `sha256`, `Digest`, `Hmac`, `zFnv1a32` (motifs LITTÉRAUX ; import resserré pour ne pas flaguer le contre-exemple dartdoc). Injection R3-I4 ⇒ RC=1 (prouvé).
  - [x] **AC2 anti-secret** : `z_ai_ports_no_secret_test.dart` (ES-9.1) scanne DÉJÀ tout `lib/src/domain/` ⇒ le nouveau fichier est couvert ; seuil relevé `>= 4` → `>= 5`. R3-I2 confirmé RED (test local + `gate:secrets` sur clé `AIza…`).
  - [x] Chaque test rougit sur son injection R3 dédiée (§ Injections R3) — **prouvé au dev** (RC=1 capturé), restauré vert.

- [x] **T6 — Vérif verte rejouée** (§ dédiée) + mise à jour File List / Dev Agent Record.

## Injections R3 prévues (mutation → AC rouge → restauration)

Chaque injection doit **RC=1** sur l'AC ciblé, puis restauration → vert (preuve du pouvoir discriminant, R3/R12).

- **R3-I1 (AC1)** — changer le retour du port en `ZStudyPodcast` nu (non `ZResult`) **ou** rendre `ZPodcastGenerationRequest.==` par identité ⇒ `z_podcast_generation_port_test.dart` RC=1.
- **R3-I2 (AC2 — anti-secret)** — insérer `const _endpoint = 'https://tts.googleapis.com/v1/text:synthesize'` (ou une clé) dans `z_podcast_generation_port.dart` ⇒ `z_ai_ports_no_secret_test.dart` RC=1 **et** `gate:secrets` RC=1.
- **R3-I3 (AC3 — AD-19.1, LOAD-BEARING M-1)** — neutraliser l'accesseur (`Map<String,dynamic> get extra => _extra;`) ⇒ `z_podcast_request_reserved_keys_test.dart` RC=1 (`updated_at` survit).
- **R3-I4 (AC4 — anti-crypto)** — ajouter `import 'package:crypto/crypto.dart';` + `sha256.convert(utf8.encode(content))` dans le fichier domaine ⇒ `z_podcast_no_crypto_test.dart` RC=1 (et pubspec devrait acquérir `crypto` ⇒ arête, AC5 RED).
- **R3-I5 (AC5 — graphe)** — ajouter une arête parasite (`crypto`/`http`/`just_audio`) au pubspec ⇒ `graph_proof` compte ≠ 44 / justification impossible.

## Dev Notes

- **RÉUTILISER, ne pas recréer (R21/SM-S4).** `ZStudyPodcast` + `buildId` + `isStale` + les 3 enums existent AU KERNEL (ES-2.8, done) et sont **déjà testés** (`z_study_podcast_test.dart`, `z_podcast_*_test.dart`). ES-9.3 ne crée **aucune** entité ni enum : elle définit **seulement** le port + son request VO, et **consomme** l'entité comme type de retour. Recréer un modèle de podcast serait un doublon inter-package interdit (AD-4/AD-17).
- **Ancrage R20/R24 (leçon L-1 du code-review ES-9.1).** La ligne PROPRE à ES-9.3 = la **surface du port** (type de retour exact), la **circulation du `sourceHash` opaque** de bout en bout, la **garde AD-19.1 de son request**, et l'**absence de crypto/secret** dans le seam. **NE PAS** re-tester en boîte noire `ZStudyPodcast.buildId`/`isStale`/`fromMap` (code kernel **déjà testé** — l'asserter serait POWERLESS sur ES-9.3, piège R20). Le test content-addressed d'ES-9.3 asserte la **composition** (« un podcast PRODUIT PAR LE PORT porte le `sourceHash` fourni ⇒ `isStale` détecte l'obsolescence »), pas « `isStale` marche ». Ne pas **surévaluer** le pouvoir discriminant (leçon L-1 : la formulation ne doit pas prétendre prouver le content-addressing du kernel).
- **🔴 AD-19.1 DÈS LE DÉPART + verrou (M-1) — leçon dominante ES-9.1.** Le request porte un `extra` LIBRE ⇒ il DOIT protéger `extra` via accessor-sanitize (slot `_extra` brut + `get extra => zSanitizeExtra(_extra, {...ZSyncMeta.reservedKeys})`). Le défaut ES-9.1 était double : (1) garde absente, masquée derrière un faux diagnostic ; (2) premier correctif = garde « vœu » sans test. ES-9.3 livre garde **ET** verrou package-local `z_podcast_request_reserved_keys_test.dart` dans le MÊME lot. `reserved_keys_gate` (`tool/reserved_keys_gate`) **n'importe PAS `zcrud_study`** ⇒ **SEUL** ce test package-local couvre le DTO. Ce request n'est **pas** persisté (VO éphémère) ⇒ conséquence runtime tolérable, mais la garde machine reste **uniforme** sur tout porteur d'`extra` (AD-19.1).
- **`sourceHash` opaque, D4 — le domaine ne hashe RIEN.** `package:crypto`/SHA-256 est INTERDIT (NFR-S10/SM-S7, précédent `ZColorPalette`). Le request **transporte** un `String` fourni par l'appelant ; le hashing du contenu source est un seam app/binding. Un scan anti-crypto verrouille l'invariant (AC4).
- **Pas de `ZSourceRegistry` ici (contraste ES-9.1).** La provenance de flashcard est OUVERTE (variants IFFD/lex) ⇒ registre. La nature de source d'un podcast est un enum FERMÉ (`ZPodcastSourceKind {note, folder, document}`) ⇒ **pas** de registre, **pas** de `switch`/`kind` en dur. Le request porte l'enum kernel tel quel. Introduire un registre serait une sur-ingénierie (AD-4 : registre = ouverture inter-package, absente).
- **`abstract interface class` (AD-4).** Port = interface pure (l'app *implements* son pipeline TTS). **Jamais `sealed`** (frontière inter-package). Aucune impl de référence dans le package (le port n'a aucun comportement neutre à factoriser — contraste avec un repository Template Method).
- **Pas de codegen.** `ZPodcastGenerationRequest` n'est **pas** une entité persistée (`@ZcrudModel`) : VO éphémère. (Dé)sérialisation inexistante (le request ne se sérialise pas) → `zcrud_study` reste sans `*.g.dart` (gate `codegen-distribution` sans objet, comme aujourd'hui). `ZStudyPodcast` (persisté) vit au kernel avec son `*.g.dart` déjà committé.
- **Directionnalité RTL / const / a11y (AD-13).** Aucun widget dans ES-9.3 (domaine pur) → sans objet cette story.

### Project Structure Notes

- Un seul nouveau fichier de prod sous `packages/zcrud_study/lib/src/domain/` (dossier créé par ES-9.1) — cohérent hexagonal (AD-1).
- Barrel unique `lib/zcrud_study.dart` (une seule surface publique ; +1 export).
- **Pubspec INCHANGÉ** : c'est la variance attendue (contraste ES-9.1/9.2 qui ajoutaient une arête) — ES-9.3 consomme le kernel déjà branché.

### References

- Story & ACs source : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-9.3` (l. 972-984) ; FR-S31 (l. 64, 135).
- Invariants : `…/architecture-zcrud-study-2026-07-12/architecture.md` — AD-4 (l. 280), AD-5/AD-11 (ports neutres `Either<ZFailure,·>`), AD-12 zéro secret (l. 52, 469), AD-19.1 accessor-sanitize (l. 104-135, 129 `...ZSyncMeta.reservedKeys` NON NÉGOCIABLE), AD-26 seams (l. 254, 280 « app-specific derrière un port neutre … podcast »), impl derrière seams côté app (l. 469 « TTS podcast … fournies par les apps, hors package »).
- Entité RÉUTILISÉE : `packages/zcrud_study_kernel/lib/src/domain/z_study_podcast.dart` (`buildId` l. 234, `isStale` l. 243, `sourceHash` opaque D4 l. 12-23) + enums `z_podcast_mode.dart`/`z_podcast_source_kind.dart`/`z_podcast_status.dart` ; barrel kernel `zcrud_study_kernel.dart:82-95`.
- Précédent DIRECT (patron à réutiliser) : ES-9.1 requests avec `extra` accessor-sanitize — `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:57-67` ; verrou M-1 `packages/zcrud_study/test/z_ai_ports_reserved_keys_test.dart` ; scan anti-secret `packages/zcrud_study/test/z_ai_ports_no_secret_test.dart` ; code-review `_bmad-output/implementation-artifacts/stories/code-review-es-9-1.md` (M-1/M-2, leçon « garde = vœu sans test »).
- `ZResult`/`ZFailure`/`zSanitizeExtra`/`ZSyncMeta`/`zJsonEquals` : `packages/zcrud_core/lib/src/domain/failures/z_failure.dart:93` + `zcrud_core/domain.dart`.
- Pubspec (INCHANGÉ) : `packages/zcrud_study/pubspec.yaml` (bloc « Arêtes inter-packages », `zcrud_study_kernel` déjà déclaré).
- Tooling gate : `scripts/dev/graph_proof.py`, `scripts/ci/gate_secret_scan.dart` (`gate:secrets`), `dart run melos run verify` (`gate:reserved-keys` + `gate:secrets` repo-wide).
- Leçons rétro : R20/R24 (`epic-es-6/7-retrospective.md`), R21/R26, M-1/M-2 (`code-review-es-9-1.md`).

### Vérif verte à rejouer (avant tout `review`/`done`)

**RC hors pipe (R15)** : lancer chaque commande **séparément** et capturer `echo "RC=$?"` **non pipé** (jamais `cmd | tee` qui masque le RC). **Runner R14** : `flutter test` (package Flutter), **jamais** `dart test`.

- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 44`** (delta 0 — aucune arête ajoutée), 20 nœuds.
- `dart run melos list` → workspace stable (20 packages, aucun cassé).
- `melos run generate` → no-op pour `zcrud_study` (aucun `@ZcrudModel`), repo-wide vert.
- `flutter analyze` sur `packages/zcrud_study` → RC=0 (cible dev actif) ; **au gate de commit d'epic** : `dart run melos run analyze` **REPO-WIDE** (détecte les régressions cross-package — NON-NÉGOCIABLE).
- `flutter test` sur `packages/zcrud_study` (**R14**) → RC=0, tous les AC couverts, chaque injection R3 prouvée RED puis restaurée. Compte attendu ≥ 115 (base ES-9.1/9.2) + nouveaux tests ES-9.3.
- `dart run scripts/ci/gate_secret_scan.dart` → **vert** (AC2/AD-12).
- **Au gate de commit d'epic uniquement** (workstreams au repos) : `dart run melos run verify` **REPO-WIDE** (miroir CI : graph_proof + `gate:reserved-keys` + `gate:secrets` + analyze + test).

## Findings / dettes anticipés

- **DW-ES93-1 (impl concrète du seam TTS, hors périmètre).** Le pipeline TTS/synthèse audio réel (routeur, prompts, streaming, upload storage, résolution `resultRef → blob`) est **app-side** (AD-26/AD-12) — ES-9.3 ne livre que le port. Aucune dette : c'est le design.
- **DW-ES93-2 (calcul du `sourceHash` hors domaine, D4).** SHA-256 du contenu source vit **app-side/binding** (parité lex). Le domaine transporte un `String` opaque, il ne hashe rien. Frontière honnête — l'introduire ferait acquérir `crypto` au package (verrouillé par `z_podcast_no_crypto_test.dart`).
- **DW-ES93-3 (pas de registre de source podcast).** `ZPodcastSourceKind` est un enum FERMÉ (kernel) ⇒ pas de `ZSourceRegistry` (contraste ES-9.1). Si un variant de source OUVERT devenait nécessaire (improbable), ce serait une story dédiée ouvrant un registre — hors périmètre, à ne pas anticiper (AD-4).
- **DW-ES93-4 (`ZPodcastGenerationRequest` non persisté).** VO éphémère (jamais écrit au store) ⇒ conséquence runtime AD-19.1 tolérable, mais la garde machine reste **uniforme** (verrou M-1). S'il devait un jour être caché, ce serait une entité `@ZcrudModel` distincte (hors périmètre).
- **DW-ES93-5 (chaîne sérielle).** ES-9.4 écrit aussi `zcrud_study` — **jamais** en vol avec ES-9.3. Rappel orchestrateur (déjà couvert par sprint-status `[SÉQ]`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill BMAD `bmad-dev-story`).

### Debug Log References

RC hors pipe (R15), runner `flutter test` (R14). Injections R3 prouvées RED puis restaurées vert :

- **R3-I1 (AC1)** — `==` rendu par identité seule (`false && …`) ⇒ `z_podcast_generation_port_test.dart` **RC=1** (test « == par valeur »). Restauré → vert.
- **R3-I2 (AC2)** — clé `AIzaSy…` insérée dans le fichier domaine ⇒ `z_ai_ports_no_secret_test.dart` **RC=1** ET `dart run scripts/ci/gate_secret_scan.dart` **RC=1** (`cle Google (AIza...)` détectée). (URL nue seule : test local RED, gate:secrets cible clés/tokens.) Restauré → vert.
- **R3-I3 (AC3, LOAD-BEARING M-1)** — accesseur neutralisé (`get extra => _extra`) ⇒ `z_podcast_request_reserved_keys_test.dart` **RC=1** (`updated_at` survit). Restauré → vert.
- **R3-I4 (AC4 anti-crypto)** — `import 'package:crypto/crypto.dart'` ajouté ⇒ `z_podcast_no_crypto_test.dart` **RC=1**. Restauré → vert.
- **R3-I5 (AC5 graphe)** — arête parasite `zcrud_note` au pubspec ⇒ `graph_proof` **45 arêtes** (≠ 44). Restauré → 44.

Vérif verte finale (RC=0 partout) : `dart pub get` RC=0 ; `flutter test` (zcrud_study) **RC=0, 148 tests** ; `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK, **total arêtes = 44**, 20 nœuds ; `dart run melos list` → 20 packages ; `dart run melos exec --scope=zcrud_study -- dart analyze` RC=0 (SUCCESS) ; `dart run melos run verify` **RC=0** (graph_proof + `gate:secrets OK` + `gate:reserved-keys OK` + verify:serialization OK, repo-wide).

### Completion Notes List

- Un seul fichier de prod ajouté : `z_podcast_generation_port.dart` — `ZPodcastGenerationRequest` (VO immuable, `extra` protégé AD-19.1 accessor-sanitize) + `ZPodcastGenerationPort` (`abstract interface class`, `Future<ZResult<ZStudyPodcast>>`, jamais `sealed`).
- `ZStudyPodcast` + enums `ZPodcastSourceKind`/`ZPodcastMode` **réutilisés** du kernel (aucun modèle recréé, R21). `sourceHash` transporté comme `String` OPAQUE FOURNI — **aucun** crypto dans le seam (D4), verrouillé par `z_podcast_no_crypto_test.dart`.
- **Pas de `ZSourceRegistry`** (contraste ES-9.1) : `sourceKind` est un enum kernel FERMÉ.
- Garde AD-19.1 livrée **AVEC son verrou package-local** dès le premier lot (leçon M-1 ES-9.1 — `reserved_keys_gate` n'importe pas `zcrud_study`, seul ce test couvre le DTO).
- **Delta graphe = 0** (44 arêtes) : pubspec ES-9.3 inchangé (arête `zcrud_study_kernel` préexistante). Aucun SDK IA/TTS/HTTP/crypto ajouté.
- Ancrage R20 respecté : les tests assertent la **circulation** du `sourceHash` de bout en bout + surface du port + garde `extra`, **pas** `buildId`/`isStale` en boîte noire (code kernel déjà testé).

### File List

Créés :
- `packages/zcrud_study/lib/src/domain/z_podcast_generation_port.dart`
- `packages/zcrud_study/test/z_podcast_generation_port_test.dart`
- `packages/zcrud_study/test/z_podcast_request_reserved_keys_test.dart`
- `packages/zcrud_study/test/z_podcast_no_crypto_test.dart`

Modifiés :
- `packages/zcrud_study/lib/zcrud_study.dart` (barrel : +1 export domaine)
- `packages/zcrud_study/test/z_ai_ports_no_secret_test.dart` (seuil de comptage relevé `>= 4` → `>= 5`)

**Pubspec INCHANGÉ par ES-9.3** (aucune dépendance ajoutée — arête `zcrud_study_kernel` préexistante ; le diff pubspec du working tree est l'héritage non committé ES-9.1/9.2). **sprint-status.yaml NON touché** (édition ciblée réservée à l'orchestrateur).
