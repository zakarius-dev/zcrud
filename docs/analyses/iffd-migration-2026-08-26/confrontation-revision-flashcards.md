# Confrontation — domaine « Révision : flashcards, écrans, édition, tags, export » (IFFD ⇄ socle zcrud)

> Mesuré le **2026-08-26**. Hôte : `/home/zakarius/DEV/iffd` à `65d1af9` (lecture seule).
> Socle : `/home/zakarius/DEV/zcrud/packages` à `cc276c154` (tag **v3.21.0**), 41 paquets.
> Entrées : `carte-revision-flashcards.md` (26 000 o, **présente**) + les cinq
> `capacites-zcrud-*.md`. **Aucun constat repris sans remesure** ; chaque ligne porte son
> `fichier:ligne`. Aucun test lancé (consigne).

---

## 0. Le cadrage qui commande la lecture

**IFFD est déjà sur `v3.21.0`** (`iffd/pubspec.yaml:305-530`, 25 entrées `ref: v3.21.0`). Tous les
canaux cités ci-dessous sont donc **déjà résolus, déjà compilés dans son binaire**. « Migrable
aujourd'hui » ne veut jamais dire « après une montée de tag » : ça veut dire **appeler ce qui est
déjà là**.

Corollaire vérifié pour cette aire : `git diff --stat v3.12.0 v3.21.0 -- packages/zcrud_session
packages/zcrud_flashcard packages/zcrud_study` ne rend **que des bumps de `pubspec.yaml`**. La vague
3.13 → 3.21 est une vague « formulaires » (`zcrud_core`, `zcrud_markdown`, `zcrud_select`,
`zcrud_responsive`). Rien de neuf n'est arrivé dans la révision : ce qui manque à l'hôte lui manque
**depuis le 12 août**, pas depuis avant-hier.

### Chiffres du périmètre, remesurés

| Grandeur | Valeur | Commande |
|---|---:|---|
| Fichiers `features/flashcards/**` | **35** | `find … -name '*.dart' \| wc -l` |
| Lignes `features/flashcards/**` | **18 178** | `find … -exec cat {} + \| wc -l` |
| `DynamicFormField(` (D1) | **60** sur 7 fichiers | `grep -rn` |
| `setState(` (D4) | **72** | `grep -rn` |
| `CircularProgressIndicator` (D5) | **12** sur 7 fichiers | `grep -rn` |
| `AlertDialog(` (D13) | **3** sur 2 fichiers | `grep -rn` |
| Bascules `useZcrud`/`zcrudFlagValue` (D3) | **32** dans le périmètre | `grep -rn` |
| Drapeaux QA du domaine | **13** sur 52 (`z_qa_flags.dart:248,260,280,287,300,322,329,348,356,362,371,414,442`) | `grep -n "id: '…"` |
| Défaut de **tous** les drapeaux mesurés | **`false` (legacy)** | `flashcard_edition_zcrud.dart:78`, `srs_quality_zcrud.dart:46`, `review_session_zcrud.dart:55`, `flashcard_list_zcrud.dart:68` |

⚠️ **Rectification de la carte** : elle annonce 29 `RichTextReaderScreen(`. Remesuré :
**27** sites `RichTextReaderScreen(` dans tout `lib/` (29 est le compte des *mentions* dans le
périmètre flashcards, commentaires inclus).

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme réellement le canal

