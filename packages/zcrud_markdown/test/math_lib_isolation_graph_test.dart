// AC6 (E6-3, AD-1) : PREUVE DE GRAPHE de l'isolation de la LIB DE RENDU LaTeX
// (`flutter_math_fork`) de l'embed E6-3.
//
// Prouve que la FERMETURE TRANSITIVE des dépendances :
//   (a) de `zcrud_core` NE CONTIENT PAS `flutter_math_fork` (ni transitives) ;
//   (b) CONTRÔLE POSITIF : la fermeture de `zcrud_markdown` CONTIENT bien
//       `flutter_math_fork` — sinon FAUX VERT ;
//   (c) ACYCLICITÉ (AD-1) : `zcrud_markdown → zcrud_core`, pas l'inverse ;
//       out-degree zcrud_* du cœur = 0.
//
// Miroir de `conversion_libs_isolation_graph_test.dart` : mode PRIMAIRE via
// `dart pub deps --json` (transitives EXTERNES incluses), FALLBACK LOCAL honnête.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lib de rendu à isoler (directe pour zcrud_markdown ; absente du cœur).
const _mathLib = 'flutter_math_fork';

Directory _packagesDir() {
  for (final base in <String>['packages', '../../packages', '../packages']) {
    final d = Directory(base);
    if (d.existsSync() && Directory('${d.path}/zcrud_core').existsSync()) {
      return d;
    }
  }
  fail('Dossier packages/ introuvable depuis ${Directory.current.path}');
}

Map<String, Set<String>>? _resolvedGraph(Directory packagesDir) {
  ProcessResult res;
  try {
    res = Process.runSync(
      'dart',
      const <String>['pub', 'deps', '--json'],
      workingDirectory: '${packagesDir.path}/zcrud_core',
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null;
  }
  if (res.exitCode != 0) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(res.stdout as String);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['packages'] is! List) return null;
  final graph = <String, Set<String>>{};
  for (final Object? p in decoded['packages'] as List) {
    if (p is! Map) continue;
    final name = p['name'];
    if (name is! String) continue;
    final deps = <String>{};
    final raw = p['dependencies'];
    if (raw is List) {
      for (final Object? dep in raw) {
        if (dep is String) deps.add(dep);
      }
    }
    graph[name] = deps;
  }
  return graph.isEmpty ? null : graph;
}

const _depBlocks = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

Set<String>? _localDirectDeps(Directory packagesDir, String pkg) {
  final f = File('${packagesDir.path}/$pkg/pubspec.yaml');
  if (!f.existsSync()) return null;
  final deps = <String>{};
  String? curBlock;
  final blockOpen = RegExp('^(${_depBlocks.join('|')}):\\s*\$');
  final topLevel = RegExp(r'^[A-Za-z_]');
  final directDep = RegExp(r'^  (?! )([A-Za-z0-9_]+)\s*:');
  for (final raw in f.readAsLinesSync()) {
    final line = raw.replaceFirst(RegExp(r'#.*$'), '');
    if (blockOpen.hasMatch(line)) {
      curBlock = blockOpen.firstMatch(line)!.group(1);
      continue;
    }
    if (curBlock != null && topLevel.hasMatch(line)) {
      curBlock = null;
    }
    if (curBlock != null) {
      final m = directDep.firstMatch(line);
      if (m != null) {
        final name = m.group(1)!;
        if (name == 'flutter' || name == 'sdk') continue;
        deps.add(name);
      }
    }
  }
  return deps;
}

Map<String, Set<String>> _localGraph(Directory packagesDir) {
  final graph = <String, Set<String>>{};
  for (final entity in packagesDir.listSync()) {
    if (entity is! Directory) continue;
    final pkg = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final deps = _localDirectDeps(packagesDir, pkg);
    if (deps != null) graph[pkg] = deps;
  }
  return graph;
}

Set<String> _closure(Map<String, Set<String>> graph, String root) {
  final seen = <String>{};
  final stack = <String>[root];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    final deps = graph[cur];
    if (deps == null) continue;
    stack.addAll(deps);
  }
  seen.remove(root);
  return seen;
}

void main() {
  final packagesDir = _packagesDir();
  final resolved = _resolvedGraph(packagesDir);
  final usingResolved = resolved != null;
  final graph = resolved ?? _localGraph(packagesDir);

  final scopeNote = usingResolved
      ? 'PREUVE COMPLÈTE : fermeture via `dart pub deps --json` '
          '(transitives EXTERNES incluses).'
      : 'PREUVE DÉGRADÉE (fallback) : fermeture LOCALE seulement.';

  test('portée de la preuve documentée (anti sur-vente)', () {
    printOnFailure(scopeNote);
    expect(graph, isNotEmpty, reason: scopeNote);
  });

  test('(a) fermeture de zcrud_core SANS flutter_math_fork (AD-1)', () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_core');
    expect(closure.contains(_mathLib), isFalse,
        reason: 'zcrud_core ne doit tirer AUCUNE lib de rendu math. '
            'Fermeture: $closure');
  });

  test('(b) CONTRÔLE POSITIF : zcrud_markdown CONTIENT flutter_math_fork', () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_markdown');
    // Dépendance DIRECTE (visible en local ET résolu) — sinon FAUX VERT.
    expect(closure.contains(_mathLib), isTrue,
        reason: 'FAUX VERT si zcrud_markdown ne tirait pas $_mathLib. '
            'Fermeture: $closure');
  });

  test('(c) ACYCLICITÉ AD-1 : zcrud_markdown → zcrud_core, PAS l\'inverse', () {
    final mdDeps = _localDirectDeps(packagesDir, 'zcrud_markdown')!;
    final coreDeps = _localDirectDeps(packagesDir, 'zcrud_core')!;
    expect(mdDeps.contains('zcrud_core'), isTrue,
        reason: 'zcrud_markdown doit dépendre de zcrud_core (arête AD-1).');
    expect(coreDeps.contains('zcrud_markdown'), isFalse,
        reason: 'zcrud_core ne doit JAMAIS dépendre de zcrud_markdown.');
    final coreZcrud = coreDeps.where((p) => p.startsWith('zcrud_')).toList();
    expect(coreZcrud, isEmpty,
        reason: 'zcrud_core out-degree zcrud_* = 0 (AD-1). Trouvé: $coreZcrud');
  });
}
