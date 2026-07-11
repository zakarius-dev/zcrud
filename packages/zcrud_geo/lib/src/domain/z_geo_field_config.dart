/// `ZGeoFieldConfig` — **config additive du champ géo** (E11b-1, AD-4/AD-12).
///
/// origine: la géométrie du champ géo était, en E11a-1, **inférée du nom d'enum**
/// (`location`→point, `geoArea`→polygone) et il n'existe **aucune** valeur
/// `circle` dans `EditionFieldType` (le cœur est interdit d'édition — AD-1). Pour
/// couvrir la triade FR-20 « point / polygone / **cercle** » sans toucher
/// `zcrud_core`, la géométrie + les défauts **surchargeables** (centre/zoom/
/// hauteur/URL de tuiles/style) sont portés **par champ** via cette
/// sous-classe concrète `const` de [ZFieldConfig] (point d'extension AD-4 déjà
/// prévu par le cœur ; cf. docstring de `ZFieldConfig` qui nomme littéralement
/// `GeoFieldConfig → zcrud_geo`). Posée sur `ZFieldSpec.config`, elle est lue
/// via `ctx.field.config` par `ZGeoFieldWidget`.
///
/// **AD-12 (aucun défaut national codé en dur non surchargeable)** : tous les
/// défauts sont **neutres** (`null` → l'adaptateur choisit un centre neutre) et
/// **surchargeables** par l'app hôte. Aucune clé/secret. `tileUrlTemplate`
/// (OSM) / `mapStyleJson` (Google) sont surchargeables, jamais un endpoint privé
/// en dur.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-14) : aucune closure,
/// aucun widget, aucune dépendance lourde. Seule dépendance : la base
/// [ZFieldConfig] de `zcrud_core`.
library;

import 'package:zcrud_core/zcrud_core.dart';

import 'z_geo_editor_toolbar_config.dart';
import 'z_geo_point.dart';

/// Géométrie d'un champ géo (FR-20). Valeurs **camelCase** (canonique §5).
enum ZGeoGeometry {
  /// Point unique (valeur de tranche = `ZGeoPoint`).
  point,

  /// Polygone/aire (valeur de tranche = `ZGeoShape`).
  polygon,

  /// Cercle centre + rayon (valeur de tranche = `ZGeoCircle`).
  circle,
}

/// Config additive `const` du champ géo (AD-4). Vit dans `zcrud_geo` ; aucune
/// modification du cœur. Tous les défauts sont neutres/surchargeables (AD-12).
class ZGeoFieldConfig extends ZFieldConfig {
  /// Construit une config géo `const`.
  ///
  /// - [geometry] : géométrie du champ ; `null` → repli sur l'inférence par le
  ///   nom de type (`location`→point, `geoArea`→polygon) pour la **rétro-compat**
  ///   E11a-1 stricte ;
  /// - [defaultCenter] : centre de carte par défaut (neutre ; `null` →
  ///   l'adaptateur choisit un centre neutre) ;
  /// - [defaultZoom] : zoom initial de la carte (neutre ; `null` → défaut
  ///   adaptateur) ;
  /// - [mapHeight] : hauteur de la surface carte (neutre ; `null` → défaut du
  ///   widget) ;
  /// - [tileUrlTemplate] : gabarit d'URL de tuiles OSM **surchargeable** (jamais
  ///   un endpoint privé en dur — AD-12) ;
  /// - [mapStyleJson] : style de carte Google **surchargeable** ;
  /// - [interactive] : `false` pour un aperçu non manipulable ;
  /// - [toolbarConfig] : config **additive** de la barre d'outils d'éditeur géo
  ///   (DP-7, gap B9) ; `null` (défaut) → **aucune barre d'outils** rendue →
  ///   rétro-compat E11a-1/E11b-1 **stricte** (un champ sans `toolbarConfig`
  ///   rend exactement l'UI d'origine).
  const ZGeoFieldConfig({
    this.geometry,
    this.defaultCenter,
    this.defaultZoom,
    this.mapHeight,
    this.tileUrlTemplate,
    this.mapStyleJson,
    this.interactive = true,
    this.toolbarConfig,
  });

  /// Géométrie du champ (`null` → repli inférence par nom de type — E11a-1).
  final ZGeoGeometry? geometry;

  /// Centre de carte par défaut (neutre, surchargeable ; `null` = choix
  /// adaptateur).
  final ZGeoPoint? defaultCenter;

  /// Zoom initial (neutre, surchargeable ; `null` = défaut adaptateur).
  final double? defaultZoom;

  /// Hauteur de la surface carte (surchargeable ; `null` = défaut widget).
  final double? mapHeight;

  /// Gabarit d'URL de tuiles OSM (surchargeable — AD-12 ; `null` = défaut OSM
  /// public de l'adaptateur).
  final String? tileUrlTemplate;

  /// Style JSON de carte Google (surchargeable ; `null` = style par défaut).
  final String? mapStyleJson;

  /// Carte manipulable (`false` = aperçu lecture seule).
  final bool interactive;

  /// Config **additive** de la barre d'outils d'éditeur géo (DP-7, gap B9).
  /// `null` (défaut) → aucune barre d'outils → rétro-compat E11a-1/E11b-1
  /// stricte. Portée par `ZGeoFieldConfig` (point d'extension AD-4), jamais par
  /// `zcrud_core`.
  final ZGeoEditorToolbarConfig? toolbarConfig;

  /// Copie avec modifications ponctuelles (propage tous les champs, dont le
  /// [toolbarConfig] additif).
  ZGeoFieldConfig copyWith({
    ZGeoGeometry? geometry,
    ZGeoPoint? defaultCenter,
    double? defaultZoom,
    double? mapHeight,
    String? tileUrlTemplate,
    String? mapStyleJson,
    bool? interactive,
    ZGeoEditorToolbarConfig? toolbarConfig,
  }) =>
      ZGeoFieldConfig(
        geometry: geometry ?? this.geometry,
        defaultCenter: defaultCenter ?? this.defaultCenter,
        defaultZoom: defaultZoom ?? this.defaultZoom,
        mapHeight: mapHeight ?? this.mapHeight,
        tileUrlTemplate: tileUrlTemplate ?? this.tileUrlTemplate,
        mapStyleJson: mapStyleJson ?? this.mapStyleJson,
        interactive: interactive ?? this.interactive,
        toolbarConfig: toolbarConfig ?? this.toolbarConfig,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoFieldConfig &&
          runtimeType == other.runtimeType &&
          geometry == other.geometry &&
          defaultCenter == other.defaultCenter &&
          defaultZoom == other.defaultZoom &&
          mapHeight == other.mapHeight &&
          tileUrlTemplate == other.tileUrlTemplate &&
          mapStyleJson == other.mapStyleJson &&
          interactive == other.interactive &&
          toolbarConfig == other.toolbarConfig;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        geometry,
        defaultCenter,
        defaultZoom,
        mapHeight,
        tileUrlTemplate,
        mapStyleJson,
        interactive,
        toolbarConfig,
      );
}
