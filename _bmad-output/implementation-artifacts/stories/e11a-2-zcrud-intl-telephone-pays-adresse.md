---
baseline_commit: fe203b90bb95a659063452af4cf584f66e7bab0f
---

# Story E11a.2 : zcrud_intl (sous-ensemble) — téléphone / pays / adresse (parité DODLP)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant zcrud dans DODLP (banc d'essai parité SM-2)**,
je veux **des champs d'édition « téléphone international » (`phoneNumber`), « pays » (`country`) et « adresse » (`address`) qui saisissent/affichent des valeurs NEUTRES (E.164 / code ISO / adresse structurée) et servent leurs constantes (indicatifs, noms, drapeaux) depuis des assets JSON chargés paresseusement**,
afin que **la parité DODLP soit atteinte AVANT E7 sans faire fuiter aucune lib intl/téléphone ni aucune constante dans le cœur (AD-1), sans reconstruction globale du formulaire (AD-2), et de façon robuste aux entrées invalides (AD-10)**.

## Contexte & cadrage

**Épopée E11a — Lot parité DODLP** (sous-ensemble MVP de geo/intl/export). E11a **précède E7** (le graphe de dépendances prime sur la numérotation : `E11a --> E7`, `E11a --> E9`). Cette story est la **deuxième d'E11a**, après E11a-1 (`zcrud_geo`, **done**), et **imite son patron** (widget servi via le seam `ZWidgetRegistry`, aucun impact cœur).

**Périmètre STRICT E11a-2 = champs téléphone + pays + adresse UNIQUEMENT.** Frontière explicite :
- **E11a-1** (fait, `done`) : `zcrud_geo` — champ géo/carte (`location`/`geoArea`).
- **E11a-3** (à venir) : `zcrud_export` — export DataGrid Excel/PDF (Syncfusion) + retrait `badCertificateCallback=>true`.
- **E11b-2** (v1.x) : `zcrud_intl` **complet** — **devise**, **états/provinces**, défauts nationaux surchargeables. **HORS périmètre ici.**

> Cette story se développe **EN PARALLÈLE d'E6 (`zcrud_markdown`) et d'E11a-3 (`zcrud_export`)**. Elle reste **strictement** dans `packages/zcrud_intl/`. **Aucune modification de `zcrud_core`** n'est nécessaire (voir *Impact zcrud_core* ci-dessous) — l'orchestrateur n'a donc **pas** à sérialiser de fichier cœur entre E11a-2, E6 et E11a-3. Si un besoin de toucher `zcrud_core` apparaît en cours de dev → **STOP + signalement à l'orchestrateur** avant toute édition du cœur (risque de conflit avec E6/E11a-3).

### État réel du terrain (vérifié sur disque)

- **E1..E6 avancés, E11a-1 `done`.** Le cœur fournit tout ce qu'il faut : ces champs n'exigent **rien de neuf** dans `zcrud_core`.
- **Les valeurs d'enum `EditionFieldType.phoneNumber` / `.country` / `.address` existent déjà** (`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`, lignes 106 / 109 / 112 — livrées en E3-3a). **Ne pas ajouter de valeur d'enum.**
- **Le routage est déjà en place** : `familyOf` (`edition_field_family.dart`, lignes 190-192) classe `phoneNumber`/`country`/`address` dans **`EditionFamily.registryOrFallback`** — exactement comme `location`/`geoArea`.
- **Le dispatcher route déjà ces types via le registre injecté** : `ZFieldWidget` (`z_field_widget.dart`, ligne 411 `case registryOrFallback:`, ligne 438) :
  ```dart
  final registry = ZcrudScope.maybeOf(context)?.widgetRegistry;
  final builder  = registry?.tryBuilderFor(field.type.name); // kind = "phoneNumber" | "country" | "address"
  if (builder == null) return ZUnsupportedFieldWidget(field: field); // repli contrôlé, jamais d'exception
  return builder(context, ZFieldWidgetContext(field: field, value: <slice>, onChanged: <setValue>));
  ```
  Le builder est appelé **DANS** la frontière de rebuild (`ZFieldListenableBuilder`, value-in-slice). La granularité AD-2 au niveau de la tranche est **déjà assurée par le cœur** ; nos widgets n'ont qu'à respecter AD-2 **en interne** (contrôleur/focus stables, jamais recréés).
- **Le contrat du registre est figé** (`z_widget_registry.dart`) : `ZFieldWidgetBuilder = Widget Function(BuildContext, ZFieldWidgetContext ctx)` ; `ctx.field` (spec `const`), `ctx.value` (tranche courante), `ctx.onChanged` (écriture, branché sur `setValue`). `register(kind, builder)` **throw** sur collision ; `tryBuilderFor` retourne `null` (chemin défensif du repli).
- **`zcrud_intl` est un squelette** : `pubspec.yaml` (dépend uniquement de `zcrud_core: ^0.0.1`, **pas** encore package Flutter), barrel `lib/zcrud_intl.dart`, marqueur `lib/src/domain/z_intl_api.dart`. C'est ici que vivent modèles de valeur, widgets, assets et chargeur.

### ADs applicables (NON-NÉGOCIABLES)

