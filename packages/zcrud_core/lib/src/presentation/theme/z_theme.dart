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

/// Habillage du **déclencheur** d'une surface de navigation (barre repliée
/// montrant l'élément courant) — token de LOOK, jamais de structure.
///
/// 🔴 **Aucune couleur ici.** Chaque valeur nomme un RÔLE de conteneur Material,
/// que le consommateur traduit en `ColorScheme` : c'est ce qui permet à un hôte
/// de demander « contour » ou « rempli » sans qu'un seul hex n'entre dans un
/// paquet (FR-26/NFR-S7).
enum ZSubfolderTriggerVariant {
  /// Aucun conteneur : le déclencheur est une simple ligne cliquable.
  /// **Rendu historique** — c'est ce que rend un thème qui ne déclare rien.
  flat,

  /// Conteneur à **contour** (bordure `ColorScheme.outlineVariant`, fond
  /// transparent) — l'habillage `Card.outlined` de la maquette IFFD.
  outlined,

  /// Conteneur **rempli** (`ColorScheme.surfaceContainerHighest`, sans bordure).
  filled,
}

/// Manière dont l'élément COURANT se distingue dans une liste de navigation —
/// token de LOOK.
///
/// 🔴 **L'inversion n'est pas un surlignage plus foncé.** `highlight` teinte le
/// fond en laissant le texte hériter de la couleur ambiante ; [inverted]
/// **retourne le couple** : fond `ColorScheme.inverseSurface`, **texte ET icônes
/// en `onInverseSurface`**. C'est ce couple de rôles — et non deux hex — qui
/// porte la capacité : quel que soit le `ColorScheme` (clair, sombre, seedé),
/// `inverseSurface`/`onInverseSurface` sont par définition le contraste maximal
/// disponible, et le paquet n'a jamais à connaître une couleur.
enum ZSubfolderSelectedEmphasis {
  /// Fond `ColorScheme.secondaryContainer`, premier plan **inchangé** (hérité).
  /// **Rendu historique.**
  highlight,

