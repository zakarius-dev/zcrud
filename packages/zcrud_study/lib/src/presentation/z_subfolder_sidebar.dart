/// `ZSubfolderSidebar` — sidebar de sous-dossiers pour GRAND écran (SUF-3, T2).
///
/// Présente l'item racine « Tous les sous-dossiers » puis les [ZSubfolderRef],
/// avec surbrillance de la sélection (`Semantics(selected:)`), repli/déploiement
/// (~56 dp repliée : icône + badge), redimensionnement **borné** (largeur
/// détenue par le PARENT) par drag **OU clavier OU action sémantique**,
/// réordonnancement optionnel (poignée + actions sémantiques) et bouton
/// « Ajouter » optionnel (slot).
///
/// **AD-2/AD-15** : la sidebar ne DÉTIENT aucun état — sélection, repli et
/// largeur sont des `ValueListenable`/callbacks injectés par `ZStudyFolderDetail`
/// (propriétaire unique). La surbrillance est scopée **par item**
/// (`ValueListenableBuilder` sur la seule tranche `selected`) : changer la
/// sélection ne reconstruit QUE les items concernés, jamais la structure.
///
/// **AD-13** : insets/alignements **directionnels** (la sidebar s'ancre côté
/// **start**, poignée de resize côté **end** via `Row`), `Semantics` explicites,
/// libellés INJECTÉS, cibles ≥ 48 dp, `const` où possible. **Aucune fonction
/// n'est réservée au pointeur** : le réordonnancement a ses actions sémantiques
/// « déplacer avant/après », et le redimensionnement a son nœud labellisé
/// `increase`/`decrease` + ses flèches clavier (WCAG 2.1.1 / 2.5.7).
///
/// Le contenu d'un item vient de [ZSubfolderNavSpec.itemBuilder] injecté (ou
/// d'une rangée neutre par défaut) ; gouttières et **surbrillance de sélection**
/// sont posées AUTOUR par ce widget — le même contrat que le sélecteur compact
/// applique de l'autre côté du seuil de bascule (parité R-SUF2).
///
/// **AD-10** : aucune I/O — le redimensionnement clampé est REMONTÉ par callback.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent,
    KeyRepeatEvent, LogicalKeyboardKey;
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import 'z_subfolder_item_chrome.dart';
import 'z_subfolder_item_content.dart' show zSubfolderRootItemLabel;
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Cible interactive minimale (AD-13).
const double _kMinTapTarget = 48.0;

/// Largeur de la zone de saisie (hit-area) de la poignée de resize (≥ 48 dp,
/// AD-13). Dimension de LAYOUT — jamais une couleur.
const double _kResizeHitWidth = 48.0;

/// Épaisseur VISUELLE du trait de la poignée de resize (dimension de layout).
const double _kResizeLineWidth = 2.0;

/// Pas (dp) d'un élargissement/rétrécissement au CLAVIER ou par action
/// sémantique — alternative non-pointeur au drag (WCAG 2.1.1 / 2.5.7).
/// Dimension de LAYOUT, jamais une couleur ni un libellé.
const double _kResizeStep = 32.0;

/// Glyphe conventionnel « ajouter » de REPLI (jamais un libellé ; un
/// `IconData` neutre — même patron que `ZSectionedStudyLayout`). Prime dès que
/// l'appelant injecte `ZSubfolderNavSpec.addIcon`.
const IconData _kAddFallbackIcon = Icons.add;

/// Sidebar de sous-dossiers (grand écran).
class ZSubfolderSidebar extends StatelessWidget {
  /// Construit la sidebar. [collapsed], [width], [minWidth]/[maxWidth] et les
  /// tranches réactives sont fournis par `ZStudyFolderDetail` (propriétaire).
  const ZSubfolderSidebar({
    required this.spec,
    required this.collapsed,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.selected,
    required this.onSelect,
    required this.onToggleCollapsed,
    required this.onWidthChanged,
    required this.onWidthChangeEnd,
    super.key,
  });

