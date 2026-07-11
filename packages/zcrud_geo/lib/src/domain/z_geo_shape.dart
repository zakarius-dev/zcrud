/// `ZGeoShape` — **aire/tracé géographique neutre** (E11a-1 + DP-21/M13,
/// AD-1/AD-14/AD-10).
///
/// origine: valeur de tranche du champ `geoArea` (polygone) ou d'un champ en
/// géométrie `polyline` (tracé ouvert) du `ZFormController`. Forme = suite
/// ordonnée de [ZGeoPoint] (`vertices`). Un **point unique** est un cas dégénéré
/// exploitable (1 sommet). Modèle **pur-Dart**, agnostique SDK carte.
///
/// **DP-21/M13 (additif rétro-compatible)** : la forme porte désormais, en plus
/// de `vertices`/`label`, des attributs **optionnels** neutres : [id] (identité
/// stable), [style] ([ZGeoShapeStyle], couleurs ARGB neutres — AUCUN `Color`
/// SDK), [holes] (trous intérieurs d'un polygone : liste de listes de sommets)
/// et [metadata] (`Map` libre). Une forme construite/sérialisée sans ces
/// attributs (E11a-1) reste **strictement inchangée** (toutes ces clés `null` →
/// omises du `Map`).
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` →
/// `null`. Un sommet invalide (absent/non numérique/hors-bornes) est **ignoré**
/// (jamais fatal) ; un trou corrompu voit ses sommets invalides filtrés (jamais
/// throw) ; un `style`/`metadata` corrompu retombe à `null`. Une aire dont tous
/// les sommets sont invalides devient une aire **vide** (état neutre), pas
/// `null`.
library;

import 'z_geo_point.dart';
import 'z_geo_shape_style.dart';

/// Forme géographique neutre : liste ordonnée de sommets + attributs optionnels
/// (id/label/style/holes/metadata).
class ZGeoShape {
  /// Construit une forme à partir de [vertices] (copie **non modifiable**) et
  /// d'attributs optionnels. [holes] est **profondément** copié en listes non
  /// modifiables (chaque trou est une liste ordonnée de sommets). [metadata]
  /// est copié en `Map` non modifiable.
  ZGeoShape({
    List<ZGeoPoint> vertices = const <ZGeoPoint>[],
    this.label,
    this.id,
    this.style,
    List<List<ZGeoPoint>>? holes,
    Map<String, Object?>? metadata,
  })  : vertices = List<ZGeoPoint>.unmodifiable(vertices),
        holes = holes == null
            ? null
            : List<List<ZGeoPoint>>.unmodifiable(
                holes.map((List<ZGeoPoint> h) =>
                    List<ZGeoPoint>.unmodifiable(h)),
              ),
        metadata = metadata == null
            ? null
            : Map<String, Object?>.unmodifiable(metadata);

  /// Sommets ordonnés de la forme (liste non modifiable ; peut être vide).
  final List<ZGeoPoint> vertices;

  /// Libellé lisible optionnel de la forme.
  final String? label;

  /// Identité stable optionnelle de la forme (DP-21 ; opaque, `String`).
  final String? id;

  /// Style de rendu neutre optionnel (DP-21 ; couleurs ARGB, aucun `Color` SDK).
  final ZGeoShapeStyle? style;

  /// Trous intérieurs optionnels d'un polygone (DP-21) : liste **non
  /// modifiable** de trous, chaque trou étant une liste ordonnée de sommets.
  /// `null` → aucun trou (rétro-compat stricte).
  final List<List<ZGeoPoint>>? holes;

  /// Métadonnées libres optionnelles (DP-21) : `Map` **non modifiable**. `null`
  /// → aucune métadonnée (rétro-compat stricte).
  final Map<String, Object?>? metadata;

  /// `true` si la forme n'a aucun sommet (état neutre).
  bool get isEmpty => vertices.isEmpty;

  /// `true` si la forme a au moins un sommet.
  bool get isNotEmpty => vertices.isNotEmpty;

  /// Sérialise en `Map` neutre. `vertices` via [ZGeoPoint.toMap] ; les attributs
  /// optionnels `null` sont **omis** (schéma additif : une forme E11a-1 sans
  /// id/style/holes/metadata produit exactement l'ancien `Map`).
  Map<String, Object?> toMap() => <String, Object?>{
        'vertices':
            vertices.map((ZGeoPoint v) => v.toMap()).toList(growable: false),
        if (label != null) 'label': label,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toMap(),
        if (holes != null)
          'holes': holes!
              .map((List<ZGeoPoint> h) =>
                  h.map((ZGeoPoint v) => v.toMap()).toList(growable: false))
              .toList(growable: false),
        if (metadata != null) 'metadata': metadata,
      };

  /// Parse **défensif** (AD-10) : `null` si [raw] n'est pas une `Map`. Sinon,
  /// chaque entrée de `vertices` est parsée par [ZGeoPoint.fromMapSafe] ; les
  /// sommets invalides sont **ignorés** (jamais throw). Les trous voient leurs
  /// sommets invalides filtrés (un trou qui devient vide est conservé — état
  /// neutre — jamais throw) ; `holes` absent/non-`List` → `null`. `style`
  /// corrompu → `null` ; `metadata` non-`Map` → `null` ; `label`/`id`
  /// non-`String` → `null`.
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
    final id = raw['id'];
    final metadata = raw['metadata'];
    return ZGeoShape(
      vertices: parsed,
      label: label is String ? label : null,
      id: id is String ? id : null,
      style: ZGeoShapeStyle.fromMapSafe(raw['style']),
      holes: _parseHoles(raw['holes']),
      metadata: metadata is Map
          ? Map<String, Object?>.from(
              metadata.map((Object? k, Object? v) =>
                  MapEntry<String, Object?>(k.toString(), v)),
            )
          : null,
    );
  }

  /// Parse défensif des trous : `null` si absent/non-`List`. Chaque trou
  /// non-`List` est ignoré ; les sommets invalides d'un trou sont filtrés.
  static List<List<ZGeoPoint>>? _parseHoles(Object? raw) {
    if (raw is! List) return null;
    final holes = <List<ZGeoPoint>>[];
    for (final Object? hole in raw) {
      if (hole is! List) continue; // trou corrompu ignoré (AD-10)
      final points = <ZGeoPoint>[];
      for (final Object? entry in hole) {
        final point = ZGeoPoint.fromMapSafe(entry);
        if (point != null) points.add(point);
      }
      holes.add(points);
    }
    return holes;
  }

  /// Alias défensif de [fromMapSafe] (nullable) — cohérence `toMap`/`fromMap`.
  static ZGeoShape? fromMap(Object? raw) => fromMapSafe(raw);

  /// Retourne une copie avec [point] ajouté en fin de liste (attributs
  /// optionnels préservés : id/style/holes/metadata).
  ZGeoShape addVertex(ZGeoPoint point) => ZGeoShape(
        vertices: <ZGeoPoint>[...vertices, point],
        label: label,
        id: id,
        style: style,
        holes: holes,
        metadata: metadata,
      );

  /// Copie avec substitutions. Les attributs optionnels absents des arguments
  /// sont **préservés** (sémantique de copie partielle : ils ne peuvent pas être
  /// remis à `null` via cette API).
  ZGeoShape copyWith({
    List<ZGeoPoint>? vertices,
    String? label,
    String? id,
    ZGeoShapeStyle? style,
    List<List<ZGeoPoint>>? holes,
    Map<String, Object?>? metadata,
  }) =>
      ZGeoShape(
        vertices: vertices ?? this.vertices,
        label: label ?? this.label,
        id: id ?? this.id,
        style: style ?? this.style,
        holes: holes ?? this.holes,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoShape &&
          other.label == label &&
          other.id == id &&
          other.style == style &&
          _vertexListEquals(other.vertices, vertices) &&
          _holesEquals(other.holes, holes) &&
          _mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        label,
        id,
        style,
        Object.hashAll(vertices),
        holes == null
            ? null
            : Object.hashAll(
                holes!.map((List<ZGeoPoint> h) => Object.hashAll(h))),
        metadata == null
            ? null
            : Object.hashAll(
                metadata!.entries
                    .map((MapEntry<String, Object?> e) =>
                        Object.hash(e.key, e.value)),
              ),
      );

  static bool _vertexListEquals(List<ZGeoPoint> a, List<ZGeoPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _holesEquals(
      List<List<ZGeoPoint>>? a, List<List<ZGeoPoint>>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_vertexListEquals(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final MapEntry<String, Object?> e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ZGeoShape(vertices: ${vertices.length}, label: $label, id: $id, '
      'style: ${style != null}, holes: ${holes?.length ?? 0})';
}
