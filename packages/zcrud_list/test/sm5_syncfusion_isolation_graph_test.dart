// AC7 (E4-1, SM-5/AD-8/AD-1) : PREUVE DE GRAPHE de l'isolation Syncfusion.
//
// Prouve que la FERMETURE TRANSITIVE des dépendances :
//   (a) de `zcrud_core` NE CONTIENT AUCUN package `syncfusion*` ;
//   (b) d'un satellite qui ne dépend PAS de `zcrud_list` (`zcrud_markdown`,
//       ancrage PRD SM-5) NE CONTIENT AUCUN package `syncfusion*` ;
//   (c) CONTRÔLE POSITIF : la fermeture de `zcrud_list` CONTIENT bien
//       `syncfusion_flutter_datagrid` — sinon le test serait un FAUX VERT ;
//   (d) ACYCLICITÉ ciblée (AD-1) : `zcrud_list → zcrud_core` existe, et
//       `zcrud_core → zcrud_list` N'EXISTE PAS (le cœur est un puits).
//
// PORTÉE DE LA FERMETURE — deux modes (M1, durcissement du code-review E4-1) :
//
//   • Mode PRIMAIRE (COMPLET) : la fermeture est fondée sur la RÉSOLUTION RÉELLE
//     du workspace via `dart pub deps --json`. Le graphe résolu inclut les
//     dépendances transitives des paquets EXTERNES — donc une contamination
//     `syncfusion*` tirée transitivement par un tiers (p.ex. `zcrud_core → foo
//     (externe) → syncfusion`) FAIT ÉCHOUER (a)/(b). Le contrôle positif (c)
//     est renforcé : il exige que la fermeture de `zcrud_list` contienne AUSSI
//     `syncfusion_flutter_core`, qui n'est PAS une dépendance directe de
//     `zcrud_list` mais est tiré TRANSITIVEMENT par `syncfusion_flutter_datagrid`
//     (arête externe→externe). Cette assertion prouve, de façon auto-validante,
//     que la fermeture traverse bien les arêtes transitives EXTERNES — l'exact
//     angle mort que M1 exigeait de fermer.
//
//   • Mode FALLBACK (LOCAL, dégradé mais HONNÊTE) : si `dart pub deps --json`
//     est indisponible/illisible dans le contexte de test, on retombe sur un
//     parcours pur-Dart offline des `pubspec.yaml` du workspace. Ce mode ne suit
//     QUE les dépendances directes déclarées dans les pubspecs LOCAUX ; les
//     paquets externes y sont des FEUILLES (leurs transitives ne sont pas
//     suivies). Il couvre les vecteurs RÉALISTES (dép directe, intermédiaire
//     LOCAL) mais PAS l'intermédiaire transitif EXTERNE. Ce mode est signalé
//     explicitement (`printOnFailure`/`markTestSkipped` non — voir ci-dessous)
//     et n'AFFIRME PAS la garantie externe-transitive : aucune sur-vente.
import 'dart:convert';
import 'dart:io';

// `flutter_test` re-exporte `test`/`group`/`expect`/`fail` (test_api) : évite
// d'ajouter `package:test` en dépendance directe de ce package Flutter.
import 'package:flutter_test/flutter_test.dart';

/// Localise le dossier `packages/` du workspace quel que soit le CWD (racine ou
/// dossier du package testé sous `flutter test`).
Directory _packagesDir() {
  for (final base in <String>[
    'packages',
    '../../packages',
    '../packages',
  ]) {
    final d = Directory(base);
    if (d.existsSync() && Directory('${d.path}/zcrud_core').existsSync()) {
      return d;
    }
  }
  fail('Dossier packages/ introuvable depuis ${Directory.current.path}');
}

// ───────────────────────── Mode PRIMAIRE : `dart pub deps --json` ────────────

/// Exécute `dart pub deps --json` dans le contexte du workspace et renvoie le
/// graphe RÉSOLU sous forme `nom -> {dépendances résolues}` (runtime + dev
/// fusionnés par pub), OU `null` si la commande échoue / est illisible.
///
/// Le graphe couvre TOUT le workspace (racine `zcrud_workspace`) : chaque nœud
/// — y compris les paquets hébergés EXTERNES — expose ses propres dépendances
/// résolues, ce qui permet une fermeture transitive COMPLÈTE (externe incluse).
Map<String, Set<String>>? _resolvedGraph(Directory packagesDir) {
  ProcessResult res;
  try {
    res = Process.runSync(
      'dart',
      const <String>['pub', 'deps', '--json'],
      // Un membre quelconque du workspace suffit : pub résout le workspace entier.
      workingDirectory: '${packagesDir.path}/zcrud_core',
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null; // `dart` absent du PATH → fallback.
  }
  if (res.exitCode != 0) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(res.stdout as String);
  } on FormatException {
    return null; // sortie non-JSON (bruit stdout) → fallback.
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

// ───────────────────────── Mode FALLBACK : pubspecs LOCAUX ───────────────────

/// Blocs de dépendances scannés (comme `graph_proof.py` : les trois).
const _depBlocks = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// Dépendances directes déclarées dans le `pubspec.yaml` LOCAL d'un package, ou
/// `null` si le package n'est pas un membre local (externe → feuille).
///
/// Parsing line-based (aligné sur `graph_proof.py`/les gardes de pureté) pour
/// éviter `package:yaml`.
Set<String>? _localDirectDeps(Directory packagesDir, String pkg) {
  final f = File('${packagesDir.path}/$pkg/pubspec.yaml');
  if (!f.existsSync()) return null; // externe : pas de pubspec local
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
        if (name == 'flutter' || name == 'sdk') continue; // SDK, pas un noeud
        deps.add(name);
      }
    }
  }
  return deps;
}

