# Carte du domaine « Étude — dossiers d'étude » (IFFD)

**Relevé du 2026-08-26.** Dépôt hôte `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`,
HEAD `65d1af9`. Lecture seule stricte — aucun fichier de l'hôte n'a été écrit, aucun test lancé.

Socle de référence au moment du relevé : **zcrud v3.21.0, 41 paquets**.

> ⚠️ Tout constat repris du relevé périmé `docs/analyses/iffd-migration-2026-08-25/` a été
> **remesuré sur disque**. Les `fichier:ligne` de ce document ont été lus au HEAD ci-dessus.

---

## 0. Périmètre réellement couvert

Le périmètre demandé (`presentation/features/folders/`, `features/documents/`, modèles de dossier)
est un point de départ. En suivant les dépendances réelles j'ai inclus **au-delà** : la couche
`documents` de *présentation* (le périmètre nommé, `lib/src/features/documents/`, est un **fichier
vide**), les dépôts du domaine, les six adaptateurs `z_backed_*`, la couche de sécurité, les
widgets partagés `presentation/core/widgets`, le socle de bascule `presentation/shared/zcrud`, et
le moteur legacy `lib/data_crud/`.

| Bloc | Fichiers | Lignes | Dans le périmètre nommé ? |
|---|---:|---:|---|
| `lib/src/presentation/features/folders/**` | 36 | 18 333 | ✅ nommé |
| `lib/src/presentation/features/documents/**` | 12 | 6 420 | ➕ ajouté (le vrai code documents) |
| `lib/src/features/documents/documents_module.dart` | 1 | **0** | ✅ nommé — **fichier VIDE** (`ls -la` : 0 octet, daté du 17 fév. 2026) |
| Modèles de dossier (`domain/models/folder*.dart`) | 6 | 1 310 | ✅ nommé |
| Ports de dépôt (`domain/repositories/folder*.dart` + `datacrud_repository.dart`) | 9 | 786 | ➕ ajouté |
| Adaptateurs de données (`data/repositories/`, 4 cités) | 4 | 2 403 | ➕ ajouté |
| Sécurité / ACL (`domain/security/`) | 5 | 1 194 | ➕ ajouté |
| **Sous-total « domaine dossier »** | **73** | **30 446** | |
| `presentation/core/widgets/**` (partagé) | 4 | 1 536 | ➕ périphérie |
| `presentation/shared/**` (bascules, registre, thème) | 17 | 3 405 | ➕ périphérie |
| `utils/functions/forms_utils.dart` | 1 | 1 193 | ➕ périphérie |
| `lib/data_crud/**` (moteur d'édition/liste legacy) | 24 | 14 980 | ➕ périphérie |
| **Total exploré** | **119** | **51 560** | |

Ce que je **n'ai pas** inclus, faute de rapport direct : `features/flashcards/**`,
`features/mindmap/**`, `features/smartnotes/**`, `features/exams/**` — le domaine dossier les
*appelle* (contenus d'un dossier) mais ils ont leurs propres cartes.

---

## 1. Ce que le domaine sait faire (en termes d'utilisateur)

### 1.1 Organiser sa matière d'étude

| Capacité | Où elle vit |
|---|---|
| Créer un **dossier d'étude** rattaché à une matière et à une année académique | `dialogs/folder_modal_dialogs.dart:47` (`showFolderEditonDialog`) |
| Créer un **sous-dossier** (un seul niveau : `isSubFolder` + `parentId`) | `dialogs/folder_actions_dialog_widget.dart:57-82` |
| Donner au dossier une **couleur** libre, choisie par l'utilisateur | `domain/models/folder_model.dart:19` (`Color? color`) |
| **Publier** un dossier vers la communauté / le partager avec des auditeurs nommés | `folder_model.dart:26,28` (`isPublic`, `sharedWith`) ; `widgets/folder_coworkers_dialog_widget.dart` (449 l) |
| Partager **par lien** et laisser les co-équipiers inviter | `folder_model.dart:29,30` (`canBeJoinedWithLink`, `coWorkersCanInviteOthers`) |
| **Archiver** un dossier (`archivedAt`) | `domain/repositories/folders_repository.dart:342` (`archiveFolder`) |
| **Supprimer en cascade** un dossier et ses sous-dossiers | `folders_repository.dart:135` (`deleteFolder`), `:346` (`deletedSubFolders`) |
| **Réordonner** les sous-dossiers à la main (persisté) | `pages/folder_details_page.dart:200-224` (`reordonnerSousDossiers`) |
| **Filtrer** la liste par filières-et-cycles, modules, auditeurs ; basculer « tous » / « mes dossiers » | `pages/folders_page.dart:194-208` + `:1455-1542` (barre) |
| **Chercher** dans les dossiers et dans leur contenu | `shared/controllers/dynamic_list_search_controller.dart` (71 l) |
| **Grouper** la liste par matière quand on regarde « tous » | `folders_page.dart:189` (`groupBySubject = !onlyForMe`) |

### 1.2 Remplir un dossier — les quatre natures de contenu

Un dossier porte **flashcards, documents, notes, cartes mentales** (+ examens rattachés).

| Capacité | Où |
|---|---|
| **Téléverser** un fichier (pdf/word/excel/ppt/image/texte) | `documents/widgets/folder_document_import_dialog_widget.dart` (53 l) |
| **Scanner** un document depuis l'appareil | `folder_content_add_dialog_widget.dart` (entrée « Scanner ») |
| **Créer une note** riche (markdown/Delta) | entrée « Créer une note » du hub |
| **Créer une carte mentale** | entrée « Créer une carte mentale » |
| **Créer des flashcards** à la main, ou par lot dans un éditeur multiple | `showMultiFlashcardEditorPage` |
| **Réordonner** documents / notes / cartes mentales par glisser-déposer, ordre **par utilisateur** | `folder_study_tools_page.dart:311` (`onFolderContentReorder<T>`) + `FolderContentsOrders` (`folder_model.dart:332`) |
| **Baliser** les flashcards d'un dossier (balises colorées, création/renommage/suppression avec purge des références orphelines) | `dialogs/folder_tags_management_dialog.dart` (538 l) |
| **Déplacer** une note / une carte / un document vers un autre dossier ou sous-dossier | `core/widgets/popup_menu_helpers.dart:413,536,921` |

### 1.3 Faire travailler l'IA sur le dossier

C'est la capacité la plus dense, et la plus dispersée.

| Capacité utilisateur | Méthode du port | Sites d'appel |
|---|---|---|
| Générer des **flashcards depuis un document** (tout le document, ou des pages choisies) | `generateFlashcardsFromWholeDocument`, `…FromDocumentPagesContents` | 2 + 3 |
| Générer des **flashcards depuis une note** | `generateFlashcardsFromNotes` | 6 |
| Générer des **flashcards depuis la matière** | `generateSubjectFlashcards` | 2 |
| Générer une **carte mentale** depuis un document ou une note | `generateMindmapFromWholeDocument`, `…FromDocumentPagesContents`, `…FromNotes` | 1 + 2 + 6 |
| **Résumer** un document (entier ou pages choisies) | `generateSummaryFromWholeDocument`, `…FromDocumentPagesContents` | 3 + 3 |
| **Expliquer** la matière du dossier, l'élaborer, la résumer, la reformuler « avec style » (poème, histoire, humour, salle de classe) | `generateSubjectExplanation`, `elaborateExplanation`, `summarizeExplanation`, `explainSubjectWithStyle` | 2 / 6 / 6 / 5 |
| Déduire les **sujets connexes** du dossier | `generateRelatedTopics` | 1 |
| **Convertir** un document non-PDF en PDF | `convertDocumentToPdf` | 7 |
| Générer un **audio** depuis un texte | `generateSpeechFromTextWithAi` | 2 |
| **Discuter** avec l'assistant dans le contexte du dossier (onglet Notebook) | `zcrud/assistant_chat_zcrud_mount.dart` (230 l), `zcrud/notebook_zcrud_mount.dart` (172 l) |

Le résultat d'une explication est **rangé sur le dossier lui-même** (`folderExplaination`,
`relatedTopics` — `folder_model.dart:31,32`), pas dans une entité séparée.

### 1.4 Lire et annoter un document

| Capacité | Où |
|---|---|
| Visionneuse PDF plein écran (Syncfusion) | `documents/widgets/folder_documents_actions_dialog_widget.dart:860-1804` (`FolderDocumentViewer`, 945 l) |
| **Annoter** : surlignage, soulignement, barré, note, dessin, formes | `documents/widgets/document_viewer/annotation_toolbar.dart` (837 l) |
| Choisir la **couleur** d'annotation dans une palette | `document_viewer/color_palette.dart` (483 l) |
| **Chercher** dans le PDF | `document_viewer/search_toolbar.dart` (229 l) |
| Barre d'outils basse (pages, zoom, signets…) | `document_viewer/bottom_toolbar.dart` (855 l) |
| **Reprendre la lecture** où on s'était arrêté | `domain/models/folder_document_reading.dart` (105 l) |
| Suivre l'**avancement d'apprentissage** d'un document | `domain/models/folder_document_learning_info.dart` (82 l) |
| **Sélectionner des pages** avant d'envoyer à l'IA | `documents/widgets/folder_document_pages_selection_dialog.dart` (470 l) |

### 1.5 Suivre sa progression

- Onglet **Progression** d'un dossier : graphiques + liste des examens à venir
  (`pages/folder_progress_page.dart`, 596 l, `examsListBuilder` à `:87`).
- **Badges de comptage** sur chaque carte de dossier : flashcards / notes / documents / cartes
  mentales / sous-dossiers (`folders_page.dart:845-860`).

### 1.6 Découvrir les dossiers publics

- `pages/public_folders_page.dart` (413 l) — la vitrine ;
  `pages/public_folders_details_page.dart` (709 l) — le détail en lecture seule.

---

## 2. Écrans et dialogues

### 2.1 Écrans (routés)

| Chemin | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `pages/folders_page.dart` | 1 542 | Liste des dossiers (+ `CommunityFoldersPage` `:1450`) | **liste** + navigation + barre de recherche/filtre (`:1455`) |
| `pages/folder_details_page.dart` | 2 037 | Détail d'un dossier : 3 onglets « Matériel pédagogique / Notebook / Progression » (`:1168-1176`) | **navigation** + rendu riche + mise en page adaptative |
| `pages/folder_study_tools_page.dart` | 2 265 | Onglet Matériel : les 4 sections de contenu (+ `SubjectStudyToolsPage` `:2252`) | **listes** + réordonnancement + états vides |
| `pages/folder_progress_page.dart` | 596 | Progression + examens | **liste** + graphiques |
| `pages/folder_explanation_page.dart` | 325 | Explication IA du dossier (+ 3 sous-classes `:276,:292,:311`) | **rendu riche** |
| `pages/public_folders_page.dart` | 413 | Dossiers publics | **liste** |
| `pages/public_folders_details_page.dart` | 709 | Détail public, lecture seule | liste + rendu riche |

Routes déclarées : `config/router/app_router.dart:152` (`FoldersPageRoute`), `:245`
(`FolderDetailsPageRoute`), `:249` (`FolderFlashcardsListPageRoute`).
`PublicFoldersPageRoute` et `CommunityFoldersPageRoute` sont **commentées** (`:160`, `:186`).

### 2.2 Dialogues et feuilles

| Chemin | Lignes | Rôle | Porte |
|---|---:|---|---|
| `dialogs/folder_modal_dialogs.dart` | 792 | **11 fonctions d'ouverture** (`:47,295,480,512,543,565,584,666,705,735,770`) | formulaires + aiguillage legacy/porté |
| `dialogs/folder_content_add_dialog_widget.dart` | 550 | « Ajouter du contenu » — 6 entrées de création | grille d'actions |
| `dialogs/folder_tags_management_dialog.dart` | 538 | Gérer les balises (sélection multiple, suppression en lot) | liste + formulaire |
| `dialogs/folder_actions_dialog_widget.dart` | 186 | Feuille d'actions d'un dossier | menu |
| `widgets/folder_coworkers_dialog_widget.dart` | 449 | Partage / co-équipiers | liste + formulaire |
| `widgets/public_folder_selection_dialog_widget.dart` | 239 | Choisir un dossier public | liste arborescente |
| `widgets/folder_subfolder_selection_dialog_widget.dart` | 228 | Choisir dossier **et** sous-dossier | liste arborescente |
| `widgets/folder_tags_selection_dialog_widget.dart` | 193 | Choisir des balises | liste à cocher |
| `widgets/folder_selection_dialog_widget.dart` | 155 | Choisir un dossier | liste arborescente |
| `documents/dialogs/documents_dialogs.dart` | 323 | 5 ouvertures document (`:37,127,173,222,303`) | formulaires + visionneuse |
| `documents/widgets/folder_documents_actions_dialog_widget.dart` | 1 804 | Actions sur un document **+ la visionneuse PDF** (`:860`) | menu + rendu PDF + annotations |
| `documents/widgets/chatbot_document_selector_dialog_widget.dart` | 842 | Choisir des documents pour le chat | liste |

### 2.3 Widgets

| Chemin | Lignes | Rôle |
|---|---:|---|
| `widgets/folder_content_creating_buttons.dart` | 241 | Boutons de création (fichier / scan) |
| `widgets/first_folder_widget.dart` | 224 | Parcours « premier dossier » (onboarding) |
| `widgets/empty_folder_content.dart` | 183 | État vide d'un dossier |
| `controllers/folder_details_controller.dart` | 487 | État de la page de détail |

### 2.4 🔴 Les jumeaux déjà portés, et leur drapeau

Douze jumeaux existent. **Onze** sont atteignables ; **un** ne l'est pas.

| Drapeau (`z_qa_flags.dart`) | Famille | Jumeau porté | l. | Écran legacy remplacé | Lecture du drapeau |
|---|---|---|---:|---|---|
| `folderCard` `:159` | rendu | `zcrud/folder_card_zcrud.dart` | 618 | `folders_page.dart:763-1449` | `folders_page.dart:997` ✅ |
| `folderCardDefault` `:165` | rendu | `zcrud/folder_card_default_zcrud.dart` | 263 | idem, rendu par `ZDefaultFolderCard` | `folders_page.dart:997` ✅ |
| `folderDetail` `:176` | comportement | `zcrud/folder_detail_zcrud.dart` | 545 | `folder_details_page.dart` (ossature) | `folder_details_page.dart:780` ✅ |
| `subfolderNav` `:185` | comportement | `zcrud/subfolder_nav_zcrud.dart` | 671 | `folder_details_page.dart:1760-2037` | `folder_details_page.dart` ✅ |
| `studyTools` `:191` | comportement | `zcrud/study_tools_zcrud_adapter.dart` + `…_view.dart` + `…_flag.dart` | 962+39+44 | `folder_study_tools_page.dart:857-2251` | `folder_study_tools_page.dart:859` ✅ |
| `folderEdition` `:197` | comportement | `dialogs/folder_zcrud_edition.dart` | 556 | branche legacy de `showFolderEditonDialog` | `folder_modal_dialogs.dart:69` ✅ |
| `foldersFilter` `:206` | comportement | `dialogs/folders_filter_zcrud_edition.dart` | 462 | `showFoldersFilterDialog` | `folder_modal_dialogs.dart:326,35` ✅ |
| `folderTags` `:223` | **données** | `zcrud/folder_tags_zcrud.dart` | 209 | `folder_tags_management_dialog.dart` | `folder_tags_management_dialog.dart` ✅ |
| `contentHub` `:230` | **données** | `zcrud/content_hub_zcrud.dart` | 458 | `folder_content_add_dialog_widget.dart` | `folder_modal_dialogs.dart:613` ✅ |
| `folderDocument` `:665` | comportement | `documents/dialogs/folder_document_zcrud_edition.dart` | 212 | `showFolderDocumentEditonDialog` | `documents_dialogs.dart` ✅ |
| `richTextEditor` `:928` | **données** | `zcrud/notebook_artifact_actions_iffd.dart` | 488 | `data_crud/rich_text_editor_screen.dart` | `notebook_artifact_actions_iffd.dart:325` ✅ |
| — **absent du registre** | — | `zcrud/folder_actions_menu_zcrud.dart` | **241** | `popup_menu_helpers.dart:186-268` | 🔴 **jamais lu** |

🔴 **`folder_actions_menu_zcrud.dart` est du code mort en production.** Preuve :
- son drapeau est une **constante de compilation sans provider** :
  `grep -rn "folderActionsMenuUseZcrud\|kFolderActionsMenuUseZcrudDefault" lib` ne rend que sa
  **déclaration** (`folder_actions_menu_zcrud.dart:56`) — donc elle n'est lue nulle part ;
- `grep -n "folderActionsMenu" lib/src/presentation/shared/zcrud/z_qa_flags.dart` → **0 résultat** :
  il n'est pas dans les 52 bascules, donc invisible à toute séance de QA ;
- `grep -rn "iffdFolderActions" lib --include='*.dart'` → **une seule ligne**, sa déclaration
  (`:98`) ; `FolderActionsMenuZcrudView` n'apparaît que dans son propre fichier (`:155,:157,:232`).
  Ses seuls consommateurs sont trois tests (`test/w8k/`, `test/w8p/`).

🔴 **Aucune bascule du domaine dossier n'est active à l'exécution.** `lib/main.dart:201-210`
active `{notebook, aiRouterEdition, exam, valuationTool, subject, flashcardEdition,
anneeAccademique, aiExpert}` — aucun des douze identifiants du tableau ci-dessus. Le domaine
dossier tourne donc **intégralement en legacy** aujourd'hui, malgré 5 226 lignes de portage
écrites (`folders/zcrud/**` = 13 fichiers, 4 940 l ; + les 3 formulaires portés, 1 230 l).

Un seul drapeau du dépôt est à `true` par défaut :
`ai_routers/zcrud/ai_router_zcrud_edition.dart:104` — hors périmètre.

---

## 3. Modèles et persistance

### 3.1 Entités

| Entité | Fichier | l. | Champs notables |
|---|---|---:|---|
| `FolderModel` | `domain/models/folder_model.dart:13` | 489 (fichier) | `accademicYear` (⚠️ orthographe legacy), `filieresEtCycles`, `title`, `subjectId`, `color` (`Color?` **type Flutter dans le domaine**), `creatorId`, `isPublic`, `sharedWith`, `canBeJoinedWithLink`, `coWorkersCanInviteOthers`, `isSubFolder`, `parentId`, 4 dates, `relatedTopics`, `folderExplaination` (⚠️ orthographe legacy) |
| `FolderContentModel` | `folder_model.dart:256` | — | base commune : `folderId`, `subFolderId` (+ `subjectId`, `creatorId`, `createdAt` hérités) |
| `FolderContentsOrders` | `folder_model.dart:332` | — | l'ordre manuel **par utilisateur** : 4 listes racine + 4 `Map<String, List<String>>` par sous-dossier |
| `FolderDocument` | `domain/models/folder_document.dart:71` | 246 | + 3 énumérations : `FolderDocumentType` `:9`, `FolderDocumentExtension` `:37` (**couleur codée en dur par extension**), `FolderDocumentStatus` `:57` |
| `FolderDocumentAnnotation` | `domain/models/folder_document_annotation.dart` | 259 | annotations PDF |
| `FolderDocumentReading` | `folder_document_reading.dart` | 105 | reprise de lecture |
| `FolderDocumentLearningInfo` | `folder_document_learning_info.dart` | 82 | avancement |
| `FolderInvitation` | `folder_invitation.dart` | 129 | invitation au partage |

Base commune : `DynamicModel` (`domain/models/dynamic_model.dart`, 79 l) — `toMap`/`copyWith`/`props`
abstraits, `==` structurel **avec descente profonde** dans listes/maps (`:52-79`, motivé en
commentaire par un défaut mesuré).

### 3.2 Sérialisation — entièrement manuelle

- **35** `Map<String, dynamic> toMap()` et **35** `factory X.fromMap` dans `lib/src/domain/models/`
  (`grep -c`), **64 / 62** dans tout `lib/`.
- **Aucune annotation zcrud sur un modèle IFFD.** `grep -rn "@ZcrudModel\|@ZcrudField\|@ZcrudId" lib`
  ne rend que **10 lignes, toutes des commentaires** des six adaptateurs `z_backed_*` — jamais une
  annotation réelle.
- Les dates sont écrites en `Timestamp` Firestore **dans le modèle du domaine**
  (`folder_model.dart:120-126`) : `cloud_firestore` fuit jusqu'au domaine.
- La couleur est écrite en ARGB32 décimal sous forme de **chaîne** (`folder_model.dart:118`).

### 3.3 Dépôts

- Contrat générique `CrudRepository<T>` (`domain/repositories/datacrud_repository.dart:20`) :
  `create` / `mapCreate` / `streamAll` / `streamOne` / `all` / `count` / `batch*` / `update` /
  `mapUpdate` / `softDelete` / `delete` / `restore`. **Pas de `Either`** : retour
  `DataState<T, Exception>` maison (`utils/resources/data_state.dart`).
- `FoldersRepository` (`domain/repositories/folders_repository.dart:10`) ajoute 13 méthodes
  métier : `usersAndCommunityFolders` `:250`, `streamCommunityFolders` `:228`,
  `folderSubFolders` `:313`, `countFoldersubFolders` `:325`, `archiveFolder` `:342`,
  `deleteFolder` `:135`, `deletedSubFolders` `:346`, `userFirstFolder` `:148`…
- Implémentation unique générique : `data/repositories/firebase_crud_repository_impl.dart` (499 l),
  spécialisée en **31 sous-classes d'une à quinze lignes** dans
  `firebase_models_repositories_impls.dart` (434 l). ✅ *Ici, pas de duplication* — c'est le
  contre-exemple utile.
- **Source** : Firestore. Un `supabase_crud_repository_impl.dart` (377 l) existe mais n'est pas
  câblé aux dossiers.
- **Cache** : `lib/src/iffd_cache_manager.dart` (hors périmètre direct).

### 3.4 Le double chemin de données zcrud (strangler fig)

Six adaptateurs traduisent une entité IFFD vers une entité **réelle** de `zcrud_study_kernel` /
`zcrud_document` / `zcrud_note` / `zcrud_exam`, derrière un drapeau Riverpod :

| Adaptateur | l. | Entité zcrud | Drapeau (défaut `false` = legacy) |
|---|---:|---|---|
| `z_backed_folder_repository.dart` | 772 | `ZStudyFolder` | `useZcrudFoldersRepositoryProvider` (`folder_providers.dart:40`) |
| `z_backed_folder_document_repository.dart` | 698 | `ZStudyDocument` | `useZcrudFolderDocumentRepositoryProvider` `:57` |
| `z_backed_smart_note_repository.dart` | 663 | `ZSmartNote` | `useZcrudSmartNoteRepositoryProvider` `:72` |
| `z_backed_mindmap_repository.dart` | 806 | `ZMindmap` | `useZcrudMindmapRepositoryProvider` `:87` |
| `z_backed_flashcard_repository.dart` | 797 | `ZFlashcard` | (dans `flashcard_providers.dart`) |
| `z_backed_exam_repository.dart` | 912 | `ZExam` | (dans `exam_providers.dart`) |
| **Total** | **4 648** | | **tous à `false`** |

Cinq dépôts du domaine dossier n'ont **aucun** jumeau zcrud :
`FolderInvitaionsRepository`, `FolderContentsOrdersRepository`, `FolderDocumentReadingRepository`,
`FolderDocumentLearningRepository`, `FolderDocumentAnnotationRepository`
(`folder_providers.dart:96-115`).

### 3.5 Traitement des erreurs

- `DataState<T, Exception>` (`DataSuccess` / `DataFailed`), pas de `Either<ZFailure, T>` dans la
  couche legacy. `ZFailure` n'apparaît que dans les **jumeaux portés** (`Right<ZFailure, Map<…>>`
  en sortie de formulaire, 12 sites — dont `folder_zcrud_edition.dart:488` et
  `folder_document_zcrud_edition.dart:168`).
