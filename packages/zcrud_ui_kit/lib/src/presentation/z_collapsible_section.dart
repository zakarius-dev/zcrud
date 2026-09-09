/// `ZCollapsibleSection` — **section repliable à en-tête**.
///
/// Un titre, un compte facultatif, un chevron, et un corps qu'on montre ou
/// qu'on cache. C'est le motif qui regroupe une liste par semaine, par
/// matière, par jour — et c'est un motif qui se recopie mal : chaque recopie
/// retrouve les mêmes pièges.
///
/// * Le corps replié est **caché** au lieu d'être **retiré** : ses widgets
///   restent montés, ses abonnements restent actifs, et une liste repliée
///   coûte autant qu'une liste ouverte. Ici le corps est **absent de
///   l'arbre** quand la section est repliée.
/// * L'état d'expansion est reconstruit à chaque `build` du parent — d'où les
///   `UniqueKey()` qu'on finit par poser pour masquer le symptôme. Ici l'état
///   vit dans le `State` de la section, et seule la section se reconstruit au
///   basculement.
/// * Le chevron tourne quoi qu'il arrive, y compris pour l'usager qui a
///   demandé la réduction des animations. Ici la rotation est **instantanée**
///   sous `MediaQuery.disableAnimations`.
/// * L'en-tête n'est pas un bouton pour un lecteur d'écran : le repli est
///   invisible. Ici l'en-tête annonce `button` **et** son état déplié/replié.
/// * Une action posée dans l'en-tête disparaît des lecteurs d'écran parce que
///   toute la ligne a été mise en `ExcludeSemantics`. Ici [trailing] garde son
///   propre nœud sémantique.
///
/// ## Emploi
///
/// ```dart
/// ZCollapsibleSection(
///   leadingIcon: Icons.calendar_month_rounded,
///   title: weekLabel,                 // libellé fourni par l'appelant
///   count: folders.length,
///   countSemanticsLabel: foldersCountLabel,
///   child: FolderGrid(folders: folders),
/// )
/// ```
///
/// ## Apparence
///
/// Chaque métrique suit la chaîne **paramètre > jeton > référence** :
/// [ZCollapsibleSectionSpec] passé en [spec], puis les jetons
/// `ZcrudTheme.collapsibleSection*`, puis [ZCollapsibleSectionReference].
/// Aucune couleur n'est écrite en dur : les teintes viennent des rôles du
/// `ColorScheme`, de `ThemeData` (`dividerColor`,
/// `scaffoldBackgroundColor`, `cardColor`) ou d'une clé de couleur résolue
/// par `zResolveColorKeyOrSlot`.
///
/// **Neutre** : aucun gestionnaire d'état, aucun routeur, aucune dépendance
/// tierce. La section ne sait pas ce qu'elle contient.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZDisplayStateBinding,
        ZToggleController,
        ZcrudTheme,
        zResolveColorKeyOrSlot;

import '../domain/z_collapsible_section_spec.dart';
import 'z_collapsible_section_reference.dart';

/// Section repliable : un en-tête cliquable, un corps monté seulement quand
/// la section est dépliée.
class ZCollapsibleSection extends StatefulWidget {
  /// Crée une section repliable.
  ///
  /// Exactement l'un de [title] (un libellé) et [titleWidget] (un widget
  /// libre) doit être fourni — la section n'invente aucun libellé.
  const ZCollapsibleSection({
    required this.child,
    this.title,
    this.titleWidget,
    this.leading,
    this.leadingIcon,
    this.leadingColorKey,
    this.leadingColorSlotIndex = 0,
    this.count,
    this.countBadge,
    this.countSemanticsLabel,
    this.trailing,
    this.initiallyExpanded = true,
    this.expandController,
    this.onExpansionChanged,
    this.semanticsLabel,
    this.spec,
    this.margin,
    this.backgroundColor,
    this.headerColor,
    super.key,
  }) : assert(
          title != null || titleWidget != null,
          'ZCollapsibleSection exige un titre : fournissez `title` (un '
          'libellé déjà localisé) ou `titleWidget`.',
        );

