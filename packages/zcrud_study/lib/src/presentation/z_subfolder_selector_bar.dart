/// `ZSubfolderSelectorBar` — surface de navigation de sous-dossiers par DÉFAUT
/// sur petit écran (CR-IFFD-40).
///
/// ## Le défaut corrigé
///
/// La rangée de puces défilante (`ZSubfolderCompactSelector`) répondait à
/// « lesquels existent ? » avant « **lequel est actif ?** » : après un seul
/// balayage, la pastille sélectionnée sortait du champ visible et l'utilisateur
/// perdait le « où suis-je », devant défiler en sens inverse pour le retrouver.
/// Rien n'était inaccessible — c'est la perte de l'ÉTAT COURANT qui était le
/// défaut.
///
/// ## Les trois propriétés qui comptent
///
/// 1. surface **pleine largeur**, **une seule ligne**, hauteur prévisible
///    (≥ 48 dp, AD-13) ;
/// 2. elle affiche **l'élément courant**, avec un repli explicite sur
///    [ZSubfolderNavSpec.allSubfoldersLabel] quand aucun n'est sélectionné —
///    **jamais un vide** (y compris si la sélection porte un id INCONNU de la
///    liste, AD-10) ;
/// 3. l'affordance d'ouverture est **visible** (chevron), et non déduite du
///    défilement.
///
/// La fratrie ne se déploie qu'à la demande, **en ligne** (aucune surface
/// flottante) : le panneau hérite donc de la `Directionality` de l'arbre, là où
/// un `Overlay` l'aurait perdue.
///
/// **AD-2/AD-15** : la SÉLECTION reste détenue par le parent (tranche
/// `ValueListenable` injectée) ; le seul état local est le dépli
/// (`ValueNotifier<bool>` créé une fois, disposé une fois), scopé par
/// `ValueListenableBuilder` — ouvrir/fermer ne reconstruit ni le corps de la
/// page ni les onglets. **AD-13** : `Semantics(selected:/button:/expanded:)`,
/// cibles ≥ 48 dp, insets **directionnels**. **FR-26** : aucune couleur ni
/// libellé en dur (les glyphes sont des `IconData` conventionnels, jamais des
/// libellés).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import 'z_subfolder_item_content.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Cible interactive minimale (AD-13).
const double _kMinTapTarget = 48.0;

/// Hauteur MAXIMALE absolue du panneau déployé (dp) — dimension de layout.
const double _kPanelMaxHeight = 240.0;

/// Fraction MAXIMALE de la hauteur d'écran occupée par le panneau déployé.
/// Repli défensif (AD-10) : sur un écran court, le panneau ne pousse jamais le
/// corps hors de la fenêtre.
const double _kPanelMaxHeightFraction = 0.4;

/// Glyphes conventionnels du chevron (jamais des libellés).
const IconData _kOpenIcon = Icons.expand_more;
const IconData _kCloseIcon = Icons.expand_less;

/// Glyphe conventionnel « ajouter » de REPLI (jamais un libellé).
const IconData _kAddFallbackIcon = Icons.add;