- **35 `try {`** et **33 `catch (`** dans `folders/` + `documents/`. Plusieurs sont des
  `catch (_) {}` muets — ex. `folder_study_tools_page.dart:280` (le tri par titre avale toute
  exception de transtypage).

---

## 4. 🔴 Le code répété — le point décisif

Chaque ligne ci-dessous est un **assemblage manquant** au socle, ou un assemblage existant que
l'hôte ne consomme pas.

| # | Ce qui est répété | Sites | Lignes | Preuve |
|---|---|---:|---:|---|
| **D1** | **Les quatre sections de contenu** de la page « outils d'étude » : `ExpandablePanel` + titre à badge + tri `getSortedIterms<T>` + `ReorderableGridView.count` + `onFolderContentReorder<T>` + carte d'item + état vide, réécrits pour Flashcards / Documents / Notes / Cartes mentales | **4** | **1 223** | `folder_study_tools_page.dart:1029-1175`, `:1176-1585`, `:1586-1945`, `:1946-2251` |
| **D2** | **Les adaptateurs de données** `z_backed_*`, dont les en-têtes disent eux-mêmes « RÉPLICATION EXACTE du patron des cutovers PRÉCÉDENTS » | **6** | **4 648** | `z_backed_folder_repository.dart:4-11` et 5 jumeaux |
| **D3** | **Sérialisation à la main** (`toMap` + `fromMap` + `copyWith` + `props`) | **35** modèles (dont **6** du domaine dossier) | **639** pour les 6 ; 35 triplets au total | `folder_model.dart` 273 l, `folder_document.dart` 96, `folder_document_annotation.dart` 112, `folder_invitation.dart` 77, `folder_document_reading.dart` 42, `folder_document_learning_info.dart` 39 |
| **D4** | **Les menus contextuels d'item** — même squelette `PopupMenu(config: MenuConfig(grid, maxColumn: 2))` + `switch (item.menuUserInfo)` + garde de droit + action | **5** | **831** | `popup_menu_helpers.dart:186` (folder), `:269` (note), `:492` (mindmap), `:612` (flashcard), `:667` (document) |
| **D5** | **Les blocs « générer avec l'IA »** : `loadingCallback(true)` → appel → `onComplete(result, completed, {hasError})` → `normalizedJsonString` → `json.decode` → `fromMapList<T>` → `batchSet` → `loadingCallback(false)` | **35** (dont 5 dans `popup_menu_helpers.dart`, 6 dans `discovry_page_controller.dart`) | ~50-100 l par site | `grep -rn "onComplete: (result, completed"` = 35 ; `normalizedJsonString` = 24 sites ; `fromMapList<FlashcardModel>` = 13 sites |
| **D6** | **Les sélecteurs de dossier** — même arbre `StreamBuilder<List<FolderModel>>` + `ExpandablePanel` par parent + `ListTile` par enfant | **3** | **622** | `folder_selection_dialog_widget.dart` (155), `folder_subfolder_selection_dialog_widget.dart` (228), `public_folder_selection_dialog_widget.dart` (239) |
| **D7** | **Les cartes d'état « génération en cours » par item** dans le contrôleur de détail : `Map<String?, bool> areXxxYyyGenerating` | **16** | 21 (déclarations) + les gardes `.values.any((e) => e)` | `folder_details_controller.dart:31-51` ; agrégats `:56-65` |
| **D8** | **Le gabarit de bascule** : `const bool kXxxDefault = false;` + `final Provider<bool> xxxUseZcrudProvider = Provider<bool>((ref) => k…, name: '…')` + entrée de registre | **55** constantes / **52** providers repo-wide, dont **12 / 10** dans le domaine dossier | ~10 l par site + 985 l de registre | `z_qa_flags.dart` (985 l) ; déclarations listées à `folders_filter_zcrud_edition.dart:146,149`, `folder_zcrud_edition.dart:141,152`, … |
| **D9** | **Pyramides de `StreamBuilder` imbriqués** pour composer les sources d'un écran | **63** occurrences dans `folders/`+`documents/` ; pyramide de **5** pour les badges de compte, de **4** pour le détail | — | `folders_page.dart:916-…` (5 niveaux, un par nature de contenu) ; `folder_details_page.dart:138-160` (4 niveaux + `ListenableBuilder`) ; répartition : `public_folders_details_page.dart` 14, `folder_details_page.dart` 11, `folders_page.dart` 9, `chatbot_document_selector_dialog_widget.dart` 9 |
| **D10** | **Les fabriques de contexte d'accès** `FolderResourceAccessContext.forDocument/forNote/forMindmap/forFlashcard` — 24 lignes identiques à l'énumération près | **4** | **96** | `folder_resource_access_service.dart:50,74,98,122` |
| **D11** | **Ouverture de dialogue** `showPushedDialog<T>(dialog:, fullscreenDialog:, bottomSheetHeightRation:, builder:)` | **108** repo-wide, **23** dans le domaine | — | `utils/functions/forms_utils.dart:727` |
| **D12** | **Confirmation** `buildConfirmDialog(context, message:, onConfirm:)` | **38** repo-wide, **12** dans le domaine | — | `forms_utils.dart:480` |
| **D13** | **Les six entrées du hub de création**, écrites en `_ContentCard` + section titrée + garde de droit | **6** entrées, **1** écran | **263** (`:110-372`) | `folder_content_add_dialog_widget.dart` — le jumeau porté fait les mêmes 6 entrées en **79 l** (`content_hub_zcrud.dart:362-440`) |
| **D14** | **`BoxDecoration` / dégradés écrits à la main** dans le domaine | **57** `BoxDecoration(`, **12** `LinearGradient(` | — | dont 10 dégradés **codés en dur** en tête de `folders_page.dart:53-73` (`folderGradientsLight` / `folderGradientsDark`) |
| **D15** | **`ListTile` d'action** (icône + libellé + garde de droit + `Navigator.pop` + ouverture) | **72** dans `folders/`+`documents/` | — | `folder_actions_dialog_widget.dart:57,99,118,135,159,167` (6 en 130 l) |

