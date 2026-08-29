/// Garde de SOURCE : la référence de chrome ne porte **aucune couleur**.
///
/// C'est l'invariant qui distingue cette référence-ci de celle de la palette
/// signature : ici on ne fige que des **métriques**. Une couleur qui s'y
/// glisserait échapperait à la chaîne « paramètre > jeton > référence » et au
/// profil neutre, puisque les scalaires, eux, ne sont pas neutralisables.
///
/// Une garde de RENDU ne verrait pas un littéral posé sur un chemin non
/// emprunté par les tests : celle-ci lit le fichier, commentaires retirés — une
/// couleur citée en dartdoc n'est pas une couleur peinte.
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
  RegExp(r'0x[fF][fF][0-9A-Fa-f]{6}'),
];

const String _reference = 'lib/src/presentation/z_page_shell_reference.dart';

void main() {
  group('Apparence B — z_page_shell_reference.dart : 0 couleur', () {
    late String source;

    setUpAll(() => source = stripComments(readPackageFile(_reference)));

    test('aucun littéral de couleur dans le code', () {
      for (final RegExp pattern in _colorLiterals) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason:
              'Couleur écrite en dur (${pattern.pattern}) dans la référence de '
              'chrome — elle ne doit contenir que des métriques.',
        );
      }
    });

    test('aucun rôle de ColorScheme, aucune opacité appliquée à une couleur', () {
      // Une référence de MÉTRIQUES n'a pas à connaître de teinte, fût-elle
      // dérivée d'un rôle: la teinte est décidée au site d'appel.
      expect(RegExp(r'\bColorScheme\b').hasMatch(source), isFalse);
      expect(RegExp(r'withValues\(').hasMatch(source), isFalse);
      expect(RegExp(r'withOpacity\(').hasMatch(source), isFalse);
    });

    test(
      'CONTRE-PREUVE : le détecteur mord réellement sur une source témoin',
      () {
        const String temoin = 'const Color c = Color(0xFF667EEA);';
        expect(
          _colorLiterals.any((RegExp p) => p.hasMatch(temoin)),
          isTrue,
          reason:
              'Si le détecteur ne voyait pas cette ligne, le test principal '
              'serait vacant.',
        );
      },
    );

    test(
      'la référence est bien celle que le chrome consomme (garde non orpheline)',
      () {
        final String shell = stripComments(
          readPackageFile('lib/src/presentation/z_page_shell.dart'),
        );
        expect(shell.contains('ZPageShellReference.appBarWashAlphas'), isTrue);
        final String fab = stripComments(
          readPackageFile('lib/src/presentation/z_gradient_fab.dart'),
        );
        expect(fab.contains('ZPageShellReference.fabCornerRadius'), isTrue);
        final String chip = stripComments(
          readPackageFile('lib/src/presentation/z_chip_style.dart'),
        );
        expect(chip.contains('ZPageShellReference.chipCornerRadius'), isTrue);
      },
    );
  });
}
