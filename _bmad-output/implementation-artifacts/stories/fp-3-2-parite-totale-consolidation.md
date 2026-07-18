<!-- Story enrichie par bmad-create-story (mode non-interactif). Épic 3 (Preuve),
     Story 3.2 du cycle form-parity — DERNIÈRE story de l'itération (fan-in FINAL,
     après FP-4/FP-5 tous `done`). Source : epics-zcrud-form-parity-2026-07-18/epics.md.
     PÉRIMÈTRE D'ÉCRITURE : `example/` UNIQUEMENT (app de démonstration + son pubspec +
     ses tests). AUCUN package `packages/*` n'est modifié — fp-3-2 les CONSOMME (AD-56 /
     AR-6). fp-3-2 COMPLÈTE l'infrastructure de fp-3-1 (done) : elle réutilise l'ossature
     `ShowcaseAxis`/`AxisForm`/`AbsentCapability` sans la réécrire. -->

# Story 3.2: Parité totale — consolidation showcase 46 types × variantes + harnais 6 formulaires DODLP + benchs SM

Status: review

## Story

As a owner (Zakarius) et dev DODLP (Bilal),
I want une **showcase EXHAUSTIVE** couvrant **tous** les `EditionFieldType` (46 valeurs) et **toutes**
leurs variantes, les **6 formulaires DODLP** répliqués sur données fictives (un par axe de risque), et les
**benchs SM** (SM-1 y compris la WebView WYSIWYG isolée),
so that je valide **SM-2** (parité traçable : 100 % des items ont un statut connu), **SM-3** (non-régression
visuelle bout-en-bout), **SM-4** (complétude auditée) et **SM-1** (granularité de rebuild) — **sans toucher
un seul package** (l'app consomme les satellites fp-4/fp-5 via le VRAI dispatcher + les seams `ZcrudScope`).

## Contexte & frontières (à lire AVANT de coder)

### Ce qui a CHANGÉ depuis fp-3-1 (le point pivot de cette story)

fp-3-1 (done) a livré l'**ossature** showcase (`example/lib/demos/showcase/*`) + le socle représentatif +
les axes MVP 1/5/6 + le banc SM-1. À l'époque, **FP-4 (média-rich) et FP-5 (finitions) n'étaient pas
livrés** : les axes 2/3/4 étaient donc `AxisStatus.upcoming` et les capacités riches (`select` modal,
média, HTML WYSIWYG, `color` multiple, `pin`, `autocomplete`, `editableTable`, `itemsAreTags`) étaient
listées comme **ABSENTES**.

**Aujourd'hui, TOUTES les stories FP-4 et FP-5 sont `done`** (vérifié sprint-status) :
- `fp-4-1` → `ZSmartSelectPresenter` (satellite `zcrud_select`) : select/radio/relation/multiselect modal.
- `fp-4-2` → `zcrud_media` (`ZMediaFieldWidget` + `ZMediaFilePicker`) : image/fichier/vidéo riches.
- `fp-4-3` → `zcrud_html` (`ZHtmlEditorField` WYSIWYG + `ZHtmlView` lecture, `registerZHtmlFields`).
- `fp-4-4` → `ZColorConfig.multiple` natif (`ZColorMultiFieldWidget`).
- `fp-5-1` → enum `pin`/`autocomplete`/`editableTable` + `ZSubListDisplayMode.tags` (natif au cœur).
- `fp-5-2` → `zcrud_field_extras` (`ZPinFieldWidget`/`ZAutocompleteFieldWidget`/`ZEditableTableFieldWidget`).
- `fp-5-3` → `geoArea` style-picker (satellite `zcrud_geo`).

**Conséquence directe pour fp-3-2** : ces capacités **ne sont plus ABSENTES** — elles doivent être
**démontrées LIVE via leur vrai adaptateur**, les axes 2/3/4 passent de `upcoming` à `mvp`, et les entrées
correspondantes **quittent** `ShowcaseData.absentCapabilities`. La liste ABSENT se réduit aux **vrais gaps
assumés** (voir plus bas).

### Ce que fp-3-2 EST (consolidation « parité totale »)

1. **Showcase EXHAUSTIVE** : compléter le socle fp-3-1 pour couvrir **les 46 `EditionFieldType` × toutes
   leurs variantes** — chaque famille rendue par **son adaptateur réel** (présence ≠ association), chaque
   item avec un **statut connu** (livré / câblé / gap assumé — jamais « on ne sait pas », SM-2/SM-4).
2. **Décisions natif-vs-package côte à côte** : `color` (sliders `ZColorFieldWidget` **vs** roue seam) ;
   `select`/`radio`/`relation` (natif **vs** modal `ZSmartSelectPresenter`) ; `phoneNumber` (panneau inline
   **vs** dialog) — surface les arbitrages D1/D2/D4 du `FIELD-PACKAGE-MATRIX`.
3. **Harnais 6 formulaires DODLP** : 6 `AxisForm` répliquant 6 formulaires fonctionnels DODLP sur **données
   FICTIVES** (aucun secret, aucun backend), un par axe de risque — preuve de non-régression bout-en-bout
   (SM-3). Branchés dans l'ossature fp-3-1 **sans la réécrire**.
4. **Benchs SM** : SM-1 **y compris quand le champ courant est la WebView WYSIWYG** (`ZHtmlEditorField`,
   AD-50) ; SM-2 (parité traçable), SM-4 (complétude) matérialisés par la showcase ; SM-3 par le harnais.

### Ce que fp-3-2 N'EST PAS (frontière stricte)

- ❌ **AUCUNE** écriture dans `packages/*`. `git status --porcelain packages/` reste **vide**. Si un besoin
  de champ/adaptateur manquant émerge → **le SIGNALER dans les Completion Notes**, ne pas l'implémenter ici.
- ❌ **PAS** de nouveau type de champ — les 46 `EditionFieldType` existent déjà (fp-1/fp-4/fp-5). Aucune
  addition d'enum.
- ❌ **PAS** de réécriture de l'ossature `axis_harness.dart` (point d'extension = ajouter des `AxisForm`).
- ❌ **PAS** de faux-rendu d'un gap : un gap assumé reste **étiqueté ABSENT**, jamais simulé par un widget
  qui feindrait la parité.

