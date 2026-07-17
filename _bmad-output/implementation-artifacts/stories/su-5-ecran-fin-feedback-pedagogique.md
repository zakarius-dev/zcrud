---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story 1.5 : Écran de fin de session et feedback pédagogique

Status: review

**Clé sprint** : `su-5-ecran-fin-feedback-pedagogique`
**Ligne du sprint-status (mot pour mot)** :
`[L][A — après su-4] FR-SU8/9 ZSessionSummaryView assemble ZSessionQualityBreakdown+ZStudyProgressRings ; confetti ^0.8.0 opt-in 1 tir JAMAIS si Reduce Motion ; banques FR/EN l10n surchargeables ; palier <10s sans indice`

**Couvre** : FR-SU8, FR-SU9 · **Package en écriture** : `zcrud_session` (SEUL)
**Spine** : AD-46 · AD-10 · AD-13 · AD-2/AD-15 · AD-8/AD-1 · hérités AD-1..32

---

## Story

As an **apprenant**,
I want **être félicité et voir mon bilan à la fin d'une session**,
so that **je reste motivé et je sais quoi réviser ensuite**.

---

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

- **su-5 assemble. su-5 ne réimplémente rien.** `ZSessionQualityBreakdown` et
  `ZStudyProgressRings` **existent, sont exportés et testés** (vérifiés sur disque, § suivant).
- **`onStackEnd` (su-4) est le point d'entrée de su-5.** su-4 a livré l'événement **sans aucune UI**,
  explicitement pour cette story (arbitrage A7 de su-4).
- **`zcrud_core` est INTERDIT à cette story** (PRD : seul E-MULTI-EDIT y écrit). Conséquence dure sur
  les banques l10n — cf. **D5**.
- **`zcrud_flashcard` n'est PAS en écriture** : su-5 le **lit** (`ZSrsConfig`, `zReduceMotionOf`).
- **`confetti ^0.8.0`** = **2ᵉ et dernière** dépendance tierce de l'epic (contre-métrique PRD :
  trois au total — `flutter_card_swiper`, `confetti`, `printing`).

---

## Périmètre RÉEL vérifié sur disque (consommer — ne JAMAIS recréer)

### Ce que les acquis offrent RÉELLEMENT (lu, pas supposé)

| Acquis | Fichier réel | Contrat réel — **lire avant de coder** |
|---|---|---|
| `ZSessionQualityBreakdown` | `lib/src/presentation/z_session_quality_breakdown.dart` | `({required Map<String,int> byQuality, required ZQualityScale scale, required int passThreshold, labelKeyFor, colorKeyFor})`. **`StatelessWidget` PUR**. Consomme `byQuality` **verbatim** (aucun recomptage). Clé hors échelle → section « hors échelle » **signalée**, jamais fusionnée (R6). |
| `ZStudyProgressRings` | `lib/src/presentation/z_study_progress_rings.dart` | `({required ZProgressRingsData data, diameter=96, strokeWidth=10, trackColorKey='neutral', progressColorKey='primary'})`. DTO **pré-calculé** via **`ZProgressRingsData.fromResult(ZStudySessionResult)`** (fonction PURE : `total==0 ⇒ ratio 0`, clamp `[0,1]`). |
| `ZSessionCardSwiper.onStackEnd` | `lib/src/presentation/z_session_card_swiper.dart:172,362` | `final VoidCallback? onStackEnd`. Émis par `_handleEnd()` — **latch one-shot `_stackEnded`** (`:360-364`), car « `onEnd` peut être ré-entrant ». **Voie d'émission UNIQUE** (arbitrage A6). su-4 rend **aucune UI** de fin. |
| `zReduceMotionOf` | `zcrud_flashcard/lib/src/presentation/z_reduce_motion.dart:32` | `MediaQuery.disableAnimationsOf(context)`. **Primitive UNIQUE du repo.** Arête `zcrud_session → zcrud_flashcard` **préexistante**. |
| `ZQualityScale` | `lib/src/presentation/z_srs_quality_buttons.dart` | **`ZQualityScale.fromConfig(ZSrsConfig)` = unique voie publique** (AD-46). `min`/`max` **dérivés**, `qualities` croissant, `contains()`. Garde de source : `z_quality_scale_single_source_test.dart` **rougit si un littéral de borne réapparaît**. |
| `ZSrsConfig` | `zcrud_flashcard/lib/src/domain/z_srs_config.dart` | `passThreshold=3`, `minQuality=0`, `maxQuality=5`, `clampQuality()` (`:129`) = **unique voie de clamp**. `assert(maxQuality == 5)` (`:44`) et `assert(minQuality == 0 ‖ 1)` (`:60`). |
| `ZStudySessionResult` | `zcrud_study_kernel/lib/src/domain/z_study_session_result.dart` | **VO PUR** `{mode, total, correct, byQuality}`. `fromMap` **ne throw jamais**. **AUCUN `duration`, AUCUN `mastered`.** |
| Gardes auto-énumérantes | `test/presentation/z_widgets_purity_test.dart`, `z_widgets_hardcode_scan_test.dart` | Scannent **récursivement `lib/src/presentation/**`** ⇒ **ton widget naît gardé, sans édition du test** (R16). |
| Garde de confinement | `test/z_card_swiper_confinement_test.dart` | Allowlist **DÉRIVÉE** (jamais figée), contre-preuve R12 mutante, lecture cwd-robuste. **À ÉTENDRE, jamais à dupliquer.** |

### Absences PROUVÉES par grep négatif (rejouables, RC cité)

```bash
grep -rn "ZSessionSummaryView" packages/ --include='*.dart'          # → RC=1 — tout est à créer
grep -rn "confetti" packages/ --include='*.yaml'                      # → RC=1 — la dépendance N'EXISTE NULLE PART
grep -rni "confetti" packages/ --include='*.dart'                     # → RC=0 mais 2 COMMENTAIRES seuls
#   (z_reduce_motion.dart:5 et z_flashcard_reduce_motion_test.dart:4 : « su-5 (confetti supprimé) »). AUCUN code.
grep -rn "ZSessionFeedback\|ZPedagogicalFeedback\|feedbackBank" packages/ --include='*.dart'  # → RC=1
grep -rn "sessionDuration\|totalDuration\|elapsedTotal" packages/ --include='*.dart'          # → RC=1
grep -rn "duration" packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart   # → RC=1
grep -rn "zcrud\.session\." packages/zcrud_core/lib --include='*.dart'                        # → RC=1 — espace de clés LIBRE
grep -rn "Semantics" ~/.pub-cache/hosted/pub.dev/confetti-0.8.0/lib/                          # → RC=1 — ZÉRO Semantics
```

---

## 🎯 Les décisions de conception (mode non interactif — option la plus conservatrice, consignée)

### D1 — `ZSessionSummaryView` est PUR et **entièrement injecté**

Il ne connaît **aucun runtime** (la garde de pureté le lui **interdit déjà** : `_bannedImports`
contient `z_study_session_engine.dart`, `z_white_exam_session_engine.dart`,
`z_linear_session_state.dart`). Il reçoit un `ZStudySessionResult` **déjà construit**, plus ce que
le VO ne porte pas. Boutons = **callbacks injectés** (`onFinish`, `onContinue`).

### D2 — 🔴 D'où viennent RÉELLEMENT les stats (vérifié, pas supposé)

| Stat FR-SU8 | Source RÉELLE | Verdict |
|---|---|---|
| **cartes totales** | `result.total` | ✅ porté par le VO |
| **maîtrisées** | **N'EXISTE PAS** — à **dériver de `result.byQuality`** | ⚠️ cf. **D3** |
| **durée** | **N'EXISTE NULLE PART** — `grep duration z_study_session_result.dart` → **RC=1** ; `grep sessionDuration\|totalDuration` → **RC=1** | ⚠️ cf. **D4** |

**Fait mesuré** : le temps est mesuré **par carte**, jamais par session — `Stopwatch` de
`z_flashcard_answer_input.dart:199` (« PREMIER `Stopwatch` du repo »), exposé en
`ZFlashcardSubmission.timeTaken`. Et **aucun runtime n'agrège** : `ZStudySessionEngine` porte
`reviewed`/`lapses`/`remaining` (`:173-179`) mais **ne produit aucun `ZStudySessionResult`** — le
**seul** producteur du repo est `scoreWhiteExam` (`z_white_exam_session_engine.dart:228`).

### D3 — 🔴 « maîtrisée » ≠ `correct` — le piège de la seconde source, inversé

