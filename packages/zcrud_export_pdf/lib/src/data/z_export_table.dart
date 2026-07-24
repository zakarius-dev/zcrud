/// Projection **neutre** (pur-Dart, headless) d'une `ZListRenderRequest` en une
/// table de chaînes prête pour l'export, indépendante de tout backend.
///
/// origine: E11a-3 (FR-24/SM-5/AD-1/AD-8/AD-10). C'est le POINT UNIQUE où le
/// contrat neutre de liste du cœur (`ZListColumn`/`ZListRow`) est aplati en
/// en-têtes + cellules texte. Les backends Excel/PDF (Syncfusion, confinés dans
/// `z_excel_exporter.dart`/`z_pdf_exporter.dart`) ne voient QUE cette table de
/// `String` — AUCUN type `zcrud_core` ni Syncfusion ne les traverse, et la
/// logique de formatage n'est PAS dupliquée : elle vient du formateur PUR du
/// cœur `ZListColumn.format` (parité écran/fichier garantie, SM-5).
///
/// **Défensif (AD-10)** : `columns`/`rows` vides → table vide mais valide ;
/// clé de cellule absente → `col.format(null)` → cellule `''` ; le formateur du
/// cœur « ne lève jamais ». Aucune exception ne remonte d'ici.
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Table d'export **neutre et immuable** : une ligne d'[headers] + N lignes de
/// cellules déjà formatées en `String`. Chaque sous-liste de [rows] a la même
/// longueur que [headers] (une cellule par colonne, dans l'ordre `order`).
///
/// Ne porte AUCUN type Syncfusion ni `zcrud_core` : c'est le contrat interne
/// partagé par les backends Excel/PDF, et un résultat neutre exposable.
class ZExportTable {
  /// Construit une table à partir des [headers] et [rows] déjà projetés.
  const ZExportTable({required this.headers, required this.rows});

  /// Projette une [ZListRenderRequest] en table de chaînes.
  ///
  /// - En-tête de colonne = `resolveHeader(col.header)` (défaut identité :
  ///   `ZListColumn.header` est une **clé l10n non résolue** ; l'app peut la
  ///   résoudre sans `BuildContext`, export headless — AD-13/AD-15).
  /// - Cellule = `col.format(row.cells[col.name])` : réutilise le formateur PUR
  ///   du cœur (choix résolu, join `', '`, ISO date…), identique à l'écran
  ///   (SM-5), défensif (AD-10 : clé absente/valeur null → `''`).
  factory ZExportTable.fromRequest(
    ZListRenderRequest request, {
    String Function(String headerKey)? resolveHeader,
  }) {
    final resolve = resolveHeader ?? _identity;
    final columns = request.columns;
    final headers = <String>[
      for (final col in columns) resolve(col.header),
    ];
    final rows = <List<String>>[
      for (final row in request.rows)
        <String>[
          for (final col in columns) col.format(row.cells[col.name]),
        ],
    ];
    return ZExportTable(headers: headers, rows: rows);
  }

  /// En-têtes de colonnes (résolus), dans l'ordre `order`. Vide si aucune colonne.
  final List<String> headers;

  /// Lignes de cellules déjà formatées ; chaque sous-liste a `headers.length`
  /// éléments. Vide si aucune ligne.
  final List<List<String>> rows;

  /// Nombre de colonnes (= `headers.length`).
  int get columnCount => headers.length;

  /// Nombre de lignes de données (hors en-tête).
  int get rowCount => rows.length;

  static String _identity(String headerKey) => headerKey;
}
