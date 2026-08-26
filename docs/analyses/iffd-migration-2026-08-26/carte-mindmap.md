# Carte du domaine « Cartes mentales » — IFFD

**Relevé du 2026-08-26.** Dépôt hôte `/home/zakarius/DEV/iffd`, lu en LECTURE SEULE.
IFFD est épinglé sur **zcrud `v3.21.0`** (`pubspec.yaml:308`, 48 entrées `ref: v3.21.0`).
Tout constat ci-dessous a été remesuré sur disque ce jour ; le relevé
`docs/analyses/iffd-migration-2026-08-25/` n'a servi à rien ici (il ne contient
aucune carte mindmap).

---

## 0. Périmètre mesuré

### 0.1 Le périmètre demandé

| Répertoire | Fichiers `.dart` | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/mindmap/` | 17 | 4 679 |
| `lib/src/features/mindmap/` | 1 | **0** |
| **Total** | **18** | **4 679** |

`lib/src/features/mindmap/mindmap_module.dart` est un fichier **de 0 octet**
(`ls -la` : `0 Feb 17 2026`). Les cinq répertoires
`lib/src/features/mindmap/{pages,providers,widgets}` et
`lib/src/presentation/features/mindmap/{controllers,pages}` sont **vides**
(`ls -A` ne rend rien pour chacun). Le domaine n'a donc **ni page ni contrôleur
propres** : tout est widget, dialogue ou adaptateur.

Détail du périmètre :

| Fichier | Lignes | Rôle |
|---|---:|---|
| `widgets/graphite_editor_widget.dart` | 946 | Éditeur outline legacy (liste à niveaux) + `MesuredRichTextWidget` + peintre de lignes d'arbre |
| `widgets/folder_mindmap_editor.dart` | 879 | Aiguilleur d'écran : outline (graphite) **ou** canevas `FlowChart` ; menus star-menu ; enum `MindmapViewer` |
| `zcrud/mindmap_zcrud_mapper.dart` | 488 | Mapper `MindmapModel` ⇄ `ZMindmap` (présentation) |
| `widgets/graphite_mindmap_viewer.dart` | 455 | Visualiseur graphe `graphite` (lecture) + phase de mesure des nœuds |
| `dialogs/mindmap_zcrud_edition.dart` | 308 | Jumeau porté du formulaire titre/description |
| `widgets/text_menu.dart` | 273 | Menu « style du texte » / « modifier le contenu » d'un élément flow-chart |
| `dialogs/mindmap_dialog_widgets.dart` | 235 | `MindmapActionsDialogWidget` (feuille d'actions) |
| `zcrud/mindmap_outline_zcrud.dart` | 184 | Jumeau porté de l'éditeur outline (`ZMindmapOutlineEditor`) |
| `dialogs/mindmap_dialogs.dart` | 179 | 3 fonctions d'ouverture : édition, visualiseur, actions |
| `widgets/element_settings_menu.dart` | 174 | Menu de propriétés d'un élément flow-chart (couleurs, épaisseur, élévation) |
| `zcrud/mindmap_rich_reader_zcrud.dart` | 166 | Fabrique unique du lecteur riche porté (`ZMarkdownReader`) |
| `zcrud/zcrud_mindmap_view.dart` | 148 | `ZcrudMindmapView` + `MindmapViewerSwitch` (aiguillage strangler fig) |
| `zcrud/text_menu_zcrud_edition.dart` | 126 | Jumeau porté du champ « Texte » d'un élément |
| `zcrud/mindmap_zcrud_flag.dart` | 42 | Flag du visualiseur |
| `widgets/hooks_web.dart` | 36 | Sauver/charger un dashboard, choisir une image (web) |
| `widgets/hooks_mobile.dart` | 27 | Idem (mobile/desktop) |
| `mindmap.dart` | 13 | Barrel |
| `../../features/mindmap/mindmap_module.dart` | 0 | **vide** |

### 0.2 Ce que j'ai inclus AU-DELÀ du périmètre

Trois fichiers **entièrement** dédiés au domaine vivent ailleurs :

| Fichier | Lignes | Rôle |
|---|---:|---|
| `lib/src/data/repositories/z_backed_mindmap_repository.dart` | 806 | Cutover W5 : mapper sans perte + port `ZMindmapDataPath` + impl Firestore + dépôt |
| `lib/src/domain/models/mindmap_model.dart` | 415 | `MindmapNode` + `MindmapModel` |
| `lib/src/domain/repositories/folder_mindmap_repository.dart` | 52 | Port + extension de requêtes dossier/matière |

**Total « domaine dédié » : 21 fichiers, 5 952 lignes.**

Et **87 fichiers `.dart` de `lib/` mentionnent `mindmap`**
(`grep -ril 'mindmap' lib --include='*.dart' | wc -l` → 87), dont les gros
consommateurs partagés que j'ai lus : `folder_study_tools_page.dart` (2 265),
`folder_details_page.dart` (2 037), `folder_documents_actions_dialog_widget.dart`
(1 804), `popup_menu_helpers.dart` (1 016), `chatbot_conversation_screen.dart`
(5 356), `explain_ai_page.dart` (812), `smartnote_actions_dialog_widget.dart` (417),
`valuation_tool_model_actions_dialog_widget.dart` (823),
`study_tools_zcrud_adapter.dart` (962), `notebook_artifact_*_iffd.dart`.

### 0.3 Tests

8 fichiers, **3 995 lignes de Dart** (+ 1 fixture JSON de 108 lignes) :

| Fichier | Lignes |
|---|---:|
| `test/characterization/mindmap_documents_roundtrip_test.dart` | 1 284 |
| `test/w3/mindmap_zcrud_mapper_test.dart` | 525 |
| `test/w7g/mindmap_zcrud_test.dart` | 522 |
| `test/w7g/mindmap_edition_legacy_test.dart` | 464 |
| `test/w3/zcrud_mindmap_view_test.dart` | 357 |
| `test/qa-w2/mindmap_roundtrip_test.dart` | 325 |
| `test/m0/mindmap_rich_reader_zcrud_test.dart` | 315 |
| `test/m0/mindmap_element_text_zcrud_test.dart` | 203 |

---

## 1. Ce que le domaine sait faire (en termes d'utilisateur)

1. **Écrire une carte mentale en liste indentée.** Ajouter un nœud, l'indenter,
   le désindenter, le réordonner par glisser, le supprimer, éditer son titre et
   son contenu en markdown. Sept niveaux au maximum (`_maxLevel = 6`,
   `graphite_editor_widget.dart:38`).
2. **Dessiner une carte mentale sur un canevas libre** (branche flow-chart) :
   poser des losanges, rectangles, ellipses, parallélogrammes, hexagones et
   boîtes de stockage, les relier par des flèches (segmentée / courbée /
   rectangulaire, avec tension réglable), les redimensionner, les colorer, les
   déplacer, tout supprimer, recentrer la vue
   (`folder_mindmap_editor.dart:239-663`).
3. **Lire une carte comme un graphe auto-agencé**, avec zoom/pan
   (`InteractiveViewer`, échelle 0,1 → 3), couleur de branche par niveau et
   style de trait par profondeur (plein / pointillé / tirets / tiret-point)
   (`graphite_mindmap_viewer.dart:383-425`).
4. **Lire du markdown + LaTeX dans chaque nœud** : gras, italique, titres,
   citations, liens, tableaux, formules `$…$` — titre ET contenu
   (`graphite_mindmap_viewer.dart:156-198`, `graphite_editor_widget.dart:569-609`).
5. **Prévisualiser pendant l'édition** : au-delà de 900 dp, éditeur et aperçu
   côte à côte ; en dessous, un bouton « Mode aperçu » ouvre le graphe en plein
   écran (`graphite_editor_widget.dart:202-249`).
6. **Nommer et décrire une carte** (titre requis, description multi-lignes)
   sans toucher à l'arbre (`mindmap_dialogs.dart:60-86`).
7. **Générer une carte par l'IA** depuis quatre sources :
   une **note** (`generateMindmapFromNotes`), les **pages sélectionnées d'un
   document** (`generateMindmapFromDocumentPagesContents`), un **document
   entier** (`generateMindmapFromWholeDocument`), et un **outil d'évaluation**
   (`valuation_tool_model_actions_dialog_widget.dart:159`). Le résultat s'ouvre
   immédiatement dans l'éditeur, avant tout enregistrement.
8. **Générer une carte depuis une explication IA** (`explain_ai_page.dart:496`)
   et **depuis un message de conversation** — la carte devient alors un
   **artefact du message** (`chatbot_conversation_screen.dart:607`,
   `notebook_capabilities_iffd.dart:488`).
9. **Ranger une carte** : la déplacer vers un autre dossier / sous-dossier /
   matière, la réordonner dans sa section, la supprimer après confirmation
   (`mindmap_dialog_widgets.dart:140-230`, `popup_menu_helpers.dart:535-608`).
10. **Voir ses cartes** dans le hub de contenu d'un dossier, la page d'outils
    d'étude, la page d'une matière, et compter celles d'un dossier
    (`countFolderMindmaps`) ou d'une matière (`countSubjectMindmaps`).
11. **Exporter/importer un dashboard flow-chart en JSON** — code présent
    (`hooks_web.dart`, `hooks_mobile.dart`) mais **aucun appelant** : voir §8.

---

## 2. Écrans et dialogues

| Surface | Fichier:ligne | Lignes | Ce qu'elle porte | Jumeau porté | Drapeau |
|---|---|---:|---|---|---|
| Éditeur outline (arbre) | `widgets/graphite_editor_widget.dart:22` | ~750 | Liste réordonnable + formulaire de nœud (2 champs `inlineMarkdown`) + rendu riche + aperçu | `zcrud/mindmap_outline_zcrud.dart:110` (`MindmapOutlineZcrud`) | `mindmapOutline` — famille **données**, défaut `false` |
| Canevas flow-chart | `widgets/folder_mindmap_editor.dart:148-877` | ~730 | Graphe libre `FlowChart` + 3 star-menus | **aucun** | — |
| Visualiseur graphe | `widgets/graphite_mindmap_viewer.dart:48` | ~410 | Lecture seule, zoom/pan, mesure hors écran des nœuds | `zcrud/zcrud_mindmap_view.dart:41` (`ZcrudMindmapView`) | `mindmapViewer` — famille **comportement**, défaut `false` |
| Lecteur riche d'un nœud | `widgets/graphite_editor_widget.dart:769` (`MesuredRichTextWidget`) + `graphite_mindmap_viewer.dart:156/178` | ~120 | Markdown + LaTeX + tableaux | `zcrud/mindmap_rich_reader_zcrud.dart:138` | `mindmapRichReader` — famille **rendu**, défaut `false` |
| Formulaire titre/description | `dialogs/mindmap_dialogs.dart:60-86` (inline `DynamicEditionScreen`) | 27 | 2 champs | `dialogs/mindmap_zcrud_edition.dart:199` (`MindmapZcrudEditionScreen`) | `mindmapEdition` — famille **comportement**, défaut `false` |
| Champ « Texte » d'un élément flow-chart | `widgets/text_menu.dart:55-81` | 27 | 1 champ multi-ligne | `zcrud/text_menu_zcrud_edition.dart:113` | `mindmapElementText` — famille **comportement**, défaut `false` |
| Feuille d'actions d'une carte | `dialogs/mindmap_dialog_widgets.dart:20-235` | 216 | 4 tuiles : modifier détails / éditer / déplacer / supprimer | **aucun** | — |
| Menu contextuel d'une carte (grille) | `core/widgets/popup_menu_helpers.dart:492-609` | 118 | Les **mêmes 4 actions**, en `PopupMenu` | **aucun** | — |
| Menu de propriétés d'élément | `widgets/element_settings_menu.dart:9` | 166 | Couleur de fond, épaisseur de bordure, élévation, couleur de bordure | **aucun** | — |
| Menu « Style du texte » | `widgets/text_menu.dart:20` (branche `styleOnly`) | ~180 | Couleur, taille, gras, alignement du texte d'un élément | **aucun** | — |
| Formulaire d'édition d'un nœud | `widgets/graphite_editor_widget.dart:419-473` (inline `DynamicEditionScreen`) | 55 | 2 champs `inlineMarkdown` (`title`, `content`) | **aucun** | — |
| État vide de l'éditeur | `widgets/graphite_editor_widget.dart:279-337` | 59 | Illustration + « Aucun noeud » + bouton « Ajouter un noeud » | **non porté** (le jumeau ne passe pas `emptyTitle/emptyMessage/emptyActionLabel`) | — |

**Les cinq drapeaux mindmap valent tous `false` par défaut** : aucun chemin porté
n'est actif en production. Ils sont recensés au registre
`lib/src/presentation/shared/zcrud/z_qa_flags.dart:586-665` (5 entrées sur 53) et
publiés dans `docs/qa-plan-comparaison-legacy-zcrud.md` (§ `mindmapRichReader`
l.146, `mindmapEdition` l.360, `mindmapElementText` l.369, `mindmapViewer` l.378,
`mindmapOutline` l.506).

Fichiers `*_zcrud_edition.dart` / `*_zcrud.dart` du domaine : **6**
(`mindmap_zcrud_edition.dart`, `text_menu_zcrud_edition.dart`,
`mindmap_outline_zcrud.dart`, `mindmap_rich_reader_zcrud.dart`,
`zcrud_mindmap_view.dart`, `mindmap_zcrud_mapper.dart`) — **1 126 lignes**.

---

## 3. Modèles et persistance

### 3.1 Entités

`lib/src/domain/models/mindmap_model.dart` (415 lignes) :

- **`MindmapNode`** (`:13-99`) — `id`, `title`, `content`, `outputs`
  (récursif), `size`, `level`, `edgeColor`, `resizable`. C'est un
  **`ChangeNotifier` mutable** (`with ChangeNotifier`, `:13`), pas un value
  object : `level` et `outputs` sont réassignés en place par l'éditeur legacy
  (`graphite_editor_widget.dart:64`, `:77`).
- **`MindmapModel extends FolderContentModel with ChangeNotifier`**
  (`:101-415`, annoté `// ignore: must_be_immutable`) — `id`, `subjectId`,
  `folderId`, `subFolderId`, `creatorId`, `createdAt`, `title`, `description`,
  `nodes`, `dashboard` (type `Dashboard` de `flutter_flow_chart`),
  `mindmapViewer`.
