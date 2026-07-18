/// Barrel d'API publique de `zcrud_html` — satellite HTML WYSIWYG (fp-4-3, AD-50).
///
/// Fournit la **2ᵉ voie** rich-text HTML de zcrud : édition **WYSIWYG** via une
/// WebView à controller ISOLÉ (`html_editor_enhanced`) + lecture native
/// (`flutter_html`). Le format persisté est du **HTML `String`** (pas de Delta —
/// c'est sa raison d'être vs la voie Delta de `zcrud_markdown`).
///
/// **Enrôlement** : [registerZHtmlFields] enregistre les `kind` `html` et
/// `inlineHtml` sur un [ZWidgetRegistry] injecté. Ces `kind` sont **exclusifs**
/// avec ceux de `zcrud_markdown` — l'app en choisit UNE voie au bootstrap ; la
/// collision fait `throw` (contrat cœur `ZWidgetRegistry.register`).
///
/// **Isolation (AD-1/AD-40)** : les dépendances lourdes `html_editor_enhanced` /
/// `flutter_html` sont confinées à `lib/src/` ; AUCUN de leurs types n'apparaît
/// dans ce barrel (gardé par `test/z_html_confinement_test.dart`).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_html_view.dart' show ZHtmlView;
export 'src/presentation/z_html_wysiwyg_registration.dart'
    show registerZHtmlFields;
