/// Carte de dossier d'étude — **primitive de présentation à props PRIMITIVES**
/// (SUF-2). Réplique neutre du natif lex `FolderCard`
/// (`packages/lex_ui/lib/presentation/widgets/study/folder_card.dart`, LECTURE
/// SEULE) : même apparence (fond teinté `accent alpha 0.12`, pastille pleine,
/// titre 2 lignes ancré bas, badge « Archivé », menu ⋮) une fois bridgée.
///
/// ## Frontière (D1 — jamais l'entité)
///
/// Comme `z_study_mindmap_section.dart` prend un `folderId` opaque et jamais
/// `ZStudyFolder`, cette carte ne reçoit **que des primitives** ([title],
/// [colorKey]) et des **slots** ([counts], [menu]). Elle ne connaît **aucun**
/// type métier study, **aucune** clé sémantique (`success`/`warning`/…) ni
/// aucune règle de permissions : tout arrive par les props. Un besoin de savoir
/// « quel dossier » serait le signe d'une frontière mal placée.
///
/// ## Écarts NON-NÉGOCIABLES vs le natif lex (imposés par l'architecture zcrud)
///
/// - lex est un `ConsumerWidget` qui `ref.watch(folderCardCountProvider)` →
///   **INTERDIT** (AD-2/AD-15 : aucun gestionnaire d'état, `ConsumerWidget`
///   banni). Le compteur devient le **slot [counts]** injecté par l'hôte (D3,
///   superset lex compteur / IFFD badges — le widget n'en interprète jamais le
///   contenu).
/// - lex prend `StudyFolder folder` → **INTERDIT** (D1) : props primitives.
/// - lex fait `FolderColorPalette.colorFor(folder.colorKey)` (table locale) →
///   **INTERDIT** (D2) : l'accent dérive de [zResolveColorKeyOrSlot], seam
///   **total** du cœur (jamais `null`, jamais de throw — AD-10 ; contraste
///   Material 3 garanti). AUCUNE `Color(0x…)`, aucun `Colors.*`, aucune table de
///   couleurs ici.
/// - lex fait `l10n.folderArchivedBadge` → **INTERDIT** (D4) : le libellé
///   « Archivé » est INJECTÉ ([archivedLabel]) — le badge n'apparaît QUE si
///   [isArchived] `== true` **et** [archivedLabel] `!= null` (pas de texte en
///   dur, pas de badge muet).
///
/// ## Invariants (architecture.md — 16 AD)
///
/// - **AD-2 / AD-15** : `StatelessWidget` pur-Flutter, **aucun** état détenu
///   (pas de compteur, pas de sélection — tout est props/slots). Rien à disposer.
/// - **AD-4** : props opaques ; slot `null` ⇒ **absent** de l'arbre (jamais un
///   no-op, jamais un espace réservé).
/// - **AD-13 / FR-26** : `Semantics` explicites, cible ≥ 48 dp
///   ([kZFolderCardMinHeight]), insets/alignements **directionnels**
///   (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), rayon et
///   gaps depuis `ZcrudTheme.of(context)`, typo depuis `Theme.of(context)` —
///   aucun littéral. `const` où immuable.
/// - **AD-45** : absence d'activation = **structurelle** ([onTap] `== null` **et**
///   [onLongPress] `== null` ⇒ aucun `InkWell` inerte, aucun rôle `button`
///   annoncé — pas un bouton éteint). La carte non interactive reste néanmoins
///   **ANNONCÉE** (titre + état archivé + [semanticLabel]) : AD-45 interdit
///   d'annoncer un *bouton* éteint, pas de rendre le *contenu* muet (AD-13).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;

/// Hauteur minimale de la cible d'activation d'une [ZFolderCard] (AD-13). La
/// carte activable ne descend jamais en dessous, quel que soit son contenu.
const double kZFolderCardMinHeight = 48;

/// Teinte de fond par défaut d'une carte de dossier — parité lex
/// (`accent.withValues(alpha: 0.12)`). Dimension d'opacité (pas une couleur) :
/// exposée pour rester ajustable sans coder de couleur en dur (FR-26).
const double kZFolderCardTintAlpha = 0.12;

