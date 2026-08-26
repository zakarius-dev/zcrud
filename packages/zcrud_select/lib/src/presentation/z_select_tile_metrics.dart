/// **Résolution** des métriques du déclencheur de sélection — maillon central de
/// la chaîne `paramètre > jeton > référence`.
///
/// Les jetons `ZcrudTheme.select*` (posés dans `zcrud_core`) complètent
/// cette chaîne, et ce fichier est le seul endroit du paquet où ses trois
/// maillons se rencontrent.
///
/// ## Ordre, dans les deux sens
///
/// 1. **paramètre** — [ZSelectTileSpec], décidé par le site d'appel ;
/// 2. **jeton** — `ZcrudTheme.select*`, décidé pour toute l'application ;
/// 3. **référence** — [ZSelectTileReference], valeurs auditées de repli.
///
/// Un maillon `null` ne se prononce pas et laisse décider le suivant ; il ne
/// **remplace jamais** le suivant par une valeur neutre. C'est la raison d'être
/// des `lerp` de plancher côté `zcrud_core` : un jeton à `0` pendant une
/// transition de thème serait un rendu que personne n'a choisi.
///
/// ## Invariants
///
/// * **Invariant AD-13** — [ZSelectTileMetrics.minHeight] ne descend **jamais**
///   sous [ZSelectTileReference.minTileHeight], quelle que soit la valeur posée
///   par le paramètre **ou** par le jeton. Les deux ne peuvent que *rehausser*.
/// * **Invariant AD-10** — un jeton de palier **inconnu**
///   (`selectModalShape: 'carousel'`) rend `null` et laisse la référence
///   décider, **sans lever**. Vaut aussi pour un thème sérialisé depuis une
///   version plus récente du socle.
/// * **Aucune couleur codée en dur** — le dernier maillon d'une COULEUR est un
///   **rôle** du `ColorScheme`, jamais un littéral. C'est pourquoi les teintes
///   ne sont pas dans [ZSelectTileReference] (qui reste « métriques seules »)
///   mais résolues ici, contre le thème ambiant.
/// * **Confinement du tiers** — aucun type `awesome_select` / `S2*` ici : la
///   traduction vers `S2ChoiceType`/`S2ModalType` reste confinée au
///   présentateur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_select_tile_reference.dart';

/// Traduit le **nom** d'un palier (`ZcrudTheme.selectMonoChoiceStyle` /
/// `selectMultiChoiceStyle`) en [ZSelectChoiceStyle].
///
/// **Conversion TOTALE** : `null` en entrée **et** tout nom inconnu rendent
/// `null` — jamais une exception, jamais un palier deviné (invariant AD-10).
/// Même patron que `zSheetFrameModeFromToken` de `zcrud_navigation`.
ZSelectChoiceStyle? zSelectChoiceStyleFromToken(String? token) {
  if (token == null) {
    return null;
  }
  for (final ZSelectChoiceStyle style in ZSelectChoiceStyle.values) {
    if (style.name == token) {
      return style;
    }
  }
  return null;
}

/// Traduit le **nom** d'un palier (`ZcrudTheme.selectModalShape`) en
/// [ZSelectModalShape]. Mêmes règles de totalité que
/// [zSelectChoiceStyleFromToken].
ZSelectModalShape? zSelectModalShapeFromToken(String? token) {
  if (token == null) {
    return null;
  }
  for (final ZSelectModalShape shape in ZSelectModalShape.values) {
    if (shape.name == token) {
      return shape;
    }
  }
  return null;
}

/// Métriques **résolues** du déclencheur de sélection : plus aucune décision n'y
/// reste à prendre (porte-valeurs immuable, patron `ZSheetFrameMetrics`).
@immutable
class ZSelectTileMetrics {
  /// Construit un jeu de métriques déjà résolu.
  const ZSelectTileMetrics({
    required this.borderColor,
    required this.borderWidth,
    required this.selectedBorderColor,
    required this.selectedBorderWidth,
    required this.emptyAdornmentAlpha,
    required this.radius,
    required this.elevation,
    required this.minHeight,
    required this.dialogBreakpoint,
    required this.monoChoiceStyle,
    required this.multiChoiceStyle,
    required this.modalShape,
    required this.chipBackgroundColor,
    required this.chipForegroundColor,
    required this.chipFontSize,
    required this.chipSpacing,
    required this.chipRunSpacing,
    required this.chipRadius,
    required this.chipPadding,
    required this.summaryMaxChips,
    required this.placeholderColor,
    required this.valueColor,
    required this.contentPadding,
    required this.choicePageLimit,
    this.cardColor,
  });

