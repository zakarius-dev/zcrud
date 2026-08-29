/// P1-H — gardes STATIQUES de source sur les surfaces de partage livrées :
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

/// Fichiers RÉELLEMENT écrits par P1-H (chemins RELATIFs au package).
const List<String> _p1hFiles = <String>[
  'lib/src/presentation/z_folder_sharing_sheet.dart',
  'lib/src/presentation/z_public_gallery_view.dart',
  'lib/src/presentation/z_study_sharing_entries.dart',
  'lib/src/presentation/z_study_sharing_gate.dart',
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
  group('FR-26 — aucune couleur littérale dans la présentation de partage', () {
    final RegExp colorRe = RegExp(r'\bColor\(0x|\bColors\.');

    test('0 littéral de couleur dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1hFiles) {
        for (final String line in _codeLines(path)) {
          if (colorRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
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
      expect(colorRe.hasMatch('    color: theme.colorScheme.error,'), isFalse);
    });
  });

  group('FR-26 — aucun libellé en dur', () {
    final RegExp literalTextRe = RegExp(r'''\bText\(\s*['"]''');

    test('0 `Text(<littéral>)` dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1hFiles) {
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
      expect(literalTextRe.hasMatch("      child: Text('Partager'),"), isTrue);
      expect(literalTextRe.hasMatch('      child: Text("Galerie"),'), isTrue);
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
      for (final String path in _p1hFiles) {
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
      expect(
        nonDirectionalRe.hasMatch(
          '  padding: const EdgeInsetsDirectional.only(start: 8),',
        ),
        isFalse,
      );
      expect(
        nonDirectionalRe.hasMatch('  textAlign: TextAlign.start,'),
        isFalse,
      );
    });
  });

  group('AD-12 — aucun secret, aucun backend en surface', () {
    // Le partage est la surface la plus exposée à une fuite d'endpoint : elle
    // manipule des liens. Aucun schéma d'URL, aucun nom de collection.
    final RegExp leakRe = RegExp(
      r'https?://|firebaseio|firestore|apiKey|Bearer\s',
      caseSensitive: false,
    );

    test('0 fuite dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p1hFiles) {
        for (final String line in _codeLines(path)) {
          if (leakRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(violations, isEmpty, reason: '🔴 fuite :\n${violations.join('\n')}');
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE une fuite injectée', () {
      expect(leakRe.hasMatch("  const base = 'https://example.test/s/';"), isTrue);
      expect(leakRe.hasMatch("  final c = 'firestore/shareLinks';"), isTrue);
      expect(leakRe.hasMatch('  final String token = link.token;'), isFalse);
    });
  });
}
