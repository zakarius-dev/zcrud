# Code Review adversariale — Groupe B (7 stories majeures)

Stories : **DP-15, DP-17, DP-18, DP-19, DP-20, DP-21, DP-22** (toutes en `review`).
Mode : skill réel `bmad-code-review` (step-file architecture, diff = working tree `git diff HEAD` + untracked). Baseline commit : `a64e3b3`.
Date : 2026-07-11.

## Verdicts par story

| Story | Périmètre | Verdict |
|-------|-----------|---------|
| DP-15 | M8+M22 select modal/multi/CRUD + choicesFromKey + seams ZChoicesSource/ZRelationCrudHandler (zcrud_core) | **APPROVED** |
| DP-17 | M14+M17 number devise/% + color picker/seam (zcrud_core) | **APPROVED** |
| DP-18 | M15 ZSignatureCodec strokes↔PNG (zcrud_core) | **APPROVED** |
| DP-19 | M18+M19 subitems soft-delete/templates + dynamicItem gabarits (zcrud_core) | **APPROVED** |
| DP-20 | M9 validateur téléphone national (zcrud_intl) | **APPROVED** |
| DP-21 | M13 geo formes/polyline/style/metadata (zcrud_geo) | **APPROVED** |
| DP-22 | M20 markdown embed image/vidéo + toolbar config (zcrud_markdown) | **APPROVED** |

Aucun finding HIGH/MAJEUR ni MEDIUM bloquant. Findings LOW/informationnels ci-dessous.

## RC réels (rejoués sur disque)

- `dart analyze packages/zcrud_core packages/zcrud_intl packages/zcrud_geo packages/zcrud_markdown` → **RC=0** (« No issues found! »).
- `flutter test packages/zcrud_core` → **All tests passed (857)**.
- `flutter test packages/zcrud_intl` → **Some tests failed (-3)** — **3 échecs PRÉ-EXISTANTS** (asset-catalog : `z_country_catalog_test.dart:165`, `z_subdivision_catalog_test.dart:142`, `z_currency_catalog_test.dart`), tous « Actual: <0> » = **assets bundlés non chargés dans le sandbox `flutter test`**. **Confirmés RED au baseline `a64e3b3`** (via `git stash` du package intl) → **régression NON introduite par DP-20**. Les tests propres de DP-20 (`z_national_phone_validator_test.dart`) **passent (19/19)**.
- `flutter test packages/zcrud_geo` → **All tests passed (162)**.
- `flutter test packages/zcrud_markdown` → **All tests passed (247)**.
- `python3 scripts/dev/graph_proof.py` → **RC=0** : `out-degree(zcrud_core)=0 (runtime)`, `ACYCLIQUE OK`, `CORE OUT=0 OK`.

## Findings par story

### DP-15 — select modal/multi/CRUD + choix dynamiques + seams
- **Neutralité (AD-1/AD-5) — OK.** `z_choices_source.dart` (port SYNCHRONE) + `z_relation_crud.dart` (port async, `dart:async` seul) : pur-Dart, aucun Flutter/backend. Registres **instanciables** (`ZChoicesSourceRegistry`/`ZRelationCrudRegistry`), lookup strict `sourceFor` (throw `ZUnregisteredTypeError`) + `trySourceFor` défensif (`null`). Aucune impl concrète dans le cœur.
- **SM-1 (AD-2) — OK.** `z_field_widget.dart` : `choicesFromKey` + `filterKeys` du `ZSelectConfig` fusionnés dans `_refListenables` (canal CIBLÉ, jamais global) — exactement le pattern `refKeys`/`filterKeys` DP-5. `ZSelectConfig` absent ⇒ aucun abonnement (repli E3-3a strict). Frappe hors clé source = 0 recompute du select.
- **Priorité de résolution défensive — OK.** `_resolveSelectChoices` : `choicesSourceKey` (registre+clé, `try/catch` sur `options`) → `choicesFromKey` (tranche `List<ZFieldChoice>` non vide) → `field.choices`. Aucun throw dans le build.
- **CRUD inline — OK.** `crudHandler` additif ; `crudKey==null`/registre/handler absent ⇒ aucun bouton (rétro-compat DP-5). Auto-sélection défensive.
- **LOW (informationnel)** `z_field_widget.dart:623` — une `ZChoicesSource` résolue qui retourne une liste **vide** court-circuite `choicesFromKey`/`field.choices` (choix vides rendus). Comportement **documenté** dans la story (« priorité au résultat de la source résolue, même vide ») ; conforme, signalé pour visibilité.