- **`rootedNodes()`** (`:127-134`) : une forêt à N racines est présentée sous une
  **racine synthétique** portant `title`/`description`.
- **`graphiteNodes()`** (`:163-207`) : aplatit l'arbre et **attribue une couleur
  de branche pseudo-aléatoire** (`Random()` non semé, mélangé à une palette de
  10 couleurs par `Color.lerp(levelColor, randomColor, 0.5)`). La couleur d'un
  nœud sans `edgeColor` persisté **change donc à chaque rendu**.

### 3.2 Sérialisation

- `toMap`/`fromMap`/`toJson`/`fromJson` **écrits à la main**, camelCase
  (`'mindmapViewer'`, `'createdAt'`), avec des clés plates `"size.width"` /
  `"size.height"`.
- **Lecture défensive réelle**, corrigée par deux correctifs datés dans le
  code : `resizable` retombe sur `true` si absent ou non booléen (`:92`, note
  `B-2`), et le `dashboard` est parsé **dans** un `try/catch` avec un second
  `try` de reconstruction manuelle élément par élément (`:213-354`, note
  `B-11`) — 141 lignes de désérialisation défensive pour ce seul champ.
- `createdAt` accepte `Timestamp`, `int` epoch, ou retombe sur `DateTime.now()`
  (`:369-375`).