### Vrais gaps ASSUMÉS restant ABSENTS (OQ-6/OQ-7 — étiquetés, jamais masqués, avec justification)

- **`icon`** (picker d'icône) : hors parité MVP, aucun besoin produit prouvé (`FIELD-PACKAGE-MATRIX` #29).
- **`subItems` variante `itemsAreTags`** : le mode natif `ZSubListDisplayMode.tags` existe (fp-5-1) mais
  **0 call-site actif** dans DODLP cloné → **démontrable** si exercé, sinon consigné OQ-6. **Décision dev
  à trancher** : soit le démontrer LIVE (mode natif dispo, préféré), soit le laisser ABSENT justifié — voir
  Dev Notes.
- **LaTeX fallback SVG (`flutter_tex`)** : **banni** par le test d'isolation (`FIELD-PACKAGE-MATRIX` #33,
  D6) → placeholder thémé, pas de SVG. Gap assumé par architecture.
- Types **non-widget** (statut « comportement », pas un gap) : `hidden` (non rendu), `password` (`text` +
  masquage), `widget`/`custom` (seams ouverts AD-4), `stepper` (paramètre de `DynamicEdition`, pas une
  famille de champ). Chacun **étiqueté avec son statut réel** (SM-2 : jamais « on ne sait pas »).

## Acceptance Criteria

**AC1 — Showcase EXHAUSTIVE : les 46 `EditionFieldType` couverts, chacun par son adaptateur réel** *(FR-40 complet, SM-2/SM-4)*
**Given** la showcase consolidée (socle fp-3-1 étendu)
**When** on l'ouvre
**Then** **chacune** des 46 valeurs de `EditionFieldType`
(`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`) a une **entrée avec un statut connu**
(livré-natif / câblé-satellite / comportement / gap-assumé) — **aucun « on ne sait pas »** (SM-2) ; les
familles rendues le sont par **leur adaptateur concret** monté par `DynamicEdition`/`ZFieldWidget`, jamais un
mock, jamais `ZUnsupportedFieldWidget` (sauf gaps assumés explicitement étiquetés). Un test **énumère les 46
valeurs de l'enum** et vérifie que chacune a une entrée classée (couverture prouvée par construction, non par
liste codée en dur qui pourrait diverger de l'enum).

**AC2 — Nouveaux types fp-4/fp-5 démontrés LIVE via leur vrai adaptateur (plus ABSENTS)** *(FR-40, SM-3)*
**Given** les capacités livrées par FP-4/FP-5 (`done`)
**When** la showcase les monte
**Then** elles se rendent par leur **vrai widget**, prouvé par `find.byType` :
- `dateRange` → `ZDateRangeFieldWidget` · `color` multiple (`ZColorConfig.multiple`) → `ZColorMultiFieldWidget`
- `mediaImage`/`mediaFile`/`mediaVideo` → `ZMediaFieldWidget` (via `registerZMediaFieldWidgets`)
- `html`/`inlineHtml` → `ZHtmlEditorField` (via `registerZHtmlFields`) ; lecture → `ZHtmlView`
- `pin` → `ZPinFieldWidget` · `autocomplete` → `ZAutocompleteFieldWidget` · `editableTable` → `ZEditableTableFieldWidget` (via `registerZFieldExtrasFields`)
- `select`/`radio`/`relation` en **modal riche** → rendus via `ZSelectFieldWidget`/`ZRelationFieldWidget` **piloté par** le `ZSmartSelectPresenter` injecté ;
et les entrées correspondantes **ne figurent plus** dans `ShowcaseData.absentCapabilities` (un test prouve leur **retrait** — grep négatif sur ces `kind`).

**AC3 — Décisions natif-vs-package montrées côte à côte** *(FR-40, SM-2)*
**Given** les types à double voie (D1/D2/D4 du `FIELD-PACKAGE-MATRIX`)
**When** la showcase les présente
**Then** les **deux rendus coexistent visiblement** quand c'est possible : `color` sliders (`ZColorFieldWidget`,
sans presenter) **vs** roue (seam `ZcrudScope.colorPicker`) ; `select`/`radio` **natif** (aucun presenter
injecté) **vs** **modal** (`ZSmartSelectPresenter` injecté) ; `phoneNumber` **inline** vs **dialog** ; un test
vérifie que les deux variantes sont présentes et rendues par leur adaptateur réel (jamais un faux-rendu).

**AC4 — Gaps assumés (OQ-6/OQ-7) étiquetés ABSENT avec justification** *(SM-2/SM-4, FR-40)*
**Given** les vrais gaps restants (`icon`, LaTeX SVG fallback, éventuellement `itemsAreTags` si non exercé)
**When** la showcase les référence
**Then** chacun apparaît **étiqueté « ABSENT / à combler »** avec une **raison** (jamais retiré, jamais
faux-rendu) ; un test vérifie la présence de ces étiquettes ; **aucun** des types désormais livrés (AC2)
n'apparaît encore comme ABSENT.

**AC5 — Harnais 6 formulaires DODLP, un par axe, données fictives** *(FR-39 complet, SM-3)*
**Given** l'ossature fp-3-1 (`ShowcaseAxis`/`AxisForm`)
**When** on ouvre les 6 formulaires
**Then** **6 formulaires** répliquant des formulaires DODLP réels (LECTURE SEULE de `dodlp-otr`) sont
peuplés, un par axe de risque, montés via `AxisFormScreen` (VRAI dispatcher) :
1. **Dense texte/nombre/date + SM-1** (`Cargaison`, `pia`) ;
2. **Sélections** `select`/`radio`/`relation` (+ `ZSmartSelectPresenter` modal) (`DemandeDepotage`, `vido`) ;
3. **Média** `mediaImage`/`mediaFile`/`mediaVideo` (`AuthProfile`, `auth`) ;
4. **Rich-text** `markdown`/`inlineMarkdown` + `html`/`inlineHtml` (`ArticleBep`/`Cotation`, `sse`/`douanes_togolaises`) ;
5. **Intl/géo** `phoneNumber`/`country`/`address`/`location` (`Consignee`/`BoatService`, `bmd`) ;
6. **Spécialisés/imbriqués** `rating`/`slider`/`signature`/`color`/`subItems`(+réordo)/`dateRange` (`Convocation`/`Event`, `bmd`/`workflow`).
Les axes 2/3/4 de l'ossature passent de `AxisStatus.upcoming` à `mvp` (peuplés) ; **données 100 % fictives**,
aucun secret, aucune dépendance backend DODLP ; un test vérifie que chaque formulaire se rend via le
dispatcher (widgets réels de son axe, jamais `ZUnsupportedFieldWidget`).

