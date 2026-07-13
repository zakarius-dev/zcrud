@TestOn('vm')
// E2-4 (AC1, AC pivot de l'épic) : `zcrud_annotations` ne déclare AUCUNE
// dépendance runtime lourde et son `lib/` n'importe aucun package lourd. Sa
// seule arête `zcrud_*` est `zcrud_core` (AD-1, cœur OUT=0). Test structurel :
// inspection du `pubspec.yaml` + grep des imports de `lib/`.
//
// ⚠️ `@TestOn('vm')` (ES-1.4) : test STRUCTUREL qui inspecte le DISQUE
// (`dart:io`) — inexécutable en JS par nature. `gate:web` (généralisé en ES-1.4 :
// tout package pur-Dart avec `test/`) rejoue désormais cette suite sous
// `dart test -p node` : sans ce tag, le chargement échoue (`Unsupported
// operation: _Namespace`). Le tag est la réponse ATTENDUE (pas un opt-out de
// confort du gate) : les tests de valeur (const/annotations) restent, eux,
// rejoués en JS.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Localise le répertoire du package `zcrud_annotations` quel que soit le CWD
/// (racine du workspace ou package).
Directory _pkgDir() {
  for (final base in <String>['', 'packages/zcrud_annotations/']) {
    final dir = Directory(base.isEmpty ? '.' : base);
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/src/domain/annotations').existsSync()) {
      return dir;
    }
  }
  fail('Répertoire zcrud_annotations introuvable depuis ${Directory.current.path}');
}

/// Dépendances runtime lourdes INTERDITES en `dependencies` (AC1) : codegen,
/// gestionnaire d'état, backend, UI lourde.
const _forbiddenDeps = <String>[
  'build_runner',
  'source_gen',
  'analyzer',
  'build:',
  'flutter_riverpod',
  'riverpod',
  'get:',
  'provider:',
  'firebase',
  'cloud_firestore',
  'syncfusion',
  'flutter_quill',
  'google_maps',
];

/// Imports INTERDITS dans `lib/` (mêmes familles + Flutter direct : les
/// annotations sont pur-données et importent la surface PURE
/// `package:zcrud_core/edition.dart`, jamais Flutter).
const _forbiddenImports = <String>[
  'package:build_runner/',
  'package:source_gen/',
  'package:analyzer/',
  'package:build/',
  'package:flutter/',
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:get/',
  'package:provider/',
  'package:firebase',
  'package:cloud_firestore/',
  'package:syncfusion',
  'package:flutter_quill/',
];

void main() {
  final pkg = _pkgDir();

  test('pubspec: seule dépendance zcrud_* = zcrud_core, aucune dep lourde (AC1)',
      () {
    final lines = File('${pkg.path}/pubspec.yaml').readAsLinesSync();

    // Section `dependencies:` (jusqu'à `dev_dependencies:` ou fin).
    final deps = <String>[];
    var inDeps = false;
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('dependencies:')) {
        inDeps = true;
        continue;
      }
      if (inDeps && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        // Nouvelle clé de premier niveau => fin de la section dependencies.
        break;
      }
      // Ignorer les lignes de commentaire (elles décrivent légitimement les
      // dépendances interdites) : ne scanner que des entrées réelles.
      if (inDeps && line.trimLeft().startsWith('#')) continue;
      if (inDeps) deps.add(line);
    }

    // Aucune dépendance lourde déclarée.
    for (final bad in _forbiddenDeps) {
      for (final d in deps) {
        expect(d.contains(bad), isFalse,
            reason: 'Dépendance runtime lourde interdite ($bad) dans pubspec: $d');
      }
    }

    // La seule arête `zcrud_*` est zcrud_core.
    final zdeps = deps
        .map((l) => l.trim())
        .where((l) => l.startsWith('zcrud_'))
        .map((l) => l.split(':').first)
        .toList();
    expect(zdeps, <String>['zcrud_core'],
        reason: 'La seule arête zcrud_* doit être zcrud_core (AD-1).');
  });

  test('lib/ n\'importe aucun package lourd ni Flutter (AC1)', () {
    final libDir = Directory('${pkg.path}/lib');
    final offenders = <String>[];
    for (final ent in libDir.listSync(recursive: true, followLinks: false)) {
      if (ent is! File || !ent.path.endsWith('.dart')) continue;
      for (final raw in ent.readAsLinesSync()) {
        final line = raw.trimLeft();
        if (!line.startsWith('import ') && !line.startsWith('export ')) continue;
        for (final bad in _forbiddenImports) {
          if (line.contains(bad)) offenders.add('${ent.path}: $line');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Imports lourds interdits dans lib/:\n${offenders.join('\n')}');
  });
}
