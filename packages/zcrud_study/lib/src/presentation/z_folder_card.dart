/// Carte de dossier d'étude — primitive de présentation à props primitives.
///
/// ## Frontière : jamais l'entité domaine
///
/// Cette carte ne reçoit que des primitives ([title], [colorKey]) et des
/// slots ([counts], [menu]). Elle ne connaît aucun type métier d'étude,
/// aucune clé sémantique (`success`/`warning`/…) ni aucune règle de
/// permissions : tout arrive par les props. Un besoin de savoir « quel
/// dossier » serait le signe d'une frontière mal placée.
///
/// ## Invariants
///
/// - **AD-2 / AD-15** : `StatelessWidget` pur-Flutter, aucun état détenu (pas
///   de compteur, pas de sélection — tout est props/slots). Rien à disposer.
/// - **AD-4** : props opaques ; un slot `null` est absent de l'arbre, jamais
///   un espace réservé.
/// - **AD-13** : `Semantics` explicites, cible ≥ 48 dp
///   ([kZFolderCardMinHeight]), insets et alignements directionnels
///   (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`),
///   rayon et espacements depuis `ZcrudTheme.of(context)`, typographie
///   depuis `Theme.of(context)` — aucun littéral. `const` où immuable.
/// - **absence d'activation structurelle** : [onTap] `== null` et
///   [onLongPress] `== null` signifient qu'aucun `InkWell` inerte n'est
///   rendu, et qu'aucun rôle `button` n'est annoncé — pas un bouton éteint.
///   La carte non interactive reste néanmoins annoncée (titre, état
///   archivé, [semanticLabel]) : le contenu, lui, n'est jamais rendu muet.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZFolderCardFooterPlacement,
        ZcrudTheme,
        zResolveColorKeyOrSlot;

/// Hauteur minimale de la cible d'activation d'une [ZFolderCard] (AD-13). La
/// carte activable ne descend jamais en dessous, quel que soit son contenu.
const double kZFolderCardMinHeight = 48;

/// Teinte de fond par défaut d'une carte de dossier
/// (`accent.withValues(alpha: 0.12)`). Dimension d'opacité (pas une couleur) :
/// exposée pour rester ajustable sans coder de couleur en dur (invariant FR-26).
const double kZFolderCardTintAlpha = 0.12;

/// Flou par défaut de l'ombre de carte **personnalisée**.
///
/// N'entre en jeu que si AU MOINS un des trois jetons `ZcrudTheme.cardShadow*`
/// est fourni : sans aucun d'eux, la carte garde l'ombre native de `Card`
/// (rendu strictement inchangé). Documenté et public pour que les trois jetons
/// se règlent INDÉPENDAMMENT — régler le seul `cardShadowAlpha` doit produire
/// une ombre visible, pas un flou nul invisible.
const double kZCardShadowBlurRadius = 8;

/// Décalage par défaut de l'ombre de carte personnalisée.
/// Voir [kZCardShadowBlurRadius] pour la règle d'activation.
const Offset kZCardShadowOffset = Offset(0, 2);

/// Opacité par défaut de l'ombre de carte personnalisée, appliquée à la
/// couleur d'ombre du thème — jamais une couleur (invariant FR-26).
/// Voir [kZCardShadowBlurRadius] pour la règle d'activation.
const double kZCardShadowAlpha = 0.12;

/// Diamètre de la pastille d'accent (dimension de LAYOUT — jamais une couleur).
/// Valeur de référence (`14×14`).
const double _kPastilleSize = 14;

/// Seuil de largeur (dp) au-delà duquel [ZFolderCardFooterPlacement.adaptive]
/// rend le bas de carte **côte à côte**. Mesuré sur la largeur
/// RÉELLEMENT offerte au bas de carte — padding interne déjà retranché, pas la
/// largeur de la carte.
///
/// 📐 **D'où vient ce 740, et pourquoi il est si haut.** Côte à côte, le
/// créneau compteur ne reçoit que `(largeur − gapS) / 2` : le côte-à-côte cesse
/// donc d'amputer exactement à `2 × largeurNaturelleDeLaRangée + gapS`. Ce
/// point d'équilibre a été **mesuré** (police de test, corpus réel de badges
/// d'un dossier d'étude : « 12 fiches », « 3 notes », « 5 documents »,
/// « 2 sous-dossiers ») : rangée de **569 dp**, quatre badges visibles sur
/// quatre à partir d'une carte de **1200 dp**, trois sur quatre à 900. La
/// police de test est un carré cadratin (~2× l'avance de la police d'interface
/// sur ce corpus) ; corrigé de ce facteur sur la seule part TEXTE, l'équilibre
/// réel tombe vers **740 dp de bas de carte**.
///
/// **Ce seuil dépend du CONTENU, pas seulement de la largeur** : avec des
/// libellés courts (« 12 », « 34 »…) l'équilibre est à ~350 dp, avec cinq
/// badges verbeux il dépasse 900. C'est la raison pour laquelle
/// [ZFolderCardFooterPlacement.adaptive] **n'est pas** le défaut de
/// `ZDefaultFolderCard` : un seuil fixe placé trop bas RÉINTRODUIT l'amputation
/// à la largeur où il bascule (mesuré : à 600 dp, côte à côte ne montre plus
/// que **2 badges sur 4** du corpus réel, contre 4 empilés). Le régime
/// adaptatif reste offert à l'hôte qui connaît ses libellés — c'est lui, et lui
/// seul, qui peut calibrer le seuil.
const double kZFolderCardFooterBesideMinWidth = 740;

