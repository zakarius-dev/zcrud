// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet et veulent
// être INSENSIBLES aux commentaires (dartdoc/`//`/`/* */`) sans devenir
// aveugles à une violation dans le CODE.
//
// 🔴 MOTIF (chantier documentation, 2026-08-11, P0D1) — plusieurs gardes de
// `zcrud_navigation` (`z_edition_chrome_source_guard_test.dart`,
// `z_sheet_frame_test.dart`, `z_edition_scrollable_body_test.dart`) scannaient
// le fichier BRUT (`File(...).readAsStringSync()`) à la recherche de motifs
// comme `TextAlign.left`, `Colors.`, `Semantics(` — exactement les termes
// qu'un dartdoc légitime doit pouvoir CITER pour documenter qu'ils sont
// interdits (« n'utilisez jamais TextAlign.left, utilisez TextAlign.start »).
// Une insertion massive de dartdoc les aurait donc rendues ROUGES pour de la
// PROSE, jamais pour du CODE. Ce fichier centralise le retrait de
// commentaires — à répliquer nulle part ailleurs dans ce paquet.
//
// Patron : `packages/zcrud_chat_kernel/test/support/z_repo_sources.dart`
// (CHAT-0b) et `packages/zcrud_get/test/z_get_form_presenter_source_guard_test.dart`
// (GSG, qui documente déjà la même précaution localement).
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')` — ce fichier n'est pas un `*_test.dart`, il ne le porte
// donc pas lui-même (le runner ne l'exécute jamais seul).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du dépôt (dossier portant `melos.yaml`), quel que soit le CWD.
Directory zRepoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Retire les commentaires (LIGNE `//`/`///` **et** BLOC `/* … */`) d'une
/// source, en PRÉSERVANT le nombre de lignes (pour que les numéros signalés
/// par une garde restent exacts) et en SAUTANT les littéraux de chaîne (une
/// URL contient `//`).
///
/// 🔴 L'ordre compte : le commentaire de LIGNE est reconnu AVANT `/*`. Un
/// dartdoc peut légitimement écrire `packages/*/lib` — une passe « bloc
/// d'abord » sur le texte entier verrait l'ouverture d'un commentaire jamais
/// refermée et AVALERAIT LA FIN DU FICHIER (incident déjà mesuré sur
/// `z_chat_action_executor.dart:13`), rendant toute garde en aval
/// silencieusement VACUELLE. D'où un balayage caractère par caractère, jamais
/// un `RegExp(r'/\*.*?\*/', dotAll: true)` global.
List<String> strippedLines(File f) {
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

/// Comme [strippedLines], mais retourne le CODE recomposé en une seule
/// chaîne (pour les gardes qui font `.contains(...)` sur la source entière).
String stripped(File f) => strippedLines(f).join('\n');

/// Variante de [stripped] quand la source est déjà en mémoire (évite une
/// double lecture disque quand l'appelant a déjà `readAsStringSync()`).
String stripSource(String raw) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String rawLine in raw.split('\n')) {
    final StringBuffer buf = StringBuffer();
    int i = 0;
    while (i < rawLine.length) {
      final String c = rawLine[i];
      final String next = i + 1 < rawLine.length ? rawLine[i + 1] : '';
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
        while (i < rawLine.length) {
          if (rawLine[i] == r'\') {
            buf.write(rawLine[i]);
            i++;
            if (i < rawLine.length) {
              buf.write(rawLine[i]);
              i++;
            }
            continue;
          }
          buf.write(rawLine[i]);
          final bool end = rawLine[i] == quote;
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
  return out.join('\n');
}