### Ce que le portage a déjà prouvé, chiffres à l'appui

Le meilleur argument pour les assemblages est **l'écart mesuré entre les deux branches du même
écran**, dans le même dépôt :

| Écran | Legacy | Porté | Ratio |
|---|---:|---:|---:|
| Quatre sections de contenu (D1) | **1 223 l** (`:1029-2251`) + 206 l d'aides (`buildContentTitle` `:103-140`, `_buildGridItemCard` `:143-226`, `getSortedIterms` `:227-310`) = **1 429 l** | `buildStudyToolsSections` `:595-820` (226) + `zStudyToolsSection` `:452-594` (143) + 4 constructeurs d'items `:821-852,887-921,922-942,943-962` (108) = **477 l** | **÷ 3,0** |
| Hub de création (D13) | **263 l** | **79 l** | **÷ 3,3** |
| Menu d'actions de dossier (D4, 1er site) | **83 l** (`:186-268`) | `iffdFolderActions` `:98-154` = **57 l** | ÷ 1,5 |

---

## 5. Ce qui est déjà branché sur zcrud

### 5.1 Fermeture des paquets consommés

**209 imports `package:zcrud_`** dans `lib/`, répartis sur 22 paquets :

`zcrud_core` 67 · `zcrud_chat_kernel` 19 · `zcrud_study` 17 · `zcrud_screen` 16 ·
`zcrud_chat` 15 · `zcrud_markdown` 11 · `zcrud_flashcard` 11 · `zcrud_study_kernel` 8 ·
`zcrud_navigation` 6 · `zcrud_mindmap` 6 · `zcrud_firestore` 5 · `zcrud_ui_kit` 3 ·
`zcrud_session` 3 · `zcrud_note` 3 · `zcrud_exam` 3 · `zcrud_document` 3 ·
`zcrud_chat_syncfusion` 3 · `zcrud_chat_material` 3 · `zcrud_select` 2 · `zcrud_intl` 2 ·
`zcrud_chat_markdown` 2 · `zcrud_menu` 1.

