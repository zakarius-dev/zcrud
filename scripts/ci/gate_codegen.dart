// Gate AD-3 : « modèle = source unique de vérité » — aucun modèle annoté orphelin.
//
// Après `melos run generate` (build_runner), tout fichier déclarant un modèle
// annoté `@ZcrudModel` DOIT posséder son part généré `<basename>.g.dart` PRÉSENT
// SUR DISQUE (le .g.dart est gitignoré donc régénéré ; on vérifie la présence
// APRÈS codegen, pas dans git). Échoue (exit != 0) si un `.g.dart` attendu manque.
//
// À E1-3, aucun `@ZcrudModel` n'existe (annotations = E2-4, générateur = E2-5) :
// 0 modèle => 0 orphelin => PASSE. Le gate est correct par construction et
// prouvé par fixture (« annoté sans .g.dart »). Convention cible confirmée avec
// E2-4 : `@ZcrudModel` sur la classe + `part '<file>.g.dart';`.
//
// Usage : dart run scripts/ci/gate_codegen.dart [--root <dir>]
//   --root : dossier à scanner (défaut : packages). Sert aux fixtures.
import 'dart:io';

// Application RÉELLE de l'annotation (ligne commençant par `@ZcrudModel` ou,
// L-1, une forme aliasée par préfixe d'import `@z.ZcrudModel`), PAS une simple
// mention en commentaire de doc (`/// ... `@ZcrudModel` ...`).
final _modelAnno = RegExp(r'^\s*@(?:[A-Za-z_][A-Za-z0-9_]*\.)?ZcrudModel\b', multiLine: true);

void main(List<String> args) {
  var root = 'packages';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) root = args[i + 1];
  }

  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('gate:codegen — dossier introuvable: $root');
    exit(2);
  }

  var models = 0;
  final missing = <String>[];
  for (final ent in dir.listSync(recursive: true, followLinks: false)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    if (ent.path.endsWith('.g.dart')) continue;
    final norm = ent.path.replaceAll('\\', '/');
    final content = ent.readAsStringSync();
    if (!_modelAnno.hasMatch(content)) continue;
    models++;
    // .g.dart attendu = même chemin, suffixe .g.dart
    final expected = ent.path.substring(0, ent.path.length - '.dart'.length) + '.g.dart';
    if (!File(expected).existsSync()) {
      missing.add('$norm (attendu: ${expected.replaceAll('\\', '/')})');
    }
  }

  if (missing.isEmpty) {
    stdout.writeln('gate:codegen OK — $models modele(s) @ZcrudModel, 0 .g.dart manquant (AD-3).');
    exit(0);
  }
  stderr.writeln('gate:codegen VIOLATION AD-3 — modele(s) annote(s) sans .g.dart genere:');
  for (final m in missing) {
    stderr.writeln('  - $m');
  }
  stderr.writeln('Executer `melos run generate` avant ce gate.');
  exit(1);
}
