---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story 1.4 : Pile de session swipeable et modes

Status: review

**Clé :** `su-4-pile-swipeable-modes` · **Epic :** E-STUDY-UI · **Taille :** L · **Dépend de :** su-1 (done), su-2, su-3
**Couvre :** FR-SU6, FR-SU7 · **AD :** AD-33, AD-34, AD-40, AD-46 + hérités AD-1..32

---

## Story

As an **apprenant**,
I want **parcourir mes cartes en pile et noter avec les boutons de qualité**,
So that **j'enchaîne mes révisions au rythme de mon app actuelle**.

---

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

| Décision | Verrouillée par |
|---|---|
| **Le swipe est une NAVIGATION. Il ne note JAMAIS.** La notation appartient aux `ZSrsQualityButtons` (su-3, livrés). | FR-SU6, sprint-status, AD-33 |
| Les **6 modes** sont servis par les **3 runtimes qui EXISTENT DÉJÀ**. **AUCUN moteur n'est créé.** | AD-34 |
| `flutter_card_swiper: ^7.2.0` — **CONFINÉ à `zcrud_session`**. Jamais dans `zcrud_core`/`zcrud_flashcard`. | AD-1, AD-8, NFR-SU7 |
| L'écriture SRS ne passe **que** par le seam `ZSessionReviewer`. | AD-33 |
| L'échelle et le clamp appartiennent à `ZSrsConfig` (`clampQuality`, unique voie). | AD-46 |
| Variantes par **enum**, jamais un booléen. | Conventions du spine |

### 🔴 su-4 est la PREMIÈRE story de l'epic à toucher un `pubspec.yaml`

su-1, su-2 et su-3 n'ont ajouté **aucune** dépendance tierce. su-4 en ajoute **une** :
`flutter_card_swiper: ^7.2.0`, dans `packages/zcrud_session/pubspec.yaml` **et nulle part ailleurs**.
Ce n'est pas une formalité : c'est une **arête de graphe** soumise aux gates (`melos run verify`,
`graph_proof`). Le confinement est un **AC testé** (AC10), pas une intention.

**Vérifié sur disque** — `scripts/dev/graph_proof.py` (98 lignes) ne contient **aucune** allowlist de
dépendance tierce :
```bash
grep -n "third\|tiers\|ALLOW\|confin\|syncfusion\|quill\|graphite\|confetti" scripts/dev/graph_proof.py
# → RC=1 (AUCUNE correspondance)
```
⇒ `graph_proof` ne vérifie que les arêtes **inter-`zcrud_*`** : il **ne détectera PAS** une fuite de
`flutter_card_swiper` vers un autre package. **Le confinement n'est gardé que par le test que su-4
écrit (AC10).** Sans lui, la contrainte NFR-SU7 est **déclarative et non tenue**.

Patron à suivre — **il existe déjà** : `packages/zcrud_export/test/isolation_gates_test.dart`
(allowlist **DÉRIVÉE dynamiquement**, jamais une liste figée ; « un garde ne prouve QUE ce qu'il
scanne » ; contrôle « aucun type tiers en signature publique » avec fichiers publics dérivés).
**Le copier dans l'esprit, pas le dupliquer aveuglément.**

---

## 🎯 LE point de conception : L'ARÈNE DES GESTES, ACTE III

**L'histoire, en trois actes — su-4 est le troisième et le plus dur :**

| Acte | Story | Conflit | Résolution |
|---|---|---|---|
| I | su-2 | `QuillEditor` volait le tap de révélation (**HIGH réel**, sous 328/328 verts) | `IgnorePointer` sur le slot AD-40 |
| II | su-3 | saisie vs révélation | **Dissous** : répondre ≠ dévoiler ; surfaces **frères** |
| III | **su-4** | **drag horizontal** au-dessus de *tap* + *saisie* + *scroll vertical* | ⬇️ ci-dessous |

### Ce que fait RÉELLEMENT `flutter_card_swiper` (lu sur disque, jamais supposé)

Source : `~/.pub-cache/hosted/pub.dev/flutter_card_swiper-7.2.0/lib/src/widget/card_swiper_state.dart`
(le paquet est **déjà dans le pub-cache** — le dev **DOIT le lire**, pas deviner) :

```dart
// _frontItem() — lignes 110-170
GestureDetector(
  child: Transform.rotate(...),        // ⚠️ AUCUN `behavior:` ⇒ deferToChild
  onTap: () async {                    // ⚠️ TOUJOURS enregistré, même si !isDisabled
    if (widget.isDisabled) { await widget.onTapDisabled?.call(); }
  },
  onPanStart:  (i) { if (!widget.isDisabled) {...} },
  onPanUpdate: (i) { if (!widget.isDisabled) { setState(() { _cardAnimation.update(dx, dy, ...); }); } },
  onPanEnd:    (i) { if (_canSwipe) { _onEndAnimation(); } },
)
```

**Quatre conséquences DURES, chacune vérifiée dans le source :**

1. **`onPan*` = `PanGestureRecognizer` ⇒ il revendique LES DEUX AXES.** Pas un
   `HorizontalDragGestureRecognizer`. Il entre donc en arène contre **tout** défilement vertical
   et **toute** saisie de texte situés **sous lui**.
2. **`onTap` est TOUJOURS enregistré** ⇒ un `TapGestureRecognizer` est **en permanence** dans
   l'arène, en concurrence avec l'`InkWell` de révélation de su-2. C'est **exactement** la
   configuration du HIGH D1 de su-2, avec un compétiteur de plus.
3. **`allowedSwipeDirection` NE filtre RIEN pendant le drag.** Vérifié : `_isValidDirection` n'est
   consulté **que** dans `_onEndAnimation()` (fin de geste). Pendant le drag, `_cardAnimation.update(
   tapInfo.delta.dx, tapInfo.delta.dy, ...)` s'applique **sur les deux axes** quoi qu'il arrive.
   ⇒ **`AllowedSwipeDirection.symmetric(horizontal: true)` n'empêche PAS le pan de voler un
   défilement vertical.** Toute story qui croirait le contraire se trompe.
4. **`onPanUpdate` appelle `setState`** ⇒ **`cardBuilder` est ré-invoqué à CHAQUE frame de drag**,
   pour la carte de devant **et** les cartes de fond. C'est frontalement le sujet de NFR-SU2
   (« la pile ne se reconstruit pas entièrement »).

### 🔒 La conception RETENUE (mode non interactif — option la plus conservatrice)

**Dissolution par la GÉOMÉTRIE, dans la continuité EXACTE de su-3 (surfaces frères).**
On ne « règle » pas l'arène avec des recognizers custom : **on fait en sorte que les gestes
concurrents ne se rencontrent jamais.**

```
ZSessionCardSwiper                     ← possède le CardSwiper ; le pan ne couvre QUE ceci
└── CardSwiper(cardBuilder: ...)
    └── Stack
        ├── ZFlashcardReviewCard       ← FRÈRE 1 (su-2) : AFFICHAGE + tap-to-reveal
        │                                 (instance MÉMOÏSÉE — cf. AC7)
        └── overlay émoji              ← recalculé par frame (offset), IgnorePointer
──────────────────────────────────────── frontière du swiper ────────────────────────
ZFlashcardAnswerInput                  ← FRÈRE 2 (su-3) : HORS de la pile. JAMAIS sous le pan.
ZSrsQualityButtons                     ← FRÈRE 3 (su-3) : la notation. HORS de la pile.
ZSessionProgressIndicator              ← FRÈRE 4 (su-4)
```

**Règle non négociable : `ZFlashcardAnswerInput` et `ZSrsQualityButtons` ne descendent JAMAIS dans
le `cardBuilder` du swiper.** Le champ de texte n'est jamais sous le `PanGestureRecognizer` :
le conflit *drag ∥ saisie* est **dissous par construction**, pas arbitré. Un `TextField` sous un
pan ancêtre, c'est la sélection de texte et le placement du curseur qui se battent contre la
navigation — un conflit qu'aucun réglage de seuil ne rend fiable.

**Reste alors DEUX conflits réels, qui doivent être MESURÉS (AC6), jamais raisonnés :**

- **drag ∥ tap-to-reveal** — `TapGestureRecognizer` (CardSwiper, ancêtre) vs `InkWell` (su-2,
  descendant). *Attendu* : sur un tap sans déplacement, l'arène est balayée (« sweep ») et le
  **premier membre inscrit gagne** ; l'inscription suit l'ordre du hit-test, **du plus profond au
  plus superficiel** ⇒ l'`InkWell` gagne, la révélation survit. **C'est une PRÉDICTION, pas une
  preuve.** AC6 la met à l'épreuve **sur le chemin markdown exact** (le seul qui avait démasqué D1).
- **drag ∥ scroll vertical de la face** — `PanGestureRecognizer` (ancêtre) vs
  `VerticalDragGestureRecognizer` (`Scrollable` de la face su-2, descendant). *Attendu* : sur un
  mouvement vertical pur, les deux dépassent leur `touchSlop` quasi simultanément, mais l'événement
  est dispatché **au plus profond d'abord** ⇒ le `Scrollable` appelle `resolve(accepted)` en
  premier et gagne ; le pan est rejeté. Sur un mouvement horizontal, le recognizer vertical
  n'accepte jamais ⇒ le pan gagne. **PRÉDICTION également.** AC6 la mesure.

> ⚠️ **Si AC6 infirme une prédiction** : le correctif est **au niveau de la composition**
> (contraindre la face à ne pas défiler *dans la pile*, ou remonter la surface concernée hors du
> swiper) — **JAMAIS** en retirant l'`IgnorePointer` de su-2 (c'est le correctif d'un HIGH réel,
> gardé par `z_flashcard_gesture_arena_test.dart`), **JAMAIS** en assouplissant un test.
> Consigner le résultat mesuré dans le Dev Agent Record, dans les deux cas.

