// ES-11.1 AC8 (R28/AD-5/AD-15) — le binding study est GÉNÉRIQUE : ni backend, ni
// entité concrète dans `lib/` ou le `pubspec.yaml`.
//
// Garde de surface (miroir du test `zcrud_riverpod`) :
//  (1) aucun symbole backend (`cloud_firestore`, `FirebaseFirestore`, `Box`,
//      `package:zcrud_firestore`, `package:hive`) dans le CODE de `lib/`
//      (commentaires strippés — un dartdoc peut NOMMER la frontière, jamais la
//      RÉFÉRENCER en code) ;
//  (2) le pubspec ne liste (hors commentaires `#`) AUCUN backend NI AUCUN package
//      d'ENTITÉ `zcrud_*` (les 6 entités déférées/E9-E10 + document/note/exam/
//      session) — deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` EXACTEMENT.
//
// R3-I7 — ajouter `import 'package:cloud_firestore/…'` (ou une dep entité/backend
//          au pubspec) ⇒ CE test rougit (et `graph_proof` diverge / `verify`
//          casse repo-wide).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _base() {
  for (final base in <String>['', 'packages/zcrud_get/']) {
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

  test('AC8 — zcrud_get/lib ne référence AUCUN symbole backend en code [R3-I7]',
      () {
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
      reason: 'Le binding study doit résoudre le repo PAR SEAM (injecté par '
          'l\'app), jamais importer un backend (AD-5/AD-15/R28). Occurrences :\n'
          '${offenders.join('\n')}',
    );
  });

  test('AC8 — pubspec.yaml ne déclare AUCUN backend NI AUCUNE entité concrète '
      '(hors commentaires) — deps zcrud_* = core + study_kernel [R3-I7]', () {
    final pubspec = File('${_base()}pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml introuvable');

    // Backends lourds interdits.
    const forbiddenBackends = <String>[
      'zcrud_firestore',
      'cloud_firestore',
      'firebase_core',
      'hive',
    ];
    // Packages d'ENTITÉ concrète interdits (R28 — le binding NAÎT générique).
    const forbiddenEntities = <String>[
      'zcrud_document',
      'zcrud_note',
      'zcrud_exam',
      'zcrud_session',
      'zcrud_flashcard',
      'zcrud_mindmap',
      'zcrud_study:', // 'zcrud_study' aggregate (≠ 'zcrud_study_kernel')
    ];
    final offenders = <String>[];
    final lines = pubspec.readAsLinesSync();
    for (var n = 0; n < lines.length; n++) {
      final code = _stripYamlComment(lines[n]);
      for (final needle in <String>[...forbiddenBackends, ...forbiddenEntities]) {
        if (code.contains(needle)) {
          offenders.add('${pubspec.path}:${n + 1} → "$needle"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Le binding ne doit lister aucun backend ni aucune entité concrète '
          '(spécialisation typée = app-side, DW-ES111-1). Occurrences :\n'
          '${offenders.join('\n')}',
    );
  });
}
