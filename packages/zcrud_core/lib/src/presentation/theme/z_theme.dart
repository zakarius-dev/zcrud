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
import 'z_gradient_resolver.dart';

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

/// RÔLE de **fond** du déclencheur de navigation de fratrie (CR-IFFD-60) —
/// token de LOOK, attribut COMPOSABLE.
///
/// 🔴 **Aucune couleur ici.** Chaque valeur nomme un RÔLE de surface Material
/// que le consommateur traduit depuis le `ColorScheme` courant (FR-26/NFR-S7)
/// — même patron que [ZStudySectionCountRole].
///
/// **Précédence** (CR-IFFD-60) : fourni, ce token PRIME sur ce que
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

/// RÔLE de **bordure** du déclencheur de navigation de fratrie (CR-IFFD-60) —
/// token de LOOK, attribut COMPOSABLE.
///
/// 🔴 **Aucune couleur ici** : chaque valeur nomme un rôle de contour du
/// `ColorScheme` courant (FR-26/NFR-S7).
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

/// Forme du compteur d'items d'un en-tête de section d'étude (CR-IFFD-50 ②) —
/// token de LOOK.
///
/// 🔴 **Aucune couleur ici** : la forme est indépendante de la matière (le rôle
/// de couleur vit dans [ZStudySectionCountRole]) — même frontière que
/// CR-IFFD-48 : la forme monte, la matière reste au thème.
enum ZStudySectionCountShape {
  /// Rectangle arrondi (`badgeRadius`, repli `radiusM`). **Rendu historique** —
  /// c'est ce que rend un thème qui ne déclare rien.
  rounded,

  /// Pastille (stadium) : les coins suivent la demi-hauteur du badge, quel que
  /// soit son contenu — la « pastille ronde » de la référence, sans rayon
  /// magique.
  pill,
}

/// RÔLE de couleur du compteur d'en-tête de section d'étude (CR-IFFD-50 ②).
///
/// 🔴 **Aucune couleur ici.** Chaque valeur nomme un **couple de rôles**
/// Material (fond / premier plan) que le consommateur traduit depuis le
/// `ColorScheme` courant : l'hôte choisit un rôle, jamais un hex (FR-26/NFR-S7)
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

/// Placement de l'affordance de REPLI d'une section d'étude (CR-IFFD-50 ④) —
/// token de LOOK (structure d'en-tête).
///
/// 🔵 **Pourquoi un token de THÈME et non un champ de spec** : c'est une
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

/// PLACEMENT du compteur d'en-tête d'une section d'étude (**CR-IFFD-61 ④**) —
/// token de LOOK (structure d'en-tête).
///
/// 🔵 **Pourquoi un token de THÈME et non un champ de spec** : même arbitrage
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

/// Hiérarchie tuile/glyphe d'une **carte d'item d'étude par défaut**
/// (CR-IFFD-55/56) — token de LOOK.
///
/// 🔴 **Aucune couleur ici** : la hiérarchie dit OÙ la couleur d'accent se
/// pose, jamais laquelle (la couleur reste un rôle/une entrée injectable —
/// CR-48). Même frontière que [ZStudySectionCountShape] : la forme monte, la
/// matière reste au thème.
enum ZStudyCardHierarchy {
  /// **Rendu de référence** (défaut CR-IFFD-56) : tuile NEUTRE (`surface`),
  /// glyphe teinté par l'accent résolu. C'est ce que rend un thème qui ne
  /// déclare rien.
  tintedGlyph,

  /// Rendu **v0.43.0** : tuile colorée par l'accent, glyphe en `onColor`
  /// apparié. Atteignable par réglage — plus un défaut (CR-IFFD-56).
  tintedTile,
}

/// Alignement VERTICAL du contenu d'une **carte d'item d'étude**
/// (**CR-IFFD-62 ④**) — token de LOOK, aucune couleur, aucune dimension.
///
/// 🔴 **N'a d'effet QUE sous une hauteur IMPOSÉE** (cadre reçu du parent :
/// `SizedBox(height:)`, cellule de grille, `ZRailItem(height:)`). Sans cadre,
/// la carte se dimensionne sur son contenu : il n'y a **aucun espace libre à
/// répartir**, et les trois valeurs rendent alors STRICTEMENT la même chose —
/// c'est ce qui rend ce token neutre par construction pour les hôtes qui ne
/// bornent pas leurs cartes.
enum ZStudyCardContentAlignment {
  /// Contenu collé en HAUT du cadre ; l'espace libre reste sous le pied.
  top,

  /// **Rendu de référence** de la carte de flashcard (CR-IFFD-62 ⑤) :
  /// l'espace libre est absorbé par le **bloc de titre** (l'énoncé), ce qui
  /// pousse le pied (pastille de type) au **bas** du cadre. C'est la cascade
  /// `Expanded` du legacy IFFD — en-tête fixe, énoncé extensible, pied en bas.
  spread,

