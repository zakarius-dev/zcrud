/// `ZGeoMapType` + `ZGeoMapOptions` — **état neutre des options de carte** piloté
/// par la barre d'outils d'éditeur géo (DP-7, gap B9 ; AD-1/AD-14).
///
/// origine: la barre d'outils (parité DODLP `GeoEditorMapState`) pilote des
/// options de carte (type, trafic, bâtiments, gestes, contrôles…). Pour ne PAS
/// faire fuiter un type de SDK carte (`MapType` Google, etc.) dans `zcrud_geo`
/// (a fortiori `zcrud_core` — AD-1), ces options sont exprimées en **types
/// neutres** : l'enum [ZGeoMapType] (valeurs **camelCase**, canonique §5) et le
/// porteur `const` [ZGeoMapOptions]. Chaque adaptateur (OSM/Google) **traduit**
/// ces valeurs vers son propre SDK **dans son fichier confiné** et **honore ce
/// qu'il supporte, ignore le reste** (même contrat que `tileUrlTemplate`/
/// `mapStyleJson`).
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-14) : aucun widget,
/// aucun type SDK.
library;

/// Type de carte **neutre** (traduit par chaque adaptateur vers son SDK).
/// Valeurs **camelCase** (canonique §5).
enum ZGeoMapType {
  /// Carte routière standard.
  normal,

  /// Vue hybride (satellite + libellés).
  hybrid,

  /// Vue satellite pure.
  satellite,

  /// Vue relief/terrain.
  terrain,
}

/// Options de carte **neutres** pilotées par la barre d'outils (DP-7). `const`,
/// immuable, `copyWith`/`==`/`hashCode`. Passé à `ZMapAdapter.buildMap` via le
/// paramètre additif `mapOptions` ; défauts = comportement de base inchangé.
class ZGeoMapOptions {
  /// Construit des options de carte `const`. Les défauts reproduisent le
  /// **`defaultState` de DODLP** (MEDIUM-1 DP-7) : `hybrid` + bâtiments, gestes
  /// (rotation/tilt), contrôles de zoom, boussole et map-toolbar **actifs** ;
  /// trafic et vue intérieure **inactifs**. Ainsi une carte munie d'une barre
  /// d'outils (même un preset `minimal`/`standard` n'exposant pas ces toggles)
  /// conserve le rendu natif attendu au lieu de tout désactiver. Le rendu SANS
  /// barre reste inchangé (`mapOptions == null` → défauts du widget natif,
  /// rétro-compat E11a-1/E11b-1).
  const ZGeoMapOptions({
    this.mapType = ZGeoMapType.hybrid,
    this.trafficEnabled = false,
    this.buildingsEnabled = true,
    this.indoorViewEnabled = false,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.zoomControlsEnabled = true,
    this.compassEnabled = true,
    this.mapToolbarEnabled = true,
  });

  /// Type de carte courant (neutre).
  final ZGeoMapType mapType;

  /// Couche trafic active.
  final bool trafficEnabled;

  /// Bâtiments 3D actifs.
  final bool buildingsEnabled;

  /// Vue intérieure (indoor) active.
  final bool indoorViewEnabled;

  /// Gestes de rotation actifs.
  final bool rotateGesturesEnabled;

  /// Gestes d'inclinaison (tilt) actifs.
  final bool tiltGesturesEnabled;

  /// Contrôles de zoom natifs actifs.
  final bool zoomControlsEnabled;

  /// Boussole native active.
  final bool compassEnabled;

  /// Barre d'outils native de la carte active (Android).
  final bool mapToolbarEnabled;

  /// Copie avec modifications ponctuelles.
  ZGeoMapOptions copyWith({
    ZGeoMapType? mapType,
    bool? trafficEnabled,
    bool? buildingsEnabled,
    bool? indoorViewEnabled,
    bool? rotateGesturesEnabled,
    bool? tiltGesturesEnabled,
    bool? zoomControlsEnabled,
    bool? compassEnabled,
    bool? mapToolbarEnabled,
  }) =>
      ZGeoMapOptions(
        mapType: mapType ?? this.mapType,
        trafficEnabled: trafficEnabled ?? this.trafficEnabled,
        buildingsEnabled: buildingsEnabled ?? this.buildingsEnabled,
        indoorViewEnabled: indoorViewEnabled ?? this.indoorViewEnabled,
        rotateGesturesEnabled:
            rotateGesturesEnabled ?? this.rotateGesturesEnabled,
        tiltGesturesEnabled: tiltGesturesEnabled ?? this.tiltGesturesEnabled,
        zoomControlsEnabled: zoomControlsEnabled ?? this.zoomControlsEnabled,
        compassEnabled: compassEnabled ?? this.compassEnabled,
        mapToolbarEnabled: mapToolbarEnabled ?? this.mapToolbarEnabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoMapOptions &&
          runtimeType == other.runtimeType &&
          mapType == other.mapType &&
          trafficEnabled == other.trafficEnabled &&
          buildingsEnabled == other.buildingsEnabled &&
          indoorViewEnabled == other.indoorViewEnabled &&
          rotateGesturesEnabled == other.rotateGesturesEnabled &&
          tiltGesturesEnabled == other.tiltGesturesEnabled &&
          zoomControlsEnabled == other.zoomControlsEnabled &&
          compassEnabled == other.compassEnabled &&
          mapToolbarEnabled == other.mapToolbarEnabled;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        mapType,
        trafficEnabled,
        buildingsEnabled,
        indoorViewEnabled,
        rotateGesturesEnabled,
        tiltGesturesEnabled,
        zoomControlsEnabled,
        compassEnabled,
        mapToolbarEnabled,
      );
}
