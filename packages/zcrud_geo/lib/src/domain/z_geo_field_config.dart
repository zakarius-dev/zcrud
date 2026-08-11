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
import 'z_geo_map_options.dart';
import 'z_geo_point.dart';

/// Géométrie d'un champ géo (FR-20). Valeurs **camelCase** (canonique §5).
enum ZGeoGeometry {
  /// Point unique (valeur de tranche = `ZGeoPoint`).
  point,

  /// Polygone/aire fermée (valeur de tranche = `ZGeoShape`).
  polygon,

  /// Cercle centre + rayon (valeur de tranche = `ZGeoCircle`).
  circle,

  /// Polyligne : tracé **ouvert** (4e forme, DP-21/M13) — valeur de tranche =
  /// `ZGeoShape` (mêmes sommets ordonnés qu'un polygone, mais rendus en tracé
  /// non fermé : aucun segment de fermeture, aucune aire).
  polyline,
}

/// Présentation du champ géo dans le **flux du formulaire** (CR
/// `geo-inline-preview` point A). La restriction porte sur la présentation
/// **en flux uniquement** — la route plein écran (G5) rend TOUJOURS le champ
/// avec toutes ses capacités, quelle que soit cette valeur.
enum ZGeoPresentation {
  /// Éditeur complet dans le flux (comportement antérieur **STRICT** — défaut,
  /// AD-4 : aucun hôte existant ne bouge).
  inlineEditor,

