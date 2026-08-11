/// `ZGeoMapType` + `ZGeoMapOptions` — **état neutre des options de carte**
/// piloté par la barre d'outils d'éditeur géo.
///
/// La barre d'outils pilote des options de carte (type, trafic, bâtiments,
/// gestes, contrôles…). Pour ne pas faire fuiter un type de SDK carte
/// (`MapType` Google, etc.) dans `zcrud_geo` — a fortiori dans `zcrud_core`,
/// invariant AD-1 — ces options sont exprimées en **types neutres** : l'enum
/// [ZGeoMapType] (valeurs camelCase) et le porteur `const` [ZGeoMapOptions].
/// Chaque adaptateur (OSM/Google) **traduit** ces valeurs vers son propre SDK
/// dans son fichier confiné, et **honore ce qu'il supporte, ignore le reste**
/// (même contrat que `tileUrlTemplate`/`mapStyleJson`).
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — invariant AD-14) :
/// aucun widget, aucun type SDK.
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

/// Options de carte **neutres** pilotées par la barre d'outils. `const`,
/// immuable, `copyWith`/`==`/`hashCode`. Passé à `ZMapAdapter.buildMap` via le
/// paramètre additif `mapOptions` ; défauts = comportement de base inchangé.
class ZGeoMapOptions {
  /// Construit des options de carte `const`. Défauts : `hybrid` avec
  /// bâtiments, contrôles de zoom, boussole et barre d'outils native
  /// **actifs** ; trafic et vue intérieure **inactifs**. Ainsi une carte
  /// munie d'une barre d'outils (même un preset qui n'expose pas tous les
  /// toggles) conserve le rendu natif attendu au lieu de tout désactiver. Le
  /// rendu **sans** barre reste inchangé (`mapOptions == null` → défauts du
  /// widget natif).
  ///
  /// Les gestes de **rotation** et d'**inclinaison** sont **inactifs par
  /// défaut** (`false`). Un hôte qui veut les activer les réactive
  /// explicitement (`ZGeoMapOptions(rotateGesturesEnabled: true,
  /// tiltGesturesEnabled: true)`) ou via les toggles `showRotationToggle`/
  /// `showTiltToggle` de la barre.
  ///
  /// [myLocationEnabled]/[myLocationButtonEnabled] pilotent le point bleu
  /// natif Google et son bouton associé ; défaut **`false`** — activer le
  /// point bleu exige que l'application hôte détienne la permission de
  /// localisation (`zcrud_geo` ne la déclare ni ne la demande, invariant
  /// AD-1) ; un défaut `true` ferait échouer le rendu chez tout hôte sans
  /// permission (invariant AD-10 : jamais un défaut qui casse). Opt-in
  /// explicite côté hôte.
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

  /// Point bleu « ma position » natif (honoré par Google ; l'adaptateur OSM
  /// n'a aucun équivalent natif → ignoré, contrat honoré-si-supporté). Défaut
  /// `false` (permission de localisation requise côté hôte — voir le
  /// constructeur).
  final bool myLocationEnabled;

  /// Bouton natif de recentrage « ma position » (Google ; sans effet tant que
  /// [myLocationEnabled] est `false`, comportement du SDK). Ignoré par
  /// l'adaptateur OSM (aucun équivalent natif).
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
