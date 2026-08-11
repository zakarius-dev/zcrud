/// **Apparence de référence** du déclencheur de sélection — métriques
/// auditées + surcharge par paramètre.
///
/// ## Structure de référence
///
/// Le déclencheur est une carte à bordure douce (rayon 12, élévation 0,
/// bordure fine) contenant une tuile de liste : titre = libellé du champ,
/// `trailing` = chevron (sauf lecture seule), et un sous-titre qui affiche
/// soit un placeholder (état vide), soit la valeur/les puces sélectionnées.
/// Rien n'est sélectionné en lecture seule ⇒ le déclencheur entier disparaît
/// de l'arbre plutôt que de rendre une coquille vide.
///
/// ## Correspondance gris → RÔLES `ColorScheme`
///
/// Ce fichier reprend une structure de référence éprouvée sans imposer de
/// palette : chaque teinte est un **rôle** Material 3, jamais un littéral :
///
/// | Usage                                   | Rôle retenu                        | Pourquoi |
/// |-----------------------------------------|------------------------------------|----------|
/// | bordure de la carte                     | `ColorScheme.outlineVariant`       | rôle « bordure douce, décorative » de M3 ; c'est **exactement** ce que peint `Card.outlined` (`_OutlinedCardDefaultsM3`), déjà le choix du socle dans `zcrud_navigation/z_sheet_frame.dart` |
/// | fond de puce (clair/sombre)             | `ColorScheme.surfaceContainerHighest` | la **surface tonale la plus haute** : le rôle absorbe l'alternance clair/sombre au lieu de la coder en dur |
/// | texte de puce                           | `ColorScheme.onSurface`            | rôle « texte principal sur une surface » — l'appairage M3 de `surfaceContainerHighest` |
/// | placeholder (état vide)                 | `ColorScheme.onSurfaceVariant`     | rôle « texte secondaire / atténué » ; c'est aussi ce que M3 donne au `subtitle` d'un `ListTile` |
/// | valeur mono renseignée                  | `ColorScheme.onSurface`            | texte principal |
/// | sous-titre d'option (modal)             | `ColorScheme.onSurfaceVariant`     | texte secondaire |
/// | option active (modal)                   | `ColorScheme.primary`              | rôle d'accentuation |
/// | en-tête de modal (fond translucide)     | `ColorScheme.surface` @ 0,7        | même intention (fond d'écran translucide), exprimée en rôle |
///
/// Conséquence assumée : sur un thème dont le `ColorScheme` s'écarte de la
/// palette grise de référence, le rendu **suit le thème de l'hôte** — c'est
/// un arbitrage délibéré, pas un écart de fidélité.
///
/// ## Défauts délibérément non reproduits
///
/// Une intégration ad hoc typique de ce composant tend à accumuler des
/// défauts que ce présentateur évite délibérément :
///
/// 1. **Un champ de validation fantôme empilé derrière le déclencheur**, monté
///    au seul motif de porter un validateur et d'afficher son message
///    d'erreur — un détournement : un champ invisible, non interactif, non
///    annoncé, qui gagne le focus au clavier et double la source de vérité.
///    Dans zcrud la validation appartient au `ZFormController` (invariant
///    AD-2) et le présentateur ne la touche **jamais** — il n'y a donc rien à
///    empiler.
/// 2. **Cibles sous 48 dp.** Un sous-titre vide et un `contentPadding`
///    vertical réduit descendent facilement sous le plancher tactile
///    (invariant AD-13) ; ici [minTileHeight] le garantit explicitement.
/// 3. **Couleurs codées en dur** — cf. la table ci-dessus.
/// 4. **État porté par la seule couleur.** « Vide » vs « renseigné » ne
///    devrait jamais se distinguer que par une nuance de gris, ni « lecture
///    seule » que par la seule disparition d'un chevron. Ici l'information
///    passe **aussi** par la sémantique (`Semantics.value` renseignée
///    seulement quand il y a une valeur, `Semantics.enabled` pour la lecture
///    seule) et par un **texte** distinct (le placeholder l10n).
/// 5. **Une liste encodée dans une chaîne par un séparateur sentinelle**, puis
///    re-parsée à la lecture. Le présentateur notifie une **vraie `List`**
///    (invariant AD-2).
/// 6. **Un rebuild global temporisé** après chaque changement — exactement le
///    défaut que l'objectif produit n°1 du dépôt corrige. Le présentateur ne
///    reconstruit rien : il notifie la tranche.
///
/// ## Chaîne de résolution
///
/// **paramètre ([ZSelectTileSpec]) > jeton `ZcrudTheme.select*` > référence
/// ([ZSelectTileReference])**. Huit jetons `ZcrudTheme.select*` sont posés
/// dans `zcrud_core` et la chaîne est résolue en un seul endroit,
/// `zSelectTileMetricsOf` (`z_select_tile_metrics.dart`).
///
/// Seules huit métriques ont un jeton dédié : les autres candidats ont été
/// **écartés** sur le critère du dépôt — *un jeton se justifie s'il porte une
/// décision à l'échelle de l'application* — parce qu'ils dupliqueraient un
/// canal que le SDK possède déjà (`ThemeData.chipTheme`, `TextTheme`,
/// `ThemeData.hintColor`, `CardThemeData.elevation`) ou qu'ils décrivent une
/// micro-métrique d'un seul widget. Ils restent **intégralement atteignables**
/// par [ZSelectTileSpec] : rien n'est perdu, seule la surface publique
/// perpétuelle l'est.
///
/// Aucune `ThemeExtension` locale n'est créée : ce dépôt s'interdit le second
/// canal pour la même propriété.
///
/// ## Invariants
///
/// * **Aucune couleur codée en dur** dans ce fichier — que des dimensions.
///   Les teintes sont résolues au rendu sur des **rôles**.
/// * **Confinement du tiers** : aucun type `awesome_select` / `S2*` ici ni en
///   signature publique — [ZSelectChoiceStyle] est un enum **local**, traduit
///   en `S2*` dans le seul `z_smart_select_presenter.dart`.
/// * **Invariant AD-13** : [minTileHeight] ≥ 48 ; insets **directionnels** au
///   rendu.
/// * **Invariant AD-10** : aucun champ ne peut faire lever d'exception ; un
///   `null` signifie « je ne me prononce pas » et le maillon suivant décide.
/// * **Invariant AD-1** : aucune arête de paquet ajoutée (Flutter vanilla
///   uniquement).
library;

