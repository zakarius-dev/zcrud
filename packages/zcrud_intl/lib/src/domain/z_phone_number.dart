/// `ZPhoneNumber` — **numéro de téléphone neutre** (E11a-2, AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du champ `phoneNumber` du `ZFormController`. Modèle
/// **pur-Dart** : uniquement des `String`. **Aucun** type d'une lib téléphone
/// (`PhoneNumber`/`IsoCode` de `phone_numbers_parser`) n'apparaît dans sa
/// signature publique — la (dé)normalisation E.164 vit EXCLUSIVEMENT dans la
/// couche presentation (widget), jamais ici (AD-1 : le domaine ne dépend d'aucune
/// lib intl/téléphone).
///
/// **Représentation canonique persistée = [e164]** (chaîne opaque, ex.
/// `"+22790000000"`). Les autres champs ([isoCode]/[dialCode]/[nationalNumber])
/// facilitent l'édition/affichage mais restent secondaires.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map`,
/// champs absents ou non-`String` → `null`/ignorés (état neutre). L'évolution de
/// schéma reste additive.
library;

/// Numéro de téléphone neutre : E.164 canonique + métadonnées d'édition.
class ZPhoneNumber {
  /// Construit un numéro neutre. Tous les champs sont optionnels : un numéro en
  /// cours de saisie peut n'avoir que [dialCode]/[isoCode] renseignés.
  const ZPhoneNumber({
    this.e164,
    this.isoCode,
    this.dialCode,
    this.nationalNumber,
  });

  /// Forme **E.164** canonique (ex. `"+22790000000"`) — la valeur persistée.
  final String? e164;

  /// Code pays ISO 3166-1 alpha-2 (ex. `"NE"`).
  final String? isoCode;

  /// Indicatif d'appel avec `+` (ex. `"+227"`).
  final String? dialCode;

  /// Partie nationale du numéro (sans indicatif).
  final String? nationalNumber;

  /// `true` si aucun champ significatif n'est renseigné (numéro neutre/vide).
  bool get isEmpty =>
      (e164 == null || e164!.isEmpty) &&
      (nationalNumber == null || nationalNumber!.isEmpty);

  /// Sérialise en `Map` neutre. Les champs `null`/vides sont omis (schéma
  /// additif, persistance compacte).
  Map<String, Object?> toMap() => <String, Object?>{
        if (_notEmpty(e164)) 'e164': e164,
        if (_notEmpty(isoCode)) 'isoCode': isoCode,
        if (_notEmpty(dialCode)) 'dialCode': dialCode,
        if (_notEmpty(nationalNumber)) 'nationalNumber': nationalNumber,
      };

  /// Parse **défensif** (AD-10) : `null` sans jamais throw si [raw] n'est pas une
  /// `Map`. Les champs non-`String` sont dégradés à `null`. Une map sans aucun
  /// champ significatif donne un [ZPhoneNumber] neutre (non-`null`, mais
  /// [isEmpty]).
  static ZPhoneNumber? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    return ZPhoneNumber(
      e164: _asString(raw['e164']),
      isoCode: _asString(raw['isoCode']),
      dialCode: _asString(raw['dialCode']),
      nationalNumber: _asString(raw['nationalNumber']),
    );
  }

  /// Alias défensif de [fromMapSafe] (cohérence `toMap`/`fromMap`). Ne throw
  /// jamais (AD-10).
  static ZPhoneNumber? fromMap(Object? raw) => fromMapSafe(raw);

  /// Copie avec substitutions. Les champs non fournis conservent leur valeur.
  ZPhoneNumber copyWith({
    String? e164,
    String? isoCode,
    String? dialCode,
    String? nationalNumber,
  }) =>
      ZPhoneNumber(
        e164: e164 ?? this.e164,
        isoCode: isoCode ?? this.isoCode,
        dialCode: dialCode ?? this.dialCode,
        nationalNumber: nationalNumber ?? this.nationalNumber,
      );

  static bool _notEmpty(String? v) => v != null && v.isNotEmpty;

  static String? _asString(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPhoneNumber &&
          other.e164 == e164 &&
          other.isoCode == isoCode &&
          other.dialCode == dialCode &&
          other.nationalNumber == nationalNumber;

  @override
  int get hashCode => Object.hash(e164, isoCode, dialCode, nationalNumber);

  @override
  String toString() => 'ZPhoneNumber(e164: $e164, isoCode: $isoCode, '
      'dialCode: $dialCode, nationalNumber: $nationalNumber)';
}
