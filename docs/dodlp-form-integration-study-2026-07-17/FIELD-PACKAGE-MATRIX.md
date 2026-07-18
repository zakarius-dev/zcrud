# Matrice exhaustive — champ × package DODLP × couverture zcrud

> **Nature** : SYNTHÈSE / DÉCISION. Consolide les 7 lentilles de `STUDY.md` (packages
> `flutter_form_builder`, `awesome_select`, `flutter_switch`, `country_picker`,
> `intl_phone_number_input`, layout/aération) **et** les 6 rapports de champ
> `07-field-*.md` → `13-field-*.md`. Aucun code, aucun commit.
> **Date** : 2026-07-17. Repos : `/home/zakarius/DEV/dodlp-otr` (référence, lecture seule)
> vs `/home/zakarius/DEV/zcrud`.
> **Référence enum** : `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`
> (40 valeurs `EditionFieldType`).

**Invariants transverses appliqués à toute décision ci-dessous** : tout adaptateur de
package tiers vit **hors `zcrud_core`** (AD-1 — un satellite ou le binding `zcrud_get`,
jamais le cœur) ; aucun état de formulaire global (AD-2 — le seam `ZWidgetRegistry` ne
livre que `ctx.value`/`ctx.onChanged`, jamais le `ZFormController`) ; aucun style/libellé
codé en dur (FR-26 — thème via `ZcrudScope`/`ThemeExtension`) ; RTL + a11y (AD-13 —
directionnel + `Semantics` + ≥ 48 dp).

**Découverte structurante (rappel `STUDY.md`)** : zcrud a **déjà réimplémenté nativement**
la quasi-totalité des familles de champ DODLP. Le bug historique (jank/perte de focus) ne
venait pas des packages de rendu mais d'un `setState()` d'écran que `ZFormController`
corrige par conception. Le vrai travail restant = **câblage** + **quelques décisions
produit** + **une poignée de vrais gaps**.

---

## 1. Matrice maîtresse (une ligne par type de champ)

Légende couverture : **NATIF** = widget `zcrud_core` livré · **NATIF (impl différée)** =
contrat/seam présent, adaptateur concret non écrit · **SATELLITE** = couvert hors cœur ·
**ABSENT** = ni widget ni contrat.
Légende parité : ✅ natif OK · 🔌 adopter/câbler un package via satellite · 🔴 gap à combler.

