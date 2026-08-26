# Carte du domaine « Étude — matières, documents, corpus » (IFFD)

**Relevé du 2026-08-26.** Dépôt hôte `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`,
HEAD `65d1af9`, arbre de travail propre (`git status --porcelain` → vide).
Socle consommé : **zcrud v3.21.0** — **48** occurrences de `ref: v3.21.0` dans `pubspec.yaml`
(première : `:308`), et **aucun autre tag zcrud**. L'hôte est **à jour du dernier tag publié**.

Tout ce qui suit a été mesuré sur disque. Les affirmations d'absence portent leur grep négatif.

### Contrôle par sondage (2026-08-26, seconde passe)

Ce relevé a été **repris et re-vérifié par sondage** sur disque. Ce qui a été remesuré, et le verdict :

| Affirmation contrôlée | Verdict |
|---|---|
| HEAD `65d1af9`, branche `feat/migration-zcrud`, arbre propre, **48** × `ref: v3.21.0` | ✅ exact |
| Périmètre donné : 9 / 3 / 12 / 3 fichiers → **2 904 / 121 / 6 420 / 741** lignes | ✅ exact |
| Ajouts : `valuation_tools/` 4 f. **1 333** l., `ai_routers/` 5 f. **2 535** l. | ✅ exact |
| **10** sous-classes de `ValuationToolModel` aux lignes 163/205/247/289/331/373/415/457/499/541 | ✅ exact |
| `z_qa_flags.dart` **985** lignes, **52** entrées `id:` ; `main.dart` lève **8** bascules | ✅ exact |
| Grep négatif `ZAnnotationToolbar` / `ZAnnotationPanel` / `ZDocumentViewerChrome` sur `lib` → **0** | ✅ exact |
| Grep négatif `ZCrudScreen` (classe socle) sur `lib` → **0** | ✅ exact |
| **3** imports `package:zcrud_` dans les 4 répertoires du périmètre donné | ✅ exact |
| ~~`GridView.count` **20** fois dans **17** fichiers~~ | ❌ **corrigé → 23 sites / 18 fichiers** (§7.4) |
| ~~« des 16 imports de `zcrud_screen`, **tous** sont `show presentFormEdition` »~~ | ❌ **corrigé** : 10 des 16 amènent AUSSI `ZFormOnly` ; `ZFormOnly` vit dans **12 fichiers** (§5.2, §7.1) |

La seconde correction change une **conclusion**, pas seulement un chiffre : la coquille de
formulaire (D9) n'est pas un manque du socle mais un **canal du socle ignoré dans ce périmètre**
(§5.2, §11 levier 2).

---

## 1. Périmètre mesuré

### 1.1 Ce qui m'était donné

