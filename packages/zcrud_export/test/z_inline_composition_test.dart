/// Preuve de **composition INLINE** texte + bitmap LaTeX (su-11, AC5).
///
/// AC5 exige d'aller AU-DELÀ de `buildImagesPdf` (une image par page) : une
/// formule s'insère DANS le flux du paragraphe. Prouvé par :
///  (a) un doc multi-cartes AVEC formules tient sur MOINS de pages qu'un rendu
///      une-image-par-formule (`buildImagesPdf`) ;
///  (b) le texte non-LaTeX reste EXTRACTIBLE (donc dessiné en texte, pas rasterisé) ;
///  (c) le port [ZLatexRasterizer] EST sollicité (les formules deviennent des
///      bitmaps, pas du texte) — sinon la preuve (a) serait vacante.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export/zcrud_export.dart';

import 'support/pdf_flashcard_support.dart';

void main() {
  // Corpus : 6 cartes, chacune une formule inline DANS l'énoncé + du texte.
  ZFlashcardPdfInput corpus() => const ZFlashcardPdfInput(
        title: 'Formules',
        cards: <ZFlashcardPdfCard>[
          ZFlashcardPdfCard(question: r'Aire du cercle TEXTEUNO $\pi r^2$ ici.'),
          ZFlashcardPdfCard(question: r'Pythagore TEXTEDOS $a^2+b^2=c^2$ suite.'),
          ZFlashcardPdfCard(question: r'Somme TEXTETRES $\sum_{i=1}^n i$ fin.'),
          ZFlashcardPdfCard(question: r'Racine TEXTEQUATRO $\sqrt{x}$ ok.'),
          ZFlashcardPdfCard(question: r'Fraction TEXTECINCO $\frac{a}{b}$ vois.'),
          ZFlashcardPdfCard(question: r'Intégrale TEXTESEIS $\int_0^1 x\,dx$ done.'),
        ],
      );

  test('(c) le port de rasterisation EST sollicité (formules → bitmaps)',
      () async {
    final raster = FakeLatexRasterizer();
    await ZFlashcardPdfTemplate(rasterizer: raster).build(corpus());
    // 6 formules DISTINCTES → 6 appels (dé-duplication par source).
    expect(raster.calls, 6,
        reason: 'chaque formule inline distincte doit passer par le port');
  });

  test('(a) inline tient sur MOINS de pages qu\'une-image-par-formule',
      () async {
    final res =
        await ZFlashcardPdfTemplate(rasterizer: FakeLatexRasterizer()).build(corpus());
    final inlinePages = pdfPageCount(res.bytes);

    // Référence "naïve" : une image par formule (une page par formule).
    final images = List.filled(6, kOnePixelPng);
    final naivePages = pdfPageCount(buildNaiveOneImagePerPagePdf(images));

    expect(naivePages, 6, reason: 'référence naïve = une image par page');
    expect(inlinePages, lessThan(naivePages),
        reason: 'la composition inline doit condenser 6 formules sur < 6 pages');
  });

  test('(b) le texte non-LaTeX reste EXTRACTIBLE (dessiné en texte)', () async {
    final res =
        await ZFlashcardPdfTemplate(rasterizer: FakeLatexRasterizer()).build(corpus());
    final text = extractPdfText(res.bytes);
    // Les fragments de texte encadrant les formules sont bien du TEXTE.
    for (final marker in <String>[
      'TEXTEUNO',
      'TEXTEDOS',
      'TEXTETRES',
      'TEXTEQUATRO',
      'TEXTECINCO',
      'TEXTESEIS',
    ]) {
      expect(text, contains(marker),
          reason: '$marker doit rester du texte extractible (pas rasterisé)');
    }
  });

  test('la source LaTeX rasterisée n\'apparaît PAS comme texte (c\'est un bitmap)',
      () async {
    final res =
        await ZFlashcardPdfTemplate(rasterizer: FakeLatexRasterizer()).build(corpus());
    final text = extractPdfText(res.bytes);
    // `a^2+b^2=c^2` a été rendu en IMAGE (bitmap fake) → pas de texte "b^2".
    expect(text, isNot(contains('a^2+b^2')),
        reason: 'une formule rasterisée ne doit pas fuir en texte');
  });
}
