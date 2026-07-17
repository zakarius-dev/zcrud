/// Normalisation de texte pour la **recherche de flashcards** (SU-8, FR-SU14 —
/// AC4, décision D5).
///
/// ## 🔴 Ce fichier ne contient AUCUNE table de repli — et c'est le point
///
/// La table des diacritiques **EXISTE DÉJÀ**, dans `zcrud_core`
/// (`z_search_text.dart` → [zFoldDiacritics]) : casse, `à/â/ä/á/ã`, `ç`,
/// `è/é/ê/ë`, `ñ`, `ö/ø`, `ü`, ligatures `œ→oe`/`æ→ae`/`ß→ss`/`ĳ→ij`, et le `ı`
/// turc. En recopier une seconde ici serait le péché de la **« 2e entité »**, en
/// version texte : deux tables divergeraient au premier ajout, et la recherche
/// donnerait deux résultats différents selon le chemin emprunté — sans qu'aucun
/// test ne rougisse.
///
/// ⇒ [zFlashcardSearchText] **DÉLÈGUE** à [zFoldDiacritics] et n'ajoute **que**
/// les deux manques que ce dernier documente lui-même :
///
/// | Manque | Origine | Traitement ici |
/// |---|---|---|
/// | **NFD** (limite **L-2**) | `zFoldDiacritics` ne replie que le **précomposé** (NFC) : `e` + U+0301 laisse le rune combinant | **strip** des marques combinantes **U+0300–U+036F** posées sur une **base LATINE** (ou orphelines), AVANT délégation |
/// | **espaces** | `zFoldDiacritics` ne normalise **aucun** espace | `trim` + runs d'espaces (dont **insécables**) → **un seul** `' '` |
///
/// L'ordre est **délibéré** : strip NFD **d'abord** (sinon `e`+U+0301 n'est pas
/// une clé de la table et sortirait tel quel), délégation **ensuite** (le
/// précomposé `é` reste replié par la table), espaces **enfin**.
///
/// ## 🔴 Le strip NFD est BORNÉ au latin (décision D7)
///
/// La table de `zFoldDiacritics` ne couvre que le **latin précomposé**. Retirer
/// une marque combinante d'une base **non-latine** (cyrillique, grec, …) ne
/// « ramène » rien à une base ASCII : il **CONFOND deux lettres distinctes**
/// (`й` = и + U+0306 deviendrait `и`, une autre lettre du russe ⇒ « мой »
/// indexé « мои »). On ne strip donc une marque combinante que si la **base
/// qu'elle décore est latine** (rune de base `< U+0250`, fin du bloc Latin
/// Extended-B) — ou **orpheline** (aucune base : rien à décorer ⇒ retirée). Le
/// non-latin est **préservé tel quel** : su-8 ne replie pas ces scripts, mais il
/// ne les **corrompt** plus. La parité NFC/NFD hors-latin reste une limite
/// documentée (relève de l'epic ME, qui possède la table).
///
/// **Pourquoi ici et pas dans `zcrud_core`** : `zcrud_core` est **INTERDIT en
/// écriture** à cette story (réservé à l'epic ME). La limite L-2 est donc
/// contournée **chez le consommateur**, sans toucher la table — qui reste
/// l'unique source.
///
/// Fonction **PURE** (aucune I/O, aucune horloge), **TOTALE** (AD-10 : ne lève
/// jamais — chaîne vide, espaces seuls, emoji, surrogates) et **IDEMPOTENTE**.
library;

import 'package:zcrud_core/domain.dart' show zFoldDiacritics;

/// Borne **basse** du bloc Unicode « Combining Diacritical Marks » (U+0300).
const int _kCombiningStart = 0x0300;

/// Borne **haute** du bloc Unicode « Combining Diacritical Marks » (U+036F).
///
/// Ce bloc porte les accents **décomposés** (NFD) du Latin : `e` + U+0301 = `é`.
/// Les retirer d'une base **latine** ramène le texte à sa base ASCII, ce qui
/// **complète** la table NFC de [zFoldDiacritics] pour le latin (limite L-2).
const int _kCombiningEnd = 0x036F;

/// Borne **haute (exclusive)** des bases considérées « latines » : fin du bloc
/// Latin Extended-B (U+024F). Une marque combinante n'est retirée que si la base
/// qu'elle décore est `< _kLatinEnd` (décision D7) — cyrillique (U+04xx), grec
/// (U+03xx) et au-delà sont **préservés**, jamais confondus.
const int _kLatinEnd = 0x0250;

/// Normalise [input] pour la **recherche de flashcards** (AC4).
///
/// Pipeline (ordre **significatif**) :
/// 1. **strip** des marques combinantes U+0300–U+036F posées sur une base
///    **latine** ou orphelines (**NFD latin** → base ; non-latin préservé — D7) ;
/// 2. **délégation** à [zFoldDiacritics] (casse + table **NFC** de `zcrud_core`
///    — jamais réimplémentée ici) ;
/// 3. **repli des espaces** : `trim` + tout run d'espaces (espace, tabulation,
///    saut de ligne, **insécable** U+00A0…) → **un seul** `' '`.
///
/// Garanties (AD-10) :
/// - **totale** : ne lève jamais (`''` → `''` ; espaces seuls → `''`) ;
/// - **idempotente** : `f(f(x)) == f(x)` ;
/// - **préserve** ce qu'elle ne sait pas replier (emoji, CJK, chiffres) — jamais
///   de perte silencieuse ni de crash sur les **paires de substitution**
///   (l'itération se fait sur les **runes**, jamais sur les `codeUnits`).
///
/// ```dart
/// zFlashcardSearchText('  Élève   ÂGÉ ')      // 'eleve age'
/// zFlashcardSearchText('élève')   // 'eleve'  (NFD replié)
/// zFlashcardSearchText('Œuvre')               // 'oeuvre' (délégué au cœur)
/// ```
String zFlashcardSearchText(String input) {
  if (input.isEmpty) return input;

  // 1. Strip NFD BORNÉ AU LATIN — comble la limite L-2 de `zFoldDiacritics`
  //    AVANT la table, SANS confondre les lettres non-latines (D7).
  //    Itération sur les RUNES (points de code) : un emoji hors BMP est une
  //    paire de substitution ; le parcourir en `codeUnits` le couperait en deux.
  final stripped = StringBuffer();
  int? lastBase; // dernier rune de BASE émis (non combinant) ; null = aucun.
  for (final rune in input.runes) {
    if (rune >= _kCombiningStart && rune <= _kCombiningEnd) {
      // Marque combinante : retirée UNIQUEMENT si sa base est latine (repliable
      // par la table) ou orpheline (rien à décorer). Sur une base non-latine,
      // la CONSERVER évite de fusionner deux lettres distinctes (й→и).
      if (lastBase == null || lastBase < _kLatinEnd) continue;
      stripped.writeCharCode(rune);
      continue;
    }
    lastBase = rune;
    stripped.writeCharCode(rune);
  }

  // 2. DÉLÉGATION — la table de repli reste UNIQUE, dans `zcrud_core`.
  final folded = zFoldDiacritics(stripped.toString());

  // 3. Repli des espaces (`zFoldDiacritics` n'en normalise aucun).
  return _collapseWhitespace(folded);
}

/// `trim` + tout run d'espaces → **un seul** `' '`.
///
/// Couvre **tous** les espaces Unicode (`\s` de Dart inclut U+00A0 insécable,
/// U+2007, U+202F…) : un utilisateur qui colle un texte riche apporte souvent des
/// insécables — les laisser produirait « aucun résultat » sur une recherche
/// pourtant juste.
String _collapseWhitespace(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');
