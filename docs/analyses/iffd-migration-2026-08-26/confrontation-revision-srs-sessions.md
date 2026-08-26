# Confrontation — domaine « Révision : SRS, sessions, gamification » (IFFD) × socle zcrud v3.21.0

> Mesuré le **2026-08-26**. `/home/zakarius/DEV/iffd` en **lecture seule stricte**, aucun test lancé.
> Socle lu à `cc276c154` (tag `v3.21.0`), 41 paquets.
> Matière d'entrée : `carte-revision-srs-sessions.md` (24 859 o, présente) + les **cinq** catalogues
> `capacites-zcrud-*.md`. **Aucun constat repris sans remesure** — quatre affirmations de la carte
> et une du catalogue sont réfutées ci-dessous (§ 0).

---

## 0. 🔴 Cinq constats d'entrée RÉFUTÉS sur disque

Ils changent le classement de trois capacités entières. À lire avant le reste.

| # | Affirmation | Source | Mesure | Conséquence |
|---|---|---|---|---|
| R1 | « `_checkAndUpdateStreak` : **aucun équivalent** — le socle rend la série, il ne la calcule pas » | carte § 4 et § 1.4 | **FAUX.** `zAdvanceStreak` (`zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:130`, 213 l.) calcule la règle complète : `started`/`incremented`/`alreadyCountedToday`/`resetToOne`/`skippedNotGraded`, plancher à 1, `best = max(best, current)` | une capacité entière passe de MANQUE à **MIGRABLE** (M1) |
| R2 | « `zcrud_export`/`zcrud_export_pdf` **délibérément absents** : exigent Syncfusion ^34, IFFD est en ^32 (`pubspec.yaml:292`) » | carte § 4 | **PÉRIMÉ.** `:292` est un **commentaire obsolète** ; `iffd/pubspec.yaml:141-149` déclare `syncfusion_flutter_* ^34.1.31`, et `zcrud_export_pdf/pubspec.yaml:39` n'exige que `syncfusion_flutter_pdf: ^34.1.31` — **contrainte déjà satisfaite** | une capacité passe de « bloquée » à **MIGRABLE** (M12) |
| R3 | « chaîne `zcrud_flashcard -> zcrud_export -> syncfusion_flutter_pdf` » | `iffd/pubspec.yaml:326` | **FAUX.** `zcrud_flashcard/pubspec.yaml` ne dépend que de `zcrud_core`, `zcrud_study_kernel`, `zcrud_markdown`, `zcrud_annotations` — **aucun `zcrud_export`** | l'adoption de `zcrud_export_pdf` n'entraîne **pas** `xlsio` |
| R4 | « **Cinq paliers** SM-2 … `QuestionType` à 5 valeurs » | carte § 2 et § 6 | **FAUX pour les types.** `QuestionType` (`iffd/lib/src/domain/models/flashcard_model.dart:12-17`) a **4** valeurs (`multipleChoice`, `trueOrFalse`, `openQuestion`, `exercise`). Le socle en a **6** | la migration des types est un **sur-ensemble** : aucune perte |
| R5 | « `ZStudySessionEngine` — **cité IFFD ✅** » | catalogue étude-révision § 5.1 | **FAUX POSITIF.** Unique occurrence : `iffd/lib/src/presentation/features/flashcards/zcrud/review_card_zcrud.dart:44`, **dans un commentaire** (`// … NI la file de session (ZStudySessionEngine)`) | **les trois** moteurs de `zcrud_session` sont non consommés, pas deux |

Les **compteurs** de la carte, eux, sont exacts et rejoués : 35 fichiers / 18 178 lignes dans
`features/flashcards/`, **313** `Colors.<nom>`, **89** `Color(0x…)`, **72** `setState(`, **0** appel
de localisation. Grep négatif l10n montré :

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn --include='*.dart' -E 'AppLocalizations|context\.l10n|S\.of\(' \
    lib/src/presentation/features/flashcards | wc -l
