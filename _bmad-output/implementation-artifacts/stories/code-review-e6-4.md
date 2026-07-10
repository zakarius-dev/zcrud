# Code Review — E6-4 « Embed tableau » (`zcrud_markdown`)

- **Story** : `_bmad-output/implementation-artifacts/stories/e6-4-embed-tableau.md` (10 ACs)
- **Skill** : `bmad-code-review` (tool `Skill`, exécution nominale ; step-01 chargé)
- **Mode** : revue adversariale, lecture seule. Baseline `3dfcb4f`.
- **Vérifs rejouées par le reviewer** : `flutter analyze` (zcrud_markdown) → **0 issue** ; `flutter test` (z_table_embed + z_delta_codec + z_markdown_codec + quill_signature_isolation) → **92/92 PASS**. (Suite complète 155 tests confirmée verte par l'orchestrateur.)
- **Périmètre disque E6-4** : `lib/src/presentation/z_table_embed.dart` (NEW), `z_markdown_field.dart` (UPDATE), `test/z_table_embed_test.dart` (NEW), `test/fixtures/rich_corpus.dart`, `test/z_markdown_codec_test.dart`, `test/quill_signature_isolation_test.dart`, `test/z_latex_embed_test.dart` (helper). `pubspec.yaml` deps **inchangé**. `zcrud_core` **non touché**. (Les modifs `example/` du worktree proviennent d'une autre story — ex-2 list-demo — pas d'E6-4.)

## Verdict global

**PASS — aucun finding HIGH / MAJEUR / MEDIUM.** Story techniquement propre, miroir fidèle du patron E6-3 déjà revu. 5 LOW/nits consignés (optionnels). Story reste verte. Recommandation : passage `done`.

## Findings

| Sévérité | Fichier:ligne | Résumé |
|----------|---------------|--------|
| LOW-1 | `test/z_table_embed_test.dart:96` | Le rendu AC2 vérifie 4 textes de cellules + `findsOneWidget` Table, mais n'assère pas explicitement les **dimensions** (nb `TableRow` == 2, nb colonnes == 2). Dims inférées des 4 textes distincts — preuve suffisante mais indirecte. |
| LOW-2 | `test/z_table_embed_test.dart:594` | La couleur de **bordure du `Table`** issue du thème (`fieldBorderColor` → `outline`) n'est vérifiée par aucun test (seule la couleur du **placeholder** l'est, l.499-521). Zéro couleur en dur est vrai à la lecture du code (l.136-139), mais non prouvé par test. |
| LOW-3 | `test/z_table_embed_test.dart:260` | Le test d'**édition** (op remplacée) s'appuie sur `cells.first.first == 'Z'` : il garde implicitement contre une double-insertion (une insertion mettrait la table éditée en 2ᵉ position, `.first` resterait 'a' → échec), mais n'assère pas explicitement `count(table ops) == 1`. |
| LOW-4 | `z_table_embed.dart:130` | `_buildTable` utilise `IntrinsicColumnWidth` sans wrapper `overflow-x` : une table plus large que le viewport peut **déborder visuellement** (overflow paint, pas de throw). Borné en pratique par `_kMaxDim = 12` colonnes du dialogue. Cosmétique. Doc l.164 nomme le placeholder « INLINE » alors que `expanded == true` (bloc) — libellé trompeur. |
| LOW-5 (nit) | `lib/src/data/delta_neutral_ops.dart:139` | Le commentaire de `_embedPlaceholder` cite encore `z-table` (anticipation E6-2) plutôt que le type canonique `table`. La logique générique (1re clé) est correcte et le fichier est **volontairement non modifié** (périmètre E6-2) → rien à corriger dans E6-4. |

## Vérifications adversariales détaillées

### SM-1 / AD-2 non régressé (CRITIQUE) — OUI
- `_kEmbedBuilders = const <EmbedBuilder>[ZLatexEmbedBuilder(), ZTableEmbedBuilder()]` (z_markdown_field.dart:669) : **une seule** liste `const` top-level, les **2 embeds** dans la même liste canonicalisée (constructeurs `const`).
- Consommée par `config: const QuillEditorConfig(... embedBuilders: _kEmbedBuilders)` (l.436-447) → config **entièrement `const`** ⇒ même instance à chaque `build`. Le test AC8 prouve `identical(buildersAfter, buildersBefore)` **après 100 frappes**, `init==1`, controller `identical`, voisin figé (`buildB` inchangé), `globalBuilds` inchangé, focus + caret (`end+100`) préservés.
- 2ᵉ `customButton` « Tableau » ajouté au **même** `_toolbarConfig` `late final` construit **une fois** en `initState` (l.276-292) — pas de recréation par build.
- Chemin chaud `_onQuillChanged` (l.358-366) **INCHANGÉ** (aucun code table) ; les `EmbedBuilder` n'entrent jamais dans `document.changes`. MED-1 préservé.

### Défensif Table / jagged (AD-10) — OUI
- `_parseTable` (z_table_embed.dart:108-126) court-circuite AVANT tout `Table(...)` : `data` non-`Map` → null ; `cells` non-`List`/vide → null ; ligne non-`List` → null ; **jagged** (`row.length != width`) → null ; largeur 0 → null ; cellules **coercées** `cell?.toString() ?? ''`. La normalisation évite tout `IndexError`/assertion Flutter (lignes garanties de largeur égale). Matrice = source de vérité (`rows`/`columns` ignorés).
- Matrice de test réelle (l.318-389) : `{}` vide, `cells` absent, `cells` vide, `cells` non-List, lignes non-List, **jagged**, data `null`, data non-Map, cellules non-String (coercion), placeholder sous RTL → `takeException()` **null** dans tous les cas, éditeur montable, placeholder `error_outline` rendu. Aucun cas manquant identifié.

