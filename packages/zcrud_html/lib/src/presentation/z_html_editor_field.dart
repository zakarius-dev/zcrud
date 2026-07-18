/// `ZHtmlEditorField` — champ d'**édition HTML WYSIWYG** (fp-4-3, AD-50/AD-2/AD-7)
/// via la WebView `html_editor_enhanced`, à **controller ISOLÉ**.
///
/// La WebView est à HTML ce que le [flutter_quill].QuillController de
/// `zcrud_markdown` est au Delta : une **2ᵉ voie d'état** qui, mal isolée,
/// casserait SM-1. L'isolation est rendue FALSIFIABLE (cf. AD-50) par :
///
/// 1. **Controller unique** — `late final HtmlEditorController` créé UNE SEULE
///    fois en [initState], jamais recréé au rebuild de tranche ; la place stable
///    (`key: ValueKey('z-html-<field.name>')`, posée par l'enrôlement) fait
///    survivre le `State` aux rebuilds voisins (SM-1).
/// 2. **Commit débouncé hors-frappe** — toute la mécanique temporelle vit dans
///    [ZHtmlCommitDebouncer] (pur Dart, testable au caractère) : `onChangeContent`
///    ⇒ débounce ⇒ `ctx.onChanged` ; jamais synchrone à la frappe.
/// 3. **Re-sync hors focus** — [didUpdateWidget] ne ré-injecte `ctx.value`
///    (`setText`) que si le champ N'a PAS le focus (garde du débouncer).
///
/// **AD-10** : contenu initial non-`String`/`null` ⇒ éditeur VIDE ; un HTML
/// malformé (`String`) est chargé best-effort (Summernote), jamais de `throw`.
/// **AD-40** : le type `HtmlEditorController` reste PRIVÉ (le
/// constructeur public ne prend qu'un [ZFieldWidgetContext]).
///
/// ⚠️ **ET-5** : le `State` de cette WebView n'est PAS montable en VM
/// `flutter_test` (pas de moteur WebView) — sa mécanique SM-1 est prouvée par la
/// classe extraite [ZHtmlCommitDebouncer] + la conception (`late final` +
/// `ValueKey`), jamais par un test tautologique qui « monte » la WebView.
library;

import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_html_commit_debouncer.dart';

/// Mode de présentation de l'éditeur HTML (dérivé du `kind` par l'enrôlement).
enum ZHtmlFieldMode {
  /// Éditeur compact en place (`inlineHtml`).
  inline,

  /// Éditeur pleine hauteur (`html`).
  block,
}

/// Champ d'édition HTML WYSIWYG scellé sur la tranche `ctx.field.name`.
///
/// Consomme/produit une **valeur HTML neutre** (`String`) — aucun type
/// `html_editor_enhanced` en signature publique (AD-40).
class ZHtmlEditorField extends StatefulWidget {
  /// Construit le champ d'édition WYSIWYG pour [ctx]. [mode] fixe la hauteur.
  ///
  /// L'assembleur (enrôlement) DOIT poser `key: ValueKey('z-html-<name>')`
  /// (place stable — AD-2) : sans quoi un rebuild voisin pourrait recréer le
  /// controller ou voler l'état.
  const ZHtmlEditorField({
    required this.ctx,
    this.mode = ZHtmlFieldMode.block,
    super.key,
  });

  /// Contexte value-in-slice (`field`/`value`/`onChanged`).
  final ZFieldWidgetContext ctx;

  /// Mode de présentation (hauteur inline compacte vs block pleine).
  final ZHtmlFieldMode mode;

  @override
  State<ZHtmlEditorField> createState() => _ZHtmlEditorFieldState();
}

class _ZHtmlEditorFieldState extends State<ZHtmlEditorField> {
  /// Controller WebView **isolé** — créé UNE SEULE fois (AD-2). `late final` ⇒
  /// toute tentative de réassignation lèverait à l'exécution (garde du langage).
  late final HtmlEditorController _controller;

  /// Débouncer + garde de focus (mécanique SM-1 extraite, testable — ET-5).
  late final ZHtmlCommitDebouncer _debouncer;

  /// Coerce défensivement `ctx.value` en HTML `String` (AD-10 : non-`String`/
  /// `null` ⇒ vide ; un HTML malformé `String` passe verbatim, best-effort).
  String get _incoming {
    final Object? v = widget.ctx.value;
    return v is String ? v : '';
  }

  @override
  void initState() {
    super.initState();
    _controller = HtmlEditorController();
    _debouncer = ZHtmlCommitDebouncer(
      onCommit: (String html) => widget.ctx.onChanged(html),
    );
    // Amorce : le contenu initial est déjà « synchronisé » ⇒ pas de rebond.
    _debouncer.markSynced(_incoming);
  }

  @override
  void didUpdateWidget(covariant ZHtmlEditorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync guardée (AD-2) : une valeur EXTERNE n'écrase l'éditeur que HORS
    // focus (garde portée par le débouncer). Jamais pendant la saisie.
    final String incoming = _incoming;
    if (_debouncer.shouldAcceptExternal(incoming)) {
      _controller.setText(incoming);
      _debouncer.markSynced(incoming);
    }
  }

  @override
  void dispose() {
    // Non-perte : `dispose()` du débouncer FLUSHE d'abord l'éventuel commit
    // débouncé en attente (frappes <fenêtre, sans blur préalable), puis nettoie.
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double height =
        widget.mode == ZHtmlFieldMode.inline ? 220 : 400;
    final String label = widget.ctx.field.label ?? widget.ctx.field.name;
    return Semantics(
      // AD-13 : a11y AU MIEUX — la WebView Summernote porte son propre DOM ;
      // les `Semantics` fines y sont hors de notre contrôle (limite documentée
      // au README). On expose au moins un conteneur étiqueté.
      container: true,
      label: label,
      textField: true,
      child: HtmlEditor(
        controller: _controller,
        htmlEditorOptions: HtmlEditorOptions(
          hint: label,
          // AD-10 : contenu initial défensif — non-`String`/`null` ⇒ vide ; un
          // HTML malformé `String` est chargé best-effort (jamais de throw).
          initialText: _incoming.isEmpty ? null : _incoming,
        ),
        // FR-26 : couleurs dérivées du thème injecté (repli `Theme.of`).
        otherOptions: OtherOptions(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          height: height,
        ),
        callbacks: Callbacks(
          // Chemin CHAUD de frappe : jamais de commit synchrone — le débouncer
          // (pur Dart, testable) programme un commit différé (SM-1/AD-2).
          onChangeContent: (String? content) =>
              _debouncer.onContentChanged(content ?? ''),
          onFocus: () => _debouncer.onFocusChanged(hasFocus: true),
          // Blur ⇒ flush : le contenu final est poussé sans attendre la fenêtre.
          onBlur: () => _debouncer.onFocusChanged(hasFocus: false),
        ),
      ),
    );
  }
}