- `props` (`equatable`) inclut `dashboard` et `nodes` (`:392-405`).

### 3.3 Dépôts — deux chemins concurrents derrière un flag

| Chemin | Fichier:ligne | Statut |
|---|---|---|
| **Legacy** `FirebaseFolderMindmapRepositoryImpl` | `data/repositories/firebase_models_repositories_impls.dart:152-169` | **actif** (défaut) |
| **Porté** `ZBackedMindmapRepository` | `data/repositories/z_backed_mindmap_repository.dart:564` | inactif |

L'aiguillage : `lib/src/features/home/providers/folder_providers.dart:88-94` —
`useZcrudMindmapRepository(Ref ref) => false;`, puis
`ref.watch(useZcrudMindmapRepositoryProvider) ? ZBackedMindmapRepository() : FirebaseFolderMindmapRepositoryImpl()`.

- **Source** : Firestore, collection **`MindmapModel`**
  (`z_backed_mindmap_repository.dart:416`, `kDefaultCollection`).
- **Requêtes** : streams nus `Stream<List<MindmapModel>>`, filtrés par
  `folderId`/`subFolderId`/`subjectId` via
  `FoldersRepository.folderContentModels` / `SubjectRepository.subjectContentModels`
  (`folder_mindmap_repository.dart:11-51`). `streamByIds` découpe en lots
  (`z_backed_mindmap_repository.dart:453-471`) et fusionne les flux à la main
  (`_combine`, `:473-497`).
- **Erreurs** : **pas** de `Either<ZFailure,T>` — un type maison
  `FirestoreDataState<T>` avec les variantes `FirestoreDataCreated`,
  `FirestoreDataUpdated`, `FirestoreDataDeleted`, `FirestoreDataRestored`,
  `FirestoreDataFailed`, `FirestoreDataSuccess`
  (`z_backed_mindmap_repository.dart:615-733`). Les erreurs sont enveloppées en
  `FirebaseException` fabriquées (`_err`, `:610`).
- **Soft-delete / horodatage** : le chemin porté écrit `ZSyncMeta.kIsDeleted` /
  `ZSyncMeta.kUpdatedAt` **hors entité** (`:526-542`) ; le chemin legacy, non.
- **Cache / offline** : **aucun** dans ce domaine. `grep -rn 'Hive\|ZLocalStore'`
  sur les trois fichiers dédiés ne rend rien.

### 3.4 Le mapping vers `ZMindmap` — écrit DEUX fois

Deux mappers `MindmapModel ⇄ ZMindmap` coexistent, **par décision d'architecture
assumée et documentée dans le code** (une arête `data → presentation` serait
interdite) :

| Mapper | Fichier | Lignes | Sens | Perte |
|---|---|---:|---|---|
| `MindmapZcrudMapper` (présentation, W3) | `presentation/features/mindmap/zcrud/mindmap_zcrud_mapper.dart` | 488 | unidirectionnel (lecture) | collapse `''`/`null` |
| `ZBackedMindmapMapper` (data, W5) | `data/repositories/z_backed_mindmap_repository.dart:156-374` | 219 | bidirectionnel | sans perte (marqueurs `iffd_id`/`iffd_folder_id`/`iffd_title`) |

Les **13 clés `extra`** sont dupliquées littéralement dans les deux
(`iffd_size_width`, `iffd_size_height`, `iffd_edge_color`, `iffd_resizable`,
`iffd_legacy_level`, `iffd_subject_id`, `iffd_sub_folder_id`, `iffd_creator_id`,
`iffd_created_at`, `iffd_mindmap_viewer`, `iffd_dashboard`,
`iffd_dashboard_serialization_failed`, `iffd_title` de nœud) —
`mindmap_zcrud_mapper.dart:53-100` et `z_backed_mindmap_repository.dart:174-198`.
Le fichier data l'écrit lui-même : « **LES DEUX MAPPERS DOIVENT RESTER ALIGNÉS** »
(`:48`).

