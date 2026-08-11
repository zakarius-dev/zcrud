/// Façade **neutre** `ZPdfCreationService` : images/scans → document PDF unique.
///
/// Source UNIQUE d'assemblage d'images en PDF, évitant qu'un tel service soit
/// dupliqué par chaque application hôte. Signature 100 % neutre :
/// `List<Uint8List>` (bytes d'images) → `Uint8List` (bytes PDF). AUCUN type
/// Syncfusion n'apparaît ici : la logique de rendu vit dans le backend confiné
/// `z_pdf_document_builder.dart`. Défensif (invariant AD-10) délégué au
/// backend.
library;

import 'dart:typed_data';

import 'z_pdf_document_builder.dart';
import 'z_pdf_export_options.dart';

/// Service d'assemblage d'images en PDF, **neutre et immuable** (`const`).
///
/// Injectable tel quel : `const ZPdfCreationService().buildFromImages(images)`.
class ZPdfCreationService {
  /// Construit le service (sans état ; immuable).
  const ZPdfCreationService();

  /// Assemble [images] (bytes ordonnés, une image par page) en un **unique**
  /// document PDF multi-pages et renvoie ses **bytes** (`Uint8List`, `%PDF-`).
  ///
  /// Fit-to-page ratio-preserving centré ([options].orientation réutilisé si
  /// fourni). Défensif (AD-10) : liste vide → PDF valide d'une page ; élément non
  /// décodable → page sautée ; jamais d'exception propagée.
  Uint8List buildFromImages(
    List<Uint8List> images, {
    ZPdfExportOptions? options,
  }) =>
      buildImagesPdf(images, options: options);
}