/// Carte d'un dossier d'étude dans une grille.
///
/// ```dart
/// ZFolderCard(
///   title: 'Chapitre 3 — Valeur en douane',
///   colorKey: 'secondary',                 // opaque : résolue par le cœur/bridge
///   headerDecoration: myAccent,             // slot : remplace la pastille historique
///   counts: const Text('42 cartes'),        // slot : compteur simple OU badges
///   menu: myFolderMenu,                      // slot : le widget ignore son contenu
///   isArchived: true,
///   archivedLabel: 'Archivé',                // INJECTÉ (jamais de littéral)
///   onTap: () => openFolder(id),
///   onLongPress: () => showActions(id),
/// )
/// ```
///
/// La carte est la **cellule** ; la grille adaptative est posée par l'appelant
/// (`ZAdaptiveGrid.builder`) — jamais réimplémentée ici.
class ZFolderCard extends StatelessWidget {
  /// Construit une carte de dossier ; seuls [title] et [colorKey] sont requis.
  const ZFolderCard({
    required this.title,
    required this.colorKey,
    this.colorSlotIndex = 0,
    this.headerDecoration,
    this.topAccent,
    this.belowSubtitle,
    this.counts,
    this.footer,
    this.footerPlacement,
    this.footerBesideMinWidth,
    this.menu,
    this.archivedLabel,
    this.isArchived = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.tintAlpha,
    this.borderSide,
    this.borderRadius,
    this.contentPadding,
    this.defaultShadow,
    super.key,
  });

  /// Titre du dossier — rendu sur **2 lignes ellipsées**, ancré en bas de la
  /// cellule (patron anti-overflow, cf. [build]).
  final String title;

  /// Clé de couleur **opaque** (`String`) résolue par [zResolveColorKeyOrSlot]
  /// (seam hôte `ZcrudScope.colorKeyResolver` prioritaire, sinon repli du cœur,
  /// sinon slot déterminé par [colorSlotIndex]). Le widget n'en connaît aucune
  /// valeur ; la dérivation d'index reste **côté app/bridge**.
  final String colorKey;

  /// Index de repli déterministe passé tel quel à [zResolveColorKeyOrSlot] :
  /// utilisé **seulement** si [colorKey] reste inconnue du resolver (couleur
  /// contrastée distincte par index — invariant AD-10).
  final int colorSlotIndex;

  /// Décoration d'en-tête injectée. Lorsqu'elle est fournie, elle remplace
  /// uniquement la pastille d'accent historique ; `null` conserve cette
  /// pastille circulaire de 14 dp à l'identique.
  final Widget? headerDecoration;

  /// Accent injecté au-dessus du contenu, sur toute la largeur de la carte.
  ///
  /// Pour une barre résolue par la couture de dégradé, employer
  /// [ZFolderCardGradientAccent]. `null` conserve strictement l'arbre et le
  /// rendu historiques.
  final Widget? topAccent;

  /// Contenu secondaire rendu **directement sous le [title]**, dans la même
  /// colonne : classement du dossier (matière, cours, catégorie, client,
  /// projet), puce d'état, méta-information.
  ///
  /// **Contrat IDENTIQUE** à `ZStudyToolsItemCard.belowSubtitle` et
  /// `ZStudyNoteCard.belowSubtitle` — même nom, même type, même
  /// espacement (`gapS`), même traitement sémantique. C'est délibérément une
  /// EXTENSION du slot existant et **pas une variante** : l'incohérence entre
  /// cartes sœurs d'une même famille était précisément le défaut signalé.
  ///
  /// **Pourquoi [counts] ne pouvait pas en tenir lieu** : composer un
  /// sous-titre dans le slot compteur trahit la sémantique du slot — le jour
  /// où [counts] recevra un traitement propre (alignement, `Semantics` de
  /// comptage), le sous-titre le subirait. Ce slot-ci est ancré au titre, pas
  /// au pied de carte.
  ///
  /// ♿ **Sa sémantique est PRÉSERVÉE**, comme sur les deux cartes sœurs : son
  /// contenu vient de l'hôte et n'est **pas** repris dans le `label` de la
  /// carte, donc l'exclure ne préviendrait aucune double annonce — cela le
  /// rendrait seulement muet. Il n'est donc PAS traité comme [topAccent] /
  /// [footer], qui sont, eux, des décors.
  ///
  /// 📐 **Coût vertical NUL en cellule contrainte** : le slot
  /// **participe** à la hauteur allouée au lieu de s'y **ajouter**. Livré, il
  /// était correct… et inutilisable à densité réelle — une grille en
  /// `childAspectRatio: itemWidth / 210` débordait sur *chaque* carte, quand le
  /// même texte tenait dans [counts] (qui, lui, vit dans une zone déjà bornée).
  /// Désormais, toute hauteur où la carte tient **sans** le slot est une hauteur
  /// où elle tient **avec**. À l'extrême, c'est le sous-titre qui se borne au
  /// reliquat (le titre reste prioritaire) — jamais la carte qui déborde.
  ///
  /// `null` ⇒ **rendu strictement inchangé** (aucun nœud, aucun espacement).
  final Widget? belowSubtitle;