  /// Clé du `Material` **conteneur** — celui qui porte l'ombre quand la
  /// section est repliée. Utile pour cibler la surface en test.
  static const Key containerKey = ValueKey<String>('zCollapsibleSection:box');

  /// Clé du `Material` d'**en-tête** — celui qui porte l'ombre quand la
  /// section est dépliée.
  static const Key headerKey = ValueKey<String>('zCollapsibleSection:header');

  /// Clé du conteneur de **corps**. Absente de l'arbre quand la section est
  /// repliée.
  static const Key bodyKey = ValueKey<String>('zCollapsibleSection:body');

  /// Clé du **chevron** animé.
  static const Key chevronKey = ValueKey<String>('zCollapsibleSection:chevron');

  /// Le contenu révélé quand la section est dépliée.
  ///
  /// **Monté seulement dépliée** : replié, ce sous-arbre n'est pas dans
  /// l'arbre — il ne construit rien, n'écoute rien, ne mesure rien.
  final Widget child;

  /// Libellé de l'en-tête, **déjà localisé** par l'appelant.
  ///
  /// Rendu avec les métriques de `TextTheme.titleMedium`, écrêté par ellipse
  /// sur une ligne. Sert aussi d'annonce par défaut aux lecteurs d'écran.
  /// Mutuellement exclusif avec [titleWidget].
  final String? title;

  /// Titre **libre** de l'en-tête, quand un simple libellé ne suffit pas
  /// (deux lignes, une date mise en forme, une puce d'état…).
  ///
  /// Mutuellement exclusif avec [title]. Sans [semanticsLabel], ce sous-arbre
  /// fournit lui-même l'annonce de l'en-tête : ses nœuds sémantiques sont
  /// alors conservés.
  final Widget? titleWidget;

  /// Contenu de tête **libre**, posé avant le titre. Prioritaire sur
  /// [leadingIcon].
  ///
  /// `null` (défaut) et [leadingIcon] `null` ⇒ aucune tête : la ligne
  /// commence au titre.
  final Widget? leading;

  /// Glyphe de tête, posé dans un **disque** teinté.
  ///
  /// Sans effet quand [leading] est fourni. Aucun glyphe par défaut : une
  /// section ne préjuge pas de ce qu'elle groupe.
  final IconData? leadingIcon;

  /// Clé de couleur du disque de tête, résolue par `zResolveColorKeyOrSlot`
  /// (seam d'hôte, puis rôles Material, puis slot déterministe).
  ///
  /// `null` (défaut) ⇒ le rôle `primary` du `ColorScheme`.
  final String? leadingColorKey;

  /// Index de repli de [leadingColorKey] dans la palette de l'appelant, quand
  /// la clé n'est reconnue par personne. Garantit une teinte **déterministe
  /// et contrastée** plutôt qu'un défaut arbitraire.
  final int leadingColorSlotIndex;

  /// Nombre affiché dans la **pastille de compte**.
  ///
  /// `null` ou négatif ou nul ⇒ pas de pastille : un compte à zéro est du
  /// bruit. Sans effet quand [countBadge] est fourni.
  final int? count;

  /// Pastille de compte **libre**, prioritaire sur [count].
  ///
  /// Pour un hôte qui a déjà sa pastille — un `ZCountBadge`, une puce, un
  /// compteur composé.
  final Widget? countBadge;

  /// Annonce du compte pour les lecteurs d'écran, **déjà localisée**.
  ///
  /// Ajoutée à l'annonce de l'en-tête : replié, l'en-tête est le seul indice
  /// de ce que la section contient, et « 12 » sans objet n'en est pas un.
  final String? countSemanticsLabel;

  /// Contenu posé **entre le titre et le chevron** — typiquement une action
  /// propre à la section.
  ///
  /// Reste hors de l'annonce de l'en-tête et **garde ses propres nœuds
  /// sémantiques** : un bouton posé ici est atteignable et annoncé pour
  /// lui-même. Son geste prime sur celui de l'en-tête.
  final Widget? trailing;

