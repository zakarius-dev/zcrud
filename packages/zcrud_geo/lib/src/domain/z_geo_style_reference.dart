/// `ZGeoStyleReference` — **fichier de référence audité** des presets de
/// style de forme par défaut, bâtis sur un bleu de référence
/// (`0xFF4285F4`).
///
/// Point d'audit unique des couleurs de référence :
///
/// 1. **Centralisation** : ces ARGB n'apparaissent que dans ce fichier —
///    jamais dans un widget ni un adaptateur ;
/// 2. **Remplaçables** : un style est toujours **opt-in** (`style` nullable
///    sur `ZGeoPoint`/`ZGeoCircle`/`ZGeoShape` — `null` ⇒ rendu dérivé du
///    thème injecté) et surchargeable champ à champ via `copyWith`.
library;

import 'z_geo_shape_style.dart';

/// Couleurs et presets de style de référence (audités, opt-in). Espace de
/// noms statique : non instanciable.
abstract final class ZGeoStyleReference {
  /// Bleu de référence, opaque.
  static const int legacyBlueArgb = 0xFF4285F4;

  /// Bleu de référence avec opacité de remplissage.
  static const int legacyBlueFillArgb = 0x334285F4;

  /// Preset point/marqueur.
  static const ZGeoShapeStyle defaultPoint = ZGeoShapeStyle(
    iconColorArgb: legacyBlueArgb,
    strokeWidth: 0,
  );

  /// Preset cercle.
  static const ZGeoShapeStyle defaultCircle = ZGeoShapeStyle(
    fillColorArgb: legacyBlueFillArgb,
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 2,
  );

  /// Preset polygone.
  static const ZGeoShapeStyle defaultPolygon = ZGeoShapeStyle(
    fillColorArgb: legacyBlueFillArgb,
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 3,
  );

  /// Preset polyligne.
  static const ZGeoShapeStyle defaultPolyline = ZGeoShapeStyle(
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 3,
  );
}
