/// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du paquet (P0D2).
///
/// [stripComments] retire les commentaires de ligne (`//`, `///`) ET de bloc
/// (`/* … */`) par un balayage caractère par caractère — `//` reconnu AVANT
/// `/*`, littéraux de chaîne préservés. Une regex bloc appliquée en un seul
/// passage serait piégée par une citation littérale de `packages/*/lib` (le
/// `/*` y ouvrirait un faux commentaire refermé sur le PROCHAIN `*/` du
/// fichier, avalant tout le code entre les deux).
library;

String stripComments(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < src.length) {
    final String c = src[i];
    final String next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= src.length ? i + 2 : src.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final String quote = c;
      out.write(c);
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          out.write(src.substring(i, i + 2 <= src.length ? i + 2 : i + 1));
          i += 2;
          continue;
        }
        out.write(src[i]);
        if (src[i] == quote || src[i] == '\n') {
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
