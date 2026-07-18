---
baseline_commit: ae3a6ad31c437e7c91350e7c69ba95aeabfa9cab
---
# Story 2.2: Point de composition binding + câblage markdown / intl / geo

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Epic source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md → Epic 2, Story 2.2 -->
<!-- Spine source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md → AD-55 (binds AD-1, AD-2, AD-4, AD-7, AD-12, AD-13) -->

## Story

As a intégrateur d'app (DODLP/GetX),
I want que le binding `zcrud_get` détienne **LE** `ZWidgetRegistry` et **compose** en un point unique le câblage des satellites de champs (markdown, intl `phoneNumber`/`country`/`address`, geo `location`) — via un composeur qui **appelle** les registrars/builders exposés par chaque satellite, jamais un fichier partagé que chaque satellite devrait éditer,
So that j'ai un point unique d'enrôlement, les satellites existants sont rendus sans réécriture, et l'ajout d'un satellite futur (`html`/`media`/`select`/`field_extras`) coûte **une ligne d'appel opt-in**, pas une refonte.

## Contexte & frontières (à lire avant de coder)

**Périmètre écriture : UNIQUEMENT `packages/zcrud_get/`.** Le cœur (`zcrud_core`) et tous les satellites d'adaptateurs (`zcrud_markdown`, `zcrud_intl`, `zcrud_geo`, `zcrud_html`, `zcrud_media`, `zcrud_select`, `zcrud_field_extras`) sont **LECTURE SEULE** — on les **référence** pour le câblage, on ne les modifie pas. Si un besoin cœur émerge (ex. un seam manquant), **STOP et signaler** — ne pas écrire dans `zcrud_core`.

**Hors périmètre :**
- PAS le showcase / harnais (`example/` — c'est fp-3 ; fp-3 **consomme** ce composeur, l'inverse est interdit).
- PAS de nouvel adaptateur de champ (aucun widget de champ créé ici).
- PAS d'écriture cœur (aucun ajout d'`EditionFieldType`, aucun seam nouveau dans `zcrud_core`).
- Story 2.1 (présentation cœur, familles natives) est **disjointe** : fichiers différents, aucun point de contact hors `zcrud_core` que fp-2-2 ne touche pas.

**Vérité de disque déjà établie (greps joués) :**
- `packages/zcrud_get/lib/` ne contient **AUCUN** composeur ni usage de `ZWidgetRegistry` aujourd'hui (grep négatif : `registerZcrudFormFields`, `registerZ`, `ZWidgetRegistry` → ABSENT). C'est un net-new dans le binding.
- `zcrud_get/pubspec.yaml` dépend aujourd'hui de `zcrud_core`, `zcrud_study_kernel`, `zcrud_navigation`, `zcrud_ui_kit` (+ `get`, `get_it`, `reflectable`, `flutter`). **Aucune** arête vers `zcrud_markdown`/`zcrud_intl`/`zcrud_geo` — à **ajouter** (arêtes SORTANTES du binding-puits).

## Acceptance Criteria

