# Étude de parité — famille RICH-TEXT / HTML / MARKDOWN / LATEX

> Extension de `STUDY.md` — DODLP → zcrud, migration sans régression visuelle.
> Périmètre : `EditionFieldTypes.markdown` / `inlineMarkdown` / `html` (module `data_crud`, formulaires CRUD).
> Repo DODLP : `/home/zakarius/DEV/dodlp-otr` (**lecture seule**). Repo zcrud : `/home/zakarius/DEV/zcrud`.
> Fichiers legacy `*.bak`/`*.bak2` **exclus** — seule la source vivante fait foi (`edition_screen.dart.bak2` notamment ignoré).

## 0. Hors périmètre écarté par grep (transparence)

`MarkdownEditorScreen` (`lib/modules/data_crud/presentation/views/markdown_editor_screen.dart`, avec `html_editor_enhanced` + `flutter_markdown_latex` + `gpt_markdown`) n'est **utilisé nulle part dans `data_crud`** — seulement par le module `assistant` (chatbot) :

```
grep -n "MarkdownEditorScreen(" lib/ -r | grep -v '\.bak'
→ lib/modules/assistant/presentation/views/screens/chatbot_conversation_screen.dart:234,953,1254
```
RC=0, 0 occurrence dans `data_crud/`. **Écarté** de cette étude (hors formulaire CRUD).

---

## 1. Vue d'ensemble — 3 `EditionFieldTypes` DODLP, 1 dispatcher

`lib/modules/data_crud/models.dart:44-85` (enum `EditionFieldTypes`) déclare 3 valeurs de la famille :

| Valeur DODLP | `EditionFieldType` zcrud | Dispatch DODLP (`edition_screen.dart`) |
|---|---|---|
| `markdown` | `richText` (mode bloc) — *voir §5 nuance nommage* | ligne 1282 |
| `inlineMarkdown` | `richText` (mode inline) | ligne 1283 (même `case`, `isInline: field.type == inlineMarkdown` ligne 1330) |
| `html` | `html` | ligne 3849 |

Le format **persisté réel** de `markdown`/`inlineMarkdown` DODLP est en fait du **JSON Delta Quill** (`jsonEncode(delta.toJson())`, `rich_text_editor_screen.dart:312`) malgré le nom du type — le libellé « markdown » est historique. `html` persiste une **`String` HTML**.

---

## 2. Champ `markdown` / `inlineMarkdown` (mode bloc + mode inline, Delta Quill)

### 2.1 Package DODLP + usage vivant

- **Éditeur riche** : `flutter_quill: ^11.5.1` (`pubspec.yaml:208`) — `QuillController`/`QuillEditor.basic`/`QuillSimpleToolbar`.
  - Dispatch : `edition_screen.dart:1282-1352` (case `markdown`/`inlineMarkdown`) → `MarkdownEditionField` (`.../rich_text_editor/editors/markdown_edition_field.dart`, 453 l.).
  - `MarkdownEditionField` gère 2 sous-modes :
    - **bloc** (`isInline: false`) : aperçu Markdown (`RichTextReaderScreen`) + bouton « Modifier »/« Rédiger » ouvrant `RichTextEditorScreen` en **dialog plein écran** (`markdown_edition_field.dart:230-247`, `showPushedDialog`).
    - **inline** (`isInline: true`) : `QuillController` + toolbar minimale directement dans la carte de champ (`markdown_edition_field.dart:416-448`, toolbar `RichTextToolbarConfig.minimal`), bouton « Valider » sauvegarde sans quitter (pas de dialog).
