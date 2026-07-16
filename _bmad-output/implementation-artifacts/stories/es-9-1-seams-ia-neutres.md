# Story ES-9.1 : Seams IA neutres (génération, explication, résumé, quota) + registre de provenance

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrateur**,
I want **des ports neutres `ZFlashcardGenerationPort` / `ZAiExplanationPort` / `ZNoteSummaryPort` (`Either<ZFailure,·>`), un value-object `ZEducationQuotaInfo` fail-open, et la provenance de flashcard branchée sur le registre pluggable `ZSourceRegistry` (AD-4)**,
so that **je branche mon routeur IA app-specific sans que prompts / endpoints / transport / clés ne fuient dans le domaine, que le quota indisponible ne bloque jamais, et que mes variants de provenance IFFD/lex (`article`, `subject`, `hsSection`, `chatConversationId`) s'enregistrent sans modifier `zcrud_study`.**

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

Cette story est la **1ʳᵉ de la chaîne sérielle ES-9.1 → 9.2 → 9.3 → 9.4** qui écrivent TOUTES `zcrud_study` : **une seule en vol**, jamais en parallèle (epics § ES-9 ; sprint-status `[SÉQ — écrit zcrud_study]`). Aucune parallélisation.

**Périmètre validé sur disque (ne rien inventer) :**

- `zcrud_study` est aujourd'hui un package **présentation-only** : `lib/src/presentation/` uniquement, barrel `lib/zcrud_study.dart` (vérifié). ES-9.1 **crée le premier `lib/src/domain/`** du package.
- **Aucun `ZEducationQuotaInfo` n'existe** dans le repo (grep exhaustif : 0 occurrence). → **NOUVEAU** value-object, à créer.
- **La provenance de flashcard EXISTE DÉJÀ** et est **déjà** registre-pluggable : `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` (`ZFlashcardSource` union `sealed` INTERNE + variant de repli `ZCustomSource` + `fromJson`/`toJson` paramétrés par un `ZSourceRegistry?`). Le registre `ZSourceRegistry` vit dans `zcrud_core` (`packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart`), réexporté par le barrel `zcrud_flashcard`. → **NE PAS recréer un modèle de provenance.** ES-9.1 **RÉUTILISE** ce mécanisme et **PROUVE** qu'un variant IFFD/lex s'enregistre + round-trip EXACT, sans toucher `zcrud_flashcard` ni `zcrud_study`.
- `ZFlashcard` (retour du port de génération) vit dans `zcrud_flashcard` ; son `fromMap`/`toMap` thread déjà le `ZSourceRegistry?` pour `source` (`z_flashcard.dart:98,125,210-211,329`).

**Arête de graphe AJOUTÉE (AD-1) :** le port de génération renvoie `List<ZFlashcard>` et la provenance passe par `ZFlashcardSource`/`ZSourceRegistry` → `zcrud_study` **doit dépendre de `zcrud_flashcard`**. Cette arête **n'existe pas encore** (le pubspec de `zcrud_study` l'interdit explicitement en attendant « la story qui la consomme réellement » — c'est CELLE-CI). ES-9.1 est cette story : arête **`zcrud_study → zcrud_flashcard`** ajoutée, **acyclique** (`zcrud_flashcard → core/kernel/annotations/generator`, jamais l'inverse ; `zcrud_flashcard` ne dépend PAS de `zcrud_study`), **CORE OUT=0 préservé**. Compte graph_proof mesuré aujourd'hui : **42 arêtes / 20 nœuds** → **43 arêtes** après (delta = **+1**, une seule arête).

**Runner (R14) :** `zcrud_study` est un package **Flutter** (`flutter` + `flutter_test` en deps — pubspec vérifié). Les nouveaux fichiers domaine sont pur-Dart, mais **les tests se lancent via `flutter test`** (jamais `dart test`) car le package est Flutter. **R25** : l'ajout de la dépendance `zcrud_flashcard` **mute le workspace** (`dart pub get`/bootstrap) — ES-9.1 étant seule en vol dans la chaîne, la fenêtre pub-get est naturellement sérialisée (aucun autre workstream `zcrud_study` actif).

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** (R12) : ancré sur la **ligne de prod PROPRE à ES-9.1** (R20/R24), prouvé par une injection qui la neutralise (§ Injections R3). Une garde de filtrage/transformation asserte la **PRÉSERVATION EXACTE**, jamais la seule absence d'anomalie (R26).

