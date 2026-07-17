/// Gabarit PDF flashcards — composition **inline** texte + LaTeX (su-11,
/// AC1/AC2/AC5/AC9). Arête `syncfusion_flutter_pdf` **CONFINÉE à ce fichier**.
///
/// origine: su-11 (E-STUDY-UI, FR-SU16). Produit un PDF imprimable typé d'un
/// dossier entier **ou** d'une sélection de cartes, avec ou sans réponses. Comme
/// les autres backends (`z_pdf_exporter.dart` / `z_pdf_document_builder.dart`),
/// l'import Syncfusion est confiné ici : il n'est JAMAIS réexporté par le barrel,
/// et aucun type `PdfDocument`/`PdfBitmap`/… n'apparaît dans une signature
/// publique. Entrée = [ZFlashcardPdfInput] **neutre** ; sortie = [ZExportedFile]
/// **neutre** (bytes `%PDF-`) → fuite de type structurellement impossible (AD-1).
///
/// **PUR (AD-42)** : ce fichier n'importe NI `printing`, NI `flutter_math_fork`,
/// NI `dart:ui` de rendu écran (`RepaintBoundary`/`toImage`/`PictureRecorder`).
/// La rasterisation LaTeX passe par le **port pur** [ZLatexRasterizer] (impl
/// concrète hors package, dans `zcrud_export_ui`). Le gabarit reste exécutable
/// sous `flutter test` **sans plateforme ni pixel réel** (rasterizer = fake/null).
///
/// **Composition inline (AC5)** : au-delà de `buildImagesPdf` (une image par
/// page), ce gabarit compose **texte + bitmap DANS le flux** (`drawString` mot à
/// mot + `drawImage` positionné à la volée). Une formule s'insère DANS le
/// paragraphe ; le texte non-LaTeX reste **extractible** (dessiné en texte).
///
/// **Défensif (AD-10, AC9)** : dossier vide → PDF 1 page (titre) ; carte
/// malformée → rendue sans crash ; LaTeX invalide (rasterizer `null`) → repli sur
/// le **texte brut** de la formule ; explication longue → **pagination** ;
/// Unicode/RTL → rendu sans exception. `PdfDocument.dispose()` en `finally` sur
/// TOUS les chemins (learning E5).
///
/// **AD-12** : aucune clé/licence Syncfusion committée, aucun `badCertificateCallback`.
library;

import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/z_latex_rasterizer.dart';
import 'z_answer_visibility.dart';
import 'z_exported_file.dart';
import 'z_flashcard_pdf_input.dart';
import 'z_pdf_export_options.dart';

/// Gabarit PDF flashcards **PUR** (bytes in → bytes out).
///
/// Le [rasterizer] est un **port** injecté (impl concrète dans `zcrud_export_ui`).
/// S'il est `null` ou échoue sur une formule, le gabarit retombe sur le texte
/// brut de la formule (AC9) — il ne lève JAMAIS vers l'appelant.
class ZFlashcardPdfTemplate {
  /// Construit le gabarit. [rasterizer] optionnel (repli texte brut si absent) ;
  /// [options] paramètre l'orientation (portrait par défaut).
  const ZFlashcardPdfTemplate({this.rasterizer, this.options});

  /// Port de rasterisation LaTeX (impl concrète hors package). `null` → repli texte.
  final ZLatexRasterizer? rasterizer;

  /// Options de mise en page (orientation). `null` → portrait.
  final ZPdfExportOptions? options;

  // Métriques de rendu (points PDF). Documentées : le gabarit produit des BYTES
  // sans BuildContext (aucune l10n/thème runtime) → constantes documentées, non
  // « couleurs codées en dur évitables » (T2 : « sinon constantes documentées »).
  static const double _titleSize = 18;
  static const double _headingSize = 12;
  static const double _bodySize = 11;
  static const double _badgeSize = 9;
  static const double _paraGap = 6; // interligne entre blocs

