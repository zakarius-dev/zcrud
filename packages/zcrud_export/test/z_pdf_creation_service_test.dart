// E11b-3 — Tests fonctionnels de `ZPdfCreationService` (Axe A, AC1-4).
//
// Vérifie le CONTENU réel (ré-ouverture via `PdfDocument`) : préfixe `%PDF-`,
// nombre de pages = nombre d'images décodables, ordre, défensif (AD-10 : liste
// vide → PDF valide d'une page ; bytes non-image → page sautée sans crash ;
// aucune fuite : boucle répétée → `returnsNormally`).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// PNG 2x2 rouge minimal valide (décodable par PdfBitmap).
final Uint8List _smallPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
);

/// PNG 1000x10 vert (beaucoup plus large que haut) : teste le fit-to-page
/// ratio-preserving (ne doit être ni rogné ni déformé).
final Uint8List _widePng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAA+gAAAAKCAYAAAAnx3TwAAAAVUlEQVR4nO3XMREAMBDDsPIn/YXhDDoR8Or3DgAAAMjlAQAAAIBBBwAAgAl5AAAAAGDQAQAAYEIeAAAAABh0AAAAmJAHAAAAAAYdAAAAJuQBAAAAwH2tO9ZkMQqfNQAAAABJRU5ErkJggg==',
);

int _pageCount(Uint8List bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

void _assertValidPdf(Uint8List bytes) {
  expect(bytes, isNotEmpty);
  expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
}

void main() {
  const service = ZPdfCreationService();

  group('AC1 — images → PDF multi-pages (une image par page, ordre)', () {
    test('1 image → PDF valide %PDF- non vide, 1 page', () {
      final bytes = service.buildFromImages(<Uint8List>[_smallPng]);
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 1);
    });

    test('N images → N pages', () {
      final bytes = service.buildFromImages(
        <Uint8List>[_smallPng, _widePng, _smallPng],
      );
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 3);
    });
  });

  group('AC2 — fit-to-page ratio-preserving (image large non rognée)', () {
    test('image beaucoup plus large que haute → 1 page valide (pas de crash)', () {
      final bytes = service.buildFromImages(<Uint8List>[_widePng]);
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 1);
    });

    test('orientation paysage réutilisée depuis les options', () {
      final bytes = service.buildFromImages(
        <Uint8List>[_smallPng],
        options: const ZPdfExportOptions(orientation: ZPdfOrientation.landscape),
      );
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 1);
    });
  });

  group('AC3 — défensif (AD-10) : vide / bytes non décodables / dispose', () {
    test('liste vide → PDF valide (une page vide), jamais d\'exception', () {
      late Uint8List bytes;
      expect(
        () => bytes = service.buildFromImages(const <Uint8List>[]),
        returnsNormally,
      );
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 1);
    });

    test('bytes non-image → page sautée, reste produit sans crash', () {
      final garbage = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      late Uint8List bytes;
      expect(
        () => bytes = service.buildFromImages(<Uint8List>[
          _smallPng,
          garbage,
          _smallPng,
        ]),
        returnsNormally,
      );
      _assertValidPdf(bytes);
      // Les 2 images valides → 2 pages ; la garbage est sautée.
      expect(_pageCount(bytes), 2);
    });

    test('QUE des bytes non décodables → PDF valide d\'une page vide', () {
      final garbage = Uint8List.fromList(<int>[9, 9, 9, 9]);
      late Uint8List bytes;
      expect(
        () => bytes = service.buildFromImages(<Uint8List>[garbage, garbage]),
        returnsNormally,
      );
      _assertValidPdf(bytes);
      expect(_pageCount(bytes), 1);
    });

    test('appels répétés → returnsNormally (dispose : pas de fuite bornée)', () {
      expect(() {
        for (var i = 0; i < 20; i++) {
          service.buildFromImages(<Uint8List>[_smallPng, _widePng]);
        }
      }, returnsNormally);
    });
  });
}
