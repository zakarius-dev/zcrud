// Gate ES-1.2 / M1 (généralisé ES-1.4) : **déterminisme web** des packages
// pur-Dart du repo.
//
// ## Pourquoi ce gate existe
//
// `zFnv1a32` (packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart)
// décompose volontairement la multiplication FNV en deux moitiés de 16 bits :
// la variante naïve `(hash * 0x01000193) & 0xFFFFFFFF` **passe 100 % des tests
// sur la VM** et **diverge en JavaScript** (`'a'` → `0xE40C2930` au lieu de
// `0xE40C292C` — mesuré par compilation dart2js réelle, code-review ES-1.2).
//
// Tant que les suites ne tournaient que sous `dart test` (VM), aucun test ne
// pouvait attraper cette régression : le garde-fou n'était qu'un COMMENTAIRE.
// Ce gate rejoue les suites pur-Dart sur la **plateforme JS** (`dart test -p
// node`) — les vecteurs golden FNV s'exécutent donc réellement en JS.
//
// ## Périmètre : DÉCOUVERTE (ES-1.4) — plus aucune liste en dur
//
// Jusqu'à ES-1.4 ce gate portait la SEULE liste en dur du repo
// (`const _kernelPath = 'packages/zcrud_study_kernel'`) : un futur package
// pur-Dart d'ES-2 (`zcrud_note`, `zcrud_session`, `zcrud_exam`…) n'aurait PAS
// été couvert. Périmètre désormais **default-ON** :
//
//   cible = TOUT package `packages/*` **pur-Dart** (pubspec sans `flutter:`
//           `sdk: flutter` dans `dependencies:` — même détection que
//           `verify_serialization.dart`) possédant un dossier `test/`,
//           MOINS l'opt-out ci-dessous.
//
// Un package ES-2 est donc couvert **à sa création**, sans éditer ce gate.
//
// ⚠️ Corollaire ASSUMÉ : un package pur-Dart dont un test importe `dart:io` sans
// `@TestOn('vm')` fera ROUGIR ce gate à sa création (« Piste n°2 » ci-dessous).
// C'est VOULU. On n'ajoute PAS d'opt-out de confort : soit le test est taggé
// `@TestOn('vm')`, soit le package sort de la cible pour une raison ÉCRITE.
//
// ## ⚠️ CONSÉQUENCE ÉCRITE du critère « pur-Dart » (L3, code-review ES-1.4)
//
// Le critère est écrit ; sa **conséquence** ne l'était pas. Elle l'est ici :
//
//   **le déterminisme web n'est vérifié QUE sur les packages PUR-DART.** Les
//   packages **Flutter** (dont **`zcrud_core` depuis E2-7**, et tout futur
//   package study Flutter — `zcrud_study`, une UI de session…) sont **HORS
//   COUVERTURE** de ce gate : `dart test -p node` ne peut pas exécuter une suite
//   qui tire `dart:ui`.
//
// Conséquence concrète : toute future **arithmétique 32-bit / fonction de
// hachage** écrite dans un package **Flutter** ne serait **PAS** rejouée en JS —
// exactement la classe de bug que `zFnv1a32` a révélée (verte sur VM, cassée en
// JS). Aujourd'hui **sans effet** : le seul site sensible du repo
// (`0xFFFFFFFF`) est `zFnv1a32` dans `zcrud_study_kernel` (pur-Dart, donc
// couvert). **Règle de conduite** : une primitive numérique sensible au web se
// place dans un package **pur-Dart** (typiquement `zcrud_study_kernel`), jamais
// dans un package Flutter — c'est la seule façon qu'elle soit gardée par machine.
// (Cf. AD-19 / NFR-S8.)
//
// ## Dégradation propre (environnement sans Node) — MAIS JAMAIS EN CI (L2)
//
// Si l'exécutable Node est introuvable, le gate **n'échoue pas** (ce serait un
// échec d'ENVIRONNEMENT, pas de code) mais **skippe BRUYAMMENT** : bannière
// explicite sur stdout + code de sortie 0.
//
// ⛔ **Ce secours est STRICTEMENT LOCAL.** Sous `CI=true` (posé par GitHub
// Actions & consorts), **tout** skip — Node absent **ou** `ZCRUD_SKIP_WEB_GATE=1`
// — devient un **ÉCHEC (RC=1)**. Un skip est un secours de **poste de dev**,
// **jamais** un échappatoire de CI : c'est précisément par un skip silencieux en
// CI que `gate:web` n'a rien vérifié pendant toute la story ES-1.2 (faux vert
// avéré), et un interrupteur d'environnement qui **verdit** un gate reproduirait
// la même mécanique en pire.
//
// Usage : dart run scripts/ci/gate_web_determinism.dart
//   Variables d'env : ZCRUD_NODE (chemin explicite de node),
//                     ZCRUD_SKIP_WEB_GATE=1 (skip bruyant forcé — REFUSÉ si CI=true),
//                     CI=true (durcit : aucun skip toléré).
import 'dart:io';

