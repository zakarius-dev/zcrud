# Confrontation — domaine « Cartes mentales » d'IFFD × socle zcrud v3.21.0

**Relevé du 2026-08-26.** Hôte `/home/zakarius/DEV/iffd` lu en **lecture seule stricte**
(aucune écriture, aucun test lancé, dans aucun dépôt). Socle lu sous
`/home/zakarius/DEV/zcrud/packages/`. IFFD est épinglé sur **v3.21.0**
(`iffd/pubspec.yaml`, 48 entrées `ref: v3.21.0`) ; `zcrud_mindmap` et `zcrud_study`
portent bien `version: 3.21.0` (`packages/zcrud_mindmap/pubspec.yaml:6`,
`packages/zcrud_study/pubspec.yaml:12`).

**Matière d'entrée** : `carte-mindmap.md` (41 567 o — **présente**, son agent n'est pas
mort) et les cinq `capacites-zcrud-*.md`. Les deux ont été **revérifiés sur disque** ;
**deux constats de la carte ont été infirmés** (§ 6).

---

## 0. Le chiffre qui commande tout : câblé ≠ actif

Le domaine dédié pèse **21 fichiers / 5 952 lignes** (17 fichiers `presentation/features/mindmap/`
= 4 679 l., plus `z_backed_mindmap_repository.dart` 806, `mindmap_model.dart` 415,
`folder_mindmap_repository.dart` 52 — `wc -l` rejoué). Six fichiers portés y vivent
(1 126 l.).

🔴 **Les cinq drapeaux mindmap valent `false`.** `mindmapEdition`, `mindmapOutline`,
`mindmapElementText`, `mindmapViewer`, `mindmapRichReader` —
`z_qa_flags.dart:586`, `:592`, `:611`, `:622`, `:632`. **Aucun** chemin porté du domaine
n'est actif en production, et le dépôt legacy est intégralement conservé à côté.
Le **seul** chemin mindmap réellement actif chez l'hôte est l'artefact de conversation
(`notebook_artifact_registry_iffd.dart:103-108`).

Conséquence pour ce document : « DÉJÀ MIGRÉ » signifie **le canal est consommé dans le
code**, pas « l'utilisateur le voit ». Chaque ligne le précise.

---

## 1. DÉJÀ MIGRÉ — le canal est consommé par l'hôte

| Canal socle | `fichier:ligne` socle | Site chez l'hôte | Actif ? |
|---|---|---|---|
| `ZMindmap` / `ZMindmapNode` | `zcrud_mindmap/lib/src/domain/z_mindmap.dart:41`, `z_mindmap_node.dart:34` | `mindmap_zcrud_mapper.dart:31` (barrel) ; `z_backed_mindmap_repository.dart:104` | non (flag) |
| `ZMindmapTreeOps.normalizeLevels` | `z_mindmap_tree_ops.dart:267` | `mindmap_zcrud_mapper.dart:160` — **seul** des 12 verbes publics consommé (`grep -rn 'ZMindmapTreeOps' lib` → **3**, dont 2 commentaires) | non |
| `ZMindmapView` + `ZMindmapViewConfig` + `ZMindmapViewMode` | `z_mindmap_view.dart:55`, `z_mindmap_view_config.dart:137`, `:123` | `zcrud_mindmap_view.dart:88` (`ZcrudMindmapView`), config `:31` | non (`mindmapViewer`) |
| `ZMindmapOutlineEditor` + `ZMindmapOutlineLabels` | `z_mindmap_outline_editor.dart:50`, `z_mindmap_outline_labels.dart:17` | `mindmap_outline_zcrud.dart:168`, libellés `:71` | non (`mindmapOutline`) |
| `ZMarkdownReader` + `ZMarkdownReaderChrome` + `ZRichTextFormulaSpec` + `ZRichTextStyleSet` | `zcrud_markdown` | `mindmap_rich_reader_zcrud.dart:149` (fabrique unique des deux surfaces) | non (`mindmapRichReader`) |
| `ZFieldSpec` / `EditionFieldType` / `ZTextConfig` / `ZValidatorSpec` / `ZFormController` / `ZEditionSubmitController` / `DynamicEdition` | `zcrud_core` | `mindmap_zcrud_edition.dart:69` ; `text_menu_zcrud_edition.dart:50` | non (`mindmapEdition`, `mindmapElementText`) |
| `presentFormEdition` | `zcrud_screen` | `text_menu_zcrud_edition.dart:52` | non |
| `ZSyncMeta.kIsDeleted` / `kUpdatedAt` (sync hors-entité) | `zcrud_core` | `z_backed_mindmap_repository.dart:103`, écriture `:526-542` | non (`useZcrudMindmapRepository → false`, `folder_providers.dart:88-94`) |
| Artefact de conversation (`ZChatArtifactSpec` / registre / compteurs / actions) | `zcrud_chat` | `notebook_artifact_registry_iffd.dart:27,103-108,175,182,189` ; `notebook_artifact_counts_iffd.dart:114-129` ; `notebook_artifact_generation_iffd.dart:90-99` | **OUI** |
| `ZContentHubSheet` + `ZContentHubEntry` + `ZContentHubSection` | `zcrud_study/…/z_content_hub_sheet.dart:188` | `content_hub_zcrud.dart:64`, montage `:453`, entrée mindmap `:336-354` | selon flag hub |
| `ZStudyToolsSectionSpec` (constructeur **générique**) + `ZDefaultNoteCard` détourné pour la mindmap | `z_study_tools_section_spec.dart:96` ; `z_default_note_card.dart:73` | `study_tools_zcrud_adapter.dart:452` (helper maison `zStudyToolsSection`), section mindmap `:781-800` | oui |
| `ZStudyLegacyCodec` (avec `opaqueKeys: {'dashboard'}`) | `zcrud_firestore/lib/src/data/z_study_codec.dart:62`, `opaqueKeys` doc `:86-89` | `z_iffd_legacy_codec.dart:59` (`'dashboard'`), `:168` — **couche MIGRATION uniquement** | oui (migration) |
| `ZItemActionsMenu` + `ZItemAction` + `menuBuilder` | `z_item_actions_menu.dart:283`, `:147`, `:342` | `folder_actions_menu_zcrud.dart:36` — **pour les dossiers seulement** | non (flag) |

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte l'ignore

