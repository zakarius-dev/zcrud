# Étude d'intégration — `flutter_form_builder` ^10.2 + `form_builder_validators` ^11.2

Lentille : réutilisation des packages de rendu de formulaire DODLP dans zcrud.
Repo DODLP (lecture seule) : `/home/zakarius/DEV/dodlp-otr`, module `lib/modules/data_crud/`.
Repo zcrud (référence, lecture seule pour ce rapport — aucune écriture) : `/home/zakarius/DEV/zcrud`.

**Résumé exécutif** : les deux packages sont dans `dodlp-otr/pubspec.yaml:86-87`
(`flutter_form_builder: ^10.2.0`, `form_builder_validators: ^11.2.0`). L'analyse du
code réel montre que DODLP **n'utilise `flutter_form_builder` que comme
orchestrateur de cycle de vie** (`validate()`/`save()`/`reset()`/`isDirty`) — **jamais**
comme source de vérité des valeurs (aucun `_form.currentState?.value` dans tout
`edition_screen.dart`, cf. grep §2.3). Le bug historique de rebuild global vient
d'un `setState(() {})` que **DODLP lui-même** appelle à l'échelle de l'écran dans
**chaque** callback `onChanged`/`onToggle`/`onTap` de champ — pas de l'`InheritedWidget`
de `FormBuilder`. Et surtout : **`zcrud_core` a déjà tranché et implémenté cette
étude** — `form_builder_validators` est une dépendance actuelle de `zcrud_core`
(`packages/zcrud_core/pubspec.yaml:48`), utilisée en fonctions pures dans
`ZValidatorCompiler`/`ZCrossFieldValidator`, avec un commentaire qui interdit
explicitement `flutter_form_builder` pour la même raison développée ici. La
proposition d'intégration de ce rapport **confirme et documente une décision déjà
prise et implémentée**, plutôt que d'en proposer une nouvelle.

---

## 1. Comment DODLP monte le formulaire

### 1.1 Le `FormBuilder` racine

`presentation/views/edition_screen.dart:206-242` :
```dart
class DynamicEditionScreenState<T> extends State<DynamicEditionScreen<T>>
    with DodlpMixin {
  ...
  late GlobalKey<FormBuilderState> _form;
  ...
  void initState() {
    ...
    _form = widget.formKey ?? GlobalKey<FormBuilderState>();
    ...
  }
```

Le `FormBuilder` lui-même n'est monté qu'**une seule fois**, en bas de l'arbre,
à `edition_screen.dart:4189-4212` :
```dart
child: FormBuilder(
  key: _form,
  initialValue: item,
  child: Column(
    children: <Widget>[const SizedBox(height: 8)] +
        widget.formFields.map((field) { ... _buildFormField(field) ... }).toList(),
  ),
),
```
Pas d'`onChanged` au niveau du `FormBuilder`, pas d'`autovalidateMode` explicite
au niveau racine (grep `autovalidateMode|onChanged:` sur tout le fichier →
seulement des `onChanged:` **locaux à chaque widget de champ**, jamais sur
`FormBuilder` lui-même — cf. §2.3). `initialValue: item` amorce
`FormBuilderState._initialValue` (utilisé par `reset()`), mais n'est **jamais
relu** pour peupler des champs qui, comme on le voit en §1.3, gèrent leur
propre valeur via le `Map item` mutable de l'écran.

### 1.2 Usage de `_form.currentState` : cycle de vie, jamais les valeurs

Grep exhaustif `_form.currentState|saveAndValidate|\.save\(\)|\.validate\(\)|\.reset\(\)|isDirty` sur
`edition_screen.dart` → 5 occurrences, toutes en dehors de `_buildFormField` :

