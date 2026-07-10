/// `ZCountryInfo` — **entrée de catalogue pays neutre** (E11a-2,
/// AD-1/AD-14/AD-10).
///
/// origine: entrée de l'asset `countries.json` bundlé dans `zcrud_intl`, servant
/// le picker pays et la liaison indicatif du champ téléphone. Modèle **pur-Dart**
/// (uniquement des `String`).
///
/// **IMPORTANT — valeur de tranche `country` = code ISO alpha-2 `String`
/// opaque** (canonique « `id` String opaque »), PAS ce modèle. [ZCountryInfo]
/// enrichit l'affichage du picker (nom/indicatif/drapeau) mais n'est **jamais**
/// la valeur écrite dans le `ZFormController` — seul [isoCode] l'est.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` ou
/// [isoCode] absent/vide → `null` (une entrée sans code ISO est inexploitable) ;
/// les autres champs non-`String` sont dégradés à `null`.
library;

/// Entrée de catalogue pays : code ISO + nom/indicatif/drapeau optionnels.
class ZCountryInfo {
  /// Construit une entrée de catalogue. Seul [isoCode] est requis (clé du picker
  /// et de la liaison téléphone).
  const ZCountryInfo({
    required this.isoCode,
    this.name,
    this.dialCode,
    this.flagEmoji,
  });

  /// Code pays ISO 3166-1 alpha-2 (ex. `"NE"`) — clé opaque.
  final String isoCode;

  /// Nom lisible du pays (ex. `"Niger"`).
  final String? name;

  /// Indicatif d'appel avec `+` (ex. `"+227"`).
  final String? dialCode;

  /// Drapeau **emoji** (ex. `"🇳🇪"`) — jamais une image (AD-12, pas d'asset
  /// binaire runtime).
  final String? flagEmoji;

  /// Sérialise en `Map` neutre. **Clés canoniques** alignées sur l'asset
  /// `countries.json` : `iso` / `name` / `dialCode` / `flag`. Le round-trip est
  /// symétrique — [fromMapSafe] relit ces mêmes clés (et accepte en plus les
  /// alias `isoCode` / `flagEmoji` pour l'interop d'un schéma externe, LOW-3).
  Map<String, Object?> toMap() => <String, Object?>{
        'iso': isoCode,
        if (name != null) 'name': name,
        if (dialCode != null) 'dialCode': dialCode,
        if (flagEmoji != null) 'flag': flagEmoji,
      };

  /// Parse **défensif** (AD-10) : `null` sans throw si [raw] n'est pas une `Map`
  /// ou si le code ISO (`iso`) est absent/vide. Accepte les alias `iso`/`isoCode`
  /// et `flag`/`flagEmoji` (robustesse de schéma).
  static ZCountryInfo? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    final iso = _asString(raw['iso']) ?? _asString(raw['isoCode']);
    if (iso == null) return null;
    return ZCountryInfo(
      isoCode: iso.toUpperCase(),
      name: _asString(raw['name']),
      dialCode: _asString(raw['dialCode']),
      flagEmoji: _asString(raw['flag']) ?? _asString(raw['flagEmoji']),
    );
  }

  /// Alias défensif de [fromMapSafe] (cohérence `toMap`/`fromMap`). Ne throw
  /// jamais (AD-10).
  static ZCountryInfo? fromMap(Object? raw) => fromMapSafe(raw);

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCountryInfo &&
          other.isoCode == isoCode &&
          other.name == name &&
          other.dialCode == dialCode &&
          other.flagEmoji == flagEmoji;

  @override
  int get hashCode => Object.hash(isoCode, name, dialCode, flagEmoji);

  @override
  String toString() => 'ZCountryInfo(isoCode: $isoCode, name: $name, '
      'dialCode: $dialCode, flagEmoji: $flagEmoji)';
}
