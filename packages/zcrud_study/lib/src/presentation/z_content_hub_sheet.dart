/// `ZContentHubSheet` — feuille d'ajout de contenu paramétrique, au rendu de
/// référence.
///
/// Remplace deux monolithes historiques par une projection
/// présentation paramétrée : icône/label/hint/intitulé de section/libellé de
/// badge sont injectés (i18n, invariants AD-13/FR-26), jamais codés en dur.
/// Entrée désactivée (`enabled == false`) ou sans callback (`onTap == null`)
/// ⇒ non actionnable (invariant AD-4 — capacité absente, jamais un no-op
/// silencieux).
///
/// ## Le défaut a changé, et c'est une rupture de rendu
///
/// Le rendu antérieur manquait de quatre choses : pas de groupement, pas
/// d'identité visuelle par entrée, pas de mise en avant (détournée par `hint`
/// chez l'hôte, à contrecœur et déclaré), pas de forme réglable. Le
/// propriétaire du socle a arbitré que le rendu de référence historique
/// devienne le défaut — sections titrées, pastille circulaire teintée,
/// badge, entrées en cartes, chevron, hauteur d'item de référence assumée,
/// défilement attendu.
///
/// Cette décision contredit délibérément la densité compacte antérieure,
/// jugée meilleure à grande échelle : à douze types la mise en page de
/// référence demande plusieurs écrans. Ce n'est pas réfuté — c'est répondu
/// par le réglage : `density: ZContentHubDensity.compact`
/// (paramètre) ou `ZcrudTheme.contentHubDensity` (jeton) restitue exactement la
/// densité d'avant. La densité n'a pas disparu ; elle a cessé d'être le défaut.
///
/// Tout hôte passif voit son rendu changer sans avoir rien demandé. C'est
/// assumé et déclaré : écart de conception, pas une parité.
///
/// ## Priorité de résolution, partout
///
/// paramètre (feuille ou entrée) > jeton `ZcrudTheme.contentHub*` >
/// [ZContentHubReference].
///
/// ## Invariants
///
/// * Invariants AD-2/AD-15 : aucun gestionnaire d'état (réactivité
///   Flutter-native pure) ; slivers builder (jamais de liste matérialisée) ;
///   `const` partout où c'est possible.
/// * Invariant AD-4 : un slot `null` (intitulé de section, badge, hint) est
///   absent de l'arbre — jamais un `SizedBox.shrink()` inerte.
/// * Invariant AD-10 : chaîne de repli totale — une palette vide, un créneau
///   inconnu, une section sans entrée ne font jamais échouer le rendu.
/// * Invariant AD-13 : insets/alignements directionnels, `Semantics`
///   explicites, cible ≥ 48 dp, chevron retourné en RTL — et la couleur
///   n'est jamais le seul canal : le libellé porte l'information, la teinte
///   n'en est qu'un rappel, la mise en avant est textuelle donc lue par un
///   lecteur d'écran (ce qui rend inutile un détournement de `hint`).
/// * Invariant FR-26 : aucune couleur ni libellé en dur ici — les teintes de
///   référence vivent dans [ZContentHubReference] (exception FR-26 encadrée,
///   exemptée nominativement par la garde de source).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZContentHubDensity, ZcrudTheme;

import 'z_content_hub_reference.dart';
import 'z_readable_tint.dart';

/// Une entrée du hub d'ajout — data-class de présentation immuable (`const`).
///
/// [icon]/[label] sont injectés (jamais un glyphe/libellé codé en dur).
/// [enabled] `false` ou [onTap] `null` ⇒ entrée non actionnable (invariant
/// AD-4).
@immutable
class ZContentHubEntry {
  /// Construit une entrée du hub.
  const ZContentHubEntry({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.hint,
    this.onTap,
    this.tint,
    this.colorKey,
    this.badgeLabel,
    this.badgeSemanticLabel,
  });

  /// Glyphe injecté de l'entrée (jamais codé en dur).
  final IconData icon;

