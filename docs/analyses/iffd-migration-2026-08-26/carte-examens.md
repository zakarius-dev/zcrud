# Carte du domaine « Examens et évaluations » — IFFD

**Relevé du 2026-08-26.** Dépôt hôte lu en LECTURE SEULE : `/home/zakarius/DEV/iffd`,
branche `main`, dernier commit `65d1af9`. Socle de référence : `zcrud` v3.21.0, 41 paquets.

Tous les `fichier:ligne` de ce document sont relatifs à `/home/zakarius/DEV/iffd/` pour l'hôte
et à `/home/zakarius/DEV/zcrud/` pour le socle. Aucune valeur n'est reprise du relevé
`iffd-migration-2026-08-25/` (déclaré périmé par son propre `OBSOLETE.md`) : tout ce qui suit a
été remesuré sur disque aujourd'hui.

---

## 0. Le point de départ était trompeur

Le périmètre annoncé — `lib/src/features/exams/` — pèse **3 fichiers et 138 lignes**, dont
113 de code généré :

```
lib/src/features/exams/exams_module.dart              1
lib/src/features/exams/providers/exam_providers.dart 24
lib/src/features/exams/providers/exam_providers.g.dart 113
lib/src/features/exams/pages/                         (répertoire VIDE)
lib/src/features/exams/widgets/                       (répertoire VIDE)
```

Le domaine réel vit ailleurs, réparti sur **trois quartiers sans lien de nommage** :

| Quartier | Où | Ce qu'il porte |
|---|---|---|
| **Examen-échéance** (entité datée) | `presentation/features/administration/` + `domain/models/exam_model.dart` + `data/repositories/z_backed_exam_repository.dart` | CRUD de l'examen d'un dossier, ses rappels, son agenda |
| **Épreuve** (passer un test) | `presentation/features/flashcards/` | test / examen blanc sur les flashcards apprises |
| **Correction** (noter une réponse) | `domain/services/ai/ai_prompt_generator.dart` + `data/repositories/*_ai_repository_impl.dart` | notation 1-5 par l'IA, explication de la bonne réponse |

