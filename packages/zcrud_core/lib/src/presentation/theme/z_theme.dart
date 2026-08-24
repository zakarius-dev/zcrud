/// `ZcrudTheme` — design-tokens sémantiques injectables (AD-6).
///
/// `ThemeExtension<ZcrudTheme>` résolu via `ZcrudScope` avec repli sur
/// `Theme.of(context)`. **AUCUN style codé en dur** dans le cœur (pas de
/// couleur/décoration figée en constante) : les couleurs sémantiques sont
/// `nullable` et **dérivées** du `ColorScheme`/`TextTheme` courant par
/// [ZcrudTheme.fallback]. Les tokens d'espacement/rayon sont la **source
/// injectable** — ils sont exemptés de la garde couleur (ce ne sont pas des
/// couleurs).
///
/// Ce fichier introduit `package:flutter/material.dart` sous
/// `presentation/` (requis par `ThemeExtension`/`Theme.of`/`ThemeData`).
/// `cupertino`/`services`/`dart:ui`-direct restent interdits.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_read_field_layout.dart';
import '../zcrud_scope.dart';
import 'z_gradient_resolver.dart';

/// Habillage du **déclencheur** d'une surface de navigation (barre repliée
/// montrant l'élément courant) — token de LOOK, jamais de structure.
///
/// **Aucune couleur ici.** Chaque valeur nomme un RÔLE de conteneur Material,
/// que le consommateur traduit en `ColorScheme` : c'est ce qui permet à un hôte
/// de demander « contour » ou « rempli » sans qu'un seul hex n'entre dans un
/// paquet.
enum ZSubfolderTriggerVariant {
  /// Aucun conteneur : le déclencheur est une simple ligne cliquable.
  /// **Rendu historique** — c'est ce que rend un thème qui ne déclare rien.
  flat,

  /// Conteneur à **contour** (bordure `ColorScheme.outlineVariant`, fond
  /// transparent) — l'habillage `Card.outlined` de la référence de maquette.
  outlined,

  /// Conteneur **rempli** (`ColorScheme.surfaceContainerHighest`, sans bordure).
  filled,
}

/// RÔLE de **fond** du déclencheur de navigation de fratrie —
/// token de LOOK, attribut COMPOSABLE.
///
/// **Aucune couleur ici.** Chaque valeur nomme un RÔLE de surface Material
/// que le consommateur traduit depuis le `ColorScheme` courant (invariant FR-26)
/// — même patron que [ZStudySectionCountRole].
///
/// **Précédence** : fourni, ce token PRIME sur ce que
/// [ZSubfolderTriggerVariant] décide pour le FOND (et seulement pour lui) ;
/// `null` ⇒ la variante décide. [none] est un choix EXPLICITE (« aucun fond »),
/// distinct de `null` (« je ne dis rien ») : il retire le fond d'une variante
/// `filled` sans toucher à sa bordure ni à son élévation.
enum ZSubfolderTriggerFill {
  /// AUCUN fond — retire explicitement le fond que la variante poserait.
  none,

  /// Fond `ColorScheme.surface`.
  surface,

  /// Fond `ColorScheme.surfaceContainerLowest`.
  surfaceContainerLowest,

  /// Fond `ColorScheme.surfaceContainerLow`.
  surfaceContainerLow,

  /// Fond `ColorScheme.surfaceContainer`.
  surfaceContainer,

  /// Fond `ColorScheme.surfaceContainerHigh`.
  surfaceContainerHigh,

  /// Fond `ColorScheme.surfaceContainerHighest` — le fond de la variante
  /// `filled` historique, exprimé comme attribut composable.
  surfaceContainerHighest,
}

/// RÔLE de **bordure** du déclencheur de navigation de fratrie —
/// token de LOOK, attribut COMPOSABLE.
///
/// **Aucune couleur ici** : chaque valeur nomme un rôle de contour du
/// `ColorScheme` courant (invariant FR-26).
///
/// **Précédence** : fourni, ce token PRIME sur ce que
/// [ZSubfolderTriggerVariant] décide pour la BORDURE (et seulement pour elle) ;
/// `null` ⇒ la variante décide. [none] retire explicitement la bordure d'une
/// variante `outlined` sans toucher à son fond.
enum ZSubfolderTriggerBorder {
  /// AUCUNE bordure — retire explicitement la bordure que la variante poserait.
  none,

  /// Bordure `ColorScheme.outlineVariant` — la bordure de la variante
  /// `outlined` historique, exprimée comme attribut composable.
  outlineVariant,

  /// Bordure `ColorScheme.outline` (contraste plus appuyé).
  outline,
}

/// Manière dont l'élément COURANT se distingue dans une liste de navigation —
/// token de LOOK.
///
/// **L'inversion n'est pas un surlignage plus foncé.** `highlight` teinte le
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

/// Forme du compteur d'items d'un en-tête de section d'étude —
/// token de LOOK.
///
/// **Aucune couleur ici** : la forme est indépendante de la matière (le rôle
/// de couleur vit dans [ZStudySectionCountRole]) — même frontière que
/// partout ailleurs : la forme monte, la matière reste au thème.
enum ZStudySectionCountShape {
  /// Rectangle arrondi (`badgeRadius`, repli `radiusM`). **Rendu historique** —
  /// c'est ce que rend un thème qui ne déclare rien.
  rounded,

  /// Pastille (stadium) : les coins suivent la demi-hauteur du badge, quel que
  /// soit son contenu — la « pastille ronde » de la référence, sans rayon
  /// magique.
  pill,
}

/// RÔLE de couleur du compteur d'en-tête de section d'étude.
///
/// **Aucune couleur ici.** Chaque valeur nomme un **couple de rôles**
/// Material (fond / premier plan) que le consommateur traduit depuis le
/// `ColorScheme` courant : l'hôte choisit un rôle, jamais un hex (invariant FR-26)
/// — même patron que [ZSubfolderSelectedEmphasis].
enum ZStudySectionCountRole {
  /// Fond `secondaryContainer`, texte `onSecondaryContainer`.
  /// **Rendu historique.**
  secondaryContainer,

  /// Fond `primaryContainer`, texte `onPrimaryContainer`.
  primaryContainer,

  /// Fond `primary`, texte `onPrimary` — l'« accent, texte inversé » de la
  /// référence, exprimé comme rôle et non comme couleur.
  primary,

  /// Fond `tertiaryContainer`, texte `onTertiaryContainer`.
  tertiaryContainer,

  /// Fond `inverseSurface`, texte `onInverseSurface` — contraste maximal
  /// disponible quel que soit le `ColorScheme` (cf.
  /// [ZSubfolderSelectedEmphasis.inverted]).
  inverseSurface,
}

/// Placement de l'affordance de REPLI d'une section d'étude —
/// token de LOOK (structure d'en-tête).
///
/// **Pourquoi un token de THÈME et non un champ de spec** : c'est une
/// décision d'apparence **par application** (toutes les sections d'une app
/// replient au même endroit), pas par descripteur — une spec par section
/// inviterait des en-têtes incohérents entre sections voisines. Même arbitrage
/// que [ZcrudTheme.subfolderBarPadding] (apparence ⇒ thème).
enum ZStudySectionCollapsePlacement {
  /// Chevron rendu **sous** le titre, aligné au début. **Rendu historique** —
  /// c'est ce que rend un thème qui ne déclare rien.
  belowTitle,

  /// Chevron rendu **dans la ligne d'en-tête, côté fin** (après les actions) —
  /// l'en-tête redevient une ligne unique, le repère de repli reste dans le
  /// rang qu'il commande. Cible ≥ 48 dp GARANTIE par le consommateur, même
  /// titre long (le titre est flexible, jamais le chevron).
  inHeaderRow,
}

/// PLACEMENT du compteur d'en-tête d'une section d'étude —
/// token de LOOK (structure d'en-tête).
///
/// **Pourquoi un token de THÈME et non un champ de spec** : même arbitrage
/// que [ZStudySectionCollapsePlacement] — toutes les sections d'une même app
/// qualifient leur titre de la même façon ; un champ par section inviterait
/// des en-têtes incohérents entre sections voisines.
enum ZStudySectionCountPlacement {
  /// Compteur renvoyé à l'**extrémité** de la ligne d'en-tête : le titre est
  /// `Expanded` et POUSSE le compteur près des actions/du chevron. **Rendu
  /// historique** — c'est ce que rend un thème qui ne déclare rien.
  lineEnd,

  /// Compteur **ADJACENT au titre** : le titre n'est plus `Expanded` mais
  /// `Flexible` (il s'ellipse), le compteur le SUIT immédiatement, et l'espace
  /// restant est laissé libre avant les actions. Le compteur qualifie alors le
  /// titre (« Notes — 6 ») et non le bord de l'écran.
  ///
  /// Le compteur n'est JAMAIS écrasé par un titre long : il reste inflexible,
  /// c'est le titre qui rétrécit (invariant mesuré à 320 dp, LTR et RTL).
  adjacentToTitle,
}

/// Hiérarchie tuile/glyphe d'une **carte d'item d'étude par défaut** —
/// token de LOOK.
///
/// **Aucune couleur ici** : la hiérarchie dit OÙ la couleur d'accent se
/// pose, jamais laquelle (la couleur reste un rôle/une entrée injectable).
/// Même frontière que [ZStudySectionCountShape] : la forme monte, la
/// matière reste au thème.
enum ZStudyCardHierarchy {
  /// **Rendu de référence** : tuile NEUTRE (`surface`),
  /// glyphe teinté par l'accent résolu. C'est ce que rend un thème qui ne
  /// déclare rien.
  tintedGlyph,

  /// Rendu alternatif : tuile colorée par l'accent, glyphe en `onColor`
  /// apparié. Atteignable par réglage — plus un défaut.
  tintedTile,
}

/// Alignement VERTICAL du contenu d'une **carte d'item d'étude** —
/// token de LOOK, aucune couleur, aucune dimension.
///
/// **N'a d'effet QUE sous une hauteur IMPOSÉE** (cadre reçu du parent :
/// `SizedBox(height:)`, cellule de grille, `ZRailItem(height:)`). Sans cadre,
/// la carte se dimensionne sur son contenu : il n'y a **aucun espace libre à
/// répartir**, et les trois valeurs rendent alors STRICTEMENT la même chose —
/// c'est ce qui rend ce token neutre par construction pour les hôtes qui ne
/// bornent pas leurs cartes.
enum ZStudyCardContentAlignment {
  /// Contenu collé en HAUT du cadre ; l'espace libre reste sous le pied.
  top,

  /// **Rendu de référence** de la carte de flashcard :
  /// l'espace libre est absorbé par le **bloc de titre** (l'énoncé), ce qui
  /// pousse le pied (pastille de type) au **bas** du cadre. C'est la cascade
  /// `Expanded` de référence — en-tête fixe, énoncé extensible, pied en bas.
  spread,

  /// Contenu collé en BAS du cadre ; l'espace libre reste au-dessus de
  /// l'en-tête.
  bottom,
}

/// DISPOSITION du bas de carte d'une carte de dossier d'étude
/// (`ZFolderCard` / `ZDefaultFolderCard`) — token de LOOK :
/// il dit OÙ va le pied, jamais ce qu'il contient.
///
/// **Le défaut mesuré qui l'a fait exister** : la primitive assemblait le
/// créneau compteur et le créneau pied dans la MÊME `Row`, chacun en
/// `Expanded` — donc chacun à la MOITIÉ de la largeur. Mesuré : une
/// carte à quatre badges de compteur n'en montrait plus que **deux**, et le
/// pied (« Par toi ») venait s'accoler au dernier badge visible. Le seul
/// contournement possible — recomposer soi-même le créneau compteur — **rend
/// à l'hôte le rendu des badges**, donc lui fait perdre le plancher de
/// contraste que `ZDefaultFolderCard` garantit.
///
/// Priorité, partout : paramètre de carte > ce jeton > défaut-référence.
enum ZFolderCardFooterPlacement {
  /// Compteur et pied **côte à côte**, chacun en `Expanded` d'une même ligne —
  /// **rendu HISTORIQUE de la primitive** `ZFolderCard`, et ce qu'elle rend
  /// toujours quand personne ne déclare rien (aucun hôte passif ne bouge).
  ///
  /// Raisonnable pour un pied court **et un seul** compteur ; c'est au-delà
  /// que la moitié de largeur devient une amputation.
  beside,

  /// Pied **EMPILÉ SOUS** le compteur : le compteur reçoit la largeur ENTIÈRE
  /// de la carte (il peut donc défiler sur toute la largeur), le pied vient
  /// dessous. Coût : une ligne de plus, donc la hauteur d'une ligne de texte
  /// plus `gapS`.
  ///
  /// **Le badge « Archivé » suit la DERNIÈRE ligne de la pile** : le poser
  /// sur la ligne des compteurs recréerait exactement l'amputation corrigée
  /// ici. Quand il n'y a qu'une ligne (pied ou compteur absent), cette règle
  /// rend donc STRICTEMENT ce que rend [beside].
  below,

  /// **Empilé en étroit, côte à côte en large** : bascule sur [beside] dès que
  /// la largeur offerte au bas de carte atteint le seuil
  /// (`ZcrudTheme.folderCardFooterBesideMinWidth`, paramètre `footerBesideMinWidth`).
  ///
  /// Largeur NON BORNÉE ⇒ repli sur [beside] (AD-10) : sans largeur finie il
  /// n'y a pas de seuil à comparer, et la ligne unique est le régime que la
  /// primitive a toujours rendu.
  adaptive,
}

/// Densité du **hub d'ajout de contenu** (`ZContentHubSheet`).
///
/// **Le défaut est le rendu de RÉFÉRENCE** (sections titrées, pastille
/// d'identité, badge de mise en avant, entrées en cartes, chevron), avec
/// hauteur d'item de référence **assumée** et **défilement attendu**.
///
/// **La densité compacte ne disparaît pas — elle cesse d'être le défaut.**
/// L'argument d'ÉCHELLE reste vrai (« à douze types, la mise en
/// page en cartes demanderait trois ou quatre écrans ») : [compact] y répond, et
/// il est atteignable **par paramètre** (`ZContentHubSheet.density`) **ET par
/// jeton** ([ZcrudTheme.contentHubDensity]) — priorité paramètre > jeton >
/// référence.
enum ZContentHubDensity {
  /// **Rendu de référence** (défaut) : entrées en cartes à la
  /// hauteur d'item de référence (112), pastille circulaire teintée, chevron
  /// d'affordance, intitulés de section, grille à deux colonnes au-delà du
  /// point de rupture.
  comfortable,

