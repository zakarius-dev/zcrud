# Story ES-4.4 : Moteur d'examen blanc — `ZWhiteExamSessionEngine` (setup→running→submitted, zéro écriture SM-2 PAR CONSTRUCTION)

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. ES-4.4 dépend d'ES-4.1 (TÊTE, source SM-2 unique verrouillée : le mode examen n'écrit JAMAIS SM-2) ET d'ES-4.2 DONE (package zcrud_session créé, ZSessionItem/ZSessionState/ZStudySessionEngine livrés). SÉQUENTIELLE vis-à-vis d'ES-4.1/4.2/4.3 : MÊME package zcrud_session, mais FICHIER DOMAINE DISTINCT (z_white_exam_session_engine.dart). NE modifie PAS le moteur SRS d'ES-4.2 (z_study_session_engine.dart) NI le runtime linéaire d'ES-4.3 (z_linear_session_state.dart). DERNIÈRE story « runtime » de l'epic avant ES-4.5 (widgets). -->
<!-- ⚠️ PARALLÉLISATION — workstream A. Un workstream B (epic ES-5) écrit packages/zcrud_study/** en parallèle. ISOLATION STRICTE : cette story n'écrit QUE des fichiers NEUFS sous packages/zcrud_session/lib/src/domain/ + 1 ligne additive (export) au barrel packages/zcrud_session/lib/zcrud_session.dart + des tests neufs. NE touche PAS zcrud_core, zcrud_flashcard/lib, zcrud_study, z_study_session_engine.dart, z_linear_session_state.dart, z_session_state.dart, z_session_item.dart (ES-4.2/4.3, réutilisés en LECTURE), NI sprint-status.yaml (orchestrateur). Vérifs CIBLÉES par package (PAS de melos repo-wide au milieu du dev — délégué à l'orchestrateur au gate de commit). -->
<!-- Gotchas rétro en vigueur : R12 (pouvoir discriminant EXIGÉ — machine à états + scoring golden + zéro-SM2-PAR-CONSTRUCTION CENTRAUX), R14 (runner par NATURE du package — zcrud_session = Flutter car ChangeNotifier ∈ flutter/foundation → flutter test), R15 (RC capturé HORS pipe), R13 (restauration par édition ciblée, jamais git checkout), R3 (injections orchestrateur), R6 (jamais de dégradation silencieuse — une transition illégale LÈVE, ne se tait pas). -->

## Story

As a **utilisateur**,
I want **passer un examen blanc (mock) via `ZWhiteExamSessionEngine` — une classe PURE (`ChangeNotifier`/reducer) qui parcourt les états **setup → running → submitted**, enregistre mes réponses, calcule un score à la SOUMISSION, sans détenir NI `ZSrsScheduler`, NI `ZRepetitionStore`, NI seam de review SRS**,
so that **je m'entraîne en conditions d'examen sans jamais modifier ma planification SRS — garantie NON par un test de comportement seul, mais PAR CONSTRUCTION (aucun point d'écriture SRS n'existe dans le runtime), et la machine à états refuse toute transition illégale au lieu de la subir silencieusement.**

---

## Contexte & état mesuré sur disque

> ⚠️ **Aucun nouveau package, aucune nouvelle dépendance, aucun `.g.dart`.** Cette story AJOUTE un fichier domaine DISTINCT dans le package `zcrud_session` **déjà livré par ES-4.2/4.3** et COMPOSE des value-objects existants (`ZSessionItem`, `ZReviewMode.whiteExam`, `ZStudySessionResult`, `ZSrsConfig.passThreshold`). Le graphe de dépendances est **INCHANGÉ** (`graph_proof.py` inchangé), `melos list` reste **20**.

### 1. Le socle ES-4.2/4.3 à COMPOSER (livré, lu INTÉGRALEMENT sur disque)

| Symbole | Fichier (ligne mesurée) | Rôle réutilisé par ES-4.4 |
|---|---|---|
| `ZSessionItem` | `packages/zcrud_session/lib/src/domain/z_session_item.dart` (l.16-50) | Identité **neutre** de carte `{flashcardId, folderId, typeKey?}`, immuable, value-object. **Réutilisée telle quelle** (aucun clone) comme élément de la file d'examen. |
| `ZReviewMode.whiteExam` | `packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart` (l.47-63, valeur `whiteExam` l.61-62 « Examen blanc (conditions d'examen, sans SRS) ») | Mode de session porté par le résultat produit. **Réutilisé** (aucune nouvelle valeur d'enum). |
| `ZStudySessionResult` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart` (l.53-92 : `{mode, total, correct, byQuality}`, `const`, égalité profonde) | **Sortie de scoring** produite à `submit()`. `total` = cartes présentées, `correct` = réponses ≥ `passThreshold`, `byQuality` = distribution qualité. **Réutilisé tel quel** (arête déjà déclarée). |
| `ZSrsConfig` | `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` (l.26/56-58, `passThreshold = 3`) | **Frontière correct/incorrect** `quality >= passThreshold` — **lu**, jamais un `3` littéral (D5). Aucun `ZRepetitionInfo` produit ⇒ pas une écriture SRS. |
| `ZSessionState` | `packages/zcrud_session/lib/src/domain/z_session_state.dart` (l.23-135) | **NE PAS réutiliser** comme état d'examen : `ZSessionState` modélise une file SRS/cramming (queue+réinsertion+lapses), sémantique inadaptée à une machine setup/running/submitted. ES-4.4 déclare son **propre** état immuable `ZWhiteExamState` (value-object dédié, aucune réinsertion, phase explicite). |
| `ZStudySessionEngine` | `z_study_session_engine.dart` (l.115-…) | **NE PAS modifier, NE PAS étendre.** Détient un seam `ZSessionReviewer` = écriture SRS ; c'est précisément ce que l'examen blanc ne doit PAS avoir. Miroir « contraste » d'ES-4.3. |
| `kLapseOffsetSoft/Hard`, `reduceGrade`, `ZLinearSessionState` | `z_study_session_engine.dart` (l.40-110), `z_linear_session_state.dart` | **HORS scope** : l'examen blanc ne re-boucle PAS les ratés (parcours strictement linéaire, comme le mode `list`), et n'a aucun offset. NE PAS réutiliser ces mécaniques. |

> ⚠️ **Nuance décisive vs ES-4.2/4.3.** Le cycle SRS (`ZStudySessionEngine`, ES-4.2) **écrit** l'état SRS via une **voie UNIQUE** (`ZSessionReviewer`). Le runtime LINÉAIRE (`ZLinearSessionState`, ES-4.3) est **plus fort** : ZÉRO écriture SRS, aucune voie. `ZWhiteExamSessionEngine` (ES-4.4) hérite de cette garantie **plus forte** (aucun seam SRS) **ET** ajoute une **machine à états à 3 phases avec scoring différé** — ce que ni le cycle ni le linéaire ne modélisent.

### 2. Le barrel actuel (lu — `packages/zcrud_session/lib/zcrud_session.dart` l.21-25)
```dart
export 'src/domain/z_linear_session_state.dart';
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
export 'src/domain/z_session_state.dart';
export 'src/domain/z_study_session_engine.dart';
```
⇒ **1 ligne additive** : `export 'src/domain/z_white_exam_session_engine.dart';` (édition ciblée, additive, du barrel — le SEUL fichier ES-4.2/4.3 touché, et seulement par ajout).

### 3. Runner & gates (MESURÉ — inchangés vs ES-4.2/4.3)
- **`ChangeNotifier` ∈ `package:flutter/foundation.dart`** ⇒ `zcrud_session` = paquet **Flutter** ⇒ **`flutter test`** (R14). `dart test` échouerait (import flutter non résolu hors runner Flutter).
- **`gate:web`** (`scripts/ci/gate_web_determinism.dart`) cible les paquets **PUR-DART** : `zcrud_session` (Flutter) est **HORS cible**. Aucune action web.
- **`gate:graph`** (`scripts/dev/graph_proof.py`) : ES-4.4 n'ajoute **AUCUNE** arête — `zcrud_core`/`zcrud_flashcard`/`zcrud_study_kernel` sont **déjà** déclarés en dépendances d'ES-4.2 (`packages/zcrud_session/pubspec.yaml` l.48-53, MESURÉ). **ACYCLIQUE + CORE OUT=0 préservés, `graph_proof.py` INCHANGÉ.**
- **`gate:melos`** : aucun nouveau package ⇒ `melos list` = **20** (inchangé).
- **`gate:codegen-distribution`** : aucun `@ZcrudModel` (état runtime NON persisté ; le score de sortie `ZStudySessionResult` est produit en mémoire, pas re-sérialisé ici) ⇒ **aucun `*.g.dart`** attendu.

---

## Reconnaissance externe MESURÉE (documentaire — origine du mode examen blanc)

> Chiffres et emplacements **MESURÉS sur disque**. Le critère de résolution **exécutable in-repo** reste le golden de machine à états + scoring ci-dessous (AC2/AC3).

### lex — le mode `whiteExam` « minuté, zéro SM-2 » + la forme de scoring
- `~/DEV/lex_douane/packages/lex_core/lib/domain/enums/review_mode.dart` (l.5, lu) : *« `[test]`, `[whiteExam]` et `[cramming]` **n'écrivent jamais** de `RepetitionInfo` ».*
- `~/DEV/lex_douane/packages/lex_core/lib/domain/enums/study_mode.dart` (l.18, lu) : *« `[whiteExam]` : examen blanc **minuté**. Runtime livré en 13.3 »* ; l.20-22 : *« seuls `[cycleCount]`/`[cycleAll]` écrivent l'état SM-2 ; les modes `[list]`, `[test]`, `[whiteExam]`, `[cramming]` n'écrivent **jamais** de SM-2 »* ; l'extension `StudyModeWritesSm2.writesSm2` (l.54-64) matérialise cette règle en **source unique**.
- `~/DEV/lex_douane/packages/lex_core/lib/domain/entities/education/study_session.dart` (l.46-72, lu) — `StudySessionResult` = **forme canonique du scoring** : `{mode, total, correct, byQuality: Map<String,int>}` où `byQuality` = *« répartition par qualité SM-2 (`"0".."5"` → compte) »*. ⇒ ES-4.4 réutilise l'**équivalent zcrud déjà livré** `ZStudySessionResult` (ES-2.7), même forme `{mode, total, correct, byQuality}` — **aucune duplication** (anti-inertie AD-4).

### ⚠️ GOTCHA MESURÉ — « minuté » = présentation, PAS le domaine pur
Le qualificatif *« minuté »* (chronomètre d'examen) est un **artefact de présentation** (widget/binding, ES-4.5 + ES-9/ES-10). Le **domaine pur** d'ES-4.4 est **agnostique de l'horloge** (D6) : la machine à états et le scoring sont **déterministes** (aucun `DateTime.now()`), reproductibles bit-à-bit. Un éventuel minuteur est piloté par le binding, qui appelle `submit()` à l'échéance — le moteur ne détient **aucune** horloge. *(Cohérent avec `ZExam.daysUntil(now)` d'ES-2.6 : l'horloge est TOUJOURS injectée/externe.)*

### ⚠️ GOTCHA MESURÉ — le runtime `whiteExam` réel de lex vit en présentation
La reconnaissance READ-ONLY (`grep -rniE "whiteExam" ~/DEV/lex_douane/packages/*/lib`, MESURÉ) montre que `whiteExam` est **défini** dans `lex_core` (enum + invariant `writesSm2=false`) mais que son **runtime** (13.3) vit côté `lex_ui` (controller UI), **non** comme classe domaine pure. ES-4.4 **corrige** cela par conception (AD-2/AD-23) : le runtime devient une **classe domaine PURE** dans `zcrud_session`, sans gestionnaire d'état — c'est précisément l'objectif produit n°1. Il n'y a donc **pas** de fichier source domaine à porter à l'identique : la forme est **tranchée ici** (machine à états + scoring), la fidélité étant assurée par les invariants mesurés (mode `whiteExam` sans SM-2 + forme `{total, correct, byQuality}`).

---

## Décisions de conception (tranchées ici)

- **D1 — `ZWhiteExamSessionEngine extends ChangeNotifier` (foundation seule), état = value-object immuable `ZWhiteExamState` + reducers PURS.** Le moteur détient un `ZWhiteExamState _state` **immuable** et l'expose en lecture. Les transitions délèguent à des **reducers PURS top-level** (aucun effet de bord, aucune horloge, aucune I/O) puis `_setState(next)` compare le value-object et n'émet `notifyListeners()` **que si l'état change** (granularité AD-2, miroir ES-4.2/4.3). **AUCUN** `setState`, **AUCUN** import `flutter_riverpod`/`get`/`provider`/`flutter/material`/`flutter/widgets` (AD-2/AD-23/NFR-S5).
- **D2 — Machine à états `setup → running → submitted` (CŒUR).** Enum **NEUF non persisté** `ZWhiteExamPhase { setup, running, submitted }` (runtime, aucun `@ZcrudModel`, aucun codegen). Transitions AUTORISÉES **uniquement** :
  - `start()` : `setup → running` (amorce le parcours, curseur 0).
  - `answer(int quality)` : reste en `running`, enregistre la réponse de la carte courante et avance le curseur linéairement (`0 → N`, aucune ré-insertion, aucun ré-ordonnancement — parcours strict comme le mode `list`).
  - `submit()` : `running → submitted` (fige l'examen, calcule le score).
  Toute autre transition est **ILLÉGALE**.
- **D3 — Transitions illégales : LÈVENT, ne se taisent JAMAIS (R6, pouvoir discriminant AC2).** Une opération appelée dans une phase incompatible **lève un `StateError`** (visible en debug ET release — testable sans dépendre du mode assert) :
  - `start()` hors `setup` (déjà `running`/`submitted`) → `StateError`.
  - `answer(...)` hors `running` (en `setup` avant `start`, ou après `submit`) → `StateError`.
  - `submit()` hors `running` (en `setup`, ou double `submit`) → `StateError`.
  - Pas de retour arrière : `submitted → running` n'existe **pas** (aucune méthode ne l'offre ; toute tentative via `start()` en phase `submitted` lève). ⇒ **jamais** de dégradation silencieuse (no-op muet interdit, R6).
- **D4 — ZÉRO écriture SM-2 PAR CONSTRUCTION (cœur AD-23).** `ZWhiteExamSessionEngine` **ne déclare AUCUN champ** de type `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; son constructeur **n'accepte AUCUN** paramètre de review/scheduler ; son corps **ne mentionne JAMAIS** `apply`/`initial`/`put`/`reviewCard`/`ZRepetitionInfo`. ⇒ il n'existe **aucun point d'appel SRS atteignable** — l'invariant « zéro écriture » est garanti **par la STRUCTURE du type**, pas par une garde runtime. *(Contraste explicite : `ZStudySessionEngine` d'ES-4.2 DÉTIENT un `ZSessionReviewer` ; l'examen blanc n'en détient AUCUN, comme `ZLinearSessionState` d'ES-4.3.)*
- **D5 — Scoring différé à la SOUMISSION, déterministe, réutilise `passThreshold` (CŒUR, AC3/AC5).** À `submit()`, un reducer PUR `scoreWhiteExam(...)` produit un `ZStudySessionResult(mode: ZReviewMode.whiteExam, total, correct, byQuality)` :
  - `total` = nombre de cartes **présentées** (réponses enregistrées) ;
  - `correct` = nombre de réponses de `quality >= passThreshold` (=3 par défaut, **lu** de `ZSrsConfig`, **jamais** un `3` littéral) ;
  - `byQuality` = distribution `Map<String,int>` `"0".."5" → compte` (clé = `quality.toString()`).
  Aucun `ZRepetitionInfo`, aucun `apply` : produire un `ZStudySessionResult` est un **agrégat pur**, pas une écriture SRS.