- **Toolbar complète** (mode bloc/dialog) : `QuillMarkdownEditorWrapper.toolBarBuilder` (`quill_markdown_editor_wrapper.dart:62-258`) — `QuillSimpleToolbar` avec dropdown H1-H6, gras/italique/souligné/barré/code inline/bloc de code/citation/listes num.+puces/checklist/indent/lien/undo-redo/clear format/copier-coller, **+ 2 boutons custom** : insertion formule LaTeX (icône `functions_rounded`) et insertion tableau (icône `table_chart_rounded`, sélecteur de grille visuel `_TableGridPickerDialog` 8×8).
- **Embeds Quill custom** (`quill_markdown_editor_wrapper.dart:451-470`) :
  - `FormulaEmbedBuilder`/`FormulaInlineEmbedBuilder` (`.../embeds/formula_embed.dart`) — rendu via **`flutter_math_fork: ^0.7.2`** (`Math.tex`, `MathStyle.display`/`.text`), avec **fallback SVG** `flutter_tex: ^5.1.10` (`TeX2SVG` + `SvgPicture.string`, `flutter_svg: ^2.0.9`) si `flutter_math_fork` échoue à parser (`formula_embed.dart:207-236`). Double-tap = édition (`FormulaEditDialog`). Préprocesseur LaTeX dédié (`_fixLineBreaks`/`_wrapInCasesIfNeeded`) pour corriger les sauts de ligne malformés.
  - `TableViewEmbedBuilder`/`TableEmbedBuilder` (`.../embeds/table_view_embed.dart`, `table_embed.dart`) — format **Markdown table string** (`EmbeddableTable` de `markdown_quill: ^4.3.0`), rendu via widget `Table` Flutter natif, tap = édition (`TableEditorScreen`, `table_editor_screen.dart`).
