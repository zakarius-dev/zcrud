# Carte du domaine « Tâches et découverte » — IFFD (mesuré le 2026-08-26)

> Relevé en **lecture seule** sur `/home/zakarius/DEV/iffd` (zcrud épinglé `ref: v3.21.0`,
> `pubspec.yaml:308`). Chemins relatifs à la racine IFFD. Aucun test lancé.

## 0. Périmètre réel

Le périmètre annoncé (4 dossiers) ne contient **que 18 fichiers / 5 252 lignes**. Il ne recouvre
qu'une part du domaine : le mot « tâches » désigne **deux choses différentes** dans IFFD, et la
« découverte » tire tout le moteur de génération IA.

| Zone | Fichiers | Lignes | Nature |
|---|---:|---:|---|
| `lib/src/presentation/features/tasks/` | 4 | 1 218 | **Tâches quotidiennes** = agrégat révisions + examens du jour (lecture seule) |
| `lib/src/features/tasks/` | 3 | 228 | Providers Riverpod (3 dépôts + 1 contrôleur vide) |
| `lib/src/presentation/features/discovery/` | 8 | 3 729 | **Découverte** = recherche + fil IA + TTS/podcast |
| `lib/src/features/discovery/` | 3 | 77 | Provider Riverpod du contrôleur de découverte |
| **Sous-total périmètre annoncé** | **18** | **5 252** | |
| 🔴 `lib/workflow/` (**inclus au-delà**) | 38 | 17 417 | **Espace de travail** = listes de tâches, tâches, agenda, événements |
| `lib/src/domain/repositories/workflow/` (2 f.) | 2 | 205 | Ports `TasksRepository` / `TasksListsRepository` |
| **TOTAL du domaine** | **58** | **22 874** | |

**Deux « tâches » distinctes, à ne jamais confondre.** Les *tâches quotidiennes*
(`presentation/features/tasks/pages/daily_tasks_page.dart`, 1 101 l.) sont un écran de **lecture** :
il agrège examens + répétitions de flashcards du jour, et **aucune entité « tâche » n'existe**. Les
*tâches de l'espace de travail* (`workflow/screens/tasks_screen.dart` 816 l. +
`task_edition_screen.dart` 589 l.) sont de vraies entités `Task` / `TaskList` : CRUD complet,
sous-tâches, rappels, récurrence.

`lib/workflow/` est **une seule bibliothèque `part`** : `workspace.dart` (112 l.) déclare **27 `part`**
et **41 `import`** (`workspace.dart:84-110`). 17 417 lignes dans un seul espace de noms — donc aucune
frontière interne mesurable par l'analyseur.

---

## 1. 🔴 LE CODE RÉPÉTÉ — la section utile

### 1.1 Les 29 emballages `callApi` de la couche IA (le plus gros gisement)

`lib/src/data/repositories/iffd_ai_repository_impl.dart` (1 377 l.) contient **29 méthodes** qui sont
toutes le **même corps** : `return callApi(endpoint: aiRouter?.<champ> ?? "<route>", stream:, userData:,
data: {"message": <prompt>(…), "model": aiRouter?.aiModel}, onComplete:)`.

| Mesure | Valeur | Preuve |
|---|---:|---|
| Emballages `return callApi(` | **29** | `grep -c 'return callApi('` |
| Signature `void Function(AiResponse result, bool completed, {bool hasError})? onComplete` recopiée | **27** dans l'impl **+ 27** dans le port abstrait | `iffd_ai_repository_impl.dart`, `ai_repository.dart` |
| Paramètre `IffdAiRouterModel? aiRouter` recopié | **22** (port) | `ai_repository.dart` |
| Paramètre `AppUserData? userData` recopié | **18** (port) | `ai_repository.dart` |
| Paramètre `CycleIFFD cycle = CycleIFFD.superieur` recopié | **13** (port) | `ai_repository.dart` |
| Routes en littéral (13 noms, 19 sites) | **19** — `generate_flashcards` ×4, `generate_mindmap` ×3, `generate_summary` ×2, puis `explain`, `chat`, `summarize_explanation`, `elaborate_explanation`, `explain_with_style`, `generate_subject_tags`, `generate_subject_flashcards`, `generate_flashcard_hint`, `generate_flashcard_explanation`, `evaluate_flashcard_answer` | `grep -on 'endpoint: … ?? "…"'` |
| Total lignes du doublet port + impl | **1 871** (`494` + `1 377`) | `wc -l` |

