// Preuve reproductible « échoue sur violation, passe sinon » des gates (AC 10).
// 5 gates d'architecture (reflectable/secrets/codegen/melos/graph) + gate:compat
// FR-25 (E1-4, dry-run de résolution du triplet flutter_quill+awesome_select+analyzer)
// + gate:reserved-keys (ES-1.4, AD-19.1 : volet B syntaxique + couverture).
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

// ---------------------------------------------------------------------------
// gate:reserved-keys — fixtures de la règle (3) `E_disk \ E_covered` (H1/M1)
// ---------------------------------------------------------------------------
//
// **Pourquoi ces fixtures existent (M1).** Jusqu'à la revue d'ES-1.4, la règle
// (3) — celle dont la mission EST d'attraper « une entité `ZExtensible` que
// personne ne sonde » — n'avait AUCUNE fixture propre : sa preuve était CONFONDUE
// avec celle du volet (B) (la classe `ZBad` déclenchait les deux, et l'assertion
// ne regardait que `exitCode != 0`). Elle serait donc restée verte même si la
// règle (3) n'existait pas. C'est exactement ce qui a laissé passer **H1** : un
// détecteur ligne-à-ligne aveugle à 3 formes de déclaration LÉGALES.
//
// Les fixtures ci-dessous **isolent** la règle (3) : chacune contient BIEN
// `...ZSyncMeta.reservedKeys` (⇒ volet (B) VERT, et on l'ASSERTE : le message du
// volet (B) doit être ABSENT) et n'apporte ni `*.g.dart` ni harnais (⇒ règles (1),
// (2), (4) muettes). Le gate ne peut donc rougir QUE par la règle (3).
//
// Elles couvrent les 4 formes de déclaration du finding + l'alias de classe.

/// Garde `_reservedKeys` RÉEL (jetons, pas commentaire) ⇒ volet (B) satisfait.
const String _rkGuard =
    '  static const Set<String> _reservedKeys = '
    '<String>{...ZSyncMeta.reservedKeys};\n';

/// Message du volet (B) — doit être ABSENT des fixtures de la règle (3).
const String _rkVoletBMsg = 'ajoutez `...ZSyncMeta.reservedKeys`';

/// Crée une fixture `packages/zcrud_fake/lib/src/e.dart` portant [source].
String _rkFixture(Directory tmp, String name, String source) {
  final dir = Directory('${tmp.path}/$name');
  Directory('${dir.path}/packages/zcrud_fake/lib/src').createSync(recursive: true);
  File('${dir.path}/packages/zcrud_fake/lib/src/e.dart').writeAsStringSync(source);
  return dir.path;
}

/// Prouve que le gate rougit par la **règle (3) SEULE** sur [classes].
void _checkRule3(Directory tmp, String name, List<String> classes, String source) {
  final root = _rkFixture(tmp, name, source);
  final r = _dart(['scripts/ci/gate_reserved_keys.dart', '--root', root]);
  final out = '${r.stdout}${r.stderr}';
  final byRule3 =
      classes.every((String c) => out.contains('`$c` est `ZExtensible`'));
  final voletBSilent = !out.contains(_rkVoletBMsg);
  _check(
    'reserved-keys/$name',
    r.exitCode != 0 && byRule3 && voletBSilent,
    'exit=${r.exitCode} (attendu !=0) · règle (3) nomme ${classes.join("+")}: '
    '$byRule3 · volet (B) MUET (preuve isolée): $voletBSilent',
  );
}

