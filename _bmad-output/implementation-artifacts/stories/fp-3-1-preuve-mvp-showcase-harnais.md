<!-- Story enrichie par bmad-create-story (mode non-interactif). Épic 3 (Preuve),
     Story 3.1 du cycle form-parity. Source : epics-zcrud-form-parity-2026-07-18/epics.md.
     PÉRIMÈTRE D'ÉCRITURE : `example/` UNIQUEMENT (app de démonstration). AUCUN package
     `packages/*` n'est modifié — fp-3-1 les CONSOMME (AD-56 / AR-6). -->

# Story 3.1: Preuve MVP — showcase socle + états transverses + banc SM-1 + harnais axes MVP

Status: review

## Story

As a owner (Zakarius) et dev DODLP (Bilal),
I want une **showcase** des champs MVP livrés dans tous leurs états transverses, un **banc SM-1**
falsifiable, et un **harnais par axes** (ossature réutilisable) couvrant les axes MVP 1/5/6 avec des
formulaires répliqués sur données fictives,
so that j'audite la complétude MVP, je prouve la granularité de rebuild (objectif produit n°1) et
l'absence de régression sur les familles natives/câblées — **sans toucher un seul package** (l'app les
consomme via le vrai dispatcher).

## Contexte & frontières (à lire AVANT de coder)

### Ce que fp-3-1 EST (ossature + socle + preuve représentative)

fp-3-1 pose l'**infrastructure showcase réutilisable** dans `example/` :

1. **Une page showcase** montant un **socle représentatif** de familles de champs via le VRAI moteur
   (`DynamicEdition` → dispatcher `ZFieldWidget`), en consommant le composeur **`registerZcrudFormFields`**
   du binding (fp-2-2, `zcrud_get`) pour peupler le `ZWidgetRegistry` des kinds satellites (markdown /
   intl / geo). Chaque champ démontré est rendu par **son adaptateur réel** (présence ≠ association).
   Chaque champ est décliné selon les **états transverses** : read-only, désactivé, erreur de
   validation, valeur initiale, conditionnel (visibilité), **RTL**, **thème clair/sombre**.
2. **Un banc SM-1** : taper 100 caractères dans un champ ne reconstruit **que** ce champ (compteur de
   builds granulaire `RebuildLog`/`RebuildBadge` déjà présent, zéro perte de focus, aucun `Form`
   global).
3. **Un harnais par AXES** — un axe = une famille/capacité — dont l'**ossature** (structure de données
   décrivant un axe → 1..n formulaires de démo + métadonnées) est réutilisée par fp-3-2. fp-3-1 peuple
   les **axes MVP 1/5/6** (représentatifs, PAS exhaustifs).

### Ce que fp-3-1 N'EST PAS (frontière stricte vs fp-3-2)

- ❌ **PAS** la showcase exhaustive des 40+ `EditionFieldType` × toutes variantes → **fp-3-2**.
- ❌ **PAS** les 6 formulaires DODLP complets répliqués → **fp-3-2** (fp-3-1 en fournit ≥ 3 sur les axes
  MVP, sur l'ossature réutilisable).
- ❌ **PAS** les axes 2 (sélections riches modal), 3 (média/fichiers), 4 (HTML WYSIWYG) — non encore
  livrés par leurs satellites (Epic 4) → couverts par fp-3-2 après FP-4/FP-5.
- ❌ **PAS** les benchs SM-2/SM-3/SM-4 complets → fp-3-2. fp-3-1 tient **SM-1** (+ ébauche non-régression
  visuelle côte à côte, NFR-7).
- ❌ **AUCUNE** écriture dans `packages/*`. Si un besoin de champ/adaptateur manquant émerge → **le
  SIGNALER dans les Completion Notes**, ne pas l'implémenter ici (les gaps sont **étiquetés « ABSENT / à
  combler »**, jamais masqués).

## Acceptance Criteria