| # | Canal du socle | Site chez l'hôte | Réserve mesurée |
|---|---|---|---|
| A1 | **`ZFlashcardAnswerInput`** (`zcrud_session/…/z_flashcard_answer_input.dart:102`) | `zcrud/review_session_zcrud.dart:118` ; monté par `widgets/interactive_flashcard_repetition_card.dart:414` | 🔴 **6 paramètres passés sur 17.** `hintPort`, `evaluationPort`, `hintPolicy`, `timerDisplay`, `timeLimit`, `advanceBehavior`, `correctionVisibility`, `allowSkipEvaluation`, `revealStoredHint`, `autoAdvanceDelay` : **aucun**. Cf. § 2 M3/M4. |
| A2 | **`ZFlashcardReviewCard`** (`zcrud_flashcard/…/z_flashcard_review_card.dart:88`) + **`ZRevealTransition`** (`…/z_reveal_transition.dart:18`) | `zcrud/review_card_zcrud.dart:168`, `:173` (`ZRevealTransition.flip3d`) | Sans drapeau propre — atteint seulement par la branche portée de la session. |
| A3 | **`ZSrsQualityButtons`** (`zcrud_session/…/z_srs_quality_buttons.dart:187`) | `zcrud/srs_quality_zcrud.dart:175` | `ZQualityScale` et `ZSrsQualityEmphasis` non cités. |
| A4 | **`ZFlashcardListView`** (`zcrud_study/…/z_flashcard_list_view.dart:343`, **25 params**) | `zcrud/flashcard_list_zcrud.dart:163` ; branché à `pages/folder_flashcards_list_page.dart:515` | **9 params sur 25.** Ni `onDuplicate`, ni tri, ni sélection multiple, ni déplacement en lot — pourtant `duplicateAction:` est un libellé posé (`:214`). |
| A5 | **`ZMultiFlashcardEditor`** (`zcrud_study/…/z_multi_flashcard_editor.dart:242`) | `zcrud/multi_flashcard_editor_zcrud.dart:172` | `ZMultiFlashcardDraftController` jamais cité : le brouillon reste piloté par le widget. |
| A6 | **`ZFlashcardSubmission`** (`zcrud_session/…/z_flashcard_submission.dart:19`) | `widgets/interactive_flashcard_repetition_card.dart:448`, `zcrud/review_session_zcrud.dart:107` | Traduction assumée : `hintsUsed` (`int`) reconstruit en `List<String>.filled` (`:455`) — écart déclaré, non silencieux. |
| A7 | **`registerZFlashcardEditors`** (`zcrud_flashcard/…/z_flashcard_editors.dart:41`) | `shared/zcrud/z_iffd_field_registry.dart:171` | 🔴 **Enregistré mais jamais atteint** : aucun champ ne déclare `EditionFieldType.custom` + `ZFlashcardFieldConfig`. Cf. § 2 M9. |
| A8 | **`ZSm2Scheduler` / `ZSrsConfig`** (`zcrud_flashcard/…/z_sm2_scheduler.dart:23`, `z_srs_config.dart:17`) | `domain/models/flashcard_repetition_info.dart:57` (`kIffdSrsConfig = ZSrsConfig(overdueBonusFactor: 0.5)`), `:392` | Derrière une bascule à défaut `false`. |
| A9 | **`ZMarkdownReader`** (`zcrud_markdown/…/z_markdown_reader.dart:57`) | **2 montages du domaine** : `zcrud/flashcard_list_rich_reader_zcrud.dart:234`, `zcrud/review_rich_reader_zcrud.dart:213` (5 dans tout `lib/`) | Face à **27** `RichTextReaderScreen(` legacy. |
| A10 | **`ZTagEditor`** (`zcrud_study/…/z_tag_editor.dart:74`) | `features/folders/zcrud/folder_tags_zcrud.dart:167` | Hors périmètre flashcards, mais c'est bien le canal de balises. |
| A11 | **`ZFieldSpec` / `presentFormEdition`** | `zcrud/flashcard_edition_zcrud.dart:106-177`, `widgets/test_exam_filter_zcrud_screen.dart:110-180`, `zcrud/export_flashcards_to_pdf_zcrud_edition.dart` | 12 des 13 drapeaux du domaine reposent dessus. |

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte ne l'appelle pas

> Chaque ligne a été vérifiée **dans le corps** du canal, pas seulement dans sa dartdoc.
> Les greps d'absence chez l'hôte sont montrés en § 5.

### M1 — L'examen blanc entier : `ZListSessionView`, pas `ZWhiteExamSessionView`

**API exacte** : `ZListSessionView` — `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart:128`
(704 lignes), avec `ZExamViewPhase` (`:105`) et `ZExamAnswerCallback` (`:124`).
Moteur : `ZWhiteExamSessionEngine` (`…/domain/z_white_exam_session_engine.dart:274`, 420 l.),
contrôleur `ZWhiteExamSessionController` (`…/domain/z_white_exam_session_controller.dart:53`, 97 l.).

**Ce que le corps fait réellement** (lu, pas déduit) :
- `build` (`:258-330`) : `_ProgressHeader` + `ListView.builder` sur **toutes** les cartes
  (`itemCount: cards.length + (submitted ? 1 : 0)`) + `_submitBar` en phase `running` ;
- `submissions` est une `Map<int, ZFlashcardSubmission>` **indexée par position** (`:295`), avec
  filtre de bornes défensif (`_answeredInRange`, `:256`) ;
- chaque question monte `ZFlashcardAnswerInput` sous `IgnorePointer(ignoring: phase != running)`
  (`:373`), en `correctionVisibility: ZCorrectionVisibility.deferred` (`:404`) ;
- l'écran de fin est `ZSessionSummaryView` inséré à l'index 0, sous `Semantics(liveRegion: true)`
  (`:339-352`).

**Correspondance mesurée avec l'hôte** — `pages/white_exam_page.dart` (779 l.) :
`Map<String, ExamAnswer> _answers` (`:46`), `ListView.builder` sur toutes les cartes (`:157-303`),
barre de soumission (`:305-355`), `_buildStatsHeader` après soumission (`:144`),
`_submitExam` (`:439`). **La forme est la même, ligne pour ligne.**

🔴 **Le piège que je dois nommer** : `ZWhiteExamSessionView` (`z_white_exam_session_view.dart:79`)
est **le mauvais choix ici**. Son moteur est un curseur **strictement linéaire**
(`recordAnswer` : `cursor: state.cursor + 1`, `z_white_exam_session_engine.dart:231-235`), alors
qu'IFFD laisse répondre **dans n'importe quel ordre**. Le catalogue « étude-révision » les liste
côte à côte sans trancher ; c'est `ZListSessionView` qui correspond, et le moteur reste utilisable
parce que `scoreWhiteExam` (`:243`) est **commutatif** — le fichier le dit lui-même (`:212-218`).

**Lignes d'hôte économisées** : ~**600** (ossature de liste, barre de soumission, en-tête de stats,
dialogue de confirmation, écran de résultat).