- **Lecture seule** : `RichTextReaderScreen` (`rich_text_editor_screen.dart:527-707`) — **bascule automatique** :
  - contenu = JSON Delta valide → `QuillEditor` readOnly complet (avec les mêmes embeds).
  - sinon → `Markdown` widget de **`flutter_markdown_plus: ^1.0.6`** (fork communautaire non-officiel de `flutter_markdown`, **PAS** `flutter_markdown` malgré la dépendance déclarée en pubspec:134 — celle-ci n'est utilisée que par le module `assistant`, cf. §0) + `formulasBuilders()` (LaTeX inline/bloc via `FormulaBlockElementBuilder`/`FormulaInlineElementBuilder`, réutilisant `flutter_math_fork`) + extension `flutter_markdown_latex: ^0.3.4` (syntaxe `LatexElementBuilder`, `formula_embed.dart:1089-1131`).
- **Conversion** : `DeltaToMarkdownHelper` (613 l.) / `MarkdownToDeltaHelper` (383 l.) — conversion bidirectionnelle Delta↔Markdown avec support LaTeX/tables custom, utilisée pour la persistance format `markdown` legacy et l'inter-op HTML (`vsc_quill_delta_to_html: ^1.0.5`, `flutter_quill_delta_from_html: ^1.5.3`).

### 2.2 Rendu visuel (ce qui casserait la parité)

- Carte de champ à en-tête dégradé (icône `article_rounded`, gradient bleu→violet `#667EEA→#764BA2`), bordure colorée si contenu non-vide, bouton d'action dégradé (« Rédiger »/« Modifier »/« Valider »).
- Mode inline : toolbar minimale **dans la carte** (pas de dialog), bouton plein-écran secondaire (icône `fullscreen`).
- Mode bloc : aperçu Markdown/Quill **tronqué en hauteur** (`kToolbarHeight * min(maxLines+1, 30)`), édition en **dialog plein écran** séparé.
- Formules LaTeX : rendu display centré (bloc) ou inline (texte), **avec filet de sécurité SVG** (MathJax-like) si le parseur natif échoue — jamais de crash visuel, dégradation progressive vers SVG.
- Tableaux : rendu `Table` Flutter natif, bordure bleue + bandeau « Cliquez pour modifier » quand éditable.
- Toolbar complète : 6 niveaux de titre, listes/checklist, indent, lien, historique undo/redo, 2 boutons custom (formule/tableau).

### 2.3 Couverture zcrud

**Natif `zcrud_markdown`** (satellite, PAS `zcrud_core` — conforme AD-1) :

```
find packages/zcrud_markdown/lib/src/presentation -name "*.dart"
→ z_html_registration.dart, z_latex_embed.dart(392l), z_markdown_codec_scope.dart,
  z_markdown_field.dart(777l), z_markdown_reader.dart(193l), z_markdown_registration.dart,
  z_media_embed.dart(349l), z_rich_text_core.dart(378l), z_rich_text_fullscreen_dialog.dart(287l),
  z_rich_text_toolbar_config.dart(312l), z_table_embed.dart(613l)
```
RC=0.

- **Éditeur** : `ZMarkdownField` (`z_markdown_field.dart`) enregistré sur les `kind` `markdown`/`inlineMarkdown` via `registerZMarkdownFields` (`z_markdown_registration.dart`) — modes bloc/inline, dialog plein écran (`z_rich_text_fullscreen_dialog.dart`) pour le bloc, toolbar (`z_rich_text_toolbar_config.dart`).
- **LaTeX** : `z_latex_embed.dart` — `ZLatexEmbed`(inline)/`ZLatexBlockEmbed`(bloc/display), rendu `flutter_math_fork` (`Math.tex`), **dialogue de saisie complet** avec aperçu live + exemples cliquables + bascule inline/bloc (`showZLatexDialog`, parité fonctionnelle avec `FormulaEditDialog` DODLP). Défensif AD-10 (placeholder erreur thémé `Semantics`).
- **Tableau** : `z_table_embed.dart` — `ZTableEmbed`, rendu `Table` Flutter **natif** (zéro dépendance ajoutée, comme DODLP), dialogue lignes/colonnes/cellules.
- **Média (image/vidéo)** : `z_media_embed.dart` — embeds `image`/`video` **avec les MÊMES clés Delta** que flutter_quill standard (`kImageEmbedType`/`kVideoEmbedType`), donc **interopérables** avec un Delta produit par DODLP.
- **Lecture seule** : `ZMarkdownReader` (`z_markdown_reader.dart`) — `QuillEditor` readOnly avec les mêmes embed builders.
- **Codecs pluggables (AD-7)** : `ZDeltaCodec` (round-trip sans perte), `ZMarkdownCodec` (`z_markdown_codec.dart`, via `markdown: ^7.2.2` + `markdown_quill: ^4.3.0` — **mêmes libs** que DODLP), `ZHtmlCodec` (voir §3).

**Écart identifié (natif présent mais dégradé)** :
- **Pas de fallback SVG `flutter_tex`** — `flutter_tex` est **explicitement banni** par un test d'isolation :
  ```
  packages/zcrud_markdown/test/quill_signature_isolation_test.dart:173: 'flutter_tex',
  ```
  RC=0 (liste des dépendances lourdes interdites au pubspec `zcrud_markdown`). Une formule LaTeX que `flutter_math_fork` ne sait pas parser (ex. `\ce{}`/`\pu{}` chimie, certaines macros exotiques) tombera sur un **placeholder d'erreur thémé** (icône `error_outline` + libellé a11y), **PAS** sur un rendu SVG serveur-side comme DODLP. C'est un écart visuel réel pour les formules complexes hors du sous-ensemble `flutter_math_fork`.
- **Format tableau différent** : DODLP persiste le tableau comme **Markdown string** (`EmbeddableTable` de `markdown_quill`) ; zcrud persiste une **structure `Map` neutre** (`rows`/`columns`/`cells`, `z_table_ops.dart`). Le **rendu** est équivalent (widget `Table` natif dans les deux cas), mais la **migration de données** d'un Delta DODLP existant contenant des embeds `table` (markdown) vers zcrud nécessite un **transformateur** (markdown-table-string → structure `rows/columns/cells`) — pas un simple passage direct.
- **Pas de bascule automatique vers un rendu Markdown léger** en lecture (perf) : DODLP `RichTextReaderScreen` bascule vers `flutter_markdown_plus` (plus léger) quand le contenu n'est pas du JSON Delta valide ; `ZMarkdownReader` zcrud instancie **toujours** un `QuillEditor` readOnly. Écart de perf potentiel sur listes avec beaucoup de rich-text court, pas un écart visuel bloquant.

**Verdict § markdown/inlineMarkdown** : **natif OK** pour l'essentiel (éditeur, toolbar, LaTeX inline/bloc, tableau, media, lecture) — écarts mineurs documentés (fallback SVG absent par choix d'architecture délibéré, format tableau à transformer en migration).

