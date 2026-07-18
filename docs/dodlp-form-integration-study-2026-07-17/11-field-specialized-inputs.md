# 11 — Inputs spécialisés : `pinput` / `autocomplete_textfield` / `editable` / `date_time_picker`

Extension de `STUDY.md` (dépôt DODLP `/home/zakarius/DEV/dodlp-otr`, **lecture seule**). Périmètre :
4 packages `pubspec.yaml` DODLP dédiés aux inputs « spécialisés » : PIN/OTP, autocomplétion, table
éditable inline, date/heure (variante `date_time_picker`, distincte de `flutter_form_builder` déjà
couverte par `02-flutter-form-builder.md`).

## Méthode

1. `grep` des 4 packages dans `pubspec.yaml` (racine DODLP) → les 4 sont bien déclarés.
2. `grep` de leur usage **vivant** (`lib/**/*.dart`, hors `.bak`/`.bak2`/`.old`) — RC de chaque commande noté.
3. Pour tout usage trouvé : lecture du site d'appel (`file:line`), remontée jusqu'au dispatch de
   `edition_screen.dart` si applicable.
4. Confrontation avec `EditionFieldType` / familles `zcrud_core` / registre `ZWidgetRegistry`.

**Verdict global anticipé et confirmé par l'investigation : 3 des 4 packages (`pinput`, `editable`,
`date_time_picker`) sont du poids mort — déclarés dans `pubspec.yaml` mais soit jamais importés, soit
importés dans une fonction jamais appelée.** Seul `autocomplete_textfield` a un usage vivant, et il est
**hors du moteur `data_crud`** (un écran métier ad hoc, pas piloté par `EditionFieldTypes`).

---

## Récapitulatif des 4 packages (déclaration pubspec)

```
$ grep -n "pinput" pubspec.yaml            → 89:  pinput: ^3.0.1                       RC=0
$ grep -n "autocomplete_textfield" pubspec.yaml → 90:  autocomplete_textfield: ^2.0.1   RC=0
$ grep -n "^  editable" pubspec.yaml       → 91:  editable: ^2.0.0                     RC=0
$ grep -n "date_time_picker" pubspec.yaml  → 100:  date_time_picker: ^2.1.0             RC=0
```

---

## 1. `pinput` (PIN/OTP) — **package mort, zéro usage vivant ni legacy**

### Recherche exhaustive

```
$ grep -rln "pinput" --include="*.dart" lib/ | grep -v ".bak"     → (vide)   RC=1 (pas de hit)
$ grep -rl "pinput|Pinput" --include="*.dart*" lib/               → (vide)   RC=1 (aucun .dart/.bak/.old)
$ grep -rn "Pinput(" --include="*.dart*" lib/                     → (vide)   RC=1
$ grep -rln "OTP|otp" --include="*.dart" lib/modules/data_crud/   → (vide)   RC=1
```

