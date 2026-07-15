# Story ES-4.2 : Runtime de session SRS en cycle (`ZStudySessionEngine`, classe pure)

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. ES-4.2 dépend d'ES-4.1 (TÊTE, source SM-2 unique verrouillée par z_sm2_contract_test.dart) → SÉQUENTIELLE vis-à-vis d'ES-4.1. Premier écrivain du NOUVEAU package zcrud_session ; SÉQUENTIELLE vs ES-4.3/4.4 (même package, fichiers domaine distincts). -->
<!-- ⚠️ PARALLÉLISATION — workstream A. Un workstream B (epic ES-5) écrit packages/zcrud_study/** en parallèle. ISOLATION STRICTE : cette story n'écrit QUE le NOUVEAU packages/zcrud_session/** + 1 ligne additive au bloc workspace: du root pubspec.yaml. NE touche PAS zcrud_core, zcrud_flashcard/lib (compose reviewCard SANS le modifier), zcrud_study, NI sprint-status.yaml (orchestrateur). Vérifs CIBLÉES par package (PAS de melos repo-wide au milieu du dev — délégué à l'orchestrateur au gate de commit). -->
<!-- Gotchas rétro en vigueur : R12 (pouvoir discriminant EXIGÉ — offset +2/+4 + zéro-apply-parasite CENTRAUX), R14 (runner par NATURE du package — zcrud_session = Flutter car ChangeNotifier ∈ flutter/foundation → flutter test), R15 (RC capturé HORS pipe), R13 (restauration par édition ciblée, jamais git checkout), R3 (injections orchestrateur), R6 (jamais de dégradation silencieuse). -->

## Story

As a **utilisateur qui révise ses cartes en répétition espacée**,
I want **réviser en CYCLE via `ZStudySessionEngine` — une classe PURE (`ChangeNotifier`/reducer) qui porte la file de session et RÉINSÈRE une carte ratée à un offset déterministe (+2/+4 selon la sévérité du lapse), pendant que la SEULE écriture SRS transite par `reviewCard() → ZSrsScheduler.apply` (AD-9) — sans AUCUN couplage à Riverpod/GetX/provider**,
so that **la session planifie mes prochaines répétitions courtes dans un ordre reproductible, le runtime reste réutilisable sous n'importe quel gestionnaire d'état (branché plus tard par un binding mince), et il est IMPOSSIBLE par construction qu'un chemin de la session fasse progresser l'état SRS hors de la voie unique.**

---

## Contexte & état mesuré sur disque

> ⚠️ **Package NEUF `zcrud_session` — premier code.** Cette story CRÉE le package (`pubspec.yaml` + barrel + `lib/src/domain/z_study_session_engine.dart`) et l'ajoute au `workspace:` du root `pubspec.yaml` (1 ligne additive). Le runtime **COMPOSE** l'ordonnanceur verrouillé en ES-4.1 (`reviewCard`) ; il **ne duplique JAMAIS** SM-2, ne référence **jamais** un `ZSrsScheduler`/`ZRepetitionStore` en champ, et ne calcule **jamais** un intervalle.

### 1. La voie d'écriture SRS UNIQUE à composer (`ZFlashcardRepository.reviewCard`, lu INTÉGRALEMENT — `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart` l.262-289)

```dart
// UNIQUE voie d'avancement SRS (AD-9). Charge l'état courant (ZRepetitionStore) ou
// scheduler.initial() si absent, applique EXACTEMENT scheduler.apply(current, quality, now),
// persiste, renvoie le nouvel état. Ne touche jamais `cards`.
Future<ZResult<ZRepetitionInfo>> reviewCard({
  required String flashcardId,
  required String folderId,
  required int quality,
  DateTime? now,
}) async { … final next = _scheduler.apply(current, quality, now: now); return _reps.put(next); }
```
- `ZResult<T> = Either<ZFailure, T>` (dartz, AD-5) ; le `reviewCard` est **async** et enveloppé `Either` : `getByCard`/`put` sur le port `ZRepetitionStore` (l.42-66 : `getByCard`/`put`/`getAll`/`sync`).
- **`apply` est appelé UNIQUEMENT ici et dans aucun autre point du repo** (verrouillé ES-4.1, AD-9). `initial()` = seul autre write (état neuf).
- `ZReviewMode` (kernel, `z_review_mode.dart`) : `spaced` (défaut config, AC1 d'E9-3) + modes non-SRS (cramming/liste/exam → ES-4.3/4.4, HORS scope).

### 2. `ZSm2Scheduler` verrouillé ES-4.1 — NE PAS RÉIMPLÉMENTER (`z_sm2_scheduler.dart`, contrat gelé `test/z_sm2_contract_test.dart`, 22 vecteurs)
- Lapse = `quality < config.passThreshold (=3)` → `repetitions=0, interval=1` (l.74-78). Réussite = `q ≥ 3`. **C'est le SEUIL de lapse que le cycle de session réutilise** (un lapse SRS ⇒ réinsertion courte dans la file). Aucune constante SM-2 n'est recopiée dans `zcrud_session` : le seuil de re-queue est propre à la file de session (D3).

### 3. `ZStudySessionConfig` (kernel, AD-24, lu — `z_study_session_config.dart` l.53-118)
- Config de valeur : `mode` (défaut `ZReviewMode.spaced`), `folderId`, `tagIds`, `types` (clés neutres), `count`. La **sélection** des cartes est portée par `ZStudySessionSelector` (kernel, hors scope ici) ; **le moteur reçoit une file DÉJÀ sélectionnée** (liste ordonnée de candidats) — il ne re-sélectionne pas.

### 4. Runner & gates du package NEUF (MESURÉ)
- **`ChangeNotifier` ∈ `package:flutter/foundation.dart`** (aucun `ChangeNotifier` pur-Dart n'existe) ⇒ `zcrud_session/pubspec.yaml` DOIT déclarer `flutter: sdk: flutter` + `flutter_test` ⇒ **package FLUTTER ⇒ `flutter test`** (R14 ; même nature que `zcrud_core` depuis E2-7). L'import est `package:flutter/foundation.dart` (foundation SEULE, **aucun** widget).
- **`gate:web`** (`scripts/ci/gate_web_determinism.dart` l.24-42) cible **UNIQUEMENT les packages PUR-DART** (pubspec **sans** `flutter:`). `zcrud_session` étant Flutter ⇒ **HORS cible du web gate** (comme `zcrud_core`/`zcrud_study`). Aucune action web.
- **`gate:graph`** (`scripts/dev/graph_proof.py` l.74/93) : acyclicité (Kahn) + `out-degree(zcrud_core) == 0`. `zcrud_session` n'ajoute que des arêtes **SORTANTES** (`→ zcrud_core`, `→ zcrud_flashcard`, `→ zcrud_study_kernel`) ; aucun de ces packages ne dépend de `zcrud_session` ⇒ **ACYCLIQUE préservé, CORE OUT=0 préservé**.
- **`gate:melos`** (`scripts/ci/gate_melos_divergence.dart` l.29-36) compare **UNIQUEMENT les blocs `scripts:`** de `pubspec.yaml`↔`melos.yaml` — **PAS** la liste de packages. `melos.yaml` déclare `packages: - packages/**` en **GLOB** (l.7-8) : le nouveau package est capté **automatiquement**. **⇒ AUCUNE édition de `melos.yaml`.** Le SEUL point de déclaration = le bloc `workspace:` du root `pubspec.yaml` (l.20-59, source de vérité de la résolution), **1 ligne additive**.

---

## Reconnaissance externe MESURÉE (documentaire — origine des offsets +2/+4)

> Chiffres et emplacements **MESURÉS sur disque**. Le critère de résolution **exécutable in-repo** reste le golden de file de session ci-dessous (AC3).

### IFFD — le moteur de cycle réel (`~/DEV/iffd/lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart`, 199 l., `extends ChangeNotifier` l.7 — lu INTÉGRALEMENT l.30-168)
- **Primitive de réinsertion** `putFlashcardAfterXNext({after, previousIndex})` (l.32-53) : `removeAt(previousIndex)` **PUIS** `insert(min(previousIndex + after, length), card)`, `notifyListeners()`. Défensif : `previousIndex` hors bornes → no-op (l.37-38) ; `try/catch` autour du remove/insert (l.41-50).
- **Offsets sur lapse** (branche `quality < 3`, l.112-131 ; **identique** en cramming l.95-105) :
  ```dart
  int after = 3;              // défaut (q==0)
  if (quality == 1) after = 3;   // « Fail »  → after 3
  if (quality == 2) after = 5;   // « Hard »  → after 5
  await onSave(updatedRepetition);   // la LAPSE est persistée (voie unique)
  putFlashcardAfterXNext(flashcard: flashcard, after: after, previousIndex: currentFlashcardIndex);
  ```
  Commentaire l.118-119 (l'INTENTION utilisateur) : **« Fail (1) -> 2 cards later, Hard (2) -> 4 cards later »**.
- **Réussite** (`q ≥ 3`, l.139-167) : `onSave(updatedRepetition)` (voie unique) ; carte **retirée** de la file si `q ≥ 5` en learning-cycle **ou** mode test (mastery/exam removal), avec réajustement d'index (l.147-166).

### lex — le LABEL canonique (`~/DEV/lex_douane/packages/lex_core/lib/domain/usecases/education/sm2.dart` l.197-229, lu)
- `previewLabel(reinsertAfterCards:)` → **« dans 2 cartes » / « dans 4 cartes »** ; dartdoc l.208 : *« réinsertion "dans 2/4 cartes", retrait à quality ≥ 5 »*. La sémantique **utilisateur** est bien **+2 / +4** cartes.

### ⚠️ GOTCHA MESURÉ — la constante brute `after` (3/5) ≠ l'offset utilisateur (+2/+4)
Le `after` d'IFFD vaut **3** (q≤1) / **5** (q==2), mais la carte courante est **retirée d'abord** (`removeAt`, l.42) et la carte suivante remonte à sa place : depuis l'œil de l'utilisateur, la carte ratée **réapparaît comme la 2ᵉ (q≤1) / 4ᵉ (q==2) carte à venir** — ce que confirment **et** le commentaire IFFD (« 2/4 cards later ») **et** le label lex (« dans 2/4 cartes »). **AD-23 est autoritaire : offset utilisateur `+2/+4`.** La correspondance « offset utilisateur → index concret dans la liste » dépend de la convention remove-then-insert ⇒ **D2 la fige sans ambiguïté** et **AC3 la verrouille par un golden d'ordre de file** (le dev ne recopie PAS la constante brute 3/5 à l'aveugle : il modélise l'offset utilisateur +2/+4 et prouve l'ordre résultant).

---

## Décisions de conception (tranchées ici)

- **D1 — `ZStudySessionEngine extends ChangeNotifier` (foundation seule), état = value-object immuable + reducer PUR.** Le moteur détient un `ZSessionState` **immuable** (`queue` = `List<ZSessionItem>`, `cursor`, compteurs `reviewed`/`lapses`/`remaining`, `isComplete`) et l'expose en lecture. Les transitions (`grade`, `skip`…) délèguent à un **reducer PUR** `ZSessionQueue`/fonction `_reduce(state, action) → state` (aucun effet de bord, aucune horloge capturée, aucune I/O) puis `notifyListeners()`. La **réinsertion +2/+4 vit dans le reducer pur** ⇒ testable golden **sans Flutter côté logique** (les tests tournent tout de même sous `flutter test`, R14). **AUCUN** `setState`, **AUCUN** import `flutter_riverpod`/`get`/`provider` (AD-2/AD-23/NFR-S5).
- **D2 — Offset de réinsertion FIGÉ (convention sans ambiguïté).** Sur lapse (`quality < 3`), la carte ratée est retirée de sa position courante puis **réinsérée parmi les cartes À VENIR** (celles après le curseur) à l'index `offset-1` (0-based), avec `offset = 2` si `quality ∈ {0,1}`, `offset = 4` si `quality == 2` — **clampé à la fin de file** si moins de `offset` cartes restent à venir. Autrement dit : la carte ratée **réapparaît comme la Nᵉ carte à venir** (N=2 pour q∈{0,1}, N=4 pour q=2). Cette convention reproduit l'effet utilisateur d'IFFD (`after=3/5` après remove-then-insert) et le label lex (« dans 2/4 cartes »). **L'ordre exact de la file après chaque grade est GELÉ par le golden AC3** (le dev recalcule et fige les positions ; toute dérive de l'offset les rougit).
- **D3 — Le SEUIL de lapse est réutilisé, PAS recopié.** Le cycle re-queue ssi `quality < ZSrsConfig.passThreshold` (=3, le MÊME seuil que `ZSm2Scheduler` — lu depuis la config injectée / exposé, jamais un `3` littéral en dur dans `zcrud_session`). La table `{0,1}→+2, {2}→+4` est propre à la **file de session** (pas du SM-2) et vit dans `zcrud_session` (constantes nommées documentées).
- **D4 — Écriture SRS = SEAM INJECTÉ, jamais un scheduler/store en champ (AD-23 « zéro par construction »).** Le moteur reçoit à la construction un **port/callback de review** `ZSessionReviewer` (typedef ou interface mince) de signature = `reviewCard` : `Future<ZResult<ZRepetitionInfo>> Function({required String flashcardId, required String folderId, required int quality, DateTime? now})`. Le moteur **NE possède AUCUN champ** `ZSrsScheduler` ni `ZRepetitionStore` et **n'appelle JAMAIS `apply`/`initial`/`put`** : à chaque grade il invoque **exactement une fois** le seam (qui, en prod, EST `ZFlashcardRepository.reviewCard`). ⇒ *par construction*, il est impossible qu'un chemin de la session fasse progresser l'état SRS hors de la voie unique. **AC2 le prouve par un espion** (le seam est appelé exactement 1×/grade avec la bonne carte ; aucune seconde voie).
- **D5 — Le grade est ATOMIQUE et ordonné : (1) invoquer le seam de review [écrit la lapse/réussite], (2) muter la file via le reducer pur, (3) `notifyListeners`.** Sur lapse : review PUIS réinsertion +2/+4 (comme IFFD l.125-131). Sur réussite (`q ≥ 3`) : review PUIS la carte quitte la file courante (consommée ; sa prochaine vraie échéance est planifiée par `apply` via le seam). L'échec du seam (`Left(ZFailure)`) est **remonté** (état d'erreur exposé), **jamais** avalé (AD-5/R6) ; la file n'est **pas** mutée si le review échoue (cohérence : pas de réinsertion « fantôme »).
- **D6 — Déterminisme total (aucune horloge capturée).** Le moteur ne lit **jamais** `DateTime.now()` ; le `now` éventuel est **passé au seam** par l'appelant/test (le seam le relaie à `reviewCard`). Le reducer de file est une **pure fonction de `(state, quality)`** ⇒ golden reproductible bit-à-bit.
- **D7 — Dépendances du package (arêtes SORTANTES seules, AD-1).** `dependencies: zcrud_core` (`ZResult`/`Either`/`Unit`, `ZFailure`), `zcrud_flashcard` (type `reviewCard`/`ZRepetitionInfo` pour lier le seam en prod ; `ZReviewMode`/`ZStudySessionConfig` réexportés), `zcrud_study_kernel` (config/mode, explicite). **Runtime edges → jamais l'inverse** ⇒ ACYCLIQUE, CORE OUT=0. `flutter` en dep (ChangeNotifier). **Anti-inertie** : le moteur reste **générique** sur l'identité de carte (`ZSessionItem` = `{flashcardId, folderId, typeKey?}` neutre) — il ne tire aucun widget flashcard.
- **D8 — Barrel `lib/zcrud_session.dart`** exporte `ZStudySessionEngine`, `ZSessionState`, `ZSessionItem`, `ZSessionReviewer` (le typedef/port). Impl sous `lib/src/domain/`. Réexport éventuel de `ZReviewMode` depuis le kernel (ergonomie), jamais l'inverse.

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant (R12)** : il nomme le vecteur/test qui ROUGIT si la garde saute.

1. **AC1 — `ZStudySessionEngine` est une CLASSE PURE, zéro gestionnaire d'état (AD-2/AD-23/NFR-S5).** Le moteur `extends ChangeNotifier` (import `package:flutter/foundation.dart` **seul**), expose un `ZSessionState` immuable, mute via un reducer pur + `notifyListeners()`. **Aucun** import `package:flutter_riverpod`/`package:get`/`package:provider` ni `package:flutter/material.dart`/`widgets.dart` dans tout `packages/zcrud_session/lib/**`. *(Discriminant : AC1 est verrouillé par un test de scan d'imports — `z_purity_test.dart` — qui lit les sources et ROUGIT si un import banni apparaît ; INJ-5.)*

2. **AC2 — Écriture SRS UNIQUEMENT via le seam `reviewCard`, zéro `apply` parasite (AD-9/AD-23, D4).** Le moteur n'a **aucun** champ `ZSrsScheduler`/`ZRepetitionStore` et n'appelle jamais `apply`/`initial`/`put`. À chaque `grade(quality)`, le seam injecté est invoqué **exactement une fois** avec `(flashcardId, folderId, quality)` de la carte courante. Un **espion** (`ZSessionReviewer` de test comptant les appels) figé : `N` grades ⇒ **exactement `N`** invocations du seam, chacune avec la carte attendue ; **0** autre voie d'avancement. *(Discriminant : INJ-1 — si un chemin de grade « oubliait » d'appeler le seam, ou l'appelait 2×, le compteur de l'espion rougit ; si le moteur exposait un `ZSrsScheduler`, le test de surface le refuse.)*

3. **AC3 — Réinsertion sur lapse à offset FIGÉ +2/+4, ORDRE DE FILE GELÉ (D2, cœur R12).** `z_session_engine_test.dart` fige, sur une file initiale nommée `[A,B,C,D,E,F]`, l'ORDRE EXACT de la file à venir après grades déterministes :
   - `grade(A, q=1)` (lapse léger, offset **+2**) ⇒ A réapparaît **2ᵉ carte à venir** : file à venir `[B, A, C, D, E, F]` (curseur sur B).
   - puis `grade(B, q=2)` (lapse dur, offset **+4**) ⇒ B réapparaît **4ᵉ carte à venir** : `[A, C, D, B, E, F]`.
   - `grade(_, q≥3)` ⇒ la carte est **consommée** (quitte la file), **pas** de réinsertion.
   - **Clamp fin de file** : un lapse offset +4 avec < 4 cartes à venir ⇒ carte réinsérée **en toute fin** (vecteur dédié). Les positions EXACTES sont figées en littéraux. *(Discriminant : INJ-2 — passer l'offset q=1 de +2 à +3, ou q=2 de +4 à +5, décale une position ⇒ le golden d'ordre rougit ; supprimer le clamp fait sortir un `insert` hors bornes ⇒ rouge.)*

4. **AC4 — Seuil de lapse = `passThreshold` réutilisé, pas un littéral (D3).** Le cycle re-queue ssi `quality < passThreshold` (=3, lu de `ZSrsConfig`/exposé, **aucun `3` en dur** dans `zcrud_session`). Vecteur : `q ∈ {0,1,2}` ⇒ réinsertion ; `q ∈ {3,4,5}` ⇒ consommation (pas de réinsertion). *(Discriminant : INJ-3 — remplacer la lecture du seuil par un littéral, puis un test config-custom (`passThreshold: 4`) attend `q=3` re-queué et obtient consommé ⇒ rouge ; prouve que le seuil est réellement paramétré.)*

5. **AC5 — Table d'offsets `{0,1}→+2, {2}→+4` gelée et documentée (D2).** Vecteurs : `q=0` et `q=1` produisent le **même** offset (+2) ; `q=2` produit +4 ; la table est portée par des **constantes nommées** de `zcrud_session` (pas de nombres magiques épars). *(Discriminant : si `q=0` divergeait de `q=1`, ou si `q=2` retombait sur +2, le vecteur rougit.)*

6. **AC6 — `grade` ATOMIQUE & ordonné ; échec de review NON avalé (D5, AD-5/R6).** L'ordre observable est : seam de review invoqué **avant** mutation de file ; sur `Left(ZFailure)` du seam, la file **n'est pas** mutée et l'échec est **exposé** (état d'erreur / valeur de retour `Either`), jamais silencieusement absorbé. Vecteur : un espion renvoyant `Left` ⇒ file inchangée + erreur visible ; un espion `Right` ⇒ file mutée. *(Discriminant : INJ-4 — si le moteur mutait la file avant/malgré l'échec du review, le vecteur « review échoue ⇒ file inchangée » rougit ; un `catch` avalant l'erreur rougit le vecteur « erreur visible ».)*

7. **AC7 — Complétion & compteurs déterministes.** `isComplete` devient vrai quand la file à venir est vide (toutes cartes consommées, aucune en attente de réinsertion) ; `reviewed`/`lapses`/`remaining` sont cohérents à chaque pas (vecteur figé sur la séquence d'AC3). *(Discriminant : si un lapse comptait comme `reviewed` définitif (au lieu de rester `remaining` jusqu'à réussite), le compteur figé rougit.)*

8. **AC8 — `ChangeNotifier` notifie une fois par transition, granularité correcte (AD-2).** Chaque `grade` réussi émet **exactement un** `notifyListeners` ; aucune notification sur une transition no-op (grade hors file / file vide). Vecteur : un listener compteur figé. *(Discriminant : une double-notification ou une notification fantôme sur no-op rougit le compteur.)*

9. **AC9 — Package NEUF acyclique, CORE OUT=0, runner Flutter, gates verts (AD-1, D7).** `packages/zcrud_session/` créé (`pubspec.yaml` Flutter, barrel, `lib/src/domain/z_study_session_engine.dart`) ; ajouté au `workspace:` du root `pubspec.yaml` (1 ligne). `melos list` = **16** (was 15) ; `python3 scripts/dev/graph_proof.py` ⇒ **ACYCLIQUE OK, CORE OUT=0 OK** ; `flutter test` sur `zcrud_session` **RC=0** ; `dart analyze packages/zcrud_session` **RC=0**. Aucune arête entrante vers `zcrud_session`. *(Discriminant : orchestrateur au gate de commit — `melos run analyze` + `melos run verify` REPO-WIDE verts ; le graph_proof rougirait si une arête créait un cycle ou touchait CORE OUT.)*

10. **AC10 — Aucun `.g.dart` parasite ; surface publique minimale (AD-4).** `zcrud_session` ne déclare **aucun** `@ZcrudModel` (state runtime, non persisté) ⇒ **aucun** `build_runner`/`.g.dart` attendu (pas de `dev_dependencies` codegen sauf si un besoin réel émerge — à justifier). Le barrel n'exporte que `ZStudySessionEngine`/`ZSessionState`/`ZSessionItem`/`ZSessionReviewer`. *(Discriminant : `melos run generate` ne produit aucun fichier dans `zcrud_session/lib/**` ; un `.g.dart` inattendu = signal.)*

---

## Tasks / Subtasks

- [x] **T1 — Créer le package `zcrud_session` (Flutter) + l'inscrire au workspace (AC9, AC10, D7)**
  - [x] `packages/zcrud_session/pubspec.yaml` : `name: zcrud_session`, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2`, `flutter: sdk: flutter` (dep) + `flutter_test: sdk: flutter` (dev) ; `dependencies: zcrud_core ^0.1.0, zcrud_flashcard ^0.1.0, zcrud_study_kernel ^0.1.0`. **Pas** de `zcrud_generator`/`build_runner` (aucun `@ZcrudModel`, AC10) sauf besoin justifié. Header-commentaire décrivant le rôle (miroir des autres pubspec ES).
  - [x] `packages/zcrud_session/lib/zcrud_session.dart` (barrel, D8) : dartdoc + exports.
  - [x] Root `pubspec.yaml` : **1 ligne additive** `- packages/zcrud_session` dans le bloc `workspace:` (près des satellites study : après `zcrud_exam`/avant `zcrud_study`, position non load-bearing pour la résolution). **NE PAS** éditer `melos.yaml` (glob `packages/**`, capté auto — cf. §4). `dart pub get` racine pour matérialiser.
- [x] **T2 — `ZSessionItem` + `ZSessionState` immuables (AC7, D1/D2/D7)**
  - [x] `ZSessionItem` neutre `{flashcardId, folderId, typeKey?}` (pas de widget/type flashcard tiré).
  - [x] `ZSessionState` immuable : `queue` (ordre), `cursor`, `reviewed`/`lapses`/`remaining`, `isComplete`, `error?` (ZFailure). `==`/`hashCode` (value-object). Constructeur `initial(List<ZSessionItem>, {mode})`.
- [x] **T3 — Reducer PUR de file + offsets +2/+4 (AC3, AC4, AC5, cœur R12, D2/D3)**
  - [x] Constantes nommées : `kLapseOffsetSoft = 2` (q∈{0,1}), `kLapseOffsetHard = 4` (q==2) ; seuil = `ZSrsConfig().passThreshold` (lu, jamais `3` en dur).
  - [x] Fonction pure `reduceGrade(ZSessionState, int quality) → ZSessionState` : lapse ⇒ retirer carte courante + réinsérer à `offset-1` parmi les à-venir (clamp fin) ; réussite ⇒ consommer ; recalcul compteurs/`isComplete`. **Aucune** horloge, **aucune** I/O.
- [x] **T4 — `ZStudySessionEngine extends ChangeNotifier` + seam de review (AC1, AC2, AC6, AC8, D1/D4/D5/D6)**
  - [x] `typedef ZSessionReviewer = Future<ZResult<ZRepetitionInfo>> Function({required String flashcardId, required String folderId, required int quality, DateTime? now});` (ou interface mince). Champ `final ZSessionReviewer _review;` — **PAS** de `ZSrsScheduler`/`ZRepetitionStore`.
  - [x] `Future<ZResult<ZRepetitionInfo>> grade(int quality, {DateTime? now})` : (1) `await _review(current, quality, now)` ; (2) sur `Right` → `state = reduceGrade(state, quality); notifyListeners();` ; sur `Left` → exposer `error`, **ne pas** muter la file, remonter `Left` (D5/AC6). Import `flutter/foundation.dart` SEUL.
  - [x] Getters lecture (`state`, `current`, `isComplete`, compteurs). Aucun `setState`, aucune closure de build.
- [x] **T5 — Tests (runner `flutter test`, R14) + pouvoir discriminant (R12)**
  - [x] `test/z_session_engine_test.dart` : golden d'ordre de file AC3 (`[A..F]`, séquence figée), AC4 seuil (config-custom `passThreshold:4`), AC5 table offsets, AC2 espion (compteur d'appels seam + carte attendue), AC6 espion `Left`/`Right`, AC7 compteurs/`isComplete`, AC8 listener compteur.
  - [x] `test/z_purity_test.dart` (AC1) : lit `lib/**/*.dart`, ROUGIT si un import banni (`flutter_riverpod`/`get`/`provider`/`flutter/material`/`flutter/widgets`) apparaît. `@TestOn('vm')` (accès `dart:io` pour lire les sources) — SIGNALER que ce fichier lit le FS (sinon il sortirait de la cible d'un éventuel web gate ; ici package Flutter ⇒ hors web gate de toute façon).
- [x] **T6 — Vérif verte CIBLÉE + injections R3 (AC9)**
  - [x] `flutter test` (zcrud_session) → RC=0 (HORS pipe, R15). `dart analyze packages/zcrud_session` → RC=0.
  - [x] `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK. `dart run melos list` → 16 packages.
  - [x] `melos run generate` (ciblé zcrud_session) ne produit aucun `.g.dart` (AC10).
  - [x] INJ-1..INJ-5 déroulées, chacune ROUGE comme prévu, restaurées par édition ciblée (R13).
  - [x] **`melos run analyze` + `melos run verify` REPO-WIDE : délégués à l'ORCHESTRATEUR au gate de commit d'epic** (workstream B actif).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail`/`| grep`. **Restauration (R13) :** édition ciblée de retour, JAMAIS `git checkout`. **Runner (R14) :** `zcrud_session` = paquet Flutter (ChangeNotifier) ⇒ `flutter test`.

- **INJ-1 — Voie de review unique (AC2, AD-9/AD-23).** Dans `grade`, commenter l'`await _review(...)` (ou l'appeler 2×). `cd packages/zcrud_session && flutter test test/z_session_engine_test.dart; RC=$?` → **RC≠0** (compteur de l'espion : attendu N, obtenu 0 ou 2N). Restaurer. *(Prouve que le seam est l'UNIQUE écriture, appelée 1×/grade.)*
- **INJ-2 — Offset de réinsertion (AC3, cœur).** Édition ciblée : `kLapseOffsetSoft` 2→3 (ou `kLapseOffsetHard` 4→5). `flutter test test/z_session_engine_test.dart; RC=$?` → **RC≠0** (le golden d'ordre `[B,A,C,D,E,F]` / `[A,C,D,B,E,F]` rouge). Restaurer. *(Prouve que le contrat MORD sur l'offset +2/+4.)*
- **INJ-3 — Seuil de lapse paramétré (AC4).** Édition ciblée : remplacer la lecture `config.passThreshold` par le littéral `3`. `flutter test; RC=$?` → **RC≠0** (vecteur config-custom `passThreshold:4` attend `q=3` re-queué, obtient consommé). Restaurer. *(Prouve que le seuil est lu, pas codé en dur.)*
- **INJ-4 — Atomicité / échec non avalé (AC6, R6).** Édition ciblée : muter la file **avant** `await _review` (ou envelopper le `grade` dans un `try/catch` qui avale). `flutter test; RC=$?` → **RC≠0** (vecteur « review `Left` ⇒ file inchangée + erreur visible » rouge). Restaurer. *(Prouve l'ordre grade-atomique et la non-absorption de l'échec.)*
- **INJ-5 — Pureté / zéro gestionnaire d'état (AC1).** Ajout ciblé d'un `import 'package:provider/provider.dart';` (ou `flutter/material.dart`) en tête d'un fichier `lib/`. `flutter test test/z_purity_test.dart; RC=$?` → **RC≠0** (le scan d'imports rougit). Retirer l'import. *(Prouve que la garde de pureté MORD ; contre-preuve R12 : sans l'ajout, le scan est vert.)*

---

## Vérif verte à rejouer (commandes exactes, RC capturé HORS pipe — R15)

```bash
# 0. Matérialiser le nouveau package dans le workspace (après édition du root pubspec)
dart pub get; echo "pub get RC=$?"