0
```

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme le canal

⚠️ **Nuance qui commande tout** : « migré » ici veut dire *écrit et compilé*, pas *actif*. Mesuré
sur tout `lib/` : **52** constantes `…UseZcrudDefault = false` contre **1** à `true`
(`ai_router_zcrud_edition.dart`, hors périmètre). Et la QA n'a pas commencé —
`docs/qa-plan-comparaison-legacy-zcrud.md` : **198** cases `[ ]`, **0** case `[x]`.

| Canal socle | `fichier:ligne` socle | Site chez l'hôte | Sites | Drapeau |
|---|---|---|---|---|
| `ZFlashcardAnswerInput` + `ZFlashcardSubmission` | `zcrud_session/…/z_flashcard_answer_input.dart:102`, `…/z_flashcard_submission.dart:19` | `…/flashcards/zcrud/review_session_zcrud.dart:36-37` | 5 / 6 | `reviewSession` = `false` |
| `ZSrsQualityButtons` + `ZQualityScale` | `zcrud_session/…/z_srs_quality_buttons.dart:187` / `:38` | `…/flashcards/zcrud/srs_quality_zcrud.dart:30-31,101,178` | 5 / 6 | `srsQuality` = `false` |
| `ZFlashcardReviewCard` + `ZRevealTransition` | `zcrud_flashcard/…/z_flashcard_review_card.dart:88`, `…/z_reveal_transition.dart:18` | `…/flashcards/zcrud/review_card_zcrud.dart` | 4 / 2 | `kReviewCardUseZcrudDefault` = `false` |
| `ZSm2Scheduler` + `ZSrsConfig` + `ZRepetitionInfo` | `zcrud_flashcard/…/z_sm2_scheduler.dart:23`, `…/z_srs_config.dart:17`, `…/z_repetition_info.dart:79` | `lib/src/domain/models/flashcard_repetition_info.dart:5-6,57,392` | 5 / 4 / 9 | `kUseZcrudSm2Scheduler` = `false` |
| `registerZFlashcardEditors` + `ZFlashcardEditionValidator` | `zcrud_flashcard/…/z_flashcard_editors.dart:41`, `…/z_flashcard_edition_validator.dart:41` | `lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:171` | 3 / 1 | actif (registre) |
| `ZFlashcard` / `ZFlashcardType` / `ZChoice` | `zcrud_flashcard/…/z_flashcard.dart:64`, `…/z_flashcard_type.dart:16`, `…/z_choice.dart:22` | `lib/src/data/repositories/z_backed_flashcard_repository.dart` (797 l.) | 51 / 14 / 15 | `useZcrudFlashcardRepository` = `false` (`…/flashcards/providers/flashcard_providers.dart:23`) |
| `ZReviewMode` | `zcrud_study_kernel/…/z_review_mode.dart:20` | 3 sites | 3 | — |
| `presentEdition` + `ZEditionPresentation` (aire **édition**, sert le périmètre) | `zcrud_navigation/…/present_edition.dart:155`, `…/z_edition_presentation.dart` | `lib/src/utils/functions/forms_utils.dart:775` (« 93 appelants ») | 4 / 22 | actif |

🔴 **`ZRepetitionStore` n'est PAS migré**, malgré ses 3 occurrences : elles vivent **toutes** dans
un fichier mort. Grep négatif montré :

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn 'ZRepetitionStore' lib | grep -v 'firebase_owner_scoped_repetition_store.dart'
$ echo "RC=$?"
RC=1
$ grep -rn 'FirebaseOwnerScopedRepetitionStore' lib | grep -v 'firebase_owner_scoped_repetition_store.dart'
lib/src/data/repositories/z_backed_folder_document_repository.dart:285:/// … (commentaire)
```

⇒ `firebase_owner_scoped_repetition_store.dart` (**154 l.**) est du code mort à supprimer sec.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire

Chaque ligne porte l'API exacte, son `fichier:ligne` dans `packages/`, ce que **le corps** fait
(pas la dartdoc), et le volume d'hôte supprimé.

### M1 — La flamme d'assiduité : `zAdvanceStreak` (et elle corrige un BUG livré)

| | |
|---|---|
| **API** | `zAdvanceStreak(ZStudyStreak, {at, mode, civilDayOf})` → `ZStreakAdvance{streak, outcome}` |
| **Socle** | `packages/zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:130` (+ `ZStreakOutcome:20`, `ZStreakAdvance:42`, `zIsGradedMode:84`) ; entité `ZStudyStreak` : `…/z_study_streak.dart:148` ; jour civil : `zLocalCivilDay:70`, `zParseCivilDayNumber:109`, `zCivilDayNumber:134` |
| **Hôte** | `…/flashcards/pages/folder_flashcards_repetitions_page.dart:113-171` (`_checkAndUpdateStreak`, **59 l.**) |
| **Corps vérifié** | lignes 138-204 : `switch` sur l'écart de **numéros de jour civil** (`todayNumber - lastNumber`), branches `gap==0`/`gap<0`/`gap==1`/`gap>1`, plancher `current < 0 ? 1 : current+1`, `_applied` maintient `best` |

🔴 **Ce n'est pas une simplification, c'est une correction.** L'hôte écrit
`today.difference(lastStudy).inDays == 1` (`:147`). Le socle documente et interdit précisément ce
calcul (`z_advance_streak.dart:109-116`, `z_study_streak.dart:24-33`) : un jour de passage à
l'heure d'été dure **23 h**, `inDays` rend alors **0** pour « hier → aujourd'hui » ⇒ la branche
`newStreak++` n'est jamais prise, on tombe dans le `else` **`newStreak = 1`** — **la flamme est
remise à 1 le lendemain du changement d'heure**, chaque année, pour tous les utilisateurs.
`zCivilDayNumber` (arithmétique entière de Hinnant, zéro `DateTime`, zéro `Duration`) est immunisé
par construction.

Gains annexes mesurés : `best` (record) gratuit ; idempotence explicite (l'hôte la bricole avec un
`bool _streakUpdated`) ; horloge reculée → jamais de `current` négatif ; `lastGradedDay` corrompu →
`started` au lieu de `catch (e) { // Silent fail }` (`:169`).

**Lignes hôte supprimées : 59.**

⚠️ **Divergence métier à arbitrer** (§ 4, R5) : l'hôte exclut le seul `listOnly` (`:119-122`) ;
`_gradedModes` (`z_advance_streak.dart:77-80`) n'admet que `spaced` et `learn` — donc `test`,
`whiteExam` et `cramming` **cessent** de faire avancer la flamme.

### M2 — L'écran de session assemblé : `ZStudySessionHost`

| | |
|---|---|
| **API** | `ZStudySessionHost({mode, queue, reviewer, config, cardBuilder, contentBuilder, evaluationPort, hintPort, headerBuilder, counterBuilder, gradingBuilder, summaryBuilder, emptyBuilder, celebrationBuilder, labels, onSessionEnd, onExit, indexController, progressStyle, …})` — **27 paramètres**, 2 requis |
| **Socle** | `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart:120` (674 l.) ; table de runtime `zcrud_session/…/z_session_runtime.dart:64` ; vue `z_study_session_view.dart:141` ; tranches `z_study_session_slices.dart:139` ; enveloppe `z_study_session_scaffold.dart:64` |
| **Hôte** | `…/pages/folder_flashcards_repetitions_page.dart` (**1 202 l.**) + `…/pages/flashcards_learning_celebration_page.dart` (**403 l.**) |

