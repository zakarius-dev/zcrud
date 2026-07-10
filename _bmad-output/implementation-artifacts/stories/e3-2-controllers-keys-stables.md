---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---

# Story 3.2: Controllers & keys stables, validation ciblée

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant `zcrud` dans une app hôte (DODLP en priorité)**,
je veux **un contrat de stabilité de champ FORMALISÉ et généralisé** (`TextEditingController` créé une seule fois, jamais recréé ni ré-injecté en écrasant la sélection, `ValueKey(field.name)`, `FocusNode` stable) **doublé d'une validation CIBLÉE par champ** (`AutovalidateMode.onUserInteraction` par champ, validateurs **mémoïsés** dérivés une fois des `ZValidatorSpec`),
afin que **la saisie survive à toute frappe et à tout rebuild externe sans jamais perdre le focus ni sauter le curseur — y compris quand le curseur est au MILIEU du texte (FR-1)** — et que **chaque champ affiche ses erreurs de validation localement, sans jamais déclencher de validation NI de rebuild global (AD-2, OBJECTIF PRODUIT N°1 / SM-1)**.

**Contexte produit.** E3-1 a posé le controller stable **MINIMAL** nécessaire à prouver SM-1 plein-formulaire : `TextEditingController` créé une fois, voie de frappe strictement **sens unique** (`onChanged → setValue`, **zéro** `.text=`), `ValueKey(name)`, rebuild borné à la tranche. E3-2 **FORMALISE et GÉNÉRALISE** ce contrat en deux ajouts orthogonaux à la machinerie de tranche (inchangée) :

