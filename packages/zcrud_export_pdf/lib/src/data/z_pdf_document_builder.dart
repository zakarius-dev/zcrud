/// Backend PDF **images → document** — arête `syncfusion_flutter_pdf` CONFINÉE
/// (E11b-3, Axe A, AD-8/SM-5).
///
/// origine: E11b-3. Déduplique le `PdfCreationService` copié à l'identique dans
/// DODLP et IFFD (scans/images → PDF multi-pages) en une **source unique**. Comme
/// les autres backends (`z_excel_exporter.dart`/`z_pdf_exporter.dart`), l'import
/// Syncfusion est **confiné à ce fichier** : il n'est JAMAIS réexporté par le
/// barrel, et aucun type `PdfDocument`/`PdfBitmap` n'apparaît dans une signature
/// publique. Entrée = bytes d'images **neutres** (`List<Uint8List>`), sortie =
/// **bytes neutres** (`Uint8List`, préfixe `%PDF-`) → fuite de type structurellement
/// impossible (AD-1 signature). Aucune clé/licence committée, aucun `badCert`
/// (AD-12). Anti-fuite de cycle de vie (learning E5) : `PdfDocument.dispose()` en
/// `finally`, y compris chemins vide/exception.
///
/// **Aucun second moteur PDF** (AD-8) : réutilise `syncfusion_flutter_pdf` DÉJÀ
/// déclaré (`PdfBitmap` + `page.graphics.drawImage`). Pas de `pdf`/`printing`.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'z_pdf_export_options.dart';

/// Assemble une liste ORDONNÉE de bytes d'images en un **unique** document PDF
/// multi-pages (une image par page, dans l'ordre) et renvoie ses **bytes**
/// (`Uint8List`, préfixe `%PDF-`).
///
/// Fit-to-page préservant le ratio, image centrée : une image plus large/haute
/// que la page n'est **ni rognée ni déformée** (AC2). [options] `orientation`
/// (défaut portrait) est réutilisé si fourni (AC2).
///
/// **Défensif (AD-10, AC3)** :
/// - [images] vide → PDF **valide** d'une page vide (jamais 0-page/exception).
/// - un élément dont les bytes ne sont **pas** une image décodable est **ignoré**
///   (page sautée), le reste est produit **sans crash**.
/// - `PdfDocument.dispose()` en `finally` sur TOUS les chemins (anti-fuite E5).
Uint8List buildImagesPdf(
  List<Uint8List> images, {
  ZPdfExportOptions? options,
}) {
  final opts = options ?? const ZPdfExportOptions();
  final document = PdfDocument();
  try {
    if (opts.orientation == ZPdfOrientation.landscape) {
      document.pageSettings.orientation = PdfPageOrientation.landscape;
    }

    for (final bytes in images) {
      // Décodage AVANT d'ajouter la page : bytes non décodables → page sautée
      // (aucune page orpheline), le reste du document reste valide (AD-10).
      final PdfBitmap bitmap;
      try {
        bitmap = PdfBitmap(bytes);
      } catch (_) {
        continue;
      }

      final page = document.pages.add();
      final size = page.getClientSize();
      final imgW = bitmap.width.toDouble();
      final imgH = bitmap.height.toDouble();

      // Fit-to-page ratio-preserving, centré (jamais de rognage ni distorsion).
      if (imgW > 0 && imgH > 0) {
        final scale = math.min(size.width / imgW, size.height / imgH);
        final drawW = imgW * scale;
        final drawH = imgH * scale;
        final left = (size.width - drawW) / 2;
        final top = (size.height - drawH) / 2;
        page.graphics.drawImage(bitmap, Rect.fromLTWH(left, top, drawW, drawH));
      }
    }

    // Défensif : aucune image décodable → garantir un PDF valide (une page vide),
    // jamais un document 0-page ambigu.
    if (document.pages.count == 0) {
      document.pages.add();
    }

    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}
