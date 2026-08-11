/// `ZGeoTileReference` — **fichier de référence audité** des jeux de tuiles
/// OSM publiques par type de carte (endpoints de service publics, sans clé).
///
/// ## Correspondance des jeux de tuiles
///
/// | Type | Source | Extension |
/// |---|---|---|
/// | `satellite` | ESRI World Imagery | `.jpg` |
/// | `hybrid` | la même imagerie ESRI World Imagery que `satellite` (aucune couche de labels distincte n'est ajoutée) | `.jpg` |
/// | `terrain` | OpenTopoMap | `.png` |
/// | `normal` | tuiles OSM standard | `.png` |
///
/// Gabarit `flutter_map` (`{z}/{x}/{y}` explicite) : l'ordre des segments
/// suit celui **documenté par chaque service** — ESRI World Imagery expose
/// `MapServer/tile/{z}/{y}/{x}` (ordre z/y/x, schéma ArcGIS officiel) tandis
/// qu'OpenTopoMap expose `{z}/{x}/{y}.png` (schéma XYZ standard).
///
/// ## Conditions d'utilisation
///
/// 1. **Centralisation** : ces endpoints n'apparaissent que dans ce fichier —
///    jamais dans un adaptateur ou un widget ;
/// 2. **Remplaçables** : par paramètre (`ZGeoFieldConfig.tileUrlTemplates` >
///    constructeur `ZOsmMapAdapter(tileUrlTemplates:)`) — la chaîne
///    paramètre > config > référence s'applique ;
/// 3. Aucun secret : endpoints **publics** sans clé (invariant AD-12) ; le
///    user-agent reste fourni par l'application hôte.
library;

import 'z_geo_map_options.dart';

/// Jeux de tuiles de référence par [ZGeoMapType] (surchargeables). Espace de
/// noms statique : non instanciable.
abstract final class ZGeoTileReference {
  /// Tuiles OSM publiques standard (type `normal`).
  static const String osmStandard =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// ESRI World Imagery (satellite), schéma ArcGIS `tile/{z}/{y}/{x}`
  /// documenté par le service.
  static const String esriWorldImagery =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
      'MapServer/tile/{z}/{y}/{x}.jpg';

  /// OpenTopoMap (terrain).
  static const String openTopoMap =
      'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  /// Jeu de tuiles par défaut par type de carte. `hybrid` pointe la même
  /// imagerie ESRI que `satellite` (aucune couche de labels distincte).
  static const Map<ZGeoMapType, String> defaults = <ZGeoMapType, String>{
    ZGeoMapType.normal: osmStandard,
    ZGeoMapType.satellite: esriWorldImagery,
    ZGeoMapType.hybrid: esriWorldImagery,
    ZGeoMapType.terrain: openTopoMap,
  };
}