/// Opt-out du gate — **allowlist JUSTIFIÉE PAR ÉCRIT** (une entrée = une raison).
///
/// - `zcrud_generator` : **builder `build_runner` VM-only**. Il dépend de
///   `dart:io`/`analyzer`/`build` ; `dart test -p node` y est structurellement
///   inapplicable (ce n'est pas du code embarquable dans une app web, mais un
///   outil de compilation exécuté sur la machine de dev / la CI).
///
/// ⛔ Toute nouvelle entrée exige une raison ÉCRITE ici. « Les tests ne passent
/// pas en JS » N'EST PAS une raison : c'est précisément ce que le gate détecte.
const Set<String> kWebOptOut = <String>{'zcrud_generator'};

/// Racine du repo (le script peut être lancé depuis un sous-dossier via melos).
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/packages').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  stderr.writeln(
    '[gate:web] ÉCHEC : racine du repo introuvable depuis ${Directory.current.path}',
  );
  exit(2);
}

/// `true` si le package [pkgDir] dépend du SDK Flutter (bloc `dependencies:`
/// contenant `flutter:` avec `sdk: flutter`). Détection textuelle robuste et
/// sans dépendance — **même helper que `scripts/ci/verify_serialization.dart`**
/// (le périmètre des deux gates doit rester cohérent).
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

/// Packages **pur-Dart avec `test/`**, hors opt-out (périmètre default-ON).
List<Directory> _targets(Directory root) {
  final pkgs = Directory('${root.path}/packages');
  if (!pkgs.existsSync()) return <Directory>[];
  final out = <Directory>[];
  for (final ent in pkgs.listSync()) {
    if (ent is! Directory) continue;
    final name = ent.path.split(Platform.pathSeparator).last;
    if (kWebOptOut.contains(name)) continue;
    if (!Directory('${ent.path}/test').existsSync()) continue;
    if (_isFlutterPackage(ent)) continue;
    out.add(ent);
  }
  out.sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return out;
}

