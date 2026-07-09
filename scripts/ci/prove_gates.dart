// Preuve reproductible « échoue sur violation, passe sinon » des gates (AC 10).
// 5 gates d'architecture (reflectable/secrets/codegen/melos/graph) + gate:compat
// FR-25 (E1-4, dry-run de résolution du triplet flutter_quill+awesome_select+analyzer).
//
// Conforme à la contrainte : AUCUNE fixture n'est laissée committée à l'état de
// violation. Ce harnais crée des fixtures ÉPHÉMÈRES (répertoires temp), exécute
// chaque gate (a) sur l'arbre RÉEL => attendu exit=0, (b) sur la fixture de
// VIOLATION => attendu exit!=0, puis NETTOIE. Il sort 0 seulement si TOUS les
// gates se comportent correctement.
//
// Usage : dart run scripts/ci/prove_gates.dart
import 'dart:io';

int _passed = 0;
int _failed = 0;

void _check(String name, bool ok, String detail) {
  if (ok) {
    _passed++;
    stdout.writeln('  [OK]   $name — $detail');
  } else {
    _failed++;
    stdout.writeln('  [FAIL] $name — $detail');
  }
}

ProcessResult _dart(List<String> a) => Process.runSync('dart', ['run', ...a]);
ProcessResult _py(List<String> a) => Process.runSync('python3', a);

