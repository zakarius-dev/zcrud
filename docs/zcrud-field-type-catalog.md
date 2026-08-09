<!-- GÉNÉRÉ — NE PAS ÉDITER À LA MAIN. -->
<!-- Source : packages/zcrud_core/test/support/z_field_type_catalog.dart -->
<!-- Garde de synchronisation : packages/zcrud_core/test/z_field_type_catalog_test.dart -->

# Catalogue des types de champ zcrud

Table de découverte demandée par le CR d'exploration DODLP du 2026-08-06 (§7). Elle répond à une seule question : **« ce type existe-t-il déjà, et que dois-je ajouter pour l'obtenir ? »**

🔴 **Ce document est dérivé du code, pas écrit à la main.** Chaque colonne est mesurée :

* la **famille** est le retour réel de `familyOf(type)` — la classification que le dispatcher `ZFieldWidget` consulte lui-même ;
* le **statut** est *dérivé* de cette famille : il n'existe aucun champ où en écrire un autre, donc aucun type ne peut être annoncé « supporté » pendant que le dispatcher le route en repli ;
* la **config** est un littéral de `Type` (nommer une classe inexistante ne compile pas), et une garde vérifie qu'elle est réellement consultée dans `lib/` ;
* les **chemins** et les **paquets satellites** sont vérifiés présents sur disque par la garde.

Une valeur ajoutée à `EditionFieldType` sans entrée ici **casse la compilation** ; un document divergent du code **fait rougir la suite de tests**.

