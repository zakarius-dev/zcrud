/// Markdown → PDF, sans résolution d'URL.
///
/// Un lien ou une image markdown est réduit à son libellé visible. Aucune
/// adresse n'est ouverte, ni en HTTP, ni en fichier local : ce module ne
/// lit pas le réseau et n'ouvre pas de chemin fourni par le document.
///
/// Quand [ZPdfExportOptions.latexEnabled] est vrai et qu'un
/// [ZLatexRasterizer] est fourni, chaque formule entre `$` est rasterisée
/// localement. Un rendu `null` ou une erreur laisse la formule en texte.
/// `latexEnabled: false` n'appelle jamais le rasteriseur.
library;

import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/z_latex_rasterizer.dart';
import 'z_pdf_export_options.dart';

/// Produit les bytes PDF de [markdown].
///
/// Le document commence par `%PDF-`. Un markdown vide reste un PDF d'une
/// page. Ne lève pas pour une formule illisible.
Future<Uint8List> buildMarkdownPdfBytes(
  String markdown, {
  String? title,
  ZPdfExportOptions? options,
  ZLatexRasterizer? latex,
}) async {
  final ZPdfExportOptions opts = options ?? const ZPdfExportOptions();
  final PdfDocument document = PdfDocument();
  try {
    if (opts.orientation == ZPdfOrientation.landscape) {
      document.pageSettings.orientation = PdfPageOrientation.landscape;
    }
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    PdfPage page = document.pages.add();
    double y = 0;
    final String heading = title ?? opts.title ?? '';
    if (heading.isNotEmpty) {
      y = _drawLine(page, font, heading, y);
    }
    final String visible = _visibleText(markdown);
    final List<String> lines = visible.split('\n');
    for (final String line in lines) {
      final List<_ZPdfRun> runs = _runs(line, latexEnabled: opts.latexEnabled);
      for (final _ZPdfRun run in runs) {
        if (run.formula && latex != null) {
          Uint8List? png;
          try {
            png = await latex.rasterize(run.text);
          } catch (_) {
            png = null;
          }
          if (png != null && png.isNotEmpty) {
            try {
              final PdfBitmap bitmap = PdfBitmap(png);
              final double h = font.height * 1.4;
              final _Placed placed = _ensure(document, page, y, h);
              page = placed.page;
              y = placed.y;
              page.graphics.drawImage(bitmap, Rect.fromLTWH(0, y, h, h));
              y += h;
              continue;
            } catch (_) {
              // Bytes non décodables : la formule reste du texte.
            }
          }
        }
        final _Placed placed = _ensure(document, page, y, font.height);
        page = placed.page;
        y = _drawLine(page, font, run.text, placed.y);
      }
    }
    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}

/// Libellé d'un lien ou d'une image, sans son adresse.
String _visibleText(String markdown) {
  final String noImages = markdown.replaceAllMapped(
    RegExp(r'!\[[^\]]*\]\([^)]*\)'),
    (Match match) => _label(match.group(0)!),
  );
  return noImages.replaceAllMapped(
    RegExp(r'\[[^\]]*\]\([^)]*\)'),
    (Match match) => _label(match.group(0)!),
  );
}

String _label(String raw) {
  final int start = raw.indexOf('[');
  final int end = raw.indexOf(']');
  if (start < 0 || end <= start) return '';
  return raw.substring(start + 1, end);
}

class _ZPdfRun {
  const _ZPdfRun(this.text, {required this.formula});

  final String text;
  final bool formula;
}

/// Découpe [line] sur `$`. Un délimiteur non refermé laisse le reste en
/// texte : aucun caractère n'est perdu.
List<_ZPdfRun> _runs(String line, {required bool latexEnabled}) {
  if (!latexEnabled || !line.contains(r'$')) {
    return <_ZPdfRun>[_ZPdfRun(line, formula: false)];
  }
  final List<String> parts = line.split(r'$');
  if (parts.length.isOdd) {
    return <_ZPdfRun>[
      for (int i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty) _ZPdfRun(parts[i], formula: i.isOdd),
    ];
  }
  final String tail = parts.removeLast();
  final List<_ZPdfRun> runs = <_ZPdfRun>[
    for (int i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) _ZPdfRun(parts[i], formula: i.isOdd),
  ];
  final String leftover = '\$$tail';
  if (leftover.isNotEmpty) {
    runs.add(_ZPdfRun(leftover, formula: false));
  }
  return runs;
}

class _Placed {
  const _Placed(this.page, this.y);

  final PdfPage page;
  final double y;
}

_Placed _ensure(PdfDocument document, PdfPage page, double y, double height) {
  final double limit = page.getClientSize().height - 24;
  if (y + height <= limit) return _Placed(page, y);
  return _Placed(document.pages.add(), 0);
}

double _drawLine(PdfPage page, PdfFont font, String text, double y) {
  final Size size = page.getClientSize();
  page.graphics.drawString(
    text,
    font,
    bounds: Rect.fromLTWH(0, y, size.width, font.height + 2),
  );
  return y + font.height + 2;
}