  /// Construit le PDF pour [input] avec le mode d'affichage [answerVisibility].
  ///
  /// Renvoie le triplet neutre `{bytes, fileName, mimeType}` — `mimeType` =
  /// `application/pdf`, bytes préfixés `%PDF-`. Ne lève jamais (AD-10).
  Future<ZExportedFile> build(
    ZFlashcardPdfInput input, {
    ZAnswerVisibility answerVisibility = ZAnswerVisibility.withAnswers,
    String fileName = 'flashcards.pdf',
  }) async {
    // Pré-rasterisation (le port est asynchrone) : on résout TOUTES les formules
    // rendues AVANT la mise en page synchrone. Cache par source (dé-duplication).
    final bitmaps = await _prerasterize(input, answerVisibility);

    final document = PdfDocument();
    try {
      final landscape = (options ?? const ZPdfExportOptions()).orientation ==
          ZPdfOrientation.landscape;
      if (landscape) {
        document.pageSettings.orientation = PdfPageOrientation.landscape;
      }

      final flow = _Flow(document);
      flow.newPage();

      // Titre (toujours présent, même dossier vide → PDF 1 page jamais 0-page).
      final titleFont =
          PdfStandardFont(PdfFontFamily.helvetica, _titleSize, style: PdfFontStyle.bold);
      flow.drawText(input.title.isEmpty ? 'Flashcards' : input.title, titleFont);
      flow.newParagraph(_paraGap);

      final n = input.cards.length;
      for (var i = 0; i < n; i++) {
        _renderCard(flow, input, input.cards[i], i + 1, n, answerVisibility, bitmaps);
      }

      final bytes = Uint8List.fromList(document.saveSync());
      return ZExportedFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
    } finally {
      document.dispose();
    }
  }

  /// Résout toutes les formules LaTeX effectivement rendues en [PdfBitmap] (ou
  /// `null` → repli texte). Défensif : rasterizer `null`/throw, PNG invalide → `null`.
  Future<Map<String, PdfBitmap?>> _prerasterize(
    ZFlashcardPdfInput input,
    ZAnswerVisibility visibility,
  ) async {
    final r = rasterizer;
    if (r == null) return const <String, PdfBitmap?>{};
    final sources = <String>{};
    for (final card in input.cards) {
      sources.addAll(_latexOf(card.question));
      for (final ch in card.choices ?? const <ZFlashcardPdfChoice>[]) {
        sources.addAll(_latexOf(ch.content));
      }
      if (visibility == ZAnswerVisibility.withAnswers) {
        sources.addAll(_latexOf(card.answer ?? ''));
        sources.addAll(_latexOf(card.explanation ?? ''));
      }
    }
    final out = <String, PdfBitmap?>{};
    for (final src in sources) {
      Uint8List? png;
      try {
        png = await r.rasterize(src);
      } catch (_) {
        png = null; // AD-10 : port défaillant ⇒ repli texte, jamais de throw.
      }
      PdfBitmap? bmp;
      if (png != null && png.isNotEmpty) {
        try {
          bmp = PdfBitmap(png);
        } catch (_) {
          bmp = null; // PNG non décodable ⇒ repli texte.
        }
      }
      out[src] = bmp;
    }
    return out;
  }

