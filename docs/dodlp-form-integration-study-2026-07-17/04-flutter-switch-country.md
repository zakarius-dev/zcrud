# Étude d'intégration — `flutter_switch` ^0.3.2 (booléen) + `country_picker` ^2.0.23 (pays)

> Étude read-only. Aucune modification de code zcrud. Repos DODLP/IFFD/lex_douane/DLCFTI en lecture seule.

## 0. Résumé exécutif

| Package DODLP | Usage réel dans le moteur data_crud | Statut | Verdict |
|---|---|---|---|
| `flutter_switch` ^0.3.2 | `EditionFieldTypes.boolean` — actif | En production | **Pas d'adaptateur nécessaire** — `SwitchListTile` Material thémé, **déjà livré** dans `zcrud_core`, couvre la parité fonctionnelle avec un delta visuel mineur et acceptable |
| `country_picker` ^2.0.23 | case `EditionFieldTypes.country` | **Code mort** (deprecated, `onSelect` no-op) — le champ pays réel de DODLP est un `EditionFieldTypes.select` sur `WORLD_COUNTRIES` | **Rien à porter** — `zcrud_intl` a déjà un picker pays maison (`ZCountryPickerField`/`ZCountryFieldWidget`) plus riche et 100% conforme AD-2/AD-13/FR-26, sans dépendance tierce |

Les deux lentilles concluent à **zéro travail de portage** : zcrud a déjà, dans le cœur ou dans `zcrud_intl`, une solution native qui couvre (ou dépasse) ce que DODLP fait avec ces deux packages.

---

## 1. `flutter_switch` ^0.3.2 — champ booléen

### 1.1 Usage DODLP

- Déclaration : `dodlp-otr/pubspec.yaml:92` → `flutter_switch: ^0.3.2`.
- Import : `lib/modules/data_crud/presentation/views/edition_screen.dart:33` → `import 'package:flutter_switch/flutter_switch.dart';`
- Site d'usage unique dans le moteur CRUD : `edition_screen.dart:1591-1668`, case `EditionFieldTypes.boolean`.

```dart
// edition_screen.dart:1629-1659
FlutterSwitch(
  disabled: widget.readOnly || field.readOnly,
  showOnOff: true,
  activeText: tr.yesText,
  inactiveText: tr.noText,
  activeColor: kSuccessColorLight,
  inactiveColor: Colors.grey.shade400,
  activeTextColor: Colors.white,
  inactiveTextColor: Colors.white,
  toggleSize: 20,
  width: 65,
  height: 30,
  valueFontSize: 12,
  borderRadius: 20,
  value: field.stateValue == null ? fieldValue ?? false : _initialValue<bool>()!,
  onToggle: (value) async {
    item = invokeItemSetter(item, attribute: fieldName, value: value);
    await field.onChange?.call(item: item, value: value, state: editionState);
    setState(() {});
  },
),
```

Second site (fichier `.bak2`, backup non actif, ignoré comme référence de production) : `edition_screen.dart.bak2:954` — même pattern, sans intérêt pour la parité.

**Confirmation d'unicité du site d'usage** :
```
grep -rn "FlutterSwitch\|flutter_switch" lib/modules/data_crud/ --include="*.dart"
→ 2 occurrences (import + widget) dans edition_screen.dart ; le seul autre hit
  est le fichier .bak2 (backup inactif, non compilé/importé nulle part).
```

### 1.2 API réellement utilisée

- `value` (bool), `onToggle` (`ValueChanged<bool>`), `disabled`.
- Rendu : `showOnOff` + `activeText`/`inactiveText` (texte "Oui"/"Non" **incrusté dans le rail du switch**, pas au-dessus/à côté) — c'est la seule feature visuelle que `SwitchListTile` Material ne réplique pas nativement.
- Dimensionnement pixel-exact : `width: 65, height: 30, toggleSize: 20, borderRadius: 20, valueFontSize: 12` — un style de "pill switch" arrondi avec label intégré, distinct du `Switch` Material standard (rail rectangulaire, pas de texte intégré).
- Couleurs codées en dur : `kSuccessColorLight` (constante app DODLP) et `Colors.grey.shade400` — **violerait FR-26 (zcrud interdit le codé en dur)** si porté tel quel ; nécessiterait un mapping vers `Theme.of(context).colorScheme` de toute façon.

