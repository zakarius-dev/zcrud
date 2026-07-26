import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fichiers source de la story SUF-1 (page-shell).
const _storyFiles = <String>[
  'lib/src/domain/z_app_bar_action.dart',
  'lib/src/domain/z_app_bar_search_config.dart',
  'lib/src/domain/z_page_tab.dart',
  'lib/src/domain/z_page_app_bar_mode.dart',
  'lib/src/presentation/z_page_shell.dart',
  'lib/src/presentation/z_searchable_app_bar.dart',
  'lib/src/presentation/z_page_scaffold.dart',
];

/// Retire les commentaires de ligne (`//` et `///`) pour éviter les
/// faux-positifs sur la dartdoc.
String _stripComments(String source) {
  final buffer = StringBuffer();
  for (final line in source.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

String _readCode(String path) => _stripComments(File(path).readAsStringSync());

void main() {
  // AC12 — zéro couleur codée en dur (hors Colors.transparent).
  test('AC12: aucune couleur littérale (Color(0x / Colors.<x>)', () {
    for (final path in _storyFiles) {
      final code = _readCode(path).replaceAll(RegExp(r'\s+'), '');
      expect(code.contains('Color(0x'), isFalse, reason: '$path: Color(0x…)');
      final colorsHits = RegExp(r'Colors\.(?!transparent)')
          .allMatches(code)
          .map((m) => m.group(0))
          .toList();
      expect(colorsHits, isEmpty, reason: '$path: littéral Colors.<x>');
    }
  });

  // AC14 — aucune forme non directionnelle (RTL).
  test('AC14: aucune forme non directionnelle (left/right)', () {
    const forbidden = <String>[
      'EdgeInsets.only(left:',
      'EdgeInsets.only(right:',
      'EdgeInsets.only(left ',
      'Positioned(left:',
      'Positioned(right:',
      'Alignment.centerLeft',
      'Alignment.centerRight',
      'TextAlign.left',
      'TextAlign.right',
    ];
    for (final path in _storyFiles) {
      final code = _readCode(path).replaceAll(RegExp(r'\s+'), '');
      for (final needle in forbidden) {
        final compact = needle.replaceAll(' ', '');
        expect(code.contains(compact), isFalse, reason: '$path: $needle');
      }
    }
  });

  // AC15 — aucun import de gestionnaire d'état / routeur / tiers / dartz.
  test('AC15: aucun import interdit', () {
    const forbidden = <String>[
      'package:get/',
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:provider/',
      'package:go_router/',
      'package:dartz/',
    ];
    for (final path in _storyFiles) {
      final code = _readCode(path);
      for (final needle in forbidden) {
        expect(code.contains(needle), isFalse, reason: '$path: import $needle');
      }
    }
  });
}
