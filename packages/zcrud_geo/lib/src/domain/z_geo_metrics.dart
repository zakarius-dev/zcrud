/// Métriques géo **pures** (G12 + « point-dans-zone » §2, AD-1/AD-14/AD-10) —
/// aire, périmètre, boîte englobante, centroïde, appartenance d'un point.
///
/// ## Nature des formules (mesurée sur le legacy, pas crue)
///
/// Reproduction **à l'identique** des formules du legacy DODLP
/// (`data_crud/models/geo_shape.dart`, `gs:398-577`) :
///
/// - **Aire de polygone (`gs:504-522`)** : approximation **SPHÉRIQUE** (excès
///   sphérique simplifié, type Chamberlain–Duquette) —
///   `Σ dLng·(2 + sin φ1 + sin φ2) · R²/2`, valeur absolue, avec
///   `R = 6371000 m` ([ZGeoPoint.earthRadiusMeters]). Ce n'est NI une aire
///   planaire NI une aire ellipsoïdale (WGS-84) : précision excellente pour des
///   emprises locales (ports, zones de contrôle), divergence croissante sur des
///   polygones continentaux. **Les trous ne sont PAS déduits** (parité stricte :
///   le legacy ignore `holes` dans `area`) — écart documenté, pas un oubli.
/// - **Aire de cercle (`gs:424-426`)** : **PLANAIRE** — `π·r²` (le legacy ne
///   projette pas le disque sur la sphère).
/// - **Périmètre (`gs:524-533`)** : somme de distances **haversine** (sphère
///   `R = 6371000 m`), **segment de fermeture inclus** (polygone fermé).
///   Pour un tracé OUVERT (polyligne), utiliser [ZGeoShapeMetrics.lengthMeters]
///   (parité `gs:535-541` : pas de segment de fermeture).
/// - **Bounds (`gs:469-498`)** : min/max lat/lng des sommets ; le cercle étend
///   sa boîte de `radius × (1/111320) °/m` (approximation legacy `gs:486`,
///   volontairement grossière en longitude — parité, documentée).
/// - **Centroïde (`gs:405-415`)** : moyenne arithmétique des sommets.
///
/// ## Point-dans-zone (enrichissement §2 — aucune des deux implémentations)
///
/// [ZGeoShapeMetrics.containsPoint] : **ray casting** (parité d'algorithme
/// classique pair-impair) sur les coordonnées lat/lng traitées en plan local —
/// adapté aux zones métier locales (même domaine de validité que l'aire
/// sphérique ci-dessus ; non valable pour un polygone enjambant l'antiméridien,
/// écart documenté). **Les trous sont gérés** : un point dans un trou (≥3
/// sommets) n'appartient PAS à la zone. **Frontière INCLUSIVE et
/// déterministe** : un point exactement sur un sommet ou une arête (au bord
/// extérieur COMME au bord d'un trou) appartient à la zone — le ray casting nu
/// est ambigu sur la frontière, un test d'appartenance au segment (ε 1e-12) le
/// tranche AVANT le lancer de rayon.
///
/// [ZGeoCircleMetrics.containsPoint] : distance **haversine** centre→point
/// ≤ rayon (frontière inclusive, cohérente avec la forme).
///
/// **Défensif (AD-10)** : jamais de throw ; entrée dégénérée (< 3 sommets pour
/// une aire, forme vide, rayon invalide) → `null`/`false`, jamais NaN propagé.
///
/// **Pur-Dart (AD-14)** : aucun Flutter, aucun SDK carte.
library;

import 'dart:math' as math;

import 'z_geo_circle.dart';
import 'z_geo_point.dart';
import 'z_geo_shape.dart';

/// Boîte englobante géographique neutre (coins SW/NE) — résultat de `bounds`
/// (parité legacy `gs:469-498`, qui rend `[southwest, northeast]`).
class ZGeoBounds {
  /// Construit la boîte `const` à partir de ses coins.
  const ZGeoBounds({required this.southWest, required this.northEast});

  /// Coin sud-ouest (lat min, lng min).
  final ZGeoPoint southWest;

  /// Coin nord-est (lat max, lng max).
  final ZGeoPoint northEast;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoBounds &&
          other.southWest == southWest &&
          other.northEast == northEast;

  @override
  int get hashCode => Object.hash(southWest, northEast);

  @override
  String toString() => 'ZGeoBounds(sw: $southWest, ne: $northEast)';
}

/// Degrés par mètre approximatifs (expansion des bounds d'un cercle — parité
/// legacy `gs:486`, `degPerMeter = 1 / 111320.0`, « Rough approximation »).
const double _kDegreesPerMeter = 1 / 111320.0;

/// Tolérance du test « point sur segment » (frontière inclusive documentée).
const double _kOnSegmentEpsilon = 1e-12;