**Fait lu sur disque** (`z_white_exam_session_engine.dart:210-216`) :
`correct = nombre de réponses quality >= passThreshold` — soit **q3-4-5** (« bon ou mieux »).
Or le **glossaire PRD** et l'**AD-46** définissent **maîtrisée = q4-5**.

⇒ **`result.correct` N'EST PAS le compte des maîtrisées.** Afficher `correct` sous le libellé
« maîtrisées » serait un **défaut de type su-2 « présence ≠ association »** : un nombre juste,
attribué au mauvais concept, et **vert** parce que personne ne compare les deux.

- `masteredCount` est **dérivé de `result.byQuality`** (somme des comptes des crans
  `q >= masteredThreshold`) — **jamais** un recomptage d'une seconde source, **jamais** `correct`.
- `masteredThreshold` est **injecté**, défaut **DÉRIVÉ `scale.max - 1`** — **jamais le littéral `4`**
  (`z_quality_scale_single_source_test.dart` rougit sur un littéral de borne ; AD-46 interdit la
  seconde source). La dérivation est **totale** sur les configs réellement permises :
  `assert(maxQuality == 5)` ⇒ `scale.max - 1 == 4` ⇒ seau `4..5`, pour `minQuality` **0 comme 1**.
- Les anneaux continuent d'afficher `correct/total` (leur contrat), le bloc stats affiche
  `maîtrisées` — **deux nombres différents, volontairement**. L'AC2 l'**oppose explicitement**.

### D4 — La durée est **INJECTÉE** ; `ZStudySessionResult` **N'EST PAS MODIFIÉ**

**Option rejetée** : ajouter `duration` au VO. Motifs : (1) VO **persisté** (`snake_case`,
round-trip) ⇒ déclenche le gate de **rétro-compatibilité de sérialisation** (`es-4-0`) pour **zéro
gain d'AC** ; (2) c'est un **portage verbatim de lex** (`{mode,total,correct,byQuality}`) ;
(3) `zcrud_study_kernel` **n'est pas le package en écriture** de su-5. ⇒ `duration` est un paramètre
du widget, mesuré par l'appelant. Conforme à « présentation pure + tout injecté ».

### D5 — Banques FR/EN : `zcrud_core` étant INTERDIT, la banque vit dans `zcrud_session`

