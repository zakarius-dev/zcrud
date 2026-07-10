// E11b-3 — Tests de mise en page PDF anti-rognage (Axe C, AC9-10) + rétro-compat.
//
// Clôt LOW-1 d'E11a-3 (tables larges rognées) : avec beaucoup de colonnes, le
// texte extrait (`PdfTextExtractor`) DOIT contenir la DERNIÈRE colonne. Vérifie
// aussi : titre présent dans le texte, orientation paysage → PDF valide, et la
// RÉTRO-COMPAT (appel sans options == comportement E11a-3, bytes valides, contenu
// inchangé).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// Schéma à NOMBREUSES colonnes (déclenche le rognage historique).
List<ZFieldSpec> _wideSchema() => List<ZFieldSpec>.generate(
      16,
      (i) => ZFieldSpec(
        name: 'col$i',
        type: EditionFieldType.text,
        label: 'Colonne$i',
      ),
    );

List<ZListRow> _wideRows() => <ZListRow>[
      ZListRow(
        id: '1',
        cells: <String, Object?>{
          for (var i = 0; i < 16; i++) 'col$i': 'v$i',
        },
      ),
    ];

String _pdfText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

void _assertValidPdf(Uint8List bytes) {
  expect(bytes, isNotEmpty);
  expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
}

void main() {
  const exporter = ZExporter();

  group('AC10 — anti-rognage : la dernière colonne est rendue', () {
    test('table à 16 colonnes → texte extrait contient la dernière colonne', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      final bytes = exporter.toPdfBytes(request);
      _assertValidPdf(bytes);
      final text = _pdfText(bytes);
      // En-tête ET valeur de la dernière colonne présents (non rognés).
      expect(text, contains('Colonne15'),
          reason: 'en-tête de la dernière colonne rogné (LOW-1 non corrigé)');
      expect(text, contains('v15'),
          reason: 'valeur de la dernière colonne rognée');
    });

    test('orientation paysage → PDF valide, dernière colonne présente', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      final bytes = exporter.toPdfBytes(
        request,
        options: const ZPdfExportOptions(orientation: ZPdfOrientation.landscape),
      );
      _assertValidPdf(bytes);
      expect(_pdfText(bytes), contains('Colonne15'));
    });
  });

  group('AC9 — titre + options', () {
    test('titre présent dans le texte extrait', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      final bytes = exporter.toPdfBytes(
        request,
        options: const ZPdfExportOptions(title: 'Rapport Export ZCRUD'),
      );
      _assertValidPdf(bytes);
      expect(_pdfText(bytes), contains('Rapport Export ZCRUD'));
    });

    test('repeatHeader false → PDF valide (option honorée sans crash)', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      final bytes = exporter.toPdfBytes(
        request,
        options: const ZPdfExportOptions(repeatHeader: false),
      );
      _assertValidPdf(bytes);
    });

    test('ZPdfExportOptions : égalité de valeur (immuable const)', () {
      const a = ZPdfExportOptions(title: 'x');
      const b = ZPdfExportOptions(title: 'x');
      const c = ZPdfExportOptions(title: 'y');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(const ZPdfExportOptions().orientation, ZPdfOrientation.portrait);
      expect(const ZPdfExportOptions().repeatHeader, isTrue);
    });
  });

  group('AC9 — rétro-compat : appel sans options == E11a-3', () {
    test('sans options → bytes PDF valides, contenu (parité) inchangé', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      final bytes = exporter.toPdfBytes(request);
      _assertValidPdf(bytes);
      final text = _pdfText(bytes);
      expect(text, contains('Colonne0'));
      expect(text, contains('v0'));
    });

    test('options == null explicite équivaut à l\'absence d\'options', () {
      final request = ZListRenderRequest.fromSchema(_wideSchema(), _wideRows());
      expect(
        () => exporter.toPdfBytes(request, options: null),
        returnsNormally,
      );
    });
  });
}
