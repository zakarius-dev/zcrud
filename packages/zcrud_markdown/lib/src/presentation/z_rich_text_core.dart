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
// SOURCE UNIQUE du type d'embed tableau (SM-S4 / ES-6.2) : re-câblage D3 sur la
// couture NEUTRE, `z_table_embed.dart` ne re-déclare plus `kTableEmbedType`.
import '../data/z_table_ops.dart';
import 'z_latex_embed.dart';
import 'z_media_embed.dart';
import 'z_rich_text_toolbar_config.dart';
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
  ZLatexBlockEmbedBuilder(),
  ZTableEmbedBuilder(),
  ZMediaEmbedBuilder(ZMediaKind.image),
  ZMediaEmbedBuilder(ZMediaKind.video),
];

/// Construit des [DefaultStyles] Quill dérivés du **thème** ambiant (MIN-1,
/// FR-26) : titres H1..H6 alignés sur les rôles typographiques du [TextTheme]
/// (couleurs/tailles/graisses du thème), SANS couleur codée en dur.
///
/// Part de `DefaultStyles.getInstance(context)` (déjà thémé par Quill) et
/// SURCHARGE les seuls styles de titre en fusionnant le rôle `TextTheme`
/// correspondant (H1→headlineLarge … H6→titleSmall). Les rôles absents laissent
/// le style Quill intact (dégradation sûre). Résultat NEUTRE côté API : ce type
/// Quill (`DefaultStyles`) ne fuit JAMAIS dans le barrel — il n'est consommé que
/// par les `QuillEditorConfig` internes (éditeur / lecteur / plein-écran).
///
/// AD-13 (documenté) : la parité DODLP (`QuillDefaultStylesHelper` + google_fonts
/// + palette de couleurs figée) n'est PAS reproduite — pas de dépendance
/// `google_fonts`, pas de couleur en dur. Seule la dérivation thème est portée.
DefaultStyles zQuillThemedStyles(BuildContext context) {
  final DefaultStyles base = DefaultStyles.getInstance(context);
  final TextTheme tt = Theme.of(context).textTheme;
  DefaultTextBlockStyle? merge(DefaultTextBlockStyle? proto, TextStyle? role) {
    if (proto == null || role == null) return proto;
    return proto.copyWith(style: proto.style.merge(role));
  }

  return base.merge(
    DefaultStyles(
      h1: merge(base.h1, tt.headlineLarge),
      h2: merge(base.h2, tt.headlineMedium),
      h3: merge(base.h3, tt.headlineSmall),
      h4: merge(base.h4, tt.titleLarge),
      h5: merge(base.h5, tt.titleMedium),
      h6: merge(base.h6, tt.titleSmall),
    ),
  );
}