  /// Contenu collé en BAS du cadre ; l'espace libre reste au-dessus de
  /// l'en-tête.
  bottom,
}

/// DISPOSITION du bas de carte d'une carte de dossier d'étude
/// (`ZFolderCard` / `ZDefaultFolderCard`, **CR-IFFD-68**) — token de LOOK :
/// il dit OÙ va le pied, jamais ce qu'il contient.
///
/// 🔴 **Le défaut mesuré qui l'a fait exister** : la primitive assemblait le
/// créneau compteur et le créneau pied dans la MÊME `Row`, chacun en
/// `Expanded` — donc chacun à la MOITIÉ de la largeur. Mesuré chez IFFD : une
/// carte à quatre badges de compteur n'en montrait plus que **deux**, et le
/// pied (« Par toi ») venait s'accoler au dernier badge visible. Le seul
/// contournement possible — recomposer soi-même le créneau compteur — **rend
/// à l'hôte le rendu des badges**, donc lui fait perdre le plancher de
/// contraste que `ZDefaultFolderCard` garantit (CR-IFFD-64).
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
  /// 🔴 **Le badge « Archivé » suit la DERNIÈRE ligne de la pile** : le poser
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

/// Densité du **hub d'ajout de contenu** (`ZContentHubSheet`, **CR-IFFD-65**).
///
/// 🔴 **Le défaut a CHANGÉ le 2026-08-05, sur décision du propriétaire du
/// socle** : le rendu de RÉFÉRENCE (legacy IFFD — sections titrées, pastille
/// d'identité, badge de mise en avant, entrées en cartes, chevron) devient le
/// défaut, hauteur d'item de référence **assumée** et **défilement attendu**.
///
/// ⚠️ **La densité d'avant ne disparaît pas — elle cesse d'être le défaut.**
/// L'argument d'ÉCHELLE de CR-IFFD-65 reste vrai (« à douze types, la mise en
/// page legacy demanderait trois ou quatre écrans ») : [compact] y répond, et
/// il est atteignable **par paramètre** (`ZContentHubSheet.density`) **ET par
/// jeton** ([ZcrudTheme.contentHubDensity]) — priorité paramètre > jeton >
/// référence.
enum ZContentHubDensity {
  /// **Rendu de référence** (défaut depuis CR-IFFD-65) : entrées en cartes à la
  /// hauteur d'item de référence (112), pastille circulaire teintée, chevron
  /// d'affordance, intitulés de section, grille à deux colonnes au-delà du
  /// point de rupture.
  comfortable,

  /// **La densité d'AVANT CR-IFFD-65**, restituée par réglage : une entrée =
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
  ///
  /// **CR-IFFD-60** : la variante reste l'API publiée (v0.36.0) et reste
  /// fonctionnelle telle quelle. Les trois attributs composables
  /// ([subfolderTriggerFill], [subfolderTriggerBorder],
  /// [subfolderTriggerElevation]) la **raffinent** : fournis, ils priment
  /// **attribut par attribut** ; absents (`null`), la variante décide.
  final ZSubfolderTriggerVariant? subfolderTriggerVariant;

  /// RÔLE de fond du déclencheur de fratrie (CR-IFFD-60) — composable.
  ///
  /// `null` ⇒ [subfolderTriggerVariant] décide du fond (rendu **strictement
  /// inchangé** pour tout thème existant). Fourni, il PRIME sur le fond de la
  /// variante — et seulement sur lui. [ZSubfolderTriggerFill.none] est le
  /// retrait EXPLICITE du fond.
  final ZSubfolderTriggerFill? subfolderTriggerFill;

  /// RÔLE de bordure du déclencheur de fratrie (CR-IFFD-60) — composable.
  ///
  /// `null` ⇒ [subfolderTriggerVariant] décide de la bordure (rendu
  /// **strictement inchangé**). Fourni, il PRIME sur la bordure de la variante
  /// — et seulement sur elle. [ZSubfolderTriggerBorder.none] est le retrait
  /// EXPLICITE de la bordure.
  final ZSubfolderTriggerBorder? subfolderTriggerBorder;

  /// RELIEF du déclencheur de fratrie (CR-IFFD-60) — composable, en dp
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

  /// Marge EXTÉRIEURE de la barre de fratrie (CR-IFFD-44, manque 2).
  /// `null` ⇒ **aucune enveloppe dans l'arbre**, rendu strictement inchangé
  /// (la barre reste bord à bord dans son parent).
  ///
  /// 🔵 **Pourquoi un token de THÈME et non un champ de spec** : les quatre
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

