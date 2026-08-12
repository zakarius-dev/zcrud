/// `ZDefaultFolderCard` — carte de dossier d'étude par défaut du socle,
/// sixième et dernier rendu par défaut de la famille.
///
/// ## Ce que cette carte ferme
///
/// Cinq types sur six avaient un rendu par défaut ; la carte de dossier était
/// la seule à n'être qu'une primitive à slots (`ZFolderCard`), que chaque
/// hôte re-décorait avec ses propres constantes. Une carte qui vit dans
/// chaque application est gelée au jour de sa copie, alors que le socle
/// continue d'évoluer.
///
/// La primitive n'est pas remplacée : cette carte est bâtie sur
/// `ZFolderCard` et n'en réécrit aucun comportement. Un hôte qui emploie
/// `ZFolderCard` telle quelle rend exactement le même pixel qu'avant
/// l'introduction de ce rendu par défaut (garde dédiée) : tout le nouveau
/// rendu est opt-in, ici.
///
/// ## Le rendu de référence
///
/// Sans aucun réglage : carte neutre (surface du `CardTheme`), bande
/// d'accent de 4 dp en tête, liseré fin sur le pourtour, tuile
/// d'icône 36 dp au coin de 8 dp teintée à 15 %, titre 2 lignes ancré bas,
/// sous-titre teinté, badges de compteur au rayon 6 sur fond teinté à
/// 10 %, ombre douce `8 / (0,2) / 0.06 clair · 0.2 sombre`. Toutes ces valeurs
/// vivent dans [ZFolderCardReference] — le point d'audit unique.
///
/// Priorité, partout : paramètre > jeton `ZcrudTheme.folderCard*` >
/// défaut-référence.
///
/// ## Le contraste, pour une couleur arbitraire
///
/// Une couleur de dossier est choisie par l'utilisateur. Un rendu antérieur
/// peignait la bande, la tuile, le glyphe et le texte de badge dans cette
/// couleur brute, et le port HSL du socle (`zReadableTypeTint`) ne bornait que
/// la clarté HSL — pas le contraste : mesuré, `#FFFF00` rendait 2.13:1 et
/// `#FFFFFE` 1.28:1 sur thème clair. Toutes les couleurs peintes par cette
/// carte passent donc par [zReadableTintOn], qui garantit un plancher
/// mesuré contre la surface réellement peinte :
///
/// | élément                     | surface de mesure                | plancher |
/// |-----------------------------|----------------------------------|----------|
/// | bande d'accent, liseré      | fond de carte (teinté si besoin) | **3.0**  |
/// | glyphe de tuile             | tuile (couleur @ 15 % composée)  | **3.0**  |
/// | libellé/glyphe de badge     | badge (couleur @ 10 % composée)  | **4.5**  |
/// | sous-titre                  | fond de carte                    | **4.5**  |
///
/// ## Invariants
///
/// - Invariant FR-26 : aucune couleur ni libellé en dur ; tout texte visible
///   est injecté ; `null` ⇒ absent de l'arbre (invariant AD-4), jamais un
///   `SizedBox.shrink()` inerte.
/// - Invariant AD-13 : insets et alignements directionnels, cible ≥ 48 dp
///   (héritée de la primitive), et la couleur n'est jamais le seul canal —
///   la couleur du dossier est un canal supplémentaire : titre, sous-titre et
///   libellés de badge portent l'information en texte, la tuile porte un
///   glyphe, l'état archivé un libellé.
/// - Invariant AD-2 : `StatelessWidget` pur, `const` partout où c'est possible,
///   aucun état détenu, aucune liste matérialisée.
/// - Invariant AD-10 : chaîne de repli totale — une clé de couleur inconnue ne
///   fait jamais échouer le rendu (créneau déterministe du cœur).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZFolderCardFooterPlacement,
        ZcrudTheme,
        zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_folder_card.dart';
import 'z_folder_card_reference.dart';
import 'z_readable_tint.dart';

