---
title: zcrud_export_pdf
description: Export PDF neutre pour zcrud — gabarits flashcards, tables, assemblage d'images, sans dépendance tableur.
---

# zcrud_export_pdf

## Rôle

`zcrud_export_pdf` isole tout ce qui produit un PDF depuis `zcrud_export`,
pour qu'un hôte n'exportant que du PDF n'ait pas à tirer la dépendance
tableur (`syncfusion_flutter_xlsio`). Il fournit l'export tabulaire
(`buildPdfBytes`), le gabarit flashcards à composition inline texte + LaTeX
(`ZFlashcardPdfTemplate`), l'assemblage d'images (`ZPdfCreationService`) et
la sauvegarde cross-plateforme (`ZFileSaver`).

## Quand l'utiliser

- Pour tout export PDF (tabulaire, flashcards, assemblage d'images) sans
  tirer de dépendance tableur.
- Pour un document flashcards imprimable avec formules LaTeX, réponses
  masquables et prise en charge d'écritures non latines via une chaîne de
  polices.
- Pour un en-tête riche (logo, hiérarchie organisationnelle, sous-titre) sur
  un document tabulaire, de façon rétrocompatible.

## Quand ne pas l'utiliser

- Si l'application a aussi besoin d'Excel : dépendre de `zcrud_export`, qui
  réexporte ce paquet intégralement et n'ajoute que le backend tableur.

## Types clés

| Type | Rôle |
|---|---|
| `buildPdfBytes` / `ZExportTable` | Export tabulaire neutre. |
| `ZPdfExportOptions` / `ZPdfHeaderSpec` | Options de mise en page, en-tête riche opt-in. |
| `ZFlashcardPdfTemplate` | Gabarit PDF flashcards, composition inline texte + LaTeX. |
| `ZLatexRasterizer` / `ZPdfFontProvider` | Ports purs de rastérisation LaTeX et de fourniture de police. |
| `ZFileSaver` | Sauvegarde cross-plateforme des bytes exportés. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_export_pdf/README.md) — installation, démarrage rapide, API complète.
- [zcrud_export](zcrud_export.md) — façade combinée Excel + PDF.
- [zcrud_export_ui](zcrud_export_ui.md) — implémentation concrète du rasteriseur LaTeX.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