**Les six modes correspondent 1 : 1**, vérifié des deux côtés :

| `FlashcardRepetitionPageType` (`folder_flashcards_repetitions_page.dart:30-36`) | `ZReviewMode` (`z_review_mode.dart:22-37`) | runtime désigné (`z_session_runtime.dart:64-69`) |
|---|---|---|
| `nFlashcardsLearningCycle` | `learn` | `srsEngine` |
| `allFlashcardsLearningCycle` | `spaced` | `srsEngine` |
| `listOnly` | `list` | `linear` |
| `test` | `test` | `whiteExam` |
| `whiteExam` | `whiteExam` | `whiteExam` |
| `cramming` | `cramming` | `linear` |

**Corps vérifié** : `zSessionRuntimeForMode` est un `switch` **exhaustif sans `default`** (un 7ᵉ mode
casse la compilation) ; `ZStudySessionEngine` (`z_study_session_engine.dart:116`) porte un
`assert(mode == spaced || mode == learn)` et **détient seul** le `ZSessionReviewer` ;
`ZWhiteExamSessionEngine` n'a **aucun paramètre `reviewer`** — l'absence d'écriture SRS est
structurelle, pas assertive.

**Lignes hôte supprimées : ≈ 1 605.**

### M3 — L'examen blanc : moteur, phases, scoring, correction différée

| | |
|---|---|
| **API** | `ZWhiteExamSessionEngine` + `ZWhiteExamState` + `ZWhiteExamPhase{setup,running,submitted}` + `ZExamScoringPort` + `scoreWhiteExam` + `ZWhiteExamSessionController` + `ZWhiteExamSessionView` + `ZCorrectionVisibility.deferred` |
| **Socle** | `zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:274 / :90 / :64 / :218 / :239` ; `…/z_white_exam_session_controller.dart:53` ; `…/presentation/z_white_exam_session_view.dart:79` ; `…/z_correction_visibility.dart:29` ; `…/z_list_session_view.dart:128` |
| **Hôte** | `…/pages/white_exam_page.dart` (**779 l.**) + `…/widgets/white_exam_question_card.dart` (**1 139 l.**) |

**Corps vérifié** : `scoreWhiteExam` (`:239-269`) compte `quality >= passThreshold`, produit
`byQuality` et un `ZStudySessionResult(mode: whiteExam)` — agrégat pur, **jamais** une écriture SRS.
`ZCorrectionVisibility.deferred` (`:41`) **pose** la correction (saisie verrouillée, une réponse par
carte) mais **ne la peint pas** — exactement la sémantique du `bool _isSubmitted` de l'hôte
(`white_exam_page.dart:50,290-291`), en trois états au lieu de deux et avec un `switch` exhaustif
qui interdit la dérive de polarité que le socle documente (`z_correction_visibility.dart:44-60`).
`ExamAnswer.iDontKnow` (`white_exam_page.dart:778`) a son pendant : `_submitDontKnow`
(`z_flashcard_answer_input.dart:652`, bouton `:1429`), qui rend `config.minQuality`.

**Lignes hôte supprimées : ≈ 1 918.**

### M4 — Les filtres test/examen : `zApplyTestFilters` + `ZStudySessionSelector`

| | |
|---|---|
| **API** | `zApplyTestFilters(cards, {srsById, filters, config, selector, random})` ; `ZFlashcardTestFilters{questionCount, masteryLevels, sources}` ; `zMasteryLevelOf(info, config)` ; `ZMasteryLevel{bad,good,mastered}` ; `zIndexSrsById(infos)` ; `ZStudySessionSelector(config).matches` |
| **Socle** | `zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:206 / :107 / :75 / :34` ; `…/z_session_categorization.dart:56` ; `zcrud_study_kernel/…/z_study_session_selector.dart:34` |
| **Hôte** | `lib/src/utils/flashcard_filters.dart` (**90 l.**) |

**Les seaux de maîtrise coïncident à la borne près**, vérifié par lecture des deux corps :

| Seau | Hôte (`flashcard_filters.dart:38-52`) | Socle (`zMasteryLevelOf` + `ZSrsConfig`) |
|---|---|---|
| mauvais / `bad` | `quality` 1-2, **plus** `quality == 0` (jamais pratiquée) | `< passThreshold` (**3**), plus `info == null` / `repetitions == 0` ⇒ **[0..2]** |
| bon / `good` | `quality == 3` | `[passThreshold .. masteredThreshold-1]` = **[3]** |
| maitrise / `mastered` | `quality` 4-5 | `>= masteredThreshold` ; `masteredThreshold => maxQuality - 1` (`z_srs_config.dart:148`) = **4** ⇒ **[4,5]** |

Deux défauts de l'hôte que le corps du socle ferme :
1. **quadratique** — `repetitions.firstWhere(...)` **par carte** (`flashcard_filters.dart:27`) ⇒ O(n²) ; le socle fait un lookup `srsById[id]` (`z_flashcard_filters.dart:221`), avec l'indexation exposée à part (`zIndexSrsById`).
2. **aléa capturé** — `filtered.shuffle(Random())` (`:85`) ; le socle exige `required Random random` (`:213`), donc un tirage reproductible en test.

**Lignes hôte supprimées : 90.** ⚠️ **Incomplet sans G1** (filtre par `documentsIds`/`notesIds`).

### M5 — Le dialogue de filtres : `ZTestFiltersDialog`

`packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:54` (411 l., params
`initial` / `availableSources` / `minQuestionCount` / `maxQuestionCount`) remplace
`…/widgets/test_exam_filter_screen.dart` (**134 l.**). **Lignes hôte supprimées : 134.**

