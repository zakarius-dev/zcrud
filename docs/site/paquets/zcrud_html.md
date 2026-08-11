---
title: zcrud_html
description: Champ HTML WYSIWYG pour zcrud — édition via WebView à controller isolé, lecture native, format persisté en String HTML.
---

# zcrud_html

## Rôle

`zcrud_html` est le satellite **HTML WYSIWYG** de zcrud : une 2ᵉ voie
rich-text, exclusive de celle de `zcrud_markdown`. L'édition passe par une
WebView (`html_editor_enhanced`) à controller isolé ; la lecture par un rendu
HTML natif (`flutter_html`). Le format persisté est directement une `String`
HTML — aucun intermédiaire Delta.

## Quand l'utiliser

- Quand le format persisté doit rester du HTML `String` sans conversion, par
  exemple pour interopérer avec un système existant qui attend du HTML.
- Quand l'édition WYSIWYG (rendu final visible pendant la frappe) est un
  besoin explicite.

## Quand ne pas l'utiliser

- Si un round-trip Markdown ou Delta suffit : `zcrud_markdown` offre un
  éditeur nativement accessible et un `ZCodec` pluggable, sans WebView.
- Si l'accessibilité fine de l'édition est prioritaire : la WebView de ce
  paquet reste hors du contrôle `Semantics` du socle côté édition (le rendu
  de lecture, lui, reste pleinement accessible).

## Types clés

| Type | Rôle |
|---|---|
| `ZHtmlEditorField` | Champ d'édition HTML WYSIWYG à controller WebView isolé (invariant [AD-2](../concepts/invariants.md#ad-2)). |
| `ZHtmlView` | Rendu de lecture HTML natif, défensif sur un contenu malformé. |
| `registerZHtmlFields` | Enregistre les `kind` `html`/`inlineHtml` dans un `ZWidgetRegistry` injecté. |

## Voir aussi

- [README du paquet](../../packages/zcrud_html/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_markdown` — voie d'édition Delta/Markdown alternative, exclusive de ce paquet.
