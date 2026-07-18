# zcrud_html

Satellite **HTML WYSIWYG** de zcrud (AD-50) — édition HTML riche en WYSIWYG via
une WebView à **controller isolé** (`html_editor_enhanced`) + lecture native
(`flutter_html`). Le format persisté est du **HTML `String`** (pas de Delta —
c'est sa raison d'être vs la voie Delta de `zcrud_markdown`).

## Enrôlement

```dart
import 'package:zcrud_html/zcrud_html.dart';

registerZHtmlFields(registry); // enregistre les kinds `html` et `inlineHtml`
```

Le builder honore `field.readOnly` (rendu lecteur `ZHtmlView` prioritaire) et
pose une place stable `ValueKey('z-html-<field.name>')` (AD-2).

## Exclusivité `md` / `html`

Les `kind` `html`/`inlineHtml` sont **mutuellement exclusifs** avec ceux de
`zcrud_markdown` : une app choisit **une seule** voie au bootstrap. La collision
est détectée par le contrat cœur `ZWidgetRegistry.register` (**`throw`
`ZDuplicateRegistrationError`**) — jamais par une dépendance vers `zcrud_markdown`
(arête interdite, AD-1).

## Isolation & SM-1 (AD-50 / AD-2)

- **Controller unique** : `HtmlEditorController` créé une seule fois en
  `initState` (`late final`), jamais recréé au rebuild de tranche.
- **Commit débouncé hors-frappe** : toute la mécanique temporelle vit dans
  `ZHtmlCommitDebouncer` (pur Dart, testable au caractère) — une frappe ne pousse
  jamais de commit synchrone ; `onBlur` flushe le contenu final.
- **Re-sync hors focus** : une valeur externe (`ctx.value`) n'est ré-injectée
  (`setText`) que hors focus — jamais d'écrasement de la saisie.

## Dépendances

- `zcrud_core` (unique arête `zcrud_*` sortante — AD-1, CORE OUT=0)
- `html_editor_enhanced` (édition WYSIWYG) + `flutter_html` (lecture) — **confinées
  à `lib/src/`**, aucun de leurs types en signature publique (AD-40, gardé par
  `test/z_html_confinement_test.dart`).

## Limites connues (documentées)

- **A11y (AD-13) au mieux côté édition** : `html_editor_enhanced` embarque son
  propre DOM/Summernote (WebView) ; les `Semantics` fines y sont hors de notre
  contrôle. Le rendu lecture `ZHtmlView` reçoit un `Semantics` de conteneur et
  hérite du thème (`Theme.of`).
- **Pertes de round-trip bornées** (dégradation gracieuse, AD-10) : code inline
  (`<code>`/`<pre>`), `<div>`/CSS inline exotiques (best-effort), embeds
  Summernote (ignorés). Le **LaTeX/MathJax** DODLP s'appuie sur un **CDN runtime**
  — hors périmètre offline zcrud (AD-12), **jamais réintroduit** ici.
- **WebView non montable en `flutter_test`** (VM sans moteur WebView) : la
  mécanique SM-1 est prouvée par `ZHtmlCommitDebouncer` (extrait, falsifiable) +
  la conception (`late final` + `ValueKey`), jamais par un test tautologique.

Publié sous licence MIT.