void main() {
  final tmp = Directory.systemTemp.createTempSync('zcrud_gate_proof_');
  // M-3 : fixture ÉPHÉMÈRE dans l'arbre RÉEL (packages/zcrud_core/bin) — le
  // filtre de répertoire du gate ne s'active qu'avec le root réel `packages`.
  // Nettoyée dans le finally quoi qu'il arrive (jamais committée).
  final binFixture = File('packages/zcrud_core/bin/__gate_proof_reflectable_probe.dart');
  // ES-1.4 (AC6) : même preuve dans un package STUDY — l'AC de l'epic exige que
  // le gate anti-reflectable couvre les packages study, pas seulement le cœur.
  // Fixture ÉPHÉMÈRE, nettoyée dans le finally (jamais committée).
  final studyFixture =
      File('packages/zcrud_study_kernel/bin/__gate_proof_reflectable_probe.dart');
  // ES-1/D1 : la fixture du gate `codegen-distribution` doit vivre DANS l'arbre
  // git (l'autorité du verdict est `git check-ignore`, inopérant hors dépôt) —
  // répertoire temp ÉPHÉMÈRE créé à la racine, supprimé dans le `finally`.
  Directory? distTmp;
  // Fail-closed : si une exception traverse le `try`, on sort ROUGE (après
  // nettoyage), jamais VERT.
  var rc = 1;
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

    // ES-1.4 (AC6) : reflectable dans un package STUDY (zcrud_study_kernel/bin)
    // est détecté sur l'arbre RÉEL — le gate n'a AUCUNE liste en dur de packages.
    studyFixture.parent.createSync(recursive: true);
    studyFixture.writeAsStringSync(
        "import 'package:reflectable/reflectable.dart';\nvoid main() {}\n");
    final rStudy = _dart(['scripts/ci/gate_reflectable.dart']);
    _check('reflectable/study-package-scanned', rStudy.exitCode != 0,
        'exit=${rStudy.exitCode} (attendu !=0 — package study couvert, ES-1.4 AC6)');
    studyFixture.deleteSync();

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

    // ---- Gate codegen-distribution (ES-1/D1) ----
    //
    // ⚠️ FIXTURE DÉDIÉE ET ISOLÉE (règle R2 de la rétro ES-1 : une fixture qui
    // déclenche deux règles n'en prouve aucune). Ce gate n'a qu'UNE règle — « un
    // `part` d'un `lib/` distribué ne doit pas désigner un fichier gitignoré » —
    // et on la prouve dans les DEUX sens :
    //   (a) fixture VIOLANTE : `part 'e.g.dart'` dont la cible est gitignorée
    //       (la négation `!packages/*/lib/**/*.g.dart` de la racine est ANCRÉE sur
    //       `packages/` : elle ne s'applique pas au chemin de la fixture, hors
    //       `packages/`) ⇒ ROUGE, et le message DOIT nommer le fichier + la
    //       négation corrective ;
    //   (b) CONTRE-ÉPREUVE : la MÊME fixture avec un `part` NON gitignoré ⇒ VERT.
    //       Sans (b), un gate qui rougirait sur la simple PRÉSENCE d'un `part`
    //       passerait la preuve (a) sans rien prouver du tout.
    //
    // La fixture vit DANS le dépôt (répertoire temp à la racine) : l'autorité du
    // verdict est `git check-ignore`, qui n'a de sens que dans un arbre git.
    stdout.writeln('== gate:codegen-distribution ==');
    final dClean = _dart(['scripts/ci/gate_codegen_distribution.dart']);
    _check('codegen-dist/clean', dClean.exitCode == 0, 'exit=${dClean.exitCode} (attendu 0)');

    distTmp = Directory('.').createTempSync('.zcrud_gate_dist_');
    final fakeLib = Directory('${distTmp.path}/packages/zcrud_fake_dist/lib/src')
      ..createSync(recursive: true);
    File('${fakeLib.path}/e.dart').writeAsStringSync(
        "// Fixture éphémère (prove_gates) — codegen gitignoré dans un lib/.\n"
        "part 'e.g.dart';\n\nclass ZFakeDist {}\n");
    File('${fakeLib.path}/e.g.dart').writeAsStringSync('part of \'e.dart\';\n');
    final dBad = _dart([
      'scripts/ci/gate_codegen_distribution.dart',
      '--root', '${distTmp.path}/packages',
    ]);
    final dOut = '${dBad.stdout}${dBad.stderr}';
    // Le gate imprime des chemins relatifs au cwd, sans le `./` que
    // `Directory('.').createTempSync` place en tête : on normalise avant de comparer.
    final fakeGen = '${fakeLib.path}/e.g.dart'
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^\./'), '');
    final namesFile = dOut.contains(fakeGen);
    final namesFix = dOut.contains('!packages/zcrud_fake_dist/lib/**/*.g.dart');
    _check(
      'codegen-dist/fixture-part-gitignore',
      dBad.exitCode != 0 && namesFile && namesFix,
      'exit=${dBad.exitCode} (attendu !=0) · nomme le .g.dart gitignoré: $namesFile · '
      'donne la négation corrective: $namesFix',
    );

    // (b) Contre-épreuve : `part` vers un fichier NON gitignoré ⇒ VERT.
    File('${fakeLib.path}/e.dart').writeAsStringSync(
        "part 'e_impl.dart';\n\nclass ZFakeDist {}\n");
    File('${fakeLib.path}/e_impl.dart').writeAsStringSync("part of 'e.dart';\n");
    File('${fakeLib.path}/e.g.dart').deleteSync();
    final dOk = _dart([
      'scripts/ci/gate_codegen_distribution.dart',
      '--root', '${distTmp.path}/packages',
    ]);
    _check(
      'codegen-dist/contre-epreuve-part-versionne',
      dOk.exitCode == 0,
      'exit=${dOk.exitCode} (attendu 0 — un `part` NON gitignoré ne doit PAS rougir : '
      'prouve que la rougeur de la fixture vient bien de l\'IGNORABILITÉ)',
    );

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

    // ---- Gate reserved-keys (AD-19.1, ES-1.4) ----
    // Volet (A) comportemental : prouvé EN PERMANENCE par le contre-exemple
    // mensonger `_LyingEntity` du harnais (tool/reserved_keys_gate) — le gate ne
    // peut pas devenir tautologiquement vert. On prouve ici les deux voies
    // STATIQUES (volet B syntaxique + contrôle de couverture), sur fixtures.
    stdout.writeln('== gate:reserved-keys (AD-19.1, ES-1.4) ==');
    final rkClean = _dart(['scripts/ci/gate_reserved_keys.dart']);
    _check('reserved-keys/clean', rkClean.exitCode == 0,
        'exit=${rkClean.exitCode} (attendu 0 — arbre réel, volets A+B+couverture)');

    // Fixture volet (B) : classe `with ZExtensible` SANS `ZSyncMeta.reservedKeys`.
    final rkB = Directory('${tmp.path}/rkb')..createSync();
    Directory('${rkB.path}/packages/zcrud_fake/lib/src')
        .createSync(recursive: true);
    File('${rkB.path}/packages/zcrud_fake/lib/src/z_bad.dart').writeAsStringSync(
        'class ZBad extends ZEntity with ZExtensible {\n'
        '  ZBad(this.extra);\n'
        '  final Map<String, dynamic> extra;\n'
        '}\n');
    final rkBadB =
        _dart(['scripts/ci/gate_reserved_keys.dart', '--root', rkB.path]);
    final rkBadBOut = '${rkBadB.stdout}${rkBadB.stderr}';
    _check(
        'reserved-keys/fixture-syntaxique',
        rkBadB.exitCode != 0 && rkBadBOut.contains(_rkVoletBMsg),
        'exit=${rkBadB.exitCode} (attendu !=0 — ZExtensible sans '
        'ZSyncMeta.reservedKeys) · message du volet (B) présent: '
        '${rkBadBOut.contains(_rkVoletBMsg)}');

    // Fixture COUVERTURE (1) : un registrar généré existe sur disque mais n'est
    // câblé nulle part dans le harnais (faux vert par omission).
    final rkC = Directory('${tmp.path}/rkc')..createSync();
    Directory('${rkC.path}/packages/zcrud_fake/lib/src')
        .createSync(recursive: true);
    File('${rkC.path}/packages/zcrud_fake/lib/src/z_ghost.g.dart')
        .writeAsStringSync(
            'void registerZGhost(ZcrudRegistry registry) =>\n'
            "    registry.register<ZGhost>('ghost');\n");
    final rkBadC =
        _dart(['scripts/ci/gate_reserved_keys.dart', '--root', rkC.path]);
    final rkBadCOut = '${rkBadC.stdout}${rkBadC.stderr}';
    _check(
        'reserved-keys/fixture-registrar-non-cable',
        rkBadC.exitCode != 0 && rkBadCOut.contains('n\'est pas câblé dans'),
        'exit=${rkBadC.exitCode} (attendu !=0 — registrar non câblé = faux vert '
        'par omission)');

    // Fixture COUVERTURE (2) — CÂBLAGE MORT : le harnais câble `registerZGhost`
    // (élément RÉEL du littéral `kRegistrars`) alors qu'aucun `*.g.dart` du
    // disque ne le déclare. Règle (2) jamais prouvée avant (M1).
    final rkD = Directory('${tmp.path}/rkd')..createSync();
    Directory('${rkD.path}/packages/zcrud_fake/lib').createSync(recursive: true);
    Directory('${rkD.path}/tool/reserved_keys_gate/lib/src')
        .createSync(recursive: true);
    File('${rkD.path}/tool/reserved_keys_gate/lib/src/registrars.dart')
        .writeAsStringSync(
            'const List<ZRegistrar> kRegistrars = <ZRegistrar>[registerZGhost];\n'
            'const Map<String, Map<String, dynamic>> kProbeBodies =\n'
            '    <String, Map<String, dynamic>>{};\n');
    final rkBadD =
        _dart(['scripts/ci/gate_reserved_keys.dart', '--root', rkD.path]);
    final rkBadDOut = '${rkBadD.stdout}${rkBadD.stderr}';
    _check(
        'reserved-keys/fixture-cablage-mort',
        rkBadD.exitCode != 0 && rkBadDOut.contains('câblage MORT'),
        'exit=${rkBadD.exitCode} (attendu !=0 — registrar câblé, absent du disque)');

    // ---- Règle (3) `E_disk \ E_covered` : PREUVE ISOLÉE, 4 FORMES (H1/M1) ----
    // Chaque fixture est VERTE au volet (B) et ne peut rougir que par (3).
    // ⚠️ Non-régression de H1 : ces 4 formes traversaient le gate en VERT.
    _checkRule3(
      tmp,
      'couverture-forme-1-une-ligne',
      <String>['ZOneLine'],
      'class ZOneLine extends ZEntity with ZExtensible implements ZSyncable {\n'
      '  ZOneLine(this.extra);\n'
      '  final Map<String, dynamic> extra;\n'
      '$_rkGuard'
      '}\n',
    );

    // Forme 2 : en-tête ENROULÉE — c'est `dart format` LUI-MÊME qui la produit
    // dès que la déclaration dépasse 80 colonnes (+ `extra` exposé par GETTER,
    // invisible au volet (B) de la v1).
    _checkRule3(
      tmp,
      'couverture-forme-2-entete-enroulee',
      <String>['ZSmartNoteRevisionSnapshot'],
      'class ZSmartNoteRevisionSnapshot extends ZEntity\n'
      '    with ZExtensible\n'
      '    implements ZSyncable, ZComparableEntity {\n'
      '  ZSmartNoteRevisionSnapshot(this._extra);\n'
      '  final Map<String, dynamic> _extra;\n'
      '  Map<String, dynamic> get extra => _extra;\n'
      '$_rkGuard'
      '}\n',
    );

    _checkRule3(
      tmp,
      'couverture-forme-3-final-class',
      <String>['ZExam'],
      'final class ZExam with ZExtensible {\n'
      '  ZExam(this.extra);\n'
      '  final Map<String, dynamic> extra;\n'
      '$_rkGuard'
      '}\n',
    );

    // Formes 4 : les 3 autres modificateurs de classe Dart 3.
    _checkRule3(
      tmp,
      'couverture-forme-4-base-sealed-interface',
      <String>['ZBaseNote', 'ZSealedNote', 'ZInterfaceNote'],
      'base class ZBaseNote with ZExtensible {\n'
      '  ZBaseNote(this.extra);\n'
      '  final Map<String, dynamic> extra;\n'
      '$_rkGuard'
      '}\n'
      '\n'
      'sealed class ZSealedNote with ZExtensible {\n'
      '  ZSealedNote(this.extra);\n'
      '  final Map<String, dynamic> extra;\n'
      '}\n'
      '\n'
      'interface class ZInterfaceNote with ZExtensible {\n'
      '  ZInterfaceNote(this.extra);\n'
      '  final Map<String, dynamic> extra;\n'
      '}\n',
    );

    // Forme 5 (bonus AST) : alias de classe `class X = Y with ZExtensible;`.
    _checkRule3(
      tmp,
      'couverture-forme-5-alias-de-classe',
      <String>['ZAliasNote'],
      'class ZAliasNote = ZEntity with ZExtensible;\n'
      '\n'
      'class ZHolder {\n'
      '$_rkGuard'
      '}\n',
    );

    stdout.writeln('');
    stdout.writeln('RESULTAT: $_passed OK, $_failed FAIL.');
    rc = _failed == 0 ? 0 : 1;
  } finally {
    // Nettoyage inconditionnel des fixtures éphémères de l'arbre réel (M-3) :
    // jamais laissées committées à l'état de violation.
    _cleanupFixture(binFixture);
    _cleanupFixture(studyFixture);
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
    // Fixture ES-1/D1 : créée à la RACINE du dépôt (contrainte `git check-ignore`)
    // => son nettoyage est NON NÉGOCIABLE (sinon elle apparaîtrait dans
    // `git status` et pourrait être committée à l'état de violation).
    try {
      distTmp?.deleteSync(recursive: true);
    } catch (_) {}
  }
  // ⚠️ `exit()` DOIT rester HORS du `try` : en Dart, `exit()` termine le
  // processus IMMÉDIATEMENT — les blocs `finally` en cours ne sont PAS exécutés.
  // Tant que l'`exit` vivait DANS le `try`, le « nettoyage inconditionnel en
  // finally » ne tournait QUE sur exception : sur le chemin NOMINAL il était du
  // CODE MORT (les `packages/*/bin/` vides et les répertoires temp fuyaient à
  // chaque exécution). Le patron anti-résidu de la story était lui-même un faux
  // vert (constaté en remédiation ES-1.4).
  exit(rc);
}

/// Supprime [fixture] puis son répertoire parent **s'il est VIDE**.
///
/// ⚠️ L'ancien critère (« supprimer le parent seulement s'il ne PRÉEXISTAIT
/// pas ») ne suffisait PAS (code-review ES-1.4) : dès la **deuxième** exécution,
/// le `bin/` créé par la première « préexistait » et n'était donc **plus jamais**
/// supprimé — deux `packages/*/bin/` **vides** restaient sur disque (invisibles à
/// `git status`, qui ne suit pas les répertoires vides, mais bien réels). Le
/// critère « vide » est le bon : un `bin/` légitime porte du code, donc n'est
/// jamais vide et n'est jamais supprimé.
void _cleanupFixture(File fixture) {
  try {
    if (fixture.existsSync()) fixture.deleteSync();
    final parent = fixture.parent;
    if (parent.existsSync() && parent.listSync().isEmpty) parent.deleteSync();
  } catch (_) {}
}
