# DP-22 — Rich-text : embed image/vidéo neutres + `ZRichTextToolbarConfig` granulaire

> Gap parité DODLP **M20** (`docs/dodlp-edition-parity-gap.md` §2.1).
> Package cible : **`zcrud_markdown`** (satellite disjoint, arête sortante =
> `zcrud_core` uniquement — AD-1).
> Mode : **dev direct accéléré** (pas de `create-story` préalable).

## Contexte / périmètre

M20 regroupait trois manques rich-text vs DODLP :
1. **Embed image/vidéo** (avant : rendus par `unknownEmbedBuilder`) — **CE TICKET**.
2. **Toolbar configurable par field** (avant : seul `showToolbar: bool`) — **CE TICKET**.
3. Dialog plein-écran — **DÉJÀ livré en DP-3**, réutilisé, non refait.

`Delta ↔ HTML` (`ZHtmlCodec`) est **DÉJÀ livré en DP-4** — hors périmètre, non régressé.

Ce ticket ajoute donc, **sans dépendance réseau ni WYSIWYG/WebView nouvelle** :
- (a) des **embeds image/vidéo NEUTRES** (rendu défensif + placeholder) branchés
  sur un **seam de source** fourni par l'hôte (aucun upload/URL en dur dans le
  package) ;
- (b) une **config granulaire par bouton** `ZRichTextToolbarConfig` (présets
  `full`/`minimal`/`markdown`) consommée par `ZMarkdownField`.

## Décisions de conception

- Les embeds réutilisent les **types Delta STANDARD** `image` / `video`
  (`{"insert":{"image":<source>}}`) → interopérables avec un Delta produit par un
  autre éditeur Quill (parité DODLP).
- **Seam neutre** `ZMediaEmbedScope` / `ZMediaResolver` (`InheritedWidget`) : le
  package ne SAIT PAS charger une source ; l'hôte injecte son rendu réel
  (`Image.network`, cache, lecteur vidéo). Absent ⇒ placeholder thémé, **zéro
  réseau**. Le code réseau reste confiné à l'app (AD-1).
- Les embeds Quill-étendus (`ZImageEmbed`/`ZVideoEmbed`/`ZMediaEmbedBuilder`)
  restent **internes** à `lib/src/` (cf. latex/table) — **seuls** les symboles
  neutres (`ZMediaEmbedScope`, `ZMediaResolver`, `ZMediaRef`, `ZMediaKind`) sont
  exportés par le barrel. Aucun type Quill ne fuit (AD-1/AD-7).
- `ZRichTextToolbarConfig` = **donnée pure** (booléens `const`), traduite EN
  INTERNE (`z_rich_text_core.dart`) vers `QuillSimpleToolbarConfig` — jamais de
  type Quill dans sa surface publique.

## Acceptance criteria implémentés

- **AC1** — Embeds image/vidéo neutres (types Delta standard) rendus par des
  `EmbedBuilder`s ajoutés à `kZEmbedBuilders` **sans retirer** latex/table
  (édition ET lecture).
- **AC2** — Seam `ZMediaEmbedScope`/`ZMediaResolver` : resolver fourni ⇒ son
  widget est rendu ; il reçoit un `ZMediaRef{kind, source}` neutre (source opaque
  passée telle quelle).
