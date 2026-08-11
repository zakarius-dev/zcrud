/// `ZGeoShapeStyle` — **style de rendu neutre d'une forme géo** (DP-21/M13,
/// AD-1/AD-5/AD-14/AD-10).
///
/// origine: DODLP (`data_crud/models/geo_shape.dart → GeoShapeStyle`) porte le
/// style de rendu des formes (couleur de remplissage/contour, épaisseur,
/// opacité, icône de marqueur, draggable, info-window). Ce modèle en est le
/// **portage neutre** : pur-données `const`, **AUCUN type SDK carte ni
/// `dart:ui`/`Color`** dans sa signature (AD-1/AD-5) — les couleurs sont
/// exprimées en **entier ARGB 32 bits** (`0xAARRGGBB`), traduites vers le
/// `Color` du SDK **exclusivement** dans l'adaptateur carte concret
/// (`src/presentation/adapters/`), jamais ici.
///
/// **Pur-données `const` (AD-14)** : aucune closure, aucun widget, aucune
/// dépendance lourde ni Flutter. Deux instances aux mêmes champs sont `==`.
///
/// **Défensif (AD-10)** : [fromMapSafe] ne **throw jamais**. `raw` non-`Map` →
/// `null` ; toute clé absente/corrompue retombe sur son **défaut neutre** (une
/// couleur non entière → `null`, une opacité hors [0,1]/non finie → bornée ou
/// défaut). L'évolution de schéma reste **additive**.
///
/// **G17** : [iconSize]/[iconAnchor]/[iconRotation] (parité `gs:109-116`) sont
/// désormais portés ET LUS par [fromMapSafe] (les données legacy posées par G1
/// ne sont plus jetées). **G18** : les presets [defaultPoint]/[defaultCircle]/
/// [defaultPolygon]/[defaultPolyline] rendent les valeurs legacy auditées de
/// `ZGeoStyleReference` (fichier de référence unique — exception FR-26
/// encadrée) ; ils restent **opt-in** (aucun preset n'est appliqué d'office).
library;

import 'z_geo_point.dart';
import 'z_geo_style_reference.dart';

/// Style de rendu neutre d'une [ZGeoShape] : couleurs ARGB, contour, opacité,
/// icône de marqueur, draggable, info-window. Aucun type SDK/`Color` exposé.
class ZGeoShapeStyle {
  /// Construit un style `const`. Tous les paramètres ont un **défaut neutre**
  /// (rétro-compat : un style « vide » = `ZGeoShapeStyle()` n'impose rien de
  /// visuel de plus que le comportement d'origine côté adaptateur).
  const ZGeoShapeStyle({
    this.fillColorArgb,
    this.strokeColorArgb,
    this.strokeWidth = 3,
    this.visible = true,
    this.zIndex = 0,
    this.geodesic = false,
    this.opacity = 1.0,
    this.draggable = false,
    this.consumeTapEvents = true,
    this.iconAsset,
    this.iconColorArgb,
    this.iconSize,
    this.iconAnchor,
    this.iconRotation = 0.0,
    this.showInfoWindow = false,
    this.infoWindowTitle,
    this.infoWindowSnippet,
  });

  /// Couleur de remplissage **ARGB 32 bits** (`0xAARRGGBB`) — polygone/cercle.
  /// `null` → l'adaptateur choisit un défaut neutre (thème injecté, FR-26).
  final int? fillColorArgb;

  /// Couleur de contour/trait **ARGB 32 bits** — polygone/cercle/polyligne.
  /// `null` → défaut neutre côté adaptateur (thème injecté, FR-26).
  final int? strokeColorArgb;

  /// Épaisseur du trait en pixels (≥0 ; défaut `3`).
  final int strokeWidth;

  /// Visibilité de la forme (défaut `true`).
  final bool visible;

  /// Index de superposition — plus grand = au-dessus (défaut `0`).
  final int zIndex;

  /// Segments géodésiques (grand cercle) pour les tracés (défaut `false`).
  final bool geodesic;

  /// Opacité `[0.0, 1.0]` (défaut `1.0`). Bornée défensivement au parse.
  final double opacity;

  /// Forme déplaçable par l'utilisateur (défaut `false`).
  final bool draggable;

  /// La forme consomme les évènements de tap (défaut `true`).
  final bool consumeTapEvents;

  /// Marqueur : chemin d'asset/URL d'icône (`null` → icône par défaut adaptateur).
  final String? iconAsset;

  /// Marqueur : teinte d'icône **ARGB 32 bits** (`null` → aucune teinte imposée).
  final int? iconColorArgb;

  /// Marqueur : taille d'icône en dp (G17, parité `gs:110` ; `null` → défaut
  /// adaptateur).
  final double? iconSize;

  /// Marqueur : point d'ancrage normalisé `(0.0-1.0, 0.0-1.0)` (G17, parité
  /// `gs:112-113` — le legacy le sérialise en `GeoPoint {lat,lng}`, repris tel
  /// quel en [ZGeoPoint] pour la compat de lecture ; `null` → défaut adaptateur).
  final ZGeoPoint? iconAnchor;