/// Diamètre de la pastille d'accent (dimension de LAYOUT — jamais une couleur).
/// Parité lex (`14×14`).
const double _kPastilleSize = 14;

/// Carte d'un dossier d'étude dans une grille (SUF-2).
///
/// ```dart
/// ZFolderCard(
///   title: 'Chapitre 3 — Valeur en douane',
///   colorKey: 'secondary',                 // opaque : résolue par le cœur/bridge
///   headerDecoration: myAccent,             // slot : remplace la pastille historique
///   counts: const Text('42 cartes'),        // slot : compteur lex OU badges IFFD
///   menu: myFolderMenu,                      // slot : le widget ignore son contenu
///   isArchived: true,
///   archivedLabel: 'Archivé',                // INJECTÉ (jamais de littéral)
///   onTap: () => openFolder(id),
///   onLongPress: () => showActions(id),
/// )
/// ```
///
/// La carte est la **cellule** ; la grille adaptative est posée par l'appelant
/// (`ZAdaptiveGrid.builder`, D5) — jamais réimplémentée ici.
class ZFolderCard extends StatelessWidget {
  /// Construit une carte de dossier ; seuls [title] et [colorKey] sont requis.
  const ZFolderCard({
    required this.title,
    required this.colorKey,
    this.colorSlotIndex = 0,
    this.headerDecoration,
    this.topAccent,
    this.counts,
    this.footer,
    this.menu,
    this.archivedLabel,
    this.isArchived = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.tintAlpha = kZFolderCardTintAlpha,
    super.key,
  });

  /// Titre du dossier — rendu sur **2 lignes ellipsées**, ancré en bas de la
  /// cellule (patron anti-overflow lex, cf. [build]).
  final String title;

  /// Clé de couleur **opaque** (`String`) résolue par [zResolveColorKeyOrSlot]
  /// (seam hôte `ZcrudScope.colorKeyResolver` prioritaire, sinon repli du cœur,
  /// sinon slot déterminé par [colorSlotIndex]). Le widget n'en connaît aucune
  /// valeur ; la dérivation d'index reste **côté app/bridge** (D2).
  final String colorKey;

  /// Index de repli déterministe passé tel quel à [zResolveColorKeyOrSlot] :
  /// utilisé **seulement** si [colorKey] reste inconnue du resolver (couleur
  /// contrastée distincte par index — AD-10).
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

  /// Slot compteur/badges rendu **verbatim**, ancré en bas (superset lex
  /// compteur / IFFD badges — D3). `null` ⇒ **absent** de l'arbre (aucun espace
  /// réservé). Le widget n'en interprète jamais le contenu.
  final Widget? counts;

  /// Slot de pied rendu sous le contenu. Il partage la même ligne que le badge
  /// archivé éventuel : ce dernier reste donc visible et n'est jamais remplacé.
  /// `null` ⇒ aucun espace réservé.
  final Widget? footer;

  /// Slot menu/trailing (ex. `IconButton` ⋮) rendu en tête, aligné en fin
  /// (RTL-safe). `null` ⇒ **absent**. **Non exclu** de la sémantique : un menu
  /// doit rester atteignable au lecteur d'écran (patron `ZStudyToolsItemCard`).
  final Widget? menu;

  /// Libellé du badge « Archivé » **INJECTÉ** (l10n) — jamais un littéral (D4).
  /// Le badge n'apparaît que si [isArchived] **et** `archivedLabel != null`.
  final String? archivedLabel;

  /// Dossier archivé : conditionne l'apparition du badge (avec [archivedLabel])
  /// et enrichit le libellé sémantique de la carte.
  final bool isArchived;

  /// Activation principale. `null` **avec** [onLongPress] `null` ⇒ carte non
  /// interactive : **aucun** `InkWell`, pas de rôle `button` (AD-45).
  final VoidCallback? onTap;

  /// Activation par appui long (ex. feuille d'actions). Voir [onTap] pour la
  /// règle d'absence structurelle.
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [archivedLabel] si le badge est présent — pour que le lecteur d'écran
  /// annonce la carte comme un tout, jamais comme une suite de fragments.
  final String? semanticLabel;

