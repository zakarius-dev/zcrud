// Primitives PARTAGÉES des gardes qui LISENT LES SOURCES de `zcrud_session`.
//
// 🔴 Source UNIQUE (patron `zcrud_chat/test/support/z_chat_sources.dart` /
// `zcrud_chat_kernel/test/support/z_repo_sources.dart`) : recopier
// `stripped`/`libDartFiles` dans chaque garde créerait autant de définitions
// divergentes de « source du package ». Chantier documentation (P0b) :
// plusieurs gardes de ce paquet ne dé-commentaient que les lignes commençant
// par `//`/`///` — aveugles à un commentaire de BLOC (`/* … */`) ou à un
// commentaire de FIN de ligne. Ce fichier centralise le dé-commentateur
// ROBUSTE (patron chat) pour que la prochaine garde s'appuie dessus au lieu
// de réinventer un stripper partiel.
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du package `zcrud_session`, que le test tourne depuis
/// `packages/zcrud_session` (`flutter test`, convention imposée par
/// CLAUDE.md) ou — en secours — depuis la racine du dépôt.
Directory packageRoot() {
  for (final String p in <String>['.', 'packages/zcrud_session']) {
    final Directory d = Directory(p);
    if (File('${d.path}/pubspec.yaml').existsSync() &&
        Directory('${d.path}/lib/src').existsSync()) {
      return d;
    }
  }
  fail('racine de zcrud_session introuvable depuis ${Directory.current.path}');
}

/// Tous les `.dart` de `lib/` (aucun code généré dans ce package).
///
/// 🔒 Contre-preuve R12 intégrée : un balayage vide (lib/ déplacé/renommé)
/// ROUGIT au lieu de laisser toute garde qui s'appuie dessus passer VERTE en
/// silence.
List<File> libDartFiles() {
  final Directory lib = Directory('${packageRoot().path}/lib');
  expect(lib.existsSync(), isTrue, reason: 'lib/ introuvable — garde VACUELLE');
  final List<File> files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

/// Un fichier de `lib/`, par suffixe de chemin (ex. `z_list_session_view.dart`
/// ou `src/presentation/z_list_session_view.dart`).
File libFile(String suffix) {
  final List<File> hits = libDartFiles()
      .where((File f) => f.path.replaceAll(r'\', '/').endsWith(suffix))
      .toList();
  expect(hits, hasLength(1),
      reason: 'fichier introuvable ou ambigu dans lib/ : $suffix');
  return hits.single;
}

/// Retire les commentaires de LIGNE (`//`, `///`) **et** de BLOC (`/* … */`,
/// multi-lignes) d'une source, en **préservant le nombre de lignes** (les
/// numéros signalés par une garde restent exacts) et en **sautant les
/// littéraux de chaîne** (une URL contient `//`).
///
/// 🔴 **L'ordre compte** : le commentaire de LIGNE est reconnu AVANT `/*`. Une
/// dartdoc de ce dépôt écrit couramment des motifs `/* … */` en PROSE dans un
/// commentaire `//`/`///` (ex. pour expliquer ce dé-commentateur lui-même) —
/// une passe « bloc d'abord » (regex `/\*[\s\S]*?\*/` sur la source ENTIÈRE)
/// verrait cette occurrence de `/*` en PROSE comme l'ouverture d'un VRAI bloc
/// et AVALERAIT tout le code jusqu'au PROCHAIN `*/` réel du fichier — un bug
/// mesuré dans `z_study_migrator_isolation_test.dart` (zcrud_firestore) avant
/// P0b. Le scan CARACTÈRE PAR CARACTÈRE ci-dessous ne commet pas cette erreur
/// : il reconnaît `//`/`/*` dans l'ORDRE où ils apparaissent réellement dans
/// le flux, et ignore tout ce qui est entre guillemets.
List<String> stripped(File f) => stripLines(f.readAsLinesSync());

/// Même dé-commentateur que [stripped], appliqué à des lignes déjà EN
/// MÉMOIRE (contre-preuves R12 qui exercent le VRAI scanner sur une source
/// ARTIFICIELLE sans passer par le disque).
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

/// Source d'un fichier, dé-commentée et RECOLLÉE en une seule chaîne (numéros
/// de ligne non préservés individuellement, mais la longueur logique du
/// fichier — donc les décalages d'index dans un `indexOf`/`substring` — reste
/// cohérente puisque chaque ligne d'origine devient une ligne de sortie).
String strippedSource(File f) => stripped(f).join('\n');

/// Même dé-commentateur, appliqué à une chaîne déjà EN MÉMOIRE (pas de
/// fichier — utile quand l'appelant a déjà fait `readAsStringSync()` ou
/// construit une source ARTIFICIELLE pour une contre-preuve R12).
String stripSource(String src) => stripLines(src.split('\n')).join('\n');
