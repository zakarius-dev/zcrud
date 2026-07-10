---
baseline_commit: 868438a73868c75a837e71f8cb443dd75ed24fa8
---

# Story EX.1 : Scaffold de l'application exemple Flutter + démo d'édition (E3)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur/évaluateur de zcrud (et futur intégrateur DODLP/lex_douane)**,
je veux **une application Flutter exemple exécutable (`example/`) qui démarre, présente un accueil des démos par domaine, et livre une première démo d'ÉDITION exerçant le moteur `DynamicEdition` (familles de champs, sections, conditionnels, grille, stepper, soumission/dirty), avec une preuve VISUELLE de la granularité de rebuild (SM-1) et de la parité multi-binding**,
afin de **disposer de la seule surface exécutable qui valide en conditions réelles les invariants du cœur (SM-1, AD-2/AD-15) et sert de harnais croissant (liste E4, firestore E5, markdown E6, geo/intl/export E11a viendront dans EX-2/EX-3), sans jamais rompre l'invariant « 14 packages produit » ni l'isolation des dépendances (SM-5)**.

**C'est la PREMIÈRE story de l'epic EX (application exemple).** Elle crée le scaffold et la démo d'édition uniquement. Les démos liste/firestore/markdown/geo-intl-export sont **hors périmètre** (frontière EX-2/EX-3, cf. §Frontière).

## Contexte

- **Origine** : consigne user 2026-07-10 + Readiness Report §#5 (« créer la story example-app rattachée E1/E2 comme harnais de validation SM-1, SM-5, E2-9 parité multi-binding »). Le Structural Seed de l'architecture liste littéralement `example/` (« app de démonstration + banc d'intégration ») mais **aucune story produit** ne le crée — ce trou est comblé ici. [Source: architecture.md#Structural Seed ; implementation-readiness-report-2026-07-09.md#5]
- **État réel du dépôt** (vérifié sur disque) : E1/E2/E3 **done**, E4 **in-progress** (E4-5 `ready-for-dev`). Le moteur d'édition E3 est **entièrement livré** dans `zcrud_core` : `DynamicEdition`, `ZFormController`, familles E3-3a/3b/3c, sections/conditionnels/grille E3-4, `ZStepperEdition` E3-5, soumission/dirty E3-6 (`ZEditionSubmitController`, `ZDiscardGuard`). Les 3 bindings (`zcrud_get`, `zcrud_riverpod`, `zcrud_provider`) sont **done** (E2-9). L'app exemple **consomme** ces livrables ; elle n'en modifie AUCUN.
- **Rôle de harnais** : `example/` est la première (et à ce stade seule) app qui monte réellement `DynamicEdition` end-to-end. Elle matérialise SM-1 (rebuild granulaire observable à l'œil et sous test) et la parité AD-15 (même formulaire, 4 mécanismes d'injection).

## Décision structurante — emplacement de l'app exemple (préserve « 14 packages produit »)

**DÉCISION (orchestrateur, à appliquer par dev-story) : app Flutter STANDALONE ISOLÉE sous `example/`, name `zcrud_example`, `publish_to: none`, avec ses PROPRES `pubspec.lock`, dépendances `path:` vers les packages zcrud consommés — CALQUÉE sur `tool/compat_check` (package isolé, hors workspace, lock propre).**

Justification (chaque contrainte du prompt honorée) :

