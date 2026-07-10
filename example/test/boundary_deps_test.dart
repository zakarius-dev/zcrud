import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'AC10 — l\'app ne dépend QUE de zcrud_core + les 3 bindings (aucun package '
      'de démo E4/E5/E6/E11a)', () {
    // `flutter test` s\'exécute depuis la racine du package `example/`.
    // On strippe les COMMENTAIRES (qui mentionnent les paquets interdits à titre
    // explicatif) pour ne tester que les vraies déclarations de dépendances.
    final withoutComments = File('pubspec.yaml')
        .readAsLinesSync()
        .map((l) {
          final hash = l.indexOf('#');
          return hash >= 0 ? l.substring(0, hash) : l;
        })
        .join('\n');

    const forbidden = <String>[
      'zcrud_list',
      'zcrud_firestore',
      'zcrud_markdown',
      'zcrud_geo',
      'zcrud_intl',
      'zcrud_export',
    ];
    for (final pkg in forbidden) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isFalse,
          reason: 'Frontière EX-1 violée : $pkg ne doit pas être une dépendance');
    }

    // Les dépendances attendues sont bien déclarées.
    for (final pkg in <String>[
      'zcrud_core',
      'zcrud_get',
      'zcrud_riverpod',
      'zcrud_provider',
    ]) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isTrue, reason: '$pkg attendu');
    }
  });
}