  /// Marge EXTÉRIEURE du contenu de la **feuille** de fratrie (CR-IFFD-46,
  /// point 4) — **pendant exact** de [subfolderBarPadding], côté feuille.
  ///
  /// `null` ⇒ **aucune enveloppe dans l'arbre**, rendu strictement inchangé (la
  /// feuille conserve sa seule gouttière interne `gapM`).
  ///
  /// ⚠️ **S'ajoute à la gouttière interne, il ne la remplace pas** : la
  /// neutralité littérale exige que `null` laisse l'arbre d'avant CR-IFFD-46.
  /// Remplacer la gouttière aurait fait de « je veux 4 dp de plus » un « je
  /// perds les 16 dp que j'avais ».
  ///
  /// ⚠️ **Elle n'entame PAS le plafond de 80 % de hauteur d'écran** de la
  /// feuille (v0.36.0) : ce plafond est posé en `constraints` sur la feuille
  /// ELLE-MÊME par `showModalBottomSheet`, donc au-DESSUS de cette marge. Une
  /// marge verticale généreuse réduit la hauteur du CONTENU, jamais celle de la
  /// feuille — et la liste, `Flexible`, absorbe la différence.
  ///
  /// **AD-13** : `EdgeInsetsGeometry` — un `EdgeInsetsDirectional` bascule en
  /// RTL. Un `EdgeInsets.only(left:)` reste possible pour l'hôte qui veut
  /// délibérément une marge physique ; c'est SON choix, jamais un défaut du
  /// socle (même arbitrage que [subfolderBarPadding]).
  final EdgeInsetsGeometry? subfolderSheetPadding;

  /// Alignement du **titre** de la feuille de fratrie (CR-IFFD-46, point 2).
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
  /// 🔵 **Pourquoi un token de THÈME et non un champ de spec** : c'est une
  /// décision d'**apparence** pure — elle ne fait apparaître ni disparaître
  /// aucun contrôle, et n'altère aucune donnée de fratrie (critère posé par
  /// `ZSubfolderAddPlacement`, qui est resté dans la spec pour la raison
  /// inverse). Le titre lui-même, en revanche, est un LIBELLÉ : il reste dans
  /// la spec (`sheetTitle`), car un paquet ne code aucune chaîne (FR-26).
  final TextAlign? subfolderSheetTitleAlign;

  /// Largeur d'un item de **rail horizontal** rendu PAR DÉFAUT par un
  /// consommateur (CR-IFFD-49 — voies typées `ZStudyToolsSectionSpec` de
  /// `zcrud_study`).
  ///
  /// `null` ⇒ le consommateur applique SON défaut documenté (280 dp côté
  /// `zcrud_study`) — rendu **strictement inchangé** pour tout thème existant.
  /// La priorité chez le consommateur est : paramètre explicite de la voie
  /// typée > ce token > défaut du consommateur.
  ///
  /// 🔵 **Pourquoi un token de THÈME** : une largeur d'item est une décision
  /// d'apparence (densité), pas de structure — même arbitrage que
  /// [subfolderBarPadding]. La valeur mesurée chez un hôte (300 dp IFFD) reste
  /// SA valeur : il la pose ici, jamais dans le socle.
  final double? railItemWidth;

  /// HAUTEUR d'un item de **rail horizontal** (**CR-IFFD-62 ①**) — pendant
  /// exact de [railItemWidth].
  ///
  /// `null` ⇒ **aucune contrainte de hauteur** n'est posée : l'item garde la
  /// hauteur que lui donne son contenu (rendu **strictement inchangé** pour
  /// tout thème existant). Priorité chez le consommateur : paramètre explicite
  /// > ce token > absence de contrainte.
  ///
  /// 🔴 **Pourquoi PAS de repli chiffré ici, contrairement à [railItemWidth]**
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

  /// ESPACEMENT entre deux items d'un **rail horizontal** (**CR-IFFD-62 ④**).
  ///
  /// `null` ⇒ le consommateur applique son repli documenté ([gapS] côté
  /// `zcrud_study`) — rendu **strictement inchangé**. Priorité : paramètre
  /// explicite de la voie typée > ce token > repli du consommateur.
  ///
  /// Ce token existe pour la même raison que [studyCardLeadingGap]
  /// (CR-IFFD-61 ③) : l'espacement du rail ridait [gapS], jeton que l'hôte
  /// règle déjà pour ses écarts inter-slots — aucune valeur de [gapS] ne
  /// pouvait satisfaire à la fois l'un et le 12 de la référence.
  final double? railItemGap;

  /// PADDING du défileur d'un **rail horizontal** (**CR-IFFD-62 ④**) — le
  /// retrait latéral du rail lui-même.
  ///
  /// `null` ⇒ le rail hérite du padding de section du consommateur (chez
  /// `zcrud_study` : `horizontal: gapM`) — rendu **strictement inchangé**.
  /// Non-null ⇒ le retrait latéral du rail devient ABSOLU : le padding
  /// horizontal de section ne s'y AJOUTE plus (il reste appliqué à l'en-tête).
  ///
  /// ⚠️ Le retrait mesuré au **bord de la première carte** vaut ce padding
  /// **plus la marge externe de la carte** (`CardThemeData.margin` /
  /// `studyCardMargin`) : les deux s'additionnent, et c'est précisément le
  /// cumul mesuré par CR-IFFD-62 (12 + 4 = 16 dp).
  final EdgeInsetsGeometry? railPadding;