  /// Slot compteur/badges rendu **verbatim**, ancré en bas. `null` ⇒
  /// **absent** de l'arbre (aucun espace réservé). Le widget n'en interprète
  /// jamais le contenu.
  final Widget? counts;

  /// Slot de pied rendu sous le contenu. Par défaut il partage la même ligne
  /// que le créneau [counts] et que le badge archivé éventuel : ce dernier
  /// reste donc visible et n'est jamais remplacé. `null` ⇒ aucun espace
  /// réservé.
  ///
  /// Voir [footerPlacement] pour l'**empiler sous** [counts].
  final Widget? footer;

  /// DISPOSITION du bas de carte : [counts] et [footer] côte à côte, empilés,
  /// ou adaptatif.
  ///
  /// **Le défaut mesuré qui a fait exister ce slot** : sans lui, les deux
  /// créneaux sont assemblés dans une même `Row`, chacun en `Expanded` — donc
  /// chacun à la MOITIÉ de la largeur, sans aucun réglage pour en sortir. Une
  /// carte à quatre badges de compteur n'en montre alors plus que **deux**,
  /// et le pied vient s'accoler au dernier badge visible. Le seul
  /// contournement possible serait de recomposer soi-même le créneau
  /// [counts] — ce qui **rend le rendu des badges à l'hôte**, donc lui fait
  /// perdre le plancher de contraste garanti par `ZDefaultFolderCard`.
  ///
  /// Priorité : ce paramètre > le jeton `ZcrudTheme.folderCardFooterPlacement`
  /// > [ZFolderCardFooterPlacement.beside] (rendu **historique** de la
  /// primitive). `null` **et** jeton absent ⇒ **rendu strictement inchangé**.
  ///
  /// La disposition n'a d'effet que si [counts] **et** [footer] sont tous
  /// deux fournis : avec un seul créneau il n'y a rien à empiler, et les trois
  /// valeurs rendent alors le même pixel (dont la place du badge « Archivé »).
  final ZFolderCardFooterPlacement? footerPlacement;

  /// Seuil de largeur (dp) du régime [ZFolderCardFooterPlacement.adaptive],
  /// mesuré sur la largeur RÉELLEMENT offerte au bas de carte (padding interne
  /// déjà retranché). Priorité : ce paramètre > le jeton
  /// `ZcrudTheme.folderCardFooterBesideMinWidth` >
  /// [kZFolderCardFooterBesideMinWidth]. Sans effet hors du régime adaptatif.
  final double? footerBesideMinWidth;

  /// Slot menu/trailing (ex. `IconButton` ⋮) rendu en tête, aligné en fin
  /// (RTL-safe). `null` ⇒ **absent**. **Non exclu** de la sémantique : un menu
  /// doit rester atteignable au lecteur d'écran (patron `ZStudyToolsItemCard`).
  final Widget? menu;

  /// Libellé du badge « Archivé » **INJECTÉ** (l10n) — jamais un littéral.
  /// Le badge n'apparaît que si [isArchived] **et** `archivedLabel != null`.
  final String? archivedLabel;

  /// Dossier archivé : conditionne l'apparition du badge (avec [archivedLabel])
  /// et enrichit le libellé sémantique de la carte.
  final bool isArchived;

  /// Activation principale. `null` **avec** [onLongPress] `null` ⇒ carte non
  /// interactive : **aucun** `InkWell`, pas de rôle `button` (invariant AD-4).
  final VoidCallback? onTap;

  /// Activation par appui long (ex. feuille d'actions). Voir [onTap] pour la
  /// règle d'absence structurelle.
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [archivedLabel] si le badge est présent — pour que le lecteur d'écran
  /// annonce la carte comme un tout, jamais comme une suite de fragments.
  final String? semanticLabel;