double _deg2rad(double deg) => deg * math.pi / 180;

/// Aire sphérique d'un anneau (parité stricte `gs:504-522`) : `< 3` sommets →
/// `0` (comme le legacy).
double _ringAreaSquareMeters(List<ZGeoPoint> ring) {
  if (ring.length < 3) return 0;
  double total = 0;
  final int n = ring.length;
  for (int i = 0; i < n; i++) {
    final ZGeoPoint p1 = ring[i];
    final ZGeoPoint p2 = ring[(i + 1) % n];
    total += _deg2rad(p2.lng - p1.lng) *
        (2 + math.sin(_deg2rad(p1.lat)) + math.sin(_deg2rad(p2.lat)));
  }
  return (total *
          ZGeoPoint.earthRadiusMeters *
          ZGeoPoint.earthRadiusMeters /
          2)
      .abs();
}

/// `true` si [p] est à l'intérieur (pair-impair) OU sur la frontière de [ring].
/// Ray casting horizontal classique ; la frontière est tranchée AVANT par un
/// test d'appartenance au segment (déterminisme documenté).
bool _ringContains(List<ZGeoPoint> ring, ZGeoPoint p) {
  final int n = ring.length;
  if (n < 3) return false;
  // 1. Frontière inclusive : sommet exact ou point sur une arête → dedans.
  for (int i = 0; i < n; i++) {
    if (_onSegment(ring[i], ring[(i + 1) % n], p)) return true;
  }
  // 2. Ray casting pair-impair (rayon horizontal vers +lng).
  bool inside = false;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final ZGeoPoint a = ring[i];
    final ZGeoPoint b = ring[j];
    final bool crosses = (a.lat > p.lat) != (b.lat > p.lat);
    if (crosses) {
      final double xIntersect =
          (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng;
      if (p.lng < xIntersect) inside = !inside;
    }
  }
  return inside;
}

/// `true` si [p] appartient au segment [a]→[b] (colinéarité + boîte, ε 1e-12).
bool _onSegment(ZGeoPoint a, ZGeoPoint b, ZGeoPoint p) {
  final double cross =
      (b.lng - a.lng) * (p.lat - a.lat) - (b.lat - a.lat) * (p.lng - a.lng);
  if (cross.abs() > _kOnSegmentEpsilon) return false;
  final bool withinLat = p.lat >= math.min(a.lat, b.lat) - _kOnSegmentEpsilon &&
      p.lat <= math.max(a.lat, b.lat) + _kOnSegmentEpsilon;
  final bool withinLng = p.lng >= math.min(a.lng, b.lng) - _kOnSegmentEpsilon &&
      p.lng <= math.max(a.lng, b.lng) + _kOnSegmentEpsilon;
  return withinLat && withinLng;
}

/// Métriques pures d'une [ZGeoShape] (G12 + §2 — parité formules `gs:398-577`).
extension ZGeoShapeMetrics on ZGeoShape {
  /// Aire **sphérique approchée** en m² (excès sphérique simplifié, parité
  /// stricte `gs:504-522` — cf. doc de bibliothèque : les trous ne sont PAS
  /// déduits, comme le legacy). `< 3` sommets → `null` (pas d'aire).
  double? get areaSquareMeters =>
      vertices.length < 3 ? null : _ringAreaSquareMeters(vertices);

  /// Périmètre **fermé** en mètres (haversine, segment de fermeture inclus —
  /// parité `gs:524-533`). `< 2` sommets → `null`.
  double? get perimeterMeters {
    if (vertices.length < 2) return null;
    double total = 0;
    final int n = vertices.length;
    for (int i = 0; i < n; i++) {
      total += vertices[i].distanceMetersTo(vertices[(i + 1) % n]);
    }
    return total;
  }

  /// Longueur **ouverte** en mètres (polyligne : haversine SANS segment de
  /// fermeture — parité `gs:535-541`). `< 2` sommets → `null`.
  double? get lengthMeters {
    if (vertices.length < 2) return null;
    double total = 0;
    for (int i = 0; i < vertices.length - 1; i++) {
      total += vertices[i].distanceMetersTo(vertices[i + 1]);
    }
    return total;
  }

  /// Boîte englobante des sommets (parité `gs:469-483`). Forme vide → `null`.
  ZGeoBounds? get bounds {
    if (vertices.isEmpty) return null;
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;
    for (final ZGeoPoint v in vertices) {
      if (v.lat < minLat) minLat = v.lat;
      if (v.lat > maxLat) maxLat = v.lat;
      if (v.lng < minLng) minLng = v.lng;
      if (v.lng > maxLng) maxLng = v.lng;
    }
    return ZGeoBounds(
      southWest: ZGeoPoint(lat: minLat, lng: minLng),
      northEast: ZGeoPoint(lat: maxLat, lng: maxLng),
    );
  }

