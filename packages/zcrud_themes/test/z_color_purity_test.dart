@TestOn('vm')
library;

// Garde de pureté FR-26, LOCALE au paquet.
//
// Pourquoi locale : la garde équivalente de `zcrud_core`
// (`test/purity/style_purity_test.dart`) n'ancre son scan que sur
// `lib/src/presentation` de `zcrud_core` — elle ne verra jamais un fichier
// d'ici. Chaque paquet qui porte des valeurs de couleur porte donc sa propre
// garde, sur le même patron.
//
// Ce que la garde interdit : un littéral de couleur PARTOUT dans `lib/`, sauf
// dans les fichiers de référence audités, nommés un par un par CHEMIN EXACT.
// L'exemption ne suit ni le nom, ni le répertoire, ni le contenu — trois
// contre-preuves le vérifient en rejouant le SCANNER RÉEL, jamais une copie de
// sa logique.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'z_package_root.dart';

/// Motifs de littéral de couleur appliqués **ligne à ligne**.
///
/// Couvre `Color(0x…)`, `Color.fromARGB(`, `Color.fromRGBO(`, `Colors.<nom>`,
/// et l'hexadécimal de couleur écrit **hors** `Color(` sous les trois formes
/// non ambiguës : `0xRRGGBB`, `0xFxxxxxxx` (opaque) et `0x80RRGGBB` (alpha
/// 50 %).
///
/// Renoncement documenté : un hexadécimal de 8 chiffres dont l'octet de tête
/// n'est ni `F…` ni `80` n'est pas distinguable textuellement d'un masque de
/// bits ou d'une graine de hachage. La garde laisse ce coin découvert plutôt
/// que de produire des faux positifs sur du code correct — une garde qui crie
/// à tort est une garde qu'on désactive.
final List<RegExp> _colorPatterns = <RegExp>[
  RegExp(r'Color\(\s*0x'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'\bColors\.'),
  RegExp(r'\b0x(?:[0-9a-fA-F]{6}|[fF][0-9a-fA-F]{7}|80[0-9a-fA-F]{6})\b'),
];

/// Motifs appliqués au **contenu joint** du fichier (lignes de code, hors
/// commentaires), donc capables de traverser un saut de ligne.
///
/// Trois formes qu'un scan ligne à ligne laisse passer :
/// 1. `Color(<entier décimal>)` — la même couleur écrite en base 10, mono ou
///    multi-ligne ;
/// 2. `Color.from(` dont une composante `red`/`green`/`blue` est un littéral
///    numérique — la dérivation à composantes **calculées** reste permise,
///    c'est la voie légitime de composition ;
/// 3. un entier décimal nu dans la plage ARGB opaque (4278190080…4294967295),
///    qui n'a pratiquement aucun autre usage qu'une couleur codée en dur.
final List<RegExp> _colorContentPatterns = <RegExp>[
  RegExp(r'\bColor\(\s*[0-9][0-9_]*\s*[,)]'),
  RegExp(
      r'\bColor\.from\([^)]*\b(?:red|green|blue)\s*:\s*[0-9]*\.?[0-9]+\s*[,)]'),
  RegExp(r'\b42[789][0-9]{7}\b'),
];

/// Fichiers de RÉFÉRENCE COULEUR audités, exemptés **nominativement**.
///
/// Chemins relatifs à la racine du paquet, comparés à l'octet près. Un fichier
/// n'entre ici qu'aux conditions de l'exception FR-26 encadrée : il est
/// l'unique fichier de référence de sa famille, ses valeurs sont remplaçables
/// par thème et par paramètre, et l'exemption le nomme — jamais son
/// répertoire, jamais un motif de nom.
const Set<String> _kColorReferenceFiles = <String>{
  'lib/src/themes/classic/z_classic_card_gradients_reference.dart',
  'lib/src/themes/classic/z_classic_celebration_reference.dart',
  'lib/src/themes/classic/z_classic_srs_palette_reference.dart',
  'lib/src/themes/classic/z_classic_surface_reference.dart',
};

