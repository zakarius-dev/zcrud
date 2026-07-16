# Reconnaissance — `zcrud_mindmap` : affichage & édition (audit de parité IFFD/graphite)

Périmètre : `packages/zcrud_mindmap/` (domaine `lib/src/domain/`, présentation `lib/src/presentation/`),
+ usage en composition dans `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart`.

## Verdict de tête

`zcrud_mindmap` fournit un **rendu de graphe interactif RÉEL, DANS le package**, via la
librairie `graphite` (`dependencies: graphite: ^1.2.1` dans le pubspec, import direct
`package:graphite/graphite.dart` dans `z_mindmap_view.dart`). Ce n'est **pas** un
simple mapper laissant l'app instancier `graphite` elle-même : `ZMindmapView` construit
directement un `DirectGraph` (widget `graphite`). `z_mindmap_graph_mapper.dart` est la
brique de **projection pure** (forêt `ZMindmapNode` par nesting → `NodeInput`/`EdgeInput`
plats consommés par `DirectGraph.list`), interne au package, pas exposée comme contrat
pour que l'app fasse le rendu elle-même.

⚠️ Différence avec IFFD : IFFD historique utilise **`graphview`** (+ un legacy
`flutter_flow_chart` explicitement NON porté), zcrud utilise **`graphite`** — pas un
copier-coller, mais une réimplémentation propre avec la même famille de capacité
(auto-layout de graphe orienté).

---

## 1. Capacités (C1…C16)

**C1 — `ZMindmap`** (domaine, forêt titrée). Fichier `lib/src/domain/z_mindmap.dart`.
Entité racine immuable : `id`, `folderId`, `title`, `description?`, `nodes` (racines de
forêt, multi-racine autorisé), slots AD-4 (`extension`, `extra`). Sync (`updatedAt`,
`isDeleted`) explicitement **HORS-ENTITÉ** (AD-16) — jamais sur `ZMindmap`. `fromJson`/
`toJson` défensifs.

**C2 — `ZMindmapNode`** (domaine, nœud d'arbre). Fichier `lib/src/domain/z_mindmap_node.dart`.
Étend `ZNode` (id de réconciliation), mixe `ZExtensible`. Topologie par **nesting**
(`children` imbriqués, jamais adjacency). Voir structure détaillée §2.

**C3 — `ZMindmapTreeOps`** (domaine, moteur pur d'arbre). Fichier
`lib/src/domain/z_mindmap_tree_ops.dart`. Classe utilitaire statique, immuable,
**structural sharing** (`identical()` sur tout sous-arbre non affecté). Voir opérations
détaillées §4.

**C4 — `ZMindmapApi`** (marqueur de version publique, placeholder). Fichier
`lib/src/domain/z_mindmap_api.dart`. Expose juste des constantes de version (`version`,
`coreApiVersion`, `markdownApiVersion`) — sert à matérialiser les arêtes AD-1 vers
`zcrud_core`/`zcrud_markdown`. Pas une API fonctionnelle.

**C5 — `ZMindmapView`** (vue de lecture graphe + liste). Fichier
`lib/src/presentation/z_mindmap_view.dart`. Deux surfaces équivalentes basculables
(`ZMindmapViewMode.graph`/`.list`) : graphe `graphite` auto-agencé (orientation
descendante, `MatrixOrientation.Vertical`) OU liste sémantique indentée (`ZMindmapListView`,
surface a11y de référence). **Lecture seule** — toute interaction remonte par callback
(`onNodeTap`, `onNodeSelected`), jamais de mutation d'arbre. Zoom/pan bornés via
l'`InteractiveViewer` interne de `graphite` (bornes `minScale`/`maxScale` de
`ZMindmapViewConfig`) ; **aucun drag libre de nœud**.

**C6 — `ZMindmapViewController` + `ZMindmapViewLabels`** (contrôles user-facing, opt-in,
ES-7.2). Fichier `lib/src/presentation/z_mindmap_view_controls.dart`. `ChangeNotifier`-like
(agrégat de `ValueNotifier`) pur-Flutter : zoom piloté/clampé (`zoomIn`/`zoomOut`/
`resetZoom`/`setScale`), toggle **compact** (rendu condensé label-seul), toggle
**plein-écran** (`SizedBox.expand` occupant l'espace hôte), toggle **super-racine**
(affiche un nœud groupant la forêt multi-racine, réutilise `usesVirtualRoot` du mapper).
100 % optionnel : `controller == null` ⇒ comportement E10 strict inchangé (aucune barre).
Le zoom `graphite` interne n'étant pas pilotable en 1.2.1 (`TransformationController`
absent du constructeur), le zoom piloté est simulé par un `Transform.scale` EXTERNE (le
zoom interne est alors neutralisé `minScale=maxScale=1`, pan interne conservé).

**C7 — `ZMindmapGraphMapper`** (mapping vers `graphite`). Fichier
`lib/src/presentation/z_mindmap_graph_mapper.dart`. Fonctions **pures**, projette la
forêt `ZMindmapNode` (nesting) vers `NodeInput`/`EdgeInput` **plats** (adjacency
`parent.id → child.id`) consommés directement par `DirectGraph.list` de `graphite`.
Multi-racine ⇒ insertion d'une **racine virtuelle** non affichée
(`virtualRootId = '__zcrud_mindmap_virtual_root__'`) reliant les vraies racines par des
arêtes sans flèche, pour donner un point d'entrée unique à `graphite` (qui exige un seul
nœud sans income) ; racine virtuelle exclue du rendu (widget de taille nulle) et de la
sémantique. Mono-racine ⇒ pas de racine virtuelle. **C'est un mapper interne au moteur
de rendu du package**, pas une API que l'app doit consommer pour faire son propre rendu
`graphite` — bien qu'exportée dans le barrel, donc réutilisable si une app veut composer
`graphite` différemment.