### 1.3 État constaté côté zcrud — DÉJÀ LIVRÉ

Le cœur possède déjà un widget de famille dédié :

`packages/zcrud_core/lib/src/presentation/edition/families/z_boolean_field_widget.dart` (52 lignes) :

```dart
// z_boolean_field_widget.dart:43-50
return SwitchListTile(
  value: checked,
  onChanged: field.readOnly ? null : onChanged,
  title: Text(resolvedLabel),
  contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
);
```

Enregistré dans le dispatcher de famille : `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart:465` (`case EditionFamily.boolean:`), routé lui-même depuis `EditionFieldType.boolean`.

Propriétés vérifiées :
- **AD-2** : `StatelessWidget`, aucun controller, `onChanged` remonte directement vers le `ZFormController` (pas de `setState` de formulaire) — respecte le seam "un champ = une tranche".
- **AD-13** : `SwitchListTile`/`ListTile` fournit nativement une cible ≥ 48 dp (hauteur de ligne standard) et un rôle sémantique `switch` (Semantics natif Flutter, pas de configuration supplémentaire nécessaire) ; `EdgeInsetsDirectional` (pas `EdgeInsets.only(left:)`) → RTL correct.
- **FR-26** : zéro couleur/style codé en dur — le thème vient de `Theme.of(context)` implicitement via le widget Material `SwitchListTile` (pas de `ThemeExtension` custom nécessaire pour ce champ, contrairement à `zcrud_intl` qui utilise `ZcrudTheme.of`).

### 1.4 Verdict : adaptateur ou `Switch` Material suffit-il ?

**`SwitchListTile` Material suffit — pas d'adaptateur `flutter_switch` à écrire.** Le widget est déjà en place dans `zcrud_core`, satisfait tous les invariants (AD-2/AD-13/FR-26), et n'a **aucune** dépendance tierce à isoler (`flutter_switch` n'apparaît dans **aucun** `pubspec.yaml` du monorepo zcrud — vérifié :
```
grep -rln "flutter_switch\|country_picker" --include="pubspec.yaml" packages/ example/
→ RC=1 (aucune correspondance)
```
).

Delta de parité visuelle assumé :
1. **Texte incrusté dans le rail** (`activeText`/`inactiveText` "Oui"/"Non" DANS le switch) — non répliqué ; `SwitchListTile.title` place le libellé du champ à côté, pas de texte on/off dans le rail lui-même. Impact UX mineur (perte d'un micro-affordance visuel), pas fonctionnel.
2. **Forme "pill" compacte** (65×30, coins 20) vs rail Material standard (~52×32, forme "stadium" native mais silhouette différente) — delta cosmétique.
3. Couleurs : DODLP fige `kSuccessColorLight`/`grey.shade400` en dur ; zcrud hérite de `Theme.of(context).colorScheme` — c'est un **gain** de conformité (FR-26), pas une régression, mais le vert de succès DODLP ne sera pas reproduit pixel-for-pixel sauf si l'app hôte (DODLP migré) fournit un `ColorScheme`/`ThemeData.switchTheme` équivalent au niveau de `ZcrudScope`/`MaterialApp.theme` — **c'est la voie recommandée** (thème applicatif, pas un fork du widget).

**Si la parité visuelle exacte (texte incrusté + forme pill) s'avère un critère produit dur** (pas juste "un switch qui marche"), un adaptateur `ZWidgetRegistry.register('boolean', ...)` basé sur `flutter_switch` resterait possible dans un satellite (ex. un futur `zcrud_dodlp_compat` ou directement l'app DODLP migrée qui override le kind au runtime) — mais rien ne l'impose au niveau du monorepo zcrud lui-même, et ça ajouterait une dépendance tierce (`flutter_switch`) uniquement pour un habillage. **Recommandation : ne pas l'ajouter** ; laisser DODLP migré personnaliser via thème (`SwitchThemeData`) si besoin, seam déjà disponible sans nouveau package.

---

## 2. `country_picker` ^2.0.23 — champ pays

### 2.1 Usage DODLP — le point clé : code mort

