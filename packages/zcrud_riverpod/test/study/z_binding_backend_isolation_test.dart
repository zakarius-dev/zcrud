// ES-10.2 AC2 — le binding NE dépend PAS du backend (isolement AD-15/AD-5).
//
// Les providers TYPÉS résolvent le repo PAR SEAM (injecté par lex) : le binding
// n'importe JAMAIS `zcrud_firestore`/`cloud_firestore`/`hive`. Garde de surface :
//  (1) aucun symbole backend (`cloud_firestore`, `FirebaseFirestore`, `Box`,
//      `package:zcrud_firestore`, `package:hive`) dans le CODE de `lib/`
//      (commentaires strippés — les dartdoc peuvent NOMMER ces packages pour
//      documenter la frontière, mais aucune LIGNE DE CODE ne les référence) ;
//  (2) le pubspec ne liste (hors commentaires `#`) aucune dépendance backend.
//
// R3-I3 — ajouter `import 'package:cloud_firestore/…'` (ou `zcrud_firestore` au
//         pubspec) dans `lib/src/study/` ⇒ CE test rougit (et `graph_proof`
//         diverge).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _base() {
  for (final base in <String>['', 'packages/zcrud_riverpod/']) {
    if (Directory('${base}lib').existsSync()) return base;
  }
  fail('lib/ introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Retire le commentaire de ligne (`//`, dartdoc `///` inclus) — la frontière
/// AD-5 peut être DOCUMENTÉE en nommant le backend, jamais RÉFÉRENCÉE en code.
String _stripDartComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// Retire le commentaire YAML (`#`).
String _stripYamlComment(String line) {
  final i = line.indexOf('#');
  return i < 0 ? line : line.substring(0, i);
}

void main() {
  const forbiddenInCode = <String>[
    'cloud_firestore',
    'FirebaseFirestore',
    'package:zcrud_firestore',
    'package:hive',
  ];

  test('AC2 — zcrud_riverpod/lib ne référence AUCUN symbole backend en code '
      '[R3-I3]', () {
    final libDir = Directory('${_base()}lib');
    final offenders = <String>[];
    for (final file in _dartFiles(libDir)) {
      final lines = file.readAsLinesSync();
      for (var n = 0; n < lines.length; n++) {
        final code = _stripDartComment(lines[n]);
        for (final needle in forbiddenInCode) {
          if (code.contains(needle)) {
            offenders.add('${file.path}:${n + 1} → "$needle"');
          }
        }
        // `Box` en tant que TYPE Hive (borné mot) — évite `Toolbox`, `checkbox`…
        if (RegExp(r'(^|[^A-Za-z0-9_])Box([^A-Za-z0-9_]|$)').hasMatch(code)) {
          offenders.add('${file.path}:${n + 1} → "Box"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Le binding doit résoudre le repo PAR SEAM (injecté par lex), '
          'jamais importer un backend (AD-5/AD-15). Occurrences :\n'
          '${offenders.join('\n')}',
    );
  });

  test('AC2 — pubspec.yaml ne déclare AUCUNE dépendance backend (hors '
      'commentaires) [R3-I3]', () {
    final pubspec = File('${_base()}pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml introuvable');

    const forbiddenDeps = <String>[
      'zcrud_firestore',
      'cloud_firestore',
      'firebase_core',
      'hive',
    ];
    final offenders = <String>[];
    final lines = pubspec.readAsLinesSync();
    for (var n = 0; n < lines.length; n++) {
      final code = _stripYamlComment(lines[n]);
      for (final needle in forbiddenDeps) {
        if (code.contains(needle)) {
          offenders.add('${pubspec.path}:${n + 1} → "$needle"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Le binding ne doit lister aucun backend en dépendance '
          '(l\'adapter folder-scopé est injecté au seam par lex). Occurrences :\n'
          '${offenders.join('\n')}',
    );
  });
}
