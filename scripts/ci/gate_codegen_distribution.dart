// Gate ES-1 / D1 : **distribution git du code généré** — aucun `part` gitignoré
// dans un package atteignable en dépendance git.
//
// ## Pourquoi ce gate existe (défaut BLOQUANT constaté au gate de commit ES-1)
//
// Les `*.g.dart` sont gitignorés par défaut (AD-3 : « régénérable, donc non
// suivi ») — vrai TANT QUE le package n'est consommé qu'À L'INTÉRIEUR du dépôt,
// où `melos run generate` tourne avant tout analyze/test/build.
//
// C'est FAUX dès qu'un package est consommé en **dépendance git** : le
// consommateur `pub get` clone l'arbre au tag et **ne régénère JAMAIS** le code
// d'une dépendance (aucun `build_runner` n'est exécuté sur les deps). Un fichier
// `part '<x>.g.dart'` manquant chez lui = **échec de compilation** de sa build.
//
// C'est exactement ce qui s'est produit en ES-1.1 : `ZStudyFolder` et
// `ZStudySessionConfig` (2 entités à codegen) ont été REMONTÉS de
// `zcrud_flashcard` — le seul package qui portait la négation `.gitignore` — vers
// le NOUVEAU package `zcrud_study_kernel`, dont les `.g.dart` restaient
// gitignorés. Tous les gates étaient VERTS : ils tournent dans l'arbre LOCAL,
// APRÈS codegen, où les fichiers existent. **Aucune machine ne regardait git.**
// Ce gate est cette machine.
//
// ## Contrat (règle R1 de la rétro ES-1 : toute règle naît avec son gate)
//
// Pour TOUT package du graphe de distribution git, toute directive `part` de son
// `lib/` DOIT désigner un fichier **NON gitignoré** (donc versionnable, donc
// présent dans l'arbre cloné par le consommateur). Sinon : ROUGE.
//
// ### Univers de distribution (pourquoi « tous les `packages/*` »)
//
// Le monorepo est PRIVÉ (`publish_to: none` × 15) : la seule voie de
// consommation est la **dépendance git** — l'app clone l'arbre au tag et pointe
// ses deps dessus. La fermeture runtime de n'importe quelle racine (aujourd'hui
// `zcrud_flashcard` → `zcrud_core` + `zcrud_study_kernel` + `zcrud_markdown` +
// `zcrud_export` + `zcrud_annotations`) est donc INCLUSE dans `packages/*`, et
// n'importe lequel des 15 peut devenir racine demain (DODLP tire déjà
// `zcrud_core`/`zcrud_get`/`zcrud_markdown`). L'univers conservateur
// « tout `packages/*` » est un SUR-ENSEMBLE de toute fermeture possible : il ne
// peut pas produire de faux vert par « package pas encore câblé » (le piège
// exact d'ES-1.1, où le kernel était neuf), et il couvre par construction les
// packages d'ES-2 (`zcrud_note`, `zcrud_document`, `zcrud_exam`, `zcrud_session`,
// `zcrud_study`) DÈS leur création — zéro liste en dur, zéro édition manuelle.
//
// Son seul coût théorique serait de contraindre un package `packages/*` jamais
// distribué : il n'en existe pas (les harnais dev/test-only vivent sous `tool/`,
// hors `packages/**` — cf. `binding_conformance`, `reserved_keys_gate`).
//
// ### Périmètre : `lib/` SEULEMENT
//
// Seul `lib/` est compilé chez le consommateur d'une dépendance pub. Le
// `test/`, `example/`, `tool/` d'une dépendance ne le sont jamais : leur code
// généré reste gitignoré et régénérable (ex. `packages/zcrud_generator/test/
// models/article.g.dart`, fixture du builder — versionner ce bruit n'apporterait
// RIEN et polluerait chaque diff de codegen).
//
// ## Pourquoi AST et pas regex (règle R5 de la rétro ES-1)
//
// Une directive `part` est une STRUCTURE Dart : `package:analyzer` (`parseString`
// + `PartDirective`) la reconnaît quelles que soient l'indentation, les retours à
// la ligne, les commentaires. Un grep `part '` aurait ici compté 2 faux positifs
// RÉELS (`packages/zcrud_generator/lib/builder.dart` et
// `.../src/zcrud_model_generator.dart` mentionnent `part '<file>.g.dart'` en
// DARTDOC) — un gate qui accuse un package sans codegen est un gate qu'on
// contourne. Un fichier Dart NON PARSABLE est un **ÉCHEC**, jamais un skip.
//
// ## Pourquoi `git check-ignore` (et pas une relecture de `.gitignore`)
//
// L'autorité de l'ignorabilité, c'est git : `.gitignore` racine + `.gitignore`
// imbriqués + `.git/info/exclude` + `core.excludesFile`, avec les règles de
// précédence de git. Réimplémenter ça = réintroduire le faux vert. On interroge
// donc `git check-ignore --no-index` (mode RÈGLES : indépendant du fait que le
// codegen ait tourné ou que le fichier ait déjà été `git add`é).
//
// Usage : dart run scripts/ci/gate_codegen_distribution.dart [--root <dir>]
//   `--root` (convention maison) : racine alternative de scan, pour les fixtures
//   de `prove_gates.dart`. DOIT rester DANS le dépôt git (l'autorité `git
//   check-ignore` s'évalue depuis la racine du dépôt).
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Suffixes de code GÉNÉRÉ (sorties de build_runner) — jamais scannés comme
/// sources (ils ne portent que des `part of`), et cités dans le message d'aide.
const List<String> kGeneratedSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
];