String? _findNode() {
  final explicit = Platform.environment['ZCRUD_NODE'];
  if (explicit != null && explicit.isNotEmpty && File(explicit).existsSync()) {
    return explicit;
  }
  for (final candidate in <String>['node', 'nodejs']) {
    try {
      final r = Process.runSync('which', <String>[candidate]);
      if (r.exitCode == 0) {
        final path = (r.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } on ProcessException {
      // `which` absent (Windows…) → tenté ci-dessous par exécution directe.
    }
    try {
      final r = Process.runSync(candidate, <String>['--version']);
      if (r.exitCode == 0) return candidate;
    } on ProcessException {
      // Non installé → candidat suivant.
    }
  }
  return null;
}

/// `true` en intégration continue (`CI=true` — GitHub Actions, GitLab, etc.).
bool _isCi() =>
    (Platform.environment['CI'] ?? '').toLowerCase().trim() == 'true';

/// Skip BRUYANT — **interdit en CI** (L2).
///
/// En CI, un skip n'est pas une dégradation propre : c'est un **faux vert**.
/// Le gate échoue donc (RC=1) en nommant la cause à corriger dans le workflow.
void _skip(String reason, List<Directory> targets) {
  if (_isCi()) {
    stderr.writeln('');
    stderr.writeln('=' * 78);
    stderr.writeln('[gate:web] ⛔ ÉCHEC — SKIP REFUSÉ EN CI (CI=true)');
    stderr.writeln('[gate:web] Raison du skip demandé : $reason');
    stderr.writeln(
      '[gate:web] Un skip est un secours de POSTE DE DEV, jamais un échappatoire '
      'de CI.',
    );
    stderr.writeln(
      '[gate:web] C\'est par un skip silencieux que ce gate n\'a RIEN vérifié '
      'pendant toute la story ES-1.2.',
    );
    stderr.writeln(
      '[gate:web] Corrigez le WORKFLOW : `actions/setup-node@v4` doit précéder '
      'les gates ; ne posez',
    );
    stderr.writeln('[gate:web] jamais ZCRUD_SKIP_WEB_GATE=1 en CI.');
    stderr.writeln('=' * 78);
    stderr.writeln('');
    exit(1);
  }
  stdout.writeln('');
  stdout.writeln('=' * 78);
  stdout.writeln('[gate:web] ⚠️  SKIP — DÉTERMINISME WEB NON VÉRIFIÉ (local)');
  stdout.writeln('[gate:web] Raison : $reason');
  stdout.writeln(
    '[gate:web] Packages NON rejoués en JS : '
    '${targets.map((Directory d) => d.path.split(Platform.pathSeparator).last).join(', ')}',
  );
  stdout.writeln(
    '[gate:web] Les vecteurs golden FNV-1a de zcrud_study_kernel n\'ont PAS été '
    'rejoués en JS.',
  );
  stdout.writeln(
    '[gate:web] Une « simplification » de la multiplication décomposée de '
    'zFnv1a32 passerait donc',
  );
  stdout.writeln(
    '[gate:web] INAPERÇUE (verte sur VM, cassée sur le web). Installer Node puis '
    'rejouer :',
  );
  stdout.writeln('[gate:web]     dart run melos run test:js');
  stdout.writeln('=' * 78);
  stdout.writeln('');
  // HORS CI uniquement (cf. garde `_isCi()` ci-dessus) : échec d'ENVIRONNEMENT
  // ≠ échec de code ⇒ build local vert, log bruyant.
  exit(0);
}

void main() {
  final root = _repoRoot();
  final targets = _targets(root);

  if (targets.isEmpty) {
    stdout.writeln(
      '[gate:web] NO-OP — aucun package pur-Dart avec test/ hors opt-out '
      '(${kWebOptOut.join(', ')}).',
    );
    exit(0);
  }

  if (Platform.environment['ZCRUD_SKIP_WEB_GATE'] == '1') {
    _skip('ZCRUD_SKIP_WEB_GATE=1 (skip explicitement demandé)', targets);
  }

  final node = _findNode();
  if (node == null) {
    _skip(
      'exécutable Node introuvable (ni ZCRUD_NODE, ni `node` dans le PATH)',
      targets,
    );
  }

  stdout.writeln('[gate:web] Node : $node');
  stdout.writeln(
    '[gate:web] Cible (pur-Dart avec test/, hors opt-out ${kWebOptOut.join(', ')}) : '
    '${targets.map((Directory d) => d.path.split(Platform.pathSeparator).last).join(', ')}',
  );

  var failed = false;
  for (final pkg in targets) {
    final name = pkg.path.split(Platform.pathSeparator).last;
    stdout.writeln('[gate:web] dart test -p node ($name)…');
    final result = Process.runSync(
      'dart',
      <String>['test', '-p', 'node'],
      workingDirectory: pkg.path,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);

    if (result.exitCode != 0) {
      failed = true;
      stderr.writeln('');
      stderr.writeln(
        '[gate:web] ÉCHEC : la suite de $name ne passe pas en JS.',
      );
      stderr.writeln(
        '[gate:web] Piste n°1 : la multiplication de `zFnv1a32` a-t-elle été '
        '« simplifiée » ? (verte sur VM, CASSÉE sur le web — cf. dartdoc).',
      );
      stderr.writeln(
        '[gate:web] Piste n°2 : un test a-t-il réintroduit `dart:io` '
        'sans `@TestOn(\'vm\')` ?',
      );
    }
  }

  if (failed) exit(1);
  stdout.writeln('[gate:web] OK — déterminisme web VÉRIFIÉ (dart test -p node).');
}