  /// Style du TITRE d'un en-tête de section d'étude (CR-IFFD-50 ①).
  ///
  /// `null` ⇒ le consommateur applique son repli documenté
  /// (`labelTextStyle`, puis `TextTheme.titleMedium`) — rendu **strictement
  /// inchangé** pour tout thème existant. Non-null ⇒ ce style PRIME : la
  /// référence peut dire « repère de navigation, plus grand et plus gras »
  /// sans qu'aucun rôle de texte ne soit figé dans un paquet.
  final TextStyle? studySectionTitleStyle;

  /// FORME du compteur d'en-tête de section d'étude (CR-IFFD-50 ②).
  ///
  /// `null` ⇒ [ZStudySectionCountShape.rounded] (rectangle arrondi,
  /// `badgeRadius` repli `radiusM`) — rendu **strictement inchangé**.
  final ZStudySectionCountShape? studySectionCountShape;

  /// RÔLE de couleur du compteur d'en-tête de section d'étude (CR-IFFD-50 ②).
  ///
  /// `null` ⇒ [ZStudySectionCountRole.secondaryContainer] — rendu
  /// **strictement inchangé**. La couleur vient TOUJOURS du `ColorScheme`
  /// courant : ce token nomme un rôle, jamais un hex (FR-26).
  final ZStudySectionCountRole? studySectionCountRole;

  /// PLACEMENT de l'affordance de repli d'une section d'étude (CR-IFFD-50 ④).
  ///
  /// `null` ⇒ [ZStudySectionCollapsePlacement.belowTitle] (chevron sous le
  /// titre) — rendu **strictement inchangé**.
  final ZStudySectionCollapsePlacement? studySectionCollapsePlacement;

  /// PLACEMENT du compteur d'en-tête d'une section d'étude (**CR-IFFD-61 ④**).
  ///
  /// `null` ⇒ [ZStudySectionCountPlacement.lineEnd] (compteur à l'extrémité de
  /// la ligne) — rendu **strictement inchangé**.
  final ZStudySectionCountPlacement? studySectionCountPlacement;

  /// ÉCART entre le titre d'en-tête de section et son compteur
  /// (**CR-IFFD-61 ④**), dans les DEUX placements.
  ///
  /// `null` ⇒ [gapS] — le rendu historique. Ce token existe parce que l'écart
  /// titre↔compteur ridait [gapS], jeton générique partagé avec toutes les
  /// autres gouttières de l'en-tête : aucune valeur de [gapS] ne pouvait à la
  /// fois satisfaire la référence (12 entre titre et compteur) et les
  /// espacements inter-actions. Même arbitrage que [studyCardLeadingGap].
  final double? studySectionCountGap;

  /// Padding STRUCTUREL **interne** de la feuille de fratrie
  /// (**CR-IFFD-61 ③**) : gouttière de la feuille, padding de son titre,
  /// padding de son pied « ajouter ».
  ///
  /// `null` ⇒ `EdgeInsetsDirectional.all(gapM)` — rendu **strictement
  /// inchangé**. Ce token existe pour la même raison que
  /// [studyCardLeadingGap] : la feuille ridait [gapM], que l'hôte règle déjà
  /// pour le padding de ses cartes (12) alors que sa feuille en demande 8.
  ///
  /// ⚠️ DISTINCT de [subfolderSheetPadding], qui est la marge **EXTÉRIEURE**
  /// de la feuille (CR-IFFD-46) et qui s'AJOUTE à celle-ci.
  final EdgeInsetsGeometry? subfolderSheetContentPadding;

  // ── Tokens des CARTES D'ITEM D'ÉTUDE par défaut (CR-IFFD-55/56) ───────────
  // Directive owner : les défauts du consommateur (`zcrud_study`) sont le
  // RENDU DE RÉFÉRENCE IFFD, centralisé dans `ZStudyCardReference` côté
  // consommateur. Chaque token `null` ⇒ le consommateur applique la valeur de
  // référence documentée. Priorité, partout : paramètre de carte > token >
  // défaut-référence. Aucune couleur figée ici (FR-26) : ce qui porte une
  // couleur ([studyCardBorderSide], les styles) est INJECTÉ par l'hôte.

  /// Hiérarchie tuile/glyphe des cartes d'étude par défaut (CR-IFFD-56).
  /// `null` ⇒ [ZStudyCardHierarchy.tintedGlyph] — le rendu de RÉFÉRENCE.
  /// [ZStudyCardHierarchy.tintedTile] restitue exactement le rendu v0.43.0.
  final ZStudyCardHierarchy? studyCardHierarchy;

