@TestOn('vm')
/// 🔴 PREUVE d'acyclicité (AD-1) — CHAT-8. « Prouve-la, ne la suppose pas. »
///
/// Lit les `pubspec.yaml` **RÉELS** de `packages/*` et reconstruit le graphe des
/// arêtes `zcrud_* → zcrud_*` de **runtime** (`dependencies:`). Périmètre
/// ÉCRIT : les `dev_dependencies` sont hors graphe ici — c'est la fermeture que
/// livre un consommateur, et c'est celle que ce lot met en jeu. Le gate global
/// `melos run gate:graph` couvre, lui, deps + dev + overrides.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kSelf = 'zcrud_chat_study';

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

/// Arêtes `zcrud_*` déclarées dans la section `dependencies:` d'un pubspec.
///
/// Analyse volontairement LIGNE À LIGNE (aucune dépendance YAML tierce dans un
/// paquet qui n'en a aucune) : on entre dans `dependencies:` et on en sort à la
/// première clé de premier niveau suivante.
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
    final RegExpMatch? m =
        RegExp(r'^\s{2}([a-z_0-9]+)\s*:').firstMatch(line);
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
    // Un graphe vide (ou un parseur muet) rendrait TOUTES les assertions
    // suivantes vraies par vacuité. On exige donc des faits connus.
    expect(graph.length, greaterThanOrEqualTo(35));
    expect(graph.containsKey(kSelf), isTrue);
    expect(graph['zcrud_flashcard'], contains('zcrud_core'));
    expect(graph['zcrud_chat_kernel'], contains('zcrud_core'));
  });

  test('le graphe entier est ACYCLIQUE', () {
    final Set<String> done = <String>{};
    final List<String> stack = <String>[];

    void visit(String node) {
      if (done.contains(node)) return;
      if (stack.contains(node)) {
        fail('CYCLE : ${<String>[...stack.sublist(stack.indexOf(node)), node].join(' → ')}');
      }
      stack.add(node);
      for (final String next in graph[node] ?? const <String>{}) {
        if (graph.containsKey(next)) visit(next);
      }
      stack.removeLast();
      done.add(node);
    }

    for (final String node in graph.keys) {
      visit(node);
    }
    expect(done, hasLength(graph.length));
  });

  test('CORE OUT = 0 — zcrud_core ne dépend d\'aucun paquet zcrud', () {
    expect(graph['zcrud_core'], isEmpty);
  });

  test('$kSelf est un PUITS : aucune arête entrante', () {
    final List<String> parents = <String>[
      for (final MapEntry<String, Set<String>> e in graph.entries)
        if (e.value.contains(kSelf)) e.key,
    ];
    expect(parents, isEmpty, reason: 'dépendants inattendus : $parents');
  });

  test('les arêtes SORTANTES déclarées sont exactement celles attendues', () {
    expect(graph[kSelf], <String>{
      'zcrud_core',
      'zcrud_mindmap',
      'zcrud_chat_kernel',
      'zcrud_flashcard',
      'zcrud_study_kernel',
      'zcrud_study',
    });
  });

  test(
      '🔴 le domaine d\'ÉTUDE n\'entre PAS dans le chat — ni zcrud_chat ni '
      'zcrud_chat_kernel ne dépendent de zcrud_flashcard', () {
    // C'est la RAISON D'ÊTRE de ce paquet. Si cette garde rougit, quelqu'un a
    // fait entrer le SRS dans le chat : DODLP et DLCFTI porteraient le domaine
    // d'étude sans usage — l'erreur exacte que la relocalisation a corrigée.
    for (final String chatPkg in <String>['zcrud_chat', 'zcrud_chat_kernel']) {
      final Set<String> deps = graph[chatPkg] ?? const <String>{};
      expect(deps, isNot(contains('zcrud_flashcard')), reason: chatPkg);
      expect(deps, isNot(contains('zcrud_study')), reason: chatPkg);
      expect(deps, isNot(contains('zcrud_study_kernel')), reason: chatPkg);
      expect(deps, isNot(contains(kSelf)), reason: chatPkg);
    }
  });

  test('le paquet est DÉCLARÉ dans le workspace racine et dans la recette', () {
    // Un paquet absent du `workspace:` ne résout pas ; absent de la recette de
    // consommation, il piège l'hôte (son arête interne est `hosted`).
    expect(
      File('${root.path}/pubspec.yaml').readAsStringSync(),
      contains('- packages/$kSelf'),
    );
    expect(
      File('${root.path}/docs/private-git-consumption.md').readAsStringSync(),
      contains('path: packages/$kSelf }'),
    );
  });
}
