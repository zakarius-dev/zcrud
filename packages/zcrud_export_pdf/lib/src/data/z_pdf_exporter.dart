/// Backend PDF du service d'export — **SEULE arête `syncfusion_flutter_pdf`** du
/// graphe zcrud (E11a-3, AD-8/SM-5).
///
/// origine: E11a-3. L'import Syncfusion pdf est **confiné à ce fichier** : il
/// n'est JAMAIS réexporté par le barrel `zcrud_export.dart`, et aucun type
/// `PdfDocument`/`PdfGrid`/`PdfPage` n'apparaît dans une signature publique. La
/// fonction [buildPdfBytes] prend une [ZExportTable] **neutre** (chaînes) et rend
/// des **bytes neutres** (`Uint8List`) : la fuite de type est structurellement
/// impossible (AD-1 signature). Un consommateur qui n'importe pas `zcrud_export`
/// ne tire donc AUCUNE dépendance PDF (SM-5).
///
/// **Aucune clé/licence Syncfusion committée** ni `badCertificateCallback`
/// (AD-12). **Anti-fuite de cycle de vie (learning E5)** : le `PdfDocument` est
/// `dispose()` en `finally`, y compris sur le chemin d'export vide ou en cas
/// d'exception (AC10).
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'z_export_table.dart';
import 'z_pdf_export_options.dart';

/// Construit un document PDF tabulaire à partir de la [table] neutre et renvoie
/// ses **bytes** (`Uint8List`, préfixe `%PDF-`). En-tête + `rows.length` lignes.
///
/// [options] (E11b-3, Axe C) paramètre la MISE EN PAGE — anti-rognage (LOW-1
/// d'E11a-3) : orientation (paysage → page plus large), titre optionnel dessiné
/// en haut, en-tête répété, en-tête riche opt-in (`options.header`, CR pilote
/// DODLP 2026-08-11 lot 4 — logo + lignes organisationnelles + sous-titre, voir
/// [ZPdfHeaderSpec]). **Rétro-compat (AC9)** : `options == null` **ou**
/// `options.header == null` conserve le comportement E11a-3 (portrait, sans
/// titre riche, largeurs réparties) bit pour bit. La largeur
/// des colonnes est répartie sur la largeur de page (`allowHorizontalOverflow =
/// false` + `columns[i].width`) de sorte que la **dernière** colonne soit rendue
/// même avec de nombreuses colonnes (AC10) ; le contenu (`col.format`) reste
/// inchangé (parité SM-5).
///
/// Défensif (AD-10) : [table] sans colonne → document valide d'**une page**
/// (aucune grille dégénérée) ; [table] sans ligne → grille avec en-têtes seuls ;
/// cellule `''` → cellule vide. Ne lève pas pour une table vide.
Uint8List buildPdfBytes(ZExportTable table, {ZPdfExportOptions? options}) {
  final opts = options ?? const ZPdfExportOptions();
  final document = PdfDocument();
  try {
    if (opts.orientation == ZPdfOrientation.landscape) {
      document.pageSettings.orientation = PdfPageOrientation.landscape;
    }
    final page = document.pages.add();
    final size = page.getClientSize();

    // Titre optionnel (+ en-tête riche opt-in) dessiné en haut ; décale le haut
    // de la grille.
    var gridTop = 0.0;
    final title = opts.title;
    final header = opts.header;
    if (header != null) {
      // En-tête riche (CR pilote DODLP, lot 4 — parité `dodlp_pdf_header.dart`) :
      // logo + lignes organisationnelles + titre centré + sous-titre, empilés
      // verticalement. Purement additif (AC9) : SEULEMENT actif quand
      // `options.header` est explicitement fourni — sinon la branche `else`
      // ci-dessous reproduit le rendu E11a-3 bit pour bit.
      var y = 0.0;
      final logoBytes = header.logoBytes;
      if (logoBytes != null) {
        try {
          final bitmap = PdfBitmap(logoBytes);
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, y, header.logoWidth, header.logoHeight),
          );
        } catch (_) {
          // Bytes non décodables comme image (AD-10) : logo omis, le reste de
          // l'en-tête (lignes organisationnelles, titre, sous-titre) continue
          // d'être rendu normalement — jamais de crash.
        }
        y += header.logoHeight + 4;
      }
      if (header.organizationLines.isNotEmpty) {
        final orgFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          10,
          style: PdfFontStyle.bold,
        );
        final orgText = header.organizationLines.join('\n');
        final orgSize = orgFont.measureString(orgText);
        page.graphics.drawString(
          orgText,
          orgFont,
          bounds: Rect.fromLTWH(0, y, size.width, orgSize.height),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        y += orgSize.height + 6;
      }
      if (title != null && title.isNotEmpty) {
        final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16);
        page.graphics.drawString(
          title,
          titleFont,
          bounds: Rect.fromLTWH(0, y, size.width, 22),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        y += 22 + 6;
      }
      final subtitle = header.subtitle;
      if (subtitle != null && subtitle.isNotEmpty) {
        final subtitleFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          10,
          style: PdfFontStyle.italic,
        );
        final subtitleSize = subtitleFont.measureString(subtitle);
        page.graphics.drawString(
          subtitle,
          subtitleFont,
          bounds: Rect.fromLTWH(0, y, size.width, subtitleSize.height),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        y += subtitleSize.height + 6;
      }
      gridTop = y;
    } else if (title != null && title.isNotEmpty) {
      // Rendu historique E11a-3, INCHANGÉ bit pour bit (AC9, rétro-compat) :
      // titre seul, aligné par défaut, décalage fixe de 28.
      final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16);
      page.graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(0, 0, size.width, 22),
      );
      gridTop = 28;
    }

    // Sans colonne : une page (+ titre éventuel) suffit (PDF valide).
    if (table.headers.isNotEmpty) {
      final grid = PdfGrid();
      grid.columns.add(count: table.headers.length);
      // En-tête répété sur chaque page auto-paginée (AC9).
      grid.repeatHeader = opts.repeatHeader;

      // Ligne d'en-tête.
      final header = grid.headers.add(1)[0];
      for (var c = 0; c < table.headers.length; c++) {
        header.cells[c].value = table.headers[c];
      }

      // Lignes de données.
      for (final rowValues in table.rows) {
        final row = grid.rows.add();
        for (var c = 0; c < rowValues.length; c++) {
          row.cells[c].value = rowValues[c];
        }
      }

      // Anti-rognage (AC10, clôt LOW-1) : police compacte + débordement
      // horizontal AUTORISÉ. `allowHorizontalOverflow = true` = mécanisme
      // Syncfusion documenté : les colonnes qui ne tiennent pas sur la largeur
      // de page sont rejouées dans une bande SOUS la précédente (chaque colonne
      // à sa largeur naturelle) — AUCUNE colonne n'est rognée ni écrasée, la
      // dernière colonne (en-tête ET valeur) est toujours rendue. Le paysage
      // (option) élargit la page et réduit le nombre de bandes.
      grid.style.font = PdfStandardFont(PdfFontFamily.helvetica, 8);
      grid.style.allowHorizontalOverflow = true;

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, gridTop, size.width, size.height - gridTop),
      );
    }

    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}
