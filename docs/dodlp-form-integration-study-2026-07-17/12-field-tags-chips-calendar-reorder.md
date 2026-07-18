# Étude d'intégration DODLP → zcrud — Famille TAGS / CHIPS / CALENDRIER / RÉORDONNANCEMENT

Extension de `STUDY.md` (qui couvre `flutter_form_builder`/`awesome_select`/`flutter_switch`/
`intl_phone_number_input`/`country_picker`). Périmètre ici : `flutter_tags`, `table_calendar`,
`drag_and_drop_lists`, `flutter_slidable`, `expandable`, et le réordonnancement des `subItems`.

Repo DODLP (lecture seule) : `/home/zakarius/DEV/dodlp-otr`. Fichiers `.bak`/`.bak2` ignorés sauf
mention explicite « legacy abandonné ». Toute absence est prouvée par `grep -qF`/`grep -qi` + RC
affiché.

---

## 1. `tags` — étiquettes en saisie libre

**DODLP** : `EditionFieldTypes.tags`, rendu dans `edition_screen.dart:2100-2187` (switch-case
`case EditionFieldTypes.tags:`).

- **Package** : `flutter_tags: ^1.0.0-nullsafety.1` (pubspec.yaml:72), import
  `edition_screen.dart:63`.
- **API utilisée** : `Tags(itemCount:, itemBuilder:, textField:)` + `ItemTags(index:, title:,
  active: true, pressEnabled: false, combine: ItemTagsCombine.withTextBefore, activeColor:,
  textColor:, elevation: 0, borderRadius: BorderRadius.circular(20), removeButton:
  ItemTagsRemoveButton(onRemoved:))` ; ajout via `TagsTextField(hintText: "Ajouter un tag...",
  onSubmitted:)`.
- **Rendu visuel** : `Card` (elevation 0, bordure grise, radius 12) enveloppant un `Wrap` de puces
  arrondies (radius 20) avec bouton de suppression intégré à la puce, couleur active
  thématisée (`isDark ? kNavyColor : Colors.grey.shade200`), + champ de saisie texte en pied de
  card pour ajouter une étiquette par `onSubmitted` (validation clavier, pas de bouton `+`
  explicite). Lecture seule : simple `Wrap` de `Chip` Material standard (pas de `Tags`/`ItemTags`).
- **Couverture zcrud** : **natif** — `packages/zcrud_core/lib/src/presentation/edition/families/z_tags_field_widget.dart`
  (`ZTagsFieldWidget`, `EditionFieldType.tags`). Puces avec `IconButton` de retrait ≥ 48 dp,
  `TextField` + bouton `+` explicite (pas seulement `onSubmitted`), `Semantics` container,
  `EdgeInsetsDirectional`. Preuve :
  `grep -n "class ZTagsFieldWidget" packages/zcrud_core/lib/src/presentation/edition/families/z_tags_field_widget.dart` → RC=0, 1 hit.
- **Écart** : radius/couleur de puce DODLP (20 dp, `kNavyColor` codé) vs thème zcrud
  (`theme.radiusM`, `theme.fieldBorderColor` — FR-26 conforme, pas de couleur en dur). C'est un
  **écart de style volontaire** côté zcrud (conforme AD/FR-26) — pas une régression fonctionnelle
  (add/remove/lecture seule tous couverts). Le bouton `+` explicite de zcrud est un **plus**
  ergonomique vs `onSubmitted`-only DODLP.
- **Verdict** : **natif zcrud suffit** pour la parité fonctionnelle. Aucun besoin d'adopter
  `flutter_tags`. Si le owner exige le rendu visuel *pixel-identique* (puce ronde 20dp, couleur
  navy), c'est un ajustement de thème (`ZcrudTheme`), pas un fork de package.

### Variante liste : `itemsAreTags` (rendu tag des `subItems` en lecture)

- **DODLP** : `dynamic_list_viewer.dart:242-276`, fonction `_buildTagsWidget()` utilisant aussi
  `Tags`/`ItemTags`, mais avec des props supplémentaires absentes du champ `tags` simple :
  `customData`, `active` (bool, état visuel actif/inactif par item), `icon: ItemTagsIcon(icon:
  iconData)`, callbacks `onPressed`/`onLongPressed` (vides dans le code vivant), et
  `removeButton` déclenchant une **confirmation** (`buildConfirmDialog`) avant suppression.
  Activé par `field.itemsAreTags` plombé jusqu'à `DynamicSubListScreen` (`edition_screen.dart:3791`,
  `itemsAreTags: field.itemsAreTags`) et jusqu'au widget de liste
  (`dynamic_list_viewer.dart:20,59,442-443`).
