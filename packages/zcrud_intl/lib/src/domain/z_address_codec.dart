/// `ZAddressCodec` — **codec de compatibilité de schéma** entre la valeur d'adresse
/// **legacy String** (DODLP, gap B10) et le modèle structuré [ZPostalAddress]
/// (E11a-2). Pur-Dart, couche `domain` (AD-1/AD-14), sans aucune lib lourde.
///
/// origine: DODLP persiste le champ adresse comme une **String plate** (adresse
/// formatée), tandis que zcrud persiste un [ZPostalAddress] structuré. Ce couple
/// (decode/encode) fait le **pont** pour qu'une collection DODLP migrée ne soit
/// **pas réécrite** en `Map` (mode « compat String »), sans embarquer de parseur
/// d'adresse.
///
/// **Stratégie « String legacy → `formatted` »** : une String legacy est portée
/// **telle quelle** dans [ZPostalAddress.formatted] (sous-champs structurés à
/// `null`). On ne tente **aucune** re-décomposition en `line1/city/…`.
///
/// **Perte structure → String (documentée, volontaire)** : [encodeToString] d'un
/// [ZPostalAddress] structuré **sans** `formatted` produit une String composée
/// (jointe par `", "`) ; la re-décoder via [decodeString] ne rend qu'un
/// [ZPostalAddress] dont **seul `formatted`** est renseigné. La re-décomposition
/// en sous-champs relèverait d'un **parseur d'adresse** (non fourni, HORS
/// périmètre). La migration fidèle consiste à **ne pas perdre la String**, pas à
/// reconstruire la structure.
///
/// **Défensif (AD-10)** : [decodeString] et [encodeToString] ne **throw JAMAIS**
/// (aucune valeur d'entrée — `Map`, `int`, `List`, `null`… — ne provoque
/// d'exception).
library;

import 'z_postal_address.dart';

/// Couple de fonctions pures (dé)sérialisant une adresse legacy `String` ⇄
/// [ZPostalAddress]. Aucun état, aucune dépendance lourde (AD-1/AD-14).
abstract final class ZAddressCodec {
  const ZAddressCodec._();

  /// Ordre canonique de composition des sous-champs vers une String (AC1).
  static const List<String> _composeOrder = <String>[
    'line1',
    'line2',
    'city',
    'region',
    'postalCode',
    'countryCode',
  ];

  /// Décode une valeur de tranche **legacy** en [ZPostalAddress].
  ///
  /// [raw] est une `String` non vide (après trim) → [ZPostalAddress] dont **seul**
  /// `formatted` porte la String **telle quelle** (non trimée). `null`, chaîne
  /// vide/blanche, ou toute valeur **non-`String`** (`Map`/`int`/`List`…) → `null`
  /// (état neutre). Ne throw jamais (AD-10).
  static ZPostalAddress? decodeString(Object? raw) {
    if (raw is! String) return null;
    if (raw.trim().isEmpty) return null;
    // La String legacy est portée telle quelle dans `formatted` (aucune perte).
    return ZPostalAddress(formatted: raw);
  }

  /// Encode un [ZPostalAddress] en String legacy (mode « compat String »).
  ///
  /// `null`/[ZPostalAddress.isEmpty] → `null`. Sinon **préfère `addr.formatted`**
  /// (round-trip String à l'octet près) ; à défaut **compose** une String depuis
  /// les sous-champs renseignés, dans l'ordre `line1, line2, city, region,
  /// postalCode, countryCode`, jointe par `", "`. Ne throw jamais (AD-10).
  static String? encodeToString(ZPostalAddress? addr) {
    if (addr == null || addr.isEmpty) return null;
    final formatted = addr.formatted;
    if (formatted != null && formatted.trim().isNotEmpty) {
      // Fidélité migration : rendu formaté préféré, non altéré (AC2/AC3a).
      return formatted;
    }
    // Composition ordonnée depuis les sous-champs (structure → String, lossy).
    final byKey = <String, String?>{
      'line1': addr.line1,
      'line2': addr.line2,
      'city': addr.city,
      'region': addr.region,
      'postalCode': addr.postalCode,
      'countryCode': addr.countryCode,
    };
    final parts = <String>[
      for (final key in _composeOrder)
        if (_notBlank(byKey[key])) byKey[key]!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;
}
