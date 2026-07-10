/// `ZSubdivision` — **subdivision (état/province/région) neutre** (E11b-2,
/// AD-1/AD-14/AD-10).
///
/// origine: entrée de l'asset `subdivisions.json` (indexé par pays), servant le
/// sélecteur d'état/province (`ZStateField`) dépendant du pays. Modèle
/// **pur-Dart** : code ISO 3166-2 (ex. `"NE-2"`), code pays ISO 3166-1 (`"NE"`),
/// nom et type optionnels.
///
/// **IMPORTANT — valeur de tranche = code ISO 3166-2 `String` opaque**, PAS ce
/// modèle. [ZSubdivision] enrichit l'affichage du picker mais n'est **jamais** la
/// valeur écrite dans le `ZFormController`.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map`, ou
/// [code]/[countryIso] absents (après repli sur `countryIso` de contexte) → `null`.
library;

/// Subdivision territoriale : code ISO 3166-2 + code pays + nom/type optionnels.
class ZSubdivision {
  /// Construit une subdivision. [code] (ISO 3166-2) et [countryIso] (ISO 3166-1)
  /// sont requis.
  const ZSubdivision({
    required this.code,
    required this.countryIso,
    this.name,
    this.type,
  });

  /// Code ISO 3166-2 (ex. `"NE-2"`) — clé opaque.
  final String code;

  /// Code pays ISO 3166-1 alpha-2 (ex. `"NE"`).
  final String countryIso;

  /// Nom lisible (ex. `"Diffa"`).
  final String? name;

  /// Type de subdivision (`"region"`/`"state"`/`"province"`…).
  final String? type;

  /// Sérialise en `Map` neutre. Clés alignées sur l'asset `subdivisions.json`.
  Map<String, Object?> toMap() => <String, Object?>{
        'code': code,
        'countryIso': countryIso,
        if (name != null) 'name': name,
        if (type != null) 'type': type,
      };

  /// Parse **défensif** (AD-10) : `null` sans throw si [raw] n'est pas une `Map`,
  /// ou si le code (`code`) ou le pays (`countryIso`, avec repli sur
  /// [countryIso] de contexte fourni par le bucket du catalogue) sont absents.
  static ZSubdivision? fromMapSafe(Object? raw, {String? countryIso}) {
    if (raw is! Map) return null;
    final code = _asString(raw['code']) ?? _asString(raw['iso']);
    final iso = _asString(raw['countryIso']) ??
        _asString(raw['country']) ??
        countryIso;
    if (code == null || iso == null) return null;
    return ZSubdivision(
      code: code.toUpperCase(),
      countryIso: iso.toUpperCase(),
      name: _asString(raw['name']),
      type: _asString(raw['type']),
    );
  }

  /// Alias défensif de [fromMapSafe].
  static ZSubdivision? fromMap(Object? raw, {String? countryIso}) =>
      fromMapSafe(raw, countryIso: countryIso);

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubdivision &&
          other.code == code &&
          other.countryIso == countryIso &&
          other.name == name &&
          other.type == type;

  @override
  int get hashCode => Object.hash(code, countryIso, name, type);

  @override
  String toString() => 'ZSubdivision(code: $code, countryIso: $countryIso, '
      'name: $name, type: $type)';
}
