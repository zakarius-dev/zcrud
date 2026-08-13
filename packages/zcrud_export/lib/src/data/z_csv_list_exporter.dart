/// Exporteur de liste au format **CSV**, branché sur le port `ZListExporter`
/// du cœur.
///
/// Écrit en Dart pur : aucune bibliothèque tierce n'intervient, et le fichier
/// produit s'ouvre dans n'importe quel tableur. C'est le format à préférer
/// quand la donnée compte plus que la mise en forme.
library;

import 'dart:convert';
import 'dart:typed_data';

// `Right`/`ZResult` viennent du barrel du cœur, qui ré-exporte les
// constructeurs de `Either`.
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart' show ZExportTable;

/// Exporteur CSV d'une liste — immuable et `const`-constructible.
///
/// ```dart
/// ZCrudScreen<Consignataire>(
///   title: 'Consignataires',
///   source: source,
///   export: ZExportPolicy(
///     exporters: const <ZListExporter>[ZCsvListExporter()],
///     onExported: (context, file) => enregistrer(file),
///   ),
/// );
/// ```
///
/// **Ce qui est écrit** : une ligne d'en-têtes, puis une ligne par ligne
/// affichée, dans l'ordre de l'écran, avec les valeurs **formatées** — celles
/// que l'utilisateur lit, devise portée par la ligne comprise. Les colonnes
/// techniques (numéro d'ordre, cases de sélection, boutons d'action) n'y
/// figurent pas : ce ne sont pas des colonnes de données.
///
/// **Conventions du fichier** : séparateur [delimiter] (`,` par défaut), fin de
/// ligne `\r\n` (la seule que tous les tableurs acceptent), guillemets doubles
/// autour de toute valeur contenant un séparateur, un guillemet, un retour à la
/// ligne ou une espace de bord — les guillemets internes étant doublés, comme
/// le veut le format. Un [byteOrderMark] (posé par défaut) fait lire l'UTF-8
/// aux tableurs qui, sans lui, dégradent les accents.
class ZCsvListExporter implements ZListExporter {
  /// Construit l'exporteur.
  const ZCsvListExporter({
    this.delimiter = ',',
    this.byteOrderMark = true,
  });

  /// Séparateur de champs. `','` par défaut ; `';'` convient mieux aux tableurs
  /// configurés en locale francophone, qui lisent la virgule comme un séparateur
  /// décimal.
  final String delimiter;

  /// Écrit la marque d'ordre des octets UTF-8 en tête du fichier (défaut
  /// `true`), sans laquelle plusieurs tableurs affichent les accents en
  /// caractères de remplacement.
  final bool byteOrderMark;

  @override
  String get id => 'csv';

  @override
  String get labelKey => 'CSV';

  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async {
    final table = ZExportTable.fromRequest(request, resolveHeader: resolveHeader);
    final buffer = StringBuffer();
    if (byteOrderMark) buffer.write('﻿');
    _writeLine(buffer, table.headers);
    for (final row in table.rows) {
      _writeLine(buffer, row);
    }
    return Right<ZFailure, Uint8List>(
      Uint8List.fromList(utf8.encode(buffer.toString())),
    );
  }

  void _writeLine(StringBuffer buffer, List<String> cells) {
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) buffer.write(delimiter);
      buffer.write(_escape(cells[i]));
    }
    buffer.write('\r\n');
  }

  String _escape(String value) {
    final needsQuotes = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.trim().length != value.length;
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