⇒ Estimation : **≈ 1 500 lignes sur 1 871** ne portent aucune information autre que « telle intention
→ telle route + tel prompt ». C'est exactement la **décision d'owner du 2026-08-23** (transport
PAR ROUTE, catalogue de routes) : ce catalogue devrait être **une table déclarative**, pas 29 méthodes.

### 1.2 Le bloc « fin de génération » recopié 7 fois

`discovry_page_controller.dart` : `onComplete: (result, completed, {hasError = false}) { _onAiCompletion(
result:…, completed:…, hasError:…, onFolderExplanation:…, scrollController:…, stream:…, onError: (error)
=> onAssistantError(aiMessageId:…, error:…, messageId:…), onAnswer: (aiAnswer) => onAiAnwser(…)) }`.

Sept sites : `:1264` (`explainSubject`), `:1320` (`getRelatedSubjects`), `:2061`
(`generateSummaryFromDocuments`), `:2131` (`_summuryFromSpecifisPages`), `:2253`
(`summarizeExplanation`), `:2303` (`elaborateExplanation`), `:2356` (`explainSubjectWithStyle`).

**7 sites × ~28 lignes ≈ 196 lignes.** Les trois derniers (`:2231-2379`, **149 lignes**) sont
*mot pour mot* identiques hors le nom de la méthode `aiRepository.*` et le
`chatbotMessageTransformer` — vérifié par lecture intégrale de `:2231-2379`.

### 1.3 Les 6 bascules de corpus documentaire, écrites 6 fois puis propagées 28 fois

`discovry_page_controller.dart:896-923` — six méthodes de **4 lignes strictement identiques**
(`enableX = !enableX; notifyListeners();`) : `toggleCDNTogo`, `toggleCDNNiger`, `toggleCDCCedeao`,
`toggleCGITogo`, `toggleTecCedeao`, `toggleCodeGATT`.
Le **même sextuplet** est ensuite recopié comme paramètres nommés à chaque appel IA :
`enableCDNTogo` apparaît **28 fois** dans **8 fichiers** (`grep -rho enableCDNTogo lib | wc -l`),
dont `iffd_ai_repository_impl.dart`, `ai_repository.dart`, `cloud_functions_ai_repository_impl.dart`,
`openai_ai_repository_impl.dart`, `notebook_settings_iffd.dart`, `chatbot_conversation_screen.dart`.
⇒ **6 outils documentaires ≈ 168 occurrences de nom** (28 × 6). Un `Set<String>` d'identifiants de
corpus supprimerait la totalité.

### 1.4 Les trois éditeurs de rendez-vous — le même formulaire écrit 3 fois

`lib/workflow/screens/appointment_editor.dart` : **7 858 lignes**, **21 classes**, aucune l10n
(40 `Text('…')` en anglais en dur, `_repeatOption`/`_weekDay`/`_ends` en dur `:11-35`).

| Classe | Lignes | Rôle |
|---|---:|---|
| `PopUpAppointmentEditorState` | `:1006-1663` — **658** | formulaire compact (popup) |
| `AppointmentEditorWebState` | `:1708-5215` — **3 508** | même formulaire, mise en page « web » |
| `AppointmentEditorState` | `:5261-6188` — **928** | même formulaire, plein écran mobile |
| `SelectRuleDialogState` + `_CustomRule` | `:6210-6425` + `:6874-7858` — **1 200** | récurrence (doublon de `recurrence_picker.dart`, 1 721 l.) |
| `_DeleteDialog` / `_EditDialog` | `:6426-6594` + `:6595-6855` — **430** | confirmations « cette occurrence / toute la série » |