/// Un badge de compteur de la carte de dossier par défaut : un glyphe et un
/// libellé déjà localisés par l'hôte (« 12 fiches », « 3 sous-dossiers »).
///
/// Le socle ne compte rien et ne traduit rien (invariants AD-2/FR-26) : il
/// rend ce que l'hôte lui donne, à la mesure de [ZFolderCardReference].
///
/// Pourquoi pas `ZCountBadgeSpec` (le type de la famille « déclencheur
/// de sous-dossier ») : celui-ci porte un entier et une icône déjà
/// construite en `Widget`, et sa rangée filtre les comptes nuls. Le badge de
/// carte de dossier porte, lui, un libellé déjà composé et localisé
/// (« 3 sous-dossiers », « 12 fiches ») et un `IconData` teinté au rendu par la
/// carte — le socle ne peut ni composer ni accorder ce libellé (invariant
/// FR-26). Les deux ne sont pas interchangeables ; les confondre obligerait
/// la carte à fabriquer du texte.
@immutable
class ZFolderCardCount {
  /// Construit un badge ; [icon] et [label] sont requis.
  const ZFolderCardCount({
    required this.icon,
    required this.label,
    this.semanticLabel,
  });

  /// Glyphe du badge (11 dp — [ZFolderCardReference.badgeGlyphSize]).
  final IconData icon;

  /// Libellé injecté (déjà localisé). C'est lui qui porte l'information :
  /// la couleur du badge n'en est qu'un rappel (invariant AD-13).
  final String label;

  /// Annonce alternative pour le lecteur d'écran. `null` ⇒ [label] est annoncé
  /// tel quel (jamais un badge muet).
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is ZFolderCardCount &&
      other.icon == icon &&
      other.label == label &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(icon, label, semanticLabel);
}

/// Carte de dossier d'étude par défaut du socle.
///
/// ```dart
/// ZDefaultFolderCard(
///   title: folder.name,
///   subtitle: subjectNameOf(folder),          // option (invariant AD-4)
///   colorKey: folder.colorKey,                // opaque : résolue par le cœur
///   counts: <ZFolderCardCount>[
///     ZFolderCardCount(icon: Icons.style_outlined, label: l10n.cards(n)),
///   ],
///   menu: myFolderMenu,                        // rendu verbatim
///   archivedLabel: l10n.archived,              // injecté (jamais un littéral)
///   isArchived: folder.isArchived,
///   onTap: () => open(folder),
/// )
/// ```
class ZDefaultFolderCard extends StatelessWidget {
  /// Construit la carte ; seul [title] est requis.
  const ZDefaultFolderCard({
    required this.title,
    this.subtitle,
    this.icon,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.counts = const <ZFolderCardCount>[],
    this.countsSlot,
    this.belowSubtitle,
    this.menu,
    this.footer,
    this.footerPlacement,
    this.footerBesideMinWidth,
    this.accent,
    this.archivedLabel,
    this.isArchived = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderSide,
    this.borderRadius,
    this.contentPadding,
    this.accentHeight,
    this.tintAlpha,
    this.minContrast,
    this.iconTileSize,
    this.iconTileRadius,
    this.iconTileTintAlpha,
    this.glyphSize,
    super.key,
  });

  /// Titre du dossier (déjà localisé) — seule entrée requise.
  final String title;

  /// Classement du dossier (matière, cours, client…), déjà localisé.
  /// `null` ⇒ absent de l'arbre (invariant AD-4).
  final String? subtitle;

  /// Glyphe de la tuile de tête. `null` ⇒ [ZFolderCardReference.glyph].
  final IconData? icon;

  /// Palette injectée bornant la clé d'accent (patron `ZTagChips`).
  final ZColorPalette palette;

  /// Clé d'identité de la couleur du dossier (`String` opaque). `null` ⇒
  /// dérivée du titre — stable pour un même dossier (remap déterministe du
  /// kernel), jamais un index d'affichage.
  final String? colorKey;

  /// Badges de compteur typés, rendus à la mesure de la référence. Vide ⇒
  /// zone absente (invariant AD-4). Ignoré si [countsSlot] est fourni.
  final List<ZFolderCardCount> counts;