- **D6 — Scoring COMPOSABLE via un seam PUR optionnel (`ZExamScoringPort`), défaut fourni.** Typedef `typedef ZExamScoringPort = ZStudySessionResult Function(List<int> qualities, {required int passThreshold});`. Le constructeur accepte un `ZExamScoringPort scorer = scoreWhiteExam` (défaut = la fonction pure top-level). ⚠️ Ce seam est **PUR** (entrées = qualités + seuil ; sortie = résultat) — il **ne peut PAS** écrire de SRS (aucun `ZRepetitionStore`/`ZSrsScheduler` en signature). C'est le « seam `ZExamScoringPort` si besoin » de l'AC epic, sans jamais rouvrir la voie SM-2.
- **D7 — Déterminisme total (aucune horloge).** Aucun `DateTime.now()`, aucun `now`. Le « minuté » est piloté par le binding (ES-9/10) qui appelle `submit()` — le domaine reste pur (D6-gotcha). Les reducers sont des **fonctions pures** ⇒ golden reproductible bit-à-bit.
- **D8 — `ZWhiteExamState` value-object immuable dédié (aucun clone de `ZSessionState`).** Champs : `{phase: ZWhiteExamPhase, queue: List<ZSessionItem>, cursor: int, answers: List<int>, result: ZStudySessionResult?}`. `==`/`hashCode` **profonds** (`listEquals`), `copyWith`. `current` = `queue[cursor]` ou `null`. `answered` = `answers.length`. `remaining` = `queue.length - cursor`. **NE PAS** réutiliser `ZSessionState` (sémantique queue/lapse inadaptée, D2-tableau).
- **D9 — `ZExam` (zcrud_exam) NON requis — runtime AUTONOME.** VÉRIFIÉ sur disque : `zcrud_exam` (`z_exam.dart`) est l'**entité de PLANIFICATION** d'un examen daté avec rappels (`{id, folderId, title, date, reminders}`, `@ZcrudModel`) — **rien** dont le runtime d'examen blanc ait besoin. `ZWhiteExamSessionEngine` consomme une **file de `ZSessionItem` déjà sélectionnée** (comme les autres runtimes) et produit un `ZStudySessionResult`. ⇒ **AUCUNE nouvelle arête vers `zcrud_exam`**, `graph_proof.py` **INCHANGÉ**, `melos list = 20`. *(Le lien examen-planifié ↔ examen-blanc, si un jour souhaité, se câble au niveau app/binding, hors domaine.)*
- **D10 — Réutilisation stricte, zéro duplication (anti-inertie AD-4).** COMPOSER `ZSessionItem` (identité), `ZReviewMode.whiteExam` (mode), `ZStudySessionResult` (scoring), `ZSrsConfig.passThreshold` (seuil correct/incorrect). **NE PAS** re-déclarer d'item/mode/résultat/seuil ; **NE PAS** réutiliser `reduceGrade`/`ZLinearSessionState`/`ZStudySessionEngine` (sémantiques SRS/linéaire distinctes).
- **D11 — Barrel : 1 export additif ; graphe & runner INCHANGÉS.** `packages/zcrud_session/lib/zcrud_session.dart` reçoit `export 'src/domain/z_white_exam_session_engine.dart';` (+ le reducer `scoreWhiteExam` exposé pour testabilité golden). Aucune nouvelle dépendance, aucun nouveau package ⇒ `graph_proof.py` inchangé, CORE OUT=0/acyclique préservés, `melos list = 20`. Runner = `flutter test` (R14). Aucun `.g.dart`.

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant (R12)** : il nomme le vecteur/test qui ROUGIT si la garde saute. Les TROIS CENTRAUX : **AC2 (machine à états — transitions illégales refusées)**, **AC3 (scoring golden déterministe)** et **AC4 (zéro-SM2 PAR CONSTRUCTION)**.

