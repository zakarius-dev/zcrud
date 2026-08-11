// Gate DOC-1 — « le rédacteur n'a pas touché au CODE ».
//
// Chantier documentation (2026-08-11) : des agents rédacteurs insèrent du
// dartdoc dans `packages/*/lib`. Ce gate prouve mécaniquement qu'un lot de
// rédaction n'a modifié QUE des commentaires et des fichiers documentaires :
//
//   1. tout `.dart` MODIFIÉ sous `packages/*/lib/` est comparé à sa version
//      de base (HEAD par défaut) APRÈS retrait des commentaires et des lignes
//      vides — la moindre différence de code = ÉCHEC (fichier + ligne) ;
//   2. tout `.dart` NOUVEAU sous `lib/`, ou tout `.dart` touché HORS `lib/`
//      (tests, scripts, example) = ÉCHEC — un lot doc n'écrit pas de code ;
//   3. les fichiers non-Dart ne sont admis que sur liste blanche documentaire
//      (README.md, CHANGELOG.md, doc/, docs/, dartdoc_options.yaml,
//      analysis_options.yaml) ; `pubspec.lock` est ignoré.
//
// La passe de strip réplique `strippedLines` de
// `packages/zcrud_chat_kernel/test/support/z_repo_sources.dart` : ligne AVANT
// bloc (une dartdoc du dépôt écrit littéralement `packages/*/lib` — une passe
// « bloc d'abord » avalerait la fin du fichier), littéraux de chaîne sautés
// (une URL contient `//`).
//
// Base de comparaison : `HEAD`, ou 1er argument (`dart run
// scripts/ci/doc_only_diff.dart <ref>`), ou variable ZCRUD_DOC_BASE.
//
// Ce gate est VOLONTAIREMENT strict : il ne tourne que sur les lots de
// rédaction (Phase 3 du chantier), jamais sur un lot de code ou un bump.
library;

import 'dart:io';

Future<void> main(List<String> args) async {
  final String base = args.isNotEmpty
      ? args.first
      : (Platform.environment['ZCRUD_DOC_BASE'] ?? 'HEAD');

  final ProcessResult status =
      await Process.run('git', <String>['status', '--porcelain=v1', '-uall']);
  if (status.exitCode != 0) {
    stderr.writeln('❌ git status a échoué : ${status.stderr}');
    exit(2);
  }

  final List<String> violations = <String>[];
  int comparedLibDart = 0;
  int allowedDocFiles = 0;

  for (final String raw in (status.stdout as String).split('\n')) {
    if (raw.trim().isEmpty) continue;
    final String xy = raw.length >= 2 ? raw.substring(0, 2) : raw;
    String path = raw.substring(3).trim();
    // Renommage « R  ancien -> nouveau » : juger les deux extrémités.
    if (path.contains(' -> ')) {
      final List<String> parts = path.split(' -> ');
      violations.add('renommage interdit dans un lot doc : ${parts.join(' -> ')}');
      continue;
    }
    if (path.startsWith('"') && path.endsWith('"')) {
      path = path.substring(1, path.length - 1);
    }
    if (path.endsWith('pubspec.lock')) continue;
    final bool untracked = xy == '??';
    final bool deleted = xy.contains('D');

    if (path.endsWith('.dart')) {
      final bool inPackagesLib =
          RegExp(r'^packages/[^/]+/lib/').hasMatch(path);
      if (!inPackagesLib) {
        violations.add('fichier .dart hors packages/*/lib touché : $path');
        continue;
      }
      if (untracked) {
        violations.add('nouveau fichier .dart sous lib/ : $path');
        continue;
      }
      if (deleted) {
        violations.add('fichier .dart supprimé sous lib/ : $path');
        continue;
      }
      final ProcessResult show =
          await Process.run('git', <String>['show', '$base:$path']);
      if (show.exitCode != 0) {
        violations.add('introuvable dans $base (fichier de code ?) : $path');
        continue;
      }
      final List<String> before = _codeLines(show.stdout as String);
      final List<String> after = _codeLines(File(path).readAsStringSync());
      comparedLibDart++;
      final String? diff = _firstDivergence(before, after);
      if (diff != null) {
        violations.add('CODE modifié (pas seulement des commentaires) : '
            '$path — $diff');
      }
      continue;
    }

    // Non-Dart : liste blanche documentaire.
    final String name = path.split('/').last;
    final bool allowed = name == 'README.md' ||
        name == 'CHANGELOG.md' ||
        name == 'dartdoc_options.yaml' ||
        name == 'analysis_options.yaml' ||
        path.startsWith('docs/') ||
        RegExp(r'^packages/[^/]+/doc/').hasMatch(path);
    if (allowed) {
      allowedDocFiles++;
    } else {
      violations.add('fichier hors liste blanche documentaire : $path');
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('❌ DOC-1 : ${violations.length} violation(s) — le lot ne '
        'se réduit pas à de la documentation :');
    for (final String v in violations) {
      stderr.writeln('   • $v');
    }
    exit(1);
  }
  stdout.writeln('✅ DOC-1 : diff documentaire pur vs $base '
      '($comparedLibDart .dart de lib comparés strippés, '
      '$allowedDocFiles fichier(s) documentaire(s)).');
}

/// Lignes de CODE d'une source : commentaires retirés (ligne avant bloc,
/// chaînes sautées), puis lignes vides éliminées et blancs normalisés — pour
/// que l'insertion de dartdoc n'introduise aucune différence.
List<String> _codeLines(String source) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String rawLine in source.split('\n')) {
    final String raw = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    final StringBuffer buf = StringBuffer();
    int i = 0;
    while (i < raw.length) {
      final String c = raw[i];
      final String next = i + 1 < raw.length ? raw[i + 1] : '';
      if (inBlock) {
        if (c == '*' && next == '/') {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '/') break;
      if (c == '/' && next == '*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') {
        final String quote = c;
        buf.write(c);
        i++;
        while (i < raw.length) {
          if (raw[i] == r'\') {
            buf.write(raw[i]);
            i++;
            if (i < raw.length) {
              buf.write(raw[i]);
              i++;
            }
            continue;
          }
          buf.write(raw[i]);
          final bool end = raw[i] == quote;
          i++;
          if (end) break;
        }
        continue;
      }
      buf.write(c);
      i++;
    }
    final String code = buf.toString().trim();
    if (code.isNotEmpty) out.add(code.replaceAll(RegExp(r'\s+'), ' '));
  }
  return out;
}

String? _firstDivergence(List<String> before, List<String> after) {
  final int n = before.length < after.length ? before.length : after.length;
  for (int i = 0; i < n; i++) {
    if (before[i] != after[i]) {
      return '1re divergence de code (séquence #${i + 1}) : '
          '« ${before[i]} » → « ${after[i]} »';
    }
  }
  if (before.length != after.length) {
    return 'nombre de lignes de code : ${before.length} → ${after.length}';
  }
  return null;
}