⚠️ **Ce que `ZListSessionView` ne porte PAS** : le **marquage de question** (`_flaggedQuestions`,
`white_exam_page.dart:47`, `:255-270`). Grep négatif montré :
`grep -in "flag\|skip\|dontKnow\|unknown" z_list_session_view.dart` → **RC=1**. Le drapeau reste à
composer au-dessus (le socle n'interdit rien : la vue est un `Column` posable dans l'arbre de l'hôte).

### M2 — Les trois saisies recopiées (D6/D7/D8) : `ZFlashcardAnswerInput`

**API exacte** : `ZFlashcardAnswerInput` — `zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart:102`
(1 645 l., **17 paramètres**).

**Corps vérifié** : `_buildInput` (`:789-812`) est un `switch` **exhaustif** sur `ZFlashcardType` :
`multipleChoice → _ChoicesInput` (`:790`), `trueOrFalse → _TrueFalseInput` (`:797`),
`openQuestion | exercise | fillBlank | shortAnswer → _WrittenInput` (`:804-807`).
Il porte en plus, **nativement**, le bouton « Je ne sais pas » (`_DontKnowButton`, `:1430`, monté
`:771`, clé l10n `zcrud.flashcard.dontKnow`, `:1449`) — qu'IFFD remonte à la main dans
`white_exam_page.dart:226-250`.

**Sites d'hôte non migrés** (grep : ces deux fichiers ne portent QUE le drapeau
`reviewRichReader`, jamais `reviewSession`) :

| Fichier | Bloc | Lignes |
|---|---|---:|
| `widgets/white_exam_question_card.dart` (`:484`, `:747`, `:1071` = les seuls flags) | `_buildQCMInput` `:679-775` · `_buildTrueFalseInput` `:776-863` · `_buildTextInput` `:864-904` | 97 + 88 + 41 = **226** |
| `widgets/flashcard_repetition_widgets.dart` (`:194`, `:518` = les seuls flags) | `_buildChoicesSection` `:484-632` | **149** |

**Lignes économisées** : **375**.

### M3 — L'indice payant : `ZFlashcardHintPort` + `ZHintPenaltyPolicy`

**API exacte** : `ZFlashcardHintPort` — `zcrud_flashcard/lib/src/domain/z_flashcard_hint_port.dart:120`
(+ `ZFlashcardHintRequest` `:48`, qui porte `shownHints` anti-répétition `:71`) ;
plafond `ZHintPenaltyPolicy` / `zApplyHintCeiling` — `…/z_hint_penalty.dart:42` / `:110`.
Point d'injection : paramètre `hintPort` de `ZFlashcardAnswerInput` (`:111`), consommé `:683`
(`final port = widget.hintPort`), bouton `hintButtonKey` (`:1362`), libellé `zcrud.flashcard.hint`
(`:1401`), échec localisé `zcrud.flashcard.hintUnavailable` (`:706`, `:725`).

**Chez l'hôte** : `widgets/interactive_flashcard_repetition_card.dart` — `_indices` (`:95`),
`_currentHintIndex` (`:96`), `_requestHint` (`:331-390`, appel IA), bouton d'indice
(`:1021-1102`). Le fichier est **déjà** derrière le drapeau `reviewSession` (`:414`) — mais
`review_session_zcrud.dart:118-127` **ne passe pas `hintPort`**. ⇒ **la branche portée perd
aujourd'hui la fonction d'indice.** C'est un canal offert, câblé à moitié.

**Lignes économisées** : ~**130**.

### M4 — L'évaluation locale QCM / vrai-faux : `zEvaluateLocally`

**API exacte** : `zEvaluateLocally` — `zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:96` ;
`zCorrectChoiceIndexes` `:66` ; `zIsSingleChoiceQcm` `:56` ; `zIsLocallyEvaluatedType` `:36`.
Port consultatif pour les types libres : `ZFlashcardAnswerEvaluationPort`
(`…/z_flashcard_answer_evaluation_port.dart:218`), paramètre `evaluationPort`
(`z_flashcard_answer_input.dart:110`).

**Corps vérifié** : `zEvaluateLocally` rend `config.maxQuality` si exact, `config.minQuality`
sinon (`_qualityFor`, `:135`), avec **égalité ensembliste stricte** (`_setEquals`, `:139`) — jamais
une inclusion.

**Chez l'hôte** : `interactive_flashcard_repetition_card.dart:206-305` (`_evaluateAnswer`) fait
exactement `isCorrect ? 5 : 1` pour le QCM (`:293-301`) et le vrai/faux (`:304-305`) — soit
`maxQuality`/`minQuality` sur l'échelle `[0,5]` d'IFFD, en dur. Le même calcul est recopié dans
`white_exam_question_card.dart:616`, `:688-706`, `:811-821`.

**Lignes économisées** : ~**100**.

### M5 — Le filtre de test/examen : `zApplyTestFilters` + `zMasteryLevelOf` + `zDrawQuestions`

**API exacte** : `zApplyTestFilters` — `zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:206` ;
`ZFlashcardTestFilters` `:107` ; `zMasteryLevelOf` `:75` ; `ZMasteryLevel` `:34` ;
`zDrawQuestions` `:461` ; `zIndexSrsById` (`z_session_categorization.dart:56`).