### M6 — Le sélecteur de modes : `ZSessionModeSelector` + `zCategorize`

| | |
|---|---|
| **API** | `ZSessionModeSelector({cards, srsById, at, streak, onStart, batchSize = 30, onOpenFilters})` ; `ZSessionModeKind{learnNew, review, test, cramming}` ; `zCategorize(cards, {srsById, at})` → `ZSessionCategories{neverLearned, due}` |
| **Socle** | `zcrud_session/…/z_session_mode_selector.dart:89 / :63` ; `zcrud_flashcard/…/z_session_categorization.dart:91 / :30` |
| **Hôte** | `FlashcardsLearningModeScreen`, `…/widgets/flashcard_widgets.dart:756` (**≈ 490 l.**), tuiles `:961` / `:1015` / `:1053` |

**Corps vérifié** : `zCategorize` (`:91-…`) classe en `neverLearned` (`info == null || repetitions == 0`)
et `due` (`repetitions > 0 && nextReviewDate <= at`), avec un **tri décoré par index** parce que
`List.sort` n'est pas stable en Dart — l'hôte n'a pas cette garantie.

🔴 **Le socle sert une tuile que l'hôte a mise en commentaire** : `ZSessionModeKind.cramming`
(`:84`) couvre le « Croulage (Cramming) » commenté à `flashcard_widgets.dart:1216`.
⚠️ La tuile « Examen Blanc » (`:1135`) reste hors couverture — voir **G2**.

**Lignes hôte supprimées : ≈ 490.**

### M7 — Le résumé de fin : `ZSessionSummaryView` + `ZSummaryCelebration`

`zcrud_session/…/z_session_summary_view.dart:206` (846 l., 12 params) + `ZSummaryCelebration:62`
(`none`/`subtle`/`confetti`) + `ZCelebrationSpec:82` + `ZSessionQualityBreakdown`
(`z_session_quality_breakdown.dart:41`) + `ZStudyProgressRings` (`z_study_progress_rings.dart:78`)
remplacent `…/pages/flashcards_learning_celebration_page.dart` (**403 l.**, déjà compté en M2).

**Compatibilité tierce vérifiée** : `confetti: ^0.8.0` des **deux** côtés
(`iffd/pubspec.yaml:172`, `zcrud_session/pubspec.yaml`). Le socle ne construit **jamais** le
`ConfettiWidget` sous Reduce Motion (`z_session_summary_view.dart:70-76`), ce que l'hôte ne fait pas.

### M8 — La pile et la progression : `ZSessionCardSwiper` + `ZSessionProgressIndicator`

| | |
|---|---|
| **API** | `ZSessionCardSwiper({queue, cardBuilder, passThreshold, onIndexChanged, onStackEnd, emptyBuilder, progressStyle, qualityOf, swipeDuration, indexController})` ; `ZSessionProgressIndicator({total, currentIndex, passThreshold, style, qualityOf, labelKeyFor, colorKeyFor, linearThickness})` ; `ZSessionProgressStyle` ; `ZSwipeEmotionIndicator` |
| **Socle** | `zcrud_session/…/z_session_card_swiper.dart:134` (648 l.) ; `…/z_session_progress_indicator.dart:77 / :46 / :380` (502 l.) |
| **Hôte** | `folder_flashcards_repetitions_page.dart:1-11` câble **trois** paquets tiers à la main |

**Compatibilité tierce vérifiée** : `flutter_card_swiper` — hôte `^7.0.2`
(`iffd/pubspec.yaml:177`), socle `^7.2.0` : **compatible** (même majeure, caret).
L'adoption **retire deux dépendances tierces directes** de l'hôte : `dots_indicator: ^4.0.1`
(`:191`) et `segmented_progress_bar: ^1.2.0` (`:192`) — leurs deux rôles sont les variantes de
`ZSessionProgressStyle`. Le swiper du socle porte en plus des **boutons de navigation accessibles**
et ramène `swipeDuration` à zéro sous Reduce Motion (`zReduceMotionOf`).

### M9 — Cesser d'envoyer les QCM et vrai/faux à l'IA

| | |
|---|---|
| **API** | `zIsLocallyEvaluatedType(type)` + `zEvaluateLocally({card, selectedChoiceIndexes, answeredTrue, config})` + `zCorrectChoiceIndexes(card)` — **déjà appelés à l'intérieur** de `ZFlashcardAnswerInput` |
| **Socle** | `zcrud_flashcard/…/z_flashcard_local_evaluation.dart:36 / :96 / :66` ; routage : `zcrud_session/…/z_flashcard_answer_input.dart:564` (`if (zIsLocallyEvaluatedType(widget.card.type)) { _submitLocal(); return; }`), évaluation `:539` |
| **Hôte** | `…/widgets/interactive_flashcard_repetition_card.dart:206` (`_evaluateAnswer`) — appelle `aiRepositoryProvider.evaluateFlashcardAnswer` **pour les quatre types**, y compris QCM et vrai/faux, et ne retombe sur `_manualEvaluateAnswer` (`:246`) qu'en cas d'échec |

🔴 **Le socle décide par le TYPE, avant tout appel réseau** ; l'hôte décide **après** l'échec du
réseau. `_manualEvaluateAnswer` rend `isCorrect ? 5 : 1` — exactement `config.maxQuality` /
`config.minQuality` de `zEvaluateLocally`, avec en plus l'**égalité ensembliste stricte** que le
socle impose (`z_flashcard_local_evaluation.dart:96-…` : une bonne réponse manquante ⇒ faux, une
mauvaise cochée ⇒ faux) et la garde « QCM sans choix correct ⇒ `null`, jamais récompensé ».