- **Constat** : `grep -rn "itemsAreTags:" lib --include="*.dart" | grep -v "\.bak"` → seuls 2 hits,
  tous deux dans le **plumbing** (`edition_screen.dart:3791`, `dynamic_list_viewer.dart:20/59`) ;
  **aucun site d'appel** dans ce repo ne positionne `itemsAreTags: true` sur une config de champ
  réelle. RC=0 (des hits existent) mais **0 usage métier** trouvé — fonctionnalité plombée mais
  **probablement inutilisée dans DODLP tel que cloné** (peut être active dans IFFD/DLCFTI, hors
  périmètre lecture ici).
- **Couverture zcrud** : **ABSENT** en tant que variante — `ZSubListFieldWidget` (mode `inline` ou
  `compact`, cf. §3) ne propose pas de rendu "tag chips avec icône + toggle actif" pour les
  sous-items. Preuve négative :
  `grep -qi "itemsAreTags\|ItemTagsIcon" packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` → RC=1.
- **Verdict** : **gap mineur, priorité basse** (feature non observée en usage réel dans DODLP). Si
  un consommateur (IFFD/DLCFTI) en dépend, ajouter un **variant de rendu** dans
  `ZSubListFieldWidget` (nouveau `ZSubListDisplayMode.tags` ou builder de résumé avec icône) plutôt
  qu'adopter `flutter_tags` — le pattern reste "puce supprimable + icône", entièrement reproductible
  avec `ChoiceChip`/`InputChip` Material (déjà utilisé par `ZRowChipsFieldWidget`), sans dépendance
  externe.

---

## 2. `rowChips` — puces mono-choix

Hors périmètre `flutter_tags` (DODLP `rowChips` est couvert par `awesome_select`/logique interne,
déjà traité dans `STUDY.md`). Rappel de couverture zcrud pour la cohérence du rapport : **natif**
— `packages/zcrud_core/lib/src/presentation/edition/families/z_row_chips_field_widget.dart`
(`ZRowChipsFieldWidget`, `ChoiceChip` sur `field.choices`, support sous-titre MIN-2). Pas de package
DODLP dédié à confronter ici (pas de `flutter_tags`/`table_calendar`/`drag_and_drop_lists`
impliqué) — RAS pour cette famille.

---

## 3. Réordonnancement des `subItems` (mini-CRUD imbriqué)

**Recherche du package `drag_and_drop_lists` dans le module `data_crud`** :
```
grep -rl "DragAndDropList" lib/modules/data_crud --include="*.dart" | grep -v "\.bak"
```
→ **RC=1 (aucun résultat)**. `drag_and_drop_lists: ^0.4.2` (pubspec.yaml:75) n'est utilisé **nulle
part dans `data_crud`** — ses 2 seuls usages vivants sont dans
`lib/modules/douanes_togolaises/presentation/views/cotation/{cotation_edition_screen.dart,
darg_and_drop_list_footer.dart}` (`DragAndDropListFooter`, écran bespoke "cotation", **hors
périmètre formulaire CRUD générique**, pas de rapport avec `subItems`).

**Recherche de `Reorder`/`ReorderableListView` dans tout `data_crud`** :
```
grep -qi "reorder" lib/modules/data_crud/presentation/views/edition_screen.dart   → RC=1
grep -qi "reorder" lib/modules/data_crud/presentation/views/dynamic_list_viewer.dart → RC=1
grep -qi "reorder" lib/modules/data_crud/forms_utils.dart → RC=1
```
**Conclusion DODLP** : le widget de sous-liste imbriquée `DynamicSubListScreen`
(`dynamic_list_viewer.dart`, invoqué depuis `edition_screen.dart:3777` au `case
EditionFieldTypes.subItems:`) **ne supporte AUCUN réordonnancement** — ni drag-and-drop, ni
boutons monter/descendre. Les `subItems` sont ajoutés en fin de liste (`item[fieldName]?.add`,
`edition_screen.dart:3827/3830`) et l'ordre n'est modifiable qu'en supprimant/recréant.

**Couverture zcrud** : **natif, et supérieur à DODLP** —
`packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart`
(`ZSubListFieldWidget`) implémente `_move(index, delta)` (lignes 289-297) exposé via des
`IconButton` monter/descendre (`Icons.arrow_upward`/`arrow_downward`, `_SubItemCard`, lignes
916-930), gouverné par `config.reorderable` (`ZSubListConfig.reorderable`, défaut `true`,
`z_sub_list_field_widget.dart:169-172`). Identité stable par item
(`KeyedSubtree(ValueKey(item.id))`) garantissant qu'un déplacement ne casse pas le focus/état d'un
sous-formulaire en cours d'édition (SM-1 imbriqué, doc-comment lignes 9-24).
Preuve : `grep -n "_reorderable\|onMoveUp\|onMoveDown" packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` → RC=0, 6 hits.

