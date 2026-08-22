---
title: zcrud_export
description: Export tabulaire neutre (Excel/PDF) pour zcrud, backends Syncfusion confinés à l'implémentation.
---

# zcrud_export

## Rôle

`zcrud_export` transforme une requête de rendu de liste (`zcrud_core`) en
bytes Excel (`.xlsx`) via `ZExporter`, avec la même façade pour le PDF
(réexporté depuis `zcrud_export_pdf`). Les backends Syncfusion sont confinés
à l'implémentation : la signature publique ne manipule que des types neutres
(`ZListRenderRequest` en entrée, `Uint8List` en sortie).

## Quand l'utiliser

- Pour exporter un rendu de liste en `.xlsx` ou en PDF depuis une seule
  dépendance, avec la même valeur de cellule que l'écran (`ZListColumn.format`).
- Comme point d'entrée commun quand l'application a besoin des deux formats
  (Excel **et** PDF).

## Quand ne pas l'utiliser

- Si seul le PDF est requis : dépendre directement de `zcrud_export_pdf`
  évite la dépendance tableur (`syncfusion_flutter_xlsio`).
- Pour choisir la destination finale d'un fichier exporté (sélecteur système,
  partage) : c'est le rôle de `zcrud_export_ui`.

## Types clés

| Type | Rôle |
|---|---|
| `ZExporter` | Façade d'export neutre et immuable — `toExcelBytes` / `toPdfBytes`. |
| `ZCsvListExporter` / `ZXlsxListExporter` | Implémentations du port `ZListExporter` du cœur : elles se déclarent sur `ZExportPolicy.exporters` d'un [`ZCrudScreen`](zcrud_screen.md) pour offrir l'export du listing. `ZPdfListExporter` vient de `zcrud_export_pdf`, réexporté ici. |
| `ZExportApi` | Marqueur de version de l'API publique du paquet. |
| `ZPdfCreationService` / `ZFileSaver` / `ZPdfExportOptions` | Réexportés depuis `zcrud_export_pdf` — assemblage PDF, sauvegarde, mise en page. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_export/README.md) — installation, démarrage rapide, API complète.
- [zcrud_export_pdf](zcrud_export_pdf.md) — le contenu PDF neutre réexporté ici.
- [zcrud_export_ui](zcrud_export_ui.md) — destinations de sauvegarde par plateforme.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
