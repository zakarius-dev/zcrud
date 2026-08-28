/// Contrat pur de reconnaissance optique du texte d'un document.
library;

import 'package:zcrud_core/domain.dart';

import 'z_document_text_extraction_port.dart';

/// Requête d'OCR d'un document.
///
/// Elle partage exactement le contrat de source et de ciblage des pages avec
/// [ZDocumentTextRequest].
typedef ZDocumentOcrRequest = ZDocumentTextRequest;

/// Port neutre d'OCR fourni par l'application hôte.
abstract interface class ZDocumentOcrPort {
  /// `true` si l'implémentation peut reconnaître du texte maintenant.
  bool get isAvailable;

  /// Reconnaît le texte décrit par [request].
  ///
  /// Un échec est rendu comme `Left(ZFailure)` ; l'implémentation ne doit pas
  /// utiliser une exception comme résultat métier.
  Future<ZResult<ZDocumentText>> recognize(ZDocumentOcrRequest request);
}

/// OCR inerte utilisé quand aucun moteur n'est configuré.
class ZInertDocumentOcrPort implements ZDocumentOcrPort {
  /// Construit le port inerte.
  const ZInertDocumentOcrPort();

  @override
  bool get isAvailable => false;

  @override
  Future<ZResult<ZDocumentText>> recognize(ZDocumentOcrRequest request) async =>
      const Left<ZFailure, ZDocumentText>(
        ZUnsupportedOperationFailure(
          'document OCR is not configured',
          operation: 'recognize',
        ),
      );
}