  /// Opacité de la teinte de fond dérivée de l'accent. Dimension d'opacité, pas
  /// une couleur (invariant FR-26).
  ///
  /// Priorité : ce slot > le jeton `ZcrudTheme.cardTintAlpha` >
  /// [kZFolderCardTintAlpha] (`0.12`, valeur de référence). `null` **et**
  /// jeton absent ⇒ **rendu strictement inchangé**.
  ///
  /// **`tintAlpha: 0` ne rend pas la carte TRANSPARENTE.** `0` exprime « pas
  /// de teinte » ; en faire `accent.withValues(alpha: 0)` produirait une
  /// carte à travers laquelle on voit le fond d'écran — jamais « carte de
  /// surface normale ». Une valeur ≤ 0 (ou > 1, clampée) fait retomber la
  /// couleur de fond sur `CardThemeData.color` du thème de l'hôte, et à
  /// défaut sur le défaut Material de `Card` (surface opaque) — **jamais**
  /// sur du transparent.
  ///
  /// C'est le motif déjà retenu deux fois par le socle sur `shape` et sur
  /// `margin` : *ne pas imposer une décision que le `CardTheme` exprime
  /// déjà*. Les deux conventions de design coexistent —
  /// carte teintée (le défaut, conservé) et carte neutre + accents (Material 3
  /// pour les surfaces de liste, et les interfaces denses où teinter chaque
  /// carte produit un damier) — et seule la seconde était inexprimable.
  ///
  /// **Hôte ayant contourné** : celui qui posait `tintAlpha: 0` + un
  /// `DecoratedBox` externe portant la couleur neutre doit **RETIRER sa
  /// compensation**, sans quoi sa décoration s'ajoute désormais à celle du
  /// `CardTheme`.
  final double? tintAlpha;

  /// Liseré du pourtour de la carte.
  ///
  /// **Le manque que ce slot ferme** : la forme de la carte était construite
  /// sans `side:`, et aucun jeton de bordure ne la visait — le liseré fin
  /// teinté que pose la carte de flashcard n'avait **aucun équivalent
  /// atteignable** ici. Ce n'était pas une absence de patron dans le socle : le
  /// patron existe pour la famille sœur (`ZcrudTheme.studyCardBorderSide`,
  /// consommé par `zStudyCardChromeOf`) — c'était une absence de RÉPLICATION.
  /// Ce slot réplique donc le patron existant à l'identique, il n'en invente
  /// pas un second.
  ///
  /// Priorité : ce slot > le jeton `ZcrudTheme.folderCardBorderSide` >
  /// `CardThemeData.shape` de l'hôte (*ne pas imposer une décision que le
  /// `CardTheme` exprime déjà*) > forme historique sans bordure. `null`
  /// **et** jeton absent ⇒ **rendu strictement inchangé**.
  final BorderSide? borderSide;

  /// Rayon de la carte. Priorité : ce slot > le jeton
  /// `ZcrudTheme.folderCardRadius` > `CardThemeData.shape` de l'hôte > jeton
  /// `radiusM` (défaut historique). `null` partout ⇒ **rendu inchangé**.
  ///
  /// Comme sur `ZStudyToolsItemCard`, fournir [borderSide] **ou**
  /// [borderRadius] fait construire une forme explicite : un slot explicite
  /// prime le thème.
  final Radius? borderRadius;

  /// Padding interne de la carte. Priorité : ce slot > le jeton
  /// `ZcrudTheme.folderCardContentPadding` > `EdgeInsetsDirectional.all`
  /// de `gapM` (défaut historique).
  ///
  /// **Pourquoi il fallait un slot** : la référence pose **12**, et `gapM`
  /// vaut **8** en thème nu — sans ce slot, la carte par défaut ne pourrait
  /// atteindre la référence qu'en ridant `gapM` pour TOUT le sous-arbre
  /// (même défaut que sur `leadingGap`).
  final EdgeInsetsGeometry? contentPadding;