Chaque ligne cite l'**API exacte**, son `fichier:ligne` dans `packages/`, la **preuve que
le corps fait ce qu'on lui prête** (pas seulement la dartdoc), et le **grep négatif** côté
hôte.

### 2.1 `ZMindmapView.nodeContentBuilder` — les nœuds portés rendent du texte brut

- **API** : `ZMindmapNodeContentBuilder = Widget Function(BuildContext, ZMindmapNode)`
  — `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:27` ;
  paramètre `ZMindmapView.nodeContentBuilder` `z_mindmap_view.dart:62`, champ `:83`.
- **Corps vérifié** : `z_mindmap_view.dart:143` —
  `widget.nodeContentBuilder ?? _defaultContent`. Le builder injecté est réellement le
  contenu rendu des deux surfaces (graphe **et** liste), pas un ornement.
- **Hôte** : `grep -rn 'nodeContentBuilder' lib test` → **0**.
  `ZcrudMindmapView` (`zcrud_mindmap_view.dart:88-94`) passe `mindmap`, `mode`, `config`,
  `onNodeTap`, `emptyLabel` — **et rien d'autre**.
- **Ce que l'hôte a déjà sous la main** : `mindmapRichReaderZcrud(...)`
  (`mindmap_rich_reader_zcrud.dart:138-163`) — markdown + LaTeX + tableaux, codec
  `IffdRichTextCodec.markdown`, `chrome: none`, `emptyBuilder` calqué sur le legacy.
  L'adoption est **un argument nommé** :
  `nodeContentBuilder: (ctx, n) => mindmapRichReaderZcrud(contenu: n.content ?? '', …)`.
- ⚠️ **PAS** via `ZMindmapMarkdownContent`. Corps lu :
  `z_mindmap_markdown_content.dart:80-95` lit des **ops Delta** dans `extra[slotKey]` et
  `:110-115` rend avec `const ZDeltaCodec()`. Le corpus IFFD est du **markdown dans
  `content`**, 0 Delta (`mindmap_rich_reader_zcrud.dart:22-28`). Ce canal-là ne s'applique
  pas ; le seam générique, si.
- **Lignes d'hôte économisées : 0** — mais c'est le **gap bloquant** du drapeau
  `mindmapViewer` : basculé aujourd'hui, il **perd** markdown, LaTeX et tableaux dans
  chaque nœud.

### 2.2 `ZMindmapOutlineEditor.editFieldBuilder` — l'édition portée d'un nœud est en texte brut

- **API** : `ZMindmapEditFieldBuilder` `z_mindmap_view_config.dart:117` ; contexte stable
  `ZMindmapEditFieldContext` `:65` (porte `controller` **stable keyé par `node.id`**,
  `value`, `onChanged`, `writeRichSlot`, `hint`, `config`, `theme`) ; paramètre
  `z_mindmap_outline_editor.dart:61`, champ `:108`.
- **Corps vérifié** : forwardé `:256`, puis `final builder = editFieldBuilder ?? _defaultEditField;`
  `:577`. Le repli `_defaultEditField` est déclaré `:702`. Le seam est réellement branché
  sur les deux champs (`label` **et** `content`, `ZMindmapEditFieldKind` `:42`).
- **Hôte** : `grep -rn 'editFieldBuilder' lib test` → **0**.
  `MindmapOutlineZcrud` (`mindmap_outline_zcrud.dart:168-181`) passe `roots`, `labels`,
  `config`, `onSave` — rien de plus.
- **Ce que ça remplace** : le formulaire de nœud legacy est un `DynamicEditionScreen`
  inline à deux champs `inlineMarkdown` (`graphite_editor_widget.dart:419-473`, **55 l.**).
- **Lignes d'hôte économisées : 55** (à la suppression du legacy).

### 2.3 État vide de l'éditeur outline — trois libellés non renseignés

- **API** : `ZMindmapOutlineLabels.emptyTitle` / `emptyMessage` / `emptyActionLabel`
  — `z_mindmap_outline_labels.dart:31-33`, champs `:79`, `:84`, `:91` ;
  et `ZMindmapOutlineEditor.emptyBuilder` (`ZMindmapOutlineEmptyBuilder`
  `z_mindmap_outline_editor.dart:40`, champ `:118`).
- **Corps vérifié** : `_OutlineEmptyState` `z_mindmap_outline_editor.dart:325+` monte
  illustration + bouton centré ≥ `minTapTarget` ; `:440-470` (`_OutlineEmptyAction`) lit
  `labels.emptyActionLabel` et retombe sur `labels.addRoot`. Chaque ligne de texte
  **n'est montée que si l'hôte la fournit**.
- **Hôte** : `kIffdMindmapOutlineLabels` (`mindmap_outline_zcrud.dart:71-83`) renseigne
  11 libellés et **aucun des trois `empty*`**.
- **Ce que ça remplace** : l'état vide legacy (illustration + « Aucun noeud » + bouton),
  `graphite_editor_widget.dart:279-337`, **59 l.**
