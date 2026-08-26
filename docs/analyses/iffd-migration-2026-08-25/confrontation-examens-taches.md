# Confrontation « Examens, évaluations, tâches, découverte » — carte IFFD × API réelle du socle

**Carte confrontée** : `docs/analyses/iffd-migration-2026-08-25/carte-examens-taches.md`
**Socle mesuré** : `/home/zakarius/DEV/zcrud/packages/` — **40 paquets**, tag **v3.21.0** (`git tag --sort=-v:refname | head -1`)
**Hôte mesuré** : `/home/zakarius/DEV/iffd` — **lecture seule stricte**, aucune écriture
**Date** : 2026-08-25

> Rien de la carte n'a été repris sur parole : chaque constat réutilisé a été **remesuré sur disque**
> et porte sa commande. Toutes les affirmations d'**absence** portent leur grep négatif montré (§7).

---

## 0. Ce que la revérification a corrigé ou précisé dans la carte

| # | Constat de la carte | Vérification sur disque | Verdict |
|---|---|---|---|
| 0.1 | « `lib/workflow/` ne contient pas une occurrence de `zcrud` » | `grep -rn "zcrud" lib/workflow --include='*.dart'` → **RC=1** | ✅ confirmé |
| 0.2 | « `zcrud_screen` jamais importé dans le périmètre » | Exact pour le périmètre — mais **`ZCrudScreen` n'est utilisé NULLE PART dans `lib/`** : ses 4 seules occurrences du dépôt sont dans `test/` (tripwires). L'hôte n'importe de `zcrud_screen` que `presentFormEdition` (9 fichiers) | ⚠️ plus large que dit |
| 0.3 | « le socle n'offre aucun moyen déclaratif de dériver un champ d'un autre » (`exam_zcrud_edition.dart:46`) | **FAUX aujourd'hui** : `ZFieldSpec.derivedFrom` existe (`zcrud_core/lib/src/domain/edition/z_field_spec.dart:74`, `:200`), `ZDerivation` est déclaré (`zcrud_core/lib/src/domain/edition/z_derivation.dart:201`) — et **IFFD s'en sert déjà dans deux autres formulaires** (`subject_zcrud_edition.dart:588`, `flashcard_edition_zcrud.dart:383`). Le commentaire du formulaire d'examen est **périmé** | 🔴 corrigé |
| 0.4 | « `zcrud_list` / `zcrud_export` délibérément absents : exigent Syncfusion ^34, IFFD est en ^32 » (`pubspec.yaml:292`) | **Commentaire périmé** : `pubspec.yaml:141-149` déclare **`syncfusion_flutter_*: ^34.1.31`** (datagrid inclus, `:144`), exactement la contrainte de `zcrud_list/pubspec.yaml:36` et `zcrud_export/pubspec.yaml:42-43`. Le blocage **n'existe plus** | 🔴 corrigé |
| 0.5 | Comptes de lignes des écrans (333 / 779 / 1 066 / 1 101 / 93 / 134 / 376) | `wc -l` : identiques à l'unité près | ✅ confirmé |
| 0.6 | Drapeaux QA `exam` et `valuationTool` actifs, `testExamFilter` non | `main.dart:201-210` : le `Set<String> qaFlags` contient `'exam'` et `'valuationTool'`, **pas** `'testExamFilter'` | ✅ confirmé |
| 0.7 | `useZcrudExamsRepository` à `false` | `exam_providers.dart:19` : `bool useZcrudExamsRepository(Ref ref) => false;` | ✅ confirmé |
| 0.8 | `ZExam` consommé | **Uniquement** dans `z_backed_exam_repository.dart` (chemin de données, drapeau à `false`). **Zéro** usage en présentation | ✅ confirmé, et c'est le point aveugle central |

---

## 1. DÉJÀ MIGRÉ

Ce que l'hôte consomme réellement du socle dans ce périmètre — sites cités, mesurés.

| Capacité de la carte | Canal socle consommé | Site hôte |
|---|---|---|
| §1.5 / n° 43 — routeur IA choisi, gouverné, persistant | `ZChatRouteSession` (`zcrud_chat/lib/src/presentation/routing/z_chat_route_session.dart:194`) + `ZAllowAllChatRouteGate` | `discovry_page_controller.dart:636` (champ), `:645` `attachRouteCatalog`, `:648-652` |
| §1.5 — catalogue de routes par tâche | `ZChatRouteCatalogPort` / `ZChatRouteSpec` (`zcrud_chat_kernel/lib/src/domain/route/z_chat_route_spec.dart:20`) | `lib/ai_assistant/zcrud/notebook_route_catalog_iffd.dart`, appelé depuis `discovry_page_controller.dart:647` |
| §3.3 — chemin de données examens sur l'entité canonique | `ZExam` (`zcrud_exam/lib/src/domain/z_exam.dart:72`), `ZReminderRecurrence` (`z_reminder_recurrence.dart:42`), `ZReminderTime`, `ZSyncMeta` | `z_backed_exam_repository.dart:91-93`, `:481` — **écrit et testé (912 lignes + 1 215 de tests `test/w5f/`), mais inerte : drapeau `false`** |
| §2.1 — formulaire d'examen | `DynamicEdition` + `ZFieldSpec` + `ZFormController` + `ZEditionSubmitController` + `ZRelationSourceRegistry` (`zcrud_core`) | `exam_zcrud_edition.dart:66`, actif en QA (`main.dart:204`) |
| §2.2 — formulaire d'outil de valeur | idem + codec rich-text markdown | `valuation_tool_model_zcrud_edition.dart:75`, actif en QA (`main.dart:205`) |
| §2.1 — filtres de test | idem | `test_exam_filter_zcrud_screen.dart:52` — **écrit, non routé** (`testExamFilter` absent du `Set` de `main.dart`) |
| §4.3 — chrome de champ, registre de widgets, teinte, ACL | `ZcrudScope` (widgetRegistry, theme, gradientResolver, iconResolver, colorKeyResolver, relationSourceRegistry, subListSeams), `registerZMarkdownFields`, `registerZFlashcardEditors`, `ZPhoneFieldWidget` | `z_iffd_field_registry.dart:78`, `:101`, `:171`, `:188`, `:227` |
| Hors périmètre mais adjacent — carnet IA | `ZChatArtifactDeclaration` / `ZChatArtifactGenerationPort` / `ZChatArtifactStorePort` / `ZChatTranscriptPort` | `lib/ai_assistant/zcrud/notebook_artifact_*.dart` — **1 493 lignes de câblage déjà écrites** |
| Hors périmètre mais adjacent — révision de flashcards | `ZFlashcardAnswerInput`, `ZFlashcardSubmission`, `ZSrsQualityButtons` (`zcrud_session`) | `review_session_zcrud.dart:35-37`, `srs_quality_zcrud.dart` — **drapeau `false` (`kReviewSessionUseZcrudDefault`)** |
| Hors périmètre mais adjacent — adaptateur carte | `iffdCardToZ` : `FlashcardModel → ZFlashcard` | `review_card_zcrud.dart` (180 lignes) — **l'adaptateur qui débloque l'examen blanc existe déjà** |

