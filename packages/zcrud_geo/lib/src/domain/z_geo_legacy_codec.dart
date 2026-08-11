/// Décodage **défensif** de l'enveloppe historique d'une valeur géo.
///
/// Un format hérité persiste ses formes en **chaîne JSON encodée**. Ce
/// helper interne (non exporté par le barrel) donne aux `fromMapSafe` des
/// types géo un repli `jsonDecode` qui ne throw jamais (invariant AD-10) :
/// une `String` non décodable rend `null`, tout autre objet est rendu tel
/// quel.
library;

import 'dart:convert';

/// Si [raw] est une `String`, tente un `jsonDecode` défensif : JSON invalide
/// → `null` (jamais de throw). Sinon retourne [raw] inchangé. La valeur
/// décodée peut être une `Map` (forme historique), une `List` (variante
/// « liste nue de points ») ou un scalaire (à refuser en aval).
Object? zGeoDecodeLegacyEnvelope(Object? raw) {
  if (raw is! String) return raw;
  final s = raw.trim();
  if (s.isEmpty) return null;
  try {
    return jsonDecode(s);
  } on FormatException {
    return null;
  }
}