  /// Rayon de la carte d'étude par défaut. `null` ⇒ 16 (référence).
  final Radius? studyCardRadius;

  /// ÉCART entre la tuile d'icône de tête et le titre, dans les cartes d'étude
  /// **par défaut** (**CR-IFFD-61 ①**). `null` ⇒ 16 (référence legacy IFFD).
  ///
  /// ⚠️ Ne concerne QUE les cartes par défaut : la primitive de base
  /// `ZStudyToolsItemCard` garde son écart historique [gapM] pour les hôtes qui
  /// la composent eux-mêmes (neutralité — cf. son slot `leadingGap`).
  ///
  /// Ce token existe parce que cet écart ridait [gapM], que l'hôte règle déjà
  /// pour le padding de carte (12) alors que la référence demande 16 : aucune
  /// valeur de [gapM] ne pouvait satisfaire les deux.
  final double? studyCardLeadingGap;

  /// ÉLÉVATION Material de la carte d'étude par défaut (**CR-IFFD-61 ②**).
  ///
  /// `null` ⇒ **0** (référence legacy IFFD : `Card(elevation: 0)`, liseré seul,
  /// AUCUNE ombre portée). Le défaut antérieur laissait l'élévation à `null`,
  /// donc au défaut Material 3 (**1.0**) — une ombre que la référence n'a pas.
  ///
  /// ⚠️ Sans effet quand une ombre de jetons `cardShadow*` est active : deux
  /// ombres ne se superposent jamais, l'élévation native cède alors la place
  /// (invariant CR-IFFD-27/57, inchangé).
  final double? studyCardElevation;

  /// Padding INTERNE de la carte d'étude par défaut.
  /// `null` ⇒ `EdgeInsetsDirectional.all(12)` (référence).
  final EdgeInsetsGeometry? studyCardContentPadding;

  /// Marge EXTERNE de la carte d'étude par défaut.
  /// `null` ⇒ `CardThemeData.margin` de l'hôte s'il est fourni, sinon
  /// `EdgeInsetsDirectional.all(4)` (référence) — la marge du `CardTheme`
  /// reste atteignable (leçon CR-LEX-73).
  final EdgeInsetsGeometry? studyCardMargin;

  /// Côté de la tuile d'icône de tête. `null` ⇒ 48 (référence).
  ///
  /// ⚠️ Token DISTINCT de [iconContainerSize] : celui-là a déjà un
  /// consommateur (`ZFolderCardGradientAccent`, repli `gapL`) — le détourner
  /// redimensionnerait la barre d'accent chez tout hôte l'ayant réglée (même
  /// arbitrage que CR-IFFD-27 côté `ZFolderCard`).
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
  /// `null` ⇒ 28 dp (référence legacy IFFD, `kStudyToolsLeadingIconSize`) —
  /// PAS la taille d'icône ambiante (24) : la référence est plus grande.
  final double? studyCardGlyphSize;

  /// ALIGNEMENT VERTICAL du contenu des cartes d'étude **par défaut**
  /// (**CR-IFFD-62 ④**), quand un cadre de hauteur leur est imposé.
  ///
  /// `null` ⇒ le consommateur applique sa valeur de RÉFÉRENCE
  /// ([ZStudyCardContentAlignment.spread] pour la carte de flashcard : énoncé
  /// extensible, pied poussé en bas — la cascade du legacy IFFD).
  ///
  /// ⚠️ **Sans hauteur imposée, ce jeton n'a AUCUN effet** : il n'y a pas
  /// d'espace libre à répartir (cf. la dartdoc de l'énumération).
  final ZStudyCardContentAlignment? studyCardContentAlignment;

  /// Dégradés **par TYPE de flashcard** de la carte de flashcard par défaut
  /// (**CR-IFFD-57**) — clé = `ZFlashcardType.name` OPAQUE (`'multipleChoice'`,
  /// `'trueOrFalse'`, `'openQuestion'`, `'exercise'`, ou toute clé future).
  ///
  /// `null` (défaut) ⇒ le consommateur applique sa **RÉFÉRENCE** (patron
  /// `studyCard*`/CR-IFFD-56 : priorité paramètre > ce jeton > seam
  /// `ZcrudScope.gradientResolver` > défaut-référence). Chaque entrée est un
  /// [ZGradientSpec] : le premier plan [ZGradientSpec.onGradient] est **CHOISI**
  /// par l'hôte (contraste mesuré), jamais deviné depuis le dégradé.
  ///
  /// ⚠️ Un dégradé n'est PAS un rôle de `ColorScheme` (CR-IFFD-57) : la matière
  /// reste REMPLAÇABLE (ce jeton) même quand elle ne peut pas être DÉRIVÉE.
  final Map<String, ZGradientSpec>? flashcardTypeGradients;

