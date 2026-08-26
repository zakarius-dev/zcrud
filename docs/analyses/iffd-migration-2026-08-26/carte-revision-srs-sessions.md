# Carte du domaine « Révision — SRS, sessions, gamification » (IFFD)

> Relevé du **2026-08-26**. `/home/zakarius/DEV/iffd` lu en **lecture seule stricte**. Socle : zcrud **v3.21.0**, 41 paquets.
> Le relevé `iffd-migration-2026-08-25/` est **périmé** ; aucun de ses constats n'est repris sans remesure.

---

## 0. Périmètre mesuré

| Zone | Fichiers | Lignes | Commentaire |
|---|---:|---:|---|
| `lib/src/presentation/features/flashcards/**` | **35** | **18 178** | le cœur du domaine |
| `lib/src/features/flashcards/**` (module DI) | 3 | 553 | dont 478 générés (`*.g.dart`) |
| `lib/src/features/gamification/**` | 1 | **0** | `gamification_module.dart` est un fichier **vide** |
| `lib/src/domain/models/flashcard_repetition_info.dart` | 1 | 489 | SM-2 + entité de répétition |
| `domain/models/` : `flashcard_model` (410), `flashcard_tag_model` (90), `folder_document_learning_info` (82) | 3 | 582 | le 3ᵉ porte aussi `FlashcardRepetitionQuality` |
| `domain/repositories/flashcard_*.dart` | 3 | 230 | ports |
| `data/repositories/` : `z_backed_flashcard_repository` (797), `firebase_owner_scoped_repetition_store` (154) | 2 | 951 | ponts vers `ZFlashcard` / `ZRepetitionStore` |
| `lib/src/utils/flashcard_filters.dart` | 1 | 90 | filtres test/examen |
| **Total périmètre direct** | **49** | **≈ 21 073** | |

**Inclus au-delà du point de départ**, parce que les dépendances y mènent : `domain/models/app_user.dart:273` (la **série** vit là), `config/themes/iffd_tokens.dart` (jeton `streakFlame`), `presentation/features/folders/pages/folder_progress_page.dart` (596 l.), `presentation/features/tasks/pages/daily_tasks_page.dart` (`nextReviewDate`), `presentation/shared/zcrud/z_qa_flags.dart` (985 l., registre des bascules).

⚠️ Deux répertoires **vides** (`ls -la` → aucun fichier) : `lib/src/domain/models/flashcard/` et `…/flashcard_tag/`. Et `lib/src/features/gamification/gamification_module.dart` fait **0 ligne** : **il n'existe pas de module de gamification**, malgré le nom du répertoire.

---

## 1. 🔴 Le code répété

### 1.1 Clones de fichier à fichier (mesure `difflib`, blocs ≥ 6 lignes communes)

| A | B | Lignes communes | Ce qui est cloné |
|---|---|---:|---|
| `widgets/flashcard_edition_screen.dart` (771) | `pages/multi_flashcard_editor_page.dart` (1 320) | **256** | déclaration des champs question/réponse/type/QCM/balises, validation, enregistrement |
| `widgets/white_exam_question_card.dart` (1 140) | `widgets/interactive_flashcard_repetition_card.dart` (1 206) | **202** | face de carte, saisie de réponse, révélation, correction, dégradés par type |
| `widgets/interactive_flashcard_repetition_card.dart` | `widgets/flashcard_repetition_widgets.dart` (718) | **164** | dégradés par type, badge de type, pastilles de balise, conteneur de carte |
| `controllers/ai_base_url_zcrud_edition.dart` (285) | `dialogs/flashcard_tag_zcrud_edition.dart` (242) | **97** | **écrans déjà portés** : `IffdZcrudScope` + `Scaffold`/`AppBar`/`Semantics`/`IconButton` d'enregistrement + `DynamicEdition` |
| `controllers/ai_base_url_zcrud_edition.dart` | `widgets/test_exam_filter_zcrud_screen.dart` (377) | **70** | idem |
| `dialogs/flashcard_tag_zcrud_edition.dart` | `widgets/test_exam_filter_zcrud_screen.dart` | **67** | idem |
| `widgets/white_exam_question_card.dart` | `widgets/flashcard_repetition_widgets.dart` | **62** | idem |

> 🔴 Le cas le plus parlant est le **4ᵉ** : la duplication ne vient plus du legacy mais du **portage** — trois écrans zcrud fraîchement écrits re-tapent le même échafaudage plein écran.

