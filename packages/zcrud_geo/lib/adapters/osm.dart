/// Entrée d'import **dédiée** de l'adaptateur carte OSM (`flutter_map`).
///
/// **AD-1 (confinement SDK)** : le SDK carte n'est atteignable QUE par cet import
/// explicite (`package:zcrud_geo/adapters/osm.dart`), jamais par le barrel
/// principal `package:zcrud_geo/zcrud_geo.dart`. Un consommateur qui n'a pas
/// besoin de carte (ou fournit son propre adaptateur) ne référence aucun symbole
/// `flutter_map`/`latlong2` dans son code. La dépendance reste néanmoins déclarée
/// au `pubspec.yaml` de `zcrud_geo` (jamais de `zcrud_core`) — CORE OUT=0.
///
/// L'app hôte enregistre le champ en passant une **fabrique** d'adaptateur
/// (MAJEUR-1 : chaque montage de champ crée SA propre instance, jamais partagée) :
/// ```dart
/// final registry = ZWidgetRegistry()
///   ..register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))
///   ..register('geoArea', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new));
/// ```
library;

export '../src/presentation/adapters/z_osm_map_adapter.dart';
