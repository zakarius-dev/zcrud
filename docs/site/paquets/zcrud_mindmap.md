---
title: zcrud_mindmap
description: Cartes mentales pour zcrud — arbre immuable, moteur de mutation pur, vue graphite et éditeur outline.
---

# zcrud_mindmap

## Rôle

`zcrud_mindmap` porte les cartes mentales de zcrud : le modèle
`ZMindmap`/`ZMindmapNode` (forêt multi-racine titrée dans un dossier, arbre
récursif par nesting), le moteur de mutation pur `ZMindmapTreeOps`
(ajout/mise à jour/suppression/recherche/déplacement/indentation/
réordonnancement, avec partage structurel) et la présentation — une vue
`graphite` auto-agencée et une vue liste sémantique accessible, équivalentes,
plus un éditeur outline dont la sauvegarde applique réellement les
modifications. Le rich-text (Markdown/LaTeX) sur le contenu d'un nœud est
opt-in, via de fins adaptateurs vers `zcrud_markdown`.

## Quand l'utiliser

- Pour rendre et éditer une **carte mentale** dans une application Flutter —
  graphe visuel, vue liste accessible, ou les deux.
- Pour un **éditeur outline** dont chaque sauvegarde applique effectivement
  la forêt mutée, avec rebuild granulaire (invariant
  [AD-2](../concepts/invariants.md#ad-2)).
- Pour brancher du **contenu riche** (Markdown/LaTeX) sur un nœud, sans que
  les applications qui n'en ont pas besoin ne tirent Quill.

## Quand ne pas l'utiliser

- Pour un simple arbre de données sans aucun rendu : le modèle
  `ZMindmap`/`ZMindmapTreeOps` suffit alors seul, sans les widgets de
  présentation ni la dépendance `graphite`.
- Pour du rendu Markdown/LaTeX autonome, hors du contexte d'un nœud de carte
  mentale : utilisez `zcrud_markdown` directement.

## Types clés

| Type | Rôle |
|---|---|
| `ZMindmap` / `ZMindmapNode` | Carte mentale immuable et nœud récursif par nesting. |
| `ZMindmapTreeOps` | Moteur d'opérations d'arbre pur, seule voie de mutation. |
| `ZMindmapView` | Vue d'une forêt — graphe auto-agencé ou liste accessible, zoom, compact, plein écran. |
| `ZMindmapOutlineEditor` / `ZMindmapOutlineController` | Éditeur outline et sa source de vérité unique. |
| `ZMindmapMarkdownContent` / `ZMindmapMarkdownEditField` | Adaptateurs minces opt-in vers `zcrud_markdown`. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_mindmap/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