Déclaration : `dodlp-otr/pubspec.yaml:99` → `country_picker: ^2.0.23`.

Import : `edition_screen.dart:60` → `import 'package:country_picker/country_picker.dart' as country_picker;`

Site d'usage : `edition_screen.dart:1851-1916`, case `EditionFieldTypes.country` — **précédée d'un commentaire explicite de dépréciation** :

```dart
// edition_screen.dart:1851
// DEPRECATED: Country case - no longer used with EditionFieldTypes enum
case EditionFieldTypes.country: // Country
  ...
  onCountrySelect() async => country_picker.showCountryPicker(
    context: context,
    showPhoneCode: false,
    exclude: WORLD_COUNTRIES.map((e) => e.iso2).toList(),
    onSelect: (country_picker.Country country) {},   // <-- no-op, ne fait RIEN
  );
```

Preuve que `EditionFieldTypes.country` n'existe même plus dans l'énumération active de DODLP :
```
grep -n "country" lib/modules/data_crud/enumerations.dart
→ (aucune sortie, RC vide) — la valeur d'enum `country` a été retirée ;
  le `case` de edition_screen.dart est un bloc mort inatteignable en pratique
  (switch exhaustif sur un enum qui ne porte plus ce membre serait une erreur
  de compilation s'il n'existait plus DU TOUT dans le type ; ici c'est très
  probablement un reliquat toléré par le compilateur via un enum qui a gardé
  la valeur ailleurs, ou du code non exécutable en pratique — dans tous les cas
  le callback onSelect est un no-op qui ne met à jour ni l'item ni l'état).
```

Preuve que `country_picker` n'est utilisé **nulle part ailleurs** dans l'app :
```
grep -rn "country_picker\|showCountryPicker" lib/ --include="*.dart" | grep -v ".bak"
→ 3 lignes, toutes dans le bloc mort ci-dessus (import + 2 usages du même appel).
```

### 2.2 Le vrai champ pays de DODLP : `EditionFieldTypes.select` + `WORLD_COUNTRIES`

Le champ pays **réellement rendu** en production est construit par `countrySelector()` :

`edition_forms.dart:161-189` :
```dart
DynamicFormField countrySelector({...}) {
  return DynamicFormField(
    name: fieldName ?? "isoCountry",
    label: fieldLabel ?? "Pays",
    type: EditionFieldTypes.select,                       // <-- pas .country
    choiceValueKey: (item) => (item["iso2"]).toString().toLowerCase(),
    choiceLabelKey: (item) =>
        "${item["emoji"] ?? ''}  ${(item["translations"] ?? [])[tr.locale == "ar" ? "fa" : tr.locale] ?? item["name"]}",
    choiceItems: WORLD_COUNTRIES.map((Country e) => e.toMap()).toList(),  // asset statique embarqué
    onChange: ({...}) async { /* cascade vers le champ état/province */ },
    validators: {"required": isFieldRequired},
  );
}
```

Donc DODLP résout le pays via son **dispatcher `select` générique** (dropdown/liste de choix), alimenté par une liste statique `WORLD_COUNTRIES` (fichier `constants/world_countries_states.dart`) avec drapeau emoji + libellé traduit + cascade vers un champ "état/province" dépendant — **pas** via un picker modal plein-écran comme `country_picker`.

### 2.3 Ce que `zcrud_intl` fournit déjà (vérifié)

```
grep -rn "country\|Country" packages/zcrud_intl/lib
→ RC=0, ~140 correspondances (catalogue complet)
```

Composants existants, tous dans `packages/zcrud_intl/lib/src/`:

