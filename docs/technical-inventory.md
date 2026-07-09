# Inventaire technique zcrud

## 1. Synthese executive

`zcrud` est le futur package Flutter unifie destine a remplacer le code CRUD dynamique duplique a l'identique (~11 000 lignes de moteur clonees) dans trois applications : **IFFD**, **DODLP** et **DLCFTI**. Ces trois projets partagent le meme ADN — un moteur declaratif pilote par une liste de `DynamicFormField` generant a la fois formulaires d'edition et tableaux de liste — mais a trois stades d'evolution divergents.

**Trois generations, trois paradigmes :**

- **DLCFTI** (le plus ancien / legacy) : dispatch de champ par `Type` Dart natif (`case const (num)`, `case const (Country)`), aucune abstraction repository (CRUD dans une extension `FirebaseFirestoreX`), GetX + reflectable. A abandonner comme source.
- **DODLP** (le plus riche fonctionnellement) : enum `EditionFieldTypes` a ~37 types reellement implementes (geo, signature, rating, slider, tags, stepper, fichiers), grille responsive, mode lecture, detection dirty. Clean-arch modulaire, get_it + GetX + provider + reflectable. **C'est le catalogue de reference.**
- **IFFD** (le plus moderne architecturalement) : Riverpod 3 + freezed + codegen, abstraction `CrudRepository<T>` propre, editeur rich-text Quill unifie, stub Supabase (intention multi-backend). Paradoxalement le catalogue de rendu le plus **pauvre** (~19 types implementes sur 26 declares ; `file`/`image`/`phoneNumber`/`password`/`icon`/`hidden`/`inlineHtml` tombent en `default` silencieux).

**Constats structurants pour l'architecture :**

1. **Un bug critique partage** : le formulaire entier est une seule `State` ; chaque frappe declenche un `setState(() {})` vide qui reconstruit tout l'arbre, provoquant jank + perte de focus / saut de curseur (cause = instabilite de reconciliation faute de keys stables et de controllers stables). C'est un objectif produit majeur (section 4).

2. **Aucun codegen de modeles reel** : malgre freezed/json_serializable declares dans IFFD, les modeles sont ecrits 100% a la main, et la deserialisation repose partout sur un **registre manuel `Map<Type, Function()>`** (50-80 entrees) a editer a chaque modele — dependance circulaire framework<->modeles metier. C'est le blocage d'extraction n°1 (partage DODLP + IFFD).

3. **reflectable est bannissable** : IFFD prouve que le moteur tourne sans reflection (sur `Map<String,dynamic>`). reflectable impose `initializeReflectable()` par entry point + codegen par fichier de test, incompatible avec Riverpod 3.

