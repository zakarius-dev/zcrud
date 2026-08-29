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
/// La `Color` d'une swatch n'est jamais écrite ici : elle suit la chaîne
/// totale `zResolveAnnotationColor` — [ZAnnotationToolbar.swatchColors], puis
/// `ZcrudScope.colorKeyResolver` et les rôles Material 3, puis la palette
/// d'annotation de référence sous profil `ZReferenceProfile.legacy`, puis le
/// slot de `ColorScheme` indexé (invariant AD-10). Les libellés (kind,
/// couleur) viennent de `ZcrudScope.labels` via
/// `label(context, key, fallback)`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../domain/z_document_annotation_kind.dart';
import 'z_annotation_palette_reference.dart';
import 'z_annotation_tool_controller.dart';
import 'z_document_viewer_reference.dart';

/// Barre d'outils d'annotation (présentation, owned/injected controller).
class ZAnnotationToolbar extends StatefulWidget {
  /// Construit la toolbar.
  ///
  /// - [controller] : controller injecté (l'appelant en garde la
  ///   propriété/le cycle de vie) ; `null` ⇒ la toolbar en possède un et le
  ///   `dispose` ;
  /// - [palette] : registre borné de `colorKey` proposées (défaut
  ///   `ZColorPalette.defaultStudy()`) ;
  /// - [kinds] : natures proposées, dans l'ordre (défaut : toutes) ;
  /// - [onKindSelected] / [onColorSelected] : callbacks de remontée (`null`
  ///   = action absente, invariant AD-4) — la `colorKey` remonte brute
  ///   (`String`).
  const ZAnnotationToolbar({
    this.controller,
    this.palette = const ZColorPalette.defaultStudy(),
    this.kinds = ZDocumentAnnotationKind.values,
    this.onKindSelected,
    this.onColorSelected,
    this.swatchColors,
    this.swatchSize,
    this.onDebugBuild,
    this.onDebugKindRowBuild,
    super.key,
  });

  /// Controller injecté (owned/injected) ; `null` ⇒ possédé par la toolbar.
  final ZAnnotationToolController? controller;

  /// Palette de `colorKey` proposées (injectée, jamais une couleur
  /// concrète).
  final ZColorPalette palette;

  /// Natures d'annotation proposées, dans l'ordre de rendu.
  ///
  /// Défaut : toutes les natures connues. Restreindre cette liste est le
  /// moyen de figer le jeu d'outils d'une visionneuse — une nature ajoutée
  /// plus tard au socle n'apparaîtra alors pas d'elle-même dans la barre.
  final List<ZDocumentAnnotationKind> kinds;

  /// Remontée du `kind` sélectionné (`null` = non câblé).
  final ValueChanged<ZDocumentAnnotationKind>? onKindSelected;

  /// Remontée de la `colorKey` brute sélectionnée (`null` = non câblé).
  final ValueChanged<String>? onColorSelected;

  /// Couleurs des pastilles, indexées par le rang de la `colorKey` dans
  /// [palette].
  ///
  /// Posée, elle l'emporte sur tout le reste — résolveur d'hôte compris — et
  /// dans les deux profils de référence. Laissée nulle, la couleur suit la
  /// chaîne du socle : résolveur d'hôte, puis palette d'annotation de
  /// référence (profil `ZReferenceProfile.legacy`), puis rôle de
  /// `ColorScheme` indexé (profil `ZReferenceProfile.neutral`).
  ///
  /// Une liste plus courte que [palette] est **cyclée**, jamais tronquée : il
  /// n'existe pas de pastille sans couleur.
  final List<Color>? swatchColors;

  /// Côté de la pastille peinte — **pas** celui de la cible tactile, qui
  /// reste d'au moins 48 dp (AD-13) quelle que soit cette valeur.
  ///
  /// `null` ⇒ la référence auditée
  /// ([ZDocumentViewerReference.swatchSize]) sous profil
  /// `ZReferenceProfile.legacy`, la pleine cible sous
  /// `ZReferenceProfile.neutral`.
  final double? swatchSize;

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
                for (final kind in widget.kinds)
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
                    swatchColors: widget.swatchColors,
                    size: widget.swatchSize ??
                        zDocumentLegacyOrNeutral<double>(
                          theme.referenceProfile,
                          ZDocumentViewerReference.swatchSize,
                          ZDocumentViewerReference.minTouchTarget,
                        ),
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
        constraints: const BoxConstraints(
          minWidth: ZDocumentViewerReference.minTouchTarget,
          minHeight: ZDocumentViewerReference.minTouchTarget,
        ),
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
                  Icon(
                    _kindIcon(kind),
                    size: ZDocumentViewerReference.barIconSize,
                  ),
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
    required this.swatchColors,
    required this.size,
    required this.onTap,
    super.key,
  });

  final String colorKey;
  final int slotIndex;
  final bool selected;
  final List<Color>? swatchColors;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = ZcrudTheme.of(context);
    // Couleur injectée : paramètre → seam hôte → référence auditée (profil
    // legacy) → repli ColorScheme (invariant AD-10), jamais un hex ici.
    final pair = zResolveAnnotationColor(
      context,
      colorKey,
      slotIndex: slotIndex,
      swatchColors: swatchColors,
    );
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
        constraints: const BoxConstraints(
          minWidth: ZDocumentViewerReference.minTouchTarget,
          minHeight: ZDocumentViewerReference.minTouchTarget,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                // Fond coloré résolu — keyé pour lecture directe par les tests.
                // La pastille peut être plus petite que la cible : le
                // `ConstrainedBox` ci-dessus tient les 48 dp, le `Stack` centre.
                ColoredBox(
                  key: ValueKey<String>(
                      '$kAnnotationSwatchFillKeyPrefix$colorKey'),
                  color: pair.color,
                  child: SizedBox(width: size, height: size),
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
    case ZDocumentAnnotationKind.underline:
      return Icons.format_underlined;
    case ZDocumentAnnotationKind.strikethrough:
      return Icons.format_strikethrough;
    case ZDocumentAnnotationKind.squiggly:
      return Icons.waves;
  }
}

/// Choisit, entre les rôles `onSurface` et `surface` du [scheme], celui qui
/// contraste le plus avec [background] — foreground dérivé, jamais fixé.
///
/// La mesure porte sur `background` **tel que passé** : un fond
/// semi-transparent doit être composé (`zCompositeOver`) par l'appelant avant
/// d'arriver ici, sinon le chiffre ne décrit pas ce qui est peint.
Color _contrastingForeground(Color background, ColorScheme scheme) {
  // Le rapport de contraste est calculé par l'UNIQUE implémentation du socle
  // (`zContrastRatio`, zcrud_core) : un second calculateur, même délégué au
  // SDK, finit toujours par diverger de celui qui porte les planchers.
  final onSurface = scheme.onSurface;
  final surface = scheme.surface;
  return zContrastRatio(onSurface, background) >=
          zContrastRatio(surface, background)
      ? onSurface
      : surface;
}
