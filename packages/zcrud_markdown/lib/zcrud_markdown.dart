/// Barrel d'API publique de `zcrud_markdown`.
///
/// Édition/lecture Markdown riche (Quill + `ZCodec` + embeds).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
///
/// ISOLATION (AD-1/AD-7) : ce barrel n'exporte AUCUN symbole `flutter_quill`
/// (aucun `QuillController`/`Document`/`Delta`). `ZMarkdownField` consomme/expose
/// une **valeur neutre** (Delta JSON) via `ZFormController` — aucun type Quill ne
/// fuit dans la signature publique.
library;

export 'src/data/z_delta_codec.dart';
export 'src/data/z_html_codec.dart';
export 'src/data/z_markdown_codec.dart';
// COMBLEMENT : couture NEUTRE pur-Dart de construction d'op embed
// tableau. N'EXPOSE QUE la fabrique `zTableEmbedOp` + le type `kTableEmbedType`
// (aucun type Quill) — l'embed de rendu et son builder restent INTERNES à
// `lib/src/presentation/` (isolation AD-1/AD-7).
export 'src/data/z_table_ops.dart' show zTableEmbedOp, kTableEmbedType;
export 'src/domain/z_codec.dart';
export 'src/domain/z_markdown_api.dart';
// (AD-57) : ponts Markdown ↔ embed OPT-IN.
// Description PURE DART (`RegExp`, `Match`, closures) — aucun type de lib de
// conversion n'y transite, c'est ce qui autorise l'export par le barrel.
export 'src/domain/z_markdown_bridge.dart';
export 'src/domain/z_markdown_copy_format.dart'
    show ZMarkdownCopyFormat, ZMarkdownCopyTransform;
export 'src/presentation/z_html_registration.dart' show registerZHtmlFields;
// (CR parité 2026-08-11) : habillage carte OPT-IN du champ rich-text
// (config PURE Flutter — aucun type Quill) + référence auditée de DIMENSIONS
// (patron `ZStudyCardReference`, aucune couleur).
export 'src/presentation/z_markdown_chrome.dart'
    show ZMarkdownFieldChrome, ZMarkdownChromeReference;
export 'src/presentation/z_markdown_codec_scope.dart';
export 'src/presentation/z_markdown_field.dart'
    show ZMarkdownField, ZMarkdownFieldMode, ZMarkdownFieldDebug;
export 'src/presentation/z_markdown_reader.dart'
    show ZMarkdownReader, ZMarkdownReaderChrome;
export 'src/presentation/z_markdown_registration.dart'
    show registerZMarkdownFields;
// Moteur Markdown du port `ZRichTextRenderer` de `zcrud_core` (DP-RT). Surface
// NEUTRE : la classe n'expose qu'un `ZCodec` et le `Widget?` du port — aucun
// type Quill.
export 'src/presentation/z_markdown_rich_text_renderer.dart'
    show ZMarkdownRichTextRenderer;
// (M20) : seam NEUTRE de résolution de source média (image/vidéo). N'EXPOSE
// QUE les symboles neutres (aucun type Quill) — les embeds `ZImageEmbed`/
// `ZVideoEmbed`/`ZMediaEmbedBuilder` (qui étendent `Embeddable`/`EmbedBuilder`)
// restent INTERNES à `lib/src/` (isolation AD-1/AD-7, cf. z_latex/z_table).
export 'src/presentation/z_media_embed.dart'
    show ZMediaEmbedScope, ZMediaResolver, ZMediaRef, ZMediaKind;
export 'src/presentation/z_rich_text_fullscreen_dialog.dart'
    show showZRichTextFullscreenDialog, ZRichTextFullscreenDialog;
// (M20) : config granulaire par bouton de la toolbar rich-text (donnée
// pure, aucun type Quill) — présets full/minimal/markdown, consommée par
// `ZMarkdownField.toolbarConfig`.
// (CR parité 2026-08-11) : jeu de styles rich-text NEUTRE par
// champ + spec de formules (PUR Flutter — `TextStyle`/`BoxDecoration`, aucun
// type Quill/math ; la traduction Quill vit sous `lib/src/`, interne).
export 'src/presentation/z_rich_text_style_set.dart'
    show ZRichTextStyleSet, ZRichTextSpacing, ZRichTextFormulaSpec;
export 'src/presentation/z_rich_text_toolbar_config.dart'
    show ZRichTextToolbarConfig;
// Mode d'interprétation du contenu d'une cellule de tableau, OPT-IN (AD-57) :
// la charge persistée ne change pas, seule sa LECTURE change. Absent ⇒ texte
// brut, c'est-à-dire le rendu historique.
export 'src/presentation/z_table_cell_scope.dart'
    show ZTableCellScope, ZTableCellContent;
