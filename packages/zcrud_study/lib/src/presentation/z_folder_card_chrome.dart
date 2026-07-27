/// Surfaces décoratives injectables de [ZFolderCard].
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Barre d'accent optionnelle pour [ZFolderCard.headerDecoration].
///
/// [gradientKey] est l'identité persistante et opaque du dossier (par exemple
/// son id). Ce n'est jamais un index de liste, de pagination, de tri ou de
/// filtre : un dossier doit conserver son dégradé quand son ordre d'affichage
/// change. Sans clé, resolver ou tokens complets, ce widget est
/// structurellement absent.
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
    final AlignmentGeometry? begin = theme.gradientBegin;
    final AlignmentGeometry? end = theme.gradientEnd;
    final ZGradientSpec? spec = zResolveGradient(context, gradientKey);
    if (spec == null || height == null || begin == null || end == null) {
      return const SizedBox.shrink();
    }

    final Gradient gradient = switch (spec.gradient) {
      final LinearGradient linear => LinearGradient(
        colors: linear.colors,
        stops: linear.stops,
        begin: begin,
        end: end,
        tileMode: linear.tileMode,
        transform: linear.transform,
      ),
      _ => spec.gradient,
    };

    return Container(
      width: theme.iconContainerSize ?? theme.gapL,
      height: height,
      decoration: BoxDecoration(gradient: gradient),
    );
  }
}