**Inclusions au-delà du chemin annoncé, et pourquoi** : `features/flashcards/**` (le runtime
d'épreuve y vit intégralement), `utils/flashcard_filters.dart` (la sélection des questions),
`presentation/features/folders/pages/folder_progress_page.dart` (deuxième liste d'examens),
`presentation/features/home/pages/dashbord_page.dart`, `presentation/features/tasks/pages/daily_tasks_page.dart`,
`workflow/source.dart` + `workflow/screens/agenda_screen.dart` (l'examen comme rendez-vous
d'agenda), `utils/helpers/permission_helpers.dart` (l'ACL par année académique).

**Exclusion explicite** : `presentation/features/valuation_tools/` et
`utils/constants/valuation_tools/` (2 325 lignes) ne relèvent PAS de l'évaluation d'un
apprenant. Vérifié en lisant `utils/constants/valuation_tools/valuation_tools.dart:12-21` et
`notes_interpretatives.dart:1-10` : c'est le corpus OMD de la **valeur en douane** (articles du
GATT, avis consultatifs, notes interprétatives). Homonymie, pas parenté.

### Périmètre chiffré

| | Fichiers | Lignes |
|---|---:|---:|
| Code de production | **26** | **9 913** |
| Tests attachés au domaine | 12 | 3 364 |

Détail des tests : `test/w7j/` (édition d'examen, 1 341 l.), `test/w7f/` (filtre de test, 752 l.),
`test/w5f/` (adaptateur de dépôt, 1 215 l.), `test/src/features/exams/providers/` (56 l.).

---

## 1. Ce que le domaine sait faire (en termes d'utilisateur)

### 1.1 Examen-échéance — planifier

1. **Inscrire un examen à une date**, rattaché à un dossier de révision et à une année
   académique (`administration/dialogs/exames_dialogs.dart:29`).
2. **Voir ses examens groupés en « à venir » / « passés »**, en grille responsive, un examen
   passé étant grisé et barré (`administration/pages/exams_page.dart:28-41`, `:286-312`).
3. **Ouvrir le dossier de révision depuis la tuile d'examen** (`exams_page.dart:291-304`).
4. **Programmer des rappels hebdomadaires** — jours de semaine + heure
   (`domain/models/exam_model.dart:19-21`). Voir §7.1 : ce modèle est propre à IFFD.
5. **Voir l'examen dans l'agenda** comme rendez-vous teal (`exam_model.dart:130-141`,
   `workflow/models/appointment.dart:17`, `workflow/source.dart:38`).
6. **Créer un examen depuis six points d'entrée différents** : la page d'administration, le
   tableau de bord, les tâches du jour, le menu d'actions d'un dossier, la page de progression
   d'un dossier, un menu contextuel (§4.1).
7. **Laisser l'examen piloter les tâches d'apprentissage** — le libellé vide de la page le dit :
   « Ajoute une date d'examen pour bénéficier de tâches d'apprentissage optimisées »
   (`exams_page.dart:32`), branché sur `smartLearnInstance` (`exams_page.dart:100-101`).
8. **Voir son titre se remplir tout seul** quand on choisit un dossier : `Examen: <titre du
   dossier>` (`exames_dialogs.dart:169-183` en legacy, `exam_zcrud_edition.dart:311-370` porté).

### 1.2 Épreuve — passer

9. **Configurer un test** : nombre de questions (1 à 30), types de questions, niveaux de maîtrise
   visés, filtrage par balises / documents / notes (`flashcards/widgets/test_exam_filter_screen.dart:39-131`).
10. **Ne composer le test que sur des cartes DÉJÀ apprises**, dédoublonnées entre « apprises » et
    « à réviser » (`flashcards/widgets/flashcard_widgets.dart:1058-1066`).
11. **Tirer au sort** quand le vivier dépasse le nombre demandé, et **battre les propositions de
    QCM** (`utils/flashcard_filters.dart:83-87`, `flashcard_widgets.dart:1106-1108`).
12. **Répondre selon le type de question** : QCM à choix simple ou multiple (l'unicité est
    déduite du nombre de bonnes réponses), vrai/faux, réponse libre en markdown riche
    (`white_exam_question_card.dart:679-904`).
13. **Déclarer « Je ne sais pas »** (`white_exam_page.dart:220-256`).
14. **Marquer une question d'un fanion** pour y revenir (`white_exam_page.dart:258-272`).
15. **Voir un chronomètre courir** et une barre de progression réponses/total
    (`white_exam_page.dart:74-88`, `:145-155`).
16. **Soumettre complet ou incomplet**, avec confirmation chiffrant les questions non répondues
    (`white_exam_page.dart:381-424`).
17. **Enchaîner les cartes en pile swipeable** dans le mode réellement atteignable
    (`folder_flashcards_repetitions_page.dart:504-540`).
18. **Voir un écran de fin de session** avec confettis et statistiques
    (`flashcards_learning_celebration_page.dart`, monté à `folder_flashcards_repetitions_page.dart:499`).

### 1.3 Correction — noter

19. **Corriger seul QCM et vrai/faux** : 5 si exact, 1 sinon ; « je ne sais pas » vaut 0
    (`white_exam_page.dart:546-583`).
20. **Faire noter les réponses libres par l'IA** sur une échelle 1-5, avec repli neutre à 3 si
    l'IA échoue ou rend une valeur hors bornes (`white_exam_page.dart:585-615`).
21. **Adapter la consigne de notation à la filière de l'auditeur** (`ai_prompt_generator.dart:531-572`,
    via `_filierePreprompt`).
22. **Recevoir un message pédagogique par question**, tiré au sort dans une banque par niveau de
    qualité (`white_exam_page.dart:491-545` — 4+6+6 = 16 messages).
23. **Demander à l'IA d'expliquer la bonne réponse**, en flux, ré-explicable
    (`white_exam_question_card.dart:226-355`, bouton « Réexpliquer » `:1014-1030`).
24. **Voir son score global** : pourcentage sur `réponses × 5`, correctes/total, temps total,
    temps moyen par question, bandeau vert au-dessus de 70 % sinon orange
    (`white_exam_page.dart:634-700`).

---

## 2. Écrans et dialogues

### 2.1 Quartier « examen-échéance »

| Fichier | Lignes | Rôle | Porte |
|---|---:|---|---|
| `presentation/features/administration/pages/exams_page.dart` | 333 | Page d'administration des examens | Liste (grille) + tuiles + états vides + navigation |
| `presentation/features/administration/dialogs/exames_dialogs.dart` | 282 | Ouvre le formulaire, ouvre le menu d'actions, écrit en base | Formulaire (aiguillage legacy/porté) |
| `presentation/features/administration/dialogs/exam_zcrud_edition.dart` | 513 | **Jumeau porté** du formulaire | Formulaire zcrud (`DynamicEdition`) |
| `presentation/features/administration/widgets/exam_actions_dialog_widget.dart` | 76 | Menu « Modifier / Supprimer » | Deux tuiles + confirmation |
| `presentation/features/folders/pages/folder_progress_page.dart` (§ examens, l. 87-200 et 539-580) | ~150 | **Deuxième** liste d'examens, dans un dossier | Liste + tuiles + états vides — quasi-copie de `exams_page` (§4.2) |

### 2.2 Quartier « épreuve »

| Fichier | Lignes | Rôle | Porte |
|---|---:|---|---|
| `flashcards/widgets/test_exam_filter_screen.dart` | 134 | Formulaire « Mise en place du test » | Formulaire legacy (`DynamicEditionScreen`) |
| `flashcards/widgets/test_exam_filter_zcrud_screen.dart` | 376 | **Jumeau porté** | Formulaire zcrud |
| `flashcards/pages/folder_flashcards_repetitions_page.dart` | 1 202 | Runtime réellement atteint (6 modes, dont `test` et `whiteExam`) | Pile swipeable + boutons + fin de session |
| `flashcards/widgets/flashcard_repetition_widgets.dart` | 717 | Aiguillage carte interactive / carte à retourner | En-tête, badge de consigne, `FlipCard` |
| `flashcards/widgets/interactive_flashcard_repetition_card.dart` | 1 205 | Carte de test/examen interactive | Saisie QCM/VF/texte + indices + notation |
| `flashcards/widgets/white_exam_question_card.dart` | 1 139 | Carte de question d'examen blanc | Saisie + rendu riche + correction + explication IA |
| `flashcards/widgets/learning_mode_question_card.dart` | 251 | Enveloppe « mode apprentissage » | Bande de messages + délègue aux deux cartes ci-dessus |
| `flashcards/pages/white_exam_page.dart` | 779 | Page d'examen blanc en LISTE | Liste + chrono + soumission + score — **jamais atteinte, cf. §2.4** |
| `flashcards/pages/flashcards_learning_celebration_page.dart` | 403 | Fin de session | Confettis + statistiques |

### 2.3 Jumeaux portés et leurs drapeaux

Deux écrans du domaine ont un jumeau `*_zcrud_*`. Les deux sont **à `false` par défaut** : le
chemin legacy est celui qui tourne.

| Drapeau (`z_qa_flags.dart`) | Écran | Défaut | Jumeau | Contrat figé par |
|---|---|---|---|---|
| `exam` (`:673`, famille `comportement`) | Administration — créer / modifier un examen | `false` (`exam_zcrud_edition.dart:77`) | `ExamZcrudEditionScreen` | `test/w7j/` (1 341 l.) |
| `testExamFilter` (`:362`, famille `comportement`) | Filtres de test / examen | `false` (`test_exam_filter_zcrud_screen.dart:61`) | `TestExamFilterZcrudScreen` | `test/w7f/` (752 l.) |

Le registre compte **52 drapeaux** (`grep -c "^  ZQaFlag($" = 52`, autant que de clés `id:`,
`z_qa_flags.dart`, 985 lignes) ; le plan de QA `docs/qa-plan-comparaison-legacy-zcrud.md` (651 l.) en détaille 52
bascules, dont ces deux-ci aux lignes 246 et 396.

Un troisième drapeau touche le domaine par la bande : `flashcardsQuestionsCount` (`:348`) —
« Générer des flashcards avec l'IA ». **Sa chaîne d'appel est morte, remesuré aujourd'hui** :

```
$ grep -rn --include='*.dart' "showQuestionsTypesSelectionDialig" lib
lib/src/presentation/shared/zcrud/z_qa_flags.dart:336            (commentaire)
lib/src/presentation/features/flashcards/dialogs/flashcards_dialogs.dart:344   (définition)
lib/src/presentation/features/flashcards/dialogs/flashcards_dialogs.dart:407   (dartdoc)
lib/src/presentation/features/flashcards/zcrud/flashcards_questions_count_zcrud_edition.dart:7,10,90,207  (commentaires)
```
→ **0 site d'appel.** La fonction se définit et se documente, personne ne l'appelle.

### 2.4 🔴 `WhiteExamPage` est du code mort — 779 lignes, jamais montées

**Grep négatif montré** :

```
$ grep -rn --include='*.dart' 'WhiteExamPageRoute' lib | grep -v 'app_router.gr.dart'
(aucune ligne)
```

La route est générée (`config/router/app_router.gr.dart:2443-2534`) mais **jamais poussée**. Son
unique site de construction est commenté : `flashcard_widgets.dart:1124-1201` — la tuile
« Examen Blanc » est intégralement en commentaire, 78 lignes. La tuile « Test » vivante
(`flashcard_widgets.dart:1045-1124`) route vers `FolderFlashcardsRepetitionsPage` avec
`FlashcardRepetitionPageType.whiteExam`, **pas** vers `WhiteExamPage`.

Le fichier n'est pas retirable tel quel : il définit `ExamAnswer` (`white_exam_page.dart:754-779`),
consommé par 3 fichiers vivants (`white_exam_question_card.dart:26,28,151`,
`learning_mode_question_card.dart:49,59`, `interactive_flashcard_repetition_card.dart:17,34,185`).
Ce qui est mort, c'est la **page** — et avec elle les 24 fonctionnalités de §1.2/§1.3 qu'elle
seule portait : chronomètre, fanions, soumission incomplète, bandeau de score global,
notation IA des réponses libres en lot, banque de messages pédagogiques.

⚠️ Conséquence pour la migration : **le comportement d'examen blanc que le code décrit n'est pas
celui que l'utilisateur voit.** Toute parité mesurée contre `WhiteExamPage` mesurerait un écran
que personne n'ouvre.

Corollaire mesuré : **0 test** sur ce runtime.

```
$ grep -rlnE 'WhiteExamPage|WhiteExamQuestionCard|LearningModeQuestionCard|applyTestExamFilters' test/
test/w8m/review_card_reveal_command_test.dart   → l. 94, un COMMENTAIRE
test/w8g/review_session_routing_test.dart       → l. 42, 91, InteractiveFlashcardRepetitionCard seulement
```
→ aucune garde de comportement sur la page d'examen, la carte de question, l'enveloppe
d'apprentissage ni la fonction de filtrage.

Et **0 `Semantics(`** dans les 3 840 lignes du runtime d'épreuve :

```
$ grep -c 'Semantics(' <4 fichiers>
white_exam_page.dart:0   white_exam_question_card.dart:0
interactive_flashcard_repetition_card.dart:0   flashcard_repetition_widgets.dart:0
```

---

## 3. Modèles et persistance

### 3.1 `ExamModel` — `domain/models/exam_model.dart` (168 l.)

| Champ | Type | Note |
|---|---|---|
| `id` | `String?` | hérité de `DynamicModel` |
| `accademicYear` | `String?` | orthographe legacy, conservée partout |
| `title` | `String?` | |
| `userId` | `String?` | propriétaire |
| `folderId` | `String?` | dossier de révision rattaché |
| `date` | **`Timestamp?`** | 🔴 fuite `cloud_firestore` dans le domaine (`exam_model.dart:5,20`) |
| `enableReminder` | `bool` | |
| `reminderDays` | `List<WeekDays>` | 🔴 **`WeekDays` vient de `syncfusion_flutter_calendar`** (`exam_model.dart:7`) |
| `reminderTime` | `TimeOfDay?` | 🔴 `TimeOfDay` vient de `flutter/material` (`exam_model.dart:6`) |

Sérialisation **écrite à la main** : `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith`/`props`
(`exam_model.dart:32-168`). Aucune annotation, aucun codegen. Deux bugs historiques corrigés en
place et documentés dans le fichier : B-12 (cast `day as String` avalé par `firstWhereOrNull`,
`:66-73`) et B-1 (`int.tryParse` sur un `int`, `:88-107`).

`toAppointment()` (`:130-141`) projette l'examen en rendez-vous Syncfusion.

### 3.2 Dépôts — deux chemins en parallèle (strangler fig)

```
domain/repositories/exams_repository.dart:8      abstract class ExamsRepository implements CrudRepository<ExamModel>
  └─ extension userExams(...)          :11-39   flux (examens, flux de dossiers) — N+1 par construction
  └─ extension userExamsInFolder(...)  :41-56

data/repositories/firebase_models_repositories_impls.dart:71   FirebaseExamsRepositoryImpl  ← ACTIF
data/repositories/z_backed_exam_repository.dart (912 l.)       ZBackedExamRepository        ← inactif
features/exams/providers/exam_providers.dart:18                useZcrudExamsRepository = false
```

Le sélecteur : `exam_providers.dart:21-24`. Défaut `false` → **Firestore direct**.

`ZBackedExamRepository` transite par l'entité **réelle** `ZExam` de `package:zcrud_exam` — c'est
le **seul** import de `zcrud_exam` dans tout IFFD (`grep -c "package:zcrud_exam" lib = 1`). Sa
table de correspondance est documentée à `z_backed_exam_repository.dart:120-131` :

- `title` / `folderId` : `ZExam` les impose NON-NULL ; un `''` réel est doublé dans
  `extra['iffd_title']` / `extra['iffd_folder_id']` et le marqueur fait foi au retour ;
- `date` : `Timestamp` ⇄ `DateTime` ISO-8601 UTC ; les nanosecondes sous-µs sont doublées dans
  `extra` ;
- `reminderDays` → `reminderRecurrence.weekdays` (conversion ISO explicite, dimanche `0`→`7`),
  **livrée par CR-IFFD-17 en zcrud v0.5.1** ;
- `reminderDaysBefore` reste **vide** — « N jours avant » n'est pas convertible en « jours de
  semaine », et le mapper refuse de fabriquer la donnée ;
- `accademicYear` et `userId` n'ont **aucun homologue** de schéma : `extra['iffd_accademic_year']`,
  `extra['iffd_user_id']`.

### 3.3 Traitement des erreurs

`CrudRepository` d'IFFD ne rend **pas** `Either<ZFailure, T>` : `userExams` rend un
`Stream<(List<ExamModel>, List<Stream<FolderModel?>?>)>` nu (`exams_repository.dart:11`). Les
états d'erreur ne sont pas rendus : `exams_page.dart:116-118` teste `!snapshot.hasData` et
affiche un `CircularProgressIndicator` — un flux en erreur affiche donc **un chargement
perpétuel**. Même motif à `folder_progress_page.dart:545`.

Côté épreuve, l'erreur d'évaluation IA est avalée en `debugPrint` puis repliée sur 3.0
(`white_exam_page.dart:608-614`) — repli sain, mais silencieux pour l'utilisateur.

### 3.4 ACL — le trait le plus spécifique

Le droit de créer un examen est porté par une clé **composée du modèle ET de l'année
académique** : `"ExamModel$accademicYear"`. **6 sites** :

```
utils/helpers/permission_helpers.dart:94          (déclaration : une CrudableObject par année)
presentation/features/home/pages/dashbord_page.dart:512
presentation/features/tasks/pages/daily_tasks_page.dart:60
presentation/features/administration/pages/exams_page.dart:75
presentation/features/folders/pages/folder_progress_page.dart:152
presentation/features/folders/dialogs/folder_actions_dialog_widget.dart:46
```

---

## 4. 🔴 Le code répété

### 4.1 Ouvrir le formulaire d'examen — **7 sites d'appel, ~14 lignes chacun**

`showExamEditonDialog` est défini une fois (`exames_dialogs.dart:29`) et appelé depuis :

| Site | Lignes du bloc |
|---|---|
| `home/pages/dashbord_page.dart:123-136` | 14 |
| `flashcards/controllers/smart_learn_controller.dart:357-374` | 18 |
| `folders/dialogs/folder_actions_dialog_widget.dart:140-153` | 14 |
| `core/widgets/popup_menu_helpers.dart:159-172` | 14 |
| `tasks/pages/daily_tasks_page.dart:67-80` | 14 |
| `administration/pages/exams_page.dart:83-96` | 14 |
| `administration/widgets/exam_actions_dialog_widget.dart:44-53` | 10 |

Chaque site reconstruit **le même `ExamModel` d'amorçage** (`userId`, `id: randomString()`,
`date`, `accademicYear`), **le même titre littéral** « Configurer un nouvel examen » (5 sites sur
7) et **les trois mêmes dépôts** lus au conteneur Riverpod. ≈ **98 lignes** dont aucune ne porte
de décision propre au site.

