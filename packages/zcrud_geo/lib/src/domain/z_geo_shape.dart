/// `ZGeoShape` — modèle de valeur **aire ou tracé géographique neutre**.
///
/// Valeur de tranche du champ `geoArea` (polygone) ou d'un champ en géométrie
/// `polyline` (tracé ouvert). Une forme est une suite ordonnée de [ZGeoPoint]
/// (`vertices`) ; un point unique est un cas dégénéré exploitable (un seul
/// sommet). Modèle **pur-Dart**, agnostique de tout SDK carte.
///
/// Au-delà de `vertices`/`label`, la forme porte des attributs **optionnels**
/// additifs et rétro-compatibles : [id] (identité stable), [style]
/// ([ZGeoShapeStyle], couleurs ARGB neutres — aucun `Color` SDK), [holes]
/// (trous intérieurs d'un polygone : liste de listes de sommets) et
/// [metadata] (`Map` libre). Une forme construite ou sérialisée sans ces
/// attributs reste strictement inchangée (toutes ces clés `null` → omises du
/// `Map`).
///
/// **Désérialisation défensive (invariant AD-10)** : [fromMapSafe] ne throw
/// jamais. `raw` non-`Map` → `null`. Un sommet invalide (absent/non
/// numérique/hors-bornes) est **ignoré** (jamais fatal) ; un trou corrompu
/// voit ses sommets invalides filtrés (jamais de throw) ; un `style`/
/// `metadata` corrompu retombe à `null`. Une aire dont tous les sommets sont
/// invalides devient une aire **vide** (état neutre), pas `null`.
///
/// **Compatibilité de lecture avec un format hérité** : [fromMapSafe] accepte
/// aussi (a) une chaîne JSON encodée (décodée défensivement), (b) l'alias de
/// lecture `points` → `vertices` (uniquement quand `vertices` est absente),
/// (c) une liste nue de points. Une `Map` typée `circle` (sans `vertices`)
/// rend `null` plutôt que d'être parsée comme une forme — cela perdrait
/// silencieusement le rayon ; le routage inter-géométries appartient à
/// `ZGeoValue.fromMapSafe`. Lecture seulement : [toMap] écrit toujours le
/// format zcrud. Détails : `doc/migration-legacy-dodlp-geo.md`.
library;

import 'z_geo_legacy_codec.dart';
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

  /// Identité stable optionnelle de la forme (opaque, `String`).
  final String? id;

  /// Style de rendu neutre optionnel (couleurs ARGB, aucun `Color` SDK).
  final ZGeoShapeStyle? style;

  /// Trous intérieurs optionnels d'un polygone : liste **non modifiable** de
  /// trous, chaque trou étant une liste ordonnée de sommets. `null` → aucun
  /// trou.
  final List<List<ZGeoPoint>>? holes;

  /// Métadonnées libres optionnelles : `Map` **non modifiable**. `null` →
  /// aucune métadonnée.
  final Map<String, Object?>? metadata;

  /// `true` si la forme n'a aucun sommet (état neutre).
  bool get isEmpty => vertices.isEmpty;

  /// `true` si la forme a au moins un sommet.
  bool get isNotEmpty => vertices.isNotEmpty;

  /// Sérialise en `Map` neutre. `vertices` via [ZGeoPoint.toMap] ; les
  /// attributs optionnels `null` sont **omis** (schéma additif : une forme
  /// sans id/style/holes/metadata produit exactement le `Map` minimal).
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
    final decoded = zGeoDecodeLegacyEnvelope(raw);
    // Variante legacy « liste nue de points » (lecteur legacy `fromDynamic`).
    if (decoded is List) {
      return ZGeoShape(vertices: _parseVertexList(decoded));
    }
    if (decoded is! Map) return null;
    var rawVertices = decoded['vertices'];
    if (rawVertices is! List) {
      // Alias de LECTURE legacy (G1) : `points` → `vertices`, uniquement quand
      // `vertices` est absente/inexploitable (la lecture stricte prime).
      // Piège routé : un cercle legacy (`type: 'circle'`) N'EST PAS une forme —
      // le lire comme telle perdrait silencieusement `radius` → `null`, le
      // routage appartient à `ZGeoValue.fromMapSafe`.
      if (decoded['type'] == 'circle') return null;
      final legacyPoints = decoded['points'];
      if (legacyPoints is List) rawVertices = legacyPoints;
    }
    final parsed = _parseVertexList(rawVertices);
    final label = decoded['label'];
    final id = decoded['id'];
    final metadata = decoded['metadata'];
    return ZGeoShape(
      vertices: parsed,
      label: label is String ? label : null,
      id: id is String ? id : null,
      style: ZGeoShapeStyle.fromMapSafe(decoded['style']),
      holes: _parseHoles(decoded['holes']),
      metadata: metadata is Map
          ? Map<String, Object?>.from(
              metadata.map((Object? k, Object? v) =>
                  MapEntry<String, Object?>(k.toString(), v)),
            )
          : null,
    );
  }

  /// Parse défensif d'une liste de sommets : chaque entrée invalide est
  /// **ignorée** (AD-10) ; une entrée non-`List` rend une liste vide.
  static List<ZGeoPoint> _parseVertexList(Object? raw) {
    final parsed = <ZGeoPoint>[];
    if (raw is List) {
      for (final Object? entry in raw) {
        final point = ZGeoPoint.fromMapSafe(entry);
        if (point != null) parsed.add(point); // sommet invalide ignoré (AD-10)
      }
    }
    return parsed;
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