### DP-17 — number devise/% + color picker
- **Couleur = donnée (FR-26/style_purity) — OK.** `z_color_field_widget.dart` : ARGB `int` en tranche, palette **dérivée HSV** (aucun littéral `0xFF…RRGGBB`), masque alpha exprimé par décalage `0xFF << 24`. Seam `ZColorPicker` injecté prioritaire + picker built-in NEUTRE (100 % Flutter) en repli. Conversion `Color(argb)` **confinée** au widget (jamais dans le domaine). Seam défaillant → `try/catch` → aucune écriture (AD-10).
- **Suffixe number NEUTRE — OK.** `z_number_field_widget.dart` : `%`/symbole devise = **donnée** (`ZNumberConfig` + repli l10n), jamais un style codé en dur. `inputFormatters` = transformateurs purs (`show`-restreint, L-2).
- **LOW (nit)** `_ZColorPickerDialogState._applyHex` appelé à chaque frappe (`onChanged`) — reste **contenu au dialog** (setState local, hors formulaire) ; le champ hex n'est pas re-synchronisé pendant la frappe (curseur préservé). Aucune action requise.

### DP-18 — ZSignatureCodec strokes↔PNG
- **Rasterisation dart:ui DÉFÉRÉE — OK.** `z_signature_codec.dart` : `dart:ui` **absent** ; `toPng` orchestre le seam `ZSignatureRasterizer` (host-fourni) ; aucun rasterizer ⇒ `null` (dégradation propre). Seuls `Offset`/`Size` (via `flutter/widgets`) + `Uint8List` utilisés — couche présentation, conforme.
- **Round-trip défensif (AD-10) — OK.** `strokesFromValue`/`valueFromStrokes` : type inattendu/point mal typé ignoré, jamais de throw. `isPng`/`pngSize` (magic-number + IHDR offsets 16/20 big-endian) défensifs (non-PNG/trop court → `false`/`null`). Seam qui throw → `try/catch` → `null`.

### DP-19 — subitems soft-delete/templates + dynamicItem
- **Config additive `const` — OK.** `z_sub_list_config.dart` : `softDelete`/`creationTemplates`/`defaultNewItem`/`createNewTextKey` additifs, défauts rétro-compat DP-6, `==`/`hashCode` profonds (map/list). `ZSubListItemTemplate` pur-données (aucune closure).
- **Soft-delete — OK (design documenté).** `z_sub_list_field_widget.dart` : item `deleted=true` (mode compact/`softDelete`) **exclu de l'agrégation parent** (`onChanged` filtre `!item.deleted`) mais **conservé dans la session** (State) → action **restaurer** disponible ; résumé barré + badge a11y.
- **LOW (informationnel)** L'item soft-deleted est **exclu de la valeur persistée** (pas de flag `is_deleted` propagé au parent) : « restaurable » vaut **dans la session d'édition** uniquement (un reseed/reset le perd). C'est la sémantique **explicitement décrite** par la story (parité restreinte vs soft-delete persistant DODLP/AD-9) ; la persistance `is_deleted` reste un concern binding. Signalé pour traçabilité.
- **Non-régression DP-6 (compact/ACL/dialog) & DP-5 — OK** (suite core 857 verte, y compris `dp19_sub_list_dynamic_item_test.dart` + tests DP-6/DP-5 existants).

