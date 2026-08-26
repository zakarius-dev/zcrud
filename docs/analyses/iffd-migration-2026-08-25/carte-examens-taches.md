# Carte du domaine « Examens, évaluations, tâches, découverte » — IFFD

**Dépôt cartographié** : `/home/zakarius/DEV/iffd` (lecture seule, aucun fichier touché)
**Date du relevé** : 2026-08-25
**Socle consommé au moment du relevé** : zcrud **v3.21.0** (`pubspec.yaml:308`, tag git)

> Toutes les affirmations d'**absence** de ce document portent leur **grep négatif montré**
> (section [§9](#9-preuves-dabsence--les-greps-négatifs)). Tous les chiffres sont mesurés,
> jamais estimés — sauf une mesure explicitement qualifiée d'heuristique (§6.14).

---

## 0. Périmètre retenu

Les cinq chemins de départ fournis par l'orchestrateur ne contiennent que **21 fichiers
et 5 351 lignes** (dont 3 690 pour la seule découverte, déjà complète) — presque uniquement des `*_module.dart` d'une ligne et des providers
Riverpod générés. Le domaine réel vit ailleurs : suivre les dépendances (modèles, dépôts,
dialogues, écrans, librairie `lib/workflow/`) donne **90 fichiers et 30 693 lignes**.

| Sous-domaine | Fichiers | Lignes | Au-delà des chemins de départ |
|---|---:|---:|---|
| **Examens** | 14 | 4 834 | `domain/models/exam_model.dart`, `domain/repositories/exams_repository.dart`, `data/repositories/z_backed_exam_repository.dart`, `presentation/features/administration/{pages,dialogs,widgets}/exam*`, `presentation/features/flashcards/{white_exam_page, white_exam_question_card, test_exam_filter*}` |
| **Évaluations** (outils de valeur en douane) | 19 | 3 716 | `domain/models/valuation/`, `domain/repositories/valuation_tool_model_repository.dart`, `features/corpus/providers/`, `presentation/features/valuation_tools/`, `utils/constants/valuation_tools/` |
| **Tâches / agenda** | 46 | 18 376 | **toute la librairie `lib/workflow/`** (36 fichiers, 16 821 lignes), `domain/repositories/workflow/` |
| **Découverte** | 11 | 3 767 | (les chemins de départ étaient complets ici) |
| **TOTAL** | **90** | **30 693** | |

> ⚠️ **Lecture du mot « évaluations ».** `valuation_tools` d'IFFD ne désigne **pas**
> l'évaluation de l'apprenant : ce sont les **outils de la valeur en douane** (articles du
> GATT, avis consultatifs, décisions, commentaires, notes explicatives, études de cas…).
> L'évaluation de l'apprenant vit dans les **examens blancs** (`white_exam_page.dart`).
> J'inclus les deux, séparément, et je signale que `valuation_tools` recoupe le domaine
> « corpus » : sa route est **redirigée vers le tableau de bord** depuis que ce corpus est
> passé à `lex_douane` (`lib/src/config/router/app_router.dart:236`).

**Vérification que le périmètre existe bien sur disque** : les 90 chemins ont été relus un
par un ; aucun `MISSING`.

---

## 1. Ce que le domaine SAIT FAIRE

### 1.1 Examens (planification)

1. **Planifier un examen** pour une année académique : titre, dossier de révision associé,
   date d'échéance, activation des rappels (`exames_dialogs.dart:29`).
2. **Dériver automatiquement le titre** de l'examen du dossier choisi
   (« Examen: *titre du dossier* ») — un champ qui en dérive un autre
   (`exames_dialogs.dart:129-143`, port zcrud `exam_zcrud_edition.dart:308`).
3. **Voir ses examens groupés** en « à venir » / « passés », triés par date, en grille
   responsive, les passés barrés et estompés (`exams_page.dart:26`, `:280`).
4. **Ouvrir le dossier de révision** d'un examen depuis sa tuile (`exams_page.dart:294`).
5. **Modifier / supprimer** un examen depuis un menu d'actions, avec confirmation
   (`exam_actions_dialog_widget.dart:38`, `:59`).
6. **Voir ses examens du jour** dans le tableau de bord quotidien, jour par jour sur la
   semaine courante (`daily_tasks_page.dart:371`).
7. **Recevoir des rappels** par jours de la semaine + heure (`ExamModel.reminderDays`,
   `reminderTime`, `exam_model.dart:19-21`).
8. **Créer un examen depuis un état vide** (« Ajoute une date d'examen pour bénéficier de
   tâches d'apprentissage optimisées », `exams_page.dart:31`).
9. La **création d'examen est soumise à permission** par année académique
   (`canCreateOrUpdate("ExamModel$accademicYear")`, `exams_page.dart:74`).

### 1.2 Examens blancs (évaluation de l'apprenant)

10. **Paramétrer un test** : nombre de questions (1..30), types de questions, niveaux de
    maîtrise, balises, documents, notes (`test_exam_filter_screen.dart:40-127`).
11. **Passer un examen blanc chronométré** sur un dossier, avec compteur visible
    (`white_exam_page.dart:76`, `:107`).
12. **Répondre à quatre familles de questions** : QCM, Vrai/Faux, question ouverte, cas
    pratique (`flashcard_model.dart:12`, `white_exam_question_card.dart:648-857`).
13. **Marquer une question** pour y revenir (`white_exam_page.dart:46`).
14. **Soumettre partiellement** (« Soumettre Incomplet ») ou totalement, avec confirmation
    (`white_exam_page.dart:334`, `:351`, `:408`).
15. **Faire corriger les réponses ouvertes par l'IA** et recevoir une note de qualité + un
    message d'apprentissage par question (`white_exam_page.dart:602`,
    `white_exam_question_card.dart:315`, `:858`).
16. **Voir un bilan** : réponses correctes, temps total, moyenne par question
    (`white_exam_page.dart:695-709`).

### 1.3 Outils de valeur en douane (« évaluations »)

17. **Consulter dix corpus juridiques** : articles du GATT, articles de l'Accord, annexes,
    notes interprétatives, décisions, avis consultatifs, commentaires, notes explicatives,
    études de cas, études (`valuation_tools.dart:12`,
    `valuation_tool_model_actions_dialog_widget.dart:658-817`).
18. **Créer / modifier / copier / supprimer** un texte : numéro d'identification, titre,
    description, contenu markdown riche (`valuation_tool_model_dialogs.dart:64-92`).
19. **Générer des flashcards** depuis un texte de corpus
    (`valuation_tool_model_actions_dialog_widget.dart:92`).
20. **Générer une carte mentale** depuis un texte (`:155`).
21. **Résumer** un texte par l'IA (`:164`, `folder_details_controller.dart:284`).
22. Le corpus est **pré-embarqué en constantes** (`utils/constants/valuation_tools/`,
    10 fichiers, 992 lignes) autant que servi depuis Firestore.

### 1.4 Tâches, agenda, espace de travail

23. **Tenir plusieurs listes de tâches**, en onglets, partageables (`members`),
    avec une « Liste par défaut » implicite (`tasks_screen.dart:129`).
24. **Créer, cocher, prioriser, réordonner** une tâche par glisser-déposer
    (`tasks_screen.dart:307`, `TaskPrefixIcon`/`TaskSuffixIcon`, `:3`, `:36`).
25. **Éditer une tâche en profondeur** : titre, notes, échéance, rappel, récurrence,
    sous-tâches réordonnables (`task_edition_screen.dart:10`, `:254`).
26. **Choisir une échéance** par raccourci (aujourd'hui / demain / semaine prochaine /
    mois prochain / personnalisée) (`task.dart:6`, `task_due_date_picker.dart`).
27. **Choisir un rappel** (dans la journée / demain / semaine prochaine / personnalisé)
    (`task.dart:10`, `task_reminder_picker.dart`).
28. **Répéter** une tâche (quotidien, jours ouvrés, hebdo, mensuel, annuel, personnalisé)
    (`task.dart:12`).
29. **Voir un agenda** en vue jour / semaine / semaine de travail / mois / planning et
    leurs variantes chronologiques (`agenda_screen.dart:23`, `l10n.dart:92-107`).
30. **Superposer dans le même agenda** les tâches, les événements, les **examens** et les
    rappels Google Agenda (`source.dart:3-40`, `AppointmentKind`, `appointment.dart:5`).
31. **Déplacer / redimensionner un rendez-vous** dans l'agenda et le voir persisté
    (`agenda_screen.dart:345-437`).
32. **Créer et éditer un événement complet** : lieu (Google Maps), participants, pièces
    jointes, visioconférence, fuseau horaire, journée entière, lecture seule, rappels
    multiples, récurrence (`event_editon_screen.dart:55`, `event.dart`,
    `event_location_widget.dart`, `event_reminders_widget.dart`).
33. **Composer une règle de récurrence** (quotidienne / hebdo / mensuelle / annuelle,
    fin jamais / à une date / après N occurrences) (`recurrence_picker.dart:801-1721`).
34. **Modifier ou supprimer** une occurrence *ou* toute la série (`CrudRecurrence`,
    `event_editon_screen.dart:25`, `:1076`).
35. **Rechercher** dans les rendez-vous de l'agenda (`source.dart:43`).
36. **Naviguer semaine par semaine** dans le tableau de bord quotidien
    (`weekdays_widget.dart:13`, `daily_tasks_page.dart:135`).
37. **Voir les révisions de flashcards dues** du jour, par dossier
    (`daily_tasks_page.dart:821` `FolderRepetitionFlashcardsWidget`).
38. **Actions rapides** depuis le tableau de bord — dont **une seule est active**
    (« Comprendre un sujet ») ; les trois autres sont câblées `enabled: false`
    (`daily_tasks_page.dart:912-935`).

### 1.5 Découverte / assistant IA

39. **Poser une question libre** et recevoir une explication en markdown **en flux**
    (`discovry_search_composer.dart:161`, `discovry_page_controller.dart:1278`).
40. **Empiler plusieurs explications** dans un fil, les retirer, les remplacer, tout effacer
    (`discovry_page_controller.dart:661-737`).
41. **Suggestions de recherche** avec surlignage de la partie saisie
    (`discovry_search_results.dart:12`).
42. **Sujets connexes** proposés après une explication, et suggestions dérivées de
    l'historique (`discovry_page_controller.dart:1334`, `:1373`, `:1399`).
43. **Choisir le modèle / routeur IA** et son niveau d'effort (`discovry_search_composer.dart:197`).
44. **Choisir un expert IA** et hériter de ses réglages par défaut (niveau, documents)
    (`discovry_page_controller.dart:786`).
45. **Activer la recherche web**, le scraping, borner le nombre de résultats
    (`:858`, `:868`, `:886`).
46. **Activer la « réflexion »** et régler son effort (`:939`, `:950`).
47. **Restreindre le contexte à des corpus juridiques** : CDN Togo, CDN Niger, CDC CEDEAO,
    CGI Togo, TEC CEDEAO, Code du GATT (`:896-921`).
48. **Choisir un niveau IFFD** de réponse (`:873`).
49. **Résumer** : un document, plusieurs documents, des pages choisies d'un document, ou
    l'explication en cours ; avec type de résumé et instruction personnalisée
    (`:1756`, `:1956`, `:2087`, `:2231`, `:956`, `:967`, `:972`).
50. **Approfondir** une explication, ou la **rejouer dans un autre style**
    (`:2281`, `:2331`).
51. **Générer des flashcards en volume** depuis l'explication (`:2159`).
52. **Écouter la réponse** : synthèse vocale et **podcast**, avec cache disque local et
    lecture en arrière-plan (`:309`, `:368`, `:426`, `:458`, `:491`, `:526`).
53. **Sélectionner des documents** de contexte, par année / filière / matière / dossier
    (`ChatBotDocumentsSelectionController`, `:39`).
54. **Régénérer** une explication, **arrêter** une génération en cours (`:1720`, `:1220`).
55. **Résumer la conversation** au fil de l'eau (`:1433`).

---

## 2. Les écrans

### 2.1 Examens

| Écran / dialogue | Chemin | Lignes | Rôle | Formulaire | Liste | Nav. | Rendu riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| `ExamsPage` | `lib/src/presentation/features/administration/pages/exams_page.dart` | 333 | Liste groupée « à venir / passés », grille responsive | — | ✅ grille | ✅ vers dossier | — |
| `showExamEditonDialog` (legacy) | `lib/src/presentation/features/administration/dialogs/exames_dialogs.dart` | 282 | Formulaire d'examen, moteur `DynamicEditionScreen` + aiguillage de bascule | ✅ 4 champs | — | — | — |
| `ExamZcrudEditionScreen` | `lib/src/presentation/features/administration/dialogs/exam_zcrud_edition.dart` | 513 | **Le même formulaire**, moteur zcrud `DynamicEdition` | ✅ 4 champs | — | — | — |
| `ExamActionsDialogWidget` | `lib/src/presentation/features/administration/widgets/exam_actions_dialog_widget.dart` | 76 | Menu Modifier / Supprimer | — | — | — | — |
| `WhiteExamPage` | `lib/src/presentation/features/flashcards/pages/white_exam_page.dart` | 779 | Examen blanc chronométré, soumission, bilan | ✅ réponses | ✅ questions | — | ✅ markdown |
| `WhiteExamQuestionCard` | `lib/src/presentation/features/flashcards/widgets/white_exam_question_card.dart` | 1 066 | Carte de question (QCM / V-F / texte) + retour d'apprentissage IA | ✅ | — | — | ✅ markdown |
| `TestExamFilterScreen` (legacy) | `lib/src/presentation/features/flashcards/widgets/test_exam_filter_screen.dart` | 134 | Filtres du test | ✅ 6 champs | — | — | — |
| `TestExamFilterZcrudScreen` | `lib/src/presentation/features/flashcards/widgets/test_exam_filter_zcrud_screen.dart` | 376 | **Les mêmes filtres**, moteur zcrud | ✅ 6 champs | — | — | — |

### 2.2 Évaluations (outils de valeur en douane)

| Écran / dialogue | Chemin | Lignes | Rôle | Formulaire | Liste | Nav. | Rendu riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| `showValationToolEditonDialog` (legacy) | `lib/src/presentation/features/valuation_tools/dialogs/valuation_tool_model_dialogs.dart` | 155 | Formulaire d'outil + aiguillage de bascule | ✅ 4 champs | — | — | ✅ `inlineMarkdown` |
| `ValuationToolZcrudEditionScreen` | `lib/src/presentation/features/valuation_tools/dialogs/valuation_tool_model_zcrud_edition.dart` | 348 | **Le même formulaire**, moteur zcrud | ✅ 4 champs | — | — | ✅ markdown |
| `ValuationToolModelActionsDialogWidget` + `ValuationToolsGridView<T>` | `lib/src/presentation/features/valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 823 | Menu d'actions (flashcards / carte mentale / modifier / supprimer) **et** dix grilles de corpus | — | ✅ ×10 | — | — |

### 2.3 Tâches / agenda

| Écran | Chemin | Lignes | Rôle | Formulaire | Liste | Nav. | Rendu riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| `DailyTasksPage` | `lib/src/presentation/features/tasks/pages/daily_tasks_page.dart` | 1 101 | Tableau de bord du jour : bandeau semaine, examens du jour, révisions dues, actions rapides | — | ✅ sections | ✅ | — |
| `WeekdaysWidget` | `lib/src/presentation/features/tasks/widgets/weekdays_widget.dart` | 93 | Navigation de semaine | — | — | ✅ | — |
| `WorkspacePage` (route `/workspace`) | `lib/workflow/screens/workspace_page.dart` | 38 | Coquille à onglets Agenda / Tâches | — | — | ✅ | — |
| `CalenderScreen` (route `/workspace/calender`) | `lib/workflow/screens/agenda_screen.dart` | 737 | Agenda Syncfusion, 9 vues, glisser-déposer, recherche | — | ✅ agenda | ✅ | — |
| `TasksScreen` (route `/workspace/tasks`) | `lib/workflow/screens/tasks_screen.dart` | 749 | Listes de tâches en onglets, réordonnancement | ✅ saisie rapide | ✅ | ✅ onglets | — |
| `TaskEditionScreen` | `lib/workflow/screens/task_edition_screen.dart` | 524 | Fiche tâche + sous-tâches | ✅ `FormBuilder` | ✅ sous-tâches | — | — |
| `AppointmentEditionScreen` | `lib/workflow/screens/event_editon_screen.dart` | 1 192 | **L'éditeur d'événement réellement monté** | ✅ | — | — | ✅ `flutter_html` |
| `PopUpAppointmentEditor` / `AppointmentEditorWeb` / `AppointmentEditor` | `lib/workflow/screens/appointment_editor.dart` | 7 858 | Trois éditeurs de rendez-vous **alternatifs**, plus dialogues et sélecteurs — voir §7 | ✅ ×3 | — | — | — |
| `RecurrencePicker` | `lib/workflow/components/recurrence_picker.dart` | 1 721 | Règle de récurrence | ✅ | — | — | — |
| Composants d'édition d'événement | `lib/workflow/components/{color_selector, event_location_widget, event_reminders_widget, is_all_day_widget, is_read_only, task_due_date_picker, task_reminder_picker}.dart` | 1 026 | Champs spécialisés | ✅ | — | — | — |

### 2.4 Découverte

| Écran | Chemin | Lignes | Rôle | Formulaire | Liste | Nav. | Rendu riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| `DiscovryPage` (route `/dashboard/assistant`) | `lib/src/presentation/features/discovery/pages/discovry_page.dart` | 207 | Accueil « DiscovryAI » : vide animé ou fil + composeur | — | — | ✅ | — |
| `DiscovryAiPage` | `lib/src/presentation/features/discovery/pages/discovry_ai_page.dart` | 425 | Fil des explications, rendu markdown, Syncfusion `assist_view` | — | ✅ fil | — | ✅ |
| `DiscovrySearchComposer` | `lib/src/presentation/features/discovery/widgets/discovry_search_composer.dart` | 483 | Composeur : saisie multi-ligne, modèle IA, experts, documents, options | ✅ | — | — | — |
| `DiscovrySearchResults` | `lib/src/presentation/features/discovery/widgets/discovry_search_results.dart` | 84 | Suggestions surlignées | — | ✅ | — | — |
| `DiscovrySearchBarWidget` + mixin | `lib/src/presentation/features/discovery/widgets/discovry_search_bar.dart` | 46 | Barre de recherche + accès aux contrôleurs | ✅ | — | — | — |
| `AssistantPage` | `lib/src/presentation/features/discovery/pages/assistant_page.dart` | 26 | Montage du `ChatbotScreen` | — | — | ✅ | — |
| `DiscovryPageController` *(pas un écran)* | `lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart` | **2 412** | 84 méthodes publiques, 57 `notifyListeners()` | — | — | — | — |

**Routes déclarées** (`lib/src/config/router/app_router.dart`) : `/dashboard/assistant`
(`DiscovryPageRoute:196`), `/workspace` (`:209`), `/workspace/calender` (`:219`),
`/workspace/tasks` (`:225`).
**Routes commentées** : `DailyTasksPageRoute` (`:134`), `ExamsPageRoute` (`:142`) — ces deux
pages sont montées **comme widgets** dans `home_page.dart:30-31` et `dashbord_page.dart:285-286`.
**Route supprimée** : `/valuation-tools` → redirection vers `/dashboard` (`:236`,
commentaire : « déplacées vers lex_douane »).

---

## 3. Modèles de domaine et persistance

### 3.1 Les entités

| Entité | Chemin | Lignes | Champs notables | Sérialisation |
|---|---|---:|---|---|
| `ExamModel` | `lib/src/domain/models/exam_model.dart` | 168 | `accademicYear`, `title`, `userId`, `folderId`, `date: Timestamp?`, `enableReminder`, `reminderDays: List<WeekDays>`, `reminderTime: TimeOfDay?` | `toMap`/`fromMap` **écrits à la main** |
| `ValuationToolModel` + 10 sous-classes | `lib/src/domain/models/valuation/valuation_tool_model.dart` | 581 | `identifier`, `title`, `description`, `content` | idem, **répétée 11 fois** |
| `TaskList`, `Task` | `lib/workflow/models/task.dart` | 584 | `members`, `readOnly`, `position`, `status`, `priority`, `due`, `remindAt`, `parent` | idem |
| `Event` | `lib/workflow/models/event.dart` | 500 | attributs Google Calendar complets | idem |
| `Appointment extends sf.Appointment` | `lib/workflow/models/appointment.dart` | 403 | union tâche+événement+examen, `AppointmentKind` | idem |
| `TimeSlice` | `lib/workflow/models/time_slice.dart` | 104 | créneau horaire | idem |
| `NoteBook`, `Note` | `lib/workflow/models/note.dart` | 81 | — | **code mort** (§7) |

**Aucun de ces modèles n'est annoté `@ZcrudModel`** — grep négatif §9.4. `build.yaml` ne
déclare que `freezed`, `riverpod_generator` et `json_serializable`, et
`FIREBASE_COLLECTION_NAMES` est **vide** (`lib/src/utils/constants/databases.dart:3`), si
bien que le nom de collection Firestore est **le nom du type Dart** :
`ExamModel`, `Task`, `TaskList`, `Event`, `ArticleGATT`, `Decision`, …
(`databases_functions.dart:8-10`).

### 3.2 Les dépôts

Contrat unique : `CrudRepository<T>` (`lib/src/domain/repositories/datacrud_repository.dart`,
93 lignes) — 19 méthodes, dont `create`, `mapCreate`, `streamAll`, `streamOne`, `streamByIds`,
`all`, `count`, `asyncCount`, `find`, `batchSet`, `batchUpdate`, `batchDelete`, `update`,
`mapUpdate`, `softDelete`, `delete`, `restore`, plus l'ACL (`objectType`, `crudableObjects`).

Implémentation unique : `FirebaseCrudRepositoryImpl<T>`
(`lib/src/data/repositories/firebase_crud_repository_impl.dart`, 499 lignes), Firestore direct,
`withConverter` branché sur le dispatcher `fromMap<T>` / `toMap<T>`
(`lib/src/utils/functions/data_functions.dart`, 515 lignes — une **table de fabriques par
`Type`**, l'équivalent manuel du registre zcrud).

Dépôts du domaine :

| Dépôt | Déclaration | Implémentation | Ligne |
|---|---|---|---|
| `ExamsRepository` | `domain/repositories/exams_repository.dart:8` | `FirebaseExamsRepositoryImpl` | `firebase_models_repositories_impls.dart:71` |
| `ValuationToolModelRepository<T>` ×10 | `domain/repositories/valuation_tool_model_repository.dart:3` | 10 classes | `firebase_models_repositories_impls.dart:306-434` |
| `TasksRepository` | `domain/repositories/workflow/tasks_repository.dart:5` | `FirebaseTasksRepositoryImpl` | `:250` |
| `TasksListsRepository` | `.../tasks_lists_repository.dart:5` | `FirebaseTasksListsRepositoryImpl` | `:235` |
| `EventsRepository` | `.../events_repository.dart:5` | `FirebaseEventsRepositoryImpl` | `:254` |

Les requêtes métier sont portées par des **extensions** sur le dépôt :
`userExams` / `userExamsInFolder` (`exams_repository.dart:10`, `:44`),
`userTasksLists` (deux homonymes, `tasks_repository.dart:8` et `tasks_lists_repository.dart:8`),
`subTasks` (`tasks_repository.dart:35`), `userEvents` (`events_repository.dart:8`).

### 3.3 Source de données, cache, synchronisation

- **Source unique : Firestore**, en direct, via `cloud_firestore`. `Timestamp` **fuit dans le
  domaine** : `ExamModel.date` est un `Timestamp?` (`exam_model.dart:18`) et
  `exams_repository.dart:22-28` construit ses bornes en `Timestamp.fromDate`.
- **Pas de cache local applicatif**, pas d'orchestrateur de synchronisation : seul le cache
  offline natif de Firestore agit. Grep négatif §9.6.
- **Soft-delete** : `softDelete` / `restore` existent au contrat
  (`datacrud_repository.dart:54`, `:59`).
- **Un second chemin de données existe pour les examens**, derrière un drapeau Riverpod :
  `ZBackedExamRepository` (`lib/src/data/repositories/z_backed_exam_repository.dart`, 912 lignes),
  qui persiste la map canonique de `ZExam` (`package:zcrud_exam`) dans **la même collection
  `ExamModel`** (`:481`), avec les clés hors-entité `ZSyncMeta` (`is_deleted` / `updated_at`).
  Le drapeau `useZcrudExamsRepository` vaut **`false`** par défaut
  (`lib/src/features/exams/providers/exam_providers.dart:18`).

### 3.4 Traitement des erreurs

- Le contrat retourne `DataState<T, Exception>` — hiérarchie maison
  (`lib/src/utils/resources/data_state.dart`, 91 lignes : `DataSuccess`, `DataFailed`,
  `DataNotSet`, `DataCreated`, `DataUpdated`, `DataDeleted`, `DataRestored`, `DataValidated`).
- **Ce résultat n'est inspecté nulle part dans la présentation du domaine.** `DataState`
  n'apparaît dans le périmètre que dans `z_backed_exam_repository.dart` (26 occurrences) ;
  les **49 appels CRUD** de la présentation sont tous en « tire et oublie »
  (`agenda_screen.dart:345-437` : 14 appels d'affilée dont aucun n'est attendu ni testé ;
  `task_edition_screen.dart:191`, `:199`, `:280`, `:460` ; `exames_dialogs.dart:249`, `:252`).
- **Aucun `StreamBuilder` du domaine ne gère la branche d'erreur** : 16 `StreamBuilder`,
  **zéro `snapshot.hasError`** (grep négatif §9.1). Le dépôt lui-même documente que ce motif
  exact a déjà coûté trois séances de diagnostic
  (`lib/src/domain/repositories/folders_repository.dart:112` : « Troisième fois que ce motif
  exact nous coûte une séance (B-39(1), B-45, ceci) »).
- **39 `catch` dans le périmètre, dont 27 silencieux** (`catch (_) {}`), le plus dense étant
  `discovry_page_controller.dart` (17).

---

## 4. Ce qui est DÉJÀ branché sur zcrud

### 4.1 Dépendances déclarées

`pubspec.yaml` déclare **23 paquets `zcrud_*`** en dépendance git, tous épinglés sur le tag
**`v3.21.0`**, plus **24 `dependency_overrides`** (fermeture transitive).
`zcrud_generator` est **absent** (grep négatif §9.4).

Au total, **91 fichiers de `lib/` importent `package:zcrud_*`** (sur ~640 fichiers Dart) —
55 fois `zcrud_core`, 19 `zcrud_chat_kernel`, 17 `zcrud_study`, 15 `zcrud_chat`,
11 `zcrud_flashcard`, 8 `zcrud_study_kernel`, 6 `zcrud_mindmap`, 5 `zcrud_screen`,
5 `zcrud_firestore`, 3 `zcrud_exam`…

### 4.2 Dans MON périmètre : 7 imports, dans 5 fichiers

| Fichier | Ligne | Ce qui est consommé |
|---|---:|---|
| `data/repositories/z_backed_exam_repository.dart` | 91-92 | `ZSyncMeta` (zcrud_core) ; `ZExam`, `ZReminderRecurrence`, `ZReminderTime` (zcrud_exam) |
| `presentation/.../dialogs/exam_zcrud_edition.dart` | 66 | `zcrud_core` complet : `ZFieldSpec`, `ZFormController`, `DynamicEdition`, `ZEditionSubmitController`, `ZRelationSourceRegistry`, `ZTextConfig`, `ZDateConfig`, `ZValidatorSpec` |
| `presentation/.../widgets/test_exam_filter_zcrud_screen.dart` | 52 | idem |
| `presentation/.../dialogs/valuation_tool_model_zcrud_edition.dart` | 75 | idem + codec rich-text |
| `presentation/.../discovery/controllers/discovry_page_controller.dart` | 7-8 | `ZChatRouteSession` (zcrud_chat), `ZAllowAllChatRouteGate` (zcrud_chat_kernel) — branché le 2026-08-23 (`:616`), catalogue de routes construit par `attachRouteCatalog` (`:645`) |

**`lib/workflow/` (36 fichiers, 16 821 lignes) ne contient pas une seule occurrence du mot
`zcrud`** — grep négatif §9.2.

### 4.3 Ce qui est enregistré au registre de widgets

`buildIffdWidgetRegistry()` (`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:78`)
construit **un registre par montage** et y enregistre :

1. `registerZMarkdownFields(...)` (`:101`) avec `IffdRichTextCodec`, `iffdMarkdownStyleSet()`
   et un `ZMarkdownFieldChrome` limité aux couleurs de signature (le reste est devenu défaut
   du socle en v3.21.0, cf. le commentaire `:110-140`) ;
2. `registerZFlashcardEditors(...)` (`:171`) — sélecteur de type, éditeur QCM, vrai/faux,
   libellés français injectés ;
3. `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` (`:188`) ;
4. `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` (`:199`) — le booléen d'IFFD
   sur `FlutterSwitch`, servi **sous le nom du type**, donc appliqué à tous les booléens sans
   qu'aucune `ZFieldSpec` ne le déclare.

`IffdZcrudScope` (`:227`) pose ensuite au `ZcrudScope` : `widgetRegistry`, `theme` mémoïsé par
luminosité, `gradientResolver` (`iffdFieldTintResolver`), `iconResolver`, `colorKeyResolver`,
`relationSourceRegistry`, `subListSeams`, et une `ZAllowAllAcl` par défaut assumée (`:288`).
Le fichier note explicitement qu'**un écran hors scope perd tout cela en silence**
(`exam_zcrud_edition.dart:475-481`).

### 4.4 Le registre des bascules

`lib/src/presentation/shared/zcrud/z_qa_flags.dart` (467 lignes) recense **34 bascules**
(`ZQaFlag`). **Trois** relèvent de mon périmètre :

| id | Écran | Provider | Ligne | Actif dans `main.dart` |
|---|---|---|---:|:-:|
| `exam` | Administration — créer / modifier un examen | `examEditionUseZcrudProvider` | `:373` | ✅ (`main.dart:204`) |
| `valuationTool` | Outils de valeur en douane — le formulaire | `valuationToolEditionUseZcrudProvider` | `:440` | ✅ (`main.dart:205`) |
| `testExamFilter` | Filtres de test / examen | `testExamFilterUseZcrudProvider` | `:255` | ❌ |

Le **chemin de données** examens (`useZcrudExamsRepository`) n'est **pas** dans ce registre et
reste à `false` (`exam_providers.dart:18`).

### 4.5 Ce que le domaine **n'utilise pas** du socle

- Aucun `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` : les **107 `ZFieldSpec` du dépôt** (dont
  14 dans mon périmètre) sont **écrits à la main**, alors qu'ils sont dérivables d'une
  annotation (grep négatif §9.4).
- `zcrud_list` / `DynamicList` : absent du périmètre (grep négatif §9.5).
- `zcrud_screen` (assemblage CRUD complet) : présent au `pubspec` mais **jamais importé dans
  mon périmètre**.
- `ValueListenableBuilder` : **zéro occurrence** dans les 90 fichiers, contre **18
  `ListenableBuilder`** (grep négatif §9.3) — c'est-à-dire zéro rebuild granulaire.

---

## 5. Les widgets maison qui refont ce que zcrud fait

| Widget / mécanique maison | Chemin | Lignes | Équivalent socle |
|---|---|---:|---|
| `DynamicEditionScreen` + `DynamicFormField` (moteur déclaratif legacy) | `lib/data_crud/edition_screen.dart`, `edition_field.dart` | — (hors périmètre : **45 sites** d'usage dans le dépôt ; dans mon périmètre **4 instanciations** — `exames_dialogs.dart:138`, `test_exam_filter_screen.dart:32`, `valuation_tool_model_dialogs.dart:58`, `tasks_screen.dart:431` — et **19 déclarations `DynamicFormField`**) | `DynamicEdition` + `ZFieldSpec` + `ZFormController` |
| `CrudRepository<T>` + `FirebaseCrudRepositoryImpl<T>` + `DataState` | `domain/repositories/datacrud_repository.dart` (93) + `data/repositories/firebase_crud_repository_impl.dart` (499) + `utils/resources/data_state.dart` (91) | 683 | `ZRepository<T>` / `ZLocalStore` / `ZRemoteStore` + `Either<ZFailure,T>` + adapters `zcrud_firestore` |
| `fromMap<T>` / `toMap<T>` : table de fabriques par `Type` | `lib/src/utils/functions/data_functions.dart` | 515 | `ZcrudRegistry` généré |
| `DataRequest<T>` (where / whereIn / or / and / isNull / arrayContains / itemFilter) | `domain/models/requests/data_request.dart` | — | `DataRequest` neutre du socle |
| `StatelessItemDialogWidget<T>` + **12 sous-classes** de dialogues d'actions | `presentation/core/widgets/dialog_widgets.dart` (48) + 12 fichiers | 48 + ~6 000 | `zcrud_menu` / actions déclaratives |
| `ValuationToolsGridView<T>` | `valuation_tool_model_actions_dialog_widget.dart:271` | ~160 | `ZListRenderer` / `DynamicList` |
| `EmptyTasksWidget` / `DailyTasksListWidget` / `DailyTaskListItemWidget` | `daily_tasks_page.dart:560`, `:638`, `:787` | 227 | section pliable + état vide du socle |
| `RecurrencePicker` (règle de récurrence) | `lib/workflow/components/recurrence_picker.dart` | 1 721 | — (pas d'équivalent socle connu ; candidat CR) |
| `TaskDueDatePicker` / `TaskReminderPicker` / `IsAllDayWidget` / `IsReadOnly` / `ColorSelector` | `lib/workflow/components/` | 572 *(sur 2 747 lignes de `components/`, dont 1 721 pour le seul `recurrence_picker`)* | familles `dateTime`, `boolean`, `select`, champ couleur |
| `EventRemindersWidget` (sous-liste réordonnable de rappels) | `lib/workflow/components/event_reminders_widget.dart` | 327 | `ZSubListField` (sous-liste réordonnable — livrée v3.17/3.18) |
| `WorkflowModuleLocalizations` (l10n dupliquée, **morte**) | `lib/workflow/l10n.dart` | 239 | `ZcrudLocalizationsDelegate` |
| Sélection de documents de contexte | `ChatBotDocumentsSelectionController`, `discovry_page_controller.dart:39` | ~120 | `ZRelationConfig` / sources de relation |
| Session de routage IA maison (avant v3.8.0) | `discovry_page_controller.dart:616-660` | ~45 | `ZChatRouteSession` — **déjà remplacé**, bon précédent |

---

## 6. Le CODE RÉPÉTÉ

**Mesure globale** : sur les **26 690 lignes non vides / non commentaires** du périmètre,
**6 108 (22,9 %)** appartiennent à au moins un bloc de **8 lignes strictement identiques**
répété ailleurs dans le périmètre.

Répartition (fichiers les plus atteints) :

| Fichier | Lignes dupliquées / lignes utiles | % |
|---|---:|---:|
| `lib/workflow/screens/appointment_editor.dart` | 3 411 / 7 423 | 46,0 |
| `lib/workflow/components/recurrence_picker.dart` | 741 / 1 395 | 53,1 |
| `lib/workflow/screens/event_editon_screen.dart` | 471 / 1 098 | 42,9 |
| `.../discovery/controllers/discovry_page_controller.dart` | 381 / 1 954 | 19,5 |
| `.../valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 120 / 769 | 15,6 |
| `lib/workflow/l10n.dart` | 117 / 204 | 57,4 |
| `lib/src/domain/models/valuation/valuation_tool_model.dart` | 98 / 511 | 19,2 |

### Les blocs, un par un

| # | Ce qui est répété | Sites | Lignes | Emplacements |
|---:|---|---:|---:|---|
| 6.1 | **Sous-classe de `ValuationToolModel`** : `copyWith` + `fromMap` + `toString`, identiques au nom de classe près | **10** | **420** | `valuation_tool_model.dart:163, 205, 247, 289, 331, 373, 415, 457, 499, 541` |
| 6.2 | **Dépôt Firebase d'un outil de valeur** : `extends FirebaseCrudRepositoryImpl<X> implements ValuationToolModelRepository<X>` + `crudableObjects` | **10** | **130** | `firebase_models_repositories_impls.dart:306-434` |
| 6.3 | **`ValuationToolsGridView<X>(...)`** avec 16 paramètres identiques ; seuls le type et le titre changent | **10** | **160** | `valuation_tool_model_actions_dialog_widget.dart:658, 674, 690, 706, 722, 738, 754, 770, 786, 802` |
| 6.4 | **Bouton de jour de la semaine** dans `AppointmentEditorWeb`, écrit sept fois au lieu d'une boucle sur `WeekDays.values` | **7** | **315** | `appointment_editor.dart:3247, 3292, 3337, 3382, 3427, 3472, 3517` |
| 6.5 | **Closure `_onAiCompletion(...)`** (résultat / erreur / réponse) recopiée dans le contrôleur de découverte | **6** | **~132** | `discovry_page_controller.dart:1689, 2067, 2137, 2260, 2310, 2363` |
| 6.6 | **Les trois éditeurs de rendez-vous** : 116 lignes non triviales **distinctes** présentes dans les **trois** ; 148 des 295 lignes distinctes du popup (50 %) sont aussi dans le mobile | **3** | 5 088 lignes de code au total | `appointment_editor.dart:1006-1663` / `1708-5209` / `5261-6188` |
| 6.7 | **`recurrence_picker.dart` est un fork de `_CustomRule`** : **339 des 423** lignes distinctes de `_CustomRule` (80 %) réapparaissent dans le picker | **2** | 2 654 | `appointment_editor.dart:6856-7788` ↔ `recurrence_picker.dart` (1 721) |
| 6.8 | **`event_editon_screen.dart` est un fork d'`AppointmentEditorWeb`** : **286 des 616** lignes distinctes (46 %) | **2** | — | `event_editon_screen.dart` ↔ `appointment_editor.dart:1708-5209` |
| 6.9 | **`WorkflowModuleLocalizations` duplique `Fr`** : 117 des 204 lignes utiles (57 %) — et la classe n'est **référencée nulle part** (§7) | **2** | 239 mortes | `lib/workflow/l10n.dart` ↔ `lib/workflow/l10n/messages/fr.dart` |
| 6.10 | **Extension de requête « `creatorId` OU `members` contient l'utilisateur »**, à l'octet | **3** | ~45 | `events_repository.dart:16-30`, `tasks_lists_repository.dart:16-30`, `tasks_repository.dart:19-33` |
| 6.11 | **`IffdPromotionControlledWidgetBuilder(userId:, builder: (context, {auditeur, userPermissions, promotionels, cycleEtFiliere, modules, aiRouters}))`** — même en-tête de contexte à chaque écran | **10** | ~120 | `exams_page.dart:56`, `exames_dialogs.dart:57`, `discovry_ai_page.dart:46`, `discovry_search_composer.dart:36`, `folders_page.dart`, `folder_study_tools_page.dart`, `side_menu_drawer.dart`, `access_controlled_view.dart`, `chatbot_screen.dart`, `chatbot_conversation_screen.dart` |
| 6.12 | **Chaîne `userPresentation`** (« Je suis …, étudiant·e à l'IFFD inscrit au cycle … de la filière … ») | **4** (2 identiques à l'octet, 2 divergentes dont une fautive : « Je ${firstName} suis auditeur ») | ~4 | `discovry_ai_page.dart:63`, `discovry_search_composer.dart:51`, `chatbot_screen.dart:636`, `chatbot_conversation_screen.dart:332` |
| 6.13 | **Tuiles « Modifier » / « Supprimer »** des dialogues d'actions (`ListTile` + `Get.back()` + `buildConfirmDialog`) | **10** / **8** dans le dépôt, dont 2 dans le périmètre | ~30 par site | `exam_actions_dialog_widget.dart:38`, `:59` ; `valuation_tool_model_actions_dialog_widget.dart:226`, `:249` ; +8 autres fichiers |
| 6.14 | **Sérialisation écrite à la main** (`toMap`/`fromMap`/`copyWith`/`==`/`hashCode`/`toString`/`props`) dans les 7 modèles du domaine — *mesure heuristique par comptage des corps de membres* | 63 membres | **~874 / 2 421 lignes (36 %)** | `exam_model.dart`, `valuation_tool_model.dart`, `task.dart`, `event.dart`, `appointment.dart`, `note.dart`, `time_slice.dart` |
| 6.15 | **Le même formulaire écrit deux fois** (legacy + port zcrud), pour trois formulaires de 4 à 6 champs | **3 paires** | **1 808** | exam (282 + 513), valuationTool (155 + 348), testExamFilter (134 + 376) |
| 6.16 | **`showPushedDialog`** — enveloppe de dialogue rappelée partout | **100** dans le dépôt | — | tout `lib/` |
| 6.17 | **`buildConfirmDialog`** — boîte de confirmation | **38** appels dans **20** fichiers | — | tout `lib/` |

> Le point 6.15 est le plus coûteux à court terme : **1 808 lignes** entretenues en double
> pour trois formulaires, avec **1 723 lignes de tests de parité** (`test/w7j`, `test/w7f`,
> `test/w7p`) qui figent le contrat de sortie du legacy.

---

## 7. Code mort prouvé dans le périmètre

| Symbole / fichier | Chemin | Lignes | Preuve |
|---|---|---:|---|
| `WorkflowModuleLocalizations` | `lib/workflow/l10n.dart` | **239** | Une seule occurrence dans tout `lib/` + `test/` : sa propre déclaration (`:5`). Le fichier n'est ni `import`é ni `part` (§9.7) |
| `NoteBook` et `Note` | `lib/workflow/models/note.dart` | **81** | `NoteBook` : zéro référence hors du fichier. `Note(` : deux occurrences, toutes deux dans le fichier (§9.8) |
| `timeSliceEditionFields` | `lib/workflow/edition_forms.dart` | **33** | Une seule occurrence : sa déclaration (`:3`) (§9.9) |
| `PopUpAppointmentEditor` | `appointment_editor.dart:961-1663` | **703** | `PopUpAppointmentEditor(` : une seule occurrence, sa propre déclaration de constructeur (`:963`) — **jamais instancié** |
| `AppointmentEditor` | `appointment_editor.dart:5216-6135` | **920** | `AppointmentEditor(` hors `PopUp…`/`…Web` : `:5218` (constructeur) et deux méthodes `_getAppointmentEditor` — **jamais instancié** |
| `displayAppointmentDetails` | `appointment_editor.dart:555-715` | **161** | Une seule occurrence : sa déclaration (`:555`) |
| `AppointmentEditorWeb` | `appointment_editor.dart:1664-5209` | **3 546** | Instancié 4 fois (`:491`, `:526`, `:596`, `:1538`), toutes depuis `_editRecurrence`/`_deleteRecurrence` (appelés uniquement depuis `displayAppointmentDetails`, mort) et depuis `PopUpAppointmentEditorState` (mort) |

**Surface vivante de `appointment_editor.dart` (7 858 lignes)** : sur ses **36 déclarations de
premier niveau**, **6 seulement** sont référencées ailleurs dans la librairie `workflow` —
`PickerChangedDetails`, `_ResourcePicker`, `_EndRule`, `_getSelectedResources`,
`_getUnSelectedResources`, `_DeleteDialog`. Les 30 autres, dont les **trois éditeurs de
rendez-vous complets**, ne sont atteignables que depuis du code lui-même inatteignable.

**Actions rapides inertes** : 3 des 4 cartes du tableau de bord sont `enabled: false,
onTap: () {}` — « Générer des flashcards », « Aide aux devoirs », « Créer un plan d'étude »
(`daily_tasks_page.dart:912-935`).

---

## 8. Conformité aux invariants zcrud — état de départ

| Invariant | Mesure dans le périmètre |
|---|---|
| **AD-2 / SM-1** (rebuilds granulaires) | **18 `ListenableBuilder`** sur des contrôleurs entiers, **0 `ValueListenableBuilder`**. Le contrôleur de découverte appelle `notifyListeners()` **57 fois** pour 84 méthodes ; toute frappe reconstruit page + composeur + fil. **172 `setState`**, dont 79 dans `appointment_editor.dart` et 29 dans `event_editon_screen.dart` |
| Controllers stables | `ScrollController` créé **dans `build()`** et jamais `dispose`é (`discovry_page.dart:24`) ; `ExpandableController` créé dans `build()` (`daily_tasks_page.dart:663`, `valuation_tool_model_actions_dialog_widget.dart:594`) ; `TabController` recréé à chaque `build` (`tasks_screen.dart:173`) ; `FocusNode.addListener` posé à chaque `build` (`tasks_screen.dart:147`, `task_edition_screen.dart:69`) |
| Clés stables | **4 `key: ValueKey(<…>.hashCode)`** (`exams_page.dart:141`, `daily_tasks_page.dart:284`, `:417-419`, `discovry_ai_page.dart:271`) et **7 `key: UniqueKey()`** — chacun force la reconstruction complète du sous-arbre |
| **AD-13** (RTL / a11y) | **64** `EdgeInsets.only(left:/right:)` ou `fromLTRB`, **17** `Alignment.*Left/*Right`, **13** `TextAlign.left/right`, **2** `Positioned(left:/right:)`. **5 `Semantics(`** au total, **toutes dans les 3 écrans portés à zcrud** — zéro ailleurs |
| **`ListView.builder`** | **13 `ListView(children:)`** non virtualisés (10 dans `appointment_editor.dart`) |
| **FR-26** (pas de couleur en dur) | **326** occurrences de `Colors.` / `Color(0x…)`, dont 110 dans `appointment_editor.dart` et 52 dans `white_exam_question_card.dart` |
| **l10n** | **100 littéraux `Text("…")`** en dur (55 dans `appointment_editor.dart`) ; **7 tooltips en anglais** dans une application française (`'Monday'`, `'Tuesday'`… `appointment_editor.dart`) ; les **8 locales non françaises de `lib/workflow/l10n/messages/` sont des coquilles** `class Xx extends Fr` (4 lignes chacune) |
| **AD-10** (désérialisation défensive) | Partiellement fait, à la main et après incident : `ExamModel.fromMap` documente deux corrections (B-1 sur `reminderTime`, B-12 sur `reminderDays`, `exam_model.dart:64-100`). Ailleurs, casts directs (`map['id'] as String?`) |
| **Erreurs** | Voir §3.4 : `Either`/`ZFailure` absents ; `DataState` jamais inspecté côté présentation ; 27 `catch (_) {}` |

---

## 9. Preuves d'absence — les greps négatifs

Les commandes ont été jouées depuis `/home/zakarius/DEV/iffd`. `$P` = les 90 fichiers du
périmètre (liste construite et vérifiée fichier par fichier).

**9.1 — Aucun `StreamBuilder` du domaine ne gère l'erreur**
```
$ xargs grep -n "snapshot\.hasError" < perimetre.txt ; echo RC=$?
RC=123          # xargs : grep n'a rien trouvé dans aucun des 90 fichiers
$ grep -rn "snapshot\.hasError" lib --include='*.dart' | wc -l
5               # et les 5 sites du dépôt sont TOUS hors périmètre
```

**9.2 — `lib/workflow/` ne connaît pas zcrud**
```
$ grep -rn "zcrud" lib/workflow --include='*.dart' ; echo RC=$?
RC=1            # 0 occurrence sur 36 fichiers / 16 821 lignes
```

**9.3 — Aucun rebuild granulaire dans le périmètre**
```
$ xargs grep -n "ValueListenableBuilder" < perimetre.txt ; echo RC=$?
RC=123          # 0 occurrence
$ xargs grep -c "ListenableBuilder(" < perimetre.txt | grep -v ':0$'
… 18 occurrences réparties sur 10 fichiers
```

**9.4 — Aucun modèle IFFD n'est annoté pour le codegen zcrud**
```
$ grep -rnE "^[[:space:]]*@Zcrud(Model|Field|Id)\b" lib --include='*.dart' ; echo RC=$?
RC=1            # les 10 occurrences de "@ZcrudField" dans lib/ sont toutes en COMMENTAIRE
$ grep -n "zcrud_generator" pubspec.yaml ; echo RC=$?
RC=1
$ cat build.yaml   # builders déclarés : freezed, riverpod_generator, json_serializable
```

**9.5 — `zcrud_list` / `DynamicList` absents du périmètre**
```
$ xargs grep -n "zcrud_list\|DynamicList\|ZListRenderer" < perimetre.txt ; echo RC=$?
RC=123
```

**9.6 — Pas de cache local applicatif ni d'orchestrateur de synchro dans le périmètre**
```
$ xargs grep -n "Hive\|ZLocalStore\|ZSyncOrchestrator\|SharedPreferences" < perimetre.txt ; echo RC=$?
RC=123
```

**9.7 — `WorkflowModuleLocalizations` est mort**
```
$ grep -rn "WorkflowModuleLocalizations" lib test --include='*.dart'
lib/workflow/l10n.dart:5:class WorkflowModuleLocalizations {     # sa seule occurrence
$ grep -rn "workflow/l10n.dart\|'l10n.dart'" lib --include='*.dart' ; echo RC=$?
RC=1            # le fichier n'est ni importé ni déclaré `part`
```

**9.8 — `NoteBook` est mort**
```
$ grep -rn "\bNoteBook\b" lib --include='*.dart' | grep -v "workflow/models/note.dart" ; echo RC=$?
RC=1
```

**9.9 — `timeSliceEditionFields` est mort**
```
$ grep -rn "timeSliceEditionFields" lib test --include='*.dart'
lib/workflow/edition_forms.dart:3:DynamicFormField timeSliceEditionFields(BuildContext context) {
```

**9.10 — Aucun test ne couvre l'agenda, les tâches ni la découverte**
```
$ grep -rln "TaskEditionScreen\|TasksScreen\|CalenderScreen\|AppointmentEditor\|ErpCalendarDataSource\|WorkspacePage\|RecurrencePicker" test --include='*.dart' ; echo RC=$?
RC=1
$ grep -rln "DiscovryPageController\|DiscovryAiPage\|DiscovrySearchComposer\|DiscovryPage" test --include='*.dart' ; echo RC=$?
RC=1
$ grep -rln "DailyTasksPage\|ExamsPage\|WhiteExamPage\|WhiteExamQuestionCard\|ValuationToolsGridView" test --include='*.dart'
test/w8m/review_card_reveal_command_test.dart      # une SEULE occurrence, et c'est un COMMENTAIRE (`:94`)
```

**Ce qui EST testé dans le périmètre** : uniquement les portages zcrud et leur contrat de
parité — `test/w5f/` (5 fichiers, 1 215 lignes : adaptateur `ZBackedExamRepository`),
`test/w7j/` (2 fichiers, 1 341 lignes : formulaire d'examen legacy + zcrud),
`test/w7f/` (3 fichiers, 752 lignes : filtres de test),
`test/w7p/` (3 fichiers, 984 lignes : outils de valeur),
`test/src/features/exams/providers/exam_providers_test.dart`.
**Total : 14 fichiers, ~4 292 lignes de tests, tous braqués sur la migration**, aucun sur le
comportement métier historique.

---

## 10. Ce que ce relevé désigne comme travail de migration

Sans prescrire l'ordre, les faits ci-dessus désignent quatre chantiers de nature très différente :

1. **Examens** — le plus avancé : entité socle `ZExam` existante, adaptateur de données écrit
   (912 lignes) et testé, formulaire porté et **actif en QA**. Restent : `ExamsPage`
   (liste + grille + tuiles → `DynamicList`/`ZListRenderer`), le menu d'actions, et le retrait
   de la branche legacy une fois la bascule tenue.
2. **Outils de valeur en douane** — 420 + 130 + 160 = **710 lignes de pure répétition** que le
   codegen (`@ZcrudModel` sur `ValuationToolModel` + un type discriminant) et un
   `DynamicList` générique effacent. Sous réserve que ce corpus reste dans IFFD : sa route est
   déjà redirigée vers `lex_douane`.
3. **Découverte** — la seule pièce déjà branchée en profondeur (`ZChatRouteSession` depuis
   v3.8.0). Le contrôleur de 2 412 lignes / 57 `notifyListeners()` est le candidat naturel au
   découpage en tranches réactives.
4. **Tâches / agenda** — **16 821 lignes hors de toute portée zcrud, sans un seul test**, dont
   **au moins 5 330 lignes prouvées inatteignables** et **22,9 %** de lignes strictement
   dupliquées. C'est le plus gros gisement, et aussi le plus risqué : c'est le seul
   sous-domaine dont on ne dispose d'**aucun filet** pour mesurer une régression.

---

*Relevé produit en lecture seule. Aucun fichier de `/home/zakarius/DEV/iffd` n'a été créé,
modifié ni supprimé. Aucun test n'a été lancé. Aucune clé d'API ni aucun secret n'est cité —
le dépôt en porte dans `.env` (racine) et dans la configuration de plateforme.*