  /// État initial, quand l'état n'est pas piloté par [expandController].
  final bool initiallyExpanded;

  /// Contrôleur de l'hôte, quand le repli doit être commandé de l'extérieur
  /// (un bouton « tout replier », par exemple).
  ///
  /// `null` (défaut) ⇒ la section détient son état. Non-null ⇒ elle **n'en
  /// garde aucune copie** : lecture et écriture traversent le contrôleur,
  /// donc rien ne peut diverger. Le contrôleur appartient à l'hôte : la
  /// section ne le libère jamais.
  final ZToggleController? expandController;

  /// Notifié à chaque basculement, avec le **nouvel** état.
  final ValueChanged<bool>? onExpansionChanged;

  /// Annonce de l'en-tête pour les lecteurs d'écran, **déjà localisée**.
  ///
  /// `null` (défaut) ⇒ [title] et [countSemanticsLabel] assemblés ; si aucun
  /// des deux n'est fourni, l'annonce vient du sous-arbre [titleWidget].
  final String? semanticsLabel;

  /// Réglages de métriques **de cette section**, prioritaires sur les jetons
  /// `ZcrudTheme.collapsibleSection*`.
  final ZCollapsibleSectionSpec? spec;

  /// Marge extérieure. `null` (défaut) ⇒ la marge de référence.
  ///
  /// `EdgeInsets.zero` supprime la marge, pour une section posée dans une
  /// liste qui gère déjà son propre rythme.
  final EdgeInsetsGeometry? margin;

  /// Couleur du conteneur et du corps. `null` (défaut) ⇒
  /// `ThemeData.scaffoldBackgroundColor`.
  final Color? backgroundColor;

  /// Couleur de l'en-tête. `null` (défaut) ⇒ `ThemeData.cardColor`.
  final Color? headerColor;

  @override
  State<ZCollapsibleSection> createState() => _ZCollapsibleSectionState();
}

