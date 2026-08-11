/// `ZGeoTileReference` — **fichier de référence AUDITÉ** des jeux de tuiles OSM
/// par type de carte (CR geo G3, exception FR-26 encadrée — endpoints de
/// service de référence, patron `ZStudyCardReference`).
///
/// ## Ce que fait réellement le legacy DODLP (mesuré, pas cru)
///
/// `dodlp-otr/.../geofence_field/maps/osm_map_adapter.dart:53-110`
/// (`_applyMapType`) commute les tuiles selon `GeoMapType` :
///
/// | Type | Source legacy (mesurée `oma:53-110`) | Extension |
/// |---|---|---|
/// | `satellite` | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/` (ESRI World Imagery, `sourceName: esri_satellite`) | `.jpg` |
/// | `hybrid` | **la même URL ESRI World Imagery** (`sourceName: esri_hybrid` — le commentaire legacy promet « with labels overlay » mais l'URL est STRICTEMENT identique au satellite : aucune couche de labels n'est réellement ajoutée) | `.jpg` |
/// | `terrain` | `https://tile.opentopomap.org/` (OpenTopoMap, `sourceName: opentopomap`) | `.png` |
/// | `normal` | retour aux tuiles OSM par défaut (`changeTileLayer(tileLayer: null)`) | — |
///
/// ## Adaptation au SDK `flutter_map`
///
/// Le legacy passe par `flutter_osm_plugin` (`CustomTile`, chemin composé par le
/// plugin) ; zcrud passe par `flutter_map` (gabarit `{z}/{x}/{y}` explicite).
/// L'ordre des segments est celui **documenté par chaque service** :
/// - ESRI World Imagery expose `MapServer/tile/{z}/{y}/{x}` (ordre **z/y/x**,
///   schéma ArcGIS officiel) ;
/// - OpenTopoMap expose `{z}/{x}/{y}.png` (schéma XYZ standard).
///
/// ## Conditions de l'exception (toutes remplies)
///
/// 1. **Centralisation** : ces endpoints n'apparaissent QUE dans ce fichier —
///    jamais dans un adaptateur ou un widget ;
/// 2. **Remplaçables** : par paramètre (`ZGeoFieldConfig.tileUrlTemplates` >
///    constructeur `ZOsmMapAdapter(tileUrlTemplates:)`) — la chaîne paramètre >
///    config > référence s'applique ;
/// 3. Aucun secret : endpoints **publics** sans clé (AD-12) ; le user-agent
///    reste fourni par l'app hôte.
library;

import 'z_geo_map_options.dart';

/// Jeux de tuiles de référence par [ZGeoMapType] (valeurs legacy auditées,
/// surchargeables). Espace de noms statique : non instanciable.
abstract final class ZGeoTileReference {
  /// Tuiles OSM publiques standard (type `normal` — défaut historique E11a-1).
  static const String osmStandard =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// ESRI World Imagery (satellite) — base mesurée `oma:57-71`, schéma ArcGIS
  /// `tile/{z}/{y}/{x}` documenté par le service.
  static const String esriWorldImagery =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
      'MapServer/tile/{z}/{y}/{x}.jpg';

  /// OpenTopoMap (terrain) — base mesurée `oma:90-104`.
  static const String openTopoMap =
      'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  /// Jeu de tuiles par défaut par type de carte (parité legacy `oma:53-110`).
  /// `hybrid` pointe la MÊME imagerie ESRI que `satellite` (mesuré : le legacy
  /// n'ajoute aucune couche de labels malgré son commentaire).
  static const Map<ZGeoMapType, String> defaults = <ZGeoMapType, String>{
    ZGeoMapType.normal: osmStandard,
    ZGeoMapType.satellite: esriWorldImagery,
    ZGeoMapType.hybrid: esriWorldImagery,
    ZGeoMapType.terrain: openTopoMap,
  };
}