🔴 **Le motif dominant de cette colonne** : le socle est branché **au niveau du formulaire et de la
donnée**, jamais au niveau de **l'écran, de la liste, de la session ni du fil IA**. Et trois des
branchements les plus coûteux (`ZBackedExamRepository`, `test_exam_filter_zcrud_screen`,
`review_session_zcrud`) sont **écrits, testés, et éteints par un drapeau**.

---

## 2. MIGRABLE AUJOURD'HUI

La catégorie la plus précieuse : le socle sait déjà le faire, l'hôte l'ignore.
Chaque ligne nomme l'API exacte avec son `fichier:ligne` dans `/home/zakarius/DEV/zcrud/packages/`.

### 2.1 Examens

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M1** | `ExamTitleDeriver` — dérivation « le titre vient du dossier », câblée impérativement (`fieldListenable().addListener` + jeton de génération anti-course) : `exam_zcrud_edition.dart:294-375` + câblage `:430`, `:449-452` | `ZFieldSpec.derivedFrom` (`zcrud_core/lib/src/domain/edition/z_field_spec.dart:200`) + `ZDerivation` (`zcrud_core/lib/src/domain/edition/z_derivation.dart:201`) — dont `ZDerivationValueFn` **asynchrone sérialisée par le socle** (`:117`) et `ZDerivationOverwrite.always/ifPristine` (`:26-35`) : **les deux limites que l'hôte se plaint de devoir réécrire (`:55-61`) sont exactement ce que le socle porte** | **95** |
| **M2** | `ExamsPage` : grille responsive, groupage « à venir / passés », tuiles, état vide, permission par année (333 l.) | `ZCrudScreen<T>` (`zcrud_screen/lib/src/presentation/z_crud_screen.dart:180`) + `ZCrudSource.items` (`z_crud_source.dart:109` — **voie de cohabitation : aucune migration du dépôt requise**) + `layout: ZListGridLayout` (`zcrud_core/lib/src/presentation/list/z_list_layout.dart:175`, `GridView.builder` responsive **rendu dans le cœur, sans Syncfusion**) + `tabs: [ZListTab]` avec `itemFilter` (`z_list_tab.dart:63`, `:288`) pour la partition à venir/passés + `acl:` (`z_crud_screen.dart:280`) | **~200** |
| **M3** | Tuile d'examen peinte à la main dans `exams_page.dart` (accent, date, pastille rappel, barré si passé) | `ZDefaultExamCard` (`zcrud_study/lib/src/presentation/z_default_exam_card.dart:44`) — accent, intitulé, date localisée par l'hôte, puce de rappel **en texte** (AD-13) | **~70** |
| **M4** | `ExamActionsDialogWidget` : `ListTile` Modifier / Supprimer + `Get.back()` + `buildConfirmDialog` (76 l.) — motif répété **10 fois** dans le dépôt (§6.13) | `ZItemActionsMenu` (`zcrud_study/lib/src/presentation/z_item_actions_menu.dart:283`) ou `ZRowAction` de `ZCrudScreen` (`z_crud_screen.dart:694`) + `showZConfirmDialog` (`zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129`) + `confirmDestructive` (`z_crud_screen.dart:930`). L'hôte **sait déjà le faire** : `folder_actions_menu_zcrud.dart:170` | **~60** (×10 sites hors périmètre) |
| **M5** | Examens du jour recalculés dans `daily_tasks_page.dart:371` | `examDailyTasks` (`zcrud_study/lib/src/presentation/z_exam_reminders.dart:75`) + `aggregateDailyStudyTasks` (`zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart:49`) + `zExamAsApproaching` | **~80** |
| **M6** | Rappels d'examen approchants (aucune surface dédiée ; logique éparpillée) | `ZExamRemindersSection` (`zcrud_study/lib/src/presentation/z_exam_reminders_section.dart:49`) + `approachingReminders` (`z_exam_reminders.dart:128`) | **~60** |
| **M7** | Modèle de rappel hebdomadaire d'IFFD porté par une `extra` chez l'hôte historiquement | `ZExam.reminderRecurrence` / `ZReminderRecurrence` (`zcrud_exam/lib/src/domain/z_reminder_recurrence.dart:42`) — porte **`weekdays` ISO-8601 ET `daysBefore`**, et `isApproaching` passe par `effectiveRecurrence`. **Déjà livré (v0.5.1), mais seul le chemin de données éteint le consomme** | (déjà écrit) |