| Type | Famille (dispatcher) | Statut | À faire côté hôte | `kind` de registre | Config | Où regarder |
|---|---|---|---|---|---|---|
| `text` | `text` | cœur | rien à ajouter | — | `ZTextConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` |
| `multiline` | `text` | cœur | rien à ajouter | — | `ZTextConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` |
| `number` | `number` | cœur | rien à ajouter | — | `ZNumberConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` |
| `integer` | `number` | cœur | rien à ajouter | — | `ZNumberConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` |
| `float` | `number` | cœur | rien à ajouter | — | `ZNumberConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` |
| `boolean` | `boolean` | cœur | rien à ajouter | — | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_boolean_field_widget.dart` |
| `dateTime` | `date` | cœur | rien à ajouter | — | `ZDateConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart` |
| `time` | `date` | cœur | rien à ajouter | — | `ZDateConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart` |
| `dateRange` | `dateRange` | cœur | rien à ajouter | — | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_date_range_field_widget.dart` |
| `select` | `select` | cœur | rien à ajouter | — | `ZSelectConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart` |
| `radio` | `select` | cœur | rien à ajouter | — | `ZSelectConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart` |
| `checkbox` | `select` | cœur | rien à ajouter | — | `ZSelectConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart` |
| `relation` | `relation` | cœur | rien à ajouter | — | `ZRelationConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart` |
| `rowChips` | `rowChips` | cœur | rien à ajouter | — | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_row_chips_field_widget.dart` |
| `tags` | `tags` | cœur | rien à ajouter | — | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_tags_field_widget.dart` |
| `subItems` | `subList` | cœur | rien à ajouter | — | `ZSubListConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` |
| `dynamicItem` | `dynamicItem` | cœur | rien à ajouter | — | `ZSubListConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_dynamic_item_field_widget.dart` |
| `file` | `file` | cœur | rien à ajouter | — | `FileFieldConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` |
| `image` | `file` | cœur | rien à ajouter | — | `FileFieldConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` |
| `document` | `file` | cœur | rien à ajouter | — | `FileFieldConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` |
| `location` | `registryOrFallback` | satellite | ajouter `zcrud_geo`, puis enregistrer le `kind` soi-même (pas de registrar global — cf. « Où regarder ») | `location` | — | `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` |
| `geoArea` | `registryOrFallback` | satellite | ajouter `zcrud_geo`, puis enregistrer le `kind` soi-même (pas de registrar global — cf. « Où regarder ») | `geoArea` | — | `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` |
| `phoneNumber` | `registryOrFallback` | satellite | ajouter `zcrud_intl`, puis enregistrer le `kind` soi-même (pas de registrar global — cf. « Où regarder ») | `phoneNumber` | — | `packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart` |
| `country` | `registryOrFallback` | satellite | ajouter `zcrud_intl`, puis enregistrer le `kind` soi-même (pas de registrar global — cf. « Où regarder ») | `country` | — | `packages/zcrud_intl/lib/src/presentation/z_country_field_widget.dart` |
| `address` | `registryOrFallback` | satellite | ajouter `zcrud_intl` puis `registerZAddressFieldWidgets(registry)` | `address` | — | `packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart` |
| `rating` | `rating` | cœur | rien à ajouter | — | `ZRatingConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_rating_field_widget.dart` |
| `slider` | `slider` | cœur | rien à ajouter | — | `ZSliderConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_slider_field_widget.dart` |
| `signature` | `signature` | cœur | rien à ajouter | — | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_signature_field_widget.dart` |
| `color` | `color` | cœur | rien à ajouter | — | `ZColorConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart` |
| `icon` | `registryOrFallback` | registre app | `ZWidgetRegistry.register('icon', …)` — repli `ZUnsupportedFieldWidget` sinon | `icon` | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_unsupported_field_widget.dart` |
| `pin` | `registryOrFallback` | satellite | ajouter `zcrud_field_extras` puis `registerZFieldExtrasFields(registry)` | `pin` | — | `packages/zcrud_field_extras/lib/src/presentation/z_field_extras_registrar.dart` |
| `autocomplete` | `registryOrFallback` | satellite | ajouter `zcrud_field_extras` puis `registerZFieldExtrasFields(registry)` | `autocomplete` | — | `packages/zcrud_field_extras/lib/src/presentation/z_field_extras_registrar.dart` |
| `editableTable` | `registryOrFallback` | satellite | ajouter `zcrud_field_extras` puis `registerZFieldExtrasFields(registry)` | `editableTable` | — | `packages/zcrud_field_extras/lib/src/presentation/z_field_extras_registrar.dart` |
| `mediaImage` | `registryOrFallback` | satellite | ajouter `zcrud_media` puis `registerZMediaFieldWidgets(registry)` | `mediaImage` | — | `packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart` |
| `mediaFile` | `registryOrFallback` | satellite | ajouter `zcrud_media` puis `registerZMediaFieldWidgets(registry)` | `mediaFile` | — | `packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart` |
| `mediaVideo` | `registryOrFallback` | satellite | ajouter `zcrud_media` puis `registerZMediaFieldWidgets(registry)` | `mediaVideo` | — | `packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart` |
| `markdown` | `registryOrFallback` | satellite | ajouter `zcrud_markdown` puis `registerZMarkdownFields(registry)` | `markdown` | — | `packages/zcrud_markdown/lib/src/presentation/z_markdown_registration.dart` |
| `inlineMarkdown` | `registryOrFallback` | satellite | ajouter `zcrud_markdown` puis `registerZMarkdownFields(registry)` | `inlineMarkdown` | — | `packages/zcrud_markdown/lib/src/presentation/z_markdown_registration.dart` |
| `html` | `registryOrFallback` | satellite | ajouter `zcrud_html` puis `registerZHtmlFields(registry)` | `html` | — | `packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart` |
| `inlineHtml` | `registryOrFallback` | satellite | ajouter `zcrud_html` puis `registerZHtmlFields(registry)` | `inlineHtml` | — | `packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart` |
| `richText` | `registryOrFallback` | satellite | ajouter `zcrud_markdown` puis `registerZMarkdownFields(registry)` | `richText` | — | `packages/zcrud_markdown/lib/src/presentation/z_markdown_registration.dart` |
| `stepper` | `unsupported` | cœur (autre chemin) | passer par `zPartitionFieldsIntoSteps` + `ZStepperEdition` | — | `ZStepFieldConfig` | `packages/zcrud_core/lib/src/presentation/edition/z_step_partition.dart`<br>`packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart`<br>`packages/zcrud_core/lib/src/presentation/edition/z_stepper_config.dart` |
| `password` | `text` | cœur | rien à ajouter | — | `ZTextConfig` | `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` |
| `hidden` | `hidden` | non rendu | aucune — champ volontairement invisible | — | — | `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` |
| `widget` | `freeWidget` | registre app | `ZWidgetRegistry.register('widget', …)` — repli `ZUnsupportedFieldWidget` sinon | `widget` | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_free_widget_field_widget.dart` |
| `custom` | `registryOrFallback` | registre app | `ZWidgetRegistry.register('custom', …)` — repli `ZUnsupportedFieldWidget` sinon | `custom` | — | `packages/zcrud_core/lib/src/presentation/edition/families/z_unsupported_field_widget.dart` |

## Seams injectables par type

Dépendances optionnelles fournies au `ZcrudScope`. Un seam absent ne fait jamais échouer le rendu (AD-10) : l'action concernée est simplement désactivée.

| Type | Seams (`ZcrudScope`) |
|---|---|
| `select` | `ZSelectPresenter`, `ZChoicesSourceRegistry` |
| `radio` | `ZSelectPresenter`, `ZChoicesSourceRegistry` |
| `checkbox` | `ZSelectPresenter`, `ZChoicesSourceRegistry` |
| `relation` | `ZRelationSourceRegistry`, `ZRelationCrudRegistry` |
| `file` | `ZFilePicker`, `CloudStorageRepository` |
| `image` | `ZFilePicker`, `CloudStorageRepository` |
| `document` | `ZFilePicker`, `CloudStorageRepository` |
| `color` | `ZColorPicker` |
| `icon` | `ZWidgetRegistry` |
| `widget` | `ZWidgetRegistry` |
| `custom` | `ZWidgetRegistry` |

## Les trois lignes qui trompent

### `stepper` — `unsupported` ne veut PAS dire indisponible

`familyOf(EditionFieldType.stepper)` retourne bien `unsupported`, et c'est **délibéré** : le dispatcher associe un `kind` à un widget-**feuille** porteur d'UNE tranche de valeur, alors qu'un stepper est un **regroupement** qui doit rester le seul écrivain de `controller.visibleFields`. Le router par le registre casserait cet invariant.

Le stepper est **pleinement supporté**, par un autre chemin : déclarez vos champs à plat en les annotant d'un `ZStepFieldConfig`, puis `zPartitionFieldsIntoSteps` en dérive les `ZEditionStep` que `ZStepperEdition` consomme. N'écrivez pas de stepper maison.

### Types servis par un satellite — aucune arête vers `zcrud_core`

`zcrud_core` **n'importe aucun paquet zcrud** (AD-1, graphe sortant = 0) : il ne peut donc pas « contenir » ces widgets. Il se contente de **nommer** le type et de router vers le `ZWidgetRegistry` injecté ; tant que le `kind` n'y est pas enregistré, le champ dégrade en `ZUnsupportedFieldWidget` — jamais un crash (AD-10).

La colonne « satellite » de ce document est donc une **chaîne de caractères inerte** dans un fichier de test, jamais un `import` : elle informe sans créer d'arête. Sa véracité n'est pas laissée à la confiance — la garde vérifie sur disque que le paquet existe et qu'il mentionne bien le `kind` annoncé.

### Types sans widget nulle part

`icon` et `custom` ne sont servis par **aucun** paquet du monorepo. Contournement : enregistrez votre propre builder sous le `kind` indiqué (`ZWidgetRegistry.register`) ; c'est le point d'extension prévu (AD-4), le même que pour `widget`. `hidden`, lui, n'a pas de contournement parce qu'il n'a pas de problème : il est invisible par contrat.