| Ligne | Usage |
|---|---|
| `edition_screen.dart:249` | `_form.currentState?.save();` (dans `_onWillPop`, avant de comparer un fingerprint) |
| `edition_screen.dart:254` | `_form.currentState?.isDirty ?? false` (détection de sortie sans sauvegarde, **combinée** à un fingerprint JSON maison — commentaire l.218-219 : *"détecter aussi les modifications faites hors des champs FormBuilder... que FormBuilderState.isDirty ignore"* → DODLP **ne fait déjà pas confiance** à `isDirty` seul) |
| `edition_screen.dart:319` | `if (_form.currentState == null) return;` (garde dans `validateForm`) |
| `edition_screen.dart:322` | `if (_form.currentState?.validate() ?? false) { ... }` (déclenche la validation de TOUS les champs enregistrés au submit) |
| `edition_screen.dart:325` | `_form.currentState?.reset();` (après soumission réussie) |

**Grep négatif décisif** — aucune lecture de valeur via `FormBuilderState` :
```
grep -n "_form.currentState?.value\|currentState!.value\|\.fields\[" \
  lib/modules/data_crud/presentation/views/edition_screen.dart
```
→ **0 résultat** (RC de grep = 1, aucune ligne). Confirmé aussi en 2ème passe
lors de la relecture ci-dessus. Les valeurs de formulaire ne transitent **jamais**
par `FormBuilderState.value` — DODLP maintient son propre état (`Map<String,
dynamic> item` + `Map<String, dynamic> editionState`, tous deux des champs
mutables de `DynamicEditionScreenState`, `edition_screen.dart:208-209`).

### 1.3 Le vrai mécanisme de propagation : `setState()` à l'échelle de l'écran

Chaque widget de champ, quel que soit son type, suit le même patron : lire
`item[fieldName]`, construire un callback qui (1) mute `item`/`editionState`
via `invokeItemSetter`, (2) appelle le hook `field.onChange?.call(...)`, (3)
**`setState(() {})`** sur `DynamicEditionScreenState` — c'est-à-dire l'écran
**entier**. Exemples avec `file:line` :

| Type de champ | Callback | `setState` |
|---|---|---|
| Texte (`FormBuilderTextField`) | `_onSubmit` | `edition_screen.dart:1114` |
| Booléen (`FlutterSwitch.onToggle`) | inline | `edition_screen.dart:1657` |
| `rowChips` (`RawChip.onPressed`) | inline | `edition_screen.dart:3357` (bloc 3314-3372) |
| `dateTime`/`timestamp` (`FormBuilderDateTimePicker.onChanged`) | inline | `edition_screen.dart:3663` |
| `time` (`onTap` du `showTimePicker`) | inline | `edition_screen.dart:3634` |
| Reset d'un select (bouton "Réinitialiser") | inline | `edition_screen.dart:2692` (via `Get.back()` puis `setState`) |
| Select multiple (`SmartSelect.multiple.onChange`) | inline | `edition_screen.dart:3059-3060` (avec un `Future.delayed(300ms)` avant le `setState`, signe explicite d'un contournement de jank connu) |

C'est **exactement** le patron proscrit par AD-2/AD-15 (`CLAUDE.md` — *"Interdits
: setState à l'échelle du formulaire"*) : `_buildFormField` est appelé dans le
`build()` de `DynamicEditionScreenState`, donc un `setState(() {})` déclenché
par la frappe d'un seul caractère dans **un** champ reconstruit **tous** les
champs du formulaire (tout `widget.formFields.map(...)` est ré-exécuté). Que
`FormBuilderTextField` préserve ou non le focus dépend alors uniquement de la
stabilité de l'`Element` Flutter sous-jacent (clé + position dans l'arbre,
`controller` externe stable) — le `Future.delayed(300ms)` avant `setState` en
`edition_screen.dart:3057-3060` est un indice concret d'un contournement de
jank déjà constaté empiriquement par l'équipe DODLP.

**Conclusion clé** : le bug historique n'est PAS intrinsèque à
`flutter_form_builder` (dont l'état interne, `FormBuilderState`, n'est même pas
consulté pour les valeurs) — il vient de la façon dont DODLP **encapsule**
chaque champ dans le `setState()` de l'écran hôte. `zcrud_core` corrige ce point
précis avec `ZFormController` (`ValueNotifier` par tranche) + `ZFieldWidget`/
`ZFieldListenableBuilder` (rebuild borné à la tranche), **indépendamment** du
sort réservé à `flutter_form_builder`.

