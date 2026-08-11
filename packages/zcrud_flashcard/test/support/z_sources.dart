// Primitives PARTAGÉES des gardes qui LISENT LES SOURCES de `zcrud_flashcard`.
//
// 🔴 Source UNIQUE (patron `zcrud_chat_kernel/test/support/z_repo_sources.dart` /
// `zcrud_chat/test/support/z_chat_sources.dart`) : recopier `stripped` /
// `libDartFiles` dans chaque garde créerait des définitions divergentes de
// « source du package » — la classe de défaut que zcrud combat partout ailleurs.
//
// Motif d'existence (chantier documentation, 2026-08-11) : des dartdoc vont
// être insérées massivement dans `packages/*/lib`, citant légitimement des
// motifs interdits (`TextAlign.left`, `Colors.red`, URLs, noms de libs). Toute
// garde qui scanne la source DOIT donc lire le code STRIPPÉ de ses
// commentaires — sans devenir aveugle aux violations dans le CODE.
//
// ⚠️ `dart:io` : ce fichier n'est PAS un `*_test.dart`, le runner ne l'exécute
// jamais seul. Les tests qui l'importent tournent sous `flutter test` (VM).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du package `zcrud_flashcard`, que le test tourne depuis
/// `packages/zcrud_flashcard` (`flutter test`, convention `melos exec`) ou depuis la
/// racine du dépôt (CI).
Directory packageRoot() {
  for (final String p in <String>['.', 'packages/zcrud_flashcard']) {
    final Directory d = Directory(p);
    if (File('${d.path}/pubspec.yaml').existsSync() &&
        Directory('${d.path}/lib/src').existsSync()) {
      return d;
    }
  }
  fail('racine de zcrud_flashcard introuvable depuis ${Directory.current.path}');
}

/// Racine du dépôt (remontée jusqu'au `melos.yaml` — jamais un `../` relatif).
Directory repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Tous les `.dart` de `lib/` du package (hors code généré), avec garde
/// anti-vacuité : un balayage vide signale un chemin cassé, jamais un paquet
/// propre.
List<File> libDartFiles() {
  final Directory lib = Directory('${packageRoot().path}/lib');
  expect(lib.existsSync(), isTrue, reason: 'lib/ introuvable');
  final List<File> files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

/// Un fichier de `lib/`, par suffixe de chemin (unique, sinon échec).
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
/// garde en aval silencieusement VACUELLE. Les littéraux de chaîne sont sautés
/// pour la même raison (une URL contient `//`).
List<String> strippedLines(File f) => stripLines(f.readAsLinesSync());

/// Source ENTIÈRE dé-commentée (lignes préservées, jointes par `\n`).
String strippedSource(File f) => strippedLines(f).join('\n');

/// [strippedLines] sur des lignes déjà en mémoire (contre-preuves des gardes).
List<String> stripLines(List<String> rawLines) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String raw in rawLines) {
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
