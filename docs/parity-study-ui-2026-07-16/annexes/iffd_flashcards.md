# Inventaire exhaustif — Affichage & Édition des Flashcards IFFD

Périmètre : capacités d'AFFICHAGE (rendu/listing/révision) et d'ÉDITION (création/modification/suppression/batch) des flashcards de l'app IFFD (`/home/zakarius/DEV/iffd`). Le SRS/scheduling n'est documenté que dans la mesure où il touche l'affichage (carte interactive, boutons de qualité).

---

## F1 — Modèle de données `FlashcardModel` (support multi-type)

1. **Rôle** : entité canonique flashcard, sous-classe de `FolderContentModel` (héritage id/subjectId/folderId/subFolderId/creatorId/createdAt).
2. **Fichier** : `lib/src/domain/models/flashcard_model.dart`.
3. **Types supportés** (`QuestionType` enum) : `multipleChoice` (QCM), `trueOrFalse` (Vrai/Faux), `openQuestion` (Question ouverte, défaut), `exercise` (Cas pratique). Chaque type a une couleur associée (`.color`).
   Champs : `question` (markdown), `type`, `answer` (pour openQuestion/exercise), `choices: List<QcmChoice>` (pour QCM — `id`, `content` markdown, `isCorrect`), `isTrue` (pour trueOrFalse), `explanation`, `indice` (hint texte simple), `tagsIds: List<String>`, `documentId`/`pageNumber` (rattachement à un document source), `noteId` (rattachement à une note), `hsSection`/`hsChapter` (rattachement Système Harmonisé), `chatConversationId`/`chatMessageId` (rattachement à une conversation IA), `isReadOnly` (flashcards par défaut non éditables/non supprimables, ex. générées depuis le référentiel SH douanier).
