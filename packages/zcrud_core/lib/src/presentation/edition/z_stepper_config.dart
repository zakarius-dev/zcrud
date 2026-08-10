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

/// **Forme d'affichage des étapes** (CR-DODLP « Material vertical », 2026-08-10).
///
/// Le besoin est à **TROIS** états, alors que [ZStepperConfig.showAllSteps] est
/// un booléen — il ne peut en porter que deux. Cette énumération les nomme :
///
/// | Valeur | En-têtes des autres étapes | Contenu monté |
/// |---|---|---|
/// | [paged] | **absents** (compteur « k/N ») | l'étape courante seule |
/// | [allExpanded] | tous, en rail | **toutes** les étapes |
/// | [accordion] | **tous**, en rail, **tapables** | l'étape active seule |
///
/// [accordion] est le rendu `Stepper(type: vertical)` de Material — celui sur
/// lequel s'appuie le legacy DODLP (`_buildInteractiveVerticalStepper`).
///
/// 🔴 **Une énumération, et NON le patron `String` de
/// `ZcrudTheme.editionSheetFrameMode`.** Ce patron-là existe pour une raison
/// précise et mesurable : `ZSheetFrameMode` vit dans `zcrud_navigation`, et
/// **AD-1 interdit à `zcrud_core` d'importer un satellite** — le jeton ne peut
/// donc PAS être typé. Ici, rien de tel : les trois enums voisines
/// ([ZStepOrientation], [ZStepStyle], [ZStepIndicatorPosition]) vivent déjà dans
/// CE fichier, dans CE paquet. Reprendre le `String` reviendrait à payer la
/// perte d'exhaustivité du `switch` (le compilateur cesse de signaler un mode
/// non traité) pour contourner une contrainte qui ne s'applique pas.
enum ZStepsDisplay {
  /// Assistant **paginé** : une étape à la fois, en-têtes des autres absents.
  /// C'est le comportement E3-5/DP-9, et le défaut de [ZStepperConfig].
  paged,

  /// **Tout affiché** : toutes les étapes dépliées simultanément, rail numéroté.
  /// Équivalent de `showAllSteps: true` (v0.66.0).
  ///
  /// ## Canaux INERTES dans cette forme (déclaration v0.66.0, inchangée)
  ///
  /// [ZStepperConfig.indicatorPosition], [ZStepperConfig.orientation],
  /// [ZStepperConfig.style], [ZStepperConfig.allowStepTap],
  /// [ZStepperConfig.validateOnNext] et [ZStepperConfig.stepSpacing] : le rail
  /// est toujours vertical, du côté début de lecture, à badges numérotés ; il
  /// n'y a ni étape courante, ni en-tête tapable, ni gate de navigation.
  allExpanded,

  /// **Accordéon Material** : tous les en-têtes visibles dans le rail numéroté,
  /// **une seule étape dépliée** (l'active), en-têtes **tapables**.
  ///
  /// ## 🔴 Matrice d'inertie — mise à jour pour CETTE forme (règle CR-IFFD-78 :
  /// un paramètre est honoré, ou son inertie est ÉCRITE)
  ///
  /// | Canal | [allExpanded] | [accordion] |
  /// |---|---|---|
  /// | [ZStepperConfig.allowStepTap] | inerte | **HONORÉ** — `false` ⇒ en-têtes non tapables (aucun `InkWell`, aucun rôle `button`) |
  /// | [ZStepperConfig.validateOnNext] | inerte (pas d'étape courante) | **HONORÉ** — même voie que le paginé (cf. `_accordionLayout`) |
  /// | [ZStepperConfig.indicatorPosition] | inerte | **inerte** — le rail est toujours du côté début de lecture (le badge est le rail ; il n'y a pas de bande séparée à placer) |
  /// | [ZStepperConfig.orientation] | inerte | **inerte** — un accordéon est vertical par construction |
  /// | [ZStepperConfig.style] | inerte | **inerte** — le rail est à badges numérotés ; `dots`/`progressBar`/`icons` ne décrivent pas ce rendu |
  /// | [ZStepperConfig.stepSpacing] | inerte | **inerte** — l'écart entre étapes vient du jeton `ZcrudTheme.stepperAllStepsGap` |
  /// | [ZStepperConfig.showLabels] / [ZStepperConfig.showSubtitles] | honorés | **honorés** |
  /// | [ZStepperConfig.indicatorSize] | honoré (diamètre du badge) | **honoré** |
  /// | couleurs `active`/`completed`/`inactive`/`rail`/`badgeForeground` | honorées | **honorées** (`completed`/`inactive` n'y prennent leur sens qu'ici) |
  ///
  /// ⚠️ [ZStepperConfig.errorColor] reste inerte dans les DEUX formes : aucune
  /// étape n'est peinte « en erreur » par le rail (l'erreur est révélée dans le
  /// champ, par `AutovalidateMode`).
  accordion,
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
    this.showAllSteps = false,
    this.stepsDisplay,
    this.indicatorSize = 40,
    this.stepSpacing = 8,
    this.activeColor,
    this.completedColor,
    this.inactiveColor,
    this.errorColor,
    this.railColor,
    this.badgeForegroundColor,
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

