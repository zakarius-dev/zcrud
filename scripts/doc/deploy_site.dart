// Publie `website/build` (site Docusaurus déjà construit par `melos run
// doc:site`) sur la branche `gh-pages`, DEPUIS LE POSTE — aucun GitHub
// Actions requis (la CI du dépôt est à l'arrêt pour facturation, cf.
// CLAUDE.md). Le contenu de `gh-pages` est géré via un `git worktree` DÉDIÉ,
// jamais l'arbre de travail principal : celui-ci porte en permanence du
// travail non commité et ne doit JAMAIS subir de `git checkout`/`git stash`
// (règle absolue du dépôt).
//
// Usage :
//   dart run scripts/doc/deploy_site.dart [--dry-run]
//
//   --dry-run : exécute tout le pipeline (worktree, copie, commit) mais NE
//   POUSSE PAS sur `origin/gh-pages`. Utile pour vérifier ce qui serait
//   publié avant de le décider réellement (la publication reste une décision
//   humaine, jamais automatique).
//
// Sûreté (chacune obligatoire) :
//   (a) refuse si l'arbre de travail principal est sale, HORS `pubspec.lock`
//       racine (les autres fichiers verrouillés — pubspec.yaml, melos.yaml,
//       .gitignore… — doivent être commités ou annulés avant de publier) ;
//   (b) refuse si `website/build` est absent ou vide (message : lancer
//       `melos run doc:site`) ;
//   (c) worktree `gh-pages` dédié, créé ORPHELIN si la branche n'existe
//       encore ni en local ni sur `origin` (première publication) ;
//   (d) le worktree est TOUJOURS nettoyé en fin d'exécution, y compris en
//       cas d'échec — implémenté par capture explicite des erreurs (jamais un
//       `exit()` direct pendant que le worktree existe : `exit()` de dart:io
//       termine l'isolat immédiatement et n'exécute AUCUN bloc `finally`) ;
//   (e) `--dry-run` fait tout sauf le push, et le dit explicitement ;
//   (f) aucun `git checkout` ni `git stash` n'est jamais exécuté avec
//       `workingDirectory` pointant sur la racine du dépôt — uniquement sur
//       le worktree temporaire dédié.
import 'dart:io';

const String _branch = 'gh-pages';
const String _remote = 'origin';

void _info(String message) => stdout.writeln('[doc:deploy] $message');

/// Échec piloté : ne termine JAMAIS le processus directement (voir (d)) — le
/// site d'appel (`main`) décide du nettoyage puis de l'`exit()` final.
class _DeployFailure implements Exception {
  final String message;
  final int code;
  const _DeployFailure(this.message, {this.code = 1});
}

Never _fail(String message, {int code = 1}) => throw _DeployFailure(message, code: code);

ProcessResult _git(List<String> args, {String? workingDirectory}) {
  return Process.runSync('git', args, workingDirectory: workingDirectory);
}

/// Racine du dépôt, demandée directement à git (fiable quel que soit le cwd
/// d'invocation — `melos run doc:deploy` comme un lancement manuel depuis un
/// sous-dossier).
Directory _repoRoot() {
  final result = _git(['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    _fail(
      'impossible de localiser la racine du dépôt git (${(result.stderr as String).trim()}).',
      code: 2,
    );
  }
  return Directory((result.stdout as String).trim());
}

/// (a) Refuse un arbre de travail sale, hors `pubspec.lock` racine.
void _checkCleanWorkingTree(Directory root) {
  final result = _git(['status', '--porcelain'], workingDirectory: root.path);
  if (result.exitCode != 0) {
    _fail('`git status` a échoué : ${(result.stderr as String).trim()}', code: 2);
  }
  final lines = (result.stdout as String)
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  // Format porcelain : 2 caractères de statut + un espace + le chemin.
  final dirty = lines.where((line) {
    final path = line.length > 3 ? line.substring(3) : line;
    return path != 'pubspec.lock';
  }).toList();
  if (dirty.isNotEmpty) {
    _fail(
      'l\'arbre de travail principal est sale (hors pubspec.lock racine) — '
      'committez ou annulez avant de publier :\n'
      '${dirty.map((l) => '  $l').join('\n')}',
    );
  }
}

