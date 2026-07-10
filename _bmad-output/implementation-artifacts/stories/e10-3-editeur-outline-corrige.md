---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 10.3 : Éditeur outline corrigé

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**intégrateur d'une app de cartes mentales (lex_douane, DODLP)**,
je veux **un éditeur outline (liste indentée éditable) pour une forêt `ZMindmap`, dont la SAUVEGARDE applique RÉELLEMENT toutes les modifications (édition de `label`/`content`, ajout, suppression, indent/outdent, réordonnancement) via `ZMindmapTreeOps`, et remonte à l'app hôte la forêt effectivement mutée**,
afin de **corriger par conception le bug historique du `MindmapView`/éditeur de lex — où les modifications saisies étaient perdues à la sauvegarde (la persistance recevait l'arbre d'origine, non muté)** — sans réintroduire un `setState` global, sans coupler l'éditeur à un gestionnaire d'état, et sans casser la lecture-seule livrée en E10-2.

## Contexte & valeur

- **Épic E10 (Cartes mentales, `zcrud_mindmap`, v1.x)** — objectif : modèle / tree-ops / vue / **édition** additifs pour lex_douane. Couvre **FR-19** ; AD-1, AD-2, AD-4, AD-13, AD-15, FR-26. Dépend de E2, E6. [Source: epics.md#E10]
- **Story E10-3 = l'ÉDITEUR OUTLINE CORRIGÉ.** AC de l'épic (verbatim) : « **sauvegarde applique réellement les modifications (bug lex corrigé)** ». C'est le **livrable clé** de l'épic : la vue lecture (E10-2) n'écrivait rien ; ici on édite et on **persiste réellement** ce qui a été édité. [Source: epics.md#E10 Story E10-3]
- **Le bug lex à corriger (dette n°5, canonique §Enforcement).** Le docstring FR-30 de `MindmapTreeOps` de lex annonçait add/move/indent/outdent mais **seuls add/update/delete/find étaient codés** ; le reparentage n'existait pas, et l'éditeur outline de lex **mutait une copie UI locale sans jamais la reverser** au chemin de sauvegarde → **les edits étaient perdus à la sauvegarde**. zcrud a déjà comblé la **moitié moteur** en E10-1 (`moveNode`/`indentNode`/`outdentNode`/`reorderChild` codés + recalcul de `level`). E10-3 comble la **moitié UI+wiring** : un éditeur dont **la sauvegarde reverse RÉELLEMENT la forêt mutée**. [Source: docs/canonical-schema.md#5 (dette n°5) ; e10-1-zmindmapnode-treeops.md]
- Consomme **strictement** ce qui est livré par **E10-1** (`ZMindmap`, `ZMindmapNode`, `ZMindmapTreeOps`) et **E10-2** (`ZMindmapViewConfig`, `ZMindmapNodeContentBuilder`, `ZMindmapNodeCard`, patrons a11y/thème) — **NE PAS recréer** ces types, **NE PAS ré-implémenter** les mutations d'arbre (toutes les mutations passent par `ZMindmapTreeOps`). [Source: e10-1-zmindmapnode-treeops.md ; e10-2-zmindmapview-graphite.md]
- **CONTRAINTE DURE : cette story NE MODIFIE PAS `zcrud_core`.** Les seams `ZcrudTheme`/`ZcrudScope`/`ZNode`/`ZExtensible` existent déjà et suffisent. Aucune mutation d'arbre n'est ré-écrite : `ZMindmapTreeOps` (E10-1) est l'unique moteur. [Source: CLAUDE.md#Key-Don'ts ; e10-2 Dépendance détectée]

## Acceptance Criteria

**AC1 — Éditeur outline : liste indentée éditable d'une forêt `ZMindmap`.**
- Un widget public **`ZMindmapOutlineEditor`** (pur-Flutter) prend en entrée une **forêt `ZMindmap` immuable** (ou `List<ZMindmapNode>` racines) et affiche un **outline indenté** : parcours **profondeur-d'abord**, **une ligne par nœud**, **indentation dérivée de `level`** via `EdgeInsetsDirectional.only(start: level * indentStep)` (**JAMAIS** `left:`), rendu par **`ListView.builder`** (jamais `ListView(children:)`). [Source: canonical-schema.md#2.2 ; architecture.md#AD-13 ; CLAUDE.md#Key-Don'ts]
- Chaque ligne expose un **champ texte éditable** pour `label` (au minimum ; `content` éditable via un second champ OU un mode déplié — le choix documenté en Dev Notes), et des **affordances d'action** par nœud : **ajouter un enfant**, **ajouter un frère**, **supprimer**, **indenter** (`indentNode`), **désindenter** (`outdentNode`). Le réordonnancement de fratrie (`reorderChild`) est exposé (boutons monter/descendre au minimum ; un `ReorderableListView` est optionnel et non requis). [Source: z_mindmap_tree_ops.dart (updateNode/addChild/deleteNode/indentNode/outdentNode/reorderChild) ; canonical-schema.md#2.2]
- **Forêt vide** → état éditable accessible (au moins une affordance « ajouter une racine » via `ZMindmapTreeOps.newRootNode`), **pas de crash**. [Source: z_mindmap_tree_ops.dart#newRootNode]

**AC2 — LA SAUVEGARDE APPLIQUE RÉELLEMENT LES MODIFICATIONS (correction du bug lex) — invariant central.**
- **Toute** mutation (édition `label`/`content`, ajout enfant/frère, suppression, indent/outdent, réordonnancement) est appliquée à l'arbre **EXCLUSIVEMENT** via `ZMindmapTreeOps` (`updateNode`, `addChild`, `deleteNode`, `indentNode`, `outdentNode`, `reorderChild`, `moveNode`) — **aucune** reconstruction manuelle d'arbre, **aucun** `copyWith` (inexistant par convention sur `ZMindmapNode`). [Source: z_mindmap_node.dart (« aucun copyWith public, mutation via ZMindmapTreeOps ») ; z_mindmap_tree_ops.dart]
- **INVARIANT ANTI-RÉGRESSION (le cœur de la story)** : quand l'utilisateur **édite** un nœud puis **sauvegarde**, la forêt remise à l'app hôte (`onSave`) **reflète RÉELLEMENT l'édition** — jamais la forêt d'origine non mutée. La forêt éditée est la **source de vérité unique** de l'éditeur (portée par le contrôleur, cf. AC3) ; `onSave` émet **exactement cette forêt mutée** (identité/valeur), pas un instantané périmé capturé à l'ouverture. [Source: epics.md#E10-3 ; canonical-schema.md#5 dette n°5]
- **Preuve par test OBLIGATOIRE** (le test qui aurait attrapé le bug lex) : un widget test qui (1) monte l'éditeur sur une forêt connue, (2) tape un nouveau `label` dans un champ, (3) déclenche la sauvegarde, (4) **asserte que la forêt reçue par `onSave` contient le `label` édité** (et non l'ancien). Idem pour add / delete / indent / outdent / reorder : chaque mutation + save produit la forêt attendue. [Source: Testing requirements ci-dessous]
- **Cohérence de `level`** : puisque toutes les mutations passent par `ZMindmapTreeOps`, le `level` reste recalculé automatiquement (indent/outdent/move) — l'éditeur **ne recalcule JAMAIS `level` à la main**. Un test asserte la cohérence de `level` de la forêt sauvegardée après indent/outdent. [Source: z_mindmap_tree_ops.dart (recalcul de level) ; e10-1 AC5]

**AC3 — Réactivité Flutter-native, AUCUN gestionnaire d'état, AUCUN `setState` global (AD-2/AD-15).**
- L'état d'édition vit dans un **contrôleur pur-Flutter** `ZMindmapOutlineController` (**`ChangeNotifier`/`Listenable`**, aucun import de `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.find`/`Provider.of`). Il détient la **forêt éditée courante** (source de vérité) et applique chaque mutation via `ZMindmapTreeOps`, notifiant ses écouteurs. [Source: architecture.md#AD-2, #AD-15 ; CLAUDE.md#Réactivité Flutter-native]
- **Rebuild granulaire (objectif produit n°1, SM-1)** : taper dans le champ d'un nœud ne reconstruit **que la ligne concernée**, **jamais** tout l'outline, **jamais** de perte de focus. Chaque champ utilise un **`TextEditingController` STABLE keyé par `ZMindmapNode.id`** (créé une fois, jamais recréé au rebuild, disposé proprement) ; **JAMAIS** de ré-injection de valeur qui écrase la sélection/le curseur pendant la frappe. Les lignes s'abonnent via `ValueListenableBuilder`/`ListenableBuilder` à la tranche qui les concerne (structure de forêt vs texte d'un nœud). [Source: CLAUDE.md#Critical-Patterns (AD-2, objectif n°1) ; architecture.md#AD-2 ; SM-1]
- **Interdits explicites** : `setState` à l'échelle du formulaire/outline ; construction des lignes dans une closure de `build()` sans clé stable ; recréation de `TextEditingController` au rebuild ; ré-injection de valeur pendant la frappe. **Obligatoires** : contrôleur stable (create/dispose), `ValueKey(node.id)` sur les lignes, validateurs mémoïsés si validation, place stable pour les nœuds. [Source: CLAUDE.md#Critical-Patterns]
- **Édition « live » vs « commit on save »** : l'approche recommandée est que **chaque édition met à jour la forêt du contrôleur en continu** (via `ZMindmapTreeOps.updateNode` débouncé/onChanged), de sorte que la forêt du contrôleur soit **toujours** à jour ; `save()` émet alors simplement `controller.forest`. Si une approche « commit on save » est choisie, elle DOIT néanmoins lire l'état ACTUEL des champs au moment du save et l'appliquer via `ZMindmapTreeOps` avant d'émettre — **le test AC2 doit passer dans les deux cas**. Le choix est documenté en Dev Notes. [Source: AC2 ; architecture.md#AD-2]

**AC4 — Conformité AD-13 : Semantics, ≥ 48 dp, directionnel/RTL de bout en bout.**
- **Zéro** usage de `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right` : uniquement les variantes **directionnelles** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`). Un test/grep de garde asserte l'absence de ces API non-directionnelles dans le code de la story. [Source: CLAUDE.md#Key-Don'ts ; architecture.md#AD-13]
- Rendu **RTL-correct** : sous `Directionality(textDirection: TextDirection.rtl)`, l'indentation de l'outline part du **côté start** (droite en RTL) ; test widget de non-régression RTL. [Source: architecture.md#AD-13]
- `Semantics` explicites : chaque champ éditable et chaque bouton d'action (ajouter/supprimer/indenter/désindenter/monter/descendre) porte un **label a11y externalisé** ; **cibles tactiles ≥ 48 dp** (`minHeight`/`minWidth` 48, réutiliser `config.minTapTarget`). **Aucune chaîne UI métier codée en dur** : tous les libellés d'action/hint sont fournis par un paramètre de configuration de libellés (ex. un objet `ZMindmapOutlineLabels` immuable passé au widget, ou des callbacks), avec **repli neutre** non-nul. [Source: architecture.md#AD-13 (« libellés externalisés ») ; e10-2 AC4]

**AC5 — Thème injecté, aucun style/couleur codé en dur (FR-26).**
- Toutes les couleurs/espacements/rayons proviennent de **`ZcrudTheme.of(context)`** (résolu via `ZcrudScope` → `ThemeExtension<ZcrudTheme>` → repli `ZcrudTheme.fallback(Theme.of(context))`). **AUCUNE** `Color(0x…)`, `Colors.*`, ni marge/rayon numérique de **style** codé en dur. Réutiliser `ZMindmapNodeCard` (déjà 100 % thématisé) pour le rendu de contenu non-édité et/ou les tokens (`theme.gapM`, `theme.gapS`, `theme.radiusM`, `theme.surfaceColor`, `theme.fieldBorderColor`, `theme.labelColor`). [Source: architecture.md#FR-26 ; z_mindmap_node_card.dart ; z_theme.dart]
- Un test asserte qu'un `ZcrudTheme` injecté via `ZcrudScope`/`ThemeExtension` est **effectivement consommé** par l'éditeur (ex. couleur/bordure d'une ligne dérivée du token injecté). [Source: e10-2 AC5]

**AC6 — Barrel, dépendances & isolation architecturale (AD-1) ; non-régression E10-1/E10-2.**
- API publique (`ZMindmapOutlineEditor`, `ZMindmapOutlineController`, l'objet de libellés éventuel) exportée via le barrel `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` ; impl sous **`lib/src/presentation/`**. Le placeholder `ZMindmapApi` est **conservé**. [Source: zcrud_mindmap/lib/zcrud_mindmap.dart]
- **AD-1** : **AUCUNE nouvelle arête de package** requise — `flutter` (SDK) est déjà une dépendance (E10-2) ; **AUCUNE** arête vers un gestionnaire d'état, Firebase, Syncfusion ou `graphite` supplémentaire. **`zcrud_core` NON modifié.** [Source: architecture.md#AD-1 ; e10-2 pubspec]
- **Non-régression** : `ZMindmapView`, `ZMindmapListView`, `ZMindmapNodeCard`, `ZMindmapViewConfig`, `ZMindmapTreeOps`, `ZMindmapNode`, `ZMindmap` restent inchangés dans leur comportement public ; les 82 tests existants (dont 26 E10-2) restent **verts**. L'éditeur est **additif**. [Source: e10-2 Completion Notes]

## Tasks / Subtasks

- [x] **Task 1 — `ZMindmapOutlineController` (ChangeNotifier pur-Flutter) (AC2, AC3)**
  - [x] Créer `lib/src/presentation/z_mindmap_outline_controller.dart` : `ChangeNotifier` détenant la **forêt éditée courante** (`List<ZMindmapNode> get forest`), initialisée depuis la forêt d'entrée.
  - [x] Exposer des méthodes de mutation qui **délèguent toutes à `ZMindmapTreeOps`** et remplacent la forêt interne + `notifyListeners()` **seulement si la forêt change** (respecter le `identical` no-op de TreeOps pour éviter les rebuilds inutiles) : `editLabel(id, label)`, `editContent(id, content)`, `addChild(parentId)`, `addSibling(id)`, `deleteNode(id)`, `indent(id)`, `outdent(id)`, `moveUp(id)`/`moveDown(id)` (via `reorderChild`).
  - [x] Gérer les **`TextEditingController` par nœud** keyés par `id` : création paresseuse à la première demande, réutilisation stable, `dispose()` de tous en fin de vie du contrôleur. Ne PAS ré-affecter `.text` pendant la frappe (source du bug de focus).
  - [x] `forestForSave()` (ou simplement `forest`) renvoie la forêt **actuelle mutée** — c'est ce que `save` émettra.
- [x] **Task 2 — `ZMindmapOutlineEditor` (widget) : outline indenté éditable (AC1, AC3, AC4, AC5)**
  - [x] Créer `lib/src/presentation/z_mindmap_outline_editor.dart` : `StatefulWidget` qui **crée/dispose** un `ZMindmapOutlineController` interne (ou en accepte un injecté — documenter le choix ; par défaut interne, create/dispose).
  - [x] `ListView.builder` sur la forêt aplatie profondeur-d'abord (recalculée quand la structure change, pas à chaque frappe) ; **indentation `EdgeInsetsDirectional.only(start: level*indentStep)`** ; `ValueKey(node.id)` par ligne.
  - [x] Par ligne : `TextField`/`TextFormField` (controller stable du contrôleur) pour `label` (+ `content` selon le choix documenté), barre d'actions (ajouter enfant/frère, supprimer, indent, outdent, monter, descendre) — chaque action appelle la méthode correspondante du contrôleur. Cibles ≥ 48 dp, `TextAlign.start`.
  - [x] Rebuild granulaire : la ligne n'écoute que sa tranche ; frappe = rebuild d'une seule ligne, zéro perte de focus. Couleurs/tokens via `ZcrudTheme.of(context)` (réutiliser `ZMindmapNodeCard`/tokens). État vide → affordance « ajouter une racine ».
- [x] **Task 3 — Sauvegarde qui applique réellement (AC2)**
  - [x] Exposer un callback `onSave` (typedef `ZMindmapForestCallback = void Function(List<ZMindmapNode> forest)` ou `void Function(ZMindmap)` selon l'entrée) et/ou une méthode `save()` sur le widget/contrôleur qui émet **la forêt mutée du contrôleur**.
  - [x] **GARANTIR** que la forêt émise reflète toutes les éditions en cours (si « commit on save », lire l'état actuel des champs et l'appliquer via `ZMindmapTreeOps.updateNode` AVANT d'émettre). Optionnel : `onChanged` continu pour un mode auto-save.
- [x] **Task 4 — Libellés externalisés & config (AC4, AC5)**
  - [x] Définir un objet de libellés a11y **immuable** (ex. `ZMindmapOutlineLabels` : addChild/addSibling/delete/indent/outdent/moveUp/moveDown/labelHint/contentHint/addRoot) avec **repli neutre non-nul** ; réutiliser `ZMindmapViewConfig` (indentStep, minTapTarget) plutôt que d'inventer des constantes.
- [x] **Task 5 — Barrel & isolation (AC6)**
  - [x] Exporter `z_mindmap_outline_editor.dart` et `z_mindmap_outline_controller.dart` (+ libellés) dans `lib/zcrud_mindmap.dart` ; `ZMindmapApi` conservé.
  - [x] **Zéro** import de gestionnaire d'état / Firebase / Syncfusion ; **zéro edit `zcrud_core`** ; **aucune** nouvelle arête pubspec.
- [x] **Task 6 — Tests (voir Testing requirements) (AC1..AC6)**
  - [x] Widget tests : **édition → save → forêt mutée correcte** (le test anti-bug lex), add/delete/indent/outdent/reorder persistés, cohérence de `level`, rebuild granulaire + zéro perte de focus, a11y/≥48 dp/RTL/directionnel, thème injecté consommé, état vide, non-régression E10-1/E10-2.
- [x] **Task 7 — Vérif verte**
  - [x] `dart analyze packages/zcrud_mindmap` RC=0 → `flutter test packages/zcrud_mindmap` RC=0 (nouveaux tests + 82 existants). Aucun codegen (`*.g.dart`) requis.

## Dev Notes

### Réutilisation OBLIGATOIRE (anti-réinvention)
- **`ZMindmapTreeOps` (E10-1) = UNIQUE moteur de mutation.** `updateNode(roots, id, {label, content})`, `addChild(roots, parentId, child)`, `deleteNode(roots, id)`, `indentNode(roots, id)`, `outdentNode(roots, id)`, `reorderChild(roots, parentId, oldIndex, newIndex)`, `moveNode(...)`, `findNode(roots, id)`, `newRootNode()`, `newChildNode(parentLevel)`. **Tout** est pur/immuable/structural-sharing (no-op = `identical`). **NE JAMAIS** reconstruire un `ZMindmapNode`/une forêt à la main, **NE JAMAIS** recalculer `level` soi-même. [Source: z_mindmap_tree_ops.dart:24-410]
  - **Sémantique `content`** (à respecter dans `editContent`) : `null` = non touché, `''` = efface, autre = remplace. `label` : `null` = non touché. [Source: z_mindmap_tree_ops.dart:58-83]
  - **`addSibling(id)`** : résoudre le parent du nœud (pas d'API `findParent` publique → utiliser `addChild(parentId)` si le nœud a un parent ; pour un frère de racine, ajouter une racine). Alternative simple et robuste : ajouter comme **enfant du parent** puis, si besoin, `reorderChild` pour le placer juste après. Documenter l'approche retenue. Pour un frère de nœud racine, `newRootNode()` + insertion en forêt (via une op TreeOps existante ; ne pas manipuler la liste racine à la main hors TreeOps). Si une op manque réellement, **signaler à l'orchestrateur** (ne PAS éditer `zcrud_core`/E10-1 dans cette story).
- **`ZMindmapNode` immuable, PAS de `copyWith`.** La mutation passe EXCLUSIVEMENT par `ZMindmapTreeOps`. `children`/`extra` sont non-modifiables ; ne pas tenter de muter en place. [Source: z_mindmap_node.dart:24-46]
- **`ZMindmapNodeCard` + `ZMindmapViewConfig` (E10-2)** : réutiliser pour le rendu thématisé et les tokens de layout (`minTapTarget`≥48, `indentStep`), et pour le rendu du contenu non-édité si un mode « aperçu » est utile. `ZMindmapNodeCard` est déjà 100 % `ZcrudTheme` + directionnel + ≥48 dp. [Source: z_mindmap_node_card.dart ; z_mindmap_view_config.dart]
- **`ZMindmapListView` (E10-2)** : modèle de référence pour l'aplatissement profondeur-d'abord, l'indentation `EdgeInsetsDirectional.only(start: node.level * config.indentStep)`, les `Semantics` et le `ListView.builder`. **Copier ces patrons** (pas le comportement lecture-seule). [Source: z_mindmap_list_view.dart:59-142]
- **`ZcrudTheme` / `ZcrudScope`** (`zcrud_core`, déjà exportés) : `ZcrudTheme.of(context)` → tokens de style. **Toute** couleur passe par là (FR-26). **Ne PAS** référencer un gestionnaire d'état ; passer par `ZcrudScope`/paramètres/callbacks. [Source: z_theme.dart ; zcrud_scope.dart ; z_mindmap_node_card.dart:35,85]

### Le bug lex à corriger — comprendre la cause racine
- Dans lex, l'éditeur outline **éditait un état UI local** (souvent une liste plate reconstruite pour l'affichage) mais **la sauvegarde persistait la carte d'origine** (ou un instantané capturé à l'ouverture, jamais reversé) → **modifications perdues**. Cause aggravée : `move/indent/outdent` **n'existaient pas** dans le moteur, donc les reparentages n'avaient nulle part où être appliqués. [Source: docs/canonical-schema.md#5 dette n°5]
- **Correction par conception zcrud** : (1) E10-1 a codé toutes les ops (fait) ; (2) E10-3 fait de **la forêt du contrôleur la source de vérité unique**, mutée en continu via `ZMindmapTreeOps`, et **`save` émet exactement cette forêt** — il n'existe **aucun** chemin où l'arbre d'origine serait re-persisté par-dessus les edits. Le **test AC2** verrouille cet invariant pour toujours.

### Réactivité & isolation (AD-2/AD-15/AD-1)
- **Aucun** `import 'package:flutter_riverpod/…'` / `get` / `provider` ; **aucun** `WidgetRef`/`Get.find`/`Provider.of`. Le `ZMindmapOutlineController` est un `ChangeNotifier` **pur-Flutter**. [Source: architecture.md#AD-2, #AD-15]
- **Piège de focus (objectif produit n°1)** : ne JAMAIS faire `textController.text = node.label` dans `build`/à chaque notification pendant la frappe — cela réinitialise le curseur et fait perdre le focus (précisément le jank historique que zcrud existe pour tuer). Créer les `TextEditingController` **une fois par `id`**, ne réaffecter `.text` **que** lors d'un remplacement structurel réel du nœud non déclenché par la frappe (ex. undo externe), et via `TextEditingValue` préservant la sélection si nécessaire. Préférer piloter la forêt DEPUIS le champ (`onChanged` → `editLabel`) plutôt que l'inverse. [Source: CLAUDE.md#Critical-Patterns ; SM-1]
- **Rebuild granulaire** : la structure de la forêt (aplatissement) ne se recalcule qu'aux mutations structurelles (add/delete/indent/outdent/reorder) ; une frappe de `label` ne doit PAS reconstruire tout l'outline. Utiliser `ValueListenableBuilder`/`ListenableBuilder` ciblés, `ValueKey(node.id)` par ligne. [Source: architecture.md#AD-2]
- **CONTRAINTE DURE** : zéro modification de `zcrud_core`. Si un besoin réel émergeait (token de thème manquant, op TreeOps manquante), **NE PAS** l'implémenter — **le signaler à l'orchestrateur**. [Source: CLAUDE.md#Key-Don'ts]

### Pièges spécifiques mindmap (ne pas se tromper de modèle)
- **Nesting, PAS adjacency plate** : la forêt est un arbre par `children` + `level` dénormalisé ; l'aplatissement outline est **dérivé** pour l'affichage, ce n'est pas le modèle de stockage. Ne pas confondre avec l'univers douane/RAG à adjacence plate (`node_content_view.dart`/`ComparativeNode`…). [Source: canonical-schema.md#194 ; e10-2 Dev Notes]
- **`content` = texte brut** (pas markdown). L'édition de `content` est un `TextField` multiligne brut ; le rendu riche reste une injection hors E10-3. [Source: e10-1 Dev Notes]
- **`level`** : maintenu par `ZMindmapTreeOps` uniquement. L'outline le lit tel quel pour l'indentation ; il ne le fixe jamais. [Source: z_mindmap_tree_ops.dart:239-277]
- **Multi-racine** : la forêt peut avoir ≥1 racines ; l'outline itère toutes les racines. Pas de racine virtuelle ici (c'était un artefact de rendu graphite E10-2, hors de l'outline). [Source: e10-2 Completion Notes]

### Project Structure Notes
- Package : `packages/zcrud_mindmap/`. Nouveaux fichiers sous `lib/src/presentation/` (`z_mindmap_outline_editor.dart`, `z_mindmap_outline_controller.dart`, éventuel `z_mindmap_outline_labels.dart`). Barrel `lib/zcrud_mindmap.dart`. Placeholder `ZMindmapApi` conservé.
- Aucune couche `data/` (pas de persistance ici — la persistance est le rôle de l'app hôte / E5 ; l'éditeur **remonte** la forêt mutée, il ne l'écrit pas lui-même). Aucun codegen (`*.g.dart`).
- **Aucune** modification de pubspec attendue (flutter SDK déjà présent depuis E10-2). Si une modif pubspec semble nécessaire, c'est un signal d'erreur de périmètre → réévaluer.

### Testing requirements
- Framework : `flutter test` (package), `*_test.dart`, `testWidgets` + `WidgetTester.pumpWidget` sous `MaterialApp`/`Directionality`/`ZcrudScope`. Golden **optionnel** (non bloquant) ; privilégier des assertions structurelles + a11y déterministes.
- **Couverture obligatoire** (ACs testables) :
  - **★ Édition → save → forêt mutée (AC2) — LE test anti-bug lex** : monter `ZMindmapOutlineEditor` sur une forêt connue avec `onSave` capturant la forêt émise ; `tester.enterText(...)` un nouveau `label` ; déclencher save ; **asserter que la forêt capturée contient le nouveau `label`** (via `ZMindmapTreeOps.findNode(saved, id)!.label == 'nouveau'`), et **jamais** l'ancien. **Sans cette assertion, la story n'est pas terminée.**
  - **Mutations structurelles persistées (AC2)** : pour chacune de add child / add sibling / delete / indent / outdent / moveUp-moveDown : effectuer l'action via l'UI (tap bouton) puis save ; asserter la topologie de la forêt sauvegardée (présence/absence de nœud, parenté, ordre de fratrie).
  - **Cohérence de `level` (AC2)** : après indent puis outdent d'un nœud avec sous-arbre, la forêt sauvegardée a des `level` cohérents (racine=0, cascade enfant=parent+1) — vérifiable via un parcours ou `ZMindmapTreeOps.normalizeLevels(saved)` renvoyant `identical`/équivalent.
  - **Rebuild granulaire + focus (AC3, SM-1)** : taper plusieurs caractères dans un champ ne fait pas perdre le focus (`tester.enterText` puis vérifier que le `TextField` reste focalisé / le curseur en fin) ; le `TextEditingController` d'une ligne n'est pas recréé entre deux frappes (identité stable).
  - **a11y/Semantics + ≥48 dp (AC4)** : champs et boutons portent des labels a11y externalisés ; cibles interactives ≥ 48 dp (asserter la contrainte de taille) ; `find.bySemanticsLabel` sur les labels injectés.
  - **RTL + directionnel (AC4)** : sous `Directionality(rtl)`, l'indentation part du côté **start** ; grep de garde asserant l'**absence** de `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `Positioned(left/right)`, `TextAlign.left/right` dans le code de la story.
  - **Thème injecté (AC5)** : un `ZcrudTheme` custom via `ZcrudScope`/`ThemeExtension` est **consommé** (couleur/bordure de ligne = token injecté) ; aucune couleur codée en dur.
  - **État vide (AC1)** : forêt vide → affordance « ajouter une racine » présente ; l'ajouter puis save produit une forêt à 1 racine.
  - **Isolation (AC6)** : grep de garde — aucun import de `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.`/`Provider.of` dans les fichiers de la story ; aucune modif hors `packages/zcrud_mindmap/**`.
  - **Non-régression (AC6)** : les 82 tests existants (E10-1/E10-2) restent verts.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E10 / Story E10-3 (« sauvegarde applique réellement les modifications, bug lex corrigé »)]
- [Source: docs/canonical-schema.md#5 (dette n°5 : MindmapTreeOps annonçait move/indent/outdent non codés ; module Étude vivant → versionné + re-portage) ; #2.2 (ZMindmap/ZMindmapNode + tree ops, nesting + level, content texte brut) ; #194 (piège de nommage : nesting vs adjacency)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1 (isolation acyclique), #AD-2 (réactivité Flutter-native, rebuild granulaire, objectif produit n°1), #AD-4 (extension), #AD-13 (a11y/RTL/directionnel, ≥48 dp, libellés externalisés), #AD-15 (bindings multi-gestionnaire, cœur sans state manager) ; FR-26 (thème injecté)]
- [Source: _bmad-output/implementation-artifacts/stories/e10-1-zmindmapnode-treeops.md ; e10-2-zmindmapview-graphite.md]
- [Source: packages/zcrud_mindmap/lib/src/domain/z_mindmap_tree_ops.dart ; z_mindmap_node.dart ; packages/zcrud_mindmap/lib/src/presentation/z_mindmap_list_view.dart ; z_mindmap_node_card.dart ; z_mindmap_view_config.dart]
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart ; zcrud_scope.dart]
- [Source: CLAUDE.md#Critical-Patterns (AD-2 objectif produit n°1 : rebuild granulaire, TextEditingController stable, pas de setState global, pas de ré-injection de valeur), #Key-Don'ts (directionnel RTL, ListView.builder, const, Semantics ≥48 dp, thème injecté, jamais de gestionnaire d'état dans un package hors binding)]

### Dépendance détectée pour l'orchestrateur
- **Aucun besoin d'édition de `zcrud_core`** : `ZcrudTheme`, `ZcrudScope`, `ZNode`, `ZExtensible` déjà exportés et suffisants.
- **Aucun besoin d'édition d'E10-1** attendu : `ZMindmapTreeOps` couvre déjà updateNode/addChild/deleteNode/indentNode/outdentNode/reorderChild/moveNode/newRootNode/newChildNode/findNode. **Point de vigilance** : il n'existe **pas** d'API publique `findParent` ni d'op « insérer une racine à un index » ; le dev doit composer `addSibling`/ajout-de-racine à partir des ops existantes (voir Dev Notes). Si une op s'avère réellement manquante, **le signaler à l'orchestrateur** — ne PAS éditer `zcrud_core` ni ré-ouvrir E10-1 dans cette story.
- **Aucune nouvelle arête pubspec** (flutter SDK déjà présent depuis E10-2 ; pas de `graphite` requis pour l'outline).
- **Parallélisation** : `zcrud_mindmap` est un **package disjoint**. E10-3 suit E10-1/E10-2 (même package, séquentiel intra-package) et ne touche PAS `zcrud_core` → parallélisable avec des stories d'autres packages tant qu'aucune n'écrit `zcrud_core` en même temps.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story` invoqué via le tool `Skill`).

### Debug Log References

- Vérif ciblée : `dart analyze packages/zcrud_mindmap` → **RC=0, No issues found**.
- `flutter test packages/zcrud_mindmap` → **RC=0, +109 tests** (89 existants E10-1/E10-2 verts + 20 nouveaux `testWidgets` + 2 tests unitaires de garde grep dans le nouveau fichier ; le compteur affiche 20 pour les `testWidgets` du fichier, 22 cas au total).
- Corrections d'itération de test (non-code de prod) : surface de test agrandie (1000×3000) via un wrapper `_tw` pour éviter la virtualisation du `ListView.builder` sur les lignes hautes ; grep de garde durci en **retirant les commentaires** avant scan (les docstrings nomment légitimement les API interdites).

### Completion Notes List

- **AC1 (outline indenté éditable)** ✅ — `ZMindmapOutlineEditor` : forêt aplatie DFS via `ListView.builder`, indentation `EdgeInsetsDirectional.only(start: level*indentStep)`, champ `label` + champ `content` (multiligne brut, `editContentField` par défaut `true`), barre d'actions par nœud (enfant/frère/supprimer/indent/outdent/monter/descendre) ; barre d'outils avec « ajouter une racine » (affordance présente même sur forêt vide) + « enregistrer ».
- **AC2 (SAUVEGARDE APPLIQUE RÉELLEMENT — invariant central)** ✅ — La forêt du `ZMindmapOutlineController` est **source de vérité unique**, mutée en continu via `ZMindmapTreeOps` uniquement (aucun `copyWith`, aucune reconstruction manuelle, aucun recalcul de `level`). `onSave` émet **exactement** `controller.forest`. **Test-preuve anti-bug-lex** présent : édition de `label` → save → `findNode(saved,'c1').label == 'ChildEdited'` (et `isNot('Child1')`) ; idem `content`, add child/sibling, delete, indent, outdent, moveUp/moveDown ; **cohérence de `level`** vérifiée (`_levelsCoherent` + `normalizeLevels(saved)` renvoie `identical`).
- **AC3 (réactivité Flutter-native, rebuild granulaire, zéro perte de focus)** ✅ — `ZMindmapOutlineController extends ChangeNotifier` pur (aucun gestionnaire d'état). **Édition de texte = 0 notification** (mise à jour silencieuse de la forêt : le `TextEditingController` STABLE keyé par `id` porte déjà le texte) ; seules les mutations **structurelles** notifient → l'outline ne se reconstruit qu'à celles-ci. Tests : identité du `TextEditingController` stable entre frappes, focus conservé après `enterText`, `editLabel` n'incrémente pas le compteur de notifications, mutation structurelle si.
- **AC4 (AD-13 : Semantics, ≥48 dp, RTL/directionnel)** ✅ — Libellés a11y externalisés via `ZMindmapOutlineLabels` (repli neutre non-nul, surchargeable) ; boutons `Semantics(button,label,onTap)` + `ExcludeSemantics(Icon)` ≥ 48 dp (`ConstrainedBox` sur `config.minTapTarget`) ; `TextAlign.start`, `EdgeInsetsDirectional` partout ; test RTL (indentation côté start) + grep de garde d'absence des API non-directionnelles.
- **AC5 (thème injecté, FR-26)** ✅ — Toutes couleurs/espacements/rayons via `ZcrudTheme.of(context)` (`labelColor`/`fieldBorderColor`/`surfaceColor`/`gapS`/`gapM`/`radiusS`) ; aucun littéral. Test : couleur d'icône = token `labelColor` injecté via `ZcrudScope`.
- **AC6 (barrel, isolation AD-1, non-régression)** ✅ — Exports ajoutés au barrel (`ZMindmapOutlineController`/`ZMindmapOutlineEditor`/`ZMindmapOutlineLabels`) ; `ZMindmapApi` conservé ; **aucune** nouvelle arête pubspec ; **aucune** modif hors `packages/zcrud_mindmap/**` ; 89 tests E10-1/E10-2 restent verts. Grep de garde : aucun import de gestionnaire d'état.
- **Choix documentés** :
  - `addSibling(id)` / `addRoot()` **composent** les ops E10-1 sans `findParent` public ni op « insérer racine » : on ajoute un enfant **sous** le nœud puis `outdentNode` → il devient frère du nœud (index +1), `level` recalculé — vrai pour racine comme non-racine. `addRoot` sur forêt **vide** crée la forêt initiale `[newRootNode()]` (composition de liste d'une fabrique, sans reconstruction de nœud) ; sinon délègue à `addSibling(dernière racine)`.
  - `moveUp/moveDown` : localisation **lecture-seule** de la position (`_locate`, l'équivalent-position de `findNode`) puis `reorderChild` — sans réutiliser le `_findParent` privé de TreeOps ni muter.
  - Édition **« live »** : chaque frappe met la forêt du contrôleur à jour en continu (sans notifier) → `save` émet toujours l'état courant.
- **Besoin `zcrud_core` détecté** : **AUCUN**. `ZcrudTheme`/`ZcrudScope` et tout `ZMindmapTreeOps` (updateNode/addChild/deleteNode/indentNode/outdentNode/reorderChild/moveNode/newRootNode/newChildNode/findNode) ont suffi. Aucune op TreeOps manquante ; le point de vigilance `findParent`/« insérer racine à index » a été **contourné par composition** comme prévu. Aucune modif de `zcrud_core` ni ré-ouverture d'E10-1.

### File List

- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_controller.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_labels.dart` (nouveau)
- `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` (modifié : exports E10-3 ajoutés, ordre alphabétique)
- `packages/zcrud_mindmap/test/z_mindmap_outline_editor_test.dart` (nouveau : 20 `testWidgets` + 2 tests de garde grep)
