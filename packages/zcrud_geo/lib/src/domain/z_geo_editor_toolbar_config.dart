/// `ZGeoEditorToolbarConfig` — **config de barre d'outils d'éditeur géo**.
///
/// Expose 18 toggles booléens, un flag `disabled` et un libellé de menu, plus
/// cinq presets (`none`/`minimal`/`standard`/`full`/`professional`). Point de
/// branchement additif posé sur [ZGeoFieldConfig.toolbarConfig] (défaut
/// `null` → barre `standard`, cf. le champ correspondant).
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — invariant AD-14) :
/// aucun widget, aucun `IconData`, aucune dépendance lourde, aucune closure.
/// Les seuls types sont des `bool`/`String`. Le rendu (icônes/boutons) vit
/// dans la couche `presentation` (`ZGeoFieldWidget`).
///
/// **Invariant AD-12** : [mapOptionsLabel] est un simple libellé
/// surchargeable ; aucun défaut national/endpoint/clé. Les libellés
/// effectifs de l'UI passent par la l10n injectée
/// (`label(context, 'geo.*', fallback:)`).
library;

/// Config `const` de la barre d'outils d'éditeur géo. Portée par
/// [ZGeoFieldConfig.toolbarConfig] ; `null` côté config → barre `standard`.
class ZGeoEditorToolbarConfig {
  /// Construit une config de barre d'outils `const`.
  const ZGeoEditorToolbarConfig({
    this.disabled = false,
    // Drawing Tools
    this.showModeSelector = true,
    this.showMyLocationButton = true,
    this.showUndoButton = true,
    this.showClearButton = true,
    this.showOptimizeButton = true,
    // Map Type
    this.showMapTypeToggle = true,
    this.showExtendedMapTypes = false,
    // Map Features
    this.showTrafficToggle = false,
    this.showBuildingsToggle = false,
    this.showIndoorViewToggle = false,
    // Gesture Controls
    this.showRotationToggle = false,
    this.showTiltToggle = false,
    // Advanced
    this.showZoomControlsToggle = false,
    this.showCompassToggle = false,
    this.showMapToolbarToggle = false,
    // Layout
    this.useMapOptionsDropdown = false,
    this.mapOptionsLabel = 'Options',
    this.showButtonLabels = true,
    this.compactMode = false,
    this.compactBreakpointDp,
  });

  // =========== Disable Toolbar ============

  /// Masque **entièrement** la barre d'outils (aucun bouton/option rendu).
  final bool disabled;

  // =========== Drawing Tools ============

  /// Affiche le sélecteur de mode (point/cercle/polygone/polyligne). Rendu
  /// quand le champ est **multi-géométries**
  /// (`ZGeoFieldConfig.allowedGeometries` non-`null`, ≥2 entrées) ; la
  /// bascule est une action discrète, jamais sur la voie de frappe (invariant
  /// AD-2). Changer de mode efface les sommets/le rayon en cours de saisie.
  final bool showModeSelector;

  /// Affiche le bouton « centrer sur ma position ».
  final bool showMyLocationButton;

  /// Affiche le bouton undo (annuler la dernière saisie/sommet).
  final bool showUndoButton;

  /// Affiche le bouton clear (tout effacer).
  final bool showClearButton;

  /// Affiche le bouton d'optimisation de polygone (réordonne les sommets par
  /// angle autour du centroïde pour prévenir l'auto-intersection).
  final bool showOptimizeButton;

  // ============ Map Type ============

  /// Affiche le toggle de type de carte de base (Normal/Hybride).
  final bool showMapTypeToggle;

  /// Affiche le sélecteur de type étendu (ajoute Satellite/Terrain).
  final bool showExtendedMapTypes;

  // ============ Map Features ============

  /// Affiche le toggle de couche trafic.
  final bool showTrafficToggle;

  /// Affiche le toggle bâtiments 3D.
  final bool showBuildingsToggle;

  /// Affiche le toggle vue intérieure (indoor).
  final bool showIndoorViewToggle;

  // ============ Gesture Controls ============

  /// Affiche le toggle de rotation.
  final bool showRotationToggle;

  /// Affiche le toggle d'inclinaison (perspective 3D).
  final bool showTiltToggle;

  // ============ Advanced Features ============

  /// Affiche le toggle des contrôles de zoom.
  final bool showZoomControlsToggle;

  /// Affiche le toggle de la boussole.
  final bool showCompassToggle;

  /// Affiche le toggle de la barre d'outils native de la carte (Android).
  final bool showMapToolbarToggle;

  // ============ Layout ============

