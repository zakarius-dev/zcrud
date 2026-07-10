---
baseline_commit: 6f6c9fb8f334a6c1bdf78ec35d4f3423cc22ecf6
---

# Story EX.3 : Démo des features restantes (Markdown / Geo / Intl / Export / Firestore-offline) dans l'application exemple

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur/évaluateur de zcrud (et futur intégrateur DODLP/lex_douane)**,
je veux **clore l'app exemple (`example/`) en y montant les DERNIÈRES features MVP end-to-end — édition Markdown riche (`ZMarkdownField` + embeds LaTeX/tableau + sélecteur de `ZCodec`), champs géo (`location`/`geoArea` via `ZWidgetRegistry` + adaptateur OSM), champs internationaux (téléphone/pays/adresse via `ZWidgetRegistry`), export tabulaire (Excel/PDF via `ZExporter`) et persistance offline (`HiveZLocalStore` derrière le port `ZLocalStore`, + documentation pour brancher Firestore réel) — chaque écran câblé depuis l'accueil, les champs géo/intl servis par un `ZWidgetRegistry` peuplé injecté au `ZcrudScope` racine et re-propagé sous les 4 bindings**,
afin de **prouver en conditions réelles les moteurs E6 (`zcrud_markdown`), E11a (`zcrud_geo`/`zcrud_intl`/`zcrud_export`) et E5 (`zcrud_firestore`), l'invariant SM-5 (les libs lourdes — Quill / flutter_map / Syncfusion xlsio-pdf / Firebase / Hive — sont tirées EXCLUSIVEMENT par les satellites, jamais par `zcrud_core`) et la parité multi-gestionnaire (AD-2/AD-15), sans jamais rompre l'invariant « 14 packages produit » ni toucher AUCUN package sous `packages/`**.

**C'est la TROISIÈME et DERNIÈRE story de l'epic EX (application exemple).** L'app croît avec les epics : édition (EX-1, done) → liste (EX-2, done) → **reste des features MVP (EX-3, cette story)**. Elle CLÔT l'epic EX en démontrant tout le périmètre MVP restant ; les flashcards (E9) et cartes mentales (E10) restent **hors périmètre** (v1.x, cf. §Frontière).

**Développée EN PARALLÈLE de REL-1** (préparation des métadonnées de publication des packages) : fichiers **strictement disjoints** — EX-3 reste **exclusivement dans `example/`** ; REL-1 touche les métadonnées sous `packages/`. Aucune dépendance croisée, aucune écriture concurrente.

## Contexte