**AC6 — SM-1 falsifiable, y compris WebView WYSIWYG isolée** *(SM-1, NFR-1, AD-2, AD-50)*
**Given** un formulaire de frappe intensive incluant un champ `html` (WYSIWYG `ZHtmlEditorField`)
**When** l'utilisateur (le test) tape 100 caractères dans **un** champ
**Then** **seul** ce champ se reconstruit (compteur `RebuildLog` du champ courant augmente ; voisins
**inchangés**), **zéro perte de focus**, **aucun `Form` global** (`find.byType(Form)` → `findsNothing`),
le `TextEditingController`/`State` de la WebView n'est **pas recréé** (le `State` de `ZHtmlEditorField`
**survit** aux rebuilds voisins). Le banc reste **falsifiable** (rougirait si un rebuild global était
réintroduit ou si la WebView était recréée), PAS tautologique. *(Note : si l'exécution de la vraie WebView
`html_editor_enhanced` n'est pas montable en `flutter test` headless, consigner l'écart et prouver la
survivance du `State` par un banc SM-1 sur un champ intensif standard + un test ciblé de non-recréation du
`State` — voir Dev Notes.)*

**AC7 — Registre via le composeur fp-2-2 + seams satellites (jamais de re-registration manuelle)** *(AR-4/AD-55, AD-4, AD-50)*
**Given** le registre showcase (`buildShowcaseWidgetRegistry`, fp-3-1)
**When** fp-3-2 l'étend pour les nouveaux satellites
**Then** l'enrôlement passe par **`registerZcrudFormFields(registry, …, additionalRegistrars: [...])`** avec
les registrars des satellites (`registerZHtmlFields`, `registerZMediaFieldWidgets`,
`registerZFieldExtrasFields`) — **jamais** une re-registration kind-par-kind dupliquant le composeur ; les
presenters/seams non-registre sont injectés **à côté** via `ZcrudScope` (`selectPresenter:
ZSmartSelectPresenter()`, `filePicker: ZMediaFilePicker(…)`, `colorPicker: …` si roue démontrée) ; le
registre reste **app-owned** (AD-4, jamais singleton statique) ; une double registration `html`⇄`markdown`
sur le même `kind` **throw** `ZDuplicateRegistrationError` (exclusivité AD-50 respectée : markdown par
défaut, html opt-in sur kinds disjoints) ; un test prouve que chaque champ satellite se rend via l'adaptateur
enrôlé par le composeur/registrar.

**AC8 — `example/` étendu proprement : deps satellites + frontière mise à jour** *(AD-56, NFR-2/9)*
**Given** `example/pubspec.yaml` et `example/test/boundary_deps_test.dart`
**When** fp-3-2 consomme les 4 satellites neufs (`zcrud_select`, `zcrud_html`, `zcrud_media`,
`zcrud_field_extras`)
**Then** chacun est déclaré en `dependencies` (`path:`) + `dependency_overrides` (patron des autres `zcrud_*`)
dans `example/pubspec.yaml` ; l'assertion POSITIVE de `boundary_deps_test.dart` est **étendue** à ces 4
paquets (sinon la liste diverge silencieusement) ; `zcrud_mindmap` **reste INTERDIT** (l'assertion négative
est préservée) ; aucune de ces deps ne tire `zcrud_mindmap` en transitif.

**AC9 — Données fictives, zéro secret, zéro backend + isolation `packages/*`** *(AD-56/AR-6, AD-12)*
**Given** toute la surface fp-3-2
**When** elle s'exécute
**Then** toutes les données sont **fictives** (aucune donnée réelle DODLP), **aucun secret** (aucune clé Maps
embarquée — `location`/`geoArea` en repli coordonnées-seules AD-12 ou config plateforme), **aucune dépendance
backend DODLP** ; `git status --porcelain packages/` **vide** ; grep de secrets **vert**.

**AC10 — Gates verts (vérif verte rejouée)** *(NFR-2/9)*
**Given** le workspace
**When** fp-3-2 est terminée
**Then** `flutter analyze` de `example/` RC=0 ; `flutter test` de `example/` RC=0 (nouveaux tests inclus) ;
`example/pubspec.lock` propre (app hors workspace) ; **`melos run analyze` + `melos run verify` repo-wide**
verts (aucune régression cross-package — `packages/*` intouché) ; `melos list` inchangé (l'app + ses deps
satellites restent HORS du glob `packages/**`).

## Tasks / Subtasks

- [x] **T1 — Étendre `example/pubspec.yaml` + frontière** (AC: 8, 9, 10)
  - [x] Ajouter `zcrud_select`, `zcrud_html`, `zcrud_media`, `zcrud_field_extras` en `dependencies`
        (`path: ../packages/<pkg>`) ET `dependency_overrides` (patron des `zcrud_*` existants).
  - [x] `dart pub get` dans `example/` → lock propre, aucune arête `zcrud_mindmap`.
  - [x] Étendre la liste POSITIVE de `example/test/boundary_deps_test.dart` avec les 4 paquets ; **préserver**
        l'assertion négative `zcrud_mindmap`.
- [x] **T2 — Étendre le registre showcase via le composeur + seams** (AC: 7)
  - [x] Dans `example/lib/demos/showcase/showcase_registry.dart`, passer
        `additionalRegistrars: [registerZHtmlFields, registerZMediaFieldWidgets, registerZFieldExtrasFields]`
        à `registerZcrudFormFields` (signature LUE ; ne PAS re-`register` kind-par-kind).
  - [x] Fournir les seams `ZcrudScope` au niveau de `ShowcaseScreen` : `selectPresenter: const ZSmartSelectPresenter()`,
        `filePicker: ZMediaFilePicker(…)` (constructeur LU), `colorPicker: …` si la roue est démontrée (AC3).
  - [x] Vérifier l'exclusivité AD-50 : markdown (défaut) + html (opt-in) sur kinds disjoints — pas de
        `ZDuplicateRegistrationError` au bootstrap.