**Équivalence des seuils, calculée sur disque et non supposée** :
`ZSrsConfig` — `minQuality = 0` (`z_srs_config.dart:27`), `passThreshold = 3` (`:26`),
`maxQuality = 5` (`:28`), **`masteredThreshold => maxQuality - 1` = 4** (`:148`).
`zMasteryLevelOf` donne donc : `bad = [0..2]` **jamais vue incluse** (`:74-79`),
`good = {3}`, `mastered = [4,5]`.
`iffd/lib/src/utils/flashcard_filters.dart:40-52` : `mauvais` = `1..2` **et** `quality == 0`,
`bon` = `3`, `maitrise` = `4..5`. **Identique, borne pour borne.**

**Gain non cosmétique** : `flashcard_filters.dart:27` fait
`repetitions.firstWhere((rep) => rep.flashcardId == fc.id, …)` **par carte** — O(n) par carte, donc
quadratique. C'est le **seul** `firstWhere` sur des répétitions de tout le dépôt (grep montré § 5).
`zApplyTestFilters` prend `srsById` déjà indexée : lookup O(1), et le fichier explique pourquoi
(`z_session_categorization.dart:50-55`).

**Lignes économisées** : ~**60** sur 90.

⚠️ **Ce que le socle ne fait pas ici** : IFFD filtre par **`documentsIds` / `notesIds`**
(`flashcard_filters.dart:64-78`), c'est-à-dire par **identité de source**. Le socle ne filtre que
par `kind` (`zMatchesSourceKind`, `z_flashcard_filters.dart:174-180`). Cf. § 3 G3.

### M6 — La catégorisation « à apprendre / à réviser » : `zCategorize`

**API exacte** : `zCategorize` — `zcrud_flashcard/lib/src/domain/z_session_categorization.dart:91` ;
`ZSessionCategories` `:30` ; `zIndexSrsById` `:56`.

**Corps vérifié** : `neverLearned` = aucun état SRS ou `repetitions == 0` (`:103-107`) ;
`due` = `nextReviewDate <= at`, **tri décoré par index** pour être stable (dartdoc `:83-89` — Dart
ne garantit pas la stabilité de `List.sort`).

**Chez l'hôte** : `widgets/flashcard_widgets.dart:837-878` refait la chose à la main —
`flashcardsToReviewIds` (`:837-841`), `nextReviewDateMap` (`:843-848`), trois seaux (`:855-864`),
tri par urgence **non stabilisé** (`:867-874`). ~**42 lignes**.

### M7 — L'écran de fin de session : `ZSessionSummaryView`

**API exacte** : `ZSessionSummaryView` — `zcrud_session/lib/src/presentation/z_session_summary_view.dart:206`
(846 l., 12 params) ; `ZSummaryCelebration` `:62` (`none`/`subtle`/`confetti`) ;
`ZCelebrationSpec` `:82` ; `zMasteredCount` `:190` ; `ZStudyProgressRings` ;
`ZSessionQualityBreakdown`.

**Dépendance déjà résolue chez l'hôte, vérifiée des deux côtés** :
`zcrud_session/pubspec.yaml:95` déclare `confetti: ^0.8.0` ; `iffd/pubspec.yaml:172` déclare
`confetti: ^0.8.0`. **Même contrainte, aucune arête nouvelle.**

**Chez l'hôte** : `pages/flashcards_learning_celebration_page.dart` (403 l.) — `ConfettiWidget`
(`:114-135`), trophée (`_buildTrophyIcon`), stats (`_buildStatsRow`), boutons d'action.

**Lignes économisées** : ~**200** (confetti, trophée, stats, boutons). Le fond dégradé et les
cercles animés (`:88-110`) sont de l'identité visuelle IFFD et restent chez l'hôte.

⚠️ **Perte mesurée à déclarer** : `ZCelebrationSpec` a **11 champs et aucun `colors`**
(`z_session_summary_view.dart:51-81`) ; le socle dérive les couleurs du thème (`:824-839`). Les six
couleurs de confetti d'IFFD (`:127-134`) ne sont pas injectables. Cf. § 3 G5.

### M8 — Le carrousel de session : `ZSessionCardSwiper`

**API exacte** : `ZSessionCardSwiper` — `zcrud_session/lib/src/presentation/z_session_card_swiper.dart:134`
(648 l., 10 params) ; `ZSessionProgressIndicator` (`…/z_session_progress_indicator.dart:77`) ;
`ZIndexController` (paramètre `indexController`, `:213`).

**Même paquet tiers, contrainte compatible** : `zcrud_session/pubspec.yaml:98`
`flutter_card_swiper: ^7.2.0` ; `iffd/pubspec.yaml:177` `flutter_card_swiper: ^7.0.2`.
L'intersection est `>= 7.2.0 < 8.0.0` — résoluble, et **IFFD dépend déjà de `zcrud_session`**
(`pubspec.yaml:412`), donc le graphe est déjà fermé.

**Chez l'hôte** : `pages/folder_flashcards_repetitions_page.dart` — `CardSwiperController` (`:198`),
`CardSwiper(` (`:503`), `CardSwiperButtons` (`:743`, classe `:922-…`).

**Ce que le socle apporte en plus, vérifié au corps** : boutons de navigation accessibles émettant
par la **même voie** que le geste (`onIndexChanged`, dartdoc `:142-146`), `swipeDuration` ramené à
zéro sous Reduce Motion (`zReduceMotionOf`, import `:120`), clé de génération de file qui évite le
`RangeError` au rétrécissement.

**Lignes économisées** : ~**260**.

### M9 — Les trois éditeurs de flashcard : enregistrés, jamais déclarés