  /// **La densité compacte antérieure**, restituée par réglage : une entrée =
  /// une ligne au plancher de 48 dp, glyphe nu (aucune pastille), ni chevron ni
  /// carte, **une seule colonne** quelle que soit la largeur. Les intitulés de
  /// section restent rendus (ils sont une capacité, pas une décoration).
  compact,
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
    this.fieldFillColor,
    this.fieldFocusedBorderColor,
    this.dateFieldDecorated,
    this.errorColor,
    this.onErrorColor,
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
    this.fieldGap,
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
    this.readLayout,
    this.readCardMargin,
    this.readPadding,
    this.readLabelGap,
    this.readLabelTextStyle,
    this.readValueTextStyle,
    this.readFillColor,
    this.readBorderColor,
    this.readBorderWidth,
    this.readCardMinHeight,
    this.readRowLabelWidth,
    this.readRowMinWidth,
    this.subListColumnMinWidth,
    this.subListActionIconSize,
    this.subListViewActionColor,
    this.subListEditActionColor,
    this.subListDeleteActionColor,
    this.subListAddControlColor,
    this.subListAddControlGradient,
    this.subListAddControlRadius,
    this.subListAddControlSize,
    this.subListAddControlIconColor,
    this.adornmentIconBackgroundAlpha,
    this.adornmentIconBackgroundRadius,
    this.adornmentIconSize,
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
    this.subfolderTriggerFill,
    this.subfolderTriggerBorder,
    this.subfolderTriggerElevation,
    this.subfolderTriggerCollapsedIcon,
    this.subfolderTriggerExpandedIcon,
    this.subfolderSelectedEmphasis,
    this.subfolderBarPadding,
    this.subfolderSheetPadding,
    this.subfolderSheetTitleAlign,
    this.railItemWidth,
    this.railItemHeight,
    this.railItemGap,
    this.railPadding,
    this.studySectionTitleStyle,
    this.studySectionCountShape,
    this.studySectionCountRole,
    this.studySectionCollapsePlacement,
    this.studySectionCountPlacement,
    this.studySectionCountGap,
    this.subfolderSheetContentPadding,
    this.studyCardHierarchy,
    this.studyCardLeadingGap,
    this.studyCardElevation,
    this.studyCardRadius,
    this.studyCardContentPadding,
    this.studyCardMargin,
    this.studyCardIconTileSize,
    this.studyCardIconTileRadius,
    this.studyCardTitleStyle,
    this.studyCardSubtitleStyle,
    this.studyCardBorderSide,
    this.studyCardBadgeRadius,
    this.studyCardGlyphSize,
    this.studyCardContentAlignment,
    this.flashcardTypeGradients,
    this.folderCardRadius,
    this.folderCardBorderSide,
    this.folderCardContentPadding,
    this.folderCardAccentHeight,
    this.folderCardTintAlpha,
    this.folderCardIconTileSize,
    this.folderCardIconTileRadius,
    this.folderCardIconTileTintAlpha,
    this.folderCardGlyphSize,
    this.folderCardMinContrast,
    this.folderCardFooterPlacement,
    this.folderCardFooterBesideMinWidth,
    this.studySessionStackFlex,
    this.studySessionInputFlex,
    this.studySessionContentPadding,
    this.studySessionDividerThickness,
    this.studySessionSectionGap,
    this.studySessionMinTarget,
    this.studySessionCounterStyle,
    this.dailyTasksBandPadding,
    this.dailyTasksDayCellMargin,
    this.dailyTasksDayCellPadding,
    this.dailyTasksDayCellRadius,
    this.dailyTasksMinTapTarget,
    this.dailyTasksMonthBreakpoint,
    this.dailyTasksItemPadding,
    this.contentHubDensity,
    this.contentHubItemExtent,
    this.contentHubItemRadius,
    this.contentHubItemPadding,
    this.contentHubItemTintAlpha,
    this.contentHubAvatarSize,
    this.contentHubAvatarTintAlpha,
    this.contentHubGlyphSize,
    this.contentHubAccents,
    this.contentHubBadgeColor,
    this.contentHubGridBreakpoint,
    this.contentHubGridCrossAxisCount,
    this.contentHubMinContrast,
    this.contentHubSectionTitleStyle,
    this.pageHeaderTitleStyle,
    this.pageHeaderSubtitleStyle,
    this.pageHeaderTabSelectedLabelStyle,
    this.pageHeaderTabUnselectedLabelStyle,
    this.chatBubbleWidthFactor,
    this.chatRequestBubbleRadius,
    this.chatResponseBubbleRadius,
    this.chatBubbleShowAuthorAvatar,
    this.chatBubbleShowAuthorName,
    this.chatBubbleShowTimestamp,
    this.chatToolAccentColor,
    this.chatCapabilityAccents,
    this.chatBusyPalette,
    this.chatComposerSendTargetSize,
    this.chatComposerSendScaleIdle,
    this.chatComposerSendScaleActive,
    this.chatComposerSendScaleDuration,
    this.chatComposerMobileBreakpoint,
    this.chatComposerHintRotationPeriod,
    this.chatComposerHintSwitchDuration,
    this.chatComposerActiveAccent,
    this.chatResponseLengthAccents,
    this.chatSelectedEmphasisWeight,
    this.chatSelectedEmphasisDecoration,
    this.editionSheetFrameMode,
    this.editionSheetWidthRatio,
    this.editionSheetMaxWidth,
    this.editionSheetBorderColor,
    this.editionSheetBorderWidth,
    this.editionChromeMinTouchTarget,
    this.editionChromeHeaderPadding,
    this.editionChromeActionBarPadding,
    this.editionChromePageHeaderExpandedHeight,
    this.selectTileBorderColor,
    this.selectTileBorderWidth,
    this.selectTileRadius,
    this.selectTileMinHeight,
    this.selectDialogBreakpoint,
    this.selectMonoChoiceStyle,
    this.selectMultiChoiceStyle,
    this.selectModalShape,
    this.stepperRailColor,
    this.stepperRailThickness,
    this.stepperBadgeForegroundColor,
    this.stepperAllStepsGap,
    this.stepperSideBandMaxWidth,
    this.booleanPillActiveColor,
    this.booleanPillInactiveColor,
    this.booleanPillActiveForegroundColor,
    this.booleanPillInactiveForegroundColor,
    this.booleanPillWidth,
    this.booleanPillHeight,
    this.booleanPillThumbSize,
    this.booleanPillRadius,
    this.booleanPillTextStyle,
  });

  /// Repli **dérivé** de [theme] (FR-26 : « hérite du `Theme.of` »). Chaque
  /// couleur est lue depuis `ColorScheme`/`TextTheme` — **aucun littéral hex**.
  factory ZcrudTheme.fallback(ThemeData theme) {
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return ZcrudTheme(
      fieldBorderColor: scheme.outline,
      errorColor: scheme.error,
      onErrorColor: scheme.onError,
      labelColor: text.bodyMedium?.color ?? scheme.onSurface,
      surfaceColor: scheme.surface,
    );
  }

  /// Couleur de bordure de champ (repli : `ColorScheme.outline`).
  ///
  /// Consommée par [inputDecoration] pour `border`
  /// et `enabledBorder` (`fieldBorderColor ?? ColorScheme.outline`). C'est déjà
  /// le jeton de bordure de champ du paquet (consommé par `z_color_field`,
  /// `z_tags_field`, `z_signature_field`, `z_sub_list_field`, `z_app_file_field`,
  /// `z_dynamic_item_field`, et hors-paquet par `zcrud_markdown`/`zcrud_geo`) :
  /// le lire ici **aligne** `inputDecoration` sur le reste du paquet.
  ///
  /// Hôte **passif inchangé au pixel** : [ZcrudTheme.fallback] pose ce jeton
  /// à `ColorScheme.outline`, exactement la valeur codée en dur auparavant.
  ///
  /// N'est **pas** appliquée à `focusedBorder` ni à `errorBorder` : ces deux
  /// bordures sont des **canaux d'état** (focus, erreur), pas un choix de style.
  /// Les teindre de la couleur de repos supprimerait la distinction
  /// repos/focus/erreur — un canal visuel payé pour une couleur (AD-13 : la
  /// couleur ne doit jamais être le seul canal, a fortiori elle ne doit pas en
  /// détruire un). Le focus a son propre jeton, [fieldFocusedBorderColor].
  final Color? fieldBorderColor;

  /// **Remplissage du CHAMP** (`InputDecoration.fillColor`).
  /// `null` (défaut, y compris au repli
  /// [ZcrudTheme.fallback]) ⇒ `ColorScheme.surfaceContainerHighest`, soit le
  /// comportement **strictement** antérieur.
  ///
  /// **Pourquoi un jeton DÉDIÉ et non [surfaceColor]** —
  /// deux raisons MESURÉES :
  /// 1. **Ce ne serait pas une rétro-compat.** [ZcrudTheme.fallback] pose
  ///    `surfaceColor: ColorScheme.surface`, donc **non-null** sur le chemin de
  ///    résolution par défaut ([ZcrudTheme.of] → scope → extension → repli).
  ///    Écrire `surfaceColor ?? surfaceContainerHighest` ferait basculer **tout
  ///    hôte passif** de `surfaceContainerHighest` (mesuré `#E6E0E9` en
  ///    `ThemeData.light()`) à `surface` (`#FEF7FF`) : un changement visuel
  ///    silencieux, pas un repli.
  /// 2. **Confusion sémantique.** [surfaceColor] est documenté « couleur de
  ///    surface » et consommé ailleurs comme fond de BANDE (bandeau composer du
  ///    chat). Fond de section et fond de champ sont deux rôles distincts ;
  ///    les fusionner rendrait l'un inatteignable sans déplacer l'autre.
  ///
  /// C'est donc ce jeton — nullable, **absent du repli** — qui rend le fond de
  /// champ atteignable par thème sans toucher au
  /// `ColorScheme` global de l'app.
  final Color? fieldFillColor;

  /// Couleur de bordure au **focus** (`InputDecoration.focusedBorder`).
  /// `null` (défaut, **absent du repli**) ⇒
  /// `ColorScheme.primary` : comportement strictement antérieur.
  ///
  /// Séparée de [fieldBorderColor] pour que le canal d'état « focus » reste
  /// pilotable **indépendamment** de la bordure de repos (AD-13).
  final Color? fieldFocusedBorderColor;

  /// Bascule d'apparence des familles `date`/`time`/
  /// `dateTime` **et** `dateRange` : `true`/`null` (défaut) ⇒ **champ décoré**
  /// (`InputDecorator` + `zFieldDecoration` : libellé flottant, astérisque
  /// requis, `fieldFillColor`/`fieldBorderColor`) ; `false` ⇒ **rendu historique**
  /// `OutlinedButton` « Libellé : valeur ».
  ///
  /// C'est une **échappatoire**, pas un défaut : la valeur nominale du paquet
  /// est le champ décoré (cohérence avec `text`/`number`/`select`). Un hôte qui tenait au rendu bouton pose
  /// `dateFieldDecorated: false` **globalement** par son thème ; un hôte qui ne
  /// veut basculer qu'un champ passe `ZDateFieldWidget.decorated` /
  /// `ZDateRangeFieldWidget.decorated` (le **paramètre l'emporte sur le jeton**,
  /// chaîne « paramètre > jeton > référence »).
  ///
  /// `null` (et non `true`) par défaut pour que [lerp] d'un thème non renseigné
  /// reste `null` — l'héritage n'est jamais gelé (cf. les autres jetons
  /// nullables). Le consommateur applique son défaut (`?? true`).
  final bool? dateFieldDecorated;

  /// Couleur d'erreur (repli : `ColorScheme.error`).
  final Color? errorColor;

  /// Couleur de **premier plan** d'erreur — ce qui se pose SUR [errorColor]
  /// (repli : `ColorScheme.onError`).
  ///
  /// Jeton **apparié** à [errorColor] : les deux sont alimentés par
  /// [ZcrudTheme.fallback] depuis le même `ColorScheme`, et un consommateur
  /// qui peint un fond d'alerte prend son texte ICI — jamais dans
  /// [surfaceColor], qui n'a aucune raison d'être lisible sur une pastille
  /// d'alerte (leur seul rapport est d'être dans la même page).
  ///
  /// Ce jeton **choisit** la couleur ; il ne garantit pas sa lisibilité. Le
  /// consommateur garde son plancher de contraste en garde-fou, de sorte
  /// qu'un couple `errorColor` / `onErrorColor` déclaré illisible soit encore
  /// corrigé.
  final Color? onErrorColor;

  /// Couleur de libellé (repli : `TextTheme.bodyMedium.color`).
  ///
  /// **DÉLIBÉRÉMENT NON consommée par [inputDecoration]**.
  /// La couleur du label d'un champ passe par [labelTextStyle] (`color` non
  /// null), jamais par ce jeton. Deux mesures le justifient :
  /// 1. **Le canal de focus serait détruit.** [inputDecoration] pose
  ///    `floatingLabelStyle`. Material résout le style du label flottant par
  ///    `defaut_état.merge(floatingLabelStyle ?? labelStyle)` : une couleur
  ///    non-null y **écrase** la couleur d'état. Mesuré : sans couleur, le
  ///    label passe de `onSurfaceVariant` au repos à `primary` au focus ;
  ///    avec une couleur imposée, il reste à la couleur imposée **au focus
  ///    aussi** — la distinction repos/focus disparaît (même classe de défaut
  ///    que `TabBar.labelStyle` coloré).
  /// 2. **Même en ne teignant que le label au repos** (`labelStyle` seul,
  ///    forme qui préserve bien le focus — mesuré : repos = couleur imposée,
  ///    focus = `primary`), le rendu de **tout hôte passif** changerait :
  ///    [ZcrudTheme.fallback] pose ce jeton à `TextTheme.bodyMedium.color`
  ///    (mesuré `#1D1B20`) alors que le label au repos rend aujourd'hui
  ///    `onSurfaceVariant` (`#49454F`). Le câbler serait un changement visuel
  ///    silencieux, pas un repli.
  ///
  /// Le jeton reste consommé par les familles qui rendent leur label
  /// **elles-mêmes** (hors `InputDecoration`), où aucun canal d'état n'existe.
  final Color? labelColor;

  /// Couleur de surface (repli : `ColorScheme.surface`).
  ///
  /// Rôle : fond de **section/bande**. Ce n'est **pas** le fond d'un champ —
  /// celui-ci a son jeton dédié [fieldFillColor] (cf. son dartdoc).
  /// Il peint AUSSI le **corps des cartes de champ markdown** (chrome de
  /// `zcrud_markdown`).
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

  /// **Aération du formulaire** (invariant FR-26) : padding **directionnel** posé par
  /// `DynamicEdition` autour de la liste des champs **quand `padding == null`**
  /// (défaut `all(12)`). Token d'espacement injectable (aucune
  /// couleur ; exempté de la garde couleur). Un `padding` explicite passé à
  /// `DynamicEdition` prime toujours sur ce repli.
  final EdgeInsetsDirectional formPadding;

  /// **Aération INTER-CHAMPS** : base d'espacement
  /// consommée par `DynamicEdition` quand aucun `interFieldGap` n'est passé au
  /// widget. `null` (défaut, **absent de [ZcrudTheme.fallback]**) ⇒ la
  /// référence `zFieldGapReference` (**12 dp**).
  ///
  /// Chaîne de résolution : `DynamicEdition.interFieldGap` **>** [fieldGap]
  /// **>** `zFieldGapReference`. Ce jeton rend l'aération pilotable **par
  /// thème** ; jusqu'ici elle n'était atteignable que par paramètre, ce qui
  /// obligeait chaque hôte à la reposer sur **chaque** `DynamicEdition`.
  ///
  /// **L'espace est UNIFORME**
  /// — appliqué entre **deux champs consécutifs** quel que soit leur type, sur
  /// les DEUX voies de rendu (plate et groupée). La table type-dépendante
  /// `zFieldGapAfter` n'est plus consultée par `DynamicEdition` (elle reste
  /// publique et inchangée pour un hôte qui la voudrait). Sans effet en
  /// **grille** (`layout` non vide) : l'espacement y reste `gridGutter` /
  /// `gridRunGutter`, rien ne s'y additionne. Poser `0` ici ramène l'absence
  /// totale d'aération.
  final double? fieldGap;

  // ── Tokens de décoration d'`InputDecoration` ────────────────────────────
  // Aucune couleur codée en dur (invariant FR-26) : les couleurs de bordure/remplissage
  // sont dérivées du `ColorScheme` courant par [inputDecoration], sauf si un
  // jeton NULLABLE les vise ([fieldBorderColor], [fieldFillColor],
  // [fieldFocusedBorderColor]) — auquel cas la valeur vient du THÈME de l'hôte,
  // jamais d'un littéral du paquet.

  /// Rayon de bordure des `InputDecoration` (défaut `12`).
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

  /// Style **non-couleur** du hint (défaut : `overflow: clip`).
  final TextStyle? hintTextStyle;

  // ── Tokens de la variante `large` (Card) ──────────────────────────────────

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

  // ── Tokens du mode LECTURE (`ZReadOnlyFieldCard`, `readOnlyWidget`).
  //    Aucune couleur : fond/filet/styles DÉRIVÉS du `ColorScheme`/`TextTheme`
  //    (invariant FR-26), et chaque jeton `null` par défaut ⇒ « la valeur propre
  //    à la forme rendue » ([ZReadFieldLayout]). Un jeton déclaré s'applique à
  //    TOUTES les formes. ─

  /// **Forme** des champs présentés en consultation, pour toute l'application.
  ///
  /// `null` (défaut) ⇒ [ZReadFieldLayout.card]. Une surface d'édition la
  /// surcharge (`DynamicEdition.readLayout`), un champ aussi
  /// (`ZFieldSpec.readLayout`) ; la priorité va du plus proche au plus
  /// lointain : champ > surface > ce jeton > défaut.
  final ZReadFieldLayout? readLayout;

  /// Marge **directionnelle** autour d'un champ consulté. `null` (défaut) ⇒
  /// aucune marge : les rangs se suivent, leur propre padding les aère.
  final EdgeInsetsDirectional? readCardMargin;

  /// Padding interne **directionnel** d'un champ consulté. `null` (défaut) ⇒ le
  /// padding propre à la forme rendue (`16`/`8` en fiche, `16`/`4` en ligne
  /// dense) ; [ZReadFieldLayout.listTile] garde le retrait de Material.
  final EdgeInsetsDirectional? readPadding;

  /// Écart entre le libellé et la valeur. `null` (défaut) ⇒ l'écart propre à la
  /// forme rendue (`0` en fiche — libellé et valeur sur deux lignes contiguës,
  /// `2` en liste de définitions, `8` à l'horizontale).
  final double? readLabelGap;

  /// Style du libellé, **fusionné par-dessus** celui de la forme rendue : un
  /// style sans couleur garde la couleur dérivée. `null` (défaut) ⇒ le style de
  /// la forme.
  final TextStyle? readLabelTextStyle;

  /// Style de la valeur, **fusionné par-dessus** celui de la forme rendue : un
  /// style sans couleur garde la couleur dérivée. `null` (défaut) ⇒ le style de
  /// la forme.
  final TextStyle? readValueTextStyle;

  /// Fond de la fiche de lecture, dans les **cinq** formes. `null` (défaut) ⇒
  /// **transparent** : la fiche est posée à plat sur le fond de la page, à la
  /// manière d'une ligne de liste — la présentation que suivent les
  /// consultations imprimables.
  ///
  /// Poser `scheme.surfaceContainerLow` pour retrouver une fiche **remplie**.
  ///
  /// C'est une propriété de la **fiche**, pas de la **forme** : le fond peint
  /// est le même en [ZReadFieldLayout.card], en [ZReadFieldLayout.listTile] et
  /// dans les trois formes denses. Déclaré, il fait naître le conteneur de la
  /// fiche là où la forme n'en construit pas (voir [readBorderWidth]) ;
  /// non déclaré, aucun conteneur n'est monté et le défaut reste intact.
  final Color? readFillColor;

  /// Couleur du filet de la fiche de lecture, dans les **cinq** formes. `null`
  /// (défaut) ⇒ `outline`.
  ///
  /// Sert avec [readBorderWidth] : c'est ce couple, et non celui des champs de
  /// saisie, qui décide si une fiche est **encadrée**. Avant ces deux jetons,
  /// la fiche empruntait la largeur de filet des champs de saisie
  /// ([inputBorderWidth]) : la retirer de la fiche retirait aussi celle des
  /// champs, donc c'était impraticable.
  ///
  /// ⚠️ **Seul, ce jeton ne peint rien** : sans [readBorderWidth] la largeur
  /// retombe à `0`, donc `BorderSide.none`. Il ne fait donc pas naître à lui
  /// seul le conteneur des formes qui n'en construisent pas.
  final Color? readBorderColor;

  /// Épaisseur du filet de la fiche de lecture, dans les **cinq** formes.
  /// `null` (défaut) ⇒ **`0`, donc aucun filet**. Poser `1` (avec
  /// [readBorderColor] si besoin) pour retrouver une fiche cernée.
  ///
  /// Strictement positif, il fait naître le conteneur de la fiche dans les
  /// formes qui n'en construisent pas ([ZReadFieldLayout.listTile] et les trois
  /// formes denses), au même rayon ([inputRadius]) qu'en
  /// [ZReadFieldLayout.card]. Ce conteneur n'apporte ni [readCardMinHeight] ni
  /// bouton de copie : les hauteurs propres à chaque forme ne bougent pas.
  final double? readBorderWidth;

  /// Hauteur minimale d'un rang — **propre à [ZReadFieldLayout.card]**, et
  /// désormais le seul jeton de fiche à l'être : [readFillColor],
  /// [readBorderColor] et [readBorderWidth] portent, eux, dans les cinq formes.
  /// Le déclarer ne touche donc pas aux hauteurs des formes denses (54 / 36 /
  /// 28), encadrées ou non.
  ///
  /// `null` (défaut) ⇒ `72`, la hauteur d'une ligne Material à deux lignes :
  /// c'est elle qui donne à la consultation le même rythme vertical qu'une
  /// liste. `0` la supprime (le rang prend alors la hauteur de son contenu).
  final double? readCardMinHeight;

  /// Largeur de la colonne des libellés en [ZReadFieldLayout.inlineRow].
  /// `null` (défaut) ⇒ `160`.
  final double? readRowLabelWidth;

  /// Largeur en deçà de laquelle [ZReadFieldLayout.inlineRow] se **replie** en
  /// présentation empilée. `null` (défaut) ⇒ `360` : sur téléphone, une ligne à
  /// deux colonnes n'a plus la place de le rester.
  final double? readRowMinWidth;

  /// Largeur minimale qu'une **colonne de résumé de sous-liste** doit garder
  /// pour rester lisible, gouttière comprise.
  ///
  /// C'est ce jeton qui décide quand une sous-liste à en-têtes abandonne sa
  /// table alignée pour empiler chaque ligne en couples libellé/valeur : la
  /// table est conservée tant que la largeur restante, actions de ligne
  /// déduites, laisse à **chaque** colonne au moins cette largeur.
  ///
  /// `null` (défaut) ⇒ la valeur est **dérivée** de [readRowLabelWidth] (160
  /// par défaut) : une colonne est coiffée par le libellé de son champ, elle
  /// doit donc être au moins aussi large que la colonne de libellés qu'un
  /// champ consulté en ligne se réserve déjà. Le poser ici permet de régler le
  /// repli des sous-listes **sans** toucher à la présentation des champs
  /// consultés en ligne.
  final double? subListColumnMinWidth;

  /// Taille (dp) des icônes des **actions de ligne** d'une sous-liste compacte
  /// (consulter / modifier / supprimer / restaurer / flèches d'ordre). `null`
  /// (défaut) ⇒ la taille native d'`IconButton` — rendu strictement inchangé.
  /// La cible tactile des boutons reste ≥ 48 dp quelle que soit la taille de
  /// glyphe déclarée.
  final double? subListActionIconSize;

  /// Couleur de l'icône « **consulter** » d'une ligne de sous-liste compacte.
  /// `null` (défaut) ⇒ couleur d'icône ambiante — rendu inchangé. La couleur
  /// n'agit que sur l'AFFICHAGE : l'action reste gouvernée par l'ACL et par la
  /// préférence `ZSubListConfig.showViewAction`.
  final Color? subListViewActionColor;

  /// Couleur de l'icône « **modifier** » d'une ligne de sous-liste compacte.
  /// `null` (défaut) ⇒ couleur d'icône ambiante — rendu inchangé.
  final Color? subListEditActionColor;

  /// Couleur de l'icône « **supprimer** » d'une ligne de sous-liste compacte.
  /// `null` (défaut) ⇒ couleur d'icône ambiante — rendu inchangé.
  final Color? subListDeleteActionColor;

  /// **Fond uni** du contrôle d'ajout d'une sous-liste (bouton `+` ou menu de
  /// gabarits). `null` (défaut) ⇒ aucun conteneur n'est ajouté à l'arbre : le
  /// bouton nu, inchangé. Ignoré quand [subListAddControlGradient] est
  /// déclaré (le dégradé prime sur le fond uni).
  final Color? subListAddControlColor;

  /// **Dégradé** du contrôle d'ajout d'une sous-liste. `null` (défaut) ⇒
  /// aucun. Prime sur [subListAddControlColor].
  final Gradient? subListAddControlGradient;

  /// **Rayon** du conteneur du contrôle d'ajout. `null` (défaut) ⇒ coins
  /// droits — et aucun conteneur si aucun autre jeton `subListAddControl*`
  /// n'est déclaré.
  final Radius? subListAddControlRadius;

  /// **Côté** (dp) du conteneur carré du contrôle d'ajout. `null` (défaut) ⇒
  /// la taille native du bouton. Le bouton interne conserve sa sémantique,
  /// son tooltip et sa cible tactile ≥ 48 dp.
  final double? subListAddControlSize;

  /// Couleur de l'**icône** du contrôle d'ajout (`Icons.add`). `null`
  /// (défaut) ⇒ couleur d'icône ambiante — rendu inchangé.
  final Color? subListAddControlIconColor;

  /// **Opacité** (`0..1`) du fond de la « pastille » peinte sous un ornement
  /// **icône** `prefix`/`suffix` décoratif d'un champ. La pastille est remplie
  /// de la **teinte par type de champ** résolue pour ce champ (déjà normalisée
  /// pour le contraste), atténuée par cette opacité.
  ///
  /// `null` (défaut) ⇒ aucune pastille : aucun conteneur n'est ajouté à
  /// l'arbre, rendu strictement inchangé. Sans teinte résolue pour le champ,
  /// aucune pastille non plus — le fond n'a **pas d'autre source de couleur**
  /// (jamais une couleur inventée). Un ornement icône **interactif** garde son
  /// affordance native (cible ≥ 48 dp) et n'est pas enveloppé.
  final double? adornmentIconBackgroundAlpha;

  /// **Rayon** des coins de la pastille d'ornement icône. `null` (défaut) ⇒
  /// coins droits. Sans [adornmentIconBackgroundAlpha], aucun conteneur n'est
  /// ajouté : le rayon seul ne peint rien.
  final Radius? adornmentIconBackgroundRadius;

  /// **Taille** (dp) du glyphe des ornements icône (`leading`/`prefix`/
  /// `suffix`). `null` (défaut) ⇒ taille du `IconTheme` ambiant — rendu
  /// inchangé. Canal de **dimension**, indépendant de la teinte et de la
  /// pastille : il s'applique même sans elles.
  final double? adornmentIconSize;

  /// Hauteur future de la barre d'accent. `null` conserve le rendu par défaut.
  final double? accentBarHeight;

  /// Début directionnel du dégradé. `null` conserve le rendu par défaut.
  final AlignmentGeometry? gradientBegin;

  /// Fin directionnelle du dégradé. `null` conserve le rendu par défaut.
  final AlignmentGeometry? gradientEnd;

  /// Flou de l'ombre de carte. `null` conserve le rendu par défaut.
  final double? cardShadowBlurRadius;

  /// Décalage de l'ombre de carte. `null` conserve le rendu par défaut.
  final Offset? cardShadowOffset;

  /// Opacité de l'ombre de carte. `null` conserve le rendu par défaut.
  final double? cardShadowAlpha;

  /// Opacité de teinte de carte. `null` conserve le rendu par défaut.
  final double? cardTintAlpha;

  /// Taille future du conteneur d'icône. `null` conserve le rendu par défaut.
  final double? iconContainerSize;

  /// Rayon futur du conteneur d'icône. `null` conserve le rendu par défaut.
  final Radius? iconContainerRadius;

  /// Padding directionnel de la pastille de compteur. `null` conserve le rendu par défaut.
  final EdgeInsetsDirectional? countPillPadding;

  /// Rayon de la pastille de compteur. `null` conserve le rendu par défaut.
  final Radius? countPillRadius;

  /// Taille d'icône de la pastille de compteur. `null` conserve le rendu par défaut.
  final double? countPillIconSize;

  /// Durée de célébration. `null` conserve le rendu par défaut.
  final Duration? celebrationDuration;

  /// Courbe de célébration. `null` conserve le rendu par défaut.
  final Curve? celebrationCurve;

  /// Durée de retournement. `null` conserve le rendu par défaut.
  final Duration? flipDuration;

  /// Courbe de retournement. `null` conserve le rendu par défaut.
  final Curve? flipCurve;

  /// Habillage du déclencheur de navigation de fratrie.
  /// `null` ⇒ [ZSubfolderTriggerVariant.flat], rendu **strictement inchangé**.
  ///
  /// La variante reste l'API publiée et reste
  /// fonctionnelle telle quelle. Les trois attributs composables
  /// ([subfolderTriggerFill], [subfolderTriggerBorder],
  /// [subfolderTriggerElevation]) la **raffinent** : fournis, ils priment
  /// **attribut par attribut** ; absents (`null`), la variante décide.
  final ZSubfolderTriggerVariant? subfolderTriggerVariant;

  /// RÔLE de fond du déclencheur de fratrie — composable.
  ///
  /// `null` ⇒ [subfolderTriggerVariant] décide du fond (rendu **strictement
  /// inchangé** pour tout thème existant). Fourni, il PRIME sur le fond de la
  /// variante — et seulement sur lui. [ZSubfolderTriggerFill.none] est le
  /// retrait EXPLICITE du fond.
  final ZSubfolderTriggerFill? subfolderTriggerFill;

  /// RÔLE de bordure du déclencheur de fratrie — composable.
  ///
  /// `null` ⇒ [subfolderTriggerVariant] décide de la bordure (rendu
  /// **strictement inchangé**). Fourni, il PRIME sur la bordure de la variante
  /// — et seulement sur elle. [ZSubfolderTriggerBorder.none] est le retrait
  /// EXPLICITE de la bordure.
  final ZSubfolderTriggerBorder? subfolderTriggerBorder;

  /// RELIEF du déclencheur de fratrie — composable, en dp
  /// d'élévation Material.
  ///
  /// `null` ⇒ aucune variante n'a d'élévation : rendu **strictement
  /// inchangé**. Fourni (> 0), le consommateur rend une élévation **TONALE M3**
  /// (voile `ColorScheme.surfaceTint` gradué par l'élévation), **JAMAIS une
  /// ombre portée** — arbitrage MESURÉ côté `zcrud_study` : le déclencheur vit
  /// dans le `bottom:` de l'app-bar (`aboveTabBar`), bord à bord au-dessus du
  /// `TabBar`, sans aucun clip interposé ; toute ombre portée descendante s'y
  /// projetterait. Cf. `_triggerChrome` (`z_subfolder_selector_bar.dart`).
  final double? subfolderTriggerElevation;

  /// Glyphe du chevron quand la fratrie est **fermée**.
  /// `null` ⇒ repli conventionnel du consommateur (`Icons.expand_more`).
  ///
  /// Un `IconData` est un **glyphe**, jamais un libellé : il ne se traduit pas.
  /// Il reste néanmoins un choix de LOOK, donc injecté et non figé.
  final IconData? subfolderTriggerCollapsedIcon;

  /// Glyphe du chevron quand la fratrie est **ouverte**.
  /// `null` ⇒ repli conventionnel du consommateur (`Icons.expand_less`).
  final IconData? subfolderTriggerExpandedIcon;

  /// Mise en évidence de l'élément courant.
  /// `null` ⇒ [ZSubfolderSelectedEmphasis.highlight], rendu **inchangé**.
  final ZSubfolderSelectedEmphasis? subfolderSelectedEmphasis;

  /// Marge EXTÉRIEURE de la barre de fratrie.
  /// `null` ⇒ **aucune enveloppe dans l'arbre**, rendu strictement inchangé
  /// (la barre reste bord à bord dans son parent).
  ///
  /// **Pourquoi un token de THÈME et non un champ de spec** : les quatre
  /// réglages déjà existants de cette surface (`subfolderTriggerVariant`,
  /// les deux glyphes de chevron, `subfolderSelectedEmphasis`) sont des tokens
  /// de thème, et une marge est une décision d'**apparence**, pas de structure.
  /// La poser dans la spec la ferait voyager avec les données de fratrie, qui
  /// n'en savent rien.
  ///
  /// **AD-13** : type `EdgeInsetsGeometry` — un `EdgeInsetsDirectional` y est
  /// admis tel quel et bascule en RTL. Un `EdgeInsets.only(left:)` reste
  /// possible pour l'hôte qui veut délibérément une marge physique ; c'est SON
  /// choix, jamais un défaut du socle.
  final EdgeInsetsGeometry? subfolderBarPadding;

  /// Marge EXTÉRIEURE du contenu de la **feuille** de fratrie —
  /// **pendant exact** de [subfolderBarPadding], côté feuille.
  ///
  /// `null` ⇒ **aucune enveloppe dans l'arbre**, rendu strictement inchangé (la
  /// feuille conserve sa seule gouttière interne `gapM`).
  ///
  /// **S'ajoute à la gouttière interne, il ne la remplace pas** : la
  /// neutralité littérale exige que `null` laisse l'arbre historique intact.
  /// Remplacer la gouttière aurait fait de « je veux 4 dp de plus » un « je
  /// perds les 16 dp que j'avais ».
  ///
  /// **Elle n'entame PAS le plafond de 80 % de hauteur d'écran** de la
  /// feuille : ce plafond est posé en `constraints` sur la feuille
  /// ELLE-MÊME par `showModalBottomSheet`, donc au-DESSUS de cette marge. Une
  /// marge verticale généreuse réduit la hauteur du CONTENU, jamais celle de la
  /// feuille — et la liste, `Flexible`, absorbe la différence.
  ///
  /// **AD-13** : `EdgeInsetsGeometry` — un `EdgeInsetsDirectional` bascule en
  /// RTL. Un `EdgeInsets.only(left:)` reste possible pour l'hôte qui veut
  /// délibérément une marge physique ; c'est SON choix, jamais un défaut du
  /// socle (même arbitrage que [subfolderBarPadding]).
  final EdgeInsetsGeometry? subfolderSheetPadding;

  /// Alignement du **titre** de la feuille de fratrie.
  ///
  /// `null` ⇒ [TextAlign.start], rendu strictement inchangé.
  ///
  /// **AD-13** : préférer les valeurs **directionnelles** ([TextAlign.start],
  /// [TextAlign.end]) ou la valeur neutre [TextAlign.center] — elles basculent
  /// (ou restent neutres) en RTL. [TextAlign.left]/[TextAlign.right] restent
  /// acceptées : ce sont des alignements **physiques**, donc un choix délibéré
  /// de l'hôte, jamais une décision du socle. Même arbitrage que
  /// [subfolderBarPadding] vis-à-vis d'`EdgeInsets.only(left:)` : le socle ne
  /// borne pas ce que l'hôte demande, il documente ce qu'il recommande.
  ///
  /// **Pourquoi un token de THÈME et non un champ de spec** : c'est une
  /// décision d'**apparence** pure — elle ne fait apparaître ni disparaître
  /// aucun contrôle, et n'altère aucune donnée de fratrie (critère posé par
  /// `ZSubfolderAddPlacement`, qui est resté dans la spec pour la raison
  /// inverse). Le titre lui-même, en revanche, est un LIBELLÉ : il reste dans
  /// la spec (`sheetTitle`), car un paquet ne code aucune chaîne (invariant FR-26).
  final TextAlign? subfolderSheetTitleAlign;

  /// Largeur d'un item de **rail horizontal** rendu PAR DÉFAUT par un
  /// consommateur (voies typées `ZStudyToolsSectionSpec` de
  /// `zcrud_study`).
  ///
  /// `null` ⇒ le consommateur applique SON défaut documenté (280 dp côté
  /// `zcrud_study`) — rendu **strictement inchangé** pour tout thème existant.
  /// La priorité chez le consommateur est : paramètre explicite de la voie
  /// typée > ce token > défaut du consommateur.
  ///
  /// **Pourquoi un token de THÈME** : une largeur d'item est une décision
  /// d'apparence (densité), pas de structure — même arbitrage que
  /// [subfolderBarPadding]. La valeur mesurée chez un hôte de référence reste
  /// SA valeur : il la pose ici, jamais dans le socle.
  final double? railItemWidth;

  /// HAUTEUR d'un item de **rail horizontal** — pendant
  /// exact de [railItemWidth].
  ///
  /// `null` ⇒ **aucune contrainte de hauteur** n'est posée : l'item garde la
  /// hauteur que lui donne son contenu (rendu **strictement inchangé** pour
  /// tout thème existant). Priorité chez le consommateur : paramètre explicite
  /// > ce token > absence de contrainte.
  ///
  /// **Pourquoi PAS de repli chiffré ici, contrairement à [railItemWidth]**
  /// (asymétrie assumée, motivée) : une largeur NON BORNÉE dans un défileur
  /// horizontal est une **faute de layout** (« non-zero flex but incoming
  /// width constraints are unbounded »), d'où un repli obligatoire côté
  /// consommateur ; une hauteur non bornée, elle, est parfaitement licite —
  /// c'est le rendu actuel de tous les rails. Y écrire 200 « parce que c'est
  /// la référence » imposerait cette hauteur à **tous** les items de rail de
  /// **tous** les hôtes, y compris ceux qui n'y mettent pas des flashcards.
  /// La hauteur de RÉFÉRENCE (200) reste portée par la carte de flashcard
  /// par défaut (`ZFlashcardCardReference.cardHeight`), là où elle a un sens.
  final double? railItemHeight;

  /// ESPACEMENT entre deux items d'un **rail horizontal**.
  ///
  /// `null` ⇒ le consommateur applique son repli documenté ([gapS] côté
  /// `zcrud_study`) — rendu **strictement inchangé**. Priorité : paramètre
  /// explicite de la voie typée > ce token > repli du consommateur.
  ///
  /// Ce token existe pour la même raison que [studyCardLeadingGap] :
  /// l'espacement du rail ridait [gapS], jeton que l'hôte
  /// règle déjà pour ses écarts inter-slots — aucune valeur de [gapS] ne
  /// pouvait satisfaire à la fois l'un et le 12 de la référence.
  final double? railItemGap;

  /// PADDING du défileur d'un **rail horizontal** — le
  /// retrait latéral du rail lui-même.
  ///
  /// `null` ⇒ le rail hérite du padding de section du consommateur (chez
  /// `zcrud_study` : `horizontal: gapM`) — rendu **strictement inchangé**.
  /// Non-null ⇒ le retrait latéral du rail devient ABSOLU : le padding
  /// horizontal de section ne s'y AJOUTE plus (il reste appliqué à l'en-tête).
  ///
  /// Le retrait mesuré au **bord de la première carte** vaut ce padding
  /// **plus la marge externe de la carte** (`CardThemeData.margin` /
  /// `studyCardMargin`) : les deux s'additionnent, et c'est précisément le
  /// cumul mesuré (12 + 4 = 16 dp).
  final EdgeInsetsGeometry? railPadding;

  /// Style du TITRE d'un en-tête de section d'étude.
  ///
  /// `null` ⇒ le consommateur applique son repli documenté
  /// (`labelTextStyle`, puis `TextTheme.titleMedium`) — rendu **strictement
  /// inchangé** pour tout thème existant. Non-null ⇒ ce style PRIME : la
  /// référence peut dire « repère de navigation, plus grand et plus gras »
  /// sans qu'aucun rôle de texte ne soit figé dans un paquet.
  final TextStyle? studySectionTitleStyle;

  /// FORME du compteur d'en-tête de section d'étude.
  ///
  /// `null` ⇒ [ZStudySectionCountShape.rounded] (rectangle arrondi,
  /// `badgeRadius` repli `radiusM`) — rendu **strictement inchangé**.
  final ZStudySectionCountShape? studySectionCountShape;

  /// RÔLE de couleur du compteur d'en-tête de section d'étude.
  ///
  /// `null` ⇒ [ZStudySectionCountRole.secondaryContainer] — rendu
  /// **strictement inchangé**. La couleur vient TOUJOURS du `ColorScheme`
  /// courant : ce token nomme un rôle, jamais un hex (invariant FR-26).
  final ZStudySectionCountRole? studySectionCountRole;

  /// PLACEMENT de l'affordance de repli d'une section d'étude.
  ///
  /// `null` ⇒ [ZStudySectionCollapsePlacement.belowTitle] (chevron sous le
  /// titre) — rendu **strictement inchangé**.
  final ZStudySectionCollapsePlacement? studySectionCollapsePlacement;

  /// PLACEMENT du compteur d'en-tête d'une section d'étude.
  ///
  /// `null` ⇒ [ZStudySectionCountPlacement.lineEnd] (compteur à l'extrémité de
  /// la ligne) — rendu **strictement inchangé**.
  final ZStudySectionCountPlacement? studySectionCountPlacement;

  /// ÉCART entre le titre d'en-tête de section et son compteur,
  /// dans les DEUX placements.
  ///
  /// `null` ⇒ [gapS] — le rendu historique. Ce token existe parce que l'écart
  /// titre↔compteur ridait [gapS], jeton générique partagé avec toutes les
  /// autres gouttières de l'en-tête : aucune valeur de [gapS] ne pouvait à la
  /// fois satisfaire la référence (12 entre titre et compteur) et les
  /// espacements inter-actions. Même arbitrage que [studyCardLeadingGap].
  final double? studySectionCountGap;

  /// Padding STRUCTUREL **interne** de la feuille de fratrie :
  /// gouttière de la feuille, padding de son titre,
  /// padding de son pied « ajouter ».
  ///
  /// `null` ⇒ `EdgeInsetsDirectional.all(gapM)` — rendu **strictement
  /// inchangé**. Ce token existe pour la même raison que
  /// [studyCardLeadingGap] : la feuille ridait [gapM], que l'hôte règle déjà
  /// pour le padding de ses cartes (12) alors que sa feuille en demande 8.
  ///
  /// DISTINCT de [subfolderSheetPadding], qui est la marge **EXTÉRIEURE**
  /// de la feuille et qui s'AJOUTE à celle-ci.
  final EdgeInsetsGeometry? subfolderSheetContentPadding;

  // ── Tokens des CARTES D'ITEM D'ÉTUDE par défaut ───────────────────────────
  // Directive owner : les défauts du consommateur (`zcrud_study`) sont le
  // RENDU DE RÉFÉRENCE, centralisé dans `ZStudyCardReference` côté
  // consommateur. Chaque token `null` ⇒ le consommateur applique la valeur de
  // référence documentée. Priorité, partout : paramètre de carte > token >
  // défaut-référence. Aucune couleur figée ici (invariant FR-26) : ce qui porte une
  // couleur ([studyCardBorderSide], les styles) est INJECTÉ par l'hôte.

  /// Hiérarchie tuile/glyphe des cartes d'étude par défaut.
  /// `null` ⇒ [ZStudyCardHierarchy.tintedGlyph] — le rendu de RÉFÉRENCE.
  /// [ZStudyCardHierarchy.tintedTile] restitue exactement le rendu antérieur.
  final ZStudyCardHierarchy? studyCardHierarchy;

  /// Rayon de la carte d'étude par défaut. `null` ⇒ 16 (référence).
  final Radius? studyCardRadius;

  /// ÉCART entre la tuile d'icône de tête et le titre, dans les cartes d'étude
  /// **par défaut**. `null` ⇒ 16 (référence historique).
  ///
  /// Ne concerne QUE les cartes par défaut : la primitive de base
  /// `ZStudyToolsItemCard` garde son écart historique [gapM] pour les hôtes qui
  /// la composent eux-mêmes (neutralité — cf. son slot `leadingGap`).
  ///
  /// Ce token existe parce que cet écart ridait [gapM], que l'hôte règle déjà
  /// pour le padding de carte (12) alors que la référence demande 16 : aucune
  /// valeur de [gapM] ne pouvait satisfaire les deux.
  final double? studyCardLeadingGap;

  /// ÉLÉVATION Material de la carte d'étude par défaut.
  ///
  /// `null` ⇒ **0** (référence historique : `Card(elevation: 0)`, liseré seul,
  /// AUCUNE ombre portée). Le défaut antérieur laissait l'élévation à `null`,
  /// donc au défaut Material 3 (**1.0**) — une ombre que la référence n'a pas.
  ///
  /// Sans effet quand une ombre de jetons `cardShadow*` est active : deux
  /// ombres ne se superposent jamais, l'élévation native cède alors la place
  /// (invariant inchangé).
  final double? studyCardElevation;

  /// Padding INTERNE de la carte d'étude par défaut.
  /// `null` ⇒ `EdgeInsetsDirectional.all(12)` (référence).
  final EdgeInsetsGeometry? studyCardContentPadding;

  /// Marge EXTERNE de la carte d'étude par défaut.
  /// `null` ⇒ `CardThemeData.margin` de l'hôte s'il est fourni, sinon
  /// `EdgeInsetsDirectional.all(4)` (référence) — la marge du `CardTheme`
  /// reste atteignable.
  final EdgeInsetsGeometry? studyCardMargin;

  /// Côté de la tuile d'icône de tête. `null` ⇒ 48 (référence).
  ///
  /// Token DISTINCT de [iconContainerSize] : celui-là a déjà un
  /// consommateur (`ZFolderCardGradientAccent`, repli `gapL`) — le détourner
  /// redimensionnerait la barre d'accent chez tout hôte l'ayant réglée (même
  /// arbitrage que côté `ZFolderCard`).
  final double? studyCardIconTileSize;

  /// Rayon de la tuile d'icône. `null` ⇒ 12 (référence). Distinct de
  /// [iconContainerRadius] (pris par la pastille de `ZFolderCard`).
  final Radius? studyCardIconTileRadius;

  /// Style du TITRE des cartes d'étude par défaut. `null` ⇒
  /// `titleMedium` en `w600`/15 (référence). Un style fourni PRIME.
  final TextStyle? studyCardTitleStyle;

  /// Style du SOUS-TITRE. `null` ⇒ `bodySmall` en `onSurfaceVariant`
  /// (référence — la couleur reste un RÔLE dérivé, jamais un hex du socle).
  final TextStyle? studyCardSubtitleStyle;

  /// Liseré de la carte d'étude par défaut. `null` ⇒ `outlineVariant` à 50 %,
  /// épaisseur 1 (référence, couleur DÉRIVÉE du `ColorScheme` courant). Une
  /// valeur fournie est le choix de l'hôte — elle peut porter sa couleur.
  final BorderSide? studyCardBorderSide;

  /// Rayon du badge d'extension en surimpression (carte de document).
  /// `null` ⇒ [radiusS] (défaut 4 = référence).
  final Radius? studyCardBadgeRadius;

  /// Taille du glyphe dans la tuile d'icône des cartes d'étude par défaut.
  /// `null` ⇒ 28 dp (référence historique, `kStudyToolsLeadingIconSize`) —
  /// PAS la taille d'icône ambiante (24) : la référence est plus grande.
  final double? studyCardGlyphSize;

  /// ALIGNEMENT VERTICAL du contenu des cartes d'étude **par défaut**,
  /// quand un cadre de hauteur leur est imposé.
  ///
  /// `null` ⇒ le consommateur applique sa valeur de RÉFÉRENCE
  /// ([ZStudyCardContentAlignment.spread] pour la carte de flashcard : énoncé
  /// extensible, pied poussé en bas — la cascade de référence).
  ///
  /// **Sans hauteur imposée, ce jeton n'a AUCUN effet** : il n'y a pas
  /// d'espace libre à répartir (cf. la dartdoc de l'énumération).
  final ZStudyCardContentAlignment? studyCardContentAlignment;

  /// Dégradés **par TYPE de flashcard** de la carte de flashcard par défaut —
  /// clé = `ZFlashcardType.name` OPAQUE (`'multipleChoice'`,
  /// `'trueOrFalse'`, `'openQuestion'`, `'exercise'`, ou toute clé future).
  ///
  /// `null` (défaut) ⇒ le consommateur applique sa **RÉFÉRENCE** (patron
  /// `studyCard*` : priorité paramètre > ce jeton > seam
  /// `ZcrudScope.gradientResolver` > défaut-référence). Chaque entrée est un
  /// [ZGradientSpec] : le premier plan [ZGradientSpec.onGradient] est **CHOISI**
  /// par l'hôte (contraste mesuré), jamais deviné depuis le dégradé.
  ///
  /// Un dégradé n'est PAS un rôle de `ColorScheme` : la matière
  /// reste REMPLAÇABLE (ce jeton) même quand elle ne peut pas être DÉRIVÉE.
  final Map<String, ZGradientSpec>? flashcardTypeGradients;

  // ── Carte de DOSSIER d'étude par défaut ───────────────────────────────────
  // La carte de dossier était la SEULE des six de la famille à n'avoir aucun
  // rendu par défaut, et son liseré n'était atteignable NI par paramètre NI par
  // jeton : la forme était bâtie sans `side:`, et les seuls jetons de carte
  // (`cardShadow*`) visaient l'OMBRE. Ces dix jetons répliquent, pour la
  // famille « carte de dossier », le patron déjà en place pour la famille sœur
  // (`studyCard*`) — ils n'en inventent pas un second.
  //
  // Chacun est `null` par DÉFAUT, et `null` signifie « le consommateur
  // applique sa valeur de RÉFÉRENCE » (`ZFolderCardReference`) — jamais « rien
  // ne se rend ». Priorité, partout : paramètre de carte > ce jeton >
  // défaut-référence.

  /// Rayon de la carte de dossier. `null` ⇒ `CardThemeData.shape` de l'hôte
  /// s'il en pose un, sinon le jeton [radiusM] (défaut historique de la
  /// primitive) — la carte PAR DÉFAUT, elle, applique sa référence (12).
  final Radius? folderCardRadius;

  /// Liseré du pourtour de la carte de dossier — **le manque net corrigé**.
  /// `null` ⇒ aucune bordure imposée (rendu historique) ; la
  /// carte PAR DÉFAUT dérive le sien de la couleur du dossier, avec un
  /// plancher de contraste MESURÉ ([folderCardMinContrast]).
  final BorderSide? folderCardBorderSide;

  /// Padding interne de la carte de dossier. `null` ⇒ `gapM` (défaut
  /// historique de la primitive) ; référence de la carte par défaut : 12.
  ///
  /// Ce jeton existe parce que `gapM` vaut 8 en thème nu : sans lui, la
  /// carte par défaut ne pouvait atteindre sa référence qu'en ridant `gapM`
  /// pour TOUT le sous-arbre (défaut corrigé par ailleurs).
  final EdgeInsetsGeometry? folderCardContentPadding;

  /// Hauteur de la bande d'accent de tête de la carte de dossier. `null` ⇒
  /// référence (4).
  final double? folderCardAccentHeight;

  /// Opacité de la teinte de FOND de la carte de dossier par défaut. `null` ⇒
  /// jeton [cardTintAlpha], puis référence (**0** — carte NEUTRE, la couleur
  /// du dossier vivant dans la bande, le liseré et la tuile).
  final double? folderCardTintAlpha;

  /// Côté de la tuile d'icône de la carte de dossier. `null` ⇒ référence (36 —
  /// ni le 48 des cartes d'étude, ni le 32 de la carte de flashcard).
  final double? folderCardIconTileSize;

  /// Rayon de la tuile d'icône de la carte de dossier. `null` ⇒ référence (8).
  final Radius? folderCardIconTileRadius;

  /// Opacité de la teinte de fond de la tuile d'icône. `null` ⇒ référence
  /// (0.15).
  final double? folderCardIconTileTintAlpha;

  /// Taille du glyphe dans la tuile d'icône. `null` ⇒ référence (20).
  final double? folderCardGlyphSize;

  /// Plancher de contraste (WCAG 2.x) imposé aux SURFACES et COMPOSANTS
  /// graphiques dérivés de la couleur du dossier — bande d'accent, liseré,
  /// glyphe de tuile. `null` ⇒ référence (**3.0:1**, §1.4.11).
  ///
  /// **Ce jeton n'est pas un réglage cosmétique** : une couleur de dossier
  /// est choisie par l'utilisateur, donc ARBITRAIRE, et aucune fenêtre de
  /// clarté HSL ne borne son contraste (mesuré : `#FFFF00` rendait 2.13:1 sur
  /// thème clair, `#FFFFFE` 1.28:1). Le relever à 4.5 aligne la carte sur le
  /// plancher du TEXTE normal ; l'abaisser sous 3.0 sort de WCAG AA.
  final double? folderCardMinContrast;

  /// DISPOSITION du bas de carte — compteur et pied côte à côte, empilés, ou
  /// adaptatif. `null` ⇒ le consommateur applique SA
  /// référence : la primitive `ZFolderCard` reste sur
  /// [ZFolderCardFooterPlacement.beside] (rendu historique, aucun hôte passif
  /// ne bouge), `ZDefaultFolderCard` applique
  /// `ZFolderCardReference.footerPlacement`.
  ///
  /// Ce jeton ne dit pas QUOI rendre, il dit OÙ : les deux créneaux restent
  /// rendus par la carte dans les trois valeurs, donc le plancher de contraste
  /// des badges de `ZDefaultFolderCard` tient dans toutes.
  final ZFolderCardFooterPlacement? folderCardFooterPlacement;

  /// Seuil de largeur (dp) au-delà duquel [ZFolderCardFooterPlacement.adaptive]
  /// bascule sur le côte-à-côte, mesuré sur la largeur RÉELLEMENT offerte au
  /// bas de carte (padding interne déjà retranché). `null` ⇒ référence.
  ///
  /// **DISCRET comme un plancher** : un point de rupture interpolé pendant
  /// une transition de thème est un point de rupture que personne n'a choisi —
  /// et il ferait basculer la mise en page au milieu de l'animation.
  final double? folderCardFooterBesideMinWidth;

  // ── Écran de SESSION de révision ───────────────────────────────────────────
  //
  // Ces sept jetons sont le **maillon du milieu** de la chaîne
  // `paramètre > jeton > référence` de `zStudySessionChromeOf`
  // (`zcrud_study/…/z_study_session_reference.dart`), qui n'avait jusqu'ici
  // QUE deux maillons. Sans eux, un hôte ne pouvait régler l'écran de session
  // que site par site, en repassant chaque paramètre à chaque montage.
  //
  // **Aucun jeton GÉNÉRIQUE n'est monté en maillon** — ni `gapM` pour
  // l'écart de section, ni `radiusM` pour un rayon : un jeton générique
  // portant plusieurs valeurs de référence différentes ne peut satisfaire
  // aucune d'entre elles. Chaque jeton ci-dessous vise UNE propriété, d'UN
  // écran.
  //
  // `null` (défaut) ⇒ le consommateur applique sa valeur de RÉFÉRENCE : le
  // rendu d'aujourd'hui est strictement inchangé tant qu'aucun n'est posé.

  /// Part verticale de la **pile de cartes** de l'écran de session.
  /// `null` ⇒ référence (`ZStudySessionReference.stackFlex` = 3).
  ///
  /// **DISCRET** : un `flex` est un entier de contrainte, pas une dimension.
  /// `lerp` le fait donc BASCULER à mi-course (jamais d'entier intermédiaire
  /// fabriqué), et un `null` ne se matérialise jamais en `0` — un `Expanded`
  /// de flex 0 s'effondrerait, faisant disparaître la pile en pleine
  /// transition de thème.
  final int? studySessionStackFlex;

  /// Part verticale de la **zone de saisie/notation** de l'écran de session.
  /// `null` ⇒ référence (`ZStudySessionReference.inputFlex` = 2).
  ///
  /// Même traitement discret que [studySessionStackFlex]. Les deux flex
  /// matérialisent l'invariant « la saisie est un FRÈRE de la pile, jamais un
  /// descendant » (arène des gestes) : les régler ne le remet pas en cause.
  final int? studySessionInputFlex;

  /// Padding interne des zones défilantes de l'écran de session.
  /// `null` ⇒ référence (`EdgeInsetsDirectional.all(12)` — AD-13).
  final EdgeInsetsGeometry? studySessionContentPadding;

  /// Épaisseur du séparateur pile ↔ saisie. `null` ⇒ référence (1).
  final double? studySessionDividerThickness;

  /// Écart vertical entre deux blocs de l'écran de session (repli « session
  /// vide » notamment). `null` ⇒ référence (12).
  final double? studySessionSectionGap;

  /// Cible tap minimale (dp) des affordances de l'écran de session.
  /// `null` ⇒ référence (48, plancher Material/AD-13).
  ///
  /// **PLANCHER, donc discret comme une contrainte, mais interpolable comme
  /// une dimension** : il est ici interpolé (c'est une longueur en dp, et deux
  /// planchers valides encadrent une valeur valide). En revanche `null` ne se
  /// matérialise JAMAIS en `0` : un plancher nul est l'absence de plancher,
  /// et une transition de thème ne doit pas ouvrir une fenêtre pendant
  /// laquelle les cibles descendent sous 48 dp.
  final double? studySessionMinTarget;

  /// Style du compteur de session. `null` ⇒ le consommateur applique son repli
  /// (`TextTheme.labelLarge` du thème courant) — jamais une taille en dur.
  final TextStyle? studySessionCounterStyle;

  // ── Vue des TÂCHES DU JOUR ─────────────────────────────────────────────────
  //
  // Ces sept jetons sont le **maillon du milieu** de la chaîne
  // `paramètre > jeton > référence` de `zDailyTasksChromeOf`
  // (`zcrud_study/…/z_daily_tasks_reference.dart`), qui n'en avait jusqu'ici
  // QUE deux. Sans eux, un hôte ne pouvait régler la vue des tâches du jour
  // qu'en repassant chaque paramètre à CHAQUE montage — donc jamais depuis
  // son thème.
  //
  // **Aucun jeton GÉNÉRIQUE n'est monté en maillon** : ni `gapM` pour un
  // écart, ni `radiusM` pour le rayon de cellule — un jeton générique
  // portant plusieurs valeurs de référence ne peut en satisfaire aucune.
  // Chaque jeton ci-dessous vise UNE propriété, d'UN écran.
  //
  // `null` (défaut) ⇒ le consommateur applique sa valeur de RÉFÉRENCE
  // (`ZDailyTasksReference`) : le rendu d'aujourd'hui est strictement inchangé
  // tant qu'aucun n'est posé.

  /// Padding du bandeau de semaine. `null` ⇒ référence
  /// (`EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4)` — AD-13).
  final EdgeInsetsGeometry? dailyTasksBandPadding;

  /// Marge EXTERNE d'une cellule de jour. `null` ⇒ référence
  /// (`EdgeInsetsDirectional.symmetric(horizontal: 2)`).
  final EdgeInsetsGeometry? dailyTasksDayCellMargin;

  /// Padding INTERNE d'une cellule de jour. `null` ⇒ référence
  /// (`EdgeInsetsDirectional.symmetric(vertical: 8)`).
  ///
  /// Distinct de [dailyTasksDayCellMargin] : la marge écarte les cellules
  /// entre elles, le padding gonfle la cible tapable. Les confondre en un seul
  /// jeton rendrait l'un des deux réglages inatteignable.
  final EdgeInsetsGeometry? dailyTasksDayCellPadding;

  /// Rayon des coins d'une cellule de jour. `null` ⇒ référence
  /// (`Radius.circular(12)`).
  final Radius? dailyTasksDayCellRadius;

  /// Cible tap minimale (dp) d'une cellule de jour. `null` ⇒ référence
  /// (48, plancher Material/AD-13).
  ///
  /// **PLANCHER** : interpolable comme une longueur (deux planchers valides
  /// encadrent une valeur valide), mais `null` ne se matérialise JAMAIS en `0`
  /// — un plancher nul est l'ABSENCE de plancher, et une transition de thème
  /// n'a pas à ouvrir une fenêtre pendant laquelle les sept cibles du bandeau
  /// descendent sous 48 dp. Même traitement que [studySessionMinTarget].
  final double? dailyTasksMinTapTarget;

  /// Largeur (dp) en deçà de laquelle le libellé de mois n'est **pas** rendu.
  /// `null` ⇒ référence (600).
  ///
  /// **SEUIL, donc DISCRET** : un point de rupture interpolé est un point de
  /// rupture qu'aucun des deux thèmes ne décrit — la mise en page basculerait
  /// au milieu de l'animation, à une largeur que personne n'a choisie. Il
  /// BASCULE donc à mi-course, comme [folderCardFooterBesideMinWidth].
  final double? dailyTasksMonthBreakpoint;

  /// Padding d'une ligne de tâche de la liste. `null` ⇒ référence
  /// (`EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6)`).
  final EdgeInsetsGeometry? dailyTasksItemPadding;

  // ── Hub d'ajout de CONTENU ─────────────────────────────────────────────────
  // Aucun jeton `contentHub*` n'existait : la forme du hub n'était atteignable
  // NI par paramètre NI par thème. La seule voie
  // ouverte à un hôte était d'envelopper la feuille dans un `Theme` écrasant
  // `ListTileTheme` pour TOUT le sous-arbre — donc de changer l'ambiance d'un
  // écran pour atteindre une carte.
  //
  // Chacun est `null` par DÉFAUT, et `null` signifie « le consommateur
  // applique sa valeur de RÉFÉRENCE » (`ZContentHubReference`) — jamais « rien
  // ne se rend ». Priorité, partout : paramètre de feuille/entrée > ce jeton >
  // défaut-référence.

  /// Densité du hub. `null` ⇒ référence ([ZContentHubDensity.comfortable] —
  /// le rendu en cartes, défaut).
  ///
  /// C'est le jeton qui **restitue la densité compacte antérieure**
  /// ([ZContentHubDensity.compact]) sans toucher au code de l'hôte : la densité
  /// n'a pas disparu, elle a cessé d'être le défaut.
  final ZContentHubDensity? contentHubDensity;

  /// Hauteur d'item de référence du hub. `null` ⇒ référence (**112** =
  /// `kToolbarHeight × 2`). En densité compacte, le plancher de 48 dp gouverne.
  final double? contentHubItemExtent;

  /// Rayon d'une carte d'entrée. `null` ⇒ référence (16).
  final Radius? contentHubItemRadius;

  /// Padding interne d'une carte d'entrée. `null` ⇒ référence (8,
  /// directionnel).
  final EdgeInsetsGeometry? contentHubItemPadding;

  /// Opacité de la teinte de FOND d'une carte d'entrée. `null` ⇒ référence
  /// (**0** — carte NEUTRE : mesuré sur pièces, le rendu historique ne teinte
  /// PAS le fond de la carte, seulement la pastille et le badge).
  final double? contentHubItemTintAlpha;

  /// Diamètre de la pastille circulaire d'identité. `null` ⇒ référence (40).
  final double? contentHubAvatarSize;

  /// Opacité du fond de la pastille. `null` ⇒ référence (0.1).
  final double? contentHubAvatarTintAlpha;

  /// Taille du glyphe dans la pastille. `null` ⇒ référence (24).
  final double? contentHubGlyphSize;

  /// Palette des teintes d'IDENTITÉ des entrées — le jeton qui remplace les six
  /// teintes littérales de `ZContentHubReference`. `null` ⇒ référence.
  ///
  /// Une entrée sans teinte explicite reçoit un créneau **déterministe de son
  /// identité** (`colorKey`, à défaut son libellé) — donc STABLE quand une
  /// application insère un type au milieu (jamais un index d'affichage). Une
  /// liste VIDE ⇒ aucune teinte d'identité (chaîne totale, AD-10 : jamais un
  /// échec de rendu).
  final List<Color>? contentHubAccents;

  /// Teinte du badge de mise en avant. `null` ⇒ référence (le vert historique).
  final Color? contentHubBadgeColor;

  /// Largeur à partir de laquelle le hub passe en grille. `null` ⇒ référence
  /// (**600** — mesuré sur le rendu historique).
  final double? contentHubGridBreakpoint;

  /// Nombre de colonnes au-delà de [contentHubGridBreakpoint]. `null` ⇒
  /// référence (2). `1` ⇒ colonne unique à toute largeur.
  final int? contentHubGridCrossAxisCount;

  /// Plancher de contraste (WCAG 2.x) imposé aux teintes d'identité peintes —
  /// pastille, glyphe. `null` ⇒ référence (**3.0:1**, §1.4.11).
  ///
  /// Le rendu historique n'en a **aucun** : il peint la teinte brute et n'a
  /// **aucune** branche de luminosité (recherche négative sur son fichier).
  /// Une teinte d'entrée pouvant être injectée par l'hôte, elle est arbitraire.
  final double? contentHubMinContrast;

  /// Style des intitulés de SECTION du hub. `null` ⇒ `titleMedium` du thème,
  /// à la graisse de référence (`w600`) — jamais une taille en dur.
  final TextStyle? contentHubSectionTitleStyle;

  // ── Typographie de l'EN-TÊTE DE PAGE ───────────────────────────────────────
  // L'en-tête de page était le seul endroit de l'écran dont la hiérarchie
  // typographique n'était atteignable NI par paramètre NI par thème : le titre
  // retombait sur `AppBarTheme.titleTextStyle` et les onglets sur le défaut M3,
  // sans qu'aucun jeton ne les vise. Un hôte n'avait qu'un recours — envelopper
  // la page dans un `Theme` réécrivant `AppBarTheme`/`TabBarTheme`, donc
  // changer l'ambiance de tout un sous-arbre pour atteindre deux textes.
  //
  // **Ces quatre jetons ne portent que des MÉTRIQUES.** Le consommateur
  // (`zcrud_ui_kit`) en retient taille, graisse, style, famille, interlettrage,
  // interlignage — et **ignore délibérément la couleur**, pour deux raisons
  // MESURÉES :
  // * pour le TITRE et le SOUS-TITRE, la couleur doit rester héritée du
  //   `foregroundColor` de l'app-bar, sans quoi un en-tête sous dégradé
  //   d'identité (`ZGradientSpec.onGradient`) redeviendrait illisible — c'est
  //   l'invariant que `_zSubtitleSlice` documente déjà côté `zcrud_ui_kit` ;
  // * pour les ONGLETS, `TabBar` dérive sa couleur de sélection de
  //   `labelStyle?.color` quand aucun `labelColor` n'est donné : un style
  //   coloré **écrase la distinction sélectionné/non-sélectionné** (mesuré :
  //   les deux onglets rendus dans la MÊME couleur). La couleur serait donc
  //   payée par la perte d'un canal d'accessibilité.
  //
  // `null` (défaut) ⇒ le consommateur ne pose **rien** : aucune enveloppe de
  // style n'entre dans l'arbre, le rendu est strictement celui d'avant.

  /// Style du TITRE de l'en-tête de page, consommé par
  /// `ZPageScaffold`/`ZSearchableAppBar`/`ZPageShellBody` de `zcrud_ui_kit`.
  ///
  /// `null` ⇒ le titre garde le style de l'app-bar de l'hôte
  /// (`AppBarTheme.titleTextStyle`, repli `TextTheme.titleLarge`) — rendu
  /// **strictement inchangé**. Non-null ⇒ ses **métriques** sont fusionnées
  /// par-dessus (la couleur est ignorée, cf. l'encadré ci-dessus).
  ///
  /// Le paramètre `titleTextStyle` du widget **prime** sur ce jeton.
  final TextStyle? pageHeaderTitleStyle;

  /// Style du SOUS-TITRE de l'en-tête de page.
  ///
  /// `null` ⇒ repli historique du consommateur (métriques de
  /// `TextTheme.titleSmall`) — rendu **strictement inchangé**. Sans objet quand
  /// aucun sous-titre n'est fourni (le slot reste absent de l'arbre).
  final TextStyle? pageHeaderSubtitleStyle;

  /// Style du libellé d'onglet **SÉLECTIONNÉ** de l'en-tête de page —
  /// le troisième canal de distinction, à côté de la couleur
  /// et de l'indicateur.
  ///
  /// `null` ⇒ défaut Material 3 (`TextTheme.titleSmall`) — rendu **strictement
  /// inchangé**.
  ///
  /// Régler CE jeton seul ne touche QUE l'onglet sélectionné : le
  /// consommateur neutralise explicitement la retombée de `TabBar`
  /// (`unselectedLabelStyle ?? labelStyle`) qui, sans cela, appliquerait le
  /// style sélectionné aux onglets non sélectionnés — donc annulerait la
  /// distinction qu'on vient de demander.
  final TextStyle? pageHeaderTabSelectedLabelStyle;

  /// Style du libellé d'onglet **NON SÉLECTIONNÉ** de l'en-tête de page.
  /// `null` ⇒ défaut Material 3 — rendu **strictement
  /// inchangé**.
  final TextStyle? pageHeaderTabUnselectedLabelStyle;

  // ── Rendu du CHAT — surface « notebook » ──────────────────────────────────
  //
  // Ces jetons sont le NIVEAU 2 de la chaîne `paramètre > jeton >
  // référence` de `ZChatNotebookSkin` (`zcrud_chat`). `null` des deux côtés
  // reste `null` à travers `lerp` : la valeur de RÉFÉRENCE du consommateur
  // n'est jamais matérialisée par une transition de thème (même invariant que
  // `studyCardBadgeRadius`).
  //
  // Les trois jetons de COULEUR sont la contrepartie de l'exception encadrée
  // de l'invariant FR-26 accordée à `ZChatNotebookReference` : sans eux, la
  // condition « remplaçable par jeton » ne serait pas tenue. Ils ne portent,
  // eux, aucune valeur littérale.

  /// Fraction de largeur d'une bulle de message.
  /// `null` ⇒ référence (`0.95` en notebook).
  final double? chatBubbleWidthFactor;

  /// Rayon de la bulle de **requête**. `null` ⇒ référence (12).
  final Radius? chatRequestBubbleRadius;

  /// Rayon de la bulle de **réponse**. `null` ⇒ référence, qui vaut elle-même
  /// `null` : le rendu historique ne pose aucun `shape` sur la réponse.
  final Radius? chatResponseBubbleRadius;

  /// Avatar d'auteur affiché dans une bulle ? `null` ⇒ référence (`false`).
  final bool? chatBubbleShowAuthorAvatar;

  /// Nom d'auteur affiché dans une bulle ? `null` ⇒ référence (`false`).
  final bool? chatBubbleShowAuthorName;

  /// Horodatage affiché dans une bulle ? `null` ⇒ référence (`true`).
  final bool? chatBubbleShowTimestamp;

  /// Teinte d'identité des affordances d'outils du chat. `null` ⇒ référence.
  final Color? chatToolAccentColor;

  /// Accents **par capacité** du notebook (`mindmap`, `flashcards`, …).
  ///
  /// Ce jeton ne remplace que le canal **chromatique** : les canaux textuel
  /// et de forme de `ZChatNotebookCapabilityStyle` ne sont pas thémables, sans
  /// quoi un thème pourrait rétablir le défaut « information portée par la
  /// seule couleur ».
  final Map<String, Color>? chatCapabilityAccents;

  /// Séquence de teintes de l'indicateur d'occupation. `null` ⇒ référence.
  final List<Color>? chatBusyPalette;

  // ── Chrome du COMPOSER de chat ─────────────────────────────────────────────
  //
  // Niveau 2 de la chaîne `paramètre > jeton > référence` de
  // `zChatComposerChromeOf` (`zcrud_chat`) — le régime exact des jetons
  // notebook ci-dessus : `null` des deux côtés reste `null` à travers `lerp`,
  // la référence du consommateur n'est jamais matérialisée par une
  // transition de thème.

  /// Côté de la cible d'ENVOI du composer. `null` ⇒ référence (48).
  ///
  /// Le consommateur l'ÉCRÊTE à son plancher AD-13 (48 dp) : un jeton qui
  /// demanderait 40 dp rend quand même 48. Et son `lerp` est un
  /// lerp de PLANCHER ([_lerpNullableFloor]) : une transition de thème ne
  /// matérialise jamais `0` — une cible de 0 dp le temps d'une animation est
  /// une régression d'accessibilité, pas une dimension qui « grandit ».
  final double? chatComposerSendTargetSize;

  /// Échelle du glyphe d'envoi, saisie VIDE. `null` ⇒ référence (0.7).
  ///
  /// `lerp` par [_lerpNullableFloor] — même raison que les durées : pour une
  /// ÉCHELLE, `0` n'est pas une absence, c'est un glyphe invisible. Traiter un
  /// côté `null` comme `0` ferait disparaître le bouton d'envoi le temps de la
  /// transition.
  final double? chatComposerSendScaleIdle;

  /// Échelle du glyphe d'envoi, saisie NON vide. `null` ⇒ référence (1).
  ///
  /// Même règle de `lerp` que [chatComposerSendScaleIdle].
  final double? chatComposerSendScaleActive;

  /// Durée de la transition d'échelle de l'envoi. `null` ⇒ référence (150 ms).
  /// `lerp` par [_lerpNullableDuration] — jamais `Duration.zero` matérialisé.
  final Duration? chatComposerSendScaleDuration;

  /// Largeur sous laquelle le composer passe en mode « icône seule ».
  /// `null` ⇒ référence (400).
  ///
  /// SEUIL, donc `lerp` **DISCRET** à `t = 0.5` — le précédent exact de
  /// [dailyTasksMonthBreakpoint] : un breakpoint interpolé
  /// continûment ferait BASCULER la mise en page plusieurs fois pendant une
  /// transition de thème, au gré des largeurs intermédiaires. Un seuil n'a pas
  /// d'états intermédiaires légitimes.
  final double? chatComposerMobileBreakpoint;

  /// Période de rotation du placeholder animé. `null` ⇒ référence (4 s).
  /// `lerp` par [_lerpNullableDuration].
  final Duration? chatComposerHintRotationPeriod;

  /// Durée du fondu de changement de texte du placeholder.
  /// `null` ⇒ référence (350 ms). `lerp` par [_lerpNullableDuration].
  final Duration? chatComposerHintSwitchDuration;

  /// Teinte d'**état ACTIF** des bascules d'outils du composer (« réfléchir »,
  /// « internet », dictée…). `null` ⇒ **aucune teinte** : le socle n'invente
  /// pas de couleur, l'état reste porté par ses canaux non chromatiques.
  ///
  /// Ce jeton ne remplace que le canal **chromatique** : les canaux textuel
  /// (libellé emphasé) et sémantique (`Semantics(toggled:)`) ne sont pas
  /// thémables, sans quoi un thème pourrait rétablir le défaut
  /// « information portée par la seule couleur » (AD-13). Même régime que
  /// [chatCapabilityAccents] côté notebook.
  ///
  /// La teinte déclarée est portée au **plancher de contraste** par le
  /// consommateur : un jeton illisible sur la surface du composer est
  /// corrigé, jamais peint tel quel.
  final Color? chatComposerActiveAccent;

  /// Accents des paliers de verbosité du chat, indexés par le **nom** du
  /// palier kernel (`'concise'`, `'standard'`, `'detailed'` —
  /// `ZChatResponseLength.name`, AD-1 : ce package ne peut pas importer
  /// l'enum). `null`/clé absente ⇒ référence.
  ///
  /// Contrepartie de l'exception encadrée de l'invariant FR-26 pour les
  /// couleurs d'effort de `ZChatComposerReference` : c'est ce jeton qui tient
  /// la condition « remplaçable par thème ». TABLE, donc `lerp` **discret** à
  /// `t = 0.5` — même règle que [chatCapabilityAccents] (pas de demi-palette).
  final Map<String, Color>? chatResponseLengthAccents;

  /// Graisse de l'option **choisie** des feuilles de réglages du chat
  /// (canal visible n°1). `null` ⇒ référence (`w700`).
  ///
  /// `lerp` par [_lerpNullableFontWeight] : `FontWeight.lerp` avec un côté
  /// `null` substituerait `w400` — la transition matérialiserait une graisse
  /// NORMALE par-dessus la référence d'emphase du consommateur, c'est-à-dire
  /// ferait disparaître la sélection visible le temps de l'animation.
  final FontWeight? chatSelectedEmphasisWeight;

  /// Décoration de l'option **choisie** (canal visible n°2).
  /// `null` ⇒ référence (souligné).
  ///
  /// Une `TextDecoration` n'a pas d'états intermédiaires (pas de
  /// demi-soulignement) : `lerp` **discret** à `t = 0.5`, comme les booléens.
  final TextDecoration? chatSelectedEmphasisDecoration;

  // ── Feuille d'édition ──────────────────────────────────────────────────────
  //
  // Maillon **jeton** de la chaîne `paramètre > jeton > référence` de la
  // bottom-sheet d'édition (`ZSheetFrameSpec` / `ZSheetFrameReference`,
  // `zcrud_navigation`). Les cinq jetons sont **absents de
  // [ZcrudTheme.fallback]** : un hôte passif ne bouge donc pas d'un pixel, et
  // `null` y signifie toujours « le consommateur applique SA référence ».

  /// **Quand** encadrer la bottom-sheet d'édition, pour toute l'app.
  ///
  /// Valeurs reconnues : `'always'` (référence), `'never'`, `'unlessChrome'`.
  /// `null` **ou valeur inconnue** ⇒ le consommateur applique sa référence
  /// (AD-10 : **jamais** d'exception — un thème écrit à la main, ou sérialisé
  /// depuis une version plus récente du socle, ne doit pas faire planter le
  /// rendu).
  ///
  /// **`String` et NON l'énumération.** `ZSheetFrameMode` vit dans
  /// `zcrud_navigation` et **AD-1 interdit à `zcrud_core` de l'importer** (le
  /// cœur ne dépend d'aucun satellite). C'est le patron déjà établi par
  /// [chatCapabilityAccents] / [chatResponseLengthAccents], indexés par le
  /// **nom** du palier kernel pour exactement la même raison. Côté
  /// `zcrud_navigation`, la traduction est
  /// `ZSheetFrameMode.values.firstWhereOrNull((m) => m.name == jeton)`.
  ///
  /// `lerp` **DISCRET** à `t = 0.5` (patron [subfolderTriggerVariant],
  /// [dailyTasksMonthBreakpoint]) : il n'existe pas de demi-cadre. Interpoler
  /// ferait clignoter la bordure pendant une transition de thème.
  final String? editionSheetFrameMode;

  /// Fraction de la largeur d'écran allouée à la feuille d'édition.
  /// `null` ⇒ référence (`0,9` — la valeur mesurée sur la référence).
  ///
  /// `lerp` par [_lerpNullableFloor] et **non** [_lerpNullableDouble] : pour
  /// cette DIMENSION, un côté `null` signifie « la référence », jamais « zéro ».
  /// `_lerpNullableDouble(null, 0.9, 0)` rendrait `0`, c'est-à-dire une feuille
  /// de **largeur nulle** le temps de l'animation (même raison que [fieldGap]).
  final double? editionSheetWidthRatio;

  /// Plafond **absolu** de largeur (dp) de la feuille d'édition.
  /// `null` ⇒ référence (`640` — le défaut de Flutter lui-même,
  /// `_BottomSheetDefaultsM3.constraints`).
  ///
  /// `lerp` par [_lerpNullableFloor], même raison de plancher que
  /// [editionSheetWidthRatio] : un plafond de `0` n'est pas une absence, c'est
  /// une feuille invisible.
  final double? editionSheetMaxWidth;

  /// Teinte du cadre de la feuille d'édition.
  /// `null` ⇒ **rôle** `ColorScheme.outlineVariant` côté consommateur (celui de
  /// `Card.outlined`, donc le « gris » exact de la référence, en clair **comme**
  /// en sombre) — jamais un littéral (invariant FR-26).
  ///
  /// `lerp` par [_lerpNullableColor] et **non** `Color.lerp` :
  /// `Color.lerp(null, c, t)` matérialise `c` dès `t > 0` et peindrait un cadre
  /// **par-dessus** le rôle de repli du consommateur pendant la transition
  /// (précédent exact : [fieldFillColor], [fieldFocusedBorderColor]).
  final Color? editionSheetBorderColor;

  /// Épaisseur du cadre de la feuille d'édition (dp). `null` ⇒ référence (`1`).
  /// `lerp` par [_lerpNullableFloor] — une épaisseur `0` est un cadre **absent**,
  /// pas une absence de réglage.
  final double? editionSheetBorderWidth;

  // ── Chrome d'édition ────────────────────────────────────────────────────
  //
  // Maillon **jeton** de `zEditionChromeMetricsOf` (`zcrud_navigation`), dont
  // la référence auditée est `ZEditionChromeReference`. Mêmes règles : nullable,
  // **absents de [ZcrudTheme.fallback]**, `lerp` motivé.
  //
  // Ne sont PAS tokenisés, délibérément :
  // * l'**écart entre deux actions** — il lit déjà [gapM], jeton générique
  //   existant. Un `editionChromeGap` serait un SECOND canal pour la même
  //   propriété, c'est-à-dire la « vue parallèle » que ce dépôt s'interdit ;
  // * le **dégagement interne d'une action** (`actionPadding`) — micro-détail
  //   d'un seul widget, pas une décision de design prise à l'échelle d'une app ;
  //   il reste surchargeable par paramètre (`ZEditionChromeMetrics`) ;
  // * les **dimensions de la poignée M3** et les **opacités d'état désactivé** —
  //   ce sont des constantes M3, pas des réglages ; elles ne figurent même pas
  //   dans le porte-valeurs résolu `ZEditionChromeMetrics`.

  /// Cible tactile minimale (dp) du chrome d'édition — AD-13.
  /// `null` ⇒ référence (`48`).
  ///
  /// `lerp` par [_lerpNullableFloor], **jamais** [_lerpNullableDouble] :
  /// exactement la leçon de [studySessionMinTarget]. Pour une CONTRAINTE de
  /// plancher, `0` n'est pas une absence — c'est « aucun plancher », donc une
  /// fenêtre (courte mais réelle) pendant laquelle les cibles du chrome
  /// n'ont plus de minimum accessible au milieu d'une transition de thème.
  final double? editionChromeMinTouchTarget;

  /// Gouttière de l'en-tête du chrome d'édition.
  /// `null` ⇒ référence (`EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8)`).
  ///
  /// `lerp` par [_lerpNullablePadding] : marge CONTINUE et **directionnelle**
  /// (AD-13 — l'interpolation préserve la nature `EdgeInsetsDirectional`, donc
  /// le RTL) ; `null` des deux côtés reste `null`, la référence du consommateur
  /// n'est jamais matérialisée.
  final EdgeInsetsDirectional? editionChromeHeaderPadding;

  /// Gouttière de la barre d'actions en pied du chrome (`dialog` / `sheet`).
  /// `null` ⇒ référence (`EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8)`).
  /// `lerp` par [_lerpNullablePadding] — même raison que
  /// [editionChromeHeaderPadding].
  final EdgeInsetsDirectional? editionChromeActionBarPadding;

  /// Hauteur **étendue** de l'en-tête repliable du mode `page` (dp).
  /// `null` ⇒ référence (`112`).
  ///
  /// `lerp` par [_lerpNullableFloor] : une hauteur d'en-tête `0` n'est pas une
  /// absence de réglage, c'est un en-tête **replié** — un rendu qu'aucun des
  /// deux thèmes ne décrit et que personne n'a choisi.
  final double? editionChromePageHeaderExpandedHeight;

  // ── Déclencheur de sélection ───────────────────────────────────────────────
  //
  // Maillon **jeton** de la chaîne `paramètre (ZSelectTileSpec) > jeton >
  // référence (ZSelectTileReference)` réalisée par `zcrud_select`. Mêmes règles
  // que les familles `editionSheet*`/`editionChrome*` : nullables, **absents de
  // [ZcrudTheme.fallback]**, `lerp` motivé par famille.
  //
  // **CRITÈRE appliqué** : un jeton se justifie s'il porte une décision à
  // l'échelle de l'APPLICATION. Une métrique qu'aucun hôte ne réglera
  // globalement reste atteignable **par paramètre** (`ZSelectTileSpec`) et n'a
  // pas besoin d'un jeton — c'est le précédent `editionChromeGap` /
  // `actionPadding`. Sur les quinze candidats relevés à l'audit de fidélité,
  // **huit** sont retenus ci-dessous et **sept** sont écartés :
  //
  // * `selectTileElevation` — le déclencheur est PLAT par conception (son relief
  //   vient de la bordure). « Mes cartes sont surélevées » est une décision
  //   d'app, mais elle a déjà son canal : `CardThemeData.elevation`. Un jeton
  //   qui ne concernerait QUE les déclencheurs de sélection ne décrit aucune
  //   décision qu'un designer prend ⇒ paramètre.
  // * `selectChipBackgroundColor` / `selectChipForegroundColor` — le thème des
  //   puces est déjà une décision d'app **portée par le SDK**
  //   (`ThemeData.chipTheme`). Deux jetons ici seraient un SECOND CANAL pour la
  //   même propriété — exactement ce que ce dépôt s'interdit.
  // * `selectChipFontSize` — la typographie a son canal (`TextTheme`). Idem.
  // * `selectChipSpacing` / `selectChipRunSpacing` — micro-métriques du `Wrap`
  //   d'un seul widget ; les écarts génériques ont [gapS]/[gapM]. Idem
  //   `editionChromeGap`.
  // * `selectPlaceholderColor` — l'état vide a déjà son canal app-scale,
  //   `ThemeData.hintColor`, que le cœur emploie lui-même pour les placeholders
  //   de sélection natifs. Idem.
  //
  // Les sept écartés restent **intégralement atteignables** par
  // `ZSelectTileSpec` : rien n'est perdu, seule la surface publique perpétuelle
  // l'est.

  /// Teinte de la bordure du déclencheur de sélection, pour toute l'app.
  /// `null` ⇒ le consommateur applique **son rôle** (`ColorScheme.outlineVariant`,
  /// celui de `Card.outlined`) — jamais un littéral (invariant FR-26).
  ///
  /// `lerp` par [_lerpNullableColor] et **non** `Color.lerp` :
  /// `Color.lerp(null, c, t)` matérialise `c` dès `t > 0` et peindrait une
  /// bordure **par-dessus** le rôle de repli du consommateur pendant la
  /// transition de thème (précédent exact : [editionSheetBorderColor]).
  ///
  /// Ce jeton existe parce que la référence de l'hôte **prime sur**
  /// `CardThemeData` : le présentateur pose un `shape:` explicite pour tenir sa
  /// fidélité, donc `cardTheme.shape` ne peut PAS servir de canal. Le jeton est
  /// le seul chemin app-scale restant.
  final Color? selectTileBorderColor;

  /// Épaisseur (dp) de la bordure du déclencheur de sélection.
  /// `null` ⇒ référence (`1` — le défaut de `BorderSide`, écrit par la référence).
  ///
  /// `lerp` par [_lerpNullableFloor] — une épaisseur `0` est une bordure
  /// **absente**, pas une absence de réglage (identique à
  /// [editionSheetBorderWidth]).
  final double? selectTileBorderWidth;

  /// Rayon (dp) des coins du déclencheur de sélection. `null` ⇒ référence (`12`).
  ///
  /// Décision app-scale (la « rondeur » est un choix de marque), inatteignable
  /// via `CardThemeData.shape` pour la raison dite en [selectTileBorderColor].
  ///
  /// `lerp` par [_lerpNullableFloor] : un rayon `0` est un coin **carré**, un
  /// rendu qu'aucun des deux thèmes ne décrit.
  final double? selectTileRadius;

  /// Plancher (dp) de hauteur du déclencheur de sélection — AD-13.
  /// `null` ⇒ référence (`48`).
  ///
  /// `lerp` par [_lerpNullableFloor], **jamais** `_lerpNullableDouble` :
  /// exactement la leçon de [editionChromeMinTouchTarget]. Pour une CONTRAINTE
  /// de plancher, `0` n'est pas une absence — c'est « aucun plancher », donc une
  /// fenêtre pendant laquelle la cible n'a plus de minimum accessible.
  ///
  /// Le consommateur ne descend **jamais** sous 48 dp quelle que soit la
  /// valeur posée ici : ce jeton ne peut que **rehausser** (AD-13).
  final double? selectTileMinHeight;

  /// Largeur utile (dp) au-delà de laquelle un modal de sélection s'ouvre en
  /// boîte de dialogue plutôt qu'en feuille. `null` ⇒ référence (`600`, le
  /// palier `medium` de Material 3).
  ///
  /// Décision **responsive** à l'échelle de l'app (même famille que
  /// `dailyTasksMonthBreakpoint`, `chatComposerMobileBreakpoint`).
  ///
  /// `lerp` par [_lerpNullableFloor] : un seuil `0` ferait basculer TOUTE la
  /// sélection en dialogue le temps de la transition.
  final double? selectDialogBreakpoint;

  /// Forme des options d'une sélection **mono**, pour toute l'app.
  ///
  /// Valeurs reconnues : `'radios'` (référence), `'checkboxes'`, `'switches'`,
  /// `'chips'`. `null` **ou valeur inconnue** ⇒ le consommateur applique sa
  /// référence (AD-10 : **jamais** d'exception — un thème écrit à la main, ou
  /// sérialisé depuis une version plus récente du socle, ne doit pas faire
  /// planter le rendu).
  ///
  /// **`String` et NON l'énumération.** `ZSelectChoiceStyle` vit dans
  /// `zcrud_select` et AD-1 interdit à `zcrud_core` de l'importer. C'est le
  /// patron déjà établi par [editionSheetFrameMode], indexé par le **nom** du
  /// palier pour exactement la même raison.
  ///
  /// `lerp` **DISCRET** à `t = 0.5` : il n'existe pas de demi-radio. Interpoler
  /// ferait clignoter la forme des options pendant une transition de thème.
  final String? selectMonoChoiceStyle;

  /// Forme des options d'une sélection **multi**, pour toute l'app.
  /// Valeurs reconnues et règles identiques à [selectMonoChoiceStyle] ;
  /// référence : `'switches'` (le défaut **mesuré**).
  final String? selectMultiChoiceStyle;

  /// Forme du **conteneur** de modal de sélection, pour toute l'app.
  ///
  /// Valeurs reconnues : `'bottomSheet'`, `'popupDialog'`, `'fullPage'`,
  /// `'adaptive'` (référence). `null` ou valeur inconnue ⇒ référence (AD-10).
  ///
  /// Même motivation `String` + `lerp` discret que [selectMonoChoiceStyle].
  final String? selectModalShape;

  // ── Famille `stepper*` (rail numéroté « tout affiché ») ────────────────────
  // Ces cinq jetons sont NULLABLES et **absents de [ZcrudTheme.fallback]** :
  // l'absence de réglage doit rester distinguable d'un réglage neutre, sinon le
  // consommateur ne peut plus appliquer son rôle de repli (invariant FR-26).
  // `lerp` motivé par jeton.

  /// Teinte du **rail** vertical reliant les badges d'étape (mode « tout
  /// affiché »). `null` ⇒ le consommateur applique **son rôle**
  /// (`ColorScheme.outlineVariant`) — jamais un littéral.
  ///
  /// `lerp` par [_lerpNullableColor] et **non** `Color.lerp` :
  /// `Color.lerp(null, c, t)` matérialise `c` dès `t > 0` et peindrait un rail
  /// **par-dessus** le rôle de repli du consommateur pendant la transition de
  /// thème (précédent exact : [selectTileBorderColor]).
  final Color? stepperRailColor;

  /// Épaisseur (dp) du rail vertical. `null` ⇒ référence (`1`, la mesure du
  /// rendu historique `_buildVerticalExpandedSteps`).
  ///
  /// `lerp` par [_lerpNullableFloor] — une épaisseur `0` est un rail **absent**,
  /// pas une absence de réglage (identique à [selectTileBorderWidth]).
  final double? stepperRailThickness;

  /// Teinte du **numéro** peint dans le badge circulaire d'étape. `null` ⇒ le
  /// consommateur DÉRIVE le contraste de la couleur du badge
  /// (`ThemeData.estimateBrightnessForColor` → `ColorScheme.surface` /
  /// `onSurface`) — le rendu historique écrit un **blanc littéral** en dur, ce
  /// que l'invariant FR-26 interdit et qui casse dès que l'hôte personnalise
  /// `activeColor` en clair.
  ///
  /// `lerp` par [_lerpNullableColor] : même raison que [stepperRailColor] —
  /// matérialiser une teinte pendant la transition écraserait le contraste
  /// dérivé et rendrait le numéro illisible sur une fraction de l'animation.
  final Color? stepperBadgeForegroundColor;

  /// Écart vertical (dp) entre deux étapes dépliées du mode « tout affiché ».
  /// `null` ⇒ référence (`24`, la mesure historique).
  ///
  /// `lerp` par [_lerpNullableFloor] : un écart `0` est un empilement collé —
  /// un rendu qu'aucun des deux thèmes ne décrit.
  final double? stepperAllStepsGap;

  /// Largeur maximale (dp) de la **bande latérale** d'indicateur quand
  /// `indicatorPosition: start`. `null` ⇒ référence (`220`).
  ///
  /// Ce jeton n'est pas cosmétique : c'est lui qui **BORNE** la bande. Sans
  /// borne, la `Row` de composition donne au `_StepIndicator` une largeur
  /// **non bornée** et le `Expanded` du rendu compact lève
  /// `RenderFlex children have non-zero flex but incoming width constraints are
  /// unbounded`.
  ///
  /// `lerp` par [_lerpNullableFloor] : une largeur `0` escamoterait la bande —
  /// pas une absence de réglage.
  final double? stepperSideBandMaxWidth;

  // ── Famille `booleanPill*` (pilule « Oui/Non ») ─────────────────────────────
  // Ces neuf jetons sont NULLABLES et **absents de [ZcrudTheme.fallback]** :
  // l'absence de réglage doit rester distinguable d'un réglage neutre, sinon le
  // consommateur ne peut plus appliquer son rôle / sa référence (invariant
  // FR-26). Ils ne sont lus QUE par `ZBooleanStyle.pill` : un hôte qui reste
  // sur le style `switchTile` (défaut) ne les traverse jamais.

  /// Teinte de la piste à l'état `true`. `null` ⇒ `ColorScheme.primary`.
  ///
  /// Le rendu historique peint un **vert** (`kSuccessColorLight`, `#2E7D32`) :
  /// Material 3 n'a **pas** de rôle « succès », et l'inventer exigerait un
  /// littéral (interdit par l'invariant FR-26). La voie exacte pour ce vert est
  /// donc la clé sémantique `ZBooleanConfig.activeColorKey` résolue par
  /// `ZcrudScope.colorKeyResolver` — ce jeton n'en est que le repli d'échelle
  /// thème.
  ///
  /// `lerp` par [_lerpNullableColor] et **non** `Color.lerp` :
  /// `Color.lerp(null, c, t)` matérialise `c` dès `t > 0` et peindrait la piste
  /// **par-dessus** le rôle de repli du consommateur pendant la transition
  /// (précédent exact : [stepperRailColor]).
  final Color? booleanPillActiveColor;

  /// Teinte de la piste à l'état `false`. `null` ⇒ `ColorScheme.outline` (le
  /// rendu historique pose un gris `grey.shade400`). `lerp` par
  /// [_lerpNullableColor], même raison que [booleanPillActiveColor].
  final Color? booleanPillInactiveColor;

  /// Teinte du **texte interne et du pouce** à l'état `true`. `null` ⇒ contraste
  /// **DÉRIVÉ** de la piste (`ThemeData.estimateBrightnessForColor` →
  /// `ColorScheme.surface` / `onSurface`), ou `onColor` de la paire quand la
  /// couleur vient d'une clé sémantique.
  ///
  /// Le rendu historique écrit un **blanc littéral** : illisible dès qu'un hôte
  /// choisit une piste claire. Dériver est le précédent
  /// [stepperBadgeForegroundColor], posé pour exactement ce défaut. `lerp` par
  /// [_lerpNullableColor] : matérialiser une teinte pendant la transition
  /// écraserait le contraste dérivé et rendrait le texte illisible sur une
  /// fraction de l'animation.
  final Color? booleanPillActiveForegroundColor;

  /// Idem à l'état `false`. `null` ⇒ même dérivation de contraste.
  final Color? booleanPillInactiveForegroundColor;

  /// Largeur (dp) de la piste. `null` ⇒ référence (`65`, mesure historique).
  ///
  /// `lerp` par [_lerpNullableFloor] : une largeur `0` escamoterait la pilule —
  /// pas une absence de réglage.
  final double? booleanPillWidth;

  /// Hauteur (dp) de la piste. `null` ⇒ référence (`30`). `lerp` par
  /// [_lerpNullableFloor], même raison que [booleanPillWidth].
  ///
  /// Ce n'est **pas** la cible tactile : la pilule est centrée dans une
  /// contrainte plancher de 48 dp (AD-13), que ce jeton ne peut pas abaisser.
  final double? booleanPillHeight;

  /// Diamètre (dp) du pouce. `null` ⇒ référence (`20`). `lerp` par
  /// [_lerpNullableFloor] : un pouce `0` est un pouce **absent**.
  final double? booleanPillThumbSize;

  /// Rayon des coins de la piste. `null` ⇒ référence (`20`, rendu historique).
  /// `lerp` par [_lerpNullableRadius] (patron [countPillRadius]).
  final Radius? booleanPillRadius;

  /// Style du texte interne. `null` ⇒ `TextTheme.labelMedium` (12 sp — la
  /// mesure `valueFontSize: 12` historique, obtenue **sans** littéral de
  /// taille). La **couleur** de ce style est toujours écrasée par le premier
  /// plan résolu (jeton/dérivation) : un hôte ne peut pas casser le contraste
  /// par ce jeton.
  ///
  /// `lerp` par `TextStyle.lerp`, qui rend déjà `null` quand les deux côtés le
  /// sont (patron [studySectionTitleStyle]).
  final TextStyle? booleanPillTextStyle;

  /// Fabrique centrale d'`InputDecoration` : assemble la décoration à
  /// partir des tokens ci-dessus + des **couleurs dérivées** du `ColorScheme`
  /// courant (bordure `outline`, focus `primary`, erreur `error`, remplissage
  /// dérivé de la surface). AUCUNE couleur codée en dur (invariant FR-26).
  ///
  /// Trois de ces couleurs sont désormais
  /// **surchargeables par thème**, chaîne `jeton ?? rôle du ColorScheme` :
  /// * `border`/`enabledBorder` ← [fieldBorderColor] (repli `outline`) ;
  /// * `fillColor` ← [fieldFillColor] (repli `surfaceContainerHighest`) ;
  /// * `focusedBorder` ← [fieldFocusedBorderColor] (repli `primary`).
  ///
  /// `errorBorder`/`focusedErrorBorder` restent sur `ColorScheme.error` : la
  /// couleur d'erreur est un rôle sémantique, pas un choix de style.
  /// La couleur du LABEL n'est **pas** pilotée par [labelColor] mais par
  /// [labelTextStyle] — voir le dartdoc de [labelColor] pour les deux mesures
  /// qui l'imposent (canal de focus, et rendu de l'hôte passif).
  ///
  /// En mode [bare] (usage interne à la Card `large`) : bordures `none`,
  /// `isDense`, padding zéro, non rempli, **sans** label/floating-label (le label
  /// est porté par la Card).
  /// Paramètres **additifs** — défauts préservant la signature historique :
  /// - [labelWidget] : label **enrichi** (`ZFieldLabel`) ; s'il est fourni, il
  ///   prime sur [label] (String) — mutuellement exclusifs côté Flutter (`label`
  ///   Widget vs `labelText`). En `bare`, aucun label n'est posé (porté par la
  ///   Card), quelle que soit la valeur ;
  /// - [prefix]/[suffix] : ornements **texte** (`InputDecoration.prefix`/`suffix`)
  ///   résolus depuis `ZFieldAdornment.text` ;
  /// - [prefixIcon]/[suffixIcon] : ornements **icône** (déjà présents) ;
  /// - [leadingIcon] : ornement de **tête** hors bordure (`InputDecoration.icon`)
  ///   résolu depuis `ZFieldSpec.leading`.
  ///
  /// Aucune signature existante cassée ; aucune couleur en dur ajoutée (invariant FR-26).
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
    Color? tintColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (bare) {
      // `bare` (Card large) : jamais de label propre (porté par la Card) ; les
      // ornements internes prefix/suffix/icon restent portés si fournis.
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
    final restBorderColor = fieldBorderColor ?? scheme.outline;
    // Teinte par type de champ (`tintColor`, déjà normalisée pour le
    // contraste par l'appelant) : elle ne touche que les canaux d'ACCENT —
    // bordure de focus et couleur des icônes d'ornement. `null` (aucun
    // résolveur injecté) ⇒ chaîne de jetons strictement inchangée.
    final focusBorderColor =
        tintColor ?? fieldFocusedBorderColor ?? scheme.primary;
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
      // La teinte par type de champ atteint aussi le LIBELLÉ FLOTTANT : même
      // grammaire opt-in que la bordure de focus et les icônes — `tintColor`
      // est déjà normalisée par l'appelant contre la surface du champ (la même
      // surface que celle sur laquelle le libellé flottant se lit), et
      // `copyWith(color: null)` est un no-op ⇒ sans résolveur, style
      // strictement identique à l'antérieur, au pixel près. Application
      // DIRECTE plutôt qu'un jeton booléen : un jeton à défaut `true` serait
      // le premier du fichier qu'il faudrait DÉPOSER pour retenir la teinte —
      // l'inverse de la grammaire opt-in du canal (aucun résolveur ⇒ rien).
      floatingLabelStyle: (labelTextStyle ?? const TextStyle()).copyWith(
        fontWeight: floatingLabelWeight,
        color: tintColor,
      ),
      filled: inputFilled,
      // Jeton DÉDIÉ, absent du repli ⇒ hôte passif
      // strictement inchangé (`surfaceContainerHighest`). Voir [fieldFillColor]
      // pour les deux raisons mesurées de ne PAS réutiliser [surfaceColor].
      fillColor: fieldFillColor ?? scheme.surfaceContainerHighest,
      contentPadding: inputContentPadding,
      prefix: prefix,
      suffix: suffix,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      // « Pastille d'icône » : les ornements icône prennent la teinte du type
      // de champ quand elle est déclarée ; sans teinte, `null` laisse le
      // `IconTheme` ambiant décider — rendu antérieur inchangé.
      iconColor: tintColor,
      prefixIconColor: tintColor,
      suffixIconColor: tintColor,
      // Bordure de REPOS pilotée par le jeton
      // (`fallback` la pose à `outline` ⇒ hôte passif inchangé au pixel).
      // `focusedBorder`/`errorBorder` gardent leurs rôles d'ÉTAT : le jeton de
      // repos ne les teint pas (sinon repos/focus/erreur deviendraient
      // indiscernables) ; le focus a son propre jeton, lui aussi absent du repli.
      border: borderOf(restBorderColor, inputBorderWidth),
      enabledBorder: borderOf(restBorderColor, inputBorderWidth),
      focusedBorder: borderOf(focusBorderColor, inputFocusedBorderWidth),
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
    Color? fieldFillColor,
    Color? fieldFocusedBorderColor,
    bool? dateFieldDecorated,
    Color? errorColor,
    Color? onErrorColor,
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
    double? fieldGap,
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
    ZReadFieldLayout? readLayout,
    EdgeInsetsDirectional? readCardMargin,
    EdgeInsetsDirectional? readPadding,
    double? readLabelGap,
    TextStyle? readLabelTextStyle,
    TextStyle? readValueTextStyle,
    Color? readFillColor,
    Color? readBorderColor,
    double? readBorderWidth,
    double? readCardMinHeight,
    double? readRowLabelWidth,
    double? readRowMinWidth,
    double? subListColumnMinWidth,
    double? subListActionIconSize,
    Color? subListViewActionColor,
    Color? subListEditActionColor,
    Color? subListDeleteActionColor,
    Color? subListAddControlColor,
    Gradient? subListAddControlGradient,
    Radius? subListAddControlRadius,
    double? subListAddControlSize,
    Color? subListAddControlIconColor,
    double? adornmentIconBackgroundAlpha,
    Radius? adornmentIconBackgroundRadius,
    double? adornmentIconSize,
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
    ZSubfolderTriggerFill? subfolderTriggerFill,
    ZSubfolderTriggerBorder? subfolderTriggerBorder,
    double? subfolderTriggerElevation,
    IconData? subfolderTriggerCollapsedIcon,
    IconData? subfolderTriggerExpandedIcon,
    ZSubfolderSelectedEmphasis? subfolderSelectedEmphasis,
    EdgeInsetsGeometry? subfolderBarPadding,
    EdgeInsetsGeometry? subfolderSheetPadding,
    TextAlign? subfolderSheetTitleAlign,
    double? railItemWidth,
    double? railItemHeight,
    double? railItemGap,
    EdgeInsetsGeometry? railPadding,
    TextStyle? studySectionTitleStyle,
    ZStudySectionCountShape? studySectionCountShape,
    ZStudySectionCountRole? studySectionCountRole,
    ZStudySectionCollapsePlacement? studySectionCollapsePlacement,
    ZStudySectionCountPlacement? studySectionCountPlacement,
    double? studySectionCountGap,
    EdgeInsetsGeometry? subfolderSheetContentPadding,
    ZStudyCardHierarchy? studyCardHierarchy,
    Radius? studyCardRadius,
    double? studyCardLeadingGap,
    double? studyCardElevation,
    EdgeInsetsGeometry? studyCardContentPadding,
    EdgeInsetsGeometry? studyCardMargin,
    double? studyCardIconTileSize,
    Radius? studyCardIconTileRadius,
    TextStyle? studyCardTitleStyle,
    TextStyle? studyCardSubtitleStyle,
    BorderSide? studyCardBorderSide,
    Radius? studyCardBadgeRadius,
    double? studyCardGlyphSize,
    ZStudyCardContentAlignment? studyCardContentAlignment,
    Map<String, ZGradientSpec>? flashcardTypeGradients,
    Radius? folderCardRadius,
    BorderSide? folderCardBorderSide,
    EdgeInsetsGeometry? folderCardContentPadding,
    double? folderCardAccentHeight,
    double? folderCardTintAlpha,
    double? folderCardIconTileSize,
    Radius? folderCardIconTileRadius,
    double? folderCardIconTileTintAlpha,
    double? folderCardGlyphSize,
    double? folderCardMinContrast,
    ZFolderCardFooterPlacement? folderCardFooterPlacement,
    double? folderCardFooterBesideMinWidth,
    int? studySessionStackFlex,
    int? studySessionInputFlex,
    EdgeInsetsGeometry? studySessionContentPadding,
    double? studySessionDividerThickness,
    double? studySessionSectionGap,
    double? studySessionMinTarget,
    TextStyle? studySessionCounterStyle,
    EdgeInsetsGeometry? dailyTasksBandPadding,
    EdgeInsetsGeometry? dailyTasksDayCellMargin,
    EdgeInsetsGeometry? dailyTasksDayCellPadding,
    Radius? dailyTasksDayCellRadius,
    double? dailyTasksMinTapTarget,
    double? dailyTasksMonthBreakpoint,
    EdgeInsetsGeometry? dailyTasksItemPadding,
    ZContentHubDensity? contentHubDensity,
    double? contentHubItemExtent,
    Radius? contentHubItemRadius,
    EdgeInsetsGeometry? contentHubItemPadding,
    double? contentHubItemTintAlpha,
    double? contentHubAvatarSize,
    double? contentHubAvatarTintAlpha,
    double? contentHubGlyphSize,
    List<Color>? contentHubAccents,
    Color? contentHubBadgeColor,
    double? contentHubGridBreakpoint,
    int? contentHubGridCrossAxisCount,
    double? contentHubMinContrast,
    TextStyle? contentHubSectionTitleStyle,
    TextStyle? pageHeaderTitleStyle,
    TextStyle? pageHeaderSubtitleStyle,
    TextStyle? pageHeaderTabSelectedLabelStyle,
    TextStyle? pageHeaderTabUnselectedLabelStyle,
    double? chatBubbleWidthFactor,
    Radius? chatRequestBubbleRadius,
    Radius? chatResponseBubbleRadius,
    bool? chatBubbleShowAuthorAvatar,
    bool? chatBubbleShowAuthorName,
    bool? chatBubbleShowTimestamp,
    Color? chatToolAccentColor,
    Map<String, Color>? chatCapabilityAccents,
    List<Color>? chatBusyPalette,
    double? chatComposerSendTargetSize,
    double? chatComposerSendScaleIdle,
    double? chatComposerSendScaleActive,
    Duration? chatComposerSendScaleDuration,
    double? chatComposerMobileBreakpoint,
    Duration? chatComposerHintRotationPeriod,
    Duration? chatComposerHintSwitchDuration,
    Color? chatComposerActiveAccent,
    Map<String, Color>? chatResponseLengthAccents,
    FontWeight? chatSelectedEmphasisWeight,
    TextDecoration? chatSelectedEmphasisDecoration,
    String? editionSheetFrameMode,
    double? editionSheetWidthRatio,
    double? editionSheetMaxWidth,
    Color? editionSheetBorderColor,
    double? editionSheetBorderWidth,
    double? editionChromeMinTouchTarget,
    EdgeInsetsDirectional? editionChromeHeaderPadding,
    EdgeInsetsDirectional? editionChromeActionBarPadding,
    double? editionChromePageHeaderExpandedHeight,
    Color? selectTileBorderColor,
    double? selectTileBorderWidth,
    double? selectTileRadius,
    double? selectTileMinHeight,
    double? selectDialogBreakpoint,
    String? selectMonoChoiceStyle,
    String? selectMultiChoiceStyle,
    String? selectModalShape,
    Color? stepperRailColor,
    double? stepperRailThickness,
    Color? stepperBadgeForegroundColor,
    double? stepperAllStepsGap,
    double? stepperSideBandMaxWidth,
    Color? booleanPillActiveColor,
    Color? booleanPillInactiveColor,
    Color? booleanPillActiveForegroundColor,
    Color? booleanPillInactiveForegroundColor,
    double? booleanPillWidth,
    double? booleanPillHeight,
    double? booleanPillThumbSize,
    Radius? booleanPillRadius,
    TextStyle? booleanPillTextStyle,
  }) => ZcrudTheme(
    fieldBorderColor: fieldBorderColor ?? this.fieldBorderColor,
    fieldFillColor: fieldFillColor ?? this.fieldFillColor,
    fieldFocusedBorderColor:
        fieldFocusedBorderColor ?? this.fieldFocusedBorderColor,
    dateFieldDecorated: dateFieldDecorated ?? this.dateFieldDecorated,
    errorColor: errorColor ?? this.errorColor,
    onErrorColor: onErrorColor ?? this.onErrorColor,
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
    fieldGap: fieldGap ?? this.fieldGap,
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
    readLayout: readLayout ?? this.readLayout,
    readCardMargin: readCardMargin ?? this.readCardMargin,
    readPadding: readPadding ?? this.readPadding,
    readLabelGap: readLabelGap ?? this.readLabelGap,
    readLabelTextStyle: readLabelTextStyle ?? this.readLabelTextStyle,
    readValueTextStyle: readValueTextStyle ?? this.readValueTextStyle,
    readFillColor: readFillColor ?? this.readFillColor,
    readBorderColor: readBorderColor ?? this.readBorderColor,
    readBorderWidth: readBorderWidth ?? this.readBorderWidth,
    readCardMinHeight: readCardMinHeight ?? this.readCardMinHeight,
    readRowLabelWidth: readRowLabelWidth ?? this.readRowLabelWidth,
    readRowMinWidth: readRowMinWidth ?? this.readRowMinWidth,
    subListColumnMinWidth:
        subListColumnMinWidth ?? this.subListColumnMinWidth,
    subListActionIconSize:
        subListActionIconSize ?? this.subListActionIconSize,
    subListViewActionColor:
        subListViewActionColor ?? this.subListViewActionColor,
    subListEditActionColor:
        subListEditActionColor ?? this.subListEditActionColor,
    subListDeleteActionColor:
        subListDeleteActionColor ?? this.subListDeleteActionColor,
    subListAddControlColor:
        subListAddControlColor ?? this.subListAddControlColor,
    subListAddControlGradient:
        subListAddControlGradient ?? this.subListAddControlGradient,
    subListAddControlRadius:
        subListAddControlRadius ?? this.subListAddControlRadius,
    subListAddControlSize:
        subListAddControlSize ?? this.subListAddControlSize,
    subListAddControlIconColor:
        subListAddControlIconColor ?? this.subListAddControlIconColor,
    adornmentIconBackgroundAlpha:
        adornmentIconBackgroundAlpha ?? this.adornmentIconBackgroundAlpha,
    adornmentIconBackgroundRadius:
        adornmentIconBackgroundRadius ?? this.adornmentIconBackgroundRadius,
    adornmentIconSize: adornmentIconSize ?? this.adornmentIconSize,
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
    subfolderTriggerFill: subfolderTriggerFill ?? this.subfolderTriggerFill,
    subfolderTriggerBorder:
        subfolderTriggerBorder ?? this.subfolderTriggerBorder,
    subfolderTriggerElevation:
        subfolderTriggerElevation ?? this.subfolderTriggerElevation,
    subfolderTriggerCollapsedIcon:
        subfolderTriggerCollapsedIcon ?? this.subfolderTriggerCollapsedIcon,
    subfolderTriggerExpandedIcon:
        subfolderTriggerExpandedIcon ?? this.subfolderTriggerExpandedIcon,
    subfolderSelectedEmphasis:
        subfolderSelectedEmphasis ?? this.subfolderSelectedEmphasis,
    subfolderBarPadding: subfolderBarPadding ?? this.subfolderBarPadding,
    subfolderSheetPadding: subfolderSheetPadding ?? this.subfolderSheetPadding,
    subfolderSheetTitleAlign:
        subfolderSheetTitleAlign ?? this.subfolderSheetTitleAlign,
    railItemWidth: railItemWidth ?? this.railItemWidth,
    railItemHeight: railItemHeight ?? this.railItemHeight,
    railItemGap: railItemGap ?? this.railItemGap,
    railPadding: railPadding ?? this.railPadding,
    studySectionTitleStyle:
        studySectionTitleStyle ?? this.studySectionTitleStyle,
    studySectionCountShape:
        studySectionCountShape ?? this.studySectionCountShape,
    studySectionCountRole: studySectionCountRole ?? this.studySectionCountRole,
    studySectionCollapsePlacement:
        studySectionCollapsePlacement ?? this.studySectionCollapsePlacement,
    studySectionCountPlacement:
        studySectionCountPlacement ?? this.studySectionCountPlacement,
    studySectionCountGap: studySectionCountGap ?? this.studySectionCountGap,
    subfolderSheetContentPadding:
        subfolderSheetContentPadding ?? this.subfolderSheetContentPadding,
    studyCardHierarchy: studyCardHierarchy ?? this.studyCardHierarchy,
    studyCardRadius: studyCardRadius ?? this.studyCardRadius,
    studyCardLeadingGap: studyCardLeadingGap ?? this.studyCardLeadingGap,
    studyCardElevation: studyCardElevation ?? this.studyCardElevation,
    studyCardContentPadding:
        studyCardContentPadding ?? this.studyCardContentPadding,
    studyCardMargin: studyCardMargin ?? this.studyCardMargin,
    studyCardIconTileSize:
        studyCardIconTileSize ?? this.studyCardIconTileSize,
    studyCardIconTileRadius:
        studyCardIconTileRadius ?? this.studyCardIconTileRadius,
    studyCardTitleStyle: studyCardTitleStyle ?? this.studyCardTitleStyle,
    studyCardSubtitleStyle:
        studyCardSubtitleStyle ?? this.studyCardSubtitleStyle,
    studyCardBorderSide: studyCardBorderSide ?? this.studyCardBorderSide,
    studyCardBadgeRadius: studyCardBadgeRadius ?? this.studyCardBadgeRadius,
    studyCardGlyphSize: studyCardGlyphSize ?? this.studyCardGlyphSize,
    studyCardContentAlignment:
        studyCardContentAlignment ?? this.studyCardContentAlignment,
    flashcardTypeGradients:
        flashcardTypeGradients ?? this.flashcardTypeGradients,
    folderCardRadius: folderCardRadius ?? this.folderCardRadius,
    folderCardBorderSide: folderCardBorderSide ?? this.folderCardBorderSide,
    folderCardContentPadding:
        folderCardContentPadding ?? this.folderCardContentPadding,
    folderCardAccentHeight:
        folderCardAccentHeight ?? this.folderCardAccentHeight,
    folderCardTintAlpha: folderCardTintAlpha ?? this.folderCardTintAlpha,
    folderCardIconTileSize:
        folderCardIconTileSize ?? this.folderCardIconTileSize,
    folderCardIconTileRadius:
        folderCardIconTileRadius ?? this.folderCardIconTileRadius,
    folderCardIconTileTintAlpha:
        folderCardIconTileTintAlpha ?? this.folderCardIconTileTintAlpha,
    folderCardGlyphSize: folderCardGlyphSize ?? this.folderCardGlyphSize,
    folderCardMinContrast:
        folderCardMinContrast ?? this.folderCardMinContrast,
    folderCardFooterPlacement:
        folderCardFooterPlacement ?? this.folderCardFooterPlacement,
    folderCardFooterBesideMinWidth:
        folderCardFooterBesideMinWidth ?? this.folderCardFooterBesideMinWidth,
    studySessionStackFlex: studySessionStackFlex ?? this.studySessionStackFlex,
    studySessionInputFlex: studySessionInputFlex ?? this.studySessionInputFlex,
    studySessionContentPadding:
        studySessionContentPadding ?? this.studySessionContentPadding,
    studySessionDividerThickness:
        studySessionDividerThickness ?? this.studySessionDividerThickness,
    studySessionSectionGap:
        studySessionSectionGap ?? this.studySessionSectionGap,
    studySessionMinTarget: studySessionMinTarget ?? this.studySessionMinTarget,
    studySessionCounterStyle:
        studySessionCounterStyle ?? this.studySessionCounterStyle,
    dailyTasksBandPadding: dailyTasksBandPadding ?? this.dailyTasksBandPadding,
    dailyTasksDayCellMargin:
        dailyTasksDayCellMargin ?? this.dailyTasksDayCellMargin,
    dailyTasksDayCellPadding:
        dailyTasksDayCellPadding ?? this.dailyTasksDayCellPadding,
    dailyTasksDayCellRadius:
        dailyTasksDayCellRadius ?? this.dailyTasksDayCellRadius,
    dailyTasksMinTapTarget:
        dailyTasksMinTapTarget ?? this.dailyTasksMinTapTarget,
    dailyTasksMonthBreakpoint:
        dailyTasksMonthBreakpoint ?? this.dailyTasksMonthBreakpoint,
    dailyTasksItemPadding: dailyTasksItemPadding ?? this.dailyTasksItemPadding,
    contentHubDensity: contentHubDensity ?? this.contentHubDensity,
    contentHubItemExtent: contentHubItemExtent ?? this.contentHubItemExtent,
    contentHubItemRadius: contentHubItemRadius ?? this.contentHubItemRadius,
    contentHubItemPadding: contentHubItemPadding ?? this.contentHubItemPadding,
    contentHubItemTintAlpha:
        contentHubItemTintAlpha ?? this.contentHubItemTintAlpha,
    contentHubAvatarSize: contentHubAvatarSize ?? this.contentHubAvatarSize,
    contentHubAvatarTintAlpha:
        contentHubAvatarTintAlpha ?? this.contentHubAvatarTintAlpha,
    contentHubGlyphSize: contentHubGlyphSize ?? this.contentHubGlyphSize,
    contentHubAccents: contentHubAccents ?? this.contentHubAccents,
    contentHubBadgeColor: contentHubBadgeColor ?? this.contentHubBadgeColor,
    contentHubGridBreakpoint:
        contentHubGridBreakpoint ?? this.contentHubGridBreakpoint,
    contentHubGridCrossAxisCount:
        contentHubGridCrossAxisCount ?? this.contentHubGridCrossAxisCount,
    contentHubMinContrast:
        contentHubMinContrast ?? this.contentHubMinContrast,
    contentHubSectionTitleStyle:
        contentHubSectionTitleStyle ?? this.contentHubSectionTitleStyle,
    pageHeaderTitleStyle: pageHeaderTitleStyle ?? this.pageHeaderTitleStyle,
    pageHeaderSubtitleStyle:
        pageHeaderSubtitleStyle ?? this.pageHeaderSubtitleStyle,
    pageHeaderTabSelectedLabelStyle:
        pageHeaderTabSelectedLabelStyle ?? this.pageHeaderTabSelectedLabelStyle,
    pageHeaderTabUnselectedLabelStyle:
        pageHeaderTabUnselectedLabelStyle ??
        this.pageHeaderTabUnselectedLabelStyle,
    chatBubbleWidthFactor:
        chatBubbleWidthFactor ?? this.chatBubbleWidthFactor,
    chatRequestBubbleRadius:
        chatRequestBubbleRadius ?? this.chatRequestBubbleRadius,
    chatResponseBubbleRadius:
        chatResponseBubbleRadius ?? this.chatResponseBubbleRadius,
    chatBubbleShowAuthorAvatar:
        chatBubbleShowAuthorAvatar ?? this.chatBubbleShowAuthorAvatar,
    chatBubbleShowAuthorName:
        chatBubbleShowAuthorName ?? this.chatBubbleShowAuthorName,
    chatBubbleShowTimestamp:
        chatBubbleShowTimestamp ?? this.chatBubbleShowTimestamp,
    chatToolAccentColor: chatToolAccentColor ?? this.chatToolAccentColor,
    chatCapabilityAccents:
        chatCapabilityAccents ?? this.chatCapabilityAccents,
    chatBusyPalette: chatBusyPalette ?? this.chatBusyPalette,
    chatComposerSendTargetSize:
        chatComposerSendTargetSize ?? this.chatComposerSendTargetSize,
    chatComposerSendScaleIdle:
        chatComposerSendScaleIdle ?? this.chatComposerSendScaleIdle,
    chatComposerSendScaleActive:
        chatComposerSendScaleActive ?? this.chatComposerSendScaleActive,
    chatComposerSendScaleDuration:
        chatComposerSendScaleDuration ?? this.chatComposerSendScaleDuration,
    chatComposerMobileBreakpoint:
        chatComposerMobileBreakpoint ?? this.chatComposerMobileBreakpoint,
    chatComposerHintRotationPeriod:
        chatComposerHintRotationPeriod ?? this.chatComposerHintRotationPeriod,
    chatComposerHintSwitchDuration:
        chatComposerHintSwitchDuration ?? this.chatComposerHintSwitchDuration,
    chatComposerActiveAccent:
        chatComposerActiveAccent ?? this.chatComposerActiveAccent,
    chatResponseLengthAccents:
        chatResponseLengthAccents ?? this.chatResponseLengthAccents,
    chatSelectedEmphasisWeight:
        chatSelectedEmphasisWeight ?? this.chatSelectedEmphasisWeight,
    chatSelectedEmphasisDecoration:
        chatSelectedEmphasisDecoration ?? this.chatSelectedEmphasisDecoration,
    editionSheetFrameMode: editionSheetFrameMode ?? this.editionSheetFrameMode,
    editionSheetWidthRatio:
        editionSheetWidthRatio ?? this.editionSheetWidthRatio,
    editionSheetMaxWidth: editionSheetMaxWidth ?? this.editionSheetMaxWidth,
    editionSheetBorderColor:
        editionSheetBorderColor ?? this.editionSheetBorderColor,
    editionSheetBorderWidth:
        editionSheetBorderWidth ?? this.editionSheetBorderWidth,
    editionChromeMinTouchTarget:
        editionChromeMinTouchTarget ?? this.editionChromeMinTouchTarget,
    editionChromeHeaderPadding:
        editionChromeHeaderPadding ?? this.editionChromeHeaderPadding,
    editionChromeActionBarPadding:
        editionChromeActionBarPadding ?? this.editionChromeActionBarPadding,
    editionChromePageHeaderExpandedHeight:
        editionChromePageHeaderExpandedHeight ??
        this.editionChromePageHeaderExpandedHeight,
    selectTileBorderColor: selectTileBorderColor ?? this.selectTileBorderColor,
    selectTileBorderWidth: selectTileBorderWidth ?? this.selectTileBorderWidth,
    selectTileRadius: selectTileRadius ?? this.selectTileRadius,
    selectTileMinHeight: selectTileMinHeight ?? this.selectTileMinHeight,
    selectDialogBreakpoint:
        selectDialogBreakpoint ?? this.selectDialogBreakpoint,
    selectMonoChoiceStyle: selectMonoChoiceStyle ?? this.selectMonoChoiceStyle,
    selectMultiChoiceStyle:
        selectMultiChoiceStyle ?? this.selectMultiChoiceStyle,
    selectModalShape: selectModalShape ?? this.selectModalShape,
    stepperRailColor: stepperRailColor ?? this.stepperRailColor,
    stepperRailThickness: stepperRailThickness ?? this.stepperRailThickness,
    stepperBadgeForegroundColor:
        stepperBadgeForegroundColor ?? this.stepperBadgeForegroundColor,
    stepperAllStepsGap: stepperAllStepsGap ?? this.stepperAllStepsGap,
    stepperSideBandMaxWidth:
        stepperSideBandMaxWidth ?? this.stepperSideBandMaxWidth,
    booleanPillActiveColor:
        booleanPillActiveColor ?? this.booleanPillActiveColor,
    booleanPillInactiveColor:
        booleanPillInactiveColor ?? this.booleanPillInactiveColor,
    booleanPillActiveForegroundColor: booleanPillActiveForegroundColor ??
        this.booleanPillActiveForegroundColor,
    booleanPillInactiveForegroundColor: booleanPillInactiveForegroundColor ??
        this.booleanPillInactiveForegroundColor,
    booleanPillWidth: booleanPillWidth ?? this.booleanPillWidth,
    booleanPillHeight: booleanPillHeight ?? this.booleanPillHeight,
    booleanPillThumbSize: booleanPillThumbSize ?? this.booleanPillThumbSize,
    booleanPillRadius: booleanPillRadius ?? this.booleanPillRadius,
    booleanPillTextStyle: booleanPillTextStyle ?? this.booleanPillTextStyle,
  );

  @override
  ZcrudTheme lerp(ThemeExtension<ZcrudTheme>? other, double t) {
    if (other is! ZcrudTheme) return this;
    return ZcrudTheme(
      fieldBorderColor: Color.lerp(fieldBorderColor, other.fieldBorderColor, t),
      // `_lerpNullableColor` et NON `Color.lerp` : ces deux jetons sont
      // absents de [ZcrudTheme.fallback], donc `null` signifie « le
      // consommateur applique SON rôle de repli » (`surfaceContainerHighest`,
      // `primary`) — pas « transparent ». Or `Color.lerp(null, c, t)` rend `c`
      // dont l'alpha est mis à l'échelle de `t` : à `t = 0` il matérialiserait
      // une couleur FANTÔME **transparente** par-dessus le repli, faisant
      // clignoter le fond/la bordure de tous les champs pendant une transition
      // de thème. Même famille de raisons que `_lerpNullableFloor`/`Duration`.
      fieldFillColor: _lerpNullableColor(fieldFillColor, other.fieldFillColor, t),
      fieldFocusedBorderColor: _lerpNullableColor(
        fieldFocusedBorderColor,
        other.fieldFocusedBorderColor,
        t,
      ),
      // Jeton DISCRET (bascule d'apparence) : aucune valeur intermédiaire n'a
      // de sens ⇒ bascule au point milieu, comme les autres booléens nullables.
      // `null` des deux côtés RESTE `null` (l'héritage n'est pas gelé).
      dateFieldDecorated:
          t < 0.5 ? dateFieldDecorated : other.dateFieldDecorated,
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      onErrorColor: Color.lerp(onErrorColor, other.onErrorColor, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      gapS: gapS + (other.gapS - gapS) * t,
      gapM: gapM + (other.gapM - gapM) * t,
      gapL: gapL + (other.gapL - gapL) * t,
      radiusS: Radius.lerp(radiusS, other.radiusS, t) ?? radiusS,
      radiusM: Radius.lerp(radiusM, other.radiusM, t) ?? radiusM,
      // `null` des DEUX côtés doit RESTER `null` : c'est l'héritage déclaré
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
      // `_lerpNullableFloor` : pour une DIMENSION, un côté `null` signifie
      // « repli du consommateur » (ici `0`) et non « zéro interpolable ».
      // `_lerpNullableDouble(null, 12, 0)` rendrait `0` — indiscernable de
      // l'absence — puis grandirait ; le plancher évite ce clignotement.
      fieldGap: _lerpNullableFloor(fieldGap, other.fieldGap, t),
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
      readLayout: t < 0.5 ? readLayout : other.readLayout,
      readCardMargin:
          EdgeInsetsDirectional.lerp(readCardMargin, other.readCardMargin, t),
      readPadding: EdgeInsetsDirectional.lerp(readPadding, other.readPadding, t),
      readLabelGap: _lerpNullableDouble(readLabelGap, other.readLabelGap, t),
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
      readFillColor: Color.lerp(readFillColor, other.readFillColor, t),
      readBorderColor: Color.lerp(readBorderColor, other.readBorderColor, t),
      readBorderWidth: _lerpNullableDouble(
        readBorderWidth,
        other.readBorderWidth,
        t,
      ),
      readCardMinHeight: _lerpNullableDouble(
        readCardMinHeight,
        other.readCardMinHeight,
        t,
      ),
      readRowLabelWidth: _lerpNullableDouble(
        readRowLabelWidth,
        other.readRowLabelWidth,
        t,
      ),
      readRowMinWidth: _lerpNullableDouble(
        readRowMinWidth,
        other.readRowMinWidth,
        t,
      ),
      subListColumnMinWidth: _lerpNullableDouble(
        subListColumnMinWidth,
        other.subListColumnMinWidth,
        t,
      ),
      subListActionIconSize: _lerpNullableDouble(
        subListActionIconSize,
        other.subListActionIconSize,
        t,
      ),
      subListViewActionColor: _lerpNullableColor(
        subListViewActionColor,
        other.subListViewActionColor,
        t,
      ),
      subListEditActionColor: _lerpNullableColor(
        subListEditActionColor,
        other.subListEditActionColor,
        t,
      ),
      subListDeleteActionColor: _lerpNullableColor(
        subListDeleteActionColor,
        other.subListDeleteActionColor,
        t,
      ),
      subListAddControlColor: _lerpNullableColor(
        subListAddControlColor,
        other.subListAddControlColor,
        t,
      ),
      // Dégradé : bascule discrète à mi-transition — `Gradient.lerp` avec un
      // côté `null` matérialiserait un dégradé fantôme sur un thème qui n'en
      // déclare pas (même raison que les glyphes de chevron).
      subListAddControlGradient: t < 0.5
          ? subListAddControlGradient
          : other.subListAddControlGradient,
      subListAddControlRadius: _lerpNullableRadius(
        subListAddControlRadius,
        other.subListAddControlRadius,
        t,
      ),
      subListAddControlSize: _lerpNullableDouble(
        subListAddControlSize,
        other.subListAddControlSize,
        t,
      ),
      subListAddControlIconColor: _lerpNullableColor(
        subListAddControlIconColor,
        other.subListAddControlIconColor,
        t,
      ),
      adornmentIconBackgroundAlpha: _lerpNullableDouble(
        adornmentIconBackgroundAlpha,
        other.adornmentIconBackgroundAlpha,
        t,
      ),
      adornmentIconBackgroundRadius: _lerpNullableRadius(
        adornmentIconBackgroundRadius,
        other.adornmentIconBackgroundRadius,
        t,
      ),
      adornmentIconSize: _lerpNullableDouble(
        adornmentIconSize,
        other.adornmentIconSize,
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
      // fill/border DISCRETS (aucun rôle intermédiaire n'existe) :
      // bascule au point milieu, `null` des DEUX côtés RESTE `null` (même
      // invariant que `subfolderTriggerVariant` : matérialiser une valeur
      // GÈLERAIT « la variante décide » à la première transition de thème).
      subfolderTriggerFill: t < 0.5
          ? subfolderTriggerFill
          : other.subfolderTriggerFill,
      subfolderTriggerBorder: t < 0.5
          ? subfolderTriggerBorder
          : other.subfolderTriggerBorder,
      // Élévation CONTINUE : elle s'interpole. `null` des DEUX côtés RESTE
      // `null` (même invariant que `accentBarHeight`).
      subfolderTriggerElevation: _lerpNullableDouble(
        subfolderTriggerElevation,
        other.subfolderTriggerElevation,
        t,
      ),
      subfolderTriggerCollapsedIcon: t < 0.5
          ? subfolderTriggerCollapsedIcon
          : other.subfolderTriggerCollapsedIcon,
      subfolderTriggerExpandedIcon: t < 0.5
          ? subfolderTriggerExpandedIcon
          : other.subfolderTriggerExpandedIcon,
      subfolderSelectedEmphasis: t < 0.5
          ? subfolderSelectedEmphasis
          : other.subfolderSelectedEmphasis,
      // Marge CONTINUE : elle s'interpole. `null` des DEUX côtés RESTE `null`
      // (même invariant que `countPillPadding`) — matérialiser
      // `EdgeInsets.zero` ici GÈLERAIT « pas d'enveloppe dans l'arbre » à la
      // première transition de thème.
      subfolderBarPadding: _lerpNullableInsets(
        subfolderBarPadding,
        other.subfolderBarPadding,
        t,
      ),
      // Même nature que `subfolderBarPadding` : marge
      // CONTINUE qui s'interpole, `null` des DEUX côtés RESTE `null` (sans quoi
      // « aucune enveloppe dans l'arbre » serait GELÉ à la première transition
      // de thème).
      subfolderSheetPadding: _lerpNullableInsets(
        subfolderSheetPadding,
        other.subfolderSheetPadding,
        t,
      ),
      // Token DISCRET (aucun alignement intermédiaire
      // n'existe entre `start` et `center`) : bascule au point milieu, même
      // invariant de `null` que les tokens discrets ci-dessus.
      subfolderSheetTitleAlign: t < 0.5
          ? subfolderSheetTitleAlign
          : other.subfolderSheetTitleAlign,
      // Largeur CONTINUE : elle s'interpole. `null` des DEUX
      // côtés RESTE `null` (même invariant que `accentBarHeight`) —
      // matérialiser une valeur ici GÈLERAIT le défaut du consommateur à la
      // première transition de thème.
      railItemWidth: _lerpNullableDouble(railItemWidth, other.railItemWidth, t),
      // MÊME invariant : `null` des DEUX côtés reste `null`
      // (`_lerpNullableDouble` court-circuite le cas null-null), sans quoi la
      // première transition de thème matérialiserait une hauteur là où le
      // contrat dit « aucune contrainte ».
      railItemHeight: _lerpNullableDouble(
        railItemHeight,
        other.railItemHeight,
        t,
      ),
      railItemGap: _lerpNullableDouble(railItemGap, other.railItemGap, t),
      // Padding CONTINU et directionnel-préservant (AD-13) ; null-null ⇒ null.
      railPadding: _lerpNullableInsets(railPadding, other.railPadding, t),
      // Style CONTINU : `TextStyle.lerp` rend déjà `null` quand
      // les DEUX côtés sont `null` (même invariant que `labelTextStyle`) — le
      // repli du consommateur (`labelTextStyle` puis `titleMedium`) n'est
      // jamais GELÉ par une transition de thème.
      studySectionTitleStyle: TextStyle.lerp(
        studySectionTitleStyle,
        other.studySectionTitleStyle,
        t,
      ),
      // Tokens DISCRETS (aucune forme/rôle/placement
      // intermédiaire n'existe) : bascule au point milieu, `null` des DEUX
      // côtés RESTE `null` (même invariant que `subfolderTriggerVariant`).
      studySectionCountShape: t < 0.5
          ? studySectionCountShape
          : other.studySectionCountShape,
      studySectionCountRole: t < 0.5
          ? studySectionCountRole
          : other.studySectionCountRole,
      studySectionCollapsePlacement: t < 0.5
          ? studySectionCollapsePlacement
          : other.studySectionCollapsePlacement,
      // Discret ⇒ bascule au point milieu ; continu ⇒
      // interpolation null-préservante.
      studySectionCountPlacement: t < 0.5
          ? studySectionCountPlacement
          : other.studySectionCountPlacement,
      studySectionCountGap: _lerpNullableDouble(
        studySectionCountGap,
        other.studySectionCountGap,
        t,
      ),
      // Gouttière interne de la feuille de fratrie.
      subfolderSheetContentPadding: _lerpNullableInsets(
        subfolderSheetContentPadding,
        other.subfolderSheetContentPadding,
        t,
      ),
      // Tokens des cartes d'étude par défaut. Même invariant que
      // TOUS les tokens nullables ci-dessus : `null` des DEUX côtés RESTE
      // `null` (matérialiser une valeur GÈLERAIT la référence du consommateur
      // à la première transition de thème). Discrets ⇒ bascule au point
      // milieu ; continus ⇒ interpolation null-préservante.
      studyCardHierarchy:
          t < 0.5 ? studyCardHierarchy : other.studyCardHierarchy,
      studyCardRadius: _lerpNullableRadius(
        studyCardRadius,
        other.studyCardRadius,
        t,
      ),
      // Écart tuile→titre et élévation des cartes par défaut.
      studyCardLeadingGap: _lerpNullableDouble(
        studyCardLeadingGap,
        other.studyCardLeadingGap,
        t,
      ),
      studyCardElevation: _lerpNullableDouble(
        studyCardElevation,
        other.studyCardElevation,
        t,
      ),
      studyCardContentPadding: _lerpNullableInsets(
        studyCardContentPadding,
        other.studyCardContentPadding,
        t,
      ),
      studyCardMargin: _lerpNullableInsets(
        studyCardMargin,
        other.studyCardMargin,
        t,
      ),
      studyCardIconTileSize: _lerpNullableDouble(
        studyCardIconTileSize,
        other.studyCardIconTileSize,
        t,
      ),
      studyCardIconTileRadius: _lerpNullableRadius(
        studyCardIconTileRadius,
        other.studyCardIconTileRadius,
        t,
      ),
      studyCardTitleStyle: TextStyle.lerp(
        studyCardTitleStyle,
        other.studyCardTitleStyle,
        t,
      ),
      studyCardSubtitleStyle: TextStyle.lerp(
        studyCardSubtitleStyle,
        other.studyCardSubtitleStyle,
        t,
      ),
      studyCardBorderSide:
          studyCardBorderSide == null && other.studyCardBorderSide == null
              ? null
              : BorderSide.lerp(
                  studyCardBorderSide ?? BorderSide.none,
                  other.studyCardBorderSide ?? BorderSide.none,
                  t,
                ),
      studyCardBadgeRadius: _lerpNullableRadius(
        studyCardBadgeRadius,
        other.studyCardBadgeRadius,
        t,
      ),
      // Court-circuit null-null : l'héritage documenté (28 = référence) ne
      // doit pas être matérialisé par une transition de thème.
      studyCardGlyphSize:
          studyCardGlyphSize == null && other.studyCardGlyphSize == null
          ? null
          : _lerpNullableDouble(
              studyCardGlyphSize,
              other.studyCardGlyphSize,
              t,
            ),
      // DISCRET (une map de specs ne s'interpole pas) et
      // null-préservant PAR CONSTRUCTION : `null`↔`null` reste `null` — la
      // référence du consommateur n'est jamais matérialisée par une
      // transition de thème (leçon `studyCardBadgeRadius`).
      // Token DISCRET (un alignement ne s'interpole pas) et
      // null-préservant PAR CONSTRUCTION : `null`↔`null` reste `null`.
      studyCardContentAlignment: t < 0.5
          ? studyCardContentAlignment
          : other.studyCardContentAlignment,
      flashcardTypeGradients:
          t < 0.5 ? flashcardTypeGradients : other.flashcardTypeGradients,
      // Chaque jeton de carte de dossier est null-PRÉSERVANT :
      // `null`↔`null` reste `null`, donc la valeur de RÉFÉRENCE du
      // consommateur n'est JAMAIS matérialisée par une transition de thème
      // (leçon `studyCardBadgeRadius`/`studyCardGlyphSize`).
      folderCardRadius: _lerpNullableRadius(
        folderCardRadius,
        other.folderCardRadius,
        t,
      ),
      folderCardBorderSide:
          folderCardBorderSide == null && other.folderCardBorderSide == null
          ? null
          : BorderSide.lerp(
              folderCardBorderSide ?? BorderSide.none,
              other.folderCardBorderSide ?? BorderSide.none,
              t,
            ),
      folderCardContentPadding: _lerpNullableInsets(
        folderCardContentPadding,
        other.folderCardContentPadding,
        t,
      ),
      folderCardAccentHeight:
          folderCardAccentHeight == null && other.folderCardAccentHeight == null
          ? null
          : _lerpNullableDouble(
              folderCardAccentHeight,
              other.folderCardAccentHeight,
              t,
            ),
      folderCardTintAlpha:
          folderCardTintAlpha == null && other.folderCardTintAlpha == null
          ? null
          : _lerpNullableDouble(
              folderCardTintAlpha,
              other.folderCardTintAlpha,
              t,
            ),
      folderCardIconTileSize:
          folderCardIconTileSize == null && other.folderCardIconTileSize == null
          ? null
          : _lerpNullableDouble(
              folderCardIconTileSize,
              other.folderCardIconTileSize,
              t,
            ),
      folderCardIconTileRadius: _lerpNullableRadius(
        folderCardIconTileRadius,
        other.folderCardIconTileRadius,
        t,
      ),
      folderCardIconTileTintAlpha:
          folderCardIconTileTintAlpha == null &&
              other.folderCardIconTileTintAlpha == null
          ? null
          : _lerpNullableDouble(
              folderCardIconTileTintAlpha,
              other.folderCardIconTileTintAlpha,
              t,
            ),
      folderCardGlyphSize:
          folderCardGlyphSize == null && other.folderCardGlyphSize == null
          ? null
          : _lerpNullableDouble(
              folderCardGlyphSize,
              other.folderCardGlyphSize,
              t,
            ),
      // Un PLANCHER ne s'interpole pas : une valeur intermédiaire pendant une
      // transition de thème serait un plancher que personne n'a choisi.
      folderCardMinContrast: t < 0.5
          ? folderCardMinContrast
          : other.folderCardMinContrast,
      // Une DISPOSITION et un POINT DE RUPTURE sont discrets : ni
      // demi-empilement, ni seuil intermédiaire (qui ferait basculer la mise en
      // page au milieu d'une transition de thème).
      folderCardFooterPlacement: t < 0.5
          ? folderCardFooterPlacement
          : other.folderCardFooterPlacement,
      folderCardFooterBesideMinWidth: t < 0.5
          ? folderCardFooterBesideMinWidth
          : other.folderCardFooterBesideMinWidth,
      // ── Session de révision ────────────────────────────────────────────────
      // Les deux FLEX sont DISCRETS : un `flex` est un entier de contrainte.
      // L'interpoler fabriquerait des entiers que personne n'a choisis (et,
      // arrondis, une pile 3/2 passerait par 2/2 — une répartition qu'aucun
      // des deux thèmes ne décrit). Ils BASCULENT donc à mi-course, comme
      // `contentHubGridCrossAxisCount`.
      studySessionStackFlex: t < 0.5
          ? studySessionStackFlex
          : other.studySessionStackFlex,
      studySessionInputFlex: t < 0.5
          ? studySessionInputFlex
          : other.studySessionInputFlex,
      // Padding CONTINU et directionnel-préservant (AD-13) ; null-null ⇒ null.
      studySessionContentPadding: _lerpNullableInsets(
        studySessionContentPadding,
        other.studySessionContentPadding,
        t,
      ),
      // Épaisseur et écart : dimensions CONTINUES. Un côté absent traité comme
      // `0` est ici acceptable (un séparateur qui s'amincit, un écart qui se
      // referme sont des rendus plausibles) ; `null` des DEUX côtés reste
      // `null`, donc la référence du consommateur n'est jamais matérialisée.
      studySessionDividerThickness: _lerpNullableDouble(
        studySessionDividerThickness,
        other.studySessionDividerThickness,
        t,
      ),
      studySessionSectionGap: _lerpNullableDouble(
        studySessionSectionGap,
        other.studySessionSectionGap,
        t,
      ),
      // Le PLANCHER de cible, lui, n'a PAS droit au traitement précédent :
      // `_lerpNullableDouble(null, 48, 0)` rendrait **0**, c'est-à-dire une
      // fenêtre — courte mais réelle — pendant laquelle les cibles tapables de
      // la session n'ont plus AUCUN plancher (AD-13 violé au milieu d'une
      // transition de thème). Même leçon que `celebrationDuration` : pour une
      // CONTRAINTE, `0` n'est pas une absence, c'est une valeur invalide.
      studySessionMinTarget: _lerpNullableFloor(
        studySessionMinTarget,
        other.studySessionMinTarget,
        t,
      ),
      // Style CONTINU : `TextStyle.lerp` rend déjà `null` quand les DEUX côtés
      // sont `null` — le repli `labelLarge` du consommateur n'est jamais gelé.
      studySessionCounterStyle: TextStyle.lerp(
        studySessionCounterStyle,
        other.studySessionCounterStyle,
        t,
      ),
      // ── Tâches du jour ───────────────────────────────────────────────────
      // Marges CONTINUES et directionnel-préservantes (AD-13) ; `null` des deux
      // côtés reste `null`, donc la référence du consommateur n'est jamais
      // matérialisée par une transition de thème.
      dailyTasksBandPadding: _lerpNullableInsets(
        dailyTasksBandPadding,
        other.dailyTasksBandPadding,
        t,
      ),
      dailyTasksDayCellMargin: _lerpNullableInsets(
        dailyTasksDayCellMargin,
        other.dailyTasksDayCellMargin,
        t,
      ),
      dailyTasksDayCellPadding: _lerpNullableInsets(
        dailyTasksDayCellPadding,
        other.dailyTasksDayCellPadding,
        t,
      ),
      dailyTasksItemPadding: _lerpNullableInsets(
        dailyTasksItemPadding,
        other.dailyTasksItemPadding,
        t,
      ),
      // Rayon CONTINU, null-préservant (helper partagé avec les autres rayons).
      dailyTasksDayCellRadius: _lerpNullableRadius(
        dailyTasksDayCellRadius,
        other.dailyTasksDayCellRadius,
        t,
      ),
      // Le PLANCHER de cible n'a PAS droit au traitement des dimensions :
      // `_lerpNullableDouble(null, 48, 0)` rendrait **0**, c'est-à-dire une
      // fenêtre — courte mais réelle — pendant laquelle les sept cibles du
      // bandeau n'ont plus AUCUN plancher (AD-13 violé en pleine transition de
      // thème). Pour une CONTRAINTE, `0` n'est pas une absence : c'est une
      // valeur invalide. Même arbitrage que `studySessionMinTarget`.
      dailyTasksMinTapTarget: _lerpNullableFloor(
        dailyTasksMinTapTarget,
        other.dailyTasksMinTapTarget,
        t,
      ),
      // Le SEUIL de mois est DISCRET : interpolé, il ferait apparaître ou
      // disparaître le libellé de mois à une largeur qu'AUCUN des deux thèmes
      // ne décrit — une bascule de mise en page au milieu de l'animation, non
      // choisie. Il bascule à mi-course, comme `folderCardFooterBesideMinWidth`
      // (même nature : un point de rupture, pas une dimension).
      dailyTasksMonthBreakpoint: t < 0.5
          ? dailyTasksMonthBreakpoint
          : other.dailyTasksMonthBreakpoint,
      // Chaque jeton de hub est null-PRÉSERVANT : `null`↔`null`
      // reste `null`, donc la valeur de RÉFÉRENCE du consommateur n'est JAMAIS
      // matérialisée par une transition de thème (leçon `studyCardBadgeRadius`).
      // Les jetons DISCRETS (densité, palette, nombre de colonnes) ne
      // s'interpolent pas : une demi-densité ou une demi-colonne n'existe pas.
      contentHubDensity: t < 0.5 ? contentHubDensity : other.contentHubDensity,
      contentHubItemExtent:
          contentHubItemExtent == null && other.contentHubItemExtent == null
          ? null
          : _lerpNullableDouble(
              contentHubItemExtent,
              other.contentHubItemExtent,
              t,
            ),
      contentHubItemRadius: _lerpNullableRadius(
        contentHubItemRadius,
        other.contentHubItemRadius,
        t,
      ),
      contentHubItemPadding: _lerpNullableInsets(
        contentHubItemPadding,
        other.contentHubItemPadding,
        t,
      ),
      contentHubItemTintAlpha:
          contentHubItemTintAlpha == null &&
              other.contentHubItemTintAlpha == null
          ? null
          : _lerpNullableDouble(
              contentHubItemTintAlpha,
              other.contentHubItemTintAlpha,
              t,
            ),
      contentHubAvatarSize:
          contentHubAvatarSize == null && other.contentHubAvatarSize == null
          ? null
          : _lerpNullableDouble(
              contentHubAvatarSize,
              other.contentHubAvatarSize,
              t,
            ),
      contentHubAvatarTintAlpha:
          contentHubAvatarTintAlpha == null &&
              other.contentHubAvatarTintAlpha == null
          ? null
          : _lerpNullableDouble(
              contentHubAvatarTintAlpha,
              other.contentHubAvatarTintAlpha,
              t,
            ),
      contentHubGlyphSize:
          contentHubGlyphSize == null && other.contentHubGlyphSize == null
          ? null
          : _lerpNullableDouble(
              contentHubGlyphSize,
              other.contentHubGlyphSize,
              t,
            ),
      contentHubAccents: t < 0.5 ? contentHubAccents : other.contentHubAccents,
      contentHubBadgeColor: Color.lerp(
        contentHubBadgeColor,
        other.contentHubBadgeColor,
        t,
      ),
      contentHubGridBreakpoint:
          contentHubGridBreakpoint == null &&
              other.contentHubGridBreakpoint == null
          ? null
          : _lerpNullableDouble(
              contentHubGridBreakpoint,
              other.contentHubGridBreakpoint,
              t,
            ),
      contentHubGridCrossAxisCount: t < 0.5
          ? contentHubGridCrossAxisCount
          : other.contentHubGridCrossAxisCount,
      // Un PLANCHER ne s'interpole pas : une valeur intermédiaire serait un
      // plancher que personne n'a choisi.
      contentHubMinContrast: t < 0.5
          ? contentHubMinContrast
          : other.contentHubMinContrast,
      contentHubSectionTitleStyle: TextStyle.lerp(
        contentHubSectionTitleStyle,
        other.contentHubSectionTitleStyle,
        t,
      ),
      // `TextStyle.lerp` est null-préservant : `null`↔`null` rend
      // `null`, donc le repli documenté du consommateur (« rien n'est posé »)
      // n'est JAMAIS matérialisé par une transition de thème (même invariant
      // que `studySectionTitleStyle`/`labelTextStyle`).
      pageHeaderTitleStyle: TextStyle.lerp(
        pageHeaderTitleStyle,
        other.pageHeaderTitleStyle,
        t,
      ),
      pageHeaderSubtitleStyle: TextStyle.lerp(
        pageHeaderSubtitleStyle,
        other.pageHeaderSubtitleStyle,
        t,
      ),
      pageHeaderTabSelectedLabelStyle: TextStyle.lerp(
        pageHeaderTabSelectedLabelStyle,
        other.pageHeaderTabSelectedLabelStyle,
        t,
      ),
      pageHeaderTabUnselectedLabelStyle: TextStyle.lerp(
        pageHeaderTabUnselectedLabelStyle,
        other.pageHeaderTabUnselectedLabelStyle,
        t,
      ),
      // Jetons du rendu de chat. Chaque helper est
      // null-PRÉSERVANT : `null`↔`null` reste `null`, donc la valeur de
      // RÉFÉRENCE de `ZChatNotebookSkin` n'est jamais matérialisée par une
      // transition de thème.
      chatBubbleWidthFactor:
          chatBubbleWidthFactor == null && other.chatBubbleWidthFactor == null
          ? null
          : _lerpNullableDouble(
              chatBubbleWidthFactor,
              other.chatBubbleWidthFactor,
              t,
            ),
      chatRequestBubbleRadius: _lerpNullableRadius(
        chatRequestBubbleRadius,
        other.chatRequestBubbleRadius,
        t,
      ),
      chatResponseBubbleRadius: _lerpNullableRadius(
        chatResponseBubbleRadius,
        other.chatResponseBubbleRadius,
        t,
      ),
      // Un BOOLÉEN, une TABLE et une SÉQUENCE sont discrets : ni demi-avatar,
      // ni demi-palette. Ils basculent au milieu de la transition.
      chatBubbleShowAuthorAvatar: t < 0.5
          ? chatBubbleShowAuthorAvatar
          : other.chatBubbleShowAuthorAvatar,
      chatBubbleShowAuthorName: t < 0.5
          ? chatBubbleShowAuthorName
          : other.chatBubbleShowAuthorName,
      chatBubbleShowTimestamp: t < 0.5
          ? chatBubbleShowTimestamp
          : other.chatBubbleShowTimestamp,
      chatToolAccentColor: Color.lerp(
        chatToolAccentColor,
        other.chatToolAccentColor,
        t,
      ),
      chatCapabilityAccents: t < 0.5
          ? chatCapabilityAccents
          : other.chatCapabilityAccents,
      chatBusyPalette: t < 0.5 ? chatBusyPalette : other.chatBusyPalette,
      // Chrome du composer. Les arguments de
      // chaque choix de lerp sont sur les DÉCLARATIONS des jetons.
      // PLANCHER de cible et ÉCHELLES : jamais `0` matérialisé — une cible
      // de 0 dp est une régression AD-13, une échelle 0 un glyphe invisible.
      chatComposerSendTargetSize: _lerpNullableFloor(
        chatComposerSendTargetSize,
        other.chatComposerSendTargetSize,
        t,
      ),
      chatComposerSendScaleIdle: _lerpNullableFloor(
        chatComposerSendScaleIdle,
        other.chatComposerSendScaleIdle,
        t,
      ),
      chatComposerSendScaleActive: _lerpNullableFloor(
        chatComposerSendScaleActive,
        other.chatComposerSendScaleActive,
        t,
      ),
      chatComposerSendScaleDuration: _lerpNullableDuration(
        chatComposerSendScaleDuration,
        other.chatComposerSendScaleDuration,
        t,
      ),
      // SEUIL : DISCRET à t=.5 — le correctif v0.54.1
      // (`dailyTasksMonthBreakpoint`) est né d'un lerp continu tagué rouge.
      chatComposerMobileBreakpoint: t < 0.5
          ? chatComposerMobileBreakpoint
          : other.chatComposerMobileBreakpoint,
      chatComposerHintRotationPeriod: _lerpNullableDuration(
        chatComposerHintRotationPeriod,
        other.chatComposerHintRotationPeriod,
        t,
      ),
      chatComposerHintSwitchDuration: _lerpNullableDuration(
        chatComposerHintSwitchDuration,
        other.chatComposerHintSwitchDuration,
        t,
      ),
      // COULEUR : interpolable, comme les autres teintes nullables — `null`
      // des deux côtés reste `null` (la référence n'est jamais matérialisée).
      chatComposerActiveAccent: Color.lerp(
        chatComposerActiveAccent,
        other.chatComposerActiveAccent,
        t,
      ),
      // TABLE : discrète, comme `chatCapabilityAccents` (pas de demi-palette).
      chatResponseLengthAccents: t < 0.5
          ? chatResponseLengthAccents
          : other.chatResponseLengthAccents,
      chatSelectedEmphasisWeight: _lerpNullableFontWeight(
        chatSelectedEmphasisWeight,
        other.chatSelectedEmphasisWeight,
        t,
      ),
      // Pas de demi-soulignement : discret, comme les booléens.
      chatSelectedEmphasisDecoration: t < 0.5
          ? chatSelectedEmphasisDecoration
          : other.chatSelectedEmphasisDecoration,
      // ── Feuille d'édition ──────────────────────────────────────────────────
      // MODE : valeur DISCRÈTE (un nom de palier), donc bascule à mi-course —
      // il n'existe pas de demi-cadre, et interpoler une chaîne n'a aucun sens.
      // Même règle que `subfolderTriggerVariant`.
      editionSheetFrameMode: t < 0.5
          ? editionSheetFrameMode
          : other.editionSheetFrameMode,
      // DIMENSIONS : `lerp` de PLANCHER. Un côté `null` signifie « la référence
      // du consommateur », jamais `0` — un ratio, un plafond ou une épaisseur
      // nuls rendraient la feuille invisible le temps de la transition.
      editionSheetWidthRatio: _lerpNullableFloor(
        editionSheetWidthRatio,
        other.editionSheetWidthRatio,
        t,
      ),
      editionSheetMaxWidth: _lerpNullableFloor(
        editionSheetMaxWidth,
        other.editionSheetMaxWidth,
        t,
      ),
      // COULEUR NULLABLE absente du repli : `_lerpNullableColor`, jamais
      // `Color.lerp` (qui matérialiserait un cadre fantôme par-dessus le rôle
      // `outlineVariant` du consommateur).
      editionSheetBorderColor: _lerpNullableColor(
        editionSheetBorderColor,
        other.editionSheetBorderColor,
        t,
      ),
      editionSheetBorderWidth: _lerpNullableFloor(
        editionSheetBorderWidth,
        other.editionSheetBorderWidth,
        t,
      ),
      // ── Chrome d'édition ────────────────────────────────────────────────
      // PLANCHER d'accessibilité : `_lerpNullableFloor` obligatoire (AD-13) —
      // même leçon que `studySessionMinTarget`.
      editionChromeMinTouchTarget: _lerpNullableFloor(
        editionChromeMinTouchTarget,
        other.editionChromeMinTouchTarget,
        t,
      ),
      // Marges CONTINUES et directionnelles (AD-13) ; null-null ⇒ null.
      editionChromeHeaderPadding: _lerpNullablePadding(
        editionChromeHeaderPadding,
        other.editionChromeHeaderPadding,
        t,
      ),
      editionChromeActionBarPadding: _lerpNullablePadding(
        editionChromeActionBarPadding,
        other.editionChromeActionBarPadding,
        t,
      ),
      // Hauteur d'en-tête : `0` serait un en-tête REPLIÉ, pas une absence.
      editionChromePageHeaderExpandedHeight: _lerpNullableFloor(
        editionChromePageHeaderExpandedHeight,
        other.editionChromePageHeaderExpandedHeight,
        t,
      ),
      // ── Déclencheur de sélection (CR-SELECT-SEAM) ───────────────────────
      // COULEUR NULLABLE absente du repli : `_lerpNullableColor`, jamais
      // `Color.lerp` (qui peindrait une bordure fantôme par-dessus le rôle).
      selectTileBorderColor: _lerpNullableColor(
        selectTileBorderColor,
        other.selectTileBorderColor,
        t,
      ),
      // DIMENSIONS : `_lerpNullableFloor` — `0` serait « pas de bordure »,
      // « coins carrés », « aucun plancher de cible » (AD-13) et « tout en
      // dialogue », c'est-à-dire quatre rendus que personne n'a choisis.
      selectTileBorderWidth: _lerpNullableFloor(
        selectTileBorderWidth,
        other.selectTileBorderWidth,
        t,
      ),
      selectTileRadius: _lerpNullableFloor(
        selectTileRadius,
        other.selectTileRadius,
        t,
      ),
      selectTileMinHeight: _lerpNullableFloor(
        selectTileMinHeight,
        other.selectTileMinHeight,
        t,
      ),
      selectDialogBreakpoint: _lerpNullableFloor(
        selectDialogBreakpoint,
        other.selectDialogBreakpoint,
        t,
      ),
      // PALIERS NOMMÉS : `lerp` DISCRET — il n'existe pas de demi-radio ni de
      // demi-feuille (patron `editionSheetFrameMode`).
      selectMonoChoiceStyle:
          t < 0.5 ? selectMonoChoiceStyle : other.selectMonoChoiceStyle,
      selectMultiChoiceStyle:
          t < 0.5 ? selectMultiChoiceStyle : other.selectMultiChoiceStyle,
      selectModalShape: t < 0.5 ? selectModalShape : other.selectModalShape,
      // COULEURS NULLABLES absentes du repli : `_lerpNullableColor`, jamais
      // `Color.lerp` (qui matérialise la teinte dès `t > 0` et écraserait le
      // rôle/contraste de repli du consommateur pendant la transition).
      stepperRailColor: _lerpNullableColor(
        stepperRailColor,
        other.stepperRailColor,
        t,
      ),
      stepperBadgeForegroundColor: _lerpNullableColor(
        stepperBadgeForegroundColor,
        other.stepperBadgeForegroundColor,
        t,
      ),
      // DIMENSIONS : `_lerpNullableFloor` — un côté `null` ne doit pas tirer la
      // mesure vers `0` (rail escamoté, étapes collées, bande de largeur nulle).
      stepperRailThickness: _lerpNullableFloor(
        stepperRailThickness,
        other.stepperRailThickness,
        t,
      ),
      stepperAllStepsGap: _lerpNullableFloor(
        stepperAllStepsGap,
        other.stepperAllStepsGap,
        t,
      ),
      stepperSideBandMaxWidth: _lerpNullableFloor(
        stepperSideBandMaxWidth,
        other.stepperSideBandMaxWidth,
        t,
      ),
      // COULEURS NULLABLES absentes du repli : `_lerpNullableColor`, jamais
      // `Color.lerp` — matérialiser une teinte dès `t > 0` écraserait le rôle
      // (piste) ou le CONTRASTE DÉRIVÉ (texte interne, pouce) du consommateur
      // pendant la transition de thème.
      booleanPillActiveColor: _lerpNullableColor(
        booleanPillActiveColor,
        other.booleanPillActiveColor,
        t,
      ),
      booleanPillInactiveColor: _lerpNullableColor(
        booleanPillInactiveColor,
        other.booleanPillInactiveColor,
        t,
      ),
      booleanPillActiveForegroundColor: _lerpNullableColor(
        booleanPillActiveForegroundColor,
        other.booleanPillActiveForegroundColor,
        t,
      ),
      booleanPillInactiveForegroundColor: _lerpNullableColor(
        booleanPillInactiveForegroundColor,
        other.booleanPillInactiveForegroundColor,
        t,
      ),
      // DIMENSIONS : `_lerpNullableFloor` — un côté `null` ne doit pas tirer la
      // mesure vers `0` (pilule escamotée, pouce absent).
      booleanPillWidth: _lerpNullableFloor(
        booleanPillWidth,
        other.booleanPillWidth,
        t,
      ),
      booleanPillHeight: _lerpNullableFloor(
        booleanPillHeight,
        other.booleanPillHeight,
        t,
      ),
      booleanPillThumbSize: _lerpNullableFloor(
        booleanPillThumbSize,
        other.booleanPillThumbSize,
        t,
      ),
      booleanPillRadius: _lerpNullableRadius(
        booleanPillRadius,
        other.booleanPillRadius,
        t,
      ),
      // STYLE CONTINU : `TextStyle.lerp` rend déjà `null` quand les deux côtés
      // le sont (patron `studySectionTitleStyle`).
      booleanPillTextStyle: TextStyle.lerp(
        booleanPillTextStyle,
        other.booleanPillTextStyle,
        t,
      ),
    );
  }
}

/// Interpole deux graisses nullables — **sans jamais matérialiser `w400`**.
///
/// Même famille de raisons que [_lerpNullableDuration] et
/// [_lerpNullableFloor] : `FontWeight.lerp` substitue `FontWeight.normal` à un
/// côté `null`. Or `null` signifie ici « le consommateur applique SA graisse
/// d'emphase de référence » (`w700` pour la sélection) : interpoler
/// depuis `w400` ferait passer l'option choisie par une graisse NORMALE — la
/// sélection visible disparaîtrait le temps de la transition, exactement le
/// défaut corrigé ici. Un côté `null` ⇒ on rend l'autre côté, seule
/// valeur réellement connue.
FontWeight? _lerpNullableFontWeight(FontWeight? a, FontWeight? b, double t) {
  if (a == null) return b;
  if (b == null) return a;
  return FontWeight.lerp(a, b, t);
}

double? _lerpNullableDouble(double? a, double? b, double t) =>
    a == null && b == null ? null : (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;

/// Interpole deux **PLANCHERS** nullables — sans jamais matérialiser `0`.
///
/// Différence VOLONTAIRE avec [_lerpNullableDouble], pour la même raison que
/// [_lerpNullableDuration] : pour une DIMENSION, traiter un côté absent comme
/// `0` est plausible (une barre qui grandit depuis rien) ; pour une CONTRAINTE
/// de plancher, `0` n'est pas une absence — c'est « aucun plancher », donc une
/// régression d'accessibilité (AD-13) le temps de la transition.
///
/// Règle : un côté `null` signifie « le consommateur applique SON plancher de
/// référence », valeur que le thème ignore. Aucune interpolation n'est alors
/// possible ; on rend l'autre côté, seule valeur réellement connue.
double? _lerpNullableFloor(double? a, double? b, double t) {
  if (a == null) return b;
  if (b == null) return a;
  return a + (b - a) * t;
}

Offset? _lerpNullableOffset(Offset? a, Offset? b, double t) =>
    a == null && b == null
    ? null
    : Offset.lerp(a ?? Offset.zero, b ?? Offset.zero, t);

Radius? _lerpNullableRadius(Radius? a, Radius? b, double t) =>
    a == null && b == null
    ? null
    : Radius.lerp(a ?? Radius.zero, b ?? Radius.zero, t);

/// Interpolation d'une marge NULLABLE **directionnelle-compatible**.
///
/// `EdgeInsetsGeometry.lerp` préserve la nature des deux bornes (un
/// `EdgeInsetsDirectional` interpolé avec `EdgeInsetsDirectional.zero` reste
/// directionnel — AD-13). `null` des deux côtés reste `null`.
EdgeInsetsGeometry? _lerpNullableInsets(
  EdgeInsetsGeometry? a,
  EdgeInsetsGeometry? b,
  double t,
) => a == null && b == null
    ? null
    : EdgeInsetsGeometry.lerp(
        a ?? (b is EdgeInsetsDirectional
            ? EdgeInsetsDirectional.zero
            : EdgeInsets.zero),
        b ?? (a is EdgeInsetsDirectional
            ? EdgeInsetsDirectional.zero
            : EdgeInsets.zero),
        t,
      );

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
/// Différence VOLONTAIRE avec les autres helpers nullables.
/// Pour une dimension, traiter un côté absent comme `0` est
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
/// `lerp` d'une couleur dont `null` **n'est pas** « transparent » mais « repli
/// du consommateur » (jeton absent de [ZcrudTheme.fallback]).
///
/// Différence VOLONTAIRE avec `Color.lerp`, même famille de raisons que
/// [_lerpNullableFloor]/[_lerpNullableDuration] : `Color.lerp(null, b, t)` rend
/// `b` avec l'alpha mis à l'échelle de `t` — à `t = 0` une couleur totalement
/// TRANSPARENTE, c'est-à-dire une couleur fantôme substituée au rôle de repli.
/// Ici un côté `null` rend simplement l'autre côté, seule valeur connue.
Color? _lerpNullableColor(Color? a, Color? b, double t) {
  if (a == null) return b;
  if (b == null) return a;
  return Color.lerp(a, b, t);
}

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
