/// `ZGeoChromeReference` — **fichier de référence audité** des dimensions et
/// couleurs du chrome de carte optionnel (encart, en-tête, seuils de zoom).
///
/// Ces valeurs sont un point d'audit unique pour un rendu de référence non
/// dérivable du thème courant (notamment le dégradé d'en-tête, une couleur
/// fixe qui n'a pas d'équivalent dans un `ColorScheme`). Toutes les autres
/// couleurs du chrome dérivent du thème injecté ; seules les valeurs
/// réellement non dérivables entrent ici, en repli d'un jeton nullable.
///
/// **Conditions d'utilisation** :
///
/// 1. **Centralisation** : ces valeurs n'apparaissent que dans ce fichier —
///    jamais directement dans un widget ;
/// 2. **Remplaçables** : le chrome est **opt-in**
///    (`ZGeoFieldConfig.showChrome`, défaut `false` ⇒ rendu inchangé sans
///    lui) et chaque dimension est surchargeable (hauteur via `mapHeight`,
///    seuil via `ZGeoEditorToolbarConfig.compactBreakpointDp`, zoom via
///    `ZGeoFieldConfig.minZoom`/`maxZoom`/`zoomStep`).
///
/// **Pur-Dart (invariant AD-14)** : entiers ARGB et doubles uniquement,
/// aucun `Color`.
library;

/// Valeurs de chrome de référence legacy (auditées, opt-in).
/// Espace de noms statique : non instanciable.
abstract final class ZGeoChromeReference {
  /// 1re couleur du dégradé d'en-tête legacy (`gff:168`).
  static const int headerGradientStartArgb = 0xFF667EEA;

  /// 2e couleur du dégradé d'en-tête de référence.
  static const int headerGradientEndArgb = 0xFF764BA2;

  /// Rayon de l'encart carte.
  static const double cardRadius = 14;

  /// Rayon intérieur de l'en-tête (rayon de l'encart − 1).
  static const double headerRadius = 13;

  /// Épaisseur de bordure quand le champ porte une valeur.
  static const double borderWidthWithContent = 1.5;

  /// Épaisseur de bordure sans valeur.
  static const double borderWidthEmpty = 1;

  /// Flou de l'ombre de l'encart.
  static const double shadowBlurRadius = 8;

  /// Décalage vertical de l'ombre.
  static const double shadowOffsetY = 2;

  /// Hauteur de carte du mode chrome.
  ///
  /// Le défaut du widget hors mode chrome reste **200**
  /// (`ZGeoFieldWidget.mapHeight`, pour ne perturber la mise en page d'aucun
  /// hôte existant) ; le mode chrome, lui, porte cette hauteur de référence
  /// **300**. `ZGeoFieldConfig.mapHeight` prime dans les deux modes.
  static const double chromeMapHeight = 300;

  /// Seuil de compaction responsive de la barre d'outils — largeur < 600 ⇒
  /// mode compact. Surchargeable via
  /// `ZGeoEditorToolbarConfig.compactBreakpointDp`.
  static const double compactBreakpointDp = 600;

  /// Zoom minimal de référence pour l'adaptateur OSM.
  static const double osmMinZoom = 3;

  /// Zoom maximal de référence pour l'adaptateur OSM.
  static const double osmMaxZoom = 19;

  /// Pas de zoom de référence pour l'adaptateur OSM. Exposé comme donnée de
  /// référence/config : aucun des deux adaptateurs fournis (OSM, Google) ne
  /// le consomme, ni l'un ni l'autre n'offrant de pas de zoom natif —
  /// honnêteté documentée plutôt qu'une simulation.
  static const double osmZoomStep = 1.0;
}
