# Étude d'intégration — champ téléphone international (`intl_phone_number_input`)

**Lentille** : `intl_phone_number_input ^0.7.4` (DODLP) — mapping vers `zcrud_intl`
**Date** : 2026-07-17
**Portée** : lecture seule sur `/home/zakarius/DEV/dodlp-otr` et `/home/zakarius/DEV/zcrud`. Aucune écriture hors ce rapport.

---

## 1. Usage DODLP (référence, lecture seule)

### 1.1 Import & dépendance

- `lib/modules/data_crud/presentation/views/edition_screen.dart:37` — `import 'package:intl_phone_number_input/intl_phone_number_input.dart';`
- `pubspec.yaml:88` — `intl_phone_number_input: ^0.7.4+1`
- Aucun autre point d'usage du widget dans le repo (hors fichier `.bak2`, mort) :
  ```
  grep -rn "InternationalPhoneNumberInput\|tgPhoneNumber" lib -r
  ```
  → seules occurrences vivantes : `edition_screen.dart:2387` (widget), `edition_screen.dart:675` (validateur `tgPhoneNumber`), `edition_screen.dart:2402` (flag `tgPhoneNumber` dans `field.validators`), + 2 sites consommateurs qui posent le flag (`douanes_togolaises/.../operateurs_economiques_screen.dart:307`, `.../agents_screens.dart:970`).

### 1.2 Le widget — `edition_screen.dart:2376-2487` (case `EditionFieldTypes.phoneNumber`)

```dart
case EditionFieldTypes.phoneNumber:
  if (widget.readOnly) {
    return fieldValue == null
        ? const EmptyContainer()
        : readOnlyWidget(label: fieldLabel!, value: fieldValue);   // 2378-2380
  }
  validators();
  final String? stateValue = editionState[fieldName] as String?;
  final String? itemValue = fieldValue as String?;
  final stateValueInfos = getPhoneNumberISO2Code(stateValue);       // 2385
  final itemValueInfos = getPhoneNumberISO2Code(itemValue);         // 2386
  final phoneField = InternationalPhoneNumberInput(                 // 2387
    onInputChanged: (PhoneNumber? value) async { ... },             // 2388-2400
    hintText: fieldLabel,
    countries: (field.validators?["tgPhoneNumber"] == true)
        ? ["TG"]
        : WORLD_COUNTRIES.where((e) => false)...,                   // 2402-2408 — voir §1.5 (bug)
    isEnabled: widget.readOnly == false,
    locale: 'fr_TG',
    searchBoxDecoration: kFormInputDecorationTheme.copyWith(...),
    textFieldController: fieldController,
    errorMessage: "Numéro invalide",
    initialValue: (stateValue != null && stateValue.isNotEmpty)
        ? PhoneNumber(isoCode: stateValueInfos?.isoCode ?? "TG",
                      dialCode: stateValueInfos?.prefix ?? "+228",
                      phoneNumber: stateValue)                       // 2419-2424
        : itemValue == null
            ? PhoneNumber(isoCode: "TG", dialCode: "228",
                          phoneNumber: "+228        ")                // 2427-2431
            : PhoneNumber(isoCode: itemValueInfos?.isoCode,
                          dialCode: itemValueInfos?.prefix,
                          phoneNumber: itemValue),                    // 2432-2436
    ignoreBlank: !isFieldRequired,
    autoFocusSearch: false,
    spaceBetweenSelectorAndTextField: 0,
    countrySelectorScrollControlled: false,
    validator: FormBuilderValidators.compose(validators<String>()),
    keyboardType: TextInputType.phone,
    selectorConfig: const SelectorConfig(
      selectorType: PhoneInputSelectorType.DIALOG,                   // 2444
      leadingPadding: 16,
      setSelectorButtonAsPrefixIcon: true,
      useEmoji: true,
      showFlags: true,
    ),
    inputDecoration: field.fieldSize == FieldSize.large
        ? InputDecoration(border: InputBorder.none, ...)             // 2451-2467 (mode "large card", pas de bordure)
        : kFormInputDecorationTheme.copyWith(labelText: fieldLabel, ...),
  );
  if (field.fieldSize == FieldSize.large) {
    return _buildLargeCard(label: fieldLabel, prefix: field.preffix,
        prefixIcon: field.preffixIcon, prefixText: field.preffixText,
        suffixIcon: field.suffixIcon, child: phoneField);            // 2477-2486
  }
  return phoneField;                                                 // 2487
```