  void _renderCard(
    _Flow flow,
    ZFlashcardPdfInput input,
    ZFlashcardPdfCard card,
    int index,
    int total,
    ZAnswerVisibility visibility,
    Map<String, PdfBitmap?> bitmaps,
  ) {
    final headingFont =
        PdfStandardFont(PdfFontFamily.helvetica, _headingSize, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, _bodySize);
    final bodyBold =
        PdfStandardFont(PdfFontFamily.helvetica, _bodySize, style: PdfFontStyle.bold);
    final badgeFont = PdfStandardFont(PdfFontFamily.helvetica, _badgeSize);

    // Numérotation (heading) — table unique.
    flow.drawText('Carte $index / $total', headingFont);
    flow.newParagraph(2);

    // Badge d'instruction (par type, table unique jamais redécidée).
    flow.drawBadge(input.labels.badgeFor(card.typeKey), badgeFont);
    flow.newParagraph(2);

    // Énoncé (composition inline texte + LaTeX).
    _drawInline(flow, card.question, bodyFont, bitmaps);
    flow.newParagraph(_paraGap / 2);

    // Choix (QCM) : ✓/✗ colorés en withAnswers, non marqués sinon.
    final choices = card.choices;
    if (choices != null) {
      for (final ch in choices) {
        flow.newLine(bodyFont.height);
        if (visibility == ZAnswerVisibility.withAnswers) {
          if (ch.isCorrect) {
            flow.drawCheck(bodyFont.height);
          } else {
            flow.drawCross(bodyFont.height);
          }
        } else {
          flow.drawEmptyBox(bodyFont.height);
        }
        _drawInline(flow, ch.content, bodyFont, bitmaps);
      }
      flow.newParagraph(_paraGap / 2);
    }

    if (visibility == ZAnswerVisibility.withAnswers) {
      // Vrai/Faux.
      if (card.isTrue != null) {
        flow.newLine(bodyFont.height);
        flow.drawText('${input.labels.answerLabel} : ', bodyBold);
        final ok = card.isTrue!;
        flow.drawText(
          ok ? input.labels.trueLabel : input.labels.falseLabel,
          bodyBold,
          color: ok ? _correctColor : _incorrectColor,
        );
        flow.newParagraph(_paraGap / 2);
      }
      // Réponse distinguée (libre).
      final answer = card.answer;
      if (answer != null && answer.isNotEmpty) {
        flow.newLine(bodyFont.height);
        flow.drawText('${input.labels.answerLabel} : ', bodyBold);
        _drawInline(flow, answer, bodyFont, bitmaps);
        flow.newParagraph(_paraGap / 2);
      }
      // Explication (paginée si longue).
      final explanation = card.explanation;
      if (explanation != null && explanation.isNotEmpty) {
        flow.newLine(bodyFont.height);
        flow.drawText('${input.labels.explanationLabel} : ', bodyBold);
        _drawInline(flow, explanation, bodyFont, bitmaps);
        flow.newParagraph(_paraGap / 2);
      }
    }

    flow.newParagraph(_paraGap);
  }

  /// Écrit [text] en composant texte + LaTeX INLINE : les segments `$...$` sont
  /// rasterisés (bitmap), les autres dessinés en texte (extractible). Repli sur
  /// le texte brut de la source LaTeX si son bitmap est absent (AC9).
  void _drawInline(
    _Flow flow,
    String text,
    PdfStandardFont font,
    Map<String, PdfBitmap?> bitmaps,
  ) {
    for (final seg in _tokenize(text)) {
      if (seg.isLatex) {
        final bmp = bitmaps[seg.text];
        if (bmp != null) {
          flow.drawInlineBitmap(bmp, font.height);
        } else {
          // Repli défensif (AC9) : texte brut de la formule (jamais de trou).
          flow.drawText(seg.text, font);
        }
      } else if (seg.text.isNotEmpty) {
        flow.drawText(seg.text, font);
      }
    }
  }

  /// Extrait les sources LaTeX (`$...$`) d'un texte (sans délimiteurs).
  static Iterable<String> _latexOf(String text) sync* {
    for (final seg in _tokenize(text)) {
      if (seg.isLatex && seg.text.isNotEmpty) yield seg.text;
    }
  }

  /// Découpe [text] en segments alternés texte / LaTeX sur le délimiteur `$`.
  /// Les positions impaires sont du LaTeX. Un `$` non apparié laisse le reste en
  /// texte (défensif). Aucun throw.
  static List<_Seg> _tokenize(String text) {
    if (!text.contains(r'$')) return <_Seg>[_Seg(false, text)];
    final parts = text.split(r'$');
    // Nombre PAIR de `$` ⇒ (parts.length impair) alternance propre. Nombre IMPAIR
    // (délimiteur non fermé) ⇒ le dernier fragment reste du TEXTE (repli).
    final unbalanced = parts.length.isEven;
    final out = <_Seg>[];
    for (var i = 0; i < parts.length; i++) {
      final isLast = i == parts.length - 1;
      final isLatex = i.isOdd && !(unbalanced && isLast);
      out.add(_Seg(isLatex, parts[i]));
    }
    return out;
  }

  /// Couleur documentée « correct » (vert). Pas de BuildContext dans un
  /// générateur de bytes → constante documentée (T2), non couleur « évitable ».
  static final PdfColor _correctColor = PdfColor(27, 128, 62);

  /// Couleur documentée « incorrect » (rouge).
  static final PdfColor _incorrectColor = PdfColor(192, 40, 40);
}