- **Lignes d'hôte économisées : 59** (à la suppression du legacy). Coût d'adoption :
  3 littéraux.

### 2.4 `ZMindmapViewController` + `ZMindmapViewLabels` — le zoom maison n'est pas borné

- **API** : `ZMindmapViewController` `z_mindmap_view_controls.dart:27` ;
  `ZMindmapViewLabels` `:119` ; paramètres `ZMindmapView.controller`
  `z_mindmap_view.dart:67` (champ `:100`) et `viewLabels` `:68`.
- **Corps vérifié** (pas la dartdoc) : `_clampScale` `z_mindmap_view_controls.dart:103`
  borne **toute** mutation d'échelle ; `zoomIn/zoomOut/resetZoom/setScale` `:79-88` y
  passent tous. Côté vue : `build` `:153-196` monte `_ZMindmapControlBar` (`:435`) dès
  que le contrôleur est non-nul, avec zoom −/reset/+ (`:459-472`), compact (`:476-481`),
  plein écran (`:485-491`), super-racine (`:495-499`) ; le plein écran enveloppe
  réellement le corps (`:158-161`).
- **Hôte** : `grep -rn 'ZMindmapViewController\|ZMindmapViewLabels\|viewLabels\|showSuperRoot' lib`
  → **0 / 0 / 0 / 0**.
  À la place : trois `FloatingActionButton` qui multiplient une `Matrix4`
  (`folder_mindmap_editor.dart:120-146`, **27 l.**) — `*= Matrix4.diagonal3Values(1.1,1.1,1)`
  répété, **sans borne haute ni basse**.
- **Lignes d'hôte économisées : 27**, et le zoom devient borné (`minScale 0.25` /
  `maxScale 2.5`, `z_mindmap_view_config.dart:140-145`).

### 2.5 `ZItemActionsMenu` pour la carte — le patron est déjà prouvé **dans le même dépôt**

- **API** : `ZItemActionsMenu` `zcrud_study/lib/src/presentation/z_item_actions_menu.dart:283`,
  `ZItemAction` `:147`, `ZItemActionKind` `:70`, `ZItemActionState` `:104`,
  `menuBuilder` `:342`, `crossAxisCount` `:297` (défaut 3).
- **Corps vérifié** : `build` `:355-425` traduit 1:1 en `ZMenuEntry`, délègue à
  `ZActionMenu` (`zcrud_menu/…/z_action_menu.dart:18`) qui applique
  `zVisibleMenuEntries` (`z_menu_entry.dart:194`) — **site unique** de la règle d'absence.
  `contentBuilder` est `null` quand aucune action n'est visible **et** qu'aucun
  `menuBuilder` n'est fourni : le déclencheur n'est alors pas actionnable.
- **Preuve que le patron marche chez cet hôte** : `folder_actions_menu_zcrud.dart:34-38`
  importe `ZItemAction`/`ZItemActionKind`/`ZItemActionsMenu` et conserve la grille 2
  colonnes via `menuBuilder` (`kFolderMenuColumns = 2`, `:44`). 13 occurrences de
  `ZItemActionsMenu`, 122 de `ZItemAction` dans `lib`+`test`.
- **Hôte, côté mindmap** : `grep -n 'zcrud\|ZItem' lib/src/presentation/features/mindmap/dialogs/mindmap_dialog_widgets.dart`
  → **RC=1, aucune sortie**. Le menu contextuel `buildMindmapPopupMenu`
  (`popup_menu_helpers.dart:492-609`, **118 l.**) construit un `PopupMenu` maison avec
  `MenuConfig(type: MenuType.grid, maxColumn: 2)` (`:505`) — **exactement** la
  configuration que `crossAxisCount: 2` rend nativement. La feuille d'actions
  (`mindmap_dialog_widgets.dart:20-235`, **216 l.**) est un `Column` de `ListTile`
  = `crossAxisCount: 1`.
- **Lignes d'hôte économisées : 334**. Gain de comportement : une action non permise
  **disparaît** au lieu d'être visible et inerte (AD-4) — c'est écrit noir sur blanc par
  l'hôte lui-même à `folder_actions_menu_zcrud.dart:20-30`.

### 2.6 `showZConfirmDialog` + `ZConfirmTone` — 38 sites de dialogue maison

- **API** : `showZConfirmDialog` `zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129` ;
  `ZConfirmDialog` `:36` ; `ZConfirmTone` `zcrud_ui_kit/lib/src/domain/z_confirm_tone.dart:12`.
- **Corps vérifié** : `:139-146` — `showDialog<bool>` puis `return result ?? false`
  (défaut sûr AD-10, jamais de throw) ; `title: null` retire réellement le titre de
  l'arbre et pose un `Semantics(scopesRoute, namesRoute)` (`:104-115`).
