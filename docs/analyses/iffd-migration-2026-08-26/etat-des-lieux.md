# État des lieux — migration d'IFFD vers zcrud

**Date** : 2026-08-26
**Hôte mesuré** : `/home/zakarius/DEV/iffd` @ `65d1af9` (branche `feat/migration-zcrud`), arbre de
travail **propre** (`git status --porcelain` → 0 ligne). Lecture seule stricte, aucun test lancé.
**Socle mesuré** : `/home/zakarius/DEV/zcrud` @ `cc276c154` = **v3.21.0**, **41 paquets**.
**Matière** : 11 cartographies, 11 confrontations, 5 catalogues de capacités, **33 réfutations
adversariales** (22 756 lignes au total), plus mes propres remesures sur disque.

> Ce document ne reprend aucun chiffre sur la foi d'un rapport. Tout ce qui est classé
> « migrable » a été soit passé à la réfutation, soit remesuré ici même. Les chiffres que je n'ai
> pas pu établir sont dits non établis, jamais devinés.

---

## 1. Le verdict en une page

### 1.1 Les volumes

| Mesure | Valeur | Comment |
|---|---:|---|
| `iffd/lib` — fichiers Dart | **549** | `find lib -name '*.dart' \| wc -l` |
| `iffd/lib` — lignes | **179 222** | `find … -exec cat {} + \| wc -l` |
| …hors code généré (`*.g.dart`, `*.gr.dart`, `*.freezed.dart`) | 531 f. / **171 835 l** | idem, avec `! -name` |
| Fichiers portant `import 'package:zcrud_` | **110** (196 imports) | `grep -rln` |
| Paquets zcrud en `dependencies:` (bloc `:10-532`) | **23** | `awk` sur la section |
| Paquets zcrud en `dependency_overrides:` **seulement** | **2** — `zcrud_annotations` (:577), `zcrud_responsive` (:682) | `comm -13` des deux listes |
| Paquets du socle **non déclarés du tout** | **16** | `zcrud_chat_firestore`, `zcrud_chat_study`, `zcrud_dnd`, `zcrud_export`, `zcrud_export_pdf`, `zcrud_export_ui`, `zcrud_field_extras`, `zcrud_generator`, `zcrud_geo`, `zcrud_geo_location`, `zcrud_get`, `zcrud_html`, `zcrud_list`, `zcrud_media`, `zcrud_provider`, `zcrud_reorder` |
| Entrées épinglées `ref: v3.21.0` | **48** | `grep -c` |

### 1.2 Les quatre parts

| Part | Volume | Nature |
|---|---:|---|
| **Déjà migré — écrit, compilé, majoritairement ÉTEINT** | **19 170 l** (62 fichiers `*zcrud*.dart`) ; 27 481 l si l'on compte les 98 fichiers sous un chemin `zcrud/` | 53 `ZQaFlag(` dans `z_qa_flags.dart`, dont **52 `const … = false`** et **1 à `true`** (`ai_router_zcrud_edition.dart:104`). 8 identifiants seulement sont forcés à l'exécution (`main.dart:201-210`). |
| **Migrable aujourd'hui, sans une ligne de socle** | **≈ 2 100 l** établies + **≈ 700 à 1 300 l** annoncées mais non passées à la réfutation | §2 |
| **Suppression de code mort** (ni socle, ni migration) | **≈ 12 250 l** | §2.0 |
| **Nécessite du travail au socle** | **≈ 6 500 l** immobilisées, 24 manques dont **9 bloquent une capacité d'étude ou de révision** | §3 |
| **Reste définitivement à l'hôte** | ≈ 12 000 l de règle métier + l'échafaudage de bascule (~1 300 l) | §5 |

### 1.3 Ce qui coûte le plus cher à l'hôte aujourd'hui

Par ordre décroissant de coût réel, pas de volume brut :

1. **La migration est écrite et non allumée.** 19 170 lignes de jumeaux compilent dans le binaire,
   52 drapeaux sur 53 sont à `false`. Le legacy que l'allumage retirerait pèse **≈ 3 640 l** pour
   le seul domaine « dossiers d'étude » (687 + 1 395 + 278 + 189 + 550 + 538). Ce n'est pas un
   chantier : c'est une décision de QA. C'est, et de loin, le meilleur rapport valeur/coût du
   dossier.
2. **12 250 lignes de code mort** que personne n'a supprimées, et sur lesquelles trois analyses
   ont failli engager un portage (§6).
