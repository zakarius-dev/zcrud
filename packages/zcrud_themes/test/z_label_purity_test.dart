@TestOn('vm')
library;

// Garde jumelle de la pureté couleur : ce paquet ne rend jamais un TEXTE
// affichable. Il rend des CLÉS l10n, que l'hôte traduit.
//
// Le risque est réel et non théorique : c'est précisément ici qu'un thème
// futur poserait `name: 'Facile'` ou `label: 'Good'` à côté de sa teinte,
// puisque le palier de notation porte déjà une teinte, un glyphe et trois
// clés. Un texte posé là traverserait le paquet jusqu'à l'écran de l'hôte,
// dans une langue qu'il n'a pas choisie.
//
// Forme mesurée : tout littéral de chaîne du CODE de `lib/` (hors directives
// `import`/`export`/`part`, hors commentaires) doit avoir une forme de CLÉ —
// un identifiant en minuscule initiale, éventuellement pointé
// (`flashcard.type.`, `zcrud.theme.classic`, `fail`) — une fois ses
// interpolations retirées.
//
// Renoncement documenté : un mot unique tout en minuscules (`'good'`) est
// textuellement indistinguable d'une clé courte. La garde attrape ce qui est
// distinguable — accents, ponctuation, espaces, majuscule initiale — et le
// dit plutôt que de prétendre couvrir le reste.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'z_package_root.dart';

/// Forme admise pour un littéral de chaîne du code : une clé.
final RegExp _keyShape = RegExp(r'^[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]*)*$');

/// Littéraux de DIAGNOSTIC exemptés, nommés par chemin exact **et** par
/// contenu exact.
///
/// N'entre ici qu'une chaîne qui ne peut pas atteindre l'interface : le corps
/// d'un `toString()`, lu par un développeur dans une trace. L'exemption ne
/// suit ni le fichier seul, ni le contenu seul — il faut les deux.
const Map<String, Set<String>> _kDiagnosticLiterals = <String, Set<String>>{
  'lib/src/z_theme_catalog.dart': <String>{r'ZThemeSpec($id)'},
  'lib/src/themes/classic/z_classic_srs_palette_reference.dart': <String>{
    r'ZClassicSrsStep($quality, $name)',
  },
};