---

## 4. 🔴 LE CODE RÉPÉTÉ

### 4.1 « Réponse IA → nœuds → carte → ouvrir l'éditeur » — **7 sites, 332 lignes**

Le bloc est identique à la variable près : `normalizedJsonString(result.data)` →
`json.decode` → `Map` ⇒ un nœud / `List` ⇒ `fromMapList<MindmapNode>` → calcul
`folderId`/`subFolderId` depuis `folder?.isSubFolder` → construction d'un
`MindmapModel` avec `randomString()` → `showFolderMindmapViewer(... crud: Crud.create)`
→ `onChanged` qui appelle `.update(mindmap)` → `catch` + `logger.severe("Error generating mindmap: $data", e)`.

| # | Fichier:lignes | Lignes |
|---:|---|---:|
| 1 | `presentation/features/documents/widgets/folder_documents_actions_dialog_widget.dart:781-820` | 40 |
| 2 | `presentation/features/valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart:169-211` | 43 |
| 3 | `presentation/features/smartnotes/widgets/smartnote_actions_dialog_widget.dart:197-255` | 59 |
| 4 | `presentation/features/explain_ai/pages/explain_ai_page.dart:512-563` | 52 |
| 5 | `presentation/core/widgets/popup_menu_helpers.dart:355-392` | 38 |
| 6 | `presentation/core/widgets/popup_menu_helpers.dart:788-829` | 42 |
| 7 | `ai_assistant/screens/chatbot_conversation_screen.dart:625-682` | 58 |
| | **TOTAL** | **332** |

Preuve d'ancrage : `grep -rn 'List<MindmapNode> nodes' lib` rend **9** résultats,
dont 2 dans `mindmap_model.dart` (déclaration de champ + variable locale de
`graphiteNodes`) → **7 sites de duplication**.
`grep -rn 'MindmapNode.fromMap' lib` rend **12** résultats : 7 sites + 3 usages
internes au modèle + 2 mentions en commentaire.

**Cinq divergences déjà installées** entre ces 7 copies :
- le `description` de la carte n'est renseigné que dans 2 sites sur 7
  (`folder_documents_actions_dialog_widget.dart:802`, `popup_menu_helpers.dart:810`) ;
- le `subjectId` vaut `subject?.id` dans 3 sites, `subjectToolPage ? … : null`
  dans 3 autres, `chatController.subject?.id` dans le 7e ;
- 5 sites journalisent l'échec, 2 avalent (`catch (_) {}` —
  `explain_ai_page.dart:563`, `chatbot_conversation_screen.dart:682`) ;
- 6 sites ouvrent l'éditeur, le 7e persiste directement dans le message
  (`chatbot_conversation_screen.dart:672-681`) ;
- un site persiste par `smartLearnInstance.folderMindmapRepository` au lieu du
  provider Riverpod, avec un `TODO(Story1.9-Task6)` en clair
  (`folder_documents_actions_dialog_widget.dart:811-813`).

### 4.2 Le menu d'actions d'une carte — **2 sites, 334 lignes**

Les **mêmes 4 gestes** (modifier les détails / éditer la carte / déplacer /
supprimer avec confirmation), avec les mêmes permissions calculées par
`FolderResourceAccessService.getResourcePermissions` :

| Site | Fichier:lignes | Lignes | Forme |
|---|---|---:|---|
| 1 | `presentation/features/mindmap/dialogs/mindmap_dialog_widgets.dart:20-235` | 216 | `Column` de `Material > Opacity > ListTile` |
| 2 | `presentation/core/widgets/popup_menu_helpers.dart:492-609` | 118 | `PopupMenu` + `switch (item.menuUserInfo)` |

Ce motif n'est pas propre à la carte mentale : **8 fichiers
`*_actions_dialog_widget.dart`** (3 554 lignes au total) et **5
`build*PopupMenu`** dans le même fichier (`popup_menu_helpers.dart:186, 269,
492, 612, 667`) répètent la même mécanique pour dossier, note, carte, flashcard,
document.

### 4.3 Les formes du canevas flow-chart — **7 sites, ~166 lignes**

`folder_mindmap_editor.dart:466-631` : sept `ActionChip` qui ne diffèrent que par
`kind`, `size` et la liste de `handlers` — losange (`:466`), rectangle (`:490`),
rectangle déplaçable (`:514`), ellipse (`:537`), parallélogramme (`:561`),
hexagone (`:583`), boîte de stockage (`:607`). Chacun ~24 lignes.
`grep -c 'dashboard.addElement(' ` → **8** (7 actifs + 1 bloc image commenté).

### 4.4 Les feuilles de style du lecteur riche — **4 sites, ~73 lignes**

`graphite_mindmap_viewer.dart` : `_lecteurTitreLegacy` (`:156-175`),
`_lecteurContenuLegacy` (`:178-198`), `_lecteurTitreZcrud` (`:229-244`),
`_lecteurContenuZcrud` (`:247-262`). Quatre fabriques qui ne diffèrent que par
`fontSize` (16/15), `textScaleFactor` (1.0/0.9) et la présence de `bold`.
Plus deux montages de `MesuredRichTextWidget` (`graphite_editor_widget.dart:570`
et `:592`) qui répètent le même bloc de 22 lignes de styles.

### 4.5 Les boutons d'action d'un nœud — **4 sites, ~40 lignes**

`graphite_editor_widget.dart:476-518` : quatre `IconButton` identiques à
l'icône, au `tooltip` et au callback près (`_outdent`, `_indent`, `_addNewNode`,
`_deleteNode`), chacun avec le même
`padding: EdgeInsets.zero, constraints: BoxConstraints(minWidth: 28, minHeight: 28)`
— **cible tactile de 28 dp**, sous le plancher de 48.

### 4.6 Le réordonnancement par type de contenu — **4 sites, ~59 lignes**

`domain/repositories/folder_contents_orders_repository.dart:27-85` :
`reorderFlashcards`, `reorderDocuments`, `reorderNotes`, `reorderMindmaps` —
quatre méthodes strictement identiques sauf le nom de la clé
(`subFlashcardsIds` / `subDocumentsIds` / `subNotesIds` / `subMindmapsIds`).