  /// Slot compteur brut (échappatoire) : rendu verbatim à la place des
  /// badges typés, pour l'hôte qui compose lui-même sa zone de compteurs.
  /// `null` ⇒ [counts] gouverne.
  final Widget? countsSlot;

  /// Contenu additionnel rendu sous le sous-titre, dans la même colonne.
  /// `null` ⇒ absent. Coexiste avec [subtitle] (les deux s'empilent).
  final Widget? belowSubtitle;

  /// Slot menu (ex. `IconButton` ⋮), rendu verbatim en tête, aligné en fin
  /// (RTL-safe). Le socle n'en fabrique aucun : la mesure de référence du
  /// glyphe est exposée par [ZFolderCardReference.menuGlyphSize].
  final Widget? menu;

  /// Slot de pied rendu verbatim (ligne de créateur, méta…). `null` ⇒
  /// absent.
  ///
  /// Il n'ampute plus les compteurs : voir [footerPlacement].
  final Widget? footer;

  /// Disposition du bas de carte. `null` ⇒ jeton
  /// `ZcrudTheme.folderCardFooterPlacement`, puis
  /// [ZFolderCardReference.footerPlacement]
  /// ([ZFolderCardFooterPlacement.below] — le pied empilé sous les
  /// compteurs, à toute largeur ; voir cette constante pour les mesures qui ont
  /// écarté un défaut adaptatif, et pour ce qui change à l'écran).
  ///
  /// Ce qui a été mesuré : avec [counts] et [footer], la primitive
  /// donnait la moitié de la largeur à chacun — une carte à quatre badges n'en
  /// montrait plus que deux, et le pied s'accolait au dernier badge visible. Le
  /// seul contournement, recomposer le créneau compteur via [countsSlot], rend
  /// le rendu des badges à l'hôte et lui fait donc perdre le plancher de
  /// contraste que cette carte garantit. Empiler le ferme sans
  /// rien rendre à l'hôte : les badges restent peints ici, par `zReadableTintOn`.
  final ZFolderCardFooterPlacement? footerPlacement;

  /// Seuil de largeur du régime [ZFolderCardFooterPlacement.adaptive], mesuré
  /// sur la largeur offerte au bas de carte. `null` ⇒ jeton
  /// `ZcrudTheme.folderCardFooterBesideMinWidth`, puis
  /// [ZFolderCardReference.footerBesideMinWidth].
  final double? footerBesideMinWidth;

  /// Bande d'accent de tête de remplacement (ex. un dégradé d'identité).
  /// `null` ⇒ la bande de référence, unie, dérivée de la couleur du dossier et
  /// corrigée en contraste.
  ///
  /// Un accent injecté est rendu tel quel : le plancher de contraste ne
  /// s'applique alors plus (c'est l'hôte qui l'a peint).
  final Widget? accent;

  /// Libellé du badge « Archivé » injecté — jamais un littéral. Le badge
  /// n'apparaît que si [isArchived] et `archivedLabel != null`.
  final String? archivedLabel;

  /// Dossier archivé.
  ///
  /// Mesuré : le socle n'applique aucune atténuation à une carte
  /// archivée — ni opacité, ni désaturation. L'état archivé ajoute un badge
  /// textuel et enrichit l'annonce ; la teinte et le liseré sont
  /// inchangés, donc leur contraste mesuré l'est aussi (garde dédiée). Il
  /// n'y a donc aucun cumul d'atténuations à craindre — et rien à porter.
  final bool isArchived;

  /// Activation principale. `null` avec [onLongPress] `null` ⇒ carte non
  /// interactive : aucun `InkWell`, pas de rôle `button`.
  final VoidCallback? onTap;