  /// Regroupe les options de carte dans un menu déroulant.
  final bool useMapOptionsDropdown;

  /// Libellé (surchargeable) du menu des options de carte.
  final String mapOptionsLabel;

  /// Affiche les libellés textuels sur les boutons de la barre.
  final bool showButtonLabels;

  /// Mode compact (icônes seules).
  final bool compactMode;

  /// Seuil (dp) de **compaction responsive** : sous cette largeur d'écran, la
  /// barre passe en mode compact même si [compactMode] est `false`. `null`
  /// (défaut) → seuil de référence audité
  /// (`ZGeoChromeReference.compactBreakpointDp` = 600). `0` → jamais de
  /// compaction automatique (opt-out).
  final double? compactBreakpointDp;

  // ============ Presets ============

  /// Barre désactivée (masque tous les outils et options).
  static const ZGeoEditorToolbarConfig none = ZGeoEditorToolbarConfig(
    disabled: true,
    showModeSelector: false,
    showMyLocationButton: false,
    showUndoButton: false,
    showClearButton: false,
    showOptimizeButton: false,
    showMapTypeToggle: false,
    showExtendedMapTypes: false,
    showTrafficToggle: false,
    showBuildingsToggle: false,
    showIndoorViewToggle: false,
    showRotationToggle: false,
    showTiltToggle: false,
    showZoomControlsToggle: false,
    showCompassToggle: false,
    showMapToolbarToggle: false,
    useMapOptionsDropdown: false,
    showButtonLabels: false,
    compactMode: true,
  );

  /// Barre minimale — seulement les outils de dessin essentiels (picking simple).
  static const ZGeoEditorToolbarConfig minimal = ZGeoEditorToolbarConfig(
    showModeSelector: false,
    showMyLocationButton: true,
    showUndoButton: true,
    showClearButton: true,
    showOptimizeButton: false,
    showMapTypeToggle: true,
    showExtendedMapTypes: false,
    showTrafficToggle: false,
    showBuildingsToggle: false,
    showIndoorViewToggle: false,
    showRotationToggle: false,
    showTiltToggle: false,
    showZoomControlsToggle: false,
    showCompassToggle: false,
    showMapToolbarToggle: false,
    useMapOptionsDropdown: false,
    showButtonLabels: false,
    compactMode: true,
  );

  /// Barre standard — outils communs, équilibre features/simplicité (défaut).
  static const ZGeoEditorToolbarConfig standard = ZGeoEditorToolbarConfig(
    showModeSelector: true,
    showMyLocationButton: true,
    showUndoButton: true,
    showClearButton: true,
    showOptimizeButton: true,
    showMapTypeToggle: true,
    showExtendedMapTypes: false,
    showTrafficToggle: false,
    showBuildingsToggle: false,
    showIndoorViewToggle: false,
    showRotationToggle: false,
    showTiltToggle: false,
    showZoomControlsToggle: false,
    showCompassToggle: false,
    showMapToolbarToggle: false,
    useMapOptionsDropdown: false,
    showButtonLabels: true,
    compactMode: false,
  );

  /// Barre complète — tous les outils/options (GIS avancé) : tous les
  /// toggles à `true` **sauf** [compactMode] (`false`).
  static const ZGeoEditorToolbarConfig full = ZGeoEditorToolbarConfig(
    showModeSelector: true,
    showMyLocationButton: true,
    showUndoButton: true,
    showClearButton: true,
    showOptimizeButton: true,
    showMapTypeToggle: true,
    showExtendedMapTypes: true,
    showTrafficToggle: true,
    showBuildingsToggle: true,
    showIndoorViewToggle: true,
    showRotationToggle: true,
    showTiltToggle: true,
    showZoomControlsToggle: true,
    showCompassToggle: true,
    showMapToolbarToggle: true,
    useMapOptionsDropdown: true,
    showButtonLabels: true,
    compactMode: false,
  );

  /// Barre professionnelle — levé/cartographie : comme [full] mais
  /// indoor/zoom/compass/mapToolbar à `false`.
  static const ZGeoEditorToolbarConfig professional = ZGeoEditorToolbarConfig(
    showModeSelector: true,
    showMyLocationButton: true,
    showUndoButton: true,
    showClearButton: true,
    showOptimizeButton: true,
    showMapTypeToggle: true,
    showExtendedMapTypes: true,
    showTrafficToggle: true,
    showBuildingsToggle: true,
    showIndoorViewToggle: false,
    showRotationToggle: true,
    showTiltToggle: true,
    showZoomControlsToggle: false,
    showCompassToggle: false,
    showMapToolbarToggle: false,
    useMapOptionsDropdown: true,
    showButtonLabels: true,
    compactMode: false,
  );