Aucun import `package:pinput/pinput.dart` nulle part dans l'arbre (ni `.dart` vivant, ni `.bak`/`.bak2`).
Le package est dans `pubspec.yaml` mais **totalement inutilisé** — pas même une trace dans un fichier
legacy abandonné. Impossible de dire ce à quoi il devait servir (probablement un champ « code de
vérification » jamais branché au moteur `data_crud`, ou dépendance orpheline d'une feature abandonnée
avant même un premier commit d'usage).

### Type de champ zcrud correspondant

Aucun `EditionFieldTypes` DODLP ne référence de notion de PIN/OTP (`models.dart:44-85`, liste complète
relue — pas de valeur `pin`/`otp`/`code`). Côté zcrud, confirmé absent :

```
$ grep -rniqF "pinput" packages/*/lib && echo RC=0 || echo RC=1     → RC=1 (absent)
$ grep -niqF "pin," packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart → RC=1
$ grep -rniF "otp" packages/*/lib  → seuls faux positifs ("SlotPair", "adopt"-like substrings), aucun
  champ PIN/OTP réel.
```

### Verdict

**Non-sujet pour la parité.** DODLP ne rend ce champ nulle part — il n'y a rien à porter. Ne pas créer de
`EditionFieldType.pin` sans un besoin produit explicite (aucune preuve d'usage historique DODLP). Si un
besoin futur émergeait (ex. écran de vérification téléphone), le patron d'intégration serait : type
`pinput` isolé dans un satellite (`zcrud_intl`, proche de `phoneNumber`) via `ZWidgetRegistry.register`,
**jamais** dans `zcrud_core` (dépendance UI tierce). Risque licence/maintenance : `pinput` est BSD-3,
maintenu, faible risque — mais **inutile tant qu'aucun consommateur n'en a besoin**.

---

## 2. `autocomplete_textfield` — vivant, mais **hors moteur `data_crud`**

### Recherche exhaustive

```
$ grep -rln "autocomplete_textfield" --include="*.dart" lib/ | grep -v ".bak"
  → lib/modules/douanes_togolaises/presentation/views/cotation/darg_and_drop_list_footer.dart   RC=0
$ grep -rn "pin\b" lib/modules/data_crud/presentation/views/edition_screen.dart  → (vide)  RC=1
$ grep -n "AutoCompleteTextField" lib/modules/data_crud/**/*.dart               → (vide)  RC=1
```

**Un seul point d'usage dans tout le repo**, et il est **hors `data_crud`** : module
`douanes_togolaises/cotation` (écran de composition d'équipes d'agents — pas un formulaire
`DynamicModel`/`EditionFieldTypes`). Site exact :
`lib/modules/douanes_togolaises/presentation/views/cotation/darg_and_drop_list_footer.dart:1-313`.

### API/variantes réellement utilisées (site vivant)

Fichier mixte selon plateforme (`kIsWeb`) :
- **Web** (`darg_and_drop_list_footer.dart:196-256`) : le code **n'utilise PAS** `autocomplete_textfield` —
  il utilise le widget **natif Flutter** `Autocomplete<String>` (`fieldViewBuilder`/`optionsViewBuilder`/
  `optionsBuilder`), câblé sur un `TextEditingController` partagé via `ChangeNotifierProvider`.
- **Mobile/desktop non-web** (`darg_and_drop_list_footer.dart:263-309`) : `AutoCompleteTextField<Agent>`
  générique — props réellement branchées : `suggestions` (liste d'`Agent`), `itemBuilder` (rendu de
  suggestion custom `Padding`+`Text`), `itemSorter`, `itemFilter` (matching insensible à la casse/espaces),
  `suggestionsAmount: 5`, `decoration` (même `InputDecoration` que la branche web), `minLength: 2`,
  `submitOnSuggestionTap: true`, `itemSubmitted` (callback business), `clearOnSubmit`, `autofocus`,
  `focusNode`, `controller`, `showCursor`, `cursorColor`.

### Rendu visuel

Liste de suggestions **inline sous le champ texte**, filtrée en live (≥ 2 caractères saisis), item custom
(padding 8, une ligne de texte formaté « grade + nom »), tap = sélection immédiate + fermeture. Contraint
dans un `Container` `maxWidth: 200 / maxHeight: 100`. Comportement différent web vs mobile (deux
implémentations distinctes déjà maintenues côté DODLP, symptomatique d'un widget non portable).

### Couverture zcrud

Pas de type `EditionFieldType` dédié « autocomplete-inline » — et c'est cohérent : ce n'est **pas** un
champ du moteur `data_crud` chez DODLP non plus (dispatch `edition_screen.dart` n'y fait jamais appel).
Le besoin le plus proche côté zcrud est `relation` (`ZRelationFieldWidget`,
`packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart:45-565`) :
option `searchable` → **modal bottom-sheet** avec champ de recherche (`_RelationSelectSheet`, ligne 407+,
`prefixIcon: Icons.search` ligne 564) — filtrage sur ouverture de modal, **pas** de suggestions inline
sous le champ pendant la frappe.

```
$ grep -n "class \|searchable" packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart
  → confirme searchable = modal, pas inline (l.45,59,88,170,215,326,557)
```

### Écart & stratégie

**Écart réel mais hors périmètre de parité `EditionFieldType`** : `autocomplete_textfield` ne sert dans
DODLP **aucun** champ `EditionFieldTypes` — c'est un widget métier ad hoc (sélecteur d'agent dans un écran
de cotation `douanes_togolaises`), pas un champ du schéma déclaratif porté vers zcrud. **Ne pas
l'adopter comme famille `EditionFieldType`** : rien dans le catalogue de parité (`docs/canonical-schema.md`
/ `technical-inventory.md`) ne le mentionne comme champ de formulaire CRUD.
Si un futur écran hors-`DynamicEdition` a besoin de ce pattern (suggestions inline pendant la frappe),
le natif Flutter `Autocomplete<T>` (déjà utilisé par DODLP lui-même côté web !) est la voie zéro-dépendance
à privilégier plutôt que de forker `autocomplete_textfield` (package peu maintenu, dernière release
ancienne, licence MIT mais mainteneur inactif — risque de dette si adopté). Si en revanche le besoin
identifié est du **inline-suggestion sur un champ `relation`/`text`** du moteur zcrud (distinct du modal
`searchable` actuel), c'est un **gain UX à instruire séparément** (nouveau mode `ZRelationConfig`, pas un
nouveau `EditionFieldType`), à base d'`Autocomplete<T>` natif — jamais `autocomplete_textfield`.

---

## 3. `editable` (table éditable inline) — **package mort, zéro usage vivant**

### Recherche exhaustive

```
$ grep -rln "package:editable" --include="*.dart*" lib/           → (vide)  RC=1
$ grep -rn "Editable(" --include="*.dart*" lib/                   → (vide)  RC=1
$ grep -rl "editable:" pubspec.yaml → 91:  editable: ^2.0.0        RC=0 (déclaration seule)
```

Aucun import, aucune instanciation de la classe `Editable` (le widget principal du package `editable`)
nulle part — ni dans `data_crud`, ni ailleurs, ni en `.bak`. Comme `pinput`, c'est une dépendance
**orpheline** du `pubspec.yaml`.

### Type de champ zcrud correspondant

Le besoin fonctionnel le plus proche dans `EditionFieldTypes` DODLP est `subItems` (`models.dart:69`) —
mini-CRUD de sous-items. Mais son rendu **n'est pas** une grille de type tableur (ce qu'offrirait
`editable` : cellules éditables inline, colonnes, ajout/suppression de lignes façon spreadsheet) — c'est
une **liste de cartes** avec dialog d'édition par item (confirmé par grep du dispatch `subItems` dans
`edition_screen.dart`, cohérent avec le pattern déjà documenté dans `STUDY.md`/`01-recon-seam-zcrud.md`
pour ce type). Le package `editable` ne rend donc **aucun** champ `data_crud` DODLP — il est mort avant
d'avoir servi.