  /// Libellé localisé injecté (i18n, invariants AD-13/FR-26). C'est lui qui
  /// porte l'information : la teinte d'identité n'en est qu'un rappel
  /// (invariant AD-13 — la couleur n'est jamais le seul canal).
  final String label;

  /// Entrée actionnable (défaut `true`). `false` ⇒ tuile désactivée.
  final bool enabled;

  /// Aide/indice localisé injecté (optionnel). `null` ⇒ absent de l'arbre.
  ///
  /// Ce n'est pas le créneau d'une mise en avant : un rendu antérieur
  /// détournait `hint` pour y écrire « Recommandé », faute de mieux. Le
  /// créneau existe désormais — [badgeLabel] — et le détournement est
  /// inutile.
  final String? hint;

  /// Callback d'activation. `null` ⇒ entrée non actionnable (invariant AD-4).
  final VoidCallback? onTap;

  /// Teinte d'identité injectée de l'entrée — le canal le
  /// plus prioritaire. `null` ⇒ créneau déterministe de [colorKey] (à
  /// défaut de [label]) dans la palette de la feuille.
  ///
  /// Toute teinte peinte est portée au plancher de contraste par
  /// `zReadableTintOn` : un rendu antérieur peignait la teinte brute, sans
  /// mesure ni branche de luminosité.
  final Color? tint;

  /// Clé d'identité opaque et stable de l'entrée (`'flashcards.ai'`…), qui
  /// gouverne son créneau de teinte. `null` ⇒ dérivée du [label].
  ///
  /// Jamais un index d'affichage : c'est ce qui rend la teinte stable
  /// quand une application insère un type au milieu. Une clé explicite la
  /// rend en outre stable d'une langue à l'autre, ce que le repli par
  /// libellé ne garantit pas.
  final String? colorKey;

  /// Libellé de mise en avant localisé injecté (« Recommandé »…). `null` ⇒
  /// badge absent de l'arbre (invariant AD-4).
  ///
  /// Requis ou nullable, jamais un défaut littéral : `badgeLabel =
  /// 'Recommandé'` fuirait en français dans une application anglaise sans voie
  /// d'override. Le canal est textuel donc accessible.
  final String? badgeLabel;

  /// Annonce alternative du badge. `null` ⇒ [badgeLabel] est annoncé tel quel.
  final String? badgeSemanticLabel;

  /// `true` ssi l'entrée est activée et porte un callback (invariant AD-4).
  bool get isActionable => enabled && onTap != null;
}

/// Un groupe titré d'entrées du hub.
///
/// Un rendu antérieur ne titrait pas les familles et rendait une liste
/// plate. C'est un argument d'échelle, pas de goût : le composant dont la
/// raison d'être est d'accueillir de nouveaux types doit rester lisible
/// quand on en accueille.
@immutable
class ZContentHubSection {
  /// Construit une section ; seules les [entries] sont requises.
  const ZContentHubSection({
    required this.entries,
    this.title,
    this.semanticLabel,
  });

  /// Entrées de la section, dans l'ordre voulu (aucun tri implicite).
  final List<ZContentHubEntry> entries;

  /// Intitulé localisé injecté de la section. `null` ⇒ section sans
  /// en-tête : l'intitulé est absent de l'arbre (invariant AD-4), jamais un
  /// texte vide réservant de la place.
  ///
  /// Nullable sans défaut littéral (invariant FR-26) — le socle ne connaît ni
  /// « Flashcards » ni « Documents ».
  final String? title;

  /// Annonce alternative de l'en-tête. `null` ⇒ [title] est annoncé tel quel.
  final String? semanticLabel;
}

