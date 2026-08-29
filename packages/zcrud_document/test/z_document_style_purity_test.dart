@TestOn('vm')
/// Garde de STYLE de `zcrud_document` — patron `zcrud_core`
/// (`test/purity/style_purity_test.dart`).
///
/// ## Ce qu'elle ajoute à `source_policy_test.dart`
///
/// `source_policy_test.dart` (AC13(d)) tenait déjà l'interdiction de couleur
/// sur `lib/src/presentation/`. Cette garde-ci **élargit la surface à tout
/// `lib/`** (le domaine compris — il est pur-Dart, un `Color` y serait un
/// défaut d'un autre ordre, mais un défaut quand même), ajoute les motifs
/// `Color.fromARGB(`/`Color.fromRGBO(`/hexadécimal de couleur nu, les formes
/// INVISIBLES à un scan ligne à ligne (`Color(<décimal>)` même multi-ligne,
/// `Color.from(red: <littéral>)`, entier décimal dans la plage ARGB opaque),
/// et surtout porte les
/// **trois contre-preuves** de l'exemption nominative. Les deux gardes
/// consomment la MÊME liste d'exemption (`kZColorReferenceFiles`) : il n'y a
/// pas deux listes à faire dériver.
///
/// ## Le scan porte sur le CODE, jamais sur la prose
///
/// Les commentaires sont retirés avant analyse (`stripComments`). C'est
/// délibéré, et c'est ce qui permet aux dartdocs du paquet d'ÉCRIRE
/// l'interdiction (« jamais un `Colors.white` en dur ») sans la déclencher.
/// Une couleur dans un commentaire ne peint rien.
///
/// ## `dart:io`
///
/// Cette garde lit le disque : `@TestOn('vm')` obligatoire (le gate `web`
/// compile les paquets pur-Dart vers Node).
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_sources.dart' as z_sources;

/// Motifs de littéral de couleur INTERDITS (regex), appliqués **ligne à
/// ligne** au code dépouillé de ses commentaires.
///
/// Couvre `Color(0x…)`, `Color.fromARGB(`, `Color.fromRGBO(`, `Colors.<nom>`,
/// et les constantes hexadécimales de couleur écrites **hors** de `Color(` —
/// forme `0xRRGGBB` (6 chiffres), `0xFxxxxxxx` (8 chiffres à alpha `F…`) et
/// `0x80RRGGBB` (alpha 50 %).
///
/// ⚠️ Renoncement DOCUMENTÉ sur l'hexadécimal : un entier hexadécimal de 8
/// chiffres dont l'octet de tête n'est ni `F…` ni `80` n'est PAS distinguable
/// textuellement d'un masque de bits ou d'une constante de hachage — deux
/// usages légitimes (`0x00FFFFFF` comme masque RGB, `0x811C9DC5` /
/// `0x01000193` comme graines FNV). Élargir à `0x[0-9a-fA-F]{8}` produirait
/// des faux positifs sur du code correct : la garde préfère laisser ce coin
/// non couvert plutôt que devenir une garde qu'on désactive.
// Les motifs sont volontairement dupliqués entre familles plutôt que fondus en
// une regex unique : un offender doit nommer la FORME qui a mordu.
final List<RegExp> _colorPatterns = <RegExp>[
  RegExp(r'Color\(\s*0x'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'\bColors\.'),
  RegExp(r'\b0x(?:[0-9a-fA-F]{6}|[fF][0-9a-fA-F]{7}|80[0-9a-fA-F]{6})\b'),
];

/// Motifs de littéral de couleur appliqués au **contenu joint** du fichier
/// (lignes dépouillées de leurs commentaires, jointes), donc capables de
/// traverser les sauts de ligne.
///
/// Trois formes que le scan ligne à ligne laissait passer :
/// 1. `Color(<entier DÉCIMAL>)` — la même couleur que `Color(0xFF…)`, écrite
///    en base 10 (`Color(4280391411)`), mono ou multi-ligne ;
/// 2. `Color.from(` dont **au moins une composante** `red`/`green`/`blue` est
///    un littéral numérique — la dérivation à composantes CALCULÉES reste
///    permise (c'est la voie légitime de composition et d'éclaircissement) ;
/// 3. un entier décimal nu dans la plage ARGB opaque
///    (`0xFF000000` = 4278190080 … `0xFFFFFFFF` = 4294967295), qui n'a
///    pratiquement aucun autre usage qu'une couleur codée en dur.
final List<RegExp> _colorContentPatterns = <RegExp>[
  RegExp(r'\bColor\(\s*[0-9][0-9_]*\s*[,)]'),
  RegExp(r'\bColor\.from\([^)]*\b(?:red|green|blue)\s*:\s*[0-9]*\.?[0-9]+\s*[,)]'),
  RegExp(r'\b42[789][0-9]{7}\b'),
];