- **Hôte** : `grep -rn 'showZConfirmDialog\|ZConfirmTone' lib test` → **0 / 0**.
  `buildConfirmDialog` maison : **38 appels dans 20 fichiers**, dont
  `mindmap_dialog_widgets.dart:219` (suppression d'une carte).
- **Dépendance déjà déclarée** : `zcrud_ui_kit` `iffd/pubspec.yaml:440`.
- **Lignes d'hôte économisées** : ~10 pour le seul site mindmap ; **le levier réel est
  hors domaine** (37 autres sites).

### 2.7 `onConfirmDelete` + `subtreeSize` — la suppression portée emporte un sous-arbre sans confirmation

- **API** : `ZMindmapOutlineEditor.onConfirmDelete`
  `z_mindmap_outline_editor.dart:83` (`Future<bool> Function(ZMindmapNode)`, `false` annule) ;
  ampleur via `ZMindmapOutlineController.subtreeSize(String id)`
  `z_mindmap_outline_controller.dart:185`.
- **Hôte** : `grep -rn 'onConfirmDelete' lib test` → **0**. Le chemin porté
  (`mindmap_outline_zcrud.dart:168-181`) ne le passe pas → un geste supprime le
  sous-arbre entier sans retour. Le legacy, lui, confirme
  (`mindmap_dialog_widgets.dart:219`).
- **Lignes d'hôte économisées : 0** — c'est une **régression évitée** sur un drapeau
  marqué `changesData: true` (`z_qa_flags.dart:602`).

### 2.8 `ZMindmapGenerationPort` — 6 stubs morts et 9 déclarations pour une seule implémentation

- **API** : `ZMindmapGenerationPort`
  `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart:189` (une méthode,
  `Future<ZResult<List<ZMindmapNode>>> generateMindmap(request)`),
  `ZMindmapGenerationRequest` `:81` (`content`, `source`, `count`, `maxDepth`,
  `languageTag`, `instructions`, `modelId`, `extra`), `ZMindmapSourceRef` `:49`
  (`id` + `selector` opaques).
- **Corps vérifié** : c'est un contrat pur — `abstract interface class`, aucune
  implémentation de référence ; `extra` filtré par `zSanitizeExtra(_extra, _reservedKeys)`
  avec `_reservedKeys = {...ZSyncMeta.reservedKeys}` (`:148-151`), conforme au gate
  `reserved-keys`. Il rend une **forêt éphémère**, jamais un `ZMindmap` à identité
  fabriquée (`:11-16`).
- **Hôte** : `grep -rn 'ZMindmapGenerationPort\|ZMindmapGenerationRequest\|ZMindmapSourceRef' lib test`
  → **0 / 0 / 0** (le symbole n'apparaît que dans `docs/`, jamais dans le code —
  `docs/gap-migration-zcrud.md:145`, `docs/plan-migration-zcrud-v2.md:472` M6-5).
- **Ce que ça remplace** : 3 méthodes déclarées au port
  (`ai_repository.dart:109`, `:408`, `:421`) et **redéclarées dans trois implémentations** :
  `iffd_ai_repository_impl.dart:624`, `:1267`, `:1298` (la seule vraie) ;
  `openai_ai_repository_impl.dart:599`, `:615`, `:651` et
  `cloud_functions_ai_repository_impl.dart:426`, `:442`, `:478` — **six corps
  `throw UnimplementedError()`**, ~14 l. chacun (mesuré `openai…:599-627`).
- **La forme `Future<ZResult<…>>` convient** — vérifié au site d'appel, pas supposé :
  les 7 copies n'agissent que sur `if (completed && !hasError)`
  (`popup_menu_helpers.dart:350-352`), le flux intermédiaire n'est jamais consommé.
- **Lignes d'hôte économisées : ~116** (84 de stubs morts + ~32 de signatures triplées).
- ⚠️ **Le port ne couvre PAS** le décodage JSON→nœuds ni l'ouverture de l'éditeur :
  voir § 3.1.

### 2.9 `ZStudyToolsSectionSpec.mindmaps` + `ZDefaultMindmapCard` + `zMindmapNodeCount`

- **API** : constructeur typé `ZStudyToolsSectionSpec.mindmaps({required List<ZMindmap> maps, nodeCountLabel, colorKeyOf, progressOf, …})`
  `z_study_tools_section_spec.dart:469` ; carte `ZDefaultMindmapCard`
  `z_default_mindmap_card.dart:90` ; compteur `zMindmapNodeCount`
  `z_default_mindmap_card.dart:69`.
- **Corps vérifié** : `zMindmapNodeCount` (`:69-79`) parcourt **toute la forêt** par pile
  explicite (aucune récursion non bornée) ; la puce de compteur est **absente** sans
  `nodeCountLabel` injecté (`:223` `nodeCountLabel?.call(count)`, montage `:393` — invariant AD-4) ; la vignette structurelle est
  `ExcludeSemantics` et l'information est redite en texte (`:31-39`).
- **Hôte** : `grep -rn 'ZStudyToolsSectionSpec\.mindmaps' lib test` → **0**
  (aucun constructeur typé n'est utilisé : `.flashcards`, `.documents`, `.notes`,
  `.folders`, `.exams` → **0** chacun). `ZDefaultMindmapCard` → **0** dans `lib`+`test`.
  `zMindmapNodeCount` → **0**.
  À la place : helper maison `zStudyToolsSection` (`study_tools_zcrud_adapter.dart:452`),
  `mindmapStudyItems` (`:943-963`, ~24 l.) et `ZDefaultNoteCard` détourné avec
  `icon: Icons.hub_outlined` codé au site (`:796`).
- **Lignes d'hôte économisées : ~64** (24 du mappeur + ~40 du bloc de section).
- ⚠️ **CONTESTÉ, et je le dis** : l'hôte a **retiré délibérément** le détour `ZMindmap`
  pour cette carte — « Carte par PRIMITIVES : plus besoin du détour `ZMindmap` retiré au
  tour précédent » (`study_tools_zcrud_adapter.dart:787-789`). Réadopter le constructeur
  typé **réintroduit** ce mapping. Le gain net (compteur de nœuds, clé d'accent stable
  dérivée de `map.id`, progression par carte, vignette réglable) doit être arbitré par
  l'hôte, pas décrété ici.

### 2.10 `zMindmapNodeCount` contre le compteur d'artefact — un bug, pas seulement une duplication

- **Hôte** : `iffdCountMindmapNodes` (`notebook_artifact_counts_iffd.dart:91-95`) est
  **récursif**, et le site appelant ne compte que le **premier nœud**
  (`:114-120` : `final MindmapNode? premier = …; if (premier != null) noeuds = iffdCountMindmapNodes(premier);`).
  Une carte à trois racines affiche donc le compte de la première.
- **Socle** : `zMindmapNodeCount(List<ZMindmapNode>)` compte **toute la forêt**, itérativement.
- **Lignes économisées : ~10**, mais l'adoption exige de passer par le mapper —
  gain marginal, correction réelle.

**Sous-total « migrable aujourd'hui » : ~665 lignes d'hôte supprimables**, plus deux
régressions évitées (zoom non borné, suppression sans confirmation) et un gap bloquant
levé (markdown/LaTeX des nœuds portés).

---

## 3. MANQUE AU SOCLE

### 3.1 🔴 Aucun assemblage « génération IA → revue → matérialisation » pour la carte mentale

- **Preuve d'absence** :
  ```
  $ ls packages/zcrud_study/lib/src/presentation | grep -i 'generation\|mindmap'
  z_default_mindmap_card.dart
  z_flashcard_generation_controller.dart
  z_flashcard_generation_sheet.dart
  z_study_mindmap_section.dart
  $ grep -rn 'ZChatMindmapArtifactAdapter' --include='*.dart' packages/ ; echo "RC=$?"
  RC=1
  ```
  Les flashcards ont **trois** pièces (`ZFlashcardGenerationSheet`
  `z_flashcard_generation_sheet.dart:214`, `ZFlashcardGenerationController`
  `z_flashcard_generation_controller.dart:84`, `ZFlashcardGenerationLauncher`
  `z_flashcard_generation_sheet.dart:868`). La carte mentale n'a **que le port**.
- **Ce que l'hôte paie** : le bloc « réponse IA → `json.decode` → nœuds → `MindmapModel` →
  `showFolderMindmapViewer(crud: create)` → `onChanged → repo.update` → `catch` » est
  recopié **7 fois, 332 lignes** :
  `folder_documents_actions_dialog_widget.dart:781-820` (40),
  `valuation_tool_model_actions_dialog_widget.dart:169-211` (43),
  `smartnote_actions_dialog_widget.dart:197-255` (59),
  `explain_ai_page.dart:512-563` (52),
  `popup_menu_helpers.dart:355-392` (38) et `:788-829` (42),
  `chatbot_conversation_screen.dart:625-682` (58).
  Ancrage : `grep -rn 'List<MindmapNode> nodes' lib` → **9**, dont 2 internes à
  `mindmap_model.dart` (`:108`, `:164`) ⇒ **7 sites**.
  Les 7 copies **divergent déjà** : `description` renseigné dans 2 sur 7 ;
  `subjectId` calculé de trois façons ; 5 journalisent l'échec, 2 l'avalent
  (`explain_ai_page.dart:563`, `chatbot_conversation_screen.dart:682`).
- **Forme du canal manquant** : un **assemblage** `ZMindmapGenerationSheet` +
  `ZMindmapGenerationController` + `ZMindmapGenerationLauncher`, **symétriques** aux
  trois pièces flashcard, dans **`zcrud_study`** ; plus un **décodeur neutre**
  `List<ZMindmapNode>` ← charge JSON (nœud unique **ou** forêt), défensif AD-10, dans
  `zcrud_mindmap` — c'est la moitié du bloc dupliqué et la seule qui soit neutre.
- **Pourquoi l'hôte ne peut pas s'en passer** : la génération IA est le **principal**
  point d'entrée du domaine (4 sources déclarées, 7 sites d'appel, un verbe CRUD dédié
  `Crud.aiMindMap`, `crud.dart:22`).
