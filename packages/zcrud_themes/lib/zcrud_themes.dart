/// Thèmes visuels nommés pour zcrud : des palettes auditées et des fabriques
/// de `ZcrudTheme` prêtes à poser, qui habillent les widgets EXISTANTS de la
/// boîte à outils.
///
/// ## Ce paquet ne rend aucun widget
///
/// Il n'exporte que des valeurs de design et des fabriques. Un widget ici
/// créerait un rendu concurrent de celui des paquets d'écrans — le doublon
/// exact qu'une boîte à outils partagée existe pour supprimer. Une garde le
/// vérifie sur la surface publique.
///
/// ## Adoption
///
/// ```dart
/// ZcrudScope(
///   theme: ZClassicTheme.of(context),
///   colorKeyResolver: ZClassicTheme.colorKeys,
///   gradientResolver: ZClassicTheme.gradients,
///   child: MonApp(),
/// )
/// ```
library;

export 'src/themes/classic/z_classic_card_gradients_reference.dart';
export 'src/themes/classic/z_classic_celebration_reference.dart';
export 'src/themes/classic/z_classic_srs_palette_reference.dart';
export 'src/themes/classic/z_classic_surface_reference.dart';
export 'src/themes/classic/z_classic_theme.dart';
export 'src/z_theme_catalog.dart';
