/// `ZAnnotationToolbar` — barre d'outils d'annotation accessible : sélection
/// du kind (surlignage / note ancrée) + palette de colorKey, bâtie
/// au-dessus des modèles déjà livrés (`ZDocumentAnnotation`,
/// `ZDocumentAnnotationKind`) — aucun modèle n'est touché.
///
/// ## Accessibilité WCAG (invariant AD-13)
///
/// - **Couleur jamais seul canal** : chaque swatch porte (1) un
///   `Semantics.label` non vide et distinct (la `colorKey` / son libellé
///   injecté) et (2) un marqueur structurel non-coloré — icône « coché »
///   keyée [kAnnotationSelectedMarkerKey] — dans la swatch sélectionnée
///   uniquement ; chaque kind porte icône + libellé texte. Deux options qui
///   ne diffèrent que par la couleur restent distinguables sans la voir.
/// - **Contraste mesuré** : la couleur du marqueur/foreground dessiné sur
///   une swatch est dérivée du `ColorScheme` (le rôle `onSurface`/`surface`
///   qui contraste le plus avec le fond résolu) — jamais un `Colors.white`
///   en dur (qui serait invisible sur une swatch claire).
/// - **Cibles ≥ 48 dp**, `Semantics` explicites (`button`/`label`/
///   `selected`), rendu directionnel (`EdgeInsetsDirectional`,
///   `Wrap`/`WrapAlignment.start` mirrorés en RTL).
///
/// ## Réactivité Flutter-native (invariants AD-2/AD-15)
///
/// L'état vit dans un [ZAnnotationToolController] (owned/injected). Chaque
/// tranche est scopée par un `ValueListenableBuilder` : sélectionner une
/// couleur ne reconstruit pas la rangée des kinds, et inversement. Aucun
/// `setState` d'échelle toolbar, aucun gestionnaire d'état tiers.
///
/// ## Couleur/libellés injectés (invariant AD-13)
///
/// La `Color` d'une swatch vient de `ZcrudScope.colorKeyResolver`
/// (`zResolveColorKeyOrSlot`, repli total sur le `ColorScheme` courant,
/// invariant AD-10) — jamais un hex en dur. Les libellés (kind, couleur)
/// viennent de `ZcrudScope.labels` via `label(context, key, fallback)`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../domain/z_document_annotation_kind.dart';
import 'z_annotation_tool_controller.dart';

/// Barre d'outils d'annotation (présentation, owned/injected controller).
class ZAnnotationToolbar extends StatefulWidget {
  /// Construit la toolbar.
  ///
  /// - [controller] : controller injecté (l'appelant en garde la
  ///   propriété/le cycle de vie) ; `null` ⇒ la toolbar en possède un et le
  ///   `dispose` ;
  /// - [palette] : registre borné de `colorKey` proposées (défaut
  ///   `ZColorPalette.defaultStudy()`) ;
  /// - [onKindSelected] / [onColorSelected] : callbacks de remontée (`null`
  ///   = action absente, invariant AD-4) — la `colorKey` remonte brute
  ///   (`String`).
  const ZAnnotationToolbar({
    this.controller,
    this.palette = const ZColorPalette.defaultStudy(),
    this.onKindSelected,
    this.onColorSelected,
    this.onDebugBuild,
    this.onDebugKindRowBuild,
    super.key,
  });

  /// Controller injecté (owned/injected) ; `null` ⇒ possédé par la toolbar.
  final ZAnnotationToolController? controller;

  /// Palette de `colorKey` proposées (injectée, jamais une couleur
  /// concrète).
  final ZColorPalette palette;

  /// Remontée du `kind` sélectionné (`null` = non câblé).
  final ValueChanged<ZDocumentAnnotationKind>? onKindSelected;

  /// Remontée de la `colorKey` brute sélectionnée (`null` = non câblé).
  final ValueChanged<String>? onColorSelected;

  /// Seam de test (identité du controller au `build`). Reçoit le
  /// controller réellement utilisé à chaque `build` : recréer le
  /// controller dans `build` changerait l'identité observée.
  @visibleForTesting
  final ValueChanged<ZAnnotationToolController>? onDebugBuild;

  /// Seam de test (compteur de rebuild de la rangée des kinds). Appelé à
  /// chaque (re)build de la tranche `selectedKind` : un `setState` d'échelle
  /// toolbar le ferait grimper quand on change la couleur.
  @visibleForTesting
  final VoidCallback? onDebugKindRowBuild;

  @override
  State<ZAnnotationToolbar> createState() => _ZAnnotationToolbarState();
}

