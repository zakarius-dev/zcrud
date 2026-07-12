# MIN-1 — Gaps MINEURS rich-text de parité DODLP (`zcrud_markdown`)

**Mode** : dev-story ACCÉLÉRÉ, DEV DIRECT groupé (sans create-story).
**Statut** : review (vert).
**Périmètre** : satellite `zcrud_markdown` disjoint. Aucun fichier DODLP modifié
(lecture seule). Source des gaps : `docs/dodlp-edition-parity-gap.md` §2.1 (lignes
« minor »).

**Invariants respectés** : AD-1 (markdown→core, `CORE OUT=0`, graph acyclique),
AD-2/SM-1 (controller rich-text isolé, aperçu/menus hors chemin chaud), AD-7
(Delta interne, ZCodec pluggable, surface publique NEUTRE — aucun type Quill/math
exporté), AD-10 (LaTeX/tableau/embed corrompu → placeholder, jamais de throw),
AD-13 (a11y ≥48 dp, directionnel), FR-26 (zéro couleur codée en dur). Rétro-compat
stricte : DP-3/DP-4/DP-22 intacts, barrel additif, embed `latex` inchangé, champs
sans nouvelle config au comportement E6-1/DP-3 identique.

---

## Items LIVRÉS

### 1. LaTeX bloc (display centré) vs inline — LIVRÉ
- Nouvel embed ADDITIF `latexBlock` (`ZLatexBlockEmbed`, `MathStyle.display`,
  rendu centré `AlignmentDirectional.center`, `expanded=true`) à côté de l'embed
  `latex` inline INCHANGÉ (`MathStyle.text`). Ajouté à `kZEmbedBuilders` (édition
  + lecture). Rendu défensif partagé (`_buildMath`).
- **AC** : op `{insert:{latexBlock:src}}` → `Math` display ; builder `latexBlock`
  ET `latex` câblés ; malformé → placeholder, aucun throw ; embed `latex` legacy
  intact.
- Fichiers : `lib/src/presentation/z_latex_embed.dart`,
  `lib/src/presentation/z_rich_text_core.dart`.

### 2. Dialogue LaTeX enrichi (aperçu live + exemples + bascule) — LIVRÉ
- `showZLatexDialog` retourne désormais `ZLatexInput{source, block}`. Le dialogue
  porte : **aperçu live** (`Math.tex` défensif, `onErrorFallback`), **exemples**
  cliquables (`ActionChip`, pré-remplissent le champ), **bascule inline/bloc**
  (`SwitchListTile` clé `zlatex-block-toggle`). Un seul `TextField` (rétro-compat
  des tests E6-3).
- **Fallback SVG (2e moteur de rendu, flutter_tex/WebView) : DÉFÉRÉ** — l'aperçu
  utilise `flutter_math_fork` (dép existante), aucune dép WebView/réseau ajoutée.
- **AC** : bascule ON → `latexBlock` inséré ; OFF (défaut) → `latex` inline ; chip
  → champ pré-rempli + aperçu `Math` ; édition d'un `latexBlock` → bascule
  pré-cochée.

### 3. Éditeur de tableau enrichi — menus ligne/colonne — LIVRÉ
- `_ZTableDialog` : `PopupMenuButton` par LIGNE (`ztable-row-menu-$r` : insérer
  au-dessus/en-dessous, supprimer) et par COLONNE (`ztable-col-menu-$c` : insérer
  avant/après, supprimer), en plus des steppers de fin existants. Insertion/
  suppression ciblée avec préservation du texte des cellules conservées, dispose
  anti-fuite des contrôleurs, bornes `_kMinDim`/`_kMaxDim` respectées (item
  supprimer désactivé au minimum).
- **Rendu WYSIWYG complet de cellules (Quill par cellule, hover « double-clic ») :
  DÉFÉRÉ** — cellules texte brut (comme E6-4), priorité aux menus ligne/col.
- **AC** : menus présents ; insérer ligne → 3 lignes, texte préservé, vide en
  bonne position ; supprimer colonne → bonne colonne retirée ; suppression bloquée
  au minimum.
- Fichier : `lib/src/presentation/z_table_embed.dart`.

### 4. Souligné `<u>` préservé au round-trip Markdown — LIVRÉ
- `ZMarkdownCodec.encode` : `customTextAttrsHandlers` émet `<u>…</u>` pour
  l'attribut `underline`. `decode` : ré-absorbe les marqueurs `<u>…</u>` littéraux
  en attribut `underline` (machine à états défensive, préserve les autres
  attributs, court-circuit si aucun marqueur). Table des pertes mise à jour
  (souligné = **conservé**). `ZDeltaCodec` reste sans perte.
- **Limite documentée** : un `<u>`/`</u>` saisi LITTÉRALEMENT en texte serait
  interprété comme souligné (parité du sentinel DODLP) — cas marginal assumé.
