/// Garde de SOURCE : le squelette ne porte aucune couleur, aucune dépendance.
///
/// Une garde de rendu ne verrait pas un littéral de couleur placé sur un
/// chemin non emprunté par les tests. Celle-ci lit le fichier, commentaires
/// retirés — une couleur citée en dartdoc n'est pas une couleur peinte.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Motifs qui désignent une couleur écrite en dur.
final List<RegExp> _colorLiterals = <RegExp>[
  RegExp(r'Color\(0x'),
  RegExp(r'Color\.fromARGB'),
  RegExp(r'Color\.fromRGBO'),
  RegExp(r'\bColors\.'),
  RegExp(r'0xFF[0-9A-Fa-f]{6}'),
];

void main() {
  group('P2-B — z_skeleton.dart : aucune couleur, aucune dépendance tierce', () {
    late String source;

    setUpAll(() {
      source = stripComments(
        readPackageFile('lib/src/presentation/z_skeleton.dart'),
      );
    });

    test('aucun littéral de couleur dans le code', () {
      for (final RegExp pattern in _colorLiterals) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason:
              'Couleur écrite en dur (${pattern.pattern}) dans z_skeleton.dart '
              '— les teintes doivent venir des rôles du ColorScheme (FR-26).',
        );
      }
    });

    test('les teintes viennent bien de rôles Material 3', () {
      expect(source.contains('scheme.surfaceContainerHighest'), isTrue);
      expect(source.contains('scheme.surfaceContainerHigh'), isTrue);
    });

    test('aucune opacité magique appliquée à une couleur', () {
      expect(RegExp(r'withOpacity\(').hasMatch(source), isFalse);
      expect(RegExp(r'withValues\(').hasMatch(source), isFalse);
    });

    test('aucun paquet tiers de squelette dans le pubspec', () {
      final String pubspec = readPackageFile('pubspec.yaml');
      for (final String forbidden in <String>[
        'skeletonizer',
        'shimmer',
        'skeleton_text',
        'skeleton_loader',
      ]) {
        expect(
          RegExp('^\\s*$forbidden:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: 'Dépendance tierce interdite : $forbidden.',
        );
      }
    });

    test('aucun import hors flutter / zcrud_core', () {
      final Iterable<RegExpMatch> imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source);
      expect(imports, isNotEmpty);
      for (final RegExpMatch m in imports) {
        final String uri = m.group(1)!;
        expect(
          uri.startsWith('package:flutter/') ||
              uri.startsWith('package:zcrud_core/') ||
              uri.startsWith('dart:'),
          isTrue,
          reason: 'Import interdit dans z_skeleton.dart : $uri',
        );
      }
    });
  });
}