### Couverture zcrud

`ZSubListFieldWidget` (`packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart:76-873`)
— confirmé par grep : mini-CRUD avec `_SubItem` (identité stable `ValueKey`), rendu compact
(`_CompactRow` l.667) + dialog d'édition par item (`_ZSubItemEditDialog` l.783/802) + carte
(`_SubItemCard` l.873). **Pas** de grille tableur inline (pas de `DataTable`/cellules éditables en place) —
même famille de rendu que DODLP `subItems` (carte + dialog), donc **parité déjà couverte** puisque DODLP
lui-même ne rend jamais de vraie table éditable inline pour aucun champ vivant.

```
$ grep -n "class \|Editable\|table\|Table" packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart
  → aucune classe DataTable/grille tableur ; uniquement card/dialog (cohérent avec absence DODLP)
```

### Verdict

**Non-sujet pour la parité** — package jamais branché à un champ réel côté DODLP. Aucune adoption à
prévoir. Si un futur besoin produit (tableur inline réel, distinct de `subItems` carte+dialog) apparaît,
ce serait un **nouveau mode** à instruire à part (pas une parité DODLP), à isoler dans un satellite
(jamais `zcrud_core`, `editable` a des dépendances `intl`/rendering non négligeables et un mainteneur peu
actif — risque de fork à peser contre un simple `DataTable`/`SfDataGrid` déjà disponible via `zcrud_list`
en édition inline).

---

## 4. `date_time_picker` (package pub, distinct de `flutter_form_builder`) — **importé mais code mort (fonction jamais appelée)**