3. **Deux défauts LATENTS déjà sur disque**, qui mordront à la première bascule de drapeau :
   `ZSrsConfig` sans `minQuality: 1` (six paliers dont un « Ok » à note 0) et `ZHintPenaltyPolicy`
   par défaut (chaque indice abaisse la note d'un cran, alors que le jumeau porté affirme
   l'inverse). Correctif : **un paramètre chacun**.
4. **Un bug livré** : la flamme d'assiduité retombe à 1 le lendemain de chaque changement d'heure
   (`folder_flashcards_repetitions_page.dart:148`, `today.difference(lastStudy).inDays == 1`).
5. **Une cascade de suppression incomplète** : supprimer un dossier **orpheline** ses documents,
   ses notes et ses cartes mentales. Grep négatif montré :
   `grep -rn "deleteFolderDocuments\|deleteFolderNotes\|deleteFolderMindmaps\|deleteFolderContents" lib` → **RC=1**.
   Et les 3 cascades existantes partent **sans `await`** avant `delete(item.id)`
   (`folders_repository.dart:137-142`).
6. **128 `StreamBuilder` sur 133 ne rendent aucune erreur** (`grep -rn 'snapshot.hasError' lib | wc -l` → 5).
7. **13 `PopScope(` sur 16 portent `canPop: true`** : les gardes anti-perte de saisie des éditeurs
   de rendez-vous et d'événement sont **inertes**.

### 1.4 Le fait qui commande la lecture de §2

**L'écart n'est pas un écart de version, c'est un écart de connaissance.** Les canaux cités en §2
sont dans l'arbre de l'hôte, résolus au tag v3.21.0, compilés — et à **zéro occurrence** dans
`iffd/lib`. Preuve directe : sur les sept CR ouvertes par le pilote le 2026-08-25
(CR-IFFD-114 → 120), **quatre ont été retirées avant émission parce que le canal existait déjà**
(`iffd/docs/zcrud-change-requests.md:7787, :7825, :7859, :7879`).

---

## 2. MIGRABLE AUJOURD'HUI, SANS AUCUN TRAVAIL AU SOCLE

> Règle appliquée : **une affirmation démentie par la réfutation n'apparaît pas ici.** Les entrées
> ci-dessous ont soit survécu à une réfutation adversariale, soit été remesurées par moi sur
> disque ce jour. Chaque entrée qui n'a subi **ni** l'une **ni** l'autre est marquée
> « NON ÉPROUVÉE » et son chiffre est à remesurer avant d'être annoncé — c'est la conduite que
> commande un taux de réfutation de 32 sur 33.

### 2.0 Lot zéro — la suppression, qui n'est pas une migration (≈ 12 250 l)

Aucune API en jeu, aucun paquet à déclarer. À faire **avant** tout portage, sous peine de porter
du code que personne n'ouvre.

| Cible | Lignes | Preuve d'inatteignabilité |
|---|---:|---|
| `lib/workflow/screens/appointment_editor.dart` | **7 858** (garder ~40 l de constantes) | `grep -rn "displayAppointmentDetails" . --include='*.dart'` → **1 ligne, sa propre définition** ; `grep -rn "AppointmentEditorWeb(\|PopUpAppointmentEditor(\|AppointmentEditor(" lib` hors du fichier → **2 hits, tous deux `_getAppointmentEditor`**, un autre symbole. Aucun `@RoutePage`. |
| `lib/data_crud/dynamic_list_screen.dart` + `agents_screens.dart:113-649` + `categorysation_screens.dart` + `models.dart:275-303` | **≈ 2 362** | `DynamicListScreen` a **1 appelant** (`agents_screens.dart:176`) ; `grep -rn "\bAgentsScreen\b" lib \| grep -v AgentsScreens` → 7 lignes = 3 commentaires + 1 littéral (`z_qa_flags.dart:766`) + 3 lignes de sa propre déclaration. **0 site de construction.** Conserver `agents_screens.dart:1-112` (`AuditeursFilter`, `ordonnerLesAuditeurs`). |
| SmartNotes : `SmartnoteActionsDialogWidget` (417) + 3 dialogues d'instructions (259) + `NoteSelectorDropdown` (212) | **≈ 888** | drapeau `smartNoteAiInstructions` classé **INOBSERVABLE** par le plan QA de l'hôte (`docs/qa-plan-comparaison-legacy-zcrud.md:340-344`) |
| `white_exam_page.dart` (conserver `ExamAnswer` :754-779, 26 l importées par 2 fichiers vivants) | **≈ 753** | `@RoutePage` posé (:19), la route est **générée** (`app_router.gr.dart:2480`) mais `grep -rn "WhiteExamPageRoute" lib \| grep -v app_router.gr.dart` → **RC=1** et `grep -n WhiteExamPageRoute lib/src/config/router/app_router.dart` → **RC=1** : la route n'est **pas dans l'arbre du routeur** et rien n'y navigue. |
| mindmap : `MindmapActionsDialogWidget` (216) + `showMindmapActionsDialog` (35) + `hooks_web/mobile` (63) | **≈ 314** | `grep -rn "showMindmapActionsDialog" lib` → **1 ligne, sa définition** |
| `firebase_owner_scoped_repetition_store.dart` | **154** | 3 occurrences, toutes internes |
| 4 modules de 0 octet | 0 | `gamification_module.dart`, `mindmap_module.dart`, `documents_module.dart`, `smartnotes_module.dart` |

**Attention** : `white_exam_question_card.dart` (1 139 l) **N'EST PAS mort** — il est monté par
`learning_mode_question_card.dart:234` en plus de `white_exam_page.dart:283`. Trois analyses le
comptaient dans les lignes à retirer.

### 2.1 Le classement, par lignes d'hôte économisées

| Rang | Canal du socle (`fichier:ligne`) | Cible hôte | Lignes | Statut de preuve |
|---:|---|---|---:|---|
| 1 | **`ZMenuEntryTile`** `zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:31` + `ZMenuEntryTile.gridDelegate` `:81` + `ZItemAction.toMenuEntry()` `zcrud_study/…/z_item_actions_menu.dart:246` + `zVisibleMenuEntries` `zcrud_menu/…/z_menu_entry.dart:194` | Les **8 dialogues d'actions**, 53 `ListTile(` bruts (empan mesuré **1 586 l** sur 3 554 l de fichiers) | **≈ 420** (estimé, 8 l./tuile) | **Le patron TOURNE DÉJÀ chez l'hôte** : `folder_actions_menu_zcrud.dart:209-219` monte `ZMenuEntryTile(entry: a.toMenuEntry(), direction: Axis.vertical)` dans un `GridView` autonome. Corps vérifié : `onSelected: null` ⇒ aucun détecteur posé (`:38-40`), donc utilisable hors menu. **⚠️ Ne pas confondre avec `ZItemActionsMenu`, démenti trois fois** (§6) : ici la tuile est posée par l'hôte dans sa propre feuille, aucun déclencheur n'est fabriqué. **Perte à assumer** : les icônes colorées en dur (`Colors.red`, `0xffc5c5c5`) — `ZMenuEntry` n'a que `isDestructive`, et il est inerte dans les 9 fichiers de rendu de `zcrud_menu`. |
| 2 | **`ZIffdTextStreamPort`** `zcrud_chat_syncfusion/lib/src/data/z_iffd_stream_port.dart:40` + `ZIffdLexer` `:98` + `zIffdChannelOfTag` `z_iffd_wire.dart:53` | La table fermée de 4 balises recopiée : `discovry_ai_page.dart:100-135` (36 l) + `iffd_ai_repository_impl.dart:130-300` (≈ 170 l, partagé) | **≈ 200** | **Le port est DÉJÀ adopté par l'hôte ailleurs** (`notebook_stream_opener_iffd.dart`, `notebook_ports_iffd.dart`, `assistant_chat_zcrud_mount.dart`). Corrige un défaut vivant : la 5ᵉ balise s'affiche dans la réponse. Classement **total** par forme (`RegExp` de forme, pas de table) : toute balise inconnue tombe en `thinking`. |
| 3 | **`ZSessionSummaryView`** `zcrud_session/…/z_session_summary_view.dart:206` + `ZSummaryCelebration` `:62` | `flashcards_learning_celebration_page.dart` (**403 l** mesurées) | **≈ 200** | **NON ÉPROUVÉE.** `confetti: ^0.8.0` déjà déclaré des deux côtés — aucune arête neuve. **Perte connue** : `ZCelebrationSpec` a 11 champs et **aucun `colors`** ; les 6 couleurs de confetti d'IFFD (`:127-134`) ne sont pas injectables. Le fond dégradé reste à l'hôte. |
| 4 | **`ZFlashcardHintPort`** `zcrud_flashcard/…/z_flashcard_hint_port.dart:120` + **`ZHintPenaltyPolicy`** `z_hint_penalty.dart:42` / `zApplyHintCeiling` `:110` | `interactive_flashcard_repetition_card.dart:95, :96, :331-390, :1021-1102` | **≈ 130** | Point d'injection : `hintPort` de `ZFlashcardAnswerInput` (`:111`), consommé `:683`. **Défaut mis au jour** : le jumeau porté `review_session_zcrud.dart:118-127` **ne passe pas `hintPort`** — la branche portée **perd** aujourd'hui la fonction d'indice. |
| 5 | **`showZConfirmDialog`** `zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129` | Les **25 `AlertDialog(` bruts** (18 fichiers, remesurés ce jour) | **≈ 150** | Corps vérifié : 5 paramètres seulement (`title`, `message`, `confirmLabel`, `cancelLabel`, `tone`), `return result ?? false` — jamais `null`, jamais de throw ; libellés par `MaterialLocalizations`. **⚠️ NE COUVRE PAS les 36 `buildConfirmDialog(`** (remesurés) : la confirmation de marque d'IFFD (pastille 64×64 à dégradé, `Icons.help_outline_rounded`) n'a **aucun slot** — voir §3, manque `UI-1`. |
| 6 | **`ZFolderContentsOrder`** `zcrud_study_kernel/…/z_folder_contents_order.dart:115` + **`zSectionKey`** `z_section_key.dart:52` + **`applyOrder<T>`** `apply_order.dart:41` | `folder_study_tools_page.dart:227-310` (84 l) + `:311-357` (47 l) | **131** | **Corrige un bug vérifié** : `getSortedIterms` porte un **shadowing** — `List<String> contentOrder = contentsMaps[T] ?? [];` **redéclaré** à `:255` dans la portée du `if` ; l'externe reste vide, donc le mode `custom` **ne trie jamais** depuis l'ordre persisté. Plus un `catch (_) {}` muet à `:298`. `applyOrder` est stable **par construction** (clé secondaire = index d'entrée) et **ne lève jamais**. |
| 7 | **`zEvaluateLocally`** `zcrud_flashcard/…/z_flashcard_local_evaluation.dart:96` + `zIsSingleChoiceQcm` `:56` + `zCorrectChoiceIndexes` `:66` | `interactive_flashcard_repetition_card.dart:206-305` (`:301`, `:305` = `isCorrect ? 5 : 1`, vérifiés) + 3 recopies dans `white_exam_question_card.dart` | **≈ 100** | Fonction **pure**, testable isolément. Égalité **ensembliste stricte** (`_setEquals`), jamais une inclusion. Apport réel au-delà des lignes : la garde « QCM sans choix correct ⇒ `null` », absente du legacy qui rend **5** à qui ne coche rien. **⚠️ Exige `ZSrsConfig(minQuality: 1)`** (entrée 16), sinon l'échec est noté **0** — valeur hors de l'échelle `FlashcardRepetitionQuality` (qui commence à `fail(1)`), et `copyWith` remplace alors **silencieusement** la note par la précédente. |
| 8 | **`ZFeedbackTier`/`zFeedbackTierFor`** `zcrud_session/…/z_session_feedback.dart:32, :104` + **`ZDefaultFeedbackBank`** `z_session_feedback_bank.dart:51` (texte FR embarqué) | `learning_mode_question_card.dart:99-190` | **≈ 80** | Seuils **identiques des deux côtés**, vérifiés : socle `exceptionalUnder = 10 s`, `exceptionalMaxHints = 0` (`:57-58`) ⇔ hôte `if (timeTaken < 10 && hintsCount == 0)` (`:106`). Le socle refuse en plus le palier sur mesure aberrante. **Limite** : `maybeResolve(key, languageCode)` ne reçoit ni la soumission ni le nombre d'indices ⇒ le sous-découpage 0/1/2+ d'IFFD est perdu (§3, `SES-4`). |
| 9 | **`ZEmptyState`** `zcrud_ui_kit/…/z_state_widgets.dart:31` | `EmptyTasksWidget`, `daily_tasks_page.dart:560-636` (`:560` vérifié) | **77** | Message **toujours présent** (l'icône n'est jamais le seul canal), couleurs du `ColorScheme`, `Semantics` composé, cible ≥ 48 dp. **⚠️ Le rendu change** : `Container(borderRadius: 24, surface α 0.5)` → état neutre. |
| 10 | **`zApplyTestFilters`** `zcrud_flashcard/…/z_flashcard_filters.dart:206` + `ZFlashcardTestFilters` `:107` + `zMasteryLevelOf` `:75` + `zDrawQuestions` `:461` | `lib/src/utils/flashcard_filters.dart` (**90 l** remesurées) | **≈ 60** | Seuils **identiques borne pour borne** : socle `bad=[0..2]`, `good={3}`, `mastered=[4,5]` ⇔ hôte `mauvais`/`bon`/`maitrise`, règle « jamais pratiquée = mauvais » comprise. **Gain non cosmétique** : l'hôte fait un `firstWhere` **par carte** (`:27`) — quadratique ; le socle prend `srsById` indexée (O(1)) et un `Random` **injecté** (donc testable). **⚠️ Ne couvre que 3 axes sur 5** : `documentsIds`/`notesIds` manquent (§3, `FLA-1`). |
| 11 | **`zAdvanceStreak`** `zcrud_study_kernel/…/z_advance_streak.dart:130` + `ZStudyStreak` `z_study_streak.dart:148` + `zCivilDayNumber` | `_checkAndUpdateStreak`, `folder_flashcards_repetitions_page.dart:113-171` | **59** | **Corrige un bug LIVRÉ, vérifié** : `today.difference(lastStudy).inDays == 1` (`:148`). Un jour de passage à l'heure d'été dure 23 h, `inDays` rend **0**, la branche d'incrément n'est jamais prise, on tombe dans `newStreak = 1` : **la flamme est remise à 1 le lendemain du changement d'heure, chaque année, pour tous les utilisateurs**. `zCivilDayNumber` est de l'arithmétique entière (Hinnant), immunisée par construction. Gains annexes : `best` gratuit, idempotence explicite, horloge reculée sans `current` négatif. **⚠️ Arbitrage propriétaire** : `_gradedModes` (`:77-80`) n'admet que `spaced` et `learn` — `test`, `whiteExam` et `cramming` **cessent** de faire avancer la flamme (l'hôte n'excluait que `listOnly`). |
| 12 | **`zCategorize`** `zcrud_flashcard/…/z_session_categorization.dart:91` + `zIndexSrsById` `:56` | `flashcard_widgets.dart:837-878` (`:837` vérifié) | **≈ 42** | Tri **décoré par index** (Dart ne garantit pas la stabilité de `List.sort` ; l'hôte ne stabilise pas). |
| 13 | **`ZFlashcardEditionFields.type()/.choices()/.trueFalse()`** `zcrud_flashcard/…/z_flashcard_editors.dart:89, :100, :109` | `flashcard_edition_zcrud.dart:187-193, :195-…` | **≈ 40** | **`registerZFlashcardEditors` EST DÉJÀ APPELÉ** (`z_iffd_field_registry.dart:171`) — mais aucun champ ne pose `ZFlashcardFieldConfig.editorKind`, donc **les trois widgets enregistrés sont du code mort**, et surtout la règle `ZFlashcardEditionValidator.validateChoices` (« ≥ 2 choix, ≥ 1 correct ») **n'est appliquée nulle part**. Le registre de l'hôte le consigne lui-même (`:157-165`). **⚠️ Arbitrage propriétaire** : des QCM à une seule proposition, aujourd'hui acceptés, seront refusés. |
| 14 | **`zFoldDiacritics`** `zcrud_core/lib/src/domain/data/z_search_text.dart:115` + `ZSearchFolding.diacriticsAndSpaces` `:49` | `normalizedText`/`unaccentedText` `data_functions.dart:55, :118` (table de 61 caractères, 61 `replaceAll`), **22 sites** | **≈ 40** | Couvre **strictement plus** : ligatures multi-caractères (`œ→oe`, `æ→ae`, `ß→ss`, `ĳ→ij`) qu'une table de longueur fixe ne peut pas exprimer ; et le blanc au sens Unicode, pas le seul U+0020. **⚠️ Écart honnête** : `zFoldDiacritics` abaisse **toujours** la casse ; les 6 sites du périmètre l'abaissent juste après, donc l'équivalence tient pour eux. |
| 15 | **`ZDiscardChangesGuard`** `zcrud_ui_kit/…/z_discard_changes_guard.dart:50` (`canPop: !dirty` `:104`) | **13 `canPop: true` sur 16 `PopScope(`** (remesurés) | **≈ 36** | Le corps ne reconstruit que le `PopScope` — le `child` passe **par paramètre**, non reconstruit au flip *dirty*. **Le vrai gain est une capacité absente** : aucune garde anti-perte de saisie n'existe aujourd'hui dans les éditeurs de rendez-vous et d'événement. |
| 16 | **`ZCascadeRegistry`** `zcrud_study_kernel/…/z_cascade_registry.dart:88` + **`ZFirestoreCascadeBatcher.deleteCascade`** `zcrud_firestore/…/z_firestore_cascade_batcher.dart:107, :136` | `folders_repository.dart:135-143` + `:346-363` | **≈ 30** | **La valeur est la correction, pas le volume.** Vérifié : les 3 cascades partent **sans `await`** et `delete(item.id)` les précède ; et **aucune cascade n'existe** pour documents/notes/cartes mentales (RC=1). Le registre est déclaratif : l'oubli devient **visible par construction**, et `deleteCascade` rend un `ZCascadeReport` au lieu d'un `Future<void>` non attendu. Garde anti-« deux propriétaires » ; flush borné à 450 écritures. |
| 17 | **`ZMindmapViewController`** + `ZMindmapViewLabels` ; **`editFieldBuilder`** ; libellés d'état vide de l'éditeur outline ; **`zMindmapNodeCount`** | 3 FAB de zoom non bornés (27) ; formulaire de nœud inline (55) ; état vide (59) ; compteur d'artefact (10, **plus un bug**) | **≈ 151** | Petits lots, non passés à la réfutation (**NON ÉPROUVÉS** individuellement) mais indépendants et à faible surface. |
| 18 | **`ZChatComputeEffort`** `zcrud_chat_kernel/…/ai/z_chat_compute_effort.dart:37` ; **`zChatConversationActions`** `zcrud_chat/…/view/z_chat_conversation_actions.dart:109` ; **`ZChatExportService`** `…/export/z_chat_export_service.dart:129` | `WorkflowEffort` (`ai_models.dart:119-137`) ; `conversation_actions_menu.dart` (157 l) ; 3 copies d'export de fil (`chatbot_conversation_screen.dart:107, :114, :127`) | **≈ 220** | **NON ÉPROUVÉES.** ⚠️ Piège nommé par le socle lui-même : `thinkingEffort == 0` (« réflexion désactivée ») n'est **pas** un niveau — le socle borne à 1 ; le 0 se porte en **capacité**, jamais en effort. Une transposition naïve activerait la réflexion en silence. |
| 19 | **`ZAdaptiveGrid`** / **`ZAdaptiveGrid.builder`** `zcrud_responsive/…/z_adaptive_grid.dart:63, :89` (les deux `const` et publics) | `exams_page.dart:123-180` + `folder_progress_page.dart:87-140` (bloc recopié, `Get.width` − `drawerWidth: 300`) + 4 `GridView.count` du domaine matières | **≈ 150** | **PRÉCONDITION NON SIGNALÉE PAR LES ANALYSES, mesurée ici** : `zcrud_responsive` n'est **PAS** en `dependencies` — il n'apparaît qu'en `dependency_overrides:682`, et **aucun barrel ne le ré-exporte** (`grep -rn "export 'package:zcrud_responsive" packages/*/lib/*.dart` → aucune ligne). Il faut **une entrée de `pubspec.yaml`**. Corrige `Get.width` (largeur de **fenêtre**, d'où le correctif `−300` écrit à la main) au profit d'un `LayoutBuilder`. Les 8 occurrences de `ZAdaptiveGrid` dans `iffd/lib` sont **toutes des commentaires**, dont un faux : « `ZAdaptiveGrid.builder` (virtualisé) n'est pas exposé » (`study_tools_zcrud_adapter.dart:69`). |
| 20 | **`ZcrudScope.derive`** `zcrud_core/…/zcrud_scope.dart:478` | `z_iffd_field_registry.dart:345` — **1 ligne à changer** | **0** | Mesuré : **28 `ZcrudScope(`** contre **0 `.derive`**. Chaque scope local **masque** les 12 seams du scope racine (registre, thème, résolveurs de teinte/icône/couleur, présentateur de sélection, formateurs). La sentinelle `_zScopeUndefined` (`:46`) distingue « omis » (hérite) de `null` explicite (repli). L'hôte a **déjà payé cette classe de défaut** (`folder_zcrud_edition.dart:520-525`, régression `ucFirst` du 2026-08-24). |
| 21 | **`ZSrsConfig(minQuality: 1)`** `zcrud_flashcard/…/z_srs_config.dart:27` | `kIffdSrsConfig`, `flashcard_repetition_info.dart:57` (remesuré : **seul `overdueBonusFactor: 0.5`** est posé) | **0** | **Défaut LATENT, pas une capacité oubliée.** `ZQualityScale.fromConfig` rend `[0..5]`, `ZSrsQualityButtons` rend un bouton par qualité ⇒ **six paliers**, dont un « 0 » que `iffdQualityLabelKey` étiquette « Ok » par repli, et qui écrit la note la plus basse de SM-2. Mordra à la bascule du drapeau `srsQuality`. |
| 22 | **`ZHintPenaltyPolicy(floor: 5)`** `zcrud_flashcard/…/z_hint_penalty.dart:42` | `review_session_zcrud.dart:26` | **0** | **La parité annoncée par le jumeau est FAUSSE** : sa table dit « le legacy compte les indices sans les pénaliser », mais `zApplyHintCeiling` est appliqué **inconditionnellement sur tous les chemins** ; avec la politique nue, chaque indice abaisse la note d'un cran. Un QCM parfait après un indice rend **4 au lieu de 5**. Si le propriétaire **veut** la pénalité, il n'y a rien à faire — mais il faut le décider. |
| 23 | **`revealController` (`ZToggleController`)** `zcrud_flashcard/…/z_flashcard_review_card.dart:110, :175` ; `zcrud_core/…/state/z_display_state.dart:254` | Débloque `ReviewCardZcrudView` (`review_card_zcrud.dart`, 180 l **écrites, jamais raccordées**) | **non établi** | **SEULE affirmation passée à la réfutation adversariale et TENUE.** 5 ancres sur 5 exactes, corps **bidirectionnel** vérifié aux deux sens, atteignable **au tag** (`git show v3.21.0` → 5 occurrences). Le contrôleur est **possédé par l'hôte** (`owner` requis) : l'objection écrite dans `test/w8m/review_card_reveal_command_test.dart:79` visait un contrôleur *interne*, conception que le socle n'a pas retenue. **Le chiffre « ~180 lignes gagnées » est démenti** (180 = taille du portage **conservé**). Trois conditions non bloquantes : mixin hors `build`, `assert(wasEverConsumed)` au dispose, et pas de slot de sur-impression sur la face arrière (le bouton « Masquer » se reloge dans un `Stack` d'hôte). |
| 24 | **`ZSubListConfig.summaryColumns`** `z_sub_list_config.dart:294` + **`.itemFormPresentation`** `:427` | 0 site hôte | **0** | Deux paramètres `const`, sans migration : ils remplacent des `summaryFields` non typés dont l'arrondi et le suffixe sont aujourd'hui écrits dans un seam. L'hôte consomme déjà largement la vague sous-listes 3.13→3.19 (**16 jetons `subList*`** posés dans `z_iffd_form_theme.dart`). |

**Total établi : ≈ 2 100 lignes**, dont **≈ 420 estimées** (entrée 1) et le reste mesuré.
**S'y ajoutent, NON ÉPROUVÉES** : `ZChatNotebookScreen` (≈ 330 l annoncées),
`ZChatToolCatalog` + feuille d'outils (136 l mesurées dans la Découverte, ≈ 600 l annoncées à
l'échelle du chatbot), `ZSessionSummaryView` (≈ 200 l). **À remesurer avant d'être promises.**

### 2.2 Deux gains à coût nul qui ne sont pas dans le tableau

- **Allumer les 12 bascules du domaine « dossiers d'étude »** dans `main.dart:201-210`. Le code est
  écrit (6 170 l de jumeaux), compilé, testé (21 fichiers de test nommément liés). Le legacy
  retiré pèse **≈ 3 640 l**. C'est une décision de QA, pas un chantier.
- **Corriger deux commentaires périmés qui gèlent deux paquets** :
  `iffd/pubspec.yaml:292` (« zcrud_list / zcrud_export exigent Syncfusion ^34, IFFD est en ^32 ») —
  faux, IFFD est en **`^34.1.31`** (`:141-149`) ; et `:326` (« la chaîne `zcrud_flashcard →
  zcrud_export → syncfusion_flutter_pdf ») — faux, `grep -n zcrud_export packages/zcrud_flashcard/pubspec.yaml`
  → **RC=1**.

---

## 3. MANQUE AU SOCLE

Groupé par paquet. **L'étude et la révision d'abord.** La colonne « bloque » dit si le manque
empêche une capacité d'étude ou de révision, pas s'il est gênant.

### 3.1 `zcrud_flashcard` / `zcrud_session` — révision, examen blanc

| # | Manque | Forme du canal | Bloque ? |
|---|---|---|---|
| **FLA-1** | **Filtrer par IDENTIFIANT de source** (`documentId`, `noteId`), pas seulement par `kind` | champ `sourceIds: Set<String>` sur `ZFlashcardTestFilters` **et** `ZFlashcardBrowseFilters` + prédicat `zMatchesSourceId`, jumeau exact de `zMatchesSourceKind` (`z_flashcard_filters.dart:174-180`) | **OUI** — la donnée est là (`ZDocumentSource.documentId` `z_flashcard_source.dart:159`, `ZNoteSource.noteId` `:98`), le filtre ne la lit pas. Sans lui, `zApplyTestFilters` (§2, entrée 10) n'adopte que **3 axes sur 5**, et le drapeau `folderFlashcardsFilter` ne peut pas basculer à parité. Grep négatif : `grep -rn 'noteId\|documentId' z_flashcard_filters.dart` → **RC=1** |
| **SES-1** | **Mode CONTRÔLÉ de la saisie de réponse** : `initialAnswer` / `onAnswerChanged` / `isSubmitted` piloté par le parent, et suppression optionnelle de « Soumettre » et « Je ne sais pas » | paramètres sur `ZFlashcardAnswerInput` (`z_flashcard_answer_input.dart:104`) | **OUI** — le socle se verrouille **one-shot** (`_submitLocked` `:334`, `onTap: corrected != null ? null` `:983`, bouton IDK retiré `:1445`) ; l'examen blanc d'IFFD laisse tout **ré-éditable** jusqu'à la soumission globale (`enabled: !isSubmitted` `:724-741`, `readOnly: widget.isSubmitted` `:886`). Modèles **mutuellement exclusifs**. C'est le mur qui rend `white_exam_question_card.dart:679-888` (208 l) structurellement non migrable |
| **SES-2** | **Slot de rendu riche pour les LIBELLÉS DE CHOIX** | `choiceBuilder` sur `_ChoicesInput` — `contentBuilder` n'a **qu'un site**, la question (`:746`) ; les choix sortent en `Text(choice.content)` nu (`:1090`) | **OUI** — le corpus IFFD porte des formules LaTeX, rendues à facteur 1.0 (`white_exam_question_card.dart:747-763`) et 1.2 (`flashcard_repetition_widgets.dart:517-542`). Sans ce slot, les formules s'affichent **en source**. Grep négatif : `grep -rn "choiceBuilder\|choicesBuilder\|ZChoiceBuilder" zcrud_session/lib/` → **RC=1** |
| **SES-3** | **Champ de réponse rédigée pluggable** (éditeur riche injecté) | `answerBuilder`/`editorBuilder` — aujourd'hui `TextFormField` nu (`:1246-1291`), refus documenté `:1206-1213` | **OUI** — les deux hôtes montent `MarkdownEditionField` (Quill), `markdown_edition_field.dart:50` |
| **SES-4** | **« Je ne sais pas » distinct d'une réponse fausse** | 5ᵉ seau `ZFeedbackTier.skipped`, atteint par un **drapeau explicite** de la soumission (`ZFlashcardSubmission.skipped: bool`) — jamais par une note-sentinelle, que `clampQuality` écrase | **OUI, partiellement** — `_submitDontKnow` et `_qualityFor(exact: false)` atterrissent sur le **même** `config.minQuality` ; IFFD a une banque de 6 messages propre à l'IDK (`white_exam_page.dart:534-545`) |
| **SES-5** | **Marquage/fanion d'une question** en cours d'examen | `flagged: Set<int>` + `onFlagToggled` sur `ZListSessionView` | Non (contournable en enveloppant, au prix de la virtualisation). Grep négatif : `grep -rln "flagged\|Icons.flag" packages/*/lib/` → **aucun résultat dans les 41 paquets** |
| **SES-6** | **Chronomètre d'EXAMEN** (le socle chronomètre par carte) et **bandeau de score global** (% cumulé, temps moyen par question) | `elapsed` notifié sur `ZWhiteExamSessionController` ; `extraStats: List<ZSummaryStat>` sur `ZSessionSummaryView` | Non — mais ces trois canaux ne concernent aujourd'hui que du **code mort** (§2.0) |
| **SES-7** | **Le seau de feedback ne voit ni la soumission ni le nombre d'indices** | `maybeResolve(key, lang, {ZFlashcardSubmission? submission})` | Non — perte du sous-découpage 0/1/2+ d'IFFD |
| **SES-8** | **`ZSessionModeKind.whiteExam`** absent du sélecteur de modes (4 valeurs) | 5ᵉ valeur d'enum + sa tuile | **OUI** — le moteur et la vue d'examen blanc existent, **rien ne les propose** ; l'entrée « Examen Blanc » de l'hôte est en commentaire (`flashcard_widgets.dart:1135`). Grep négatif : `grep -n whiteExam z_session_mode_selector.dart` → **RC=1** |
| **SES-9** | **Couleurs de confetti non injectables** | `colors: List<Color>?` sur `ZCelebrationSpec` (11 champs, aucun `colors`) | Non — perte cosmétique, à arbitrer contre FR-26 |
| **SES-10** | **Le swipe ne peut pas noter**, et la file ne peut pas muter sans reset d'index | relayer la direction (ou `previousIndex`) en sortie de `ZSessionCardSwiper` ; désarmer le reset à 0 de `didUpdateWidget:365-388` | **OUI pour une adoption non destructive** — IFFD note par direction (`folder_flashcards_repetitions_page.dart:626, :651`) et mute sa file à presque chaque note ; le socle interdit le premier par construction (`_handleSwipe` ignore `direction`) et remonte à la carte 0 au second |
| **SES-11** | **Persistance du streak** | port `ZStreakStore` (patron `ZRepetitionStore`), ou adaptateur documenté | Non (l'hôte peut posséder la persistance) — mais c'est la pièce qui **fait atterrir** §2 entrée 11. ⚠️ La forme stockée diffère : socle `lastGradedDay` (`yyyy-MM-dd`), hôte `DateTime` ⇒ **migration de données** |

### 3.2 `zcrud_markdown` — le rendu des contenus de cours (trois CR **ouvertes**)

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **MD-1** | **Retour à la ligne souple non déclarable** (CR-IFFD-115, `docs/zcrud-change-requests.md:7675`) | `softLineBreak` (défaut `false`, rendu **inchangé**) sur `ZMarkdownCodec`, conditionnant l'enregistrement de `_ZSoftLineBreakSyntax` (`z_markdown_codec.dart:283`, enregistrée **inconditionnellement** `:509`) | **OUI, et c'est le manque le plus grave du dossier** — le corpus d'IFFD n'est pas écrit par des auteurs markdown : ce sont des saisies au clavier et des sorties de modèle, où Entrée sépare les lignes. `parser.addNode(md.Text(' '))` **recolle tout en un pavé**. 127 valeurs `content` de production sont lues de travers, ainsi que **toutes les explications générées par l'IA**. Aggravation mesurée : le drapeau `flashcardListRichReader` bascule la **réponse** et pas la **question** (`z_qa_flags.dart:266-269`) ⇒ une même tuile rend ses deux faces avec **deux moteurs différents**. Grep négatif : `grep -rn softLineBreak packages/*/lib` → **RC=1 sur les 41 paquets** |
| **MD-2** | **Géométrie fermée du tableau rendu** (CR-IFFD-114, `:7589`) | slot de tableau dans `ZRichTextStyleSet` (largeur de colonne + défilement horizontal), **ou** export de `kZEmbedBuilders` | **OUI, indirectement** — `defaultColumnWidth: const IntrinsicColumnWidth()` en dur (`z_table_embed.dart:187`), aucun `SingleChildScrollView` dans le **rendu** (les deux sont dans le dialogue d'édition). Le lecteur legacy pose `MinColumnWidth(IntrinsicColumnWidth(), FlexColumnWidth())`. Un tableau large **déborde**. Le tableau est un support de cours courant, rendu par ce chemin unique dans le lecteur d'explications IA. Les 4 échappatoires ont été essayées et mesurées **inertes** par le pilote |
| **MD-3** | **Pas de sous-titre au dialogue d'édition plein écran** (CR-IFFD-116, `:7734`) | `subtitle: String?` sur `showZRichTextFullscreenDialog` **et** `ZRichTextFullscreenDialog` | Non — mais **quatrième surface** du même motif (après `ZFolderCard`/CR-28 et `ZSearchableAppBar`/CR-34). Contournement de l'hôte : `'$titre — $sousTitre'` (`workflow_notes_zcrud_edition.dart:152-166`) : l'information survit, la hiérarchie non. Grep négatif : `grep -rn subtitle packages/zcrud_markdown/lib` → **RC=1** |
| **MD-4** | **Extraction de texte brut d'un corps riche** | `zPlainTextOf(ops) → String` (ou `ZCodec.toPlainText`) | Non — mais sans elle `ZDefaultNoteCard.excerpt` (`:78`) est inatteignable. `toPlainText()` n'est appelé qu'**en interne**, 7 sites |

### 3.3 `zcrud_study` — assemblages manquants (étude)

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **STU-1** | **Aucun assemblage « génération IA → revue → matérialisation » pour la carte mentale** | `ZMindmapGenerationSheet` + `ZMindmapGenerationController` + `ZMindmapGenerationLauncher`, **symétriques** aux trois pièces flashcard ; plus un décodeur neutre `List<ZMindmapNode>` ← JSON dans `zcrud_mindmap` | **OUI** — le port existe **seul** : `grep -rn ZMindmapGenerationPort packages/*/lib` → **2 lignes**, sa déclaration et une dartdoc. L'hôte recopie le bloc « réponse IA → `json.decode` → nœuds → viewer → `repo.update` → `catch` » **7 fois, 332 lignes**, et les 7 copies **divergent déjà** (`description` renseigné dans 2 sur 7, `subjectId` calculé de trois façons, 5 journalisent l'échec et 2 l'avalent) |
| **STU-2** | **`ZNoteSummaryPort` n'a aucun consommateur** | contrôleur + surface, patron `ZFlashcardGenerationController` | **OUI** — capacité « Résumer avec instructions ». `grep -rn ZNoteSummaryPort packages/*/lib` → **2 lignes**. La requête ne porte que `content`/`maxLength`/`languageTag`/`extra` : ni `summaryType`, ni `modelId` |
| **STU-3** | **Aucun chemin « one-tap » note → cartes persistées** | raccourci sur `ZFlashcardGenerationController` (pré-remplir `content`, pré-sélectionner une `contextSource`, sauter l'étape tags), ou pilotage sans tête | **OUI** — le geste réel des **5 sites** IFFD (409 l mesurées) est **1 tap** ; le socle impose ≥ 4 interactions et son `_contentController` naît **vide** (`:304`). Grep négatif : `grep -rn 'quickGenerate\|generateAndCommit\|skipTagConfirmation\|autoConfirm' zcrud_study/lib zcrud_flashcard/lib` → **RC=1** |
| **STU-4** | **Port de génération à contrat PROGRESSIF** | `Stream` ou callback de progression, en regard de `Future<ZResult<…>>` | **OUI** — tous les ports de génération du socle sont one-shot ; l'hôte est **progressif** (`onComplete(result, completed, {hasError})` rappelé en boucle, `iffd_ai_repository_impl.dart:146, :160, :168, :194`). Chaque adoption exige un adaptateur d'hôte |
| **STU-5** | **Aucun rattachement typé d'un dossier à une MATIÈRE** | champ `subjectId` (ou `ZStudySubjectRef`) sur `ZStudyFolder` | **OUI** — grep négatif : `grep -rn -i "subjectid\|subject_id" zcrud_study_kernel/lib zcrud_study/lib` → **RC=1** ; `grep -rnE "class ZStudySubject\|class ZSubject" …` → **RC=1**. L'hôte range `subjectId` dans `extra['iffd_subject_id']` et sa propre table dit « aucun homologue de schéma » (`z_backed_folder_repository.dart:134`). Sans ce lien : pas de groupement par matière, pas de filtre par matière, pas de `SubjectStudyToolsPage`, pas de « flashcards par défaut de la matière » |
| **STU-6** | **Sélecteur d'arbre INTER-dossiers** et **déplacement d'un contenu** | `ZFolderTreePicker` rendant `(folderId, subFolderId)` + `onMove(ref)` | Non, mais coûte **≈ 320 l** à l'hôte sur 7 sites. `ZSubfolderNavSpec` est **scopé à UN dossier** ; le seul voisin, `ZFlashcardListBatchMove`, reçoit sa destination d'un `resolveDestination` **fourni par l'hôte** |
| **STU-7** | **Aucune recherche sur une section d'outils d'étude** | `searchQuery`/`matches` sur `ZStudyToolsSectionSpec` (36 propriétés, aucune) | Non. Grep négatif : `grep -in search z_study_tools_section_spec.dart` → **RC=1** |
| **STU-8** | **Aucun point d'enveloppement d'item** ni de rappel indexé sur les sections typées | `itemWrapper` (ou `opacity`/`dimmed` sur les cartes par défaut) ; rappels rendant le modèle d'origine | Non — mais c'est ce qui rend `ZStudyToolsSectionSpec.mindmaps` inadoptable : `grep -rn opacity zcrud_study/lib` → **0 ligne dans tout le paquet**, alors que l'hôte atténue les contenus hérités à `Opacity(0.5)` et garde un tripwire dédié |
| **STU-9** | **`ZExamEditor` n'a pas le rappel HEBDOMADAIRE** | section « jours de la semaine », gouvernée par `effectiveReminderRecurrence` | **OUI** — l'entité **sait déjà** porter les deux modèles ; seul l'éditeur est en retard, et il **ment** : sur un examen IFFD (qui a toujours une récurrence), il affiche « Jours avant » dont les valeurs **n'ont aucun effet**. `ZExamEditor` n'est **pas adoptable en l'état**. Grep négatif : `grep -n "reminderRecurrence\|weekdays" z_exam_editor.dart` → **RC=1** |
| **STU-10** | **Aucune variante « échéance passée » sur `ZDefaultExamCard`** | `ZExamCardEmphasis` (enum `normal`/`past`), rendu **textuel aussi** (AD-13) | Non — mais c'est le seul signal qui distingue les deux groupes de la grille |
| **STU-11** | **Aucun port d'explication EN FLUX** | `ZAiExplanationStreamPort` rendant `Stream<ZResult<String>>`, ou une requête adressée **par route** | **OUI** — `ZAiExplanationPort.explain` rend `Future<ZResult<String>>` (`:71`). En `Future`, l'apprenant attend devant un écran figé, alors que l'hôte diffuse au fil de l'eau (`white_exam_question_card.dart:226-355`) |

### 3.4 `zcrud_document` — la lecture annotée

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **DOC-1** | **Trois natures d'annotation** : `underline`, `strikethrough`, `squiggly` | valeurs d'enum **additives** sur `ZDocumentAnnotationKind` (ajouter **en fin**, `highlight` reste le repli) | **OUI** — l'enum complet est `{highlight, stickyNote}` (`z_document_annotation_kind.dart:23-30`, fichier lu en entier) ; l'hôte en emploie **5**. Adopter aujourd'hui = **perdre 3 outils de surlignage**. C'est ce qui bloque le plus gros gisement du domaine matières : la visionneuse (3 348 l, **zéro test**) |
| **DOC-2** | **Opacité d'une annotation** | `double? opacity` borné + slot dans `ZAnnotationToolbar` | Non — dégrade |
| **DOC-3** | **Glyphe d'une note ancrée** et lignes de texte couvertes | `String iconKey` + convention sur `rects` | Non |
| **DOC-4** | **Aucun canal de conversion de document** (non-PDF → PDF) | port `ZDocumentConversionPort` | Non — `convertDocumentToPdf` est appelé **7 fois** ; `ZPdfCreationService.buildImagesPdf` ne fait qu'images → PDF |

### 3.5 `zcrud_core` — gouvernance et formulaires

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **CORE-1** | **`ZCrudAction` est fermé à 11 valeurs** ; IFFD en gouverne **17** | valeurs additives, **ou** une clé d'action ouverte (`String`) en second canal | **OUI** — les 11 de `RessourceACL` correspondent exactement, mais l'enum `Crud` d'IFFD ajoute `move` **et six droits IA** (`aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`, `aiExplain`, `aiChat`, `crud.dart:20-25`). **Chez IFFD, le droit de générer avec l'IA est un droit CRUD comme un autre.** Un `ZAcl` du socle ne peut ni gouverner la génération IA ni le déplacement. Grep négatif : `grep -niE 'String action\|customAction\|actionKey' z_acl.dart` → **RC=1** |
| **CORE-2** | **Aucun horodatage MÉTIER de dernière modification**, distinct de l'horloge de sync | champ `modifiedAt` sur `ZStudyFolder`, **hors** `ZSyncMeta.reservedKeys` | Non — `ZStudyFolder.updatedAt` est `@Deprecated` et documenté « miroir de compatibilité, le store réécrit la clé à chaque écriture ». L'hôte doit **doubler** son `updatedAt` métier dans `extra['iffd_updated_at']` : le socle **prescrit le contournement au lieu d'offrir le canal** |
| **CORE-3** | **Aucun effet de bord déclaratif par champ (`onChange`)** | complément à `ZDerivation` | Non — mais mesuré : **la conclusion de l'hôte est fausse**. Les deux effets encore câblés en `addListener` (`folder_zcrud_edition.dart:476-511`, `exam_zcrud_edition.dart:311-370`, ~100 l) **sont** exprimables en `ZDerivation(overwrite: always)`, et l'hôte l'a déjà démontré ailleurs (`subject_zcrud_edition.dart:84-92`) |
| **CORE-4** | **Une option de `select` ne peut pas porter sa propre sous-valeur** | sous-valeur typée sur l'option | Non |

### 3.6 `zcrud_screen` / `zcrud_navigation` / `zcrud_ui_kit` — assemblages d'écran

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **SCR-1** | **Aucun mode de sortie « fusionner sur `initialValues` »** sur `presentFormEdition` | `mergeWithInitialValues: bool` (ou crochet `onValues`) rendant `{...initialValues, ...zNormalizeFormValues(...)}` | Non pour l'étude, **mais c'est le manque le plus DANGEREUX du dossier** : `zNormalizeFormValues` n'itère que `fields` (`z_form_values.dart:258`) et écarte `readOnly` et les conditions fausses. Un formulaire partiel sur une entité complète est la norme — mesuré : IFFD écrit `{...départ, ...saisie}` **à la main 4 fois**, et `tasks_screen.dart:790-815` a dû se doter d'une fonction de fusion de **26 lignes** dont la dartdoc dit « LA FUSION EST LA RAISON D'ÊTRE DE CETTE FONCTION ». **Oublier la fusion est une perte de données silencieuse** : sur `folder_document`, l'`update` réécrirait le document amputé de `id`/`folderId`/`subFolderId` |
| **SCR-2** | **`steps` ⊥ `bodyBuilder` sont mutuellement exclusifs** (assert `present_form_edition.dart:258-262`) | lever l'exclusion, ou offrir un enveloppement de l'assistant | Non — mais interdit d'envelopper un assistant à étapes dans un scope applicatif : c'est ce qui bloque `subject` et `ai_router`, qui montent tous deux un `IffdZcrudScope` local **et** utilisent `steps` |
| **SCR-3** | **`maxWidth`/`maxHeight`/`sheetFrame` absents de `presentFormEdition`** alors que `presentEdition`, qu'il appelle, les porte | relais de paramètres | Non — mais les 3 points d'entrée hôte déclarent tous `bottomSheetHeightRation`. Grep négatif : `grep -n "maxWidth\|maxHeight\|sheetFrame" present_form_edition.dart` → **RC=1** |
| **SCR-4** | **Aucun créneau d'état vide** sur `ZCrudScreen`/`DynamicList` | `emptyBuilder` injectable | Non pour l'étude — mais `dynamic_list.dart:184-192` code en dur `_ZListMessageView('list.empty')`, alors que **4 pages d'administration sur 5** portent un état vide illustré (~148 l mesurées). Grep négatif : `grep -rn "emptyBuilder\|onEmpty\|emptyWidget" zcrud_screen/lib zcrud_core/lib/src/presentation/list/` → **RC=1** |
| **SCR-5** | **Aucun slot de bouton flottant sur `ZCrudScreen`** | passe-plat `floatingActionButton` + `floatingActionButtonLocation` vers `ZPageScaffold` (**qui les a déjà**, `z_page_scaffold.dart:67-68`) | Non — mais 4 pages d'administration sur 5 **créent par FAB**, et `ai_experts_page.dart:1119-1205` porte un **FAB à état** (spinner + « Génération… » + `onPressed: null`). `ZCrudScreen` possédant le `Scaffold`, l'hôte ne peut ni le passer ni l'envelopper. Grep négatif : `grep -n floatingActionButton z_crud_screen.dart` → **0 ligne** |
| **SCR-6** | **Aucune variante de liste GROUPÉE** (sections à en-tête, repliables) | 5ᵉ variante de `ZListLayout` (`groupOf` + en-tête + repli persistable, patron `ZSectionCollapseStore`) | Non — mais c'est le **principe d'organisation** de deux pages : sections A→Z (188 l) et accordéons par effort (193 l). Et l'unique échappatoire, `ZListCustomLayout`, **perd les actions de ligne** (`dynamic_list.dart:392-396` ne reçoit pas `interaction`) |
| **SCR-7** | **Aucun mode SÉLECTEUR** (l'écran rend une valeur au lieu d'éditer) | 4ᵉ valeur de `ZScreenMode` | Non |
| **SCR-8** | **Aucun rafraîchissement manuel** (tirer pour rafraîchir) | `onRefresh` sur `ZCrudScreen`/`ZPageScaffold` | Non — l'hôte contourne par une **clé de re-souscription forcée** (`randomString()`, 70 occ. / 46 f.). Grep négatif : `grep -rn "RefreshIndicator\|SmartRefresher\|onRefresh" packages/*/lib \| wc -l` → **0** |
| **UI-1** | **`ZConfirmDialog` n'a aucun jeton de thème ni slot d'ornement** | jetons `confirmDialog*` **nullables** de `ZcrudTheme` (rendu inchangé si absents), ou slot `icon`/`leading` | Non — mais c'est ce qui borne §2 entrée 5 aux **25 `AlertDialog` bruts** et laisse les **36 `buildConfirmDialog`** hors de portée. Grep négatif : `grep -n confirm packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` → **RC=1**, aucun des 220 jetons |
| **UI-2** | **Aucun mode OVERLAY de chargement** (contenu atténué + spinner par-dessus) et **aucun spinner paramétrable** (`size`, `strokeWidth`, `color`, et surtout `value` déterminé) | `isBusy`/`busyOverlay` sur `ZPageScaffold` ; paramètres sur `ZLoadingState` | Non — mais 5 sites hôte pour le premier, 7 pour le second ; `ZContentStateView` **démonte** le contenu (`:219`), l'hôte le garde monté. Grep négatif : `grep -rn "class ZBusy\|class ZOverlay\|class ZProgressOverlay\|class ZLoadingOverlay" packages/*/lib/` → **RC=1** |
| **UI-3** | **`ZEmptyState` n'a que 5 paramètres, aucun slot `child`, `size: 48` codé en dur** (`_ZStateScaffold:267`) | slot `child` + taille d'icône réglable | Non — mais borne l'adoption : l'hôte porte 13 champs de constructeur, `FaIcon size: 200`, `DottedBorder`, deux `FolderDocumentSelector` |

### 3.7 `zcrud_firestore` / `zcrud_generator` — données

| # | Manque | Forme | Bloque ? |
|---|---|---|---|
| **FIR-1** | **Aucune voie d'écriture FUSIONNANTE** (`SetOptions(merge:)`) | `save(…, merge: true)` ou `patch` | Non pour l'étude, **mais destructeur en cutover** : `save` écrit en `batch.set` **nu** (`:1020`, dartdoc `:1002-1007` : « tout champ hors `_toMap` est écrasé ») alors que `put` de l'hôte fusionne par défaut. En strangler fig, les deux moteurs **co-écrivent le même document** : un seul `save` par le socle efface le corps legacy et **détruit le filet de rollback par bascule de drapeau**. Grep négatif : `grep -n SetOptions firebase_z_repository_impl.dart \| grep -v '///'` → **0 ligne** |
| **FIR-2** | **Aucun flux unitaire** `watchById(String id)` | verbe sur `ZRepository`, résolu par `doc(id).snapshots()` | Non — le port n'expose que `Stream<List<T>>` + un `getById` en `Future`. Grep négatif : `grep -rn "watchById\|watchOne\|watchSingle" packages/*/lib/` → **RC=1**. Bloque 6 adaptateurs hôtes identiques à 95,6 % |
| **FIR-3** | **Aucune lecture par identifiants de documents, chunkée ≤ 30** | `whereIn` chunké avec fan-in, adressable par identité de document (`ZFilter.field` est un `String`, `FieldPath.documentId` est hors d'atteinte) | Non — même famille |
| **FIR-4** | **Aucune suppression définitive** | `hardDelete` sur `ZRepository`, **ou** décision explicite de ne pas en avoir | Non — refus assumé du socle. Grep : `grep -rn hardDelete packages/*/lib` → **1 ligne, une dartdoc qui déclare l'absence** |
| **FIR-5** | **Aucun dépôt Firestore purgeable** | mixin `ZPurgeable<T>` **appliqué** à `FirebaseZRepositoryImpl` | Non — le contrat existe côté cœur et `ZCrudScreen` le consulte par un `is` ; sans le mixin, « supprimer définitivement » n'est jamais atteignable. `grep -rn ZPurgeable zcrud_firestore/lib` → **RC=1** |
| **GEN-1** | **Le codegen émet dans une `extension`, jamais en membres d'instance** | émettre en `mixin` ou en membres d'instance | **OUI pour toute adoption du codegen chez IFFD** — un membre d'extension **ne satisfait jamais** un membre abstrait hérité. `DynamicModel:9-13` déclare `toMap()` et `copyWith()` **abstraits** ; **33 des 49 classes** de `models/` en descendent. **1 249 des 1 476 lignes visées (84,6 %) sont structurellement inatteignables** |
| **GEN-2** | **Le codegen ne collecte pas les champs hérités**, et la perte est SILENCIEUSE | branche « champs de la superclasse » (`allSupertypes`), **ou** refus de build explicite | **OUI** — `_collectFields` n'itère que `element.fields` (`:465`), et `_isSilentlyLost` retourne `false` pour un champ hérité sérialisable (« omission assumée ») : **le build reste vert et le `toMap` émis perd le champ sans signal**. 24 des 40 sous-classes héritent d'une base porteuse de champs. `id` lui-même n'est jamais émis (43 usages de `super.id`) |
| **GEN-3** | **`_classify` n'a aucune branche `Map`**, ni `Timestamp` comme type de champ | branche `Map<K,V>` (clé `String` ou enum) | **OUI** — **49 champs** non classifiables chez IFFD, dont 36 `Map<…>` (22 dans le seul `annee_accademique.dart`), 4 `IconData`, 4 `Color`, 1 `Rect?`, 1 `TimeOfDay?`, `List<PdfTextLine>`. Les trois issues sont toutes perdantes : non annoté ⇒ le build **lève** ; `@ZcrudField` ⇒ `_classify` **lève** ; `@ZcrudIgnore` ⇒ perte de données silencieuse |
| **GEN-4** | **`ZPersistAs` n'a pas le format `int` millisecondes**, et pas de hook pour un enum persisté par un membre | 3ᵉ valeur d'enum ; crochet d'encodage | Non — mais IFFD emploie le format sur 4 dates, et `FlashcardRepetitionQuality` est persisté par `.value` (int 1..5) quand le générateur encode par `.name` |
| **GEN-5** | **Le `copyWith` généré est à sentinelle**, l'hôte est en `?? this.x` | mode `copyWith` à sémantique `??` optionnel | Non — mais **256 sites `.copyWith(`** sont à auditer avant toute adoption |
| **GEN-6** | **`analyzer` : fenêtre à prouver** | — | `zcrud_generator` exige `analyzer >= 12.0.0 < 14.0.0` ; `iffd/pubspec.lock` résout **analyzer 9.0.0** (avec freezed 3.2.5, json_serializable 6.13.0, riverpod_analyzer_utils 1.0.0-dev.9, auto_route_generator ^10.1). **Saut de 3 majeures à re-résoudre.** Non tranchable en lecture seule (`pub get` interdit ici) — à mesurer avant tout engagement |

### 3.8 Manques transverses, hors étude

`ZChatRouteSession` ne porte **pas** la cible du POST (le catalogue n'émet ni `route_name`, ni
`handler_id`, ni `params.endpoint`) — cf. §6 ; aucune **règle de récurrence de calendrier** dans
les 41 paquets (`grep -rn "RecurrenceRule\|RecurrenceType\|recurrenceRule" packages/*/lib` →
**RC=1**) ; aucun **canevas libre** (flow-chart) — 3 occurrences, toutes en commentaire ; aucune
entité **tâche** ; aucun **glisser entre listes** ; aucun **menu latéral/rail/fil d'Ariane** ;
aucun **FAB expansible** ; aucun **composeur de champs hors du binding GetX**.

---

## 4. L'ORDRE DE BATAILLE

Chaque lot tient en une release. Les dépendances sont mesurées, pas supposées.

### Lot 1 — **À LANCER EN PREMIER** : les cinq corrections à un paramètre (paquets : aucun)

**Périmètre** : `ZSrsConfig(minQuality: 1)` · `ZHintPenaltyPolicy(floor: 5)` ·
`ZcrudScope.derive` à `z_iffd_field_registry.dart:345` · raccorder `revealController` ·
retirer les 3 commentaires périmés (`pubspec.yaml:292`, `:326`, `study_tools_zcrud_adapter.dart:69`).
**Paquets touchés** : **aucun** — tout se joue chez l'hôte.
**Dépendances** : aucune.
**Ce que ça débloque** : deux défauts latents désamorcés **avant** la QA plutôt qu'après ; les 23
scopes locaux cessent de masquer les 12 seams racine ; un portage gelé (`ReviewCardZcrudView`) est
raccordé.

**Pourquoi celui-ci d'abord** : c'est le seul lot dont **chaque entrée a été vérifiée ligne à
ligne**, dont le coût est de l'ordre de la ligne, et qui **corrige des défauts** au lieu d'en
déplacer. `revealController` est en outre la **seule** affirmation de tout le dossier à avoir
survécu à une réfutation adversariale complète. Un lot qui ne peut pas se tromper est le bon
premier lot quand 32 promesses sur 33 viennent d'être démenties.

### Lot 2 — La suppression (paquets : aucun)

**Périmètre** : les 7 cibles de §2.0, ≈ **12 250 lignes**.
**Dépendances** : aucune. **À faire avant tout portage.**
**Ce que ça débloque** : `appointment_editor.dart` (7 858 l) sortait des analyses comme « 2 500
lignes migrables » ; `dynamic_list_screen.dart` (1 753 l) comme « 1 753 lignes à porter ». Les deux
sont morts. Supprimer d'abord évite d'engager deux lots de portage sur du code que personne
n'ouvre.
**Attention** : conserver `agents_screens.dart:1-112`, `ExamAnswer` (`white_exam_page.dart:754-779`),
et les 4 constantes de `appointment_editor.dart` encore consommées par `recurrence_picker.dart`.

### Lot 3 — Le domaine pur de la révision (paquets : aucun ; canaux `zcrud_flashcard`, `zcrud_session`)

**Périmètre** : `zApplyTestFilters` · `zEvaluateLocally` · `zCategorize` · `zAdvanceStreak` ·
`zFeedbackTierFor`/`ZDefaultFeedbackBank` · `zFoldDiacritics`. ≈ **380 lignes**, **fonctions pures**.
**Dépendances** : lot 1 (le réglage `minQuality: 1` conditionne `zEvaluateLocally`).
**Ce que ça débloque** : un bug livré corrigé (la flamme au changement d'heure), un quadratique
supprimé, un tirage aléatoire enfin injectable donc testable, et trois recopies de barème unifiées.
**Réserves à porter au brief** : le filtre par identifiant de source (FLA-1) reste manquant — deux
axes sur cinq restent à la main ; l'arbitrage `_gradedModes` doit être tranché par le propriétaire.

### Lot 4 — Le socle du socle : `zcrud_markdown` (paquet : `zcrud_markdown`)

**Périmètre** : **MD-1** (`softLineBreak`), **MD-2** (géométrie du tableau), **MD-3** (`subtitle`).
Les trois sont des **CR ouvertes du pilote**, toutes trois à surface additive avec rendu inchangé
par défaut.
**Dépendances** : aucune.
**Ce que ça débloque** : **MD-1 est le seul manque du dossier qui fausse la lecture d'un corpus de
production**. Tant qu'il tient, chaque note, chaque explication IA et chaque question de flashcard
est recollée en pavé, et une même tuile rend ses deux faces avec deux moteurs différents. C'est le
lot socle à faire en premier.

### Lot 5 — La saisie de réponse (paquet : `zcrud_session`)

**Périmètre** : **SES-1** (mode contrôlé), **SES-2** (slot de libellé de choix), **SES-3** (éditeur
riche injecté), **SES-4** (« je ne sais pas » distinct).
**Dépendances** : lot 4 (SES-2 et SES-3 n'ont d'intérêt que si le markdown se lit droit).
**Ce que ça débloque** : `ZFlashcardAnswerInput` est **déjà branché** dans IFFD
(`interactive_flashcard_repetition_card.dart:414`, drapeau `kReviewSessionUseZcrudDefault = false`).
Les quatre manques sont exactement ce qui **retient la bascule**. Sans eux, les 208 lignes de saisie
de l'examen blanc restent structurellement non migrables et les formules LaTeX du corpus
s'afficheraient en source.

### Lot 6 — La gouvernance (paquet : `zcrud_core`)

**Périmètre** : **CORE-1** (`ZCrudAction` ouvert ou additif : `move` + les 6 droits IA).
**Dépendances** : aucune.
**Ce que ça débloque** : chez IFFD, **générer avec l'IA est un droit CRUD**. Tant que l'enum est
fermé à 11 valeurs, aucun écran assemblé du socle ne peut gouverner la génération ni le
déplacement — ce qui retire au portage d'écran une part de son intérêt.

### Lot 7 — Les assemblages de génération (paquet : `zcrud_study`)

**Périmètre** : **STU-1** (carte mentale : contrôleur + feuille + lanceur, symétriques aux trois
pièces flashcard, plus un décodeur JSON → `List<ZMindmapNode>` dans `zcrud_mindmap`), **STU-2**
(résumé de note), **STU-3** (chemin one-tap), **STU-4** (contrat progressif).
**Dépendances** : lot 6 (les gestes de génération sont gouvernés par les droits IA).
**Ce que ça débloque** : 332 lignes recopiées 7 fois et **déjà divergentes** côté carte mentale ;
409 lignes sur 5 sites côté flashcards-depuis-une-note. C'est le plus gros gisement d'assemblage
manquant du dossier, et il est **entièrement neuf** : le socle n'a que les ports.

### Lot 8 — Les écrans de liste (paquets : `zcrud_screen`, `zcrud_core`, `zcrud_ui_kit`)

**Périmètre** : **SCR-1** (fusion sur `initialValues` — le plus urgent, c'est une classe de perte
de données silencieuse), **SCR-4** (état vide injectable), **SCR-5** (passe-plat FAB), **SCR-6**
(liste groupée + `interaction` relayée à `ZListCustomLayout`), **UI-1** (jetons de confirmation).
**Dépendances** : lot 6.
**Ce que ça débloque** : c'est l'ensemble minimal sans lequel **aucune** des cinq pages
d'administration, ni les deux pages IA, ne sont portables sans régression. Les réfutations ont
montré que le gain volumétrique y est de **24 % à 30 %** de ce qui était annoncé ; ces cinq canaux
sont ce qui manque pour que le reste ne soit pas une perte nette.

### Lot 9 — Les données (paquets : `zcrud_firestore`, `zcrud_generator`)

**Périmètre** : **FIR-1** (écriture fusionnante — sans elle, toute adoption du dépôt générique en
cutover **détruit le filet de rollback**), **FIR-2**, **FIR-3**, **FIR-4/5** ; puis **GEN-1** à
**GEN-3**, et la mesure de **GEN-6** (`analyzer`).
**Dépendances** : aucune, mais **le lot 9 est le dernier** : il porte le plus de risque pour le
moins de certitude, et sa moitié `zcrud_generator` (GEN-1/2/3) est une refonte d'émission, pas un
ajout de paramètre.
**Ce que ça débloque** : 823 lignes d'adaptateur réécrites 6 fois à 95,6 % près, et — seulement si
GEN-1 à GEN-3 sont livrés — l'accès du codegen aux 2 604 lignes de (dé)sérialisation manuelle.
**Ne pas engager la moitié `generator` sans avoir d'abord prouvé la co-résolution `analyzer ≥ 12`.**

---

## 5. Ce qui reste à l'hôte définitivement, et pourquoi c'est sain

Le socle ne porte pas de règle métier. Les points ci-dessous ne sont pas des manques : ce sont les
**paramètres que les seams du socle attendent**.

| Famille | Volume / preuve | Pourquoi c'est sain |
|---|---|---|
| **La matrice d'autorisations CRUD par ressource** — un rôle porte une matrice par objet délégable, éditée par douze d'un coup pour une année académique | `lib/src/domain/security/` : 4 fichiers, **902 l** ; 33 lectures d'`AppUserPermissions` sur 12 fichiers | Déjà exprimée **par le bon seam** : le champ maison `z_iffd_acl_matrix_field.dart` (262 l) est servi par `ZWidgetRegistry`. Le socle porte `ZAcl`/`ZCrudAction` ; leur **remplissage** est le métier d'un institut |
| **L'année académique comme suffixe de clé d'ACL** — `"FolderModel$accademicYear"`, relue à chaque appel, jamais capturée | `folder_details_page.dart:191-195`, `permission_helpers.dart:83` | Un même utilisateur a des droits **différents sur le même type** selon l'année. Aucune ontologie de socle ne porte ça, et aucune ne le devrait |
| **`FiliereEtCycleIFFD`, `NiveauIFFD`, `CycleIFFD`, `AuditeurIffd`** — 6 filières × 2 cycles, `title` dérivé par découpe de chaîne | `iffd_models.dart:30` | Nomenclature d'un établissement |
| **Les 29 prompts pédagogiques** et les **6 corpus juridiques** (Code du GATT, TEC CEDEAO, codes des douanes CEDEAO/Togo/Niger, CGI Togo) | `AiPromptGenerator` ; `notebook_settings_iffd.dart:55-62` | Le socle transporte une **requête**, jamais une **intention pédagogique**. `ZChatCorpusOption` les accueille déjà comme **déclaration d'hôte** — clé opaque + libellé traduisible |
| **Le Système Harmonisé douanier** (`hsSection`, `hsChapter`) et les 9 outils de la valeur en douane | `flashcard_model.dart:106-141` ; `sh2022.dart` | `ZFlashcard.extra` + `ZExtension` (AD-4) sont faits pour ça |
| **Le corpus est du markdown, jamais du Delta** | `IffdRichTextCodec` (193 l) ; le défaut `ZDeltaCodec` viderait ~11 400 valeurs | `ZCodec` est **pluggable exactement pour cela** (AD-7), et l'hôte le consomme déjà |
| **Le double format `content`** (markdown OU Delta selon l'historique), `iffd_content` faisant foi ; les orthographes fautives contractuelles `accademicYear`, `folderExplaination` | `z_backed_smart_note_repository.dart:108-238` ; `folder_model.dart:19, :32` | Dette de schéma d'IFFD, préservée jusque dans les adaptateurs. Le socle a déjà fait sa part : `normalizeNoteContentOps` préserve **verbatim** une `String` markdown |
| **La génération PDF DISTANTE des flashcards** | `export_flashcards_to_pdf.dart:61-88` (`dio.post`) | `ZFlashcardPdfTemplate` génère **localement**. Le substituer serait un **changement de produit**, pas une migration. Deux analyses l'ont proposé ; c'est à écarter explicitement |
| **La hiérarchie bicéphale** (un sous-dossier est un dossier dont `isSubFolder` est vrai) et la **double appartenance** dossier OU matière | `folder_model.dart:99` ; purge de clés `smartnotes_dialogs.dart:105-111` | Invariant produit. Le socle n'a que `parentId` + `validatePlacement` |
| **`Task extends google_api.Task`, `Event extends google_api.Event`** | `workflow/models/task.dart:124`, `event.dart:5` | C'est une **frontière d'intégration** (Google Calendar/Tasks), pas une dette. Elle bloque d'ailleurs le codegen par construction, et c'est normal |
| **L'échafaudage de bascule** — 55 `const bool k*Default`, 67 `Provider<bool>`, `z_qa_flags.dart` (985 l), `z_flag_gateway.dart` | ≈ **1 300 l** | **Strangler fig, temporaire par construction.** Il disparaît avec le legacy. Le registre porte une assertion qui **interdit au classement de se contredire** — après s'être déjà contredit une fois. C'est une pratique d'hôte à propager par l'exemple, pas un canal à livrer |
| **Les 6 adaptateurs `z_backed_*`** | **4 648 l** | Mappeurs `FolderModel ↔ ZStudyFolder` : le prix du double modèle **pendant** la transition. Ils disparaissent quand l'hôte adopte l'entité du socle |
| **Le routage** (26 routes, `meta: SideMenuItem(...).toMap()` générant le menu latéral) | `app_router.dart` 270 l + 2 601 l générées | Hors périmètre **par conception** : `zcrud_navigation/pubspec.yaml:16` déclare « AUCUN routeur », et deux gardes de source en interdisent l'import |
| **Le chrome de marque des écrans d'authentification** | `login_page` 727 l, etc. | Grep négatif : `grep -rn "class Z.*Login\|class Z.*Auth\|class Z.*Splash" packages/*/lib` → **RC=1**. ⚠️ La **duplication interne** reste un défaut d'hôte : `login_page.dart:403-435` et `accademic_year_selection_page.dart:227-259` sont **identiques à l'octet** |
| **Le plan comptable SYSCOHADA, la cotation, l'agenda `lib/workflow/`** | 1 472 l + 624 l + le sous-domaine calendaire | Sans rapport avec le CRUD déclaratif |

Une dernière pratique de l'hôte mérite d'être remontée telle quelle : **le tripwire**. IFFD garde
des tests qui **affirment la perte** sur chaque défaut amont contourné (par ex. « l'atténuation
legacy `Opacity(0.5)` est CONSERVÉE au-dessus de la carte du socle »,
`test/w6/study_tools_zcrud_test.dart:1561-1586`). Quand l'amont corrige, le test rougit et désigne
le doublon — au lieu de croire un handoff sur parole. C'est le pendant exact de la discipline R3
côté socle, et c'est à propager.

---

## 6. Ce que la réfutation a démenti — ce qu'on a failli promettre à tort

**33 affirmations passées à la réfutation adversariale. 32 démenties. 1 tenue.**

Ce n'est pas un accident de rédaction : c'est un **motif**, et il a une forme constante.

### 6.1 Le motif dominant : le corps métier compté comme du gain

Dans neuf réfutations sur dix, le canal du socle **existe**, il est **exporté**, il est
**atteignable**, et son corps fait ce qu'on lui prête. Ce qui tombe, c'est le **chiffre** — parce
qu'on a compté comme « supprimées » des lignes qui sont seulement **déplacées**.

- « Les 5 menus contextuels d'item, ~545 lignes » → **≈ 45-60**. Les 548 lignes annoncées sont les
  corps de `onClickMenu` (appels IA, `json.decode`, écritures de dépôt, dialogues), **relocalisés**
  dans les closures `onSelected`. Facteur **9**.
- « L'examen blanc entier, ~600 lignes » → **≈ 230**, dont 91 déplacées et 201 à conserver.
- « Les états de chargement/vide, ~283 lignes » → **≈ 30-40**. Facteur **8**.
- « Les deux pages de liste IA, ~1 700 lignes » → **≈ 405 brutes**, soit **24 %** — et à en
  déduire deux adaptateurs `ZRepository` de 9 membres, deux `listFields`, deux `cellsOf`, deux
  `editionBuilder` et un pont `ZAcl`. **Solde net au mieux nul.**
- « La coquille des 4 formulaires, ~420 lignes » → **76 lignes de chrome réellement retirées**,
  ~250 déplacées, 106 comptées à tort dans l'assiette, **75 tests widget à réécrire**.

**La preuve la plus dure, et elle vient de l'hôte** : IFFD a déjà porté le plus petit des cinq
menus. Bilan mesuré du seul essai réel : **+241 lignes écrites, −0 supprimée**, et le portage est
mort (drapeau à `false`, zéro import depuis `lib/`).

### 6.2 Le second motif : la cible n'existe pas

Deux des plus gros gisements annoncés étaient du **code mort**.

- « Les trois surfaces de l'éditeur de rendez-vous (5 091 l), ~2 500 lignes migrables » →
  `displayAppointmentDetails` a **un seul hit dans tout le dépôt : sa propre définition**. Le
  mapping proposé **inventait un champ absent** (des « rappels » : `grep -in "reminder\|rappel"` sur
  les 7 858 lignes → **0**) et **omettait un champ massivement présent** (le fuseau horaire : 94
  occurrences, une classe dédiée de 83 l). Et la masse réelle (58 % de la surface) est la
  **récurrence**, que la revendication renvoyait elle-même à l'hôte via `EditionFieldType.custom`.
  Le « gain » annoncé était, à la ligne près, ce qui ne bouge pas.
- « 1 753 lignes de moteur de liste qui ne servent QU'UN SEUL écran » → elles ne servent **aucun
  écran atteignable**. `AgentsScreen` n'est construit nulle part.

### 6.3 Le troisième motif : la condition cachée qui détruit des données

Trois affirmations auraient causé une perte silencieuse si on les avait suivies.

- **`presentFormEdition`** rend `zNormalizeFormValues` (champs **déclarés** seulement) là où l'hôte
  émet `controller.values` (**toutes** les tranches semées). Sur `folder_document`, qui déclare **un
  seul champ**, l'`update` aurait réécrit le document **amputé de `id`, `folderId`, `subFolderId`**.
  Sur l'examen : **5 clés perdues sur 9**, dont `id` — ce qui transforme une mise à jour en création.
- **`FirebaseZRepositoryImpl.save`** écrit en écrasement **total** ; `put` de l'hôte fusionne. En
  cutover strangler fig, où les deux moteurs co-écrivent le même document, un seul `save` **détruit
  le filet de rollback par bascule de drapeau**.
- **`ZDeletionSemantics.strict`**, présenté comme « le mode qui s'applique », est l'**exact
  contraire** des trois chemins de lecture réels de l'hôte (filtrage client sur `is_deleted == true`
  ⇒ absent = **visible**). Et le parc n'est pas backfillé : le moteur legacy écrit `"deleted"`,
  jamais `is_deleted`, **dans les mêmes collections**. Brancher le socle au défaut aurait fait
  **disparaître silencieusement tout le parc historique**.

### 6.4 Le quatrième motif : « offert » confondu avec « consommé »

- `ZItemAction.isDestructive` : **inerte** — `grep -rn isDestructive zcrud_menu/lib/src/presentation/`
  → **RC=1** sur les 9 fichiers de rendu. Il n'est lu que par des tests tautologiques.
- `ZFeatureAvailability.gate` ne fait **rien disparaître** : il laisse l'entrée rendue, au complet,
  à pleine opacité, seulement non tapable. La migration aurait été une **régression** contre l'état
  actuel de l'hôte, qui grise à `Opacity(0.5)`.
- Le catalogue de routes IA : `routeName` n'est **pas** un endpoint, c'est une **clé d'annuaire de
  ports** ; aucune ligne du socle ne construit d'URL à partir de lui, et le décodeur n'émet
  `routeName` pour aucune des 13 routes d'IFFD. La répartition est **structurellement inerte** :
  `zChatRouteDispatchIds` rend une liste vide, donc toujours le port de repli.
- `$XxxTimestampFields` n'agit **que** via `FirebaseZRepositoryImpl` : `grep -rn FirebaseZRepositoryImpl iffd/lib`
  → **RC=1**. Le canal existe et n'atteint rien.

### 6.5 Les erreurs de citation, à ne pas reproduire

Plusieurs réfutations ont relevé des ancres fausses dans les preuves avancées — jusqu'à **4 sur 10**
dans un cas (`ZItemActionKind` annoncé `:95`, mesuré `:70`). Les symboles existaient ; **la preuve
n'avait pas été relue sur disque**. Deux chemins cités n'existaient pas
(`domain/entity/z_entity.dart` — le réel est `domain/contracts/z_entity.dart`), et un symbole
entier était imaginaire (`ZRowActionMenu`).

### 6.6 Deux préconditions que personne n'avait signalées, mesurées ici

- **`zcrud_responsive` n'est PAS une dépendance déclarée** : il n'apparaît qu'en
  `dependency_overrides:682`, et aucun barrel ne le ré-exporte. Toute adoption de `ZAdaptiveGrid` /
  `ZReorderableAdaptiveGrid` exige **une entrée de `pubspec.yaml`** — trois analyses affirmaient
  « sans un octet de `pubspec.yaml` ».
- **`zcrud_annotations` idem** (`:577`), et **`zcrud_generator` est absent** : le codegen exige
  **deux** entrées, pas une. Un override ne confère aucun droit d'import.

### 6.7 Ce qu'il faut en retenir pour la suite

**Le socle n'est presque jamais en cause.** Sur les 33 affirmations attaquées, le canal existait
32 fois. Ce qui a échoué, c'est la mesure du besoin de l'hôte : on a comparé une **API** à une
**ligne de code**, jamais un **comportement** à un **comportement**.

La règle qui en découle, et qui gouverne §2 de ce document : **un gain n'est un gain que si l'on a
mesuré ce qui reste**, et il faut le mesurer par comptage d'accolades sur le bloc réel, pas par
`wc -l` sur le fichier. Les seuls chiffres de §2 qui n'ont pas cette assise sont marqués
« NON ÉPROUVÉE » — quatre entrées sur vingt-quatre.

---

## 7. Ce que ce document n'établit pas

- **Aucun test lancé, dans aucun dépôt.** Rien ici n'atteste qu'un canal *fonctionne* — seulement
  qu'il *existe*, à telle ligne, avec tel corps.
- **Aucune compilation, aucun `pub get`.** La fermeture transitive de `zcrud_responsive`,
  `zcrud_list`, `zcrud_export_pdf`, `zcrud_chat_study` et `zcrud_generator` n'est pas résolue.
  **GEN-6** (fenêtre `analyzer`) est le point le plus incertain du dossier.
- **Les volumes en base de production** (nombre de documents sans `is_deleted`, part de cartes
  `flowchart`, corps `id` absents) sont **illisibles depuis les dépôts**. Trois verdicts de §6.3 en
  dépendent pour leur ampleur, pas pour leur existence.
- **Quatre entrées de §2 n'ont pas été passées à la réfutation** et leurs chiffres sont à remesurer :
  `ZSessionSummaryView`, `ZChatNotebookScreen`, la feuille d'outils déclarative, les petits lots
  mindmap.
- **Aucun secret n'a été lu**, aucun fichier de configuration de plateforme n'a été ouvert. Les
  clés d'API évoquées par les analyses vivent dans la configuration de plateforme de l'application
  hôte ; elles ne sont ni citées ni nécessaires ici.
- **Aucune écriture hors de `docs/analyses/iffd-migration-2026-08-26/`.** `/home/zakarius/DEV/iffd`
  est resté à `git status --porcelain` vide, avant comme après.