- **Verdict** : **natif zcrud dépasse déjà DODLP** — aucune adoption de package requise. Le
  réordonnancement est monter/descendre (pas de drag-and-drop tactile), ce qui est un choix
  délibéré et documenté (a11y : cibles ≥ 48 dp, pas de geste complexe) ; DODLP n'ayant **aucun**
  réordonnancement, il n'y a **aucun risque de régression visuelle** à migrer — c'est une
  amélioration nette. Pas de gap.
- **Risque signalé** : si un consommateur (IFFD/DLCFTI, hors lecture ici) a un usage vivant de
  `DragAndDropListFooter`/`drag_and_drop_lists` pour du drag-and-drop tactile de `subItems`
  (non confirmé dans DODLP), il faudrait alors évaluer un adaptateur `ZFieldWidgetBuilder`
  drag-and-drop dédié dans un satellite (jamais `zcrud_core`, AD-1) — **non justifié aujourd'hui**
  par la preuve disque DODLP.

---

## 4. `flutter_slidable` — actions swipe sur les lignes de liste

```
grep -rl "Slidable(" lib --include="*.dart" | grep -v "\.bak"   → RC=1 (aucun résultat, tout lib/)
grep -rn "package:flutter_slidable" lib --include="*.dart" | grep -v "\.bak"  → RC=1
```
**Constat** : `flutter_slidable: ^4.0.3` (pubspec.yaml:71) est déclaré en dépendance mais **n'a
strictement aucun usage vivant** dans le code source (ni `Slidable(`, ni `import
'package:flutter_slidable'`). Le nom `_slidableItemBuilder` existe bien
(`dynamic_list_viewer.dart:277-295`) mais c'est un **simple `InkWell`/`SingleChildScrollView`
horizontal** avec `onLongPress` ouvrant un bottom-sheet CRUD — **aucun widget `Slidable`
réel n'est instancié**, le nom est vestigial/historique.
- **Verdict** : **dépendance pubspec morte** — rien à porter côté zcrud. Ne pas adopter
  `flutter_slidable`. Aucune action requise.

---

## 5. `expandable` — sections repliables (hors famille champ, contexte)

```
grep -rl "package:expandable\|ExpandablePanel" lib --include="*.dart" | grep -v "\.bak"
→ lib/src/presentation/side_menu/side_menu.dart
  lib/src/presentation/side_menu/src/module_menu.dart
  lib/modules/data_crud/forms_utils.dart
  lib/modules/workflow/workspace.dart
```
- **Dans `data_crud`** : `forms_utils.dart:32-110`, classe `MyStickyHeader` — un **en-tête de
  section repliable** (`ExpandablePanel` + `ExpandableController`, état persisté via `GetStorage`)
  utilisé pour grouper des **blocs de champs** dans le formulaire (`edition_screen.dart:577`,
  `return MyStickyHeader(...)`), pas pour un champ individuel de notre famille
  (tags/calendrier/réordonnancement).