/// Construit une [QuillSimpleToolbarConfig] STABLE (SM-1/AD-2) branchée sur les
/// callbacks d'insertion d'embed, PILOTÉE par une [ZRichTextToolbarConfig]
/// granulaire (DP-22, M20) — chaque bouton (natif Quill ET custom
/// LaTeX/table/image/vidéo) est activé/masqué au drapeau.
///
/// [config] traduit la granularité NEUTRE (aucun type Quill ne fuit à l'appelant)
/// vers les `showXxx` de Quill + la liste `customButtons`. La config DOIT être
/// construite UNE FOIS par l'appelant (en `initState`) et HISSÉE en champ —
/// jamais ré-allouée dans le chemin chaud de frappe.
QuillSimpleToolbarConfig buildZToolbarConfig({
  required VoidCallback onInsertLatex,
  required VoidCallback onInsertTable,
  VoidCallback? onInsertImage,
  VoidCallback? onInsertVideo,
  ZRichTextToolbarConfig config = ZRichTextToolbarConfig.full,
}) =>
    QuillSimpleToolbarConfig(
      toolbarSize: kZMinTapTarget,
      multiRowsDisplay: false,
      showUndo: config.showUndoRedo,
      showRedo: config.showUndoRedo,
      showFontFamily: config.showFontFamily,
      showFontSize: config.showFontSize,
      showBoldButton: config.showBold,
      showItalicButton: config.showItalic,
      showUnderLineButton: config.showUnderline,
      showStrikeThrough: config.showStrikethrough,
      showInlineCode: config.showInlineCode,
      showColorButton: config.showColor,
      showBackgroundColorButton: config.showBackgroundColor,
      showClearFormat: config.showClearFormat,
      showHeaderStyle: config.showHeaderStyle,
      showAlignmentButtons: config.showAlignment,
      showListNumbers: config.showList,
      showListBullets: config.showList,
      showListCheck: config.showList,
      showIndent: config.showIndent,
      showQuote: config.showBlockQuote,
      showCodeBlock: config.showCodeBlock,
      showLink: config.showLink,
      showSearchButton: config.showSearch,
      showSubscript: config.showSubscript,
      showSuperscript: config.showSuperscript,
      customButtons: <QuillToolbarCustomButtonOptions>[
        if (config.showLatexButton)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.functions),
            tooltip: 'Insérer une formule',
            onPressed: onInsertLatex,
          ),
        if (config.showTableButton)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Insérer un tableau',
            onPressed: onInsertTable,
          ),
        if (config.showImageButton && onInsertImage != null)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Insérer une image',
            onPressed: onInsertImage,
          ),
        if (config.showVideoButton && onInsertVideo != null)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Insérer une vidéo',
            onPressed: onInsertVideo,
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
  final ZLatexInput? input = await showZLatexDialog(
    context,
    initial: existing?.source ?? '',
    initialBlock: existing?.block ?? false,
  );
  if (input == null || !isMounted()) return;
  // MIN-1 : bascule inline/bloc → embed `latex` (text) vs `latexBlock` (display).
  final Embeddable embed = input.block
      ? ZLatexBlockEmbed(input.source)
      : ZLatexEmbed(input.source);
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      embed,
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
    embed,
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed LaTeX (inline `latex` OU bloc `latexBlock`) sous/juste-avant
/// le caret (pour l'édition, E6-3 + MIN-1). Retient le mode `block`.
_LatexEmbedHit? _latexEmbedAtSelection(QuillController quill) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map) {
      final bool isBlock = insert[kLatexBlockEmbedType] is String;
      final bool isInline = insert[kLatexEmbedType] is String;
      if ((isInline || isBlock) && (caret == index || caret == index + 1)) {
        final String source =
            (isBlock ? insert[kLatexBlockEmbedType] : insert[kLatexEmbedType])
                as String;
        return _LatexEmbedHit(index, source, block: isBlock);
      }
      // Un embed (latex ou autre) occupe une position Delta.
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

// ─────────────────────────────── Embed média (DP-22) ────────────────────────

/// Ouvre le dialogue de saisie/édition d'une **source média** ([kind] image ou
/// vidéo) puis insère (ou remplace) l'op embed `{insert:{image|video:<source>}}`
/// au point d'insertion courant du [quill]. MIROIR EXACT du flux LaTeX/table,
/// paramétré par la nature du média. SEAM NEUTRE : seule une source OPAQUE est
/// portée — aucun upload/accès réseau n'est câblé (cf. `z_media_embed.dart`).
Future<void> insertZMedia(
  BuildContext context,
  QuillController quill, {
  required ZMediaKind kind,
  required bool Function() isMounted,
}) async {
  final String embedType =
      kind == ZMediaKind.image ? kImageEmbedType : kVideoEmbedType;
  final _MediaEmbedHit? existing = _mediaEmbedAtSelection(quill, embedType);
  final String? source = await showZMediaSourceDialog(
    context,
    kind: kind,
    initial: existing?.source ?? '',
  );
  if (source == null || !isMounted()) return;
  final Embeddable embed =
      kind == ZMediaKind.image ? ZImageEmbed(source) : ZVideoEmbed(source);
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      embed,
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
    embed,
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed média (`embedType`) sous/juste-avant le caret (édition).
_MediaEmbedHit? _mediaEmbedAtSelection(QuillController quill, String embedType) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert[embedType] is String) {
      if (caret == index || caret == index + 1) {
        return _MediaEmbedHit(index, insert[embedType] as String);
      }
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

/// Localisation d'un embed média dans le document (index Delta + source).
class _MediaEmbedHit {
  const _MediaEmbedHit(this.index, this.source);

  final int index;
  final String source;
}

/// Localisation d'un embed LaTeX dans le document (index Delta + source + mode).
class _LatexEmbedHit {
  const _LatexEmbedHit(this.index, this.source, {required this.block});

  final int index;
  final String source;

  /// `true` si l'embed détecté est un `latexBlock` (display) — MIN-1.
  final bool block;
}

/// Localisation d'un embed tableau dans le document (index Delta + structure).
class _TableEmbedHit {
  const _TableEmbedHit(this.index, this.structure);

  final int index;
  final Map<String, dynamic> structure;
}
