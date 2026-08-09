/// **Apparence de référence DODLP** du déclencheur de sélection (CR-SELECT-FID,
/// 2026-08-09) — métriques auditées + surcharge par paramètre.
///
/// ## Ce que fait réellement DODLP legacy (mesuré, pas cru)
///
/// `dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart`,
/// `_buildSmartSelect` (l. ~2833) — deux `tileBuilder`, **multi** (l. ~2899) et
/// **mono** (l. ~3064), rigoureusement de même structure :
///
/// ```dart
/// Card(
///   elevation: 0,
///   shape: RoundedRectangleBorder(
///     borderRadius: BorderRadius.circular(12),
///     side: BorderSide(color: Colors.grey.shade300),   // ← épaisseur par défaut : 1
///   ),
///   child: Stack(children: [
///     if (rienDeSélectionné) FormBuilder…(options: []),  // ← DÉFAUT, cf. plus bas
///     ListTile(
///       title:    _buildLabelWidget(),                   // libellé du champ
///       trailing: readOnly ? null : Icon(Icons.chevron_right),
///       subtitle: vide
///           ? Text(placeholder, style: TextStyle(color: Colors.grey.shade400))
///           : Wrap(spacing: 6, runSpacing: 4, children: chips)   // MULTI
///           // MONO : Text(title, fontSize: 15,
///           //   color: vide ? grey.shade400 : (isDark ? white70 : black87))
///       onTap: field.choiceBuilder == null && (readOnly || isLoading)
///           ? null : state.showModal,
///       leading: field.leading,
///       // MONO uniquement : contentPadding EdgeInsets.symmetric(h: 16, v: 8)
///     ),
///   ]),
/// )
/// ```
///
/// Puce du multi :
/// `Chip(label: Text(t, style: TextStyle(fontSize: 12)), backgroundColor:
/// isDark ? kNavyColor : Colors.grey.shade200, labelStyle: TextStyle(color:
/// isDark ? Colors.white : Colors.black87))`.
///
/// Et, quand **rien n'est sélectionné en lecture seule**, le tile entier est
/// remplacé par `const EmptyContainer()` (leur `SizedBox.shrink`).
///
/// ## 🔴 Correspondance GRIS → RÔLES `ColorScheme` (FR-26)
///
/// Le propriétaire a tranché : **on n'impose pas les couleurs**. Les métriques
/// de DODLP sont reprises **à l'identique** ; leurs gris sont traduits en
/// **rôles Material 3**, jamais en littéraux :
///
/// | DODLP (littéral)                        | Rôle retenu ici                    | Pourquoi |
/// |-----------------------------------------|------------------------------------|----------|
/// | `Colors.grey.shade300` (bordure Card)   | `ColorScheme.outlineVariant`       | rôle « bordure douce, décorative » de M3 ; c'est **exactement** ce que peint `Card.outlined` (`_OutlinedCardDefaultsM3`), déjà le choix du socle dans `zcrud_navigation/z_sheet_frame.dart` |
/// | `grey.shade200` / `kNavyColor` (fond de puce, clair/sombre) | `ColorScheme.surfaceContainerHighest` | c'est la **surface tonale la plus haute** : gris clair sur un schéma clair, teinte sombre sur un schéma sombre — le rôle absorbe donc le ternaire `isDark` de DODLP, au lieu de le recopier |
/// | `Colors.black87` / `Colors.white` (texte de puce) | `ColorScheme.onSurface`     | rôle « texte principal sur une surface » — l'appairage M3 de `surfaceContainerHighest` |
/// | `Colors.grey.shade400` (placeholder)    | `ColorScheme.onSurfaceVariant`     | rôle « texte secondaire / atténué » ; c'est aussi ce que M3 donne au `subtitle` d'un `ListTile` |
/// | `Colors.white70` / `black87` (valeur mono renseignée) | `ColorScheme.onSurface` | texte principal |
/// | `Colors.grey` italique (sous-titre d'option, modal) | `ColorScheme.onSurfaceVariant` | texte secondaire |
/// | `Colors.blueAccent` (option active, modal) | `ColorScheme.primary`           | rôle d'accentuation |
/// | `theme.scaffoldBackgroundColor.withValues(alpha: .7)` (en-tête de modal) | `ColorScheme.surface` @ .7 | même intention (fond d'écran translucide), exprimée en rôle |
///
/// ⚠️ Conséquence assumée : sur un thème dont le `ColorScheme` s'écarte des
/// gris de DODLP, le rendu **suit le thème de l'hôte** — c'est l'arbitrage du
/// propriétaire, pas un écart de fidélité.
///
/// ## 🔴 Quatre défauts du legacy DÉLIBÉRÉMENT non reproduits
///
/// 1. **Le `Stack` + `FormBuilderCheckboxGroup` / `FormBuilderChoiceChips` à
///    `options: []`.** DODLP empile, *derrière* le `ListTile*, un champ de
///    formulaire **sans aucune option**, monté au seul motif de porter un
///    `validator` (`FormBuilderValidators.compose(_validators)`) et d'afficher
///    son `errorText`. C'est un détournement : un champ invisible, non
///    interactif, non annoncé, qui gagne le focus au clavier et dont
///    l'`initialValue` double la source de vérité. Dans zcrud la validation
///    appartient au `ZFormController` (AD-2) et le présentateur ne la touche
///    **jamais** — il n'y a donc rien à empiler.
/// 2. **Cibles sous 48 dp.** Un `ListTile` à sous-titre vide et
///    `contentPadding` vertical 8 descend sous le plancher AD-13 ; ici
///    [minTileHeight] le garantit explicitement.
/// 3. **Couleurs codées en dur** — cf. la table ci-dessus.
/// 4. **État porté par la seule couleur.** Chez DODLP, « vide » vs « renseigné »
///    ne se distingue que par la nuance de gris du sous-titre, et
///    « lecture seule » que par la disparition du chevron. Ici l'information
///    passe **aussi** par la sémantique (`Semantics.value` renseignée seulement
///    quand il y a une valeur, `Semantics.enabled` pour la lecture seule) et
///    par un **texte** distinct (le placeholder l10n).
///
/// Deux autres, trouvés en chemin et écartés pour la même raison :
///
/// 5. **`fieldController.text = value.join("S2Choice")`** — une liste encodée
///    dans une chaîne par un séparateur sentinelle, puis re-`split` à la
///    lecture. Le présentateur notifie une **vraie `List`** (AD-2).
/// 6. **`Future.delayed(300ms, () => setState(() {}))`** après chaque
///    changement — le rebuild global du formulaire, c'est-à-dire l'objectif
///    produit n°1 du dépôt. Le présentateur ne reconstruit rien : il notifie
///    la tranche (SM-1).
///
/// ## Chaîne de résolution
///
/// **paramètre ([ZSelectTileSpec]) > jeton `ZcrudTheme.select*` > référence
/// ([ZSelectTileReference])**.
///
/// ✅ **Le maillon « jeton » EXISTE depuis CR-SELECT-SEAM (2026-08-09)** : huit
/// jetons `ZcrudTheme.select*` ont été posés dans `zcrud_core` et la chaîne est
/// résolue en un seul endroit, `zSelectTileMetricsOf`
/// (`z_select_tile_metrics.dart`).
///
/// 🔴 **Huit, pas quinze.** Les sept candidats restants ont été **écartés** sur
/// le critère du dépôt — *un jeton se justifie s'il porte une décision à
/// l'échelle de l'application* — parce qu'ils dupliqueraient un canal que le SDK
/// possède déjà (`ThemeData.chipTheme`, `TextTheme`, `ThemeData.hintColor`,
/// `CardThemeData.elevation`) ou qu'ils décrivent une micro-métrique d'un seul
/// widget. Ils restent **intégralement atteignables** par [ZSelectTileSpec] :
/// rien n'est perdu, seule la surface publique perpétuelle l'est. Le détail des
/// exclusions est dans le dartdoc des jetons (`z_theme.dart`).
///
/// Aucune `ThemeExtension` locale n'est créée : ce dépôt s'interdit le second
/// canal (CR-TOKENS, 2026-08-09).
///
/// ## Invariants
///
/// * **FR-26 / NFR-S7** : 🔴 **aucune couleur** dans ce fichier — que des
///   dimensions. Les teintes sont résolues au rendu sur des **rôles**.
/// * **AD-40/AD-49** : aucun type `awesome_select` / `S2*` ici ni en signature
///   publique — [ZSelectChoiceStyle] est un enum **local**, traduit en `S2*`
///   dans le seul `z_smart_select_presenter.dart`.
/// * **AD-13** : [minTileHeight] ≥ 48 ; insets **directionnels** au rendu.
/// * **AD-10** : aucun champ ne peut faire lever d'exception ; un `null`
///   signifie « je ne me prononce pas » et le maillon suivant décide.
/// * **AD-1** : aucune arête de paquet ajoutée (Flutter vanilla uniquement).
library;

