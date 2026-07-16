library;

/// Garde de SURFACE (ES-11.2, AC8, AD-5/AD-27/R28) : le migrateur de corpus
/// `ZLegacyStudyMigrator` reste **générique par `Map`** et **backend-agnostique**.
///
/// ★ R3-I7 : ajouter dans `z_study_migrator.dart` un `import
///   'package:cloud_firestore/…'`/`package:hive/…` (en CODE, hors dartdoc) ou
///   une dépendance d'ENTITÉ au pubspec ⇒ cette garde ROUGE (et `graph_proof`
///   diverge / `melos verify` casse).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Retire commentaires de ligne (`//`, `///`) et de bloc (`/* */`) d'une source
/// Dart — pour ne scanner QUE le code exécutable (les dartdocs mentionnent
/// légitimement `cloud_firestore`/`WriteBatch` au titre du confinement AD-5).
String _stripComments(String source) {
  final withoutBlock = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final lines = withoutBlock.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  });
  return lines.join('\n');
}

void main() {
  const migratorPath = 'lib/src/data/z_study_migrator.dart';
  const pubspecPath = 'pubspec.yaml';

  group('AC8 — confinement backend/entité du migrateur', () {
    late String migratorCode;

    setUpAll(() {
      migratorCode = _stripComments(File(migratorPath).readAsStringSync());
    });

    test('AUCUN symbole/import backend en CODE (cloud_firestore/hive) — AD-5', () {
      for (final needle in const <String>[
        'cloud_firestore',
        'FirebaseFirestore',
        'FirebaseException',
        'WriteBatch',
        'DocumentSnapshot',
        'QuerySnapshot',
        'Timestamp',
        "package:hive",
        'HiveObject',
        'Box<',
      ]) {
        expect(migratorCode.contains(needle), isFalse,
            reason: 'symbole backend interdit en code : $needle');
      }
    });

    test('AUCUN import de package d\'ENTITÉ (générique par Map — R28)', () {
      for (final entityPkg in const <String>[
        'zcrud_document',
        'zcrud_note',
        'zcrud_exam',
        'zcrud_session',
        'zcrud_flashcard',
        'zcrud_mindmap',
      ]) {
        expect(migratorCode.contains('package:$entityPkg/'), isFalse,
            reason: 'aucune arête runtime vers l\'entité $entityPkg');
      }
    });

    test('le pubspec n\'introduit AUCUNE dépendance d\'entité (delta graphe 0)',
        () {
      final pubspec = File(pubspecPath).readAsStringSync();
      for (final entityPkg in const <String>[
        'zcrud_document',
        'zcrud_note',
        'zcrud_exam',
        'zcrud_session',
        'zcrud_flashcard',
        'zcrud_mindmap',
      ]) {
        expect(RegExp('^\\s*$entityPkg\\s*:', multiLine: true)
            .hasMatch(pubspec), isFalse,
            reason: 'dépendance d\'entité interdite : $entityPkg');
      }
    });
  });
}
