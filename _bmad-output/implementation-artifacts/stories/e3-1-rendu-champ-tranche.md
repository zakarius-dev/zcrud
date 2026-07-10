---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---

# Story 3.1: Rendu d'un champ = widget écoutant sa tranche (`ValueListenableBuilder`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP en priorité)**,
je veux **un formulaire d'édition de référence (`DynamicEdition`) où chaque champ est un widget top-level qui n'écoute QUE sa tranche d'état** via `ValueListenableBuilder` (aucun `setState` global),
afin que **taper dans un champ ne reconstruise que ce champ (SM-1 plein formulaire) — corrigeant par conception le bug historique de rebuild global (jank, perte de focus, saut de curseur), OBJECTIF PRODUIT N°1** — et que **la saisie en cours survive à un rebuild externe (perte de connexion, UJ-2)**.

**Contexte produit.** E2-7 a prouvé la garantie de rebuild ciblé **au niveau du controller** (harnais 2 champs, `sm1_granular_rebuild_test.dart`). E3-1 est la **réalisation PLEIN-FORMULAIRE** : on assemble N champs à partir d'un `ZFormController` dans un formulaire de référence et on porte le **test SM-1 complet** exigé par le PRD (≥ 30 champs, ≥ 3 sections, 100 caractères). C'est la première story d'E3, l'épic qui « corrige le bug de rebuild » (couvre FR-1..FR-5, AD-2, SM-1 ; dépend d'E2).

## Acceptance Criteria

> Tous les ACs sont **testables** (widget tests `flutter_test` + gardes de pureté existantes). Les compteurs de build et les `FocusNode` sont les instruments de preuve de SM-1.

1. **AC1 — Frontière de rebuild = la tranche.** Chaque champ du formulaire est rendu par un **widget hôte générique** (`ZEditionField`, nouveau) qui n'écoute QUE la tranche du champ via `ZFieldListenableBuilder(controller, name: field.name, builder: …)` (fin wrapper de `ValueListenableBuilder` sur `controller.fieldListenable(name)` — helper E2-7 réutilisé, PAS réimplémenté). Écrire une valeur (`controller.setValue(name, …)`) ne notifie QUE les listeners de cette tranche : un test avec compteur de build par champ montre que seul le champ écrit se reconstruit.

2. **AC2 — Aucun `setState` global, aucun rebuild global sur frappe.** Le `build()` de niveau formulaire (`DynamicEdition`) **ne se ré-exécute PAS** lors d'une frappe : un compteur de build de niveau formulaire reste **inchangé** pendant une session de saisie. Aucun `setState` à l'échelle du formulaire n'existe dans le code (garde textuelle dans le test / revue). `setValue` ne déclenche jamais `notifyListeners()` global (invariant `ZFormController` d'E2-7 : seul le canal structurel `visibleFields` le fait).

3. **AC3 — Place stable (`ValueKey(field.name)`) + assemblage sans closure locale.** Chaque `ZEditionField` porte `key: ValueKey(field.name)`. La liste des champs est construite via **`ListView.builder`** (jamais `ListView(children: [...])`), et chaque champ est un **widget top-level** — pas construit dans une closure locale du `build()` parent au-delà de la frontière `builder` du slice. Le formulaire n'observe que le canal **structurel** `controller.visibleFields` (via `ValueListenableBuilder<List<String>>`), jamais une tranche de valeur.

