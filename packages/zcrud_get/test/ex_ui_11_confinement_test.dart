// EX-UI.11 AC1/AC4 — `get` confiné au binding (AD-15). Test STATIQUE : scanne
// les directives `import`/`export` des sources de `zcrud_navigation/lib` ET
// `zcrud_ui_kit/lib` → AUCUNE ne référence `package:get/` ni `go_router` ; et
// `package:get/` n'apparaît QUE dans `zcrud_get/lib`. Scan des directives
// uniquement (jamais la prose dartdoc). Robuste au cwd (racine repo ou package).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Remonte depuis le cwd jusqu'à la racine du monorepo (dossier contenant
/// `packages/zcrud_navigation`).
Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/packages/zcrud_navigation').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Racine du monorepo introuvable depuis ${Directory.current.path}');
    }
    dir = parent;
  }
}

/// Directive `import '...'` / `export '...'` — ignore la prose (dartdoc/comment).
final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// Retourne l'ensemble des URIs importées/exportées par les `.dart` sous [libDir].
Set<String> _directiveUris(Directory libDir) {
  final uris = <String>{};
  if (!libDir.existsSync()) return uris;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final line in entity.readAsLinesSync()) {
      final m = _directive.firstMatch(line);
      if (m != null) uris.add(m.group(1)!);
    }
  }
  return uris;
}

/// Comme [_directiveUris] mais garde le fichier fautif pour un message clair.
List<String> _offenders(Directory libDir, bool Function(String uri) bad) {
  final hits = <String>[];
  if (!libDir.existsSync()) return hits;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final line in entity.readAsLinesSync()) {
      final m = _directive.firstMatch(line);
      if (m != null && bad(m.group(1)!)) {
        hits.add('${entity.path} → ${m.group(1)}');
      }
    }
  }
  return hits;
}

void main() {
  final root = _repoRoot();
  bool isManager(String uri) =>
      uri.startsWith('package:get/') || uri.contains('go_router');

  test('zcrud_navigation/lib n\'importe NI get NI go_router (AC1/AC4)', () {
    final offenders =
        _offenders(Directory('${root.path}/packages/zcrud_navigation/lib'), isManager);
    expect(offenders, isEmpty, reason: 'get/go_router fuit dans zcrud_navigation: $offenders');
  });

  test('zcrud_ui_kit/lib n\'importe NI get NI go_router (AC2/AC4)', () {
    final offenders =
        _offenders(Directory('${root.path}/packages/zcrud_ui_kit/lib'), isManager);
    expect(offenders, isEmpty, reason: 'get/go_router fuit dans zcrud_ui_kit: $offenders');
  });

  test('package:get/ EST bien présent dans zcrud_get/lib (confiné, AD-15)', () {
    final uris = _directiveUris(Directory('${root.path}/packages/zcrud_get/lib'));
    expect(
      uris.any((u) => u.startsWith('package:get/')),
      isTrue,
      reason: 'le binding GetX doit importer package:get/ (idiome manager confiné)',
    );
  });

  test(
      'clause « QUE » AC4/AD-15 : AUCUN package sauf zcrud_get n\'importe get/'
      'go_router (balayage exhaustif packages/*/lib — pas juste nav+ui_kit)',
      () {
    // Renforce le MEDIUM du code-review : le scan restreint à nav+ui_kit ne
    // prouvait pas l\'absence de fuite dans zcrud_responsive (transitif) ou
    // tout autre package. On balaie donc TOUS les `packages/*/lib` en excluant
    // le seul binding autorisé à importer `get` : zcrud_get.
    final packagesDir = Directory('${root.path}/packages');
    final leaks = <String>[];
    for (final pkg in packagesDir.listSync().whereType<Directory>()) {
      if (pkg.path.endsWith('/zcrud_get')) continue; // seul autorisé (AD-15).
      leaks.addAll(_offenders(Directory('${pkg.path}/lib'), isManager));
    }
    expect(leaks, isEmpty,
        reason: 'get/go_router fuit hors du binding zcrud_get : $leaks');
  });
}
