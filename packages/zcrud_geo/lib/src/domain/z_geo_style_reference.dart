/// `ZGeoStyleReference` — **fichier de référence AUDITÉ** des presets de style
/// de forme legacy DODLP (CR geo G18, exception FR-26 encadrée, patron
/// `ZStudyCardReference`).
///
/// ## Ce que fait réellement le legacy DODLP (mesuré, pas cru)
///
/// `dodlp-otr/lib/modules/data_crud/models/geo_shape.dart:154-177` expose
/// 4 presets `GeoShapeStyle` bâtis sur le **bleu Google `0xFF4285F4`** :
///
/// | Preset legacy (`gs`) | Valeurs mesurées |
/// |---|---|
/// | `defaultPoint` (154-157) | `iconColor: 0xFF4285F4`, `strokeWidth: 0` |
/// | `defaultCircle` (159-164) | `fillColor: 0x334285F4`, `strokeColor: 0xFF4285F4`, `strokeWidth: 2` |
/// | `defaultPolygon` (166-171) | `fillColor: 0x334285F4`, `strokeColor: 0xFF4285F4`, `strokeWidth: 3` |
/// | `defaultPolyline` (173-177) | `strokeColor: 0xFF4285F4`, `strokeWidth: 3` |
///
/// ## Conditions de l'exception FR-26 (toutes remplies)
///
/// 1. **Centralisation** : ces ARGB legacy n'apparaissent QUE dans ce fichier
///    (jamais dans un widget ni un adaptateur — vérifiable par grep) ;
/// 2. **Remplaçables** : un style est TOUJOURS opt-in (`style` nullable sur
///    `ZGeoPoint`/`ZGeoCircle`/`ZGeoShape` — `null` ⇒ chaîne thème inchangée,
///    AD-4) et surchargeables champ à champ via `copyWith` ;
/// 3. **Exemption nominative** : aucune garde anti-couleurs n'existe dans
///    `zcrud_geo` à ce jour (grep négatif rejoué au montage G18) ; si une telle
///    garde est ajoutée, elle doit exempter CE fichier et lui seul.
library;

import 'z_geo_shape_style.dart';

/// Couleurs et presets de style de référence legacy (audités, opt-in).
/// Espace de noms statique : non instanciable.
abstract final class ZGeoStyleReference {
  /// Bleu Google legacy (`gs:155` — « Google Blue »), opaque.
  static const int legacyBlueArgb = 0xFF4285F4;

  /// Bleu Google legacy avec opacité de remplissage (`gs:161`).
  static const int legacyBlueFillArgb = 0x334285F4;

  /// Preset point/marqueur (parité `gs:154-157`).
  static const ZGeoShapeStyle defaultPoint = ZGeoShapeStyle(
    iconColorArgb: legacyBlueArgb,
    strokeWidth: 0,
  );

  /// Preset cercle (parité `gs:159-164`).
  static const ZGeoShapeStyle defaultCircle = ZGeoShapeStyle(
    fillColorArgb: legacyBlueFillArgb,
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 2,
  );

  /// Preset polygone (parité `gs:166-171`).
  static const ZGeoShapeStyle defaultPolygon = ZGeoShapeStyle(
    fillColorArgb: legacyBlueFillArgb,
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 3,
  );

  /// Preset polyligne (parité `gs:173-177`).
  static const ZGeoShapeStyle defaultPolyline = ZGeoShapeStyle(
    strokeColorArgb: legacyBlueArgb,
    strokeWidth: 3,
  );
}