### 1.2 Blocs répétés ≥ 7 lignes identiques, dans le périmètre (41 fichiers scannés)

| Bloc | Sites | Où |
|---|---:|---|
| `type: EditionFieldTypes.crudDataSelect` + `multiple` + `acl` + `itemsSorter` + `dynamicItemTransformer` | **9** | `pages/folder_flashcards_list_page.dart:961,981,1000,1020,1039,1059,1079,1099,1119` — bloc de 7 lignes identique 9 fois de suite dans **un seul fichier** (10 `crudDataSelect` au total avec `:861`) |
| `IconData _getTypeIcon(QuestionType type)` (switch complet sur 5 types) | **3** | `white_exam_question_card.dart:97`, `interactive_flashcard_repetition_card.dart:115`, `flashcard_repetition_widgets.dart:63` |
| `if (showCorrectness) { … }` (coloration bonne/mauvaise réponse) | **4** | `white_exam_question_card.dart:695,797`, `interactive_flashcard_repetition_card.dart:702,817` |
| `AppBar` + `Semantics(button, label:'Enregistrer')` + `IconButton(save_outlined, 48×48)` | **3** dans le périmètre, **12** dans tout `lib/` | `grep -c "label: 'Enregistrer'" → 12` |

### 1.3 Compteurs bruts sur les 35 fichiers de `features/flashcards/`

| Motif | Sites | Fichiers |
|---|---:|---|
| `Colors.<nom>` codé en dur | **313** | 35 |
| `Color(0x…)` hexadécimal | **89** | — |
| `BorderRadius.circular` | **76** | — |
| `BoxDecoration(` | **75** | 11 |
| `setState(` | **72** | 10 |
| `LinearGradient(` / `BoxShadow(` / `CircularProgressIndicator` | **19** / **15** / **12** | — |
| `StreamBuilder`/`FutureBuilder` + `hasData/hasError/ConnectionState` | **8** / **20** | 6 |
| chaînes françaises en dur dans le source | **120** | 24 |
| appels à `AppLocalizations` / `context.l10n` / `S.of()` | **0** | — |

**Grep négatif montré** (aucune localisation dans le périmètre) :
```
$ grep -rn --include='*.dart' -E 'AppLocalizations|context\.l10n|S\.of\(' \
    lib/src/presentation/features/flashcards | wc -l
0
```