### 1.3 API du package tierce réellement exercée

| Prop / type | Usage DODLP |
|---|---|
| `InternationalPhoneNumberInput` (widget principal) | seul point d'entrée, pas de variante `PhoneNumberInput` pur State |
| `onInputChanged: void Function(PhoneNumber?)` | callback unique de mutation — écrit `value?.phoneNumber` (E.164/brut selon parsing interne du package) dans `editionState[fieldName]` + `invokeItemSetter` |
| `PhoneNumber({isoCode, dialCode, phoneNumber})` | construit/lit la valeur initiale ET la valeur de sortie |
| `countries: List<String>` (codes ISO2 uppercase) | restreint le sélecteur — voir bug §1.5 |
| `selectorConfig: SelectorConfig(selectorType: DIALOG, useEmoji: true, showFlags: true, setSelectorButtonAsPrefixIcon: true)` | sélecteur pays en **popup dialog modal** (liste + recherche), drapeau en **emoji**, bouton sélecteur **en préfixe** du champ texte |
| `textFieldController: fieldController` | le `TextEditingController` du champ est **fourni par l'appelant** (pas géré en interne) — cohérent avec le pattern DODLP de controllers pré-alloués par `fieldName` |
| `validator`, `errorMessage` | validation déléguée à `FormBuilderValidators.compose` (flutter_form_builder) — voir étude séparée sur `flutter_form_builder` |
| `ignoreBlank: !isFieldRequired` | permet un champ vide si non requis |
| `keyboardType: TextInputType.phone` | clavier numérique |
| `locale: 'fr_TG'` | localise le nom des pays dans le sélecteur (mais sans effet sur la restriction de liste) |
| `inputDecoration` | Material `InputDecoration` standard, deux variantes (bordé vs "large card" sans bordure) |

### 1.4 Rendu visuel

- **Champ texte unique** avec, en **préfixe**, un bouton sélecteur (drapeau emoji + indicatif) — pas deux widgets séparés.
- Le tap sur le préfixe ouvre un **`AlertDialog`/bottom modal** (selon `selectorType: DIALOG`) listant les pays avec **recherche** (boîte de recherche stylée via `searchBoxDecoration`, fond blanc dur-codé `Colors.white` — voir §1.6).
- Mode `FieldSize.large` : rendu en carte (`_buildLargeCard`), bordures supprimées, hint stylé (couleur grise conditionnée dark/light **codée en dur** `Colors.grey.shade600/400`).
- Mode lecture seule : **pas** de rendu du widget tiers — juste `readOnlyWidget(label, value)` = affichage texte brut de la valeur stockée (aucun formatage E.164→national, aucun drapeau).

### 1.5 Bug avéré dans le mapping "pays autorisés" (à NE PAS reproduire)

```dart
countries: (field.validators?["tgPhoneNumber"] == true)
    ? ["TG"]
    : WORLD_COUNTRIES
          .where((element) => false)      // ← toujours faux : liste vidée
          .map((e) => e.iso2.toUpperCase())
          .where((el) => el.trim() != "TG")
          .toList(),
```
Hors du cas `tgPhoneNumber`, la branche `else` produit **toujours une liste vide** (`.where((element) => false)` élimine tout avant le `.map`). Résultat runtime : `InternationalPhoneNumberInput(countries: [])` — le package interprète une liste vide comme **"toutes"** (comportement par défaut du package, non un filtre explicite), donc le champ fonctionne "par accident" en mode non-restreint. **Ne pas porter ce bug** dans l'adaptateur zcrud — le zcrud existant (§2) ne restreint pas la liste de pays et n'a pas cette classe de bug.

### 1.6 Style codé en dur (à ne pas porter — violerait FR-26)