C'est le constat le plus net du domaine, et il ne demande **aucune nouvelle dépendance**.

`registerZFlashcardEditors(registry, …)` **est appelé** — `iffd/lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:171`.
Il enregistre un builder sous le `kind` `custom` (`kZFlashcardEditorKindName = EditionFieldType.custom.name`,
`zcrud_flashcard/lib/src/presentation/z_flashcard_editors.dart:30`), qui discrimine ensuite par
`ZFlashcardFieldConfig.editorKind` (`:56-77`) vers `ZFlashcardTypeFieldWidget`,
`ZChoicesFieldWidget`, `ZTrueFalseFieldWidget`.

**Mais aucun champ d'IFFD ne pose cette configuration.** `zcrud/flashcard_edition_zcrud.dart`
déclare des familles **génériques** : `boolean` (`:109`, `:190`), `inlineMarkdown` (`:114`, `:151`,
`:161`), `select` (`:142`, `:381`, `:395`), `text` (`:171`, `:177`), `subItems` (`:198`),
`relation` (`:278`). Et `ZFlashcardEditionFields` est à **0 occurrence** dans tout `lib/`.

⇒ **Les trois widgets enregistrés sont du code mort**, et surtout la règle métier portée par
`ZFlashcardEditionValidator.validateChoices` — « au moins 2 choix, au moins 1 correct »
(`z_flashcard_edition_validator.dart:47-56`) — **n'est appliquée nulle part**. Le registre d'IFFD le
dit lui-même (`z_iffd_field_registry.dart:157-165`) : « le legacy IFFD ne valide cette règle NULLE
PART ». Il l'a écrit, puis a enregistré le builder, puis a déclaré des familles génériques.

**API exacte à appeler** : `ZFlashcardEditionFields.type()` / `.choices()` / `.trueFalse()` —
`zcrud_flashcard/lib/src/presentation/z_flashcard_editors.dart:89` / `:100` / `:109` (catalogue
complet : `.all()` `:157`).