  /// Clé stable de la poignée de redimensionnement (exposée pour les tests).
  static const Key resizeHandleKey = ValueKey<String>('suf3:sidebar:resize');

  /// Clé stable du contrôle de repli (exposée pour les tests).
  static const Key collapseToggleKey =
      ValueKey<String>('suf3:sidebar:collapse');

  /// Descripteur de navigation (données + labels + bornes, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Sidebar repliée (~[ZSubfolderNavSpec.collapsedWidth]) — icône + badge.
  final bool collapsed;

  /// **État courant** du redimensionnement (dp), détenu par le PARENT (AD-2).
  ///
  /// 🔴 **Ce paramètre n'applique AUCUNE contrainte de layout.** Ce n'est pas un
  /// oubli : la sidebar ne décide pas de sa taille (AD-2) — elle rend une `Row`
  /// d'`Expanded` et occupe donc **toute la largeur que son parent lui donne**.
  ///
  /// Ce que `width` FAIT réellement :
  /// * elle alimente la **poignée de redimensionnement** (valeur de départ du
  ///   drag, des pas clavier et des actions sémantiques `increase`/`decrease`,
  ///   clampés dans `[minWidth, maxWidth]`) ;
  /// * elle est **annoncée** par la sémantique de cette poignée
  ///   (`value: '${width.round()}'`).
  ///
  /// Ce que `width` NE FAIT PAS : aucun `SizedBox`, aucun `ConstrainedBox`,
  /// aucune borne de layout. **C'est à l'hôte de poser la contrainte**, comme le
  /// fait `ZStudyFolderDetail` :
  ///
  /// ```dart
  /// SizedBox(
  ///   width: clamped,
  ///   child: ZSubfolderSidebar(width: clamped, /* … */),
  /// )
  /// ```
  ///
  /// ⚠️ **Symptôme si on l'oublie** — placer la sidebar dans une `Row` (ou tout
  /// parent à largeur non bornée) sans `SizedBox` produit des **milliers**
  /// d'exceptions de rendu `Failed assertion: … 'hasSize'`, levées **loin du
  /// site fautif** (dans les descendants, pas ici). Si vous voyez ce symptôme,
  /// la contrainte manquante est chez vous, pas dans le socle.
  ///
  /// (Sans effet visuel quand [collapsed] est vrai : le parent pose alors
  /// `ZSubfolderNavSpec.collapsedWidth`.)
  final double width;

  /// Borne basse de largeur (dp) — [ZSubfolderNavSpec.minSidebarWidth].
  final double minWidth;

  /// Borne haute de largeur (dp) — `max(minWidth, fraction × largeurÉcran)`.
  final double maxWidth;

  /// Tranche réactive de sélection (`null` = item racine).
  final ValueListenable<String?> selected;

  /// Émis quand un item est choisi (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  /// Bascule repli/déploiement (l'état est détenu par le parent).
  final VoidCallback onToggleCollapsed;

  /// Émis pendant le drag de resize avec la largeur **déjà clampée**
  /// `[minWidth, maxWidth]` — le parent met sa tranche à jour.
  final ValueChanged<double> onWidthChanged;