- **AD-1** — `zcrud_intl → zcrud_core` seulement ; les libs intl/téléphone (`phone_numbers_parser`, etc.) et les **assets de constantes** ne fuient **jamais** dans `zcrud_core` ; graphe acyclique + **CORE OUT=0** préservés.
- **AD-2 / SM-1** — champs à **contrôleur(s)/focus isolés stables** (create `initState` / `dispose`, jamais recréés), `ValueKey(field.name)` déjà posé par l'assembleur du cœur, rebuild ciblé à la tranche, focus préservé pendant la frappe (numéro, ligne d'adresse). Interdits : `setState` de formulaire, ré-injection de valeur dans le contrôleur pendant la frappe (sync guardée hors focus).
- **AD-4** — widgets fournis par le satellite et **enregistrés** dans `ZWidgetRegistry` (instanciable, injecté ; jamais un singleton statique mutable). `kind` = **nom d'enum** (`"phoneNumber"`, `"country"`, `"address"`), aligné sur la convention `ZTypeRegistry`.
- **AD-10** — parse **défensif** : numéro non parsable / indicatif inconnu / code pays absent d'un catalogue / map d'adresse corrompue / valeur de tranche `null` → état neutre/vide, **jamais** de crash ni d'exception remontant au parent (`fromMapSafe → null`, `@JsonKey(defaultValue)`, `unknownEnumValue`). Assets manquants/malformés → catalogue vide, jamais un throw.
- **AD-12** — **AUCUN secret** dans `zcrud_intl` (aucune clé d'API de géocodage/validation d'adresse, aucun endpoint en dur non surchargeable, **jamais** `badCertificateCallback => true`). Le sous-ensemble MVP est **hors-ligne** (parse local + assets bundlés) — pas d'appel réseau.
- **AD-13** — RTL (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional`), `Semantics` explicites, cibles tactiles **≥ 48 dp**, thème **injecté** via `ZcrudTheme.of(context)` (repli `Theme.of(context)`) — **aucune** couleur/style codé en dur. Libellés via `ZcrudScope.labels` (l10n injectée), fallback textuel.
- **AD-14/AD-15** — couche `domain/` des modèles de valeur = **Dart pur** (aucun Flutter, aucune lib intl en signature publique) ; **aucun** gestionnaire d'état importé (primitives Flutter uniquement) ; la présentation (widgets) peut dépendre de Flutter.

## Conception (résumé pour le dev)

### 1. Modèles de valeur NEUTRES (couche `domain/`, pur-Dart, sérialisables)

Chaque valeur de tranche est **neutre** — que des `String`/`Map`, aucun type de lib téléphone/intl :

- **`ZPhoneNumber`** (valeur de tranche pour `phoneNumber`) : `{ String? isoCode; /* ISO 3166-1 alpha-2, ex. "NE" */ String? dialCode; /* "+227" */ String? nationalNumber; String? e164; /* "+22790000000" */ }`. **Représentation canonique persistée = `e164`** (chaîne opaque) ; les autres champs facilitent l'édition/affichage. `toMap`/`fromMap` + `fromMapSafe → null` défensif (numéro non parsable, indicatif inconnu, champs absents). La (dé)normalisation E.164 est faite **dans la couche presentation** via la lib (pas dans le modèle pur).
- **`ZCountry`** (valeur de tranche pour `country`) : la **valeur persistée = le code ISO alpha-2 `String` opaque** (canonique §« `id` String opaque »). Un **modèle enrichi** `ZCountryInfo { String isoCode; String? name; String? dialCode; String? flagEmoji; }` sert **uniquement** le picker (source = asset JSON), il n'est **pas** forcément la valeur de tranche (garder la tranche = code ISO string pour parité/simplicité DODLP ; documenter le choix). `fromMapSafe` défensif : code inconnu/absent → `null`.
- **`ZPostalAddress`** (valeur de tranche pour `address`) : `{ String? line1; String? line2; String? city; String? region; String? postalCode; String? countryCode; String? formatted; }`. Structurée + sérialisable ; `toMap`/`fromMap` + `fromMapSafe → null` défensif (map corrompue, tous champs vides → adresse vide neutre, jamais throw).
- **Agnostique lib** : aucun type `PhoneNumber`/`IsoCode` d'une lib dans la signature publique. Round-trip `toMap→fromMap` stable. Enums éventuels (aucun requis a priori) en camelCase + `@JsonKey(unknownEnumValue:)`.

### 2. Catalogue de constantes en **assets JSON paresseux** (FR-21, AD-1)

- **Asset bundlé dans `zcrud_intl`** : `lib/assets/countries.json` (ou `assets/`) — liste `[{ "iso": "NE", "name": "Niger", "dialCode": "+227", "flag": "🇳🇪" }, …]`. Déclaré au `pubspec.yaml` de `zcrud_intl` sous `flutter: assets:` (chemin **package** `packages/zcrud_intl/...` au chargement).
- **Chargeur paresseux** `ZCountryCatalog` (couche `data`/`presentation`) : charge via `rootBundle.loadString('packages/zcrud_intl/assets/countries.json')` **à la première demande**, **parse défensif** (JSON malformé → catalogue vide, jamais throw), **met en cache** le résultat (lecture seule, immuable → un cache partagé est légitime car **aucune ressource disposable** ; ce n'est PAS un contrôleur). Le catalogue est **injectable/surchargeable** (paramètre optionnel) pour tests et pour éviter un défaut national codé en dur non surchargeable.
- **Pas de secret, pas de réseau** : tout est bundlé et local (AD-12).

### 3. Widgets de champ (patron AD-2), servis via factories enregistrables

Trois `StatefulWidget` (ou un widget paramétré par mode), branchés via des **factories de builder** :

- **`ZPhoneFieldWidget`** : champ numéro + sélecteur d'indicatif/pays lié. `TextEditingController`/`FocusNode` pour le numéro créés **1× en `initState`**, `dispose` en `dispose`, **jamais** recréés ni ré-injectés pendant la frappe (sync guardée hors focus). L'indicatif pays modifie la valeur E.164 émise. Écrit un `ZPhoneNumber` neutre via `ctx.onChanged`. Parse/format **via la lib** (`phone_numbers_parser`), confiné à la presentation.
- **`ZCountryFieldWidget`** : sélecteur de pays (recherche + liste depuis `ZCountryCatalog`). Émet le **code ISO string** via `ctx.onChanged`. Pas de `TextEditingController` requis hors champ de recherche (créé/disposé proprement s'il existe).
- **`ZAddressFieldWidget`** : sous-formulaire d'adresse structurée (lignes, ville, région, code postal, pays). Un `TextEditingController`/`FocusNode` **stable par sous-champ** (`late final`, créés 1× en `initState`, disposés), sync guardée hors focus. Émet un `ZPostalAddress` neutre via `ctx.onChanged`. Réutilise `ZCountryFieldWidget` pour le pays.
- **Factories** : `ZPhoneFieldWidget.builder({ZCountryCatalog? catalog}) → ZFieldWidgetBuilder` (idem `country`/`address`). Le catalogue est **capturé par closure** → **aucun** nouveau slot dans `zcrud_core`, **aucun** `ZcrudScope` étendu. L'app enregistre `registry.register('phoneNumber', ZPhoneFieldWidget.builder(...))`, `'country'`, `'address'`.
- **Anti-fuite (learning E5)** : tout `TextEditingController`/`FocusNode` disposé. Le catalogue partagé n'est PAS disposable (lecture seule) → pas d'« instance-par-montage » requise pour lui ; en revanche **chaque contrôleur/focus est bien par-montage** (jamais aliasé entre deux champs). Si un widget venait à posséder une ressource disposable, appliquer le patron **fabrique → instance possédée en `initState` → `dispose`** (cf. remédiation MAJEUR-1 d'E11a-1).

### 4. Isolation (AD-1)

Les libs intl/téléphone et les assets ne sont déclarés **qu'au** `pubspec.yaml` de `zcrud_intl` ; **aucun** type lib ne fuit dans `zcrud_core`, ni dans les valeurs de tranche, ni dans les signatures publiques du barrel `lib/zcrud_intl.dart` ; **aucun** secret dans le package.

### 5. Défensif (AD-10)

Numéro non parsable, indicatif/code pays inconnu, adresse absente/corrompue, asset manquant/malformé, valeur de tranche `null` → état neutre/vide, jamais de throw remontant au parent.

## Impact zcrud_core

**NON — aucune modification de `zcrud_core`.** Justification vérifiée sur disque :
- Les valeurs d'enum `phoneNumber`/`country`/`address` **existent déjà** (`edition_field_type.dart` l. 106/109/112, E3-3a).
- Le routage `familyOf → registryOrFallback` **existe déjà** pour ces trois types (`edition_field_family.dart` l. 190-192).
- Le seam `ZWidgetRegistry` + le dispatch `tryBuilderFor(field.type.name)` + le repli `ZUnsupportedFieldWidget` **existent déjà** (E3-3a/E3-3b-1) et sont **prouvés par E11a-1**.
- Le catalogue de pays est **capturé par closure** dans les factories de builder → **pas** besoin d'ajouter un slot à `ZcrudScope`.

→ **Aucune sérialisation de fichier cœur à prévoir avec E6/E11a-3.** Si un besoin de toucher `zcrud_core` émergeait (p. ex. slot d'injection dans `ZcrudScope`), **STOP + signalement à l'orchestrateur** avant d'éditer le cœur. La conception ci-dessus est faite pour l'éviter.

## Acceptance Criteria

1. **Modèles de valeur neutres & sérialisables (AD-1/AD-14).** `ZPhoneNumber` (E.164 + isoCode/dialCode/nationalNumber), `ZPostalAddress` (adresse structurée) et le code pays (`String` ISO alpha-2 comme valeur de tranche `country`, avec `ZCountryInfo` pour le picker) vivent dans `zcrud_intl` (`domain/`, pur-Dart), exposent `toMap/fromMap` (ou codegen), round-trip stable. **Aucun** type de lib intl/téléphone (`PhoneNumber`, `IsoCode`, …) n'apparaît dans leur API publique. *Test : round-trip `toMap→fromMap` des 3 modèles ; `dart analyze` ; grep signatures sans type lib.*
2. **Champs servis via le registre (AD-4).** `ZPhoneFieldWidget.builder`, `ZCountryFieldWidget.builder`, `ZAddressFieldWidget.builder` renvoient chacun un `ZFieldWidgetBuilder` enregistrable sous les `kind` `"phoneNumber"`, `"country"`, `"address"` dans `ZWidgetRegistry` ; via un `ZcrudScope(widgetRegistry: …)`, un champ de chaque type rend le widget intl (et non `ZUnsupportedFieldWidget`). *Test widget : registre peuplé → widget intl présent (×3) ; registre vide → repli `ZUnsupportedFieldWidget`, pas de crash.*
3. **L'édition met à jour la tranche (valeur neutre) (AD-2).** Saisir un numéro écrit un `ZPhoneNumber` (E.164 correct) ; choisir un pays écrit le **code ISO string** ; remplir l'adresse écrit un `ZPostalAddress` — le tout via `ctx.onChanged` ; la valeur lue du `ZFormController` est la valeur neutre attendue. *Test widget : frappe/sélection → `controller.valueOf(field)` == valeur neutre attendue (×3).*
4. **Sélecteur de pays + téléphone lié depuis l'asset paresseux (FR-21).** La liste des pays provient de `ZCountryCatalog` (asset JSON chargé **paresseusement** et mis en cache) ; le champ téléphone lie l'indicatif au pays choisi (changer le pays met à jour l'indicatif/E.164). Le catalogue est **injectable** (surchargeable en test, pas de défaut national non surchargeable). *Test widget : catalogue fake injecté → liste rendue + sélection ; téléphone : changer le pays → dialCode/E.164 mis à jour.*
5. **Validation défensive (AD-10).** Numéro non parsable / indicatif inconnu / code pays absent du catalogue / map d'adresse corrompue / valeur de tranche `null` / asset manquant ou JSON malformé → champ en état neutre/vide, **jamais** d'exception remontant au parent. *Test : table de cas (numéro « abc », `dialCode` inconnu, `countryCode` "ZZ", map adresse corrompue, tranche `null`, catalogue asset introuvable → catalogue vide) → état neutre, `returnsNormally`.*
6. **SM-1 / rebuild ciblé + focus préservé (AD-2).** Taper dans le champ numéro ou une ligne d'adresse ne reconstruit **que** la tranche du champ courant (compteur de build voisin inchangé), **zéro** perte de focus / saut de curseur ; `TextEditingController`/`FocusNode` créés **1×** (`initState`), jamais recréés. *Test widget : hooks `onInit`(==1)/`onBuild` + `expect(focusNode.hasFocus, isTrue)` après ≥2 frappes, via le vrai dispatch `DynamicEdition`.*
7. **Anti-fuite de cycle de vie (learning E5).** `dispose` libère **tous** les `TextEditingController`/`FocusNode` des trois widgets ; chaque contrôleur/focus est **par-montage** (jamais aliasé entre deux champs) ; le catalogue partagé (lecture seule) n'introduit aucune ressource non disposée. *Test : pump→pumpWidget(SizedBox) ; deux champs téléphone/adresse montés simultanément → contrôleurs distincts, aucun listener/contrôleur non disposé.*
8. **Thème injecté + RTL + a11y ≥48 dp (AD-13).** Couleurs/styles via `ZcrudTheme.of(context)` (repli `Theme.of`) — **aucune** valeur codée en dur ; libellés via `ZcrudScope.labels` (fallback) ; paddings/alignements **directionnels** ; `Semantics` explicites ; cibles tactiles (sélecteur pays, boutons) **≥ 48 dp**. *Test : rendu des 3 champs sous `Directionality.rtl` sans exception + audit statique (grep anti `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, couleur littérale).*
9. **Gate isolation — `zcrud_core` ne tire AUCUNE lib intl (AD-1).** Le `pubspec.yaml` de `zcrud_core` ne liste ni `phone_numbers_parser`, ni aucune lib téléphone/intl/country ; ces libs et l'asset `countries.json` n'apparaissent qu'au `pubspec.yaml` de `zcrud_intl`. *Test/gate : assertion sur les dépendances (script/grep) ; `melos run verify` / graph_proof **CORE OUT=0** ; `dart pub deps` de `zcrud_core` sans lib intl.*
10. **Aucune fuite de type lib intl (AD-1, signature).** Ni les valeurs de tranche, ni l'API publique de `zcrud_intl` (barrel `lib/zcrud_intl.dart`) n'exposent un type d'une lib intl/téléphone ; ces types restent **internes** aux widgets de presentation. *Test : inspection des exports du barrel + `dart analyze` ; le barrel n'exporte pas de symbole lib tiers.*
11. **Gate secrets — AUCUN secret dans le package (AD-12).** Aucune clé d'API (géocodage/validation), aucun token, aucun endpoint réseau en dur ; aucun `badCertificateCallback => true`. Sous-ensemble MVP **hors-ligne**. *Gate : scan de secrets (E1-3/E2-10) vert sur `zcrud_intl` ; grep négatif.*
12. **Vérif verte rejouée.** `melos run generate` OK → `dart analyze` RC=0 → `flutter test` RC=0 sur `zcrud_intl` (et workspace inchangé, `melos list` = 14). *Gate `done`.*

