/// Export PDF d'un texte de notebook.
///
/// Le socle ne produit pas les bytes : un rendu PDF tire un moteur, et
/// l'invariant AD-1 interdit de l'imposer à tout consommateur du chat.
/// L'écran n'affiche le geste d'export que lorsque ce port est fourni.
/// L'implémentation de référence vit dans `zcrud_export_pdf`
/// (`buildMarkdownPdfBytes`) ; l'hôte l'adapte à ce port. Elle ne doit
/// jamais résoudre une URL du document (fichier local ou ressource
/// distante) : un lien est réduit à son libellé.
library;

import 'dart:typed_data';

import 'package:zcrud_core/domain.dart';

/// Produit les bytes PDF d'un markdown.
abstract interface class ZChatExportPort {
  /// Exporte [markdown]. [title] est le titre optionnel du document.
  ///
  /// Un échec est un [ZFailure], jamais une exception vers l'écran.
  Future<ZResult<Uint8List>> exportPdf({
    required String markdown,
    String? title,
  });
}
