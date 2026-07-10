// Slot CI E2-10 (AD-10) : rétro-compatibilité de sérialisation.
//
// AD-10 (architecture.md) : évolution de schéma ADDITIVE + désérialisation
// DÉFENSIVE (un document historique/tronqué/à champs inconnus ne casse jamais le
// parent). La suite de tests correspondante est RATTACHÉE AU GATE DE MERGE en
// E1-3 (cette story câble le SLOT) et sera FOURNIE par E2-10.
//
// Convention de branchement STABLE (E2-10 n'aura PAS à toucher le workflow) :
//   - E2-10 ajoutera des tests taggés `serialization-compat`
//     (`@Tags(['serialization-compat'])`) dans les packages concernés.
//   - Ce script exécute `<runner> test --tags serialization-compat` dans chaque
//     package possédant un dossier `test/`, où `<runner>` est `flutter` pour un
//     package Flutter (dépend du SDK Flutter, ex. `zcrud_core` depuis E2-7) et
//     `dart` pour un package pur-Dart. `dart test` refuse de tourner dans un
//     package Flutter (dart:ui indisponible) — d'où l'aiguillage par runner.
//   - TANT QU'AUCUN test/dossier `test/` n'existe (état E1-3), c'est un NO-OP VERT.
//
// Usage : dart run scripts/ci/verify_serialization.dart
import 'dart:io';

/// `true` si le package [pkgDir] dépend du SDK Flutter (bloc `dependencies:`
/// contenant `flutter:` avec `sdk: flutter`). Détection textuelle robuste et
/// sans dépendance : parcourt `pubspec.yaml` et repère un `flutter:` sous
/// `dependencies:` (le SDK est déclaré `flutter:\n    sdk: flutter`).
bool _isFlutterPackage(Directory pkgDir) {
  final pubspec = File('${pkgDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  var inDeps = false;
  for (final raw in pubspec.readAsLinesSync()) {
    final line = raw.replaceFirst(RegExp(r'#.*$'), '');
    if (RegExp(r'^dependencies:\s*$').hasMatch(line)) {
      inDeps = true;
      continue;
    }
    // Une clé top-level non indentée ferme le bloc dependencies.
    if (inDeps && RegExp(r'^[A-Za-z_]').hasMatch(line)) inDeps = false;
    if (inDeps && RegExp(r'^\s+flutter:\s*$').hasMatch(line)) return true;
  }
  return false;
}

void main() {
  final pkgs = Directory('packages');
  if (!pkgs.existsSync()) {
    stdout.writeln('verify:serialization NO-OP — pas de packages/. Slot E2-10 (AD-10).');
    exit(0);
  }

  final withTests = <Directory>[];
  for (final ent in pkgs.listSync()) {
    if (ent is Directory && Directory('${ent.path}/test').existsSync()) {
      withTests.add(ent);
    }
  }

  if (withTests.isEmpty) {
    stdout.writeln(
        'verify:serialization NO-OP VERT — aucun dossier test/ (etat E1-3). '
        'Slot rattache au gate de merge ; E2-10 fournira les tests taggés '
        '`serialization-compat` (AD-10), branches ici sans toucher au workflow.');
    exit(0);
  }

  var failed = false;
  for (final pkg in withTests) {
    final runner = _isFlutterPackage(pkg) ? 'flutter' : 'dart';
    final r = Process.runSync(
      runner,
      ['test', '--tags', 'serialization-compat'],
      workingDirectory: pkg.path,
    );
    // exit 79 = "no tests ran" (aucun test taggé `serialization-compat`) =>
    // toléré (dart ET flutter). On NE RELAIE PAS le stderr brut
    // « ERROR: No tests match the requested tag selectors » : ce texte « ERROR »
    // est TROMPEUR alors que le gate TOLÈRE explicitement ce cas (il a déjà
    // induit un reviewer en erreur — LOW-4). On imprime à la place une ligne
    // claire SKIP. RC global inchangé (0) ; sémantique du gate inchangée.
    if (r.exitCode == 79) {
      stdout.writeln(
          'verify:serialization — ${pkg.path} : SKIP (aucun test serialization-compat)');
      continue;
    }
    stdout.writeln(
        'verify:serialization — ${pkg.path} (tag serialization-compat, runner: $runner)');
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    if (r.exitCode != 0) failed = true;
  }
  exit(failed ? 1 : 0);
}