class _ZAnnotationToolbarState extends State<ZAnnotationToolbar> {
  late final ZAnnotationToolController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = ZAnnotationToolController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Seam d'identité : reporte le controller en cours d'usage.
    widget.onDebugBuild?.call(_controller);
    final theme = ZcrudTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── Tranche « kind » — n'écoute QUE selectedKind. ────────────────────
        ValueListenableBuilder<ZDocumentAnnotationKind>(
          valueListenable: _controller.selectedKind,
          builder: (context, selectedKind, _) {
            widget.onDebugKindRowBuild?.call();
            return Wrap(
              spacing: theme.gapM,
              runSpacing: theme.gapM,
              alignment: WrapAlignment.start,
              children: <Widget>[
                for (final kind in ZDocumentAnnotationKind.values)
                  _KindButton(
                    key: ValueKey<String>('$kAnnotationKindKeyPrefix${kind.name}'),
                    kind: kind,
                    selected: kind == selectedKind,
                    onTap: () {
                      _controller.selectKind(kind);
                      widget.onKindSelected?.call(kind);
                    },
                  ),
              ],
            );
          },
        ),
        SizedBox(height: theme.gapM),
        // ── Tranche « colorKey » — n'écoute QUE selectedColorKey. ────────────
        ValueListenableBuilder<String>(
          valueListenable: _controller.selectedColorKey,
          builder: (context, selectedColorKey, _) {
            return Wrap(
              spacing: theme.gapM,
              runSpacing: theme.gapM,
              alignment: WrapAlignment.start,
              children: <Widget>[
                for (final colorKey in widget.palette.keys)
                  _Swatch(
                    key: ValueKey<String>(
                        '$kAnnotationSwatchKeyPrefix$colorKey'),
                    colorKey: colorKey,
                    slotIndex: widget.palette.indexOf(colorKey),
                    selected: colorKey == selectedColorKey,
                    onTap: () {
                      _controller.selectColorKey(colorKey);
                      widget.onColorSelected?.call(colorKey);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Bouton d'un `kind` : icône + libellé (canal non-coloré), cible ≥ 48 dp,
/// `Semantics` explicite.
class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.kind,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ZDocumentAnnotationKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final text = label(
      context,
      'zcrud.annotation.kind.${kind.name}',
      fallback: kind.name,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Padding(
              padding: theme.fieldPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(_kindIcon(kind), size: 20),
                  SizedBox(width: theme.gapS),
                  Text(text, textAlign: TextAlign.start),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Swatch d'une `colorKey` : fond coloré injecté + libellé sémantique
/// distinct + marqueur structurel de sélection. Cible ≥ 48 dp.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colorKey,
    required this.slotIndex,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String colorKey;
  final int slotIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = ZcrudTheme.of(context);
    // Couleur injectée : seam hôte → repli ColorScheme (invariant AD-10),
    // jamais un hex en dur.
    final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: slotIndex);
    // Marqueur dérivé : le rôle du ColorScheme qui contraste le plus avec
    // le fond — jamais fixé (`Colors.white` interdit).
    final markerColor = _contrastingForeground(pair.color, scheme);
    // Canal non-coloré redondant : libellé distinct par colorKey (injecté).
    final text = label(
      context,
      'zcrud.annotation.color.$colorKey',
      fallback: colorKey,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                // Fond coloré résolu — keyé pour lecture directe par les tests.
                ColoredBox(
                  key: ValueKey<String>(
                      '$kAnnotationSwatchFillKeyPrefix$colorKey'),
                  color: pair.color,
                  child: const SizedBox(width: 48, height: 48),
                ),
                if (selected)
                  // Marqueur structurel non-coloré : présent uniquement dans
                  // la swatch sélectionnée.
                  Icon(
                    Icons.check,
                    key: const ValueKey<String>(kAnnotationSelectedMarkerKey),
                    color: markerColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône d'un `kind` (canal non-coloré). `IconData` — jamais une `Color`.
IconData _kindIcon(ZDocumentAnnotationKind kind) {
  switch (kind) {
    case ZDocumentAnnotationKind.highlight:
      return Icons.brush_outlined;
    case ZDocumentAnnotationKind.stickyNote:
      return Icons.sticky_note_2_outlined;
  }
}

/// Ratio de contraste WCAG 2.1 entre deux couleurs (luminance relative
/// dérivée de `Color.computeLuminance`). Résultat dans `[1, 21]`.
double _wcagContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Choisit, entre les rôles `onSurface` et `surface` du [scheme], celui qui
/// contraste le plus avec [background] — foreground dérivé, jamais fixé.
Color _contrastingForeground(Color background, ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final surface = scheme.surface;
  return _wcagContrastRatio(onSurface, background) >=
          _wcagContrastRatio(surface, background)
      ? onSurface
      : surface;
}