/// (b) Refuse une build absente ou vide.
Directory _checkBuildDir(Directory root) {
  final buildDir = Directory('${root.path}/website/build');
  if (!buildDir.existsSync()) {
    _fail('website/build est absent — lancez `melos run doc:site` avant `melos run doc:deploy`.');
  }
  if (buildDir.listSync().isEmpty) {
    _fail('website/build est vide — lancez `melos run doc:site` avant `melos run doc:deploy`.');
  }
  return buildDir;
}

bool _localBranchExists(Directory root, String branch) {
  return _git(
        ['show-ref', '--verify', '--quiet', 'refs/heads/$branch'],
        workingDirectory: root.path,
      ).exitCode ==
      0;
}

bool _remoteBranchExists(Directory root, String remote, String branch) {
  return _git(
        ['ls-remote', '--exit-code', '--heads', remote, branch],
        workingDirectory: root.path,
      ).exitCode ==
      0;
}

/// Copie récursive du contenu de [source] dans [destination] (déjà créé).
void _copyDirectoryContents(Directory source, Directory destination) {
  for (final entity in source.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    final newPath = '${destination.path}/$name';
    if (entity is Directory) {
      Directory(newPath).createSync(recursive: true);
      _copyDirectoryContents(entity, Directory(newPath));
    } else if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Link) {
      // Symlink rare dans une build statique — on copie la cible résolue
      // plutôt que de recréer un lien (portabilité gh-pages).
      final target = entity.resolveSymbolicLinksSync();
      final targetStat = FileSystemEntity.typeSync(target);
      if (targetStat == FileSystemEntityType.file) File(target).copySync(newPath);
    }
  }
}

/// Vide le worktree (hors `.git`) avant d'y recopier `website/build`.
void _clearWorktreeContent(Directory worktreeDir) {
  for (final entity in worktreeDir.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name == '.git') continue;
    if (entity is Directory) {
      entity.deleteSync(recursive: true);
    } else {
      entity.deleteSync();
    }
  }
}