- **Bloque une capacité d'étude ? OUI** — c'est la voie « note / document / pages / outil
  d'évaluation → carte mentale ».

### 3.2 🔴 Le canevas libre (flow-chart) est totalement absent du socle

- **Preuve d'absence** :
  ```
  $ grep -rn 'flutter_flow_chart\|FlowChart\|Dashboard' --include='*.dart' --include='*.yaml' \
      packages/*/lib packages/*/pubspec.yaml
  zcrud_firestore/lib/src/data/z_study_codec.dart:87:  ///   `dashboard` (sérialisation `flutter_flow_chart`), dont les noms de champs
  zcrud_study/pubspec.yaml:51:#   `zcrud_mindmap` — PAS de `graphite`/`flutter_flow_chart`/
  zcrud_study/lib/src/presentation/z_study_mindmap_section.dart:12:///   `flutter_flow_chart`/`graphview`/`graphite` ici.
  ```
  **Trois occurrences, toutes en commentaire.** Aucun widget, aucune dépendance.
  `zcrud_mindmap` ne connaît que `graphite: ^1.2.1`
  (`packages/zcrud_mindmap/pubspec.yaml:30`) — un **auto-agenceur d'arbre**, pas un
  canevas libre.
- **Ce que l'hôte paie** : `folder_mindmap_editor.dart:148-877` (~730 l., dont
  7 `ActionChip` de forme quasi identiques `:466-631`, ~166 l.),
  `element_settings_menu.dart` (174 l.), `text_menu.dart` branche `styleOnly` (~180 l.).
  **Aucun jumeau porté** pour ces trois surfaces.
  Le `dashboard` voyage **opaque** dans `extra['iffd_dashboard']`, avec un marqueur de
  perte `iffd_dashboard_serialization_failed` (`mindmap_zcrud_mapper.dart:96-100`,
  `z_backed_mindmap_repository.dart:336-347`).