### Recherche exhaustive

```
$ grep -rln "date_time_picker" --include="*.dart" lib/ | grep -v ".bak"
  → lib/modules/data_crud/forms_utils.dart                          RC=0
$ grep -n "DateTimePicker" lib/modules/data_crud/forms_utils.dart
  → 745:      return DateTimePicker(                                 RC=0
$ grep -rn "showDateTimePicker(" --include="*.dart" lib/ | grep -v "forms_utils.dart:735"
  → (vide)                                                            RC=1
```

Site exact : `lib/modules/data_crud/forms_utils.dart:9` (`import 'package:date_time_picker/date_time_picker.dart';`)
et `forms_utils.dart:735-753` :

```dart
Future<DateTime?> showDateTimePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? minDate,
  DateTime? maxDate,
}) async {
  final today = DateTime.now();
  return showDialog(
    context: context,
    builder: (context) {
      return DateTimePicker(
        initialDate: initialDate,
        initialTime: TimeOfDay.fromDateTime(initialDate ?? today),
        firstDate: today,
        lastDate: maxDate ?? today.add(const Duration(days: 365)),
      );
    },
  );
}
```

Une fonction utilitaire **wrapper** au-dessus du widget `DateTimePicker` du package `date_time_picker` est
bien définie — mais **grep négatif confirmé** : aucun appelant `showDateTimePicker(` nulle part ailleurs
dans le repo (le seul hit est la définition elle-même). **Code mort** : compile, mais n'est jamais exécuté
à l'exécution réelle de l'app.

### Ce qui rend réellement `dateTime`/`time`/`timestamp` dans `edition_screen.dart`

Le dispatch réel (`case EditionFieldTypes.timestamp / dateTime / time`, `edition_screen.dart:3372-3374`
puis bloc `3372-3600+`) utilise :
- **`FormBuilderDateTimePicker`** (package `flutter_form_builder`, déjà cadré par `02-flutter-form-builder.md`
  de `STUDY.md` — hors périmètre de cette fiche) pour `dateTime`/`timestamp`, avec `inputType` dérivé
  (`InputType.date`/`InputType.both`, `edition_screen.dart:744-751`, `3377-3381`).
- **`showTimePicker`** natif Flutter (Material) pour `EditionFieldTypes.time` seul
  (`edition_screen.dart:3499-3503`), sur un `FormBuilderTextField` en lecture seule affichant l'heure
  formatée.

Donc **le package `date_time_picker` (pub) n'est PAS le rendu vivant de la parité `dateTime`/`time`/
`timestamp` DODLP** — c'est `flutter_form_builder` (déjà étudié ailleurs) + `showTimePicker` natif.
`date_time_picker` est une dépendance **legacy abandonnée en cours de route** (probablement l'implé
avant migration vers `FormBuilderDateTimePicker`), dont seul le wrapper mort a survécu.

### Couverture zcrud

`ZDateFieldWidget` (`packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart:32-211`)
couvre déjà nativement `dateTime`/`time` (et un mode `date` seul, `ZDateMode.date`, l.510+ dans
`z_field_config.dart`) via **pickers Material natifs** (`showDatePicker`/`showTimePicker`,
`_pick` l.138-200) — stockage ISO-8601, résolveurs `firstDate`/`lastDate` paresseux (bornes cross-champ),
croix d'effacement (MIN-2), `Semantics` bouton unique (L-1), cible ≥ 48 dp. C'est un rendu **différent**
de DODLP (déclencheur `OutlinedButton` vs `FormBuilderDateTimePicker` en `InputDecoration` intégrée au
flux du formulaire) mais **fonctionnellement supérieur/équivalent** et déjà conforme AD-2/AD-13 — sans
aucune dépendance vers `date_time_picker` (pub) ni même vers `flutter_form_builder`.

```
$ grep -rlqF "date_time_picker" packages/*/pubspec.yaml   → RC=1 (absent, confirmé — zcrud ne dépend pas
  de ce package, ce qui est correct puisque DODLP lui-même ne l'utilise pas réellement)
```

### Lien avec `dateRange` (futur)

