/// `ZAnnotationPanel` — liste accessible des annotations existantes.
/// Lecture/sélection ; l'édition du texte d'une note ancrée est déléguée à
/// l'hôte (hors périmètre du panel).
///
/// - `ListView.builder` — jamais `ListView(children: [...])` : la liste est
///   lazy (seul un sous-ensemble d'entrées est construit).
/// - Chaque entrée : icône + libellé de `kind` (canal non-coloré), swatch
///   (fond injecté + libellé `colorKey` redondant), extrait `text`/`page`,
///   cible ≥ 48 dp, `Semantics` explicite (kind + page + extrait).
/// - Défensif (invariant AD-10) : `text == null`/`colorKey == ''`/`kind`
///   par défaut ⇒ rendu propre (placeholder + swatch de repli
///   `ColorScheme`) ; liste vide ⇒ état vide dédié ; résolveur de couleur
///   absent ⇒ repli `ColorScheme`. Jamais de `throw`.
/// - `onSelect == null` ⇒ entrée non tapable (invariant AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../domain/z_document_annotation.dart';
import '../domain/z_document_annotation_kind.dart';
import 'z_annotation_palette_reference.dart';
import 'z_annotation_tool_controller.dart';
import 'z_document_viewer_reference.dart';

/// Panneau listant les [ZDocumentAnnotation] d'un document (présentation).
class ZAnnotationPanel extends StatelessWidget {
  /// Construit le panneau.
  ///
  /// - [annotations] : liste à afficher (ordre stable, conservé) ;
  /// - [onSelect] : callback de sélection (`null` = entrées non tapables,
  ///   invariant AD-4) ;
  /// - [palette] : palette de résolution des `colorKey` (injectée) ;
  /// - [emptyState] : widget d'état vide (défaut : libellé accessible
  ///   injecté).
  const ZAnnotationPanel({
    required this.annotations,
    this.onSelect,
    this.palette = const ZColorPalette.defaultStudy(),
    this.emptyState,
    this.swatchColors,
    this.entryCornerRadius,
    super.key,
  });

  /// Annotations à lister (ordre préservé).
  final List<ZDocumentAnnotation> annotations;

  /// Remontée de sélection (`null` = non tapable).
  final ValueChanged<ZDocumentAnnotation>? onSelect;

  /// Palette de résolution des `colorKey`.
  final ZColorPalette palette;

  /// État vide surchargeable (défaut : libellé accessible).
  final Widget? emptyState;

  /// Couleurs des pastilles, indexées par le rang de la `colorKey` dans
  /// [palette].
  ///
  /// Posée, elle l'emporte sur tout le reste — résolveur d'hôte compris — et
  /// dans les deux profils de référence. Laissée nulle, la couleur suit la
  /// chaîne du socle : résolveur d'hôte, puis palette d'annotation de
  /// référence (profil `ZReferenceProfile.legacy`), puis rôle de
  /// `ColorScheme` indexé (profil `ZReferenceProfile.neutral`).
  ///
  /// Une liste plus courte que [palette] est **cyclée**, jamais tronquée.
  final List<Color>? swatchColors;

  /// Rayon des coins de l'encre d'une entrée.
  ///
  /// `null` ⇒ la référence auditée
  /// ([ZDocumentViewerReference.panelCornerRadius]) sous profil
  /// `ZReferenceProfile.legacy`, aucun rayon sous
  /// `ZReferenceProfile.neutral`.
  final double? entryCornerRadius;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return emptyState ??
          Semantics(
            label: label(
              context,
              'zcrud.annotation.panel.empty',
              fallback: 'No annotations',
            ),
            child: Center(
              child: Text(
                label(
                  context,
                  'zcrud.annotation.panel.empty',
                  fallback: 'No annotations',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
    }
    final double? cornerRadius = entryCornerRadius ??
        zDocumentLegacyOrNeutral<double?>(
          ZcrudTheme.of(context).referenceProfile,
          ZDocumentViewerReference.panelCornerRadius,
          null,
        );
    return ListView.builder(
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final annotation = annotations[index];
        return _PanelEntry(
          key: ValueKey<String>(
              '$kAnnotationPanelEntryKeyPrefix${annotation.id ?? index}'),
          annotation: annotation,
          slotIndex: palette.indexOf(annotation.colorKey),
          swatchColors: swatchColors,
          cornerRadius: cornerRadius,
          onTap: onSelect == null ? null : () => onSelect!(annotation),
        );
      },
    );
  }
}

/// Entrée accessible d'une annotation (cible ≥ 48 dp, `Semantics`, canal
/// non-coloré). Privée.
class _PanelEntry extends StatelessWidget {
  const _PanelEntry({
    required this.annotation,
    required this.slotIndex,
    required this.swatchColors,
    required this.cornerRadius,
    required this.onTap,
    super.key,
  });

  final ZDocumentAnnotation annotation;
  final int slotIndex;
  final List<Color>? swatchColors;
  final double? cornerRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final kindText = label(
      context,
      'zcrud.annotation.kind.${annotation.kind.name}',
      fallback: annotation.kind.name,
    );
    final colorText = label(
      context,
      'zcrud.annotation.color.${annotation.colorKey}',
      fallback: annotation.colorKey.isEmpty ? 'default' : annotation.colorKey,
    );
    final excerpt = (annotation.text == null || annotation.text!.trim().isEmpty)
        ? label(
            context,
            'zcrud.annotation.entry.empty',
            fallback: '(no text)',
          )
        : annotation.text!.trim();
    final pageText = label(
      context,
      'zcrud.annotation.entry.page',
      fallback: 'page',
    );
    // Fond injecté : paramètre → seam hôte → référence auditée (profil
    // legacy) → repli total ColorScheme (invariant AD-10) — jamais un hex ici.
    final pair = zResolveAnnotationColor(
      context,
      annotation.colorKey,
      slotIndex: slotIndex,
      swatchColors: swatchColors,
    );
    // Canal texte redondant : kind + page + extrait, jamais la couleur
    // seule.
    final semanticsValue = '$kindText · $pageText ${annotation.page} · $excerpt';

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: ZDocumentViewerReference.minTouchTarget,
      ),
      child: Padding(
        padding: theme.fieldPadding,
        child: Row(
          children: <Widget>[
            Icon(
              _entryIcon(annotation.kind),
              size: ZDocumentViewerReference.barIconSize,
            ),
            SizedBox(width: theme.gapM),
            // Swatch : fond coloré + libellé `colorKey` redondant (non-coloré).
            ColoredBox(
              color: pair.color,
              child: const SizedBox(width: 24, height: 24),
            ),
            SizedBox(width: theme.gapS),
            Text(colorText),
            SizedBox(width: theme.gapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('$kindText · $pageText ${annotation.page}'),
                  Text(
                    excerpt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: kindText,
      value: semanticsValue,
      child: onTap == null
          ? row
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: cornerRadius == null
                    ? null
                    : BorderRadius.all(Radius.circular(cornerRadius!)),
                child: row,
              ),
            ),
    );
  }
}

/// Icône d'entrée selon le `kind` (canal non-coloré). `IconData`, jamais
/// `Color`.
IconData _entryIcon(ZDocumentAnnotationKind kind) {
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