/// Un segment de texte inline : soit du texte brut, soit une source LaTeX.
class _Seg {
  const _Seg(this.isLatex, this.text);
  final bool isLatex;
  final String text;
}

/// Moteur de **flux** : place mots et bitmaps en ligne, retourne à la ligne et
/// pagine automatiquement. `syncfusion_flutter_pdf` confiné au fichier parent.
class _Flow {
  _Flow(this._document);

  final PdfDocument _document;
  late PdfPage _page;
  late double _contentW;
  late double _contentH;
  double _x = 0;
  double _yTop = 0;
  double _lineMaxH = 0;

  /// Ajoute une page et réinitialise le curseur en haut à gauche du client.
  void newPage() {
    _page = _document.pages.add();
    final size = _page.getClientSize();
    _contentW = size.width;
    _contentH = size.height;
    _x = 0;
    _yTop = 0;
    _lineMaxH = 0;
  }

  /// Termine la ligne courante et descend de [gap] points (nouveau paragraphe).
  void newParagraph(double gap) {
    if (_x > 0 || _lineMaxH > 0) {
      _yTop += _lineMaxH;
      _lineMaxH = 0;
      _x = 0;
    }
    _yTop += gap;
    _ensureRoom(0);
  }

  /// Force un retour à la ligne, en réservant au moins [minLineHeight] de hauteur.
  void newLine(double minLineHeight) {
    if (_x > 0 || _lineMaxH > 0) {
      _yTop += _lineMaxH;
      _x = 0;
      _lineMaxH = 0;
    }
    _lineMaxH = minLineHeight;
    _ensureRoom(minLineHeight);
  }

  /// Nouvelle page si le bas courant + [h] dépasse la zone client (pagination).
  void _ensureRoom(double h) {
    if (_yTop + h > _contentH && _yTop > 0) {
      newPage();
    }
  }

  /// Place un élément (largeur [w], hauteur [h]) : retour à la ligne si trop
  /// large, nouvelle page si trop bas, puis peint via [paint] au coin haut-gauche.
  void _place(double w, double h, void Function(double x, double y) paint) {
    if (_x > 0 && _x + w > _contentW) {
      // Retour à la ligne.
      _yTop += _lineMaxH == 0 ? h : _lineMaxH;
      _x = 0;
      _lineMaxH = 0;
    }
    _ensureRoom(h);
    paint(_x, _yTop);
    _x += w;
    if (h > _lineMaxH) _lineMaxH = h;
  }

  /// Dessine [text] en le découpant en mots (chaque mot = un élément plaçable) :
  /// le texte reste **extractible** (drawString), avec habillage et pagination.
  ///
  /// Défensif (AD-10) : les polices STANDARD (WinAnsi) ne portent PAS tous les
  /// glyphes Unicode (arabe/CJK/emoji…) et `measureString`/`drawString`
  /// **lèveraient** sur un caractère non supporté. [text] est donc d'abord
  /// [_sanitize]é (les glyphes hors police → `?`) — le rendu ne throw JAMAIS
  /// (le shaping RTL/complexe complet exigerait une police TrueType embarquée,
  /// hors périmètre pur de `zcrud_export`).
  void drawText(String rawText, PdfStandardFont font, {PdfColor? color}) {
    if (rawText.isEmpty) return;
    final text = _sanitize(font, rawText);
    if (text.isEmpty) return;
    final brush = color == null ? null : PdfSolidBrush(color);
    final spaceW = _measure(font, ' ');
    final words = text.split(RegExp(r'(?<= )|(?= )')); // conserve les espaces
    for (final token in words) {
      if (token.isEmpty) continue;
      if (token == ' ') {
        // Espace : avance sans peindre (sauf en début de ligne où on l'ignore).
        if (_x > 0) _x += spaceW;
        continue;
      }
      final w = _measure(font, token);
      final h = font.height;
      _place(w, h, (x, y) {
        _page.graphics.drawString(
          token,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(x, y, w <= 0 ? _contentW : w, h),
        );
      });
    }
  }