4. **AC4 — Controller stable, valeur détenue par le `ZFormController`, zéro ré-injection.** Le `ZFormController` est créé **une fois** et détenu de façon stable (par l'hôte/harnais ; jamais recréé dans un `build`). Le `TextEditingController` interne au `ZEditionField` est créé **une seule fois** (`initState`) et libéré (`dispose`) ; il n'est **jamais recréé** au rebuild ni **ré-injecté** depuis la valeur de la tranche (`.text = …` interdit dans la voie de frappe) — la saisie est à **sens unique** `onChanged → controller.setValue`. (La formalisation complète du contrat de controller stable/validation ciblée relève d'E3-2 — voir Frontière.)

5. **AC5 — `DynamicEdition` : formulaire de référence.** Un widget `DynamicEdition` assemble N champs à partir d'un `ZFormController` + `List<ZFieldSpec>` : il rend, pour chaque nom de `controller.visibleFields`, un `ZEditionField` correspondant. Il supporte un regroupement visuel en **sections** (en-têtes de section simples, non repliables). Un test d'assemblage prouve que N champs distincts sont rendus, chacun lié à sa tranche.

6. **AC6 — TEST SM-1 COMPLET (headline).** Sur un **formulaire de référence à ≥ 30 champs répartis en ≥ 3 sections**, **taper 100 caractères** dans un champ situé au milieu du formulaire :
   - le **compteur de build du champ courant** augmente (≈ 1 par frappe) ;
   - le **compteur de build de CHAQUE autre champ** reste **strictement égal** à sa valeur initiale (aucun voisin reconstruit) ;
   - le **compteur de build de niveau formulaire** reste **inchangé** (zéro rebuild global) ;
   - le **`FocusNode` du champ courant** conserve `hasFocus == true` d'un bout à l'autre ;
   - la **sélection/position du curseur** n'est jamais réinitialisée (curseur en fin de texte après la frappe, texte final = 100 caractères saisis).

7. **AC7 — EDGE CASE UJ-2 (perte de connexion pendant la saisie).** Pendant une saisie **en cours** (texte partiel dans un champ), un **rebuild externe** de l'ancêtre du formulaire — simulant une perte/reprise de connexion (ex. changement d'un `InheritedWidget`/état de connectivité déclenchant `markNeedsBuild` sur un ancêtre) — **ne** provoque **NI** reconstruction/recréation du `ZFormController`, **NI** perte de la saisie en cours :
   - `identical(controllerAvant, controllerAprès) == true` (même instance) ;
   - `controller.valueOf(name)` == la valeur partielle saisie (non perdue) ;
   - le `TextField` affiche toujours le texte partiel ; les valeurs des **autres** champs sont intactes ;
   - l'`Element`/`State` du `ZEditionField` (et son `TextEditingController`) **ne sont pas recréés** (réutilisation d'élément grâce à `ValueKey(name)` ; pas de ré-injection) ;
   - le `FocusNode` conserve le focus.

8. **AC8 — Pureté par couche & invariants AD respectés.** Les nouveaux fichiers vivent sous `packages/zcrud_core/lib/src/presentation/edition/`, n'importent que les URIs Flutter autorisées sous `presentation/` (`foundation`/`widgets`/`material`), **aucun** gestionnaire d'état, **aucune** dépendance lourde — la garde `presentation_purity_test.dart` reste **verte**. Les nouveaux types publics sont exportés par le barrel `lib/zcrud_core.dart`. `melos run generate` → `analyze` RC=0 → `flutter test` RC=0.

## Tasks / Subtasks