- **Forme du canal manquant** : un **satellite neuf** (`zcrud_diagram`) portant un canevas
  à formes/liens, ou — moins cher — un **seam de rendu** `ZMindmapCanvasPort` dans
  `zcrud_mindmap` laissant l'hôte fournir sa surface tout en réutilisant l'entité, le menu
  d'actions et le chrome. Le tiers `flutter_flow_chart` est lourd : le porter au socle est
  une décision de produit, pas une évidence.
- **Bloque une capacité d'étude ? OUI, et de façon non évidente** : l'état vide de la
  section « cartes mentales » de la page d'outils crée une carte **`flowchart`** et la
  titre automatiquement `"<dossier|matière> yyyy-MM-dd"`
  (`folder_study_tools_page.dart:1983-2020`). Un des trois points de création de l'hôte
  produit donc un objet que le socle **ne sait pas rendre du tout**.
  ⚠️ Un `grep 'MindmapViewer.flowchart'` naïf **rate ce site** : le nom d'enum y est coupé
  sur trois lignes.

### 3.3 Aucune persistance d'un ORDRE de contenu par dossier

- **Preuve d'absence** :
  ```
  $ grep -rn 'subMindmapsIds\|reorderMindmaps\|reorderContent' --include='*.dart' packages/*/lib ; echo "RC=$?"
  RC=1
  $ grep -rn 'ZContentOrder' --include='*.dart' packages/*/lib ; echo "RC=$?"
  RC=1
  $ grep -n 'order\|Order\|Ids\b' packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart ; echo "RC=$?"
  RC=1
  ```
- **Ce que l'hôte paie** : `folder_contents_orders_repository.dart:27-85` — quatre méthodes
  **strictement identiques** (`reorderFlashcards`, `reorderDocuments`, `reorderNotes`,
  `reorderMindmaps`) ne différant que par le nom de clé
  (`subFlashcardsIds` / `subDocumentsIds` / `subNotesIds` / `subMindmapsIds`) — **59 l.**
- **Forme** : une **entité/port** `ZContentOrder` (ordre par *kind* de contenu, clé opaque)
  dans **`zcrud_study_kernel`**, ou un slot d'ordre sur `ZStudyFolder`. Le socle porte
  déjà le **geste** (`ZStudyToolsSectionSpec.onReorder`, `z_study_tools_section_spec.dart:46`)
  et non sa **persistance**.
- **Bloque une capacité d'étude ? Non** — le réordonnancement fonctionne. C'est la moitié
  manquante d'un canal existant.

### 3.4 Le mapper legacy↔canonique est écrit deux fois, et le socle n'a pas de couture pour l'éviter

- **Ce que l'hôte paie** : `MindmapZcrudMapper` (présentation, `mindmap_zcrud_mapper.dart`,
  **488 l.**, unidirectionnel) + `ZBackedMindmapMapper` (data,
  `z_backed_mindmap_repository.dart:156-374`, **219 l.**, bidirectionnel sans perte)
  = **707 lignes**, avec **13 clés `extra` dupliquées littéralement**
  (`mindmap_zcrud_mapper.dart:53-100` ↔ `z_backed_mindmap_repository.dart:174-198`).
  Le fichier data l'écrit lui-même : « **LES DEUX MAPPERS DOIVENT RESTER ALIGNÉS** »
  (`:48`). Cause assumée : une arête `data → presentation` serait interdite.
