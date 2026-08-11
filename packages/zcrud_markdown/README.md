# zcrud_markdown

Édition et lecture Markdown riche pour zcrud, construites sur un éditeur Quill
isolé et un `ZCodec` pluggable — invariant [AD-7](../../docs/site/concepts/invariants.md#ad-7).

## Aperçu {#apercu}

`zcrud_markdown` est le paquet **satellite Flutter** qui porte la seule arête
vers `flutter_quill` du graphe de dépendances. L'éditeur (`ZMarkdownField`)
travaille toujours en **Delta interne** et n'expose sur la tranche du
`ZFormController` qu'une **valeur neutre** — une `List<Map<String, dynamic>>`
d'ops Delta JSON-safe, jamais un type Quill. Le format réellement **persisté**
(Delta JSON, Markdown, HTML) est choisi par l'application au travers d'un
`ZCodec` pluggable, appliqué à la couture de sérialisation, hors du chemin
chaud de frappe.

Ce paquet fournit :

- l'**éditeur** `ZMarkdownField` et le **lecteur** `ZMarkdownReader`, tous deux
  au controller Quill isolé (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2)) ;
- trois **codecs** prêts à l'emploi — `ZDeltaCodec` (identité, sans perte),
  `ZMarkdownCodec` (Markdown, round-trip borné et documenté) et `ZHtmlCodec`
  (HTML, round-trip borné) ;
- des **embeds riches** opt-in — formule LaTeX, tableau, image/vidéo, filet
  horizontal — rendus par des `EmbedBuilder` internes, jamais exposés en tant
  que types Quill ;
- l'**habillage** du champ (chrome carte, plein écran) et des **presets de
  toolbar** granulaires, pour composer une expérience d'édition sans
  reconstruire le moteur ;
- l'**enrôlement** dans le registre de widgets du cœur via
  `registerZMarkdownFields`/`registerZHtmlFields`.

**Utilisez ce paquet** pour un champ de formulaire ou une vue de lecture
rich-text (notes, descriptions, contenu structuré) qui doit rester
interopérable au format Markdown ou HTML. **N'utilisez pas ce paquet** si vous
avez seulement besoin d'un champ texte simple (`EditionFieldType.text` du
cœur suffit), ou si vous voulez un éditeur HTML **WYSIWYG** natif (WebView) :
c'est le rôle de `zcrud_html`, une voie exclusive de celle-ci.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Un champ est décrit une fois par un `ZFieldSpec` ; sa valeur vit dans une
/// tranche du controller de formulaire.
const bodyField = ZFieldSpec(
  name: 'body',
  type: EditionFieldType.markdown,
  label: 'Corps',
);

/// Champ rich-text scellé sur la tranche `body` du formulaire. La valeur
/// portée est un Delta JSON neutre, jamais un type Quill.
Widget buildBody(ZFormController controller) => ZMarkdownField(
      key: const ValueKey('body'),
      controller: controller,
      field: bodyField,
    );

/// Lecture seule du même contenu, hors formulaire.
Widget buildPreview(List<Map<String, dynamic>> ops) =>
    ZMarkdownReader(ops: ops);