**C8 — `ZMindmapNodeCard` + `ZMindmapDefaultNodeContent`** (carte de nœud thématisée,
partagée graphe/liste). Fichier `lib/src/presentation/z_mindmap_node_card.dart`. Rendu
par défaut : `label` texte brut thématisé (repli sur extrait de `content` si `label`
vide), cible ≥ 48 dp, couleurs 100 % `ZcrudTheme` (aucun littéral). Mode **compact**
(ES-7.2) : rendu condensé label-seul mono-ligne, masque tout `contentBuilder` injecté.
Sélection surlignée (bordure) via un `isSelected` déjà résolu par l'appelant (pas de
double-abonnement).

**C9 — `ZMindmapListView`** (vue liste = surface a11y de référence). Fichier
`lib/src/presentation/z_mindmap_list_view.dart`. Parcours profondeur-d'abord,
`ListView.builder`, indentation dérivée de `level` (`EdgeInsetsDirectional.only(start:)`),
`Semantics` explicite par entrée (label, profondeur annoncée « niveau N », état
sélectionné, action d'activation pour lecteur d'écran). Supporte le mode compact et la
super-racine (mêmes tranches que `ZMindmapView`). Lecture seule.

**C10 — `ZMindmapMarkdownContent`** (seam rich-text opt-in du contenu de nœud, ES-7.2/
OQ-S5). Fichier `lib/src/presentation/z_mindmap_markdown_content.dart`. Adaptateur mince
composant `ZMarkdownReader` + `const ZDeltaCodec()` (codec identité) de `zcrud_markdown`.
`ZMindmapNode.content` reste **texte brut** dans le modèle canonique ; ce widget lit un
payload rich (ops Delta neutres) depuis `node.extra[slotKey]` (slot AD-4, clé applicative
non imposée par le cœur) et le rend en rich-text ; repli texte brut si absent/mal formé
(AD-10, jamais de throw, aucune heuristique de détection de format). Fournit
`ZMindmapMarkdownContent.builder(slotKey:)` = fabrique de `nodeContentBuilder` injectable
dans `ZMindmapView`. **Le défaut de `ZMindmapView` reste texte brut** — le rich-text est
un choix explicite de l'app hôte.