- [x] **Tâche 1 — `ZEditionField` : widget hôte générique scellé sur sa tranche (AC1, AC3, AC4)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart`.
  - [x] `StatefulWidget` prenant `{ required ZFormController controller, required ZFieldSpec field }` ; `key: ValueKey(field.name)` posé par l'assembleur (`DynamicEdition`), documenté comme obligatoire.
  - [x] Dans le `build`, envelopper le rendu dans `ZFieldListenableBuilder(controller: controller, name: field.name, builder: …)` — **réutiliser** le helper E2-7, ne pas réimplémenter le `ValueListenableBuilder`.
  - [x] `State` : créer le `TextEditingController` **une fois** en `initState` (valeur initiale = `controller.valueOf(field.name)` en `String`), le `dispose` ; **jamais** `.text = …` dans la voie de frappe ; `onChanged: (v) => controller.setValue(field.name, v)` (sens unique).
  - [x] **Rendu par défaut uniforme** (un `TextField` générique) — le **dispatcher par type** (`ZFieldWidget` texte/nombre/date/booléen/select/relation) est **E3-3a** (voir Frontière) ; ici un rendu texte unique suffit à prouver SM-1 sur N champs.
- [x] **Tâche 2 — `DynamicEdition` : formulaire de référence (AC2, AC3, AC5)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart`.
  - [x] Prend `{ required ZFormController controller, required List<ZFieldSpec> fields, ... regroupement en sections }`.
  - [x] Observer **uniquement** `controller.visibleFields` via `ValueListenableBuilder<List<String>>` ; pour chaque nom visible, rendre un `ZEditionField(key: ValueKey(name), …)` via **`ListView.builder`**.
  - [x] En-têtes de section = simples widgets non interactifs (regroupement visuel ; **repli/conditionnel/grille = E3-4**, hors périmètre).
  - [x] **Aucun** `setState` de niveau formulaire ; **aucune** écoute d'une tranche de valeur au niveau formulaire ; champs construits comme widgets top-level (frontière `builder`).
- [x] **Tâche 3 — Export & barrel (AC8)**
  - [x] Exporter `ZEditionField` et `DynamicEdition` depuis `lib/zcrud_core.dart` (section couche présentation, ordre alpha `directives_ordering`).
- [x] **Tâche 4 — Harnais de formulaire de référence pour les tests (AC6)**
  - [x] Fabrique de test : `ZFormController` + `List<ZFieldSpec>` de **≥ 30 champs / ≥ 3 sections**, avec **compteurs de build par champ** et **compteur de build de niveau formulaire** (via un `builder` instrumenté ou un `ValueWidgetBuilder` compteur).
- [x] **Tâche 5 — Test SM-1 plein formulaire (AC6)**
  - [x] `test/presentation/edition/sm1_full_form_test.dart` : focaliser un champ central, taper **100 caractères** caractère-par-caractère (`pump` par frappe) ; asserts sur compteurs (champ courant ↑, voisins inchangés, formulaire inchangé), `FocusNode.hasFocus`, sélection/curseur, texte final.
- [x] **Tâche 6 — Test edge UJ-2 (AC7)**
  - [x] `test/presentation/edition/uj2_external_rebuild_test.dart` : saisie partielle → déclencher un rebuild externe de l'ancêtre (changement d'`InheritedWidget`/état simulé de connexion) → asserts `identical(controller)`, `valueOf`, texte affiché, autres champs intacts, `State`/`TextEditingController` non recréés, focus préservé.
- [x] **Tâche 7 — Test d'assemblage `DynamicEdition` (AC5)**
  - [x] `test/presentation/edition/dynamic_edition_test.dart` : N champs distincts rendus, chacun lié à sa tranche ; changement de `visibleFields` reflété (ajout/retrait) sans toucher les tranches de valeur des champs restants.
- [x] **Tâche 8 — Vérif verte & gardes (AC8)**
  - [x] `dart run melos run generate` → `analyze` RC=0 → `flutter test` RC=0 ; `presentation_purity_test.dart` vert ; pas de `ListView(children:)`, pas de `setState` formulaire (revue + garde textuelle si utile).

## Dev Notes

### Objectif produit n°1 — plein formulaire

E3-1 transforme la **mécanique** réactive d'E2-7 (controller + helper de slice) en **rendu de formulaire** et en apporte la **preuve plein-format** (SM-1). Le bug historique = un `build()` de formulaire qui reconstruit TOUS les champs à chaque frappe → jank, perte de focus, saut de curseur. La correction par conception : **un champ = un widget top-level qui n'écoute que sa tranche** ; le formulaire n'écoute que la **structure** (`visibleFields`), jamais les valeurs.

### État réel sur disque (fondation à réutiliser, NE PAS réinventer)