- **Origine** : consigne user 2026-07-10 + sprint-status section EX (`ex-3-reste-features-demo: backlog`). L'app exemple est le **harnais de validation croissant** défini en EX-1/EX-2 : après l'édition (E3) et la liste (E4), elle doit exercer Markdown (E6), Geo/Intl/Export (E11a) et Firestore-offline (E5) pour prouver SM-5 (l'app tire les libs lourdes via les satellites) et l'isolation AD-1 (aucun type de SDK — Quill/flutter_map/Syncfusion/Firebase/Hive — ne fuit dans `zcrud_core`). [Source: sprint-status.yaml (section EX) ; ex-1-scaffold-edition-demo.md ; ex-2-list-demo.md]
- **État réel du dépôt** (vérifié sur disque, `git rev-parse HEAD` = `6f6c9fb`) : **E6 done** (`zcrud_markdown` : `ZMarkdownField`, `ZCodec`/`ZDeltaCodec`/`ZMarkdownCodec`, `ZMarkdownCodecScope`, embeds LaTeX/tableau) ; **E11a done** (`zcrud_geo` : `ZGeoFieldWidget` + `ZMapAdapter` + adaptateur OSM `ZOsmMapAdapter` ; `zcrud_intl` : `ZPhoneFieldWidget`/`ZCountryFieldWidget`/`ZAddressFieldWidget` + `ZCountryCatalog` ; `zcrud_export` : `ZExporter.toExcelBytes/toPdfBytes` + `ZExportTable`) ; **E5 done (MVP)** (`zcrud_firestore` : `HiveZLocalStore`, `FirestoreZRemoteStore`, `FirebaseZRepositoryImpl` derrière les ports neutres `ZLocalStore`/`ZRemoteStore`/`ZRepository`). `dart run melos list` = **14** packages.
- **Ce que EX-1/EX-2 ont déjà posé** (à RÉUTILISER, NE PAS réinventer) :
  - `ExampleApp` (`lib/app.dart`) : `MaterialApp` + `ZcrudScope` **racine** dans le `builder:` (thème `ZcrudTheme` de démo `gapM/gapL`, `DemoFilePicker`, **`listRenderer: const ZSfDataGridRenderer()`** injecté en EX-2), l10n zcrud fr/en, toggles thème/langue/**RTL** (`Directionality` explicite, AD-13).
  - `HomeScreen` (`lib/home_screen.dart`) : `ListView.builder` d'entrées `_DemoEntry` par domaine. « Édition » + « Liste » actives ; **« Firestore / offline », « Markdown », « Geo / Intl / Export » présentes mais DÉSACTIVÉES** (`available: false`, chip « à venir », `_staticEntries`).
  - `binding/binding_selector.dart` : `DemoBinding {scope, get, riverpod, provider}`, `wrapWithBinding(binding, child, {rootScope})` + **`_BindingSeamForwarder`** qui re-propage sous le scope d'un binding les seams du scope racine — **il forwarde DÉJÀ `root.widgetRegistry`** (ligne 83, vérifié sur disque) en plus de `labels`/`theme`/`filePicker`/`cloudStorage`/`listRenderer`. **AUCUNE modification requise** de ce fichier (cf. §Décision structurante).
  - Écrans de démo : `demos/edition_demo_screen.dart` (patron `BindingSelector` + `wrapWithBinding(rootScope: ZcrudScope.maybeOf(context))` + `KeyedSubtree(ValueKey(binding))` + dispose dépendant→dépendance, MAJEUR-1 EX-1), `demos/list_demo_screen.dart` + `demos/list_demo_data.dart` (`DemoRecord`/`DemoStore`/`DemoRepository` + `demoSchema` + `toDemoRow`, in-memory).
  - Support : `support/demo_file_picker.dart`, `support/rebuild_indicator.dart`, `test/support/pump_helpers.dart`.
  - Tests : `test/boundary_deps_test.dart` (frontière deps — À ÉTENDRE), `binding_parity_test.dart`, `app_smoke_test.dart`, `edition_families_test.dart`, `list_demo_test.dart`, `sm1_granular_rebuild_test.dart`.
  [Source: example/lib/app.dart:62-89 ; home_screen.dart:59-97 ; binding/binding_selector.dart:41-90 ; demos/edition_demo_screen.dart:52-143 ; demos/list_demo_screen.dart ; test/boundary_deps_test.dart]

## Décision structurante — registre de widgets injecté au scope racine + point d'injection des satellites

**DÉCISIONS (orchestrateur, à appliquer par dev-story) :**

1. **Le `ZWidgetRegistry` (peuplé des builders géo/intl, et éventuellement markdown) est injecté au `ZcrudScope` RACINE** (`example/lib/app.dart`), pas au niveau d'un écran. Ajouter `widgetRegistry: demoWidgetRegistry` au `ZcrudScope` racine du `builder:` de `ExampleApp`. **Raison** : identique à `listRenderer` en EX-2 — le `_BindingSeamForwarder` (`binding_selector.dart:83`) ne re-propage sous un binding QUE les seams captés depuis le **scope racine** (`root.widgetRegistry`). Injecter le registre plus bas que le scope racine le rendrait invisible sous get/riverpod/provider (`maybeOf` = plus proche seulement) → les champs `location`/`geoArea`/`phoneNumber`/`country`/`address` retomberaient sur `ZUnsupportedFieldWidget` sous 3 des 4 bindings (le dispatcher `ZFieldWidget` route `EditionFamily.registryOrFallback` → `ZcrudScope.maybeOf(context)?.widgetRegistry?.tryBuilderFor(field.type.name)`, cf. `z_field_widget.dart:437-438`). Injecter à la racine = parité gratuite des 4 voies (AC10). **`binding_selector.dart` n'est PAS modifié** (il forwarde déjà `widgetRegistry`).
2. **Le registre `demoWidgetRegistry` est construit UNE fois** (instance non-mutable après peuplement, AD-4 : jamais un singleton statique mutable global — l'instancier dans `ExampleApp` et le passer par valeur, ou dans un fichier support `demos/demo_registry.dart`). Peuplement (kinds ↔ builders des satellites, signatures vérifiées sur disque) :
   - `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))`
   - `registry.register('geoArea', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))`
   - `registry.register('phoneNumber', ZPhoneFieldWidget.builder(catalog: cat))`
   - `registry.register('country', ZCountryFieldWidget.builder(catalog: cat))`
   - `registry.register('address', ZAddressFieldWidget.builder(catalog: cat))`
   - (optionnel) `registry.register('markdown', (context, ctx) => ZMarkdownField(controller: <?>, field: ctx.field))` — **NON recommandé** : `ZMarkdownField` exige un `ZFormController` (contrôleur isolé E6/AD-7), or `ZFieldWidgetContext` n'expose que `value`/`onChanged` (pas de `ZFormController`). Pour la démo Markdown, monter **`ZMarkdownField` DIRECTEMENT** sur un `ZFormController` local (cf. AC3) plutôt que via le registre.
   Le `catalog` intl est partagé (une seule instance `ZCountryCatalog` — l'asset JSON n'est lu qu'une fois ; sans `catalog:` explicite les builders partagent déjà `sharedDefaultCountryCatalog()`).
3. **Les packages satellites sont ajoutés au SEUL `pubspec.yaml` de `example/`** (deps `path:` + `dependency_overrides` `path:`, calqués sur `zcrud_core`/bindings/`zcrud_list` existants). L'app reste **hors** du bloc `workspace:` racine et hors du glob melos `packages/**` (invariant « 14 » préservé, lock propre `example/pubspec.lock`). Packages ajoutés : `zcrud_markdown`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_firestore`.
4. **Démo Firestore/offline = `HiveZLocalStore` (offline réel, sans backend Firebase)**, derrière le port `ZLocalStore<DemoRecord>`. **Raison** : une démo qui exige un projet Firebase configuré (`Firebase.initializeApp()` + `google-services.json`/config web) ne serait ni portable ni testable hermétiquement. On démontre l'offline-first via `HiveZLocalStore` (`Hive.initFlutter()` au démarrage) et on **documente** (texte + commentaires) le branchement de `FirestoreZRemoteStore`/`FirebaseZRepositoryImpl` pour le distant. L'écran de démo est construit **contre le port** `ZLocalStore` (injectable) : runtime = `HiveZLocalStore` ; test = adaptateur hermétique (voir AC7/§Ambiguïtés #4).

**Risques connus à valider en dev-story (ambiguïtés, cf. §Ambiguïtés)** : (a) `resolution: workspace` des satellites vs `path:` (voie standalone EX-1/EX-2 attendue) ; (b) `zcrud_firestore` tire `cloud_firestore`/`firebase_core` — impact sur `flutter build web` sans config Firebase (le simple fait de *dépendre* du plugin ne doit pas casser le build web ; seul `initializeApp()` exigerait la config — À PROUVER par un `flutter build web` réel) ; (c) initialisation Hive en test widget (temp dir vs adaptateur in-memory).

## Acceptance Criteria

1. **AC1 — Satellites ajoutés au SEUL pubspec de l'app ; l'app compile ; `packages/` INCHANGÉ.** Le `pubspec.yaml` de `example/` déclare `zcrud_markdown`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_firestore` (deps `path: ../packages/<pkg>` + entrées miroir `dependency_overrides` `path:`), tirant transitivement Quill / flutter_map+latlong2 / Syncfusion xlsio+pdf / cloud_firestore+firebase_core+hive+hive_flutter. `flutter pub get` RC=0 (lock **propre** `example/pubspec.lock`, root `pubspec.lock` intact). `flutter analyze` (app) RC=0 ; `flutter test` (app) RC=0. **AUCUN** fichier sous `packages/**` n'est créé/modifié (`git status -- packages/` ne montre AUCUN fichier attribuable à EX-3). Given un checkout → When `flutter pub get && flutter analyze && flutter test` dans `example/` → Then RC=0 et `packages/` inchangé.

2. **AC2 — Invariant « 14 packages PRODUIT » préservé.** `dart run melos list` retourne **exactement 14** packages ; l'app exemple n'y figure pas. `python3 scripts/dev/graph_proof.py` reste vert (CORE OUT=0, acyclique). `dart run scripts/ci/gate_melos_divergence.dart` (M-1) reste vert. Given les satellites ajoutés à l'app → When on rejoue melos list + graph_proof + gate:melos → Then 14 packages, graphe inchangé, M-1 vert. (Les libs lourdes tirées dans le lock **de l'app** ne polluent PAS le lock racine — SM-5/AD-15.)

3. **AC3 — Écran démo MARKDOWN : `ZMarkdownField` + embeds + sélecteur de `ZCodec` + valeur persistée.** Un écran `MarkdownDemoScreen` (`example/lib/demos/markdown_demo_screen.dart`) monte un **`ZMarkdownField`** (`showToolbar: true`) sur un `ZFormController` **stable** (créé en `initState`, `dispose` en fin de vie) portant un champ `EditionFieldType.markdown`. La **toolbar** expose les embeds **LaTeX** et **tableau** (boutons E6-3/E6-4). Un **sélecteur `ZCodec`** (segmenté : « Delta » `const ZDeltaCodec()` / « Markdown » `const ZMarkdownCodec()`) fixe le codec (via le paramètre `codec:` du champ **ou** un `ZMarkdownCodecScope` — documenter le choix ; noter que le codec est résolu 1× au montage : changer de codec re-monte le champ via une `Key`). La **valeur persistée** courante de la tranche (`controller.valueOf(name)` — Delta JSON ou String Markdown selon le codec) est affichée en lecture (zone de texte read-only) pour matérialiser l'encodage. Given l'écran monté → When on tape du texte / insère un embed LaTeX ou tableau / bascule le codec → Then le champ édite sans perte de focus (AD-2), l'embed s'insère, et la valeur persistée affichée reflète l'encodage du codec choisi.

4. **AC4 — Écran démo GEO : `location` + `geoArea` via `ZWidgetRegistry` + adaptateur OSM.** Un écran `GeoDemoScreen` (`example/lib/demos/geo_demo_screen.dart`) monte une `DynamicEdition` (ou un `ZFieldWidget` par champ) sur un `ZFormController` stable avec un schéma comportant **au moins un `EditionFieldType.location`** et **un `EditionFieldType.geoArea`**. Ces champs sont rendus par le `demoWidgetRegistry` **injecté au scope racine** (`ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new)`), avec la carte OSM (`flutter_map`, **sans clé API** — AD-12/E1-5). La valeur de tranche reste **neutre** (`ZGeoPoint`/`ZGeoShape`, aucun type SDK carte). Given l'écran monté → When on inspecte le champ géo → Then le widget géo (champs coordonnées + carte OSM) est rendu via le registre ; When on fixe un point / ajoute un sommet → Then la valeur neutre de tranche est mise à jour (pas de `ZUnsupportedFieldWidget`).

5. **AC5 — Écran démo INTL : téléphone / pays / adresse via `ZWidgetRegistry`, validation numéro.** Un écran `IntlDemoScreen` (`example/lib/demos/intl_demo_screen.dart`) monte une `DynamicEdition` sur un `ZFormController` stable avec un schéma comportant **un `EditionFieldType.phoneNumber`, un `EditionFieldType.country`, un `EditionFieldType.address`**. Ces champs sont rendus par le `demoWidgetRegistry` racine (`ZPhoneFieldWidget.builder`/`ZCountryFieldWidget.builder`/`ZAddressFieldWidget.builder`, `ZCountryCatalog` partagé). Le champ **téléphone valide** un numéro : saisir un numéro valide produit une valeur de tranche **`ZPhoneNumber` (E.164)** ; un numéro invalide est signalé (erreur de validation du champ). Given l'écran monté → When on saisit un numéro/ sélectionne un pays / renseigne une adresse → Then chaque champ intl est rendu via le registre, un numéro valide est normalisé en E.164 (valeur `ZPhoneNumber` neutre), un numéro invalide est signalé.

6. **AC6 — Écran démo EXPORT : liste EX-2 → Excel/PDF via `ZExporter`, bytes non vides.** Un écran `ExportDemoScreen` (`example/lib/demos/export_demo_screen.dart`) réutilise le **schéma + données de démo EX-2** (`demoSchema` + lignes de `DemoRepository`/`DemoStore`) pour construire un `ZListRenderRequest` (`ZListRenderRequest.fromSchema(demoSchema, rows, policy: ...)` — colonnes dérivées + `ZListRow`). Deux boutons **« Exporter Excel »** / **« Exporter PDF »** appellent `const ZExporter().toExcelBytes(request, resolveHeader: ...)` / `.toPdfBytes(...)` et produisent des **`Uint8List` non vides** (Excel = `.xlsx` ; PDF = préfixe `%PDF-`). Les bytes sont **partagés/enregistrés** via une couture app (au minimum : `DemoFilePicker`/écriture, ou un hook de partage ; un snackbar confirmant `bytes.length > 0` est acceptable pour la démo — documenter). Given l'écran → When on tape « Exporter Excel » puis « Exporter PDF » → Then chaque appel renvoie des bytes non vides (Excel non vide ; PDF commençant par `%PDF-`), confirmés à l'utilisateur.

7. **AC7 — Écran démo FIRESTORE/OFFLINE : CRUD offline via `HiveZLocalStore` (port `ZLocalStore`) + doc Firestore.** Un écran `OfflineDemoScreen` (`example/lib/demos/offline_demo_screen.dart`) démontre un **CRUD offline** (créer / lister / modifier / soft-delete+restore / clear) sur `DemoRecord`, adossé au port **`ZLocalStore<DemoRecord>`** dont l'implémentation runtime est **`HiveZLocalStore`** (`zcrud_firestore`). Les signatures consommées restent **neutres** (`ZResult<…>`, `Stream<List<T>>` nus — aucun type Hive/Firestore ne fuit). Le magasin local est la **source de vérité** (offline-first, AD-9). Un **bloc de documentation** (commentaires + section README/notes) explique comment brancher le **distant Firestore réel** (`FirestoreZRemoteStore` + `FirebaseZRepositoryImpl` après `Firebase.initializeApp()`), **non initialisé** dans la démo (aucun secret/clé committé). Given l'écran → When on crée/liste/modifie/supprime-restaure un enregistrement → Then la vue reflète l'état du store local (persistance offline), sans backend Firebase ; la voie Firestore est documentée mais non requise.

8. **AC8 — `ZWidgetRegistry` peuplé + injecté au `ZcrudScope` racine, re-propagé sous les bindings.** Le `demoWidgetRegistry` (kinds `location`/`geoArea`/`phoneNumber`/`country`/`address` enregistrés) est injecté via `ZcrudScope(widgetRegistry: ...)` au **scope racine** (`app.dart`). `binding_selector.dart` **n'est pas modifié** (il forwarde déjà `root.widgetRegistry`). Given le registre injecté à la racine → When une `DynamicEdition` avec des champs géo/intl est montée sous n'importe lequel des 4 bindings → Then chaque champ est résolu par le registre (jamais `ZUnsupportedFieldWidget`). Un test assert `ZcrudScope.of(context).widgetRegistry` contient les 5 kinds et rend les champs géo/intl sous ≥ 2 wraps.

9. **AC9 — Câblage accueil : entrées Markdown / Geo / Intl / Export / Firestore ACTIVÉES.** Dans `home_screen.dart`, les entrées correspondantes ne sont plus « à venir »/désactivées : elles sont **actives** (`available: true`, `onOpen:` navigant vers l'écran de démo dédié), cibles tactiles ≥ 48 dp (AD-13). Le libellé/regroupement peut être ajusté (ex. « Geo / Intl / Export » scindé en entrées ou conservé comme hub — documenter). Given l'accueil → When on tape chaque entrée activée → Then l'app navigue vers l'écran de démo correspondant sans exception. **Plus AUCUNE entrée « à venir »** ne subsiste pour une feature MVP (EX clôturé ; flashcards/mindmaps NON listées ou marquées v1.x, cf. Frontière).

10. **AC10 — Parité multi-binding (AD-15) sur les écrans servis par le registre.** Les écrans Geo et Intl (champs servis par `demoWidgetRegistry`) réutilisent `BindingSelector` + `wrapWithBinding(binding, body, rootScope: ZcrudScope.maybeOf(context))` + `KeyedSubtree(ValueKey(binding))` (nouveau `ZFormController` par wrap, dispose dépendant→dépendance, MAJEUR-1 EX-1). Le rendu des champs géo/intl est **identique** sous les 4 voies (scope / get / riverpod / provider) grâce à la re-propagation de `root.widgetRegistry`. Un test monte un écran registre-servi sous **≥ 2** wraps (défaut + 1 binding) et assert la parité observable (champs rendus, aucun `ZUnsupportedFieldWidget`). Pour l'écran Markdown (contrôleur isolé, non servi par le registre), la parité binding est **optionnelle** — si non exposée, le documenter. Given un écran géo/intl → When on change de binding → Then rendu identique, champs toujours résolus.

11. **AC11 — SM-5 non cassé + isolation AD-1 démontrée.** `zcrud_core` **reste** sans Quill / flutter_map / Syncfusion / Firebase / Hive (aucune modification de `zcrud_core` par cette story). Chaque lib lourde vient **exclusivement** de son satellite, importé par l'**app** : Quill via `zcrud_markdown`, flutter_map via `zcrud_geo` (adaptateur OSM via `package:zcrud_geo/adapters/osm.dart`), Syncfusion xlsio/pdf via `zcrud_export`, Firebase/Hive via `zcrud_firestore`. Aucun type de SDK ne fuit dans une valeur de tranche ni dans le code app hors de son point d'usage. Le lock racine **n'est pas pollué**. Given la story terminée → When on inspecte `git diff` sur `packages/` et le lock racine → Then `packages/` inchangé, lock racine non pollué, aucune lib lourde importée hors de `example/`.

12. **AC12 — Frontière EX-3 = clôture EX + gates transverses verts.** Le test de frontière (`example/test/boundary_deps_test.dart`) est **mis à jour** : `zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/`zcrud_export`/`zcrud_firestore` désormais **AUTORISÉS** (en plus de `zcrud_core` + 3 bindings + `zcrud_list`) ; **`zcrud_flashcard` et `zcrud_mindmap` restent INTERDITS** (E9/E10 = v1.x, hors MVP). Aucune démo flashcard/mindmap n'est ajoutée. Les gates transverses restent verts : `gate:reflectable` (aucun `reflectable` introduit), `gate:secrets` (**aucune clé Google Maps** — OSM sans clé, AD-12 ; **aucune config/clé Firebase** committée ; aucune licence Syncfusion committée), `gate:codegen`. Given le `pubspec.yaml` de l'app → When on liste ses deps → Then les 10 packages autorisés uniquement, `zcrud_flashcard`/`zcrud_mindmap` absents ; gates verts.

## Tasks / Subtasks

- [x] **T1 — Ajouter les 5 satellites au pubspec de l'app + `flutter pub get` réel (AC1, AC2, AC11, AC12).**
  - [x] Dans `example/pubspec.yaml` : ajouter `zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/`zcrud_export`/`zcrud_firestore` (`path: ../packages/<pkg>`) au bloc `dependencies` ET les entrées miroir dans `dependency_overrides` (calqué sur `zcrud_core`/bindings/`zcrud_list`). Mettre à jour le commentaire d'en-tête (frontière EX-3 : ces 5 désormais autorisés ; `zcrud_flashcard`/`zcrud_mindmap` toujours interdits, v1.x).
  - [x] Tenter `flutter pub get` réel dans `example/`. Documenter la voie retenue (standalone `path:`+overrides attendue, comme EX-1/EX-2) et la preuve (RC=0, nb deps du lock propre, root lock intact).
  - [x] Si l'app appelle `Hive.initFlutter()` / référence `Box` ou une API Hive **directement** (AC7), déclarer `hive`/`hive_flutter` en deps directes (transitives via `zcrud_firestore`, `depend_on_referenced_packages`) — documenter. De même pour tout type Syncfusion/Quill importé explicitement en test-only (comme `syncfusion_flutter_datagrid` en EX-2).
  - [x] Vérifier `dart run melos list` = **14**, `graph_proof.py` vert, `gate:melos` (M-1) vert (AC2). Vérifier `git status -- packages/` sans fichier EX-3 (AC1/AC11).
- [x] **T2 — Construire + injecter `demoWidgetRegistry` au `ZcrudScope` racine (AC4, AC5, AC8, AC10).**
  - [x] Créer `example/lib/demos/demo_registry.dart` (ou l'assembler dans `app.dart`) : `ZWidgetRegistry demoWidgetRegistry()` peuplant `location`/`geoArea` (`ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new)`, import `package:zcrud_geo/zcrud_geo.dart` + `package:zcrud_geo/adapters/osm.dart`) et `phoneNumber`/`country`/`address` (`ZPhoneFieldWidget.builder`/`ZCountryFieldWidget.builder`/`ZAddressFieldWidget.builder`, `package:zcrud_intl/zcrud_intl.dart`, `ZCountryCatalog` partagé). Instance construite UNE fois (AD-4, pas de singleton mutable global).
  - [x] Dans `example/lib/app.dart`, ajouter `widgetRegistry: <instance>` au `ZcrudScope` **racine** du `builder:`. Justification en commentaire : la racine est le seul point re-propagé par `_BindingSeamForwarder` (parité 4 bindings, AC8/AC10).
  - [x] Confirmer que `binding_selector.dart` n'est PAS modifié (il forwarde déjà `root.widgetRegistry`, ligne 83) — sinon documenter.
- [x] **T3 — Écran `MarkdownDemoScreen` (AC3).**
  - [x] `example/lib/demos/markdown_demo_screen.dart` : `StatefulWidget`, `ZFormController` stable (`initState`/`dispose`), champ `EditionFieldType.markdown`. Monter `ZMarkdownField(controller:, field:, showToolbar: true, codec: <sélectionné>)` DIRECTEMENT (contrôleur isolé E6/AD-7 — pas via le registre). Sélecteur `ZCodec` segmenté (Delta/Markdown) ; re-monter le champ via une `Key` au changement de codec (résolution codec 1× au montage, cf. `ZMarkdownCodecScope` doc). Zone read-only affichant `controller.valueOf(name)` (valeur persistée). Embeds LaTeX/tableau via la toolbar. Directionnel (AD-13), `const` où possible.
- [x] **T4 — Écran `GeoDemoScreen` (AC4, AC10).**
  - [x] `example/lib/demos/geo_demo_screen.dart` : `ZFormController` stable + schéma `[location, geoArea]` (`ZFieldSpec`), monté via `DynamicEdition` (ou `ZFieldWidget` par champ). Les champs résolus par le registre racine (OSM). `BindingSelector` + `wrapWithBinding(rootScope:)` + `KeyedSubtree(ValueKey(binding))`, nouveau controller par wrap, dispose dépendant→dépendance (MAJEUR-1). Valeur neutre `ZGeoPoint`/`ZGeoShape`.
- [x] **T5 — Écran `IntlDemoScreen` (AC5, AC10).**
  - [x] `example/lib/demos/intl_demo_screen.dart` : `ZFormController` stable + schéma `[phoneNumber, country, address]`, `DynamicEdition`, champs résolus par le registre racine. Démontrer la validation E.164 du téléphone (valeur `ZPhoneNumber`). Parité binding comme T4.
- [x] **T6 — Écran `ExportDemoScreen` (AC6, AC11).**
  - [x] `example/lib/demos/export_demo_screen.dart` : réutiliser `demoSchema` + lignes de `DemoRepository`/`DemoStore` (EX-2) → `ZListRenderRequest.fromSchema(demoSchema, rows, policy: ...)`. Boutons « Exporter Excel »/« Exporter PDF » → `const ZExporter().toExcelBytes(request, resolveHeader:)` / `.toPdfBytes(...)`. Confirmer `bytes.length > 0` (snackbar) ; couture partage/enregistrement (via `DemoFilePicker`/écriture ou hook — documenter le choix). Aucune licence Syncfusion committée.
- [x] **T7 — Écran `OfflineDemoScreen` (AC7, AC11).**
  - [x] `example/lib/demos/offline_demo_screen.dart` : CRUD offline `DemoRecord` contre le port `ZLocalStore<DemoRecord>` **injectable** ; runtime = `HiveZLocalStore` (via `HiveZLocalStore.openBox(kind:, fromMap:, toMap:)` après `Hive.initFlutter()` — appel guardé dans `main.dart`/au montage). Opérations : `put`/`watchAll`/`softDelete`/`restore`/`clear`. Bloc de doc (commentaires + notes) sur le branchement `FirestoreZRemoteStore`/`FirebaseZRepositoryImpl` (non initialisé, aucun secret). Vue reflétant `watchAll()`.
  - [x] `DemoRecord` doit exposer `toMap`/`fromMap` (réutiliser/étendre le modèle EX-2 `list_demo_data.dart` sans casser EX-2 ; si `DemoRecord` EX-2 n'a pas de (dé)sérialisation map, l'ajouter DANS `example/` de façon additive, ou définir un modèle offline dédié — documenter).
- [x] **T8 — Câblage accueil (AC9).**
  - [x] `home_screen.dart` : déplacer les entrées Firestore/Markdown/Geo/Intl/Export de `_staticEntries` (désactivées) vers des entrées **actives** dans `_entries` (`available: true`, `onOpen:` → écran dédié). Ajuster libellés/regroupement (documenter). Plus aucune entrée MVP « à venir ». Cibles ≥ 48 dp (AD-13).
- [x] **T9 — Tests + vérif verte + gates (AC1, AC3–AC12).**
  - [x] Widget, un test par écran (affichage + 1 interaction) : Markdown (édite + insère un embed / bascule codec → valeur persistée change) ; Geo (champ géo rendu via registre, pas d'`ZUnsupportedFieldWidget` ; fixe un point → valeur neutre) ; Intl (téléphone valide → `ZPhoneNumber` E.164 ; invalide → signalé) ; Export (Excel bytes non vides + PDF `%PDF-`) ; Offline (create→list→softDelete→restore reflété par le store).
  - [x] Registre/parité : `demoWidgetRegistry` contient les 5 kinds ; un écran registre-servi monté sous ≥ 2 wraps (défaut + 1 binding) → rendu identique, aucun `ZUnsupportedFieldWidget` (AC8/AC10).
  - [x] Navigation : tap de chaque entrée d'accueil → écran poussé (AC9).
  - [x] Frontière : mettre à jour `example/test/boundary_deps_test.dart` — AUTORISER les 5 satellites ; INTERDIRE `zcrud_flashcard`/`zcrud_mindmap` (AC12).
  - [x] Vérif verte : `flutter analyze` (app) RC=0 ; `flutter test` (app) RC=0 ; `flutter build web` compile (prouve que dépendre de `zcrud_firestore`/Firebase ne casse pas le build — ambiguïté (b)). `melos list` = 14 ; `graph_proof.py`/`gate:melos`/`gate:reflectable`/`gate:secrets`/`gate:codegen` verts ; `git status -- packages/` sans fichier EX-3 ; lock racine inchangé.

## Dev Notes

### Contraintes d'architecture applicables (rappel AD)

- **AD-1 / SM-5 (isolation, cœur léger)** : `zcrud_core` reste sans Quill/flutter_map/Syncfusion/Firebase/Hive. L'app exemple, CONSOMMATEUR, a le droit de tirer les satellites — ça ne casse PAS SM-5 (qui concerne le graphe de `zcrud_core`, pas des apps). Chaque barrel satellite est **isolant** : aucun type de SDK n'est réexporté (vérifié — cf. commentaires des barrels `zcrud_markdown`/`zcrud_geo`/`zcrud_intl`/`zcrud_export`/`zcrud_firestore`). L'adaptateur OSM concret est atteint via l'entrée dédiée `package:zcrud_geo/adapters/osm.dart` (le SDK carte reste hors de la voie d'import par défaut). Le lock **de l'app** porte les libs lourdes ; le lock **racine** ne doit PAS. [Source: packages/*/lib/<pkg>.dart (barrels) ; architecture.md#AD-1 ; prd.md SM-5 ; ex-2-list-demo.md#AC11]
- **AD-2 / AD-15 (réactivité Flutter-native, parité)** : `ZFormController` = `ChangeNotifier` pur-Flutter, une tranche `ValueListenable` par champ. Les champs registre-servis lisent `ctx.value` / écrivent `ctx.onChanged` **dans** la frontière de rebuild du dispatcher (aucune souscription élargie). Le rich-text (`ZMarkdownField`) gère SON contrôleur isolé (AD-7). Contrôleurs dans le `State` (create `initState` / dispose). Code manager-spécifique confiné au `wrap` (`binding_selector.dart`). [Source: z_widget_registry.dart:30-66 ; z_markdown_field.dart:27-69 ; architecture.md#AD-2/#AD-7/#AD-15]
- **AD-4 (extensibilité par registre)** : `ZWidgetRegistry` est **instanciable**, injecté via `ZcrudScope.widgetRegistry` — jamais un singleton statique mutable. `register(kind, builder)` throw sur collision (`ZDuplicateRegistrationError`) ; le dispatcher utilise `tryBuilderFor` (défensif → repli `ZUnsupportedFieldWidget`). [Source: z_widget_registry.dart:71-108 ; architecture.md#AD-4]
- **AD-9 (offline-first)** : store local = source de vérité ; distant fire-and-forget. La démo n'exerce que le local (`HiveZLocalStore`) ; le merge LWW/orchestrateur (E5-3/E5-4) est v1.x (backlog) — hors périmètre. [Source: hive_z_local_store.dart ; z_local_store.dart ; architecture.md#AD-9]
- **AD-12 / gate:secrets (pas de secret)** : OSM **sans clé API** (flutter_map) ; **aucune** clé Google Maps, **aucune** config/clé Firebase, **aucune** licence Syncfusion committée. La config Firebase (`Firebase.initializeApp()`) est une responsabilité plateforme de l'app hôte, hors démo. [Source: architecture.md#AD-12 ; e1-5-revocation-cle-google-maps.md ; CLAUDE.md Key Don'ts]
- **AD-13 (a11y/RTL)** : variantes **directionnelles** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`), cibles ≥ 48 dp, `Semantics` explicites ; le toggle RTL de l'accueil doit continuer d'exercer la direction sur les nouveaux écrans. [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts]
- **AD-1 / « 14 packages » + `ListView.builder` + `const`** : `example/` reste hors `workspace:` racine et hors glob melos `packages/**` ; NE modifier AUCUN fichier sous `packages/`. Jamais `ListView(children:)`. [Source: pubspec.yaml ; ex-1/ex-2 stories]

### API publique consommée (signatures réelles, vérifiées sur disque — LECTURE SEULE de `packages/`)

**`zcrud_core` (dispatch + registre + ports)** :
- **`ZWidgetRegistry`** (`z_widget_registry.dart:71`) : `ZWidgetRegistry()` ; `void register(String kind, ZFieldWidgetBuilder builder)` (throw `ZDuplicateRegistrationError` sur collision) ; `bool isRegistered(String)` ; `Iterable<String> get kinds` ; `ZFieldWidgetBuilder builderFor(String)` (throw `ZUnregisteredTypeError`) ; `ZFieldWidgetBuilder? tryBuilderFor(String)` (null si absent). [Source: z_widget_registry.dart:71-108]
- **`typedef ZFieldWidgetBuilder = Widget Function(BuildContext context, ZFieldWidgetContext ctx)`** ; **`ZFieldWidgetContext`** = `const ZFieldWidgetContext({ required ZFieldSpec field, required Object? value, required ValueChanged<Object?> onChanged })`. Le builder lit `ctx.value` / écrit `ctx.onChanged`. **Pas de `ZFormController` dans le ctx** (raison pour laquelle Markdown est monté directement, pas via le registre). [Source: z_widget_registry.dart:30-66]
- Dispatch : `ZFieldWidget` route `EditionFamily.registryOrFallback` → `ZcrudScope.maybeOf(context)?.widgetRegistry?.tryBuilderFor(field.type.name)` ; si absent → `ZUnsupportedFieldWidget`. Les types `location`/`geoArea`/`phoneNumber`/`country`/`address`/`markdown`/`inlineMarkdown`/`richText`/`icon`/`custom` sont « servis ailleurs ». [Source: z_field_widget.dart:411-438]
- **`EditionFieldType`** (`edition_field_type.dart:39`) : contient `markdown` (130), `inlineMarkdown`, `richText` (142), `location` (100), `geoArea` (103), `phoneNumber` (106), `country` (109), `address` (112), + scalaires EX-2. [Source: edition_field_type.dart:39-142]
- **`ZcrudScope`** : `widgetRegistry: ZWidgetRegistry?` (`zcrud_scope.dart:52,74`) ; `ZcrudScope.of(context)`/`maybeOf(context)`. [Source: zcrud_scope.dart:52-74]
- **`ZLocalStore<T extends ZEntity>`** (port, `z_local_store.dart:44`) : `Stream<List<T>> watchAll()` ; `Future<ZResult<List<T>>> getAll()` ; `Future<ZResult<T>> getById(String)` ; `Future<ZResult<T>> put(T)` ; `Future<ZResult<Unit>> softDelete(String)` ; `Future<ZResult<Unit>> restore(String)` ; `Future<ZResult<Unit>> clear()`. Flux NUS. [Source: z_local_store.dart:44-75]
- **`ZListRenderRequest`** : `const ZListRenderRequest({ required List<ZListColumn> columns, required List<ZListRow> rows })` ; **fabrique** `ZListRenderRequest.fromSchema(List<ZFieldSpec> fields, List<ZListRow> rows, { ZColumnPolicy? policy })` (dérive `columns` via `deriveColumns`). `ZListRow({ required String id, required Map<String,Object?> cells })`. [Source: z_list_render_request.dart:70-92 ; :33]

**`zcrud_markdown`** (barrel `package:zcrud_markdown/zcrud_markdown.dart`) :
- **`ZMarkdownField`** (`z_markdown_field.dart:27`) : `const ZMarkdownField({ required ZFormController controller, required ZFieldSpec field, bool showToolbar = true, ZCodec? codec, VoidCallback? onInit, VoidCallback? onBuild, Key? key })`. Consomme/expose une valeur neutre (Delta JSON) via `ZFormController` — aucun type Quill n'est exposé. La toolbar porte les embeds LaTeX (E6-3) et tableau (E6-4). [Source: z_markdown_field.dart:27-69]
- **`ZCodec`** (abstract, `z_codec.dart:29`) : `String encode(...)` / `List<Map<String,dynamic>> decode(Object? persisted)` (défensif AD-10). Implémentations : **`const ZDeltaCodec()`** (`z_delta_codec.dart:22` — Delta JSON, decode = identité défensive) ; **`const ZMarkdownCodec()`** (`z_markdown_codec.dart:51` — round-trip Markdown défensif). [Source: z_codec.dart ; z_delta_codec.dart ; z_markdown_codec.dart]
- **`ZMarkdownCodecScope`** (`z_markdown_codec_scope.dart:24`) : `const ZMarkdownCodecScope({ required ZCodec codec, required Widget child })` ; `of(context)`/`maybeOf(context)`. **STABILITÉ** : chaque champ résout son codec 1× au montage — changer `codec` à chaud ne re-seede pas les champs déjà montés (utiliser une `Key` pour forcer le re-montage au switch de codec). [Source: z_markdown_codec_scope.dart:24-63]

**`zcrud_geo`** (barrel + `package:zcrud_geo/adapters/osm.dart`) :
- **`ZGeoFieldWidget.builder({ ZMapAdapterFactory? adapterFactory, ... })`** → `ZFieldWidgetBuilder` enregistrable sous `'location'` et/ou `'geoArea'`. Valeur neutre `ZGeoPoint` (location) / `ZGeoShape` (geoArea). Le mode est déduit de `ctx.field.type.name` (`'geoArea'` vs `'location'`). [Source: z_geo_field_widget.dart:30-76]
- **`typedef ZMapAdapterFactory = ZMapAdapter Function()`** ; **`ZOsmMapAdapter`** (exporté par `package:zcrud_geo/adapters/osm.dart` → `z_osm_map_adapter.dart`) : `ZOsmMapAdapter.new` = fabrique OSM (flutter_map, SANS clé). Usage : `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))`. [Source: adapters/osm.dart:14-19 ; z_map_adapter.dart:30]

**`zcrud_intl`** (barrel `package:zcrud_intl/zcrud_intl.dart`) :
- **`ZPhoneFieldWidget.builder({ ZCountryCatalog? catalog, String? defaultIsoCode, ... })`** → `ZFieldWidgetBuilder` (`'phoneNumber'`). Valeur neutre `ZPhoneNumber` (E.164). [Source: z_phone_field_widget.dart:64-79]
- **`ZCountryFieldWidget.builder({ ZCountryCatalog? catalog, ... })`** → (`'country'`). Valeur = code ISO alpha-2 `String`. [Source: z_country_field_widget.dart:54-70]
- **`ZAddressFieldWidget.builder({ ZCountryCatalog? catalog, ... })`** → (`'address'`). Valeur neutre `ZPostalAddress`. [Source: z_address_field_widget.dart:52-70]
- **`ZCountryCatalog`** : constantes pays depuis un **asset JSON paresseux** ; sans `catalog:` explicite, les builders partagent `sharedDefaultCountryCatalog()` (asset lu 1×). **Vérifier** que l'asset du package est disponible côté app sans déclaration supplémentaire (assets bundlés par `zcrud_intl`). [Source: z_country_catalog.dart ; z_phone_field_widget.dart:70]

**`zcrud_export`** (barrel `package:zcrud_export/zcrud_export.dart`) :
- **`ZExporter`** (`z_exporter.dart:37`) : `const ZExporter()` ; `Uint8List toExcelBytes(ZListRenderRequest request, { String Function(String headerKey)? resolveHeader })` ; `Uint8List toPdfBytes(ZListRenderRequest request, { String Function(String headerKey)? resolveHeader })`. Backends Syncfusion xlsio/pdf confinés à `src/data/` (jamais réexportés). Entrées neutres (`ZListRenderRequest`), sorties `Uint8List`. [Source: z_exporter.dart:37-66]
- **`ZExportTable`** : `const ZExportTable({ required List<...> headers, required List<...> rows })` ; `ZExportTable.fromRequest(request, resolveHeader:)`. Généralement pas manipulé directement (passer par `ZExporter`). [Source: z_export_table.dart:25-37]

**`zcrud_firestore`** (barrel `package:zcrud_firestore/zcrud_firestore.dart`) :
- **`HiveZLocalStore<T extends ZEntity> extends ZLocalStore<T>`** (`hive_z_local_store.dart:64`) : ctor `HiveZLocalStore({ required Box<dynamic> box, required String kind, required T Function(Map<String,dynamic>) fromMap, required Map<String,dynamic> Function(T) toMap, bool ownsBox = false, ... })` (injection de `Box` — test) ; static `Future<HiveZLocalStore<T>> openBox<T>({ required String kind, required T Function(Map) fromMap, required Map Function(T) toMap, ... })` (prod ; ouvre via `Hive.openBox` — **exige** `Hive.init`/`Hive.initFlutter()` préalable). Aucun type Hive exposé (signatures `ZResult`/`Stream` nues). [Source: hive_z_local_store.dart:64-113]
- **`FirestoreZRemoteStore`** / **`FirebaseZRepositoryImpl`** : distant offline-first (injection d'une instance `FirebaseFirestore`). **NON initialisés dans la démo** (documentés). [Source: zcrud_firestore.dart ; firestore_z_remote_store.dart ; firebase_z_repository_impl.dart]

### Réutilisation EX-2 (données de démo)

`example/lib/demos/list_demo_data.dart` fournit `DemoRecord implements ZEntity`, `DemoStore` (soft-delete `is_deleted` hors-entité), `DemoRepository`, `demoSchema` (6 champs affichables), `toDemoRow`. **Réutiliser** pour l'export (AC6 : `demoSchema` + `ZListRow` → `ZListRenderRequest.fromSchema`) et l'offline (AC7 : `DemoRecord` ; ajouter `toMap`/`fromMap` de façon **additive** si absents — sans casser EX-2). NE PAS dupliquer le modèle inutilement. [Source: ex-2-list-demo.md#File List ; example/lib/demos/list_demo_data.dart]

### Point d'injection du registre (décision critique)

Le `_BindingSeamForwarder` (`binding_selector.dart:67-90`) re-propage `root.widgetRegistry` (ligne 83) sous le `ZcrudScope` d'un binding. **Conséquence** : le `widgetRegistry` DOIT être injecté au `ZcrudScope` **racine** (`app.dart`), sinon il est masqué sous get/riverpod/provider (`maybeOf` = plus proche) et les champs géo/intl retombent sur `ZUnsupportedFieldWidget` sur 3 des 4 bindings. Injecter à la racine = parité gratuite (AC8/AC10). **Aucune** modification de `binding_selector.dart`. [Source: binding_selector.dart:80-88 ; app.dart:62-80 ; z_field_widget.dart:437-438]

### Previous story intelligence (EX-1 done, EX-2 done)

- **Voie standalone confirmée** (EX-1/EX-2) : `path:` + `dependency_overrides` `path:` suffisent (aucun ajout au `workspace:` racine). Rejouer pour les 5 satellites. [Source: ex-2-list-demo.md#T1]
- **MAJEUR-1 (EX-1)** : au switch de binding, disposer les contrôleurs **dépendants AVANT** leurs dépendances (ex. `ZEditionSubmitController`/sélection avant `ZFormController`). [Source: edition_demo_screen.dart:62-84]
- **MEDIUM-1 (EX-1)** : les seams applicatifs (dont `widgetRegistry`) sont re-propagés par `_BindingSeamForwarder` — s'appuyer dessus, NE PAS le retoucher. [Source: binding_selector.dart:33-40,83]
- **EX-2** : `listRenderer` injecté au scope racine (même patron que `widgetRegistry` ici) ; `uses-material-design: true` déjà présent au pubspec app. Réutiliser `test/support/pump_helpers.dart` ; étendre `boundary_deps_test.dart`. [Source: ex-2-list-demo.md#T2/#File List ; example/pubspec.yaml:60-61]
- `reference_form.dart` (EX-1) n'utilise **aucun** type registre-routé (`location`/`geoArea`/`phoneNumber`(type)/`address`/`markdown`) — son `country` est un `select`. Injecter `widgetRegistry` à la racine **n'affecte donc pas** l'écran d'édition EX-1 (vérifié sur disque). [Source: example/lib/demos/reference_form.dart]

### Frontière EX-3 (CLÔTURE de l'epic EX)

- **EX-3 (cette story)** = démos des features MVP restantes : **Markdown** (E6), **Geo/Intl/Export** (E11a), **Firestore-offline** (E5, via `HiveZLocalStore`). CLÔT l'epic EX (après quoi : `epic-ex-retrospective`).
- **HORS périmètre (v1.x)** : **Flashcards** (E9, `zcrud_flashcard`), **Cartes mentales** (E10, `zcrud_mindmap`) — restent INTERDITES par `boundary_deps_test.dart`. Le **merge LWW / `ZSyncOrchestrator`** (E5-3/E5-4) et le géo/intl/export **complet** (E11b) sont aussi v1.x. Aucune démo de ces features n'est ajoutée.

### Project Structure Notes

- Fichiers NOUVEAUX (tous sous `example/`) : `example/lib/demos/demo_registry.dart` (registre peuplé) ; `example/lib/demos/markdown_demo_screen.dart` ; `geo_demo_screen.dart` ; `intl_demo_screen.dart` ; `export_demo_screen.dart` ; `offline_demo_screen.dart` ; tests `example/test/*.dart` (markdown/geo/intl/export/offline + registre/parité).
- Fichiers MODIFIÉS (tous sous `example/`) : `example/pubspec.yaml` (+5 satellites) ; `example/lib/app.dart` (+ `widgetRegistry` racine) ; `example/lib/home_screen.dart` (activer 5 entrées) ; `example/lib/main.dart` (éventuel `Hive.initFlutter()` guardé) ; `example/lib/demos/list_demo_data.dart` (ajout additif `toMap`/`fromMap` sur `DemoRecord` si nécessaire) ; `example/test/boundary_deps_test.dart` (autoriser 5 satellites, interdire flashcard/mindmap).
- **AUCUN** fichier sous `packages/**` créé ou modifié (lecture seule pour comprendre l'API) — invariant NON-NÉGOCIABLE (REL-1 en parallèle touche `packages/`, fichiers disjoints).
- Naming : préfixe `Z` pour les types cœur/satellites consommés ; `*DemoScreen`/`demoWidgetRegistry` côté app (pas de préfixe `Z`) ; fichiers snake_case.

### Ambiguïtés détectées (à trancher en dev-story, documenter le choix)

1. **`resolution: workspace` des satellites + `path:`** : voie standalone attendue (comme EX-1/EX-2) ; fallback documenté si `pub` refuse. Prouver par `flutter pub get` réel.
2. **`flutter build web` avec `cloud_firestore`/`firebase_core` sans config Firebase** : le simple fait de dépendre du plugin ne doit PAS casser le build web (seul `Firebase.initializeApp()` exige la config, non appelé). **À PROUVER** par un `flutter build web` réel ; si le build casse, isoler la démo offline derrière `HiveZLocalStore` seul en évitant tout import de `FirestoreZRemoteStore`/`FirebaseZRepositoryImpl` au runtime (imports au niveau doc uniquement), voire retirer `zcrud_firestore` et documenter Hive/Firestore textuellement (repli extrême, à justifier).
3. **Markdown via registre vs direct** : **direct** recommandé (`ZMarkdownField` exige `ZFormController`, absent de `ZFieldWidgetContext`). Documenter.
4. **Init Hive en test widget** : `HiveZLocalStore.openBox` exige `Hive.init`/`initFlutter`. Options : (a) test injecte un `Box` via `Hive.init(Directory.systemTemp)` en `setUp` (Hive réel, hermétique) ; (b) l'écran est construit contre le port `ZLocalStore` et le test injecte un **fake in-memory `ZLocalStore`** (plus hermétique, ne prouve pas Hive réel) ; (c) test d'intégration Hive séparé. **Recommandé** : écran contre le port + injection ; test principal via (a) Hive temp dir pour prouver le CRUD offline réel, sinon (b) documenté.
5. **Export : partage/enregistrement des bytes** : `DemoFilePicker`/écriture fichier vs snackbar confirmant `bytes.length > 0`. Snackbar acceptable pour la démo (documenter) ; l'AC exige surtout des **bytes non vides** vérifiés.
6. **Regroupement accueil** : conserver « Geo / Intl / Export » comme entrées séparées ou hub. Documenter.
7. **Asset `ZCountryCatalog`** : vérifier que l'asset JSON de `zcrud_intl` est résolu côté app sans déclaration supplémentaire (bundlé par le package). Si un chargement d'asset échoue en test, documenter le contournement (catalog de test injecté).

### References

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml (section EX : ex-3-reste-features-demo)]
- [Source: _bmad-output/implementation-artifacts/stories/ex-1-scaffold-edition-demo.md ; ex-2-list-demo.md (scaffold, isolation, parité, registre/renderer au scope racine, MAJEUR-1/MEDIUM-1)]
- [Source: example/lib/app.dart ; home_screen.dart ; binding/binding_selector.dart:67-90 ; demos/edition_demo_screen.dart ; demos/list_demo_data.dart ; demos/reference_form.dart ; example/pubspec.yaml ; example/test/boundary_deps_test.dart]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart ; z_field_widget.dart:411-438 ; presentation/zcrud_scope.dart ; domain/edition/edition_field_type.dart ; domain/ports/z_local_store.dart ; presentation/list/z_list_render_request.dart]
- [Source: packages/zcrud_markdown/lib/zcrud_markdown.dart + src/presentation/z_markdown_field.dart + src/domain/z_codec.dart + src/data/z_delta_codec.dart / z_markdown_codec.dart + src/presentation/z_markdown_codec_scope.dart]
- [Source: packages/zcrud_geo/lib/zcrud_geo.dart + adapters/osm.dart + src/presentation/z_geo_field_widget.dart / z_map_adapter.dart ; packages/zcrud_geo/pubspec.yaml (flutter_map/latlong2, sans clé)]
- [Source: packages/zcrud_intl/lib/zcrud_intl.dart + src/presentation/z_{phone,country,address}_field_widget.dart + src/data/z_country_catalog.dart]
- [Source: packages/zcrud_export/lib/zcrud_export.dart + src/data/z_exporter.dart / z_export_table.dart]
- [Source: packages/zcrud_firestore/lib/zcrud_firestore.dart + src/data/hive_z_local_store.dart / firestore_z_remote_store.dart / firebase_z_repository_impl.dart ; packages/zcrud_firestore/pubspec.yaml (cloud_firestore/firebase_core/hive/hive_flutter)]
- [Source: architecture.md#AD-1/#AD-2/#AD-4/#AD-7/#AD-9/#AD-12/#AD-13/#AD-15 ; prd.md SM-5/FR (markdown/geo/intl/export/firestore) ; CLAUDE.md Key Don'ts]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story ; skill `bmad-dev-story` invoqué via le tool `Skill`, workflow résolu par `resolve_customization.py`).

### Debug Log References

- **DynamicEdition ne rend rien sans `visibleFields` seedé** : `DynamicEdition` ne construit QUE `controller.visibleFields.value` ; sans conditions ni `initialValues`, cet ensemble est vide → 0 champ (ni registre, ni `ZUnsupportedFieldWidget`). Correctif : les controllers géo/intl sont seedés avec `initialValues: {nom: null}` (le ctor `ZFormController` en dérive `visibleFields`). [z_form_controller.dart:51 ; dynamic_edition.dart:300-305]
- **Boucle de rebuild offline** : `StreamBuilder(stream: store.watchAll())` recréait un abonnement à chaque rebuild → `onListen` re-seed → rebuild infini (`pumpAndSettle` timeout). Correctif : `watchAll()` appelé UNE fois à l'ouverture du store, flux mis en cache dans le `State`.
- **Hive sous FakeAsync** : l'IO fichier de `Hive.openBox` ne se résout pas sous le FakeAsync des `testWidgets` (spinner perpétuel). Ambiguïté #4 tranchée : le test **widget** injecte un `ZLocalStore` in-memory hermétique (option b) ; un test **`test()`** séparé exerce le vrai `HiveZLocalStore` en temp-dir (option a) → CRUD offline réel prouvé.
- **`flutter build web`** (ambiguïté #2) : **RC=0** — dépendre de `cloud_firestore`/`firebase_core` ne casse PAS le build web (seul `Firebase.initializeApp()`, non appelé, exigerait la config). Repli non nécessaire.
- **app_smoke_test (EX-1)** mis à jour : l'assertion « chips à venir » est remplacée par « aucune entrée à venir » (AC9 : EX clôturé).

### Completion Notes List

- **12/12 AC satisfaits.** 5 écrans de démo (Markdown/Geo/Intl/Export/Offline) + registre géo/intl injecté au `ZcrudScope` RACINE, re-propagé sous les 4 bindings par `_BindingSeamForwarder` (NON modifié). Accueil : 5 entrées activées, plus aucune « à venir ».
- **AUCUN fichier sous `packages/` touché** (lecture seule de l'API ; les modifs `packages/` visibles en `git status` sont celles de REL-1 en parallèle : métadonnées de publication + barrel export — disjointes d'EX-3).
- **Décisions/ambiguïtés** : #2 build web OK ; #3 Markdown monté DIRECTEMENT (contrôleur isolé, pas via registre) ; #4 offline = Hive réel (test unité) + fake in-memory (test widget) ; #5 export confirmé par snackbar + zone résultat (bytes non vides / `%PDF-`) ; #6 entrées d'accueil séparées par feature ; #1/#7 voie standalone `path:`+overrides OK, asset `ZCountryCatalog` résolu sans déclaration app.
- **Vérif verte rejouée sur disque** : `flutter pub get` RC=0 (lock app propre, root lock INTACT) ; `flutter analyze` **0 issue** ; `flutter test` **46 tests, RC=0** ; `flutter build web` RC=0 ; `melos list` = **14**.
- **SM-5/AD-1** : Quill/flutter_map/Syncfusion/Firebase/Hive tirés EXCLUSIVEMENT via les satellites (par l'APP), jamais via `zcrud_core` ; adaptateur OSM via l'entrée dédiée `package:zcrud_geo/adapters/osm.dart` ; aucun type SDK dans une valeur de tranche. Aucun secret (OSM sans clé, aucune config Firebase, aucune licence Syncfusion).
- **Frontière** : EX-3 CLÔT l'epic EX. `zcrud_flashcard`/`zcrud_mindmap` (E9/E10) restent INTERDITS (`boundary_deps_test.dart` mis à jour).
- **Note restore UI** : l'écran offline expose create/list/modifier/soft-delete/clear ; la voie `restore()` du port est prouvée par le test unité Hive réel (create→softDelete→restore→clear).

### Remédiation code-review EX-3 (passe post-review — 2026-07-10)

Findings de `code-review-ex-3.md` traités (périmètre STRICT `example/`, `packages/` NON touché, root lock intact) :

- **MEDIUM-1 (restore non exposé UI) — CORRIGÉ.** `OfflineDemoScreen._softDelete` déclenche désormais un **SnackBar « Annuler »** (clé `offlineUndo`) rappelant `store.restore(id)` : le CRUD offline complet **create / softDelete / restore** est exerçable **À LA MAIN**. Voie choisie = undo immédiat (idiome Gmail) car le port `ZLocalStore` **n'expose PAS** les soft-deleted (`watchAll`/`getAll` les excluent) — une corbeille exigerait de dupliquer l'état `is_deleted` dans l'écran. `ScaffoldMessenger` capté AVANT l'`await` (pas de `BuildContext` au travers d'un gap async) ; garde `mounted`. **Nouveau test widget** `AC7 — soft-delete puis restaurer via « Annuler »` : tap supprimer → SnackBar → tap Annuler → l'enregistrement **réapparaît** (ListTile re-trouvé, `offlineEmpty` absent). AD-9 respecté (soft-delete = drapeau restaurable), AD-13 (`TextAlign.start`).
- **LOW-2 (interaction Markdown simulée) — DOCUMENTÉ.** Bloc de commentaire ajouté en tête de `markdown_demo_test.dart` : la couverture PROFONDE de l'éditeur (frappe Quill réelle avec focus, embeds LaTeX/tableau toolbar) est portée par les ~155 tests du **package `zcrud_markdown` (E6)** ; le test de démo couvre l'**intégration** (montage `ZMarkdownField` contrôleur isolé AD-7 + valeur persistée `persistedValueOf` + bascule codec). L'écran n'ajoute aucune logique d'édition → frappe Quill non re-jouée (redondante avec E6).
- **LOW-3 (parité geo sous 1 binding) — CORRIGÉ.** Ajout d'une boucle de parité `AC10 — Geo : parité de rendu sous {scope, riverpod}` dans `geo_demo_test.dart` (miroir de la boucle Intl de `demo_registry_test.dart`) : `GeoDemoScreen(initialBinding:)` monté sous ≥ 2 wraps → 2 `ZGeoFieldWidget`, 0 `ZUnsupportedFieldWidget`. La parité géo sous binding est désormais OBSERVÉE (plus seulement sur Intl).
- **Vérif verte REJOUÉE sur disque (ciblée `example/`)** : `flutter analyze` **0 issue, RC=0** ; `flutter test` **49 tests, RC=0** (dont le nouveau test restore UI + 2 tests parité geo) ; `flutter build web` **RC=0** (`✓ Built build/web`). `git status -- packages/` **VIDE** ; root `pubspec.lock` **intact**. `Status` NON modifié (reste `review`, transition pilotée par l'orchestrateur).

### File List

**Créés (tous sous `example/`) :**
- `example/lib/demos/demo_registry.dart`
- `example/lib/demos/markdown_demo_screen.dart`
- `example/lib/demos/geo_demo_screen.dart`
- `example/lib/demos/intl_demo_screen.dart`
- `example/lib/demos/export_demo_screen.dart`
- `example/lib/demos/offline_demo_screen.dart`
- `example/test/markdown_demo_test.dart`
- `example/test/geo_demo_test.dart`
- `example/test/intl_demo_test.dart`
- `example/test/export_demo_test.dart`
- `example/test/offline_demo_test.dart`
- `example/test/demo_registry_test.dart`
- `example/test/home_nav_test.dart`

**Modifiés (tous sous `example/`) :**
- `example/pubspec.yaml` (+5 satellites en `dependencies` + `dependency_overrides` `path:` ; `hive`/`hive_flutter` en deps directes)
- `example/lib/app.dart` (`widgetRegistry` injecté au `ZcrudScope` racine)
- `example/lib/main.dart` (`Hive.initFlutter()` avant `runApp`)
- `example/lib/home_screen.dart` (5 entrées activées, plus aucune « à venir »)
- `example/lib/demos/list_demo_data.dart` (ajout ADDITIF `DemoRecord.toMap`/`fromMap`)
- `example/test/support/pump_helpers.dart` (helper `wrapForTestWithRegistry`)
- `example/test/boundary_deps_test.dart` (autorise les 5 satellites ; interdit flashcard/mindmap)
- `example/test/app_smoke_test.dart` (assertion « à venir » → « aucune à venir », AC9)

**Modifiés lors de la remédiation code-review (2026-07-10, `example/` uniquement) :**
- `example/lib/demos/offline_demo_screen.dart` (MEDIUM-1 : voie restore UI via SnackBar « Annuler » ; `import 'dart:async'`)
- `example/test/offline_demo_test.dart` (MEDIUM-1 : nouveau test widget restore via UI)
- `example/test/markdown_demo_test.dart` (LOW-2 : documentation du périmètre de couverture E6)
- `example/test/geo_demo_test.dart` (LOW-3 : boucle de parité geo sous ≥ 2 bindings)

**AUCUN fichier sous `packages/` créé ou modifié par EX-3 (remédiation incluse).**

### Change Log

| Date | Version | Description | Auteur |
|------|---------|-------------|--------|
| 2026-07-10 | 0.1 | Implémentation EX-3 : démos Markdown/Geo/Intl/Export/Offline, registre racine, accueil complet, 13 fichiers créés + 8 modifiés (example/ uniquement). 46 tests verts, analyze 0 issue, build web OK. | dev-story (Opus 4.8) |
| 2026-07-10 | 0.2 | Remédiation code-review EX-3 : MEDIUM-1 corrigé (restore exposé UI via SnackBar « Annuler » + test widget), LOW-2 documenté (couverture éditeur E6), LOW-3 corrigé (parité geo sous 2 bindings). `example/` uniquement. 49 tests verts, analyze 0 issue, build web OK, `packages/` non touché. | dev-story remédiation (Opus 4.8) |
