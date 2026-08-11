// Primitives PARTAGÉES des gardes qui LISENT LES SOURCES sous
// `packages/zcrud_study_kernel/lib` (patron
// `zcrud_chat_kernel/test/support/z_repo_sources.dart`) — source UNIQUE pour
// éviter deux définitions divergentes de « source du package », dépouillée
// ou non.
//
// R3INJ-P0A : marqueur d'injection de la campagne P0A (zcrud_study /
// zcrud_study_kernel). N'apparaît jamais hors des injections temporaires de
// preuve, restaurées par copie immédiatement après mesure.
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')` + `library;`. Package **pur-Dart** (`package:test`, pas
// `flutter_test`) — patron des tests existants (`apply_order_test.dart`…).
library;

import 'dart:io';

import 'package:test/test.dart';

/// Racine `lib/` du package, quel que soit le CWD (patron `z_kernel_purity_test`).
Directory kernelLibDir() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    final Directory nested =
        Directory('${dir.path}/packages/zcrud_study_kernel/lib');
    if (nested.existsSync()) return nested;
    final Directory direct = Directory('${dir.path}/lib');
    if (direct.existsSync() &&
        File('${dir.path}/lib/zcrud_study_kernel.dart').existsSync()) {
      return direct;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('lib/ de zcrud_study_kernel introuvable depuis ${Directory.current.path}');
}

/// Racine du DÉPÔT (ancrage `melos.yaml`).
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

/// Tous les `.dart` de `lib/` (hors code généré).
List<File> libDartFiles() {
  final Directory dir = kernelLibDir();
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

/// Retire les commentaires de LIGNE **et** de BLOC en préservant le nombre de
/// lignes, en sautant les littéraux de chaîne.
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

/// [stripped] joint en une seule chaîne.
String strippedText(File f) => stripped(f).join('\n');