### Isolation (AD-1) — 0 dépendance — OUI
- `pubspec.yaml` deps **inchangé** (aucune arête ajoutée) ; rendu via widget `Table` du framework Flutter. Gate signature (quill_signature_isolation_test.dart:155-184) : `z_table_embed`/`ZTableEmbed`/`ZTableEmbedBuilder` **non exportés** par le barrel ; libs lourdes (`flutter_tex`, `html_editor_enhanced`, `pluto_grid`, `webview_flutter`, …) **absentes** du pubspec. Barrel (`lib/zcrud_markdown.dart`) inchangé. Valeur de tranche = op Delta neutre `{insert:{table:...}}` JSON-safe (`jsonDecode(jsonEncode(v)) == v` prouvé l.221).

### Cohérence E6-2/E6-3 (op opaque) — codec inchangé — OUI
- `DeltaNeutralOps`/`ZDeltaCodec`/`ZMarkdownCodec` **non modifiés** (fichiers hors périmètre E6-4). `_embedPlaceholder` capte `table` **génériquement** (1re clé) → `[embed:table]`, aucun cas spécial. `ZDeltaCodec` = identité (test corpus `table-type-embed` + `mixed-text+table`). Coexistence LaTeX : `_kEmbedBuilders` porte les 2 clés (`latex`+`table`), `_tableEmbedAtSelection` (`insert[table] is Map`) et `_latexEmbedAtSelection` (`insert[latex] is String`) discriminent sans interférence ; le comptage d'offset traite l'autre embed comme longueur 1.

### Round-trip + coexistence latex — OUI
- `ZDeltaCodec.decode(encode(ops)) == ops` (identité) sur `tableTypeEmbedOps` + `mixedTextAndTableEmbedOps` (structure imbriquée préservée). `ZMarkdownCodec` : texte « avant »/« apres » préservé, `[embed:table]` présent, embed **jamais ressuscité** (z_markdown_codec_test.dart:164-189). L'insertion réelle (AC3) prouve la survie de la matrice imbriquée à travers le **Document Quill** vivant (`encodeNeutral` → `cells == [[a,b],[c,d]]`).

### AD-13 (RTL / thème / a11y) — OUI
- Bordure/couleurs du `Table` et du placeholder issues de `ZcrudTheme` (repli `Theme`), zéro couleur en dur ; padding `EdgeInsetsDirectional`, `TextAlign.start`. Placeholder porte `Semantics(label: kTableInvalidLabel)`. Bouton toolbar présent, toolbar ≥ 48 dp, boutons dialogue OK/Annuler ≥ 48 dp (`ConstrainedBox`). Table rendu sous `rtl` + `ThemeData.dark()` sans exception. (Couleur du placeholder testée ; couleur de bordure Table non testée → LOW-2.)

### Insertion / édition — OUI
- Bouton toolbar → `_promptAndInsertTable` → `showZTableDialog` → `replaceText` insère l'op au caret (repli fin de doc si sélection invalide). Édition : `_tableEmbedAtSelection` détecte l'embed sous/juste-après le caret → dialogue pré-rempli → remplacement longueur 1. Annulation → aucune mutation. Rendu bloc (`expanded == true`). Contrôleurs de cellules créés/disposés dans le `State` du dialogue (anti-fuite), `_resize` réutilise/dispose correctement.

### Qualité des tests — OK
- Rendu `Table` réellement vérifié en **édition** (via le champ, `_kEmbedBuilders`) ET **readOnly** (QuillEditor dédié). Pas de tautologie majeure. Helper `_pressTableButton` désambiguïse les **2 boutons** custom par `tooltip` (voie de production réelle) ; helper LaTeX E6-3 idem mis à jour. Réserves mineures : LOW-1/LOW-2/LOW-3.

### Frontière E6-4 (clôt E6) — OUI
- Uniquement embeds LaTeX (E6-3) + table (E6-4). Aucune dépendance lourde. `zcrud_core` intact. Contenu riche de cellule / fusion / redimensionnement = hors périmètre (v1.x). Cellules = texte simple.

## Finding le plus grave

Aucun finding bloquant : le plus notable (LOW-2) est l'absence de test asserant que la **couleur de bordure du `Table`** provient du thème injecté — vérifié à la lecture du code mais non couvert par test.

---

## Décision orchestrateur (2026-07-10)

0 HIGH/MAJEUR/MEDIUM → **aucune remédiation requise**. Les 5 LOW sont **consignés/déférés** :
- LOW-1/2/3 (durcissement de tests : dims explicites, couleur bordure thème, count ops) → nits de robustesse de test.
- LOW-4 (`IntrinsicColumnWidth` sans overflow-x → débordement visuel >12 col, sans throw ; doc « inline » vs bloc) → **v1.x** (redimensionnement/scroll de cellule = rich-text avancé) ; correction du doc-comment mineure déférée.
- LOW-5 (commentaire E6-2 cite `z-table`) → aucun changement (fichier codec volontairement figé).

**Vérif verte rejouée (orchestrateur, ciblée zcrud_markdown)** : `flutter analyze` **0 issue** · `flutter test` **155/155** · aucune dép ajoutée (Table natif) · **CORE OUT=0**. Story E6-4 → **done**.