### 2.2 Examens blancs (évaluation de l'apprenant)

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M8** | `WhiteExamPage` (779 l.) : `Timer.periodic` + `setState` par seconde (`:76-84`), `Map<String,ExamAnswer>` d'état, soumission partielle et totale, bilan (`:695-709`) | `ZWhiteExamSessionEngine` (`zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:274` — machine `setup → running → submitted`, **zéro écriture SRS garantie par le type**) + `ZWhiteExamSessionController` (`z_white_exam_session_controller.dart`) + `ZListSessionView` (`z_list_session_view.dart:128` — 704 l., **porte déjà le compte des non-répondues et sa boîte de confirmation**, `:429`, `:493-509`) + `ZTimerDisplay` (`z_timer_display.dart`) | **~700** |
| **M9** | `WhiteExamQuestionCard` (1 066 l.) : QCM / Vrai-Faux / texte + correction + retour d'apprentissage IA | `ZFlashcardType` (`zcrud_flashcard/lib/src/domain/z_flashcard_type.dart:16` — `multipleChoice`, `trueOrFalse`, `openQuestion`, **`exercise`** : les **4 familles d'IFFD ont chacune leur pendant**, `QuestionType.exercise("Cas pratique")` ↔ `ZFlashcardType.exercise`) + `ZFlashcardAnswerInput` (déjà connu de l'hôte) + `contentBuilder`/`correctionBuilder` de `ZListSessionView` | **~500** |
| **M10** | Correction IA des réponses ouvertes : appel, note, message par question (`white_exam_page.dart:602`, `white_exam_question_card.dart:315`, `:858`) | `ZFlashcardAnswerEvaluationPort` (`zcrud_flashcard/lib/src/domain/z_flashcard_answer_evaluation_port.dart:218`) → `ZFlashcardAnswerEvaluation{feedback, suggestedQuality, isCorrect}` (`:157-179`) ; branché par `ZListSessionView.evaluationPort` (`z_list_session_view.dart:201`). **Le port refuse par contrat d'être appelé sur QCM/Vrai-Faux** (évaluation locale exacte, `z_flashcard_local_evaluation.dart`) — ce que l'hôte fait aussi, mais sans le dire | **~180** |
| **M11** | Bilan de fin (réponses correctes, temps total, moyenne) peint à la main (`:695-709`) | `ZSessionSummaryView` (`zcrud_session/lib/src/presentation/z_session_summary_view.dart:206`) + `ZSessionQualityBreakdown` + `ZStudyProgressRings` + `zMasteredCount` | **~100** |
| **M12** | `TestExamFilterScreen` **et** `TestExamFilterZcrudScreen` (134 + 376 = 510 l.) pour 6 filtres | `ZTestFiltersDialog` (`zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:54`) + `ZFlashcardTestFilters` (`zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:107` : `questionCount`, `masteryLevels`, `sources`) + `zApplyTestFilters` (fonction pure) + `ZStudySessionConfig` (`zcrud_study_kernel/lib/src/domain/z_study_session_config.dart:52` : `types`, `tagIds`, `folderId`, `count`). **Couverture : 5 des 6 filtres** — voir §3 pour documents/notes | **~350** |
| **M13** | `FlashcardModel → ZFlashcard` : la conversion nécessaire à tout ce qui précède | `iffdCardToZ` — **déjà écrit par l'hôte** (`review_card_zcrud.dart`, 180 l.). Aucun coût d'amorçage | 0 (déjà là) |

### 2.3 Outils de valeur en douane

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M14** | 10 sous-classes de `ValuationToolModel` : `copyWith` + `fromMap` + `toString` identiques au nom près (`valuation_tool_model.dart:163, 205, 247, 289, 331, 373, 415, 457, 499, 541`) | `@ZcrudModel` / `@ZcrudField` (`zcrud_annotations`) + `zcrud_generator` (dev_dependency) → `ZcrudRegistry.register<T>(kind, fromMap:, toMap:, fieldSpecs:)` (`zcrud_core/lib/src/domain/registry/zcrud_registry.dart:80`, `:140`) sur **un seul type discriminé** ; provenance par `ZTypeRegistry`/`ZSourceRegistry` (AD-4) | **420** |
| **M15** | 10 dépôts `extends FirebaseCrudRepositoryImpl<X> implements ValuationToolModelRepository<X>` (`firebase_models_repositories_impls.dart:306-434`) | `FirebaseZRepositoryImpl` (`zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart`) — **un seul dépôt générique**, `ZResult<…>`/`Stream<List<T>>` nus, aucun type `cloud_firestore` en signature | **130** |
| **M16** | 10 appels `ValuationToolsGridView<X>(…)` à 16 paramètres identiques (`valuation_tool_model_actions_dialog_widget.dart:658, 674, 690, 706, 722, 738, 754, 770, 786, 802`) + la classe elle-même (~190 l.) | **Un** `ZCrudScreen<ValuationToolModel>` avec `tabs: [ZListTab(labelKey:…, itemFilter:…)] × 10` (`z_list_tab.dart:63`, `:288`) ou `ZSectionedStudyLayout` (`zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart`, **que l'hôte utilise déjà** via `ZStudyToolsSectionSpec`) ; rendu par `ZListGridLayout.forEntity<T>` (`z_list_layout.dart:186`) | **~280** |
| **M17** | Actions du menu d'outil : flashcards, carte mentale, résumé (`:92`, `:155`, `:164`) | `ZFlashcardGenerationController` / `ZFlashcardGenerationSheet` + `ZFlashcardGenerationPort` (`zcrud_study/lib/src/domain/z_flashcard_generation_port.dart`) ; `ZMindmapGenerationPort` (`z_mindmap_generation_port.dart`) ; `ZNoteSummaryPort` (`z_note_summary_port.dart`) — **ports neutres, prompts et endpoints restent à l'hôte (AD-12)** | **~120** |

### 2.4 Tâches / agenda

⚠️ Le socle **ne porte ni tâche ni agenda** (§3). Ce qui suit est ce qui est migrable **malgré** cette
absence, parce que ce sont des mécaniques génériques, pas du métier de tâche.

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M18** | `DailyTasksPage` + `WeekdaysWidget` (1 101 + 93 = 1 194 l.) : bandeau de 7 jours, navigation de semaine, sections, état vide | `ZDailyTasksView` (`zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:212`) — **corps composable sans `Scaffold`**, bandeau de semaine **en arithmétique UTC** (`zStudyWeekDays`, `:138-143`), liste virtualisée, `emptyState` injecté, horloge **injectée** (`now`, `:273`), cibles ≥ 48 dp et **défilement horizontal du bandeau quand la largeur ne permet pas 7 cibles** ; dispatch ouvert par `kind` avec `unknownTaskBuilder` (`:184`) — **c'est par là que les tâches propres d'IFFD entrent sans que le socle connaisse la tâche** | **~500** |
| **M19** | `EventRemindersWidget` : sous-liste réordonnable de rappels (327 l.) | `EditionFieldType.subItems` + `ZSubListConfig(reorderable: true, …)` (`zcrud_core/lib/src/domain/edition/z_sub_list_config.dart:154`, `:200`) + `ZSubListField` (`zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart:1`) — **place stable par item (`KeyedSubtree(ValueKey(itemId))`), aucun `setState` de formulaire**. L'hôte **maîtrise déjà** ce canal : `ai_router_zcrud_edition.dart:285`, `:366` | **327** |
| **M20** | Sous-tâches réordonnables de `TaskEditionScreen` : `FormBuilder` + `GlobalKey<FormBuilderState>` + `ReorderableListView(children:)` non virtualisé (`task_edition_screen.dart:26`, `:82`, `:254`) | Même canal que M19 + `ZFormOnly` / `ZFormOnlyController` (`zcrud_screen/lib/src/presentation/z_form_only.dart:52`) — le formulaire **au milieu d'une page composée par l'hôte**, validé par un bouton extérieur. 🔴 `flutter_form_builder` est **interdit par AD-2/AD-15** (`zcrud_core/pubspec.yaml`, commentaire des dépendances) : ce site est le contre-exemple exact | **~300** |
| **M21** | `TasksScreen` : `TabController` **recréé à chaque `build`** (`:173`), `ReorderableListView(children:)` (`:307`), `DynamicEditionScreen` legacy (`:431`) | `ZCrudScreen` + `tabs` + `tabsStore` (`z_crud_screen.dart:348`, `:396`) + `ZListBuilderLayout` (`z_list_layout.dart:116`, `ListView.builder`) ou `ZReorderableAdaptiveGrid` (`zcrud_responsive/lib/src/presentation/z_reorderable_adaptive_grid.dart:96`) ; `ZCrudSource.items` pour garder le dépôt de l'hôte | **~350** |
| **M22** | `ColorSelector` (81 l.), `IsAllDayWidget` (37 l.), `IsReadOnly` (92 l.) | `EditionFieldType.color` (`zcrud_core/lib/src/domain/edition/edition_field_type.dart:127`) servi par `z_color_field_widget.dart` ; `EditionFieldType.boolean` (`:55`) servi par `z_boolean_field_widget.dart` — **et l'hôte a déjà son booléen `FlutterSwitch` enregistré au registre sous `kIffdBooleanKind`** (`z_iffd_field_registry.dart:199`) | **210** |
| **M23** | 13 `ListView(children:)` non virtualisés (dont 10 dans `appointment_editor.dart`), 16 `StreamBuilder` sans branche d'erreur | `ZEmptyState` / `ZErrorState` (`zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:31`, `:127`) ; états vide/chargement/erreur **rendus par `DynamicList` lui-même** (`z_crud_screen.dart:28-30`) | **~120** |
| **M24** | `showPushedDialog` (100 sites dépôt), `buildConfirmDialog` (38 appels / 20 fichiers) | `presentEdition` (`zcrud_navigation/lib/src/presentation/present_edition.dart:155`) + `presentFormEdition` (`zcrud_screen/lib/src/presentation/present_form_edition.dart:234`, **déjà utilisé par 9 fichiers de l'hôte**) + `showZConfirmDialog` (`zcrud_ui_kit/.../z_confirm_dialog.dart:129`) | hors périmètre, ~700 dépôt |

### 2.5 Découverte / assistant IA

🔴 **Le contraste le plus fort du relevé** : l'hôte a écrit **1 493 lignes** de câblage
`ZChatArtifact*` pour le carnet (`lib/ai_assistant/zcrud/`), et **rien** de tout cela n'est
consommé par la Découverte, qui refait la même chose à la main dans un contrôleur de 2 412 lignes.

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M25** | `DiscovryPageController` : **57 `notifyListeners()` pour 84 méthodes**, 0 `ValueListenableBuilder` — toute frappe reconstruit page + composeur + fil | `ZChatController` (`zcrud_chat/lib/src/presentation/z_chat_controller.dart:1`) — **tranches `ValueListenable` indépendantes** (`composer`, `attachmentIds`, `canSend`, `messages`, `activeRequests`, `streamText` **par `requestId`**, `progress`, `lastFailure`, `liveAnnouncement`), `notifyListeners()` réservé au seul `attach`. C'est **littéralement l'objectif produit n° 1 du dépôt** | **~450** |
| **M26** | Retirer / remplacer / effacer une explication, régénérer, arrêter (`:661-737`, `:1720`, `:1220`) — verbes écrits un par un | `ZChatController.runAction(ZChatAction)` — **point d'entrée unique**, le verbe est une **donnée** (`ZChatAction`, famille scellée du kernel) : « il n'y a pas de `deleteMessage()`, pas de `regenerateAnswer()` » (`z_chat_controller.dart:16-18`) | **~200** |
| **M27** | 6 closures `_onAiCompletion(…)` recopiées (`:1689, 2067, 2137, 2260, 2310, 2363`) — §6.5 de la carte, **132 lignes mesurées** | `ZChatArtifactDeclaration` / `ZChatArtifactVerb` / `ZChatArtifactRegistry` (`zcrud_chat_kernel/lib/src/domain/notebook/z_chat_artifact_declaration.dart:290`) + `ZChatArtifactGenerationPort` + `ZChatArtifactBar` — **l'hôte a déjà 1 493 lignes de câblage pour le carnet** | **132** |
| **M28** | Options du composeur (`discovry_search_composer.dart:197`, controller `:858, :868, :873, :886, :896-921, :939, :950`) : modèle, effort, recherche web, scraping, plafond de résultats, réflexion + effort, niveau IFFD, corpus juridiques | `ZChatGenerationSettings` (`zcrud_chat_kernel/lib/src/domain/ai/z_chat_generation_settings.dart:86` : `responseLength`, `lengthBias`, `computeEffort`, `revealThinkingSteps`, **`webSearch`**, **`capabilities: Map<String,bool>` ouverte**) + `ZChatComputeEffort` (`z_chat_compute_effort.dart:37`, 1..5) + `ZChatCorpusScope`/`ZChatCorpusSelector` (`z_chat_corpus_scope.dart:140`, `:61` — **le catalogue de corpus est une donnée d'hôte, le socle ne nomme aucun code douanier**) + `ZChatToolCatalog` (`z_chat_tool_catalog.dart:177`) rendus par `ZChatSettingsSheet` (`zcrud_chat/lib/src/presentation/view/z_chat_settings_sheet.dart:322`, **2 046 l. déjà écrites**) et `ZChatComposer` (`z_chat_composer.dart:90`) | **~400** |
| **M29** | Suggestions de recherche avec surlignage de la saisie (`discovry_search_results.dart:12`, 84 l.) | `zChatHighlightRanges` + son unique widget de rendu (`zcrud_chat/lib/src/presentation/view/z_chat_highlight.dart`) + `ZChatSuggestion`/`ZChatSuggestionAction` (`zcrud_chat_kernel/lib/src/domain/z_chat_suggestion.dart:20`) | **~60** |
| **M30** | Réflexion affichée par étapes | `ZChatThinkingStep{agent, content, timestamp}` (`zcrud_chat_kernel/lib/src/domain/z_chat_thinking_step.dart:22`) + tranche `progress` du contrôleur | **~50** |
| **M31** | Rejouer dans un autre style (`:2331`) | `ZChatGenerationStyle{kind, params}` (`zcrud_chat_kernel/lib/src/domain/ai/z_chat_generation_style.dart:50`) | **~30** |
| **M32** | Chaîne de lecture vocale / podcast : cache disque local, repli, lecture de fond (`:309, :368, :426, :458, :491, :526`) | `ZChatSpeechPort` (`zcrud_chat_kernel/lib/src/domain/diffusion/z_chat_speech_port.dart:144`) + **`ZChatSpeechChain`** (`:174` — **la chaîne de repli est un objet, ordonnée, et les échecs de maillons sont conservés dans `attempts`**) + `ZChatDiffusionService` (`zcrud_chat/lib/src/presentation/diffusion/z_chat_diffusion_service.dart:51`) + `ZChatDiffusionBar` + `ZPodcastGenerationPort`/`ZStudyPodcast`/`ZPodcastFreshness`. **`just_audio` et le cache disque restent à l'hôte** — le socle ne tire aucune bibliothèque audio | **~250** |
| **M33** | Découpage SSE écrit à la main : `replaceFirst("data: ", "")`, sentinelle, transformateur d'octets (`iffd_ai_repository_impl.dart:54-161`) — *adjacent au périmètre, mais c'est le transport de la capacité n° 39* | `zChatSseLines` (`zcrud_chat_kernel/lib/src/data/sse/z_chat_sse_line.dart:1`) + `ZChatSseStreamPort` / `ZChatSseOpener` / `zChatSseJsonLineDecoder` (`z_chat_sse_stream_port.dart:129`) — **l'hôte ne fournit que l'ouvreur du POST et le décodeur de ligne** | **~80** |

### 2.6 Données et sérialisation (transverse au périmètre)

| # | Ce que l'hôte fait à la main | API socle exacte | Lignes hôte économisées |
|---|---|---|---:|
| **M34** | `toMap`/`fromMap`/`copyWith`/`==`/`hashCode`/`toString`/`props` écrits à la main dans les 7 modèles du domaine (mesure **heuristique** de la carte : ~874 l. sur 2 421, dont ~180 déjà comptées en M14) | `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` + `zcrud_generator` (**absent du `pubspec.yaml` d'IFFD**) → `fromMap`/`toMap`/`copyWith` + `ZFieldSpec[]` + enregistrement au registre. Les **107 `ZFieldSpec` écrits à la main** du dépôt (14 dans le périmètre) en sont **dérivables** | **~694** |
| **M35** | `ExamModel.date` est un `Timestamp?` (`exam_model.dart:18`) — `cloud_firestore` **fuit dans le domaine** ; l'hôte redoute de changer le format sur disque | `ZcrudField.persistAs: ZPersistAs.timestamp` (`zcrud_annotations/lib/src/domain/annotations/z_persist_as.dart:16`, `:22-26`) — **le champ reste un `Timestamp` natif côté Firestore, le domaine reste `DateTime`**, et le hint ne référence aucun type `cloud_firestore`. **Zéro occurrence de `ZPersistAs` chez IFFD** | débloque M34 |
| **M36** | `fromMap<T>`/`toMap<T>` : table de fabriques par `Type` (`data_functions.dart`, 515 l.) | `ZcrudRegistry` (`zcrud_core/lib/src/domain/registry/zcrud_registry.dart:80`) — **le registre instanciable**, injecté par `ZcrudScope`, alimenté par le codegen | **515** |
| **M37** | `CrudRepository<T>` (93) + `FirebaseCrudRepositoryImpl<T>` (499) + `DataState` (91) = 683 l. — et `DataState` **n'est inspecté nulle part** en présentation (49 appels CRUD en « tire et oublie ») | `ZRepository<T>` + `ZDataRequest` (curseur neutre) + `Either<ZFailure, T>` (AD-5) + `FirebaseZRepositoryImpl`/`FirestoreZRemoteStore`/`HiveZLocalStore`/`ZOfflineFirstRepository` (`zcrud_firestore/lib/src/data/`) + `ZPurgeable` pour la purge | **683** |
| **M38** | `zcrud_list` / `zcrud_export` écartés du `pubspec` sur une contrainte Syncfusion **qui n'existe plus** (`pubspec.yaml:292` dit « IFFD est en ^32 », `:141-149` déclare **^34.1.31**) | `zcrud_list` exige `syncfusion_flutter_datagrid: ^34.1.31` (`zcrud_list/pubspec.yaml:36`), `zcrud_export` exige `^34.1.31` (`:42-43`) — **satisfait**. Débloque `ZListDataGridLayout` et `ZExportPolicy` (`z_crud_screen.dart:1003`) | déblocage |
| **M39** | ⚠️ **`ZCrudScreen` ne dépend d'AUCUN Syncfusion** — `zcrud_screen/pubspec.yaml` ne déclare que `zcrud_core`, `zcrud_menu`, `zcrud_navigation`, `zcrud_ui_kit`. M2/M16/M21 sont donc atteignables **même si M38 était refusé**, via `ZListGridLayout`/`ZListBuilderLayout` qui rendent **dans le cœur** (`z_list_layout.dart:1-10`) | — | — |

**Total migrable aujourd'hui** : **~7 500 lignes d'hôte** (≈ **3 150 mesurées à l'octet** sur les blocs
dupliqués et les fichiers entiers, ≈ **4 350 estimées** sur les écrans — l'estimation retire ce qui
reste inévitablement à l'hôte : adaptateurs de modèle, libellés, prompts, thème).

---

## 3. MANQUE AU SOCLE

Preuve d'absence = grep négatif montré en §7.

| # | Ce qui manque | Forme du canal manquant | Paquet | Pourquoi l'hôte ne peut pas s'en passer |
|---|---|---|---|---|
| **G1** | **Entité tâche et liste de tâches** — `ZTask` / `ZTaskList` : titre, notes, échéance, rappel, récurrence, position, statut, priorité, parent, `members`, `readOnly` | **Entité** `@ZcrudModel` pur-Dart (comme `ZExam`) + son port `ZRepository` | **nouveau `zcrud_task`** (dépend de `zcrud_core` + `zcrud_annotations` seuls, AD-1) | `task.dart` = **584 l.** de modèle écrit à la main, `TasksScreen` + `TaskEditionScreen` = **1 273 l.**, **zéro test**. Sans entité socle, aucune des briques génériques (liste, formulaire, corbeille, ACL) ne s'accroche à quoi que ce soit de typé — `ZCrudSource.items` mitige mais ne dérive ni `ZFieldSpec` ni cellules |
| **G2** | **Vue agenda** — jour / semaine / semaine de travail / mois / planning, glisser-déposer d'un rendez-vous, redimensionnement, recherche | **Port de rendu** `ZAgendaRenderer` + descripteur neutre `ZAgendaRequest`/`ZAgendaSlot`, sur le **patron exact de `ZListRenderer`/`zcrud_list`** : le cœur ne nomme que l'abstraction, le backend Syncfusion Calendar vit dans un satellite | **nouveau `zcrud_agenda`** (backend `syncfusion_flutter_calendar`, déjà au `pubspec` d'IFFD `:142`) | `agenda_screen.dart` = **737 l.**, 9 vues, 14 appels CRUD d'affilée dont **aucun n'est attendu ni testé** (`:345-437`). C'est la seule capacité du périmètre qui n'a **aucun** point d'accroche socle |
| **G3** | **Entité événement / rendez-vous** — lieu, participants, pièces jointes, visioconférence, fuseau horaire, journée entière, lecture seule, rappels multiples, récurrence | **Entité** + **union de vue** (`ZAppointment`, projection tâche ∪ événement ∪ examen — c'est exactement `AppointmentKind` d'IFFD) | `zcrud_agenda` (G2) | `event.dart` (500 l.) + `appointment.dart` (403 l.) + `event_editon_screen.dart` (**1 192 l.**) + `appointment_editor.dart` (**7 858 l., dont ≥ 5 330 prouvées inatteignables**). Le fuseau horaire à lui seul est **absent du socle entier** (§7.5) |
| **G4** | **Règle de récurrence générale** — quotidien / jours ouvrés / hebdo / mensuel / annuel / personnalisé ; fin jamais / à une date / après N occurrences ; modifier une occurrence *ou* la série | **Value-object** `ZRecurrenceRule` (pur-Dart, RFC 5545 en surface neutre, `fromJsonSafe`) + **famille de champ** `EditionFieldType.recurrence` servie par un widget de satellite via `ZWidgetRegistry` (patron `pin`/`autocomplete`/`editableTable`) | value-object en **`zcrud_core`**, composeur en **`zcrud_field_extras`** | `recurrence_picker.dart` = **1 721 l.**, dont **741 (53 %) dupliquées** avec `appointment_editor.dart:6856-7788` — **le même sélecteur écrit deux fois**. `ZReminderRecurrence` (`zcrud_exam`) ne couvre que « jours de semaine » et « N jours avant » : il **ne sait pas dire** « tous les 3 mois, jusqu'au 12 avril » |
| **G5** | **Raccourcis d'échéance** — aujourd'hui / demain / semaine prochaine / mois prochain / personnalisée ; et raccourcis de rappel (dans la journée / demain / semaine prochaine) | **Jeton déclaratif** : `ZDateConfig.presets: List<ZDatePreset>` — pur-données (libellé par clé l10n + décalage relatif), résolu contre l'horloge injectée | **`zcrud_core`** (`z_field_config.dart`, à côté de `firstDateKey`/`minDateIso`/`maxDays`) | `task_due_date_picker.dart` (192 l.) + `task_reminder_picker.dart` (170 l.) = **362 l.** qui n'existent que pour ces raccourcis. `ZDateConfig` porte bornes et amplitude, **aucun préréglage** (§7.4) |
| **G6** | **Marquer une question pour y revenir** pendant un examen blanc | **Paramètres additifs** sur `ZListSessionView` : `flagged: Set<int>` + `onFlagToggled: ValueChanged<int>` — pur affichage, aucune règle (le moteur n'a pas à connaître le marquage) | **`zcrud_session`** | `white_exam_page.dart:46` (`Map<String,bool> _flaggedQuestions`) : sans ce canal, migrer l'examen blanc **perd une capacité** de l'hôte. C'est le seul manque qui bloque M8/M9 d'être une parité stricte |
| **G7** | **Filtres de test par documents et par notes** | Extension du **descripteur** : `ZFlashcardTestFilters.documentIds` / `noteIds`, ou passage par `ZFlashcardSource.kind` déjà ouvert (AD-4) — à trancher | **`zcrud_flashcard`** | `test_exam_filter_screen.dart:66-83` : 2 des 6 filtres d'IFFD (`documentsIds`, `notesIds`) n'ont pas de pendant. `ZStudySessionConfig` couvre `folderId`/`tagIds`/`types`/`count`, pas les documents |
| **G8** | **Variante de tâche générique du tableau de bord** — `ZDailyStudyTask` est une famille **ouverte** (`abstract interface class` + `String kind`, `z_daily_study_task.dart:41`) mais ne livre que `ZDueCardsTask` (`:50`) et `ZExamTask` (`:79`) | **Variante** `ZTodoTask` + sa carte par défaut `ZDefaultTaskCard` (patron `ZDefaultExamCard`) | **`zcrud_study_kernel`** + **`zcrud_study`** | Sans elle, M18 fait passer les tâches d'IFFD par `unknownTaskBuilder` : ça marche (c'est prévu), mais l'hôte repeint sa tuile. Coût réel faible — à arbitrer contre G1 |
| **G9** | **Partage d'une liste de tâches** (`members`, `readOnly`) | Généralisation de `ZStudyMembership`/`ZShareLink` (`zcrud_study/lib/src/domain/z_study_membership.dart`) hors du dossier d'étude | **`zcrud_study`** ou `zcrud_task` (G1) | `task.dart` porte `members` et `readOnly` ; `tasks_lists_repository.dart:16-30` porte la requête « `creatorId` OU `members` contient l'utilisateur », **recopiée à l'octet dans 3 fichiers** (§6.10). Le socle a la notion, mais **collée au dossier d'étude** |
| **G10** | **Rendu HTML riche d'un descriptif d'événement** — l'hôte utilise `flutter_html` (`event_editon_screen.dart`) | `EditionFieldType.html` / `inlineHtml` sont **déclarés** (`edition_field_type.dart:187-190`) — vérifier que `zcrud_html` sert bien le `kind` correspondant, sinon le champ dégrade en `ZUnsupportedFieldWidget` | **`zcrud_html`** | Non bloquant (repli propre, AD-10), mais à qualifier avant d'annoncer la parité |

**Ce qui NE manque pas, contrairement à ce qu'on pourrait croire** — vérifié :
`ZChatGenerationSettings.webSearch` couvre la recherche web ; `capabilities: Map<String,bool>`
couvre scraping et plafond de résultats sans nouveau champ ; `ZChatComputeEffort` couvre l'effort
de réflexion ; `ZChatCorpusScope` couvre la restriction aux corpus juridiques **sans que le socle
nomme un seul code douanier** ; `ZFlashcardType.exercise` couvre le « cas pratique » ;
`ZListSessionView` couvre déjà la soumission partielle avec confirmation.

---

## 4. RESTE À L'HÔTE

Le socle ne porte aucune règle métier (AD-16). Ces éléments doivent rester chez IFFD **même après
une migration complète**, et une CR qui les demanderait au socle serait à refuser.

| Élément | Site | Pourquoi cela reste à l'hôte |
|---|---|---|
| Les **dix corpus juridiques** de la valeur en douane (GATT, avis consultatifs, décisions, notes explicatives…) et leurs 992 lignes de constantes | `utils/constants/valuation_tools/` (10 fichiers) | Vocabulaire métier d'un domaine douanier. `ZChatSettingsSheet` le dit explicitement : « le catalogue de corpus est une **donnée d'hôte** » |
| `NiveauIFFD`, `SummaryType`, la chaîne `userPresentation` (« Je suis …, étudiant·e à l'IFFD inscrit au cycle … ») | `discovry_page_controller.dart:605-607`, `discovry_ai_page.dart:63` (+ 3 copies, §6.12 — **dont une fautive : « Je ${firstName} suis auditeur »**) | Identité et pédagogie propres à l'IFFD. ✅ Mais les **4 copies divergentes** sont un défaut d'hôte à corriger, indépendamment du socle |
| Les **prompts** (« Transforme ce contenu en une transcription audio du déroulement d'un cours destiné aux auditeurs de l'IFFD… ») | `discovry_page_controller.dart:464` | AD-12 : aucun prompt, endpoint ni clé ne peut entrer dans un paquet du socle |
| La permission `canCreateOrUpdate("ExamModel$accademicYear")` — droit **par année académique** | `exams_page.dart:74` | Règle d'autorisation métier. Elle s'**implémente** derrière `ZAcl` (`zcrud_core/lib/src/domain/ports/z_acl.dart`), elle n'y **entre** pas |
| L'année académique, la filière, le cycle, les promotions, `IffdPromotionControlledWidgetBuilder` (10 sites, §6.11) | `exams_page.dart:56` et 9 autres | Modèle organisationnel de l'IFFD. ⚠️ Le **factorisage** des 10 en-têtes identiques est un travail d'hôte, pas un manque socle |
| Le format d'affichage des dates et tous les libellés français | partout | Le socle ne formate **jamais** une date ni ne traduit : `ZDefaultExamCard` reçoit `dateLabel` déjà formaté, `ZDailyTasksView` reçoit ses builders de libellé |
| Le **lecteur audio** (`just_audio`, `just_audio_background`, `LockCachingAudioSource`, cache disque via `path_provider`) | `discovry_page_controller.dart:219, 339-416, 514` | `ZChatSpeechPort` est un **port** : « ni bibliothèque audio, ni bibliothèque de synthèse vocale, ni HTTP n'entrent ici — chaque maillon est une implémentation d'hôte » |
| L'ouverture du POST vers le backend IA (URL, authentification, charge utile) | `iffd_ai_repository_impl.dart:94-128` | `ZChatSseOpener` est explicitement la part d'hôte : « le socle ne tire aucune bibliothèque HTTP » |
| La planification **système** des notifications de rappel | `ExamModel.reminderDays`/`reminderTime` consommés côté app | `z_exam_reminders.dart:27-33` : « la programmation concrète (canal OS) reste côté application » |
| Le **code mort** : `WorkflowModuleLocalizations` (239 l.), `NoteBook`/`Note` (81 l.), `timeSliceEditionFields` (33 l.), `PopUpAppointmentEditor` (703 l.), `AppointmentEditor` (920 l.), `displayAppointmentDetails` (161 l.), `AppointmentEditorWeb` (3 546 l.) | §7 de la carte | **≥ 5 683 lignes à supprimer, pas à migrer.** Ce n'est ni un manque socle ni une migration : c'est du ménage, et il doit précéder toute migration de l'agenda sous peine de porter du mort |
| Les 3 actions rapides `enabled: false, onTap: () {}` du tableau de bord | `daily_tasks_page.dart:912-935` | 🔴 Contraire à AD-4 — `ZDailyTasksView` le dit : « aucune action désactivée n'est rendue : porter une commande morte serait porter un défaut ». À **retirer**, pas à porter |

---

## 5. Le fait le plus coûteux du relevé

**Trois branchements socle sont écrits, testés, et éteints par un drapeau** :

| Branchement | Lignes de prod | Lignes de test | État |
|---|---:|---:|---|
| `ZBackedExamRepository` (chemin de données examens) | 912 | 1 215 (`test/w5f/`) | `useZcrudExamsRepository = false` (`exam_providers.dart:19`) |
| `TestExamFilterZcrudScreen` | 376 | 752 (`test/w7f/`) | `'testExamFilter'` **absent** du `Set` de `main.dart:201-210` |
| `review_session_zcrud` (saisie de révision) | 131 | — | `kReviewSessionUseZcrudDefault = false` |

⇒ **1 419 lignes de portage et 1 967 lignes de tests** produites, et **aucune ne s'exécute en
production**. Pendant ce temps le legacy correspondant est maintenu en double (§6.15 : **1 808
lignes** pour trois formulaires de 4 à 6 champs, plus **1 723 lignes de tests de parité**).

Le coût de la migration n'est donc **pas** dans l'écriture du portage — il est dans **la décision de
basculer**. C'est la conclusion opérationnelle de cette confrontation.

---

## 6. Récapitulatif chiffré

| Catégorie | Capacités | Blocs répétés | Lignes hôte concernées |
|---|---:|---:|---:|
| **DÉJÀ MIGRÉ** | 8 | — | ~1 500 (dont 1 419 éteintes par drapeau) |
| **MIGRABLE AUJOURD'HUI** | 39 canaux (M1–M39) | 9 des 17 blocs de la carte | **~7 500 supprimables** |
| **MANQUE AU SOCLE** | 10 canaux (G1–G10) | 3 blocs (6.4, 6.6, 6.7) | ~12 000 (agenda + événement + récurrence) |
| **RESTE À L'HÔTE** | 11 familles | 2 blocs (6.11, 6.12) | ~1 500 + **5 683 de code mort à supprimer** |

**Répartition des 17 blocs répétés de la carte** :
absorbés par le socle aujourd'hui → **6.1, 6.2, 6.3, 6.5, 6.9, 6.10, 6.13, 6.14, 6.16, 6.17** (10) ;
bloqués par un manque socle → **6.4, 6.6, 6.7** (3, tous dans l'agenda) ;
travail d'hôte pur → **6.11, 6.12** (2) ;
décision de bascule → **6.15** (2 restants, 1 808 l.).

---

## 7. Preuves d'absence — les greps négatifs

Joués depuis `/home/zakarius/DEV/zcrud/packages/` (socle) ou `/home/zakarius/DEV/iffd` (hôte).

**7.1 — Le socle ne porte AUCUNE entité tâche ni événement**
```
$ grep -rnE "class ZTask|class ZTaskList|class ZTodo|class ZChecklist" */lib/ ; echo RC=$?
RC=1
$ grep -rnE "class ZEvent\b|class ZCalendarEvent" */lib/ ; echo RC=$?
RC=1
```

**7.2 — Le socle ne porte AUCUNE vue agenda / calendrier**
```
$ grep -rnE "class Z[A-Za-z]*Calendar|class Z[A-Za-z]*Agenda|class Z[A-Za-z]*Appointment" */lib/ ; echo RC=$?
RC=1
```

**7.3 — Le socle ne porte AUCUNE règle de récurrence générale**
```
$ grep -rniE "rrule|byweekday|freq(uency)?:.*(daily|weekly)|recurrenceRule" */lib/ ; echo RC=$?
RC=1
# Les seules occurrences de "recurrence" du socle sont dans zcrud_exam :
$ grep -rln "Recurrence" */lib/
zcrud_exam/lib/zcrud_exam.dart
zcrud_exam/lib/src/domain/z_reminder_recurrence.dart
zcrud_exam/lib/src/domain/z_exam.dart
```

**7.4 — `ZDateConfig` ne porte AUCUN préréglage d'échéance**
```
$ grep -rniE "preset|quickpick|quick_pick|raccourci" \
    zcrud_core/lib/src/domain/edition/z_field_config.dart \
    zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart ; echo RC=$?
RC=1
```

**7.5 — Le socle ne connaît NI fuseau horaire NI visioconférence**
```
$ grep -rniE "timezone|timeZone" */lib/ ; echo RC=$?
RC=1
$ grep -rniE "\bconference\b|\bhangout\b|meetingLink" */lib/ ; echo RC=$?
RC=1
# (une recherche sur "visio" seul rend des faux positifs : "reseedRevision" contient "visio")
```

**7.6 — `zcrud_session` / `zcrud_flashcard` ne savent PAS marquer une question**
```
$ grep -rni "flag\|marquer\|bookmark" zcrud_session/lib/ zcrud_flashcard/lib/
zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:353:  // …le flag d'accessibilité natif
zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:361:  // Premier canal non-coloré : le flag d'accessibilité natif.
# 2 occurrences, toutes deux des COMMENTAIRES sur l'a11y — aucun canal de marquage
```

**7.7 — L'hôte n'utilise NULLE PART l'écran CRUD assemblé**
```
$ grep -rn "ZCrudScreen" lib --include='*.dart' ; echo RC=$?
RC=1                       # (les 4 occurrences du dépôt sont dans test/, ce sont des tripwires)
$ grep -rn "\bDynamicList(" lib --include='*.dart' ; echo RC=$?
RC=1
$ grep -rn "ZListGridLayout\|ZListBuilderLayout\|ZListDataGridLayout" lib --include='*.dart' ; echo RC=$?
RC=1
```

**7.8 — L'hôte ignore TOUT le volet examen blanc du socle**
```
$ grep -rn "ZWhiteExamSession\|ZListSessionView\|ZTestFiltersDialog\|ZFlashcardTestFilters\|\
zApplyTestFilters\|ZTimerDisplay\|ZSessionSummaryView" lib --include='*.dart' ; echo RC=$?
RC=1
$ grep -rn "ZFlashcardAnswerEvaluationPort" lib --include='*.dart' ; echo RC=$?
RC=1
```

**7.9 — L'hôte ignore TOUT le volet examen/tâches de `zcrud_study`**
```
$ grep -rn "ZDailyTasksView\|ZExamRemindersSection\|ZDefaultExamCard\|approachingReminders\|examDailyTasks" \
    lib --include='*.dart' ; echo RC=$?
RC=1
$ grep -rn "ZExamEditor" lib --include='*.dart'
lib/src/presentation/features/folders/zcrud/content_hub_zcrud.dart:13:// … `ZExamEditor`, …
# une seule occurrence, dans un COMMENTAIRE
```

**7.10 — `ZExam` n'atteint jamais la présentation**
```
$ grep -rn "\bZExam\b" lib --include='*.dart' | grep -v "z_backed_exam_repository.dart"
lib/src/features/exams/providers/exam_providers.dart:15:/// réelle `ZExam`). Une régression se corrige…
lib/src/features/exams/providers/exam_providers.g.dart:15:  (idem, généré)
lib/src/features/exams/providers/exam_providers.g.dart:25:  (idem, généré)
lib/src/features/exams/providers/exam_providers.g.dart:35:  (idem, généré)
# 4 occurrences hors de l'adaptateur, TOUTES des COMMENTAIRES (dont 3 recopiées
# par le générateur Riverpod). Aucun site de code, aucune occurrence en `presentation/`.
$ grep -rn "\bZExam\b" lib/src/presentation --include='*.dart' ; echo RC=$?
RC=1
```

**7.11 — Aucun codegen zcrud chez l'hôte**
```
$ grep -rnE "^[[:space:]]*@Zcrud(Model|Field|Id)\b" lib --include='*.dart' ; echo RC=$?
RC=1
$ grep -n "zcrud_generator" pubspec.yaml ; echo RC=$?
RC=1
$ grep -rn "ZPersistAs" lib --include='*.dart' ; echo RC=$?
RC=1
```

**7.12 — `lib/workflow/` ignore intégralement zcrud**
```
$ grep -rn "zcrud" lib/workflow --include='*.dart' ; echo RC=$?
RC=1                       # 36 fichiers, 16 821 lignes
$ grep -rn "ZSubListConfig\|subItems" lib/workflow --include='*.dart' ; echo RC=$?
RC=1
```

**7.13 — Les paquets de liste et d'export ne sont plus bloqués**
```
$ grep -n "syncfusion_flutter_datagrid" /home/zakarius/DEV/iffd/pubspec.yaml
144:  syncfusion_flutter_datagrid: ^34.1.31
$ grep -n "syncfusion_flutter_datagrid" packages/zcrud_list/pubspec.yaml
36:  syncfusion_flutter_datagrid: ^34.1.31
# La contrainte de zcrud_list est SATISFAITE ; le commentaire pubspec.yaml:292
# (« IFFD est en ^32 ») est PÉRIMÉ.
$ grep -rn "zcrud_list\|zcrud_export" /home/zakarius/DEV/iffd/lib --include='*.dart' ; echo RC=$?
RC=1
```

**7.14 — `ZCrudScreen` n'a AUCUNE dépendance Syncfusion**
```
$ grep -A6 "^dependencies:" packages/zcrud_screen/pubspec.yaml
dependencies:
  zcrud_core: ^3.21.0
  zcrud_menu: ^3.21.0
  zcrud_navigation: ^3.21.0
  zcrud_ui_kit: ^3.21.0
  flutter:
    sdk: flutter
$ grep -rn "syncfusion" packages/zcrud_screen/lib packages/zcrud_screen/pubspec.yaml ; echo RC=$?
RC=1
# (les seules occurrences du paquet sont dans test/z_crud_screen_export_test.dart — une
#  GARDE qui INTERDIT syncfusion — et une phrase du README.)
```

---

*Confrontation produite en lecture seule sur `/home/zakarius/DEV/iffd`. Aucun fichier de l'hôte n'a
été créé, modifié ni supprimé. Aucun test n'a été lancé. Aucune clé d'API ni aucun secret n'est
cité — l'hôte en porte dans son `.env` de racine et dans sa configuration de plateforme.*