4. **Édition** : `toMap/fromMap/copyWith` codegen-like manuel (pas de `@JsonSerializable`), désérialisation défensive (`??`, `int.tryParse`).
5. **Affichage** : `shuffledChoices()` mélange les propositions QCM pour l'affichage en session.
6. **Spécial** : `subjectDefaultFlashcards(subject)` — génère automatiquement des flashcards en lecture seule à partir d'un référentiel Système Harmonisé (SH) pour un sujet donné (parsing d'avis de classement, extraction question/réponse par regex/markdown).
7. **Couplage** : `cloud_firestore` (Timestamp), Flutter (Color/IconData pour l'UI).

## F2 — SRS / Répétition espacée (`FlashcardRepetitionInfo` + `Sm`)

1. **Rôle** : état de révision par flashcard/utilisateur ; expose les boutons de qualité affichés à l'utilisateur.
2. **Fichier** : `lib/src/domain/models/flashcard_repetition_info.dart`.
3. **Champs** : `flashcardId`, `userId`, `nextReviewDate`, `interval`, `repetitions`, `quality` (enum `FlashcardRepetitionQuality` : fail/hard/good/easy/perfect, valeurs 1-5 avec icône/couleur/label et texte "prochaine révision"), `easeFactor`, `learnedAt`, `accademicYear`.
4. **Algorithme** : SM-2 étendu (`Sm.calc`) avec bonus "overdue" si révision en retard.
5. **Affichage** : `getNextIntervalString(quality)` calcule le texte "dans X jours/mois/ans" affiché sous chaque bouton de qualité.
6. **Édition** : `updateWithQuality(quality)` produit la paire (ancien, nouveau) état après une réponse.
7. **Couplage** : Firestore (Timestamp), aucune UI directe (consommé par les widgets de révision).

## F3 — Tags flashcards (`FlashcardTagModel` + CRUD)

1. **Rôle** : balises colorées attachées aux flashcards, filtrables et affichables en badge.
2. **Fichiers** : `flashcard_tag_model.dart`, `flashcard_tags_repository.dart`, dialog d'édition dans `flashcards_dialogs.dart` (`showFlashcardTagEditonDialog`).
3. **Champs** : `title`, `color`.
4. **Édition** : dialog `DynamicEditionScreen` générique (titre + color picker), CRUD complet (create/update).
5. **Affichage** : widget `flashcardTags(tags)` (chips arrondis colorés, scroll horizontal) ; couleur auto-ajustée en luminosité/saturation selon thème clair/sombre (`adjustTagColor`).
6. **Spécial** : dialog dédié `showFlashcardTagsSelectionDialog` (sélection multiple par checkbox avec Set, sauvegarde immédiate sur `flashcardRepository.update`).
7. **Couplage** : Riverpod (`flashcardTagsRepositoryProvider`), Firestore.

## F4 — Édition unitaire d'une flashcard (`FlashcardEditionScreen`)

1. **Rôle** : formulaire complet de création/modification d'une flashcard unique, en dialog ou plein écran.
2. **Fichier** : `widgets/flashcard_edition_screen.dart`, invoqué via `showFlashcardEditonDialog` (`flashcards_dialogs.dart`).
3. **Champs dynamiques selon type** : sélecteur de type (QCM/Vrai-Faux/Ouverte/Exercice) ; champ `question` en markdown inline ; `answer` markdown (affiché seulement si openQuestion/exercise) ; `isTrue` booléen (si trueOrFalse) ; sous-formulaire `choices` en liste éditable avec toggle "bonne réponse" (switch coloré vert/rouge) + preview markdown, dialog imbriqué pour éditer chaque proposition (si multipleChoice) ; `indice`, `explanation` ; sélecteur SH (Section/Chapitre en cascade) si sujet = référentiel douanier ; sélecteur de tags (chips avec menu popup "ajouter", suppression par croix).
4. **Modes** : dialog (desktop/tablette) ou plein écran (mobile), `bodyOnly`+`useDefaultDialogActions`.
5. **Persistance** : à la fermeture, `fromMap<FlashcardModel>` puis `create`/`update` selon `Crud`.
6. **Couplage** : moteur `DynamicEditionScreen`/`DynamicFormField` (proto du `data_crud` interne, ancêtre de zcrud), Riverpod (lecture repository via `ProviderScope.containerOf`).

## F5 — Menu d'actions contextuel flashcard (`FlashcardActionsDialogWidget` + popup menu)

1. **Rôle** : menu "..." sur une carte flashcard (liste ou grille) proposant Modifier/Supprimer.
2. **Fichiers** : `widgets/flashcard_actions_dialog_widget.dart` (bottom-sheet/dialog complet avec permissions), `popup_menu_helpers.dart::buildFlashcardPopupMenu` (menu grille rapide inline).
3. **Actions** : "Modifier" → ouvre `showFlashcardEditonDialog` en mode update ; "Supprimer" → dialog de confirmation puis `delete()` + purge en cascade des `FlashcardRepetitionInfo` associées via `deleteFlashcardRepetitions`.
4. **Permissions** : calculées par `FolderResourceAccessService` (canUpdate/canDelete selon créateur/propriétaire dossier/année académique).
5. **Couplage** : GetX (navigation `Get.back`), Riverpod.

## F6 — Création rapide (dialog "Créer manuellement" vs "Générer avec l'IA")

1. **Rôle** : point d'entrée de création depuis un dossier — choix entre saisie manuelle et génération IA.
2. **Fichier** : `widgets/flashcards_creation_dialog_widget.dart`, invoqué via `showFlashcardsCreationModal`.
3. **Options** : "Créer manuellement" (ouvre `FlashcardEditionScreen` vide, pré-rempli avec folderId/subFolderId) ; "Générer avec l'IA" (visible seulement si permission `Crud.aiFlashCard`) → ouvre le générateur IA.
4. **Couplage** : GetX, permissions `AppUserPermissions`.

## F7 — Génération de flashcards par IA (`AiFlashcardsGeneratorDialogWidget`)

1. **Rôle** : dialog à 3 onglets pour générer des lots de flashcards via IA à partir de différentes sources.
2. **Fichier** : `widgets/ai_flashcards_generator_dialog_widget.dart` (~1240 lignes), dialogs annexes dans `flashcards_dialogs.dart` (`showQuestionsTypesSelectionDialig`, `FlashcardsQuestionsCountEditionScreen`).
3. **3 modes de génération** :
   - **Documents** : sélection d'un document existant (drag&drop, upload PDF/PPT/DOC, ou scan photo via `CunningDocumentScanner`) → sélection de pages → génération.
   - **Sujets/tags** : saisie/sélection de thèmes (auto-suggérés par IA à partir du titre du dossier, max 4) → génération par sujet.
   - **Texte libre** : éditeur markdown inline (jusqu'à 30 000 caractères) → génération depuis texte brut.
4. **Configuration avancée** (`FlashcardsQuestionsCountEditionScreen`) : répartition du nombre de questions par `QuestionType` (sous-items éditables avec ajout dynamique via popup menu), instructions complémentaires libres, choix du modèle d'IA parmi les modèles configurés (`aiRouter.flashcardsFallbackModels`).
5. **Résultat** : callback `onFlashcardsGenerated(List<FlashcardModel>)` — les flashcards générées sont pré-remplies (id, folderId/subjectId, creatorId, contenu) mais **pas sauvegardées automatiquement**, laissées à l'appelant (souvent injectées dans l'éditeur multi-flashcards F8 pour revue avant sauvegarde).
6. **Indicateur** : `FlashcardGenerationIndicator` (animation de couleur pendant génération), `WrapInProgressIndication`.
7. **Couplage** : Riverpod (`aiRepositoryProvider`), Dio (appels réseau IA), `file_picker`, `cunning_document_scanner`.

## F8 — Éditeur multi-flashcards / batch (`MultiFlashcardEditorPage`)

1. **Rôle** : écran plein page permettant de créer/éditer/supprimer plusieurs flashcards en lot avant sauvegarde finale (ex. après génération IA), avec preview.
2. **Fichier** : `pages/multi_flashcard_editor_page.dart` (~1240 lignes).
3. **Layout responsive** : Desktop/tablette = split-view (sidebar liste + panneau formulaire) ; Mobile = navigation liste ↔ formulaire plein écran.
4. **Fonctions batch** :
   - Ajout d'une nouvelle flashcard vide (insérée après la sélection courante).
   - **Mode sélection multiple** (`_isSelectionMode`) : cases à cocher sur chaque carte, "tout sélectionner/désélectionner", badge du nombre sélectionné, **suppression groupée** avec dialog de confirmation (`_deleteSelectedFlashcards`).
   - Suppression unitaire par carte (icône poubelle flottante).
   - Bouton "Générer avec l'IA" intégré (ouvre F7, ajoute les résultats à la liste courante).
   - Bouton "Aperçu" (bascule vers rendu `FlashcardRepetitionCard` en lecture seule, avec bouton retour à l'édition).
   - Sauvegarde : bouton "Enregistrer" renvoie la liste complète via callback `onChange` + `Get.back(result: ...)`.
5. **Formulaire par carte** : identique à F4 (mêmes champs conditionnels par type, y compris QCM avec switch bonne/mauvaise réponse, tags), avec auto-save sur chaque `onChange` (pas de bouton "sauvegarder" par carte — modification en direct dans la liste locale `_flashcards`).
6. **Couplage** : `data_crud` (DynamicEditionScreen/FormBuilder), GetX.

## F9 — Liste/grille des flashcards d'un dossier (`FolderFlashcardsListPage`)

1. **Rôle** : vue grille responsive de toutes les flashcards d'un dossier, avec recherche, sélection multiple, filtres, export PDF.
2. **Fichier** : `pages/folder_flashcards_list_page.dart` (~1080 lignes).
3. **Affichage** : `GridView.count` responsive (largeur de carte adaptative ≥300-350px), chaque carte = `FlashcardCard` (question tronquée, badge type coloré, tags, icône document source, aperçu réponse si en grille).
4. **Recherche** : barre de recherche texte sur la question (`DynamicSearcheableAppBar`), normalisation du texte (insensible accents/espaces).
5. **Filtres** (`FolderFlashcardsListController.flashcardMatched`) : par tags (au moins un tag sélectionné), documents source, notes source, sections/chapitres SH, et (spécifique module "Valuation Tool") articles GATT/annexes/décisions/avis/commentaires/notes explicatives/études de cas/études — filtre dédié `FolderFlashcardsListFilterScreen` (dialog avec un `DynamicFormField` multi-select par catégorie de source).
6. **Sélection multiple** (mode long-press) : checkbox sur chaque carte, barre d'actions bas d'écran (BottomNavigationBar) avec **Déplacer** (vers autre dossier/sujet), **Ajouter des tags** (désactivé/TODO dans le code actuel), **Supprimer** (par lots de 10, avec purge cascade des répétitions SRS).
7. **Export PDF** : icône dans l'app bar → `ExportFlashcardsToPdf` (F11) sur la sélection ou l'ensemble filtré.

## F10 — Carte flashcard compacte (`FlashcardCard` + `FlashcardAnwserWidget`)

1. **Rôle** : widget carte réutilisé en liste/grille — affiche question (markdown/LaTeX rendu), type, tags, document source ; en mode grille affiche aussi un aperçu de la réponse.
2. **Fichier** : `widgets/flashcard_widgets.dart`.
3. **Affichage réponse par type** (`FlashcardAnwserWidget`) : QCM → liste des propositions avec coche verte/croix rouge ; Vrai/Faux → badge tamponné "Vrai"/"Faux" pivoté (style tampon) coloré ; Ouverte/Exercice → texte réponse markdown/LaTeX.
4. **Interactions** : tap → ouvre la page de révision (`FolderFlashcardsRepetitionsPage`) positionnée sur cette carte ; long-press → active la sélection multiple ; tap sur les tags → dialog de sélection de tags (F3) ; menu "..." → actions (F5).
5. **Dégradés de couleur par type** : QCM violet/bleu, Vrai-Faux vert, Ouverte rose/rouge, Exercice bleu cyan — cohérents dans toute l'app.
6. **Couplage** : `RichTextReaderScreen` (rendu markdown+LaTeX du module `data_crud`), Riverpod.

## F11 — Export PDF des flashcards (`ExportFlashcardsToPdf`)

1. **Rôle** : génère et prévisualise un PDF imprimable des flashcards sélectionnées (fiches de révision papier).
2. **Fichier** : `widgets/export_flashcards_to_pdf.dart`.
3. **Contenu du PDF** : titre "QUESTIONS DE RÉVISION", sous-titre configurable (nom du module), numérotation des questions, rendu markdown→texte multi-lignes avec gestion du gras/italique/souligné (conversion HTML intermédiaire), badge d'instruction selon type ("Choisir une ou plusieurs réponses" / "Répondre par Vrai ou Faux"), symboles ✓/✗ colorés (vert/rouge) pour Vrai-Faux et QCM, réponses ouvertes affichées en vert en dessous de la question.
4. **Génération** : deux voies — génération locale via `syncfusion_flutter_pdf` (`exportToPdf`, présente mais partiellement utilisée) et génération **côté serveur** via appel API (`convertToPdf` → POST vers `AiRepository.convertFlashcardsToPdfEndpoint`, réponse binaire PDF).
5. **Options utilisateur** : dialog réglages (icône ⚙️) permettant de changer le "Module" (sous-titre) ; options avec/sans réponses, LaTeX (actuellement commentées/désactivées dans le code).
6. **Prévisualisation** : `PdfPreview` (package `printing`), export/partage/impression natif.
7. **Bonus** : `ExportMarkdownToPdf` — variante générique export d'un contenu markdown quelconque en PDF (même mécanisme serveur), utilisée ailleurs dans l'app (pas spécifique flashcards).
8. **Couplage** : `syncfusion_flutter_pdf`, `printing`, `dio`, `markdown` (conversion HTML), polices custom (Tahoma, Source Serif) embarquées en assets.

## F12 — Carte de révision interactive avec flip recto/verso (`FlashcardRepetitionCard`)

1. **Rôle** : widget principal de révision — orchestre l'affichage recto (question) / verso (réponse) et bascule vers le mode interactif ou apprentissage.
2. **Fichier** : `widgets/flashcard_repetition_widgets.dart`.
3. **Flip card** : utilise `flip_card` package (`FlipCard`, `flipOnTouch` activé sauf en mode apprentissage), face avant = question + choix (aperçu statique QCM/Vrai-Faux non interactif), face arrière = `FlashcardAnwserWidget` + bouton "Masquer la réponse".
4. **Modes déterminés par `FlashcardRepetitionPageType`** : `listOnly` (flip simple, pas de SRS), `nFlashcardsLearningCycle`/`allFlashcardsLearningCycle` (apprentissage — délègue à `LearningModeQuestionCard`, feedback qualité), `test`/`whiteExam` (mode examen — délègue à `InteractiveFlashcardRepetitionCard`, saisie de réponse notée), `cramming` (bachotage sans impact SRS, code présent mais UI commentée/désactivée).
5. **Header/Footer** : tags cliquables (ouvre sélection F3), badge type coloré avec icône, menu actions "..." (F5), icône éclair décorative.
6. **Écoute temps réel** : `streamOne(flashcard.id)` pour rafraîchir automatiquement la carte si modifiée ailleurs.
7. **Couplage** : `RichTextReaderScreen` (LaTeX/markdown), Riverpod.

## F13 — Carte interactive de test/examen avec saisie notée (`InteractiveFlashcardRepetitionCard`)

1. **Rôle** : version "active" de la carte de révision pour les modes test/exam/apprentissage — l'utilisateur saisit réellement une réponse, notée automatiquement ou par IA.
2. **Fichier** : `widgets/interactive_flashcard_repetition_card.dart` (~1050 lignes).
3. **Saisie par type** : QCM → cases à cocher (mode simple/multiple selon nb de bonnes réponses), correction visuelle vert/rouge après soumission ; Vrai/Faux → 2 boutons radio avec auto-soumission ; Ouverte/Exercice → éditeur markdown inline pour rédiger la réponse.
4. **Évaluation** : QCM/Vrai-Faux évalués localement (comparaison exacte) ; Ouverte/Exercice évaluées par **IA** (`aiRepository.evaluateFlashcardAnswer`, score 1-5) avec repli sur score neutre (3) si échec IA.
5. **Système d'indices (hints)** : bouton "Indice" affichant l'indice existant (`flashcard.indice`) puis génération de nouveaux indices via IA (`generateFlashcardHint`) si épuisés, tracking du nombre d'indices utilisés (impacte l'évaluation qualité).
6. **Bouton "Je ne sais pas"** : soumission directe avec qualité 1 (échec) sans réponse.
7. **Feedback** : minuteur de réponse (`Stopwatch`), affichage de la réponse attendue après soumission pour les questions ouvertes, indicateur "Évaluation en cours..." pendant l'appel IA, auto-passage à la carte suivante après 200ms.
8. **Couplage** : `aiRepositoryProvider` (Riverpod), `MarkdownEditionField`, `RichTextReaderScreen`.

## F14 — Feedback pédagogique en mode apprentissage (`LearningModeQuestionCard`)

1. **Rôle** : enrobe la carte interactive (F13) en mode apprentissage pour afficher un message d'encouragement/motivation personnalisé après soumission, avant de passer à la suite.
2. **Fichier** : `widgets/learning_mode_question_card.dart`.
3. **Messages dynamiques** : banques de phrases variées selon qualité (4-5 = encouragement, 3 = neutre, 1-2 = motivation), modulées par temps de réponse (<10s sans indice = "exceptionnel") et nombre d'indices utilisés.
4. **Affichage post-soumission** : bascule vers `WhiteExamQuestionCard` (widget partagé avec le mode examen blanc) affichant réponse attendue + message.
5. **Couplage** : dépend de F13 pour la saisie, de `white_exam_question_card.dart` pour l'affichage résultat.

## F15 — Session de révision / apprentissage (`FolderFlashcardsRepetitionsPage`)

1. **Rôle** : écran plein page orchestrant une session de révision complète (swipe de cartes, progression, boutons de qualité SRS, confettis de fin).
2. **Fichier** : `pages/folder_flashcards_repetitions_page.dart` (~1200 lignes).
3. **6 types de session** (`FlashcardRepetitionPageType`) : `nFlashcardsLearningCycle` (apprentissage d'un lot ciblé), `allFlashcardsLearningCycle`, `listOnly` (simple consultation swipeable, pas de SRS), `test` (examen avec retrait immédiat après réponse), `whiteExam`, `cramming` (bachotage, actuellement désactivé côté UI).
4. **Navigation par swipe** : `CardSwiper` (package `flutter_card_swiper`) — swipe droite = qualité positive/suivant, gauche = négatif/précédent ; indicateurs visuels (émojis satisfait/insatisfait) qui apparaissent pendant le drag selon la direction/intensité.
5. **Indicateur de progression** : `DotsIndicator` (points colorés par qualité de dernière révision) en mode apprentissage cycle N, `SegmentedProgressBar` en mode "tous les flashcards".
6. **Boutons de qualité SRS** (`CardSwiperButtons`) : 5 boutons (fail/hard/good/easy/perfect avec icône+couleur+label), affichage du texte "prochaine révision dans X" par bouton, désactivés en lecture seule, navigation précédent/suivant.
7. **Fin de session** : `LearningCelebrationPage` (F16) affichée quand la liste de cartes est vide + `ConfettiWidget` explosif.
8. **Gamification** : mise à jour du "streak" quotidien de l'utilisateur (`_checkAndUpdateStreak`) après une répétition (hors mode listOnly), snackbar "🔥 Flamme mise à jour".
9. **Persistance SRS** : à chaque swipe/qualité, calcul `updateWithQuality` puis `flashcardRepetitionRepository.update()`.
10. **Couplage** : Riverpod, `flutter_card_swiper`, `confetti`, `dots_indicator`, `segmented_progress_bar`.

## F16 — Page de célébration de fin de session (`LearningCelebrationPage`)

1. **Rôle** : écran de félicitations animé affiché à la fin d'une session de révision.
2. **Fichier** : `pages/flashcards_learning_celebration_page.dart`.
3. **Contenu** : trophée animé (scale + glow), titre "Félicitations ! 🎉" en dégradé, message, **statistiques** (nombre de cartes, cartes maîtrisées, durée de session), confettis explosifs (`confetti` package), cercles de fond animés.
4. **Action** : bouton "Retour au dossier" (pop navigation).
5. **Animations** : `AnimationController` scale (élastique) + fade, post-frame callback pour déclenchement séquencé.
6. **Couplage** : `confetti`, pas de dépendance data (reçoit juste `totalCards`/`masteredCards`/`sessionDuration` en paramètres).

## F17 — Point d'entrée "Mode Apprentissage" (`FlashcardsLearningModeScreen`)

1. **Rôle** : dialog/bottom-sheet listant les options de session pour un dossier (choix du mode de révision) avec calcul dynamique des lots.
2. **Fichier** : `widgets/flashcard_widgets.dart` (classe `FlashcardsLearningModeScreen`).
3. **Options proposées** : "Apprendre +N flashcards" (les jamais apprises, lot de 30 max) avec indicateur de progression circulaire ; "Flashcards à réviser" (celles dont `nextReviewDate` est dépassé, triées par urgence, visible seulement s'il y en a) ; "Test" (examen sur les flashcards déjà apprises, avec dialog de configuration de filtres F18 avant lancement) ; option "Examen Blanc" et "Croulage/Cramming" présentes dans le code mais commentées (désactivées en production).
4. **Affiche** le streak de l'utilisateur en haut (badge flamme orange) si actif.
5. **Logique de catégorisation** : classe chaque flashcard en apprise / à réviser / à apprendre via lookup sets O(1) sur les `FlashcardRepetitionInfo`.
6. **Couplage** : GetX (navigation, snackbars), `AutoRouterMixin`.

## F18 — Filtres de configuration Test/Examen (`showTestExamFilterDialog` + `applyTestExamFilters`)

1. **Rôle** : dialog de paramétrage avant de lancer une session de test, et fonction pure de filtrage appliquée sur la liste de flashcards.
2. **Fichiers** : `dialogs/flashcards_dialogs.dart` (`showTestExamFilterDialog`, `TestExamFilterScreen` référencé), `utils/flashcard_filters.dart` (`applyTestExamFilters`).
3. **Critères de filtre** : nombre de questions désiré (`questionCount`, défaut 10, tirage aléatoire si excédent), types de questions (`questionTypes` — multi-sélection parmi les 4 `QuestionType`), niveaux de maîtrise (`masteryLevels` : "mauvais" qualité 1-2 ou jamais pratiqué, "bon" qualité 3, "maitrise" qualité 4-5), tags, documents source, notes source.
4. **Résultat** : liste filtrée et éventuellement échantillonnée aléatoirement (`Random().shuffle`), puis mélange des choix QCM (`shuffledChoices()`) avant lancement de session.
5. **Couplage** : pur Dart (fonction de filtrage testable indépendamment de l'UI).

---

## Récapitulatif — Types de flashcards supportés

| Type (`QuestionType`) | Libellé | Champs actifs |
|---|---|---|
| `openQuestion` (défaut) | Question ouverte | `question`, `answer`, `indice`, `explanation` |
| `multipleChoice` | QCM | `question`, `choices: List<QcmChoice>` (id, content, isCorrect — 1 ou plusieurs bonnes réponses) |
| `trueOrFalse` | Vrai/Faux | `question`, `isTrue` |
| `exercise` | Cas pratique | `question`, `answer`, `indice`, `explanation` (mêmes champs qu'openQuestion, badge "résoudre un cas pratique") |

## Récapitulatif — Champs transverses de `FlashcardModel`

`id`, `subjectId`, `folderId`/`subFolderId`, `creatorId`, `createdAt` (hérités de `FolderContentModel`), `question` (markdown), `type`, `answer`, `choices`, `isTrue`, `explanation`, `indice` (hint texte simple, distinct du système d'indices IA affiché en révision), `tagsIds`, `documentId`/`pageNumber` (rattachement document source), `noteId` (rattachement note source), `hsSection`/`hsChapter` (rattachement Système Harmonisé douanier), `chatConversationId`/`chatMessageId` (rattachement conversation IA source), `isReadOnly` (flashcards protégées, ex. générées depuis référentiel officiel SH).

Champs SRS associés (entité séparée `FlashcardRepetitionInfo`) : `nextReviewDate`, `interval`, `repetitions`, `quality` (1-5), `easeFactor`, `learnedAt`, `accademicYear`.