  /// Ombre de **REPLI** (patron `ZStudyToolsItemCard`) :
  /// utilisée lorsqu'aucun des trois jetons `ZcrudTheme.cardShadow*` n'est
  /// fourni. Les jetons de l'hôte **PRIMENT** toujours — l'ombre de référence
  /// d'une carte par défaut ne rend jamais le canal d'ombre de l'hôte
  /// inatteignable.
  ///
  /// `null` (défaut) ⇒ **rendu strictement inchangé** : aucune ombre peinte,
  /// élévation native de `Card` conservée.
  final BoxDecoration? defaultShadow;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Accent DÉRIVÉ, jamais codé en dur (invariant AD-10).
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      colorKey,
      slotIndex: colorSlotIndex,
    );
    // Résolution UNIQUE du `CardTheme` : la teinte, la forme et la marge en
    // dépendent toutes les trois — en ajouter une seconde lecture ferait
    // diverger les trois décisions.
    final CardThemeData cardTheme = CardTheme.of(context);

    // Priorité slot > jeton > valeur de référence ; ≤ 0 ⇒ surface NEUTRE du
    // `CardTheme`, jamais une carte transparente. `null` partout ⇒ rendu
    // inchangé.
    final double resolvedTintAlpha =
        tintAlpha ?? theme.cardTintAlpha ?? kZFolderCardTintAlpha;
    final Color? tint = resolvedTintAlpha <= 0
        ? cardTheme.color
        : pair.color.withValues(alpha: math.min(1, resolvedTintAlpha));

    final bool showArchived = isArchived && archivedLabel != null;

    // Un semanticLabel explicite décrit la carte comme un tout : les nouveaux
    // slots purement visuels/de pied ne doivent alors pas créer une annonce
    // concurrente. Sans semanticLabel, ils restent accessibles comme `counts`.
    final Widget? semanticTopAccent = topAccent == null
        ? null
        : semanticLabel == null
        ? topAccent
        : ExcludeSemantics(child: topAccent!);
    final Widget? semanticFooter = footer == null
        ? null
        : semanticLabel == null
        ? footer
        : ExcludeSemantics(child: footer!);

    // Pied de carte : slots compteur/pied + badge « Archivé » conditionnel.
    // Rendu SEULEMENT s'il a du contenu (AD-4 : aucun espace réservé quand les
    // trois sont absents).
    //
    // ExcludeSemantics : le texte du badge est DÉJÀ porté par le `label` du
    // nœud de la carte (repli enrichi) — le répéter le ferait annoncer deux
    // fois. Le badge reste visuellement présent. Construit UNE fois : les deux
    // dispositions le posent au même endroit sémantique.
    final Widget? archivedBadge = showArchived
        ? ExcludeSemantics(child: _ArchivedBadge(label: archivedLabel!))
        : null;

    final List<Widget> footerChildren = <Widget>[
      if (counts != null)
        Expanded(child: counts!)
      else if (semanticFooter != null)
        Expanded(child: semanticFooter)
      else if (showArchived)
        const Spacer(),
      if (counts != null && semanticFooter != null) SizedBox(width: theme.gapS),
      if (counts != null && semanticFooter != null)
        Expanded(child: semanticFooter),
      if (archivedBadge != null) ...<Widget>[
        SizedBox(width: theme.gapS),
        archivedBadge,
      ],
    ];

    // ── DISPOSITION du bas de carte ──────────────────────────────────────
    // Priorité paramètre > jeton > défaut HISTORIQUE (`beside`) : un hôte qui
    // ne déclare rien rend exactement le pixel d'avant.
    final ZFolderCardFooterPlacement placement =
        footerPlacement ??
        theme.folderCardFooterPlacement ??
        ZFolderCardFooterPlacement.beside;

    // Ligne UNIQUE (rendu historique) : les deux créneaux en `Expanded` d'une
    // même `Row`, donc chacun à la moitié de la largeur.
    Widget besideRow() => Row(children: footerChildren);

    // Pile : le créneau compteur reçoit la largeur ENTIÈRE (il peut donc
    // défiler sur toute la carte), le pied vient dessous.
    //
    // Le badge « Archivé » suit la DERNIÈRE ligne de la pile, jamais celle
    // des compteurs : l'y poser recréerait exactement l'amputation que cette
    // disposition corrige (le badge est inflexible, il mangerait la largeur
    // rendue aux compteurs). Sur la ligne du pied, il partage la place avec un
    // pied court — qui est le cas nominal (« Par toi », une ligne de méta).
    Widget stackedColumn() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[Expanded(child: counts!)]),
        SizedBox(height: theme.gapS),
        Row(
          children: <Widget>[
            Expanded(child: semanticFooter!),
            if (archivedBadge != null) ...<Widget>[
              SizedBox(width: theme.gapS),
              archivedBadge,
            ],
          ],
        ),
      ],
    );

    // Avec un seul créneau il n'y a RIEN à empiler : les trois dispositions
    // rendent alors strictement la ligne historique (badge compris).
    final bool stackable = counts != null && semanticFooter != null;

    Widget footerArea() {
      if (!stackable) return besideRow();
      switch (placement) {
        case ZFolderCardFooterPlacement.beside:
          return besideRow();
        case ZFolderCardFooterPlacement.below:
          return stackedColumn();
        case ZFolderCardFooterPlacement.adaptive:
          final double threshold =
              footerBesideMinWidth ??
              theme.folderCardFooterBesideMinWidth ??
              kZFolderCardFooterBesideMinWidth;
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // AD-10 — largeur non bornée : aucun seuil n'a de sens, on rend
              // le régime que la primitive a toujours rendu.
              final bool wide =
                  !constraints.maxWidth.isFinite ||
                  constraints.maxWidth >= threshold;
              return wide ? besideRow() : stackedColumn();
            },
          );
      }
    }

    // ExcludeSemantics CIBLÉ sur le SEUL titre : le nœud de la carte le porte
    // déjà dans son `label`. Volontairement NON étendu au menu ni au slot counts
    // (qui doivent rester atteignables au lecteur d'écran).
    final Widget titleText = ExcludeSemantics(
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    // Le sous-titre est ancré AU TITRE (donc suit l'ancrage bas du patron
    // anti-overflow), pas au pied de carte. `null` ⇒ l'arbre reste exactement
    // `titleText`, sans colonne ni espacement supplémentaires.
    //
    // Le slot doit PARTICIPER à la hauteur, jamais s'y AJOUTER.
    // Mesuré : `RenderFlex overflowed` dès 210 dp de cellule, alors que le
    // MÊME texte composé dans [counts] tient — parce que [counts] vit
    // dans une zone DÉJÀ BORNÉE (`Expanded`), là où cette colonne, sizée au
    // contenu et à enfants tous INFLEXIBLES, débordait la hauteur résiduelle
    // que l'`Align` lui prête. Gouverner l'espacement (`gapS`) ne pouvait pas
    // suffire : le gap n'est qu'une fraction du coût, le reste est la hauteur
    // propre du sous-titre.
    //
    // En régime BORNÉ, la colonne est donc reconstruite pour ne JAMAIS pouvoir
    // déborder : le titre garde la priorité (hauteur naturelle) mais est borné
    // à la place réellement disponible — exactement ce que le régime sans slot
    // faisait déjà, l'`Align` passant des contraintes lâches à un `Text` qui
    // s'y conforme — et le sous-titre absorbe le reliquat via un `Flexible`.
    // La somme des enfants inflexibles ne dépasse donc jamais la contrainte.
    Widget stackedBlock(Widget below) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        titleText,
        SizedBox(height: theme.gapS),
        // Volontairement HORS `ExcludeSemantics`, comme sur les deux cartes
        // sœurs : ce contenu n'est pas dans le `label` de la carte, l'exclure
        // le rendrait muet sans rien dédupliquer.
        below,
      ],
    );

    Widget titleBlockFor({required bool bounded}) {
      final Widget? below = belowSubtitle;
      if (below == null) return titleText;
      if (!bounded) return stackedBlock(below);
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double available = constraints.maxHeight;
          // AD-10 — repli sûr : sans hauteur finie, aucune répartition n'a de
          // sens, la colonne reste sizée au contenu.
          if (!available.isFinite) return stackedBlock(below);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: available),
                child: titleText,
              ),
              // `Flexible` (fit LOOSE) : le sous-titre prend sa hauteur
              // naturelle tant qu'il y a la place, et se borne au reliquat
              // sinon — au lieu de faire déborder la carte. L'ESPACEMENT est
              // porté par ce même enfant flexible (`Padding` plutôt que
              // `SizedBox`) : un gap inflexible pouvait à lui seul dépasser la
              // place restante et faire déborder la colonne. Aucun enfant
              // inflexible ne peut donc plus excéder la contrainte — le titre
              // en est borné, l'espacement en fait partie.
              Flexible(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(top: theme.gapS),
                  child: below,
                ),
              ),
            ],
          );
        },
      );
    }

    // Deux régimes selon la hauteur DISPONIBLE, décidés par un
    // `LayoutBuilder` (jamais un layout de grille : la grille reste posée par
    // l'appelant) :
    //   • hauteur BORNÉE (cellule de `ZAdaptiveGrid.builder`, hauteur pilotée par
    //     `itemHeight`) ⇒ patron anti-overflow : `Expanded(Align(bottomStart))`
    //     absorbe la hauteur résiduelle, le titre est ancré EN BAS puis ellipsé
    //     ⇒ JAMAIS d'overflow (contrairement à un `Spacer` + hauteurs fixes).
    //   • hauteur NON BORNÉE (usage autonome / min-content) ⇒ colonne
    //     `MainAxisSize.min` sizée au contenu, plancher assuré par le
    //     `ConstrainedBox(minHeight: kZFolderCardMinHeight)` (invariant
    //     AD-13) — un `Expanded` y lèverait « unbounded height ».
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = constraints.maxHeight.isFinite;
        return Padding(
          // Priorité slot > jeton > défaut historique (`gapM`).
          padding:
              contentPadding ??
              theme.folderCardContentPadding ??
              EdgeInsetsDirectional.all(theme.gapM),
          child: Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // En-tête : décoration injectée ou pastille pleine d'accent +
              // menu aligné en fin (RTL-safe).
              Row(
                children: <Widget>[
                  // `iconContainerRadius` pilote la silhouette de la pastille
                  // d'accent : `null` conserve le disque de 14 dp à l'identique
                  // (rendu strictement inchangé), une valeur fournie donne un
                  // carré aux coins arrondis de ce rayon. La TAILLE reste
                  // volontairement figée : `iconContainerSize` a déjà un
                  // consommateur (`ZFolderCardGradientAccent`) et la détourner
                  // ici redimensionnerait la pastille chez tout hôte l'ayant
                  // réglée pour la barre d'accent.
                  headerDecoration ??
                      Container(
                        width: _kPastilleSize,
                        height: _kPastilleSize,
                        decoration: theme.iconContainerRadius == null
                            ? BoxDecoration(
                                color: pair.color,
                                shape: BoxShape.circle,
                              )
                            : BoxDecoration(
                                color: pair.color,
                                borderRadius: BorderRadius.all(
                                  theme.iconContainerRadius!,
                                ),
                              ),
                      ),
                  const Spacer(),
                  // Slot menu rendu verbatim, NON exclu de la sémantique.
                  ?menu,
                ],
              ),
              if (bounded)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: titleBlockFor(bounded: true),
                  ),
                )
              else
                titleBlockFor(bounded: false),
              if (footerChildren.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.gapS),
                footerArea(),
              ],
            ],
          ),
        );
      },
    );

    // Le thème Material de l'hôte décide la forme complète (dont sa bordure)
    // lorsqu'il en fournit une. La même instance est donnée au `Card` et à
    // l'`InkWell` pour que le clip et l'encre restent parfaitement cohérents.
    //
    // Le LISERÉ est atteignable par le MÊME patron que la famille sœur
    // (`ZStudyToolsItemCard`) : un slot explicite (`borderSide`/
    // `borderRadius`) ou son jeton construit la forme ; sinon
    // `CardThemeData.shape` de l'hôte prime, inchangé ; sinon le rayon `radiusM`
    // historique. Aucun de ces deux slots ⇒ arbre et pixel STRICTEMENT
    // identiques à l'historique.
    final BorderSide? resolvedSide = borderSide ?? theme.folderCardBorderSide;
    final Radius? resolvedCorner = borderRadius ?? theme.folderCardRadius;
    final ShapeBorder shape = resolvedSide != null || resolvedCorner != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.all(resolvedCorner ?? theme.radiusM),
            side: resolvedSide ?? BorderSide.none,
          )
        : cardTheme.shape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(theme.radiusM),
              );

    // Même traitement pour la MARGE : un widget qui imposerait une marge
    // figée à `EdgeInsets.zero` forcerait chaque hôte à la restituer par un
    // `Padding` externe, dupliquant la déclaration au lieu de la lire depuis
    // le `CardTheme`. Un hôte qui compense de la sorte doit RETIRER son
    // `Padding` externe : sinon les deux marges s'additionnent. Même motif
    // que sur `shape`, et même correction sur `ZStudyToolsItemCard` — pour ne
    // pas laisser le défaut réapparaître sur une troisième carte.
    // Défaut inchangé : sans `CardTheme.margin`, la marge reste nulle.
    final EdgeInsetsGeometry cardMargin = cardTheme.margin ?? EdgeInsets.zero;

    final bool interactive = onTap != null || onLongPress != null;

    final Widget cardContent = semanticTopAccent == null
        ? content
        : LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool bounded = constraints.maxHeight.isFinite;
              return Column(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                children: <Widget>[
                  SizedBox(width: double.infinity, child: semanticTopAccent),
                  if (bounded) Expanded(child: content) else content,
                ],
              );
            },
          );

    // Ombre pilotée par les jetons `cardShadow*`. `null` (aucun jeton) ⇒
    // chemin d'arbre STRICTEMENT identique à l'historique. Les jetons de
    // l'hôte PRIMENT le repli [defaultShadow] (patron `ZStudyToolsItemCard`).
    final BoxDecoration? shadow =
        zResolveCardShadowDecoration(context, shape: shape) ?? defaultShadow;

    final Widget innerCard = Card(
      // Quand l'ombre est peinte par la décoration, la marge doit rester HORS
      // de la boîte ombrée (sinon l'ombre épouse la marge, pas la carte) : elle
      // est alors portée par un `Padding` externe et le `Card` la met à zéro.
      margin: shadow == null ? cardMargin : EdgeInsets.zero,
      color: tint,
      shape: shape,
      // Deux ombres ne se superposent pas : l'élévation native cède la place à
      // l'ombre des jetons, qui la remplace intégralement.
      elevation: shadow == null ? null : 0,
      clipBehavior: Clip.antiAlias,
      child: interactive
          ? InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              customBorder: shape,
              // L'action sémantique est portée UNE SEULE fois — par le nœud de
              // la carte ci-dessous ; l'encre et le tap de pointeur restent.
              excludeFromSemantics: true,
              child: cardContent,
            )
          // AD-45 — pas d'`InkWell` inerte : l'absence d'activation est
          // structurelle, elle ne se rend pas comme un bouton éteint.
          : cardContent,
    );

    final Widget card = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kZFolderCardMinHeight),
      child: shadow == null
          ? innerCard
          : Padding(
              padding: cardMargin,
              child: DecoratedBox(decoration: shadow, child: innerCard),
            ),
    );

    // Libellé UNIQUE de la carte, identique dans les DEUX régimes : les
    // fragments internes (titre `:184`, badge `:177`) sont `ExcludeSemantics`
    // INCONDITIONNELLEMENT — ce nœud est donc le SEUL porteur de l'annonce.
    final String cardLabel =
        semanticLabel ?? (showArchived ? '$title, ${archivedLabel!}' : title);

    // AD-45 — sans aucune activation, pas de nœud `button` : l'absence de
    // capacité est structurelle, la carte n'est pas un bouton désactivé. Mais
    // « non interactive » ≠ « muette » (AD-13) : le CONTENU reste annoncé
    // (titre + état archivé + `semanticLabel` injecté), sans `button:` ni
    // `onTap:` — sinon les `ExcludeSemantics` ci-dessus rendraient la carte
    // totalement absente de l'arbre sémantique (WCAG 1.1.1 / 1.3.1).
    if (!interactive) {
      return Semantics(container: true, label: cardLabel, child: card);
    }

    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      label: cardLabel,
      child: card,
    );
  }
}

