// Gate AD-3 : interdiction de `reflectable` dans le moteur zcrud.
//
// AD-3 (architecture.md) : `reflectable` est BANNI du moteur. SEULE exception
// autorisée : l'adaptateur `ReflectableCodec` DODLP (né en E2-6/E7), allowlisté
// par convention de chemin/nom de fichier ci-dessous.
//
// Le gate scanne les sources Dart des packages (`packages/*/lib/**`) et échoue
// (exit != 0) si un fichier hors allowlist importe/référence `package:reflectable`
// ou déclare un `@Reflector`. Choix Dart (pas de grep shell) : testable,
// cross-plateforme (cf. story §Décision mécanisme — historique de grep buggés).
//
// Usage : dart run scripts/ci/gate_reflectable.dart [--root <dir>]
//   --root : dossier à scanner (défaut : packages). Sert aux fixtures de preuve.
import 'dart:io';

// Allowlist AD-3 (M-1) : l'UNIQUE exception est l'adaptateur ReflectableCodec
// DODLP, ancré à un CHEMIN CONVENTIONNEL SCOPÉ à son package de binding — PAS un
// simple basename. Un fichier `reflectable_codec.dart` situé n'importe où ailleurs
// (a fortiori dans le cœur) N'EST PAS exempté.
//
// Chemin réservé (binding GetX/DODLP) : packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart
const _allowlistedSuffix = 'zcrud_get/lib/src/data/codecs/reflectable_codec.dart';

// Packages du MOTEUR où reflectable est banni SANS AUCUNE exception, quel que
// soit le nom du fichier (M-1 : le cœur ne peut jamais être allowlisté).
const _neverExemptPackages = ['zcrud_core'];

bool _inNeverExemptPackage(String norm) {
  for (final pkg in _neverExemptPackages) {
    if (norm.contains('/$pkg/') || norm.startsWith('$pkg/')) return true;
  }
  return false;
}

bool _isAllowlisted(String path) {
  final p = path.replaceAll('\\', '/');
  // Le cœur (et tout package listé) n'est JAMAIS exempté, même nommé reflectable_codec.dart.
  if (_inNeverExemptPackage(p)) return false;
  return p.endsWith(_allowlistedSuffix);
}

// M-3 : répertoires scannés d'un package moteur (pas seulement lib/). Un
// reflectable dans bin/tool/test/example d'un package moteur doit être détecté.
const _scanDirs = ['/lib/', '/bin/', '/tool/', '/test/', '/example/'];

// Motifs de violation : import du package OU annotation @Reflector.
final _reflectableImport = RegExp(r'''package:reflectable/''');
final _reflectorAnno = RegExp(r'@Reflector\b');

void main(List<String> args) {
  var root = 'packages';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) root = args[i + 1];
  }

  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('gate:reflectable — dossier introuvable: $root');
    exit(2);
  }

  final violations = <String>[];
  for (final ent in dir.listSync(recursive: true, followLinks: false)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    // Sur l'arbre réel, scanner lib/ + bin/ + tool/ + test/ + example/ des
    // packages moteur (M-3) ; sur un --root de fixture on scanne tout.
    final norm = ent.path.replaceAll('\\', '/');
    if (root == 'packages' && !_scanDirs.any((d) => norm.contains(d))) continue;
    if (_isAllowlisted(norm)) continue;
    final content = ent.readAsStringSync();
    if (_reflectableImport.hasMatch(content) || _reflectorAnno.hasMatch(content)) {
      violations.add(norm);
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('gate:reflectable OK — 0 usage de reflectable hors allowlist (AD-3).');
    exit(0);
  }
  stderr.writeln('gate:reflectable VIOLATION AD-3 — reflectable interdit dans le moteur:');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  exit(1);
}