- [x] **T3 — Showcase exhaustive : compléter le socle aux 46 types** (AC: 1, 2)
  - [x] Étendre `ShowcaseData` (nouveau bloc ou sections) pour couvrir les types non encore au socle fp-3-1 :
        `dateRange` (déjà), `color` multiple (`ZColorConfig.multiple`), `mediaImage`/`mediaFile`/`mediaVideo`,
        `html`/`inlineHtml`, `inlineMarkdown`, `richText`, `pin`, `autocomplete`, `editableTable`,
        `geoArea` (style-picker fp-5-3), `stepper` (paramètre `DynamicEdition`), `password`/`hidden`/`widget`/`custom`
        (statut « comportement/seam »).
  - [x] Construire l'entrée showcase de façon **dérivée de l'enum** : le test AC1 énumère
        `EditionFieldType.values` et exige un statut par valeur (couverture prouvée par construction).
- [x] **T4 — Décisions natif-vs-package côte à côte** (AC: 3)
  - [x] Monter `color` sliders vs roue ; `select`/`radio` natif (sous-arbre SANS `selectPresenter`) vs modal
        (sous-arbre AVEC `ZSmartSelectPresenter`) ; `phoneNumber` inline vs dialog. Deux `ZcrudScope`
        imbriqués OK (l'un sans presenter, l'autre avec) pour prouver les deux voies.
- [x] **T5 — Réconcilier `ShowcaseData.absentCapabilities`** (AC: 2, 4)
  - [x] **Retirer** les entrées désormais livrées (`select modal`, `mediaImage/File/Video`, `html/inlineHtml`,
        `color multiple`, `pin`, `autocomplete`, `editableTable`).
  - [x] **Conserver** les gaps assumés (`icon`, LaTeX SVG fallback, `itemsAreTags` si non exercé) avec `reason`.
  - [x] Basculer les axes 2/3/4 de `AxisStatus.upcoming` à `mvp` (peuplés en T6).
- [x] **T6 — Harnais 6 formulaires DODLP** (AC: 5)
  - [x] Répliquer 6 `AxisForm` (schémas `ZFieldSpec[]` pur-données, valeurs FICTIVES) d'après les entités
        DODLP (LECTURE SEULE) — un par axe (voir shortlist AC5 + Dev Notes pour les chemins). Brancher chaque
        `AxisForm` dans son `ShowcaseAxis` de `ShowcaseData.axes` **sans réécrire l'ossature**.
  - [x] Chaque formulaire exerce les familles saillantes de son entité via le VRAI dispatcher.
- [x] **T7 — Banc SM-1 incl. WYSIWYG** (AC: 6)
  - [x] Ajouter au banc de l'axe 1 (ou un banc dédié) un champ `html` (`ZHtmlEditorField`) ; prouver la
        granularité (voisins inchangés + focus) ET la non-recréation du `State` WebView. Consigner l'écart si
        la WebView n'est pas montable headless (repli : banc SM-1 standard + test de survivance du `State`).
- [x] **T8 — Tests widget** (AC: 1-9)
  - [x] `example/test/showcase_exhaustive_test.dart` : énumère `EditionFieldType.values` → statut par valeur ;
        nouveaux types rendus par leur adaptateur réel (`find.byType(ZMediaFieldWidget)`, `ZHtmlEditorField`,
        `ZPinFieldWidget`, `ZAutocompleteFieldWidget`, `ZEditableTableFieldWidget`, `ZColorMultiFieldWidget`,
        `ZDateRangeFieldWidget`), jamais `ZUnsupportedFieldWidget` hors gaps ; étiquettes ABSENT résiduelles
        présentes ; `absentCapabilities` **ne contient plus** les kinds livrés (grep négatif).
  - [x] `example/test/showcase_native_vs_package_test.dart` : les deux voies (natif vs modal/roue/dialog)
        présentes et rendues par leur adaptateur.
  - [x] `example/test/dodlp_forms_harness_test.dart` : les 6 formulaires se rendent via le dispatcher (widgets
        réels par axe), données fictives, axes 2/3/4 = `mvp`.
  - [x] `example/test/showcase_sm1_wysiwyg_test.dart` : SM-1 falsifiable incl. survivance du `State` WYSIWYG
        (modeler sur `showcase_sm1_test.dart` / `sm1_granular_rebuild_test.dart`).
  - [x] Étendre/ajuster `axis_harness_test.dart` et `showcase_screen_test.dart` fp-3-1 si le retrait des
        « à venir » / ABSENT casse leurs assertions (mettre à jour, ne pas affaiblir).
- [x] **T9 — Gates & isolation** (AC: 9, 10)
  - [x] `git status --porcelain packages/` **vide** ; grep secrets vert.
  - [x] `flutter analyze` + `flutter test` de `example/` RC=0 ; `melos run analyze` + `melos run verify`
        repo-wide verts ; `example/pubspec.lock` propre.

## Dev Notes

### Infrastructure fp-3-1 à RÉUTILISER (ne PAS réécrire)

- **`example/lib/demos/showcase/axis_harness.dart`** — `ShowcaseAxis` / `AxisForm` / `AbsentCapability` /
  `AxisFormScreen` / `AxisHarnessScreen`. **Point d'extension unique** : ajouter des `AxisForm` à
  `ShowcaseAxis.forms`. `AxisFormScreen` monte déjà un `ZFormController` STABLE (AD-2) + banc SM-1 optionnel
  (`rebuildLog`/`intensiveFieldName`). Aucune réécriture. [Source: example/lib/demos/showcase/axis_harness.dart]
- **`example/lib/demos/showcase/showcase_data.dart`** — `ShowcaseData` (socle + `axes` + `absentCapabilities`).
  fp-3-2 **étend** le socle, **retire** les gaps livrés, **peuple** les axes 2/3/4. [Source: example/lib/demos/showcase/showcase_data.dart]