---

## 2. Cartographie DODLP : type de champ → widget utilisé

Grep de référence : `grep -n "case EditionFieldTypes\." edition_screen.dart`
(37 `case`) croisé avec `grep -n "FormBuilder" edition_screen.dart` (33
occurrences, listées exhaustivement ci-dessous par ligne).

| `EditionFieldTypes` DODLP | Widget réellement rendu | `file:line` | Utilise `flutter_form_builder` ? |
|---|---|---|---|
| `text` / `number` / `integer` / `float` | `FormBuilderTextField` (+ variante `_buildLargeCard`, + `Autocomplete` si `suggestions`) | `edition_screen.dart:1118` (standard), `:1172` (large card), `:1262` (avec autocomplete) | **Oui** — seul usage "pur" du widget `FormBuilderTextField` |
| `boolean` | `FlutterSwitch` (package `flutter_switch`, PAS FormBuilder) | `edition_screen.dart:1629` | Non |
| `select` / `crudDataSelect` / `radio` | `SmartSelect<T>.single`/`.multiple` (package **`awesome_select`**, alias `SmartSelect`/`S2Choice`/`S2State`) ; `FormBuilderCheckboxGroup`/`FormBuilderChoiceChips` n'apparaissent qu'en **stub décoratif**, `options: List.empty()` — la sélection réelle est gérée par `awesome_select`, pas par le widget FormBuilder | `edition_screen.dart:2488-3320` (bloc entier) ; stubs à `:2916` (`FormBuilderCheckboxGroup`) et `:3083` (`FormBuilderChoiceChips`) | **Partiellement/cosmétique** — le widget FormBuilder n'est PAS la source d'interaction |
| `rowChips` | `Wrap`/`RawChip` maison (aucun FormBuilder) | `edition_screen.dart:3314-3372` | Non |
| `tags` | `Tags`/`ItemTags` (package `flutter_tags_x` ou équivalent) | `edition_screen.dart:2100-2160+` | Non |
| `dateTime` / `timestamp` | `FormBuilderDateTimePicker` | `edition_screen.dart:3601` | **Oui** |
| `time` | `FormBuilderTextField` en lecture seule + `showTimePicker` natif Flutter au `onTap` | `edition_screen.dart:3462` | **Oui** (juste comme habillage de champ texte, pas de widget dédié) |
| `widget` | closure libre hôte (`field.widget?.call(...)`), avec un cas spécial si le widget retourné `is FormBuilderField` (readOnly) | `edition_screen.dart:3719-3730` | Conditionnel (dépend du champ custom fourni par l'app) |
| `address`/`addressSearchField` | `FormBuilderTextField` (bloc dédié) | `edition_screen.dart:1530` (`addressField`) | **Oui** |
| tous types texte | validateurs | `FormBuilderValidators.compose(_validators)` à `edition_screen.dart:1158, 1215, 1407, 1567, 2441, 3966` | **Oui** (`form_builder_validators`) |

**Formulaires "simples" hors dispatcher principal** — `presentation/views/edition_forms.dart:143-145` :
```dart
: FormBuilderTextField(
    ...
    validator: FormBuilderValidators.required(),
```
Seul usage de `flutter_form_builder` dans ce fichier (282 lignes), pour un
formulaire ad hoc hors `DynamicEditionScreen`.

### 2.1 Le vrai "moteur de sélection" de DODLP n'est pas `flutter_form_builder`

`import 'package:awesome_select/awesome_select.dart';` — `edition_screen.dart:22`
(seul import lié à la sélection ; grep `smart_select` sur `pubspec.yaml` → 0
résultat, le package est distribué sous le nom `awesome_select`, déclaré en
dépendance git à `pubspec.yaml:95-97`). Tous les champs à choix (`select`,
`radio`, `crudDataSelect`, une partie de `rowChips`, `checkbox`-group visuel)
passent par `SmartSelect`/`S2Choice`/`S2State` de ce package tiers — **hors
scope de la présente lentille**, mais à signaler pour l'équipe qui étudiera la
parité `select`/`radio`/`relation` : ce n'est **pas** `flutter_form_builder`
qui porte l'UI de sélection DODLP.

### 2.2 Validateurs `form_builder_validators` — dispatch DODLP complet

`edition_screen.dart:607-759` (fonction `validators<R>()`, appelée pour chaque
champ à partir de `field.validators` — une `Map<String,dynamic>` déclarative) :

| Clé DODLP | Fonction `form_builder_validators` | `file:line` |
|---|---|---|
| `required` | `FormBuilderValidators.required<R>()` | `:624` |
| `minLength` | `FormBuilderValidators.minLength` | `:628` |
| `maxLength` | `FormBuilderValidators.maxLength` | `:632` |
| `max` | `FormBuilderValidators.max<R>` | `:640` |
| `min` | `FormBuilderValidators.min<R>` | `:650` |
| `equal` | `FormBuilderValidators.equal<R>` | `:656` |
| `notEqual` | `FormBuilderValidators.notEqual<R>` | `:658` |
| `match` | `FormBuilderValidators.match(value)` | `:660` |
| `matchKey` | `FormBuilderValidators.match(RegExp(item[value]))` (inter-champs, résolu via `item`) | `:662` |
| `email` | `FormBuilderValidators.email()` | `:667` |
| `url` | `FormBuilderValidators.url()` | `:670` |
| `ip` | `FormBuilderValidators.ip()` | `:672` |
| `creditCard` | `FormBuilderValidators.creditCard()` | `:674` |
| `tgPhoneNumber` | validateur **maison** (regex préfixes Togo), pas `form_builder_validators` | `:676-700` |
| `numeric` | `FormBuilderValidators.numeric()` | `:703` |
| `integer` | `FormBuilderValidators.integer()` | `:708` |
| `dateString` | `FormBuilderValidators.date()` | `:710` |
| `password` | validateur **maison** (longueur 8-20, ≥1 maj., ≥1 min. — PAS `FormBuilderValidators.password`) | `:721-742` |

### 2.3 Preuve négative — pas de `FormBuilderDropdown`/`Radio`/`Switch`

```
grep -n "FormBuilderDropdown\|FormBuilderCheckbox\b\|FormBuilderRadio\|FormBuilderSwitch\|FormBuilderSlider\|FormBuilderRangeSlider\|FormBuilderSearchableDropdown\|FormBuilderTypeAhead\|FormBuilderSegmentedControl" \
  lib/modules/data_crud/presentation/views/edition_screen.dart
```
→ **0 résultat**. Seuls widgets FormBuilder réellement instanciés dans DODLP :
`FormBuilderTextField`, `FormBuilderDateTimePicker`, `FormBuilderCheckboxGroup`
(stub), `FormBuilderChoiceChips` (stub), plus `FormBuilder` lui-même et
`FormBuilderValidators`/`FormBuilderField`/`FormBuilderFieldOption`/
`FormBuilderChipOption`/`FormBuilderFieldDecorationState` (types utilitaires).

---

## 3. Cible zcrud — l'étude est déjà tranchée dans le code

### 3.1 `form_builder_validators` est déjà une dépendance de `zcrud_core`

`packages/zcrud_core/pubspec.yaml:42-48` :
```yaml
  # `form_builder_validators` (validateurs PURS `String? Function(String?)`,
  # dépend d'`intl`) — JAMAIS `flutter_form_builder` (son `FormBuilder`/
  # ...
  form_builder_validators: ^11.0.0
```
Et `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart`
(en-tête, lignes 12-16) :
> *"On tire UNIQUEMENT `package:form_builder_validators` (validateurs PURS,
> `String? Function(String?)`). JAMAIS `flutter_form_builder` : son
> `FormBuilder`/`FormBuilderState` serait un ÉTAT de formulaire global,
> interdit."*

