@TestOn('vm')
library;

// LES NEUF JETONS QUE CE THÈME NE POSE PAS — et la mesure qui le justifie.
//
// Un jeton laissé vide est une réponse, pas un oubli : encore faut-il que la
// raison reste vraie. Cette garde ne se contente donc PAS de constater les
// `null` (une garde qui s'arrêterait là défendrait le choix au lieu de le
// mesurer) : elle lit sur disque le code qui rendrait ces jetons visibles, et
// rougit le jour où la raison de ne pas les poser disparaît.
//
// 🔴 Pourquoi une garde de SOURCE : les consommateurs vivent dans `zcrud_study`
// et `zcrud_ui_kit`, dont ce paquet n'a PAS d'arête — et ne doit pas en ouvrir
// (il est un PUITS du graphe). Patron déjà employé par
// `z_socle_gradient_parity_test.dart` et `z_classic_flashcard_surface_test.dart`.
//
// La morsure est prouvée des deux côtés : l'extraction est une fonction pure du
// texte, et les contre-preuves mutent ce texte EN MÉMOIRE — jamais sur disque,
// ce paquet n'étant le rédacteur d'aucun des deux autres.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_themes/zcrud_themes.dart';

import 'z_package_root.dart';

/// Les TROIS consommateurs du jeton global `ZcrudTheme.accentBarHeight`.
const String kZAccentCardPath =
    'packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart';
const String kZAccentFolderPath =
    'packages/zcrud_study/lib/src/presentation/z_folder_card_chrome.dart';
const String kZAccentFieldPath =
    'packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart';

/// Le fichier de référence du chrome de page, et ses trois consommateurs.
const String kZChromeReferencePath =
    'packages/zcrud_ui_kit/lib/src/presentation/z_page_shell_reference.dart';
const String kZChromeShellPath =
    'packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart';
const String kZChromeFabPath =
    'packages/zcrud_ui_kit/lib/src/presentation/z_gradient_fab.dart';
const String kZChromeChipPath =
    'packages/zcrud_ui_kit/lib/src/presentation/z_chip_style.dart';

/// Le texte de [path], lu sur disque.
///
/// Lève si le fichier a bougé : une garde qui ne trouve plus sa source doit
/// rougir, jamais se taire.
String zReadSource(String path) {
  final File file = File('${zMonorepoRoot().path}/$path');
  if (!file.existsSync()) {
    throw StateError(
      'Source introuvable : ${file.path}. La garde ne mesure plus rien — '
      'corrigez le chemin.',
    );
  }
  return file.readAsStringSync();
}

