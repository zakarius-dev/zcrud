# Reconnaissance mindmaps — lex_douane (source canonique)

Périmètre : `lex_core` (domaine), `lex_ui` (présentation), `lex_data` (repo). IGNORÉ : `apps/lex_douane_admin`.

## Bibliothèque de rendu graphe

`packages/lex_ui/pubspec.yaml:52` → `graphview: ^1.5.1` (PAS `graphite`).
`mindmap_view.dart` importe `package:graphview/GraphView.dart` et utilise
`BuchheimWalkerAlgorithm` + `BuchheimWalkerConfiguration` (`TreeEdgeRenderer`),
orientation `ORIENTATION_TOP_BOTTOM`. **Auto-layout pur** : aucun `Draggable`,
aucune position de nœud stockée ni manipulable — le layout est l'unique source
de position, recalculé à chaque build. Zoom/pan via `InteractiveViewer`
(`TransformationController`), boutons zoom in/out overlay (cible ≥48dp).

## L1..Ln — Fonctionnalités

**L1. Entité `Mindmap`** (carte persistée) — `lex_core/lib/domain/entities/education/mindmap.dart`, classe `Mindmap`.
Champs : `id`, `folderId`, `title`, `nodes: List<MindmapNode>` (racines — supporte multi-racines). `@JsonSerializable(fieldRename: snake)`. Pas de `updatedAt` intra-entité (LWW porté hors-entité par le repo, comme `is_deleted`).

**L2. Entité `MindmapNode`** (nœud canonique, partagé chat↔éducation) — `lex_core/lib/domain/entities/lexia_mindmap.dart`, classe `MindmapNode`.
Champs : `id: String`, `label: String`, `content: String?` (texte libre, PAS de markdown/Delta — simple `String`), `children: List<MindmapNode>` (récursif), `level: int` (profondeur, racine=0). **Aucun champ couleur, taille, ni position (x/y)**. Pas de `copyWith` (immutabilité stricte, reconstruction par constructeur — cf. `MindmapTreeOps`).

**L3. `LexiaMindmap`** (mindmap éphémère produite par le chat IA, pré-attachement) — `lex_core/lib/domain/entities/lexia_mindmap.dart`, classe `LexiaMindmap` : `title?`, `description?`, `root: MindmapNode` (racine **unique**, pas de forêt). Distincte de `Mindmap` (persistée) — mappée vers `Mindmap` via `attachMindmapToFolder`.

**L4. `MindmapsRepository`** (port domaine) — `lex_core/lib/domain/repositories/mindmaps_repository.dart`. `dataChanges` (Stream), `mindmapsStream(folderId)`, `getMindmaps`, `getMindmap`, `saveMindmap`, `deleteMindmap`, `sync()`, `dispose()`. Tout en `Either<Failure,T>`. Offline-first Hive-first + Firestore fire-and-forget, sous-collection `users/{uid}/study_folders/{folderId}/mindmaps/{mapId}`, LWW sur `updated_at` hors-entité.