### 4.2 La liste d'examens — **2 sites, ~80 % identiques**

`examsListBuilder` + `emptyExamsWidgetBuilder` + la boucle de groupement « à venir / passés »
existent deux fois :

| | Fichier | Lignes |
|---|---|---|
| ① | `administration/pages/exams_page.dart:123-220` | 98 |
| ② | `folders/pages/folder_progress_page.dart:87-191` et `:539-580` | 147 |

Diff mesuré sur le cœur commun (`examsListBuilder`, 54 l. vs 49 l. après normalisation de
l'indentation) : **21 lignes divergentes sur 103**. Y sont recopiés à l'identique : le tri par
date décroissante, le calcul de grille (`Get.width`, `drawerWidth = 300`, `itemMinWidth` 350/300,
`childAspectRatio: itemWidth / (kToolbarHeight + 20|40)`), le `GridView.count` non défilant, et
la boucle upcoming/passed.

### 4.3 Les trois saisies de réponse — **2 sites, 199 vs 205 lignes**

`_buildQCMInput` / `_buildTrueFalseInput` / `_buildTextInput` sont écrits deux fois :

| Méthode | `white_exam_question_card.dart` | `interactive_flashcard_repetition_card.dart` |
|---|---|---|
| `_buildQCMInput` | `:679-775` (97 l.) | `:686-787` (102 l.) |
| `_buildTrueFalseInput` | `:776-863` (88 l.) | `:788-890` (103 l.) |
| `_buildTextInput` | `:864-904` (41 l.) | `:891-911` (21 l.) |

Diff mesuré sur les deux `_buildQCMInput` : **63 lignes divergentes sur 199**. Les divergences
sont des variantes réelles (le facteur d'échelle du lecteur markdown vaut `1.0` d'un côté et
`1.1` de l'autre ; `widget.isSubmitted` contre `_isSubmitted` ; `enabled:` contre
`onChanged: null`) — c'est-à-dire exactement le genre d'écart qu'une copie produit et qu'on ne
remarque pas.

**≈ 452 lignes pour trois formes de saisie.**

### 4.4 La table des dégradés par type de question — **3 sites, 23 lignes IDENTIQUES à l'octet**

```
white_exam_question_card.dart:86-108
interactive_flashcard_repetition_card.dart:104-126
flashcard_repetition_widgets.dart:52-74
```
`diff` après normalisation d'indentation : **aucune différence**, deux fois. 4 couleurs de
dégradé, un getter `_cardGradient`, un `_getTypeIcon(QuestionType)` de 4 cas.
**69 lignes, dont 46 redondantes.** Et 8 hexadécimaux en dur × 3.

### 4.5 En-tête et badge de consigne — **2 sites**

| | `flashcard_repetition_widgets.dart` | `interactive_flashcard_repetition_card.dart` |
|---|---|---|
| `_buildHeader` | `:319-422` (104 l.) | `:580-608` (29 l.) |
| `_buildInstructionBadge` | `:423-480` (58 l.) | `:609-673` (65 l.) |

Diff des deux badges : **17 lignes divergentes sur ~62** — dont une divergence de fond : la copie
de `flashcard_repetition_widgets.dart` traite `openQuestion` et `exercise` par un `default:`
commun, l'autre leur donne deux libellés et deux icônes distincts.

### 4.6 Les messages pédagogiques — **2 banques, ~90 lignes**

| Fichier | Fonctions | Lignes |
|---|---|---|
| `white_exam_page.dart:491-545` | `_generateFeedbackMessage`, `_getEncouragementMessage`, `_getMotivationMessage`, `_getIDontKnowMessage` | 55 |
| `learning_mode_question_card.dart:57-160` | `_showQualityFeedback`, `_getEncouragementMessage`, `_getMotivationMessage` | ~104 |

Mêmes seuils (`5|4` / `3` / défaut), même tirage `messages[DateTime.now().millisecond % n]`,
messages partiellement recopiés (« Waouh ! Tu connais ça par cœur ! ⚡ » figure dans les deux).

### 4.7 Le formulaire zcrud monté à la main — **12 sites, dont les 2 du domaine**

Douze fichiers construisent eux-mêmes `ZFormController` + `ZEditionSubmitController` + `Scaffold`
+ `AppBar` + bouton « Enregistrer » `Semantics(button)` à 48 dp :

```
$ grep -rl --include='*.dart' "label: 'Enregistrer'," lib   → 12 fichiers
```

dont `administration/dialogs/exam_zcrud_edition.dart:424-512` (89 l.) et
`flashcards/widgets/test_exam_filter_zcrud_screen.dart:311-376` (66 l.).

**Seize sites d'appel d'IFFD, répartis sur 15 fichiers, sont déjà passés à `presentFormEdition`** de
`zcrud_screen` (`grep -rn "presentFormEdition(" lib` = 16 ; `grep -rln` = 15). Le
fichier qui a fait la bascule le dit lui-même
(`administration/dialogs/auditeur_account_zcrud_edition.dart:124-143`) :

> « Chacun d'eux remontait à la main son `Scaffold`, son `AppBar`, son bouton « Enregistrer » et
> son `ZEditionSubmitController` — une quarantaine de lignes rejouées par formulaire, dont aucune
> ne portait de décision. »

⇒ **≈ 480 lignes** encore rejouées sur les 12 sites restants, et les deux du domaine « examens »
en font partie.

### 4.8 Le menu « Modifier / Supprimer » — **12 sites**

12 classes héritent de `StatelessItemDialogWidget` (`grep -rl "extends StatelessItemDialogWidget"`
= 12 fichiers, 4 394 lignes cumulées), dont `exam_actions_dialog_widget.dart` (76 l.). Chacune
rejoue les deux `Material > ListTile` (icône, libellé, `Get.back()`) et la confirmation :
`buildConfirmDialog` est appelée **35 fois** dans `lib/`.

### 4.9 Le récapitulatif chiffré

| Bloc répété | Sites | Lignes en jeu | Redondance estimée |
|---|---:|---:|---:|
| Ouverture du formulaire d'examen (§4.1) | 7 | 98 | ~84 |
| Liste d'examens + groupement + état vide (§4.2) | 2 | 245 | ~100 |
| Saisies QCM / vrai-faux / texte (§4.3) | 2 | 452 | ~200 |
| Table des dégradés + icône par type (§4.4) | 3 | 69 | **46 (identiques à l'octet)** |
| En-tête + badge de consigne (§4.5) | 2 | 256 | ~90 |
| Banque de messages pédagogiques (§4.6) | 2 | 159 | ~70 |
| Écran de formulaire zcrud monté à la main (§4.7) | 12 (dont 2 ici) | ~480 | ~440 |
| Menu d'actions « Modifier / Supprimer » (§4.8) | 12 (dont 1 ici) | — | — |
| **Total attribuable au domaine** | | **~1 280** | **~590** |

Soit **environ 6 % du domaine réécrit à l'identique**, et **~590 lignes** qu'aucun assemblage du
socle ne demanderait d'écrire.

---

## 5. Ce qui est DÉJÀ branché sur zcrud

IFFD importe **22 paquets `zcrud_*`** (`grep -h "^import 'package:zcrud_"` = 196 imports) :

```
zcrud_core 67   zcrud_chat_kernel 19   zcrud_study 16   zcrud_screen 16   zcrud_chat 15
zcrud_markdown 11   zcrud_flashcard 9   zcrud_study_kernel 6   zcrud_navigation 6
zcrud_firestore 5   zcrud_mindmap 4   zcrud_ui_kit 3   zcrud_session 3
zcrud_chat_syncfusion 3   zcrud_chat_material 3   zcrud_select 2   zcrud_intl 2
zcrud_chat_markdown 2   zcrud_note 1   zcrud_menu 1   zcrud_exam 1   zcrud_document 1
```

### 5.1 Dans le domaine « examens », précisément

| Ce qui est consommé | Où | Depuis |
|---|---|---|
| `ZExam`, `ZReminderRecurrence`, `ZReminderTime` | `data/repositories/z_backed_exam_repository.dart:95-97` | `zcrud_exam` — **unique site** |
| `ZFieldSpec`, `EditionFieldType`, `ZTextConfig`, `ZDateConfig`, `ZRelationConfig`, `ZValidatorSpec`, `ZFormController`, `ZEditionSubmitController`, `DynamicEdition`, `ZRelationSourceRegistry`, `Right`/`ZFailure` | `exam_zcrud_edition.dart:66` | `zcrud_core` |
| `ZFieldSpec`, `ZFieldChoice`, `EditionFieldType`, `ZFormController`, `ZEditionSubmitController`, `DynamicEdition` | `test_exam_filter_zcrud_screen.dart:52` | `zcrud_core` |
| `ZFlashcardSubmission` | `interactive_flashcard_repetition_card.dart:21` | `zcrud_session` |
| `ZFlashcardAnswerInput` | `flashcards/zcrud/review_session_zcrud.dart:37,118` | `zcrud_session` |
| `ZSrsQualityButtons` (via `srs_quality_zcrud.dart:30`) | `flashcards/zcrud/srs_quality_zcrud.dart` | `zcrud_session` |
| `ZSubListConfig` (comptes de questions) | `shared/zcrud/z_questions_counts_field.dart:38-44` | `zcrud_core` |

### 5.2 Le registre de widgets

`shared/zcrud/z_iffd_field_registry.dart` (461 l.) construit **un registre par montage** (jamais
un singleton — `ZWidgetRegistry.register` lève sur collision, `:73-78`) et y pose :

- `registerZMarkdownFields(registry, codec: IffdRichTextCodec(), styleSet: iffdMarkdownStyleSet())`
  (`:102-105`) — le codec **markdown** (et non Delta) est ce qui empêche la destruction des
  ~11 400 valeurs du corpus (`:19-24`) ;
- `registerZFlashcardEditors` (`zcrud_flashcard`) ;
- `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` (`:188`) ;
- `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` (`:199`) ;
- le présentateur de sélection `ZSmartSelectPresenter` (`zcrud_select`), le thème de formulaire,
  la palette de teintes par type, le formateur numérique, le formateur de date.

**24 montages de `IffdZcrudScope` dans 22 fichiers.** Deux fichiers de formulaire zcrud n'y sont
PAS montés :

```
lib/src/presentation/features/administration/dialogs/auditeur_account_zcrud_edition.dart  (passe par presentFormEdition)
lib/src/presentation/features/flashcards/widgets/test_exam_filter_zcrud_screen.dart       (monte son propre Scaffold)
```

⚠️ Le second est un défaut. Le registre le dit lui-même
(`exam_zcrud_edition.dart:480-485`) : « Un écran hors scope perd tout cela EN SILENCE — mesuré :
la casse `ucFirst` a régressé sur les pilotes sans scope au retrait des re-déclarations
(2026-08-24). » `TestExamFilterZcrudScreen` perd donc la casse par défaut, le port numérique, le
présentateur de sélection et le thème des sous-listes.

---

## 6. 🔴 Ce que le socle porte DÉJÀ et qu'IFFD réécrit

`zcrud_session` (v3.21.0) exporte un **runtime d'examen blanc complet**, avec ses vues. IFFD n'en
consomme rien. Grep négatif montré, exécuté aujourd'hui sur `lib/` :

```
ZWhiteExamSessionEngine     : 0        ZListSessionView            : 0
ZWhiteExamSessionController : 0        ZTestFiltersDialog          : 0
ZWhiteExamSessionView       : 0        zApplyTestFilters           : 0
ZFlashcardTestFilters       : 0        ZSessionSummaryView         : 0
ZTimerDisplay               : 0        ZFeedbackBank               : 0
ZCorrectionVisibility       : 0        ZSessionModeSelector        : 0
ZSessionProgressIndicator   : 0        ZSessionQualityBreakdown    : 0
```

Correspondance terme à terme :

| Ce qu'IFFD écrit | Lignes | Ce que le socle porte | Lignes |
|---|---:|---|---:|
| `white_exam_page.dart` — machine soumission/score, chrono, fanions | 779 | `ZWhiteExamSessionEngine` (`setup→running→submitted`, scoring différé pur, zéro écriture SRS **par construction du type**) | 420 |
| — | — | `ZWhiteExamSessionController` | 97 |
| la liste de questions + soumission de `white_exam_page.dart` | ~300 | `ZListSessionView` (vue pure, affordances gatées sur la phase, aucun `StateError` atteignable) | 704 |
| — | — | `ZWhiteExamSessionView` | 283 |
| `test_exam_filter_screen.dart` + `test_exam_filter_zcrud_screen.dart` | 510 | `ZTestFiltersDialog` (a11y AD-13 : `Semantics(checked:, onTap:)` + `excludeSemantics`) | 411 |
| `utils/flashcard_filters.dart` (`applyTestExamFilters`) | 90 | `zApplyTestFilters` + `ZFlashcardTestFilters` + `ZMasteryLevel` (`zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:107-146,206`) | ~140 |
| les 3 `_build*Input` × 2 sites | 452 | `ZFlashcardAnswerInput` (`zcrud_session`) — **déjà importé une fois** par `review_session_zcrud.dart` | 1 645 |
| les 2 banques de messages (§4.6) | 159 | `ZFeedbackBank`/`ZDefaultFeedbackBank` (`z_session_feedback_bank.dart`) + `z_session_feedback.dart` (sélection pure `(quality, timeTaken, hintsUsed)` → clé l10n, qualité passée par `config.clampQuality`) | 137 + 153 |
| `flashcards_learning_celebration_page.dart` (confetti importé en direct) | 403 | `ZSessionSummaryView` (confine `confetti` ; assemble `ZSessionQualityBreakdown` + `ZStudyProgressRings`) | 846 |
| le chronomètre de `white_exam_page.dart:74-88` | ~15 | `ZTimerDisplay` (temps toujours mesuré, affichage par enum) | 39 |
| le `Scaffold`+`AppBar`+bouton × 2 (§4.7) | 155 | `presentFormEdition` (`zcrud_screen`) — **déjà utilisé sur 16 sites d'IFFD (15 fichiers)** | — |

**Total : ~2 863 lignes d'IFFD face à ~4 582 lignes de socle déjà écrites, testées et
documentées.** Le socle en offre davantage (correction différée `ZCorrectionVisibility`, découpe
par qualité, anneaux de progression, badge flamme, `ZSessionCardSwiper` qui confine
`flutter_card_swiper`) — mais surtout, il porte trois propriétés qu'IFFD n'a pas :
**zéro écriture SRS garantie par le type** (le constructeur n'a aucun seam `reviewer`), **zéro
`Semantics` manquant** (AD-13 par construction, contre 0 `Semantics(` chez IFFD), et **le
déterminisme total** (aucun `DateTime.now()` dans le moteur, contre le tirage
`DateTime.now().millisecond % n` des banques de messages).

### 6.1 Les widgets maison qui refont ce que le socle fait

| Widget maison | Fichier:ligne | Lignes | Homologue socle |
|---|---|---:|---|
| `WhiteExamPage` | `flashcards/pages/white_exam_page.dart:20` | 779 | `ZWhiteExamSessionEngine` + `ZListSessionView` |
| `WhiteExamQuestionCard` | `flashcards/widgets/white_exam_question_card.dart:20` | 1 139 | `ZFlashcardAnswerInput` (+ `ZFlashcardReviewCard`) |
| `InteractiveFlashcardRepetitionCard` | `flashcards/widgets/interactive_flashcard_repetition_card.dart:25` | 1 205 | idem |
| `LearningModeQuestionCard` | `flashcards/widgets/learning_mode_question_card.dart:14` | 251 | `ZFeedbackBank`/`ZDefaultFeedbackBank` + `z_session_feedback.dart` |
| `LearningCelebrationPage` | `flashcards/pages/flashcards_learning_celebration_page.dart:7` | 403 | `ZSessionSummaryView` |
| `TestExamFilterScreen` | `flashcards/widgets/test_exam_filter_screen.dart:10` | 134 | `ZTestFiltersDialog` |
| `TestExamFilterZcrudScreen` | `flashcards/widgets/test_exam_filter_zcrud_screen.dart:270` | 376 | `ZTestFiltersDialog` + `presentFormEdition` |
| `ExamsListItemBuilder` | `administration/pages/exams_page.dart:255` | 79 | (aucun — voir §8) |
| `ExamActionsDialogWidget` | `administration/widgets/exam_actions_dialog_widget.dart:15` | 76 | `ZRowActionMenu` (`zcrud_screen`) |
| `ExamZcrudEditionScreen` | `administration/dialogs/exam_zcrud_edition.dart:383` | 130 | `presentFormEdition` |

### 6.2 Thème et RTL

268 couleurs en dur (`Colors.*` ou `Color(0x…)`) dans 6 fichiers du runtime d'épreuve :

```
 31  white_exam_page.dart                       67  white_exam_question_card.dart
 54  interactive_flashcard_repetition_card.dart 57  flashcard_repetition_widgets.dart
 57  folder_flashcards_repetitions_page.dart     2  exam_actions_dialog_widget.dart
```

3 sites non directionnels (`EdgeInsets.only(left:|right:)` / `Alignment.centerLeft|Right` /
`TextAlign.left|right`) : `white_exam_page.dart`, `flashcard_repetition_widgets.dart`,
`folder_flashcards_repetitions_page.dart`, 1 chacun. Les fichiers d'administration en sont
indemnes (0 couleur en dur, 0 site non directionnel).

---

## 7. Ce que le domaine fait de PARTICULIER

Ce qui suit résiste à la généralisation — ou l'a déjà éprouvée.

### 7.1 Le rappel hebdomadaire absolu — la CR déjà gagnée

`ExamModel.reminderDays: List<WeekDays>` signifie « rappelle-moi **ces jours de la semaine** ».
`ZExam.reminderDaysBefore: List<int>` signifiait « rappelle-moi **N jours avant l'échéance** ».
Les deux ne sont **pas** inter-convertibles — « lundi » n'est pas « k jours avant »
(`z_backed_exam_repository.dart:29-40`). Le socle a reconnu la seconde famille au lieu d'en
imposer une : `ZReminderRecurrence` porte `daysBefore` **et** `weekdays`, livré par CR-IFFD-17 en
zcrud v0.5.1. C'est le patron : la particularité d'IFFD est devenue une capacité du socle sans
que l'autre modèle disparaisse.

### 7.2 L'ACL par année académique

Le droit n'est pas « peut créer un examen » mais « peut créer un examen **de l'année
2024-2025** ». La clé est `"ExamModel$accademicYear"` (6 sites, §3.4) et une `CrudableObject` est
créée **par année** (`permission_helpers.dart:91-100`). Aucune ACL de zcrud n'a cette forme
composée aujourd'hui.

### 7.3 L'année académique comme dimension de tout

`accademicYear` (orthographe legacy, jamais corrigée) traverse le modèle, chaque requête
(`exames_dialogs.dart:69-92` construit trois `DataRequest` distinctes — mienne, communautaire,
admin), les permissions et le titre affiché. Il n'a **aucun homologue** dans `ZExam` : il voyage
en `extra['iffd_accademic_year']`.

### 7.4 La visibilité communautaire filtrée par la promotion

Le sélecteur de dossier d'un examen n'offre pas « tous les dossiers » : il unit les dossiers de
l'auditeur et les dossiers **publics de ses camarades de promotion**, puis filtre encore par les
modules de son cycle et de sa filière (`exames_dialogs.dart:76-109`). Un administrateur voit tout.
La requête est construite à partir des **permissions**, pas d'un autre champ du formulaire — c'est
pourquoi le jumeau porté la passe par la source injectée et non par `filterKeys`
(`exam_zcrud_edition.dart:121-124`).

### 7.5 La dérivation « un champ qui en dérive un autre »

Choisir un dossier réécrit le titre : `Examen: <titre du dossier>`. Le legacy l'écrit **trois
fois** parce qu'il a trois lieux de vérité (`exames_dialogs.dart:169-183`) ; le portage l'écrit
**une** fois (`exam_zcrud_edition.dart:365-368`). Le fichier signale que `ZFieldSpec` n'a « ni
`onChange`, ni `derivedFrom` » (`:41-60`) et que le câblage est donc impératif, avec un jeton de
génération contre les résolutions obsolètes (`:321,354,363`). **Motif générique, aucune règle
IFFD dedans** — candidat d'assemblage, et le fichier le dit lui-même.

Un arbitrage produit s'y est greffé (D5, tranché 2026-07-24) : un dossier sans titre ne produit
plus `"Examen: null"` mais `"Examen"` (`exam_zcrud_edition.dart:176-179`).

### 7.6 La consigne de notation adaptée à la filière

`evaluateFlashcardAnswerPrompt` (`domain/services/ai/ai_prompt_generator.dart:531-572`) préfixe
la consigne par `_filierePreprompt(userData:)` — le modèle sait à quelle filière et quel cycle
appartient l'auditeur avant de noter. Le barème 1-5 est ensuite dicté en toutes lettres, et la
réponse contrainte à « UNIQUEMENT le chiffre ». Trois implémentations le servent :
`iffd_ai_repository_impl.dart:1117` (1 377 l.), `openai_ai_repository_impl.dart:516` (672 l.),
`cloud_functions_ai_repository_impl.dart:343` (499 l.) — même interface
(`domain/repositories/ai_repository.dart:343-353`), 32-33 méthodes chacune.

### 7.7 Les trois seuils de maîtrise nommés en français

`mauvais` (qualité 1-2), `bon` (3), `maitrise` (4-5) — plus une règle non écrite dans le libellé :
**une carte jamais pratiquée (qualité 0) compte comme « mauvais »**
(`utils/flashcard_filters.dart:49-52`). Le socle a `ZMasteryLevel` ; la clé de repli est un
identifiant sans accent (`maitrise`) qui devra être mappé, pas traduit.

### 7.8 Le QCM dont l'unicité est déduite

Aucun champ ne dit si un QCM est à choix simple : c'est **compté** à l'affichage —
`rightAnswersCount == 1` ⇒ choix simple (`white_exam_question_card.dart:681-682`, et le jumeau
`interactive_flashcard_repetition_card.dart:688-689`). Une carte à une seule bonne réponse
devient donc mécaniquement un radio, une carte à deux devient des cases. Règle implicite,
dupliquée, jamais testée.

### 7.9 Le seuil de réussite à 3, et la moyenne sur 5

Une réponse compte « correcte » à partir de **3/5** (`white_exam_page.dart:513-515`, commenté
« user's requirement ») ; le score global est `cumul / (réponses × 5)` (`:636-639`) et le bandeau
vire au vert à **70 %** de réponses correctes (`:652-654`). Trois constantes de produit, en dur,
sur trois lignes différentes. Le socle réutilise `ZSrsConfig.passThreshold` « jamais un littéral
en dur » (`z_white_exam_session_engine.dart:34-36`).

### 7.10 L'examen est aussi un rendez-vous d'agenda

`ExamModel.toAppointment()` (`exam_model.dart:130-141`) produit un `Appointment` Syncfusion
journée entière, teinté teal (`workflow/models/appointment.dart:17`), agrégé avec tâches et
événements dans `workflow/source.dart:38` et affiché par `workflow/screens/agenda_screen.dart:277`.
Aucun paquet zcrud ne couvre cette projection calendrier.

---

## 8. Ce qui manque au socle, vu d'ici

Trois assemblages sont réclamés par le code lu, dans l'ordre de ce qu'ils feraient économiser :

1. **L'écran de liste d'entités datées groupées par échéance.** §4.2 : deux copies à 80 %
   identiques, tri par date, grille responsive calculée à la main sur `Get.width`, tuiles,
   états vides. `ZCrudScreen` existe (`zcrud_screen`) mais n'est utilisé **nulle part** dans
   IFFD (`grep -rl "ZCrudScreen" lib` → 0). Il faudrait mesurer s'il couvre le groupement par
   échéance et la grille, ou si c'est un assemblage voisin.

2. **La dérivation déclarative d'un champ par un autre.** §7.5 — le fichier de portage la
   nomme lui-même « CR SOCLE CANDIDATE, motif GÉNÉRIQUE, rien d'IFFD là-dedans »
   (`exam_zcrud_edition.dart:41-60`), avec ses deux limites mesurées : `_syncText` ne réécrit
   le buffer que hors focus, et rien ne sérialise deux résolutions asynchrones rapprochées.

3. **L'ACL composée `<Type><Portée>`.** §7.2/§3.4 — six sites reconstruisent la clé par
   concaténation. Une portée déclarée (`ZAcl` paramétré par une dimension) éviterait une chaîne
   littérale répétée dans six fichiers.

Et un rappel de méthode : **le drapeau `testExamFilter` bascule un écran qui n'est pas sous
`IffdZcrudScope`** (§5.2). Une QA de ce drapeau mesurerait aujourd'hui un écran privé de la
casse par défaut, du port numérique et du présentateur de sélection — c'est-à-dire un écart
attribué au portage alors qu'il vient d'un montage manquant.

---

## 9. Ordre de bataille suggéré

Rien de ceci n'est un plan d'exécution : c'est ce que les mesures ci-dessus rendent évident.

| # | Geste | Fondé sur |
|---|---|---|
| 1 | Monter `TestExamFilterZcrudScreen` sous `IffdZcrudScope` **avant** toute QA du drapeau | §5.2 |
| 2 | Trancher le sort de `WhiteExamPage` : 779 lignes mortes, décrivant un comportement que personne ne voit | §2.4 |
| 3 | Adopter `zApplyTestFilters` / `ZFlashcardTestFilters` — fonction pure, 90 lignes rendues, aucune UI en jeu | §6 |
| 4 | Faire passer les 2 formulaires du domaine à `presentFormEdition` (16 sites, 15 fichiers, l'ont déjà fait) | §4.7 |
| 5 | Extraire les 23 lignes identiques à l'octet des dégradés par type (3 sites) | §4.4 |
| 6 | Confronter le runtime d'épreuve à `ZWhiteExamSessionEngine` + `ZListSessionView` + `ZFlashcardAnswerInput` | §6 |
| 7 | Émettre la CR « champ dérivé » — le motif est nommé et documenté par IFFD lui-même | §7.5, §8.2 |

---

## Annexe — inventaire des 26 fichiers de production

| Fichier | Lignes |
|---|---:|
| `lib/src/domain/models/exam_model.dart` | 168 |
| `lib/src/domain/repositories/exams_repository.dart` | 57 |
| `lib/src/data/repositories/z_backed_exam_repository.dart` | 912 |
| `lib/src/features/exams/exams_module.dart` | 1 |
| `lib/src/features/exams/providers/exam_providers.dart` | 24 |
| `lib/src/features/exams/providers/exam_providers.g.dart` | 113 |
| `lib/src/presentation/features/administration/pages/exams_page.dart` | 333 |
| `lib/src/presentation/features/administration/dialogs/exames_dialogs.dart` | 282 |
| `lib/src/presentation/features/administration/dialogs/exam_zcrud_edition.dart` | 513 |
| `lib/src/presentation/features/administration/widgets/exam_actions_dialog_widget.dart` | 76 |
| `lib/src/presentation/features/flashcards/pages/white_exam_page.dart` | 779 |
| `lib/src/presentation/features/flashcards/widgets/white_exam_question_card.dart` | 1 139 |
| `lib/src/presentation/features/flashcards/widgets/interactive_flashcard_repetition_card.dart` | 1 205 |
| `lib/src/presentation/features/flashcards/widgets/learning_mode_question_card.dart` | 251 |
| `lib/src/presentation/features/flashcards/widgets/flashcard_repetition_widgets.dart` | 717 |
| `lib/src/presentation/features/flashcards/pages/folder_flashcards_repetitions_page.dart` | 1 202 |
| `lib/src/presentation/features/flashcards/pages/flashcards_learning_celebration_page.dart` | 403 |
| `lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart` | 199 |
| `lib/src/presentation/features/flashcards/widgets/test_exam_filter_screen.dart` | 134 |
| `lib/src/presentation/features/flashcards/widgets/test_exam_filter_zcrud_screen.dart` | 376 |
| `lib/src/utils/flashcard_filters.dart` | 90 |
| `lib/src/presentation/features/flashcards/zcrud/flashcards_questions_count_zcrud_edition.dart` | 276 |
| `lib/src/presentation/shared/zcrud/z_questions_counts_field.dart` | 169 |
| `lib/src/presentation/features/flashcards/zcrud/srs_quality_zcrud.dart` | 183 |
| `lib/src/presentation/features/flashcards/zcrud/review_session_zcrud.dart` | 131 |
| `lib/src/presentation/features/flashcards/zcrud/review_card_zcrud.dart` | 180 |
| **Total** | **9 913** |

Chaîne de correction IA, partagée avec d'autres domaines et donc **non comptée** ci-dessus :
`domain/repositories/ai_repository.dart` (494), `domain/services/ai/ai_prompt_generator.dart` (597),
`data/repositories/iffd_ai_repository_impl.dart` (1 377), `openai_ai_repository_impl.dart` (672),
`cloud_functions_ai_repository_impl.dart` (499) — **3 639 lignes**.

---

## 10. Contrôle de second passage — 2026-08-26, sondage sur disque

Le présent document a été produit par un premier passage interrompu. Un second passage en a
**resondé sept affirmations chiffrées** directement sur disque (dépôt hôte en lecture seule,
`HEAD = 65d1af9`, inchangé depuis le premier passage). Résultat : **six exactes, une erreur de
nommage corrigée**.

| # | Affirmation resondée | Commande | Verdict |
|---|---|---|---|
| 1 | Périmètre annoncé = 3 fichiers / 138 l. | `find lib/src/features/exams -type f \| wc -l` ; `wc -l` | ✅ 3 / 138 |
| 2 | `WhiteExamPageRoute` jamais poussée | `grep -rn 'WhiteExamPageRoute' lib \| grep -v app_router.gr.dart \| wc -l` | ✅ **0** |
| 3 | Écran de formulaire zcrud monté à la main × 12 | `grep -rl "label: 'Enregistrer'," lib \| wc -l` | ✅ 12 |
| 4 | 52 drapeaux ; `exam` `:673`, `testExamFilter` `:362`, `flashcardsQuestionsCount` `:348` | `grep -c "^  ZQaFlag($"` + `grep -n "id: '…'"` | ✅ 52 / 985 l., lignes exactes |
| 5 | Domaine = 26 fichiers / 9 913 l. | `wc -l` sur les 26 chemins de l'annexe | ✅ **9913 total** |
| 6 | Dégradés par type : 3 sites **identiques à l'octet** | `sed`+`diff` après normalisation d'indentation | ✅ `diff` vide **deux fois** |
| 7 | Homologues du socle absents d'IFFD / présents en `zcrud_session` | `grep -rn … lib \| wc -l` (hôte) puis `wc -l` (socle) | ⚠️ voir erratum |

**Détail du contrôle 7.** Les dix symboles sont bien à **0** dans `lib/` de l'hôte
(`ZWhiteExamSessionEngine`, `ZWhiteExamSessionController`, `ZListSessionView`,
`ZWhiteExamSessionView`, `ZTestFiltersDialog`, `zApplyTestFilters`, `ZFlashcardTestFilters`,
`ZSessionSummaryView`, `ZTimerDisplay`, `ZCrudScreen`, `ZCorrectionVisibility`,
`ZSessionQualityBreakdown`, `ZSessionCardSwiper` — **13 greps à 0**). Les tailles annoncées en §6
sont exactes à la ligne près :

```
420  z_white_exam_session_engine.dart      411  z_test_filters_dialog.dart
 97  z_white_exam_session_controller.dart 1645  z_flashcard_answer_input.dart
704  z_list_session_view.dart              846  z_session_summary_view.dart
283  z_white_exam_session_view.dart         39  z_timer_display.dart
137  z_session_feedback.dart               153  z_session_feedback_bank.dart
```

### 🔴 Erratum corrigé — un symbole du socle avait été mal nommé

Le premier passage citait **`ZSessionFeedbackBank`** (§6, §6.1 et le bloc de grep négatif). **Ce
symbole n'existe nulle part dans le socle** — grep négatif montré :

```
$ grep -rn --include='*.dart' "ZSessionFeedbackBank" packages/
(aucune ligne)
```

Les noms réels sont **`ZFeedbackBank`** (abstrait, `zcrud_session/lib/src/presentation/z_session_feedback_bank.dart:38`)
et **`ZDefaultFeedbackBank`** (`:51`), dans un fichier de **153 lignes**. La capacité est donc bien
là — seule l'étiquette était fausse. Les trois occurrences ont été corrigées dans ce document.

⚠️ **Portée de l'erratum** : le grep négatif « `ZSessionFeedbackBank : 0` » était **vide de sens**
(un symbole inexistant est à 0 partout). Resondé sous les vrais noms, le constat **tient** :
`ZFeedbackBank` = 0 et `ZDefaultFeedbackBank` = 0 dans `lib/` de l'hôte. La conclusion de §4.6 —
IFFD écrit deux banques de messages là où le socle en porte une — est donc **confirmée**, sur une
preuve valide cette fois.

C'est l'illustration exacte de la règle maison : *une absence n'est un constat que si son grep est
montré* — et un grep montré doit encore porter sur un symbole qui existe.

### Complément — le lot CR-IFFD-114 → 120 touche ce domaine par la bande

Le rapport ne citait que CR-IFFD-17 (§7.1). Le lot **S6 émis le 2026-08-25**
(`docs/zcrud-change-requests.md:97-113`) concerne le **lecteur riche et l'éditeur plein écran** :
3 CR émises (**114** géométrie du tableau markdown fermée ; **115** retour à la ligne souple recollé
en espace, *« un site n'a PAS été porté pour cette raison »* ; **116** absence de sous-titre du
dialogue plein écran, **quatrième** surface du même motif) et **4 retraits avant émission**
(117-120, canal existant trouvé).

Lien avec les examens : la **réponse libre** d'une épreuve est saisie et rendue en markdown riche
(`white_exam_question_card.dart:864-904`), avec un facteur d'échelle du lecteur qui **diverge entre
les deux copies** (`1.0` contre `1.1`, §4.3). Toute reprise de ces cartes sur le canal riche du
socle hérite donc des trois CR ouvertes du lot S6 — à vérifier livrées avant de mesurer une parité.

### Second correctif — « 16 fichiers » était « 16 sites dans 15 fichiers »

Resondé : `grep -rn "presentFormEdition(" lib` = **16**, `grep -rln` = **15** — un fichier porte
deux appels. Les trois formulations concernées (§4.7, §6, §9) ont été rectifiées. L'ordre de
grandeur et la conclusion sont inchangés.

Trois autres compteurs de câblage ont été resondés et sont **exacts** : 196 imports `zcrud_*`
pour 22 paquets distincts ; **24 montages** de `IffdZcrudScope` dans **22 fichiers** ;
`buildConfirmDialog` appelé **35** fois ; 12 classes héritant de `StatelessItemDialogWidget`.