  /// Marqueur : rotation en degrés (G17, parité `gs:116` ; défaut `0.0`).
  final double iconRotation;

  /// Marqueur : afficher l'info-window (défaut `false`).
  final bool showInfoWindow;

  /// Marqueur : titre d'info-window (`null` → aucun).
  final String? infoWindowTitle;

  /// Marqueur : texte secondaire d'info-window (`null` → aucun).
  final String? infoWindowSnippet;

  /// Borne inférieure d'opacité.
  static const double minOpacity = 0.0;

  /// Borne supérieure d'opacité.
  static const double maxOpacity = 1.0;

  // ===== Presets legacy audités (G18, opt-in — valeurs : ZGeoStyleReference) ==

  /// Preset point/marqueur legacy (`gs:154-157`, référence auditée — opt-in).
  static const ZGeoShapeStyle defaultPoint = ZGeoStyleReference.defaultPoint;

  /// Preset cercle legacy (`gs:159-164`, référence auditée — opt-in).
  static const ZGeoShapeStyle defaultCircle = ZGeoStyleReference.defaultCircle;

  /// Preset polygone legacy (`gs:166-171`, référence auditée — opt-in).
  static const ZGeoShapeStyle defaultPolygon =
      ZGeoStyleReference.defaultPolygon;

  /// Preset polyligne legacy (`gs:173-177`, référence auditée — opt-in).
  static const ZGeoShapeStyle defaultPolyline =
      ZGeoStyleReference.defaultPolyline;

  /// Sérialise en `Map` neutre. Les scalaires sont toujours émis ; les couleurs
  /// ARGB et les libellés d'info-window `null` sont **omis** (schéma additif).
  Map<String, Object?> toMap() => <String, Object?>{
        if (fillColorArgb != null) 'fillColorArgb': fillColorArgb,
        if (strokeColorArgb != null) 'strokeColorArgb': strokeColorArgb,
        'strokeWidth': strokeWidth,
        'visible': visible,
        'zIndex': zIndex,
        'geodesic': geodesic,
        'opacity': opacity,
        'draggable': draggable,
        'consumeTapEvents': consumeTapEvents,
        if (iconAsset != null) 'iconAsset': iconAsset,
        if (iconColorArgb != null) 'iconColorArgb': iconColorArgb,
        if (iconSize != null) 'iconSize': iconSize,
        if (iconAnchor != null) 'iconAnchor': iconAnchor!.toMap(),
        'iconRotation': iconRotation,
        'showInfoWindow': showInfoWindow,
        if (infoWindowTitle != null) 'infoWindowTitle': infoWindowTitle,
        if (infoWindowSnippet != null) 'infoWindowSnippet': infoWindowSnippet,
      };

  /// Parse **défensif** (AD-10) : `null` si [raw] n'est pas une `Map`. Chaque
  /// clé absente/corrompue retombe sur son défaut neutre ; l'opacité est bornée
  /// à `[0,1]` (non finie → défaut). Ne throw **jamais**.
  ///
  /// **Alias de LECTURE legacy DODLP (G1)** : `fillColor`/`strokeColor`/
  /// `iconColor` (int ARGB `Color.value`, mesuré dans le JSON legacy) sont lues
  /// quand la clé zcrud `*Argb` est absente — la lecture stricte prime
  /// toujours. **G17** : `iconSize`/`iconAnchor`/`iconRotation` (mêmes clés des
  /// deux côtés) sont désormais LUES au lieu d'être jetées — un `iconAnchor`
  /// corrompu retombe à `null`, une rotation non numérique au défaut `0.0`.
  static ZGeoShapeStyle? fromMapSafe(Object? raw) {
    if (raw is! Map) return null;
    return ZGeoShapeStyle(
      fillColorArgb: _asArgb(raw['fillColorArgb'] ?? raw['fillColor']),
      strokeColorArgb: _asArgb(raw['strokeColorArgb'] ?? raw['strokeColor']),
      strokeWidth: _asInt(raw['strokeWidth'], 3),
      visible: _asBool(raw['visible'], true),
      zIndex: _asInt(raw['zIndex'], 0),
      geodesic: _asBool(raw['geodesic'], false),
      opacity: _asOpacity(raw['opacity']),
      draggable: _asBool(raw['draggable'], false),
      consumeTapEvents: _asBool(raw['consumeTapEvents'], true),
      iconAsset: raw['iconAsset'] is String ? raw['iconAsset'] as String : null,
      iconColorArgb: _asArgb(raw['iconColorArgb'] ?? raw['iconColor']),
      iconSize: _asFiniteDouble(raw['iconSize']),
      iconAnchor: ZGeoPoint.fromMapSafe(raw['iconAnchor']),
      iconRotation: _asFiniteDouble(raw['iconRotation']) ?? 0.0,
      showInfoWindow: _asBool(raw['showInfoWindow'], false),
      infoWindowTitle: raw['infoWindowTitle'] is String
          ? raw['infoWindowTitle'] as String
          : null,
      infoWindowSnippet: raw['infoWindowSnippet'] is String
          ? raw['infoWindowSnippet'] as String
          : null,
    );
  }

