# Confrontation — domaine « Examens et évaluations » d'IFFD face au socle zcrud v3.21.0

**Relevé du 2026-08-26.** Hôte lu en LECTURE SEULE : `/home/zakarius/DEV/iffd` (`main`).
Socle : `/home/zakarius/DEV/zcrud/packages/`, v3.21.0, 41 paquets. Aucun test lancé (consigne) :
tout ce qui suit atteste qu'un canal **existe**, à telle ligne, avec tel corps — jamais qu'il
*fonctionne*.

Matière d'entrée : `carte-examens.md` (48 918 o, présent et complet — son agent n'est pas mort)
et les cinq `capacites-zcrud-*.md`. **Aucun des deux n'a été cru sur parole** : les §0 ci-dessous
recensent les constats que j'ai dû corriger.

---

## 0. Ce que j'ai dû CORRIGER dans la matière d'entrée

Quatre constats repris tels quels auraient fait dérailler la migration.

### 0.1 🔴 `TestExamFilterZcrudScreen` n'est PAS hors scope — la carte se trompe

`carte-examens.md` §5.2 affirme que cet écran « perd la casse par défaut, le port numérique, le
présentateur de sélection et le thème des sous-listes » faute d'être sous `IffdZcrudScope`, et
en fait un pré-requis n°1 de son ordre de bataille.

**Mesuré** : IFFD monte le scope **une fois pour toute l'application**, dans le `builder:` de
`GetMaterialApp.router` — donc **au-dessus du `Navigator`** :

```
iffd/lib/main.dart:269-270
  builder: (BuildContext context, Widget? child) =>
      IffdZcrudScope(child: child ?? const SizedBox.shrink()),
```

Le commentaire d'IFFD lui-même l'explique (`main.dart:260-265`) : « `builder` place précisément
là — sous le `Theme`, au-dessus du `Navigator` — donc **toutes les routes en héritent** ». Or
`TestExamFilterZcrudScreen` est poussé par `showPushedDialog`
(`flashcards_dialogs.dart:616-622`), c'est-à-dire **une route**. Il hérite du scope.

⇒ Le geste n°1 de l'ordre de bataille de la carte est **sans objet**. Le corriger vaut mieux que
le rejouer : une QA lancée sur cette prémisse chercherait un écart qui n'existe pas.

### 0.2 🔴 `ZTimerDisplay` n'est pas un chronomètre d'examen — c'est un **enum**

La carte (§6) l'oppose au « chronomètre de `white_exam_page.dart:74-88` (~15 l.) » comme s'il le
remplaçait. Corps lu : `zcrud_session/lib/src/presentation/z_timer_display.dart` est un **fichier
de 39 lignes contenant un `enum` à 3 valeurs** (`hidden`/`elapsed`/`countdown`), consommé par
`ZFlashcardAnswerInput.timerDisplay` — un minuteur **par carte**, pas par examen.
`ZListSessionView.duration` (`z_list_session_view.dart:143,188,351`) est une `Duration`
**injectée**, jamais mesurée. Le seul `Stopwatch` du paquet vit dans `ZFlashcardAnswerInput`
(`z_flashcard_answer_input.dart:241`).

⇒ Le chronomètre d'examen global reste **à l'hôte** (§4.2).

### 0.3 🔴 Le blocage documenté de `ReviewCardZcrudView` a été LEVÉ par le socle il y a longtemps

IFFD gèle un portage entier sur un manque du socle :

```
iffd/lib/src/presentation/features/flashcards/zcrud/review_card_zcrud.dart:106-119
  « `ZFlashcardReviewCard` n'expose AUCUN moyen de commander la révélation […]
    ⛔ C'est pourquoi ce portage n'est PAS raccordé. […] inertie MOTIVÉE,
    gelée par `test/w8m/review_card_reveal_command_test.dart`. »
```

