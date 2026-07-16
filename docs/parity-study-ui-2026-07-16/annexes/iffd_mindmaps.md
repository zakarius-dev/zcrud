# Reconnaissance — Mindmaps IFFD (affichage + édition)

Périmètre : `lib/src/domain/models/mindmap_model.dart`, `lib/src/domain/repositories/folder_mindmap_repository.dart`,
`lib/src/presentation/features/mindmap/**`, `lib/src/features/mindmap/mindmap_module.dart`.

## Vue d'ensemble architecturale

IFFD a **deux modes de rendu/édition de mindmap distincts**, sélectionnés par l'enum
`MindmapViewer { graphite, flowchart }` (`folder_mindmap_editor.dart:20`), stocké sur le modèle
(`MindmapModel.mindmapViewer`, défaut `graphite`) :

1. **Mode `graphite`** (par défaut) — structure **arborescente stricte** (nœuds `title`/`content` avec
   `outputs` = enfants). Édition via une **liste outline réordonnable** (`GraphiteEditorWidget`,
   *pas* d'édition directe sur le graphe). Affichage/preview via `GraphiteMindmapViewer`, qui utilise
   le **package `graphite` (^1.2.1)** en pur **moteur de layout + rendu de graphe orienté** (auto-layout,
   pas de drag manuel des nœuds).
2. **Mode `flowchart`** — diagramme **libre** (freeform) basé sur le package **`flutter_flow_chart`
   (^4.1.1)** : `Dashboard`/`FlowElement` avec formes multiples (rectangle, diamant, ellipse, hexagone,
   parallélogramme, storage), connexions dessinées à la main (drag depuis un `Handler`), style d'arête
   configurable (segmenté/courbé/rectangulaire, tension), déplaçable/redimensionnable/connectable par
   élément, sauvegarde/chargement JSON sur disque (mobile) ou téléchargement (web).

Les deux modes partagent le même modèle `MindmapModel` (le champ `dashboard: Dashboard?` du flowchart
coexiste avec `nodes: List<MindmapNode>` du mode graphite) et le même repository CRUD
(`FolderMindmapRepository`).

---

## Structure de données — nœud / arête / modèle

### `MindmapNode` (mode graphite — arbre, `mindmap_model.dart:13-97`)

| Champ | Type | Rôle |
|---|---|---|
| `id` | `String?` | identifiant, auto-généré (`randomString()`) si absent |
| `title` | `String?` | titre du nœud — supporte markdown/LaTeX inline (rendu via `RichTextReaderScreen`) |
| `content` | `String?` | contenu détaillé du nœud — même moteur markdown/LaTeX |
| `outputs` | `List<MindmapNode>` | **enfants directs** (structure arborescente native, pas de liste d'arêtes séparée) |
| `size` | `Size` | taille (persistée mais recalculée dynamiquement par mesure du widget au rendu) |
| `level` | `int` | profondeur dans l'arbre (calculée, pas saisie par l'utilisateur) — max 6 (7 niveaux, 0-6) dans l'éditeur outline |
| `edgeColor` | `Color?` | couleur de l'arête sortante vers les enfants — auto-générée par niveau + variation aléatoire si absente |
| `resizable` | `bool` | (default `true`, peu exploité) |

`ChangeNotifier` mixin (mais pas vraiment exploité pour la réactivité fine — le controller parent
réassigne des copies). `toMap/fromMap` maison (pas de générateur), désérialisation défensive
(`edgeColor` accepte `int` ARGB ou `Color`; `size.width/size.height` en clés plates).

Pas d'arêtes explicites typées — la relation est purement `parent.outputs → enfant`. `MindmapModel.graphiteNodes()`
aplatit l'arbre en liste avec `level` recalculé et couleur combinée (couleur de niveau + teinte aléatoire,
`Color.lerp`) pour l'affichage graphite.

### `MindmapModel` (racine, `mindmap_model.dart:100-404`)

| Champ | Rôle |
|---|---|
| `id/subjectId/folderId/subFolderId/creatorId/createdAt` | hérités de `FolderContentModel` (contenu de dossier, ACL) |
| `title`, `description` | méta de la carte |
| `nodes: List<MindmapNode>` | racine(s) de l'arbre (mode graphite) |
| `dashboard: Dashboard?` | diagramme freeform complet (mode flowchart) — sérialisation très défensive/artisanale (parsing manuel imbriqué de `elements`, `next`/arêtes, `arrowParams`, `pivots`, `gridBackgroundParams`) |
| `mindmapViewer: MindmapViewer` | `graphite` \| `flowchart`, persisté (`.name`) |