  /// Teinte de la bordure (jeton `selectTileBorderColor`, sinon rôle
  /// `outlineVariant`).
  final Color borderColor;

  /// Épaisseur de la bordure (dp).
  final double borderWidth;

  /// Teinte de la bordure **quand le champ porte une valeur**.
  ///
  /// Égale à [borderColor] lorsque rien ne la distingue — c'est le cas d'une
  /// application qui ne sert aucune teinte par type de champ et n'a posé ni
  /// paramètre ni jeton d'état.
  final Color selectedBorderColor;

  /// Épaisseur (dp) de la bordure **quand le champ porte une valeur**. Égale à
  /// [borderWidth] lorsque rien ne la distingue (cf. [selectedBorderColor]).
  final double selectedBorderWidth;

  /// Opacité du fond de la pastille d'ornement d'un déclencheur **vide**.
  ///
  /// `null` ⇒ la pastille garde l'opacité de son jeton dans les deux états —
  /// c'est le cas d'une application qui n'a posé aucun jeton de pastille (il
  /// n'y a alors pas de pastille du tout).
  final double? emptyAdornmentAlpha;

  /// Rayon des coins (dp).
  final double radius;

  /// Élévation du `Card` — **sans jeton** (cf. la note de critère dans
  /// `z_theme.dart`) : paramètre > référence.
  final double elevation;

  /// Fond du `Card` ; `null` ⇒ fond de carte du thème ambiant (invariant
  /// AD-4).
  final Color? cardColor;

  /// Plancher de hauteur (dp), **jamais inférieur à 48** (invariant AD-13).
  final double minHeight;

  /// Largeur de bascule feuille → dialogue (dp).
  final double dialogBreakpoint;

  /// Forme des options en mono.
  final ZSelectChoiceStyle monoChoiceStyle;

  /// Forme des options en multi.
  final ZSelectChoiceStyle multiChoiceStyle;

  /// Forme du conteneur de modal.
  final ZSelectModalShape modalShape;

  /// Fond d'une puce — **sans jeton** (canal app-scale : `ThemeData.chipTheme`).
  final Color chipBackgroundColor;

  /// Texte d'une puce — **sans jeton** (idem).
  final Color chipForegroundColor;

  /// Taille du texte d'une puce (pt) — **sans jeton** (canal : `TextTheme`).
  final double chipFontSize;

  /// Écart horizontal entre puces — **sans jeton** (canal : `gapS`/`gapM`).
  final double chipSpacing;

  /// Écart vertical entre rangées de puces — **sans jeton** (idem).
  final double chipRunSpacing;

  /// Rayon des coins d'une puce du résumé (dp).
  final double chipRadius;

  /// Rembourrage intérieur **directionnel** d'une puce du résumé (AD-13).
  final EdgeInsetsGeometry chipPadding;

  /// Nombre maximum de valeurs affichées dans le résumé multi ; `null` ⇒
  /// **aucune coupure**, toutes les valeurs sont rendues.
  ///
  /// Déjà normalisé : une valeur non positive posée par l'hôte est rendue ici
  /// comme `null` (invariant AD-10). La coupure est **visuelle seulement** —
  /// l'annonce accessible du déclencheur ne perd jamais de valeur (AD-13).
  final int? summaryMaxChips;

  /// Teinte de l'état vide — **sans jeton** (canal : `ThemeData.hintColor`).
  final Color placeholderColor;

  /// Teinte de la valeur renseignée (mono).
  final Color valueColor;

  /// Marge intérieure **directionnelle** du `ListTile` (invariant AD-13).
  final EdgeInsetsGeometry contentPadding;

  /// Options chargées par page dans le modal.
  final int choicePageLimit;
}

