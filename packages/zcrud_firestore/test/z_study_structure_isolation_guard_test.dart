@TestOn('vm')
library;

// Garde d'ISOLATION (AD-1/AD-5) : servir la structure d'étude depuis Firestore
// ne doit RIEN faire entrer de Firestore dans le noyau.
//
// La direction de dépendance est à sens unique — le satellite Firestore
// dépend du noyau, jamais l'inverse. La fabrique livrée ici est précisément le
// genre de code qui pourrait faire glisser cette frontière (« il suffirait
// d'un petit type Firestore dans l'entité… ») ; le défaut serait PASSIF, tout
// resterait vert, et il ne se paierait qu'au moment où un hôte voudrait tester
// le noyau sans Firebase.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Remonte jusqu'au dossier du paquet (celui qui porte `pubspec.yaml`).
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('pubspec.yaml introuvable depuis ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  final Directory kernel = Directory(
    '${_packageRoot().parent.path}/zcrud_study_kernel',
  );
  final File kernelPubspec = File('${kernel.path}/pubspec.yaml');

  setUpAll(() {
    // Sujet monté : sans ces deux assertions, les gardes suivantes seraient
    // vertes par vacuité (rien à lire).
    expect(
      kernelPubspec.existsSync(),
      isTrue,
      reason: 'garde MAL ANCRÉE : ${kernelPubspec.path} introuvable',
    );
    expect(
      Directory('${kernel.path}/lib').existsSync(),
      isTrue,
      reason: 'garde MAL ANCRÉE : sources du noyau introuvables',
    );
  });

  test('le pubspec du noyau ne déclare AUCUNE dépendance backend', () {
    final String content = kernelPubspec.readAsStringSync();
    for (final String forbidden in const <String>[
      'cloud_firestore',
      'firebase_core',
      'firebase_auth',
      'hive',
    ]) {
      expect(
        content.contains(forbidden),
        isFalse,
        reason: '`$forbidden` déclaré par zcrud_study_kernel — la frontière '
            'AD-1/AD-5 est franchie.',
      );
    }
  });

  test('aucune source du noyau n\'IMPORTE un type backend', () {
    final List<String> offenders = <String>[];
    int scanned = 0;
    for (final FileSystemEntity entity
        in Directory('${kernel.path}/lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      for (final String line in entity.readAsLinesSync()) {
        final String trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        if (trimmed.contains('package:cloud_firestore/') ||
            trimmed.contains('package:firebase_') ||
            trimmed.contains('package:hive')) {
          offenders.add('${entity.path} : $trimmed');
        }
      }
    }
    expect(scanned, greaterThan(20), reason: 'sujet monté : sources scannées');
    expect(offenders, isEmpty);
  });
}
