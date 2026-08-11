/// Utilitaires PARTAGÉS des gardes de `zcrud_menu`.
///
/// 🔴 Ancrage : `_repoRoot()` remonte jusqu'au dossier portant `melos.yaml`
/// (convention CLAUDE.md). Un `../` relatif rendrait la garde dépendante du
/// répertoire de lancement — un rouge obtenu depuis la racine ne serait alors
/// pas un rouge du code, et un vert obtenu au mauvais endroit ne prouverait rien.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du monorepo (dossier portant `melos.yaml`).
Directory repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('racine du monorepo (melos.yaml) introuvable depuis '
      '${Directory.current.path}');
}

/// `lib/` d'un package du monorepo.
Directory packageLib(String package) {
  final d = Directory('${repoRoot().path}/packages/$package/lib');
  if (!d.existsSync()) fail('lib/ de $package introuvable : ${d.path}');
  return d;
}

/// Fichiers `.dart` d'un répertoire (récursif).
List<File> dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);

/// Retire les commentaires Dart (`//`, `///`, `/* */`).
///
/// Indispensable : les dartdoc de ce package CITENT nommément les motifs
/// interdits (`Alignment.centerLeft`, `PopupMenuButton`, `flutter_riverpod`…)
/// pour expliquer pourquoi ils le sont. Une garde qui grepperait le fichier brut
/// se dénoncerait elle-même — et, pire, resterait rouge quoi qu'on fasse au CODE.
///
/// 🔴 P0D2 : réécrite en scanner caractère par caractère (`//` reconnu AVANT
/// `/*`). L'ancienne implémentation retirait les blocs `/* … */` par une regex
/// `dotAll` appliquée en un seul passage sur le fichier ENTIER, avant même le
/// retrait des `//` : un dartdoc citant littéralement `packages/*/lib`
/// (présent tel quel dans CLAUDE.md, donc probable dans la documentation à
/// venir) y ouvre un faux commentaire de bloc que la regex referme sur le
/// PROCHAIN `*/` du fichier — avalant potentiellement des dizaines de lignes
/// de CODE réel, rendant la garde silencieusement vacuelle sans jamais rougir
/// pour le signaler.
String stripComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < source.length) {
    final String c = source[i];
    final String next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= source.length ? i + 2 : source.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final String quote = c;
      out.write(c);
      i++;
      while (i < source.length) {
        if (source[i] == r'\') {
          out.write(source.substring(i, i + 2 <= source.length ? i + 2 : i + 1));
          i += 2;
          continue;
        }
        out.write(source[i]);
        if (source[i] == quote || source[i] == '\n') {
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

/// Source de `lib/` d'un package, commentaires RETIRÉS, indexée par chemin.
Map<String, String> libCode(String package) {
  final files = dartFiles(packageLib(package));
  if (files.isEmpty) {
    fail('contrôle positif en échec : aucun .dart sous lib/ de $package — '
        'la garde se serait déclarée verte sans rien lire.');
  }
  return <String, String>{
    for (final f in files) f.path: stripComments(f.readAsStringSync()),
  };
}
