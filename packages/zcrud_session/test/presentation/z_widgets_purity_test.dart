/// AC9 — pureté runtime des widgets de PRÉSENTATION (AD-2/AD-15/AD-23).
///
/// Les 3 widgets `ZSrsQualityButtons`/`ZSessionQualityBreakdown`/
/// `ZStudyProgressRings` sont des `StatelessWidget` PURS : ils n'importent NI un
/// moteur de session (`z_study_session_engine`/`z_white_exam_session_engine`/
/// `z_linear_session_state`), NI un `ZRepetitionStore`, NI un gestionnaire
/// d'état (Riverpod/GetX/provider). `simulate` n'est appelé que côté APPELANT
/// (seam `previewLabelFor`) — aucun `apply`/`put`/`reviewCard` dans les widgets.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**` — jamais
/// une liste figée : un futur widget de présentation est capté sans édition du
/// test (durabilité de la garde, R16).
List<String> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: $root (cwd=${Directory.current.path})');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// Imports/symboles interdits dans les widgets (couplage runtime / état / SRS).
const List<String> _bannedImports = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:get/',
  'package:provider/',
  'z_study_session_engine.dart',
  'z_white_exam_session_engine.dart',
  'z_linear_session_state.dart',
];

/// Symboles d'ÉCRITURE SRS interdits (AD-23 : projection pure seule).
const List<String> _bannedWriteSymbols = <String>[
  'ZRepetitionStore',
  '.apply(',
  '.reviewCard(',
];

void main() {
  test('AC9 — aucun import de moteur / état ; aucune écriture SRS', () {
    final violations = <String>[];
    for (final path in _presentationFiles()) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'introuvable: $path');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
          for (final banned in _bannedImports) {
            if (trimmed.contains(banned)) {
              violations.add('$path:${i + 1} → import banni: $banned');
            }
          }
        }
        for (final banned in _bannedWriteSymbols) {
          if (line.contains(banned)) {
            violations.add('$path:${i + 1} → écriture SRS interdite: $banned');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'couplage runtime / écriture SRS détecté :\n'
            '${violations.join('\n')}');
  });
}
