/// P1-G — gardes STATIQUES de source sur la présentation podcast livrée :
/// FR-26 (aucune couleur littérale, aucun libellé en dur) et AD-13 (aucune
/// variante directionnelle interdite).
///
/// Accès `dart:io` ⇒ `@TestOn('vm')` (le gate `web` compile ce paquet vers
/// Node : sans cette annotation, la garde rougirait en JS).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show stripped;

/// Fichiers RÉELLEMENT écrits par P1-G (chemins RELATIFs au package).
const List<String> _p1gFiles = <String>[
  'lib/src/presentation/z_podcast_card.dart',
  'lib/src/presentation/z_podcast_audio_player.dart',
  'lib/src/presentation/z_podcast_generation_controller.dart',
  'lib/src/presentation/z_podcast_hub_entry.dart',
];

/// Lignes de CODE (commentaires dépouillés — sans quoi la garde mordrait sur
/// de la PROSE de dartdoc et non sur du code).
List<String> _codeLines(String path) {
  final File file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'introuvable: $path (cwd=${Directory.current.path}) — lancer '
        '`flutter test` DEPUIS le dossier du package',
  );
  return stripped(file);
}

void main() {
  group('FR-26 — aucune couleur littérale dans la présentation podcast', () {
    final RegExp colorRe = RegExp(r'\bColor\(0x|\bColors\.');

    test('0 littéral de couleur dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1gFiles) {
        final List<String> lines = _codeLines(path);
        for (final String line in lines) {
          if (colorRe.hasMatch(line)) violations.add('$path → « ${line.trim()} »');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '🔴 couleur codée en dur :\n${violations.join('\n')}\n'
            'Toute couleur vient du `ColorScheme`/`ZcrudTheme` (FR-26).',
      );
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE une couleur injectée', () {
      expect(colorRe.hasMatch('    color: const Color(0xFF388E3C),'), isTrue);
      expect(colorRe.hasMatch('    color: Colors.red,'), isTrue);
      // …et laisse passer un rôle du thème.
      expect(colorRe.hasMatch('    color: theme.colorScheme.error,'), isFalse);
    });
  });

  group('FR-26 — aucun libellé en dur', () {
    // Un `Text('…')` littéral est la forme exacte que le socle s'interdit :
    // tout texte rendu est INJECTÉ par l'hôte.
    final RegExp literalTextRe = RegExp(r'''\bText\(\s*['"]''');

    test('0 `Text(<littéral>)` dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1gFiles) {
        for (final String line in _codeLines(path)) {
          if (literalTextRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '🔴 libellé codé en dur :\n${violations.join('\n')}\n'
            'Aucun texte rendu par ce paquet (FR-26).',
      );
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE un libellé injecté', () {
      expect(literalTextRe.hasMatch("      child: Text('Régénérer'),"), isTrue);
      expect(literalTextRe.hasMatch('      child: Text("Podcast"),'), isTrue);
      // …et laisse passer un texte porté par une variable.
      expect(literalTextRe.hasMatch('      child: Text(label),'), isFalse);
    });
  });

  group('AD-13 — aucune variante NON directionnelle', () {
    final RegExp nonDirectionalRe = RegExp(
      r'EdgeInsets\.only\(\s*(left|right)\s*:|Alignment\.center(Left|Right)\b'
      r'|Positioned\(\s*(left|right)\s*:|TextAlign\.(left|right)\b',
    );

    test('0 variante physique dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1gFiles) {
        for (final String line in _codeLines(path)) {
          if (nonDirectionalRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '🔴 variante non directionnelle :\n${violations.join('\n')}\n'
            'Utiliser les variantes directionnelles (AD-13).',
      );
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE une variante physique', () {
      expect(
        nonDirectionalRe.hasMatch('  padding: const EdgeInsets.only(left: 8),'),
        isTrue,
      );
      expect(nonDirectionalRe.hasMatch('  textAlign: TextAlign.left,'), isTrue);
      // …et laisse passer les variantes directionnelles.
      expect(
        nonDirectionalRe.hasMatch(
          '  padding: const EdgeInsetsDirectional.only(start: 8),',
        ),
        isFalse,
      );
      expect(nonDirectionalRe.hasMatch('  textAlign: TextAlign.start,'), isFalse);
    });
  });
}
