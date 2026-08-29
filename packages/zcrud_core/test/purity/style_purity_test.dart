// AC6/AC7 (FR-26, AD-13) : garde « aucun style codé en dur » + « directionnel
// uniquement » sur `lib/src/presentation/**`.
//
// (a) COULEURS : échoue sur tout littéral de couleur — `Color(0x…)`,
//     `Color(<décimal>)`, `Color.fromARGB(`, `Color.fromRGBO(`,
//     `Color.from(red: <littéral>)`, `Colors.<x>`, littéral hexadécimal de
//     couleur hors `Color(`, entier décimal dans la plage ARGB opaque — et sur
//     les constantes de style
//     interdites (`kNavyColor`/`kFormInputDecorationTheme`). Le repli
//     `ZcrudTheme.fallback` est EXEMPTÉ (il ne fait que DÉRIVER `ColorScheme`/
//     `TextTheme`, sans littéral) — l'exemption est bornée à son corps de
//     factory par comptage d'accolades.
//     Les FICHIERS DE RÉFÉRENCE COULEUR audités (patron FR-26 encadré) sont
//     exemptés NOMINATIVEMENT PAR CHEMIN EXACT (`_kColorReferenceFiles`), et
//     eux seuls : l'exemption ne suit ni le contenu, ni le nom de fichier, ni
//     un répertoire. Trois contre-preuves la tiennent : un chemin exempté qui
//     n'existe pas rougit, un chemin exempté SANS littéral de couleur rougit
//     (exemption inutile), et le MÊME CONTENU placé sous un autre chemin
//     rougit.
// (b) DIRECTIONNEL : échoue sur toute variante NON directionnelle
//     (`EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`/`topLeft/Right`/
//     `bottomLeft/Right`, `TextAlign.left/right`, `Positioned(left/right`).
//
// Réutilise le pattern `_stripComment` des purity-tests E2-7 (scan hors
// commentaires). Test pur-fichiers (`package:test`) tournant sous `flutter test`.
import 'dart:io';

import 'package:test/test.dart';

/// Motifs de littéral de couleur / constante de style INTERDITS, appliqués
/// **ligne à ligne** (regex).
///
/// Couvre `Color(0x…)`, `Color.fromARGB(`, `Color.fromRGBO(`, `Colors.<nom>`,
/// et les constantes hexadécimales de couleur écrites **hors** de `Color(` —
/// forme `0xRRGGBB` (6 chiffres), `0xFxxxxxxx` (8 chiffres à alpha `F…`) et
/// `0x80RRGGBB` (alpha 50 %).
///
/// ⚠️ Renoncement DOCUMENTÉ sur l'hexadécimal : un entier hexadécimal de 8
/// chiffres dont l'octet de tête n'est ni `F…` ni `80` n'est PAS distinguable
/// textuellement d'un masque de bits ou d'une constante de hachage — deux
/// usages légitimes qui vivent dans `lib/src/presentation/` (`0x00FFFFFF`
/// comme masque RGB, `0x811C9DC5`/`0x01000193` comme graines FNV). Élargir à
/// `0x[0-9a-fA-F]{8}` produirait des faux positifs sur du code correct : la
/// garde préfère laisser ce coin non couvert plutôt que devenir désactivable.
// Les motifs sont volontairement dupliqués entre familles plutôt que fondus en
// une regex unique : un offender doit nommer la FORME qui a mordu.
final _colorPatterns = <RegExp>[
  RegExp(r'Color\(\s*0x'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'\bColors\.'),
  RegExp(r'\b0x(?:[0-9a-fA-F]{6}|[fF][0-9a-fA-F]{7}|80[0-9a-fA-F]{6})\b'),
  RegExp(r'\bkNavyColor\b'),
  RegExp(r'\bkFormInputDecorationTheme\b'),
];