/// Résout les métriques du déclencheur — **paramètre ([ZSelectTileSpec]) > jeton
/// (`ZcrudTheme.select*`) > référence ([ZSelectTileReference])**.
///
/// **Aucun jeton n'agit tant qu'il n'est pas déclaré** : sans `spec` ET sans
/// jeton, chaque valeur rendue est **exactement** celle de la référence. Les
/// jetons `select*` sont absents de `ZcrudTheme.fallback()` — un hôte qui n'a
/// rien déclaré obtient l'apparence de référence, jamais une valeur neutre.
///
/// [tint] est la **teinte par type de champ** déjà normalisée
/// (`zResolveFieldTint`), ou `null` si aucun résolveur ne la sert. Elle n'est
/// consultée que pour le dernier maillon du duo d'état renseigné
/// ([ZSelectTileMetrics.selectedBorderColor] / `selectedBorderWidth`) : sans
/// elle, ce duo vaut **exactement** celui du repos, et le déclencheur ne
/// réagit pas à la présence d'une valeur.
ZSelectTileMetrics zSelectTileMetricsOf(
  BuildContext context, {
  ZSelectTileSpec? spec,
  Color? tint,
}) {
  final ZcrudTheme token = ZcrudTheme.of(context);
  final ThemeData theme = Theme.of(context);
  final ColorScheme scheme = theme.colorScheme;

  // invariant AD-13 : le plancher de 48 dp ne peut être que REHAUSSÉ — ni par
  // le paramètre, ni par le jeton. `math.max` appliqué APRÈS la résolution de
  // la chaîne, donc un `selectTileMinHeight: 24` posé au thème pour toute
  // l'app ne descend pas davantage la cible qu'un paramètre à 24.
  final double requested = spec?.minTileHeight ??
      token.selectTileMinHeight ??
      ZSelectTileReference.minTileHeight;
  final double minHeight = requested < ZSelectTileReference.minTileHeight
      ? ZSelectTileReference.minTileHeight
      : requested;

  // invariant AD-10 : un palier NON POSITIF (0, négatif) ne lève pas et ne
  // devine pas un nombre — il vaut « aucune coupure », l'échappatoire
  // documentée pour un hôte qui veut ses quinze valeurs à l'écran.
  final int? requestedMaxChips = spec?.summaryMaxChips ??
      token.selectSummaryMaxChips ??
      ZSelectTileReference.summaryMaxChips;
  final int? summaryMaxChips =
      (requestedMaxChips != null && requestedMaxChips > 0)
          ? requestedMaxChips
          : null;

  // Duo de REPOS, résolu d'abord : il sert aussi de dernier maillon à l'état
  // renseigné, ce qui est la charnière de l'inertie décrite plus bas.
  final Color borderColor = spec?.borderColor ??
      token.selectTileBorderColor ??
      scheme.outlineVariant;
  final double borderWidth = spec?.borderWidth ??
      token.selectTileBorderWidth ??
      ZSelectTileReference.borderWidth;

  // ── État RENSEIGNÉ ────────────────────────────────────────────────────────
  // Application DIRECTE de la teinte, sans jeton booléen d'activation : un
  // drapeau à défaut `true` serait le premier du socle qu'il faudrait DÉPOSER
  // pour retenir un rendu, exactement l'inverse de la grammaire opt-in du
  // canal de teinte (cf. le libellé flottant dans `z_theme.dart`). Le
  // déclencheur est ici : `tint == null` ⇒ le duo de repos est reconduit tel
  // quel dans les deux états.
  //
  // Conséquence MESURÉE et voulue : l'ÉPAISSEUR ne bouge jamais seule. Sans
  // résolveur de dégradé, une bordure qui s'épaissirait au remplissage serait
  // un changement de rendu que l'application n'a pas demandé et que rien ne
  // rend lisible (aucune couleur ne l'accompagne). Avec résolveur, couleur et
  // épaisseur changent ENSEMBLE — deux canaux pour un même état, jamais la
  // couleur seule (AD-13).
  final Color selectedBorderColor = spec?.selectedBorderColor ??
      token.selectTileSelectedBorderColor ??
      (tint == null
          ? borderColor
          : tint.withValues(
              alpha: ZSelectTileReference.selectedBorderTintAlpha,
            ));
  final double selectedBorderWidth = spec?.selectedBorderWidth ??
      token.selectTileSelectedBorderWidth ??
      (tint == null
          ? borderWidth
          : ZSelectTileReference.selectedBorderWidth);

  // Pastille d'ornement de l'état VIDE. L'atténuation n'existe que là où la
  // pastille existe : sans le jeton d'opacité du cœur, il n'y a rien à
  // atténuer et la valeur reste `null` — aucun canal ne s'ouvre tout seul.
  final double? pillAlpha = token.adornmentIconBackgroundAlpha;
  final double? emptyAdornmentAlpha = spec?.emptyAdornmentAlpha ??
      token.selectTileEmptyAdornmentAlpha ??
      (pillAlpha == null
          ? null
          : pillAlpha * ZSelectTileReference.emptyAdornmentAlphaFactor);

  return ZSelectTileMetrics(
    // Dernier maillon = RÔLE, jamais un littéral.
    borderColor: borderColor,
    borderWidth: borderWidth,
    selectedBorderColor: selectedBorderColor,
    selectedBorderWidth: selectedBorderWidth,
    emptyAdornmentAlpha: emptyAdornmentAlpha,
    radius: spec?.cardRadius ??
        token.selectTileRadius ??
        ZSelectTileReference.cardRadius,
    // Sans jeton, délibérément : paramètre > référence.
    elevation: spec?.cardElevation ?? ZSelectTileReference.cardElevation,
    cardColor: spec?.cardColor,
    minHeight: minHeight,
    dialogBreakpoint: spec?.dialogBreakpoint ??
        token.selectDialogBreakpoint ??
        ZSelectTileReference.dialogBreakpoint,
    // invariant AD-10 : nom de palier inconnu ⇒ `null` ⇒ la référence décide, sans lever.
    monoChoiceStyle: spec?.monoChoiceStyle ??
        zSelectChoiceStyleFromToken(token.selectMonoChoiceStyle) ??
        ZSelectTileReference.monoChoiceStyle,
    multiChoiceStyle: spec?.multiChoiceStyle ??
        zSelectChoiceStyleFromToken(token.selectMultiChoiceStyle) ??
        ZSelectTileReference.multiChoiceStyle,
    modalShape: spec?.modalShape ??
        zSelectModalShapeFromToken(token.selectModalShape) ??
        ZSelectTileReference.modalShape,
    chipBackgroundColor:
        spec?.chipBackgroundColor ?? scheme.surfaceContainerHighest,
    chipForegroundColor: spec?.chipForegroundColor ?? scheme.onSurface,
    chipFontSize: spec?.chipFontSize ??
        token.selectSummaryChipFontSize ??
        ZSelectTileReference.chipFontSize,
    chipSpacing: spec?.chipSpacing ?? ZSelectTileReference.chipSpacing,
    chipRunSpacing:
        spec?.chipRunSpacing ?? ZSelectTileReference.chipRunSpacing,
    chipRadius: spec?.chipRadius ??
        token.selectSummaryChipRadius ??
        ZSelectTileReference.summaryChipRadius,
    // invariant AD-13 : insets DIRECTIONNELS (jamais `left`/`right`).
    chipPadding: spec?.chipPadding ??
        token.selectSummaryChipPadding ??
        const EdgeInsetsDirectional.symmetric(
          horizontal: ZSelectTileReference.summaryChipPaddingHorizontal,
          vertical: ZSelectTileReference.summaryChipPaddingVertical,
        ),
    summaryMaxChips: summaryMaxChips,
    placeholderColor: spec?.placeholderColor ?? scheme.onSurfaceVariant,
    valueColor: spec?.valueColor ?? scheme.onSurface,
    // invariant AD-13 : insets DIRECTIONNELS (jamais `left`/`right`).
    contentPadding: spec?.contentPadding ??
        const EdgeInsetsDirectional.symmetric(
          horizontal: ZSelectTileReference.contentPaddingHorizontal,
          vertical: ZSelectTileReference.contentPaddingVertical,
        ),
    choicePageLimit:
        spec?.choicePageLimit ?? ZSelectTileReference.choicePageLimit,
  );
}