- **Ce que le socle a — et ce qu'il ne fait pas** : `ZStudyLegacyCodec`
  (`packages/zcrud_firestore/lib/src/data/z_study_codec.dart:62`) offre `opaqueKeys`
  (documenté sur `dashboard`/`flutter_flow_chart`, `:86-89`), `preserveLegacyUnder`,
  `syncMetaKeyAliases`, `keyAliases`, `preserveAbsenceUnder`, `recurseNested`.
  L'hôte **le consomme déjà** — mais uniquement dans la couche migration
  (`z_iffd_legacy_codec.dart:59` déclare `'dashboard'` opaque, `:168` l'injecte).
  Grep négatif ciblé :
  ```
  $ grep -n 'ZStudyLegacyCodec\|zcrud_firestore\|opaqueKeys' lib/src/data/repositories/z_backed_mindmap_repository.dart ; echo "RC=$?"
  RC=1
  ```
  ⚠️ **Honnêteté** : `ZStudyLegacyCodec` normalise des **`Map`** (casse, dates, clés
  réservées). Il **ne traduit pas modèle↔modèle** : l'adopter dans le dépôt runtime ne
  supprimerait **pas** les 707 lignes. Le présenter comme la solution serait une capacité
  promise à tort.
- **Forme du canal manquant** : une **couture de mapping neutre** dans `zcrud_mindmap`
  (domaine) — un `ZMindmapExtraCodec` déclarant une fois les clés d'extension et leur
  (dé)sérialisation — consommable **par les deux couches** sans créer d'arête
  `data → presentation`.
- **Bloque ? Non**, mais c'est le plus gros gisement de dérive silencieuse du domaine.

### 3.5 La super-racine du socle ne porte qu'un libellé, pas un titre + une description

- **Socle** : `ZMindmapGraphMapper` regroupe sous une racine **virtuelle non affichée**
  quand `roots.length > 1` (`z_mindmap_graph_mapper.dart:43`, `:57-62`) ;
  la vue liste affiche une super-racine **si et seulement si** un libellé est fourni
  (`z_mindmap_list_view.dart:107`, `:121`, `:133`) ; le libellé est un `String` unique
  (`ZMindmapViewLabels.superRootLabel`, `z_mindmap_view_controls.dart:131`).
- **Hôte** : la racine synthétique porte `title` **et** `description` de la carte
  (`mindmap_model.dart:127-134`, répliqué `mindmap_zcrud_mapper.dart:105-108` sous
  `syntheticRootId = '__iffd_mindmap_synthetic_root__'`).
- **Forme** : un `superRootBuilder` (ou un `superRootContent`) à côté de
  `superRootLabel`, dans `zcrud_mindmap`. Faible priorité — l'hôte contourne par le mapper
  et l'éditeur porté désactive volontairement la racine synthétique
  (`mindmap_outline_zcrud.dart:125-129`).

### 3.6 `ZStudyMindmapSection` existe mais ne répond pas au besoin de l'hôte

- **API** : `ZStudyMindmapSection` `z_study_mindmap_section.dart:76`,
  `ZStudyMindmapMode` `:61`.
- **Corps lu** : c'est une section **singleton** — « `itemCount` vaut **TOUJOURS** `1`
  (la mindmap = section singleton, non triée, non réordonnable) » (`:168-175`) — qui
  bascule lecture ⇄ édition **d'UNE carte**. Elle expose bien `nodeContentBuilder`
  (`:126`) et `outlineController` (`:130`).
- **Besoin de l'hôte** : une section qui **liste N cartes** d'un dossier, réordonnable,
  repliable, avec bouton d'ajout (`study_tools_zcrud_adapter.dart:781-800`).
- ⇒ **Ce n'est pas le même objet.** Le catalogue la présente comme « une section de cartes
  mentales dans la page-détail » (`capacites-zcrud-etude-revision.md:194`) : la formulation
  laisse croire à une liste. Elle ne l'est pas. Le canal qui répond au besoin est
  `ZStudyToolsSectionSpec.mindmaps` (§ 2.9), pas celui-ci.

---

## 4. RESTE À L'HÔTE — règle métier propre à IFFD

| Point | `fichier:ligne` chez l'hôte | Pourquoi le socle ne le porte pas |
|---|---|---|
| Permissions indexées par **année académique** — nom de ressource `"MindmapModel${accademicYear.id}"` | `permission_helpers.dart:83`, `folder_resource_access_service.dart:170` | Modèle d'autorisation propre à l'établissement |
| Verbe CRUD dédié `Crud.aiMindMap("Carte mentale avec l'IA", …, true)` | `domain/security/crud.dart:22` | Vocabulaire de droits IFFD |
| **Deux moteurs de rendu dans une seule entité** (`mindmapViewer: graphite \| flowchart`) | `mindmap_model.dart:101-415` | Choix de produit ; le socle ne connaît que l'arbre (§ 3.2) |
| Le **même** bouton « ajouter » ne crée pas le même objet selon l'écran (graphite au hub `content_hub_zcrud.dart:343` et à la feuille `folder_content_add_dialog_widget.dart:347` ; **flowchart** + titre auto `"… yyyy-MM-dd"` en page d'outils) | `folder_study_tools_page.dart:1983-2020` | Règle d'écran, pas une capacité |
| **Couleurs de branche tirées au sort à chaque rendu** (`Random()` non semé mêlé à une palette de 10 par `Color.lerp(…, 0.5)`) | `mindmap_model.dart:163-207` | Frontalement incompatible avec FR-26 ; à trancher côté hôte (garder ⇒ hors socle ; abandonner ⇒ jetons de thème) |
| **Sept niveaux maximum** (`_maxLevel = 6`) et palette de 7 couleurs de niveau | `graphite_editor_widget.dart:38`, `:324-336` | Contrainte pédagogique |
| **Le style de trait encode la profondeur** (1 → pointillé, 2 → tirets, 3 → tiret-point) | `graphite_mindmap_viewer.dart:400-414` | Convention de lecture IFFD |
| La carte mentale **est** un artefact de message, sérialisée en chaîne JSON dans `ChatbotMessage.mindmap` | `ai_assistant/models/chatbot_message.dart:134`, `:11` | Schéma de message de l'hôte |
| `FirestoreDataState<T>` au lieu de `Either<ZFailure,T>` ; erreurs enveloppées en `FirebaseException` fabriquées | `z_backed_mindmap_repository.dart:610`, `:615-733` | Convention de couche data de l'hôte (le socle recommande AD-5, ne l'impose pas à l'hôte) |
| Collection Firestore `MindmapModel`, requêtes par `folderId`/`subFolderId`/`subjectId`, `streamByIds` en lots + `_combine` maison | `z_backed_mindmap_repository.dart:416`, `:453-497` | Topologie de base propre à IFFD |
| `renormaliserNiveaux` sur `MindmapNode` legacy | `mindmap_outline_zcrud.dart:94-103` (10 l.) | Opère sur le **type legacy** ; `ZMindmapTreeOps.normalizeLevels` opère sur `ZMindmapNode` — les deux sont légitimes |
| **Code mort à supprimer, pas à migrer** : `saveDashboard`/`loadDashboard`/`pickImageBytes` (63 l., 2 fichiers) — **aucun appelant** ; le seul consommateur potentiel est commenté | `hooks_web.dart`, `hooks_mobile.dart`, `folder_mindmap_editor.dart:626-652` | Ménage d'hôte |
| `mindmap_module.dart` **vide** (0 octet) + 5 répertoires vides | `lib/src/features/mindmap/` | Ménage d'hôte |

---

## 5. Récapitulatif chiffré

