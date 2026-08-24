---
title: zcrud_markdown
description: Édition et lecture Markdown riche pour zcrud — éditeur Quill isolé et ZCodec pluggable (Delta/Markdown/HTML).
---

# zcrud_markdown

## Rôle

`zcrud_markdown` porte la seule arête vers `flutter_quill` du graphe de
dépendances zcrud. L'éditeur (`ZMarkdownField`) et le lecteur
(`ZMarkdownReader`) travaillent toujours en **Delta interne** et n'exposent
sur leur tranche de formulaire qu'une valeur neutre (`List<Map<String,
dynamic>>`) — jamais un type Quill. Le format réellement **persisté** (Delta
JSON, Markdown, HTML) est une décision applicative, prise via un `ZCodec`
pluggable appliqué à la couture de sérialisation, hors du chemin chaud de
frappe. Le paquet fournit aussi des embeds riches opt-in (LaTeX, tableau,
image/vidéo, filet horizontal), un habillage de champ (chrome carte, plein
écran) et des presets de toolbar granulaires.

## Quand l'utiliser

- Pour un champ de formulaire ou une vue de lecture **rich-text** (notes,
  descriptions, contenu structuré) dont le format persisté doit rester
  interopérable (Markdown ou HTML).
- Pour composer une expérience d'édition riche — formules mathématiques,
  tableaux, médias — sans réimplémenter un moteur d'édition.
- Comme dépendance d'un domaine applicatif (voir `zcrud_note`) qui veut
  brancher son contenu typé directement sur l'éditeur, sans conversion.

## Quand ne pas l'utiliser

- Pour un champ texte simple : `EditionFieldType.text` du cœur suffit, sans
  tirer Quill.
- Pour une édition HTML **WYSIWYG** native (WebView) : c'est le rôle de
  `zcrud_html`, une voie exclusive de celle-ci — les deux paquets ne
  s'utilisent jamais ensemble sur le même champ.

## Deux règles du rendu de lecture {#rendu-lecture}

- **Une cellule de tableau est nue.** Une cellule riche (gras, lien,
  formule) est rendue par un lecteur imbriqué **sans cadre ni padding
  propres** : le tableau dessine déjà sa grille, et une cellule riche reste
  visuellement identique à une cellule en texte pur — jamais deux bordures
  concentriques dans le même tableau.
- **Une formule LaTeX bloc trop large défile.** Le rendu de lecture d'un
  bloc LaTeX défile horizontalement au lieu de tronquer la fin de la
  formule ; l'alignement, les marges et `blockScaleFactor` restent ce
  qu'ils étaient — réduire l'échelle n'est pas nécessaire pour faire tenir
  une formule.

Tout le reste du rendu est inchangé : ces deux comportements sont ceux du
lecteur, aucun paramètre d'hôte n'est requis.

## Types clés

| Type | Rôle |
|---|---|
| `ZMarkdownField` / `ZMarkdownReader` | Champ d'édition et lecteur rich-text, au controller Quill isolé (invariant [AD-2](../concepts/invariants.md#ad-2)). |
| `ZCodec` / `ZDeltaCodec` / `ZMarkdownCodec` / `ZHtmlCodec` | Abstraction pluggable de (dé)sérialisation et ses trois implémentations prêtes à l'emploi (invariant [AD-7](../concepts/invariants.md#ad-7)). |
| `ZMarkdownEmbedBridge` / `ZMarkdownBridges` | Déclaration d'une syntaxe Markdown inline ↔ embed Delta (LaTeX prêt à l'emploi). |
| `ZRichTextToolbarConfig` / `ZRichTextStyleSet` | Configuration granulaire de la toolbar et jeu de styles injectable par champ. |
| `registerZMarkdownFields` / `registerZHtmlFields` | Enrôlement des `kind` du champ dans le `ZWidgetRegistry` du cœur. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_markdown/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_html` — voie d'édition HTML WYSIWYG alternative, exclusive de ce paquet.
- `zcrud_note` — consommateur type de ce paquet pour un corps de note.