**AC1 — Page showcase : socle représentatif via le VRAI dispatcher** *(FR-40 socle)*
**Given** une nouvelle page « Showcase » ajoutée à `example/` (route depuis `home_screen.dart`)
**When** on l'ouvre
**Then** un **socle représentatif** de familles MVP livrées (Epics 1-2) est démontré — au minimum :
saisie (`text`/`multiline`/`number`/`integer`/`float`/`password`), `boolean`, `dateTime`/`time`,
`dateRange`, `select`/`radio`/`checkbox` natifs, `relation`, `rowChips`, `tags`, `subItems`
(+réordonnancement), `dynamicItem`, `rating`, `slider`, `signature`, `color` simple, et les kinds
satellites câblés `markdown`/`phoneNumber`/`country`/`address`/`location` — **chaque champ rendu par son
adaptateur réel** monté par `DynamicEdition`/`ZFieldWidget` (le test PROUVE `find.byType(ZXxxFieldWidget)`
ou le widget concret du satellite, PAS un mock, PAS le `ZUnsupportedFieldWidget`).

**AC2 — Gaps non livrés étiquetés « ABSENT / à combler » (jamais masqués)** *(FR-40 socle, SM-4)*
**Given** les capacités non encore livrées par leurs satellites (`select`/`radio`/`relation` **modal**
riche, média/fichier, HTML WYSIWYG, `color` multiple, `icon`, `pin`, `autocomplete`, `editableTable`,
variante `itemsAreTags`)
**When** la showcase les référence
**Then** chaque gap apparaît **explicitement étiqueté « ABSENT / à combler »** (entrée visible avec un
libellé/statut, jamais retirée ni silencieusement masquée) ; un test vérifie la présence de ces
étiquettes ; les gaps ne sont **jamais** rendus via un faux widget qui simulerait la parité.

**AC3 — États transverses par champ** *(FR-40 socle, AD-13, NFR-7)*
**Given** un champ du socle
**When** la showcase le décline
**Then** les états transverses sont démontrables et testés : **read-only** (`spec.copyWith(readOnly:true)`
ou `DynamicEdition(readOnly:true)`), **désactivé**, **erreur de validation** (validateur en échec, message
thémé), **valeur initiale** (pré-remplie via `initialValues`), **conditionnel** (un champ garde masque/
révèle un champ dépendant via `ZCondition`), **RTL** (`Directionality(TextDirection.rtl)` — variantes
directionnelles, aucun `EdgeInsets.only(left/right)`), **thème clair/sombre** (bascule `ThemeMode`,
couleurs dérivées du `ColorScheme`, aucune couleur littérale codée en dur — FR-26).

**AC4 — Consommation du composeur fp-2-2 (`registerZcrudFormFields`)** *(AR-4/AD-55, AD-56)*
**Given** le point de composition unique du binding (`packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart`)
**When** la showcase construit le `ZWidgetRegistry` qui peuple les kinds satellites
**Then** elle appelle **`registerZcrudFormFields(registry, …)`** (et NON une re-registration manuelle
kind-par-kind dupliquant le composeur) ; le registre est **détenu par l'app** et injecté via
`ZcrudScope.widgetRegistry` (jamais un singleton statique mutable, AD-4) ; le dispatcher `ZFieldWidget`
le résout à l'exécution ; un test prouve que le composeur est bien le chemin exercé (le champ satellite
se rend via l'adaptateur enrôlé par le composeur). *(Écart connu à trancher : `ZMarkdownField` exige un
`ZFormController` isolé absent de `ZFieldWidgetContext` — cf. Dev Notes ; la voie markdown dans la
showcase suit la même stratégie que `markdown_demo_screen.dart` si le dispatcher ne peut la monter, et
l'écart est consigné.)*

**AC5 — Banc SM-1 falsifiable** *(SM-1, NFR-1, AD-2)*
**Given** un formulaire de frappe intensive de la showcase/harnais
**When** l'utilisateur (le test) tape 100 caractères dans UN champ texte
**Then** **seul** ce champ se reconstruit (le compteur `RebuildLog` du champ courant augmente ; les
compteurs des champs voisins restent **inchangés**), **zéro perte de focus** (le même `EditableText`
garde le focus), **aucun `Form`/`FormBuilder` global** (`find.byType(Form)` → `findsNothing`), le
`TextEditingController` n'est **pas recréé** au rebuild. Le banc est **falsifiable** (mesure la bonne
granularité : un test qui rougirait si un rebuild global était réintroduit), PAS tautologique.

