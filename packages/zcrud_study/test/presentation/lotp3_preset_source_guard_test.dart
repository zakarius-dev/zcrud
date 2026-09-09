/// **Gardes de SOURCE des assemblages de référence** — ce qu'un preset n'a
/// pas le droit d'être.
///
/// Un assemblage de référence est la place la plus tentante du dépôt pour
/// déposer la peau d'une application : il rend un écran entier, et « juste
/// cette couleur-là » y passerait inaperçu. Trois propriétés qu'aucun test de
/// comportement ne tient durablement :
///
/// 1. **`0` couleur littérale** (FR-26/AD-6) — les couleurs entrent par CLÉ,
///    jamais par valeur ;
/// 2. **`0` libellé affichable** — les textes sont déjà localisés par l'hôte,
///    l'assemblage n'en compose aucun ;
/// 3. **`0` nom d'application hôte** — un preset nomme une direction de
///    design, jamais un client.
///
/// Chaque scanner est **partagé** avec sa contre-preuve : sans ce partage, la
/// contre-preuve prouverait le pouvoir des MOTIFS, jamais celui du SCANNER.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as zsrc;

/// Le répertoire des assemblages de référence, relatif au package.
const String _presetDir = 'lib/src/presentation/preset';

/// Les fichiers RÉELLEMENT présents — scan récursif, jamais une liste figée :
/// tout futur assemblage est capté sans édition de ce test.
List<File> _presetFiles() {
  final Directory dir = Directory('${zsrc.packageRoot().path}/$_presetDir');
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable : $_presetDir — ⚠️ `flutter test` doit '
          'être lancé DEPUIS le package');
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

/// **Scanner RÉEL** des couleurs littérales — partagé avec sa contre-preuve.
List<String> _colorHits(String source) => <String>[
      for (final String pattern in <String>[
        'Colors.',
        'Color(0x',
        'AppColors.',
      ])
        if (source.contains(pattern)) pattern,
    ];

/// **Scanner RÉEL** des libellés affichables — partagé avec sa contre-preuve.
///
/// Vise les PUITS réellement rendus, là où un littéral est toujours un défaut :
/// le 1ᵉʳ argument de `Text(` et les arguments nommés qui rendent du texte.
/// Il ne prétend pas voir un littéral passé par une variable intermédiaire.
List<String> _labelHits(String source) => <RegExp>[
      RegExp(r'''Text\(\s*['"]'''),
      RegExp(r'''(hintText|labelText|tooltip|semanticLabel)\s*:\s*['"]'''),
    ]
        .expand((RegExp re) =>
            re.allMatches(source).map((RegExpMatch m) => m.group(0)!))
        .toList(growable: false);

/// **Scanner RÉEL** des noms d'application hôte — partagé avec sa contre-preuve.
///
/// Joué sur la source BRUTE, commentaires compris : un nom d'hôte dans un
/// commentaire est exactement la fuite de peau que cette garde traque.
List<String> _hostNameHits(String source) => <RegExp>[
      RegExp('iffd', caseSensitive: false),
      RegExp('lex_douane', caseSensitive: false),
      RegExp(r'\blex\b', caseSensitive: false),
      RegExp('dodlp', caseSensitive: false),
      RegExp('dlcfti', caseSensitive: false),
    ]
        .expand((RegExp re) =>
            re.allMatches(source).map((RegExpMatch m) => m.group(0)!))
        .toList(growable: false);

void main() {
  group('🧭 la garde n\'est pas VACUELLE', () {
    test('les trois assemblages de référence sont bien scannés', () {
      final List<String> names =
          _presetFiles().map((File f) => f.uri.pathSegments.last).toList();
      expect(names, isNotEmpty, reason: '🔴 aucun fichier scanné');
      expect(
        names,
        containsAll(<String>[
          'z_card_chrome_spec.dart',
          'z_session_header_spec.dart',
          'z_study_session_preset.dart',
        ]),
        reason: '🔴 un assemblage a été déplacé hors du scan',
      );
    });
  });

  group('🎨 FR-26 — aucune couleur littérale dans un assemblage', () {
    test('aucun fichier ne porte de couleur en dur', () {
      for (final File file in _presetFiles()) {
        expect(_colorHits(zsrc.strippedText(file)), isEmpty,
            reason: '🔴 couleur littérale dans ${file.path} — les couleurs '
                'entrent par CLÉ');
      }
    });

    test('la garde MORD : une couleur injectée est signalée', () {
      expect(_colorHits('final c = Color(0xFF102030);'), isNotEmpty);
      expect(_colorHits('final c = Colors.red;'), isNotEmpty);
      expect(_colorHits('final c = pair.color;'), isEmpty,
          reason: '🔴 le scanner condamnerait la résolution PAR CLÉ');
    });
  });

  group('🔤 aucun libellé affichable dans un assemblage', () {
    test('aucun fichier ne compose de texte', () {
      for (final File file in _presetFiles()) {
        expect(_labelHits(zsrc.strippedText(file)), isEmpty,
            reason: '🔴 libellé en dur dans ${file.path} — les textes sont '
                'déjà localisés par l\'hôte');
      }
    });

    test('la garde MORD : un libellé injecté est signalé', () {
      expect(_labelHits("return const Text('Session terminée');"), isNotEmpty);
      expect(_labelHits("Semantics(semanticLabel: 'série')"), isNotEmpty);
      expect(_labelHits('return Text(spec.title);'), isEmpty,
          reason: '🔴 le scanner condamnerait le rendu d\'une valeur d\'hôte');
    });
  });

  group('🏷 aucun nom d\'application hôte dans un assemblage', () {
    test('aucun fichier ne nomme un hôte', () {
      for (final File file in _presetFiles()) {
        expect(_hostNameHits(file.readAsStringSync()), isEmpty,
            reason: '🔴 nom d\'application hôte dans ${file.path} — un preset '
                'nomme une direction de design, jamais un client');
      }
    });

    test('la garde MORD : un nom d\'hôte injecté est signalé', () {
      expect(_hostNameHits('/// Peau IFFD de la session.'), isNotEmpty);
      expect(_hostNameHits('// porté depuis lex_douane'), isNotEmpty);
      expect(_hostNameHits('// variante DODLP'), isNotEmpty);
      expect(_hostNameHits('final flex = 3; // complexe'), isEmpty,
          reason: '🔴 le scanner condamnerait `flex` et `complexe`');
    });
  });
}