/// Ombre de carte **personnalisée** dérivée des jetons `ZcrudTheme.cardShadow*`.
///
/// Ces trois jetons sont déclarés, présents dans `copyWith`, interpolés dans
/// `lerp`, et lus ici par ce widget : un hôte qui les règle voit un effet
/// observable. *Un jeton que personne ne lit est un jeton qui ment.*
///
/// **Pourquoi `Card.elevation` ne suffit pas** : Material DÉRIVE le flou et le
/// décalage de l'élévation, sans permettre de les fixer. Tout hôte migrant
/// depuis une carte à ombre custom bute là — d'où une ombre peinte par une
/// [BoxDecoration] sous la carte, l'élévation native étant alors mise à zéro
/// pour ne pas superposer deux ombres.
///
/// Retourne `null` quand **aucun** des trois jetons n'est fourni : la carte
/// garde alors son ombre native, donc un **rendu strictement inchangé**. Dès
/// qu'un seul est fourni, les deux autres retombent sur
/// [kZCardShadowBlurRadius] / [kZCardShadowOffset] / [kZCardShadowAlpha] — des
/// valeurs volontairement NON neutres, pour que chacun des trois jetons ait un
/// effet observable **seul** (un flou nul rendrait `cardShadowAlpha` inerte —
/// exactement le défaut qu'un jeton non lu produirait).
///
/// La couleur vient du thème (`CardThemeData.shadowColor`, sinon
/// `ThemeData.shadowColor`) : aucune couleur codée en dur (invariant FR-26).
BoxDecoration? zResolveCardShadowDecoration(
  BuildContext context, {
  required ShapeBorder shape,
}) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  final double? blur = theme.cardShadowBlurRadius;
  final Offset? offset = theme.cardShadowOffset;
  final double? alpha = theme.cardShadowAlpha;
  if (blur == null && offset == null && alpha == null) return null;

  final Color base =
      CardTheme.of(context).shadowColor ?? Theme.of(context).shadowColor;
  final BoxShadow shadow = BoxShadow(
    color: base.withValues(alpha: (alpha ?? kZCardShadowAlpha).clamp(0.0, 1.0)),
    blurRadius: math.max(0, blur ?? kZCardShadowBlurRadius),
    offset: offset ?? kZCardShadowOffset,
  );

  // La silhouette de l'ombre suit la forme réelle de la carte, sinon l'ombre
  // déborderait des coins arrondis.
  if (shape is CircleBorder) {
    return BoxDecoration(shape: BoxShape.circle, boxShadow: <BoxShadow>[shadow]);
  }
  final BorderRadiusGeometry radius = shape is RoundedRectangleBorder
      ? shape.borderRadius
      : BorderRadius.all(theme.radiusM);
  return BoxDecoration(borderRadius: radius, boxShadow: <BoxShadow>[shadow]);
}

/// Badge discret « Archivé », en NEUTRE : fond `surfaceContainerHighest`,
/// texte `onSurfaceVariant`, rayon `badgeRadius` du thème (repli `radiusM`).
/// Aucune couleur codée en dur (invariant FR-26). Rendu **conditionnellement** par
/// [ZFolderCard] (jamais un badge muet).
class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.all(theme.badgeRadius ?? theme.radiusM),
      ),
      child: Text(
        label,
        textAlign: TextAlign.start,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