  /// Copie avec modifications ponctuelles.
  ZGeoEditorToolbarConfig copyWith({
    bool? disabled,
    bool? showModeSelector,
    bool? showMyLocationButton,
    bool? showUndoButton,
    bool? showClearButton,
    bool? showOptimizeButton,
    bool? showMapTypeToggle,
    bool? showExtendedMapTypes,
    bool? showTrafficToggle,
    bool? showBuildingsToggle,
    bool? showIndoorViewToggle,
    bool? showRotationToggle,
    bool? showTiltToggle,
    bool? showZoomControlsToggle,
    bool? showCompassToggle,
    bool? showMapToolbarToggle,
    bool? useMapOptionsDropdown,
    String? mapOptionsLabel,
    bool? showButtonLabels,
    bool? compactMode,
    double? compactBreakpointDp,
  }) =>
      ZGeoEditorToolbarConfig(
        disabled: disabled ?? this.disabled,
        showModeSelector: showModeSelector ?? this.showModeSelector,
        showMyLocationButton: showMyLocationButton ?? this.showMyLocationButton,
        showUndoButton: showUndoButton ?? this.showUndoButton,
        showClearButton: showClearButton ?? this.showClearButton,
        showOptimizeButton: showOptimizeButton ?? this.showOptimizeButton,
        showMapTypeToggle: showMapTypeToggle ?? this.showMapTypeToggle,
        showExtendedMapTypes: showExtendedMapTypes ?? this.showExtendedMapTypes,
        showTrafficToggle: showTrafficToggle ?? this.showTrafficToggle,
        showBuildingsToggle: showBuildingsToggle ?? this.showBuildingsToggle,
        showIndoorViewToggle: showIndoorViewToggle ?? this.showIndoorViewToggle,
        showRotationToggle: showRotationToggle ?? this.showRotationToggle,
        showTiltToggle: showTiltToggle ?? this.showTiltToggle,
        showZoomControlsToggle:
            showZoomControlsToggle ?? this.showZoomControlsToggle,
        showCompassToggle: showCompassToggle ?? this.showCompassToggle,
        showMapToolbarToggle: showMapToolbarToggle ?? this.showMapToolbarToggle,
        useMapOptionsDropdown:
            useMapOptionsDropdown ?? this.useMapOptionsDropdown,
        mapOptionsLabel: mapOptionsLabel ?? this.mapOptionsLabel,
        showButtonLabels: showButtonLabels ?? this.showButtonLabels,
        compactMode: compactMode ?? this.compactMode,
        compactBreakpointDp: compactBreakpointDp ?? this.compactBreakpointDp,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGeoEditorToolbarConfig &&
          runtimeType == other.runtimeType &&
          disabled == other.disabled &&
          showModeSelector == other.showModeSelector &&
          showMyLocationButton == other.showMyLocationButton &&
          showUndoButton == other.showUndoButton &&
          showClearButton == other.showClearButton &&
          showOptimizeButton == other.showOptimizeButton &&
          showMapTypeToggle == other.showMapTypeToggle &&
          showExtendedMapTypes == other.showExtendedMapTypes &&
          showTrafficToggle == other.showTrafficToggle &&
          showBuildingsToggle == other.showBuildingsToggle &&
          showIndoorViewToggle == other.showIndoorViewToggle &&
          showRotationToggle == other.showRotationToggle &&
          showTiltToggle == other.showTiltToggle &&
          showZoomControlsToggle == other.showZoomControlsToggle &&
          showCompassToggle == other.showCompassToggle &&
          showMapToolbarToggle == other.showMapToolbarToggle &&
          useMapOptionsDropdown == other.useMapOptionsDropdown &&
          mapOptionsLabel == other.mapOptionsLabel &&
          showButtonLabels == other.showButtonLabels &&
          compactMode == other.compactMode &&
          compactBreakpointDp == other.compactBreakpointDp;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        runtimeType,
        disabled,
        showModeSelector,
        showMyLocationButton,
        showUndoButton,
        showClearButton,
        showOptimizeButton,
        showMapTypeToggle,
        showExtendedMapTypes,
        showTrafficToggle,
        showBuildingsToggle,
        showIndoorViewToggle,
        showRotationToggle,
        showTiltToggle,
        showZoomControlsToggle,
        showCompassToggle,
        showMapToolbarToggle,
        useMapOptionsDropdown,
        mapOptionsLabel,
        showButtonLabels,
        compactMode,
        compactBreakpointDp,
      ]);
}