/// Feuille d'ajout de contenu paramétrique, au rendu de référence.
///
/// Testable en isolation (widget nu) ou présentée en modale via [show].
///
/// ```dart
/// ZContentHubSheet(
///   sections: <ZContentHubSection>[
///     ZContentHubSection(
///       title: l10n.flashcards,                       // injecté
///       entries: <ZContentHubEntry>[
///         ZContentHubEntry(
///           icon: Icons.auto_awesome,
///           label: l10n.generateWithAi,
///           colorKey: 'flashcards.ai',                 // teinte stable
///           badgeLabel: l10n.recommended,              // mise en avant texte
///           onTap: fa.gate('flashcards.ai', _generate),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
class ZContentHubSheet extends StatelessWidget {
  /// Construit la feuille.
  ///
  /// [entries] et [sections] coexistent : les [entries] forment une section
  /// sans intitulé rendue en tête, puis viennent les [sections]. Rien
  /// n'est jamais silencieusement perdu (invariant AD-10).
  const ZContentHubSheet({
    this.entries = const <ZContentHubEntry>[],
    this.sections = const <ZContentHubSection>[],
    this.density,
    this.itemExtent,
    this.itemRadius,
    this.itemPadding,
    this.itemTintAlpha,
    this.avatarSize,
    this.avatarTintAlpha,
    this.glyphSize,
    this.accents,
    this.badgeColor,
    this.chevronGlyph,
    this.gridBreakpoint,
    this.gridCrossAxisCount,
    this.minContrast,
    this.sectionTitleStyle,
    this.padding,
    super.key,
  });

  /// Entrées non groupées, dans l'ordre d'affichage voulu (aucun tri
  /// implicite). Rendues comme une section sans intitulé, en tête.
  final List<ZContentHubEntry> entries;

  /// Sections titrées. Vide ⇒ aucune section titrée.
  final List<ZContentHubSection> sections;

  /// Densité du rendu. `null` ⇒ jeton `contentHubDensity`, puis référence
  /// ([ZContentHubDensity.comfortable] — le rendu de référence).
  ///
  /// [ZContentHubDensity.compact] restitue la densité d'avant ce rendu de
  /// référence : une entrée = une ligne au plancher de 48 dp, glyphe nu,
  /// ni carte ni chevron, une seule colonne. C'est la réponse à l'argument
  /// d'échelle.
  final ZContentHubDensity? density;

  /// Hauteur d'item de référence. `null` ⇒ jeton, puis référence (112).
  final double? itemExtent;

  /// Rayon d'une carte d'entrée. `null` ⇒ jeton, puis référence (16).
  final Radius? itemRadius;

  /// Padding interne d'une carte. `null` ⇒ jeton, puis référence (8).
  final EdgeInsetsGeometry? itemPadding;

  /// Opacité de la teinte de fond d'une carte. `null` ⇒ jeton, puis référence
  /// (0 — carte neutre, mesuré sur le rendu historique).
  final double? itemTintAlpha;

  /// Diamètre de la pastille d'identité. `null` ⇒ jeton, puis référence (40).
  final double? avatarSize;

  /// Opacité du fond de la pastille. `null` ⇒ jeton, puis référence (0.1).
  final double? avatarTintAlpha;

  /// Taille du glyphe d'entrée. `null` ⇒ jeton, puis référence (24).
  final double? glyphSize;

  /// Palette des teintes d'identité. `null` ⇒ jeton `contentHubAccents`, puis
  /// [ZContentHubReference.accents]. Liste vide ⇒ aucune teinte
  /// d'identité : le hub rend alors ses glyphes au rôle `onSurfaceVariant`
  /// (chaîne totale, invariant AD-10 — jamais un échec).
  final List<Color>? accents;

  /// Teinte du badge de mise en avant. `null` ⇒ jeton, puis référence.
  final Color? badgeColor;

  /// Glyphe du chevron d'affordance. `null` ⇒ référence
  /// (`arrow_forward_ios`). Toujours rendu retourné en RTL, quel que soit
  /// le glyphe (le socle force `matchTextDirection`).
  final IconData? chevronGlyph;

  /// Largeur à partir de laquelle le hub passe en grille. `null` ⇒ jeton, puis
  /// référence (600 — mesuré sur le rendu historique).
  final double? gridBreakpoint;

  /// Nombre de colonnes au-delà de [gridBreakpoint]. `null` ⇒ jeton, puis
  /// référence (2). `1` ⇒ colonne unique à toute largeur.
  final int? gridCrossAxisCount;

