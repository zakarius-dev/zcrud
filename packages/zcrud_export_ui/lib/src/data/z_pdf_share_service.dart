/// Service de **partage / impression** de bytes PDF (su-11, AC6). Arête
/// `printing` **confinée** (avec `z_pdf_preview.dart`).
///
/// origine: su-11 (E-STUDY-UI, FR-SU16, AD-42). La destination des bytes (le PDF
/// déjà produit par `ZFlashcardPdfTemplate`, PUR) est une opération de
/// PLATEFORME : elle vit dans ce satellite, jamais dans `zcrud_export`.
///
/// 🔴 **API publique 100% `Uint8List`** : le type `PdfPageFormat` (de `printing`
/// / `pdf`) est **absorbé** en interne (`Printing.sharePdf` n'en a pas besoin ;
/// `layoutPdf` reçoit un format par défaut ici) et ne franchit JAMAIS ce package.
/// Aucun type `printing`/`pdf` n'apparaît en signature publique ni au barrel.
/// Gardé par `test/z_export_ui_confinement_test.dart`.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Partage et impression de documents PDF déjà rendus (bytes).
class ZPdfShareService {
  /// Construit le service.
  const ZPdfShareService();

  /// Ouvre la feuille de **partage** système pour [bytes] (PDF), sous le nom
  /// [fileName]. Renvoie `true` si l'utilisateur a effectivement partagé.
  Future<bool> share(
    Uint8List bytes, {
    String fileName = 'flashcards.pdf',
  }) {
    return Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  /// Lance le flux d'**impression** système pour [bytes] (PDF). [jobName] est le
  /// nom du travail d'impression affiché. Renvoie `true` si l'impression a été
  /// lancée.
  Future<bool> printDocument(
    Uint8List bytes, {
    String jobName = 'Flashcards',
  }) {
    // `PdfPageFormat` ABSORBÉ : `onLayout` renvoie les bytes déjà mis en page par
    // `ZFlashcardPdfTemplate` quel que soit le format demandé par la plateforme.
    return Printing.layoutPdf(onLayout: (_) => bytes, name: jobName);
  }
}
