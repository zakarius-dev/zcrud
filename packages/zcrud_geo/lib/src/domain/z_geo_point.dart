/// `ZGeoPoint` — modèle de valeur **point géographique neutre**.
///
/// Valeur de tranche du type de champ `location`. Modèle **pur-Dart** (aucun
/// Flutter, aucun SDK carte) : uniquement `double`/`String`. Aucun type SDK
/// (`LatLng` Google/OSM) n'apparaît dans sa signature publique — la conversion
/// vers/depuis un type SDK vit exclusivement dans l'adaptateur carte concret
/// (invariant [AD-1](../../../../../docs/site/concepts/invariants.md#ad-1) :
/// le domaine ne dépend d'aucun SDK).
///
/// **Désérialisation défensive (invariant
/// [AD-10](../../../../../docs/site/concepts/invariants.md#ad-10))** :
/// [fromMapSafe] ne throw jamais. Coordonnée absente, non numérique, non finie
/// (NaN/Inf) ou hors-bornes (lat ∉ [-90,90], lng ∉ [-180,180]) → `null` (état
/// neutre).
///
/// **Compatibilité de lecture avec un format hérité** : [fromMapSafe] accepte
/// aussi (a) une chaîne JSON encodée (enveloppe historique décodée
/// défensivement), (b) les clés `latitude`/`longitude` quand `lat`/`lng` sont
/// absentes, (c) une forme historique typée `point`
/// (`{type: 'point', points: [{lat,lng}], label}` → `points[0]` + `label`).
/// Lecture seulement : [toMap] écrit toujours le format zcrud. Détails de
/// correspondance champ à champ : `doc/migration-legacy-dodlp-geo.md`.
///
/// Le point porte un [style] de rendu nullable ([ZGeoShapeStyle]) — `null`
/// signifie un rendu inchangé, dérivé du thème injecté.
library;

import 'dart:math' as math;

import 'z_geo_legacy_codec.dart';
import 'z_geo_shape_style.dart';

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
    this.style,
  });

  /// Latitude en degrés décimaux (plage valide [-90, 90]).
  final double lat;

  /// Longitude en degrés décimaux (plage valide [-180, 180]).
  final double lng;

  /// Libellé lisible optionnel (ex. nom du lieu).
  final String? label;

  /// Adresse postale optionnelle (texte libre).
  final String? address;

  /// Style de rendu neutre optionnel. `null` ⇒ rendu inchangé : l'adaptateur
  /// retombe sur le thème injecté.
  final ZGeoShapeStyle? style;

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

  /// Rayon terrestre moyen en mètres, utilisé par [distanceMetersTo] et par
  /// les calculs de métriques ([ZGeoShapeMetrics], [ZGeoCircleMetrics]).
  static const double earthRadiusMeters = 6371000;

  /// Distance **haversine** en mètres vers [other]. Pur-Dart, aucun SDK. Sert
  /// notamment au cercle « deux taps » (rayon = distance centre→second tap)
  /// et aux poignées de rayon des adaptateurs.
  double distanceMetersTo(ZGeoPoint other) {
    final double lat1 = lat * math.pi / 180;
    final double lat2 = other.lat * math.pi / 180;
    final double dLat = (other.lat - lat) * math.pi / 180;
    final double dLon = (other.lng - lng) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

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
        if (style != null) 'style': style!.toMap(),
      };

  /// Parse **défensif** : retourne `null` sans jamais throw si [raw] n'est
  /// pas une `Map` (ou une `String` JSON encodée en contenant une), si
  /// lat/lng sont absents/non numériques/non finis, ou hors-bornes.
  /// `label`/`address` non-`String` → ignorés (dégradés à `null`).
  ///
  /// Alias de lecture compatibilité — la lecture stricte prime toujours :
  /// `latitude`/`longitude` ne sont consultées que si `lat`/`lng` manquent ;
  /// une forme historique `{type:'point', points:[…]}` n'est routée que si
  /// aucune coordonnée directe n'est présente ET que `type == 'point'` (un
  /// `type` non-point n'est pas un point : `null`, jamais `points[0]` volé à
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
      // G9 : style optionnel (zcrud comme legacy) ; corrompu → null (AD-10).
      style: ZGeoShapeStyle.fromMapSafe(decoded['style']),
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
    var first = fromMapSafe(points.first);
    if (first == null) return null;
    final label = map['label'];
    if (first.label == null && label is String) {
      first = first.copyWith(label: label);
    }
    // G9 : le style legacy est porté par la FORME (`{type:'point', style:…}`),
    // pas par l'entrée de `points` — le reprendre s'il manque au point.
    final style = ZGeoShapeStyle.fromMapSafe(map['style']);
    if (first.style == null && style != null) {
      first = first.copyWith(style: style);
    }
    return first;
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

  /// Copie avec substitutions. `label`/`address`/`style` ne peuvent pas être
  /// remis à `null` via cette API (sémantique de copie partielle).
  ZGeoPoint copyWith({
    double? lat,
    double? lng,
    String? label,
    String? address,
    ZGeoShapeStyle? style,
  }) =>
      ZGeoPoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        label: label ?? this.label,
        address: address ?? this.address,
        style: style ?? this.style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoPoint &&
          other.lat == lat &&
          other.lng == lng &&
          other.label == label &&
          other.address == address &&
          other.style == style;

  @override
  int get hashCode => Object.hash(lat, lng, label, address, style);

  @override
  String toString() =>
      'ZGeoPoint(lat: $lat, lng: $lng, label: $label, address: $address)';
}
