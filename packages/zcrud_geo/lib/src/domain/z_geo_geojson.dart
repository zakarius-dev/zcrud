/// Import/export **GeoJSON** (RFC 7946) des valeurs géo neutres
/// (enrichissement §2 « valeur haute / coût faible », AD-1/AD-10/AD-14).
///
/// ## Périmètre mesuré (pas cru)
///
/// Le legacy DODLP n'a **AUCUN** code GeoJSON : grep négatif rejoué sur tout
/// `data_crud/` (`grep -rn -i "geojson\|kml"` → 0 occurrence géo ; les boutons
/// ↑/↓ visibles sur la capture device ne correspondent à aucun code source
/// mesurable dans `geofence_field.dart`). Il n'y a donc **rien à copier au
/// niveau champ** : cette bibliothèque expose l'**API seulement** (`toGeoJson`
/// / [ZGeoJson.fromGeoJsonSafe]) — l'app hôte branche ses propres boutons
/// (file picker / partage) sur ces fonctions pures.
///
/// ## ⚠️ Ordre des coordonnées (piège classique, gardé spécifiquement)
///
/// RFC 7946 §3.1.1 : une position GeoJSON est **`[longitude, latitude]`** —
/// l'INVERSE de l'ordre d'affichage courant « lat, lng » et des clés
/// `lat`/`lng` de [ZGeoPoint]. Toute lecture/écriture de ce fichier passe par
/// [_position]/[_positionOf] pour qu'il n'existe qu'UN site d'inversion.
///
/// ## Correspondances
///
/// | zcrud | GeoJSON |
/// |---|---|
/// | [ZGeoPoint] | `Point` |
/// | [ZGeoShape] (polygone) | `Polygon` (anneau extérieur + trous, anneaux **fermés** : 1er = dernier) |
/// | [ZGeoShape] (polyligne, `asLineString: true`) | `LineString` |
/// | [ZGeoCircle] | **hors RFC 7946** (aucun type cercle) → `Feature` `Point` + `properties.radius_m` (convention documentée, relue par l'import) |
///
/// L'import accepte aussi `Feature` (géométrie extraite ; `radius_m`/`radius`
/// numérique sur un `Point` → [ZGeoCircle]) et `FeatureCollection`
/// (**première** feature exploitable — écart documenté : les valeurs zcrud
/// sont mono-forme). `MultiPolygon`/`MultiPoint`/etc. → `null` (non portés par
/// le modèle de valeur, évolution additive possible).
///
/// **Défensif (AD-10)** : [ZGeoJson.fromGeoJsonSafe] ne **throw jamais** —
/// JSON invalide, type inconnu, coordonnées hors-bornes/non numériques →
/// `null` (une position invalide d'un anneau est ignorée, comme les sommets
/// corrompus de `ZGeoShape.fromMapSafe`).
///
/// **Pur-Dart (AD-14)** : `dart:convert` uniquement.
library;

import 'dart:convert';

import 'z_geo_circle.dart';
import 'z_geo_point.dart';
import 'z_geo_shape.dart';

/// Position GeoJSON `[lng, lat]` d'un point neutre (UNIQUE site d'inversion).
List<double> _position(ZGeoPoint p) => <double>[p.lng, p.lat];

/// Point neutre depuis une position GeoJSON `[lng, lat]` (UNIQUE site
/// d'inversion en lecture). Invalide/hors-bornes → `null` (AD-10).
ZGeoPoint? _positionOf(Object? raw) {
  if (raw is! List || raw.length < 2) return null;
  final Object? lng = raw[0];
  final Object? lat = raw[1];
  if (lng is! num || lat is! num) return null;
  final ZGeoPoint p = ZGeoPoint(lat: lat.toDouble(), lng: lng.toDouble());
  return p.isValid ? p : null;
}

/// Anneau GeoJSON **fermé** (1er = dernier — RFC 7946 §3.1.6) depuis des
/// sommets zcrud (non fermés).
List<List<double>> _closedRing(List<ZGeoPoint> vertices) => <List<double>>[
      for (final ZGeoPoint v in vertices) _position(v),
      if (vertices.isNotEmpty) _position(vertices.first),
    ];

/// Sommets zcrud depuis un anneau GeoJSON : positions invalides ignorées
/// (AD-10), position de fermeture (1re == dernière) retirée.
List<ZGeoPoint> _ringVertices(Object? raw) {
  final List<ZGeoPoint> out = <ZGeoPoint>[];
  if (raw is List) {
    for (final Object? entry in raw) {
      final ZGeoPoint? p = _positionOf(entry);
      if (p != null) out.add(p);
    }
  }
  if (out.length >= 2 &&
      out.first.lat == out.last.lat &&
      out.first.lng == out.last.lng) {
    out.removeLast(); // fermeture RFC retirée (zcrud ne duplique pas)
  }
  return out;
}

/// Export GeoJSON d'un [ZGeoPoint] (`Point`, position `[lng, lat]`).
extension ZGeoPointGeoJson on ZGeoPoint {
  /// Géométrie GeoJSON `Point` (RFC 7946). Les métadonnées zcrud
  /// (`label`/`address`/`style`) ne font pas partie de la géométrie et ne sont
  /// pas exportées (une `Feature` hôte peut les porter en `properties`).
  Map<String, Object?> toGeoJson() => <String, Object?>{
        'type': 'Point',
        'coordinates': _position(this),
      };
}

