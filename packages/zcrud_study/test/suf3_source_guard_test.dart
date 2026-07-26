/// SUF-3 gardes STATIQUES de source (AC1 : aucune app-bar réimplémentée ; AC16 :
/// aucun gestionnaire d'état/routeur importé). Scan des fichiers de la story.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fichiers RÉELLEMENT écrits par SUF-3 (chemins RELATIFs au package).
const List<String> _suf3Files = <String>[
  'lib/src/presentation/z_study_folder_detail.dart',
  'lib/src/presentation/z_subfolder_ref.dart',
  'lib/src/presentation/z_subfolder_nav_spec.dart',
  'lib/src/presentation/z_subfolder_sidebar.dart',
  'lib/src/presentation/z_subfolder_compact_selector.dart',
  'lib/src/presentation/z_subfolder_item_chrome.dart',
];

/// Lignes de CODE (hors commentaires `//` / `///`).
List<String> _codeLines(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue,
      reason: 'introuvable: $path (cwd=${Directory.current.path}) — lancer '
          '`flutter test` DEPUIS le package');
  return file
      .readAsLinesSync()
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///');
      })
      .toList();
}

void main() {
  group('AC1 — aucune app-bar réimplémentée (délégation à SUF-1)', () {
    final appBarRe = RegExp(r'\b(AppBar|SliverAppBar)\s*\(');

    test('0 AppBar(/SliverAppBar( dans les fichiers de la story', () {
      final violations = <String>[];
      for (final path in _suf3Files) {
        final lines = _codeLines(path);
        for (var i = 0; i < lines.length; i++) {
          if (appBarRe.hasMatch(lines[i])) {
            violations.add('$path → « ${lines[i].trim()} »');
          }
        }
      }
      expect(violations, isEmpty,
          reason: '🔴 app-bar réimplémentée :\n${violations.join('\n')}\n'
              'Le shell d\'app-bar est délégué à `ZPageScaffold` (SUF-1).');
    });

    test('CONTRE-PREUVE : le scanner ATTRAPE un AppBar( injecté', () {
      expect(appBarRe.hasMatch('    appBar: AppBar(title: t),'), isTrue);
      expect(appBarRe.hasMatch('  const SliverAppBar(pinned: true),'), isTrue);
      // …mais pas une simple mention en prose/identifiant composé.
      expect(appBarRe.hasMatch('  ZSearchableAppBarConfig x;'), isFalse);
    });
  });

  group('AC16 — aucun gestionnaire d\'état / routeur / tiers UI', () {
    const bannedImports = <String>[
      'package:get/',
      'package:flutter_riverpod/',
      'package:provider/',
      'package:go_router/',
    ];

    test('0 import banni dans les fichiers de la story', () {
      final violations = <String>[];
      for (final path in _suf3Files) {
        for (final line in _codeLines(path)) {
          if (line.startsWith('import ')) {
            for (final banned in bannedImports) {
              if (line.contains(banned)) {
                violations.add('$path → « ${line.trim()} »');
              }
            }
          }
        }
      }
      expect(violations, isEmpty,
          reason: '🔴 import interdit :\n${violations.join('\n')}\n'
              'AD-2/AD-15 : réactivité Flutter-native pure, aucun manager/routeur.');
    });
  });
}