**AC1 — Le binding détient et compose LE registre (AR-4 / AD-55)**
**Given** le binding `zcrud_get`
**When** l'app bootstrap et appelle le composeur unique
**Then** le composeur enrôle les builders sur une instance `ZWidgetRegistry` **fournie par l'appelant** (jamais construite en singleton statique interne — AD-4) ; l'app injecte ce registre via `ZcrudScope.widgetRegistry` ; chaque satellite est câblé par **un seul appel** ; une **double composition** (ou double `register` d'un même `kind`) fait **`throw` `ZDuplicateRegistrationError`** (contrat `ZWidgetRegistry.register`, jamais un last-wins silencieux).

**AC2 — Pas de point de contact partagé (anti-pattern écarté)**
**Given** l'architecture du composeur
**When** on ajoute un satellite futur (`html`/`media`/`select`/`field_extras`)
**Then** **aucun satellite n'édite le fichier du composeur** : chaque satellite fournit **son** registrar (ex. `registerZMediaFieldWidgets`, `registerZHtmlFields`) ou son `.builder()` ; le composeur les **appelle** (satellites MVP câblés en dur) et **expose un seam d'extension opt-in** (`additionalRegistrars`) permettant à l'app d'enrôler un satellite non-MVP **en une ligne au site d'appel**, sans que le binding ne dépende de ce satellite ni que le composeur soit réécrit.

**AC3 — markdown (FR-21, voie rich-text par défaut)**
**Given** `zcrud_markdown`
**When** le composeur câble la voie markdown
**Then** `markdown` / `inlineMarkdown` / `richText` sont enrôlés via `registerZMarkdownFields(registry, codec: …)` ; un champ de **chacun** de ces `kind`, rendu **à travers le dispatcher `ZFieldWidget`** (pas en construction directe), atteint bien `ZMarkdownField` (controller Quill isolé, `ValueKey('z-markdown-<name>')`, AD-7/AD-2) ; la voie markdown est la voie rich-text **par défaut**.

**AC4 — intl : phoneNumber / country / address (FR-24, FR-25, FR-26)**
**Given** `zcrud_intl`
**When** le composeur câble intl
**Then** `registry.register('phoneNumber', ZPhoneFieldWidget.builder(…))` (**manquant aujourd'hui — aucun `registerZ` phone n'existe**) est ajouté ; `registry.register('country', ZCountryFieldWidget.builder(…))` est ajouté ; `registerZAddressFieldWidgets(registry, …)` est appelé (enrôle `address` **et** `addressSearchField`) ; un champ de chaque `kind`, rendu via le dispatcher, atteint respectivement `ZPhoneFieldWidget` / `ZCountryFieldWidget` / `ZAddressFieldWidget` ; les catalogues pays sont partagés (une seule lecture d'asset — `sharedDefaultCountryCatalog()` réutilisé par défaut). Défauts OQ-3/OQ-4 (sélecteur pays inline, validateur Togo `length:8`) restent ceux des widgets satellites (non ré-décidés ici).

**AC5 — geo : location (FR-27)**
**Given** `zcrud_geo`
**When** le composeur câble `location`
**Then** `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: …))` est ajouté (`geoArea` optionnel, même patron) ; un champ `location` rendu via le dispatcher atteint `ZGeoFieldWidget` ; le satellite reste isolé (**CORE OUT=0**), **aucun secret** (clé Maps) embarqué dans un package (AD-12) — `adapterFactory`/config viennent de la plateforme de l'app, injectés au site d'appel.

**AC6 — exclusivité html ⇄ markdown (AD-50)**
**Given** que `zcrud_markdown` et `zcrud_html` enregistrent tous deux `html`/`inlineHtml`
**When** l'app choisit sa voie de rich-text
**Then** le composeur ne câble **jamais** les deux voies simultanément : markdown par défaut ; la voie HTML WYSIWYG est un **opt-in** (via `additionalRegistrars`, l'app passe le `registerZHtmlFields` de `zcrud_html`) ; câbler les deux fait **`throw` `ZDuplicateRegistrationError`** sur le `kind` en collision — comportement **prouvé par test**, jamais masqué.

**AC7 — isolation deps & graphe (AD-1)**
**Given** les arêtes ajoutées au `pubspec.yaml` du binding
**When** `graph_proof` et `melos analyze` tournent
**Then** `zcrud_get` gagne des arêtes **SORTANTES** vers `zcrud_markdown`, `zcrud_intl`, `zcrud_geo` (satellites MVP) et **AUCUN** satellite ne dépend du binding (graphe **acyclique**, CORE OUT=0 inchangé — le cœur ne gagne aucune arête) ; les satellites non-MVP (`zcrud_html`/`zcrud_media`/`zcrud_select`/`zcrud_field_extras`) **ne sont PAS** ajoutés en dépendance du binding (ils entrent via le seam opt-in, au site d'appel de l'app).

## Tasks / Subtasks

- [x] **T1 — Composeur unique `registerZcrudFormFields`** (AC1, AC2, AC3, AC4, AC5)
  - [x] Créer `packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart` : fonction top-level `void registerZcrudFormFields(ZWidgetRegistry registry, {…})` opérant sur le registre **injecté** (jamais de singleton interne).
  - [x] Paramètres de composition (tous optionnels, défauts sûrs) : `ZCodec? richTextCodec` (markdown), `ZCountryCatalog? countryCatalog`, `ZSubdivisionCatalog? subdivisionCatalog`, `ZPlaceSearchProvider? placeSearch`, `ZMapAdapterFactory? geoAdapterFactory`, `bool wireGeoArea = false`, `Iterable<void Function(ZWidgetRegistry)> additionalRegistrars = const []` (seam opt-in html/media/select/field_extras).
  - [x] Corps : `registerZMarkdownFields(registry, codec: richTextCodec)` ; `registry.register('phoneNumber', ZPhoneFieldWidget.builder(catalog: countryCatalog))` ; `registry.register('country', ZCountryFieldWidget.builder(catalog: countryCatalog))` ; `registerZAddressFieldWidgets(registry, catalog: countryCatalog, subdivisionCatalog: subdivisionCatalog, placeSearch: placeSearch)` ; `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: geoAdapterFactory))` (+ `'geoArea'` si `wireGeoArea`) ; puis `for (final r in additionalRegistrars) r(registry);` **en dernier** (pour que les collisions opt-in throw de façon déterministe).
  - [x] Docstring : point de composition unique (AD-55), anti-pattern écarté (chaque satellite fournit son registrar, on l'appelle), catalogues partagés, exclusivité html/markdown.
- [x] **T2 — Arêtes de dépendance du binding** (AC7)
  - [x] `packages/zcrud_get/pubspec.yaml` : ajouter `zcrud_markdown: ^0.2.1`, `zcrud_intl: ^0.2.1`, `zcrud_geo: ^0.2.1` (mêmes contraintes inter-packages que l'existant). Commenter : arêtes SORTANTES du binding-puits, CORE OUT=0 intact, acyclique. **Ne PAS** ajouter html/media/select/field_extras.
  - [x] `dart pub get` / `melos bootstrap` pour résoudre. (RC=0 racine + example)
- [x] **T3 — Export barrel** (AC1)
  - [x] `packages/zcrud_get/lib/zcrud_get.dart` : `export 'src/presentation/z_form_fields_composer.dart';` avec commentaire (fp-2-2, composeur AD-55).
- [x] **T4 — Tests porteurs via le vrai dispatcher** (AC3, AC4, AC5, tous « présence≠association »)
  - [x] `packages/zcrud_get/test/z_form_fields_composer_test.dart` : `ZWidgetRegistry` réel, `registerZcrudFormFields(...)`, `ZcrudScope(widgetRegistry:)` + `ZFormController` + `DynamicEdition` réel, `pumpWidget`, et pour chaque `kind` (`markdown`/`inlineMarkdown`/`richText`/`phoneNumber`/`country`/`address`/`location`) : `find.byType(...)` `findsOneWidget` **et** `ZUnsupportedFieldWidget` `findsNothing` — association bout-en-bout via `tryBuilderFor(field.type.name)`.
  - [x] **R3 (test porteur, non-tautologique)** : oracle de mutation — MÊME arbre, registre VIDE (composeur non appelé) → `ZUnsupportedFieldWidget` `findsOneWidget` (+ widget satellite `findsNothing`) pour chaque kind. Si l'association casse, le test positif verrait ce repli → il rougit.
- [x] **T5 — Test exclusivité & double-composition** (AC1, AC6)
  - [x] `expect(() { registerZcrudFormFields(r); registerZcrudFormFields(r); }, throwsA(isA<ZDuplicateRegistrationError>()))` (double composition).
  - [x] Exclusivité html : `additionalRegistrars: [registerZHtmlFields, registerZHtmlFields]` → `throwsA(isA<ZDuplicateRegistrationError>())` sur `html`. Choix documenté : `zcrud_html` n'est PAS dep du binding ; on prouve AD-50 avec `registerZHtmlFields` de `zcrud_markdown` (voie HTML-via-Delta, DÉJÀ dep) qui revendique les MÊMES kinds `html`/`inlineHtml` que le WYSIWYG de `zcrud_html` → comportement identique. + test de coexistence (une seule voie html opt-in + markdown = kinds disjoints, pas de collision).
- [x] **T6 — Vérif verte + gates** (AC7)
  - [x] `dart analyze packages/zcrud_get` RC=0 ; `flutter test packages/zcrud_get` RC=0 (74 tests, dont 19 nouveaux). (Analyze/verify **repo-wide** délégués à l'orchestrateur au gate de commit — parallélisme actif fp-4-4/fp-5-2.)
  - [x] `python3 scripts/dev/graph_proof.py` : ACYCLIQUE OK, CORE OUT=0 OK ; arêtes sortantes `zcrud_get → zcrud_markdown/zcrud_intl/zcrud_geo` présentes, aucun satellite → binding. Scan secrets `zcrud_get/lib` : aucune clé Maps.

## Dev Notes

### Contrats satellites confirmés sur disque (signatures à appeler — LECTURE SEULE)

| Satellite | Symbole à appeler | Kinds enrôlés | Fichier source |
|---|---|---|---|
| `zcrud_markdown` | `registerZMarkdownFields(ZWidgetRegistry, {ZCodec? codec, int? minLines, int? maxLines, int? characterLimit})` | `markdown`, `inlineMarkdown`, `richText` | `lib/src/presentation/z_markdown_registration.dart:37` |
| `zcrud_markdown` (voie HTML-via-Delta) | `registerZHtmlFields(ZWidgetRegistry, {ZCodec? codec})` | `html`, `inlineHtml` | `lib/src/presentation/z_html_registration.dart:44` |
| `zcrud_intl` phone | `ZPhoneFieldWidget.builder({ZCountryCatalog? catalog, String? defaultIsoCode, …}) → ZFieldWidgetBuilder` — **pas de `registerZ`** ; le composeur appelle `registry.register('phoneNumber', …)` | `phoneNumber` | `lib/src/presentation/z_phone_field_widget.dart:66` |
| `zcrud_intl` country | `ZCountryFieldWidget.builder({ZCountryCatalog? catalog, …}) → ZFieldWidgetBuilder` — **pas de `registerZ`** ; `registry.register('country', …)` | `country` | `lib/src/presentation/z_country_field_widget.dart:55` |
| `zcrud_intl` address | `registerZAddressFieldWidgets(ZWidgetRegistry, {ZCountryCatalog? catalog, ZSubdivisionCatalog?, ZPlaceSearchProvider?, …})` | `address`, `addressSearchField` (`addressFieldKind`/`addressSearchFieldKind`) | `lib/src/presentation/z_address_field_widget.dart:51` |
| `zcrud_geo` | `ZGeoFieldWidget.builder({ZMapAdapterFactory? adapterFactory, ZGeoGeometry?, double mapHeight, …}) → ZFieldWidgetBuilder` — **pas de `registerZ`** ; `registry.register('location', …)` (+`'geoArea'`) | `location`, `geoArea` | `lib/src/presentation/z_geo_field_widget.dart:106` |

**Écart intl/geo à connaître :** phone/country/geo n'exposent **pas** de fonction `registerZ<Pkg>Fields` — seulement des `static ZFieldWidgetBuilder builder(...)`. Le composeur les enrôle donc par `registry.register('<kind>', X.builder(...))` en dur (les kinds sont les noms d'`EditionFieldType`, camelCase). C'est **conforme** à AD-55 (le binding est le point de composition) et **ne viole PAS** l'anti-pattern (le composeur appartient au binding ; aucun satellite n'édite un fichier partagé). Ne PAS ajouter ces `registerZ` dans les satellites (hors périmètre — lecture seule).

### Satellites non-MVP (seam opt-in, PAS de dépendance binding)

- `zcrud_html` : `registerZHtmlFields(ZWidgetRegistry)` (WYSIWYG, `lib/src/presentation/z_html_wysiwyg_registration.dart:45`) — enregistre `html`/`inlineHtml`, **exclusif** avec la voie markdown (AD-50).
- `zcrud_media` : `registerZMediaFieldWidgets(ZWidgetRegistry, {ZMediaFilePicker? picker, …})` (`lib/src/presentation/z_media_field_widget.dart:81`) — enrôle `mediaImage`/`mediaFile`/`mediaVideo`. Le `picker` doit AUSSI être injecté dans `ZcrudScope.filePicker` (seam séparé, hors composeur registre).
- `zcrud_select` : **pas un registrar de widget** — `ZSmartSelectPresenter` est une impl de `ZSelectPresenter` injectée via **`ZcrudScope.selectPresenter`** (seam de présentateur, pas `ZWidgetRegistry`). Donc **hors** du composeur registre ; c'est une composition de scope (fp-4). Le noter en docstring, ne PAS le forcer dans `additionalRegistrars`.
- `zcrud_field_extras` : **ÉCART — aucun registrar aujourd'hui** (grep : le barrel n'exporte qu'un `z_field_extras_placeholder.dart` ; `registerZ` ABSENT). Phase Finitions (AD-53). Le seam `additionalRegistrars` est **prêt** à le recevoir plus tard ; ne rien câbler maintenant.

Tous ces satellites passent par le **seam d'extension opt-in** `additionalRegistrars` (au site d'appel de l'app), pas par une dépendance du binding — c'est ce qui garde le graphe MVP minimal (AC7) et fait de l'ajout d'un satellite **1 ligne opt-in**.

### Seams de scope vs registre de widgets (frontière à ne pas confondre)

Le composeur fp-2-2 câble **UNIQUEMENT le `ZWidgetRegistry`** (association `kind → ZFieldWidgetBuilder`). Les autres compositions AD-55 sont des **valeurs de `ZcrudScope`**, distinctes et déjà présentes comme paramètres de `ZcrudScope` (`packages/zcrud_core/lib/src/presentation/zcrud_scope.dart`) :
- `ZcrudScope.widgetRegistry` (le registre composé ici),
- `ZcrudScope.selectPresenter` (`ZSelectPresenter?`, défaut `null` → rendu natif — fp-4),
- `ZcrudScope.filePicker` (`ZFilePicker?` — fp-5 média),
- `ZcrudScope.colorPicker` (`ZColorPicker?`, roue HSV `flex_color_picker` côté binding — AD-52).
Ces seams sont injectés par l'app/le `ZcrudGetScope` **à côté** du composeur ; fp-2-2 ne les recâble pas mais **documente** leur coexistence (l'app fait `ZcrudScope(widgetRegistry: reg, selectPresenter: …, filePicker: …)`).

### Dispatcher — chemin réel exercé par les tests (présence≠association)

`ZFieldWidget._buildFromRegistry` (`packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:699`) fait :
`ZcrudScope.maybeOf(context)?.widgetRegistry?.tryBuilderFor(field.type.name)` → si `null` ⇒ `ZUnsupportedFieldWidget`, sinon appelle le builder avec `ZFieldWidgetContext(field, value, onChanged: setValue)`. Les kinds markdown/phone/country/address/location ne sont **pas** pré-routés par `familyOf` (ce sont des types servis par le registre) ⇒ ils passent **réellement** par ce chemin. Un test qui monte `ZcrudScope` + `ZFieldWidget` et cherche `find.byType(ZMarkdownField)` prouve donc l'**association bout-en-bout**, pas juste que `register` fut appelé. Un test qui asserte seulement `registry.isRegistered('markdown')` serait **tautologique** — l'interdire (R3).

### AD-4 — jamais de singleton statique

`registerZcrudFormFields` prend le `ZWidgetRegistry` **en paramètre** (fourni/possédé par l'app via `ZcrudGetScope`/bootstrap). Interdit : une variable statique `_registry` dans le composeur, un `ZWidgetRegistry()` global, ou un enrôlement par side-effect d'import. AD-55 : « registre injecté via `ZcrudScope`, jamais un singleton statique ».

### Invariants applicables (rappel)

- **AD-1** : `zcrud_get` peut dépendre de plusieurs satellites (arêtes sortantes) ; **aucun** satellite ne dépend du binding ; graphe acyclique ; CORE OUT=0 (le cœur ne gagne rien).
- **AD-2** : le composeur ne touche pas la granularité de rebuild ; les builders satellites gèrent eux-mêmes leurs controllers isolés (Quill markdown, TextEditingController phone/geo créés 1× en `initState`). Le composeur ne passe **jamais** le `ZFormController` à un builder.
- **AD-4** : registre injecté, jamais statique ; registres/présentateurs sont des valeurs.
- **AD-7** : rich-text à controller isolé (assuré par `ZMarkdownField`, `ValueKey('z-markdown-<name>')`).
- **AD-12** : aucun secret (clé Maps) dans un package ; `adapterFactory` geo vient de la plateforme app.
- **AD-13** : RTL/a11y sont la responsabilité des widgets satellites (déjà livrés) ; le composeur n'introduit aucun style codé en dur.
- **AD-50** : exclusivité `html`⇄`markdown` sur `html`/`inlineHtml` ; collision `register` = `throw`.
- **AD-55** : point de composition unique = le binding.

### Testing standards

- `flutter_test` ; tests widget sous `packages/zcrud_get/test/`, suffixe `*_test.dart`.
- Monter un vrai `ZcrudScope` + `ZFormController` + `ZFieldWidget` (pas de mock du dispatcher).
- Tests **porteurs** : ils rougissent si l'association `kind → widget` casse (mutation d'oracle documentée) — discipline R3, anti-tautologie.
- Vérif verte rejouée sur disque : `melos run generate` → `melos run analyze` (repo-wide) → `flutter test` (RC=0) + `graph_proof`/secrets.

### Project Structure Notes

- Nouveau fichier : `packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart` (impl) + export dans le barrel `lib/zcrud_get.dart`.
- Nouveau test : `packages/zcrud_get/test/z_form_fields_composer_test.dart`.
- `pubspec.yaml` du binding : +3 arêtes `zcrud_markdown`/`zcrud_intl`/`zcrud_geo`.
- Aucune écriture hors `packages/zcrud_get/`. Aucun `*.g.dart` régénéré attendu (pas d'annotation modèle touchée).
- Conflit/variance : `zcrud_intl`/`zcrud_geo` n'offrent pas de `registerZ` phone/country/location (seulement `.builder()`) → le composeur appelle `registry.register('<kind>', …)` directement. Assumé et documenté (pas une violation AD-55).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story 2.2] (ACs Given/When/Then, FR-21/24/25/26/27)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-55] (binding = point de composition unique)
- [Source: ARCHITECTURE-SPINE.md#AD-50] (exclusivité html/markdown, collision = throw)
- [Source: ARCHITECTURE-SPINE.md#AD-4] (registre injecté, jamais statique)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart] (`ZWidgetRegistry.register` throw `ZDuplicateRegistrationError`, `tryBuilderFor`)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:699] (dispatcher `_buildFromRegistry`)
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] (seams `widgetRegistry`/`selectPresenter`/`filePicker`/`colorPicker`)
- [Source: packages/zcrud_markdown/lib/src/presentation/z_markdown_registration.dart:37] (`registerZMarkdownFields`)
- [Source: packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart:66 / z_country_field_widget.dart:55 / z_address_field_widget.dart:51]
- [Source: packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart:106] (`ZGeoFieldWidget.builder`)
- [Source: packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart:45] (`registerZHtmlFields` — opt-in exclusif)
- [Source: packages/zcrud_get/pubspec.yaml] (deps actuelles ; +3 arêtes à ajouter)
- [Source: scripts/dev/graph_proof.py] (gate acyclique / CORE OUT=0)

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `bmad-dev-story` (skill réel invoqué).

### Debug Log References

- `dart pub get` (racine + example) → RC=0 après ajout des 3 arêtes.
- `dart analyze packages/zcrud_get` → `No issues found!` (RC=0).
- `flutter test packages/zcrud_get/test/z_form_fields_composer_test.dart` → 19 tests, All passed.
- `flutter test packages/zcrud_get` → 74 tests, All passed (aucune régression).
- `python3 scripts/dev/graph_proof.py` → `ACYCLIQUE OK`, `CORE OUT=0 OK`, 64 arêtes, 29 nœuds.
- Scan secrets `packages/zcrud_get/lib` (AIza / maps.googleapis / api_key) → aucun résultat.

### Completion Notes List

- **AD-55** : `registerZcrudFormFields(ZWidgetRegistry, {...})` est le point de composition UNIQUE du binding ; il opère sur le registre **injecté par l'appelant** (aucun singleton statique — AD-4 prouvé par test `isRegistered` sur l'instance passée).
- **Anti-pattern écarté (AC2)** : le composeur APPELLE `registerZMarkdownFields`, `ZPhoneFieldWidget.builder`, `ZCountryFieldWidget.builder`, `registerZAddressFieldWidgets`, `ZGeoFieldWidget.builder`. Seam opt-in `additionalRegistrars` (exécuté EN DERNIER) = 1 ligne au site d'appel pour html/media/field_extras — sans arête de dépendance du binding.
- **Écart intl/geo (documenté)** : phone/country/geo n'exposent PAS de `registerZ<Pkg>Fields` — seulement `.builder()` statique. Le composeur enrôle par `registry.register('<kind>', X.builder(...))`. Conforme AD-55 (le composeur appartient au binding), aucun satellite modifié (lecture seule respectée).
- **Exclusivité html ⇄ markdown (AD-50)** : markdown = voie rich-text par défaut ; html = opt-in via `additionalRegistrars`. Double câblage html → `ZDuplicateRegistrationError` (test). Choix : `zcrud_html` NON ajouté en dep (entre par le seam) ; exclusivité prouvée avec `registerZHtmlFields` de `zcrud_markdown` (mêmes kinds `html`/`inlineHtml` que le WYSIWYG). `select` (présentateur `ZcrudScope.selectPresenter`) et `field_extras` (aucun registrar aujourd'hui — Finitions) restent hors composeur, documentés en docstring.
- **AC7 / AD-1** : 3 arêtes SORTANTES `zcrud_get → zcrud_markdown/zcrud_intl/zcrud_geo` ; graphe acyclique ; CORE OUT=0 inchangé ; aucun satellite ne dépend du binding.
- **Périmètre** : écrits UNIQUEMENT sous `packages/zcrud_get/` (+ `pubspec.lock` via pub get). Cœur et satellites-code INTOUCHÉS (les modifs `zcrud_core`/`zcrud_field_extras` visibles en `git status` appartiennent aux workstreams parallèles fp-4-4/fp-5-2).
- Analyze/verify **repo-wide** délégués à l'orchestrateur au gate de commit (parallélisme actif — un `melos test` global au milieu d'un dev actif est proscrit).

### File List

- `packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart` (net-new — composeur AD-55)
- `packages/zcrud_get/lib/zcrud_get.dart` (M — export du composeur)
- `packages/zcrud_get/pubspec.yaml` (M — +3 arêtes markdown/intl/geo)
- `packages/zcrud_get/test/z_form_fields_composer_test.dart` (net-new — 19 tests porteurs)
- `pubspec.lock` (M — résolution des nouvelles arêtes ; hors commit story)
