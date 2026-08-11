/// `ZGeoPoint` — **point géographique neutre** (E11a-1, AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du champ `location` du `ZFormController`. Modèle
/// **pur-Dart** (aucun Flutter, aucun SDK carte) : uniquement `double`/`String`.
/// **Aucun** `LatLng` (google/osm) n'apparaît dans sa signature publique — la
/// conversion vers/depuis un type SDK vit EXCLUSIVEMENT dans l'adaptateur carte
/// concret (`src/presentation/adapters/`), jamais ici (AD-1 : le domaine ne
/// dépend d'aucun SDK).
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. Coordonnée absente,
/// non numérique, non finie (NaN/Inf) ou hors-bornes (lat ∉ [-90,90], lng ∉
/// [-180,180]) → `null` (état neutre). L'évolution de schéma reste additive.
///
/// **Lecture legacy DODLP (G1)** : [fromMapSafe] accepte aussi (a) une
/// **chaîne JSON** (enveloppe legacy `toJson()`, décodée défensivement), (b)
/// les clés `latitude`/`longitude` (variante acceptée par le lecteur legacy)
/// quand `lat`/`lng` sont absentes, (c) une **forme legacy typée `point`**
/// (`{type: 'point', points: [{lat,lng}], label}` → `points[0]` + `label`).
/// LECTURE seulement : [toMap] est strictement inchangé.
library;

import 'z_geo_legacy_codec.dart';

/// Point géographique neutre : latitude/longitude + libellé/adresse optionnels.
class ZGeoPoint {
  /// Construit un point aux [lat]/[lng] (degrés décimaux) et métadonnées
  /// optionnelles. Aucune validation dure (pas d'`assert`) : les bornes sont
  /// vérifiées au **parse** défensif ([fromMapSafe]) — un point construit
  /// programmatiquement reste sous la responsabilité de l'appelant.
  const ZGeoPoint({
    required this.lat,
    required this.lng,
    this.label,
    this.address,
  });

  /// Latitude en degrés décimaux (plage valide [-90, 90]).
  final double lat;

  /// Longitude en degrés décimaux (plage valide [-180, 180]).
  final double lng;

  /// Libellé lisible optionnel (ex. nom du lieu).
  final String? label;

  /// Adresse postale optionnelle (texte libre).
  final String? address;

  /// Borne inférieure de latitude.
  static const double minLat = -90;

  /// Borne supérieure de latitude.
  static const double maxLat = 90;

  /// Borne inférieure de longitude.
  static const double minLng = -180;

  /// Borne supérieure de longitude.
  static const double maxLng = 180;

  /// `true` si [lat]/[lng] sont finis ET dans les bornes géographiques.
  bool get isValid => _inBounds(lat, lng);

  static bool _inBounds(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= minLat &&
      lat <= maxLat &&
      lng >= minLng &&
      lng <= maxLng;

  /// Sérialise en `Map` neutre (persistance snake_case-friendly : clés simples
  /// `lat`/`lng`/`label`/`address`). Les métadonnées `null` sont omises.
  Map<String, Object?> toMap() => <String, Object?>{
        'lat': lat,
        'lng': lng,
        if (label != null) 'label': label,
        if (address != null) 'address': address,
      };

  /// Parse **défensif** (AD-10) : retourne `null` sans jamais throw si [raw]
  /// n'est pas une `Map` (ou une `String` JSON legacy en contenant une), si
  /// lat/lng sont absents/non numériques/non finis, ou hors-bornes.
  /// `label`/`address` non-`String` → ignorés (dégradés à `null`).
  ///
  /// **Alias de LECTURE legacy (G1)** — la lecture stricte prime toujours :
  /// `latitude`/`longitude` ne sont consultées que si `lat`/`lng` manquent ;
  /// une forme legacy `{type:'point', points:[…]}` n'est routée que si aucune
  /// coordonnée directe n'est présente ET que `type == 'point'` (un `type`
  /// legacy non-point n'est PAS un point : `null`, jamais `points[0]` volé à
  /// un polygone).
  static ZGeoPoint? fromMapSafe(Object? raw) {
    final decoded = zGeoDecodeLegacyEnvelope(raw);
    if (decoded is! Map) return null;
    final lat =
        _asFiniteDouble(decoded['lat']) ?? _asFiniteDouble(decoded['latitude']);
    final lng = _asFiniteDouble(decoded['lng']) ??
        _asFiniteDouble(decoded['longitude']);
    if (lat == null || lng == null) return _fromLegacyPointShape(decoded);
    if (!_inBounds(lat, lng)) return null;
    final label = decoded['label'];
    final address = decoded['address'];
    return ZGeoPoint(
      lat: lat,
      lng: lng,
      label: label is String ? label : null,
      address: address is String ? address : null,
    );
  }

  /// Lecture legacy (G1) d'une **forme** DODLP de type `point` :
  /// `{type:'point', points:[{lat,lng}], label}` → `points[0]` (+ `label` de la
  /// forme). Tout autre `type` (ou `points` inexploitable) → `null` (AD-10) —
  /// le routage inter-géométries appartient à `ZGeoValue.fromMapSafe`.
  static ZGeoPoint? _fromLegacyPointShape(Map<Object?, Object?> map) {
    if (map['type'] != 'point') return null;
    final points = map['points'];
    if (points is! List || points.isEmpty) return null;
    final first = fromMapSafe(points.first);
    if (first == null) return null;
    final label = map['label'];
    return (first.label == null && label is String)
        ? first.copyWith(label: label)
        : first;
  }

  /// Alias défensif de [fromMapSafe] (nullable) — cohérence de nommage
  /// `toMap`/`fromMap`. Ne throw jamais (AD-10).
  static ZGeoPoint? fromMap(Object? raw) => fromMapSafe(raw);

  /// Convertit `num`/`String` en `double` **fini**, sinon `null` (défensif).
  static double? _asFiniteDouble(Object? v) {
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite ? d : null;
    }
    if (v is String) {
      final d = double.tryParse(v.trim());
      return (d != null && d.isFinite) ? d : null;
    }
    return null;
  }

  /// Copie avec substitutions. `label`/`address` ne peuvent pas être remis à
  /// `null` via cette API (sémantique de copie partielle).
  ZGeoPoint copyWith({
    double? lat,
    double? lng,
    String? label,
    String? address,
  }) =>
      ZGeoPoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        label: label ?? this.label,
        address: address ?? this.address,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoPoint &&
          other.lat == lat &&
          other.lng == lng &&
          other.label == label &&
          other.address == address;

  @override
  int get hashCode => Object.hash(lat, lng, label, address);

  @override
  String toString() =>
      'ZGeoPoint(lat: $lat, lng: $lng, label: $label, address: $address)';
}