| Fichier | Rôle |
|---|---|
| `domain/z_country_info.dart` | `ZCountryInfo` — entrée de catalogue neutre (isoCode, name, dialCode, flagEmoji, traductions). Désérialisation défensive (`fromMapSafe`, AD-10). |
| `data/z_country_catalog.dart` | `ZCountryCatalog` — catalogue chargé paresseusement depuis un asset JSON, **zéro secret/zéro réseau** (`sharedDefaultCountryCatalog()`), `byIso()`, `search()`. |
| `presentation/z_country_picker_field.dart` | `ZCountryPickerField` — **sélecteur inline réutilisable** (interne, non exporté) : cible ≥48dp, recherche (`TextField`), `ListView.builder`, `preferredIsos` (= équivalent "favoris"), drapeaux emoji, indicatifs. |
| `presentation/z_country_field_widget.dart` | `ZCountryFieldWidget` — widget de champ `country` branché sur `ZWidgetRegistry` (`ZCountryFieldWidget.builder(catalog:)`, s'enregistre sous le kind `"country"`). |
| `domain/z_intl_field_config.dart` | `ZIntlFieldConfig` — `defaultCountryIso`, `preferredCountryIsos` (config déclarative par champ/app). |

`ZCountryPickerField` est aussi réutilisé en interne par `z_phone_field_widget.dart` (indicatif téléphonique) et `z_address_field_widget.dart` (pays de l'adresse) — **un seul composant pays pour 3 champs** (`country`, `phoneNumber`, `address`), cohérent avec le principe DRY du moteur.

### 2.4 Comparatif fonctionnel

| Critère | `country_picker` (DODLP, code mort) | `ZCountryPickerField` (zcrud_intl, existant) |
|---|---|---|
| Recherche | Oui (natif au package) | Oui (`TextField` + `catalog.search()`) |
| Drapeaux | Oui (emoji/asset) | Oui (`flagEmoji`) |
| Favoris/préférés | `favorite` (paramètre du package) — **non utilisé** par DODLP (`onSelect` no-op) | `preferredIsos` — implémenté et câblé (config par champ) |
| Localisation des noms de pays | Oui (l10n du package) | Traduction via `label()`/catalogue (dépend du JSON embarqué — à vérifier si couvre FR/AR comme `WORLD_COUNTRIES`) |
| Indicatif téléphonique | `showPhoneCode` (bool) | `dialCode` par entrée + mode `compact` dédié |
| Exclusion de pays | `exclude: [...]` | Non exposé actuellement (gap mineur, pas utilisé par le vrai champ DODLP `select` non plus) |
| Dépendance tierce | Oui (`country_picker` + assets internes) | **Aucune** — 100% Flutter + asset JSON interne à `zcrud_intl` |
| AD-2 (état) | Modal `showCountryPicker` = `Navigator`/route, pas de controller de formulaire — neutre vis-à-vis d'AD-2 en soi | `StatefulWidget` local, `TextEditingController`/`FocusNode` créés 1× (`initState`)/disposés (`dispose`) — conforme, rebuild local via `setState` **du champ seul** |
| AD-13 (RTL/a11y/48dp) | Non auditée (package tiers, hors contrôle zcrud) | Auditée et commentée dans le code : `Semantics` explicites, `EdgeInsetsDirectional`, `TextAlign.start`, `ConstrainedBox(minHeight: 48)`, notes MEDIUM-2 sur l'opérabilité lecteur d'écran déjà corrigées |
| FR-26 (thème) | Package tiers — thème non garanti conforme | `ZcrudTheme.of(context)` explicite, zéro couleur en dur |

### 2.5 Mapping `EditionFieldType`

- DODLP `EditionFieldTypes.select` (champ pays via `countrySelector()`) ↔ zcrud **`relation`/`select`** générique — le pattern "dropdown avec choiceItems statiques + cascade vers champ dépendant" relève du dispatcher `select` de zcrud_core, **pas** d'un kind `country` dédié.
- Le kind `country` propre de zcrud (`ZCountryFieldWidget`, enregistré via `ZWidgetRegistry.register('country', ...)`) est une **amélioration** par rapport à DODLP : un champ pays natif et typé (au lieu de bricoler un `select` générique sur une liste statique), avec cascade possible vers `phoneNumber`/`address` par le même catalogue partagé.
- Le kind `country_picker` mort de DODLP (`EditionFieldTypes.country`, non exécuté) ne mappe vers **rien** de significatif — c'est un vestige à ignorer pour la parité.

### 2.6 Proposition d'intégration

**Rien à porter depuis `country_picker`.** Deux options pour la parité DODLP, aucune ne nécessite la dépendance tierce :

1. **Option recommandée — migrer le champ pays de DODLP vers le kind `country` de `zcrud_intl`** (`ZCountryFieldWidget`/`ZCountryCatalog`), en vérifiant/complétant l'asset JSON du catalogue pour couvrir les mêmes langues que `WORLD_COUNTRIES` (FR/AR observés dans `edition_forms.dart:173`, `tr.locale == "ar" ? "fa" : tr.locale` — indice qu'un jeu de traductions clé `"fa"` existe dans les données DODLP ; à vérifier que le JSON `zcrud_intl` porte des clés équivalentes ou un mécanisme de fallback l10n `label()`).
2. **Option repli — garder le pattern `select` générique**, alimenté par un asset de pays équivalent à `WORLD_COUNTRIES`, si l'app consommatrice veut conserver exactement le rendu dropdown existant plutôt que le picker `ZCountryPickerField`. Ne nécessite aucun code zcrud nouveau (le dispatcher `select` existe déjà) — juste fournir les `choiceItems`.

Dans les deux cas : **placement hors cœur respecté** (`zcrud_intl` est déjà un satellite, `zcrud_core` n'importe rien de lourd — aucune dépendance ajoutée à `zcrud_core`), **AD-1 intact** (`zcrud_intl` dépend de `zcrud_core`, jamais l'inverse), **AD-2 intact** (widget `StatefulWidget` local au champ, pas d'état de formulaire global), **AD-13/FR-26 déjà audités** dans le code existant.

### 2.7 Risques / questions ouvertes

- **Couverture linguistique du catalogue `zcrud_intl`** : à vérifier (hors périmètre de cette étude read-only sur DODLP) que l'asset JSON de `ZCountryCatalog` couvre FR/AR/EN au même niveau que `WORLD_COUNTRIES` (le code DODLP indexe `translations["fa"]` pour l'arabe — clé à confirmer, potentiellement une confusion legacy avec le persan `fa` au lieu de `ar`, à ne **pas** reproduire).
- **Exclusion de pays** (`exclude:` de `country_picker`) : non répliquée dans `ZCountryPickerField`. DODLP ne l'utilise pas non plus dans son vrai champ pays (`select`), donc pas un blocker de parité — à signaler si un futur besoin métier (ex. restreindre à une liste de pays éligibles) apparaît.
- **Cascade pays → état/province** : `countrySelector()` de DODLP met à jour un champ dépendant (`state`/`countryStates`) au changement de pays. `zcrud_intl` a un mécanisme voisin pour `address` (`_onCountrySelected` recharge les subdivisions via `ZSubdivisionCatalog`, cf. `z_address_field_widget.dart`) — **à confirmer** que ce pattern couvre le besoin DODLP (état standalone hors du sous-formulaire adresse) ou s'il faut un point d'extension supplémentaire (`field.onChange` déjà disponible côté `ZFieldSpec`, probablement suffisant).

---

## 3. Verdict de synthèse (répondant à la question posée dans le contexte partagé)

- **`flutter_switch`** : **pas d'adaptateur** — `SwitchListTile` Material déjà livré dans `zcrud_core/.../families/z_boolean_field_widget.dart`, conforme AD-2/AD-13/FR-26, aucune dépendance tierce. Delta = cosmétique (texte incrusté dans le rail, forme "pill"), absorbable par thème (`SwitchThemeData`) côté app hôte sans fork.
- **`country_picker`** : **hors sujet pour la parité** — c'est du **code mort** côté DODLP (`onSelect` no-op, kind d'enum retiré). Le vrai champ pays DODLP est un `select` générique sur `WORLD_COUNTRIES`. zcrud possède déjà mieux : `ZCountryPickerField`/`ZCountryFieldWidget` dans `zcrud_intl`, sans dépendance tierce, avec favoris/recherche/drapeaux/indicatifs et audit AD-2/AD-13/FR-26 déjà tracé dans les commentaires du code (learnings E5, MEDIUM-2 corrigé).
- **Point commun aux deux lentilles** : dans les deux cas, **zéro nouvelle dépendance tierce à isoler**, **zéro nouveau `ZWidgetRegistry.register`** requis — les kinds `boolean` et `country` sont déjà servis nativement par le cœur/`zcrud_intl`. Le travail de "parité DODLP" pour ces deux champs se réduit à **du thème** (couleurs switch) et **du mapping de données** (catalogue pays JSON vs `WORLD_COUNTRIES`), pas à du portage de widget.
