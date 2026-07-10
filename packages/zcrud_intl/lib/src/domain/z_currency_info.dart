/// `ZCurrencyInfo` — **entrée de catalogue devise neutre** (E11b-2,
/// AD-1/AD-14/AD-10).
///
/// origine: entrée de l'asset `currencies.json` bundlé dans `zcrud_intl`, servant
/// le sélecteur de code devise (`ZCurrencyField`). Modèle **pur-Dart**.
///
/// **IMPORTANT — valeur de tranche = code devise ISO 4217 `String` opaque**, PAS
/// ce modèle. [ZCurrencyInfo] enrichit l'affichage du picker (nom/symbole/
/// décimales) mais n'est **jamais** la valeur écrite dans le `ZFormController`.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` ou
/// [code] absent/vide → `null` ; `decimalDigits` non entier → `null`.
library;

/// Entrée de catalogue devise : code ISO 4217 + nom/symbole/décimales optionnels.
class ZCurrencyInfo {
  /// Construit une entrée de catalogue. Seul [code] est requis (clé du picker).
  const ZCurrencyInfo({
    required this.code,
    this.name,
    this.symbol,
    this.decimalDigits,
  });

  /// Code devise ISO 4217 (ex. `"XOF"`) — clé opaque.
  final String code;

  /// Nom lisible de la devise (ex. `"Franc CFA (BCEAO)"`).
  final String? name;

  /// Symbole d'affichage (ex. `"€"`, `"CFA"`).
  final String? symbol;

  /// Nombre de décimales usuelles (ex. `2` pour EUR, `0` pour XOF/JPY).
  final int? decimalDigits;

  /// Sérialise en `Map` neutre. Clés alignées sur l'asset `currencies.json`.
  Map<String, Object?> toMap() => <String, Object?>{
        'code': code,
        if (name != null) 'name': name,
        if (symbol != null) 'symbol': symbol,
        if (decimalDigits != null) 'decimalDigits': decimalDigits,
      };

  /// Parse **défensif** (AD-10) : `null` sans throw si [raw] n'est pas une `Map`
  /// ou si le code (`code`) est absent/vide. Accepte l'alias `currencyCode`.
  static ZCurrencyInfo? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    final code = _asString(raw['code']) ?? _asString(raw['currencyCode']);
    if (code == null) return null;
    return ZCurrencyInfo(
      code: code.toUpperCase(),
      name: _asString(raw['name']),
      symbol: _asString(raw['symbol']),
      decimalDigits: _asInt(raw['decimalDigits']),
    );
  }

  /// Alias défensif de [fromMapSafe].
  static ZCurrencyInfo? fromMap(Object? raw) => fromMapSafe(raw);

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num && v.isFinite) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCurrencyInfo &&
          other.code == code &&
          other.name == name &&
          other.symbol == symbol &&
          other.decimalDigits == decimalDigits;

  @override
  int get hashCode => Object.hash(code, name, symbol, decimalDigits);

  @override
  String toString() => 'ZCurrencyInfo(code: $code, name: $name, '
      'symbol: $symbol, decimalDigits: $decimalDigits)';
}
