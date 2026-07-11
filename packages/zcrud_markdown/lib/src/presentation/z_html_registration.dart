/// Factory d'enregistrement des champs **HTML** `zcrud_markdown` dans un
/// [ZWidgetRegistry] injecté (DP-4 / gap B5, AC2, AD-4).
///
/// Enregistre les `kind` `html` (mode `block`) et `inlineHtml` (mode `inline`)
/// sur le MÊME adaptateur `ctx`-natif ([ZMarkdownField.fromContext]) que
/// markdown (DP-3), paramétré par le mode + un [ZCodec] (défaut [ZHtmlCodec]).
/// Le widget réel est fourni par CE package satellite (le cœur reste agnostique
/// — AD-1) ; le registre est INSTANCIABLE et injecté via
/// `ZcrudScope.widgetRegistry` — jamais un singleton statique mutable.
///
/// Le format persisté est donc du **HTML** (`String`), converti vers/depuis le
/// Delta interne à la COUTURE DE PERSISTANCE (hors chemin chaud de frappe —
/// SM-1/AD-2). Aucun WYSIWYG HTML natif (`html_editor_enhanced`/WebView) :
/// l'édition passe par l'éditeur Delta isolé de DP-3, thémé (FR-26).
///
/// Une collision de `kind` fait **`throw`** (contrat `ZWidgetRegistry.register`).
///
/// > Porte de sortie : un futur besoin WYSIWYG HTML natif serait un satellite
/// > `zcrud_html` DISTINCT enregistrant son propre builder sur ces mêmes kinds —
/// > hors périmètre DP-4 (parité de MIGRATION, pas copie du chrome WebView).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_html_codec.dart';
import '../domain/z_codec.dart';
import 'z_markdown_field.dart';

/// Enregistre les builders **HTML** `zcrud_markdown` dans [registry].
///
/// [codec] optionnel : format persisté des champs HTML (défaut [ZHtmlCodec]).
/// Une app peut injecter un autre [ZCodec] (ex. `ZDeltaCodec` pour du Delta pur)
/// SANS changer le widget. Chaque builder construit un
/// [ZMarkdownField.fromContext] avec `key: ValueKey('z-html-<field.name>')`
/// (place stable — AD-2) et le [ZMarkdownFieldMode] dérivé du `kind` :
///
/// | `kind`       | mode    |
/// |--------------|---------|
/// | `inlineHtml` | inline  |
/// | `html`       | block   |
///
/// `field.readOnly` est honoré par l'adaptateur (rendu lecteur, prioritaire).
void registerZHtmlFields(
  ZWidgetRegistry registry, {
  ZCodec? codec,
}) {
  final ZCodec effective = codec ?? const ZHtmlCodec();
  registry.register(
    'inlineHtml',
    (context, ctx) => _build(ctx, ZMarkdownFieldMode.inline, effective),
  );
  registry.register(
    'html',
    (context, ctx) => _build(ctx, ZMarkdownFieldMode.block, effective),
  );
}

Widget _build(
  ZFieldWidgetContext ctx,
  ZMarkdownFieldMode mode,
  ZCodec codec,
) =>
    ZMarkdownField.fromContext(
      // Place stable (AD-2) : le `State` persiste ⇒ QuillController jamais recréé.
      key: ValueKey<String>('z-html-${ctx.field.name}'),
      ctx: ctx,
      mode: mode,
      codec: codec,
    );
