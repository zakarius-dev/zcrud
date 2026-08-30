/// Surfaces décoratives injectables de [ZFolderCard].
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_gradient_geometry.dart';

/// Barre d'accent optionnelle pour [ZFolderCard.headerDecoration].
///
/// [gradientKey] est l'identité persistante et opaque du dossier (par exemple
/// son id). Ce n'est jamais un index de liste, de pagination, de tri ou de
/// filtre : un dossier doit conserver son dégradé quand son ordre d'affichage
/// change. Sans clé, resolver ou tokens complets, ce widget est
/// structurellement absent.
///
/// Les jetons `ZcrudTheme.gradientBegin` / `gradientEnd` donnent sa géométrie
/// au dégradé qui n'en déclare pas ; un dégradé qui déclare la sienne la
/// conserve (invariant AD-13).
class ZFolderCardGradientAccent extends StatelessWidget {
  /// Construit une barre d'accent résolue par la couture hôte.
  const ZFolderCardGradientAccent({required this.gradientKey, super.key});

  /// Identité persistante du dossier, jamais son index d'affichage.
  final String gradientKey;

  @override
  Widget build(BuildContext context) {
    if (gradientKey.isEmpty) return const SizedBox.shrink();

    final ZcrudTheme theme = ZcrudTheme.of(context);
    final double? height = theme.accentBarHeight;
    final ZGradientSpec? spec = zResolveGradient(context, gradientKey);
    if (spec == null || height == null || !zHasGradientGeometryTokens(theme)) {
      return const SizedBox.shrink();
    }

    final Gradient gradient = zApplyThemedGradientGeometry(
      spec.gradient,
      theme,
    );

    return Container(
      width: theme.iconContainerSize ?? theme.gapL,
      height: height,
      decoration: BoxDecoration(gradient: gradient),
    );
  }
}