C'est **verbatim l'option (a)** de la question posée à cette lentille — déjà
implémentée, pas seulement proposée.

### 3.2 Parité de couverture — `ZValidatorCompiler`/`ZCrossFieldValidator` vs DODLP

`ZValidatorCompiler._compileOne` (`z_validator_compiler.dart:63-149`) couvre,
avec les mêmes fonctions `FormBuilderValidators.*` que DODLP :
`required, minLength, maxLength, min, max, equal, notEqual, email, url, ip,
creditCard, phone, numeric, integer, dateString(date), address(street),
percentage(between), password, pattern(match)`.

Écarts notés, tous **documentés et volontaires** dans le code source (pas des
trous silencieux) :
- `ZValidatorKind.match` (référence à un autre champ, `matchKey` côté DODLP)
  est **déféré** par `ZValidatorCompiler` (retourne `null`, commentaire
  l.20-26) vers `ZCrossFieldValidator` (`z_cross_field_validator.dart`) —
  closures mémoïsées capturant `ZFormController`, relecture ciblée via
  `fieldListenable(refKey)` (AD-2, `z_cross_field_validator.dart:11-19`).
  Fonctionnellement équivalent à `matchKey`/`min`/`max` inter-champs de DODLP,
  en préservant le rebuild granulaire (DODLP, lui, relit `item[value]`
  directement sans passer par un mécanisme réactif dédié).
