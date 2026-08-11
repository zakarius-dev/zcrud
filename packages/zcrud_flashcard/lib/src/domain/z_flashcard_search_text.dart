/// Normalisation de texte pour la recherche de flashcards.
///
/// ## Ce fichier ne contient aucune table de repli — et c'est le point
///
/// La table des diacritiques existe déjà, dans `zcrud_core` (`zFoldDiacritics`) :
/// casse, `à/â/ä/á/ã`, `ç`, `è/é/ê/ë`, `ñ`, `ö/ø`, `ü`, ligatures
/// `œ→oe`/`æ→ae`/`ß→ss`/`ĳ→ij`, et le `ı` turc. En recopier une seconde ici
/// serait une seconde entité, en version texte : deux tables divergeraient au
/// premier ajout, et la recherche donnerait deux résultats différents selon
/// le chemin emprunté — sans qu'aucun test ne rougisse.
///
/// [zFlashcardSearchText] délègue donc à [zFoldDiacritics] et n'ajoute que
/// deux manques que ce dernier documente lui-même :
///
/// | Manque | Origine | Traitement ici |
/// |---|---|---|
/// | Formes décomposées (NFD) | `zFoldDiacritics` ne replie que le précomposé (NFC) : `e` + U+0301 laisse le rune combinant | strip des marques combinantes U+0300–U+036F posées sur une base latine (ou orphelines), avant délégation |
/// | Espaces | `zFoldDiacritics` ne normalise aucun espace | `trim` + runs d'espaces (dont insécables) → un seul `' '` |
///
/// L'ordre est délibéré : strip NFD d'abord (sinon `e`+U+0301 n'est pas une
/// clé de la table et sortirait tel quel), délégation ensuite (le précomposé
/// `é` reste replié par la table), espaces enfin.
///
/// ## Le strip NFD est borné au latin
///
/// La table de `zFoldDiacritics` ne couvre que le latin précomposé. Retirer
/// une marque combinante d'une base non latine (cyrillique, grec, …) ne
/// « ramène » rien à une base ASCII : cela confond deux lettres distinctes.
/// On ne strippe donc une marque combinante que si la base qu'elle décore
/// est latine (rune de base inférieur à U+0250, fin du bloc Latin
/// Extended-B) — ou orpheline (aucune base : rien à décorer, donc retirée).
/// Le non-latin est préservé tel quel : ce paquet ne replie pas ces scripts,
/// mais il ne les corrompt plus. La parité NFC/NFD hors latin reste une
/// limite documentée, qui relève du paquet propriétaire de la table.
///
/// Fonction pure (aucune E/S, aucune horloge), totale (invariant AD-10 : ne
/// lève jamais — chaîne vide, espaces seuls, emoji, paires de substitution)
/// et idempotente.
library;

import 'package:zcrud_core/domain.dart' show zFoldDiacritics;

/// Borne basse du bloc Unicode « Combining Diacritical Marks » (U+0300).
const int _kCombiningStart = 0x0300;

/// Borne haute du bloc Unicode « Combining Diacritical Marks » (U+036F).
///
/// Ce bloc porte les accents décomposés (NFD) du latin : `e` + U+0301 = `é`.
/// Les retirer d'une base latine ramène le texte à sa base ASCII, ce qui
/// complète la table NFC de [zFoldDiacritics] pour le latin.
const int _kCombiningEnd = 0x036F;

/// Borne haute (exclusive) des bases considérées « latines » : fin du bloc
/// Latin Extended-B (U+024F). Une marque combinante n'est retirée que si la
/// base qu'elle décore est inférieure à `_kLatinEnd` — cyrillique (U+04xx),
/// grec (U+03xx) et au-delà sont préservés, jamais confondus.
const int _kLatinEnd = 0x0250;

/// Normalise [input] pour la recherche de flashcards.
///
/// Pipeline (ordre significatif) :
/// 1. strip des marques combinantes U+0300–U+036F posées sur une base latine
///    ou orphelines (formes NFD latines réduites à leur base ; non-latin
///    préservé) ;
/// 2. délégation à [zFoldDiacritics] (casse et table NFC de `zcrud_core` —
///    jamais réimplémentée ici) ;
/// 3. repli des espaces : `trim` + tout run d'espaces (espace, tabulation,
///    saut de ligne, insécable U+00A0…) → un seul `' '`.
///
/// Garanties (invariant AD-10) :
/// - totale : ne lève jamais (`''` → `''` ; espaces seuls → `''`) ;
/// - idempotente : `f(f(x)) == f(x)` ;
/// - préserve ce qu'elle ne sait pas replier (emoji, CJK, chiffres) — jamais
///   de perte silencieuse ni de crash sur les paires de substitution
///   (l'itération se fait sur les runes, jamais sur les unités de code).
///
/// ```dart
/// zFlashcardSearchText('  Élève   ÂGÉ ')      // 'eleve age'
/// zFlashcardSearchText('élève')   // 'eleve'  (NFD replié)
/// zFlashcardSearchText('Œuvre')               // 'oeuvre' (délégué au cœur)
/// ```
String zFlashcardSearchText(String input) {
  if (input.isEmpty) return input;

  // 1. Strip NFD borné au latin — comble une limite connue de
  //    `zFoldDiacritics`, avant la table, sans confondre les lettres
  //    non-latines. Itération sur les runes (points de code) : un emoji
  //    hors BMP est une paire de substitution ; le parcourir en unités de
  //    code le couperait en deux.
  final stripped = StringBuffer();
  int? lastBase; // dernier rune de BASE émis (non combinant) ; null = aucun.
  for (final rune in input.runes) {
    if (rune >= _kCombiningStart && rune <= _kCombiningEnd) {
      // Marque combinante : retirée uniquement si sa base est latine
      // (repliable par la table) ou orpheline (rien à décorer). Sur une
      // base non latine, la conserver évite de fusionner deux lettres
      // distinctes.
      if (lastBase == null || lastBase < _kLatinEnd) continue;
      stripped.writeCharCode(rune);
      continue;
    }
    lastBase = rune;
    stripped.writeCharCode(rune);
  }

  // 2. Délégation — la table de repli reste unique, dans `zcrud_core`.
  final folded = zFoldDiacritics(stripped.toString());

  // 3. Repli des espaces (`zFoldDiacritics` n'en normalise aucun).
  return _collapseWhitespace(folded);
}

/// `trim` + tout run d'espaces → un seul `' '`.
///
/// Couvre tous les espaces Unicode (`\s` de Dart inclut U+00A0 insécable,
/// U+2007, U+202F…) : un utilisateur qui colle un texte riche apporte souvent
/// des insécables — les laisser produirait « aucun résultat » sur une
/// recherche pourtant juste.
String _collapseWhitespace(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');