- **`example/lib/demos/showcase/showcase_registry.dart`** — `buildShowcaseWidgetRegistry()` : appelle DÉJÀ
  `registerZcrudFormFields`. fp-3-2 y ajoute `additionalRegistrars`. [Source: example/lib/demos/showcase/showcase_registry.dart]
- **`example/lib/demos/showcase/showcase_screen.dart`** — page + `ZcrudScope.widgetRegistry`. fp-3-2 y
  injecte les seams `selectPresenter`/`filePicker`/`colorPicker`. [Source: example/lib/demos/showcase/showcase_screen.dart]
- **`example/lib/support/rebuild_indicator.dart`** — `RebuildLog`/`RebuildBadge` (banc SM-1 granulaire).
- **`example/test/{showcase_screen_test,showcase_sm1_test,axis_harness_test,sm1_granular_rebuild_test}.dart`**
  — patrons de test (présence≠association, SM-1 falsifiable, ossature).

### Composeur fp-2-2 — signature ACTUELLE (LECTURE SEULE)

`void registerZcrudFormFields(ZWidgetRegistry registry, {ZCodec? richTextCodec, ZCountryCatalog?
countryCatalog, ZSubdivisionCatalog? subdivisionCatalog, ZPlaceSearchProvider? placeSearch,
ZMapAdapterFactory? geoAdapterFactory, bool wireGeoArea = false, Iterable<void Function(ZWidgetRegistry)>
additionalRegistrars = const []})`. Enrôle **par défaut** : markdown/inlineMarkdown/richText (via
`registerZMarkdownFields`), phoneNumber/country (`.builder()`), address (`registerZAddressFieldWidgets`),
location (+ geoArea si `wireGeoArea`). Les `additionalRegistrars` sont exécutés **en dernier** (collision →
`throw ZDuplicateRegistrationError`). **fp-3-2 y passe `registerZHtmlFields` / `registerZMediaFieldWidgets` /
`registerZFieldExtrasFields`.** [Source: packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart]

### Seams `ZcrudScope` (valeurs, PAS des registrars — injectées à côté du registre)

`ZcrudScope` porte : `widgetRegistry`, `selectPresenter` (`ZSelectPresenter?`), `filePicker` (`ZFilePicker?`),
`colorPicker` (`ZColorPicker?`), `iconResolver`, `relationSourceRegistry`/`relationCrudRegistry`/
`choicesSourceRegistry`. [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart]
- **`ZSmartSelectPresenter`** (`zcrud_select`) a un **const ctor** `const ZSmartSelectPresenter()`. Quand il
  est dans `ZcrudScope.selectPresenter`, `ZSelectFieldWidget` (`z_select_field_widget.dart:123` :
  `ZcrudScope.maybeOf(context)?.selectPresenter`) **supplante** le rendu natif → modal riche. **Sans** lui →
  rendu natif. C'est le levier « natif vs modal côte à côte » (AC3). [Source: packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart ; packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart]
- **`ZMediaFilePicker`** (`zcrud_media`) `implements ZFilePicker` — ctor `ZMediaFilePicker({…})` à LIRE ;
  l'injecter dans `ZcrudScope.filePicker`. [Source: packages/zcrud_media/lib/src/data/z_media_file_picker.dart]

### Adaptateurs concrets attendus par les tests (présence ≠ association)

| Type / variante | Widget concret (find.byType) | Source d'enrôlement |
|---|---|---|
| text/multiline/password | `ZTextFieldWidget` | natif cœur |
| number/integer/float | `ZNumberFieldWidget` | natif cœur |
| boolean | `ZBooleanFieldWidget` | natif cœur |
| dateTime/time | `ZDateFieldWidget` | natif cœur |
| **dateRange** | `ZDateRangeFieldWidget` | natif cœur (fp-1-1) |
| select/radio/checkbox | `ZSelectFieldWidget` (+ presenter = modal) | natif + `ZSmartSelectPresenter` |
| relation | `ZRelationFieldWidget` | natif + presenter |
| rowChips/tags | `ZRowChipsFieldWidget` / `ZTagsFieldWidget` | natif cœur |
| subItems/dynamicItem | `ZSubListFieldWidget` / `ZDynamicItemFieldWidget` | natif cœur |
| rating/slider/signature | `ZRatingFieldWidget` / `ZSliderFieldWidget` / `ZSignatureFieldWidget` | natif cœur |
| color (simple) | `ZColorFieldWidget` | natif cœur |
| **color (multiple)** | `ZColorMultiFieldWidget` | natif cœur (`ZColorConfig.multiple`, fp-4-4) |
| **mediaImage/File/Video** | `ZMediaFieldWidget` | `registerZMediaFieldWidgets` (fp-4-2) |
| **html/inlineHtml** (édition) | `ZHtmlEditorField` | `registerZHtmlFields` (fp-4-3) |
| html/inlineHtml (lecture) | `ZHtmlView` | `zcrud_html` |
| **pin** | `ZPinFieldWidget` | `registerZFieldExtrasFields` (fp-5-2) |
| **autocomplete** | `ZAutocompleteFieldWidget` | `registerZFieldExtrasFields` |
| **editableTable** | `ZEditableTableFieldWidget` | `registerZFieldExtrasFields` |
| markdown/inlineMarkdown/richText | `ZMarkdownField` | `registerZMarkdownFields` (défaut composeur) |
| phoneNumber/country/address | `ZPhoneFieldWidget`/`ZCountryFieldWidget`/`ZAddressFieldWidget` | intl (composeur) |
| location/geoArea | `ZGeoFieldWidget` | geo (composeur, `wireGeoArea:true` pour geoArea) |

Le repli **`ZUnsupportedFieldWidget`** (`packages/zcrud_core/lib/src/presentation/edition/families/
z_unsupported_field_widget.dart`) ne doit apparaître **que** pour un gap assumé explicitement étiqueté (jamais
pour un type censé être rendu).

### `html` : registration + exclusivité AD-50

