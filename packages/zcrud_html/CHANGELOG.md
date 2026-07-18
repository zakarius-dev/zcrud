# Changelog

All notable changes to `zcrud_html` are documented in this file.

## Unreleased (fp-4-3)

WYSIWYG HTML adapter (AD-50, epic E-FORM-PARITY).

- `registerZHtmlFields(registry)` enrolls the `html` (block) and `inlineHtml` (inline) kinds on an injected `ZWidgetRegistry`. Mutually exclusive with `zcrud_markdown` — the second owner of a kind throws `ZDuplicateRegistrationError` (core contract, no `zcrud_markdown` edge).
- `ZHtmlEditorField`: isolated-controller WYSIWYG editor (`html_editor_enhanced` WebView) — `late final HtmlEditorController` created once in `initState`, stable `ValueKey` place, debounced off-keystroke commit, out-of-focus re-sync (SM-1/AD-2). Persisted format is HTML `String`.
- `ZHtmlCommitDebouncer`: pure-Dart, injectable temporal mechanics (falsifiable SM-1 unit — the WebView `State` is not mountable in `flutter_test`).
- `ZHtmlView`: native HTML reader (`flutter_html`) — defensive (AD-10: corrupt/null/non-`String` renders empty, never throws), themed (FR-26), `Semantics` container.
- Heavy deps `html_editor_enhanced: ^2.7.1` + `flutter_html: ^3.0.0` added, confined to `lib/src/` (no third-party type in the public barrel, AD-40); confinement guard + R12 probe updated (probe intruder now `get`).
- Documented limits: WebView a11y (best-effort), bounded round-trip losses, no MathJax CDN.

## 0.2.1

Initial skeleton (fp-1-2, epic E-FORM-PARITY).

- HTML satellite substrate (AD-50): pubspec, barrel, `lib/src/{domain,data,presentation}` tree with documented placeholder, confinement guard.
- Depends only on `zcrud_core` among zcrud packages (AD-1, CORE OUT=0).
- No heavy dependency yet (`html_editor_enhanced`/`flutter_html` land confined in fp-4-3).
- Published under the MIT license.
