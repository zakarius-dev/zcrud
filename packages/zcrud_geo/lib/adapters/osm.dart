/// Entrée d'import **dédiée** de l'adaptateur carte OSM (`flutter_map`).
///
/// **Invariant AD-1 (confinement SDK)** : le SDK carte n'est atteignable que
/// par cet import explicite (`package:zcrud_geo/adapters/osm.dart`), jamais
/// par le barrel principal `package:zcrud_geo/zcrud_geo.dart`. Un
/// consommateur qui n'a pas besoin de carte (ou fournit son propre
/// adaptateur) ne référence aucun symbole `flutter_map`/`latlong2` dans son
/// code. La dépendance reste néanmoins déclarée au `pubspec.yaml` de
/// `zcrud_geo` (jamais de `zcrud_core`).
///
/// L'application hôte enregistre le champ en passant une **fabrique**
/// d'adaptateur (chaque montage de champ crée sa propre instance, jamais
/// partagée) :
/// ```dart
/// final registry = ZWidgetRegistry()
///   ..register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))
///   ..register('geoArea', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new));
/// ```
library;

export '../src/presentation/adapters/z_osm_map_adapter.dart';
