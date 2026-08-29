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
/// `Color.fromARGB(`/`Color.fromRGBO(`/`0xFF……` nu, et surtout porte les
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

/// Motifs de littéral de couleur INTERDITS (regex), appliqués au code
/// dépouillé de ses commentaires.
final List<RegExp> _colorPatterns = <RegExp>[
  RegExp(r'Color\(\s*0x'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'\bColors\.'),
  RegExp(r'\b0x[fF][0-9a-fA-F]{5,7}\b'),
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
  final List<String> lines = z_sources.stripComments(source).split('\n');
  for (int i = 0; i < lines.length; i++) {
    for (final RegExp pat in _colorPatterns) {
      if (pat.hasMatch(lines[i])) {
        offenders.add('$path:${i + 1}: ${pat.pattern} → ${lines[i].trim()}');
      }
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