/// Chemin du fichier, relatif à la racine du paquet, séparateurs normalisés.
String _relative(File file) {
  final String root = zThemesPackageRoot().path.replaceAll(r'\', '/');
  final String path = file.path.replaceAll(r'\', '/');
  return path.startsWith('$root/') ? path.substring(root.length + 1) : path;
}

final RegExp _directive = RegExp(r'^\s*(import|export|part)\b');
final RegExp _literal = RegExp('\'([^\']*)\'|"([^"]*)"');
final RegExp _interpolationBraced = RegExp(r'\$\{[^}]*\}');
final RegExp _interpolationBare = RegExp(r'\$[a-zA-Z_][a-zA-Z0-9_]*');

String _stripComment(String line) {
  final int i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// Partie littérale d'une chaîne, interpolations retirées.
String _textPart(String s) => s
    .replaceAll(_interpolationBraced, '')
    .replaceAll(_interpolationBare, '');

/// Détecte les chaînes non conformes de [lines] **comme si** elles vivaient
/// sous [relPath].
///
/// Le chemin est un paramètre pour que les contre-preuves rejouent ce scanner
/// même, et non une copie de sa logique.
List<String> zScanLabels(String relPath, List<String> lines) {
  final Set<String> exemptes = _kDiagnosticLiterals[relPath] ?? const <String>{};
  final List<String> offenders = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final String code = _stripComment(lines[i]);
    if (_directive.hasMatch(code)) continue;
    for (final RegExpMatch m in _literal.allMatches(code)) {
      final String s = m.group(1) ?? m.group(2)!;
      if (s.isEmpty || exemptes.contains(s)) continue;
      final String text = _textPart(s);
      if (text.isEmpty || _keyShape.hasMatch(text)) continue;
      offenders.add('$relPath:${i + 1}: ${s.trim()}');
    }
  }
  return offenders;
}

void main() {
  test('aucun texte affichable dans lib/ — des clés, jamais des libellés', () {
    final List<File> sources = zThemesLibSources();
    expect(sources, isNotEmpty,
        reason: 'lib/ vide : la garde ne mesurerait rien.');
    final List<String> offenders = <String>[];
    for (final File file in sources) {
      offenders.addAll(zScanLabels(_relative(file), file.readAsLinesSync()));
    }
    expect(offenders, isEmpty,
        reason: 'Ce paquet expose des CLÉS l10n, jamais un texte affichable. '
            'Chaînes non conformes :\n${offenders.join('\n')}');
  });

  test('le scanner attrape un libellé affichable, et laisse passer une clé',
      () {
    List<String> scan(String source) =>
        zScanLabels('lib/src/_sonde_libelle.dart', source.split('\n'));

    const Map<String, String> mordantes = <String, String>{
      'français accentué': "  static const String l = 'Réussi';",
      'français multi-mots': "  static const String l = 'Trop facile';",
      'anglais multi-mots': '  static const String l = "Very easy";',
      'anglais capitalisé': "  static const String l = 'Good';",
      'phrase ponctuée': "  static const String l = 'Bravo !';",
      'texte interpolé': "  String f(int n) => 'Encore \$n cartes';",
    };
    for (final MapEntry<String, String> e in mordantes.entries) {
      expect(scan(e.value), isNotEmpty,
          reason: '🔴 libellé NON attrapé (${e.key}) : ${e.value}');
    }

    const Map<String, String> legitimes = <String, String>{
      'clé pointée': "  static const String k = 'zcrud.theme.classic';",
      'préfixe de clé': "  static const String k = 'flashcard.type.';",
      'mot-clé court': "  static const String k = 'fail';",
      'clé composée': "  String k(String s) => '\$prefix\${step.name}';",
      'directive import': "import 'package:flutter/material.dart';",
      'directive export': "export 'src/z_theme_catalog.dart';",
      'libellé commenté': "  // le libellé 'Trop facile' reste à l'hôte",
    };
    for (final MapEntry<String, String> e in legitimes.entries) {
      expect(scan(e.value), isEmpty,
          reason: '🔴 FAUX POSITIF (${e.key}) : ${e.value}');
    }
  });

  test('exemption ① : chaque littéral exempté EXISTE dans le fichier nommé',
      () {
    final Map<String, File> parChemin = <String, File>{
      for (final File f in zThemesLibSources()) _relative(f): f,
    };
    final List<String> fantomes = <String>[];
    _kDiagnosticLiterals.forEach((String path, Set<String> literals) {
      final File? f = parChemin[path];
      if (f == null) {
        fantomes.add('$path (fichier absent)');
        return;
      }
      final String source = f.readAsStringSync();
      for (final String l in literals) {
        if (!source.contains(l)) fantomes.add('$path :: $l');
      }
    });
    expect(fantomes, isEmpty,
        reason: '🔴 exemption FANTÔME : $fantomes — une exemption qui ne '
            'correspond à rien laisse la porte ouverte. Retirez-la.');
  });

  test('exemption ② : chaque littéral exempté serait REFUSÉ sans exemption',
      () {
    final List<String> inutiles = <String>[];
    _kDiagnosticLiterals.forEach((String path, Set<String> literals) {
      for (final String l in literals) {
        // Rejoue le SCANNER RÉEL sous un chemin non exempté.
        final List<String> vu = zScanLabels(
          'lib/src/_sonde_exemption.dart',
          <String>["  String toString() => '$l';"],
        );
        if (vu.isEmpty) inutiles.add('$path :: $l');
      }
    });
    expect(inutiles, isEmpty,
        reason: '🔴 exemption INUTILE : $inutiles — ces chaînes passent déjà '
            "la garde ; leur exemption ne protège rien et masquerait une "
            'chaîne future. Retirez-la.');
  });

  test('exemption ③ : le MÊME littéral sous un autre chemin est REFUSÉ', () {
    _kDiagnosticLiterals.forEach((String path, Set<String> literals) {
      for (final String l in literals) {
        final String imposteur = '${path.substring(0, path.length - 5)}_copie.dart';
        final List<String> ligne = <String>["  String toString() => '$l';"];
        expect(zScanLabels(imposteur, ligne), isNotEmpty,
            reason: "🔴 l'exemption a suivi le CONTENU : $l passerait sous "
                '$imposteur.');
        expect(zScanLabels(path, ligne), isEmpty,
            reason: "l'exemption nominative de $path :: $l ne s'applique pas");
      }
    });
  });
}
