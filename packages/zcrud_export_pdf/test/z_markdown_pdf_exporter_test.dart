/// Export markdown : les adresses ne sont pas résolues, le LaTeX est optionnel.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

void main() {
  test('le module ne résout aucune adresse', () {
    final String src = File(
      'lib/src/data/z_markdown_pdf_exporter.dart',
    ).readAsStringSync();
    for (final String banned in <String>[
      'HttpClient',
      'NetworkImage',
      'dart:io',
      'package:http',
      'InternetAddress',
    ]) {
      expect(src.contains(banned), isFalse, reason: banned);
    }
  });

  test(
    'un lien est réduit à son libellé et latexEnabled ferme le rasteriseur',
    () async {
      final _Raster raster = _Raster();
      final bytes = await buildMarkdownPdfBytes(
        'voir [code](https://evil.example/a) et \$x^2\$',
        options: const ZPdfExportOptions(latexEnabled: false),
        latex: raster,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(raster.calls, isEmpty);
      expect(String.fromCharCodes(bytes).contains('evil.example'), isFalse);

      await buildMarkdownPdfBytes(
        r'formule $x^2$ fin',
        options: const ZPdfExportOptions(latexEnabled: true),
        latex: raster,
      );
      expect(raster.calls, <String>['x^2']);
    },
  );
}

class _Raster implements ZLatexRasterizer {
  final List<String> calls = <String>[];

  @override
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth}) async {
    calls.add(latex);
    return null;
  }
}