  /// **Mode « TOUT AFFICHÉ »** (parité DODLP `StepperConfig.showAllSteps`) :
  /// `false` (défaut) ⇒ assistant **paginé**, comportement E3-5/DP-9 **exact et
  /// inchangé**. `true` ⇒ toutes les étapes sont **dépliées simultanément**,
  /// reliées par un **rail** vertical à badges numérotés (cible visuelle du
  /// legacy DODLP `_buildVerticalExpandedSteps`).
  ///
  /// 🔴 Ce mode ne PAGINE PAS : il n'y a ni étape courante, ni bouton
  /// « Précédent/Suivant », ni **gate de validation par étape** (`validateOnNext`
  /// devient sans objet au niveau où `showAllSteps` est posé — il reste
  /// pleinement actif dans les sous-steppers imbriqués, qui, eux, paginent).
  /// C'est un arbitrage assumé : une navigation par étape n'a pas de sens quand
  /// toutes les étapes sont visibles en même temps.
  ///
  /// L'invariant DP-9/AC13 tient : la fenêtre `controller.visibleFields` devient
  /// l'**UNION de toutes les étapes effectives** (+ contributions des nested), et
  /// c'est toujours le stepper RACINE, et lui seul, qui l'écrit.
  final bool showAllSteps;

  /// **Forme d'affichage à trois états** (CR-DODLP « Material vertical »).
  /// Défaut **`null`** ⇒ la forme est **DÉRIVÉE** de [showAllSteps], donc un
  /// hôte qui n'y touche pas rend **exactement** comme avant (cf.
  /// [effectiveDisplay]).
  ///
  /// ## 🔴 La règle de préséance, écrite (deux canaux pour une même idée)
  ///
  /// [showAllSteps] et [stepsDisplay] peuvent se **contredire** (`showAllSteps:
  /// true` + `stepsDisplay: ZStepsDisplay.paged`, par exemple). La règle est :
  ///
  /// > **`stepsDisplay` non `null` GAGNE, toujours. `showAllSteps` n'est plus
  /// > consulté du tout.**
  ///
  /// Elle n'est pas arbitraire : `stepsDisplay` est le canal **explicite et
  /// complet** (il sait dire les trois états), `showAllSteps` est l'**alias
  /// hérité** qui n'en sait dire que deux. Faire gagner l'alias rendrait le
  /// troisième état inatteignable pour tout hôte qui passe aussi le booléen. Et
  /// la préséance ne peut PAS être « le dernier écrit » : le constructeur est
  /// `const`, il n'y a pas d'ordre.
  ///
  /// ⚠️ Corollaire assumé : `stepsDisplay: ZStepsDisplay.paged` **annule** un
  /// `showAllSteps: true`. C'est un choix délibéré, gardé par un test.
  ///
  /// ⚠️ [copyWith] ne permet pas de **remettre** ce champ à `null` (même limite
  /// que les overrides couleur de cette classe) : repasser explicitement
  /// `stepsDisplay: ZStepsDisplay.paged` ou `.allExpanded`.
  final ZStepsDisplay? stepsDisplay;

  /// Forme d'affichage **effective** — la seule que le rendu consulte.
  ///
  /// `stepsDisplay ?? (showAllSteps ? allExpanded : paged)`. Un hôte passif
  /// (`stepsDisplay` omis, `showAllSteps` à `false`) obtient donc [ZStepsDisplay.paged],
  /// c'est-à-dire le comportement historique, au widget près.
  ZStepsDisplay get effectiveDisplay =>
      stepsDisplay ??
      (showAllSteps ? ZStepsDisplay.allExpanded : ZStepsDisplay.paged);

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

  /// Override couleur du **rail** reliant les badges en mode [showAllSteps].
  /// Défaut `null` ⇒ jeton `ZcrudTheme.stepperRailColor`, puis rôle
  /// `ColorScheme.outlineVariant` (FR-26 : aucun littéral).
  final Color? railColor;

