/// Fichier exporté **neutre** : le triplet `{bytes, fileName, mimeType}` rendu
/// par `ZFlashcardPdfTemplate` (su-11, AC1).
///
/// origine: su-11 (FR-SU16). Type de transport **pur** (aucun type Syncfusion,
/// aucun `zcrud_core`, aucune plateforme) : les bytes sont le PDF déjà rendu,
/// prêts à être prévisualisés / imprimés / partagés par le satellite
/// `zcrud_export_ui` (`printing`) ou sauvegardés par [ZFileSaver]. Immuable.
library;

import 'dart:typed_data';

/// Un fichier produit par un export : ses **bytes**, un **nom** suggéré et son
/// **type MIME**. Neutre et immuable — aucune fuite de type de plateforme.
class ZExportedFile {
  /// Construit un fichier exporté immuable.
  const ZExportedFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Les bytes du fichier (pour un PDF : préfixe `%PDF-`).
  final Uint8List bytes;

  /// Nom de fichier suggéré (ex. `flashcards.pdf`).
  final String fileName;

  /// Type MIME (ex. `application/pdf`).
  final String mimeType;
}