`registerZHtmlFields(registry)` register `'inlineHtml'` puis `'html'`
([Source: packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart]). Ces kinds sont
**disjoints** de markdown (`markdown`/`inlineMarkdown`/`richText`) : les câbler ensemble ne collisionne PAS.
Ne PAS enrôler une 2ᵉ voie html (ex. html-via-Delta de `zcrud_markdown`) en même temps → `throw`. La showcase
choisit **une** voie html (WYSIWYG `zcrud_html`).

### `EditionFieldType` — le compte réel est **46**, pas 40

L'epic dit « 40 » : c'était le compte au moment du `FIELD-PACKAGE-MATRIX` (2026-07-17), **avant** que
fp-1/fp-4/fp-5 ajoutent `dateRange`, `pin`, `autocomplete`, `editableTable`, `mediaImage`, `mediaFile`,
`mediaVideo`. L'enum en porte **46** aujourd'hui (vérifié). La showcase doit couvrir les **46** — le test
d'exhaustivité **énumère `EditionFieldType.values`** (jamais un nombre codé en dur qui divergerait de l'enum).
[Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart]

### Statuts « comportement / seam » (SM-2 : jamais « on ne sait pas »)

- `password` → `ZTextFieldWidget` masqué (statut : livré, comportement `text`).
- `hidden` → **non rendu** (statut : comportement — l'entrée showcase l'explique, aucun widget attendu).
- `stepper` → **paramètre de `DynamicEdition`** (`ZStepperConfig`), pas une famille de champ (statut : livré,
  hors dispatcher `ZFieldWidget`).
- `widget` / `custom` → **seams ouverts AD-4** (closure/`ZTypeRegistry`) — statut : livré (seam), démontrable
  par un `widget`-builder fictif app-side.

### Harnais 6 formulaires — entités DODLP de référence (LECTURE SEULE `/home/zakarius/DEV/dodlp-otr`)

Repérer les `ZFieldSpec`/champs de chaque entité (reproduire **la forme**, pas les données) :
1. **Cargaison** — `lib/modules/pia/…` (dense texte/nombre/date + subItems conteneurs + relation).
2. **DemandeDepotage** — `lib/modules/vido/domain/models/demande_depotage.dart` (select/relation `crudDataSelect`,
   number, switch).
3. **AuthProfileData** — `lib/modules/auth/domain/models/user_profile_data.dart` +
   `lib/modules/auth/profile/auth_profile_edition_screen.dart` (image/fichier, text). *(Note : DODLP est
   `reflectable`-based `Entity` ; les métadonnées de champ sont dérivées ailleurs — reproduire un schéma
   `ZFieldSpec[]` REPRÉSENTATIF, pas un portage 1:1.)*
4. **ArticleBep / Cotation** — `lib/modules/sse/domain/models/article_bep.dart` /
   `lib/modules/douanes_togolaises/presentation/views/cotation/cotation_edition_screen.dart` (number, select,
   relation, markdown/html).
5. **Consignee / BoatService** — `lib/modules/bmd/domain/models/{shared/consignee.dart,boat_services/boat_service.dart}`
   (phone, country, address, location, switch, select).
6. **ConvocationBmd / Event** — `lib/modules/bmd/domain/models/boat_services/convocation.dart` +
   `lib/modules/workflow/…` (dateTime, **dateRange** candidat, relation, rating/slider/signature/subItems).

Justification couverture : cette shortlist couvre les **6 axes de risque** du `FIELD-PACKAGE-MATRIX` §5.2 et
maximise la diversité de types (texte/nombre/date/select/relation/média/rich-text/intl/géo/spécialisés/
imbriqués). **Données 100 % fictives** (noms/valeurs inventés app-side), aucun secret, aucun backend.
[Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md §5.2 ;
docs/dodlp-form-integration-study-2026-07-17/NEXT-ITERATION-SCOPE.md §1]

### Banc SM-1 WYSIWYG — piège d'exécution headless

