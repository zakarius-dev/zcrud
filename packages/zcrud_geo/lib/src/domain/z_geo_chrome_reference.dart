/// `ZGeoChromeReference` — **fichier de référence AUDITÉ** du chrome de carte
/// legacy DODLP (G19/G20/G23, exception FR-26 encadrée, patron
/// `ZStudyCardReference` — même statut que `ZGeoStyleReference`).
///
/// ## Ce que fait réellement le legacy (mesuré, pas cru)
///
/// `geofence_field.dart` :
///
/// | Valeur | Mesure legacy |
/// |---|---|
/// | Dégradé d'en-tête | `gff:168` — `[0xFF667EEA, 0xFF764BA2]` (violet, non dérivable du `ColorScheme`) |
/// | Rayon de l'encart | `gff:1408` — `BorderRadius.circular(14)` (en-tête : 13, `gff:1437`) |
/// | Bordure | `gff:1409-1414` — teinte du dégradé alpha 80, épaisseur 1.5 si contenu (sinon 1) |
/// | Ombre | `gff:1415-1423` — teinte du dégradé alpha 10 (15 sombre), blur 8, offset (0, 2) |
/// | Hauteur de carte | `gff:1579-1581` — **300 px en dur** |
/// | Seuil compact | `gff:776,880` — `MediaQuery.width < 600` |
/// | Zoom OSM | `oma:162-167` — min **3**, max **19**, pas **1.0** |
///
/// ## Conditions de l'exception FR-26 (toutes remplies)
///
/// 1. **Centralisation** : ces valeurs n'apparaissent QUE dans ce fichier
///    (jamais dans un widget — vérifiable par grep) ;
/// 2. **Remplaçables** : le chrome est **opt-in** (`ZGeoFieldConfig.showChrome`,
///    défaut `false` ⇒ rendu antérieur strictement inchangé — AD-4) et chaque
///    dimension surchargeable (hauteur via `mapHeight`, seuil via
///    `ZGeoEditorToolbarConfig.compactBreakpointDp`, zoom via
///    `ZGeoFieldConfig.minZoom`/`maxZoom`/`zoomStep`) ; les couleurs du chrome
///    dérivent du thème injecté PARTOUT où un rôle existe — seul le dégradé
///    d'en-tête legacy (non dérivable) entre ici, en repli d'un jeton nullable ;
/// 3. **Exemption nominative** : si une garde anti-couleurs est ajoutée à
///    `zcrud_geo`, elle doit exempter ce fichier et `z_geo_style_reference.dart`
///    et eux seuls.
///
/// **Pur-Dart (AD-14)** : entiers ARGB et doubles uniquement, aucun `Color`.
library;

/// Valeurs de chrome de référence legacy (auditées, opt-in).
/// Espace de noms statique : non instanciable.
abstract final class ZGeoChromeReference {
  /// 1re couleur du dégradé d'en-tête legacy (`gff:168`).
  static const int headerGradientStartArgb = 0xFF667EEA;

  /// 2e couleur du dégradé d'en-tête legacy (`gff:168`).
  static const int headerGradientEndArgb = 0xFF764BA2;

  /// Rayon de l'encart carte (`gff:1408`).
  static const double cardRadius = 14;

  /// Rayon intérieur de l'en-tête (`gff:1437` — rayon de l'encart − 1).
  static const double headerRadius = 13;

  /// Épaisseur de bordure quand le champ porte une valeur (`gff:1413`).
  static const double borderWidthWithContent = 1.5;

  /// Épaisseur de bordure sans valeur (`gff:1413`).
  static const double borderWidthEmpty = 1;

  /// Flou de l'ombre de l'encart (`gff:1420`).
  static const double shadowBlurRadius = 8;

  /// Décalage vertical de l'ombre (`gff:1421`).
  static const double shadowOffsetY = 2;

  /// Hauteur de carte du mode chrome (`gff:1580` — 300 px en dur legacy).
  ///
  /// **Décision hauteur (G19, justification écrite)** : le défaut du widget
  /// zcrud reste **200** (`ZGeoFieldWidget.mapHeight` — le changer casserait la
  /// mise en page de tout hôte existant, pendant du handoff G22) ; le mode
  /// **chrome opt-in** — qui EST le look legacy — porte la hauteur legacy 300.
  /// `ZGeoFieldConfig.mapHeight` prime dans les deux modes.
  static const double chromeMapHeight = 300;

  /// Seuil de compaction responsive de la barre d'outils (`gff:776,880` —
  /// largeur < 600 ⇒ mode compact). Surchargeable via
  /// `ZGeoEditorToolbarConfig.compactBreakpointDp` (G20).
  static const double compactBreakpointDp = 600;

  /// Zoom minimal OSM legacy (`oma:164`).
  static const double osmMinZoom = 3;

  /// Zoom maximal OSM legacy (`oma:165`).
  static const double osmMaxZoom = 19;

  /// Pas de zoom OSM legacy (`oma:166`). **Note d'honnêteté (G23)** : exposé
  /// comme donnée de référence/config ; AUCUN des deux adaptateurs actuels ne
  /// le consomme (`flutter_map` n'a pas de pas de zoom natif, Google non plus —
  /// le legacy le passait au plugin `flutter_osm_plugin`, SDK non retenu).
  static const double osmZoomStep = 1.0;
}