**AC6 — Harnais par axes : ossature réutilisable + axes MVP 1/5/6** *(FR-39 axes 1/5/6, NFR-7)*
**Given** le harnais dans `example/`
**When** on ouvre les formulaires MVP
**Then** l'**ossature** (un modèle de données décrivant un axe : identifiant, titre, statut, liste de
formulaires de démo + schéma `ZFieldSpec`) est en place et **réutilisable telle quelle par fp-3-2** (les
axes 2/3/4 et les 6 formulaires complets s'y branchent sans réécriture) ; les **axes MVP** sont peuplés :
**axe 1** (texte/nombre/date dense + banc SM-1), **axe 5** (intl/géo : `phoneNumber`/`country`/`location`),
**axe 6** (spécialisés/imbriqués : `rating`/`slider`/`signature`/`color`/`subItems`+réordonnancement) ;
au moins **3 formulaires** répliqués sur ces axes ; les axes non-MVP (2/3/4) sont présents dans
l'ossature mais **étiquetés « à venir »** (cohérent avec AC2).

**AC7 — Données fictives, zéro secret, zéro backend** *(AD-56/AR-6, AD-12)*
**Given** toute la surface fp-3-1
**When** elle s'exécute
**Then** toutes les données sont **fictives** (aucune donnée réelle DODLP, choix/relations en dur ou
fakes app-side), **aucun secret** (aucune clé Maps embarquée — la config géo vient de la plateforme de
l'app / repli coordonnées-seules AD-12), **aucune dépendance backend DODLP** ; un grep de secrets reste
vert.

**AC8 — Isolation `example/` : aucun package modifié + gates verts** *(AD-56, NFR-2/9)*
**Given** le workspace
**When** fp-3-1 est terminée
**Then** `git status --porcelain packages/` est **vide** (aucun fichier `packages/*` modifié — la story
est CONSOMMATRICE) ; `melos list` = **29** (monorepo agrandi par les satellites form-parity ; `zcrud_example` HORS glob = isolation OK — le compte 14 était périmé) ; `flutter analyze` de `example/` RC=0 ;
`flutter test` de `example/` RC=0 (nouveaux tests inclus) ; `example/pubspec.lock` propre (l'app hors
workspace). Vérif verte repo-wide (`melos run analyze` + `melos run verify`) inchangée (aucune régression
cross-package puisque `packages/*` intouché).

## Tasks / Subtasks

- [x] **T1 — Page showcase : squelette + route** (AC: 1, 3, 8)
  - [x] Créer `example/lib/demos/showcase/showcase_screen.dart` (nouvelle page, `StatefulWidget`,
        `ZFormController` STABLE créé en `initState`/`dispose`é — AD-2).
  - [x] Enregistrer l'entrée dans `home_screen.dart` (`_DemoEntry` « Showcase »).
  - [x] Monter le socle via `DynamicEdition` sur un schéma `ZFieldSpec[]` représentatif (réutiliser les
        patrons de `reference_form.dart`, données fictives).
- [x] **T2 — États transverses par champ** (AC: 3)
  - [x] Décliner chaque famille du socle en read-only / désactivé / erreur / valeur initiale /
        conditionnel (`ZCondition` garde→dépendant) ; bascules RTL (`Directionality`) et thème
        (`ThemeMode`) au niveau de la page (réutiliser les bascules de `app.dart` ou locales).
  - [x] Vérifier zéro couleur/​libellé codé en dur (FR-26 ; couleurs via `ColorScheme`, libellés via
        l10n/`ZcrudLocalizations` ou labels de schéma).
- [x] **T3 — Registre via le composeur fp-2-2** (AC: 4)
  - [x] Construire le `ZWidgetRegistry` de la showcase en appelant `registerZcrudFormFields(registry, …)`
        (importer `package:zcrud_get/…` — signature LUE ; passer `countryCatalog` partagé, `geoAdapterFactory`
        OSM si géo démontrée, `wireGeoArea` si `geoArea` exercé).
  - [x] Injecter le registre via `ZcrudScope.widgetRegistry` (app-owned, AD-4 — pas de singleton).
  - [x] Trancher la voie **markdown** (dispatcher vs montage direct type `markdown_demo_screen.dart`) et
        **consigner l'écart** si le dispatcher ne peut monter `ZMarkdownField` (contrôleur isolé absent du
        `ZFieldWidgetContext`).
- [x] **T4 — Étiquettes « ABSENT / à combler »** (AC: 2)
  - [x] Section/liste de gaps non livrés (`select` modal, média, WYSIWYG, `color` multiple, `icon`,
        `pin`, `autocomplete`, `editableTable`, `itemsAreTags`) avec statut visible ; jamais masqués,
        jamais faux-rendus.
- [x] **T5 — Harnais par axes : ossature + axes 1/5/6** (AC: 6)
  - [x] Créer `example/lib/demos/showcase/axis_harness.dart` : modèle de données `ShowcaseAxis`
        (id, titre, statut MVP/à-venir, `List<AxisForm>` avec schéma `ZFieldSpec`) — **ossature réutilisable
        par fp-3-2** (documenter ce point d'extension).
  - [x] Peupler axe 1 (dense texte/nombre/date + SM-1), axe 5 (phone/country/location), axe 6
        (rating/slider/signature/color/subItems+réordo) ; ≥ 3 formulaires ; axes 2/3/4 déclarés « à venir ».
- [x] **T6 — Banc SM-1 falsifiable** (AC: 5)
  - [x] Réutiliser `RebuildLog`/`RebuildBadge` (`support/rebuild_indicator.dart`) sur le formulaire dense
        de l'axe 1 ; exposer un `RebuildLog` injectable pour le test.
- [x] **T7 — Tests widget** (AC: 1, 2, 3, 5, 6, 7)
  - [x] `example/test/showcase_screen_test.dart` : les champs du socle se rendent via LEUR adaptateur
        réel (`find.byType(ZXxxFieldWidget)` / widget satellite, jamais `ZUnsupportedFieldWidget`) ;
        étiquettes ABSENT présentes ; read-only/désactivé/erreur/conditionnel/RTL/thème vérifiés.
  - [x] `example/test/showcase_sm1_test.dart` : SM-1 falsifiable (100 caractères → seul le champ courant
        rebuild, voisins inchangés, focus conservé, aucun `Form`). Modeler sur `sm1_granular_rebuild_test.dart`.
  - [x] `example/test/axis_harness_test.dart` : ossature — axes 1/5/6 peuplés, axes 2/3/4 « à venir »,
        ≥ 3 formulaires, données fictives.
- [x] **T8 — Gates & isolation** (AC: 7, 8)
  - [x] `git status --porcelain packages/` vide (aucun package modifié).
  - [x] `melos list` = 29 (isolation OK, `zcrud_example` hors glob ; 14 périmé) ; `flutter analyze` + `flutter test` de `example/` RC=0 ; grep secrets vert ;
        `melos run analyze` + `melos run verify` repo-wide verts.

## Dev Notes

### Infrastructure `example/` EXISTANTE à réutiliser (ne PAS réinventer)

- **`example/lib/support/rebuild_indicator.dart`** — `RebuildLog` (compteur par champ) + `RebuildBadge`
  (scellé sur UNE tranche `ZFieldListenableBuilder`). C'est déjà le compteur granulaire SM-1 : le banc de
  l'AC5 s'appuie dessus. [Source: example/lib/support/rebuild_indicator.dart]
- **`example/lib/demos/reference_form.dart`** — `ReferenceForm` : schéma `ZFieldSpec[]` pur-données
  (≥ 30 champs, sections, 1 conditionnel `premiumCode` gardé par `active`, grille responsive). Patron à
  cloner pour les schémas de la showcase/harnais. [Source: example/lib/demos/reference_form.dart]
- **`example/lib/demos/edition_demo_screen.dart`** — patron `DynamicEdition` + `ZFormController` STABLE
  (créé en `initState`, `dispose`é) + sélecteur de binding + `RebuildLog`. Modèle d'écran. [Source: example/lib/demos/edition_demo_screen.dart]
- **`example/test/sm1_granular_rebuild_test.dart`** — patron de test SM-1 falsifiable (baseline des
  compteurs, frappe, vérif voisins inchangés + focus + `find.byType(Form) == findsNothing`). Cloner la
  méthode pour `showcase_sm1_test.dart`. [Source: example/test/sm1_granular_rebuild_test.dart]
- **`example/lib/demos/demo_registry.dart`** — `buildDemoWidgetRegistry()` : construit AUJOURD'HUI le
  registre **manuellement** (`..register('location', …)`, `..register('phoneNumber', …)`) **sans** passer
  par le composeur. fp-3-1 doit, pour la showcase, passer par **`registerZcrudFormFields`** (AC4). Deux
  options : (a) refactorer `buildDemoWidgetRegistry()` pour déléguer au composeur ; (b) construire un
  registre showcase dédié via le composeur. **Choisir (a) si et seulement si** cela ne casse pas les démos
  géo/intl existantes (le composeur enrôle AUSSI `markdown` — voir écart ci-dessous) ; sinon (b) pour
  rester dans le périmètre example/ sans régression. Consigner le choix. [Source: example/lib/demos/demo_registry.dart]

### Composeur fp-2-2 — signature à appeler (LECTURE SEULE, ne pas éditer le package)

`void registerZcrudFormFields(ZWidgetRegistry registry, {ZCodec? richTextCodec, ZCountryCatalog?
countryCatalog, ZSubdivisionCatalog? subdivisionCatalog, ZPlaceSearchProvider? placeSearch,
ZMapAdapterFactory? geoAdapterFactory, bool wireGeoArea = false, Iterable<void Function(ZWidgetRegistry)>
additionalRegistrars})`. Il enrôle par défaut : voie markdown (`markdown`/`inlineMarkdown`/`richText`),
`phoneNumber`, `country`, `address`, `location` (+ `geoArea` si `wireGeoArea`). Collision de `kind` →
`throw ZDuplicateRegistrationError` (ne PAS composer deux fois le même registre ; ne pas re-`register`
un kind déjà enrôlé). [Source: packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart]

### Écart connu à trancher — voie MARKDOWN via le dispatcher

`demo_registry.dart` note explicitement que **markdown n'est PAS enregistré** dans le registre de la démo
car `ZMarkdownField` exige un `ZFormController` (contrôleur isolé, AD-7) **absent du `ZFieldWidgetContext`**
(le dispatcher ne passe que `ctx.value`/`ctx.onChanged`, jamais le contrôleur — AD-2). Or le composeur
`registerZcrudFormFields` enrôle `markdown` par défaut. **Conséquence pour fp-3-1** : appeler le composeur
enrôle le builder markdown, mais son montage via `DynamicEdition`/`ZFieldWidget` peut ne pas fournir le
contrôleur attendu. **Décision dev** : soit la voie markdown de la showcase est montée DIRECTEMENT (patron
`markdown_demo_screen.dart`) hors dispatcher, soit le builder markdown du composeur gère l'absence de
contrôleur ; dans les deux cas **consigner l'écart** dans les Completion Notes (ne PAS modifier le
package pour « corriger » — hors périmètre fp-3-1 ; signaler si un vrai gap package émerge). [Source: example/lib/demos/demo_registry.dart lignes registrar]

### Présence ≠ association (piège central de la preuve)

Un champ « présent » à l'écran ne prouve rien s'il est mocké. Chaque test de la showcase doit vérifier
que le champ est rendu par **son adaptateur concret** — `find.byType(ZTextFieldWidget)`,
`ZDateFieldWidget`, `ZSignatureFieldWidget`, `ZPhoneFieldWidget` (satellite intl), `ZGeoFieldWidget`
(satellite geo), etc. — et **jamais** le `ZUnsupportedFieldWidget` (le fallback du dispatcher pour un kind
non enrôlé, cf. `packages/zcrud_core/lib/src/presentation/edition/families/z_unsupported_field_widget.dart`).
Un kind « ABSENT » (AC2) est justement celui qui rendrait `ZUnsupportedFieldWidget` ou n'est pas monté du
tout : il est **étiqueté**, pas faux-rendu.

### Banc SM-1 falsifiable (ne pas mesurer le mauvais grain)

Le test SM-1 doit rougir si un rebuild global était réintroduit. Mesurer via `RebuildLog.countOf(name)` :
prendre la baseline, taper N caractères dans le champ A, exiger `countOf(A)` augmente **et**
`countOf(B)`/`countOf(C)` **inchangés** (voisins). Vérifier le focus conservé (même `EditableText` focus)
et `find.byType(Form) == findsNothing`. Un test qui n'exigerait que « countOf(A) > 0 » serait tautologique
— exiger l'invariance des voisins. [Source: architecture-zcrud-2026-07-09/architecture.md AD-2 ; example/test/sm1_granular_rebuild_test.dart]

### États de champ — leviers disponibles (`ZFieldSpec`)

`ZFieldSpec` porte `readOnly` (bool), `condition` (`ZCondition`, visibilité conditionnelle évaluée par E3),
`defaultValue`, `validators`, `config`, `choices`. Le mode lecture GLOBAL existe
(`DynamicEdition(readOnly: true)` → `spec.copyWith(readOnly: true)`). Désactivé/erreur : via validateurs +
état du contrôleur. [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart]

### Invariants applicables (rappel — chaque AC les respecte)

- **AD-56 / AR-6** : harnais + showcase dans `example/` UNIQUEMENT, données fictives, zéro secret, aucun
  package modifié.
- **AD-2 / SM-1 / NFR-1** : `ZFormController` stable, rebuild granulaire par tranche, aucun `setState`
  d'écran, `TextEditingController` non recréé, `ValueKey(field.name)`.
- **AD-13** : RTL (variantes directionnelles — `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`),
  `Semantics`, cibles ≥ 48 dp.
- **FR-26** : aucun style/couleur/libellé codé en dur — thème via `ZcrudScope`/`ThemeExtension`, repli
  `Theme.of(context)`.
- **AD-4** : registre app-owned injecté via `ZcrudScope.widgetRegistry`, jamais un singleton statique mutable.
- **AD-12** : aucune clé Maps embarquée — géo via config plateforme de l'app / repli coordonnées-seules.
- **`ListView.builder`** (jamais `ListView(children:)`), `const` sur widgets immuables.

### Testing standards

- Framework : `flutter_test` (widget tests dans `example/test/`, patron des tests existants).
- Chaque AC → fichier réel + test : rendu par adaptateur réel (présence≠association), étiquettes ABSENT,
  états transverses, SM-1 falsifiable (compteurs + focus + absence de `Form`), ossature axes.
- Rejouer la **vérif verte** : `flutter analyze` + `flutter test` de `example/` RC=0 ; `melos run analyze`
  + `melos run verify` repo-wide (aucune régression cross-package attendue, `packages/*` intouché).

### Project Structure Notes

- Nouveaux fichiers (tous sous `example/`) : `example/lib/demos/showcase/showcase_screen.dart`,
  `example/lib/demos/showcase/axis_harness.dart` (ossature réutilisable fp-3-2), éventuels schémas
  `showcase_forms.dart` ; entrée dans `example/lib/home_screen.dart` ; tests
  `example/test/showcase_screen_test.dart`, `example/test/showcase_sm1_test.dart`,
  `example/test/axis_harness_test.dart`.
- Refactor éventuel (au choix dev, AC4) : `example/lib/demos/demo_registry.dart` pour déléguer à
  `registerZcrudFormFields` — UNIQUEMENT si sans régression des démos géo/intl.
- **Contrainte d'isolation** (`example/pubspec.yaml`) : l'app est HORS du `workspace:` root et hors glob
  melos `packages/**` ; lock propre `example/pubspec.lock` ; consommatrice only — NE modifie AUCUN
  `packages/*`. `zcrud_core` reste Syncfusion/Firebase/Maps-free (SM-5). [Source: example/pubspec.yaml]

### Vérifications sur disque déjà jouées (état au départ)

- `grep -rniq "showcase" example/lib` → **rc=1** (ABSENT — la page n'existe pas encore).
- `grep -rniq "harnais\|axe " example/lib` → **rc=1** (ABSENT — l'ossature axes n'existe pas).
- `registerZcrudFormFields` **n'est consommé nulle part** hors sa définition (grep repo-wide) → fp-3-1
  est le premier consommateur du composeur fp-2-2.
- `EditionFieldType` porte 46 valeurs dont `dateRange` (livré fp-1-1). [Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart]
- `fp-2-2` = `done` au sprint-status (composeur disponible). [Source: sprint-status.yaml]

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Epic 3 / Story 3.1]
- [Source: packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart] (composeur fp-2-2, AD-55)
- [Source: example/lib/support/rebuild_indicator.dart] (banc SM-1 granulaire)
- [Source: example/lib/demos/reference_form.dart] (patron schéma) ; [Source: example/lib/demos/edition_demo_screen.dart] (patron écran)
- [Source: example/test/sm1_granular_rebuild_test.dart] (patron SM-1 falsifiable)
- [Source: example/lib/demos/demo_registry.dart] (registre manuel actuel + écart markdown)
- [Source: docs/dodlp-form-integration-study-2026-07-17/NEXT-ITERATION-SCOPE.md] (matrice de couverture showcase + shortlist 6 formulaires)
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md] (couverture par type × parité)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] (AD-2, AD-4, AD-12, AD-13, AD-55, AD-56)

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — reprise dev-story après plantage d'un agent précédent.