- **AC3** — Rendu **défensif** (AD-10) : source absente / non-`String` / vide ⇒
  placeholder (le resolver n'est PAS appelé) ; resolver absent OU qui `throw` ⇒
  placeholder thémé, **JAMAIS** de throw.
- **AC4** — Insertion/édition via toolbar (boutons image & vidéo) → op Delta
  `{insert:{image|video:<source>}}` ; tranche **NEUTRE + JSON-safe** (AD-7) ;
  source blanche = annulation (aucun embed inséré).
- **AC5** — `ZRichTextToolbarConfig` : présets `full`/`minimal`/`markdown` +
  `copyWith` + `==`/`hashCode` ; granularité par bouton (natif + custom
  latex/table/image/vidéo).
- **AC6 — RÉTRO-COMPAT (NON-NÉGOCIABLE)** : `ZMarkdownField` **sans**
  `toolbarConfig` conserve exactement le comportement E6-1/DP-3 (préset `full` en
  voie `controller`/plein-écran, `minimal` en mode `inline`) ; `showToolbar`
  reste honoré (masque toute la barre) ; DP-3 (lecture seule / modes / dialog
  plein-écran) et DP-4 (`ZHtmlCodec`) intacts.
- **AC7** — a11y/thème (AD-13/FR-26) : label a11y sur placeholder, bordure/texte
  issus de `ZcrudTheme`/`Theme` (zéro couleur en dur), cibles ≥ 48 dp au
  dialogue, insets directionnels, RTL + thème sombre sans exception.
- **AC8 — Isolation (AD-1/AD-7)** : aucune dépendance WYSIWYG/WebView/réseau
  ajoutée au `pubspec` ; embeds Quill-étendus non exportés ; barrel n'importe/
  n'exporte aucun symbole `flutter_quill`.
- **AC9 — SM-1/AD-2** : `kZEmbedBuilders` `const` canonicalisé (aucune
  réallocation à la frappe) ; controller isolé non recréé ; embeds hors chemin
  chaud.

## Fichiers

### Modifiés
- `packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` — ajout du
  getter `_effectiveToolbarConfig` (résout la config effective : `full` pour
  `fullEditor`, `minimal` pour `inlineEditor`, ou la config fournie), câblage des
  callbacks `onInsertImage`/`onInsertVideo` + `toolbarConfig` optionnel.
- `packages/zcrud_markdown/lib/src/presentation/z_rich_text_core.dart` — embeds
  image/vidéo dans `kZEmbedBuilders`, `buildZToolbarConfig` piloté par
  `ZRichTextToolbarConfig`, `insertZMedia`.
- `packages/zcrud_markdown/lib/zcrud_markdown.dart` — exports additifs du seam
  média neutre + `ZRichTextToolbarConfig`.

### Créés
- `packages/zcrud_markdown/lib/src/presentation/z_media_embed.dart` — `ZMediaKind`,
  `ZMediaRef`, `ZMediaResolver`, `ZMediaEmbedScope`, `ZImageEmbed`/`ZVideoEmbed`,
  `ZMediaEmbedBuilder` (rendu défensif), `showZMediaSourceDialog`.
- `packages/zcrud_markdown/lib/src/presentation/z_rich_text_toolbar_config.dart` —
  `ZRichTextToolbarConfig` (présets + `copyWith` + égalité).
- `packages/zcrud_markdown/test/z_media_embed_test.dart` — rendu via seam,
  placeholder défensif, insertion toolbar, a11y/thème, stabilité embedBuilders.
- `packages/zcrud_markdown/test/z_rich_text_toolbar_config_test.dart` — présets,
  `copyWith`/égalité, rétro-compat `showToolbar` + granularité par field.

> Note : `z_media_embed.dart` / `z_rich_text_toolbar_config.dart` étaient présents
> à l'état incomplet (getter `_effectiveToolbarConfig` manquant ⇒ le package ne
> compilait pas). Ce ticket complète le câblage, ajoute les exports barrel et la
> couverture de tests.

## Vérif verte (rejouée réellement sur disque)

| Vérification | Commande | RC |
|---|---|---|
| Analyse package | `dart analyze packages/zcrud_markdown` | **0** — No issues found |
| Tests package | `flutter test` (`--concurrency=1`) | **0** — **247/247 passed** |
| Graphe AD-1 | `python3 scripts/dev/graph_proof.py` | **0** — ACYCLIQUE OK, CORE OUT=0 OK |
| Dépendants barrel | `dart analyze packages/zcrud_mindmap packages/zcrud_flashcard` | **0** — No issues found |

Aucun codegen requis (aucune annotation `@ZcrudModel` modifiée).
