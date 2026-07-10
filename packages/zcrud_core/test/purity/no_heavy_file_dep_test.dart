// AC13 (E3-3c, AD-1) — Preuve « cœur OUT=0 » pour le champ fichier : `zcrud_core`
// ne tire AUCUNE dépendance lourde d'acquisition/stockage. (a) `pubspec.yaml`
// sans `image_picker`/`file_picker`/`firebase*` ; (b) `lib/` sans occurrence
// TEXTUELLE d'un import de ces packages. Le picker + le storage sont des SEAMS
// injectés (impls hors cœur : app/binding pour E7, `zcrud_firestore` pour E5).
import 'dart:io';

import 'package:test/test.dart';

/// Packages lourds INTERDITS dans `zcrud_core` (acquisition/stockage fichier).
const _forbiddenPackages = <String>[
  'image_picker',
  'file_picker',
  'firebase_storage',
  'firebase_core',
  'cloud_firestore',
  'firebase',
];

Directory _dir(String rel) {
  for (final base in <String>['', 'packages/zcrud_core/']) {
    final d = Directory('$base$rel');
    if (d.existsSync()) return d;
  }
  fail('$rel introuvable depuis ${Directory.current.path}');
}

File _file(String rel) {
  for (final base in <String>['', 'packages/zcrud_core/']) {
    final f = File('$base$rel');
    if (f.existsSync()) return f;
  }
  fail('$rel introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Retire la partie commentaire (les doc-comments citent légitimement les
/// packages interdits pour documenter qu'ils ne doivent jamais être tirés).
String _stripComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

void main() {
  test('pubspec.yaml : aucune dépendance lourde image/file/firebase (AC13a)', () {
    final lines = _file('pubspec.yaml').readAsLinesSync();
    // Retire les commentaires `#` (les commentaires citent E5/E7 légitimement).
    final code = lines
        .map((l) {
          final i = l.indexOf('#');
          return i < 0 ? l : l.substring(0, i);
        })
        .join('\n');
    for (final pkg in _forbiddenPackages) {
      expect(code.contains(pkg), isFalse,
          reason: 'pubspec.yaml ne doit PAS déclarer "$pkg" (AD-1)');
    }
  });

  test('lib/ : aucun import textuel de package lourd fichier (AC13d)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_dir('lib'))) {
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final line = _stripComment(raw);
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        for (final pkg in _forbiddenPackages) {
          if (line.contains('package:$pkg')) {
            offenders.add('${file.path}:$lineNo → $trimmed');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Imports lourds interdits dans zcrud_core/lib (AD-1):\n'
            '${offenders.join('\n')}');
  });
}
