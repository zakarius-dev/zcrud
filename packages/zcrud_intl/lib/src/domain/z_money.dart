/// `ZMoney` — **valeur monétaire neutre** (E11b-2, AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du couple **montant + devise** (ISO 4217). Modèle
/// **pur-Dart** : un code devise `String` (ISO 4217, ex. `"XOF"`), un montant
/// `num` et un rendu formaté optionnel. Aucune lib devise/`intl` n'entre ici
/// (AD-1) : le formatage riche locale-aware est HORS périmètre (dép lourde).
///
/// **IMPORTANT** : le montant **seul** reste servi par le champ `number` du cœur
/// + `ZNumberConfig(isCurrency: true)`. [ZMoney] sert le **couple** montant+devise
/// et l'affichage ; `ZCurrencyField` peut émettre soit un code devise `String`
/// seul, soit un [ZMoney] quand un montant est saisi.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map`,
/// `amount` non numérique / non fini (NaN/Infinity), map « tous champs vides » →
/// `null`. Un montant non-fini est **rejeté** (dégradé à `null`), jamais propagé.
library;

/// Valeur monétaire neutre : code devise ISO 4217 + montant + rendu formaté.
class ZMoney {
  /// Construit une valeur monétaire. Tous les champs sont optionnels.
  const ZMoney({this.currencyCode, this.amount, this.formatted});

  /// Code devise ISO 4217 (ex. `"XOF"`, `"EUR"`) — clé opaque.
  final String? currencyCode;

  /// Montant numérique (jamais NaN/Infinity : rejeté à la lecture défensive).
  final num? amount;

  /// Rendu textuel formaté optionnel (libre).
  final String? formatted;

  /// `true` si aucun champ n'est renseigné (valeur neutre/vide).
  bool get isEmpty =>
      !_notEmpty(currencyCode) && amount == null && !_notEmpty(formatted);

  /// Sérialise en `Map` neutre. Les champs `null`/vides sont omis (additif).
  Map<String, Object?> toMap() => <String, Object?>{
        if (_notEmpty(currencyCode)) 'currencyCode': currencyCode,
        if (amount != null) 'amount': amount,
        if (_notEmpty(formatted)) 'formatted': formatted,
      };

  /// Parse **défensif** (AD-10) : `null` sans throw si [raw] n'est pas une `Map`
  /// ou si tous les champs sont vides. Accepte les alias `currency`/`code` pour le
  /// code devise. `amount` non numérique / non fini → dégradé à `null`.
  static ZMoney? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    final code = _asString(raw['currencyCode']) ??
        _asString(raw['currency']) ??
        _asString(raw['code']);
    final amount = _asNum(raw['amount']);
    final formatted = _asString(raw['formatted']);
    final money = ZMoney(currencyCode: code, amount: amount, formatted: formatted);
    return money.isEmpty ? null : money;
  }

  /// Alias défensif de [fromMapSafe] (cohérence `toMap`/`fromMap`).
  static ZMoney? fromMap(Object? raw) => fromMapSafe(raw);

  /// Copie avec substitutions.
  ZMoney copyWith({String? currencyCode, num? amount, String? formatted}) =>
      ZMoney(
        currencyCode: currencyCode ?? this.currencyCode,
        amount: amount ?? this.amount,
        formatted: formatted ?? this.formatted,
      );

  static bool _notEmpty(String? v) => v != null && v.isNotEmpty;

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  /// Numérise défensivement : `num` fini, ou `String` numérique fini ; sinon
  /// `null`. NaN/Infinity **rejetés** (AD-10).
  static num? _asNum(Object? v) {
    if (v is num) return v.isFinite ? v : null;
    if (v is String) {
      final parsed = num.tryParse(v.trim());
      return (parsed != null && parsed.isFinite) ? parsed : null;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMoney &&
          other.currencyCode == currencyCode &&
          other.amount == amount &&
          other.formatted == formatted;

  @override
  int get hashCode => Object.hash(currencyCode, amount, formatted);

  @override
  String toString() =>
      'ZMoney(currencyCode: $currencyCode, amount: $amount, formatted: $formatted)';
}
