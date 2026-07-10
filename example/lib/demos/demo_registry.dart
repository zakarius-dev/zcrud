import 'package:zcrud_core/zcrud_core.dart';
// Entrée d'import DÉDIÉE de l'adaptateur carte OSM (AD-1) : le SDK `flutter_map`
// n'est atteint QUE par ce chemin, jamais par le barrel principal `zcrud_geo`.
import 'package:zcrud_geo/adapters/osm.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

/// Construit le `ZWidgetRegistry` PEUPLÉ de la démo (EX-3, AC8) — instance
/// **non-mutable après peuplement** (AD-4 : jamais un singleton statique mutable
/// global ; construite UNE fois par `ExampleApp` et passée par valeur au
/// `ZcrudScope` racine, cf. `app.dart`).
///
/// Kinds ↔ builders des satellites (signatures vérifiées sur disque) :
///  - `location`/`geoArea` → `ZGeoFieldWidget.builder(adapterFactory:
///    ZOsmMapAdapter.new)` : carte OSM (`flutter_map`, SANS clé API — AD-12) ;
///    valeur de tranche NEUTRE (`ZGeoPoint`/`ZGeoShape`), aucun type SDK carte.
///  - `phoneNumber`/`country`/`address` → `ZPhoneFieldWidget.builder` /
///    `ZCountryFieldWidget.builder` / `ZAddressFieldWidget.builder`, partageant
///    UN SEUL [ZCountryCatalog] (l'asset JSON n'est lu qu'une fois) ; valeurs
///    neutres (`ZPhoneNumber` E.164 / code ISO / `ZPostalAddress`).
///
/// Markdown n'est PAS enregistré ici : `ZMarkdownField` exige un `ZFormController`
/// (contrôleur isolé E6/AD-7), absent de `ZFieldWidgetContext` — la démo Markdown
/// le monte DIRECTEMENT (cf. `markdown_demo_screen.dart`).
ZWidgetRegistry buildDemoWidgetRegistry() {
  // Catalogue pays PARTAGÉ par les 3 kinds intl (asset lu 1×, LOW-1 E11a).
  final catalog = ZCountryCatalog();
  return ZWidgetRegistry()
    ..register(
      'location',
      ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new),
    )
    ..register(
      'geoArea',
      ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new),
    )
    ..register('phoneNumber', ZPhoneFieldWidget.builder(catalog: catalog))
    ..register('country', ZCountryFieldWidget.builder(catalog: catalog))
    ..register('address', ZAddressFieldWidget.builder(catalog: catalog));
}