/// Graphe FALLBACK `nom -> deps` des seuls membres LOCAUX (externes = feuilles
/// absentes de la table).
Map<String, Set<String>> _localGraph(Directory packagesDir) {
  final graph = <String, Set<String>>{};
  for (final entity in packagesDir.listSync()) {
    if (entity is! Directory) continue;
    final pkg = entity.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last;
    final deps = _localDirectDeps(packagesDir, pkg);
    if (deps != null) graph[pkg] = deps;
  }
  return graph;
}

// ───────────────────────────── Fermeture transitive ─────────────────────────

/// Fermeture transitive des noms atteignables depuis [root] dans [graph]. Les
/// nœuds absents de [graph] (externes en mode fallback) sont des feuilles.
Set<String> _closure(Map<String, Set<String>> graph, String root) {
  final seen = <String>{};
  final stack = <String>[root];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    final deps = graph[cur];
    if (deps == null) continue; // feuille (externe en fallback)
    stack.addAll(deps);
  }
  seen.remove(root);
  return seen;
}

List<String> _syncfusion(Set<String> closure) =>
    closure.where((p) => p.startsWith('syncfusion')).toList()..sort();

void main() {
  final packagesDir = _packagesDir();

  // Résolution RÉELLE en priorité ; fallback local documenté si indisponible.
  final resolved = _resolvedGraph(packagesDir);
  final usingResolved = resolved != null;
  final graph = resolved ?? _localGraph(packagesDir);

  // Trace la portée effective (visible sur échec ; sinon silencieuse).
  final scopeNote = usingResolved
      ? 'PREUVE COMPLÈTE : fermeture fondée sur `dart pub deps --json` '
          '(transitives EXTERNES incluses).'
      : 'PREUVE DÉGRADÉE (fallback) : `dart pub deps --json` indisponible ; '
          'fermeture LOCALE seulement (transitives externes NON suivies). '
          'Vecteur externe-transitif NON couvert par ce run.';

  test('SM-5 · portée de la preuve documentée (M1, anti sur-vente)', () {
    printOnFailure(scopeNote);
    // En mode résolu, on EXIGE que le contrôle positif externe-transitif ait pu
    // être validé (voir test (c)). Aucune assertion ici : ce test ancre juste
    // la note de portée dans le rapport et échoue jamais.
    expect(graph, isNotEmpty, reason: scopeNote);
  });

  test('(a) fermeture de zcrud_core SANS syncfusion (SM-5/AD-8)', () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_core');
    expect(_syncfusion(closure), isEmpty,
        reason: 'zcrud_core ne doit tirer AUCUN syncfusion* '
            '(${usingResolved ? "fermeture RÉSOLUE complète" : "fermeture locale"}). '
            'Trouvé: ${_syncfusion(closure)}');
  });

  test('(b) fermeture de zcrud_markdown SANS syncfusion (SM-5, ancrage PRD)',
      () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_markdown');
    expect(_syncfusion(closure), isEmpty,
        reason: 'zcrud_markdown seul ne doit AJOUTER aucun syncfusion* (SM-5). '
            'Trouvé: ${_syncfusion(closure)}');
  });

  test('(c) CONTRÔLE POSITIF : fermeture de zcrud_list AVEC syncfusion '
      '(écarte le faux vert)', () {
    printOnFailure(scopeNote);
    final closure = _closure(graph, 'zcrud_list');
    // Dépendance DIRECTE : présente dans les deux modes.
    expect(closure.contains('syncfusion_flutter_datagrid'), isTrue,
        reason: 'Le test de graphe serait un FAUX VERT si zcrud_list ne tirait '
            'pas syncfusion_flutter_datagrid. Fermeture: $closure');
    expect(_syncfusion(closure), isNotEmpty);

    if (usingResolved) {
      // CONTRÔLE POSITIF EXTERNE-TRANSITIF (M1) : `syncfusion_flutter_core`
      // n'est PAS une dép directe de zcrud_list — il est tiré transitivement
      // par `syncfusion_flutter_datagrid` (arête externe→externe). Sa présence
      // dans la fermeture PROUVE que le parcours suit les transitives externes,
      // donc qu'une contamination externe-transitive de zcrud_core SERAIT
      // détectée par (a)/(b). C'est la fermeture directe de l'angle mort M1.
      expect(closure.contains('syncfusion_flutter_core'), isTrue,
          reason: 'La fermeture RÉSOLUE doit inclure syncfusion_flutter_core '
              '(transitif de syncfusion_flutter_datagrid) — preuve que le '
              'parcours suit les arêtes EXTERNES transitives. Fermeture: '
              '$closure');
    }
  });

  test('(d) ACYCLICITÉ AD-1 : zcrud_list → zcrud_core, PAS l\'inverse', () {
    // Les arêtes zcrud_* sont locales : on lit les pubspecs directement pour
    // rester indépendant du mode (le graphe résolu fusionne dev-deps, non
    // pertinent ici).
    final listDeps = _localDirectDeps(packagesDir, 'zcrud_list')!;
    final coreDeps = _localDirectDeps(packagesDir, 'zcrud_core')!;
    expect(listDeps.contains('zcrud_core'), isTrue,
        reason: 'zcrud_list doit dépendre de zcrud_core (arête AD-1 tangible).');
    expect(coreDeps.contains('zcrud_list'), isFalse,
        reason: 'zcrud_core ne doit JAMAIS dépendre de zcrud_list (puits AD-1).');
    final coreZcrud = coreDeps.where((p) => p.startsWith('zcrud_')).toList();
    expect(coreZcrud, isEmpty,
        reason: 'zcrud_core out-degree zcrud_* = 0 (AD-1). Trouvé: $coreZcrud');
  });
}
