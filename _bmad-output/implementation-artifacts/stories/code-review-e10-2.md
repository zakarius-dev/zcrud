# Code Review — E10-2 : ZMindmapView (graphite auto-layout + vue liste a11y)

- **Mode** : skill réel `bmad-code-review` (workflow step-file) — exécution autonome (subagent), diff construit depuis `baseline_commit` 04aaaf09, scope `packages/zcrud_mindmap/` uniquement.
- **Story** : `_bmad-output/implementation-artifacts/stories/e10-2-zmindmapview-graphite.md` (7 ACs).
- **Vérif rejouée réellement sur disque** :
  - `dart analyze packages/zcrud_mindmap` → **RC=0** (« No issues found! »).
  - `flutter test packages/zcrud_mindmap` → **RC=0**, **82 tests OK** (dont 26 nouveaux E10-2 : `z_mindmap_view_test.dart` 16 + `z_mindmap_conformance_test.dart` 10).
- **Fichiers revus** : `pubspec.yaml`, barrel `zcrud_mindmap.dart`, `lib/src/presentation/{z_mindmap_view_config, z_mindmap_graph_mapper, z_mindmap_node_card, z_mindmap_list_view, z_mindmap_view}.dart`, `test/{z_mindmap_view_test, z_mindmap_conformance_test}.dart`.

---

## Findings

### HIGH / MAJEUR

#### H1 — La surface a11y de référence (vue liste) n'expose AUCUNE action sémantique d'activation (AD-13)
- **Fichier** : `lib/src/presentation/z_mindmap_list_view.dart:109-135`
- **Constat** : chaque entrée est un `Semantics(container: true, button: onNodeTap != null, label: node.label, …)` dont l'enfant interactif est `ExcludeSemantics( child: ZMindmapNodeCard(onTap: onNodeTap) )`. Le seul geste d'activation réel est le `GestureDetector` **interne à la carte** (`z_mindmap_node_card.dart:120-124`), or il est placé **sous `ExcludeSemantics`** → son action sémantique `tap` est supprimée. Le `Semantics` parent déclare `button: true` mais **ne fournit aucun `onTap:`**. Résultat : le nœud de sémantique fusionné est annoncé comme bouton mais **ne porte pas de `SemanticsAction.tap`**.
- **Impact** : un utilisateur de lecteur d'écran (TalkBack/VoiceOver) entend « bouton » mais le double-tap d'activation **ne déclenche rien** — `onNodeTap` n'est jamais appelé par la voie assistive. La vue liste est pourtant désignée par la story (AC2/AC4) comme **la surface d'accessibilité de référence** : son unique chemin d'interaction a11y est cassé. Le pointeur (souris/doigt) fonctionne, ce qui masque le défaut ; les tests AC6 tapent via `tester.tap` (pointeur), jamais via une action sémantique — le trou n'est pas couvert.
- **Recommandation** : porter l'action sur le `Semantics` parent :
  `Semantics(..., button: onNodeTap != null, onTap: onNodeTap == null ? null : () => onNodeTap!(node), child: …)`.
  Conserver `ExcludeSemantics` sur la carte pour éviter le doublon de label. Ajouter un test qui exerce `SemanticsAction.tap` (via `tester.binding.pipelineOwner.semanticsOwner.performAction(id, SemanticsAction.tap)` ou `find.bySemanticsLabel` + action) et vérifie que `onNodeTap` est bien invoqué.

---

### MEDIUM

#### M1 — Double `ValueListenableBuilder` redondant sur le même notifier dans la vue liste
- **Fichier** : `lib/src/presentation/z_mindmap_list_view.dart:105-137` + `z_mindmap_node_card.dart:89-91`
- **Constat** : dans le `itemBuilder`, chaque entrée est déjà enveloppée d'un `ValueListenableBuilder<String?>(valueListenable: selectedListenable)` (pour piloter `Semantics(selected: isSelected)`). La `ZMindmapNodeCard` qu'elle contient **re-souscrit au même `selectedListenable`** via son propre `ValueListenableBuilder`. Chaque ligne de liste porte donc deux abonnements empilés au même notifier ; à chaque changement de sélection, la ligne reconstruit deux fois (Semantics+Padding puis la carte). De plus, comme **toutes** les cartes écoutent le notifier partagé, une sélection reconstruit O(n) lignes et non « la seule tranche concernée » (AC6, littéral : « le notifier local ne rebuild que la tranche concernée »).
- **Impact** : rebuild redondant/non minimal ; s'éloigne de l'objectif AC6 de rebuild strictement ciblé. Fonctionnellement correct mais inefficace pour de grandes cartes.
- **Recommandation** : dans le chemin liste, ne garder qu'un seul point d'écoute — soit consommer `isSelected` déjà calculé par le VLB externe et passer un `ZMindmapNodeCard` non ré-abonné (variante « selected: bool »), soit retirer le VLB externe et laisser la carte porter l'état, en déplaçant l'attribut `Semantics(selected:)` à l'intérieur. Éviter la double souscription.

