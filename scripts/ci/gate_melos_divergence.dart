// Gate M-1 : anti-divergence des blocs `scripts:` melos.
//
// Contexte (code-review E1-1, M-1) : sous melos >= 7 + pub workspaces, melos lit
// ses scripts depuis le bloc `melos:` du root `pubspec.yaml` (SOURCE DE VÉRITÉ)
// et IGNORE le bloc `scripts:` de `melos.yaml` (copie conservée pour lisibilité).
// Ce gate garantit que les deux blocs restent IDENTIQUES : toute divergence
// (script modifié dans un fichier et pas l'autre) échoue (exit != 0).
//
// Comparaison SÉMANTIQUE : mêmes clés de scripts, et pour chacune mêmes
// `run`/`exec`/`description`/`packageFilters` (indépendant de l'ordre des clés).
//
// Usage : dart run scripts/ci/gate_melos_divergence.dart [--pubspec <p>] [--melos <m>]
//   overrides de chemins pour les fixtures de preuve.
import 'dart:io';
import 'package:yaml/yaml.dart';

Object? _normalize(Object? node) {
  if (node is YamlMap || node is Map) {
    final m = <String, Object?>{};
    (node as Map).forEach((k, v) => m['$k'] = _normalize(v));
    return m;
  }
  if (node is YamlList || node is List) {
    return (node as List).map(_normalize).toList();
  }
  return node;
}

Map<String, Object?> _scriptsFromPubspec(String path) {
  final doc = loadYaml(File(path).readAsStringSync());
  final melos = doc is YamlMap ? doc['melos'] : null;
  final scripts = melos is YamlMap ? melos['scripts'] : null;
  return (_normalize(scripts) as Map<String, Object?>?) ?? <String, Object?>{};
}

Map<String, Object?> _scriptsFromMelosYaml(String path) {
  final doc = loadYaml(File(path).readAsStringSync());
  final scripts = doc is YamlMap ? doc['scripts'] : null;
  return (_normalize(scripts) as Map<String, Object?>?) ?? <String, Object?>{};
}

String _canon(Object? o) {
  // Sérialisation déterministe (clés triées) pour une comparaison stable.
  if (o is Map) {
    final keys = o.keys.map((e) => '$e').toList()..sort();
    return '{${keys.map((k) => '$k:${_canon(o[k])}').join(',')}}';
  }
  if (o is List) return '[${o.map(_canon).join(',')}]';
  return '$o';
}

void main(List<String> args) {
  var pubspecPath = 'pubspec.yaml';
  var melosPath = 'melos.yaml';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--pubspec' && i + 1 < args.length) pubspecPath = args[i + 1];
    if (args[i] == '--melos' && i + 1 < args.length) melosPath = args[i + 1];
  }

  final a = _scriptsFromPubspec(pubspecPath);
  final b = _scriptsFromMelosYaml(melosPath);

  final keysA = a.keys.toSet();
  final keysB = b.keys.toSet();
  final onlyA = keysA.difference(keysB);
  final onlyB = keysB.difference(keysA);
  final divergent = <String>[];
  for (final k in keysA.intersection(keysB)) {
    if (_canon(a[k]) != _canon(b[k])) divergent.add(k);
  }

  if (onlyA.isEmpty && onlyB.isEmpty && divergent.isEmpty) {
    stdout.writeln('gate:melos OK — blocs scripts identiques (${a.length} scripts, M-1).');
    exit(0);
  }
  stderr.writeln('gate:melos VIOLATION M-1 — divergence des blocs scripts melos:');
  if (onlyA.isNotEmpty) stderr.writeln('  seulement dans pubspec.yaml: ${onlyA.toList()..sort()}');
  if (onlyB.isNotEmpty) stderr.writeln('  seulement dans melos.yaml:   ${onlyB.toList()..sort()}');
  if (divergent.isNotEmpty) stderr.writeln('  contenu divergent:           ${divergent..sort()}');
  exit(1);
}
