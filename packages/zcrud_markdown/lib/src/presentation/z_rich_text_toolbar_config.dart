/// `ZRichTextToolbarConfig` (DP-22, M20) — configuration **granulaire par bouton**
/// de la barre d'outils rich-text, NEUTRE (aucun type Quill).
///
/// Remplace/enrichit l'unique drapeau `showToolbar: bool` d'E6-1 par une
/// granularité au bouton (parité DODLP `RichTextToolbarConfig` — présets
/// `full`/`minimal`/`markdown`). Consommée par `ZMarkdownField` (voie `controller`
/// ET voie `ctx`) et traduite EN INTERNE (sous `lib/src/`) vers la config Quill —
/// AUCUN type Quill ne fuit dans cette classe ni dans la surface publique
/// (AD-1/AD-7).
///
/// RÉTRO-COMPAT (NON-NÉGOCIABLE) : `toolbarConfig` est OPTIONNEL. Un
/// `ZMarkdownField` sans `toolbarConfig` conserve EXACTEMENT le comportement
/// E6-1/DP-3 (drapeau `showToolbar` honoré, toolbar pleine en voie `controller`,
/// toolbar compacte en mode `inline`).
///
/// ISOLATION : classe de DONNÉES pure (booléens `const`) — sûre à exporter par le
/// barrel. Sa traduction en `QuillSimpleToolbarConfig` vit dans
/// `z_rich_text_core.dart` (interne), jamais ici.
library;

import 'package:flutter/foundation.dart';

/// Configuration granulaire (par bouton) de la toolbar rich-text (DP-22).
///
/// Chaque drapeau active/désactive UN groupe de boutons de la barre. Les présets
/// [full]/[minimal]/[markdown] couvrent les cas parité DODLP ; [copyWith] permet
/// une personnalisation fine par field.
@immutable
class ZRichTextToolbarConfig {
  /// Construit une config granulaire. Tous les groupes sont activés par DÉFAUT
  /// (équivaut au préset [full]) ; passez `false` pour masquer un groupe.
  const ZRichTextToolbarConfig({
    this.showUndoRedo = true,
    this.showFontFamily = true,
    this.showFontSize = true,
    this.showBold = true,
    this.showItalic = true,
    this.showUnderline = true,
    this.showStrikethrough = true,
    this.showInlineCode = true,
    this.showColor = true,
    this.showBackgroundColor = true,
    this.showClearFormat = true,
    this.showHeaderStyle = true,
    this.showAlignment = true,
    this.showList = true,
    this.showIndent = true,
    this.showBlockQuote = true,
    this.showCodeBlock = true,
    this.showLink = true,
    this.showSearch = true,
    this.showSubscript = true,
    this.showSuperscript = true,
    this.showLatexButton = true,
    this.showTableButton = true,
    this.showImageButton = true,
    this.showVideoButton = true,
  });

  /// Boutons Annuler/Rétablir.
  final bool showUndoRedo;

  /// Sélecteur de police.
  final bool showFontFamily;

  /// Sélecteur de taille de police.
  final bool showFontSize;

  /// Bouton **gras**.
  final bool showBold;

  /// Bouton *italique*.
  final bool showItalic;

  /// Bouton souligné.
  final bool showUnderline;

  /// Bouton barré.
  final bool showStrikethrough;

  /// Bouton code inline.
  final bool showInlineCode;

  /// Bouton couleur de texte.
  final bool showColor;

  /// Bouton couleur de fond (surlignage).
  final bool showBackgroundColor;

  /// Bouton effacer le format.
  final bool showClearFormat;

  /// Sélecteur de style de titre (H1..H6 / normal).
  final bool showHeaderStyle;

  /// Boutons d'alignement (gauche/centre/droite/justifié).
  final bool showAlignment;

  /// Boutons de liste (numérotée / à puces / cases à cocher).
  final bool showList;

  /// Boutons d'indentation (+/−).
  final bool showIndent;

  /// Bouton citation (blockquote).
  final bool showBlockQuote;

  /// Bouton bloc de code.
  final bool showCodeBlock;

  /// Bouton lien.
  final bool showLink;

  /// Bouton recherche.
  final bool showSearch;

  /// Bouton indice (subscript).
  final bool showSubscript;

  /// Bouton exposant (superscript).
  final bool showSuperscript;

  /// Bouton custom « Insérer une formule » (embed LaTeX, E6-3).
  final bool showLatexButton;

  /// Bouton custom « Insérer un tableau » (embed table, E6-4).
  final bool showTableButton;

  /// Bouton custom « Insérer une image » (embed image, DP-22).
  final bool showImageButton;

  /// Bouton custom « Insérer une vidéo » (embed vidéo, DP-22).
  final bool showVideoButton;

  /// Préset **complet** : tous les boutons (défaut de la voie `controller`).
  static const ZRichTextToolbarConfig full = ZRichTextToolbarConfig();

  /// Préset **minimal** (parité DODLP `minimal`) : style inline de base + listes,
  /// SANS police/couleur/alignement/embeds — pour un champ compact. C'est le
  /// préset appliqué par défaut au mode `inline`.
  static const ZRichTextToolbarConfig minimal = ZRichTextToolbarConfig(
    showUndoRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderline: true,
    showStrikethrough: false,
    showInlineCode: false,
    showColor: false,
    showBackgroundColor: false,
    showClearFormat: false,
    showHeaderStyle: false,
    showAlignment: false,
    showList: true,
    showIndent: false,
    showBlockQuote: false,
    showCodeBlock: false,
    showLink: false,
    showSearch: false,
    showSubscript: false,
    showSuperscript: false,
    showLatexButton: false,
    showTableButton: false,
    showImageButton: false,
    showVideoButton: false,
  );