  /// Fond `ColorScheme.inverseSurface`, premier plan **forcé** à
  /// `ColorScheme.onInverseSurface` (texte *et* glyphes, y compris ceux d'un
  /// `itemBuilder` injecté).
  inverted,
}

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
    this.badgeRadius,
    this.fieldPadding = const EdgeInsetsDirectional.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.formPadding = const EdgeInsetsDirectional.all(12),
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
    this.readCardMargin = const EdgeInsetsDirectional.only(bottom: 12),
    this.readPadding = const EdgeInsetsDirectional.all(16),
    this.readLabelGap = 8,
    this.readLabelTextStyle,
    this.readValueTextStyle = const TextStyle(fontWeight: FontWeight.w500),
    this.accentBarHeight,
    this.gradientBegin,
    this.gradientEnd,
    this.cardShadowBlurRadius,
    this.cardShadowOffset,
    this.cardShadowAlpha,
    this.cardTintAlpha,
    this.iconContainerSize,
    this.iconContainerRadius,
    this.countPillPadding,
    this.countPillRadius,
    this.countPillIconSize,
    this.celebrationDuration,
    this.celebrationCurve,
    this.flipDuration,
    this.flipCurve,
    this.subfolderTriggerVariant,
    this.subfolderTriggerCollapsedIcon,
    this.subfolderTriggerExpandedIcon,
    this.subfolderSelectedEmphasis,
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

  /// Rayon des badges. `null` conserve le rayon moyen [radiusM], afin que les
  /// thèmes existants gardent strictement leur rendu.
  final Radius? badgeRadius;

  /// Padding de champ **directionnel** (RTL-safe, AD-13).
  final EdgeInsetsDirectional fieldPadding;

  /// **Aération du formulaire** (AD-54, FR-26) : padding **directionnel** posé par
  /// `DynamicEdition` autour de la liste des champs **quand `padding == null`**
  /// (défaut `all(12)` — parité DODLP). Token d'espacement injectable (aucune
  /// couleur ; exempté de la garde couleur). Un `padding` explicite passé à
  /// `DynamicEdition` prime toujours sur ce repli.
  final EdgeInsetsDirectional formPadding;

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

  // ── Tokens du mode LECTURE (fiche `ZReadOnlyFieldCard` — DP-13, parité DODLP
  //    `readOnlyWidget`). Aucune couleur : fond/bordure DÉRIVÉS du `ColorScheme`
  //    (FR-26). Réutilise `inputRadius`/`inputBorderWidth` pour la forme. ───────

  /// Marge basse **directionnelle** entre deux fiches de lecture (défaut
  /// `only(bottom: 12)` — parité `margin: only(bottom:12)`).
  final EdgeInsetsDirectional readCardMargin;

  /// Padding interne **directionnel** de la fiche de lecture (défaut `all(16)`).
  final EdgeInsetsDirectional readPadding;

  /// Écart vertical entre le label et la valeur dans la fiche (défaut `8`).
  final double readLabelGap;

  /// Style **non-couleur** du label de la fiche (`color == null` → dérivé
  /// `labelMedium`). Défaut `null`.
  final TextStyle? readLabelTextStyle;

  /// Style **non-couleur** de la valeur de la fiche (`color == null` → dérivé ;
  /// défaut poids `w500`).
  final TextStyle? readValueTextStyle;

  /// Hauteur future de la barre d'accent. `null` conserve v0.19.3 inchangé.
  final double? accentBarHeight;

  /// Début directionnel du dégradé. `null` conserve v0.19.3 inchangé.
  final AlignmentGeometry? gradientBegin;

  /// Fin directionnelle du dégradé. `null` conserve v0.19.3 inchangé.
  final AlignmentGeometry? gradientEnd;

  /// Flou de l'ombre de carte. `null` conserve v0.19.3 inchangé.
  final double? cardShadowBlurRadius;

  /// Décalage de l'ombre de carte. `null` conserve v0.19.3 inchangé.
  final Offset? cardShadowOffset;

  /// Opacité de l'ombre de carte. `null` conserve v0.19.3 inchangé.
  final double? cardShadowAlpha;

  /// Opacité de teinte de carte. `null` conserve v0.19.3 inchangé.
  final double? cardTintAlpha;

  /// Taille future du conteneur d'icône. `null` conserve v0.19.3 inchangé.
  final double? iconContainerSize;

  /// Rayon futur du conteneur d'icône. `null` conserve v0.19.3 inchangé.
  final Radius? iconContainerRadius;

  /// Padding directionnel de la pastille de compteur. `null` conserve v0.19.3.
  final EdgeInsetsDirectional? countPillPadding;

  /// Rayon de la pastille de compteur. `null` conserve v0.19.3 inchangé.
  final Radius? countPillRadius;

  /// Taille d'icône de la pastille de compteur. `null` conserve v0.19.3.
  final double? countPillIconSize;

  /// Durée de célébration. `null` conserve v0.19.3 inchangé.
  final Duration? celebrationDuration;

  /// Courbe de célébration. `null` conserve v0.19.3 inchangé.
  final Curve? celebrationCurve;

  /// Durée de retournement. `null` conserve v0.19.3 inchangé.
  final Duration? flipDuration;

  /// Courbe de retournement. `null` conserve v0.19.3 inchangé.
  final Curve? flipCurve;

  /// Habillage du déclencheur de navigation de fratrie (CR-IFFD-41, point 1).
  /// `null` ⇒ [ZSubfolderTriggerVariant.flat], rendu **strictement inchangé**.
  final ZSubfolderTriggerVariant? subfolderTriggerVariant;

  /// Glyphe du chevron quand la fratrie est **fermée** (CR-IFFD-41, point 2).
  /// `null` ⇒ repli conventionnel du consommateur (`Icons.expand_more`).
  ///
  /// Un `IconData` est un **glyphe**, jamais un libellé : il ne se traduit pas.
  /// Il reste néanmoins un choix de LOOK, donc injecté et non figé.
  final IconData? subfolderTriggerCollapsedIcon;

  /// Glyphe du chevron quand la fratrie est **ouverte** (CR-IFFD-41, point 2).
  /// `null` ⇒ repli conventionnel du consommateur (`Icons.expand_less`).
  final IconData? subfolderTriggerExpandedIcon;

  /// Mise en évidence de l'élément courant (CR-IFFD-41, point 6).
  /// `null` ⇒ [ZSubfolderSelectedEmphasis.highlight], rendu **inchangé**.
  final ZSubfolderSelectedEmphasis? subfolderSelectedEmphasis;

  /// Fabrique centrale d'`InputDecoration` (M2, AC10) : assemble la décoration à
  /// partir des tokens ci-dessus + des **couleurs dérivées** du `ColorScheme`
  /// courant (bordure `outline`, focus `primary`, erreur `error`, remplissage
  /// dérivé de la surface). AUCUNE couleur codée en dur (FR-26).
  ///
  /// En mode [bare] (usage interne à la Card `large`, AC4) : bordures `none`,
  /// `isDense`, padding zéro, non rempli, **sans** label/floating-label (le label
  /// est porté par la Card).
  /// Paramètres **additifs DP-12 (M1/M5/M6)** — défauts préservant DP-1 :
  /// - [labelWidget] : label **enrichi** (`ZFieldLabel`) ; s'il est fourni, il
  ///   prime sur [label] (String) — mutuellement exclusifs côté Flutter (`label`
  ///   Widget vs `labelText`). En `bare`, aucun label n'est posé (porté par la
  ///   Card), quelle que soit la valeur ;
  /// - [prefix]/[suffix] : ornements **texte** (`InputDecoration.prefix`/`suffix`)
  ///   résolus depuis `ZFieldAdornment.text` ;
  /// - [prefixIcon]/[suffixIcon] : ornements **icône** (déjà présents DP-1) ;
  /// - [leadingIcon] : ornement de **tête** hors bordure (`InputDecoration.icon`)
  ///   résolu depuis `ZFieldSpec.leading`.
  ///
  /// Aucune signature existante cassée ; aucune couleur en dur ajoutée (FR-26).
  InputDecoration inputDecoration(
    BuildContext context, {
    String? label,
    String? hintText,
    String? helperText,
    String? errorText,
    bool bare = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Widget? labelWidget,
    Widget? prefix,
    Widget? suffix,
    Widget? leadingIcon,
    String? suffixText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (bare) {
      // `bare` (Card large) : jamais de label propre (porté par la Card) ; les
      // ornements internes prefix/suffix/icon restent portés si fournis (AC9).
      return InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        icon: leadingIcon,
        hintText: hintText,
        hintStyle: hintTextStyle,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
        errorText: errorText,
        errorMaxLines: helperMaxLines,
        prefix: prefix,
        suffix: suffix,
        suffixText: suffixText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      );
    }
    final radius = BorderRadius.all(inputRadius);
    OutlineInputBorder borderOf(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      // Label enrichi (Widget) prioritaire ; sinon `labelText` (String). Les deux
      // sont mutuellement exclusifs côté Flutter.
      label: labelWidget,
      labelText: labelWidget == null ? label : null,
      icon: leadingIcon,
      hintText: hintText,
      hintStyle: hintTextStyle,
      helperText: helperText,
      helperMaxLines: helperMaxLines,
      errorText: errorText,
      errorMaxLines: helperMaxLines,
      labelStyle: labelTextStyle,
      floatingLabelStyle: (labelTextStyle ?? const TextStyle()).copyWith(
        fontWeight: floatingLabelWeight,
      ),
      filled: inputFilled,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: inputContentPadding,
      prefix: prefix,
      suffix: suffix,
      suffixText: suffixText,
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
    Radius? badgeRadius,
    EdgeInsetsDirectional? fieldPadding,
    EdgeInsetsDirectional? formPadding,
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
    EdgeInsetsDirectional? readCardMargin,
    EdgeInsetsDirectional? readPadding,
    double? readLabelGap,
    TextStyle? readLabelTextStyle,
    TextStyle? readValueTextStyle,
    double? accentBarHeight,
    AlignmentGeometry? gradientBegin,
    AlignmentGeometry? gradientEnd,
    double? cardShadowBlurRadius,
    Offset? cardShadowOffset,
    double? cardShadowAlpha,
    double? cardTintAlpha,
    double? iconContainerSize,
    Radius? iconContainerRadius,
    EdgeInsetsDirectional? countPillPadding,
    Radius? countPillRadius,
    double? countPillIconSize,
    Duration? celebrationDuration,
    Curve? celebrationCurve,
    Duration? flipDuration,
    Curve? flipCurve,
    ZSubfolderTriggerVariant? subfolderTriggerVariant,
    IconData? subfolderTriggerCollapsedIcon,
    IconData? subfolderTriggerExpandedIcon,
    ZSubfolderSelectedEmphasis? subfolderSelectedEmphasis,
  }) => ZcrudTheme(
    fieldBorderColor: fieldBorderColor ?? this.fieldBorderColor,
    errorColor: errorColor ?? this.errorColor,
    labelColor: labelColor ?? this.labelColor,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    gapS: gapS ?? this.gapS,
    gapM: gapM ?? this.gapM,
    gapL: gapL ?? this.gapL,
    radiusS: radiusS ?? this.radiusS,
    radiusM: radiusM ?? this.radiusM,
    badgeRadius: badgeRadius ?? this.badgeRadius,
    fieldPadding: fieldPadding ?? this.fieldPadding,
    formPadding: formPadding ?? this.formPadding,
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
    readCardMargin: readCardMargin ?? this.readCardMargin,
    readPadding: readPadding ?? this.readPadding,
    readLabelGap: readLabelGap ?? this.readLabelGap,
    readLabelTextStyle: readLabelTextStyle ?? this.readLabelTextStyle,
    readValueTextStyle: readValueTextStyle ?? this.readValueTextStyle,
    accentBarHeight: accentBarHeight ?? this.accentBarHeight,
    gradientBegin: gradientBegin ?? this.gradientBegin,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    cardShadowBlurRadius: cardShadowBlurRadius ?? this.cardShadowBlurRadius,
    cardShadowOffset: cardShadowOffset ?? this.cardShadowOffset,
    cardShadowAlpha: cardShadowAlpha ?? this.cardShadowAlpha,
    cardTintAlpha: cardTintAlpha ?? this.cardTintAlpha,
    iconContainerSize: iconContainerSize ?? this.iconContainerSize,
    iconContainerRadius: iconContainerRadius ?? this.iconContainerRadius,
    countPillPadding: countPillPadding ?? this.countPillPadding,
    countPillRadius: countPillRadius ?? this.countPillRadius,
    countPillIconSize: countPillIconSize ?? this.countPillIconSize,
    celebrationDuration: celebrationDuration ?? this.celebrationDuration,
    celebrationCurve: celebrationCurve ?? this.celebrationCurve,
    flipDuration: flipDuration ?? this.flipDuration,
    flipCurve: flipCurve ?? this.flipCurve,
    subfolderTriggerVariant:
        subfolderTriggerVariant ?? this.subfolderTriggerVariant,
    subfolderTriggerCollapsedIcon:
        subfolderTriggerCollapsedIcon ?? this.subfolderTriggerCollapsedIcon,
    subfolderTriggerExpandedIcon:
        subfolderTriggerExpandedIcon ?? this.subfolderTriggerExpandedIcon,
    subfolderSelectedEmphasis:
        subfolderSelectedEmphasis ?? this.subfolderSelectedEmphasis,
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
      // ⚠️ `null` des DEUX côtés doit RESTER `null` : c'est l'héritage déclaré
      // (« badgeRadius nul ⇒ suit radiusM »). MESURÉ sans ce court-circuit :
      // `lerp` de deux thèmes par défaut rendait `Radius.circular(8.0)` au lieu
      // de `null` — l'héritage était donc GELÉ à la première transition de
      // thème (Flutter lerp à chaque changement), et le badge cessait ensuite
      // de suivre `radiusM`. Le rendu immédiat était identique, la régression
      // ne serait apparue qu'au changement suivant de `radiusM`.
      badgeRadius: badgeRadius == null && other.badgeRadius == null
          ? null
          : Radius.lerp(
              badgeRadius ?? radiusM,
              other.badgeRadius ?? other.radiusM,
              t,
            ),
      fieldPadding:
          EdgeInsetsDirectional.lerp(fieldPadding, other.fieldPadding, t) ??
          fieldPadding,
      formPadding:
          EdgeInsetsDirectional.lerp(formPadding, other.formPadding, t) ??
          formPadding,
      inputRadius:
          Radius.lerp(inputRadius, other.inputRadius, t) ?? inputRadius,
      inputBorderWidth:
          inputBorderWidth + (other.inputBorderWidth - inputBorderWidth) * t,
      inputFocusedBorderWidth:
          inputFocusedBorderWidth +
          (other.inputFocusedBorderWidth - inputFocusedBorderWidth) * t,
      inputContentPadding:
          EdgeInsetsDirectional.lerp(
            inputContentPadding,
            other.inputContentPadding,
            t,
          ) ??
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
      largeLabelTextStyle: TextStyle.lerp(
        largeLabelTextStyle,
        other.largeLabelTextStyle,
        t,
      ),
      largeLeadingIconSize:
          largeLeadingIconSize +
          (other.largeLeadingIconSize - largeLeadingIconSize) * t,
      largeLeadingGap:
          largeLeadingGap + (other.largeLeadingGap - largeLeadingGap) * t,
      largeLabelGap: largeLabelGap + (other.largeLabelGap - largeLabelGap) * t,
      readCardMargin:
          EdgeInsetsDirectional.lerp(readCardMargin, other.readCardMargin, t) ??
          readCardMargin,
      readPadding:
          EdgeInsetsDirectional.lerp(readPadding, other.readPadding, t) ??
          readPadding,
      readLabelGap: readLabelGap + (other.readLabelGap - readLabelGap) * t,
      readLabelTextStyle: TextStyle.lerp(
        readLabelTextStyle,
        other.readLabelTextStyle,
        t,
      ),
      readValueTextStyle: TextStyle.lerp(
        readValueTextStyle,
        other.readValueTextStyle,
        t,
      ),
      accentBarHeight: _lerpNullableDouble(
        accentBarHeight,
        other.accentBarHeight,
        t,
      ),
      gradientBegin: _lerpNullableAlignment(
        gradientBegin,
        other.gradientBegin,
        t,
      ),
      gradientEnd: _lerpNullableAlignment(gradientEnd, other.gradientEnd, t),
      cardShadowBlurRadius: _lerpNullableDouble(
        cardShadowBlurRadius,
        other.cardShadowBlurRadius,
        t,
      ),
      cardShadowOffset: _lerpNullableOffset(
        cardShadowOffset,
        other.cardShadowOffset,
        t,
      ),
      cardShadowAlpha: _lerpNullableDouble(
        cardShadowAlpha,
        other.cardShadowAlpha,
        t,
      ),
      cardTintAlpha: _lerpNullableDouble(cardTintAlpha, other.cardTintAlpha, t),
      iconContainerSize: _lerpNullableDouble(
        iconContainerSize,
        other.iconContainerSize,
        t,
      ),
      iconContainerRadius: _lerpNullableRadius(
        iconContainerRadius,
        other.iconContainerRadius,
        t,
      ),
      countPillPadding: _lerpNullablePadding(
        countPillPadding,
        other.countPillPadding,
        t,
      ),
      countPillRadius: _lerpNullableRadius(
        countPillRadius,
        other.countPillRadius,
        t,
      ),
      countPillIconSize: _lerpNullableDouble(
        countPillIconSize,
        other.countPillIconSize,
        t,
      ),
      celebrationDuration: _lerpNullableDuration(
        celebrationDuration,
        other.celebrationDuration,
        t,
      ),
      celebrationCurve: _chooseNullableCurve(
        celebrationCurve,
        other.celebrationCurve,
        t,
      ),
      flipDuration: _lerpNullableDuration(flipDuration, other.flipDuration, t),
      flipCurve: _chooseNullableCurve(flipCurve, other.flipCurve, t),
      // Tokens DISCRETS nullables (variante, glyphe, emphase) : aucune valeur
      // intermédiaire n'existe — bascule au point milieu. `null` des DEUX côtés
      // RESTE `null` (même invariant que `badgeRadius`) : matérialiser une
      // valeur ici GÈLERAIT le repli du consommateur à la première transition
      // de thème, et le rendu par défaut cesserait ensuite de suivre.
      subfolderTriggerVariant: t < 0.5
          ? subfolderTriggerVariant
          : other.subfolderTriggerVariant,
      subfolderTriggerCollapsedIcon: t < 0.5
          ? subfolderTriggerCollapsedIcon
          : other.subfolderTriggerCollapsedIcon,
      subfolderTriggerExpandedIcon: t < 0.5
          ? subfolderTriggerExpandedIcon
          : other.subfolderTriggerExpandedIcon,
      subfolderSelectedEmphasis: t < 0.5
          ? subfolderSelectedEmphasis
          : other.subfolderSelectedEmphasis,
    );
  }
}