1. **AC1 — `ZWhiteExamSessionEngine` est une CLASSE PURE, zéro gestionnaire d'état (AD-2/AD-23/NFR-S5).** Le runtime `extends ChangeNotifier` (import `package:flutter/foundation.dart` **seul**), expose un `ZWhiteExamState` immuable, mute via reducers purs + `notifyListeners()` granulaire. **Aucun** import `flutter_riverpod`/`get`/`provider`/`flutter/material`/`flutter/widgets` dans tout `packages/zcrud_session/lib/**`. *(Discriminant : verrouillé par le scan d'imports existant `z_purity_test.dart` (ES-4.2, balaie tout `lib/**`) qui ROUGIT si un import banni apparaît dans le fichier neuf ; INJ-3.)*

2. **AC2 — Machine à états `setup→running→submitted` : transitions déterministes, transitions ILLÉGALES REFUSÉES — CŒUR (D2/D3, R6, R12).** `z_white_exam_session_test.dart` fige :
   - le **chemin nominal** `setup → start() → running → answer()×N → submit() → submitted` (phase exacte après chaque appel) ;
   - chaque transition **illégale LÈVE `StateError`** (jamais un no-op muet) : `answer()` avant `start()` (phase `setup`) ; `submit()` avant `start()` (phase `setup`) ; `start()` en `running` ; `start()` en `submitted` (interdit le retour arrière `submitted→running`) ; `answer()` après `submit()` (phase `submitted`) ; **double** `submit()`. Chaque cas : `expect(() => …, throwsStateError)`. *(Discriminant : INJ-2 — remplacer une garde de phase par un `return` silencieux (no-op) fait DISPARAÎTRE le throw ⇒ `throwsStateError` rougit ; autoriser `submitted→running` rougit le test « pas de retour arrière ».)*