## Tasks / Subtasks

- [x] **T1 — Modèles de valeur neutres** (AC: 1, 5, 10)
  - [x] `lib/src/domain/z_phone_number.dart` : `ZPhoneNumber` (isoCode/dialCode/nationalNumber/e164), `toMap`/`fromMap` + `fromMapSafe → null` défensif.
  - [x] `lib/src/domain/z_postal_address.dart` : `ZPostalAddress` (adresse structurée), parse défensif (map corrompue → null, tous vides → adresse neutre).
  - [x] `lib/src/domain/z_country_info.dart` : `ZCountryInfo` (iso/name/dialCode/flag) pour le picker ; documenter que la **valeur de tranche `country` = code ISO string**.
  - [x] Barrel : n'exporter que les modèles neutres (pas de type lib tiers).
- [x] **T2 — Catalogue pays en asset JSON paresseux** (AC: 4, 5, 11)
  - [x] `lib/assets/countries.json` (iso/name/dialCode/flag) — 245 pays (dial codes autoritatifs `phone_numbers_parser`, drapeaux emoji), couvre la parité DODLP.
  - [x] `lib/src/data/z_country_catalog.dart` : chargeur `rootBundle` **paresseux + cache**, parse défensif (JSON malformé/asset absent → catalogue vide), **injectable/surchargeable** (`fromList`, `bundle`) ; asset déclaré au `pubspec.yaml`.