bool _isGenerated(String path) =>
    kGeneratedSuffixes.any((String s) => path.endsWith(s));

/// Une directive `part` : le fichier qui l'écrit → le fichier qu'elle inclut.
class _PartRef {
  _PartRef(this.pkg, this.source, this.target);

  /// Nom du répertoire du package (ex. `zcrud_study_kernel`).
  final String pkg;

  /// Chemin (relatif au cwd) du fichier portant la directive.
  final String source;

  /// Chemin (relatif au cwd) du fichier inclus par la directive.
  final String target;
}

int _errors = 0;

void _fail(String message) {
  _errors++;
  stderr.writeln('[gate:codegen-distribution] ÉCHEC : $message');
}

String _norm(String p) => p.replaceAll('\\', '/');

/// Résout l'URI d'un `part` relativement au fichier source (sans `package:path`,
/// non déclaré à la racine) : `Uri.file` conserve les chemins relatifs.
String _resolvePart(String sourcePath, String uri) =>
    _norm(Uri.file(_norm(sourcePath)).resolve(uri).toFilePath());

/// Collecte toutes les directives `part` du `lib/` de [pkgDir] (AST).
List<_PartRef> _collectParts(Directory pkgDir) {
  final refs = <_PartRef>[];
  final lib = Directory('${pkgDir.path}/lib');
  if (!lib.existsSync()) return refs;
  final pkg = _norm(pkgDir.path).split('/').last;

  final files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((File f) => _norm(f.path))
      .where((String p) => p.endsWith('.dart') && !_isGenerated(p))
      .toList()
    ..sort();

  for (final path in files) {
    final CompilationUnit unit;
    try {
      unit = parseString(content: File(path).readAsStringSync()).unit;
    } on ArgumentError catch (e) {
      // Non parsable => ÉCHEC (jamais un skip) : un gate qui n'arrive pas à lire
      // un fichier ne peut RIEN affirmer sur les `part` qu'il contient.
      _fail(
        'fichier Dart NON PARSABLE ($path) — le gate refuse de scanner à '
        "l'aveugle (une directive `part` gitignorée pourrait s'y cacher) : "
        '${e.toString().split('\n').take(3).join(' ')}',
      );
      continue;
    }
    for (final directive in unit.directives) {
      if (directive is! PartDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri == null) {
        _fail('directive `part` à URI non littérale dans $path — non analysable.');
        continue;
      }
      if (Uri.parse(uri).hasScheme) {
        // `part 'package:…'` : non mappable sur un chemin du dépôt => on refuse
        // de conclure (fail-closed) plutôt que de laisser passer en silence.
        _fail('directive `part` à URI non relative ($uri) dans $path — non supportée.');
        continue;
      }
      refs.add(_PartRef(pkg, path, _resolvePart(path, uri)));
    }
  }
  return refs;
}

/// Chemins de [paths] que **git IGNORE** (autorité : `git check-ignore`).
///
/// `--no-index` = mode RÈGLES pur : le verdict ne dépend PAS du fait que le
/// fichier existe déjà dans l'index (un `git add -f` ponctuel ne doit pas
/// masquer une règle `.gitignore` fautive) ni du fait que le codegen ait tourné.
Set<String> _ignoredPaths(List<String> paths) {
  final ignored = <String>{};
  const chunk = 200; // marge confortable sous la limite d'arguments.
  for (var i = 0; i < paths.length; i += chunk) {
    final slice = paths.sublist(i, i + chunk > paths.length ? paths.length : i + chunk);
    final r = Process.runSync(
      'git',
      <String>['check-ignore', '--no-index', '--', ...slice],
    );
    // 0 = au moins un chemin ignoré (listés sur stdout) ; 1 = aucun ; >1 = erreur.
    if (r.exitCode > 1) {
      stderr.writeln(
        '[gate:codegen-distribution] ÉCHEC : `git check-ignore` a échoué '
        '(exit=${r.exitCode}) — le gate ne peut pas conclure : ${r.stderr}',
      );
      exit(2);
    }
    for (final line in (r.stdout as String).split('\n')) {
      final p = line.trim();
      if (p.isNotEmpty) ignored.add(_norm(p));
    }
  }
  return ignored;
}

