/// Normalisation de texte **pur-Dart** pour la **recherche sans accents** du
/// domaine `zcrud_core`.
///
/// origine: E4-3 (recherche/filtre/tri/pagination de la liste, FR-6..FR-8 ·
/// AD-8/AD-10/AD-16). Ce helper **neutre** est réutilisable par l'adaptateur
/// Firestore (E5) et par le moteur in-memory (`zApplyListRequest`, E4-3).
///
/// **Pur-Dart, aucune dépendance** (AD-1, out-degree 0) : aucun `BuildContext`,
/// aucun widget, aucun `dart:ui`, PAS de `package:intl`. Déterministe (même
/// entrée → même sortie) et **ne lève jamais** (chaîne vide → chaîne vide).
///
/// **Limite connue (L-2, consignée — extension future).** La table couvre les
/// formes **précomposées** (NFC : `é` = U+00E9). Une entrée en forme
/// **décomposée** (NFD : `e` + U+0301 combinant) n'est PAS repliée — le rune
/// combinant subsiste. Sans `package:intl`/`dart:convert` Unicode, aucune
/// normalisation NFD n'est appliquée (out-degree 0). Rare en pratique (les
/// données persistées zcrud sont majoritairement NFC). Évolution future
/// possible **sans dépendance** : stripper les marques combinantes
/// U+0300–U+036F avant consultation de la table.
library;

/// Table de repli des **diacritiques Latin** courants (français + langues
/// latines usuelles) vers leur forme ASCII. Clés en **minuscule** (le pliage
/// abaisse la casse AVANT de consulter la table) ; les ligatures (`œ`/`æ`/`ß`)
/// se déplient sur PLUSIEURS caractères (d'où un `StringBuffer`, pas un map
/// char→char de longueur fixe).
///
/// Documentée et figée : toute évolution reste **additive** (AD-10). Couvre au
/// minimum `à â ä á ã å → a`, `ç → c`, `è é ê ë → e`, `ì í î ï → i`, `ñ → n`,
/// `ò ó ô ö õ → o`, `ù ú û ü → u`, `ý ÿ → y`, `œ → oe`, `æ → ae`, `ß → ss`.
const Map<String, String> _foldTable = <String, String>{
  // a
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  // c
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
  // d
  'ð': 'd', 'đ': 'd', 'ď': 'd',
  // e
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ę': 'e',
  'ě': 'e', 'ė': 'e',
  // g
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
  // i
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
  'ı': 'i',
  // l
  'ł': 'l', 'ľ': 'l', 'ĺ': 'l', 'ļ': 'l',
  // n
  'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ņ': 'n',
  // o
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ō': 'o', 'ŏ': 'o',
  'ő': 'o', 'ø': 'o',
  // r
  'ŕ': 'r', 'ř': 'r', 'ŗ': 'r',
  // s
  'š': 's', 'ś': 's', 'ş': 's', 'ŝ': 's', 'ș': 's',
  // t
  'ť': 't', 'ţ': 't', 'ț': 't', 'þ': 't',
  // u
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u',
  'ű': 'u', 'ų': 'u',
  // y
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  // z
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  // ligatures (multi-caractères)
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss', 'ĳ': 'ij',
};

/// Replie [input] pour la **recherche sans accents** : abaisse la casse puis
/// remplace chaque diacritique Latin par sa forme ASCII (table [_foldTable]).
///
/// Exemples : `zFoldDiacritics('Café') == 'cafe'`,
/// `zFoldDiacritics('ÉÈÊË') == 'eeee'`, `zFoldDiacritics('Œuvre') == 'oeuvre'`.
/// **Idempotent** (`zFoldDiacritics(zFoldDiacritics(x)) == zFoldDiacritics(x)`)
/// et total (chaîne vide → chaîne vide ; ne lève jamais).
String zFoldDiacritics(String input) {
  if (input.isEmpty) return input;
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_foldTable[ch] ?? ch);
  }
  return buffer.toString();
}
