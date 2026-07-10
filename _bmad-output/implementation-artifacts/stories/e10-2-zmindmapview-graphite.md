---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 10.2 : ZMindmapView (graphite auto-layout + vue liste a11y)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**intégrateur d'une app de cartes mentales (lex_douane, DODLP)**,
je veux **une vue `ZMindmapView` qui rend une forêt `ZMindmap` en carte mentale auto-agencée (auto-layout `graphite`, zoom/pan, sans drag libre) ET une vue liste sémantique indentée par `level` comme surface d'accessibilité équivalente, avec un `nodeContentBuilder` injectable pour brancher un rendu de contenu riche/domaine**,
afin de **visualiser une carte mentale de façon lisible, accessible (a11y/RTL AD-13) et thématisable, sans réintroduire la fragilité du `MindmapView` de lex ni coupler la vue à un gestionnaire d'état ou à un thème codé en dur**.

## Contexte & valeur

- **Épic E10 (Cartes mentales, `zcrud_mindmap`, v1.x)** — objectif : modèle / tree-ops / **vue** additifs pour lex_douane. Couvre **FR-19** ; AD-4, AD-13. Dépend de E2, E6. [Source: epics.md#E10]
- **Story E10-2** est la **VUE** : `graphite` auto-layout zoom/pan à partir de la forêt `ZMindmap` ; vue liste sémantique indentée = surface a11y ; `nodeContentBuilder` injectable (AD-13). [Source: epics.md#E10 Story E10-2]
- Consomme **strictement** les modèles livrés par **E10-1** (`ZMindmap`, `ZMindmapNode`, `ZMindmapTreeOps`) — **NE PAS recréer** ces types. Cette story n'ajoute **aucune** mutation d'arbre (l'éditeur outline corrigé = **E10-3**, hors périmètre). E10-2 est **lecture/affichage** : elle rend une forêt immuable et remonte les interactions (tap/sélection) par callbacks, sans muter l'arbre elle-même. [Source: e10-1-zmindmapnode-treeops.md ; epics.md#E10-3]
- **Dette portée avec vigilance** : le `MindmapView` de lex reposait sur `graphview` + `BuchheimWalkerAlgorithm`. L'architecture **supersede** `graphview` par **`graphite ^1.2.1`** (pinné par lex_douane) : le portage cible **`graphite`**. Contraintes conservées de l'original : **auto-layout** (pas de positionnement manuel), **zoom/pan** via `InteractiveViewer`, **aucun drag libre** de nœud, **mode compact/plein écran**, **vue liste sémantique a11y indentée par `level`**. [Source: canonical-schema.md#2.2 (ZMindmapView) ; architecture.md « Auto-layout mindmap = graphite (graphview superseded) », Stack `graphite ^1.2.1`]

## Acceptance Criteria

**AC1 — `ZMindmapView` : rendu graphite auto-agencé de la forêt `ZMindmap`, zoom/pan, sans drag libre.**
- `ZMindmapView` est un `StatelessWidget`/`StatefulWidget` **pur-Flutter** prenant en entrée une **`ZMindmap` immuable** (ou `List<ZMindmapNode>` racines) et produisant un graphe **auto-agencé** via **`graphite`** (`DirectGraph`), **orientation descendante** (parent → enfants), à partir de la topologie par **nesting** (`children`) des `ZMindmapNode`. [Source: canonical-schema.md#2.2 ; architecture.md#Stack graphite]
- Les arêtes du graphe sont **dérivées de l'arbre** (`parent.id → child.id`) ; les identités de nœuds graphite sont les `ZMindmapNode.id` (clé de réconciliation). **Multi-racine géré** : une forêt à ≥2 racines est rendue sans crash (soit racines multiples supportées par `graphite`, soit rattachées à une **racine virtuelle non affichée** — le choix documenté dans les Dev Notes ; la racine virtuelle, si utilisée, est **exclue de la sémantique** et du rendu visible).
- **Zoom/pan** activés (via `InteractiveViewer` et/ou l'API de `graphite`), **`minScale`/`maxScale` bornés** ; **AUCUN drag libre** de nœud (positions imposées par l'auto-layout, jamais déplaçables à la souris/au doigt). [Source: canonical-schema.md#2.2 « InteractiveViewer zoom/pan, aucun drag libre »]
- **Forêt vide** (`nodes` vide) → état vide accessible (message via libellé injecté / repli neutre), **pas de crash**.

**AC2 — Vue liste sémantique indentée = surface d'accessibilité équivalente (AD-13).**
- `ZMindmapView` expose une **vue liste sémantique** (widget dédié `ZMindmapListView` ou mode de `ZMindmapView`) : parcours **profondeur-d'abord** de la forêt, **une entrée par nœud**, **indentation dérivée de `level`** (via `EdgeInsetsDirectional.only(start: level * step)` — **JAMAIS** `left:`), rendue par `ListView.builder` (jamais `ListView(children:)`). [Source: architecture.md#AD-13 « la vue liste sémantique est la surface a11y de référence » ; CLAUDE.md#Key-Don'ts]
- La **surface a11y de référence** est la **vue liste** : le rendu graphite visuel est enveloppé d'`ExcludeSemantics` (ou équivalent) pour ne pas polluer le lecteur d'écran ; les `Semantics` **explicites** (label = `ZMindmapNode.label`, profondeur annoncée, état sélectionné si applicable) vivent sur la vue liste. Les deux vues affichent **la même information** (équivalence graphe ⇄ liste). [Source: canonical-schema.md#2.6/262 « ExcludeSemantics sur le visuel, vue liste = surface a11y de référence » ; architecture.md#AD-13]
- Chaque entrée interactive de la vue liste (et chaque nœud interactif du graphe) est une **cible ≥ 48 dp** (`minHeight`/`minWidth` 48). [Source: architecture.md#AD-13 ; CLAUDE.md#Key-Don'ts]

**AC3 — `nodeContentBuilder` injectable (extension du rendu de contenu).**
- `ZMindmapView` (et la vue liste) acceptent un **`nodeContentBuilder` injectable** (typedef `ZMindmapNodeContentBuilder = Widget Function(BuildContext context, ZMindmapNode node)`), permettant à l'app hôte de brancher un **rendu de contenu riche/domaine** (ex. markdown via `zcrud_markdown`, badges de source/audio via `extension`/`extra` AD-4) **sans modifier le package**. [Source: canonical-schema.md#2.2 « injecter un nodeCardBuilder/nodeContentBuilder » ; epics.md#E10-2]
- **Défaut sûr** : si `nodeContentBuilder` est `null`, un rendu par défaut affiche `label` (et, en repli, un extrait de `content`) — **texte brut**, `TextAlign.start`, thématisé, tronqué proprement (`overflow`). Le builder par défaut **ne dépend pas** de `zcrud_markdown` (le contenu est du **texte brut** en E10 ; le rendu riche est une **injection** de l'app). [Source: e10-1 Dev Notes « content = texte brut, pas markdown »]
- Le `nodeContentBuilder` est appliqué **à l'identique** dans les deux vues (graphe et liste) pour garantir l'équivalence.

**AC4 — Conformité AD-13 : Semantics, ≥ 48 dp, directionnel/RTL de bout en bout.**
- **Zéro** usage de `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right` : uniquement les variantes **directionnelles** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`). Un test/inspection asserte l'absence de ces API non-directionnelles dans le code de la story. [Source: CLAUDE.md#Key-Don'ts ; architecture.md#AD-13]
- Rendu **RTL-correct** : sous `Directionality(textDirection: TextDirection.rtl)`, l'indentation de la vue liste part du **côté start** (droite en RTL) ; test widget de non-régression RTL. [Source: architecture.md#AD-13]
- `Semantics` explicites sur les nœuds interactifs ; cibles tactiles ≥ 48 dp ; libellés **externalisés** (aucune chaîne UI métier codée en dur — libellés fournis par un paramètre/`ZcrudStrings`/callback, repli neutre). [Source: architecture.md#AD-13 « libellés externalisés, pas de singleton statique mutable »]

**AC5 — Thème injecté, aucun style/couleur codé en dur (FR-26).**
- Toutes les couleurs/espacements/rayons proviennent de **`ZcrudTheme.of(context)`** (résolu via `ZcrudScope` → `ThemeExtension<ZcrudTheme>` → repli `ZcrudTheme.fallback(Theme.of(context))`). **AUCUNE** `Color(0x…)`, `Colors.*`, ni marge/rayon numérique codé en dur pour le style (les constantes de layout structurel — ex. pas de couleur — restent admissibles mais dérivent des tokens quand un token existe). [Source: architecture.md#FR-26 ; packages/zcrud_core/lib/src/presentation/theme/z_theme.dart ; CLAUDE.md#Key-Don'ts]
- Un test asserte qu'un `ZcrudTheme` injecté via `ZcrudScope`/`ThemeExtension` est **effectivement consommé** par la vue (ex. couleur d'un nœud dérivée du token injecté).

**AC6 — Réactivité Flutter-native, AUCUN gestionnaire d'état (AD-2/AD-15).**
- `ZMindmapView` **n'importe AUCUN** gestionnaire d'état (`flutter_riverpod`, `get`, `provider`) ni `WidgetRef`/`Get.find`/`Provider.of`. La vue est **pilotée par la donnée immuable** passée en entrée ; toute interaction (tap sur un nœud, sélection, demande d'édition) est **remontée par callback** (`onNodeTap`/`onNodeSelected`…) à l'app hôte — E10-2 **ne mute pas** l'arbre. [Source: architecture.md#AD-2, #AD-15 ; CLAUDE.md#Key-Don'ts]
- Si un **état de vue local** est nécessaire (nœud sélectionné, échelle de zoom, mode compact/plein écran), il est porté par un **`ChangeNotifier`/`ValueNotifier` pur-Flutter** interne + `ValueListenableBuilder`/`ListenableBuilder` (rebuild ciblé), **jamais** un `setState` reconstruisant toute la vue à chaque interaction, **jamais** un gestionnaire d'état tiers. [Source: architecture.md#AD-2]
- `const` sur tout widget immuable ; `TextEditingController`/notifiers créés une fois (create/dispose), jamais recréés au rebuild. [Source: CLAUDE.md#Key-Don'ts]

**AC7 — Barrel, dépendances & isolation architecturale (AD-1).**
- API publique (`ZMindmapView`, `ZMindmapListView` si séparé, `ZMindmapNodeContentBuilder`, `ZMindmapViewConfig` éventuel) exportée via le barrel `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` ; impl sous **`lib/src/presentation/`**. Le placeholder `ZMindmapApi` est **conservé** (arêtes AD-1). [Source: zcrud_mindmap/lib/zcrud_mindmap.dart]
- **AD-1** : l'arête **`zcrud_mindmap → graphite`** est **autorisée** (ajoutée au pubspec) ; l'arête `zcrud_mindmap → flutter` (SDK) est ajoutée (le package devient porteur d'UI). **AUCUNE** arête vers un gestionnaire d'état, Firebase ou Syncfusion. **CONTRAINTE DURE : cette story NE MODIFIE PAS `zcrud_core`** — `ZcrudTheme`/`ZcrudScope`/`ZNode`/`ZExtensible` y existent déjà et sont réutilisés. [Source: CLAUDE.md#Key-Don'ts ; architecture.md#AD-1]

## Tasks / Subtasks

- [x] **Task 0 — Dépendances pubspec (AC1, AC7)**
  - [x] Ajouter `graphite: ^1.2.1` aux `dependencies` de `packages/zcrud_mindmap/pubspec.yaml` (arête AD-1 autorisée, version pinnée par l'architecture).
  - [x] Ajouter `flutter: {sdk: flutter}` aux `dependencies` (le package porte désormais de l'UI). Vérifier qu'aucun gestionnaire d'état / Firebase / Syncfusion n'est tiré.
  - [x] `dart pub get` (ou `melos bootstrap`) résout sans conflit.
- [x] **Task 1 — Dérivation graphe depuis la forêt (AC1)**
  - [x] Créer `lib/src/presentation/z_mindmap_graph_mapper.dart` (ou helper interne) : forêt `List<ZMindmapNode>` → structure `graphite` (`NodeInput`/`EdgeInput` : `parent.id → child.id`), parcours par nesting.
  - [x] Gérer le **multi-racine** (racine virtuelle non affichée OU racines multiples natives) ; documenter le choix.
- [x] **Task 2 — `ZMindmapView` graphite auto-layout + zoom/pan (AC1, AC5, AC6)**
  - [x] Créer `lib/src/presentation/z_mindmap_view.dart` : `DirectGraph` orienté top-down, `nodeBuilder` branché sur `nodeContentBuilder` (défaut sûr), zoom/pan bornés, **aucun drag libre**, mode compact/plein écran.
  - [x] Couleurs/espacements via `ZcrudTheme.of(context)` ; état de vue local (zoom/mode/sélection) via `ValueNotifier` + `ValueListenableBuilder` (pas de `setState` global, pas de gestionnaire d'état).
  - [x] État **forêt vide** accessible ; `const` partout où possible.
- [x] **Task 3 — Vue liste sémantique a11y (AC2, AC3, AC4, AC5)**
  - [x] Créer `lib/src/presentation/z_mindmap_list_view.dart` : `ListView.builder`, aplatissement profondeur-d'abord, indentation `EdgeInsetsDirectional(start: level*step)`, `Semantics` explicites, cibles ≥ 48 dp, `TextAlign.start`.
  - [x] Appliquer `ExcludeSemantics` sur le rendu graphite ; la vue liste porte la sémantique.
  - [x] `nodeContentBuilder` appliqué identiquement aux deux vues ; libellés externalisés (paramètres/callbacks), repli neutre.
- [x] **Task 4 — API publique `nodeContentBuilder` + config (AC3, AC7)**
  - [x] Définir `typedef ZMindmapNodeContentBuilder` + éventuel `ZMindmapViewConfig` (mode, bornes de zoom, step d'indentation) immuable.
  - [x] Exposer les callbacks d'interaction (`onNodeTap`/`onNodeSelected`), sans mutation d'arbre.
- [x] **Task 5 — Barrel & conformité (AC7)**
  - [x] Exporter les nouveaux symboles dans `lib/zcrud_mindmap.dart` ; `ZMindmapApi` conservé.
  - [x] Zéro import de gestionnaire d'état / Firebase / Syncfusion ; **zéro edit `zcrud_core`**.
- [x] **Task 6 — Tests (voir Testing requirements) (AC1..AC6)**
  - [x] Widget tests : rendu graphe (pump sans exception, nœuds présents), vue liste (indentation par level), a11y/Semantics, injection `nodeContentBuilder`, thème injecté consommé, RTL, ≥48 dp, absence d'API non-directionnelles, forêt vide.
- [x] **Task 7 — Vérif verte**
  - [x] `dart analyze packages/zcrud_mindmap` RC=0 → `flutter test packages/zcrud_mindmap` RC=0. Aucun codegen (`*.g.dart`) requis.

## Dev Notes

### Réutilisation OBLIGATOIRE (anti-réinvention)
- **Modèles E10-1** (`ZMindmap`, `ZMindmapNode`, `ZMindmapTreeOps`) : **déjà livrés**, immuables, exportés par le barrel. La vue les **consomme** (lecture + parcours) — **ne pas** recréer, **ne pas** muter. `ZMindmapTreeOps.findNode` disponible pour résoudre un id → nœud si besoin. [Source: e10-1-zmindmapnode-treeops.md ; z_mindmap_tree_ops.dart]
- **`ZcrudTheme`** (`zcrud_core`, exporté) : `ZcrudTheme.of(context)` résout `ZcrudScope.theme` → `Theme.of(context).extension<ZcrudTheme>()` → `ZcrudTheme.fallback(Theme.of(context))`. **Toute** couleur/token de style passe par là (FR-26). Modèle de référence : les widgets de champ du cœur (`z_tags_field_widget.dart`, `z_color_field_widget.dart`) qui font `final theme = ZcrudTheme.of(context);`. [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart ; z_color_field_widget.dart:62]
- **`ZcrudScope`** (`zcrud_core`, exporté) : point d'injection thème/l10n/seams (InheritedWidget). Ne PAS référencer un gestionnaire d'état ; passer par `ZcrudScope`/paramètres. [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart]
- **`ZNode`/`ZExtensible`** : `ZMindmapNode extends ZNode with ZExtensible` — le `nodeContentBuilder` de l'app peut lire `node.extension`/`node.extra` (AD-4) pour un rendu domaine, **sans** que le package connaisse ces extensions. [Source: z_mindmap_node.dart]

### graphite ^1.2.1 (guardrails d'API)
- Paquet **`graphite`** (pinné `^1.2.1`, présent au pub cache), **supersede `graphview`** du canonique. Vue haut niveau : `DirectGraph(list: List<NodeInput>, defaultCellSize, defaultBuilder/builder, orientation)` — **auto-layout de DAG** (pas de positions manuelles). Les arêtes se déclarent via `NodeInput(id, next: [EdgeInput(outcome: childId)])` (adjacency dérivée de l'arbre par nesting). Orientation **top→bottom** pour une carte mentale descendante. [Source: architecture.md#Stack, #note graphite]
- **Zoom/pan** : envelopper dans `InteractiveViewer` (bornes `minScale`/`maxScale`) et/ou utiliser les capacités intégrées de `graphite` ; **désactiver tout drag libre** de nœud (l'API `graphite` n'autorise pas le repositionnement manuel par défaut — ne pas l'activer). [Source: canonical-schema.md#2.2]
- Le `nodeBuilder` de `graphite` doit **déléguer** à `nodeContentBuilder` (ou au défaut sûr) ; envelopper chaque nœud d'une cible ≥ 48 dp thématisée. **Ne pas** afficher la racine virtuelle si l'approche multi-racine l'utilise.
- **Piège de version** : NE PAS régénérer le lock global du workspace ni bumper d'autres packages ; se limiter à ajouter `graphite`/`flutter` au pubspec de `zcrud_mindmap`.

### Pièges spécifiques mindmap (ne pas se tromper de modèle)
- **Nesting, PAS adjacency plate** : la forêt est un arbre par `children` imbriqués + `level` dénormalisé ; l'adjacency `graphite` est **dérivée** à la volée, ce n'est pas le modèle de stockage. Ne pas confondre avec l'univers douane/RAG à adjacence plate. [Source: e10-1 Dev Notes ; canonical-schema.md#2.2]
- **`content` = texte brut** (pas markdown) : le défaut de rendu affiche `label`/extrait brut. Le rendu riche est une **injection** (`nodeContentBuilder`), jamais une dépendance dure de la vue. [Source: e10-1 Dev Notes]
- **`level`** : ne le recalculer pas ici (E10-1 le garantit cohérent via `normalizeLevels`) ; s'en servir **tel quel** pour l'indentation de la vue liste. La vue est **lecture seule** : aucune op `ZMindmapTreeOps` de mutation.
- **Vue liste = surface a11y de référence** (AD-13) : le graphe visuel est `ExcludeSemantics` ; la sémantique et l'équivalence d'information vivent dans la liste. Les deux vues partagent le même `nodeContentBuilder`.

### Réactivité & isolation (AD-2/AD-15/AD-1)
- **Aucun** `import 'package:flutter_riverpod/…'` / `get` / `provider` ; **aucun** `WidgetRef`/`Get.find`/`Provider.of`. Vue pilotée par la donnée immuable + callbacks de remontée. [Source: architecture.md#AD-2, #AD-15]
- État de vue local (zoom, mode, sélection) = `ValueNotifier`/`ChangeNotifier` **pur-Flutter** + `ValueListenableBuilder` (rebuild ciblé), disposé proprement. Pas de `setState` reconstruisant toute la carte. [Source: architecture.md#AD-2]
- **CONTRAINTE DURE** : zéro modification de `zcrud_core`. Si un besoin réel émergeait (ex. un token de thème manquant), **NE PAS** l'implémenter — le **signaler à l'orchestrateur** (voir section dédiée). [Source: CLAUDE.md#Key-Don'ts]

### Project Structure Notes
- Package : `packages/zcrud_mindmap/`. **Nouvelle couche `lib/src/presentation/`** (E10-2) à côté de `lib/src/domain/` (E10-1). Barrel `lib/zcrud_mindmap.dart`. Placeholder `ZMindmapApi` conservé.
- Aucune couche `data/` (pas de persistance ici — E5). Aucun codegen (`*.g.dart`).

### Testing requirements
- Framework : `flutter test` (package), `*_test.dart`, `testWidgets` + `WidgetTester.pumpWidget` sous `MaterialApp`/`Directionality`. Golden **optionnel** (non bloquant) ; privilégier des assertions structurelles + a11y déterministes.
- **Couverture obligatoire** (ACs testables) :
  - **Rendu graphe (AC1)** : `pumpWidget(ZMindmapView(mindmap: forêt à ≥3 niveaux))` → aucune exception ; les `label` des nœuds sont trouvables ; **multi-racine** (≥2 racines) rendu sans crash ; **forêt vide** → état vide, pas de crash.
  - **Vue liste indentée (AC2)** : une entrée par nœud (parcours profondeur-d'abord) ; **indentation croissante avec `level`** (asserter le padding `start` dérivé de `level`) ; `ListView.builder` utilisé.
  - **a11y/Semantics (AC2, AC4)** : le rendu graphite est `ExcludeSemantics` ; la vue liste porte des `Semantics` avec `label` = `ZMindmapNode.label` ; cibles interactives **≥ 48 dp** (asserter la contrainte de taille) ; test via `SemanticsTester`/`find.bySemanticsLabel`.
  - **Injection `nodeContentBuilder` (AC3)** : un builder custom (ex. rendant un `Key`/texte sentinelle) est **effectivement utilisé** dans le graphe ET la liste ; défaut sûr quand `null` (affiche `label`).
  - **Thème injecté (AC5)** : un `ZcrudTheme` custom via `ZcrudScope`/`ThemeExtension` est **consommé** (ex. couleur de nœud = token injecté) ; aucune couleur codée en dur.
  - **RTL (AC4)** : sous `Directionality(rtl)`, l'indentation part du côté **start** (pas `left`) ; non-régression.
  - **Directionnel/lint (AC4)** : test/inspection asserant l'**absence** de `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `Positioned(left/right)`, `TextAlign.left/right` dans le code de la story (grep de garde admissible).
  - **Réactivité (AC6)** : un tap sur un nœud déclenche `onNodeTap`/sélection **sans reconstruire toute la vue** (le notifier local ne rebuild que la tranche concernée) ; aucun import de gestionnaire d'état (grep de garde).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E10 / Story E10-2]
- [Source: docs/canonical-schema.md#2.2 ZMindmapView (auto-layout, InteractiveViewer zoom/pan, aucun drag libre, vue liste sémantique a11y, nodeContentBuilder) ; #262 (RTL/a11y : directionnel, ExcludeSemantics, vue liste = surface a11y de référence)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1, #AD-2, #AD-13, #AD-15 ; Stack `graphite ^1.2.1` ; note « graphview superseded → graphite »]
- [Source: _bmad-output/implementation-artifacts/stories/e10-1-zmindmapnode-treeops.md (modèles consommés) ; packages/zcrud_mindmap/lib/src/domain/*.dart]
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart ; zcrud_scope.dart ; z_color_field_widget.dart (patron a11y/thème de référence)]
- [Source: CLAUDE.md#Critical-Patterns, #Key-Don'ts (directionnel RTL AD-13, ListView.builder, const, Semantics ≥48 dp, thème injecté, jamais de gestionnaire d'état dans un package UI hors binding)]

### Dépendance détectée pour l'orchestrateur
- **Aucun besoin d'édition de `zcrud_core`** : `ZcrudTheme`, `ZcrudScope`, `ZNode`, `ZExtensible` sont déjà exportés et suffisent. Si le dev-story découvre un token de thème réellement manquant, **le signaler à l'orchestrateur** (ne PAS éditer `zcrud_core` dans cette story).
- **Nouvelles arêtes pubspec** (attendues, non bloquantes) : `graphite: ^1.2.1` (autorisée par l'architecture) + `flutter: {sdk: flutter}`. **Aucune** arête vers un gestionnaire d'état / Firebase / Syncfusion.
- **Parallélisation** : `zcrud_mindmap` est un **package disjoint** — parallélisable avec des stories d'autres packages tant qu'aucune n'écrit `zcrud_core` en même temps (E10-2 n'y touche pas). Suit E10-1 (même package, séquentiel intra-package) ; précède E10-3 (éditeur outline, qui muter l'arbre).

## Dev Agent Record

### Implementation Plan
- **Task 0** — pubspec `zcrud_mindmap` : ajout `flutter: {sdk: flutter}` + `graphite: ^1.2.1` (arêtes AD-1 autorisées ; graphite tire transitivement `touchable`/`arrow_path`). Aucune arête gestionnaire d'état / Firebase / Syncfusion. `dart pub get` RC=0 (workspace lock partagé : +graphite +touchable +arrow_path).
- **Task 1** — `z_mindmap_graph_mapper.dart` : projection PURE forêt→`graphite` (liste plate `NodeInput`/`EdgeInput`, adjacency `parent.id→child.id` dérivée à la volée du nesting). **Choix multi-racine documenté** : racine virtuelle unique non affichée (arêtes `EdgeArrowType.none`) seulement si ≥2 racines ; mono-racine → nœuds réels seuls ; forêt vide → liste vide (l'appelant affiche l'état vide sans instancier `DirectGraph`).
- **Task 2** — `z_mindmap_view.dart` (`StatefulWidget`) : `DirectGraph` `MatrixOrientation.Vertical` (descendant), zoom/pan bornés par l'`InteractiveViewer` interne de graphite (`minScale`/`maxScale` de la config), **aucun callback de pan de nœud câblé → aucun drag libre**. `nodeBuilder` délègue au `nodeContentBuilder` (défaut sûr) ; racine virtuelle → `SizedBox.shrink()`. Graphe enveloppé d'`ExcludeSemantics`. État de vue local (sélection, mode) via `ValueNotifier` + `ValueListenableBuilder` (rebuild ciblé, create/dispose), **aucun `setState` global**.
- **Task 3** — `z_mindmap_list_view.dart` : `ListView.builder`, aplatissement profondeur-d'abord (1 entrée/nœud), indentation `EdgeInsetsDirectional.only(start: level*step)`, `Semantics` explicite (label=`node.label`, `hint` de profondeur, `selected`, `button`), cibles ≥48 dp, `TextAlign.start`. Le contenu (carte) est enveloppé d'`ExcludeSemantics` pour éviter le doublon de label ; la sémantique vit sur le parent.
- **Task 4** — `z_mindmap_view_config.dart` : `typedef ZMindmapNodeContentBuilder`, `ZMindmapNodeCallback`, `enum ZMindmapViewMode`, `ZMindmapViewConfig` immuable (bornes de zoom, `cellSize`, `cellSpacing`, `indentStep`, `minTapTarget≥48`) — aucune couleur. Callbacks `onNodeTap`/`onNodeSelected` sans mutation d'arbre.
- **Task 5** — barrel : export des 4 fichiers publics de présentation ; `ZMindmapApi` conservé ; zéro import manager/Firebase/Syncfusion ; **zéro edit `zcrud_core`**.
- **Task 6/7** — tests + vérif verte (voir ci-dessous).

### Completion Notes
- ✅ **AC1..AC7 satisfaits.** `ZMindmapView` (graphe graphite auto-agencé, zoom/pan bornés, aucun drag libre, multi-racine via racine virtuelle non affichée, forêt vide accessible) + `ZMindmapListView` (surface a11y de référence, `ListView.builder`, indentation directionnelle par `level`, `Semantics` explicites, ≥48 dp). `nodeContentBuilder` injectable partagé graphe/liste, défaut sûr sans dépendance à `zcrud_markdown`. Thème 100 % via `ZcrudTheme.of` (repli `Theme.of`), aucune couleur codée en dur. Réactivité Flutter-native (`ValueNotifier`/`ValueListenableBuilder`), aucun gestionnaire d'état.
- ✅ **Isolation** : modifications confinées à `packages/zcrud_mindmap/**` (+ lock workspace partagé). **`zcrud_core` NON modifié** — aucun besoin détecté (les seams `ZcrudTheme`/`ZcrudScope`/`ZNode`/`ZExtensible` suffisent).
- ✅ **Vérif verte rejouée** : `dart pub get` RC=0 · `dart analyze packages/zcrud_mindmap` RC=0 (No issues found) · `flutter test packages/zcrud_mindmap` RC=0 — **82 tests OK** dont **26 nouveaux** (E10-2 : `z_mindmap_view_test.dart` + `z_mindmap_conformance_test.dart`).
- ℹ️ **Choix de conception (multi-racine)** : racine virtuelle unique reliée par arêtes sans flèche (`EdgeArrowType.none`), rendue en taille nulle et exclue de la sémantique (graphe `ExcludeSemantics` + liste itérant la forêt réelle). N'est insérée que si ≥2 racines.
- ℹ️ **Surfaces équivalentes** : `ZMindmapView` bascule graphe⇄liste via un `ValueNotifier<ZMindmapViewMode>` interne (param `mode`), et `ZMindmapListView` est exporté et utilisable seul (surface a11y de référence composable par l'app).

### File List
- `packages/zcrud_mindmap/pubspec.yaml` (modifié — Task 0)
- `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` (modifié — barrel, Task 5)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_graph_mapper.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_list_view.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart` (nouveau)
- `packages/zcrud_mindmap/test/z_mindmap_view_test.dart` (nouveau)
- `packages/zcrud_mindmap/test/z_mindmap_conformance_test.dart` (nouveau)

### Change Log
- 2026-07-10 — E10-2 implémentée : `ZMindmapView` (graphite auto-layout, zoom/pan bornés, sans drag libre) + `ZMindmapListView` (a11y indentée par `level`) + `nodeContentBuilder` injectable ; thème injecté, réactivité Flutter-native, isolation `zcrud_mindmap`. Analyze RC=0, 82 tests verts (26 nouveaux). Statut → review.
