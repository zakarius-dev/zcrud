# Story ES-4.3 : Runtimes cramming/liste — `ZLinearSessionState` (zéro écriture SM-2 PAR CONSTRUCTION)

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. ES-4.3 dépend d'ES-4.1 (TÊTE, source SM-2 unique verrouillée) ET d'ES-4.2 (DONE : package zcrud_session créé, ZSessionItem/ZSessionState/ZStudySessionEngine livrés). SÉQUENTIELLE vis-à-vis d'ES-4.1/4.2/4.4 : MÊME package zcrud_session, mais FICHIERS DOMAINE DISTINCTS (z_linear_session_state.dart). NE modifie PAS le moteur SRS d'ES-4.2. -->
<!-- ⚠️ PARALLÉLISATION — workstream A. Un workstream B (epic ES-5) écrit packages/zcrud_study/** en parallèle. ISOLATION STRICTE : cette story n'écrit QUE des fichiers NEUFS sous packages/zcrud_session/lib/src/domain/ + 1 ligne additive (export) au barrel packages/zcrud_session/lib/zcrud_session.dart + un test neuf. NE touche PAS zcrud_core, zcrud_flashcard/lib, zcrud_study, z_study_session_engine.dart (ES-4.2, sauf réutilisation en LECTURE des constantes exportées), NI sprint-status.yaml (orchestrateur). Vérifs CIBLÉES par package (PAS de melos repo-wide au milieu du dev — délégué à l'orchestrateur au gate de commit). -->
<!-- Gotchas rétro en vigueur : R12 (pouvoir discriminant EXIGÉ — zéro-SM2-PAR-CONSTRUCTION + progression linéaire golden CENTRAUX), R14 (runner par NATURE du package — zcrud_session = Flutter car ChangeNotifier ∈ flutter/foundation → flutter test), R15 (RC capturé HORS pipe), R13 (restauration par édition ciblée, jamais git checkout), R3 (injections orchestrateur), R6 (jamais de dégradation silencieuse). -->

## Story

As a **utilisateur**,
I want **réviser en mode cramming/liste via `ZLinearSessionState` — une classe PURE (`ChangeNotifier`/reducer) qui parcourt une file de cartes LINÉAIREMENT (par index/curseur), sans détenir NI `ZSrsScheduler`, NI `ZRepetitionStore`, NI seam de review SRS — de sorte qu'aucun chemin de la session ne puisse faire progresser ma planification SRS**,
so that **une session d'entraînement en liste ou en bachotage ne modifie JAMAIS mes intervalles de répétition espacée — garantie NON par un test de comportement seul, mais PAR CONSTRUCTION (aucun point d'écriture SRS n'existe dans le runtime).**

---

## Contexte & état mesuré sur disque

> ⚠️ **Aucun nouveau package, aucune nouvelle dépendance, aucun `.g.dart`.** Cette story AJOUTE des fichiers domaine DISTINCTS dans le package `zcrud_session` **déjà livré par ES-4.2** et COMPOSE ses value-objects (`ZSessionItem`, `ZSessionState`). Le graphe de dépendances est **INCHANGÉ** (`graph_proof.py` inchangé), `melos list` reste **20**.

### 1. Le socle ES-4.2 à COMPOSER (livré, lu INTÉGRALEMENT sur disque)

| Symbole | Fichier | Rôle réutilisé par ES-4.3 |
|---|---|---|
| `ZSessionItem` | `packages/zcrud_session/lib/src/domain/z_session_item.dart` (l.16-50) | Identité **neutre** de carte `{flashcardId, folderId, typeKey?}`, immuable, value-object. **Réutilisée telle quelle** (aucun clone) comme élément de la file linéaire. |
| `ZSessionState` | `packages/zcrud_session/lib/src/domain/z_session_state.dart` (l.23-135) | Instantané **immuable** `{queue, cursor, reviewed, lapses, mode, error?}`, value-object (`==`/`hashCode` profonds via `listEquals`, l.108-129), `copyWith`, getters `current`/`isComplete`/`remaining`. **Réutilisé comme snapshot** du runtime linéaire (composition, anti-inertie). |
| `kLapseOffsetSoft = 2`, `kLapseOffsetHard = 4`, `kLapseSoftMaxQuality = 1` | `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` (l.40-50) | Constantes d'offset **exportées** par le barrel (l.24). **Réutilisées en LECTURE** pour la ré-insertion cramming (une carte ratée re-boucle « +2/+4 cartes plus loin », comme IFFD). **JAMAIS recopiées.** |
| `reduceGrade(...)` | `z_study_session_engine.dart` (l.68-110) | **NE PAS réutiliser** : c'est le reducer du CYCLE SRS (sémantique `reviewed`/lapse SRS). ES-4.3 écrit ses **propres** reducers linéaires purs. |
| `ZStudySessionEngine` | `z_study_session_engine.dart` (l.115-215) | **NE PAS modifier, NE PAS étendre.** Détient un seam `ZSessionReviewer` = écriture SRS ; c'est précisément ce que le runtime LINÉAIRE ne doit PAS avoir. |

> ⚠️ **Nuance décisive vs ES-4.2.** Le cycle SRS (`ZStudySessionEngine`) **écrit bien** l'état SRS — via une **voie UNIQUE** (`ZSessionReviewer` = `reviewCard`), l'invariant étant « une seule voie, jamais de seconde ». Le runtime LINÉAIRE d'ES-4.3 est **plus fort** : **ZÉRO écriture SRS, aucune voie du tout** — `ZLinearSessionState` **ne détient AUCUN** `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ⇒ il n'existe **aucun point d'appel `apply`** atteignable (AD-23 « par construction »).

### 2. Le barrel actuel (lu — `packages/zcrud_session/lib/zcrud_session.dart` l.21-24)
```dart
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
export 'src/domain/z_session_state.dart';
export 'src/domain/z_study_session_engine.dart';
```
⇒ **1 ligne additive** : `export 'src/domain/z_linear_session_state.dart';` (édition ciblée, additive, du barrel — le SEUL fichier ES-4.2 touché, et seulement par ajout).

### 3. `ZReviewMode` (kernel, lu — `z_review_mode.dart` l.16-44)
Enum à 6 valeurs. Note de flux mesurée (l.16-20) : *« seuls `spaced` et `learn` écrivent de l'état SRS ; les modes `list`/`test`/`whiteExam`/`cramming` parcourent les cartes SANS faire avancer la répétition espacée »*. Les deux modes LINÉAIRES d'ES-4.3 sont **`ZReviewMode.list`** (« parcours en liste (revue linéaire, sans SRS) », l.33-34) et **`ZReviewMode.cramming`** (« bachotage … sans SRS », l.42-43). `spaced`/`learn`/`test`/`whiteExam` sont **HORS scope** (spaced/learn = cycle ES-4.2 ; whiteExam = ES-4.4).

### 4. `ZSrsConfig.passThreshold` (lu — `z_srs_config.dart` l.26/56-58)
`passThreshold = 3` (défaut). Réutilisé **en LECTURE** comme frontière réussite/lapse pour la ré-insertion cramming (`quality < passThreshold` ⇒ re-boucle). Ce n'est **pas** une écriture SRS : aucun `ZRepetitionInfo` n'est produit, aucun `apply` appelé — juste un `int` de comparaison. Jamais un `3` littéral dans `zcrud_session` (D3, cohérent avec ES-4.2).

### 5. Runner & gates (MESURÉ — inchangés vs ES-4.2)
- **`ChangeNotifier` ∈ `package:flutter/foundation.dart`** ⇒ `zcrud_session` = paquet **Flutter** ⇒ **`flutter test`** (R14). `dart test` échouerait (import flutter non résolu hors runner Flutter).
- **`gate:web`** (`scripts/ci/gate_web_determinism.dart` l.24-42) cible les paquets **PUR-DART** : `zcrud_session` (Flutter) est **HORS cible**. Aucune action web.
- **`gate:graph`** (`scripts/dev/graph_proof.py`) : ES-4.3 n'ajoute **AUCUNE** arête (aucune nouvelle dépendance de package — `zcrud_flashcard`/`zcrud_study_kernel`/`zcrud_core` déjà déclarés en ES-4.2, cf. `pubspec.yaml` l.48-53). **ACYCLIQUE + CORE OUT=0 préservés, `graph_proof.py` INCHANGÉ.**
- **`gate:melos`** compare les blocs `scripts:` ; `melos.yaml` capte `packages/**` en glob : **aucune édition**. Aucun nouveau package ⇒ `melos list` = **20** (inchangé).
- **`gate:codegen-distribution`** : aucun `@ZcrudModel` (état runtime NON persisté) ⇒ **aucun `*.g.dart`** attendu (AC-8).

---

## Reconnaissance externe MESURÉE (documentaire — origine des runtimes linéaires)

> Chiffres et emplacements **MESURÉS sur disque**. Le critère de résolution **exécutable in-repo** reste le golden de progression linéaire ci-dessous (AC3/AC4).

### IFFD — le mode cramming réel « no SRS update » (`~/DEV/iffd/lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart`, `extends ChangeNotifier`, lu l.80-107)
```dart
bool isCramming = false, // For cramming mode - no SRS update
...
// 0. If Cramming, we don't update SRS. ... we don't save changes to the repetition info.
if (isCramming) {
  if (quality < 3) {                 // lapse → la carte re-boucle dans la session
    int after = 3;
    if (quality == 1) after = 3;     // Fail  → réapparaît 2 cartes plus loin
    if (quality == 2) after = 5;     // Hard  → réapparaît 4 cartes plus loin
    putFlashcardAfterXNext(flashcard: flashcard, after: after, previousIndex: currentFlashcardIndex);
  }
  return;                            // ⚠️ RETURN AVANT tout onSave() → ZÉRO écriture SRS
}
// ... (branche NON-cramming ci-dessous appelle await onSave(updatedRepetition) — voie SRS)
```
- **Preuve mesurée du « zéro SRS » cramming** : la branche `isCramming` **`return` (l.106) AVANT** le moindre `onSave` (comparer l.106 vs l.125 `await onSave(...)` de la branche SRS). L'entraînement re-boucle la file (`putFlashcardAfterXNext`) mais **n'appelle jamais** la persistance de répétition ⇒ intervalles SRS **intacts**.
- **Offsets cramming** : `after=3` (q≤1) / `after=5` (q=2). Après `removeAt` + `insert`, l'effet UTILISATEUR = **+2 / +4 cartes plus loin** (même artefact remove-then-insert que le cycle, cf. GOTCHA ES-4.2). ⇒ ES-4.3 réutilise `kLapseOffsetSoft (=2)` / `kLapseOffsetHard (=4)` d'ES-4.2 (anti-inertie).

### lex — le label canonique des modes non-SRS (`~/DEV/lex_douane/packages/lex_core/lib/domain/enums/review_mode.dart` l.5, l.25-26, lu ; `study_mode.dart` l.18-22, l.60)
- Dartdoc l.5 : *« `[test]`, `[whiteExam]` et `[cramming]` **n'écrivent jamais** de `RepetitionInfo` »* ; l.25-26 : *« Bachotage (cramming) — **pas** d'écriture SM-2 »*.
- `study_mode.dart` l.22 : *« modes `[list]`, `[test]`, `[whiteExam]`, `[cramming]` n'écrivent **jamais** de SM-2 »*. Le mode `list` = parcours linéaire strict (pas de re-boucle).

### ⚠️ GOTCHA MESURÉ — « zéro SRS » ≠ « ne rien faire »
Le mode `list` = parcours **strictement linéaire** (curseur 0→N−1, aucune ré-insertion). Le mode `cramming` = parcours linéaire **avec re-boucle des cartes ratées** (offset +2/+4) — **mais toujours sans SRS**. La distinction list/cramming porte **uniquement** sur la re-boucle, **jamais** sur une écriture SRS. AD-23 est autoritaire : **les deux modes n'ont AUCUN seam SRS** ; leur unique différence est la stratégie d'avancement de la file (golden AC3 vs AC4).

---

## Décisions de conception (tranchées ici)

- **D1 — `ZLinearSessionState extends ChangeNotifier` (foundation seule), état = value-object immuable + reducer PUR.** Le runtime linéaire détient un **`ZSessionState` immuable réutilisé d'ES-4.2** (composition — aucun clone) et l'expose en lecture. Les transitions délèguent à des **reducers PURS top-level** (aucun effet de bord, aucune horloge, aucune I/O) puis `notifyListeners()` **granulaire** (uniquement si l'état change, via un `_setState` comparant le value-object — miroir d'ES-4.2). **AUCUN** `setState`, **AUCUN** import `flutter_riverpod`/`get`/`provider`/`flutter/material`/`widgets` (AD-2/AD-23/NFR-S5).
- **D2 — ZÉRO écriture SM-2 PAR CONSTRUCTION (cœur AD-23).** `ZLinearSessionState` **ne déclare AUCUN champ** de type `ZSessionReviewer`, `ZSrsScheduler`, `ZRepetitionStore` ; son constructeur **n'accepte AUCUN** paramètre de review/scheduler ; son corps **ne mentionne JAMAIS** `apply`/`initial`/`put`/`reviewCard`/`ZRepetitionInfo`. ⇒ il n'existe **aucun point d'appel SRS atteignable** — l'invariant « zéro écriture » est garanti **par la STRUCTURE du type**, pas par une garde runtime. *(Contraste explicite : `ZStudySessionEngine` d'ES-4.2 DÉTIENT un `ZSessionReviewer` ; `ZLinearSessionState` n'en détient AUCUN.)*
- **D3 — Deux modes LINÉAIRES via une même state-machine, reducers distincts.**
  - **`ZReviewMode.list`** (strict) : `advance()` fait progresser le curseur `0 → N` sans jamais modifier l'ordre ni ré-insérer ; `reviewed += 1` par carte parcourue ; `isComplete` quand toutes les cartes ont été vues. La `quality` éventuelle est **ignorée** (parcours pur).
  - **`ZReviewMode.cramming`** (re-boucle) : `answer(quality)` — sur **réussite** (`quality >= passThreshold`) la carte est **consommée** (`reviewed += 1`) ; sur **lapse** (`quality < passThreshold`) la carte est **retirée puis ré-insérée parmi les cartes à venir** à `cursor + offset − 1` (clamp fin de file), `offset = kLapseOffsetSoft (=2)` si `quality <= kLapseSoftMaxQuality (=1)` sinon `kLapseOffsetHard (=4)`, `lapses += 1` (la carte reste `remaining`). **AUCUNE écriture SRS dans les deux cas.**
- **D4 — Constructeur restreint aux modes linéaires.** `ZLinearSessionState({required List<ZSessionItem> queue, ZReviewMode mode = ZReviewMode.list})`. Un `assert(mode == ZReviewMode.list || mode == ZReviewMode.cramming)` **rejette** en debug les modes SRS (`spaced`/`learn`) et examen (`whiteExam`/`test` → ES-4.4) : ce runtime ne sait PAS écrire du SRS, il refuse donc les modes qui l'exigeraient. *(Discriminant additionnel : un test vérifie que `spaced` déclenche l'assert.)*
- **D5 — Seuil de lapse RÉUTILISÉ, pas recopié (cohérent D3 d'ES-4.2).** La frontière cramming réussite/lapse est `ZSrsConfig().passThreshold` (=3), **lu** (paramétrable via un `ZSrsConfig` optionnel injecté), **jamais** un `3` littéral. Réutiliser ce seuil n'est **pas** une dépendance SRS d'écriture : c'est un simple `int` de comparaison (aucun `apply`).
- **D6 — Déterminisme total (aucune horloge).** Aucun `DateTime.now()`, aucun `now` (inutile : pas de seam SRS). Les reducers linéaires sont des **fonctions pures de `(state[, quality])`** ⇒ golden reproductible bit-à-bit.
- **D7 — Réutilisation stricte, zéro duplication (anti-inertie AD-4).** COMPOSER `ZSessionItem` (identité), `ZSessionState` (snapshot immuable + value-object equality + `copyWith`), les constantes `kLapseOffsetSoft`/`kLapseOffsetHard`/`kLapseSoftMaxQuality` (offsets cramming), `ZReviewMode` (kernel), `ZSrsConfig` (seuil). **NE PAS** re-déclarer d'item/state/offsets ; **NE PAS** réutiliser `reduceGrade` (sémantique SRS) — écrire des reducers linéaires dédiés.
- **D8 — Barrel : 1 export additif.** `packages/zcrud_session/lib/zcrud_session.dart` reçoit `export 'src/domain/z_linear_session_state.dart';` (+ les reducers top-level `advanceLinear`/`requeueCramming` si exposés pour testabilité golden). Impl sous `lib/src/domain/`. **NE PAS** toucher aux autres exports.
- **D9 — Graphe & runner INCHANGÉS.** Aucune nouvelle dépendance (deps ES-4.2 suffisent : `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel`), aucun nouveau package ⇒ `graph_proof.py` inchangé, CORE OUT=0/acyclique préservés, `melos list = 20`. Runner = `flutter test` (R14). Aucun `.g.dart`.

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant (R12)** : il nomme le vecteur/test qui ROUGIT si la garde saute. Les deux CENTRAUX : **AC2 (zéro-SM2 PAR CONSTRUCTION)** et **AC3/AC4 (progression linéaire golden)**.

1. **AC1 — `ZLinearSessionState` est une CLASSE PURE, zéro gestionnaire d'état (AD-2/AD-23/NFR-S5).** Le runtime `extends ChangeNotifier` (import `package:flutter/foundation.dart` **seul**), expose un `ZSessionState` immuable, mute via reducers purs + `notifyListeners()` granulaire. **Aucun** import `flutter_riverpod`/`get`/`provider`/`flutter/material`/`flutter/widgets` dans tout `packages/zcrud_session/lib/**`. *(Discriminant : verrouillé par le scan d'imports existant `z_purity_test.dart` (ES-4.2, déjà présent — il balaie tout `lib/**`) qui ROUGIT si un import banni apparaît dans le fichier neuf ; INJ-3.)*

2. **AC2 — ZÉRO écriture SM-2 PAR CONSTRUCTION — CŒUR (AD-23, D2).** `ZLinearSessionState` **ne déclare AUCUN** champ de type `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`, son constructeur **n'accepte AUCUN** paramètre de review/scheduler, et son source **ne contient JAMAIS** les symboles `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`/`ZRepetitionInfo`. Prouvé par **DEUX gardes complémentaires** :
   - **(a) scan de source** `z_linear_no_srs_test.dart` : lit `lib/src/domain/z_linear_session_state.dart` et ROUGIT si l'un de ces symboles apparaît ⇒ l'introduction d'un champ reviewer SRS **rougit** l'AC ;
   - **(b) comportement** : une session linéaire COMPLÈTE (list ET cramming, toutes cartes parcourues/consommées) s'exécute **sans qu'aucun seam SRS n'existe pour être appelé** — il n'y a **aucun** paramètre reviewer à injecter au constructeur (preuve de type : le test construit `ZLinearSessionState(queue: …)` sans reviewer, ce qui compile). *(Discriminant : INJ-1 — ajouter un champ `ZSessionReviewer _review;` + son appel rougit immédiatement le scan (a) ; c'est la garde « par construction ».)*

3. **AC3 — Progression LINÉAIRE stricte (mode `list`), ORDRE & CURSEUR GELÉS — CŒUR (D3, R12).** `z_linear_session_test.dart` fige, sur une file `[A,B,C,D,E,F]` en mode `list`, la séquence EXACTE des cartes `current` renvoyées par `advance()` : **`[A, B, C, D, E, F]`** dans cet ordre, la file n'étant **jamais** ré-ordonnée, `cursor` croissant `0,1,2,3,4,5`, `reviewed` = `1..6`, `isComplete` vrai **uniquement** après la 6ᵉ. *(Discriminant : INJ-2 — si `advance()` sautait une carte, ré-ordonnait la file, ou avançait de 2, le golden d'ordre/curseur rougit.)*

4. **AC4 — Cramming : re-boucle des ratés à offset +2/+4, ORDRE GELÉ ; réussite = consommation (D3/D5).** Sur `[A,B,C,D,E,F]` en mode `cramming` :
   - `answer(A, q=1)` (lapse léger, +2) ⇒ A réapparaît **2ᵉ carte à venir** : file à venir `[B, A, C, D, E, F]`, `lapses=1`, A reste `remaining` ;
   - puis `answer(B, q=2)` (lapse dur, +4) ⇒ `[A, C, D, B, E, F]`, `lapses=2` ;
   - `answer(_, q≥passThreshold)` ⇒ carte **consommée** (quitte la file), `reviewed += 1`, **pas** de ré-insertion ;
   - **clamp fin de file** : offset +4 avec < 4 cartes à venir ⇒ carte ré-insérée **en toute fin** (vecteur dédié `[X,Y,Z]` + `answer(X,q=2)` ⇒ `[Y,Z,X]`). Positions figées en littéraux. *(Discriminant : INJ-4 — passer l'offset q=1 de +2 à +3 (ou q=2 de +4 à +5) décale une position ⇒ golden rouge ; supprimer le clamp fait sortir un `insert` hors bornes ⇒ rouge.)*

5. **AC5 — Seuil cramming = `passThreshold` réutilisé, pas un littéral (D5).** La re-boucle cramming se déclenche ssi `quality < passThreshold` (=3, lu de `ZSrsConfig`, **aucun `3` en dur**). Vecteur config-custom `ZSrsConfig(passThreshold: 4)` : `answer(q=3)` attendu **re-bouclé** (lapse) ; en défaut (=3), `answer(q=3)` attendu **consommé**. *(Discriminant : remplacer la lecture par un littéral `3` fait échouer le vecteur `passThreshold:4`.)*

6. **AC6 — Modes SRS/examen REFUSÉS par le constructeur (D4).** `ZLinearSessionState(queue: …, mode: ZReviewMode.spaced)` (ou `learn`/`whiteExam`/`test`) déclenche l'`assert` en debug (ce runtime ne sait PAS écrire du SRS). *(Discriminant : le test `expect(() => ZLinearSessionState(queue: q, mode: ZReviewMode.spaced), throwsA(isA<AssertionError>()))` rougit si l'assert est retiré.)*

7. **AC7 — `ChangeNotifier` : une notification par transition effective, granularité correcte (AD-2, AC8-ES4.2).** Chaque `advance()`/`answer()` qui change réellement l'état émet **exactement un** `notifyListeners` ; aucune notification sur no-op (avancer une session complète). Vecteur : listener compteur figé. *(Discriminant : double-notification ou notification fantôme sur no-op rougit le compteur.)*

8. **AC8 — Aucun `.g.dart`, aucune nouvelle dépendance/arête, graphe & inventaire INCHANGÉS (AD-1, D9).** Aucun `@ZcrudModel` ⇒ **aucun** `*.g.dart` produit dans `zcrud_session/lib/**`. `pubspec.yaml` de `zcrud_session` **inchangé** (deps ES-4.2 suffisent). `python3 scripts/dev/graph_proof.py` ⇒ **ACYCLIQUE OK, CORE OUT=0 OK** (identique à ES-4.2) ; `dart run melos list` ⇒ **20** (inchangé) ; `flutter test` sur `zcrud_session` **RC=0** ; `dart analyze packages/zcrud_session` **RC=0**. *(Discriminant : orchestrateur au gate de commit — `melos run analyze` + `melos run verify` REPO-WIDE verts.)*

---

## Tasks / Subtasks

- [x] **T1 — `ZLinearSessionState` + reducers linéaires purs (AC1, AC2, AC3, AC4, AC5, AC6, AC7 ; D1..D7)**
  - [x] `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart` : `class ZLinearSessionState extends ChangeNotifier` (import `package:flutter/foundation.dart` SEUL). **AUCUN** champ `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; **AUCUN** paramètre de review/scheduler au constructeur (D2, cœur AC2).
  - [x] Constructeur `ZLinearSessionState({required List<ZSessionItem> queue, ZReviewMode mode = ZReviewMode.list, ZSrsConfig config = const ZSrsConfig()})` + `assert(mode == ZReviewMode.list || mode == ZReviewMode.cramming)` (D4/AC6). Détient un `ZSessionState _state` amorcé via le **constructeur public** de `ZSessionState` (pas `.initial` — évite le motif banni `.initial(` de la garde zéro-SM2).
  - [x] Reducers PURS top-level : `ZSessionState advanceLinear(ZSessionState)` (list : curseur strict, aucune ré-insertion) ; `ZSessionState requeueCramming(ZSessionState, int quality, {required int passThreshold})` (cramming : réussite→consommation, lapse→ré-insertion `cursor+offset−1` clamp fin, `offset` via `kLapseOffsetSoft`/`kLapseOffsetHard`/`kLapseSoftMaxQuality` RÉUTILISÉS). **Aucune** horloge, **aucune** I/O, **aucun** symbole SRS.
  - [x] API : `advance()` (mode list), `answer(int quality)` (mode cramming ; en mode list, ignore `quality` et délègue à `advanceLinear`). `_setState(next)` compare le value-object et ne notifie que si changement (AC7, miroir ES-4.2). Getters lecture `state`/`current`/`isComplete`/`reviewed`/`lapses`/`remaining` (mode-conscients). Seuil = `_config.passThreshold` (jamais `3` littéral, D5/AC5).
  - [x] `packages/zcrud_session/lib/zcrud_session.dart` : **1 ligne additive** `export 'src/domain/z_linear_session_state.dart';` (D8). Autres exports intacts.
- [x] **T2 — Tests (runner `flutter test`, R14) + pouvoir discriminant (R12)**
  - [x] `test/z_linear_session_test.dart` : golden AC3 (`list` : ordre `[A..F]`, curseur, `reviewed`, `isComplete`) ; golden AC4 (`cramming` : `[B,A,C,D,E,F]` → `[A,C,D,B,E,F]`, clamp `[X,Y,Z]`→`[Y,Z,X]`, réussite=consommation, `lapses`) ; AC5 seuil config-custom `passThreshold:4` ; AC6 assert modes SRS ; AC7 listener compteur (une notif/transition, zéro sur no-op).
  - [x] `test/z_linear_no_srs_test.dart` (AC2a, CŒUR) : `@TestOn('vm')` ; lit `lib/src/domain/z_linear_session_state.dart` (hors commentaires) et **ROUGIT** si l'un de `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`/`.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo` apparaît. `z_purity_test.dart` (ES-4.2) balaie déjà `lib/**` ⇒ couvre AC1 sur le fichier neuf (vérifié).
- [x] **T3 — Vérif verte CIBLÉE + injections R3 (AC8)**
  - [x] `flutter test` (zcrud_session) → RC=0 (37 tests). `dart analyze packages/zcrud_session` → RC=0.
  - [x] `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK (inchangé). `dart run melos list` → 20 (inchangé).
  - [x] Aucun `.g.dart` dans `zcrud_session/lib` (aucun `@ZcrudModel`, AC8).
  - [x] INJ-1..INJ-4 déroulées, chacune ROUGE comme prévu, restaurées par édition ciblée (R13).
  - [ ] **`melos run analyze` + `melos run verify` REPO-WIDE : délégués à l'ORCHESTRATEUR au gate de commit d'epic** (workstream B actif).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail`/`| grep`. **Restauration (R13) :** édition ciblée de retour, JAMAIS `git checkout`. **Runner (R14) :** `zcrud_session` = paquet Flutter ⇒ `flutter test`.

- **INJ-1 — Zéro-SM2 PAR CONSTRUCTION (AC2a, CŒUR AD-23).** Ajout ciblé d'un champ `final ZSessionReviewer _review;` (+ import + un appel `_review(...)`) dans `z_linear_session_state.dart`. `cd packages/zcrud_session && flutter test test/z_linear_no_srs_test.dart; RC=$?` → **RC≠0** (le scan détecte `ZSessionReviewer`/`reviewCard`). Retirer. *(Prouve que l'introduction d'un seam SRS rougit l'AC — la garde « par construction ».)*
- **INJ-2 — Progression linéaire stricte (AC3, CŒUR).** Édition ciblée : dans `advanceLinear`, avancer le curseur de 2 (ou sauter une carte). `flutter test test/z_linear_session_test.dart; RC=$?` → **RC≠0** (golden d'ordre/curseur `[A,B,C,D,E,F]` rouge). Restaurer. *(Prouve que le contrat MORD sur la progression linéaire.)*
- **INJ-3 — Pureté / zéro gestionnaire d'état (AC1).** Ajout ciblé d'un `import 'package:provider/provider.dart';` en tête de `z_linear_session_state.dart`. `flutter test test/z_purity_test.dart; RC=$?` → **RC≠0** (scan d'imports bannis rouge). Retirer. *(Prouve que la garde de pureté MORD ; contre-preuve : scan vert sans l'ajout.)*
- **INJ-4 — Offset cramming (AC4).** Édition ciblée : dans `requeueCramming`, forcer `offset = kLapseOffsetSoft + 1` (ou lire `kLapseOffsetHard + 1`). `flutter test test/z_linear_session_test.dart; RC=$?` → **RC≠0** (golden cramming `[B,A,C,D,E,F]`/`[A,C,D,B,E,F]` rouge). Restaurer. *(Prouve que le contrat MORD sur l'offset +2/+4 de la re-boucle.)*

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
- **Fichiers touchés (EXCLUSIVEMENT)** : **NEUFS** `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart`, `packages/zcrud_session/test/z_linear_session_test.dart`, `packages/zcrud_session/test/z_linear_no_srs_test.dart` ; **1 ligne additive** au barrel `packages/zcrud_session/lib/zcrud_session.dart` (export). **NE touche PAS** `z_study_session_engine.dart`/`z_session_state.dart`/`z_session_item.dart`/`z_session_reviewer.dart` (ES-4.2 — réutilisés en LECTURE via import/export), `pubspec.yaml` (deps suffisantes), `zcrud_core`, `zcrud_flashcard/lib`, `zcrud_study` (workstream B), `melos.yaml`, NI `sprint-status.yaml` (orchestrateur).
- **AD-23 « ZÉRO écriture SM-2 PAR CONSTRUCTION »** : le runtime linéaire n'a **AUCUN** seam/scheduler/store SRS ⇒ aucun point d'écriture SRS n'existe (garantie de TYPE, pas de garde runtime). ⚠️ Distinction vs ES-4.2 : le cycle SRS écrit via UNE voie unique (`ZSessionReviewer`) ; le linéaire n'a AUCUNE voie.
- **AD-2 (Flutter-native, objectif produit n°1)** : `ChangeNotifier` + state immuable + reducers purs ; jamais `setState`, jamais Riverpod/GetX/provider (bindings = ES-9/ES-10).
- **AD-1** : aucune nouvelle arête (deps ES-4.2 réutilisées) ⇒ CORE OUT=0/acyclique/graphe INCHANGÉS.
- **AD-4 (extensibilité/composition)** : COMPOSER `ZSessionItem`/`ZSessionState`/constantes d'offset — jamais dupliquer.

### Anti-inertie (réutilisation)
- **COMPOSER** `ZSessionItem` (identité), `ZSessionState` (snapshot immuable + `==`/`hashCode`/`copyWith`), `kLapseOffsetSoft`/`kLapseOffsetHard`/`kLapseSoftMaxQuality` (offsets cramming), `ZReviewMode` (kernel), `ZSrsConfig.passThreshold` (seuil). **NE PAS** réutiliser `reduceGrade` (sémantique SRS) ni `ZStudySessionEngine` (détient un seam SRS = interdit ici).
- **NE PAS** recopier la constante brute `after=3/5` d'IFFD : réutiliser l'offset UTILISATEUR +2/+4 déjà modélisé en ES-4.2 (artefact remove-then-insert).
- Aucun nouveau package, aucune nouvelle dépendance, aucun `.g.dart`, `graph_proof.py` inchangé.

### Runner par nature du package (R14) — MESURÉ
`ChangeNotifier` ∈ `package:flutter/foundation.dart` ⇒ `zcrud_session` = paquet Flutter ⇒ **`flutter test`**. Le `gate:web` (pur-Dart only) l'IGNORE. Le test de scan de source (`z_linear_no_srs_test.dart`) lit le FS ⇒ `@TestOn('vm')` (comme `z_purity_test.dart` d'ES-4.2).

### Project Structure Notes
- Structure miroir ES-4.2 : impl en `lib/src/domain/`, exposée par le barrel. Runtime pur (pas de `data`/`presentation` ; les widgets qualité/progression = ES-4.5).
- Le binding (ES-9/ES-10) instancie `ZLinearSessionState(queue: …, mode: ZReviewMode.list|cramming)` — **aucun** reviewer à fournir (contraste voulu avec `ZStudySessionEngine`).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-4.3 — L657-673 : `ZLinearSessionState`, ne référence PAS `ZRepetitionStore`, zéro `apply`, garanti par construction]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-23 — L239-242 : runtimes purs, linéaire/examen ne référencent PAS `ZRepetitionStore`, « zéro écriture SM-2 » garanti PAR CONSTRUCTION et testé (aucun `apply` durant une session linéaire)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-2 / AD-1 — Flutter-native ; CORE OUT=0, acyclique]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#FR-S19 — L52, L123 : Runtimes cramming/liste (`ZLinearSessionState`), zéro écriture SM-2 par construction]
- [Source: _bmad-output/implementation-artifacts/stories/es-4-2-runtime-session-srs-cycle.md — socle zcrud_session livré ; distinction voie-unique (cycle) vs zéro-voie (linéaire)]
- [Source: packages/zcrud_session/lib/src/domain/z_session_item.dart#L16-L50 — ZSessionItem neutre (réutilisé)]
- [Source: packages/zcrud_session/lib/src/domain/z_session_state.dart#L23-L135 — ZSessionState immuable value-object (réutilisé comme snapshot)]
- [Source: packages/zcrud_session/lib/src/domain/z_study_session_engine.dart#L40-L50 — kLapseOffsetSoft/Hard/SoftMaxQuality (réutilisés) ; L115-215 ZStudySessionEngine (NON modifié, détient un seam = contraste)]
- [Source: packages/zcrud_session/lib/zcrud_session.dart#L21-L24 — barrel (1 export additif)]
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart#L16-L44 — ZReviewMode : list/cramming = sans SRS]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart#L26-L58 — passThreshold=3 (seuil réutilisé, D5)]
- [Source: ~/DEV/iffd/lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart#L80-L107 — branche isCramming : `return` AVANT tout onSave ⇒ zéro SRS ; re-boucle after=3/5 (+2/+4)]
- [Source: ~/DEV/lex_douane/packages/lex_core/lib/domain/enums/review_mode.dart#L5,L25-26 — cramming « pas d'écriture SM-2 » ; study_mode.dart#L22 — list/test/whiteExam/cramming « n'écrivent jamais de SM-2 »]
- [Source: scripts/dev/graph_proof.py — acyclicité + CORE OUT=0 (INCHANGÉ) ; scripts/ci/gate_web_determinism.dart#L24-42 — web gate pur-Dart only]
- [Source: CLAUDE.md — AD-2 (SM-1), AD-23 (zéro écriture SM-2 par construction), AD-1 (CORE OUT=0), R12/R13/R14/R15 gotchas]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high) — workstream A parallèle (isolation stricte `packages/zcrud_session/**`).

### Debug Log References

Vérif verte CIBLÉE (RC capturé HORS pipe, R15 ; runner `flutter test`, R14) :

| # | Commande | Attendu | RC | Résultat |
|---|----------|---------|----|----------|
| 1 | `dart analyze packages/zcrud_session` | 0 | **0** | No issues found! |
| 2 | `flutter test` (zcrud_session) | 0 | **0** | All tests passed! — **37 tests** (17 neufs ES-4.3 + 20 existants ES-4.2, zéro régression) |
| 3 | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE + CORE OUT=0 | **0** | ACYCLIQUE OK / CORE OUT=0 OK (INCHANGÉ) |
| 4 | `dart run melos list` | 20 | — | **20** (INCHANGÉ) |
| 5 | `find packages/zcrud_session/lib -name '*.g.dart'` | vide | — | aucun `.g.dart` (AC8) |

`melos run analyze` + `melos run verify` REPO-WIDE : **délégués à l'orchestrateur** au gate de commit d'epic (workstream B `zcrud_study` actif — pas de vérif repo-wide au milieu du dev).

Injections R3 (pouvoir discriminant R12) — chacune ROUGE comme prévu, restaurée par édition ciblée (R13), message EXACT :

- **INJ-1** (zéro-SM2 PAR CONSTRUCTION, AC2a — CŒUR) : ajout `ZSessionReviewer? _review;` dans le code du runtime → `flutter test test/z_linear_no_srs_test.dart` RC=**1**.
  Message : `Expected: empty / Actual: ['lib/src/domain/z_linear_session_state.dart:175 → ZSessionReviewer dans « ZSessionReviewer? _review; // INJ-1 »']` → « symbole(s) SRS détecté(s) dans le runtime linéaire — la garantie « zéro écriture SM-2 PAR CONSTRUCTION » (AD-23) est violée ». Restauré.
- **INJ-2** (progression linéaire stricte, AC3 — CŒUR) : `advanceLinear` curseur `+2` → `flutter test test/z_linear_session_test.dart` RC=**1**.
  Message : `Expected: ['A', 'B', 'C', 'D', 'E', 'F'] / Actual: ['A', 'C', 'E']`. Restauré (`+1`).
- **INJ-3** (pureté / zéro gestionnaire d'état, AC1) : `import 'package:provider/provider.dart';` en tête du runtime → `flutter test test/z_purity_test.dart` RC=**1**.
  Message : `Expected: empty / Actual: ["lib/src/domain/z_linear_session_state.dart:43 → import 'package:provider/provider.dart'; // INJ-3"]` → « imports bannis (gestionnaire d'état / widget) détectés ». Restauré.
- **INJ-4** (offset cramming +2/+4, AC4) : `requeueCramming` offset soft `kLapseOffsetSoft + 1` → `flutter test test/z_linear_session_test.dart` RC=**1**.
  Message : `Expected: ['B', 'A', 'C', 'D', 'E', 'F'] / Actual: ['B', 'C', 'A', 'D', 'E', 'F']`. Restauré (`kLapseOffsetSoft`).

### Completion Notes List

- **`ZLinearSessionState extends ChangeNotifier`** (foundation seule, AD-2) : détient un `ZSessionState` immuable **réutilisé d'ES-4.2** (composition, aucun clone) amorcé via le **constructeur public** de `ZSessionState` (et NON la factory `.initial` — voir note zéro-SM2 ci-dessous), mute via reducers PURS top-level + `_setState` granulaire (notifie ssi le value-object change, AC7).
- **Zéro-SM2 PAR CONSTRUCTION (AD-23, cœur AC2)** : le runtime ne déclare **AUCUN** champ `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`, son constructeur n'accepte **AUCUN** paramètre de review/scheduler, et son CODE ne contient **aucun** `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo` ⇒ aucun point d'écriture SRS atteignable (garantie de TYPE). Détail décisif : l'amorçage évite `ZSessionState.initial(...)` (qui contient le motif banni `.initial(`) et passe par le constructeur public `ZSessionState(queue: …, cursor: 0, …)` — la garde de source reste ainsi verte par construction, tout en NOMMANT librement les concepts SRS dans la dartdoc (le scan ignore les lignes de commentaire).
- **Deux modes linéaires, TOUJOURS sans SRS** : `list` = `advanceLinear` (curseur `0→N` strict, file jamais ré-ordonnée ni tronquée, `reviewed += 1`/carte ; `isComplete` = `cursor ≥ N`) ; `cramming` = `requeueCramming` (réussite `q ≥ passThreshold` ⇒ consommation `reviewed += 1` ; lapse `q < passThreshold` ⇒ retrait + ré-insertion à `cursor + offset − 1` clampé fin, `offset = kLapseOffsetSoft(2)` si `q ≤ kLapseSoftMaxQuality(1)` sinon `kLapseOffsetHard(4)` — constantes **RÉUTILISÉES** d'ES-4.2 ; `lapses += 1`). `isComplete` cramming = file vide.
- **Constructeur restreint** : `assert(mode == list || mode == cramming)` refuse en debug `spaced`/`learn`/`whiteExam`/`test` (AC6) — ce runtime ne sait pas écrire de SRS, il refuse les modes qui l'exigeraient.
- **Seuil réutilisé, pas recopié (AC5, D5)** : frontière lapse = `ZSrsConfig.passThreshold` lu (injectable), jamais un `3` littéral. Vecteur `passThreshold: 4` : `q=3` devient un lapse (re-bouclé) ; en défaut `q=3` est consommé.
- **Getters mode-conscients** : `isComplete`/`remaining` distinguent list (curseur vs fin de file) et cramming (file vide) car `ZSessionState.isComplete` (= `queue.isEmpty`) ne s'applique qu'au cramming (list ne tronque pas la file).
- **Anti-inertie (AD-4)** : COMPOSE `ZSessionItem`, `ZSessionState` (+ `==`/`copyWith`), constantes d'offset, `ZReviewMode`, `ZSrsConfig` — **aucune** duplication ; `reduceGrade`/`ZStudySessionEngine` (sémantique SRS) NON réutilisés. `z_study_session_engine.dart` touché uniquement en **LECTURE** (import `show` des 3 constantes d'offset — aucune modification).
- **Barrel** : 1 export additif `z_linear_session_state.dart` (autres exports intacts). **Aucune** nouvelle dépendance/arête (deps ES-4.2 suffisent) : graphe INCHANGÉ, CORE OUT=0, `melos list = 20`, aucun `.g.dart` (AC8).

### File List

- **NEUF** `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart` — `ZLinearSessionState` + reducers purs `advanceLinear`/`requeueCramming`.
- **NEUF** `packages/zcrud_session/test/z_linear_session_test.dart` — goldens AC3 (list)/AC4 (cramming)/AC5 (seuil)/AC6 (assert modes)/AC7 (notif granulaire) + AC1 (type).
- **NEUF** `packages/zcrud_session/test/z_linear_no_srs_test.dart` — garde zéro-SM2 par construction (AC2a, `@TestOn('vm')`, scan de source).
- **MODIFIÉ (additif, 1 ligne)** `packages/zcrud_session/lib/zcrud_session.dart` — `export 'src/domain/z_linear_session_state.dart';`.