### DP-20 — validateur téléphone national
- **AD-12 (aucun préfixe/longueur/Togo/secret en dur) — OK.** `z_national_phone_validator.dart` : `prefixes`/`length` **paramètres requis**, aucune valeur nationale en défaut. La recette Togo vit en **doc-comment** (exemple), pas en code.
- **Défensif (AD-10) + pur-Dart (AD-14) — OK.** `validate` ne throw jamais (accepte `ZPhoneNumber`/`String`/`Map`/`null`), ordre requis→longueur→préfixe. Aucune dép Flutter/`phone_numbers_parser`/`zcrud_core`.
- **Tests propres verts (19/19).** Les 3 échecs de la suite intl sont **pré-existants et hors périmètre** (voir RC réels).

### DP-21 — geo formes/polyline/style/metadata
- **Neutralité SDK (AD-1) — OK.** `z_geo_shape.dart`/`z_geo_shape_style.dart` : aucun `import` Google/OSM/`Color`/`dart:ui` (domaine n'importe que `z_geo_*`/`dart:`). Couleurs = **ARGB `int`** (`fillColorArgb`/`strokeColorArgb`/`iconColorArgb`), traduction `Color` confinée aux `presentation/adapters/`.
- **Sérialisation défensive + rétro-compat — OK.** `fromMapSafe` : `raw` non-`Map`→`null`, sommets invalides ignorés, `holes` (liste de listes) filtrée sans throw, `style`/`metadata`/`label`/`id` corrompus→`null`/défaut. `toMap` **omet** les clés `null` → une forme E11a-1 (sans id/style/holes/metadata) produit **exactement** l'ancien `Map` (rétro-compat 3 formes preservée). Clés **camelCase**. Opacité bornée `[0,1]`. `copyWith`/`==`/`hashCode` profonds (holes/metadata).

### DP-22 — markdown embed image/vidéo + toolbar config
- **Isolation (AD-1/AD-7) — OK.** `z_media_embed.dart` : seam `ZMediaResolver`/`ZMediaEmbedScope` (InheritedWidget) — **aucune** dép réseau/WebView/picker, aucune URL/endpoint en dur ; sans resolver ou resolver qui throw → **placeholder thémé** (aucun accès réseau). Types embed = STANDARD Quill (`image`/`video`) pour interop/parité DODLP. `z_rich_text_core.dart` (consomme Quill) vit sous `lib/src/` et **n'est pas re-exporté** par le barrel (surface publique NEUTRE). `ZRichTextToolbarConfig` = classe de données pure (`const`, presets full/minimal/markdown).
- **Non-régression DP-3/DP-4 — OK** (`showToolbar` honoré sans `toolbarConfig` ; suite markdown 247 verte).
- **LOW (nit)** Libellés UI **en dur en français** dans le dialog média (`'Image'`/`'Vidéo'`/`'Source de l\'image'`) et tooltips toolbar (`'Insérer une image/vidéo'`), + `kImagePlaceholderLabel='image'`/`kVideoPlaceholderLabel='vidéo'`. **Cohérent avec le pattern pré-existant** LaTeX/table (E6-3/E6-4) — pas une régression. Candidat l10n si le package se dote d'un catalogue de traductions.

## Conclusion

**7/7 stories APPROVED.** Neutralité des seams (AD-1/AD-4/AD-5), SM-1 (AD-2), défensif (AD-10), rétro-compat additive et graphe acyclique (CORE OUT=0) **vérifiés**. Analyze RC=0 ; core/geo/markdown 100 % verts ; intl vert **hors 3 échecs asset-catalog PRÉ-EXISTANTS** (confirmés au baseline, hors périmètre des 7 stories). Aucun finding HIGH/MAJEUR/MEDIUM — uniquement des LOW informationnels.