/// Retire les commentaires de [source] et aplatit les blancs : les motifs
/// ciblent le CODE, et une expression s'écrit sur plusieurs lignes.
String zCodeOf(String source) => source
    .split('\n')
    .map((String line) {
      final int i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ');

// ── `accentBarHeight` : le jeton GLOBAL ──────────────────────────────────────

/// L'expression affectée à la hauteur du liseré chez un consommateur du jeton
/// `ZcrudTheme.accentBarHeight`.
///
/// Lève si aucune affectation ne traverse le jeton : le consommateur a changé
/// de forme, et la garde ne mesure plus la propriété qu'elle croit mesurer.
String zAccentHeightExpression(String source) {
  final RegExpMatch? m = RegExp(
    r'final\s+[\w?<> ]*\bheight\s*=\s*([^;]*accentBarHeight[^;]*);',
  ).firstMatch(zCodeOf(source));
  if (m == null) {
    throw StateError(
      'Aucune lecture de `accentBarHeight` chez ce consommateur : la garde ne '
      'mesure plus rien.',
    );
  }
  return m.group(1)!.trim();
}

/// `true` si l'expression laisse un **paramètre** passer devant le jeton.
bool zHasParameterAhead(String expression) =>
    expression.contains('??') &&
    expression.indexOf('??') < expression.indexOf('accentBarHeight');

// ── Chrome de page : jeton `??` référence ────────────────────────────────────

/// Valeur textuelle de chaque `static const` du fichier de référence du chrome.
///
/// Lève sur un fichier illisible plutôt que de rendre une table vide : une
/// garde qui comparerait le vide au vide resterait verte en ne mesurant rien.
Map<String, String> zParseChromeReference(String source) {
  final Map<String, String> out = <String, String>{};
  for (final RegExpMatch m in RegExp(
    r'static\s+const\s+[\w<>,?]+(?:\s*<[^>]*>)?\s+(\w+)\s*=\s*([^;]+);',
  ).allMatches(zCodeOf(source))) {
    out[m.group(1)!] = m.group(2)!.replaceAll(' ', '');
  }
  if (out.isEmpty) {
    throw StateError(
      'Aucune constante lue dans le fichier de référence du chrome : la garde '
      'ne mesure plus rien.',
    );
  }
  return out;
}

/// Un jeton de chrome, le fichier qui le consomme, et le motif qui prouve que
/// la **référence** est son repli — sans condition.
///
/// Chaque motif est écrit sur la forme RÉELLE du code, jamais sur une forme
/// supposée : c'est ce qui le rend falsifiable.
const Map<String, (String, String)> kZChromeChains = <String, (String, String)>{
  'appBarWashAlphas': (
    kZChromeShellPath,
    r'ZcrudTheme\.of\(context\)\.appBarWashAlphas;.{0,240}?'
        r'return ZPageShellReference\.appBarWashAlphas;',
  ),
  'appBarWashElevation': (
    kZChromeShellPath,
    r'ZcrudTheme\.of\(context\)\.appBarWashElevation;.{0,240}?'
        r'return ZPageShellReference\.appBarWashElevation;',
  ),
  'fabElevation': (
    kZChromeFabPath,
    r'ZcrudTheme\.of\(context\)\.fabElevation;.{0,240}?'
        r'return ZPageShellReference\.fabElevation;',
  ),
  'fabIconSize': (
    kZChromeFabPath,
    r'ZcrudTheme\.of\(context\)\.fabIconSize;.{0,240}?'
        r'return ZPageShellReference\.fabIconSize;',
  ),
  'fabLabelStyle': (
    kZChromeFabPath,
    r'ZcrudTheme\.of\(context\)\.fabLabelStyle \?\?.{0,160}?'
        r'ZPageShellReference\.fabLabelWeight.{0,120}?'
        r'ZPageShellReference\.fabLabelLetterSpacing',
  ),
  'fabShape': (
    kZChromeFabPath,
    r'ZcrudTheme\.of\(context\)\.fabShape;.{0,600}?shape == null \?',
  ),
  'choiceChipShape': (
    kZChromeChipPath,
    r'ZcrudTheme\.of\(context\)\.choiceChipShape \?\?.{0,200}?'
        r'ZPageShellReference\.chipCornerRadius',
  ),
  'choiceChipShowCheckmark': (
    kZChromeChipPath,
    r'ZcrudTheme\.of\(context\)\.choiceChipShowCheckmark \?\? '
        r'ZPageShellReference\.chipShowCheckmark',
  ),
};

/// `true` si [source] résout [token] par ordre `jeton > référence`.
bool zResolvesToReference(String token, String source) =>
    RegExp(kZChromeChains[token]!.$2).hasMatch(zCodeOf(source));

void main() {
  group('les NEUF jetons restent vides sous le thème Classic', () {
    test('`accentBarHeight` et les huit jetons de chrome sont `null`', () {
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme t = ZClassicTheme.forTheme(ThemeData(brightness: b));
        expect(t.accentBarHeight, isNull, reason: '$b accentBarHeight');
        expect(t.appBarWashAlphas, isNull, reason: '$b appBarWashAlphas');
        expect(t.appBarWashElevation, isNull, reason: '$b appBarWashElevation');
        expect(t.fabShape, isNull, reason: '$b fabShape');
        expect(t.fabElevation, isNull, reason: '$b fabElevation');
        expect(t.fabIconSize, isNull, reason: '$b fabIconSize');
        expect(t.fabLabelStyle, isNull, reason: '$b fabLabelStyle');
        expect(t.choiceChipShape, isNull, reason: '$b choiceChipShape');
        expect(t.choiceChipShowCheckmark, isNull,
            reason: '$b choiceChipShowCheckmark');
        // Non-vacuité : sans elle, un thème devenu entièrement vide passerait
        // ce test sans rien prouver.
        expect(t.flashcardTypeGradients, isNotNull, reason: '$b');
        expect(t.signaturePalette, isNotNull, reason: '$b');
      }
    });

    test('le thème ne pose pas non plus la géométrie de dégradé', () {
      // Conséquence MESURÉE : le liseré des cartes de dossier exige les DEUX
      // jetons de géométrie en plus de la hauteur. Poser la seule hauteur ne
      // le ferait donc même pas apparaître — l'effet du jeton dépendrait de
      // ce que l'hôte a branché par ailleurs.
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme t = ZClassicTheme.forTheme(ThemeData(brightness: b));
        expect(t.gradientBegin, isNull, reason: '$b');
        expect(t.gradientEnd, isNull, reason: '$b');
      }
    });
  });

  group('`accentBarHeight` est GLOBAL — mesuré sur ses trois consommateurs', () {
    test('la carte de révision offre un paramètre pour s\'y soustraire', () {
      final String expression =
          zAccentHeightExpression(zReadSource(kZAccentCardPath));
      expect(zHasParameterAhead(expression), isTrue,
          reason: 'La carte lit le jeton NU : la voie paramètre a disparu, et '
              'la valeur mesurée n\'a plus de chemin précis.');
    });

    test('les deux AUTRES surfaces le lisent NU', () {
      // C'est là toute la raison de ne pas le poser : sur ces deux surfaces,
      // le jeton n'a pas de contrepoids. Le poser pour atteindre la carte de
      // révision les repeindrait sans qu'aucun appelant puisse s'y opposer.
      for (final String path in <String>[
        kZAccentFolderPath,
        kZAccentFieldPath,
      ]) {
        final String expression = zAccentHeightExpression(zReadSource(path));
        expect(zHasParameterAhead(expression), isFalse, reason: path);
      }
    });

    test('la valeur mesurée reste publiée, pour la voie paramètre', () {
      expect(ZClassicSurfaceReference.cardAccentHeight, 4);
      expect(ZClassicSurfaceReference.cardAccentHeight, greaterThan(0),
          reason: 'Une hauteur nulle ne peint aucun liseré.');
    });
  });

  group('chrome de page — la référence EST déjà la valeur mesurée', () {
    late final Map<String, String> reference =
        zParseChromeReference(zReadSource(kZChromeReferencePath));

    test('la rampe de lavis d\'origine, arrêt par arrêt', () {
      // Relevé du rendu d'origine : quatre opacités décroissantes posées sur la
      // teinte d'identité de la barre. Si cette rampe change, ce thème doit
      // reprendre la main et poser son jeton — c'est ce que cette garde signale.
      expect(reference['appBarWashAlphas'],
          '<double>[0.15,0.10,0.05,0.02]');
      expect(reference['appBarWashElevation'], '0');
    });

    test('les métriques de bouton et de puce', () {
      expect(reference['fabElevation'], '0');
      expect(reference['fabIconSize'], '22');
      expect(reference['fabCornerRadius'], '20');
      expect(reference['fabLabelLetterSpacing'], '0.3');
      expect(reference['fabLabelWeight'], 'FontWeight.w600');
      expect(reference['chipCornerRadius'], '12');
      expect(reference['chipShowCheckmark'], 'false');
    });

    test('les HUIT jetons ont la référence pour repli, sans condition', () {
      expect(kZChromeChains, hasLength(8),
          reason: 'Huit jetons de chrome : la table doit tous les couvrir.');
      for (final MapEntry<String, (String, String)> e
          in kZChromeChains.entries) {
        expect(
          zResolvesToReference(e.key, zReadSource(e.value.$1)),
          isTrue,
          reason: '${e.key} : la chaîne `jeton > référence` n\'est plus celle '
              'que la garde connaît. Poser le jeton dans le thème redeviendrait '
              'peut-être nécessaire — remesurer.',
        );
      }
    });
  });

  group('la garde MORD (sources mutées en mémoire)', () {
    test('un paramètre retiré de la carte de révision est vu', () {
      final String source = zReadSource(kZAccentCardPath);
      final String mute =
          source.replaceFirst('widget.accentHeight ?? theme.accentBarHeight',
              'theme.accentBarHeight');
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zHasParameterAhead(zAccentHeightExpression(mute)), isFalse);
    });

    test('un paramètre AJOUTÉ à la carte de dossier est vu', () {
      final String source = zReadSource(kZAccentFolderPath);
      final String mute = source.replaceFirst(
        'final double? height = theme.accentBarHeight;',
        'final double? height = accentHeight ?? theme.accentBarHeight;',
      );
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zHasParameterAhead(zAccentHeightExpression(mute)), isTrue);
    });

    test('un consommateur qui cesse de lire le jeton LÈVE', () {
      final String source = zReadSource(kZAccentFieldPath);
      final String mute = source.replaceFirst('accentBarHeight;', 'gapL;');
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(() => zAccentHeightExpression(mute), throwsStateError);
    });

    test('une rampe de lavis changée est vue', () {
      final String source = zReadSource(kZChromeReferencePath);
      final String mute = source.replaceFirst('0.15, 0.10', '0.20, 0.10');
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zParseChromeReference(mute)['appBarWashAlphas'],
          isNot('<double>[0.15,0.10,0.05,0.02]'));
    });

    test('un arrêt RETIRÉ de la rampe est vu', () {
      final String source = zReadSource(kZChromeReferencePath);
      final String mute = source.replaceFirst('0.05, 0.02', '0.05');
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zParseChromeReference(mute)['appBarWashAlphas'],
          isNot('<double>[0.15,0.10,0.05,0.02]'));
    });

    test('un repli de chrome qui cesse de viser la référence est vu', () {
      final String source = zReadSource(kZChromeChipPath);
      final String mute = source.replaceFirst(
        'ZPageShellReference.chipShowCheckmark',
        'true',
      );
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zResolvesToReference('choiceChipShowCheckmark', mute), isFalse);
    });

    test('un jeton de chrome qui cesse d\'être consulté est vu', () {
      final String source = zReadSource(kZChromeFabPath);
      final String mute = source.replaceFirst(
        'ZcrudTheme.of(context).fabIconSize;',
        'null;',
      );
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(zResolvesToReference('fabIconSize', mute), isFalse);
    });

    test('un fichier de référence illisible LÈVE, au lieu de rendre la garde '
        'creuse', () {
      expect(() => zParseChromeReference('library;'), throwsStateError);
    });

    test('une source déplacée LÈVE', () {
      expect(
        () => zReadSource('packages/zcrud_ui_kit/lib/introuvable.dart'),
        throwsStateError,
      );
    });
  });
}
