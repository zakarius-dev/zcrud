/// Noyau **interne partagé** du rich-text Quill (DP-3) : embeds LaTeX/tableau,
/// config de toolbar STABLE et insertion/édition d'embed — FACTORISÉ depuis
/// `ZMarkdownField` (E6-1..E6-4) pour être RÉUTILISÉ **sans dupliquer le chemin
/// chaud** par les trois voies rich-text :
///   1. l'éditeur pleine-toolbar de la voie publique `ZMarkdownField({controller})`,
///   2. l'éditeur compact de la voie `ctx`/registre (mode `inline`),
///   3. l'éditeur plein-écran `ZRichTextFullscreenDialog`.
///
/// ISOLATION (AD-1/AD-7) : ce fichier vit sous `lib/src/` de `zcrud_markdown` et
/// peut donc consommer `flutter_quill`. AUCUN de ses symboles n'est re-exporté
/// par le barrel : la surface publique reste NEUTRE (aucun type Quill/math). Le
/// comportement d'insertion/édition d'embed est le MIROIR EXACT d'E6-3/E6-4 —
/// seule la localisation du code change (méthodes d'instance → fonctions
/// top-level paramétrées par le [QuillController]), pas la sémantique.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../data/delta_neutral_ops.dart';
import 'z_latex_embed.dart';
import 'z_table_embed.dart';

/// Cible de tap minimale (AD-13) — dimensionne les boutons de la toolbar et sa
/// hauteur minimale. PARTAGÉE par toutes les voies rich-text.
const double kZMinTapTarget = 48;

/// `EmbedBuilder`s branchés sur `QuillEditorConfig.embedBuilders` (E6-3/E6-4).
///
/// Liste `const` (donc CANONICALISÉE → instance UNIQUE partagée par tous les
/// builds ET par toutes les voies rich-text) : la référence est STABLE, aucune
/// allocation à chaque (re)build de tranche (SM-1/AD-2). MÊME liste pour LaTeX
/// (E6-3) ET tableau (E6-4), en édition ET en lecture. Définie HORS de la
/// surface publique scannée par les tests d'isolation de signature.
const List<EmbedBuilder> kZEmbedBuilders = <EmbedBuilder>[
  ZLatexEmbedBuilder(),
  ZTableEmbedBuilder(),
];

/// Construit une [QuillSimpleToolbarConfig] STABLE (SM-1/AD-2) branchée sur les
/// callbacks d'insertion d'embed [onInsertLatex]/[onInsertTable].
///
/// [minimal] `true` ⇒ toolbar compacte (voie `inline` : moins de boutons, une
/// seule rangée) ; `false` ⇒ toolbar complète (voie pleine-toolbar / plein-écran).
/// La config DOIT être construite UNE FOIS par l'appelant (en `initState`) et
/// HISSÉE en champ — jamais ré-allouée dans le chemin chaud de frappe.
QuillSimpleToolbarConfig buildZToolbarConfig({
  required VoidCallback onInsertLatex,
  required VoidCallback onInsertTable,
  bool minimal = false,
}) =>
    QuillSimpleToolbarConfig(
      toolbarSize: kZMinTapTarget,
      multiRowsDisplay: false,
      showAlignmentButtons: !minimal,
      // Rendu compact (mode inline) : on masque les groupes lourds pour tenir
      // sur une rangée, sans jamais retirer l'accès aux embeds (custom buttons).
      showColorButton: !minimal,
      showBackgroundColorButton: !minimal,
      showClearFormat: !minimal,
      showCodeBlock: !minimal,
      showQuote: !minimal,
      showIndent: !minimal,
      showSearchButton: !minimal,
      showSubscript: !minimal,
      showSuperscript: !minimal,
      customButtons: <QuillToolbarCustomButtonOptions>[
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.functions),
          tooltip: 'Insérer une formule',
          onPressed: onInsertLatex,
        ),
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.grid_on),
          tooltip: 'Insérer un tableau',
          onPressed: onInsertTable,
        ),
      ],
    );

// ─────────────────────────────── Embed LaTeX (E6-3) ──────────────────────────

/// Ouvre le dialogue de saisie/édition d'une formule LaTeX puis insère (ou
/// remplace) l'op embed `{insert:{latex:...}}` au point d'insertion courant du
/// [quill]. MIROIR EXACT d'E6-3 (`_promptAndInsertLatex`), paramétré par le
/// controller pour être partagé par toutes les voies. [isMounted] garde contre
/// une écriture après démontage de l'hôte.
Future<void> insertZLatex(
  BuildContext context,
  QuillController quill, {
  required bool Function() isMounted,
}) async {
  final _LatexEmbedHit? existing = _latexEmbedAtSelection(quill);
  final String? source =
      await showZLatexDialog(context, initial: existing?.source ?? '');
  if (source == null || !isMounted()) return;
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      ZLatexEmbed(source),
      TextSelection.collapsed(offset: existing.index + 1),
    );
    return;
  }
  final TextSelection sel = quill.selection;
  final int index =
      sel.isValid ? sel.start : (quill.document.length - 1).clamp(0, 1 << 30);
  final int length = sel.isValid ? sel.end - sel.start : 0;
  quill.replaceText(
    index,
    length,
    ZLatexEmbed(source),
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed LaTeX sous/juste-avant le caret (pour l'édition, E6-3).
_LatexEmbedHit? _latexEmbedAtSelection(QuillController quill) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert[kLatexEmbedType] is String) {
      if (caret == index || caret == index + 1) {
        return _LatexEmbedHit(index, insert[kLatexEmbedType] as String);
      }
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

// ─────────────────────────────── Embed tableau (E6-4) ────────────────────────

/// Ouvre le dialogue de saisie/édition d'un tableau puis insère (ou remplace)
/// l'op embed `{insert:{table:...}}` au point d'insertion courant du [quill].
/// MIROIR EXACT d'E6-4 (`_promptAndInsertTable`), paramétré par le controller.
Future<void> insertZTable(
  BuildContext context,
  QuillController quill, {
  required bool Function() isMounted,
}) async {
  final _TableEmbedHit? existing = _tableEmbedAtSelection(quill);
  final Map<String, dynamic>? structure =
      await showZTableDialog(context, initial: existing?.structure);
  if (structure == null || !isMounted()) return;
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      ZTableEmbed(structure),
      TextSelection.collapsed(offset: existing.index + 1),
    );
    return;
  }
  final TextSelection sel = quill.selection;
  final int index =
      sel.isValid ? sel.start : (quill.document.length - 1).clamp(0, 1 << 30);
  final int length = sel.isValid ? sel.end - sel.start : 0;
  quill.replaceText(
    index,
    length,
    ZTableEmbed(structure),
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed tableau sous/juste-avant le caret (pour l'édition, E6-4).
_TableEmbedHit? _tableEmbedAtSelection(QuillController quill) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert[kTableEmbedType] is Map) {
      if (caret == index || caret == index + 1) {
        return _TableEmbedHit(
          index,
          Map<String, dynamic>.from(insert[kTableEmbedType] as Map),
        );
      }
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

/// Localisation d'un embed LaTeX dans le document (index Delta + source).
class _LatexEmbedHit {
  const _LatexEmbedHit(this.index, this.source);

  final int index;
  final String source;
}

/// Localisation d'un embed tableau dans le document (index Delta + structure).
class _TableEmbedHit {
  const _TableEmbedHit(this.index, this.structure);

  final int index;
  final Map<String, dynamic> structure;
}