### Debug Log References

- `dart analyze` (scope fp-3-1) → **No issues found** (lib/demos/showcase + 3 tests + home_screen).
- `flutter test test/showcase_screen_test.dart` → **9/9 pass**.
- `flutter test test/showcase_sm1_test.dart` → **1/1 pass** (banc SM-1).
- `flutter test test/axis_harness_test.dart` → **2/2 pass** (ossature + harnais).
- `git status --porcelain packages/` → **vide** (aucun package modifié — story consommatrice).

### Completion Notes List

**Réutilisé du partiel de l'agent mort (non recréé)** : `axis_harness.dart` (ossature
`ShowcaseAxis`/`AxisForm`/`AbsentCapability`/`AxisFormScreen`/`AxisHarnessScreen`) et
`showcase_registry.dart` (`buildShowcaseWidgetRegistry` via le composeur fp-2-2) — évalués
cohérents avec la story, conservés tels quels (0 modification).

**Recréé / ajouté** : `showcase_data.dart` (socle + axes 1/5/6 + axes 2/3/4 « à venir » +
gaps ABSENTS), `showcase_screen.dart` (page showcase), entrée « Showcase » dans
`home_screen.dart`, et 3 tests.

**Écart MARKDOWN (tranché)** : l'écart historique « markdown exige un `ZFormController` »
est **résolu** — le composeur fp-2-2 enrôle `markdown` via `ZMarkdownField.fromContext`
(voie `ctx`-native, SANS contrôleur, cf. `z_markdown_registration.dart`). Le dispatcher
`ZFieldWidget` (famille `registryOrFallback` → `_dispatchRegistry`) le monte donc
DIRECTEMENT. La voie markdown de la showcase passe par le VRAI dispatcher (test :
`find.byType(ZMarkdownField)`), aucun montage direct ni modif package nécessaires.