| Chemin | Fichiers `.dart` | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/subjects/` | 9 | 2 904 |
| `lib/src/features/subjects/` | 3 | 121 |
| `lib/src/presentation/features/documents/` | 12 | 6 420 |
| `lib/src/features/corpus/` | 3 | 741 |
| **Sous-total périmètre donné** | **27** | **10 186** |

### 1.2 Ce que j'ai INCLUS au-delà, et pourquoi

Le point de départ ne tient pas debout seul : `lib/src/features/corpus/` ne contient **aucun**
modèle de corpus — c'est un fichier de **providers Riverpod** qui câble dix dépôts d'outils de
valeur en douane (`corpus_providers.dart:26-73`) et le dépôt des routeurs IA
(`corpus_providers.dart:16-23`). Le « corpus » d'IFFD, ce sont donc **les outils de valeur en
douane** (`valuation_tools`) **et** le **routeur IA** (`ai_routers`) qui décide quel modèle sert
quelle tâche. Je les ai suivis.

| Chemin ajouté | Fichiers | Lignes | Raison |
|---|---:|---:|---|
| `lib/src/presentation/features/valuation_tools/` | 4 | 1 333 | l'IHM du corpus dont `features/corpus/` porte les dépôts |
| `lib/src/presentation/features/ai_routers/` | 5 | 2 535 | l'autre moitié de `corpus_providers.dart` |
| `lib/src/domain/models/subject_model.dart` | 1 | 235 | l'entité « matière » |
| `lib/src/domain/models/folder_document*.dart` (4) | 4 | 692 | document + annotation + lecture + maîtrise |
| `lib/src/domain/models/valuation/valuation_tool_model.dart` | 1 | 581 | les 10 types du corpus |
| `lib/src/domain/models/ai/ai_models.dart` | 1 | 581 | `IffdAiRouterModel` |
| `lib/src/domain/repositories/` (7 ports du domaine) | 7 | 329 | contrats matière / document / corpus / routeur |
| `lib/src/domain/security/document_access_service.dart` | 1 | 238 | l'ACL de document, réutilisée par 2 écrans |
| `lib/src/data/repositories/z_backed_folder_document_repository.dart` | 1 | 698 | l'adaptateur zcrud déjà écrit |
| `lib/src/utils/constants/valuation_tools/` (10) | 10 | 992 | **le corpus lui-même**, en constantes Dart |
| **Sous-total ajouté** | **35** | **8 214** | |

**Total du domaine cartographié : 62 fichiers, 18 400 lignes.**

Deux frontières que je n'ai **pas** franchies, en les nommant :
- `lib/src/presentation/features/folders/` (36 fichiers, **18 333 lignes**) — la « matière » et le
  « dossier » partagent leur page de contenus (`SubjectStudyToolsPage extends FolderStudyToolsPage`,
  `folder_study_tools_page.dart:2252`) et leur contrôleur (`FolderDetailsController`, 487 lignes,
  utilisé par `subject_details_page.dart:74`). Ce domaine relève d'une carte à lui.
- `lib/src/data/repositories/firebase_crud_repository_impl.dart` (499 lignes) — le socle Firestore
  générique de **tous** les dépôts de l'app.

---

## 2. Ce que le domaine sait faire (en termes d'utilisateur)

### 2.1 Matières (« Modules IFFD »)

1. **Parcourir les matières de sa filière et de son cycle.** Un onglet par couple
   filière × cycle auquel l'utilisateur a droit — jusqu'à **12** (`FiliereEtCycleIFFD`,
   `iffd_models.dart:31-44` : 6 filières × 2 cycles). Les onglets ne sont pas décoratifs : chacun
   porte sa **propre ACL** (`subjects_page.dart:487`, clé `"SubjectModel<filiere>"`), et un
   utilisateur sans aucun droit voit « Désolé, vous n'avez pas accès aux modules de l'IFFD »
   (`subjects_page.dart:434`).
2. **Voir d'un coup d'œil ce que contient une matière** — quatre compteurs vivants sur la carte
   (flashcards, notes, documents, cartes mentales), en squelette pendant le chargement
   (`subjects_page.dart:558-585`).
3. **Créer / modifier / supprimer une matière** : titre, filières et cycles, contexte global,
   agents IA experts (multiple), agent IA par défaut, instructions personnalisées
   (`subject_model_dialogs.dart:155-283`).
4. **Chaîner les choix par cascade** : vider « Filières et cycles » vide « Agents IA experts »,
   qui vide « Agent par défaut » — et le catalogue de chaque niveau est **filtré** par le niveau
   au-dessus (`subject_zcrud_edition.dart:540-604`, `SubjectCascadeCleaner`).
5. **Ouvrir le matériel pédagogique partagé** d'une matière : documents, notes, flashcards, cartes
   mentales, réordonnables (`subject_details_page.dart:426`, onglet 1).
6. **Faire expliquer un sujet par l'IA** dans le second onglet (`SubjectExplanationPage`,
   `folder_explanation_page.dart:276`).
7. **Choisir une matière** depuis un autre écran (`SubjectSelectionDialogWidget`, 83 lignes).

### 2.2 Documents

8. **Téléverser un ou plusieurs documents** (PDF, Word, Excel, PowerPoint, image, texte —
   `FolderDocumentType`, `folder_document.dart:9-35`), avec deux chemins distincts web/natif
   (`subject_details_page.dart:155-255`), puis **conversion automatique en PDF** côté serveur
   (`ai_repository.dart:88`).
9. **Suivre l'ingestion** : téléversement → converti → vectorisé, six états
   (`FolderDocumentStatus`, `folder_document.dart:57-69`), dont `readyForChat` qui conditionne
   l'usage du document par l'assistant.
10. **Lire un PDF avec annotations** : surligner, souligner, barrer, ondulé, note collante, dessin
    libre — avec palette de couleurs, opacité, annuler/refaire, recherche plein texte, mode plein
    écran, disposition et sens de défilement mémorisés, **reprise à la page où l'on s'était
    arrêté** (`FolderDocumentViewer`, `folder_documents_actions_dialog_widget.dart:860-1804`,
    944 lignes).
11. **Annoter en le sachant partagé** : l'annotation est une entité à part entière
    (`FolderDocumentAnnotation`, 259 lignes) rattachée au document **et** à son auteur.
12. **Générer des flashcards depuis un document** — soit le document entier, soit **des pages
    choisies une à une** avec extraction de texte page par page
    (`folder_document_pages_selection_dialog.dart`, 470 lignes).
13. **Générer une carte mentale depuis un document** (idem : entier ou pages choisies).
14. **Résumer un document** (idem).
15. **Retirer un document de l'assistant IA** (`ignoreDocumentForAssistant`,
    `folder_documents_actions_dialog_widget.dart:483`).
16. **Renommer, déplacer, supprimer** un document — la suppression purge aussi le fichier du
    stockage (`folder_documents_actions_dialog_widget.dart:672-686`).
17. **Joindre des documents à une conversation** avec l'assistant
    (`ChatbotDocumentSelectorDialogWidget`, 842 lignes ; et le chemin porté
    `notebook_document_picker_iffd.dart`, 103 lignes).

### 2.3 Corpus (outils de valeur en douane) et routage IA

18. **Consulter le Code du GATT** : dix familles de textes — Articles du GATT, Articles de
    l'Accord, Annexes, Notes interprétatives, Décisions, Avis consultatifs, Commentaires, Notes
    explicatives, Études de cas, Études (`valuation_tool_model.dart:135-160`).
19. **Chercher dans le corpus** par numéro exact, par titre ou par description, avec un **tri
    numérique par identifiant** (« 3.10 » après « 3.2 » — `valuation_tool_model_actions_dialog_widget.dart:480-500`).
20. **Créer / modifier un texte du corpus** : numéro d'identification, titre, description,
    contenu markdown (`valuation_tool_model_dialogs.dart:67-92`).
21. **Générer des flashcards ou une carte mentale depuis un texte du corpus**
    (`valuation_tool_model_actions_dialog_widget.dart:92` et `:155`).
    ⚠️ **Le résumé, lui, est une plomberie MORTE** : le `summaryCallback` est câblé de bout en
    bout — paramètre du dialogue (`:40`), relais depuis la grille (`:542`), état
    `areValuationToolModelSummarizing` du contrôleur (`folder_details_controller.dart:41`),
    indicateur visuel (`:437`) — mais **aucune tuile ne le déclenche** : le dialogue ne porte que
    quatre tuiles (« Générer des flashcards » `:92`, « Générer une carte mentale » `:155`,
    « Modifier » `:226`, « Supprimer » `:249`), et **grep négatif** sur
    `SummaryFromValuationTool|summarizeValuationTool|generateSummaryFromValuation` dans tout
    `lib/` → **RC=1**. Le bouton n'existe pas, la méthode d'`AiRepository` non plus.
22. **Restreindre une conversation IA à un corpus** — c'est le seul chemin par lequel les corpus
    atteignent la requête (`z_qa_flags.dart:503`).
23. **Configurer le routage IA par tâche** : un routeur porte **treize** couples
    « modèle principal + modèles de repli », un par type de génération — général, explication,
    chat, carte mentale, flashcards, résumé, élaboration, exemples, poème, histoire, humour, style
    de chat, réflexion (`ai_models.dart:194-234`) — plus l'effort de workflow et le **nombre de
    questions par type** (`ai_models.dart:237-245`).

---

## 3. Écrans et dialogues

### 3.1 Matières

| Fichier | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `subjects/pages/subjects_page.dart` | 941 | liste des matières | onglets par filière, recherche, grille de cartes, FAB, état vide illustré |
| `subjects/pages/subject_details_page.dart` | 506 | détail d'une matière | 2 onglets, 7 `StreamBuilder` imbriqués (`:78-120`), téléversement, barre d'actions |
| `subjects/dialogs/subject_model_dialogs.dart` | 333 | formulaire LEGACY + aiguillage | 8 `DynamicFormField`, cascade impérative, 3 entrées de dialogue |
| `subjects/dialogs/subject_zcrud_edition.dart` | 728 | **jumeau porté** | 6 `ZFieldSpec` (`:316`), 2 `ZEditionStep` (`:403`), cascade déclarative (`:540`) |
| `subjects/controllers/subject_details_controller.dart` | 186 | 🔴 **MORT** | aucun appelant hors de son propre fichier |
| `subjects/widgets/subject_selection_dialog_widget.dart` | 83 | choisir une matière | `StreamBuilder` + `ListView.builder` |
| `subjects/widgets/subject_actions_dialog_widget.dart` | 66 | menu d'actions | 2 tuiles — **la suppression ne demande AUCUNE confirmation** (`:51-60`) |
| `subjects/pages/subject_custom_assistant_page.dart` | 54 | 🔴 **MORT** | seul appel : une ligne commentée (`subject_details_page.dart:450`) |
| `subjects/subjects.dart` | 7 | barrel | exporte les deux fichiers morts |

### 3.2 Documents

| Fichier | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `documents/widgets/folder_documents_actions_dialog_widget.dart` | 1 804 | menu d'actions **+ visionneuse PDF** | 8 tuiles d'action + 22 `ListTile` + `FolderDocumentViewer` (944 l.) |
| `documents/widgets/document_viewer/bottom_toolbar.dart` | 855 | barre d'annotation mobile | surlignage / barré / souligné / ondulé, undo-redo |
| `documents/widgets/chatbot_document_selector_dialog_widget.dart` | 842 | choisir des documents pour l'IA | 4 `StreamBuilder`, sélection multiple |
| `documents/widgets/document_viewer/annotation_toolbar.dart` | 837 | barre d'annotation bureau | 18 couleurs codées en dur |
| `documents/widgets/document_viewer/color_palette.dart` | 483 | palette couleur + opacité | **52 couleurs codées en dur** |
| `documents/widgets/folder_document_pages_selection_dialog.dart` | 470 | choisir des pages d'un PDF | vignettes, extraction de texte page à page |
| `documents/dialogs/documents_dialogs.dart` | 323 | 5 entrées de dialogue | formulaire legacy à **1 champ** (`:78-86`) |
| `documents/widgets/document_selector_dropdown.dart` | 303 | 🔴 **MORT** | aucun appelant, **pas même exporté** par le barrel |
| `documents/widgets/document_viewer/search_toolbar.dart` | 229 | recherche plein texte PDF | |
| `documents/dialogs/folder_document_zcrud_edition.dart` | 212 | **jumeau porté** | **1** `ZFieldSpec` (`:73-89`) pour 123 lignes de coquille |
| `documents/widgets/folder_document_import_dialog_widget.dart` | 53 | import | appelé depuis `folder_modal_dialogs.dart:575` |
| `documents/documents.dart` | 9 | barrel | |
| `lib/src/features/documents/documents_module.dart` | **0 octet** | 🔴 **MORT** | + 3 répertoires vides (`pages/`, `providers/`, `widgets/`) |

### 3.3 Corpus et routeurs IA

| Fichier | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 823 | menu d'actions **+ grille** **+ page** | 3 classes en un fichier : `…ActionsDialogWidget` (`:36`, 4 tuiles), `ValuationToolsGridView` (`:271`), `ValuationToolsWidgets` (`:616`, 10 grilles empilées) |
| `ai_routers/pages/ai_routers_page.dart` | 803 | liste des routeurs | grille, recherche, état vide illustré |
| `ai_routers/dialogs/ai_routers_dialogs.dart` | 716 | formulaire LEGACY | 11 `DynamicFormField` + **14 appels** à `buildFallbackModelsField` |
| `ai_routers/zcrud/ai_router_zcrud_edition.dart` | 685 | **jumeau porté** | 5 `ZFieldSpec` + sous-listes + `IffdMinimumOneAcl` |
| `valuation_tools/dialogs/valuation_tool_model_zcrud_edition.dart` | 348 | **jumeau porté** | 4 `ZFieldSpec` (`:130`) |
| `ai_routers/zcrud/ai_router_sub_list_seams.dart` | 329 | coutures de sous-liste | |
| `valuation_tools/dialogs/valuation_tool_model_dialogs.dart` | 155 | 2 entrées de dialogue | formulaire legacy à 4 champs |
| `features/corpus/providers/corpus_providers.dart` (+ `.g.dart`) | 90 + 650 | 12 providers | 10 dépôts d'outils + routeur + agrégat |

### 3.4 Les jumeaux portés et leur drapeau

Le registre de bascules est unique : `lib/src/presentation/shared/zcrud/z_qa_flags.dart`
(985 lignes, **52** entrées `ZQaFlag` — je les ai comptées : 52 lignes `id: '…'`).

| Écran du périmètre | Jumeau porté | Drapeau | Défaut du code | **Actif dans `main.dart` ?** |
|---|---|---|---|---|
| Créer / modifier une matière | `subject_zcrud_edition.dart:605` | `subject` (`z_qa_flags.dart:580`) | `false` (`:170`) | ✅ **OUI** (`main.dart:205`) |
| Renommer un document | `folder_document_zcrud_edition.dart:120` | `folderDocument` (`z_qa_flags.dart:665`) | `false` (`:51`) | ❌ non |
| Outil de valeur en douane | `valuation_tool_model_zcrud_edition.dart:232` | `valuationTool` (`z_qa_flags.dart:800`) | `false` (`:83`) | ✅ **OUI** (`main.dart:204`) |
| Routeur IA | `ai_router_zcrud_edition.dart:436` | `aiRouterEdition` (`z_qa_flags.dart:434`) | **`true`** (`:104`) | ✅ **OUI** (`main.dart:202`) |

`main.dart:201-210` lève huit bascules : `notebook`, `aiRouterEdition`, `exam`, `valuationTool`,
`subject`, `flashcardEdition`, `anneeAccademique`, `aiExpert`. **Trois des quatre écrans du
périmètre tournent donc déjà sur le socle dans le binaire courant.** Le quatrième — le renommage
de document — ne coûte qu'une chaîne de plus dans ce `Set`.

Aucune LISTE du périmètre n'a de jumeau porté : `subjects_page.dart`, `ai_routers_page.dart` et
`ValuationToolsGridView` sont exclusivement legacy.

---

## 4. Modèles et persistance

### 4.1 Les entités

| Entité | Fichier | Lignes | Base | Sérialisation |
|---|---|---:|---|---|
| `SubjectModel` | `subject_model.dart:18` | 155 | `DynamicModel` | `toMap`/`fromMap` **à la main**, camelCase |
| `SubjectContentModel` | `subject_model.dart:159` | 77 | `DynamicModel` | idem |
| `FolderDocument` | `folder_document.dart:71` | 176 | `FolderContentModel` → `SubjectContentModel` | idem |
| `FolderDocumentAnnotation` | `folder_document_annotation.dart` | 259 | `DynamicModel` | idem |
| `FolderDocumentReading` | `folder_document_reading.dart` | 105 | `DynamicModel` | idem |
| `FolderDocumentLearningInfo` | `folder_document_learning_info.dart` | 82 | `DynamicModel` | idem |
| `ValuationToolModel` + **10 sous-classes** | `valuation_tool_model.dart` | 581 | `DynamicModel` | idem, **10 fois** |
| `IffdAiRouterModel` | `ai_models.dart:190` | 392 | `DynamicModel` | idem |

`DynamicModel` (79 lignes) est la base maison : `id`, `toMap()`, `copyWith()`, `props`, égalité
structurelle **profonde** écrite à la main (`dynamic_model.dart:52-71` — le commentaire dit
pourquoi : sans elle, `[] == []` vaut `false` et deux modèles identiques restaient inégaux).

Aucune annotation de génération : **grep négatif** —
`grep -rn "@ZcrudModel\|@JsonSerializable\|@freezed" lib/src/domain/models/` → **RC=1, aucune
occurrence**. Tout est écrit à la main.

### 4.2 Le dispatcher de désérialisation

`fromMap<T>` (`data_functions.dart:314-413`) est une **table `Map<Type, Function>` de 45 entrées**
tenue à la main — dont les 10 outils de valeur, `SubjectModel`, `FolderDocument`, ses trois
satellites, et `IffdAiRouterModel`. La table est **reconstruite à chaque appel** (elle est déclarée
dans le corps de la fonction, `:336`).

C'est exactement ce que `ZcrudRegistry` fait par codegen. Le fichier `reflector.dart` (le
`reflectable` d'origine) est **entièrement commenté** — l'hôte a déjà renoncé à la réflexion.

### 4.3 Les ports et l'implémentation

- **Port unique** : `CrudRepository<T>` (`datacrud_repository.dart:20-62`) — 20 méthodes,
  `create` / `mapCreate` / `streamAll` / `streamOne` / `count` / `batchSet` / `batchUpdate` /
  `softDelete` / `delete` / `restore`…
- **Implémentation** : `FirebaseCrudRepositoryImpl<T>` (499 lignes) — Firestore direct,
  **10 `catch`**, converti en `DataState<T, Exception>`.
- **Traitement des erreurs** : `DataState` (91 lignes) — `DataSuccess` / `DataFailed` /
  `DataNotSet` + 5 sous-types (`DataCreated`, `DataUpdated`, `DataDeleted`, `DataRestored`,
  `DataValidated`). **Ce n'est PAS `Either<ZFailure, T>`** : grep négatif sur `Either<` dans tout
  le périmètre → **3 occurrences seulement, toutes dans les 3 jumeaux portés**
  (`subject_zcrud_edition.dart:676`, `folder_document_zcrud_edition.dart:168`,
  `valuation_tool_model_zcrud_edition.dart:302`), et ce sont des `Right<ZFailure, Map>` de
  soumission de formulaire, pas des retours de dépôt.
- **Requêtes** : `DataRequest<T>` (213 lignes) — 12 familles d'opérateurs (`where`, `whereIn`,
  `arrayContainsAny`, `isGreaterThan`, `or`, `and`…) + un `itemFilter` **côté client**
  (`data_request.dart:19`), utilisé pour ce que Firestore ne sait pas exprimer
  (`subject_repository.dart:20-25` : « les contenus de la matière qui n'ont pas de dossier »).
- **Pas de pagination par curseur** : `DataRequest` porte `limit`, jamais de curseur.
  Grep négatif : `grep -n "cursor\|startAfter\|Cursor" data_request.dart` → **aucune occurrence**.
- **Source** : Firestore direct, **pas de cache local, pas de synchronisation**. Grep négatif :
  `grep -rn "Hive\|offline" lib/src/data/repositories/firebase_crud_repository_impl.dart` →
  aucune occurrence.

### 4.4 Ce qui est déjà mappé vers une entité zcrud

`ZBackedFolderDocumentRepository` (`z_backed_folder_document_repository.dart`, **698 lignes**)
traduit `FolderDocument` ↔ **`ZStudyDocument`** (`package:zcrud_document`) sans perte, avec une
table de correspondance documentée (`:64-104`) et le passage par `ZSyncMeta` pour le soft-delete.
Il est **derrière un drapeau à `false`** : `useZcrudFolderDocumentRepositoryProvider`
(`folder_providers.dart:56-63`).

**Six** dépôts adossés zcrud existent au même niveau (`z_backed_*.dart` : exam 912, mindmap 806,
flashcard 797, folder 772, document 698, note 663 — **4 648 lignes**), **tous derrière un drapeau
à `false`** (`folder_providers.dart:40`, `:56`, `:72`, `:88` pour les quatre du domaine étude).

**Rien n'est mappé pour** : `SubjectModel`, `ValuationToolModel` et ses 10 sous-classes,
`IffdAiRouterModel`, `FolderDocumentAnnotation`, `FolderDocumentReading`,
`FolderDocumentLearningInfo`. Grep négatif :
`grep -rn "ZDocumentAnnotation\|ZDocumentReadingState\|ZDocumentLearningInfo" lib` → **RC=1,
aucune occurrence** — alors que les trois entités **existent** dans `zcrud_document`
(`packages/zcrud_document/lib/zcrud_document.dart:67-74`).

---

## 5. 🔴 LE CODE RÉPÉTÉ

Chaque ligne de ce tableau est un **assemblage manquant au socle**. Les sites et lignes sont
mesurés, pas estimés, sauf mention « ≈ ».

| # | Bloc répété | Sites | Lignes | Où (échantillon) |
|---|---|---:|---:|---|
| **D1** | **Les 10 sous-classes d'outil du corpus** — constructeur + `copyWith` + `fromMap` + `toString`, **identiques au mot près**, seul le nom du type change | **10** | **419** | `valuation_tool_model.dart:163` `:205` `:247` `:289` `:331` `:373` `:415` `:457` `:499` `:541` |
| **D2** | **Les 10 dépôts Firebase du corpus** — `class Firebase<X>RepositoryImpl extends FirebaseCrudRepositoryImpl<X> implements ValuationToolModelRepository<X>` | **10** | **129** | `firebase_models_repositories_impls.dart:306-434` |
| **D3** | **Les 10 providers Riverpod du corpus** + leur code généré | **10** | **48 + 650** | `corpus_providers.dart:26-73` ; `corpus_providers.g.dart` (650 l. générées) |
| **D4** | **Le dispatcher de type du corpus** — `if (T == ArticleGATT) … else if (T == …)`, 10 branches | **10** | **22** | `valuation_tool_model_repository.dart:46-68` |
| **D5** | **La table de fabriques du corpus, une SECONDE fois** | **10** | **12** | `valuation_tool_model.dart:65-79` |
| **D6** | **Les 10 `ValuationToolsGridView<T>` empilés**, 15 paramètres recopiés à chaque fois | **10** | **174** | `valuation_tool_model_actions_dialog_widget.dart:650-823` |
| **D7** | **Les 13 couples « modèle + replis » du routeur IA** — champs, constructeur, `copyWith` (signature **et** corps), `toMap`, `fromMap`, `props` : six recopies de la même liste de 13 | **13 × 6** | **≈ 182** | `ai_models.dart:194-234` (champs), `:243-270` (ctor), `:283-310` (copyWith sig.) |
| **D8** | **`buildFallbackModelsField(…)`** — le même groupe de sous-liste, appelé une fois par tâche | **14** | **66** | `ai_routers_dialogs.dart:540-605` |
| **D9** ⚠️ | **La coquille d'un formulaire porté** — *canal du socle IGNORÉ, pas manquant : cf. §5.2* — drapeau (`const bool k…Default` + `Provider<bool>`) + `State` (`_fields`/`_controller`/`_submit`, `initState`, `dispose`, `_onSave`) + `Scaffold` + `AppBar` + `Semantics/IconButton` « Enregistrer » + `DynamicEdition` | **12** | **≈ 840** | les 12 fichiers portant `label: 'Enregistrer'` — dont `subject_zcrud_edition.dart:640-728` (89 l.) et `folder_document_zcrud_edition.dart:146-212` (67 l. **pour UN champ**) |
| **D10** | **Le drapeau de bascule seul** (`const bool k…Default` + `final Provider<bool> …`) | **52 providers / 56 constantes** | **≈ 950** | `folder_document_zcrud_edition.dart:49-67` (19 l.) est le gabarit |
| **D11** | **L'état vide illustré** — cercle 180 dp + 2 cercles concentriques + `ShaderMask` + titre + description + bouton dégradé | **6** | **≈ 900** (155 l. mesurées sur le site matières) | `subjects_page.dart:128-282`, `ai_routers_page.dart:150`, `accademic_years_page.dart:162`, `user_role_page.dart:112`, `ai_experts_page.dart:140`, `auditeurs_pages.dart:299` |
| **D12** | **La palette de 8 dégradés**, valeurs et ordre **identiques à l'octet** (3 sites sur 4 ; le 4ᵉ est tronqué à 6) | **4** | **44** | `subjects_page.dart:49`, `user_role_page.dart:31`, `auditeurs_pages.dart:50`, `accademic_years_page.dart:28` |
| **D13** | **Le post-traitement d'une génération IA** — décoder le JSON, reconstruire les modèles, sauver (par lots de 10 avec pause d'1 s en repli) | **9** sites d'écriture de flashcards (11 appels dont 2 commentés) / **7** sites de carte mentale | **≈ 540** | flashcards : `valuation_tool_model_actions_dialog_widget.dart:129`, `folder_documents_actions_dialog_widget.dart:733` **et** `:750`, `smartnote_actions_dialog_widget.dart:143`, `folder_content_add_dialog_widget.dart:94`, `folder_tags_selection_dialog_widget.dart:166`, `content_hub_zcrud.dart:200`, `popup_menu_helpers.dart:327` **et** `:742` — carte mentale : `valuation…:173`, `smartnote…:201`, `folder_documents…:784`, `explain_ai_page.dart:518`, `popup_menu_helpers.dart:358` **et** `:791`, `chatbot_conversation_screen.dart:631` |
| **D14** | **La tuile d'action** `Material > Opacity > ListTile(leading, title, enabled, onTap)` | **53** | **≈ 640** | 8 dialogues d'actions : documents 22, corpus 7, dossier 7, note 6, flashcard 5, examen 2, rôle 2, matière 2 |
| **D15** | **La queue d'un dialogue d'édition** — `if (result != null) { result["id"] = randomString(); final m = fromMap<T>(result); switch (crud) { create → repo.create; update → repo.update } }` | **11** | **≈ 200** | `subject_model_dialogs.dart:66-83`, `documents_dialogs.dart:97-118`, `valuation_tool_model_dialogs.dart:98-115`, `ai_routers_dialogs.dart:89-…` (+7) |
| **D16** | **Les registres d'« en cours » par item** — `Map<String?, bool> areXY = {}` + `void setXY(…) { …; notifyListeners(); }` + `bool isXY([id]) => …` | **26** (18 + 8) | **≈ 310** | `folder_details_controller.dart:31-51` (18 cartes, 31 accesseurs), `subject_details_controller.dart:22-29` (8, **fichier mort**) |
| **D17** | **Les sous-classes vides de contrôleur de recherche** — `class XListController extends DynamicListSearchController {}` | **16** | **37** | `dynamic_list_search_controller.dart:35-71` |
| **D18** | **Le compteur en badge** — `StreamBuilder<DataCount<T>>` imbriqué (4 niveaux) + `_buildStatBadge` | **10** streams / **2** badges | **≈ 180** | `subjects_page.dart:558-585` + `:904`, `folders_page.dart` (5 streams, 6 réf.), `public_folders_page.dart` |
| **D19** | **La table de fabriques de désérialisation**, tenue à la main et **réallouée à chaque appel** | **45 entrées** | **74** | `data_functions.dart:336-409` |
| **D20** | **L'en-tête chercheuse** — `PreferredSize(preferredSize: Size.fromHeight(kToolbarHeight * n), child: DynamicSearcheableAppBar<C>(…))` | **21** | **≈ 250** | `subjects_page.dart:70-84`, `subject_details_page.dart:288-403`, + 13 fichiers |

**Total mesuré du code répété identifié : ≈ 6 700 lignes**, dont **≈ 1 450 pour le seul corpus**
(D1→D6) et **≈ 1 790 pour la coquille de portage** (D9+D10).

### 5.1 Le cas le plus net : le corpus

Dix types qui ne se distinguent **que par leur nom** coûtent aujourd'hui, en cumul :
419 (modèles) + 129 (dépôts) + 48 + 650 (providers) + 22 (dispatcher) + 12 (fabriques) +
174 (grilles) + 10 entrées dans `fromMap` + 10 dans `tabsTypes` + 10 dans `tabsTitles`
= **≈ 1 490 lignes pour zéro différence de comportement**.

Une seule `@ZcrudModel` sur un `ZValuationText` portant `kind` (10 valeurs d'enum) + un
`ZCrudScreen` à onglets rendrait tout cela dérivé. **C'est la démonstration la plus courte de
l'objectif produit n°2.**

### 5.2 Le cas le plus coûteux : la coquille de portage

`folder_document_zcrud_edition.dart` est le juge de paix : **212 lignes pour porter UN champ
texte**. La déclaration utile fait **18 lignes** (`:73-89`). Les 123 lignes de `State` +
`Scaffold` + `AppBar` + bouton « Enregistrer » + `IffdZcrudScope` sont recopiées **12 fois**
dans l'app.

🔴 **Et le gabarit court existe déjà — dans la même application.** Mesuré le 2026-08-26 :

| Gabarit | Fichiers | Exemple | Lignes | Chrome écrit à la main |
|---|---:|---|---:|---|
| **`presentFormEdition` / `ZFormOnly`** (socle) | **12** portent `ZFormOnly` ; **16** sites d'appel `presentFormEdition(` | `lib/workflow/screens/zcrud/task_list_zcrud_edition.dart` (2 champs) | **117** | **aucun** — un seul appel `presentFormEdition(` (`:111`) |
| **`Scaffold` + `AppBar` maison** | les **4 jumeaux du périmètre** | `folder_document_zcrud_edition.dart` (1 champ) | **212** | `Scaffold` ×1, `AppBar` ×1, bouton « Enregistrer » |

**Les quatre jumeaux du périmètre n'utilisent NI l'un NI l'autre canal du socle** — mesure exacte,
`grep -c` par fichier :

| Jumeau | Lignes | `ZFormOnly` | `presentFormEdition` | `Scaffold(` | `AppBar(` |
|---|---:|---:|---:|---:|---:|
| `subject_zcrud_edition.dart` | 728 | **0** | **0** | 1 | 1 |
| `folder_document_zcrud_edition.dart` | 212 | **0** | **0** | 1 | 1 |
| `valuation_tool_model_zcrud_edition.dart` | 348 | **0** | **0** | 1 | 1 |
| `ai_router_zcrud_edition.dart` | 685 | **0** | **0** | 1 | 1 |

⇒ **Ce n'est PAS un assemblage manquant au socle : c'est un canal du socle ignoré dans ce
périmètre precisement.** Onze éditions portées ailleurs dans `lib/` (`ai_expert`, `annee_accademique`,
`app_user_role`, `auditeur_iffd`, `auditeurs_filter`, `first_login`, `flashcards_questions_count`,
`folder_flashcards_filter`, `folders_filter`, `task_list`, `chatbot_conversation`) ont déjà fait le
pas. La correction ne demande **aucun développement côté zcrud** — elle demande d'aligner ces quatre
fichiers, pour un gain mesuré de l'ordre de **95 lignes par fichier** (212 → 117 sur le cas à un
champ).

---

## 6. Ce qui est DÉJÀ branché sur zcrud

### 6.1 L'empreinte globale (contexte)

- **25 paquets zcrud déclarés** au `pubspec.yaml`, **22 réellement importés** par le code.
- **110 fichiers** de `lib/` importent `package:zcrud_*` (**48 884 lignes**).
- **98 fichiers** portent `zcrud` dans leur chemin (**27 481 lignes**).

Répartition des imports par paquet (nombre de lignes `import 'package:zcrud_X`) :

| Paquet | Imports | Paquet | Imports |
|---|---:|---|---:|
| `zcrud_core` | 67 | `zcrud_firestore` | 5 |
| `zcrud_chat_kernel` | 19 | `zcrud_mindmap` | 4 |
| `zcrud_study` | 17 | `zcrud_ui_kit` | 3 |
| `zcrud_screen` | 16 | `zcrud_session` | 3 |
| `zcrud_chat` | 15 | `zcrud_chat_syncfusion` | 3 |
| `zcrud_markdown` | 11 | `zcrud_chat_material` | 3 |
| `zcrud_flashcard` | 9 | `zcrud_select` / `zcrud_intl` / `zcrud_chat_markdown` | 2 chacun |
| `zcrud_study_kernel` | 6 | `zcrud_note` / `zcrud_menu` / `zcrud_exam` / `zcrud_document` | 1 chacun |
| `zcrud_navigation` | 6 | | |

### 6.2 Dans le périmètre : trois imports, un seul paquet

**Grep exhaustif** de `package:zcrud_` sur `subjects/`, `documents/`, `features/subjects/`,
`features/corpus/`, `valuation_tools/` :

```
subjects/dialogs/subject_zcrud_edition.dart:156            import 'package:zcrud_core/zcrud_core.dart';
documents/dialogs/folder_document_zcrud_edition.dart:45    import 'package:zcrud_core/zcrud_core.dart';
valuation_tools/dialogs/valuation_tool_model_zcrud_edition.dart:75  import 'package:zcrud_core/zcrud_core.dart';
```

**Trois lignes. Un seul paquet. Aucune liste, aucun écran, aucun menu, aucun document.**
(`ai_routers/zcrud/ai_router_zcrud_edition.dart:47` en ajoute un quatrième, hors des quatre
répertoires du périmètre initial.)

### 6.3 Ce qui est consommé du socle

| Symbole zcrud | Où | Usage |
|---|---|---|
| `ZFieldSpec` / `EditionFieldType` / `ZValidatorSpec` / `ZTextConfig` | 4 jumeaux du périmètre | **17 champs déclarés** (6 matière, 1 document, 4 outil, 5+ routeur) |
| `ZFormController` / `ZEditionSubmitController` | 12 fichiers | moteur d'édition granulaire |
| `DynamicEdition` | 10 fichiers | rendu du formulaire |
| `ZStepperEdition` + `kIffdStepperConfig` | 5 fichiers | mode « étapes tout affiché » (`subject_zcrud_edition.dart:721`) |
| `ZRelationConfig` / `ZRelationSourceRegistry` | matière (`:288-298`, `:352-374`) | les deux selects d'experts IA, avec `filterKeys` déclaratif — **le canal qui remplace l'imbrication `widget` du legacy** |
| `ZSubListConfig` + `ZAcl` | routeur IA | sous-listes de modèles de repli, ACL « au moins un » (`IffdMinimumOneAcl`) |
| `presentFormEdition` (`zcrud_screen`) | **16 fichiers** | présentation du formulaire |
| `ZItemActionsMenu` + `ZMenuEntryTile` (`zcrud_study`, `zcrud_menu`) | **1 seul fichier** (`folders/zcrud/folder_actions_menu_zcrud.dart`) | menu d'actions d'item |

### 6.4 Ce qui est enregistré au registre de widgets

`IffdZcrudScope` (`z_iffd_field_registry.dart:227-416`, monté **23 fois** dans `lib/` (24 occurrences dont son propre constructeur `:229`)) pose un
`ZcrudScope` (`:345`) portant :

| Canal | Contenu | Ligne |
|---|---|---|
| `widgetRegistry` | `registerZMarkdownFields` (codec `IffdRichTextCodec` + `iffdMarkdownStyleSet` + chrome) | `:101-146` |
| | `registerZFlashcardEditors` (Vrai/Faux/Ajouter une proposition) | `:171-176` |
| | `register('phoneNumber', ZPhoneFieldWidget.builder())` | `:188` |
| | `register(kIffdBooleanKind, iffdBooleanBuilder())` — `FlutterSwitch` | `:199` |
| `theme` | jetons IFFD mémoïsés par luminosité (`z_iffd_form_theme.dart`, 281 l.) | `:354` |
| `gradientResolver` | teinte par type de champ (`z_iffd_field_palette.dart`, 225 l.) | `:363` |
| `iconResolver` | clés d'icône d'ornement IFFD | `:369` |
| `colorKeyResolver` | clés de couleur IFFD | `:375` |
| `selectPresenter` | `ZSmartSelectPresenter` (`zcrud_select`) | `:386` |
| `defaultTextConfig` | `ZTextConfig(textTransform: ucFirstLegacy)` — la casse du legacy, **une fois pour toute l'app** | `:395` |
| `numberDisplayFormatter` | `IffdNumberDisplayFormatter` — « 12 », jamais « 12.0 » | `:401` |
| `dateDisplayFormatter` | `IffdDateDisplayFormatter` | `:418`-`:446` |

Un **champ maison** enregistré et propre au périmètre voisin : `z_iffd_acl_matrix_field.dart`
(262 l.) et `z_questions_counts_field.dart` (169 l., **partagé** entre le routeur IA et la
génération de flashcards).

---

## 7. Les widgets maison qui refont ce que le socle fait probablement

### 7.1 🔴 Le plus gros : l'écran CRUD assemblé n'est utilisé nulle part

**Grep négatif prouvé** : `grep -rn "ZCrudScreen" lib` → aucune occurrence de la classe du socle
(les 7 résultats de `ZcrudScreen` sont la classe **locale** `TestExamFilterZcrudScreen`).
Des **16** imports de `zcrud_screen` : **15** amènent `presentFormEdition` (**16** sites
d'appel `presentFormEdition(`), **10** amènent **AUSSI** `ZFormOnly` + `ZFormOnlyController`,
et **1** (`first_login_zcrud_edition.dart`) n'amène **que** `ZFormOnly`/`ZFormOnlyController`.
`ZFormOnly` est donc consommé dans **12 fichiers** de `lib/` — mais **aucun** n'est du périmètre
(cf. §5.2).

`ZCrudScreen` (`packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart`, 4 428 lignes)
porte déjà, en paramètres déclarés : `tabs` + `tabsStore` + `tabsScopeKey` (`:348`, `:396`,
`:409`), `searchEnabled` (`:657`), `acl` + `rowAcl` + `actionAclMode` (`:280`, `:866`, `:874`),
`rowActions` + `rowActionsPresentation` + `inlineActionLimit` (`:694`, `:895`, `:900`),
`confirmDestructive` (`:930`), `canCreate` / `canDuplicate` (`:462`, `:472`), `trash` +
`trashPolicy` + `trashCount` (`:480`, `:496`, `:526`), `layout` + `itemBuilder` (`:302`, `:310`),
`export` (`:1003`), `selection` + `batchActions` (`:984`, `:990`), `history` (`:684`).

Face à cela, IFFD écrit à la main :

| Écran maison | Lignes | Ce que `ZCrudScreen` couvre déjà |
|---|---:|---|
| `subjects_page.dart` | **941** | onglets, ACL par onglet, recherche, création, grille, état vide |
| `ai_routers_page.dart` | **803** | idem |
| `ValuationToolsGridView` (dans le fichier d'actions) | **345** | idem + tri + recherche |
| *(hors périmètre, même forme)* `folders_page` 1 542, `ai_experts_page` 1 330, `auditeurs_pages` 1 281, `accademic_years_page` 692, `user_role_page` 632, `public_folders_page` 413, `exams_page` 333 | **6 223** | idem |

**Obstacle réel et nommé** : `ZCrudSource<T extends ZEntity>`
(`packages/zcrud_screen/lib/src/presentation/z_crud_source.dart:45`). Les entités IFFD étendent
`DynamicModel`, pas `ZEntity`. Adopter `ZCrudScreen` suppose donc, pour chaque type, soit une
entité zcrud (comme `ZStudyDocument` pour les documents), soit un adaptateur. **Pour la matière,
l'entité n'existe pas** : grep négatif —
`grep -rn "class ZSubject\|class ZStudySubject\|class ZCourse\|class ZDiscipline" packages/*/lib`
→ **aucune occurrence**. `ZStudyFolder` existe (`zcrud_study_kernel`), et il ne porte **pas** de
`subjectId` (`z_study_folder.dart:140-206` : `id`, `title`, `colorKey`, `parentId`, `ownerId`,
`archivedAt`, `createdAt`, `updatedAt`, `isPublic`, `sharedWith`, `canBeJoinedWithLink`,
`coWorkersCanInviteOthers`, `shareId`) — IFFD le loge dans `extra`.

### 7.2 La visionneuse PDF et ses barres

| Widget maison | Lignes | Ce que `zcrud_document` v3.21.0 offre déjà |
|---|---:|---|
| `document_viewer/annotation_toolbar.dart` | 837 | **`ZAnnotationToolbar`** (`zcrud_document.dart:91`) |
| `document_viewer/bottom_toolbar.dart` | 855 | idem (variante compacte) |
| `document_viewer/color_palette.dart` | 483 | les clés de nuancier `kAnnotationSwatchKeyPrefix` / `kAnnotationSwatchFillKeyPrefix` de `ZAnnotationToolController` (`zcrud_document.dart:83-90`), la palette elle-même venant de `ZColorPalette` (`zcrud_study_kernel.dart:54`) |
| `document_viewer/search_toolbar.dart` | 229 | — (pas d'équivalent trouvé) |
| `FolderDocumentViewer` (dans le fichier d'actions) | 944 | **`ZDocumentViewerChrome`** + `ZDocumentPageNavigation` + `ZDocumentViewerLoadState` (`zcrud_document.dart:92-96`) — coquille sans moteur de rendu, exactement la frontière qu'IFFD franchit à la main |
| — | | **`ZAnnotationPanel`** (`zcrud_document.dart:82`) : aucun équivalent maison |
| **Total** | **3 348** | |

**Grep négatif** : `grep -rn "ZAnnotationToolbar\|ZAnnotationPanel\|ZDocumentViewerChrome" lib`
→ **RC=1, aucune occurrence**. Ces quatre surfaces du socle sont **inconnues de l'hôte**.

De même pour le domaine : `ZDocumentAnnotation`, `ZDocumentReadingState`,
`ZDocumentLearningInfo` existent dans `zcrud_document` et **aucun n'est consommé** — alors
qu'IFFD maintient `FolderDocumentAnnotation` (259 l.), `FolderDocumentReading` (105 l.) et
`FolderDocumentLearningInfo` (82 l.) à la main.

### 7.3 Les menus d'actions

`ZItemActionsMenu` (`zcrud_study`) est adopté **dans un seul fichier**
(`folders/zcrud/folder_actions_menu_zcrud.dart`, 241 l.). Il apporte, dit son propre en-tête
(`:22-30`), la règle **« `onSelected == null` ⇒ action ABSENTE »** — là où le legacy affiche
l'entrée puis ne fait rien.

**Grep négatif** : `grep -rn "ZItemAction" lib/src/presentation/features/{subjects,documents,valuation_tools}`
→ **RC=1, aucune occurrence**.
Les 8 dialogues d'actions du reste de l'app (**3 554 lignes**, 53 tuiles) restent maison, dont les
deux plus gros du périmètre : documents **1 804 l.** et corpus **823 l.**

### 7.4 Les listes non virtualisées

`GridView.count` (qui construit **tous** ses enfants) est utilisé **23 fois** dans **18** fichiers,
dont `subjects_page.dart:318` — sous un `SingleChildScrollView`, avec
`physics: NeverScrollableScrollPhysics` : la grille des matières est **entièrement construite**
à chaque rendu. `ListView(` (non-`.builder`) apparaît **14 fois** (grep strict `[^a-zA-Z]ListView(`). C'est le
« Never `ListView(children: [...])` » du socle, à **34 sites**.

### 7.5 Le reste

| Widget maison | Lignes | Homologue socle |
|---|---:|---|
| `DynamicSearcheableAppBar<C>` | 372 | `searchEnabled` + `ZAppBarAction` / `ZAppBarActionsBuilder` de `ZCrudScreen` |
| `DynamicListSearchController` + 16 sous-classes vides | 71 | `ZListController` |
| `StatelessItemDialogWidget<T>` | 48 | `ZRowActionMenu` / `ZItemActionsMenu` |
| `EmptyFolderContent` + `FolderContentType` | 183 | état vide déclaré par `ZCrudScreen` |
| `RessourceACL` (11 booléens) + `AppUserPermissions` | 163 + 256 | `ZAcl` (port abstrait, `ZCrudAction` à 11 valeurs) |
| `DocumentAccessService` | 238 | `ZAcl` + `rowAcl` |

---

## 8. Ce que le domaine fait de PARTICULIER — et qui résiste

Ce sont les points sur lesquels **aucun assemblage générique ne doit être promis** sans échappatoire.

1. **🔴 Un identifiant de document Firestore codé en dur dans l'IHM.**
   `"AiOtWJ3A5oWkMEvc"` — la matière « valeur en douane » — décide seul de l'apparition du bouton
   « Code du GATT ». **Quatre sites l'écrivent en littéral inline** :
   `subject_details_page.dart:307`, `folder_details_page.dart:1187`,
   `public_folders_details_page.dart:519`, `folder_flashcards_list_page.dart:957` — et une
   cinquième occurrence le nomme enfin, côté porté seulement
   (`kFolderFlashcardsFilterValuationSubjectId`, `folder_flashcards_filter_zcrud_edition.dart:163`).
   Aucune généralisation ne récupérera cette règle : c'est une **donnée**, pas une structure. Elle
   doit devenir une déclaration de l'hôte avant tout portage de ces écrans.

2. **Le corpus est un fond de constantes Dart, complété par Firestore — pas l'inverse.**
   `valuation_tool_model_actions_dialog_widget.dart:337-378` : les items **locaux**
   (`lib/src/utils/constants/valuation_tools/`, 992 lignes, `id` = `hashCode` de la map) sont la
   base ; le flux Firestore ne fournit qu'un **remplacement d'`id` et de `title`**. Un item en
   ligne **sans jumeau local n'apparaît jamais**. Aucun `ZRepository` ne modélise cela : c'est
   une source **fusionnée local-prioritaire**, avec appariement par `identifier`.

3. **Le tri par identifiant numérique segmenté.** « 3.10 » vient après « 3.2 » : l'identifiant est
   découpé sur `.`, chaque segment converti en entier, comparés premier puis dernier
   (`valuation_tool_model_actions_dialog_widget.dart:481-505`). Un tri lexicographique de socle
   donnerait un ordre faux sur tout le Code du GATT.

4. **L'ACL n'est pas par type, mais par type × filière × cycle.**
   `permissions.getACL("SubjectModel${filiere.name}").or(permissions.getACL<SubjectModel>())`
   (`subjects_page.dart:396-398`) — **jusqu'à 12 ACL pour une seule entité**, avec un **repli**
   sur l'ACL du type. `AuditeurIffd${accademicYear}_${filiere.name}` (`subject_model_dialogs.dart:200`)
   ajoute même l'année académique dans la clé. `ZAcl.can(action, {target, collectionId})` peut
   l'exprimer — mais la **composition par `.or()`** et la fabrication de la clé sont propres à IFFD.

5. **Le vocabulaire d'actions dépasse le CRUD.** `Crud` (`crud.dart:6-25`) porte 17 valeurs, dont
   `move` et **six actions IA** : `aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`,
   `aiExplain`, `aiChat`, chacune soumise à permission. `ZCrudAction`
   (`packages/zcrud_core/lib/src/domain/ports/z_acl.dart:28-61`) en a **11** — `view`, `create`,
   `update`, `delete`, `restore`, `copy`, `archive`, `publish`, `clear`, `validate`, `history` :
   **ni `move`, ni aucune action IA**. Sept actions gouvernées d'IFFD n'ont pas de nom côté socle.

6. **Le routage IA est par ROUTE et par TYPE DE GÉNÉRATION.** `IffdAiRouterModel` déclare treize
   couples « modèle + replis », un par intention (`ai_models.dart:194-234`), plus un effort de
   workflow et un **nombre de questions par type de question** (`ai_models.dart:239`). C'est
   exactement le « mode par route » de la décision d'owner du 2026-08-23 — et la répétition D7/D8
   montre que ce mode **appelle un assemblage**, pas treize recopies.

7. **La cascade de matière efface, elle ne se contente pas de filtrer.** Vider « Filières et
   cycles » **remet à `null`** l'expert par défaut, et le modèle doit savoir distinguer « non
   fourni » de « mis à `null` » — d'où la sentinelle `_undefined` de `copyWith`
   (`subject_model.dart:15`, `:151`, `:163`) et `preserveNullKeys` à la sortie du formulaire porté
   (`subject_zcrud_edition.dart:673`, alimenté par `SubjectCascadeCleaner.clearedKeys` `:546`).

8. **Deux champs, deux hauteurs, dans le même formulaire.** « Contexte global »
   `minLines: 3 / maxLines: 5`, « Instructions personnalisées » `minLines: 5 / maxLines: 10`
   (`subject_zcrud_edition.dart:348-382`). Le commentaire dit que c'était inexprimable avant
   CR-IFFD-25 §2 (v0.10.0) — c'est aujourd'hui acquis, et ça doit le rester.

9. **Le contenu du corpus est 100 % markdown, jamais Delta.** `IffdRichTextCodec`
   (`z_iffd_rich_text_codec.dart`, 193 l.) existe parce que le défaut du socle (`ZDeltaCodec`)
   rendrait vide **~11 400 valeurs** du corpus (`z_iffd_field_registry.dart:20`). Toute adoption
   d'un champ riche dans ce domaine doit passer par ce codec.

10. **Le document a trois satellites personnels, jamais colocalisés.** Annotation (partagée, par
    auteur), lecture en cours (page, disposition, sens), maîtrise par page. Ils vivent dans trois
    collections et trois dépôts distincts (`folder_document_annotation_repository.dart`,
    `folder_document_reading_repository.dart`, `folder_document_learning_repository.dart`).
    `zcrud_document` fait la **même** séparation — c'est une convergence, pas un obstacle.

11. **La suppression d'une matière ne confirme rien.** `subject_actions_dialog_widget.dart:51-60`
    appelle `deleteSubject` directement, sans `buildConfirmDialog` — alors que le document
    (`folder_documents_actions_dialog_widget.dart:670-687`) et le corpus le font. `ZCrudScreen`
    porte `confirmDestructive` (`:930`) : l'adopter **changerait le comportement**, et c'est à
    signaler en QA plutôt qu'à découvrir.

---

## 9. Code mort trouvé dans le périmètre

L'hôte vient d'en supprimer six fichiers (1 629 lignes, commit `a3d10b7`). Il en reste **quatre**
dans ce domaine :

| Fichier | Lignes | Preuve |
|---|---:|---|
| `subjects/controllers/subject_details_controller.dart` | 186 | `grep -rn "SubjectDetailsController" lib` → **2 occurrences, toutes deux dans le fichier lui-même** (`:9` la classe, `:12` son constructeur). Exporté par le barrel `subjects.dart:1`. |
| `documents/widgets/document_selector_dropdown.dart` | 303 | `grep -rn "DocumentSelectorDropdown" lib test` hors du fichier → **RC=1**. **Pas exporté** par `documents.dart`. |
| `subjects/pages/subject_custom_assistant_page.dart` | 54 | seul appel : `subject_details_page.dart:450`, **ligne commentée**. Exporté par `subjects.dart:3`. |
| `lib/src/features/documents/documents_module.dart` | **0 octet** | + `pages/`, `providers/`, `widgets/` **vides** |
| **Total** | **543** | |

---

## 10. Ce qui est gardé par des tests

| Suite | Fichiers | Lignes | Ce qu'elle garde |
|---|---:|---:|---|
| `test/w7o/` | 3 | 1 321 | matière : aiguillage du drapeau, cascade legacy, jumeau zcrud |
| `test/w7p/` | 3 | 984 | outil de valeur : aiguillage, legacy, jumeau |
| `test/w7d/` | 2 | 482 | document : contrat legacy figé, jumeau |
| `test/w8l/` | 1 | 229 | routeur IA |
| `test/w5/` | 6 | 837 | `ZBackedFolderDocumentRepository` : mapping, drapeau, clés réservées |
| **Total** | **15** | **3 853** | |

Le dépôt compte **224** fichiers `*_test.dart` au total.

**Ce qui n'est gardé par rien** dans ce domaine : les trois listes (`subjects_page`,
`ai_routers_page`, `ValuationToolsGridView`), la visionneuse PDF et ses barres (3 348 lignes),
les dialogues d'actions (2 627 lignes dans le périmètre).

---

## 11. Synthèse pour la migration

**Trois leviers, par rapport « lignes supprimées / risque » décroissant :**

1. **Le corpus par codegen.** Un `@ZcrudModel` `ZValuationText { kind, identifier, title,
   description, content }` + un `ZCrudScreen` à 10 onglets ferait tomber **≈ 1 490 lignes**
   (D1→D6) et supprimerait 10 dépôts, 10 providers, 2 tables de dispatch. Risque faible : le
   comportement est déjà uniforme, et il est **testé** (`test/w7p/`, 984 l.). Le seul point dur est
   la fusion local-prioritaire (§8.2) et le tri par identifiant segmenté (§8.3) — deux règles à
   déclarer, pas à généraliser.

2. **La coquille de formulaire porté — la question est TRANCHÉE : c'est un canal IGNORÉ, pas un
   manque du socle.** Douze recopies de la même `State` + `Scaffold` + `AppBar` + bouton
   « Enregistrer » (**≈ 840 l.**), plus **52** blocs de drapeau (**≈ 950 l.**). Or la même app
   consomme déjà `presentFormEdition` sur **16 sites** et `ZFormOnly` dans **12 fichiers** — et
   **aucun des quatre jumeaux du périmètre ne les utilise** (mesuré §5.2). Le levier ne demande
   donc **aucun développement de socle** : c'est un alignement des quatre jumeaux sur le gabarit
   que l'hôte applique déjà ailleurs.

3. **La visionneuse de document.** `ZDocumentViewerChrome`, `ZAnnotationToolbar`,
   `ZAnnotationPanel` et `ZAnnotationToolController` sont exportés par `zcrud_document` v3.21.0 et
   sont **totalement inconnus de l'hôte** (grep négatif §7.2). Face à eux : **3 348 lignes** maison, **zéro test**. C'est le
   plus gros gisement, et le plus risqué — la QA d'un lecteur PDF annotable ne se fait pas au
   grep.

**Le préalable commun aux trois** : les entités du domaine étendent `DynamicModel`, et
`ZCrudSource` exige `ZEntity`. Le chemin est déjà tracé pour le document
(`ZBackedFolderDocumentRepository` → `ZStudyDocument`, 698 l., drapeau à `false`) ; il **n'existe
pas** pour la matière, faute d'entité `ZSubject` côté socle (grep négatif §7.1).

