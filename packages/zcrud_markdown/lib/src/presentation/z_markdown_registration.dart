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
import 'z_markdown_field.dart';

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
void registerZMarkdownFields(
  ZWidgetRegistry registry, {
  ZCodec? codec,
}) {
  registry.register(
    'inlineMarkdown',
    (context, ctx) => _build(ctx, ZMarkdownFieldMode.inline, codec),
  );
  registry.register(
    'markdown',
    (context, ctx) => _build(ctx, ZMarkdownFieldMode.block, codec),
  );
  registry.register(
    'richText',
    (context, ctx) => _build(ctx, ZMarkdownFieldMode.block, codec),
  );
}

Widget _build(
  ZFieldWidgetContext ctx,
  ZMarkdownFieldMode mode,
  ZCodec? codec,
) =>
    ZMarkdownField.fromContext(
      // Place stable (AD-2) : le `State` persiste ⇒ QuillController jamais recréé.
      key: ValueKey<String>('z-markdown-${ctx.field.name}'),
      ctx: ctx,
      mode: mode,
      codec: codec,
    );
