/// Gabarit PDF flashcards — composition **inline** texte + LaTeX. Arête
/// `syncfusion_flutter_pdf` **CONFINÉE à ce fichier**.
///
/// Produit un PDF imprimable typé d'un dossier entier **ou** d'une sélection
/// de cartes, avec ou sans réponses. Comme les autres backends
/// (`z_pdf_exporter.dart` / `z_pdf_document_builder.dart`), l'import
/// Syncfusion est confiné ici : il n'est JAMAIS réexporté par le barrel, et
/// aucun type `PdfDocument`/`PdfBitmap`/… n'apparaît dans une signature
/// publique. Entrée = [ZFlashcardPdfInput] **neutre** ; sortie =
/// [ZExportedFile] **neutre** (bytes `%PDF-`) → fuite de type
/// structurellement impossible (invariant AD-1).
///
/// **Pur** : ce fichier n'importe NI `printing`, NI `flutter_math_fork`,
/// NI `dart:ui` de rendu écran (`RepaintBoundary`/`toImage`/`PictureRecorder`).
/// La rasterisation LaTeX passe par le **port pur** [ZLatexRasterizer] (impl
/// concrète hors package, dans `zcrud_export_ui`). Le gabarit reste exécutable
/// sous `flutter test` **sans plateforme ni pixel réel** (rasterizer = fake/null).
///
/// **Composition inline** : au-delà d'une image par page, ce gabarit compose
/// **texte + bitmap DANS le flux** (`drawString` mot à mot + `drawImage`
/// positionné à la volée). Une formule s'insère DANS le paragraphe ; le texte
/// non-LaTeX reste **extractible** (dessiné en texte).
///
/// **Défensif (invariant AD-10)** : dossier vide → PDF 1 page (titre) ; carte
/// malformée → rendue sans crash ; LaTeX invalide (rasterizer `null`) → repli sur
/// le **texte brut** de la formule ; explication longue → **pagination** ;
/// Unicode/RTL → rendu sans exception. `PdfDocument.dispose()` en `finally` sur
/// TOUS les chemins.
///
/// **Invariant AD-12** : aucune clé/licence Syncfusion committée, aucun `badCertificateCallback`.
library;

import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/z_font_coverage.dart';
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
/// brut de la formule — il ne lève JAMAIS vers l'appelant.
class ZFlashcardPdfTemplate {
  /// Construit le gabarit. [rasterizer] optionnel (repli texte brut si absent) ;
  /// [options] paramètre l'orientation (portrait par défaut).
  const ZFlashcardPdfTemplate({
    this.rasterizer,
    this.options,
    this.fontProvider,
    this.fallbackFontProviders = const <ZPdfFontProvider>[],
  });

  /// Port de rasterisation LaTeX (impl concrète hors package). `null` → repli texte.
  final ZLatexRasterizer? rasterizer;

  /// Port de police **TrueType** — `null` ⇒ police standard
  /// WinAnsi, donc **latin-1 seulement**, et tout caractère hors jeu redevient
  /// `?`. Le fournir suffit à ce que l'arabe, le grec, le cyrillique, le CJK ou
  /// les emoji survivent à l'export.
  ///
  /// Une police seule ne couvre **jamais** toutes les écritures — voir
  /// [fallbackFontProviders], qui lève cette limite.
  final ZPdfFontProvider? fontProvider;

  /// **Chaîne de repli** de polices — consultées dans l'ordre quand
  /// [fontProvider] ne porte pas un caractère.
  ///
  /// **Pourquoi une chaîne, pas une seule police.** Une police unique par
  /// document impose de trouver une fonte qui couvre toutes les écritures
  /// attendues — or **une telle police n'existe pas** dans un bundle
  /// mobile raisonnable — `NotoSans-Regular` porte 2840 glyphes sans l'arabe,
  /// `NotoSansArabic-Regular` en porte 1161 **sans même la lettre `A`**. Les
  /// fontes Noto sont découpées **par écriture**, c'est leur principe de
  /// conception. Sans chaîne de repli, un document mêlant latin et arabe est
  /// donc impossible.
  ///
  /// ```dart
  /// ZFlashcardPdfTemplate(
  ///   fontProvider: NotoSansProvider(),
  ///   fallbackFontProviders: [NotoArabicProvider(), NotoCjkProvider()],
  /// );
  /// ```
  ///
  /// La sélection se fait **par suite de caractères** (`run`) : chaque portion
  /// du texte est dessinée avec la première police de la chaîne qui la porte.
  /// Un caractère que **personne** ne porte devient `?` — une perte **visible**,
  /// jamais un `.notdef` invisible (cf. [ZFontCoverage]).
  ///
  /// Un mot mêlant deux écritures peut être coupé en fin de ligne entre ses
  /// deux portions : le retour à la ligne opère par élément placé.
  final List<ZPdfFontProvider> fallbackFontProviders;

