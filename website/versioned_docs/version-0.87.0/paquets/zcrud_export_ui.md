---
title: zcrud_export_ui
description: Destinations d'export plateforme pour zcrud — rastérisation LaTeX, aperçu, impression et partage de PDF.
---

# zcrud_export_ui

## Rôle

`zcrud_export_ui` porte les maillons **plateforme** de l'export que
`zcrud_export` — package pur — ne peut pas porter : la rastérisation
concrète d'une formule LaTeX en image (`flutter_math_fork`) et
l'aperçu/impression/partage de bytes PDF déjà rendus (`printing`). C'est un
satellite feuille : aucun paquet zcrud n'en dépend.

## Quand l'utiliser

- Pour rendre une formule LaTeX en image PNG, via l'implémentation concrète
  du port `ZLatexRasterizer`.
- Pour prévisualiser, imprimer ou partager un document PDF déjà produit par
  `zcrud_export`/`zcrud_export_pdf`.

## Quand ne pas l'utiliser

- Pour produire les bytes PDF eux-mêmes : c'est le rôle de
  `zcrud_export`/`zcrud_export_pdf`, ce paquet ne fait que les consommer.
- Si l'application n'a besoin d'aucune formule LaTeX ni d'aucun
  aperçu/impression/partage natif.

## Types clés

| Type | Rôle |
|---|---|
| `ZFlutterMathLatexRasterizer` | Implémentation concrète du port `ZLatexRasterizer`, PNG hors écran. |
| `ZPdfShareService` | Partage et impression système de bytes PDF. |
| `ZPdfPreview` | Widget d'aperçu PDF, actions imprimer/partager intégrées. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_export_ui/README.md) — installation, démarrage rapide, API complète.
- [zcrud_export](zcrud_export.md) — la façade d'export neutre consommée ici.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