  /// Émis à la FIN du drag (changement **stabilisé**) — le parent persiste via
  /// son callback injecté (aucune I/O ici).
  final VoidCallback onWidthChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Scope de mode posé AU-DESSUS de tout le sous-arbre d'items : un
    // `itemBuilder` injecté lit `ZSubfolderLayoutMode.of(context) == sidebar` et
    // sait donc que sa largeur est BORNÉE (CR-IFFD-31) — sans 4ᵉ paramètre.
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.sidebar,
      // CR-IFFD-46, point 1 — second axe : la surface CONCRÈTE.
      surface: ZSubfolderSurface.sidebar,
      child: collapsed
          ? _buildCollapsed(context, theme)
          : _buildExpanded(context, theme),
    );
  }

  // --- Repliée ---------------------------------------------------------------

  Widget _buildCollapsed(BuildContext context, ZcrudTheme theme) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _collapseToggle(context, theme),
          SizedBox(height: theme.gapS),
          // Badge du NOMBRE de sous-dossiers (interpolation d'un entier — jamais
          // un libellé traduisible).
          ZSubfolderCountPill(count: spec.subfolders.length),
        ],
      ),
    );
  }

  // --- Déployée --------------------------------------------------------------

  Widget _buildExpanded(BuildContext context, ZcrudTheme theme) {
    // `Row` directionnel : contenu au START, poignée de resize à l'END (RTL-safe
    // sans left/right explicites).
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _collapseToggle(context, theme),
              // En-tête INJECTÉ (CR-IFFD-30) : `null` ⇒ slot absent, rendu
              // inchangé. Rendu ICI, donc UNIQUEMENT à l'état déployé — il
              // disparaît au repli sans que l'hôte ait à s'abonner à
              // `collapsed` (`_buildCollapsed` ne le rend pas).
              if (spec.sidebarHeader != null) spec.sidebarHeader!,
              _rootItem(context, theme),
              Expanded(child: _list(context, theme)),
              if (spec.addAction != null) _addButton(context, theme),
            ],
          ),
        ),
        _resizeHandle(context, theme),
      ],
    );
  }

  Widget _collapseToggle(BuildContext context, ZcrudTheme theme) {
    // Libellé INJECTÉ (repli sur un AUTRE label injecté — jamais une chaîne en
    // dur) : déployée ⇒ « replier », repliée ⇒ « déployer ».
    final label = collapsed
        ? (spec.expandLabel ?? spec.allSubfoldersLabel)
        : (spec.collapseLabel ?? spec.allSubfoldersLabel);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kMinTapTarget,
          minHeight: _kMinTapTarget,
        ),
        child: IconButton(
          key: collapseToggleKey,
          onPressed: onToggleCollapsed,
          tooltip: label,
          icon: Icon(
            collapsed ? Icons.chevron_right : Icons.chevron_left,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }

  Widget _rootItem(BuildContext context, ZcrudTheme theme) => _SubfolderRow(
        spec: spec,
        theme: theme,
        // Item racine : id de sélection `null`, aucune couleur/compteur.
        refOrNull: null,
        // CR-IFFD-46, point 1 — la ligne racine désigne le CONTENEUR ; elle
        // suit donc `rootItemLabel` (repli : `allSubfoldersLabel`), via la
        // source UNIQUE de ce repli.
        label: zSubfolderRootItemLabel(spec),
        rootIcon: spec.rootItemIcon,
        index: -1,
        selected: selected,
        onSelect: onSelect,
      );

  Widget _list(BuildContext context, ZcrudTheme theme) {
    final subfolders = spec.subfolders;
    if (spec.onReorder != null) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: subfolders.length,
        // `onReorderItem` (remplace `onReorder`, obsolète) : le `newIndex` est
        // DÉJÀ ajusté en convention `removeAt(old)`/`insert(new)` — MÊME patron
        // que `ZSectionedStudyLayout`.
        onReorderItem: _handleReorder,
        itemBuilder: (context, index) {
          final ref = subfolders[index];
          return _SubfolderRow(
            // Clé STABLE requise par ReorderableListView (id opaque, jamais
            // l'index).
            key: ValueKey<String>('suf3:subfolder:${ref.id}'),
            spec: spec,
            theme: theme,
            refOrNull: ref,
            label: ref.label,
            index: index,
            selected: selected,
            onSelect: onSelect,
          );
        },
      );
    }
    return ListView.builder(
      itemCount: subfolders.length,
      itemBuilder: (context, index) {
        final ref = subfolders[index];
        return _SubfolderRow(
          key: ValueKey<String>('suf3:subfolder:${ref.id}'),
          spec: spec,
          theme: theme,
          refOrNull: ref,
          label: ref.label,
          index: index,
          selected: selected,
          onSelect: onSelect,
        );
      },
    );
  }

  /// Émet le déplacement vers [spec.onReorder] en convention
  /// `removeAt(old)/insert(new)` (indices LINÉAIRES sur `subfolders`, item
  /// racine exclu). `onReorderItem` fournit un [newIndex] DÉJÀ ajusté pour le
  /// retrait à [oldIndex] — aucun `-1` manuel (symétrie avec `zReorderIds`).
  void _handleReorder(int oldIndex, int newIndex) {
    spec.onReorder!(oldIndex, newIndex);
  }

  Widget _addButton(BuildContext context, ZcrudTheme theme) {
    final label = spec.addLabel ?? spec.allSubfoldersLabel;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kMinTapTarget,
          minHeight: _kMinTapTarget,
        ),
        child: IconButton(
          key: const ValueKey<String>('suf3:sidebar:add'),
          onPressed: spec.addAction,
          tooltip: label,
          icon: Icon(spec.addIcon ?? _kAddFallbackIcon, semanticLabel: label),
        ),
      ),
    );
  }

  Widget _resizeHandle(BuildContext context, ZcrudTheme theme) => _ResizeHandle(
        key: resizeHandleKey,
        // Libellé INJECTÉ (repli sur un AUTRE label injecté — jamais une chaîne
        // en dur) : un contrôle interactif n'est JAMAIS rendu sans annonce.
        label: spec.resizeLabel ?? spec.allSubfoldersLabel,
        width: width,
        minWidth: minWidth,
        maxWidth: maxWidth,
        onWidthChanged: onWidthChanged,
        onWidthChangeEnd: onWidthChangeEnd,
      );
}

