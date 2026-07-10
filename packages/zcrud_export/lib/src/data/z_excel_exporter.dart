/// Backend Excel du service d'export — **SEULE arête `syncfusion_flutter_xlsio`**
/// du graphe zcrud (E11a-3, AD-8/SM-5).
///
/// origine: E11a-3. L'import Syncfusion xlsio est **confiné à ce fichier** : il
/// n'est JAMAIS réexporté par le barrel `zcrud_export.dart`, et aucun type
/// `Workbook`/`Worksheet`/`Range` n'apparaît dans une signature publique. La
/// fonction [buildExcelBytes] prend une [ZExportTable] **neutre** (chaînes) et
/// rend des **bytes neutres** (`Uint8List`) : la fuite de type est structurellement
/// impossible (AD-1 signature). Un consommateur qui n'importe pas `zcrud_export`
/// ne tire donc AUCUNE dépendance Excel (SM-5).
///
/// **Aucune clé/licence Syncfusion committée** : `SyncfusionLicense.registerLicense`
/// est une config plateforme de l'app hôte, jamais du package (AD-12).
///
/// **Anti-fuite de cycle de vie (learning E5)** : le `Workbook` est `dispose()`
/// en `finally`, y compris sur le chemin d'export vide ou en cas d'exception —
/// aucune ressource native non libérée (AC10).
library;

import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart';

import 'z_export_table.dart';

/// Construit un classeur `.xlsx` à partir de la [table] neutre et renvoie ses
/// **bytes** (`Uint8List`). Ligne 1 = en-têtes ; lignes suivantes = cellules.
///
/// Défensif (AD-10) : [table] sans colonne → classeur avec une feuille **vide**
/// mais valide ; [table] sans ligne → en-têtes seuls ; cellule `''` → cellule
/// vide. Ne lève pas pour une table vide.
Uint8List buildExcelBytes(ZExportTable table) {
  final workbook = Workbook();
  try {
    final sheet = workbook.worksheets[0];

    // Ligne 1 : en-têtes (indices xlsio 1-based).
    for (var c = 0; c < table.headers.length; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(table.headers[c]);
    }

    // Lignes de données à partir de la ligne 2.
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      for (var c = 0; c < row.length; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(row[c]);
      }
    }

    return Uint8List.fromList(workbook.saveAsStream());
  } finally {
    workbook.dispose();
  }
}