  /// Centroïde (moyenne arithmétique des sommets — parité `gs:405-415`).
  /// Forme vide → `null`.
  ZGeoPoint? get centroid {
    if (vertices.isEmpty) return null;
    double lat = 0, lng = 0;
    for (final ZGeoPoint v in vertices) {
      lat += v.lat;
      lng += v.lng;
    }
    return ZGeoPoint(lat: lat / vertices.length, lng: lng / vertices.length);
  }

  /// **Point-dans-zone** (ray casting pair-impair, frontière INCLUSIVE —
  /// cf. doc de bibliothèque). Gère les **trous** (un point dans un trou de ≥3
  /// sommets n'appartient pas à la zone, SAUF s'il est exactement sur le bord
  /// du trou — frontière inclusive partout). `< 3` sommets → `false` (AD-10).
  bool containsPoint(ZGeoPoint point) {
    if (!point.isValid || vertices.length < 3) return false;
    if (!_ringContains(vertices, point)) return false;
    final List<List<ZGeoPoint>>? h = holes;
    if (h != null) {
      for (final List<ZGeoPoint> hole in h) {
        if (hole.length < 3) continue; // trou dégénéré ignoré (AD-10)
        // Bord du trou = frontière de la zone → inclusif (appartient).
        bool onHoleEdge = false;
        for (int i = 0; i < hole.length; i++) {
          if (_onSegment(hole[i], hole[(i + 1) % hole.length], point)) {
            onHoleEdge = true;
            break;
          }
        }
        if (onHoleEdge) continue;
        if (_ringContains(hole, point)) return false; // dans le trou → dehors
      }
    }
    return true;
  }

  /// G16 — réordonne les sommets **par angle autour du centroïde** pour
  /// prévenir l'auto-intersection (parité stricte `gff:922-959`,
  /// `_optimizePolygon` : tri par `atan2(lat - centreLat, lng - centreLng)`).
  /// `< 3` sommets → forme inchangée (parité du garde legacy `gff:923`).
  /// Attributs (id/label/style/holes/metadata) préservés.
  ZGeoShape sortedByAngleAroundCentroid() {
    if (vertices.length < 3) return this;
    final ZGeoPoint c = centroid!;
    final List<ZGeoPoint> sorted = <ZGeoPoint>[...vertices]..sort(
        (ZGeoPoint a, ZGeoPoint b) {
          final double angleA = math.atan2(a.lat - c.lat, a.lng - c.lng);
          final double angleB = math.atan2(b.lat - c.lat, b.lng - c.lng);
          return angleA.compareTo(angleB);
        },
      );
    return copyWith(vertices: sorted);
  }
}

/// Métriques pures d'un [ZGeoCircle] (G12 — parité formules legacy).
extension ZGeoCircleMetrics on ZGeoCircle {
  /// Aire **planaire** `π·r²` (parité stricte `gs:424-426` — le legacy ne
  /// projette pas le disque sur la sphère). Cercle invalide → `null`.
  double? get areaSquareMeters =>
      isValid ? math.pi * radiusMeters * radiusMeters : null;

  /// Circonférence `2·π·r` (parité `gs:439-441`). Cercle invalide → `null`.
  double? get perimeterMeters => isValid ? 2 * math.pi * radiusMeters : null;

  /// Boîte englobante : centre ± `radius × (1/111320) °/m` (approximation
  /// legacy `gs:485-492`, volontairement grossière en longitude — parité
  /// documentée). Cercle invalide → `null`. Les bornes sont ÉCRÊTÉES aux
  /// limites géographiques (AD-10 : jamais un coin hors-bornes).
  ZGeoBounds? get bounds {
    if (!isValid) return null;
    final double radiusDeg = radiusMeters * _kDegreesPerMeter;
    return ZGeoBounds(
      southWest: ZGeoPoint(
        lat: (center.lat - radiusDeg).clamp(ZGeoPoint.minLat, ZGeoPoint.maxLat),
        lng: (center.lng - radiusDeg).clamp(ZGeoPoint.minLng, ZGeoPoint.maxLng),
      ),
      northEast: ZGeoPoint(
        lat: (center.lat + radiusDeg).clamp(ZGeoPoint.minLat, ZGeoPoint.maxLat),
        lng: (center.lng + radiusDeg).clamp(ZGeoPoint.minLng, ZGeoPoint.maxLng),
      ),
    );
  }

  /// **Point-dans-zone** : distance haversine centre→[point] ≤ rayon
  /// (frontière inclusive). Cercle ou point invalide → `false` (AD-10).
  bool containsPoint(ZGeoPoint point) {
    if (!isValid || !point.isValid) return false;
    return center.distanceMetersTo(point) <= radiusMeters;
  }
}