**Contrainte dure** : les tables `_frLabels`/`_enLabels` vivent dans
`zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (`:24`, `:113`, `_tables` `:204`) — **fermées
et hors périmètre**. Le patron `label(context, key, fallback:)` ne porte qu'**UNE** langue de repli,
alors que FR-SU9 exige **FR *et* EN par défaut**. (C'est la dette **LOW consignée par su-4** :
« clés `zcrud.session.*` non définies ».)

**Conception retenue — chaîne à 3 étages, sans toucher au cœur** :

1. **Sélection** = fonction **PURE** (`lib/src/domain/`, pur-Dart) : entrées
   `(quality, timeTaken, hintsUsed, config, thresholds)` → **une clé l10n** (`String`). Testable
   **hors widget** (exigence FR-SU9).
2. **Banque par défaut** (`lib/src/presentation/`) : maps **FR** et **EN**, `clé → texte`,
   sélectionnées par `Localizations.localeOf(context).languageCode` (repli EN).
3. **Résolution** : `label(context, key, fallback: bank.resolve(key, locale))`.
   `label()` donne priorité à `ZcrudScope.labels` → table de locale → `_enLabels` du cœur →
   `fallback`. Les clés `zcrud.session.feedback.*` étant **absentes du cœur** (grep **RC=1**), le
   défaut rendu est bien celui de **notre** banque, et une app qui injecte `ZcrudScope(labels:)`
   **gagne**.
4. **Slot de surcharge** : une banque injectée (`ZFeedbackBank?`) **remplace INTÉGRALEMENT** la
   banque par défaut (exigence AC : « surcharge intégrale »).

### D6 — 🔴 `confetti 0.8.0` — pièges RÉELS relevés **dans les sources du paquet**

> Lu : `~/.pub-cache/hosted/pub.dev/confetti-0.8.0/lib/src/confetti.dart`, `lib/src/particle.dart`,
> `lib/src/constants.dart` (`kLowLimit = 1/60`). su-4 a démasqué 3 crashs réels du swiper par cette
> lecture — voici ce que la même lecture donne ici.

| # | Fait **lu dans le paquet** | Conséquence pour su-5 |
|---|---|---|
| **T1** | `ConfettiController({duration = const Duration(seconds: 30)})` + `assert(!duration.isNegative && duration.inMicroseconds > 0)` | **`Duration.zero` fait ASSERT-FAIL.** Reduce Motion ⇒ **NE PAS CONSTRUIRE** le widget — surtout pas « une durée nulle ». Et le **défaut 30 s** est absurde pour un tir unique ⇒ **durée explicite courte**. |
| **T2** | `_animationStatusListener` : sur `completed`, appelle `_continueAnimation()` **INCONDITIONNELLEMENT** ⇒ `_animController.forward(from: 0)` — **même avec `shouldLoop: false`** | L'`AnimationController` **redémarre en boucle**. Il ne s'arrête **que** via `_particleSystemListener` quand le système passe `finished`. ⇒ **`pumpAndSettle` peut ne JAMAIS converger.** |
| **T3** | `pauseEmissionOnLowFrameRate = true` (défaut) ; `_animationListener` calcule `deltaTime` sur **`DateTime.now()`** (horloge **murale**, jamais le faux temps du test) ; `ParticleSystem.update()` fait **`if (pauseEmission) return;` AVANT le bloc d'émission** (`particle.dart:165`) | En test, `delta > kLowLimit` ⇒ **ZÉRO particule émise**. Le statut reste `started` ⇒ jamais `finished` ⇒ **boucle infinie de T2**. ⇒ (a) `pauseEmissionOnLowFrameRate: false` ; (b) **n'assérer JAMAIS sur les particules** — assérer sur **notre latch** et sur la **présence/absence du `ConfettiWidget`**. |
| **T4** | `colors: null` ⇒ **couleurs aléatoires** | **Viole NFR-SU5.** ⇒ `colors:` **injectées depuis le thème** (`zResolveColorKeyOrSlot`). |
| ~~T4bis~~ | ~~`strokeColor = Colors.black` en dur viole NFR-SU5~~ | 🔴 **RECTIFIÉ (code-review su-5)** : **cette affirmation de la story était FAUSSE**. Vérifié dans le paquet (`confetti.dart:26-27`) : `strokeWidth = 0` par **défaut** et n'est jamais surchargé ⇒ le stroke **n'est JAMAIS peint**. **Aucune violation** — la story avait tort, **le code avait raison**. Rien à corriger dans le code. |
| **T5** | `ConfettiController.dispose()` fait `notifyListeners()` **puis** `super.dispose()` ; `_ConfettiWidgetState.dispose()` appelle `widget.confettiController.stop()` ; `stop()` **court-circuite** si `state == disposed` | **Posséder** le controller dans **notre** `State`, le disposer dans **notre** `dispose()` (Flutter démonte les **enfants d'abord** ⇒ le `ConfettiWidget` s'est déjà désabonné). **Jamais** disposer le controller pendant que le `ConfettiWidget` est encore monté. |
| **T6** | `grep -rn "Semantics" confetti-0.8.0/lib/` → **RC=1** — **ZÉRO `Semantics`** (exactement comme `flutter_card_swiper`) | Le confetti est **purement décoratif** ⇒ `ExcludeSemantics` **obligatoire**, et **aucune information** ne doit y transiter (l'apprenant au lecteur d'écran ne « voit » rien). |

### D7 — 🔴 Reduce Motion : la leçon DURE de su-3, à ne pas rejouer

su-3 avait un `AnimatedOpacity(opacity: 1)` **qui n'animait rien** ⇒ l'appel à `zReduceMotionOf`
était **décoratif**, son test **incapable de rougir**, et **tout a dû être retiré**. su-4 a corrigé
en **gardant le câblage lui-même** (D6 de `code-review-su-4.md`).

**Règle su-5, sans exception** : **chaque** animation (trophée élastique, glow, cercles de fond,
confettis) est soit **RÉELLE et sa dégradation PROUVÉE par un test qui rougit**, soit **RETIRÉE**.
Une animation dont on ne sait pas écrire le test qui rougit **n'entre pas dans la story**.
**Aucune conformité AD-13 simulée.**

### D8 — `ZDocPageQuality.mastered` **n'est PAS réutilisable** (justification écrite exigée)

`grep -rn -i "mastered" packages/` → **RC=0**, mais **uniquement** dans `zcrud_document`
(`z_doc_page_quality.dart:29` `mastered(2)`, `z_document_learning_info.dart:188` `masteredCount`).
C'est une **échelle 0..2 de pages de document** (`toReview=0`, `mastered=2`) — **un autre domaine,
une autre échelle**, et `zcrud_document` **n'est pas sur une arête de `zcrud_session`** (pubspec :
`zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel`). **Le réutiliser serait une fausse
réutilisation** (homonymie), et l'importer créerait une **arête interdite**. ⇒ le seau « maîtrisée »
de su-5 est **dérivé de l'échelle SM-2** (D3). *Précédent : su-4 a dû justifier par écrit que son
indicateur était distinct de `ZSessionQualityBreakdown`.*

### D9 — Handoff su-6 (ne PAS ouvrir ici, mais ne PAS créer la divergence)

su-6 (FR-SU12) a besoin des **mêmes seaux** (mauvais **q0-2** / bon **q3** / maîtrisé **q4-5**).
su-5 crée le seuil « maîtrisé » **une fois** (D3). **su-6 DOIT le consommer, jamais le redéclarer.**
Consigné ici pour que le `create-story` de su-6 le lise. su-5 **n'implémente aucun filtre**.

---

## ⚠️ Écart PRD tranché (à consigner, pas à ré-ouvrir)

| Point | PRD FR-SU9 | Glossaire PRD + Epics 1.5 + **AD-46** | **Tranché** |
|---|---|---|---|
| Seau « mauvais » du feedback | « qualité (4-5 / 3 / **1-2**) » | « mauvais = **0-2** » ; AC epics : « (4-5 / 3 / **0-2**) » | **q0-2** — AD-46 : « **aucune note n'est hors seau** ». Le PRD (§FR-SU9) porte un **résidu** de l'échelle 1-5 déjà **explicitement amendée** par le spine (§ « Écarts assumés »). Une note **q0** ne doit tomber dans **aucun trou**. |

---

## ⚠️ Frontières de périmètre (dures)

| Sujet | Story propriétaire | su-5 |
|---|---|---|
| Sélecteur de session, streak, filtres | **su-6** | 🚫 |
| UI d'examen blanc (`ZListSessionView`) | **su-7** | 🚫 |
| Liste de flashcards | **su-8** | 🚫 |
| Parcours assemblé `example/` | **su-10** | 🚫 |
| Nouveau moteur / écriture SRS | *aucune* (AD-34/AD-33) | 🚫 **su-5 n'écrit AUCUN SRS** |
| `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard` en écriture | E-MULTI-EDIT / autres | 🚫 **lecture seule** |

---

## Acceptance Criteria

### AC1 — `ZSessionSummaryView` **assemble** ; il ne réimplémente **rien**

**Given** une session terminée
**When** `ZSessionSummaryView` s'affiche
**Then** il **monte** `ZSessionQualityBreakdown` **et** `ZStudyProgressRings` (les widgets existants)
**And** les anneaux sont alimentés par **`ZProgressRingsData.fromResult(result)`** (jamais un ratio recalculé)
**And** le breakdown reçoit **`result.byQuality` verbatim** (jamais un recomptage)
**And** `passThreshold`/`scale` viennent de la **`ZSrsConfig` injectée** (`ZQualityScale.fromConfig`).

- **Fichier** : `lib/src/presentation/z_session_summary_view.dart` (**NEW**) + export barrel.
- **Test porteur** : `test/presentation/z_session_summary_view_test.dart` — `expect(find.byType(ZSessionQualityBreakdown), findsOneWidget)` **et** `find.byType(ZStudyProgressRings)`, **plus** l'assertion que le DTO monté **égale** `ZProgressRingsData.fromResult(result)` (VO à `==` de valeur).
- **Injection R3** : remplacer le montage de `ZStudyProgressRings` par un `CustomPaint` maison ⇒ **ROUGE**.

### AC2 — 🎯 Stats : total / **maîtrisées** / durée — et « maîtrisées » **n'est pas** `correct`

**Given** un `result` où `correct` et le compte des maîtrisées **DIFFÈRENT**
(ex. `byQuality = {'0':1,'2':1,'3':3,'4':2,'5':1}`, `total=8`, `correct=6` ⇒ **maîtrisées = 3**)
**When** l'écran s'affiche
**Then** la stat « maîtrisées » affiche **3** (q4+q5), **jamais 6**
**And** la stat « totales » affiche `result.total`
**And** la **durée** affichée est la `Duration` **injectée**
**And** le seuil de maîtrise est **dérivé** (`scale.max - 1`), **jamais le littéral `4`**.

- **Test porteur** : `test/presentation/z_session_summary_view_test.dart`.
- 🔴 **Le corpus est choisi pour que `correct != masteredCount`** — c'est **tout** le pouvoir
  discriminant de l'AC (défaut su-2 « présence ≠ association »). Un corpus où les deux coïncident
  rendrait le test **incapable de rougir**.
- 🔴 **Interdit** (défaut su-4) : comparer l'assertion à **la constante du code**
  (`expect(masteredCount, ZSummaryDefaults.masteredThreshold…)`). L'attendu est **`3`, écrit en dur
  dans le test**, dérivé **à la main** du corpus du test.
- **Injections R3** : (a) `masteredCount → result.correct` ⇒ **ROUGE** (`3 != 6`) ;
  (b) seuil `scale.max - 1 → scale.max` ⇒ **ROUGE** (`3 → 1`) ;
  (c) durée injectée ignorée ⇒ **ROUGE**.

### AC3 — Boutons « Terminer » / « Encore N dues » — callbacks injectés, **ACTIONNÉS**

**Given** `dueRemaining = 7` et les callbacks `onFinish`/`onContinue` injectés
**When** l'utilisateur **tape** « Terminer », puis (test suivant) **tape** « Encore 7 dues »
**Then** `onFinish` est invoqué **exactement une fois** et `onContinue` **jamais**, puis l'inverse
**And** le libellé « Encore N dues » porte **N = 7** (jamais un compte recalculé)
**And** `dueRemaining == 0` ⇒ le bouton « Encore N dues » est **absent** (jamais grisé — patron AD-45)
**And** chaque bouton est une cible **≥ 48 dp** avec `Semantics(button: true)` et libellé l10n.

- 🔴 **Le test TAPE réellement chaque bouton** (`tester.tap` + `pump`). Défaut su-4 **interdit de
  récidive** : un bouton « précédent » qui **avançait** était vert parce que le test n'assérait que
  `label isNotEmpty` et **ne tapait jamais le bouton**. **Un contrôle doit être ACTIONNÉ dans son test.**
- 🔴 **Chaque tap vérifie le compteur de l'AUTRE callback** (« présence ≠ association » : deux
  boutons câblés sur le même callback passeraient un test qui ne compte qu'un seul).
- 🚫 **`warnIfMissed: false` INTERDIT** — il masquerait une mauvaise cible (défaut consigné).
- **Injection R3** : permuter `onFinish`/`onContinue` ⇒ **ROUGE**.

### AC4 — Feedback pédagogique : **fonction PURE**, testable hors widget (FR-SU9)

**Given** une soumission en mode apprentissage `(quality, timeTaken, hintsUsed)`
**When** le feedback est calculé
**Then** le message dépend de la **qualité** (**4-5** encouragement / **3** neutre / **q0-2** motivation),
du **temps de réponse** et du **nombre d'indices**
**And** le palier « **exceptionnel** » par défaut est **`timeTaken < 10 s` ET `hintsUsed == 0`**
(seuil **configurable**, jamais un `10` en dur dans un `build()`)
**And** la sélection est une **fonction pure** (aucun `BuildContext`), retournant une **clé l10n**
**And** toute qualité hors bornes passe par **`config.clampQuality`** (voie **unique**, AD-46/AD-10)
⇒ **aucune note n'est hors seau** (q0 tombe dans « mauvais »).

- **Fichier** : `lib/src/domain/z_session_feedback.dart` (**NEW**, **pur-Dart** — `z_purity_test.dart`
  bannit `flutter/material|widgets|cupertino` dans `lib/src/domain/`).
- **Test porteur** : `test/domain/z_session_feedback_test.dart` — **`test`, pas `testWidgets`**.
- **Table à couvrir explicitement** : `q5/5 s/0 indice` → exceptionnel ; `q5/30 s/0` → encouragement
  (**pas** exceptionnel) ; `q5/5 s/1 indice` → encouragement (**pas** exceptionnel — *l'indice tue le
  palier*) ; `q3/*` → neutre ; **`q0`**, `q1`, `q2` → motivation ; **`q-3` et `q9`** → clampés
  (`0`→motivation, `5`→encouragement), **jamais** d'exception.
- 🔴 **Interdit** (défaut su-4) : une fonction locale au test qui recalcule l'attendu — le test
  **s'appellerait lui-même**. Les attendus sont des **clés littérales écrites dans le test**.
- **Injections R3** : (a) `< 10 s` → `<= 10 s` ⇒ ROUGE sur un cas à **exactement 10 s** (borne
  **explicitement testée**) ; (b) supprimer la condition `hintsUsed == 0` ⇒ ROUGE ;
  (c) seau `q0-2` → `q1-2` ⇒ **ROUGE sur `q0`** ; (d) retirer `clampQuality` ⇒ ROUGE.

### AC5 — Banques FR/EN par défaut, **surchargeables intégralement** (NFR-SU4)

**Given** aucune banque injectée
**When** le feedback s'affiche en locale **`fr`** puis en locale **`en`**
**Then** les **deux** rendent le texte de la banque par défaut **de leur langue** (textes **différents**)
**And** une **banque injectée** les **surcharge intégralement**
**And** aucun libellé utilisateur n'est codé en dur hors des banques (`label(context, key, fallback:)`).

- **Fichiers** : `lib/src/presentation/z_session_feedback_bank.dart` (**NEW**).
- **Espace de clés** : `zcrud.session.feedback.*` — **libre** (grep cœur **RC=1**).
- **Test porteur** : `test/presentation/z_session_feedback_bank_test.dart` — monter sous
  `Localizations` en `fr` puis en `en`, assérer **deux textes distincts et non vides** ; puis
  injecter une banque témoin et assérer qu'**elle seule** parle.
- 🔴 **Interdit** : assérer `text.isNotEmpty` seul (l'assertion serait **vraie quoi qu'il arrive** —
  défaut « preuve creuse » de su-4). On assère le **texte attendu** et la **différence FR≠EN**.
- **Injection R3** : rendre la banque FR **identique** à EN ⇒ **ROUGE**.

### AC6 — `confetti` **opt-in**, **UN SEUL tir**, jamais deux

**Given** le confetti **opt-in activé** (défaut : **désactivé**)
**When** l'écran s'affiche, **puis se reconstruit N fois** (`setState` parent, changement de thème,
`didUpdateWidget`, rotation)
**Then** le tir part **exactement une fois** (latch **one-shot**, patron `_stackEnded` de su-4 `:360`)
**And** `confetti` **opt-out par défaut** ⇒ aucun `ConfettiWidget` monté.

- 🔴 **N'assérer JAMAIS sur les particules** (**T3** : `pauseEmissionOnLowFrameRate` + horloge
  **murale** ⇒ **zéro particule en test**, l'assertion serait **fausse pour la mauvaise raison**).
  On assère sur **notre latch** (compteur de `play()` via un seam de test) et sur
  `find.byType(ConfettiWidget)`.
- 🚫 **`pumpAndSettle` INTERDIT** autour du confetti (**T2** : `_continueAnimation()` inconditionnel
  ⇒ peut **ne jamais converger**). Utiliser `pump()` + durées explicites.
- **Réglages imposés** (T1/T3/T4) : `duration` **explicite courte** (jamais le défaut 30 s, **jamais
  `Duration.zero` → assert-fail**), `pauseEmissionOnLowFrameRate: false`, `shouldLoop: false`,
  `colors:` **injectées du thème**, `ExcludeSemantics` (**T6**).
- **Injection R3** : retirer le latch ⇒ **ROUGE** (`plays == 3` au lieu de `1`).

### AC7 — 🎯 Reduce Motion : **aucun confetti**, animations **neutralisées** (NFR-SU3)

**Given** **Reduce Motion actif** (`MediaQuery(disableAnimations: true)`)
**When** l'écran de fin s'affiche, confetti **opt-in activé**
**Then** **aucun `ConfettiWidget` n'est monté** et **aucun tir** n'est déclenché
**And** trophée / dégradé / cercles de fond **ne sont pas animés** — **état final rendu
immédiatement** (dégradation de l'**animation**, jamais de la **fonction** — `zReduceMotionOf`)
**And** le signal est lu **via `zReduceMotionOf`** — **primitive unique**, jamais un
`MediaQuery.of(context).disableAnimations` réécrit.

- **Test porteur** : `test/presentation/z_session_summary_reduce_motion_test.dart`.
- 🔴 **Le CÂBLAGE est gardé** (leçon su-3/D6 su-4) : un test **rougit si `zReduceMotionOf` n'est plus
  appelé** — la garde porte sur l'**appel**, pas sur une apparence.
- 🔴 **Chaque animation prouve sa dégradation** : sans Reduce Motion, la valeur animée **DIFFÈRE entre
  deux `pump()` intermédiaires** ; avec Reduce Motion, elle est **à sa valeur finale au premier
  frame**. **Une animation dont ce test ne peut pas rougir DOIT ÊTRE RETIRÉE** (D7) — pas conservée
  avec un `zReduceMotionOf` décoratif.
- **Injections R3** : (a) ignorer Reduce Motion pour le confetti ⇒ ROUGE ; (b) rendre une animation
  inerte (`Tween(begin: 1, end: 1)`, l'exact défaut su-3) ⇒ **le test de dégradation doit ROUGIR**
  (il constate que « animé » et « non animé » sont **indiscernables**) ; (c) `zReduceMotionOf` →
  `false` constant ⇒ ROUGE.

### AC8 — `confetti` **CONFINÉ** à `zcrud_session` (NFR-SU7, AD-1/AD-8)

**Given** le monorepo
**When** la garde de confinement s'exécute
**Then** **un seul `pubspec.yaml`** déclare `confetti` (`zcrud_session`), **épinglé `^0.8.0`**
**And** **un seul fichier** de `lib/` l'importe
**And** le **barrel ne l'importe ni ne le réexporte**
**And** **aucun type `confetti`** (`ConfettiWidget`, `ConfettiController`, `ConfettiControllerState`,
`BlastDirectionality`, `ParticleStats`, `ParticleStatsCallback`) n'apparaît dans une **signature
publique** hors de ce fichier.

- 🔴 **Fait vérifié** : `scripts/dev/graph_proof.py` ne détecte **AUCUNE fuite tierce** (il ne connaît
  que les arêtes inter-`zcrud_*`) ⇒ **ce test est le SEUL exécuteur de la contrainte**.
- 🔴 **ÉTENDRE `test/z_card_swiper_confinement_test.dart`, JAMAIS le dupliquer** : su-4 y a livré une
  allowlist **DÉRIVÉE** et une contre-preuve **mutante**. **Généraliser** les consts `_pkg` /
  `_ownerPackage` / `_bannedTypes` en une **table de paquets confinés** (`flutter_card_swiper`,
  `confetti`) et **renommer** le fichier `z_third_party_confinement_test.dart` (`git mv`).
  ⚠️ L'assertion `importers hasLength(1)` devient **par paquet** (chacun a **son** fichier).
- **Injection R3** : déclarer `confetti` dans un 2ᵉ `pubspec.yaml` ⇒ **ROUGE** ; exposer
  `ConfettiController` dans le barrel ⇒ **ROUGE**.

### AC9 — Robustesse & cycle de vie (AD-10) — leçons su-3/su-4

**Given** l'écran de fin
**When** chacun des cas ci-dessous survient
**Then** **aucun crash, aucune exception** :

| Cas | Attendu |
|---|---|
| **Session vide** (`total == 0`, `byQuality == {}`) | Rendu **observable** (anneau vide via `fromResult` — `ratio 0`, **jamais** de division par zéro), **pas** un écran blanc |
| **`onStackEnd` ré-entrant** (su-4 : « `onEnd` peut être ré-entrant ») | L'écran est poussé **une seule fois** — le latch **one-shot** de su-4 (`:360`) est **consommé**, jamais réinventé |
| **Démontage pendant une animation** (`pumpWidget(SizedBox())` en plein tir) | **Aucune exception**, controllers **disposés** (`tester.takeException()` **`isNull`**) |
| **Démontage pendant un tir de confetti** (**T5**) | Notre `State` dispose le controller **après** le démontage du `ConfettiWidget` — **aucun `notifyListeners` post-dispose** |
| **`byQuality` avec clé hors échelle** (`{'9': 2}`) | **Signalée**, jamais fusionnée (contrat existant du breakdown) ; **`masteredCount` ne la compte pas** |
| **`result` incohérent** (`correct > total`) | `ratio` **clampé** (contrat existant) ; aucun crash |

- **Test porteur** : `test/presentation/z_session_summary_lifecycle_test.dart`.
- 🔴 **La branche de repli doit être ATTEINTE** (défaut consigné : « branche de repli jamais
  atteinte ») : le cas « session vide » **observe** le rendu (`find.byType`/clé), il ne se contente
  pas de constater l'absence d'exception.
- 🔴 **Le `key` dérivé de l'identité de la file est le patron de su-4 — le RÉUTILISER** si su-5
  reconstruit une sous-arborescence sur changement de `result` (racine unique de D1/D2/D8 de su-4 :
  **la file qui rétrécit crashait sur le chemin NOMINAL**, `reduceGrade` retirant une carte à
  **chaque réussite**).

### AC10 — A11y / l10n / thème / RTL — la garde est **auto-énumérante**, ne pas la doubler

**Given** les widgets de `lib/src/presentation/**`
**When** `z_widgets_hardcode_scan_test.dart` et `z_widgets_purity_test.dart` s'exécutent
**Then** ils **captent `z_session_summary_view.dart` SANS édition** (scan **récursif**, R16)
**And** **zéro** `Colors.`/`Color(0x`, **zéro** API non-directionnelle, **zéro** `ListView(children:)`,
**zéro** libellé utilisateur en dur
**And** le widget est **`StatelessWidget`/`StatefulWidget` pur** — aucun gestionnaire d'état, aucun
runtime importé, aucune écriture SRS.

- 🚫 **AUCUNE garde parallèle** — les étendre si besoin (leçon E10 : « une garde redondante diverge »).
- **Semantics** : la valeur des stats est exposée en **texte** (couleur jamais seul canal, AD-13) ;
  le confetti est **`ExcludeSemantics`** (**T6** : le paquet n'a **aucun** `Semantics`).

#### 🔎 Portée RÉELLE de la garde de libellés (lue — ne pas la « corriger » à tort)

`_bannedUserStringRules` vise **les puits RÉELLEMENT RENDUS** : 1ᵉʳ argument positionnel de `Text(`
/`SelectableText(`, et `errorText:`/`labelText:`/`hintText:`/`helperText:`/`tooltip:`/`semanticLabel:`.

- ✅ **La banque FR/EN ne la déclenche PAS** : ses littéraux sont des **valeurs de map**
  (`'zcrud.session.feedback.…': 'Bravo !'`), pas un puits de rendu. `fallback:` est le patron
  **SANCTIONNÉ**. ⇒ **Ne pas contourner la garde, ne pas la modifier** : il n'y a rien à taire.
  (🚫 Rappel su-2 : **on ne modifie JAMAIS un test pour taire un défaut**.)
- ⚠️ **Angle mort CONSIGNÉ** (dartdoc de la garde, ledger su-4) : **`Semantics(label: '…')` n'est PAS
  couvert** (l'ajouter rougirait sur du code hérité su-1/su-2). ⇒ **su-5 doit s'auto-discipliner** :
  tout `Semantics(label:/value:)` passe par `label(context, key, fallback:)`. **Une garde ne prouve
  QUE ce qu'elle scanne** — l'absence de rouge ici **n'est pas** une preuve de conformité.
- ⚠️ Autre angle mort : un littéral passé par une **variable intermédiaire**
  (`final s = 'Bravo'; … Text(s)`) échappe au scan. Ne pas l'exploiter.

### AC11 — **enums > booléens** (convention du spine)

**Given** les variantes d'affichage de l'écran de fin
**When** une variante est exprimée
**Then** elle est portée par un **enum** (ex. `ZSummaryCelebration { none, subtle, confetti }`),
**jamais** par un `bool showConfetti`
**And** le défaut est **`none`/`subtle`** (confetti **opt-in**, jamais par défaut).

- **Test porteur** : garde de source (motif `bool show`/`bool is` dans la signature publique du
  widget) **ou** assertion de l'API. **Le défaut opt-out est ASSÉRÉ.**

---

## Spécifications techniques — contrat à livrer

```dart
// lib/src/domain/z_session_feedback.dart  (NEW — PUR-DART, aucun import flutter/material|widgets)

/// Seau de feedback — dérivé de la qualité CLAMPÉE (AD-46 : aucune note hors seau).
enum ZFeedbackTier { motivation, neutral, encouragement, exceptional }

/// Seuils du palier « exceptionnel » (configurables — jamais un `10` dans un build()).
class ZFeedbackThresholds {
  const ZFeedbackThresholds({
    this.exceptionalUnder = const Duration(seconds: 10), // FR-SU9 : < 10 s
    this.exceptionalMaxHints = 0,                        // … SANS indice
  });
  final Duration exceptionalUnder;
  final int exceptionalMaxHints;
}

/// Sélection PURE (aucun BuildContext) → **clé l10n**. Testable hors widget.
/// - `config.clampQuality(quality)` = **voie UNIQUE** de clamp (AD-46/AD-10) ;
/// - seaux : `>= masteredThreshold` → encouragement · `== passThreshold` → neutral
///   · **sinon → motivation (q0-2 : AUCUNE note hors seau)** ;
/// - `exceptional` : encouragement **ET** `timeTaken < exceptionalUnder` **ET**
///   `hintsUsed <= exceptionalMaxHints`.
ZFeedbackTier zFeedbackTierFor({
  required int quality,
  required Duration timeTaken,
  required int hintsUsed,
  required ZSrsConfig config,
  required int masteredThreshold,
  ZFeedbackThresholds thresholds = const ZFeedbackThresholds(),
});

String zFeedbackKeyFor(ZFeedbackTier tier); // → 'zcrud.session.feedback.<tier>'
```

```dart
// lib/src/presentation/z_session_feedback_bank.dart  (NEW)

/// Banque de messages : clé l10n → texte. Slot de surcharge INTÉGRALE (FR-SU9).
abstract class ZFeedbackBank {
  String? maybeResolve(String key, String languageCode);
}

/// Banque par défaut FR/EN EMBARQUÉE dans `zcrud_session`.
/// 🔴 `zcrud_core` est INTERDIT à cette story ⇒ les tables `_frLabels`/`_enLabels`
/// du cœur ne peuvent pas être étendues (cf. D5). Résolution finale :
///   `label(context, key, fallback: bank.maybeResolve(key, lang) ?? '')`
/// ⇒ `ZcrudScope(labels:)` de l'app garde la PRIORITÉ (chaîne de `label()`).
class ZDefaultFeedbackBank implements ZFeedbackBank { /* maps fr + en */ }
```

```dart
// lib/src/presentation/z_session_summary_view.dart  (NEW — confetti CONFINÉ ICI)