1. **Stabilité généralisée** — le contrat devient un invariant testé de premier ordre : robustesse du cycle `create/dispose` même sous bascule de visibilité/rebuild structurel, `FocusNode` stable détenu par le `State`, et **synchronisation guardée valeur→champ** : une valeur changée **de l'extérieur** (p. ex. `setValue` programmatique, `defaultValue`, valeur dérivée) se reflète dans le `TextField` **quand le champ n'a pas le focus**, mais n'est **JAMAIS** ré-injectée en écrasant la sélection **quand le champ a le focus** (FR-1). E3-1 était volontairement 100 % sens unique ; E3-2 autorise cette réflexion externe **sûre** sans casser FR-1.
2. **Validation ciblée** — le rendu passe de `TextField` à `TextFormField` **autonome** (sans `Form`/`FormBuilder` global — AD-2), avec `autovalidateMode: AutovalidateMode.onUserInteraction` **par champ** et un `validator` **mémoïsé** compilé **une seule fois** depuis `field.validators` (`ZValidatorSpec` d'E2-4) — identité stable entre builds, jamais recréé au rebuild.

E3-2 reste **type-agnostique** (un `TextFormField` uniforme) : le dispatcher par type et l'a11y/RTL par-widget restent **E3-3a** ; la validation globale à la soumission + dirty + `onSubmit` restent **E3-6** (voir Frontière). Couvre **FR-1** ; renforce **AD-2**, **SM-1**.

## Acceptance Criteria

> Tous les ACs sont **testables** (widget tests `flutter_test` : compteurs de build, `FocusNode`, `TextSelection`, IME simulé via `tester.testTextInput`, `find.text` des messages d'erreur). Les gardes de pureté existantes restent l'oracle des invariants d'architecture.

1. **AC1 — Contrat de stabilité du `TextEditingController` (généralisé, testé de premier ordre).** Le `TextEditingController` interne à `ZEditionField` est créé **exactement une fois** en `initState` et libéré en `dispose` ; il n'est **jamais** recréé au rebuild (compteur d'`initState`/de construction du controller == 1 sur toute la vie du champ, y compris après **N rebuilds structurels** de `DynamicEdition` via `setVisibleFields` réordonnant/rafraîchissant l'ensemble sans retirer le champ). Aucune écriture `_text.text = …` / `_text.value = …` **dans la voie de frappe** (garde textuelle + revue). La voie de frappe demeure **sens unique** `onChanged → controller.setValue(name, v)`.

2. **AC2 — Synchronisation guardée valeur→champ, sans clobber de sélection (FR-1).** Quand la tranche du champ change **de l'extérieur** (`controller.setValue(name, x)` déclenché hors de la frappe locale) :
   - si le champ **n'a PAS le focus** : le `TextField` reflète la nouvelle valeur (`_text.text == '$x'`) — la réflexion externe fonctionne ;
   - si le champ **A le focus** (édition en cours) : la sélection/le curseur et le texte en cours de saisie sont **préservés intacts** — **aucune** ré-injection n'écrase la sélection (FR-1 « la valeur n'est jamais ré-injectée en écrasant la sélection »). La réflexion différée (à la perte de focus) est **acceptable** ; le clobber pendant le focus est **interdit**.
   La garde repose sur un `FocusNode` **stable** détenu par le `State` (créé une fois, `dispose`), non sur un `hashCode` ou une recréation.

3. **AC3 — `AutovalidateMode.onUserInteraction` PAR CHAMP (jamais global).** Chaque champ est rendu par un `TextFormField` **autonome** portant `autovalidateMode: AutovalidateMode.onUserInteraction` ; la validation se déclenche **au niveau du champ** sur interaction utilisateur, **sans** `Form`/`FormBuilder`/`FormBuilderState` global comme source d'état ou déclencheur (AD-2 : « pas de `FormBuilder` global »). Un test prouve qu'aucun `Form` ancêtre n'est requis et qu'invalider un champ **n'affiche pas** d'erreur sur les autres champs (validation **isolée par tranche**).

4. **AC4 — Validateurs MÉMOÏSÉS (identité stable entre builds).** Le `validator` (`FormFieldValidator<String?>`) passé au `TextFormField` est **compilé une seule fois** depuis `field.validators` (liste de `ZValidatorSpec`, E2-4) et **mémoïsé** (`late final` dans le `State`, ou cache partagé keyé sur l'identité de la liste de specs) : son **identité est strictement stable** d'un build à l'autre (`identical(validatorBuild1, validatorBuild2) == true`), il n'est **jamais** recréé dans `build()`. La compilation couvre au moins toutes les familles **locales au champ** de `ZValidatorKind` (`required`, `minLength`, `maxLength`, `min`/`max` littérales, `equal`, `notEqual`, `email`, `url`, `ip`, `creditCard`, `phone`, `numeric`, `integer`, `dateString`, `address`, `percentage`, `password`, `pattern`) ; un champ **sans** validateurs a un `validator == null` (aucune surcharge). `errorText` de chaque `ZValidatorSpec` est propagé comme message.

5. **AC5 — Message d'erreur de validation par champ (affiché & isolé).** Sur un champ portant `ZValidatorSpec.required()` (ou `minLength`), une interaction laissant la valeur invalide fait apparaître le **message d'erreur sous CE champ** (`find.text(errorText)`), tandis qu'un champ voisin valide **n'affiche aucune erreur**. Corriger la valeur fait **disparaître** le message (sur interaction). La validation reste **ciblée** : afficher/effacer l'erreur d'un champ ne reconstruit **que** ce champ (compteur de build voisin inchangé — non-régression SM-1).

6. **AC6 — Curseur AU MILIEU préservé (comble L2 du code-review E3-1) + focus préservé.** Avec un caret placé **au milieu** du texte (offset médian, via IME simulé `tester.testTextInput.updateEditingValue(TextEditingValue(text, selection: collapsed(mid)))`) :
   - **insérer un caractère au caret** insère **à la position médiane** (pas d'append en fin) et le caret avance de 1 en restant dans la zone médiane ; le texte final = insertion au milieu ; `controller.setValue` reçoit le texte médian correct ;
   - **un rebuild externe/structurel** survenant caret-au-milieu **ne réinitialise PAS** la sélection (`_text.selection` inchangée : offset médian conservé), ne recrée pas le `State`/controller, et conserve `focusNode.hasFocus == true`.
   Ce test est distinct du SM-1 d'E3-1 (append-only) et prouve la préservation **médiane** exigée par FR-1.

7. **AC7 — Non-régression SM-1 avec validation active (FR-1 complet).** Sur le formulaire de référence (≥ 30 champs, ≥ 3 sections) **avec `AutovalidateMode.onUserInteraction` et validateurs mémoïsés actifs**, taper 100 caractères dans un champ central :
   - le compteur de build du **champ courant** augmente (le `TextFormField` peut se reconstruire pour (dé)afficher l'erreur — borné à la tranche) ; le compteur de **CHAQUE autre champ** reste **strictement** à sa valeur initiale ; le compteur de **niveau formulaire** reste **inchangé** (zéro rebuild global) ;
   - `focusNode.hasFocus == true` d'un bout à l'autre ; sélection/curseur jamais réinitialisés ;
   - `controller.valueOf(cible)` == les 100 caractères saisis. Les conséquences testables de **FR-1** (aucun `setState` formulaire ; controller créé 1× ; `key` = `ValueKey(name)`) restent vraies.

8. **AC8 — Pureté par couche, dépendance validateurs & vérif verte.** Le compilateur de validateurs (nouveau) vit sous `presentation/edition/` (il tire `package:form_builder_validators` — dépendance **du moteur d'édition** déclarée au Stack de l'architecture, **PAS** un gestionnaire d'état). Conséquences à traiter :
   - `form_builder_validators` ajouté à `packages/zcrud_core/pubspec.yaml` ; **`flutter_form_builder` (widget/état global) N'EST PAS importé** (violerait AD-2) ;
   - la garde `presentation_purity_test.dart` est **étendue** pour whitelister `package:form_builder_validators/` (inflexion additive, comme `material.dart` en E2-8) — elle reste **verte** ; `presentation_purity_test`/`style_purity_test`/`domain_purity_test` verts ;
   - graphe **`CORE OUT=0`** préservé (`form_builder_validators` n'est pas `zcrud_*`) ; **gate de compatibilité E1-4** rejoué **vert** (`form_builder_validators` résout contre le workspace lex_douane) ;
   - les nouveaux types publics (si exposés) sont exportés par le barrel `lib/zcrud_core.dart` (ordre alpha). `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 → `melos run verify` RC=0.

## Tasks / Subtasks

- [x] **Tâche 1 — Compilateur de validateurs mémoïsé (`ZValidatorSpec[] → FormFieldValidator<String?>`) (AC4, AC8)**
  - [x] Créer `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart` : fonction/`class` compilant une `List<ZValidatorSpec>` en un unique `FormFieldValidator<String?>` via `FormBuilderValidators.compose([...])` (form_builder_validators). Mapper **chaque** `ZValidatorKind` local au champ vers le `FormBuilderValidators.*` correspondant, en propageant `errorText`, `length`, `bound`, `value`, `pattern`.
  - [x] Liste **vide** de validateurs ⇒ retourner `null` (aucune surcharge sur le `TextFormField`).
  - [x] Ajouter `form_builder_validators` aux `dependencies` de `packages/zcrud_core/pubspec.yaml` (ne PAS ajouter `flutter_form_builder` — AD-2). Documenter en commentaire : dépendance **moteur d'édition** (Stack), pas un gestionnaire d'état ; CORE OUT=0 préservé (non `zcrud_*`).
  - [x] Décision **validateurs inter-champs** (`ZValidatorKind.min/max` via `refKey`, `match`) : soit compilés en **closures mémoïsées capturant le `controller`** (lisent `controller.valueOf(refKey)` à l'invocation — identité stable, état lu à la volée), soit **déférés** avec un TODO documenté vers E3-6/E3-5 si `form_builder_validators` n'offre pas de variante sans contexte `FormBuilder`. **Trancher explicitement dans les Dev Notes** ; le must-have E3-2 = les validateurs **locaux au champ**.
- [x] **Tâche 2 — `ZEditionField` : contrat de stabilité généralisé + `FocusNode` + sync guardée (AC1, AC2, AC6)**
  - [x] `_ZEditionFieldState` : ajouter un `FocusNode` **stable** (`late final`, créé en `initState`, `dispose`). Le `TextEditingController` reste créé **une fois** (inchangé E3-1).
  - [x] Dans le `builder` du slice (`ZFieldListenableBuilder`), implémenter la **sync guardée** : si `!_focus.hasFocus && _text.text != _stringOf(value)` alors `_text.value = TextEditingValue(text: _stringOf(value), selection: TextSelection.collapsed(offset: len))` ; **jamais** de write-back quand `_focus.hasFocus` (protège la sélection — FR-1/AC2). `_stringOf(null) == ''`.
  - [x] La voie de frappe reste **sens unique** (`onChanged → setValue`) ; **aucun** `.text=` dans `onChanged`.
- [x] **Tâche 3 — Rendu : `TextFormField` autonome + validation ciblée (AC3, AC4, AC5)**
  - [x] Remplacer le `TextField` par un `TextFormField` (toujours **type-agnostique**, un seul rendu — le dispatcher par type reste E3-3a) portant : `controller: _text`, `focusNode: _focus`, `autovalidateMode: AutovalidateMode.onUserInteraction`, `validator: _validator` (mémoïsé), `onChanged: (v) => controller.setValue(name, v)`, `decoration` label.
  - [x] Mémoïser `_validator` en `late final` (compilé une fois depuis `widget.field.validators` en `initState` ou via getter paresseux) — **jamais** recompilé dans `build`.
  - [x] **Aucun** `Form`/`FormBuilder` ancêtre requis ni introduit (AD-2). Insets/aligns **directionnels** si layout ajouté (AD-13).
- [x] **Tâche 4 — Export & barrel (AC8)**
  - [x] Exporter le compilateur de validateurs depuis `lib/zcrud_core.dart` **s'il** fait partie de l'API publique (sinon garder `src/`-privé) — ordre alpha, section présentation.
- [x] **Tâche 5 — Garde de pureté & pubspec (AC8)**
  - [x] Étendre `test/purity/presentation_purity_test.dart` : ajouter `package:form_builder_validators/` à la whitelist d'imports autorisés sous `presentation/` (inflexion additive documentée en en-tête, comme material E2-8). Vérifier que la garde reste **verte** et continue de rejeter les gestionnaires d'état / backends lourds.
  - [x] Rejouer le **gate de compatibilité E1-4** (`dart pub get --dry-run` / script `gate:compat`) : `form_builder_validators` résout contre le workspace lex_douane.
- [x] **Tâche 6 — Test contrat de stabilité (AC1)**
  - [x] `test/presentation/edition/controller_stability_test.dart` : compteur d'`initState`/construction == 1 après **N `setVisibleFields`** (réordonnancement/refresh sans retirer le champ) et après rebuild d'ancêtre ; garde textuelle « pas de `.text=`/`.value=` dans la voie de frappe ».
- [x] **Tâche 7 — Test sync guardée (AC2)**
  - [x] `test/presentation/edition/external_value_sync_test.dart` : (a) champ **non focalisé** + `controller.setValue(name, 'X')` externe ⇒ `find.text('X')` / `_text.text == 'X'` ; (b) champ **focalisé** avec saisie partielle + `setValue` externe ⇒ sélection/curseur **inchangés**, texte en cours **préservé** (aucun clobber). Voisins intacts.
- [x] **Tâche 8 — Test validation ciblée (AC3, AC5)**
  - [x] `test/presentation/edition/field_validation_test.dart` : champ `required` invalidé sur interaction ⇒ `find.text(errorText)` présent **sous ce champ** ; voisin valide ⇒ **aucune** erreur ; correction ⇒ message disparaît ; **aucun** `Form` ancêtre ; compteur de build voisin **inchangé** (validation isolée). Optionnel : `minLength`/`email`.
  - [x] Test d'**identité** du validateur mémoïsé : capturer `_validator` sur deux builds successifs (hook `@visibleForTesting`) ⇒ `identical`.
- [x] **Tâche 9 — Test curseur AU MILIEU (AC6, comble L2)**
  - [x] `test/presentation/edition/mid_cursor_test.dart` : placer le caret au milieu (`updateEditingValue` + `selection: collapsed(mid)`), insérer un caractère au caret ⇒ insertion médiane + caret +1 médian + `valueOf` cohérent ; déclencher un rebuild structurel caret-au-milieu ⇒ sélection **inchangée**, `initState`==1, focus conservé.
- [x] **Tâche 10 — Test non-régression SM-1 avec validation (AC7)**
  - [x] Étendre/ajouter `test/presentation/edition/sm1_with_validation_test.dart` (ou paramétrer le harnais `_reference_form.dart` pour attacher des `ZValidatorSpec` à quelques champs) : 100 frappes sur un champ central **validé** ⇒ voisins inchangés, formulaire inchangé, focus/curseur intacts, valeur finale correcte.
- [x] **Tâche 11 — Vérif verte & gardes (AC8)**
  - [x] `dart run melos run generate` → `analyze` RC=0 → `flutter test` RC=0 → `melos run verify` RC=0 (graph `CORE OUT=0`, gates `melos`/`reflectable`/`secrets`/`codegen`/`compat`/`serialization` verts). Non-régression : E3-1 (`sm1_full_form`/`uj2_external_rebuild`/`dynamic_edition`) + E2-7 (`sm1_granular`) + E2-9 parité ×4 verts.

## Dev Notes

### Ce qu'E3-2 ajoute (et ne refait pas)

E3-1 a déjà prouvé SM-1 plein-format et l'edge UJ-2 avec un controller **minimal** (créé 1×, sens unique, `ValueKey`). E3-2 **n'introduit AUCUN changement** à la machinerie de tranche (`ZFormController`, `ZFieldListenableBuilder`, `DynamicEdition` structurel) — elle est suffisante. E3-2 **enrichit uniquement `ZEditionField`** (+ un compilateur de validateurs) selon deux axes orthogonaux : (1) **stabilité généralisée** (FocusNode stable + sync guardée sans clobber) et (2) **validation ciblée** (TextFormField autonome + validateurs mémoïsés). Le rendu reste **type-agnostique** (un seul `TextFormField`).

### État réel sur disque (fondation à réutiliser, NE PAS réinventer)

- **`ZEditionField`** (`lib/src/presentation/edition/z_edition_field.dart`, E3-1) : `StatefulWidget`, `TextEditingController _text` créé 1× en `initState`, `dispose` ; rendu sous `ZFieldListenableBuilder(controller, name, builder)` ; voie de frappe sens unique `onChanged → setValue` ; hooks `@visibleForTesting` `onInit`/`onBuild`. → E3-2 **modifie ce fichier** : ajoute `FocusNode`, sync guardée dans le `builder`, `_validator` mémoïsé, remplace `TextField`→`TextFormField`. Conserver les hooks (les tests SM-1/UJ-2 d'E3-1 en dépendent) et en ajouter au besoin (ex. exposer `_validator` pour l'assert d'identité).
- **`DynamicEdition`** (`.../edition/dynamic_edition.dart`, E3-1) : observe **uniquement** `controller.visibleFields` ; monte via `ListView.builder` ; pose `ValueKey(name)` sur la voie par défaut `_buildField` ; seam `fieldBuilder`. → **Non modifié** par E3-2 (sauf si un besoin réel émerge — à justifier).
- **`ZFormController`** (`.../presentation/z_form_controller.dart`, E2-7) : `setValue(name, v)` notifie **UNIQUEMENT** la tranche (aucun `notifyListeners()` global) ; `valueOf(name)` ; `visibleFields`/`setVisibleFields` = seul canal structurel global. → E3-2 **consomme** cette API telle quelle (la sync guardée lit `value` fourni par le slice ; les validateurs inter-champs, si retenus, lisent `valueOf(refKey)`). **API E2-7 suffisante** : ne pas la modifier.
- **`ZValidatorSpec`** / **`ZValidatorKind`** (`lib/src/domain/edition/z_validator_spec.dart`, E2-4) : type-valeur `const` pur-données, **aucune closure/exécution**. Sa doc dit explicitement : « La composition en `FormBuilderValidators` … est **E3** — attachée au `ZFormController`, jamais au schéma statique. » → **E3-2 est le lieu** de cette compilation. `ZFieldSpec.validators` (`lib/src/domain/edition/z_field_spec.dart`) porte la liste ; sa doc : « composés en `FormBuilderValidators` par E3 ».
- **Harnais de test** `test/presentation/edition/_reference_form.dart` (E3-1) : fabrique 36 champs / 3 sections, compteurs `fieldBuilds`/`fieldInits`/`formBuilds`, `buildForm()` instrumenté, helpers `useTallSurface`/`editableOf`. → **Réutiliser** ; l'étendre pour attacher des `ZValidatorSpec` à quelques champs (AC7).

### Dépendance `form_builder_validators` — sanctionnée par l'architecture

Le **Stack** de l'architecture (`architecture.md`, tableau technique) liste `flutter_form_builder / form_builder_validators` sous **« (moteur édition) »**, et **AD-2** précise : « `form_builder_validators` sert la composition de validateurs, **jamais l'état** ». C'est donc la cible de compilation **sanctionnée**. Points de vigilance NON-NÉGOCIABLES :
- **N'importer QUE `form_builder_validators`** (validateurs purs = `String? Function(String?)`, tirent `intl`). **NE PAS importer `flutter_form_builder`** : son `FormBuilder`/`FormBuilderState` est un **état de formulaire global** interdit par AD-2 (« pas de `FormBuilder` global comme source d'état »).
- `form_builder_validators` **n'est pas un gestionnaire d'état** et **n'est pas** dans la liste des deps lourdes interdites (Firebase/Syncfusion/Quill/Maps) → conforme à « aucune dépendance lourde ».
- Graphe : `form_builder_validators` n'est pas `zcrud_*` ⇒ **`CORE OUT=0` préservé** (`graph_proof.py` ne compte que les arêtes `zcrud_*`).
- La garde `presentation_purity_test.dart` a une **whitelist stricte** (relatif / `zcrud_core` / `dartz` / `dart:` sûr / flutter foundation·widgets·material). Un import `form_builder_validators` **échouerait** la garde tel quel ⇒ **l'étendre** (ajout additif documenté, précédent : material en E2-8). Sans cette extension, `analyze` passe mais le **test de pureté échoue** — piège à ne pas manquer.
- Rejouer le **gate E1-4** (compat lex_douane) après ajout.

### Conception du contrat de stabilité + sync guardée (AC1, AC2, AC6)

```
_ZEditionFieldState
  late final TextEditingController _text;   // créé 1× (initState), jamais recréé/ré-injecté en voie de frappe
  late final FocusNode _focus;              // créé 1×, dispose ; oracle du "champ a le focus ?"
  late final FormFieldValidator<String?>? _validator;  // compilé 1× depuis field.validators (mémoïsé)

  build → ZFieldListenableBuilder(controller, name, builder: (ctx, value, _) {
            // SYNC GUARDÉE (AC2) : refléter une valeur EXTERNE seulement hors focus,
            // et sans jamais écraser la sélection quand le champ édite.
            final s = value == null ? '' : '$value';
            if (!_focus.hasFocus && _text.text != s) {
              _text.value = TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
            }
            return TextFormField(
              controller: _text, focusNode: _focus,
              autovalidateMode: AutovalidateMode.onUserInteraction,   // PAR CHAMP (AC3)
              validator: _validator,                                   // mémoïsé (AC4)
              onChanged: (v) => controller.setValue(name, v),          // sens unique
            );
          })
```

**Pourquoi la garde `!_focus.hasFocus`** : c'est le point délicat de FR-1. Réfléchir une valeur externe est utile (defaultValue, valeur programmatique) mais si on écrit `_text.value` pendant que l'utilisateur tape, on **écrase la sélection** (caret sauté). La garde autorise la réflexion **uniquement** quand aucun caret n'est en jeu (champ non focalisé). Pendant le focus, priorité **absolue** à la saisie en cours (FR-1). Pendant la **frappe locale**, `onChanged→setValue` met `value == _text.text` ⇒ la condition `_text.text != s` est fausse ⇒ **aucun** write-back (idempotent, pas de boucle).

### Conception du test curseur AU MILIEU (comble L2 — code-review E3-1)

L2 relevait qu'E3-1 ne teste qu'en **append** (l'`enterText` de `flutter_test` recolle la sélection en fin). Ici on prouve la préservation **médiane** :
- **Piège** : `tester.enterText(finder, s)` **remplace tout** le texte et **repositionne** le caret en fin — inutilisable pour prouver « caret médian préservé ». Utiliser l'**IME simulé** : `tester.testTextInput.updateEditingValue(TextEditingValue(text: 'ABCDEF', selection: TextSelection.collapsed(offset: 3)))` pour poser un caret médian, puis un second `updateEditingValue` insérant un caractère à l'offset 3 (`'ABCXDEF'`, caret 4).
- **Asserts** : `_text.selection.baseOffset == 4` (médian, pas 7/fin) ; `controller.valueOf(name) == 'ABCXDEF'` ; après un **rebuild structurel** (`setVisibleFields` réordonnant) déclenché caret-au-milieu ⇒ `_text.selection` **inchangée**, `fieldInits[name] == 1` (State/controller non recréés), `focusNode.hasFocus == true`.

### Conception de la validation ciblée (AC3, AC5) — pas de `Form` global

Un `TextFormField` **autonome** (sans `Form` ancêtre) fonctionne parfaitement avec `AutovalidateMode.onUserInteraction` : le `FormFieldState` interne se (dé)valide **lui-même** à chaque changement de valeur et affiche son `errorText` sous le champ, **sans** dépendre d'un `Form.of(context).validate()`. C'est exactement « validation ciblée par champ, pas globale » (AD-2). La validation **agrégée à la soumission** (`Form.validate()` / valider tous les champs avant `onSubmit`) est **E3-6** — hors périmètre ici. Un test doit vérifier **l'absence** de `Form` ancêtre et l'**isolation** (l'erreur d'un champ n'apparaît pas sur un voisin).

### Frontière E3-2 / E3-3a / E3-6 (décision de découpe)

- **E3-2 (cette story)** : **contrat de stabilité généralisé** (controller 1×/dispose, `FocusNode` stable, sync guardée sans clobber) + **validation CIBLÉE** (`AutovalidateMode.onUserInteraction` par champ, validateurs **mémoïsés** compilés depuis `ZValidatorSpec`) + **préservation focus/curseur médian** (comble L2). Rendu **type-agnostique** (un `TextFormField` uniforme).
- **E3-3a (ensuite)** : **dispatcher par type** (`ZFieldWidget` texte/nombre/date/booléen/select/relation) + **a11y/RTL par-widget** (`Semantics`, ≥ 48 dp, `EdgeInsetsDirectional`/`TextAlign.start`). E3-2 laisse le rendu **neutre** pour qu'E3-3a échange le widget interne **sans** toucher ni la machinerie de tranche, ni le contrat de stabilité, ni la compilation de validateurs (réutilisés par chaque widget-type).
- **E3-6 (plus tard)** : **soumission create/update** — validation **agrégée** avant `onSubmit`, détection **dirty**, états UI (`submit-in-progress`, échec). E3-2 ne fait **que** la validation **par champ à l'interaction** ; il **n'introduit ni** `onSubmit`, **ni** dirty, **ni** validation globale.
- **E3-4** : sections repliables, champs **conditionnels** (`condition`/`setVisibleFields`), mode lecture, grille. E3-2 utilise `setVisibleFields` **uniquement** comme instrument de test (rebuild structurel) ; il n'implémente pas la logique conditionnelle.
- **E3-5** : stepper — sectionne le **même** controller, validation **par étape** via `form_builder_validators`. E3-2 pose la **compilation** de validateurs que E3-5 réutilisera ; il n'implémente pas le stepper.

**Ambiguïté tranchée** — validateurs **inter-champs** (`min/max` via `refKey`, `match`) : dépendent de l'état runtime. Ils **peuvent** être des closures mémoïsées capturant le `controller` (identité stable, lisent `valueOf(refKey)` à l'invocation) ; si `form_builder_validators` n'offre pas de variante sans contexte `FormBuilder`, les **déférer** (TODO documenté) vers E3-6/E3-5. Le **must-have E3-2** = les validateurs **locaux au champ**. **Trancher et documenter dans la PR.**

### a11y / RTL en E3-2

L'a11y/RTL **par-widget** (`Semantics`, ≥ 48 dp) est portée par **E3-3a**. E3-2 ne doit **pas** introduire de régression : tout layout ajouté utilise les variantes **directionnelles** (`EdgeInsetsDirectional`, `TextAlign.start/end`) — jamais `left/right` (AD-13, `style_purity_test`). Rester minimal.

### Project Structure Notes

- Modifié : `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart` (FocusNode + sync guardée + `TextFormField` + `_validator` mémoïsé).
- Nouveau : `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart`.
- Modifié : `packages/zcrud_core/pubspec.yaml` (ajout `form_builder_validators`) ; `packages/zcrud_core/test/purity/presentation_purity_test.dart` (whitelist additive) ; éventuellement `lib/zcrud_core.dart` (export si public) ; `test/presentation/edition/_reference_form.dart` (specs avec validateurs pour AC7).
- Nouveaux tests sous `test/presentation/edition/` : `controller_stability_test.dart`, `external_value_sync_test.dart`, `field_validation_test.dart`, `mid_cursor_test.dart`, `sm1_with_validation_test.dart`.
- **Aucune** modification attendue de `z_form_controller.dart`, `z_field_listenable_builder.dart`, `dynamic_edition.dart` (API/machinerie E2-7/E3-1 suffisantes). Toute modification réelle doit être **justifiée** (extension additive, sans casser E3-1/E2-7).
- **Variance** : le `TextFormField` autonome (sans `Form`) est un choix délibéré (AD-2) ; documenter que la validation agrégée arrive en E3-6 avec un `Form` scoping les champs à la soumission (sans devenir source d'état).

### Testing standards

- Framework : `flutter_test` (`WidgetTester`, `pump`, `find`, `FocusNode`, `tester.testTextInput.updateEditingValue`, `TextSelection`). `zcrud_core` est un package Flutter (tests présentation sous `flutter test`).
- Compteurs de build : patron `_reference_form.dart` (E3-1) / `sm1_granular_rebuild_test.dart` (E2-7). Réutiliser `useTallSurface`/`editableOf`.
- Gardes à garder **vertes** : `presentation_purity_test.dart` (après extension whitelist), `style_purity_test.dart`, `domain_purity_test.dart`.
- Vérif verte = `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 → `melos run verify` RC=0 (dont `gate:compat` après ajout de `form_builder_validators`).

### References

- [Source: epics.md#E3 Story E3-2] — AC : `TextEditingController` créé une fois (create/dispose), jamais recréé ni ré-injecté ; `ValueKey(field.name)` ; `AutovalidateMode.onUserInteraction` ; validateurs mémoïsés ; focus/curseur préservés (FR-1).
- [Source: epics.md#E3 Stories E3-1/E3-3a/E3-6] — frontière : E3-1 (mécanisme de tranche + SM-1 + UJ-2) ; E3-3a (dispatcher par type + a11y/RTL) ; E3-6 (soumission/dirty/validation agrégée).
- [Source: architecture.md#AD-2] — controller stable (create/dispose), `ValueKey(field.name)`, **validateurs mémoïsés**, `AutovalidateMode.onUserInteraction` **par champ** ; interdits : `setState` formulaire, recréation `TextEditingController`, **ré-injection de la valeur** ; « `form_builder_validators` sert la composition de validateurs, **jamais l'état** ; pas de `FormBuilder` global ».
- [Source: architecture.md#Stack] — `flutter_form_builder / form_builder_validators` sous « (moteur édition) » : dépendance sanctionnée du moteur d'édition.
- [Source: architecture.md#AD-15/AD-6] — aucun gestionnaire d'état dans `zcrud_core` ; accès via `ZcrudScope`/binding.
- [Source: architecture.md#AD-14] — pureté par couche : `presentation/` autorise Flutter ; `domain/` pur-Dart.
- [Source: architecture.md#AD-13] — RTL/a11y : variantes directionnelles (a11y par-widget en E3-3a).
- [Source: prd.md#FR-1] — édition sans rebuild global : aucun `setState` formulaire ; **focus + position du curseur préservés à chaque frappe** ; `TextEditingController` créé 1× (initState/dispose), jamais recréé, **valeur jamais ré-injectée en écrasant la sélection** ; `key` stable `ValueKey(field.name)` (jamais `hashCode`).
- [Source: story e3-1-rendu-champ-tranche.md] — fondation : `ZEditionField`/`DynamicEdition`, sens unique `onChanged→setValue`, `ValueKey`, harnais `_reference_form.dart` ; frontière assignant explicitement à E3-2 : `AutovalidateMode`, validateurs mémoïsés, préservation curseur sous rebuild « comme contrat de premier ordre ».
- [Source: code-review-e3-1.md#L2] — trou de couverture : curseur au **milieu** du texte non testé (append-only) — **déféré à E3-2**, comblé ici (AC6).
- [Source: code z_edition_field.dart / z_form_controller.dart / z_field_listenable_builder.dart / z_validator_spec.dart / z_field_spec.dart / _reference_form.dart / presentation_purity_test.dart] — API et gardes réellement sur disque (lues, non supposées).
- [Source: CLAUDE.md#Réactivité Flutter-native + Key Don'ts] — controller stable, `ValueKey`, validateurs mémoïsés, `AutovalidateMode.onUserInteraction` par champ ; jamais de ré-injection écrasant la sélection ; jamais de gestionnaire d'état dans le cœur.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `dart pub get` (racine, lockfile partagé unique) → RC=0 ; `form_builder_validators` **11.3.0** résolu (intl 0.20.2). `flutter_form_builder` **NON** tiré.
- `dart analyze .` (zcrud_core) → RC=0, « No issues found! ».
- `melos run analyze` (14 packages) → SUCCESS (RC=0).
- `melos run generate` → SUCCESS (build_runner, RC=0).
- `melos run gate:compat` → OK (voie manifeste verte, analyzer 8.4.1 ; workspace lex_douane SKIP propre). RC=0.
- `melos run verify` → RC=0 (graph acyclique + CORE OUT=0, gate:melos, gate:reflectable, gate:secrets, gate:codegen, gate:compat, verify:serialization tous verts).
- `graph_proof.py` → `out-degree(zcrud_core)=0`, `ACYCLIQUE OK`, `CORE OUT=0 OK` ; `melos list` = **14**.
- `melos run test` → RC=0. **335 tests** verts : dart (zcrud_annotations 8 + zcrud_generator 80) + flutter (zcrud_core **214**, zcrud_get 17, zcrud_riverpod 8, zcrud_provider 8).
- Régression E3-1/E2-7/E2-9 : `sm1_full_form`, `uj2_external_rebuild`, `dynamic_edition` verts ; parité bindings ×4 vertes.

##### Remédiation code-review — MEDIUM-1 (couverture sémantique du compilateur), 2026-07-09

- **Correctif = ajout de COUVERTURE, comportement du compilateur INCHANGÉ.** Nouveau test pur `test/presentation/edition/z_validator_compiler_test.dart` (`flutter_test`, invoque directement le `String? Function(String?)`, sans widget) : **+26 tests**, tous verts au 1er run — **aucun bug de mapping découvert**.
- **20 familles `ZValidatorKind` exercées sémantiquement** (valide→`null` ET invalide→message `errorText` propagé) : `required`, `minLength`, `maxLength`, `min`(littéral), `max`(littéral), `equal`, `notEqual`, `email`, `url`, `ip`, `creditCard`(Luhn), `phone`→`phoneNumber`, `numeric`, `integer`, `dateString`→`date`, `address`→`street`, `percentage`→`between(0,100)` (bornes 0/100 incluses testées), `password`, `pattern`→`match(RegExp)`. `errorText` toujours fourni explicitement → aucune dépendance à `FormBuilderLocalizations.current` et propagation asservie.
- **Liste vide** ⇒ `compile([]) == null` (aucune surcharge). **Validateur unique** ⇒ renvoyé tel quel, fonctionnel. **Composition** (`compose`) : `[required, minLength(3)]` → `''`→`REQUIS` (1re erreur), `'ab'`→`COURT` (2e), `'abcd'`→`null` (ordre préservé).
- **Inter-champs DÉFÉRÉS (E3-5/E3-6) ignorés silencieusement (branche null-guardée `refKey`/`bound==null`)** : `compile([minKey])`/`compile([maxKey])`/`compile([match])` ⇒ `null` ; `[required, minKey]` ⇒ seul `required` subsiste (déféré absorbé). Le test **reflète** le comportement réel actuel (LOW-1) sans le modifier.
- **Vérif verte rejouée réellement** : `melos run analyze` RC=0 ; `melos run test` RC=0 (**zcrud_core 214 → 240**, total workspace **335 → 361**) ; `melos run verify` RC=0 ; `gate:compat` RC=0 ; `prove_gates` **22 OK / 0 FAIL** (inchangé) ; `graph_proof` `CORE OUT=0 OK` + acyclique ; `melos list`=**14** ; 0 `.g.dart` committé. Non-régression E3-1/E3-2 (SM-1/UJ-2, sync guardée, curseur médian) + E2-7/E2-9 confirmée.
- **LOW-1/2/3 : déférés/hors périmètre** (consignés au code-review) — non traités ici.

#### Incident de test (résolu, hors défaut produit)

Premier run : 3 tests rouges (`controller_stability`, `mid_cursor` post-rebuild, identité validateur). Cause : le rebuild structurel de test réordonnait `visibleFields` par **rotation complète** (déplacement lointain de la cible) → `ListView.builder` **recycle** l'état hors cache-extent et remonte le champ (`initState`==2, sélection perdue, `_validator` recompilé). Ce n'est **pas** un défaut de `ZEditionField` (le contrat AD-2 vise « rebuild ⇒ pas de recréation », pas le recyclage de viewport). Correctif : les tests déclenchent désormais un rebuild structurel **réel** par **permutation des deux derniers champs** (loin de la cible), qui laisse la cible en place → `initState`==1, curseur médian et identité du validateur préservés. Invariant testé isolé du comportement de virtualisation de `ListView`.

### Completion Notes List

- **Compilateur mémoïsable** `ZValidatorCompiler.compile(List<ZValidatorSpec>) → FormFieldValidator<String>?` (`lib/src/presentation/edition/z_validator_compiler.dart`, `abstract final class` sans état) : `null` si liste vide/aucun validateur champ-local ; 1 validateur → renvoyé tel quel ; N → `FormBuilderValidators.compose<String>`. Mappe toutes les familles **champ-locales** de `ZValidatorKind` (`required/minLength/maxLength/min/max` littérales`/equal/notEqual/email/url/ip/creditCard/phone→phoneNumber/numeric/integer/dateString→date/address→street/percentage→between(0,100)/password/pattern→match(RegExp)`), `errorText` propagé. Exporté par le barrel (API publique, réutilisée E3-5).
- **Décision validateurs inter-champs (tranchée + documentée)** : `min/max` **référencés** (`refKey`) et `match` (égalité à un autre champ) dépendent de l'**état runtime d'un autre champ** ⇒ **DÉFÉRÉS à E3-5/E3-6** (closures mémoïsées capturant le `ZFormController`). Le compilateur les **ignore** (aucun validateur produit). Le must-have E3-2 = validateurs **champ-locaux**, livrés. Documenté dans l'en-tête du compilateur et le `switch`.
- **`ZEditionField` généralisé** : `FocusNode _focus` stable (`late final`, `dispose`) ; `_validator` **mémoïsé** (`late final`, compilé 1× en `initState`, identité stable prouvée `identical`) ; **sync guardée** dans le `builder` de tranche : write-back `_text.value` UNIQUEMENT si `!_focus.hasFocus && _text.text != s` (jamais pendant l'édition → sélection/curseur protégés, FR-1 ; idempotent pendant la frappe). Rendu passé de `TextField` à **`TextFormField` autonome** (aucun `Form` ancêtre) + `AutovalidateMode.onUserInteraction` par champ. Voie de frappe inchangée (sens unique `onChanged→setValue` ; aucun `.text=`).
- **Dépendance** : `form_builder_validators: ^11.0.0` ajouté aux `dependencies` de `zcrud_core` (commentaire : moteur d'édition, PAS un gestionnaire d'état ; CORE OUT=0 préservé). `flutter_form_builder` **jamais** importé.
- **Garde de pureté étendue** (inflexion **additive**, précédent material E2-8) : `presentation_purity_test.dart` whiteliste `package:form_builder_validators/` ET ajoute `package:flutter_form_builder` à la liste des **interdits** — prouve que `form_builder_validators` passe alors que `flutter_form_builder`/cupertino/services/dart:ui-direct/managers restent rejetés. Garde verte.
- **Preuves testées** : controller/State créés 1× (`initState`==1 après N rebuilds structurels, `TextEditingController` identique) ; sync externe hors-focus reflétée / focus → aucun clobber (texte+sélection préservés, voisins intacts) ; validation `onUserInteraction` par champ (message sous CE champ, voisin sans erreur, aucun `Form` ancêtre, correction → disparition, voisin non reconstruit) ; identité du `_validator` stable entre builds (tranche + structurel) ; champ sans validateur → `validator==null` ; **curseur AU MILIEU** (comble L2) préservé à l'insertion médiane ET sous rebuild structurel (`initState`==1, focus gardé) ; SM-1 avec validation active (100 frappes, voisins+formulaire inchangés, focus/curseur intacts, valeur correcte).

### File List

**Créés :**
- `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart`
- `packages/zcrud_core/test/presentation/edition/controller_stability_test.dart`
- `packages/zcrud_core/test/presentation/edition/external_value_sync_test.dart`
- `packages/zcrud_core/test/presentation/edition/field_validation_test.dart`
- `packages/zcrud_core/test/presentation/edition/mid_cursor_test.dart`
- `packages/zcrud_core/test/presentation/edition/sm1_with_validation_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_validator_compiler_test.dart` (remédiation MEDIUM-1 : couverture sémantique des 20 familles + vide/composition/inter-champs déférés)

**Modifiés :**
- `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart` (FocusNode stable + sync guardée + `_validator` mémoïsé + `TextFormField` autonome)
- `packages/zcrud_core/lib/zcrud_core.dart` (export `z_validator_compiler.dart`)
- `packages/zcrud_core/pubspec.yaml` (dépendance `form_builder_validators: ^11.0.0`)
- `packages/zcrud_core/test/purity/presentation_purity_test.dart` (whitelist additive `form_builder_validators/` ; interdit `flutter_form_builder`)
- `packages/zcrud_core/test/presentation/edition/_reference_form.dart` (param `validatorsByField` pour AC7)
- `pubspec.lock` (racine, résolution partagée — non committé par package)

### Change Log

- 2026-07-09 — E3-2 : contrat de stabilité généralisé (FocusNode stable, sync guardée sans clobber) + validation ciblée (`TextFormField` autonome, `AutovalidateMode.onUserInteraction` par champ, validateurs mémoïsés via `ZValidatorCompiler`/`form_builder_validators`) + comble L2 (curseur médian). Status → review.
- 2026-07-09 — Remédiation code-review **MEDIUM-1** : ajout `z_validator_compiler_test.dart` (+26 tests, 20 familles couvertes sémantiquement + vide/composition/inter-champs déférés), 0 bug de mapping, comportement compilateur inchangé. Vérif verte rejouée (analyze/test/verify/compat RC=0, CORE OUT=0, melos list=14). Status reste **review**.
