// Primitives PARTAGÉES des gardes qui LISENT LES SOURCES sous
// `packages/*/lib` (patron `zcrud_chat_kernel/test/support/z_repo_sources.dart`
// et `zcrud_chat/test/support/z_chat_sources.dart` — cette source unique évite
// deux définitions divergentes de « source du package », dépouillée ou non.
//
// R3INJ-P0A : marqueur d'injection de la campagne P0A (zcrud_study /
// zcrud_study_kernel). N'apparaît jamais hors des injections temporaires de
// preuve, restaurées par copie immédiatement après mesure.
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')` + `library;` — sinon le gate `web-determinism` rend toute la
// suite non compilable en JS.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du package `zcrud_study`, que le test tourne depuis
/// `packages/zcrud_study` (`flutter test`) ou depuis la racine du dépôt.
Directory packageRoot() {
  for (final String p in <String>['.', 'packages/zcrud_study']) {
    final Directory d = Directory(p);
    if (File('${d.path}/pubspec.yaml').existsSync() &&
        Directory('${d.path}/lib/src').existsSync()) {
      return d;
    }
  }
  fail('racine de zcrud_study introuvable depuis ${Directory.current.path}');
}

/// Racine du DÉPÔT (ancrage `melos.yaml`), pour les gardes qui lisent la
/// source d'un AUTRE package (ex. `zcrud_core`).
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

/// Tous les `.dart` de `lib/` du package (aucun code généré à exclure : ce
/// package n'en a pas sous `lib/`).
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
List<String> stripped(File f) => strippedLines(f.readAsLinesSync());

/// Variante testable directement sur des lignes déjà en mémoire (contre-preuves).
List<String> strippedLines(List<String> rawLines) {
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

/// [stripped] joint en une seule chaîne (pour les scans `.contains`/`RegExp`
/// sur tout le fichier plutôt que ligne à ligne).
String strippedText(File f) => stripped(f).join('\n');

/// Source dépouillée d'un fichier `.dart`, par chemin RELATIF au package
/// (`lib/src/presentation/...`). Échoue bruyamment si absent.
String strippedOf(String relativePath) {
  final File file = File('${packageRoot().path}/$relativePath');
  expect(file.existsSync(), isTrue,
      reason: 'introuvable: $relativePath (cwd=${Directory.current.path}) — '
          'lancer `flutter test` DEPUIS le package `zcrud_study`');
  return strippedText(file);
}

/// Source dépouillée d'un fichier `.dart` d'un AUTRE package, par chemin
/// relatif à la racine du dépôt (`packages/<pkg>/lib/...`).
String strippedCrossPackage(String repoRelativePath) {
  final File file = File('${repoRoot().path}/$repoRelativePath');
  expect(file.existsSync(), isTrue,
      reason: 'introuvable: $repoRelativePath depuis ${repoRoot().path}');
  return strippedText(file);
}