Répétitions internes : `recurrenceProperties` **227**, `_selectedTimeZoneIndex` **60**,
`_selectedColorIndex` **37**, `ListTile(` **32**, `TextField(`/`TextFormField(` **23**,
`showDialog` **19**, `showDatePicker`/`showTimePicker` **14**, `DropdownButton` **7**.
**La récurrence est écrite deux fois** — `recurrence_picker.dart` (**1 721 l.**) et
`_CustomRule`/`SelectRecurrenceRuleDialog` (**≈ 1 200 l.**) : ≈ **2 900 lignes** pour « répéter ».

### 1.5 La pyramide de 5 `StreamBuilder` imbriqués (tâches quotidiennes)

`daily_tasks_page.dart:371-445` empile **cinq** `StreamBuilder` : examens → répétitions → dossiers →
messages de chat → flashcards, chacun avec son `initialData:`, son `stream: <ids>.isEmpty ? const
Stream.empty() : repo.streamByIds(...)` et son `snapshot.data ?? const []`.

| Motif | Sites | Preuve |
|---|---:|---|
| `<ids>.isEmpty ? const Stream.empty() : …streamByIds(…)` | **3** | `:422`, `:429`, `:437` (le 1er flux, `:371`, n'a pas de garde) |
| `<x>Snapshot.data ?? const …` | **5** | `:392`, `:395`, `:448`, `:450`, `:460` |
| `ProviderScope.containerOf(context).read(…)` **au milieu d'un `build`** | **9** | `grep -coF` sur le fichier |
| `StreamBuilder<` dans le domaine (tasks+discovery+workflow) | **12** | `grep -rhoF 'StreamBuilder<'` |

⇒ **75 lignes** de plomberie de flux pour un seul écran, avec **zéro** état d'erreur : aucun
`hasError`, aucun `ConnectionState`, aucun `CircularProgressIndicator` sur cette page
(**grep négatif** : `grep -cF hasError` → **0**, `grep -cF ConnectionState` → **0**, `grep -cF CircularProgressIndicator` → **0**).
L'état vide est traité une seule fois, par `EmptyTasksWidget` (`:560-637`, **78 l.**).

### 1.6 Le motif de bascule legacy/socle, 3 sites dans le domaine

`zcrudFlagValue(<flagProvider>, fallback: k…Default, context: context) ? await _presenter…ParLeSocle(…)
: await showPushedDialog(builder: DynamicEditionScreen(…))`.

Trois sites : `tasks_screen.dart:454-500` (formulaire de **liste de tâches**),
`task_edition_screen.dart:443` et `event_editon_screen.dart:1007` (éditeur riche des **notes** /
de la **description d'événement**).

Repo entier : **61** appels `zcrudFlagValue(` — le domaine n'en porte que **3** (4,9 %).

### 1.7 Le bruit récurrent — domaine (58 f.) puis application entière

| Motif | Domaine | Ce que ça révèle |
|---|---:|---|
| `setState(` | **158** | aucun rebuild granulaire — objectif produit n°1 de zcrud entièrement à faire |
| `Colors.` en dur | **256** | FR-26 violé partout ; contre **37** `Theme.of(context)` → ratio 1:7 en faveur du dur |
| `notifyListeners()` | **58** | un contrôleur par écran, notification globale |
| `Navigator.pop(` | **58** | aucun canal de retour normalisé |
| `ListTile(` | **69** | tuiles refaites à la main, zéro composant partagé |
| `Container(` **166** / `Expanded(` **53** / `IconButton(` **51** / `Icon(Icons.` **52** | **322** | mise en page ad hoc |
| `TextEditingController(` | **23** | controllers créés à la main, non mémoïsés |
| `showDatePicker(` **13** + `showTimePicker(` **10** | **23** | 23 sélecteurs date/heure écrits à la main |
| `AlertDialog(` **8** + `showDialog` **25** + `showModalBottomSheet(` **3** | **36** | dialogues et confirmations ad hoc |
| `DateFormat(` | **27** | formatage de date répété, non centralisé |

À l'échelle de l'application, pour dimensionner l'assemblage : **215** `DynamicFormField(`,
**96** `DynamicEditionScreen` dans **51** fichiers, moteur legacy `lib/data_crud/` = **14 980 lignes /
24 fichiers**. Le domaine « tâches » n'y contribue que **7** `DynamicFormField(` et **2**
`DynamicEditionScreen` — il est donc **presque intact**, et c'est ce qui le rend coûteux à porter.
## 2. Ce que le domaine SAIT FAIRE (termes d'utilisateur)

**Tâches quotidiennes** (`daily_tasks_page.dart`, 1 101 l.) — voir **jour par jour** (barre de
7 jours, `weekdays_widget.dart`) ce qui est prévu : examens à venir et cartes à réviser ; compter ce
qui reste (`count == 0` → `EmptyTasksWidget`, `:560-637`) ; **grouper les révisions par dossier puis
par date** (`FolderRepetitionFlashcardsWidget`, `:821-899`) et lancer la révision d'un dossier ;
créer un examen à la date choisie si le droit `ExamModel<année>` l'autorise (`:53-58`) ; quatre
raccourcis (`:900-984`) — ⚠️ **trois sur quatre sont inertes** (`enabled: false, onTap: () {}`,
`:911-934`), seul « Comprendre un sujet » ouvre la Découverte.

**Espace de travail — tâches** (`tasks_screen.dart` 816 l. + `task_edition_screen.dart` 589 l.) —
**plusieurs listes** en onglets : créer, renommer, supprimer (avec suppression en lot des tâches),
vider les tâches terminées ; une liste peut être **verrouillée** et **partagée** (`members`,
`creatorId` — le champ `members` est **entièrement commenté**, `tasks_screen.dart:454-465`) ;
cocher/décocher (`TaskPrefixIcon`, `:3-35`), **réordonner par glisser** (`position`), **filtrer par
texte** ; une tâche porte titre, **notes riches**, **échéance** (`task_due_date_picker.dart`, 192 l. :
aujourd'hui / demain / semaine prochaine / date libre), **rappel** (`task_reminder_picker.dart`,
170 l.), **priorité**, **sous-étapes** (`parent`/`subTasks`), **répétition**.

**Espace de travail — agenda** (`agenda_screen.dart` 737 l., `event_editon_screen.dart` 1 308 l.,
`appointment_editor.dart` 7 858 l.) — voir un **calendrier** (`SfCalendar`) ; créer/éditer un
**événement** : titre, tout-le-jour, début/fin, **fuseau horaire**, **lieu** (Google Maps),
**participants**, **rappels multiples** (`event_reminders_widget.dart`, 327 l.), **couleur**,
**description riche**, **récurrence complète** ; supprimer ou modifier **une occurrence ou toute la
série** (`_DeleteDialog`, `_EditDialog`).

**Découverte** (3 729 l.) — poser une question ou choisir une **suggestion**, obtenir une
**explication de l'IA en flux** (token par token) avec **sujets connexes** ; reprendre une
explication : la **résumer**, l'**approfondir**, la **réexpliquer dans un style**, la **régénérer** ;
**écouter** : lecture vocale (`readAudio`, `:526`) et **podcast téléchargeable** (`playPodcast`,
`generateChatbotMessagePodcast`, `readPodcast`, ~300 l. via `just_audio(_background)`) ; **régler la
génération** avant d'envoyer : raisonnement à 6 niveaux (`toggleThinking`, 0-5), recherche web +
scraping, nombre de résultats, budget de jetons de réflexion, résumé et son type, **expert IA**,
**niveau IFFD**, fournisseur TTS, **routeur/modèle** ; **restreindre à un corpus** (6 codes
juridiques) ; **sélectionner des documents** de l'arborescence
(`ChatBotDocumentsSelectionController`, `:39-155`) puis **résumer** un document entier, des **pages
précises** ou plusieurs documents, **créer des flashcards en lot** (`createLargeFalshcards`, `:2159`) ;
**générer des suggestions depuis l'historique** et **résumer une conversation**.

---

## 3. Ce qui est DÉJÀ branché sur zcrud

IFFD consomme zcrud **`ref: v3.21.0`** (`pubspec.yaml:308`) — la version courante du socle.
**209 sites d'import `package:zcrud_*`** dans `lib/`, répartis sur **22 paquets**
(top : `zcrud_core` 67, `zcrud_chat_kernel` 19, `zcrud_study` 17, `zcrud_screen` 16, `zcrud_chat` 15).

**Dans le domaine étudié, le branchement est quasi nul : 2 sites sur 209 (0,96 %)** —
`discovry_page_controller.dart:7` (`ZChatRouteSession`, `zcrud_chat`) et `:8-9`
(`ZAllowAllChatRouteGate`, `zcrud_chat_kernel`). C'est tout : la session de route
(`attachRouteCatalog`, `:645-656`) résout le routeur choisi via `iffdRouteCatalog(routers)`
(`lib/ai_assistant/zcrud/notebook_route_catalog_iffd.dart`, 106 l.). **Aucun formulaire, aucune
liste, aucun lecteur, aucun composer du socle n'est utilisé ici.**

### Écrans à jumeau porté (`*_zcrud_*.dart`) — 62 fichiers dans l'app, **2** dans le domaine

| Jumeau | L. | Drapeau (`z_qa_flags.dart`) | Défaut | Famille |
|---|---:|---|---|---|
| `workflow/screens/zcrud/task_list_zcrud_edition.dart` | 117 | `taskList` (`:852`) | **legacy** (`kTaskListEditionUseZcrudDefault = false`) | comportement |
| `workflow/screens/zcrud/workflow_notes_zcrud_edition.dart` | 214 | `workflowNotes` (`:883`) | legacy | **données** (`changesData: true`) |

Le registre de QA porte **53 bascules** (`grep -c 'ZQaFlag(' z_qa_flags.dart` → 53) ; le domaine
« tâches/découverte » n'en a que **2** (3,8 %). ⚠️ **Aucune bascule ne couvre la Découverte
elle-même** : le seul flag qui l'effleure est `aiExplanationRichReader` (`:822`), qui porte le
**rendu du texte** d'une explication (partagé avec « Explain AI »), pas la Découverte comme écran.
`discovry_ai_page.dart:53-55` le lit par `ref.watch(aiExplanationRichReaderUseZcrudProvider)`.

**Grep négatif n°1** : `grep -rn "kIffdCorpusCatalog|notebook_settings_iffd|ZChatCorpusOption|
ZChatSettings" lib/src/presentation/features/discovery lib/src/presentation/features/tasks
lib/workflow` → **RC=1, aucune occurrence**. Le catalogue `ZChatCorpusOption` **existe déjà côté
hôte** (`notebook_settings_iffd.dart:55-61`, six clés ; table `'enableCDNTogo' → 'cdnTogo'` à `:76`)
— **mais uniquement pour le Notebook**. La Découverte garde ses six booléens à la main.
**Grep négatif n°2** : `find lib/src/presentation/features/tasks
lib/src/presentation/features/discovery -name '*zcrud*'` → **aucun résultat** : aucun jumeau porté
sous le périmètre annoncé.

### Infrastructure zcrud déjà en place chez l'hôte (réutilisable telle quelle)

`lib/src/presentation/shared/zcrud/` — **14 fichiers, 3 234 lignes** : registre de champs
(`z_iffd_field_registry.dart`, 461 l. ; 2 familles enregistrées : `phoneNumber` `:188`,
`kIffdBooleanKind` `:199`), thème de formulaire (281 l.), palette (225 l.), codec rich-text (193 l.),
matrice ACL (262 l.), passerelle de drapeaux (86 l.), registre de QA (985 l.).
`IffdZcrudScope` est monté **globalement** au `builder` de l'app (`lib/main.dart:270`).

---

## 4. Widgets maison qui refont ce que le socle fait déjà

| Widget / bloc maison | Chemin | Lignes | Équivalent socle v3.21.0 (vérifié sur disque) |
|---|---|---:|---|
| `_showTaskListEditionScreen` inline | `workflow/screens/tasks_screen.dart:334-500` | ~166 | `presentFormEdition` (`zcrud_screen`) — **déjà porté**, sous drapeau |
| Éditeur riche des notes | `workflow/screens/task_edition_screen.dart:440-500` | ~60 | `zcrud_markdown` — **déjà porté**, sous drapeau |
| `buildConfirmDialog` (helper maison) | 20 fichiers, **38 sites** | — | `ZConfirmDialog` + `ZConfirmTone` (`zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart`, `.../domain/z_confirm_tone.dart`) |
| `EmptyTasksWidget` | `daily_tasks_page.dart:560-637` | 78 | `ZEmptyState` / `ZLoadingState` / `ZErrorState` / `ZContentStateView` (`zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:31,75,127,180`) |
| `TaskDueDatePicker` | `workflow/components/task_due_date_picker.dart` | 192 | `ZDateField` (`zcrud_core/.../families/z_date_field_widget.dart`) + `ZDateDisplayFormatter` (port) |
| `TaskReminderPicker` | `workflow/components/task_reminder_picker.dart` | 170 | `ZReminderRecurrence` (`zcrud_exam/lib/src/domain/z_reminder_recurrence.dart`, 199 l.) + `ZExamRemindersSection` (`zcrud_study`, 178 l.) — **modèle proche, pas identique** |
| `EventRemindersWidget` | `workflow/components/event_reminders_widget.dart` | 327 | idem ci-dessus (rappels par décalage) |
| `RecurrencePicker` + `_CustomRule` | `recurrence_picker.dart` + `appointment_editor.dart:6856-7858` | ~2 900 | ⚠️ **rien au socle** : `grep -rlF ZRecurrence packages/*/lib` → **0** ; `grep -rlF recurrence packages/*/lib` → 2 fichiers, tous deux `ZReminderRecurrence` (rappels d'examen, pas règle RRULE) |
| `IsReadOnlyWidget` | `workflow/components/is_read_only.dart` | 92 | famille `boolean` du socle + `kIffdBooleanKind` déjà enregistré |
| `ColorSelector` | `workflow/components/color_selector.dart` | 81 | *(non recherché — hors budget)* |
| 6 bascules de corpus + `toolsCount` | `discovry_page_controller.dart:858-936` | ~80 | `ZChatCorpusOption` / `ZChatCorpusSelector` / `ZChatCorpusScope` (`zcrud_chat_kernel/.../ai/z_chat_corpus_scope.dart:61,140`) — **déjà déclarés par l'hôte pour le Notebook** |
| Barre d'outils du composer | `discovry_search_composer.dart:246-330…` | 483 | `ZChatComposerChrome` / `ZChatComposerSubmitPolicy` (`zcrud_chat`), `ZChatToolEntry` + `ZChatToolProminence`/`Surface`/`HiddenReason` (`zcrud_chat_kernel/.../tools/z_chat_tool_entry.dart:32,62,74`) |
| Feuille de réglages IA (dispersée dans le contrôleur) | `discovry_page_controller.dart:836-1000` | ~165 | `ZChatSettingsSheet` + `ZChatSettingsController`/`Section`/`Label` (17 fichiers du socle) |
| 29 emballages `callApi` | `iffd_ai_repository_impl.dart` | 1 377 | `ZChatRouteCatalogPort` / `ZChatRouteCatalogSource` / `ZChatRouteCatalogShape.suffixPairs` (`zcrud_chat_kernel/.../route/`) + `ZChatGenerationRequest` — **le motif est déjà celui de `notebook_route_catalog_iffd.dart`** |
| `ZChatArtifact` / transformations | `transformAssistantResponse` + `ChatbotMessageTransformer` | ~100 | `ZChatArtifact` (16 fichiers socle) — cf. CR-IFFD-84 (déjà traitée) |

---

## 5. Écrans et dialogues

**7 pages routées** (`@RoutePage`). Les six coquilles mineures sont omises du tableau :
`weekdays_widget.dart` (93), `assistant_page.dart` (26, routé `:11`), `discovry_search_results.dart`
(84), `discovry_search_bar.dart` (46), `workspace_page.dart` (38, routé `:3`),
`time_management_page.dart` (**1 ligne**).

| Chemin | Lignes | Routé | Rôle | Ce qu'il porte |
|---|---:|:-:|---|---|
| `features/tasks/pages/daily_tasks_page.dart` | 1 101 | ✅ `:38` | Tâches du jour | 5 `StreamBuilder` imbriqués, 7 classes, 4 raccourcis (3 inertes), `ChatbotMixin` |
| `features/tasks/controllers/time_manager_controller.dart` | 21 | — | Contrôleur | **vide** (`initListeners(){}`) — 3 dépôts, aucune logique ; `late final timeManagerInstance` **global** |
| `features/discovery/pages/discovry_page.dart` | 207 | ✅ `:16` | Découverte | `ConsumerWidget with DiscovrySearchBar` |
| `features/discovery/pages/discovry_ai_page.dart` | 464 | ✅ `:23` | Fil IA | lit `aiExplanationRichReaderUseZcrudProvider` (`:53`), nettoie le flux par 6 `RegExp` |
| `features/discovery/widgets/discovry_search_composer.dart` | 483 | — | Composer | bascules outils, popup routeur, popup expert |
| `features/discovery/controllers/discovry_page_controller.dart` | **2 412** | — | **Contrôleur-dieu** | 2 classes + 1 modèle ; **102 membres de premier niveau** ; audio, TTS, podcast, IA, corpus, réglages |
| `workflow/screens/tasks_screen.dart` | 816 | ✅ `:79` | Listes de tâches | 4 classes, 2 `showModalBottomSheet` (menus gauche/droite), 3 `buildConfirmDialog` |
| `workflow/screens/task_edition_screen.dart` | 589 | — | Édition d'une tâche | sous-étapes, échéance, rappel, notes riches (drapeau `workflowNotes`) |
| `workflow/screens/agenda_screen.dart` | 737 | ✅ `:22` | Agenda | `SfCalendar` |
| `workflow/screens/event_editon_screen.dart` | 1 308 | — | Édition d'un événement | 3 `showDialog`, notes riches (même drapeau) |
| `workflow/screens/appointment_editor.dart` | **7 858** | — | 3 éditeurs de RDV + 4 dialogues | popup / web / mobile ; suppression et modification de série ; règle de récurrence |

**Dialogues** du domaine : `AlertDialog(` **8**, `showDialog` **25**, `showModalBottomSheet(` **3**,
`buildConfirmDialog` **4** (sur 38 dans l'app, 20 fichiers). Aucun n'utilise `ZConfirmDialog`.

**Localisation** : `WorkflowLocalizations` déclare **41 libellés** (`l10n/messages/abstract.dart`)
et **une seule traduction réelle**, `fr.dart` (413 l.) ; les **8 autres locales** font **4 lignes
chacune** et déclarent `class En extends Fr` — *l'anglais est du français*. Face à ces 41 libellés,
le domaine porte **68 littéraux `Text("…")` en dur** et **256 `Colors.*`**.

**RTL (AD-13)**, **71 sites** : `EdgeInsets.only(left:` **42**, `Alignment.centerRight` **10**,
`TextAlign.left` **8**, `TextAlign.right` **5**, `Alignment.centerLeft` **4**,
`EdgeInsets.only(right:` **2**. Grep négatif : `Positioned(left:` → **0**, `ListView(children` → **0**.

---

## 6. Modèles et persistance

**Entités** (toutes sous `lib/workflow/models/`, toutes `part of '../workspace.dart'`) :
`TaskList` (`task.dart:14-123`), `Task` (`task.dart:124-584`), `Event` (`event.dart:5-500`),
`Appointment` (403 l.), `TimeSlice` (104 l.), `Note` (81 l.). `Task` **étend `google_api.Task`**
et `Event` **étend `google_api.Event`** (`lib/src/core/services/google/google_api.dart`, importé
`as google_api hide Colors`, `workspace.dart:31`) : le schéma Google Calendar/Tasks fuit dans le
domaine (`EventAttendee`, `EventReminder`, `TaskLinks`). Toutes implémentent `DynamicModel` (79 l.).

**Sérialisation** : **manuelle**, `toMap()`/`fromMap()` écrits à la main — `Task.toMap` liste
**26 clés** (`task.dart:254-285`). Aucun codegen (`grep -c reflectable pubspec.yaml` → **0** ;
`find lib/workflow -name '*.g.dart'` → **0**). Le dispatch de type est une **table
`Map<Type, dynamic Function()>` de 40 entrées** (`utils/functions/data_functions.dart:337-400`), où
le domaine occupe 5 lignes (`:383-387`). Conventions : clés **camelCase** (`isAllDay`, `listId`,
`startTimeZone`) — **et non snake_case** ; dates en **millisecondes epoch stringifiées** ; couleur en
`toARGB32().toString()`.

**Dépôts** : port `CrudRepository<T>` (`domain/repositories/datacrud_repository.dart`, 93 l.,
**21 opérations** dont `streamAll`, `streamByIds`, `batchDelete`, `smartDelete`, `softDelete`,
`restore`, `setMap`), spécialisé par `TasksRepository` / `TasksListsRepository` / `EventsRepository`
(109 l. à eux trois, l'essentiel en `extension` portant les requêtes métier). Implémentation unique :
`FirebaseCrudRepositoryImpl<T extends DynamicModel>` (499 l.) — **`cloud_firestore` fuit jusque dans
l'écran** (`daily_tasks_page.dart:2`, `Timestamp` en paramètre public `:41`). Nom de collection par
table `FIREBASE_COLLECTION_NAMES[T]`, repli `T.toString()` (`databases_functions.dart:8-11`).
**Aucun cache local, aucun offline-first** ici.

**Erreurs** : `DataState<T, Exception>` maison (`utils/resources/data_state.dart` — `DataSuccess` /
`DataFailed`), **pas** `Either<ZFailure, T>`. Les flux (`streamAll`, `streamByIds`) sont **nus** —
donc **aucun canal d'erreur** côté écran : sur `daily_tasks_page.dart`, `grep -cF hasError` → **0**,
`grep -cF ConnectionState` → **0**.

---

## 7. Ce qui est PARTICULIER à IFFD

1. **Les 6 corpus juridiques** (Code du GATT, TEC CEDEAO, Codes des douanes CEDEAO / Togo / Niger,
   CGI Togo) — le métier même de l'institut. Le socle n'a pas à les connaître ; `ZChatCorpusOption`
   les accueille **déjà** comme déclaration d'hôte (`notebook_settings_iffd.dart:55-61`).
2. **`IffdAiRouterModel`** (`domain/models/ai/ai_models.dart`, 581 l.) : un champ de modèle **par
   intention** (`summaryModel`, `aiModel`…). C'est exactement la forme
   `ZChatRouteCatalogShape.suffixPairs` que l'hôte décode déjà (`notebook_route_catalog_iffd.dart:42`)
   — donc **généralisable**, contrairement aux corpus.
3. **`NiveauIFFD` / `FiliereEtCycleIFFD` / `CycleIFFD` / `AuditeurIffd`** : le contexte pédagogique est
   injecté dans **chaque** prompt (`userPresentation` construit avec accord de genre,
   `discovry_ai_page.dart:74-75`). Spécifique.
4. **Droits par chaîne composée** : `canCreateOrUpdate("ExamModel$accademicYear")`
   (`daily_tasks_page.dart:56-57`) — la permission est nommée `<Type><année académique>`.
5. **`Task extends google_api.Task` / `Event extends google_api.Event`** : l'espace de travail est
   modelé sur Google Calendar/Tasks (fuseaux, `etag`, `EventAttendee`, `EventReminder`). À traiter
   comme une **frontière**, pas comme une dette.
6. **La règle de récurrence RRULE complète** (~2 900 l.) : **le socle n'a rien d'équivalent** —
   `grep -rlF ZRecurrence packages/*/lib` → **0** ; `grep -rlF recurrence packages/*/lib` → **2**
   fichiers, tous deux `ZReminderRecurrence` (rappels d'examen, pas RRULE). C'est le plus gros manque
   côté zcrud si l'agenda migre, et le plus gros gisement de duplication côté IFFD.
7. **TTS / podcast** (`just_audio` + `just_audio_background`, `discovry_page_controller.dart:309-608`,
   ~300 l.) : écouter une explication en fond, hors application. Équivalent socle non recherché.
8. **`ChatBotDocumentsSelectionController`** (`:39-155`, 117 l.) : cascade année → filière/cycle →
   matière → dossier → sous-dossier → documents. La *cascade* est généralisable ; ses **six niveaux**
   sont l'arborescence IFFD.
