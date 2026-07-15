/// `ZAnnotationPanel` — liste ACCESSIBLE des annotations existantes (ES-8.2, D3,
/// D8, FR-S28). Lecture/sélection ; l'édition du texte d'une sticky note est
/// **déléguée à l'hôte** (hors périmètre du panel).
///
/// - **`ListView.builder`** (NFR-S6) — jamais `ListView(children: [...])` : la
///   liste est LAZY (seul un sous-ensemble d'entrées est construit).
/// - Chaque entrée : icône + libellé de `kind` (canal non-coloré, D5), swatch
///   (fond INJECTÉ + libellé `colorKey` redondant), extrait `text`/`page`, cible
///   ≥ 48 dp, `Semantics` explicite (kind + page + extrait).
/// - **Défensif** (AD-10) : `text == null`/`colorKey == ''`/`kind` par défaut ⇒
///   rendu propre (placeholder + swatch de repli `ColorScheme`) ; liste vide ⇒
///   **empty-state** ; `colorKeyResolver` absent ⇒ repli `ColorScheme`. Jamais
///   de throw.
/// - `onSelect == null` ⇒ entrée NON tapable (AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../domain/z_document_annotation.dart';
import '../domain/z_document_annotation_kind.dart';
import 'z_annotation_tool_controller.dart';

/// Panneau listant les [ZDocumentAnnotation] d'un document (présentation).
class ZAnnotationPanel extends StatelessWidget {
  /// Construit le panneau.
  ///
  /// - [annotations] : liste à afficher (ordre stable, conservé) ;
  /// - [onSelect] : callback de sélection (`null` = entrées non tapables, AD-4) ;
  /// - [palette] : palette de résolution des `colorKey` (injectée) ;
  /// - [emptyState] : widget d'état vide (défaut : libellé accessible injecté).
  const ZAnnotationPanel({
    required this.annotations,
    this.onSelect,
    this.palette = const ZColorPalette.defaultStudy(),
    this.emptyState,
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
    return ListView.builder(
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final annotation = annotations[index];
        return _PanelEntry(
          key: ValueKey<String>(
              '$kAnnotationPanelEntryKeyPrefix${annotation.id ?? index}'),
          annotation: annotation,
          slotIndex: palette.indexOf(annotation.colorKey),
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
    required this.onTap,
    super.key,
  });

  final ZDocumentAnnotation annotation;
  final int slotIndex;
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
    // Fond INJECTÉ, repli total ColorScheme (AD-10) — jamais un hex en dur.
    final pair =
        zResolveColorKeyOrSlot(context, annotation.colorKey, slotIndex: slotIndex);
    // Canal texte redondant (D5/D7) : kind + page + extrait, JAMAIS la couleur
    // seule.
    final semanticsValue = '$kindText · $pageText ${annotation.page} · $excerpt';

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: theme.fieldPadding,
        child: Row(
          children: <Widget>[
            Icon(_entryIcon(annotation.kind), size: 20),
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
              child: InkWell(onTap: onTap, child: row),
            ),
    );
  }
}

/// Icône d'entrée selon le `kind` (canal non-coloré). `IconData`, jamais `Color`.
IconData _entryIcon(ZDocumentAnnotationKind kind) {
  switch (kind) {
    case ZDocumentAnnotationKind.highlight:
      return Icons.brush_outlined;
    case ZDocumentAnnotationKind.stickyNote:
      return Icons.sticky_note_2_outlined;
  }
}

