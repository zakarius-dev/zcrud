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
  /// **`defaultState` de DODLP** (MEDIUM-1 DP-7) : `hybrid` + bâtiments,
  /// contrôles de zoom, boussole et map-toolbar **actifs** ; trafic et vue
  /// intérieure **inactifs**. Ainsi une carte munie d'une barre d'outils (même
  /// un preset `minimal`/`standard` n'exposant pas ces toggles) conserve le
  /// rendu natif attendu au lieu de tout désactiver. Le rendu SANS barre reste
  /// inchangé (`mapOptions == null` → défauts du widget natif, rétro-compat
  /// E11a-1/E11b-1).
  ///
  /// **G22 (CHANGEMENT DE DÉFAUT, parité legacy `gec:293-294`)** : les gestes
  /// de **rotation** et d'**inclinaison** sont désormais **inactifs par
  /// défaut** (`false`, comme le `GeoEditorMapState.defaultState` legacy —
  /// l'ancien défaut zcrud `true` divergeait). ⚠️ Handoff : un hôte qui
  /// comptait sur rotation/tilt actifs doit les réactiver explicitement
  /// (`ZGeoMapOptions(rotateGesturesEnabled: true, tiltGesturesEnabled: true)`
  /// ou via les toggles `showRotationToggle`/`showTiltToggle` de la barre).
  ///
  /// **G21 (additif)** : [myLocationEnabled]/[myLocationButtonEnabled]
  /// (point bleu natif Google + bouton associé). **Divergence documentée vs
  /// legacy** (`gec:298` : `myLocationEnabled: true`) : le défaut zcrud est
  /// **`false`** — activer le point bleu exige la permission de localisation
  /// de l'app hôte (que `zcrud_geo` ne déclare ni ne demande, AD-1/G10) ; un
  /// `true` par défaut ferait échouer le rendu chez tout hôte sans permission
  /// (AD-10 : jamais un défaut qui casse). Opt-in explicite côté hôte.
  const ZGeoMapOptions({
    this.mapType = ZGeoMapType.hybrid,
    this.trafficEnabled = false,
    this.buildingsEnabled = true,
    this.indoorViewEnabled = false,
    this.rotateGesturesEnabled = false,
    this.tiltGesturesEnabled = false,
    this.zoomControlsEnabled = true,
    this.compassEnabled = true,
    this.mapToolbarEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = true,
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

  /// G21 — point bleu « ma position » natif (honoré par Google ; OSM
  /// `flutter_map` n'a **aucun** équivalent natif → ignoré, contrat
  /// honoré-si-supporté, écart documenté). Défaut `false` (permission de
  /// localisation requise côté hôte — divergence legacy documentée au
  /// constructeur).
  final bool myLocationEnabled;

  /// G21 — bouton natif de recentrage « ma position » (Google ; sans effet
  /// tant que [myLocationEnabled] est `false`, comportement SDK). OSM : ignoré
  /// (aucun équivalent natif).
  final bool myLocationButtonEnabled;

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
    bool? myLocationEnabled,
    bool? myLocationButtonEnabled,
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
        myLocationEnabled: myLocationEnabled ?? this.myLocationEnabled,
        myLocationButtonEnabled:
            myLocationButtonEnabled ?? this.myLocationButtonEnabled,
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
          mapToolbarEnabled == other.mapToolbarEnabled &&
          myLocationEnabled == other.myLocationEnabled &&
          myLocationButtonEnabled == other.myLocationButtonEnabled;

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
        myLocationEnabled,
        myLocationButtonEnabled,
      );
}