- **Invariant « melos list = 14 » PRÉSERVÉ automatiquement** : l'app n'est **ni** sous le glob melos `packages/**`, **ni** membre du bloc `workspace:` du root `pubspec.yaml`. Aucun `melos.ignore` supplémentaire n'est même requis (contrairement à `binding_conformance` qui, lui, EST membre du workspace et doit donc être ignoré). `dart run melos list` doit rester **14**. [Source: pubspec.yaml (bloc `workspace:` + `melos.ignore`) ; tool/compat_check/pubspec.yaml]
- **graph_proof.py inchangé (AD-1, CORE OUT=0 / acyclique)** : `scripts/dev/graph_proof.py` **n'itère que `packages/*`** — une app sous `example/` en est invisible quel que soit son nom (le préfixe `zcrud_` n'entraîne AUCUNE arête car le scan ne descend pas dans `example/`). [Source: tool/compat_check/pubspec.yaml (commentaire « HORS du scope de graph_proof.py qui n'itère que packages/* »)]
- **Isolation des dépendances lourdes (raison d'être long terme de l'epic EX)** : l'app CROÎTRA vers `zcrud_list` (Syncfusion, EX-2), `zcrud_firestore` (Firebase, EX-3), `zcrud_geo` (Google Maps, EX-3). Ces poids **ne doivent JAMAIS polluer le lock partagé racine** des 14 membres (exactement la raison pour laquelle `tool/compat_check` est isolé et **hors** `workspace:` — « sinon il tire Flutter/deps lourdes dans le lock partagé — INTERDIT, AD-15 »). Un lock propre à l'app garantit cette isolation pour toute la durée de l'epic EX. [Source: tool/compat_check/pubspec.yaml#Isolation]
- **SM-5 NON cassé** : SM-5 concerne le graphe de dépendances de **`zcrud_core`** (importer un satellite n'ajoute ni Firebase, ni Syncfusion, ni Maps). L'app exemple, elle, a le DROIT de tout consommer — c'est un CONSOMMATEUR, pas un package produit. `zcrud_core` reste strictement Syncfusion/Firebase/Maps-free ; l'app n'y ajoute rien. [Source: prd.md SM-5 ; architecture.md AD-1/AD-15]
- **`publish_to: none`** : l'app n'est jamais publiée sur pub.dev (comme `tool/compat_check`, `binding_conformance`, le root workspace).

**Risque connu à valider en dev-story (ambiguïté)** : une dépendance `path:` vers un package qui déclare `resolution: workspace` (cas de `zcrud_core`, `zcrud_get`, …) PEUT être refusée par `pub` hors contexte workspace (« package is a workspace member »). **Protocole dev-story** : tenter d'abord la voie standalone/`path:` + `flutter pub get` réel. Si pub refuse, appliquer le **fallback documenté** : ajouter `example` au bloc `workspace:` du root `pubspec.yaml` **ET** à `melos.ignore` (pubspec.yaml + `melos.yaml`, sinon le gate M-1 `gate:melos` échoue), en nommant l'app **SANS préfixe `zcrud_`** (ex. `example_gallery`) pour rester invisible à graph_proof — calqué sur `binding_conformance`. **Dans les deux voies, l'invariant `melos list = 14` reste tenu et testé (AC2).** Documenter la voie retenue et la preuve `pub get` dans les notes de dev.

## Acceptance Criteria

1. **AC1 — L'app exemple existe, compile et démarre.** Un package application Flutter existe sous `example/` (`name: zcrud_example`, `publish_to: none`, `environment.sdk: ^3.12.2`, `flutter` SDK). `flutter analyze` RC=0 sur l'app ; l'app **compile** (au minimum `flutter test` de smoke RC=0 ; `flutter build <target>` compile sans erreur — la CI/dev peut cibler la plateforme disponible). L'`main()` monte un `MaterialApp`. Given un checkout propre → When `flutter pub get && flutter analyze && flutter test` dans `example/` → Then RC=0.

2. **AC2 — Invariant « 14 packages PRODUIT » préservé.** `dart run melos list` retourne **exactement 14** packages (les mêmes qu'avant la story) ; l'app exemple n'y figure PAS. `python3 scripts/dev/graph_proof.py` reste **vert** (CORE OUT=0, acyclique inchangé). `dart run scripts/ci/gate_melos_divergence.dart` (M-1) reste vert. Given l'app créée → When on rejoue melos list + graph_proof + gate:melos → Then 14 packages, graphe inchangé, M-1 vert.

3. **AC3 — Accueil (navigation par domaine) + thème injecté + l10n + RTL.** L'app présente un écran d'accueil qui **liste les démos par domaine** : « Édition » (active), et les domaines à venir « Liste », « Firestore », « Markdown », « Geo/Intl/Export » rendus **désactivés/étiquetés « à venir »** (frontière EX-2/EX-3). Le thème est injecté via `ZcrudScope(theme: ...)`/`ZcrudTheme` (aucun style codé en dur — repli `Theme.of`), la localisation via `ZcrudLocalizationsDelegate` (l10n zcrud fr/en câblée dans `MaterialApp.localizationsDelegates`/`supportedLocales`), et un **toggle RTL** (bascule de `Locale`/`Directionality` ou `textDirection`) est présent et fonctionnel (aucune régression : usage directionnel — `EdgeInsetsDirectional`, `TextAlign.start/end` — AD-13). Given l'app démarrée → When on lit l'accueil et on active le toggle RTL → Then la liste des domaines s'affiche, le thème `ZcrudTheme` s'applique, la direction bascule LTR↔RTL sans exception.

4. **AC4 — Écran démo ÉDITION : `DynamicEdition` exerçant les familles de champs.** Un écran « Démo Édition » monte un `DynamicEdition` piloté par un `ZFormController` **stable** (créé en `initState`, `dispose` en fin de vie) sur un **formulaire de référence** exerçant les familles E3 : `text`/`multiline`, `number`/`integer`, `dateTime`, `boolean`, `select`/`radio`, `relation`, `tags`/`rowChips`, `rating`, `slider`, `color`, `signature`, `file`/`image`/`document` (via un `ZFilePicker` de démo injecté dans le scope), et une **sous-liste inline** `subItems` (mini-CRUD E3-3b-2). Chaque champ a un `ValueKey(field.name)` (garanti par `DynamicEdition`). Given l'écran monté → When on inspecte l'arbre → Then chaque famille listée est rendue par son widget dédié (aucun `ZUnsupportedFieldWidget` pour les types couverts par le cœur), le controller est unique et stable.

5. **AC5 — Sections repliables + conditionnels + grille responsive + stepper + soumission/dirty.** La démo édition exerce, sur le MÊME `ZFormController` : (a) au moins une **section repliable** (`ZEditionSection`) ; (b) au moins un **champ conditionnel** (`displayCondition`/`ZCondition`) dont l'apparition/disparition suit un champ de garde ; (c) la **grille responsive** (`layout:` avec `ZResponsiveSpan` par breakpoint) ; (d) une variante **stepper** (`ZStepperEdition` partitionnant le même controller en étapes, validation par étape) accessible depuis la démo ; (e) une **soumission** via `ZEditionSubmitController` (hook `onSubmit` renvoyant `Either<ZFailure,T>` — succès/échec applicatif rendus), un bouton `ZSubmitButton` scellé sur l'état, une **bannière dirty** n'écoutant que `controller.isDirty`, et un `ZDiscardGuard` (seam `onConfirmDiscard` fourni par l'app = dialogue). Given la démo → When on replie une section / bascule le champ de garde / passe une étape du stepper / soumet un formulaire invalide puis valide → Then chaque comportement fonctionne (section pliée, champ conditionnel masqué/révélé, étape validée, soumission bloquée si invalide puis `onSubmit` appelé une fois si valide, bannière dirty réactive).

6. **AC6 — SM-1 démontré VISUELLEMENT et sous test.** L'écran d'édition affiche un **indicateur de rebuild par champ** (compteur de builds par champ, ou surbrillance éphémère au rebuild) rendant la granularité observable à l'œil. Un **test widget** prouve qu'en tapant ≥ 100 caractères dans un champ texte, (i) **seul** le champ courant se reconstruit (le compteur des voisins n'augmente pas), (ii) **aucune perte de focus** ni de position du curseur, (iii) aucun `Form`/`FormBuilder` global (`find.byType(Form) findsNothing` si applicable au cœur). Given le champ A focalisé → When on tape 100 caractères → Then compteur(A) augmente, compteur(B…) inchangé, focus conservé. [Réf. oracle : `binding_conformance` — mais l'app teste sa PROPRE surface, pas via ce harnais.]

7. **AC7 — Parité multi-binding démontrée (AD-15).** Un **sélecteur** (segmented control/dropdown) permet de rendre le **même** formulaire de référence sous : (i) `ZcrudScope` seul (défaut zéro-dépendance), (ii) `zcrud_get` (`ZcrudGetScope`), (iii) `zcrud_riverpod` (`ZcrudRiverpodScope`), (iv) `zcrud_provider` (`ZcrudProviderScope`). Le comportement (granularité SM-1 incluse) est **identique** dans les quatre : le manager ne vit que dans le `wrap` d'injection, jamais dans la config de champs. Given le sélecteur → When on choisit chaque binding et on tape dans un champ → Then le formulaire se comporte à l'identique (mêmes familles rendues, même rebuild granulaire) sous les 4. Un test widget monte le formulaire sous **au moins 2** wraps (défaut + un binding) et assert la parité de comportement observable.

8. **AC8 — `publish_to: none` et non-régression des gates transverses.** Le `pubspec.yaml` de l'app porte `publish_to: none` (jamais publiée sur pub.dev). Les gates transverses restent verts après ajout de l'app : `gate:reflectable` (aucun `reflectable` introduit hors chemin allowlisté), `gate:secrets` (aucun secret committé — pas de clé Google Maps/endpoint dans l'app), `gate:codegen` (aucun modèle annoté sans `.g.dart`). Given l'app ajoutée → When on rejoue `melos run verify` (ou les gates individuels disponibles) → Then verts. Note : `gate:compat`/`flutter` peuvent exiger la toolchain Flutter (documenter si indisponible).

9. **AC9 — SM-5 non cassé (le cœur reste isolé).** L'app peut dépendre de bindings et (dès EX-2) de `zcrud_list`/Syncfusion, MAIS `zcrud_core` **reste** sans Syncfusion/Firebase/Maps (aucune modification de `zcrud_core` par cette story). Le lock propre de l'app **n'altère pas** le `pubspec.lock` racine partagé des 14 membres. Given la story terminée → When on inspecte `git diff` sur `packages/zcrud_core` et le lock racine → Then `zcrud_core` inchangé, lock racine non pollué par des deps d'app.

10. **AC10 — Frontière EX-1/EX-2/EX-3 respectée.** L'app ne contient **aucune** démo Liste (`DynamicList`), Firestore/offline, Markdown, Geo/Intl/Export fonctionnelle : ces entrées d'accueil sont présentes mais **désactivées/« à venir »** (renvoyées à EX-2/EX-3). Aucune dépendance à `zcrud_list`, `zcrud_firestore`, `zcrud_markdown`, `zcrud_geo`, `zcrud_intl`, `zcrud_export` n'est ajoutée par EX-1. Given le `pubspec.yaml` de l'app → When on liste ses dépendances → Then seulement `zcrud_core` + les 3 bindings (+ deps Flutter standard), aucun package de démo E4/E5/E6/E11a.

## Tasks / Subtasks

- [ ] **T1 — Scaffold du package application `example/` (AC1, AC2, AC8, AC9).**
  - [ ] Créer `example/pubspec.yaml` : `name: zcrud_example`, `publish_to: none`, `environment.sdk: ^3.12.2`, `flutter` SDK ; deps `path:` vers `zcrud_core`, `zcrud_get`, `zcrud_riverpod`, `zcrud_provider` (AC7) ; **PAS** de `resolution: workspace` (app isolée) ; dev_deps `flutter_test`, `flutter_lints`/`lints`.
  - [ ] Tenter `flutter pub get` réel. **Si** pub refuse le `path:` vers un membre `resolution: workspace` → appliquer le fallback (workspace member + `melos.ignore` dans pubspec.yaml ET melos.yaml, nom sans préfixe `zcrud_`), documenter la voie retenue.
  - [ ] Vérifier `dart run melos list` = **14** et `graph_proof.py` vert (AC2).
  - [ ] `example/lib/main.dart` : `main()` → `runApp(MaterialApp)`.
  - [ ] `analysis_options.yaml` de l'app (hérite de la baseline ou `flutter_lints`).
- [ ] **T2 — Coquille `MaterialApp` : thème, l10n, RTL, accueil (AC3).**
  - [ ] Envelopper l'app dans un `ZcrudScope` racine (thème `ZcrudTheme` de démo, `ZcrudLabels` éventuels, `ZFilePicker` de démo injecté pour AC4).
  - [ ] Câbler `localizationsDelegates: [ZcrudLocalizationsDelegate(), ...GlobalMaterialLocalizations...]`, `supportedLocales: ZcrudLocalizationsDelegate.supportedLocales`.
  - [ ] Écran d'accueil `HomeScreen` : liste des domaines (Édition active ; Liste/Firestore/Markdown/Geo « à venir » désactivés — AC10).
  - [ ] Toggle RTL (bascule `Locale`/`textDirection`), toggle thème clair/sombre optionnel. Usage **directionnel** partout (AD-13).
- [ ] **T3 — Écran démo Édition : formulaire de référence (AC4, AC5).**
  - [ ] Construire la liste `List<ZFieldSpec>` de référence couvrant les familles (T3 doit produire ≥ 30 champs / ≥ 3 sections pour rester fidèle au formulaire de référence SM-1).
  - [ ] `ZFormController` stable (create `initState` / `dispose`), `DynamicEdition(controller, fields, sections, layout, ...)`.
  - [ ] Sections repliables (`ZEditionSection`), ≥ 1 champ conditionnel (`ZCondition`), `layout` responsive (`ZResponsiveSpan`).
  - [ ] Sous-liste inline `subItems` (mini-CRUD E3-3b-2) ; champ `signature` ; champ `file/image` via `ZFilePicker` de démo.
  - [ ] Variante `ZStepperEdition` (mêmes `fields`, `steps`) accessible depuis la démo.
  - [ ] Soumission : `ZEditionSubmitController(onSubmit: ... → Right(value))`, `ZSubmitButton`, bannière dirty (`ValueListenableBuilder(controller.isDirty)`), `ZDiscardGuard(onConfirmDiscard: dialogue)`.
- [ ] **T4 — Visualisation SM-1 (AC6).**
  - [ ] Indicateur de rebuild par champ (compteur incrémenté dans le `builder` du champ, ou flash). Ne PAS introduire de rebuild global pour l'afficher (chaque compteur écoute sa propre tranche).
  - [ ] Panneau récapitulatif optionnel (n'écoute que des `ValueListenable` dédiés — jamais le `notifyListeners` global).
- [ ] **T5 — Sélecteur de parité multi-binding (AC7).**
  - [ ] Widget `BindingSelector` (enum {scope, get, riverpod, provider}).
  - [ ] Fonction `wrapWithBinding(binding, child)` : `ZcrudScope` / `ZcrudGetScope` / `ZcrudRiverpodScope` / `ZcrudProviderScope`, la config de champs restant IDENTIQUE (le manager n'est que dans le wrap).
  - [ ] Reconstruire proprement le sous-arbre au changement de binding (nouveau controller par wrap, dispose de l'ancien).
- [ ] **T6 — Tests (AC1, AC4, AC6, AC7, AC10).**
  - [ ] Smoke test : `pumpWidget(app)` démarre sans exception ; l'accueil s'affiche ; navigation vers la démo Édition monte l'écran.
  - [ ] Test familles : l'écran Édition rend les widgets de familles attendus (aucun `ZUnsupportedFieldWidget` sur les types couverts).
  - [ ] Test SM-1 : taper 100 caractères dans un champ → compteur voisin inchangé, focus conservé (`find.byType(Form) findsNothing` si pertinent).
  - [ ] Test parité : monter le formulaire sous ≥ 2 wraps (défaut + 1 binding), asserter la parité de comportement observable.
  - [ ] Test frontière : le `pubspec.yaml` de l'app ne dépend PAS de `zcrud_list`/`_firestore`/`_markdown`/`_geo`/`_intl`/`_export`.
- [ ] **T7 — Vérif verte + gates (AC1, AC2, AC8, AC9).**
  - [ ] `flutter analyze` (app) RC=0 ; `flutter test` (app) RC=0.
  - [ ] `melos run generate` (no-op propre attendu — l'app n'a pas de modèle annoté en EX-1), `melos run analyze`, `melos run test` restent verts (les 14 packages).
  - [ ] `melos list` = 14 ; `graph_proof.py` vert ; `gate:melos`/`gate:reflectable`/`gate:secrets`/`gate:codegen` verts.
  - [ ] Confirmer `git diff` : `packages/zcrud_core` **inchangé** ; lock racine non pollué (AC9).

## Dev Notes

### Contraintes d'architecture applicables (rappel AD)

- **AD-2 / SM-1 (objectif produit n°1)** : la démo doit **prouver** la granularité, pas la contredire. Interdits dans l'app : `setState` à l'échelle du formulaire, reconstruction des `ZFieldSpec`/du controller dans `build()`, recréation de `TextEditingController`. Le controller vit dans le `State` (create/dispose). L'indicateur de rebuild SM-1 doit lui-même être granulaire (chaque compteur écoute sa tranche). [Source: architecture.md#AD-2 ; prd.md SM-1]
- **AD-15 (parité bindings)** : le code spécifique à un manager vit UNIQUEMENT dans le `wrap` (`ZcrudGetScope`/`ZcrudRiverpodScope`/`ZcrudProviderScope`) ; la config de champs et l'écran d'édition sont manager-agnostiques. Un même controller/formulaire fonctionne à l'identique sous les 4. [Source: architecture.md#AD-15]
- **AD-13 (a11y/RTL)** : variantes **directionnelles** obligatoires (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) ; `Semantics` explicites ; cibles ≥ 48 dp ; le toggle RTL de l'accueil exerce réellement la direction. [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts]
- **AD-6/FR-26 (thème injecté)** : aucun style/couleur codé en dur ; passer par `ZcrudScope(theme: ZcrudTheme(...))` avec repli `Theme.of`. [Source: z_theme.dart ; CLAUDE.md]
- **AD-1 / SM-5 / SM-C1** : ne PAS transformer l'app en package produit ; ne pas modifier `zcrud_core` ; ne pas polluer le lock racine ; l'invariant « 14 » est un garde-fou testé (AC2). [Source: pubspec.yaml ; tool/compat_check ; prd.md SM-5]
- **`ListView.builder`** (jamais `ListView(children:)`), `const` pour les widgets immuables. [Source: CLAUDE.md Key Don'ts]

### API publique consommée (signatures réelles, vérifiées sur disque)

Tout est exposé par le barrel `package:zcrud_core/zcrud_core.dart`. Signatures clés :

- `ZFormController({ Map<String,Object?>? initialValues, List<String>? visibleFields, ... })` — `ChangeNotifier`. Méthodes : `setValue(name, value)`, `valueOf(name)`, `values` (snapshot immuable), `fieldListenable(name) → ValueListenable<Object?>`, `isDirty → ValueListenable<bool>`, `visibleFields → ValueListenable<List<String>>`, `markPristine()`, `reset()`, `reseed(values)`, `dispose()`. [Source: z_form_controller.dart]
- `DynamicEdition({ required ZFormController controller, required List<ZFieldSpec> fields, List<ZEditionSection> sections = const [], Map<String, ZResponsiveSpan> layout = const {}, ... })` — `StatefulWidget`, `ListView.builder`, écoute STRUCTURELLE only, place stable (`KeyedSubtree`/`ValueKey(name)`). [Source: dynamic_edition.dart:96]
- `ZEditionSection({ required String title, required List<String> fields, ... })`. [Source: dynamic_edition.dart:66]
- `ZStepperEdition({ required ZFormController controller, required List<ZFieldSpec> fields, required List<ZEditionStep> steps, Map<String, ZResponsiveSpan> layout = const {}, ... })` ; `ZEditionStep({ required String title, required List<String> fields, List<ZEditionSection> sections = const [] })`. [Source: z_stepper_edition.dart:53,86]
- Soumission : `ZEditionSubmitController<T>({ required ZFormController controller, required List<ZFieldSpec> fields, required Future<Either<ZFailure,T>> Function(Map<String,Object?>) onSubmit })` ; `state → ValueListenable<ZSubmissionState>` ; `submit()` ; `ZSubmissionState.idle/inProgress/success/failure` ; `ZSubmitButton`, `ZDiscardGuard(onConfirmDiscard: Future<bool> Function()?)`. [Source: z_submission.dart:175 ; z_discard_guard.dart]
- Familles : `EditionFieldType` (enum ouvert) — valeurs disponibles E3 : `text, multiline, number, integer, float, boolean, dateTime, time, select, radio, checkbox, relation, rowChips, tags, subItems, dynamicItem, file, image, document, rating, slider, signature, color, password, hidden, widget, custom` (les `location/geoArea/phoneNumber/country/address/markdown/html/richText/icon` sont servis AILLEURS via registre — hors EX-1). [Source: edition_field_type.dart]
- Injection/scoping : `ZcrudScope({ required Widget child, ZDependencyResolver resolver, ZAcl acl, ZcrudLabels? labels, ZcrudTheme? theme, ZWidgetRegistry? widgetRegistry, ZFilePicker? filePicker, CloudStorageRepository? cloudStorage, ZListRenderer? listRenderer })`. [Source: zcrud_scope.dart:46]
- Bindings :
  - `ZcrudGetScope({ required Widget child, GetIt? locator, ZFormController Function()? createController, ZAcl acl, bool registerController, bool registerInGetX })` (package `zcrud_get`, `get`/`get_it`). [Source: zcrud_get_scope.dart:48]
  - `ZcrudRiverpodScope({ required Widget child, List<Override> overrides, Map<Type, ProviderListenable<Object?>> seams, ZAcl acl })` (package `zcrud_riverpod`, `flutter_riverpod`). [Source: zcrud_riverpod_scope.dart:38]
  - `ZcrudProviderScope({ required Widget child, ZFormController Function()? createController, List<SingleChildWidget> providers, ZAcl acl })` (package `zcrud_provider`, `provider`). [Source: zcrud_provider_scope.dart:36]
- l10n/thème : `ZcrudLocalizationsDelegate()` + `ZcrudLocalizationsDelegate.supportedLocales` (fr/en) ; `ZcrudTheme.of(context)` (repli `Theme.of`) ; `label(context, key)`. [Source: z_localizations.dart:181 ; z_theme.dart:89]
- Seam fichier : `ZFilePicker` (interface) — l'app fournit une **impl de démo** (stub renvoyant un `AppFile` factice, OU `image_picker`/`file_picker` si dev-story choisit d'ajouter la dép ; en EX-1 un stub suffit pour AC4). [Source: z_file_picker.dart ; zcrud_scope.dart#filePicker]

### Source tree — fichiers à CRÉER (aucun fichier existant modifié hors T1-fallback)

```
example/
  pubspec.yaml                       # NEW (name: zcrud_example, publish_to: none, path deps)
  analysis_options.yaml              # NEW
  lib/
    main.dart                        # NEW (runApp + ZcrudScope racine + MaterialApp + l10n/RTL)
    app.dart                         # NEW (MaterialApp, thème, delegates, routes)
    home_screen.dart                 # NEW (liste des démos par domaine ; « à venir » désactivés)
    demos/
      edition_demo_screen.dart       # NEW (DynamicEdition + sections/conditionnels/grille)
      edition_stepper_demo.dart      # NEW (ZStepperEdition)
      reference_form.dart            # NEW (List<ZFieldSpec> de référence ≥30 champs/≥3 sections)
    binding/
      binding_selector.dart          # NEW (enum + wrapWithBinding)
    support/
      demo_file_picker.dart          # NEW (impl ZFilePicker de démo/stub)
      rebuild_indicator.dart         # NEW (compteur SM-1 granulaire)
  test/
    app_smoke_test.dart              # NEW
    edition_families_test.dart       # NEW
    sm1_granular_rebuild_test.dart   # NEW
    binding_parity_test.dart         # NEW
    boundary_deps_test.dart          # NEW (ou script) — pas de deps E4/E5/E6/E11a
```

Fichiers potentiellement modifiés SEULEMENT dans la voie fallback (T1) : `pubspec.yaml` (root, bloc `workspace:` + `melos.ignore`) et `melos.yaml` (`ignore:`), en miroir strict (gate M-1). **Aucun** fichier de `packages/**` n'est modifié.

### Testing standards

- Framework : `flutter_test` (widget tests) dans `example/test/`. `melos run test:flutter` route l'app si elle est ciblée ; sinon la vérif verte de l'app se rejoue via `flutter test` dans `example/` (l'app étant hors du glob melos, la rejouer explicitement).
- Le test SM-1 suit le pattern éprouvé du cœur/`binding_conformance` : `enterText` répété, comparaison de compteurs de build par champ, assertion de focus conservé. L'app teste sa PROPRE surface (pas via le harnais `binding_conformance`).
- Ne PAS committer de golden lourd ; smoke + assertions structurelles suffisent.

### Frontière EX-1 / EX-2 / EX-3 (périmètre)

- **EX-1 (cette story)** : scaffold + accueil + démo ÉDITION (E3) + SM-1 visuel + parité binding. Deps : `zcrud_core` + 3 bindings uniquement.
- **EX-2** : démo **Liste** (`DynamicList` + `zcrud_list`/Syncfusion via `ZcrudScope(listRenderer:)`), sous-listes/onglets E4-5. Ajoute Syncfusion au lock **propre** de l'app.
- **EX-3** : démos **Firestore/offline** (E5), **Markdown** (E6), **Geo/Intl/Export** (E11a). Ajoute Firebase/Maps/export au lock **propre** de l'app.
- Les entrées d'accueil de ces domaines existent dès EX-1 mais sont **désactivées/« à venir »** (AC10).

### Project Structure Notes

- L'app `example/` est **alignée** sur le Structural Seed (`example/` y figure explicitement) ; elle n'est PAS un des 14 packages produit (comme `tool/compat_check`/`tool/binding_conformance` ne le sont pas). [Source: architecture.md#Structural Seed]
- **Variance assumée** : l'app est **isolée** (hors `workspace:`, lock propre) — divergence VOULUE vs `binding_conformance` (membre du workspace), justifiée par les deps lourdes futures (EX-2/EX-3) qui ne doivent pas polluer le lock racine (§Décision structurante). Fallback documenté si `path:`→`resolution: workspace` refusé par pub.

### References

- [Source: architecture.md#Structural Seed — `example/` « app de démonstration + banc d'intégration »]
- [Source: architecture.md#AD-2, #AD-6, #AD-13, #AD-15 — invariants réactivité/thème/a11y/bindings]
- [Source: implementation-readiness-report-2026-07-09.md#5 — créer la story example-app (harnais SM-1/SM-5/parité E2-9)]
- [Source: prd.md#SM-1 (formulaire ≥30 champs/≥3 sections, 100 caractères, zéro rebuild global), #SM-5 (isolation deps), #SM-C1]
- [Source: pubspec.yaml (bloc `workspace:` 14 membres + `melos.ignore`), melos.yaml (`ignore:`), gate M-1 `scripts/ci/gate_melos_divergence.dart`]
- [Source: tool/compat_check/pubspec.yaml — patron d'isolation (hors workspace, lock propre, hors graph_proof) ; tool/binding_conformance/pubspec.yaml — patron « membre + melos.ignore »]
- [Source: packages/zcrud_core/lib/zcrud_core.dart — barrel ; dynamic_edition.dart, z_form_controller.dart, z_stepper_edition.dart, z_submission.dart, z_discard_guard.dart, zcrud_scope.dart, z_theme.dart, z_localizations.dart, edition_field_type.dart, z_file_picker.dart]
- [Source: packages/zcrud_get/lib/…/zcrud_get_scope.dart, zcrud_riverpod/…/zcrud_riverpod_scope.dart, zcrud_provider/…/zcrud_provider_scope.dart — wraps de binding]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created (create-story EX-1).

### File List