**AC1 — Ports IA neutres (`Either<ZFailure,·>`, AD-5/AD-11)**
**Given** un routeur IA app-specific
**When** on définit les trois ports dans `zcrud_study/lib/src/domain/`
**Then**
- `ZFlashcardGenerationPort` expose `Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest request)` ;
- `ZAiExplanationPort` expose `Future<ZResult<String>> explain(ZAiExplanationRequest request)` ;
- `ZNoteSummaryPort` expose `Future<ZResult<String>> summarize(ZNoteSummaryRequest request)` ;
- `ZResult<T>` = `Either<ZFailure,T>` (`zcrud_core`, `z_failure.dart:93`) ; `void` ⇒ `Unit` ; **aucun `Stream` enveloppé** (AD-5) ;
- chaque **request est un value-object IMMUABLE** (`==`/`hashCode` par valeur, champs `final`, pas de setter) ;
- les ports sont `abstract interface class` (AD-4 : `abstract interface`, **jamais `sealed`** — l'app *implements*, aucune impl de référence dans le package).
**Discriminant** — un test de surface (`ZFlashcardGenerationPort` implémenté par un fake) vérifie le **type de retour exact** (`ZResult<List<ZFlashcard>>`, pas `List<ZFlashcard>` nu) et l'**égalité par valeur** du request ; injection R3-I1 (retour non enveloppé / request à égalité d'identité) ⇒ RC=1.