- **`ZFormController`** (`lib/src/presentation/z_form_controller.dart`, E2-7) : `ChangeNotifier` pur-Flutter. `fieldListenable(name)` = tranche `ValueListenable` **mémoïsée** (même instance pour un `name`, création paresseuse). `setValue(name, v)` notifie **UNIQUEMENT** cette tranche (aucun `notifyListeners()` global). `valueOf(name)` lit la valeur. `visibleFields`/`setVisibleFields(names)` = **seul** canal structurel qui déclenche `notifyListeners()` global. `dispose()` libère toutes les tranches. → E3-1 **consomme** cette API telle quelle.
- **`ZFieldListenableBuilder`** (`lib/src/presentation/z_field_listenable_builder.dart`, E2-7) : fin wrapper de `ValueListenableBuilder` sur `controller.fieldListenable(name)`. Sa doc dit explicitement : « poser `key: ValueKey(name)` sur le widget de champ ; NE PAS construire les champs dans une closure locale du `build()` parent ; ne jamais ré-injecter dans un `TextEditingController` ». → E3-1 **réutilise** ce helper comme frontière de rebuild ; ne pas le dupliquer.
- **`ZcrudScope`** (`lib/src/presentation/zcrud_scope.dart`, E2-7/E2-8) : `InheritedWidget` zéro-config portant les seams (`resolver`/`acl`/`labels`/`theme`). E3-1 n'a PAS besoin de seam applicatif (rendu texte neutre) ; si un `DynamicEdition` doit résoudre un label/thème, passer par `ZcrudScope.of` / `ZcrudTheme.of` (repli `Theme.of`). Le harnais de test enveloppe l'arbre dans un `ZcrudScope()` par défaut si besoin.
- **`ZFieldSpec`** (`lib/src/domain/edition/z_field_spec.dart`, E2-4/E2-5) : `const` pur-données (`name`, `type`, `label`, `validators`, `config`, `choices`, `condition`, `defaultValue`, `readOnly`, `showIfNull`, …). E3-1 lit `name`/`label`/`defaultValue` ; l'**interprétation `type → widget`** est E3-3a (ici rendu texte uniforme, indépendant de `type`).
- **`EditionFieldType`** (`lib/src/domain/edition/edition_field_type.dart`) : enum ouvert (`text`, `number`, `boolean`, …, `custom`). **Non utilisé pour dispatcher en E3-1** (rendu uniforme).

### Preuve E2-7 déjà en place (à étendre, pas à refaire)

`test/presentation/sm1_granular_rebuild_test.dart` prouve SM-1 **au niveau controller** (2 champs, `setValue`/`enterText` ×N, `buildsA`↑, `buildsB` inchangé, `buildsGlobal` inchangé, `focusNode.hasFocus`). E3-1 **porte cette preuve au plein formulaire** (≥ 30 champs, ≥ 3 sections, 100 caractères) sur `DynamicEdition`. Réutiliser le même **patron de compteurs** et la même discipline (saisie sens unique `onChanged → setValue`, jamais `.text=`).

### Frontière de couche (AD-14, AD-1) — RAPPEL

