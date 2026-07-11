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
export 'src/presentation/z_rich_text_fullscreen_dialog.dart'
    show showZRichTextFullscreenDialog, ZRichTextFullscreenDialog;