/// Chemin du fichier, relatif à la racine du paquet, séparateurs normalisés.
String _relative(File file) {
  final String root = zThemesPackageRoot().path.replaceAll(r'\', '/');
  final String path = file.path.replaceAll(r'\', '/');
  return path.startsWith('$root/') ? path.substring(root.length + 1) : path;
}

/// Retire la partie commentaire — les motifs ciblent le CODE.
String _stripComment(String line) {
  final int i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// Détecte les littéraux de couleur de [lines] **comme s'ils vivaient sous**
/// [relPath].
///
/// Le chemin est un paramètre, et non lu du disque, pour que les contre-preuves
/// puissent rejouer exactement ce scanner sous un autre chemin.
List<String> zScanColors(String relPath, List<String> lines) {
  final List<String> offenders = <String>[];
  if (_kColorReferenceFiles.contains(relPath)) return offenders;
  final List<String> code = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final String line = _stripComment(lines[i]);
    code.add(line);
    for (final RegExp pat in _colorPatterns) {
      if (pat.hasMatch(line)) {
        offenders.add('$relPath:${i + 1}: ${pat.pattern} → ${line.trim()}');
      }
    }
  }
  final String joined = code.join('\n');
  for (final RegExp pat in _colorContentPatterns) {
    final Match? m = pat.firstMatch(joined);
    if (m != null) offenders.add('$relPath: ${pat.pattern} → ${m[0]}');
  }
  return offenders;
}

void main() {
  test('aucun littéral de couleur hors fichier de référence audité (FR-26)',
      () {
    final List<File> sources = zThemesLibSources();
    expect(sources, isNotEmpty,
        reason: 'lib/ vide : la garde ne mesurerait rien.');

    final List<String> offenders = <String>[];
    for (final File file in sources) {
      offenders.addAll(zScanColors(_relative(file), file.readAsLinesSync()));
    }
    expect(offenders, isEmpty,
        reason: 'Couleur codée en dur hors référence auditée (FR-26) :\n'
            '${offenders.join('\n')}');
  });

  test('le scanner attrape les formes de couleur annoncées', () {
    List<String> scan(String source) =>
        zScanColors('lib/src/_sonde_forme.dart', source.split('\n'));

    const Map<String, String> mordantes = <String, String>{
      'Color(0x…)': 'const Color c = Color(0xFF112233);',
      'Colors.<nom>': 'final Color c = Colors.red;',
      'fromARGB': 'const Color c = Color.fromARGB(255, 10, 20, 30);',
      'fromRGBO': 'const Color c = Color.fromRGBO(10, 20, 30, 1.0);',
      'hex RGB hors Color(': 'const int c = 0x2196F3;',
      'hex ARGB opaque hors Color(': 'const int c = 0xFF112233;',
      'hex ARGB alpha 50 % hors Color(': 'const int c = 0x80112233;',
      'décimal': 'const Color c = Color(4280391411);',
      'décimal multi-ligne': 'const Color c = Color(\n  4280391411,\n);',
      'Color.from littéral':
          'const Color c = Color.from(alpha: 1, red: 0.2, green: 0.4, blue: 0.6);',
      'grand entier décimal': 'const int c = 4280391411;',
    };
    for (final MapEntry<String, String> e in mordantes.entries) {
      expect(scan(e.value), isNotEmpty,
          reason: '🔴 forme NON attrapée (${e.key}) : ${e.value}');
    }

    // Contre-preuve de faux positif : les formes légitimes restent muettes,
    // sans quoi la garde deviendrait une garde qu'on désactive.
    const Map<String, String> legitimes = <String, String>{
      'masque RGB': 'final int rgb = argb & 0x00FFFFFF;',
      'graine FNV': 'int hash = 0x811C9DC5;',
      'Color.from calculé':
          'Color f(Color c) => Color.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);',
      'couleur commentée': '// const Color c = Color(0xFF112233);',
      'jeton du socle': 'final Color? c = theme.srsQualityColors;',
    };
    for (final MapEntry<String, String> e in legitimes.entries) {
      expect(scan(e.value), isEmpty,
          reason: '🔴 FAUX POSITIF (${e.key}) : ${e.value}');
    }
  });

  // ── Contre-preuves de l'EXEMPTION NOMINATIVE ────────────────────────────
  // Une exemption par chemin est une porte : ces trois tests prouvent qu'elle
  // est étroite (①), utile (②), et attachée au CHEMIN et non au contenu (③).

  test('exemption ① : chaque chemin exempté EXISTE sur disque', () {
    final Set<String> presents =
        zThemesLibSources().map(_relative).toSet();
    final List<String> fantomes = _kColorReferenceFiles
        .where((String p) => !presents.contains(p))
        .toList()
      ..sort();
    expect(fantomes, isEmpty,
        reason: '🔴 exemption FANTÔME : $fantomes — un chemin exempté qui '
            "n'existe pas laisse la porte ouverte à un futur fichier portant "
            'ce nom. Retirez-le.');
  });

  test('exemption ② : chaque fichier exempté PORTE des littéraux de couleur',
      () {
    final Map<String, File> parChemin = <String, File>{
      for (final File f in zThemesLibSources()) _relative(f): f,
    };
    final List<String> inutiles = <String>[];
    for (final String exempte in _kColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue; // couvert par ①
      // Rejoue le SCANNER RÉEL sous un chemin non exempté : compte les
      // littéraux que l'exemption masque effectivement.
      final int trouves =
          zScanColors('lib/src/_sonde_exemption.dart', f.readAsLinesSync())
              .length;
      if (trouves == 0) inutiles.add(exempte);
    }
    expect(inutiles, isEmpty,
        reason: '🔴 exemption INUTILE : $inutiles — ces fichiers ne portent '
            "aucun littéral de couleur ; leur exemption ne protège rien et "
            'masquerait un littéral futur. Retirez-la.');
  });

  test('exemption ③ : le MÊME CONTENU sous un autre chemin est REFUSÉ', () {
    final Map<String, File> parChemin = <String, File>{
      for (final File f in zThemesLibSources()) _relative(f): f,
    };
    for (final String exempte in _kColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue;
      final List<String> lignes = f.readAsLinesSync();
      // Un chemin VOISIN, dans le même répertoire, au nom quasi identique :
      // si l'exemption suivait le répertoire ou le motif de nom, il passerait.
      final String imposteur =
          '${exempte.substring(0, exempte.length - 5)}_copie.dart';
      expect(zScanColors(imposteur, lignes), isNotEmpty,
          reason: "🔴 l'exemption a suivi le CONTENU ou le RÉPERTOIRE : une "
              'copie de $exempte placée en $imposteur passerait la garde.');
      // Et le chemin exempté, lui, reste bien muet — sinon l'exemption est
      // inopérante et ② seul ne le dirait pas.
      expect(zScanColors(exempte, lignes), isEmpty,
          reason: "l'exemption nominative de $exempte ne s'applique pas");
    }
  });
}