  /// Plancher de contraste des teintes peintes. `null` ⇒ jeton, puis référence
  /// (3.0).
  final double? minContrast;

  /// Style des intitulés de section. `null` ⇒ jeton, puis `titleMedium` du
  /// thème à la graisse de référence.
  final TextStyle? sectionTitleStyle;

  /// Padding de la zone défilante. `null` ⇒ référence (8 horizontal /
  /// 4 vertical).
  final EdgeInsetsGeometry? padding;

  /// Clé de l'en-tête d'une section (testabilité).
  static const ValueKey<String> sectionTitleKey = ValueKey<String>(
    'zContentHubSheet_sectionTitle',
  );

  /// Clé de la pastille d'identité d'une entrée (testabilité).
  static const ValueKey<String> avatarKey = ValueKey<String>(
    'zContentHubSheet_avatar',
  );

  /// Clé du badge de mise en avant d'une entrée (testabilité).
  static const ValueKey<String> badgeKey = ValueKey<String>(
    'zContentHubSheet_badge',
  );

  /// Clé du chevron d'affordance d'une entrée (testabilité).
  static const ValueKey<String> chevronKey = ValueKey<String>(
    'zContentHubSheet_chevron',
  );

  /// Clé du retournement RTL de secours du chevron (testabilité).
  ///
  /// Présente uniquement quand le glyphe injecté ne porte pas
  /// `IconData.matchTextDirection` et que la direction est RTL — sans quoi
  /// aucun nœud n'est ajouté à l'arbre. Le glyphe de référence n'en a jamais
  /// besoin (il porte déjà la propriété, mesuré dans le SDK).
  static const ValueKey<String> chevronMirrorKey = ValueKey<String>(
    'zContentHubSheet_chevronMirror',
  );

  /// Présente la feuille en modale (`showModalBottomSheet`) et se résout à sa
  /// fermeture. Le contenu (icônes/libellés/intitulés injectés) est fourni par
  /// l'appelant — jamais de contenu codé en dur ici.
  static Future<void> show(
    BuildContext context, {
    List<ZContentHubEntry> entries = const <ZContentHubEntry>[],
    List<ZContentHubSection> sections = const <ZContentHubSection>[],
    ZContentHubDensity? density,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => ZContentHubSheet(
        entries: entries,
        sections: sections,
        density: density,
      ),
    );
  }

  /// Groupes réellement rendus : les [entries] non groupées d'abord (section
  /// sans intitulé), puis les [sections]. Une section vide est écartée —
  /// elle ne laisserait qu'un intitulé orphelin (invariant AD-4).
  List<ZContentHubSection> _groups() => <ZContentHubSection>[
    if (entries.isNotEmpty) ZContentHubSection(entries: entries),
    for (final ZContentHubSection section in sections)
      if (section.entries.isNotEmpty) section,
  ];

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ThemeData material = Theme.of(context);
    final ZContentHubDensity resolvedDensity =
        density ?? theme.contentHubDensity ?? ZContentHubDensity.comfortable;
    final bool comfortable = resolvedDensity == ZContentHubDensity.comfortable;

    final List<Color> palette =
        accents ?? theme.contentHubAccents ?? ZContentHubReference.accents;
    final double floor =
        minContrast ??
        theme.contentHubMinContrast ??
        ZContentHubReference.minContrast;
    // Surface sur laquelle la carte repose réellement — c'est contre elle que
    // le contraste se mesure, jamais contre une surface nominale. En thème
    // sombre elle est sombre : c'est ce qui fait remonter la teinte, là où un
    // rendu antérieur peignait le même hex dans les deux luminosités (mesuré :
    // aucune branche `Brightness` dans son rendu).
    final Color baseSurface =
        CardTheme.of(context).color ?? material.colorScheme.surface;

