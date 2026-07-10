// AC5/AC9 — gardes statiques E9-5 (AD-1/AD-13/FR-26/AD-2/AD-15), rejouées comme
// tests. Reprend le patron E11b-2 (AI-E10-2) : garde grep **cwd-robuste** +
// **strip-comment**, denylist complète (couleurs/directionnel/gestionnaires
// d'état) sur `packages/zcrud_flashcard/lib/`, + isolation AD-1 (aucun backend
// Firebase/Hive/Syncfusion, aucune arête vers le paquet adaptateur).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Libs backend/lourdes à NE JAMAIS tirer dans `zcrud_flashcard` (AD-1) :
const _bannedBackendLibs = <String>[
  'cloud_firestore',
  'firebase_core',
  'firebase_auth',
  'package:hive',
  'hive_flutter',
  'zcrud_firestore',
  'syncfusion_flutter',
];

/// Gestionnaires d'état bannis du cœur/satellites réactifs (AD-2/AD-15).
const _bannedManagers = <String>[
  'package:flutter_riverpod',
  'package:riverpod',
  'package:get/',
  'package:provider/',
];

/// Lecture **cwd-robuste** : passe que `flutter test` soit lancé à la racine du
/// workspace OU dans le dossier du package.
String _read(String path) {
  final candidates = <String>[path, '../../$path', _underPackage(path)];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $path');
}

String _underPackage(String repoPath) {
  const prefix = 'packages/zcrud_flashcard/';
  return repoPath.startsWith(prefix) ? repoPath.substring(prefix.length) : repoPath;
}

Directory _libDir() => Directory('packages/zcrud_flashcard/lib').existsSync()
    ? Directory('packages/zcrud_flashcard/lib')
    : Directory('lib');

/// Supprime les commentaires Dart (`// …` et `/* … */`) pour qu'un motif cité en
/// commentaire ne déclenche PAS de faux positif (AI-E10-2).
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

Iterable<File> _dartFiles() => _libDir()
    .listSync(recursive: true)
    .whereType<File>()
    .where((e) => e.path.endsWith('.dart') && !e.path.endsWith('.g.dart'));

/// Denylist FR-26/AD-13 (AI-E10-2) — motifs interdits dans le source dé-commenté.
final _bannedPatterns = <RegExp>[
  RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
  RegExp(r'Alignment\.center(Left|Right)\b'),
  RegExp(r'TextAlign\.(left|right)\b'),
  RegExp(r'Positioned\([^)]*\b(left|right)\s*:'),
  RegExp(r'\bColors\.'),
  RegExp(r'Color\(0x'),
];

void main() {
  group('AC9 — isolation AD-1 : aucun backend/manager/Syncfusion', () {
    test('lib/ n\'importe aucun backend Firebase/Hive/Syncfusion/adaptateur', () {
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final lib in _bannedBackendLibs) {
          expect(src.contains(lib), isFalse,
              reason: 'AD-1 : ${e.path} ne doit PAS tirer $lib');
        }
      }
    });

    test('lib/ n\'importe aucun gestionnaire d\'état (AD-2/AD-15)', () {
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final m in _bannedManagers) {
          expect(src.contains(m), isFalse,
              reason: 'gestionnaire d\'état interdit dans ${e.path} : $m');
        }
      }
    });

    test('pubspec flashcard n\'ajoute aucune dép backend/manager/Syncfusion', () {
      final pubspec = _read('packages/zcrud_flashcard/pubspec.yaml');
      for (final lib in <String>[
        'cloud_firestore',
        'firebase_core',
        'hive',
        'zcrud_firestore',
        'syncfusion_flutter_datagrid',
        'flutter_riverpod',
        'get',
        'provider',
      ]) {
        expect(RegExp('^\\s+$lib:', multiLine: true).hasMatch(pubspec), isFalse,
            reason: 'zcrud_flashcard ne doit PAS dépendre de $lib (AD-1)');
      }
    });
  });

  group('AC5 — FR-26/AD-13 : garde grep exhaustive (strip-comment, cwd-robuste)',
      () {
    test('lib/ sans couleur codée en dur ni motif non directionnel', () {
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final re in _bannedPatterns) {
          expect(re.hasMatch(src), isFalse,
              reason: 'motif interdit (FR-26/AD-13) dans ${e.path} : '
                  '${re.pattern}');
        }
      }
    });

    test('(méta) la garde DÉTECTE un motif interdit injecté', () {
      // Preuve que le scanner n'est pas vacant : un échantillon fautif matche.
      const injected = 'Container(color: Colors.red);';
      final hit = _bannedPatterns.any((re) => re.hasMatch(injected));
      expect(hit, isTrue,
          reason: 'la denylist doit détecter un Colors. injecté');
      // Et le strip-comment neutralise le même motif en commentaire.
      final commented = _stripComments('// $injected');
      expect(_bannedPatterns.any((re) => re.hasMatch(commented)), isFalse,
          reason: 'un motif en commentaire ne doit PAS matcher (strip-comment)');
    });
  });
}