- `fillColor: Colors.white` sur `searchBoxDecoration` (ligne 2414) — ignore le thème sombre.
- `color: isDark ? Colors.grey.shade600 : Colors.grey.shade400` sur le hint en mode `large` (2461-2463) — couleurs codées en dur (branchées manuellement sur `isDark` plutôt que `Theme.of(context)`/`ThemeExtension`).

### 1.7 Persistance / format de valeur

- `functions.dart:780-806` (`getPhoneNumberISO2Code`) — **heuristique locale** : si la chaîne stockée fait exactement 8 caractères, préfixe `+228` (Togo) en dur, puis tente de déduire l'ISO2 par préfixe croissant (2 à 6 caractères) via `PhoneNumber.getISO2CodeByPrefix` (API statique du package tiers). Retourne `PhoneNumberInfos{prefix, isoCode, parsednumber}`.
- La valeur persistée dans `item`/`editionState` est **`value?.phoneNumber`** brut tel que renvoyé par `onInputChanged` — **pas garanti E.164 strict** (le package renvoie souvent la saisie utilisateur peu normalisée ; DODLP recompense en relisant via `getPhoneNumberISO2Code` à l'affichage suivant). Il n'y a **aucune garantie de format canonique en base** — c'est une dette DODLP, pas une spec à reproduire.
- Validateur `tgPhoneNumber` (edition_screen.dart:675-696) : la chaîne validée est censée être la **forme nationale formatée avec espaces** (`"90 12 34 56"` = 11 caractères), préfixes autorisés `{70,71,77,78,79,90,91,92,93,96,97,98,99}`.

---

## 2. Ce qui existe DÉJÀ côté zcrud (`zcrud_intl`) — vérifié sur disque

**Finding majeur : le champ téléphone international est déjà implémenté dans `zcrud_intl`, comme un champ enregistré via `ZWidgetRegistry` sous le kind `"phoneNumber"`.** Ce n'est pas un gap à combler ex nihilo mais une story déjà livrée (marquée en commentaires `E11a-2`/`E11b-2` dans le code), avec des choix **délibérément différents** de DODLP.

```
grep -rn "phone\|Phone" packages/zcrud_intl/lib   → RC=0, ~90 occurrences (non vide)
```

### 2.1 Fichiers

| Fichier | Rôle |
|---|---|
| `packages/zcrud_intl/lib/src/domain/z_phone_number.dart` | modèle neutre `ZPhoneNumber` (E.164 + métadonnées), **aucun type de lib tierce** |
| `packages/zcrud_intl/lib/src/domain/z_national_phone_validator.dart` | validateur national **paramétrable**, pur-Dart (ni Flutter ni `phone_numbers_parser`) — la recette Togo (parité `tgPhoneNumber`) y est documentée en commentaire avec les **mêmes 13 préfixes** que DODLP |
| `packages/zcrud_intl/lib/src/presentation/z_phone_codec.dart` | **pont unique** vers `phone_numbers_parser` (parse/format E.164) — seul point d'entrée de la lib tierce dans tout le package (AD-1) |
| `packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart` | `ZPhoneFieldWidget` — le widget d'édition, servi via `ZWidgetRegistry` |
| `packages/zcrud_intl/lib/src/presentation/z_country_picker_field.dart` | `ZCountryPickerField` — sélecteur pays interne réutilisable (téléphone + champ pays + adresse) |
| `packages/zcrud_intl/lib/src/domain/z_intl_field_config.dart` | `ZIntlFieldConfig` (config additive par champ : `nationalPhone`, `preferredCountryIsos`, `searchable`, `defaultCountryIso`) |
| `packages/zcrud_intl/lib/src/presentation/z_national_phone_message.dart` | messages FR (i18n) pour `ZNationalPhoneError` |
| `packages/zcrud_intl/lib/src/data/z_country_catalog.dart` | catalogue pays bundlé (`lib/assets/countries.json`), paresseux |

### 2.2 Lib tierce choisie : `phone_numbers_parser` (PAS `intl_phone_number_input`)

`pubspec.yaml:38` — `phone_numbers_parser: ^9.0.23`, commentée explicitement comme **pur-Dart, métadonnées bundlées, SANS clé API ni réseau (AD-12)**, confinée au seul pont `z_phone_codec.dart`. C'est un choix délibéré et cohérent avec AD-1/AD-12 : `intl_phone_number_input` embarque son propre widget Material (moins contrôlable pour AD-13/FR-26/AD-2) alors que `phone_numbers_parser` n'est qu'une lib de parsing/formatage — le **widget** est écrit en interne (`ZPhoneFieldWidget`/`ZCountryPickerField`), ce qui permet de respecter nativement AD-2 (contrôleur stable), AD-13 (Semantics/RTL/48dp) et FR-26 (thème via `ZcrudTheme.of(context)`, zéro couleur en dur).

### 2.3 Conformité AD-2 (rebuild ciblé, contrôleur stable) — vérifiée dans le code

- `_numberController`/`_numberFocus` créés **1×** en `initState` (`z_phone_field_widget.dart:110-111`), jamais recréés.
- **Sync guardée** (`didUpdateWidget:130-140`) : une valeur externe n'écrase le champ texte que **hors focus** (`if (_hasNumberFocus) return;`) — exactement le patron anti-jank/anti-perte-de-focus qui est l'objectif produit n°1 de zcrud.
- Voie d'écriture unique : `_emit()` (frappe → `ZPhoneCodec.parse` → `ctx.onChanged`), jamais de `setState` de formulaire.
- `ZCountryPickerField` suit le même patron (contrôleur de recherche stable, `setState` **local** au champ uniquement).

### 2.4 Conformité AD-1 (isolation)

- Commentaire pubspec explicite : *"cette lib vit EXCLUSIVEMENT ici (jamais dans `zcrud_core`) et est CONFINÉE à l'unique pont `src/presentation/z_phone_codec.dart`. Aucun type lib (`PhoneNumber`/`IsoCode`) ne fuit ni dans `zcrud_core`, ni dans la valeur de tranche, ni dans l'API publique du barrel."*
- `zcrud_intl.dart` (barrel) exporte `ZPhoneNumber` (neutre), `ZNationalPhoneValidator`, `ZPhoneFieldWidget` — **jamais** de type `phone_numbers_parser`.

### 2.5 Conformité AD-13 / FR-26 — vérifiée dans le code

- `Semantics(container: true, label: resolvedLabel)` sur le champ complet ; `Semantics(button:, onTap:)` explicite sur le trigger du sélecteur pays avec commentaire **MEDIUM-2** documentant un piège a11y déjà corrigé (`ExcludeSemantics` qui masquait l'action native — l'action est reposée sur le nœud englobant).
- `ConstrainedBox(minHeight: 48)` sur le champ numéro ET sur chaque item de liste pays (`z_country_picker_field.dart:159`, `:260`) — cible ≥48dp.
- `EdgeInsetsDirectional.symmetric(...)` (pas `EdgeInsets.only(left:)`) — RTL.
- `TextAlign.start` partout (pas `.left`).
- Couleurs via `ZcrudTheme.of(context)` (`theme.labelColor`, `theme.gapS/M`) — **zéro couleur codée en dur**, contrairement à DODLP §1.6.

### 2.6 Parité fonctionnelle avec `tgPhoneNumber` (validateur national Togo)

`z_national_phone_validator.dart:23-49` documente **explicitement** la parité DODLP : mêmes 13 préfixes (`70,71,77,78,79,90,91,92,93,96,97,98,99`), et propose **deux variantes** (chiffres nus `length:8` vs chaîne formatée `length:11` façon DODLP) — câblage opt-in via `ZIntlFieldConfig(nationalPhone: ...)`.

### 2.7 Gap identifié : PAS ENCORE câblé en production

```
grep -rn "register(.phoneNumber.\|ZPhoneFieldWidget.builder" packages --include="*.dart" | grep -v "/test/"
→ RC=0, UNIQUE occurrence = le commentaire d'exemple dans z_phone_field_widget.dart:65 lui-même (doc, pas du code exécuté)
```
```
grep -rln "zcrud_intl" packages/zcrud_get packages/zcrud_riverpod packages/zcrud_provider
→ seul hit = un artefact de build (.dart_tool/build/.../asset_graph.json), AUCUN import source
```
**Aucun package binding (`zcrud_get`, futur consommateur DODLP) n'enregistre aujourd'hui `ZPhoneFieldWidget.builder(...)` dans un `ZWidgetRegistry`.** Le widget existe, testé unitairement (`packages/zcrud_intl/test/z_intl_field_widgets_test.dart`, `z_phone_codec_test.dart`, `z_national_phone_validator_test.dart`), mais le **câblage applicatif** (`registry.register('phoneNumber', ZPhoneFieldWidget.builder(...))`) reste à faire côté app consommatrice (DODLP, epic E7) ou dans un module d'amorçage `zcrud_get`.

---

## 3. Mapping `EditionFieldType` / kind

- DODLP `EditionFieldTypes.phoneNumber` (enum, `models.dart:73`) ↔ zcrud **kind custom `"phoneNumber"`** enregistré via `ZWidgetRegistry.register('phoneNumber', builder)` — **confirmé, pas une proposition** : c'est exactement ce que `ZPhoneFieldWidget.builder` est fait pour faire (docstring `z_phone_field_widget.dart:61-65`).
- `EditionFieldType` du cœur (`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`) n'a **pas** de valeur `phone` standard — cohérent avec le principe "type qui vit ailleurs → registre", pas une lacune.

---

## 4. Proposition d'intégration (pour la migration DODLP)

Puisque l'essentiel existe déjà, la proposition se limite au **câblage manquant**, pas à une réimplémentation :

1. **Enregistrement applicatif** (hors `zcrud_core`, hors `zcrud_intl` lui-même — dans le module de bootstrap du binding consommateur, ex. `zcrud_get` côté DODLP ou l'app DODLP post-migration) :
   ```dart
   registry.register('phoneNumber', ZPhoneFieldWidget.builder(
     catalog: sharedDefaultCountryCatalog(),
     defaultIsoCode: 'TG',   // si un défaut national est voulu (surchargeable, pas codé en dur non surchargeable — AD-12)
   ));
   ```
2. **Mapping du flag `tgPhoneNumber` legacy** → `ZFieldSpec.config = ZIntlFieldConfig(nationalPhone: <variante A ou B ci-dessus §2.6>)`. À trancher : DODLP valide la forme **formatée avec espaces** (`length:11`) — la variante B (`digitsOnly:false`) est la parité **stricte**, la variante A (`length:8`, chiffres nus) est plus propre mais change le comportement observable (message d'erreur déclenché à un seuil de saisie différent). **Recommandation : variante A** (chiffres nus) comme cible propre, avec un test explicite de non-régression sur le comportement utilisateur (nombre de chiffres avant erreur), car `ZPhoneNumber.nationalNumber` de `ZPhoneCodec` normalise déjà en chiffres nus — la variante B nécessiterait de recomposer artificiellement les espaces, contraire à l'esprit "neutre" du modèle.
3. **Persistance** : le kind `phoneNumber` de zcrud émet un `ZPhoneNumber` neutre (E.164 canonique + `nationalNumber` + `isoCode`), sérialisable via `ZPhoneNumber.fromMapSafe`/`toMap` (désérialisation défensive AD-10) — **format strictement meilleur** que la chaîne DODLP peu-normalisée (§1.7). Migration de données : prévoir un script de backfill qui repasse chaque valeur `String` DODLP historique par `ZPhoneCodec.parse(raw, iso: 'TG')` pour obtenir un `ZPhoneNumber` propre, plutôt que de conserver le format legacy.
4. **Sélecteur pays** : `ZCountryPickerField` (inline, dépliant une liste + recherche sous le trigger) diffère visuellement du **dialog modal plein écran** de `intl_phone_number_input` (`selectorType: DIALOG`). Fonctionnellement équivalent (recherche + liste + drapeau), mais l'expérience utilisateur change (pas de modal, panneau inline) — **risque de parité perçue** à valider avec le owner produit avant migration (cf. §5).
5. **Mode lecture seule** : DODLP affiche la valeur brute non formatée (`readOnlyWidget`). `ZPhoneFieldWidget` ne semble pas avoir de branche read-only dédiée avec formatage E.164→national lisible — à vérifier dans `zcrud_core`/`ZFieldWidget` dispatcher (hors périmètre de cette lentille) si le mode lecture seule global du formulaire suffit, ou si `ZPhoneFieldWidget` doit gagner un rendu spécifique lecture seule (actuellement `field.readOnly` désactive juste l'édition du `TextField`/picker mais garde le même layout à deux widgets — pas un simple texte).

---

## 5. Risques de parité identifiés

| Risque | Détail |
|---|---|
| **Sélecteur visuel** | Dialog modal (DODLP) vs panneau inline dépliant (zcrud) — changement UX perceptible par les utilisateurs habitués à DODLP. |
| **Drapeaux** | Les deux utilisent des emoji drapeau (`useEmoji: true` DODLP / `flagEmoji` zcrud) — rendu dépendant de la police système, risque de glyphes manquants identique des deux côtés (pas un delta). |
| **Format de persistance** | Legacy DODLP = `String` peu-normalisée ; zcrud = `ZPhoneNumber` structuré. Nécessite un plan de migration de données (backfill), pas seulement un mapping de widget. |
| **Longueur/préfixes du validateur national** | Deux variantes possibles (chiffres nus vs formaté) donnant des seuils d'erreur différents — décision produit à trancher explicitement, pas seulement technique. |
| **Restriction de pays** | DODLP a un bug qui neutralise de facto la restriction hors Togo (§1.5) ; `ZCountryPickerField`/`ZPhoneFieldWidget` n'implémentent pas de restriction de pays par défaut (`preferredCountryIsos` ne fait que réordonner, pas filtrer) — à confirmer si une restriction stricte est un besoin réel ou un artefact du bug DODLP à ne pas reproduire. |
| **Mode lecture seule** | Pas de rendu formaté dédié identifié pour `ZPhoneFieldWidget` en lecture seule (§4.5) — à creuser au niveau du dispatcher `ZFieldWidget`. |

---

## 6. Questions ouvertes

1. Le câblage `registry.register('phoneNumber', ...)` doit-il vivre dans `zcrud_get` (binding GetX, consommateur prioritaire DODLP) comme un enregistrement par défaut, ou rester à la charge exclusive de l'app DODLP au moment d'E7 ?
2. Variante A (chiffres nus) vs B (formatée) du `ZNationalPhoneValidator` Togo — décision produit à figer avant E7.
3. Faut-il un rendu lecture-seule dédié pour `ZPhoneFieldWidget` (texte formaté + drapeau, sans les cibles tactiles de 48dp) plutôt que le layout d'édition désactivé ?
4. Le panneau de sélection pays inline (vs dialog DODLP) est-il acceptable côté UX, ou faut-il une variante `ZCountryPickerField` en `showDialog`/`showModalBottomSheet` pour coller à l'expérience DODLP existante ?

---

## Commandes de vérification (traçabilité)

```bash
# DODLP — usage
grep -n "InternationalPhoneNumberInput\|intl_phone_number_input\|PhoneNumber(" \
  lib/modules/data_crud/presentation/views/edition_screen.dart   # → lignes 37, 2387, 2420, 2427, 2432
grep -n "intl_phone_number_input" pubspec.yaml                    # → ligne 88
grep -rn "InternationalPhoneNumberInput\|tgPhoneNumber" lib -r     # → RC=0, sites listés §1.1

# zcrud_intl — existant
grep -rn "phone\|Phone" packages/zcrud_intl/lib                   # → RC=0, ~90 lignes (non vide)
grep -rn "register(.phoneNumber.\|ZPhoneFieldWidget.builder" packages --include="*.dart" | grep -v "/test/"
                                                                    # → RC=0, seul hit = docstring (pas de câblage prod)
grep -rln "zcrud_intl" packages/zcrud_get packages/zcrud_riverpod packages/zcrud_provider
                                                                    # → seul hit = artefact de build, aucun import source
```
