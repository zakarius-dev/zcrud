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
import '../domain/z_pdf_font_provider.dart';
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
  const ZFlashcardPdfTemplate({
    this.rasterizer,
    this.options,
    this.fontProvider,
  });

  /// Port de rasterisation LaTeX (impl concrète hors package). `null` → repli texte.
  final ZLatexRasterizer? rasterizer;

  /// Port de police **TrueType** (CR-LEX-38) — `null` ⇒ police standard
  /// WinAnsi, donc **latin-1 seulement**, et tout caractère hors jeu redevient
  /// `?`. Le fournir suffit à ce que l'arabe, le grec, le cyrillique, le CJK ou
  /// les emoji survivent à l'export.
  ///
  /// ⚠️ La police fournie doit **couvrir** les écritures de votre corpus : le
  /// gabarit n'en compose qu'une seule pour tout le document.
  final ZPdfFontProvider? fontProvider;

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

  /// Charge les octets de police, **sans jamais lever** (AD-10).
  Future<Uint8List?> _loadFontBytes() async {
    final provider = fontProvider;
    if (provider == null) return null;
    try {
      final bytes = await provider.loadFont();
      return (bytes == null || bytes.isEmpty) ? null : bytes;
    } on Object {
      // Un provider défaillant ne doit pas coûter l'export entier : on dégrade
      // vers la police standard, comme s'il n'avait pas été fourni.
      return null;
    }
  }

  /// Fabrique une police à [size] : TrueType si [bytes] est fourni (Unicode),
  /// sinon standard WinAnsi (CR-LEX-38). Un `PdfTrueTypeFont` invalide retombe
  /// aussi sur le standard — jamais d'export perdu.
  static PdfFont _font(Uint8List? bytes, double size, {PdfFontStyle? style}) {
    if (bytes != null) {
      try {
        return PdfTrueTypeFont(bytes, size, style: style);
      } on Object {
        // Octets illisibles : on ne casse pas l'export.
      }
    }
    return PdfStandardFont(PdfFontFamily.helvetica, size, style: style);
  }

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
    // CR-LEX-38 : octets de police chargés UNE fois, défensivement. Un provider
    // absent, rendant `null`, ou levant ⇒ repli sur la police standard : le
    // rendu fonctionne toujours, il redevient borné au latin-1.
    final Uint8List? fontBytes = await _loadFontBytes();

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
          _font(fontBytes, _titleSize, style: PdfFontStyle.bold);
      // CR-LEX-42 : le repli de titre était lui aussi écrit en français en dur.
      flow.drawText(
        input.title.isEmpty ? input.labels.untitledLabel : input.title,
        titleFont,
      );
      flow.newParagraph(_paraGap);

      final n = input.cards.length;
      for (var i = 0; i < n; i++) {
        _renderCard(flow, input, input.cards[i], i + 1, n, answerVisibility,
            bitmaps, fontBytes);
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
      // CR-LEX-39 : l'indice est rendu dans LES DEUX modes — ses formules
      // doivent donc être pré-rasterisées inconditionnellement.
      sources.addAll(_latexOf(card.hint ?? ''));
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
    Uint8List? fontBytes,
  ) {
    final headingFont = _font(fontBytes, _headingSize, style: PdfFontStyle.bold);
    final bodyFont = _font(fontBytes, _bodySize);
    final bodyBold = _font(fontBytes, _bodySize, style: PdfFontStyle.bold);
    final badgeFont = _font(fontBytes, _badgeSize);

    // Numérotation (heading) — table unique. CR-LEX-42 : la seule chaîne
    // française que l'hôte ne pouvait PAS surcharger. Un patron vide supprime
    // la numérotation, ce qui est un choix d'hôte légitime.
    final numbering = input.labels.cardNumberFor(index, total);
    if (numbering.isNotEmpty) {
      flow.drawText(numbering, headingFont);
      flow.newParagraph(2);
    }

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

    // CR-LEX-39 — INDICE, rendu HORS du bloc réponse : il reste visible en
    // `withoutAnswers`, qui est le mode RÉVISION, celui où un indice sert le
    // plus. Le masquer avec la réponse en ferait un doublon de l'explication.
    final hint = card.hint;
    if (hint != null && hint.isNotEmpty) {
      flow.newLine(bodyFont.height);
      flow.drawText('${input.labels.hintLabel} : ', bodyBold);
      _drawInline(flow, hint, bodyFont, bitmaps);
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
    PdfFont font,
    Map<String, PdfBitmap?> bitmaps,
  ) {
    for (final seg in _tokenize(text, latexEnabled: _latexEnabled)) {
      if (seg.isLatex) {
        final bmp = bitmaps[seg.source];
        if (bmp != null) {
          flow.drawInlineBitmap(bmp, font.height);
        } else {
          // CR-LEX-41 §B — repli défensif (AC9) : on réémet le texte SOURCE,
          // DÉLIMITEURS COMPRIS. Auparavant `seg.text` était peint nu : les `$`
          // disparaissaient du document, et avec eux le sens (« 100 $ US » →
          // « 100  US »). Le repli ne doit rien coûter.
          flow.drawText(seg.raw, font);
        }
      } else if (seg.raw.isNotEmpty) {
        flow.drawText(seg.raw, font);
      }
    }
  }

  /// Extrait les sources LaTeX (`$...$`) d'un texte (sans délimiteurs).
  Iterable<String> _latexOf(String text) sync* {
    for (final seg in _tokenize(text, latexEnabled: _latexEnabled)) {
      if (seg.isLatex && seg.source.isNotEmpty) yield seg.source;
    }
  }

  /// Interprétation LaTeX active (CR-LEX-41 §B) — `ZPdfExportOptions.latexEnabled`.
  bool get _latexEnabled => (options ?? const ZPdfExportOptions()).latexEnabled;

  /// Découpe [text] en segments alternés texte / LaTeX sur le délimiteur `$`.
  ///
  /// 🔴 **INVARIANT SANS PERTE (CR-LEX-41 §B)** : la concaténation des [_Seg.raw]
  /// reconstitue [text] **caractère pour caractère**. C'est ce qui garantit qu'un
  /// `$` — délimiteur apparié, délimiteur orphelin, ou simple symbole monétaire —
  /// ne peut plus s'évaporer du document. L'ancienne version, bâtie sur un
  /// `split(r'$')` dont les délimiteurs n'étaient jamais réémis, violait cet
  /// invariant en silence. Un test le vérifie sur un corpus.
  ///
  /// Un `$` non apparié rattache le reste au TEXTE (défensif). Aucun throw.
  static List<_Seg> _tokenize(String text, {bool latexEnabled = true}) {
    if (!latexEnabled || !text.contains(r'$')) {
      return <_Seg>[_Seg(false, text, text)];
    }
    final parts = text.split(r'$');
    final out = <_Seg>[];
    // `pending` porte un délimiteur ORPHELIN, recollé au texte qui le suit — il
    // appartient au contenu, pas à la syntaxe.
    var pending = '';
    var i = 0;
    while (i < parts.length) {
      out.add(_Seg(false, parts[i], pending + parts[i]));
      pending = '';
      i++;
      if (i >= parts.length) break;
      if (i < parts.length - 1) {
        // Un `$` fermant existe ⇒ formule appariée, délimiteurs conservés.
        out.add(_Seg(true, parts[i], '\$${parts[i]}\$'));
        i++;
      } else {
        pending = r'$'; // Ouvrant sans fermant : c'est du texte.
      }
    }
    if (pending.isNotEmpty) out.add(_Seg(false, '', pending));
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
  const _Seg(this.isLatex, this.source, this.raw);

  /// Le segment est une formule appariée `$...$`.
  final bool isLatex;

  /// Contenu **sans délimiteurs** — la clé de rasterisation.
  final String source;

  /// Contenu **tel qu'il figure dans la source**, délimiteurs compris. C'est ce
  /// qui est peint en repli : `raw` concaténé sur tous les segments reconstitue
  /// le texte d'origine à l'identique (CR-LEX-41 §B).
  final String raw;
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

  /// Sépare les **ruptures de ligne** d'un texte : `\r\n`, `\n`, `\r`, la
  /// tabulation verticale, le saut de page, et les séparateurs Unicode
  /// `U+2028`/`U+2029`.
  static final RegExp _lineBreaks = RegExp(r'\r\n|[\n\r\v\f\u2028\u2029]');

  /// Dessine [rawText] en le découpant en **lignes** puis en **mots** (chaque mot
  /// = un élément plaçable) : le texte reste **extractible** (drawString), avec
  /// habillage et pagination.
  ///
  /// 🔴 **CR-LEX-41 §A — les sauts de ligne étaient une PERTE SILENCIEUSE.** Le
  /// découpage ne portait que sur l'espace : un mot contenant `\n` partait en
  /// **un seul** `drawString` dans un `Rect` d'**une** hauteur de ligne, et tout
  /// ce qui suivait le saut sortait du rectangle — jamais rendu, sans exception
  /// ni compteur. Le PDF restait valide et **amputé**. C'était plus grave que la
  /// substitution Unicode de CR-LEX-38 : celle-ci laissait au moins un `?`.
  /// Un saut de ligne est désormais un **vrai retour à la ligne**.
  ///
  /// Défensif (AD-10) : les polices STANDARD (WinAnsi) ne portent PAS tous les
  /// glyphes Unicode (arabe/CJK/emoji…) et `measureString`/`drawString`
  /// **lèveraient** sur un caractère non supporté. Chaque ligne est donc
  /// [_sanitize]é (les glyphes hors police → `?`) — le rendu ne throw JAMAIS
  /// (le shaping RTL/complexe complet exige une police TrueType, cf. CR-LEX-38 :
  /// `ZPdfFontProvider`).
  void drawText(String rawText, PdfFont font, {PdfColor? color}) {
    if (rawText.isEmpty) return;
    final lines = rawText.split(_lineBreaks);
    for (var i = 0; i < lines.length; i++) {
      // Toute ligne SAUF la première ouvre un nouveau retour chariot. La
      // première ne le fait pas : `drawText` est aussi appelé EN COURS de ligne
      // (« Réponse : » puis le contenu) — la composition inline doit tenir.
      if (i > 0) newLine(font.height);
      _drawSingleLine(lines[i], font, color: color);
    }
  }

  /// Dessine UNE ligne (garantie sans rupture) mot à mot.
  ///
  /// ⚠️ La tabulation n'est **pas** transformée, et c'est un choix MESURÉ, pas un
  /// oubli. La CR-LEX-41 demandait de découper aussi sur `\t` ; l'extraction du
  /// PDF montre que `\t` ne perdait **rien** — `'AAA\tBBB'` ressort `AAA    BBB`,
  /// intact. La perte venait entièrement du `\n`. Une expansion en espaces a été
  /// écrite puis **retirée** : aucune assertion ne pouvait la faire rougir, et du
  /// code qu'aucun test ne peut infirmer est précisément ce que ce dépôt traque.
  void _drawSingleLine(String rawLine, PdfFont font, {PdfColor? color}) {
    if (rawLine.isEmpty) return;
    final text = _sanitize(font, rawLine);
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
  ///
  /// 🔴 Le badge souffrait de la **même amputation** que [drawText] avant
  /// CR-LEX-41 §A — un libellé multi-ligne était peint dans un rectangle d'une
  /// seule hauteur de ligne, et la suite disparaissait. La CR ne le signalait
  /// pas ; c'est le jumeau du défaut, deux méthodes plus loin.
  ///
  /// Un badge est par construction un **encadré d'une ligne** : plutôt que
  /// d'inventer un encadré multi-ligne, les blancs sont **aplatis** (`\s+` → un
  /// espace). Aucun mot n'est retiré — c'est une perte de mise en forme, pas de
  /// contenu, et elle est visible dans le document.
  void drawBadge(String rawText, PdfFont font) {
    final flattened = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final text = _sanitize(font, flattened);
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

  double _measure(PdfFont font, String text) {
    if (text.isEmpty) return 0;
    return font.measureString(text).width;
  }

  /// Remplace les caractères non portés par [font] (WinAnsi) par `?` afin que
  /// `measureString`/`drawString` ne lèvent JAMAIS (AD-10). Chemin rapide : si la
  /// chaîne entière se mesure, elle est renvoyée telle quelle (aucun coût).
  static String _sanitize(PdfFont font, String text) {
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