  // ── Carte de DOSSIER d'étude par défaut (CR-IFFD-64) ──────────────────────
  // La carte de dossier était la SEULE des six de la famille à n'avoir aucun
  // rendu par défaut, et son liseré n'était atteignable NI par paramètre NI par
  // jeton : la forme était bâtie sans `side:`, et les seuls jetons de carte
  // (`cardShadow*`) visaient l'OMBRE. Ces dix jetons répliquent, pour la
  // famille « carte de dossier », le patron déjà en place pour la famille sœur
  // (`studyCard*`) — ils n'en inventent pas un second.
  //
  // 🔴 Chacun est `null` par DÉFAUT, et `null` signifie « le consommateur
  // applique sa valeur de RÉFÉRENCE » (`ZFolderCardReference`) — jamais « rien
  // ne se rend ». Priorité, partout : paramètre de carte > ce jeton >
  // défaut-référence.

  /// Rayon de la carte de dossier. `null` ⇒ `CardThemeData.shape` de l'hôte
  /// s'il en pose un, sinon le jeton [radiusM] (défaut historique de la
  /// primitive) — la carte PAR DÉFAUT, elle, applique sa référence (12).
  final Radius? folderCardRadius;

  /// Liseré du pourtour de la carte de dossier — **le manque net de
  /// CR-IFFD-64**. `null` ⇒ aucune bordure imposée (rendu historique) ; la
  /// carte PAR DÉFAUT dérive le sien de la couleur du dossier, avec un
  /// plancher de contraste MESURÉ ([folderCardMinContrast]).
  final BorderSide? folderCardBorderSide;

  /// Padding interne de la carte de dossier. `null` ⇒ `gapM` (défaut
  /// historique de la primitive) ; référence de la carte par défaut : 12.
  ///
  /// ⚠️ Ce jeton existe parce que `gapM` vaut 8 en thème nu : sans lui, la
  /// carte par défaut ne pouvait atteindre sa référence qu'en ridant `gapM`
  /// pour TOUT le sous-arbre (défaut corrigé par CR-IFFD-61 ① ailleurs).
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
  /// 🔴 **Ce jeton n'est pas un réglage cosmétique** : une couleur de dossier
  /// est choisie par l'utilisateur, donc ARBITRAIRE, et aucune fenêtre de
  /// clarté HSL ne borne son contraste (mesuré : `#FFFF00` rendait 2.13:1 sur
  /// thème clair, `#FFFFFE` 1.28:1). Le relever à 4.5 aligne la carte sur le
  /// plancher du TEXTE normal ; l'abaisser sous 3.0 sort de WCAG AA.
  final double? folderCardMinContrast;

  /// DISPOSITION du bas de carte — compteur et pied côte à côte, empilés, ou
  /// adaptatif (**CR-IFFD-68**). `null` ⇒ le consommateur applique SA
  /// référence : la primitive `ZFolderCard` reste sur
  /// [ZFolderCardFooterPlacement.beside] (rendu historique, aucun hôte passif
  /// ne bouge), `ZDefaultFolderCard` applique
  /// `ZFolderCardReference.footerPlacement`.
  ///
  /// 🔴 Ce jeton ne dit pas QUOI rendre, il dit OÙ : les deux créneaux restent
  /// rendus par la carte dans les trois valeurs, donc le plancher de contraste
  /// des badges de `ZDefaultFolderCard` tient dans toutes.
  final ZFolderCardFooterPlacement? folderCardFooterPlacement;

  /// Seuil de largeur (dp) au-delà duquel [ZFolderCardFooterPlacement.adaptive]
  /// bascule sur le côte-à-côte, mesuré sur la largeur RÉELLEMENT offerte au
  /// bas de carte (padding interne déjà retranché). `null` ⇒ référence.
  ///
  /// 🔴 **DISCRET comme un plancher** : un point de rupture interpolé pendant
  /// une transition de thème est un point de rupture que personne n'a choisi —
  /// et il ferait basculer la mise en page au milieu de l'animation.
  final double? folderCardFooterBesideMinWidth;

  // ── Hub d'ajout de CONTENU (CR-IFFD-65) ───────────────────────────────────
  // Aucun jeton `contentHub*` n'existait : la forme du hub n'était atteignable
  // NI par paramètre NI par thème (grief ④ de la CR, MESURÉ). La seule voie
  // ouverte à un hôte était d'envelopper la feuille dans un `Theme` écrasant
  // `ListTileTheme` pour TOUT le sous-arbre — donc de changer l'ambiance d'un
  // écran pour atteindre une carte.
  //
  // 🔴 Chacun est `null` par DÉFAUT, et `null` signifie « le consommateur
  // applique sa valeur de RÉFÉRENCE » (`ZContentHubReference`) — jamais « rien
  // ne se rend ». Priorité, partout : paramètre de feuille/entrée > ce jeton >
  // défaut-référence.

