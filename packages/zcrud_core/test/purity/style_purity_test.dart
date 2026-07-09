// AC6/AC7 (FR-26, AD-13) : garde « aucun style codé en dur » + « directionnel
// uniquement » sur `lib/src/presentation/**`.
//
// (a) COULEURS : échoue sur tout littéral de couleur (`Color(0x…)`, `Colors.<x>`,
//     littéral hexadécimal `0x[fF]{6,8}`) et sur les constantes de style
//     interdites (`kNavyColor`/`kFormInputDecorationTheme`). Le repli
//     `ZcrudTheme.fallback` est EXEMPTÉ (il ne fait que DÉRIVER `ColorScheme`/
//     `TextTheme`, sans littéral) — l'exemption est bornée à son corps de
//     factory par comptage d'accolades.
// (b) DIRECTIONNEL : échoue sur toute variante NON directionnelle
//     (`EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`/`topLeft/Right`/
//     `bottomLeft/Right`, `TextAlign.left/right`, `Positioned(left/right`).
//
// Réutilise le pattern `_stripComment` des purity-tests E2-7 (scan hors
// commentaires). Test pur-fichiers (`package:test`) tournant sous `flutter test`.
import 'dart:io';

import 'package:test/test.dart';

/// Motifs de littéral de couleur / constante de style INTERDITS (regex).
///
/// L-2 : couvre aussi `Color.fromARGB(`/`Color.fromRGBO(` (littéraux de couleur
/// construits par composantes) — un futur codage en dur ARGB/RGBO ne doit plus
/// passer sous la garde.
final _colorPatterns = <RegExp>[
  RegExp(r'Color\(\s*0x'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'\bColors\.'),
  RegExp(r'\b0x[fF][0-9a-fA-F]{5,7}\b'),
  RegExp(r'\bkNavyColor\b'),
  RegExp(r'\bkFormInputDecorationTheme\b'),
];

/// Motifs de variante NON directionnelle INTERDITS (AD-13).
///
/// L-3 : scan désormais appliqué au **contenu entier du fichier** (lignes jointes
/// hors commentaires) — `[^)]*` traverse les sauts de ligne, donc les appels
/// **multi-lignes** (`EdgeInsets.only(\n  left: 8,\n)`, `Positioned(\n  left: …`)
/// sont attrapés. Ajout des variantes non-directionnelles `EdgeInsets.fromLTRB(`,
/// `BorderRadius.only(`, `BorderRadius.horizontal(`.
final _directionalPatterns = <RegExp>[
  RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
  RegExp(r'EdgeInsets\.fromLTRB\('),
  RegExp(r'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b'),
  RegExp(r'TextAlign\.(left|right)\b'),
  RegExp(r'Positioned\([^)]*\b(left|right)\s*:'),
  RegExp(r'BorderRadius\.only\('),
  RegExp(r'BorderRadius\.horizontal\('),
];

