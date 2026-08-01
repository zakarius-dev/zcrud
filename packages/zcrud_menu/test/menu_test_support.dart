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
String stripComments(String source) {
  final sansBlocs = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sansBlocs
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        if (i < 0) return l;
        // Un `//` dans une chaîne littérale (ex. une URL) n'est pas un
        // commentaire : on ne coupe que si les guillemets sont équilibrés avant.
        final avant = l.substring(0, i);
        final quotes = "'".allMatches(avant).length;
        final dquotes = '"'.allMatches(avant).length;
        if (quotes.isOdd || dquotes.isOdd) return l;
        return avant;
      })
      .join('\n');
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