/// Variante de célébration — **enum**, jamais un booléen (AC11).
enum ZSummaryCelebration { none, subtle, confetti }

/// Écran de fin de session — **assemble**, ne réimplémente rien (FR-SU8).
class ZSessionSummaryView extends StatefulWidget {
  const ZSessionSummaryView({
    required this.result,          // ZStudySessionResult INJECTÉ (kernel VO)
    required this.duration,        // 🔴 INJECTÉE — le VO ne la porte PAS (D4, grep RC=1)
    required this.config,          // ZSrsConfig → scale + passThreshold (AD-46)
    required this.onFinish,        // callback injecté (AC3)
    this.dueRemaining = 0,         // « Encore N dues » ; 0 ⇒ bouton ABSENT
    this.onContinue,               // callback injecté (AC3)
    this.celebration = ZSummaryCelebration.none, // 🔒 confetti OPT-IN (défaut none)
    this.masteredThreshold,        // défaut DÉRIVÉ `scale.max - 1` (D3), jamais 4
    this.feedbackBank,             // slot de surcharge INTÉGRALE (AC5)
    super.key,
  });
  // ...
}

/// Compte des MAÎTRISÉES — dérivé de `byQuality` (D3).
/// 🔴 CE N'EST PAS `result.correct` (= q >= passThreshold, soit q3+ — vérifié
///    `z_white_exam_session_engine.dart:210-216`). Ici : q >= masteredThreshold (q4-5).
int zMasteredCount(Map<String, int> byQuality, ZQualityScale scale, int masteredThreshold);
```

**Réglages `ConfettiWidget` imposés (D6 — lus dans le paquet)** :
`ConfettiController(duration: <courte, explicite>)` · `pauseEmissionOnLowFrameRate: false` (T3) ·
`shouldLoop: false` · `colors: <thème>` (T4) · `ExcludeSemantics` (T6) ·
**controller possédé par notre `State`, disposé dans notre `dispose()`** (T5) ·
**jamais construit sous Reduce Motion** (T1 — `Duration.zero` **assert-fail**).

---

## Tasks / Subtasks

- [x] **T1 — Dépendance confinée** (AC8)
  - [x] `confetti: ^0.8.0` dans le **seul** `packages/zcrud_session/pubspec.yaml`
  - [x] `dart pub get` ; vérifier `graph_proof` / CORE OUT=0 inchangés
  - **Compatibilité VÉRIFIÉE** (lue dans `confetti-0.8.0/pubspec.yaml`, patron AD-42/`printing`) :
    `sdk: ">=2.17.0 <4.0.0"` · `flutter: ">=3.0.0"` · **seule dépendance transitive :
    `vector_math ^2.1.4`** (déjà tirée par Flutter) ⇒ compatible avec le SDK du monorepo
    (`zcrud_session` : `sdk: ^3.12.2`), **aucune dépendance de plateforme**, aucun codegen.
- [x] **T2 — Feedback pur** (AC4)
  - [x] `lib/src/domain/z_session_feedback.dart` (pur-Dart) + export barrel
  - [x] `test/domain/z_session_feedback_test.dart` (`test`, hors widget) + table de cas + bornes
- [x] **T3 — Banques FR/EN** (AC5)
  - [x] `lib/src/presentation/z_session_feedback_bank.dart` + export barrel
  - [x] `test/presentation/z_session_feedback_bank_test.dart` (fr ≠ en ; surcharge intégrale)
- [x] **T4 — `ZSessionSummaryView`** (AC1, AC2, AC3, AC11)
  - [x] `lib/src/presentation/z_session_summary_view.dart` + export barrel
  - [x] Assemblage breakdown + rings ; stats total/**maîtrisées**/durée ; boutons à callbacks
  - [x] `test/presentation/z_session_summary_view_test.dart` (corpus `correct != mastered` ; **taps réels**)
- [x] **T5 — Célébration + Reduce Motion** (AC6, AC7)
  - [x] Trophée/glow : animations **RÉELLES** (injection su-3 `Tween(1,1)` ⇒ **ROUGE**) ; **cercles de fond RETIRÉS** (D7 — cf. Completion Notes)
  - [x] Latch one-shot ; confetti jamais sous Reduce Motion
  - [x] `test/presentation/z_session_summary_reduce_motion_test.dart` (câblage gardé + dégradation prouvée)
- [x] **T6 — Robustesse & cycle de vie** (AC9)
  - [x] `test/presentation/z_session_summary_lifecycle_test.dart` (vide, ré-entrance, démontage, T5)
- [x] **T7 — Garde de confinement ÉTENDUE** (AC8)
  - [x] `mv test/z_card_swiper_confinement_test.dart test/z_third_party_confinement_test.dart`
        (⚠️ `git mv` **impossible** : le fichier n'est pas suivi — su-1..su-4 ne sont pas committés)
  - [x] Généralisée en **table de paquets** (allowlist **dérivée** conservée, contre-preuve mutante conservée)
- [x] **T8 — Vérif verte** (`flutter test` **par package**) + relecture des gardes auto-énumérantes

---

## Stratégie de test

### ⚠️ `melos run test` est INUTILISABLE (parallélise, se bloque) — `flutter test` PAR PACKAGE

```bash
cd /home/zakarius/DEV/zcrud/packages/zcrud_session   && flutter test   # réf. 314 tests
cd /home/zakarius/DEV/zcrud/packages/zcrud_flashcard && flutter test   # réf. 399 tests (NON régressé : lecture seule)
# Vérif transverse (workstreams au repos) :
cd /home/zakarius/DEV/zcrud && dart run melos run analyze   # RC=0 attendu, REPO-WIDE
```

- 🚫 **Jamais `git checkout`** — su-1..su-5 **ne sont pas committés** : un checkout les **détruit**.
- 🚫 **Jamais `dart format`** — repo *short*, non format-gated.
- 🚫 **Jamais `pumpAndSettle`** autour du confetti (**T2** : peut ne jamais converger).
- Référence de non-régression : **23/23 packages, 3993 tests**.

### Discipline R3 — un test qui ne rougit pas ne prouve rien

Pour **chaque** AC, l'injection R3 listée est **rejouée** et doit **ROUGIR**. Une injection qui reste
verte = le test est **décoratif** ⇒ corriger le **test**, jamais l'AC.

### 🔴 Défauts déjà démasqués dans cet epic — **interdits de récidive**

| Défaut | Origine | Garde-fou su-5 |
|---|---|---|
| **Test tautologique** (fonction locale recalculant l'attendu ; assertion comparée à **une constante du code**) | su-4 (« 48 dp ») | AC2/AC4 : attendus **littéraux écrits dans le test**, jamais lus du code |
| **Présence ≠ association** (marqueur sur le mauvais choix ; bouton « précédent » qui **avance**) | su-2, su-4 | AC3 : **chaque bouton est TAPÉ** et l'**autre** callback est vérifié |
| **Preuve creuse** (« MESURÉ » vacueux ; assertion vraie quoi qu'il arrive) | su-4 | AC5 : jamais `isNotEmpty` seul. AC6 : ne pas assérer sur des particules **qui n'existent pas en test** (T3) |
| **Reduce Motion décoratif** (`AnimatedOpacity(opacity: 1)` n'animant rien) | su-3 (**tout retiré**) | AC7 : animation **réelle** + **câblage gardé**, sinon **RETIRÉE** (D7) |
| **Branche de repli jamais atteinte** ; sonde mesurant un **sibling** ; `warnIfMissed: false` | su-3/su-4 | AC9 : le repli est **observé**. AC3 : `warnIfMissed: false` **interdit** |
| **Garde ligne-à-ligne** ; contre-preuve **ré-implémentant** le scanner | E10 | AC8/AC10 : gardes **étendues**, jamais dupliquées ; allowlist **dérivée** |
| **Crash sur le chemin NOMINAL** (file qui rétrécit ⇒ `RangeError`) | su-4 (HIGH) | AC9 : `key` **dérivée de l'identité** — patron **réutilisé** |
| 🚫 **Modifier un test pour taire un défaut réel** (débordement `RenderFlex` masqué) | su-2 | **Interdit.** Un débordement se **corrige** dans le widget |

---

## Dev Notes

### Contraintes AD applicables

- **AD-46** — échelle **possédée par `ZSrsConfig`** ; `ZQualityScale.fromConfig` **dérive**.
  `clampQuality` = **voie unique**. Seau « mauvais » = **q0-2** (aucune note hors seau).
- **AD-2/AD-15** — widget **pur-Flutter** ; aucun gestionnaire d'état ; controllers **stables**
  (create/dispose), jamais recréés au rebuild.
- **AD-10** — **jamais d'exception** : session vide, `byQuality` corrompu, `correct > total`,
  démontage en plein tir → replis **définis et observés**.
- **AD-13** — `Semantics` explicites, cibles **≥ 48 dp**, variantes **directionnelles**,
  **Reduce Motion** réel ; couleur **jamais** seul canal.
- **AD-1/AD-8** — `confetti` **confiné** à `zcrud_session` ; graphe acyclique ; **CORE OUT=0**.
- **AD-33/AD-34** — su-5 **n'écrit aucun SRS** et **ne crée aucun moteur** (la garde de pureté
  l'interdit structurellement).

### Key Don'ts (spécifiques à su-5)

- 🚫 **Never** réimplémenter le breakdown ou les anneaux — **les monter** (AC1).
- 🚫 **Never** afficher `result.correct` sous le libellé « maîtrisées » (**D3** : q3+ ≠ q4-5).
- 🚫 **Never** écrire le littéral `4` pour le seuil de maîtrise — **dériver** `scale.max - 1` (AD-46).
- 🚫 **Never** ajouter `duration` à `ZStudySessionResult` (**D4** : VO persisté, gate rétro-compat,
  package hors périmètre).
- 🚫 **Never** réutiliser `ZDocPageQuality.mastered` (**D8** : échelle 0..2, autre domaine, arête
  interdite).
- 🚫 **Never** toucher `zcrud_core` / `zcrud_study_kernel` / `zcrud_flashcard` (lecture seule).
- 🚫 **Never** `Duration.zero` sur `ConfettiController` (**T1** : `assert` ⇒ **crash**) — sous Reduce
  Motion, **ne pas construire**.
- 🚫 **Never** `pumpAndSettle` autour du confetti (**T2**).
- 🚫 **Never** assérer sur le nombre de particules (**T3** : il vaut **zéro** en test).
- 🚫 **Never** laisser `colors: null` (**T4** : couleurs **aléatoires** ⇒ viole NFR-SU5).
- 🚫 **Never** créer une garde parallèle — **étendre** les gardes auto-énumérantes (AC8/AC10).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.5`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU8, FR-SU9, §4 Glossaire, NFR-SU3/4/5/7`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-46, AD-10, AD-13, AD-1/AD-8, Conventions`]
- [Source: `_bmad-output/implementation-artifacts/stories/su-4-pile-swipeable-modes.md#AC10, AC12, arbitrages A6/A7`]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-4.md#D1, D2, D3, D6`]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-3.md#D8`]
- [Source: `~/.pub-cache/hosted/pub.dev/confetti-0.8.0/lib/src/confetti.dart`, `lib/src/particle.dart:153-180`, `lib/src/constants.dart`]
- [Source: `docs/parity-study-ui-2026-07-16/annexes/iffd_flashcards.md` — best-of-breed : trophée animé, stats, confettis, cercles animés]
- [Source: `CLAUDE.md` — cycle BMAD strict, vérif verte, Key Don'ts]

---

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8[1m]` — skill `bmad-dev-story` (tool `Skill`, résolution `resolve_customization.py` RC=0 :
`activation_steps_prepend`/`append` vides, `persistent_facts` = `**/project-context.md` (**aucun fichier
sur disque** — vérifié), `on_complete` vide).

### Debug Log References

**Vérif verte RÉELLE (rejouée, RC mesurés)** :

| Commande | RC | Résultat |
|---|---|---|
| `dart run melos run analyze` (repo-wide) | **0** | SUCCESS |
| `dart run melos run verify` (repo-wide) | **0** | gates `codegen-distribution`/`secrets`/`graph_proof`/`serialization` OK |
| `flutter test` **par package** (23 packages, séquentiel) | **0** | **23/23 — 4076 tests** |
| `zcrud_session` | 0 | **397** (référence su-4 : 314 ⇒ **+83**) |
| `zcrud_flashcard` | 0 | **399** — **inchangé** (lecture seule respectée) |

Référence su-4 : 23/23, **3993** ⇒ **4076 = 3993 + 83**. Aucune régression.

### Completion Notes List

#### ✅ Statut par AC

| AC | Statut | Preuve |
|---|---|---|
| AC1 assemblage | ✅ | breakdown + rings MONTÉS ; DTO `== ZProgressRingsData.fromResult` ; `byQuality` verbatim ; scale/passThreshold dérivés (config tronquée testée) |
| AC2 stats | ✅ | corpus `correct=6 != mastered=3` ; seuil dérivé `scale.max - 1` |
| AC3 boutons | ✅ | **chaque bouton TAPÉ** + compteur de l'AUTRE callback vérifié ; `dueRemaining==0` ⇒ absent ; ≥48 dp ; **aucun `warnIfMissed: false`** |
| AC4 feedback pur | ✅ | `test` (jamais `testWidgets`) ; bornes ; clamp ; totalité |
| AC5 banques FR/EN | ✅ | textes littéraux attendus ; FR≠EN ; surcharge intégrale ; priorité `ZcrudScope` |
| AC6 confetti 1 tir | ✅ | latch one-shot ; opt-out par défaut ; **jamais d'assertion sur les particules** |
| AC7 Reduce Motion | ✅ | dégradation **prouvée** ; injection su-3 `Tween(1,1)` ⇒ **ROUGE** |
| AC8 confinement | ✅ | garde **généralisée en table** ; 2 injections ⇒ ROUGE |
| AC9 robustesse | ✅ | vide **observé**, hors-échelle, `correct>total`, durée négative, démontages, débordement |
| AC10 a11y/l10n/thème | ✅ | gardes auto-énumérantes **prouvées capter le fichier** (4 injections ⇒ ROUGE) |
| AC11 enums | ✅ | défaut `none` **asséré** + garde de source anti-`bool show…` |

#### 🔴 Défauts RÉELS trouvés par mes propres tests (corrigés dans le CODE)

1. **Double annonce au lecteur d'écran** (a11y, AD-13) — `Semantics(label:)` du bouton **fusionnait**
   avec le `Text` interne : le nœud annonçait **« Terminer\nTerminer »**. Corrigé par
   `ExcludeSemantics` autour du `Text` (le libellé est porté par le `Semantics` du bouton, canal
   unique). **Le test d'AC3 l'a démasqué** — sans lui, la story livrait un bégaiement d'annonce.

#### 🔴 Écarts CONSIGNÉS (mesurés, jamais supposés)

1. **R3-(d) de l'AC4 est INATTEIGNABLE telle qu'écrite dans la story.** « Retirer `clampQuality` ⇒
   ROUGE » — **rejouée, restée VERTE (19/19)**. C'était le **TEST** qui avait tort. Mesuré : sur toute
   config **permise**, le seau est **invariant par clamp** — clamp haut (`q<min→min`) :
   `assert(minQuality < passThreshold)` ⇒ `min` et tout `q` en dessous sont dans `motivation` ; clamp
   bas (`q>max→max`) : `max=5 >= mastered=4` ⇒ `encouragement`, comme un `q9` brut. Les cas `q-3`/`q9`
   étaient verts **par accident arithmétique** (ils prouvaient AD-10, jamais le clamp). Le clamp n'est
   observable que si `masteredThreshold > max` (paramètre **injecté et sans `assert`** ⇒ entrée
   légitime). Deux tests ajoutés (`q9`/`q999` avec `masteredThreshold: 6`) : **injection rejouée ⇒
   ROUGE (2 tests)**. Le clamp est **conservé** (AD-46 : voie unique) et désormais **réellement gardé**.
2. **`>= passThreshold` retenu au lieu du `== passThreshold` de la spec** (`zFeedbackTierFor`).
   **Identique** sur toute config par défaut (`3` est la seule note entre les deux seuils), mais
   **total et correct** sur une échelle tronquée : avec `passThreshold=1`, un `q2` est une **réussite**
   et le `==` l'aurait envoyé en `motivation` **silencieusement**. Colle au **glossaire** (« bon » =
   réussi mais non maîtrisé), définition normative des seaux (AD-46).
3. **Cercles de fond animés : RETIRÉS** (D7). Le trophée (échelle élastique) et le halo (opacité) sont
   **réels** et leur dégradation **prouvée** (injection `Tween(1,1)` ⇒ ROUGE **sur les deux**). Pour les
   cercles de fond, je n'ai pas su écrire un test de dégradation qui rougisse **au-delà** de ce que ces
   deux animations prouvent déjà : D7 est explicite — « une animation dont on ne sait pas écrire le
   test qui rougit **n'entre pas dans la story** ». Décor non livré plutôt que conformité AD-13 simulée.
4. **`git mv` impossible** (T7) : le fichier n'est **pas suivi** (su-1..su-4 non committés) ⇒ `mv` simple.
   **Aucun `git checkout`/`restore` joué.**
5. **Harnais de test corrigé, jamais l'inverse** : `MaterialApp(locale: Locale('fr'))` **échoue**
   (`DefaultMaterialLocalizations` ne supporte que `en`). C'est le **harnais** qui avait tort (mesuré :
   le même widget rend le FR correctement sous `Localizations`) ⇒ montage de `Localizations`
   directement. **Aucun test affaibli pour contourner l'erreur.**
6. **Preuve invalide démasquée et REJOUÉE** : mon 1ᵉʳ passage d'injections AC10 montrait « rouge »…
   pour la **mauvaise raison** (bug de quoting zsh ⇒ chemin de test inexistant, `+0 -1`). Rejoué
   correctement : baseline **21 vert** → chaque injection **20 -1** (exactement une garde rougit) →
   restauration **21 vert**. Idem, une assertion `lessThanOrEqualTo(1)` **infalsifiable** (vraie même à
   0 poussée) a été remplacée par un **assemblage réel** (`_StackEndHost` : swiper → `onStackEnd` →
   écran de fin **observé**, `ends == 1`).

#### 🔒 Les 4 pièges du paquet `confetti`, neutralisés (relus par moi dans les sources)

| Piège | Vérifié | Neutralisation |
|---|---|---|
| **T1** `assert(!duration.isNegative && duration.inMicroseconds > 0)` (`confetti.dart:501`) | ✅ lu | Sous Reduce Motion le widget **n'est PAS construit** (jamais `Duration.zero`) ; durée **explicite 800 ms** (jamais le défaut 30 s) |
| **T2** `_continueAnimation()` **hors** du `if (!shouldLoop)` (`:252-258`) | ✅ lu | `shouldLoop: false` **et** **aucun `pumpAndSettle`** autour du confetti (`pump()` + durées explicites) |
| **T3** `deltaTime` sur **horloge murale** + `pauseEmission` | ✅ lu | `pauseEmissionOnLowFrameRate: false` ; **aucune assertion sur les particules** — on assère le **latch** (`celebrationPlays`) et `find.byType(ConfettiWidget)` |
| **T4** `colors: null` ⇒ aléatoire | ✅ lu | `colors:` **injectées du thème** (`zResolveColorKeyOrSlot`) |
| **T5** `dispose()` ⇒ `notifyListeners()` **avant** `super.dispose()` (`:531-534`) | ✅ lu | Controller **possédé par notre `State`** ; vérifié que `_ConfettiWidgetState.dispose()` (`:377-382`) **retire son listener** et que Flutter démonte les **enfants d'abord** ⇒ aucun notify post-dispose. **Test de démontage en plein tir : `takeException() isNull`** |
| **T6** `grep Semantics confetti-0.8.0/lib/` → **RC=1** | ✅ rejoué | `ExcludeSemantics` — aucune information ne transite par le confetti |

#### 🔬 Injections R3 JOUÉES (cassé → **ROUGE** → restauré `cp` + **SHA-256 vérifié**)

| # | Injection | Résultat |
|---|---|---|
| AC4-a | `< 10 s` → `<= 10 s` | 🔴 ROUGE (test de borne exacte à 10 s) |
| AC4-b | suppression de `hintsUsed == 0` | 🔴 ROUGE |
| AC4-c | seau `q0-2` → `q1-2` | 🔴 ROUGE (sur **q0**) |
| AC4-d | retrait de `clampQuality` | ⚠️ **VERT** au 1ᵉʳ jet (test creux) → test **réparé** → 🔴 **ROUGE (2 tests)** |
| AC5 | banque FR := banque EN | 🔴 ROUGE (4 tests) |
| AC1 | rings → `CustomPaint` maison | 🔴 ROUGE |
| AC2-a | `masteredCount` := `result.correct` | 🔴 ROUGE (6 ≠ 3) |
| AC2-b | seuil `scale.max - 1` → `scale.max` | 🔴 ROUGE (3 → 1) |
| AC2-c | durée injectée ignorée | 🔴 ROUGE |
| AC3 | permutation `onFinish`/`onContinue` | 🔴 ROUGE |
| AC6 | retrait du latch one-shot | 🔴 ROUGE (`plays == 3`) |
| AC7-a | Reduce Motion ignoré pour le confetti | 🔴 ROUGE |
| AC7-b | **trophée INERTE `Tween(1,1)`** (défaut EXACT su-3) | 🔴 **ROUGE** |
| AC7-b' | **halo INERTE** | 🔴 **ROUGE** |
| AC7-c | `zReduceMotionOf` → `false` constant | 🔴 ROUGE |
| AC8-a | `confetti` déclaré dans un 2ᵉ `pubspec` | 🔴 ROUGE |
| AC8-b | `ConfettiController` exposé au barrel | 🔴 ROUGE (2 tests) |
| AC9-i | suppression du `SingleChildScrollView` | 🔴 ROUGE (débordement RÉEL) |
| AC9-ii | retrait de la garde de durée négative | 🔴 ROUGE |
| AC9-iii | `masteredCount` comptant les clés hors échelle | 🔴 ROUGE |
| AC10 ×4 | `Colors.red` / libellé en dur / `Alignment.topLeft` / import de moteur **dans MON fichier** | 🔴 ROUGE (les gardes auto-énumérantes **captent le fichier neuf sans édition** — R16) |

**Toutes les sources touchées ont été restaurées et vérifiées par `sha256sum -c` (OK).**

#### 🚫 Ce que je n'ai PAS fait (et pourquoi)

- **`zcrud_core` / `zcrud_study_kernel` / `zcrud_flashcard`** : **aucune écriture** (vérifié
  `git status` : leurs modifications présentes sont **celles de su-1..su-4**, non committées, intactes).
  `ZStudySessionResult` **non modifié** (D4). Le `pubspec.yaml` de `zcrud_flashcard`, muté le temps
  d'une injection, est **restauré** (SHA-256 OK).
- **Aucun `git checkout`/`git restore`**, **aucun commit**, **aucune écriture du `sprint-status.yaml`**,
  **aucun `dart format`**, **aucun `melos run test`**.
- **Aucune garde parallèle** : les gardes existantes ont été **étendues** (table de paquets) ou
  **consommées telles quelles**. La garde de libellés **n'a pas été modifiée** (la banque ne la
  déclenche pas : ses littéraux sont des **valeurs de map**, pas un puits de rendu).
- **`Semantics(label:)` — angle mort consigné, non couvert par la garde** : auto-discipline appliquée
  (tout `Semantics(label:/value:)` passe par `label(context, key, fallback:)` ou un texte **déjà
  résolu** par l'appelant). La garde n'a **pas** été élargie (elle rougirait sur du code hérité su-1/su-2).
- **Libellés de chrome de l'écran** (`titre`/`Cartes`/`Maîtrisées`/`Durée`/`Terminer`) : patron
  **SANCTIONNÉ** `label(context, key, fallback:)` — donc **un seul** repli linguistique, comme tous les
  widgets du repo. Les **banques FR/EN** couvrent le **feedback** (périmètre exact de FR-SU9). Étendre
  la bilinguisation au chrome demanderait soit d'écrire dans `zcrud_core` (**interdit**), soit de
  détourner `ZFeedbackBank` de son rôle : **hors périmètre**, consigné.
- **su-6/su-7/su-8/su-10** : aucun filtre, aucun sélecteur, aucun parcours assemblé. Le seuil
  « maîtrisé » est créé **une fois** (`zMasteredCount` + défaut dérivé) — **su-6 doit le consommer**.

### File List

**Créés (`packages/zcrud_session/`)**
- `lib/src/domain/z_session_feedback.dart` — sélection PURE (pur-Dart) + `ZFeedbackTier`/`ZFeedbackThresholds`
- `lib/src/presentation/z_session_feedback_bank.dart` — `ZFeedbackBank`/`ZDefaultFeedbackBank` FR+EN, `zFeedbackText`, `ZSessionFeedbackText`
- `lib/src/presentation/z_session_summary_view.dart` — `ZSessionSummaryView` + `ZSummaryCelebration` + `zMasteredCount` (**seul importeur de `confetti`**)
- `test/domain/z_session_feedback_test.dart` (19 tests)
- `test/presentation/z_session_feedback_bank_test.dart` (12)
- `test/presentation/z_session_summary_view_test.dart` (17)
- `test/presentation/z_session_summary_reduce_motion_test.dart` (13)
- `test/presentation/z_session_summary_lifecycle_test.dart` (13)

**Modifiés**
- `packages/zcrud_session/pubspec.yaml` — `confetti: ^0.8.0` (+ dartdoc de confinement)
- `packages/zcrud_session/lib/zcrud_session.dart` — 3 exports (barrel : **aucun type tiers**)

**Renommé + généralisé**
- `packages/zcrud_session/test/z_card_swiper_confinement_test.dart` →
  `packages/zcrud_session/test/z_third_party_confinement_test.dart` (**table de paquets**, 15 tests)

**Hors périmètre, non committé, signalé**
- `pubspec.lock` (racine) : `confetti` + `arrow_path` ajoutés par la **résolution** (`dart pub get`
  RC=0). Le fichier était **déjà modifié** avant la story ; **exclu du commit** par la règle d'epic.

### Change Log

| Date | Version | Description |
|---|---|---|
| 2026-07-17 | su-5 | Écran de fin de session + feedback pédagogique. 3 fichiers de prod, 5 suites de tests (74 tests neufs), garde de confinement **généralisée en table de paquets**. 2ᵉ dépendance tierce de l'epic (`confetti ^0.8.0`) **confinée, opt-in, 1 tir, jamais sous Reduce Motion**. 1 défaut a11y RÉEL corrigé (double annonce). 1 test creux démasqué et réparé (clamp AD-46). Cercles de fond **retirés** (D7). 23/23 packages, **4076 tests**, `analyze`/`verify` RC=0. |
