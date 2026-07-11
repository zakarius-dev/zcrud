# Parité moteur d'édition DODLP → zcrud — Matrice de gaps

> Consolidation de 6 analyses de domaine (lecture réelle de `dodlp-otr/lib/modules/data_crud/**`
> vs `packages/{zcrud_core,zcrud_markdown,zcrud_geo,zcrud_intl}/lib/src/**`).
> Objectif : disposer d'une carte actionnable des écarts avant migration DODLP → zcrud.

---

## 1. Résumé exécutif

### Volumétrie (≈117 features analysées, 6 domaines)

| Sévérité | Décompte (dédupliqué) | Signification |
|---|---|---|
| **Blocking** | **14** | Bloque une migration structurellement fidèle : capacité absente OU changement de contrat de données / d'UX pour des usages **réels en prod** DODLP. |
| **Major** | **~24** | Régression fonctionnelle/visuelle notable ; contournement possible mais coûteux. |
| **Minor** | **~30** | Écart cosmétique, confort, ou capacité peu/pas utilisée. |
| **Parité (supported / none)** | **~40** | Comportement porté fidèlement (souvent amélioré). |

### Les 14 gaps BLOQUANTS (dédupliqués)

1. **`FieldSize.large`** — variante visuelle Card (label au-dessus, minHeight 64, leading/suffix) : **absente** de `ZFieldSpec`. Usage prod réel (`pia/cargaison_stepper_form.dart`, `antaser/besc_detail_form.dart`, y compris dans un stepper). *(apparaît dans 3 domaines : layout, spécialisés, transverse).*
2. **`ZTextConfig.minLines/maxLines` mort** — déclaré au domaine mais **jamais lu** par `ZTextFieldWidget` (hardcodé 1/1 ou 3/null). Toute config multi-lignes authored serait silencieusement ignorée.
3. **`displayCondition` → `ZCondition` trop faible** — closures DODLP réelles (`crud != Crud.read`, `mode == …`, `(entries as List).isNotEmpty`) **inexprimables** dans l'arbre déclaratif `ZCondition` (pas de contexte externe, pas de prédicat de forme/liste, pas d'accès à l'item persisté distinct de l'état).
4. **Mode LECTURE SEULE rich-text absent** — `ZMarkdownField` ne lit jamais `field.readOnly`, affiche **toujours** l'éditeur Quill + toolbar. Tout écran de consultation DODLP casserait.
5. **Type de champ `html`/`inlineHtml`** — **aucun** widget WYSIWYG HTML ni `ZCodec` HTML côté zcrud. Champs `html` prod DODLP sans voie de migration.
6. **Distinction `markdown` (bloc, plein-écran) vs `inlineMarkdown` (compact)** — un seul `ZMarkdownField` sans mode inline/fullscreen ni dialog plein-écran. `inlineMarkdown` = type rich-text le plus utilisé DODLP (9 fichiers bmd/vido).
7. **`crudDataSelect` (relation dynamique)** — `ZRelationFieldWidget` n'est qu'un dropdown statique (`options` vide par défaut) ; **pas de stream/repository/filtre cross-champ** (câblage « E4 » à confirmer).
8. **`subItems` — inline vs liste compacte + dialog** — zcrud rend TOUS les sous-champs de TOUS les items en ligne ; DODLP = liste tabulaire/résumé + dialog d'édition par item + ACL + `popUpMenuOptions`. Changement d'UX fondamental pour pia/antaser/auth.
9. **Champ geo — barre d'outils éditeur** — `GeoEditorToolbarConfig` (18 toggles, 5 presets) absent ; zcrud = saisie manuelle de coordonnées lat/lng, pas d'éditeur GIS.
10. **Champ `address` — incompatibilité de schéma** — DODLP persiste une **String** (+ Google Places autocomplete) ; zcrud persiste un **`ZPostalAddress` structuré** (6 sous-champs) sans recherche géographique. Migration de données requise.
11. **`StepperConfig` absent + stepper non récursif** — `ZStepperEdition` = partitionnement plat, un seul style fixe « Étape k/N ». Pas d'orientation/style/couleurs/icônes/subtitles, pas de steppers imbriqués (20+ usages bmd/vido).
12. **Dates — bornes min/max ignorées** — `ZDateFieldWidget` hardcode `DateTime(1900)/DateTime(2100)`, ne lit ni `ZDateConfig.firstDateKey/lastDateKey` ni un `minDate/maxDate` littéral (inexistant). Toute borne DODLP perdue.
13. **Type `dateTime` = date SEULE** — `ZDateFieldWidget` n'ouvre qu'un `showDatePicker` pour `dateTime`, fige l'heure à minuit. DODLP ouvre un picker combiné date+heure.
14. **`timestamp` (persistance Firestore)** — pas de hint de sérialisation par champ pour distinguer « persister comme `Timestamp` natif » vs « String ISO-8601 » ; migration change silencieusement le format sur disque. *(AD-5 interdit `Timestamp` dans le domaine → besoin d'un mécanisme côté générateur/`zcrud_firestore`).*

---

## 2. Gaps par domaine

### 2.1 Éditeur Markdown / Rich-text (`zcrud_markdown`)

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| Mode lecture seule rich-text | Bascule vers rendu non-éditable dès `readOnly`/action `read` (`edition_screen.dart:1282-1330,3849-3910`) | **missing** — `z_markdown_field.dart` ne lit jamais `field.readOnly` | Affiche toujours l'éditeur+toolbar ; aucun reader léger ; `ZFieldWidgetContext` ne passe pas de flag readOnly | **blocking** |
| Type `html`/`inlineHtml` (WYSIWYG) | `html_editor_enhanced` + MathJax + upload image + toolbar HTML (`html_editor_wrapper.dart:1-370`) | **missing** — aucune dep HTML | Pas de widget ni `ZCodec` HTML ; champs `html` prod sans migration | **blocking** |
| `markdown` (bloc/plein-écran) vs `inlineMarkdown` (compact) | `MarkdownEditionField.isInline` + `RichTextEditorScreen` en dialog fullscreen (`markdown_edition_field.dart:34-452`) | **missing** — un seul widget (`edition_field_type.dart:129-133`) | Pas de mode aperçu/plein-écran ni toggle | **blocking** |
| Dialog/bottom-sheet plein-écran | `RichTextEditorScreen` (dialog 80%×70% ou Scaffold) (`rich_text_editor_screen.dart:38-521`) | **missing** | Aucun écran d'édition plein-écran | major |
| Toolbar configurable par field | `RichTextToolbarConfig` (présets full/minimal/markdown) (`editor_config.dart:18-72`) | **partial** — seul `showToolbar: bool` (`z_markdown_field.dart:213-292`) | Config Quill câblée en dur, pas de granularité par bouton | major |
| Conversion Delta ↔ HTML | `vsc_quill_delta_to_html` / `flutter_quill_delta_from_html` (`rich_text_editor_screen.dart:212-319`) | **missing** — deps HTML absentes | Aucun `ZHtmlCodec` | major |
| Upload/embed image & vidéo | `onImageUpload`, embeds image/vidéo (`html_editor_wrapper.dart:112-124`; `delta_to_markdown_helper.dart:513-534`) | **missing** — seuls latex/table | Embed image/video non rendu (`unknownEmbedBuilder`) | major |
| Wiring `markdown/…/richText` → widget | Intégré dans le switch géant (`edition_screen.dart`) | **partial** — `registryOrFallback` (`edition_field_family.dart:178-195`) | `zcrud_markdown` **ne s'auto-enregistre pas** ; app doit câbler chaque kind ; `html/inlineHtml` restent en repli | major |
| LaTeX bloc (display) vs inline (text) | `FormulaBlockEmbed` / `FormulaInlineEmbed` (`formula_embed.dart:247-407`) | **partial** — `ZLatexEmbed` unique `MathStyle.text` | Pas de mode display/bloc centré | minor |
| Dialogue LaTeX (aperçu live, exemples, fallback SVG) | `FormulaEditDialog` + `RenderComplexLatex` + fallback flutter_tex (`formula_edit_dialog.dart:1-226`) | **partial** — `TextField` nu, pas d'aperçu | Ni aperçu live, ni exemples, ni 2e moteur de rendu | minor |
| Éditeur de tableau riche | `TableEditorScreen` (Quill par cellule, menus ligne/colonne, grille hover) (`table_editor_screen.dart:1-989`) | **partial** — `_ZTableDialog` texte brut par cellule | Cellules texte brut, dialog modal, pas de menus par ligne/col | minor |
| Rendu tableau lecture (double-clic) | `TableViewWidget` cellules riches, hover « double-clic pour éditer » | **supported** — `ZTableEmbedBuilder` texte brut | Contenu cellule non enrichi, pas d'affordance hover | minor |
| Table des pertes Markdown | Convertisseur maison préserve `<u>` souligné (`delta_to_markdown_helper.dart:538-612`) | **partial** — `ZMarkdownCodec` documente la perte (souligné/couleur/police…) | Perte au round-trip Markdown (pas sur `ZDeltaCodec` par défaut) | minor |
| minLines/maxLines rich-text | `DynamicFormField.minLines/maxLines` | **missing** | Hauteur intrinsèque, pas de mode compact borné | minor |
| Limite caractères / spellcheck | `characterLimit`/`spellCheck` | **missing** | Aucun équivalent | minor |
| Styles Quill (couleurs/Google Fonts) | `QuillDefaultStylesHelper` (H1-H6, google_fonts) | **partial** — bordure thème seule | Pas de `customStyles`/`DefaultStyles` (en partie divergence voulue AD-13) | minor |

### 2.2 Catalogue des 37 types de champ

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| `timestamp` | Persiste `Timestamp.fromDate` Firestore natif (`edition_screen.dart:3694`) | **missing** — absorbé par `dateTime` ISO-8601 | Pas de hint de sérialisation par champ ; format disque change silencieusement | **major** |
| `select` — choix dynamiques | `stateChoiceItems` recalculés depuis un autre champ | **partial** — `ZFieldSpec.choices` const figée | Pas de recalcul cross-champ déclaratif | major |
| `crudDataSelect` → `relation` | Stream Firestore, multi-select chips, modal recherche, disabled-predicate (6 fichiers) | **partial** — `z_relation_field_widget.dart` dropdown statique | Pas de source dynamique/multi/modal (« câblage E4 ») | major |
| `inlineMarkdown` | `isInline:true`, largement utilisé (9 fichiers bmd/vido) | **missing** — `ZMarkdownField` non enregistré au registry | Pas branchable sur le kind ; type rich-text le + utilisé | major |
| `stepper` | Récursif + `StepperConfig` par instance (20+ usages) | **partial** — `ZStepperEdition` plat, un style | Pas de nesting ni config visuelle | major |
| `text` | Un seul type, minLines/maxLines | **partial** — scindé `text`/`multiline` | Règle de mapping requise (text+minLines>1 → multiline) | minor |
| `number`/`float` | `isCurrency`, min/maxValueKey croisés | **partial** — pas d'`isCurrency` lu | Formatage monétaire absent | minor |
| `time` | Map{hour,minute} (TimeOfDay) | **partial** — ISO-8601 | Conversion explicite à la migration | minor |
| `color` | `recentColors` | **partial** | Pas de couleurs récentes | minor |
| `widget` | Closure inline sur le champ | **supported** — via `ZWidgetRegistry` (kind 'widget') | Indirection registry (migration mécanique non 1:1) | minor |
| `subItems` | mini-CRUD plein (listViewBuilder, itemActionsBuilder) | **supported** — SM-1 imbriqué garanti | Pas d'écran plein-écran autonome (différé E4-5) | minor |
| `markdown` | 0 usage réel hors moteur | **missing** — widget non enregistré | Non branchable sur le kind | minor |
| `html` | 0 usage réel | **missing** | Aucun éditeur HTML | minor |
| `address`/`addressSearchField` | 2 valeurs distinctes, même rendu | **partial**/**missing** — une seule `address` | Mapping n:1 + pas de recherche géo | minor |
| `geoArea` | point/polygone/cercle | **supported** — même widget que location | Vérifier support polygone/cercle complet | minor |
| `tags` | suggestions/autocomplete | **supported** | Vérifier équivalent `suggestions` | minor |
| `icon`/`password`/`hidden`/`checkbox` | **types morts** DODLP (default→EmptyContainer, 0 usage) | **supported** (zcrud les implémente correctement) | Aucun risque (zcrud > DODLP) | none |
| `integer`/`boolean`/`dateTime`/`rowChips`/`radio`/`file`/`image`/`document`/`rating`/`slider`/`signature`/`phoneNumber`/`country`/`location`/`dynamicItem` | — | **supported** | Parité | none |

### 2.3 Affichage / taille / layout

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| `FieldSize.large` (Card wrapper) | `_buildLargeCard` minHeight 64, 15 usages prod (`models.dart:88-94`; `edition_screen.dart:893-971`) | **missing** | Aucun `fieldSize`/wrapper Card | **blocking** |
| `minLines`/`maxLines` (texte) | Pilotent le `TextFormField` (ex. minLines:2/maxLines:4 pia) | **partial** — `ZTextConfig` déclaré mais **jamais lu** (`z_text_field_widget.dart:71-72` hardcode) | Config authored ignorée au runtime | **blocking** |
| `displayCondition` | Closure arbitraire (item/editionState/crud + externes), usages réels (`cargaison_form.dart:57`, `besc_detail_form.dart:375`) | **partial** — `ZCondition` arbre déclaratif champ/valeur | Pas de contexte externe / forme de liste / item persisté | **blocking** |
| Leading/prefix/suffix par champ | `suffix/suffixIcon/preffix/leading` (`models.dart:559-565`) | **missing** | Aucun slot leading/suffix sur `ZFieldSpec` | major |
| Décor (`kFormInputDecorationTheme`) | radius 12, border w2, padding 16/16, helperMaxLines 2, floating bold (`themes.dart:17-78`) | **partial** — `ZcrudTheme` **non câblé** dans text/number/select/relation | Défauts divergents (radiusM=8, padding 12/8), pas de focus width/helperMaxLines | major |
| `showIfNull` — défaut inversé | défaut **false** (masque vides) (`models.dart:843`) | **partial** — défaut **true** (`z_field_spec.dart:82`) | Écrans lecture + denses sans audit champ par champ | major |
| Rendu lecture (widget dédié) | `readOnlyWidget` Card label/valeur + copie presse-papier (`edition_screen.dart:975-1040`) | **missing** — réutilise le widget d'édition `readOnly:true` | Apparence formulaire grisé au lieu de fiche consultation | major |
| Style label (bodyLarge/w500 + `*` requis rouge) | `_buildLabelWidget` (~20 usages) | **missing** — `labelText` String nue | Perte de l'astérisque requis + style | major |
| `hintText`/`helperText` par champ | Propagés dans `InputDecoration` | **missing** — absents de `ZFieldSpec` | Perte de contenu (pas seulement de style) | major |
| Span responsive xs..xl | Bootstrap 576/768/992/1200, cascade + bin-packing | **supported** — `z_responsive_grid.dart` seuils identiques | Wrap natif vs Expanded : vérifier pixel-fidelity | minor |
| Colocalisation span+champ | Propriétés directes du champ | **partial** — `layout: Map<String,ZResponsiveSpan>` externe | Clé string non typée (dérive au renommage) | minor |
| `withSpaceer` (12dp conditionnel) | SizedBox 12 après certains types, édition seule | **missing** — gutter uniforme 8dp | Champs collés en fallback Column | minor |
| Fallback pleine largeur | Column simple si aucun span | **supported** | Parité | none |
| `readOnly` per-field | `readOnly` + mode global | **supported** — `copyWith(readOnly:true)` | Parité | none |

### 2.4 Sélection, choix & relations

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| `crudDataSelect` source dynamique | `loadRessourcesStream` + `ressourceFilter` (`edition_screen.dart:2500-2549`) | **partial** — `options` statique (« E4 ») | Pas de Stream/filtre cross-champ | **blocking** |
| `subItems` (liste compacte + dialog) | `DynamicSubListScreen` DataTable + dialog par item + ACL + `popUpMenuOptions` (`dynamic_list_viewer.dart:15-463`) | **partial** — `ZSubListFieldWidget` tout inline | UX fondamentalement différente ; manque résumé/colonnes, dialog, ACL granulaire, transformer, itemsAreTags, crudRepository | **blocking** |
| `select` dropdown | `SmartSelect` S2 modal + filtre/recherche + sous-titre | **partial** — `DropdownButtonFormField` natif | Pas de modal/recherche/sous-titre/disabled | major |
| `select` multiple (chips) | `SmartSelect.multiple` confirmation + chips | **missing** | Seul `checkbox` porte le multi (UX différente) | major |
| `crudDataSelect` CRUD inline | Créer/modifier/copier l'entité liée (`edition_screen.dart:3223-3311`) | **missing** | Aucun bouton/callback CRUD | major |
| `subItems` actions CRUD + confirmation/restore | `showResourceBottomModalDialog` + soft-delete/restore/clear | **missing** — `_removeAt` direct sans confirmation | Pas de confirmation ni soft-delete | major |
| `dynamicItem` | Résumé + dialog séparé (`edition_screen.dart:1355-1453`) | **partial** — édition inline | UX inline vs dialog ; pas de `defaultNewItem`/`createNewText` (0 usage réel) | major |
| `select` lecture multi | Libellés joints (readOnlyWidget) | **missing** | Dropdown désactivé au lieu de synthèse | minor |
| Réinitialisation sélection | Bouton reset → null | **partial** | Pas de bouton reset natif | minor |
| `radio` | En réalité modal S2 (radios) | **partial** — RadioListTile inline | Inline vs modal (0 usage réel) | minor |
| `rowChips` | Wrap RawChip mono-choix | **partial** — ChoiceChip mono | Pas de `stateChoiceItems`/sous-titre (mode multiple mort DODLP) | minor |
| `tags` | ItemTags add/remove/dédup | **supported** — bouton + en plus | Amélioration a11y | none |
| `checkbox` DODLP | **type mort** (no-op) | **na** — multi-sélection fonctionnelle | zcrud > DODLP (à documenter) | none |
| Choix statiques `{id,name}` depuis enum | `enum.values.map(...)` recalculé | **supported** — `choices` non-const runtime OK | Parité | none |

### 2.5 Champs spécialisés (geo/phone/address/color/signature/dates/stepper/number)

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| Geo — barre d'outils éditeur | `GeoEditorToolbarConfig` 18 toggles/5 presets (`geo_editor_config.dart:7-273`) | **missing** — `z_map_adapter.dart` center/shape only | Saisie manuelle lat/lng, pas d'éditeur GIS | **blocking** |
| `address` — schéma | **String** + Google Places (`edition_screen.dart:1454-1589`) | **partial** — `ZPostalAddress` 6 sous-champs, pas de recherche | Incompatibilité persistance + pas d'autocomplete | **blocking** |
| `StepperConfig` visuel | position/orientation/style/couleurs/icônes/subtitles/5 presets (`stepper_config.dart:1-268`) | **missing** — `_StepIndicator` texte fixe | Perte totale de personnalisation wizard (usage prod) | **blocking** |
| `FieldSize.large` | `_buildLargeCard` (usage prod stepper/detail) | **missing** | Aucun équivalent | **blocking** |
| Dates — bornes min/max | `firstDateKey/lastDateKey` + `minDate/maxDate` littéral (`models.dart:643-647`) | **missing** — `ZDateFieldWidget` hardcode 1900/2100 | Bornes ignorées même si `ZDateConfig` déclare firstDateKey | **blocking** |
| `dateTime` = date+heure | `FormBuilderDateTimePicker` combiné | **missing** — `ZDateFieldWidget` date SEULE | Heure figée à minuit | **blocking** |
| Geo — formes (polyline) | 4 formes dont polyline (`geo_shape.dart:7-19`) | **partial** — 3 formes (pas polyline) | Tracé ouvert sans cible | major |
| Geo — style des formes (`GeoShapeStyle`) | couleur/opacité/icône/draggable/info-window | **missing** | Aucun styling par forme | major |
| `color` — richesse picker | `flex_color_picker` roue HSV+hex+opacité+recent+multi | **partial** — 15 swatches fixes, mono | Choix couleur arbitraire impossible | major |
| `signature` — format | Uint8List PNG bitmap | **partial** — strokes vectoriels normalisés | Incompatible données stockées (rasterisation requise) | major |
| Stepper — métadonnées par champ | `stepIndex/stepIcon/stepSubtitle` sur le champ | **partial** — `ZEditionStep{title,fields}` externe | Icône par étape non transportable | major |
| `number` — devise/pourcentage | `isCurrency`/`isPercentage` (`edition_screen.dart:1087`) | **missing** — `ZNumberConfig` déclaré mais **jamais lu** | Config morte, pas de formatage | major |
| Geo — holes + metadata | `holes`/`metadata`/`id` (`geo_shape.dart:277-315`) | **missing** — vertices+label | Polygone à trou impossible | minor |
| `phoneNumber` | `intl_phone_number_input` + validateur Togo | **supported** — `ZPhoneCodec` E.164 | Validateur national Togo à recréer | minor |
| `slider` — défauts | 0..100 | **partial** — 0..1 | Plage change silencieusement | minor |
| `file`/`image` — config | `allowedDocumentTypes` catégories + fallback image | **partial** — `allowedSources` (par source) | Pas de granularité par type doc, pas de fallback image | minor |
| `number` — bornes croisées | `minValueKey/maxValueKey` | **supported** — `ZValidatorSpec.refKey` (autre chemin) | Doublon de déclaration (confusion outillage) | minor |
| Dates — effacer valeur | Croix quand non requis | **missing** | Impossible de revenir à null | minor |
| `timestamp` | `Timestamp.fromDate` | **na** — String ISO (AD-5) | Vérifier adaptateur `zcrud_firestore` | minor |
| `password` | `text` + validator (obscure) | **supported** — enum dédié obscureText | Règles complexité à recréer | minor |
| `country` | picker (onSelect **vide**, bug) | **supported** — fonctionnel | zcrud > DODLP | none |
| `rating` max | hardcodé 5 | **supported** — `ZRatingConfig.max` configurable | zcrud > DODLP | none |
| `file` sources/upload | scan/caméra/galerie/picker | **supported** — seams `ZFilePicker`/storage | Parité | none |
| `icon` | type mort | **na** — « hors parité MVP » | Mort des deux côtés | none |

### 2.6 Formulaire transverse

| Feature | DODLP | zcrud (statut + réf) | Gap | Sév. |
|---|---|---|---|---|
| ACL formulaire (`RessourceACL` 11 flags) + `aclBuilder` sub-items | read/create/update/delete/copy/restore/archive/publish/clear/validate/history (`ressource_acl.dart:3-70`) | **partial** — `ZAcl` 5 actions, câblé LISTE seulement | Pas de copy/archive/publish/clear/validate/history ; jamais consommé côté `DynamicEdition`/sub-liste | major |
| Rendu vue lecture dédié | `readOnlyWidget` Card (`edition_screen.dart:975-1023`) | **missing** — TextFormField readOnly bordé | *(= 2.3 rendu lecture)* | major |
| `FieldSize.large` | Card pleine hauteur | **missing** | *(= gap blocking, ici classé major)* | major |
| Validateur téléphone Togo | préfixes 90/77/… longueur 11 (`edition_screen.dart:675-700`) | **missing** — `phoneNumber()` générique | Règle nationale perdue | major |
| Politique mot de passe | 8-20 car, maj+min, PAS de chiffre requis (`edition_screen.dart:719-742`) | **partial** — `password()` défauts + stricts | Mot de passe DODLP valide peut être rejeté | major |
| Clés validateur « format seul » | `address`/`percentage`/`date` = **no-op** validation | **partial** — `address→street()`, `percentage→between(0,100)` **valident** | Valeurs qui passaient en DODLP rejetées | major |
| Validation par étape stepper | Navigation LIBRE, jamais `validate()` (`dynamic_stepper.dart:814-852`) | **supported** — `_next()` **bloque** si invalide | Comportement + strict, casse flux non-linéaires | major |
| `stateValidators` (closures runtime) | Injection dynamique arbitraire | **missing** — catalogue `ZValidatorKind` fermé (AD-3) | Capacité perdue (0 usage réel) | minor |
| Persistance repli sections | GetStorage par titre (survit redémarrage) | **partial** — `_collapsed` en mémoire | Pas de persistance | minor |
| `enableFeadback` | readOnly sans bascule vue | **missing** | Pas de 2e niveau (0 usage réel) | minor |
| Accès `TextEditingController` externe | `field.controller/stateController` (auth_profile x5) | **partial** — `valueOf(name)` équivalent | Réécrire 5 accès (AD-2 interdit) | minor |
| Résolution thème | Constantes figées `kNavyColor`… | **supported** — `ZcrudTheme` ThemeExtension | Mapping explicite requis (AD-6 voulu) | minor |
| Espacement inter-champ | `withSpaceer` 12/16dp type-dépendant | **partial** — gutter 8dp uniforme | Densité différente (réglable) | minor |
| Dirty-tracking + discard | `isDirty` + fingerprint JSON | **supported** — dirty par tranche + `ZDiscardGuard` | Parité (+ robuste) | none |
| Soumission agrégée | `validateForm` + garde double-submit | **supported** — `ZEditionSubmitController` Either | Parité | none |
| Validation inter-champs `match` | `matchKey` (auth réel) | **supported** — `ZCrossFieldValidator` | Parité | none |

---

## 3. Liste priorisée des gaps à combler (action concrète)

### 🔴 BLOCKING

| # | Gap | Action proposée (fichier/package cible) |
|---|---|---|
| B1 | `FieldSize.large` | Ajouter `ZFieldVariant {normal, large}` à `ZFieldSpec` (`zcrud_core/domain/edition/z_field_spec.dart`) + annotation `@ZcrudField(variant:)` (`zcrud_annotations` + `zcrud_generator`) + décorateur Card générique dans le dispatcher `z_field_widget.dart` (thémé via `ZcrudTheme`). Prérequis : slots leading/suffix (B-adjacent M1). |
| B2 | `minLines/maxLines` morts | Câbler `field.config` (`ZTextConfig.minLines/maxLines`) dans `z_text_field_widget.dart:71-72` au lieu des littéraux. |
| B3 | `displayCondition` faible | Étendre `ZCondition` (`zcrud_core/domain/edition/z_condition.dart`) : (a) clé de **contexte externe** (ex. `ZConditionOp.contextEquals` lisant une Map de contexte passée à `DynamicEdition`), (b) prédicats de **forme** (`isEmptyList`/`lengthGt`), (c) accès à l'item persisté original. Documenter les patterns de contournement (pseudo-champ caché `mode`). |
| B4 | Lecture seule rich-text | Ajouter lecture de `field.readOnly` dans `ZMarkdownField` (`zcrud_markdown/.../z_markdown_field.dart`) + widget reader léger (Quill `readOnly:true` sans toolbar, ou rendu Markdown statique) ; propager un flag readOnly via `ZFieldWidgetContext`. |
| B5 | Type `html`/`inlineHtml` | Décision produit : soit nouveau package `zcrud_html` (`html_editor_enhanced` + `flutter_html` + `ZHtmlCodec`), soit mapping documenté `html→markdown` avec perte assumée. À défaut, laisser en repli explicite + doc de non-parité. |
| B6 | `markdown` vs `inlineMarkdown` + dialog plein-écran | Introduire un paramètre `mode {inline, block}` dans `ZMarkdownField` + un `ZRichTextFullscreenDialog` (`zcrud_markdown/presentation/`) ; helper `registerMarkdownFields(registry)` auto-enregistrant markdown/inlineMarkdown/richText. |
| B7 | `crudDataSelect` dynamique | Livrer le port de source dynamique (« E4 ») : `ZRelationSource` (stream + filtre cross-champ) injecté via `ZWidgetRegistry.register('relation', ...)` dans un binding ; ajouter multi-sélection + modal de recherche à `z_relation_field_widget.dart`. |
| B8 | `subItems` inline vs compact | Ajouter un mode d'affichage `collapsed` (résumé/colonnes + dialog d'édition par item) à `z_sub_list_field_widget.dart` + `ZSubListScreen` (E4-5) ; brancher `ZAcl` par action ; confirmation de suppression. |
| B9 | Geo — barre d'outils | Ajouter `ZGeoEditorToolbarConfig` (`zcrud_geo/domain/`) + rendu boutons undo/clear/my-location/type-carte dans `z_geo_field_widget.dart` (adapters Google/OSM). |
| B10 | `address` schéma | Décider : garder `ZPostalAddress` **et** fournir un `ZAddressCodec` String↔structuré + migration de données ; ajouter seam `ZPlaceSearchProvider` (autocomplete) dans `zcrud_intl`. |
| B11 | `StepperConfig` + nesting | Ajouter `ZStepperConfig` (orientation/style/couleurs/icônes) à `z_stepper_edition.dart` + champ `icon`/`subtitle` sur `ZEditionStep` ; étudier steppers imbriqués (sous-arbres de champs). |
| B12 | Dates bornes min/max | Câbler `ZDateConfig.firstDateKey/lastDateKey` dans `z_date_field_widget.dart:90-96` (résolution cross-champ via controller) + ajouter `minDate/maxDate` littéraux à `ZDateConfig`. |
| B13 | `dateTime` date+heure | Dans `z_date_field_widget.dart`, brancher un picker combiné (showDatePicker→showTimePicker) pour le type `dateTime` ; conserver `time` seul et `date` seul. |
| B14 | `timestamp` sérialisation | Ajouter un hint `@ZcrudField(persistAs: timestamp)` (`zcrud_annotations`/`zcrud_generator`) consommé par l'adaptateur `zcrud_firestore` (String ISO ↔ `Timestamp`), sans faire fuiter `Timestamp` dans `zcrud_core` (AD-5). |

### 🟠 MAJOR

| # | Gap | Action proposée |
|---|---|---|
| M1 | Leading/prefix/suffix par champ | Ajouter slots `prefix/suffix/leading` (icône/texte/kind widget) à `ZFieldSpec` ; consommés par le décor + le wrapper large (B1). |
| M2 | Décor `ZcrudTheme` non câblé | Appliquer `ZcrudTheme` dans `z_text/number/select/relation_field_widget.dart` (InputDecoration : radius, border, padding, filled) ; aligner `radiusM→12`, `fieldPadding→16/16`, ajouter tokens `focusedBorderWidth`, `helperMaxLines`, `floatingLabelBold`. |
| M3 | `showIfNull` défaut inversé | Inverser le défaut de `ZFieldSpec.showIfNull` à `false` (`z_field_spec.dart:82`) OU imposer un audit champ par champ à la migration. |
| M4 | Rendu vue lecture dédié | Créer un décorateur « fiche » (Card label/valeur + copie presse-papier) activé en mode readOnly global, dispatché dans `z_field_widget.dart` au lieu de réutiliser le widget d'édition. |
| M5 | Style label + `*` requis | Ajouter un `label(context)` enrichi (style thémé + astérisque rouge si requis & !readOnly) partagé par les familles text/number/select/relation. |
| M6 | `hintText`/`helperText` | Ajouter `hintText/helperText` à `ZFieldSpec` + projection générateur ; consommer dans les familles + token `helperMaxLines`. |
| M7 | ACL édition | Étendre `ZAcl`/`ZCrudAction` (copy/archive/publish/clear/validate/history) + consommer côté `DynamicEdition`/`z_sub_list_field_widget.dart` via `aclBuilder`. |
| M8 | `select` modal/multi/CRUD inline | Enrichir `z_select_field_widget.dart` (modal recherche, sous-titre/disabled par choix) + variante multi chips ; bouton CRUD inline sur `relation`. |
| M9 | Validateur téléphone Togo | Ajouter un `ZValidatorKind.phoneNational(prefixes, length)` ou validateur custom en config `zcrud_intl` ; documenter la recréation. |
| M10 | Politique mot de passe | Exposer `ZValidatorSpec.password(minLength, maxLength, requireUpper, requireLower, requireDigit, requireSpecial)` mappable sur la politique DODLP (8-20, maj+min, pas de chiffre). |
| M11 | Validateurs « format seul » | Reclasser `address`/`percentage` en no-op de validation (hint de clavier uniquement) OU rendre la contrainte opt-in, pour éviter le rejet de valeurs DODLP valides. |
| M12 | Validation par étape stepper | Rendre le gate `_next()` **configurable** (`validateOnNext: bool`, défaut permissif pour parité DODLP) dans `z_stepper_edition.dart`. |
| M13 | Geo — style des formes / polyline / metadata | Ajouter `ZGeoShapeStyle` + géométrie `polyline` + `holes/metadata/id` à `ZGeoShape` (`zcrud_geo`). |
| M14 | `color` picker riche | Enrichir `z_color_field_widget.dart` (roue HSV/hex/opacité/recent/multi) ou intégrer un adapter picker injectable. |
| M15 | `signature` format | Fournir un `ZSignatureCodec` strokes↔PNG (rasterisation) pour compat données DODLP existantes + consommation PDF/tiers. |
| M16 | Stepper métadonnées par champ | Ajouter `icon`/`subtitle` à `ZEditionStep` + projection générateur depuis `stepIndex/stepIcon` DODLP. |
| M17 | `number` devise/pourcentage | Câbler `ZNumberConfig.isCurrency/isPercentage` dans `z_number_field_widget.dart` (formatage lecture + suffixe `(en %)`). |
| M18 | `subItems` CRUD + confirmation/restore | Ajouter confirmation de suppression, soft-delete/restore, `popUpMenuOptions` (gabarits de création) à `z_sub_list_field_widget.dart`. |
| M19 | `dynamicItem` gabarits | Ajouter `defaultNewItem`/`createNewText` + `subItemsFormFieldsBuilder(state)` dynamique. |
| M20 | Delta↔HTML + embed image/vidéo + toolbar configurable + dialog fullscreen | Regrouper dans l'effort `zcrud_html`/enrichissement `zcrud_markdown` (voir B5/B6). |
| M21 | `timestamp` type catalogue | Couvert par B14. |
| M22 | `select` choix dynamiques (`stateChoiceItems`) | Documenter le recalcul de `choices` côté appelant à chaque rebuild + éventuel seam `choicesBuilder`. |
| M23 | `inlineMarkdown`/`markdown` wiring | Couvert par B6 (helper d'enregistrement). |
| M24 | `stepper` type catalogue | Couvert par B11. |

### 🟡 MINOR (regroupés)

Span pixel-fidelity ; colocalisation span (test de cohérence clés `layout`) ; `withSpaceer` type-dépendant ; LaTeX bloc/inline + aperçu live + fallback SVG ; éditeur tableau riche ; table des pertes Markdown ; minLines/maxLines rich-text ; limite caractères/spellcheck ; styles Quill thémés ; `text`→`multiline` mapping ; `time` Map↔ISO ; `color` recentColors ; `widget` indirection registry ; `address`/`addressSearchField` mapping n:1 ; geo holes ; slider défauts 0..100 ; file config par type ; dates effacement valeur ; `stateValidators` ; persistance repli sections ; `enableFeadback` ; accès controller externe→`valueOf` ; thème mapping ; espacement densité.

---

## 4. Déjà à parité (rassurant)

- **Réactivité granulaire (objectif n°1)** : `ZFormController`/`ValueListenable` par tranche, rebuild ciblé, SM-1 (y compris imbriqué dans sub-lists). **Supérieur** au refresh global DODLP.
- **Dirty-tracking + discard-guard** : par tranche (plus robuste que le fingerprint JSON DODLP) + `ZDiscardGuard`.
- **Soumission agrégée** : `ZEditionSubmitController` (Either/ZFailure, garde anti-double-submit, markPristine).
- **Validation inter-champs `match`** : `ZCrossFieldValidator` (`matchKey`), confirmé sur auth réel.
- **Grille responsive 12 colonnes** : breakpoints Bootstrap identiques (576/768/992/1200), cascade mobile-first, fallback Column.
- **Sections repliables** + **thème sémantique injectable** (`ZcrudTheme`/AD-6, remplacement voulu des constantes figées).
- **Types champ de base fidèles** : integer/boolean/dateTime/rowChips/radio/file/image/document/rating/slider/signature(UX)/phoneNumber/country/location/dynamicItem/tags.
- **types morts DODLP mieux traités** : icon/password/hidden/checkbox (default→EmptyContainer côté DODLP) sont correctement implémentés côté zcrud.
- **Champs bornes croisées** : `ZValidatorSpec.refKey` (min/max/match).
- **`rating.max`** configurable (vs hardcodé 5 DODLP) ; **`country`** fonctionnel (vs onSelect vide DODLP) ; **`file`** via seams injectables.
- **`bmad` codegen `choices` runtime** : `ZFieldSpec.choices` alimentable dynamiquement (équivalent `enum.values.map`).

> ⚠️ Réserves de vérification : (1) confirmer si le câblage runtime `relation` « E4 » a été livré ; (2) confirmer l'existence de l'adaptateur `timestamp` dans `zcrud_firestore` ; (3) test pixel-fidelity de la grille responsive ; (4) support polygone/cercle complet de `ZGeoFieldWidget`.
