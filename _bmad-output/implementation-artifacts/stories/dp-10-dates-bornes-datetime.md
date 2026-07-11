# Story DP.10: Dates — bornes min/max + `dateTime` combiné (parité DODLP, gaps B12+B13)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur migrant un formulaire DODLP vers zcrud,
I want que le champ date (`ZDateFieldWidget`) respecte des **bornes min/max** déclarées — soit littérales, soit dérivées d'un autre champ du formulaire (`firstDateKey`/`lastDateKey`) — et que le type `dateTime` ouvre un **picker combiné date + heure** (au lieu d'une date figée à minuit),
so that la parité DODLP soit rétablie (bornes de sélection honorées, heure réellement saisissable) **sans** casser le comportement des formulaires existants, **sans** import d'un gestionnaire d'état dans le cœur, et **sans** rebuild global du formulaire (AD-2 / objectif produit n°1).

## Contexte & source de vérité

- **Gap B12** (`docs/dodlp-edition-parity-gap.md:33`, `:131`, `:192`) — **bloquant** : `ZDateFieldWidget` hardcode `firstDate: DateTime(1900)` / `lastDate: DateTime(2100)` (`z_date_field_widget.dart:94-95`) et **ne lit ni** `ZDateConfig.firstDateKey/lastDateKey` **ni** une borne littérale (inexistante à ce jour). Toute borne DODLP est perdue.
- **Gap B13** (`docs/dodlp-edition-parity-gap.md:34`, `:132`, `:193`) — **bloquant** : pour `dateTime`, `ZDateFieldWidget` n'ouvre qu'un `showDatePicker` (`z_date_field_widget.dart:91-97`) → heure figée à minuit. DODLP ouvre un picker **combiné** date + heure.
- **DP-10 (epics)** : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md:172` — « Câbler `firstDateKey/lastDateKey` + `minDate/maxDate` ; picker combiné date+heure pour `dateTime`. [B12+B13, zcrud_core] ».

### Comportement DODLP exact (lecture réelle — `dodlp-otr`, LECTURE SEULE)

Fichiers : `lib/modules/data_crud/models.dart` (`:643-647`) et `lib/modules/data_crud/presentation/views/edition_screen.dart` (`:3372-3620`, `:720-752`).

1. **Modèle de bornes** (`models.dart:643-647`) — un champ date porte **quatre** attributs :
   - `String? firstDateKey` / `String? lastDateKey` : clés d'**un autre champ** du formulaire fournissant la borne (résolution **cross-champ**).
   - `DateTime? minDate` / `DateTime? maxDate` : bornes **littérales**.
2. **Résolution des bornes** (`edition_screen.dart:3567-3581`) — priorité **littéral d'abord, puis cross-champ** :
   ```
   _firstDate = field.minDate ?? crossField(firstDateKey)   // Timestamp→toDate ou DateTime
   _lastDate  = field.maxDate ?? crossField(lastDateKey)
   ```
   Aucune borne ⇒ `_firstDate`/`_lastDate` restent `null`.
3. **Date initiale + garde-fou anti-crash** (`:3583-3608`) :
   ```
   initalDate = _lastDate ?? _firstDate ?? now
   firstDate: (_firstDate != null && _firstDate.compareTo(initalDate) > 0) ? initalDate : _firstDate
   ```
   c.-à-d. si la borne basse est **après** la date initiale, on **replie** la borne basse sur la date initiale (évite l'assertion `initialDate >= firstDate` de Material).
4. **Picker combiné** (`:3377-3382`, `:3600-3608`) — le mode dérive d'un **sous-type** (`InputType.date` / `InputType.time` / `InputType.both`), **orthogonal** à l'enum `EditionFieldTypes` :
   - sous-type `"date"` → `InputType.date` → **date seule** (`DateFormat.yMMMd()`).
   - sous-type `"time"` → `InputType.time` → **heure seule** (`DateFormat.Hm()`).
   - sous-type `"dateTime"` → `InputType.both` → **date + heure** (`DateFormat.yMMMd().add_Hm()`).
   `FormBuilderDateTimePicker` gère le combiné en une passe ; `EditionFieldTypes.timestamp`/`dateTime`/`time` partagent **la même branche** (seul le sous-type distingue date/both/time — la persistance `timestamp` est un axe séparé, déjà couvert par **DP-11**).
5. **Type `time`** (`edition_screen.dart:3440-3559`) : picker d'heure seul (`showTimePicker`), stockage `{hour, minute}` DODLP → en zcrud déjà `HH:mm` ISO (comportement actuel de `ZDateFieldWidget`, à préserver tel quel).

**Retenu pour zcrud** (voir §Décisions) : `dateTime` par défaut ⇒ **combiné date+heure** (fix B13). Le mode **date seule** reste atteignable via la config (parité du sous-type DODLP `"date"`). Le type `time` reste inchangé.

## État actuel du code cœur (fichiers à MODIFIER — lus intégralement)

- **`packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart`** (109 l.) :
  - `StatelessWidget` **pur** (aucun `TextEditingController` — AD-2), reçoit `{field, value, onChanged}`. `value` = ISO String ou `null`.
  - `_isTime` (type `time`) → `showTimePicker` → `onChanged('HH:mm')`.
  - **Sinon** (`dateTime`) → `showDatePicker(firstDate: DateTime(1900), lastDate: DateTime(2100))` → `onChanged(picked.toIso8601String())`. **← B12 (bornes hardcodées L94-95) + B13 (date seule, pas d'heure L91-97).**
  - a11y : wrapper `Semantics(button, excludeSemantics)`, `OutlinedButton` `minimumSize: Size.fromHeight(48)`, `AlignmentDirectional.centerStart`. **À préserver.**
- **`packages/zcrud_core/lib/src/domain/edition/z_field_config.dart`** (`ZDateConfig`, L244-264) : `const ZDateConfig({firstDateKey, lastDateKey})` + `==`/`hashCode`. **`firstDateKey`/`lastDateKey` existent DÉJÀ mais ne sont PAS lus par le widget.** Pas de borne littérale. Base `abstract ZFieldConfig` `const` (AD-4).
- **`packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart`** (dispatcher, `case EditionFamily.date` L349-354) : instancie `ZDateFieldWidget(field, value, onChanged: (iso) => widget.controller.setValue(...))`. **Détient `widget.controller` (`ZFormController`)** — seul point du cœur ayant accès aux valeurs des autres champs.
- **`packages/zcrud_core/lib/src/presentation/z_form_controller.dart`** : `ZFormController extends ChangeNotifier` expose `Object? valueOf(String name)` (L109) — **API de lecture cross-champ** ; `setValue` (L117, jamais de rebuild global) ; `values` (L142).
- **`packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart`** : clés `selectDate` (L46/102), `selectTime` (L47/103). Pas de clé combinée.
- **`EditionFieldType`** (`edition_field_type.dart`) : possède `dateTime` (L59) et `time` (L61). **Aucun type `date` seul** ni `timestamp` (absorbé — cf. DP-11). **Ne PAS toucher à l'enum** : le mode date/dateTime/time est porté par la **config** (parité du sous-type DODLP, additif).

## Périmètre (STRICT)

**1 seul package : `packages/zcrud_core` (+ ses tests).** Aucun autre package touché.

Fichiers concernés :
1. `lib/src/domain/edition/z_field_config.dart` — enrichir `ZDateConfig` (bornes littérales ISO + `mode`) + nouvel enum neutre `ZDateMode`. **Additif / rétro-compatible.**
2. `lib/src/presentation/edition/families/z_date_field_widget.dart` — lire les bornes résolues + brancher le picker combiné.
3. `lib/src/presentation/edition/z_field_widget.dart` — le dispatcher **résout** les bornes (littéral + cross-champ via `controller.valueOf`) et les injecte au widget.
4. `lib/src/presentation/l10n/z_localizations.dart` — clé `selectDateTime` (en + fr), additive.
5. Tests sous `packages/zcrud_core/test/`.

**INTERDIT** : modifier `EditionFieldType` ; importer un gestionnaire d'état dans le cœur ; faire fuiter un type backend (`Timestamp`) — le cœur ne connaît que String ISO / `DateTime` ; toucher un autre package ; toucher DODLP (lecture seule) ; toucher le sprint-status.

## Décisions de conception (à respecter — lèvent toute ambiguïté)

- **D1 — Bornes littérales en String ISO-8601, PAS en `DateTime`.** `ZDateConfig` est `const` (annotations `@ZcrudField.config`). `DateTime` **n'a pas de constructeur `const`** ⇒ un champ `DateTime` casserait la constness dans une annotation. On stocke donc `minDateIso` / `maxDateIso` en **`String?` ISO-8601** (const-safe, aligné convention dates zcrud), parsés **défensivement** au runtime. (Divergence assumée vs. `DateTime` brut DODLP.)
- **D2 — Mode porté par la config, pas par l'enum.** Nouvel enum neutre `ZDateMode { date, dateTime, time }` (valeurs **camelCase**, canonique §5 ; discipline `@JsonKey(unknownEnumValue:)` non requise ici, non persisté). `ZDateConfig.mode` (`ZDateMode?`, défaut `null`). Résolution du mode par le widget :
  - `config?.mode != null` ⇒ ce mode.
  - sinon `field.type == EditionFieldType.time` ⇒ `time` ; `field.type == EditionFieldType.dateTime` ⇒ **`dateTime` (combiné)**.
  - `mode == date` ⇒ date seule (parité sous-type DODLP `"date"`).
- **D3 — Résolution des bornes au moment du tap (lazy), dans le dispatcher.** Le seul détenteur de `ZFormController` est `z_field_widget.dart`. Il injecte au widget **deux résolveurs** `ValueGetter<DateTime?>? firstDate` / `ValueGetter<DateTime?>? lastDate` (fermetures pur-Dart, aucune fuite d'état). Le widget les appelle **dans `_pick`** (au tap) → valeurs cross-champ **fraîches**, aucun abonnement réactif cross-champ, **aucun rebuild global** (AD-2). Le widget reste un `StatelessWidget` **pur et testable** (les tests injectent des getters littéraux, sans `ZFormController`).
- **D4 — Priorité de résolution (parité DODLP, ordre exact).** `firstDate = parse(minDateIso) ?? crossField(firstDateKey) ?? DateTime(1900)` ; `lastDate = parse(maxDateIso) ?? crossField(lastDateKey) ?? DateTime(2100)`. Le **littéral prime** sur le **cross-champ**, qui prime sur le **repli** `1900/2100`. → « fin du hardcode » = 1900/2100 ne sont plus la **seule** source mais l'**ultime repli** (`showDatePicker` exige `firstDate`/`lastDate` non nuls).
- **D5 — Valeur cross-champ.** Lue via `controller.valueOf(key)`, attendue en **String ISO** (convention zcrud). Tolérant : `DateTime` accepté tel quel ; toute autre valeur ou String non parsable ⇒ **borne absente** (repli). Jamais de throw (AD-10).

## Acceptance Criteria

1. **`ZDateConfig` enrichi, additif et `const`-safe.** `ZDateConfig` gagne `minDateIso` (`String?`), `maxDateIso` (`String?`) et `mode` (`ZDateMode?`), tout en conservant `firstDateKey`/`lastDateKey`. Le constructeur reste `const` et pur-données (tous champs `final`, **aucun `DateTime` littéral**, aucune closure, aucun import). `==`/`hashCode` intègrent les nouveaux champs. Le test existant `ZDateConfig const` (`edition_field_type_test.dart:230`) reste **vert** (constructeur nommé rétro-compatible : nouveaux paramètres optionnels).

2. **Nouvel enum neutre `ZDateMode`.** `enum ZDateMode { date, dateTime, time }` (valeurs camelCase) défini dans `zcrud_core` (domaine, pur-Dart), documenté, sans dépendance.

3. **Résolution du mode (D2).** `ZDateFieldWidget` détermine le mode effectif : `config.mode` s'il est non nul ; sinon dérivé du type (`time` → time, `dateTime` → **dateTime combiné**). `mode == date` ⇒ date seule.

4. **Bornes résolues et honorées — fin du hardcode (B12).** Le `showDatePicker` reçoit `firstDate`/`lastDate` **issus** de : littéral `minDateIso`/`maxDateIso` (parsé) → sinon cross-champ `firstDateKey`/`lastDateKey` (via `controller.valueOf`, parsé) → sinon repli `DateTime(1900)`/`DateTime(2100)` (D4). Test : une config `minDateIso`/`maxDateIso` fixe les bornes ; une config `firstDateKey`/`lastDateKey` pointant un champ peuplé fixe les bornes depuis la valeur de cet autre champ ; le littéral l'emporte sur le cross-champ.

5. **Seam cross-champ conforme AD-2 (D3).** La lecture des valeurs des autres champs (`ZFormController.valueOf`) vit **uniquement** dans `z_field_widget.dart` (dispatcher), qui injecte des résolveurs `ValueGetter<DateTime?>?` à `ZDateFieldWidget`. Le widget reste `StatelessWidget` **sans** `ZFormController`, **sans** `TextEditingController`, et **sans** dépendance à un gestionnaire d'état. La résolution s'effectue **au tap** (`_pick`), pas au build. Aucun `setState`/rebuild à l'échelle du formulaire (SM-1 préservé).

6. **`dateTime` = picker combiné date + heure (B13).** En mode `dateTime`, `_pick` ouvre `showDatePicker` (borné) **puis** `showTimePicker`, fusionne date + heure en **un seul `DateTime`** et notifie `onChanged(iso)`. **Préservation de l'heure** : à la ré-édition, `showDatePicker.initialDate` et `showTimePicker.initialTime` dérivent de la valeur courante ; annulation de l'étape **date** ⇒ **abandon** (aucun `onChanged`) ; annulation de l'étape **heure** ⇒ conserver la **date choisie** avec l'**heure préexistante** (ou minuit si aucune) — l'heure n'est jamais écrasée à minuit par erreur. Test : sur un champ `dateTime` avec valeur initiale à `14:30`, choisir une nouvelle date puis une nouvelle heure produit un ISO combinant les deux ; une valeur non-minuit est préservée.

7. **`date` seule et `time` inchangés.** `mode == date` ⇒ `showDatePicker` **seul** (heure non demandée ; valeur = date à minuit, ISO) — « date reste date seule ». `time` (type ou `mode == time`) ⇒ `showTimePicker` **seul**, sortie `HH:mm`, **comportement actuel strictement préservé**. Les bornes `firstDate`/`lastDate` s'appliquent à l'étape date de `date` et `dateTime` (l'heure n'est pas bornée — parité DODLP `time` traité à part).

8. **Défensif AD-10 — bornes invalides ⇒ repli, jamais de crash.** `minDateIso`/`maxDateIso`/valeur cross-champ non parsable ⇒ borne **ignorée** (repli sur le cross-champ puis 1900/2100). Incohérence `firstDate > lastDate` ou `initialDate` hors `[firstDate, lastDate]` ⇒ **repli/clamp** (parité DODLP `:3600` : si borne basse > date initiale, replier la borne basse sur la date initiale ; clamper `initialDate` dans l'intervalle) de sorte que `showDatePicker` ne reçoive **jamais** d'arguments qui déclenchent une assertion. Aucune exception propagée.

9. **Rétro-compatibilité (D4/D2).** Sans `ZDateConfig` (`config == null`) : `time` **inchangé** ; `dateTime` s'ouvre en **combiné** avec bornes de repli `1900/2100` (l'upgrade B13 est **intentionnel** et documenté — la valeur reste ISO-8601, une valeur stockée à minuit est préservée). Le **format de sérialisation** (ISO-8601 String) est **inchangé**. Les tests d'édition existants (`z_field_dispatch_test.dart`, `field_rtl_test.dart`, `reveal_all_families_test.dart`, catalogue a11y…) restent **verts**.

10. **l10n additive + a11y/RTL AD-13 préservés.** Une clé `selectDateTime` est ajoutée (maps `en` **et** `fr`), avec **repli** sur `selectDate` si absente (défensif). Le wrapper `Semantics(button, label, value, excludeSemantics)`, la cible **≥ 48 dp**, l'`AlignmentDirectional.centerStart` et l'absence de couleur codée en dur sont **conservés** ; les pickers Material héritent de la `Directionality` ambiante (RTL). Aucune régression a11y (catalogue a11y vert).

## Testing Requirements

Emplacement : `packages/zcrud_core/test/` (widget tests via `flutter_test`, `WidgetTester`, `mockNetworkImagesFor` non requis). Suivre les patterns existants (`field_rtl_test.dart`, `z_field_dispatch_test.dart`, helpers `_reference_form.dart`).

Cas obligatoires :
- **Domaine** (`test/domain/edition/`) : `ZDateConfig` avec `minDateIso`/`maxDateIso`/`mode` — constness, `==`/`hashCode` (deux configs égales ⇔ mêmes 5 champs ; différentes sinon) ; `ZDateMode` valeurs. Le test `ZDateConfig const` existant reste vert.
- **Bornes littérales (AC4/B12)** : monter `ZDateFieldWidget` (mode date) avec résolveurs issus de `minDateIso`/`maxDateIso` ; ouvrir le picker ; asserter que `firstDate`/`lastDate` du `showDatePicker` correspondent (via un `DatePickerDialog` findable, ou en interceptant les bornes par un résolveur espion). Cas **sans** config ⇒ 1900/2100.
- **Bornes cross-champ (AC4/AC5)** : via le dispatcher réel (`ZFieldWidget` + `ZFormController` avec deux champs, l'un `firstDateKey` de l'autre), peupler le champ source, ouvrir le picker du champ borné, asserter la borne dérivée. Vérifier la **priorité** littéral > cross-champ.
- **Combiné date+heure (AC6/B13)** : champ `dateTime`, valeur initiale `2026-07-11T14:30:00`; piloter `showDatePicker` puis `showTimePicker`; asserter l'ISO résultant combine la nouvelle date et la nouvelle heure ; asserter qu'annuler l'étape heure conserve l'heure préexistante (pas de minuit).
- **date seule / time (AC7)** : `mode == date` ⇒ un seul dialog (pas de `showTimePicker`) ; `time` ⇒ comportement `HH:mm` inchangé.
- **Défensif (AC8)** : `minDateIso: 'pas-une-date'` et cross-champ non parsable ⇒ aucun crash, repli 1900/2100 ; `minDateIso` > `maxDateIso` et `minDate` > date initiale ⇒ pas d'assertion `showDatePicker` (clamp appliqué).
- **Rétro-compat (AC9)** : les suites d'édition existantes restent vertes (rejouées par la vérif verte).
- **SM-1 / AD-2 (AC5)** : la sélection d'une date ne déclenche pas de rebuild des autres champs (compteur de build sur un champ voisin, pattern des tests SM-1 existants) — au minimum, asserter que `ZDateFieldWidget` reste `StatelessWidget` sans `TextEditingController` et que la lecture cross-champ passe par le dispatcher.

## Points de contact « cœur partagé » à signaler (SÉRIALISATION / CROSS-STORY)

- **`ZDateConfig` (`z_field_config.dart`) est une surface de config partagée** (même fichier que `ZTextConfig`/`ZNumberConfig`/`ZSliderConfig`/`FileFieldConfig`, touchés par DP-1 et d'autres stories de la famille champ). Modification **strictement additive** : nouveaux paramètres nommés **optionnels**, aucun champ existant renommé/supprimé, `const` préservé ⇒ aucun modèle/annotation existant ne casse. **Ne pas réordonner** les paramètres positionnels (il n'y en a pas — tous nommés). Si le générateur (`zcrud_generator`) projette un jour `ZDateConfig` depuis `@ZcrudField`, l'ajout reste compatible (paramètres optionnels).
- **Signature publique de `ZDateFieldWidget`** modifiée (ajout de `firstDate`/`lastDate` `ValueGetter<DateTime?>?` optionnels). Impact confiné au dispatcher `z_field_widget.dart` (seul appelant en prod) + tests. Rester **optionnels** (défaut `null` ⇒ repli 1900/2100) pour ne pas casser les tests montant le widget directement.
- **`z_field_widget.dart`** : ne modifier **que** le `case EditionFamily.date`. C'est le point de contact `zcrud_core` unique de cette story — si une autre story en vol écrit ce fichier, **sérialiser** (une seule story touche `z_field_widget.dart` à la fois).
- **`z_localizations.dart`** : ajout de clé **additif** (deux maps) — pas de suppression.

## Definition of Done

- [x] AC1–AC10 satisfaits, vérifiés par tests.
- [x] `melos run generate` — **sans objet** (aucune annotation `@ZcrudModel`/`@ZcrudField`/`@JsonSerializable` ajoutée/modifiée ; `ZDateMode`/bornes littérales sont du pur-Dard non projeté par le générateur — cf. story « générateur ne projette pas `ZDateConfig` à ce jour »).
- [x] `dart analyze packages/zcrud_core` RC=0 (No issues found).
- [x] `flutter test` (zcrud_core) RC=0 — 664 tests (dont 29 nouveaux DP-10 + domaine enrichi).
- [x] Aucun import gestionnaire d'état / backend ajouté au cœur ; `ZDateFieldWidget` reste `StatelessWidget` pur (résolveurs `ValueGetter<DateTime?>?` injectés par le dispatcher, résolution au tap).
- [x] Aucune régression a11y/RTL ; aucune couleur codée en dur (wrapper `Semantics`/≥48 dp/`AlignmentDirectional` préservés).
- [x] DODLP intact (lecture seule).

### Vérifs vertes rejouées (RC réels)

- `dart analyze packages/zcrud_core` → RC=0 (No issues found).
- `flutter test` (zcrud_core) → RC=0 (664 tests, All tests passed).
- `dart test test/purity/domain_entrypoint_dart_test.dart` → RC=0.
- `python3 scripts/dev/graph_proof.py` → RC=0 (ACYCLIQUE OK, CORE OUT=0 OK).
- `melos run generate` → sans objet (aucun codegen impacté).

### File List (zcrud_core uniquement)

- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` — modifié : `enum ZDateMode { date, dateTime, time }` + `ZDateConfig` enrichi (`minDateIso`/`maxDateIso`/`mode`, `==`/`hashCode`, const-safe, additif).
- `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart` — modifié : résolution du mode (D2), bornes injectées `firstDate`/`lastDate` résolues au tap (D3/D4), picker combiné date+heure (B13), clamp défensif (AC8), placeholder `selectDateTime`.
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` — modifié : `case EditionFamily.date` injecte les résolveurs via `_resolveDateBound` (littéral > cross-champ `controller.valueOf`, défensif).
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` — modifié : clé `selectDateTime` (en + fr), additive.
- `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart` — modifié : `ZDateConfig` enrichi (const/==/hashCode) + `ZDateMode`.
- `packages/zcrud_core/test/presentation/edition/dp10_date_bounds_datetime_test.dart` — créé : 29 tests (bornes littérales/cross-champ/priorité, combiné, préservation heure, date/time inchangés, défensif, StatelessWidget).