import 'package:flutter/widgets.dart';

/// Forme des options **dans le modal** — enum **local** (le type `S2*`
/// correspondant ne franchit jamais la frontière publique).
enum ZSelectChoiceStyle {
  /// Boutons radio — **défaut mono** de référence.
  radios,

  /// Cases à cocher.
  checkboxes,

  /// Interrupteurs — **défaut multi** de référence.
  switches,

  /// Puces (`chips`).
  ///
  /// Le style reste **atteignable** par ce paquet, mais n'est jamais deviné
  /// automatiquement à partir du nom d'un champ — un aiguillage par nom de
  /// champ serait propre à un modèle de données précis, sans aucun sens dans
  /// un socle générique.
  chips,
}

/// Forme du **conteneur** du modal.
enum ZSelectModalShape {
  /// Feuille par le bas — le défaut mobile de référence.
  bottomSheet,

  /// Boîte de dialogue — le rendu de référence sur web/desktop.
  popupDialog,

  /// Page pleine.
  fullPage,

  /// Choisit [popupDialog] au-delà de [ZSelectTileReference.dialogBreakpoint]
  /// de largeur utile, [bottomSheet] en deçà — **défaut**.
  ///
  /// C'est un substitut **mesurable** à un détecteur de plateforme : le socle
  /// ne peut pas dépendre d'un tel détecteur (aucune arête de paquet,
  /// invariant AD-1), et la largeur utile est de toute façon le critère
  /// *utile* — un navigateur en fenêtre étroite mérite la feuille, pas une
  /// boîte de dialogue étroite.
  adaptive,
}

