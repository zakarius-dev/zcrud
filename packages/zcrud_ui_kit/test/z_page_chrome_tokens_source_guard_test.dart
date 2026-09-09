/// Garde de SOURCE : chaque jeton de chrome de page est **réellement lu sur le
/// thème**, par un motif DISCRIMINANT.
///
/// 🔴 Le trou que cette garde ferme. La garde d'inertie des jetons de
/// `zcrud_core` (`z_theme_token_inertia_guard_test.dart`) cherche le motif
/// textuel `.<nom>` dans les sources de `packages/*/lib`. Quatre de ces
/// jetons-ci portent **le même nom** que le membre de référence qu'ils
/// remplacent (`ZPageShellReference.appBarWashAlphas`,
/// `…appBarWashElevation`, `…fabElevation`, `…fabIconSize`) : la lecture de la
/// RÉFÉRENCE suffit à satisfaire son motif. MESURÉ — en supprimant les deux
/// lectures du thème dans `_zWashAlphas`/`_zWashElevation`, la garde d'inertie
/// est restée **VERTE** alors que les deux jetons étaient devenus inertes.
///
/// Le motif exigé ici, `ZcrudTheme.of(context).<jeton>`, ne peut pas être
/// satisfait par une lecture de la référence : il nomme la source.
///
/// Les gardes de RENDU du fichier voisin restent la mesure principale — cette
/// garde-ci n'est que le filet structurel qui manque en amont.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Jeton → fichier qui doit le lire sur le thème.
const Map<String, String> _sites = <String, String>{
  'appBarWashAlphas': 'lib/src/presentation/z_page_shell.dart',
  'appBarWashElevation': 'lib/src/presentation/z_page_shell.dart',
  'fabShape': 'lib/src/presentation/z_gradient_fab.dart',
  'fabElevation': 'lib/src/presentation/z_gradient_fab.dart',
  'fabIconSize': 'lib/src/presentation/z_gradient_fab.dart',
  'fabLabelStyle': 'lib/src/presentation/z_gradient_fab.dart',
  'choiceChipShape': 'lib/src/presentation/z_chip_style.dart',
  'choiceChipShowCheckmark': 'lib/src/presentation/z_chip_style.dart',
};

RegExp _lecture(String jeton) =>
    RegExp('ZcrudTheme\\.of\\(context\\)\\.$jeton\\b');

void main() {
  test('chaque jeton de chrome est lu SUR LE THÈME, à son site de rendu', () {
    final List<String> muets = <String>[];
    for (final MapEntry<String, String> e in _sites.entries) {
      final String code = stripComments(readPackageFile(e.value));
      if (!_lecture(e.key).hasMatch(code)) muets.add('${e.key} → ${e.value}');
    }
    expect(
      muets,
      isEmpty,
      reason:
          '🔴 jeton(s) déclaré(s) dans `ZcrudTheme` mais plus lu(s) sur le '
          'thème au site nommé — la valeur retomberait silencieusement sur la '
          'référence :\n${muets.join("\n")}',
    );
  });

  test(
    'CONTRE-PREUVE : lire la RÉFÉRENCE ne satisfait PAS le motif',
    () {
      // C'est exactement la source qui rendait la garde d'inertie amont verte.
      const String temoin = 'return ZPageShellReference.appBarWashAlphas;';
      expect(_lecture('appBarWashAlphas').hasMatch(temoin), isFalse);
      expect(
        RegExp(r'\.appBarWashAlphas\b').hasMatch(temoin),
        isTrue,
        reason: 'si le motif AMONT ne mordait pas non plus sur ce témoin, '
            'cette garde n\'aurait rien à ajouter',
      );
      // …et le motif exigé mord bien sur une vraie lecture de thème.
      expect(
        _lecture('appBarWashAlphas').hasMatch(
          'final List<double>? t = ZcrudTheme.of(context).appBarWashAlphas;',
        ),
        isTrue,
      );
    },
  );

  test('la table de sites reste alignée sur les jetons livrés', () {
    expect(_sites, hasLength(8));
    for (final String fichier in _sites.values.toSet()) {
      expect(
        readPackageFile(fichier),
        isNotEmpty,
        reason: 'site introuvable : $fichier',
      );
    }
  });
}