void main() {
  final tmp = Directory.systemTemp.createTempSync('zcrud_gate_proof_');
  // M-3 : fixture ÉPHÉMÈRE dans l'arbre RÉEL (packages/zcrud_core/bin) — le
  // filtre de répertoire du gate ne s'active qu'avec le root réel `packages`.
  // Nettoyée dans le finally quoi qu'il arrive (jamais committée).
  final binFixture = File('packages/zcrud_core/bin/__gate_proof_reflectable_probe.dart');
  final binDirPreexisted = binFixture.parent.existsSync();
  try {
    // ---- Gate reflectable (AD-3) ----
    stdout.writeln('== gate:reflectable ==');
    final rClean = _dart(['scripts/ci/gate_reflectable.dart']);
    _check('reflectable/clean', rClean.exitCode == 0, 'exit=${rClean.exitCode} (attendu 0)');

    final refBad = Directory('${tmp.path}/refbad')..createSync();
    File('${refBad.path}/bad.dart').writeAsStringSync(
        "import 'package:reflectable/reflectable.dart';\nclass X {}\n");
    final rBad = _dart(['scripts/ci/gate_reflectable.dart', '--root', refBad.path]);
    _check('reflectable/fixture', rBad.exitCode != 0, 'exit=${rBad.exitCode} (attendu !=0)');

    // Allowlist (M-1) : ReflectableCodec toléré UNIQUEMENT au chemin conventionnel
    // scopé du binding DODLP (zcrud_get/lib/src/data/codecs/reflectable_codec.dart).
    final refAllow = Directory('${tmp.path}/refallow')..createSync();
    final allowPath = Directory(
        '${refAllow.path}/packages/zcrud_get/lib/src/data/codecs')
      ..createSync(recursive: true);
    File('${allowPath.path}/reflectable_codec.dart').writeAsStringSync(
        "import 'package:reflectable/reflectable.dart';\nclass ReflectableCodec {}\n");
    final rAllow = _dart(['scripts/ci/gate_reflectable.dart', '--root', refAllow.path]);
    _check('reflectable/allowlist-scoped', rAllow.exitCode == 0,
        'exit=${rAllow.exitCode} (attendu 0 — chemin scopé DODLP)');

    // M-1 : le MÊME basename reflectable_codec.dart dans le CŒUR est REJETÉ
    // (le cœur n'est jamais exempté, quel que soit le nom de fichier).
    final refCore = Directory('${tmp.path}/refcore')..createSync();
    final corePath = Directory('${refCore.path}/packages/zcrud_core/lib/src')
      ..createSync(recursive: true);
    File('${corePath.path}/reflectable_codec.dart').writeAsStringSync(
        "import 'package:reflectable/reflectable.dart';\nclass ReflectableCodec {}\n");
    final rCore = _dart(['scripts/ci/gate_reflectable.dart', '--root', refCore.path]);
    _check('reflectable/core-rejected', rCore.exitCode != 0,
        'exit=${rCore.exitCode} (attendu !=0 — cœur jamais allowlisté, M-1)');

    // M-3 : reflectable dans packages/zcrud_core/bin/ (hors lib/) est détecté sur
    // l'arbre RÉEL (root=packages). Fixture éphémère, nettoyée dans le finally.
    binFixture.parent.createSync(recursive: true);
    binFixture.writeAsStringSync(
        "import 'package:reflectable/reflectable.dart';\nvoid main() {}\n");
    final rBin = _dart(['scripts/ci/gate_reflectable.dart']);
    _check('reflectable/bin-scanned', rBin.exitCode != 0,
        'exit=${rBin.exitCode} (attendu !=0 — bin/ d\'un package moteur, M-3)');
    binFixture.deleteSync();

    // ---- Gate secrets (AD-12) ----
    stdout.writeln('== gate:secrets ==');
    final sClean = _dart(['scripts/ci/gate_secret_scan.dart']);
    _check('secrets/clean', sClean.exitCode == 0, 'exit=${sClean.exitCode} (attendu 0)');

    // Cle AIza factice construite par concatenation (pas de litteral secret ici).
    final fakeKey = 'AIza' + ''.padRight(35, 'C');
    final secBad = Directory('${tmp.path}/secbad')..createSync();
    File('${secBad.path}/leaked.dart').writeAsStringSync("const k = '$fakeKey';\n");
    final sBad = _dart(['scripts/ci/gate_secret_scan.dart', '--root', secBad.path]);
    _check('secrets/fixture-AIza', sBad.exitCode != 0, 'exit=${sBad.exitCode} (attendu !=0)');

    // H-1 : forme d'AFFECTATION RÉELLE du badCertificateCallback (la seule valide
    // en Dart). Chaine construite en morceaux pour ne pas s'auto-declencher.
    final secBad2 = Directory('${tmp.path}/secbad2')..createSync();
    final badCertAssign =
        'badCertificateCallback ' '= (X509Certificate c, String h, int p) ' '=> true';
    File('${secBad2.path}/net.dart').writeAsStringSync(
        'void s(dynamic client) { client.$badCertAssign; }\n');
    final sBad2 = _dart(['scripts/ci/gate_secret_scan.dart', '--root', secBad2.path]);
    _check('secrets/fixture-badCert-assign', sBad2.exitCode != 0,
        'exit=${sBad2.exitCode} (attendu !=0 — forme d\'affectation réelle, H-1)');

    // H-1 (variante) : affectation avec corps `{ return true; }`.
    final secBad2b = Directory('${tmp.path}/secbad2b')..createSync();
    final badCertBlock = 'badCertificateCallback ' '= (c, h, p) ' '{ return true; }';
    File('${secBad2b.path}/net2.dart').writeAsStringSync(
        'void s(dynamic client) { client.$badCertBlock }\n');
    final sBad2b = _dart(['scripts/ci/gate_secret_scan.dart', '--root', secBad2b.path]);
    _check('secrets/fixture-badCert-block', sBad2b.exitCode != 0,
        'exit=${sBad2b.exitCode} (attendu !=0 — corps { return true }, H-1)');

    // M-2 : secret dans un `.txt` (extension hors ancien jeu figé) — REJETÉ.
    final secBad3 = Directory('${tmp.path}/secbad3')..createSync();
    File('${secBad3.path}/secrets.txt').writeAsStringSync('google_key=$fakeKey\n');
    final sBad3 = _dart(['scripts/ci/gate_secret_scan.dart', '--root', secBad3.path]);
    _check('secrets/fixture-txt', sBad3.exitCode != 0,
        'exit=${sBad3.exitCode} (attendu !=0 — .txt hors ancien jeu d\'extensions, M-2)');

    // M-2 : secret dans un fichier SANS extension (ex. credentials) — REJETÉ.
    final secBad4 = Directory('${tmp.path}/secbad4')..createSync();
    File('${secBad4.path}/credentials').writeAsStringSync('$fakeKey\n');
    final sBad4 = _dart(['scripts/ci/gate_secret_scan.dart', '--root', secBad4.path]);
    _check('secrets/fixture-noext', sBad4.exitCode != 0,
        'exit=${sBad4.exitCode} (attendu !=0 — fichier sans extension, M-2)');

    // ---- Gate codegen (AD-3) ----
    stdout.writeln('== gate:codegen ==');
    final cClean = _dart(['scripts/ci/gate_codegen.dart']);
    _check('codegen/clean', cClean.exitCode == 0, 'exit=${cClean.exitCode} (attendu 0)');

    final cgBad = Directory('${tmp.path}/cgbad')..createSync();
    File('${cgBad.path}/orphan.dart').writeAsStringSync(
        "part 'orphan.g.dart';\n@ZcrudModel()\nclass Orphan {}\n"); // pas de .g.dart
    final cBad = _dart(['scripts/ci/gate_codegen.dart', '--root', cgBad.path]);
    _check('codegen/fixture', cBad.exitCode != 0, 'exit=${cBad.exitCode} (attendu !=0)');

    // L-1 : annotation ALIASÉE par préfixe d'import (@z.ZcrudModel) sans .g.dart — REJETÉ.
    final cgBad2 = Directory('${tmp.path}/cgbad2')..createSync();
    File('${cgBad2.path}/orphan_aliased.dart').writeAsStringSync(
        "import 'package:zcrud_annotations/zcrud_annotations.dart' as z;\n"
        "part 'orphan_aliased.g.dart';\n@z.ZcrudModel()\nclass OrphanAliased {}\n");
    final cBad2 = _dart(['scripts/ci/gate_codegen.dart', '--root', cgBad2.path]);
    _check('codegen/fixture-aliased', cBad2.exitCode != 0,
        'exit=${cBad2.exitCode} (attendu !=0 — @z.ZcrudModel aliasé, L-1)');

    // ---- Gate melos M-1 ----
    stdout.writeln('== gate:melos ==');
    final mClean = _dart(['scripts/ci/gate_melos_divergence.dart']);
    _check('melos/clean', mClean.exitCode == 0, 'exit=${mClean.exitCode} (attendu 0)');

    // Fixture : copie des deux fichiers avec une divergence injectee.
    final pub = File('pubspec.yaml').readAsStringSync();
    final mel = File('melos.yaml').readAsStringSync();
    final pubCopy = File('${tmp.path}/pubspec.yaml')..writeAsStringSync(pub);
    // Diverger : renommer le exec du script analyze dans la copie melos.yaml.
    final melDiverged = mel.replaceFirst('exec: dart analyze .', 'exec: dart analyze --fatal-infos .');
    final melCopy = File('${tmp.path}/melos.yaml')..writeAsStringSync(melDiverged);
    final mBad = _dart([
      'scripts/ci/gate_melos_divergence.dart',
      '--pubspec', pubCopy.path,
      '--melos', melCopy.path,
    ]);
    _check('melos/fixture', mBad.exitCode != 0, 'exit=${mBad.exitCode} (attendu !=0)');

    // ---- Gate acyclicite AD-1 (L-3 : dev_dependencies + dependency_overrides) ----
    stdout.writeln('== gate:graph (AD-1, L-3) ==');
    final gClean = _py(['scripts/dev/graph_proof.py']);
    _check('graph/clean', gClean.exitCode == 0, 'exit=${gClean.exitCode} (attendu 0)');

    // Fixture 1 : cycle via dev_dependencies (prouve que le bloc est desormais lu).
    final gRoot = Directory('${tmp.path}/gpk')..createSync();
    Directory('${gRoot.path}/zcrud_fa').createSync();
    Directory('${gRoot.path}/zcrud_fb').createSync();
    File('${gRoot.path}/zcrud_fa/pubspec.yaml').writeAsStringSync(
        'name: zcrud_fa\ndependencies:\n  zcrud_fb: ^0.0.1\n');
    File('${gRoot.path}/zcrud_fb/pubspec.yaml').writeAsStringSync(
        'name: zcrud_fb\ndev_dependencies:\n  zcrud_fa: ^0.0.1\n'); // back-edge en dev_deps => cycle
    final gDev = _py(['scripts/dev/graph_proof.py', gRoot.path]);
    _check('graph/fixture-dev_dependencies', gDev.exitCode != 0,
        'exit=${gDev.exitCode} (attendu !=0, cycle via dev_dependencies)');

    // Fixture 2 : cycle via dependency_overrides.
    final gRoot2 = Directory('${tmp.path}/gpk2')..createSync();
    Directory('${gRoot2.path}/zcrud_ga').createSync();
    Directory('${gRoot2.path}/zcrud_gb').createSync();
    File('${gRoot2.path}/zcrud_ga/pubspec.yaml').writeAsStringSync(
        'name: zcrud_ga\ndependencies:\n  zcrud_gb: ^0.0.1\n');
    File('${gRoot2.path}/zcrud_gb/pubspec.yaml').writeAsStringSync(
        'name: zcrud_gb\ndependency_overrides:\n  zcrud_ga: ^0.0.1\n');
    final gOvr = _py(['scripts/dev/graph_proof.py', gRoot2.path]);
    _check('graph/fixture-dependency_overrides', gOvr.exitCode != 0,
        'exit=${gOvr.exitCode} (attendu !=0, cycle via dependency_overrides)');

    // ---- Gate compat FR-25 (E1-4) — dry-run de résolution du triplet ----
    // Dépend de la toolchain Flutter (fournie en CI par subosito). La voie
    // manifeste (bloquante) résout tool/compat_check ; la fixture épingle une
    // borne d'analyzer impossible à co-résoudre => échec prouvé.
    stdout.writeln('== gate:compat (FR-25, E1-4) ==');
    final coClean = _dart(['scripts/ci/gate_compat_resolution.dart']);
    _check('compat/clean', coClean.exitCode == 0,
        'exit=${coClean.exitCode} (attendu 0 — triplet co-résout)');

    // Fixture ÉPHÉMÈRE : package de compat avec analyzer borné hors intersection.
    final coBad = Directory('${tmp.path}/compatbad')..createSync();
    File('${coBad.path}/pubspec.yaml').writeAsStringSync(
        'name: zcrud_compat_fixture_bad\n'
        'publish_to: none\n'
        'environment:\n'
        '  sdk: ^3.12.2\n'
        '  flutter: ">=3.24.0"\n'
        'dependencies:\n'
        '  flutter:\n'
        '    sdk: flutter\n'
        '  flutter_quill: ^11.5.0\n'
        '  analyzer: ">=99.0.0 <100.0.0"\n'); // borne impossible => conflit
    final coBadRun =
        _dart(['scripts/ci/gate_compat_resolution.dart', '--package', coBad.path]);
    _check('compat/fixture', coBadRun.exitCode != 0,
        'exit=${coBadRun.exitCode} (attendu !=0 — analyzer hors intersection)');

    // Voie opportuniste : LEX_WORKSPACE absent => SKIP propre, gate reste vert.
    final coSkip = Process.runSync(
        'dart', ['run', 'scripts/ci/gate_compat_resolution.dart'],
        environment: {'LEX_WORKSPACE': '/does/not/exist/lex'});
    _check('compat/opportuniste-skip', coSkip.exitCode == 0,
        'exit=${coSkip.exitCode} (attendu 0 — workspace absent = informationnel)');

    stdout.writeln('');
    stdout.writeln('RESULTAT: $_passed OK, $_failed FAIL.');
    exit(_failed == 0 ? 0 : 1);
  } finally {
    // Nettoyage inconditionnel de la fixture éphémère dans l'arbre réel (M-3) :
    // jamais laissée committée à l'état de violation.
    try {
      if (binFixture.existsSync()) binFixture.deleteSync();
      if (!binDirPreexisted && binFixture.parent.existsSync()) {
        binFixture.parent.deleteSync();
      }
    } catch (_) {}
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}
