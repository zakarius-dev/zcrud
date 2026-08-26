# Capacités du socle zcrud — aire « Édition : champs, sections, sous-listes, thème, texte riche »

**Relevé du 2026-08-26.** Socle mesuré à **v3.21.0** (les sept paquets du périmètre portent tous
`version: 3.21.0` — `packages/<pkg>/pubspec.yaml`). Tout `fichier:ligne` est relatif à
`/home/zakarius/DEV/zcrud/packages/`.

Ce document catalogue **ce que le socle sait faire aujourd'hui**, canal public par canal public. Il
ne dit rien de ce que l'hôte fait ou ne fait pas : c'est le travail des agents de confrontation.

## Méthode et limites de ce relevé

- Source primaire : les **barrels** (`lib/<pkg>.dart`) — l'API publique EST ce qu'ils exportent — et
  les **CHANGELOG.md**, plus explicites que le code sur les canaux récents.
- Datation des canaux : par **diff de tags git** (`git diff --stat v3.12.0..v3.21.0 -- packages/*/lib`),
  pas par lecture du texte des CHANGELOG. Le tableau de la §9 est donc mesuré, non recopié.
- **Aucun test n'a été lancé**, dans aucun dépôt. Aucun fichier n'a été écrit hors de ce dossier.
- Ce relevé **n'a pas ouvert les 22 659 lignes** de `zcrud_core/lib/src/presentation/edition/` ligne à
  ligne. Les canaux sont catalogués par leur **déclaration** (`final`/`typedef`/`enum`/`static`) et
  par la dartdoc du point de déclaration. Là où le comportement n'a pas été lu jusqu'au site de
  consommation, la §8 le dit comme un **soupçon**, jamais comme un fait.
- Le relevé `docs/analyses/iffd-migration-2026-08-25/` n'a servi de preuve pour **aucune** ligne
  ci-dessous : il est marqué périmé et interrompu par son propre `OBSOLETE.md`.

## Vue d'ensemble chiffrée (mesurée)