```

## Concepts clés {#concepts-cles}

- **Delta interne, codec pluggable (invariant [AD-7](../../docs/site/concepts/invariants.md#ad-7))** —
  l'éditeur ne connaît qu'un seul format de travail (Delta) ; le format
  persisté est une décision de l'application, prise au niveau du modèle via
  `ZCodec.encode`/`decode`, jamais dans le widget.
- **Isolation Quill (invariants [AD-1](../../docs/site/concepts/invariants.md#ad-1)/[AD-8](../../docs/site/concepts/invariants.md#ad-8))** —
  aucun type `flutter_quill` (`QuillController`, `Document`, `Delta`) ne fuit
  par le barrel : un consommateur qui n'importe pas ce paquet ne tire aucune
  dépendance Quill.
- **Round-trip et pertes documentées** — `ZDeltaCodec` est sans perte ;
  `ZMarkdownCodec` et `ZHtmlCodec` sont bornés à leur sous-ensemble exprimable
  et documentent explicitement ce qu'ils ne peuvent pas réexprimer (attributs
  exotiques, certains embeds) — jamais une perte silencieuse ou totale.
- **Embeds opt-in, jamais destructeurs (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  une formule LaTeX ou un tableau non reconnu en aval dégrade en placeholder
  textuel localisé, sans jamais vider le document entier.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Champ et lecteur** | |
| `ZMarkdownField` / `ZMarkdownFieldMode` / `ZMarkdownFieldDebug` | Champ d'édition rich-text scellé sur une tranche, ses modes de présentation (`inline`/`block`) et son introspection de test. |
| `ZMarkdownReader` / `ZMarkdownReaderChrome` | Lecteur rich-text en lecture seule et son habillage. |
| `ZMarkdownRichTextRenderer` | Implémentation Markdown du port `ZRichTextRenderer` du cœur. |
| **Codecs** | |
| `ZCodec` | Abstraction pluggable de (dé)sérialisation Delta ↔ format persisté. |
| `ZDeltaCodec` | Codec identité — persisté = Delta JSON, round-trip sans perte. |
| `ZMarkdownCodec` | Codec Markdown — round-trip borné au sous-ensemble exprimable, pertes documentées. |
| `ZHtmlCodec` | Codec HTML — round-trip borné, préserve la couleur inline (contrairement à Markdown). |
| `ZMarkdownCodecScope` | Défaut de codec hérité pour un sous-arbre de champs. |
| **Ponts et embeds** | |
| `ZMarkdownEmbedBridge` / `ZMarkdownBridges` | Déclaration d'une syntaxe Markdown inline ↔ embed Delta (LaTeX prêt à l'emploi). |
| `zTableEmbedOp` / `kTableEmbedType` | Fabrique neutre (pur Dart) d'une op embed tableau, réutilisable hors Flutter. |
| `ZMediaEmbedScope` / `ZMediaResolver` / `ZMediaRef` / `ZMediaKind` | Résolution de source média (image/vidéo) injectable par l'hôte. |
| `ZTableCellScope` / `ZTableCellContent` | Mode d'interprétation opt-in du contenu d'une cellule de tableau. |
| **Habillage et présentation** | |
| `ZMarkdownFieldChrome` / `ZMarkdownChromeReference` | Habillage « carte » opt-in du champ (en-tête, bordure, action). |
| `ZRichTextStyleSet` / `ZRichTextSpacing` / `ZRichTextFormulaSpec` | Jeu de styles neutre injectable par champ. |
| `ZRichTextToolbarConfig` | Configuration granulaire par bouton de la barre d'outils, avec presets. |
| `ZRichTextFullscreenDialog` / `showZRichTextFullscreenDialog` | Dialog d'édition plein écran. |
| **Enrôlement** | |
| `registerZMarkdownFields` / `registerZHtmlFields` | Enregistrent les `kind` du champ dans un `ZWidgetRegistry` injecté. |

## Cas limites et invariants {#cas-limites}

- **Décodage toujours défensif (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  une valeur `null`, vide, corrompue ou d'un format legacy décode en document
  vide ou en ops vides, jamais en exception.
- **Aucun secret, aucune dépendance réseau (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  ce paquet ne contacte aucun service distant ; le rendu LaTeX est local
  (`flutter_math_fork`).
- **Thème injecté, zéro couleur codée en dur** — chrome, toolbar et styles par
  défaut dérivent du `Theme.of(context)` ambiant ; toute couleur legacy figée
  reste à la charge de l'application, injectée en paramètre.
- **Accessibilité et RTL (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  cibles tactiles ≥ 48 dp, `Semantics` explicites, variantes directionnelles
  partout dans le chrome et la toolbar.
- **`html`/`inlineHtml` sont exclusifs avec `zcrud_html`** — les deux paquets
  peuvent enregistrer les mêmes `kind` sur des voies différentes (Delta ici,
  WYSIWYG WebView côté `zcrud_html`) ; une application choisit une seule voie
  au démarrage, la collision d'enregistrement est détectée explicitement.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_markdown.md`](../../docs/site/paquets/zcrud_markdown.md)
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_html` — voie d'édition HTML WYSIWYG alternative, exclusive de ce paquet.
- `zcrud_note` — consommateur de ce paquet pour l'édition/lecture du corps d'une note.
- `zcrud_core` — `ZFormController`, `ZFieldSpec`, `ZWidgetRegistry`, `ZRichTextRenderer`.

## Licence {#licence}

MIT — voir la racine du dépôt.