  /// Options de mise en page (orientation). `null` → portrait.
  final ZPdfExportOptions? options;

  // Métriques de rendu (points PDF). Documentées : le gabarit produit des BYTES
  // sans BuildContext (aucune l10n/thème runtime) → constantes documentées, non
  // des couleurs codées en dur évitables.
  static const double _titleSize = 18;
  static const double _headingSize = 12;
  static const double _bodySize = 11;
  static const double _badgeSize = 9;
  static const double _paraGap = 6; // interligne entre blocs

  /// Charge les octets d'UN provider, **sans jamais lever** (AD-10).
  static Future<Uint8List?> _loadOne(ZPdfFontProvider provider) async {
    try {
      final bytes = await provider.loadFont();
      return (bytes == null || bytes.isEmpty) ? null : bytes;
    } on Object {
      // Un provider défaillant ne doit pas coûter l'export entier : on dégrade,
      // comme s'il n'avait pas été fourni.
      return null;
    }
  }

  /// Charge la chaîne complète : [fontProvider] d'abord, puis les replis dans
  /// l'ordre déclaré. Les providers absents/défaillants sont simplement omis —
  /// une chaîne vide ramène au comportement standard WinAnsi.
  Future<List<Uint8List>> _loadFontChain() async {
    final out = <Uint8List>[];
    final primary = fontProvider;
    if (primary != null) {
      final b = await _loadOne(primary);
      if (b != null) out.add(b);
    }
    for (final p in fallbackFontProviders) {
      final b = await _loadOne(p);
      if (b != null) out.add(b);
    }
    return out;
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
    // Octets de police chargés UNE fois, défensivement. Un provider
    // absent, rendant `null`, ou levant ⇒ repli sur la police standard : le
    // rendu fonctionne toujours, il redevient borné au latin-1.
    final chain = _FontChain(await _loadFontChain());

    final document = PdfDocument();
    try {
      final landscape = (options ?? const ZPdfExportOptions()).orientation ==
          ZPdfOrientation.landscape;
      if (landscape) {
        document.pageSettings.orientation = PdfPageOrientation.landscape;
      }

      final flow = _Flow(document, chain);
      flow.newPage();

      // Titre (toujours présent, même dossier vide → PDF 1 page jamais 0-page).
      const titleFont = _FontRef(_titleSize, PdfFontStyle.bold);
      // Le repli de titre est une clé l10n de l'hôte, jamais un texte figé.
      flow.drawText(
        input.title.isEmpty ? input.labels.untitledLabel : input.title,
        titleFont,
      );
      flow.newParagraph(_paraGap);

      final n = input.cards.length;
      for (var i = 0; i < n; i++) {
        _renderCard(
            flow, input, input.cards[i], i + 1, n, answerVisibility, bitmaps);
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
      // L'indice est rendu dans LES DEUX modes — ses formules doivent donc
      // être pré-rasterisées inconditionnellement.
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
  ) {
    const headingFont = _FontRef(_headingSize, PdfFontStyle.bold);
    const bodyFont = _FontRef(_bodySize);
    const bodyBold = _FontRef(_bodySize, PdfFontStyle.bold);
    const badgeFont = _FontRef(_badgeSize);
    // Hauteur de ligne : métrique de la police PRIMAIRE (les replis ont des
    // métriques proches ; mélanger les hauteurs ferait sauter l'interligne).
    final bodyH = flow.chain.primary(bodyFont).height;

    // Numérotation (heading) — table unique, surchargeable par l'hôte via ses
    // libellés. Un patron vide supprime la numérotation, ce qui est un choix
    // d'hôte légitime.
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
        flow.newLine(bodyH);
        if (visibility == ZAnswerVisibility.withAnswers) {
          if (ch.isCorrect) {
            flow.drawCheck(bodyH);
          } else {
            flow.drawCross(bodyH);
          }
        } else {
          flow.drawEmptyBox(bodyH);
        }
        _drawInline(flow, ch.content, bodyFont, bitmaps);
      }
      flow.newParagraph(_paraGap / 2);
    }

    // INDICE, rendu HORS du bloc réponse : il reste visible en
    // `withoutAnswers`, qui est le mode RÉVISION, celui où un indice sert le
    // plus. Le masquer avec la réponse en ferait un doublon de l'explication.
    final hint = card.hint;
    if (hint != null && hint.isNotEmpty) {
      flow.newLine(bodyH);
      flow.drawText('${input.labels.hintLabel} : ', bodyBold);
      _drawInline(flow, hint, bodyFont, bitmaps);
      flow.newParagraph(_paraGap / 2);
    }

    if (visibility == ZAnswerVisibility.withAnswers) {
      // Vrai/Faux.
      if (card.isTrue != null) {
        flow.newLine(bodyH);
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
        flow.newLine(bodyH);
        flow.drawText('${input.labels.answerLabel} : ', bodyBold);
        _drawInline(flow, answer, bodyFont, bitmaps);
        flow.newParagraph(_paraGap / 2);
      }
      // Explication (paginée si longue).
      final explanation = card.explanation;
      if (explanation != null && explanation.isNotEmpty) {
        flow.newLine(bodyH);
        flow.drawText('${input.labels.explanationLabel} : ', bodyBold);
        _drawInline(flow, explanation, bodyFont, bitmaps);
        flow.newParagraph(_paraGap / 2);
      }
    }

    flow.newParagraph(_paraGap);
  }

