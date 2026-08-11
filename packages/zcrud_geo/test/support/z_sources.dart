/// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet (P0D2).
///
/// 🔴 Motivation : `isolation_gates_test.dart` scannait `lib/` en TEXTE BRUT —
/// aucun retrait de commentaire — pour l'audit RTL (AD-13), les secrets et le
/// confinement Google. Un dartdoc citant légitimement `TextAlign.left` pour
/// EXPLIQUER pourquoi il est interdit (exactement le style de documentation du
/// chantier à venir) faisait alors rougir la garde sur sa propre prose.
///
/// [stripComments] retire les commentaires de ligne (`//`, `///`) ET de bloc
/// (`/* … */`) par un balayage caractère par caractère — `//` reconnu AVANT
/// `/*`, littéraux de chaîne préservés. Une regex bloc appliquée en un seul
/// passage serait piégée par une citation littérale de `packages/*/lib` (le
/// `/*` y ouvrirait un faux commentaire refermé sur le PROCHAIN `*/` du
/// fichier, avalant tout le code entre les deux).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du paquet `zcrud_geo`, quel que soit le cwd.
Directory packageRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    final File pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zcrud_geo')) {
      return dir;
    }
    final Directory candidate = Directory('${dir.path}/packages/zcrud_geo');
    if (candidate.existsSync()) return candidate;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('racine de zcrud_geo introuvable depuis ${Directory.current.path}');
}

/// `lib/` du paquet, cwd-robuste.
Directory libDir() => Directory('${packageRoot().path}/lib');

/// Tous les `.dart` de `lib/` (hors code généré), vacuité vérifiée.
List<File> libDartFiles() {
  final Directory dir = libDir();
  expect(dir.existsSync(), isTrue,
      reason: 'lib/ de zcrud_geo introuvable — la garde serait VACUELLE');
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();
  expect(files.length, greaterThanOrEqualTo(5),
      reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) scanné(s) sous '
          'zcrud_geo/lib.');
  return files;
}

/// Lit un fichier repo-relatif, cwd-robuste (racine du repo ou du paquet).
String readRepoFile(String repoPath) {
  const String prefix = 'packages/zcrud_geo/';
  for (final String c in <String>[
    repoPath,
    '../../$repoPath',
    if (repoPath.startsWith(prefix)) repoPath.substring(prefix.length),
  ]) {
    final File f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $repoPath');
}

/// Retire commentaires de ligne et de bloc d'une source Dart, littéraux de
/// chaîne préservés. Voir la dartdoc de tête pour le piège évité.
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
