/// Décodage **défensif** de l'enveloppe legacy DODLP (G1, AD-10).
///
/// origine: le legacy DODLP (`data_crud/models/geo_shape.dart`) persiste ses
/// formes en **chaîne JSON** (`GeoShape.toJson()` = `json.encode(toMap())`).
/// Ce helper interne (non exporté par le barrel) donne aux `fromMapSafe` des
/// types géo un repli `jsonDecode` **qui ne throw jamais** : une `String` non
/// décodable rend `null`, tout autre objet est rendu tel quel.
library;

import 'dart:convert';

/// Si [raw] est une `String`, tente un `jsonDecode` défensif : JSON invalide →
/// `null` (jamais throw, AD-10). Sinon retourne [raw] inchangé. La valeur
/// décodée peut être une `Map` (forme legacy), une `List` (variante legacy
/// « liste nue de points », `gs:604-611`) ou un scalaire (à refuser en aval).
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