---

## 3. Champ `html` (édition + lecture, `String` HTML)

### 3.1 Package DODLP + usage vivant

- **Édition** : `HtmlEditorScreen` (classe `@Deprecated` héritant de `RichTextEditorScreen` avec `type: RichTextEditorType.html`, `rich_text_editor_screen.dart:713-723`) — dispatch `edition_screen.dart:3849-3971` :
  - Web : `showDialog` (`edition_screen.dart:3864-3872`).
  - Mobile/desktop : `Navigator.push` plein écran (`edition_screen.dart:3874-3882`).
  - Widget réel : `HtmlEditorWrapper` (`.../editors/html_editor_wrapper.dart`, 370 l.) enveloppant **`html_editor_enhanced: ^2.7.1`** — éditeur **WYSIWYG WebView** (moteur Summernote.js embarqué) : `html_editor.HtmlEditor` + `html_editor.ToolbarWidget` (`ToolbarType.nativeExpandable`, boutons style/font/liste/insertion/autres) + **2 boutons custom** (insertion tableau via `TableEditDialog` → markdown→HTML, insertion LaTeX via `FormulaEditDialog` → wrap `$$...$$` injecté en HTML brut) + upload image (`file_picker`).
  - **LaTeX dans l'éditeur HTML** : rendu côté **WebView via MathJax 3 chargé dynamiquement** (`webInitialScripts` injectant un `<script>` CDN `mathjax@3/es5/tex-svg.js`, config `inlineMath`/`displayMath`, `html_editor_wrapper.dart:239-257`) — **PAS** `flutter_math_fork` ici (celui-ci ne s'applique qu'à l'éditeur Quill/markdown). Le HTML éditeur dépend donc d'un **CDN externe en runtime** pour le rendu LaTeX pendant l'édition.
  - CSS injecté custom (thème clair/sombre, typographies Inter/Poppins/Fira Code) directement dans le `<head>` du document HTML édité.
- **Lecture seule** :
  - Contenu court (< 100 caractères) OU champ `readOnly` global : `Html(data: fieldValue)` de **`flutter_html: ^3.0.0`** — rendu HTML natif Flutter (pas de WebView), 3 sites d'usage vivants dans `data_crud` :
    ```
    grep -rn "Html(data:" lib/modules/data_crud/
    → edition_screen.dart:3855,3907,3942 ; dynamic_list_screen.dart:964 ; streamed_dynamic_list_screen.dart:908
    ```
    RC=0. (Utilisé aussi en **rendu de cellule de liste**, hors périmètre form/édition strict mais même famille.)
  - Contenu ≥ 100 caractères non-readOnly : `TextFormField` tronqué avec `onTap` rouvrant l'éditeur (`edition_screen.dart:3928-3971`).
- **Conversion round-trip** : `HtmlToDelta` (`flutter_quill_delta_from_html: ^1.5.3`) + `QuillDeltaToHtmlConverter` (`vsc_quill_delta_to_html: ^1.0.5`) — utilisées pour convertir HTML↔Markdown au besoin (`_onSave`, `rich_text_editor_screen.dart:291-303`), mais l'éditeur HTML lui-même **édite du HTML brut**, pas un Delta.

### 3.2 Rendu visuel (ce qui casserait la parité)

