/// Factory d'enregistrement des champs rich-text `zcrud_markdown` dans un
/// [ZWidgetRegistry] injecté (DP-3, AC6, AD-4).
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
import 'z_markdown_chrome.dart';
import 'z_markdown_field.dart';
import 'z_rich_text_style_set.dart';

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
/// [minLines]/[maxLines] (MIN-1) bornent la hauteur de l'éditeur inline
/// (mode compact) ; [characterLimit] (MIN-1) active un compteur + troncature
/// souple. [styleSet]/[chrome]/[textScaleFactor]/[formulaSpec] (GAP-5/6/7, CR
/// parité 2026-08-11) : défauts de REGISTRE partagés par tous les champs
/// rich-text du sous-arbre (styles « signature » de l'hôte, habillage carte,
/// échelle, formules). Tous OPTIONNELS : omis ⇒ comportement DP-3 INCHANGÉ.
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
