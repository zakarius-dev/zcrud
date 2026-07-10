/// `ZGeoShape` — **aire/polygone géographique neutre** (E11a-1, AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du champ `geoArea` du `ZFormController`. Aire =
/// suite ordonnée de [ZGeoPoint] (`vertices`). Un **point unique** est un cas
/// dégénéré exploitable (1 sommet). Modèle **pur-Dart**, agnostique SDK carte.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` →
/// `null`. Un sommet invalide (absent/non numérique/hors-bornes) est **ignoré**
/// (jamais fatal) : une aire dont tous les sommets sont invalides devient une
/// aire **vide** (état neutre), pas `null`.
library;

import 'z_geo_point.dart';

/// Aire géographique neutre : liste ordonnée de sommets + libellé optionnel.
class ZGeoShape {
  /// Construit une aire à partir de [vertices] (copie **non modifiable**) et
  /// d'un [label] optionnel.
  ZGeoShape({
    List<ZGeoPoint> vertices = const <ZGeoPoint>[],
    this.label,
  }) : vertices = List<ZGeoPoint>.unmodifiable(vertices);

  /// Sommets ordonnés de l'aire (liste non modifiable ; peut être vide).
  final List<ZGeoPoint> vertices;

  /// Libellé lisible optionnel de l'aire.
  final String? label;

  /// `true` si l'aire n'a aucun sommet (état neutre).
  bool get isEmpty => vertices.isEmpty;

  /// `true` si l'aire a au moins un sommet.
  bool get isNotEmpty => vertices.isNotEmpty;

  /// Sérialise en `Map` neutre. Chaque sommet via [ZGeoPoint.toMap] ; `label`
  /// `null` omis.
  Map<String, Object?> toMap() => <String, Object?>{
        'vertices':
            vertices.map((ZGeoPoint v) => v.toMap()).toList(growable: false),
        if (label != null) 'label': label,
      };

  /// Parse **défensif** (AD-10) : `null` si [raw] n'est pas une `Map`. Sinon,
  /// chaque entrée de `vertices` est parsée par [ZGeoPoint.fromMapSafe] ; les
  /// sommets invalides sont **ignorés** (jamais throw). `label` non-`String` →
  /// `null`.
  static ZGeoShape? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    final rawVertices = raw['vertices'];
    final parsed = <ZGeoPoint>[];
    if (rawVertices is List) {
      for (final Object? entry in rawVertices) {
        final point = ZGeoPoint.fromMapSafe(entry);
        if (point != null) parsed.add(point); // sommet invalide ignoré (AD-10)
      }
    }
    final label = raw['label'];
    return ZGeoShape(
      vertices: parsed,
      label: label is String ? label : null,
    );
  }

  /// Alias défensif de [fromMapSafe] (nullable) — cohérence `toMap`/`fromMap`.
  static ZGeoShape? fromMap(Object? raw) => fromMapSafe(raw);

  /// Retourne une copie avec [point] ajouté en fin de liste.
  ZGeoShape addVertex(ZGeoPoint point) => ZGeoShape(
        vertices: <ZGeoPoint>[...vertices, point],
        label: label,
      );

  /// Copie avec substitutions.
  ZGeoShape copyWith({List<ZGeoPoint>? vertices, String? label}) => ZGeoShape(
        vertices: vertices ?? this.vertices,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoShape &&
          other.label == label &&
          _listEquals(other.vertices, vertices);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(vertices));

  static bool _listEquals(List<ZGeoPoint> a, List<ZGeoPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ZGeoShape(vertices: ${vertices.length}, label: $label)';
}
