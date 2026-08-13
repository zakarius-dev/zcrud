/// Exporteur de liste au format **PDF**, branché sur le port `ZListExporter`
/// du cœur.
///
/// C'est la pièce qui rend l'export d'un écran déclaratif : l'application
/// déclare cet exporteur, l'écran offre l'entrée correspondante, et le fichier
/// est produit à partir de ce qui est affiché — sans que l'écran, lui, ne
/// connaisse ni PDF ni bibliothèque de rendu.
///
/// **Isolation (invariants AD-1/AD-8)** : le moteur PDF reste confiné aux impls
/// concrètes de ce paquet ; cette classe n'expose que des types neutres
/// (`ZListRenderRequest` en entrée, `Uint8List` en sortie).
library;

import 'dart:typed_data';

// `Right`/`ZFailure`/`ZResult` viennent du barrel du cœur, qui ré-exporte les
// constructeurs de `Either` : ce paquet n'a donc aucune dépendance directe à
// `dartz` à déclarer.
import 'package:zcrud_core/zcrud_core.dart';

import 'z_export_table.dart';
import 'z_pdf_export_options.dart';
import 'z_pdf_exporter.dart';

/// Exporteur PDF d'une liste — immuable et `const`-constructible.
///
/// ```dart
/// ZCrudScreen<Consignataire>(
///   title: 'Consignataires',
///   source: source,
///   export: ZExportPolicy(
///     exporters: const <ZListExporter>[ZPdfListExporter()],
///     onExported: (context, file) => partager(file),
///   ),
/// );
/// ```
///
/// Le titre de l'écran devient le titre du document, sauf si [options] en porte
/// déjà un : ce que l'appelant a écrit explicitement fait autorité.
///
/// **Ce qui est exporté** : les colonnes de la requête de rendu — donc celles
/// que l'écran affiche, dans leur ordre, avec leurs valeurs **formatées**. Les
/// colonnes techniques (numéro d'ordre, cases de sélection, boutons d'action)
/// n'en font pas partie : elles ne sont pas des colonnes de données.
class ZPdfListExporter implements ZListExporter {
  /// Construit l'exporteur, éventuellement paramétré par [options]
  /// (orientation, en-tête riche, répétition de la ligne d'en-tête).
  const ZPdfListExporter({this.options});

  /// Mise en page du document, ou `null` pour la mise en page par défaut.
  final ZPdfExportOptions? options;

  @override
  String get id => 'pdf';

  @override
  String get labelKey => 'PDF';

  @override
  String get fileExtension => 'pdf';

  @override
  String get mimeType => 'application/pdf';

  /// Mise en page réellement employée pour un écran intitulé [title].
  ///
  /// Le titre de l'écran ne sert qu'à **combler** : des [options] qui portent
  /// déjà un titre font autorité — ce que l'appelant a écrit explicitement
  /// l'emporte toujours sur ce qui est dérivé. Sans options déclarées, le titre
  /// de l'écran devient le titre du document.
  ZPdfExportOptions effectiveOptions(String? title) {
    final declared = options;
    if (declared == null) return ZPdfExportOptions(title: title);
    if (declared.title != null || title == null) return declared;
    return ZPdfExportOptions(
      orientation: declared.orientation,
      title: title,
      header: declared.header,
      repeatHeader: declared.repeatHeader,
      latexEnabled: declared.latexEnabled,
    );
  }

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async {
    final table = ZExportTable.fromRequest(request, resolveHeader: resolveHeader);
    return Right<ZFailure, Uint8List>(
      buildPdfBytes(table, options: effectiveOptions(title)),
    );
  }
}