  /// Densité du hub. `null` ⇒ référence ([ZContentHubDensity.comfortable] —
  /// le rendu legacy, défaut depuis CR-IFFD-65).
  ///
  /// 🔴 C'est le jeton qui **restitue la densité d'avant CR-IFFD-65**
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
  /// (**0** — carte NEUTRE : mesuré sur pièces, le legacy ne teinte PAS le fond
  /// de la carte, seulement la pastille et le badge).
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

  /// Teinte du badge de mise en avant. `null` ⇒ référence (le vert du legacy).
  final Color? contentHubBadgeColor;

  /// Largeur à partir de laquelle le hub passe en grille. `null` ⇒ référence
  /// (**600** — mesuré dans le legacy, que la CR déclarait « non mesuré »).
  final double? contentHubGridBreakpoint;

  /// Nombre de colonnes au-delà de [contentHubGridBreakpoint]. `null` ⇒
  /// référence (2). `1` ⇒ colonne unique à toute largeur.
  final int? contentHubGridCrossAxisCount;

  /// Plancher de contraste (WCAG 2.x) imposé aux teintes d'identité peintes —
  /// pastille, glyphe. `null` ⇒ référence (**3.0:1**, §1.4.11).
  ///
  /// 🔴 Le legacy n'en a **aucun** : il peint la teinte brute et n'a **aucune**
  /// branche de luminosité (recherche négative sur son fichier). Une teinte
  /// d'entrée pouvant être injectée par l'hôte, elle est arbitraire.
  final double? contentHubMinContrast;

  /// Style des intitulés de SECTION du hub. `null` ⇒ `titleMedium` du thème,
  /// à la graisse de référence (`w600`) — jamais une taille en dur.
  final TextStyle? contentHubSectionTitleStyle;

  // ── Typographie de l'EN-TÊTE DE PAGE (CR-IFFD-63) ─────────────────────────
  // L'en-tête de page était le seul endroit de l'écran dont la hiérarchie
  // typographique n'était atteignable NI par paramètre NI par thème : le titre
  // retombait sur `AppBarTheme.titleTextStyle` et les onglets sur le défaut M3,
  // sans qu'aucun jeton ne les vise. Un hôte n'avait qu'un recours — envelopper
  // la page dans un `Theme` réécrivant `AppBarTheme`/`TabBarTheme`, donc
  // changer l'ambiance de tout un sous-arbre pour atteindre deux textes.
  //
  // 🔴 **Ces quatre jetons ne portent que des MÉTRIQUES.** Le consommateur
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

  /// Style du TITRE de l'en-tête de page (**CR-IFFD-63**), consommé par
  /// `ZPageScaffold`/`ZSearchableAppBar`/`ZPageShellBody` de `zcrud_ui_kit`.
  ///
  /// `null` ⇒ le titre garde le style de l'app-bar de l'hôte
  /// (`AppBarTheme.titleTextStyle`, repli `TextTheme.titleLarge`) — rendu
  /// **strictement inchangé**. Non-null ⇒ ses **métriques** sont fusionnées
  /// par-dessus (la couleur est ignorée, cf. l'encadré ci-dessus).
  ///
  /// ⚠️ Le paramètre `titleTextStyle` du widget **prime** sur ce jeton.
  final TextStyle? pageHeaderTitleStyle;

  /// Style du SOUS-TITRE de l'en-tête de page (**CR-IFFD-63**).
  ///
  /// `null` ⇒ repli historique du consommateur (métriques de
  /// `TextTheme.titleSmall`) — rendu **strictement inchangé**. Sans objet quand
  /// aucun sous-titre n'est fourni (le slot reste absent de l'arbre).
  final TextStyle? pageHeaderSubtitleStyle;

  /// Style du libellé d'onglet **SÉLECTIONNÉ** de l'en-tête de page
  /// (**CR-IFFD-63**) — le troisième canal de distinction, à côté de la couleur
  /// et de l'indicateur.
  ///
  /// `null` ⇒ défaut Material 3 (`TextTheme.titleSmall`) — rendu **strictement
  /// inchangé**.
  ///
  /// ⚠️ Régler CE jeton seul ne touche QUE l'onglet sélectionné : le
  /// consommateur neutralise explicitement la retombée de `TabBar`
  /// (`unselectedLabelStyle ?? labelStyle`) qui, sans cela, appliquerait le
  /// style sélectionné aux onglets non sélectionnés — donc annulerait la
  /// distinction qu'on vient de demander.
  final TextStyle? pageHeaderTabSelectedLabelStyle;

