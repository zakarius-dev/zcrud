/// Service d'export tabulaire **neutre** (headless) : `ZListRenderRequest` du
/// cœur → bytes Excel (`.xlsx`) / PDF.
///
/// `ZExporter` est la façade **100 % neutre** de l'export : elle consomme le
/// contrat de liste du cœur (colonnes dérivées + lignes brutes) et rend des
/// **bytes** (`Uint8List`). Les backends Syncfusion (Excel/PDF) sont **confinés**
/// à `z_excel_exporter.dart`/`z_pdf_exporter.dart` : AUCUN type `Workbook`/
/// `PdfDocument` n'apparaît dans cette API ni dans le barrel (invariant AD-1).
///
/// **Parité écran/fichier** : la valeur d'une cellule est
/// `col.format(row.cells[col.name])` — exactement le formateur PUR du cœur
/// (`ZListColumn.format`) utilisé par le rendu `SfDataGrid`. Une seule source de
/// vérité de formatage, zéro duplication.
///
/// **Défensif (invariant AD-10)** : `columns`/`rows` vides, clé de cellule
/// absente, valeur `null` → cellule/fichier vide mais valide, **jamais** de
/// crash.
///
/// **Licence Syncfusion — responsabilité de l'app hôte (invariant AD-12)** :
/// les libs `syncfusion_flutter_*` peuvent exiger un enregistrement de
/// licence via `SyncfusionLicense.registerLicense(...)`. Cet appel — et la
/// clé — appartiennent au **bootstrap de l'app hôte**, JAMAIS à ce package
/// (zéro secret committé). `ZExporter` n'enregistre aucune licence et ne
/// contient aucun contournement TLS.
library;

import 'dart:typed_data';

import 'package:zcrud_core/zcrud_core.dart';

import 'z_excel_exporter.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

/// Façade d'export neutre et immuable (`const`-constructible).
///
/// Injectable tel quel : `const ZExporter().toExcelBytes(request)`.
class ZExporter {
  /// Construit le service (sans état ; immuable).
  const ZExporter();

  /// Exporte la [request] en classeur Excel `.xlsx` et renvoie ses **bytes**.
  ///
  /// [resolveHeader] (défaut identité) résout la **clé l10n** `ZListColumn.header`
  /// sans `BuildContext` (export headless). En-tête ligne 1 ; cellule =
  /// `col.format(row.cells[col.name])`. Défensif AD-10.
  Uint8List toExcelBytes(
    ZListRenderRequest request, {
    String Function(String headerKey)? resolveHeader,
  }) {
    final table = ZExportTable.fromRequest(request, resolveHeader: resolveHeader);
    return buildExcelBytes(table);
  }

  /// Exporte la [request] en document PDF tabulaire et renvoie ses **bytes**
  /// (préfixe `%PDF-`).
  ///
  /// Même contrat neutre que [toExcelBytes] : en-tête + `rows.length` lignes,
  /// valeurs = `col.format(...)`, [resolveHeader] optionnel, défensif AD-10.
  ///
  /// [options] paramètre la mise en page — orientation, titre, en-tête
  /// répété — et corrige le rognage horizontal des tables larges.
  /// **Rétro-compatible** : un appel sans [options] conserve le comportement
  /// par défaut d'origine du service.
  Uint8List toPdfBytes(
    ZListRenderRequest request, {
    String Function(String headerKey)? resolveHeader,
    ZPdfExportOptions? options,
  }) {
    final table = ZExportTable.fromRequest(request, resolveHeader: resolveHeader);
    return buildPdfBytes(table, options: options);
  }
}
