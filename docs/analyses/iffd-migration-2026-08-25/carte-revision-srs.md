# Carte du domaine « Révision — flashcards, répétition espacée, sessions, gamification » (IFFD)

**Dépôt cartographié** : `/home/zakarius/DEV/iffd` (LECTURE SEULE — aucune écriture)
**Commit de tête au moment du relevé** : `e36c490` *« feat(zcrud): v3.20.0 + v3.21.0 adoptées — CR-112 livrée… »*
**Socle consommé** : zcrud **`ref: v3.21.0`** (`pubspec.yaml:308,313,318` …), **23 paquets `zcrud_*` en `dependencies`**, **25 en `dependency_overrides`**
**Date du relevé** : 2026-08-25

---

## 0. Périmètre retenu — et ce qui a été ajouté au point de départ

Le point de départ fourni était : `lib/src/presentation/features/flashcards/`, `lib/src/features/flashcards/`, `lib/src/features/gamification/`, `lib/src/domain/models/flashcard/`, `lib/src/domain/models/flashcard_tag/`.

🔴 **Deux des cinq chemins fournis sont VIDES.** Grep négatif montré :

```
$ ls -la lib/src/domain/models/flashcard/ lib/src/domain/models/flashcard_tag/
lib/src/domain/models/flashcard/:      total 8   (. et .. seulement)
lib/src/domain/models/flashcard_tag/:  total 8   (. et .. seulement)
```

Les modèles vivent **un cran plus haut**, à plat : `lib/src/domain/models/flashcard_model.dart`, `flashcard_repetition_info.dart`, `flashcard_tag_model.dart`.

🔴 **`lib/src/features/gamification/` est un squelette VIDE.** Grep négatif montré :

```
$ find lib/src/features/gamification -type f -o -type d
lib/src/features/gamification
lib/src/features/gamification/gamification_module.dart
lib/src/features/gamification/pages          (vide)
lib/src/features/gamification/providers      (vide)
lib/src/features/gamification/widgets        (vide)
$ wc -c lib/src/features/gamification/gamification_module.dart
0 lib/src/features/gamification/gamification_module.dart
$ grep -rn "gamification" lib/ --include='*.dart'
src/core/constants/firestore_paths.dart:34:  static const String leagues = 'global/gamification/leagues';
src/config/themes/iffd_tokens.dart:78:  /// Dark theme tokens (same gamification colors, adjusted surfaces)
```

Aucun fichier Dart n'importe ce module. La gamification **réelle** vit ailleurs (§ 2.7).

### Périmètre effectivement cartographié

