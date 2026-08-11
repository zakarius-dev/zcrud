/// Lecture de la **couverture réelle** d'une police TrueType/OpenType, par sa
/// table `cmap`.
///
/// ## Pourquoi ce code existe
///
/// **`PdfTrueTypeFont.measureString` ne lève JAMAIS** sur un caractère non
/// couvert (vérifié sur l'arabe, le grec, le CJK et les emoji). Or tout filet
/// défensif fondé sur ce `throw` deviendrait un **no-op silencieux** dès
/// qu'une police TrueType est injectée : ce qui n'est pas couvert ne
/// redeviendrait plus un `?` explicite, mais un `.notdef`, une case vide qui
/// passe pour une mise en page.
///
/// Il n'existe aucun autre oracle :
/// - `measureString` ne discrimine pas (ci-dessus) ;
/// - une heuristique de largeur serait une **paraphrase** — vérifié : sur
///   `NotoSansArabic` un `A` absent vaut `2.860`, exactement la chasse d'un
///   glyphe réel ;
/// - `TtfReader` de Syncfusion n'est pas exporté par `pdf.dart`.
///
/// La table `cmap` **est la police elle-même** : c'est l'autorité.
///
/// ## Ce que ce lecteur N'EST PAS
///
/// « Couvert par le `cmap` » ≠ « écrit dans le PDF ». Vérifié sur les 2626
/// points de code déclarés par `NotoSans-Regular` : **`U+FFFD` est EFFACÉ**
/// par `syncfusion_flutter_pdf` lui-même (propriété du moteur, vérifiée sans
/// aucun code zcrud). Un appelant qui refuse sur la seule foi du `cmap`
/// acceptera `U+FFFD` puis le verra disparaître.
library;

import 'dart:typed_data';

/// Couverture en points de code d'une police TrueType, lue dans sa table `cmap`.
///
/// Construite par [ZFontCoverage.parse], qui rend `null` sur des octets
/// illisibles plutôt que de lever (AD-10). Exposée **publiquement** parce qu'un
/// hôte qui doit décider quoi refuser n'a pas à réimplémenter un lecteur de
/// `cmap` : c'est du code de bibliothèque.
///
/// ```dart
/// final c = ZFontCoverage.parse(octetsNoto);
/// c?.covers('م'.runes.first);   // false pour NotoSans-Regular
/// c?.coversAll('Καλημέρα');     // true
/// ```
class ZFontCoverage {
  ZFontCoverage._(this._data, this._subtable, this._format);

  final ByteData _data;
  final int _subtable;
  final int _format;

  /// Cache des réponses — un document répète massivement les mêmes caractères.
  final Map<int, bool> _memo = <int, bool>{};

  /// Lit la couverture des [bytes] d'une police TrueType/OpenType.
  ///
  /// Rend `null` si les octets ne sont pas une police lisible, si aucune
  /// sous-table `cmap` exploitable n'est trouvée, ou à la moindre lecture hors
  /// bornes. **Ne lève jamais** : un `null` dit « je ne sais pas », que
  /// l'appelant doit traiter comme « ne pas prétendre couvrir ».
  static ZFontCoverage? parse(Uint8List bytes) {
    try {
      return _parse(bytes);
    } on Object {
      return null; // AD-10 : police tronquée/corrompue ⇒ aucune affirmation.
    }
  }

  static ZFontCoverage? _parse(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(bytes);

    // Collection TrueType (`ttcf`) : on prend la PREMIÈRE police.
    var base = 0;
    if (data.getUint32(0) == 0x74746366) {
      if (bytes.length < 16) return null;
      base = data.getUint32(12);
      if (base + 12 > bytes.length) return null;
    }

    final numTables = data.getUint16(base + 4);
    var cmap = -1;
    for (var i = 0; i < numTables; i++) {
      final rec = base + 12 + i * 16;
      if (rec + 16 > bytes.length) return null;
      if (data.getUint32(rec) == 0x636D6170) {
        // 'cmap'
        cmap = data.getUint32(rec + 8);
        break;
      }
    }
    if (cmap < 0 || cmap + 4 > bytes.length) return null;

    // Choix de la sous-table, par ORDRE DE PRÉFÉRENCE : format 12 (Unicode
    // complet, hors BMP) avant format 4 (BMP seul). Une police qui porte les
    // deux doit être lue par la plus complète, sinon un emoji « couvert »
    // serait déclaré absent.
    final nSub = data.getUint16(cmap + 2);
    var best = -1;
    var bestFormat = -1;
    var bestScore = -1;
    for (var i = 0; i < nSub; i++) {
      final rec = cmap + 4 + i * 8;
      if (rec + 8 > bytes.length) return null;
      final platform = data.getUint16(rec);
      final encoding = data.getUint16(rec + 2);
      final off = cmap + data.getUint32(rec + 4);
      if (off + 2 > bytes.length) continue;
      final format = data.getUint16(off);
      if (format != 4 && format != 12) continue;
      // (3,10) et (0,4/6) = Unicode complet ; (3,1) et (0,3) = BMP.
      final unicode = (platform == 3 && (encoding == 1 || encoding == 10)) ||
          platform == 0;
      if (!unicode) continue;
      final score = format == 12 ? 2 : 1;
      if (score > bestScore) {
        bestScore = score;
        best = off;
        bestFormat = format;
      }
    }
    if (best < 0) return null;
    return ZFontCoverage._(data, best, bestFormat);
  }

