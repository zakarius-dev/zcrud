/// Test de résolution / modularité (ES-1.1, AC8 — NFR-S10/SM-S7).
///
/// Assertion **outillée** (pas seulement narrative) : la fermeture transitive
/// des arêtes `zcrud_*` du noyau `zcrud_study_kernel` se limite à
/// `{zcrud_core, zcrud_annotations}` — donc **aucun** Firebase (`zcrud_firestore`),
/// examens/communauté ni satellite lourd n'entre dans le graphe d'une app qui
/// n'importe que le noyau (ou, à terme, une note seule). Reproductible : lit les
/// `pubspec.yaml` du workspace depuis la racine du repo.
///
/// **VM-only** (`dart:io` : lecture des `pubspec.yaml`) — annoté `@TestOn('vm')`
/// pour que la suite du kernel reste **exécutable sous `dart test -p node`**
/// (gate de déterminisme web des vecteurs FNV, ES-1.2/M1 ; cf.
/// `z_kernel_purity_test.dart`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Extrait les arêtes `zcrud_*` du bloc `dependencies:` d'un pubspec.
Set<String> _runtimeDeps(String pkg, String packagesRoot) {
  final file = File('$packagesRoot/$pkg/pubspec.yaml');
  if (!file.existsSync()) return <String>{};
  final deps = <String>{};
  var inDeps = false;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.replaceAll('\t', '  ');
    if (RegExp(r'^dependencies:\s*$').hasMatch(line)) {
      inDeps = true;
      continue;
    }
    // Une nouvelle clé top-level (non indentée, non commentaire) ferme le bloc.
    if (inDeps && RegExp(r'^[A-Za-z_]').hasMatch(line)) {
      inDeps = false;
    }
    if (inDeps) {
      final m = RegExp(r'^\s+(zcrud_[a-z_]+)\s*:').firstMatch(line);
      if (m != null && m.group(1) != pkg) deps.add(m.group(1)!);
    }
  }
  return deps;
}

Set<String> _transitiveClosure(String start, String packagesRoot) {
  final seen = <String>{};
  final stack = <String>[start];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    for (final dep in _runtimeDeps(cur, packagesRoot)) {
      if (seen.add(dep)) stack.add(dep);
    }
  }
  return seen;
}

/// Localise le dossier `packages/` en remontant depuis le cwd du test.
String _findPackagesRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory('${dir.path}/packages');
    if (candidate.existsSync() &&
        File('${candidate.path}/zcrud_study_kernel/pubspec.yaml').existsSync()) {
      return candidate.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Dossier packages/ introuvable depuis ${Directory.current.path}');
}

void main() {
  group('Résolution du noyau (NFR-S10 / SM-S7 — AC8)', () {
    final packagesRoot = _findPackagesRoot();
    final closure = _transitiveClosure('zcrud_study_kernel', packagesRoot);

    test('fermeture transitive == {zcrud_core, zcrud_annotations}', () {
      expect(closure, <String>{'zcrud_core', 'zcrud_annotations'});
    });

    test('aucun Firebase (zcrud_firestore) dans la fermeture', () {
      expect(closure.contains('zcrud_firestore'), isFalse);
    });

    test('aucune arête retour vers zcrud_flashcard (acyclicité AD-1)', () {
      expect(closure.contains('zcrud_flashcard'), isFalse);
    });

    test('aucun satellite lourd (list/markdown/export/geo/mindmap)', () {
      for (final heavy in <String>[
        'zcrud_list',
        'zcrud_markdown',
        'zcrud_export',
        'zcrud_geo',
        'zcrud_mindmap',
      ]) {
        expect(closure.contains(heavy), isFalse, reason: '$heavy ne doit '
            'pas entrer dans le graphe transitif du noyau');
      }
    });
  });
}
