/// Backend PDF du service d'export — **SEULE arête `syncfusion_flutter_pdf`** du
/// graphe zcrud (E11a-3, AD-8/SM-5).
///
/// origine: E11a-3. L'import Syncfusion pdf est **confiné à ce fichier** : il
/// n'est JAMAIS réexporté par le barrel `zcrud_export.dart`, et aucun type
/// `PdfDocument`/`PdfGrid`/`PdfPage` n'apparaît dans une signature publique. La
/// fonction [buildPdfBytes] prend une [ZExportTable] **neutre** (chaînes) et rend
/// des **bytes neutres** (`Uint8List`) : la fuite de type est structurellement
/// impossible (AD-1 signature). Un consommateur qui n'importe pas `zcrud_export`
/// ne tire donc AUCUNE dépendance PDF (SM-5).
///
/// **Aucune clé/licence Syncfusion committée** ni `badCertificateCallback`
/// (AD-12). **Anti-fuite de cycle de vie (learning E5)** : le `PdfDocument` est
/// `dispose()` en `finally`, y compris sur le chemin d'export vide ou en cas
/// d'exception (AC10).
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'z_export_table.dart';

/// Construit un document PDF tabulaire à partir de la [table] neutre et renvoie
/// ses **bytes** (`Uint8List`, préfixe `%PDF-`). En-tête + `rows.length` lignes.
///
/// Défensif (AD-10) : [table] sans colonne → document valide d'**une page vide**
/// (aucune grille dégénérée) ; [table] sans ligne → grille avec en-têtes seuls ;
/// cellule `''` → cellule vide. Ne lève pas pour une table vide.
Uint8List buildPdfBytes(ZExportTable table) {
  final document = PdfDocument();
  try {
    final page = document.pages.add();

    // Sans colonne : une page vide suffit (PDF valide, pas de grille dégénérée).
    if (table.headers.isNotEmpty) {
      final grid = PdfGrid();
      grid.columns.add(count: table.headers.length);

      // Ligne d'en-tête.
      final header = grid.headers.add(1)[0];
      for (var c = 0; c < table.headers.length; c++) {
        header.cells[c].value = table.headers[c];
      }

      // Lignes de données.
      for (final rowValues in table.rows) {
        final row = grid.rows.add();
        for (var c = 0; c < rowValues.length; c++) {
          row.cells[c].value = rowValues[c];
        }
      }

      final size = page.getClientSize();
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }

    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}
