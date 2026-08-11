// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet et veulent
// être INSENSIBLES aux commentaires (dartdoc/`//`/`/* */`) sans devenir
// aveugles à une violation dans le CODE.
//
// 🔴 MOTIF (chantier documentation, 2026-08-11, P0D1) — quatre fichiers de ce
// paquet (`z_mindmap_conformance_test.dart`,
// `z_mindmap_markdown_edit_field_test.dart`,
// `z_mindmap_markdown_content_test.dart`, `z_mindmap_view_controls_test.dart`)
// dupliquaient CHACUN la même fonction `_stripComments`, qui retirait les
// blocs `/* … */` par un SEUL `RegExp(r'/\*.*?\*/', dotAll: true)` appliqué
// au fichier ENTIER, AVANT le retrait des commentaires de ligne. C'est
// exactement l'ordre que `zcrud_chat_kernel/test/support/z_repo_sources.dart`
// documente comme DANGEREUX : un dartdoc qui écrit littéralement `/*` dans un
// commentaire de LIGNE (par ex. pour expliquer la syntaxe des commentaires de
// bloc) ferait avaler tout le texte jusqu'au PROCHAIN `*/` du fichier — y
// compris du CODE RÉEL entre les deux — rendant la garde VACUELLE sur cette
// tranche sans qu'aucun signal ne le montre. Ce fichier centralise donc le
// retrait de commentaires — dans le BON ORDRE (ligne avant bloc, caractère
// par caractère) — à répliquer nulle part ailleurs dans ce paquet.
//
// Patron : `packages/zcrud_chat_kernel/test/support/z_repo_sources.dart`.
//
// ⚠️ `dart:io` : ce fichier n'est pas un `*_test.dart`, le runner ne l'exécute
// jamais seul — il ne porte donc pas `@TestOn('vm')`.
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
/// source déjà en mémoire, en SAUTANT les littéraux de chaîne (une URL
/// contient `//`). Drop-in pour tout ancien `_stripComments(String source)`
/// local : même signature, même contrat (retourne le CODE recomposé).
///
/// 🔴 L'ordre compte : le commentaire de LIGNE est reconnu AVANT `/*`, et le
/// balayage se fait caractère par caractère — jamais un `RegExp` global de
/// bloc appliqué au texte entier (cf. l'en-tête de ce fichier).
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

/// Variante qui lit directement un [File] et retourne le code strippé.
String stripped(File f) => stripSource(f.readAsStringSync());