/// Les **valeurs de référence** du déclencheur de sélection — point d'audit
/// unique.
///
/// **AUCUNE COULEUR ici** : uniquement des dimensions.
abstract final class ZSelectTileReference {
  /// Rayon du `Card` du déclencheur (dp).
  static const double cardRadius = 12;

  /// Élévation du `Card` — `0` (le relief vient de la bordure, pas de l'ombre).
  static const double cardElevation = 0;

  /// Épaisseur de la bordure (dp) — la valeur par défaut de `BorderSide`.
  static const double borderWidth = 1;

  /// Écart horizontal entre deux puces.
  static const double chipSpacing = 6;

  /// Écart vertical entre deux rangées de puces.
  static const double chipRunSpacing = 4;

  /// Taille du texte d'une puce (pt).
  static const double chipFontSize = 12;

  /// Taille du texte de la valeur en **mono** (pt).
  ///
  /// La référence ne fixe aucune taille sur le sous-titre du multi (les
  /// puces portent la leur) : cette métrique ne vaut que pour la branche
  /// mono.
  static const double monoValueFontSize = 15;

  /// Écart (dp) entre un ornement `prefix`/`suffix` et le contenu du
  /// sous-titre.
  ///
  /// La valeur reprend celle que Material applique entre le `prefix`/`suffix`
  /// et le texte d'un `InputDecorator` (4 dp de `gap` horizontal) — c'est le
  /// rendu NATIF que l'enrôlement doit conserver, pas une invention de style.
  static const double ornamentGap = 4;

  /// Marge intérieure horizontale du `ListTile` (dp).
  static const double contentPaddingHorizontal = 16;

  /// Marge intérieure verticale du `ListTile` (dp).
  static const double contentPaddingVertical = 8;

  /// Plancher de hauteur du déclencheur (dp).
  ///
  /// C'est le plancher tactile (invariant AD-13), nécessaire car une tuile
  /// à sous-titre vide et un `contentPadding` réduit peuvent naturellement
  /// descendre en dessous.
  static const double minTileHeight = 48;

  /// Largeur utile (dp) au-delà de laquelle [ZSelectModalShape.adaptive] bascule
  /// en boîte de dialogue.
  ///
  /// 600 dp est le palier `medium` de Material 3 (`WindowWidthSizeClass`) — le
  /// même que le SDK emploie pour distinguer téléphone et tablette.
  static const double dialogBreakpoint = 600;

  /// Opacité du fond de l'en-tête de modal.
  static const double modalHeaderOpacity = 0.7;

  /// Élévation de l'en-tête de modal.
  static const double modalHeaderElevation = 3;

  /// Nombre d'options chargées par page dans le modal.
  static const int choicePageLimit = 20;

  /// Délai au-delà duquel un [ZSelectOptionsLoader] qui **ne se termine pas**
  /// est abandonné au profit du rendu dégradé (liste vide) — invariant AD-10.
  ///
  /// Sans ce plancher, une source distante silencieuse laisserait le modal en
  /// attente **définitive**.
  ///
  /// 30 s : assez long pour un réseau lent, assez court pour qu'un utilisateur
  /// obtienne un état vide explicite plutôt qu'un indicateur perpétuel.
  static const Duration optionsLoadTimeout = Duration(seconds: 30);

  /// Forme des options en **mono** — `radios` (défaut de référence hors web).
  static const ZSelectChoiceStyle monoChoiceStyle = ZSelectChoiceStyle.radios;