import 'package:flutter/widgets.dart';

/// Forme des options **dans le modal** — enum **local** (AD-40 : le type `S2*`
/// correspondant ne franchit jamais la frontière publique).
///
/// Les noms reprennent ceux de DODLP pour que la correspondance soit lisible.
enum ZSelectChoiceStyle {
  /// Boutons radio — **défaut mono** de DODLP (`_choiceType`, branche non-web).
  radios,

  /// Cases à cocher.
  checkboxes,

  /// Interrupteurs — **défaut multi** de DODLP
  /// (`choiceType: field.s2choiceType ?? S2ChoiceType.switches`, l. ~3009).
  switches,

  /// Puces (`chips`) — DODLP les réserve à une liste de noms de champs codée en
  /// dur (`["state", "label", "attributeType", "stockUnit", "barecodeType"]`).
  /// 🔴 Cette liste **n'est pas reproduite** : c'est un aiguillage par nom de
  /// champ propre à leur modèle de données, sans aucun sens dans un socle. Le
  /// style reste **atteignable**, il n'est simplement plus deviné.
  chips,
}

/// Forme du **conteneur** du modal.
enum ZSelectModalShape {
  /// Feuille par le bas — le défaut mobile de DODLP.
  bottomSheet,

  /// Boîte de dialogue — ce que DODLP choisit sur web/desktop
  /// (`AppPlatform.isWebOrDesktop ? S2ModalType.popupDialog : …`).
  popupDialog,

