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
///
/// **Lecture legacy DODLP (G1)** : [fromMapSafe] accepte aussi (a) une
/// **chaîne JSON** (enveloppe legacy, décodée défensivement), (b) le cercle
/// legacy `{type:'circle', points:[centre], radius}` — alias de LECTURE
/// `radius` → `radius_m` (quand `radius_m` est absente) et centre repris de
/// `points[0]` (quand `center` est absente). LECTURE seulement : [toMap] est
/// strictement inchangé (`center`/`radius_m`).
///
/// **G9 (additif, AD-4)** : le cercle porte un [style] de rendu **nullable**
/// ([ZGeoShapeStyle]) — `null` ⇒ comportement/rendu strictement inchangés.
/// [fromMapSafe] lit la clé `style` (zcrud comme legacy) ; [toMap] ne l'émet
/// que non-`null` (schéma additif).
library;

import 'z_geo_legacy_codec.dart';
import 'z_geo_point.dart';
import 'z_geo_shape_style.dart';

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
    this.style,
  });

  /// Centre du cercle (point neutre).
  final ZGeoPoint center;

  /// Rayon en mètres (valide si fini et strictement positif).
  final double radiusMeters;

  /// Libellé lisible optionnel.
  final String? label;

  /// Style de rendu neutre optionnel (G9, additif — `null` ⇒ rendu inchangé :
  /// l'adaptateur retombe sur le thème injecté, FR-26).
  final ZGeoShapeStyle? style;

  /// `true` si le [center] est dans les bornes ET le rayon est fini > 0.
  bool get isValid =>
      center.isValid && radiusMeters.isFinite && radiusMeters > 0;

  /// Sérialise en `Map` neutre (persistance snake_case : `center`/`radius_m`/
  /// `label`). Le `label` `null` est omis.
  Map<String, Object?> toMap() => <String, Object?>{
        'center': center.toMap(),
        'radius_m': radiusMeters,
        if (label != null) 'label': label,
        if (style != null) 'style': style!.toMap(),
      };

  /// Parse **défensif** (AD-10) : retourne `null` sans jamais throw si [raw]
  /// n'est pas une `Map`, si le centre est absent/invalide, ou si le rayon est
  /// absent/non numérique/non fini/≤0. `label` non-`String` → `null`.
  static ZGeoCircle? fromMapSafe(Object? raw) {
    final decoded = zGeoDecodeLegacyEnvelope(raw);
    if (decoded is! Map) return null;
    // Centre : clé zcrud `center` d'abord ; repli legacy `points[0]` UNIQUEMENT
    // quand `center` est absente (un `center` présent-mais-corrompu reste
    // `null` comme avant — la lecture élargie ne secourt pas la stricte).
    var center = ZGeoPoint.fromMapSafe(decoded['center']);
    if (center == null && decoded['center'] == null) {
      final points = decoded['points'];
      if (points is List && points.isNotEmpty) {
        center = ZGeoPoint.fromMapSafe(points.first);
      }
    }
    if (center == null) return null;
    // Rayon : clé zcrud `radius_m` d'abord ; alias de LECTURE legacy `radius`
    // uniquement quand `radius_m` est absente (même règle de non-secours).
    final rawRadius = decoded['radius_m'] ?? decoded['radius'];
    final radius = _asPositiveFiniteDouble(rawRadius);
    if (radius == null) return null;
    final label = decoded['label'];
    return ZGeoCircle(
      center: center,
      radiusMeters: radius,
      label: label is String ? label : null,
      // G9 : style optionnel (zcrud comme legacy) ; corrompu → null (AD-10).
      style: ZGeoShapeStyle.fromMapSafe(decoded['style']),
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

  /// Copie avec substitutions. `label`/`style` ne peuvent pas être remis à
  /// `null` via cette API (sémantique de copie partielle).
  ZGeoCircle copyWith({
    ZGeoPoint? center,
    double? radiusMeters,
    String? label,
    ZGeoShapeStyle? style,
  }) =>
      ZGeoCircle(
        center: center ?? this.center,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        label: label ?? this.label,
        style: style ?? this.style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoCircle &&
          other.center == center &&
          other.radiusMeters == radiusMeters &&
          other.label == label &&
          other.style == style;

  @override
  int get hashCode => Object.hash(center, radiusMeters, label, style);

  @override
  String toString() =>
      'ZGeoCircle(center: $center, radiusMeters: $radiusMeters, label: $label)';
}
