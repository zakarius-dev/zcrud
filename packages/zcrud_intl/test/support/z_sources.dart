/// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet (P0D2).
///
/// 🔴 Motivation : plusieurs gardes de `zcrud_intl` retiraient les commentaires
/// via une regex bloc `RegExp(r'/\*[\s\S]*?\*/')` appliquée AVANT le retrait des
/// commentaires de ligne, et SANS tenir compte des littéraux de chaîne. Cette
/// forme est piégée par un texte de dartdoc parfaitement légitime qui contient
/// littéralement `packages/*/lib` (présent tel quel dans CLAUDE.md et donc
/// probable dans la documentation à venir) : `/*` y ouvre un faux commentaire de
/// bloc que la regex referme sur le PROCHAIN `*/` du fichier — potentiellement
/// des dizaines de lignes plus loin — et tout le CODE entre les deux disparaît
/// silencieusement du texte analysé. La garde devient alors aveugle aux
/// violations qu'elle est censée détecter, sans jamais rougir pour le signaler.
///
/// [stripComments] remplace ces implémentations : balayage caractère par
/// caractère, `//` reconnu AVANT `/*` (un commentaire de ligne ne peut pas
/// ouvrir un faux bloc), et les littéraux de chaîne sont recopiés tels quels
/// (un `//` dans une URL n'est pas un commentaire).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du paquet `zcrud_intl`, quel que soit le cwd (racine du workspace
/// via `melos exec`, ou racine du paquet via `cd packages/zcrud_intl`).
Directory packageRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    final File pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zcrud_intl')) {
      return dir;
    }
    final Directory candidate = Directory('${dir.path}/packages/zcrud_intl');
    if (candidate.existsSync()) return candidate;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('racine de zcrud_intl introuvable depuis ${Directory.current.path}');
}

/// Tous les `.dart` de `lib/` (hors code généré), avec vacuité vérifiée.
List<File> libDartFiles() {
  final Directory dir = Directory('${packageRoot().path}/lib');
  expect(dir.existsSync(), isTrue,
      reason: 'lib/ de zcrud_intl introuvable — la garde serait VACUELLE');
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();
  expect(files.length, greaterThanOrEqualTo(10),
      reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) scanné(s) sous '
          'zcrud_intl/lib — un balayage quasi vide signale un chemin cassé.');
  return files;
}

/// Lit un fichier repo-relatif ou package-relatif, cwd-robuste.
String readRepoFile(String repoPath) {
  const String prefix = 'packages/zcrud_intl/';
  final List<String> candidates = <String>[
    repoPath,
    '${packageRoot().path}/${repoPath.startsWith(prefix) ? repoPath.substring(prefix.length) : repoPath}',
    if (repoPath.startsWith(prefix)) repoPath.substring(prefix.length),
  ];
  for (final String c in candidates) {
    final File f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $repoPath');
}

/// Retire commentaires de ligne (`//`, `///`) et de bloc (`/* */`) d'une
/// source Dart, en respectant les littéraux de chaîne.
///
/// 🔴 L'ordre compte : `//` est reconnu AVANT `/*` caractère par caractère —
/// jamais par une regex bloc appliquée sur le fichier entier (cf. dartdoc de
/// tête : un `/*` accidentel dans une citation de chemin avalerait tout le
/// code jusqu'au prochain `*/`, rendant la garde silencieusement vacuelle).
String stripComments(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < src.length) {
    final String c = src[i];
    final String next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= src.length ? i + 2 : src.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final String quote = c;
      out.write(c);
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          out.write(src.substring(i, i + 2 <= src.length ? i + 2 : i + 1));
          i += 2;
          continue;
        }
        out.write(src[i]);
        if (src[i] == quote || src[i] == '\n') {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Source d'un fichier `lib/`, commentaires retirés.
String strippedSource(File f) => stripComments(f.readAsStringSync());

/// Source repo/package-relative, commentaires retirés.
String strippedRepoFile(String repoPath) => stripComments(readRepoFile(repoPath));