/// Barre de sélection de sous-dossiers (petit écran, surface par DÉFAUT).
class ZSubfolderSelectorBar extends StatefulWidget {
  /// Construit la barre de sélection.
  const ZSubfolderSelectorBar({
    required this.spec,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Clé stable de la barre (exposée pour les tests).
  static const Key barKey = ValueKey<String>('suf3:selector');

  /// Clé stable de la ligne cliquable montrant l'élément courant.
  static const Key triggerKey = ValueKey<String>('suf3:selector:trigger');

  /// Clé stable du chevron d'ouverture.
  static const Key chevronKey = ValueKey<String>('suf3:selector:chevron');

  /// Clé stable du panneau déployé (ABSENT de l'arbre tant qu'il est fermé).
  static const Key panelKey = ValueKey<String>('suf3:selector:panel');

  /// Clé stable du bouton « Ajouter » (absent si `spec.addAction == null`).
  static const Key addKey = ValueKey<String>('suf3:selector:add');

  /// Clé stable d'un item du panneau ([id] vide = item racine « tous »).
  static Key itemKey(String id) => ValueKey<String>('suf3:selector:item:$id');

  /// Descripteur de navigation (données + libellés, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine).
  final ValueListenable<String?> selected;

  /// Émis quand un item est choisi (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  @override
  State<ZSubfolderSelectorBar> createState() => _ZSubfolderSelectorBarState();
}

class _ZSubfolderSelectorBarState extends State<ZSubfolderSelectorBar> {
  /// Dépli du panneau — SEUL état local (AD-2 : la sélection reste au parent).
  final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _toggle() => _open.value = !_open.value;

  /// Item courant, ou `null` pour la racine.
  ///
  /// **AD-10** : un id qui ne correspond à AUCUN sous-dossier (liste rafraîchie,
  /// dossier supprimé) retombe sur la racine — la barre affiche alors le repli
  /// [ZSubfolderNavSpec.allSubfoldersLabel], jamais un vide.
  ZSubfolderRef? _currentRef(String? id) {
    if (id == null) return null;
    for (final ZSubfolderRef ref in widget.spec.subfolders) {
      if (ref.id == id) return ref;
    }
    return null;
  }

  Widget _itemContent(
    BuildContext context,
    ZSubfolderRef? refOrNull,
    bool selected,
  ) => zBuildSubfolderItemContent(
    context,
    spec: widget.spec,
    refOrNull: refOrNull,
    label: refOrNull?.label ?? widget.spec.allSubfoldersLabel,
    selected: selected,
  );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    // Scope de mode posé AU-DESSUS de tout le sous-arbre d'items : un
    // `itemBuilder` injecté observe `compact` ici comme dans la rangée de puces
    // — un builder existant rend donc à l'identique (CR-IFFD-31/CR-IFFD-40).
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.compact,
      child: Column(
        key: ZSubfolderSelectorBar.barKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _bar(context, theme),
          ValueListenableBuilder<bool>(
            valueListenable: _open,
            builder: (context, open, _) => open
                ? _panel(context, theme)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- Ligne unique : élément courant + chevron (+ « Ajouter ») -------------

  Widget _bar(BuildContext context, ZcrudTheme theme) {
    return Row(
      children: <Widget>[
        Expanded(child: _trigger(context, theme)),
        // Slot d'ajout — MÊME capacité que la rangée de puces et que la sidebar
        // (AD-4 : `addAction` null ⇒ bouton ABSENT de l'arbre).
        if (widget.spec.addAction != null) _addButton(context, theme),
      ],
    );
  }

  Widget _trigger(BuildContext context, ZcrudTheme theme) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selected,
      builder: (context, currentId, _) {
        final ZSubfolderRef? ref = _currentRef(currentId);
        final String label = ref?.label ?? widget.spec.allSubfoldersLabel;
        return ValueListenableBuilder<bool>(
          valueListenable: _open,
          builder: (context, open, _) {
            return Semantics(
              container: true,
              button: true,
              expanded: open,
              // Annonce de l'ÉLÉMENT COURANT — c'est la réponse à « où
              // suis-je ». `excludeSemantics` garantit UNE seule annonce, même
              // quand le contenu vient d'un `itemBuilder` injecté.
              label: label,
              excludeSemantics: true,
              onTap: _toggle,
              child: InkWell(
                key: ZSubfolderSelectorBar.triggerKey,
                onTap: _toggle,
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _kMinTapTarget,
                    minWidth: _kMinTapTarget,
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.gapM,
                      vertical: theme.gapS,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _itemContent(context, ref, true),
                          ),
                        ),
                        SizedBox(width: theme.gapS),
                        // Affordance VISIBLE d'ouverture (jamais déduite du
                        // défilement), ancrée côté END (RTL-safe : c'est la
                        // `Row` directionnelle qui la place, aucun `left`/
                        // `right`).
                        Icon(
                          open ? _kCloseIcon : _kOpenIcon,
                          key: ZSubfolderSelectorBar.chevronKey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _addButton(BuildContext context, ZcrudTheme theme) {
    final String label =
        widget.spec.addLabel ?? widget.spec.allSubfoldersLabel;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        key: ZSubfolderSelectorBar.addKey,
        onPressed: widget.spec.addAction,
        tooltip: label,
        icon: Icon(
          widget.spec.addIcon ?? _kAddFallbackIcon,
          semanticLabel: label,
        ),
      ),
    );
  }

  // --- Panneau déployé (à la demande) --------------------------------------

  Widget _panel(BuildContext context, ZcrudTheme theme) {
    final List<ZSubfolderRef> subfolders = widget.spec.subfolders;
    // Borne défensive (AD-10) : sur un écran court, le panneau ne chasse pas le
    // corps de la page hors de la fenêtre.
    final double maxHeight = math.min(
      _kPanelMaxHeight,
      MediaQuery.sizeOf(context).height * _kPanelMaxHeightFraction,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.builder(
        key: ZSubfolderSelectorBar.panelKey,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        // +1 : l'item racine « tous » est TOUJOURS en tête (AC8).
        itemCount: subfolders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _panelItem(context, theme, null);
          }
          return _panelItem(context, theme, subfolders[index - 1]);
        },
      ),
    );
  }

  Widget _panelItem(
    BuildContext context,
    ZcrudTheme theme,
    ZSubfolderRef? refOrNull,
  ) {
    final String? id = refOrNull?.id;
    final String label = refOrNull?.label ?? widget.spec.allSubfoldersLabel;
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selected,
      builder: (context, current, _) {
        final bool isSelected = current == id;
        return Semantics(
          container: true,
          button: true,
          selected: isSelected,
          label: label,
          excludeSemantics: true,
          onTap: () => _select(id),
          child: InkWell(
            key: ZSubfolderSelectorBar.itemKey(id ?? ''),
            onTap: () => _select(id),
            excludeFromSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              // Surbrillance posée AUTOUR du contenu — donc aussi quand il vient
              // d'un `itemBuilder` injecté (même contrat que la sidebar : la
              // mise en évidence n'est JAMAIS déléguée à l'hôte).
              child: Container(
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
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _itemContent(context, refOrNull, isSelected),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Choisit [id] et REFERME le panneau : la fratrie ne reste pas déployée, la
  /// barre revient à sa ligne unique montrant le nouvel élément courant.
  void _select(String? id) {
    widget.onSelect(id);
    _open.value = false;
  }
}