**Grep négatif montré** (pas de `AsyncValue`/`.when()` : l'asynchrone du périmètre est `StreamBuilder` + `setState`, pas Riverpod) :
```
$ grep -rn --include='*.dart' '\.when(' lib/src/presentation/features/flashcards | wc -l
0
$ grep -rn --include='*.dart' 'AsyncValue' lib/src/presentation/features/flashcards | wc -l
0
$ grep -rn --include='*.dart' 'ref\.watch' lib/src/presentation/features/flashcards | wc -l
1
```

### 1.4 Ce que chaque répétition désigne comme assemblage manquant

| Répétition | Assemblage attendu du socle | Existe déjà ? |
|---|---|---|
| Échafaudage d'édition plein écran ×12 | `ZEditionScaffold` (`packages/zcrud_navigation/lib/src/presentation/z_edition_scaffold.dart`) / `ZCrudScreen` (`packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart`) | ✅ **existe**, non consommé sous cette forme |
| Face de carte + révélation + correction ×3 | `ZFlashcardReviewCard`, `ZRevealTransition` (`zcrud_flashcard`), `ZWhiteExamQuestionBuilder` (`zcrud_session`) | ✅ **existe** |
| Saisie de réponse (texte/QCM/vrai-faux) ×2 | `ZFlashcardAnswerInput` (1 645 l., `zcrud_session`) | ✅ **existe**, importé mais **derrière un drapeau à `false`** |
| Déclaration des champs de flashcard ×2 (256 l.) | `ZFlashcardEditionFields` + `ZFlashcardEditionValidator` (`zcrud_flashcard`) | ✅ **existe** |
| 9 `crudDataSelect` identiques dans un fichier | dérivation des `ZFieldSpec` depuis `@ZcrudModel` | ✅ principe du socle, **non appliqué** |
| Icône/dégradé par `QuestionType` ×3 | `ZFlashcardQuestionTypeBadgeBuilder`, `ZFlashcardTypeLabel` (`zcrud_flashcard`) | ✅ **existe** |
| Série (streak) calculée dans une page | `ZStreakBadge` + `z_streak_toast.dart` (`zcrud_session`) — **le calcul, lui, n'existe nulle part** | ⚠️ affichage oui, **règle métier non** |

---

## 2. Ce que le domaine sait faire (vu de l'utilisateur)

| Capacité | Où elle vit | Mesure |
|---|---|---:|
| **Six modes de session** : `nFlashcardsLearningCycle`, `allFlashcardsLearningCycle`, `listOnly`, `test`, `whiteExam`, `cramming` | `pages/folder_flashcards_repetitions_page.dart:30-36` | 1 202 l. |
| Feuille « Comment veux-tu apprendre ? » : *Apprendre +N flashcards*, *Flashcards à réviser*, *Test* | `widgets/flashcard_widgets.dart:756` (`FlashcardsLearningModeScreen`), tuiles l. 961/1015/1053 | 3 modes actifs |
| ⚠️ *Examen Blanc* et *Croulage (Cramming)* : tuiles **commentées** dans le source | `flashcard_widgets.dart:1135` et `:1216` | **105** lignes de code mort commenté dans ce seul fichier |
| Carte qui se retourne, balayage gauche/droite (`flutter_card_swiper`), points de progression (`dots_indicator`), barre segmentée (`segmented_progress_bar`), confettis (`confetti`) | `folder_flashcards_repetitions_page.dart:1-11` | 5 paquets tiers |
| **Cinq paliers de notation** SM-2 : *Compliqué / Difficile / Ok / facile / Très Facile* (valeurs 1-5, icône + couleur + « à revoir dans… ») | `domain/models/flashcard_repetition_info.dart:181-203` ; aperçu de l'intervalle par `getNextIntervalString:439`, appelé en `folder_flashcards_repetitions_page.dart:1021` | enum `FlashcardRepetitionQuality` |
| Saisie de réponse **libre**, **QCM**, **vrai/faux**, plus indice et explication | `widgets/interactive_flashcard_repetition_card.dart` (1 205 l.), `widgets/white_exam_question_card.dart` (1 139 l.) | 2 344 l. |
| Examen blanc à correction différée + score | `pages/white_exam_page.dart` (779 l.), classe `ExamAnswer:754` | |
| Page de célébration (confettis, 5 s) | `pages/flashcards_learning_celebration_page.dart` | 403 l. |
| **Série d'étude (« flamme »)** : +1 si la dernière étude date d'hier, remise à 1 sinon, jamais si `listOnly` | `folder_flashcards_repetitions_page.dart:113-171` (`_checkAndUpdateStreak`) | **59 l.**, un seul site |
| Affichage de la série | `widgets/flashcard_widgets.dart:895-925` ; couleur `iffd_tokens.dart:22 streakFlame = 0xFFFF6F00` | |
| Filtres test/examen (balises, documents, notes, HS, outils douane) | `utils/flashcard_filters.dart` (90 l.), `widgets/test_exam_filter_screen.dart` (134 l.) | |
| Génération de flashcards par l'IA | `widgets/ai_flashcards_generator_dialog_widget.dart` | 1 238 l. |
| Éditeur multi-flashcards (lot) | `pages/multi_flashcard_editor_page.dart` | 1 319 l. |
| Export PDF des flashcards | `widgets/export_flashcards_to_pdf.dart` | 390 l. |
| Progression par dossier + rappel du jour | `features/folders/pages/folder_progress_page.dart` (596 l.) ; `features/tasks/pages/daily_tasks_page.dart` (lit `nextReviewDate`) | 2 sites |

**Ce que le domaine ne sait PAS faire** (grep négatif montré) — **ni points, ni badges, ni niveaux, ni classement** ; la « gamification » se réduit à un entier `currentStreak` :
```
$ grep -rn --include='*.dart' -iE '\bxp\b|badge|leaderboard|trophy|achievement|level_?up' lib | wc -l
0        # (le seul « badge » du dépôt est ZFlashcardQuestionTypeBadgeBuilder, côté zcrud)
$ wc -l lib/src/features/gamification/gamification_module.dart
0 lib/src/features/gamification/gamification_module.dart
```

---

## 3. Ce qui est déjà branché sur zcrud

### 3.1 Dépendances déclarées vs réellement importées

`pubspec.yaml` déclare **25** paquets zcrud. Comptage des `import 'package:zcrud_*'` dans `lib/` :

| Paquet | Fichiers importateurs | Dans le périmètre révision |
|---|---:|---:|
| `zcrud_core` | 67 | 12 |
| `zcrud_chat_kernel` | 19 | 0 |
| `zcrud_study` | 17 | 3 |
| `zcrud_screen` | 16 | 3 |
| `zcrud_chat` | 15 | 0 |
| `zcrud_markdown` | 11 | 2 |
| **`zcrud_flashcard`** | **9** | 6 |
| `zcrud_study_kernel` | 6 | 1 |
| `zcrud_navigation` | 6 | 2 |
| `zcrud_firestore` | 5 | 0 |
| **`zcrud_session`** | **3** | **3** |
| `zcrud_exam` | 1 | 0 |

🔴 **`zcrud_session` pèse 8 462 lignes et 28 fichiers ; IFFD n'en importe que quatre symboles** :
`ZFlashcardAnswerInput`, `ZFlashcardSubmission` (`zcrud/review_session_zcrud.dart:36-37`),
`ZQualityScale`, `ZSrsQualityButtons` (`zcrud/srs_quality_zcrud.dart:30-31`).
Restent **non consommés** : `ZStudySessionEngine`, `ZWhiteExamSessionEngine`/`View`/`Controller`, `ZSessionCardSwiper` (648 l.), `ZSessionSummaryView` (846 l.), `ZListSessionView` (704 l.), `ZSessionProgressIndicator` (502 l.), `ZTestFiltersDialog` (411 l.), `ZSessionModeSelector` (365 l.), `ZSessionQualityBreakdown`, `ZStudyProgressRings`, `ZStreakBadge`, `z_streak_toast.dart`, `ZSummaryCelebration`, `ZFeedbackBank`, `ZTimerDisplay`, `ZCorrectionVisibility`, `ZLinearSessionState`.

### 3.2 Ce qui est enregistré au registre de champs

`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart` (461 l.) — 3 appels d'enregistrement :

| Appel | Ligne | Effet |
|---|---:|---|
| `registerZMarkdownFields(...)` | 101 | champs riches |
| **`registerZFlashcardEditors(...)`** | **171** | sélecteur de type, éditeur de QCM, vrai/faux — libellés FR injectés |
| `registry.register('phoneNumber', …)` puis `register(kIffdBooleanKind, …)` | 185, 199 | hors périmètre |

Le commentaire de `:150-170` acte une **divergence assumée** : `ZFlashcardEditionValidator` impose « ≥ 2 choix, ≥ 1 correct », règle que **le legacy IFFD ne valide nulle part** — un QCM à une seule proposition, aujourd'hui accepté, sera refusé après bascule. **À arbitrer par le propriétaire.**

### 3.3 Jumeaux portés du domaine révision, et leur drapeau

`lib/src/presentation/features/flashcards/zcrud/` = **10 fichiers, 2 512 l.** ; plus 3 jumeaux hors de ce
dossier. Drapeaux référencés dans `lib/src/presentation/shared/zcrud/z_qa_flags.dart` (985 l., **52** entrées).

| Jumeau porté | Lignes | Drapeau | Famille | Défaut |
|---|---:|---|---|---|
| `zcrud/folder_flashcards_filter_zcrud_edition.dart` | 738 | `folderFlashcardsFilter` | comportement | `false` |
| `zcrud/flashcard_edition_zcrud.dart` | 579 | `flashcardEdition` | **données** | `false` |
| `widgets/test_exam_filter_zcrud_screen.dart` | 376 | `testExamFilter` | comportement | `false` |
| `controllers/ai_base_url_zcrud_edition.dart` | 284 | `aiBaseUrl` | comportement | `false` |
| `zcrud/flashcards_questions_count_zcrud_edition.dart` | 276 | `flashcardsQuestionsCount` | comportement | `false` |
| `zcrud/flashcard_list_rich_reader_zcrud.dart` | 252 | `flashcardListRichReader` | rendu | `false` |
| `zcrud/multi_flashcard_editor_zcrud.dart` | 243 | `multiEditor` | **données** | `false` |
| `dialogs/flashcard_tag_zcrud_edition.dart` | 241 | `flashcardTag` | comportement | `false` |
| `zcrud/review_rich_reader_zcrud.dart` | 235 | `reviewRichReader` | rendu | `false` |
| `zcrud/flashcard_list_zcrud.dart` | 219 | `flashcardList` | comportement | `false` |
| `zcrud/flashcard_batch_zcrud.dart` | 214 | `kFlashcardBatchUseZcrudDefault` (hors registre QA) | — | `false` |
| `zcrud/srs_quality_zcrud.dart` | 183 | `srsQuality` | **données** | `false` |
| `zcrud/review_card_zcrud.dart` | 180 | `kReviewCardUseZcrudDefault` (hors registre QA) | — | `false` |
| `zcrud/export_flashcards_to_pdf_zcrud_edition.dart` | 175 | `exportPdfOptions` | comportement | `false` |
| `zcrud/review_session_zcrud.dart` | 131 | `reviewSession` | **données** | `false` |

🔴 **Le portage est écrit mais éteint.** Sur les **55** constantes `k…UseZcrudDefault` du dépôt, **54 valent `false`** ; la seule à `true` est `kAiRouterEditionUseZcrudDefault` (`features/ai_routers/zcrud/ai_router_zcrud_edition.dart:104`), **hors du périmètre révision**. Et la QA n'a pas commencé : `docs/qa-plan-comparaison-legacy-zcrud.md` porte **198 cases `[ ]`, 0 case `[x]`**.

### 3.4 Le SRS : déjà porté, mais derrière un interrupteur

`lib/src/domain/models/flashcard_repetition_info.dart` importe `ZRepetitionInfo, ZSm2Scheduler, ZSrsConfig`
(`:5-6`). La bascule est un `const bool` :

```
:57   const ZSrsConfig kIffdSrsConfig = ZSrsConfig(overdueBonusFactor: 0.5);
:78   const bool kUseZcrudSm2Scheduler = false;
:392        const scheduler = ZSm2Scheduler(config: kIffdSrsConfig);
:412        return Sm().calc(…)                     // chemin historique, actif
```

Le fichier documente l'écart mesuré (`:26-56`) : sur un échec, l'EF d'IFFD **restait intact** (carte ratée jamais rendue plus difficile) ; le socle applique la pénalité canonique et met l'EF à jour **avant** l'intervalle — d'où 19/20/21 j au lieu de 20/20/20, ce qui différencie enfin les trois boutons.
⚠️ `overdueBonusFactor` doit rester à **0,5** : le socle le laisse à `0.0` par défaut (opt-in CR-LEX-37) — adopter la config par défaut supprimerait **silencieusement** le bonus de retard d'IFFD.

---

## 4. Widgets maison qui refont ce que le socle fait déjà

| Widget maison | Chemin (`lib/src/presentation/features/flashcards/`) | Lignes | Équivalent zcrud v3.21.0 |
|---|---|---:|---|
| `InteractiveFlashcardRepetitionCard` | `widgets/interactive_flashcard_repetition_card.dart` | **1 205** | `ZFlashcardReviewCard` + `ZRevealTransition` (`zcrud_flashcard`) + `ZFlashcardAnswerInput` (1 645 l., `zcrud_session`) |
| `WhiteExamQuestionCard` | `widgets/white_exam_question_card.dart` | **1 139** | `ZWhiteExamQuestionBuilder` / `ZWhiteExamCorrectionBuilder` / `ZCorrectionVisibility` |
| `FolderFlashcardsRepetitionsPage` | `pages/folder_flashcards_repetitions_page.dart` | **1 202** | `ZStudySessionEngine` + `ZSessionCardSwiper` (648 l.) + `ZSessionProgressIndicator` (502 l.) |
| `WhiteExamPage` + `ExamAnswer` | `pages/white_exam_page.dart` | 779 | `ZWhiteExamSessionEngine`/`Controller`/`View`, `ZExamScoringPort` |
| `flashcard_repetition_widgets.dart` (dégradés, badges de type, pastilles) | `widgets/` | 717 | `ZFlashcardQuestionTypeBadgeBuilder`, `ZFlashcardTypeLabel`, `ZFlashcardOptionTile` |
| `MultiFlashcardEditorPage` | `pages/multi_flashcard_editor_page.dart` | **1 319** | `ZMultiFlashcardEditor` (déjà utilisé par le jumeau porté, 243 l. — **11 % du legacy**) |
| `FlashcardEditionScreen` | `widgets/flashcard_edition_screen.dart` | 770 | `ZFlashcardEditionFields` + `ZFlashcardEditionValidator` (jumeau porté : 579 l.) |
| `LearningCelebrationPage` | `pages/flashcards_learning_celebration_page.dart` | 403 | `ZSummaryCelebration`, `ZCelebrationSpec`, `ZSessionSummaryView` (846 l.) |
| `FlashcardsLearningModeScreen` | `widgets/flashcard_widgets.dart:756` | ~490 | `ZSessionModeSelector` (365 l.), `ZStudyProgressRings` (194 l.) |
| `TestExamFilterScreen` + `applyTestExamFilters` | `widgets/test_exam_filter_screen.dart` + `utils/flashcard_filters.dart` | 224 | `ZTestFiltersDialog` (411 l.), `ZFlashcardTestFilters`, `ZFlashcardBrowseFilters` |
| Affichage de série (flamme) | `widgets/flashcard_widgets.dart:895-925` | ~30 | `ZStreakBadge` (123 l.), `z_streak_toast.dart` (133 l.) |
| `_checkAndUpdateStreak` (**règle** de série) | `pages/folder_flashcards_repetitions_page.dart:113-171` | 59 | **aucun équivalent** — le socle rend la série, il ne la calcule pas |
| `ExportFlashcardsToPdf` | `widgets/export_flashcards_to_pdf.dart` | 390 | `zcrud_export`/`zcrud_export_pdf` — **délibérément absents** : exigent Syncfusion ^34, IFFD est en ^32 (`pubspec.yaml:292`) |
| Échafaudage d'édition plein écran ×12 | 12 fichiers, `label: 'Enregistrer'` | ~25 ×12 | `ZEditionScaffold` (`zcrud_navigation`), `ZCrudScreen` (`zcrud_screen`) |

**Total legacy remplaçable identifié : ≈ 8 700 lignes**, face aux 8 462 l. de `zcrud_session` et aux briques de `zcrud_flashcard` déjà livrées.

---

## 5. Écrans et dialogues

| Chemin (`lib/src/presentation/features/flashcards/`) | L. | Rôle | Porte |
|---|---:|---|---|
| `pages/multi_flashcard_editor_page.dart` | 1 319 | édition en lot | 15 `DynamicFormField`, 18 `setState` |
| `widgets/flashcard_widgets.dart` | 1 250 | carte de grille, réponse, **feuille des modes** | 3 classes, 105 l. commentées |
| `widgets/ai_flashcards_generator_dialog_widget.dart` | 1 238 | génération IA | 12 `setState` |
| `widgets/interactive_flashcard_repetition_card.dart` | 1 205 | carte de session interactive | 13 `setState`, 11 `BoxDecoration` |
| `pages/folder_flashcards_repetitions_page.dart` | 1 202 | **la session** (6 modes) + série | `ConsumerStatefulWidget` + `Get` + `auto_route` |
| `widgets/white_exam_question_card.dart` | 1 139 | question d'examen blanc | 7 `setState`, 9 `BoxDecoration` |
| `pages/folder_flashcards_list_page.dart` | 1 139 | liste des flashcards d'un dossier | `DynamicListSearchController`, **9 `crudDataSelect` clonés** (l. 961-1078) |
| `dialogs/flashcards_dialogs.dart` | 906 | **9 dialogues** (édition, actions, création, IA, balise, filtres, test/examen, modes, sélection de balises) | 6 aiguillages `zcrudFlagValue` |
| `pages/white_exam_page.dart` | 779 | examen blanc à correction différée | |
| `widgets/flashcard_edition_screen.dart` | 770 | formulaire d'une flashcard | 22 `DynamicFormField` |
| `widgets/flashcard_repetition_widgets.dart` | 717 | briques visuelles de session | 13 `BoxDecoration` |
| `controllers/smart_learn_controller.dart` | 568 | contrôleur « fourre-tout » : dossiers, examens, toasts, dialogues, IA | `extends Controller` (clean-architecture legacy) |
| `pages/flashcards_learning_celebration_page.dart` | 403 | célébration | |
| `widgets/export_flashcards_to_pdf.dart` | 390 | export PDF | 7 `DynamicFormField` |
| `controllers/flashcards_learing_controller.dart` | 199 | état de session (nom mal orthographié dans le source) | |
| + les **15 jumeaux portés** du § 3.3 | 2 512 | | tous éteints |

---

## 6. Modèles et persistance

**Entités.** `FlashcardModel extends FolderContentModel` (410 l., 15 champs + `QuestionType` à 5 valeurs +
`QcmChoice`), `FlashcardRepetitionInfo extends DynamicModel` (489 l., 14 champs), `FlashcardTagModel` (90 l.),
`FolderDocumentLearningInfo` (82 l., second porteur de `FlashcardRepetitionQuality`). Tout passe par la
classe maison `DynamicModel` — **24 déclarations `extends DynamicModel` sur 21 fichiers** — avec `toMap()`
manuscrit et `props`. Pas de codegen : **grep négatif** — `grep -rn '@ZcrudModel\|@JsonSerializable' lib | wc -l` → `0`.
La lecture est défensive au cas par cas (`_intOrNull`, `flashcard_repetition_info.dart:207-221` : Firestore peut rendre `2.0` là où `2` a été écrit, et `int.tryParse('2.0')` rendait `null`, **effaçant la progression**).

**Dépôts et fuite d'infrastructure.** Ports `FlashcardRepository` (92 l.), `FlashcardRepetitionRepository`
(70 l.), `FlashcardTagsRepository` (68 l.), tous `extends CrudRepository<T>` avec des `Stream<List<T>>` nus —
mais **`cloud_firestore` fuit dans le domaine** : `Timestamp.fromDate` en `domain/repositories/flashcard_repetition_repository.dart:50-56`, et **15 fichiers de `lib/src/domain/` importent `cloud_firestore`**. Aucune `Either<ZFailure,T>` : les erreurs remontent en exceptions ou sont avalées (`folder_flashcards_repetitions_page.dart:169` — `catch (e) { // Silent fail }`).
Deux adaptateurs zcrud existent mais **ne sont pas branchés** : `ZBackedFlashcardRepository` (797 l.) est
choisi par `useZcrudFlashcardRepository(Ref) => false` (`features/flashcards/providers/flashcard_providers.dart:23`) ;
`FirebaseOwnerScopedRepetitionStore implements ZRepetitionStore` (154 l.) est **du code mort** :
```
$ grep -rn 'FirebaseOwnerScopedRepetitionStore' lib | grep -v 'firebase_owner_scoped_repetition_store.dart'
lib/src/data/repositories/z_backed_folder_document_repository.dart:285:/// … (commentaire)
$ grep -rn 'ZRepetitionStore' lib | grep -v 'firebase_owner_scoped_repetition_store.dart' | wc -l
0
```

---

## 7. Ce qui est particulier à IFFD

1. **Le bonus de retard SM-2** (`interval + (delay × 0.5).round()`) : `ZSrsConfig.overdueBonusFactor` est
   `0.0` par défaut dans le socle. IFFD **doit** passer `kIffdSrsConfig` (`flashcard_repetition_info.dart:57`).
2. **Cinq paliers, pas quatre** — libellés, icônes et couleurs figés dans l'enum
   (`flashcard_repetition_info.dart:181-189`), plus un texte « à revoir » **non temporel**
   (« dans 2 cartes », « à la fin ») propre à l'ordonnancement intra-session d'IFFD.
3. **Le Système Harmonisé douanier** : `FlashcardModel` porte `hsSection`/`hsChapter` (`:106-107`) et sait
   fabriquer des flashcards depuis un corpus d'avis de classement (`:330-346`). Les filtres de session en
   dépendent. Rien de généralisable.
4. **La série vit sur `AppUserData`**, pas sur une entité de session (`domain/models/app_user.dart:273`
   `currentStreak`, plus `lastStudyDate`), et se met à jour **depuis la page de session**, en `catch`
   silencieux, avec un `SnackBar` orange codé en dur. Aucun test, aucun service.
5. **`accademicYear`** (orthographe du source) sur `FlashcardRepetitionInfo:236` : le SRS d'IFFD est
   partitionné par **année académique**.
6. **Français en dur, sans l10n** : 120 littéraux accentués dans 24 fichiers, `AppLocalizations` jamais appelé. Toute bascule exige d'injecter les libellés — le socle le permet (`registerZFlashcardEditors(trueLabel: 'Vrai', …)`, `z_iffd_field_registry.dart:171-176`).
7. **Deux moteurs déclaratifs coexistent** : le `data_crud` legacy embarqué (`lib/data_crud/`, **27 fichiers, 14 980 l.**, dont `edition_screen.dart` à 4 073 l.) et zcrud — 215 `DynamicFormField(` dans `lib/`, dont 60 dans le périmètre. La migration n'est pas terminable sans trancher ce doublon.
