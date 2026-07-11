// AC7 (E6-2, AD-1) : PREUVE DE GRAPHE de l'isolation des LIBS DE CONVERSION
// (`markdown`, `markdown_quill`) du `ZMarkdownCodec`.
//
// Prouve que la FERMETURE TRANSITIVE des dépendances :
//   (a) de `zcrud_core` NE CONTIENT AUCUNE lib de conversion ;
//   (b) CONTRÔLE POSITIF : la fermeture de `zcrud_markdown` CONTIENT bien
//       `markdown_quill` ET `markdown` — sinon FAUX VERT ;
//   (c) ACYCLICITÉ (AD-1) : `zcrud_markdown → zcrud_core`, pas l'inverse ;
//       out-degree zcrud_* du cœur = 0.
//
// Miroir de `flutter_quill_isolation_graph_test.dart` : mode PRIMAIRE via
// `dart pub deps --json` (transitives EXTERNES incluses), FALLBACK LOCAL honnête.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Libs de conversion à isoler (directes + transitives éventuelles).
///
/// DP-4 : ajout des libs de conversion **HTML** du `ZHtmlCodec`
/// (`vsc_quill_delta_to_html` Delta→HTML, `flutter_quill_delta_from_html`
/// HTML→Delta) — mêmes garanties d'isolation AD-1 que Markdown.
const _conversionLibs = <String>[
  'markdown_quill',
  'markdown',
  'vsc_quill_delta_to_html',
  'flutter_quill_delta_from_html',
];

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

List<String> _convLibs(Set<String> closure) =>
    closure.where(_conversionLibs.contains).toList()..sort();

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

  test('(a) fermeture de zcrud_core SANS lib de conversion (AD-1)', () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_core');
    expect(_convLibs(closure), isEmpty,
        reason: 'zcrud_core ne doit tirer AUCUNE lib de conversion Markdown. '
            'Trouvé: ${_convLibs(closure)}');
  });

  test('(b) CONTRÔLE POSITIF : zcrud_markdown CONTIENT les libs de conversion',
      () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_markdown');
    // `markdown_quill` est une dépendance DIRECTE (visible en local ET résolu).
    expect(closure.contains('markdown_quill'), isTrue,
        reason: 'FAUX VERT si zcrud_markdown ne tirait pas markdown_quill. '
            'Fermeture: $closure');
    // DP-4 : les libs de conversion HTML sont AUSSI des deps DIRECTES.
    expect(closure.contains('vsc_quill_delta_to_html'), isTrue,
        reason: 'FAUX VERT si zcrud_markdown ne tirait pas '
            'vsc_quill_delta_to_html. Fermeture: $closure');
    expect(closure.contains('flutter_quill_delta_from_html'), isTrue,
        reason: 'FAUX VERT si zcrud_markdown ne tirait pas '
            'flutter_quill_delta_from_html. Fermeture: $closure');
    if (usingResolved) {
      // `markdown` est tiré transitivement (par markdown_quill) : sa présence
      // dans la fermeture RÉSOLUE prouve le parcours des transitives externes.
      expect(closure.contains('markdown'), isTrue,
          reason: 'La fermeture RÉSOLUE doit inclure `markdown` (transitif). '
              'Fermeture: $closure');
    }
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