**Le canal existe** : `ZFlashcardReviewCard.revealController` (`ZToggleController?`),
`zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:110` (paramètre) et `:175`
(champ), livré en **v0.32.0** (`git log -S revealController` → `4231a2398`, « CR-IFFD-38 & 39 —
commande externe d'état »). Sa dartdoc (`:150-158`) nomme **littéralement les deux sites
d'IFFD** :

> « Un hôte qui possède un second chemin de déclenchement — un bouton « Voir la réponse » à côté
> de la carte, un bouton « Masquer la réponse » posé par le parent sur la face arrière — n'a
> alors aucune façon de commander la révélation. »

L'objection écrite du test (`review_card_reveal_command_test.dart:79` : « un `revealController`
**interne à la carte** ne l'aurait pas servi ») ne porte pas : le contrôleur est **possédé par
l'hôte, hors `build`** (`z_flashcard_review_card.dart:172-177`) et sert donc les deux sites.

**GREP NÉGATIF MONTRÉ** :
```
$ grep -rn --include='*.dart' "revealController\|ZToggleController" iffd/lib
RC=1   (aucune ligne)
```

### 0.4 🟡 Deux comptes de `presentFormEdition` circulent — le bon est 16/15

`capacites-zcrud-listes-ecrans.md` annonce **29 fichiers**, la carte **16 sites / 15 fichiers**.
Les deux sont exacts dans leur métrique et l'écart trompe :

```
$ grep -rn  --include='*.dart' "presentFormEdition(" iffd/lib | wc -l   → 16   (appels)
$ grep -rln --include='*.dart' "presentFormEdition(" iffd/lib | wc -l   → 15   (fichiers)
$ grep -rlnw --include='*.dart' "presentFormEdition"  iffd/lib | wc -l  → 29   (imports + dartdoc compris)
```
La métrique actionnable est **16 appels dans 15 fichiers**.

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme le canal

| Canal du socle | Site chez l'hôte | Portée |
|---|---|---|
| `ZExam`, `ZReminderTime`, `ZReminderRecurrence` (`zcrud_exam`) | `data/repositories/z_backed_exam_repository.dart:92-97` | **Unique** import de `zcrud_exam` d'IFFD (`grep -rn "package:zcrud_exam" lib` → 1 import réel, l. 92). Dépôt **inactif** : `exam_providers.dart:18`, `useZcrudExamsRepository = false` |
| `ZReminderRecurrence.weekdays` | `z_backed_exam_repository.dart:29-40` | La particularité d'IFFD (§7.1 de la carte) est **devenue une capacité du socle** (CR-IFFD-17, v0.5.1) sans supprimer le modèle relatif |
| `ZFieldSpec`/`EditionFieldType`/`ZTextConfig`/`ZDateConfig`/`ZRelationConfig`/`ZValidatorSpec`/`ZFormController`/`ZEditionSubmitController`/`DynamicEdition`/`ZRelationSourceRegistry` | `administration/dialogs/exam_zcrud_edition.dart:66` | Formulaire d'examen **entièrement déclaratif** — drapeau `exam` à `false` (`:77`) |
| mêmes canaux (+ `ZFieldChoice`) | `flashcards/widgets/test_exam_filter_zcrud_screen.dart:52` | Formulaire de filtres **entièrement déclaratif** — drapeau `testExamFilter` à `false` (`:61`) |
| `ZFlashcardAnswerInput`, `ZFlashcardSubmission` (`zcrud_session`) | `flashcards/zcrud/review_session_zcrud.dart:37,118` | **Précédent décisif** : la saisie de réponse du socle est déjà montée pour la session de révision |
| `ZFlashcard` + adaptateur `iffdCardToZ` | `flashcards/zcrud/review_card_zcrud.dart:85` (délègue à `iffdCardsToZ`) | L'adaptateur `FlashcardModel → ZFlashcard` **existe et est éprouvé** — c'est l'enabler de tout le §2 |
| `ZSrsConfig` (`kIffdSrsConfig`) | `domain/models/flashcard_repetition_info.dart:57` | `ZSrsConfig(overdueBonusFactor: 0.5)` |
| `ZReviewMode` + `iffdReviewMode` | `flashcards/zcrud/review_session_zcrud.dart:73-74` | Ne couvre que `learn`/`spaced` — 4 des 6 modes restent à mapper |
| `ZSrsQualityButtons` | `flashcards/zcrud/srs_quality_zcrud.dart:30,102` | Avec `ZQualityScale.fromConfig(kIffdSrsConfig)` |
| `ZItemActionsMenu` + `ZItemAction` (`zcrud_study`) | `folders/zcrud/folder_actions_menu_zcrud.dart:38,170` | **Le patron existe** — mais pas appliqué à `ExamActionsDialogWidget` (§2.8) |
| `ZAdaptiveGrid` (`zcrud_responsive`) | `folders/zcrud/study_tools_zcrud_adapter.dart:566` | Idem — pas appliqué aux deux grilles d'examens (§2.3) |
| `ZAcl` (impl. maison) | `ai_routers/zcrud/ai_router_sub_list_seams.dart:216` (`IffdMinimumOneAcl`) ; `IffdZcrudScope(acl:)` `shared/zcrud/z_iffd_field_registry.dart:406` | Le port ACL **est** consommé (§4.4) |
| `ZSubListConfig` | `shared/zcrud/z_questions_counts_field.dart:38-44` | Comptes de questions |
| `IffdZcrudScope` racine | `main.dart:269-270` | Voir §0.1 |

**Aucune CR du registre (76 entrées, `docs/zcrud-change-requests.md`) ne porte sur ce domaine** :
```
$ grep -nE "^## CR-IFFD" iffd/docs/zcrud-change-requests.md | grep -i "exam"
RC=1   (aucune ligne)
```
Le domaine n'a donc **jamais** été confronté au socle. C'est le principal résultat de ce relevé.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte l'ignore

**Pré-requis vérifié pour les onze lignes : aucun changement de `pubspec.yaml`.**
`zcrud_session`, `zcrud_flashcard`, `zcrud_screen`, `zcrud_study`, `zcrud_exam`,
`zcrud_responsive`, `zcrud_ui_kit` sont **tous déjà déclarés** (`grep -oE "^  (zcrud_[a-z_]+):"
iffd/pubspec.yaml` → 25 paquets, les sept en font partie).

**GREP NÉGATIF MONTRÉ — les canaux cités ci-dessous, chez IFFD :**
```
$ for s in ZWhiteExamSessionEngine ZWhiteExamSessionController ZWhiteExamSessionView \
    ZListSessionView ZTestFiltersDialog zApplyTestFilters ZFlashcardTestFilters \
    ZSessionSummaryView ZFeedbackBank ZDefaultFeedbackBank ZTimerDisplay \
    ZCorrectionVisibility ZSessionProgressIndicator ZSessionModeSelector \
    ZSessionQualityBreakdown ZMasteryLevel zMasteryLevelOf zDrawQuestions zShuffleChoices \
    zEvaluateLocally zIsSingleChoiceQcm zCorrectChoiceIndexes ZFlashcardAnswerEvaluationPort \
    ZExamScoringPort ZSessionCardSwiper ZStudyProgressRings ZExamExtensionParser \
    ZHintPenaltyPolicy ZRowActionsMenu ZConfirmDialog showZConfirmDialog ZEmptyState \
    ZContentStateView ZCrudScreen ZDefaultExamCard ZExamEditor ZExamRemindersSection \
    examDailyTasks revealController ZToggleController zSessionRuntimeForMode; do
    grep -rlnw --include='*.dart' "$s" iffd/lib | wc -l ; done
→ 0 pour TOUS (seul ZItemActionsMenu, hors liste, rend 1)
```

### 2.1 `revealController` — débloque un portage GELÉ (0 ligne de socle à écrire)

| | |
|---|---|
| **API exacte** | `ZFlashcardReviewCard.revealController` (type `ZToggleController?`) |
| **Preuve** | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:110` (paramètre), `:175` (champ), `:313-314` (`ZDisplayStateBinding.bind`), `:358` (re-bind au `didUpdateWidget`) ; `ZToggleController` : `packages/zcrud_core/lib/src/presentation/state/z_display_state.dart:254` |
| **Corps vérifié** | `_reveal = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)..bind(widget.revealController)` — le contrôleur devient **source unique** ; le tap de la carte écrit **dedans** ; le passage à la carte suivante y écrit `false` |
| **Ce que l'hôte croit** | « aucun moyen de commander la révélation » (`review_card_zcrud.dart:106-119`), portage gelé, tripwire `test/w8m/` |
| **Lignes d'hôte débloquées** | `ReviewCardZcrudView` (`review_card_zcrud.dart`, **180 l.**) passe d'inerte à raccordable ; côté legacy, le `FlipCardController` et ses **2 sites de commande** (`interactive_flashcard_repetition_card.dart:1127`, `flashcard_repetition_widgets.dart:153,258`, `learning_mode_question_card.dart:213`) deviennent retirables |

### 2.2 `presentFormEdition` — les 2 formulaires du domaine montent encore leur Scaffold

| | |
|---|---|
| **API exacte** | `presentFormEdition(BuildContext, {required List<ZFieldSpec> fields, …})` — **22 paramètres**, dont `formController: ZFormController?` |
| **Preuve** | `packages/zcrud_screen/lib/src/presentation/present_form_edition.dart:234-256` |
| **Corps vérifié** | Construit un `ZFormOnlyController` (`:274`), `submit()` rend `null` si invalide et laisse la fenêtre ouverte (`:285-288`), `markPristine()` puis `Navigator.pop(values)` (`:294-295`). Le `formController` **injecté** est relayé (`form: formController`, `:277`) ⇒ le `ExamTitleDeriver` d'IFFD (§7.5 de la carte) **survit** |
| **Sites hôtes** | `administration/dialogs/exam_zcrud_edition.dart:424-513` (**90 l.**, dont 36 de `build`/`Scaffold`/`AppBar`/`Semantics(button)`) ; `flashcards/widgets/test_exam_filter_zcrud_screen.dart:311-376` (**66 l.**) |
| **Preuve que l'hôte sait faire** | `administration/dialogs/auditeur_account_zcrud_edition.dart:143-160` — 16 appels dans 15 fichiers |
| **Lignes économisées** | **~100** (les deux `State` moins ce qu'il faut garder : création/destruction du contrôleur + attache du dériveur + `adaptExamZcrudOutput`) |
| **Bonus non demandé** | conteneur **adaptatif** page/feuille/dialogue et **garde d'abandon** — l'hôte les énumère lui-même (`auditeur_account_zcrud_edition.dart:130-140`) |

### 2.3 `ZAdaptiveGrid` / `ZListGridLayout` — la grille calculée à la main sur `Get.width`, 2×

| | |
|---|---|
| **API exacte** | `ZAdaptiveGrid({required children, required minItemWidth, spacing, itemHeight, aspectRatio, minColumns, maxColumns, padding})` et `ZAdaptiveGrid.builder({itemCount, itemBuilder, …})` ; variante liste : `ZListGridLayout(maxCrossAxisExtent, mainAxisSpacing, crossAxisSpacing, childAspectRatio, mainAxisExtent, padding, maxColumns, entityBuilder)` |
| **Preuve** | `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:57` (ctor `:63`, ctor `.builder` `:89`) ; `packages/zcrud_core/lib/src/presentation/list/z_list_layout.dart:175-257` |
| **Corps vérifié** | `availableWidth = constraints.maxWidth` d'un `LayoutBuilder` — la dartdoc interdit explicitement `Get.width`/`MediaQuery.sizeOf` (`z_adaptive_grid.dart:15-20`). Garde vide avant tout `LayoutBuilder`. `computeCrossAxisCount` partagée par les deux ctors |
| **Sites hôtes** | ① `administration/pages/exams_page.dart:123-180` (**58 l.**, `Get.width`, `drawerWidth = 300`, `itemMinWidth` 350/300, `childAspectRatio: itemWidth / (kToolbarHeight + 20\|40)`, `GridView.count` non défilant) ; ② `folders/pages/folder_progress_page.dart:87-140` (même bloc recopié) |
| **Lignes économisées** | **~90** (2 × ~45) |
| **Défaut corrigé au passage** | `Get.width` est la largeur de **fenêtre** — c'est précisément pourquoi IFFD lui soustrait `drawerWidth = 300` à la main. La mesure locale rend ce correctif inutile, et juste en split-view |
| **Non couvert** | `GridView.count` d'IFFD est **non défilant** dans un `SingleChildScrollView` : c'est le ctor `children:` (eager) qu'il faut, pas `.builder` |

### 2.4 `zApplyTestFilters` + `ZFlashcardTestFilters` + `ZMasteryLevel` — le filtrage pur

| | |
|---|---|
| **API exacte** | `zApplyTestFilters(Iterable<ZFlashcard>, {required Map<String,ZRepetitionInfo> srsById, required ZFlashcardTestFilters filters, required ZSrsConfig config, required ZStudySessionSelector selector, required Random random})` |
| **Preuve** | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:206-236` ; `ZFlashcardTestFilters` `:107` ; `ZMasteryLevel` `:34` ; `zMasteryLevelOf` `:75` ; `zDrawQuestions` `:461` ; `ZStudySessionSelector` `packages/zcrud_study_kernel/lib/src/domain/z_study_session_selector.dart:34` |
| **Corps vérifié** | Ordre : ① `selector.matches` (dossier ∧ tags ∧ types) ② seau de maîtrise, **lookup Map O(1)** ③ `kind` de source ④ tirage à `questionCount` avec **`Random` injecté** |
| **Équivalence de seuils, MESURÉE** | `ZSrsConfig` : `passThreshold = 3` (`z_srs_config.dart:26`), `minQuality = 0` (`:27`), `masteredThreshold => maxQuality - 1` = **4** (`:148`). Donc `bad = [0..2]`, `good = [3]`, `mastered = [4..5]` — **exactement** `mauvais`/`bon`/`maitrise` d'IFFD (`utils/flashcard_filters.dart:38-52`), **y compris la règle « jamais pratiquée compte comme mauvais »** (`zMasteryLevelOf` rend `bad` sur `info == null`, `repetitions == 0` ou `lastQuality == null`) |
| **Sémantique des tags identique** | `_matchesTags` = `any` (`z_study_session_selector.dart:77-84`) ⇔ `fc.tagsIds.any(...)` (`flashcard_filters.dart:62`) |
| **Sites hôtes** | `utils/flashcard_filters.dart` (**90 l.**, fonction `applyTestExamFilters`) |
| **Lignes économisées** | **~62 sur 90** — voir la réserve §3.1 : `documentsIds`/`notesIds` **ne sont pas couverts** |
| **Défaut corrigé au passage** | IFFD fait un `repetitions.firstWhere(...)` **par carte** (`flashcard_filters.dart:27-34`) → O(n·m) ; le socle indexe (`srsById`). Et `filtered.shuffle(Random())` (`:85`) crée un générateur non injecté ⇒ non testable |

