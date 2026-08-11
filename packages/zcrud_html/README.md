# zcrud_html

Champ HTML WYSIWYG pour zcrud — édition via une WebView à controller isolé,
lecture native, format persisté en `String` HTML.

## Aperçu {#apercu}

`zcrud_html` est le satellite **HTML WYSIWYG** de zcrud : une **2ᵉ voie**
rich-text, exclusive de celle de `zcrud_markdown`. Là où `zcrud_markdown`
édite en Delta interne avec un `ZCodec` pluggable, `zcrud_html` édite
**directement en HTML** via une WebView (`html_editor_enhanced`) et lit avec
un rendu HTML natif (`flutter_html`) — sans jamais passer par un document
Delta. C'est le choix pertinent quand le format persisté doit rester du HTML
`String` sans intermédiaire de conversion.

Ce paquet fournit :

- `ZHtmlEditorField` — le champ d'édition WYSIWYG, au controller WebView
  **isolé** (créé une seule fois, jamais recréé au rebuild) ;
- `ZHtmlView` — le rendu de lecture, natif et défensif ;
- `registerZHtmlFields` — l'enrôlement des `kind` `html`/`inlineHtml` dans un
  `ZWidgetRegistry` injecté.

**Utilisez ce paquet** quand votre application doit éditer du HTML `String`
en WYSIWYG (par exemple pour interopérer avec un système existant qui attend
du HTML). **N'utilisez pas ce paquet** si un round-trip Markdown ou Delta
suffit, ou si l'accessibilité fine de l'édition est prioritaire : préférez
alors `zcrud_markdown`, dont l'éditeur Quill est nativement accessible — la
WebView de ce paquet reste hors du contrôle `Semantics` du socle côté
édition.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_html/zcrud_html.dart';

/// Enregistre les `kind` `html` (mode bloc) et `inlineHtml` (mode inline)
/// dans le registre de widgets du cœur, une fois au bootstrap de l'app.
void bootstrap(ZWidgetRegistry registry) {
  registerZHtmlFields(registry);
}
```

Une fois enregistré, un `ZFieldSpec` de `kind: 'html'` (ou `'inlineHtml'`) est
rendu automatiquement par `ZHtmlEditorField` en édition et `ZHtmlView` en
lecture, au travers du dispatcher de champs du cœur — aucun câblage widget par
widget n'est nécessaire.

## Concepts clés {#concepts-cles}

- **Exclusivité avec `zcrud_markdown`** — les `kind` `html`/`inlineHtml` sont
  **mutuellement exclusifs** entre les deux paquets : une application choisit
  une seule voie au bootstrap. La collision est détectée par le contrat cœur
  `ZWidgetRegistry.register` (`throw`), jamais par une dépendance directe
  entre les deux paquets — interdite par l'invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1).
- **Controller isolé et commit débouncé (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  le `HtmlEditorController` est créé une seule fois ; toute la mécanique
  temporelle de débounce vit dans `ZHtmlCommitDebouncer`, une classe pur-Dart
  testable indépendamment de la WebView.
- **Isolation des dépendances lourdes (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1))** —
  `html_editor_enhanced` et `flutter_html` sont confinées à `lib/src/` :
  aucun de leurs types n'apparaît dans le barrel public.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZHtmlEditorField` | Champ d'édition HTML WYSIWYG à controller WebView isolé. |
| `ZHtmlView` | Rendu de lecture HTML natif, défensif sur un contenu malformé. |
| `registerZHtmlFields` | Enregistre les `kind` `html`/`inlineHtml` dans un `ZWidgetRegistry`. |

## Cas limites et invariants {#cas-limites}

- **Décodage défensif (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un contenu initial non-`String`/`null` rend un éditeur vide ; un HTML
  malformé se rend en best-effort, jamais un `throw`.
- **Re-sync guardée hors focus** — une valeur externe n'est réinjectée dans
  l'éditeur que si le champ n'a pas le focus, pour ne jamais écraser une
  saisie en cours.
- **Pertes de round-trip bornées** — code inline, `<div>`/CSS inline exotiques
  et embeds spécifiques à un éditeur tiers dégradent proprement plutôt que de
  faire échouer la conversion.
- **Accessibilité limitée côté édition** — la WebView embarque son propre DOM :
  les `Semantics` fines y échappent au contrôle du paquet. Le rendu de lecture
  `ZHtmlView`, lui, expose un `Semantics` de conteneur complet et hérite du
  thème ambiant.
- **Aucune dépendance réseau (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  ni CDN, ni endpoint en dur : un rendu de formule mathématique par CDN
  externe est hors périmètre offline de zcrud et n'est jamais réintroduit ici.
- **WebView non montable sous `flutter_test`** — la mécanique de débounce est
  prouvée par `ZHtmlCommitDebouncer` en isolation, pas par un test qui monte
  la WebView (indisponible en VM).

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_html.md`](../../docs/site/paquets/zcrud_html.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_markdown` — voie d'édition Delta/Markdown alternative, exclusive de ce paquet.
- `zcrud_core` — `ZWidgetRegistry`, `ZFieldSpec`, dispatcher de champs.

## Licence {#licence}

MIT — voir la racine du dépôt.
