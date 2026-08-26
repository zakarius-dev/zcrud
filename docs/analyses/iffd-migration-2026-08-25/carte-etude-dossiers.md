# Carte du domaine « Étude — dossiers, matières, documents » (IFFD)

> Relevé du **2026-08-25**, sur `/home/zakarius/DEV/iffd` à `e36c490`
> (« feat(zcrud): v3.20.0 + v3.21.0 adoptées »), arbre de travail **propre**
> (`git status --short` : aucune sortie).
> Dépôt lu en **lecture seule stricte** : aucun fichier d'IFFD n'a été créé,
> modifié ni supprimé.
> Toutes les affirmations d'**absence** portent leur grep négatif, montré en
> §9.

---

## 0. Périmètre réellement couvert

### 0.1 Ce qui était demandé

| Chemin déclaré | Fichiers `.dart` | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/folders/` | 35 | 17 613 |
| `lib/src/presentation/features/subjects/` | 9 | 2 904 |
| `lib/src/presentation/features/documents/` | 12 | 6 420 |
| `lib/src/features/subjects/` | 3 | 121 |
| `lib/src/features/documents/` | 1 | **0** (fichier vide) |
| `lib/src/features/corpus/` | 3 | 741 |
| **Total déclaré** | **63** | **27 799** |

### 0.2 Ce que j'ai inclus au-delà, en suivant les dépendances réelles

Le périmètre déclaré ne contient **ni modèle, ni dépôt, ni contrôle d'accès** :
`lib/src/features/*` n'est qu'une couche de **providers Riverpod** (barils
`*_module.dart` + `@riverpod`), et `lib/src/features/documents/documents_module.dart`
est **littéralement vide** (0 octet) — les providers du document vivent dans
`lib/src/features/home/providers/folder_providers.dart`.

| Ajouté (suivi de dépendance) | Fichiers | Lignes |
|---|---:|---:|
| Modèles de domaine (`folder_model`, `subject_model`, `folder_document`, `folder_document_annotation`, `folder_document_learning_info`, `folder_document_reading`, `folder_invitation`, `dynamic_model`) | 8 | 1 585 |
| Contrats de dépôt (`folders_repository`, `subject_repository`, `folder_document_*`, `folder_contents_orders_repository`, `folder_mindmap_repository`, `folder_invitaions_repository`, `datacrud_repository`) | 10 | 895 |
| Contrôle d'accès (`folder_resource_access_service`, `document_access_service`) | 2 | 602 |
| Implémentations de données (`firebase_crud_repository_impl`, `firebase_models_repositories_impls`, `z_backed_folder_repository`, `z_backed_folder_document_repository`) | 4 | 2 403 |
| Providers du dossier/document (`features/home/providers/folder_providers.dart`) | 1 | 123 |
| Briques partagées de présentation (`presentation/core/widgets/*`, `presentation/shared/controllers/*`) | 5 | 1 620 |
| **Socle zcrud app-side** (`presentation/shared/zcrud/*`) | 13 | 2 471 |
| **Total suivi** | **43** | **9 699** |

> **Périmètre réel de la migration : 106 fichiers, 37 498 lignes**, soit
> **21,6 %** des 173 587 lignes de `lib/` (536 fichiers `.dart`).

### 0.3 Ce que j'ai volontairement laissé dehors

`lib/data_crud/` — le **moteur déclaratif legacy** (32 fichiers, 16 889 lignes,
dont `edition_screen.dart` à **4 038** lignes et `dynamic_list_screen.dart` à
**1 753**). Il est l'ancêtre direct de zcrud, il est consommé par le périmètre
(`DynamicEditionScreen`), mais il n'appartient pas au domaine « Étude » : il est
**transverse à toute l'application**. Il est cité chaque fois qu'il explique un
chiffre.

---

## 1. Ce que le domaine SAIT FAIRE

Formulé en capacités visibles par un auditeur de l'IFFD, pas en classes.

### 1.1 Organiser

| # | Capacité | Où c'est rendu |
|---|---|---|
| C-01 | Créer un **dossier d'étude** portant un titre, une couleur, une matière de rattachement, une année académique, des filières/cycles et une date de début de cours | `folders/dialogs/folder_modal_dialogs.dart:41` (`showFolderEditonDialog`) |
| C-02 | Créer un **sous-dossier** (hiérarchie à **un seul niveau** : `isSubFolder` + `parentId`) | `folder_modal_dialogs.dart:150` (champ `isSubFolder`), `folder_model.dart:164` (`getFolderIds`) |
| C-03 | Créer une **matière** (module) avec coefficient, contexte global, instructions GPT, magasin vectoriel, filières/cycles, experts IA et expert par défaut | `subjects/dialogs/subject_model_dialogs.dart:28` |
| C-04 | **Rechercher** et **filtrer** les dossiers (matière, filière/cycle, auteur, groupement par matière) | `folder_modal_dialogs.dart:289` (`showFoldersFilterDialog`), `folders_page.dart:131` |
| C-05 | **Archiver** un dossier (`archivedAt`), le supprimer avec cascade sur ses contenus | `folders_repository.dart:135` (`deleteFolder`), `:346` (`deletedSubFolders`) |
| C-06 | **Réordonner** les contenus d'un dossier par glisser-déposer, ordre **personnel** (par utilisateur) | `folder_model.dart:334` (`FolderContentsOrders`, id `"${userId}_$folderId"`), `folder_study_tools_page.dart:1521/1881/2197` |

### 1.2 Partager

| # | Capacité | Où |
|---|---|---|
| C-07 | Rendre un dossier **public** ou privé | champ `isPublic`, `folder_modal_dialogs.dart:261` |
| C-08 | **Partager** avec des co-équipiers nommés (`sharedWith`), autoriser la **jonction par lien** (`canBeJoinedWithLink`), laisser les co-équipiers **inviter** d'autres personnes (`coWorkersCanInviteOthers`) | `folders/widgets/folder_coworkers_dialog_widget.dart` (449 l.), `folder_invitation.dart` |
| C-09 | Parcourir un **espace communautaire** de dossiers publics et l'ouvrir en lecture seule | `public_folders_page.dart:27`, `public_folders_details_page.dart:46` |

### 1.3 Alimenter en matériel pédagogique

| # | Capacité | Où |
|---|---|---|
| C-10 | **Importer un document** (PDF/Office/image) depuis le sélecteur de fichiers — chemin web (octets) **et** chemin natif (fichier) | `folder_details_page.dart:415-566`, `subject_details_page.dart:162-248` |
| C-11 | **Scanner** un document depuis l'appareil | `folder_content_add_dialog_widget.dart:270` (« Scanner un document ») |
| C-12 | **Convertir automatiquement en PDF** après téléversement, suivre l'état (`uploading` / `uploaded` / erreur) | `ai_repository.dart:88` (`convertDocumentToPdf`), `folder_document.dart:57` (`FolderDocumentStatus`) |
| C-13 | Ouvrir un **hub d'ajout de contenu** à six entrées : générer des flashcards avec l'IA, en créer manuellement, téléverser un fichier, scanner, créer une note, créer une carte mentale | `folder_content_add_dialog_widget.dart:153/202/242/270/303/338` |
| C-14 | Gérer les **balises** d'un dossier : créer, renommer, colorer, supprimer à l'unité ou par lot, voir le nombre de flashcards qui les emploient | `folders/dialogs/folder_tags_management_dialog.dart` (538 l.) |

### 1.4 Lire et annoter

| # | Capacité | Où |
|---|---|---|
| C-15 | **Lire un PDF** dans une visionneuse intégrée : table des matières, page-par-page / pages en continu / défilement vertical, plein écran | `folder_documents_actions_dialog_widget.dart:860` (`FolderDocumentViewer`), `:1197`, `:1366-1400` |
| C-16 | **Rechercher** dans le texte du document | `documents/widgets/document_viewer/search_toolbar.dart` (229 l.) |
| C-17 | **Annoter** : surligner, dessiner, choisir une couleur dans une palette | `document_viewer/annotation_toolbar.dart` (837 l.), `color_palette.dart` (483 l.) |
| C-18 | Reprendre la lecture à la page laissée | `folder_document_reading.dart` (105 l.) |

### 1.5 Générer avec l'IA

| # | Capacité | Où |
|---|---|---|
| C-19 | **Générer des flashcards** depuis un document — entier ou **sélection de pages** | `ai_repository.dart:380/394`, `folder_document_pages_selection_dialog.dart` (470 l.) |
| C-20 | **Générer une carte mentale** depuis un document (entier ou pages), depuis des notes | `ai_repository.dart:408/421/109` |
| C-21 | **Résumer** un document (entier ou pages) | `ai_repository.dart:215/233` |
| C-22 | **Expliquer une matière** puis décliner l'explication en 7 variantes : résumé, élaboration, exemples, poème, histoire, humour, salle de classe | `ai_repository.dart:153/253/264/275`, `folder_details_controller.dart:45-51` |
| C-23 | **Sujets connexes** d'un dossier, **balises** d'une matière | `ai_repository.dart:183/194/306` |
| C-24 | **Synthèse vocale** d'un texte généré | `ai_repository.dart:117` |
| C-25 | **Ignorer** un document pour l'assistant IA (exclusion du magasin vectoriel) | `ai_repository.dart:433`, `folder_documents_actions_dialog_widget.dart:483` |
| C-26 | **Converser** avec l'assistant du dossier ou de la matière (Notebook / Assistant) | `folder_explanation_page.dart:27`, `folders/zcrud/notebook_zcrud_mount.dart`, `assistant_chat_zcrud_mount.dart` |

### 1.6 Suivre sa progression

| # | Capacité | Où |
|---|---|---|
| C-27 | Voir la répartition **apprises / à réviser / à apprendre** en graphique radial | `folder_progress_page.dart:215-530` (`SfCircularChart` + `RadialBarSeries`) |
| C-28 | Grouper la progression **par examen**, configurer une date d'examen | `folder_progress_page.dart:173` (« Configurer un nouvel examen »), `:573` |
| C-29 | Voir, sur chaque carte de dossier, le **compte** de flashcards, notes, documents, cartes mentales et sous-dossiers | `folders_page.dart:925-979` |

### 1.7 Naviguer

| # | Capacité | Où |
|---|---|---|
| C-30 | Barre latérale de **sous-dossiers** sur grand écran, **sélecteur compact** sur petit écran, avec réordonnancement et création en place | `folder_details_page.dart:1760` (`_SubfolderSidebar`, 279 l.), `folders/zcrud/subfolder_nav_zcrud.dart` |
| C-31 | Disposition **redimensionnable** (poignée de séparation) entre la barre latérale et le contenu | `folder_details_page.dart:1571` (`_ResizableLayout`) |
| C-32 | Trois onglets par dossier : **Matériel pédagogique**, **Notebook**, **Progression** | `folder_details_page.dart:1168-1176` |
| C-33 | Choisir un dossier / un sous-dossier / une matière / un dossier public par **feuille de sélection**, avec création en place | 5 feuilles, cf. §5 D-11 |

### 1.8 Contrôler l'accès

| # | Capacité | Où |
|---|---|---|
| C-34 | Distinguer **propriétaire du dossier**, **créateur de la ressource**, **lecture seule** ; calculer par ressource : peut générer flashcards / carte mentale / résumé, peut modifier, supprimer, déplacer | `folder_resource_access_service.dart:196-264`, `document_access_service.dart:56-119` |
| C-35 | 17 opérations déclarées, dont **6 opérations IA** (`aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`, `aiExplain`, `aiChat`) | `domain/security/crud.dart:6-25` |
| C-36 | Permissions **par rôle** et **par année académique** (clé d'accès `"$modele$anneeAccademique"`) | `folder_details_page.dart:189` (`cleAcces`), `domain/security/app_user_permissions.dart` |

---

## 2. Les écrans

### 2.1 Écrans routés (`@RoutePage`) — 11

| Écran | Chemin:ligne | Lignes de classe | `build()` le plus gros | Formulaire | Liste | Navigation | Rendu riche |
|---|---|---:|---:|:-:|:-:|:-:|:-:|
| `FoldersPage` — liste des dossiers d'étude, recherche, filtres, groupement par matière | `folders/pages/folders_page.dart:115` | 648 | **630** | — | ✅ grille de cartes | ✅ vers le détail | — |
| `CommunityFoldersPage` — même écran, drapeau `isCommunity` | `folders_page.dart:1450` | 5 | — | — | ✅ | ✅ | — |
| `PublicFoldersPage` — espace partagé | `folders/pages/public_folders_page.dart:27` | 198 | 181 | — | ✅ | ✅ | — |
| `PublicFoldersDetailsPage` — détail d'un dossier public, 3 onglets, lecture seule | `folders/pages/public_folders_details_page.dart:46` | 665 | **275** | — | ✅ | ✅ onglets | ✅ Notebook |
| `FolderDetailsPage` — **l'écran central** : en-tête, barre latérale de sous-dossiers, 3 onglets, import de documents | `folders/pages/folder_details_page.dart:68` | **1 503** | **1 476** | ✅ (import) | ✅ | ✅ onglets + latéral | ✅ Notebook |
| `FolderExplanationPage` — Notebook / conversation IA du dossier | `folders/pages/folder_explanation_page.dart:27` | 249 | 212 | — | ✅ fil | — | ✅ markdown |
| `SubjectExplanationPage` — idem, matière | `folder_explanation_page.dart:276` | 16 | — | — | ✅ | — | ✅ |
| `FolderChatbotPage` — idem, mode chat | `folder_explanation_page.dart:292` | 18 | — | — | ✅ | — | ✅ |
| `SubjectChatbotPage` — idem, chat matière | `folder_explanation_page.dart:311` | 15 | — | — | ✅ | — | ✅ |
| `SubjectsPage` — liste des matières | `subjects/pages/subjects_page.dart:45` | 468 | 450 | — | ✅ grille | ✅ | — |
| `SubjectDetailsPage` — détail d'une matière, 2 onglets | `subjects/pages/subject_details_page.dart:50` | 458 | **437** | ✅ (import) | ✅ | ✅ onglets | ✅ |

### 2.2 Écrans montés en onglet ou en page interne — 5

| Écran | Chemin:ligne | Lignes | `build()` | Rôle |
|---|---|---:|---:|---|
| `FolderStudyToolsPage` | `folders/pages/folder_study_tools_page.dart:61` | **2 191** | **1 393** | Onglet « Matériel pédagogique » : 4 sections (rail flashcards, grilles documents / notes / cartes mentales), repliables et réordonnables |
| `SubjectStudyToolsPage` | `folder_study_tools_page.dart:2252` | 15 | — | Même écran, drapeau `subjectToolPage` |
| `FolderProgressPage` | `folders/pages/folder_progress_page.dart:35` | 563 | **452** | Onglet « Progression » : graphique radial + regroupement par examen |
| `SubjectCustomAssistantPage` | `subjects/pages/subject_custom_assistant_page.dart:5` | 51 | 44 | Écran d'accueil « Créer un assistant personnalisé » |
| `FolderDocumentViewer` (+ son `State`) | `documents/widgets/folder_documents_actions_dialog_widget.dart:860` / `:883` | 946 | 578 | Visionneuse PDF : sommaire, recherche, annotations, plein écran |

### 2.3 Écrans modaux (dialogues plein écran / feuilles) — 13

| Écran modal | Chemin:ligne | Lignes | Formulaire | Liste | Rendu riche |
|---|---|---:|:-:|:-:|:-:|
| `showFolderEditonDialog` — édition de dossier (**deux moteurs**, legacy + zcrud) | `folders/dialogs/folder_modal_dialogs.dart:41` | 247 | ✅ 10 champs legacy / 6 `ZFieldSpec` | — | ✅ |
| `FolderZcrudEditionScreen` — jumeau zcrud du précédent | `folders/dialogs/folder_zcrud_edition.dart:374` | 182 | ✅ | — | ✅ |
| `showFoldersFilterDialog` — filtres de la liste | `folder_modal_dialogs.dart:289` | 145 | ✅ 4 champs | — | — |
| `showSubjectEditonDialog` / `SubjectEditionScreen` | `subjects/dialogs/subject_model_dialogs.dart:28` | 262 | ✅ 8 champs legacy | — | ✅ instructions GPT |
| `SubjectZcrudEditionScreen` — jumeau zcrud | `subjects/dialogs/subject_zcrud_edition.dart` | 728 | ✅ 6 `ZFieldSpec` | — | ✅ |
| `showFolderDocumentEditonDialog` — renommage de document | `documents/dialogs/documents_dialogs.dart:37` | 60 | ✅ 1 champ | — | — |
| `FolderDocumentZcrudEditionScreen` — jumeau zcrud | `documents/dialogs/folder_document_zcrud_edition.dart` | 212 | ✅ 1 `ZFieldSpec` | — | — |
| `FolderDocumentsActionsDialogWidget` — 8 actions sur un document | `documents/widgets/folder_documents_actions_dialog_widget.dart:43` | 817 | — | ✅ tuiles d'action | — |
| `FolderTagsManagementDialog` — gestion des balises | `folders/dialogs/folder_tags_management_dialog.dart` | 538 | ✅ inline | ✅ | — |
| `FolderContentAddDialogWidget` (+ son `State`, `build()` de 262 l.) — hub d'ajout | `folders/dialogs/folder_content_add_dialog_widget.dart:27` / `:73` | 550 | — | ✅ 6 cartes | — |
| `FolderCoworkersDialogWidget` — co-équipiers et invitations | `folders/widgets/folder_coworkers_dialog_widget.dart` | 449 | ✅ inline | ✅ | — |
| `ChatbotDocumentSelectorDialogWidget` — choix de documents pour l'assistant | `documents/widgets/chatbot_document_selector_dialog_widget.dart:25` | 842 | — | ✅ | — |
| `FolderDocumentPagesSelectionDialog` — sélection de pages | `documents/widgets/folder_document_pages_selection_dialog.dart` | 470 | — | ✅ vignettes | — |

**Chiffre saillant** : `FolderDetailsPage.build()` fait **1 476 lignes**
(`folder_details_page.dart:92-1567`) et `FolderStudyToolsPage.build()` **1 393**
(`:857-2249`). Deux méthodes de plus de mille lignes, chacune reconstruisant
tout son arbre à chaque notification — c'est l'inverse exact de l'objectif
produit n° 1 de zcrud.

---

## 3. Modèles de domaine et persistance

### 3.1 Entités

Toutes descendent d'une base maison **`DynamicModel`**
(`domain/models/dynamic_model.dart`, 79 l.) : `id` nullable, `toMap()`
abstrait, `toJson()`, `copyWith()`, `props` et une **égalité structurelle
profonde** écrite à la main (`_deepEquals`, 25 l.).

| Entité | Chemin:ligne | Lignes | Champs | Collection Firestore |
|---|---|---:|---:|---|
| `FolderModel` | `domain/models/folder_model.dart:13` | 258 | 19 | `FolderModel` |
| `FolderContentModel` (base des contenus) | `folder_model.dart:253` | 80 | 6 | — (abstraite) |
| `FolderContentsOrders` (ordre personnel) | `folder_model.dart:334` | 156 | 7 | `FolderContentsOrders` |
| `SubjectModel` | `domain/models/subject_model.dart:17` | 153 | 10 | `SubjectModel` |
| `SubjectContentModel` | `subject_model.dart:170` | 66 | 4 | — |
| `FolderDocument` | `domain/models/folder_document.dart:71` | 176 | 9 (+6 hérités) | `FolderDocument` |
| `FolderDocumentAnnotation` | `folder_document_annotation.dart` | 259 | — | `FolderDocumentAnnotation` |
| `FolderDocumentReading` | `folder_document_reading.dart` | 105 | — | `FolderDocumentReading` |
| `FolderDocumentLearningInfo` | `folder_document_learning_info.dart` | 82 | — | `FolderDocumentLearningInfo` |
| `FolderInvitation` | `folder_invitation.dart` | 129 | — | `FolderInvitation` |

### 3.2 Sérialisation

**Écrite à la main, intégralement.** Aucune annotation zcrud n'est posée sur un
modèle d'IFFD (grep négatif §9.1).

- `toMap()` / `fromMap()` / `toJson()` / `fromJson()` / `copyWith()` / `props`
  sont recopiés champ à champ dans chaque modèle.
- Un **registre de fabriques tenu à la main** dispatche `fromMap<T>` :
  `utils/functions/data_functions.dart:336-390`, **une `Map<Type, Function()>`
  de 25+ entrées** (`FolderModel: () => FolderModel.fromMap(map)`, …). Ajouter
  une entité impose d'éditer ce fichier : c'est exactement ce que le
  `ZcrudRegistry` généré remplace.
- Les dates franchissent **trois formes** en lecture (`Timestamp`, `int` millis,
  `DateTime`), chacune re-décodée à la main, **quatre fois** dans le seul
  `FolderModel.fromMap` (`folder_model.dart:164-190`).
- 🔴 **`FolderModel.toJson()` a dû être réparé** parce que `toMap()` émet des
  `Timestamp` que `json.encode` ne sait pas encoder
  (`folder_model.dart:196-216`, commentaire « B-8 ») : `toMap()` et `toJson()`
  produisent donc **deux formats différents** pour la même entité.
- 🔴 Un champ **fantôme** est documenté : `SubjectModel.aiExperts` /
  `defaultAiExpert` étaient **proposés par le formulaire et jetés par le
  modèle** jusqu'au 2026-07-23 (`subject_model.dart:26-46`).
- Fautes d'orthographe **figées dans le schéma persisté** :
  `accademicYear`, `folderExplaination`, `coeficient` — signalées comme
  « orthographe legacy PRÉSERVÉE » dans `z_backed_folder_repository.dart:57-61`.

### 3.3 Dépôts et source de données

**Un seul backend : Cloud Firestore.** Pas de cache local de domaine, pas de
synchronisation offline (grep négatif §9.4 — le seul `CacheManager` du dépôt,
`src/iffd_cache_manager.dart`, est un cache **d'images réseau**).

- Contrat unique `CrudRepository<T>` (`domain/repositories/datacrud_repository.dart:20`,
  22 méthodes) : `create`, `mapCreate`, `streamAll`, `streamOne`, `streamByIds`,
  `all`, `count`, `asyncCount`, `find`, `batchSet`, `batchUpdate`, `batchDelete`,
  `update`, `mapUpdate`, `softDelete`, `delete`, `restore`.
- Une seule implémentation générique `FirebaseCrudRepositoryImpl<T>`
  (`data/repositories/firebase_crud_repository_impl.dart:18`, 499 l.) et
  **36 sous-classes d'une ligne** (`firebase_models_repositories_impls.dart:61-433`).
- 🔴 **Le nom de collection est le nom du type Dart.**
  `FIREBASE_COLLECTION_NAMES` est une **map vide**
  (`utils/constants/databases.dart:3`), donc
  `getFirebaseCollectionName<T>()` retombe sur `T.toString()`
  (`utils/functions/databases_functions.dart:9`). Les collections Firestore
  s'appellent littéralement `FolderModel`, `SubjectModel`, `FolderDocument`.
  Renommer une classe Dart **casse la base**.
- **Soft-delete** par un booléen `deleted` posé dans la map
  (`firebase_crud_repository_impl.dart:350` / `:377`), sans entité de
  métadonnées séparée.
- Pagination : `DataRequest<T>` (`domain/models/requests/data_request.dart:5`)
  — `where` / `whereIn` / `or` / `itemFilter` / tri, **par offset**, pas par
  curseur.
- `streamByIds` découpe en **paquets de 30** et recombine les flux à la main
  (`firebase_crud_repository_impl.dart:76-104`).

### 3.4 Traitement des erreurs

Pas de `Either<ZFailure, T>` sur ce chemin : une **hiérarchie maison** de
« data states ».

- `DataState<T, E>` avec `data` et `error` nullables
  (`utils/resources/data_state.dart:1`) et 8 sous-classes
  (`DataSuccess`, `DataFailed`, `DataNotSet`, `DataCreated`, `DataUpdated`,
  `DataDeleted`, `DataRestored`, `DataValidated`).
- `FirestoreDataState<T> extends DataState<T, FirebaseException>`
  (`utils/resources/firestore_data_state.dart:5`) et 7 sous-classes de plus.
- 🔴 **Toute erreur est ré-emballée en `FirebaseException`**, y compris celles
  qui n'en sont pas : `firebase_crud_repository_impl.dart:211`, `:270`, `:286`,
  `:311`, `:325`, `:341`, `:368` font `catch (e) { return FirestoreDataFailed(FirebaseException(...)) }`.
- 🔴 **Un chemin critique sans gestionnaire d'erreur du tout** : le comptage.
  `count()` monte `query.count().get()` dans un `StreamController` **nu** ;
  l'échec de l'agrégation (filtre `or`, règle de sécurité, index manquant) ne
  remonte jamais, et la carte reste en squelette. Le défaut est décrit **par le
  code lui-même** dans `folders_repository.dart:96-110` (encadré « B-28 »).
- 🔴 `getAll` / `getOne` **avalent l'échec** : sur un `DataFailed`, ils rendent
  `[]` et `null` — indiscernable d'un résultat vide
  (`datacrud_repository.dart:68-82`).

### 3.5 Le chemin de données zcrud, déjà écrit et **éteint**

Deux adaptateurs « strangler fig » existent pour ce périmètre :

| Adaptateur | Chemin | Lignes | Entité zcrud cible |
|---|---|---:|---|
| `ZBackedFolderRepository` | `data/repositories/z_backed_folder_repository.dart` | 772 | `ZStudyFolder` (`zcrud_study_kernel`) |
| `ZBackedFolderDocumentRepository` | `data/repositories/z_backed_folder_document_repository.dart` | 698 | `ZStudyDocument` (`zcrud_document`) |

Ils sont **complets** (port neutre `ZFolderDataPath`, implémentation Firestore
en schéma canonique + `ZSyncMeta`, mappeur bidirectionnel documenté champ par
champ) et **jamais atteints** : leurs drapeaux valent `false` en dur —
`useZcrudFoldersRepository` (`features/home/providers/folder_providers.dart:40`),
`useZcrudFolderDocumentRepository` (`:56`).

Le mappeur documente **six écarts structurels** résolus par `extra` préfixé
`iffd_` (`z_backed_folder_repository.dart:29-80`) : `color` (type Flutter
interdit en modèle zcrud), `sharedAt` (sans homologue), `updatedAt` (clé
réservée `ZSyncMeta` réécrite par le store), `accademicYear`,
`filieresEtCycles`, `subjectId`, `isSubFolder`, `relatedTopics`,
`folderExplaination`, et la non-nullabilité de `title`/`ownerId`.

---

## 4. Ce qui est DÉJÀ branché sur zcrud

### 4.1 Dépendances déclarées

`pubspec.yaml` déclare **23 paquets `zcrud_*` en `dependencies`** (épinglés sur
`ref: v3.21.0`) et **25 en `dependency_overrides`** :

`zcrud_core`, `zcrud_firestore`, `zcrud_riverpod`, `zcrud_select`,
`zcrud_flashcard`, `zcrud_menu`, `zcrud_mindmap`, `zcrud_markdown`,
`zcrud_intl`, `zcrud_document`, `zcrud_note`, `zcrud_study`, `zcrud_exam`,
`zcrud_session`, `zcrud_study_kernel`, `zcrud_ui_kit`, `zcrud_chat_kernel`,
`zcrud_chat_syncfusion`, `zcrud_chat`, `zcrud_chat_markdown`,
`zcrud_chat_material`, `zcrud_navigation`, `zcrud_screen`.

Imports effectifs dans tout `lib/` — **173 lignes `import`** :
`zcrud_core` 61 · `zcrud_chat_kernel` 19 · `zcrud_study` 16 · `zcrud_chat` 15 ·
`zcrud_screen` 10 · `zcrud_flashcard` 9 · `zcrud_study_kernel` 6 ·
`zcrud_firestore` 5 · `zcrud_navigation` 4 · `zcrud_mindmap` 4 ·
`zcrud_ui_kit` 3 · `zcrud_session` 3 · `zcrud_markdown` 3 ·
`zcrud_chat_syncfusion` 3 · `zcrud_chat_material` 3 · `zcrud_intl` 2 ·
`zcrud_chat_markdown` 2 · `zcrud_select` 1 · `zcrud_note` 1 · `zcrud_menu` 1 ·
`zcrud_exam` 1 · `zcrud_document` 1.

### 4.2 Ce que le périmètre consomme précisément

| Fichier hôte | Paquet | Symboles |
|---|---|---|
| `folders/zcrud/content_hub_zcrud.dart` (458 l.) | `zcrud_study` | `ZContentHubEntry`, `ZContentHubSection`, `ZContentHubSheet` |
| `folders/zcrud/folder_tags_zcrud.dart` (209 l.) | `zcrud_study`, `zcrud_study_kernel` | `ZTagEditor`, `ZColorPalette`, `ZFlashcardTag` |
| `folders/zcrud/folder_actions_menu_zcrud.dart` (241 l.) | `zcrud_menu`, `zcrud_study` | `ZMenuEntryTile`, `ZItemAction`, `ZItemActionKind`, `ZItemActionsMenu` |
| `folders/zcrud/folder_card_zcrud.dart` (618 l.) | `zcrud_core`, `zcrud_study` | `ZFolderCard`, `ZFolderCardFooterPlacement`, `ZcrudTheme` |
| `folders/zcrud/folder_card_default_zcrud.dart` (263 l.) | `zcrud_core`, `zcrud_study`, `zcrud_study_kernel` | `ZDefaultFolderCard`, `ZFolderCardCount`, `ZColorPair`, `ZColorPalette`, `ZcrudScope` |
| `folders/zcrud/folder_detail_zcrud.dart` (545 l.) | `zcrud_core`, `zcrud_ui_kit`, `zcrud_study` | `ZStudySection*` (4), `ZSubfolderTrigger*` (3), `ZGradientSpec`, `ZcrudScope`, `ZcrudTheme`, `ZAppBarAction`, `ZAppBarSearchConfig` |
| `folders/zcrud/subfolder_nav_zcrud.dart` (671 l.) | `zcrud_study` | `ZSubfolderSidebar`, `ZSubfolderCompactSelector`, `ZSubfolderNavSpec`, `ZSubfolderRef`, `ZSubfolderAddPlacement`, `ZSubfolderLayoutMode` |
| `folders/zcrud/study_tools_zcrud_adapter.dart` (962 l.) | `zcrud_study` (import complet), `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel` | `ZStudyToolsSectionSpec`, `ZStudyToolsItemCard`, `ZFlashcard`, `ZFlashcardTag`, `ZColorPair`, `ZcrudTheme` |
| `folders/zcrud/study_tools_zcrud_view.dart` (39 l.) | `zcrud_study` | `ZStudyToolsPage` |
| `folders/zcrud/notebook_zcrud_mount.dart` (172 l.) | `zcrud_chat` | `ZChatModelOption` |
| `folders/zcrud/assistant_chat_zcrud_mount.dart` (230 l.) | `zcrud_chat`, `zcrud_chat_material`, `zcrud_chat_markdown`, `zcrud_chat_syncfusion`, `zcrud_core` | `ZChatConversationScreen`, `ZChatController`, `ZChatSettingsController`, `ZChatRendererScope`, `ZChatMaterialComposer`, `ZChatMarkdownRenderer`, `ZIffdTextStreamPort` |
| `folders/dialogs/folder_zcrud_edition.dart` (556 l.) | `zcrud_core` | `ZFormController`, `ZFieldSpec`, `DynamicEdition`, `ZEditionSubmitController`, `ZRelationSourceRegistry`, `ZFailure` |
| `subjects/dialogs/subject_zcrud_edition.dart` (728 l.) | `zcrud_core` | idem |
| `documents/dialogs/folder_document_zcrud_edition.dart` (212 l.) | `zcrud_core` | idem |
| `folders/pages/folder_details_page.dart` (legacy !) | `zcrud_ui_kit` | `ZAppBarSearchConfig`, `ZAppBarAction` |
| `folders/pages/folder_study_tools_page.dart` (legacy !) | `zcrud_study`, `zcrud_study_kernel` | `ZStudyToolsSectionSpec`, `ZFlashcardTag` |

**Total du portage zcrud dans le périmètre : 5 948 lignes** — c'est la somme
des fichiers dont le nom porte `zcrud` : les 12 fichiers `*zcrud*` de
`folders/zcrud/` (4 452 l. ; le répertoire entier fait 4 759 l., le solde étant
`notebook_artifact_actions_iffd.dart`, 307 l.) plus les 3 écrans d'édition
(556 + 728 + 212 = 1 496 l.). Sur tout `lib/`, 44 fichiers `*zcrud*` totalisent
**14 824 lignes**.

### 4.3 Ce qui est enregistré au registre de widgets

`presentation/shared/zcrud/z_iffd_field_registry.dart:79` — **un registre par
montage**, jamais un singleton (le socle lève sur collision) :

| Enregistrement | Ligne | Ce que ça sert |
|---|---:|---|
| `registerZMarkdownFields(registry, codec: IffdRichTextCodec(), styleSet: …, chrome: …)` | `:102` | Champs à éditeur riche, **persistance en Markdown** (décision B-24). Le codec est décrit comme « le seul endroit où se joue la non-destruction des données » — sans lui, ~11 400 valeurs markdown seraient décodées vides puis écrasées (`:19-23`). |
| `registerZFlashcardEditors(registry, trueLabel:'Vrai', falseLabel:'Faux', addChoiceLabel:…)` | `:177` | Sélecteur de type, éditeur QCM, vrai/faux, avec `ZFlashcardEditionValidator` (règle « ≥ 2 choix, ≥ 1 correct » que le legacy IFFD ne valide nulle part). |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `:188` | `zcrud_intl` — répare un champ que le legacy déclarait sans jamais le rendre. |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | `:199` | `FlutterSwitch` en `switchTile` sur **tous** les booléens de l'application, sans qu'aucune `ZFieldSpec` ne le déclare. |
| `extraWidgets` (registre **local enfant**, par formulaire) | `:236-259` | Matrice d'autorisations (`z_iffd_acl_matrix_field.dart`, 262 l.) : elle dépend de deux flux, donc ne peut pas être globale. |

`IffdZcrudScope` (`z_iffd_field_registry.dart:220`) est monté **17 fois** dans
`lib/` (dont `main.dart:1` et 3 sites du périmètre) et porte aussi les sources
de relation, l'ACL, les coutures de sous-liste, le thème de formulaire, le
présentateur de sélection et le défaut de casse legacy.

Sources de relation : un adaptateur **unique et partagé**
`IffdRelationSource<T>` (`z_iffd_relation_source.dart:46`) reproduit le pipeline
`crudDataSelect` legacy en 7 étapes ; chaque formulaire n'apporte que sa requête
et son libellé (`folder_zcrud_edition.dart:165` et `:190`).

### 4.4 🔴 Le portage est écrit, mesuré, testé — et **éteint à 90 % sur ce périmètre**

`lib/` porte **38 constantes `const bool k…Default`**, dont **une seule vaut
`true`** (`kAiRouterEditionUseZcrudDefault`,
`ai_routers/zcrud/ai_router_zcrud_edition.dart:91`) — plus 6 drapeaux de dépôt,
tous à `false`.

Le registre de QA (`shared/zcrud/z_qa_flags.dart`, 467 l.) recense **34
bascules**. `main.dart:201-210` en active **8** :
`notebook`, `aiRouterEdition`, `exam`, `valuationTool`, `subject`,
`flashcardEdition`, `anneeAccademique`, `aiExpert`.

Croisement avec le périmètre « Étude » :

| Bascule du périmètre | Fichier porté | Lignes portées | Active en `main.dart` ? |
|---|---|---:|:-:|
| `subject` | `subjects/dialogs/subject_zcrud_edition.dart` | 728 | ✅ **oui** |
| `folderCard` | `folders/zcrud/folder_card_zcrud.dart` | 618 | ❌ |
| `folderCardDefault` | `folders/zcrud/folder_card_default_zcrud.dart` | 263 | ❌ |
| `folderDetail` | `folders/zcrud/folder_detail_zcrud.dart` | 545 | ❌ |
| `subfolderNav` | `folders/zcrud/subfolder_nav_zcrud.dart` | 671 | ❌ |
| `studyTools` | `study_tools_zcrud_adapter.dart` + `_view` + `_flag` | 1 045 | ❌ |
| `folderEdition` | `folders/dialogs/folder_zcrud_edition.dart` | 556 | ❌ |
| `folderTags` | `folders/zcrud/folder_tags_zcrud.dart` | 209 | ❌ |
| `contentHub` | `folders/zcrud/content_hub_zcrud.dart` | 458 | ❌ |
| `folderDocument` | `documents/dialogs/folder_document_zcrud_edition.dart` | 212 | ❌ |
| — (dépôt) | `z_backed_folder_repository.dart` | 772 | ❌ |
| — (dépôt) | `z_backed_folder_document_repository.dart` | 698 | ❌ |

> **6 047 lignes de portage zcrud dormantes** dans ce seul périmètre —
> 4 577 de présentation + 1 470 de chemin de données — contre **728 lignes
> actives** (`subject`). Ce n'est pas de la dette morte : c'est le legacy et son
> jumeau qui **coexistent tous deux dans l'arbre**, et qui doivent tous deux
> être maintenus tant que la bascule n'est pas faite. C'est la première source
> de duplication du domaine (§5).

---

## 5. Le CODE RÉPÉTÉ

Méthode : normalisation des blancs, retrait des commentaires, comparaison
`difflib.SequenceMatcher` deux à deux ; les « lignes identiques » sont des
lignes de code réellement égales après normalisation, pas une estimation.

### Tableau de synthèse

| # | Bloc répété | Sites | Lignes en cause | Preuve la plus forte |
|---|---|---:|---:|---|
| D-1 | **Déclaration DOUBLE des champs** d'une même entité : `DynamicFormField` legacy **et** `ZFieldSpec` zcrud | 2 moteurs | 217 + 107 déclarations | folder : 10 legacy / 6 zcrud ; matière : 8 / 6 ; document : 1 / 1 |
| D-2 | **Ossature d'écran d'édition zcrud** montée à la main (`IffdZcrudScope > Scaffold > AppBar(Save) > DynamicEdition`) | **10** | **338** | `smartnote_zcrud_edition.dart` ↔ `valuation_tool_model_zcrud_edition.dart` : **29 lignes identiques sur 29 (100 %)** |
| D-3 | **Amorçage d'un formulaire zcrud** en `initState` (`ZFormController` + `ZEditionSubmitController` + `ZRelationSourceRegistry` + `dispose`) | **12** | **344** | `folder_zcrud_edition.dart:444-491` ↔ `subject_zcrud_edition.dart:649-679` : 20 lignes identiques |
| D-4 | **Post-traitement de dialogue d'édition** (`if (result != null)` → `randomString()` id → `fromMap<T>` → `switch (crud)` create/update) | **12** | **264** | 12 fichiers, bloc de 20 à 29 lignes chacun |
| D-5 | **Pyramide de `StreamBuilder<DataCount>` + dérivation count/loading/empty** | 10 `StreamBuilder`, 3 blocs | **131** | `folders_page.dart:925-979` ↔ `subjects_page.dart:558-620` : 14 lignes identiques d'un coup |
| D-6 | **Flux d'import de document écrit dans `build()`** (créer → téléverser → mettre à jour l'état → convertir en PDF) | **5** | **≈ 170** | `folder_details_page.dart:423 / :470 / :535` ; `subject_details_page.dart:170 / :215` — 20 + 16 + 14 lignes identiques entre les deux fichiers |
| D-7 | **Palette de 5 dégradés codée en dur** (`Color(0xFF667eea)`…) | **6 fichiers** (38 sites du seul littéral, 8 fichiers) | ≈ 120 | `folders_page.dart:55-74`, `subjects_page.dart:48-58`, `accademic_years_page.dart:29`, `user_role_page.dart:32`, `auditeurs_pages.dart:45`, `ai_routers_page.dart:25` |
| D-8 | **Service de permissions dupliqué** | 2 | **133 identiques / 155** | `document_access_service.dart` (238 l.) est un clone spécialisé de `folder_resource_access_service.dart` (364 l.), **60,3 % identique** |
| D-9 | **Contrôleur de détail** (drapeaux « en cours » par item et par opération) | 2 | **149 identiques / 159** | `folder_details_controller.dart` (487 l.) ↔ `subject_details_controller.dart` (186 l.), **52,5 %** ; blocs contigus de **67** et **33** lignes |
| D-10 | **Sections de contenu** de la page « outils d'étude » (`ExpandableNotifier` + `ExpandablePanel` + `ReorderableGridView` + état vide) | 4 (3 mesurables) | **1 092** | `folder_study_tools_page.dart:1160-1570` ↔ `:1571-1930` : **194 lignes identiques (50,3 %)** ; `:1571` ↔ `:1931` : **189 (55,5 %)** |
| D-11 | **Feuille de sélection d'entité** (flux + bouton « créer » + tuile + retour de l'id) | **5** | **898** | `folder_selection_dialog_widget.dart` (155) ↔ `subject_selection_dialog_widget.dart` (83) : **49 lignes identiques, 46,7 %** ; + `folder_subfolder_…` (228), `public_folder_…` (239), `folder_tags_…` (193) |
| D-12 | **Feuille d'actions par entité** — 12 sous-classes de `StatelessItemDialogWidget<T>` (base de 48 l. dont le `build` est un `Placeholder()`) | **12** | **4 394** | `folder_actions_dialog_widget.dart` (186), `subject_actions_dialog_widget.dart` (66), `folder_documents_actions_dialog_widget.dart` (1 804), + 9 hors périmètre |
| D-13 | **Tuile d'action** `ListTile(leading: Icon(…), title: Text(…), enabled:, onTap:)` | **65 sites / 20 fichiers** | ≈ 780 | 8 dans `folder_documents_actions_dialog_widget.dart`, 11 dans `data_crud/dynamic_list_screen.dart`, 6 dans `forms_utils.dart` |
| D-14 | **Sous-classes vides** de `DynamicListSearchController`, créées uniquement pour servir de tag GetX | **16** | 37 | `shared/controllers/dynamic_list_search_controller.dart:35-71` |
| D-15 | **Registre de fabriques `fromMap<T>` tenu à la main** | 1 site, 25+ entrées | ≈ 45 | `utils/functions/data_functions.dart:336-390` |
| D-16 | **Méthodes de comptage jumelles** `countFolderX` / `countSubjectX` | **11 méthodes** | — | `flashcard_repository.dart:36/53`, `smart_note_repository.dart:25/42`, `folder_document_repository.dart:26/43`, `folder_mindmap_repository.dart:26/43`, `flashcard_tags_repository.dart:27/45`, `folders_repository.dart:325` |
| D-17 | **Sous-classes de page à un seul drapeau** | 6 | 88 | `CommunityFoldersPage` (5 l.), `SubjectStudyToolsPage` (15 l.), `SubjectExplanationPage` (15), `FolderChatbotPage` (18), `SubjectChatbotPage` (15), `PublicFoldersDetailsSearchController` (2) |
| D-18 | **Ré-emballage d'erreur en `FirebaseException`** | 7 | ≈ 42 | `firebase_crud_repository_impl.dart:211, 270, 286, 311, 325, 341, 368` |

### 5.1 Le détail qui décide : D-2, l'assemblage manquant le plus criant

Dix écrans d'édition zcrud montent **à la main** exactement le même arbre :

```
IffdZcrudScope(relationSources: _relations,
  child: Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [
      if (!widget.readOnly) Semantics(button: true, label: 'Enregistrer',
        child: IconButton(tooltip:'Enregistrer', iconSize: 24,
          constraints: BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(Icons.save_outlined), onPressed: _onSave))]),
    body: DynamicEdition(controller: _controller, fields: _fields)))
```

| Site | Lignes |
|---|---|
| `flashcards/zcrud/flashcard_edition_zcrud.dart:490-549` | 60 |
| `folders/dialogs/folder_zcrud_edition.dart:518-555` | 38 |
| `administration/dialogs/exam_zcrud_edition.dart:479-512` | 34 |
| `mindmap/dialogs/mindmap_zcrud_edition.dart:275-307` | 33 |
| `smartnotes/dialogs/smartnote_zcrud_edition.dart:311-341` | 31 |
| `valuation_tools/dialogs/valuation_tool_model_zcrud_edition.dart:317-347` | 31 |
| `documents/dialogs/folder_document_zcrud_edition.dart:183-211` | 29 |
| `flashcards/controllers/ai_base_url_zcrud_edition.dart:255-283` | 29 |
| `flashcards/dialogs/flashcard_tag_zcrud_edition.dart:212-240` | 29 |
| `flashcards/widgets/test_exam_filter_zcrud_screen.dart:352-375` | 24 |

🔴 **Et zcrud fournit déjà l'assemblage** : `presentFormEdition`
(`package:zcrud_screen`). Il est utilisé dans **5 fichiers, tous sous
`administration/`** — `auditeur_account_zcrud_edition.dart:149`,
`auditeur_iffd_zcrud_edition.dart`, `app_user_role_zcrud_edition.dart`,
`ai_expert_zcrud_edition.dart`, `annee_accademique_zcrud_edition.dart` —
et **dans aucun fichier du périmètre Étude**. `auditeur_account_zcrud_edition.dart:130`
porte le commentaire « ⚠️ CE QUE `presentFormEdition` APPORTE ET QUE NOTRE
PATRON MAISON N'AVAIT PAS » : la démonstration est faite dans le dépôt, elle
n'a simplement pas été propagée. Avec D-3, ce sont **682 lignes** que
l'assemblage du socle absorbe.

### 5.2 Le détail qui coûte le plus : D-10, les sections d'outils d'étude

`folder_study_tools_page.dart` déclare **quatre** sections de contenu
(« Flashcards » rail horizontal, « Documents », « Notes », « Cartes mentales »)
dont trois sont bâties sur le même gabarit `ExpandableNotifier` +
`ExpandablePanel` + `ReorderableGridView.count` + `EmtyFolderContent` :

| Section | Lignes | Similarité avec la suivante |
|---|---|---|
| A — Flashcards + Documents, `:1160-1570` | 411 | vs B : **194 lignes identiques (50,3 %)** |
| B — Notes, `:1571-1930` | 360 | vs C : **189 lignes identiques (55,5 %)** |
| C — Cartes mentales, `:1931-2251` | 321 | vs A : 162 lignes identiques (44,3 %) |

Et `study_tools_zcrud_adapter.dart:1-95` **nomme lui-même** la correspondance
section par section vers `ZStudyToolsSectionSpec` : la traduction est écrite,
mesurée, et son drapeau `studyToolsZcrudPageEnabled` vaut `false`.

### 5.3 Ce que le socle nomme déjà comme remplaçable

`content_hub_zcrud.dart:2-12` cite mot pour mot la dartdoc de `ZContentHubSheet` :

> « Remplace les monolithes IFFD `folder_content_creating_buttons.dart` (241 l.) /
> `folder_content_add_dialog_widget.dart` (550 l.) par une projection
> présentation paramétrée par une `List<ZContentHubEntry>` »

Le fichier hôte qualifie cela de « **vingtième occurrence du motif “offert, non
passé”** ». Le portage fait 458 lignes ; les 791 lignes legacy sont toujours là,
et c'est encore elles qui s'exécutent.

---

## 6. Les widgets maison qui refont ce que zcrud fait

| Widget maison | Chemin:ligne | Lignes | Équivalent zcrud | État |
|---|---|---:|---|---|
| `FolderItemWidget` + `_FolderItemWidgetState` | `folders_page.dart:763` / `:809` | **687** | `ZFolderCard` / `ZDefaultFolderCard` | Porté (618 + 263 l.), **éteint** |
| `SubjectItemWidget` + état | `subjects_page.dart:513` / `:541` | **430** | `ZFolderCard` (même famille de carte) | **Non porté** |
| `PublicFolderItemWidget` | `public_folders_page.dart:225` | **190** | `ZDefaultFolderCard` | **Non porté** |
| `_SubfolderSidebar` | `folder_details_page.dart:1760` | **279** | `ZSubfolderSidebar` / `ZSubfolderCompactSelector` | Porté (671 l.), **éteint** |
| `_ResizableLayout` + état | `folder_details_page.dart:1571` / `:1586` | **189** | — (pas d'équivalent identifié dans les symboles consommés) | **Non porté** |
| `FolderContentAddDialogWidget` | `folder_content_add_dialog_widget.dart:27` | **550** | `ZContentHubSheet` | Porté (458 l.), **éteint** |
| `FolderContentCreationButton` + `FolderDocumentSelector` | `folder_content_creating_buttons.dart:12` / `:178` | **241** | `ZContentHubEntry` | idem |
| `FolderTagsManagementDialog` | `folder_tags_management_dialog.dart` | **538** | `ZTagEditor` | Porté (209 l.), **éteint** — et le portage **répare** une purge d'orphelins absente du legacy (`folder_tags_zcrud.dart:8-13`) |
| `FolderDocumentsActionsDialogWidget` | `folder_documents_actions_dialog_widget.dart:43` | **817** | `ZItemActionsMenu` + `ZMenuEntryTile` | Porté pour le dossier seulement (`folder_actions_menu_zcrud.dart`, 241 l.), **éteint** ; **pas porté pour le document** |
| `EmtyFolderContent` + enum `FolderContentType` | `empty_folder_content.dart:16` / `:43` | **183** | `ZStudyToolsSectionSpec.emptyState` (slot injecté) | Le socle attend un widget hôte ici — l'enum reste légitime |
| `DynamicSearcheableAppBar` | `core/widgets/dynamic_searcheable_app_bar.dart` | **372** | `ZAppBarSearchConfig` + `ZAppBarAction` (`zcrud_ui_kit`) | **Consommé en partie** : `folder_details_page.dart:51/65` importe déjà `zcrud_ui_kit`, mais le widget maison reste monté ailleurs (8 sites) |
| `popup_menu_helpers.dart` | `core/widgets/popup_menu_helpers.dart` | **1 016** | `ZItemActionsMenu`, `ZMenuEntryTile` | **Non porté** |
| `WrapInProgressIndication` + `FlashcardGenerationIndicator` | `core/widgets/loading_indicators.dart:4` / `:44` | **97** | états de chargement du socle | **Non porté** |
| `StatelessItemDialogWidget<T>` (base dont `build` rend `Placeholder()`) | `core/widgets/dialog_widgets.dart:10` | **48** (+ 4 394 l. de sous-classes) | `ZItemActionsMenu` | **Non porté** |
| 5 feuilles de sélection | cf. D-11 | **898** | `ZSmartSelectPresenter` (déjà posé au scope, `z_iffd_field_registry.dart:56`) — mais seulement pour le **champ** `relation`, pas pour les feuilles autonomes | **Non porté** |
| 4 sélecteurs de document distincts | `chatbot_document_selector_dialog_widget.dart` (842), `document_selector_dropdown.dart` (303), `folder_document_pages_selection_dialog.dart` (470), `folder_document_import_dialog_widget.dart` (53) | **1 668** | — | **Non porté**. ⚠️ Textuellement **peu** dupliqués (4,3 % à 15 % de similarité) : c'est une duplication **fonctionnelle**, quatre façons de choisir un document |
| Visionneuse de document + barres d'outils | `folder_documents_actions_dialog_widget.dart:860`, `annotation_toolbar.dart` (837), `bottom_toolbar.dart` (855), `color_palette.dart` (483), `search_toolbar.dart` (229) | **3 348** | `zcrud_document` est en dépendance mais n'est importé qu'**une fois**, dans `z_backed_folder_document_repository.dart:37` — **rien de sa présentation n'est consommé** | **Non porté** |

---

## 7. Signaux transverses utiles à la migration

Mesurés sur les 3 répertoires de présentation du périmètre
(`folders/`, `subjects/`, `documents/`).

| Signal | Compte | Lecture |
|---|---:|---|
| `Color(0x…)` littéraux | **102** | FR-26 : couleur codée en dur. La palette de dégradés en est l'essentiel (D-7). |
| `Colors.<nom>` | **261** | idem |
| `setState(` | **84** | AD-2 : reconstruction non granulaire |
| `StreamBuilder` | **76** | dont **11 imbriqués** dans `folder_details_page.dart` (profondeur maximale, ligne 367) et **10** dans `public_folders_details_page.dart:265` |
| `Semantics(` | **8** | AD-13 : quasi absent, pour ~30 écrans |
| `ListView(children:` | **0** ✅ | AD-13 respecté |
| `ListView.builder` | 13 | |
| `EdgeInsets.only(left/right)` + `fromLTRB` | **17** | AD-13 : variantes non directionnelles |
| `Alignment.centerLeft/Right/…` | **15** | idem |
| `TextAlign.left/right` | **0** ✅ | |
| `Positioned(left:/right:)` | **0** ✅ | |
| `showDialog(` / `AlertDialog(` en direct | **2** (un seul fichier) | ✅ bon signe : les confirmations passent par `buildConfirmDialog` (`utils/functions/forms_utils.dart`) et `showPushedDialog` (**100 sites** dans `lib/`) |
| Profondeur d'imbrication `StreamBuilder`/`FutureBuilder` | **11** | `folder_details_page.dart:367` |

**Tests existants du périmètre** : 22 fichiers répartis sur les lots
`w6`, `w7d`, `w7h`, `w7k`, `w7o`, `w8a`, `w8b`, `w8i`, `w8k`, `w8p`, `w8q`,
`qa-w2`, `characterization`, plus
`test/src/features/home/providers/folder_providers_test.dart` et
`test/src/features/subjects/providers/subject_providers_test.dart`.
Notable : `test/characterization/folders_subjects_roundtrip_test.dart` — une
garde de **caractérisation** du round-trip, exactement le tripwire recommandé
côté aval.

---

## 8. Ce que ce relevé dit de la migration

1. **Le domaine Étude est largement migré sur le papier, presque pas à
   l'écran.** 6 775 lignes de portage zcrud existent dans le périmètre
   (5 305 de présentation + 1 470 de chemin de données) ; **728 seulement sont
   atteignables à l'exécution** — le formulaire de matière, seule bascule du
   périmètre présente dans `main.dart:201-210`. Le premier travail n'est pas
   d'écrire du portage : c'est de **basculer** ce qui est écrit, une bascule à
   la fois selon la famille de risque déjà classée dans `z_qa_flags.dart`, puis
   de retirer le legacy derrière.

2. **L'assemblage le plus rentable existe déjà et n'est pas consommé.**
   `presentFormEdition` absorbe D-2 + D-3 = **682 lignes** sur 12 écrans ;
   `ZContentHubSheet` absorbe **791 lignes** ; `ZStudyToolsSectionSpec`
   absorbe **1 092 lignes**. Trois assemblages, **2 565 lignes**, tous déjà
   livrés par le socle et déjà traduits côté hôte.

3. **Trois assemblages manquent vraiment**, et chacun est signalé par un compte
   de sites, pas par une intuition :
   - une **feuille de sélection d'entité** (D-11 : 5 sites, 898 l.) ;
   - une **feuille d'actions par entité** (D-12 : 12 sites, 4 394 l., dont la
     base maison rend un `Placeholder()`) ;
   - un **flux d'import de fichier** (D-6 : 5 sites, ~170 l., écrit dans des
     `build()`).

4. **Le modèle est le vrai verrou.** Aucune annotation `@ZcrudModel` n'existe
   (§9.1) : `toMap`/`fromMap`/`copyWith`/`props` sont écrits à la main sur 10
   entités, dispatché par une `Map<Type, Function>` maintenue à la main, et le
   **nom de collection Firestore est le nom de la classe Dart**. Tant que ce
   point tient, chaque champ ajouté se paie deux fois (legacy + zcrud) et
   chaque renommage de classe est un incident de production.

5. **Deux `build()` de plus de 1 400 lignes** (`FolderDetailsPage` : 1 476 ;
   `FolderStudyToolsPage` : 1 393) et **11 `StreamBuilder` imbriqués** sont la
   raison d'être de l'objectif produit n° 1. Aucun découpage progressif ne les
   réduira : ils tombent avec `ZStudyFolderDetail` + `ZStudyToolsPage`, tous
   deux déjà portés et éteints.

---

## 9. Greps négatifs (preuves d'absence)

### 9.1 Aucune annotation zcrud n'est posée sur un modèle d'IFFD

```
$ grep -rn "^\s*@Zcrud" lib --include='*.dart'
$ echo RC=$?
RC=1
```

RC=1 ⇒ **zéro occurrence**. Les 10 occurrences de `@ZcrudField` dans `lib/`
sont toutes des **commentaires** des adaptateurs `z_backed_*`, qui décrivent le
schéma des entités **de zcrud**, jamais d'IFFD :
`z_backed_flashcard_repository.dart:20,134`, `z_backed_exam_repository.dart:20,151`,
`z_backed_smart_note_repository.dart:18,109`,
`z_backed_folder_document_repository.dart:17,106`,
`z_backed_folder_repository.dart:21,156`.
`zcrud_annotations` n'apparaît qu'en `dependency_overrides`
(`pubspec.yaml:577`), tiré transitivement par `zcrud_study_kernel`.

### 9.2 Le périmètre n'utilise pas le moteur de liste legacy

```
$ grep -rn "DynamicListScreen\|DynamicDataTable" \
    lib/src/presentation/features/folders \
    lib/src/presentation/features/subjects \
    lib/src/presentation/features/documents --include='*.dart'
$ echo RC=$?
RC=1
```

RC=1 ⇒ **zéro occurrence**. Les seuls consommateurs de `DynamicListScreen` dans
`lib/` sont `lib/cotation/cotations_screen.dart` et `lib/agents_screens.dart`
(2 sites chacun), hors périmètre. Toutes les listes du domaine Étude sont des
grilles et des `ListView.builder` **écrits à la main**.

### 9.3 `zcrud_list` et `zcrud_export` ne sont pas importés

```
$ grep -rn "package:zcrud_list\|package:zcrud_export" lib --include='*.dart'
$ echo RC=$?
RC=1
```

RC=1 ⇒ **zéro occurrence**. Cohérent avec la note de `pubspec.yaml:292`
(« exigent Syncfusion ^34 »).

### 9.4 Aucun cache local ni synchronisation offline du domaine

```
$ grep -rn "Hive\|persistenceEnabled\|Source.cache\|GetOptions" lib/src --include='*.dart'
$ echo RC=$?
RC=1
```

RC=1 ⇒ **zéro occurrence**. La seule occurrence de `CacheManager` dans `lib/src`
est `src/iffd_cache_manager.dart:3-5`, un cache **d'images réseau**
(`flutter_cache_manager`), sans rapport avec les données du domaine.

### 9.5 Aucun secret n'est lu ni cité par ce relevé

Aucune clé d'API, aucun jeton, aucun identifiant de service n'a été extrait,
recopié ni cité. Les fichiers de configuration de plateforme
(`firebase.json`, `firestore.rules`, `storage.rules`, `functions/`,
`nodejs/`, `android/`, `ios/`, `web/`) n'ont **pas** été ouverts.

### 9.6 Aucune écriture dans le dépôt IFFD

```
$ git -C /home/zakarius/DEV/iffd status --short
```
(aucune sortie, au début comme à la fin du relevé)