/// Export GeoJSON d'une [ZGeoShape] (`Polygon` fermé + trous, ou `LineString`).
extension ZGeoShapeGeoJson on ZGeoShape {
  /// Géométrie GeoJSON. Par défaut `Polygon` : anneau extérieur **fermé**
  /// (1er = dernier) + trous de ≥3 sommets (chacun fermé). [asLineString] :
  /// `true` → `LineString` (tracé ouvert — la forme zcrud ne porte pas
  /// l'ouverture, c'est la géométrie du champ qui la connaît, DP-21).
  Map<String, Object?> toGeoJson({bool asLineString = false}) {
    if (asLineString) {
      return <String, Object?>{
        'type': 'LineString',
        'coordinates': <List<double>>[
          for (final ZGeoPoint v in vertices) _position(v),
        ],
      };
    }
    return <String, Object?>{
      'type': 'Polygon',
      'coordinates': <List<List<double>>>[
        _closedRing(vertices),
        if (holes != null)
          for (final List<ZGeoPoint> hole in holes!)
            if (hole.length >= 3) _closedRing(hole),
      ],
    };
  }
}

/// Export GeoJSON d'un [ZGeoCircle] — **convention documentée** (RFC 7946 n'a
/// aucun type cercle) : `Feature` portant un `Point` + `properties.radius_m`.
extension ZGeoCircleGeoJson on ZGeoCircle {
  /// `Feature{geometry: Point(centre), properties: {radius_m}}` — relu par
  /// [ZGeoJson.fromGeoJsonSafe] (aller-retour sans perte de rayon).
  Map<String, Object?> toGeoJson() => <String, Object?>{
        'type': 'Feature',
        'geometry': center.toGeoJson(),
        'properties': <String, Object?>{'radius_m': radiusMeters},
      };
}

/// Import GeoJSON **défensif et discriminé** (pendant RFC du routeur legacy
/// `ZGeoValue.fromMapSafe`). Espace de noms statique : non instanciable.
abstract final class ZGeoJson {
  /// Parse un GeoJSON (`Map`, ou `String` JSON) en valeur zcrud neutre :
  /// [ZGeoPoint] (`Point`), [ZGeoShape] (`Polygon`/`LineString`), [ZGeoCircle]
  /// (`Feature` `Point` + `radius_m`/`radius` numérique — convention d'export).
  /// `Feature` → géométrie extraite ; `FeatureCollection` → première feature
  /// exploitable. Invalide/type non porté → `null`, **jamais de throw**
  /// (AD-10). Résultat typé `Object?` (les trois types n'ont pas d'ancêtre
  /// commun) — se consomme par `switch`/`is`, comme `ZGeoValue.fromMapSafe`.
  static Object? fromGeoJsonSafe(Object? raw) {
    Object? decoded = raw;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null; // JSON invalide → null (AD-10)
      }
    }
    if (decoded is! Map) return null;
    switch (decoded['type']) {
      case 'Point':
        return _positionOf(decoded['coordinates']);
      case 'LineString':
        final List<ZGeoPoint> vertices = <ZGeoPoint>[];
        final Object? coords = decoded['coordinates'];
        if (coords is List) {
          for (final Object? entry in coords) {
            final ZGeoPoint? p = _positionOf(entry);
            if (p != null) vertices.add(p);
          }
        }
        return vertices.isEmpty ? null : ZGeoShape(vertices: vertices);
      case 'Polygon':
        final Object? rings = decoded['coordinates'];
        if (rings is! List || rings.isEmpty) return null;
        final List<ZGeoPoint> outer = _ringVertices(rings.first);
        if (outer.isEmpty) return null;
        final List<List<ZGeoPoint>> holes = <List<ZGeoPoint>>[
          for (final Object? ring in rings.skip(1))
            if (_ringVertices(ring) case final List<ZGeoPoint> h
                when h.isNotEmpty)
              h,
        ];
        return ZGeoShape(
          vertices: outer,
          holes: holes.isEmpty ? null : holes,
        );
      case 'Feature':
        final Object? geometry = decoded['geometry'];
        final Object? value = fromGeoJsonSafe(geometry);
        // Convention cercle : Point + radius_m/radius numérique > 0.
        if (value is ZGeoPoint) {
          final Object? props = decoded['properties'];
          if (props is Map) {
            final Object? radius = props['radius_m'] ?? props['radius'];
            if (radius is num &&
                radius.toDouble().isFinite &&
                radius > 0) {
              return ZGeoCircle(
                center: value,
                radiusMeters: radius.toDouble(),
              );
            }
          }
        }
        return value;
      case 'FeatureCollection':
        final Object? features = decoded['features'];
        if (features is List) {
          for (final Object? feature in features) {
            final Object? value = fromGeoJsonSafe(feature);
            if (value != null) return value; // première exploitable
          }
        }
        return null;
    }
    return null; // type GeoJSON inconnu/non porté (MultiPolygon…) → null
  }
}
