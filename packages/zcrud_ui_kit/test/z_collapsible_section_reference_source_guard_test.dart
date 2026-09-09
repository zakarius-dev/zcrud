/// Garde de SOURCE : la référence de section repliable ne porte **aucune
/// couleur**.
///
/// C'est l'invariant qui rend la référence neutralisable : les scalaires
/// qu'elle fige ne peignent rien par eux-mêmes, donc un hôte qui change de
/// palette n'hérite d'aucune teinte figée. Une couleur qui s'y glisserait
/// échapperait à la chaîne « paramètre > jeton > référence » — les métriques,
/// elles, sont couvertes par les dix jetons.
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

const String _reference =
    'lib/src/presentation/z_collapsible_section_reference.dart';
const String _widget = 'lib/src/presentation/z_collapsible_section.dart';

void main() {
  group('z_collapsible_section_reference.dart : 0 couleur', () {
    late String source;

    setUpAll(() => source = stripComments(readPackageFile(_reference)));

    test('aucun littéral de couleur dans le code', () {
      for (final RegExp pattern in _colorLiterals) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason:
              'Couleur écrite en dur (${pattern.pattern}) dans la référence de '
              'section repliable — elle ne doit contenir que des métriques.',
        );
      }
    });

    test('aucun rôle de ColorScheme, aucune opacité appliquée à une couleur',
        () {
      // Une référence de MÉTRIQUES n'a pas à connaître de teinte, fût-elle
      // dérivée d'un rôle : la teinte est décidée au site d'appel. Les
      // opacités qui vivent ici sont des NOMBRES — elles ne sont appliquées à
      // une couleur que dans le widget.
      expect(RegExp(r'\bColorScheme\b').hasMatch(source), isFalse);
      expect(RegExp(r'withValues\(').hasMatch(source), isFalse);
      expect(RegExp(r'withOpacity\(').hasMatch(source), isFalse);
      expect(RegExp(r'\bColor\b').hasMatch(source), isFalse);
    });

    test(
      'CONTRE-PREUVE : le détecteur mord réellement sur une source témoin',
      () {
        const String temoin = 'const Color c = Color(0xFF667EEA);';
        expect(
          _colorLiterals.any((RegExp p) => p.hasMatch(temoin)),
          isTrue,
          reason: 'Si le détecteur ne voyait pas cette ligne, le test '
              'principal serait vacant.',
        );
      },
    );

    test(
      'la référence est bien celle que la section consomme (garde non '
      'orpheline)',
      () {
        final String widget = stripComments(readPackageFile(_widget));
        // Les vingt-et-un scalaires de la référence, tous cités par le widget :
        // une valeur figée que personne ne lit est une valeur morte.
        for (final String member in <String>[
          'margin',
          'cornerRadius',
          'borderAlpha',
          'expandedElevation',
          'collapsedElevation',
          'headerContentPadding',
          'leadingGap',
          'leadingPadding',
          'leadingBackgroundAlpha',
          'leadingIconSize',
          'titleWeight',
          'titleMaxLines',
          'countMargin',
          'countPadding',
          'countCornerRadius',
          'countWeight',
          'chevronExpandedTurns',
          'chevronCollapsedTurns',
          'chevronDuration',
          'bodyBorderAlpha',
          'bodyCornerRadius',
          'minTouchTarget',
        ]) {
          expect(
            widget.contains('ZCollapsibleSectionReference.$member'),
            isTrue,
            reason:
                '`ZCollapsibleSectionReference.$member` est figé mais lu par '
                'aucun site de la section — scalaire mort.',
          );
        }
      },
    );

    test('la référence déclare TOUS les membres attendus (garde non vacante)',
        () {
      final Iterable<RegExpMatch> members =
          RegExp(r'static const [\w<>, ?]+ (\w+) =').allMatches(source);
      expect(
        members.length,
        greaterThanOrEqualTo(20),
        reason:
            '🔴 le scanner ne trouve plus les membres — la garde ci-dessus '
            'deviendrait vacante.',
      );
    });

    test('les insets de la référence sont DIRECTIONNELS (invariant AD-13)', () {
      expect(RegExp(r'\bEdgeInsets\.').hasMatch(source), isFalse,
          reason: 'un inset non directionnel casserait le rendu RTL');
      expect(RegExp(r'\bEdgeInsetsDirectional\b').hasMatch(source), isTrue);
    });
  });
}