  /// La police porte-t-elle un glyphe pour [codePoint] ?
  ///
  /// Un identifiant de glyphe `0` est `.notdef` — donc **non couvert**, même si
  /// la table le mentionne. C'est toute la nuance : `.notdef` se dessine (une
  /// case vide), il ne lève pas.
  bool covers(int codePoint) =>
      _memo[codePoint] ??= _lookup(codePoint) != 0;

  /// Tous les points de code de [text] sont-ils couverts ?
  ///
  /// Les caractères de **contrôle et d'espacement** (`\n`, `\t`, espace…) sont
  /// exclus du verdict : ils ne sont pas dessinés — c'est le moteur de flux qui
  /// les interprète. Sans cette exclusion, un texte multiligne serait déclaré
  /// non rendable par toute police dont le `cmap` ignore `\n` (c'est le cas de
  /// NotoSans, mesuré).
  bool coversAll(String text) {
    for (final r in text.runes) {
      if (isLayoutCodePoint(r)) continue;
      if (!covers(r)) return false;
    }
    return true;
  }

  /// Points de code de [text] qu'AUCUNE couverture ne porte — le diagnostic
  /// exploitable pour un hôte qui veut dire *quoi* il ne peut pas rendre.
  Set<int> missingIn(String text) {
    final out = <int>{};
    for (final r in text.runes) {
      if (isLayoutCodePoint(r)) continue;
      if (!covers(r)) out.add(r);
    }
    return out;
  }

  /// Le point de code relève-t-il de la **mise en page** (jamais dessiné) ?
  ///
  /// Espaces, tabulation, retours à la ligne, séparateurs Unicode. Exposé parce
  /// qu'un hôte qui construit sa propre garde doit appliquer la MÊME exclusion,
  /// faute de quoi il refusera du contenu parfaitement rendable.
  static bool isLayoutCodePoint(int codePoint) =>
      codePoint == 0x20 ||
      codePoint == 0x09 ||
      codePoint == 0x0A ||
      codePoint == 0x0D ||
      codePoint == 0x0B ||
      codePoint == 0x0C ||
      codePoint == 0x2028 ||
      codePoint == 0x2029;

  /// Identifiant de glyphe pour [c], `0` si absent. Défensif : toute lecture
  /// hors bornes rend `0` (« non couvert ») plutôt que de lever.
  int _lookup(int c) {
    try {
      return _format == 12 ? _lookup12(c) : _lookup4(c);
    } on Object {
      return 0;
    }
  }

  int _lookup4(int c) {
    if (c > 0xFFFF) return 0; // Format 4 = BMP seul, par construction.
    final t = _subtable;
    final segX2 = _data.getUint16(t + 6);
    final segCount = segX2 ~/ 2;
    final endCodes = t + 14;
    final startCodes = endCodes + segX2 + 2; // + reservedPad
    final idDeltas = startCodes + segX2;
    final idRangeOffsets = idDeltas + segX2;

    // Recherche binaire du premier segment dont endCode >= c.
    var lo = 0;
    var hi = segCount - 1;
    var seg = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_data.getUint16(endCodes + mid * 2) >= c) {
        seg = mid;
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    if (seg < 0) return 0;
    if (_data.getUint16(startCodes + seg * 2) > c) return 0;

    final idRangeOffset = _data.getUint16(idRangeOffsets + seg * 2);
    if (idRangeOffset == 0) {
      final delta = _data.getInt16(idDeltas + seg * 2);
      return (c + delta) & 0xFFFF;
    }
    final start = _data.getUint16(startCodes + seg * 2);
    final addr =
        idRangeOffsets + seg * 2 + idRangeOffset + (c - start) * 2;
    if (addr + 2 > _data.lengthInBytes) return 0;
    final g = _data.getUint16(addr);
    if (g == 0) return 0;
    return (g + _data.getInt16(idDeltas + seg * 2)) & 0xFFFF;
  }

  int _lookup12(int c) {
    final t = _subtable;
    final nGroups = _data.getUint32(t + 12);
    var lo = 0;
    var hi = nGroups - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final g = t + 16 + mid * 12;
      final startChar = _data.getUint32(g);
      final endChar = _data.getUint32(g + 4);
      if (c < startChar) {
        hi = mid - 1;
      } else if (c > endChar) {
        lo = mid + 1;
      } else {
        return _data.getUint32(g + 8) + (c - startChar);
      }
    }
    return 0;
  }
}