| Grandeur | Valeur | Où c'est compté |
|---|---|---|
| Paquets du périmètre | 7 | `zcrud_core`, `zcrud_select`, `zcrud_field_extras`, `zcrud_markdown`, `zcrud_html`, `zcrud_media`, `zcrud_document` |
| `export` du barrel `zcrud_core` | **89** | `zcrud_core/lib/zcrud_core.dart` |
| `export` de `domain.dart` / `edition.dart` | 65 / 14 | `zcrud_core/lib/domain.dart`, `zcrud_core/lib/edition.dart` |
| Fichiers Dart de `zcrud_core/lib` | 160 | `find zcrud_core/lib -name '*.dart' \| wc -l` |
| Valeurs de `EditionFieldType` | **46** | `zcrud_core/lib/src/domain/edition/edition_field_type.dart:38-213` |
| Paramètres de `ZFieldSpec` | **23** | `zcrud_core/lib/src/domain/edition/z_field_spec.dart:88-233` |
| Seams de `ZcrudScope` | **25** | `zcrud_core/lib/src/presentation/zcrud_scope.dart:110-320` |
| Jetons publics de `ZcrudTheme` | **220** (dont **107 d'édition**) | `zcrud_core/lib/src/presentation/theme/z_theme.dart:594-2404` |
| Clés de libellés (tables `en` / `fr`) | **123 / 123** | `zcrud_core/lib/src/presentation/l10n/z_localizations.dart:24-366` |
| Paramètres de `ZSubListConfig` | 15 | `zcrud_core/lib/src/domain/edition/z_sub_list_config.dart:175-427` |
| Seams de `ZSubListSeams` | 14 | `zcrud_core/lib/src/presentation/edition/z_sub_list_seams.dart:925-1020` |
| Paramètres de `ZRichTextToolbarConfig` | 36 | `zcrud_markdown/lib/src/presentation/z_rich_text_toolbar_config.dart:80-241` |
| Propriétés de `ZRichTextStyleSet` | 33 | `zcrud_markdown/lib/src/presentation/z_rich_text_style_set.dart:113-213` |
| Paramètres de `ZSelectTileSpec` | 24 | `zcrud_select/lib/src/presentation/z_select_tile_reference.dart:302-406` |

**Volume de ce catalogue** : **264 lignes de canal** réparties sur 22 tableaux (§1 à §7), plus
21 pièges (§8) et 9 lignes de datation (§9). Une ligne peut porter plusieurs symboles nommés
(« 12 jetons `read*` » = une ligne, douze canaux) : le catalogue couvre donc plus de canaux qu'il
n'a de lignes.

**Répartition des 220 jetons de `ZcrudTheme`** (classée par préfixe de nom, comptage mécanique) :
`champ/décoration` 26 · `subList*` 21 · `select*` 12 · `read*` 12 · `editionSheet*`/`editionChrome*` 9 ·
`booleanPill*` 9 · ornement/accent 6 · `large*` 6 · `stepper*` 5 · `dateFieldDecorated` 1 —
**107 jetons d'édition**. Les 113 autres servent l'étude/hub (80), le chat (20) et la carte générique (13).

---

## 1. `zcrud_core` — le moteur déclaratif

### 1.1 Déclarer un champ : `ZFieldSpec` et ses configs

Un hôte décrit un champ par une donnée `const`, jamais par un widget.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient | Défaut |
|---|---|---|---|
| `ZFieldSpec` (23 paramètres) | `zcrud_core/lib/src/domain/edition/z_field_spec.dart:47` | La déclaration unique d'un champ : elle alimente le formulaire, la liste et la cellule | — |
| `.name` / `.type` / `.label` | `…/z_field_spec.dart:88,91,95` | Identité de tranche, famille de rendu, libellé | `label` ⇒ `name` |
| `.validators` | `…/z_field_spec.dart:99` | Validation déclarative (21 `ZValidatorKind`) | `const []` |
| `.config` | `…/z_field_spec.dart:102` | La config typée de la famille (§1.1b) | `null` |
| `.choices` | `…/z_field_spec.dart:105` | Options statiques d'un `select`/`radio`/`checkbox`/`rowChips` | `const []` |
| `.condition` | `…/z_field_spec.dart:109` | Visibilité conditionnelle (16 opérateurs, 3 sources) | `null` |
| `.searchable` | `…/z_field_spec.dart:112` | Le champ entre dans la recherche de liste | `false` |
| `.defaultValue` | `…/z_field_spec.dart:127` | Valeur d'amorçage de la tranche absente d'`initialValues` | `null` — **piège P-06** |
| `.readOnly` / `.showIfNull` / `.multiple` / `.isId` | `…/z_field_spec.dart:130,141,144,147` | Lecture seule statique, affichage si nul, multi-valeur, clé | — |
| `.fieldSize` | `…/z_field_spec.dart:153` | `normal` (inline) ou `large` (carte, libellé au-dessus, champ « bare ») | `normal` |
| `.readLayout` | `…/z_field_spec.dart:165` | Forme de consultation par champ (5 formes) | `null` ⇒ scope/thème |
| `.leading` / `.prefix` / `.suffix` | `…/z_field_spec.dart:170,174,180` | Trois slots d'ornement (`ZFieldAdornment`) | `null` |
| `.hintText` / `.helperText` | `…/z_field_spec.dart:184,188` | Texte d'aide (littéral ou clé l10n) | `null` |
| `.derivedFrom` | `…/z_field_spec.dart:200` | Dérivation depuis d'autres champs (5 cibles, §1.9) | `null` |
| `.widgetKind` | `…/z_field_spec.dart:219` | Clé de registre pour un widget servi ailleurs | `null` ⇒ `type.name` |
| `.choicesResolver` | `…/z_field_spec.dart:233` | Résolveur d'options en closure | `null` |

#### 1.1b Configs typées par famille — `ZFieldConfig`

Toutes dans `zcrud_core/lib/src/domain/edition/z_field_config.dart` (994 lignes).

| Config | Ligne | Paramètres notables |
|---|---|---|
| `ZTextConfig` | `:59` | `minLines:70`, `maxLines:73`, **`keyboardType:101`** (table fermée, chaîne inconnue ⇒ repli par `maxLines`), **`capitalization:105`** (`ZTextCapitalization` `:35`, dont `lowercase` déterministe collage compris), **`textTransform:147`** |
| `ZNumberConfig` | `:168` | **`minValueKey:185` / `maxValueKey:189`** (bornes lues sur un autre champ, revalidation ciblée), `isCurrency:192`, `isPercentage:195`, `currencySymbol:202` |
| `ZColorConfig` | `:236` | `enableAlpha:258`, `showPalette:261`, `showRecent:264`, `recentColors:268`, `multiple:274` |
| `ZSliderConfig` | `:300` | `min:306`, `max:309`, `divisions:312` |
| `ZRatingConfig` | `:330` | `max:335` |
| `ZBooleanConfig` | `:381` | `showStateLabel:400`, `trueLabel:404`, `falseLabel:408`, `style:412` (`ZBooleanStyle` `:487`), `activeColorKey:420`, `inactiveColorKey:425`, `boxed:443` |
| `FileFieldConfig` | `:532` | `acceptedExtensions:549`, `acceptedMimeTypes:553`, `maxFiles:556`, `maxSizeBytes:560`, `allowedSources:563` (`ZFileSource` `:502`), `allowedDocumentTypes:574`, `imageFallback:580` |
| `ZSelectConfig` | `:657` | `searchable:671`, `modalThreshold:676`, `choicesFromKey:682`, `choicesSourceKey:688`, **`choiceBuilderKey:693`** (rendu riche d'option par clé), `filterKeys:698`, `radioAsModal:704` |
| `ZRelationConfig` | `:746` | `sourceKey:757`, `filterKeys:763`, `searchable:767`, **`crudKey:772`** (CRUD inline de l'entité liée) |
| `ZDateConfig` | `:852` | `firstDateKey:865` / `lastDateKey:868` (bornes par champ), `minDateIso:871` / `maxDateIso:874`, `mode:878` (`ZDateMode` `:809`), `maxDays:912` / `minDays:928` (`ZDateSpanVerdict` `:825`) |
| `ZSubListConfig` | `z_sub_list_config.dart:154` | cf. §1.5 |
| `ZStepFieldConfig` | `presentation/edition/z_step_partition.dart:73` | Annote un `ZFieldSpec` plat pour le regrouper en étapes |

**Un hôte qui veut X écrit Y** : pour un champ téléphone à clavier numérique et libellé en majuscules
initiales, il écrit `ZFieldSpec(name:…, type: EditionFieldType.text, config: ZTextConfig(keyboardType: 'phone',
capitalization: ZTextCapitalization.words))` — aucun widget, aucun `TextInputType` importé.

#### 1.1c Autres types-valeur de déclaration

| Canal | `fichier:ligne` | Ce qu'il permet |
|---|---|---|
| `ZValidatorSpec` + 21 `ZValidatorKind` | `…/z_validator_spec.dart:114` / `:17` | `required`, `requiredIf`, `minLength`, `maxLength`, `min`, `max`, `equal`, `notEqual`, `match`, `email`, `url`, `ip`, `creditCard`, `phone`, `numeric`, `integer`, `dateString`, `address`, `percentage`, `password`, `pattern` ; 17 champs de paramétrage (`:324-380`) dont la politique de mot de passe granulaire (`:346-366`) et `condition:380` |
| `ZCondition` + 16 `ZConditionOp` | `…/z_condition.dart:111` / `:51` | `equals`, `notEquals`, `isNull`, `notNull`, `truthy`, `and`, `or`, `not`, `isEmpty`, `isNotEmpty`, `lengthEquals`, `lengthGt/Gte/Lt/Lte`, `contains` — sur 3 `ZValueSource` (`:39`) : `state`, `persisted`, `context` |
| `ZConditionEvaluator` | `…/z_condition_evaluator.dart` (296 l.) | Évaluation pure et totale |
| `ZFieldChoice` | `…/z_field_choice.dart:22` | `value`, `label`, `subtitle`, `disabled` |
| `ZFieldAdornment` (+ `ZAdornmentKind`) | `…/z_field_adornment.dart:36` / `:23` | Ornement pur-données `text`/`icon`/`widget` ; **`onTap:75`** rend l'ornement actionnable |
| `ZFieldSize` | `…/z_field_size.dart:17` | `normal` / `large` |
| `ZReadFieldLayout` (5 formes) | `…/z_read_field_layout.dart:29` | Forme de consultation ; `card` est la seule entièrement paramétrable |
| `ZFieldTintPresets.classic` (15 entrées) | `…/z_field_tint_presets.dart:73` | Palette **copiable** de teintes par type — **jamais lue par le socle** (dartdoc `:13-15`) |
| `ZDateRange` | `…/z_date_range.dart:1` | Valeur de tranche d'un `dateRange` |
| `ZTimeCodec` | `…/z_time_codec.dart` | Encodage de l'heure |
| `ZPathValues` | `…/z_path_values.dart` | Valeurs par chemin (sous-listes) |
| `ZFieldRename` | `…/z_field_rename.dart:15` | Convention de renommage à la persistance |

### 1.2 Catalogue des 46 types et routage vers les familles

`EditionFieldType` : `edition_field_type.dart:38-213`. La classification est un `switch` **exhaustif
sans `default:`** — `familyOf` : `presentation/edition/edition_field_family.dart:121`.

| Famille (`EditionFamily`, `edition_field_family.dart:38`) | Types routés | Widget servi |
|---|---|---|
| `text` `:40` | `text`, `multiline`, `password` | `ZTextFieldWidget` (`families/z_text_field_widget.dart:34`) |
| `number` `:43` | `number`, `integer`, `float` | `ZNumberFieldWidget` (`families/z_number_field_widget.dart:37`) |
| `date` `:46` | `dateTime`, `time` | `ZDateFieldWidget` (`families/z_date_field_widget.dart:56`) |
| `dateRange` `:50` | `dateRange` | `ZDateRangeFieldWidget` (`families/z_date_range_field_widget.dart:115`) |
| `boolean` `:54` | `boolean` | `ZBooleanFieldWidget` (`families/z_boolean_field_widget.dart:188`) |
| `select` `:57` | `select`, `radio`, `checkbox` | `ZSelectFieldWidget` (`families/z_select_field_widget.dart:45`) |
| `relation` `:60` | `relation` | `ZRelationFieldWidget` (`families/z_relation_field_widget.dart:50`) |
| `tags` `:63` | `tags` | `ZTagsFieldWidget` (`families/z_tags_field_widget.dart:28`) |
| `rowChips` `:66` | `rowChips` | `ZRowChipsFieldWidget` (`families/z_row_chips_field_widget.dart:44`) |
| `rating` `:69` | `rating` | `ZRatingFieldWidget` (`families/z_rating_field_widget.dart:22`) |
| `slider` `:72` | `slider` | `ZSliderFieldWidget` (`families/z_slider_field_widget.dart:20`) |
| `color` `:75` | `color` | `ZColorFieldWidget` (`families/z_color_field_widget.dart:50`) + `ZColorMultiFieldWidget` (`…z_color_multi_field_widget.dart:42`) |
| `subList` `:79` | `subItems` | `ZSubListFieldWidget` (`families/z_sub_list_field_widget.dart:188`, **4 202 lignes**) |
| `dynamicItem` `:83` | `dynamicItem` | `ZDynamicItemFieldWidget` (`families/z_dynamic_item_field_widget.dart:63`) |
| `signature` `:88` | `signature` | `ZSignatureFieldWidget` (`families/z_signature_field_widget.dart:64`) + `ZSignatureCodec` (`…z_signature_codec.dart:78`) |
| `freeWidget` `:94` | `widget` | `ZFreeWidgetFieldWidget` (`families/z_free_widget_field_widget.dart:43`), sinon repli |
| `registryOrFallback` `:99` | `markdown`, `inlineMarkdown`, `html`, `inlineHtml`, `richText`, `location`, `geoArea`, `phoneNumber`, `country`, `address`, `icon`, `pin`, `autocomplete`, `editableTable`, `mediaImage`, `mediaFile`, `mediaVideo`, `custom` (**18 types**) | Le `ZWidgetRegistry` injecté, sinon `ZUnsupportedFieldWidget` |
| `file` `:110` | `file`, `image`, `document` | `ZAppFileField` (`families/z_app_file_field_widget.dart:72`) |
| `hidden` `:113` | `hidden` | `SizedBox.shrink` |
| `unsupported` `:117` | **`stepper` seul** | `ZUnsupportedFieldWidget` (`families/z_unsupported_field_widget.dart:26`) |

Dispatcher : `ZFieldWidget` (`presentation/edition/z_field_widget.dart:88`, 1 114 lignes) — réutilise
la tranche du champ, ne recrée jamais son contrôleur.

### 1.3 Le formulaire : `DynamicEdition`, sections, grille

| Canal | `fichier:ligne` | Ce qu'un hôte obtient | Défaut |
|---|---|---|---|
| `DynamicEdition` | `presentation/edition/dynamic_edition.dart:296` | Le formulaire de référence : `ListView.builder`, écoute **structurelle** seule, place stable par `KeyedSubtree` | — |
| `.controller` / `.fields` | `:324,327` | L'état et le schéma | requis |
| `.sections` | `:344` | Groupement visuel | `const []` |
| `.padding` / `.shrinkWrap` / `.physics` | `:347,350,353` | Enveloppe de défilement | — |
| `.fieldBuilder` | `:360` | Échappatoire totale de rendu par champ | `null` |
| `.readOnly` / `.readLayout` | `:374,386` | Bascule consultation + forme | `false` |
| `.layout` / `.gridGutter` / `.gridRunGutter` | `:390,394,401` | Grille responsive 12 colonnes par champ | — |
| `.conditionContext` | `:413` | Le contexte lu par `ZValueSource.context` | `const {}` |
| `.manageVisibility` | `:424` | Le formulaire pilote `visibleFields` (single-writer) | `true` |
| `.acl` | `:438` | ACL du formulaire | `null` ⇒ scope |
| `.formActions` | `:446` | Actions d'en-tête filtrées par ACL (`ZFormAction` `:133`) | `const []` |
| `.collectionId` | `:451` | Cible de l'ACL | `null` |
| `.collapseStore` / `.formId` | `:458,462` | Persistance du repli des sections (`ZSectionCollapseStore` `z_section_collapse_store.dart:25`, repli mémoire `:42`) | `null` |
| `.interFieldGap` | `:491` | Espacement inter-champs | `null` ⇒ jeton |
| `.onStructuralBuild` | `:497` | Sonde de rebuild structurel | `null` |
| `ZEditionSection` | `:250` | `title:269`, `fields:273`, `collapsible:276`, `initiallyExpanded:279`, **`icon:284`**, **`style:290`** | — |
| `ZEditionSectionStyle` (9 propriétés) | `:192` | `background:208`, `topAccent:212`, `radius:216`, `titleStyle:219`, `headerPadding:222`, `iconColor:226`, `collapsedIcon:231`, `expandedIcon:235`, **`startRailColor:240` / `startRailWidth:244`** (filet vertical côté début, directionnel) | tout `null` ⇒ arbre inchangé |
| `ZResponsiveGrid` / `ZResponsiveSpan` / `ZBreakpoint` | `z_responsive_grid.dart:177` / `:96` / `:45` | Spans `xs/sm/md/lg/xl` (`:116-128`) ; seuils 576/768/992/1200 (`ZResponsiveBreakpoints:66-77`) | — |
| `zUnknownLayoutKeys` | `z_responsive_grid.dart:33` | Détecter une clé de `layout` qui ne correspond à aucun champ | — |
| `zFieldGapAfter` | `dynamic_edition.dart:105` | L'espacement que le socle pose après un type donné | — |

### 1.4 Sous-listes (`subItems`) — le plus gros chantier récent

**Config** — `zcrud_core/lib/src/domain/edition/z_sub_list_config.dart` (695 lignes).

| Canal | Ligne | Ce qu'un hôte obtient | Défaut |
|---|---|---|---|
| `ZSubListConfig` | `:154` | Mini-CRUD imbriqué déclaratif | — |
| `.itemFields` | `:175` | Le schéma d'un item (récursif : un `subItems` peut en contenir un) | requis |
| `.reorderable` | `:200` | Contrôles d'ordre ; **`bool?` depuis 3.13.0** (`null` = historique) | `null` |
| `.displayMode` | `:228` | `ZSubListDisplayMode` (`:85`) : `inline`, `compact`, `tags` | `inline` |
| `.showViewAction` / `.showEditAction` / `.showDeleteAction` | `:238,243,250` | **Préférence** d'affichage des actions de ligne — « montré = permis (ACL) **et** préféré » | `true` |
| `.summaryFields` | `:259` | Colonnes du résumé compact ; un nom de sous-liste y rend son **compte** | `const []` |
| `.summaryColumns` | `:294` | Colonnes typées (`ZSubListSummaryColumn` `:509` : `name`, `labelKey`, `labelFallback`, `decimals`, `suffixKey`, `suffixFallback`) | `const []` |
| `.softDelete` | `:301` | Corbeille d'item | `false` |
| `.creationTemplates` | `:307` | Modèles de création (`ZSubListItemTemplate` `:597` : `labelKey`, `id`, `defaults`, `opensForm`) | `const []` |
| `.defaultNewItem` | `:338` | Valeurs d'un item neuf | `const {}` |
| `.createNewTextKey` | `:342` | Libellé du contrôle d'ajout | `null` |
| `.aclCollectionId` | `:358` | Collection ACL de la sous-liste | `null` |
| `.showSummaryHeaders` | `:419` | En-têtes de colonnes du résumé | — |
| `.itemFormPresentation` | `:427` | `ZSubItemFormPresentation` (`:130`) : `dialog`, `sheet`, `page` | `dialog` |

**Seams de présentation** — `zcrud_core/lib/src/presentation/edition/z_sub_list_seams.dart` (1 094 l.).
Registre instanciable et chaînable : `ZSubListSeamRegistry:1031` (`parent:1038`, `seamsFor:1070`,
`trySeamsFor:1080`, `resolve:1086`), injecté par `ZcrudScope.subListSeamRegistry`.

| Seam (`ZSubListSeams:902`) | Ligne | Ce qu'un hôte obtient |
|---|---|---|
| `acl` | `:925` | ACL propre à ce champ |
| `itemTitleBuilder` | `:928` | Titre d'un item depuis sa map |
| `itemBuilder` | `:931` | Rendu libre d'une ligne |
| `itemActionsBuilder` | `:934` | Actions supplémentaires par ligne |
| `listViewBuilder` | `:937` | Conteneur de la liste (`ZSubListViewData:203`, dont **`onReorder:247`**) |
| `captionBuilder` | `:940` | Légende du bloc |
| **`headerBuilder`** | `:950` | En-tête complet (`ZSubListHeaderView:290` : `field`, `itemCount`, `addControl`, `onAdd`) |
| `itemTransformer` | `:953` | Transformation d'affichage d'un item |
| `itemFieldsResolver` | `:956` | Sous-champs dynamiques par item |
| `subSchemaResolver` | `:972` | Schéma résolu depuis le parent |
| `creationTemplatesResolver` | `:982` | Modèles de création calculés |
| `itemMenuOptions` | `:996` | Menu d'item (`ZSubItemMenuOption:484` : 8 propriétés dont `destructive:528` et `permission:537`) |
| `onCrud` | `:1003` | Hook CRUD avec **veto** (`ZSubItemCrudRequest:549` / `ZSubItemCrudOutcome:691`, dont `vetoed:732`, `reasonKey:753`, `parentPatch:787`) |
| **`itemBorderColorKey`** | `:1020` | Bordure de ligne **dépendant de l'item** (chaîne seam → `colorKeyResolver` → rôles M3 → `fieldBorderColor`) |

**Glisser-déposer** : la sous-liste consulte le port `ZReorderRenderer`
(`presentation/reorder/z_reorder_renderer.dart:51`) — celui de `ZcrudScope.reorderRenderer`
(`z_sub_list_field_widget.dart:611`), sinon un repli interne zéro-configuration.
`buildDragHandle` (`z_reorder_renderer.dart:91`) a une implémentation par défaut **identité** ;
`ZReorderRenderRequest.dragPreviewWrapper` (`z_reorder_render_request.dart:127`) habille l'aperçu
flotté, qui vit dans l'`Overlay`.

**Widget** : `ZSubListFieldWidget` (`families/z_sub_list_field_widget.dart:188`) + le typedef
`ZSubItemFieldBuilder` (`:180`).

### 1.5 Consultation (mode lecture)

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZReadModeScope` | `presentation/edition/z_read_mode_scope.dart:62` | Le mode de présentation **posé une fois** par `DynamicEdition`/`ZStepperEdition` d'après leur `readOnly`, lu par chaque champ — la consultation ne se perd pas au premier `fieldBuilder` de remplacement. Porte aussi la **forme** (`layout:87`) : un seul canal, jamais deux |
| `.of` / `.layoutOf` / `.maybeOf` | `:100,110,94` | Lecture depuis un widget custom |
| `ZReadOnlyFieldCard` | `presentation/edition/z_read_only_field_card.dart:77` | Rendu d'un champ consulté : `label:94`, `value:97`, `copyText:100` (copie presse-papier accessible), `valueSemantics:108`, `layout:113` |
| `ZReadFieldLayout` (5 formes) | `domain/edition/z_read_field_layout.dart:29` | `card` (défaut, seule entièrement paramétrable) + 4 autres |
| 12 jetons `read*` | `theme/z_theme.dart:817-900` | `readLayout`, `readCardMargin`, `readPadding`, `readLabelGap`, `readLabelTextStyle`, `readValueTextStyle`, `readFillColor`, `readBorderColor`, `readBorderWidth`, `readCardMinHeight`, `readRowLabelWidth`, `readRowMinWidth` |
| `ZLargeFieldCard` | `presentation/edition/z_large_field_card.dart:20` | Décorateur de `ZFieldSize.large` : `label`, `labelWidget`, `child`, `leading`, `suffix` ; mesures par les 6 jetons `large*` (`z_theme.dart:787-803`) |
| `ZFieldLabel` | `presentation/edition/z_field_label.dart:24` | Libellé enrichi partagé (style thémé + astérisque requis), `large:37` |

### 1.6 Ornements, teinte par type, accent

Fichier pivot : `presentation/edition/z_field_adornment_view.dart` (452 lignes).

| Canal | Ligne | Ce qu'un hôte obtient | Condition d'effet |
|---|---|---|---|
| `zFieldDecoration` | `:367` | L'`InputDecoration` complète que le socle pose — utile pour un widget custom qui veut la parité | — |
| `ZAdornmentIconResolver` | `:45` | Résout une clé d'icône neutre en `IconData` (injecté par `ZcrudScope.iconResolver`) | — |
| `zResolveAdornmentIcon` | `:81` | Le même, depuis un `BuildContext` | — |
| `zResolveFieldTint` | `:206` | Teinte du champ, par clé `zFieldTypeTintKey(field.type)` | **`gradientResolver` injecté** |
| `zResolveFieldAccent` | `:218` | Accent, par clé `zFieldAccentKey(field.name)` puis repli sur la teinte de type | idem |
| **`zResolveTintedAdornment`** + `ZTintedAdornment` | `:270` / `:227` | Point d'entrée public pour un **présentateur riche** : teinte normalisée + icône en pastille, prêtes à poser sur une tuile, sans dupliquer la normalisation | idem |
| `zFieldTypeTintKey` / `zFieldAccentKey` | `theme/z_gradient_resolver.dart:20` / `:35` | Les deux conventions de clés (préfixes `:10` et `:24`) | — |
| `ZGradientSpec` / `ZGradientResolver` | `theme/z_gradient_resolver.dart:40` / `:63` | Le seam de dégradé et son DTO (`onGradient` inclus) | — |
| `zDerivedGradientResolver` / `zResolveGradient` | `theme/z_gradient_resolver.dart:86` / `:129` | Résolveur dérivé et lecture depuis le contexte | — |
| 6 jetons ornement/accent | `theme/z_theme.dart:1078-1102` | `adornmentIconBackgroundAlpha`, `adornmentIconBackgroundRadius`, `adornmentIconSize`, `accentBarHeight`, `gradientBegin`, `gradientEnd` | **P-01** |

Toute couleur passée au socle est **normalisée pour le contraste** avant d'être peinte —
`zReadableTintOn` (`theme/z_readable_tint.dart:219`), planchers `kZNonTextMinContrast = 3.0` (`:111`)
et `kZTextMinContrast = 4.5` (`:114`), avec `zRelativeLuminance:140`, `zContrastRatio:153`,
`zCompositeOver:165`. **Domicile unique** du calculateur de contraste du dépôt.

Autres résolveurs de couleur : `ZColorKeyResolver` (`theme/z_color_key_resolver.dart:148`),
`ZColorPair:56`, `ZColorSlot:89`, `zDefaultColorKeyResolver:167`, `zColorSlotPair:184`,
`zResolveColorKey:198`, `zResolveColorKeyOrSlot:217`. Inversion/premier plan :
`ZInvertedSurface` (`theme/z_inverted_surface.dart:77`), `ZForegroundOverride`
(`theme/z_foreground_override.dart:76`). Cycle de teintes : `ZColorCycle`
(`theme/z_color_cycle.dart:107`, palette **et** période **requises**, aucun contrôleur sous
« Réduire les animations »), `zColorCycleAt:75`.

### 1.7 Assistant multi-étapes

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZStepperEdition` | `presentation/edition/z_stepper_edition.dart:271` (2 102 l.) | Partitionne le **même** `ZFormController` en étapes ; réutilise `DynamicEdition` par étape (`:1443`) ; état préservé en va-et-vient ; steppers imbriqués (single-writer racine de `visibleFields`) |
| `ZEditionStep` | `:110` | Descripteur : titre + noms de champs (+ sections) |
| `ZStepFieldBuilder` | `:262` | Rendu par champ, avec le mode d'autovalidation |
| `ZStepperConfig` (17 propriétés) | `z_stepper_config.dart:135` | `orientation:158`, `style:161`, `indicatorPosition:164`, `showLabels:167`, `showSubtitles:171`, `allowStepTap:175`, **`validateOnNext:179`**, `showAllSteps:197`, `stepsDisplay:224`, `indicatorSize:236`, `stepSpacing:239`, `activeColor:242`, `completedColor:245`, `inactiveColor:249`, `errorColor:252`, `railColor:257`, `badgeForegroundColor:263` |
| Enums | `:24,33,53,85` | `ZStepOrientation`, `ZStepStyle`, `ZStepIndicatorPosition`, `ZStepsDisplay` |
| `zPartitionFieldsIntoSteps` + `ZStepPartition` | `z_step_partition.dart:236` / `:167` | Adaptateur **data-driven inline** : une liste PLATE de `ZFieldSpec` annotés (`ZStepFieldConfig:73`) devient `List<ZEditionStep>` par une fonction pure et totale. `ZStepOf:150`, `ZStepTitleFallback:157` |
| 5 jetons `stepper*` | `theme/z_theme.dart:2291-2330` | `stepperRailColor`, `stepperRailThickness`, `stepperBadgeForegroundColor`, `stepperAllStepsGap`, `stepperSideBandMaxWidth` |

⚠️ `EditionFieldType.stepper` reste **délibérément `unsupported`** (`edition_field_family.dart:233`) :
un stepper est un regroupement single-writer, pas un widget-feuille.

### 1.8 État, validation, dérivation, soumission

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZFormController` | `presentation/z_form_controller.dart:33` | `ChangeNotifier` pur-Flutter ; `fieldListenable:123` (une tranche par champ), `valueOf:129`, `setValue:243`, `seedDefaultValue:150`, `baselineValueOf:169`, `isTouched:183`, `recordRemovedFile:207` / `removedFilesOf:219`, `revealErrors:290`, `markPristine:296`, `reset:314`, `reseed:332`, `setVisibleFields:355` |
| `ZFieldListenableBuilder` | `presentation/z_field_listenable_builder.dart:21` | Sceller un widget custom sur une seule tranche |
| `ZEditionField` | `presentation/edition/z_edition_field.dart:56` | Champ hôte scellé sur sa tranche, `TextEditingController` stable, saisie sens unique |
| `ZValidatorCompiler` | `presentation/edition/z_validator_compiler.dart:48` | `ZValidatorSpec[] → FormFieldValidator` mémoïsable (via `form_builder_validators`, **jamais** `flutter_form_builder`) |
| `ZCrossFieldValidator` | `presentation/edition/z_cross_field_validator.dart:45` | Validation inter-champs `match`/`minKey`/`maxKey` en closures capturant le controller ; `zNumberBoundKeysOf:145` |
| `zValidateFormFields` | `presentation/edition/z_form_values.dart:75` | **Voie unique** de validation agrégée (conditionnels honorés) |
| `zNormalizeFormValues` / `zNormalizeFieldValue` | `…/z_form_values.dart:253` / `:123` | Normalisation des saisies avant soumission |
| `zIsFieldActive` | `…/z_form_values.dart:48` | Le champ est-il actif (condition satisfaite) |
| `zRemovedFilesKey` | `…/z_form_values.dart:228` | Convention de clé des fichiers retirés |
| `zIsEmptyValue` / `zValidationText` | `presentation/edition/z_value_emptiness.dart:37` / `:52` | **Règle unique** de vacuité du dépôt — à réutiliser dans un champ custom à valeur structurée plutôt que d'en réinventer une seconde |
| `ZDerivation` (5 cibles) | `domain/edition/z_derivation.dart:201` | `value:221`, `options:224`, `visible:228`, `bounds:231`, **`readOnly:241`** ; `sources:215`, `overwrite:218` (`ZDerivationOverwrite:26`), bornes `ZFieldBounds:44`, préfixe de clé `$zderived` (`:93`), détection de cycles (`:265-310`) |
| `ZDerivationEngine` | `presentation/edition/z_derivation_engine.dart:37` | Le moteur qui applique les dérivations |
| `ZEditionSubmitController<T>` | `presentation/edition/z_submission.dart:176` | Validation agrégée **toutes-étapes** (`fields` = catalogue complet, `:192`), seam `onSubmit` en `Either<ZFailure,T>` (`ZOnSubmit:161`), états `ZSubmissionState:76` / `ZSubmissionStatus:60`, ré-entrance ignorée (`:218`), exception enveloppée en `ZServerFailure` (`:236`) |
| `ZValidationFailure` | `…/z_submission.dart:36` | L'échec de validation typé |
| `ZSubmitButton<T>` | `presentation/edition/z_submit_button.dart:24` | Chrome accessible scellé sur l'état |
| `ZDiscardGuard` + `ZConfirmDiscard` | `presentation/edition/z_discard_guard.dart:27` / `:24` | Garde de sortie type `PopScope`, **aucune dépendance de routing** |

### 1.9 `ZcrudScope` — les 25 seams

`presentation/zcrud_scope.dart:75`. `of:544`, `maybeOf:557`, **`derive:478`** (dérivation d'un scope
enfant avec sentinelle `_zScopeUndefined:46` — un paramètre omis n'écrase pas le parent).

| Seam | Ligne | Ce qu'un hôte branche | Défaut |
|---|---|---|---|
| `resolver` | `:110` | Injection de dépendances (`ZDependencyResolver`, `z_dependency_resolver.dart:19`) | throw actionnable |
| `acl` | `:117` | Droits (`ZAcl`, `domain/ports/z_acl.dart:101` ; `ZAllowAllAcl:123`, `ZDenyAllAcl:177`, `ZRestrictedAcl:210`, `zRestrictAcl:247`) | permissif |
| `labels` | `:120` | Registre de libellés (`ZcrudLabels`, `l10n/z_labels.dart:20`) | `null` |
| `theme` | `:123` | `ZcrudTheme` prioritaire sur le `ThemeExtension` | `null` |
| `widgetRegistry` | `:128` | Widgets d'édition servis ailleurs | `null` |
| `subListSeamRegistry` | `:144` | Seams de sous-liste | `null` |
| `relationSourceRegistry` | `:152` | Sources dynamiques de `relation` | `null` |
| `choicesSourceRegistry` | `:160` | Options calculées de `select` | `null` |
| `selectChoiceBuilderRegistry` | `:164` | Rendus riches d'options par clé | `null` |
| `relationCrudRegistry` | `:172` | CRUD inline de l'entité liée | `null` |
| `filePicker` | `:177` | Acquisition de fichiers (`ZFilePicker`, `edition/z_file_picker.dart:20`) | `null` |
| `cloudStorage` | `:183` | Upload/états (`CloudStorageRepository`) | `null` |
| `appFileResolver` | `:199` | Référence opaque → `AppFile` | `null` |
| `listRenderer` | `:208` | Rendu de liste | `null` |
| **`reorderRenderer`** | `:219` | Châssis de réordonnancement | repli interne |
| `dropRegionRenderer` | `:229` | Zone de dépôt native (`dnd/z_drop_region_renderer.dart:38` ; défaut `ZNoDropRegionRenderer:57`) | inerte |
| `selectPresenter` | `:239` | Présentation riche des familles de sélection | rendu natif |
| `iconResolver` | `:246` | Clé d'icône → `IconData` | `null` |
| `colorPicker` | `:253` | Sélecteur de couleur (`ZColorPicker`, `families/z_color_field_widget.dart:42`) | dialogue interne `ZColorPickerDialog:286` |
| `colorKeyResolver` | `:272` | Clé de couleur → paire (fond/premier plan) | rôles M3 |
| `gradientResolver` | `:276` | Clé → dégradé/teinte | `null` ⇒ **aucune teinte** |
| `richTextRenderer` | `:286` | Port de rendu rich-text (`z_rich_text_renderer.dart:37`) | `null` |
| `dateDisplayFormatter` | `:296` | Formatage d'affichage des dates | chaîne brute |
| `numberDisplayFormatter` | `:308` | Formatage d'affichage des nombres | rendu inchangé |
| **`defaultTextConfig`** | `:320` | `ZTextConfig` par défaut du sous-arbre (précédence **champ > scope**) | `null` |

### 1.10 `ZcrudTheme` — 220 jetons, chaîne de résolution

`theme/z_theme.dart:323`. Résolution (`:2553`) : **`ZcrudScope.theme` → `Theme.of(context).extension<ZcrudTheme>()`
→ `ZcrudTheme.fallback(Theme.of(context))`**.

Jetons d'édition, par famille (107 au total) :

| Famille | Lignes | Jetons |
|---|---|---|
| Champ / décoration (26) | `:594-782` | `fieldBorderColor`, `fieldFillColor`, `fieldFocusedBorderColor`, `errorColor`, **`onErrorColor`** (3.5.0), `labelColor`, `surfaceColor`, `gapS/M/L`, `radiusS/M`, `badgeRadius`, `fieldPadding`, `formPadding`, `fieldGap`, `inputRadius`, `inputBorderWidth`, `inputFocusedBorderWidth`, `inputContentPadding`, `inputFilled`, `helperMaxLines`, `floatingLabelWeight`, `labelTextStyle`, `inputTextStyle`, `hintTextStyle` |
| `dateFieldDecorated` (1) | `:644` | Le champ date porte-t-il la décoration |
| `large*` (6) | `:787-803` | `largeMinHeight`, `largePadding`, `largeLabelTextStyle`, `largeLeadingIconSize`, `largeLeadingGap`, `largeLabelGap` |
| `read*` (12) | `:817-900` | cf. §1.5 |
| `subList*` (21) | `:916-1066` | `subListColumnMinWidth`, `subListActionIconSize`, `subListViewActionColor`, `subListEditActionColor`, `subListDeleteActionColor`, `subListAddControlColor`, `subListAddControlGradient`, `subListAddControlRadius`, `subListAddControlSize`, `subListAddControlIconColor`, **`subListDragHandleIcon:969`**, **`subListDragHandleSize:979`**, **`subListDragHandleColor:983`**, **`subListCaptionTopPadding:993`**, **`subListHeaderTopPadding:1001`**, **`subListRowVerticalPadding:1012`**, **`subListRowHorizontalPadding:1026`**, **`subListRowInnerPadding:1041`**, **`subListCellVerticalPadding:1049`**, **`subListTableVerticalMargin:1057`**, **`subListBlockEndPadding:1066`** |
| ornement / accent (6) | `:1078-1108` | cf. §1.6 |
| `editionSheet*` / `editionChrome*` (9) | `:2005-2089` | `editionSheetFrameMode`, `editionSheetWidthRatio`, `editionSheetMaxWidth`, `editionSheetBorderColor`, `editionSheetBorderWidth`, `editionChromeMinTouchTarget`, `editionChromeHeaderPadding`, `editionChromeActionBarPadding`, `editionChromePageHeaderExpandedHeight` |
| `select*` (12) | `:2157-2275` | `selectTileBorderColor`, `selectTileBorderWidth`, `selectTileRadius`, `selectTileMinHeight`, `selectDialogBreakpoint`, `selectMonoChoiceStyle`, `selectMultiChoiceStyle`, `selectModalShape`, **`selectSummaryMaxChips:2255`**, **`selectSummaryChipRadius:2262`**, **`selectSummaryChipPadding:2268`**, **`selectSummaryChipFontSize:2275`** |
| `stepper*` (5) | `:2291-2330` | cf. §1.7 |
| `booleanPill*` (9) | `:2352-2404` | `booleanPillActiveColor`, `booleanPillInactiveColor`, `booleanPillActiveForegroundColor`, `booleanPillInactiveForegroundColor`, `booleanPillWidth`, `booleanPillHeight`, `booleanPillThumbSize`, `booleanPillRadius`, `booleanPillTextStyle` |

Douze enums de thème accompagnent ces jetons (`:29,54,88,110,127,144,173,192,215,235,264,306`) — la
plupart hors aire d'édition.

### 1.11 Localisation

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZcrudLocalizations` + `ZcrudLocalizationsDelegate` | `l10n/z_localizations.dart:373` / `:407` | Delegate générique, tables `en` (`:24`) et `fr` (`:209`), **123 clés chacune** |
| `ZcrudLabels` | `l10n/z_labels.dart:20` | Registre de surcharge par l'hôte : `maybeResolve:36`, `resolve:39` |
| `label(context, key)` | exporté par `l10n/z_labels.dart` | Le helper de lecture |
| `ZCrudTitles` | `presentation/z_crud_titles.dart:24` | Titres d'écran CRUD |

Clés d'édition ajoutées récemment : `'choiceUnresolved'` (`:172`/`:342`),
`'selectSummaryOverflow'` (`:67`/`:249`), et les quatre du chrome rich-text compact
`'z.markdown.write'` / `'z.markdown.edit'` / `'z.markdown.commit'` / `'z.markdown.expand'`
(`:200-203` en `en`, `:360-363` en `fr`).

### 1.12 Registres et ports d'édition

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZWidgetRegistry` | `presentation/edition/z_widget_registry.dart:194` | Registre **instanciable et chaînable** (`parent:202`), `isRegistered:223` ; une collision de `kind` **`throw`** |
| `ZFieldWidgetContext` | `…/z_widget_registry.dart:123` | `field:133`, `value:136`, `onChanged:142`, `valueOf:153` — le contrat d'un widget servi par registre |
| `ZFieldWidgetBuilder` | `…/z_widget_registry.dart:161` | La signature à fournir |
| `ZSelectPresenter` | `presentation/edition/z_select_presenter.dart:245` | Seam Material-free de présentation riche des familles de sélection |
| `ZSelectPresentation` | `…/z_select_presenter.dart:131` | Le DTO neutre passé au présentateur |
| `ZSelectOptionsQuery` / `ZSelectOptionsLoader` | `:31` / `:56` | Chargement asynchrone d'options |
| `ZSelectChoiceContext` / `ZSelectChoiceBuilder` / `ZSelectChoiceSecondaryBuilder` | `:71` / `:99` / `:111` | Rendu riche d'une option |
| `ZSelectChoiceBuilderRegistry` / `ZSelectChoiceBuilders` | `presentation/edition/z_select_choice_builder_registry.dart:35` / `:17` | Clé `const` dans `ZSelectConfig.choiceBuilderKey`, fermeture dans l'hôte, repli natif si la clé ne résout rien |
| `ZChoicesSource` + `ZChoicesSourceRegistry` | `domain/ports/z_choices_source.dart:40` / `:65` | Options calculées **synchrones** |
| `ZRelationSource` + `ZRelationSourceRegistry` | `domain/ports/z_relation_source.dart:45` / `:71` | Flux `List<ZFieldChoice>` nu |
| `ZRelationCrudHandler` + `ZRelationCrudRegistry` | `domain/ports/z_relation_crud.dart:82` / `:189` | create/edit/copy inline → `Future<ZFieldChoice?>` |
| `ZAppFileResolver` | `domain/ports/z_app_file_resolver.dart:44` | Référence opaque `String` → `AppFile` |
| `ZDateDisplayFormatter` + `zDateModeOf` + `zDateDisplayTextOf` | `domain/ports/z_date_display_formatter.dart:51,75,93` | Formatage d'affichage des dates. **Sans port : chaîne brute** |
| `ZNumberDisplayFormatter` + `zNumberDisplayTextOf` | `domain/ports/z_number_display_formatter.dart:43` / `:67` | Formatage d'affichage des nombres (lecture **et** résumé de sous-liste). **Sans port : rendu inchangé** |
| `ZFilePicker` | `presentation/edition/z_file_picker.dart:20` | Acquisition de fichier — impl fournie par l'app ou un binding, jamais par le cœur |
| `ZDisplayStateController<T>` / `ZToggleController` / `ZIndexController` / `ZDisplayStateBinding` | `presentation/state/z_display_state.dart:182,254,276,333` | Patron « état d'affichage détenu par le composant, mais pilotable par l'hôte » |

---

## 2. `zcrud_select` — présentateur riche des sélections

Barrel : `zcrud_select/lib/zcrud_select.dart` (53 lignes, 3 exports). Fork `awesome_select`
vendorisé et **confiné** : aucun type `S2*`/`SmartSelect` au barrel.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient | Défaut |
|---|---|---|---|
| `ZSmartSelectPresenter` | `src/presentation/z_smart_select_presenter.dart` (via barrel `:52`) | `const`-constructible, sans side-effect d'import. Injecté par `ZcrudScope(selectPresenter: const ZSmartSelectPresenter())`, il supplante le rendu natif de `select`/`radio`/`checkbox`/`multiselect`/`relation` par un modal S2 responsive + recherche | — |
| `ZSelectTileSpec` (24 paramètres) | `src/presentation/z_select_tile_reference.dart:272` | Le maillon **paramètre** de la chaîne : `borderColor:302`, `borderWidth:305`, `cardRadius:308`, `cardElevation:311`, `cardColor:314`, `chipBackgroundColor:318`, `chipForegroundColor:321`, `chipFontSize:325`, `chipSpacing:328`, `chipRunSpacing:332`, `chipRadius:337`, `chipPadding:342`, **`summaryMaxChips:354`**, `placeholderColor:358`, `valueColor:362`, `contentPadding:366`, `minTileHeight:374`, `monoChoiceStyle:378`, `multiChoiceStyle:382`, `modalShape:385`, `dialogBreakpoint:389`, `choicePageLimit:393`, `showTrailingChevron:397`, `showModalActions:406` | tout `null` |
| `ZSelectTileReference` | `…/z_select_tile_reference.dart:147-262` | L'apparence de **référence** auditée : `cardRadius = 12`, `borderWidth = 1`, `chipSpacing = 6`, `chipRunSpacing = 6`, `chipFontSize = 12`, **`summaryMaxChips = 3`** (`:189`), `summaryChipRadius = 6`, `summaryOverflowFontSize = 11`, `minTileHeight = 48`, `dialogBreakpoint = 600`, `choicePageLimit = 20`, `optionsLoadTimeout = 30 s`, `monoChoiceStyle = radios`, `multiChoiceStyle = switches`, `modalShape = adaptive` | — |
| `ZSelectChoiceStyle` / `ZSelectModalShape` | `…/z_select_tile_reference.dart:100` / `:120` | Style d'option et forme de modal | — |
| `zSelectTileMetricsOf` | `src/presentation/z_select_tile_metrics.dart:187` | **Le seul endroit** où les trois maillons se rencontrent — exporté pour qu'un hôte **vérifie** ce que sa configuration produit | — |
| `ZSelectTileMetrics` (22 champs) | `…/z_select_tile_metrics.dart:78` | Le résultat résolu | — |
| `zSelectChoiceStyleFromToken` / `zSelectModalShapeFromToken` | `…/z_select_tile_metrics.dart:48` / `:63` | Convertisseurs **totaux** : nom inconnu ⇒ `null` ⇒ la référence décide, **sans lever** | — |

**Chaîne de résolution** : `paramètre (ZSelectTileSpec) > jeton (ZcrudTheme.select*, 12 jetons posés
dans zcrud_core) > référence (ZSelectTileReference)`. Les couleurs sont des **rôles `ColorScheme`** —
chaque app garde son thème.

---

## 3. `zcrud_field_extras` — trois champs riches

Barrel : `zcrud_field_extras/lib/zcrud_field_extras.dart` (70 lignes). Seule dépendance lourde :
`pinput`, confinée à `lib/src/`.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `registerZFieldExtrasFields(registry)` | `src/presentation/z_field_extras_registrar.dart:40-46` | Enrôle les trois `kind` en une ligne |
| `ZPinFieldWidget` / `pinFieldKind` | `src/presentation/z_pin_field_widget.dart:56` / `:38` | PIN/OTP à segments ; `kZPinDefaultLength = 4` (`:41`), `kZPinCellMinSize = 48` (`:44`), `zPinLengthOf` (`:50` — **lit `field.hintText`**) |
| `ZAutocompleteFieldWidget` / `autocompleteFieldKind` | `src/presentation/z_autocomplete_field_widget.dart:39` / `:36` | Autocomplétion sur le widget **natif Flutter** `Autocomplete` (zéro dépendance) |
| `ZEditableTableFieldWidget` / `editableTableFieldKind` | `src/presentation/z_editable_table_field_widget.dart:70` | Table éditable virtualisée (`ListView.builder`) ; `kZTableDefaultColumn = 'value'` (`:39`), `zParseTableRows:46`, `zTableColumns:59` |

Les trois `kind` sont **alignés sur `EditionFieldType.<x>.name`** — les seuls que le dispatcher cœur
résout via `registryOrFallback`. Sans enrôlement : `ZUnsupportedFieldWidget`, jamais un crash.

---

## 4. `zcrud_markdown` — la voie Delta du texte riche

Barrel : `zcrud_markdown/lib/zcrud_markdown.dart` (69 lignes). Aucun symbole `flutter_quill` exporté.
`lib/src/presentation/` : 6 296 lignes sur 17 fichiers.

### 4.1 Champ, lecteur, dialogue

| Canal | `fichier:ligne` | Ce qu'un hôte obtient | Défaut |
|---|---|---|---|
| `registerZMarkdownFields` | `src/presentation/z_markdown_registration.dart:56` | Enrôle **trois** `kind` : `inlineMarkdown`→`inline`, `markdown`→`block`, `richText`→`block` (`:101-112`). **Tous les paramètres par-champ de `ZMarkdownField` sont posables ici** (garde de parité `z_markdown_registration_parity_test.dart`, citée `:47`) | — |
| `ZMarkdownField` (25 paramètres) | `src/presentation/z_markdown_field.dart:108` | Le champ rich-text scellé sur sa tranche ; valeur **neutre** (Delta JSON) | — |
| `.mode` (`ZMarkdownFieldMode`) | `:197` / enum `:74` | `inline` = éditeur compact + bouton plein-écran ; `block` = aperçu lecteur + dialogue | dérivé du `kind` |
| `.showToolbar` / `.toolbarConfig` | `:200` / `:210` | Barre d'outils et sa config granulaire | cf. P-04 |
| `.placeholder` / `.codec` | `:223` / `:228` | Texte vide, format persisté | `ZDeltaCodec` |
| `.minLines` / `.maxLines` / `.characterLimit` | `:232,237,243` | Bornes de hauteur et compteur | `null` |
| `.styleSet` / `.formulaSpec` / `.textScaleFactor` | `:250,271,267` | Styles de rendu, formules, échelle | `null` |
| `.chrome` | `:260` | Habillage carte (`ZMarkdownFieldChrome`) | cf. P-04 |
| `.emptyIcon` / `.emptySubtitle` / `.emptyBuilder` | `:276,280,285` | État vide, **relayé depuis le lecteur** | `null` |
| `.copyOnLongPress` / `.copyFormats` / `.copiedFeedbackText` / `.copySemanticsLabel` | `:290,295,299,303` | Copie multi-format | `false` / `const []` |
| `.showLabel` | `:185` | Masquer le libellé rendu par le champ | `true` |
| `.onInit` / `.onBuild` | `:307,311` | Sondes | `null` |
| `ZMarkdownFieldDebug` | `:88` (`@visibleForTesting`) | `debugDocChangeCount`, `debugDocSubscriptionActive`, `debugPersistedValue` — vérifier l'absence de fuite sans toucher au `State` privé | — |
| `ZMarkdownReader` (17 paramètres) | `src/presentation/z_markdown_reader.dart:57` | Lecteur non éditable : `value:90`, `codec:93`, `label:96`, `placeholder:99` (`defaultPlaceholder = 'Aucun contenu'`, `:86`), **`chrome:103`**, `semanticsEnabled:113`, `baseStyle:123`, `styleSet:127`, `textScaleFactor:130`, `formulaSpec:133`, `copyOnLongPress:146`, `copyFormats:158`, `copiedFeedbackText:163`, `copySemanticsLabel:168`, `emptyBuilder:173`, `emptyIcon:177`, `emptySubtitle:181` | — |
| `ZMarkdownReaderChrome` | `…/z_markdown_reader.dart:47` | `bordered` (cadre + rayon + `fieldPadding` du thème — **défaut**) ou `none` (aucun cadre, **aucun padding** : l'appelant habille) | `bordered` |
| `showZRichTextFullscreenDialog` | `src/presentation/z_rich_text_fullscreen_dialog.dart:44` | Éditeur plein écran : `initialValue`, **`title`** (défaut « Éditer »), `codec`, `placeholder`, `styleSet`, `textScaleFactor`, `formulaSpec`, `toolbarConfig`. Valider ⇒ valeur neutre ; annuler ⇒ `null` | — |
| `ZRichTextFullscreenDialog` | `…/z_rich_text_fullscreen_dialog.dart:77` | Le contenu du dialogue (exposé pour les tests widget) ; `fullscreen:121` | seuil `600` dp (`:36`) : sous ce seuil, `Scaffold` plein écran ; au-dessus, dialogue 80 %×70 % |

### 4.2 Barre d'outils, styles, embeds

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZRichTextToolbarConfig` (36 paramètres) | `src/presentation/z_rich_text_toolbar_config.dart:33` | 26 bascules de bouton (`:80-166`) + habillage : `roundedIcons:173`, `multiRow:200`, **`themedBarBackground:209`**, **`showSectionDividers:212`**, **`iconSize:219`**, **`iconButtonFactor:223`**, **`iconColor:228`**, **`selectedIconColor:232`**, **`barHeight:241`** |
| Préréglages | `:245` `full` · `:250` `minimal` · **`:297` `inline`** · `:334` `markdown` | Un préréglage est une **donnée**, jamais un comportement. `inline` = 16 boutons dans leur ordre, groupés (annuler · rétablir · gras · italique · souligné · code inline ┃ titre ┃ listes ┃ retraits ┃ presse-papier ┃ formule · tableau), `iconSize: 20`, `iconButtonFactor: 1.2` |
| `ZRichTextStyleSet` (33 propriétés) | `src/presentation/z_rich_text_style_set.dart:74` | Jeu de styles **neutre** (`TextStyle`/`BoxDecoration`, aucun type Quill) : `paragraph`, `h1`…`h6`, `bold`, `italic`, `underline`, `strikeThrough`, `subscript`, `superscript`, `inlineCode` (+ fond `:155`, rayon `:158`), `codeBlock` (+ décoration `:165`), `quote` (+ décoration `:173`), `lists`, `link`, `sizeSmall/Large/Huge`, `placeholder`, `lineHeight`, `headingLineHeight`, et 5 espacements `ZRichTextSpacing` (`:41`) |
| `ZRichTextFormulaSpec` | `…/z_rich_text_style_set.dart:226` | `textStyle:236`, `blockScaleFactor:239`, `inlineScaleFactor:242` |
| `ZMarkdownFieldChrome` (7 propriétés) | `src/presentation/z_markdown_chrome.dart:96` | `icon:109` (défaut `Icons.article_rounded`), `gradient:113`, `onGradient:120`, `gradientKey:124`, `labelBuilder:128`, `showActionButton:132`, **`deferWrites:145`** |
| `ZMarkdownChromeReference` | `…/z_markdown_chrome.dart:44-86` | Référence auditée de **dimensions** (aucune couleur) : `cardRadius 14`, `headerRadius 13`, `chipRadius 8`, `headerPadding 12`, `iconChipPadding 8`, `headerIconSize 18`, `borderWidthFilled 1.5`, `borderWidthEmpty 1`, opacités, ombre |
| `ZTableCellScope` / `ZTableCellContent` | `src/presentation/z_table_cell_scope.dart:47` / `:14` | Mode d'interprétation d'une cellule de tableau, **OPT-IN** : la charge persistée ne change pas, seule sa lecture change. Absent ⇒ texte brut |
| `zTableEmbedOp` / `kTableEmbedType` | `src/data/z_table_ops.dart` (via barrel `:20`) | Fabrique **neutre** d'op embed tableau (aucun type Quill) |
| `ZMediaEmbedScope` / `ZMediaResolver` / `ZMediaRef` / `ZMediaKind` | `src/presentation/z_media_embed.dart` (via barrel `:51`) | Seam neutre de résolution de source média (image/vidéo) |
| `ZMarkdownRichTextRenderer` | `src/presentation/z_markdown_rich_text_renderer.dart:` (via barrel `:45`) | Moteur du port `ZRichTextRenderer` du cœur — surface neutre |
| `ZMarkdownCopyFormat` / `ZMarkdownCopyTransform` | `src/domain/z_markdown_copy_format.dart` (via barrel `:27`) | Copie multi-format : clé, libellé par clé l10n, transformation |
| `ZMarkdownCodecScope` | `src/presentation/z_markdown_codec_scope.dart` | Codec du sous-arbre |
| `ZDeltaCodec` / `ZMarkdownCodec` / `ZHtmlCodec` / `ZCodec` | `src/data/z_delta_codec.dart`, `…/z_markdown_codec.dart`, `…/z_html_codec.dart`, `src/domain/z_codec.dart` | Les quatre maillons de (dé)sérialisation pluggable |
| `zMarkdownBridge` (ponts Markdown ↔ embed) | `src/domain/z_markdown_bridge.dart` | Description **pure Dart** (`RegExp`, `Match`, closures), OPT-IN |
| `registerZHtmlFields` (**voie Delta**) | `src/presentation/z_html_registration.dart:44` | Enrôle `html`/`inlineHtml` **sur l'éditeur Delta**, persistant du HTML `String` via `ZHtmlCodec` (`:48`) — **homonyme du satellite `zcrud_html`, cf. P-05** |

Embeds internes (non exportés, isolation AD-1/AD-7) : `z_latex_embed.dart` (508 l.),
`z_table_embed.dart` (660 l.), `z_divider_embed.dart` (113 l.), `z_table_cell.dart` (142 l.).

---

## 5. `zcrud_html` — la voie WYSIWYG WebView

Barrel : `zcrud_html/lib/zcrud_html.dart` (22 lignes, **2 exports**). Le plus petit du périmètre.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `registerZHtmlFields(registry)` | `src/presentation/z_html_wysiwyg_registration.dart:45` | Enrôle `inlineHtml` (`:46`) et `html` (`:50`) sur l'éditeur **WYSIWYG WebView** (`html_editor_enhanced`) ; `field.readOnly` ⇒ lecteur `ZHtmlView` prioritaire (`:60-68`) |
| `ZHtmlView` | `src/presentation/z_html_view.dart` (via barrel `:20`) | Lecture native (`flutter_html`) ; valeur non-`String` ⇒ rendu vide, HTML malformé rendu best-effort, **jamais** de `throw` |

Format persisté : **HTML `String`** — c'est sa raison d'être face à la voie Delta. `html_editor_enhanced`
et `flutter_html` sont confinés à `lib/src/` (garde `test/z_html_confinement_test.dart`, citée au
barrel `:15`).

---

## 6. `zcrud_media` — acquisition et affordances média

Barrel : `zcrud_media/lib/zcrud_media.dart` (52 lignes). Aucun symbole de plugin exporté.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZMediaFilePicker` | `src/data/z_media_file_picker.dart` (via barrel `:35`) | Impl concrète de `ZFilePicker` : galerie/caméra/sélecteur/recadrage. À injecter dans `ZcrudScope.filePicker` — sert les types **natifs** `image`/`file`/`document` que le cœur route déjà vers `ZAppFileField` |
| `registerZMediaFieldWidgets(registry, picker:)` | `src/presentation/z_media_field_widget.dart:83` | Enrôle les widgets riches (drop-zone / ouverture / vignette vidéo) sous les `kind` **custom** |
| `mediaImageFieldKind` / `mediaFileFieldKind` / `mediaVideoFieldKind` | `…/z_media_field_widget.dart:49,53,57` | `= EditionFieldType.mediaImage/mediaFile/mediaVideo .name` |
| `ZMediaFieldWidget` / `ZMediaFieldMode` | `…/z_media_field_widget.dart:129` / `:61` | `image`, `file`, (vidéo) |
| Six seams | `src/domain/z_media_seams.dart` (barrel `:37-44`) | `ZDocumentScanSeam`, `ZFileOpenSeam`, `ZFilePickSeam`, `ZImageCropSeam`, `ZImagePickSeam`, `ZVideoThumbnailSeam` — chacun remplaçable |
| `ZMediaCropOptions` | `src/domain/z_media_crop_options.dart` (barrel `:36`) | Options de recadrage neutres |

⚠️ Les `kind` média sont **custom**, distincts des types natifs `image`/`file`/`document` : le cœur
route les types natifs **avant** le registre (`edition_field_family.dart:224-227`).

---

## 7. `zcrud_document` — documents, annotations, viewer

Barrel : `zcrud_document/lib/zcrud_document.dart` (96 lignes). Zéro dépendance lourde.
Contribution à l'aire d'édition : **des modèles** et **un chrome de viewer accessible**, pas des
champs de formulaire.

| Canal | `fichier:ligne` | Ce qu'un hôte obtient |
|---|---|---|
| `ZStudyDocument` | `src/domain/z_study_document.dart` (barrel `:75`) | Contenu partageable (nom, chemin, statut d'ingestion, taille) |
| `ZDocumentReadingState` | `src/domain/z_document_reading_state.dart` (barrel `:71`) | État **personnel** (page courante, préférences, pages maîtrisées) — jamais colocalisé dans le document |
| `ZDocumentViewerPrefs` | `src/domain/z_document_viewer_prefs.dart` (barrel `:74`) | Zoom borné, sens, disposition — enums pur-Dart |
| `ZDocumentLearningInfo` / `ZDocPageQuality` | barrel `:70`, `:67` | Maîtrise par page (`Map<int,int>` ⇒ value object écrit à la main) |
| `ZDocumentAnnotation` / `ZDocumentAnnotationKind` / `ZAnnotationBounds` | barrel `:68`, `:69`, `:66` | Annotation partageable ; rectangle borné `[0,1]` ; repli défensif `highlight` |
| `ZAnnotationPanel` | `src/presentation/z_annotation_panel.dart:26` | `annotations:44`, `onSelect:47`, `palette:50`, `emptyState:53` |
| `ZAnnotationToolbar` | `src/presentation/z_annotation_toolbar.dart:45` | `controller:67`, `palette:71`, `onKindSelected:74`, `onColorSelected:77` |
| `ZAnnotationToolController` | `src/presentation/z_annotation_tool_controller.dart:53` | `ChangeNotifier` du type et de la couleur sélectionnés ; 5 préfixes de clés exportés (barrel `:84-89`) |
| `ZDocumentViewerChrome` | `src/presentation/z_document_viewer_chrome.dart:57` | `document:72`, `topBar:75`, `bottomBar:78`, `loadState:81`, `loading:84`, `error:87`, `empty:90`, `pageNavigation:93` |
| `ZDocumentPageNavigation` / `ZDocumentViewerLoadState` | `…/z_document_viewer_chrome.dart:29` / `:11` | Navigation de page accessible |

⚠️ **Aucune extension générée n'est exportée** (barrel `:35-62`) : les trois `hide` sont délibérés —
un `copyWith` généré remettrait `extra`/`extension`/`learning` à leurs défauts, et pour
`ZDocumentViewerPrefs` contournerait l'invariant de zoom (exemple donné au barrel `:52-53`).

---

## 8. Pièges — ce qui existe mais n'agit que sous condition

Chaque piège porte sa preuve. Ce qui est marqué **soupçon** n'a pas été mesuré jusqu'au site de
consommation et doit être vérifié avant d'être affirmé.

| Id | Piège | Preuve | Nature |
|---|---|---|---|
| **P-01** | `accentBarHeight` est un jeton **partagé** : il était déjà consommé par la carte de flashcard et par la carte de dossier avant que le champ ne s'en serve (3.16.0). Un hôte qui l'avait posé pour ses cartes **et** qui dispose d'un résolveur de teinte verra désormais ses **champs** porter la barre. Il n'existe pas de moyen de le neutraliser côté champs par jeton | `grep -rln accentBarHeight packages/*/lib` ⇒ `zcrud_core/…/z_theme.dart`, `zcrud_core/…/edition/z_field_widget.dart`, `zcrud_flashcard/…/z_flashcard_review_card.dart`, `zcrud_study/…/z_folder_card_chrome.dart` | **fait** |
| **P-02** | Toute la teinte par type de champ (bordure de focus, pastille d'icône, libellé flottant, barre d'accent) est **inerte tant qu'aucun `gradientResolver` n'est injecté**. La dartdoc le dit (`z_field_adornment_view.dart:197`), mais un lecteur pressé du CHANGELOG 3.14–3.16 croira à un défaut actif | `z_field_adornment_view.dart:206-219`, `zcrud_scope.dart:276` | **fait** |
| **P-03** | `subListRowHorizontalPadding` gouverne **aussi** l'en-tête de colonnes et le **seuil d'empilement** du résumé compact : le réduire peut faire redevenir tabulaire un résumé jusqu'ici empilé. Le libellé du bloc conserve sa marge propre de 16 dp | Défaut lu à `z_sub_list_field_widget.dart:1589` ; l'avertissement est au CHANGELOG `zcrud_core/CHANGELOG.md` §3.18.0 « Attention » | fait pour le défaut, **soupçon** pour le seuil (les deux sites `:3325` et `:3858` sont des dartdocs, pas le calcul) |
| **P-04** | **Le rendu d'un hôte passif a changé en 3.21.0** : un champ `inlineMarkdown` servi par le registre rend désormais **par défaut** une carte (en-tête icône + libellé + bordure teintée + pilule) et une barre habillée. `chrome`/`toolbarConfig` **REMPLACENT** ces défauts, ils ne s'y ajoutent pas. Et un hôte francophone qui ne monte pas le delegate verra **l'anglais** là où le paquet écrivait le français en dur | `z_markdown_registration.dart:51-55` ; `z_markdown_chrome.dart:92-94` ; `zcrud_markdown/CHANGELOG.md` §3.21.0 « Attention » | **fait** |
| **P-05** | **Deux `registerZHtmlFields` homonymes** enregistrent les **mêmes** `kind` `html`/`inlineHtml` : celui de `zcrud_markdown` (voie Delta, `z_html_registration.dart:44`) et celui de `zcrud_html` (voie WYSIWYG WebView, `z_html_wysiwyg_registration.dart:45`). Ils sont **mutuellement exclusifs** ; la collision **`throw` `ZDuplicateRegistrationError`**. L'homonymie est délibérée (une app importe exactement un des deux barrels) | Les deux fichiers, plus la note `z_html_wysiwyg_registration.dart:9-17` | **fait** |
| **P-06** | `ZFieldSpec.defaultValue` n'est amorcé que par `DynamicEdition._seedDefaultValues` (`dynamic_edition.dart:747-751`), sur `widget.fields` — et `ZStepperEdition` ne passe à chaque `DynamicEdition` que `_stepSpecs(index)` (`z_stepper_edition.dart:1446`). Une étape jamais montée ne verrait donc jamais ses `defaultValue` amorcés, alors que `ZEditionSubmitController` soumet `controller.values` (`z_submission.dart:234`), un instantané des tranches | Les trois sites ci-dessus | **soupçon** — non vérifié jusqu'au comportement observé ; à confirmer par un test avant d'en faire un constat |
| **P-07** | `_seedDefaultValues` ne pose la tranche que si `f.defaultValue != null` (`dynamic_edition.dart:749`) : un `defaultValue` explicitement nul est indiscernable d'un absent. La règle documentée « clé présente = autoritaire, même nulle » porte sur `initialValues`, pas sur `defaultValue` | `dynamic_edition.dart:737-751`, `z_form_controller.dart:134-150` | **fait** |
| **P-08** | Le résumé d'un `select` multiple est **coupé par défaut au-delà de trois valeurs depuis 3.20.0** — changement de rendu pour un hôte passif. Échappatoire : un palier **non positif** rétablit l'affichage intégral, et rien ne lève | `ZSelectTileReference.summaryMaxChips = 3` (`z_select_tile_reference.dart:189`) ; jeton `selectSummaryMaxChips` (`z_theme.dart:2255`) ; résolution `z_select_tile_metrics.dart:209-212` | **fait** |
| **P-09** | Les flèches monter/descendre de sous-liste ont été **supprimées** en 3.17.0 au profit de la poignée : c'est un remplacement, pas un ajout. L'équivalent non gestuel est désormais **sémantique**, par ligne. Le résumé **tabulaire** ne s'applique plus quand l'ordre est réordonnable | `zcrud_core/CHANGELOG.md` §3.17.0 « Modifié » | **fait** (CHANGELOG), non revérifié au widget |
| **P-10** | Deux planchers d'accessibilité de sous-liste sont **délibérément non réglables** : la marge avant le glyphe de poignée ne descend pas sous 12 dp (et **remonte à 14 dp** si l'on pose `subListDragHandleSize: 20`), et le jeu de 14 dp sous le texte d'une ligne réordonnable appartient à la cible de 48 dp. L'échappatoire est `reorderable: false` | `zcrud_core/CHANGELOG.md` §3.17.0 et §3.18.0 « Attention » | **fait** (CHANGELOG) |
| **P-11** | `EditionFieldType.stepper` est le **seul** type qui tombe en `unsupported`, et c'est délibéré. Un hôte qui déclare un champ `stepper` obtient `ZUnsupportedFieldWidget`, pas un assistant | `edition_field_family.dart:230-234` | **fait** |
| **P-12** | `EditionFieldType.tags` route vers la famille **native** `tags`, pas vers `registryOrFallback` : un builder enregistré sous `kind == 'tags'` serait du **code mort** jamais atteint par le dispatcher | `edition_field_family.dart:155-156` ; note explicite `zcrud_field_extras/lib/zcrud_field_extras.dart:37-44` | **fait** |
| **P-13** | `editableTable` s'édite pleinement **en mémoire**, mais **la persistance via `@ZcrudModel` n'est pas supportée** : le générateur lève sur un élément `Map` sans branche de classification | `zcrud_field_extras/lib/zcrud_field_extras.dart:28-35` | **fait** (déclaré par le paquet lui-même) |
| **P-14** | `ZMarkdownFieldChrome.deferWrites` **n'est sûr que si la soumission est précédée d'une perte de focus**. Un écran qui soumet directement depuis un bouton n'ayant pas défocalisé l'éditeur enregistre la tranche d'**avant** la saisie — l'utilisateur perd son texte, sans message. C'est pourquoi le défaut ne l'active pas | `z_markdown_chrome.dart:139-145` | **fait** (avertissement au point de déclaration) |
| **P-15** | `ZMarkdownReaderChrome.none` retire le cadre **et le padding** : ce n'est pas « cadre en moins », c'est « habillage à la charge de l'appelant » | `z_markdown_reader.dart:50-54` | **fait** |
| **P-16** | Le seuil de bascule du dialogue plein écran (600 dp) est une **constante privée** (`_kFullscreenBreakpoint`), non exposée et non paramétrable ; seul `ZRichTextFullscreenDialog.fullscreen` permet de forcer la présentation, et il n'est pas atteint par `showZRichTextFullscreenDialog` (qui le calcule) | `z_rich_text_fullscreen_dialog.dart:36,55-56,121` | **fait** |
| **P-17** | `showZRichTextFullscreenDialog` porte un `title`, **pas de sous-titre**, et le chrome de carte non plus. Le seul `subtitle` du paquet est `emptySubtitle` — le sous-titre de l'**état vide** du lecteur, pas un sous-titre d'en-tête | Signature complète `z_rich_text_fullscreen_dialog.dart:44-54` ; `grep -in subtitle z_rich_text_fullscreen_dialog.dart` ⇒ **RC=1, aucune ligne** ; `grep -in subtitle z_markdown_chrome.dart` ⇒ **RC=1, aucune ligne** ; `grep -in subtitle z_markdown_field.dart` ⇒ 6 lignes, **toutes** `emptySubtitle` (`:131,166,279,280,283,886`) | **fait** (greps négatifs montrés) |
| **P-18** | `zPinLengthOf` lit la longueur du PIN dans **`field.hintText`** — un canal détourné : un hôte qui pose un vrai texte d'aide sur un champ `pin` perd la longueur (repli `kZPinDefaultLength = 4`) | `zcrud_field_extras/lib/src/presentation/z_pin_field_widget.dart:41,50` | **fait** |
| **P-19** | Aucun jeton de `ZcrudTheme` ne concerne le texte riche : la barre d'outils et le chrome markdown se règlent **uniquement** par paramètre (`ZRichTextToolbarConfig`, `ZMarkdownFieldChrome`), jamais par le thème injecté | `grep '^  final ' z_theme.dart \| grep -iE 'markdown\|rich\|toolbar\|editor'` ⇒ **RC=1, aucune ligne** | **fait** (grep négatif montré) |
| **P-20** | `ZDateDisplayFormatter` et `ZNumberDisplayFormatter` sont des **ports sans impl dans le cœur** : sans injection, la date sort en **chaîne brute** et le nombre au **rendu inchangé**. Un écart de format n'est donc pas forcément un défaut du socle, mais un port non branché | `domain.dart:103-107` et `:111` ; `domain/ports/z_date_display_formatter.dart:51`, `…/z_number_display_formatter.dart:43` | **fait** |
| **P-21** | `ZFieldTintPresets.classic` (15 teintes ARGB) est de la **donnée à copier**, jamais un défaut : **aucun site de `lib/` ne la lit**. Un hôte qui l'importe sans écrire son résolveur n'obtient rien | `grep -rn ZFieldTintPresets packages/*/lib/` ⇒ **2 lignes seulement**, toutes deux dans le fichier de déclaration : `z_field_tint_presets.dart:26` (exemple de dartdoc) et `:66` (la déclaration) — **aucun consommateur** | **fait** (grep négatif montré) |

---

## 9. Livré récemment (v3.13.0 → v3.21.0, 24–25 août 2026) — probablement inconnu de l'hôte

Table **mesurée** par `git diff --stat <tag précédent> <tag> -- packages/{core,select,field_extras,markdown,html,media,document}/lib`.
Sur ces neuf versions, **2 objets seulement** ont été touchés dans les sept paquets :
`zcrud_core` (8 versions sur 9), `zcrud_markdown` (2), `zcrud_select` (3).
`zcrud_field_extras`, `zcrud_html`, `zcrud_media` et `zcrud_document` n'ont **rien reçu** sur cette
plage — prouvé par identité à l'octet : `git diff --quiet v3.12.0 v3.21.0 -- packages/<pkg>/lib`
rend **RC=0 pour les quatre**. Leur catalogue ci-dessus (§3, §5, §6, §7) est donc, à un détail près,
celui que l'hôte pouvait déjà connaître.

| Version | Paquet(s) | Canaux publics livrés | `fichier:ligne` |
|---|---|---|---|
| **3.13.0** | core, select | `ZSubListConfig.reorderable` passe `bool`→**`bool?`** ; `showViewAction`/`showEditAction`/`showDeleteAction` ; jetons de couleur/taille d'action et **5 jetons du contrôle d'ajout** ; **`ZSubListSeams.headerBuilder`** + `ZSubListHeaderView` ; **`ZEditionSection.icon`** et **`ZEditionSection.style`** (`ZEditionSectionStyle`, 9 propriétés dont le filet vertical directionnel) ; `ZSubListViewData.onReorder`. Côté select : contrat d'**orphelin** honoré par `ZSmartSelectPresenter` (clé `choiceUnresolved`) | `z_sub_list_config.dart:200,238,243,250` · `z_sub_list_seams.dart:950,290` · `dynamic_edition.dart:284,290,192` · `z_theme.dart:923-961` · `z_localizations.dart:172,342` |
| **3.14.0** | core, markdown | **`ZTextConfig.keyboardType`** ; **`ZTextCapitalization`** (dont `lowercase`) et **`ZcrudScope.defaultTextConfig`** (précédence champ > scope) ; port **`ZNumberDisplayFormatter`** ; **`minValueKey`/`maxValueKey`** honorés ; **cinquième cible `ZDerivation.readOnly`** ; **`ZFieldAdornment.onTap`** ; **`ZFieldSpec.defaultValue`** amorcé ; `ZFieldTintPresets` ; teinte de type sur bordure de focus et pastille. Markdown : **copie multi-format** et **état vide relayé** du lecteur vers le champ | `z_field_config.dart:101,105,147,185,189` · `zcrud_scope.dart:320` · `z_number_display_formatter.dart:43` · `z_derivation.dart:241` · `z_field_adornment.dart:75` · `z_field_spec.dart:127` · `z_field_tint_presets.dart:73` · `z_markdown_copy_format.dart` · `z_markdown_reader.dart:158,173-181` |
| **3.15.0** | core | Teinte de type atteignant le **libellé flottant** ; **pastille de fond** de l'icône d'ornement (3 jetons) | `z_field_adornment_view.dart` (+67 l.) · `z_theme.dart:1078-1089` |
| **3.16.0** | core, select | **Accent supérieur de champ** (`accentBarHeight` cesse d'être « futur ») ; teinte et pastille sur le slot **`leading`** ; **`zResolveTintedAdornment`** + `zResolveFieldTint`/`zResolveFieldAccent` (point d'entrée public pour un présentateur riche) ; `zFieldAccentKey`. Select : la tête de tuile porte teinte et pastille du cœur | `z_theme.dart:1102` · `z_field_adornment_view.dart:206,218,227,270` · `z_gradient_resolver.dart:24,35` |
| **3.17.0** | core | **Glisser-déposer dans la sous-liste** via le port `ZReorderRenderer` (poignée ≥ 48 dp + actions sémantiques, dans les deux modes) ; la **voie groupée respecte l'ordre déclaré de `fields`** ; **6 jetons d'espacement vertical** de sous-liste (jusqu'à 52 dp regagnés en résumé tabulaire) ; une section sans titre ni icône ne rend plus d'en-tête. 🔴 **Suppression** des flèches monter/descendre | `z_sub_list_field_widget.dart:611` · `dynamic_edition.dart` (+179 l.) · `z_theme.dart:993,1001,1012,1049,1057,1066` |
| **3.18.0** | core | **3 jetons de poignée** (`subListDragHandleIcon`/`Size`/`Color`) ; **2 marges horizontales de ligne** (`subListRowHorizontalPadding` ⇒ 16, `subListRowInnerPadding` ⇒ 12) ; **`ZSubListSeams.itemBorderColorKey`** (bordure dépendant de l'item) ; poignée par défaut `Icons.drag_indicator_rounded` | `z_theme.dart:969,979,983,1026,1041` · `z_sub_list_seams.dart:1020,442` |
| **3.19.0** | core | **`ZReorderRenderer.buildDragHandle`** (implémentation par défaut **identité**) ; **`ZReorderRenderRequest.dragPreviewWrapper`** (habillage de l'aperçu flotté, qui vit dans l'`Overlay`) ; correctif : la poignée n'est plus muette sous un renderer injecté | `z_reorder_renderer.dart:91` · `z_reorder_render_request.dart:127` |
| **3.20.0** | core, select | **Coupure du résumé d'un `select` multiple** : `selectSummaryMaxChips` + 3 jetons de forme, clé l10n `selectSummaryOverflow`, `ZSelectTileSpec.summaryMaxChips`, `ZSelectTileReference.summaryMaxChips = 3`. 🔴 **Coupure active par défaut** ; palier non positif ⇒ affichage intégral. L'annonce accessible porte toujours la **totalité** des valeurs | `z_theme.dart:2255,2262,2268,2275` · `z_localizations.dart:67,249` · `z_select_tile_reference.dart:189,354` · `z_select_tile_metrics.dart:165,209` |
| **3.21.0** | core, markdown | **Le champ compact a un chrome et une barre d'outils PAR DÉFAUT** (carte, en-tête, barre à fleur) ; **préréglage `ZRichTextToolbarConfig.inline`** (16 boutons groupés) ; **6 paramètres de géométrie de barre** (`showSectionDividers`, `iconSize`, `iconButtonFactor`, `iconColor`, `selectedIconColor`, `barHeight`) ; **4 clés l10n** du chrome (`z.markdown.write/edit/commit/expand`) ; correctif : **`themedBarBackground` était inerte** en affichage sur une seule ligne — le mode dans lequel la barre de formulaire est toujours rendue | `z_rich_text_toolbar_config.dart:297,212,219,223,228,232,241` · `z_localizations.dart:200-203,360-363` · `z_markdown_registration.dart:51-55` |

### Ce qu'un agent de confrontation devrait regarder en premier

1. **Le champ rich-text compact** (3.21.0) : le socle rend maintenant, sans configuration, ce que
   beaucoup d'hôtes composaient à la main. Tout hôte qui posait sa propre carte autour d'un
   `inlineMarkdown` **empile désormais deux cartes** — c'est le cas d'école du « hôte qui compensait ».
2. **La sous-liste** (3.13 → 3.19, cinq versions consécutives, ~1 400 lignes ajoutées au seul
   `z_sub_list_field_widget.dart`) : glisser-déposer, 21 jetons, 14 seams, en-tête remplaçable,
   bordure par item. C'est la surface la plus transformée du périmètre.
3. **La teinte par type de champ** (3.14 → 3.16) : quatre points d'application (bordure de focus,
   pastille d'icône, libellé flottant, barre d'accent) et un point d'entrée public pour les
   présentateurs riches — le tout **inerte sans `gradientResolver`** (P-02).
4. **Les sections décorées** (3.13.0) : `ZEditionSectionStyle` couvre fond, filet supérieur, rayon,
   typographie, rembourrage d'en-tête, couleur d'icône, chevrons remplaçables et filet vertical
   directionnel — neuf leviers, tous `null` par défaut.
5. **Les deux ports de formatage d'affichage** (`ZDateDisplayFormatter`, `ZNumberDisplayFormatter`) :
   un écart de format chez l'hôte est souvent un port non branché, pas un défaut du socle (P-20).