- [x] **T3 — Widget téléphone (patron AD-2)** (AC: 2, 3, 4, 6, 7, 8)
  - [x] `lib/src/presentation/z_phone_field_widget.dart` : `StatefulWidget`, contrôleur/focus numéro `late final` (create `initState` / `dispose`), sync guardée hors focus, sélecteur d'indicatif lié au pays, écriture `ctx.onChanged` (E.164). Factory `ZPhoneFieldWidget.builder({ZCountryCatalog?, defaultIsoCode})`. Parse/format via `phone_numbers_parser` confiné dans `z_phone_codec.dart`.
- [x] **T4 — Widget pays (patron AD-2)** (AC: 2, 3, 4, 8)
  - [x] `lib/src/presentation/z_country_field_widget.dart` : sélecteur recherche+liste (`z_country_picker_field.dart`) depuis `ZCountryCatalog`, émet le code ISO string via `ctx.onChanged`, contrôleur de recherche disposé, thème/RTL/≥48 dp. Factory `.builder({ZCountryCatalog?})`.
- [x] **T5 — Widget adresse (patron AD-2)** (AC: 2, 3, 6, 7, 8)
  - [x] `lib/src/presentation/z_address_field_widget.dart` : sous-formulaire structuré, contrôleur/focus **par sous-champ** `late final` (create `initState` / `dispose`), sync guardée hors focus, réutilise le champ pays, émet `ZPostalAddress`. Factory `.builder({ZCountryCatalog?})`.
