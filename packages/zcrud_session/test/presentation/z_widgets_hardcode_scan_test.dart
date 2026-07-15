/// AC4 — ZÉRO couleur/label en dur dans les 3 widgets de présentation.
/// AC5 — ZÉRO API non-directionnelle, ZÉRO `ListView(children:)`.
///
/// Scan des SOURCES (`dart:io`) des fichiers `lib/src/presentation/`. Discriminants
/// INJ-4 (`Colors.`/`Color(0x`) et INJ-5 (`EdgeInsets.only(left:` etc.).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**` — jamais
/// une liste figée : un futur widget codant `Colors.*`/API non-directionnelle
/// est capté sans édition du test (durabilité de la garde, R16).
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

/// Motifs de **couleur en dur** interdits (FR-26/AD-6 — AC4).
const List<String> _bannedColorPatterns = <String>[
  'Colors.',
  'Color(0x',
  'AppColors.',
];

/// Motifs **non-directionnels** interdits (AD-13 — AC5).
const List<String> _bannedDirectionalPatterns = <String>[
  'EdgeInsets.only(left:',
  'EdgeInsets.only(right:',
  'Alignment.centerLeft',
  'Alignment.centerRight',
  'Alignment.topLeft',
  'Alignment.topRight',
  'Alignment.bottomLeft',
  'Alignment.bottomRight',
  'TextAlign.left',
  'TextAlign.right',
  'Positioned(left:',
  'Positioned(right:',
  'ListView(children:',
];

List<String> _scan(List<String> patterns) {
  final violations = <String>[];
  for (final path in _presentationFiles()) {
    final file = File(path);
    expect(file.existsSync(), isTrue,
        reason: 'fichier introuvable: $path (cwd=${Directory.current.path})');
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      // Les lignes de commentaire/doc ne sont pas du code : elles CITENT
      // légitimement les motifs interdits (ex. « jamais de `Colors.*` »).
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*')) {
        continue;
      }
      for (final pattern in patterns) {
        if (lines[i].contains(pattern)) {
          violations.add('$path:${i + 1} → $pattern :: $trimmed');
        }
      }
    }
  }
  return violations;
}

void main() {
  test('AC4 — aucune couleur en dur (Colors./Color(0x/AppColors.)', () {
    final violations = _scan(_bannedColorPatterns);
    expect(violations, isEmpty,
        reason: 'couleur codée en dur détectée :\n${violations.join('\n')}');
  });

  test('AC5 — aucune API non-directionnelle ni ListView(children:)', () {
    final violations = _scan(_bannedDirectionalPatterns);
    expect(violations, isEmpty,
        reason:
            'API non-directionnelle / ListView(children:) :\n${violations.join('\n')}');
  });
}