`rootedNodes()` : si `nodes.length > 1`, crée une racine synthétique enveloppant tous les nœuds
top-level (avec `title`/`description` du modèle) — garantit un graphe à racine unique pour `graphite`.

### Flowchart : `FlowElement` (package `flutter_flow_chart`)

Nœud freeform avec `kind` (`ElementKind.rectangle/diamond/oval/parallelogram/hexagon/storage/image`),
`position`, `size`, `text`, style (`backgroundColor`, `borderColor`, `borderThickness`, `elevation`,
`textColor`, `textSize`, `textIsBold`), `handlers` (points d'ancrage: `topCenter/bottomCenter/leftCenter/rightCenter`),
flags `isDraggable/isResizable/isConnectable/isEditingText`. Arêtes = connexions entre `Handler`s avec
`ArrowStyle` (`segmented` avec `tension`, `curve`, `rectangular`), gérées par `Dashboard`
(`addElement`, `removeElement`, `removeElementConnection(s)`, `dissectElementConnection` → pivots,
`setArrowStyleByHandler`, `setElementDraggable/Resizable/Connectable/EditingText`).

---

## Inventaire des fonctionnalités

### M1 — Éditeur outline arborescent (mode graphite)
1. **Rôle** : édition de la mindmap comme une **liste indentée réordonnable** (façon plan/outline), pas
   un canvas graphique — chaque ligne = un nœud avec indentation visuelle = profondeur.
2. **Fichier** : `widgets/graphite_editor_widget.dart`, classe `GraphiteEditorWidget`
   (+ `_GraphiteEditorWidgetState`).
3. **Structure** : maintient une `_flatList` (aplatissement DFS de l'arbre `MindmapNode.outputs`) +
   `_parentMap` ; reconstruit l'arbre (`_reconstructTree`) à partir de `level` après chaque mutation.
4. **Édition** : `_addNewNode` (insertion après l'index courant, hérite le niveau du voisin),
   `_deleteNode`, `_updateNode` (titre/contenu via dialog), `_indent`/`_outdent` (± niveau, plafonné à
   `_maxLevel=6`), `_onReorder` (drag-and-drop via `ReorderableListView.builder`, avec recalage
   automatique du niveau si le nœud déplacé dépasse `prevNode.level + 1`).
5. **Affichage** : rendu textuel avec un `CustomPainter` (`GraphiteParentLinePainter`) dessinant les
   traits de connexion parent→enfant (lignes verticales/horizontales arrondies façon arborescence de
   fichiers), couleur par niveau (palette fixe de 7 couleurs). Sur écran large (>900px), split-view
   éditeur (gauche) + `MindmapPreviewWidget` (droite, rendu graphite live) ; sur petit écran, bouton
   bascule vers un dialog plein écran d'aperçu.
6. **Spécial** : bouton `visibility` pour prévisualiser en plein écran sur mobile ; bouton `save`.
7. **Couplage** : GetX (`showPushedDialog`), `DynamicEditionScreen`/`DynamicFormField` (data_crud IFFD,
   type `inlineMarkdown`) pour le dialog d'édition titre/contenu d'un nœud, `RichTextReaderScreen` pour
   le rendu markdown/LaTeX du titre et du contenu.

### M2 — Édition du contenu d'un nœud (dialog markdown)
1. **Rôle** : bouton « Editer » sur chaque nœud ouvre un formulaire dédié titre + contenu.
2. **Fichier** : `graphite_editor_widget.dart:420-465` (dans `_buildNodeTile`).
3. **Structure** : deux champs `DynamicFormField` type `EditionFieldTypes.inlineMarkdown` (titre 2
   lignes, contenu 5-10 lignes) — édition markdown inline (pas un éditeur riche Quill plein écran).
4. **Édition** : validation `required` sur le titre ; retour Map → `_updateNode`.
5. **Affichage** : rendu du résultat via `MesuredRichTextWidget`/`RichTextReaderScreen` (markdown +
   LaTeX, styles `strong`/`em` personnalisés rose/bleu).
6. **Spécial** : —
7. **Couplage** : `DynamicEditionScreen` (data_crud), `RichTextReaderScreen` (moteur markdown/LaTeX
   partagé avec le reste de l'app).

### M3 — Rendu graphe orienté auto-layout (viewer graphite)
1. **Rôle** : affichage du graphe complet en canvas pannable/zoomable avec disposition automatique
   (pas de positionnement manuel).
2. **Fichier** : `widgets/graphite_mindmap_viewer.dart`, classe `GraphiteMindmapViewer` (+
   `MindmapPreviewWidget` wrapper stateless).
3. **Structure** : convertit `MindmapModel.graphiteNodes()` (liste aplatie avec `level`/`edgeColor`) en
   `List<NodeInput>` du package `graphite` (chaque `NodeInput` a `id`, `next: List<EdgeInput>` = ses
   enfants, `size: NodeSize`).
4. **Édition** : **aucune** — viewer pur (lecture seule, y compris en mode preview intégré à l'éditeur).
5. **Affichage** : `DirectGraph` (package `graphite`) avec `orientation` dynamique
   (`MatrixOrientation.Vertical` si largeur>hauteur, sinon `Horizontal`), `centered: true`,
   `nodeBuilder` custom (carte avec bordure colorée, titre+contenu markdown/LaTeX rendus via
   `RichTextReaderScreen`), `styleBuilder` pour le style de trait par arête (`LineStyle.dotted` niveau
   1, `dashed` niveau 2, `dashDotted` niveau 3, `solid` sinon ; couleur = `edgeColor` du nœud parent,
   `borderRadius: 40`). Zoom/pan via `InteractiveViewer` (`minScale 0.1`/`maxScale 3` au niveau du
   viewer, `minScale .1`/`maxScale 5` au niveau de `DirectGraph`), `TransformationController` partageable
   (boutons zoom in/out/recentrer dans `FolderMindmapEditor`).
6. **Spécial** : **phase de mesure préalable** — chaque nœud est d'abord rendu `Offstage` pour mesurer
   sa taille réelle (markdown peut varier en hauteur) via `MeasuredSizeWidget`/`RenderBox`, un spinner
   s'affiche pendant la mesure, puis le graphe est rendu avec les tailles mesurées (`NodeSize` bornée
   120-400 large / 50-600 haut). Re-mesure incrémentale sur `didUpdateWidget` si nouveaux nœuds.
7. **Couplage** : package **`graphite`** (`DirectGraph`, `NodeInput`, `EdgeInput`, `EdgeStyle`,
   `MatrixOrientation`, `LineStyle`, `EdgeArrowType`), GetX (`firstWhereOrNull`), `RichTextReaderScreen`.

### M4 — Orchestrateur d'édition/affichage `FolderMindmapEditor`
1. **Rôle** : point d'entrée unique qui bascule entre les 4 combinaisons (graphite/flowchart) ×
   (édition/lecture) selon `crud` et `mindmapViewer`.
2. **Fichier** : `widgets/folder_mindmap_editor.dart`, classe `FolderMindmapEditor`.
3. **Structure** : `ValueNotifier<MindmapModel?>` + `ListenableBuilder` pour réagir aux changements
   externes du modèle.
4. **Édition** : si `crud == create|update` et viewer `graphite` → délègue à `GraphiteEditorWidget`
   (M1) ; si viewer `flowchart` → construit un `Dashboard` interactif complet (M5-M9 ci-dessous).
5. **Affichage** : si `crud == read` et viewer `graphite` → `GraphiteMindmapViewer` (M3) + FAB
   `ExpandableFab` avec zoom in/out/recentrer manuels (`Matrix4.diagonal3Values`).
6. **Spécial** : sauvegarde flowchart déclenche `folderMindmapRepositoryProvider.update(...)` (Riverpod,
   via `ProviderScope.containerOf(context)`, bien que le widget hérite aussi de `AutoRouterMixin` +
   utilise `Get.back()` — **mix GetX/Riverpod** dans le même widget).
7. **Couplage** : GetX (`Get.back`), **Riverpod** (`ProviderScope.containerOf(...).read(folderMindmapRepositoryProvider)`),
   `flutter_expandable_fab`, `star_menu`, `flutter_flow_chart`.

### M5 — Ajout de formes libres (mode flowchart)
1. **Rôle** : menu contextuel (tap/long-press sur le canvas vide) pour insérer une forme à la position
   pointée.
2. **Fichier** : `folder_mindmap_editor.dart:404-637` (`_displayDashboardMenu`).
3. **Structure** : chaque forme = `FlowElement` avec `kind` parmi `diamond/rectangle/oval/parallelogram/
   hexagon/storage` (+ variante rectangle "déplaçable/redimensionnable/non-connectable"), taille et
   `handlers` prédéfinis par forme.
4. **Édition** : ajout via `dashboard.addElement(...)`, couleur de bordure aléatoire par insertion
   (`randomColor()`), suppression globale (`dashboard.removeAllElements()`).
5. **Affichage** : menu `StarMenu` (package `star_menu`) en éventail linéaire ancré à la position du tap.
6. **Spécial** : ajout d'image (`ElementKind.image` + `pickImageBytes()`) **commenté/désactivé** dans le
   code actuel.
7. **Couplage** : `flutter_flow_chart` (`Dashboard`, `FlowElement`, `ElementKind`, `Handler`),
   `star_menu`.

### M6 — Connexions/arêtes libres entre éléments (mode flowchart)
1. **Rôle** : tracer des liens entre formes via leurs `Handler`s (poignées d'ancrage), avec styles de
   trait configurables.
2. **Fichier** : `folder_mindmap_editor.dart:205-313` (`_displayHandlerMenu`), `FlowChart.onNewConnection`.
3. **Structure** : arête = connexion entre deux `Handler` d'éléments, `ArrowStyle` (`segmented` avec
   `tension` réglable par slider 0-3, `curve`, `rectangular`).
4. **Édition** : suppression d'une connexion (`removeElementConnection`), **dissection** (ajout d'un
   pivot intermédiaire sur l'arête, `dissectElementConnection`) et suppression d'un pivot
   (`onPivotSecondaryPressed → dashboard.removeDissection`), changement de style via menu `StarMenu`
   sur le handler.
5. **Affichage** : rendu natif du package `flutter_flow_chart` (`FlowChart` widget).
6. **Spécial** : —
7. **Couplage** : `flutter_flow_chart`, `star_menu`.

### M7 — Menu d'édition d'un élément (mode flowchart)
1. **Rôle** : menu contextuel sur un élément (rectangle/diamant/etc.) pour ses actions et propriétés.
2. **Fichier** : `folder_mindmap_editor.dart:316-402` (`_displayElementMenu`), `widgets/element_settings_menu.dart`,
   `widgets/text_menu.dart`.
3. **Structure** : actions sur `FlowElement` — suppression, suppression de toutes ses connexions,
   toggle `isConnectable`/`isResizable`, style (couleur fond/bordure via `HueRingPicker`, épaisseur de
   bordure par slider, élévation/ombre par slider), texte (couleur, gras, taille via slider,
   édition du contenu texte via `DynamicEditionScreen`/`DynamicFormField` multi-lignes).
4. **Édition** : `TextContentMenu` (édition du texte, `styleOnly:false`) vs `TextMenu` (style seul,
   `styleOnly:true`), `ElementSettingsMenu` (apparence).
5. **Affichage** : `StarMenu` en grille (`StarMenuParameters.panel(context, columns: 2)`).
6. **Spécial** : sélecteur de couleur `flutter_colorpicker` (`HueRingPicker`).
7. **Couplage** : `flutter_flow_chart`, `star_menu`, `flutter_colorpicker`, `DynamicEditionScreen`
   (data_crud).

### M8 — Import/export du diagramme flowchart (fichier JSON)
1. **Rôle** : sauvegarder/charger le `Dashboard` complet en fichier JSON local (mobile/desktop) ou
   téléchargement navigateur (web).
2. **Fichier** : `widgets/hooks_mobile.dart` (I/O fichier via `path_provider`/`dart:io`) et
   `widgets/hooks_web.dart` (téléchargement via `dart:html`/`web`), sélectionnés par
   `mindmap_module.dart` (`export ... if (dart.library.js_interop) ...`).
3. **Structure** : sérialisation native du package `flutter_flow_chart` (`dashboard.saveDashboard(path)`
   / `dashboard.prettyJson()` / `dashboard.loadDashboard(path)` / `loadDashboardData(json)`).
4. **Édition** : remplace entièrement le dashboard courant au chargement.
5. **Affichage** : n/a (I/O).
6. **Spécial** : nom de fichier fixe `FLOWCHART.json` ; sélection d'image (`pickImageBytes`, via
   `file_picker`) réutilisée par M5.
7. **Couplage** : `flutter_flow_chart`, `file_picker`, `path_provider` (mobile), `package:web` (web) —
   **non branché dans l'UI actuelle** (pas de bouton visible appelant `saveDashboard`/`loadDashboard`
   dans `folder_mindmap_editor.dart` — fonctions exportées mais apparemment orphelines/legacy).

### M9 — Recentrage / zoom du flowchart
1. **Rôle** : FAB de recentrage automatique du dashboard.
2. **Fichier** : `folder_mindmap_editor.dart:838-841`.
3. **Structure** : `dashboard.recenter` (méthode native du package).
4. **Édition** : n/a.
5. **Affichage** : bouton flottant unique (`Icons.center_focus_strong`).
6. **Spécial** : le zoom/scale du flowchart est aussi piloté nativement par `FlowChart.onScaleUpdate`
   (callback vide ici, pas d'action custom).
7. **Couplage** : `flutter_flow_chart`.

### M10 — Dialog CRUD des métadonnées de la mindmap
1. **Rôle** : formulaire léger pour créer/modifier titre + description de la carte (indépendamment du
   contenu des nœuds/du diagramme).
2. **Fichier** : `dialogs/mindmap_dialogs.dart`, fonction `showMindmapEditonDialog`.
3. **Structure** : `DynamicFormField` `title` (requis) + `description` (multi-lignes).
4. **Édition** : passe par `DynamicEditionScreen` générique (data_crud IFFD) ; à la validation, appelle
   `mindmapsRepository.create/update`. Génère un `id` (`randomString()`) en création.
5. **Affichage** : dialog/bottom-sheet standard (`showPushedDialog`).
6. **Spécial** : gère le contexte "sujet" vs "dossier" (`subjectToolPage` → retire `folderId`/
   `subFolderId` ou `subjectId` selon le cas) — mindmap rattachable à un `SubjectModel` ou à un
   `FolderModel`.
7. **Couplage** : GetX indirect (via `showPushedDialog`), `DataCrudLocalizations`, `FirebaseFolderMindmapRepositoryImpl`
   par défaut.

### M11 — Ouverture du viewer/éditeur complet en dialog plein écran
1. **Rôle** : point d'entrée pour ouvrir `FolderMindmapEditor` (M4) en plein écran depuis n'importe où
   dans l'app (liste de dossier, actions, chat IA…).
2. **Fichier** : `dialogs/mindmap_dialogs.dart`, fonction `showFolderMindmapViewer`.
3. **Structure** : wrap `FolderMindmapEditor` avec `mindmap`, `crud`, `initialDashboard`, callback
   `onChanged`.
4. **Édition** : callback `onChanged` répercute la mutation vers l'appelant (ex. sauvegarde repository).
5. **Affichage** : `showPushedDialog(dialog:true, fullscreenDialog:true)`.
6. **Spécial** : —
7. **Couplage** : —

### M12 — Menu d'actions sur une mindmap (item de liste)
1. **Rôle** : menu contextuel (long-press/clic sur item dans une liste de dossier) — modifier
   métadonnées, éditer le contenu, déplacer, supprimer.
2. **Fichier** : `dialogs/mindmap_dialogs.dart` (`showMindmapActionsDialog`),
   `dialogs/mindmap_dialog_widgets.dart` (`MindmapActionsDialogWidget`).
3. **Structure** : n/a (actions sur `MindmapModel` existant).
4. **Édition** : « Modifier les détails » → M10 ; « Editer la carte mentale » → M11 (`crud: update`) ;
   « Déplacer » → sélection dossier/sujet cible (`batchUpdate` sur `folderId`/`subFolderId` ou
   `subjectId`) ; « Supprimer » → confirmation puis `repository.delete(id)`.
5. **Affichage** : liste de `ListTile` conditionnés par permissions (`canUpdate`/`canDelete`/`canMove`,
   via `FolderResourceAccessService.forMindmap`).
6. **Spécial** : contrôle d'accès fin (créateur de la ressource / propriétaire du dossier requis pour
   supprimer).
7. **Couplage** : **Riverpod** (`ProviderScope.containerOf(context).read(folderMindmapRepositoryProvider)`),
   GetX (`Get.back`), `FolderResourceAccessService`.

### M13 — Génération de mindmap par IA (3 variantes)
1. **Rôle** : génère automatiquement les nœuds d'une mindmap à partir (a) de notes texte libres,
   (b) du contenu de pages sélectionnées d'un document, (c) d'un document entier.
2. **Fichier** : `domain/repositories/ai_repository.dart` (contrat), `data/repositories/iffd_ai_repository_impl.dart`
   + `cloud_functions_ai_repository_impl.dart` (impl), `domain/services/ai/ai_prompt_generator.dart`
   (construction des prompts), consommé depuis `lib/ai_assistant/screens/chatbot_conversation_screen.dart`
   et `presentation/features/explain_ai/pages/explain_ai_page.dart`.
3. **Structure** : `generateMindmapFromNotes({subject, notes})`,
   `generateMindmapFromDocumentPagesContents({documentId, pagesContents: Map<int,String>, cycle, ...})`,
   `generateMindmapFromWholeDocument({documentId, cycle, ...})` — toutes retournent un
   `AiResponse` asynchrone (callback `onComplete`) dont le contenu JSON est parsé en
   `List<MindmapNode>` puis enveloppé dans un `MindmapModel` unique (souvent racine synthétique via
   `nodes: [mindmapNode]` où `mindmapNode.outputs` contient les nœuds réels).
4. **Édition** : le résultat généré est ensuite ouvert dans `showFolderMindmapViewer` (M11, `crud:
   update`) pour retouche manuelle avant sauvegarde.
5. **Affichage** : bouton/menu dédié dans le chat IA (`mindmapMenu`, `PopupMenu`) affichant un badge du
   nombre de nœuds générés (`mindmapNodesCount`), état "génération en cours" par message
   (`isMindmapGenerating`).
6. **Spécial** : **modèle IA configurable par fonctionnalité** via `IffdAiRouterModel.mindmapModel` +
   `mindmapFallbackModels` (liste de repli) ; requêtes JSON-mode (`jsonMode:true`) ; endpoint dédié
   `"generate_mindmap"` / `"generate_mindmap_with_ai"` / `"generate_mindmap_from_whole_document"`
   selon l'impl. Génération liée à un message de conversation IA (`mindmapRequestId`/`mindmapResponseId`,
   `ChatbotMessageTransformer.mindmap`, `ChatbotMessageType.mindmap`) — traçable/rejouable dans
   l'historique du chat.
7. **Couplage** : services IA (`AiRepository`, Cloud Functions ou OpenAI direct selon impl), Riverpod
   (`folderMindmapRepositoryProvider`), modèle `IffdAiRouterModel`/`AiResponse` (`domain/models/ai/ai_models.dart`).

---

## Ce qui N'EXISTE PAS (absence notée pour l'audit de parité)

- Pas de conversion mindmap ↔ markdown/outline texte brut (pas de `toMarkdown()`/`fromMarkdown()` sur
  `MindmapModel`/`MindmapNode`).
- Pas d'export PDF/image/PNG de la mindmap (code de partage/PDF présent mais **entièrement commenté**
  dans `folder_mindmap_editor.dart:697-762`).
- Pas de "drag" manuel des nœuds en mode `graphite` (positionnement 100% auto via le package
  `graphite`) — seul le mode `flowchart` a un positionnement libre par drag.
- Le champ `MindmapNode.resizable` et `size` sont quasi-inertes en mode graphite (taille recalculée par
  mesure du widget, pas par saisie utilisateur).
- Import/export JSON du dashboard flowchart (M8) semble **legacy/non branché** dans l'UI de production
  actuelle (fonctions exportées, aucun bouton visible les appelant dans `folder_mindmap_editor.dart`).
- Mix d'état notable : le module mélange GetX (`Get.back`, `AutoRouterMixin`) et **Riverpod**
  (`ProviderScope.containerOf(context).read(...)`) dans les mêmes widgets — pas une architecture
  homogène.
