# Carte du domaine « Révision — flashcards : écrans, édition, tags, export » (IFFD)

> Relevé du **2026-08-26**, lecture seule sur `/home/zakarius/DEV/iffd`, HEAD `65d1af9`.
> Socle de référence : zcrud **v3.21.0** (41 paquets, `/home/zakarius/DEV/zcrud/packages`).
> Le relevé `iffd-migration-2026-08-25/` est PÉRIMÉ : rien n'en est repris sans remesure.

---

## 0. Périmètre mesuré

| Zone | Fichiers | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/flashcards/**` | **35** | **18 178** |
| `lib/src/data/repositories/z_backed_flashcard_repository.dart` | 1 | 797 |
| `lib/src/data/repositories/firebase_owner_scoped_repetition_store.dart` | 1 | 154 |
| `lib/src/domain/models/flashcard_{model,repetition_info,tag_model}.dart` | 3 | 989 |
| `lib/src/domain/repositories/flashcard_{repository,repetition_repository,tags_repository}.dart` | 3 | 230 |
| `lib/src/utils/flashcard_filters.dart` | 1 | 90 |
| `lib/src/features/flashcards/` (providers Riverpod + `.g.dart`) | 3 | 553 |
| **Total périmètre** | **47** | **20 991** |

⚠️ **Les deux dossiers annoncés au brief sont VIDES.** `ls -la lib/src/domain/models/flashcard`
et `.../flashcard_tag` : `total 8`, aucun fichier — seulement `.` et `..`, datés du 6 fév. 2026.
Les modèles sont des fichiers **plats** dans `lib/src/domain/models/`.

**Inclus au-delà du point de départ** (dépendances réelles suivies) :
`lib/data_crud/**` — le moteur déclaratif legacy, **14 980 lignes / 23 fichiers**, dont
`edition_screen.dart` (**4 073 l.**), `dynamic_list_screen.dart` (1 753 l.),
`rich_text_editor_screen.dart` (773 l.) et les embeds LaTeX/tableaux (3 081 l.). C'est le jumeau
historique de `zcrud_core` + `zcrud_markdown` + `zcrud_list`, et le domaine flashcards en est un
**gros consommateur** : 60 déclarations `DynamicFormField(` sur 215 dans tout le dépôt (28 %),
10 sites `EditionScreen(`, 29 sites `RichTextReaderScreen`.

---

## 1. 🔴 Le code répété

Compté par `grep -rn` sur les 47 fichiers du périmètre. « sites » = occurrences ; « fichiers » =
fichiers distincts.

| # | Bloc répété | Sites | Fichiers | Lignes en jeu | Preuve |
|---|---|---:|---:|---:|---|
| D1 | **Déclaration de champ** `DynamicFormField(` | **60** | 7 | ~1 500 | `flashcard_edition_screen.dart` 22×, `multi_flashcard_editor_page.dart` 15×, `export_flashcards_to_pdf.dart` 7×, `test_exam_filter_screen.dart` 6×, `smart_learn_controller.dart` 4×, `folder_flashcards_list_page.dart` 4×, `flashcards_dialogs.dart` 2× |
| D2 | **Câblage d'un lecteur riche** `RichTextReaderScreen(` + `getDefaultStyleSheet(` recopié à la main | **29** / **14** | 7 | ~900 | `flashcard_widgets.dart` 7×, `interactive_flashcard_repetition_card.dart` 6×, `white_exam_question_card.dart` 5×, `flashcard_repetition_widgets.dart` 4×, `flashcard_list_rich_reader_zcrud.dart` 3×, `review_rich_reader_zcrud.dart` 3×, `multi_flashcard_editor_page.dart` 1× |
| D3 | **Branche legacy/porté** (strangler fig) : `if (useZcrud) … else …` | **59** | **22** | ~1 200 | `grep -rn 'UseZcrudProvider\|useZcrud'` — chaque écran porté vit **en double** |
| D4 | **`setState(` à l'échelle de l'écran** (violation SM-1) | **72** | **10** | — | `interactive_flashcard_repetition_card.dart`, `white_exam_question_card.dart`, `multi_flashcard_editor_page.dart`, `flashcards_dialogs.dart`, … |
| D5 | **Indicateur de chargement** `CircularProgressIndicator` monté à la main | **12** | 7 | ~60 | `white_exam_question_card.dart:606,1019,1095` ; `ai_flashcards_generator_dialog_widget.dart:656,742,944` ; `interactive_flashcard_repetition_card.dart:937,1010` ; `flashcards_dialogs.dart:784` ; `white_exam_page.dart:384` ; `flashcard_widgets.dart:799` ; `multi_flashcard_editor_page.dart:376` |
| D6 | **Saisie QCM** `_buildQCMInput` / `_buildChoicesSection` | **3** | 3 | 102 + 97 + 149 = **348** | `interactive_…:686-787`, `white_exam_question_card.dart:679-775`, `flashcard_repetition_widgets.dart:484-632`. `diff -y --suppress-common-lines` entre les deux premiers : **34 lignes divergentes sur 102** — ~67 % identique |
| D7 | **Saisie vrai/faux** `_buildTrueFalseInput` | **2** | 2 | 103 + 88 = **191** | `interactive_…:788-890` vs `white_exam_question_card.dart:776-863` — **31 lignes divergentes sur 103**, ~70 % identique |
| D8 | **Saisie texte libre** `_buildTextInput` | **2** | 2 | 21 + 41 = **62** | `interactive_…:891-911`, `white_exam_question_card.dart:864-904` |
| D9 | **En-tête de carte** `_buildHeader` | **2** | 2 | 29 + 104 = **133** | `interactive_…:580-608`, `flashcard_repetition_widgets.dart:319-422` |
| D10 | **Badge de consigne** `_buildInstructionBadge` | **2** | 2 | 65 + 61 = **126** | `interactive_…:609-673`, `flashcard_repetition_widgets.dart:423-483` |
| D11 | **Pied de carte** `_buildFooter` | **2** | 2 | 76 + 85 = **161** | `interactive_…:1130-1205`, `flashcard_repetition_widgets.dart:633-717` |
| D12 | **Exporteur PDF** : `_ExportFlashcardsToPdfState` (142 l.) vs `_ExportMarkdownToPdfState` (185 l.) dans **le même fichier** | 2 | 1 | **327** | `export_flashcards_to_pdf.dart:51-192` vs `:206-390` — **108 lignes divergentes** sur 185, soit ~42 % recopié |
| D13 | **Confirmation de suppression** montée à la main | **6** | 4 | ~70 | `multi_flashcard_editor_page.dart:151-161` et `:230-240`, `flashcard_actions_dialog_widget.dart:103-108`, `folder_flashcards_list_page.dart:655`, plus les libellés dupliqués côté porté (`flashcard_batch_zcrud.dart:58`, `flashcard_list_zcrud.dart:213`, `multi_flashcard_editor_zcrud.dart:81,90`) |
| D14 | **Retour de navigation** `Get.back` | **33** | **13** | — | mélangé à 13 sites `Navigator.` — deux conventions de navigation cohabitent |
| D15 | **`Theme.of(context)`** relu localement au lieu d'un jeton injecté | 15 | **12** | — | — |
| D16 | **Bascule d'état de carte** (`StatefulWidget` + `initState`/`dispose` recréés) | 17 déclarations | 15 | — | 17 `StatefulWidget` + 14 `StatelessWidget` sur 35 fichiers |

**Total mesurable du seul code de carte de révision recopié (D6→D11) : 1 021 lignes sur 4 sites.**

### Ce que ces répétitions désignent comme assemblage manquant

| Répétition | Ce que le socle a déjà (v3.21.0) | Consommé par IFFD ? |
|---|---|---|
| D6, D7, D8 | `ZFlashcardAnswerInput` — `zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart`, **1 645 l.** | **OUI mais partiellement** : 5 occurrences, uniquement dans `review_session_zcrud.dart` (derrière le flag `reviewSession`). Les 3 cartes legacy gardent leurs 348 + 191 + 62 lignes. |
| D9, D10, D11 | `ZFlashcardReviewCard` — `zcrud_flashcard/…/z_flashcard_review_card.dart`, **1 044 l.** | 4 occurrences, `review_card_zcrud.dart` seul |
| D2 | `ZMarkdownReader` (`zcrud_markdown`) + `ZRichTextStyleSet` | **2** sites `ZMarkdownReader(` contre **29** `RichTextReaderScreen` |
| D5, D13 | états et confirmations de `zcrud_screen` / `ZCrudScreen` | `presentFormEdition` : 1 import |
| D1 | `ZFieldSpec` (77 occ.) + `ZFieldChoice` (68 occ.) | **branché**, mais en parallèle des 60 `DynamicFormField` |

---

## 2. Ce que le domaine sait faire (en termes d'utilisateur)

1. **Tenir une grille de flashcards par dossier**, avec recherche, filtres et sélection multiple
   (`folder_flashcards_list_page.dart`, 1 139 l.).
2. **Créer / modifier une flashcard** : question, réponse, type (QCM, vrai-faux, question ouverte,
   exercice), propositions de QCM, explication, indice, balises — en texte riche (LaTeX, tableaux,
   gras/titres colorés).
3. **Éditer plusieurs flashcards à la suite** dans un éditeur multiple avec brouillon
   (`multi_flashcard_editor_page.dart`, 1 319 l.).
4. **Générer des flashcards par l'IA** depuis un document, une note ou une conversation : choix du
   modèle, instructions, nombre de questions **par type** (`ai_flashcards_generator_dialog_widget.dart`,
   1 238 l.).
5. **Réviser en répétition espacée** (SM-2) : carte qui se retourne, cinq paliers de notation,
   indice payant, évaluation de la réponse libre par l'IA
   (`folder_flashcards_repetitions_page.dart` 1 202 l., `interactive_flashcard_repetition_card.dart`
   1 205 l.).
6. **Mode apprentissage** — parcours guidé avec encouragements et page de célébration
   (`flashcards_learning_celebration_page.dart`, 403 l.).
7. **Passer un examen blanc** chronométré, avec correction et **ré-explication par l'IA**
   (`white_exam_page.dart` 779 l., `white_exam_question_card.dart` 1 139 l.).
8. **Filtrer une session** par balises, documents, notes, et — spécifique IFFD — par **sections /
   chapitres du Système Harmonisé** ou par les **neuf outils de la valeur en douane**.
9. **Étiqueter** les flashcards (balises colorées) : créer, modifier, sélectionner.
10. **Exporter en PDF** un paquet de flashcards ou une réponse de l'assistant, avec titre et module
    imprimés en tête (`export_flashcards_to_pdf.dart`, 390 l.).
11. **Apprentissage « intelligent »** — sélection automatique de ce qu'il faut réviser
    (`smart_learn_controller.dart`, 568 l.).

---

## 3. Ce qui est DÉJÀ branché sur zcrud

### 3.1 Paquets consommés dans le périmètre (imports mesurés)

IFFD déclare **23 paquets `zcrud_*`** en `dependencies` (`pubspec.yaml`) ; **`zcrud_export` et
`zcrud_list` n'en font PAS partie** et ne sont importés nulle part (`grep -rn 'package:zcrud_export\|package:zcrud_list' lib` = 0).


`zcrud_core` (8 imports), `zcrud_study` (3), `zcrud_flashcard` (4), `zcrud_session` (3),
`zcrud_screen` (3), `zcrud_navigation` (2), `zcrud_markdown` (2), `zcrud_study_kernel` (1).

Symboles les plus employés : `ZFieldSpec` (77), `ZFieldChoice` (68), `ZFlashcard` (17),
`ZCondition` (16), `ZValidatorSpec` (15), `ZFormController` (13), `ZRelationSourceRegistry` (9),
`ZMarkdownReader` (9 mentions / **2 montages**), `ZEditionSubmitController` (9), `ZEditionStep` (8).

### 3.2 Écrans à jumeau porté (`lib/src/presentation/features/flashcards/zcrud/` + 3 hors dossier)

| Drapeau (`z_qa_flags.dart`) | Jumeau porté | Lignes | Famille QA | Écrit en base ? |
|---|---|---:|---|---|
| `flashcardList` | `zcrud/flashcard_list_zcrud.dart` | 219 | comportement | non |
| `flashcardListRichReader` | `zcrud/flashcard_list_rich_reader_zcrud.dart` | 252 | rendu | non |
| `multiEditor` | `zcrud/multi_flashcard_editor_zcrud.dart` | 243 | données | **oui** |
| `reviewSession` | `zcrud/review_session_zcrud.dart` | 131 | données | **oui** |
| `reviewRichReader` | `zcrud/review_rich_reader_zcrud.dart` | 235 | rendu | non |
| `srsQuality` | `zcrud/srs_quality_zcrud.dart` | 183 | données | **oui** |
| `flashcardEdition` | `zcrud/flashcard_edition_zcrud.dart` | 579 | données | **oui** |
| `flashcardsQuestionsCount` | `zcrud/flashcards_questions_count_zcrud_edition.dart` | 276 | comportement | non |
| `flashcardTag` | `dialogs/flashcard_tag_zcrud_edition.dart` | 241 | comportement | non |
| `testExamFilter` | `widgets/test_exam_filter_zcrud_screen.dart` | 376 | comportement | non |
| `folderFlashcardsFilter` | `zcrud/folder_flashcards_filter_zcrud_edition.dart` | 738 | comportement | non |
| `exportPdfOptions` | `zcrud/export_flashcards_to_pdf_zcrud_edition.dart` | 175 | comportement | non |
| (sans flag propre) | `zcrud/review_card_zcrud.dart` | 180 | — | non |
| (sans flag propre) | `zcrud/flashcard_batch_zcrud.dart` | 214 | — | non |
| `aiBaseUrl` | `controllers/ai_base_url_zcrud_edition.dart` | 284 | comportement | non |

**15 jumeaux portés, 4 326 lignes.** Les 12 drapeaux du domaine « flashcards » sur les **52 bascules**
du plan QA (`docs/qa-plan-comparaison-legacy-zcrud.md`, 651 l.) — soit **23 %** du plan.

### 3.3 Chemin de données

`z_backed_flashcard_repository.dart` (797 l.) est le **troisième cutover strangler fig** (W5) :
il transite par l'entité réelle `ZFlashcard` (`ZBackedFlashcardMapper.toCanonical`), derrière un
flag Riverpod dont le **défaut reste LEGACY**. Le planificateur SM-2 du socle (`ZSm2Scheduler`,
`ZSrsConfig`) est adopté avec `kIffdSrsConfig = ZSrsConfig(overdueBonusFactor: 0.5)`
(`flashcard_repetition_info.dart:56`), également derrière une bascule strangler fig.

### 3.4 Registres et adaptateurs maison (`lib/src/presentation/shared/zcrud/`, 14 fichiers, 3 234 l.)

`z_iffd_field_registry.dart`, `z_iffd_relation_source.dart`, `z_iffd_field_palette.dart`,
`z_iffd_form_theme.dart`, `z_iffd_markdown_style.dart`, `z_iffd_rich_text_codec.dart`,
`z_iffd_stepper.dart`, `z_iffd_value_adapters.dart`, `z_iffd_acl_matrix_field.dart`,
`z_iffd_boolean_field.dart`, `z_questions_counts_field.dart`, `z_text_transforms.dart`,
`z_flag_gateway.dart`, `z_qa_flags.dart` (985 l.).

### 3.5 CR ouvertes issues de ce domaine (registre `docs/zcrud-change-requests.md`, 440 Ko)

| CR | Sujet | État |
|---|---|---|
| **CR-IFFD-114** (`:7589`) | géométrie du tableau markdown rendu, figée dans `_buildTable` (`z_table_embed.dart:187`) — pas d'échappatoire | **ouverte** |
| **CR-IFFD-115** (`:7675`) | `softLineBreak` non déclarable — `_ZSoftLineBreakSyntax` (`z_markdown_codec.dart:283-297`) enregistrée inconditionnellement | **ouverte** |
| **CR-IFFD-116** (`:7734`) | `showZRichTextFullscreenDialog` sans `subtitle` (quatrième surface) | **ouverte** |
| CR-IFFD-117 → 120 (`:7787`, `:7825`, `:7859`, `:7879`) | encodage sortie dialogue, `onTapLink`, `padding` du lecteur, plein cadre forcé | **RETIRÉES AVANT ÉMISSION** — le canal existait |

🔴 **CR-115 bloque directement ce domaine** : le drapeau `flashcardListRichReader` bascule le rendu
de la RÉPONSE mais **pas celui de la QUESTION**, « elle seule passe `softLineBreak`, que le socle
n'a pas » (`z_qa_flags.dart:266-268`). Une tuile rend donc sa question par `RichTextReaderScreen`
et sa réponse par `ZMarkdownReader` — **deux moteurs dans une même tuile**.

---

## 4. Les widgets maison qui refont ce que le socle fait

Vérifié par grep négatif sur **tout** `lib` d'IFFD (`grep -rn "\bZSymbole\b" lib`).

| Widget maison | Chemin | Lignes | Équivalent socle v3.21.0 | Occurrences chez IFFD |
|---|---|---:|---|---:|
| `WhiteExamPage` + `ExamAnswer` | `pages/white_exam_page.dart` | 779 | `ZWhiteExamSessionView` (283 l.) + `ZWhiteExamSessionEngine` (420 l.) + `ZWhiteExamSessionController` | **0 / 0 / 0** |
| `WhiteExamQuestionCard` | `widgets/white_exam_question_card.dart` | 1 139 | `ZFlashcardReviewCard` (1 044 l.) + `ZFlashcardAnswerInput` (1 645 l.) + `ZCorrectionVisibility` | 4 / 5 / **0** |
| `InteractiveFlashcardRepetitionCard` | `widgets/interactive_flashcard_repetition_card.dart` | 1 205 | `ZFlashcardReviewCard`, `ZFlashcardHintPort` (131 l.), `ZHintPenalty`, `ZFlashcardLocalEvaluation` (135 l.), `ZFlashcardAnswerEvaluationPort` | **0 / 0 / 0 / 0** pour les quatre derniers |
| `FlashcardRepetitionCard` | `widgets/flashcard_repetition_widgets.dart` | 717 | `ZFlashcardReviewCard` + `ZRevealTransition` | `ZRevealTransition` : 2 |
| `CardSwiperButtons` + le carrousel de `FolderFlashcardsRepetitionsPage` | `pages/folder_flashcards_repetitions_page.dart` | 1 202 | `ZSessionCardSwiper` (648 l.) + `ZStudySessionEngine` (254 l.) + `ZSessionProgressIndicator` + `ZCardAdvanceBehavior` | **0 / 1 (mention) / 0 / 0** |
| `LearningCelebrationPage` | `pages/flashcards_learning_celebration_page.dart` | 403 | `ZSessionSummaryView` (846 l.) + `ZStudyProgressRings` + `ZStreakBadge` / `ZStreakToast` | **0 / 0 / 0 / 0** |
| `LearningModeQuestionCard` (messages d'encouragement en dur) | `widgets/learning_mode_question_card.dart` | 251 | `ZSessionFeedbackBank` | **0** |
| `TestExamFilterScreen` | `widgets/test_exam_filter_screen.dart` | 134 | `ZTestFiltersDialog` (411 l.) | **0** |
| `FlashcardCard` / `FlashcardsLearningModeScreen` | `widgets/flashcard_widgets.dart` | 1 250 | `ZFlashcardListView` + `ZListSessionView` (704 l.) | 4 / **0** |
| `_FlashcardTagsSelectionWidget` | `dialogs/flashcards_dialogs.dart:704-906` | 202 | `ZRelationConfig` + `ZRelationSource` (branchés ailleurs) | `ZRelationConfig` : 6 |
| `Sm` (SM-2 maison) | `domain/models/flashcard_repetition_info.dart:100-180` | ~80 | `ZSm2Scheduler` | adopté derrière bascule |
| `ExportFlashcardsToPdf` / `ExportMarkdownToPdf` | `widgets/export_flashcards_to_pdf.dart` | 390 | `zcrud_export` — **non déclaré**, et le verrou invoqué a DISPARU (cf. §7) | 0 import |
| Moteur déclaratif `data_crud` | `lib/data_crud/**` | **14 980** | `zcrud_core` + `zcrud_markdown` + `zcrud_list` | cohabitation |

**Somme des équivalents socle jamais montés** (`ZWhiteExamSessionView/Engine`, `ZSessionCardSwiper`,
`ZSessionSummaryView`, `ZListSessionView`, `ZTestFiltersDialog`, `ZFlashcardChoicesFieldWidget`,
`ZFlashcardTypeFieldWidget`, `ZFlashcardTrueFalseFieldWidget`, `ZFlashcardHintPort`,
`ZFlashcardLocalEvaluation`, `ZFlashcardFilters`, `ZSessionFeedbackBank`, `ZStudyProgressRings`,
`ZStreakBadge`, `ZReduceMotion`, `ZSessionCategorization`, `ZFlashcardDuplicate`,
`ZFlashcardSort`, `ZFlashcardSearchText`, `ZCorrectionVisibility`, `ZCardAdvanceBehavior`,
`ZSessionModeSelector`, `ZSessionQualityBreakdown`, `ZTimerDisplay`) :
**24 symboles publics à 0 occurrence** dans `lib` d'IFFD, pour environ **5 500 lignes de socle
inutilisées** face à ~5 700 lignes maison qui font le même travail.

---

## 5. Écrans et dialogues

| Chemin (`lib/src/presentation/features/flashcards/`) | Lignes | Rôle | Porte |
|---|---:|---|---|
| `pages/multi_flashcard_editor_page.dart` | 1 319 | Éditeur multi-flashcards | 15 `DynamicFormField`, 2 confirmations de suppression, brouillon |
| `widgets/flashcard_widgets.dart` | 1 250 | Tuile de carte, réponse, mode apprentissage | 7 lecteurs riches, `FlashcardCard`, `FlashcardAnwserWidget`, `FlashcardsLearningModeScreen` |
| `widgets/ai_flashcards_generator_dialog_widget.dart` | 1 238 | Génération IA | 3 indicateurs de chargement, choix de modèle |
| `widgets/interactive_flashcard_repetition_card.dart` | 1 205 | Carte de révision interactive | QCM/VF/texte, indice, feedback, 5 paliers |
| `pages/folder_flashcards_repetitions_page.dart` | 1 202 | Session de révision (carrousel) | `CardSwiperButtons`, `FlashcardRepetitionPageType` |
| `widgets/white_exam_question_card.dart` | 1 139 | Question d'examen blanc | QCM/VF/texte, ré-explication IA, couleur/titre de qualité |
| `pages/folder_flashcards_list_page.dart` | 1 139 | Grille des flashcards d'un dossier | `FolderFlashcardsListController extends DynamicListSearchController`, `FolderFlashcardsListFilterScreen` |
| `dialogs/flashcards_dialogs.dart` | 906 | **9 dialogues** (édition, actions, création, IA, balise, nb de questions, filtre liste, filtre test/examen, mode apprentissage, sélection de balises) | 6 bascules `useZcrud` |
| `pages/white_exam_page.dart` | 779 | Examen blanc complet | chronomètre, `ExamAnswer` |
| `widgets/flashcard_edition_screen.dart` | 770 | Formulaire legacy de flashcard | **22** `DynamicFormField`, `QuestionsDifficulty`, `FlashcardsQuestionsCountEditionScreen` |
| `zcrud/folder_flashcards_filter_zcrud_edition.dart` | 738 | Filtre porté (SH + outils valeur) | `ZValuationToolFilterSpec` |
| `widgets/flashcard_repetition_widgets.dart` | 717 | Carte de révision « retournable » | `_buildHeader`, `_buildInstructionBadge`, `_buildChoicesSection`, `_buildFooter` |
| `zcrud/flashcard_edition_zcrud.dart` | 579 | Formulaire porté | `FlashcardTagsRelationSource extends ZRelationSource` |
| `controllers/smart_learn_controller.dart` | 568 | Apprentissage intelligent | `extends Controller`, 4 `DynamicFormField` |
| `pages/flashcards_learning_celebration_page.dart` | 403 | Célébration de fin de session | animation |
| `widgets/export_flashcards_to_pdf.dart` | 390 | Aperçu + export PDF (×2) | 7 `DynamicFormField` |
| `widgets/test_exam_filter_zcrud_screen.dart` | 376 | Filtres test/examen portés | — |
| `controllers/ai_base_url_zcrud_edition.dart` | 284 | URL de base IA portée | — |
| 17 autres fichiers (`zcrud/`, `dialogs/`, petits widgets) | 1 246 | jumeaux portés + dialogues courts | — |

---

## 6. Modèles et persistance

**Entités.** `FlashcardModel extends FolderContentModel` (410 l.) porte 17 champs déclarés :
`question`, `type` (`QuestionType`, 4 valeurs), `answer`, `choices` (`List<QcmChoice>`), `isTrue`,
`explanation`, `indice`, `tagsIds`, `documentId`, `pageNumber`, `noteId`, `hsSection`, `hsChapter`,
`chatConversationId`, `chatMessageId`, `isReadOnly`, plus `canonicalHsChapter` (`:133`) et
`subjectDefaultFlashcards` (`:327`). Sérialisation **manuelle** : `toMap()` (`:177`),
`fromMap()` (`:202`), `fromJson()` (`:268`) — **aucun codegen**. `QcmChoice` (`:49`) porte
`id` / `content` nullable / `isCorrect`. `FlashcardTagModel` (90 l.) et `RepetitionInfo` /
`Sm` (`flashcard_repetition_info.dart`, 489 l.) complètent le schéma. `cloud_firestore` est importé
**directement dans le modèle de domaine** (`flashcard_repetition_info.dart:8`) — fuite d'infrastructure
que l'AD-11 interdit côté socle.

**Dépôts.** Trois ports (`flashcard_repository.dart` 92 l., `flashcard_repetition_repository.dart`
70 l., `flashcard_tags_repository.dart` 68 l.) ; l'implémentation Firebase historique cohabite avec
`ZBackedFlashcardRepository` (797 l.), adaptateur strangler fig sur `ZFlashcard`. Les écarts de schéma
sont **doublés dans `extra`** : `extra['iffd_type']` (4 valeurs `QuestionType` ⇄ 6 valeurs
`ZFlashcardType`, avec repli défensif sur `openQuestion`) et `extra['iffd_choices']` (verbatim, car
`ZChoice` n'a ni `id` ni `content` nullable) — source de foi au retour, round-trip garanti.
`FirebaseOwnerScopedRepetitionStore` (154 l.) porte l'état SRS séparé de la carte, conformément à
AD-9. Les erreurs passent par `Either<ZFailure, T>` sur le chemin porté (`ZFailure` : 5 occurrences,
`Right`/`Unit`/`unit` importés de `zcrud_core/domain.dart`).

---

## 7. Ce qui est particulier à IFFD et résisterait à la généralisation

| Particularité | Où | Pourquoi ça résiste |
|---|---|---|
| **Système Harmonisé (SH)** — sections et chapitres douaniers, avec recalcul en cascade section → chapitre et signalement « hors catalogue » | `flashcard_model.dart:106-141` (`hsSection`, `hsChapter`, `canonicalHsChapter`), `folder_flashcards_filter_zcrud_edition.dart`, `utils/constants/sh2022.dart` | Nomenclature métier douanière ; le socle a le seam (`ZCondition`, `ZRelationSource`) mais pas le référentiel |
| **Les neuf outils de la valeur en douane**, triés par identifiant **numérique** (1, 2, 10 — jamais 1, 10, 2) | `folder_flashcards_filter_zcrud_edition.dart:213` `ZValuationToolFilterSpec` (16 occurrences) | Tri métier ; généralisable en `ZFieldChoice` ordonné, la donnée non |
| **`overdueBonusFactor: 0.5`** — bonus de retard SM-2, opt-in côté socle (défaut 0.0, CR-LEX-37) | `flashcard_repetition_info.dart:56` | Politique pédagogique IFFD, déjà déclarable |
| **`softLineBreak: true` sur la QUESTION seule** | `flashcard_widgets.dart:426` | Bloqué par **CR-IFFD-115** ; jusqu'à sa livraison, deux moteurs de rendu dans une même tuile |
| **Ré-explication d'une réponse par l'IA en cours d'examen** | `white_exam_question_card.dart:226` `_regenerateExplanation` | Couplage session ⇄ IA ; le socle a `ZFlashcardAnswerEvaluationPort` (0 occurrence chez IFFD) mais pas ce parcours |
| **Indice payant** (`_requestHint`, pénalité) | `interactive_flashcard_repetition_card.dart:331` | `ZFlashcardHintPort` (131 l.) + `ZHintPenalty` existent au socle, **0 occurrence** chez IFFD |
| **`FlashcardGeneratorSource`** — provenance de la carte (document, note, conversation, scan) avec icône et sous-titre | `flashcard_model.dart:36-45` | Correspond à `ZSourceRegistry`/`ZFlashcardSource` (AD-4), non branché |
| **Bibliothèque de messages d'encouragement en français, en dur** | `learning_mode_question_card.dart:99` `_getEncouragementMessage`, `:155` `_getMotivationMessage` (`"Excellent ! Tu as trouvé sans aucune aide !"` `:128`) | `ZSessionFeedbackBank` existe (0 occurrence) ; les textes eux-mêmes sont éditoriaux |
| 🔴 **Le verrou Syncfusion a sauté et personne ne l'a vu** : le commentaire `pubspec.yaml:292` dit encore « `zcrud_list` / `zcrud_export` exigent Syncfusion ^34, IFFD est en ^32 » — or `pubspec.yaml:141-148` déclare **^34.1.31** sur les huit paquets Syncfusion | `pubspec.yaml:141-148` vs `:292` | **Ce n'est plus une particularité, c'est un commentaire périmé.** `grep -rn 'package:zcrud_export\|package:zcrud_list' lib` = **0**, et ni l'un ni l'autre n'est déclaré en `dependencies` (les 4 occurrences dans ce bloc sont toutes des commentaires). Les 390 l. d'export PDF et les 1 753 l. de `data_crud/dynamic_list_screen.dart` restent maison **sans raison technique subsistante** |
| **Chaîne d'appel morte** : `showQuestionsTypesSelectionDialig` (déclarée `flashcards_dialogs.dart:344`) n'a **aucun** site d'appel — la bascule `flashcardsQuestionsCount` est **non atteignable à l'appareil** | remesuré le 2026-08-26 : `grep -rn 'showQuestionsTypesSelectionDialig(' lib` → **1 seule ligne**, sa propre déclaration ; 7 occurrences du nom en tout, les 6 autres en commentaires | Portage livré (276 l.) sur un écran que rien n'ouvre |

---

## Trois chiffres à retenir

1. **1 021 lignes** de carte de révision recopiées sur **4 fichiers** (D6→D11), face à
   `ZFlashcardReviewCard` (1 044 l.) + `ZFlashcardAnswerInput` (1 645 l.) déjà publiés.
2. **24 symboles publics du socle à 0 occurrence** dans tout `lib` d'IFFD — dont la totalité du
   runtime d'examen blanc et de session (`ZWhiteExamSessionView/Engine`, `ZSessionCardSwiper`,
   `ZSessionSummaryView`, `ZListSessionView`, `ZTestFiltersDialog`), soit ~5 500 lignes de socle
   inutilisées pour ~5 700 lignes maison équivalentes.
3. **59 branches `useZcrud` sur 22 fichiers** : chaque écran porté du domaine vit **en double**, et
   la dette de bascule est aujourd'hui plus grosse que la dette d'origine sur ces fichiers-là.