**L5. `MindmapTreeOps`** (transformations d'arbre pures) — `lex_core/lib/domain/utils/mindmap_tree_ops.dart`. Opérations disponibles :
- `updateNode(roots, nodeId, {label?, content?})` — rename + édition contenu (recherche récursive, structural sharing).
- `addChild(roots, parentId, child)` — ajout d'un enfant (dernier de la fratrie).
- `deleteNode(roots, nodeId)` — suppression du nœud + tout son sous-arbre.
- `newRootNode()` / `newChildNode(parentLevel)` — fabriques (id UUID v4, label vide, content null).
- `findNode(roots, nodeId)` — recherche en profondeur.
**ABSENT** : pas de `move`/`reparent`, pas de `reorder` (réordonnancement de fratrie), pas d'`indent`/`outdent`. L'arborescence ne se modifie que par add-child / delete / rename — pas de réorganisation topologique une fois créée.

**L6. `MindmapView`** (widget viewer/éditeur réutilisable) — `lex_ui/lib/presentation/widgets/study/mindmap_view.dart`. Rend une forêt de `MindmapNode` en graphe auto-agencé (`graphview`/`BuchheimWalkerAlgorithm`), `InteractiveViewer` (zoom/pan). Deux modes : `interactive:true` (tap nœud → callback `onTapNode`, écran plein) et `compact:true` (chat, read-only, hauteur bornée 220px). Multi-racines gérées via super-racine invisible (le layout exige un arbre unique). Style nœud : `primaryContainer` si `level==0`, `secondaryContainer` sinon — **couleur dérivée du niveau, pas persistée par nœud**. Icône indicateur si `content` non vide.

**L7. `StudyMindmapScreen` / `_MindmapEditorForm`** (écran plein éditeur) — `lex_ui/lib/presentation/screens/study_mindmap_screen.dart`. Sentinelle `mindmapId=='new'` = création (racine vide par défaut). Persistance **à chaque mutation** (pas de bouton save global) via `studyContentControllerProvider.saveMindmap`. FAB « ajouter nœud » (ajoute un enfant à la 1ère racine). Bascule **Graphe / Liste sémantique** en AppBar (icône `list_rounded`/`account_tree_rounded`).

**L8. `_MindmapListView`** (vue liste = **outline arborescent**, surface a11y de référence) — même fichier. Arbre aplati en profondeur, indentation proportionnelle à `level` (`EdgeInsetsDirectional.only(start: 16 + level*20)`), chaque ligne = `Semantics` + tap → même feuille d'édition que le graphe. Explicitement documentée comme « le canvas n'est pas lisible au lecteur d'écran » → la liste est la voie d'édition alternative accessible.

**L9. `MindmapNodeEditSheet`** (feuille d'édition de nœud, bottom sheet) — même fichier. Deux `TextField` : `label` (mono-ligne) et `content` (multiligne, `minLines:2 maxLines:5`, **texte brut, pas d'éditeur markdown/riche**). Actions : Ajouter un enfant / Supprimer (avec confirmation si sous-arbre non vide) / Enregistrer. Ne mute rien elle-même — renvoie l'intention à l'écran qui applique `MindmapTreeOps` (pur).

**L10. Édition titre** — dialog simple (`AlertDialog` + `TextField`) déclenché en tapant le titre en AppBar ; persiste en ré-appliquant la forêt courante.

**L11. Génération IA de mindmap (via chat Lexia)** — backend `backend/app/services/agents/prompts/education/mindmap_generator.py` (prompt système, sortie structurée Pydantic, contrainte `maxDepth`, schéma canonique `{id,label,content?,children[],level}`) + `backend/app/services/education/mindmap_service.py`. Côté UI : pas un « générateur dédié » façon `document_generate_sheet.dart` — le LLM produit un `MindmapBlock` **inline dans une réponse de chat**, rendu nativement par `content_block_renderer.dart::_buildMindmapBlock` (via `MindmapView` compact, read-only) avec un bouton **« Attacher »** (`onAttachMindmap`). `content_block_attach.dart::attachMindmapToFolder` mappe le `LexiaMindmap` éphémère (racine unique) vers l'entité persistable `Mindmap` (`nodes:[mindmap.root]`) et appelle `MindmapsRepository.saveMindmap`.

**L12. Création manuelle depuis le hub** — `add_content_hub_sheet.dart` : entrée « Mindmap » (`hubMindmap`), gate par `StudyEditorAvailability.mindmapEditor` (flag feature).

**L13. Suppression depuis le menu d'item** — `study_item_actions_menu.dart` : `StudyItemKind.mindmap` → `controller.deleteMindmap(itemId)`, confirmation dialog dédiée.

## Export/Import

**ABSENT.** Aucune trace d'export PDF/Excel/JSON ni d'import de mindmap externe — seul chemin d'entrée externe = la génération IA via chat (bloc attaché au dossier), pas un fichier importé.

## Réponses FOCUS (a-d)

**(a) Rendu auto-layout ?** PRÉSENT — package `graphview` (`^1.5.1`), algorithme `BuchheimWalkerAlgorithm` (arbre, orientation top-bottom), **zéro drag libre de nœud** (pas de `Draggable`, aucune position persistée). Zoom/pan seulement via `InteractiveViewer`.

**(b) Édition markdown/LaTeX du contenu d'un nœud ?** ABSENT. Le `content` d'un `MindmapNode` est un `String?` simple édité par un `TextField` multiligne brut dans `MindmapNodeEditSheet` — pas de `ZCodec`/Quill/Delta, pas de rendu markdown, pas d'embed LaTeX.

**(c) Génération IA de mindmap ?** PRÉSENT — prompt dédié backend (`mindmap_generator.py`, structured output Pydantic, contrainte de profondeur `maxDepth`), déclenché depuis une conversation de chat avec l'assistant Lexia (pas un bouton « Générer » dans l'écran Study lui-même) ; résultat rendu inline (`MindmapBlock`) avec action « Attacher au dossier » qui persiste via `MindmapsRepository`.

**(d) Couleur/taille/position persistées par nœud ?** ABSENT. `MindmapNode` ne porte que `id/label/content/children/level`. La couleur affichée (`primaryContainer` racine vs `secondaryContainer` reste) est **calculée depuis `level`** au rendu, jamais stockée ; aucune taille ni position (x/y) en entité — le layout `graphview` recalcule tout à chaque build.

## Couplage

- `zcrud`-side comparable : `zcrud_mindmap` (`ZMindmap`, `ZMindmapTreeOps`, `ZMindmapView`) — confirmer alignement des noms d'opérations `MindmapTreeOps` (update/addChild/deleteNode/newRootNode/newChildNode/findNode) et l'absence côté source de move/reorder/indent-outdent (donc pas un gap zcrud vs lex_douane sur ce point précis).
- `MindmapNode` est **partagé** entre le module chat (blocs IA) et le module éducation (`Mindmap.nodes`) — un seul schéma canonique, pas de structure de nœud parallèle (contrainte explicite du code, « Enforcement n°3 »).
- Rendu 100% Riverpod (`ConsumerStatefulWidget`/`ConsumerWidget`) — couplage fort au binding Riverpod côté lex_ui (attendu, lex_douane = conso Riverpod).