**C11 — `ZMindmapOutlineController`** (contrôleur d'édition, source de vérité unique,
E10-3). Fichier `lib/src/presentation/z_mindmap_outline_controller.dart`. `ChangeNotifier`
pur-Flutter détenant la forêt éditée ; toute mutation passe par `ZMindmapTreeOps` et
**remplace** la forêt interne en continu, de sorte que `controller.forest` reflète
toujours l'état édité — **correction par conception** du bug historique lex/IFFD où la
sauvegarde pouvait re-persister l'arbre d'origine par-dessus les modifications
(« dette n°5 », doc cite explicitement `_reconstructTree`/algo « dernier nœud connu par
niveau » d'IFFD comme référence à couvrir). `TextEditingController` **stables** par nœud
(keyés par id, jamais recréés) pour `label` et `content`. Édition de texte
(`editLabel`/`editContent`) **ne notifie PAS** (le champ porte déjà le texte, zéro
rebuild global, zéro perte de focus, SM-1) ; mutations structurelles
(`addChild`/`addSibling`/`addRoot`/`deleteNode`/`indent`/`outdent`/`moveUp`/`moveDown`)
**notifient** (reconstruisent l'outline aplati). Purge les controllers du sous-arbre
supprimé (anti-fuite mémoire).

**C12 — `ZMindmapOutlineEditor`** (widget d'édition outline arborescente, E10-3). Fichier
`lib/src/presentation/z_mindmap_outline_editor.dart`. Liste indentée éditable : par
défaut crée/possède un `ZMindmapOutlineController` interne (ou en accepte un injecté).
Par nœud : champ `label` (TextField), champ `content` optionnel (texte brut multiligne,
`editContentField`), barre d'actions (ajouter enfant/frère, indenter, désindenter, monter,
descendre, supprimer) — chaque action ≥ 48 dp, `Semantics(button:true)`. Barre d'outils
supérieure : « ajouter une racine » + « enregistrer » (`onSave` optionnel, émet
`controller.forest`). `onChanged` optionnel pour mode auto-save. `ListenableBuilder`
unique au niveau structurel (une frappe ne reconstruit pas la liste, SM-1).

**C13 — `ZMindmapOutlineLabels`** (libellés a11y externalisés de l'éditeur outline).
Fichier `lib/src/presentation/z_mindmap_outline_labels.dart`. Bundle immuable (11 champs :
addChild/addSibling/delete/indent/outdent/moveUp/moveDown/addRoot/save/labelHint/
contentHint), repli neutre non-nul, surchargeable pour i18n.

**C14 — `ZStudyMindmapSection`** (composition study-tools, PAS dans `zcrud_mindmap` mais
dans `zcrud_study`). Fichier `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart`.
Adaptateur mince qui assemble `ZMindmapView` (lecture) et `ZMindmapOutlineEditor`
(édition) avec une bascule lecture⇄édition locale (`ValueNotifier`), dans le layout
sectionné study-tools. Explicite dans sa doc : « SANS jamais réimplémenter le moteur
graphite ni porter le flowchart legacy IFFD » — confirme que le graphe est bien rendu par
`zcrud_mindmap`, jamais recodé par l'app/l'orchestrateur.

**C15 — génération/fabrique de nœuds** (`ZMindmapTreeOps.newRootNode`/`newChildNode`).
UUID v4 généré sans dépendance externe (`Random.secure`). Fabriques triviales, pas de
génération de contenu.

**C16 — Config de layout (`ZMindmapViewConfig`)**. Fichier
`lib/src/presentation/z_mindmap_view_config.dart`. Constantes géométriques immuables :
`minScale`/`maxScale` (bornes zoom `graphite`), `cellSize`/`cellSpacing` (taille/espacement
des cellules du graphe auto-agencé), `indentStep` (pas d'indentation liste/outline),
`minTapTarget` (≥ 48 dp, AD-13). Aucune couleur (couleurs = `ZcrudTheme`).

---

## 2. Structure des entités

### `ZMindmapNode`
| Champ | Type | Notes |
|---|---|---|
| `id` | `String` | clé de réconciliation `ZNode`, non-null |
| `label` | `String` | titre court mono-ligne, défaut `''` |
| `content` | `String?` | **texte brut multiligne** (PAS markdown/rich — le rendu riche est un slot AD-4 opt-in, cf. C10) |
| `level` | `int` | cache de profondeur dénormalisé (racine = 0), **recalculé systématiquement** par `ZMindmapTreeOps`, jamais fait confiance après reparentage |
| `children` | `List<ZMindmapNode>` | topologie par **nesting**, copiée défensivement (unmodifiable) |
| `extension` | `ZExtension?` | slot AD-4 typé versionné (`formatVersion`), sous-classes vivent hors du cœur |
| `extra` | `Map<String,dynamic>` | échappatoire AD-4, défaut `{}`, jamais `null`, round-trip des clés inconnues |

Pas de couleur, pas d'icône, pas de position (x/y) dans le modèle — le positionnement est
délégué entièrement à l'auto-layout `graphite` au rendu (aucune coordonnée persistée).
Aucun `copyWith` public : mutation exclusivement via `ZMindmapTreeOps`.

### `ZMindmap`
| Champ | Type | Notes |
|---|---|---|
| `id` | `String` | opaque |
| `folderId` | `String` | clé de sous-collection / filtrage |
| `title` | `String` | défaut `''` |
| `description` | `String?` | optionnelle |
| `nodes` | `List<ZMindmapNode>` | **racines de la forêt** (multi-racine autorisé) |
| `extension` | `ZExtension?` | slot AD-4 au niveau carte |
| `extra` | `Map<String,dynamic>` | échappatoire AD-4 |

**Invariant dur (AD-16)** : `ZMindmap` ne porte NI `updatedAt` NI `isDeleted` — sync
100% hors-entité (`ZSyncMeta`, géré par le store, hors périmètre `zcrud_mindmap`). Pas de
`copyWith` public non plus.

---

## 3. Édition (résumé transverse)

- **`ZMindmapTreeOps`** (moteur pur, C3) : `updateNode` (label/content), `addChild`,
  `deleteNode` (sous-arbre entier), `findNode`, `moveNode` (reparentage + anti-cycle +
  recalcul `level` en cascade), `indentNode`/`outdentNode` (rattachement frère précédent /
  frère du parent), `reorderChild` (réordonne une fratrie, `level` inchangé),
  `normalizeLevels` (renormalise toute une forêt, utilisé en désérialisation défensive).
  Toutes no-op `identical` si sans effet (structural sharing total).
- **Outline editor/controller** (C11/C12) : édition arborescente complète — ajout
  enfant/frère/racine, suppression, indent/outdent, réordonnancement, édition de texte —
  **avec sauvegarde fiable** (corrige le bug historique de perte d'edits au save côté
  IFFD/lex).
- **Édition du contenu markdown d'un nœud** : **PAS dans le modèle canonique**
  (`content` reste texte brut). Le rich-text est un **slot lecture seule opt-in**
  (`ZMindmapMarkdownContent`, C10) — il n'y a **aucun éditeur riche** de nœud dans
  `zcrud_mindmap` (pas de `ZMarkdownField` câblé sur un nœud), seulement un **lecteur**
  optionnel. Toute édition riche du contenu d'un nœud serait à construire côté app en
  composant `zcrud_markdown` sur le slot `extra`.
- **Édition du graphe elle-même (drag de nœud, repositionnement manuel)** : **ABSENTE**.
  Le graphe est **auto-agencé** par `graphite` (`DirectGraph`), sans callback de pan de
  nœud câblé — aucun drag libre. L'édition structurelle (add/delete/move) se fait
  exclusivement via la **vue liste/outline**, jamais en manipulant directement le graphe
  visuel.

---

## 4. Affichage (résumé transverse)

- **`ZMindmapView`** (C5) bascule graphe ⇄ liste, zoom/pan bornés (graphe), lecture
  seule stricte, callbacks de sélection/tap uniquement.
- **Graphe** : rendu **réellement fourni** par le package via `graphite.DirectGraph`,
  orientation descendante, cellules configurables (`ZMindmapViewConfig.cellSize`/
  `cellSpacing`), `ExcludeSemantics` (surface visuelle, pas la référence a11y).
- **Liste** (`ZMindmapListView`, C9) = **surface a11y de référence** obligatoire pour
  toute équivalence fonctionnelle graphe⇄liste (AD-13).
- **Contrôles utilisateur** (`ZMindmapViewController`, C6) : zoom in/out/reset piloté,
  compact, plein-écran, super-racine — tous **opt-in**, additifs, non présents par défaut.
- **`ZMindmapGraphMapper`** (C7) : mapping pur nesting → `NodeInput`/`EdgeInput` plats
  pour `graphite`, **interne au rendu du package**.

---

## 5. ABSENT / PORT-SEULEMENT / DÉLÉGUÉ À L'APP

- **Rendu graphe interactif** : **FOURNI** dans le package (verdict de tête). Pas
  délégué, pas mapper-only.
- **Drag libre de nœud dans le graphe (repositionnement manuel à la souris/tactile)** :
  **ABSENT** — auto-layout uniquement, aucun callback de pan de nœud câblé, `graphite`
  gère seul le placement. Aucune coordonnée x/y n'est même stockée dans `ZMindmapNode`.
- **Édition riche (markdown/LaTeX) du contenu d'un nœud** : **PORT/opt-in en lecture
  seule uniquement** (`ZMindmapMarkdownContent` = lecteur, pas d'éditeur). Le champ
  `content` du modèle canonique reste texte brut par design ; tout éditeur riche de nœud
  serait à construire côté app (composition `zcrud_markdown`).
- **Génération IA de mindmap** (ex. génération auto d'une carte à partir d'un
  document/résumé) : **ABSENT** de `zcrud_mindmap`. Il n'existe aucun port dédié
  `ZMindmapGenerationPort` (contrairement à `ZFlashcardGenerationPort` qui existe pour
  les flashcards). Le seul artefact voisin trouvé est `ZAiExplanationPort` /
  `ZNoteSummaryPort` dans **`zcrud_study`** (`packages/zcrud_study/lib/src/domain/
  z_ai_explanation_port.dart` / `z_note_summary_port.dart`) — un port générique
  d'explication/texte, **sans lien structurel avec `ZMindmap`** (retourne `String`, pas
  une forêt de nœuds). Le doc `docs/study-integration-inventory.md` liste par ailleurs
  une **« génération IA mindmap/résumé/explication dossier »** comme seam **proposé**
  (`ZAiExplanationPort`, `ZNoteSummaryPort`) — traité comme point d'extension futur, pas
  une capacité de génération de mindmap dédiée et livrée.
- **Export (PDF/image/OPML/JSON structuré pour interop externe)** : **ABSENT**. Seule la
  sérialisation JSON canonique interne existe (`ZMindmap.toJson`/`fromJson`,
  `ZMindmapNode.toJson`/`fromJson`) — pas un export utilisateur (pas de PDF/PNG/OPML).
  `zcrud_export` (PDF/Excel Syncfusion) n'a **aucune** référence à `ZMindmap`/mindmap
  dans son code (`z_export_api.dart` grep vide).
- **Import depuis un format externe (OPML, XMind, etc.)** : **ABSENT**.
- **Mode flowchart legacy IFFD (`flutter_flow_chart`)** : **explicitement NON porté**
  (doc `study-integration-inventory.md` : « Ne PAS porter le mode flowchart legacy »).
- **Couleur par nœud** (IFFD a potentiellement des couleurs de nœud/carte) : **ABSENT**
  du modèle canonique `ZMindmapNode` — pas de champ couleur ; tout badge/couleur custom
  passerait par `extra`/`extension` (AD-4) + un `nodeContentBuilder` custom côté app.
- **Position/coordonnées de nœud persistées** : **ABSENT** — auto-layout systématique,
  jamais de x/y stocké.