  /// Override couleur du **numéro** peint dans le badge. Défaut `null` ⇒ jeton
  /// `ZcrudTheme.stepperBadgeForegroundColor`, puis **contraste dérivé** de la
  /// couleur du badge. Le legacy DODLP écrit un **blanc littéral** : illisible
  /// dès qu'un hôte choisit un `activeColor` clair, et interdit par FR-26.
  final Color? badgeForegroundColor;

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
    bool? showAllSteps,
    ZStepsDisplay? stepsDisplay,
    double? indicatorSize,
    double? stepSpacing,
    Color? activeColor,
    Color? completedColor,
    Color? inactiveColor,
    Color? errorColor,
    Color? railColor,
    Color? badgeForegroundColor,
  }) =>
      ZStepperConfig(
        orientation: orientation ?? this.orientation,
        style: style ?? this.style,
        indicatorPosition: indicatorPosition ?? this.indicatorPosition,
        showLabels: showLabels ?? this.showLabels,
        showSubtitles: showSubtitles ?? this.showSubtitles,
        allowStepTap: allowStepTap ?? this.allowStepTap,
        validateOnNext: validateOnNext ?? this.validateOnNext,
        showAllSteps: showAllSteps ?? this.showAllSteps,
        stepsDisplay: stepsDisplay ?? this.stepsDisplay,
        indicatorSize: indicatorSize ?? this.indicatorSize,
        stepSpacing: stepSpacing ?? this.stepSpacing,
        activeColor: activeColor ?? this.activeColor,
        completedColor: completedColor ?? this.completedColor,
        inactiveColor: inactiveColor ?? this.inactiveColor,
        errorColor: errorColor ?? this.errorColor,
        railColor: railColor ?? this.railColor,
        badgeForegroundColor: badgeForegroundColor ?? this.badgeForegroundColor,
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
          showAllSteps == other.showAllSteps &&
          stepsDisplay == other.stepsDisplay &&
          indicatorSize == other.indicatorSize &&
          stepSpacing == other.stepSpacing &&
          activeColor == other.activeColor &&
          completedColor == other.completedColor &&
          inactiveColor == other.inactiveColor &&
          errorColor == other.errorColor &&
          railColor == other.railColor &&
          badgeForegroundColor == other.badgeForegroundColor;

  @override
  int get hashCode => Object.hash(
        orientation,
        style,
        indicatorPosition,
        showLabels,
        showSubtitles,
        allowStepTap,
        validateOnNext,
        showAllSteps,
        stepsDisplay,
        indicatorSize,
        stepSpacing,
        activeColor,
        completedColor,
        inactiveColor,
        errorColor,
        railColor,
        badgeForegroundColor,
      );

  /// Preset de parité : `top`/`horizontal`/`numbered` (= défaut E3-5).
  static const ZStepperConfig defaultHorizontal = ZStepperConfig();

  /// Preset de parité : `start`/`vertical`/`numbered` (indicateur latéral
  /// directionnel).
  static const ZStepperConfig defaultVertical = ZStepperConfig(
    orientation: ZStepOrientation.vertical,
    indicatorPosition: ZStepIndicatorPosition.start,
  );

  /// Preset de parité **legacy DODLP `showAllSteps: true`** : vertical, toutes
  /// les étapes dépliées, rail numéroté. Aucune couleur figée (FR-26).
  static const ZStepperConfig allStepsVertical = ZStepperConfig(
    orientation: ZStepOrientation.vertical,
    indicatorPosition: ZStepIndicatorPosition.start,
    showAllSteps: true,
    showSubtitles: true,
  );

  /// Preset de parité **legacy DODLP `_buildInteractiveVerticalStepper`**
  /// (CR « Material vertical ») : accordéon — tous les en-têtes dans le rail
  /// numéroté, une seule étape dépliée, en-têtes tapables.
  ///
  /// ⚠️ `validateOnNext` reste à son défaut **`true`** (gate strict) : le
  /// legacy, lui, navigue librement. Un hôte qui veut la parité EXACTE de la
  /// navigation legacy pose `validateOnNext: false` — cf. la règle écrite sur
  /// `ZStepperEdition._accordionLayout`.
  static const ZStepperConfig accordionVertical = ZStepperConfig(
    orientation: ZStepOrientation.vertical,
    indicatorPosition: ZStepIndicatorPosition.start,
    stepsDisplay: ZStepsDisplay.accordion,
    showSubtitles: true,
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
