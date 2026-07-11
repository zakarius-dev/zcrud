/// `ZStepperConfig` — configuration **présentation** (pur-données `const`) de
/// l'assistant multi-étapes [ZStepperEdition] (DP-9, parité DODLP `StepperConfig`).
///
/// origine: DODLP `data_crud/models/stepper_config.dart` porte un `StepperConfig`
/// riche (style/orientation/position d'indicateur, icône/sous-titre par étape,
/// gate `validateOnNext`, couleurs applicatives). DP-9 en livre le **runtime**
/// zcrud, ADDITIF et rétro-compatible :
/// - AD-1 : ces types accompagnent Flutter (`IconData`/`Color`/orientation de
///   rendu) → ils vivent en **présentation**, jamais dans le domaine pur.
/// - AD-6 / FR-26 : les overrides couleur sont **NULLABLES** (défaut `null`) — le
///   rendu DÉRIVE les couleurs du `ColorScheme` de l'app ; aucun `Colors.*`/
///   `Color(0x…)` littéral. Un preset ne fige **aucune** couleur.
/// - AD-13 : `left` DODLP → **`start`** directionnel ([ZStepIndicatorPosition]).
/// - Additivité stricte : enums + classe nouveaux, valeurs d'enum **camelCase**.
///
/// Aucune (dé)sérialisation domaine n'est en jeu : ce sont des descripteurs
/// d'**authoring de présentation**, non persistés (AD-3/AD-14).
library;

import 'package:flutter/material.dart';

/// Orientation de la bande d'étapes (miroir de `StepOrientation` DODLP).
enum ZStepOrientation {
  /// Étapes disposées horizontalement (défaut, parité `defaultHorizontal`).
  horizontal,

  /// Étapes disposées verticalement (parité `defaultVertical`).
  vertical,
}

/// Style visuel de l'indicateur d'étape (miroir de `StepStyle` DODLP).
enum ZStepStyle {
  /// Position « k/N » numérotée + titre (défaut ; reproduit l'indicateur
  /// historique E3-5). Une icône par étape est ignorée dans ce style.
  numbered,

  /// Icône par étape ([ZEditionStep.icon]) avec repli sur le numéro si absente.
  icons,

  /// Barre de progression continue (`LinearProgressIndicator`).
  progressBar,

  /// Points (un par étape ; l'étape courante/complétée est mise en avant).
  dots,
}

/// Position de la bande d'indicateurs relativement à la zone de contenu.
///
/// **AD-13** : `left` DODLP est remplacé par **`start`** — la bande latérale suit
/// la `Directionality` (côté début de lecture), jamais un `left` physique.
enum ZStepIndicatorPosition {
  /// Bande au-dessus du contenu (défaut, parité `top` DODLP).
  top,

  /// Bande du **côté début de lecture** (directionnel ; `left` DODLP → `start`).
  start,

  /// Bande au-dessous du contenu (parité `bottom` DODLP).
  bottom,
}

/// Configuration `const` & immuable de [ZStepperEdition] (DP-9).
///
/// Tous les défauts reproduisent **exactement** le comportement E3-5 (indicateur
/// `top`/`horizontal`/`numbered` « k/N » + titre, gate strict `validateOnNext`).
/// Les overrides couleur sont **nullables** (défaut `null`) → dérivés du
/// `ColorScheme` par le rendu (AD-6/FR-26). Les mesures (`indicatorSize`,
/// `stepSpacing`) sont des tokens de config surchargeables par l'app.
@immutable
class ZStepperConfig {
  /// Construit une configuration `const`.
  const ZStepperConfig({
    this.orientation = ZStepOrientation.horizontal,
    this.style = ZStepStyle.numbered,
    this.indicatorPosition = ZStepIndicatorPosition.top,
    this.showLabels = true,
    this.showSubtitles = false,
    this.allowStepTap = true,
    this.validateOnNext = true,
    this.indicatorSize = 40,
    this.stepSpacing = 8,
    this.activeColor,
    this.completedColor,
    this.inactiveColor,
    this.errorColor,
  });

  /// Orientation de la bande d'étapes (défaut `horizontal`).
  final ZStepOrientation orientation;

  /// Style visuel de l'indicateur (défaut `numbered` = « k/N » historique).
  final ZStepStyle style;

  /// Position de la bande relativement au contenu (défaut `top`, directionnel).
  final ZStepIndicatorPosition indicatorPosition;

  /// Affiche les titres d'étape dans la bande (défaut `true`).
  final bool showLabels;

  /// Affiche le sous-titre de l'étape courante ([ZEditionStep.subtitle]) sous
  /// l'indicateur (défaut `false` — parité DODLP).
  final bool showSubtitles;

  /// Autorise la navigation par tap sur l'indicateur (défaut `true`). Retour
  /// arrière libre ; saut avant soumis au même gate que « Suivant ».
  final bool allowStepTap;