  /// Forme des options en **multi** — `switches`.
  ///
  /// Reste surchargeable ([ZSelectTileSpec.multiChoiceStyle]) pour un hôte
  /// qui préfère des cases à cocher.
  static const ZSelectChoiceStyle multiChoiceStyle = ZSelectChoiceStyle.switches;

  /// Forme du conteneur de modal — [ZSelectModalShape.adaptive] (dialogue sur
  /// grand écran, feuille sinon), sans détecteur de plateforme.
  static const ZSelectModalShape modalShape = ZSelectModalShape.adaptive;
}

/// **Surcharge par paramètre** (priorité la plus haute) de l'apparence du
/// déclencheur et du modal.
///
/// Chaque champ `null` ⇒ « je ne me prononce pas », et le maillon suivant de la
/// chaîne décide (jeton — *trou documenté* —, puis référence). Un
/// `ZSelectTileSpec()` vide est donc rigoureusement équivalent à `null` (AD-4).
@immutable
class ZSelectTileSpec {
  /// Construit une surcharge **partielle** de l'apparence de référence.
  const ZSelectTileSpec({
    this.borderColor,
    this.borderWidth,
    this.cardRadius,
    this.cardElevation,
    this.cardColor,
    this.chipBackgroundColor,
    this.chipForegroundColor,
    this.chipFontSize,
    this.chipSpacing,
    this.chipRunSpacing,
    this.placeholderColor,
    this.valueColor,
    this.contentPadding,
    this.minTileHeight,
    this.monoChoiceStyle,
    this.multiChoiceStyle,
    this.modalShape,
    this.dialogBreakpoint,
    this.choicePageLimit,
    this.showTrailingChevron,
    this.showModalActions,
  });

  /// Teinte de la bordure. `null` ⇒ **rôle** `ColorScheme.outlineVariant`.
  final Color? borderColor;

  /// Épaisseur de la bordure (dp). `null` ⇒ [ZSelectTileReference.borderWidth].
  final double? borderWidth;

  /// Rayon du `Card` (dp). `null` ⇒ [ZSelectTileReference.cardRadius].
  final double? cardRadius;

  /// Élévation du `Card`. `null` ⇒ [ZSelectTileReference.cardElevation].
  final double? cardElevation;

  /// Fond du `Card`. `null` ⇒ le fond de carte du thème ambiant.
  final Color? cardColor;

  /// Fond d'une puce (multi). `null` ⇒ **rôle**
  /// `ColorScheme.surfaceContainerHighest`.
  final Color? chipBackgroundColor;

  /// Texte d'une puce (multi). `null` ⇒ **rôle** `ColorScheme.onSurface`.
  final Color? chipForegroundColor;

  /// Taille du texte d'une puce (pt). `null` ⇒
  /// [ZSelectTileReference.chipFontSize].
  final double? chipFontSize;

  /// Écart horizontal entre puces. `null` ⇒ [ZSelectTileReference.chipSpacing].
  final double? chipSpacing;

  /// Écart vertical entre rangées de puces. `null` ⇒
  /// [ZSelectTileReference.chipRunSpacing].
  final double? chipRunSpacing;

  /// Teinte du placeholder (état vide). `null` ⇒ **rôle**
  /// `ColorScheme.onSurfaceVariant`.
  final Color? placeholderColor;

  /// Teinte de la valeur renseignée (mono). `null` ⇒ **rôle**
  /// `ColorScheme.onSurface`.
  final Color? valueColor;

  /// Marge intérieure du `ListTile`. **Directionnelle** attendue
  /// (`EdgeInsetsDirectional`) — AD-13. `null` ⇒ référence (16 / 8).
  final EdgeInsetsGeometry? contentPadding;

  /// Plancher de hauteur du déclencheur (dp).
  ///
  /// Une valeur **inférieure à 48** violerait l'invariant AD-13 ; le
  /// présentateur ne la refuse pas (invariant AD-10 : jamais d'exception)
  /// mais **ne descend jamais sous [ZSelectTileReference.minTileHeight]** —
  /// la surcharge ne peut que *rehausser* le plancher.
  final double? minTileHeight;