Aucun des 3 types `EditionFieldTypes` DODLP (`time`, `dateTime`, `timestamp`) ne couvre une **plage** de
dates. DODLP n'a pas de champ « plage de dates » natif dans le moteur `data_crud` (confirmé : `models.dart`
n'a pas de valeur `dateRange`/`period`/`interval`). C'est cohérent avec la note déjà actée dans
`NEXT-ITERATION-SCOPE.md:59-76` : `dateRange` serait un **gain net** pour zcrud (pas une parité à
reproduire), à instruire comme story dédiée touchant `zcrud_core` (enum + `ZDateRange` + widget patron
`z_date_field_widget.dart` + génération), sérialisée seule sur `zcrud_core` (AD-1/règle de
parallélisation). Aucune leçon de `date_time_picker` (pub) à en tirer côté API — le package n'a jamais
exposé de mode plage utilisé par DODLP (et n'est de toute façon pas le rendu vivant).

### Verdict

**Aucune adoption.** `date_time_picker` (pub) n'est le rendu vivant d'aucun champ DODLP réel — c'est un
mort-vivant dans `forms_utils.dart`. La vraie parité `dateTime`/`time` passe par `flutter_form_builder`
(déjà traité) et `showTimePicker` natif, et zcrud la couvre déjà nativement via `ZDateFieldWidget`
(pickers Material natifs, ISO-8601, AD-2/AD-13 conformes) sans dépendance externe. Le seul travail
restant identifié est l'ajout du type **`dateRange`**, qui est une extension zcrud, pas un portage DODLP.

---

## Tableau de synthèse

| # | Champ / package DODLP | Usage vivant (`file:line`) | `EditionFieldTypes` DODLP concerné | Couverture zcrud | Verdict |
|---|---|---|---|---|---|
| 1 | `pinput` (PIN/OTP) | **Aucun** — RC=1 partout, y compris `.bak` | Aucun | Absent (confirmé grep, `EditionFieldType` n'a pas de `pin`) | **Non-sujet** — package orphelin jamais branché ; ne pas créer de type zcrud sans besoin produit prouvé |
| 2 | `autocomplete_textfield` (autocomplétion) | `douanes_togolaises/.../darg_and_drop_list_footer.dart:1-313` (mobile) + `Autocomplete<String>` natif en web (196-256) | **Aucun** — hors moteur `data_crud`, écran métier ad hoc | `relation` (`ZRelationFieldWidget`) offre `searchable` en **modal**, pas suggestions inline | **Non-sujet pour la parité `EditionFieldType`** ; si besoin futur d'inline-suggestion → `Autocomplete<T>` natif Flutter (déjà utilisé par DODLP web), pas le package tiers |
| 3 | `editable` (table éditable inline) | **Aucun** — RC=1 partout | `subItems` en théorie, mais rendu réel = carte+dialog, pas grille | `ZSubListFieldWidget` = carte + dialog (même famille que DODLP réel) | **Non-sujet** — package orphelin ; parité `subItems` déjà assurée par le pattern carte/dialog commun aux deux côtés |
| 4 | `date_time_picker` (pub, ≠ form_builder) | `forms_utils.dart:735-753` — fonction `showDateTimePicker` **définie mais 0 appelant** (RC=1 sur les appels) | `dateTime`/`time`/`timestamp` — mais rendus par `FormBuilderDateTimePicker` + `showTimePicker` natif, PAS ce package | `ZDateFieldWidget` (natif, pickers Material, ISO-8601, `ZDateMode.date/time/dateTime`) | **Non-sujet** — dépendance legacy morte ; parité réelle passe par `flutter_form_builder` (déjà traité ailleurs) + zcrud la couvre déjà nativement, sans dépendance externe |

**Aucun des 4 packages de cette fiche ne nécessite d'adaptateur `ZFieldWidgetBuilder`** — 3 sont des
dépendances mortes (`pinput`, `editable`, `date_time_picker`), et le 4ᵉ (`autocomplete_textfield`) sert
un besoin hors du moteur `data_crud` pour lequel zcrud n'a pas vocation à répliquer un package tiers
(l'équivalent natif `Autocomplete<T>` est déjà préféré par DODLP lui-même côté web).