3. **AC3 — Scoring déterministe calculé à la SOUMISSION, golden figé — CŒUR (D5, R12).** Sur une file de 5 cartes en `whiteExam`, réponses `qualities = [5, 3, 2, 0, 4]` (`passThreshold=3` défaut), `submit()` produit **exactement** `ZStudySessionResult(mode: ZReviewMode.whiteExam, total: 5, correct: 3, byQuality: {"5":1, "3":1, "2":1, "0":1, "4":1})` — `correct=3` (les qualités `5,3,4` ≥ 3), figé en littéral et comparé par égalité profonde ; `engine.state.result` = ce résultat, non-`null` **uniquement** en phase `submitted`. *(Discriminant : INJ-4 — un score dévié (`correct` off-by-one, mauvaise frontière `>` vs `>=`, `byQuality` erroné) fait rougir le golden par égalité de value-object.)*

4. **AC4 — ZÉRO écriture SM-2 PAR CONSTRUCTION — CŒUR (AD-23, D4).** `ZWhiteExamSessionEngine` **ne déclare AUCUN** champ de type `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`, son constructeur **n'accepte AUCUN** paramètre de review/scheduler, et son source **ne contient JAMAIS** les symboles `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`/`ZRepetitionInfo`. Prouvé par **DEUX gardes complémentaires** :
   - **(a) scan de source** `z_white_exam_no_srs_test.dart` (`@TestOn('vm')`) : lit `lib/src/domain/z_white_exam_session_engine.dart` (hors commentaires) et ROUGIT si l'un de ces symboles apparaît ⇒ l'introduction d'un champ reviewer SRS **rougit** l'AC ;
   - **(b) comportement** : un examen COMPLET (`start`→`answer`×N→`submit`) s'exécute **sans qu'aucun seam SRS n'existe pour être appelé** — aucun paramètre reviewer à injecter au constructeur (preuve de type : le test construit `ZWhiteExamSessionEngine(queue: …)` sans reviewer, ce qui compile). *(Discriminant : INJ-1 — ajouter un champ `ZSessionReviewer _review;` + son appel rougit immédiatement le scan (a) ; c'est la garde « par construction ».)*

5. **AC5 — Frontière correct/incorrect = `passThreshold` RÉUTILISÉ, pas un littéral (D5).** `correct` compte les réponses `quality >= passThreshold` (=3, lu de `ZSrsConfig`, **aucun `3` en dur**). Vecteur config-custom `ZSrsConfig(passThreshold: 4)` sur `qualities = [5, 3, 4]` : `correct = 2` attendu (`5,4` ≥ 4 ; `3` en-deçà) ; en défaut (=3), `correct = 3`. *(Discriminant : remplacer la lecture par un littéral `3` fait échouer le vecteur `passThreshold:4`.)*