**Lignes économisées** : ~**40** (`flashcardIsTrueField()` `:187-193`, `flashcardChoicesField()`
`:195-…` et le `subItems` de choix qu'il configure).

### M10 — La confirmation destructive : `showZConfirmDialog`

**API exacte** : `showZConfirmDialog` / `ZConfirmDialog` —
`zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129` / `:36` ;
ton `ZConfirmTone` (`domain/z_confirm_tone.dart:12`). Rend `Future<bool>`, libellés via
`MaterialLocalizations`, `title` optionnel (`:51`).

**Le paquet est déjà déclaré** (`iffd/pubspec.yaml:440`) **et déjà importé** dans trois fichiers du
dossier `folders` (`folder_detail_zcrud.dart:36`, `folder_details_page.dart:51`, `:65`) — **zéro
dans `flashcards`**.

**Chez l'hôte** : `AlertDialog(` à `pages/white_exam_page.dart:407`,
`pages/multi_flashcard_editor_page.dart:150` et `:229` (3 sites). ~**40 lignes**.

### M11 — Les états de chargement : `ZLoadingState` / `ZContentStateView`

**API exacte** : `ZLoadingState` `zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:75` ;
`ZEmptyState` `:31` ; `ZErrorState` `:127` ; aiguilleur `ZContentStateView` `:180` sur
`ZContentState` (`domain/z_content_state.dart:13`, `switch` exhaustif).

**Chez l'hôte** : **12** `CircularProgressIndicator` montés à la main dans le périmètre
(`white_exam_question_card.dart` ×3, `ai_flashcards_generator_dialog_widget.dart` ×3,
`interactive_flashcard_repetition_card.dart` ×2, `flashcards_dialogs.dart`, `white_exam_page.dart`,
`flashcard_widgets.dart`, `multi_flashcard_editor_page.dart`). ~**60 lignes**, et surtout des
`Semantics` et une cible ≥ 48 dp que le montage manuel ne porte pas.

### M12 — Le feedback pédagogique (partiellement) : `zFeedbackTierFor` + `ZFeedbackBank`

**API exacte** : `ZFeedbackTier` — `zcrud_session/lib/src/domain/z_session_feedback.dart:32` ;
`ZFeedbackThresholds` `:48` ; `zFeedbackTierFor` `:104` ; `zFeedbackKeyFor` `:136` ;
`ZFeedbackBank` / `ZDefaultFeedbackBank` (`…/presentation/z_session_feedback_bank.dart:38` / `:51`) ;
`zFeedbackText` `:99`.

**Seuils identiques, vérifiés des deux côtés** : socle `exceptionalUnder = 10 s`,
`exceptionalMaxHints = 0` (`z_session_feedback.dart:57-58`) ; IFFD
`if (timeTaken < 10 && hintsCount == 0)` (`learning_mode_question_card.dart:106`). **La même règle,
au même chiffre.** Le socle porte en plus le refus du palier sur mesure aberrante (`:124-129`) —
qu'IFFD n'a pas.

**Lignes économisées** : ~**80** sur les 92 de `_getEncouragementMessage`/`_getMotivationMessage`
(`:99-190`).

⚠️ **Limite honnête** : `ZFeedbackTier` n'a que **4 seaux** et `ZFeedbackBank.maybeResolve(key,
languageCode)` (`:44`) ne reçoit **ni la soumission ni le nombre d'indices**. Le sous-découpage
d'IFFD par nombre d'indices (0 / 1 / 2+, `:132`, `:139`, `:146`) et le tirage aléatoire parmi 3-4
variantes ne sont **pas** exprimables. Cf. § 3 G6.

---

## 3. MANQUE AU SOCLE

| # | Ce qui manque | Forme du canal | Paquet | Pourquoi l'hôte ne peut pas s'en passer | Bloque une capacité ? |
|---|---|---|---|---|---|
| **G1** | 🔴 **`softLineBreak` non déclarable** (CR-IFFD-115, ouverte) | **paramètre** sur `ZDeltaCodec`/`ZMarkdownCodec` — ou une **liste de syntaxes inline** injectable | `zcrud_markdown` | `_ZSoftLineBreakSyntax` est enregistrée **inconditionnellement** (`z_markdown_codec.dart:509`, déclarée `:283`) et **recolle** le retour souple en espace. Le lecteur de **question** d'IFFD passe `softLineBreak: true` (`flashcard_widgets.dart:426`), seul site du dépôt. **Grep négatif montré : `grep -rn "softLineBreak" packages/zcrud_markdown/lib/src` → RC=1, aucune ligne.** | ✅ **OUI.** Le drapeau `flashcardListRichReader` bascule la **réponse** et pas la **question** (`z_qa_flags.dart:266-269`) : une même tuile rend aujourd'hui ses deux faces avec **deux moteurs différents**. |
| **G2** | 🔴 **`ZPdfPreview` n'accepte que des octets déjà calculés** | **paramètre** `bytesBuilder`/`Future<Uint8List> Function()` + `actions` + `fileName` + `loadingBuilder` | `zcrud_export_ui` | `ZPdfPreview` — `z_pdf_preview.dart:118` : **un seul canal, `bytes: Uint8List`**, plus `semanticsLabel`/`canPrint`/`canShare`. IFFD monte `PdfPreview(build: (format) => convertToPdf(), loadingWidget:…, maxPageWidth:…, pdfFileName:…, actions: [IconButton …])` (`export_flashcards_to_pdf.dart:102-186`, `:262-…`), au-dessus d'un POST **distant** (`:78-80` : `dio.post("${baseUrl}${AiRepository.convertFlashcardsToPdfEndpoint}")`). Sans builder asynchrone ni slot d'actions, le canal du socle **ne peut pas** porter cet écran. | Non — mais il ferme la seule voie de migration de l'export. |
| **G3** | **Filtre de source par IDENTITÉ, pas seulement par `kind`** | **paramètre** `sourceIds: Set<String>` (ou prédicat `bool Function(ZFlashcardSource)`) sur `ZFlashcardTestFilters` / `ZFlashcardBrowseFilters` | `zcrud_flashcard` | `zMatchesSourceKind` (`z_flashcard_filters.dart:174-180`) ne compare que `card.source?.kind`. Or `ZDocumentSource.documentId` (`z_flashcard_source.dart:159`) et `ZNoteSource.noteId` (`:98`) **existent** — la donnée est là, le filtre ne la lit pas. IFFD filtre par `documentsIds`/`notesIds` (`flashcard_filters.dart:64-78`), et c'est l'un de ses trois axes de session. | ✅ **OUI, partiellement** : sans lui, `zApplyTestFilters` ne remplace `applyTestExamFilters` qu'à 3 axes sur 5. |
| **G4** | **Marquage/signalement d'une question en cours d'examen** | **paramètre** `flagged: Set<int>` + `onFlagToggled` sur `ZListSessionView` (ou un slot `questionLeading`) | `zcrud_session` | Grep négatif montré : `grep -in "flag\|skip\|dontKnow\|unknown" z_list_session_view.dart` → **RC=1**. IFFD porte `_flaggedQuestions` (`white_exam_page.dart:47`) et son bouton (`:255-270`). Contournable en enveloppant chaque question — mais alors on perd la virtualisation du `ListView.builder` interne. | Non (contournable, avec coût). |
| **G5** | **Couleurs de confetti non injectables** | **paramètre** `colors: List<Color>?` (ou `colorKeys`) sur `ZCelebrationSpec` | `zcrud_session` | `ZCelebrationSpec` a 11 champs (`z_session_summary_view.dart:51-81`) : `burstDuration`, `numberOfParticles`, `gravity`, `emissionFrequency`, `entranceCurve`, `trophyIcon`, `trophyDecoration`, et 4 champs d'anneaux. **Aucun `colors`** ; les teintes sont dérivées du thème (`:824-839`). IFFD en pose six (`flashcards_learning_celebration_page.dart:127-134`). | Non — perte cosmétique, à arbitrer contre FR-26. |
| **G6** | **Le seau de feedback ne voit pas le nombre d'indices** | **paramètre** : une `ZFeedbackBank` recevant la soumission (`maybeResolve(key, lang, {ZFlashcardSubmission? submission})`), ou un `ZFeedbackTier` enrichi | `zcrud_session` | `ZFeedbackBank.maybeResolve(String key, String languageCode)` (`z_session_feedback_bank.dart:44`) : deux arguments, aucun contexte. Le sous-découpage d'IFFD par indices (`learning_mode_question_card.dart:132`, `:139`, `:146`) est perdu. | Non. |
| **G7** | **`collapseStore`/`formId` inatteignables depuis un écran assemblé** | **relais** de paramètre | `zcrud_screen` | Constat repris du catalogue « listes-écrans » et **remesuré** : `grep -n 'collapseStore\|formId' packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart` → **une seule ligne, `:4352`**, qui est le commentaire expliquant l'absence. Sans effet direct sur ce domaine (IFFD passe par `presentFormEdition`), consigné pour l'aire édition. | Non. |

---

## 4. RESTE À L'HÔTE — règle métier IFFD, le socle n'a pas à la porter

| Particularité | Site | Pourquoi c'est un invariant, pas une préférence |
|---|---|---|
| **Génération PDF DISTANTE** | `widgets/export_flashcards_to_pdf.dart:61-88` et `:219-246` — `dio.post` vers `AiRepository.convertFlashcardsToPdfEndpoint` / `convertMarkdownToPdfEndpoint` (l'URL de base vit dans le routeur IA d'IFFD, jamais nommée ici) | Le socle porte `ZFlashcardPdfTemplate` (`zcrud_export_pdf/…/z_flashcard_pdf_template.dart:51`, 811 l., génération **locale** bytes-in/bytes-out). **Ce n'est pas le même produit** : IFFD a fait le choix d'un service. Le catalogue « listes-écrans » ne le posait qu'en soupçon — **il est confirmé**. Le rapprochement `ZFlashcardPdfTemplate` ⇄ `ExportFlashcardsToPdf` serait une capacité promise à tort. |
| **Système Harmonisé (sections/chapitres douaniers)** | `domain/models/flashcard_model.dart:106-141` (`hsSection`, `hsChapter`, `canonicalHsChapter`) ; `zcrud/flashcard_edition_zcrud.dart:378`, `:392` ; `utils/constants/sh2022.dart` | Nomenclature métier. Le socle donne les coutures (`ZCondition`, `ZRelationSource`, `ZFieldSpec`), jamais le référentiel — et IFFD les utilise déjà. |
| **Les neuf outils de la valeur en douane, triés numériquement** | `zcrud/folder_flashcards_filter_zcrud_edition.dart:213` (`ZValuationToolFilterSpec`) | Idem : donnée métier. |
| **`overdueBonusFactor: 0.5`** | `domain/models/flashcard_repetition_info.dart:57` | Politique pédagogique, **déjà déclarable** par `ZSrsConfig` (défaut socle `0.0`, `z_srs_config.dart:25`). Le canal existe, le choix est à l'hôte. |
| **Ré-explication IA d'une réponse en cours d'examen** | `widgets/white_exam_question_card.dart:226` (`_regenerateExplanation`) | Parcours produit IFFD. Le socle a `ZAiExplanationPort` (`zcrud_study/…/z_ai_explanation_port.dart:67`) pour l'appel, **jamais** l'orchestration du parcours. |
| **Bibliothèque éditoriale d'encouragements en français** | `widgets/learning_mode_question_card.dart:99-190` | Les **textes** sont éditoriaux. Seule la **règle de routage** est migrable (M12). |
| **`ExamAnswer`** | `pages/white_exam_page.dart:754` | Structure IFFD que le socle ne modélise pas — l'hôte l'a déjà mesuré et déclaré (`interactive_flashcard_repetition_card.dart:406-410`). |
| **Deux conventions de navigation** (`Get.back` ×33 / `Navigator.` ×13) | tout le périmètre | Choix d'architecture applicative. `zcrud_navigation` offre une politique de présentation, pas un routeur. |

---

## 5. Greps négatifs montrés

```
# Symboles du socle à ZÉRO occurrence dans tout iffd/lib — grep -rlnw <sym> lib | wc -l
ZWhiteExamSessionView 0   ZWhiteExamSessionEngine 0   ZWhiteExamSessionController 0
ZListSessionView 0        ZSessionCardSwiper 0        ZSessionSummaryView 0
ZTestFiltersDialog 0      ZFlashcardHintPort 0        ZHintPenaltyPolicy 0
ZFlashcardAnswerEvaluationPort 0                      ZSessionFeedbackBank 0
ZStudyProgressRings 0     ZStreakBadge 0              ZCorrectionVisibility 0
ZCardAdvanceBehavior 0    ZSessionModeSelector 0      ZSessionQualityBreakdown 0
ZTimerDisplay 0           ZSessionProgressIndicator 0 ZFlashcardPreview 0
ZFlashcardPdfTemplate 0   ZPdfPreview 0               ZFileSaver 0   ZExporter 0
showZConfirmDialog 0      ZConfirmDialog 0            ZDiscardChangesGuard 0
ZLoadingState 0           ZContentStateView 0         ZEmptyState 0  ZErrorState 0
ZFlashcardGenerationPort 0  ZFlashcardGenerationSheet 0  ZFlashcardGenerationController 0
ZFlashcardGenerationLauncher 0                        zDuplicateFlashcardForEditing 0
ZFlashcardTestFilters 0   zApplyTestFilters 0         ZFlashcardBrowseFilters 0
zApplyBrowseFilters 0     zFlashcardSearchText 0      ZFlashcardSortMode 0
zSortFlashcards 0         ZSessionCategories 0        zEvaluateLocally 0
zCorrectChoiceIndexes 0   ZMasteryLevel 0             ZFlashcardSource 0
ZSourceRegistry 0         ZFlashcardEditionFields 0   ZChoicesFieldWidget 0
ZTrueFalseFieldWidget 0   ZFlashcardTypeFieldWidget 0 ZStudySessionHost 0
ZStudySessionView 0       ZStudySessionScaffold 0     ZFlashcardRepository 0
ZStudySessionSelector 0   ZSessionCandidate 0