- `password` : `ZValidatorCompiler` utilise
  `FormBuilderValidators.password(minLength: 8, maxLength: 20,
  minUppercaseCount: 1, minLowercaseCount: 1, minNumberCount: 0,
  minSpecialCharCount: 0, checkNullOrEmpty: false)`
  (`z_validator_compiler.dart:132-143`) — paramétrage **choisi pour reproduire
  exactement** le validateur maison DODLP (8-20 caractères, ≥1 maj., ≥1 min.,
  pas de chiffre/spécial requis — comparer à `edition_screen.dart:721-742`).
  Le commentaire du fichier le dit explicitement : *"défaut aligné DODLP
  (permissif)"*.
- `tgPhoneNumber` (validateur régional Togo, `edition_screen.dart:676-700`)
  n'a pas d'équivalent `ZValidatorKind` dédié — attendu, car côté zcrud le
  numéro de téléphone international est un **type de champ** (`phoneNumber`,
  `EditionFieldType.phoneNumber`) porté par `zcrud_intl` (E11a), pas un
  validateur de texte générique.

### 3.3 `flutter_form_builder` — CORE OUT=0, confirmé par grep

```
grep -rn "flutter_form_builder" packages/*/pubspec.yaml
```
→ 1 seule occurrence, dans un **commentaire** (`zcrud_core/pubspec.yaml:43`),
jamais en dépendance déclarée. Aucun package zcrud ne dépend de
`flutter_form_builder`. AD-1 (CORE OUT=0 pour les packages lourds) et l'objectif
n°1 (AD-2/AD-15) sont donc déjà respectés sur ce point précis.

### 3.4 Les widgets `FormBuilder*` ne sont pas nécessaires : le cœur a déjà ses propres familles

`packages/zcrud_core/lib/src/presentation/edition/families/` contient déjà des
implémentations natives, **stateless**, pilotées par `TextEditingController`/
`FocusNode` **stables détenus par l'hôte** (`ZFieldWidget`), pour la quasi-
totalité du catalogue `EditionFieldType` : `z_text_field_widget.dart` (text/
multiline/password — `TextFormField` nu, **aucun** `Form` ancêtre, cf. en-tête
"Rendu d'un TextFormField autonome (aucun Form global — AD-2)"),
`z_number_field_widget.dart`, `z_boolean_field_widget.dart`,
`z_date_field_widget.dart`, `z_select_field_widget.dart`,
`z_row_chips_field_widget.dart`, `z_tags_field_widget.dart`,
`z_rating_field_widget.dart`, `z_slider_field_widget.dart`,
`z_color_field_widget.dart`, `z_signature_field_widget.dart`,
`z_app_file_field_widget.dart`, `z_relation_field_widget.dart`
(couvre `crudDataSelect`), `z_sub_list_field_widget.dart`,
`z_dynamic_item_field_widget.dart`, `z_free_widget_field_widget.dart`.