# 1. Tests du package NEUF (RUNNER = flutter, R14 : ChangeNotifier ∈ flutter/foundation)
cd packages/zcrud_session && flutter test; echo "session test RC=$?"; cd ../..

# 2. Analyse ciblée
dart analyze packages/zcrud_session; echo "analyze RC=$?"

# 3. Graphe (acyclicité + CORE OUT=0) & inventaire packages
python3 scripts/dev/graph_proof.py; echo "graph RC=$?"     # attendu : ACYCLIQUE OK, CORE OUT=0 OK
dart run melos list; echo "melos list RC=$?"                # attendu : 16 packages

# 4. Codegen ciblé — NE doit RIEN produire dans zcrud_session/lib (AC10)
dart run melos run generate; echo "generate RC=$?"

# 5. (ORCHESTRATEUR, gate de commit d'epic — PAS pendant le dev, workstream B actif)
dart run melos run analyze; echo "melos analyze RC=$?"
dart run melos run verify;  echo "melos verify  RC=$?"
```

> ⚠️ Ne JAMAIS mesurer un RC via `flutter test … | tail`/`| grep` (R15). Toujours `cmd; RC=$?`.
> ⚠️ **Runner (R14)** : `zcrud_session` = paquet Flutter ⇒ `flutter test`. `dart test` échouerait (import `package:flutter/foundation.dart` non résolu hors runner Flutter).

---

## Dev Notes

### Périmètre & invariants NON-NÉGOCIABLES
- **Fichiers touchés (EXCLUSIVEMENT)** : **NOUVEAU** `packages/zcrud_session/` (`pubspec.yaml`, `lib/zcrud_session.dart`, `lib/src/domain/z_study_session_engine.dart`, + éventuels `z_session_state.dart`/`z_session_item.dart`/`z_session_reviewer.dart`, `test/z_session_engine_test.dart`, `test/z_purity_test.dart`) ; root `pubspec.yaml` bloc `workspace:` (**1 ligne** additive). **NE touche PAS** `zcrud_core`, `zcrud_flashcard/lib` (composé, jamais modifié), `zcrud_study` (workstream B), `melos.yaml` (glob), NI `sprint-status.yaml` (orchestrateur).
- **AD-23 « zéro écriture SM-2 PAR CONSTRUCTION »** : le moteur n'a **aucun** champ `ZSrsScheduler`/`ZRepetitionStore` et n'appelle jamais `apply`/`initial`/`put` — la seule mutation SRS transite par le seam `ZSessionReviewer` (= `reviewCard` en prod, AD-9). ⚠️ Nuance vs ES-4.3/4.4 : le cycle SRS **écrit bien l'état** (via le seam, pour enregistrer lapse/réussite) — l'invariant ici est « **UNE seule voie, jamais de seconde** », pas « aucune écriture » (ça, c'est ES-4.3 linéaire).
- **AD-2 (Flutter-native, objectif produit n°1)** : `ChangeNotifier` + state immuable + reducer pur ; jamais `setState`, jamais Riverpod/GetX/provider dans le runtime (leur câblage vit dans les bindings, ES-9).
- **AD-1** : arêtes SORTANTES seules (`→ core/flashcard/kernel`), CORE OUT=0, acyclique. **AD-5/AD-10** : `Either`/`ZFailure` remontés, échec jamais avalé.

### Anti-inertie (réutilisation)
- **COMPOSER `reviewCard` d'ES-4.1** (verrou `z_sm2_contract_test.dart`), **ne JAMAIS** réimplémenter SM-2, un intervalle, ou l'EF dans `zcrud_session`.
- Réutiliser `ZReviewMode`/`ZStudySessionConfig` (kernel), `ZResult`/`ZFailure`/`Either` (core), `ZRepetitionInfo` (flashcard) — aucun clone.
- Le moteur est **générique** sur l'identité de carte (`ZSessionItem` neutre) : il ne tire aucun widget flashcard, ne connaît pas le type d'une carte au-delà d'un `typeKey` opaque.
- **NE PAS recopier la constante brute `after=3/5` d'IFFD** : modéliser l'offset UTILISATEUR +2/+4 (D2) et prouver l'ordre résultant par golden (le 3/5 d'IFFD est l'artefact d'un remove-then-insert — cf. GOTCHA mesuré).

### Runner par nature du package (R14) — MESURÉ
`ChangeNotifier` provient de `package:flutter/foundation.dart` (aucun équivalent pur-Dart) ⇒ `zcrud_session` déclare `flutter: sdk: flutter` ⇒ **paquet Flutter ⇒ `flutter test`** (comme `zcrud_core` depuis E2-7). Le `gate:web` (pur-Dart only, `gate_web_determinism.dart` l.24-42) l'IGNORE. La logique de file est pur-Dart (reducer), mais le **runner du package** reste `flutter test`.

### Fichiers racine touchés (miroir melos↔pubspec) — MESURÉ
`melos.yaml` déclare `packages: - packages/**` en **GLOB** (l.7-8) ⇒ un nouveau package est capté **automatiquement**, **aucune** édition de `melos.yaml`. Le `gate:melos` (`gate_melos_divergence.dart`) ne compare que les blocs `scripts:` (l.29-36), pas la liste de packages. **Seul le bloc `workspace:` du root `pubspec.yaml`** (source de vérité de la résolution) reçoit `- packages/zcrud_session` (1 ligne). Le bloc `melos.ignore` du root ne concerne QUE les harnais `tool/` — `zcrud_session` n'y est pas.

### Project Structure Notes
- Structure miroir des satellites study : `lib/<pkg>.dart` (barrel) + `lib/src/domain/`. Impl runtime en `domain` (pas de `data`/`presentation` ici ; les widgets qualité/progression = ES-4.5).
- `ZSessionReviewer` = seam d'injection (typedef ou interface mince) : en prod, `(f) => repo.reviewCard(flashcardId: f.flashcardId, folderId: f.folderId, quality: q, now: now)`. Le binding (ES-9) fournit le repo concret ; le moteur reste ignorant de Firestore/Hive.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-4.2 — ACs : queue + réinsertion +2/+4, voie unique reviewCard]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-23 — L239-242 : runtimes purs, offset +2/+4, zéro écriture SM-2 par construction, aucun import Riverpod/GetX]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-22 — L228-237 : ZSm2Scheduler source unique (verrouillé ES-4.1)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-2 / AD-1 — Flutter-native ; CORE OUT=0, acyclique]
- [Source: _bmad-output/implementation-artifacts/stories/es-4-1-convergence-sm2-tests-contrat.md — ordonnanceur verrouillé (dép. de tête)]
- [Source: packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart#L262-L289 — reviewCard, voie d'écriture unique à composer]
- [Source: packages/zcrud_flashcard/lib/src/data/z_repetition_store.dart#L42-L66 — port ZRepetitionStore (que le moteur NE référence PAS)]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart#L44-L78 — lapse = q<passThreshold=3 (seuil réutilisé, D3)]
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart#L53-L118 — ZStudySessionConfig/ZReviewMode (kernel)]
- [Source: ~/DEV/iffd/lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart#L32-L168 — putFlashcardAfterXNext (after=3/5), lapse re-queue, offset utilisateur « 2/4 cards later »]
- [Source: ~/DEV/lex_douane/packages/lex_core/lib/domain/usecases/education/sm2.dart#L197-L229 — previewLabel « dans 2/4 cartes » (label canonique +2/+4)]
- [Source: pubspec.yaml#workspace / melos.yaml#L7-8 — glob packages/** ; seul workspace: du root pubspec déclare le package]
- [Source: scripts/dev/graph_proof.py#L74-L93 — acyclicité + CORE OUT=0 ; scripts/ci/gate_web_determinism.dart#L24-42 — web gate pur-Dart only]
- [Source: CLAUDE.md — AD-2 (SM-1), AD-9/AD-23 (voie unique), AD-1 (CORE OUT=0), R12/R13/R14/R15 gotchas]

## Dev Agent Record

### Agent Model Used

bmad-dev-story (effort high), Opus 4.8 — workstream A parallèle, isolation stricte `zcrud_session` + 1 ligne additive au bloc `workspace:` du root `pubspec.yaml`.

### Debug Log References

Vérif verte CIBLÉE (RC capturé HORS pipe, R15) :

| # | Commande | Attendu | Résultat |
|---|----------|---------|----------|
| 0 | `dart pub get` (bootstrap, propriétaire du nouveau package) | RC=0 | **RC=0** (`Got dependencies!`) |
| 1 | `dart analyze packages/zcrud_session` | RC=0 | **RC=0** (`No issues found!`) |
| 2 | `flutter test` (zcrud_session, R14) | RC=0 | **RC=0** — `All tests passed!` (**20 tests** : 18 engine + 2 purity) |
| 3 | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE + CORE OUT=0 | **RC=0** — `ACYCLIQUE OK`, `CORE OUT=0 OK` ; 3 arêtes SORTANTES `zcrud_session → {core, flashcard, study_kernel}` ; `noeuds = 20, triés = 20` |
| 4 | `dart run melos list` | 20 (19→20 ; la story dit « 15→16 » = ERRONÉ) | **20** |
| 5 | AC10 codegen | aucun `.g.dart` | **0** `.g.dart`/`.freezed.dart` ; aucun `@ZcrudModel`/`build_runner`/`zcrud_generator` dans le code (uniquement en commentaire) |

Isolation confirmée : `git status --porcelain packages/zcrud_flashcard/lib packages/zcrud_core` = **VIDE** (composé, jamais modifié). `melos.yaml` non touché (glob `packages/**`). `sprint-status.yaml` non touché (orchestrateur). `melos run verify`/`analyze` REPO-WIDE délégués à l'orchestrateur (workstream B ES-5 actif).

### Completion Notes List

**Conception**
- `ZStudySessionEngine extends ChangeNotifier` (`package:flutter/foundation.dart` SEULE — aucun widget). État `ZSessionState` **immuable** (value-object `==`/`hashCode` profonds via `listEquals`), muté par un **reducer PUR** top-level `reduceGrade(state, quality, {passThreshold})` (aucune horloge, aucune I/O). `notifyListeners()` **uniquement si l'état change** (`_setState` compare) ⇒ zéro notification fantôme (AC8).
- **Seam injecté `ZSessionReviewer`** (typedef = signature exacte de `reviewCard`). Le moteur ne détient **AUCUN** `ZSrsScheduler`/`ZRepetitionStore` et n'appelle **jamais** `apply`/`initial`/`put` (AD-23 « zéro par construction »). `grade()` : (1) seam D'ABORD (1×/grade), (2) sur `Right` → `reduceGrade` + notify, (3) sur `Left` → `error` exposé + `Left` remonté, file **inchangée** (AD-5/R6). No-op sur session complète (aucun seam, aucune notify, `Left(DomainFailure)`).
- **Cycle offsets (D2)** : lapse (`quality < passThreshold`) ⇒ retrait de la carte courante + réinsertion parmi les à-venir à `cursor + offset - 1` (clamp fin de file). `offset = kLapseOffsetSoft (=2)` si `quality ≤ kLapseSoftMaxQuality (=1)`, sinon `kLapseOffsetHard (=4)`. **NE recopie PAS** la constante brute 3/5 d'IFFD (artefact du remove-then-insert) — modélise l'offset UTILISATEUR +2/+4.
- **Seuil RÉUTILISÉ (D3)** : `_passThreshold => _config.passThreshold` (`ZSrsConfig`), jamais un `3` littéral.

**Golden d'ordre figé (AC3)** : file `[A,B,C,D,E,F]` → `grade(A,q=1)` (+2) ⇒ `[B,A,C,D,E,F]` (curseur B) → `grade(B,q=2)` (+4) ⇒ `[A,C,D,B,E,F]`. Clamp : `[X,Y,Z]` + `grade(X,q=2)` ⇒ `[Y,Z,X]`. Réussite ⇒ consommation. Compteurs : lapse reste `remaining` (jamais `reviewed`) ; `reviewed` n'incrémente qu'à la réussite.

**Espion seam (AC2)** : N grades ⇒ EXACTEMENT N appels, cartes attendues `[A,B,C]`, `now` relayé ; grade sur session complète ⇒ 0 appel supplémentaire.

**Injections R3 — messages EXACTS (rejouées RÉELLEMENT, RC hors pipe, restaurées par édition ciblée R13)**
- **INJ-1** (2e appel `_review` hors voie unique) → `flutter test test/z_session_engine_test.dart` **RC=1** — `Expected: <3> / Actual: <6>` (compteur espion), aussi `Expected: <1> / Actual: <2>`. Prouve la voie UNIQUE 1×/grade.
- **INJ-2** (`kLapseOffsetSoft` 2→3) → **RC=1** — `Expected: 'BACDEF' / Actual: 'BCADEF'`. Prouve que le golden MORD sur l'offset +2.
- **INJ-3** (`_config.passThreshold` → littéral `3`) → **RC=1** — vecteur config-custom `passThreshold:4` : `Expected: <2> / Actual: <1>` (remaining). Prouve que le seuil est LU, pas codé en dur.
- **INJ-4** (`reduceGrade` AVANT `await _review`) → **RC=1** — vecteur AC6 `seam Left ⇒ file INCHANGÉE` : `Expected: 'ABC' / Actual: 'BAC'`. Prouve l'ordre grade-atomique / non-absorption de l'échec.
- **INJ-5** (`import 'package:provider/provider.dart';` dans `z_session_item.dart`) → `flutter test test/z_purity_test.dart` **RC=1** — `imports bannis (gestionnaire d'état / widget) détectés : lib/src/domain/z_session_item.dart:14 → import 'package:provider/provider.dart';`. Prouve que la garde de pureté MORD (contre-preuve : scan vert sans l'ajout).

Après restauration des 5 injections : `dart analyze` **RC=0** (`No issues found!`) + `flutter test` **RC=0** (`All tests passed!`, 20 tests).

### File List

**NOUVEAU package `packages/zcrud_session/`**
- `packages/zcrud_session/pubspec.yaml` (Flutter ; deps `zcrud_core`/`zcrud_flashcard`/`zcrud_study_kernel` ; dev `flutter_test` ; aucun codegen)
- `packages/zcrud_session/lib/zcrud_session.dart` (barrel)
- `packages/zcrud_session/lib/src/domain/z_session_item.dart`
- `packages/zcrud_session/lib/src/domain/z_session_reviewer.dart`
- `packages/zcrud_session/lib/src/domain/z_session_state.dart`
- `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` (engine + constantes offsets + reducer pur `reduceGrade`)
- `packages/zcrud_session/test/z_session_engine_test.dart` (18 tests : golden ordre, espion seam, seuil, offsets, atomicité, compteurs, notify, reducer pur)
- `packages/zcrud_session/test/z_purity_test.dart` (2 tests : scan d'imports bannis, `@TestOn('vm')`)

**Racine (1 ligne additive)**
- `pubspec.yaml` — bloc `workspace:` : `- packages/zcrud_session` (+ commentaire descriptif). `melos.yaml` NON touché (glob).