  /// Page pleine.
  fullPage,

  /// Choisit [popupDialog] au-delà de [ZSelectTileReference.dialogBreakpoint]
  /// de largeur utile, [bottomSheet] en deçà — **défaut**.
  ///
  /// 🔴 C'est notre substitut **mesurable** au `AppPlatform.isWebOrDesktop` de
  /// DODLP : le socle ne peut pas dépendre d'un détecteur de plateforme (aucune
  /// arête de paquet, AD-1), et la largeur utile est de toute façon le critère
  /// *utile* — un navigateur en fenêtre étroite mérite la feuille, pas une
  /// boîte de dialogue de 300 dp.
  adaptive,
}

/// Les **valeurs de référence** du déclencheur de sélection — point d'audit
/// unique (patron `ZSheetFrameReference` / `ZStudyCardReference`).
///
/// 🔴 **AUCUNE COULEUR ici** : uniquement des dimensions relevées chez DODLP.
abstract final class ZSelectTileReference {
  /// Rayon du `Card` du déclencheur (dp) — `BorderRadius.circular(12)` chez
  /// DODLP, dans les DEUX branches (multi l. ~2903, mono l. ~3070).
  static const double cardRadius = 12;

  /// Élévation du `Card` — `elevation: 0` chez DODLP (le relief vient de la
  /// bordure, pas de l'ombre).
  static const double cardElevation = 0;

  /// Épaisseur de la bordure (dp) — DODLP écrit `BorderSide(color: …)` sans
  /// `width`, donc **la valeur par défaut de `BorderSide`, soit 1,0**.
  static const double borderWidth = 1;

  /// Écart horizontal entre deux puces — `Wrap(spacing: 6)` (l. ~2934).
  static const double chipSpacing = 6;

  /// Écart vertical entre deux rangées de puces — `Wrap(runSpacing: 4)`.
  static const double chipRunSpacing = 4;

  /// Taille du texte d'une puce (pt) — `TextStyle(fontSize: 12)` (l. ~2940).
  static const double chipFontSize = 12;

  /// Taille du texte de la valeur en **mono** (pt) — `fontSize: 15` (l. ~3125).
  ///
  /// ⚠️ DODLP ne fixe **aucune** taille sur le sous-titre du multi (les puces
  /// portent la leur) : cette métrique ne vaut que pour la branche mono.
  static const double monoValueFontSize = 15;

  /// CR-SELECT-GAPS — écart (dp) entre un ornement `prefix`/`suffix` et le
  /// contenu du sous-titre.
  ///
  /// 🔴 **Sans référence DODLP** : leur `tileBuilder` ne rend aucun ornement
  /// interne (ils n'ont que `leading`). La valeur reprend celle que Material
  /// applique entre le `prefix`/`suffix` et le texte d'un `InputDecorator`
  /// (`_kFinalLabelScale`-indépendante : 4 dp de `gap` horizontal) — c'est le
  /// rendu NATIF que l'enrôlement doit conserver, pas une invention de style.
  static const double ornamentGap = 4;

  /// Marge intérieure horizontale du `ListTile` (dp) —
  /// `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`, l. ~3067.
  ///
  /// ⚠️ **Mesuré** : DODLP ne pose ce `contentPadding` que sur la branche
  /// **mono**. La branche multi laisse le défaut du `ListTile`. Le socle
  /// l'applique aux deux — un écart **délibéré** (deux champs voisins, l'un
  /// mono l'autre multi, ne peuvent pas s'aligner autrement), et minime : le
  /// défaut Material est justement `horizontal: 16`.
  static const double contentPaddingHorizontal = 16;