class _ZCollapsibleSectionState extends State<ZCollapsibleSection> {
  /// État interne par défaut, contrôleur de l'hôte s'il y en a un. **Jamais un
  /// miroir** : quand l'hôte pilote, lecture et écriture le traversent.
  late final ZDisplayStateBinding<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = ZDisplayStateBinding<bool>(
      consumer: this,
      initialValue: widget.initiallyExpanded,
    )..bind(widget.expandController);
  }

  @override
  void didUpdateWidget(covariant ZCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son pilote : sans cela la
    // section resterait branchée sur l'ancien, muette pour le nouveau.
    _expanded.bind(widget.expandController);
  }

  @override
  void dispose() {
    // Ne dispose JAMAIS le contrôleur de l'hôte : il ne nous appartient pas.
    _expanded.dispose();
    super.dispose();
  }

  void _toggle() {
    final bool next = !_expanded.value;
    _expanded.value = next;
    widget.onExpansionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    // Invariant AD-2 : le basculement ne reconstruit QUE cette tranche — ni la
    // page, ni les sections voisines. Le corps, lui, est un widget déjà
    // construit par l'appelant : le monter ou le démonter ne le rebâtit pas.
    return ValueListenableBuilder<bool>(
      valueListenable: _expanded.listenable,
      builder: (BuildContext context, bool expanded, Widget? _) =>
          _buildSection(context, expanded),
    );
  }

  Widget _buildSection(BuildContext context, bool expanded) {
    final ThemeData theme = Theme.of(context);
    final ZcrudTheme tokens = ZcrudTheme.of(context);
    final ZCollapsibleSectionSpec? spec = widget.spec;

    // Chaîne `paramètre > jeton > référence`, appliquée valeur par valeur.
    final double cornerRadius = spec?.cornerRadius ??
        tokens.collapsibleSectionCornerRadius ??
        ZCollapsibleSectionReference.cornerRadius;
    final double borderAlpha = spec?.borderAlpha ??
        tokens.collapsibleSectionBorderAlpha ??
        ZCollapsibleSectionReference.borderAlpha;
    final double expandedElevation = spec?.expandedElevation ??
        tokens.collapsibleSectionExpandedElevation ??
        ZCollapsibleSectionReference.expandedElevation;
    final double collapsedElevation = spec?.collapsedElevation ??
        tokens.collapsibleSectionCollapsedElevation ??
        ZCollapsibleSectionReference.collapsedElevation;

    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
      side: BorderSide(
        color: theme.dividerColor.withValues(alpha: borderAlpha),
      ),
    );
    final Color surface =
        widget.backgroundColor ?? theme.scaffoldBackgroundColor;

    return Padding(
      padding: widget.margin ?? ZCollapsibleSectionReference.margin,
      child: Material(
        key: ZCollapsibleSection.containerKey,
        // L'ombre s'échange : dépliée, elle est portée par l'en-tête (la
        // césure à marquer est celle de l'en-tête et du corps) ; repliée, la
        // section entière n'est plus qu'une carte, et c'est le conteneur qui
        // la porte.
        elevation: expanded ? collapsedElevation : expandedElevation,
        shape: expanded ? null : shape,
        color: surface,
        // Rognage seulement quand une forme est posée : `antiAlias` sans
        // forme coûterait une couche de composition pour rien.
        clipBehavior: expanded ? Clip.none : Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context, theme, tokens, spec, expanded, shape,
                expandedElevation, collapsedElevation),
            if (expanded) _buildBody(context, theme, tokens, spec, surface),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    ZcrudTheme tokens,
    ZCollapsibleSectionSpec? spec,
    bool expanded,
    RoundedRectangleBorder shape,
    double expandedElevation,
    double collapsedElevation,
  ) {
    final ColorScheme scheme = theme.colorScheme;
    final Widget? leading = _buildLeading(context, theme, tokens, spec);
    final Widget? badge = _buildCountBadge(theme, tokens, spec);
    final Widget? trailing = widget.trailing;
    final String? label = _semanticsLabel();

    Widget titleSlot = widget.titleWidget ??
        Text(
          widget.title!,
          maxLines: ZCollapsibleSectionReference.titleMaxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: ZCollapsibleSectionReference.titleWeight,
          ),
        );
    // Le titre n'est masqué aux lecteurs d'écran que si l'annonce de
    // l'en-tête le porte déjà — sinon le bouton serait sans nom (AD-10 :
    // aucun chemin ne doit produire un nœud muet).
    if (label != null) titleSlot = ExcludeSemantics(child: titleSlot);

    final Widget row = Padding(
      padding: ZCollapsibleSectionReference.headerContentPadding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            ExcludeSemantics(child: leading),
            const SizedBox(width: ZCollapsibleSectionReference.leadingGap),
          ],
          Expanded(child: titleSlot),
          if (badge != null) ExcludeSemantics(child: badge),
          // Hors de l'annonce de l'en-tête, et sans `ExcludeSemantics` : une
          // action posée ici reste atteignable et annoncée pour elle-même.
          ?trailing,
          ExcludeSemantics(
            child: _buildChevron(context, scheme, tokens, spec, expanded),
          ),
        ],
      ),
    );

    return Material(
      key: ZCollapsibleSection.headerKey,
      elevation: expanded ? expandedElevation : collapsedElevation,
      color: widget.headerColor ?? theme.cardColor,
      shape: expanded ? shape : null,
      child: Semantics(
        container: true,
        // Les enfants gardent leurs propres nœuds : c'est ce qui laisse
        // `trailing` atteignable sous l'en-tête-bouton.
        explicitChildNodes: true,
        button: true,
        expanded: expanded,
        label: label,
        child: InkWell(
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ZCollapsibleSectionReference.minTouchTarget,
            ),
            child: row,
          ),
        ),
      ),
    );
  }

  /// Annonce de l'en-tête, ou `null` quand aucun texte n'est disponible — le
  /// sous-arbre du titre fournit alors lui-même le nom du bouton.
  String? _semanticsLabel() {
    final String? explicit = widget.semanticsLabel;
    if (explicit != null) return explicit;
    final String? title = widget.title;
    final String? count = widget.countSemanticsLabel;
    if (title == null) return count;
    if (count == null) return title;
    return '$title, $count';
  }

  Widget? _buildLeading(
    BuildContext context,
    ThemeData theme,
    ZcrudTheme tokens,
    ZCollapsibleSectionSpec? spec,
  ) {
    final Widget? custom = widget.leading;
    if (custom != null) return custom;
    final IconData? icon = widget.leadingIcon;
    if (icon == null) return null;

    final String? colorKey = widget.leadingColorKey;
    final ZColorPair? pair = colorKey == null
        ? null
        : zResolveColorKeyOrSlot(
            context,
            colorKey,
            slotIndex: widget.leadingColorSlotIndex,
          );
    final Color tint = pair?.color ?? theme.colorScheme.primary;
    final double backgroundAlpha = spec?.leadingBackgroundAlpha ??
        tokens.collapsibleSectionLeadingBackgroundAlpha ??
        ZCollapsibleSectionReference.leadingBackgroundAlpha;
    final double size = spec?.leadingIconSize ??
        tokens.collapsibleSectionLeadingIconSize ??
        ZCollapsibleSectionReference.leadingIconSize;

    return Container(
      padding: ZCollapsibleSectionReference.leadingPadding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: backgroundAlpha),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: tint, size: size),
    );
  }

  Widget? _buildCountBadge(
    ThemeData theme,
    ZcrudTheme tokens,
    ZCollapsibleSectionSpec? spec,
  ) {
    final Widget? custom = widget.countBadge;
    if (custom != null) {
      return Padding(
        padding: ZCollapsibleSectionReference.countMargin,
        child: custom,
      );
    }
    final int? count = widget.count;
    if (count == null || count <= 0) return null;

    final ColorScheme scheme = theme.colorScheme;
    final double radius = spec?.countCornerRadius ??
        tokens.collapsibleSectionCountCornerRadius ??
        ZCollapsibleSectionReference.countCornerRadius;
    return Container(
      margin: ZCollapsibleSectionReference.countMargin,
      padding: ZCollapsibleSectionReference.countPadding,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.start,
        style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: ZCollapsibleSectionReference.countWeight,
        ),
      ),
    );
  }

  Widget _buildChevron(
    BuildContext context,
    ColorScheme scheme,
    ZcrudTheme tokens,
    ZCollapsibleSectionSpec? spec,
    bool expanded,
  ) {
    final Duration declared = spec?.chevronDuration ??
        tokens.collapsibleSectionChevronDuration ??
        ZCollapsibleSectionReference.chevronDuration;
    // Réduction des animations demandée : la rotation est INSTANTANÉE, la
    // durée déclarée n'est pas lue (invariant AD-13).
    final Duration duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : declared;
    return AnimatedRotation(
      key: ZCollapsibleSection.chevronKey,
      turns: expanded
          ? ZCollapsibleSectionReference.chevronExpandedTurns
          : ZCollapsibleSectionReference.chevronCollapsedTurns,
      duration: duration,
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ZcrudTheme tokens,
    ZCollapsibleSectionSpec? spec,
    Color surface,
  ) {
    final double borderAlpha = spec?.bodyBorderAlpha ??
        tokens.collapsibleSectionBodyBorderAlpha ??
        ZCollapsibleSectionReference.bodyBorderAlpha;
    final double radius = spec?.bodyCornerRadius ??
        tokens.collapsibleSectionBodyCornerRadius ??
        ZCollapsibleSectionReference.bodyCornerRadius;
    return Container(
      key: ZCollapsibleSection.bodyKey,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: borderAlpha),
          ),
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(radius),
        ),
      ),
      child: widget.child,
    );
  }
}