---

## Périmètre RÉEL vérifié sur disque (consommer — ne JAMAIS recréer)

| Acquis | Fichier | su-4 en fait quoi |
|---|---|---|
| `ZStudySessionEngine` (+ garde de mode AD-34) | `zcrud_session/lib/src/domain/z_study_session_engine.dart` | **consomme** |
| `ZLinearSessionState` (garde `assert` list/cramming) | `.../domain/z_linear_session_state.dart` | **consomme** |
| `ZWhiteExamSessionEngine` (`ZExamScoringPort`) | `.../domain/z_white_exam_session_engine.dart` | **consomme** |
| `ZSessionReviewer` (seam d'écriture UNIQUE) | `.../domain/z_session_reviewer.dart` | **relaie** — su-4 le branche enfin |
| `ZSessionItem` / `ZSessionState` | `.../domain/` | consomme |
| `ZFlashcardReviewCard` (6 types, `ZRevealTransition`, face défilable, contenu hissé en `child:`, slot AD-40 sous `IgnorePointer`) | `zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart` | **compose dans le `cardBuilder`** |
| `ZFlashcardAnswerInput`, `ZTimerDisplay`, `ZCardAdvanceBehavior` (+ `zDefaultAdvanceBehavior`) | `zcrud_session/lib/src/presentation/` | compose **en frère, hors pile** |
| `ZSrsQualityButtons` (+ `selectedQuality`, `ZQualityScale`) | `.../presentation/z_srs_quality_buttons.dart` | **la SEULE voie de notation** |
| `ZSessionQualityBreakdown`, `ZStudyProgressRings` | `.../presentation/` | ⚠️ cf. arbitrage A3 |
| `zReduceMotionOf` | `zcrud_flashcard` — **primitive UNIQUE du repo** | consomme — **jamais une 2ᵉ** |
| `ZSrsConfig` (`minQuality=0`, `maxQuality=5`, `passThreshold=3`, `clampQuality`) | `zcrud_flashcard/lib/src/domain/z_srs_config.dart` | consomme |
| Gardes **auto-énumérantes** (`lib/src/presentation/**` récursif) | `zcrud_session/test/presentation/z_widgets_purity_test.dart`, `z_widgets_hardcode_scan_test.dart` | **ton widget naît gardé — ÉTENDRE, jamais dupliquer** |
| Arène des gestes su-2/su-3 | `.../presentation/z_flashcard_gesture_arena_test.dart` | **étendre (acte III)** |
| Jeton de fraîcheur `_generation` | `.../presentation/z_flashcard_answer_input.dart:280` | **RÉUTILISER le patron** |

### Absences PROUVÉES par grep négatif (rejouables, RC cité)

```bash
cd /home/zakarius/DEV/zcrud

grep -rn "flutter_card_swiper" --include=pubspec.yaml --include="*.dart" . | grep -v "/build/"
# → RC=1 — la dépendance N'EXISTE NULLE PART. su-4 l'introduit.

grep -rn "ZSessionCardSwiper" packages/
# → RC=0, 1 SEULE occurrence : un COMMENTAIRE de su-2
#   (z_flashcard_review_card.dart:9 « le swipe appartient à su-4 »). AUCUN code. À créer.

grep -rn "Semantics" ~/.pub-cache/hosted/pub.dev/flutter_card_swiper-7.2.0/lib/
# → RC=1 — ZÉRO Semantics dans TOUT le paquet.
#   ⇒ le swipe est INVISIBLE à un lecteur d'écran ⇒ alternative accessible OBLIGATOIRE (AC9, AD-13).
```

---

## 🔴 AD-34 — l'état RÉEL, et ce que su-4 doit (et ne doit pas) faire

**Le spine dit** : « le seul trou résiduel est **symétrique** et doit être fermé :
`ZStudySessionEngine` accepte n'importe quel `ZReviewMode` ». **C'est PÉRIMÉ. su-1 l'a déjà fermé.**
Vérifié sur disque — `z_study_session_engine.dart:137-149` :

```dart
ZStudySessionEngine({ required List<ZSessionItem> queue, required ZSessionReviewer reviewer,
    ZSrsConfig config = const ZSrsConfig(), ZReviewMode mode = ZReviewMode.spaced })
  : assert(mode == ZReviewMode.spaced || mode == ZReviewMode.learn,
      'ZStudySessionEngine ne supporte que les modes SRS (spaced/learn) : ...'),
```

⇒ **su-4 N'AJOUTE PAS cette garde. Il la CONSOMME et prouve le mapping complet.**
Réécrire une garde déjà livrée serait une régression de duplication.

**Table AD-34 confrontée au disque (les 3 runtimes EXISTENT — `grep -rln "class ZStudySessionEngine\|class ZLinearSessionState\|class ZWhiteExamSessionEngine" packages/*/lib/` → 3 fichiers, RC=0) :**

| Mode | Runtime | Garde réelle sur disque | Reviewer ? |
|---|---|---|---|
| `spaced`, `learn` | `ZStudySessionEngine` | `assert(mode == spaced ‖ mode == learn)` (su-1) | **oui — le SEUL** |
| `list`, `cramming` | `ZLinearSessionState` | `assert(mode == list ‖ mode == cramming)` (l.147-153) | **aucun paramètre** ⇒ impossible |
| `test`, `whiteExam` | `ZWhiteExamSessionEngine` | **aucun paramètre `mode`** (ctor : `queue`, `config`, `scorer`) | **aucun paramètre** ⇒ impossible |

**`ZReviewMode` compte exactement 6 valeurs** (`z_review_mode.dart:26-44` : `spaced`, `learn`,
`list`, `test`, `whiteExam`, `cramming`). Aucune n'est orpheline.

**⚠️ Le régime d'écriture est une propriété du TYPE, jamais du `mode` passé en paramètre.**
`ZWhiteExamSessionEngine` n'a **pas** de paramètre `mode` : pour lui, la preuve est **structurelle**
(aucun seam à recevoir), pas assertive. Un test qui attendrait un `AssertionError` de sa part
échouerait — et aurait raison de le faire.

**🚫 Aucun `ZSessionReviewer` no-op n'est fourni** — ce serait la **porte dérobée** qu'AD-34 interdit
nommément (un mode non-SRS servi par le moteur SRS sous couvert d'un reviewer inerte). Dans les
tests, l'espion de reviewer est un espion qui **enregistre** (et dont on prouve qu'il n'est **jamais**
appelé), jamais un no-op offert à la prod.

---

## ⚠️ Frontières de périmètre (dures)

| ✅ su-4 | 🚫 PAS su-4 |
|---|---|
| `ZSessionCardSwiper` (pile + navigation) | Écran de fin de session, trophée, confetti, stats → **su-5** |
| Table `zSessionRuntimeForMode` + preuve du mapping | `ZSessionModeSelector`, streak, filtres test/examen → **su-6** |
| Indicateurs de progression (points / barre / émojis de drag) | UI d'examen blanc (`ZListSessionView`) → **su-7** |
| Branchement `ZSrsQualityButtons` → `ZSessionReviewer` | Liste de flashcards, filtres, ordre manuel → **su-8** |
| Dépendance `flutter_card_swiper` confinée | Toute création de moteur (AD-34) · toute écriture dans `zcrud_core` |

---

## Acceptance Criteria

### AC1 — `ZSessionCardSwiper` : la pile, et RIEN QUE la navigation
**Given** une file `List<ZSessionItem>` déjà sélectionnée (AD-33 : le widget ne sélectionne jamais)
**When** l'hôte monte `ZSessionCardSwiper`
**Then** le widget rend une pile de cartes via `flutter_card_swiper`
**And** son **API publique ne comporte AUCUN paramètre de qualité, de notation ou de reviewer** —
la notation est **structurellement impossible** depuis ce type (propriété du TYPE, AD-34/AD-33)
**And** aucun type `flutter_card_swiper` (`CardSwiper`, `CardSwiperDirection`, `CardSwiperController`,
`AllowedSwipeDirection`) n'apparaît dans une **signature publique** (AC10).

- **Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart` (NEW)
- **Test porteur** : `test/presentation/z_session_card_swiper_test.dart` — la pile se monte, la carte
  courante est rendue, la navigation avance l'index.
- **Test porteur (surface)** : `test/presentation/z_swipe_never_grades_test.dart` — garde de
  **source** dérivée : le fichier de `ZSessionCardSwiper` ne mentionne **jamais** `quality`,
  `reviewCard`, `ZSessionReviewer`, `ZSrsScheduler`, `apply(`, `grade(`.
- **Injection R3-I1** : ajouter un paramètre `onQualitySelected` au ctor et l'appeler depuis
  `onSwipe` ⇒ **la garde de source doit ROUGIR**.

### AC2 — Le swipe NAVIGUE ; il ne note JAMAIS
**Given** une session en cours, un `ZSessionReviewer` **espion** branché sur les `ZSrsQualityButtons`
**When** l'utilisateur swipe une carte (gauche **ou** droite)
**Then** l'index de la pile avance — `onIndexChanged` est émis **exactement une fois**
**And** **l'espion de reviewer n'est JAMAIS appelé** (0 appel) — la note reste aux
`ZSrsQualityButtons` (FR-SU6)
**And** un tap sur un `ZSrsQualityButtons` appelle l'espion **exactement une fois** (⇒ l'espion est
**capable** d'être appelé : la preuve n'est pas vide).

> 🔴 **Anti-tautologie — NON NÉGOCIABLE.** « L'espion n'est jamais appelé » est **vide** si l'espion
> ne peut de toute façon pas l'être. Le **même** espion, dans le **même** test, DOIT être appelé par
> la voie légitime (bouton de qualité). Sans ce témoin positif, le test reste vert même si le
> câblage entier a disparu — exactement le défaut « prouver la présence au lieu de l'association »
> (leçon HIGH su-2 / D6 su-3).

- **Test porteur** : `test/presentation/z_swipe_never_grades_test.dart`
- **Injection R3-I2** : câbler `onSwipe` sur `reviewer(quality: 5)` (le geste « Tinder-like » que la
  story interdit) ⇒ **ROUGE** (l'espion reçoit ≥ 1 appel).
- **Injection R3-I3** : débrancher `ZSrsQualityButtons` du reviewer ⇒ **ROUGE** (témoin positif à 0).

### AC3 — Les 6 modes sur les 3 runtimes EXISTANTS ; aucun moteur créé
**Given** les six valeurs de `ZReviewMode`
**When** une session est construite pour un mode
**Then** le mode est servi par le runtime que désigne la **table unique de prod**
`zSessionRuntimeForMode` (`spaced`/`learn` → `ZStudySessionEngine` ; `list`/`cramming` →
`ZLinearSessionState` ; `test`/`whiteExam` → `ZWhiteExamSessionEngine`)
**And** **aucun nouveau moteur n'est créé** (AD-34).

- **Fichier** : `packages/zcrud_session/lib/src/domain/z_session_runtime.dart` (NEW) —
  `enum ZSessionRuntimeKind { srsEngine, linear, whiteExam }` +
  `ZSessionRuntimeKind zSessionRuntimeForMode(ZReviewMode)` — **table UNIQUE**, `switch` exhaustif
  **sans `default`** (une 7ᵉ valeur de `ZReviewMode` casse la compilation). Patron identique à
  `zDefaultAdvanceBehavior` (su-3) : *« table unique, jamais redécidée par un widget »*.
- **Test porteur** : `test/z_session_runtime_mapping_test.dart` — **le test CONFRONTE la table aux
  constructeurs RÉELS**, il ne se contente pas de la relire :

  > 🔴 **Anti-tautologie — le cœur de cette AC.** Un test qui écrit
  > `expect(zSessionRuntimeForMode(ZReviewMode.list), ZSessionRuntimeKind.linear)` **ne prouve
  > rien** : il récite la table à elle-même (défaut démasqué en su-3 : *« fonction locale appelée
  > par le test »*, D11). Le test porteur **boucle sur `ZReviewMode.values`** (jamais une liste
  > figée) et, **pour chaque mode**, prouve l'**ACCORD entre la table et la réalité des types** :
  > 1. construire le runtime **désigné par la table** ⇒ **ne lève PAS** ;
  > 2. construire `ZStudySessionEngine` (le seul à recevoir un reviewer) avec un mode que la table
  >    n'y envoie **pas** ⇒ lève un **`AssertionError`** ;
  > 3. construire `ZLinearSessionState` avec un mode que la table n'y envoie **pas** ⇒
  >    **`AssertionError`** ;
  > 4. `ZWhiteExamSessionEngine` : preuve **structurelle** — son ctor n'a **ni** `mode` **ni**
  >    `reviewer` (⚠️ **ne pas** attendre d'`AssertionError` de sa part : il n'en lève aucune, et
  >    le prescrire ferait échouer le test à raison).
  >
  > Ainsi, faire diverger la table de la réalité rend le test **rouge des deux côtés**.

- **Test porteur (aucun moteur créé)** : garde **auto-énumérante** — scanner
  `zcrud_session/lib/src/domain/**` et extraire toute déclaration de classe dont le nom matche
  `Z.*(SessionEngine|SessionState)$` ; l'ensemble obtenu doit être **exactement**
  `{ZStudySessionEngine, ZLinearSessionState, ZWhiteExamSessionEngine}`. Un 4ᵉ runtime ⇒ **ROUGE**.
  🚫 **Jamais une garde ligne-à-ligne** ; 🚫 jamais une liste figée de fichiers.
- **Injection R3-I4** : dans la table, router `cramming → srsEngine` ⇒ **ROUGE** (l'`assert` réel de
  `ZStudySessionEngine` lève).
- **Injection R3-I5** : ajouter `class ZFakeSessionEngine {}` dans `lib/src/domain/` ⇒ **ROUGE**.

### AC4 — 🎯 AUCUN mode non-SRS n'atteint `reviewCard` (l'AC centrale — AD-33/AD-34)
**Given** un mode non-SRS (`list`, `cramming`, `test`, `whiteExam`)
**When** la session s'exécute **entièrement** (toutes les cartes parcourues, jusqu'à complétion)
**Then** **`reviewCard` n'est JAMAIS atteint** — 0 appel de l'espion `ZSessionReviewer`
**And** pour `spaced`/`learn`, une notation via `ZSrsQualityButtons` atteint `reviewCard`
**exactement une fois par carte notée** (témoin positif — même exigence qu'AC2).

- **Test porteur** : `test/z_no_srs_write_in_non_srs_modes_test.dart` — **session complète pilotée
  jusqu'à `isComplete`**, pas un seul tour de boucle.
- **Complémentarité — à ne PAS confondre** : `z_linear_no_srs_test.dart` (existant, su-1) est une
  garde de **SOURCE** (le fichier ne mentionne aucun symbole SRS). Le test d'AC4 est une garde de
  **COMPORTEMENT** (une exécution complète n'appelle rien). Les deux sont nécessaires : une garde
  de source ne prouve pas une exécution, une exécution ne prouve pas l'absence de porte dérobée.
  **Étendre l'existante, ne pas la dupliquer.**
- **Injection R3-I6** : brancher `ZLinearSessionState.advance` sur un reviewer (via un champ ajouté)
  ⇒ **ROUGE** (source **et** comportement).
- **Injection R3-I7** : retirer le témoin positif `spaced` ⇒ le test doit **rougir** (sinon la preuve
  est vide).

### AC5 — La notation reste aux `ZSrsQualityButtons`, branchée sur le seam
**Given** une carte notée par l'apprenant via `ZSrsQualityButtons`
**When** une qualité est choisie
**Then** `ZSessionReviewer` est invoqué **exactement une fois** avec
`(flashcardId, folderId, quality, now)` de la carte **COURANTE**
**And** la qualité est passée par `ZSrsConfig.clampQuality` — **unique voie de clamp (AD-46)** ;
aucune borne (`0`, `5`, `3`) n'est recopiée en littéral
**And** sur `Left` (échec du seam), la file **n'avance pas** et l'échec est **exposé**, jamais avalé
(AD-5/AD-10).

- **Test porteur** : `test/presentation/z_session_grading_test.dart`
- **Injection R3-I8** : remplacer `config.clampQuality(q)` par `q.clamp(0, 5)` ⇒ **ROUGE** (test
  paramétré sur un `ZSrsConfig` **non standard**, p.ex. `maxQuality: 4` — sinon les deux voies
  coïncident et le test reste vert à tort : *le clamp littéral n'est démasqué que par une échelle
  qui diverge du défaut*).
- **Injection R3-I9** : avancer la file avant l'`await` du seam ⇒ **ROUGE** (`Left` → file figée).

### AC6 — 🎯 L'ARÈNE DES GESTES, ACTE III (drag ∥ tap ∥ saisie ∥ scroll)
**Given** l'assemblage RÉEL — `ZSessionCardSwiper` (contenant `ZFlashcardReviewCard`) **frère** de
`ZFlashcardAnswerInput` et `ZSrsQualityButtons` — sur le **chemin markdown EXACT**
(`contentBuilder: ZFlashcardMarkdownContent.builder()`)
**When** l'utilisateur exerce chacun des quatre gestes
**Then** chacun atteint **sa** cible et **aucune autre** :

| Geste | Cible | Doit se produire | Doit **ne pas** se produire |
|---|---|---|---|
| **tap** sur la carte | `InkWell` (su-2) | `onRevealChanged` émis | l'index n'avance pas |
| **drag horizontal** sur la carte | `CardSwiper` | l'index avance | `onRevealChanged` non émis ; reviewer à 0 |
| **saisie** dans le champ (tap + frappe) | `ZFlashcardAnswerInput` | le texte est saisi | l'index n'avance pas |
| **drag vertical** sur la face défilable | `Scrollable` (su-2) | la face défile | l'index n'avance pas |

- **Test porteur** : **ÉTENDRE** `test/presentation/z_flashcard_gesture_arena_test.dart` (acte III) —
  🚫 ne pas créer un `z_swipe_arena_test.dart` parallèle qui divergerait avec le temps (leçon su-3 :
  *« su-3 la DURCIT au lieu d'en créer une parallèle »*).
- **Chemin markdown OBLIGATOIRE** : le fichier existant le dit verbatim — *« c'est le seul qui
  pouvait démasquer D1, et le seul qui peut démasquer sa réapparition »*. Un test sur le chemin
  texte simple **ne prouve rien** de cette arène.
- **Témoin observable** : réutiliser l'astuce du fichier existant (`onQualitySelected` non nul ⇒ la
  rangée SRS devient un **témoin** de « une correction a eu lieu »). Ne pas chercher un nœud **par
  le libellé qu'on vérifie**.
- 🚫 **INTERDIT** : retirer l'`IgnorePointer` de su-2 pour « régler » l'arène.
- **Injections R3-I10a..d** : neutraliser tour à tour chaque cible attendue (p.ex. descendre
  `ZFlashcardAnswerInput` **dans** le `cardBuilder`) ⇒ **ROUGE**. En particulier **R3-I10c** : placer
  le champ de saisie sous le pan ⇒ le drag doit voler la saisie ⇒ **ROUGE**.

### AC7 — NFR-SU2 : la pile ne se reconstruit pas entièrement pendant le drag
**Given** une pile montée, une sonde de comptage de builds placée **À L'INTÉRIEUR du contenu de la
carte** (dans le `contentBuilder`, sous-arbre de `ZFlashcardReviewCard`)
**When** l'utilisateur effectue un drag complet (multiples `pointer.moveBy`)
**Then** le contenu de carte **n'est pas reconstruit** — le compteur reste à sa valeur initiale
**And** l'overlay d'indicateur émotionnel, lui, **se met bien à jour** pendant le drag (⇒ la preuve
n'est pas « rien ne bouge »).

- **Conception imposée** : `onPanUpdate` appelle `setState` ⇒ `cardBuilder` **EST** ré-invoqué à
  chaque frame (fait vérifié sur disque). La granularité s'obtient donc en rendant l'invocation
  **inoffensive** : `ZSessionCardSwiper` **mémoïse l'instance de widget de carte par index** et la
  renvoie **à l'identique** (`identical(w1, w2) == true`) ⇒ `Element.update` court-circuite le
  sous-arbre. L'overlay émoji est un **frère** dans un `Stack`, seul à dépendre de
  `horizontalOffsetPercentage`. Patron **hérité de su-2** (contenu hissé en `child:`).
  - Invalider le cache **uniquement** sur changement réel de la file/carte (`didUpdateWidget`).
- 🔴 **Anti-défaut (leçon su-3 : « sonde mesurant un sibling »)** : la sonde compte les builds **du
  contenu de la carte**, pas d'un widget voisin. Une sonde placée à côté de la carte mesurerait
  autre chose et resterait verte à tort.
- **Test porteur** : `test/presentation/z_session_card_swiper_sm1_test.dart`
- **Injection R3-I11** : supprimer la mémoïsation (reconstruire le widget de carte à chaque appel du
  `cardBuilder`) ⇒ **ROUGE** (le compteur grimpe avec les frames).

### AC8 — Indicateurs de progression et émojis de drag (enums, jamais des booléens)
**Given** une session en **mode lot N** puis en **mode complet**
**When** la progression avance
**Then** l'indicateur est respectivement **points colorés par qualité** et **barre segmentée**
**And** les **indicateurs émotionnels** apparaissent **pendant le drag**
**And** ils sont **statiques si Reduce Motion** (NFR-SU3).

- **Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart` (NEW)
  — `enum ZSessionProgressStyle { dots, segmentedBar }`. **Jamais un `bool isBatch`.**
- **Couleurs/labels INJECTÉS** : réutiliser le patron `colorKeyFor`/`labelKeyFor` de
  `ZSrsQualityButtons`/`ZSessionQualityBreakdown` (`zDefaultQualityLabelKey`). **Zéro `Colors.*`,
  zéro `Color(0x…)`, zéro libellé en dur** — la garde auto-énumérante `z_widgets_hardcode_scan_test`
  capte le nouveau fichier **sans édition** (R16).
- **Émojis de drag** : source IFFD (lecture seule) ; pilotés par `horizontalOffsetPercentage`
  (fourni par `cardBuilder`) ; overlay sous `IgnorePointer` (il ne doit **rien** voler à l'arène).

#### 🔴 Reduce Motion — l'animation doit EXISTER VRAIMENT
> **Leçon su-3 / D8 — le piège exact à ne pas retomber dedans.** su-3 a dû **retirer** un
> `AnimatedOpacity(opacity: 1)` qui n'animait rien : l'appel à `zReduceMotionOf` y était
> **décoratif**, le test **tautologique**, et le tout **invraisemblablement vert**.
> Ici, la dégradation doit être **RÉELLE et MESURABLE** :
> - **Sans** Reduce Motion : l'indicateur émotionnel varie **continûment** avec l'offset du drag
>   (opacité et/ou échelle = fonction de `horizontalOffsetPercentage`).
> - **Avec** Reduce Motion : **fonction préservée, animation supprimée** — apparition **binaire au
>   seuil**, opacité et échelle **fixes**, aucune interpolation. L'indicateur **apparaît toujours**
>   (jamais de dégradation de la FONCTION, seulement de l'ANIMATION — règle su-2/AC3).
> - **Second point d'application** : la `duration` du `CardSwiper` (défaut **200 ms**, animation de
>   retour/envol bien réelle) ⇒ `Duration.zero` sous Reduce Motion.
>
> **Test porteur** : pomper le **même** drag à **deux offsets distincts** (p.ex. 20 % et 60 %) et
> comparer les valeurs **résolues** (opacité/échelle lues sur le widget, pas déduites) :
> - sans RM ⇒ les deux valeurs **DIFFÈRENT** ;
> - avec RM ⇒ les deux valeurs sont **IDENTIQUES**, et l'émoji est bien **présent** au-delà du seuil.
>
> **Injection R3-I12** : faire retourner à la branche RM la valeur interpolée (dégradation
> supprimée) ⇒ **ROUGE**. Si cette injection **ne rougit pas**, l'appel à `zReduceMotionOf` est
> **décoratif** : le signaler et le **retirer** plutôt que de conserver un test tautologique.
- **Test porteur** : `test/presentation/z_session_progress_indicator_test.dart`,
  `test/presentation/z_session_swipe_reduce_motion_test.dart`

### AC9 — A11y : le swipe n'est PAS accessible ⇒ alternative obligatoire (AD-13)
**Given** un lecteur d'écran actif
**When** l'apprenant veut avancer dans la pile
**Then** une **alternative accessible** existe : contrôles de navigation **≥ 48 dp**, `Semantics`
explicites et **localisés** (`ZcrudLabels`, jamais un libellé en dur), pilotant la pile via le
contrôleur du swiper
**And** la progression est annoncée (`Semantics(value:)` — l'**association**, pas la présence)
**And** les variantes **directionnelles** sont utilisées partout (`EdgeInsetsDirectional`,
`AlignmentDirectional`, `TextAlign.start/end`) — RTL.

- **Justification factuelle** : `grep -rn "Semantics" ~/.pub-cache/.../flutter_card_swiper-7.2.0/lib/`
  → **RC=1**. Le paquet n'expose **aucune** sémantique : sans alternative, la pile est **inutilisable**
  au lecteur d'écran. Ce n'est pas une précaution, c'est un **trou mesuré**.
- **Moyen** : `CardSwiperController` (API réelle vérifiée : `swipe(direction)`, `undo()`,
  `moveTo(index)`, `dispose()`) — **confiné** au fichier du swiper, **jamais** en signature publique
  (AC10). ⚠️ `dispose()` est `Future<void>` **et le contrôleur est possédé par `ZSessionCardSwiper`**
  ⇒ créer/disposer dans `initState`/`dispose` (jamais dans `build`).
- **Test porteur** : `test/presentation/z_session_card_swiper_a11y_test.dart` — cibles ≥ 48 dp
  (`tester.getSize`), `Semantics` **associés au bon nœud**, navigation par bouton ⇒ index avance.
- 🔴 **Anti-défaut (leçon su-2/HIGH, su-3/D6b)** : ne pas chercher un nœud **par le libellé qu'on
  vérifie** ; prouver l'**association** (`Semantics.value` porté par le nœud de progression), pas la
  simple présence d'une chaîne quelque part dans l'arbre.
- **Injection R3-I13** : retirer le `Semantics(value:)` de la progression ⇒ **ROUGE**.
- **Injection R3-I14** : ramener une cible à 40 dp ⇒ **ROUGE**.

### AC10 — `flutter_card_swiper` CONFINÉ à `zcrud_session` (NFR-SU7, AD-1/AD-8)
**Given** le monorepo
**When** les gates sont rejoués
**Then** `flutter_card_swiper: ^7.2.0` n'est déclaré que dans `packages/zcrud_session/pubspec.yaml`
**And** **aucun** autre package ne l'importe (en particulier **jamais** `zcrud_core` ni
`zcrud_flashcard`)
**And** au sein de `zcrud_session`, l'import est confiné à **`z_session_card_swiper.dart`** — le
barrel `zcrud_session.dart` ne l'exporte ni ne le réexporte
**And** aucun type du paquet n'apparaît dans une **signature publique**
**And** `melos run analyze` **repo-wide** et `melos run verify` sont **verts**.

- **Test porteur** : `test/z_card_swiper_confinement_test.dart` (NEW) — patron
  `zcrud_export/test/isolation_gates_test.dart` : **allowlist DÉRIVÉE dynamiquement** (les `.dart` de
  `lib/` qui importent le paquet), fichiers publics **dérivés** (tous les `.dart` de `lib/` **sauf**
  ceux de l'allowlist), lecture **cwd-robuste** (candidats `path` puis `../../path`).
- 🔴 **Portée déclarée honnêtement** (leçon E10 : *« un garde ne prouve QUE ce qu'il scanne »*) : ce
  test scanne `zcrud_session` **et** les `pubspec.yaml` de `packages/*` (déclaration de la
  dépendance). Il **ne scanne pas** les sources des autres packages — c'est `melos run analyze`
  repo-wide + `graph_proof` qui couvrent le reste. **Écrire cette portée dans l'en-tête du test**,
  ne pas laisser croire qu'il prouve plus.
- **Injections R3-I15** : (a) déclarer `flutter_card_swiper` dans `packages/zcrud_flashcard/pubspec.yaml`
  ⇒ **ROUGE** ; (b) exposer `CardSwiperDirection` dans une signature publique ⇒ **ROUGE** ;
  (c) importer le paquet depuis un 2ᵉ fichier de `lib/` ⇒ **ROUGE**.

### AC11 — Robustesse AD-10 : les asserts de `CardSwiper` sont des CRASH RÉELS
**Given** une file de **0** carte, puis de **1** carte
**When** `ZSessionCardSwiper` est monté
**Then** **aucune exception n'est levée** — repli défini, jamais un crash.

> 🔴 **Ce ne sont pas des cas théoriques — les asserts sont dans le ctor, lus sur disque**
> (`card_swiper.dart`) :
> ```dart
> assert(numberOfCardsDisplayed >= 1 && numberOfCardsDisplayed <= cardsCount, ...)  // défaut = 2
> assert(initialIndex >= 0 && initialIndex < cardsCount, ...)
> ```
> - **file vide (`cardsCount = 0`)** ⇒ **les DEUX asserts lèvent** ⇒ `ZSessionCardSwiper` **ne doit
>   PAS construire `CardSwiper`** : rendre un **repli d'état vide** (slot injectable, labels
>   localisés).
> - **file d'UNE carte (`cardsCount = 1`)** ⇒ `numberOfCardsDisplayed` **défaut 2 > 1** ⇒ **assert
>   lève** ⇒ **crash sur une session parfaitement normale.** Correctif obligatoire :
>   `numberOfCardsDisplayed: math.min(2, queue.length)`.
> - **`isLoop` (défaut `true`)** ⇒ une file de session **boucle indéfiniment** : la session ne se
>   termine jamais. Obligatoire : **`isLoop: false`**. (`onEnd` n'est appelé que sur la **dernière**
>   carte, après `onSwipe` — vérifié dans `_handleCompleteSwipe`.)

- **Test porteur** : `test/presentation/z_session_card_swiper_fallback_test.dart` — file **vide** ⇒
  repli rendu, **zéro exception** ; file d'**une** carte ⇒ montée sans exception, swipe ⇒ fin de pile.
- **Injections R3-I16** : (a) rétablir `numberOfCardsDisplayed: 2` en dur ⇒ **ROUGE** sur la file
  d'une carte ; (b) construire `CardSwiper` sur file vide ⇒ **ROUGE** ; (c) `isLoop: true` ⇒ **ROUGE**
  (la pile ne se termine jamais).
- 🔴 **Anti-défaut (leçon su-3 : « branche de repli JAMAIS atteinte »)** : le test doit **atteindre**
  le repli et **l'observer**, pas seulement constater l'absence d'exception.

### AC12 — Concurrence : le patron `_generation` est RÉUTILISÉ, jamais réinventé
**Given** les fenêtres asynchrones réelles de l'assemblage
**When** l'un des scénarios ci-dessous se produit
**Then** aucun effet ne se pose sur la **mauvaise carte**, et rien n'est compté deux fois :

| Scénario | Exigence |
|---|---|
| **swipe pendant un appel de port EN VOL** (évaluation su-3) | l'évaluation périmée n'atteint **jamais** la nouvelle carte ; **0 note** écrite pour elle |
| **double-swipe** (deux gestes en succession rapide) | l'index avance de **1 par carte** ; `onIndexChanged` **jamais** émis deux fois pour le même index |
| **swipe pendant une soumission** (`onSubmitted` en vol) | la soumission de la carte A n'est **jamais** attribuée à la carte B |
| **carte changée sous un `then`** | le résultat périmé est **ignoré** (jeton de fraîcheur) |

- 🔴 **`onSwipe` est `FutureOr<bool>` et il est `await`é** — vérifié sur disque :
  ```dart
  final shouldCancelSwipe = await widget.onSwipe?.call(_currentIndex!, _nextIndex, _detectedDirection) == false;
  ```
  ⇒ un `onSwipe` asynchrone **ouvre une fenêtre** pendant laquelle la file peut changer. C'est la
  **même racine** que le D1 MAJEUR de su-3.
- **Patron OBLIGATOIRE — réutiliser, ne pas réinventer** : le jeton `_generation` de
  `z_flashcard_answer_input.dart:280` — capturé **AVANT** l'`await`, incrémenté dans
  `_resetForNewCard()`/`didUpdateWidget`, comparé **après** l'`await`. Sa dartdoc dit déjà pourquoi :
  *« en su-4 (`onSubmitted` branché sur `ZSessionReviewer.reviewCard`), c'est un SRS faux écrit sur
  la mauvaise carte, par la voie légitime »*. **su-4 est le moment où ce risque devient réel.**
- **Test porteur** : `test/presentation/z_session_swipe_concurrency_test.dart` — port/seam à
  `Completer` contrôlé (jamais un `Future.delayed` au hasard).
- **Injections R3-I17** : (a) retirer la capture du jeton avant l'`await` ⇒ **ROUGE** ; (b) retirer le
  verrou one-shot de `onIndexChanged` ⇒ **ROUGE** (double émission).

---

## Spécifications techniques — contrat à livrer

> ⚠️ Signatures **indicatives sur la forme**, **contraignantes sur les invariants** (absence de
> paramètre de notation, types tiers hors API publique, enums). Le dev **DOIT** relire les sources
> réelles (`~/.pub-cache/.../flutter_card_swiper-7.2.0/lib/src/widget/card_swiper_state.dart`)
> avant d'écrire.

```dart
// packages/zcrud_session/lib/src/domain/z_session_runtime.dart  (NEW)

/// Régime d'écriture d'un runtime de session — propriété du TYPE (AD-34).
enum ZSessionRuntimeKind { srsEngine, linear, whiteExam }

/// TABLE UNIQUE mode → runtime (AD-34). Jamais redécidée par un widget.
/// `switch` exhaustif SANS `default` : une 7ᵉ valeur de `ZReviewMode` casse la compilation.
ZSessionRuntimeKind zSessionRuntimeForMode(ZReviewMode mode) => switch (mode) {
      ZReviewMode.spaced || ZReviewMode.learn => ZSessionRuntimeKind.srsEngine,
      ZReviewMode.list || ZReviewMode.cramming => ZSessionRuntimeKind.linear,
      ZReviewMode.test || ZReviewMode.whiteExam => ZSessionRuntimeKind.whiteExam,
    };
```

```dart
// packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart  (NEW)

/// Pile de session swipeable — le swipe est une NAVIGATION (FR-SU6).
///
/// 🚫 AUCUN paramètre de qualité / de notation / de reviewer : la notation est
/// STRUCTURELLEMENT impossible depuis ce type (AD-33/AD-34). Elle appartient aux
/// `ZSrsQualityButtons`, composés en FRÈRE par l'hôte — HORS de la pile.
class ZSessionCardSwiper extends StatefulWidget {
  const ZSessionCardSwiper({
    required this.queue,                 // file DÉJÀ sélectionnée (AD-33)
    required this.cardBuilder,           // (context, item) → carte d'AFFICHAGE (su-2)
    this.onIndexChanged,                 // navigation SEULE
    this.onStackEnd,                     // fin de pile (l'écran de fin = su-5)
    this.emptyBuilder,                   // repli file vide (AD-10, AC11)
    this.progressStyle = ZSessionProgressStyle.dots,
    this.swipeDuration = const Duration(milliseconds: 200),
    super.key,
  });
  // ...
}
```

**Réglages de `CardSwiper` IMPOSÉS (chacun adossé à un fait vérifié sur disque) :**

| Réglage | Valeur | Pourquoi |
|---|---|---|
| `isLoop` | **`false`** | défaut `true` ⇒ la session ne se termine jamais (AC11) |
| `numberOfCardsDisplayed` | **`math.min(2, queue.length)`** | défaut `2` ⇒ **assert ⇒ crash** sur une file d'1 carte (AC11) |
| `cardsCount` | `queue.length`, **jamais 0** | `cardsCount = 0` ⇒ 2 asserts ⇒ crash ; repli avant construction (AC11) |
| `duration` | `zReduceMotionOf(context) ? Duration.zero : swipeDuration` | animation **réelle** de 200 ms (AC8) |
| `allowedSwipeDirection` | `AllowedSwipeDirection.symmetric(horizontal: true)` | ⚠️ **ne filtre QUE la fin de geste** — n'empêche **pas** le pan de revendiquer le vertical (§ arène) |
| `onSwipe` | **navigation seule** → `onIndexChanged` | 🚫 jamais mappé sur une qualité (AC2) ; `await`é ⇒ jeton de fraîcheur (AC12) |
| `onEnd` | → `onStackEnd` | n'est appelé que sur la **dernière** carte, **après** `onSwipe` |

**RTL** : `CardSwiperDirection.left/right` sont **physiques**. Puisque le swipe est une **navigation
seule**, **les deux directions horizontales font avancer** — aucune sémantique gauche/droite n'est
attachée. Cela **dissout** la question RTL *et* supprime la tentation « gauche = raté / droite =
réussi » que FR-SU6 interdit. **Arbitrage A2, tranché.**

---

## Tasks / Subtasks

- [x] **T1 — Dépendance confinée** (AC10)
  - [x] `flutter_card_swiper: ^7.2.0` dans `packages/zcrud_session/pubspec.yaml` **uniquement** ;
        commentaire d'arête (patron `zcrud_mindmap`/`graphite`) : pourquoi ici, pourquoi nulle part ailleurs
  - [x] `dart pub get` ; `test/z_card_swiper_confinement_test.dart` (allowlist **dérivée**, portée déclarée)
  - [x] `melos run analyze` **repo-wide** + `melos run verify` verts
- [x] **T2 — Table des runtimes** (AC3) — `z_session_runtime.dart` + export barrel ; `switch` exhaustif sans `default`
- [x] **T3 — Preuve du mapping** (AC3, AC4) — boucle sur `ZReviewMode.values` ; confrontation table ↔ ctors réels ;
      garde auto-énumérante « exactement 3 runtimes » ; **session complète** en mode non-SRS ⇒ 0 appel du seam ;
      témoin positif `spaced`
- [x] **T4 — `ZSessionCardSwiper`** (AC1, AC11) — pile, réglages imposés, repli file vide, contrôleur possédé
      (`initState`/`dispose`), **aucun** paramètre de notation
- [x] **T5 — Mémoïsation par index** (AC7) — instance de carte `identical` entre frames ; invalidation sur
      `didUpdateWidget` ; sonde **dans** le contenu de carte
- [x] **T6 — Navigation ≠ notation** (AC2, AC5) — `onSwipe` → `onIndexChanged` ; `ZSrsQualityButtons` → seam ;
      `clampQuality` (AD-46) ; `Left` ⇒ file figée ; garde de source
- [x] **T7 — Arène acte III** (AC6) — **étendre** `z_flashcard_gesture_arena_test.dart`, chemin **markdown**,
      4 gestes × cible unique ; consigner le **verdict mesuré** des deux prédictions
- [x] **T8 — Indicateurs** (AC8) — `ZSessionProgressIndicator` + `ZSessionProgressStyle` ; émojis pilotés par
      l'offset, sous `IgnorePointer` ; couleurs/labels injectés
- [x] **T9 — Reduce Motion RÉEL** (AC8) — `duration: Duration.zero` ; émoji **statique** (2 offsets ⇒ valeurs
      identiques) ; **si R3-I12 ne rougit pas ⇒ retirer l'appel décoratif et le consigner**
- [x] **T10 — A11y/RTL** (AC9) — alternative ≥ 48 dp, `Semantics(value:)` **associé**, labels `ZcrudLabels`,
      API directionnelles
- [x] **T11 — Concurrence** (AC12) — jeton `_generation` **réutilisé** ; one-shot `onIndexChanged` ;
      `Completer` contrôlés
- [x] **T12 — Vérif verte + R3** — `flutter test` **par package** ; **17 injections** rejouées, rouge **mesuré**,
      table des écarts

---

## Stratégie de test

### ⚠️ `melos run test` est INUTILISABLE (parallélise, se bloque) — `flutter test` PAR PACKAGE

```bash
cd /home/zakarius/DEV/zcrud/packages/zcrud_session  && flutter test   # baseline 244
cd /home/zakarius/DEV/zcrud/packages/zcrud_flashcard && flutter test   # baseline 399
cd /home/zakarius/DEV/zcrud && dart run melos run analyze              # repo-wide, RC=0
cd /home/zakarius/DEV/zcrud && dart run melos run verify               # gates
```

**Baseline vérifiée sur disque le 2026-07-17** : `zcrud_session` → **`00:07 +244: All tests passed!`**
(rejoué réellement). Référence repo : **23/23 packages, 3923 tests** ; `zcrud_flashcard` **399**.
su-4 ne touche `zcrud_flashcard` **qu'en lecture** ⇒ ses 399 doivent rester **inchangés**.

### Discipline R3 — un test qui ne rougit pas ne prouve rien

**17 injections prescrites** (R3-I1..I17). Chacune : appliquer sur le disque, **mesurer** le rouge,
**restaurer**. Consigner `+n -m` réels. 🚫 **On ne modifie JAMAIS un test pour taire un défaut réel.**

### 🔴 Défauts déjà démasqués dans cet epic — interdits de récidive

| Défaut | Où il a frappé | Le piège **de su-4** |
|---|---|---|
| Test **tautologique** (fonction locale appelée par le test) | su-3/D11 | réciter `zSessionRuntimeForMode` au lieu de la **confronter aux ctors** (AC3) |
| **Animation factice** ⇒ test invraisemblablement vert | su-3/D8 | un émoji « statique » qui n'était **jamais** animé (AC8) |
| Preuve de **présence** au lieu d'**association** | su-2/HIGH, su-3/D6b | `Semantics` présent quelque part ≠ porté par le **bon nœud** (AC9) |
| Sonde mesurant un **sibling** | su-3 | compter les builds **à côté** de la carte (AC7) |
| Branche de repli **jamais atteinte** | su-3 | file vide « sans exception » **sans observer** le repli (AC11) |
| Garde **ligne-à-ligne** / liste figée | E10, E11a | énumérer les runtimes en dur au lieu de scanner (AC3) |
| Contre-preuve qui **ré-implémente** le scanner | E11a | réécrire le confinement dans le test (AC10) |
| Nœud cherché **par le libellé qu'on vérifie** | su-2 | (AC6, AC9) |
| **Absence** affirmée sans grep négatif | transverse | toute absence ⇒ commande + RC |

---

## Dev Notes

### Contraintes AD applicables
**AD-1** graphe acyclique, CORE OUT=0, dépendance tierce **confinée** · **AD-2/AD-15** pur-Flutter,
zéro gestionnaire d'état · **AD-5/AD-10** `Either`, jamais d'exception, replis définis ·
**AD-13** RTL, `Semantics`, ≥ 48 dp, l10n/thème injectés · **AD-33** sélection amont, écriture SRS par
seam unique · **AD-34** un runtime par régime, **aucun créé** · **AD-40** slot de rendu riche ·
**AD-46** échelle possédée par `ZSrsConfig`, `clampQuality` unique voie.

### Key Don'ts (spécifiques à su-4)
- 🚫 **Never** mapper un swipe (ou une direction) sur une qualité — le swipe **navigue** (FR-SU6).
- 🚫 **Never** créer un 4ᵉ runtime, ni « adapter » un runtime existant à un mode qu'il refuse (AD-34).
- 🚫 **Never** fournir un `ZSessionReviewer` **no-op** en prod — la porte dérobée nommée par AD-34.
- 🚫 **Never** ajouter la garde de mode à `ZStudySessionEngine` — **su-1 l'a déjà livrée** (l.142-149).
- 🚫 **Never** descendre `ZFlashcardAnswerInput`/`ZSrsQualityButtons` dans le `cardBuilder`.
- 🚫 **Never** retirer l'`IgnorePointer` de su-2 pour « régler » l'arène (correctif d'un HIGH réel).
- 🚫 **Never** créer une 2ᵉ primitive Reduce Motion — `zReduceMotionOf` est **unique dans le repo**.
- 🚫 **Never** créer une garde parallèle à `z_widgets_purity_test` / `z_widgets_hardcode_scan_test` /
  `z_flashcard_gesture_arena_test` / `z_linear_no_srs_test` — **les ÉTENDRE**.
- 🚫 **Never** laisser un type `flutter_card_swiper` dans une signature publique.
- 🚫 **Never** `Colors.*` / `Color(0x` / libellé en dur / `EdgeInsets.only(left:` / `ListView(children:)`.
- 🚫 **Never** `git checkout` dans cet arbre — **su-1..su-3 ne sont PAS committés** ; un checkout les
  détruit (**c'est arrivé** : cf. code-review-su-3, « Incident `git checkout` »).
- 🚫 **Never** committer au milieu de la story (commit en **fin d'epic**).

### Project Structure Notes
```
packages/zcrud_session/
  pubspec.yaml                                   ← MODIFIÉ : + flutter_card_swiper ^7.2.0 (SEUL point)
  lib/zcrud_session.dart                         ← MODIFIÉ : exports (aucun type tiers)
  lib/src/domain/z_session_runtime.dart          ← NEW  (table AD-34)
  lib/src/presentation/z_session_card_swiper.dart        ← NEW  (SEUL import du paquet tiers)
  lib/src/presentation/z_session_progress_indicator.dart ← NEW
  test/z_session_runtime_mapping_test.dart               ← NEW
  test/z_no_srs_write_in_non_srs_modes_test.dart         ← NEW
  test/z_card_swiper_confinement_test.dart               ← NEW
  test/presentation/z_session_card_swiper_test.dart      ← NEW
  test/presentation/z_swipe_never_grades_test.dart       ← NEW
  test/presentation/z_session_grading_test.dart          ← NEW
  test/presentation/z_session_card_swiper_sm1_test.dart  ← NEW
  test/presentation/z_session_card_swiper_a11y_test.dart      ← NEW
  test/presentation/z_session_card_swiper_fallback_test.dart  ← NEW
  test/presentation/z_session_progress_indicator_test.dart    ← NEW
  test/presentation/z_session_swipe_reduce_motion_test.dart   ← NEW
  test/presentation/z_session_swipe_concurrency_test.dart     ← NEW
  test/presentation/z_flashcard_gesture_arena_test.dart  ← ÉTENDU (acte III)
```
`packages/zcrud_flashcard/**` : **LECTURE SEULE**. `pubspec.yaml` **racine** : **inchangé** (le bloc
`workspace:` n'énumère que les packages ; aucun nouveau package n'est créé).
`/home/zakarius/DEV/iffd` et `lex_ui` : **LECTURE SEULE** (source best-of-breed des émojis de drag).

### Ambiguïtés relevées & arbitrages (mode non interactif — option la plus conservatrice)

| # | Ambiguïté | Arbitrage | Motif |
|---|---|---|---|
| **A1** | Le spine exige la garde symétrique AD-34 sur `ZStudySessionEngine` | **NE PAS l'ajouter — su-1 l'a livrée** (vérifié l.142-149). su-4 la **consomme** et **prouve le mapping** | Le spine décrit un état **antérieur** à su-1. Ré-ajouter = duplication |
| **A2** | `CardSwiperDirection.left/right` : sémantique en RTL ? | **Les deux directions AVANCENT** — aucune sémantique directionnelle | Dissout le RTL **et** supprime la tentation « gauche = raté » qu'interdit FR-SU6 |
| **A3** | `ZSessionQualityBreakdown` (existant) ≈ « barre segmentée » ? | **Distinct** : le breakdown agrège **par qualité**, l'indicateur su-4 est **par carte** (position). ⚠️ Le dev **DOIT relire** `z_session_quality_breakdown.dart` et **justifier** dans le Dev Agent Record ; si le recouvrement est réel ⇒ **réutiliser**, jamais dupliquer | Anti-réinvention |
| **A4** | Émoji « statique » sous Reduce Motion = quoi exactement ? | **Apparition binaire au seuil, opacité/échelle fixes, aucune interpolation** — l'émoji **apparaît toujours** | Dégrader l'**animation**, jamais la **fonction** (règle su-2/AC3) |
| **A5** | Que faire si l'arène infirme une prédiction (AC6) ? | Corriger **au niveau de la composition** ; **jamais** en touchant l'`IgnorePointer` de su-2 ni en assouplissant un test ; **consigner le mesuré** | Le raisonnement sur l'arène **n'est pas une preuve** |
| **A6** | `onIndexChanged` : émettre aussi sur navigation programmatique (a11y) ? | **Oui** — une seule voie d'émission pour les deux origines | Une 2ᵉ voie = 2 comptages divergents |
| **A7** | Où finit su-4 sur la fin de pile ? | `onStackEnd` **émis**, **aucune UI** de fin | L'écran de fin est **su-5** |

### Previous Story Intelligence
- **su-1** (`done`) : garde de mode AD-34 livrée sur `ZStudySessionEngine` ; `z_linear_no_srs_test`.
- **su-2** (`review`/vert) : **HIGH réel** — `QuillEditor` volait le tap sous **328/328 verts** ⇒
  `IgnorePointer`. Leçon : *prouver l'**association**, pas la présence*. Contenu **hissé en `child:`**
  (patron de mémoïsation réutilisé en AC7).
- **su-3** (`review`/vert, 244 tests) : **4 MAJEURS, 8 MEDIUM** — `_generation` (D1), verrou one-shot
  (D2), `didUpdateWidget` (D3/D4/D13), `zReduceMotionOf` **décoratif** (D8, code mort **retiré**),
  2 tables divergentes (D11), **16/16 injections rouges**. su-3 a **dissous** l'arène (surfaces
  frères) — **su-4 hérite de cette architecture, il ne la rejoue pas.**
- **Incident consigné** : un `git checkout` a détruit du travail non committé. **Ne pas répéter.**

### Git Intelligence
`git status` : su-1..su-3 **non committés** (arbre de travail). Dernier commit : `9ea262f chore(release):
bump 0.2.0 → 0.2.1`. Convention : **commit unique en fin d'epic**, `*.g.dart` de `packages/*/lib/`
inclus (su-4 n'en génère **aucun** : `zcrud_session` n'a aucun `@ZcrudModel` — gate
`codegen-distribution` sans objet), `pubspec.lock` **exclus**.

### Latest Tech — `flutter_card_swiper` 7.2.0 (LU sur disque, non supposé)
Présent en pub-cache (`7.0.2` **et** `7.2.0`) — **épingler `^7.2.0`**. `sdk: >=3.0.0 <4.0.0`,
`flutter: >=1.17.0` — compatible (`environment.sdk: ^3.12.2`). **13 fichiers**, dépendance unique :
`flutter`. **API réelle** : `CardSwiper` (ctor ci-dessus), `CardSwiperController`
(`swipe`/`undo`/`moveTo`/`dispose` → `Future<void>`), `CardSwiperDirection` (`left`/`right`/`top`/
`bottom`/`none`, **physiques**), `AllowedSwipeDirection` (`.all()`/`.none()`/`.only()`/`.symmetric()`),
`NullableCardBuilder(context, index, horizontalOffsetPercentage, verticalOffsetPercentage)`,
`CardSwiperOnSwipe → FutureOr<bool>` (**`false` annule le swipe**), `enum SwipeType`, `enum UndoDirection`.
**Zéro `Semantics` dans tout le paquet** (RC=1) ⇒ AC9.

### References
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.4`]
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-33`, `#AD-34`, `#AD-46`, `#Placement des paquets`, `#Conventions`]
- [Source: `epics.md#Requirements Inventory` — FR-SU6, FR-SU7, NFR-SU2/3/4/5/6/7]
- [Source: `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart:137-149` — garde AD-34 (su-1)]
- [Source: `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart:147-153` — garde symétrique]
- [Source: `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:249-268` — ni `mode` ni `reviewer`]
- [Source: `packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart:26-44` — 6 valeurs]
- [Source: `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart:280,520` — `_generation`]
- [Source: `packages/zcrud_export/test/isolation_gates_test.dart` — patron de confinement dérivé]
- [Source: `~/.pub-cache/hosted/pub.dev/flutter_card_swiper-7.2.0/lib/src/widget/card_swiper_state.dart:110-170,216-300`]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-3.md` — D1/D2/D8/D11, 16/16 R3]
- [Source: `CLAUDE.md` — cycle BMAD, Key Don'ts, vérif verte]

---

## Dev Agent Record

### Agent Model Used
Claude Opus 4.8 (1M) — skill `bmad-dev-story` (mode non interactif).

### Debug Log References
- Vérif verte finale : `melos run analyze` **RC=0** (0 erreur repo-wide) · `melos run verify` **RC=0** ·
  `flutter test` **par package** — `zcrud_session` **304** (baseline 244, +60), `zcrud_flashcard`
  **399** (**inchangé** — lecture seule), `zcrud_study_kernel` **313** (non touché, non régressé).
- 🚫 `melos run test` **jamais lancé** (parallélise et se bloque) ; 🚫 `dart format` **jamais lancé** ;
  🚫 aucun `git checkout`/`restore` — sauvegardes par `cp` + SHA-256 (`/tmp/su4_backup`), restaurations
  vérifiées par `diff` (byte-exact).

### Completion Notes List
- [x] **Verdict MESURÉ des 2 prédictions d'arène (AC6) — les DEUX sont CONFIRMÉES**, sur le chemin
      markdown exact (`z_flashcard_gesture_arena_test.dart`, 14/14) :
  - *drag ∥ tap-to-reveal* : l'`InkWell` (descendant) **gagne** le tap contre le `TapGestureRecognizer`
    du `CardSwiper` (toujours enregistré) ⇒ la révélation survit, l'index n'avance pas. **Confirmée.**
  - *drag ∥ scroll vertical* : le `Scrollable` de la face (descendant) **gagne** le geste vertical
    contre le `PanGestureRecognizer` (qui revendique pourtant les deux axes) ⇒ la face défile, l'index
    n'avance pas. **Confirmée.**
  - ⇒ **aucune correction de composition n'a été nécessaire** ; l'`IgnorePointer` de su-2 est intact
    (garde de non-régression toujours verte).
- [x] **Arbitrage A3 justifié** après relecture de `z_session_quality_breakdown.dart` : **DISTINCT**,
      aucune réutilisation possible. Le breakdown consomme `Map<String,int> byQuality` — une
      **agrégation PAR QUALITÉ** (cardinalité = 6 crans, ordre = l'échelle) qui a **perdu la position**
      de chaque carte. L'indicateur su-4 est **PAR CARTE** (cardinalité = N, ordre = la position) et
      répond à « où en suis-je ? », pas à « comment ai-je noté ? ». Réutiliser le breakdown exigerait
      de lui rendre l'information qu'il agrège — c'est-à-dire d'en faire ce widget-ci. Les seams
      communs (`labelKeyFor`/`colorKeyFor`/`ZQualityScale`) restent définis **une seule fois**
      (`z_srs_quality_buttons.dart`) : zéro duplication. Table comparative dans la dartdoc du fichier.
- [x] **R3-I12 : ROUGE MESURÉ** ⇒ la dégradation Reduce Motion est **RÉELLE**, l'appel à
      `zReduceMotionOf` **n'est PAS décoratif** ⇒ **conservé** (le piège D8 de su-3 est évité).
      Mesures : sans RM, opacité 0.2→0.6 et largeur peinte de l'icône **19.2→25.6 px** ; avec RM,
      **1.0/1.0** et **32.0/32.0 px** (aucune interpolation, émoji toujours présent = FONCTION
      préservée). 2ᵉ point d'application (`duration` 200 ms → `Duration.zero`) également gardé.
- [x] **Table des 17 injections** : voir ci-dessous. **3 injections ont démasqué de VRAIS défauts de
      MES tests/mon code** ; toutes corrigées puis re-mesurées ROUGE.

#### 🔴 Écarts assumés vs la story (mesurés, non négociés)

| # | Ce que la story prescrit | Réalité **mesurée** | Décision |
|---|---|---|---|
| **AC5 / R3-I8** | échelle divergente « p.ex. `maxQuality: 4` » | **impossible à construire** : `ZSrsConfig` porte `assert(maxQuality == 5)` (`z_srs_config.dart:43-58` — SM-2 est intrinsèquement 0..5, formule gelée). La seule borne paramétrable est `minQuality` (0 ou 1) | divergence par le **BAS** : `ZSrsConfig(minQuality: 1)` ⇒ `clampQuality(0)=1` vs `0.clamp(0,5)=0`. Démasque le clamp littéral tout aussi bien — **R3-I8 ROUGE** |
| **AC3** | garde auto-énumérante sur le motif de nom `Z.*(SessionEngine\|SessionState)$` | ce motif capte **`ZSessionState`**, qui est le **value-object** d'état, pas un runtime ⇒ garde rouge sur du code conforme | **deux critères complémentaires** : (a) STRUCTUREL — les seuls `extends ChangeNotifier` du domaine sont les 3 runtimes (capte un 4ᵉ runtime quel que soit son nom) ; (b) NOMMAGE — capte même une classe qui n'étend rien (R3-I5). Les deux ROUGES |
| **AC12 / R3-I17a** | « retirer la capture du jeton avant l'`await` ⇒ ROUGE » | **NE ROUGIT PAS** : mon `_handleSwipe` est **synchrone** ⇒ **aucune fenêtre `await` ne s'ouvre** ⇒ le jeton était **structurellement inatteignable**, et sa dartdoc affirmait « capturé avant l'await » alors qu'aucun `await` n'existe = **fausse affirmation de conformité (défaut D8)** | jeton **RETIRÉ** ; la fenêtre est **dissoute** par la synchronicité (comme su-3 dissout par la géométrie), et l'invariant qui la rend vraie est désormais **GARDÉ** : un test rougit si `_handleSwipe` devient `async`/rend un `Future` — **vérifié ROUGE**. Le jeton reste RÉELLEMENT porteur là où la fenêtre existe (su-3, port `await`é), et l'assemblage le prouve |
| **AC12 / R3-I17b** | « retirer le verrou one-shot ⇒ ROUGE (double émission) » | **NE ROUGIT PAS** : mesuré, un **triple tap** sans laisser retomber l'animation n'émet qu'un seul index — le paquet avance `_undoableIndex` une fois par swipe **complété**, et `isLoop:false` rend `_currentIndex` nul après la dernière carte | verrous **CONSERVÉS** en défense en profondeur, mais leur **portée honnête est écrite dans la dartdoc** (« non atteint avec 7.2.0 + handler synchrone ») — aucune fausse affirmation |
| **AC4 / R3-I6** | « ⇒ ROUGE (source **ET** comportement) » | avec une injection qui **compile** : **SOURCE ROUGE** (garde su-1), **COMPORTEMENT VERT** — le test ne peut pas passer d'espion à un paramètre qui n'existe pas dans l'API réelle | consigné. La complémentarité que la story défend est **confirmée par la mesure** : c'est la garde de SOURCE qui attrape cette classe de défaut ; le test de comportement en attrape une autre (prouvé : il rougit sur R3-I4 et sur la casse de la voie SRS) |
| **AC2 / R3-I10c** | « le drag doit voler la saisie ⇒ ROUGE » | **ROUGE**, mais par un **autre symptôme** que prédit : descendre `ZFlashcardAnswerInput` dans le `cardBuilder` le fait rendre **2 fois** (une par carte affichée) ⇒ le test échoue sur `Found 2 TextField` avant même d'exercer le vol de geste | la mise sous le pan **est** détectée. La protection structurelle réelle est la **garde de composition (8)**, qui interdit au code de prod du swiper de composer la saisie/notation — **ROUGE** sur R3-I10d |

#### Table des injections R3 — **toutes JOUÉES sur disque, rouge MESURÉ, restaurées (`cp` + `diff`)**

| Injection | Cible | Résultat mesuré |
|---|---|---|
| **R3-I1** | `onQualitySelected` au ctor + appelé depuis `onSwipe` | 🔴 **VERT au 1er jet — TROU RÉEL** : la garde comparait `'quality'` en **casse exacte**, or `onQualitySelected` contient `Quality` ⇒ **aveugle au défaut exact qu'elle existe pour attraper**. Garde rendue **insensible à la casse** + contre-preuve rejouant le défaut verbatim ⇒ **ROUGE (+3 -1)** |
| R3-I2 | `onSwipe` câblé sur `reviewer(quality: 5)` | ✅ ROUGE |
| R3-I3 | `ZSrsQualityButtons` débranché du reviewer | ✅ ROUGE (témoin positif à 0) |
| R3-I4 | table : `cramming → srsEngine` | ✅ ROUGE (mapping **et** AC4) |
| R3-I5 | `class ZFakeSessionEngine {}` dans `domain/` | ✅ ROUGE (critère de nommage) |
| R3-I5bis | 4ᵉ runtime `extends ChangeNotifier` | ✅ ROUGE (critère structurel) |
| R3-I6 | `ZLinearSessionState.advance` câblé sur un reviewer | ✅ ROUGE (**source**) · ⚠️ VERT (comportement) — cf. écarts |
| R3-I7 | « retirer le témoin positif » | ⚠️ **non falsifiable tel quel** (supprimer un test ne rougit jamais une suite). **Intention réelle jouée** : casser la voie SRS (le moteur n'atteint plus le seam) ⇒ **ROUGE sur 3 suites** ⇒ le témoin est bien **porteur** |
| R3-I8 | `clampQuality` → `q.clamp(0, 5)` | ✅ ROUGE (via `minQuality: 1` — cf. écarts) |
| R3-I9 | file avancée **avant** l'`await` du seam | ✅ ROUGE (AC5 **et** AC12) |
| R3-I10c | saisie descendue dans le `cardBuilder` | ✅ ROUGE (symptôme différent — cf. écarts) |
| R3-I10d | le swiper compose lui-même la notation | ✅ ROUGE (garde de composition) |
| **R3-I11** | mémoïsation supprimée | ✅ ROUGE (le compteur grimpe avec les frames) |
| **R3-I12** | branche RM rend la valeur interpolée | ✅ **ROUGE** ⇒ RM **réel**, appel **conservé** |
| R3-I13 | `Semantics(value:)` retiré de la progression | ✅ ROUGE |
| **R3-I14** | cible ramenée à 40 dp | 🔴 **VERT au 1er jet — TAUTOLOGIE RÉELLE** : le test comparait à `ZSessionCardSwiper.minTarget`, donc l'injection **baissait l'assertion en même temps que le code**. Le `48` d'AD-13 est une exigence **externe** ⇒ écrit en dur dans le test ⇒ **ROUGE** |
| R3-I15a | dép. déclarée dans `zcrud_flashcard` | ✅ ROUGE |
| R3-I15b | `CardSwiperDirection` en signature publique | ✅ ROUGE |
| R3-I15c | paquet importé depuis un 2ᵉ fichier de `lib/` | ✅ ROUGE |
| R3-I16a | `numberOfCardsDisplayed: 2` en dur | ✅ ROUGE (file d'1 carte) |
| R3-I16b | `CardSwiper` construit sur file vide | ✅ ROUGE |
| **R3-I16c** | `isLoop: true` | 🔴 **VERT au 1er jet — TROU RÉEL** : `onEnd` est appelé dès `_currentIndex == cardsCount - 1`, **indépendamment d'`isLoop`** ⇒ observer `onEnd` ne prouve **rien**. Le discriminant réel est que **la 1ʳᵉ carte réapparaît** (session infinie) ⇒ test réécrit sur ce fait ⇒ **ROUGE** |
| R3-I17a | jeton de fraîcheur retiré | ⚠️ VERT ⇒ code **décoratif RETIRÉ** + invariant de synchronicité **gardé** (garde vérifiée **ROUGE** si `async`) |
| R3-I17b | verrous one-shot retirés | ⚠️ VERT ⇒ conservés en défense, **portée honnête consignée** en dartdoc |

### File List

**Créés**
- `packages/zcrud_session/lib/src/domain/z_session_runtime.dart`
- `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart`
- `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart`
- `packages/zcrud_session/test/z_session_runtime_mapping_test.dart`
- `packages/zcrud_session/test/z_no_srs_write_in_non_srs_modes_test.dart`
- `packages/zcrud_session/test/z_card_swiper_confinement_test.dart`
- `packages/zcrud_session/test/presentation/z_swiper_harness.dart`
- `packages/zcrud_session/test/presentation/z_session_card_swiper_test.dart`
- `packages/zcrud_session/test/presentation/z_session_card_swiper_fallback_test.dart`
- `packages/zcrud_session/test/presentation/z_session_card_swiper_sm1_test.dart`
- `packages/zcrud_session/test/presentation/z_session_card_swiper_a11y_test.dart`
- `packages/zcrud_session/test/presentation/z_swipe_never_grades_test.dart`
- `packages/zcrud_session/test/presentation/z_session_grading_test.dart`
- `packages/zcrud_session/test/presentation/z_session_progress_indicator_test.dart`
- `packages/zcrud_session/test/presentation/z_session_swipe_reduce_motion_test.dart`
- `packages/zcrud_session/test/presentation/z_session_swipe_concurrency_test.dart`

**Modifiés**
- `packages/zcrud_session/pubspec.yaml` — `flutter_card_swiper: ^7.2.0` (**seul point de déclaration**) + commentaire d'arête
- `packages/zcrud_session/lib/zcrud_session.dart` — exports (aucun type tiers)
- `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` — `clampQuality` (AD-46/AC5), **la garde AD-34 de su-1 est INTACTE** (consommée, jamais réécrite)
- `packages/zcrud_session/test/presentation/z_flashcard_gesture_arena_test.dart` — **ÉTENDU** (acte III : 5 tests ; aucune garde parallèle)
- `_bmad-output/implementation-artifacts/stories/su-4-pile-swipeable-modes.md` — Dev Agent Record

**Non committés / signalés** : `pubspec.lock` (racine) — contient désormais `flutter_card_swiper 7.2.0`,
**imposé par la résolution** ; il était **déjà modifié vs HEAD avant su-4** (dérive préexistante :
`graphite`, `google_maps`, `arrow_path` sont absents de HEAD et n'ont **pas** été introduits par su-4).
`example/pubspec.lock` **inchangé** (SHA-256 identique à l'état initial) et toujours untracked.
Les deux `pubspec.lock` sont **exclus du commit d'epic** (convention). **Aucun `*.g.dart`** généré
(`zcrud_session` n'a aucun `@ZcrudModel` ⇒ gate `codegen-distribution` sans objet).

### Change Log
- **su-4** — Pile de session swipeable + modes. `ZSessionCardSwiper` (navigation SEULE : aucun
  paramètre de notation — impossibilité **structurelle**), table unique `zSessionRuntimeForMode`
  (**aucun moteur créé** — les 3 runtimes existants servent les 6 modes), indicateurs de progression
  (**enum**) + retour émotionnel de drag (animation **réelle**, dégradée sous Reduce Motion),
  alternative accessible ≥ 48 dp (le paquet n'expose **aucune** sémantique — trou mesuré),
  `flutter_card_swiper ^7.2.0` **confiné** (gardé par le seul test d'AC10 : `graph_proof` est aveugle
  aux arêtes tierces), clamp AD-46 sur la voie unique de notation.
- **3 défauts réels démasqués par la discipline R3 et corrigés** : garde de source **sensible à la
  casse** (aveugle à `onQualitySelected`), assertion a11y **tautologique** (48 dp comparé à la
  constante du code), test `isLoop` **non discriminant** (`onEnd` est appelé même en bouclant).
- **1 code décoratif retiré** (jeton `_generation` du swiper, structurellement inatteignable —
  défaut D8 de su-3 évité) et **remplacé par une garde d'invariant** réellement porteuse.
