/// Support de test PARTAGÉ pour le gabarit PDF flashcards (su-11).
///
/// - [extractPdfText] / [pdfPageCount] : décodent les BYTES rendus (Syncfusion en
///   dev_dependency de TEST uniquement — jamais dans `lib/`, cf. isolation gate).
/// - [FakeLatexRasterizer] : impl PURE en test du port [ZLatexRasterizer] (rend
///   un PNG connu 1×1 pour toute source non vide) → prouve la composition inline
///   SANS plateforme ni `flutter_math_fork`.
/// - [NullLatexRasterizer] : rend toujours `null` → prouve le repli texte (AC9).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// PNG **1×1** valide et décodable (rouge opaque) — bitmap connu pour les tests
/// de composition inline (aucun rendu réel de formule requis côté `zcrud_export`).
final Uint8List kOnePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Extrait le texte de [pdfBytes] (toutes pages). Preuve que le texte non-LaTeX
/// reste EXTRACTIBLE (dessiné en texte, pas rasterisé) — AC2/AC5.
String extractPdfText(Uint8List pdfBytes) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  try {
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

/// Nombre de pages de [pdfBytes] (preuve de pagination AC9 / densité inline AC5).
int pdfPageCount(Uint8List pdfBytes) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

/// Référence NAÏVE « une image par page » (le comportement AVANT AC5 : un rendu
/// LaTeX = une page image). Construit ici en test pour donner un point de
/// comparaison HONNÊTE à la densité inline (une image → une page).
Uint8List buildNaiveOneImagePerPagePdf(List<Uint8List> images) {
  final document = PdfDocument();
  try {
    for (final bytes in images) {
      final page = document.pages.add();
      final bmp = PdfBitmap(bytes);
      final size = page.getClientSize();
      page.graphics.drawImage(bmp, Rect.fromLTWH(0, 0, size.width, size.height));
    }
    if (document.pages.count == 0) document.pages.add();
    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}

/// Fake rasteriseur PUR : rend [kOnePixelPng] pour toute source non vide, `null`
/// sinon. Permet de tester la composition inline (bitmap DANS le flux) sans
/// plateforme ni `flutter_math_fork`.
class FakeLatexRasterizer implements ZLatexRasterizer {
  /// Compte les appels (utile pour prouver que le port EST sollicité).
  int calls = 0;

  @override
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth}) async {
    calls++;
    if (latex.isEmpty) return null;
    return kOnePixelPng;
  }
}

/// Rasteriseur qui échoue TOUJOURS (`null`) — prouve le repli texte brut (AC9).
class NullLatexRasterizer implements ZLatexRasterizer {
  @override
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth}) async =>
      null;
}

/// Rasteriseur qui LÈVE toujours — prouve que le gabarit absorbe l'exception du
/// port et retombe sur le texte (AD-10, jamais de throw du parent).
class ThrowingLatexRasterizer implements ZLatexRasterizer {
  @override
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth}) async =>
      throw StateError('rasteriseur défaillant (témoin AD-10)');
}
