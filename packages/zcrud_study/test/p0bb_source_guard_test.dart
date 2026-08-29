// P0b-B — gardes STATIQUES de source sur les surfaces de structure d'étude :
// FR-26 (aucune couleur littérale, aucun libellé en dur), AD-13 (aucune
// variante directionnelle interdite) et virtualisation obligatoire du
// sélecteur.
//
// Accès `dart:io` ⇒ `@TestOn('vm')` (le gate `web` compile ce paquet vers
// Node : sans cette annotation, la garde rougirait en JS).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show stripped;

/// Fichiers RÉELLEMENT écrits par P0b-B (chemins RELATIFs au package).
const List<String> _p0bbFiles = <String>[
  'lib/src/domain/z_study_scope_filtering.dart',
  'lib/src/presentation/z_study_path_bar.dart',
  'lib/src/presentation/z_study_scope_bar.dart',
  'lib/src/presentation/z_study_unit_picker.dart',
];

/// Lignes de CODE (commentaires dépouillés — sans quoi la garde mordrait sur
/// de la PROSE de dartdoc et non sur du code).
List<String> _codeLines(String path) {
  final File file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'introuvable: $path (cwd=${Directory.current.path}) — lancer '
        '`flutter test` DEPUIS le dossier du package',
  );
  return stripped(file);
}

void main() {
  group('FR-26 — aucune couleur littérale', () {
    final RegExp colorRe = RegExp(r'\bColor\(0x|\bColors\.');

    test('0 littéral de couleur dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p0bbFiles) {
        for (final String line in _codeLines(path)) {
          if (colorRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            '🔴 couleur codée en dur :\n${violations.join('\n')}\n'
            'Toute couleur vient du `ColorScheme`/`ZcrudTheme` ou de la '
            'palette signature du socle (FR-26).',
      );
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE une couleur injectée', () {
      expect(colorRe.hasMatch('    color: const Color(0xFF388E3C),'), isTrue);
      expect(colorRe.hasMatch('    color: Colors.red,'), isTrue);
      expect(colorRe.hasMatch('    gradient: spec.gradient,'), isFalse);
    });
  });

  group('FR-26 — aucun libellé en dur', () {
    final RegExp literalTextRe = RegExp(r'''\bText\(\s*['"]''');

    test('0 `Text(<littéral>)` dans les fichiers du lot', () {
      final List<String> violations = <String>[];
      for (final String path in _p0bbFiles) {
        for (final String line in _codeLines(path)) {
          if (literalTextRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            '🔴 libellé codé en dur :\n${violations.join('\n')}\n'
            'Les libellés viennent des instantanés `ZStudyRef` ou d\'un '
            'constructeur injecté (FR-26).',
      );
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE un libellé injecté', () {
      expect(literalTextRe.hasMatch("      child: Text('Portée'),"), isTrue);
      expect(literalTextRe.hasMatch('      child: Text("Unité"),'), isTrue);
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
      for (final String path in _p0bbFiles) {
        for (final String line in _codeLines(path)) {
          if (nonDirectionalRe.hasMatch(line)) {
            violations.add('$path → « ${line.trim()} »');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            '🔴 variante non directionnelle :\n${violations.join('\n')}\n'
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

  group(
    'Virtualisation — le sélecteur ne matérialise JAMAIS tout l\'arbre',
    () {
      const String picker = 'lib/src/presentation/z_study_unit_picker.dart';
      final RegExp eagerListRe = RegExp(
        r'ListView\(|Column\(\s*children:\s*\[',
      );

      test('`ListView.builder` PRÉSENT, aucune liste matérialisée', () {
        final List<String> lines = _codeLines(picker);
        expect(
          lines.any((String l) => l.contains('ListView.builder(')),
          isTrue,
          reason:
              '🔴 le sélecteur doit virtualiser ses rangées : un arbre de '
              'structure peut porter des milliers de nœuds.',
        );

        final List<String> violations = <String>[
          for (final String line in lines)
            if (eagerListRe.hasMatch(line)) '« ${line.trim()} »',
        ];
        expect(
          violations,
          isEmpty,
          reason: '🔴 liste matérialisée :\n${violations.join('\n')}',
        );
      });

      test('CONTRE-PREUVE : le scanner ATTRAPE une liste matérialisée', () {
        expect(
          eagerListRe.hasMatch('    return ListView(children: rows);'),
          isTrue,
        );
        expect(
          eagerListRe.hasMatch('    return ListView.builder(itemCount: n);'),
          isFalse,
        );
      });
    },
  );
}