---

### LOW / nits

#### L1 — Champ mort `_FlatEntry.indexInTraversal`
- **Fichier** : `lib/src/presentation/z_mindmap_list_view.dart:25-29, 68`
- Le champ `indexInTraversal` est stocké (`out.length`) mais **jamais lu**. Code mort. Recommandation : supprimer le champ (et réduire `_FlatEntry` au seul `node`, voire remplacer par `List<ZMindmapNode>`).

#### L2 — Closure de contenu par défaut réallouée à chaque build
- **Fichier** : `lib/src/presentation/z_mindmap_view.dart:101-103`
- Le getter `_contentBuilder` recrée la closure `(context, node) => ZMindmapDefaultNodeContent(node: node)` à chaque `build` quand `nodeContentBuilder == null`, cassant toute stabilité d'identité passée aux cartes. Impact négligeable (cartes `StatelessWidget` de toute façon reconstruites) mais évitable. Recommandation : mémoïser le défaut dans un champ `late final` du State.

#### L3 — `Semantics.label` = `node.label` brut alors que le contenu par défaut a un repli sur `content`
- **Fichier** : `lib/src/presentation/z_mindmap_list_view.dart:113` vs `z_mindmap_node_card.dart:38`
- Le `Semantics` annonce `node.label` tel quel ; or `ZMindmapDefaultNodeContent` affiche un extrait de `content` quand `label` est vide. Pour un nœud « content-only » (label vide), le lecteur d'écran annonce un label **vide** alors que la surface visuelle montre du texte. Incohérence a11y mineure. Recommandation : aligner le label sémantique sur la même règle de repli (`node.label.isNotEmpty ? node.label : (node.content ?? '')`).

#### L4 — Racine virtuelle multi-racine : cellule vide réservée dans le layout
- **Fichier** : `lib/src/presentation/z_mindmap_view.dart:164-168` + `z_mindmap_graph_mapper.dart:57-70`
- La racine virtuelle est rendue en `SizedBox.shrink()` et exclue de la sémantique (correct), mais `graphite` lui alloue tout de même un emplacement dans l'auto-layout (arêtes `EdgeArrowType.none` vers les racines réelles) → possible espace vide/arêtes fantômes en tête de graphe en mode multi-racine. Purement visuel, choix documenté et acceptable. Informationnel : à surveiller si un rendu propre multi-racine est exigé plus tard (E10-3).

---

## Conformité aux axes adversariaux (vérifiée)

