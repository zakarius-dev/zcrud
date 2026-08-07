// CR-IFFD-73 — PREUVE DE CONFINEMENT de Quill, et preuve que l'OPT-IN NE COÛTE
// RIEN à qui ne monte pas ce paquet.
//
// Patron STRICT de `zcrud_list/test/sm5_syncfusion_isolation_graph_test.dart`
// (isolation Syncfusion) : fermeture transitive fondée sur la RÉSOLUTION RÉELLE
// (`dart pub deps --json`), repli local documenté, et CONTRÔLE POSITIF pour
// écarter le faux vert.
//
// Ce que ce fichier établit :
//   (a) SOURCE — aucun fichier de ce paquet ne nomme un type/import Quill ;
//   (b) PUBSPEC — aucune arête TIERCE directe (Quill n'est atteint que via
//       l'API neutre de `zcrud_markdown`) ;
//   (c) OPT-IN — la fermeture de `zcrud_chat` ne contient NI `flutter_quill` NI
//       `flutter_math_fork` : un hôte qui ne monte pas ce satellite ne tire
//       rien de nouveau ;
//   (d) CONTRÔLE POSITIF — la fermeture de CE paquet contient bien
//       `flutter_quill` (sinon (c) serait vert pour la mauvaise raison), et
//       aussi `flutter_math_fork`, tiré TRANSITIVEMENT (arête externe→externe :
//       preuve que le parcours traverse bien le transitif) ;
//   (e) ACYCLICITÉ AD-1 — arêtes sortantes seulement, CORE OUT zcrud_* = 0, et
//       ce paquet est un PUITS (aucune arête entrante).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kSelf = 'zcrud_chat_markdown';

/// Racine du dépôt (dossier portant `melos.yaml`) — ancrage ROBUSTE au CWD,
/// jamais un `../` relatif (convention `melos exec` : le CWD est le dossier du
/// paquet).
Directory _repoRoot() {
  Directory d = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${d.path}/melos.yaml').existsSync() &&
        Directory('${d.path}/packages/zcrud_core').existsSync()) {
      return d;
    }
    final Directory parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  fail('Racine du dépôt introuvable depuis ${Directory.current.path}');
}

Directory _packagesDir() => Directory('${_repoRoot().path}/packages');

// ───────────────────────── Mode PRIMAIRE : résolution réelle ────────────────

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
  final Map<String, Set<String>> graph = <String, Set<String>>{};
  for (final Object? p in decoded['packages'] as List<Object?>) {
    if (p is! Map) continue;
    final Object? name = p['name'];
    if (name is! String) continue;
    final Set<String> deps = <String>{};
    final Object? raw = p['dependencies'];
    if (raw is List) {
      for (final Object? dep in raw) {
        if (dep is String) deps.add(dep);
      }
    }
    graph[name] = deps;
  }
  return graph.isEmpty ? null : graph;
}

// ───────────────────────── Mode FALLBACK : pubspecs locaux ──────────────────

const List<String> _depBlocks = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

Set<String>? _localDirectDeps(Directory packagesDir, String pkg) {
  final File f = File('${packagesDir.path}/$pkg/pubspec.yaml');
  if (!f.existsSync()) return null;
  final Set<String> deps = <String>{};
  String? curBlock;
  final RegExp blockOpen = RegExp('^(${_depBlocks.join('|')}):\\s*\$');
  final RegExp topLevel = RegExp(r'^[A-Za-z_]');
  final RegExp directDep = RegExp(r'^  (?! )([A-Za-z0-9_]+)\s*:');
  for (final String raw in f.readAsLinesSync()) {
    final String line = raw.replaceFirst(RegExp('#.*\$'), '');
    if (blockOpen.hasMatch(line)) {
      curBlock = blockOpen.firstMatch(line)!.group(1);
      continue;
    }
    if (curBlock != null && topLevel.hasMatch(line)) curBlock = null;
    if (curBlock != null) {
      final RegExpMatch? m = directDep.firstMatch(line);
      if (m != null) {
        final String name = m.group(1)!;
        if (name == 'flutter' || name == 'sdk') continue;
        deps.add(name);
      }
    }
  }
  return deps;
}