4. **Deux consommateurs prioritaires modernes** : **DODLP** (banc d'essai n°1, mais sur GetX/get_it/reflectable — l'injection zcrud doit etre framework-neutre) et **lex_douane** (monorepo Melos, Riverpod 3 + freezed + json_serializable, deja dote nativement de flashcards/mindmaps mais SANS aucun framework de formulaire riche — c'est le vrai vide a combler).

**Recommandation de decoupage** : un `zcrud_core` pur (contrats, `EditionFieldTypes`, `DataRequest`/`DataState` neutres, moteur d'edition/liste, champ fichier), un `zcrud_annotations` + generateur (codegen serialisation + schema), et des sous-packages optionnels pour les dependances lourdes : `zcrud_markdown`, `zcrud_mindmap`, `zcrud_flashcard`, `zcrud_firestore`, `zcrud_geo`, `zcrud_export`.

---

## 2. Inventaire des fonctionnalites par domaine

### 2.1 Formulaires / Edition dynamique

| Element | Existe ou (projet:fichier:ligne) | Maturite |
|---|---|---|
| Moteur `DynamicEditionScreen<T>` (StatefulWidget + `build()` monolithique 2625/4038/4455 l.) | iffd `lib/data_crud/edition_screen.dart:164`; dodlp `.../edition_screen.dart:206`; dlcfti `edition_screen.dart:167` | mature-mais-defectueux |
| Schema declaratif `DynamicFormField<T>` (~90 proprietes) | iffd `lib/data_crud/edition_field.dart:80`; dodlp `models.dart:549`; dlcfti `models.dart:480` | mature (god-class) |
| Etat `item` + `editionState` (2 maps paralleles + `GlobalKey<FormBuilderState>`) | dodlp `edition_screen.dart:1055`; iffd `edition_screen.dart:712` | mature |
| Steppers multi-etapes (`DynamicStepper` + `StepperConfig`) | dodlp `.../widgets/dynamic_stepper.dart:31`, `models/stepper_config.dart:40` | partiel (bug FormBuilder non enveloppe) |
| Sections repliables (`MyStickyHeader`/`ExpandablePanel`, etat persiste GetStorage/SharedPreferences) | dodlp `forms_utils.dart:43`; iffd `edition_screen.dart:520` | mature |
| Champs conditionnels `displayCondition(item,state,crud)` | iffd `edition_screen.dart:501`; dodlp `edition_screen.dart:430` | mature |
| Grille responsive 12 colonnes (`ResponsiveFormRow/Col`, xs/sm/md/lg/xl) | dodlp `.../widgets/responsive_form_row.dart:24`, `utils/responsive_utils.dart:25` | mature |
| Mode lecture (`readOnly` + `showIfNull`) | dodlp `edition_screen.dart:437` | partiel (absent DLCFTI) |
| Detection dirty par empreinte (`_fingerprint`) | dodlp `edition_screen.dart:220,246` | mature (DODLP seul) |
| Soumission create/update (`validateForm`, branches formOnly/bodyOnly/defaut) | dodlp `edition_screen.dart:318`; iffd `edition_screen.dart:392` | mature |
| Registres app-specifiques (`getResourceEditionFormFields<T>`, `getDynamicInitialState<T>`, `onDynamicFormSubmit<T>`) | dodlp `edition_forms.dart:46`, `initial_states.dart:6`, `on_form_submit.dart:7` | mature (glue a injecter) |

### 2.2 Liste / Table dynamique

| Element | Existe ou | Maturite |
|---|---|---|
| `DynamicListScreen<T>` (~1750-2020 l., copie-colle x4) | iffd `dynamic_list_screen.dart:970`; dodlp `.../dynamic_list_screen.dart:1197` | mature |
| Rendu SfDataGrid (mode gridTable, defaut) | iffd `dynamic_list_screen.dart:970-1112` | mature |
| Rendu Material DataTable (RichText/devise/ErpFile) | iffd `dynamic_list_screen.dart:850` | mature |
| `itemBuilder` / `customView` (rendu libre) | iffd `dynamic_list_screen.dart:1178,1235` | mature |
| Recherche client-side (sans accents + contains tous champs) | iffd `dynamic_list_screen.dart:758-774,1339` | mature |
| Filtrage/tri colonne Syncfusion (mutuellement exclusifs) | iffd `dynamic_list_screen.dart:721-741,988` | mature |
| `FirestoreQueryFilter` (where serveur) | dodlp `firestore_query_filter.dart:29` | partiel |
| Pagination `SfDataPager` (in-memory, **cosmetique/buggy**) | iffd `dynamic_list_screen.dart:1114-1142` | buggy |
| Pagination Firestore streamee reelle (`StreamedDynamicListScreen` + FirestoreQueryBuilder) | dodlp `streamed_dynamic_list_screen.dart:790` | partiel (DODLP seul) |
| Selection multiple (**bug**: `_dataGridController` commente) | iffd `dynamic_list_screen.dart:1094,1100` | buggy |
| Actions ligne CRUD + ACL (`CrudActionsButons` + `RessourceACL`) | iffd `dynamic_list_screen.dart:73-342` | mature |
| Export Excel/PDF (datagrid_export/xlsio/pdf) | dodlp `dynamic_list_screen.dart:1037`; **iffd stubs vides** `dynamic_list_screen.dart:966` | mature (dodlp/dlcfti) / perdu (iffd) |
| Sous-listes imbriquees (`DynamicSubListScreen`) | iffd `sub_list_screen.dart:74`; dodlp `dynamic_list_viewer.dart:304` | mature |
| Onglets (`DynamicTab` + `DynamicTabsState`) | iffd `dynamic_list_screen.dart:1453`, `categorysation_screens.dart:8` | mature |
| Corbeille (`trashOnly`, soft-delete) | iffd `dynamic_list_screen.dart:1272` | mature |

### 2.3 Couche de donnees (data layer)

| Element | Existe ou | Maturite |
|---|---|---|
| Abstraction `CrudRepository<T>` (domain) | iffd `lib/src/domain/repositories/datacrud_repository.dart:20`; dodlp idem | mature |
| Impl `FirebaseCrudRepositoryImpl<T>` (withConverter, streams, count, batch) | iffd `lib/src/data/repositories/firebase_crud_repository_impl.dart:17` | mature |
| CRUD legacy extension `FirebaseFirestoreX` | dlcfti `extentions/firestore_extension.dart:60` | buggy/legacy |
| Interface `DataBase` (declaree, jamais implementee = code mort) | dodlp `interfaces.dart:8`; dlcfti `interfaces.dart:6` | mort |
| `DataRequest<T>` (operateurs + or/and -> `Filter` Firestore) | iffd `lib/src/domain/models/requests/data_request.dart:5,44` | mature |
| Streams (`streamAll`/`streamOne`/`streamByIds` chunk whereIn 30) | iffd `firebase_crud_repository_impl.dart:145,110` | mature |
| Comptage agrege `count()`/`asyncCount()` | iffd `firebase_crud_repository_impl.dart:408` | mature |
| Soft/hard-delete + restore | iffd `firebase_crud_repository_impl.dart:364,337` | mature |
| Batch/bulk (**incoherent** batch+transaction, `catch(_){}`) | iffd `firebase_crud_repository_impl.dart:51,380` | buggy |
| Mapping (`withConverter` + registre manuel factories ~60 types) | iffd `databases_functions.dart:13`, `data_functions.dart:314` | mature (anti-pattern) |
| Abstraction stockage `CloudStorageRepository` | iffd `cloud_storage_repository.dart:6`; dodlp idem | mature |
| Wrappers `DataState`/`FirestoreDataState` | iffd `data_state.dart:1` | mature |
| Stub Supabase `SupabaseCrudRepositoryImpl<T>` (100% commente) | iffd `supabase_crud_repository_impl.dart:16` | intention multi-backend |
| **Bug `limit`** (`query.limit()` sans reassignation) | iffd `firebase_crud_repository_impl.dart:154,393,455` | buggy |

### 2.4 Serialisation / State management

| Element | Existe ou | Maturite |
|---|---|---|
| Interface `DynamicModel` (id/deleted/canBeDeleted/lastCrudOperation + toMap/copyWith/props) | iffd `dynamic_model.dart:3`; dodlp `interfaces.dart:42`; dlcfti `named_model.dart:9` | mature |
| Serialisation manuelle par modele (~120 l. boilerplate/entite) | iffd `course.dart:6`; dodlp `named_model.dart:32` | mature |
| Registre manuel `fromMap<T>` (God-function 50-80 entrees) | dodlp `functions.dart:634-756`; iffd `data_functions.dart:314-413` | mature (anti-pattern bloquant) |
| Reflectable (`invokeItemGetter/Setter`, court-circuite pour Map) | dodlp `functions.dart:236-283` | partiel (a remplacer) |
| freezed/json_serializable declares mais **quasi inutilises** (1 seul `.freezed.dart`) | iffd `failures.freezed.dart`, `pubspec.yaml:61` | non-applique |
| Providers Riverpod codegen en couches | iffd `folder_providers.dart:21`, `auth_providers.dart:19` | mature (IFFD seul) |
| Notifier codegen (`class extends _$X`, `build()`+`state=`) | iffd `settings_providers.dart:29` | mature |
| Family via parametres nommes requis | iffd `flashcard_providers.dart:29` | mature |
| Injection par override dans `ProviderScope` (`sharedPreferencesProvider` throw) | iffd `core_providers.dart:8` + `main.dart:150` | mature |
| DODLP/DLCFTI = `provider` + `context.watch<AppUserPermissions>()` + setState | dodlp/dlcfti dynamic_list_screen | partiel |

### 2.5 Markdown + Embeds (editeur riche)

| Element | Existe ou | Maturite |
|---|---|---|
| `RichTextEditorScreen` (hote unifie edition/lecture, dispatch quillMarkdown/html) | iffd `rich_text_editor_screen.dart:38,306`; dodlp idem | mature |
| `QuillMarkdownEditorWrapper` (Quill 11 WYSIWYG + toolbar + embeds) | iffd `.../editors/quill_markdown_editor_wrapper.dart:62` | mature |
| `MarkdownEditionField` (champ CRUD, **seul champ a controller isole** = bon pattern) | iffd `.../editors/markdown_edition_field.dart:50` | mature |
| Conversions `MarkdownToDeltaHelper` / `DeltaToMarkdownHelper` (placeholders regex) | iffd `markdown_to_delta_helper.dart:114`; `delta_to_markdown_helper.dart:27` | partiel/buggy |
| `QuillDefaultStylesHelper` (google_fonts, textScaleFactor safe) | iffd `quill_default_styles_helper.dart:15` | mature |
| Embeds LaTeX (`FormulaBlockEmbed`/`Inline` + `RenderComplexLatex` flutter_math_fork + fallback flutter_tex) | iffd `embeds/formula_embed.dart:93,254` | mature |
| Embeds Tableaux (`TableViewEmbedBuilder` ACTIF ; syncfusion variante = **code mort**) | iffd `embeds/table_view_embed.dart:15`; `syncfusion_table_widget.dart:2` (mort) | partiel |
| `HtmlEditorWrapper` (html_editor_enhanced, WebView, KaTeX/MathJax CDN) | iffd `.../editors/html_editor_wrapper.dart:12`, `editor_css.dart:1` | partiel |
| `RichTextToolbarConfig` + `editor_config` (presets full/minimal/markdown) | iffd `editor_config.dart:4` | mature |
| HtmlEditorScreen legacy (HTML-only, sans Quill/LaTeX) | dlcfti `html_editor_screen.dart:10` | legacy |

**Point critique** : un champ `markdown` sauvegarde en realite du **JSON Delta** (`jsonEncode(delta.toJson())`, `rich_text_editor_screen.dart:313`) — format canonique a figer.

### 2.6 Mindmap (IFFD)

| Element | Existe ou | Maturite |
|---|---|---|
| Viewer graphite auto-layoute (`DirectGraph`) | iffd `graphite_mindmap_viewer.dart:43` | mature |
| Mesure de taille de noeud (`MeasuredSizeWidget`) | iffd `graphite_mindmap_viewer.dart:9,141` | mature |
| Editeur outline (ReorderableListView indent/outdent) | iffd `graphite_editor_widget.dart:13` | partiel-buggy |
| Editeur flowchart libre (`flutter_flow_chart` + `star_menu`) | iffd `folder_mindmap_editor.dart:33` | mature |
| Modele `MindmapNode`/`MindmapModel` (recursif, extends `FolderContentModel`) | iffd `mindmap_model.dart:13` | mature |
| Version anterieure minimale (graphite seul, params injectables) | dodlp `mindmap_edition_screen.dart` (204 l.) | partiel |
| Generation IA (`generateMindmapFromNotes` -> `MindmapNode.fromMap`) | iffd `iffd_ai_repository_impl.dart:535` | mature |
| **Bug sauvegarde outline** (renvoie `widget.mindmap` original) | iffd `graphite_editor_widget.dart:214` | buggy |

Absent de DLCFTI.

### 2.7 Flashcards (IFFD uniquement)

| Element | Existe ou | Maturite |
|---|---|---|
| `FlashcardModel` (4 types QCM/VF/ouverte/exercice) | iffd `flashcard_model.dart:12,88` | mature |
| SRS SM-2 maison (`FlashcardRepetitionInfo`, `Sm.calc`) | iffd `flashcard_repetition_info.dart:28,115` | mature |
| 6 modes d'apprentissage (`FlashcardRepetitionPageType`) | iffd `folder_flashcards_repetitions_page.dart:30` | mature |
| Carte interactive test/examen + indices IA | iffd `interactive_flashcard_repetition_card.dart:20` | mature |
| Examen blanc (**2 implementations concurrentes**) | iffd `white_exam_page.dart:20` + mode swiper | mature (redondant) |
| Generation IA multi-sources | iffd `ai_flashcards_generator_dialog_widget.dart:33` | mature |
| Edition via data_crud (`FlashcardEditionScreen`) | iffd `flashcard_edition_screen.dart:25` | mature |
| Export PDF (backend distant + fallback Syncfusion) | iffd `export_flashcards_to_pdf.dart:33` | partiel |
| Filtrage pur `applyTestExamFilters()` | iffd `flashcard_filters.dart:6` | mature |

Absent de DODLP/DLCFTI. Le package `spaced_repetition` est declare mais commente (SM-2 reimplemente maison).

### 2.8 Fichiers / PDF / Export

| Element | Existe ou | Maturite |
|---|---|---|
| Modele `AppFile` + enums `AppDocumentType`/`Status` | dodlp `models/app_file.dart:77,10` | mature (DODLP seul) |
| `FileFieldConfig` (multiple/maxFiles/extensions) | dodlp `models/file_field_config.dart:3` | mature |
| `AppFileEditionField` (scan/camera/galerie/picker, 738 l.) | dodlp `.../app_file_edition_field.dart:17` | mature |
| `CloudStorageRepository` (unique point couplage Firebase Storage) | dodlp/iffd `firebase_cloud_storage_repository_impl.dart:9` | mature |
| Orchestration upload draft->cloud (**copiee-collee dans ecrans metier**) | dodlp `ship_handlings_screen.dart:121` | partiel |
| `PdfCreationService` (images/scan -> PDF, **duplique DODLP/IFFD**) | dodlp `services/pdf_creation_service.dart:11`; iffd idem | mature |
| Export Excel/PDF DataGrid (syncfusion) | dodlp `dynamic_list_screen.dart:1037` | mature |
| `FileSaveHelper` (imports conditionnels web/mobile, **web vide**) | dodlp `save_file_mobile.dart:16` | partiel |
| Module `file_manager` (`ErpFile` + `CustomCacheManager`) | dodlp `file_manager/.../erp_file.dart:13` | partiel |
| Upload image direct legacy `pickCropAndSetImage` (FirebaseStorage direct) | dodlp `functions.dart:1051`; dlcfti `functions.dart:937` | buggy |

IFFD : **pas de champ fichier generique** (upload feature-par-feature). Export PDF IFFD deporte sur endpoint IA distant.

### 2.9 Champs specialises (geo / telephone / pays / stepper)

| Element | Existe ou | Maturite |
|---|---|---|
| `GeoShape` (modele geo agnostique SDK, geometrie spherique) | dodlp `models/geo_shape.dart:23` | mature (DODLP seul) |
| Pattern adaptateur carte (`MapAdapter` -> Google/OSM) | dodlp `.../geofence_field/maps/map_interface.dart:4` | mature |
| `GeofenceField` (editeur carte, 1692 l. monolithe) | dodlp `.../geofence_field.dart:17` | mature |
| `GeoFieldConfig` / `GeoEditorToolbarConfig` (presets) | dodlp `models/geo_field_config.dart:8`, `geo_editor_config.dart:7` | mature |
| Champ telephone international (`intl_phone_number_input`) | dodlp `.../phone_number_infos.dart:5`; dlcfti idem | mature (defauts Togo en dur) |
| Pays/Etat (`Country` + `WORLD_COUNTRIES` 1.1 Mo, **country DEPRECATED/buggy**) | dodlp `models/country.dart:55`, `constants/world_countries_states.dart:7` | buggy |
| Devise (`formatedCurrency`, `WORLD_CURRENCIES`) | dodlp `constants/world_currencies.dart:8`, `functions.dart:341` | mature |
| MCC/MNC operateurs (843 Ko) | dodlp `constants/mccmnc.dart:2` | mature |
| Stepper configurable (`StepperConfig` + `dynamic_stepper.dart` 868 l.) | dodlp `models/stepper_config.dart:40` | mature |
| `google_maps.dart` (**cle API Google en clair commitee**) | dodlp `google_maps.dart:9`; dlcfti `google_maps.dart:12` | risque securite |

IFFD n'a rien de geo/pays/stepper ; `phoneNumber` dans l'enum sans widget.

### 2.10 Localisation (l10n)

| Element | Existe ou | Maturite |
|---|---|---|
| Delegate custom (`LocalizationsDelegate`, PAS gen-l10n/ARB) | iffd `l10n/localizations_delegate.dart:62`; dodlp/dlcfti idem | mature |
| Contrat abstrait `DataCrudLocalizationsData` (**enumere ressources metier**) | iffd `l10n/messages/abstract.dart:7`; dodlp/dlcfti idem | mature (non generique) |
| Extension `TrExtension` (grammaire FR codee en dur) | iffd `abstract.dart:56-133` | mature |
| Impl francaise `Fr` (seule reelle) | iffd `l10n/messages/fr.dart:6` | mature |
| **Stubs de langues** (`class En extends Fr {}` = fausses traductions) | dodlp `l10n/messages/en.dart:1`; dlcfti idem | buggy |
| Singleton statique mutable `DataCrudLocalizations.current` (48x IFFD) | iffd `localizations_delegate.dart:27` | partiel (anti-pattern) |
| Override `withDefaultOverrides` (**code mort**) | iffd `localizations_delegate.dart:56` | non branche |

---

## 3. Catalogue complet des types de champs

Base canonique = enum `EditionFieldTypes` de DODLP (union 37-40 valeurs). Colonne « Affichage liste » = capacite via `DynamicListField`.

| Type | Edition | Affichage liste | Config specialisee | Projets (implemente) |
|---|---|---|---|---|
| `text` / multiline | TextFormField (minLines/maxLines, formatters, suggestions Autocomplete) | valueToString | inputType | iffd, dodlp, dlcfti |
| `number` / `integer` / `float` | TextFormField numerique, `formatedNumber` | formatedNumber | minValueKey/maxValueKey, isCurrency/isPercentage | iffd, dodlp, dlcfti |
| `boolean` | Switch/toggle | texte | — | iffd, dodlp, dlcfti |
| `dateTime` / `timestamp` / `time` | date/time picker | InputType format | firstDateKey/lastDateKey, min/maxDate | iffd, dodlp, dlcfti |
| `select` / `radio` / `checkbox` | awesome_select (S2) | valueToString | choiceItems/choiceLabelKey/choiceValueKey | iffd, dodlp, dlcfti |
| `crudDataSelect` (relation) | select via `CrudRepository<T>` stream + edition inline | label | choiceItemsRepository/RequestBuilder | iffd, dodlp, dlcfti |
| multi-select (`multiple=true`) | SmartSelect multi | liste | — | iffd, dodlp, dlcfti |
| `rowChips` | puces horizontales | — | — | iffd, dodlp, dlcfti |
| `tags` (saisie libre) | flutter_tags | Wrap Chip | — | **dodlp** |
| `subItems` (liste imbriquee) | `DynamicSubListScreen` mini-CRUD | DataTable | subItemsFieldsBuilder/FormFieldsBuilder | iffd, dodlp, dlcfti |
| `dynamicItem` / `DeepAttribute` | sous-formulaire `DynamicEditionScreen<Map>` | texte | subItemsFormFieldsBuilder | dodlp, dlcfti |
| `file` / `image` / `document` | `AppFileEditionField` | ErpFilePreview (dodlp) | `FileFieldConfig` | **dodlp** (iffd declare non-impl.) |
| `location` / `geoArea` | `GeofenceField` (point/polygone/cercle) | — | `GeoFieldConfig` | **dodlp** |
| `phoneNumber` (intl) | `InternationalPhoneNumberInput` | texte | defauts Togo | dodlp, dlcfti (iffd non-impl.) |
| `country` | country_picker (**buggy**) | countryNameWithEmoji | WORLD_COUNTRIES | dodlp, dlcfti |
| `address` / `addressSearchField` | TextFormField streetAddress / Google Places | texte | validateur address | dodlp, dlcfti |
| `rating` | rangee 5 etoiles | num | — | **dodlp** |
| `slider` | Slider Material | double | min/max/divisions | **dodlp** |
| `signature` | package signature | image | — | **dodlp** |
| `color` | color picker (recentColors) | swatch | — | iffd, dodlp, dlcfti |
| `icon` | **non implemente (fallback)** | — | — | iffd, dodlp (declare) |
| `markdown` / `inlineMarkdown` | editeur Quill (iffd) / markdown_editor (dodlp) | rendu limite | RichTextToolbarConfig | iffd, dodlp |
| `html` / `inlineHtml` | html_editor_enhanced | widget Html | Toolbar | iffd, dodlp, dlcfti (`inlineHtml` iffd non-impl.) |
| `RichText` (Type dlcfti -> html) | html | Html | — | dlcfti |
| `stepper` | regroupement multi-etapes | — | `StepperConfig` + grille responsive | **dodlp** |
| `password` | validateur seul (pas de case dedie) | masque | — | iffd, dodlp, dlcfti (partiel) |
| `hidden` | **non rendu** | — | — | iffd, dodlp, dlcfti |
| `widget` (builder libre) | closure `(editionState, readOnly, setState)` | — | — | iffd, dodlp, dlcfti |

Validation transverse : `Map<String,dynamic> validators` -> `FormBuilderValidators.compose` (required, minLength, maxLength, min/max avec `minValueKey`/`maxValueKey`, equal, notEqual, match, matchKey, email, url, ip, creditCard, tgPhoneNumber, numeric, integer, dateString, address, percentage, password) + `stateValidators`.

---

## 4. Le bug critique du rafraichissement de formulaire

> **Objectif produit majeur.** Ce defaut est present a l'identique dans les trois projets (compteurs de `setState` : DODLP=35, DLCFTI=24, IFFD=18) et n'a JAMAIS ete corrige — meme IFFD (Riverpod 3) n'a pas migre `edition_screen.dart` (seul `dynamic_list_screen.dart:397` est `ConsumerStatefulWidget`).

### 4.1 Mecanisme precis (cause racine)

**1. Le formulaire entier est UNE seule `State`.**
`DynamicEditionScreenState extends State` (iffd `edition_screen.dart:164` — State pur, PAS ConsumerState ; dodlp `:206` avec DodlpMixin ; dlcfti `:167`).

**2. Chaque frappe declenche un rebuild GLOBAL.**
`onChanged: (v) => _onSubmit(v)` (dodlp `:1159`, dlcfti `:703`, iffd `:1072`), et `_onSubmit` mute `item` puis appelle un **`setState(() {})` VIDE** (dodlp `:1098`->`:1114` ; dlcfti `:651`->`:663` ; iffd `:1022`->`:1034`).

**3. Toute la construction des champs est une closure recreee dans `build()`.**
`_buildFormField` est declaree LOCALEMENT dans `build()` (dodlp `:401`, dlcfti `:290`, iffd `:462`). A chaque `setState`, `build()` re-execute et reconstruit RECURSIVEMENT tous les champs : chaque `FormBuilderTextField` re-instancie, `validators<R>()` recalcule (dodlp `:607`, iffd `:551`), `InputDecoration`/gradients recomputes (`_buildPremiumDecoration` iffd `:296`) -> jank a chaque frappe.

**4. Perte de focus / saut de curseur = instabilite de reconciliation des `Element`s :**

- **(a) Listes de champs SANS key stable.** `Column(children: field.childreen.map(...).toList())` et `widget.formFields.map(...).toList()` n'ont pas de key (dodlp `:4192,538` ; dlcfti `:2390,293` ; iffd `:3860,481`). `displayCondition` reevalue a chaque build renvoie `EmptyContainer` quand faux, et `field.onChange` peut muter `editionState` -> **le nombre/ordre des champs visibles change entre deux rebuilds**. Le matching par index (faute de key) reattribue le mauvais `Element`/`FocusNode` -> focus perdu.
- **(b) `initialValue` recalcule** depuis `item` fraichement mute et repasse a chaque rebuild sans `TextEditingController` stable (controller null sauf `field.stateController`) ; racine `FormBuilder(initialValue: item)` (dodlp `:4191`, dlcfti `:2389`, iffd `:3859`).
- **(c) Wrapper `Autocomplete`** avec `initialValue: TextEditingValue(text: fieldValue)` recalcule a chaque rebuild (dodlp `:1233`, dlcfti `:714`, iffd `:1086`).

**5. Ce qui N'EST PAS la cause.** reflectable court-circuite pour les Map (`item` est toujours `Map<String,dynamic>`), donc hors hot-path. Aucun debounce n'existe. La version `flutter_form_builder` n'est pas discriminante (DODLP v10 buggue comme DLCFTI v9). Le `Builder` enveloppant d'IFFD (`:462`) n'isole pas du `setState` parent.

### 4.2 Prescription de conception (cible zcrud)

1. **Supprimer le `setState` global.** Deplacer `item`+`editionState` dans un Notifier Riverpod 3 codegen (`@riverpod class EditionForm extends _$EditionForm`), etat immuable freezed. Mutations via methodes du notifier, jamais via `setState` de la `State`.
2. **Un champ = un `ConsumerWidget` top-level par type**, qui `ref.watch(editionFormProvider(formId).select((s) => s.values[name]))` : SEUL ce champ se reconstruit quand SA valeur change.
3. **`TextEditingController` STABLE par champ** : cree une seule fois (initState du widget de champ / registre keye par `field.name`), jamais recree au rebuild. `onChanged` ecrit dans l'etat avec **debounce ~250ms** ; on ne re-injecte JAMAIS la valeur dans le controller (plus de reset selection).
4. **Key stable obligatoire** : `ValueKey(field.name)` (jamais `hashCode`). Champs conditionnels : reserver une place stable (`Offstage`/`SizedBox` keye) plutot que retirer l'`Element`.
5. **Separer structure vs valeurs** : la visibilite (`displayCondition`) derivee dans un selecteur dedie ; seul un changement de visibilite reconstruit la LISTE.
6. **Validation ciblee** : `AutovalidateMode.onUserInteraction` par champ, erreur calculee dans le widget (ou via selecteur d'erreur du provider) ; memoiser les validateurs par champ.
7. **Extraire `_buildFormField` hors de `build()`** : un widget par type (`ZcrudTextField`, `ZcrudNumberField`...) const-constructible + `RepaintBoundary` ; le dispatcher choisit le widget selon `field.type` avec key stable.
8. **Generaliser le seul bon modele existant** : `MarkdownEditionField` (`markdown_edition_field.dart:21`) possede deja son propre controller isole et ne remonte que via callback — a etendre a TOUS les types.
9. **Cycle de vie des controllers** : creer en initState/didUpdateWidget, disposer en dispose (IFFD a le `dispose` commente = fuite).

---

## 5. Strategie recommandee : serialisation & etat

### 5.1 Serialisation — 100% codegen, abandon de reflectable

**Constat** : aucun des trois projets ne fait de vrai codegen de modeles ; DODLP/DLCFTI reflechissent (`invokeItemGetter/Setter`) mais doivent quand meme ecrire a la main le registre `Type->fromMap` ET tout le `toMap/fromMap` (reflectable n'automatise PAS la (de)serialisation). IFFD a retire reflectable mais garde le meme registre manuel. Double cout partout.

**Decision** :

- **Bannir reflectable** (confirme faisable : IFFD tourne sans). Impose `initializeReflectable()` par entry point + `.reflectable.dart` par fichier de test, incompatible avec Riverpod 3 / lex_douane.
- **`zcrud_annotations`** : `@ZcrudModel`, `@ZcrudField(label:, type:, validators:, choices:...)`, `@ZcrudId`.
- **`zcrud_generator`** (build_runner) : genere pour chaque modele `toMap/fromMap/copyWith/props/==/hashCode` ET le schema `List<DynamicFormField>` ET l'enregistrement dans un `ZcrudRegistry.register<T>(fromMap, toMap, schema)`.
- **Le modele devient source unique de verite** : le schema de formulaire est DERIVE des annotations (elimine la classe de bugs `field.name` <-> propriete par cle String).
- **Registre genere, echec explicite** : `throw` si un type non enregistre (jamais de `createInstance?.call() as T` -> cast null silencieux).
- Adosser a **freezed 3 + json_serializable 6** pour les modeles la ou pertinent (aligne lex_douane/IFFD). Pour lex_douane, prevoir un adaptateur car ses entites sont en `@JsonSerializable` PUR avec schema verrouille (ne pas imposer un 2e modele concurrent).

### 5.2 Gestion d'etat — Riverpod 3 codegen, rebuilds granulaires

- **Paradigme UNIQUE = Riverpod** (`riverpod_annotation`/`riverpod_generator` ^4, aligne IFFD/lex_douane). Retirer flutter_clean_architecture Controller et GetX (Rx/service-locator/GetStorage) du moteur. **⚠️ Superseded (architecture 2026-07-09, AD-15) :** la décision finale est une **réactivité Flutter-native** (`ChangeNotifier`/`ValueListenable`, aucun gestionnaire d'état dans le cœur) + **bindings multi-gestionnaire** (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`). Riverpod n'est donc **pas** imposé ; ce qui précède reste l'analyse du code existant.
- **Superposition de providers** (modele IFFD `folder_providers.dart`) : repository providers -> stream providers -> providers derives -> Notifiers. `autoDispose` par defaut ; `keepAlive:true` reserve aux singletons ; family via parametres nommes requis pour le per-ressource.
- **Rebuilds granulaires** : un champ = un `ConsumerWidget` qui `.select` sa tranche d'etat (cf. section 4.2).
- **Injection framework-neutre** : DODLP n'a PAS Riverpod (GetX/get_it/provider). L'injection zcrud doit passer par des **seams** (providers qui `throw` par defaut, override dans `ProviderScope`, cf. `core_providers.dart:8` + `main.dart:150`) **ET** un mode `InheritedWidget`/locator pour DODLP. Prevoir `zcrud_riverpod` optionnel + adaptateur DODLP delegant a `getIt<DodlpController>()`.
- **Interdire** `ProviderScope.containerOf(context).read(...)` dans le code du package ; toujours passer par `WidgetRef` (ref.watch reactif, ref.read en callback).
- **Bannir le singleton statique `DataCrudLocalizations.current`** au profit de `of(context)`/provider.

---

## 6. Decoupage monorepo propose (melos)

| Package | Responsabilite | Contenu extrait (source) | Deps externes | Depend de |
|---|---|---|---|---|
| **zcrud_core** | Coeur pur-Dart/Flutter : contrats, moteur edition+liste, champ fichier generique, l10n generique. AUCUN modele metier, AUCUN Firebase. | `EditionFieldTypes` (dodlp models.dart:44), `DynamicFormField` refactore (coeur + configs), moteur `DynamicEditionScreen`/`DynamicListScreen` reecrit (rebuilds granulaires), `CrudRepository<T>`/`DataState`/`DataRequest` neutres (promus depuis iffd src/), `RessourceACL`, `AppFile`+`FileFieldConfig`+`AppFileEditionField`+`AppFileUploadService`, `ResponsiveFormRow`, `StepperConfig`+`DynamicStepper`, `DynamicItemsNotifier`, l10n delegate generique | flutter_form_builder, form_builder_validators, awesome_select, flutter_riverpod, intl | — |
| **zcrud_annotations** | Annotations + contrat de codegen. | `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` (a creer) | — | zcrud_core |
| **zcrud_generator** (dev) | Builder build_runner generant serialisation + schema + registre. | (a creer) | build, source_gen, build_runner | zcrud_annotations, zcrud_core |
| **zcrud_markdown** | Editeur riche Quill<->Delta<->Markdown + embeds LaTeX/tableaux + lecteur. | `RichTextEditorScreen`, `QuillMarkdownEditorWrapper`, `RichTextToolbarConfig`, helpers de conversion, `QuillDefaultStylesHelper`, embeds `FormulaBlockEmbed`/`RenderComplexLatex`/`FormulaEditDialog`/`TableViewEmbedBuilder`/`TableEditorScreen` (iffd, source de reference) | flutter_quill ^11.5, markdown_quill, markdown, flutter_markdown_plus, flutter_markdown_latex, flutter_math_fork, (flutter_tex **optionnel**), flutter_quill_delta_from_html | zcrud_core |
| **zcrud_mindmap** | Viewer + editeur outline + tree-ops purs. | `MindmapNode`/`MindmapData` pur (sans FolderContentModel/Firestore), `MindmapView` (iffd `graphite_mindmap_viewer.dart` + API parametrable dodlp), `MindmapTreeOps`, editeur outline corrige | graphite, (flutter_flow_chart **optionnel** -> eventuellement zcrud_flowchart), collection | zcrud_core, zcrud_markdown |
| **zcrud_flashcard** | Flashcards + SRS + modes + generation (ports abstraits). | Coeur SRS `Sm.calc`+`FlashcardRepetitionInfo`+enums (pur, sans Flutter), `FlashcardModel` decouple de FolderContentModel, `applyTestExamFilters`, widgets unifies (1 `QuestionInput` + 1 `QuestionAnswerView`), ports `FlashcardRepository`/`AiFlashcardService` | flutter_card_swiper, flip_card, confetti, dots_indicator, segmented_progress_bar | zcrud_core, zcrud_markdown, zcrud_export (PDF) |
| **zcrud_firestore** | Adaptateur backend Firestore (isole cloud_firestore). | `FirebaseCrudRepositoryImpl<T>` debugge (limit, batch/transaction, catch(_){}), traduction `DataRequest`->`Filter` (`toCombinedFilter`), withConverter, count, streamByIds, `FirebaseCloudStorageRepositoryImpl`, pagination curseur (a ajouter) | cloud_firestore, firebase_core, firebase_auth, firebase_storage | zcrud_core |
| **zcrud_geo** | Champs geo (deps natives isolees). Coeur pur + adaptateurs. | `GeoShape`/`GeoPoint`/`GeoShapeStyle` (pur), `MapAdapter`/`UnifiedMapController`, `GeofenceField` decoupe, `GeoFieldConfig`/`GeoEditorToolbarConfig`, sous-adaptateurs Google/OSM optionnels | google_maps_flutter, flutter_osm_plugin, geolocator, flex_color_picker | zcrud_core |
| **zcrud_export** | PDF + export tabulaire (source unique dedupliquee). | `PdfCreationService` (dedup DODLP/IFFD), helper export DataGrid Excel/PDF factorise, `FileSaveHelper` (web a implementer), previsualisation PDF | pdf, printing, syncfusion_flutter_pdf/xlsio | zcrud_core |
| **zcrud_intl** (optionnel) | Telephone international + pays/etat/devise. | Champ `phoneNumber`, `Country`/`CountryState`, `formatedCurrency`, constantes en **assets JSON** (pas 2 Mo de const) | intl_phone_number_input, country_picker, intl | zcrud_core |

**Justifications d'inclusion/fusion :**
- **zcrud_core** absorbe le champ fichier (couplage limite a l'interface `CloudStorageRepository`) et le stepper/responsive (pur Flutter) — pas de raison de les isoler.
- **zcrud_markdown** separe car flutter_quill + flutter_tex + html_editor_enhanced sont lourds et absents de lex_douane ; `flutter_tex`/`html_editor_enhanced` rendus **optionnels** (WebView, CDN, multi-plateforme fragile).
- **zcrud_mindmap / zcrud_flashcard** separes car specifiques IFFD et tirant des packages UI dedies ; le mode flowchart (deserialisation Dashboard fragile) peut aller dans un `zcrud_flowchart` a part.
- **zcrud_firestore** isole imperativement cloud_firestore (`Timestamp`/`Filter`/`FirebaseException` fuient aujourd'hui dans le domaine) pour garder `zcrud_core` backend-agnostic et honorer l'intention multi-backend (stub Supabase IFFD).
- **zcrud_geo** obligatoirement separe (deps natives + permissions + cle Maps).
- **zcrud_export** dedupliquе `PdfCreationService` (identique DODLP/IFFD) et le code export DataGrid (duplique list/streamed) ; acter la contrainte de licence commerciale Syncfusion.
- **zcrud_intl** : constantes de 2 Mo (mccmnc/countries/currencies) a transformer en assets versionnes ; a fusionner dans core seulement si on accepte les deps.

---

## 7. Risques d'extraction & couplages applicatifs (par package)

### zcrud_core
- **BLOQUANT — registre manuel `fromMap<T>`** : `functions.dart` importe ~35 modeles metier de 11 modules (dodlp `functions.dart:7-93,709-751` ; iffd `data_functions.dart:337`). Dependance circulaire framework<->modeles. *Resolution : inverser via `ZcrudRegistry` injecte au bootstrap.*
- **BLOQUANT — god-object `DodlpController` via `DodlpMixin`** (`getIt<DodlpController>()`, dodlp_widgets.dart:22 ; `models.dart:10`). *Resolution : interface `CrudResolver` injectee.*
- **BLOQUANT — contrat + ACL hors module** : `CrudRepository`/`DataState`/`DataRequest` dans `src/`, `smartDelete(...,DodlpController?)` = circularite. *Resolution : promouvoir dans zcrud_core, retirer le param DodlpController.*
- `DynamicFormField` transporte des Widget/Function/callbacks non serialisables (toMap/fromMap ne les serialise pas) + deps UI (awesome_select S2ChoiceType). Melange modele/presentation.
- Couplage GetX (Get.back/Get.width/Get.bottomSheet), theme app (`kNavyColor`/`kFormInputDecorationTheme`), persistance UI (GetStorage/SharedPreferences), `AppPlatform` (module metier alors que `responsive_utils.dart` existe).
- `AppFile` couple au singleton `dodlp` + Firestore + convention cloudPath codee dans ecrans metier.

### zcrud_annotations / generator
- Necessite d'inverser la dependance de mapping (registry injecte par l'app). Adaptateur codec double : reflectable-backed (transition DODLP) vs enregistrement explicite/freezed (IFFD/lex_douane).

### zcrud_markdown
- Format ambigu (Delta JSON persiste pour champs `markdown`) : figer un canonique avant extraction.
- Couplage GetX (`Get.back`/`Get.height` `rich_text_editor_screen.dart:327`), helpers `forms_utils` (showPushedDialog), import circulaire embeds->screen (`RichTextReaderScreen`).
- Deps CDN (google_fonts, KaTeX, MathJax) non hors-ligne ; `flutter_tex` (WebView lourd) ; `flutter_svg` transitif non declare.
- Code mort (quillHtml commente, syncfusion table embeds, TableSizePickerDialog), bug de localisation d'embed par egalite de valeur, `newCellValue` global mutable, chaines FR en dur.
- DODLP importe `flutter_quill_delta_from_html` **absent de son pubspec** (fichier douteux) — prendre **IFFD** comme source.

### zcrud_mindmap
- `MindmapModel extends FolderContentModel` + `cloud_firestore` Timestamp dans `fromMap:360` ; couplage data_crud (DynamicEditionScreen/RichTextReaderScreen), GetX+AutoRoute+Riverpod melanges. Seuls `MindmapView` + `MindmapTreeOps` sont proprement extractibles. `get` juste pour `firstWhereOrNull` (-> collection).

### zcrud_flashcard
- Couplage Firestore (Timestamp), `FolderContentModel`/`DynamicModel`, data_crud, couche IA 100% IFFD (`IffdAiRouterModel`, endpoints `smart-learning.zakarius.com`), constantes douanieres SH en dur, `SmartLearnController` (god-object 20+ repos), export PDF via endpoint distant + assets polices IFFD.

### zcrud_firestore
- cloud_firestore fuit dans le domaine (`toCombinedFilter` retourne `Filter`, `FirestoreDataState` expose `FirebaseException`). Bugs a corriger a l'extraction (limit, batch, catch silencieux, null=erreur). Versions divergentes (firebase_storage 12 vs 13). Schema implicite : champs `id`/`deleted`/`canBeDeleted` imposes.

### zcrud_geo
- **SECRET — cle API Google Maps en clair** (`google_maps.dart`) : a sortir vers config plateforme. Deps natives lourdes + permissions. Defauts Togo en dur (+228/fr_TG/centre Lome). `GeofenceField` monolithe 1692 l. `country` DEPRECATED/buggy (`el.iso2 = fieldValue`). 2 Mo de constantes dupliquees.

### zcrud_export
- Licence commerciale Syncfusion (impact packaging). Endpoint IA distant IFFD (non portable, traiter en adaptateur `RemotePdfRenderer`). `badCertificateCallback => true` (`helpers.dart:160`) a retirer. Version web `FileSaveHelper` vide.

### l10n (dans zcrud_core)
- Contrat `DataCrudLocalizationsData` **non generique** (enumere ressources metier folderText/dduText/saiseText) ; couple a `Crud`/`CrudTitles`/`normalizedText` (src/) ; grammaire FR codee en dur ; `Intl.defaultLocale='fr_TG'` global ; stubs de fausses langues ; bugs de `name:` Intl dupliques. *Resolution : ne garder que le chrome CRUD generique + API registry pour les libelles metier fournis par l'app/feature.*

---

## 8. Chemin de migration des consommateurs

### 8.1 DODLP — banc d'essai prioritaire

DODLP importe data_crud depuis **180 fichiers** (couplage entrant sain = consommateurs). L'objectif : une PR ou seuls changent (a) les imports des consommateurs et (b) l'ajout d'une couche adaptateur mince — DodlpController, repos Firebase et bootstrap restent inchanges (retro-compatibilite prouvee).

Sequence :
1. **Creer `zcrud_core`** avec interfaces + deplacer `DataState`/`DataRequest`/`CrudRepository`/`RessourceACL` depuis `src/`; casser `smartDelete(DodlpController?)`.
2. **Parametrer `functions.dart`** : remplacer `factories`/`FIREBASE_COLLECTION_NAMES`/`FIREBASE_COLLECTION_LABELS`/`createInstanceOf` reflectable par un `ZcrudRegistry` injecte au bootstrap. Fournir un **adaptateur codec reflectable-backed** pour que DODLP conserve sa reflection sans lister les modeles.
3. **Migrer widgets/ecrans generiques** : remplacer `DodlpMixin` par `CrudResolver` injecte via un mode **`InheritedWidget`/locator** (DODLP n'a pas Riverpod). L'adaptateur delegue a `getIt<DodlpController>().getCrudRepository<T>()`.
4. **Abstraire les services** : `ZcrudPermissions` (adapte `AppUserPermissions`), `ZcrudToast` (`ToastService`), `ZcrudPlatform` (ou `responsive_utils`), `ZcrudConfig`/ThemeExtension (au lieu de `Get.find<AppSettings>` + `themes.dart`).
5. **Point d'injection** : apres `registerServices()` (`services_registers.dart`) et dans `MyApp.build` (`main.dart`), envelopper dans un `ZcrudScope` (resolver=DodlpController, permissions, toast, config, codec=ReflectableCodec). Preserver l'init 2 apps Firebase.
6. **Basculer les 180 imports** consommateurs vers `package:zcrud_*` ; supprimer le code duplique dans `src/`.
7. **Valider a chaque etape** que DODLP compile (reflectable + firebase 2 apps).

### 8.2 lex_douane — consommateur n°2 (le plus recent)

Monorepo Melos (Clean Arch 3 couches : `lex_core`/`lex_data`/`lex_ui` + apps `lex_douane` v1.5.3 et `lex_douane_admin`). Stack **identique a IFFD** (Riverpod 3.3.0, freezed 3.2.3, json_serializable 6.14, go_router 17, dartz 0.10.1, Firebase core4/firestore6/auth6, Dart ^3.12.2). Integration **greenfield** (aucune dep data_crud actuelle).

Priorites :
1. **Cibler les FORMULAIRES RICHES d'abord** (vrai vide) : ~87 fichiers (40 lex_ui + 47 admin) roulent des formulaires hand-rolled (TextEditingController+setState+PopScope). Consommer zcrud d'abord dans `lex_douane_admin` (`article_editor_screen`, `code_form_screen`, `tec_form_screen`) puis `lex_ui`.
2. **Flashcards/Mindmaps = integration ADDITIVE, pas remplacement** : lex_douane a deja un module « Etudier » mature (SRS/SM-2, offline-first Hive+Firestore, rendu chat) sur un **schema canonique VERROUILLE** (Enforcement n°3, `MindmapNode` sans copyWith, `@JsonSerializable` pur). Fournir des widgets zcrud **parametres par l'entite de l'app** (adaptateur), ne jamais imposer un 2e modele.
3. **Ports purs** : `zcrud_core` expose des ports persistence-agnostic (`Either<Failure,T>` dartz) que lex_douane branche sur ses repos.
4. **Reutiliser tel quel** `MindmapView` + `MindmapTreeOps` (deja persistence-agnostic) comme base de `zcrud_mindmap`.
5. **Gate de compatibilite** : verifier le dry-run de resolution des deps (flutter_quill + awesome_select + analyzer) contre le workspace **AVANT** tout code — `lex_aa7_lint` (custom_lint/analyzer 8.4.0) a deja du etre retire pour ne pas bloquer la montee riverpod/json. **reflectable est exclu** (incompatible codegen Riverpod 3).
6. **Contraintes NON-negociables lex_douane** : `ConsumerWidget`/`ConsumerStatefulWidget` uniquement, `Either<Failure,T>`, `ListView.builder`, pas de bang operator, full RTL (`EdgeInsetsDirectional`/`AlignmentDirectional`), a11y >=48dp+Semantics, `*.g.dart` generes, l10n injectable (zero dep a `lex_localizations`/`go_router` dans zcrud).

---

## 9. Questions ouvertes / decisions a trancher en phase architecture

1. **Format canonique du rich-text** : Delta JSON (source de verite Quill) avec export markdown/HTML a la demande, OU markdown pur ? Aujourd'hui incoherent (champ `markdown` = Delta JSON persiste). Impacte round-trip et interoperabilite chat lex_douane.

2. **Modele de champ freezed generique vs schema derive par annotations** : le codegen genere-t-il un `DynamicFormField` a partir des annotations du modele, ou expose-t-on un `DynamicFormField` construit a la main ? Comment concilier avec le schema **verrouille** `@JsonSerializable` de lex_douane (adaptateur vs generation) ?

3. **Injection framework-neutre** : quel mecanisme unique satisfait a la fois Riverpod (IFFD/lex_douane) et locator/InheritedWidget (DODLP) ? `ZcrudScope` InheritedWidget + `zcrud_riverpod` optionnel suffisent-ils ?

4. **Mode stepper** : corriger le bug (arbre stepper non enveloppe dans un `FormBuilder` -> validation/binding casses) — envelopper dans un unique FormBuilder ? Impact sur l'architecture de Notifier par champ.

5. **Sort du mode flowchart mindmap** : integrer dans `zcrud_mindmap` (deserialisation Dashboard `flutter_flow_chart` fragile) ou sortir en `zcrud_flowchart` separe ?

6. **`flutter_tex` et `html_editor_enhanced`** : optionnels (feature flags / sous-modules) ou supprimes ? Impact multi-plateforme (WebView desktop) et taille.

7. **Constantes lourdes** (mccmnc 843 Ko, countries 1.1 Mo, currencies 60 Ko) : assets JSON charges paresseusement, package de donnees separe `zcrud_geo_data`, ou const embarquees ? Impact taille binaire.

8. **Rendu liste vs edition** : unifier les deux definitions (deriver `DynamicListField` du meme type que `DynamicFormField`) ou garder disjoints ? Le rendu liste doit-il connaitre chaque type de champ ?

9. **Pagination** : ajouter la pagination par curseur (`startAfter`/cursor opaque) absente des trois projets — dans le contrat `ZQuery`/`DataRequest` neutre ou seulement dans `zcrud_firestore` ?

10. **Multi-backend** : maintenir le contrat `CrudRepository` exprimable en SQL/PostgREST (documenter `arrayContains` comme capacite optionnelle) pour concretiser le stub Supabase, ou assumer Firestore-first ?

11. **ACL et l10n metier** : dans un `zcrud_acl` optionnel + registry de libelles fourni par les features (`zcrud_flashcard`/`zcrud_mindmap`), ou hooks dans core ?

12. **Licence Syncfusion** (`zcrud_export`, rendu DataGrid) : acter la contrainte commerciale ou prevoir une abstraction `ZcrudListView` permettant un backend non-Syncfusion (Material DataTable) ?

13. **Strategie de test** : imposer des tests de round-trip serialisation et de conversion Markdown<->Delta (listes imbriquees, formules multi-lignes, tableaux, entites HTML) comme gate d'extraction — quel budget ?

14. **Correction des typos d'API publique** (`searchInpuCtrl`, `crudActionsButtionsBuilder`, `_buildLisBody`, `childreen`, `savetext`) : renommer proprement des la conception du package (rupture assumee vs alias de compat) ?
