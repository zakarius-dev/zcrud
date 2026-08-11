/// `ZGeoValue` — **point d'entrée discriminé** de lecture d'une valeur géo
/// (G1, AD-1/AD-10/AD-14).
///
/// origine: le legacy DODLP (`data_crud/models/geo_shape.dart`) persiste un
/// **type polymorphe unique** `GeoShape` auto-descriptif (`type:
/// point|circle|polygon|polyline`, valeurs d'enum en camelCase), en **chaîne
/// JSON** (`toJson()`). zcrud porte trois types **disjoints sans ancêtre
/// commun** (`ZGeoPoint`/`ZGeoCircle`/`ZGeoShape`) où la géométrie vient de la
/// *config du champ*. [fromMapSafe] réconcilie les deux mondes : il route une
/// valeur legacy sur son `type` porté pour qu'elle reste **auto-descriptive**.
///
/// ## Note de migration legacy DODLP → zcrud (G1-d)
///
/// Correspondance champ à champ (mesurée sur le writer legacy) :
///
/// | Legacy (`GeoShape.toMap`) | zcrud |
/// |---|---|
/// | enveloppe `String` JSON (`toJson`) | `Map` — la String reste LUE partout |
/// | `type: 'point'` + `points[0]` | [ZGeoPoint] (`lat`/`lng`, `label` repris) |
/// | `type: 'circle'` + `points[0]` + `radius` (m) | [ZGeoCircle] (`center` + `radius_m`) |
/// | `type: 'polygon'` + `points` + `holes` | [ZGeoShape] (`vertices` + `holes`) |
/// | `type: 'polyline'` + `points` | [ZGeoShape] (tracé ouvert — l'ouverture vient de la géométrie du champ, `ZGeoGeometry.polyline`) |
/// | `points: [{lat,lng}]` (variante lue : `latitude`/`longitude`) | `vertices: [{lat,lng}]` |
/// | `style.fillColor`/`strokeColor`/`iconColor` (int ARGB `Color.value`) | `style.fillColorArgb`/`strokeColorArgb`/`iconColorArgb` (int ARGB identique) |
/// | `style.iconSize`/`iconAnchor`/`iconRotation` | **ignorés** sans erreur (G17 hors périmètre G1) |
/// | `id`/`label`/`metadata` | mêmes clés |
/// | `List` JSON nue de points (lecteur `fromDynamic`) | 1 point → [ZGeoPoint], sinon [ZGeoShape] |
///
/// **Lecture seulement** : l'écriture zcrud (`toMap`) est strictement
/// inchangée. À la première re-sauvegarde, la valeur est réécrite au format
/// zcrud (le discriminant `type` disparaît ; la géométrie est ensuite portée
/// par `ZGeoFieldConfig.geometry`). Aucun hôte zcrud n'a rien à changer ; un
/// hôte qui **pré-convertissait** lui-même les valeurs legacy peut retirer sa
/// conversion (elle reste sans effet : une valeur déjà zcrud se relit
/// exactement comme avant).
///
/// **Défensif (AD-10)** : ne **throw jamais**. JSON invalide, `type` inconnu
/// sans structure reconnaissable, géométrie inexploitable → `null`.
library;

import 'z_geo_circle.dart';
import 'z_geo_legacy_codec.dart';
import 'z_geo_point.dart';
import 'z_geo_shape.dart';

/// Routeur de lecture discriminé d'une valeur géo (legacy DODLP ou zcrud).
/// Espace de noms statique : non instanciable.
abstract final class ZGeoValue {
  /// Parse **défensif** (AD-10) et **discriminé** : retourne un [ZGeoPoint],
  /// un [ZGeoCircle], un [ZGeoShape] ou `null` — jamais de throw. Les trois
  /// types zcrud n'ayant pas d'ancêtre commun, le résultat est typé `Object?`
  /// et se consomme par `switch`/`is`.
  ///
  /// Routage :
  /// 1. une instance déjà typée ([ZGeoPoint]/[ZGeoCircle]/[ZGeoShape]) est
  ///    rendue telle quelle ;
  /// 2. une `String` est décodée en JSON (invalide → `null`) ;
  /// 3. une `List` nue de points suit le lecteur legacy `fromDynamic` :
  ///    1 point valide → [ZGeoPoint], sinon [ZGeoShape] ;
  /// 4. une `Map` portant `type` (`point|circle|polygon|polyline`, camelCase
  ///    legacy) est routée sur le parseur du type — le cercle legacy
  ///    (`points[0]` + `radius`) devient un [ZGeoCircle], jamais une forme à
  ///    un sommet qui perdrait le rayon ;
  /// 5. sans `type` (valeur zcrud), détection **structurelle** :
  ///    `vertices`/`points` → [ZGeoShape] ; `center` ou `radius_m`/`radius` →
  ///    [ZGeoCircle] ; `lat`/`lng` (ou `latitude`/`longitude`) → [ZGeoPoint] ;
  /// 6. `type` inconnu (schéma futur) → repli sur la même détection
  ///    structurelle (évolution additive), sinon `null`.
  static Object? fromMapSafe(Object? raw) {
    if (raw is ZGeoPoint || raw is ZGeoCircle || raw is ZGeoShape) return raw;
    final decoded = zGeoDecodeLegacyEnvelope(raw);
    if (decoded is List) {
      // Variante legacy « liste nue » (gs:604-611) : 1 → point, sinon forme.
      if (decoded.length == 1) {
        final point = ZGeoPoint.fromMapSafe(decoded.single);
        if (point != null) return point;
      }
      return ZGeoShape.fromMapSafe(decoded);
    }
    if (decoded is! Map) return null;
    switch (decoded['type']) {
      case 'point':
        return ZGeoPoint.fromMapSafe(decoded);
      case 'circle':
        return ZGeoCircle.fromMapSafe(decoded);
      case 'polygon':
      case 'polyline':
        return ZGeoShape.fromMapSafe(decoded);
    }
    // Sans discriminant (valeur zcrud) ou discriminant inconnu (schéma futur,
    // AD-10 additif) : détection structurelle. Le cercle est testé AVANT la
    // forme : un rayon présent désigne un cercle, même accompagné de `points`
    // (le lire comme forme perdrait silencieusement le rayon — piège G1).
    if (decoded['center'] != null ||
        decoded['radius_m'] != null ||
        decoded['radius'] != null) {
      return ZGeoCircle.fromMapSafe(decoded);
    }
    if (decoded['vertices'] is List || decoded['points'] is List) {
      return ZGeoShape.fromMapSafe(decoded);
    }
    return ZGeoPoint.fromMapSafe(decoded);
  }
}