  /// Activation par appui long.
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title] (+ le libellé
  /// archivé si le badge est présent).
  final String? semanticLabel;

  /// Liseré. `null` ⇒ jeton `folderCardBorderSide`, puis liseré de référence
  /// **dérivé de la couleur du dossier** et corrigé en contraste.
  final BorderSide? borderSide;

  /// Rayon de la carte. `null` ⇒ jeton `folderCardRadius`, puis référence (12).
  final Radius? borderRadius;

  /// Padding interne. `null` ⇒ jeton `folderCardContentPadding`, puis
  /// référence (12).
  final EdgeInsetsGeometry? contentPadding;

  /// Hauteur de la bande d'accent. `null` ⇒ jeton `folderCardAccentHeight`,
  /// puis référence (4). Une valeur ≤ 0 supprime la bande (invariant AD-4 :
  /// absente de l'arbre, jamais une bande de hauteur nulle).
  final double? accentHeight;

  /// Opacité de la teinte de fond. `null` ⇒ jeton `folderCardTintAlpha`, puis
  /// jeton `cardTintAlpha`, puis référence (**0** — carte neutre).
  final double? tintAlpha;

  /// Plancher de contraste des surfaces et composants graphiques. `null` ⇒
  /// jeton `folderCardMinContrast`, puis référence (3.0).
  final double? minContrast;

  /// Côté de la tuile d'icône. `null` ⇒ jeton, puis référence (36).
  final double? iconTileSize;

  /// Rayon de la tuile d'icône. `null` ⇒ jeton, puis référence (8).
  final Radius? iconTileRadius;

  /// Opacité de la teinte de la tuile. `null` ⇒ jeton, puis référence (0.15).
  final double? iconTileTintAlpha;

  /// Taille du glyphe de la tuile. `null` ⇒ jeton, puis référence (20).
  final double? glyphSize;

  /// Clé de la bande d'accent de référence (testabilité).
  static const ValueKey<String> accentKey = ValueKey<String>(
    'zDefaultFolderCard_accent',
  );

  /// Clé de la tuile d'icône (testabilité).
  static const ValueKey<String> iconTileKey = ValueKey<String>(
    'zDefaultFolderCard_iconTile',
  );

  /// Clé de la zone de badges de compteur (testabilité).
  static const ValueKey<String> countsKey = ValueKey<String>(
    'zDefaultFolderCard_counts',
  );

  /// Clé du sous-titre (testabilité).
  static const ValueKey<String> subtitleKey = ValueKey<String>(
    'zDefaultFolderCard_subtitle',
  );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ThemeData material = Theme.of(context);
    // Identité stable du dossier : remap déterministe du kernel, calculé une
    // fois (il gouverne à la fois la clé passée à la primitive et le créneau
    // de repli — les deux doivent désigner la même couleur).
    final String identityKey = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      seedTitle: title,
    );
    final int identitySlot = palette.indexOf(identityKey);
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      identityKey,
      slotIndex: identitySlot,
    );

    final double resolvedTint =
        tintAlpha ??
        theme.folderCardTintAlpha ??
        theme.cardTintAlpha ??
        ZFolderCardReference.tintAlpha;
    final double floor =
        minContrast ??
        theme.folderCardMinContrast ??
        ZFolderCardReference.minContrast;

    // ── La surface réellement peinte sous les accents ────────────────────────
    // Mesurer le contraste contre la surface nue serait faux dès que la
    // carte est teintée — le fond est alors `couleur du dossier @ tintAlpha`
    // composée sur la surface, donc déjà proche de la teinte. C'est la
    // composition qui est mesurée, pas la surface nominale.
    final Color baseSurface =
        CardTheme.of(context).color ?? material.colorScheme.surfaceContainerLow;
    final Color cardSurface = resolvedTint <= 0
        ? baseSurface
        : zCompositeOver(
            pair.color.withValues(alpha: math.min(1, resolvedTint)),
            baseSurface,
          );

    // Teinte LISIBLE de la carte : bande + liseré, plancher garanti sur la
    // surface ci-dessus, pour une couleur d'entrée ARBITRAIRE.
    final Color readable = zReadableTintOn(
      pair.color,
      surface: cardSurface,
      minContrast: floor,
    );

    final double resolvedAccentHeight =
        accentHeight ??
        theme.folderCardAccentHeight ??
        ZFolderCardReference.accentBandHeight;

    // Invariant AD-4 — une bande de hauteur nulle serait un nœud inerte : elle
    // est absente de l'arbre.
    final Widget? band =
        accent ??
        (resolvedAccentHeight <= 0
            ? null
            : SizedBox(
                key: accentKey,
                height: resolvedAccentHeight,
                child: ColoredBox(color: readable),
              ));

    return ZFolderCard(
      title: title,
      // La clé d'identité est déjà remappée : le créneau de repli suit la
      // même palette (chaîne totale, invariant AD-10).
      colorKey: identityKey,
      colorSlotIndex: identitySlot,
      tintAlpha: resolvedTint,
      topAccent: band,
      headerDecoration: _buildIconTile(context, theme, pair, cardSurface, floor),
      menu: menu,
      belowSubtitle: _buildBelowSubtitle(context, theme, pair, cardSurface),
      counts: _buildCounts(context, theme, pair, cardSurface),
      footer: footer,
      // Priorité paramètre > jeton > référence de la carte par
      // défaut : la primitive, elle, reste sur son défaut historique quand
      // personne ne déclare rien (elle ne reçoit jamais `null` d'ici).
      footerPlacement:
          footerPlacement ??
          theme.folderCardFooterPlacement ??
          ZFolderCardReference.footerPlacement,
      // Laissé tel quel (donc `null` par défaut) : la primitive applique la
      // MÊME chaîne jeton > constante, et il n'existe qu'un seuil dans le socle.
      footerBesideMinWidth: footerBesideMinWidth,
      archivedLabel: archivedLabel,
      isArchived: isArchived,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      borderSide:
          borderSide ??
          theme.folderCardBorderSide ??
          BorderSide(color: readable, width: ZFolderCardReference.borderWidth),
      borderRadius:
          borderRadius ??
          theme.folderCardRadius ??
          ZFolderCardReference.cardRadius,
      contentPadding:
          contentPadding ??
          theme.folderCardContentPadding ??
          ZFolderCardReference.contentPadding,
      defaultShadow: _referenceShadow(material),
    );
  }

  /// Ombre douce de référence — repli sous les jetons `cardShadow*` de l'hôte
  /// (qui priment). Couleur = rôle `shadowColor` : un rendu antérieur y
  /// écrivait une couleur noire en dur, jamais reproduit ici (invariant
  /// FR-26).
  BoxDecoration _referenceShadow(ThemeData material) => BoxDecoration(
    borderRadius: BorderRadius.all(
      borderRadius ?? ZFolderCardReference.cardRadius,
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: material.shadowColor.withValues(
          alpha: material.brightness == Brightness.dark
              ? ZFolderCardReference.shadowAlphaDark
              : ZFolderCardReference.shadowAlphaLight,
        ),
        blurRadius: ZFolderCardReference.shadowBlurRadius,
        offset: ZFolderCardReference.shadowOffset,
      ),
    ],
  );

  /// Tuile d'icône de tête — décorative (`ExcludeSemantics`) : le titre
  /// porte déjà l'information, la tuile n'est qu'un rappel visuel (invariant
  /// AD-13).
  Widget _buildIconTile(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    Color cardSurface,
    double floor,
  ) {
    final double side =
        iconTileSize ??
        theme.folderCardIconTileSize ??
        ZFolderCardReference.iconTileSize;
    final Radius corner =
        iconTileRadius ??
        theme.folderCardIconTileRadius ??
        ZFolderCardReference.iconTileRadius;
    final double alpha =
        iconTileTintAlpha ??
        theme.folderCardIconTileTintAlpha ??
        ZFolderCardReference.iconTileTintAlpha;
    // Le glyphe se mesure contre la tuile, pas contre la carte : la tuile est
    // déjà teintée, mesurer contre la carte surestimerait le contraste.
    final Color tileSurface = zCompositeOver(
      pair.color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      cardSurface,
    );
    return ExcludeSemantics(
      child: SizedBox(
        key: iconTileKey,
        width: side,
        height: side,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tileSurface,
            borderRadius: BorderRadius.all(corner),
          ),
          child: Center(
            child: Icon(
              icon ?? ZFolderCardReference.glyph,
              size:
                  glyphSize ??
                  theme.folderCardGlyphSize ??
                  ZFolderCardReference.glyphSize,
              color: zReadableTintOn(
                pair.color,
                surface: tileSurface,
                minContrast: floor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sous-titre teinté + contenu additionnel de l'hôte. `null` ⇒ slot
  /// absent de l'arbre (invariant AD-4) — jamais un espace réservé.
  Widget? _buildBelowSubtitle(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    Color cardSurface,
  ) {
    final String? label = subtitle;
    final Widget? extra = belowSubtitle;
    if (label == null) return extra;

    final TextTheme text = Theme.of(context).textTheme;
    // Le rendu antérieur peint la couleur du dossier @ 0.8 : on part de cette
    // composition (donc du même rendu visé), puis on la corrige au plancher du
    // texte — c'est du texte au corps courant, pas un objet graphique.
    final Color soft = zCompositeOver(
      pair.color.withValues(alpha: ZFolderCardReference.subtitleAlpha),
      cardSurface,
    );
    final Widget subtitleText = Padding(
      padding: const EdgeInsetsDirectional.only(
        top: ZFolderCardReference.subtitleGap,
      ),
      child: Text(
        label,
        key: subtitleKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: text.bodySmall?.copyWith(
          fontSize: ZFolderCardReference.subtitleFontSize,
          color: zReadableTintOn(
            soft,
            surface: cardSurface,
            minContrast: ZFolderCardReference.textMinContrast,
          ),
        ),
      ),
    );
    if (extra == null) return subtitleText;
    // Mesuré : dans un slot prêté en fit loose, des enfants inflexibles
    // s'ajoutent à la hauteur au lieu d'y participer — chaque bloc est donc
    // `Flexible`, l'espacement compris.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(child: subtitleText),
        Flexible(
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: theme.gapS),
            child: extra,
          ),
        ),
      ],
    );
  }

  /// Zone de badges de compteur. `null` ⇒ absente (invariant AD-4).
  Widget? _buildCounts(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    Color cardSurface,
  ) {
    final Widget? raw = countsSlot;
    if (raw != null) return raw;
    if (counts.isEmpty) return null;

    final Color badgeSurface = zCompositeOver(
      pair.color.withValues(
        alpha: ZFolderCardReference.badgeBackgroundAlpha,
      ),
      cardSurface,
    );
    // Le libellé d'un badge est du texte : plancher 4.5, mesuré contre le fond
    // du badge (déjà teinté), jamais contre la carte.
    final Color onBadge = zReadableTintOn(
      pair.color,
      surface: badgeSurface,
      minContrast: ZFolderCardReference.textMinContrast,
    );
    final TextStyle? style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: ZFolderCardReference.badgeFontSize,
      fontWeight: ZFolderCardReference.badgeFontWeight,
      color: onBadge,
    );
    // Défilement horizontal : une rangée de badges ne déborde
    // jamais, même sous ~160 dp de largeur de cellule.
    return SingleChildScrollView(
      key: countsKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ZFolderCardReference.badgeSpacing,
        children: <Widget>[
          for (final ZFolderCardCount count in counts)
            _ZCountBadge(
              count: count,
              background: badgeSurface,
              foreground: onBadge,
              style: style,
            ),
        ],
      ),
    );
  }
}

/// Badge de compteur au dessin de référence — fond teinté à 10 %, rayon 6,
/// glyphe 11 dp, libellé 10/w600. Aucune couleur en dur : tout est dérivé.
class _ZCountBadge extends StatelessWidget {
  const _ZCountBadge({
    required this.count,
    required this.background,
    required this.foreground,
    required this.style,
  });

  final ZFolderCardCount count;
  final Color background;
  final Color foreground;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: count.semanticLabel ?? count.label,
    child: Container(
      padding: ZFolderCardReference.badgePadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(ZFolderCardReference.badgeRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ZFolderCardReference.badgeGlyphGap,
        children: <Widget>[
          Icon(
            count.icon,
            size: ZFolderCardReference.badgeGlyphSize,
            color: foreground,
          ),
          // Le texte du badge est déjà porté par le `label` du nœud ci-dessus :
          // l'exclure évite la double annonce, sans le rendre muet.
          ExcludeSemantics(
            child: Text(
              count.label,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    ),
  );
}