  /// Marge intérieure verticale du `ListTile` (dp) — `vertical: 8` (l. ~3067).
  static const double contentPaddingVertical = 8;

  /// Plancher de hauteur du déclencheur (dp).
  ///
  /// 🔴 **N'est PAS une valeur de DODLP** : c'est le plancher **AD-13**, ajouté
  /// parce que leur `ListTile` (sous-titre vide + `contentPadding` vertical 8)
  /// peut descendre dessous. Défaut non reproduit n°2.
  static const double minTileHeight = 48;

  /// Largeur utile (dp) au-delà de laquelle [ZSelectModalShape.adaptive] bascule
  /// en boîte de dialogue.
  ///
  /// 600 dp est le palier `medium` de Material 3 (`WindowWidthSizeClass`) — le
  /// même que le SDK emploie pour distinguer téléphone et tablette.
  static const double dialogBreakpoint = 600;

  /// Opacité du fond de l'en-tête de modal — `withValues(alpha: 0.7)` chez
  /// DODLP (l. ~2988 et ~3178), identique dans les deux branches.
  static const double modalHeaderOpacity = 0.7;

  /// Élévation de l'en-tête de modal — `elevation: 3.0` chez DODLP.
  static const double modalHeaderElevation = 3;

  /// Nombre d'options chargées par page dans le modal — `pageLimit` du
  /// `S2ChoiceConfig`, dont DODLP fixe le défaut d'appel à `20`
  /// (`_buildSmartSelect({int pageLimit = 20, …})`, l. ~2835).
  static const int choicePageLimit = 20;

  /// Délai au-delà duquel un [ZSelectOptionsLoader] qui **ne se termine pas**
  /// est abandonné au profit du rendu dégradé (liste vide) — AD-10.
  ///
  /// 🔴 **N'est PAS une valeur de DODLP** : DODLP n'impose aucun délai, et son
  /// `choiceLoader` est de toute façon du **code mort** (le champ
  /// `_choiceLoader` est déclaré puis jamais affecté, `edition_screen.dart`
  /// l. ~2812 — le corps réel est en commentaire). Ce plancher de robustesse est
  /// à nous : sans lui, une source distante silencieuse laisserait le modal en
  /// attente **définitive**, le `finally` du fork ne s'exécutant jamais.
  ///
  /// 30 s : assez long pour un réseau lent, assez court pour qu'un utilisateur
  /// obtienne un état vide explicite plutôt qu'un indicateur perpétuel.
  static const Duration optionsLoadTimeout = Duration(seconds: 30);

  /// Forme des options en **mono** — `radios` (défaut DODLP hors web).
  static const ZSelectChoiceStyle monoChoiceStyle = ZSelectChoiceStyle.radios;

  /// Forme des options en **multi** — `switches`.
  ///
  /// 🔴 **Mesuré, et contre-intuitif** : la branche multi de DODLP calcule bien
  /// un `_choiceType` (l. ~2869) mais **ne s'en sert pas** — elle passe
  /// `choiceType: field.s2choiceType ?? S2ChoiceType.switches` (l. ~3009). Le
  /// défaut multi est donc l'**interrupteur**, pas la case à cocher. La version
  /// précédente de ce présentateur employait `checkboxes` : c'est cette
  /// valeur-ci qui est fidèle, et elle reste surchargeable
  /// ([ZSelectTileSpec.multiChoiceStyle]).
  static const ZSelectChoiceStyle multiChoiceStyle = ZSelectChoiceStyle.switches;

  /// Forme du conteneur de modal — [ZSelectModalShape.adaptive], qui restitue
  /// l'intention de DODLP (`popupDialog` sur grand écran, `bottomSheet` sinon)
  /// sans détecteur de plateforme.
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
  /// 🔴 Une valeur **inférieure à 48** viole AD-13 ; le présentateur ne la
  /// refuse pas (AD-10 : jamais d'exception) mais **ne descend jamais sous
  /// [ZSelectTileReference.minTileHeight]** — la surcharge ne peut que
  /// *rehausser* le plancher.
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

  /// Affiche le chevron de fin de ligne. `null` ⇒ règle de DODLP : **oui, sauf
  /// en lecture seule**. Une valeur explicite l'impose dans les deux cas.
  final bool? showTrailingChevron;

  /// Rend la **barre d'actions du modal** (créer / confirmer / réinitialiser /
  /// rechercher — parité `_modalActionsBuilder` DODLP). `null` ⇒ **oui**, c'est
  /// la référence.
  ///
  /// `false` rend la main aux seules actions par défaut du fork (bascule de
  /// recherche + bouton de confirmation quand `useConfirm` est actif) — utile à
  /// un hôte qui n'a pas la barre DODLP dans son langage d'interface.
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
