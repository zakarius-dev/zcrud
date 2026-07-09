/// `ZcrudTheme` — design-tokens sémantiques injectables (FR-26, AD-6).
///
/// origine : `ThemeExtension<ZcrudTheme>` résolu via `ZcrudScope` avec repli sur
/// `Theme.of(context)`. **AUCUN style codé en dur** dans le cœur (pas de
/// `kNavyColor`/`kFormInputDecorationTheme`) : les couleurs sémantiques sont
/// `nullable` et **dérivées** du `ColorScheme`/`TextTheme` courant par
/// [ZcrudTheme.fallback]. Les tokens d'espacement/rayon sont la **source
/// injectable** — ils sont exemptés de la garde couleur (ce ne sont pas des
/// couleurs).
///
/// INFLEXION E2-8 : ce fichier introduit `package:flutter/material.dart` sous
/// `presentation/` (requis par `ThemeExtension`/`Theme.of`/`ThemeData` — FR-26).
/// `cupertino`/`services`/`dart:ui`-direct restent interdits.
library;

import 'package:flutter/material.dart';

import '../zcrud_scope.dart';

/// Extension de thème du chrome CRUD (FR-26). Couleurs sémantiques dérivées au
/// repli ; espacements/rayons/insets directionnels comme tokens injectables.
@immutable
class ZcrudTheme extends ThemeExtension<ZcrudTheme> {
  /// Construit un thème. Les couleurs par défaut sont `null` (résolues au repli
  /// [fallback], dérivées du `ColorScheme`) ; les tokens d'espacement/rayon ont
  /// des valeurs par défaut sémantiques (aucune couleur).
  const ZcrudTheme({
    this.fieldBorderColor,
    this.errorColor,
    this.labelColor,
    this.surfaceColor,
    this.gapS = 4,
    this.gapM = 8,
    this.gapL = 16,
    this.radiusS = const Radius.circular(4),
    this.radiusM = const Radius.circular(8),
    this.fieldPadding = const EdgeInsetsDirectional.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
  });

  /// Repli **dérivé** de [theme] (FR-26 : « hérite du `Theme.of` »). Chaque
  /// couleur est lue depuis `ColorScheme`/`TextTheme` — **aucun littéral hex**.
  factory ZcrudTheme.fallback(ThemeData theme) {
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return ZcrudTheme(
      fieldBorderColor: scheme.outline,
      errorColor: scheme.error,
      labelColor: text.bodyMedium?.color ?? scheme.onSurface,
      surfaceColor: scheme.surface,
    );
  }

  /// Couleur de bordure de champ (repli : `ColorScheme.outline`).
  final Color? fieldBorderColor;

  /// Couleur d'erreur (repli : `ColorScheme.error`).
  final Color? errorColor;

  /// Couleur de libellé (repli : `TextTheme.bodyMedium.color`).
  final Color? labelColor;

  /// Couleur de surface (repli : `ColorScheme.surface`).
  final Color? surfaceColor;

  /// Échelle d'espacement — petit.
  final double gapS;

  /// Échelle d'espacement — moyen.
  final double gapM;

  /// Échelle d'espacement — grand.
  final double gapL;

  /// Rayon — petit.
  final Radius radiusS;

  /// Rayon — moyen.
  final Radius radiusM;

  /// Padding de champ **directionnel** (RTL-safe, AD-13).
  final EdgeInsetsDirectional fieldPadding;

  /// Résout le thème du chrome CRUD (FR-26, AD-6) :
  ///   `ZcrudScope.theme` → `Theme.of(context).extension<ZcrudTheme>()`
  ///   → `ZcrudTheme.fallback(Theme.of(context))`.
  static ZcrudTheme of(BuildContext context) {
    final fromScope = ZcrudScope.maybeOf(context)?.theme;
    if (fromScope != null) return fromScope;
    final theme = Theme.of(context);
    return theme.extension<ZcrudTheme>() ?? ZcrudTheme.fallback(theme);
  }

  @override
  ZcrudTheme copyWith({
    Color? fieldBorderColor,
    Color? errorColor,
    Color? labelColor,
    Color? surfaceColor,
    double? gapS,
    double? gapM,
    double? gapL,
    Radius? radiusS,
    Radius? radiusM,
    EdgeInsetsDirectional? fieldPadding,
  }) =>
      ZcrudTheme(
        fieldBorderColor: fieldBorderColor ?? this.fieldBorderColor,
        errorColor: errorColor ?? this.errorColor,
        labelColor: labelColor ?? this.labelColor,
        surfaceColor: surfaceColor ?? this.surfaceColor,
        gapS: gapS ?? this.gapS,
        gapM: gapM ?? this.gapM,
        gapL: gapL ?? this.gapL,
        radiusS: radiusS ?? this.radiusS,
        radiusM: radiusM ?? this.radiusM,
        fieldPadding: fieldPadding ?? this.fieldPadding,
      );

  @override
  ZcrudTheme lerp(ThemeExtension<ZcrudTheme>? other, double t) {
    if (other is! ZcrudTheme) return this;
    return ZcrudTheme(
      fieldBorderColor: Color.lerp(fieldBorderColor, other.fieldBorderColor, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      gapS: gapS + (other.gapS - gapS) * t,
      gapM: gapM + (other.gapM - gapM) * t,
      gapL: gapL + (other.gapL - gapL) * t,
      radiusS: Radius.lerp(radiusS, other.radiusS, t) ?? radiusS,
      radiusM: Radius.lerp(radiusM, other.radiusM, t) ?? radiusM,
      fieldPadding:
          EdgeInsetsDirectional.lerp(fieldPadding, other.fieldPadding, t) ??
              fieldPadding,
    );
  }
}