double? _lerpNullableDouble(double? a, double? b, double t) =>
    a == null && b == null ? null : (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;

Offset? _lerpNullableOffset(Offset? a, Offset? b, double t) =>
    a == null && b == null
    ? null
    : Offset.lerp(a ?? Offset.zero, b ?? Offset.zero, t);

Radius? _lerpNullableRadius(Radius? a, Radius? b, double t) =>
    a == null && b == null
    ? null
    : Radius.lerp(a ?? Radius.zero, b ?? Radius.zero, t);

EdgeInsetsDirectional? _lerpNullablePadding(
  EdgeInsetsDirectional? a,
  EdgeInsetsDirectional? b,
  double t,
) => a == null && b == null
    ? null
    : EdgeInsetsDirectional.lerp(
        a ?? EdgeInsetsDirectional.zero,
        b ?? EdgeInsetsDirectional.zero,
        t,
      );

AlignmentGeometry? _lerpNullableAlignment(
  AlignmentGeometry? a,
  AlignmentGeometry? b,
  double t,
) => a == null && b == null
    ? null
    : AlignmentGeometry.lerp(
        a ?? AlignmentDirectional.center,
        b ?? AlignmentDirectional.center,
        t,
      );

/// Interpole deux durées nullables — **sans jamais matérialiser `Duration.zero`**.
///
/// 🔴 Différence VOLONTAIRE avec les autres helpers nullables (CR epic VIS,
/// MAJEUR-1). Pour une dimension, traiter un côté absent comme `0` est
/// acceptable : une barre d'accent qui « grandit depuis rien » est un rendu
/// plausible. Pour une DURÉE, `0` n'est pas une absence, c'est une valeur
/// **invalide** : une animation de durée nulle est dégénérée, et
/// `ConfettiController` lève sur une durée non strictement positive.
///
/// MESURÉ avant correction, avec `a.celebrationDuration == null` et
/// `b.celebrationDuration == 5 s` : `t=0.0` rendait `0:00:00.000000`. Un thème
/// animé vers un préréglage traversait donc un instant où la durée valait zéro
/// — et une session de célébration construite à cet instant précis plantait.
///
/// Règle retenue : un côté `null` signifie « le consommateur applique SON
/// défaut », valeur que le thème **ignore**. Aucune interpolation n'est donc
/// possible ; on rend l'autre côté, qui est la seule valeur réellement connue.
Duration? _lerpNullableDuration(Duration? a, Duration? b, double t) {
  if (a == null) return b;
  if (b == null) return a;
  return Duration(
    microseconds:
        (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t).round(),
  );
}

Curve? _chooseNullableCurve(Curve? a, Curve? b, double t) =>
    a == null && b == null
    ? null
    : t < .5
    ? a ?? b
    : b ?? a;
