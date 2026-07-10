/// `ZPostalAddress` — **adresse postale neutre structurée** (E11a-2,
/// AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du champ `address` du `ZFormController`. Modèle
/// **pur-Dart** : uniquement des `String`. Aucune lib d'adresse/géocodage n'entre
/// ici (AD-1) ; l'autocomplétion réseau est explicitement HORS périmètre
/// (E11b/AD-12 : sous-ensemble MVP hors-ligne).
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` →
/// `null` ; champs non-`String` dégradés à `null` ; une map dont tous les champs
/// sont vides donne une adresse **neutre/vide** (non-`null`, [isEmpty]).
library;

/// Adresse postale neutre : lignes + ville/région/code postal + pays + rendu.
class ZPostalAddress {
  /// Construit une adresse structurée. Tous les champs sont optionnels.
  const ZPostalAddress({
    this.line1,
    this.line2,
    this.city,
    this.region,
    this.postalCode,
    this.countryCode,
    this.formatted,
  });

  /// Première ligne (numéro + voie).
  final String? line1;

  /// Deuxième ligne (complément).
  final String? line2;

  /// Ville / localité.
  final String? city;

  /// Région / état / province.
  final String? region;

  /// Code postal.
  final String? postalCode;

  /// Code pays ISO 3166-1 alpha-2 (ex. `"NE"`).
  final String? countryCode;

  /// Rendu textuel formaté optionnel (libre).
  final String? formatted;

  /// `true` si aucun champ n'est renseigné (adresse neutre/vide).
  bool get isEmpty =>
      !_notEmpty(line1) &&
      !_notEmpty(line2) &&
      !_notEmpty(city) &&
      !_notEmpty(region) &&
      !_notEmpty(postalCode) &&
      !_notEmpty(countryCode) &&
      !_notEmpty(formatted);

  /// Sérialise en `Map` neutre. Les champs `null`/vides sont omis (schéma
  /// additif).
  Map<String, Object?> toMap() => <String, Object?>{
        if (_notEmpty(line1)) 'line1': line1,
        if (_notEmpty(line2)) 'line2': line2,
        if (_notEmpty(city)) 'city': city,
        if (_notEmpty(region)) 'region': region,
        if (_notEmpty(postalCode)) 'postalCode': postalCode,
        if (_notEmpty(countryCode)) 'countryCode': countryCode,
        if (_notEmpty(formatted)) 'formatted': formatted,
      };

  /// Parse **défensif** (AD-10) : `null` sans jamais throw si [raw] n'est pas une
  /// `Map`. Champs non-`String` dégradés à `null`. Une map « tous champs vides »
  /// donne une adresse neutre (non-`null`, [isEmpty]).
  static ZPostalAddress? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    return ZPostalAddress(
      line1: _asString(raw['line1']),
      line2: _asString(raw['line2']),
      city: _asString(raw['city']),
      region: _asString(raw['region']),
      postalCode: _asString(raw['postalCode']),
      countryCode: _asString(raw['countryCode']),
      formatted: _asString(raw['formatted']),
    );
  }

  /// Alias défensif de [fromMapSafe] (cohérence `toMap`/`fromMap`). Ne throw
  /// jamais (AD-10).
  static ZPostalAddress? fromMap(Object? raw) => fromMapSafe(raw);

  /// Copie avec substitutions. Les champs non fournis conservent leur valeur.
  ZPostalAddress copyWith({
    String? line1,
    String? line2,
    String? city,
    String? region,
    String? postalCode,
    String? countryCode,
    String? formatted,
  }) =>
      ZPostalAddress(
        line1: line1 ?? this.line1,
        line2: line2 ?? this.line2,
        city: city ?? this.city,
        region: region ?? this.region,
        postalCode: postalCode ?? this.postalCode,
        countryCode: countryCode ?? this.countryCode,
        formatted: formatted ?? this.formatted,
      );

  static bool _notEmpty(String? v) => v != null && v.isNotEmpty;

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPostalAddress &&
          other.line1 == line1 &&
          other.line2 == line2 &&
          other.city == city &&
          other.region == region &&
          other.postalCode == postalCode &&
          other.countryCode == countryCode &&
          other.formatted == formatted;

  @override
  int get hashCode => Object.hash(
        line1,
        line2,
        city,
        region,
        postalCode,
        countryCode,
        formatted,
      );

  @override
  String toString() => 'ZPostalAddress(line1: $line1, line2: $line2, '
      'city: $city, region: $region, postalCode: $postalCode, '
      'countryCode: $countryCode, formatted: $formatted)';
}