- **Éditeur = chrome navigateur intégré (WebView)** : barre d'outils Summernote (styles étendus : couleurs de police, tailles, alignement, exposant/indice non exposés ici mais dispo dans le lib), rendu **pixel-exact** du HTML final pendant l'édition (WYSIWYG réel, pas d'approximation Delta), support de balises HTML arbitraires (`<div>`, `<span style="">`, classes CSS custom).
- **Rendu LaTeX en édition** via MathJax (SVG serveur-JS dans la WebView), **dépendance réseau CDN** (`cdn.jsdelivr.net`) — un problème réseau dégrade silencieusement l'affichage des formules pendant l'édition (pas de fallback local documenté ici).
- **Lecture** via `flutter_html` : rendu natif Flutter de balises HTML standard (tables, listes, styles inline, liens) — pas de WebView, mais supporte plus de constructions HTML brutes que ce qu'un Delta Quill peut re-exprimer (cf. §3.3).

### 3.3 Couverture zcrud

**Satellite `zcrud_markdown`**, `kind` `html`/`inlineHtml` enregistrés par `registerZHtmlFields` (`z_html_registration.dart`) → **même adaptateur `ZMarkdownField`/`ZMarkdownReader`** que markdown, paramétré par `ZHtmlCodec` (`z_html_codec.dart`, 126 l.) au lieu de `ZDeltaCodec`. **PAS un widget dédié** : le champ `html` DODLP est réinterprété comme **« format de persistance HTML au-dessus d'un contenu Delta »**, décision de conception documentée en tête de fichier (`z_html_registration.dart:1-20`).

**ABSENT — preuve par grep négatif** :

```bash
# 1. AUCUN éditeur WYSIWYG WebView natif dans zcrud
grep -rln "html_editor_enhanced\|webview_flutter" packages/zcrud_markdown/
→ (aucune sortie) RC=1

# 2. flutter_html (rendu HTML natif façon DODLP) absent de zcrud_markdown
grep -rln "flutter_html" packages/zcrud_markdown/
→ (aucune sortie) RC=1

# 3. Confirmé bannis explicitement par test d'isolation (pubspec zcrud_markdown)
grep -n "html_editor_enhanced\|webview_flutter" packages/zcrud_markdown/test/quill_signature_isolation_test.dart
→ 173:        'flutter_tex',
  177:        'webview_flutter',
  (html_editor_enhanced listé ligne 173 bloc précédent — cf. §2.3)
RC=0
```

Cette absence est **une décision d'architecture délibérée et documentée**, pas un oubli :

```
_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md:171
→ "flutter_tex, html_editor_enhanced, google_maps_flutter, flutter_osm_plugin sont des
   dépendances optionnelles confinées à leurs packages" [en fait : NON intégrées du tout
   pour html_editor_enhanced — le pubspec zcrud_markdown ne les déclare pas]
```
Et explicitement dans le code (`z_html_registration.dart:13-14`, `z_html_codec.dart:27`) :
> « Aucun WYSIWYG HTML natif (`html_editor_enhanced`/WebView) : l'édition passe par l'éditeur Delta isolé de DP-3 » … « Un futur besoin WYSIWYG HTML natif resterait un **satellite distinct** (`zcrud_html`), hors périmètre. »

**Conséquence fonctionnelle documentée dans `ZHtmlCodec`** (table des pertes, `z_html_codec.dart:43-61`) : le round-trip HTML↔Delta est **borné**, PRÉSERVE paragraphes/titres H1-H6/gras/italique/souligné/barré/couleur/listes/liens/blocs de code/blockquote, mais **PERD** :
- `code` inline (le texte survit, l'attribut de style disparaît) ;
- tout embed LaTeX/tableau HTML non standard → dégradé en placeholder textuel `[embed:latex]`/`[embed:table]` (perte **bornée**, jamais de crash) ;
- attributs/styles HTML exotiques hors sous-ensemble (`<div class="">`, CSS custom, structures Summernote spécifiques).

**Verdict § html** : **GAP réel et assumé**. Le widget d'édition WYSIWYG-WebView (`html_editor_enhanced`) et le rendu HTML natif (`flutter_html`) sont **ABSENTS** de zcrud par choix d'architecture (isolation AD-1, cohérence AD-2/SM-1 avec l'éditeur Delta unique). La stratégie zcrud n'est **pas** d'adopter ces packages mais de **réinterpréter le champ `html` comme un format de persistance** au-dessus de l'éditeur Delta commun. Cela suffit pour un contenu HTML **simple/structuré** (le sous-ensemble commun), mais **casse la parité visuelle** pour :
1. tout enregistrement DODLP existant contenant du HTML riche hors du sous-ensemble Delta (styles inline CSS, `<div>` de mise en page, classes) → migration avec perte contrôlée mais réelle ;
2. l'expérience d'édition elle-même (WYSIWYG pixel-exact avec chrome navigateur vs. éditeur Quill/Delta stylé).

---

## 4. Stratégie de package (synthèse par format)

| Format | Stratégie | Justification |
|---|---|---|
| **Delta Quill** (`markdown`/`inlineMarkdown`) | **Natif zcrud_markdown suffit** — aucune adoption de package DODLP nécessaire | Même stack `flutter_quill` des deux côtés ; LaTeX (`flutter_math_fork`) et tableau (widget `Table` natif) déjà couverts avec dialogue de saisie équivalent |
| **LaTeX fallback SVG** (`flutter_tex`) | **Ne pas adopter** — accepter le gap | `flutter_tex` est bannie par un test d'isolation explicite (dépendance lourde/WebView potentielle selon plateforme) ; formule non-parsable par `flutter_math_fork` = cas rare, dégradation propre (placeholder), pas de crash. Risque d'adoption : réintroduit une dépendance non maîtrisée, viole AD-1 si mal isolée |
| **Tableau markdown-string** (`markdown_quill.EmbeddableTable`) | **Écrire un transformateur de migration** (pas un widget) | Le rendu final est équivalent (`Table` natif) ; seul le **format de la valeur Delta persistée** diffère (string markdown vs `Map` structuré) — un script de migration de données, pas un `ZFieldWidgetBuilder` |
| **HTML WYSIWYG** (`html_editor_enhanced`) | **NE PAS adopter dans zcrud_markdown** ; si besoin réel, **nouveau satellite `zcrud_html` dédié** (porte de sortie déjà documentée) | Architecture zcrud a explicitement banni les dépendances WebView/WYSIWYG lourdes du satellite rich-text (AD-1 isolation, cohérence SM-1/AD-2 : un seul chemin de frappe Delta). Adopter `html_editor_enhanced` dans `zcrud_markdown` casserait ce test d'isolation et introduirait une 2ᵉ voie d'édition (Delta ET DOM HTML natif) — risque de divergence d'état, incompatible avec le contrat `ZFormController`/`ValueListenable` par champ (AD-2) puisque `html_editor_enhanced` gère son propre état interne WebView hors du contrôleur Flutter |
| **Rendu HTML natif** (`flutter_html`) | **Écarté** — le rendu passe par `ZHtmlCodec` → Delta → `ZMarkdownReader` | Cohérent avec la décision ci-dessus ; couvre le sous-ensemble commun. Si un besoin de rendu HTML brut arbitraire (au-delà du Delta) apparaît en migration, il relève du même satellite `zcrud_html` hors périmètre actuel |

**Risques si on adoptait quand même `html_editor_enhanced`/`flutter_html` dans un satellite** :
- **Licence** : `html_editor_enhanced` (BSD-3, OK), `flutter_html` (MIT, OK) — pas de blocage licence en soi.
- **Maintenance** : `html_editor_enhanced` embarque une WebView + JS (Summernote) — surface de bugs plateforme (iOS/Android/Web) beaucoup plus large que `flutter_quill` pur-Dart ; `flutter_math_fork` a déjà eu ce risque documenté ailleurs dans le repo (`.memlog.md:13` : « dormant 14 mois »/« plan B: flutter_tex »).
- **Migration de données** : un satellite `zcrud_html` créerait un **second format canonique** (DOM HTML natif) parallèle au Delta neutre de `zcrud_core`/`ZFormController` — violerait la « valeur neutre unique par tranche » (AD-2/AD-7) sauf à le traiter, comme `ZHtmlCodec` actuellement, en pur format de persistance au-dessus du Delta (auquel cas on retombe sur le round-trip borné déjà en place, sans gain réel par rapport à l'existant).

---

## 5. Nuance de nommage `EditionFieldType` zcrud

`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart:129-142` déclare **3 valeurs distinctes** côté zcrud : `markdown`, `inlineMarkdown`, `html`, **ET** `richText` — cette dernière commentée « Texte riche (Delta interne) — widget en zcrud_markdown (E6) ». La correspondance effective observée dans le code (`z_markdown_registration.dart`/`z_html_registration.dart`) est que `markdown`/`inlineMarkdown`/`html`/`inlineHtml` sont tous servis par le **même** `ZMarkdownField`, différenciés par le **codec** (`ZDeltaCodec` vs `ZMarkdownCodec` vs `ZHtmlCodec`) — `richText` n'a pas été vérifié comme un 4ᵉ kind distinct dans ce passage (à confirmer si une story ultérieure le mobilise explicitement).

---

## Retour compact

Rapport : `/home/zakarius/DEV/zcrud/docs/dodlp-form-integration-study-2026-07-17/10-field-richtext-html-markdown.md`

- **`markdown`/`inlineMarkdown` (Delta Quill, bloc+inline)** → `flutter_quill ^11.5.1` + `flutter_math_fork` + `markdown_quill` (`edition_screen.dart:1282`, `markdown_edition_field.dart`, `quill_markdown_editor_wrapper.dart`) → zcrud **natif** (`zcrud_markdown`: `ZMarkdownField`/`z_latex_embed.dart`/`z_table_embed.dart`/`z_media_embed.dart`/`z_markdown_reader.dart`) → **verdict : natif OK**, gaps mineurs (pas de fallback SVG `flutter_tex` — banni explicitement ; format tableau à transformer en migration : markdown-string → `Map` structuré).
- **LaTeX fallback SVG** (`flutter_tex`+MathJax-like, `formula_embed.dart:207-236`) → **ABSENT** de zcrud (`grep flutter_tex packages/zcrud_markdown` RC=1, banni par `quill_signature_isolation_test.dart:173`) → **verdict : gap assumé**, ne pas adopter (dépendance lourde/WebView).
- **`html` — édition WYSIWYG** (`html_editor_enhanced ^2.7.1` + WebView Summernote + MathJax CDN, `edition_screen.dart:3849`, `html_editor_wrapper.dart`) → **ABSENT** de zcrud (`grep html_editor_enhanced packages/zcrud_markdown` RC=1, banni explicitement `z_html_registration.dart:13`, architecture.md:171) → **verdict : gap assumé par décision d'architecture** — réinterprété comme format de persistance (`ZHtmlCodec`) au-dessus du même éditeur Delta, PAS un widget dédié adopté.
- **`html` — lecture** (`flutter_html ^3.0.0`, `Html(data:)`, `edition_screen.dart:3855/3907/3942` + listes) → **ABSENT** de zcrud (`grep flutter_html packages/zcrud_markdown` RC=1) → **verdict : gap assumé**, rendu via `ZMarkdownReader`(Quill) après décodage `ZHtmlCodec` — round-trip **borné avec pertes documentées** (`z_html_codec.dart:43-61` : code inline, embeds non-standard, styles CSS exotiques).
- **Risque migration principal** : enregistrements DODLP `html` avec HTML riche (styles inline, `<div>`, classes) hors sous-ensemble Delta → dégradation à la migration (documentée, non silencieuse) ; embeds tableau markdown-string DODLP → nécessitent transformateur vers structure `Map` zcrud.
- **Aucun risque de fork/licence** identifié pour les packages déjà partagés (`flutter_quill`, `markdown`, `markdown_quill`, `vsc_quill_delta_to_html`, `flutter_quill_delta_from_html`, `flutter_math_fork` — mêmes versions/libs des deux côtés).