| Groupe | Fichiers | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/flashcards/**` | 30 | **15 953** |
| `lib/src/features/flashcards/**` (2 + 1 `.g.dart`) + `features/gamification/**` (1 vide) | 4 | **553** |
| Modèles + contrats de dépôt + adaptateurs de données (§ 3) | 10 | **3 250** |
| `folders/zcrud/study_tools_zcrud_adapter.dart` + `study_tools_zcrud_flag.dart` (suivis : consommés par `flashcard_list_zcrud.dart:36`) | 2 | **1 006** |
| **TOTAL périmètre étendu** | **46** | **20 762** |

**Suivi au-delà du point de départ** (dépendances réelles) :
- `lib/src/domain/models/{flashcard_model,flashcard_repetition_info,flashcard_tag_model,exam_model}.dart`
- `lib/src/domain/repositories/{flashcard_repository,flashcard_repetition_repository,flashcard_tags_repository}.dart`
- `lib/src/data/repositories/{z_backed_flashcard_repository,z_backed_exam_repository,firebase_owner_scoped_repetition_store}.dart`
- `lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart` (libellés de la liste portée)
- `lib/src/domain/models/app_user.dart:273-274` (`currentStreak`, `lastStudyDate` — la gamification réelle)
- `lib/src/presentation/shared/zcrud/**` (13 fichiers, 2 471 l.) — colle zcrud commune, **hors périmètre propre** mais indispensable à toute migration

**Empreinte totale du mot « flashcard » dans l'application** : **157 fichiers Dart** le mentionnent
(`find lib -name '*.dart' | xargs grep -ln 'Flashcard\|flashcard' | wc -l`). Le domaine irrigue le
tableau de bord, les tâches quotidiennes, le chatbot IA, les dossiers et le carnet de notes.

---

## 1. Ce que le domaine SAIT FAIRE (capacités visibles par l'utilisateur)

Établi en lisant les écrans, les libellés et les branches de code, pas les noms de classes.

### 1.1 Créer et organiser des cartes

1. **Créer une flashcard à la main**, de quatre types : *QCM*, *Vrai/Faux*, *Question ouverte*, *Cas pratique* (`flashcard_model.dart:12-17`). Le formulaire change de forme selon le type (§ 4.1).
2. **Écrire question, réponse, propositions de QCM en texte riche** (markdown inline + **formules LaTeX**) — `flutter_markdown_latex` (`pubspec.yaml:118`), rendu via `DeltaToMarkdownHelper.normalizedMarkdown` à **22 sites** du périmètre.
3. **Ajouter un indice et une explication** (champs `indice`, `explanation`, texte simple 3 lignes).
4. **Classer une carte par balises** (`FlashcardTagModel` : titre + couleur), avec **création de balise à la volée** (`flashcards_dialogs.dart:224`) et **sélection multiple** (`showFlashcardTagsSelectionDialog`, `:555`).
5. **Rattacher une carte à sa source** : un document (+ n° de page), une note, un message de conversation IA (`documentId`/`pageNumber`/`noteId`/`chatConversationId`/`chatMessageId`).
6. **Classer une carte dans la nomenclature douanière du Système Harmonisé** : *Section (SH)* puis *Chapitre (SH)*, le second dépendant du premier (`flashcard_edition_screen.dart:85-120`).
7. **Éditer plusieurs cartes d'affilée dans un atelier deux panneaux** (liste à gauche, formulaire à droite ; disposition bureau / mobile) — `MultiFlashcardEditorPage`.
8. **Sélectionner par lot, tout sélectionner, supprimer la sélection** (`multi_flashcard_editor_page.dart:113-176`).
9. **Consulter un corpus embarqué en lecture seule** : les avis de classement du SH 2022 sont transformés en cartes non modifiables (`FlashcardModel.subjectDefaultFlashcards`, `flashcard_model.dart:322-408`, `isReadOnly: true`).

### 1.2 Générer des cartes automatiquement

10. **Générer des flashcards par IA à partir de trois sources** (`FlashcardGeneratorSource`, `flashcard_model.dart:35-46`) :
    - *Sujets / mots-clés* — sélection de balises et de sujets ;
    - *Texte* — coller ou écrire un texte ;
    - *Document* — un document existant, un fichier déposé, ou **un document scanné** (`_scanDocument`, `ai_flashcards_generator_dialog_widget.dart:972`).
11. **Choisir le nombre et la difficulté des questions à générer** (`QuestionsDifficulty`, `flashcard_edition_screen.dart:549`).
12. **Générer des cartes depuis une conversation du chatbot** (`chatbot_conversation_screen.dart:898`) et depuis le carnet de notes IA (`notebook_artifact_actions_iffd.dart:166`).
13. **Choisir le routeur / modèle IA** utilisé pour la génération et pour l'évaluation (`IffdAiRouterModel` passé de bout en bout ; réglage d'URL de base via `showAiBaseUrlDialog`, `smart_learn_controller.dart:435`).

### 1.3 Réviser

14. **Six modes de révision** (`FlashcardRepetitionPageType`, `folder_flashcards_repetitions_page.dart:30-37`) :

    | Mode | Ce que l'utilisateur en voit |
    |---|---|
    | `listOnly` | feuilleter les cartes sans noter ni écrire de progression |
    | `nFlashcardsLearningCycle` | « **Apprendre +N flashcards** » — cycle d'apprentissage sur un lot (30 par cycle, `flashcard_widgets.dart:706`) |
    | `allFlashcardsLearningCycle` | même chose sur tout le dossier |
    | `test` | « **Flashcards à réviser** » — les cartes échues ce jour, retirées de la file dès qu'elles sont répondues |
    | `whiteExam` | « **Test / examen blanc** » — toutes les questions, puis correction et score global |
    | `cramming` | bachotage : **aucune écriture SRS**, les cartes ratées reviennent 3 à 5 cartes plus loin (`flashcards_learing_controller.dart:88-107`) |

15. **Répondre réellement à la question**, pas seulement retourner la carte : cocher des propositions de QCM, choisir Vrai/Faux, **rédiger une réponse libre** (`_buildQCMInput` / `_buildTrueFalseInput` / `_buildTextInput`).
16. **Retourner la carte** pour voir la réponse (dépendance tierce `flip_card ^0.7.0`, `pubspec.yaml:178`, **12 sites** dans le périmètre).
17. **Demander des indices, un par un**, avec compteur (`_currentHintIndex`, `_indices`).
18. **Se faire noter automatiquement**, y compris **par l'IA sur les questions ouvertes** (`evaluateFlashcardAnswer`) avec **repli sur une notation locale** si l'IA échoue (`_manualEvaluateAnswer`).
19. **Dire « je ne sais pas »** (`isIDontKnow`) — noté 0 en mode examen.
20. **Se noter soi-même sur cinq paliers** : *Compliqué / Difficile / Ok / facile / Très Facile* (`FlashcardRepetitionQuality`, `flashcard_repetition_info.dart:180-201`), chacun annonçant sa prochaine échéance (« dans 2 cartes », « à la fin », « en 3 jours »).
    ⚠️ Ce geste **n'existe aujourd'hui que derrière un flag à `false`** (§ 5.3).
21. **Balayer les cartes** (`flutter_card_swiper ^7.0.2`) — gauche = raté, droite = réussi (`flashcards_learing_controller.dart:186-193`).
22. **Voir sa progression pendant la session** : « X/Y terminées (Z restantes) », pourcentage, barre segmentée colorée par qualité (`segmented_progress_bar`), points de position (`dots_indicator`).
23. **Être chronométré** : le temps de réponse est mesuré (`Stopwatch`) et transmis à l'évaluateur IA — **mais jamais affiché** (constat porté par `review_session_zcrud.dart:23`).
24. **Recevoir un message de retour personnalisé** après chaque réponse : félicitations, encouragement, ou relance en cas de « je ne sais pas » — tirés au hasard dans 4 à 6 formules (`white_exam_page.dart:490-543`).
25. **Voir un écran de célébration** en fin de cycle : trophée, confettis (`confetti ^0.8.0`), 3 statistiques, cercles animés (`LearningCelebrationPage`).

### 1.4 Choisir ce qu'on révise

26. **Filtrer la liste des cartes d'un dossier** par recherche texte, balises, documents, notes, section SH, chapitre SH, **et neuf familles d'outils d'évaluation douanière** (articles du GATT, annexes, notes interprétatives, décisions, avis consultatifs, commentaires, notes explicatives, études de cas, études) — `FolderFlashcardsListController.filter`, `folder_flashcards_list_page.dart:178-262`.
27. **Configurer un test** : nombre de questions (max 30), types de questions, **niveaux de maîtrise**, balises, documents, notes (`test_exam_filter_screen.dart:42-121`).
28. **Voir la liste en grille responsive** (350 dp/colonne au-delà de 840 dp de large, 300 en dessous — `folder_flashcards_list_page.dart:500-510`).
29. **Voir le hub d'apprentissage d'un dossier** avec trois tuiles à progression circulaire : *Apprendre +N* / *Flashcards à réviser* / *Test* (`FlashcardsLearningModeScreen`, `flashcard_widgets.dart:636-1010`).

### 1.5 Exporter et partager

30. **Exporter des flashcards en PDF** avec un sous-titre de module saisi (`ExportFlashcardsToPdf`, 296 l., `pdf`/`printing`/`flutter_quill_to_pdf`).
31. **Exporter du markdown en PDF** avec un titre (`ExportMarkdownToPdf`, même fichier).

### 1.6 Réviser depuis ailleurs dans l'application

32. **Lancer une révision depuis les tâches quotidiennes** (`daily_tasks_page.dart:877`).
33. **Lancer une révision depuis le carnet de notes IA** (`notebook_artifact_actions_iffd.dart:154`, mode `allFlashcardsLearningCycle`).
34. **Lancer une révision depuis une conversation du chatbot** (`chatbot_conversation_screen.dart:854`).

### 1.7 Gamification — ce qui existe réellement

35. **Une flamme de série (« streak ») de jours consécutifs d'étude** : incrémentée si la dernière étude était hier, remise à 1 sinon, annoncée par un bandeau « 🔥 Flamme mise à jour: N jours! » (`folder_flashcards_repetitions_page.dart:112-171`), et affichée « N jours de suite ! » (`flashcard_widgets.dart:781-803`).

🔴 **C'est tout.** Grep négatif montré (points d'expérience, badges, succès, classement) :

```
$ grep -rniE "\bxp\b|xpPoints|badgeId|achievement|trophy|trophee|leaderboard|classement" \
    lib/src/presentation/features/flashcards lib/src/features lib/src/domain/models/app_user.dart
lib/src/presentation/features/flashcards/pages/flashcards_learning_celebration_page.dart:147:  // Trophy icon with glow
lib/src/presentation/features/flashcards/pages/flashcards_learning_celebration_page.dart:148:  _buildTrophyIcon(isDark),
lib/src/presentation/features/flashcards/pages/flashcards_learning_celebration_page.dart:241:  Widget _buildTrophyIcon(bool isDark) {
```

Les trois seules occurrences sont **l'icône décorative** de l'écran de célébration. Il existe par ailleurs un **chemin Firestore déclaré et inutilisé** : `firestore_paths.dart:34 → 'global/gamification/leagues'` (aucun lecteur dans `lib/`). **La gamification d'IFFD = une flamme de série, et rien d'autre.**

---

## 2. Les écrans

**Trois pages sont routées** (`@RoutePage`), une seule est déclarée dans le routeur manuel ; les autres sont poussées à la main (`MaterialPageRoute` / `showPushedDialog`).

| # | Écran | Chemin | Lignes | Rôle | Formulaire | Liste | Navigation | Rendu riche |
|---|---|---|---:|---|:-:|:-:|:-:|:-:|
| 1 | `FolderFlashcardsListPage` | `pages/folder_flashcards_list_page.dart:368` | **1 146** | Liste/grille des cartes d'un dossier, recherche, filtres, sélection multiple, actions | ✔ (filtre `:794`) | ✔ grille | ✔ route `/folder/:folderId/flashcards` | ✔ |
| 2 | `FolderFlashcardsRepetitionsPage` | `pages/folder_flashcards_repetitions_page.dart:40` | **1 202** | **Écran central de révision** : file de cartes, balayage, progression, streak, 6 modes | — | ✔ file | ✔ `@RoutePage` + 8 sites d'appel manuels | ✔ |
| 3 | `MultiFlashcardEditorPage` | `pages/multi_flashcard_editor_page.dart:33` | **1 287** | Atelier d'édition multi-cartes, deux panneaux, sélection par lot | ✔ (`:831`, `:977`) | ✔ barre latérale | ✔ `showMultiFlashcardEditorPage` (5 sites) | ✔ |
| 4 | `WhiteExamPage` | `pages/white_exam_page.dart:20` | **779** | Examen blanc : toutes les questions, correction, score, dialogue de résultats | ✔ (réponses) | ✔ | ✔ `@RoutePage` | ✔ |
| 5 | `LearningCelebrationPage` | `pages/flashcards_learning_celebration_page.dart:12` | **403** | Fin de cycle : trophée, confettis, 3 statistiques | — | — | ✔ (poussée depuis `:499`) | — |
| 6 | `FlashcardEditionScreen` (legacy) | `widgets/flashcard_edition_screen.dart:25` | **770** | Formulaire de carte legacy (22 `DynamicFormField`) + `FlashcardsQuestionsCountEditionScreen` (`:560`) | ✔✔ | — | dialogue | ✔ |
| 7 | `FlashcardZcrudEditionScreen` (porté) | `zcrud/flashcard_edition_zcrud.dart:412` | **579** | Même formulaire, porté sur `DynamicEdition` du socle | ✔✔ | — | dialogue (flag) | ✔ |
| 8 | `AiFlashcardsGeneratorDialogWidget` | `widgets/ai_flashcards_generator_dialog_widget.dart:32` | **1 238** | Générateur IA à 3 onglets (Documents / Sujets / Texte), dépôt de fichier, scan | ✔ | ✔ | dialogue plein écran | ✔ |
| 9 | `InteractiveFlashcardRepetitionCard` | `widgets/interactive_flashcard_repetition_card.dart:24` | **1 149** | Carte interactive : saisie de réponse, indices, chrono, évaluation, notation | ✔ | — | — | ✔ |
| 10 | `WhiteExamQuestionCard` | `widgets/white_exam_question_card.dart:18` | **1 066** | Même carte, variante examen (soumission différée, correction groupée) | ✔ | — | — | ✔ |
| 11 | `FlashcardCard` + `FlashcardAnwserWidget` + `FlashcardsLearningModeScreen` | `widgets/flashcard_widgets.dart:107,491,636` | **1 130** | Tuile de grille, affichage de réponse, **hub d'apprentissage du dossier** | — | ✔ | ✔ (3 tuiles → 3 modes) | ✔ |
| 12 | `FlashcardRepetitionCard` | `widgets/flashcard_repetition_widgets.dart:18` | **663** | Carte de révision « simple » (avec `FlipCard`) | — | — | — | ✔ |
| 13 | `SmartLearnController` | `controllers/smart_learn_controller.dart:53` | **568** | Contrôleur-orchestrateur global (voir § 6.1) | ✔ (dialogues) | — | ✔ | — |
| 14 | `flashcards_dialogs.dart` | `dialogs/flashcards_dialogs.dart` | **779** | 9 fonctions d'ouverture de dialogue + sélecteur de balises | ✔ | ✔ | ✔ | — |
| 15 | `TestExamFilterZcrudScreen` | `widgets/test_exam_filter_zcrud_screen.dart:270` | **376** | Configuration de test, portée sur le socle | ✔ | — | dialogue (flag) | — |
| 16 | `ExportFlashcardsToPdf` + `ExportMarkdownToPdf` | `widgets/export_flashcards_to_pdf.dart:29,165` | **296** | Export PDF (2 formulaires 1 champ) | ✔ | — | dialogue | ✔ |
| 17 | `AiBaseUrlZcrudEditionScreen` | `controllers/ai_base_url_zcrud_edition.dart:193` | **284** | Réglage de l'URL/routeur IA, porté | ✔ | — | dialogue (flag) | — |
| 18 | `LearningModeQuestionCard` | `widgets/learning_mode_question_card.dart:14` | **251** | Enveloppe de carte en mode apprentissage | — | — | — | ✔ |
| 19 | `FlashcardTagZcrudEditionScreen` | `dialogs/flashcard_tag_zcrud_edition.dart:151` | **241** | Édition d'une balise, portée | ✔ | — | dialogue (flag) | — |
| 20 | `FlashcardListZcrudView` | `zcrud/flashcard_list_zcrud.dart:124` | **219** | Grille de cartes portée sur `ZFlashcardListView` | — | ✔ | (flag) | ✔ |
| 21 | `MultiFlashcardEditorZcrudView` | `zcrud/multi_flashcard_editor_zcrud.dart:143` | **243** | Atelier multi-cartes porté sur `ZMultiFlashcardEditor` | ✔ | ✔ | (flag) | ✔ |
| 22 | `TestExamFilterScreen` (legacy) | `widgets/test_exam_filter_screen.dart:10` | **134** | Configuration de test legacy (6 `DynamicFormField`) | ✔ | — | dialogue | — |
| 23 | `FlashcardActionsDialogWidget` | `widgets/flashcard_actions_dialog_widget.dart:17` | **126** | Menu d'actions sur une carte | — | — | feuille | — |
| 24 | `FlashcardsCreationDialogWidget` | `widgets/flashcards_creation_dialog_widget.dart:16` | **103** | Choix de la source de création | — | — | feuille | — |
| 25 | `ReviewCardZcrudView` / `ReviewAnswerZcrudView` / `SrsQualityZcrudView` | `zcrud/review_card_zcrud.dart:131`, `review_session_zcrud.dart:77`, `srs_quality_zcrud.dart:156` | **180 + 131 + 183** | Les trois briques de révision portées sur le socle | ✔ | — | (2 sur 3 câblées, § 5.3) | ✔ |

**Les 4 écrans les plus lourds pèsent 4 414 lignes**, soit **28 % du périmètre de présentation**.
**Les 6 fichiers > 1 000 lignes pèsent 7 116 lignes**, soit **45 %**.

---

## 3. Modèles de domaine et persistance

### 3.1 Entités

| Entité | Fichier | Lignes | Champs | Sérialisation |
|---|---|---:|---:|---|
| `FlashcardModel` (`extends FolderContentModel`) | `domain/models/flashcard_model.dart:85` | **410** | 17 propres + 6 hérités | `toMap`/`fromMap`/`fromJson` **écrits à la main** |
| `FlashcardRepetitionInfo` (`extends DynamicModel`) | `domain/models/flashcard_repetition_info.dart:221` | **489** (fichier) | 15 | idem, à la main |
| `FlashcardTagModel` (`extends FolderContentModel`) | `domain/models/flashcard_tag_model.dart:9` | **90** | 2 propres (`title`, `color`) | idem |
| `ExamModel` (`extends DynamicModel`) | `domain/models/exam_model.dart:12` | **168** | 8 | idem |
| `QcmChoice` | `flashcard_model.dart:48` | — | 3 | idem |
| `QuestionType` (enum, 4 valeurs) | `flashcard_model.dart:12` | — | — | porte **sa couleur en dur** (`Color(0xFF4CAF50)`…) |
| `FlashcardRepetitionQuality` (enum, 5 paliers) | `flashcard_repetition_info.dart:180` | — | — | porte **son libellé, son icône, sa couleur et son texte d'échéance** |
| `FlashcardGeneratorSource` (enum, 3 valeurs) | `flashcard_model.dart:35` | — | — | porte titre + icône + sous-titre |

🔴 **Aucun codegen.** `toMap`/`fromMap`/`copyWith`/`props` sont écrits à la main sur les 4 entités.
Seul `flashcard_providers.g.dart` (478 l.) est généré, et c'est du **Riverpod**, pas de la sérialisation.
Grep : `grep -rn "@ZcrudModel\|@JsonSerializable" lib/src/domain/models/flashcard*` → aucune occurrence.

🔴 **Firestore fuit dans le domaine.** `cloud_firestore` est importé **directement** par
`flashcard_model.dart:4`, `flashcard_repetition_info.dart:7`, `flashcard_tag_model.dart:4`,
`exam_model.dart:4` et par le contrat `flashcard_repetition_repository.dart:3`
(`Timestamp.fromDate` dans un `DataRequest`). Le domaine n'est **pas** backend-agnostique.

🔴 **Flutter fuit aussi** : `flashcard_model.dart:5` importe `Color, Colors, IconData, Icons`,
`flashcard_tag_model.dart:5` importe `Color`. Une couleur de balise est persistée
en `toARGB32().toString()`.

### 3.2 Algorithme de répétition espacée

Deux implémentations coexistent dans **le même fichier**, arbitrées par un flag. L'implémentation maison tient en 100 lignes (`SmResponse` `:80-91`, `Sm` `:94-179`) :

| | Legacy `Sm.calc` (`flashcard_repetition_info.dart:94-179`) | Socle `ZSm2Scheduler` |
|---|---|---|
| Statut | **actif** | inactif |
| Flag | `kUseZcrudSm2Scheduler = false` (`:78`), lu en `:377` | — |
| Échec (q<3) | reps→0, intervalle→1 j, **EF intact** | reps→0, intervalle→1 j, **EF pénalisé** |
| Ordre | intervalle puis EF | EF puis intervalle |
| Bonus de retard | `+ (retard × 0,5).round()` | même valeur, **via `ZSrsConfig(overdueBonusFactor: 0.5)`** (`kIffdSrsConfig`, `:59`) |

Le fichier documente, mesuré, l'écart exact à la bascule (q=0 : EF 2,000 → 1,300 ; q=3 : 20 j → 19 j ;
q=5 : 20 j → 21 j) et nomme les trois tests à re-baser
(`test/characterization/flashcards_roundtrip_test.dart`).

**Lecture défensive** : `_intOrNull` (`:216`) accepte `int`, `num`, `String` entier ou décimal —
correctif d'un défaut où Firestore renvoyait `2.0` et **effaçait la progression de révision**
(`int.tryParse('2.0') == null` → repli au défaut `1`).

### 3.3 Contrats de dépôt

`CrudRepository<T>` (`domain/repositories/datacrud_repository.dart:23-63`) — **23 méthodes** :
`create` / `mapCreate` / `streamByIds` / `streamAll` / `streamOne` / `all` / `count` / `asyncCount` /
`batchDelete` / `find` / `batchSet` / `batchUpdate` / `update` / `mapUpdate` / `softDelete` /
`delete` / `restore` + ACL (`objectType`, `crudableObjects`).

Trois contrats spécialisés, chacun **presque vide**, l'essentiel vivant dans une `extension` :

| Contrat | Fichier | Lignes | Membres propres | Extension |
|---|---|---:|---:|---|
| `FlashcardRepository` | `flashcard_repository.dart:12` | 92 | 1 (`saveFolderFlashcards`) | 6 méthodes (§ streams par dossier/sujet, compteurs, suppression en cascade) |
| `FlashcardRepetitionRepository` | `flashcard_repetition_repository.dart:12` | 70 | **0** | 3 (`folderFlashcards`, `userRepetitions`, `deleteFlashcardRepetitions`) |
| `FlashcardTagsRepository` | `flashcard_tags_repository.dart:11` | 68 | **0** | 5 |

🔴 **Inversion de dépendance cassée** : les trois contrats de **domaine** importent
`presentation/features/flashcards/controllers/smart_learn_controller.dart`
(`flashcard_repository.dart:1`, `flashcard_repetition_repository.dart:5`, `flashcard_tags_repository.dart:1`,
et jusqu'à `datacrud_repository.dart:7`). Le domaine dépend de la présentation.

### 3.4 Source de données et erreurs

- **Une seule source : Firestore.** `FirebaseCrudRepositoryImpl<T>` (`data/repositories/firebase_crud_repository_impl.dart:18`, **499 l.**) porte tout le CRUD ; les trois dépôts du domaine en héritent en **3 à 40 lignes** chacun (`firebase_models_repositories_impls.dart:173,213,218`).
- **Erreurs** : type maison `DataState<T,E>` avec 8 sous-classes (`DataSuccess`, `DataFailed`, `DataNotSet`, `DataCreated`, `DataUpdated`, `DataDeleted`…), `utils/resources/data_state.dart`. **Ce n'est pas `Either<ZFailure,T>`** : `DataFailed` porte une `FirebaseException` **brute** (`FirestoreDataFailed(e)`, `:209,253,309`). Le type d'erreur du backend traverse toute la pile.
- **Pas de cache local ni d'offline-first dans ce domaine.** Grep négatif :

```
$ grep -rln "Hive\|persistenceEnabled\|Source.cache" lib/src/presentation/features/flashcards \
    lib/src/domain/models/flashcard_model.dart lib/src/domain/models/flashcard_repetition_info.dart
(aucun résultat)
```

  `IffdCacheManager` existe (`lib/src/iffd_cache_manager.dart`) mais aucun fichier du périmètre ne l'importe.
- **Pas de soft-delete effectif dans le domaine** : `softDelete` est déclaré sur le contrat, mais les appels du périmètre passent par `delete(item.id)` (`flashcard_repository.dart:69`).

### 3.5 Les deux adaptateurs « ZBacked » (écrits, testés, **non branchés**)

| Adaptateur | Fichier | Lignes | Statut |
|---|---|---:|---|
| `ZBackedFlashcardRepository` | `data/repositories/z_backed_flashcard_repository.dart` | **797** | branché derrière `useZcrudFlashcardRepositoryProvider` = **`false`** (`flashcard_providers.dart:23`) |
| `ZBackedExamRepository` | `data/repositories/z_backed_exam_repository.dart` | **912** | idem, non actif |
| `FirebaseOwnerScopedRepetitionStore` (`implements ZRepetitionStore`) | `data/repositories/firebase_owner_scoped_repetition_store.dart:42` | **154** | 🔴 **jamais instancié dans `lib/`** |

Grep négatif montré :

```
$ grep -rn "FirebaseOwnerScopedRepetitionStore(" lib/ --include='*.dart' \
    | grep -v "^lib/src/data/repositories/firebase_owner_scoped_repetition_store.dart"
(aucun résultat)
$ grep -rln "FirebaseOwnerScopedRepetitionStore(" test/
test/zcrud/owner_scoped_repetition_store_test.dart
```

`ZBackedFlashcardMapper` (`:135`) documente une **table de correspondance `FlashcardModel ↔ ZFlashcard`
sans perte** : 13 champs à homologue de schéma, **10 champs dans `extra` préfixés `iffd_`**
(`iffd_subject_id`, `iffd_creator_id`, `iffd_document_id`, `iffd_page_number`, `iffd_note_id`,
`iffd_hs_section`, `iffd_hs_chapter`, `iffd_chat_conversation_id`, `iffd_chat_message_id`,
plus les doublures de fidélité `iffd_type`, `iffd_question`, `iffd_choices`).

---

## 4. LE CODE RÉPÉTÉ — le point décisif

Méthode : détection de clones par appariement de séquences sur lignes normalisées
(commentaires et ponctuation structurelle retirés), plus relevé manuel des motifs nommés.
Chiffres reproductibles avec les scripts décrits en § 8.

### 4.1 🔴 Le schéma du formulaire de flashcard, déclaré **3 fois**

| Site | Fichier:lignes | Lignes | Champs déclarés |
|---|---|---:|---:|
| 1 | `widgets/flashcard_edition_screen.dart:82-345` | **264** | 11 (`Systeme Harmonisé` → `hsSection`, `hsChapter`, `type`, `question`, `answer`, `isTrue`, `choices{isCorrect,content}`, `indice`, `explanation`) |
| 2 | `pages/multi_flashcard_editor_page.dart:849-1140` | **292** | les **mêmes 11** |
| 3 | `zcrud/flashcard_edition_zcrud.dart:107-400` | ~290 | les mêmes, réécrits en `ZFieldSpec` |

**Similarité mesurée entre les sites 1 et 2 : 72 %, 199 lignes normalisées identiques.**
Blocs contigus identiques : `:84-99` ↔ `:851-866` (16 l.), `:201-225` ↔ `:984-1008` (20 l.),
`:269-288` ↔ `:1067-1086` (17 l.), `:448-467` ↔ `:1157-1176` (17 l.), `:503-532` ↔ `:1211-1240` (23 l.).

L'ensemble du bloc « Système Harmonisé » — dont la construction dynamique des chapitres
depuis la section — est **copié caractère pour caractère**, à l'indentation et à un appel
`onChange(...)` supplémentaire près.

⇒ **Un même formulaire, trois sources de vérité.** Toute évolution de schéma doit être
faite trois fois ou diverge. C'est exactement le défaut que `@ZcrudModel → ZFieldSpec[]` supprime.

### 4.2 🔴 Les trois « cartes de question », clones à 3 exemplaires

| Paire | Lignes communes (blocs ≥ 6 l.) | Tailles |
|---|---:|---|
| `interactive_flashcard_repetition_card.dart` ↔ `white_exam_question_card.dart` | **124** | 791 ↔ 762 (l. normalisées) |
| `flashcard_repetition_widgets.dart` ↔ `interactive_flashcard_repetition_card.dart` | **101** | 488 ↔ 791 |
| `flashcard_repetition_widgets.dart` ↔ `white_exam_question_card.dart` | **41** | 488 ↔ 762 |

Méthodes portant **le même nom** dans plusieurs fichiers, avec leur similarité mesurée :

| Méthode | Sites | Tailles | Lignes communes | Similarité |
|---|---:|---|---:|---:|
| `_buildQCMInput` | 2 (`interactive:649`, `white_exam:660`) | 82 / 82 | 70 | **90 %** |
| `_buildInstructionBadge` | 2 (`repetition_widgets:390`, `interactive:572`) | 60 / 64 | 52 | **88 %** |
| `_buildTrueFalseInput` | 2 (`interactive:732`, `white_exam:743`) | 102 / 87 | 70 | **78 %** |
| `_buildTextInput` | 2 (`interactive:835`, `white_exam:831`) | 20 / 25 | 14 | 65 % |
| `_buildFooter` | 2 (`repetition_widgets:579`, `interactive:1074`) | 84 / 75 | 47 | 59 % |
| `_buildHeader` | **3** (`ai_generator:239`, `repetition_widgets:286`, `interactive:543`) | 21 / 103 / 28 | 20 | 31 % |
| `_buildActionButtons` | 2 (`celebration:365`, `interactive:942`) | 38 / 115 | — | — |

Le seul diff de `_buildQCMInput` tient en **trois différences sémantiquement nulles** :
`_isSubmitted` vs `widget.isSubmitted`, `onChanged: null` vs `enabled: false`, et un
`textScaleFactor` de 1,1 au lieu de 1,0. **Les 78 lignes de logique de sélection QCM
(choix unique vs multiple, cochage, décochage) sont écrites deux fois.**

⇒ **~265 lignes de rendu de question dupliquées** sur les seules paires mesurées.

### 4.3 🔴 L'évaluation de réponse, écrite **2 fois**

| Site | Fichier:lignes | Lignes | Ce qu'il fait |
|---|---|---:|---|
| 1 | `interactive_flashcard_repetition_card.dart:205-310` | **106** | `_evaluateAnswer` (IA + repli) + `_getCorrectAnswerText` + `_getUserAnswerText` + `_manualEvaluateAnswer` |
| 2 | `white_exam_page.dart:548-620` | **73** | `_evaluateAnswer` + `_evaluateOpenAnswer` |

Même règle métier aux deux endroits : QCM correct ⇒ **5**, sinon **1** ; Vrai/Faux correct ⇒ **5**,
sinon **1** ; question ouverte ⇒ appel IA `evaluateFlashcardAnswer`, repli **3**.
Le site 1 rend un `int`, le site 2 un `double`. La divergence est déjà présente :
le site 2 traite « je ne sais pas » (retour `0`), pas le site 1.

### 4.4 🔴 Le filtre par listes d'identifiants, écrit **15 fois × 4 endroits**

Dans le seul `FolderFlashcardsListController` (`folder_flashcards_list_page.dart:39-345`), le même
concept « filtrer par une liste d'identifiants sélectionnés » est décliné **15 fois**, à **4 endroits chacun** :

| Endroit | Sites | Lignes/site | Total |
|---|---:|---:|---:|
| Déclaration `List<String> selectedXxxIds = []` (`:41-59`) | 15 | 1 | **15** |
| Méthode `void selectXxx([List<String?>? ids])` (`:81-176`) | **16** | 5 | **80** |
| Prédicat `if (selectedXxxIds.isNotEmpty && …) return false;` (`:186-259`) | 15 | 4 | **60** |
| Aller-retour `fromMap` / `toMap` (`:263-315`) | 15 × 2 | 1-2 | **~45** |
| **TOTAL** | | | **≈ 200 lignes** |

🔴 Pire : **neuf de ces quinze filtres testent la MÊME propriété** — `el.noteId` :
`selectedAccordArticlesIds`, `selectedAnnexesIds`, `selectedNotesInterpretativesIds`,
`selectedDecisionsIds`, `selectedAvisConsultatifsIds`, `selectedCommentairesIds`,
`selectedNotesExplicativesIds`, `selectedEtudeDeCasIds`, `selectedEtudesIds`
(`:200-243`). Neuf blocs de quatre lignes rigoureusement interchangeables.

Le corps de `selectXxx` est identique à un nom près :

```dart
void selectTags([List<String?>? ids]) {
  if (ids == null) return;
  selectedTagsIds = ids.whereType<String>().toList();
  refreshUI();
}
```

### 4.5 Le squelette d'écran d'édition zcrud, écrit **13 fois** (dont 4 dans ce périmètre)

Motif : `class XZcrudEditionScreen extends StatefulWidget` → `_fields` / `_controller` /
`ZEditionSubmitController` → `initState` → `dispose` → `_onSave` → `build` =
`IffdZcrudScope(child: Scaffold(appBar: …, body: DynamicEdition(...)))`.

| Fichier | Bloc (classe → fin de fichier) |
|---|---:|
| `ai_routers/zcrud/ai_router_zcrud_edition.dart:444` | 261 |
| `folders/dialogs/folder_zcrud_edition.dart:374` | 183 |
| **`flashcards/zcrud/flashcard_edition_zcrud.dart:412`** | **168** |
| `administration/dialogs/exam_zcrud_edition.dart:383` | 131 |
| `subjects/dialogs/subject_zcrud_edition.dart:605` | 124 |
| `smartnotes/dialogs/smartnote_zcrud_edition.dart:225` | 118 |
| `valuation_tools/.../valuation_tool_model_zcrud_edition.dart:232` | 117 |
| `mindmap/dialogs/mindmap_zcrud_edition.dart:199` | 110 |
| **`flashcards/widgets/test_exam_filter_zcrud_screen.dart:270`** | **107** |
| **`flashcards/controllers/ai_base_url_zcrud_edition.dart:193`** | **92** |
| **`flashcards/dialogs/flashcard_tag_zcrud_edition.dart:151`** | **91** |
| `documents/dialogs/folder_document_zcrud_edition.dart:122` | 91 |
| `administration/dialogs/auditeur_account_zcrud_edition.dart` | (162 l. de fichier) |
| **TOTAL** | **≈ 1 593 lignes sur 13 sites** |

Clones contigus mesurés à l'intérieur du périmètre :
`ai_base_url_zcrud_edition.dart:239-280` ↔ `flashcard_tag_zcrud_edition.dart:196-237` = **26 lignes identiques** ;
mêmes fichiers ↔ `test_exam_filter_zcrud_screen.dart:354-367` = **12 lignes à 3 sites**.

⇒ **Signal d'assemblage manquant côté socle** : un écran CRUD complet (scope + barre + action
« Enregistrer » accessible ≥ 48 dp + `DynamicEdition` + soumission) devrait être **une brique**,
pas un patron à recopier.

### 4.6 Le bloc de bascule strangler-fig, écrit **33 fois** (5 dans ce périmètre)

`zcrudFlagValue(<provider>, fallback: k<Nom>Default)` suivi d'un ternaire legacy/porté :
**33 sites** dans `lib/`. Périmètre révision : `smart_learn_controller.dart:444`,
`flashcards_dialogs.dart:68,240,479`, `interactive_flashcard_repetition_card.dart:164,411`,
`multi_flashcard_editor_page.dart:269`. C'est une dette **temporaire** et assumée, mais elle
double chaque point d'entrée.

### 4.7 Autres répétitions relevées

| Motif | Sites | Détail |
|---|---:|---|
| `DeltaToMarkdownHelper.normalizedMarkdown(...)` en appel direct | **22** | dans 5 fichiers ; aucun point de passage unique |
| `CircularProgressIndicator` monté à la main | **12** | 7 fichiers (`white_exam_question_card` ×3, `ai_generator` ×3, `interactive` ×2…) |
| `StreamBuilder` avec ses états chargement/vide non factorisés | **7** | 5 fichiers |
| Dialogue de confirmation de suppression (`showDialog` + `AlertDialog` + Annuler/Supprimer) | **3** | `multi_flashcard_editor_page.dart:146-165`, `:225-244` (**quasi identiques**, ~20 l.), `white_exam_page.dart:405-420` |
| `Color(0x…)` codé en dur | **65** | dont 30 dans `flashcards_learning_celebration_page.dart` |
| `Colors.<nom>` codé en dur | **263** | tout le périmètre |
| `LinearGradient(...)` monté à la main | **19** | dégradés par type de question, par écran |
| Libellé français en dur dans un `Text("…")` | **44** | aucun `l10n` dans le périmètre |
| Formulaires legacy `DynamicFormField(` | **217** dans `lib/` | dont **48 dans le périmètre** (`flashcard_edition_screen` 22, `multi_flashcard_editor_page` 15, `export_flashcards_to_pdf` 7, `test_exam_filter_screen` 6, `folder_flashcards_list_page` 4, `smart_learn_controller` 4) |
| `DynamicEditionScreen<` (moteur legacy) | **44** dans `lib/` | dont **9 dans le périmètre** |

### 4.8 Récapitulatif chiffré des duplications

| # | Ce qui est répété | Sites | Lignes concernées |
|---|---|---:|---:|
| 1 | Schéma du formulaire de flashcard | **3** | **~846** (264 + 292 + 290) |
| 2 | Squelette d'écran d'édition zcrud | **13** (4 ici) | **~1 593** (458 ici) |
| 3 | Filtre par liste d'identifiants (déclaration + setter + prédicat + (dé)sérialisation) | **15** | **~200** |
| 4 | Rendu de saisie de question (QCM / Vrai-Faux / texte, bandeau, pied) | **2 à 3** | **~265** |
| 5 | Évaluation de réponse (IA + repli manuel) | **2** | **179** |
| 6 | Bloc de bascule strangler-fig | **33** (5 ici) | ~100 |
| 7 | Normalisation markdown en appel direct | **22** | 22 |
| 8 | Indicateur de chargement monté à la main | **12** | ~36 |
| 9 | Dialogue de confirmation de suppression | **3** | ~55 |
| | **Duplication mesurée, périmètre révision seul** | | **≈ 1 660 lignes** |

Soit **≈ 10 % du périmètre de présentation** (1 660 / 15 953) attribuables à des blocs
recopiés — sans compter les 263 couleurs et 44 libellés en dur.

---

## 5. Ce qui est DÉJÀ branché sur zcrud

### 5.1 Paquets et symboles consommés

**11 fichiers du périmètre importent `package:zcrud_*`.**

| Paquet | Symboles importés | Où |
|---|---|---|
| `zcrud_core` (25) | `DynamicEdition`, `ZFieldSpec`, `ZFormController`, `ZEditionSubmitController`, `ZValidatorSpec`, `ZCondition`, `ZFieldChoice`, `ZDerivation`, `ZDerivationOverwrite`, `ZRelationConfig`, `ZRelationSource`, `ZRelationSourceRegistry`, `ZSubListConfig`, `ZTextConfig`, `EditionFieldType`, `ZBatchAction`, `ZBatchActionKind`, `ZBatchReport`, `ZFailure`, `ZResult`, `ZSyncMeta`, `Right`, `Unit`, `unit` | 6 fichiers |
| `zcrud_flashcard` (9) | `ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZFlashcardReviewCard`, `ZRevealTransition`, `ZRepetitionInfo`, `ZSm2Scheduler`, `ZSrsConfig` | 4 fichiers |
| `zcrud_study` (7) | `ZFlashcardListView`, `ZFlashcardListLabels`, `ZFlashcardListSelection`, `ZFlashcardListBatchMove`, `ZFlashcardBatchMoveDestination`, `ZMultiFlashcardEditor`, `ZMultiFlashcardEditorLabels` | 3 fichiers |
| `zcrud_session` (4) | `ZFlashcardAnswerInput`, `ZFlashcardSubmission`, `ZSrsQualityButtons`, `ZQualityScale` | 3 fichiers |
| `zcrud_exam` (3) | `ZExam`, `ZReminderRecurrence`, `ZReminderTime` | `z_backed_exam_repository.dart` |
| `zcrud_study_kernel` (1) | `ZReviewMode` | `review_session_zcrud.dart` |

### 5.2 Ce qui est enregistré au registre de widgets

`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart` (**445 l.**) construit le registre
et le `ZcrudScope` d'IFFD (`IffdZcrudScope`, `:227`). Enregistrements mesurés :

| Enregistrement | Ligne | Effet |
|---|---:|---|
| `registerZMarkdownFields(...)` avec `ZMarkdownFieldChrome` | `:101-147` | rend `markdown` / `inlineMarkdown` ; sans lui le champ **ne se rend pas** |
| `registerZFlashcardEditors(registry, trueLabel:'Vrai', falseLabel:'Faux', addChoiceLabel:'Ajouter une proposition')` | `:171-176` | **les trois éditeurs spécialisés de flashcard du socle** (type, QCM, vrai/faux) sous le `kind` `custom` |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `:188` | champ téléphone (hors périmètre révision) |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | `:199` | booléen `FlutterSwitch` — **remplace tous les booléens de l'application** sans qu'une `ZFieldSpec` le déclare |

⚠️ Le fichier documente une **divergence assumée et favorable** (`:157-169`) :
`ZFlashcardEditionValidator` du socle impose « au moins 2 choix, au moins 1 correct » — règle
que **le legacy IFFD ne valide nulle part**. Adopter le socle **refusera** un QCM à une seule
proposition, aujourd'hui accepté.

### 5.3 État réel du branchement — 🔴 rien n'est actif en production

**11 flags de bascule** couvrent le périmètre. **Tous à `false`.** Grep négatif montré :

```
$ grep -rn "UseZcrud.*= true\|kUseZcrudSm2Scheduler = true" \
    lib/src/presentation/features/flashcards \
    lib/src/domain/models/flashcard_repetition_info.dart \
    lib/src/features/flashcards --include='*.dart'
RC=1  (aucune occurrence)
```

Sur les **38 flags** de toute l'application, **un seul est à `true`**
(`ai_router_zcrud_edition.dart:91`) — et il est hors du périmètre révision.

| Flag | Fichier:ligne | Brique portée | Câblé à un site d'appel ? |
|---|---|---|---|
| `kUseZcrudSm2Scheduler` | `flashcard_repetition_info.dart:78` | `ZSm2Scheduler` | ✔ (`:377`) |
| `kFlashcardEditionUseZcrudDefault` | `zcrud/flashcard_edition_zcrud.dart:78` | `DynamicEdition` | ✔ `flashcards_dialogs.dart:68` |
| `kFlashcardListUseZcrudDefault` | `zcrud/flashcard_list_zcrud.dart:68` | `ZFlashcardListView` | ✔ `folder_flashcards_list_page.dart:539` |
| `kMultiFlashcardEditorUseZcrudDefault` | `zcrud/multi_flashcard_editor_zcrud.dart:54` | `ZMultiFlashcardEditor` | ✔ `multi_flashcard_editor_page.dart:282` |
| `kReviewSessionUseZcrudDefault` | `zcrud/review_session_zcrud.dart:55` | `ZFlashcardAnswerInput` | ✔ `interactive_…_card.dart:413` |
| `kSrsQualityUseZcrudDefault` | `zcrud/srs_quality_zcrud.dart:46` | `ZSrsQualityButtons` | ✔ `interactive_…_card.dart:172` |
| `kFlashcardTagEditionUseZcrudDefault` | `dialogs/flashcard_tag_zcrud_edition.dart:41` | `DynamicEdition` | ✔ `flashcards_dialogs.dart:247` |
| `kTestExamFilterUseZcrudDefault` | `widgets/test_exam_filter_zcrud_screen.dart:61` | `DynamicEdition` | ✔ `flashcards_dialogs.dart:495` |
| `kAiBaseUrlEditionUseZcrudDefault` | `controllers/ai_base_url_zcrud_edition.dart:58` | `DynamicEdition` | ✔ `smart_learn_controller.dart:466` |
| `kReviewCardUseZcrudDefault` | `zcrud/review_card_zcrud.dart:78` | `ZFlashcardReviewCard` | 🔴 **NON** |
| `kFlashcardBatchUseZcrudDefault` | `zcrud/flashcard_batch_zcrud.dart:71` | `ZFlashcardListSelection` | 🔴 **NON** |
| `useZcrudFlashcardRepository` | `flashcard_providers.dart:23` | `ZBackedFlashcardRepository` | ✔ `:27` |

**Deux briques portées, testées, et jamais montées.** Greps négatifs montrés :

```
$ grep -rn "flashcard_batch_zcrud" lib/ --include='*.dart'
(aucun résultat — seulement test/w8j/… et test/w9e/…)

$ grep -rn "review_card_zcrud" lib/ --include='*.dart'
src/presentation/features/flashcards/zcrud/review_session_zcrud.dart:43: import 'review_card_zcrud.dart' show iffdCardToZ;
```

`ReviewCardZcrudView` n'est référencé **nulle part** hors sa propre déclaration : seule la
fonction de conversion `iffdCardToZ` est réutilisée. L'inertie est **documentée et motivée**
(`review_card_zcrud.dart:110-125`) : `ZFlashcardReviewCard` n'expose aucun moyen de **commander**
la révélation, alors que le mode apprentissage appelle `flipCardController.toggleCard`
(`interactive_flashcard_repetition_card.dart:1127`, contrôleur fourni depuis 3 sites :
`flashcard_repetition_widgets.dart:153,258`, `learning_mode_question_card.dart:213`). Basculer
rendrait le bouton « Voir la réponse » **inerte**. Gelé par `test/w8m/review_card_reveal_command_test.dart`.

⇒ **C'est une demande de socle identifiée et non émise** (le fichier renvoie à
`docs/zcrud-change-requests.md`, « candidat CR-IFFD, à présenter avant émission »).

### 5.4 Ce que la migration a déjà produit en tests

**79 fichiers de test** mentionnent le domaine, **22 184 lignes**. Suites propres au chantier :

| Suite | Objet | Tests | Lignes |
|---|---|---:|---:|
| `test/w5c/` | mapping `FlashcardModel ↔ ZFlashcard` | 32 | 666 |
| `test/w8m/` | commande de révélation (gel de l'inertie) | 27 | 436 |
| `test/w8n/` | schéma d'édition porté | 26 | 260 |
| `test/w8d/` | **caractérisation du chemin d'écriture SRS** | 24 | 290 |
| `test/w8f/` | boutons de notation + routage | 24 | 271 |
| `test/w8j/` | sélection par lot | 20 | 271 |
| `test/w8c/` | éditeur multi-cartes | 18 | 274 |
| `test/w9e/` | inertie du lot + écarts d'édition + source de balises | 15 | 254 |
| `test/w8g/` | routage de la session de révision | 13 | 173 |
| `test/w8h/` | liste portée | 13 | 217 |
| `test/w8e/` | carte de révision portée | 12 | 210 |
| `test/dette/` | adoption du planificateur (B-16) | 11 | 177 |
| `test/w9h/` | sortie du formulaire porté | 10 | 152 |
| `test/w9k/` | écart de câblage de la liste | 6 | 105 |
| **TOTAL** | | **251** | **3 756** |

`test/w8d` fige, entre autres : « les deux premiers paliers sont des **lapses**, pas des
réussites », « un lapse ne **pénalise pas** l'E-Factor », « le plancher de 1 jour est absolu »,
« `toMap` tronque `nextReviewDate` à minuit ».

---

## 6. Les widgets maison qui refont ce que zcrud fait probablement

| Widget / classe maison | Fichier:ligne | Lignes | Contrepartie socle plausible | Statut |
|---|---|---:|---|---|
| `InteractiveFlashcardRepetitionCard` | `widgets/interactive_flashcard_repetition_card.dart:24` | **1 149** | `ZFlashcardReviewCard` + `ZFlashcardAnswerInput` + `ZSrsQualityButtons` | 2 des 3 briques portées, flags à `false` ; blocage sur la commande de révélation |
| `WhiteExamQuestionCard` | `widgets/white_exam_question_card.dart:18` | **1 066** | `ZFlashcardAnswerInput` en mode examen (`correctionVisibility` différée) | **aucun portage** |
| `FlashcardCard` (tuile de grille) | `widgets/flashcard_widgets.dart:107` | **383** | tuile native de `ZFlashcardListView` | **déclaré non couvert** (`flashcard_list_zcrud.dart:120-122`) |
| `FlashcardRepetitionCard` (+ `FlipCard`) | `widgets/flashcard_repetition_widgets.dart:18` | **663** | `ZFlashcardReviewCard` + `ZRevealTransition.flip3d` (le socle **interdit** `flip_card`, FR-SU1) | non porté |
| `FlashcardsLearingController` (file de session, ré-injection après échec, retrait, index) | `controllers/flashcards_learing_controller.dart:7` | **199** | `ZStudySessionEngine` | 🔴 **jamais importé** — grep négatif : `grep -rn "ZStudySessionEngine" lib/` → 1 seule occurrence, dans un **commentaire** (`review_card_zcrud.dart:44`) |
| `Sm` / `SmResponse` (SM-2 maison) | `domain/models/flashcard_repetition_info.dart:80,94` | **100** (`:80-91` + `:94-179`) | `ZSm2Scheduler` + `ZSrsConfig` | porté, flag à `false` |
| `FolderFlashcardsListController` (recherche + 15 filtres + sélection) | `pages/folder_flashcards_list_page.dart:39` | **327** | filtres déclaratifs du socle | non porté |
| `DynamicEditionScreen` + `DynamicFormField` (moteur d'édition legacy) | `lib/data_crud/edition_screen.dart` | — | `DynamicEdition` + `ZFieldSpec` | **44 + 217 sites** dans `lib/`, dont 9 + 48 ici |
| `DataState<T,E>` + 8 sous-classes | `utils/resources/data_state.dart` | — | `Either<ZFailure,T>` | non porté |
| `CrudRepository<T>` (23 méthodes) | `domain/repositories/datacrud_repository.dart:23` | 93 | `ZRepository<T>` / `ZLocalStore` / `ZRemoteStore` | adaptateurs `ZBacked*` écrits, non actifs |
| `_buildTrophyIcon` / `_buildStatsRow` / `_buildStatItem` / `_buildBackgroundCircle` | `pages/flashcards_learning_celebration_page.dart:198-364` | ~170 | écran de fin de session du socle | non porté ; **30 couleurs en dur** |
| Bandeaux de progression : `segmented_progress_bar` + `dots_indicator` + anneau maison `buildCircledProgessWidget` | `folder_flashcards_repetitions_page.dart`, `flashcard_widgets.dart:664` | ~90 | primitives de progression du socle | non porté |
| `ExportFlashcardsToPdf` / `ExportMarkdownToPdf` | `widgets/export_flashcards_to_pdf.dart:29,165` | **296** | `zcrud_export` / `zcrud_export_pdf` | 🔴 non consommé — `zcrud_export` **absent** du `pubspec.yaml` d'IFFD (raison documentée `:292` : « exigent Syncfusion ^34, IFFD est en ^32 ») |

### 6.1 Le contrôleur-orchestrateur

`SmartLearnController` (`controllers/smart_learn_controller.dart:53`, **568 l.**) est un objet
central qui reçoit **23 dépôts injectés** (23 paramètres `required` au constructeur) et qui est lu
depuis **52 sites** via le singleton global `smartLearnInstance` (`:51`). Il porte à la fois :
l'année académique, l'URL de base IA, le routeur IA, les dossiers de l'utilisateur, les toasts
(succès/erreur/info), l'ouverture des dialogues d'édition et d'actions génériques.

⚠️ Il est **importé par le domaine** : les trois contrats de dépôt du périmètre en dépendent
(§ 3.3). C'est le nœud le plus coûteux à défaire d'une migration.

---

## 7. Synthèse pour la migration

**Ce qui est déjà fait** : 10 briques portées (**2 650 lignes** : 1 749 dans `flashcards/zcrud/` + 901 dans trois écrans portés hors de ce dossier), 251 tests
dédiés, un mapping sans perte `FlashcardModel ↔ ZFlashcard` documenté champ par champ, un
`ZcrudScope` complet avec 4 enregistrements au registre, et un adaptateur SRS owner-scopé.

**Ce qui reste entier** :
1. **Aucune bascule n'est active** — 11 flags sur 11 à `false`, un seul `true` dans toute l'app.
2. **Deux briques portées ne sont pas montées** (`ReviewCardZcrudView`, `flashcard_batch_zcrud`), dont une pour une raison de **socle** identifiée et non transmise : `ZFlashcardReviewCard` ne sait pas recevoir une commande de révélation.
3. **Trois écrans lourds n'ont aucun portage** : `WhiteExamQuestionCard` (1 066 l.), `FolderFlashcardsRepetitionsPage` (1 202 l.), `FlashcardsLearningModeScreen`.
4. **Le moteur de session** (`FlashcardsLearingController`) et `ZStudySessionEngine` ne se sont jamais rencontrés.
5. **Le domaine n'est pas isolé** : `cloud_firestore` et `flutter/material` dans les entités, `presentation/` importé par `domain/repositories/`, `FirebaseException` remontée jusqu'à l'appelant.
6. **≈ 1 660 lignes dupliquées** identifiées et chiffrées (§ 4.8) — dont le schéma du formulaire de flashcard écrit **trois fois** et un filtre par identifiants écrit **quinze fois**.
7. **Deux assemblages manquants côté socle**, révélés par les chiffres :
   - un **écran CRUD complet** (scope + barre + action Enregistrer + `DynamicEdition` + soumission), recopié **13 fois** dans IFFD (~1 593 l.) ;
   - une **primitive de saisie de question réutilisable** entre révision et examen, recopiée à 78-102 lignes par forme.

---

## 8. Méthode et reproductibilité

- **Comptage de lignes** : `wc -l` sur les fichiers listés ; aucun `.g.dart` exclu sauf mention.
- **Détection de clones** : appariement `difflib.SequenceMatcher` sur lignes normalisées
  (commentaires `//` retirés, espaces compressés, lignes de ponctuation seule ignorées :
  `{`, `}`, `});`, `)`, `);`, `],`, `],)`, `}),`, `),`). Seuil de bloc contigu : **12 lignes**
  pour les clones nommés, **6 lignes** pour le total par paire de fichiers.
- **Longueur de méthode** : comptage par appariement d'accolades depuis la ligne de signature.
- **Toute affirmation d'absence** de ce rapport porte son grep négatif, montré dans le corps
  du texte (§ 0, § 1.7, § 3.4, § 5.3, § 6).
- **Aucun test n'a été lancé.** Aucun fichier du dépôt IFFD n'a été modifié.
- Les valeurs non lisibles dans le code ne sont pas devinées : lorsque le code ne dit pas
  (ex. le nombre de cartes par cycle hors la constante `flashcardsPerCycle = 30`), le rapport
  cite la ligne plutôt que d'extrapoler.
