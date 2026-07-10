---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 10.1 : ZMindmapNode/ZMindmap + ZMindmapTreeOps

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**intégrateur d'une app de cartes mentales (lex_douane, DODLP)**,
je veux **un modèle de carte mentale canonique (`ZMindmap`/`ZMindmapNode`) et un moteur d'opérations d'arbre pur (`ZMindmapTreeOps`) couvrant add/update/delete/find ET move/indent/outdent avec recalcul fiable de `level`**,
afin de **manipuler l'arborescence d'une carte de façon immuable, prévisible et rétro-compatible, sans réimplémenter la dette de `MindmapTreeOps` (reparentage jamais codé dans lex) ni polluer le cœur du domaine**.

## Contexte & valeur

- **Épic E10 (Cartes mentales, `zcrud_mindmap`, v1.x)** — objectif : modèle / tree-ops / vue additifs pour lex_douane. Couvre **FR-19** ; AD-4, AD-13. Dépend de E2, E6. [Source: epics.md#E10]
- Cette story livre **uniquement le modèle de domaine + le moteur d'arbre pur** (Dart pur, aucune UI, aucune persistance). `ZMindmapView` (rendu graphite + vue liste a11y) = **E10-2**. Éditeur outline corrigé = **E10-3**. **Ne pas** anticiper ces stories.
- **Dette portée avec vigilance** : le docstring `MindmapTreeOps` de lex annonce `add/move/indent/outdent` mais **seuls `add/update/delete/find` sont codés** — `move/indent/outdent/reorder` **n'existent pas**. zcrud les **ajoute** au canonique avec recalcul systématique de `level`, en les signalant comme extension zcrud au-delà de lex. [Source: canonical-schema.md#2.2, #5 (dette n°5), OQ-5/OQ-10/OQ-11]

## Acceptance Criteria

**AC1 — `ZMindmapNode` : arbre par nesting + `level`, immuable, réutilise les contrats du cœur.**
- `ZMindmapNode` **étend `ZNode`** de `zcrud_core` (réutilise le contrat `id` non-null de réconciliation ; **ne PAS** recréer un contrat de nœud). [Source: zcrud_core/lib/src/domain/contracts/z_node.dart]
- Champs : `id: String` (non-null), `label: String` (non-null), `content: String?` (texte brut multiligne — **PAS markdown**), `children: List<ZMindmapNode>` (topologie par **nesting**, jamais adjacency), `level: int` (cache de profondeur dénormalisé, racine=0). [Source: canonical-schema.md#2.2]
- **Immuable par convention** : `final` partout, `List.unmodifiable`/liste défensivement copiée pour `children` ; **AUCUN `copyWith` public** (la mutation passe EXCLUSIVEMENT par `ZMindmapTreeOps`). [Source: canonical-schema.md#2.2 « immuable par convention, mute uniquement via MindmapTreeOps »]

**AC2 — `ZMindmapNode` porte les slots d'extension AD-4 (`data`/`ZExtension?` + `extra`).**
- `ZMindmapNode` **mixe `ZExtensible`** de `zcrud_core` : expose `extension: ZExtension?` (slot type additif **versionné**, défaut `null`) et `extra: Map<String,dynamic>` (échappatoire non typée, défaut `const {}`, jamais `null`). [Source: zcrud_core/lib/src/domain/extension/z_extensible.dart ; architecture.md#AD-4]
- Ce slot `extension` EST le « `data`/`ZExtension?` » exigé par l'épic (capacités domaine audio/sources/RAG/confiance sans polluer le cœur). **Ne PAS** définir une nouvelle base d'extension : réutiliser `ZExtension` (`abstract`, jamais `sealed`) et sa brique défensive `ZExtension.guard`. [Source: epics.md#E10-1 ; canonical-schema.md#2.2 ligne `data`]
- `extra` **round-trip** : les clés inconnues du cœur sont préservées telles quelles à la (dé)sérialisation.

**AC3 — `ZMindmap` : forêt titrée dans un container, SANS métadonnées de sync dans l'entité.**
- Champs : `id: String` (non-null), `folderId: String` (container/dossier, non-null), `title: String` (non-null), `description: String?`, `nodes: List<ZMindmapNode>` (racines de la forêt ; multi-racine autorisé). [Source: canonical-schema.md#2.2]
- **INVARIANT DUR (AD-16) : `ZMindmap` NE PORTE NI `updatedAt` NI `isDeleted`/`is_deleted` dans l'entité.** Les métadonnées de sync sont **HORS-ENTITÉ**, portées par `ZSyncMeta` (déjà dans `zcrud_core`), gérées par le store/dépôt (E5), **hors périmètre de cette story**. Un test asserte l'absence de ces champs sur `ZMindmap` et `ZMindmapNode`. [Source: canonical-schema.md#2.2 note d'invariant ; z_sync_meta.dart ; architecture.md#AD-16]
- `ZMindmap` mixe aussi `ZExtensible` (slots AD-4 au niveau carte).

**AC4 — `ZMindmapTreeOps` : opérations existantes portées (pures, structural sharing).**
- Moteur **pur** (fonctions statiques / classe sans état), **immuable**, avec **structural sharing** : tout sous-arbre non modifié est **retourné par référence** (`identical(before, after) == true`). [Source: canonical-schema.md#2.2 « pur, immuable, structural sharing via identical() »]
- Porte à l'identique du contrat lex : `updateNode(roots, nodeId, {label, content})`, `addChild(roots, parentId, child)`, `deleteNode(roots, nodeId)`, `findNode(roots, nodeId) → ZMindmapNode?`, factories `newRootNode()` et `newChildNode(parentLevel)`. Sémantique `content` : `''` efface, `null` = non touché (sur `updateNode`). [Source: canonical-schema.md#2.2 lignes 103, 122]
- Toutes les opérations opèrent sur une **forêt** `List<ZMindmapNode>` (racines) et renvoient une **nouvelle forêt**.

**AC5 — `ZMindmapTreeOps` : `move`/`indent`/`outdent`/`reorder` AJOUTÉS avec recalcul de `level`.**
- `moveNode(roots, nodeId, newParentId, {int? index})` : reparente `nodeId` (et son sous-arbre) sous `newParentId` (ou en racine si `newParentId == null`) à la position `index` ; **recalcule `level`** de tout le sous-arbre déplacé (nouvelle racine du sous-arbre = `newParentLevel + 1`, ou `0` en racine, puis cascade `enfant.level = parent.level + 1`). [Source: canonical-schema.md#2.2 MANQUANT, #5 dette n°5]
- `indentNode(roots, nodeId)` : rattache le nœud comme **dernier enfant de son frère précédent** ; recalcule `level` (+1 en cascade). **No-op** si le nœud est premier de sa fratrie (pas de frère précédent).
- `outdentNode(roots, nodeId)` : rattache le nœud comme **frère suivant de son parent** ; recalcule `level` (−1 en cascade). **No-op** si le nœud est une racine (pas de parent).
- `reorderChild(roots, parentId, oldIndex, newIndex)` : réordonne une fratrie ; `level` inchangé.
- **Anti-cycle** : `moveNode` vers soi-même ou vers un **descendant** de `nodeId` est **rejeté en no-op** (renvoie la forêt d'origine `identical`), jamais de corruption ni de boucle infinie.
- Toute opération no-op (cible introuvable, déplacement sans effet, indent/outdent impossible) renvoie la **forêt d'entrée par référence** (`identical`).

**AC6 — Désérialisation défensive (AD-10) : un champ absent/corrompu ne fait jamais échouer le parent.**
- `ZMindmap.fromJson` / `ZMindmapNode.fromJson` **ne throwent JAMAIS** : `children`/`nodes` absent ou non-liste → `[]` ; `label`/`title` absent → chaîne vide (défaut UI) ; `content`/`description` absent → `null` ; `level` absent/non-int → recalculé/`0` ; `extension` de `formatVersion` non gérée ou corrompue → `null` (via `fromJsonSafe`/`ZExtension.guard`) sans invalider le nœud ; `extra` = clés résiduelles préservées. [Source: architecture.md#AD-10 ; z_extension.dart guard]
- (Dé)sérialisation **round-trip** stable. Persistance : clés **snake_case** (uniformisation canonique §5 — le camelCase brut de lex est corrigé ici), dates ISO-8601 si applicable, **valeurs d'enum en camelCase** le cas échéant. [Source: canonical-schema.md#5 ; architecture.md#AD-3]

**AC7 — Barrel & isolation architecturale.**
- API publique exportée via le barrel `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` (impl sous `lib/src/domain/`). Le placeholder `ZMindmapApi` (`z_mindmap_api.dart`) est **conservé** (arêtes AD-1). [Source: zcrud_mindmap/lib/src/domain/z_mindmap_api.dart]
- **AD-1 (acyclicité)** : `zcrud_mindmap` dépend de `zcrud_core` (+ `zcrud_markdown` déjà déclaré) ; **JAMAIS l'inverse**. **CONTRAINTE DURE : cette story NE MODIFIE PAS `zcrud_core`** — toutes les briques nécessaires (`ZNode`, `ZExtensible`, `ZExtension`, `ZSyncMeta`) y existent déjà. [Source: CLAUDE.md#Key-Don'ts ; architecture.md#AD-1]

## Tasks / Subtasks

- [x] **Task 1 — `ZMindmapNode` (AC1, AC2, AC6)**
  - [x] Créer `lib/src/domain/z_mindmap_node.dart` : classe étendant `ZNode`, mixant `ZExtensible`.
  - [x] Champs `final` : `id`, `label`, `content?`, `children` (copie défensive / non-modifiable), `level` ; slots `extension`/`extra` (défaut `null`/`const {}`).
  - [x] `fromJson`/`toJson` défensifs (AD-10), snake_case, round-trip ; **aucun `copyWith` public**.
  - [x] Identité par référence (défaut, aligné canonique §5) — pas d'override `==` nécessaire, l'API repose sur `identical()` pour le structural sharing.
- [x] **Task 2 — `ZMindmap` (AC3, AC6)**
  - [x] Créer `lib/src/domain/z_mindmap.dart` : `id`, `folderId`, `title`, `description?`, `nodes`, slots `ZExtensible`.
  - [x] **NE PAS** ajouter `updatedAt`/`isDeleted` (sync hors-entité `ZSyncMeta`) — invariant testé.
  - [x] `fromJson`/`toJson` défensifs, snake_case (`folder_id`), round-trip ; renormalisation des `level` à la lecture.
- [x] **Task 3 — `ZMindmapTreeOps` : port des opérations existantes (AC4)**
  - [x] Créer `lib/src/domain/z_mindmap_tree_ops.dart` : `updateNode`, `addChild`, `deleteNode`, `findNode`, factories `newRootNode`/`newChildNode(parentLevel)`.
  - [x] Moteur privé `_replaceNode`/`_removeNode` garantissant le **structural sharing** (`identical` sur sous-arbres intacts).
- [x] **Task 4 — `ZMindmapTreeOps` : opérations ajoutées + recalcul `level` (AC5)**
  - [x] `moveNode` (garde anti-cycle vers soi/descendant + no-op même-emplacement), `indentNode`, `outdentNode`, `reorderChild`.
  - [x] Helper privé `_recomputeLevels(subtree, baseLevel)` appliqué à tout sous-arbre reparenté + `normalizeLevels`.
  - [x] No-op → forêt d'entrée `identical`.
- [x] **Task 5 — Barrel & conformité (AC7)**
  - [x] Exporter les 3 fichiers dans `lib/zcrud_mindmap.dart` ; `ZMindmapApi` conservé.
  - [x] Zéro import de gestionnaire d'état / Firebase / Syncfusion ; zéro edit `zcrud_core`.
- [x] **Task 6 — Tests (voir Testing requirements) (AC1..AC6)**
  - [x] `test/z_mindmap_node_test.dart`, `test/z_mindmap_test.dart`, `test/z_mindmap_tree_ops_test.dart` — 55 tests verts.
- [x] **Task 7 — Vérif verte**
  - [x] Aucun codegen (`*.g.dart`) requis (JSON hand-written immuable/défensif, permis par Dev Notes) → `dart analyze` RC=0 → `flutter test` RC=0 (55 tests).

## Dev Notes

### Réutilisation OBLIGATOIRE du cœur (anti-réinvention)
- **`ZNode`** (`zcrud_core`, exporté) : contrat `id` non-null. `ZMindmapNode extends ZNode`. Ne PAS recréer un contrat de nœud. [Source: z_node.dart]
- **`ZExtensible` + `ZExtension`** (`zcrud_core`, exportés) : slots AD-4. `ZMindmapNode`/`ZMindmap` mixent `ZExtensible`. Extensions concrètes = sous-classes de `ZExtension` (dans l'app hôte / stories ultérieures), pas ici. Utiliser `ZExtension.guard(...)` pour le parse défensif ; `zExtraRead<T>` pour lire `extra`. [Source: z_extensible.dart, z_extension.dart]
- **`ZSyncMeta`** (`zcrud_core`, exporté) : le réceptacle hors-entité des `updated_at`/`is_deleted`. `ZMindmap` **n'en dépend pas directement** (la sync est branchée en E5) — juste **ne pas** dupliquer ces champs dans l'entité. [Source: z_sync_meta.dart]

### Pièges spécifiques mindmap (ne pas se tromper de modèle)
- **Nesting, PAS adjacency** : la carte mentale zcrud est un arbre par `children` imbriqués + `level` dénormalisé — **PAS** l'univers douane/RAG à adjacence plate (`ComparativeNode`/`NodeContext`/`HierarchyNode`, markdown + audio). Ne pas confondre. [Source: canonical-schema.md#2.2 « Piège de nommage à éviter »]
- **`content` = texte brut**, pas markdown (le rendu riche est une extension pluggable, hors E10-1).
- **`level` = cache fragile** maintenu par l'appelant → dans zcrud, **recalcul systématique** par `ZMindmapTreeOps` à chaque reparentage (fiabiliser OQ-11). Ne jamais faire confiance au `level` d'un nœud déplacé : le recomputer.
- **Immuabilité stricte** : jamais de mutation en place de `children`/`level` ; toute transformation reconstruit les nœuds impactés et **partage** les sous-arbres intacts (`identical`).

### Sérialisation
- Hand-written `fromJson`/`toJson` immuables + défensifs sont acceptables et conformes à l'origine lex (nœud sans `copyWith`, mutation via TreeOps). Si `@ZcrudModel` est utilisé, garder l'immuabilité et **ne pas** exposer de `copyWith` public sur `ZMindmapNode` (mutation via TreeOps uniquement) ; l'uniformisation casse/sentinelle relève d'OQ-12 (générateur) et n'est pas bloquante ici. [Source: architecture.md#AD-3 ; canonical-schema.md#5, OQ-12]
- **snake_case** en persistance (correction de la divergence camelCase de lex, canonique §5).

### Project Structure Notes
- Package : `packages/zcrud_mindmap/`. Impl sous `lib/src/domain/` ; barrel `lib/zcrud_mindmap.dart`. Placeholder `ZMindmapApi` conservé.
- Aucune couche `data/`/`presentation/` dans cette story (domaine pur). Persistance/vue = stories ultérieures.

### Testing requirements
- Framework : `flutter test` (package), `*_test.dart`.
- **Couverture obligatoire** (ACs testables) :
  - **`level`** : après `addChild` (level=parent+1), `moveNode` (racine→0, sous-parent→+1, cascade sur descendants profonds ≥3 niveaux), `indentNode` (+1 cascade), `outdentNode` (−1 cascade). Asserter le `level` de CHAQUE nœud du sous-arbre déplacé.
  - **Structural sharing** : après une op ciblée, les sous-arbres non touchés sont `identical` à l'entrée ; une op no-op renvoie la forêt d'entrée `identical`.
  - **move/indent/outdent** : cas nominaux + bornes — indent du premier enfant (no-op), outdent d'une racine (no-op), `moveNode` vers un descendant / vers soi-même (rejet no-op, pas de cycle), `moveNode` avec `index` hors bornes (clamp ou no-op documenté).
  - **add/update/delete/find** : `updateNode` avec `content:''` (efface) vs `content:null` (inchangé) ; `deleteNode` d'un nœud interne (enfants supprimés avec) ; `findNode` profond et introuvable (`null`).
  - **AC3 invariant** : test asserant que la sérialisation de `ZMindmap`/`ZMindmapNode` ne contient PAS `updated_at`/`is_deleted`.
  - **AD-10 défensif** : `fromJson` sur maps corrompues/partielles (children absent, level non-int, extension `formatVersion` inconnue, clés extra inconnues) → jamais de throw, valeurs de repli correctes, `extra` préservé au round-trip.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E10 / Story E10-1]
- [Source: docs/canonical-schema.md#2.2 ZMindmap / ZMindmapNode (+ tree ops) ; #5 (dette n°5, OQ-5/OQ-10/OQ-11/OQ-12) ; #note d'invariant sync hors-entité]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1, #AD-3, #AD-4, #AD-10, #AD-13, #AD-16]
- [Source: packages/zcrud_core/lib/src/domain/contracts/z_node.dart]
- [Source: packages/zcrud_core/lib/src/domain/extension/z_extensible.dart ; z_extension.dart]
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart]
- [Source: packages/zcrud_mindmap/lib/src/domain/z_mindmap_api.dart]
- [Source: CLAUDE.md#Critical-Patterns, #Key-Don'ts (jamais de gestionnaire d'état / Firebase dans le domaine ; directionnel RTL AD-13 — non applicable ici, pas d'UI)]

### Dépendance détectée pour l'orchestrateur
- **Aucun besoin d'édition de `zcrud_core`** : `ZNode`, `ZExtensible`, `ZExtension`, `ZSyncMeta` sont déjà exportés. Story auto-suffisante sur `zcrud_mindmap` (fichiers disjoints). Parallélisable avec E5-3 / E9-1 (packages disjoints, aucun contact `zcrud_core`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, mode Skill).

### Debug Log References

- 1 erreur d'inférence de type corrigée : `ZExtension.guard(...)` inférait `T = ZExtension` (non-null) alors que le décodeur renvoie `ZExtension?` → explicité en `ZExtension.guard<ZExtension?>(...)` dans les deux `fromJson`.
- `dart analyze packages/zcrud_mindmap` → RC=0, « No issues found! ».
- `flutter test` (package) → RC=0, **55 tests** verts.

### Completion Notes List

- Domaine pur (Dart) — aucune couche `data/`/`presentation/`, aucun codegen (`*.g.dart`) : `fromJson`/`toJson` hand-written immuables + défensifs (permis par Dev Notes / AD-3).
- **Réutilisation stricte du cœur (AD-1)** : `ZMindmapNode extends ZNode with ZExtensible` ; `ZMindmap with ZExtensible` ; `ZExtension.guard` pour le parse défensif. **Zéro édition de `zcrud_core`** (contrainte de parallélisation WS-C respectée).
- **AC1** : `ZMindmapNode` immuable, `children` en `List.unmodifiable` (copie défensive), aucun `copyWith` public — mutation exclusivement via `ZMindmapTreeOps`.
- **AC2** : slots AD-4 `extension` (versionné, défaut null) + `extra` (jamais null) ; `extra` = clés résiduelles inconnues, round-trip préservé.
- **AC3** : `ZMindmap` forêt multi-racine, `folder_id` snake_case ; **aucun `updatedAt`/`is_deleted`** (invariant AD-16 testé sur node ET map).
- **AC4** : `updateNode` (`''` efface / `null` non touché), `addChild`, `deleteNode`, `findNode`, `newRootNode`/`newChildNode` ; structural sharing via `_replaceNode`/`_removeNode` (`identical` sur branches intactes).
- **AC5** : `moveNode` (recalcul `level` cascade, base = newParent.level+1 ou 0 ; anti-cycle soi/descendant ; no-op même-emplacement), `indentNode` (+1), `outdentNode` (−1), `reorderChild` (level inchangé, supporte racines via `parentId == null`). Helper `_recomputeLevels` + `normalizeLevels`. UUID v4 généré sans dépendance externe (`Random.secure`).
- **AC6** : `fromJson` ne throw jamais (children/nodes non-liste → [], enfants corrompus ignorés, level non-int → 0 puis renormalisé, extension formatVersion inconnue/décodeur throw → null, extra préservé) ; round-trip stable.
- **AC7** : barrel exporte les 3 fichiers, `ZMindmapApi` conservé ; `dev_dependencies: flutter_test` ajoutée (aucune arête runtime `zcrud_*` nouvelle).

### File List

- `packages/zcrud_mindmap/lib/src/domain/z_mindmap_node.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart` (nouveau)
- `packages/zcrud_mindmap/lib/src/domain/z_mindmap_tree_ops.dart` (nouveau)
- `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` (modifié — exports)
- `packages/zcrud_mindmap/pubspec.yaml` (modifié — dev_dependencies flutter_test)
- `packages/zcrud_mindmap/test/z_mindmap_node_test.dart` (nouveau)
- `packages/zcrud_mindmap/test/z_mindmap_test.dart` (nouveau)
- `packages/zcrud_mindmap/test/z_mindmap_tree_ops_test.dart` (nouveau)