Coût supprimé : un aller-retour IA **par carte QCM/vrai-faux**, sur des cartes exactement évaluables.
**Aucune ligne nouvelle** : le jumeau `review_session_zcrud.dart` consomme déjà
`ZFlashcardAnswerInput` — il suffit de basculer `reviewSession`.

### M10 — 🔴 `ZSrsConfig(minQuality: 1)` : un défaut LATENT déjà sur disque

**Ce n'est pas une capacité oubliée, c'est un bug écrit et non encore basculé.**

1. `kIffdSrsConfig = ZSrsConfig(overdueBonusFactor: 0.5)` — `iffd/lib/src/domain/models/flashcard_repetition_info.dart:57`. **`minQuality` reste au défaut `0`** (`packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart:27`).
2. `ZQualityScale get iffdQualityScale => ZQualityScale.fromConfig(kIffdSrsConfig);` — `iffd/…/zcrud/srs_quality_zcrud.dart:101`. `fromConfig` lit `min = config.minQuality` (`z_srs_quality_buttons.dart:53`), et `qualities => [for (var q = min; q <= max; q++) q]` (`:65`) ⇒ **`[0,1,2,3,4,5]`**.
3. `ZSrsQualityButtons` rend **un bouton par qualité** — corps vérifié : `for (final quality in scale.qualities)` (`z_srs_quality_buttons.dart:271`).
4. `iffdQualityLabelKey(0)` ne trouve aucun palier (l'enum va de 1 à 5) et retombe sur `orElse: () => FlashcardRepetitionQuality.good` (`srs_quality_zcrud.dart:113-116`) ⇒ **le bouton « 0 » s'affiche « Ok »**.

⇒ À la bascule du drapeau `srsQuality`, l'hôte afficherait **six** paliers dont un « Ok » qui écrit
la note la plus basse de SM-2. Le fichier affirme pourtant en dartdoc « IFFD ne PROPOSE aujourd'hui
que 1..5 à l'utilisateur » (`:78`) — sa propre config le contredit.

**Correctif : un paramètre.** `ZSrsConfig(minQuality: 1, overdueBonusFactor: 0.5)`. `minQuality: 1`
est explicitement admis (`assert(minQuality == 0 || minQuality == 1)`, `z_srs_config.dart:59-66`),
documenté « sans blackout ».

### M11 — 🔴 `ZHintPenaltyPolicy` : la parité annoncée par le jumeau est FAUSSE

`iffd/…/zcrud/review_session_zcrud.dart:26` écrit, dans sa table de négociation de surface :
« `hintPolicy` → défaut socle → *le legacy compte les indices sans les pénaliser* ».

**Mesuré : le défaut socle pénalise.** `_finalQuality` appelle `zApplyHintCeiling`
**inconditionnellement, sur tous les chemins** — `z_flashcard_answer_input.dart:502-507`, dartdoc du
corps : « Voie unique d'attribution : le plafond d'indices est appliqué en dernier, sur la valeur
rendue, sur tous les chemins ». Avec `ZHintPenaltyPolicy()` nu, `zHintCeilingFloor` rend
`passThreshold - 1 = 2` (`z_hint_penalty.dart:80-88`) et `ceiling = max(maxQuality - hintsUsed, 2)`
(`:99`) ⇒ **chaque indice consommé abaisse la note d'un cran**.

Absence de plafond côté hôte, grep négatif montré :

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn --include='*.dart' -iE 'hintCeiling|hintPenalty|ceiling' lib
$ echo "RC=$?"
RC=1
```

**Correctif : un paramètre.** `hintPolicy: ZHintPenaltyPolicy(floor: 5)` neutralise le plafond —
`floor = max(5, 2) = 5`, `ceiling = max(5 - used, 5) = 5`, `min(raw, 5) = raw`. Si au contraire le
propriétaire **veut** la pénalité, il n'y a rien à faire — mais il faut le décider, pas le subir.

### M12 — L'export PDF local : `zcrud_export_pdf`

| | |
|---|---|
| **API** | `ZFlashcardPdfTemplate({rasterizer, options, fontProvider, fallbackFontProviders})` ; `ZFlashcardPdfInput{title, cards, labels}` ; `ZFlashcardPdfCard` ; `ZFlashcardPdfLabels` ; `ZAnswerVisibility` ; `ZPdfExportOptions` ; `buildPdfBytes` ; `ZPdfCreationService` ; `ZFileSaver` |
| **Socle** | `packages/zcrud_export_pdf/lib/src/data/z_flashcard_pdf_template.dart:51` ; `…/z_flashcard_pdf_input.dart:190 / :59 / :103` ; `…/z_answer_visibility.dart:12` ; `…/z_pdf_export_options.dart:119` |
| **Hôte** | `…/widgets/export_flashcards_to_pdf.dart` (**390 l.**) |
| **Blocage levé** | cf. § 0, R2 et R3 : `zcrud_export_pdf/pubspec.yaml:39` n'exige que `syncfusion_flutter_pdf: ^34.1.31`, que `iffd/pubspec.yaml:145` déclare **déjà**. `zcrud_export` (et donc `xlsio`) n'est **pas** dans la chaîne |

🔴 **Ce que l'adoption change vraiment** : aujourd'hui l'hôte **envoie ses flashcards sérialisées à
un backend IA** pour fabriquer le PDF — `export_flashcards_to_pdf.dart:61-89`, `dio.post` vers
`…${AiRepository.convertFlashcardsToPdfEndpoint}` avec `json.encode(toMapList(flashcards))`, réponse
en bytes. Le socle produit les bytes **localement** (`bytes in → bytes out`, dartdoc du corps),
avec un port de rasterisation LaTeX injecté (repli texte brut, ne lève jamais) et une **chaîne de
polices de repli** par suite de caractères (`fallbackFontProviders`, `:75-98`) — sans quoi un
document mêlant latin et arabe est impossible.

⚠️ `zcrud_export_pdf` n'est **pas** déclaré chez l'hôte. Un `grep 'zcrud_export'` nu **hit** —
mais **uniquement des commentaires** (`pubspec.yaml:292, 326, 337, 710-712`, tous préfixés `#`), dont
un qui annonce un override « AJOUTÉ EN v0.16.0 » qui **n'existe plus**. Le grep qui prouve
réellement l'absence porte sur les entrées **non commentées** et sur le verrou :

```
$ cd /home/zakarius/DEV/iffd
$ grep -n '^\s*zcrud_export' pubspec.yaml ; echo "RC=$?"
RC=1
$ grep -n 'zcrud_export' pubspec.lock ; echo "RC=$?"
RC=1
```

⇒ l'adoption demande une entrée `dependencies` **et** un override, et la fermeture transitive doit
être vérifiée (le motif « TROISIÈME OCCURRENCE » de `iffd/pubspec.yaml:334-339`).

**Lignes hôte supprimées : 390** (+ une dépendance réseau).

### M13 — Les couleurs : `ZcrudTheme.flashcardTypeGradients` et les jetons de session

| | |
|---|---|
| **API** | `ZcrudTheme(flashcardTypeGradients: Map<String, ZGradientSpec>?)` + `studySessionStackFlex` / `studySessionInputFlex` / `studySessionContentPadding` / `studySessionDividerThickness` / `studySessionSectionGap` / `studySessionMinTarget` / `studySessionCounterStyle` ; `zReadableTypeTint` ; `ZFlashcardCardReference` ; `ZStudySessionReference` |
| **Socle** | `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:1486` (`flashcardTypeGradients`), `:1600 / :1608 / :1612 / :1615 / :1619 / :1630 / :1634` ; `zcrud_study/…/z_default_flashcard_card.dart:150` ; `…/z_flashcard_card_reference.dart:53` ; `…/z_study_session_reference.dart:32` |
| **Hôte** | **313** `Colors.<nom>` + **89** `Color(0x…)` + **19** `LinearGradient(` dans les 35 fichiers du périmètre ; `_getTypeIcon` dupliqué **3 fois** (`white_exam_question_card.dart:97`, `interactive_flashcard_repetition_card.dart:115`, `flashcard_repetition_widgets.dart:63`) |

L'hôte ne pose **aucun** de ces huit jetons. Grep négatif montré :

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn --include='*.dart' 'flashcardTypeGradients\|studySession' lib
$ echo "RC=$?"
RC=1
```

Cible principale : `…/widgets/flashcard_repetition_widgets.dart` (**717 l.** de dégradés, badges de
type et pastilles).

### M14 — Le feedback pédagogique localisé : `ZFeedbackBank`

`zcrud_session/…/z_session_feedback_bank.dart:38` (`ZFeedbackBank`), `:51`
(`ZDefaultFeedbackBank` — **texte FR déjà embarqué**, quatre seaux, repli anglais), `:99`
(`zFeedbackText`), `:118` (`ZSessionFeedbackText`) ; sélection pure
`z_session_feedback.dart:104` (`zFeedbackTierFor(qualité, temps, indices)` → clé l10n) et `:48`
(`ZFeedbackThresholds`).

Le périmètre hôte compte **120** littéraux français en dur dans **24** fichiers et **zéro** appel de
localisation (grep négatif § 0). `zFeedbackText` passe le texte en `fallback:` de `label()`, donc
`ZcrudScope.labels` de l'hôte **garde la priorité** (`:105-109`) — l'adoption n'impose aucune table.

### M15 — Le libellé « à revoir dans… » cesse d'être décoratif

`srs_quality_zcrud.dart:120-127` qualifie les libellés `repeatIn` de l'hôte de « **décoratif, pas
informatif** », parce que `Sm.calc` calcule des **jours** et non des positions de file.

**Mesuré : sous `ZStudySessionEngine`, ils deviennent littéralement vrais.**
`kLapseOffsetSoft = 2` (`z_study_session_engine.dart:41`), `kLapseOffsetHard = 4` (`:45`),
`kLapseSoftMaxQuality = 1` (`:50`), reducer `reduceGrade` (`:69-95`) — tous **publics et exportés**
(`zcrud_session.dart:39`).

| Palier hôte | `repeatIn` annoncé | Comportement réel de `reduceGrade` |
|---|---|---|
| `fail(1)` | « dans 2 cartes » | `q <= 1` ⇒ offset **+2** ✅ |
| `hard(2)` | « dans 4 cartes » | `q == 2 < passThreshold` ⇒ offset **+4** ✅ |
| `good(3)` / `easy(4)` | « à la fin » | `q >= 3` ⇒ carte **consommée**, jamais réinsérée ✅ |

**Aucune ligne à écrire** — c'est un gain de véracité obtenu par la bascule de M2.

---

## 3. MANQUE AU SOCLE

| # | Ce qui manque | Forme | Paquet | Pourquoi l'hôte ne peut pas s'en passer | Bloque une capacité ? |
|---|---|---|---|---|---|
| **G1** | **Filtre par IDENTIFIANT de source** (`documentId`, `noteId`) | un champ `sourceIds: Set<String>` sur `ZFlashcardTestFilters` **et** `ZFlashcardBrowseFilters`, plus un prédicat partagé `zMatchesSourceId` — jumeau exact de `zMatchesSourceKind` | `zcrud_flashcard` | L'hôte filtre sur les deux (`utils/flashcard_filters.dart:66-80`) et l'écran « Paramètres des flashcards » les expose (`docs/qa-plan-comparaison-legacy-zcrud.md:257`). Le socle **porte la donnée** (`ZNoteSource.noteId` `z_flashcard_source.dart:98`, `ZDocumentSource.documentId` `:159`) mais **ne filtre que par `kind`** (`zMatchesSourceKind` `:180`) — quatre `kind` seulement, jamais un identifiant | 🔴 **OUI** — M4 et M5 sont incomplets sans lui ; le drapeau `folderFlashcardsFilter` ne peut pas basculer à parité |
| **G2** | **`ZSessionModeKind.whiteExam`** | une 5ᵉ valeur d'enum + sa tuile dans le sélecteur | `zcrud_session` | `ZReviewMode.whiteExam` existe, `ZWhiteExamSessionEngine`/`View` existent — mais **rien ne propose l'examen blanc** dans `ZSessionModeSelector` (4 valeurs : `learnNew`/`review`/`test`/`cramming`). L'hôte a cette tuile, en commentaire (`flashcard_widgets.dart:1135`) | 🔴 **OUI** — M6 ne peut pas restituer l'entrée « Examen Blanc » |
| **G3** | **Persistance / port du streak** | soit un port `ZStreakStore` (patron `ZRepetitionStore`), soit un adaptateur documenté | `zcrud_study_kernel` (port) + `zcrud_firestore` (adaptateur) | `zAdvanceStreak` est **pur** : rien ne stocke `ZStudyStreak`. L'hôte le garde sur `AppUserData.currentStreak`/`lastStudyDate` (`domain/models/app_user.dart:273`). ⚠️ **La forme stockée diffère** : le socle clé sur `lastGradedDay` (`String` `yyyy-MM-dd`), l'hôte sur un `DateTime` — une migration de données est requise, pas seulement un câblage | Non (l'hôte peut posséder la persistance) — mais c'est la pièce qui **fait atterrir M1** |
| **G4** | **Gamification au-delà de la flamme** — points, badges, niveaux, classement | entités + agrégats + rendus | n'existe nulle part | Le socle n'en a **rien** ; le seul hit est un `trophyIcon` décoratif (`z_session_summary_view.dart:98,147,587`, 11 lignes au total). **Mais l'hôte n'en a rien non plus** : `lib/src/features/gamification/gamification_module.dart` fait **0 ligne**, et `grep -rn -iE '\bxp\b\|badge\|leaderboard\|trophy\|achievement\|level_?up' iffd/lib` → **0** | **Non — ce n'est pas un écart de migration.** Le domaine « gamification » est **vide des deux côtés** ; sa seule mécanique réelle est la flamme (M1) |

Grep négatif de G1 montré :

```
$ cd /home/zakarius/DEV/zcrud/packages
$ grep -rn 'noteId\|documentId' zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart ; echo "RC=$?"
RC=1
$ grep -rn 'sourceIds\|Predicate\|extraFilter\|customFilter' zcrud_flashcard/lib/ | grep -v '\.g\.dart' ; echo "RC=$?"
RC=1
```

Grep négatif de G2 montré :

```
$ grep -n 'whiteExam' zcrud_session/lib/src/presentation/z_session_mode_selector.dart ; echo "RC=$?"
RC=1
```

Grep négatif de G4 montré (les 41 paquets) :

```
$ grep -rn --include='*.dart' -iE '\bxp\b|leaderboard|achievement|levelUp|level_up' */lib | grep -v '\.g\.dart' ; echo "RC=$?"
RC=1
$ grep -rn --include='*.dart' -i 'trophy' */lib | grep -v '\.g\.dart' | wc -l
11        # toutes dans z_session_summary_view.dart : une icône, pas un système
```

---

## 4. RESTE À L'HÔTE — règle métier IFFD

Le socle ne porte pas de règle métier. Ces huit points ne sont pas des manques : ce sont les
paramètres que les seams du socle **attendent** de l'hôte.

| # | Règle | Où elle vit | Comment le socle l'accueille |
|---|---|---|---|
| **R1** | **Système Harmonisé douanier** — `hsSection`/`hsChapter`, fabrication de flashcards depuis un corpus d'avis de classement, plus le bloc « outils de valeur en douane » du filtre | `domain/models/flashcard_model.dart:106-107`, `:330-346` ; `docs/qa-plan-…:257` | `ZFlashcard.extra` + `ZExtension` (AD-4) ; le filtre reste hôte, au-dessus de `zApplyTestFilters` |
| **R2** | **Partition par année académique** — le SRS d'IFFD est cloisonné par `accademicYear` | `domain/models/flashcard_repetition_info.dart:236` | hors schéma `ZRepetitionInfo` ⇒ `extra` / clé de collection côté adaptateur |
| **R3** | **Cinq paliers : libellés, icônes, couleurs, `repeatIn`** | `flashcard_repetition_info.dart:181-189` | **par conception** : `ZSrsQualityButtons` prend `labelKeyFor` / `previewLabelFor` / `colorKeyFor` — il n'écrit aucun libellé (`zDefaultQualityLabelKey:183` ne rend qu'une **clé**) |
| **R4** | **`overdueBonusFactor: 0.5`** — le bonus de retard SM-2 | `flashcard_repetition_info.dart:57` | défaut socle `0.0` (`z_srs_config.dart:25`, opt-in CR-LEX-37). 🔴 **doit rester déclaré explicitement** : l'omettre supprimerait le bonus en silence |
| **R5** | **Quels modes font avancer la flamme** | hôte : tout sauf `listOnly` (`folder_flashcards_repetitions_page.dart:119-122`) | socle : `spaced` + `learn` seuls (`_gradedModes`, `z_advance_streak.dart:77-80`). ⚠️ **Arbitrage propriétaire** : adopter M1 tel quel **retire** `test`, `whiteExam` et `cramming` du décompte |
| **R6** | **Validation QCM** — « ≥ 2 choix, ≥ 1 correct » | divergence déjà consignée par l'hôte, `shared/zcrud/z_iffd_field_registry.dart:150-170` | `ZFlashcardEditionValidator` impose la règle ; le legacy IFFD ne valide rien ⇒ des QCM à une proposition, aujourd'hui acceptés, seront refusés. **Arbitrage propriétaire** |
| **R7** | **La flamme vit sur `AppUserData`** + le modèle de permissions | `domain/models/app_user.dart:273` ; `domain/security/app_user_permissions.dart` | cf. G3 : le socle calcule, l'hôte possède |
| **R8** | **Lecture défensive des nombres Firestore** (`2.0` rendu là où `2` a été écrit) | `flashcard_repetition_info.dart:207-221` (`_intOrNull`) | quirk de persistance de l'hôte ; à conserver dans son adaptateur, hors du domaine |

---

## 5. Ce que ça pèse

### Lignes d'hôte supprimables

| Fichier / bloc hôte | lignes | remplacé par | supprimable |
|---|---:|---|---:|
| `pages/folder_flashcards_repetitions_page.dart` | 1 202 | `ZStudySessionHost` (M2) | 1 202 |
| `widgets/white_exam_question_card.dart` | 1 139 | `ZFlashcardAnswerInput(deferred)` + `ZWhiteExamSessionView` (M3) | 1 139 |
| `widgets/interactive_flashcard_repetition_card.dart` | 1 205 | jumeaux déjà écrits (311 l.) — M9 | 894 |
| `pages/white_exam_page.dart` | 779 | `ZWhiteExamSessionEngine`/`Controller` (M3) | 779 |
| `widgets/flashcard_repetition_widgets.dart` | 717 | badges/dégradés par jetons (M13) | 717 |
| `FlashcardsLearningModeScreen` (`flashcard_widgets.dart:756`) | ≈ 490 | `ZSessionModeSelector` + `zCategorize` (M6) | 490 |
| `pages/flashcards_learning_celebration_page.dart` | 403 | `ZSessionSummaryView` (M7) | 403 |
| `widgets/export_flashcards_to_pdf.dart` | 390 | `ZFlashcardPdfTemplate` (M12) | 390 |
| classe `Sm` + `getNextIntervalString` (`flashcard_repetition_info.dart`) | 489 | `ZSm2Scheduler` (drapeau existant) | ≈ 250 |
| `data/repositories/firebase_owner_scoped_repetition_store.dart` | 154 | **code mort** — suppression sèche | 154 |
| `widgets/test_exam_filter_screen.dart` | 134 | `ZTestFiltersDialog` (M5) | 134 |
| `utils/flashcard_filters.dart` | 90 | `zApplyTestFilters` (M4) | 90 |
| `_checkAndUpdateStreak` (`…repetitions_page.dart:113-171`) | 59 | `zAdvanceStreak` (M1) | 59 |
| 3 échafaudages plein écran du périmètre (`label: 'Enregistrer'`) | ≈ 75 | `presentEdition(chrome:)` + `ZEditionScaffold` | ≈ 75 |
| **Total** | | | **≈ 6 776** |

Soit **≈ 37 %** des 18 178 lignes de `features/flashcards/`, avant même de compter les 105 lignes de
code mort commenté de `flashcard_widgets.dart` et les 2 répertoires vides.

### Dépendances tierces retirées

`dots_indicator ^4.0.1`, `segmented_progress_bar ^1.2.0` (M8) ; un aller-retour réseau par export
PDF (M12) ; un aller-retour IA par carte QCM/vrai-faux (M9).

### Deux défauts déjà écrits, corrigés par un paramètre chacun

`ZSrsConfig(minQuality: 1)` (M10, six boutons dont un « Ok » à note 0) et
`ZHintPenaltyPolicy(floor: 5)` (M11, pénalité d'indice non voulue). **Les deux mordraient à la
première bascule de drapeau** — ce sont les corrections à faire **avant** la QA, pas après.

### Le vrai goulot n'est pas le socle

Le portage du domaine est **écrit et éteint** : 15 jumeaux, 2 512 l., **52** drapeaux à `false`
contre **1** à `true`, **198** cases de QA vides sur 198. `zcrud_session` pèse 8 462 l. et 28
fichiers ; l'hôte n'en appelle réellement que **quatre** symboles (`ZFlashcardAnswerInput`,
`ZFlashcardSubmission`, `ZQualityScale`, `ZSrsQualityButtons`) — **92,6 %** de sa surface publique
n'est appelée nulle part, moteurs et écrans compris (§ 0, R5).

---

## 6. Ce que je n'ai PAS mesuré

- **Aucun test lancé**, dans aucun dépôt. Rien ici n'atteste qu'un canal *fonctionne* — seulement
  qu'il *existe*, à telle ligne, avec tel corps.
- **La composabilité bout à bout** de `ZStudySessionHost` sur des données IFFD réelles : j'ai
  vérifié les signatures, les corps et la correspondance des six modes, **pas** un montage compilé.
- **La fermeture transitive** de `zcrud_export_pdf` chez l'hôte (M12) : la contrainte Syncfusion est
  satisfaite, le graphe complet ne l'a pas été résolu.
- **La migration de données** du streak (`DateTime` → `yyyy-MM-dd`, G3) : forme identifiée, volume
  et procédure non établis.
- **Les 26 bascules de l'aire Étude** du registre QA n'ont pas été croisées une à une ; seules les
  15 du périmètre révision l'ont été.