- **AD-1 (isolation)** : diff limité à `packages/zcrud_mindmap/` ; **zéro edit `zcrud_core`** confirmé. Arêtes ajoutées au pubspec = `flutter (sdk)` + `graphite ^1.2.1` uniquement ; aucune arête gestionnaire d'état/Firebase/Syncfusion. `zcrud_markdown` reste une dépendance **utilisée par le domaine** (`z_mindmap_api.dart`, arête AD-1 E10-1) — pas un finding E10-2. ✅
- **Projection forêt→graphite** : pure (`ZMindmapGraphMapper.fromForest`), arêtes `parent.id→child.id` par nesting, racine virtuelle seulement si ≥2 racines, non affichée et hors sémantique (graphe entier `ExcludeSemantics`, liste itère la forêt réelle) → **aucune fuite** de la racine virtuelle. ✅
- **AD-13 (directionnel)** : `EdgeInsetsDirectional`, `AlignmentDirectional.centerStart`, `TextAlign.start` partout ; garde grep conformité verte ; test RTL asserte `resolve(rtl).right == 48`. ✅ (mais activation sémantique cassée, cf. H1).
- **≥48 dp** : `ConstrainedBox(minWidth/minHeight: config.minTapTarget)` avec `assert(minTapTarget>=48)` ; test présent. ✅
- **AD-2/AD-15 (réactivité)** : aucun import `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.*`/`Provider.of` (garde grep) ; état local via `ValueNotifier` + `ValueListenableBuilder`, create/dispose corrects ; aucun `setState` global ; la sélection ne reconstruit pas `_buildGraph` (VLB externe sur `_mode` seulement). ✅ (réserve d'efficience M1).
- **FR-26 (thème)** : couleurs via `ZcrudTheme.of(context)` avec repli `Theme.of(context)` ; aucun littéral `Color(0x…)`/`Colors.*` dans le code de prod ; test AC5 prouve la consommation du token `surfaceColor` injecté. ✅ (largeurs de bordure 1/2 = constantes géométriques, aucun token existant → admissible).
- **ListView.builder** : utilisé (pas de `ListView(children:)`). ✅
- **`nodeContentBuilder`** : défaut sûr sans dépendance dure à `zcrud_markdown` (le défaut n'importe que `zcrud_core`/Material) ; appliqué à l'identique graphe+liste ; tests d'injection présents. ✅
- **Qualité des gardes grep** : `z_mindmap_conformance_test.dart` retire réellement les commentaires avant de chercher les motifs interdits (docstrings citant les API bannies non comptés) et itère sur tous les fichiers `lib/src/presentation/**` → gardes AD-13/AD-2 effectives et non cosmétiques. ✅

---

## Verdict

**CORRECTIONS REQUISES avant `done`.**

- **H1 (MAJEUR)** doit être corrigé : la vue liste, désignée surface a11y de référence (AD-13, objectif central de la story), n'expose aucune action d'activation aux lecteurs d'écran. Correction ciblée (ajout `onTap` sur le `Semantics` parent) + test d'action sémantique.
- **M1 (MEDIUM)** à corriger par défaut dans le périmètre (double souscription redondante) ou justifier par écrit si reporté.
- **L1–L4** optionnels (L1/L2 triviaux, recommandés).

Analyze **RC=0**, tests **RC=0 / 82 OK** — la story est verte mais le défaut H1 échappe à la suite actuelle (aucun test n'exerce l'activation via action sémantique). Re-vérif verte exigée après correction.

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_mindmap` RC=0, `flutter test packages/zcrud_mindmap` **83 tests** (+1 H1).

- **H1 (MAJEUR) — CORRIGÉ.** Action sémantique d'activation ajoutée sur le `Semantics` parent de chaque entrée de liste (`onTap: onNodeTap != null ? () => onNodeTap!(node) : null`, `z_mindmap_list_view.dart`). **Test dédié ajouté** (`z_mindmap_view_test.dart`) : active l'entrée via `SemanticsAction.tap` (voie lecteur d'écran, ≠ tap pointeur) et vérifie que `onNodeTap` remonte le bon nœud — assertion `hasAction(SemanticsAction.tap)` incluse.
- **M1 (MEDIUM) — CORRIGÉ.** Suppression du double `ValueListenableBuilder` : `ZMindmapNodeCard` reçoit désormais un `bool isSelected` déjà résolu (plus d'abonnement interne). Le point d'écoute unique vit dans la surface parente (ligne de liste ET nœud graphe). Rebuild ciblé conforme AC6/AD-2.
- **L1 — CORRIGÉ** : `_FlatEntry.indexInTraversal` (champ mort) supprimé ; `_flatten` renvoie directement `List<ZMindmapNode>`.
- **L2 — CORRIGÉ** : contenu par défaut = tear-off statique stable `_defaultContent` (plus de closure réallouée par build).
- **L3 — CORRIGÉ** : `Semantics.label` applique le même repli que le contenu par défaut (`label` sinon `content`) → un nœud « content-only » annonce un texte utile.
- **L4 — CONSIGNÉ** (visuel documenté) : la racine virtuelle multi-racine réserve une cellule vide dans le layout graphite ; non bloquant, à affiner si besoin en E10-3.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