Autrement dit : le seam `ZWidgetRegistry` (`z_widget_registry.dart`) reste
disponible pour un `kind` dont le widget "vit ailleurs" (markdown/E6, géo/
tél/E11a, `custom`) — mais **aucun de ces types cibles n'a besoin d'un widget
`FormBuilder***`, puisque zcrud_core a déjà réimplémenté nativement l'exact
équivalent de tout ce que DODLP obtient via `FormBuilderTextField`/
`FormBuilderDateTimePicker`, en respectant directement AD-2 (contrôleur
stable, `ValueNotifier` par tranche, zéro `setState` global) au lieu de
compter sur la préservation accidentelle du focus d'un `Element` Flutter
stable sous un `setState()` parent, comme le fait DODLP aujourd'hui.

---

## 4. Verdict sur la tension d'état AD-2

**La tension existe en théorie mais est déjà neutralisée en pratique côté
zcrud, et n'était de toute façon pas le vrai moteur du bug côté DODLP.**

1. **`FormBuilder`/`FormBuilderState` porte bien un état de formulaire global**
   au sens API (`InheritedWidget` via `_FormBuilderScope`,
   `flutter_form_builder-10.2.0/lib/src/form_builder.dart:113,381`) — mais
   l'analyse de `flutter_form_builder-10.2.0/lib/src/form_builder_field.dart:141-155`
   montre que `FormBuilderField<T> extends FormField<T>` fonctionne **sans**
   ancêtre `FormBuilder` : `_formBuilderState = FormBuilder.of(context)` est
   **nullable**, et chaque accès (`_formBuilderState?.registerField(...)`,
   `_informFormForFieldChange` l.185-189) est gardé par `?.`/`if (... != null)`.
   Techniquement, un `FormBuilderTextField`/`FormBuilderDateTimePicker` **peut
   être monté seul**, hors de tout `FormBuilder`, en simple `FormField` — c'est
   d'ailleurs le patron implicite de DODLP pour ses champs `select`/`radio`
   (`FormBuilderCheckboxGroup`/`FormBuilderChoiceChips` stubs à `options:
   List.empty()`, purement décoratifs, jamais réellement pilotés par
   `FormBuilderState`).
2. **Le bug historique n'est pas causé par cet `InheritedWidget`** — DODLP
   n'appelle jamais `.value`/`.fields[...]` de `FormBuilderState` (§1.2), et le
   `setState()` réel qui reconstruit tout l'écran à chaque frappe est **du code
   applicatif DODLP**, pas du framework `flutter_form_builder` (§1.3).
3. **`zcrud_core` a choisi et implémenté l'option (a)** : `form_builder_validators`
   seul (fonctions pures `String? Function(String?)`, aucun `Widget`, aucun
   état) est adopté comme dépendance de `zcrud_core`, avec interdiction
   explicite en commentaire de `flutter_form_builder`. C'est l'option **sans
   risque** vis-à-vis d'AD-2 : aucune surface d'état à neutraliser.
4. **Les options (b)/(c)** (widgets `FormBuilder*` pilotés par une tranche, ou
   confinés dans un adaptateur DODLP-facing) restent **faisables** — la
   nullabilité de `FormBuilder.of(context)` le permet — mais sont
   **superflues** : `zcrud_core` a déjà toutes les familles de widgets
   nécessaires (§3.4), rendues de façon plus conforme à AD-2 (contrôleur
   stable + `ValueNotifier`/tranche dès la conception) qu'un wrapper autour
   de `FormBuilderField`. Les introduire ajouterait une dépendance lourde à
   `zcrud_core` (violerait AD-1, CORE OUT=0) pour un gain nul en couverture de
   type et un gain incertain en parité visuelle (DODLP lui-même n'utilise
   `FormBuilderTextField`/`FormBuilderDateTimePicker` qu'avec sa propre
   `InputDecoration`/thème custom — reproductible directement dans
   `ZTextFieldWidget`/`ZDateFieldWidget` sans dépendance).

