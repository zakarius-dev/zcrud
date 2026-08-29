// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES de `zcrud_document`.
//
// 🔴 P0D3 (chantier dartdoc) : les gardes de ce paquet qui grep-aient le
// `lib/` BRUT (`z_document_viewer_chrome_test.dart` — `contains('Colors.')`,
// `contains("Text('")`…) mordraient sur leur PROPRE documentation dès qu'une
// dartdoc citerait ces motifs pour EXPLIQUER l'interdiction (exactement le
// contenu du chantier de documentation en cours). Ce fichier centralise donc
// un dépouillement de commentaires ROBUSTE (patron
// `zcrud_chat_kernel/test/support/z_repo_sources.dart`) :
//   • `//` reconnu AVANT `/*` (une dartdoc peut écrire un chemin contenant
//     `/*` sans faire s'effondrer le parseur) ;
//   • les littéraux de chaîne sont SAUTÉS (une URL contient `//`) ;
//   • la numérotation de ligne est PRÉSERVÉE (les messages d'échec restent
//     exacts).
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier tourne sous VM
// (`@TestOn('vm')` déjà porté par les gardes existantes du paquet — Flutter
// SDK exclut `zcrud_document` de `gate:web` de toute façon, cf.
// `source_policy_test.dart`). Ce fichier n'est pas un `*_test.dart` lui-même.
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

/// Fichiers de RÉFÉRENCE COULEUR audités, exemptés **nominativement** des
/// gardes anti-couleurs du paquet (exception FR-26 encadrée).
///
/// 🔴 SOURCE UNIQUE : `source_policy_test.dart` (AC13(d)) **et**
/// `z_document_style_purity_test.dart` lisent cette même constante. Deux
/// listes recopiées dériveraient, et la plus laxiste des deux gagnerait en
/// silence.
///
/// Chemins relatifs à la racine du paquet, comparés après normalisation des
/// séparateurs et ancrage sur `lib/`. Un fichier n'entre ici qu'à trois
/// conditions : il est l'UNIQUE fichier de référence de sa famille, ses
/// valeurs sont remplaçables par paramètre et par profil, et l'exemption le
/// nomme — jamais son répertoire, jamais son contenu.
///
/// Trois contre-preuves tiennent cette liste étroite (cf.
/// `z_document_style_purity_test.dart`) : un chemin exempté qui n'existe pas
/// rougit, un chemin exempté SANS littéral de couleur rougit, et le MÊME
/// CONTENU placé sous un autre chemin rougit.
const Set<String> kZColorReferenceFiles = <String>{
  'lib/src/presentation/z_annotation_palette_reference.dart',
};

/// Chemin normalisé et ancré sur `lib/` — `packages/zcrud_document/lib/x` et
/// `lib/x` rendent la même chaîne, quel que soit le répertoire de lancement.
String normalizedLibPath(String path) {
  final String p = path.replaceAll(r'\', '/');
  final int i = p.indexOf('lib/');
  return i < 0 ? p : p.substring(i);
}

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