### 4.7 Les mappeurs « modèle → item d'outil d'étude » — **4 sites, ~95 lignes**

`presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart:821`
(`flashcardStudyItems`), `:887` (`documentStudyItems`), `:922`
(`noteStudyItems`), `:943` (`mindmapStudyItems`) — même boucle, même filtre
`id != null`, même calcul d'`opacity`, seuls l'icône et les champs changent.
Suivis de quatre appels `zStudyToolsSection(...)` quasi identiques
(`:664`, `:710`, `:749`, `:782`).

### 4.8 Le port de génération IA déclaré trois fois, implémenté une seule

Les 3 méthodes `generateMindmapFrom*` sont déclarées au port
(`domain/repositories/ai_repository.dart:109`, `:408`, `:421`) et redéclarées
dans **trois** implémentations :

| Impl | Fichier:lignes | État |
|---|---|---|
| `IffdAiRepositoryImpl` | `data/repositories/iffd_ai_repository_impl.dart:623-640, 1266-1294, 1297-1321` | **implémentée** (72 lignes) |
| `OpenAiAiRepositoryImpl` | `data/repositories/openai_ai_repository_impl.dart:599, 615, 651` | 3 × `throw UnimplementedError()` |
| `CloudFunctionsAiRepositoryImpl` | `data/repositories/cloud_functions_ai_repository_impl.dart:426, 442, 478` | 3 × `throw UnimplementedError()` |

**6 stubs morts, ~96 lignes.** Les trois signatures font 12 à 16 lignes chacune,
recopiées 3 fois : ~130 lignes de signature.

### 4.9 La création d'une carte vide — **4 sites, ~75 lignes**

Même bloc « `MindmapModel(id: randomString(), subjectId: subjectToolPage ? … : null,
folderId: …, subFolderId: …, creatorId: …)` puis `showFolderMindmapViewer(…, crud: Crud.create,
onChanged: (m) { if (m != null) repo.update(m); })` » :

| Site | Fichier:lignes | Moteur créé |
|---|---|---|
| 1 | `presentation/features/folders/zcrud/content_hub_zcrud.dart:336-354` | `MindmapViewer.graphite` |
| 2 | `presentation/features/folders/dialogs/folder_content_add_dialog_widget.dart:340-357` | `MindmapViewer.graphite` |
| 3 | `presentation/features/folders/pages/folder_study_tools_page.dart:1983-2020` | **`MindmapViewer.flowchart`** |
| 4 | `presentation/features/folders/zcrud/notebook_artifact_actions_iffd.dart:100-129` | ouvre une carte existante (artefact de message) |

### 4.10 L'ouverture d'un visualiseur — **16 sites d'appel**

`grep -rn 'showFolderMindmapViewer' lib` rend 20 résultats : 1 déclaration
(`mindmap_dialogs.dart:124`), 1 import, 2 commentaires, et **16 appels**
répartis sur 11 fichiers. Le rappel
`onChanged: (m) { if (m != null) repo.update(m); }` est recopié à **10** d'entre
eux (`grep -rn '\.update(mindmap)\|\.update(m)'` → 10).
`folderMindmapRepositoryProvider` est lu à **28** endroits, dont 7 dans le seul
`popup_menu_helpers.dart`.

### 4.11 Le gabarit de drapeau strangler fig — **5 sites dans le domaine, 52 dans le dépôt**

Chaque fichier porté redéclare le même triplet
`const bool kXUseZcrudDefault = false;` + `final Provider<bool> xUseZcrudProvider`
+ `bool xUsesZcrud(BuildContext) => zcrudFlagValue(...)` :
`mindmap_zcrud_flag.dart:39`, `mindmap_zcrud_edition.dart:88`,
`mindmap_outline_zcrud.dart:59`, `mindmap_rich_reader_zcrud.dart:99`,
`text_menu_zcrud_edition.dart:69`.
Au dépôt entier : **52** providers de bascule
(`grep -rn 'final Provider<bool> .*UseZcrud\|.*Enabled' lib | wc -l` → 52), pour
**53** entrées `ZQaFlag` (`z_qa_flags.dart`).

### 4.12 Récapitulatif chiffré

| Duplication | Sites | Lignes |
|---|---:|---:|
| Réponse IA → carte → éditeur | 7 | 332 |
| Menu d'actions d'une carte | 2 | 334 |
| Formes du canevas flow-chart | 7 | 166 |
| Feuilles de style du lecteur riche | 4 (+2 montages) | ~117 |
| Boutons d'action d'un nœud | 4 | ~40 |
| `reorder*` par type de contenu | 4 | 59 |
| Mappeurs `*StudyItems` | 4 | ~95 |
| Signatures + stubs du port IA mindmap | 9 déclarations, 6 stubs | ~226 |
| Création d'une carte vide | 4 | ~75 |
| `onChanged → repo.update` | 10 | ~50 |
| Gabarit de drapeau | 5 (52 au dépôt) | ~60 |
| **Total mesuré** | | **~1 554** |

Soit **plus d'un quart** des 5 952 lignes du domaine dédié, sans compter les
1 016 lignes de `popup_menu_helpers.dart` ni les 3 554 lignes de feuilles
d'actions qui portent la moitié de ces copies.

---

## 5. Ce qui est DÉJÀ branché sur zcrud

`grep -rn 'package:zcrud_mindmap' lib` rend **6** résultats, dans **4** fichiers
(3 imports actifs + 3 mentions en commentaire) :

| Fichier | Symboles importés |
|---|---|
| `zcrud/mindmap_zcrud_mapper.dart:31` | barrel entier (`ZMindmap`, `ZMindmapNode`, `ZMindmapTreeOps.normalizeLevels`) |
| `zcrud/zcrud_mindmap_view.dart:20` | barrel entier (`ZMindmapView`, `ZMindmapViewMode`, `ZMindmapViewConfig`, `ZMindmapNodeCallback`) |
| `zcrud/mindmap_outline_zcrud.dart:42` | `ZMindmapNode`, `ZMindmapOutlineEditor`, `ZMindmapOutlineLabels` |
| `data/repositories/z_backed_mindmap_repository.dart:104` | `ZMindmap`, `ZMindmapNode` |

Autres paquets zcrud consommés **par le domaine** :