    final _ZContentHubChrome chrome = _ZContentHubChrome(
      comfortable: comfortable,
      extent:
          itemExtent ??
          theme.contentHubItemExtent ??
          ZContentHubReference.itemExtent,
      radius:
          itemRadius ??
          theme.contentHubItemRadius ??
          ZContentHubReference.itemRadius,
      padding:
          itemPadding ??
          theme.contentHubItemPadding ??
          ZContentHubReference.itemPadding,
      tintAlpha:
          itemTintAlpha ??
          theme.contentHubItemTintAlpha ??
          ZContentHubReference.itemTintAlpha,
      avatarSize:
          avatarSize ??
          theme.contentHubAvatarSize ??
          ZContentHubReference.avatarSize,
      avatarTintAlpha:
          avatarTintAlpha ??
          theme.contentHubAvatarTintAlpha ??
          ZContentHubReference.avatarTintAlpha,
      glyphSize:
          glyphSize ??
          theme.contentHubGlyphSize ??
          ZContentHubReference.glyphSize,
      badgeColor:
          badgeColor ??
          theme.contentHubBadgeColor ??
          ZContentHubReference.badgeAccent,
      chevron: chevronGlyph ?? ZContentHubReference.chevronGlyph,
      palette: palette,
      minContrast: floor,
      baseSurface: baseSurface,
      neutralColor: material.colorScheme.onSurfaceVariant,
      borderSide: BorderSide(
        color: material.colorScheme.outlineVariant,
        width: ZContentHubReference.borderWidth,
      ),
      spacing: ZContentHubReference.itemSpacing,
    );

    final List<ZContentHubSection> groups = _groups();
    final TextStyle? titleStyle =
        (sectionTitleStyle ??
                theme.contentHubSectionTitleStyle ??
                material.textTheme.titleMedium)
            ?.copyWith(fontWeight: ZContentHubReference.sectionTitleFontWeight);

    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Mesuré : le rendu historique passe à deux colonnes dès 600 lp de
          // large.
          final double breakpoint =
              gridBreakpoint ??
              theme.contentHubGridBreakpoint ??
              ZContentHubReference.gridBreakpoint;
          final int wideColumns =
              gridCrossAxisCount ??
              theme.contentHubGridCrossAxisCount ??
              ZContentHubReference.gridCrossAxisCount;
          final int columns = !comfortable || constraints.maxWidth < breakpoint
              ? 1
              : (wideColumns < 1 ? 1 : wideColumns);