  /// Écrit [text] en composant texte + LaTeX INLINE : les segments `$...$` sont
  /// rasterisés (bitmap), les autres dessinés en texte (extractible). Repli sur
  /// le texte brut de la source LaTeX si son bitmap est absent.
  void _drawInline(
    _Flow flow,
    String text,
    _FontRef font,
    Map<String, PdfBitmap?> bitmaps,
  ) {
    final h = flow.chain.primary(font).height;
    for (final seg in _tokenize(text, latexEnabled: _latexEnabled)) {
      if (seg.isLatex) {
        final bmp = bitmaps[seg.source];
        if (bmp != null) {
          flow.drawInlineBitmap(bmp, h);
        } else {
          // Repli défensif : on réémet le texte SOURCE, DÉLIMITEURS COMPRIS.
          // Peindre le contenu nu ferait disparaître les `$` du document, et
          // avec eux le sens (« 100 $ US » → « 100  US »). Le repli ne doit
          // rien coûter.
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

  /// Interprétation LaTeX active — `ZPdfExportOptions.latexEnabled`.
  bool get _latexEnabled => (options ?? const ZPdfExportOptions()).latexEnabled;

  /// Découpe [text] en segments alternés texte / LaTeX sur le délimiteur `$`.
  ///
  /// **Invariant sans perte** : la concaténation des [_Seg.raw]
  /// reconstitue [text] **caractère pour caractère**. C'est ce qui garantit qu'un
  /// `$` — délimiteur apparié, délimiteur orphelin, ou simple symbole monétaire —
  /// ne peut plus s'évaporer du document. Un découpage naïf sur le seul
  /// caractère `$`, sans réémission des délimiteurs, violerait cet invariant
  /// en silence. Un test le vérifie sur un corpus.
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
  /// générateur de bytes → constante documentée, non couleur codée en dur
  /// évitable.
  static final PdfColor _correctColor = PdfColor(27, 128, 62);

  /// Couleur documentée « incorrect » (rouge).
  static final PdfColor _incorrectColor = PdfColor(192, 40, 40);
}

/// Descripteur de police **indépendant des octets** : taille + style. Le choix
/// de la fonte réelle est différé au dessin, caractère par caractère.
class _FontRef {
  const _FontRef(this.size, [this.style]);
  final double size;
  final PdfFontStyle? style;
}

/// Chaîne de polices : les octets, leur couverture `cmap`, et le cache des
/// `PdfFont` construits.
///
/// **Pourquoi un cache** : `PdfTrueTypeFont` est coûteux à construire, et le
/// gabarit en demande plusieurs par carte. Sans cache, un document de
/// 200 cartes reconstruirait des centaines de fois les mêmes polices.
class _FontChain {
  _FontChain(this._bytes);

  final List<Uint8List> _bytes;
  final Map<int, ZFontCoverage?> _coverages = <int, ZFontCoverage?>{};
  final Map<String, PdfFont> _cache = <String, PdfFont>{};

  /// Couverture de la police [i], `null` si illisible (⇒ traitée en **optimiste**
  /// : on ne prive pas l'hôte d'une police au motif qu'on n'a pas su la lire).
  ZFontCoverage? _coverage(int i) =>
      _coverages.putIfAbsent(i, () => ZFontCoverage.parse(_bytes[i]));

  /// Index de la première police portant [codePoint], ou `-1` si aucune.
  ///
  /// Une police dont le `cmap` est illisible est **éligible** : sans cela, une
  /// police valide mais exotique serait écartée en silence, ce qui priverait
  /// l'hôte d'une police fournie explicitement.
  int indexFor(int codePoint) {
    if (ZFontCoverage.isLayoutCodePoint(codePoint)) return 0;
    for (var i = 0; i < _bytes.length; i++) {
      final c = _coverage(i);
      if (c == null || c.covers(codePoint)) return i;
    }
    return -1;
  }

  /// Police construite pour l'index [i] (`-1`/hors chaîne ⇒ standard WinAnsi).
  /// Un `PdfTrueTypeFont` invalide retombe sur le standard — jamais d'export
  /// perdu (invariant AD-10).
  PdfFont fontAt(int i, _FontRef ref) {
    final key = '$i|${ref.size}|${ref.style}';
    final hit = _cache[key];
    if (hit != null) return hit;
    PdfFont built;
    if (i >= 0 && i < _bytes.length) {
      try {
        built = PdfTrueTypeFont(_bytes[i], ref.size, style: ref.style);
      } on Object {
        built = PdfStandardFont(PdfFontFamily.helvetica, ref.size,
            style: ref.style);
      }
    } else {
      built =
          PdfStandardFont(PdfFontFamily.helvetica, ref.size, style: ref.style);
    }
    return _cache[key] = built;
  }

  /// Police de référence pour les MÉTRIQUES (hauteur de ligne, gabarits) : la
  /// première de la chaîne, sinon la standard.
  PdfFont primary(_FontRef ref) => fontAt(_bytes.isEmpty ? -1 : 0, ref);

  /// Découpe [text] en **suites de caractères servies par la même police**.
  ///
  /// Un caractère qu'AUCUNE police ne porte est remplacé par `?` et rattaché à
  /// la suite de la police primaire : la perte redevient **visible**. Avec une
  /// police TrueType, `measureString` **ne lève jamais** sur un caractère non
  /// couvert : sans cette substitution explicite, le non-couvert deviendrait
  /// un `.notdef` silencieux, c'est-à-dire une case vide indiscernable d'une
  /// mise en page.
  List<_Run> runs(String text) {
    // Sans chaîne TrueType, rien à sélectionner ni à substituer ici : c'est
    // `_sanitize` (qui discrimine, lui, sur une police standard) qui opère.
    if (_bytes.isEmpty) return <_Run>[_Run(-1, text)];
    final out = <_Run>[];
    final buf = StringBuffer();
    var current = -2; // -2 = aucun run ouvert
    for (final r in text.runes) {
      var idx = indexFor(r);
      var ch = String.fromCharCode(r);
      if (idx < 0) {
        idx = _bytes.isEmpty ? -1 : 0;
        ch = '?'; // Perte VISIBLE, jamais un .notdef muet.
      }
      if (idx != current && buf.isNotEmpty) {
        out.add(_Run(current, buf.toString()));
        buf.clear();
      }
      current = idx;
      buf.write(ch);
    }
    if (buf.isNotEmpty) out.add(_Run(current, buf.toString()));
    return out;
  }
}

/// Une suite de caractères dessinée d'un seul trait, avec une seule police.
class _Run {
  const _Run(this.fontIndex, this.text);
  final int fontIndex;
  final String text;
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
  /// le texte d'origine à l'identique.
  final String raw;
}

/// Moteur de **flux** : place mots et bitmaps en ligne, retourne à la ligne et
/// pagine automatiquement. `syncfusion_flutter_pdf` confiné au fichier parent.
class _Flow {
  _Flow(this._document, this.chain);

  final PdfDocument _document;

  /// Chaîne de polices — la fonte réelle est choisie au dessin.
  final _FontChain chain;
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
  /// **Les sauts de ligne ne doivent jamais être une perte silencieuse.** Un
  /// découpage qui ne porterait que sur l'espace enverrait un mot contenant
  /// `\n` en **un seul** `drawString` dans un `Rect` d'**une** hauteur de
  /// ligne : tout ce qui suit le saut sortirait du rectangle — jamais rendu,
  /// sans exception ni compteur, le PDF restant valide et **amputé**. Un saut
  /// de ligne est donc traité comme un **vrai retour à la ligne**.
  ///
  /// Défensif (invariant AD-10) : les polices STANDARD (WinAnsi) ne portent
  /// PAS tous les glyphes Unicode (arabe/CJK/emoji…) et
  /// `measureString`/`drawString` **lèveraient** sur un caractère non
  /// supporté. Chaque ligne est donc [_sanitize]é (les glyphes hors police →
  /// `?`) — le rendu ne throw JAMAIS (le shaping RTL/complexe complet exige
  /// une police TrueType, cf. `ZPdfFontProvider`).
  void drawText(String rawText, _FontRef ref, {PdfColor? color}) {
    if (rawText.isEmpty) return;
    final font = chain.primary(ref);
    final lines = rawText.split(_lineBreaks);
    for (var i = 0; i < lines.length; i++) {
      // Toute ligne SAUF la première ouvre un nouveau retour chariot. La
      // première ne le fait pas : `drawText` est aussi appelé EN COURS de ligne
      // (« Réponse : » puis le contenu) — la composition inline doit tenir.
      if (i > 0) newLine(font.height);
      _drawSingleLine(lines[i], ref, color: color);
    }
  }

  /// Dessine UNE ligne (garantie sans rupture) mot à mot.
  ///
  /// La tabulation n'est **pas** transformée, et c'est un choix MESURÉ, pas un
  /// oubli. L'extraction du PDF montre que `\t` ne perd **rien** —
  /// `'AAA\tBBB'` ressort `AAA    BBB`, intact ; la perte venait entièrement
  /// du `\n`. Une expansion en espaces serait donc du code qu'aucun test ne
  /// peut distinguer de son absence — un signe qu'elle n'a pas sa place ici.
  void _drawSingleLine(String rawLine, _FontRef ref, {PdfColor? color}) {
    if (rawLine.isEmpty) return;
    final primary = chain.primary(ref);
    final text = _sanitize(primary, rawLine);
    if (text.isEmpty) return;
    final brush = color == null ? null : PdfSolidBrush(color);
    final spaceW = _measure(primary, ' ');
    final words = text.split(RegExp(r'(?<= )|(?= )')); // conserve les espaces
    for (final token in words) {
      if (token.isEmpty) continue;
      if (token == ' ') {
        // Espace : avance sans peindre (sauf en début de ligne où on l'ignore).
        if (_x > 0) _x += spaceW;
        continue;
      }
      // Un mot peut mêler deux écritures — il est découpé en suites
      // servies par une même police, chacune peinte avec la sienne.
      for (final run in chain.runs(token)) {
        final f = chain.fontAt(run.fontIndex, ref);
        final w = _measure(f, run.text);
        final h = f.height;
        _place(w, h, (x, y) {
          _page.graphics.drawString(
            run.text,
            f,
            brush: brush,
            bounds: Rect.fromLTWH(x, y, w <= 0 ? _contentW : w, h),
          );
        });
      }
    }
  }

  /// Dessine un badge : texte encadré d'un rectangle de fond léger (bloc).
  ///
  /// Le badge est exposé au **même risque d'amputation** que [drawText] : un
  /// libellé multi-ligne peint dans un rectangle d'une seule hauteur de ligne
  /// verrait sa suite disparaître.
  ///
  /// Un badge est par construction un **encadré d'une ligne** : plutôt que
  /// d'inventer un encadré multi-ligne, les blancs sont **aplatis** (`\s+` → un
  /// espace). Aucun mot n'est retiré — c'est une perte de mise en forme, pas de
  /// contenu, et elle est visible dans le document.
  void drawBadge(String rawText, _FontRef ref) {
    final font = chain.primary(ref);
    final flattened = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Le badge est un encadré d'UNE ligne : on ne compose pas plusieurs polices
    // dedans, mais les non-couverts deviennent `?` (visible) et non `.notdef`.
    final text = chain.runs(_sanitize(font, flattened)).map((r) => r.text).join();
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