- **Hors périmètre de cette étude** (ni tags, ni calendrier, ni réordonnancement d'items) — signalé
  pour traçabilité de l'attribution des packages du pubspec, sans verdict de couverture ici (la
  brique zcrud pertinente serait un futur "groupe de champs repliable", absent des familles listées
  dans le prompt-cadre ; à couvrir par l'étude dédiée aux layouts/sections si elle existe).

---

## 6. `table_calendar` — calendrier (sélection simple vs plage → informe `dateRange`)

```
grep -rn "TableCalendar(" lib --include="*.dart" | grep -v "\.bak"
→ lib/modules/workflow/presentation/views/screens/agenda_screen.dart:682
```
**Constat clé** : `table_calendar: ^3.2.0` (pubspec.yaml:73) est importé dans
`edition_screen.dart:45` (`import 'package:table_calendar/table_calendar.dart';`) **mais jamais
instancié** dans ce fichier — aucun `TableCalendar(`, `CalendarFormat`, `RangeSelectionMode`,
`DateTimeRange` trouvé :
```
grep -n "TableCalendar(" lib/modules/data_crud/presentation/views/edition_screen.dart → (vide) RC=1
grep -n "CalendarFormat\|RangeSelectionMode\|DateRangePicker\|showDateRangePicker\|DateTimeRange" \
  lib/modules/data_crud/presentation/views/edition_screen.dart → (vide) RC=1
```
Le **seul usage vivant** de `TableCalendar` dans tout le repo est dans le module **`workflow`**
(`agenda_screen.dart:682`), un écran d'agenda **indépendant des formulaires CRUD** — pas un champ
de saisie de date/plage.

**Rendu réel du champ date DODLP** : `EditionFieldTypes.dateTime`/`time`
(`edition_screen.dart:3373-3600+`) utilise **`FormBuilderDateTimePicker`**
(`flutter_form_builder`, ligne 3601 — déjà couvert par `STUDY.md`), avec `DateFormat.yMMMd()`/
`.Hm()`/les deux selon `InputType`. **Pas de sélection de plage** (`DateTimeRange`) nulle part dans
`data_crud`.

**Package additionnel `date_time_picker` (mort aussi)** : `forms_utils.dart:10,735-...` définit
`showDateTimePicker()` (wrapper autour de `date_time_picker` pkg) mais :
```
grep -rn "showDateTimePicker(" lib --include="*.dart" | grep -v "\.bak" | grep -v "forms_utils.dart:735"
→ (vide) RC=1
```
**Aucun appelant** — `date_time_picker: ^2.1.0` (pubspec.yaml:100) est une **2ᵉ dépendance morte**
liée aux dates.

**Ce que ça signifie pour le futur champ `dateRange` zcrud** :
- DODLP **n'a jamais implémenté** de sélection de plage de dates dans ses formulaires CRUD — ni via
  `table_calendar`, ni via `showDateRangePicker` Material, ni via un widget dédié. Il n'y a donc
  **aucune contrainte de parité visuelle** à respecter pour `dateRange` — zcrud est libre de choisir
  son propre design (`showDateRangePicker` Material standard, cohérent avec le `dateTime` actuel).
- **Couverture zcrud actuelle** : **ABSENT** — ni `EditionFieldType.dateRange`, ni widget associé.
  Preuve : `grep -n "dateRange\|DateRange" packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` → RC=1 (vide).
  `EditionFieldType` liste seulement `dateTime`/`time` (pas de `date` seul ni `dateRange`).
- **Verdict** : **gap réel côté zcrud** (nouveau type à créer), mais **zéro dette de parité DODLP**
  — c'est une extension nette (FR future), pas une migration à risque. Stratégie recommandée :
  ajouter `EditionFieldType.dateRange` + `ZDateRangeFieldWidget` **natif** dans `zcrud_core`
  (réutilisant `showDateRangePicker` du SDK Flutter, cohérent avec `z_date_field_widget.dart`
  existant) — **pas besoin d'adopter `table_calendar`** (package tiers, lourd, calendrier complet
  vs simple range-picker ponctuel ; DODLP lui-même ne l'a jamais retenu pour ses formulaires).

---

## Synthèse

| Champ / pattern | Package DODLP | Couverture zcrud | Verdict |
|---|---|---|---|
| `tags` (étiquettes) | `flutter_tags` (`edition_screen.dart:2100-2187`) | **natif** `ZTagsFieldWidget` | Natif OK (écart de style théorisable, pas fonctionnel) |
| `subItems` rendu "tag" (`itemsAreTags`) | `flutter_tags` (`dynamic_list_viewer.dart:242-276`), plombé mais **0 call-site actif** trouvé | **ABSENT** (pas de variant tag dans `ZSubListFieldWidget`) | Gap mineur, priorité basse (feature non observée en usage réel DODLP) |
| `rowChips` | (hors `flutter_tags`, cf. STUDY.md) | **natif** `ZRowChipsFieldWidget` | RAS |
| Réordonnancement `subItems` | **AUCUN** (`drag_and_drop_lists` non utilisé dans `data_crud` ; aucun `Reorder*` trouvé) | **natif** `ZSubListFieldWidget._move()` (monter/descendre) | Natif OK — **supérieur** à DODLP (DODLP n'a aucun réordo) |
| Actions swipe liste | `flutter_slidable` **déclaré mais mort** (0 usage `Slidable(`) | n/a | Dépendance morte, rien à porter |
| Sections repliables (hors champ) | `expandable` (`MyStickyHeader`, `forms_utils.dart:32-110`) | Hors périmètre de cette famille | Signalé seulement (à traiter par l'étude layout/sections si elle existe) |
| Calendrier / `dateRange` | `table_calendar` **jamais utilisé en formulaire** (seul usage : `agenda_screen.dart:682`, module `workflow`, hors CRUD) ; `date_time_picker` aussi mort (`forms_utils.dart:735`, 0 appelant) | **ABSENT** (`EditionFieldType` n'a ni `date` seul ni `dateRange`) | Gap réel mais zéro dette de parité — créer natif zcrud (`showDateRangePicker` SDK), ne pas adopter `table_calendar` |

**Risques fork/licence** : aucun — dans les 3 packages du prompt-cadre pour cette famille
(`flutter_tags`, `table_calendar`, `drag_and_drop_lists`), **aucun n'a d'usage vivant justifiant
une adoption** côté zcrud. `flutter_tags` a un équivalent natif fonctionnellement suffisant ;
`table_calendar`/`drag_and_drop_lists` ne sont même pas utilisés par DODLP pour les cas qu'on
suspectait (calendrier de champ, réordo de subItems) — leurs seuls usages vivants sont dans des
modules hors CRUD générique (`workflow`/`douanes_togolaises`), donc **hors périmètre de la
migration formulaire**.
