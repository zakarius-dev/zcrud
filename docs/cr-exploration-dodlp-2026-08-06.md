# CR d'exploration — Ce que DODLP peut apporter à zcrud

> **Date** : 2026-08-06 · **zcrud analysé** : v0.53.0 (HEAD `c454dac`) · **Source DODLP** : `dodlp-otr`, branche `feat/zcrud-pilot`
> **Nature** : retour de terrain d'un pilote de migration réel. Constats et pistes — l'équipe zcrud arbitre et implémente.
> **Avertissement** : findings datés. zcrud évolue en parallèle ; recouper chaque point avant impl pour éviter les redites.

## 0. Objet & angle

Ce CR **n'est pas un ré-inventaire** du catalogue de champs (`docs/technical-inventory.md` §3 et `docs/dodlp-edition-parity-gap.md` le couvrent déjà). C'est un **retour de terrain** : DODLP a mené un pilote de migration réel (2 écrans portés — filtres « anciennes valeurs » livré, stepper agent restant), et ce document consigne ce que cette migration a **révélé après v0.53.0** : gaps de capacité restants, frictions d'adoption, et un verdict sur l'idée d'un satellite `zcrud_formfields_*`.

## 1. TL;DR

- **v0.53.0 a comblé la quasi-totalité** des 14 « bloquants » de `dodlp-edition-parity-gap.md`. Sur les 37 types DODLP : ~20 natifs au cœur, ~10 servis par satellites, **2 réellement orphelins** (`stepper`, `icon`).
- **1 gap de capacité majeur** : le **stepper *data-driven inline*** (déclaration en liste plate annotée `stepIndex`, façon DODLP) — `ZStepperEdition` existe mais exige des `steps` explicites. C'est ce qui bloque le portage du formulaire agent DODLP.
- **4 frictions d'adoption** issues du terrain (pas des bugs — des aspérités de migration à fort ROI) : ordre des champs piloté par la persistance, doc d'intégration git incomplète, `zcrud_get` qui force `auto_route ^11`, découvrabilité des types cœur.
- **Verdict `zcrud_formfields_*`** : **non** en bundle monolithique (redondant, contraire à AD-48/52/55/57). **Oui** sous la forme d'un composeur *manager-neutre* lifté hors de `zcrud_get`.
- **Zone à recouper par l'équipe** : les **listes/tableaux** (le `DynamicListScreen` DODLP, ~60 params, est très riche ; comparaison feature-à-feature avec `zcrud_list` non faite ici).

## 2. Déjà acquis côté zcrud — NE PAS refaire

Vérifié par lecture directe. Ce bloc existe pour **éviter les redites** : plusieurs mécanismes que DODLP aurait « apportés » sont déjà portés.

| Capacité DODLP | Statut zcrud v0.53.0 | Emplacement |
|---|---|---|
| `color` (roue HSV, multi) | **natif** + seam `ZcrudScope.colorPicker` | `families/z_color_field_widget.dart` (AD-52) |
| `signature` | **natif zéro-dép** (CustomPaint, pas le package `signature`) | `families/z_signature_field_widget.dart` |
| Plage de dates | **natif** `dateRange` | `families/z_date_range_field_widget.dart` (AD-47) |
| Rendu lecture (Card label/valeur + **copie presse-papier**) | **porté** | `edition/z_read_only_field_card.dart`, `z_read_only_value.dart` |
| Sections repliables **persistées** (parité GetStorage) | **porté** (seam neutre) | `edition/z_section_collapse_store.dart` |
| Tokens visuels DODLP (radius 12, bordure focus 2, padding 16, helperMaxLines 2, label flottant gras) | **portés** | `ZcrudTheme` (`presentation/theme/z_theme.dart`) |
| `displayCondition(item, state, crud)` | **porté** (arbre `ZCondition`, sources `state`/`persisted`/`context`) | `domain/edition/z_condition.dart` |
| `fieldSize.large` (Card) | **porté** | `edition/z_large_field_card.dart` |
| Navigation dérivée du breakpoint (dialog/sheet/page) | **porté** | `zcrud_navigation` : `presentEdition`, `ZPresentationPolicy` |
| markdown / html / geo / phone·country·address / media / pin·autocomplete·editableTable / select riche | **satellites** | `zcrud_markdown`, `zcrud_html`, `zcrud_geo`, `zcrud_intl`, `zcrud_media`, `zcrud_field_extras`, `zcrud_select` |
| Export Excel/PDF, liste Syncfusion | **satellites** | `zcrud_export(_pdf/_ui)`, `zcrud_list` |