- **AC** : encode contient `<u>world</u>` ; round-trip préserve `underline` ;
  décodage d'un `<u>` littéral → attribut ; souligné+gras combinés préservés ;
  texte sans souligné inchangé.
- Fichier : `lib/src/data/z_markdown_codec.dart`.

### 5. minLines/maxLines rich-text (hauteur bornée / compact) — LIVRÉ
- `ZMarkdownField.minLines/maxLines` (both ctors + registration). `maxLines` posé
  ⇒ éditeur `scrollable:true` + `ConstrainedBox(maxHeight = maxLines*lineHeight)` ;
  `minLines` ⇒ `minHeight`. Sans borne : comportement E6-1 (non-scrollable,
  intrinsèque) INCHANGÉ.
- **AC** : sans borne → `scrollable:false` ; `maxLines` → `scrollable:true` +
  hauteur plafonnée.

### 6. Limite de caractères — LIVRÉ (spellcheck DÉFÉRÉ)
- `ZMarkdownField.characterLimit` : compteur vivant `n / limite` (Semantics,
  couleur d'alerte thème au dépassement) + troncature SOUPLE best-effort
  (`_enforceCharacterLimit`, gardée contre la ré-entrance, défensive). Opt-in :
  sans limite, aucun compteur, chemin chaud intact.
- **spellcheck (toggle) : DÉFÉRÉ** — `flutter_quill` 11.5.1 n'expose AUCUN champ
  de spellcheck par éditeur dans `QuillEditorConfig` (le clavier plateforme gère
  la correction). Un toggle par champ nécessiterait une nouvelle dépendance/fork →
  hors scope MIN-1, seam non ajouté pour éviter une config morte.
- **AC** : compteur affiché ; frappe au-delà de la limite tronquée ; sans limite,
  aucun compteur.

### 7. Styles Quill thémés (H1-H6 dérivés du thème) — LIVRÉ (parité partielle)
- `zQuillThemedStyles(context)` : part de `DefaultStyles.getInstance` (déjà thémé)
  et surcharge H1..H6 en fusionnant les rôles `TextTheme` (headlineLarge…titleSmall)
  — couleurs/tailles/graisses du thème, **zéro couleur codée en dur** (FR-26).
  Appliqué en `customStyles` de l'éditeur, du lecteur et du plein-écran. Type Quill
  `DefaultStyles` INTERNE (jamais exporté).
- **Divergence AD-13/FR-26 assumée & documentée** : la parité DODLP
  (`QuillDefaultStylesHelper` + `google_fonts` + palette de couleurs FIGÉE) n'est
  PAS reproduite — pas de dép `google_fonts`, pas de couleur en dur. Seule la
  dérivation thème est portée.
- **AC** : éditeur ET lecteur exposent `customStyles` non-null (h1/h2 présents).

---

## Items MINOR §2.1 NON couverts (déférés, documentés)

| Gap §2.1 | Sévérité | Décision |
|---|---|---|
| Fallback SVG / 2e moteur de rendu LaTeX (flutter_tex) | minor | **Déféré** — dép WebView lourde ; aperçu via `flutter_math_fork` existant. |
| Rendu tableau WYSIWYG (Quill/cellule, hover double-clic) | minor | **Déféré** — cellules texte brut ; menus ligne/col livrés. |
| spellcheck (toggle) | minor | **Déféré** — non exposé par `flutter_quill` 11.x. |
| Styles google_fonts + palette couleurs figée | minor | **Hors parité assumée** (FR-26) — seule la dérivation thème est portée. |

> Gaps §2.1 **blocking/major** (lecture seule DP-3, html/inlineHtml, dialog
> plein-écran, toolbar granulaire, upload image/vidéo…) : hors périmètre MIN-1
> (déjà traités par DP-3/DP-22 ou d'autres lots).

---

## Vérif verte REJOUÉE (RC réels)

| Commande | RC |
|---|---|
| `dart analyze packages/zcrud_markdown` | **0** (No issues found) |
| `flutter test packages/zcrud_markdown` | **0** — **269 tests** (247 base + 22 MIN-1) |
| `python3 scripts/dev/graph_proof.py` | **0** — ACYCLIQUE OK, CORE OUT=0 OK (`markdown→core` seul) |
| `dart analyze packages/zcrud_mindmap packages/zcrud_flashcard` | **0** |
| `flutter test packages/zcrud_mindmap` (consommateur) | **0** — 110 tests |

> Pas de codegen : aucune annotation `@ZcrudModel`/`@JsonSerializable` touchée.

## Tests MIN-1 ajoutés (22)
- `test/min1_latex_block_dialog_test.dart` (6)
- `test/min1_table_menus_test.dart` (4)
- `test/min1_underline_roundtrip_test.dart` (6)
- `test/min1_field_options_test.dart` (6)