  /// Alias défensif de [fromMapSafe] (nullable) — cohérence `toMap`/`fromMap`.
  static ZGeoShapeStyle? fromMap(Object? raw) => fromMapSafe(raw);

  /// Convertit en entier ARGB : `int` direct, `num`→`toInt`, `String` décimale
  /// ou hexadécimale (`0x…`/`#…`), sinon `null` (défensif).
  static int? _asArgb(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      if (s.startsWith('#')) return int.tryParse(s.substring(1), radix: 16);
      if (s.startsWith('0x') || s.startsWith('0X')) {
        return int.tryParse(s.substring(2), radix: 16);
      }
      return int.tryParse(s);
    }
    return null;
  }

  static int _asInt(Object? v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  static bool _asBool(Object? v, bool fallback) => v is bool ? v : fallback;

  /// `double` **fini** ou `null` (défensif — G17).
  static double? _asFiniteDouble(Object? v) {
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim());
    }
    return (d != null && d.isFinite) ? d : null;
  }

  /// Opacité bornée `[0,1]` ; absente/non numérique/non finie → défaut `1.0`.
  static double _asOpacity(Object? v) {
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim());
    }
    if (d == null || !d.isFinite) return maxOpacity;
    return d.clamp(minOpacity, maxOpacity);
  }

  /// Copie avec substitutions. Les couleurs/libellés ne peuvent pas être remis
  /// à `null` via cette API (sémantique de copie partielle).
  ZGeoShapeStyle copyWith({
    int? fillColorArgb,
    int? strokeColorArgb,
    int? strokeWidth,
    bool? visible,
    int? zIndex,
    bool? geodesic,
    double? opacity,
    bool? draggable,
    bool? consumeTapEvents,
    String? iconAsset,
    int? iconColorArgb,
    double? iconSize,
    ZGeoPoint? iconAnchor,
    double? iconRotation,
    bool? showInfoWindow,
    String? infoWindowTitle,
    String? infoWindowSnippet,
  }) =>
      ZGeoShapeStyle(
        fillColorArgb: fillColorArgb ?? this.fillColorArgb,
        strokeColorArgb: strokeColorArgb ?? this.strokeColorArgb,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        visible: visible ?? this.visible,
        zIndex: zIndex ?? this.zIndex,
        geodesic: geodesic ?? this.geodesic,
        opacity: opacity ?? this.opacity,
        draggable: draggable ?? this.draggable,
        consumeTapEvents: consumeTapEvents ?? this.consumeTapEvents,
        iconAsset: iconAsset ?? this.iconAsset,
        iconColorArgb: iconColorArgb ?? this.iconColorArgb,
        iconSize: iconSize ?? this.iconSize,
        iconAnchor: iconAnchor ?? this.iconAnchor,
        iconRotation: iconRotation ?? this.iconRotation,
        showInfoWindow: showInfoWindow ?? this.showInfoWindow,
        infoWindowTitle: infoWindowTitle ?? this.infoWindowTitle,
        infoWindowSnippet: infoWindowSnippet ?? this.infoWindowSnippet,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoShapeStyle &&
          other.fillColorArgb == fillColorArgb &&
          other.strokeColorArgb == strokeColorArgb &&
          other.strokeWidth == strokeWidth &&
          other.visible == visible &&
          other.zIndex == zIndex &&
          other.geodesic == geodesic &&
          other.opacity == opacity &&
          other.draggable == draggable &&
          other.consumeTapEvents == consumeTapEvents &&
          other.iconAsset == iconAsset &&
          other.iconColorArgb == iconColorArgb &&
          other.iconSize == iconSize &&
          other.iconAnchor == iconAnchor &&
          other.iconRotation == iconRotation &&
          other.showInfoWindow == showInfoWindow &&
          other.infoWindowTitle == infoWindowTitle &&
          other.infoWindowSnippet == infoWindowSnippet;

  @override
  int get hashCode => Object.hash(
        fillColorArgb,
        strokeColorArgb,
        strokeWidth,
        visible,
        zIndex,
        geodesic,
        opacity,
        draggable,
        consumeTapEvents,
        iconAsset,
        iconColorArgb,
        iconSize,
        iconAnchor,
        iconRotation,
        showInfoWindow,
        infoWindowTitle,
        infoWindowSnippet,
      );

  @override
  String toString() =>
      'ZGeoShapeStyle(fill: $fillColorArgb, stroke: $strokeColorArgb, '
      'strokeWidth: $strokeWidth, opacity: $opacity, draggable: $draggable, '
      'infoWindow: $showInfoWindow)';
}
