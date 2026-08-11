# zcrud_mindmap

Cartes mentales pour zcrud : un arbre immuable `ZMindmap`/`ZMindmapNode`, un
moteur de mutation pur `ZMindmapTreeOps`, et une vue graphite avec un éditeur
outline — invariant AD-2 (réactivité Flutter-native) de bout en bout.

## Aperçu {#apercu}

`zcrud_mindmap` est le paquet satellite qui porte les cartes mentales de
zcrud, au-dessus du cœur (`zcrud_core`, invariant AD-1) et de la couche
rich-text (`zcrud_markdown`, opt-in). Le domaine — `ZMindmap` (forêt titrée),
`ZMindmapNode` (nœud récursif par nesting) et `ZMindmapTreeOps` (moteur de
mutation pur) — est indépendant de tout rendu ; la présentation ajoute une
vue graphe auto-agencée (`graphite`), une vue liste sémantique accessible et
un éditeur outline dont la sauvegarde applique réellement les modifications.

Ce paquet fournit :

- le **modèle** — `ZMindmap`/`ZMindmapNode`, une forêt multi-racine titrée
  dans un dossier, sérialisable et défensive (invariant AD-10) ;
- le **moteur d'arbre** — `ZMindmapTreeOps`, des opérations pures
  (ajout/mise à jour/suppression/recherche, déplacement/indentation/
  réordonnancement) avec partage structurel par `identical()` ;
- la **vue** — `ZMindmapView`, deux surfaces équivalentes (graphe `graphite`
  et liste indentée accessible) partageant le même constructeur de contenu
  de nœud, avec zoom piloté, mode compact, plein écran et super-racine
  opt-in ;
- l'**éditeur outline** — `ZMindmapOutlineEditor`, une liste indentée
  éditable dont le `ZMindmapOutlineController` est la source de vérité
  unique, avec rebuild granulaire (invariant AD-2) ;
- des **seams rich-text opt-in** — `ZMindmapMarkdownContent` et
  `ZMindmapMarkdownEditField`, de fins adaptateurs vers `zcrud_markdown` qui
  n'imposent rien par défaut (le contenu de nœud reste texte brut tant que
  l'hôte n'injecte pas ces seams).

**Utilisez ce paquet** pour construire une carte mentale éditable dans une
application Flutter — vue graphe ou liste, édition outline, contenu riche
opt-in. **N'utilisez pas ce paquet** pour un simple arbre de données sans
rendu (le modèle `ZMindmap`/`ZMindmapTreeOps` suffit alors, sans tirer
`graphite` ni les widgets de présentation) ni pour du rendu Markdown/LaTeX
autonome, hors du contexte d'un nœud de carte (utilisez `zcrud_markdown`
directement).

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Une forêt d'une seule racine, et sa vue par défaut.
///
/// Toute mutation passe exclusivement par [ZMindmapTreeOps] — jamais de
/// `copyWith` direct sur un [ZMindmapNode].
List<ZMindmapNode> buildInitialForest() {
  var forest = <ZMindmapNode>[ZMindmapTreeOps.newRootNode()];
  forest = ZMindmapTreeOps.updateNode(
    forest,
    forest.first.id,
    label: 'Racine',
  );
  return forest;
}