  /// **Aperçu inerte en flux / édition en plein écran** (parité legacy :
  /// `gff:1525` — undo/clear rendus seulement `if (isFullscreen)` ;
  /// `gff:1668,1683` — `onMapTap: isFullscreen && … ? _onMapTapped : (_) {}`,
  /// le tap d'ajout est désarmé hors plein écran). En flux : chrome (si
  /// activé) + carte **lecture seule** (pan/zoom conservés, tap d'ajout et
  /// drags désarmés) + pied « N points » localisé (`geo.pointsDefined`) —
  /// ni saisie lat/lng, ni liste de sommets, ni barre d'outils, ni picker de
  /// style. L'icône plein écran n'apparaît que si le champ est **éditable**
  /// (masquée en `readOnly` : l'aperçu reste, sans porte d'entrée).
  previewWithFullscreen,
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
  /// - [toolbarConfig] : config de la barre d'outils d'éditeur géo (DP-7,
  ///   gap B9). **G15 (changement de défaut, décision pilote)** : `null`
  ///   (défaut) → barre **`standard`** (parité legacy `es:2337` :
  ///   `geoConfig?.toolbarConfig ?? GeoEditorToolbarConfig.standard`). Pour ne
  ///   rendre **aucune** barre, poser explicitement
  ///   `ZGeoEditorToolbarConfig.none` ;
  /// - [allowedGeometries] : géométries proposées par le **sélecteur de mode**
  ///   (G2, parité legacy `gff:46-50`/`es:2326-2332`) ; `null` (défaut) →
  ///   champ mono-géométrie (comportement antérieur strict) ;
  /// - [adapterKey] : clé de fabrique d'adaptateur carte **par champ** (G4,
  ///   parité legacy `gfc:25` `mapsProvider`) résolue dans le registre
  ///   `ZGeoFieldWidget.builder(adapterFactories: {...})` ; `null` (défaut) ou
  ///   clé absente du registre → repli sur l'`adapterFactory` unique
  ///   (hôte mono-factory strictement inchangé) ;
  /// - [tileUrlTemplates] : gabarits de tuiles OSM **par type de carte** (G3) ;
  ///   `null` → défauts audités `ZGeoTileReference.defaults` (ESRI World
  ///   Imagery pour satellite/hybride, OpenTopoMap pour terrain — mesurés
  ///   `oma:53-110`).
  const ZGeoFieldConfig({
    this.geometry,
    this.defaultCenter,
    this.defaultZoom,
    this.mapHeight,
    this.tileUrlTemplate,
    this.mapStyleJson,
    this.interactive = true,
    this.toolbarConfig,
    this.allowedGeometries,
    this.adapterKey,
    this.tileUrlTemplates,
    this.allowFullscreen = true,
    this.showStylePicker = false,
    this.showMetrics = false,
    this.showChrome = false,
    this.minZoom,
    this.maxZoom,
    this.zoomStep,
    this.presentation = ZGeoPresentation.inlineEditor,
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

  /// Config de la barre d'outils d'éditeur géo (DP-7, gap B9). **G15** :
  /// `null` (défaut) → barre **`standard`** (parité legacy `es:2337`) ;
  /// `ZGeoEditorToolbarConfig.none` → aucune barre. Portée par
  /// `ZGeoFieldConfig` (point d'extension AD-4), jamais par `zcrud_core`.
  final ZGeoEditorToolbarConfig? toolbarConfig;

  /// Géométries proposées par le sélecteur de mode (G2). `null` → champ
  /// mono-géométrie (aucun sélecteur, comportement antérieur strict). La
  /// **géométrie portée par la valeur initiale prime** sur cette liste
  /// (parité legacy `gff:272`).
  final List<ZGeoGeometry>? allowedGeometries;

  /// Clé de fabrique d'adaptateur carte par champ (G4). `null` ou clé
  /// inconnue → repli sur l'`adapterFactory` unique du builder (AD-10, jamais
  /// de crash).
  final String? adapterKey;

  /// Gabarits de tuiles OSM par type de carte (G3, surchargeables — AD-12).
  /// `null` → défauts audités `ZGeoTileReference.defaults`. Un type absent de
  /// la `Map` retombe sur le défaut audité de ce type.
  final Map<ZGeoMapType, String>? tileUrlTemplates;

  /// Mode **plein écran** (G5, parité legacy `gff:971-1177` `_openFullscreen`).
  /// `true` (défaut — parité : le legacy expose TOUJOURS ce bouton, et c'est
  /// son SEUL mode d'édition carte) → le champ rend un bouton d'en-tête qui
  /// ouvre une route immersive rendant LE MÊME champ (`mapHeight` infini) avec
  /// AppBar (fermeture + « Enregistrer » validé par géométrie). Le bouton
  /// n'apparaît que si une carte existe (adaptateur injecté) ; `false` →
  /// aucun bouton, comportement antérieur strict.
  final bool allowFullscreen;

  /// G8 — câblage du **picker de style** (`ZGeoShapeStylePicker`, existant et
  /// testé mais jusqu'ici jamais référencé en production). `true` → le champ
  /// rend le picker et **persiste le style dans la valeur** (parité legacy
  /// `gff:299-307` : `GeoShape.style` porté par la valeur). `false` (défaut)
  /// → rendu strictement inchangé (AD-4).
  final bool showStylePicker;

  /// G12 — affichage du **chip de métriques** « aire | périmètre » + compteur
  /// de points (parité legacy `gff:1363-1391`). Les calculs sont les
  /// extensions pures de `z_geo_metrics.dart` (formules legacy reproduites,
  /// nature documentée) ; les unités passent par la l10n injectée
  /// (`geo.unit.*` — jamais « m² » figé hors repli). `false` (défaut) → aucun
  /// chip (AD-4).
  final bool showMetrics;

  /// G19 — **chrome legacy opt-in** : encart carte (rayon/bordure/ombre —
  /// rôles de thème, valeurs non dérivables en référence auditée
  /// `ZGeoChromeReference`), en-tête dégradé + icône, pied de carte
  /// **localisé** (`geo.pointsDefined` — jamais le texte anglais legacy en
  /// dur). En mode chrome, la hauteur de carte par défaut est la valeur
  /// legacy **300** (`ZGeoChromeReference.chromeMapHeight` ; [mapHeight] prime
  /// — décision G19 documentée dans la référence). `false` (défaut) → rendu
  /// antérieur strictement inchangé (AD-4).
  final bool showChrome;

  /// G23 — zoom minimal de la carte (honoré-si-supporté par l'adaptateur).
  /// `null` → défaut de l'adaptateur (référence legacy OSM :
  /// `ZGeoChromeReference.osmMinZoom` = 3).
  final double? minZoom;

  /// G23 — zoom maximal (honoré-si-supporté). `null` → défaut adaptateur
  /// (référence legacy OSM : `ZGeoChromeReference.osmMaxZoom` = 19).
  final double? maxZoom;

  /// G23 — pas de zoom (référence legacy OSM :
  /// `ZGeoChromeReference.osmZoomStep` = 1.0). **Donnée exposée, sans
  /// consommateur actuel** : ni `flutter_map` ni Google Maps n'offrent de pas
  /// de zoom natif (le legacy le passait à `flutter_osm_plugin`, SDK non
  /// retenu) — honnêteté documentée plutôt qu'une simulation.
  final double? zoomStep;

  /// Présentation du champ **en flux** (CR `geo-inline-preview` A). Défaut
  /// [ZGeoPresentation.inlineEditor] = comportement antérieur **strict**
  /// (AD-4). [ZGeoPresentation.previewWithFullscreen] = aperçu inerte en
  /// flux, édition complète réservée à la route plein écran — la route
  /// immersive n'hérite **jamais** de la restriction d'aperçu.
  final ZGeoPresentation presentation;

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
    List<ZGeoGeometry>? allowedGeometries,
    String? adapterKey,
    Map<ZGeoMapType, String>? tileUrlTemplates,
    bool? allowFullscreen,
    bool? showStylePicker,
    bool? showMetrics,
    bool? showChrome,
    double? minZoom,
    double? maxZoom,
    double? zoomStep,
    ZGeoPresentation? presentation,
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
        allowedGeometries: allowedGeometries ?? this.allowedGeometries,
        adapterKey: adapterKey ?? this.adapterKey,
        tileUrlTemplates: tileUrlTemplates ?? this.tileUrlTemplates,
        allowFullscreen: allowFullscreen ?? this.allowFullscreen,
        showStylePicker: showStylePicker ?? this.showStylePicker,
        showMetrics: showMetrics ?? this.showMetrics,
        showChrome: showChrome ?? this.showChrome,
        minZoom: minZoom ?? this.minZoom,
        maxZoom: maxZoom ?? this.maxZoom,
        zoomStep: zoomStep ?? this.zoomStep,
        presentation: presentation ?? this.presentation,
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
          toolbarConfig == other.toolbarConfig &&
          _listEquals(other.allowedGeometries, allowedGeometries) &&
          adapterKey == other.adapterKey &&
          _mapEquals(other.tileUrlTemplates, tileUrlTemplates) &&
          allowFullscreen == other.allowFullscreen &&
          showStylePicker == other.showStylePicker &&
          showMetrics == other.showMetrics &&
          showChrome == other.showChrome &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom &&
          zoomStep == other.zoomStep &&
          presentation == other.presentation;

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
        allowedGeometries == null
            ? null
            : Object.hashAll(allowedGeometries!),
        adapterKey,
        tileUrlTemplates == null
            ? null
            : Object.hashAll(tileUrlTemplates!.entries
                .map((MapEntry<ZGeoMapType, String> e) =>
                    Object.hash(e.key, e.value))),
        allowFullscreen,
        showStylePicker,
        showMetrics,
        showChrome,
        minZoom,
        maxZoom,
        zoomStep,
        presentation,
      );

  static bool _listEquals(List<ZGeoGeometry>? a, List<ZGeoGeometry>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(
      Map<ZGeoMapType, String>? a, Map<ZGeoMapType, String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final MapEntry<ZGeoMapType, String> e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