  /// Dessine un badge : texte encadré d'un rectangle de fond léger (bloc).
  void drawBadge(String rawText, PdfStandardFont font) {
    final text = _sanitize(font, rawText);
    if (_x > 0) newLine(font.height);
    final padH = 4.0;
    final padV = 2.0;
    final tw = _measure(font, text);
    final w = tw + padH * 2;
    final h = font.height + padV * 2;
    _place(w, h, (x, y) {
      _page.graphics.drawRectangle(
        pen: PdfPen(_badgeBorder, width: 0.5),
        brush: PdfSolidBrush(_badgeBg),
        bounds: Rect.fromLTWH(x, y, w, h),
      );
      _page.graphics.drawString(
        text,
        font,
        bounds: Rect.fromLTWH(x + padH, y + padV, tw <= 0 ? w : tw, font.height),
      );
    });
  }

  /// Insère un bitmap LaTeX **dans le flux**, mis à l'échelle sur la hauteur de
  /// ligne [lineH] (ratio préservé).
  void drawInlineBitmap(PdfBitmap bmp, double lineH) {
    final bw = bmp.width.toDouble();
    final bh = bmp.height.toDouble();
    if (bw <= 0 || bh <= 0) return;
    // Échelle : hauteur ~ 1.15× la ligne (les formules débordent un peu), bornée.
    final targetH = lineH * 1.15;
    final scale = targetH / bh;
    final drawW = bw * scale;
    final drawH = targetH;
    _place(drawW, drawH, (x, y) {
      _page.graphics.drawImage(bmp, Rect.fromLTWH(x, y, drawW, drawH));
    });
  }

  /// Dessine un ✓ vectoriel **vert** (WinAnsi ne porte pas ✓ ⇒ tracé sûr).
  void drawCheck(double lineH) {
    final s = lineH * 0.8;
    _place(s + 3, lineH, (x, y) {
      final pen = PdfPen(PdfColor(27, 128, 62), width: 1.6);
      final cy = y + lineH / 2;
      _page.graphics
          .drawLine(pen, Offset(x + s * 0.15, cy), Offset(x + s * 0.4, cy + s * 0.3));
      _page.graphics
          .drawLine(pen, Offset(x + s * 0.4, cy + s * 0.3), Offset(x + s * 0.85, cy - s * 0.35));
    });
  }

  /// Dessine un ✗ vectoriel **rouge**.
  void drawCross(double lineH) {
    final s = lineH * 0.7;
    _place(s + 3, lineH, (x, y) {
      final pen = PdfPen(PdfColor(192, 40, 40), width: 1.6);
      final cy = y + lineH / 2;
      _page.graphics
          .drawLine(pen, Offset(x + s * 0.2, cy - s * 0.35), Offset(x + s * 0.8, cy + s * 0.35));
      _page.graphics
          .drawLine(pen, Offset(x + s * 0.8, cy - s * 0.35), Offset(x + s * 0.2, cy + s * 0.35));
    });
  }

  /// Dessine une case vide (choix non marqué, withoutAnswers).
  void drawEmptyBox(double lineH) {
    final s = lineH * 0.6;
    _place(s + 3, lineH, (x, y) {
      final cy = y + (lineH - s) / 2;
      _page.graphics.drawRectangle(
        pen: PdfPen(_badgeBorder, width: 0.8),
        bounds: Rect.fromLTWH(x, cy, s, s),
      );
    });
  }

  double _measure(PdfStandardFont font, String text) {
    if (text.isEmpty) return 0;
    return font.measureString(text).width;
  }

  /// Remplace les caractères non portés par [font] (WinAnsi) par `?` afin que
  /// `measureString`/`drawString` ne lèvent JAMAIS (AD-10). Chemin rapide : si la
  /// chaîne entière se mesure, elle est renvoyée telle quelle (aucun coût).
  static String _sanitize(PdfStandardFont font, String text) {
    if (text.isEmpty) return text;
    try {
      font.measureString(text);
      return text; // Tous les glyphes sont supportés.
    } catch (_) {
      // Chemin lent (rare) : filtre glyphe par glyphe.
      final sb = StringBuffer();
      for (final rune in text.runes) {
        final ch = String.fromCharCode(rune);
        try {
          font.measureString(ch);
          sb.write(ch);
        } catch (_) {
          sb.write('?');
        }
      }
      return sb.toString();
    }
  }

  static final PdfColor _badgeBg = PdfColor(232, 236, 245);
  static final PdfColor _badgeBorder = PdfColor(170, 178, 196);
}