/// Motifs de littéral de couleur appliqués au **contenu joint** du fichier
/// (lignes hors commentaires et hors corps exempté), donc capables de
/// traverser les sauts de ligne.
///
/// Trois formes que le scan ligne à ligne laissait passer :
/// 1. `Color(<entier DÉCIMAL>)` — la même couleur que `Color(0xFF…)`, écrite
///    en base 10 (`Color(4280391411)`), mono ou multi-ligne ;
/// 2. `Color.from(` dont **au moins une composante** `red`/`green`/`blue` est
///    un littéral numérique — la dérivation à composantes CALCULÉES reste
///    permise (c'est la voie légitime de composition/éclaircissement) ;
/// 3. un entier décimal nu dans la plage ARGB opaque
///    (`0xFF000000` = 4278190080 … `0xFFFFFFFF` = 4294967295), qui n'a
///    pratiquement aucun autre usage qu'une couleur codée en dur.
final _colorContentPatterns = <RegExp>[
  RegExp(r'\bColor\(\s*[0-9][0-9_]*\s*[,)]'),
  RegExp(r'\bColor\.from\([^)]*\b(?:red|green|blue)\s*:\s*[0-9]*\.?[0-9]+\s*[,)]'),
  RegExp(r'\b42[789][0-9]{7}\b'),
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

/// Fichiers de RÉFÉRENCE COULEUR audités, exemptés **nominativement**.
///
/// Chemins relatifs à la racine du package, comparés à l'octet près après
/// normalisation des séparateurs. Un fichier n'entre ici qu'à trois
/// conditions (exception FR-26 encadrée) : il est l'UNIQUE fichier de
/// référence de sa famille, ses valeurs sont remplaçables par thème et par
/// paramètre, et l'exemption le nomme — jamais son répertoire.
const Set<String> _kColorReferenceFiles = <String>{
  'lib/src/presentation/theme/z_signature_palette_reference.dart',
  // Famille « indicateur d'occupation » : les 7 teintes du cycle
  // « génération en cours », remplaçables par jeton `ZcrudTheme.busyPalette`
  // et neutralisables par `ZReferenceProfile.neutral`.
  'lib/src/presentation/theme/z_busy_palette_reference.dart',
};

/// Chemin normalisé et ancré sur `lib/` — `packages/zcrud_core/lib/x` et
/// `lib/x` rendent la même chaîne, quel que soit le répertoire de lancement.
String _normalized(String path) {
  final String p = path.replaceAll(r'\', '/');
  final int i = p.indexOf('lib/src/presentation/');
  return i < 0 ? p : p.substring(i);
}

/// Détecte les littéraux de couleur de [lines] comme s'ils vivaient sous
/// [path]. Extrait pour que les contre-preuves puissent rejouer EXACTEMENT le
/// même scan sous un autre chemin.
List<String> _scanColors(String path, List<String> lines) {
  final offenders = <String>[];
  if (_kColorReferenceFiles.contains(_normalized(path))) return offenders;
  final st = _FallbackState();
  final code = <String>[];
  var lineNo = 0;
  for (final raw in lines) {
    lineNo++;
    final exempt = _inFallback(path, raw, st);
    final line = _stripComment(raw);
    // Le contenu joint ne retient que le CODE non exempté : une forme
    // multi-ligne ne peut donc pas se reconstituer à cheval sur le corps
    // exempté de `ZcrudTheme.fallback`.
    code.add(exempt ? '' : line);
    for (final pat in _colorPatterns) {
      if (pat.hasMatch(line) && !exempt) {
        offenders.add('$path:$lineNo: ${pat.pattern} → ${line.trim()}');
      }
    }
  }
  final String joined = code.join('\n');
  for (final pat in _colorContentPatterns) {
    if (pat.hasMatch(joined)) {
      offenders.add('$path: ${pat.pattern} → ${pat.firstMatch(joined)![0]}');
    }
  }
  return offenders;
}

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
      offenders.addAll(_scanColors(file.path, file.readAsLinesSync()));
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

  test('L-4 : la garde couleur détecte les formes INVISIBLES au scan ligne à '
      'ligne (décimal, Color.from littéral, hex hors Color()', () {
    // Une forme est « attrapée » si le scan complet (ligne + contenu joint)
    // la reporte sous un chemin NON exempté — c'est exactement ce que fait la
    // garde sur un vrai fichier.
    List<String> scan(String source) => _scanColors(
          'lib/src/presentation/theme/_sonde_forme.dart',
          source.split('\n'),
        );

    const Map<String, String> mordantes = <String, String>{
      'décimal': 'const Color c = Color(4280391411);',
      'décimal multi-ligne': 'const Color c = Color(\n  4280391411,\n);',
      'Color.from littéral': 'const Color c = '
          'Color.from(alpha: 1, red: 0.2, green: 0.4, blue: 0.6);',
      'hex RGB hors Color(': 'const int c = 0x2196F3;',
      'hex ARGB alpha 50 % hors Color(': 'const int c = 0x80112233;',
      'grand entier décimal': 'const int c = 4280391411;',
      // Formes déjà couvertes : elles doivent le RESTER.
      'Color(0x…)': 'const Color c = Color(0xFF112233);',
      'Colors.<nom>': 'final Color c = Colors.red;',
      'fromARGB': 'const Color c = Color.fromARGB(255, 10, 20, 30);',
      'fromRGBO': 'const Color c = Color.fromRGBO(10, 20, 30, 1.0);',
    };
    for (final MapEntry<String, String> e in mordantes.entries) {
      expect(scan(e.value), isNotEmpty,
          reason: '🔴 forme NON attrapée (${e.key}) : ${e.value}');
    }

    // Contre-preuves : trois usages LÉGITIMES présents dans
    // `lib/src/presentation/` doivent rester silencieux — sinon la garde
    // devient un générateur de faux positifs, donc une garde qu'on désactive.
    const Map<String, String> legitimes = <String, String>{
      'masque RGB': 'final int rgb = argb & 0x00FFFFFF;',
      'graine FNV': 'int hash = 0x811C9DC5;',
      'graine FNV (multiplicateur)': 'hash = (hash * 0x01000193).toUnsigned(32);',
      'Color.from calculé': 'Color f(Color c) => '
          'Color.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);',
      'Color.from composé': 'Color f(Color a, Color b) => Color.from(\n'
          '  alpha: 1,\n  red: a.r * t + b.r * (1 - t),\n'
          '  green: a.g * t + b.g * (1 - t),\n  blue: a.b * t + b.b * (1 - t),\n);',
      'décalage alpha': 'return (a << 24) | (rgb.toARGB32() & 0x00FFFFFF);',
      'octets de signature PNG': 'const List<int> sig = <int>[0x89, 0x50, 0x4E];',
    };
    for (final MapEntry<String, String> e in legitimes.entries) {
      expect(scan(e.value), isEmpty,
          reason: '🔴 FAUX POSITIF (${e.key}) : ${e.value}');
    }
  });

  // ── Contre-preuves de l'EXEMPTION NOMINATIVE ──────────────────────────────
  // Une exemption par chemin est une porte ouverte : ces trois tests prouvent
  // qu'elle est étroite, utile, et attachée au CHEMIN et non au contenu.

  test('exemption nominative ① : chaque chemin exempté EXISTE sur disque', () {
    final Directory dir = _presentationDir();
    final Set<String> present =
        _dartFiles(dir).map((f) => _normalized(f.path)).toSet();
    final List<String> fantomes = _kColorReferenceFiles
        .where((String p) => !present.contains(p))
        .toList();
    expect(fantomes, isEmpty,
        reason: '🔴 exemption FANTÔME : $fantomes — un chemin exempté qui '
            "n'existe plus laisse la porte ouverte pour un futur fichier "
            'portant ce nom. Retirez-le.');
  });

  test('exemption nominative ② : chaque fichier exempté PORTE bien des '
      'littéraux de couleur (exemption inutile ⇒ rouge)', () {
    final Directory dir = _presentationDir();
    final Map<String, File> parChemin = <String, File>{
      for (final f in _dartFiles(dir)) _normalized(f.path): f,
    };
    final List<String> inutiles = <String>[];
    for (final String exempte in _kColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue; // couvert par la contre-preuve ①
      // Rejoue le scan sous un chemin NON exempté : compte les littéraux
      // réels. Le chemin de sonde doit rester sous `lib/src/presentation/`
      // (sinon `_inFallback` et la normalisation ne se comportent pas pareil)
      // tout en étant absent de la liste d'exemption.
      final int trouves = _scanColors(
        'lib/src/presentation/theme/_sonde_exemption_inutile.dart',
        f.readAsLinesSync(),
      ).length;
      if (trouves == 0) inutiles.add(exempte);
    }
    expect(inutiles, isEmpty,
        reason: '🔴 exemption INUTILE : $inutiles — ces fichiers ne portent '
            'aucun littéral de couleur, leur exemption ne protège rien et '
            'masquerait un littéral futur. Retirez-la.');
  });

  test('exemption nominative ③ : le MÊME CONTENU sous un autre chemin est '
      'REFUSÉ (exemption attachée au chemin, pas au contenu)', () {
    final Directory dir = _presentationDir();
    final Map<String, File> parChemin = <String, File>{
      for (final f in _dartFiles(dir)) _normalized(f.path): f,
    };
    for (final String exempte in _kColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue;
      final List<String> lignes = f.readAsLinesSync();
      // Le contenu EXACT du fichier exempté, présenté sous un chemin voisin.
      final String imposteur =
          'lib/src/presentation/theme/z_signature_palette_copie.dart';
      expect(_scanColors(imposteur, lignes), isNotEmpty,
          reason: "🔴 l'exemption a suivi le CONTENU : une copie de $exempte "
              'placée en $imposteur passerait la garde.');
      // Et le chemin exempté, lui, reste silencieux — sinon l'exemption ne
      // fonctionne pas du tout et le test ① serait le seul à le dire.
      expect(_scanColors(exempte, lignes), isEmpty,
          reason: "l'exemption nominative de $exempte ne s'applique pas");
    }
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
