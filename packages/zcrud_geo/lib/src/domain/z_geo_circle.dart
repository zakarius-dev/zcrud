/// `ZGeoCircle` — **cercle géographique neutre** (E11b-1, AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche d'un champ géo en géométrie `circle`
/// ([ZGeoGeometry.circle], portée par `ZGeoFieldConfig`). Un cercle = un
/// [ZGeoPoint] `center` + un `radiusMeters` (rayon en mètres). Modèle
/// **pur-Dart** : aucun Flutter, aucun SDK carte (pas de `Circle`/`LatLng`) — la
/// conversion vers/depuis un type SDK vit EXCLUSIVEMENT dans l'adaptateur carte
/// concret (`src/presentation/adapters/`), jamais ici (AD-1).
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. Centre
/// absent/invalide, rayon absent/non numérique/non fini (NaN/Inf)/≤0 → `null`
/// (état neutre). L'évolution de schéma reste additive.
library;

import 'z_geo_point.dart';

/// Cercle géographique neutre : centre ([ZGeoPoint]) + rayon en mètres.
class ZGeoCircle {
  /// Construit un cercle de [center] et [radiusMeters] (mètres) + [label]
  /// optionnel. Aucune validation dure (pas d'`assert`) : la validité est
  /// vérifiée au **parse** défensif ([fromMapSafe]) et via [isValid] — un cercle
  /// construit programmatiquement reste sous la responsabilité de l'appelant.
  const ZGeoCircle({
    required this.center,
    required this.radiusMeters,
    this.label,
  });

  /// Centre du cercle (point neutre).
  final ZGeoPoint center;

  /// Rayon en mètres (valide si fini et strictement positif).
  final double radiusMeters;

  /// Libellé lisible optionnel.
  final String? label;

  /// `true` si le [center] est dans les bornes ET le rayon est fini > 0.
  bool get isValid =>
      center.isValid && radiusMeters.isFinite && radiusMeters > 0;

  /// Sérialise en `Map` neutre (persistance snake_case : `center`/`radius_m`/
  /// `label`). Le `label` `null` est omis.
  Map<String, Object?> toMap() => <String, Object?>{
        'center': center.toMap(),
        'radius_m': radiusMeters,
        if (label != null) 'label': label,
      };

  /// Parse **défensif** (AD-10) : retourne `null` sans jamais throw si [raw]
  /// n'est pas une `Map`, si le centre est absent/invalide, ou si le rayon est
  /// absent/non numérique/non fini/≤0. `label` non-`String` → `null`.
  static ZGeoCircle? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    final center = ZGeoPoint.fromMapSafe(raw['center']);
    if (center == null) return null;
    final radius = _asPositiveFiniteDouble(raw['radius_m']);
    if (radius == null) return null;
    final label = raw['label'];
    return ZGeoCircle(
      center: center,
      radiusMeters: radius,
      label: label is String ? label : null,
    );
  }

  /// Alias défensif de [fromMapSafe] (nullable) — cohérence `toMap`/`fromMap`.
  /// Ne throw jamais (AD-10).
  static ZGeoCircle? fromMap(Object? raw) => fromMapSafe(raw);

  /// Convertit `num`/`String` en `double` **fini strictement positif**, sinon
  /// `null` (défensif : NaN/Inf/0/négatif rejetés).
  static double? _asPositiveFiniteDouble(Object? v) {
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim());
    }
    if (d == null || !d.isFinite || d <= 0) return null;
    return d;
  }

  /// Copie avec substitutions. `label` ne peut pas être remis à `null` via cette
  /// API (sémantique de copie partielle).
  ZGeoCircle copyWith({
    ZGeoPoint? center,
    double? radiusMeters,
    String? label,
  }) =>
      ZGeoCircle(
        center: center ?? this.center,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoCircle &&
          other.center == center &&
          other.radiusMeters == radiusMeters &&
          other.label == label;

  @override
  int get hashCode => Object.hash(center, radiusMeters, label);

  @override
  String toString() =>
      'ZGeoCircle(center: $center, radiusMeters: $radiusMeters, label: $label)';
}