- [x] **T6 — Barrel & exports** (AC: 10)
  - [x] `lib/zcrud_intl.dart` : modèles neutres + `ZCountryCatalog` + les 3 factories ; **aucun** symbole de lib tiers (pont `z_phone_codec` non exporté).
- [x] **T7 — Tests** (AC: 1-8, 10) — 53 tests verts (voir *Stratégie de tests*).
- [x] **T8 — Gates** (AC: 9, 11, 12)
  - [x] Assertion dépendances (`zcrud_core` sans lib intl), scan secrets vert, `analyze`+`test` RC=0, `graph_proof` CORE OUT=0, `dart pub get --dry-run` OK, `melos list`=14. (Pas de codegen dans `zcrud_intl` → `generate` sans objet.)

## Stratégie de tests

- **Unitaires modèle (pur-Dart)** : round-trip `ZPhoneNumber`/`ZPostalAddress`/`ZCountryInfo` ; table défensive AD-10 (numéro non parsable, indicatif/code pays inconnu, map d'adresse corrompue, tranche `null`).
- **Catalogue** : chargement paresseux depuis un asset de test ; asset absent / JSON malformé → catalogue vide (pas de throw) ; cache (2ᵉ lecture sans re-parse) ; catalogue injecté (fake) surchargeable.
- **Widget** : (a) registre peuplé → widget intl (×3) ; registre vide → `ZUnsupportedFieldWidget` (repli) ; (b) frappe numéro → tranche = `ZPhoneNumber` E.164 ; sélection pays → tranche = code ISO ; saisie adresse → `ZPostalAddress` ; (c) changer le pays du téléphone → dialCode/E.164 mis à jour ; (d) SM-1 : `onInit`==1, focus conservé après ≥2 frappes via le **vrai dispatch** `DynamicEdition`, compteur build voisin inchangé ; (e) `dispose` → tous contrôleurs libérés, deux champs montés → contrôleurs distincts ; (f) rendu des 3 champs sous `Directionality.rtl` sans exception.
- **Fake `ZCountryCatalog`** en test (pas d'accès disque réel) : prouve le contrat (liste/recherche/sélection) et l'injection.
- **Gates statiques** : grep anti-lib dans le barrel + `zcrud_core/pubspec.yaml` ; grep anti-secret/`badCertificateCallback` ; grep RTL (anti `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`) ; `graph_proof` **CORE OUT=0**.

## Dev Notes

### Fichiers du cœur à NE PAS modifier (lecture de référence)

- `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` — `ZWidgetRegistry`, `ZFieldWidgetBuilder`, `ZFieldWidgetContext` (le contrat que les factories doivent satisfaire ; `register` throw sur collision, `tryBuilderFor` → `null`).
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (l. 411, 430-445) — routage `registryOrFallback` → `tryBuilderFor(field.type.name)` → repli. Confirme : `kind == field.type.name` (`"phoneNumber"`/`"country"`/`"address"`), builder appelé dans la frontière de rebuild, `ctx.onChanged` = `setValue`.
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (l. 190-192) — `phoneNumber`/`country`/`address` → `registryOrFallback` (déjà classés).
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (l. 106/109/112) — `phoneNumber`/`country`/`address` déjà présents. **Ne pas ajouter d'enum.**
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — `widgetRegistry`, `theme` (`ZcrudTheme.of`), `labels`. **Ne pas** ajouter de slot ; le catalogue passe par la closure des factories.

### Patron E11a-1 à imiter (source `packages/zcrud_geo/`)

E11a-1 (`done`, **52 tests verts**) est le **gabarit direct** : modèle neutre `domain/` + widget `presentation/` `StatefulWidget` patron AD-2 + factory capturant la dépendance optionnelle par closure + barrel sans symbole tiers + gate d'isolation. Lire :
- `packages/zcrud_geo/lib/src/domain/z_geo_point.dart` (parse défensif `fromMapSafe`, bornes) — modèle de la discipline AD-10.
- `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` (contrôleur/focus `late final` en `initState`, sync guardée hors focus, `label()` l10n, `ZcrudTheme.of`, ≥48 dp) — modèle du widget AD-2/AD-13.
- `packages/zcrud_geo/test/z_geo_field_widget_test.dart` + `test/isolation_gates_test.dart` — modèles des tests widget/SM-1/isolation.
- `packages/zcrud_geo/lib/zcrud_geo.dart` — modèle de barrel (deps lourdes hors barrel principal).

### Learnings absorbés (E5 / E11a-1)

- **E5 / E11a-1 (défensif réel)** : tester les cas RÉELS (numéro « abc », indicatif/code pays inconnu, adresse corrompue, asset absent/JSON malformé) → état neutre, jamais de throw.
- **E5 / E11a-1 (anti-fuite)** : disposer **tout** `TextEditingController`/`FocusNode`.
- **E11a-1 MAJEUR-1 (instance-par-montage)** : ne **jamais** partager/aliaser une **ressource disposable** entre deux montages. Ici, le seul état partagé est le **catalogue pays immuable en lecture seule** (légitimement partageable/caché) ; en revanche **chaque contrôleur/focus reste par-montage**. Si un widget devait posséder une ressource disposable, appliquer le patron **fabrique → instance possédée en `initState` → `dispose`**.
- **E3-3b** : `ZTypeRegistry` = **codec** (pur-Dart), `ZWidgetRegistry` = **widgets** (présentation). Ces champs passent par `ZWidgetRegistry`, **pas** `ZTypeRegistry`.

### Project Structure Notes

- Tout sous `packages/zcrud_intl/lib/` : `src/domain/` (modèles neutres, pur-Dart, AD-14) ; `src/data/` (chargeur d'asset) ; `src/presentation/` (widgets, dépendent de Flutter) ; `assets/countries.json`. Barrel `lib/zcrud_intl.dart`. `*_test.dart` sous `test/`. Aucun `*.g.dart` committé.
- `pubspec.yaml` de `zcrud_intl` : devient un **package Flutter** (`flutter` en dep + `sdk: flutter`), ajoute `phone_numbers_parser` (pur-Dart, E.164), déclare l'asset `countries.json` ; **rien** dans `zcrud_core`.
- Nommage : types publics préfixés `Z` (`ZPhoneNumber`, `ZPostalAddress`, `ZCountryInfo`, `ZCountryCatalog`, `ZPhoneFieldWidget`, `ZCountryFieldWidget`, `ZAddressFieldWidget`) ; fichiers snake_case ; enums persistés camelCase ; valeur `country` = code ISO alpha-2 `String` opaque (canonique).

### Latest tech (à confirmer via `pub` au dev — versions indicatives 2026)

- **Téléphone (recommandé, pur-Dart, sans clé) :** `phone_numbers_parser` (≈ ^9.x) — parse/valide/formate en **E.164**, métadonnées bundlées **dans le package** (aucun asset runtime externe, aucun réseau) → alignement AD-1/AD-12 optimal. Alternative : `libphonenumber_plugin` (native, plus lourd) — **non recommandé** (fuite plateforme). Confirmer la version au dev.
- **Pays / indicatifs / drapeaux :** **asset JSON bundlé dans `zcrud_intl`** (`countries.json`) chargé paresseusement (FR-21), **plutôt** qu'une lib `country_picker` (évite un widget imposé et garde le rendu sous notre contrôle thème/RTL). Le flag = **emoji** (`String`), pas d'image.
- **Adresse :** MVP = sous-formulaire **structuré local** (pas de lib d'autocomplétion réseau → AD-12). L'autocomplétion géocodée = **E11b** (hors périmètre).
- Confirmer la compat SDK Dart `^3.12.2` du workspace + gate compat (E1-4, `dart pub get --dry-run`) ; Flutter du workspace (3.44.x observé en E11a-1).

### References

- [Source: epics.md#E11a — Story E11a-2] (`_bmad-output/planning-artifacts/epics/.../epics.md` l. 115) — champs téléphone international + pays + adresse à parité DODLP ; **constantes en assets JSON paresseux (FR-21)**.
- [Source: epics.md#E11b] l. 150-154 — devise/états/surcharges = E11b-2 (frontière : **hors** E11a-2).
- [Source: epics.md — chemin critique] l. 34, 46, 161 — `E11a --> E7` / `E11a --> E9` ; E11a dans le MVP.
- [Source: architecture.md#AD-1] l. 57-60 — direction de dépendance acyclique ; libs intl/assets confinées à `zcrud_intl` (`architecture.md` l. 50, 191, 239).
- [Source: architecture.md#AD-2] l. 62-71 — rebuilds granulaires, contrôleur stable.
- [Source: architecture.md#AD-4] l. 72-76 — extension par registre injecté (jamais singleton statique).
- [Source: architecture.md#AD-10] l. 102-111 — désérialisation défensive.
- [Source: architecture.md#AD-12] l. 112-116 — zéro secret ; pas de `badCertificateCallback`.
- [Source: architecture.md#AD-13] l. 117-121 — RTL/a11y/thème injecté.
- [Source: architecture.md#AD-14/AD-15] l. 122-131 — pureté des couches ; aucun gestionnaire d'état.
- [Source: zcrud_core] `z_widget_registry.dart`, `z_field_widget.dart` (l. 411/430-445), `edition_field_family.dart` (l. 190-192), `edition_field_type.dart` (l. 106/109/112), `zcrud_scope.dart`.
- [Source: E11a-1 story] `e11a-1-zcrud-geo-champ-geo-carte.md` — patron widget-via-registre, isolation, défensif, remédiation MAJEUR-1 (instance-par-montage).
- [Source: CLAUDE.md] Key Don'ts — jamais de lib intl/gestionnaire d'état dans `zcrud_core` ; jamais de secret dans un package ; thème injecté ; RTL directionnel ; cibles ≥ 48 dp ; `ListView.builder`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story)

### Debug Log References

- `flutter analyze` (zcrud_intl) → **RC=0, No issues found**.
- `flutter test` (zcrud_intl) → **RC=0, 53 tests verts**.
- `python3 scripts/dev/graph_proof.py` → **CORE OUT=0**, ACYCLIQUE OK, `out-degree(zcrud_core)=0`.
- `dart pub get --dry-run` → **RC=0** (phone_numbers_parser 9.0.24 résolu, gate compat E1-4 vert).
- `dart run melos list` → **14** packages (workspace inchangé).

#### Remédiation code-review E11a-2 (passe 2) — vérif rejouée sur disque

- `flutter analyze` (zcrud_intl) → **RC=0, No issues found** (APIs a11y non dépréciées : `isSemantics` + `SemanticsNode.owner`).
- `flutter test` (zcrud_intl) → **RC=0, 59 tests verts** (+6 : dé-dup catalogue concurrent, catalogue partagé, 3× action a11y opérable, clés canoniques `ZCountryInfo`).
- `python3 scripts/dev/graph_proof.py` → **CORE OUT=0**, ACYCLIQUE OK, 14 nœuds.
- `dart pub get --dry-run` → **RC=0**.
- `dart run melos list` → **14** packages.

### Completion Notes List

- **12/12 ACs satisfaits.** `zcrud_core` **NON touché** (confirmé : valeurs d'enum + routage `registryOrFallback` + seam `ZWidgetRegistry` déjà présents ; catalogue capturé par closure de factory → aucun slot ajouté à `ZcrudScope`).
- **Modèles neutres** (`ZPhoneNumber` E.164, `ZPostalAddress`, `ZCountryInfo`) pur-Dart, round-trip stable, `fromMapSafe` défensif (non-map/null/types corrompus → neutre, jamais de throw — AD-10).
- **Catalogue** : asset `lib/assets/countries.json` (245 pays, dial codes autoritatifs de `phone_numbers_parser`, drapeaux emoji dérivés du code ISO), chargé paresseusement via `rootBundle`, **cache** (2ᵉ lecture sans re-parse, prouvé par compteur), **injectable** (`fromList`/`bundle`). Défaut de prod = `packages/zcrud_intl/assets/countries.json` (clé consommateur).
- **Isolation (AD-1)** : `phone_numbers_parser` **confiné** au seul `z_phone_codec.dart` (gate : 1 seul importateur) ; barrel sans symbole de lib tierce (pont non exporté) ; `zcrud_core/pubspec.yaml` sans lib intl (0) ; valeurs de tranche = `ZPhoneNumber`/code ISO `String`/`ZPostalAddress` neutres, jamais un `PhoneNumber`/`IsoCode`.
- **AD-2/SM-1** : contrôleurs/focus `late final` créés 1× en `initState`, disposés ; sync guardée hors focus ; frappe → seule la tranche du champ courant se reconstruit (voisin inchangé), focus préservé (prouvé harness slice + bout-en-bout `DynamicEdition`).
- **AD-13** : thème via `ZcrudTheme.of` (repli `Theme.of`), libellés via `label()`/`ZcrudScope.labels`, insets/alignements directionnels (gate RTL statique), `Semantics` explicites, cibles ≥48 dp (gate `getSize`).
- **AD-12** : aucun secret / clé / endpoint réseau / `badCertificateCallback` (gate scan) ; MVP hors-ligne (parse local + asset bundlé).
- **Frontière E11a-2 respectée** : téléphone/pays/adresse uniquement ; devise/états/surcharges = E11b (hors périmètre). Aucune modification de `zcrud_markdown` (E6), `zcrud_export` (E11a-3), `example/`, ni sprint-status.yaml.
- **Libs/assets retenus** : `phone_numbers_parser: ^9.0.23` (résolu 9.0.24, pur-Dart, métadonnées bundlées, sans clé/réseau) ; asset `lib/assets/countries.json`.
- **Blocages** : aucun.

#### Remédiation code-review E11a-2 (passe 2) — findings traités

- **MEDIUM-1 (dé-dup charge catalogue)** — CORRIGÉ : `ZCountryCatalog.load()` mémoïse le `Future` en vol (`_loading`, effacé à la résolution) ; les appels concurrents reçoivent le **même** `Future` → asset lu/parsé **1×** (invariant « chargé une seule fois » rétabli). Chemin pré-chargé (`fromList`) commit synchrone hors `_loading`. Test ajouté : 2 `load()` concurrents → `identical(f1,f2)`, `stringLoads==1`, `assetReads==1`.
- **MEDIUM-2 (a11y opérable, AD-13)** — CORRIGÉ : action recâblée **sur le nœud `Semantics` englobant** (`onTap:`) pour le trigger pays et les items de liste (l'`ExcludeSemantics` du child est conservé, mais le nœud « bouton » porte désormais `SemanticsAction.tap`). Champ numéro tél : suppression du `Semantics(textField)`+`ExcludeSemantics` inopérable → le `TextField` expose sa sémantique éditable native (libellé via `labelText`). Tests ajoutés (×3) : action `tap` **présente ET fonctionnelle** (déclenchée via `SemanticsNode.owner.performAction` → ouvre le picker / sélectionne le pays), champ éditable exposé.
- **LOW-1 (catalogue par défaut partagé)** — CORRIGÉ : `sharedDefaultCountryCatalog()` (instance module-level lazy) utilisée par les 3 `.builder()` quand aucun `catalog` n'est injecté → une seule lecture d'asset pour les 3 kinds. Test : instance stable partagée.
- **LOW-2 (scan linéaire `_isoOf`)** — CORRIGÉ : `ZPhoneCodec` mémoïse un index `nom→IsoCode` construit 1× (remplace le scan de `IsoCode.values` à chaque appel). Aucun changement de comportement (tests codec verts).
- **LOW-3 (asymétrie clés `iso`/`isoCode`)** — DOC + TEST : clés canoniques `iso`/`flag` conservées (alignées `countries.json` ; les changer casserait le parse de l'asset) ; doc `toMap` clarifie le contrat + alias acceptés. Test verrouille les clés canoniques + round-trip symétrique.
- **Nit (rechargement e164 seul)** — DOCUMENTÉ : commentaire `initState` explicitant que l'affichage s'amorce depuis `nationalNumber` (toujours renseigné par le codec) ; ne pas dé-normaliser l'E.164 au montage (éviterait un aller-retour codec ré-injectant l'indicatif dans le national).

### File List

**Nouveaux (packages/zcrud_intl/) :**
- `lib/src/domain/z_phone_number.dart`
- `lib/src/domain/z_postal_address.dart`
- `lib/src/domain/z_country_info.dart`
- `lib/src/data/z_country_catalog.dart`
- `lib/src/presentation/z_phone_codec.dart` (pont interne confiné, non exporté)
- `lib/src/presentation/z_country_picker_field.dart` (sélecteur inline interne)
- `lib/src/presentation/z_phone_field_widget.dart`
- `lib/src/presentation/z_country_field_widget.dart`
- `lib/src/presentation/z_address_field_widget.dart`
- `lib/assets/countries.json` (245 pays)
- `test/z_intl_models_test.dart`
- `test/z_country_catalog_test.dart`
- `test/z_phone_codec_test.dart`
- `test/z_intl_field_widgets_test.dart`
- `test/isolation_gates_test.dart`

**Modifiés (packages/zcrud_intl/) :**
- `lib/zcrud_intl.dart` (barrel : exporte modèles neutres + `ZCountryCatalog` + 3 factories)
- `pubspec.yaml` (package Flutter ; `phone_numbers_parser` ; asset `countries.json`)

**Modifiés — remédiation code-review E11a-2 (passe 2) :**
- `lib/src/data/z_country_catalog.dart` (MEDIUM-1 dé-dup `_loading` ; LOW-1 `sharedDefaultCountryCatalog()`)
- `lib/src/presentation/z_country_picker_field.dart` (MEDIUM-2 `onTap` sur `Semantics` trigger + items)
- `lib/src/presentation/z_phone_field_widget.dart` (MEDIUM-2 champ numéro éditable ; LOW-1 catalogue partagé ; Nit doc)
- `lib/src/presentation/z_country_field_widget.dart` (LOW-1 catalogue partagé)
- `lib/src/presentation/z_address_field_widget.dart` (LOW-1 catalogue partagé)
- `lib/src/presentation/z_phone_codec.dart` (LOW-2 index `nom→IsoCode` mémoïsé)
- `lib/src/domain/z_country_info.dart` (LOW-3 doc contrat clés canoniques `toMap`)
- `test/z_country_catalog_test.dart` (tests MEDIUM-1 concurrent + LOW-1 partagé)
- `test/z_intl_field_widgets_test.dart` (tests MEDIUM-2 action a11y opérable ×3)
- `test/z_intl_models_test.dart` (test LOW-3 clés canoniques + round-trip)