  /// Opacité de la teinte de fond dérivée de l'accent (défaut
  /// [kZFolderCardTintAlpha] = parité lex `0.12`). Dimension d'opacité, pas une
  /// couleur (FR-26).
  final double tintAlpha;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    // D2/AD-10 — accent DÉRIVÉ, jamais codé en dur : seam total du cœur.
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      colorKey,
      slotIndex: colorSlotIndex,
    );
    final Color tint = pair.color.withValues(alpha: tintAlpha);

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
      if (showArchived) ...<Widget>[
        SizedBox(width: theme.gapS),
        // ExcludeSemantics : le texte du badge est DÉJÀ porté par le `label` du
        // nœud de la carte (repli enrichi) — le répéter le ferait annoncer deux
        // fois. Le badge reste visuellement présent.
        ExcludeSemantics(child: _ArchivedBadge(label: archivedLabel!)),
      ],
    ];

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

    // D6 / AC9 vs AC6 — deux régimes selon la hauteur DISPONIBLE, décidés par un
    // `LayoutBuilder` (jamais un layout de grille : la grille reste posée par
    // l'appelant, D5) :
    //   • hauteur BORNÉE (cellule de `ZAdaptiveGrid.builder`, hauteur pilotée par
    //     `itemHeight`) ⇒ patron anti-overflow lex : `Expanded(Align(bottomStart))`
    //     absorbe la hauteur résiduelle, le titre est ancré EN BAS puis ellipsé
    //     ⇒ JAMAIS d'overflow (contrairement à un `Spacer` + hauteurs fixes).
    //   • hauteur NON BORNÉE (usage autonome / min-content) ⇒ colonne
    //     `MainAxisSize.min` sizée au contenu, plancher assuré par le
    //     `ConstrainedBox(minHeight: kZFolderCardMinHeight)` (AD-13) — un
    //     `Expanded` y lèverait « unbounded height ».
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = constraints.maxHeight.isFinite;
        return Padding(
          padding: EdgeInsetsDirectional.all(theme.gapM),
          child: Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // En-tête : décoration injectée ou pastille pleine d'accent +
              // menu aligné en fin (RTL-safe).
              Row(
                children: <Widget>[
                  headerDecoration ??
                      Container(
                        width: _kPastilleSize,
                        height: _kPastilleSize,
                        decoration: BoxDecoration(
                          color: pair.color,
                          shape: BoxShape.circle,
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
                    child: titleText,
                  ),
                )
              else
                titleText,
              if (footerChildren.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.gapS),
                Row(children: footerChildren),
              ],
            ],
          ),
        );
      },
    );

    // Le thème Material de l'hôte décide la forme complète (dont sa bordure)
    // lorsqu'il en fournit une. La même instance est donnée au `Card` et à
    // l'`InkWell` pour que le clip et l'encre restent parfaitement cohérents.
    final CardThemeData cardTheme = CardTheme.of(context);
    final ShapeBorder shape =
        cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.all(theme.radiusM));

    // 🔴 Même traitement pour la MARGE (CR-LEX-73). Elle était figée à
    // `EdgeInsets.zero`, si bien que chaque hôte la restituait par un `Padding`
    // externe — lex l'a fait, et signale que « tout autre hôte devra la
    // réécrire ». C'est le motif E3 déjà corrigé sur `shape` (CR-LEX-61) : un
    // widget qui impose une décision que le `CardTheme` exprime déjà force
    // l'hôte à la déclarer deux fois. La CR demandait la correction sur les
    // DEUX widgets porteurs du défaut, pour ne pas la voir réapparaître sur un
    // troisième — `ZStudyToolsItemCard` porte la même.
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

    final Widget card = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kZFolderCardMinHeight),
      child: Card(
        margin: cardMargin,
        color: tint,
        shape: shape,
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

/// Badge discret « Archivé » — parité lex `_ArchivedBadge` en NEUTRE : fond
/// `surfaceContainerHighest`, texte `onSurfaceVariant`, rayon `badgeRadius` du
/// thème (repli `radiusM`).
/// Aucune couleur codée en dur (FR-26). Rendu **conditionnellement** par
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