  /// Style du libellé d'onglet **NON SÉLECTIONNÉ** de l'en-tête de page
  /// (**CR-IFFD-63**). `null` ⇒ défaut Material 3 — rendu **strictement
  /// inchangé**.
  final TextStyle? pageHeaderTabUnselectedLabelStyle;

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
      // CR-IFFD-60 — fill/border DISCRETS (aucun rôle intermédiaire n'existe) :
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
      // CR-IFFD-46, point 4 — même nature que `subfolderBarPadding` : marge
      // CONTINUE qui s'interpole, `null` des DEUX côtés RESTE `null` (sans quoi
      // « aucune enveloppe dans l'arbre » serait GELÉ à la première transition
      // de thème).
      subfolderSheetPadding: _lerpNullableInsets(
        subfolderSheetPadding,
        other.subfolderSheetPadding,
        t,
      ),
      // CR-IFFD-46, point 2 — token DISCRET (aucun alignement intermédiaire
      // n'existe entre `start` et `center`) : bascule au point milieu, même
      // invariant de `null` que les tokens discrets ci-dessus.
      subfolderSheetTitleAlign: t < 0.5
          ? subfolderSheetTitleAlign
          : other.subfolderSheetTitleAlign,
      // CR-IFFD-49 — largeur CONTINUE : elle s'interpole. `null` des DEUX
      // côtés RESTE `null` (même invariant que `accentBarHeight`) —
      // matérialiser une valeur ici GÈLERAIT le défaut du consommateur à la
      // première transition de thème.
      railItemWidth: _lerpNullableDouble(railItemWidth, other.railItemWidth, t),
      // CR-IFFD-62 ① — MÊME invariant : `null` des DEUX côtés reste `null`
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
      // CR-IFFD-50 ① — style CONTINU : `TextStyle.lerp` rend déjà `null` quand
      // les DEUX côtés sont `null` (même invariant que `labelTextStyle`) — le
      // repli du consommateur (`labelTextStyle` puis `titleMedium`) n'est
      // jamais GELÉ par une transition de thème.
      studySectionTitleStyle: TextStyle.lerp(
        studySectionTitleStyle,
        other.studySectionTitleStyle,
        t,
      ),
      // CR-IFFD-50 ②/④ — tokens DISCRETS (aucune forme/rôle/placement
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
      // CR-IFFD-61 ④ — discret ⇒ bascule au point milieu ; continu ⇒
      // interpolation null-préservante.
      studySectionCountPlacement: t < 0.5
          ? studySectionCountPlacement
          : other.studySectionCountPlacement,
      studySectionCountGap: _lerpNullableDouble(
        studySectionCountGap,
        other.studySectionCountGap,
        t,
      ),
      // CR-IFFD-61 ③ — gouttière interne de la feuille de fratrie.
      subfolderSheetContentPadding: _lerpNullableInsets(
        subfolderSheetContentPadding,
        other.subfolderSheetContentPadding,
        t,
      ),
      // CR-IFFD-56 — tokens des cartes d'étude par défaut. Même invariant que
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
      // CR-IFFD-61 ①/② — écart tuile→titre et élévation des cartes par défaut.
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
      // CR-IFFD-57 — DISCRET (une map de specs ne s'interpole pas) et
      // null-préservant PAR CONSTRUCTION : `null`↔`null` reste `null` — la
      // référence du consommateur n'est jamais matérialisée par une
      // transition de thème (leçon `studyCardBadgeRadius`).
      // CR-IFFD-62 ④ — token DISCRET (un alignement ne s'interpole pas) et
      // null-préservant PAR CONSTRUCTION : `null`↔`null` reste `null`.
      studyCardContentAlignment: t < 0.5
          ? studyCardContentAlignment
          : other.studyCardContentAlignment,
      flashcardTypeGradients:
          t < 0.5 ? flashcardTypeGradients : other.flashcardTypeGradients,
      // CR-IFFD-64 — chaque jeton de carte de dossier est null-PRÉSERVANT :
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
      // CR-IFFD-68 — une DISPOSITION et un POINT DE RUPTURE sont discrets : ni
      // demi-empilement, ni seuil intermédiaire (qui ferait basculer la mise en
      // page au milieu d'une transition de thème).
      folderCardFooterPlacement: t < 0.5
          ? folderCardFooterPlacement
          : other.folderCardFooterPlacement,
      folderCardFooterBesideMinWidth: t < 0.5
          ? folderCardFooterBesideMinWidth
          : other.folderCardFooterBesideMinWidth,
      // CR-IFFD-65 — chaque jeton de hub est null-PRÉSERVANT : `null`↔`null`
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
      // CR-IFFD-63 — `TextStyle.lerp` est null-préservant : `null`↔`null` rend
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

/// Interpolation d'une marge NULLABLE **directionnelle-compatible**.
///
/// ⚠️ `EdgeInsetsGeometry.lerp` préserve la nature des deux bornes (un
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