# 59 symboles publics à ZÉRO (liste ci-dessus, comptée). `ZStudySessionEngine` : 1 occurrence, en COMMENTAIRE
# (review_card_zcrud.dart:44) — donc 0 usage réel.

$ grep -rn 'package:zcrud_export\|package:zcrud_list' /home/zakarius/DEV/iffd/lib --include='*.dart'
RC=1                      # aucun import, et aucune entrée en dependencies/overrides

$ grep -rn "softLineBreak" /home/zakarius/DEV/zcrud/packages/zcrud_markdown/lib/src
RC=1                      # le socle ne connaît pas ce nom

$ grep -in "flag\|skip\|dontKnow\|unknown" packages/zcrud_session/lib/src/presentation/z_list_session_view.dart
RC=1                      # aucun canal de marquage de question

$ grep -n "zcrud_export" /home/zakarius/DEV/zcrud/packages/zcrud_flashcard/pubspec.yaml
RC=1                      # l'export n'arrive PLUS transitivement

$ grep -rn "repetitions.firstWhere\|firstWhere((rep" /home/zakarius/DEV/iffd/lib --include='*.dart'
lib/src/utils/flashcard_filters.dart:27      # site UNIQUE du O(n) par carte
```

---

## 6. Deux commentaires de l'hôte qui gouvernent des absences, et qui sont PÉRIMÉS

Remesuré ligne à ligne, parce qu'ils justifient à eux seuls deux paquets non adoptés :

1. `iffd/pubspec.yaml:292` — « `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34, IFFD est en
   ^32 ». **Faux aujourd'hui** : `iffd/pubspec.yaml:141-148` déclare **`^34.1.31`** sur les huit
   paquets Syncfusion ; `zcrud_list/pubspec.yaml:36` demande `syncfusion_flutter_datagrid: ^34.1.31` ;
   `zcrud_export/pubspec.yaml:42-43` demande `xlsio` + `pdf` en `^34.1.31`. **Le verrou n'existe plus.**