Directory _presentationDir() {
  for (final base in <String>['', 'packages/zcrud_core/']) {
    final dir = Directory('${base}lib/src/presentation');
    if (dir.existsSync()) return dir;
  }
  fail('lib/src/presentation introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Retire la partie commentaire (`//` et `///`) — les checks ciblent le CODE.
String _stripComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// `true` si la ligne appartient au corps de la factory `ZcrudTheme.fallback`
/// (exemption couleur : dérivation pure de `ColorScheme`). Met à jour [depth].
///
/// Comptage d'accolades : on entre à la ligne `factory ZcrudTheme.fallback`, on
/// sort quand la profoncdeur relative retombe à 0.
bool _inFallback(String path, String line, _FallbackState st) {
  if (!path.endsWith('z_theme.dart')) return false;
  final code = _stripComment(line);
  if (!st.inside && code.contains('factory ZcrudTheme.fallback')) {
    st.inside = true;
    st.depth = 0;
  }
  if (!st.inside) return false;
  st.depth += '{'.allMatches(code).length - '}'.allMatches(code).length;
  final wasInside = st.inside;
  if (st.depth <= 0 && (code.contains('}') || code.contains(';'))) {
    st.inside = false;
  }
  return wasInside;
}

class _FallbackState {
  bool inside = false;
  int depth = 0;
}

void main() {
  test('aucun littéral de couleur / style codé en dur (AC6/FR-26)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_presentationDir())) {
      final st = _FallbackState();
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final exempt = _inFallback(file.path, raw, st);
        final line = _stripComment(raw);
        for (final pat in _colorPatterns) {
          if (pat.hasMatch(line) && !exempt) {
            offenders.add('${file.path}:$lineNo: ${pat.pattern} → ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Style codé en dur interdit (FR-26) :\n${offenders.join('\n')}');
  });

  test('variantes directionnelles uniquement (AC7/AD-13)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_presentationDir())) {
      // L-3 : reconstruit le contenu HORS commentaires, lignes jointes → un
      // appel multi-lignes reste analysable (`[^)]*` traverse les `\n`).
      final content = file.readAsLinesSync().map(_stripComment).join('\n');
      for (final pat in _directionalPatterns) {
        if (pat.hasMatch(content)) {
          offenders.add('${file.path}: ${pat.pattern}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Variante non directionnelle interdite (AD-13) :\n'
            '${offenders.join('\n')}');
  });

  // ── Auto-vérifications des gardes durcies (L-2 / L-3) ─────────────────────
  // Prouvent que les motifs ajoutés DÉTECTENT bien une violation-échantillon.
  // Les échantillons vivent dans des chaînes de test (jamais au top-level d'un
  // fichier lib scanné par un vrai gate).

  test('L-2 : la garde couleur détecte Color.fromARGB / Color.fromRGBO', () {
    const argbSample = 'final c = Color.fromARGB(255, 10, 20, 30);';
    const rgboSample = 'final c = Color.fromRGBO(10, 20, 30, 1.0);';
    expect(_colorPatterns.any((p) => p.hasMatch(argbSample)), isTrue,
        reason: 'Color.fromARGB( devrait être attrapé');
    expect(_colorPatterns.any((p) => p.hasMatch(rgboSample)), isTrue,
        reason: 'Color.fromRGBO( devrait être attrapé');
  });

  test('L-3 : la garde directionnelle détecte le multi-ligne et fromLTRB/'
      'BorderRadius non-directionnels', () {
    // EdgeInsets.only(left:) réparti sur plusieurs lignes.
    const multilineOnly = 'padding: EdgeInsets.only(\n  left: 8,\n  top: 4,\n),';
    // Positioned(left:) multi-ligne.
    const multilinePositioned = 'Positioned(\n  left: 12,\n  child: SizedBox(),\n),';
    const fromLtrb = 'padding: EdgeInsets.fromLTRB(8, 4, 8, 4),';
    const borderOnly = 'borderRadius: BorderRadius.only(topLeft: r),';
    const borderHorizontal = 'borderRadius: BorderRadius.horizontal(left: r),';
    for (final sample in <String>[
      multilineOnly,
      multilinePositioned,
      fromLtrb,
      borderOnly,
      borderHorizontal,
    ]) {
      expect(_directionalPatterns.any((p) => p.hasMatch(sample)), isTrue,
          reason: 'échantillon non détecté : ${sample.replaceAll('\n', r'\n')}');
    }

    // Contre-preuve : les variantes DIRECTIONNELLES ne déclenchent PAS la garde.
    for (final ok in <String>[
      'padding: EdgeInsetsDirectional.only(start: 8),',
      'padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),',
      'PositionedDirectional(\n  start: 12,\n  child: SizedBox(),\n),',
      'borderRadius: BorderRadiusDirectional.only(topStart: r),',
    ]) {
      expect(_directionalPatterns.any((p) => p.hasMatch(ok)), isFalse,
          reason: 'faux positif directionnel sur : ${ok.replaceAll('\n', r'\n')}');
    }
  });
}