  /// Préset **markdown** (parité DODLP `markdown`) : style + listes + insertions
  /// (embeds), SANS police/couleur/alignement — pensé pour un rendu Markdown.
  static const ZRichTextToolbarConfig markdown = ZRichTextToolbarConfig(
    showUndoRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderline: true,
    showStrikethrough: true,
    showInlineCode: true,
    showColor: false,
    showBackgroundColor: false,
    showClearFormat: false,
    showHeaderStyle: true,
    showAlignment: false,
    showList: true,
    showIndent: false,
    showBlockQuote: true,
    showCodeBlock: true,
    showLink: true,
    showSearch: false,
    showSubscript: false,
    showSuperscript: false,
    showLatexButton: true,
    showTableButton: true,
    showImageButton: true,
    showVideoButton: true,
  );

  /// Retourne une copie avec les drapeaux fournis remplacés (personnalisation
  /// par field à partir d'un préset).
  ZRichTextToolbarConfig copyWith({
    bool? showUndoRedo,
    bool? showFontFamily,
    bool? showFontSize,
    bool? showBold,
    bool? showItalic,
    bool? showUnderline,
    bool? showStrikethrough,
    bool? showInlineCode,
    bool? showColor,
    bool? showBackgroundColor,
    bool? showClearFormat,
    bool? showHeaderStyle,
    bool? showAlignment,
    bool? showList,
    bool? showIndent,
    bool? showBlockQuote,
    bool? showCodeBlock,
    bool? showLink,
    bool? showSearch,
    bool? showSubscript,
    bool? showSuperscript,
    bool? showLatexButton,
    bool? showTableButton,
    bool? showImageButton,
    bool? showVideoButton,
  }) {
    return ZRichTextToolbarConfig(
      showUndoRedo: showUndoRedo ?? this.showUndoRedo,
      showFontFamily: showFontFamily ?? this.showFontFamily,
      showFontSize: showFontSize ?? this.showFontSize,
      showBold: showBold ?? this.showBold,
      showItalic: showItalic ?? this.showItalic,
      showUnderline: showUnderline ?? this.showUnderline,
      showStrikethrough: showStrikethrough ?? this.showStrikethrough,
      showInlineCode: showInlineCode ?? this.showInlineCode,
      showColor: showColor ?? this.showColor,
      showBackgroundColor: showBackgroundColor ?? this.showBackgroundColor,
      showClearFormat: showClearFormat ?? this.showClearFormat,
      showHeaderStyle: showHeaderStyle ?? this.showHeaderStyle,
      showAlignment: showAlignment ?? this.showAlignment,
      showList: showList ?? this.showList,
      showIndent: showIndent ?? this.showIndent,
      showBlockQuote: showBlockQuote ?? this.showBlockQuote,
      showCodeBlock: showCodeBlock ?? this.showCodeBlock,
      showLink: showLink ?? this.showLink,
      showSearch: showSearch ?? this.showSearch,
      showSubscript: showSubscript ?? this.showSubscript,
      showSuperscript: showSuperscript ?? this.showSuperscript,
      showLatexButton: showLatexButton ?? this.showLatexButton,
      showTableButton: showTableButton ?? this.showTableButton,
      showImageButton: showImageButton ?? this.showImageButton,
      showVideoButton: showVideoButton ?? this.showVideoButton,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRichTextToolbarConfig &&
          runtimeType == other.runtimeType &&
          showUndoRedo == other.showUndoRedo &&
          showFontFamily == other.showFontFamily &&
          showFontSize == other.showFontSize &&
          showBold == other.showBold &&
          showItalic == other.showItalic &&
          showUnderline == other.showUnderline &&
          showStrikethrough == other.showStrikethrough &&
          showInlineCode == other.showInlineCode &&
          showColor == other.showColor &&
          showBackgroundColor == other.showBackgroundColor &&
          showClearFormat == other.showClearFormat &&
          showHeaderStyle == other.showHeaderStyle &&
          showAlignment == other.showAlignment &&
          showList == other.showList &&
          showIndent == other.showIndent &&
          showBlockQuote == other.showBlockQuote &&
          showCodeBlock == other.showCodeBlock &&
          showLink == other.showLink &&
          showSearch == other.showSearch &&
          showSubscript == other.showSubscript &&
          showSuperscript == other.showSuperscript &&
          showLatexButton == other.showLatexButton &&
          showTableButton == other.showTableButton &&
          showImageButton == other.showImageButton &&
          showVideoButton == other.showVideoButton;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        showUndoRedo,
        showFontFamily,
        showFontSize,
        showBold,
        showItalic,
        showUnderline,
        showStrikethrough,
        showInlineCode,
        showColor,
        showBackgroundColor,
        showClearFormat,
        showHeaderStyle,
        showAlignment,
        showList,
        showIndent,
        showBlockQuote,
        showCodeBlock,
        showLink,
        showSearch,
        showSubscript,
        showSuperscript,
        showLatexButton,
        showTableButton,
        showImageButton,
        showVideoButton,
      ]);
}