**Jamais importés** (greps négatifs) :
- `grep -rn "package:zcrud_list" lib` → **0 résultat** ;
- `grep -rn "package:zcrud_export" lib` → **0 résultat**.
  Motif documenté dans le `pubspec.yaml:292` : « `zcrud_list` / `zcrud_export` exigent
  Syncfusion ^34, IFFD est en ^32 ».
- `grep -rn "ZCrudScreen" lib/…/folders lib/…/documents` → **0 résultat** : l'écran CRUD assemblé
  n'est nulle part dans ce domaine.

### 5.2 Ce que le domaine dossier consomme, fichier par fichier

| Fichier | Paquets zcrud | Symboles clés |
|---|---|---|
| `zcrud/study_tools_zcrud_adapter.dart` (962) | core, flashcard, study, study_kernel | `ZStudyToolsPage`, `ZStudyToolsSectionSpec`, `ZStudyToolsItem(Card)`, `ZDefaultDocumentCard`, `ZDefaultFlashcardCard`, `ZDefaultNoteCard`, `ZReorderableAdaptiveGrid`, `ZDefaultReorderRenderer`, `ZStudyReorderHandleMode`, `ZAdaptiveGrid`, `ZTags`, `ZColorPair` |
| `zcrud/folder_detail_zcrud.dart` (545) | core, study, ui_kit | `ZStudyFolderDetail`, `ZPageScaffold`, `ZAppBarAction`, `ZAppBarSearchConfig`, `ZResponsiveLayout`, `ZSectionedStudyLayout`, `ZSubfolderNavSpec/Placement`, `ZStudySection*`, `ZGradientSpec` |
| `zcrud/subfolder_nav_zcrud.dart` (671) | study | `ZSubfolderSidebar`, `ZSubfolderCompactSelector`, `ZSubfolderNavSpec`, `ZSubfolderRef`, `ZSubfolderCountPill`, `ZSubfolderLayoutMode`, `ZSubfolderAddPlacement` |
| `zcrud/folder_card_zcrud.dart` (618) | core, study | `ZFolderCard`, `ZDefaultFolderCard`, `ZFolderCardFooterPlacement`, `ZFolderCardGradientAccent`, `ZStudyNoteCard` |
| `zcrud/folder_card_default_zcrud.dart` (263) | core, study, study_kernel | `ZDefaultFolderCard`, `ZFolderCardCount`, `ZColorPalette` |
| `zcrud/content_hub_zcrud.dart` (458) | study | `ZContentHubSheet`, `ZContentHubSection`, `ZContentHubEntry` (6), `ZExamEditor`, `ZSmartNoteEditor`, `ZMindmapOutlineEditor` |
| `zcrud/folder_tags_zcrud.dart` (209) | study, study_kernel | `ZTagEditor`, `ZFlashcardTag`, `ZColorPalette` |
| `zcrud/folder_actions_menu_zcrud.dart` (241) | menu, study | `ZItemActionsMenu`, `ZItemAction(Kind)`, `ZMenuEntryTile` — **inatteignable** (§ 2.4) |
| `zcrud/assistant_chat_zcrud_mount.dart` (230) | chat, chat_material, chat_markdown, chat_syncfusion, core | `ZChatConversationScreen`, `ZChatController`, `ZChatMaterialComposer`, `ZChatMarkdownRenderer`, `ZChatTranscriptBinding` |
| `zcrud/notebook_zcrud_mount.dart` (172) | chat | `ZChatModelOption` |
| `zcrud/notebook_artifact_actions_iffd.dart` (488) | markdown | `ZRichTextFullscreenDialog`, `ZRichTextToolbarConfig` |
| `dialogs/folder_zcrud_edition.dart` (556) | core | 6 `ZFieldSpec` (`:213,224,238,248,260,265`) |
| `dialogs/folders_filter_zcrud_edition.dart` (462) | core, screen | 3 `ZFieldSpec` (`:254,278,290`), `ZFormOnly`, `presentFormEdition` |
| `documents/dialogs/folder_document_zcrud_edition.dart` (212) | core | 1 `ZFieldSpec` (`:74`) |
| `pages/folder_details_page.dart` | ui_kit | `ZAppBarAction` (`:65`) |
| `pages/folder_study_tools_page.dart` | study, study_kernel | (via l'adaptateur) |

### 5.3 Le registre de widgets

`presentation/shared/zcrud/z_iffd_field_registry.dart:78` (`buildIffdWidgetRegistry`), **un registre
par montage** (jamais un singleton) :

| Enregistrement | Ligne | Détail |
|---|---:|---|
| `registerZMarkdownFields(registry, codec:, styleSet:, chrome:)` | `:101` | codec `IffdRichTextCodec`, jeu de styles maison, `ZMarkdownFieldChrome(gradientKey:, onGradient:)`. Le bloc a **maigri de 18 lignes** après v3.21.0 : le socle rend désormais carte + barre habillée sans configuration hôte, et `toolbarConfig` a été **retiré** (il *remplace* le préréglage au lieu de s'y ajouter). |
| `registerZFlashcardEditors(registry, trueLabel:, falseLabel:, addChoiceLabel:)` | `:171` | trois éditeurs dédiés (type, QCM, vrai/faux) servis sous le `kind` `custom`. Le commentaire signale une **divergence assumée** : le validateur QCM du socle (« ≥ 2 choix, ≥ 1 correct ») n'existe **nulle part** en legacy. |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `:188` | le legacy **déclarait** `EditionFieldTypes.phoneNumber` sans jamais le rendre |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | `:199` | `FlutterSwitch` sous le **nom du type** ⇒ tous les booléens changent de contrôle sans qu'une `ZFieldSpec` le déclare |

Autour : `IffdZcrudScope` (`:295`), thèmes mémoïsés par luminosité (`:323`), `ZSmartSelectPresenter`
par luminosité (`:336`).

Autres pièces partagées : `z_iffd_acl_matrix_field.dart` (262), `z_iffd_field_palette.dart` (225),
`z_iffd_form_theme.dart` (281), `z_iffd_rich_text_codec.dart` (193), `z_iffd_relation_source.dart`
(140), `z_iffd_boolean_field.dart` (140), `z_questions_counts_field.dart` (169),
`z_iffd_markdown_style.dart` (153), `z_iffd_stepper.dart` (60), `z_iffd_value_adapters.dart` (39),
`z_text_transforms.dart` (40), `z_flag_gateway.dart` (86).

### 5.4 La passerelle de drapeau

`z_flag_gateway.dart:1-34` documente un défaut mesuré le 2026-07-30 : **sur 17 providers de
bascule, un seul était lu** ; les seize autres aiguillaient sur la constante `const`, résolue à la
compilation. La passerelle `zcrudFlagValue(provider, fallback:)` lit le `ProviderScope` depuis un
code sans `ref` (les `showXxxDialog` sont des fonctions top-level appelées de dizaines de sites).
Elle **ne réagit pas** aux changements (`read`, pas `watch`) et **ne lève jamais** (repli legacy).

---

## 6. Les widgets maison qui refont ce que le socle fait

| Widget maison | Fichier:ligne | l. | Équivalent socle | État |
|---|---|---:|---|---|
| `FolderItemWidget` (carte de dossier, dégradé + badges + menu) | `folders_page.dart:763-1449` | **687** | `ZFolderCard` / `ZDefaultFolderCard` (`zcrud_study`) | jumeau écrit, **éteint** |
| `_SubfolderSidebar` | `folder_details_page.dart:1760-2037` | **278** | `ZSubfolderSidebar` | jumeau écrit, **éteint** |
| `_ResizableLayout` (colonne redimensionnable à la souris) | `folder_details_page.dart:1571-1759` | **189** | `ZResponsiveLayout` (`zcrud_responsive`) | jumeau écrit, **éteint** |
| `_buildGridItemCard` | `folder_study_tools_page.dart:143-226` | **84** | `ZStudyToolsItemCard` | jumeau écrit, **éteint** |
| `buildContentTitle` (titre + pastille de compte) | `folder_study_tools_page.dart:103-140` | **38** | `ZStudySectionCount*` de `ZStudyToolsSectionSpec` | jumeau écrit, **éteint** |
| `EmtyFolderContent` | `widgets/empty_folder_content.dart:44` | **183** | `globalEmptyState` de `ZStudyToolsPage` | jumeau écrit, **éteint** |
| `FolderContentAddDialogWidget` | `dialogs/folder_content_add_dialog_widget.dart:27` | **550** | `ZContentHubSheet` | jumeau écrit, **éteint** |
| `FolderTagsManagementDialog` | `dialogs/folder_tags_management_dialog.dart:14` | **538** | `ZTagEditor` + `ZTagChips` | jumeau écrit, **éteint** |
| 5 × `buildXxxPopupMenu` | `popup_menu_helpers.dart:186,269,492,612,667` | **831** | `ZItemActionsMenu` + `ZItemAction` (`zcrud_menu`) | **1 sur 5** porté, et **inatteignable** |
| 3 × sélecteur de dossier | `widgets/folder_*_selection_dialog_widget.dart` | **622** | `ZSubfolderCompactSelector` / `ZSubfolderSelectorBar` | **aucun** jumeau |
| `DynamicSearcheableAppBar` | `core/widgets/dynamic_searcheable_app_bar.dart:9` | **372** | `ZPageScaffold` + `ZAppBarSearchConfig` (`zcrud_ui_kit` / `zcrud_screen`) | consommé **uniquement** dans `folder_detail_zcrud.dart`, éteint |
| `WrapInProgressIndication` / `FlashcardGenerationIndicator` | `core/widgets/loading_indicators.dart:4,44` | **100** | états de chargement du socle | **aucun** jumeau ; 48 usages de l'indicateur repo-wide |
| Visionneuse PDF + barres (`FolderDocumentViewer`, `annotation_toolbar`, `bottom_toolbar`, `color_palette`, `search_toolbar`) | `folder_documents_actions_dialog_widget.dart:860` + `document_viewer/*` | **945 + 2 404** | `zcrud_document` : `ZAnnotationToolbar`, `ZAnnotationPanel`, `ZDocumentViewerChrome`, `ZAnnotationToolController`, `ZDocumentViewerPrefs` | **aucun** jumeau — 3 349 l face à un paquet dédié jamais consommé pour cela |
| Moteur d'édition/liste legacy `lib/data_crud/**` | 24 fichiers | **14 980** | `zcrud_core` (moteur) + `zcrud_screen` (écran) + `zcrud_markdown` (rich-text) + `zcrud_list` | remplacement **partiel** : 238 `DynamicFormField` subsistent |

**Les déclarations de champ** : 238 instanciations de `DynamicFormField` dans `lib/`, dont **14**
dans `folder_modal_dialogs.dart` seul et **1** dans `documents_dialogs.dart`. En face, les trois
formulaires portés du domaine déclarent **10 `ZFieldSpec`** au total (6 + 3 + 1).

---

## 7. Ce que le domaine fait de PARTICULIER

Ce qui suit résisterait à toute généralisation — ou exigerait un canal déclaratif dédié.

1. **L'année académique est une dimension de tout.** Elle sert de **suffixe de clé d'ACL** :
   `"FolderModel$accademicYear"` (`folder_actions_dialog_widget.dart:41`,
   `folder_details_page.dart:194` via `cleAcces(modele)`). Un même utilisateur a des droits
   *différents sur le même type* selon l'année. La clé est **relue à chaque appel, jamais
   capturée** — le commentaire `folder_details_page.dart:189-192` explique pourquoi : elle change
   sans reconstruire le bloc.

2. **La filière et le cycle sont un produit cartésien fermé.**
   `FiliereEtCycleIFFD` (`domain/models/iffd_models.dart:30`) énumère **12 valeurs**
   (6 filières × 2 cycles), avec deux vues (`cyclesMoyens`, `cyclesSuperieurs`) et un `title`
   dérivé par découpe de chaîne. Un dossier public n'est visible que par les auditeurs de la
   promotion correspondante.

3. **La « promotion » d'un auditeur est calculée, pas stockée sur le dossier.**
   `anneeEnCours?.promotionAuditeur(userId)` rend un couple `(filière, cycle)` que la page
   reconvertit en `FiliereEtCycleIFFD` (`folders_page.dart:178-182`). Le filtre de liste **change
   de forme** selon ce couple : sans promotion, la requête interroge les matières par
   `whereIn`/`itemFilter` ; avec promotion, par `arrayContains` (`folders_page.dart:209-238`).

4. **Le filtre est une ACL déguisée.** En mode « mes dossiers » (`onlyForMe`), les filtres
   « Filières et cycles » et « Auditeurs » **disparaissent** et leurs valeurs sont neutralisées
   (`folders_page.dart:200-208`), puis **retrouvées intactes** au retour — comportement décrit
   comme à vérifier en priorité dans `z_qa_flags.dart:206-219`.

5. **Vingt-six verbes CRUD, dont six « étendus IA ».** `Crud` (`domain/security/crud.dart:6`)
   énumère 17 verbes classiques *plus* `aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`,
   `aiExplain`, `aiChat`, marqués `extended: true`. **Le droit de générer avec l'IA est un droit
   CRUD comme un autre**, avec trois jeux de défauts (`defaultCrudOperations`,
   `defaultFolderCrudOperations`, `defaultCrudOperationsExtended`, `:33-58`).

6. **`RessourceACL` est une matrice à 11 booléens** (`read, create, update, delete, copy, restore,
   archive, publish, clear, validate, history`) avec un `grantOwnerPermissions()` qui **force
   `read/update/delete` à vrai** et laisse le reste (`ressource_acl.dart:28-39`). Le propriétaire
   d'un dossier n'a donc pas *tous* les droits — seulement ce socle-là.

7. **Un dossier a quatre dates de sens différent** : `createdAt`, `updatedAt`, `archivedAt`,
   `sharedAt`. `sharedAt` n'a **aucun homologue** dans `ZStudyFolder` et vit en `extra`
   (`z_backed_folder_repository.dart:42-45`) ; `updatedAt` en a un mais il est **inexploitable**
   (clé de sync réservée `ZSyncMeta`, réécrite inconditionnellement par le store) et doit donc être
   doublé en `extra['iffd_updated_at']`.

8. **La couleur d'un dossier est une couleur, pas une clé de thème.** `ZStudyFolder` porte une
   `colorKey` symbolique ; IFFD y range l'ARGB32 décimal **et** double la valeur dans
   `extra['iffd_color']` qui fait foi au retour (`z_backed_folder_repository.dart:32-40`). Le socle
   a mesuré que peindre cette couleur brute donne « un jaune à 2.13 de contraste, un quasi-blanc à
   1.28, et un GRIS rendu ROUGE » (`z_qa_flags.dart:165-175`).

9. **Deux orthographes fautives sont contractuelles** : `accademicYear` et `folderExplaination`.
   Elles sont **préservées à dessein** jusque dans l'adaptateur zcrud (`z_backed_folder_repository.dart:59-62`).

10. **La hiérarchie est plate à un seul niveau, mais bicéphale.** `FolderModel.getFolderIds()`
    (`folder_model.dart:99`) rend `(folderId, subFolderId)` : un sous-dossier est un dossier dont
    `isSubFolder` est vrai. Ce dédoublement se propage partout — `FolderContentsOrders` porte
    **quatre listes racine plus quatre maps par sous-dossier** (`folder_model.dart:335-338`), et
    les badges de compte d'une carte de sous-dossier comptent en réalité **le parent**
    (`folders_page.dart:842-843`).

11. **L'ordre de contenu est personnel.** `FolderContentsOrders` a pour identifiant
    `"${userId}_$folderId"` (`folder_details_page.dart:140`) : deux utilisateurs voient le même
    dossier dans deux ordres différents.

12. **Le rail de flashcards n'est pas réordonnable, et ce n'est pas un oubli.** Le commentaire
    `study_tools_zcrud_adapter.dart:610-616` le relève dans le legacy et **refuse** de l'ajouter au
    portage (« ce serait un ajout de fonctionnalité déguisé en portage »). Le rail est aussi borné
    à `take(10)` alors que son badge affiche le **total**.

13. **Une flashcard peut venir de la matière, pas du dossier.**
    `FlashcardModel.subjectDefaultFlashcards(subject)` est concaténée aux flashcards du dossier
    **seulement à la racine** (`folder_study_tools_page.dart:869-873`).

14. **La couleur d'un document est décidée par son extension**, en dur dans l'énumération
    (`folder_document.dart:37-55` : `pdf` rouge, `doc/docx` bleu, `xls/xlsx` vert, `ppt/pptx`
    orange, images bleu-gris, `txt/md` gris).

15. **Le format persisté du rich-text legacy ment sur son nom.** `format: RichTextFormat.markdown`
    range en réalité un **Delta JSON sérialisé** (`data_crud/rich_text_editor_screen.dart:306-320`,
    relu par `markdown_edition_field.dart:317-322`). La branche portée range du **markdown**
    (`IffdRichTextCodec`, décision B-24) ; les deux sens de lecture restent ouverts
    (`z_iffd_rich_text_codec.dart:114-118`). Analyse complète : `z_qa_flags.dart:908-927`.

16. **Une divergence de comportement est assumée dans les formulaires portés** : un `required`
    **inerte** en legacy devient honoré en porté, et le validateur QCM du socle refusera un QCM à
    une seule proposition que le legacy acceptait (`z_iffd_field_registry.dart:153-170`,
    `smartnote_zcrud_edition.dart`). « Le porter à l'identique reviendrait à porter un bug. »

---

## 8. Ce que ce relevé n'a pas pu établir

- **La couverture réelle des tests** : 224 fichiers `*_test.dart`, dont 21 nommément liés au
  domaine dossier (`test/w6/`, `test/w7k/`, `test/w7d/`, `test/w8a/`, `test/w8b/`, `test/w8i/`,
  `test/w8k/`, `test/w8p/`, `test/w8q/`, `test/qa-w2/`, `test/m0/`, `test/characterization/`).
  Aucun test n'a été lancé (consigne).
- **Les CR ouvertes du lot S6** (`CR-IFFD-114`, `115`, `116` —
  `docs/zcrud-change-requests.md:7589,7675,7734`) portent sur le **lecteur riche et l'éditeur plein
  écran**, pas sur la structure des dossiers. `CR-IFFD-117` à `120` sont marquées « RETIRÉE AVANT
  ÉMISSION » (`:7787,7825,7859,7879`). Je ne les ai pas confrontées au socle : c'est le travail de
  la confrontation, pas de la carte.
- **Aucun secret n'a été lu.** Je n'ai ouvert aucun fichier de configuration de plateforme.

---

## 9. Annexe — contre-vérification par sondage (2026-08-26, second passage)

Ce document a été écrit par un premier passage interrompu. Un second passage a **remesuré sur
disque** treize de ses affirmations chiffrées, au même HEAD (`65d1af9`, `feat/migration-zcrud`).
Aucun fichier de l'hôte n'a été écrit ; aucun test n'a été lancé.

| Affirmation du document | Commande | Mesuré | Verdict |
|---|---|---:|---|
| `folders/**` = 36 fichiers | `find … -name '*.dart' \| wc -l` | **36** | ✅ |
| `folders/**` = 18 333 l | `find … -exec cat {} + \| wc -l` | **18 333** | ✅ |
| `features/documents/documents_module.dart` vide | `ls -la` | **0 octet**, et c'est le **seul fichier** de l'arbre (`find … -type f \| wc -l` = 1, les sous-dossiers `pages/ providers/ widgets/` sont vides) | ✅ + précision |
| `presentation/features/documents/**` = 12 f. / 6 420 l | idem | **12 / 6 420** | ✅ |
| `lib/data_crud/**` = 24 f. / 14 980 l | idem | **24 / 14 980** | ✅ |
| `folder_study_tools_page.dart` 2 265 l | `wc -l` | **2 265** | ✅ |
| `folder_details_page.dart` 2 037 l / `folders_page.dart` 1 542 l | `wc -l` | **2 037 / 1 542** | ✅ |
| D5 — 35 blocs « générer avec l'IA » | `grep -rn "onComplete: (result, completed" lib \| wc -l` | **35** | ✅ |
| D9 — 63 `StreamBuilder` dans le domaine | `grep -rn "StreamBuilder" folders documents \| wc -l` | **63** | ✅ |
| D11 / D12 — 108 `showPushedDialog` / 38 `buildConfirmDialog` | `grep -rn … \| wc -l` | **108 / 38** | ✅ |
| D3 — 35 `toMap()` dans `domain/models/` | `grep -rn "Map<String, dynamic> toMap()" … \| wc -l` | **35**, répartis sur **17 fichiers** | ✅ + précision |
| D2 — 4 648 l d'adaptateurs `z_backed_*` | `wc -l lib/src/data/repositories/z_backed_*.dart` | **4 648** (6 fichiers) | ✅ |
| 209 imports `package:zcrud_` | `grep -rhn "package:zcrud_" lib \| wc -l` | **209** | ✅ |
| 238 `DynamicFormField`, dont 14 dans `folder_modal_dialogs.dart` | `grep -rn "DynamicFormField(" \| wc -l` = **215** ; `"DynamicFormField<"` = **23** → **238** ; `grep -c "DynamicFormField[(<]" folder_modal_dialogs.dart` = **14** | **238 / 14** | ✅ (le total agrège les deux formes ; un `grep` sur la seule forme non générique en rend 215) |
| `zcrud_list` / `zcrud_export` jamais importés | `grep -rn "package:zcrud_list" lib \| wc -l` → **0** ; `…zcrud_export…` → **0** | **0 / 0** | ✅ grep négatif montré |
| `z_qa_flags.dart` 985 l, `folderCard` `:159` | `wc -l` + `sed -n '159p'` → `id: 'folderCard',` | **985 / :159** | ✅ |

**Aucune correction n'a été nécessaire.** Le document est retenu tel quel.

### 9.1 Canaux du socle livrés récemment et pertinents pour ce domaine

Le document parlait de v3.21.0 en bloc. Le détail des `CHANGELOG.md`, pour les seuls paquets que ce
domaine consomme ou devrait consommer :

| Paquet | Dernière version | Ce qui a bougé, et pourquoi ça compte ici |
|---|---|---|
| `zcrud_screen` | **3.14.0 (2026-08-24)** | `ZCrudScreen.beforeSubmit` (`(values, original) → map`, appelé après validation avant décodage, sur création/édition/duplication). Le domaine n'importe **`ZCrudScreen` nulle part** (§ 5.1, grep négatif) : le canal est inconnu de l'hôte. 3.8.0 documente `entityFor` + la tuile typée par layout. |
| `zcrud_responsive` | **3.19.0 (2026-08-24)** | Contrat de poignée honoré par le renderer par défaut (glissement immédiat, sans appui long), `dragPreviewWrapper`, zone sensible couvrant toute la cible. C'est exactement la mécanique que D1 réécrit quatre fois à la main (`ReorderableGridView.count`). |
| `zcrud_study` | 3.6.0 (2026-08-23) / **3.3.0 (2026-08-21)** | Le calculateur de teinte lisible est **remonté dans `zcrud_core`**, barrel ré-exporté, sans rupture. Pertinent pour la particularité n° 8 (couleur brute de dossier au contraste 1.28–2.13). |
| `zcrud_document` | **3.3.1 (2026-08-21)** | La barre d'annotation consomme le calculateur de contraste unique du cœur, rendu inchangé mesuré (0.0 près sur 1 257 couleurs / 5 028 couples). Face aux **3 349 l** de visionneuse maison (§ 6), jamais consommée pour cela. |
| `zcrud_menu` | 0.93.0 (2026-08-13) | Cible de D4 (5 menus, 831 l). Un seul jumeau écrit, et **inatteignable** (§ 2.4). |
| `zcrud_ui_kit` | 2.4.0 (2026-08-17) | `ZPageScaffold` / `ZAppBarSearchConfig`, cible de `DynamicSearcheableAppBar` (372 l). |
| `zcrud_note` | 0.86.0 | **Aucune livraison depuis le chantier documentation** — le seul paquet du lot resté immobile. |

⚠️ Ce tableau lit les `CHANGELOG.md` du socle, **pas** le code de l'hôte : il dit ce qui est
disponible, jamais que l'hôte pourrait l'adopter sans travail. La confrontation reste à faire.