| Paquet | Site | Symbole |
|---|---|---|
| `zcrud_markdown` | `zcrud/mindmap_rich_reader_zcrud.dart:67`, `widgets/graphite_editor_widget.dart:5` | `ZMarkdownReader`, `ZMarkdownReaderChrome`, `ZRichTextFormulaSpec`, `ZRichTextStyleSet` |
| `zcrud_core` | `dialogs/mindmap_zcrud_edition.dart:69`, `zcrud/text_menu_zcrud_edition.dart:50` | `ZFieldSpec`, `EditionFieldType`, `ZTextConfig`, `ZValidatorSpec`, `ZFormController`, `ZEditionSubmitController`, `DynamicEdition`, `ZFailure` |
| `zcrud_screen` | `zcrud/text_menu_zcrud_edition.dart:52` | `presentFormEdition` |
| `zcrud_core` (`ZSyncMeta`) | `data/repositories/z_backed_mindmap_repository.dart:103` | `ZSyncMeta.kIsDeleted`, `kUpdatedAt` |

Au dépôt entier, **110 fichiers** importent `package:zcrud_*`
(`zcrud_core` 67 imports, `zcrud_chat_kernel` 19, `zcrud_study` 17,
`zcrud_screen` 16, `zcrud_chat` 15, `zcrud_markdown` 11, `zcrud_flashcard` 11,
`zcrud_mindmap` 6…).

**Registre de widgets** : le domaine ne déclare **aucun** `ZFieldSpec`
personnalisé au registre. Les deux formulaires portés
(`mindmapZcrudFields()`, `mindmapElementTextFields()`) déclarent leurs champs en
dur, sous `IffdZcrudScope` (`mindmap_zcrud_edition.dart:282`) — qui apporte le
défaut de casse `ucFirstLegacy`, le port numérique et le présentateur de
sélection. Le jumeau `text_menu_zcrud_edition.dart` **n'est pas** sous ce scope :
il redéclare `textTransform: ucFirstLegacy` champ par champ (`:94`), avec la
justification en tête de fichier (`:38-45`).

**Le canal `zcrud_chat` est déjà branché** : une carte mentale est un artefact
de message (`kIffdArtifactMindmap = 'mindmap'`,
`notebook_artifact_registry_iffd.dart:27`), avec son compteur de nœuds
(`iffdCountMindmapNodes`, `notebook_artifact_counts_iffd.dart:91`), son store
(`notebook_artifact_store_iffd.dart:85`), ses actions
(`notebook_artifact_actions_iffd.dart:100`) et sa génération
(`notebook_capabilities_iffd.dart:479`). C'est le **seul** chemin mindmap
d'IFFD réellement porté et actif.

---

## 6. Widgets maison qui refont ce que le socle fait

| Widget maison | Fichier:ligne | Lignes | Ce que le socle a |
|---|---|---:|---|
| `GraphiteEditorWidget` | `widgets/graphite_editor_widget.dart:22` | ~750 | `ZMindmapOutlineEditor` (802 l.) + `ZMindmapOutlineController` (302 l.) |
| `GraphiteMindmapViewer` | `widgets/graphite_mindmap_viewer.dart:48` | ~410 | `ZMindmapView` (540 l.) + `ZMindmapListView` (213 l.) + `ZMindmapNodeCard` (211 l.) |
| `MesuredRichTextWidget` | `widgets/graphite_editor_widget.dart:769` | 178 | `ZMarkdownReader` + `ZMindmapMarkdownContent` (120 l.) |
| `MeasuredSizeWidget` | `widgets/graphite_mindmap_viewer.dart:15` | 33 | inutile côté socle : `ZMindmapView` mesure via `graphite` sans phase hors écran |
| `GraphiteParentLinePainter` | `widgets/graphite_editor_widget.dart:655` | 113 | l'indentation de `ZMindmapListView` (jetons `indentStep`) |
| `MindmapPreviewWidget` | `widgets/graphite_mindmap_viewer.dart:447` | 9 | `ZMindmapView` en mode lecture |
| `MindmapActionsDialogWidget` | `dialogs/mindmap_dialog_widgets.dart:20` | 216 | `ZRowActionMenu` (`zcrud_screen`, 176 l.) / `ZActionMenu` (`zcrud_menu`) |
| `buildMindmapPopupMenu` | `core/widgets/popup_menu_helpers.dart:492` | 118 | idem |
| état vide de l'éditeur | `widgets/graphite_editor_widget.dart:279` | 59 | `ZEmptyState` (`zcrud_ui_kit`) + `emptyBuilder`/`emptyTitle` de `ZMindmapOutlineEditor` |
| `buildConfirmDialog` (36 appels au dépôt) | `core/widgets/dialog_widgets.dart` | — | `showZConfirmDialog` + `ZConfirmTone` (`zcrud_ui_kit`) |
| `MindmapZcrudMapper` + `ZBackedMindmapMapper` | 2 fichiers | 707 | rien au socle — mais **un seul** mapper suffirait si le sens des arêtes le permettait |
| `_flatList`/`_reconstructTree`/`_indent`/`_outdent`/`_onReorder` | `widgets/graphite_editor_widget.dart:51-190` | 140 | `ZMindmapTreeOps` (435 l. : add/update/delete/find/move/indent/outdent/reorder + `normalizeLevels`) |
| `renormaliserNiveaux` | `zcrud/mindmap_outline_zcrud.dart:94` | 10 | `ZMindmapTreeOps.normalizeLevels` (déjà utilisé, ailleurs, par le mapper `:160`) |
| `DashboardX.clone()` | `widgets/folder_mindmap_editor.dart:27` | 9 | — (spécifique `flutter_flow_chart`) |

---

## 7. Capacités du socle **non consommées** (v3.21.0)

Greps négatifs, exécutés sur `lib` **et** `test` d'IFFD, RC=1 (aucun résultat) :

```
$ grep -rn 'ZMindmapGenerationPort\|ZMindmapGenerationRequest\|ZMindmapSourceRef' lib test --include='*.dart' ; echo "RC=$?"
RC=1
$ grep -rn 'ZMindmapViewController\|ZMindmapViewControls\|ZMindmapViewLabels\|nodeContentBuilder\|editFieldBuilder\|ZMindmapMarkdownContent\|ZMindmapMarkdownEditField\|ZMindmapOutlineController' lib test --include='*.dart' ; echo "RC=$?"
RC=1
$ grep -rn 'ZStudyMindmapSection\|ZDefaultMindmapCard' lib test ; echo "RC=$?"
RC=1
```

