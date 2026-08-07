@TestOn('vm')
/// 🔴 Preuve d'OPT-IN et d'acyclicité (AD-1/AD-57) — lot K3.
///
/// Lit les `pubspec.yaml` RÉELS de `packages/*` (patron
/// `zcrud_chat_study/test/z_acyclicity_proof_test.dart`) et prouve :
///
/// * **MAT-G1** — ce paquet est un PUITS : aucune arête entrante. C'est la
///   preuve d'opt-in : un consommateur de `zcrud_chat` qui ne le monte pas ne
///   tire RIEN de sa fermeture ;
/// * **MAT-G2** — ses arêtes SORTANTES sont exactement
///   {zcrud_core, zcrud_chat_kernel, zcrud_chat} — aucune dépendance tierce ;
/// * **MAT-G3** — il est déclaré au `workspace:` racine ET à la recette de
///   consommation git (le gate `consumption-recipe` a mordu au dernier paquet
///   oublié : la garde locale rougit AVANT le gate).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kSelf = 'zcrud_chat_material';

Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable depuis ${Directory.current.path}');
    }
    dir = parent;
  }
}

/// Arêtes `zcrud_*` déclarées dans la section `dependencies:` d'un pubspec —
/// ligne à ligne, aucune dépendance YAML tierce.
Set<String> _runtimeZcrudDeps(File pubspec) {
  final List<String> lines = pubspec.readAsLinesSync();
  final Set<String> deps = <String>{};
  var inDeps = false;
  for (final String raw in lines) {
    final String line = raw.split('#').first;
    if (line.trim().isEmpty) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      inDeps = line.trimRight() == 'dependencies:';
      continue;
    }
    if (!inDeps) continue;
    final RegExpMatch? m = RegExp(r'^\s{2}([a-z_0-9]+)\s*:').firstMatch(line);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (name.startsWith('zcrud_')) deps.add(name);
  }
  return deps;
}

void main() {
  final Directory root = _repoRoot();
  final Map<String, Set<String>> graph = <String, Set<String>>{};
  for (final FileSystemEntity e
      in Directory('${root.path}/packages').listSync()) {
    if (e is! Directory) continue;
    final File pubspec = File('${e.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final String name = e.path.split('/').last;
    if (!name.startsWith('zcrud_')) continue;
    graph[name] = _runtimeZcrudDeps(pubspec);
  }

  test('contrôle positif — le graphe lu est bien celui du dépôt', () {
    expect(graph.length, greaterThanOrEqualTo(37));
    expect(graph.containsKey(kSelf), isTrue);
    expect(graph['zcrud_chat'], contains('zcrud_chat_kernel'));
    expect(graph['zcrud_chat_kernel'], contains('zcrud_core'));
  });

  test('🔴 MAT-G1 — $kSelf est un PUITS : aucune arête entrante (opt-in '
      'prouvé)', () {
    final List<String> parents = <String>[
      for (final MapEntry<String, Set<String>> e in graph.entries)
        if (e.value.contains(kSelf)) e.key,
    ];
    expect(parents, isEmpty,
        reason: '🔴 dépendants inattendus : $parents — un consommateur de '
            'zcrud_chat tirerait Material sans l\'avoir choisi (AD-57)');
  });

  test('🔴 MAT-G2 — arêtes SORTANTES exactes, aucune dépendance tierce', () {
    expect(graph[kSelf], <String>{
      'zcrud_core',
      'zcrud_chat_kernel',
      'zcrud_chat',
    });
    // Aucune dépendance hors flutter/zcrud_* dans `dependencies:`.
    final List<String> lines =
        File('${root.path}/packages/$kSelf/pubspec.yaml').readAsLinesSync();
    var inDeps = false;
    final List<String> foreign = <String>[];
    for (final String raw in lines) {
      final String line = raw.split('#').first;
      if (line.trim().isEmpty) continue;
      if (!line.startsWith(' ')) {
        inDeps = line.trimRight() == 'dependencies:';
        continue;
      }
      if (!inDeps) continue;
      final RegExpMatch? m = RegExp(r'^\s{2}([a-z_0-9]+)\s*:').firstMatch(line);
      if (m == null) continue;
      final String name = m.group(1)!;
      if (name != 'flutter' && !name.startsWith('zcrud_')) foreign.add(name);
    }
    expect(foreign, isEmpty,
        reason: '🔴 dépendance tierce inattendue : $foreign — Material vient '
            'du SDK, rien d\'autre n\'est autorisé ici');
  });

  test('🔴 MAT-G3 — déclaré au workspace racine ET à la recette', () {
    expect(
      File('${root.path}/pubspec.yaml').readAsStringSync(),
      contains('- packages/$kSelf'),
      reason: '🔴 absent du `workspace:` racine — le paquet ne résout pas',
    );
    expect(
      File('${root.path}/docs/private-git-consumption.md').readAsStringSync(),
      contains('path: packages/$kSelf }'),
      reason: '🔴 absent de la recette — l\'arête interne est `hosted`, pub '
          'chercherait le paquet sur pub.dev chez tout consommateur git',
    );
  });
}
