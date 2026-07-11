/// Barrel d'API publique de `zcrud_geo`.
///
/// Champ géo (`location`/`geoArea`) : modèle de valeur **neutre**
/// (`ZGeoPoint`/`ZGeoShape`), port carte **pur** (`ZMapAdapter`) et widget de
/// champ (`ZGeoFieldWidget` + factory `builder`) servi via `ZWidgetRegistry`.
///
/// **AD-1 (isolation)** : ce barrel n'exporte AUCUN symbole de SDK carte
/// (`flutter_map`/`latlong2`). L'adaptateur concret OSM est atteint via l'entrée
/// dédiée `package:zcrud_geo/adapters/osm.dart` — le SDK reste hors de la voie
/// d'import par défaut. Aucun type carte ne fuit dans la valeur de tranche ni
/// dans une signature publique.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/z_geo_api.dart';
export 'src/domain/z_geo_circle.dart';
export 'src/domain/z_geo_editor_toolbar_config.dart'
    show ZGeoEditorToolbarConfig;
export 'src/domain/z_geo_field_config.dart' show ZGeoFieldConfig, ZGeoGeometry;
export 'src/domain/z_geo_map_options.dart' show ZGeoMapOptions, ZGeoMapType;
export 'src/domain/z_geo_point.dart';
export 'src/domain/z_geo_shape.dart';
export 'src/presentation/z_geo_field_widget.dart';
export 'src/presentation/z_map_adapter.dart';
