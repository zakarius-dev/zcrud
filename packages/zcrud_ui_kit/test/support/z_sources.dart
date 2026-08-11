/// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet (P0D2).
///
/// [stripComments] retire les commentaires de ligne (`//`, `///`) ET de bloc
/// (`/* … */`) par un balayage caractère par caractère — `//` reconnu AVANT
/// `/*`, littéraux de chaîne préservés tels quels. Une regex bloc appliquée en
/// un seul passage sur le fichier entier serait piégée par une citation de
/// chemin du type `packages/*/lib` (présente telle quelle dans CLAUDE.md, donc
/// probable dans le dartdoc à venir) : le `/*` y ouvrirait un faux commentaire
/// que la regex referme sur le PROCHAIN `*/` du fichier, avalant tout le code
/// entre les deux et rendant la garde silencieusement vacuelle.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du paquet `zcrud_ui_kit`, quel que soit le cwd.
Directory packageRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    final File pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zcrud_ui_kit')) {
      return dir;
    }
    final Directory candidate = Directory('${dir.path}/packages/zcrud_ui_kit');
    if (candidate.existsSync()) return candidate;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('racine de zcrud_ui_kit introuvable depuis ${Directory.current.path}');
}

/// Lit un fichier package-relatif, cwd-robuste.
String readPackageFile(String relative) {
  for (final String base in <String>[
    packageRoot().path,
    '.',
    'packages/zcrud_ui_kit',
  ]) {
    final File f = File('$base/$relative');
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $relative');
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
