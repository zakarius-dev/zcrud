/// Entrée d'import **dédiée** de l'adaptateur carte Google (`google_maps_flutter`).
///
/// **AD-1 (confinement SDK)** : le SDK Google n'est atteignable QUE par cet
/// import explicite (`package:zcrud_geo/adapters/google.dart`), jamais par le
/// barrel principal `package:zcrud_geo/zcrud_geo.dart`. Un consommateur qui n'a
/// pas besoin de Google Maps (ou fournit son propre adaptateur / utilise OSM) ne
/// référence aucun symbole `google_maps_flutter` dans son code. La dépendance
/// reste néanmoins déclarée au `pubspec.yaml` de `zcrud_geo` (jamais de
/// `zcrud_core`) — CORE OUT=0.
///
/// **AD-12 (aucune clé dans le package)** : la clé API Google Maps vit dans la
/// **config plateforme** de l'app hôte — jamais dans `zcrud_geo` :
/// - Android : `AndroidManifest.xml` → `com.google.android.geo.API_KEY` ;
/// - iOS : `AppDelegate` → `GMSServices.provideAPIKey(...)`.
///
/// L'app hôte enregistre le champ en passant une **fabrique** d'adaptateur
/// (MAJEUR-1 : chaque montage de champ crée SA propre instance, jamais partagée) :
/// ```dart
/// final registry = ZWidgetRegistry()
///   ..register('location', ZGeoFieldWidget.builder(adapterFactory: ZGoogleMapAdapter.new))
///   ..register('geoArea', ZGeoFieldWidget.builder(adapterFactory: ZGoogleMapAdapter.new));
/// ```
/// Pour un champ **cercle**, poser `ZGeoFieldConfig(geometry: ZGeoGeometry.circle)`
/// sur `ZFieldSpec.config` (ou `ZGeoFieldWidget.builder(geometry: ZGeoGeometry.circle)`).
library;

export '../src/presentation/adapters/z_google_map_adapter.dart';