**Conclusion** : ne rien changer sur ce point. Le placement correct de
`form_builder_validators` (fonctions pures, dans `zcrud_core`, jamais de
widget) est déjà en place et documenté ; `flutter_form_builder` (les widgets)
ne doit **pas** être ajouté comme dépendance zcrud, ni au cœur ni dans un
satellite — un satellite qui voudrait malgré tout réutiliser un widget
`FormBuilder*` précis (ex. pour un champ `custom` très spécifique côté app
hôte DODLP) resterait libre de le faire **dans le code applicatif de l'app**,
via `ZWidgetRegistry.register('custom', ...)` ou `EditionFieldType.widget`,
en s'appuyant sur la nullabilité de `FormBuilder.of(context)` démontrée en
§4.1 — jamais dans un package zcrud.

---

## 5. Risques / points de vigilance

- **Régression de parité visuelle non liée à `flutter_form_builder`** : la
  vraie UI de sélection DODLP (`select`/`radio`/`crudDataSelect`/une partie de
  `rowChips`) vient du package tiers `awesome_select` (`SmartSelect`), pas de
  `flutter_form_builder` — hors scope de cette lentille, à couvrir par l'étude
  dédiée au mapping `select`/`radio`/`relation`.
- **`FormBuilderCheckboxGroup`/`FormBuilderChoiceChips` DODLP sont des stubs
  vides** (`options: List.empty()`) — ne pas les prendre comme référence de
  rendu pour `checkbox`/`rowChips` : ils ne contribuent qu'au cycle
  validate()/save() de `FormBuilder`, l'UI réelle vient d'`awesome_select`/
  `RawChip`.
- **`matchKey`/validateurs inter-champs DODLP** lisent `item[value]`
  directement (pas de réactivité ciblée) — `ZCrossFieldValidator` fait mieux
  (abonnement ciblé `fieldListenable(refKey)`), donc la migration améliore le
  invariant plutôt que de le dégrader ; à vérifier au cas par cas que chaque
  `matchKey`/`min`/`max` inter-champs DODLP identifié en story de parité a bien
  un binding `refKey` équivalent côté schéma zcrud.
- **`tgPhoneNumber`** (validateur régional Togo) n'a pas d'équivalent
  `ZValidatorKind` — attendu vu le choix de porter le téléphone comme type de
  champ dédié (`zcrud_intl`), mais à confirmer lors de la story de parité
  téléphone que la règle de préfixes Togo est bien reprise dans
  `zcrud_intl`/l'app hôte, pas perdue.

## 6. Questions ouvertes

1. La story de parité `select`/`radio`/`relation`/`rowChips` doit-elle aussi
   étudier `awesome_select` (`SmartSelect`) comme candidat de réutilisation,
   ou est-il acquis que `ZSelectFieldWidget`/`ZRowChipsFieldWidget` natifs
   suffisent et que `awesome_select` ne migre pas ?
2. Le validateur `tgPhoneNumber` (régional Togo) et le validateur `password`
   custom DODLP doivent-ils être vérifiés champ-par-champ contre
   `ZValidatorCompiler`/`zcrud_intl` dans une story de parité dédiée
   (checklist SM-2), au-delà de la correspondance déjà documentée ici ?
3. Un satellite/app hôte souhaitant malgré tout réutiliser un widget
   `FormBuilder*` précis pour un champ `EditionFieldType.custom` (ex. lors
   d'une migration incrémentale DODLP) doit-il être explicitement autorisé
   à le faire dans le code applicatif (hors packages zcrud), avec une note
   dans la documentation d'intégration — pour éviter qu'un développeur ne le
   réintroduise par erreur dans un satellite zcrud ?
