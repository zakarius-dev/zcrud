@TestOn('vm')
library;

// Une palette porte un nom de THÈME, jamais un nom d'application. Nommer un
// hôte dans `lib/` ferait de ce paquet la propriété d'un consommateur, alors
// qu'il est offert à tous — et gèlerait le nom d'un client dans une API
// publique.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'z_package_root.dart';

/// Noms d'hôtes interdits dans `lib/`, en minuscules (la comparaison est
/// insensible à la casse : `IFFD` comme `iffd`).
const List<String> _hostNames = <String>[
  'iffd',
  'lex_douane',
  'lexdouane',
  'dodlp',
  'dlcfti',
];

void main() {
  test('aucun nom d\'application hôte dans lib/', () {
    final List<File> sources = zThemesLibSources();
    expect(sources, isNotEmpty,
        reason: 'lib/ vide : la garde ne mesurerait rien.');

    final List<String> offences = <String>[];
    for (final File file in sources) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String lower = lines[i].toLowerCase();
        for (final String host in _hostNames) {
          if (lower.contains(host)) {
            offences.add('${file.path}:${i + 1}: $host');
          }
        }
      }
    }
    expect(
      offences,
      isEmpty,
      reason: 'Nom d\'hôte dans lib/ :\n${offences.join('\n')}',
    );
  });
}
