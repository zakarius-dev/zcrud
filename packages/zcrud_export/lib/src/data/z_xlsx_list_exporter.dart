/// Exporteur de liste au format **Excel (`.xlsx`)**, branché sur le port
/// `ZListExporter` du cœur.
///
/// Réutilise la façade d'export déjà offerte par ce paquet ([ZExporter]) : la
/// production du classeur n'est pas réécrite, seul le contrat du port lui est
/// donné.
///
/// **Isolation (invariants AD-1/AD-8)** : le moteur tableur reste confiné aux
/// impls concrètes de ce paquet ; cette classe n'expose que des types neutres.
library;

import 'dart:typed_data';

// `Right`/`ZResult` viennent du barrel du cœur, qui ré-exporte les
// constructeurs de `Either`.
import 'package:zcrud_core/zcrud_core.dart';

import 'z_exporter.dart';

/// Exporteur Excel d'une liste — immuable et `const`-constructible.
///
/// ```dart
/// ZCrudScreen<Consignataire>(
///   title: 'Consignataires',
///   source: source,
///   export: ZExportPolicy(
///     exporters: const <ZListExporter>[ZXlsxListExporter()],
///     onExported: (context, file) => enregistrer(file),
///   ),
/// );
/// ```
///
/// **Ce qui est écrit** : une ligne d'en-têtes, puis une ligne par ligne
/// affichée, dans l'ordre de l'écran, avec les valeurs **formatées**. Les
/// colonnes techniques (numéro d'ordre, cases de sélection, boutons d'action)
/// n'y figurent pas : ce ne sont pas des colonnes de données.
class ZXlsxListExporter implements ZListExporter {
  /// Construit l'exporteur.
  const ZXlsxListExporter();

  @override
  String get id => 'xlsx';

  @override
  String get labelKey => 'Excel';

  @override
  String get fileExtension => 'xlsx';

  @override
  String get mimeType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async =>
      Right<ZFailure, Uint8List>(
        const ZExporter().toExcelBytes(request, resolveHeader: resolveHeader),
      );
}
