// Construit le site Docusaurus (`website/`) : relaie `npm run build` tel
// quel, sans jamais construire le site « à la main ». Le script se contente
// de vérifier les préalables et de faire suivre le code de retour — la
// substance de la build appartient entièrement à Docusaurus/npm.
//
// Usage :
//   dart run scripts/doc/build_site.dart
//
// Appelé par `melos run doc:site`, qui régénère d'abord la référence d'API
// (`melos run doc:api`) avant d'invoquer ce script — ce script n'appelle PAS
// `doc:api` lui-même, il suppose `website/static/api/` déjà à jour.
//
// Préalables vérifiés AVANT de lancer `npm run build` :
//   (a) `website/` existe (site scaffoldé) ;
//   (b) `website/node_modules` existe (dépendances npm installées).
// Un préalable manquant produit un message clair et un RC=1, sans tenter la
// build.
import 'dart:io';

void _info(String message) => stdout.writeln('[doc:site] $message');

/// Racine du dépôt, demandée directement à git (fiable quel que soit le cwd
/// d'invocation — `melos run doc:site` comme un lancement manuel).
Directory _repoRoot() {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    stderr.writeln(
      '[doc:site] ÉCHEC — impossible de localiser la racine du dépôt git : '
      '${(result.stderr as String).trim()}',
    );
    exit(2);
  }
  return Directory((result.stdout as String).trim());
}

Future<void> main(List<String> args) async {
  final repoRoot = _repoRoot();
  final websiteDir = Directory('${repoRoot.path}/website');

  if (!websiteDir.existsSync()) {
    stderr.writeln(
      '[doc:site] ÉCHEC — website/ est introuvable : le site Docusaurus n\'est pas encore scaffoldé.',
    );
    exit(1);
  }

  final nodeModules = Directory('${websiteDir.path}/node_modules');
  if (!nodeModules.existsSync()) {
    stderr.writeln(
      '[doc:site] ÉCHEC — website/node_modules est introuvable. '
      'Lancez `npm install` depuis website/ avant `melos run doc:site`.',
    );
    exit(1);
  }

  _info('construction du site (npm run build, dans ${websiteDir.path})…');

  final process = await Process.start(
    'npm',
    ['run', 'build'],
    workingDirectory: websiteDir.path,
    runInShell: true,
  );

  final stdoutDone = process.stdout.transform(const SystemEncoding().decoder).listen(stdout.write).asFuture<void>();
  final stderrDone = process.stderr.transform(const SystemEncoding().decoder).listen(stderr.write).asFuture<void>();

  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);

  if (exitCode == 0) {
    _info('build terminée avec succès (RC=0).');
  } else {
    stderr.writeln('[doc:site] ÉCHEC — `npm run build` a rendu RC=$exitCode.');
  }
  exit(exitCode);
}