**Sur l'apparence visuelle** (préoccupation explicite côté DODLP) : l'essentiel est déjà transférable via `ZcrudTheme` (tokens ci-dessus, câblés et vérifiés au pilote). DODLP reste une **référence de calibrage** utile, mais ce n'est plus un chantier de portage.

## 3. Gaps de capacité restants (actionnables)

### G1 — Stepper *data-driven inline* **[gap majeur]**
- **État zcrud** : `EditionFieldType.stepper` est classé `EditionFamily.unsupported` (`edition_field_family.dart:236`) → repli `ZUnsupportedFieldWidget`. Un `ZStepperEdition` + `ZStepperConfig` existent (`edition/z_stepper_edition.dart`), mais comme **widget wrapper distinct** exigeant `steps: List<ZEditionStep>` où **chaque étape énumère nommément ses champs**.
- **Modèle DODLP** : le stepper est un **type de champ** dans une liste plate `formFields` ; ses enfants portent `stepIndex/stepTitle/stepSubtitle/stepIcon` et le moteur **regroupe automatiquement** (sniffing `stepIndex`), y compris en **récursif** (`dynamic_stepper.dart`).
- **Pourquoi ça compte** : porter un formulaire stepper DODLP (ex. l'écran agent, 4 étapes) vers zcrud impose aujourd'hui de **restructurer manuellement** la liste plate en `List<ZEditionStep>` — non-1:1, source d'erreurs. C'est le point qui a stoppé le pilote agent.
- **Piste d'apport DODLP** : un **adaptateur** `List<ZFieldSpec>` annotés (via un `ZFieldConfig` portant `stepIndex/stepTitle/…`) → `List<ZEditionStep>`, réutilisant `ZStepperEdition`. Faible surface, gros gain de migration. À arbitrer : soit un vrai type de champ `stepper` servi par le registre, soit un helper de construction.
- **Note** : le `StepperConfig` DODLP déclare ~15 propriétés (orientation, indicatorPosition, style numbered/icons/progressBar/dots, couleurs, animations, builders) — **mais DODLP lui-même n'en honore que ~5**. Ne pas sur-spécifier `ZStepperConfig` en copiant une intention non tenue ; se caler sur l'usage réel.

### G2 — `icon`
- Toujours en fallback étiqueté ABSENT (question ouverte OQ-6, `zcrud_field_extras`). Type mineur (peu/pas utilisé en prod DODLP). À compléter ou acter comme non-parité.

### G3 — `inputFormatters` / `textCapitalization` sur `ZTextConfig`
- `ZTextConfig` porte `minLines/maxLines/keyboardType` mais **pas** de formateurs de saisie. DODLP a `uppercaseFormatter`/`lowerCaseFormatter`/`ucFirstFormatter` largement utilisés (codes douaniers en majuscules). Contournement pilote : normalisation **à la soumission** (valeur finale identique, mais l'UX diffère pendant la frappe). Petit ajout à fort confort de migration.

## 4. Frictions d'adoption (retour terrain — fort ROI, faible coût)

Ce ne sont pas des bugs mais des aspérités qui **coûtent du temps à chaque migration**. Les remonter est peut-être l'apport le plus utile de DODLP.

### F1 — L'ordre d'affichage est piloté par la persistance, pas par le schéma **[piège silencieux]**
- `ZFormController` amorce `visibleFields` sur `initialValues.keys` ; `DynamicEdition` rend **dans cet ordre**, pas dans celui de la liste `fields`. Conséquence : migrer en passant le `toMap()` d'un modèle fait dépendre l'affichage de l'ordre de la Map de persistance — **silencieusement** (aucune erreur). Au pilote, des champs sont « disparus » sous la ligne de flottaison jusqu'à passage explicite de `visibleFields`.
- **Piste** : quand `fields` est fourni, ordonner par `fields` par défaut (ou avertir/documenter). C'est le premier écueil que rencontrera toute app migrant depuis un modèle.

### F2 — `docs/private-git-consumption.md` incomplet
- La doc prescrit de déclarer chaque dépendance transitive en git. **Insuffisant** : les deps inter-`zcrud_*` sont des contraintes *hosted* (`zcrud_core: ^0.x`), et pub refuse deux sources pour un même package → `version solving failed`. Il faut des **`dependency_overrides`** forçant la source git sur toute la fermeture. À ajouter à la doc (bloque le premier `pub get` sinon).

### F3 — `zcrud_get` force `auto_route ^11`
- `zcrud_get` (binding pourtant désigné « cible DODLP ») dépend de `reflectable ^5.2.3` → `reflectable_builder` → `analyzer` récent → `auto_route_generator ≥10.5` → **`auto_route ^11.1.0`**. Une app sur `auto_route 10` (DODLP) ne peut pas tirer `zcrud_get` sans montée majeure du routage. Au pilote, `zcrud_get` a dû être écarté (le cœur marche sans binding, AD-15). À signaler : le binding « cible DODLP » est en l'état inutilisable pour DODLP.

### F4 — Découvrabilité des types cœur
- Au pilote, un `ZDateRangeField` **custom** a été créé… alors que `z_date_range_field_widget` (`dateRange`, AD-47) **existait déjà**. Symptôme d'un manque de **doc de découverte** (« quels types sont natifs vs satellites vs à enregistrer »). La table §7 ci-dessous vise à combler ce manque ; une version maintenue côté zcrud éviterait à chaque migrateur de réinventer l'existant.

## 5. Verdict — faut-il un satellite `zcrud_formfields_*` ?

**Idée examinée** : créer un satellite qui dépendrait des packages de rendu externes (flex_color_picker, signature, maps, quill, intl_phone, country_picker, awesome_select) et enregistrerait des builders pour chaque type.

**Réponse : non en bundle monolithique — le pattern existe déjà, mieux fragmenté.**

Trois raisons **de correction** (pas de goût) :
1. **`color`, `signature`, `select`/`radio` ne sont PAS des `kind` de registre.** `familyOf` les pré-route vers des **familles natives** avant `registryOrFallback`. Un builder registry pour ces kinds serait **du code mort jamais appelé** (AD-48 l'acte explicitement pour select/radio/relation). Le bon chemin est le **seam typé** : `ZcrudScope.colorPicker`, `ZSelectPresenter`.
2. **Duplication d'un outillage déjà arbitré** : color→seam (AD-52), select→`zcrud_select`/awesome_select vendorisé (AD-48), phone/country→`zcrud_intl` (`phone_numbers_parser`), maps→`zcrud_geo`. Réintroduire d'autres paquets recrée des **collisions de `kind`** (`register` throw) et contredit le choix de stack.
3. **Défaut zéro-dépendance impossible** (AD-57 condition 3) : un agrégateur qui hard-dépend de quill+maps+webview+crop **impose l'union de toutes les deps lourdes** à tout consommateur — l'anti-pattern exact que la fragmentation en satellites combat.

**Ce que le besoin réel réclame** (« un point de composition unique ») **existe déjà** : `registerZcrudFormFields` (AD-55, `zcrud_get/lib/src/presentation/z_form_fields_composer.dart`), avec seam `additionalRegistrars` pour l'opt-in une-ligne. **Mais il vit dans le binding GetX**, donc n'est pas manager-neutre.

**Recommandation** : **lifter ce composeur hors de `zcrud_get`** en une fonction/petit package *manager-neutre* (mêmes satellites câblés, même seam `additionalRegistrars`), laissant les seams non-registry (`selectPresenter`, `filePicker`, `colorPicker`) à l'app via `ZcrudScope`. On obtient l'ergonomie « un point de composition » **sans** créer un nœud de dépendance qui force le poids, et en respectant AD-55/56/57.

## 6. Zone à recouper par l'équipe — les LISTES

Non tranché dans ce CR (comparaison feature-à-feature `DynamicListScreen` ↔ `zcrud_list` non faite). Le `DynamicListScreen` DODLP (~60 paramètres de constructeur, `dynamic_list_screen.dart`) porte un ensemble riche que l'équipe voudra peut-être recouper :
- corbeille / soft-delete (`trashOnly`, partition deleted/unDeleted) ;
- onglets **persistés** (`DynamicTabsState` sur GetStorage : index + offsets de scroll) ;
- **historique CRUD** (`DynamicHystoryScreen`, sous-collection `crud_operations`, diff de versions) ;
- recherche client **sans accents**, multi-champ (`unaccentedText`) ;
- export Excel/PDF avec **en-tête PDF DODLP** (`dodlp_pdf_header`) ;
- sélection multiple, sous-listes (`DynamicSubListScreen`), actions de ligne gardées par ACL 11 flags ;
- pagination Firestore réelle (`StreamedDynamicListScreen` + `FirestoreQueryBuilder`).

Point d'architecture à signaler : côté DODLP, la décision « plateforme → mode fenêtre » n'est **pas** dans le helper de présentation mais **chez les appelants** (`dialog: widget.dialog || AppPlatform.isWebOrDesktop`). zcrud a déjà mieux (dérivation par breakpoint dans `presentEdition`) — donc ici **zcrud > DODLP**, à ne pas régresser.

## 7. Annexe — Table type → statut (référence de découverte)

| Type DODLP | Statut zcrud v0.53.0 | Rendu / satellite |
|---|---|---|
| text, multiline, password | **cœur** | `z_text_field_widget` (password = texte masqué) |
| number, integer, float | **cœur** | `z_number_field_widget` |
| dateTime, time | **cœur** | `z_date_field_widget` |
| **dateRange** | **cœur** (AD-47) | `z_date_range_field_widget` |
| boolean | **cœur** | `z_boolean_field_widget` |
| select, radio, checkbox | **cœur** + seam `ZSelectPresenter` | `z_select_field_widget` (+ `zcrud_select`/awesome_select) |
| relation (`crudDataSelect`) | **cœur** + registres | `z_relation_field_widget` + relation/choices/crud registries |
| tags | **cœur** | `z_tags_field_widget` |
| rowChips | **cœur** | `z_row_chips_field_widget` |
| rating | **cœur** | `z_rating_field_widget` |
| slider | **cœur** | `z_slider_field_widget` |
| color | **cœur** + seam `colorPicker` (AD-52) | `z_color_field_widget` / `z_color_multi_field_widget` |
| subItems | **cœur** | `z_sub_list_field_widget` (mini-CRUD imbriqué) |
| dynamicItem | **cœur** | `z_dynamic_item_field_widget` |
| signature | **cœur zéro-dép** | `z_signature_field_widget` |
| file, image, document | **cœur** + seams `filePicker`/`cloudStorage` ; média riche → `zcrud_media` | `z_app_file_field_widget` |
| markdown, inlineMarkdown, richText | **satellite** | `zcrud_markdown` (`registerZMarkdownFields`) |
| html, inlineHtml | **satellite** | `zcrud_html` (`registerZHtmlFields`) |
| location, geoArea | **satellite** | `zcrud_geo` (`ZGeoFieldWidget.builder`, adapters OSM/Google) |
| phoneNumber, country, address | **satellite** | `zcrud_intl` |
| pin, autocomplete, editableTable | **satellite** | `zcrud_field_extras` |
| widget (`freeWidget`) | **registre** (app) | `z_free_widget_field_widget` |
| custom | **registre** (app) | fourni par l'app |
| **stepper** | **repli `unsupported`** (G1) | wrapper `ZStepperEdition` (steps explicites) |
| **icon** | **repli** (G2) | planifié `zcrud_field_extras` |
| hidden | non rendu (voulu) | `SizedBox.shrink()` |

**Mécanisme de registre** (pour un satellite) : `ZWidgetRegistry.register(kind, builder)` où `kind == field.type.name` ; injecté via `ZcrudScope.widgetRegistry` ; `register` **throw** sur collision (jamais last-wins). Auto-enregistrement **explicite** au bootstrap (`registerZ<Pkg>Fields(registry)`), jamais par side-effect d'import. Seams non-registry co-injectés au scope : `selectPresenter`, `colorPicker`, `iconResolver`, `filePicker`, `cloudStorage`, `listRenderer`, `relationSourceRegistry`, `choicesSourceRegistry`, `relationCrudRegistry`.

## 8. Références

- **zcrud** (v0.53.0) : `packages/zcrud_core/lib/src/presentation/edition/{edition_field_family.dart, z_widget_registry.dart, z_read_only_field_card.dart, z_section_collapse_store.dart, z_large_field_card.dart}`, `packages/zcrud_core/lib/src/presentation/edition/families/z_date_range_field_widget.dart`, `packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart`, `packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart`, `_bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md` (AD-47..57). Docs connexes : `docs/dodlp-edition-parity-gap.md`, `docs/technical-inventory.md`, `docs/private-git-consumption.md`.
- **DODLP** (`dodlp-otr`, branche `feat/zcrud-pilot`) : `lib/modules/data_crud/{models.dart, forms_utils.dart}`, `lib/modules/data_crud/presentation/views/{edition_screen.dart, dynamic_list_screen.dart, streamed_dynamic_list_screen.dart, dynamic_history_screen.dart}`, `lib/modules/data_crud/presentation/widgets/dynamic_stepper.dart`, `lib/modules/data_crud/models/stepper_config.dart`. Findings reproductibles : F1 (test d'ordre), F2/F3 (`flutter pub get` réel), F4 (`ZDateRangeField` custom redondant).
