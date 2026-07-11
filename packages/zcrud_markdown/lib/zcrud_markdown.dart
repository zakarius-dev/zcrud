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
export 'src/domain/z_codec.dart';
export 'src/domain/z_markdown_api.dart';
export 'src/presentation/z_html_registration.dart' show registerZHtmlFields;
export 'src/presentation/z_markdown_codec_scope.dart';
export 'src/presentation/z_markdown_field.dart'
    show ZMarkdownField, ZMarkdownFieldMode, ZMarkdownFieldDebug;
export 'src/presentation/z_markdown_reader.dart' show ZMarkdownReader;
export 'src/presentation/z_markdown_registration.dart'
    show registerZMarkdownFields;
// DP-22 (M20) : seam NEUTRE de résolution de source média (image/vidéo). N'EXPOSE
// QUE les symboles neutres (aucun type Quill) — les embeds `ZImageEmbed`/
// `ZVideoEmbed`/`ZMediaEmbedBuilder` (qui étendent `Embeddable`/`EmbedBuilder`)
// restent INTERNES à `lib/src/` (isolation AD-1/AD-7, cf. z_latex/z_table).
export 'src/presentation/z_media_embed.dart'
    show ZMediaEmbedScope, ZMediaResolver, ZMediaRef, ZMediaKind;
export 'src/presentation/z_rich_text_fullscreen_dialog.dart'
    show showZRichTextFullscreenDialog, ZRichTextFullscreenDialog;
// DP-22 (M20) : config granulaire par bouton de la toolbar rich-text (donnée
// pure, aucun type Quill) — présets full/minimal/markdown, consommée par
// `ZMarkdownField.toolbarConfig`.
export 'src/presentation/z_rich_text_toolbar_config.dart'
    show ZRichTextToolbarConfig;