  /// Forme des options en mono. `null` ⇒
  /// [ZSelectTileReference.monoChoiceStyle].
  final ZSelectChoiceStyle? monoChoiceStyle;

  /// Forme des options en multi. `null` ⇒
  /// [ZSelectTileReference.multiChoiceStyle].
  final ZSelectChoiceStyle? multiChoiceStyle;

  /// Forme du conteneur de modal. `null` ⇒ [ZSelectTileReference.modalShape].
  final ZSelectModalShape? modalShape;

  /// Largeur de bascule de [ZSelectModalShape.adaptive] (dp). `null` ⇒
  /// [ZSelectTileReference.dialogBreakpoint].
  final double? dialogBreakpoint;

  /// Options chargées par page. `null` ⇒
  /// [ZSelectTileReference.choicePageLimit].
  final int? choicePageLimit;

  /// Affiche le chevron de fin de ligne. `null` ⇒ règle de référence : **oui,
  /// sauf en lecture seule**. Une valeur explicite l'impose dans les deux cas.
  final bool? showTrailingChevron;

  /// Rend la **barre d'actions du modal** (créer / confirmer / réinitialiser /
  /// rechercher). `null` ⇒ **oui**, c'est la référence.
  ///
  /// `false` rend la main aux seules actions par défaut du fork (bascule de
  /// recherche + bouton de confirmation quand `useConfirm` est actif) — utile
  /// à un hôte dont la barre d'actions ne fait pas partie de son langage
  /// d'interface.
  final bool? showModalActions;

  /// Copie modifiée (AD-4 : extension par composition).
  ZSelectTileSpec copyWith({
    Color? borderColor,
    double? borderWidth,
    double? cardRadius,
    double? cardElevation,
    Color? cardColor,
    Color? chipBackgroundColor,
    Color? chipForegroundColor,
    double? chipFontSize,
    double? chipSpacing,
    double? chipRunSpacing,
    Color? placeholderColor,
    Color? valueColor,
    EdgeInsetsGeometry? contentPadding,
    double? minTileHeight,
    ZSelectChoiceStyle? monoChoiceStyle,
    ZSelectChoiceStyle? multiChoiceStyle,
    ZSelectModalShape? modalShape,
    double? dialogBreakpoint,
    int? choicePageLimit,
    bool? showTrailingChevron,
    bool? showModalActions,
  }) =>
      ZSelectTileSpec(
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        cardRadius: cardRadius ?? this.cardRadius,
        cardElevation: cardElevation ?? this.cardElevation,
        cardColor: cardColor ?? this.cardColor,
        chipBackgroundColor: chipBackgroundColor ?? this.chipBackgroundColor,
        chipForegroundColor: chipForegroundColor ?? this.chipForegroundColor,
        chipFontSize: chipFontSize ?? this.chipFontSize,
        chipSpacing: chipSpacing ?? this.chipSpacing,
        chipRunSpacing: chipRunSpacing ?? this.chipRunSpacing,
        placeholderColor: placeholderColor ?? this.placeholderColor,
        valueColor: valueColor ?? this.valueColor,
        contentPadding: contentPadding ?? this.contentPadding,
        minTileHeight: minTileHeight ?? this.minTileHeight,
        monoChoiceStyle: monoChoiceStyle ?? this.monoChoiceStyle,
        multiChoiceStyle: multiChoiceStyle ?? this.multiChoiceStyle,
        modalShape: modalShape ?? this.modalShape,
        dialogBreakpoint: dialogBreakpoint ?? this.dialogBreakpoint,
        choicePageLimit: choicePageLimit ?? this.choicePageLimit,
        showTrailingChevron: showTrailingChevron ?? this.showTrailingChevron,
        showModalActions: showModalActions ?? this.showModalActions,
      );
}
