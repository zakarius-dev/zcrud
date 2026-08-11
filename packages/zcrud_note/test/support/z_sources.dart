// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES de `zcrud_note`.
//
// 🔴 P0D3 (chantier dartdoc) : `source_policy_test.dart` dépouillait déjà les
// commentaires, mais avec un dé-commentateur REGEX « bloc PUIS ligne »
// appliqué sur le fichier ENTIER (`replaceAll(RegExp(r'/\*.*?\*/', dotAll))`
// avant le split par ligne). Cet ordre est FRAGILE : un `/*` apparu DANS un
// commentaire `//`/`///` (une dartdoc citant un chemin de ce genre) peut être
// pris pour l'ouverture d'un vrai bloc et AVALER tout le reste du fichier
// jusqu'au prochain `*/` réel — exactement le risque que documente
// `zcrud_chat_kernel/test/support/z_repo_sources.dart`. Ce fichier reprend ce
// patron ROBUSTE :
//   • `//` reconnu AVANT `/*` ;
//   • les littéraux de chaîne sont SAUTÉS (une URL contient `//`) ;
//   • la numérotation de ligne est PRÉSERVÉE (les messages d'échec restent
//     exacts).
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier tourne sous VM
// (`@TestOn('vm')` déjà porté par `source_policy_test.dart` — Flutter SDK
// exclut `zcrud_note` de `gate:web` de toute façon). Ce fichier n'est pas un
// `*_test.dart` lui-même.
library;

import 'dart:io';

/// Retire les commentaires (LIGNE **et** BLOC) d'une source entière, en
/// PRÉSERVANT le nombre de lignes.
///
/// 🔴 L'ordre compte : `//` est reconnu AVANT `/*`. Une dartdoc de ce dépôt
/// écrit couramment des chemins/URLs — un dé-commentateur « bloc d'abord »
/// appliqué au fichier ENTIER risquerait de confondre un `/*` apparu DANS un
/// commentaire de ligne avec l'ouverture d'un vrai bloc, puis d'avaler tout
/// le reste du fichier jusqu'au prochain `*/` réel. Les littéraux de chaîne
/// sont sautés pour la même raison (une URL contient `//`).
String stripComments(String src) => _strippedLines(src).join('\n');

/// Variante `File` de [stripComments].
String stripCommentsOf(File f) => stripComments(f.readAsStringSync());

List<String> _strippedLines(String src) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String raw in src.split('\n')) {
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