6. **AC6 — Scoring COMPOSABLE via `ZExamScoringPort` PUR, défaut fourni (D6).** Le constructeur accepte un `scorer` optionnel (`ZExamScoringPort`, défaut `scoreWhiteExam`) ; un vecteur injecte un scorer alternatif pur (ex. `correct = total`) et vérifie que `submit()` produit le résultat de CE scorer. La signature de `ZExamScoringPort` **n'expose AUCUN** `ZRepetitionStore`/`ZSrsScheduler` (seam pur, jamais une voie SRS — cohérent AC4). *(Discriminant : le vecteur scorer-custom rougit si `submit()` ignore le `scorer` injecté et code le scoring en dur.)*

7. **AC7 — `ChangeNotifier` : une notification par transition effective, granularité correcte (AD-2).** Chaque `start()`/`answer()`/`submit()` qui change réellement l'état émet **exactement un** `notifyListeners`. Vecteur : listener compteur figé (ex. `start`+3×`answer`+`submit` ⇒ 5 notifications). *(Discriminant : double-notification ou notification fantôme rougit le compteur.)*

8. **AC8 — Aucun `.g.dart`, aucune nouvelle dépendance/arête, graphe & inventaire INCHANGÉS (AD-1, D9/D11).** Aucun `@ZcrudModel` ⇒ **aucun** `*.g.dart` produit dans `zcrud_session/lib/**`. `pubspec.yaml` de `zcrud_session` **inchangé** (deps ES-4.2 suffisent — **aucune** arête vers `zcrud_exam`, D9). `python3 scripts/dev/graph_proof.py` ⇒ **ACYCLIQUE OK, CORE OUT=0 OK** (identique à ES-4.3) ; `dart run melos list` ⇒ **20** (inchangé) ; `flutter test` sur `zcrud_session` **RC=0** ; `dart analyze packages/zcrud_session` **RC=0**. *(Discriminant : orchestrateur au gate de commit — `melos run analyze` + `melos run verify` REPO-WIDE verts.)*

---

## Tasks / Subtasks

- [x] **T1 — `ZWhiteExamState` + `ZWhiteExamPhase` + reducers purs (AC1, AC2, AC3, AC7 ; D1/D2/D8)**
  - [x] `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart` : enum **NEUF non persisté** `ZWhiteExamPhase { setup, running, submitted }` (aucun `@ZcrudModel`).
  - [x] Value-object immuable `ZWhiteExamState { phase, queue: List<ZSessionItem>, cursor, answers: List<int>, result: ZStudySessionResult? }` : `==`/`hashCode` **profonds** (`listEquals`), `copyWith`, getters `current`/`answered`/`remaining`/`isSubmitted`. **NE PAS** cloner `ZSessionState` (D8).
  - [x] Reducers PURS top-level : `ZWhiteExamState startExam(ZWhiteExamState)` (setup→running) ; `ZWhiteExamState recordAnswer(ZWhiteExamState, int quality)` (running : append `answers`, `cursor+1`, parcours strict) ; `scoreWhiteExam(List<int> qualities, {required int passThreshold}) → ZStudySessionResult` (D5). **Aucune** horloge, **aucune** I/O, **aucun** symbole SRS.