| # | `EditionFieldType` | Package DODLP utilisé | Variante / usage DODLP | Couverture zcrud | Parité | Placement adaptateur (jamais `zcrud_core`) | Risque (fork/licence/migration) |
|---|---|---|---|---|---|---|---|
| 1 | `text` | `flutter_form_builder` (`FormBuilderTextField`) | orchestrateur cycle de vie, valeurs hors `FormBuilderState` | **NATIF** `ZTextFieldWidget` | ✅ | — (validateurs `form_builder_validators` déjà dep `zcrud_core`) | Faible |
| 2 | `multiline` | `flutter_form_builder` | `maxLines`, bloc | **NATIF** `ZTextFieldWidget` (multiline) | ✅ | — | Faible |
| 3 | `number` | `flutter_form_builder` | + mode `isPercentage` (suffixe %) | **NATIF** `ZNumberFieldWidget` (DP-17) | ✅ | — | Faible |
| 4 | `integer` | `flutter_form_builder` | clavier num. | **NATIF** `ZNumberFieldWidget` | ✅ | — | Faible |
| 5 | `float` | `flutter_form_builder` | décimal + devise | **NATIF** `ZNumberFieldWidget` (DP-17) | ✅ | — | Faible |
| 6 | `boolean` | `flutter_switch` ^0.3.2 | pill switch texte "Oui/Non" incrusté | **NATIF** `ZBooleanFieldWidget` (`SwitchListTile`) | ✅ | — (delta cosmétique via `SwitchThemeData`) | Faible |
| 7 | `dateTime` | `flutter_form_builder` (`FormBuilderDateTimePicker`) ; `date_time_picker` pkg **mort** | picker date+heure | **NATIF** `ZDateFieldWidget` (Material natif, ISO-8601) | ✅ | — | Faible |
| 8 | `time` | `showTimePicker` natif | heure seule | **NATIF** `ZDateFieldWidget` (`ZDateMode.time`) | ✅ | — | Faible |
| 9 | `select` | **`awesome_select`** (`SmartSelect`, fork git) | modal S2 responsive + recherche | **NATIF** `ZSelectFieldWidget` + configs (`ZSelectConfig`) | ✅/🔌 | Satellite `zcrud_select`/`zcrud_dodlp_compat` **ou** binding `zcrud_get` si parité modal riche exigée | **Élevé** (fork non pub.dev, `ref: master` flottant) |
| 10 | `radio` | `awesome_select` | **modal S2** (pas `RadioListTile` inline) | **NATIF** `ZSelectFieldWidget` (`radioAsModal: true`) | ✅/🔌 | idem #9 | Élevé (parité UX perçue : modal vs inline) |
| 11 | `checkbox` | `awesome_select` | choix multiple | **NATIF** (famille select multiple) | ✅ | idem #9 | Moyen |
| 12 | `relation` | `awesome_select` (`crudDataSelect`) | modal + recherche + **CRUD inline** | **NATIF** `ZRelationFieldWidget` (`searchable` modal, `ZRelationConfig.crudKey`) | ✅/🔌 | idem #9 (registres runtime `ZRelationSourceRegistry`/`ZRelationCrudRegistry` à vérifier) | Élevé (CRUD inline + fork) |
| 13 | `rowChips` | interne (logique DODLP) | puces mono-choix | **NATIF** `ZRowChipsFieldWidget` (`ChoiceChip`) | ✅ | — | Faible |
| 14 | `tags` | `flutter_tags` ^1.0.0-ns | `ItemTags` puces radius 20 + `TagsTextField` | **NATIF** `ZTagsFieldWidget` (bouton `+` explicite, ≥48dp) | ✅ | — (écart style pur, ajustable via `ZcrudTheme`) | Faible |
| 15 | `subItems` | mini-CRUD interne ; `editable` pkg **mort** | carte + dialog ; **aucun réordo** DODLP | **NATIF** `ZSubListFieldWidget` (+ `_move()` monter/descendre : **supérieur**) | ✅ | — | Faible |
| 15b | `subItems` **variante `itemsAreTags`** | `flutter_tags` (`dynamic_list_viewer.dart:242`) | rendu tag+icône+toggle ; **0 call-site actif** | **ABSENT** (pas de `ZSubListDisplayMode.tags`) | 🔴 (mineur) | `zcrud_core` : nouveau `ZSubListDisplayMode.tags` (`InputChip`, sans dépendance) | Faible (feature non observée en usage réel) |
| 16 | `dynamicItem` | sous-formulaire interne | `DeepAttribute` | **NATIF** (famille sous-formulaire) | ✅ | — | Faible |
| 17 | `file` | `file_picker` ^10.3.3 | bottom-sheet 4 sources | **NATIF (impl différée)** `ZAppFileField` + `ZFilePicker`/`ZFileSource` | ✅/🔌 | Adaptateur `ZFilePicker` dans `zcrud_get`/`zcrud_media` (E7) | Faible |
| 18 | `image` | `image_picker` ^1.2.0 | caméra + galerie (`pickMultiImage`) | **NATIF (impl différée)** `ZAppFileField` (`imageFallback`) | ✅/🔌 | idem #17 | Faible |
| 19 | `document` | `cunning_document_scanner` ^1.4.0 + `file_picker` | scan → PDF (`PdfCreationService`) | **NATIF (impl différée)** (`ZFileSource.scan` prévu, service PDF absent) | ✅/🔌 | idem #17 + service PDF (E7) | Moyen (`cunning_document_scanner` mono-mainteneur, natif plateforme) |
| 20 | `location` | (géo interne) | point géo | **SATELLITE** `zcrud_geo` (modèle + adapters carte) | ✅ | `zcrud_geo` | Faible |
| 21 | `geoArea` | `flex_color_picker` (style fill/stroke) | polygone/cercle + toolbar stylisation | **SATELLITE partiel** : modèle `ZGeoShapeStyle` OK ; **UI picker fill/stroke ABSENTE** | 🔴 | `zcrud_geo` : réutiliser seam `ZColorPicker`/`ZColorPickerDialog` (pas de 2ᵉ picker) | Faible (reporté à l'éditeur geofence interactif) |
| 22 | `phoneNumber` | `intl_phone_number_input` ^0.7.4 | sélecteur pays **dialog** + validateur TG | **SATELLITE** `zcrud_intl` `ZPhoneFieldWidget` (`phone_numbers_parser`) | ✅/🔌 | `zcrud_intl` **existe** — seul le **câblage** `registry.register('phoneNumber', …)` manque | Moyen (sélecteur inline vs dialog ; **migration données** String→`ZPhoneNumber`) |
| 23 | `country` | `country_picker` ^2.0.23 (**code mort**) ; vrai champ = `select` sur `WORLD_COUNTRIES` | picker pays | **SATELLITE** `zcrud_intl` `ZCountryFieldWidget` (zéro dép tierce) | ✅ | `zcrud_intl` (existe) — vérifier couverture l10n JSON | Faible |
| 24 | `address` | (recherche adresse interne) | adresse postale | **SATELLITE** `zcrud_intl` `ZAddressFieldWidget` (s'auto-enregistre `registry.register('address'/'addressSearch', …)`) ⟵ _corrigé orchestrateur : widget PRÉSENT, pas un gap_ | ✅ | `zcrud_intl` **existe** — recherche/géocodage éventuel via adapter `zcrud_geo` | Faible (pas de dette de parité observée) |
| 25 | `rating` | **aucun** (Material `Icons.star` ad-hoc, 5 fixes, `kGoldColor` codé) | note étoiles | **NATIF** `ZRatingFieldWidget` (max configurable, toggle-clear, a11y) — **supérieur** | ✅ | — | Nul |
| 26 | `slider` | **aucun** (`Slider` Material) | curseur `min/max/divisions` | **NATIF** `ZSliderFieldWidget` | ✅ | — (écarts cosmétiques : Card wrapper, couleurs) | Nul |
| 27 | `signature` | **`package:signature` ^6.3.0** (PAS syncfusion) | canevas 200px + Effacer/Valider, **PNG bitmap** | **NATIF** `ZSignatureFieldWidget` (0 dép, strokes vectoriels) | ✅ | — | **Migration données** (PNG DODLP → strokes zcrud, **non réversible**) |
| 28 | `color` | `flex_color_picker` ^3.7.1 | dialog roue HSV + primaires/accents/hex/opacité/récents | **NATIF** `ZColorFieldWidget` (DP-17) + seam `ZcrudScope.colorPicker` | ✅/🔌 | seam binding `zcrud_get` si roue HSV pixel-exacte exigée | Faible (`flex_color_picker` reste côté binding) |
| 28b | `color` **variante `multiple`** | **`color_picker_field` ^2.1.0** (≠ flex) | multi-sélection, `List<int>` ARGB | **ABSENT** (`ZColorConfig` strictement mono) | 🔴 | `zcrud_core` : `ZColorConfig.multiple` natif (recommandé) **ou** satellite `kind:"colorMulti"` | Faible (`color_picker_field` peu maintenu — ne pas forker) |
| 29 | `icon` | (hors parité MVP) | picker d'icône | **ABSENT** (déclaré, fallback au rendu) | 🔴 (hors MVP) | satellite si besoin (registre d'icônes) | Faible |
| 30 | `markdown` | `flutter_quill` ^11.5.1 + `flutter_math_fork` + `markdown_quill` | éditeur bloc, toolbar, LaTeX, table, dialog plein écran | **SATELLITE** `zcrud_markdown` `ZMarkdownField` | ✅ | `zcrud_markdown` (existe) | Faible (mêmes libs) — gap LaTeX SVG (#33) |
| 31 | `inlineMarkdown` | `flutter_quill` | toolbar minimale inline | **SATELLITE** `zcrud_markdown` (`isInline`) | ✅ | `zcrud_markdown` | Faible |
| 32 | `html` | **`html_editor_enhanced` ^2.7.1** (WYSIWYG WebView Summernote + MathJax CDN) | édition WYSIWYG DOM | **SATELLITE partiel** : réinterprété via `ZHtmlCodec`→Delta→`ZMarkdownField` ; **WYSIWYG ABSENT** | 🔴 | **Nouveau satellite `zcrud_html`** (porte de sortie documentée) — jamais `zcrud_markdown` | Moyen (WebView + JS, migration HTML riche→Delta avec pertes bornées) |
| 32b | `html`/`inlineHtml` **lecture** | **`flutter_html` ^3.0.0** (`Html(data:)`) | rendu HTML natif | **SATELLITE partiel** : via `ZMarkdownReader` (Quill) après `ZHtmlCodec` | 🔴 | idem #32 | Moyen (round-trip borné : perte code inline / styles CSS exotiques) |
| 33 | `markdown`/`html` **LaTeX fallback** | `flutter_tex` ^5.1.10 (TeX→SVG) | filet MathJax-like si `flutter_math_fork` échoue | **ABSENT** (`flutter_tex` **banni** par test d'isolation) | 🔴 (assumé) | **Ne pas adopter** — placeholder thémé au lieu du SVG | Moyen (dép lourde/WebView — décision d'archi) |
| 34 | `inlineHtml` | `html_editor_enhanced`/`flutter_html` | HTML en ligne | **SATELLITE partiel** (idem #32/#32b) | 🔴 | `zcrud_html` | Moyen |
| 35 | `richText` | `flutter_quill` | Delta interne | **SATELLITE** `zcrud_markdown` (4ᵉ kind à confirmer) | ✅ | `zcrud_markdown` | Faible |
| 36 | `stepper` | interne (`dynamic_stepper`, `MyStickyHeader` + `expandable`) | steppers/sections | **NATIF** `ZStepperConfig` (répare le bug DODLP `indicatorSize`) | ✅ | — (paramètre de `DynamicEdition`, pas un widget de champ) | Faible |
| 37 | `password` | `flutter_form_builder` (`obscureText`) | texte masqué | **NATIF** (`text` + masquage) | ✅ | — | Faible |
| 38 | `hidden` | — | non rendu | **NATIF** (comportement, pas un widget) | ✅ | — | Nul |
| 39 | `widget` | — (builder libre) | closure runtime | **NATIF** (seam `ZWidgetRegistry`/`ZTypeRegistry`) | ✅ | app/satellite via `register` | Nul |
| 40 | `custom` | — (extension hôte AD-4) | type projeté par l'app | **NATIF** (seam ouvert) | ✅ | app/satellite via `register` | Nul |

**Familles hors `EditionFieldType` (packages DODLP attribués mais non-champ)** : `dateRange`
(voir §2) ; jauge upload `percent_indicator` (infra, pas un champ) ; réordo `subItems`
(`drag_and_drop_lists` **non utilisé** dans `data_crud`) ; swipe `flutter_slidable`
(**mort**) ; sections repliables `expandable`/`MyStickyHeader` (layout, couvert par
lentille aération) ; autocomplete inline `autocomplete_textfield` (hors `data_crud`) ;
PIN `pinput`, table `editable`, `date_time_picker`, `camera`, `video_thumbnail`,
`image_cropper` avatar, `file_manager`/`open_file`/`dotted_border`, `table_calendar`,
`syncfusion_flutter_signaturepad` — **tous morts, hors moteur CRUD, ou avatar hors schéma**
(voir §3).

---

## 2. Champs ABSENTS de zcrud — le vrai backlog (priorisé)

**8 gaps réels** (types/variantes que zcrud ne peut pas rendre aujourd'hui). Aucun ne
requiert un fork risqué : la majorité se comble en Flutter natif ou par un satellite propre.

| Prio | Champ / variante absent | Package DODLP source | Satellite cible (jamais `zcrud_core` pour un widget lourd) | Effort | Note |
|---|---|---|---|---|---|
| **P1** | **`dateRange`** (plage de dates) — *net-new, zéro dette de parité* | aucun (DODLP ne l'a jamais fait ; `table_calendar` mort en form) | **`zcrud_core` natif** `ZDateRangeFieldWidget` (`showDateRangePicker` SDK) + enum + `ZDateRange` + codegen | **M** | **Ne pas** adopter `table_calendar`. Story sérialisée seule sur `zcrud_core` (règle parallélisation). Gain net. |
| **P1** | **`color` multiple** (`ZColorConfig.multiple`, `List<int>` ARGB) | `color_picker_field` ^2.1.0 | **`zcrud_core` natif** (picker built-in en boucle + case à cocher) — recommandé ; sinon satellite `kind:"colorMulti"` | **S-M** | `color_picker_field` peu maintenu — répliquer en Flutter pur, ne pas forker. Non traité par DP-17. |
| **P2** | **`html` WYSIWYG** (édition DOM pixel-exacte) | `html_editor_enhanced` ^2.7.1 | **Nouveau satellite `zcrud_html`** (porte de sortie déjà documentée) | **L** | Seulement si le owner exige la WYSIWYG. Casse le contrat Delta unique (AD-2) : à isoler comme 2ᵉ voie assumée. |
| **P2** | **`html`/`inlineHtml` rendu natif** (balises HTML arbitraires en lecture) | `flutter_html` ^3.0.0 | `zcrud_html` (même satellite) | **M** | Couplé au P2 WYSIWYG. Sinon `ZHtmlCodec`→Delta suffit pour HTML **simple/structuré**. |
| **P3** | **`geoArea` — UI stylisation fill/stroke** (toolbar geofence) | `flex_color_picker` (roue seule) | `zcrud_geo` : **réutiliser** le seam `ZColorPicker`/`ZColorPickerDialog` de `zcrud_core` | **M** | Modèle `ZGeoShapeStyle` déjà prêt. Reporté à l'éditeur geofence interactif. Pas de 2ᵉ picker. |
| ~~P3~~ | ~~**`address`**~~ | interne DODLP | **PAS UN GAP** — `ZAddressFieldWidget` PRÉSENT dans `zcrud_intl` (auto-enregistré `'address'`/`'addressSearch'`) ⟵ _corrigé orchestrateur_ | — | Éventuel géocodage de recherche = adapter `zcrud_geo` (amélioration, pas parité). | Nul |
| **P4** | **`subItems` variante `itemsAreTags`** (rendu tag + icône + toggle) | `flutter_tags` | `zcrud_core` : `ZSubListDisplayMode.tags` (`InputChip`, zéro dép) | **S** | Feature plombée mais **0 call-site actif** dans DODLP cloné. Priorité basse (peut-être active IFFD/DLCFTI). |
| **P4** | **`icon`** (picker d'icône) | — (hors parité MVP) | satellite dédié (registre d'icônes) si besoin | **S** | Déclaré `EditionFieldType.icon`, fallback au rendu. Aucun besoin produit prouvé. |

**Gaps « assumés par architecture » (à ne PAS combler par défaut)** :
- **LaTeX fallback SVG `flutter_tex`** (#33) : banni par `quill_signature_isolation_test.dart`.
  Formule hors sous-ensemble `flutter_math_fork` → placeholder thémé, pas de SVG. Accepter le gap.

**Gaps d'IMPLÉMENTATION (contrat présent, pas un gap de conception — prévus E7)** :
- **`ZFilePicker` concret** (`image_picker`/`file_picker`/`cunning_document_scanner`) — seams
  `ZFileSource.{scan,camera,gallery,filePicker}` déjà dans le cœur ; adaptateur dans `zcrud_get`/`zcrud_media`.
- **`CloudStorageRepository` concret** (Firebase Storage) — port défini, impl dans `zcrud_firestore`.
- **Câblage `phoneNumber`** — `ZPhoneFieldWidget` existe et est testé ; aucun binding n'appelle
  `registry.register('phoneNumber', …)` aujourd'hui.

---

## 3. Champs où le natif zcrud suffit (aucune dépendance à ajouter)

**Ne pas recréer la roue** : ces champs sont couverts nativement (souvent **supérieurs** à
DODLP en a11y/RTL/thème). Adopter un package ici serait une régression AD-1/AD-13.

- **Texte / nombre / date** (`text`, `multiline`, `number`, `integer`, `float`, `dateTime`,
  `time`, `password`) : natif ; `flutter_form_builder` **écarté** (seuls ses validateurs
  `form_builder_validators`, déjà dep pure de `zcrud_core`, sont réutilisés). `date_time_picker`
  (pkg) est **code mort** chez DODLP.
- **`boolean`** : `SwitchListTile` natif ; `flutter_switch` = delta cosmétique absorbable par thème.
- **`tags`** / **`rowChips`** : `ZTagsFieldWidget` / `ZRowChipsFieldWidget` natifs ; `flutter_tags`
  inutile (natif ajoute même un bouton `+` explicite + a11y).
- **`subItems`** (réordonnancement) : `ZSubListFieldWidget._move()` **dépasse** DODLP (qui n'a
  aucun réordo) ; `drag_and_drop_lists`/`editable` sont morts/hors-CRUD.
- **`rating`** / **`slider`** / **`signature`** : natifs, **0 dépendance des deux côtés** (DODLP
  n'a pas de package rating/slider ; `package:signature` remplacé par strokes vectoriels natifs).
  Écarts purement cosmétiques (layout Row/Column, `Card` wrapper, couleurs codées DODLP).
- **`country`** : `ZCountryFieldWidget` natif ; `country_picker` est **code mort** chez DODLP.
- **`stepper`** / sections : `ZStepperConfig` + grille responsive natifs (réparent des bugs DODLP).

---

## 4. Décisions natif-vs-package pour le owner

Là où deux voies coexistent (natif zcrud **ou** adopter le package DODLP). Recommandation +
justification (parité vs poids/AD-1). **La recommandation par défaut est le natif** ; le
package n'entre qu'au prix d'un satellite/seam explicite.

| Décision | Natif zcrud | Package DODLP (via satellite/seam) | Recommandation | Justification |
|---|---|---|---|---|
| **D1 — `color`** | `ZColorFieldWidget` (sliders HSV + hex + récents) | `flex_color_picker` (roue HSV + primaires/accents + `nameThatColor`) via seam `ZcrudScope.colorPicker` | **Natif par défaut** ; adaptateur binding **optionnel** si roue pixel-exacte jugée bloquante | Fonctionnellement équivalent (même espace couleur atteignable). `flex_color_picker` MIT maintenu mais lourd → **reste côté binding**, jamais `zcrud_core`/`zcrud_geo` (AD-1). |
| **D2 — `select`/`radio`/`relation`** | familles natives + `ZSelectConfig.radioAsModal`/`ZRelationConfig.crudKey` | `awesome_select` (`SmartSelect` modal S2 + recherche + CRUD inline) | **Trancher** : natif (delta visuel modal) **vs** adopter le fork | **Le point dur.** `awesome_select` = fork git non pub.dev, `ref: master` flottant, mainteneur unique → risque semver propagé à **tous** les consommateurs. Seul type où la parité DODLP est réellement riche. Décider aussi l'emplacement (`zcrud_select`/`zcrud_dodlp_compat`/module `zcrud_get`) et l'option **vendoriser** (fork interne). |
| **D3 — `signature`** | `ZSignatureFieldWidget` (strokes vectoriels, 0 dép) | `package:signature` (PNG bitmap) | **Natif** (sans hésiter) | Natif gagne en isolation (AD-1) + a11y. Le vrai sujet n'est **pas** le widget mais la **migration de données** (PNG DODLP existants → non redécodables en strokes ; item ETL, pas un gap de package). |
| **D4 — `phoneNumber` (sélecteur pays)** | `ZPhoneFieldWidget` panneau **inline** | `intl_phone_number_input` sélecteur **dialog modal** | **Natif + décider la variante UX** | `zcrud_intl` existe et est testé. Question : le panneau inline suffit-il, ou faut-il une variante `showDialog`/`showModalBottomSheet` pour coller au dialog DODLP ? + **migration données** String→`ZPhoneNumber` (backfill `ZPhoneCodec.parse(raw, iso:'TG')`). |
| **D5 — `html` WYSIWYG** | `ZHtmlCodec`→Delta→`ZMarkdownField` (sous-ensemble commun) | `html_editor_enhanced` (WYSIWYG WebView pixel-exact) | **Accepter le gap** sauf besoin fort → sinon **nouveau `zcrud_html`** | Adopter dans `zcrud_markdown` casserait le test d'isolation + introduirait une 2ᵉ voie d'état hors `ZFormController` (AD-2). Réserver à un satellite distinct assumé. Migration HTML riche→Delta = pertes **bornées documentées**. |
| **D6 — LaTeX fallback SVG** | placeholder thémé si `flutter_math_fork` échoue | `flutter_tex` (TeX→SVG MathJax-like) | **Accepter le gap** (ne pas adopter) | `flutter_tex` banni par test d'isolation (dép lourde/WebView). Cas rare (chimie `\ce{}`, macros exotiques), dégradation propre, pas de crash. |
| **D7 — `dateRange`** | `ZDateRangeFieldWidget` natif (`showDateRangePicker` SDK) | `table_calendar` | **Natif** | DODLP ne l'a jamais implémenté → **zéro contrainte de parité**. `table_calendar` = calendrier complet lourd, disproportionné pour un range-picker ponctuel. |

---

## 5. Lien showcase & harnais 6-formulaires DODLP

### 5.1 Page showcase — champs/variantes à démontrer

**Doit exercer chaque famille couverte + chaque écart/décision** pour rendre les arbitrages
visibles au owner :

- **Familles natives « tout vert »** (preuve de parité fonctionnelle + supériorité a11y) :
  `text`, `multiline`, `number` (+ `%`), `integer`, `float` (+ devise), `boolean`, `dateTime`,
  `time`, `tags`, `rowChips`, `rating`, `slider`, `signature`, `subItems` (avec **réordo
  monter/descendre** — écart supérieur à DODLP), `stepper`, `password`.
- **Décisions natif-vs-package** (montrer les **deux** rendus côte à côte quand possible) :
  `color` (built-in sliders **vs** seam `flex_color_picker`) ; `select`/`radio`/`relation`
  (natif **vs** modal `awesome_select` — surface la décision D2) ; `phoneNumber` (panneau
  inline **vs** dialog — décision D4).
- **Satellites** : `markdown`/`inlineMarkdown` (toolbar + LaTeX inline/bloc + table + media),
  `country`, `location`/`geoArea` (avec le **gap UI stylisation** signalé), `html` (rendu via
  `ZHtmlCodec` + bandeau « WYSIWYG hors périmètre » pour la décision D5).
- **Gaps du backlog (§2)** — placeholders explicites étiquetés « ABSENT / à combler » :
  `dateRange`, `color` multiple, `icon`, `subItems.itemsAreTags` (⟵ `address` RETIRÉ : widget présent). Ne pas les cacher :
  la showcase sert aussi de tableau de bord du reste-à-faire.
- **Preuve SM-1** : un formulaire de frappe intensive (100 caractères → seul le champ courant
  se reconstruit, zéro perte de focus) — le cœur de l'objectif produit n°1.

### 5.2 Harnais 6-formulaires DODLP — champs exercés

Le harnais rejoue des formulaires **réels** DODLP pour valider la migration sans régression.
Chaque formulaire doit couvrir un axe de risque distinct :

1. **Formulaire texte/nombre/date dense** → familles natives + validateurs `form_builder_validators`
   + SM-1 (rebuild granulaire sous frappe).
2. **Formulaire à sélections** (`select`/`radio`/`relation` + `crudDataSelect`) → **exerce la
   décision D2** (parité modal S2, CRUD inline, `radioAsModal`).
3. **Formulaire média** (`file`/`image`/`document` + scan) → exerce l'adaptateur `ZFilePicker`
   (4 sources) + `CloudStorageRepository` (E7).
4. **Formulaire rich-text** (`markdown`/`inlineMarkdown` + LaTeX + table + `html`) → exerce
   `zcrud_markdown` + le round-trip `ZHtmlCodec` borné (décision D5/D6).
5. **Formulaire intl/géo** (`phoneNumber` + `country` + `location`/`geoArea`) → exerce le câblage
   `zcrud_intl` + la **migration données téléphone** (D4) + le gap UI geofence (P3).
6. **Formulaire spécialisés/imbriqués** (`rating`/`slider`/`signature`/`color`/`subItems` +
   réordo) → exerce les natifs « 0 dépendance » + les décisions D1/D3 + la **migration données
   signature** (PNG→strokes, item ETL).

**Gate transverse par formulaire** : 16 AD ; CORE OUT=0 (grep — aucune dép lourde dans
`zcrud_core/pubspec.yaml`) ; SM-1 ; tests widget RTL/a11y ; vérif verte
`generate`+`analyze`+`test` rejouée avant tout `done`.

---

## Annexe — les 3 écarts les plus coûteux pour la parité DODLP

1. **`select`/`radio`/`relation` via `awesome_select` (décision D2)** — le seul type où la parité
   DODLP est visuellement riche (modal S2 responsive + recherche + CRUD inline), porté par un
   **fork git non pub.dev à `ref` flottant** : coûteux à reproduire nativement ET risqué à adopter.
2. **`html` WYSIWYG (`html_editor_enhanced`) + rendu `flutter_html` (décision D5)** — gap assumé par
   architecture : exige un satellite `zcrud_html` entier (WebView + 2ᵉ voie d'état hors AD-2) et une
   migration HTML riche→Delta à pertes bornées.
3. **Migrations de données non-widget** — `signature` (PNG bitmap → strokes vectoriels
   **non réversibles**) et `phoneNumber` (String legacy → `ZPhoneNumber` E.164) : le widget est prêt
   des deux cas, mais un backfill ETL est indispensable, sinon perte silencieuse à la migration.