/// Poignée de redimensionnement de la sidebar — **triple voie** (AD-13) :
///
/// 1. **pointeur** : drag horizontal (signe INVERSÉ en RTL, la sidebar étant
///    ancrée côté start ⇒ à droite) ;
/// 2. **clavier** : focusable, flèches ← / → par pas de [_kResizeStep]
///    (inversées en RTL) — WCAG 2.1.1 ;
/// 3. **sémantique** : `increase`/`decrease` sur un nœud LABELLISÉ portant la
///    largeur courante comme `value` — alternative au drag (WCAG 2.5.7), au
///    même titre que les `customSemanticsActions` du réordonnancement.
///
/// Ne DÉTIENT aucune largeur (AD-2) : elle remonte des valeurs **déjà clampées**
/// via [onWidthChanged], puis signale la stabilisation via [onWidthChangeEnd]
/// (le clavier/la sémantique produisent un changement immédiatement stabilisé).
/// Le seul état local est le **focus** (préoccupation purement visuelle).
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.label,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onWidthChanged,
    required this.onWidthChangeEnd,
    super.key,
  });

  final String label;
  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onWidthChangeEnd;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  /// Nœud de focus DÉTENU (créé une fois, disposé une fois — AD-2).
  final FocusNode _focusNode = FocusNode(debugLabel: 'suf3:sidebar:resize');

  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _clamp(double v) =>
      v.clamp(widget.minWidth, widget.maxWidth).toDouble();

  bool get _canWiden => widget.width < widget.maxWidth - 0.01;

  bool get _canNarrow => widget.width > widget.minWidth + 0.01;

  /// Applique un pas NON-POINTEUR : la valeur est clampée puis remontée, et le
  /// changement est immédiatement STABILISÉ (aucun `dragEnd` ne viendra).
  void _step(double delta) {
    final next = _clamp(widget.width + delta);
    if (next == widget.width) return;
    widget.onWidthChanged(next);
    widget.onWidthChangeEnd();
  }

  void _widen() => _step(_kResizeStep);

  void _narrow() => _step(-_kResizeStep);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // En RTL la sidebar est ancrée à droite : ← l'ÉLARGIT (même inversion que
    // le drag).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      rtl ? _narrow() : _widen();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      rtl ? _widen() : _narrow();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textDir = Directionality.of(context);
    return Focus(
      focusNode: _focusNode,
      // La sémantique (label/valeur/actions) est déclarée EXPLICITEMENT
      // ci-dessous : un seul nœud, jamais un doublon anonyme « focusable ».
      includeSemantics: false,
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Semantics(
        container: true,
        label: widget.label,
        // Largeurs = interpolations de NOMBRES (jamais un libellé traduisible).
        value: '${widget.width.round()}',
        increasedValue: '${_clamp(widget.width + _kResizeStep).round()}',
        decreasedValue: '${_clamp(widget.width - _kResizeStep).round()}',
        // Aux bornes, l'action est ABSENTE (jamais un no-op annoncé — AD-45).
        onIncrease: _canWiden ? _widen : null,
        onDecrease: _canNarrow ? _narrow : null,
        focusable: true,
        focused: _focused,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusNode.requestFocus,
            onHorizontalDragUpdate: (details) {
              // En RTL, la sidebar est ancrée à droite : glisser vers la GAUCHE
              // l'agrandit ⇒ le signe du delta s'inverse (AD-13).
              final signed = textDir == TextDirection.rtl
                  ? -details.delta.dx
                  : details.delta.dx;
              widget.onWidthChanged(_clamp(widget.width + signed));
            },
            onHorizontalDragEnd: (_) => widget.onWidthChangeEnd(),
            child: SizedBox(
              // Hit-area ≥ 48 dp (AD-13), trait visuel fin au centre.
              width: _kResizeHitWidth,
              child: Center(
                child: Container(
                  width: _focused ? _kResizeLineWidth * 2 : _kResizeLineWidth,
                  color: _focused ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une rangée sélectionnable de la sidebar (item racine OU sous-dossier).
///
/// Scope la surbrillance sur la SEULE tranche `selected` (AD-2) : un
/// `ValueListenableBuilder` par item. Le contenu visuel vient de
/// [ZSubfolderNavSpec.itemBuilder] (injecté) ou d'une rangée neutre thémée par
/// défaut (D3/R-SUF2) ; la surbrillance de sélection est TOUJOURS appliquée par
/// SUF-3 (fond dérivé du thème — AC8).
class _SubfolderRow extends StatelessWidget {
  const _SubfolderRow({
    required this.spec,
    required this.theme,
    required this.refOrNull,
    required this.label,
    required this.index,
    this.rootIcon,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final ZSubfolderNavSpec spec;
  final ZcrudTheme theme;

  /// `null` pour l'item racine « Tous les sous-dossiers ».
  final ZSubfolderRef? refOrNull;
  final String label;

  /// CR-IFFD-46, point 1 — glyphe de tête de la ligne RACINE (`null` ⇒ absent
  /// de l'arbre, AD-4). Passé explicitement par le site racine : `refOrNull`
  /// seul ne suffirait pas à distinguer les surfaces.
  final IconData? rootIcon;

  /// Index LINÉAIRE dans `subfolders` (−1 pour la racine, non réordonnable).
  final int index;
  final ValueListenable<String?> selected;
  final ValueChanged<String?> onSelect;

  bool get _reorderable => refOrNull != null && spec.onReorder != null;

  @override
  Widget build(BuildContext context) {
    final ref = refOrNull;
    final selectionId = ref?.id; // `null` = racine
    return ValueListenableBuilder<String?>(
      valueListenable: selected,
      builder: (context, current, _) {
        final isSelected = current == selectionId;
        final content = spec.itemBuilder?.call(
              context,
              ref ?? ZSubfolderRef(id: '', label: label),
              isSelected,
            ) ??
            _defaultContent(context, isSelected);

        // Actions sémantiques de déplacement (a11y AD-13) — alternative
        // accessible au drag, uniquement si réordonnable ET labels injectés.
        final moveActions = <CustomSemanticsAction, VoidCallback>{};
        if (_reorderable) {
          if (spec.moveBeforeLabel != null && index > 0) {
            moveActions[CustomSemanticsAction(label: spec.moveBeforeLabel!)] =
                () => spec.onReorder!(index, index - 1);
          }
          if (spec.moveAfterLabel != null &&
              index < spec.subfolders.length - 1) {
            moveActions[CustomSemanticsAction(label: spec.moveAfterLabel!)] =
                () => spec.onReorder!(index, index + 1);
          }
        }

        return Semantics(
          selected: isSelected,
          button: true,
          onTap: () => onSelect(selectionId),
          customSemanticsActions: moveActions.isEmpty ? null : moveActions,
          child: InkWell(
            onTap: () => onSelect(selectionId),
            // Le nœud bouton/sélection/actions est porté UNE SEULE fois par le
            // `Semantics` parent ; l'encre et le tap de pointeur restent.
            excludeFromSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              // Surbrillance + gouttières posées AUTOUR de `content` — donc
              // aussi quand l'item vient de `spec.itemBuilder` (AC8 : la mise en
              // évidence VISUELLE est TOUJOURS appliquée par SUF-3, jamais
              // déléguée à l'hôte ; sinon l'écran contredirait le
              // `Semantics(selected:)` ci-dessus).
              child: Container(
                margin: EdgeInsetsDirectional.symmetric(
                  vertical: theme.gapS / 2,
                ),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.gapM,
                  vertical: theme.gapS,
                ),
                decoration: isSelected
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.all(theme.radiusM),
                      )
                    : null,
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rangée neutre par défaut. Ne pose NI gouttières NI surbrillance : les deux
  /// sont appliquées par [build] autour du contenu — `itemBuilder` injecté
  /// compris (parité de rendu des deux chemins).
  Widget _defaultContent(BuildContext context, bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    final ref = refOrNull;
    final Color fg =
        isSelected ? scheme.onSecondaryContainer : scheme.onSurface;

    final children = <Widget>[
      // CR-IFFD-46, point 1 — glyphe de tête de la RACINE, à la place que la
      // pastille d'accent tient sur un sous-dossier. `null` ⇒ absent (AD-4).
      // Couleur DÉRIVÉE du premier plan de l'item (jamais littérale, FR-26).
      if (ref == null && rootIcon != null) ...<Widget>[
        Icon(rootIcon, color: fg),
        SizedBox(width: theme.gapS),
      ],
      if (ref?.colorKey != null) ...<Widget>[
        ZSubfolderAccentPastille(colorKey: ref!.colorKey!),
        SizedBox(width: theme.gapS),
      ],
      Expanded(
        child: Text(
          label,
          // CR-IFFD-46, point 3 — borne ADRESSABLE. `null` ⇒ 1 ligne, rendu
          // strictement inchangé. La largeur est BORNÉE ici (`Expanded` dans
          // une colonne de largeur finie) : le retour à la ligne y est
          // réellement possible, contrairement à la rangée de puces.
          maxLines: spec.itemMaxLines ?? 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
              .copyWith(
            color: fg,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      if (ref?.count != null) ...<Widget>[
        SizedBox(width: theme.gapS),
        ZSubfolderCountPill(count: ref!.count!),
      ],
      if (_reorderable) ...<Widget>[
        SizedBox(width: theme.gapS),
        _DragHandle(
          index: index,
          label: spec.reorderHandleLabel ?? spec.allSubfoldersLabel,
        ),
      ],
    ];

    return Row(children: children);
  }
}

/// Poignée de drag DIRECTIONNELLE d'un item réordonnable (a11y label INJECTÉ,
/// cible ≥ 48 dp). Déclenche le drag du `ReorderableListView` par son index.
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Semantics(
        container: true,
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: const Icon(Icons.drag_handle),
        ),
      ),
    );
  }
}