/// (d) Nettoyage systématique du worktree temporaire — appelé explicitement
/// depuis `main` sur CHAQUE chemin de sortie (succès, échec piloté, échec
/// inattendu), jamais depuis un `finally` implicite après un `exit()`.
void _cleanupWorktree(Directory? root, Directory? worktreeDir) {
  if (worktreeDir == null) return;
  _info('nettoyage du worktree temporaire ${worktreeDir.path}…');
  if (root != null) {
    final remove = _git(
      ['worktree', 'remove', '--force', worktreeDir.path],
      workingDirectory: root.path,
    );
    if (remove.exitCode != 0) {
      _info(
        'git worktree remove : ${(remove.stderr as String).trim()} '
        '(repli : suppression manuelle du dossier)',
      );
    }
  }
  if (worktreeDir.existsSync()) {
    try {
      worktreeDir.deleteSync(recursive: true);
    } catch (e) {
      _info('suppression manuelle du worktree : $e');
    }
  }
  if (root != null) {
    _git(['worktree', 'prune'], workingDirectory: root.path);
  }
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  Directory? root;
  Directory? worktreeDir;

  try {
    root = _repoRoot();
    _info('racine du dépôt : ${root.path}');

    _checkCleanWorkingTree(root);
    _info('arbre de travail principal propre (hors pubspec.lock).');

    final buildDir = _checkBuildDir(root);
    _info('website/build trouvé et non vide.');

    final shaResult = _git(['rev-parse', 'HEAD'], workingDirectory: root.path);
    if (shaResult.exitCode != 0) {
      _fail('impossible de lire le SHA courant : ${(shaResult.stderr as String).trim()}', code: 2);
    }
    final sha = (shaResult.stdout as String).trim();

    final localBranch = _localBranchExists(root, _branch);
    final remoteBranch = !localBranch && _remoteBranchExists(root, _remote, _branch);
    final branchExists = localBranch || remoteBranch;

    worktreeDir = Directory.systemTemp.createTempSync('zcrud-gh-pages-');
    _info(
      'worktree temporaire : ${worktreeDir.path} '
      '(branche $_branch ${branchExists ? "existante" : "absente — création ORPHELINE"}).',
    );

    // (c) Worktree dédié — jamais de checkout/stash sur `root` (règle (f)).
    if (branchExists) {
      if (remoteBranch) {
        final fetch = _git(
          ['fetch', _remote, '$_branch:$_branch'],
          workingDirectory: root.path,
        );
        if (fetch.exitCode != 0) {
          _fail('`git fetch $_remote $_branch` a échoué : ${(fetch.stderr as String).trim()}', code: 2);
        }
      }
      final add = _git(
        ['worktree', 'add', worktreeDir.path, _branch],
        workingDirectory: root.path,
      );
      if (add.exitCode != 0) {
        _fail('`git worktree add` a échoué : ${(add.stderr as String).trim()}', code: 2);
      }
    } else {
      // Branche orpheline : on ouvre un worktree DÉTACHÉ (pas de checkout sur
      // `root`), puis on bascule ce worktree — lui seul — sur une branche
      // orpheline, et on en vide le contenu hérité.
      final add = _git(
        ['worktree', 'add', '--detach', worktreeDir.path, 'HEAD'],
        workingDirectory: root.path,
      );
      if (add.exitCode != 0) {
        _fail('`git worktree add --detach` a échoué : ${(add.stderr as String).trim()}', code: 2);
      }
      final orphan = _git(['checkout', '--orphan', _branch], workingDirectory: worktreeDir.path);
      if (orphan.exitCode != 0) {
        _fail('`git checkout --orphan` (worktree) a échoué : ${(orphan.stderr as String).trim()}', code: 2);
      }
      // `checkout --orphan` conserve le contenu hérité de HEAD en index —
      // on le retire pour partir d'un historique réellement vide.
      _git(['rm', '-rf', '--quiet', '.'], workingDirectory: worktreeDir.path);
    }

    _clearWorktreeContent(worktreeDir);
    _copyDirectoryContents(buildDir, worktreeDir);

    // Obligatoire pour GitHub Pages : sans ce fichier, Jekyll (activé par
    // défaut côté Pages) ignore silencieusement tout dossier préfixé `_`
    // (ex. Docusaurus émet `_next`-like assets sous certains presets).
    File('${worktreeDir.path}/.nojekyll').writeAsStringSync('');

    final addAll = _git(['add', '-A'], workingDirectory: worktreeDir.path);
    if (addAll.exitCode != 0) {
      _fail('`git add -A` (worktree) a échoué : ${(addAll.stderr as String).trim()}', code: 2);
    }

    final diffCheck = _git(['diff', '--cached', '--quiet'], workingDirectory: worktreeDir.path);
    if (diffCheck.exitCode == 0) {
      _info('aucun changement à publier — le contenu est identique à $_branch actuel.');
    } else {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final shortSha = sha.length > 12 ? sha.substring(0, 12) : sha;
      final message = 'Publication du site ($timestamp UTC) depuis $shortSha';
      final commit = _git(['commit', '-m', message], workingDirectory: worktreeDir.path);
      if (commit.exitCode != 0) {
        _fail('`git commit` (worktree) a échoué : ${(commit.stderr as String).trim()}', code: 2);
      }
      _info('commit créé sur $_branch : "$message".');

      if (dryRun) {
        _info('--dry-run : push VOLONTAIREMENT SAUTÉ — rien n\'a été publié sur $_remote/$_branch.');
      } else {
        final push = _git(
          ['push', _remote, 'HEAD:refs/heads/$_branch'],
          workingDirectory: worktreeDir.path,
        );
        if (push.exitCode != 0) {
          _fail('`git push` a échoué : ${(push.stderr as String).trim()}', code: 2);
        }
        _info('publié sur $_remote/$_branch.');
      }
    }

    _cleanupWorktree(root, worktreeDir);
    _info('terminé.');
  } on _DeployFailure catch (e) {
    stderr.writeln('[doc:deploy] ÉCHEC : ${e.message}');
    _cleanupWorktree(root, worktreeDir);
    exit(e.code);
  } catch (e, st) {
    stderr.writeln('[doc:deploy] ÉCHEC INATTENDU : $e\n$st');
    _cleanupWorktree(root, worktreeDir);
    exit(2);
  }
}
