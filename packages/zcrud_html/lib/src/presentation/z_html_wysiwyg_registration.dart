/// Factory d'enregistrement des champs **HTML WYSIWYG** `zcrud_html` dans un
/// [ZWidgetRegistry] injecté (fp-4-3, AD-50/AD-55/AR-5).
///
/// Enregistre les `kind` `html` (mode block) et `inlineHtml` (mode inline) sur
/// l'adaptateur WYSIWYG WebView de CE satellite (le cœur reste agnostique —
/// AD-1). Le format persisté est du **HTML `String`** (la voie WYSIWYG ne force
/// PAS de Delta — c'est sa raison d'être vs la voie Delta de `zcrud_markdown`).
///
/// ## Exclusivité `md` / `html` (AR-5) — prouvée par le CONTRAT CŒUR
/// `zcrud_markdown` enregistre DÉJÀ `html`/`inlineHtml` (voie Delta). Les deux
/// voies sont **mutuellement exclusives** : l'app en choisit UNE au bootstrap.
/// La collision est détectée par [ZWidgetRegistry.register] (**`throw`**
/// [ZDuplicateRegistrationError]) — JAMAIS par une dépendance de `zcrud_html`
/// vers `zcrud_markdown` (arête interdite AD-1). [registerZHtmlFields] porte
/// **le même nom** que son homonyme markdown (convention AD-55
/// `registerZ<Pkg>Fields`, pkg=html) : c'est VOULU — une app importe exactement
/// UN des deux barrels (jamais les deux ⇒ aucune ambiguïté d'import Dart).
///
/// **AD-40** : aucun type `html_editor_enhanced`/`flutter_html` n'apparaît en
/// signature — le builder route en interne sur [ZHtmlEditorField] (édition) ou
/// [ZHtmlView] (lecture), tous deux à API neutre.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_html_editor_field.dart';
import 'z_html_view.dart';

/// Enregistre les builders **HTML WYSIWYG** `zcrud_html` dans [registry].
///
/// Enregistre EXACTEMENT deux `kind` :
///
/// | `kind`       | mode   | rendu éditable        |
/// |--------------|--------|-----------------------|
/// | `inlineHtml` | inline | [ZHtmlEditorField] compact |
/// | `html`       | block  | [ZHtmlEditorField] pleine hauteur |
///
/// Chaque builder pose `key: ValueKey('z-html-<field.name>')` (place stable —
/// AD-2). `field.readOnly` est honoré : rendu **lecteur** [ZHtmlView] prioritaire
/// (patron « lecteur-prioritaire » de l'adaptateur markdown).
///
/// Une collision de `kind` (2ᵉ propriétaire — voie markdown OU double appel) fait
/// **`throw`** [ZDuplicateRegistrationError] (contrat [ZWidgetRegistry.register]).
void registerZHtmlFields(ZWidgetRegistry registry) {
  registry.register(
    'inlineHtml',
    (context, ctx) => _build(ctx, ZHtmlFieldMode.inline),
  );
  registry.register(
    'html',
    (context, ctx) => _build(ctx, ZHtmlFieldMode.block),
  );
}

/// Route sur le lecteur (`readOnly`) ou l'éditeur WYSIWYG, avec place stable.
Widget _build(ZFieldWidgetContext ctx, ZHtmlFieldMode mode) {
  final Key key = ValueKey<String>('z-html-${ctx.field.name}');
  final String label = ctx.field.label ?? ctx.field.name;
  if (ctx.field.readOnly) {
    // Lecteur prioritaire (AD-10 : valeur non-`String`/`null` ⇒ rendu vide ; un
    // HTML malformé `String` est rendu best-effort par ZHtmlView, jamais throw).
    return ZHtmlView(
      key: key,
      html: ctx.value is String ? ctx.value as String : null,
      label: label,
    );
  }
  return ZHtmlEditorField(key: key, ctx: ctx, mode: mode);
}