## Dev Notes

- Le seam D3 (résolveurs injectés) est le cœur de la conformité AD-2 : **ne pas** passer `ZFormController` à `ZDateFieldWidget`, **ne pas** résoudre les bornes dans `build()`, résoudre **au tap**.
- `showDatePicker` **exige** `firstDate`/`lastDate` non nuls et `initialDate ∈ [firstDate, lastDate]` — d'où le repli 1900/2100 et le clamp (AC8). Répliquer la garde DODLP `edition_screen.dart:3600` (si `firstDate > initialDate` → `firstDate = initialDate`) ; de même clamper `lastDate`/`initialDate`.
- Combiné (AC6) : `showTimePicker(initialTime: TimeOfDay.fromDateTime(dateChoisie_ou_valeurCourante))`; fusion `DateTime(d.year, d.month, d.day, t.hour, t.minute)`. `time` seul continue d'émettre `HH:mm` (ne PAS émettre un ISO complet pour `time`).
- l10n : réutiliser le helper `label(context, key)` déjà en place ; ajouter `selectDateTime` avec repli `selectDate`.

## Project Context Reference

- Architecture : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` — AD-1 (cœur out-degree 0), AD-2 (réactivité Flutter-native, rebuilds granulaires), AD-4 (extension additive), AD-10 (désérialisation défensive), AD-13 (RTL/a11y ≥ 48 dp).
- Parité : `docs/dodlp-edition-parity-gap.md` (B12 `:33/:131/:192`, B13 `:34/:132/:193`).
- Epics : `epics-zcrud-2026-07-09/epics.md:172` (DP-10).
- Précédent : DP-11 (`timestamp` persistance) — axe **persistance** séparé du présent axe **picker/bornes** ; ne pas recouper.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-11 | 0.1 | Story créée (bmad-create-story) — bornes B12 + dateTime combiné B13, périmètre zcrud_core | create-story |