  /// Gate de validation à la transition « Suivant » (défaut **`true`** = gate
  /// strict E3-5). `false` ⇒ navigation **libre** (parité DODLP, gap M12).
  final bool validateOnNext;

  /// Taille (dp) d'un marqueur d'indicateur (`dots`/cercles) — token de config.
  final double indicatorSize;

  /// Espacement (dp) entre marqueurs d'indicateur — token de config.
  final double stepSpacing;

  /// Override couleur de l'étape **active** (défaut `null` ⇒ `ColorScheme.primary`).
  final Color? activeColor;

  /// Override couleur d'une étape **complétée** (défaut `null` ⇒ `primary`).
  final Color? completedColor;

  /// Override couleur d'une étape **en attente** (défaut `null` ⇒
  /// `onSurfaceVariant`).
  final Color? inactiveColor;

  /// Override couleur d'une étape **en erreur** (défaut `null` ⇒ `error`).
  final Color? errorColor;

  /// Couleur effective de l'étape active (override, sinon `ColorScheme.primary`).
  Color activeOf(ColorScheme scheme) => activeColor ?? scheme.primary;

  /// Couleur effective d'une étape complétée (override, sinon `primary`).
  Color completedOf(ColorScheme scheme) => completedColor ?? scheme.primary;

  /// Couleur effective d'une étape en attente (override, sinon `onSurfaceVariant`).
  Color inactiveOf(ColorScheme scheme) => inactiveColor ?? scheme.onSurfaceVariant;

  /// Couleur effective d'une étape en erreur (override, sinon `error`).
  Color errorOf(ColorScheme scheme) => errorColor ?? scheme.error;

  /// Copie avec surcharges ponctuelles (les couleurs restent explicitement
  /// surchargeables ; passer une valeur remplace, l'omettre conserve).
  ZStepperConfig copyWith({
    ZStepOrientation? orientation,
    ZStepStyle? style,
    ZStepIndicatorPosition? indicatorPosition,
    bool? showLabels,
    bool? showSubtitles,
    bool? allowStepTap,
    bool? validateOnNext,
    double? indicatorSize,
    double? stepSpacing,
    Color? activeColor,
    Color? completedColor,
    Color? inactiveColor,
    Color? errorColor,
  }) =>
      ZStepperConfig(
        orientation: orientation ?? this.orientation,
        style: style ?? this.style,
        indicatorPosition: indicatorPosition ?? this.indicatorPosition,
        showLabels: showLabels ?? this.showLabels,
        showSubtitles: showSubtitles ?? this.showSubtitles,
        allowStepTap: allowStepTap ?? this.allowStepTap,
        validateOnNext: validateOnNext ?? this.validateOnNext,
        indicatorSize: indicatorSize ?? this.indicatorSize,
        stepSpacing: stepSpacing ?? this.stepSpacing,
        activeColor: activeColor ?? this.activeColor,
        completedColor: completedColor ?? this.completedColor,
        inactiveColor: inactiveColor ?? this.inactiveColor,
        errorColor: errorColor ?? this.errorColor,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStepperConfig &&
          runtimeType == other.runtimeType &&
          orientation == other.orientation &&
          style == other.style &&
          indicatorPosition == other.indicatorPosition &&
          showLabels == other.showLabels &&
          showSubtitles == other.showSubtitles &&
          allowStepTap == other.allowStepTap &&
          validateOnNext == other.validateOnNext &&
          indicatorSize == other.indicatorSize &&
          stepSpacing == other.stepSpacing &&
          activeColor == other.activeColor &&
          completedColor == other.completedColor &&
          inactiveColor == other.inactiveColor &&
          errorColor == other.errorColor;

  @override
  int get hashCode => Object.hash(
        orientation,
        style,
        indicatorPosition,
        showLabels,
        showSubtitles,
        allowStepTap,
        validateOnNext,
        indicatorSize,
        stepSpacing,
        activeColor,
        completedColor,
        inactiveColor,
        errorColor,
      );

  /// Preset de parité : `top`/`horizontal`/`numbered` (= défaut E3-5).
  static const ZStepperConfig defaultHorizontal = ZStepperConfig();

  /// Preset de parité : `start`/`vertical`/`numbered` (indicateur latéral
  /// directionnel).
  static const ZStepperConfig defaultVertical = ZStepperConfig(
    orientation: ZStepOrientation.vertical,
    indicatorPosition: ZStepIndicatorPosition.start,
  );

  /// Preset de parité : `bottom`/`horizontal`/`dots`, sans titres.
  static const ZStepperConfig dotStyle = ZStepperConfig(
    style: ZStepStyle.dots,
    indicatorPosition: ZStepIndicatorPosition.bottom,
    showLabels: false,
  );

  /// Preset de parité : `top`/`horizontal`/`progressBar`, sans titres.
  static const ZStepperConfig progressBarStyle = ZStepperConfig(
    style: ZStepStyle.progressBar,
    showLabels: false,
  );
}
