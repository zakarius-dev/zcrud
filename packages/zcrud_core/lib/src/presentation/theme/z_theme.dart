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
    this.inputRadius = const Radius.circular(12),
    this.inputBorderWidth = 1,
    this.inputFocusedBorderWidth = 2,
    this.inputContentPadding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    this.inputFilled = true,
    this.helperMaxLines = 2,
    this.floatingLabelWeight = FontWeight.bold,
    this.labelTextStyle,
    this.inputTextStyle,
    this.hintTextStyle = const TextStyle(overflow: TextOverflow.clip),
    this.largeMinHeight = 64,
    this.largePadding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.largeLabelTextStyle = const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
    ),
    this.largeLeadingIconSize = 22,
    this.largeLeadingGap = 12,
    this.largeLabelGap = 4,
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

  // ── Tokens de décoration d'`InputDecoration` (parité DODLP M2) ────────────
  // Aucune couleur : les couleurs de bordure/remplissage sont TOUJOURS dérivées
  // du `ColorScheme` courant par [inputDecoration] (FR-26).

  /// Rayon de bordure des `InputDecoration` (défaut `12` — parité DODLP).
  final Radius inputRadius;

  /// Épaisseur de bordure enabled/normale (défaut `1`).
  final double inputBorderWidth;

  /// Épaisseur de bordure au focus (défaut `2`).
  final double inputFocusedBorderWidth;

  /// Padding interne **directionnel** de l'`InputDecoration` (défaut `16/16`).
  final EdgeInsetsDirectional inputContentPadding;

  /// Fond rempli (`filled`) des champs (défaut `true` — la couleur de
  /// remplissage est dérivée de la surface du `ColorScheme`).
  final bool inputFilled;

  /// Nombre maximal de lignes du helper/erreur (défaut `2`).
  final int helperMaxLines;

  /// Poids du label flottant (défaut `FontWeight.bold`).
  final FontWeight floatingLabelWeight;

  /// Style **non-couleur** du label (poids/taille ; `color == null` → dérivé).
  final TextStyle? labelTextStyle;

  /// Style **non-couleur** du texte saisi (`color == null` → dérivé).
  final TextStyle? inputTextStyle;

  /// Style **non-couleur** du hint (défaut : `overflow: clip` conforme DODLP).
  final TextStyle? hintTextStyle;

  // ── Tokens de la variante `large` (Card — parité DODLP `_buildLargeCard`) ──

  /// Hauteur minimale de la Card `large` (défaut `64`).
  final double largeMinHeight;

  /// Padding interne **directionnel** de la Card `large` (défaut `16/12`).
  final EdgeInsetsDirectional largePadding;

  /// Style **non-couleur** du label au-dessus du champ en `large` (défaut :
  /// `w500`, taille `16` — parité `bodyLarge`/`_buildLabelWidget`).
  final TextStyle? largeLabelTextStyle;

  /// Taille de l'icône leading en `large` (défaut `22`).
  final double largeLeadingIconSize;

  /// Écart entre le leading et la colonne label/champ en `large` (défaut `12`).
  final double largeLeadingGap;

  /// Écart vertical entre le label et le champ en `large` (défaut `4`).
  final double largeLabelGap;

  /// Fabrique centrale d'`InputDecoration` (M2, AC10) : assemble la décoration à
  /// partir des tokens ci-dessus + des **couleurs dérivées** du `ColorScheme`
  /// courant (bordure `outline`, focus `primary`, erreur `error`, remplissage
  /// dérivé de la surface). AUCUNE couleur codée en dur (FR-26).
  ///
  /// En mode [bare] (usage interne à la Card `large`, AC4) : bordures `none`,
  /// `isDense`, padding zéro, non rempli, **sans** label/floating-label (le label
  /// est porté par la Card).
  InputDecoration inputDecoration(
    BuildContext context, {
    String? label,
    String? hintText,
    String? helperText,
    String? errorText,
    bool bare = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (bare) {
      return InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        hintText: hintText,
        hintStyle: hintTextStyle,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
        errorText: errorText,
        errorMaxLines: helperMaxLines,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      );
    }
    final radius = BorderRadius.all(inputRadius);
    OutlineInputBorder borderOf(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: hintTextStyle,
      helperText: helperText,
      helperMaxLines: helperMaxLines,
      errorText: errorText,
      errorMaxLines: helperMaxLines,
      labelStyle: labelTextStyle,
      floatingLabelStyle: (labelTextStyle ?? const TextStyle())
          .copyWith(fontWeight: floatingLabelWeight),
      filled: inputFilled,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: inputContentPadding,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: borderOf(scheme.outline, inputBorderWidth),
      enabledBorder: borderOf(scheme.outline, inputBorderWidth),
      focusedBorder: borderOf(scheme.primary, inputFocusedBorderWidth),
      errorBorder: borderOf(scheme.error, inputBorderWidth),
      focusedErrorBorder: borderOf(scheme.error, inputFocusedBorderWidth),
    );
  }

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
    Radius? inputRadius,
    double? inputBorderWidth,
    double? inputFocusedBorderWidth,
    EdgeInsetsDirectional? inputContentPadding,
    bool? inputFilled,
    int? helperMaxLines,
    FontWeight? floatingLabelWeight,
    TextStyle? labelTextStyle,
    TextStyle? inputTextStyle,
    TextStyle? hintTextStyle,
    double? largeMinHeight,
    EdgeInsetsDirectional? largePadding,
    TextStyle? largeLabelTextStyle,
    double? largeLeadingIconSize,
    double? largeLeadingGap,
    double? largeLabelGap,
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
        inputRadius: inputRadius ?? this.inputRadius,
        inputBorderWidth: inputBorderWidth ?? this.inputBorderWidth,
        inputFocusedBorderWidth:
            inputFocusedBorderWidth ?? this.inputFocusedBorderWidth,
        inputContentPadding: inputContentPadding ?? this.inputContentPadding,
        inputFilled: inputFilled ?? this.inputFilled,
        helperMaxLines: helperMaxLines ?? this.helperMaxLines,
        floatingLabelWeight: floatingLabelWeight ?? this.floatingLabelWeight,
        labelTextStyle: labelTextStyle ?? this.labelTextStyle,
        inputTextStyle: inputTextStyle ?? this.inputTextStyle,
        hintTextStyle: hintTextStyle ?? this.hintTextStyle,
        largeMinHeight: largeMinHeight ?? this.largeMinHeight,
        largePadding: largePadding ?? this.largePadding,
        largeLabelTextStyle: largeLabelTextStyle ?? this.largeLabelTextStyle,
        largeLeadingIconSize: largeLeadingIconSize ?? this.largeLeadingIconSize,
        largeLeadingGap: largeLeadingGap ?? this.largeLeadingGap,
        largeLabelGap: largeLabelGap ?? this.largeLabelGap,
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
      inputRadius: Radius.lerp(inputRadius, other.inputRadius, t) ?? inputRadius,
      inputBorderWidth:
          inputBorderWidth + (other.inputBorderWidth - inputBorderWidth) * t,
      inputFocusedBorderWidth: inputFocusedBorderWidth +
          (other.inputFocusedBorderWidth - inputFocusedBorderWidth) * t,
      inputContentPadding: EdgeInsetsDirectional.lerp(
              inputContentPadding, other.inputContentPadding, t) ??
          inputContentPadding,
      // Tokens discrets (non interpolables) : bascule au point milieu.
      inputFilled: t < 0.5 ? inputFilled : other.inputFilled,
      helperMaxLines: t < 0.5 ? helperMaxLines : other.helperMaxLines,
      floatingLabelWeight:
          FontWeight.lerp(floatingLabelWeight, other.floatingLabelWeight, t) ??
              floatingLabelWeight,
      labelTextStyle: TextStyle.lerp(labelTextStyle, other.labelTextStyle, t),
      inputTextStyle: TextStyle.lerp(inputTextStyle, other.inputTextStyle, t),
      hintTextStyle: TextStyle.lerp(hintTextStyle, other.hintTextStyle, t),
      largeMinHeight:
          largeMinHeight + (other.largeMinHeight - largeMinHeight) * t,
      largePadding:
          EdgeInsetsDirectional.lerp(largePadding, other.largePadding, t) ??
              largePadding,
      largeLabelTextStyle:
          TextStyle.lerp(largeLabelTextStyle, other.largeLabelTextStyle, t),
      largeLeadingIconSize: largeLeadingIconSize +
          (other.largeLeadingIconSize - largeLeadingIconSize) * t,
      largeLeadingGap:
          largeLeadingGap + (other.largeLeadingGap - largeLeadingGap) * t,
      largeLabelGap: largeLabelGap + (other.largeLabelGap - largeLabelGap) * t,
    );
  }
}