| Catégorie | Blocs | Lignes d'hôte concernées |
|---|---:|---:|
| **Migrable aujourd'hui** | 10 | **~665 supprimables** |
| **Manque au socle** | 6 | ~1 828 immobilisées (332 IA + 1 084 flow-chart + 59 ordre + 707 mappers, recoupements déduits) |
| **Reste à l'hôte** | 13 | ~1 300 (dont **63 de code mort** à supprimer) |
| **Déjà migré (câblé)** | 13 canaux | 1 126 l. de jumeaux portés, **0 actif** hors artefact de chat |

Détail des ~665 lignes migrables :

| Bloc | § | Lignes |
|---|---|---:|
| Menu d'actions de carte (feuille 216 + popup 118) → `ZItemActionsMenu` | 2.5 | 334 |
| Stubs morts + signatures triplées du port IA → `ZMindmapGenerationPort` | 2.8 | ~116 |
| Section + mappeur d'items → `ZStudyToolsSectionSpec.mindmaps` *(contesté)* | 2.9 | ~64 |
| État vide de l'éditeur → `emptyTitle/emptyMessage/emptyActionLabel` | 2.3 | 59 |
| Formulaire de nœud inline → `editFieldBuilder` | 2.2 | 55 |
| 3 FAB de zoom non bornés → `ZMindmapViewController` | 2.4 | 27 |
| Dialogue de confirmation (site mindmap) → `showZConfirmDialog` | 2.6 | ~10 |
| Compteur de nœuds → `zMindmapNodeCount` | 2.10 | ~10 |
| `nodeContentBuilder` (gap bloquant, 0 ligne) | 2.1 | 0 |
| `onConfirmDelete` (régression évitée, 0 ligne) | 2.7 | 0 |

---

## 6. ⚠️ Deux constats de `carte-mindmap.md` INFIRMÉS

| Affirmation de la carte | Remesure | Verdict |
|---|---|---|
| § 6 : « `MindmapActionsDialogWidget` → **`ZRowActionMenu`** (`zcrud_screen`, 176 l.) / `ZActionMenu` (`zcrud_menu`) » | `grep -rn 'ZRowActionMenu' --include='*.dart' packages/` → **RC=1, aucune sortie**. Idem côté IFFD (RC=1). | ❌ **`ZRowActionMenu` n'existe pas.** Le canal réel est `ZItemActionsMenu` (`zcrud_study/…/z_item_actions_menu.dart:283`) au-dessus de `ZActionMenu` (`zcrud_menu/…/z_action_menu.dart:18`). Corrigé au § 2.5. |
| § 7 : « `ZMindmapMarkdownContent` … ce qu'IFFD fait à la place : `ZcrudMindmapView` ne passe pas `nodeContentBuilder` → texte brut » — laisse entendre que `ZMindmapMarkdownContent` est le canal à adopter | Corps lu : `z_mindmap_markdown_content.dart:80-95` lit des **ops Delta** dans `extra[slotKey]`, `:110-115` rend via `const ZDeltaCodec()`. Le corpus IFFD est du markdown dans `content`, **0 Delta**. | ⚠️ **Canal inapplicable.** Le seam correct est `nodeContentBuilder` **nu**, alimenté par la fabrique que l'hôte possède déjà (`mindmap_rich_reader_zcrud.dart:138`). Précisé au § 2.1. Même correction pour `ZMindmapMarkdownEditField` vs `editFieldBuilder` (§ 2.2). |

Une affirmation du catalogue est également **nuancée** : `ZStudyMindmapSection`
(`capacites-zcrud-etude-revision.md:194`, « une section de cartes mentales dans la
page-détail ») est une section **singleton** (`itemCount` toujours 1,
`z_study_mindmap_section.dart:168-175`), pas une liste de cartes — cf. § 3.6.

---

## 7. Ce que ce relevé n'a PAS établi

- **Le coût runtime du portage du lecteur riche.** L'hôte le décrit comme le pire cas du
  périmètre (deux `ZMarkdownReader` par nœud, tous montés hors écran simultanément pendant
  la phase de mesure, `graphite_mindmap_viewer.dart:332-359` ; note de QA
  `z_qa_flags.dart:645-655`). Aucune mesure n'existe, et **je n'ai lancé aucun test**.
  Le chiffre « 9 093 valeurs de nœuds » est une affirmation d'hôte recopiée d'un
  commentaire (`z_iffd_rich_text_codec.dart:9`), **non remesurée**.
- **Les volumes en base** (nombre de cartes, part de cartes `flowchart`) : illisibles
  depuis les dépôts.
- **La fermeture transitive** d'un ajout de dépendance : `zcrud_menu`, `zcrud_mindmap`,
  `zcrud_study`, `zcrud_ui_kit`, `zcrud_screen`, `zcrud_markdown`, `zcrud_firestore` sont
  **déjà déclarés** chez l'hôte (`iffd/pubspec.yaml:340`, `:345`, `:391`, `:440`, `:524`,
  `:355`, `:310`) — aucun des chantiers du § 2 n'ajoute de paquet. Je n'ai pas résolu le
  graphe au-delà de cette lecture.
- **L'ancienneté des coutures.** `git log -S` situe `onConfirmDelete` en v0.15.0,
  `emptyBuilder` en v0.54.0, `ZStudyToolsSectionSpec.mindmaps` en v0.45.0 ;
  `ZMindmapViewController`, `editFieldBuilder` et `ZMindmapGenerationPort` ne remontent
  qu'à la passe de documentation `f97ebf6c1`, ce qui **ne date pas leur introduction**.
  Aucun de ces canaux n'est « récent » : ce ne sont pas des livraisons de la vague
  3.13→3.21 que l'hôte pourrait ignorer de bonne foi.

Aucun test n'a été lancé, dans aucun dépôt. Aucun fichier hors de
`docs/analyses/iffd-migration-2026-08-26/` n'a été écrit.