**AC2 — Zéro fuite transport / prompt / secret dans le package (AD-12, Key Don't « never de secret »)**
**Given** que `toWireJson` / prompts / endpoints / streaming SSE / clés API restent **côté app**
**When** on analyse les 4 fichiers domaine + le pubspec de `zcrud_study`
**Then**
- **aucun** littéral d'endpoint/URL (`http://`, `https://`, `api.`, `.com/v1`, …), **aucune** clé/token, **aucun** nom de header provider en dur, **aucune** chaîne de prompt, **aucun** `toWireJson`/`toSse`/mécanique de transport dans les fichiers ES-9.1 ;
- **aucune** dépendance IA/HTTP concrète ajoutée au pubspec (`http`, `dio`, `openai`, `google_generative_ai`, `firebase_ai`, SDK IA quelconque) — la seule arête ajoutée est `zcrud_flashcard` ;
- `dart run scripts/ci/gate_secret_scan.dart` (gate `gate:secrets`, AD-12) **vert**.
**Discriminant** — un test de scan LOCAL au package énumère les 4 fichiers et asserte l'**absence** de tout motif endpoint/clé/prompt ; injection R3-I2 (insérer `const _endpoint = 'https://api.openai.com/v1/chat'`) ⇒ le scan RC=1 (et `gate:secrets` RC=1). L'AC prouve l'**absence RÉELLE**, pas « le fichier compile ».

**AC3 — `ZEducationQuotaInfo` fail-open (AD-4, « indisponible ⇒ ne bloque pas »)**
**Given** un quota IA indisponible ou épuisé
**When** on construit `ZEducationQuotaInfo` (`int? limit`, `int? remaining`, `int? resetSeconds` — **tous nullables**)
**Then**
- quota **indisponible** (`ZEducationQuotaInfo.unavailable()` / tous champs `null`) ⇒ `allowsRequest == true` (**FAIL-OPEN** : l'absence d'info NE BLOQUE PAS) ;
- `remaining == 0` (ou `< 0`) ⇒ `allowsRequest == false` (seul cas bloquant : `remaining != null && remaining <= 0`) ;
- `remaining > 0` (ou `remaining == null` avec `limit`/`reset` présents) ⇒ `allowsRequest == true` ;
- la construction se fait **côté datasource** (app) à partir des headers HTTP — le VO reste **transport-agnostique** : s'il expose un helper `fromHeaders`, **les noms de header sont INJECTÉS** (paramètres `limitKey`/`remainingKey`/`resetKey`), **jamais** de nom de header provider codé en dur (sinon fuite transport, viole AC2/AD-11).
**Discriminant** — la garde porte sur la **sémantique fail-open**, pas l'existence du champ : injection R3-I3 (faire retourner `false` quand tous champs `null`) ⇒ le test « indisponible ⇒ autorisé » RC=1. Un quota indisponible qui bloquerait est le bug exact que cet AC interdit.

**AC4 — Désérialisation défensive + round-trip DISCRIMINANT du quota (AD-10, R22/R26)**
**Given** des données de quota corrompues/partielles
**When** on parse puis re-sérialise `ZEducationQuotaInfo`
**Then**
- `fromJson`/`fromHeaders` sur entrée `null`, non-map, ou valeurs non-numériques (`"abc"`, `true`, listes) ⇒ **jamais de throw** (AD-10), champs illisibles ⇒ `null` (repli sûr, parse via `int.tryParse`/coercion défensive) ;
- **round-trip EXACT** : pour tout `q` valide, `ZEducationQuotaInfo.fromJson(q.toJson()) == q` — **les trois champs survivent byte-à-byte, `null` inclus** (R26 : préservation EXACTE, pas « pas d'exception »).
**Discriminant R22/R26** — prouver par injection de **sur-purge** : R3-I4 (un `toJson` qui **omet `resetSeconds`**) ⇒ le round-trip `fromJson(toJson()) == q` RC=1. L'assertion vérifie que **chaque** champ (`limit`, `remaining`, `resetSeconds`) est restitué, y compris le cas où deux d'entre eux sont `null` et un seul non-`null` — un round-trip qui « tolère » la perte d'un champ échoue. **Ne pas** se contenter d'asserter « fromJson ne lève pas ».

**AC5 — Provenance de flashcard par REGISTRE pluggable, jamais par switch exhaustif (AD-4, R21/R26)**
**Given** une provenance de flashcard produite par la génération (`article`/`subject`/`hsSection`/`chatConversationId` — variants IFFD/lex)
**When** une app hôte l'enregistre et la fait transiter par le port
**Then**
- le variant IFFD/lex est enregistré via `ZSourceRegistry.register(kind, fromJson: …, toJson: …)` (AD-4 pt.3) **sans modifier `zcrud_study` ni `zcrud_flashcard`** (réutilisation stricte de l'existant) ;
- une carte produite par `ZFlashcardGenerationPort` porte cette provenance dans son `ZFlashcard.source`, et **round-trip EXACT** via `ZFlashcard.toMap(sourceRegistry:)` → `ZFlashcard.fromMap(…, sourceRegistry:)` : `kind` **et** le corps du variant (`hsSection`/`chatConversationId`/…) sont **préservés à l'identique** ;
- **aucun `kind` de provenance douane/lex n'est codé en dur dans `zcrud_study`** (pas de `switch`/`if (kind == 'article')` — la surface reste générique).
**Discriminant R26** — injection de **sur-purge** R3-I5 (un `toJson` de codec enregistré qui **droppe `hsSection`**) ⇒ le round-trip « corps préservé » RC=1 ; ancrage R21 : le test enregistre un variant **au niveau de l'app (dans le test)**, jamais en éditant le package d'origine ; grep R3-I6 (ajouter `article` en variant codé en dur dans `zcrud_study`) ⇒ le test « aucun kind lex en dur » RC=1. L'AC asserte la **préservation exacte du variant**, pas « le round-trip ne throw pas ».

**AC6 — Graphe acyclique, arête justifiée (AD-1/AD-17, CORE OUT=0)**
**Given** l'arête `zcrud_study → zcrud_flashcard` ajoutée
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 43`** (42 → 43, **exactement +1**), 20 nœuds inchangés ; le pubspec de `zcrud_study` documente l'arête (`zcrud_flashcard` : consommé par ES-9.1 pour `ZFlashcard`/`ZFlashcardSource`/`ZSourceRegistry`). **Aucune** autre arête ajoutée (pas de gestionnaire d'état, pas de SDK IA).
**Discriminant** — un delta ≠ +1 (ex. arête `zcrud_riverpod`/`get`/SDK ajoutée par erreur) fait diverger le compte ⇒ échec ; `graph_proof` refuse tout cycle.

## Tasks / Subtasks

- [x] **T1 — Arête de graphe + pubspec (AC6)** — `packages/zcrud_study/pubspec.yaml`
  - [x] Ajouter `zcrud_flashcard: ^0.1.0` sous `dependencies` ; retirer `zcrud_flashcard` de la liste ⛔ interdite du commentaire, y documenter l'arête (« AJOUTÉE par ES-9.1 : `ZFlashcard` retour du port de génération + provenance `ZFlashcardSource`/`ZSourceRegistry`. Acyclique : flashcard → core/kernel, jamais l'inverse »).
  - [x] **NE PAS** ajouter `http`/`dio`/SDK IA/gestionnaire d'état (AC2).
  - [x] `dart pub get` (fenêtre R25 : ES-9.1 seule en vol) puis `python3 scripts/dev/graph_proof.py` → **43 arêtes**, ACYCLIQUE OK, CORE OUT=0 OK.

- [x] **T2 — `ZEducationQuotaInfo` (AC3, AC4)** — **NOUVEAU** `packages/zcrud_study/lib/src/domain/z_education_quota_info.dart`
  - [x] Classe immuable `const ZEducationQuotaInfo({this.limit, this.remaining, this.resetSeconds})` — 3 champs `int?` ; `const ZEducationQuotaInfo.unavailable()` (tous `null`).
  - [x] `bool get allowsRequest` — **fail-open** : `true` sauf si `remaining != null && remaining <= 0`.
  - [x] `Map<String,dynamic> toJson()` + `factory ZEducationQuotaInfo.fromJson(Object? raw)` **défensif** (coercion `int?` via `int.tryParse`/`num`, non-map ⇒ `unavailable()`, **jamais de throw** — AD-10).
  - [x] (Optionnel) `factory ZEducationQuotaInfo.fromHeaders(Map<String,String>? headers, {required String limitKey, required String remainingKey, required String resetKey})` — noms de header **INJECTÉS**, défensif ; **aucun** nom de header en dur (AC2).
  - [x] `==`/`hashCode` par valeur (3 champs) ; dartdoc `origine`/AD.

- [x] **T3 — `ZFlashcardGenerationPort` + request (AC1, AC5)** — **NOUVEAU** `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart`
  - [x] `ZFlashcardGenerationRequest` : value-object immuable (`==`/`hashCode`) portant le **contenu source neutre** (ex. `String content`, `int? count`, `String? languageTag`, **`ZFlashcardSource? provenance`**, `Map<String,dynamic> extra = const {}`). **Aucun** prompt/endpoint/clé (AC2).
  - [x] `abstract interface class ZFlashcardGenerationPort` : `Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest request)`.
  - [x] Dartdoc : impl (routeur IA, prompts, `toWireJson`, SSE) **côté app** ; le port stampe `request.provenance` dans `ZFlashcard.source` (AC5, provenance registre-pluggable).

- [x] **T4 — `ZAiExplanationPort` + `ZNoteSummaryPort` + requests (AC1, AC2)** — **NOUVEAUX** `packages/zcrud_study/lib/src/domain/z_ai_explanation_port.dart`, `packages/zcrud_study/lib/src/domain/z_note_summary_port.dart`
  - [x] `ZAiExplanationRequest` (VO immuable : contenu à expliquer + contexte neutre) ; `abstract interface class ZAiExplanationPort { Future<ZResult<String>> explain(ZAiExplanationRequest request); }`.
  - [x] `ZNoteSummaryRequest` (VO immuable) ; `abstract interface class ZNoteSummaryPort { Future<ZResult<String>> summarize(ZNoteSummaryRequest request); }`.
  - [x] Requests **value-objects** (`==`/`hashCode`) ; aucun transport/secret (AC2).

- [x] **T5 — Barrel (AC1)** — `packages/zcrud_study/lib/zcrud_study.dart`
  - [x] Exporter les 4 nouveaux fichiers `src/domain/*.dart`. Ne PAS ré-exporter `ZFlashcard`/`ZFlashcardSource` (le consommateur importe `package:zcrud_flashcard/…`) sauf besoin ergonomique justifié.

- [x] **T6 — Tests `flutter test` (R14) — `packages/zcrud_study/test/`**
  - [x] `z_education_quota_info_test.dart` : fail-open (indispo ⇒ autorisé, `remaining=0` ⇒ bloqué, `remaining>0`/`null` ⇒ autorisé — AC3) ; défensif (garbage ⇒ pas de throw — AC4) ; **round-trip discriminant** `fromJson(toJson()) == q` sur les 3 champs, dont cas `null` partiels (AC4, R26).
  - [x] `z_ai_ports_surface_test.dart` : fakes implémentant les 3 ports ; type de retour exact (`ZResult<List<ZFlashcard>>`/`ZResult<String>`) ; égalité par valeur des requests (AC1).
  - [x] `z_ai_ports_no_secret_test.dart` : scan LOCAL des 4 fichiers domaine — **absence** d'endpoint/clé/prompt/header en dur (AC2).
  - [x] `z_flashcard_provenance_registry_test.dart` : enregistrer un variant lex/IFFD (`article` avec `hsSection` / `conversation` avec `chatConversationId`) via `ZSourceRegistry.register` (**dans le test = app hôte**) ; carte produite par un fake `ZFlashcardGenerationPort` portant cette provenance ; **round-trip EXACT** via `ZFlashcard.toMap(sourceRegistry:)`/`fromMap(…, sourceRegistry:)` — `kind` **et** corps préservés (AC5, R26) ; asserter **aucun `kind` lex en dur** dans `zcrud_study` (grep/source).
  - [x] Chaque test rougit sur son injection R3 dédiée (cf. § Injections R3) — **prouvé au dev**, pas seulement en revue.

- [x] **T7 — Vérif verte rejouée** (§ dédiée) + mise à jour File List.

## Injections R3 prévues (mutation → AC rouge → restauration)

Chaque injection doit **RC=1** sur l'AC ciblé, puis restauration → vert (preuve du pouvoir discriminant, R3/R12).

- **R3-I1 (AC1)** — changer un retour de port en `List<ZFlashcard>` nu (non `ZResult`) **ou** rendre un request `==` par identité ⇒ test de surface RC=1.
- **R3-I2 (AC2 — anti-secret)** — insérer `const _endpoint = 'https://api.openai.com/v1/chat'` (ou une clé) dans un fichier domaine ⇒ `z_ai_ports_no_secret_test.dart` RC=1 **et** `gate:secrets` RC=1.
- **R3-I3 (AC3 — fail-open)** — faire retourner `allowsRequest == false` quand tous les champs sont `null` ⇒ test « quota indisponible ⇒ autorisé » RC=1.
- **R3-I4 (AC4 — round-trip défensif, R26 sur-purge)** — `toJson` qui **omet `resetSeconds`** ⇒ `fromJson(toJson()) == q` RC=1 (préservation exacte des 3 champs).
- **R3-I5 (AC5 — provenance, R26 sur-purge)** — codec enregistré dont le `toJson` **droppe `hsSection`** ⇒ round-trip « corps de provenance préservé » RC=1.
- **R3-I6 (AC5 — pas de switch lex en dur)** — ajouter `if (kind == 'article')` codé en dur dans `zcrud_study` ⇒ test « aucun kind lex en dur » RC=1.
- **R3-I7 (AC6 — graphe)** — ajouter une arête parasite (ex. `http`/`flutter_riverpod`) ⇒ `graph_proof` compte ≠ 43 / échec de justification.

## Dev Notes

- **RÉUTILISER, ne pas recréer (R21/SM-S4).** La provenance registre-pluggable **existe déjà** (`ZFlashcardSource` + `ZSourceRegistry`). ES-9.1 ne crée **aucun** nouveau modèle de provenance ; elle **consomme** l'existant et **prouve** l'extensibilité (variant lex enregistré + round-trip exact). Recréer un registre serait un doublon inter-package interdit (AD-4).
- **Ancrage R20/R24.** Les ports/VO d'ES-9.1 sont des **contrats propres à ES-9.1** — ancrer chaque AC sur SA ligne (type de retour du port, sémantique `allowsRequest`, exactitude du round-trip du VO, préservation du corps de provenance). **Ne PAS** ré-tester en boîte noire `ZFlashcardSource.fromJson`/`ZSourceRegistry.register` (ce sont des mécanismes de `zcrud_flashcard`/`zcrud_core` **déjà** testés — les asserter serait POWERLESS sur ES-9.1, piège R20). Le test provenance d'ES-9.1 asserte la **composition** : « une carte PRODUITE PAR LE PORT round-trippe sa provenance enregistrée », pas « le registre marche ».
- **R26 (leçon centrale ES-8).** Les gardes round-trip (AC4/AC5) sont des gardes de **transformation** : asserter la **PRÉSERVATION EXACTE** (`fromJson(toJson()) == q`, corps de variant byte-à-byte), **jamais** « pas de throw » ni « champ présent ». Prouver par injection de **sur-purge** (omission d'un champ ⇒ RC=1). Un round-trip vrai de façon **vacue** (VO vide, provenance sans corps) ne compte pas — inclure des cas non-dégénérés (champs partiels non-`null`, variant à corps riche).
- **Fail-open (AC3) — l'inverse du réflexe.** L'intuition « quota indisponible ⇒ refuser » est **le bug**. Indisponible ⇒ **autoriser**. Seul `remaining <= 0` connu bloque. Le VO ne décide **jamais** de politique réseau/retry — juste `allowsRequest`.
- **Anti-secret (AC2/AD-12).** Le package ne connaît **ni** endpoint **ni** clé **ni** prompt **ni** nom de header provider. Le datasource app extrait les headers → construit le VO. Un `fromHeaders` dans le package est acceptable **uniquement** avec noms de header **injectés** (jamais `'x-ratelimit-remaining'` en dur = fuite transport).
- **`abstract interface class` (AD-4).** Ports = interfaces pures (l'app *implements*). **Jamais `sealed`** (frontière inter-package). Pas d'impl de référence dans le package (contraste avec `ZStudyRepository` qui, lui, porte un Template Method concret car il a un comportement à factoriser — ici les ports n'ont aucun comportement neutre à fournir).
- **Pas de codegen.** `ZEducationQuotaInfo` n'est **pas** une entité persistée (`@ZcrudModel`) : c'est un VO éphémère construit depuis les headers (AC3). (Dé)sérialisation **manuelle** défensive → `zcrud_study` reste sans `*.g.dart` (gate `codegen-distribution` sans objet, comme aujourd'hui).
- **Directionnalité RTL / const / a11y (AD-13).** Aucun widget dans ES-9.1 (domaine pur) → sans objet cette story.

### Project Structure Notes

- Nouveaux fichiers **tous** sous `packages/zcrud_study/lib/src/domain/` (premier dossier domaine du package) — cohérent avec la structure hexagonale `domain`/`data`/`presentation` (AD-1).
- Barrel unique `lib/zcrud_study.dart` (pas de `domain.dart` séparé — le package n'en a pas ; garder une seule surface publique).
- **Conflit/variance** : le pubspec interdisait `zcrud_flashcard` « jusqu'à la story qui la consomme » ; ES-9.1 lève l'interdiction **avec justification** (T1). C'est la variance attendue, pas une entorse.

### References

- Story & ACs source : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-9.1` (l. 932-952) ; FR-S29 (l. 62, 133).
- Invariants : `…/architecture-zcrud-study-2026-07-12/architecture.md` — AD-4 (l. 46, 280), AD-5/AD-11 (ports neutres `Either<ZFailure,·>`), AD-12 zéro secret (l. 52, 469), seams/registres/quota fail-open (l. 280), impl derrière seams côté app (l. 469).
- Provenance existante (À RÉUTILISER) : `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` ; registre `packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart` + base `z_open_registry.dart`.
- `ZFlashcard` (retour + source) : `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:68,83,98,125,210,329`.
- `ZResult`/`ZFailure` : `packages/zcrud_core/lib/src/domain/failures/z_failure.dart:22,44,93`.
- Pubspec + arête à muter : `packages/zcrud_study/pubspec.yaml` (bloc « Arêtes inter-packages »).
- Tooling gate : `scripts/dev/graph_proof.py`, `scripts/ci/gate_secret_scan.dart` (`gate:secrets`), `melos.yaml:55,65,89` (`verify`).
- Leçons rétro : R20/R24 (`epic-es-6/7-retrospective.md`), R21 (`epic-es-6-retrospective.md:69`), R22 (`…:72`), R25/R26 (`epic-es-8-retrospective.md:91-92`), dette IA anticipée (`epic-es-8-retrospective.md:109`).

### Vérif verte à rejouer (avant tout `review`/`done`)

**RC hors pipe (R15)** : lancer chaque commande **séparément** et capturer `echo "RC=$?"` **non pipé** (jamais `cmd | tee` qui masque le RC). **Runner R14** : `flutter test` (package Flutter), **jamais** `dart test`.

- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 43`** (delta +1 = `zcrud_study → zcrud_flashcard`), 20 nœuds.
- `dart run melos list` → workspace stable (aucun package cassé par l'arête ajoutée).
- `dart pub get` (racine) → résolution verte (fenêtre R25, ES-9.1 seule en vol).
- `melos run generate` → no-op pour `zcrud_study` (aucun `@ZcrudModel`), repo-wide vert.
- `flutter analyze` sur `packages/zcrud_study` → RC=0 (cible dev actif) ; **au gate de commit d'epic** : `dart run melos run analyze` **REPO-WIDE** (détecte les régressions cross-package — NON-NÉGOCIABLE).
- `flutter test` sur `packages/zcrud_study` (**R14**) → RC=0, tous les AC couverts, chaque injection R3 prouvée RED puis restaurée.
- `dart run scripts/ci/gate_secret_scan.dart` → **vert** (AC2/AD-12).
- **Au gate de commit d'epic uniquement** (workstreams au repos) : `dart run melos run verify` **REPO-WIDE** (miroir CI : graph_proof + gates + analyze + test).

## Findings / dettes anticipés

- **DW-ES91-1 (impl concrète du seam, hors périmètre).** Les impls IA réelles (routeur, prompts, `toWireJson`, TTS, SSE) sont **app-side** (AD-26/AD-12) — ES-9.1 ne livre que les ports. Aucune dette : c'est le design.
- **DW-ES91-2 (variant `subject` non pré-fourni).** L'AC mentionne `subject`/`article`/`hsSection`/`chatConversationId` : ce sont des variants **OUVERTS** enregistrés par l'app via `ZSourceRegistry` (jamais des variants codés dans `zcrud_flashcard`). ES-9.1 en **prouve** l'enregistrement + round-trip ; elle n'ajoute **aucun** variant en dur (le faire violerait AD-4). Pas de dette.
- **DW-ES91-3 (`ZEducationQuotaInfo` non persisté).** VO éphémère (headers) — s'il devait un jour être caché/persisté, ce serait une entité `@ZcrudModel` distincte (hors périmètre). Frontière honnête, à ne pas anticiper.
- **DW-ES91-4 (chaîne sérielle).** ES-9.2/9.3/9.4 écrivent aussi `zcrud_study` — **jamais** en vol avec ES-9.1. Rappel orchestrateur (déjà couvert par sprint-status `[SÉQ]`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill réel `bmad-dev-story`).

### Debug Log References

Vérif verte rejouée (RC hors pipe, R15) :
- `python3 scripts/dev/graph_proof.py` → `zcrud_study -> zcrud_flashcard` présent, **total arêtes = 43** (42→43, +1), 20 nœuds, **ACYCLIQUE OK**, **CORE OUT=0 OK**. RC=0.
- `dart run melos list` → 20 packages, workspace stable.
- `dart pub get` (racine) → RC=0 (fenêtre R25, ES-9.1 seule en vol).
- `dart run melos exec --scope=zcrud_study -- dart analyze` → RC=0 (No issues found).
- `flutter test` (packages/zcrud_study, **R14**) → **+112 All tests passed** (28 nouveaux ES-9.1 + 84 existants, zéro régression). RC=0.
- `dart run scripts/ci/gate_secret_scan.dart` → **gate:secrets OK** (AD-12). RC=0.

Injections R3 (mutation → AC rouge RC=1 → restauration ciblée → vert) — TOUTES prouvées RED puis restaurées :
- R3-I1 (AC1) : `==` du request en identité ⇒ `z_ai_ports_surface_test` RED (1) → restauré.
- R3-I2 (AC2) : `const _endpoint='https://api.openai.com/v1/chat'` ⇒ `z_ai_ports_no_secret_test` RED → restauré.
- R3-I3 (AC3) : `allowsRequest=false` quand tout null ⇒ `z_education_quota_info_test` RED (5) → restauré.
- R3-I4 (AC4, R26 sur-purge) : `toJson` omet `reset_seconds` ⇒ round-trip RED (2 cas à `resetSeconds` non-null) → restauré.
- R3-I5 (AC5, R26 sur-purge) : codec `article` enregistré (test) dont `toJson` droppe `hs_section` ⇒ round-trip provenance RED (1) → restauré.
- R3-I6 (AC5) : `kind == 'article'` en dur dans `z_ai_explanation_port.dart` ⇒ test « aucun kind lex en dur » RED → restauré.
- R3-I7 (AC6) : arête parasite `zcrud_riverpod` ⇒ graph_proof `total arêtes = 44` (≠ 43) → restauré.

`melos run verify` REPO-WIDE (**RECTIFIÉ après code-review — M-2**) : le diagnostic initial de ce Debug Log était **FAUX** et masquait un défaut réel de cette story. La VÉRITÉ mesurée sur disque :
- **`gate:reserved-keys` terminait bien RED, mais À CAUSE D'ES-9.1** : les 3 request value-objects (`ZFlashcardGenerationRequest`/`ZAiExplanationRequest`/`ZNoteSummaryRequest`) portaient un champ `extra` **sans la protection AD-19.1** (`...ZSyncMeta.reservedKeys`) — 3 violations sur les 3 fichiers de ports NEUFS. Preuve que ce n'était PAS pré-existant : `melos run verify` était **RC=0 au gate de commit ES-8**.
- Les lignes `uses-material-design` sur zcrud_markdown/flutter_quill/zcrud_export sont des **warnings BÉNINS de l'outil `flutter test`** (imprimés à chaque run, y compris au verify vert d'ES-8), **SANS rapport** avec l'échec du gate. Le diagnostic initial les avait confondues avec la vraie panne.
- **CORRECTIF (orchestrateur, remédiation)** : pattern accessor-sanitize DW-ES22-3 appliqué aux 3 ports (slot `_extra` brut + `get extra => zSanitizeExtra(_extra, _reservedKeys)`, `_reservedKeys = {...ZSyncMeta.reservedKeys}`) ⇒ `gate:reserved-keys` **VERT**, `melos run verify` **RC=0**. + **verrou de test** package-local `z_ai_ports_reserved_keys_test.dart` (M-1) qui ROUGIT si l'accesseur est neutralisé.
- **État FINAL vérifié** : `flutter test zcrud_study` **+115** RC=0, `melos run verify` RC=0 (`gate:reserved-keys OK` + `gate:secrets OK`), graph_proof 43 arêtes ACYCLIQUE CORE OUT=0, `melos list`=20.

### Completion Notes List

- 4 fichiers domaine NEUFS (premier `lib/src/domain/` du package) : 3 ports `abstract interface class` (jamais `sealed`, AD-4) retournant `Future<ZResult<…>>` (AD-5, `Either<ZFailure,·>`, aucun `Stream` enveloppé) + requests value-objects immuables (`==`/`hashCode` par valeur, `extra` en égalité profonde via `zJsonEquals`/`zJsonHash`) ; `ZEducationQuotaInfo` VO fail-open (indispo⇒autorisé, seul `remaining<=0` bloque) avec (dé)sérialisation manuelle défensive (AD-10, `int.tryParse`/coercion, jamais de throw) et round-trip EXACT des 3 champs.
- Provenance : RÉUTILISE `ZFlashcardSource` + `ZSourceRegistry` EXISTANTS (aucun modèle recréé, R21). Le test prouve la COMPOSITION propre à ES-9.1 (une carte PRODUITE PAR le port round-trippe sa provenance enregistrée `article`/`chatConversation`, kind ET corps préservés) — pas la mécanique interne du registre (R20). Aucun `kind` lex/douane codé en dur dans `zcrud_study` (garde outillée).
- Arête `zcrud_study → zcrud_flashcard` AJOUTÉE (SEULE nouvelle, 42→43), acyclique (flashcard→core/kernel, jamais l'inverse), CORE OUT=0 préservé. Aucun SDK IA / client HTTP / gestionnaire d'état ajouté (AD-11/AD-12).
- Aucun fichier hors `packages/zcrud_study/` modifié (zcrud_flashcard/core/kernel CONSOMMÉS, non touchés). sprint-status.yaml NON touché.

### File List

Créés :
- `packages/zcrud_study/lib/src/domain/z_education_quota_info.dart`
- `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart`
- `packages/zcrud_study/lib/src/domain/z_ai_explanation_port.dart`
- `packages/zcrud_study/lib/src/domain/z_note_summary_port.dart`
- `packages/zcrud_study/test/z_education_quota_info_test.dart`
- `packages/zcrud_study/test/z_ai_ports_surface_test.dart`
- `packages/zcrud_study/test/z_ai_ports_no_secret_test.dart`
- `packages/zcrud_study/test/z_flashcard_provenance_registry_test.dart`

Modifiés :
- `packages/zcrud_study/pubspec.yaml` (arête `zcrud_flashcard` + justification ES-9.1)
- `packages/zcrud_study/lib/zcrud_study.dart` (barrel : 4 exports domaine)