### 2.5 `ZFlashcardAnswerInput` — les trois saisies écrites **deux fois** (452 l.)

| | |
|---|---|
| **API exacte** | `ZFlashcardAnswerInput({required ZFlashcard card, required ZReviewMode mode, ZSrsConfig srsConfig, ZFlashcardContentBuilder? contentBuilder, ZFlashcardAnswerEvaluationPort? evaluationPort, bool allowSkipEvaluation, ZFlashcardHintPort? hintPort, bool revealStoredHint, ZHintPenaltyPolicy hintPolicy, ZTimerDisplay timerDisplay, Duration? timeLimit, ZCardAdvanceBehavior? advanceBehavior, Duration autoAdvanceDelay, ZCorrectionVisibility correctionVisibility, onSubmitted, onQualitySelected, onAdvance})` — 17 params |
| **Preuve** | `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart:102` (classe), `:104-123` (ctor) ; **routage par type vérifié** `:789-808` (`switch (widget.card.type)` → `_ChoicesInput` / `_TrueFalseInput` / `_WrittenInput` pour les 4 types écrits) |
| **Sites hôtes** | `white_exam_question_card.dart:679-904` (`_buildQCMInput` 97 l., `_buildTrueFalseInput` 88 l., `_buildTextInput` 41 l.) et `interactive_flashcard_repetition_card.dart:686-911` (102 + 103 + 21 l.) |
| **Preuve que l'hôte sait faire** | `flashcards/zcrud/review_session_zcrud.dart:118-127` monte déjà ce widget avec `iffdCardToZ` + `kIffdSrsConfig` + `contentBuilder` |
| **Lignes économisées** | **~452** (les deux jeux de trois saisies) |
| **Défaut corrigé au passage** | les deux copies ont **divergé** : facteur d'échelle markdown `1.0` vs `1.1`, `widget.isSubmitted` vs `_isSubmitted`, `enabled:` vs `onChanged: null` (§4.3 de la carte). Et **0 `Semantics(`** dans les 3 840 lignes du runtime d'épreuve d'IFFD |