Directory _libDir() {
  for (final String base in <String>['', 'packages/zcrud_document/']) {
    final Directory dir = Directory('${base}lib');
    if (dir.existsSync()) return dir;
  }
  fail('lib/ introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

/// Détecte les littéraux de couleur de [source] **comme s'il vivait sous**
/// [path]. Extrait pour que les contre-preuves rejouent EXACTEMENT le même
/// scan sous un autre chemin — l'exemption suit le chemin, jamais le contenu.
List<String> scanColors(String path, String source) {
  final List<String> offenders = <String>[];
  if (z_sources.kZColorReferenceFiles
      .contains(z_sources.normalizedLibPath(path))) {
    return offenders;
  }
  final String stripped = z_sources.stripComments(source);
  final List<String> lines = stripped.split('\n');
  for (int i = 0; i < lines.length; i++) {
    for (final RegExp pat in _colorPatterns) {
      if (pat.hasMatch(lines[i])) {
        offenders.add('$path:${i + 1}: ${pat.pattern} → ${lines[i].trim()}');
      }
    }
  }
  // Second scan, sur le CODE JOINT : `[^)]*` et `\s*` traversent alors les
  // sauts de ligne, ce que le scan ligne à ligne ne peut pas faire. Le
  // dépouillement des commentaires préserve le nombre de lignes, donc aucune
  // forme ne peut se reconstituer à cheval sur une dartdoc retirée.
  for (final RegExp pat in _colorContentPatterns) {
    if (pat.hasMatch(stripped)) {
      offenders.add('$path: ${pat.pattern} → ${pat.firstMatch(stripped)![0]}');
    }
  }
  return offenders;
}

void main() {
  test('aucun littéral de couleur dans lib/ hors référence exemptée (FR-26)',
      () {
    final List<String> offenders = <String>[];
    for (final File f in _dartFiles(_libDir())) {
      offenders.addAll(scanColors(f.path, f.readAsStringSync()));
    }
    expect(offenders, isEmpty,
        reason: 'FR-26 : toute couleur est INJECTÉE (paramètre, '
            'ZcrudScope.colorKeyResolver) ou DÉRIVÉE du ColorScheme. Seul '
            '${z_sources.kZColorReferenceFiles} a le droit d\'écrire un hex :'
            '\n${offenders.join('\n')}');
  });

  test('la garde DÉTECTE les quatre écritures d\'un littéral de couleur', () {
    for (final String sample in <String>[
      'final c = Color(0xFF112233);',
      'final c = Color.fromARGB(255, 10, 20, 30);',
      'final c = Color.fromRGBO(10, 20, 30, 1.0);',
      'final c = Colors.white;',
      'const int argb = 0xFF00AABB;',
    ]) {
      expect(
        scanColors('lib/src/presentation/_sonde.dart', sample),
        isNotEmpty,
        reason: 'échantillon non détecté : $sample',
      );
    }
    // Contre-preuve de faux positif : une couleur DÉRIVÉE ne déclenche rien.
    expect(
      scanColors(
        'lib/src/presentation/_sonde.dart',
        'final c = Theme.of(context).colorScheme.primaryContainer;',
      ),
      isEmpty,
    );
  });

  test(
      'la garde DÉTECTE les formes INVISIBLES au scan ligne à ligne '
      '(décimal, Color.from littéral, hex hors Color()', () {
    // Une forme est « attrapée » si le scan complet (ligne + contenu joint) la
    // reporte sous un chemin NON exempté — exactement ce que fait la garde sur
    // un vrai fichier de `lib/`.
    List<String> scan(String source) =>
        scanColors('lib/src/presentation/_sonde_forme.dart', source);

    const Map<String, String> mordantes = <String, String>{
      'décimal': 'const Color c = Color(4280391411);',
      'décimal multi-ligne': 'const Color c = Color(\n  4280391411,\n);',
      'Color.from littéral': 'const Color c = '
          'Color.from(alpha: 1, red: 0.2, green: 0.4, blue: 0.6);',
      'hex RGB hors Color(': 'const int c = 0x2196F3;',
      'hex ARGB alpha 50 % hors Color(': 'const int c = 0x80112233;',
      'grand entier décimal': 'const int c = 4280391411;',
      // Formes déjà couvertes avant durcissement : elles doivent le RESTER.
      'Color(0x…)': 'const Color c = Color(0xFF112233);',
      'Colors.<nom>': 'final Color c = Colors.red;',
      'fromARGB': 'const Color c = Color.fromARGB(255, 10, 20, 30);',
      'fromRGBO': 'const Color c = Color.fromRGBO(10, 20, 30, 1.0);',
    };
    for (final MapEntry<String, String> e in mordantes.entries) {
      expect(scan(e.value), isNotEmpty,
          reason: '🔴 forme NON attrapée (${e.key}) : ${e.value}');
    }

    // Contre-preuves : des usages LÉGITIMES d'un entier ou d'un `Color.from`
    // doivent rester silencieux — sinon la garde devient un générateur de faux
    // positifs, donc une garde qu'on désactive.
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
      'octets de signature PDF': 'const List<int> sig = <int>[0x25, 0x50, 0x44];',
    };
    for (final MapEntry<String, String> e in legitimes.entries) {
      expect(scan(e.value), isEmpty,
          reason: '🔴 FAUX POSITIF (${e.key}) : ${e.value}');
    }
  });

  test('la garde IGNORE une couleur citée en COMMENTAIRE (prose de contrat)',
      () {
    expect(
      scanColors(
        'lib/src/presentation/_sonde.dart',
        '/// jamais un `Colors.white` en dur.\n'
        '// interdit : Color(0xFF112233)\n'
        'final c = scheme.primary;',
      ),
      isEmpty,
      reason: 'une couleur qui ne peint rien ne doit pas rougir — sinon la '
          'garde interdirait de DOCUMENTER son propre interdit.',
    );
  });

  // ── Contre-preuves de l'EXEMPTION NOMINATIVE ────────────────────────────
  // Une exemption par chemin est une porte ouverte : ces trois tests prouvent
  // qu'elle est étroite, utile, et attachée au CHEMIN et non au contenu.

  test('exemption nominative ① : chaque chemin exempté EXISTE sur disque', () {
    final Set<String> present = _dartFiles(_libDir())
        .map((File f) => z_sources.normalizedLibPath(f.path))
        .toSet();
    final List<String> fantomes = z_sources.kZColorReferenceFiles
        .where((String p) => !present.contains(p))
        .toList();
    expect(fantomes, isEmpty,
        reason: '🔴 exemption FANTÔME : $fantomes — un chemin exempté qui '
            "n'existe plus laisse la porte ouverte pour un futur fichier "
            'portant ce nom. Retirez-le.');
  });

  test('exemption nominative ② : chaque fichier exempté PORTE bien des '
      'littéraux de couleur (exemption inutile ⇒ rouge)', () {
    final Map<String, File> parChemin = <String, File>{
      for (final File f in _dartFiles(_libDir()))
        z_sources.normalizedLibPath(f.path): f,
    };
    final List<String> inutiles = <String>[];
    for (final String exempte in z_sources.kZColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue; // couvert par la contre-preuve ①
      // Rejoue le scan sous un chemin NON exempté : compte les littéraux
      // réels. Le chemin de sonde reste sous `lib/` (même normalisation) tout
      // en étant absent de la liste d'exemption.
      final int trouves = scanColors(
        'lib/src/presentation/_sonde_exemption_inutile.dart',
        f.readAsStringSync(),
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
    final Map<String, File> parChemin = <String, File>{
      for (final File f in _dartFiles(_libDir()))
        z_sources.normalizedLibPath(f.path): f,
    };
    for (final String exempte in z_sources.kZColorReferenceFiles) {
      final File? f = parChemin[exempte];
      if (f == null) continue;
      final String contenu = f.readAsStringSync();
      const String imposteur =
          'lib/src/presentation/z_annotation_palette_copie.dart';
      expect(scanColors(imposteur, contenu), isNotEmpty,
          reason: "🔴 l'exemption a suivi le CONTENU : une copie de $exempte "
              'placée en $imposteur passerait la garde.');
      // Et le chemin exempté, lui, reste silencieux — sinon l'exemption ne
      // fonctionne pas du tout et le test ① serait le seul à le dire.
      expect(scanColors(exempte, contenu), isEmpty,
          reason: "l'exemption nominative de $exempte ne s'applique pas");
    }
  });
}