2. `iffd/pubspec.yaml:326` — « la chaîne `zcrud_flashcard -> zcrud_export -> syncfusion_flutter_pdf` ».
   **Faux** : `grep -n 'zcrud_export' packages/zcrud_flashcard/pubspec.yaml` → **RC=1**.

⇒ Ces deux commentaires n'empêchent plus rien **techniquement**. Mais l'adoption de `zcrud_export*`
reste **sans objet fonctionnel** ici, pour la raison du § 4 : l'export d'IFFD est distant. Le lever
serait un gain de clarté, pas un gain de code.

---

## 7. Ce que je n'ai pas mesuré

- **Aucun test lancé**, dans aucun dépôt. Rien ici n'atteste qu'un canal *fonctionne* — seulement
  qu'il *existe*, à telle ligne, avec tel corps et tels défauts.
- La **composabilité bout à bout** de `ZListSessionView` + `ZWhiteExamSessionEngine` +
  `ZWhiteExamSessionController` à partir des seuls canaux publics : j'ai lu les trois constructeurs
  et les reducers, je n'ai pas assemblé l'écran.
- `zcrud_chat_study` (13 canaux, **paquet non déclaré** chez IFFD) : il porte
  `ZChatFlashcardGenerator` et `zChatConversationGenerationRequest`, qui correspondent à la
  génération de cartes depuis une conversation d'IFFD. **Fermeture transitive non résolue** — je ne
  la classe donc ni en migrable ni en manquant.
- `ZFlashcardGenerationSheet` (`zcrud_study/…/z_flashcard_generation_sheet.dart:214`, 919 l.) face à
  `ai_flashcards_generator_dialog_widget.dart` (1 238 l.) : les deux existent, mais l'hôte y mêle
  **scan de document** (`cunning_document_scanner`, `:3`), upload et génération de tags par IA
  (`:134`). Le socle a `acquisitionGestures` (`:270`) et `contextSources` (`:266`) pour cela — la
  correspondance est **plausible et non vérifiée jusqu'au bout**. Je la laisse hors du tableau
  « migrable » plutôt que de promettre une capacité que je n'ai pas mesurée.

---

## Trois chiffres à retenir

1. **~1 950 lignes d'hôte** supprimables **sans montée de tag ni nouvelle dépendance** — les douze
   entrées du § 2, dont **600** pour le seul examen blanc.
2. **59 symboles publics du socle à zéro occurrence** dans tout `iffd/lib`, dont la totalité du
   runtime d'examen (`ZListSessionView`, les trois pièces d'examen blanc), la totalité du domaine
   pur de filtrage/tri/catégorisation, et les deux ports IA de la révision (indice, évaluation).
3. **Un seul manque bloque vraiment une capacité** : `softLineBreak` (G1, CR-IFFD-115). Tant qu'il
   tient, une tuile de flashcard rend sa question et sa réponse avec **deux moteurs markdown
   différents** — et c'est le socle qui l'impose, pas l'hôte.
