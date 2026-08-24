/// Factory d'enregistrement des champs rich-text `zcrud_markdown` dans un
/// [ZWidgetRegistry] injecté (AD-4).
///
/// Enregistre les `kind` `markdown` (mode `block`), `inlineMarkdown` (mode
/// `inline`) et `richText` (mode `block`, alias) sur le MÊME adaptateur
/// `ctx`-natif ([ZMarkdownField.fromContext]) paramétré par le mode. Le widget
/// réel est fourni par CE package satellite (le cœur reste agnostique — AD-1) ;
/// le registre est INSTANCIABLE et injecté via `ZcrudScope.widgetRegistry` —
/// jamais un singleton statique mutable.
///
/// Une collision de `kind` fait **`throw`** (contrat `ZWidgetRegistry.register`).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_codec.dart';
import '../domain/z_markdown_copy_format.dart';
import 'z_markdown_chrome.dart';
import 'z_markdown_field.dart';
import 'z_rich_text_style_set.dart';
import 'z_rich_text_toolbar_config.dart';

/// Enregistre les builders rich-text `zcrud_markdown` dans [registry].
///
/// [codec] optionnel : format persisté partagé par tous les champs (défaut
/// `ZDeltaCodec` via [ZMarkdownField]). Chaque builder construit un
/// [ZMarkdownField.fromContext] avec `key: ValueKey(field.name)` (place stable —
/// AD-2) et le [ZMarkdownFieldMode] dérivé du `kind` :
///
/// | `kind`           | mode    |
/// |------------------|---------|
/// | `inlineMarkdown` | inline  |
/// | `markdown`       | block   |
/// | `richText`       | block   |
///
/// `field.readOnly` est honoré par l'adaptateur (rendu lecteur, prioritaire).
/// [minLines]/[maxLines] bornent la hauteur de l'éditeur inline
/// (mode compact) ; [characterLimit] active un compteur + troncature
/// souple. [styleSet]/[chrome]/[textScaleFactor]/[formulaSpec] : défauts de
/// REGISTRE partagés par tous les champs rich-text du sous-arbre (styles
/// « signature » de l'hôte, habillage carte, échelle, formules).
/// [toolbarConfig] :
/// config granulaire de la barre d'outils (boutons + `themedBarBackground`)
/// partagée par tous les champs rich-text — le registre est la SEULE voie de
/// construction pour un hôte, donc tout paramètre par-champ de [ZMarkdownField]
/// DOIT être posable ici (garde de parité
/// `z_markdown_registration_parity_test.dart`). [showLabel] : `false` masque
/// le libellé rendu par le champ (hôte posant le sien).
/// Tous OPTIONNELS : omis ⇒ comportement INCHANGÉ.
void registerZMarkdownFields(
  ZWidgetRegistry registry, {
  ZCodec? codec,
  int? minLines,
  int? maxLines,
  int? characterLimit,
  ZRichTextStyleSet? styleSet,
  ZMarkdownFieldChrome? chrome,
  double? textScaleFactor,
  ZRichTextFormulaSpec? formulaSpec,
  ZRichTextToolbarConfig? toolbarConfig,
  bool showLabel = true,
  IconData? emptyIcon,
  String? emptySubtitle,
  WidgetBuilder? emptyBuilder,
  bool copyOnLongPress = false,
  List<ZMarkdownCopyFormat> copyFormats = const <ZMarkdownCopyFormat>[],
  String? copiedFeedbackText,
  String? copySemanticsLabel,
}) {
  Widget build(ZFieldWidgetContext ctx, ZMarkdownFieldMode mode) =>
      ZMarkdownField.fromContext(
        // Place stable (AD-2) : `State` persiste ⇒ QuillController jamais recréé.
        key: ValueKey<String>('z-markdown-${ctx.field.name}'),
        ctx: ctx,
        mode: mode,
        codec: codec,
        minLines: minLines,
        maxLines: maxLines,
        characterLimit: characterLimit,
        styleSet: styleSet,
        chrome: chrome,
        textScaleFactor: textScaleFactor,
        formulaSpec: formulaSpec,
        toolbarConfig: toolbarConfig,
        showLabel: showLabel,
        emptyIcon: emptyIcon,
        emptySubtitle: emptySubtitle,
        emptyBuilder: emptyBuilder,
        copyOnLongPress: copyOnLongPress,
        copyFormats: copyFormats,
        copiedFeedbackText: copiedFeedbackText,
        copySemanticsLabel: copySemanticsLabel,
      );

  registry.register(
    'inlineMarkdown',
    (context, ctx) => build(ctx, ZMarkdownFieldMode.inline),
  );
  registry.register(
    'markdown',
    (context, ctx) => build(ctx, ZMarkdownFieldMode.block),
  );
  registry.register(
    'richText',
    (context, ctx) => build(ctx, ZMarkdownFieldMode.block),
  );
}