          return CustomScrollView(
            shrinkWrap: true,
            slivers: <Widget>[
              SliverPadding(
                padding: padding ?? ZContentHubReference.listPadding,
                sliver: SliverMainAxisGroup(
                  slivers: <Widget>[
                    for (final ZContentHubSection group in groups) ...<Widget>[
                      if (group.title != null)
                        SliverToBoxAdapter(
                          child: _ZSectionHeader(
                            section: group,
                            style: titleStyle,
                          ),
                        ),
                      if (columns == 1)
                        SliverList.builder(
                          itemCount: group.entries.length,
                          itemBuilder: (BuildContext context, int index) =>
                              Padding(
                                padding: EdgeInsetsDirectional.only(
                                  bottom: chrome.spacing,
                                ),
                                child: _ZContentHubTile(
                                  entry: group.entries[index],
                                  chrome: chrome,
                                ),
                              ),
                        )
                      else
                        SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: chrome.spacing,
                                crossAxisSpacing: chrome.spacing,
                                // Facteur d'échelle de texte : une cellule de
                                // grille a une hauteur imposée — la figer à
                                // 112 déborderait dès que l'utilisateur
                                // agrandit le texte. L'extent suit donc le
                                // `TextScaler` ambiant. En colonne unique,
                                // c'est un simple plancher, donc le problème
                                // ne se pose pas.
                                mainAxisExtent: MediaQuery.textScalerOf(
                                  context,
                                ).scale(chrome.extent),
                              ),
                          itemCount: group.entries.length,
                          itemBuilder: (BuildContext context, int index) =>
                              _ZContentHubTile(
                                entry: group.entries[index],
                                chrome: chrome,
                              ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Enveloppe [child] de sorte que le glyphe [icon] soit retourné en RTL,
/// même s'il ne porte pas `IconData.matchTextDirection`.
///
/// Mesuré : le widget `Icon` n'a aucune propriété `matchTextDirection` —
/// elle vit sur `IconData`, et `Icons.arrow_forward_ios` la porte déjà à
/// `true` (vérifié sur pièces du SDK). Le chevron de référence se retourne
/// donc déjà correctement : il n'y a pas là de défaut RTL.
///
/// Le socle ne s'en remet pas au glyphe pour autant : un hôte peut injecter un
/// chevron qui ne la porte pas, et l'affordance pointerait alors à l'envers en
/// arabe. Ce repli le rattrape.
///
/// Pourquoi pas reconstruire un `IconData` : ses trois premiers
/// paramètres sont `@mustBeConst` dans le SDK — un `IconData` fabriqué à
/// l'exécution casse le tree-shaking des icônes en release. La correction
/// passe donc par une transformation de rendu, jamais par un glyphe forgé.
Widget zMirrorIfNeeded(
  BuildContext context,
  IconData icon,
  Widget child, {
  Key? key,
}) => icon.matchTextDirection || Directionality.of(context) != TextDirection.rtl
    ? child
    : Transform.flip(key: key, flipX: true, child: child);

/// Créneau déterministe de [seed] dans une palette de [count] teintes.
///
/// Jamais un index d'affichage — c'est toute la différence mesurée par
/// la garde d'insertion : ajouter un type au milieu de la liste ne doit
/// déplacer aucune teinte des entrées voisines. Une fonction de la seule
/// identité de l'entrée le garantit.
int zAccentSlot(String seed, int count) {
  if (count <= 0) return 0;
  int hash = 0;
  for (int i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.codeUnitAt(i)) & 0x1fffffff;
  }
  return hash % count;
}

/// Chrome résolu du hub — calculé une fois par `build` et prêté à chaque tuile
/// (invariant AD-2 : aucune tuile ne refait la cascade paramètre > jeton >
/// référence).
@immutable
class _ZContentHubChrome {
  const _ZContentHubChrome({
    required this.comfortable,
    required this.extent,
    required this.radius,
    required this.padding,
    required this.tintAlpha,
    required this.avatarSize,
    required this.avatarTintAlpha,
    required this.glyphSize,
    required this.badgeColor,
    required this.chevron,
    required this.palette,
    required this.minContrast,
    required this.baseSurface,
    required this.neutralColor,
    required this.borderSide,
    required this.spacing,
  });

  final bool comfortable;
  final double extent;
  final Radius radius;
  final EdgeInsetsGeometry padding;
  final double tintAlpha;
  final double avatarSize;
  final double avatarTintAlpha;
  final double glyphSize;
  final Color badgeColor;
  final IconData chevron;
  final List<Color> palette;
  final double minContrast;
  final Color baseSurface;
  final Color neutralColor;
  final BorderSide borderSide;
  final double spacing;

  /// Teinte d'identité d'une entrée. `null` ⇒ aucune identité chromatique
  /// (palette vide) : le glyphe retombe sur un rôle neutre — chaîne totale
  /// (invariant AD-10), jamais un échec de rendu.
  Color? accentFor(ZContentHubEntry entry) {
    if (entry.tint != null) return entry.tint;
    if (palette.isEmpty) return null;
    return palette[zAccentSlot(entry.colorKey ?? entry.label, palette.length)];
  }
}

/// En-tête de section — `Semantics(header: true)`, jamais un simple `Text`.
class _ZSectionHeader extends StatelessWidget {
  const _ZSectionHeader({required this.section, required this.style});

  final ZContentHubSection section;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String title = section.title!;
    return Semantics(
      header: true,
      label: section.semanticLabel ?? title,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: ZContentHubReference.sectionTitleGap,
          bottom: ZContentHubReference.sectionTitleGap,
        ),
        child: ExcludeSemantics(
          child: Text(
            title,
            key: ZContentHubSheet.sectionTitleKey,
            style: style,
            textAlign: TextAlign.start,
          ),
        ),
      ),
    );
  }
}

/// Une entrée rendue au dessin de référence — carte teintable, pastille
/// circulaire, badge textuel, chevron d'affordance.
///
/// Un seul `InkWell` pour toute la carte : la pastille
/// (40 dp) n'est jamais une cible tactile indépendante, elle passerait
/// sinon sous le plancher de 48 dp (invariant AD-13).
class _ZContentHubTile extends StatelessWidget {
  const _ZContentHubTile({required this.entry, required this.chrome});

  final ZContentHubEntry entry;
  final _ZContentHubChrome chrome;

  @override
  Widget build(BuildContext context) {
    final ThemeData material = Theme.of(context);
    final bool actionable = entry.isActionable;
    final Color? accent = chrome.accentFor(entry);

    // Surface réellement peinte par la carte (neutre par défaut — mesuré : le
    // rendu historique ne teinte pas le fond de sa carte).
    final Color itemSurface = (accent == null || chrome.tintAlpha <= 0)
        ? chrome.baseSurface
        : zCompositeOver(
            accent.withValues(alpha: chrome.tintAlpha.clamp(0.0, 1.0)),
            chrome.baseSurface,
          );

    final Widget content = chrome.comfortable
        ? _buildCard(context, material, accent, itemSurface)
        : _buildCompact(context, material, accent, itemSurface);

    // Pas de `MergeSemantics` ici, et c'est mesuré : le retirer ne change
    // rien au nœud rendu (même libellé annoncé, même `childrenCount`). Le
    // badge n'est pas une frontière sémantique (aucun `container: true`) :
    // son annotation se fond déjà dans celle de la tuile. Un `MergeSemantics`
    // inerte donnerait l'illusion d'un mécanisme. Ce qui est réellement
    // garanti (et gardé) : le badge est annoncé avec le bouton, en un seul
    // nœud — c'est ce qui rend inutile tout détournement de `hint`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: chrome.comfortable
            ? chrome.extent
            : ZContentHubReference.minTapTarget,
      ),
      child: Semantics(
        button: true,
        enabled: actionable,
        label: entry.label,
        hint: entry.hint,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: actionable ? entry.onTap : null,
            borderRadius: BorderRadius.all(chrome.radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.comfortable ? itemSurface : null,
                borderRadius: BorderRadius.all(chrome.radius),
                border: chrome.comfortable
                    ? Border.fromBorderSide(chrome.borderSide)
                    : null,
              ),
              child: Padding(padding: chrome.padding, child: content),
            ),
          ),
        ),
      ),
    );
  }

  /// Rendu de référence — pastille + badge + chevron, puis libellé.
  Widget _buildCard(
    BuildContext context,
    ThemeData material,
    Color? accent,
    Color itemSurface,
  ) {
    final Widget? badge = _buildBadge(context, material, itemSurface);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _buildAvatar(accent, itemSurface),
            const SizedBox(width: ZContentHubReference.labelGap),
            // Invariant AD-4 — pas de badge ⇒ rien dans l'arbre à sa place,
            // seulement l'espace élastique qui pousse le chevron en fin de
            // ligne.
            if (badge != null) Flexible(child: badge),
            const Spacer(),
            _buildChevron(context, material),
          ],
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ZContentHubReference.labelGap,
              top: ZContentHubReference.labelGap,
            ),
            child: _buildLabelBlock(material),
          ),
        ),
      ],
    );
  }

  /// Rendu compact — la densité d'avant ce rendu de référence, restituée par
  /// réglage : glyphe nu, aucune carte, aucun chevron, une ligne au plancher
  /// de 48 dp.
  Widget _buildCompact(
    BuildContext context,
    ThemeData material,
    Color? accent,
    Color itemSurface,
  ) {
    final Widget? badge = _buildBadge(context, material, itemSurface);
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            entry.icon,
            size: chrome.glyphSize,
            color: accent == null
                ? chrome.neutralColor
                : zReadableTintOn(
                    accent,
                    surface: itemSurface,
                    minContrast: chrome.minContrast,
                  ),
          ),
        ),
        const SizedBox(width: ZContentHubReference.labelGap),
        Expanded(child: _buildLabelBlock(material)),
        if (badge != null) badge,
      ],
    );
  }

  /// Libellé (+ indice) — le porteur de l'information (invariant AD-13 : la
  /// couleur n'est jamais le seul canal). Exclu de la sémantique : il est
  /// déjà porté par le `Semantics(label:)` de la tuile (pas de double
  /// annonce).
  Widget _buildLabelBlock(ThemeData material) {
    final String? hint = entry.hint;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: material.textTheme.bodyMedium?.copyWith(
                fontWeight: ZContentHubReference.labelFontWeight,
              ),
            ),
          ),
          // Invariant AD-4 — pas d'indice ⇒ absent de l'arbre, jamais un
          // `Text('')`.
          if (hint != null)
            Flexible(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: material.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  /// Pastille circulaire d'identité — décorative : le libellé porte déjà
  /// l'information, la teinte n'en est qu'un rappel (invariant AD-13).
  Widget _buildAvatar(Color? accent, Color itemSurface) {
    final Color surface = accent == null
        ? itemSurface
        : zCompositeOver(
            accent.withValues(alpha: chrome.avatarTintAlpha.clamp(0.0, 1.0)),
            itemSurface,
          );
    // Le glyphe se mesure contre la pastille (déjà teintée), jamais contre la
    // carte : mesurer contre la carte surestimerait le contraste.
    final Color glyphColor = accent == null
        ? chrome.neutralColor
        : zReadableTintOn(
            accent,
            surface: surface,
            minContrast: chrome.minContrast,
          );
    return ExcludeSemantics(
      child: SizedBox(
        key: ZContentHubSheet.avatarKey,
        width: chrome.avatarSize,
        height: chrome.avatarSize,
        child: DecoratedBox(
          decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
          child: Center(
            child: Icon(entry.icon, size: chrome.glyphSize, color: glyphColor),
          ),
        ),
      ),
    );
  }

  /// Chevron d'affordance — décoratif, et retourné en RTL (invariant AD-13),
  /// y compris quand l'hôte injecte un glyphe qui ne porte pas
  /// `IconData.matchTextDirection` (cf. [zMirrorIfNeeded]).
  Widget _buildChevron(BuildContext context, ThemeData material) =>
      ExcludeSemantics(
        child: zMirrorIfNeeded(
          context,
          chrome.chevron,
          Icon(
            chrome.chevron,
            key: ZContentHubSheet.chevronKey,
            size: ZContentHubReference.chevronSize,
            color: material.colorScheme.onSurfaceVariant,
          ),
          key: ZContentHubSheet.chevronMirrorKey,
        ),
      );

  /// Badge de mise en avant. `null` ⇒ absent de l'arbre (invariant AD-4) —
  /// jamais un `SizedBox.shrink()` inerte.
  Widget? _buildBadge(
    BuildContext context,
    ThemeData material,
    Color itemSurface,
  ) {
    final String? label = entry.badgeLabel;
    if (label == null) return null;
    final Color surface = zCompositeOver(
      chrome.badgeColor.withValues(alpha: ZContentHubReference.badgeTintAlpha),
      itemSurface,
    );
    // Le libellé d'un badge est du texte : plancher 4.5, mesuré contre le fond
    // du badge (déjà teinté), jamais contre la carte.
    final Color onBadge = zReadableTintOn(
      chrome.badgeColor,
      surface: surface,
      minContrast: ZContentHubReference.textMinContrast,
    );
    return Semantics(
      label: entry.badgeSemanticLabel ?? label,
      child: Container(
        key: ZContentHubSheet.badgeKey,
        padding: ZContentHubReference.badgePadding,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.all(
            ZContentHubReference.badgeRadius,
          ),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: material.textTheme.labelSmall?.copyWith(
              color: onBadge,
              fontWeight: ZContentHubReference.badgeFontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