### 2.6 `zEvaluateLocally` + `zIsSingleChoiceQcm` + `zCorrectChoiceIndexes` — la correction QCM/VF

| | |
|---|---|
| **API exacte** | `zEvaluateLocally({required ZFlashcard card, required Set<int> selectedChoiceIndexes, bool? answeredTrue, required ZSrsConfig config}) → int?` ; `zIsSingleChoiceQcm(ZFlashcard) → bool` ; `zIsLocallyEvaluatedType(ZFlashcardType) → bool` |
| **Preuve** | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:96` / `:56` / `:66` / `:36` |
| **Corps vérifié** | QCM = **égalité ensembliste stricte** `{sélection} == {corrects}` — identique au test d'IFFD (`white_exam_page.dart:557-570`, longueurs égales + `every(contains)`). Rend `config.maxQuality` si exact, `config.minQuality` sinon. `zIsSingleChoiceQcm` = `zCorrectChoiceIndexes(card).length == 1` — **exactement** la règle implicite d'IFFD `rightAnswersCount == 1` (`white_exam_question_card.dart:681-682` **et** son jumeau `interactive_flashcard_repetition_card.dart:688-689`) |
| **Réglage requis** | IFFD note 5 / **1** (`white_exam_page.dart:569,574`). Il faut donc `ZSrsConfig(minQuality: 1, overdueBonusFactor: 0.5)` pour ce runtime — `minQuality: 1` est **explicitement supporté** (`z_srs_config.dart:60-65` : « minQuality DOIT valoir 0 ou 1 »), mais `kIffdSrsConfig` vaut aujourd'hui `minQuality: 0` (`flashcard_repetition_info.dart:57`). **Conséquence à assumer** : le « je ne sais pas » à 0 devient inreprésentable (§3.3) |
| **Lignes économisées** | **~40** (la règle d'unicité dupliquée + les deux blocs `_evaluateAnswer`) |
| **Défaut corrigé au passage** | le socle refuse `{} == {}` sur une carte sans choix correct (« dégrader, jamais récompenser », `z_flashcard_local_evaluation.dart:104-108`) ; IFFD rendrait `isCorrect == true` à qui ne coche rien sur une carte malformée |

### 2.7 `ZFlashcardAnswerEvaluationPort` — la notation IA 1-5, avec le MÊME repli

| | |
|---|---|
| **API exacte** | `abstract interface class ZFlashcardAnswerEvaluationPort { Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(ZFlashcardAnswerEvaluationRequest) }` |
| **Preuve** | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_answer_evaluation_port.dart:218` (port), `:58` (requête), `:157` (évaluation) |
| **Correspondance champ à champ** | requête : `question`, `userAnswer`, `expectedAnswer`, `explanation`, `cardType`, `timeTaken`, `hintsUsed`, `extra` ⇄ les 7 arguments d'`evaluateFlashcardAnswer` d'IFFD (`white_exam_page.dart:592-604`) |
| **Repli identique** | dartdoc `:238-243` : « `Left` […] le consommateur retombe alors sur la qualité neutre (`config.passThreshold`) » = **3** ⇄ le `return 3.0` d'IFFD (`white_exam_page.dart:614`) |
| **Ce qui reste à l'hôte** | l'implémentation du port (le préprompt filière §7.6 y vit — c'est sa place) |
| **Lignes économisées** | **~35** côté surface, mais surtout : le port est **consultatif par contrat** (« n'écrit jamais le SRS ») ⇒ l'invariant AD-9 devient structurel au lieu d'être une convention |

### 2.8 `ZItemActionsMenu` + `showZConfirmDialog` — le menu « Modifier / Supprimer »

| | |
|---|---|
| **API exacte** | `ZItemActionsMenu(actions:, crossAxisCount:, …)` + `ZItemAction({required kind, required label, required icon, onSelected, id, permitted, disabledReason, state, stateSemanticLabel, count})` ; `Future<bool> showZConfirmDialog(...)` + `ZConfirmDialog({title, required message, confirmLabel, cancelLabel, tone})` |
| **Preuve** | `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:283` / `:147` / `:297` (`crossAxisCount`) ; `packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:36` et `:129` |
| **Corps vérifié** | `ZItemAction` : trois états (`onSelected`/`disabledReason`/`permitted`) avec `assert` d'exclusivité (`:174-181`) ; `ZConfirmDialog` dérive la couleur du bouton du `ColorScheme` selon `ZConfirmTone.destructive`, libellés par `MaterialLocalizations` — **jamais** un littéral |
| **Sites hôtes** | `administration/widgets/exam_actions_dialog_widget.dart` (**76 l.**, deux `Material > ListTile` + `Colors.red` × 2 + `buildConfirmDialog`) ; famille : **12** classes `extends StatelessItemDialogWidget`, **38** appels de `buildConfirmDialog` dans **20** fichiers |
| **Preuve que l'hôte sait faire** | `folders/zcrud/folder_actions_menu_zcrud.dart:170` monte déjà `ZItemActionsMenu` |
| **Lignes économisées** | **~55** pour l'examen seul |
| **⚠️ Piège de version** | `crossAxisCount` est passé de **1 colonne à une grille 3 colonnes** en v3.0.0 (`z_item_actions_menu.dart:297`). Retour arrière : `crossAxisCount: 1` |

### 2.9 `ZContentStateView` / `ZErrorState` — le chargement PERPÉTUEL sur flux en erreur

| | |
|---|---|
| **API exacte** | `ZContentStateView({required ZContentState state, required WidgetBuilder successBuilder, Widget? idle, Widget? loading, Widget? empty, Widget? error})` |
| **Preuve** | `packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:180` (classe), `:183` (ctor), `:194-209` (champs) ; `ZEmptyState:31`, `ZLoadingState:75`, `ZErrorState:127` |
| **Défaut hôte** | `exams_page.dart:116-118` et `folder_progress_page.dart:545` testent `!snapshot.hasData` et rendent un `CircularProgressIndicator` ⇒ **un flux en erreur affiche un chargement perpétuel**. IFFD compte **49** `CircularProgressIndicator` |
| **Lignes économisées** | ~20 sur ce domaine ; le canal `error` **n'existe pas** dans le code hôte, c'est une capacité gagnée, pas seulement des lignes rendues |

### 2.10 `ZExam.isPast(now)` / `daysUntil(now)` — le groupement « à venir / passés »

| | |
|---|---|
| **API exacte** | `bool ZExam.isPast(DateTime now)` ; `int? ZExam.daysUntil(DateTime now)` |
| **Preuve** | `packages/zcrud_exam/lib/src/domain/z_exam.dart:326-330` et `:313-319` |
| **Corps vérifié** | normalisation **UTC jour calendaire** (`DateTime.utc(y,m,d)`), `now` en **paramètre** — aucun `DateTime.now()` implicite |
| **Sites hôtes** | `exams_page.dart:195-220` et `folder_progress_page.dart:549-565` — deux boucles de groupement recopiées, chacune avec son `final now = DateTime.now()` |
| **⚠️ Écart de sémantique MESURÉ** | IFFD compare des **instants** (`date.isBefore(now)`, `exams_page.dart:212`) ; le socle compare des **jours calendaires**. Un examen d'aujourd'hui 08 h 00 lu à 10 h 00 est « passé » chez IFFD, « à venir » (`daysUntil == 0`) chez le socle. **Bascule à décider explicitement, pas à subir** |
| **Lignes économisées** | ~30, et le déterminisme (horloge injectée) en prime |

### 2.11 `ZDefaultExamCard` — la tuile d'examen (partielle, voir §3.5)

| | |
|---|---|
| **API exacte** | `ZDefaultExamCard({required ZExam exam, untitledLabel, dateLabel, reminderLabel, palette, colorKey, titleMaxLines, trailing, onTap, onLongPress, semanticLabel})` |
| **Preuve** | `packages/zcrud_study/lib/src/presentation/z_default_exam_card.dart:44` (classe), `:46-62` (ctor) — **204 l.** |
| **Corps vérifié** | barre d'accent, intitulé, date **déjà formatée par l'hôte**, puce de rappel rendue seulement si `exam.reminderEnabled` **et** libellé injecté (l'état est dit **en texte**, AD-13) ; accent dérivé de la clé stable `'exam'` par `remapColorKey` |
| **Site hôte** | `ExamsListItemBuilder` (`exams_page.dart:255-333`, **79 l.**), monté **2×** |
| **Couverture** | titre / date / rappel / `trailing` / `onTap` / a11y ✅ ; le traitement « passé » (`Opacity(0.7)` + `TextDecoration.lineThrough`) ❌ — voir §3.5 |

### 2.12 `examDailyTasks` / `approachingReminders` / `ZExamRemindersSection` — l'examen pilote les tâches

| | |
|---|---|
| **API exacte** | `examDailyTasks(...)`, `approachingReminders(...)`, `zExamAsApproaching(ZExam) → ZApproachingExam`, `ZExamRemindersSection({required exams, required now, onRemindersComputed, tileBuilder, emptyState, shrinkWrap, reminderSemanticLabel, dueInLabel})` |
| **Preuve** | `packages/zcrud_study/lib/src/presentation/z_exam_reminders.dart:66` (`zExamAsApproaching`), `:68+` (`examDailyTasks`) ; `z_exam_reminders_section.dart:50` (classe), `:52-63` (ctor) ; exports `zcrud_study.dart:86-92` |
| **Corps vérifié** | délègue filtre (`isApproaching`) + tri (date croissante) à `aggregateDailyStudyTasks` du kernel ; **aucun plugin de notification, aucun `Timer`** — la planification OS reste un seam applicatif, exposé par `onRemindersComputed` |
| **Besoin hôte** | §1.1.7 de la carte : « Ajoute une date d'examen pour bénéficier de tâches d'apprentissage optimisées » (`exams_page.dart:32`), branché sur `smartLearnInstance` (`:100-101`) ; `tasks/pages/daily_tasks_page.dart` |
| **Réserve honnête** | je **n'ai pas** mesuré la surface de `smartLearnInstance` : je ne chiffre donc pas les lignes économisées ici. Le canal existe et n'est pas appelé ; l'équivalence fonctionnelle reste à établir |

---

## 3. MANQUE AU SOCLE

Sept manques, chacun avec sa preuve d'absence, sa forme et son paquet.

### 3.1 Filtrer un test par **document précis** et **note précise**

| | |
|---|---|
| **Preuve d'absence** | `$ grep -rn "documentIds\|noteIds\|documentsIds\|notesIds\|sourceIds" packages/zcrud_flashcard/lib/` → **RC=1** |
| **Ce qui existe** | `ZFlashcardTestFilters.sources: Set<String>` filtre par **`kind`** de provenance (`'note'`, `'document'`, `'conversation'`…) via `zMatchesSourceKind` (`z_flashcard_filters.dart:174-179`), pas par identifiant |
| **La donnée est pourtant là** | `ZNoteSource.noteId` (`z_flashcard_source.dart:98`), `ZDocumentSource.documentId` (`:159`) — l'entité porte l'id, aucun canal ne le filtre |
| **Besoin hôte** | `utils/flashcard_filters.dart:67-80` (2 filtres) et le formulaire qui les alimente (`test_exam_filter_screen.dart:100-130`) : l'auditeur compose un test **sur un document du corpus** |
| **Forme du canal** | un champ `sourceIds: Set<String>` sur `ZFlashcardTestFilters` + un prédicat `zMatchesSourceId(card, ids)` **extrait** au même titre que `zMatchesSourceKind` (le fichier justifie déjà l'extraction pour le partage avec `zApplyBrowseFilters`) |
| **Paquet** | `zcrud_flashcard` (`z_flashcard_filters.dart`) |
| **Bloque une capacité d'étude ?** | **OUI** — sans lui, `zApplyTestFilters` n'est adoptable qu'en gardant 2 filtres à la main, ce qui recrée deux sources du même filtre (ce que le fichier condamne explicitement, `:65-77`) |

### 3.2 `ZTestFiltersDialog` ne propose que **2 des 6 sections** du formulaire d'IFFD

| | |
|---|---|
| **Preuve** | `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:54` — ctor `:65-71` : `initial`, `availableSources`, `minQuestionCount` (1), `maxQuestionCount` (100). Sections rendues : nombre de questions (stepper), seaux de maîtrise, `kind` de source |
| **Besoin hôte** | `test_exam_filter_screen.dart:39-131` : questionCount **(1-30)**, questionTypes, masteryLevels, tagsIds, documentsIds, notesIds — **6 sections** |
| **Forme du canal** | soit des sections optionnelles supplémentaires sur le dialogue (types, tags, sources par id, chacune absente si sa liste de choix est vide — le patron `availableSources` existe déjà), soit **assumer** que ce dialogue n'est pas le canal d'IFFD |
| **Paquet** | `zcrud_session` |
| **Verdict opérationnel** | ⚠️ **NE PAS le classer « migrable »**. IFFD a déjà porté ce formulaire en `ZFieldSpec` déclaratifs (`test_exam_filter_zcrud_screen.dart`, 376 l.) : sa voie est `presentFormEdition` (§2.2) + `zApplyTestFilters` (§2.4), **pas** `ZTestFiltersDialog` |

### 3.3 Distinguer « je ne sais pas » d'une réponse fausse

| | |
|---|---|
| **Preuve d'absence** | `ZFeedbackTier` a **4** valeurs (`motivation`/`neutral`/`encouragement`/`exceptional`, `z_session_feedback.dart:32-45`) ; `motivation` couvre `q0-2` **en bloc** (`zFeedbackTierFor:130`). `ZDefaultFeedbackBank` porte **un seul message par seau** (`z_session_feedback_bank.dart:57-62` pour `fr`) |
| **Besoin hôte** | `white_exam_page.dart:491-502` : `case 0: // IDK` a sa **propre banque de 6 messages** (`:534-545`), distincte des 6 messages de `_getMotivationMessage` (`:523-532`) — et l'affordance « Je ne sais pas » est un bouton réel (`white_exam_page.dart:220-256`) |
| **Aggravé par §2.6** | adopter `zEvaluateLocally` avec le barème 5/1 impose `minQuality: 1` ⇒ `config.clampQuality(0)` rend **1** ⇒ IDK et faux deviennent **le même état** |
| **Forme du canal** | un cinquième seau `ZFeedbackTier.skipped`, atteint par un **drapeau explicite** de la soumission (`ZFlashcardSubmission.skipped: bool`) — jamais par une note-sentinelle, qui est justement ce que `clampQuality` écrase |
| **Paquets** | `zcrud_session` (`z_session_feedback.dart`, `z_flashcard_submission.dart`) |
| **Bloque une capacité de révision ?** | **OUI, partiellement** — l'affordance « je ne sais pas » et son registre pédagogique sont perdus à la migration |

### 3.4 Le rappel **hebdomadaire** est absent de `ZExamEditor`

| | |
|---|---|
| **Preuve d'absence** | `$ grep -n "reminderRecurrence\|weekdays\|ZReminderRecurrence" packages/zcrud_study/lib/src/presentation/z_exam_editor.dart` → **RC=1** |
| **Ce que l'éditeur compose** | `z_exam_editor.dart:327-336` : `base.copyWith(folderId, title, date, reminderEnabled, reminderDaysBefore, reminderTime)` — **jamais** `reminderRecurrence` |
| **Pas de perte de données** | `ZExam.copyWith` est à sentinelle et **préserve** `reminderRecurrence` (`z_exam.dart:284-286`). Rien n'est effacé |
| **Mais l'UI ment** | `effectiveReminderRecurrence` rend `reminderRecurrence` dès qu'elle est non-`null` (`z_exam.dart:402-403`) ⇒ sur un examen IFFD (qui en a **toujours** une, CR-IFFD-17), l'éditeur affiche la section « Jours avant » dont **les valeurs saisies n'ont aucun effet** sur `isApproaching`. C'est un canal « qui n'agit que sous condition », de la pire espèce : silencieux |
| **Forme du canal** | une section « jours de la semaine » dans `ZExamEditor`, gouvernée par la famille de `effectiveReminderRecurrence` — l'entité sait déjà porter les deux modèles, seul l'éditeur est en retard |
| **Paquet** | `zcrud_study` (`z_exam_editor.dart`, 588 l., 25 params) |
| **Conséquence** | **`ZExamEditor` n'est PAS adoptable par IFFD en l'état.** C'est pourquoi il n'apparaît pas au §2 |

### 3.5 Aucune variante « échéance passée » sur `ZDefaultExamCard`

| | |
|---|---|
| **Preuve d'absence** | `$ grep -niE "lineThrough\|opacity\|dim\|past\|expired\|isPast" packages/zcrud_study/lib/src/presentation/z_default_exam_card.dart` → une seule ligne, `:170`, et c'est un `BoxDecoration` de la barre d'accent |
| **Besoin hôte** | `exams_page.dart:286-312` : `Opacity(opacity: isPassed ? 0.7 : 1)` + `TextDecoration.lineThrough` sur l'intitulé. Le paramètre `isPassed` traverse la tuile depuis le groupement |
| **Pourquoi l'hôte ne peut pas s'en passer** | c'est le **seul** signal visuel qui distingue les deux groupes de la grille ; l'envelopper d'un `Opacity` de l'extérieur ne donnerait pas le barré, qui est **dans** le `Text` du titre |
| **Forme du canal** | un `ZExamCardEmphasis` (enum `normal`/`past`) — pas un `bool` : un troisième état (« aujourd'hui ») est prévisible. Le rendu doit rester **textuel aussi** (AD-13 : l'opacité seule ne dit rien à un lecteur d'écran, et `semanticLabel` est injecté) |
| **Paquet** | `zcrud_study` (`z_default_exam_card.dart`) |

### 3.6 Aucun port d'explication **en flux**

| | |
|---|---|
| **Preuve d'absence** | `ZAiExplanationPort.explain` rend `Future<ZResult<String>>` — **une seule valeur** (`packages/zcrud_study/lib/src/domain/z_ai_explanation_port.dart:71`). `$ grep -rn "Stream<" packages/zcrud_study/lib/src/domain/*.dart` → 4 lignes, **toutes** dans `z_study_sharing_port.dart` / `z_study_moderation_port.dart` (adhésions, signalements) |
| **Besoin hôte** | `white_exam_question_card.dart:226-355` diffuse l'explication **au fil de l'eau**, avec un bouton « Réexpliquer » (`:1014-1030`) |
| **Ce qui existe ailleurs** | `ZChatStreamPort` (`packages/zcrud_chat_kernel/lib/src/domain/ai/z_chat_generation_port.dart:465`) — mais il est bâti pour un message/une conversation, pas pour l'explication d'une carte |
| **Forme du canal** | soit un `ZAiExplanationStreamPort` frère rendant `Stream<ZResult<String>>`, soit un `ZChatGenerationRequest` adressé par **route** (« expliquer la réponse ») consommant le catalogue de routes livré en v3.8→3.10 — c'est justement le mode de transport d'IFFD (décision d'owner du 2026-08-23) |
| **Paquet** | `zcrud_study` (port neutre) ou `zcrud_chat_kernel` (voie route) |
| **Bloque une capacité d'étude ?** | **OUI** — l'explication en flux est la fonctionnalité n°23 du domaine ; en `Future`, l'apprenant attend devant un écran figé |

### 3.7 Chronomètre d'examen, fanions de question, et bandeau de score global

| | |
|---|---|
| **Preuve d'absence (fanions)** | `$ grep -rniE 'flagged\|bookmark\|markForReview\|toggleFlag' packages/zcrud_session/lib/` → **RC=1** |
| **Preuve d'absence (chrono d'examen)** | `$ grep -rn "Stopwatch" packages/zcrud_session/lib/` → 4 lignes : 2 en dartdoc de `z_timer_display.dart`, 2 dans `z_flashcard_answer_input.dart:241,269` — **par carte**, jamais par examen. `ZListSessionView.duration` est **injectée** (`:143,188`) |
| **Preuve d'absence (score global)** | `$ grep -nE "averagePerQuestion\|avgPerQuestion\|perQuestion\|0\.7\|70" packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart` → **RC=1**. Les clés rendues sont `totalValueKey`, `masteredValueKey`, `durationValueKey` (`:301-311`) |
| **Besoin hôte** | `white_exam_page.dart:74-88` (chrono), `:258-272` (fanion), `:634-700` (pourcentage sur `réponses × 5`, temps moyen par question, bandeau vert ≥ 70 %) |
| **Forme des canaux** | ① une `ZExamStopwatch` (ou un `elapsed` notifié sur `ZWhiteExamSessionController`) ; ② un `Set<int> flagged` sur `ZWhiteExamState` + une affordance sur `ZListSessionView` ; ③ des tuiles supplémentaires **déclarées** sur `ZSessionSummaryView` (`extraStats: List<ZSummaryStat>`) — les seuils restent à l'hôte (§4.5) |
| **Paquet** | `zcrud_session` |
| **Bloque une capacité d'étude ?** | ① et ② **oui** pour un examen blanc chronométré ; ③ non (l'hôte peut composer au-dessus) — mais ①②③ ne concernent aujourd'hui **que du code mort** (§4.1) |

---

## 4. RESTE À L'HÔTE — règle métier propre à IFFD

| # | Règle | Preuve | Pourquoi le socle ne la porte pas |
|---|---|---|---|
| 4.1 | **`WhiteExamPage` est morte** — 779 l. jamais montées | `$ grep -rn 'WhiteExamPageRoute' iffd/lib \| grep -v app_router.gr.dart` → **RC=1** ; unique site de construction commenté (`flashcard_widgets.dart:1124-1201`, 78 l. en commentaire) ; `ExamAnswer` (`:754-779`) reste consommé par 3 fichiers vivants | Décision de produit. ⚠️ **Elle conditionne §3.7** : chrono, fanions et bandeau de score n'existent que là. Trancher le sort de la page **avant** d'émettre ces trois CR |
| 4.2 | Le **chronomètre visible** et le fanion sont des choix de produit | `white_exam_page.dart:74-88`, `:258-272` | Le socle offre `ZTimerDisplay` **par carte** ; l'examen chronométré global est un régime, pas un défaut |
| 4.3 | **ACL composée `"ExamModel$accademicYear"`**, 6 sites | `permission_helpers.dart:94` ; `dashbord_page.dart:512` ; `daily_tasks_page.dart:60` ; `exams_page.dart:75` ; `folder_progress_page.dart:152` ; `folder_actions_dialog_widget.dart:46` | Le port **existe** : `ZAcl.can(ZCrudAction, {ZEntity? target, String? collectionId})` (`packages/zcrud_core/lib/src/domain/ports/z_acl.dart:104`), déjà implémenté par IFFD (`IffdMinimumOneAcl`) et posé sur le scope (`z_iffd_field_registry.dart:406`). La **composition** de la clé est de la règle métier : une seule impl. de `ZAcl` la referme, et le littéral cesse d'être écrit 6 fois. ⇒ **ce n'est PAS un manque du socle** (la carte le classait ainsi, §8.3) |
| 4.4 | **`accademicYear`** comme dimension de tout (orthographe legacy comprise) | `exam_model.dart`, `exames_dialogs.dart:69-92` (3 `DataRequest`), `z_backed_exam_repository.dart` → `extra['iffd_accademic_year']` | Concept d'IFFD. L'échappatoire `extra` (AD-4) est **exactement** son canal |
| 4.5 | **Trois constantes de barème** : correct ≥ 3/5, score = `cumul / (réponses × 5)`, bandeau vert à 70 % | `white_exam_page.dart:513-515` (« user's requirement »), `:636-639`, `:652-654` | Le socle réutilise `ZSrsConfig.passThreshold` et n'invente aucun seuil ; les deux autres sont des décisions de produit |
| 4.6 | **Visibilité communautaire filtrée par la promotion** | `exames_dialogs.dart:76-109` ; passée par la source injectée, pas par `filterKeys` (`exam_zcrud_edition.dart:121-124`) | Requête construite à partir des **permissions**. Le socle offre `ZRelationSourceRegistry` — la règle reste à l'hôte |
| 4.7 | **Titre dérivé du dossier** : `Examen: <titre>`, et `"Examen"` si le dossier est sans titre (arbitrage D5, 2026-07-24) | `exam_zcrud_edition.dart:365-368`, `:176-179` | Le **libellé** est métier. Le **motif** (un champ qui en dérive un autre) est générique et le fichier le dit lui-même (`:41-60`) : voir §5 |
| 4.8 | **Projection en rendez-vous d'agenda** | `exam_model.dart:130-141` → `workflow/models/appointment.dart:17` → `workflow/source.dart:38` → `agenda_screen.dart:277` | **GREP NÉGATIF MONTRÉ** : `$ grep -rniE "Appointment\|CalendarDataSource" packages/*/lib/` → **RC=1** ; `$ grep -rn "syncfusion_flutter_calendar" packages/*/pubspec.yaml` → **RC=1**. Aucun paquet zcrud ne touche au calendrier, et **c'est délibéré** (AD-1/AD-8 : une seule arête Syncfusion, celle de `zcrud_list`) |
| 4.9 | **Le préprompt de filière** avant la notation IA | `ai_prompt_generator.dart:531-572` (`_filierePreprompt`) ; 3 implémentations (`iffd_ai_repository_impl.dart:1117`, `openai_ai_repository_impl.dart:516`, `cloud_functions_ai_repository_impl.dart:343`) | AD-12 : **aucun prompt** ne vit dans le socle. Sa place est l'implémentation de `ZFlashcardAnswerEvaluationPort` (§2.7) |
| 4.10 | Les **fuites de types** dans `ExamModel` | `exam_model.dart:5` (`Timestamp`), `:6` (`TimeOfDay`), `:7` (`WeekDays` de `syncfusion_flutter_calendar`) | Dette de l'hôte. `ZExam` est déjà neutre (`DateTime?`, `ZReminderTime`, `List<int>`) et le mapper existe (`z_backed_exam_repository.dart:120-131`) |

---

## 5. Deux CR à ÉMETTRE, nommées par IFFD lui-même

### 5.1 La dérivation déclarative d'un champ par un autre

`exam_zcrud_edition.dart:41-60` : « CR SOCLE CANDIDATE, motif **GÉNÉRIQUE**, rien d'IFFD
là-dedans » — `ZFieldSpec` n'a « ni `onChange`, ni `derivedFrom` ». Le câblage impératif d'IFFD
porte deux limites **mesurées et écrites** par l'hôte : `_syncText` ne réécrit le buffer que hors
focus, et rien ne sérialise deux résolutions asynchrones rapprochées (jeton de génération,
`:321,354,363`). Le legacy l'écrit **3 fois** (`exames_dialogs.dart:169-183`), le portage **1**.
Forme : un `derivedFrom`/`onChange` sur `ZFieldSpec` (paquet `zcrud_core`).
⚠️ **Cette CR ne bloque pas §2.2** : `presentFormEdition(formController:)` relaie le contrôleur,
donc `ExamTitleDeriver` continue de fonctionner tel quel.

### 5.2 Le jeton `flashcardTypeGradients` est **déjà posé** — mais côté carte seulement

Le jeton existe (`packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:460,1486`,
`Map<String, ZGradientSpec>?`, clé = `ZFlashcardType.name` opaque) et est consommé par
`ZDefaultFlashcardCard` (`packages/zcrud_study/lib/src/presentation/z_default_flashcard_card.dart:420`).
IFFD ne le pose pas :
```
$ grep -rn --include='*.dart' "flashcardTypeGradients" iffd/lib   → RC=1
```
et recopie la table **3 fois, identique à l'octet** (`white_exam_question_card.dart:86-108`,
`interactive_flashcard_repetition_card.dart:104-126`, `flashcard_repetition_widgets.dart:52-74`
— 8 hexadécimaux × 3, 46 lignes redondantes sur 69).

⇒ **Migrable aujourd'hui, à condition d'être honnête sur la portée** : poser le jeton et lire
`ZcrudTheme.of(context).flashcardTypeGradients?[type.name]` centralise **la donnée** dans un
fichier de référence (patron FR-26 encadré, cf. `ZStudyCardReference`) ; cela ne fait pas rendre
la carte par le socle. IFFD connaît déjà `ZGradientSpec`
(`shared/zcrud/z_iffd_field_palette.dart:169-182`, `folders/zcrud/folder_detail_zcrud.dart:473`).
**~46 lignes** rendues, et 8 hexadécimaux qui cessent d'être en dur dans 3 widgets.

---

## 6. Récapitulatif chiffré

### Migrable aujourd'hui — sans une ligne de socle, sans un octet de `pubspec.yaml`

| # | Canal | Preuve socle | Lignes d'hôte |
|---|---|---|---:|
| 2.5 | `ZFlashcardAnswerInput` | `zcrud_session/…/z_flashcard_answer_input.dart:102,789-808` | **452** |
| 2.2 | `presentFormEdition` | `zcrud_screen/…/present_form_edition.dart:234-256` | **100** |
| 2.3 | `ZAdaptiveGrid` / `ZListGridLayout` | `zcrud_responsive/…/z_adaptive_grid.dart:57` ; `zcrud_core/…/z_list_layout.dart:175` | **90** |
| 2.4 | `zApplyTestFilters` (partiel) | `zcrud_flashcard/…/z_flashcard_filters.dart:206` | **62** |
| 2.11 | `ZDefaultExamCard` (partiel) | `zcrud_study/…/z_default_exam_card.dart:44` | **60** |
| 2.8 | `ZItemActionsMenu` + `showZConfirmDialog` | `zcrud_study/…/z_item_actions_menu.dart:283` ; `zcrud_ui_kit/…/z_confirm_dialog.dart:129` | **55** |
| 5.2 | jeton `flashcardTypeGradients` | `zcrud_core/…/z_theme.dart:1486` | **46** |
| 2.6 | `zEvaluateLocally` + `zIsSingleChoiceQcm` | `zcrud_flashcard/…/z_flashcard_local_evaluation.dart:96,56` | **40** |
| 2.7 | `ZFlashcardAnswerEvaluationPort` | `zcrud_flashcard/…/z_flashcard_answer_evaluation_port.dart:218` | **35** |
| 2.10 | `ZExam.isPast` / `daysUntil` | `zcrud_exam/…/z_exam.dart:326,313` | **30** |
| 2.9 | `ZContentStateView` | `zcrud_ui_kit/…/z_state_widgets.dart:180` | **20** |
| 2.1 | `revealController` | `zcrud_flashcard/…/z_flashcard_review_card.dart:110,175` | *débloque 180 l. gelées* |
| 2.12 | `examDailyTasks` / `ZExamRemindersSection` | `zcrud_study/…/z_exam_reminders_section.dart:50` | *non chiffré* |
| | | **Total supprimable** | **≈ 990** |

Rapporté aux **9 913 lignes** de production du domaine (26 fichiers, chiffre de la carte
revérifié fichier par fichier) : **≈ 10 %**, sans compter les 779 lignes mortes ni les 180 gelées.

### Ce qui manque au socle

7 manques, dont **4 bloquants** pour une capacité d'étude ou de révision : §3.1 (filtre par
document/note), §3.3 (« je ne sais pas »), §3.4 (rappel hebdomadaire dans `ZExamEditor`),
§3.6 (explication en flux). Deux CR sont en outre **déjà nommées par l'hôte** (§5.1) ou
**déjà servies et ignorées** (§5.2).

### Ordre d'attaque, fondé sur les mesures ci-dessus

| # | Geste | Pourquoi en premier |
|---|---|---|
| 1 | **Raccorder `revealController`** (§2.1) et retirer la note périmée de `review_card_zcrud.dart:106-119` | Coût nul, débloque 180 lignes gelées, corrige une croyance fausse qui gèle aussi un test |
| 2 | **Trancher le sort de `WhiteExamPage`** (§4.1) | 779 lignes mortes gouvernent **trois** CR (§3.7). Les émettre avant serait demander au socle de porter du code que personne n'ouvre |
| 3 | `zApplyTestFilters` + `zEvaluateLocally` + `zIsSingleChoiceQcm` (§2.4, §2.6) | Fonctions **pures**, aucune UI en jeu, testables isolément — et le seul réglage à décider (`minQuality: 1`) est chiffré |
| 4 | `presentFormEdition` sur les 2 formulaires (§2.2) | 16 appels dans 15 fichiers l'ont déjà fait ; le dériveur survit |
| 5 | `ZAdaptiveGrid` sur les 2 grilles (§2.3) | Supprime `Get.width` **et** le correctif `drawerWidth` |
| 6 | `ZFlashcardAnswerInput` sur les 2 × 3 saisies (§2.5) | Le plus gros gain (452 l.), mais après 3 et 4 : le patron d'adoption est alors rodé |
| 7 | Émettre §3.4 (`ZExamEditor` hebdomadaire), §3.1 (filtre par id de source), §5.1 (champ dérivé) | Les trois sont nommables **fichier:ligne**, et §3.4 est l'exact pendant de CR-IFFD-17 déjà gagnée |

---

## 7. Limites de ce relevé

- **Aucun test lancé**, dans aucun dépôt. Rien ici n'atteste qu'un canal *fonctionne* — seulement
  qu'il *existe*, à telle ligne, avec tel corps lu.
- Les **lignes économisées** sont des estimations bornées par comptage de blocs
  (`sed -n 'a,bp' | wc -l`), pas par une réécriture réelle. Elles ne comptent jamais le code
  d'adaptation à écrire en face.
- **§2.12 n'est pas chiffré** : je n'ai pas mesuré la surface de `smartLearnInstance`.
- Le **round-trip markdown** (`ZSmartNote`) et la **fermeture transitive** de `zcrud_chat_study`
  ne sont pas dans ce périmètre et n'ont pas été résolus.
- Le relevé `iffd-migration-2026-08-25/` n'a servi à **rien** ici : aucun de ses constats n'est
  repris.