| Capacité socle | Où elle vit | Ce qu'IFFD fait à la place |
|---|---|---|
| `ZMindmapGenerationPort` + `ZMindmapGenerationRequest` + `ZMindmapSourceRef` | `zcrud_study/lib/src/domain/z_mindmap_generation_port.dart` | 3 méthodes ad hoc au port `AiRepository`, 7 copies du décodage (§4.1) |
| `ZStudyMindmapSection` (393 l.) | `zcrud_study/…/z_study_mindmap_section.dart` | section maison dans `study_tools_zcrud_adapter.dart:782` |
| `ZDefaultMindmapCard` (458 l.) | `zcrud_study/…/z_default_mindmap_card.dart` | `ZDefaultNoteCard` détourné (`study_tools_zcrud_adapter.dart:793`) |
| `ZMindmapViewController` + `ZMindmapViewLabels` (`z_mindmap_view_controls.dart`, 163 l. ; classes aux l. 27 et 119) — zoom clampé, compact, plein écran, super-racine | `zcrud_mindmap` | 3 `FloatingActionButton` maison qui multiplient une `Matrix4` (`folder_mindmap_editor.dart:120-146`) |
| `ZMindmapView.nodeContentBuilder` | `zcrud_mindmap` | `ZcrudMindmapView` ne le passe pas → les nœuds portés rendent du **texte brut**, sans markdown ni LaTeX (`zcrud_mindmap_view.dart:88-94`) |
| `ZMindmapOutlineEditor.editFieldBuilder` + `ZMindmapMarkdownEditField` | `zcrud_mindmap` | `MindmapOutlineZcrud` ne le passe pas → l'édition portée d'un nœud est en texte brut (`mindmap_outline_zcrud.dart:168-181`) |
| `ZMindmapOutlineLabels.emptyTitle/emptyMessage/emptyActionLabel` + `emptyBuilder` | `zcrud_mindmap` | `kIffdMindmapOutlineLabels` (`mindmap_outline_zcrud.dart:71-83`) ne renseigne **aucun** des trois → l'état vide riche du legacy est perdu sur le chemin porté |
| `ZMindmapListView` (surface a11y) | `zcrud_mindmap` | `ZcrudMindmapView` fige `mode: ZMindmapViewMode.graph` par défaut ; aucun appelant ne demande `list` |
| `ZMindmapTreeOps` (add/move/indent/outdent/reorder) | `zcrud_mindmap` | seul `normalizeLevels` est utilisé, et seulement dans le mapper (`mindmap_zcrud_mapper.dart:160`) |
| `ZRowActionMenu` / `ZActionMenu` | `zcrud_screen` / `zcrud_menu` | 2 menus maison (§4.2) |
| `ZConfirmDialog` / `showZConfirmDialog`, `ZEmptyState`, `ZLoadingState`, `ZErrorState`, `ZContentStateView` | `zcrud_ui_kit` | `buildConfirmDialog` maison, 36 appels ; états vides ad hoc |

**CR-IFFD-67 est corrigée au socle et IFFD ne l'a pas repris.** La CR
(`docs/zcrud-change-requests.md:4785`) signalait ① les sept actions de nœud
empilées une par ligne et ② l'absence d'état vide. ① est fermé :
`_OutlineActionButton` porte désormais `widthFactor`/`heightFactor` avec la
justification en clair (`packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart:768-782`).
② est fermé aussi (`emptyBuilder` `:62/:118`, `emptyTitle`/`emptyMessage`/
`emptyActionLabel` `:363-364`, `:451-455`) — mais **l'hôte ne câble rien**.
CR-IFFD-61 (`:4156`, gap de carte, accent 4 dp, badge de compteur) porte sur
`ZStudyToolsItemCard`/`ZDefaultNoteCard`, consommés eux.

---

## 8. Ce qui est PARTICULIER à IFFD

1. **Deux moteurs de rendu dans une seule entité.** `MindmapModel.mindmapViewer`
   choisit entre `graphite` (arbre) et `flowchart` (canevas libre
   `flutter_flow_chart`). Le socle ne connaît que l'arbre : le `dashboard`
   `flutter_flow_chart` voyage **opaque** dans `extra['iffd_dashboard']`, avec un
   marqueur de perte `iffd_dashboard_serialization_failed` si `toMap()` lève
   (`mindmap_zcrud_mapper.dart:96-100`, `z_backed_mindmap_repository.dart:336-347`).
2. **Le même bouton « ajouter une carte » ne crée pas le même objet.** Le hub de
   contenu (`content_hub_zcrud.dart:343`) et la feuille d'ajout
   (`folder_content_add_dialog_widget.dart:347`) créent une carte `graphite` ;
   l'état vide de la section « cartes mentales » de la page d'outils d'étude
   crée une carte **`flowchart`** et la **titre automatiquement**
   `"<dossier|matière> yyyy-MM-dd"` (`folder_study_tools_page.dart:2004-2012`).
   ⚠️ Un `grep 'MindmapViewer.flowchart'` naïf **rate ce site** : le nom d'enum
   y est coupé sur trois lignes.
3. **La racine synthétique.** Une carte à plusieurs racines est affichée sous une
   racine artificielle portant `title`/`description`
   (`mindmap_model.dart:127-134`). Le mapper la reproduit
   (`useLegacyRooting`, `syntheticRootId = '__iffd_mindmap_synthetic_root__'`,
   `mindmap_zcrud_mapper.dart:105-108`) — mais **l'éditeur porté la désactive
   volontairement** pour ne pas faire éditer un nœud fantôme
   (`mindmap_outline_zcrud.dart:125-129`).
4. **Les couleurs de branche sont tirées au sort à chaque rendu.**
   `graphiteNodes()` (`mindmap_model.dart:163-207`) mélange une palette de 10
   couleurs indexée par niveau avec un `Random()` non semé quand `edgeColor` est
   nul. Deux ouvertures de la même carte ne donnent pas les mêmes couleurs.
   Incompatible frontalement avec FR-26 (couleurs par thème).
5. **Le style de trait encode la profondeur.** Niveau 1 → pointillé, 2 → tirets,
   3 → tiret-point, sinon plein (`graphite_mindmap_viewer.dart:400-414`).
6. **Sept niveaux, pas plus** (`_maxLevel = 6`,
   `graphite_editor_widget.dart:38`), avec une palette de 7 couleurs de niveau
   (`_getColorForLevel`, `:324-336`).
7. **Les permissions sont indexées par ANNÉE ACADÉMIQUE.** Le nom de ressource
   effectif est `"MindmapModel${accademicYear.id}"`
   (`permission_helpers.dart:83`, `folder_resource_access_service.dart:170`).
   Le droit de générer une carte par IA est un verbe CRUD à part entière —
   `Crud.aiMindMap("Carte mentale avec l'IA", "Carte mentale", true)`
   (`domain/security/crud.dart:22`).