/// Chemins de [paths] présents sur disque mais NON suivis par git (info).
Set<String> _untracked(List<String> paths) {
  final onDisk = paths.where((String p) => File(p).existsSync()).toList();
  if (onDisk.isEmpty) return <String>{};
  final r = Process.runSync('git', <String>['ls-files', '--', ...onDisk]);
  if (r.exitCode != 0) return <String>{};
  final tracked = (r.stdout as String)
      .split('\n')
      .map((String l) => l.trim())
      .where((String l) => l.isNotEmpty)
      .toSet();
  return onDisk.where((String p) => !tracked.contains(p)).toSet();
}

/// Négation `.gitignore` à ajouter pour dé-ignorer [target] du package [pkg].
String _suggestion(String pkg, String target) {
  final name = target.split('/').last;
  final dot = name.indexOf('.');
  final suffix = dot >= 0 ? name.substring(dot) : '.dart';
  final glob = kGeneratedSuffixes.contains(suffix) ? '*$suffix' : name;
  return '!packages/$pkg/lib/**/$glob';
}

void main(List<String> args) {
  var root = 'packages';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) root = args[i + 1];
  }

  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('[gate:codegen-distribution] ÉCHEC : dossier introuvable: $root');
    exit(2);
  }

  // (1) Découverte DYNAMIQUE des packages : tout enfant immédiat de `root`
  //     portant un `lib/`. JAMAIS de liste en dur (les packages d'ES-2 seront
  //     couverts à leur création, sans toucher à ce fichier).
  final pkgDirs = dir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .where((Directory d) => Directory('${d.path}/lib').existsSync())
      .toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));

  // (2) Directives `part` par AST.
  final refs = <_PartRef>[];
  for (final p in pkgDirs) {
    refs.addAll(_collectParts(p));
  }
  if (_errors > 0) {
    stderr.writeln(
      '[gate:codegen-distribution] $_errors fichier(s)/directive(s) non analysable(s) — ROUGE.',
    );
    exit(2);
  }

  if (refs.isEmpty) {
    stdout.writeln(
      'gate:codegen-distribution OK — ${pkgDirs.length} package(s) scanné(s), '
      "aucune directive `part` dans un `lib/` (rien à distribuer).",
    );
    exit(0);
  }

  // (3) Verdict d'ignorabilité — autorité git.
  final targets = refs.map((_PartRef r) => r.target).toSet().toList()..sort();
  final ignored = _ignoredPaths(targets);

  final violations = refs.where((_PartRef r) => ignored.contains(r.target)).toList();
  final pkgsWithParts = refs.map((_PartRef r) => r.pkg).toSet().toList()..sort();

  if (violations.isNotEmpty) {
    stderr.writeln(
      'gate:codegen-distribution VIOLATION — code inclus par `part` mais GITIGNORÉ, '
      'dans un package distribué en dépendance git :',
    );
    final byPkg = <String, List<_PartRef>>{};
    for (final v in violations) {
      byPkg.putIfAbsent(v.pkg, () => <_PartRef>[]).add(v);
    }
    for (final entry in byPkg.entries) {
      stderr.writeln('  package `${entry.key}` :');
      for (final v in entry.value) {
        stderr.writeln('    - ${v.target}  (inclus par `part` depuis ${v.source})');
      }
      stderr.writeln(
        '    => CORRECTIF : ajoutez `${_suggestion(entry.key, entry.value.first.target)}` '
        'à .gitignore — sinon un consommateur en dépendance git obtiendra un package '
        'SANS son code généré (il clone l\'arbre au tag et ne régénère PAS le code '
        'd\'une dépendance) => ÉCHEC DE COMPILATION CHEZ LUI.',
      );
    }
    exit(1);
  }

  // (4) Information non bloquante : généré présent mais pas encore `git add`é.
  //     Non fatal (une story en cours n'a pas encore committé), mais visible :
  //     le fichier DOIT partir dans le commit, sinon le consommateur ne l'aura pas.
  final untracked = _untracked(targets);
  if (untracked.isNotEmpty) {
    stdout.writeln(
      'gate:codegen-distribution NOTE — ${untracked.length} fichier(s) inclus par '
      '`part`, non gitignoré(s) mais PAS ENCORE suivi(s) par git : à committer '
      '(`git add`) — un consommateur en dépendance git ne verra que ce qui est committé.',
    );
    for (final u in (untracked.toList()..sort())) {
      stdout.writeln('    - $u');
    }
  }

  stdout.writeln(
    'gate:codegen-distribution OK — ${pkgDirs.length} package(s) scanné(s), '
    '${pkgsWithParts.length} avec directives `part` (${pkgsWithParts.join(", ")}), '
    '${targets.length} fichier(s) inclus, 0 gitignoré.',
  );
  exit(0);
}