**Détail d'intégration** : `ColoredBox` de fond du thème local remplacé par `Material`
(porte la couleur de surface ET sert d'ancêtre Material aux `ListTile`/encres — évite
l'assertion Flutter « ListTile background may be invisible »).

**Read-mode global** : un `bool _readOnly` (via `setState`) est passé à `DynamicEdition(readOnly:)` ⇒
une bascule LIVE du mode lecture garde les champs saisissables en `TextField` `readOnly:true` (pas de
fiche `ZReadOnlyFieldCard`, qui exigerait un montage frais en read-mode). L'état read-only reste
prouvé de façon falsifiable (`EditableText.readOnly` bascule false→true). _(corrigé post-revue :
la description mentionnait à tort un symbole `_readModeCard`/`ZReadOnlyFieldCard` inexistant sur disque.)_

**Pré-existant hors périmètre fp-3-1 — CORRIGÉ PAR REMÉDIATION ORCHESTRATEUR SÉPARÉE (mise à jour post-revue)** :
au moment du dev de fp-3-1, `dart analyze example` était RC≠0 à cause de **2 erreurs pré-existantes**
dans des fichiers que fp-3-1 n'a PAS touchés (dérive d'API des vagues committées) :
`test/offline_demo_test.dart:146` (fake `ZLocalStore` sans `applyMerged`/`syncEntries`) et
`test/markdown_demo_test.dart:32` (`controller` nullable). L'agent dev de fp-3-1 a **respecté sa
frontière** et ne les a pas corrigés. Ils ont été **réparés ensuite par une remédiation example
distincte de l'orchestrateur** (fakes réalignés sur le port réel `ZLocalStore` + `!` justifié — aucune
assertion affaiblie, aucun package touché). État ACTUEL sur disque : **`dart analyze example` RC=0**
(1 seul `info` deprecation `list_demo_screen.dart:390`, non fatal), **`flutter test example` = 83 verts**.
Ces 2 fichiers (`example/test/{offline_demo_test,markdown_demo_test}.dart`) sont modifiés dans le
working tree mais **n'appartiennent pas à la File List de fp-3-1** (remédiation séparée).

### File List

Nouveaux (tous sous `example/`) :
- `example/lib/demos/showcase/showcase_data.dart`
- `example/lib/demos/showcase/showcase_screen.dart`
- `example/test/showcase_screen_test.dart`
- `example/test/showcase_sm1_test.dart`
- `example/test/axis_harness_test.dart`

Réutilisés du partiel (conservés, 0 modif) :
- `example/lib/demos/showcase/axis_harness.dart`
- `example/lib/demos/showcase/showcase_registry.dart`

Modifiés :
- `example/lib/home_screen.dart` (entrée « Showcase »)

Aucun `packages/*` modifié (story consommatrice — AD-56).