Map<String, Set<String>> _localGraph(Directory packagesDir) {
  final Map<String, Set<String>> graph = <String, Set<String>>{};
  for (final FileSystemEntity e in packagesDir.listSync()) {
    if (e is! Directory) continue;
    final String pkg = e.uri.pathSegments.where((String s) => s.isNotEmpty).last;
    final Set<String>? deps = _localDirectDeps(packagesDir, pkg);
    if (deps != null) graph[pkg] = deps;
  }
  return graph;
}

Set<String> _closure(Map<String, Set<String>> graph, String root) {
  final Set<String> seen = <String>{};
  final List<String> stack = <String>[root];
  while (stack.isNotEmpty) {
    final String cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    final Set<String>? deps = graph[cur];
    if (deps == null) continue;
    stack.addAll(deps);
  }
  seen.remove(root);
  return seen;
}

/// Les libs de rendu riche dont le confinement est en jeu.
const List<String> _kRichTextLibs = <String>[
  'flutter_quill',
  'flutter_math_fork',
  'markdown_quill',
  'vsc_quill_delta_to_html',
];

List<String> _found(Set<String> closure) =>
    _kRichTextLibs.where(closure.contains).toList()..sort();

void main() {
  final Directory packagesDir = _packagesDir();
  final Map<String, Set<String>>? resolved = _resolvedGraph(packagesDir);
  final bool usingResolved = resolved != null;
  final Map<String, Set<String>> graph = resolved ?? _localGraph(packagesDir);
  final String scopeNote = usingResolved
      ? 'PREUVE COMPLÈTE : fermeture fondée sur `dart pub deps --json` '
            '(transitives EXTERNES incluses).'
      : 'PREUVE DÉGRADÉE (repli) : `dart pub deps --json` indisponible ; '
            'fermeture LOCALE seulement (transitives externes NON suivies).';

  group('(a) SOURCE — aucun type Quill ne fuit dans ce paquet', () {
    List<File> sources() {
      final Directory lib = Directory('${packagesDir.path}/$_kSelf/lib');
      return lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('les sources existent (anti faux vert par dossier vide)', () {
      expect(
        sources(),
        isNotEmpty,
        reason: 'Sans source à scanner, tous les tests de cette famille '
            'seraient verts pour rien.',
      );
    });

    test('aucun import `flutter_quill` / `flutter_math_fork`', () {
      final List<String> offenders = <String>[];
      for (final File f in sources()) {
        final String s = f.readAsStringSync();
        for (final String lib in _kRichTextLibs) {
          if (s.contains('package:$lib/')) {
            offenders.add('${f.path} -> $lib');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 Quill doit être atteint UNIQUEMENT via l\'API neutre de '
            '`zcrud_markdown`. Trouvé: $offenders',
      );
    });

    test('aucun NOM de type Quill dans la source', () {
      // Le confinement d'un import ne dit rien d'un type re-exporté par
      // inadvertance : on vise aussi les noms.
      const List<String> quillTypes = <String>[
        'QuillController',
        'QuillEditor',
        'QuillEditorConfig',
        'EmbedBuilder',
        'Embeddable',
        'DefaultStyles',
        'Delta(',
        'Math.tex',
      ];
      final List<String> offenders = <String>[];
      for (final File f in sources()) {
        final String s = f.readAsStringSync();
        for (final String t in quillTypes) {
          if (s.contains(t)) offenders.add('${f.path} -> $t');
        }
      }
      expect(offenders, isEmpty, reason: 'Trouvé: $offenders');
    });
  });

  group('(b) PUBSPEC — aucune arête TIERCE directe', () {
    test('les dépendances directes sont exclusivement des `zcrud_*`', () {
      final Set<String> deps = _localDirectDeps(packagesDir, _kSelf)!;
      final List<String> thirdParty = deps
          .where(
            (String d) => !d.startsWith('zcrud_') && d != 'flutter_test',
          )
          .toList();
      expect(
        thirdParty,
        isEmpty,
        reason: '🔴 Ce paquet ne doit déclarer AUCUNE arête tierce directe : '
            'Quill est atteint par `zcrud_markdown`, dont le barrel n\'exporte '
            'aucun symbole Quill. Trouvé: $thirdParty',
      );
      expect(deps, contains('zcrud_markdown'));
      expect(deps, contains('zcrud_chat'));
    });
  });

  group('🔴 (c) OPT-IN — ne pas monter ce paquet ne coûte RIEN', () {
    test('la fermeture de `zcrud_chat` est SANS Quill ni math', () {
      printOnFailure(scopeNote);
      final Set<String> closure = _closure(graph, 'zcrud_chat');
      expect(
        _found(closure),
        isEmpty,
        reason: '🔴 `zcrud_chat` doit rester ZÉRO-DÉPENDANCE tierce : c\'est '
            'la promesse d\'AD-57 et la raison d\'être de la couture. '
            'Trouvé: ${_found(closure)}',
      );
    });

    test('la fermeture de `zcrud_chat_kernel` est SANS Quill ni math', () {
      printOnFailure(scopeNote);
      expect(_found(_closure(graph, 'zcrud_chat_kernel')), isEmpty);
    });

    test('la fermeture de `zcrud_core` est SANS Quill ni math', () {
      printOnFailure(scopeNote);
      expect(_found(_closure(graph, 'zcrud_core')), isEmpty);
    });

    test('aucun paquet ne DÉPEND de ce satellite (il est un PUITS)', () {
      final List<String> incoming = <String>[];
      for (final FileSystemEntity e in packagesDir.listSync()) {
        if (e is! Directory) continue;
        final String pkg = e.uri.pathSegments
            .where((String s) => s.isNotEmpty)
            .last;
        if (pkg == _kSelf) continue;
        final Set<String>? deps = _localDirectDeps(packagesDir, pkg);
        if (deps != null && deps.contains(_kSelf)) incoming.add(pkg);
      }
      expect(
        incoming,
        isEmpty,
        reason: '🔴 Une arête ENTRANTE ferait tirer Quill à un paquet qui ne '
            'l\'a pas demandé — l\'opt-in cesserait d\'en être un. '
            'Trouvé: $incoming',
      );
    });
  });

  group('🔬 (d) CONTRÔLE POSITIF — le test SAIT voir Quill', () {
    test('la fermeture de CE paquet CONTIENT bien flutter_quill', () {
      printOnFailure(scopeNote);
      final Set<String> closure = _closure(graph, _kSelf);
      expect(
        closure.contains('flutter_quill'),
        isTrue,
        reason: '🔴 Sans cela, le groupe (c) serait vert parce que le test ne '
            'sait rien voir, pas parce que rien ne fuit. Fermeture: $closure',
      );
      if (usingResolved) {
        // `flutter_math_fork` n'est PAS une dép directe de ce paquet NI de sa
        // dép directe déclarée en premier : il est tiré par `zcrud_markdown`.
        // Sa présence prouve que le parcours suit les arêtes transitives.
        expect(
          closure.contains('flutter_math_fork'),
          isTrue,
          reason: 'La fermeture RÉSOLUE doit inclure `flutter_math_fork` '
              '(transitif) — preuve que le parcours traverse le transitif, '
              'donc qu\'une contamination de `zcrud_chat` SERAIT vue par (c). '
              'Fermeture: $closure',
        );
      }
    });

    test('la fermeture de `zcrud_markdown` CONTIENT flutter_quill', () {
      expect(_closure(graph, 'zcrud_markdown').contains('flutter_quill'), true);
    });
  });

  group('(e) ACYCLICITÉ AD-1', () {
    test('arêtes sortantes déclarées, et `zcrud_core` reste un puits', () {
      final Set<String> self = _localDirectDeps(packagesDir, _kSelf)!;
      final Set<String> core = _localDirectDeps(packagesDir, 'zcrud_core')!;
      expect(self.contains('zcrud_core'), isTrue);
      expect(core.contains(_kSelf), isFalse);
      final List<String> coreZcrud = core
          .where((String p) => p.startsWith('zcrud_'))
          .toList();
      expect(
        coreZcrud,
        isEmpty,
        reason: 'CORE OUT zcrud_* = 0 (AD-1). Trouvé: $coreZcrud',
      );
    });

    test('le paquet est DÉCLARÉ au workspace racine', () {
      final String root = File(
        '${_repoRoot().path}/pubspec.yaml',
      ).readAsStringSync();
      expect(
        root.contains('- packages/$_kSelf'),
        isTrue,
        reason: '🔴 Un paquet non déclaré au bloc `workspace:` n\'est ni '
            'résolu, ni vu par `melos list` : il serait invisible et mort.',
      );
    });
  });
}