- [x] **T2 — `ZWhiteExamSessionEngine` (machine à états + gardes + scoring composable) (AC2, AC4, AC5, AC6, AC7 ; D3/D4/D6)**
  - [x] `class ZWhiteExamSessionEngine extends ChangeNotifier` (import `package:flutter/foundation.dart` SEUL). **AUCUN** champ `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; **AUCUN** paramètre de review/scheduler au constructeur (D4, cœur AC4).
  - [x] Constructeur `ZWhiteExamSessionEngine({required List<ZSessionItem> queue, ZSrsConfig config = const ZSrsConfig(), ZExamScoringPort scorer = scoreWhiteExam})` ; état initial en phase `setup` (curseur 0, `answers` vide, `result` null).
  - [x] API : `start()` (garde phase `setup`, sinon `throw StateError`) ; `answer(int quality)` (garde phase `running`, sinon `throw StateError`) ; `submit()` (garde phase `running`, sinon `throw StateError` — couvre double-submit ET setup) ; `_setState(next)` compare le value-object et ne notifie que si changement (AC7). Getters lecture `state`/`phase`/`current`/`answered`/`remaining`/`result` (result non-null uniquement en `submitted`). Seuil = `_config.passThreshold` (jamais `3` littéral, D5/AC5).
  - [x] `typedef ZExamScoringPort = ZStudySessionResult Function(List<int> qualities, {required int passThreshold});` — seam PUR, aucune signature SRS (D6/AC6).
  - [x] `packages/zcrud_session/lib/zcrud_session.dart` : **1 ligne additive** `export 'src/domain/z_white_exam_session_engine.dart';` (D11). Autres exports intacts.
- [x] **T3 — Tests (runner `flutter test`, R14) + pouvoir discriminant (R12)**
  - [x] `test/z_white_exam_session_test.dart` : golden AC2 (chemin nominal setup→running→submitted + **6 cas de transition illégale `throwsStateError`**) ; golden AC3 (scoring `[5,3,2,0,4]` → `total:5, correct:3, byQuality:{…}`) ; AC5 seuil config-custom `passThreshold:4` ; AC6 scorer-custom injecté ; AC7 listener compteur.
  - [x] `test/z_white_exam_no_srs_test.dart` (AC4a, CŒUR) : `@TestOn('vm')` ; lit `lib/src/domain/z_white_exam_session_engine.dart` (hors commentaires) et **ROUGIT** si l'un de `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`/`.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo` apparaît. `z_purity_test.dart` (ES-4.2) balaie déjà `lib/**` ⇒ couvre AC1 sur le fichier neuf.
- [x] **T4 — Vérif verte CIBLÉE + injections R3 (AC8)**
  - [x] `flutter test` (zcrud_session) → RC=0 (54 tests). `dart analyze packages/zcrud_session` → RC=0.
  - [x] `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK (inchangé). `dart run melos list` → 20 (inchangé).
  - [x] Aucun `.g.dart` dans `zcrud_session/lib` (aucun `@ZcrudModel`, AC8). `pubspec.yaml` inchangé (aucune arête `zcrud_exam`, D9).
  - [x] INJ-1..INJ-4 déroulées, chacune ROUGE comme prévu, restaurées par édition ciblée (R13).
  - [ ] **`melos run analyze` + `melos run verify` REPO-WIDE : délégués à l'ORCHESTRATEUR au gate de commit d'epic** (workstream B actif).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail`/`| grep`. **Restauration (R13) :** édition ciblée de retour, JAMAIS `git checkout`. **Runner (R14) :** `zcrud_session` = paquet Flutter ⇒ `flutter test`.

- **INJ-1 — Zéro-SM2 PAR CONSTRUCTION (AC4a, CŒUR AD-23).** Ajout ciblé d'un champ `final ZSessionReviewer _review;` (+ import + un appel) dans `z_white_exam_session_engine.dart`. `cd packages/zcrud_session && flutter test test/z_white_exam_no_srs_test.dart; RC=$?` → **RC≠0** (le scan détecte `ZSessionReviewer`/`reviewCard`). Retirer. *(Prouve que l'introduction d'un seam SRS rougit l'AC — la garde « par construction ».)*
- **INJ-2 — Machine à états, transition illégale (AC2, CŒUR).** Édition ciblée : dans la garde de `answer()` (ou `submit()`), remplacer `throw StateError(...)` par un `return;` silencieux (no-op muet). `flutter test test/z_white_exam_session_test.dart; RC=$?` → **RC≠0** (`throwsStateError` rougit — R6 : une transition illégale ne DOIT PAS se taire). Restaurer. *(Prouve que la machine à états MORD sur les transitions illégales.)*
- **INJ-3 — Pureté / zéro gestionnaire d'état (AC1).** Ajout ciblé d'un `import 'package:provider/provider.dart';` en tête de `z_white_exam_session_engine.dart`. `flutter test test/z_purity_test.dart; RC=$?` → **RC≠0** (scan d'imports bannis rouge). Retirer. *(Prouve que la garde de pureté MORD.)*
- **INJ-4 — Scoring déterministe (AC3).** Édition ciblée : dans `scoreWhiteExam`, changer la frontière `quality >= passThreshold` en `quality > passThreshold` (ou incrémenter `correct` d'un cran). `flutter test test/z_white_exam_session_test.dart; RC=$?` → **RC≠0** (golden `correct:3, byQuality:{…}` rouge). Restaurer. *(Prouve que le contrat MORD sur le scoring.)*

---

## Vérif verte à rejouer (commandes exactes, RC capturé HORS pipe — R15)

```bash
# 0. (aucune édition pubspec/workspace — deps ES-4.2 suffisent ; bootstrap seulement si besoin)
dart pub get; echo "pub get RC=$?"

# 1. Tests du package (RUNNER = flutter, R14 : ChangeNotifier ∈ flutter/foundation)
cd packages/zcrud_session && flutter test; echo "session test RC=$?"; cd ../..

# 2. Analyse ciblée
dart analyze packages/zcrud_session; echo "analyze RC=$?"

# 3. Graphe (INCHANGÉ) & inventaire packages
python3 scripts/dev/graph_proof.py; echo "graph RC=$?"     # attendu : ACYCLIQUE OK, CORE OUT=0 OK
dart run melos list; echo "melos list RC=$?"                # attendu : 20 packages (INCHANGÉ)

# 4. Codegen ciblé — NE doit RIEN produire dans zcrud_session/lib (AC8)
dart run melos run generate; echo "generate RC=$?"

# 5. (ORCHESTRATEUR, gate de commit d'epic — PAS pendant le dev, workstream B actif)
dart run melos run analyze; echo "melos analyze RC=$?"
dart run melos run verify;  echo "melos verify  RC=$?"
```

> ⚠️ Ne JAMAIS mesurer un RC via `flutter test … | tail`/`| grep` (R15). Toujours `cmd; RC=$?`.
> ⚠️ **Runner (R14)** : `zcrud_session` = paquet Flutter ⇒ `flutter test` (`dart test` échouerait — import flutter non résolu).

---

## Dev Notes

### Périmètre & invariants NON-NÉGOCIABLES
- **Fichiers touchés (EXCLUSIVEMENT)** : **NEUFS** `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart`, `packages/zcrud_session/test/z_white_exam_session_test.dart`, `packages/zcrud_session/test/z_white_exam_no_srs_test.dart` ; **1 ligne additive** au barrel `packages/zcrud_session/lib/zcrud_session.dart` (export). **NE touche PAS** `z_study_session_engine.dart`/`z_linear_session_state.dart`/`z_session_state.dart`/`z_session_item.dart`/`z_session_reviewer.dart` (ES-4.2/4.3 — réutilisés en LECTURE), `pubspec.yaml` (deps suffisantes), `zcrud_core`, `zcrud_flashcard/lib`, `zcrud_exam` (D9 : aucune arête), `zcrud_study` (workstream B), `melos.yaml`, NI `sprint-status.yaml` (orchestrateur).
- **AD-23 « ZÉRO écriture SM-2 PAR CONSTRUCTION »** : le runtime examen n'a **AUCUN** seam/scheduler/store SRS ⇒ aucun point d'écriture SRS n'existe (garantie de TYPE). ⚠️ Distinction vs ES-4.2 : le cycle SRS écrit via UNE voie unique (`ZSessionReviewer`) ; l'examen blanc n'a AUCUNE voie (comme le linéaire ES-4.3).
- **AD-2 (Flutter-native, objectif produit n°1)** : `ChangeNotifier` + state immuable + reducers purs ; jamais `setState`, jamais Riverpod/GetX/provider (bindings = ES-9/ES-10).
- **AD-1** : aucune nouvelle arête (deps ES-4.2 réutilisées, `zcrud_exam` NON requis) ⇒ CORE OUT=0/acyclique/graphe INCHANGÉS.
- **AD-4 (extensibilité/composition)** : COMPOSER `ZSessionItem`/`ZReviewMode.whiteExam`/`ZStudySessionResult`/`ZSrsConfig.passThreshold` — jamais dupliquer.
- **R6 (jamais de dégradation silencieuse)** : une transition illégale de la machine à états **LÈVE `StateError`** — elle ne se tait JAMAIS (no-op muet interdit).

### Anti-inertie (réutilisation)
- **COMPOSER** `ZSessionItem` (identité), `ZReviewMode.whiteExam` (mode), `ZStudySessionResult` (scoring `{mode, total, correct, byQuality}`, ES-2.7), `ZSrsConfig.passThreshold` (seuil). **NE PAS** réutiliser `reduceGrade`/`ZLinearSessionState`/`ZStudySessionEngine` (sémantiques SRS/linéaire distinctes), **NE PAS** cloner `ZSessionState` (queue/lapse inadaptée à setup/running/submitted).
- **NE PAS** dépendre de `zcrud_exam` (D9 : entité de planification, sans rapport avec le runtime).
- Aucun nouveau package, aucune nouvelle dépendance, aucun `.g.dart`, `graph_proof.py` inchangé.

### Runner par nature du package (R14) — MESURÉ
`ChangeNotifier` ∈ `package:flutter/foundation.dart` ⇒ `zcrud_session` = paquet Flutter ⇒ **`flutter test`**. Le `gate:web` (pur-Dart only) l'IGNORE. Le test de scan de source (`z_white_exam_no_srs_test.dart`) lit le FS ⇒ `@TestOn('vm')` (comme `z_purity_test.dart` d'ES-4.2 et `z_linear_no_srs_test.dart` d'ES-4.3).

### Injections R3 prévues (orchestrateur)
Voir section dédiée « Injections R3 » : INJ-1 (zéro-SM2 scan), INJ-2 (transition illégale → machine à états), INJ-3 (pureté imports), INJ-4 (scoring déterministe). Chacune ROUGE puis restaurée par édition ciblée (R13), RC hors pipe (R15).

### Project Structure Notes
- Structure miroir ES-4.2/4.3 : impl en `lib/src/domain/`, exposée par le barrel. Runtime pur (pas de `data`/`presentation` ; les widgets qualité/progression = ES-4.5).
- Le binding (ES-9/ES-10) instancie `ZWhiteExamSessionEngine(queue: …)` — **aucun** reviewer à fournir (contraste voulu avec `ZStudySessionEngine`) ; le minuteur d'examen (le « minuté ») est piloté côté binding et appelle `submit()` à l'échéance (D6-gotcha).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-4.4 — L675-688 : `ZWhiteExamSessionEngine` setup→running→submitted (classe pure), scoring composable (seam `ZExamScoringPort` si besoin), aucune écriture SM-2 (AD-23)]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#FR-S20 — L53, L124 : Examen blanc (`ZWhiteExamSessionEngine`, setup/running/submitted)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-23 — L239-242 : runtimes purs, `ZWhiteExamSessionEngine` (setup→running→submitted) classe pure, ne référence PAS `ZRepetitionStore`, « zéro écriture SM-2 » garanti PAR CONSTRUCTION et testé]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-2 / AD-1 — Flutter-native ; CORE OUT=0, acyclique]
- [Source: _bmad-output/implementation-artifacts/stories/es-4-3-runtimes-cramming-liste.md — socle zcrud_session ; patron « zéro-voie » (scan de source no-SRS), miroir de la garde par construction]
- [Source: _bmad-output/implementation-artifacts/stories/es-4-2-runtime-session-srs-cycle.md — socle zcrud_session livré ; contraste voie-unique (cycle) vs zéro-voie (examen)]
- [Source: packages/zcrud_session/lib/src/domain/z_session_item.dart#L16-L50 — ZSessionItem neutre (réutilisé)]
- [Source: packages/zcrud_session/lib/src/domain/z_session_state.dart#L23-L135 — ZSessionState (NON réutilisé : sémantique queue/lapse ; ZWhiteExamState dédié, D8)]
- [Source: packages/zcrud_session/lib/src/domain/z_study_session_engine.dart#L115+ — ZStudySessionEngine (NON modifié, détient un seam = contraste)]
- [Source: packages/zcrud_session/lib/zcrud_session.dart#L21-L25 — barrel (1 export additif)]
- [Source: packages/zcrud_session/pubspec.yaml#L48-L53 — deps ES-4.2 (zcrud_core/zcrud_flashcard/zcrud_study_kernel) suffisantes ; aucune arête zcrud_exam, D9]
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart#L47-L63 — ZReviewMode.whiteExam « conditions d'examen, sans SRS » (réutilisé)]
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart#L53-L92 — ZStudySessionResult {mode, total, correct, byQuality} (sortie de scoring réutilisée, ES-2.7)]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart#L26-L58 — passThreshold=3 (frontière correct/incorrect réutilisée, D5)]
- [Source: packages/zcrud_exam/lib/src/domain/z_exam.dart#L1-L80 — ZExam = entité de PLANIFICATION (dated + reminders), SANS rapport avec le runtime d'examen blanc (D9 : aucune dépendance)]
- [Source: ~/DEV/lex_douane/packages/lex_core/lib/domain/enums/study_mode.dart#L18-L22,L54-64 — whiteExam « minuté », `StudyModeWritesSm2.writesSm2=false` : examen blanc n'écrit JAMAIS SM-2]
- [Source: ~/DEV/lex_douane/packages/lex_core/lib/domain/entities/education/study_session.dart#L46-L72 — StudySessionResult {mode, total, correct, byQuality} : forme canonique du scoring portée en ZStudySessionResult]
- [Source: scripts/dev/graph_proof.py — acyclicité + CORE OUT=0 (INCHANGÉ) ; scripts/ci/gate_web_determinism.dart — web gate pur-Dart only]
- [Source: CLAUDE.md — AD-2 (SM-1), AD-23 (zéro écriture SM-2 par construction), AD-1 (CORE OUT=0), R6/R12/R13/R14/R15 gotchas]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high)

### Debug Log References

Vérifs vertes CIBLÉES (RC capturé HORS pipe, R15) :

| Étape | Commande | Résultat | RC |
|---|---|---|---|
| Analyse | `dart analyze packages/zcrud_session` | No issues found | 0 |
| Tests | `flutter test` (zcrud_session) | All tests passed — **54 tests** (dont 15 neufs examen blanc + 1 no-SRS) | 0 |
| No-SRS scan | `flutter test test/z_white_exam_no_srs_test.dart` | AC4a vert (aucun symbole SRS) | 0 |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK, CORE OUT=0 OK** (inchangé) | 0 |
| Inventaire | `dart run melos list` | **20 packages** (inchangé) | 0 |

`.g.dart` : AUCUN produit dans `zcrud_session/lib` (aucun `@ZcrudModel`, AC8). `pubspec.yaml` INCHANGÉ (aucune arête `zcrud_exam`, D9).

### Injections R3 (pouvoir discriminant R12 — chacune ROUGE puis restaurée par édition ciblée R13, RC hors pipe R15)

| Inj | Garde prouvée | Test rejoué | RC | Message EXACT capturé |
|---|---|---|---|---|
| **INJ-1** | Zéro-SM2 PAR CONSTRUCTION (AC4a, AD-23) — champ `final ZSessionReviewer _review` ajouté | `flutter test test/z_white_exam_no_srs_test.dart` | **1** | `symbole(s) SRS détecté(s)… (AD-23) est violée : lib/src/domain/z_white_exam_session_engine.dart:272 → ZSessionReviewer dans « final ZSessionReviewer _review = throw UnimplementedError(); »` |
| **INJ-2** | Machine à états — garde de `answer()` remplacée par `return;` muet | `flutter test test/z_white_exam_session_test.dart` | **1** | `Expected: throws <Instance of 'StateError'>` / `Actual: <Closure: () => void>` (2 tests rouges : answer avant start, answer après submit) |
| **INJ-3** | Pureté / zéro gestionnaire d'état (AC1) — `import 'package:provider/provider.dart';` ajouté | `flutter test test/z_purity_test.dart` | **1** | `imports bannis (gestionnaire d'état / widget) détectés : lib/src/domain/z_white_exam_session_engine.dart:53 → import 'package:provider/provider.dart';` |
| **INJ-4** | Scoring déterministe (AC3) — frontière `quality >= passThreshold` → `> passThreshold` | `flutter test test/z_white_exam_session_test.dart` | **1** | `Expected: ZStudySessionResult:<…correct: 3…>` / `Actual: ZStudySessionResult:<…correct: 2…>` |

Après restauration des 4 injections (édition ciblée, jamais `git checkout`) : `dart analyze` RC=0, `flutter test` RC=0 (54 tests verts).

### Completion Notes List

- **Machine à états `setup → running → submitted` (AC2, CŒUR)** : `ZWhiteExamPhase{setup,running,submitted}` (enum neuf non persisté) + `ZWhiteExamSessionEngine extends ChangeNotifier`. Transitions autorisées uniquement : `start()` (setup→running), `answer(quality)` (reste running, parcours strictement linéaire cursor 0→N), `submit()` (running→submitted). Toute transition ILLÉGALE **lève `StateError`** — jamais un no-op muet (R6) : `answer`/`submit` hors running, `start` hors setup (couvre double-submit et le retour arrière interdit `submitted→running`). 7 cas figés par `throwsStateError`.
- **Scoring différé composant `ZStudySessionResult` (AC3/AC5/AC6)** : reducer PUR top-level `scoreWhiteExam(qualities, {passThreshold})` calculé à `submit()`, COMPOSANT `ZStudySessionResult(mode: whiteExam, total, correct, byQuality)` (ES-2.7, réutilisé — aucune duplication). `correct = quality >= passThreshold`, seuil LU de `ZSrsConfig.passThreshold` (jamais `3` littéral). Golden figé `[5,3,2,0,4]→total:5, correct:3, byQuality:{5:1,3:1,2:1,0:1,4:1}`. Seam PUR `ZExamScoringPort` (défaut `scoreWhiteExam`) — signature sans store/scheduler SRS, ne peut PAS rouvrir la voie SM-2.
- **Zéro-SM2 PAR CONSTRUCTION (AC4, CŒUR AD-23)** : le moteur ne déclare AUCUN champ `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; le constructeur `ZWhiteExamSessionEngine(queue:…)` n'accepte AUCUN reviewer/scheduler ; la source n'invoque aucun `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo`. Prouvé par le scan `z_white_exam_no_srs_test.dart` (`@TestOn('vm')`, miroir ES-4.3) + preuve de type (construction sans reviewer compile).
- **AD-2 / granularité** : état immuable `ZWhiteExamState` (value-object dédié, `listEquals` profond, NE clone PAS `ZSessionState`, D8), `_setState` notifie uniquement si l'état change → AC7 : start+3×answer+submit = 5 notifications exactes.
- **AD-1 / graphe INCHANGÉ** : aucune nouvelle arête (`zcrud_exam` NON requis, D9), CORE OUT=0, `melos list`=20, aucun `.g.dart`. Barrel : 1 export additif.

### File List

- `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart` (NEUF) — `ZWhiteExamPhase`, `ZWhiteExamState`, `ZExamScoringPort`, reducers purs `startExam`/`recordAnswer`/`scoreWhiteExam`, `ZWhiteExamSessionEngine`.
- `packages/zcrud_session/lib/zcrud_session.dart` (MODIFIÉ — 1 ligne additive) — `export 'src/domain/z_white_exam_session_engine.dart';`.
- `packages/zcrud_session/test/z_white_exam_session_test.dart` (NEUF) — goldens AC2/AC3/AC5/AC6/AC7.
- `packages/zcrud_session/test/z_white_exam_no_srs_test.dart` (NEUF, `@TestOn('vm')`) — scan de source zéro-SM2 (AC4a).
