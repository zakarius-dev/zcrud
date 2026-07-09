// Gate FR-25 (E1-4) : compatibilité de RÉSOLUTION des dépendances lourdes
// d'intégration (flutter_quill + awesome_select + analyzer).
//
// Deux voies (cf. tool/compat_check/README.md) :
//   1. VOIE MANIFESTE (défaut, AUTORITÉ de merge, BLOQUANTE) — exécute
//      `flutter pub get --dry-run` dans le package de compat ISOLÉ
//      `tool/compat_check/`. Un conflit de résolution => exit != 0 (merge bloqué).
//      Déterministe, hermétique, indépendant de la présence du workspace lex_douane.
//   2. VOIE WORKSPACE RÉEL (opportuniste, INFORMATIONNELLE, non bloquante) —
//      activée seulement si l'env `LEX_WORKSPACE` pointe un chemin résoluble ;
//      sinon SKIP propre (gate vert). Une indisponibilité ne fait JAMAIS échouer
//      le gate ; seule la voie manifeste est bloquante.
//
// Dépendance toolchain : `flutter` doit être sur le PATH. Son absence est
// signalée EXPLICITEMENT (exit != 0) — jamais un faux vert silencieux (AC 7).
//
// Usage :
//   dart run scripts/ci/gate_compat_resolution.dart [--package <dir>] [--flutter <bin>]
//     --package <dir> : dossier du package de compat (défaut: tool/compat_check).
//                       Sert aux fixtures de preuve (arbre incompatible temporaire).
//     --flutter <bin> : binaire flutter à utiliser (défaut: `flutter` du PATH).
//   Env LEX_WORKSPACE=<dir> : active la voie opportuniste.
import 'dart:convert';
import 'dart:io';

const _defaultPackage = 'tool/compat_check';

/// Lance `<flutter> pub get --dry-run` dans [dir]. Retourne le ProcessResult,
/// ou `null` si la toolchain Flutter est introuvable (ProcessException).
ProcessResult? _dryRun(String flutter, String dir) {
  try {
    return Process.runSync(
      flutter,
      ['pub', 'get', '--dry-run'],
      workingDirectory: dir,
    );
  } on ProcessException {
    return null; // toolchain absente
  }
}

/// Extrait les versions résolues des dépendances-clés du log de dry-run,
/// pour traçabilité (AC 2).
void _logResolved(String output) {
  final keys = {'flutter_quill', 'awesome_select', 'analyzer'};
  final re = RegExp(r'^[+*!]?\s*(\w+)\s+(\S+)');
  for (final line in const LineSplitter().convert(output)) {
    final m = re.firstMatch(line.trimLeft());
    if (m != null && keys.contains(m.group(1))) {
      stdout.writeln('    résolu: ${m.group(1)} ${m.group(2)}');
    }
  }
}

void main(List<String> args) {
  var packageDir = _defaultPackage;
  var flutter = 'flutter';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--package' && i + 1 < args.length) packageDir = args[i + 1];
    if (args[i] == '--flutter' && i + 1 < args.length) flutter = args[i + 1];
  }

  if (!File('$packageDir/pubspec.yaml').existsSync()) {
    stderr.writeln(
        'gate:compat ERREUR — package de compat introuvable: $packageDir/pubspec.yaml');
    exit(2);
  }

  // ---- VOIE MANIFESTE (bloquante) ----
  stdout.writeln('== gate:compat — voie manifeste (BLOQUANTE) ==');
  stdout.writeln('  flutter pub get --dry-run  (dans $packageDir)');
  final manifest = _dryRun(flutter, packageDir);

  if (manifest == null) {
    // Toolchain Flutter absente : signalé EXPLICITEMENT, pas de faux vert (AC 7).
    stderr.writeln(
        'gate:compat ERREUR TOOLCHAIN — binaire `$flutter` introuvable sur le PATH.');
    stderr.writeln(
        '  Ce gate exige la toolchain Flutter (flutter_quill/awesome_select tirent Flutter).');
    stderr.writeln(
        '  En CI, subosito/flutter-action la fournit. Localement : installer Flutter.');
    exit(3);
  }

  final out = '${manifest.stdout}';
  if (manifest.exitCode != 0) {
    stderr.writeln(
        'gate:compat VIOLATION FR-25 — la résolution du triplet a ÉCHOUÉ (conflit de version).');
    stderr.writeln('  exit=${manifest.exitCode}');
    stderr.write(out);
    stderr.write('${manifest.stderr}');
    exit(1);
  }
  stdout.writeln('  [OK] résolution manifeste réussie (exit=0).');
  _logResolved(out);

  // ---- VOIE WORKSPACE RÉEL (opportuniste, informationnelle) ----
  stdout.writeln('== gate:compat — voie workspace réel (INFORMATIONNELLE) ==');
  final lex = Platform.environment['LEX_WORKSPACE'];
  if (lex == null || lex.trim().isEmpty) {
    stdout.writeln(
        '  [SKIP] LEX_WORKSPACE non défini — voie opportuniste ignorée (gate reste vert).');
  } else if (!File('$lex/pubspec.yaml').existsSync()) {
    stdout.writeln(
        '  [SKIP] LEX_WORKSPACE="$lex" illisible (pas de pubspec.yaml) — informationnel, non bloquant.');
  } else {
    stdout.writeln('  flutter pub get --dry-run  (dans $lex)');
    final real = _dryRun(flutter, lex);
    if (real == null) {
      stdout.writeln(
          '  [INFO] toolchain Flutter absente pour la voie opportuniste — ignoré (non bloquant).');
    } else if (real.exitCode != 0) {
      stdout.writeln(
          '  [INFO] résolution contre le workspace lex_douane réel NON concluante '
          '(exit=${real.exitCode}) — INFORMATIONNEL, non bloquant.');
    } else {
      stdout.writeln(
          '  [OK] résolution contre le workspace lex_douane réel réussie (exit=0).');
    }
  }

  stdout.writeln('gate:compat OK — voie manifeste verte (autorité de merge).');
  exit(0);
}
