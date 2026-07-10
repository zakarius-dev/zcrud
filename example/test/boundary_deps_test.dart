import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'AC12 — l\'app dépend de zcrud_core + 3 bindings + zcrud_list + les 5 '
      'satellites EX-3 ; flashcard/mindmap (E9/E10) restent INTERDITS', () {
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

    // Frontière EX-3 (CLÔTURE de l'epic EX) : `zcrud_markdown`/`_geo`/`_intl`/
    // `_export`/`_firestore` sont désormais AUTORISÉS (démos MVP restantes, tirent
    // Quill/flutter_map/Syncfusion/Firebase/Hive via l'app — SM-5). Seuls
    // `zcrud_flashcard` (E9) et `zcrud_mindmap` (E10) restent INTERDITS (v1.x).
    const forbidden = <String>[
      'zcrud_flashcard',
      'zcrud_mindmap',
    ];
    for (final pkg in forbidden) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isFalse,
          reason: 'Frontière EX-3 violée : $pkg (E9/E10, v1.x) ne doit pas '
              'être une dépendance');
    }

    // Les 10 paquets zcrud attendus sont bien déclarés.
    for (final pkg in <String>[
      'zcrud_core',
      'zcrud_get',
      'zcrud_riverpod',
      'zcrud_provider',
      'zcrud_list',
      'zcrud_markdown',
      'zcrud_geo',
      'zcrud_intl',
      'zcrud_export',
      'zcrud_firestore',
    ]) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isTrue, reason: '$pkg attendu');
    }
  });
}