/// Le rendu par défaut : graphe auto-agencé + vue liste accessible
/// équivalente, sans aucune dépendance à `zcrud_markdown`.
Widget buildMindmap(List<ZMindmapNode> forest) {
  return ZMindmapView(roots: forest);
}
```

## Concepts clés {#concepts-cles}

- **Arbre par nesting, mutation par moteur pur** — `ZMindmapNode` est un
  arbre récursif (`children`), jamais une liste à adjacence ; il ne porte
  aucun `copyWith` public. Toute mutation passe par `ZMindmapTreeOps`, qui
  renvoie une nouvelle forêt (ou l'entrée `identical` si l'opération est un
  no-op) et recalcule systématiquement le cache `level` du sous-arbre
  reparenté.
- **Deux surfaces équivalentes** — le graphe `graphite` (visuel,
  `ExcludeSemantics`, zoom/pan bornés) et la vue liste indentée sont deux
  projections en lecture seule de la **même** forêt ; la vue liste est la
  surface d'accessibilité de référence, parcourue en profondeur-d'abord.
- **Rich-text opt-in, jamais par défaut (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  `ZMindmapMarkdownContent`/`ZMindmapMarkdownEditField` sont de fins
  adaptateurs vers `zcrud_markdown`, montés seulement par injection
  explicite (`nodeContentBuilder`, `editFieldBuilder`) ; sans eux, le
  contenu d'un nœud reste du texte brut, et ce paquet ne tire jamais Quill.
- **Réactivité granulaire (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  `ZMindmapOutlineController` et `ZMindmapViewController` sont des
  `ChangeNotifier`/agrégats de `ValueNotifier` purs Flutter ; une frappe de
  texte ne notifie pas les mutations structurelles, un zoom ne reconstruit
  pas les nœuds.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Domaine** | |
| `ZMindmap` | Carte mentale immuable : forêt de nœuds racines titrée dans un dossier. |
| `ZMindmapNode` | Nœud récursif par nesting, avec cache de profondeur `level` dénormalisé. |
| `ZMindmapTreeOps` | Moteur d'opérations d'arbre pur : ajout/mise à jour/suppression/recherche/déplacement/indentation/réordonnancement. |
| `ZExtensionDecoder` | Décodeur d'extension typée injecté à la désérialisation d'un nœud. |
| **Vue** | |
| `ZMindmapView` | Vue d'une forêt : graphe auto-agencé ou liste accessible, zoom, compact, plein écran, super-racine. |
| `ZMindmapViewConfig` / `ZMindmapViewMode` | Réglages géométriques partagés et mode de rendu (graphe / liste). |
| `ZMindmapViewController` / `ZMindmapViewLabels` | État de vue local (zoom/compact/plein écran) et libellés a11y externalisés des contrôles. |
| `ZMindmapListView` | Vue liste sémantique indentée seule, surface d'accessibilité de référence. |
| `ZMindmapCellClip` | Borne un contenu de nœud à sa cellule graphe, sans débordement visuel. |
| `ZMindmapNodeCard` | Carte de nœud thématisée, partagée par le graphe et la vue liste. |
| `ZMindmapDefaultNodeContent` | Rendu de contenu de nœud par défaut (texte brut). |
| `ZMindmapNodeContentBuilder` / `ZMindmapNodeCallback` | Point d'injection du rendu de contenu d'un nœud et callback d'interaction. |
| **Éditeur outline** | |
| `ZMindmapOutlineEditor` | Liste indentée éditable dont la sauvegarde applique réellement les modifications. |
| `ZMindmapOutlineController` | Source de vérité unique de l'éditeur, `ChangeNotifier` pur mutant via `ZMindmapTreeOps`. |
| `ZMindmapOutlineLabels` | Libellés a11y externalisés de l'éditeur outline. |
| `ZMindmapForestCallback` / `ZMindmapOutlineEmptyBuilder` | Callback de sauvegarde de la forêt et builder de l'état vide, tous deux opt-in. |
| `ZMindmapEditFieldKind` / `ZMindmapEditFieldContext` / `ZMindmapEditFieldBuilder` | Nature de champ édité, son contexte, et le point d'injection d'un champ d'édition riche. |
| **Rich-text opt-in** | |
| `ZMindmapMarkdownContent` | Adaptateur mince de rendu Markdown/LaTeX pour le contenu d'un nœud. |
| `ZMindmapMarkdownEditField` | Adaptateur mince d'édition Markdown/LaTeX pour un champ de nœud. |
| **Interne graphe** | |
| `ZMindmapGraphMapper` / `ZMindmapGraphData` | Projection en lecture seule de la forêt vers la structure `graphite`. |
| `ZMindmapApi` | Marqueur de version d'API publique, rattache les arêtes de dépendance invariant AD-1. |

## Cas limites et invariants {#cas-limites}

- **Sync hors-entité (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  ni `ZMindmap` ni `ZMindmapNode` ne portent `updatedAt` ou `is_deleted` :
  ces métadonnées vivent dans `ZSyncMeta`, gérées par le store/dépôt.
- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un `extra` corrompu ou un `ZExtensionDecoder` qui échoue ne fait jamais
  échouer le parsing d'un nœud ou d'une carte.
- **Forêt vide guidée, jamais une page blanche** — `ZMindmapOutlineEditor`
  rend toujours une structure d'ajout centrée quand la forêt est vide ; les
  libellés associés (`emptyTitle`, `emptyMessage`, `emptyActionLabel`) ne
  sont montés que si l'hôte les fournit.
- **Contrôleur remplacé en cours de vie** — si `ZMindmapOutlineEditor` reçoit
  un nouveau `controller` en `didUpdateWidget`, l'ancien contrôleur possédé
  (le cas échéant) est disposé et le nouveau adopté ; un contrôleur injecté
  par l'appelant n'est jamais disposé par ce widget.
- **Super-racine opt-in** — la racine virtuelle multi-forêt (`graphite`)
  n'est jamais affichée par défaut ; `showSuperRoot` la rend visible et
  étiquetée sans introduire de second mécanisme, et n'a aucun effet à une
  seule racine.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_mindmap.md`](../../docs/site/paquets/zcrud_mindmap.md).
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_markdown` — le codec et les widgets rich-text branchés en opt-in.
- `zcrud_core` — le cœur dont ce paquet réutilise `ZEntity`/`ZExtensible`/`ZSyncMeta`.

## Licence {#licence}

MIT — voir la racine du dépôt.
