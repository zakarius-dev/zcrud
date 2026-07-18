/// `ZHtmlView` — rendu HTML **natif en lecture** (fp-4-3, FR-23/AD-10) via
/// `flutter_html`, widget PUR Flutter (montable en `flutter_test`, contrairement
/// à la WebView d'édition — cf. ET-5).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-10 (défensif)** : une entrée non-`String` / `null` ⇒ **rendu vide** ;
///   un HTML malformé (`String`) est rendu **best-effort** (`flutter_html` rend
///   les fragments) — JAMAIS de `throw`. Le format porté est **HTML `String`**.
/// - **AD-40 / NFR-2** : aucun type `flutter_html` n'apparaît en signature
///   publique ([ZHtmlView] ne prend qu'un `String?` + un `label`).
/// - **FR-26 / NFR-4** : couleur de texte dérivée du thème injecté
///   (`Theme.of(context)`), ZÉRO couleur codée en dur.
/// - **AD-13** : conteneur `Semantics` explicite ; directionnel (aucun
///   `EdgeInsets.only(left:/right:)`).
///
/// ## Pertes de round-trip BORNÉES (WYSIWYG HTML ⇄ rendu natif) — documentées
/// La voie WYSIWYG persiste du **HTML natif** (pas de Delta) ; le rendu
/// `flutter_html` ne couvre pas 1:1 tout le DOM Summernote. Pertes connues et
/// ACCEPTÉES (dégradation gracieuse, jamais de throw — AD-10) :
///
/// | Construction HTML source              | Rendu `flutter_html`            |
/// |---------------------------------------|---------------------------------|
/// | Code inline `<code>` / `<pre>`        | texte brut (pas de coloration)  |
/// | `<div>` / classes / CSS inline exotiques | best-effort, styles partiels |
/// | Embeds Summernote (widgets JS)        | ignorés (non rendus)            |
/// | LaTeX/MathJax (CDN runtime DODLP)     | HORS périmètre offline (AD-12) — |
/// |                                       | jamais réintroduit ici          |
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Affiche du HTML en LECTURE via `flutter_html`.
///
/// [html] est la valeur persistée (HTML `String`) — non-`String`/`null` ⇒ rendu
/// vide ; un HTML malformé (`String`) est rendu best-effort, jamais `throw`
/// (AD-10). [label] alimente le `Semantics` de conteneur.
class ZHtmlView extends StatelessWidget {
  /// Construit le rendu HTML en lecture. Aucun type tiers en signature (AD-40).
  const ZHtmlView({
    required this.html,
    this.label,
    super.key,
  });

  /// HTML persisté à rendre (`String`). `null` ⇒ rendu vide (défensif AD-10).
  final String? html;

  /// Libellé du champ, exposé au lecteur d'écran (`Semantics`). Optionnel.
  final String? label;

  /// Coerce défensivement toute entrée en `String` rendable (AD-10).
  static String _sanitize(Object? value) => value is String ? value : '';

  @override
  Widget build(BuildContext context) {
    final String data = _sanitize(html);
    // FR-26 : couleur de texte issue du thème injecté (repli `Theme.of`), zéro
    // couleur codée en dur ; le rendu `flutter_html` en hérite via `body`.
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      container: true,
      label: label,
      child: Html(
        data: data,
        style: <String, Style>{
          'body': Style(
            margin: Margins.zero,
            color: onSurface,
          ),
        },
      ),
    );
  }
}
