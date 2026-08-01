// Primitives PARTAGÉES des gardes qui LISENT LES SOURCES de `zcrud_chat`.
//
// 🔴 Source UNIQUE (patron `zcrud_chat_kernel/test/support/z_repo_sources.dart`) :
// recopier `stripped`/`libDartFiles` dans chaque garde créerait deux
// définitions divergentes de « source du package ».
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du package, que le test tourne depuis `packages/zcrud_chat`
/// (`flutter test`) ou depuis la racine du dépôt (CI).
Directory packageRoot() {
  for (final String p in <String>['.', 'packages/zcrud_chat']) {
    final Directory d = Directory(p);
    if (File('${d.path}/pubspec.yaml').existsSync() &&
        Directory('${d.path}/lib/src').existsSync()) {
      return d;
    }
  }
  fail('racine de zcrud_chat introuvable depuis ${Directory.current.path}');
}

/// Tous les `.dart` de `lib/` (aucun code généré : ce package n'en a pas).
List<File> libDartFiles() {
  final Directory lib = Directory('${packageRoot().path}/lib');
  expect(lib.existsSync(), isTrue, reason: 'lib/ introuvable');
  final List<File> files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

/// Un fichier de `lib/`, par suffixe de chemin.
File libFile(String suffix) {
  final List<File> hits = libDartFiles()
      .where((File f) => f.path.replaceAll(r'\', '/').endsWith(suffix))
      .toList();
  expect(hits, hasLength(1), reason: 'fichier introuvable ou ambigu : $suffix');
  return hits.single;
}

/// Retire les commentaires de LIGNE **et** de BLOC en préservant le nombre de
/// lignes (les numéros signalés restent exacts) et en sautant les littéraux de
/// chaîne.
///
/// 🔴 L'ordre compte : `//` est reconnu AVANT `/*`. Une dartdoc de ce dépôt
/// écrit littéralement `packages/*/lib` — une passe « bloc d'abord » y verrait
/// une ouverture jamais refermée et AVALERAIT LA FIN DU FICHIER, rendant toute
/// garde en aval silencieusement VACUELLE.
List<String> stripped(File f) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String raw in f.readAsLinesSync()) {
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
    out.add(buf.toString());
  }
  return out;
}

/// Lignes de `lib/` **dé-commentées**, indexées par chemin.
Map<String, List<String>> strippedLib() => <String, List<String>>{
  for (final File f in libDartFiles()) f.path: stripped(f),
};