`ZHtmlEditorField` enveloppe une **WebView** (`html_editor_enhanced`, AD-50). En `flutter test` headless la
WebView peut ne pas s'initialiser. **Stratégie** : (a) prouver la survivance du `State` de `ZHtmlEditorField`
aux rebuilds voisins par un test de non-recréation (`GlobalKey`/compteur d'`initState`) ; (b) tenir le banc
SM-1 « voisins inchangés + focus » sur un champ intensif **standard** monté à côté du champ html. Si la
WebView est montable (mock/plateforme), démontrer directement la frappe dans le WYSIWYG. **Consigner l'écart
choisi** dans les Completion Notes (ne PAS modifier le package pour « faciliter » le test). [Source: fp-4-3 ACs, AD-50]

### Invariants applicables (rappel — chaque AC les respecte)

- **AD-56 / AR-6** : `example/` UNIQUEMENT, données fictives, zéro secret, **aucun** `packages/*` modifié.
- **AD-2 / SM-1 / NFR-1** : `ZFormController` stable, rebuild granulaire, `TextEditingController`/`State`
  WebView non recréés, aucun `Form` global, `ValueKey(field.name)`.
- **AD-13** : RTL (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), `Semantics`, ≥ 48 dp.
- **FR-26** : aucun style/couleur/libellé codé en dur — `ColorScheme`/thème, l10n/labels de schéma.
- **AD-4** : registre + presenters app-owned via `ZcrudScope`, jamais singleton statique mutable.
- **AD-12** : aucune clé Maps embarquée — `location`/`geoArea` en repli coordonnées-seules / config plateforme.
- **AD-50** : exclusivité html ⇄ markdown (kinds disjoints ici ; double voie même kind → `throw`).
- **`ListView.builder`** (jamais `ListView(children:)`), `const` sur widgets immuables.

### Testing standards

- Framework : `flutter_test` (widget tests dans `example/test/`).
- Chaque AC → fichier réel + test : exhaustivité dérivée de l'enum (AC1), adaptateurs réels par `find.byType`
  (AC2, présence≠association), côte-à-côte natif/package (AC3), étiquettes ABSENT + retrait des livrés (AC4),
  6 formulaires via dispatcher (AC5), SM-1 falsifiable incl. survivance `State` WYSIWYG (AC6), composeur +
  seams (AC7), frontière deps (AC8).
- Rejouer la **vérif verte** : `flutter analyze` + `flutter test` de `example/` RC=0 ; `melos run analyze` +
  `melos run verify` repo-wide (aucune régression cross-package — `packages/*` intouché).

### Project Structure Notes

- Fichiers modifiés (tous sous `example/`) : `example/pubspec.yaml` (+4 deps), `example/test/boundary_deps_test.dart`
  (+4 attendus), `example/lib/demos/showcase/{showcase_data,showcase_registry,showcase_screen}.dart` (extension).
- Nouveaux tests : `example/test/{showcase_exhaustive,showcase_native_vs_package,dodlp_forms_harness,showcase_sm1_wysiwyg}_test.dart`.
- Nouveaux fichiers de schémas optionnels : `example/lib/demos/showcase/dodlp_forms.dart` (6 `AxisForm` DODLP
  fictifs) — branchés dans `ShowcaseData.axes` sans réécrire `axis_harness.dart`.
- **Isolation** (`example/pubspec.yaml`) : app HORS `workspace:` root et hors glob `packages/**` ; lock propre ;
  consommatrice only — NE modifie AUCUN `packages/*`. `zcrud_core` reste Syncfusion/Firebase/Maps-free (SM-5).

### Vérifications sur disque déjà jouées (état au départ)

- FP-4 (4/4) + FP-5 (3/3) = **`done`** au sprint-status (satellites disponibles). [Source: sprint-status.yaml]
- `example/pubspec.yaml` **ne dépend PAS** encore de `zcrud_{select,html,media,field_extras}` (grep négatif) →
  T1 les ajoute.
- Composeur `registerZcrudFormFields` porte le seam `additionalRegistrars` (LU). Registrars disponibles :
  `registerZHtmlFields`, `registerZMediaFieldWidgets`, `registerZFieldExtrasFields`, `registerZFieldExtrasFields`
  (barrels LUS). Widgets concrets confirmés : `ZHtmlEditorField`/`ZHtmlView`, `ZMediaFieldWidget`,
  `ZPinFieldWidget`/`ZAutocompleteFieldWidget`/`ZEditableTableFieldWidget`, `ZColorMultiFieldWidget`,
  `ZDateRangeFieldWidget`.
- `ZSelectFieldWidget` consomme `ZcrudScope.selectPresenter` (LU ligne 123) → levier natif/modal (AC3).
- `EditionFieldType.values` = **46** (comptés sur disque ; l'epic « 40 » est périmé).
- DODLP réel présent en LECTURE SEULE (`/home/zakarius/DEV/dodlp-otr/lib/modules/`) — entités des 6 forms
  localisées (pia/vido/auth/sse/bmd/workflow).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Epic 3 / Story 3.2]
- [Source: _bmad-output/implementation-artifacts/stories/fp-3-1-preuve-mvp-showcase-harnais.md] (infra réutilisée)
- [Source: packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart] (composeur + additionalRegistrars, AD-55)
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] (seams selectPresenter/filePicker/colorPicker)
- [Source: packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart] (fp-4-1)
- [Source: packages/zcrud_media/lib/src/data/z_media_file_picker.dart ; packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart] (fp-4-2)
- [Source: packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart] (fp-4-3, registerZHtmlFields)
- [Source: packages/zcrud_field_extras/lib/zcrud_field_extras.dart] (fp-5-2 : pin/autocomplete/editableTable)
- [Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart] (46 valeurs)
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md] (§5 showcase + 6 formulaires)
- [Source: docs/dodlp-form-integration-study-2026-07-17/NEXT-ITERATION-SCOPE.md] (matrice + shortlist)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] (AD-2/4/12/13/50/55/56)

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M) — bmad-dev-story (effort high), périmètre `example/` UNIQUEMENT.

### Debug Log References

- Probes jetables (supprimés) : montabilité headless des adaptateurs riches +
  résolution `awesome_select`. Constats : tous les adaptateurs fp-4/fp-5 sont
  montables & routés (présence ≠ association) SAUF la WebView WYSIWYG
  `ZHtmlEditorField` (ET-5, non montable — confirmé) ; `ZHtmlView` (lecture)
  montable.

### Completion Notes List

**Réutilisé de fp-3-1 (sans réécriture)** : `axis_harness.dart`
(`ShowcaseAxis`/`AxisForm`/`AxisFormScreen`/`AxisHarnessScreen`, point
d'extension = ajout d'`AxisForm`), `showcase_data.dart` (socle étendu, pas
réécrit), `showcase_registry.dart`/`showcase_screen.dart` (étendus), le banc SM-1
(`RebuildLog`/`RebuildBadge`), les patrons de test (`pump_helpers`,
`showcase_sm1_test`).

**Ajouté** : matrice de couverture EXHAUSTIVE dérivée de l'enum
(`showcase_coverage.dart`, 46 types → statut connu, `CoverageStatus` sans valeur
« inconnu » ⇒ SM-2 par typage), 6 formulaires DODLP fictifs (`dodlp_forms.dart`),
section natif-vs-package (`showcase_native_vs_package.dart`, seams
`selectPresenter`/`colorPicker` côte à côte), 4 suites de tests.

**Capacités RETIRÉES de `absentCapabilities`** (désormais LIVE via leur vrai
adaptateur, prouvé par `find.byType`) : `select/radio/relation` modal
(`ZSmartSelectPresenter`), `mediaImage/mediaFile/mediaVideo` (`ZMediaFieldWidget`),
`html/inlineHtml` (`ZHtmlView` lecture + registrar WYSIWYG), `color` multiple
(`ZColorMultiFieldWidget`), `pin`/`autocomplete`/`editableTable`
(`field_extras`). Axes 2/3/4 basculés `upcoming → mvp` (6 axes MVP, 0 « à venir »).

**Gaps ASSUMÉS conservés (étiquetés ABSENT, justifiés)** : `icon` (hors parité
MVP), `latexSvgFallback` (`flutter_tex` banni par isolation), `itemsAreTags`
(mode natif dispo mais 0 call-site DODLP → OQ-6). Aucun faux-rendu.