`zcrud_core/presentation/` **autorise** Flutter (`foundation`/`widgets`/`material`) ; c'est la couche **`domain/`** qui est pur-Dart. Les nouveaux widgets d'E3-1 vivent sous `presentation/edition/`. Gardes en vigueur : `presentation_purity_test.dart` (interdit `dart:ui` direct, `cupertino`, `services`, tout gestionnaire d'état, dépendances lourdes), `style_purity_test.dart` (pas de style codé en dur ; ici rendu neutre via `Theme.of`/repli). Rester dans ces clous.

### Conception du rendu de champ par tranche + formulaire de référence

```
DynamicEdition(controller, fields)
  └─ ValueListenableBuilder<List<String>>(controller.visibleFields)   ← écoute STRUCTURE only
       └─ ListView.builder( itemCount: visible.length )
            └─ ZEditionField(key: ValueKey(name), controller, field)   ← widget top-level, place stable
                 └─ ZFieldListenableBuilder(controller, name)          ← écoute la TRANCHE only
                      └─ TextField( controller: _texEditingCtrl,        ← créé 1×, jamais ré-injecté
                                    onChanged: (v)=>controller.setValue(name,v) )  ← sens unique
```
Points-clés AD-2 garantis par ce montage : (1) le `build` de `DynamicEdition` ne dépend que de `visibleFields` → une frappe (qui ne touche pas `visibleFields`) ne le ré-exécute pas ; (2) `ValueKey(name)` fige la place → un rebuild externe réutilise l'`Element`/`State` (état de saisie préservé, UJ-2) ; (3) `TextEditingController` créé une fois, jamais ré-injecté → focus/curseur intacts ; (4) `ZFieldListenableBuilder` borne le rebuild à la tranche du champ.

### Design du test SM-1 complet (100 caractères)

- **Harnais** : `DynamicEdition` avec ≥ 30 `ZFieldSpec` répartis en ≥ 3 « sections » (regroupement visuel simple). Instrumenter chaque champ avec un **compteur de build** (`Map<String,int>`), incrémenté dans le `builder` du slice de ce champ ; un **compteur de niveau formulaire** incrémenté dans le `builder` structurel du `ValueListenableBuilder<List<String>>` (ou un `StatelessWidget`/`StatefulWidget` compteur enveloppant `DynamicEdition`).
- **Action** : `tester.tap` sur le champ cible (focus), puis boucle de **100 frappes** — saisir caractère par caractère (ex. `tester.enterText(finder, texte[0..i])` puis `await tester.pump()`), OU envoyer 100 événements de touche. Utiliser un `FocusNode` explicite sur le champ cible pour l'assertion.
- **Asserts** : `builds[cible]` a augmenté (≈ 100) ; `∀ autre champ visible/monté : builds[autre] == builds0[autre]` (inchangé) ; `formBuilds == formBuilds0` (== 1 typiquement) ; `focusNode.hasFocus == true` ; `TextSelection` = curseur en fin (`baseOffset == extentOffset == 100`) ; `controller.valueOf(cible)` == la chaîne saisie.
- **Piège à documenter** : `enterText` de `flutter_test` **remplace** tout le texte et repositionne le curseur — pour prouver « zéro perte de curseur », préférer une saisie incrémentale caractère-par-caractère (chaîne cumulative) OU vérifier explicitement que la sélection finale est cohérente ; ne pas conclure faussement à partir du comportement de remplacement de `enterText`.

### Design de l'edge case UJ-2 (perte de connexion pendant la saisie)

- **Simulation** : le formulaire est enfant d'un ancêtre porteur d'un état de « connexion » (ex. un `StatefulWidget`/`InheritedWidget` `_ConnectivityHost`). Pendant une saisie **partielle** (ex. 10 caractères entrés), déclencher `setState`/mise à jour de cet ancêtre (bascule online→offline) ⇒ `markNeedsBuild` se propage à l'arbre du formulaire.
- **Invariant prouvé** : le `ZFormController` est **créé hors** du sous-arbre reconstruit (détenu par le harnais/hôte, référence stable) ; les `ZEditionField` sont **keyés** ⇒ réutilisation d'`Element`/`State`. Donc : `identical(controllerAvant, controllerAprès)`, `controller.valueOf(name) == '0123456789'`, `find.text('0123456789')` toujours présent, autres champs intacts, `State`/`TextEditingController` non recréés (vérifier via un compteur d'`initState` == 1, ou l'identité du `State`), `focusNode.hasFocus == true`.
- **Anti-pattern à NE PAS commettre** (sinon UJ-2 casse) : recréer le `ZFormController` dans un `build`, omettre `ValueKey(name)`, ou ré-injecter `_texEditingCtrl.text = valeurTranche` au rebuild (écraserait la saisie/sélection).

### Frontière E3-1 / E3-2 / E3-3a (décision de découpe)

- **E3-1 (cette story)** : pose **le mécanisme de tranche au niveau widget** (`ZEditionField` scellé sur sa tranche) + **le formulaire de référence** (`DynamicEdition`, assemblage `ListView.builder` + sections visuelles) + **la preuve SM-1 plein-format** (100 caractères) + **l'edge UJ-2**. Le `TextEditingController` est créé **une fois** (minimum nécessaire pour prouver « zéro perte de focus/curseur ») et la voie de frappe est **sens unique**.
- **E3-2 (suivante)** : **formalise et généralise** le contrat de controller stable et la **validation ciblée** : `AutovalidateMode.onUserInteraction` par champ, **validateurs mémoïsés** (`ZValidatorSpec → FormBuilderValidators`), garantie de cycle **create/dispose** robuste même sous bascule de visibilité, préservation curseur sous rebuild structurel comme contrat testé de premier ordre. E3-1 **n'introduit ni** `AutovalidateMode` **ni** validateurs.
- **E3-3a (ensuite)** : remplace le **rendu par défaut uniforme** de `ZEditionField` par un **dispatcher par type** (`ZFieldWidget` pour texte/nombre/date/booléen/select/relation), avec a11y/RTL par-widget (`Semantics`, cibles ≥ 48 dp, `EdgeInsetsDirectional`/`TextAlign.start`, AD-13/FR-23). E3-1 rend volontairement **type-agnostique** pour que E3-3a échange le rendu interne **sans** toucher la machinerie de slice/frontière.
- **E3-4 (plus tard)** : sections **repliables**, champs **conditionnels** (`displayCondition` via place stable + `setVisibleFields`), mode lecture, **grille responsive** 12 colonnes. E3-1 ne fournit que des **en-têtes de section visuels** non repliables.

### a11y / RTL en E3-1

L'exigence a11y/RTL **par-widget** (`Semantics`, cibles ≥ 48 dp, insets directionnels) est portée par **E3-3a** (dispatcher). E3-1 ne doit **pas** introduire de régression : si un layout est écrit, utiliser les variantes **directionnelles** (`EdgeInsetsDirectional`, `TextAlign.start/end`) — jamais `left/right` (AD-13, garde de style). Garder le rendu minimal.

### Project Structure Notes

- Nouveaux fichiers : `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart`, `.../edition/dynamic_edition.dart` (sous-dossier `edition/` **nouveau** sous `presentation/`, cohérent avec le regroupement `l10n/`, `theme/` existants).
- Exports ajoutés dans `packages/zcrud_core/lib/zcrud_core.dart` (section « Couche présentation », ordre alpha).
- Tests sous `packages/zcrud_core/test/presentation/edition/` : `sm1_full_form_test.dart`, `uj2_external_rebuild_test.dart`, `dynamic_edition_test.dart`.
- **Aucune** modification de `z_form_controller.dart` / `z_field_listenable_builder.dart` attendue (API E2-7 suffisante). Si un besoin réel émerge (ex. exposer `hasSlice(name)`), le documenter et le justifier (extension additive, sans casser E2-7).
- **Conflit potentiel / variance** : `DynamicEdition` dans un `ListView.builder` — si l'app hôte imbrique le formulaire dans un scroll parent, prévoir `shrinkWrap`/`physics` documentés (ne pas sur-concevoir ; défaut simple, note pour E3-4/E7).

### Testing standards

- Framework : `flutter_test` (`WidgetTester`, `pump`, `find`, `FocusNode`, `tester.enterText`/événements clavier). Le package `zcrud_core` est un **package Flutter** (les tests de présentation tournent sous `flutter test`).
- Scripts melos scindés (E2-7) : `test:flutter` couvre `zcrud_core` (a un `test/` + Flutter). Vérif verte = `melos run generate` → `analyze` RC=0 → `flutter test` RC=0.
- Compteurs de build : instrument standard (voir `sm1_granular_rebuild_test.dart` d'E2-7 comme patron de référence).
- Gardes existantes à garder vertes : `presentation_purity_test.dart`, `style_purity_test.dart`, `domain_purity_test.dart` (le domaine reste pur-Dart, non touché).

### References

- [Source: epics.md#E3] — Épic E3 « Moteur DynamicEdition à rebuilds granulaires », objectif : corriger le bug de rebuild ; couvre FR-1..FR-5, AD-2, SM-1 ; dépend d'E2.
- [Source: epics.md#E3 Story E3-1] — AC : `ZFormController` immuable ; **aucun** `setState` global ; test widget « taper 100 caractères ne reconstruit que le champ courant » (SM-1) ; **edge case UJ-2** : perte de connexion pendant la saisie → état du `ZFormController` non reconstruit/perdu.
- [Source: epics.md#E3 Stories E3-2/E3-3a/E3-4] — frontière : E3-2 (controllers/keys stables, `AutovalidateMode`, validateurs mémoïsés), E3-3a (dispatcher par type + a11y/RTL par-widget), E3-4 (sections repliables/conditionnelles/grille).
- [Source: architecture.md#AD-2] — réactivité Flutter-native, rebuilds granulaires ; interdits (`setState` formulaire, construction dans closure locale de `build()`, recréation de `TextEditingController`, ré-injection de valeur) ; obligatoires (controller stable create/dispose, `ValueKey(field.name)`, validateurs mémoïsés, `AutovalidateMode.onUserInteraction`, place stable) ; diagramme du cycle réactif (`Frappe → ZFormController → valueListenable(name) → ZFieldWidget (ValueListenableBuilder) → rebuild ciblé`).
- [Source: architecture.md#AD-15] — aucun gestionnaire d'état dans `zcrud_core` ; bindings multi-gestionnaire via `ZcrudScope`.
- [Source: architecture.md#AD-14] — pureté PAR COUCHE : `presentation/` autorise Flutter (widgets), `domain/` pur-Dart.
- [Source: architecture.md#AD-13] — RTL/a11y : variantes directionnelles ; `Semantics`, cibles ≥ 48 dp (par-widget en E3-3a).
- [Source: prd.md#SM-1] — « Zéro rebuild global à l'édition : sur un formulaire de référence (≥ 30 champs, ≥ 3 sections), taper 100 caractères ne provoque aucun rebuild hors du champ courant et zéro perte de focus (test widget + profiling). Valide FR-1, FR-3. »
- [Source: prd.md#UJ-2] — DODLP saisit une fiche longue sans jank : chaque frappe ne reconstruit que le champ courant ; focus/curseur préservés ; apparition de champs conditionnels ne déplace pas le focus.
- [Source: prd.md#DynamicEdition] — génère un formulaire depuis un `ZFieldSpec[]` ; objectif n°1 = supprimer le rebuild global ; un champ = un widget top-level qui n'observe que sa tranche.
- [Source: story e2-7-reactivite-flutter-native.md] — fondation : `ZFormController`, `ZFieldListenableBuilder`, `ZcrudScope`, harnais SM-1 proto (2 champs) ; explicite « la version PLEIN FORMULAIRE 100 caractères sera portée en E3-1 sur `DynamicEdition` ».
- [Source: code z_form_controller.dart / z_field_listenable_builder.dart / zcrud_scope.dart / z_field_spec.dart] — API réellement disponible sur disque (lue, non supposée).
- [Source: CLAUDE.md#Réactivité Flutter-native + Key Don'ts] — jamais de `setState` formulaire ; `ListView.builder` ; variantes directionnelles ; `ValueKey`, controller stable.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, effort high).

### Debug Log References

Vérif verte rejouée réellement sur disque :
- `melos run analyze` → RC=0 (14 packages, `SUCCESS`).
- `melos run test` → RC=0 (total 325 : dart 8+80+8+8+17=121 ; flutter `zcrud_core` 204, dont les 6 nouveaux tests E3-1).
- `melos run verify` → RC=0 : `graph_proof` noeuds=14 / **CORE OUT=0 OK** / ACYCLIQUE OK ; `gate:melos` OK (13 scripts) ; `gate:reflectable` OK ; `gate:secrets` OK ; `gate:codegen` OK (0 `.g.dart` manquant, 0 committé) ; `gate:compat` OK ; `verify:serialization` OK.
- Non-régression : E2-7 `sm1_granular_rebuild_test.dart` (2/2) ✓ ; E2-9 parité ×4 `z_get_parity` / `z_riverpod_parity` / `zcrud_provider_scope` (13/13) ✓.

### Completion Notes List

- **AC1/AC4** — `ZEditionField` (`StatefulWidget`) scellé sur sa tranche via `ZFieldListenableBuilder` (helper E2-7 réutilisé, non réimplémenté) ; `TextEditingController` créé une fois en `initState`, `dispose` ; saisie **sens unique** `onChanged → setValue`, **zéro** `.text=`/ré-injection.
- **AC2/AC3/AC5** — `DynamicEdition` observe **uniquement** `controller.visibleFields` (`ValueListenableBuilder<List<String>>`) ; montage via **`ListView.builder`** ; chaque `ZEditionField` porte `key: ValueKey(name)` ; sections **visuelles** non repliables (en-têtes dérivés du thème, insets directionnels) ; **aucun** `setState` formulaire. Seam `fieldBuilder` (branchement E3-3a) + hooks d'instrumentation `@visibleForTesting` (`onInit`/`onBuild`/`onStructuralBuild`) pour les compteurs.
- **AC6 (SM-1 COMPLET)** — `sm1_full_form_test.dart` : formulaire 36 champs / 3 sections, 100 frappes incrémentales (chaîne cumulative — évite le piège `enterText`) dans un champ central. Prouvé : `builds[cible]` = baseline(1)+100 = **101** ; **chaque** voisin monté **= 1** (strictement inchangé) ; `formBuilds` **= 1** (0 rebuild global) ; `focusNode.hasFocus == true` d'un bout à l'autre ; `selection.base==extent==100` (curseur en fin, non réinitialisé) ; `valueOf(cible)` == 100 caractères.
- **AC7 (UJ-2)** — `uj2_external_rebuild_test.dart` : saisie partielle `0123456789` puis bascule externe connectivité (online→offline) sur un ancêtre. Prouvé : `identical(controllerAvant, controllerAprès)` ; `valueOf` cible+voisin préservés ; texte partiel toujours affiché ; **`initState` == 1** (State/`TextEditingController` non recréés grâce à `ValueKey`) ; focus conservé ; reprise de saisie post-reconnexion sans reset de curseur.
- **AC8** — nouveaux fichiers sous `presentation/edition/` (import `material` autorisé E2-8) ; `presentation_purity_test` + `style_purity_test` + `domain_purity_test` verts ; exports ajoutés au barrel (ordre alpha). `domain/`/`data/` pur-Dart inchangés ; 0 gestionnaire d'état / `WidgetRef` / `Get` / `Provider` dans `zcrud_core`.
- **Frontières respectées** : ni `AutovalidateMode`/validateurs (E3-2), ni dispatcher par type / a11y-RTL par-widget (E3-3a), ni sections repliables/conditionnelles/grille (E3-4). `z_form_controller.dart` / `z_field_listenable_builder.dart` **non modifiés** (API E2-7 suffisante).

### File List

Nouveaux :
- `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart`
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart`
- `packages/zcrud_core/test/presentation/edition/_reference_form.dart` (harnais partagé)
- `packages/zcrud_core/test/presentation/edition/sm1_full_form_test.dart` (AC6)
- `packages/zcrud_core/test/presentation/edition/uj2_external_rebuild_test.dart` (AC7)
- `packages/zcrud_core/test/presentation/edition/dynamic_edition_test.dart` (AC5)

Modifiés :
- `packages/zcrud_core/lib/zcrud_core.dart` (exports `DynamicEdition`/`ZEditionField`/`ZEditionSection`)
