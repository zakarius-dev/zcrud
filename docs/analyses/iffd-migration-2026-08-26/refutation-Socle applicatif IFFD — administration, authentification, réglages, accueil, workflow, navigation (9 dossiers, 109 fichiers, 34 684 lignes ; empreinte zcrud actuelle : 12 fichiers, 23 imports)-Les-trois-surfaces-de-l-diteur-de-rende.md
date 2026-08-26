# Réfutation — « Les trois surfaces de l'éditeur de rendez-vous »

**Domaine** : Socle applicatif IFFD — administration, authentification, réglages, accueil, workflow, navigation
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZFieldSpec[]` + `presentFormEdition(policy:)` + `ZPresentationPolicy` ; `EditionFieldType.dateRange / color / subItems / custom` »
**Gain annoncé** : ~2 500 lignes d'hôte supprimées.

**VERDICT : DÉMENTIE.**

Le canal existe, il est exporté, il est déjà exercé par l'hôte — cette moitié résiste. Ce qui ne résiste pas, c'est la **cible** : les 5 088 lignes visées sont du **code mort non atteignable**, leur mapping **invente un champ absent** et **omet un champ massivement présent**, le type `dateRange` cité **ne porte pas l'heure** que l'éditeur manipule, et la masse réelle (58 % de la surface principale) est la **récurrence** — que la revendication renvoie elle-même à l'hôte via `EditionFieldType.custom`. Le « gain » annoncé est, à la ligne près, ce qui ne bouge pas.

Repères : IFFD @ `65d1af9` (lecture seule), zcrud @ `cc276c154` (v3.21.0).

---

## 0. Ce qui résiste — le canal est réel (vérifié au corps, pas à la dartdoc)

| Élément cité | Vérification sur disque | Verdict |
|---|---|---|
| `z_presentation_policy.dart:72-84` | `ZEditionPresentation resolve(...)` **:73-84** ; corps = `switch` exhaustif `compact→sheet`, `medium→dialog`, `expanded→(light→dialog / heavy→page)`. Ligne 72 = dernière ligne de dartdoc. | ✅ (décalage d'1 l.) |
| `.from :65` | `factory ZPresentationPolicy.from(ZPresentationResolver) = _FnPresentationPolicy;` **:64-65** | ✅ |
| `presentFormEdition(policy:)` | `zcrud_screen/lib/src/presentation/present_form_edition.dart:234`, paramètre `ZPresentationPolicy policy = const ZPresentationPolicy()` **:244** | ✅ |
| La policy **agit** | `present_edition.dart:155-268` — `final ZEditionPresentation mode = forcedMode ?? policy.resolve(ZWindowSizeClass.of(context), formWeight: formWeight);` puis `presenter.present(..., mode: mode)`. Ce n'est pas un drapeau inerte. | ✅ |
| `edition_field_type.dart:38-213`, 46 types | `grep -c "^  [a-zA-Z]*,$"` → **46**. `dateRange` :65, `subItems` :88, `color` :127, `custom` :212. | ✅ |
| `custom → registryOrFallback` | `.../presentation/edition/edition_field_family.dart:220-221` ; dispatch `z_field_widget.dart:990-991` → `_dispatchRegistry` :1062 → `_tryRegistryWidget` :1081 → `ZcrudScope.maybeOf(context)?.widgetRegistry` :1085, repli `ZUnsupportedFieldWidget`. Le contexte passé porte bien `value` + `onChanged → setValue`. | ✅ |
| `z_field_config.dart:852,:878,:914` | :852 `class ZDateConfig extends ZFieldConfig {` ; :878 `final ZDateMode? mode;` ; :914 dartdoc de `minDays`. | ✅ |
| `z_sub_list_config.dart:154` | `class ZSubListConfig extends ZFieldConfig {` | ✅ |
| Atteignable depuis IFFD | `iffd/pubspec.yaml` : `zcrud_navigation` **:498**, `zcrud_screen` **:524** (deps + overrides :690/:695). Barils : `zcrud_navigation.dart:46-47`, `zcrud_screen.dart:24`. IFFD appelle déjà `presentFormEdition` **60 fois** et exerce `ZWidgetRegistry` (`z_iffd_field_registry.dart:78`, `kIffdAclMatrixKind`). | ✅ |

**Aucune réfutation à porter sur l'existence, l'export ou l'effectivité des canaux.** Tout le reste l'est.

---

## R1 — DÉCISIF : les 5 088 lignes sont du **code mort**. Le gain ne vient pas du socle, il vient de `git rm`.

Fichier : `/home/zakarius/DEV/iffd/lib/workflow/screens/appointment_editor.dart` (7 858 l, `part of '../workspace.dart'`).

**Grep négatif montré — le point d'entrée unique n'est appelé nulle part :**

```
$ grep -rn "displayAppointmentDetails" . --include='*.dart' --exclude-dir=build --exclude-dir=.git
lib/workflow/screens/appointment_editor.dart:555:Widget displayAppointmentDetails(
```
→ **1 seule occurrence dans tout le dépôt : sa propre définition.**

**Grep négatif montré — aucune des trois surfaces n'est instanciée :**

| Surface | Occurrences hors définition | Détail |
|---|---|---|
| `PopUpAppointmentEditor` | **0 instanciation** | seulement :963 (ctor), :1006 (State), :1028 (`didUpdateWidget`) |
| `AppointmentEditor` | **0 instanciation** | seulement :5218 (ctor), :5261 (State), :5291 (`didUpdateWidget`) |
| `AppointmentEditorWeb` | 4 instanciations — **toutes dans le même fichier** | :491 et :526 (dans `_editRecurrence` :404-554), :596 (dans `displayAppointmentDetails` :555-715), :1538 (dans le `build` du popup **mort**) |

Et `_editRecurrence` n'est appelé que depuis :606, à l'intérieur de `displayAppointmentDetails`. La chaîne entière est refermée sur elle-même.

```
$ grep -n "@RoutePage" lib/workflow/screens/appointment_editor.dart
(0 ligne)
```
→ aucune entrée par le routeur `auto_route`.

**Dernier commit touchant le fichier** : `8fe3db5 "All wranings lints fixed"`, **2025-11-25** — un passage de lint global, pas une évolution.

```
$ grep -rln "zcrud" lib/workflow/ --include='*.dart'
lib/workflow/screens/task_edition_screen.dart
lib/workflow/screens/tasks_screen.dart
lib/workflow/screens/event_editon_screen.dart
lib/workflow/workspace.dart
lib/workflow/screens/zcrud/workflow_notes_zcrud_edition.dart
lib/workflow/screens/zcrud/task_list_zcrud_edition.dart
```
→ `appointment_editor.dart` **absent de la liste** : zéro import zcrud. L'éditeur **vivant** est `lib/workflow/screens/event_editon_screen.dart` (1 308 l), méthode `_getAppointmentEditor` **:529**, montée à **:1186** — et *lui* porte déjà zcrud (jumeau `workflow_notes`).

**Ce que le fichier mort exporte encore vers du code vivant** — 7 références seulement, toutes vers des **constantes**, pas vers les surfaces :

| Symbole | Consommateur vivant |
|---|---|
| `_weekDay` | `components/recurrence_picker.dart:832`, `event_editon_screen.dart:163`, `:373` |
| `_dayMonths` | `event_editon_screen.dart:158`, `:307` |
| `_daysPosition` | `event_editon_screen.dart:161`, `:372` — **les deux commentées** |
| `PickerChangedDetails` | `event_editon_screen.dart:825` |

⇒ Environ **40 lignes de données** sont vivantes ; les **5 088 lignes de surfaces** ne le sont pas.

**Conséquence sur le gain annoncé** : « ~2 500 lignes d'hôte supprimées » décrit la suppression d'un fichier que **personne n'appelle**. Elle est réalisable aujourd'hui, sans zcrud, en déplaçant 4 constantes. Attribuer ce gain au socle, c'est facturer au socle un `git rm`. Et le migrer *vraiment* reviendrait à **ressusciter** une fonctionnalité que l'application n'atteint plus.

---

## R2 — Le mapping **invente** un champ : « subItems (rappels) »

```
$ grep -in "reminder\|rappel\|alarm\|notification" lib/workflow/screens/appointment_editor.dart
(0 ligne)
```

**Zéro occurrence** dans les 7 858 lignes du fichier, donc *a fortiori* zéro dans les 5 088 lignes attaquées. Il n'y a **pas de champ « rappels »** dans l'éditeur de rendez-vous.

Les rappels existent ailleurs dans le module, hors du périmètre chiffré : `lib/workflow/components/event_reminders_widget.dart` (**327 l**) et `lib/workflow/components/task_reminder_picker.dart` (**170 l**), consommés par `event_editon_screen.dart` / `task_edition_screen.dart`. Le mapping projette donc `subItems` sur un besoin qui n'appartient pas à la cible.

---

## R3 — Le mapping **omet** un champ massivement présent : le fuseau horaire

```
$ grep -c "TimeZone" lib/workflow/screens/appointment_editor.dart
94
```

- Classe dédiée `CalendarTimeZonePicker` **:878-897** + `CalendarTimeZonePickerState` **:899-960** = **83 l**.
- État : `_isTimeZoneEnabled` (:1719), `_selectedTimeZoneIndex` (:1710) ; libellé `'Time zone'` **:2883** ; la hauteur de la dialogue en dépend (:2214, :2217, :2221, :2224).
- Persisté : `startTimeZone` / `endTimeZone` sur chaque `Appointment` (:1509-1518, :4935-4944).

Aucun des **46** `EditionFieldType` ne nomme un fuseau ; le mapping avancé ne le mentionne pas. C'est un champ de plus à faire passer par `custom` ou `select` + catalogue IANA — non compté dans le gain.

---

## R4 — `EditionFieldType.dateRange` **ne porte pas l'heure**. La « plage » de l'hôte en est faite.

Lecture du **corps**, pas de la dartdoc :

```
$ grep -n "showDateRangePicker\|TimeOfDay\|showTimePicker" \
    packages/zcrud_core/lib/src/presentation/edition/families/z_date_range_field_widget.dart
3:/// Déclencheur de picker de **plage** (`showDateRangePicker`) — picker Material
331:    final picked = await showDateRangePicker(
```
→ **`TimeOfDay` : 0 ligne. `showTimePicker` : 0 ligne.** Le sélecteur est `showDateRangePicker` (Material, **date seule**, `DateTimeRange` normalisé à minuit), et l'affichage est **figé** en date : `:308  zDateDisplayTextForMode(context, _isoDate(d), mode: ZDateMode.date)`.

Côté hôte, l'heure est la matière même du champ :

| Surface | État horaire |
|---|---|
| `PopUpAppointmentEditorState` | `late TimeOfDay _startTime;` **:1011**, `late TimeOfDay _endTime;` **:1012** |
| `AppointmentEditorWebState` | `late TimeOfDay _startTime;` **:1712**, `late TimeOfDay _endTime;` **:1714** |

Libellés `'Start'` **:2391** / `'End'` **:2611** — chacun avec son sélecteur de date **et** son sélecteur d'heure.

**Le repli ne sauve pas la citation** : on peut évidemment déclarer 2 × `dateTime`. Mais alors la moitié de la preuve avancée tombe — `ZDateConfig.maxDays`/`minDays` sont documentés « **Sans effet sur les types `dateTime`/`time`** » (`z_field_config.dart`, dartdoc de `maxDays`, autour de :912). Les lignes `:852,:878,:914` citées comme « ZDateConfig amplitudes » deviennent **inertes** dans la seule configuration qui rend le besoin.

---

## R5 — `ZDerivation` n'a **aucune cible** pour « masquer l'heure »

```
$ grep -n "this\.value,\|this\.options,\|this\.visible,\|this\.bounds,\|this\.readOnly," \
    packages/zcrud_core/lib/src/domain/edition/z_derivation.dart
207:    this.value,
208:    this.options,
209:    this.visible,
210:    this.bounds,
211:    this.readOnly,
```
```
$ grep -n "ZDateMode\|config\b" packages/zcrud_core/lib/src/domain/edition/z_derivation.dart
82:///   config: ZSelectConfig(choicesFromKey: ZDerivationChannels.optionsKey('ville')),
```
→ **5 cibles** (`value`/`options`/`visible`/`bounds`/`readOnly`), et **aucune** ne dérive une *config* ni un `ZDateMode`. La seule occurrence de `config` est un exemple de dartdoc sans rapport.

Or ce que `_isAllDay` pilote chez l'hôte n'est pas la visibilité d'un champ, c'est la **granularité** d'un champ : `_isAllDay == true` masque les sélecteurs d'**heure** en gardant les sélecteurs de **date** (`_isAllDay`, **31 lignes** dans le fichier — chiffre du CR confirmé).

- Avec `dateRange` : il n'y a **pas** de sous-champ heure à masquer (R4) — la dérivation `visible` n'a pas d'objet.
- Avec 2 × `dateTime` : `visible` masque le **champ entier**, date comprise — ce n'est pas le comportement de l'hôte, et rien ne permet de basculer `ZDateMode.dateTime → ZDateMode.date`.

La preuve « `ZDerivation` cible `visible` (masquer l'heure) » nomme un canal réel appliqué à un besoin qu'il ne couvre pas.

---

## R6 — `EditionFieldType.color` ne sait pas porter la palette de l'hôte

```dart
// z_color_field_widget.dart:77
static List<int> _palette() { /* 12 teintes HSV (i*30°) + 3 neutres = 15 */ }
```
`_palette()` est **statique et privée**, sans paramètre. `ZColorConfig` n'expose que `enableAlpha` (:258), `showPalette` (:261), `showRecent` (:264) :

```
$ grep -n "palette" packages/zcrud_core/lib/src/domain/edition/z_field_config.dart
260:  /// Affiche la **palette de swatches** dérivée (défaut `true`, rétro-compat).
```
→ on peut **montrer ou cacher** la palette dérivée ; on ne peut pas la **remplacer**.

L'hôte, lui, ne choisit pas un ARGB : il choisit un **index** dans une collection fournie par l'application, avec des **noms** affichés — `widget.colorCollection[_selectedColorIndex]` et `widget.colorNames[_selectedColorIndex]` (**:1479**, :1509, :4935). Migrer vers `color` change la valeur persistée (`int` ARGB) *et* perd la nomination. Couverture partielle présentée comme totale.

---

## R7 — Les trois surfaces **ne sont pas trois tailles d'une même déclaration**

C'est le cœur de la revendication (« `ZPresentationPolicy.resolve` rend les trois surfaces d'une déclaration ») et c'est faux sur les deux axes.

**(a) Les jeux de champs diffèrent.**

```
$ grep -n "Repeat\|_selectedRecurrenceType" lib/workflow/screens/appointment_editor.dart | awk -F: '$1>=1006 && $1<=1663'
(0 ligne)
```
→ le popup (`PopUpAppointmentEditorState`, :1006-1663) n'a **aucune récurrence** et **pas** de `_isTimeZoneEnabled` : son état tient en 13 champs (:1007-1019). La surface web en déclare **30 de plus**, tous récurrence (:1723-1735). Sa propre dartdoc l'annonce : *« Builds the appointment editor with **minimal elements** in a pop-up »* (:960-961).

`presentFormEdition` prend **une** liste `fields:` et rend **ce même catalogue** dans le conteneur que la policy choisit. Le jeu de champs n'est jamais fonction de `ZWindowSizeClass`. Faire varier `fields` selon la taille, c'est l'hôte qui l'écrit — la policy n'y contribue rien.

**(b) La bascule n'est pas un breakpoint, c'est un bouton.**

`PopUpAppointmentEditorState.build` :1488-1543 : un `RawMaterialButton` dont le `onPressed` (**:1501**) fait `Navigator.pop(context)` puis `showDialog(... AppointmentEditorWeb ...)` (**:1538**). C'est de la **divulgation progressive déclenchée au tap** (« More options »), pas une dérivation de largeur de fenêtre. `ZPresentationPolicy.resolve` est **pure** et ne prend que `(ZWindowSizeClass, ZFormWeight)` — elle ne peut pas modéliser cette transition.

---

## R8 — La masse est la **récurrence**, que la revendication renvoie elle-même à l'hôte

Mesures dans `AppointmentEditorWebState` (:1708-5209, **3 502 l**) :

| Bloc | Lignes | Poids |
|---|---|---|
| Logique de récurrence (`_updateWebRecurrenceProperties`, `_dailyRule`…`_yearlyRule`, `_noEndDateRange`/`_endDateRange`/`_countRange`, `_addInterval`/`_removeInterval`, `_monthWeekIcon`/`_monthDayIcon`, `_addDay`/`_removeDay`, `_addCount`/`_removeCount`, `_webSelectWeekDays`, `_webInitialWeekdays`) — :1802-2139 | **338** | |
| UI de récurrence dans `build` — :2959-4644 | **1 686** | |
| **Total récurrence** | **2 024** | **58 %** de la surface, **40 %** des 5 088 l |

Vérification des bornes : le premier libellé de récurrence est `'Repeat'` **:2981** ; entre :2959 et :4644 **aucun** libellé non-récurrent n'apparaît ; le suivant est `'Employees'` **:4657**, puis `'Description'` **:4717**.

Le reste de la récurrence du même fichier, hors des 5 088 l attaquées : `SelectRecurrenceRuleDialog` + `SelectRuleDialogState` :6189-6425 (**237 l**), `_CustomRule` + `CustomRuleState` :6856-7858 (**1 003 l**). Et, **vivant** celui-là : `lib/workflow/components/recurrence_picker.dart` (**1 721 l**).

Or la revendication écrit elle-même : *« La règle de récurrence entre par `EditionFieldType.custom` → `registryOrFallback` → `ZcrudScope.widgetRegistry` »*. Le seam est réel (§0), mais il **ne rend rien** : il appelle un widget que **l'hôte doit écrire**. Le socle fournit le trou, pas le bouchon.

⇒ Le gain annoncé (~2 500 l) est du même ordre que la masse qui **ne bouge pas** (2 024 l dans la seule surface web, ~3 264 l en comptant les dialogues de règle du fichier). Les deux ne peuvent pas être vrais ensemble.

---

## R9 — La soumission de l'hôte n'est pas une `Map`

`presentFormEdition` rend `Future<Map<String, dynamic>?>` (:234) — un dictionnaire de valeurs. Le chemin d'enregistrement de l'hôte, lui, est une **mutation de `CalendarDataSource` Syncfusion** :

- `events.appointments.removeAt(...)` / `.add(...)` puis `events.notifyListeners(CalendarDataSourceAction.remove | .add, <Appointment>[...])` — p. ex. :4915-4921, :4952-4955 ;
- génération de la règle : `SfCalendar.generateRRule(_recurrenceProperties!, _startDate, _endDate)` :4947-4950 ;
- gestion des exceptions de série : `recurrenceExceptionDates` :4910, :4938 ;
- garde métier « deux occurrences le même jour » avec `AlertDialog` :4882-4903 ;
- sémantique série/occurrence : `_DeleteDialog` :6426-6594 et `_EditDialog` :6595-6844 (**419 l**), `enum _Edit { event, series }` :5210, `enum _Delete { event, series }` :5212, `_editExceptionSeries` :112-256 appelé à :5003.

Le bloc d'enregistrement de la surface web (≈ :4860-5190, **~330 l**) n'est pas du rendu de formulaire : c'est de la logique de calendrier récurrent. `presentFormEdition` ne la remplace ni ne l'appelle.

---

## Chiffres de la revendication — contrôlés

| Affirmation du CR | Mesure | Écart |
|---|---|---|
| fichier 7 858 l | 7 858 | 0 |
| `PopUpAppointmentEditorState :1006` (657 l) | :1006-1663 = **658** | +1 |
| `AppointmentEditorWebState :1708` (3 507 l) | :1708-5209 = **3 502** | −5 |
| `AppointmentEditorState :5261` (927 l) | :5261-6188 = **928** | +1 |
| total 5 091 l | **5 088** | −3 |
| `_isAllDay` 31 fois | `grep -c` → **31** | 0 |
| `_updateAppointmentProperties` 14 | **14** | 0 |
| `_getResourceEditor` 6 | **6** | 0 |
| 46 types couvrent le formulaire | 46 types confirmés ; **couverture** réfutée (R2-R6) | — |

Le **mesurage** du CR est fiable à ±5 lignes. C'est son **interprétation** qui ne tient pas.

---

## Ce qui est vrai à la place

1. **Le canal est réel et déjà branché** : `presentFormEdition(policy:)` + `ZPresentationPolicy` + les 46 `EditionFieldType` existent, sont exportés, sont des dépendances déclarées d'IFFD (`pubspec.yaml:498`/`:524`) et sont exercés 60 fois. Rien à reprocher au socle.
2. **La cible est morte.** Les 5 088 l de `appointment_editor.dart` n'ont **aucun point d'entrée** (`displayAppointmentDetails` : 1 occurrence dans tout le dépôt, sa définition ; 0 `@RoutePage` ; 0 instanciation externe des trois `State`). Le geste correct est un **retrait** — extraire les 4 constantes encore consommées (`_weekDay`, `_dayMonths`, `_daysPosition`, `PickerChangedDetails`, 7 références vivantes) vers `components/recurrence_picker.dart`, puis supprimer le fichier. Aucun paquet zcrud n'est requis pour cela, et le gain est **~7 800 l**, pas 2 500.
3. **La vraie cible de migration, si migration il doit y avoir**, est `lib/workflow/screens/event_editon_screen.dart` (1 308 l, `_getAppointmentEditor` :529, monté :1186) — c'est *lui* qui est atteignable et qui porte déjà un jumeau zcrud. Il faudrait le mesurer avant de lui promettre quoi que ce soit ; ce CR ne l'a pas fait.
4. **Même sur une cible vivante, la couverture serait partielle** : l'heure de début/fin (`dateRange` est date-seule, `ZDateConfig.maxDays` inerte sur `dateTime`), le fuseau horaire (94 l, 0 type dédié), la palette nommée de l'hôte (`_palette()` privée, non substituable), la bascule `_isAllDay` date↔date+heure (aucune cible `ZDerivation`), et surtout la **récurrence** (2 024 l dans la seule surface web) qui reste à la charge de l'hôte via `custom`.
5. **`ZPresentationPolicy` ne rend pas « trois surfaces d'une déclaration »** quand les surfaces portent des **jeux de champs différents** et basculent **au tap**. Elle choisit un conteneur pour un catalogue donné ; elle ne choisit pas le catalogue.

---

## Annexe — commandes de vérification (toutes en lecture seule)

```bash
# R1 — mort
cd /home/zakarius/DEV/iffd
grep -rn "displayAppointmentDetails" . --include='*.dart' --exclude-dir=build --exclude-dir=.git
grep -rn "\bPopUpAppointmentEditor\b\|\bAppointmentEditor\b" lib/ test/ --include='*.dart'
grep -n "@RoutePage" lib/workflow/screens/appointment_editor.dart
git log -1 --format='%ad %s' --date=short -- lib/workflow/screens/appointment_editor.dart

# R2 — rappels absents
grep -in "reminder\|rappel\|alarm\|notification" lib/workflow/screens/appointment_editor.dart

# R3 — fuseau présent
grep -c "TimeZone" lib/workflow/screens/appointment_editor.dart

# R4 — dateRange sans heure
cd /home/zakarius/DEV/zcrud
grep -n "showDateRangePicker\|TimeOfDay\|showTimePicker" \
  packages/zcrud_core/lib/src/presentation/edition/families/z_date_range_field_widget.dart

# R5 — cibles de ZDerivation
grep -n "this\.value,\|this\.options,\|this\.visible,\|this\.bounds,\|this\.readOnly," \
  packages/zcrud_core/lib/src/domain/edition/z_derivation.dart
grep -n "ZDateMode\|config\b" packages/zcrud_core/lib/src/domain/edition/z_derivation.dart

# R6 — palette non substituable
grep -n "_palette()" packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart
grep -n "palette" packages/zcrud_core/lib/src/domain/edition/z_field_config.dart

# R7 — popup sans récurrence
cd /home/zakarius/DEV/iffd
grep -n "Repeat\|_selectedRecurrenceType" lib/workflow/screens/appointment_editor.dart | awk -F: '$1>=1006 && $1<=1663'
```