**Écarts consignés** :
- **ET-5 (WebView WYSIWYG non montable headless)** : `ZHtmlEditorField`
  (`html_editor_enhanced`) n'est pas montable en `flutter test` (documenté dans le
  package lui-même). Les champs `html`/`inlineHtml` sont donc démontrés en
  **lecture** (`ZHtmlView`, montable) dans la showcase, le harnais et le banc SM-1 ;
  l'édition WYSIWYG reste exercée au RUNTIME. AC6 : granularité SM-1 prouvée sur un
  champ intensif standard entouré de **voisins riches** (`ZHtmlView` + `ZMarkdownField`
  STATEFUL dont le `State` SURVIT aux rebuilds — proxy du pattern d'isolation
  WYSIWYG, même `ValueKey` de place stable). Repli conforme à la note de l'AC6.
- **`awesome_select` (feuille privée de `zcrud_select`)** : le fork MIT vendorisé
  patché Flutter M3 vit sous `packages/awesome_select` (membre workspace). L'app
  STANDALONE (hors workspace) résolvait le HOSTED `awesome_select ^6.0.0` (CASSÉ :
  `headline6`/`errorColor` retirés) ⇒ ajout d'un `dependency_overrides:
  awesome_select: path: ../packages/awesome_select` dans `example/pubspec.yaml`
  (même patron transitif que `zcrud_annotations`/`zcrud_study_kernel`). AUCUN
  `packages/*` modifié.

**Aucun besoin de champ/adaptateur manquant** n'a émergé (frontière `packages/*`
respectée : `git status --porcelain packages/` VIDE).

**Correctifs code-review (`code-review-fp-3-2.md`)** :
- **MED-1** — `file`/`image`/`document` (étiquetés `liveNative`, comptés « Livré
  natif ») étaient ABSENTS du socle ⇒ comptés sans être montés. Ajout du groupe
  `_nativeFiles` (3 champs, rendus par leur VRAI adaptateur natif `ZAppFileField`
  via le dispatcher, seams picker/storage injectés, données fictives) + section
  « Fichiers natifs ». Ajout d'un **test DÉRIVÉ de la matrice** (`showcase_exhaustive_test.dart`,
  `MED-1`) : pour CHAQUE type `liveNative`/`liveSatellite` de `ShowcaseCoverage.byType`,
  exige AU MOINS un champ EFFECTIVEMENT monté dans le socle ET rendu sans repli
  `ZUnsupportedFieldWidget`. **Falsifiabilité prouvée** : `_nativeFiles` retiré du
  socle ⇒ test ROUGE nommant `EditionFieldType.file` (RC=1), restauré ⇒ vert.
- **LOW-2** — prose « WYSIWYG exercée au RUNTIME » corrigée (aucun call-site
  `ZHtmlEditorField` — grep 0) : `showcase_data.dart` + `showcase_coverage.dart`
  bornent honnêtement à « registrar câblé + rendu LECTURE (`ZHtmlView`) démontré ;
  aucun champ html ÉDITABLE monté (tous `readOnly`) ; éditeur WebView non montable
  en `flutter test` (ET-5), édition au runtime hors démo test ». Comportement
  INCHANGÉ (prose + note de couverture uniquement).

**Vérif verte rejouée (RC réels)** : `flutter test example` suite ENTIÈRE = **96
passed, RC=0** ; `dart analyze example` **RC=0** (seul subsiste l'`info`
deprecation PRÉ-EXISTANTE `softDeleteSelected` de `list_demo_screen.dart`,
fichier non touché) ; garde de frontière `boundary_deps_test.dart` VERTE
(`zcrud_mindmap` interdit, absent du lock ; les 4 nouveaux satellites en assertion
POSITIVE) ; `melos list` = 29 (inchangé, `example` hors workspace). Repo-wide
`melos analyze`/`verify` logiquement inchangés (`packages/*` intouché) — rejeu au
gate de commit d'epic par l'orchestrateur.

### File List

**Modifiés (example/ — les 2 modifs cadrées + les fichiers showcase fp-3-1)** :
- `example/pubspec.yaml` (+4 deps satellites `zcrud_select`/`zcrud_html`/`zcrud_media`/`zcrud_field_extras` + overrides ; + override transitif `awesome_select` → fork vendorisé)
- `example/test/boundary_deps_test.dart` (assertion POSITIVE étendue aux 4 satellites ; `zcrud_mindmap` reste INTERDIT)
- `example/lib/demos/showcase/showcase_data.dart` (socle étendu `_richNew`, absentCapabilities réconcilié, axes 2/3/4 → mvp + 6 formulaires DODLP ; **MED-1** groupe `_nativeFiles` file/image/document + section « Fichiers natifs » ; **LOW-2** prose HTML WYSIWYG bornée à la lecture)
- `example/lib/demos/showcase/showcase_coverage.dart` (**LOW-2** notes html/inlineHtml : `ZHtmlView` lecture, édition WYSIWYG runtime non montable en test — ET-5)
- `example/lib/demos/showcase/showcase_registry.dart` (`additionalRegistrars` html/media/field_extras + `wireGeoArea`)
- `example/lib/demos/showcase/showcase_screen.dart` (seam `ZMediaFilePicker`, section natif-vs-package, résumé de couverture)
- `example/test/showcase_screen_test.dart` (comptes ajustés : 3 markdown, 2 geo, 3 color ; gap représentatif LaTeX)
- `example/test/axis_harness_test.dart` (6 axes MVP, 0 « à venir »)

**Nouveaux (example/)** :
- `example/lib/demos/showcase/showcase_coverage.dart` (matrice 46 types → statut, dérivée de l'enum)
- `example/lib/demos/showcase/dodlp_forms.dart` (6 `AxisForm` DODLP fictifs)
- `example/lib/demos/showcase/showcase_native_vs_package.dart` (AC3, seams côte à côte)
- `example/test/showcase_exhaustive_test.dart` (AC1/AC2/AC4 ; **MED-1** test dérivé de la matrice : chaque type LIVE effectivement monté par son adaptateur réel, falsifiable)
- `example/test/showcase_native_vs_package_test.dart` (AC3)
- `example/test/dodlp_forms_harness_test.dart` (AC5)
- `example/test/showcase_sm1_wysiwyg_test.dart` (AC6)

**`packages/*`** : INTOUCHÉS (git porcelain vide).