8. **La carte mentale est un artefact de MESSAGE.** `ChatbotMessage.mindmap` est
   une chaîne JSON de `MindmapModel` (`ai_assistant/models/chatbot_message.dart:134`),
   et `ChatbotMessageType.mindmap` existe (`:11`). Le compteur affiché sur le
   bouton compte les nœuds du **premier** nœud seulement
   (`notebook_artifact_counts_iffd.dart:107-120`).
9. **La phase de mesure hors écran.** Le visualiseur monte **tous** les nœuds
   `Offstage` simultanément pour relever leur taille avant de dessiner le graphe
   (`graphite_mindmap_viewer.dart:332-359`), avec un `CircularProgressIndicator`
   pendant. Le corpus compte **9 093 valeurs de nœuds**
   (chiffre relevé par l'hôte, `z_iffd_rich_text_codec.dart:9`), et chaque nœud
   monte **deux** lecteurs riches : c'est le pire cas de coût identifié pour le
   portage du lecteur (`z_qa_flags.dart:645-655`).
10. **Le contenu des nœuds est du markdown, jamais du Delta.** Le codec
    `IffdRichTextCodec.markdown` est imposé explicitement, parce que le défaut
    du socle (`ZDeltaCodec`) rendrait chaque nœud vide
    (`mindmap_rich_reader_zcrud.dart:22-28`).
11. **Trois divergences de rendu déclarées et NON corrigées** entre legacy et
    porté, consignées dans le registre de QA
    (`z_qa_flags.dart:657-665`) : la citation perd le `black87` figé, le lien
    garde la couleur de rôle du thème, l'outline continue de neutraliser
    `##`/`###`.
12. **Import/export de dashboard sans appelant.** `saveDashboard`,
    `loadDashboard` et `pickImageBytes` sont déclarés en double
    (`hooks_web.dart` / `hooks_mobile.dart`, 63 lignes) et exportés par le
    barrel (`mindmap.dart:7-8`). Preuve d'absence d'appelant :

    ```
    $ grep -rn 'saveDashboard\|loadDashboard\|pickImageBytes' lib test --include='*.dart'
    hooks_mobile.dart:9,11,15,17,21     (déclarations + appels internes à Dashboard)
    hooks_web.dart:9,21,24,30           (idem)
    folder_mindmap_editor.dart:634      //     final bytes = await pickImageBytes();
    ```

    10 résultats : 9 dans les deux fichiers de hooks eux-mêmes, et **1 en
    commentaire**. Le seul consommateur potentiel, l'entrée « Ajouter une
    image » du menu de dashboard, est commenté
    (`folder_mindmap_editor.dart:626-652`).

---

## 9. Ce que ce relevé n'a pas pu établir

- Les **volumes réels en base** (nombre de cartes, de nœuds, part de cartes
  `flowchart`) : aucune donnée Firestore n'est lisible depuis le dépôt. Le seul
  chiffre de corpus disponible (9 093 valeurs de nœuds) est une **affirmation de
  l'hôte** recopiée d'un commentaire, non remesurée ici.
- Le **coût réel du portage du lecteur riche** : la QA le décrit comme « à
  tester à la montre » (`z_qa_flags.dart:645`), aucune mesure n'existe au dépôt.
- Aucun test n'a été lancé, dans aucun dépôt.

---

## 10. Annexe — contre-vérification par sondage (2026-08-26, second passage)

Ce relevé a été écrit par un premier passage puis **re-échantillonné** sur disque.
Neuf affirmations chiffrées ont été remesurées ; **huit confirmées, une corrigée**.

| Affirmation | Remesure | Verdict |
|---|---|---|
| `presentation/features/mindmap/` = 17 fichiers / 4 679 lignes | `find … -name '*.dart' \| wc -l` → 17 ; `cat \| wc -l` → 4 679 | ✅ |
| `features/mindmap/mindmap_module.dart` vide | `ls -la` → `0 Feb 17 2026` ; 1 seul fichier sous l'arbre | ✅ |
| 3 fichiers dédiés hors périmètre = 1 273 lignes (total domaine 5 952) | `wc -l` → 806 + 415 + 52 = 1 273 ; 4 679 + 1 273 = 5 952 | ✅ |
| 7 sites de duplication « réponse IA → carte » | `grep -rn 'List<MindmapNode> nodes' lib` → 9 (dont 2 internes au modèle) | ✅ |
| 5 drapeaux mindmap sur 53 | `grep -c 'ZQaFlag('` → 53 ; ids mindmap aux l. 586, 592, 611, 622, 632 | ✅ |
| 6 imports `package:zcrud_mindmap` | `grep -rn … \| wc -l` → 6 | ✅ |
| 20 occurrences `showFolderMindmapViewer` | `grep -rn … \| wc -l` → 20 | ✅ |
| IFFD épinglé sur zcrud v3.21.0, 48 entrées | `grep -c 'ref: v3.21.0' pubspec.yaml` → 48 | ✅ |
| Trois greps négatifs du §7 (`ZMindmapGenerationPort…`, `ZMindmapViewController…`, `ZStudyMindmapSection…`) | rejoués sur `lib test` → **RC=1** chacun, aucune sortie | ✅ |
| **`ZMindmapViewControls` (163 l.)** | `grep -rn 'ZMindmapViewControls' packages/ --include='*.dart'` → **aucune sortie**. Le fichier `z_mindmap_view_controls.dart` fait bien 163 l. mais déclare `ZMindmapViewController` (l. 27) et `ZMindmapViewLabels` (l. 119) | ❌ **corrigé au §7** |

Onze symboles du socle cités au §7 ont été localisés à leur fichier
(`ZMindmapGenerationPort`, `ZMindmapSourceRef` → `zcrud_study/…/z_mindmap_generation_port.dart` ;
`ZStudyMindmapSection`, `ZDefaultMindmapCard` → `zcrud_study/…/presentation/` ;
`ZMindmapViewController`, `ZMindmapMarkdownContent`, `ZMindmapMarkdownEditField`,
`ZMindmapTreeOps` (435 l.), `ZMindmapListView`, `ZMindmapOutlineController` →
`zcrud_mindmap/…`), et `z_mindmap_outline_editor.dart` mesure bien **802** lignes.

Aucun test n'a été lancé, dans aucun dépôt. Aucun fichier hors de ce répertoire
n'a été écrit.
