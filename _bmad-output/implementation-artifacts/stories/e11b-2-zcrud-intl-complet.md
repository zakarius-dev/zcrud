---
baseline_commit: 04aaaf0
---

# Story E11b.2 : zcrud_intl complet — devise + états/provinces + défauts nationaux surchargeables (`ZIntlFieldConfig`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant zcrud (DODLP puis lex_douane) au-delà de la parité MVP**,
je veux **compléter `zcrud_intl` avec (1) un champ/valeur DEVISE neutre servi depuis un catalogue ISO 4217 paresseux, (2) un sélecteur ÉTATS/PROVINCES dépendant du pays (catalogue ISO 3166-2 paresseux) intégré à l'adresse et disponible en widget autonome, et (3) une config additive `ZIntlFieldConfig` portant les DÉFAUTS NATIONAUX SURCHARGEABLES (pays par défaut, pays préférés, options) lue par les champs téléphone/pays/adresse existants**,
afin que **FR-21 soit complètement couvert (téléphone/pays/**devise**/**état**) sans aucun défaut national codé en dur non surchargeable, sans faire fuiter aucune lib/asset dans le cœur (AD-1), sans reconstruction globale du formulaire (AD-2), de façon défensive (AD-10), hors-ligne et sans secret (AD-12) — et EN NE MODIFIANT PAS `zcrud_core`.**

## Contexte & cadrage

**Épopée E11b — Reste géo / intl / export (v1.x/v2).** Objectif (epics.md l. 150-151) : « compléter **au-delà** du lot parité MVP ; couvre FR-20, **FR-21**, FR-8-export (reste) ; AD-12 ; dépend de E11a ». Story E11b-2 (epics.md l. 154) : « **`zcrud_intl` complet : devise + états + surcharges.** AC : devise, états/provinces ; **défauts nationaux surchargeables**. »

Cette story **prolonge** E11a-2 (`done`, 59 tests verts) qui a livré le **sous-ensemble parité MVP** : champs `phoneNumber`/`country`/`address`, modèles neutres (`ZPhoneNumber`/`ZPostalAddress`/`ZCountryInfo`), catalogue pays `ZCountryCatalog` (asset `countries.json`, 245 pays), pont téléphone confiné `z_phone_codec.dart`. **Frontière E11a-2 → E11b-2** (déclarée en E11a-2 l. 24) : la **devise**, les **états/provinces** et les **défauts nationaux surchargeables** étaient explicitement **HORS E11a-2** et **renvoyés à E11b-2** — c'est **exactement** le périmètre ici.

**Gabarit direct : E11b-1 (`zcrud_geo` complet, `done`).** E11b-1 a résolu le **même dilemme** — enrichir un satellite « au-delà du MVP » **sans nouvelle valeur d'enum `EditionFieldType`** (cœur interdit d'édition) — via une **sous-classe additive `ZGeoFieldConfig extends ZFieldConfig`** lue par-champ (`ctx.field.config`), en **réutilisant** les enums existants (`location`/`geoArea`). E11b-2 **imite ce patron** pour les défauts nationaux (`ZIntlFieldConfig`), et livre devise/états comme **widgets + modèles + catalogues composables** (voir *Décision d'architecture — routage* ci-dessous).

> Package **`packages/zcrud_intl/` UNIQUEMENT**. **Aucune modification de `zcrud_core`** (justifiée §*Impact zcrud_core*). Si un besoin RÉEL de toucher le cœur émerge (p. ex. une valeur d'enum `EditionFieldType.currency`/`.state` jugée indispensable) → **STOP + signalement à l'orchestrateur** AVANT toute édition du cœur.

### Décision d'architecture — routage devise/états SANS nouvelle valeur d'enum (NON-NÉGOCIABLE)

**Constat vérifié sur disque** (`edition_field_type.dart`) : les valeurs d'enum `phoneNumber`/`country`/`address` existent (l. 106/109/112) ; **il n'existe AUCUNE valeur `currency`/`state`/`province`**, et E11b-2 **ne peut pas** en ajouter (cœur figé). Contrairement à E11b-1 (qui a **réutilisé** `location`/`geoArea` pour enrichir la géométrie « cercle » via config), la devise et l'état **n'ont aucun enum existant à réutiliser** pour un routage `registryOrFallback` par `field.type.name`.

**Décision (pragmatique, zéro core-change) — l'épopée exige des CAPACITÉS (« devise, états/provinces »), pas des `EditionFieldType` de premier rang :**
1. **Défauts nationaux surchargeables → config additive `ZIntlFieldConfig extends ZFieldConfig`**, lue via `ctx.field.config` par les widgets **déjà routés** `phoneNumber`/`country`/`address`. **Exactement** le patron E11b-1 (`ZGeoFieldConfig`), **zéro** modification cœur. C'est le livrable qui répond littéralement à « défauts nationaux surchargeables ».
2. **Devise & états/provinces → widgets/modèles/catalogues COMPOSABLES** (`ZMoney`/`ZCurrencyCatalog`/`ZCurrencyField` ; `ZSubdivision`/`ZSubdivisionCatalog`/`ZStateField`), utilisables (a) **directement** par une app dans ses formulaires, (b) **à l'intérieur** de `ZAddressField` (sélecteur d'état pour le sous-champ `region`, dépendant du pays). Le montant monétaire **pur** reste servi par le champ `number` du cœur + `ZNumberConfig(isCurrency: true)` **déjà existant** ; `ZCurrencyField` fournit le **sélecteur de code devise** (ISO 4217) qui le complète.
3. **HORS story (signalé, pas requis) :** un `EditionFieldType.currency`/`.state` de premier rang **routé par le moteur** exigerait un enum cœur → **OUT** ; à décider par le PM/orchestrateur si un besoin produit réel apparaît. La conception ci-dessus délivre FR-21 **sans** ce besoin.

### ADs applicables (NON-NÉGOCIABLES)

- **AD-1** — `zcrud_intl → zcrud_core` seulement. Les nouveaux catalogues sont des **assets JSON locaux bundlés** dans `zcrud_intl` ; `phone_numbers_parser` reste **confiné** à `z_phone_codec.dart` ; **aucune** nouvelle lib intl/devise lourde n'est ajoutée (pas de `intl`/`money2`/`currency_picker` imposé). Aucun type de lib ne fuit dans le cœur, ni dans une valeur de tranche, ni dans le barrel. Graphe acyclique + **CORE OUT=0** préservés.
- **AD-2 / SM-1** — nouveaux widgets (`ZCurrencyField`, `ZStateField`, sélecteur d'état dans `ZAddressField`) à **contrôleur(s)/focus isolés stables** (`late final`, create `initState` / `dispose`, **jamais** recréés), sync **guardée hors focus**, rebuild ciblé à la tranche, focus préservé pendant la frappe/recherche. Interdits : `setState` de formulaire, ré-injection de valeur dans le contrôleur pendant la frappe.
- **AD-4** — `ZIntlFieldConfig` = **sous-classe concrète `const` de `ZFieldConfig`** (base abstraite, jamais `sealed`) déclarée **dans `zcrud_intl`** ; lue via `ctx.field.config` ; **aucune** modification du cœur. Widgets fournis via factories `.builder` enregistrables (kind = `field.type.name` pour les types déjà routés) ; **jamais** de singleton statique mutable (les catalogues partagés sont **immuables lecture seule**).
- **AD-10** — parse **défensif** partout : code devise inconnu / map `ZMoney` corrompue / montant non numérique / code pays sans subdivision / subdivision inconnue / valeur de tranche `null` / asset devise ou subdivision **absent ou malformé** → état **neutre/vide**, **jamais** de throw remontant au parent (`fromMapSafe → null`, catalogue vide, `@JsonKey(defaultValue)`).
- **AD-12** — **AUCUN secret** (aucune clé de taux de change/validation, aucun endpoint réseau en dur, **jamais** `badCertificateCallback => true`). Devise/états sont **hors-ligne** (assets bundlés) — **pas** de taux de change réseau, **pas** d'autocomplétion géocodée (= E11b géo/v2).
- **AD-13** — RTL (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional`), `Semantics` explicites **opérables** (action `tap` sur le nœud englobant, cf. MEDIUM-2 E11a-2), cibles tactiles **≥ 48 dp**, thème **injecté** via `ZcrudTheme.of(context)` (repli `Theme.of`), libellés via `ZcrudScope.labels`/`label()` (fallback) — **aucune** couleur/style codé en dur. **AI-E10-1** : appliquer les helpers de test réutilisables `assertSemanticActionTap`/`assertMinTapTarget` à **chaque** cible interactive.
- **AD-14/AD-15** — modèles de valeur (`ZMoney`, `ZCurrencyInfo`, `ZSubdivision`, `ZIntlFieldConfig`) = **Dart pur** (aucun Flutter, aucune lib intl en signature publique ; `ZIntlFieldConfig` importe seulement la base `ZFieldConfig` du cœur) ; **aucun** gestionnaire d'état importé ; la présentation (widgets) peut dépendre de Flutter.

## Conception (résumé pour le dev)

### 1. `ZIntlFieldConfig extends ZFieldConfig` — défauts nationaux surchargeables (AD-4)

`lib/src/domain/z_intl_field_config.dart`, **pur-données `const`**, `==`/`hashCode`. Champs (tous **optionnels**, défauts **neutres**, aucun défaut national en dur) :
- `String? defaultCountryIso` — pays initial pour `phoneNumber`/`country`/`address` (surcharge le paramètre `defaultIsoCode` de factory ; **par-champ**).
- `List<String> preferredCountryIsos` (défaut `const []`) — pays remontés en tête du picker.
- `bool showDialCode` (défaut `true`), `bool searchable` (défaut `true`) — options d'affichage neutres.
- (optionnel) `String? defaultCurrencyCode` pour amorcer `ZCurrencyField`.

**Lecture par-champ** dans les widgets **existants** : `final cfg = ctx.field.config is ZIntlFieldConfig ? ctx.field.config as ZIntlFieldConfig : null;` puis `final iso = <valeur de tranche>?.isoCode ?? cfg?.defaultCountryIso ?? widget.defaultIsoCode;`. **Rétro-compat E11a-2 STRICTE** : `config == null` → comportement **identique** à E11a-2 (les 59 tests restent verts). C'est le livrable « **défauts nationaux surchargeables** » de l'épopée.

### 2. Devise (ISO 4217) — modèle neutre + catalogue paresseux + sélecteur

- **`ZMoney`** (`lib/src/domain/z_money.dart`, pur-Dart) : `{ String? currencyCode; /* ISO 4217, ex. "XOF" */ num? amount; String? formatted; }`. Valeur de tranche **neutre** (jamais un type de lib). `toMap`/`fromMap` + `fromMapSafe → null` défensif (map corrompue, `amount` non numérique/non fini, tous champs vides → `null`). Round-trip stable. *Le montant seul reste servi par le champ `number` + `ZNumberConfig(isCurrency:true)` du cœur ; `ZMoney` sert le couple montant+devise et l'affichage.*
- **`ZCurrencyInfo`** (`lib/src/domain/z_currency_info.dart`) : `{ String code; /* ISO 4217 */ String? name; String? symbol; int? decimalDigits; }` — entrée de catalogue, `fromMapSafe` défensif (code absent → `null`).
- **`ZCurrencyCatalog`** (`lib/src/data/z_currency_catalog.dart`) : **calqué sur `ZCountryCatalog`** (même discipline paresse+cache+injection+défensif). Asset `lib/assets/currencies.json` (liste ISO 4217, ~180 entrées : `code`/`name`/`symbol`/`decimalDigits`). Chargeur `rootBundle` **paresseux + cache + dé-dup `_loading`** ; `fromList` pré-chargé (test/surcharge) ; `bundle` injectable ; asset absent/JSON malformé → **catalogue vide** (jamais throw). `byCode(code)` + `search(query)`. `sharedDefaultCurrencyCatalog()` (LOW-1 E11a-2).
- **`ZCurrencyField`** (`lib/src/presentation/z_currency_field_widget.dart`, patron AD-2) : sélecteur de code devise (recherche + liste depuis `ZCurrencyCatalog`) ; contrôleur de recherche `late final` créé 1× en `initState`, disposé ; émet le **code devise `String`** (valeur de tranche neutre) — ou un `ZMoney` si un montant est saisi ; thème/RTL/≥48 dp/`Semantics` opérables. Factory `ZCurrencyField.builder({ZCurrencyCatalog? catalog})`. **Réutiliser le composant sélecteur interne** de E11a-2 (`z_country_picker_field.dart`) ou en factoriser un pendant `z_currency_picker_field.dart` du **même** patron (ne pas dupliquer la logique a11y/RTL).

### 3. États / provinces (ISO 3166-2) — modèle + catalogue dépendant du pays + widget

- **`ZSubdivision`** (`lib/src/domain/z_subdivision.dart`, pur-Dart) : `{ String code; /* ISO 3166-2, ex. "NE-2" */ String countryIso; /* "NE" */ String? name; String? type; /* "region"/"state"/"province" */ }`. `toMap`/`fromMap` + `fromMapSafe → null` défensif.
- **`ZSubdivisionCatalog`** (`lib/src/data/z_subdivision_catalog.dart`) : asset `lib/assets/subdivisions.json` **indexé par pays** (`{ "NE": [ {…} ], "US": [ {…} ], … }`). Paresse+cache+injection+défensif (même patron). `forCountry(iso)` → `List<ZSubdivision>` (pays inconnu / non chargé → **liste vide**, jamais throw). **Périmètre pragmatique du contenu** : livrer un **sous-ensemble curaté et documenté** (pays prioritaires DODLP/lex_douane + un échantillon multi-continent) ; le catalogue est **injectable/extensible** par l'app → couverture ISO 3166-2 **exhaustive = v2** (voir *HORS story*). Aucun défaut national codé en dur non surchargeable.
- **`ZStateField`** (`lib/src/presentation/z_state_field_widget.dart`, patron AD-2) : sélecteur d'état/province **dépendant d'un `countryIso`** (paramètre widget) ; émet le **code ISO 3166-2 `String`** (valeur de tranche neutre). Si le pays n'a **aucune** subdivision au catalogue → repli **champ texte libre** (région saisie), jamais un champ mort. Factory `.builder({ZSubdivisionCatalog? catalog})`.
- **Intégration adresse** : dans **`ZAddressField` existant**, le sous-champ `region` bascule sur `ZStateField` **quand le `countryCode` sélectionné a des subdivisions** (sinon texte libre — comportement E11a-2 conservé). Le changement de pays met à jour la liste des subdivisions disponibles. **Rétro-compat** : sans catalogue de subdivisions injecté / pour un pays sans subdivision → `region` reste un `TextField` libre **identique** à E11a-2.

### 4. Outillage de test réutilisable (AI-E10-1 / AI-E10-2)

- **AI-E10-1** — créer `test/support/a11y_asserts.dart` : `Future<void> assertSemanticActionTap(WidgetTester t, Finder f)` (l'action `SemanticsAction.tap` est **présente ET opérable** via `SemanticsNode.owner.performAction`, cf. MEDIUM-2 E11a-2) + `void assertMinTapTarget(WidgetTester t, Finder f, [double min = 48])` (via `tester.getSize`). Appliqués à **chaque** cible interactive des nouveaux widgets (trigger devise/état + items de liste). *(Helpers **locaux** au package : pas de package de test partagé — hors périmètre ; documenter le patron pour réemploi E9/futurs.)*
- **AI-E10-2** — factoriser/étendre le **template de garde grep** de conformité (déjà présent : `test/isolation_gates_test.dart`) : denylist complète (`Colors.`, `Color(0x`, `EdgeInsets.only(left`/`right`, `Alignment.centerLeft`/`Right`, `Positioned(left`/`right`, `TextAlign.left`/`right`, imports gestionnaires d'état), **résolution de chemin cwd-robuste**, **strip-comment** (ne pas matcher un motif en commentaire). Étendre la couverture aux nouveaux fichiers `z_currency_*`/`z_state_*`/`z_subdivision_*`/`z_money*`.

### 5. Isolation & défensif (AD-1/AD-10/AD-12)

Nouveaux catalogues = **assets JSON locaux** (aucune nouvelle lib lourde ; **ne pas** ajouter `intl`/`money2`/`currency_picker`). `phone_numbers_parser` reste **confiné** à `z_phone_codec.dart` (gate : 1 seul importateur inchangé). Barrel : exporter seulement modèles neutres + catalogues + widgets + `ZIntlFieldConfig` ; **aucun** symbole de lib tierce. Tous cas invalides → neutre/vide, jamais throw. Zéro secret/réseau.

## Impact zcrud_core

**NON — aucune modification de `zcrud_core`.** Justification vérifiée sur disque :
- **`ZFieldConfig` est déjà le point d'extension AD-4** (`z_field_config.dart`, docstring l. 6-12 : configs lourdes **additives**, hors cœur ; base `abstract`, jamais `sealed`). `ZIntlFieldConfig` en hérite **dans `zcrud_intl`**.
- **`ZFieldSpec.config` (`ZFieldConfig?`) existe déjà** (`z_field_spec.dart` l. 40/64) et **circule jusqu'au widget** via `ctx.field.config` (`ZFieldWidgetContext`) — les défauts nationaux passent **par-champ**, sans slot `ZcrudScope`.
- Le seam `ZWidgetRegistry` + routage `registryOrFallback` (`z_field_widget.dart` l. 411/438, kind = `field.type.name`) + repli `ZUnsupportedFieldWidget` restent **inchangés** ; devise/états sont **composables** (pas de nouveau kind requis).
- Les catalogues sont **capturés par closure** des factories → **aucun** slot ajouté à `ZcrudScope`.

→ **Aucune sérialisation de fichier cœur à prévoir.** Un `EditionFieldType.currency`/`.state` de premier rang (routé moteur) exigerait un enum cœur → **HORS story** ; si un besoin produit réel apparaît, **STOP + signalement à l'orchestrateur** avant toute édition du cœur.

## Périmètre — IN / OUT

**IN (E11b-2) :**
1. `ZIntlFieldConfig extends ZFieldConfig` (défauts nationaux surchargeables) lue par les widgets `phoneNumber`/`country`/`address` **existants** (rétro-compat E11a-2 stricte).
2. Devise : `ZMoney` + `ZCurrencyInfo` + `ZCurrencyCatalog` (asset `currencies.json` ISO 4217, paresseux/défensif/injectable) + `ZCurrencyField` (widget AD-2 + `.builder`).
3. États/provinces : `ZSubdivision` + `ZSubdivisionCatalog` (asset `subdivisions.json` ISO 3166-2, **sous-ensemble curaté** indexé par pays, paresseux/défensif/injectable) + `ZStateField` (widget AD-2 + `.builder`) + **intégration au sous-champ `region` de `ZAddressField`** (dépendant du pays, repli texte libre).
4. Outillage de test `assertSemanticActionTap`/`assertMinTapTarget` (AI-E10-1) + garde grep étendue cwd-robuste/strip-comment (AI-E10-2).
5. Gates : isolation (0 nouvelle lib intl ; barrel sans symbole tiers ; `zcrud_core` sans lib intl ; CORE OUT=0), secrets, RTL, **rétro-compat E11a-2 (59 tests verts)**, vérif verte.

**OUT / HORS story (signalé) :**
- **`EditionFieldType.currency`/`.state` de premier rang routé par le moteur** → exige un enum cœur (interdit). Signalé à l'orchestrateur ; non requis pour couvrir FR-21.
- **Taux de change / conversion de devise en réseau** → AD-12 (offline) ; v2.
- **Couverture ISO 3166-2 EXHAUSTIVE** (toutes subdivisions de tous les pays) → sous-ensemble curaté **injectable/extensible** ici ; exhaustivité = v2.
- **Assets `mccmnc` (843 Ko, codes opérateurs mobiles)** évoqués FR-21 → métadonnée d'opérateur, non requise pour l'édition de formulaire ; v2.
- **Autocomplétion géocodée d'adresse** → géo/E11b-geo/v2 (AD-12).
- **Formatage locale-aware nombre/date généraliste** (lib `intl`) → hors périmètre (tirerait une dép lourde).

## Acceptance Criteria

1. **`ZIntlFieldConfig` additive (AD-4), lue par-champ, rétro-compat STRICTE (AD-4/AD-2).** `ZIntlFieldConfig extends ZFieldConfig` (`const`, pur-données, `==`/`hashCode`) vit dans `zcrud_intl`, porte des défauts **surchargeables neutres** (`defaultCountryIso`, `preferredCountryIsos`, `showDialCode`, …) ; posée sur `ZFieldSpec.config`, elle est lue via `ctx.field.config` par les widgets **existants** `phoneNumber`/`country`/`address` (le pays initial suit `slice?.isoCode ?? cfg?.defaultCountryIso ?? widget.defaultIsoCode`). **Aucune** modification de `zcrud_core`. *Test : config assignée → widget résout le pays par défaut depuis la config ; `config == null` → chemins et rendu **identiques** à E11a-2 (les 59 tests E11a-2 restent verts) ; `==`/`hashCode`.*
2. **Modèle devise neutre & sérialisable (AD-1/AD-14).** `ZMoney { currencyCode (ISO 4217), amount, formatted }` pur-Dart, `toMap/fromMap`, round-trip stable ; **aucun** type de lib dans l'API publique. *Test : round-trip ; `dart analyze` ; grep signatures.*
3. **Catalogue devise paresseux/défensif/injectable (FR-21, AD-10).** `ZCurrencyCatalog` charge `lib/assets/currencies.json` (ISO 4217) **paresseusement** (cache + dé-dup `_loading`), `byCode`/`search` ; asset absent / JSON malformé → catalogue **vide** (jamais throw) ; `fromList`/`bundle` injectables. *Test : fake catalogue + asset de test ; asset absent → vide ; cache (2ᵉ lecture sans re-parse) ; charges concurrentes → un seul parse.*
4. **`ZCurrencyField` servi & éditant la tranche (AD-2/AD-4).** `ZCurrencyField.builder` renvoie un `ZFieldWidgetBuilder` ; sélectionner une devise écrit le **code ISO 4217 `String`** (ou un `ZMoney`) via `ctx.onChanged` ; la liste vient de `ZCurrencyCatalog` (injectable). *Test widget : sélection → tranche = code devise attendu ; catalogue fake → liste rendue + recherche.*
5. **États/provinces dépendants du pays (FR-21, AD-10).** `ZSubdivision` + `ZSubdivisionCatalog.forCountry(iso)` (asset `subdivisions.json` indexé par pays, paresseux/défensif/injectable) ; `ZStateField` émet le **code ISO 3166-2 `String`** ; pays inconnu / sans subdivision → **repli texte libre**, jamais un champ mort ni un throw. *Test : catalogue fake (NE, US) → liste par pays ; changer le pays met à jour la liste ; pays "ZZ" → repli texte libre / liste vide, `returnsNormally`.*
6. **Intégration adresse (rétro-compat E11a-2).** Dans `ZAddressField`, le sous-champ `region` devient un `ZStateField` **si** le `countryCode` a des subdivisions ; sinon `region` reste un `TextField` libre **identique** à E11a-2. Changer le pays met à jour l'option d'état. Sans catalogue subdivisions injecté → comportement E11a-2 inchangé. *Test widget : pays avec subdivisions → sélecteur d'état ; pays sans → texte libre ; émet `ZPostalAddress` neutre dans les deux cas.*
7. **Validation défensive complète (AD-10).** Code devise inconnu / map `ZMoney` corrompue / `amount` non numérique-non fini / code pays sans subdivision / subdivision "ZZ-99" / valeur de tranche `null` / asset devise ou subdivision **absent ou malformé** → état **neutre/vide**, **jamais** d'exception remontant au parent. *Test : table de cas → état neutre, `returnsNormally`.*
8. **SM-1 / rebuild ciblé + focus préservé (AD-2).** Taper dans la recherche devise/état (ou une ligne d'adresse enrichie) ne reconstruit **que** la tranche du champ courant (compteur de build voisin inchangé), **zéro** perte de focus ; `TextEditingController`/`FocusNode` créés **1×** (`initState`), jamais recréés. *Test widget : `onInit`==1 + focus conservé après ≥2 frappes ; via le **vrai dispatch** `DynamicEdition` pour l'adresse enrichie, pump direct pour les widgets autonomes.*
9. **Anti-fuite de cycle de vie (learning E5/E11a-1).** `dispose` libère **tous** les contrôleurs/focus des nouveaux widgets ; chaque contrôleur/focus est **par-montage** (jamais aliasé) ; les catalogues partagés (lecture seule) n'introduisent aucune ressource non disposée. *Test : pump → pumpWidget(SizedBox) ; deux `ZCurrencyField`/`ZStateField` montés → contrôleurs distincts, rien de non disposé.*
10. **Thème injecté + RTL + a11y ≥48 dp + action opérable (AD-13, AI-E10-1).** Couleurs/styles via `ZcrudTheme.of` (repli `Theme.of`) — **aucune** valeur codée en dur ; libellés via `ZcrudScope.labels`/`label()` (fallback) ; paddings/alignements **directionnels** ; `Semantics` **opérables** (action `tap` sur le nœud englobant) ; cibles **≥ 48 dp**. Helpers réutilisables `assertSemanticActionTap`/`assertMinTapTarget` appliqués à **chaque** cible interactive (trigger + items de devise/état). *Test : rendu des nouveaux champs sous `Directionality.rtl` sans exception ; `assertSemanticActionTap`/`assertMinTapTarget` verts sur triggers/items.*
11. **Gate isolation — zéro nouvelle lib intl, cœur intact (AD-1, AI-E10-2).** Aucune nouvelle lib lourde ajoutée (`pubspec.yaml` de `zcrud_intl` : pas de `intl`/`money2`/`currency_picker`) ; `phone_numbers_parser` reste **confiné** au seul `z_phone_codec.dart` ; le barrel `lib/zcrud_intl.dart` n'exporte **aucun** symbole de lib tierce ; `zcrud_core/pubspec.yaml` sans lib intl ; **CORE OUT=0**. Garde grep **cwd-robuste + strip-comment** (denylist RTL/couleur/état-mgr) verte sur les nouveaux fichiers. *Gate : `graph_proof` CORE OUT=0 ; grep confinement (1 importateur `phone_numbers_parser`) ; grep barrel ; `dart pub deps` de `zcrud_core` sans lib intl.*
12. **Gate secrets — AUCUN secret (AD-12).** Aucune clé (taux de change/validation), aucun token, aucun endpoint réseau en dur, aucun `badCertificateCallback => true` ; devise/états **hors-ligne** (assets bundlés). *Gate : scan secrets vert sur `zcrud_intl` ; grep négatif.*
13. **Rétro-compat E11a-2 STRICTE + vérif verte rejouée.** Les **59 tests E11a-2 restent verts** (aucun export retiré/renommé du barrel ; comportement `phoneNumber`/`country`/`address` inchangé sans `ZIntlFieldConfig`) ; `melos run generate` OK (sans objet ici) → `flutter analyze` (`zcrud_intl`) RC=0 → `flutter test` (`zcrud_intl`) RC=0 ; `melos list`=14 ; `graph_proof` CORE OUT=0 ; `dart pub get --dry-run` RC=0. *Gate `done`.*

## Tasks / Subtasks

- [x] **T1 — `ZIntlFieldConfig` (AD-4) + lecture par-champ** (AC: 1)
  - [x] `lib/src/domain/z_intl_field_config.dart` : `ZIntlFieldConfig extends ZFieldConfig` (`const`, défauts neutres surchargeables, `==`/`hashCode`), `import 'package:zcrud_core/zcrud_core.dart'` pour la base.
  - [x] Brancher la lecture `ctx.field.config is ZIntlFieldConfig` dans `z_phone_field_widget.dart`, `z_country_field_widget.dart`, `z_address_field_widget.dart` (pays par défaut, pays préférés) — **rétro-compat stricte** : `config == null` → chemin E11a-2 identique.
- [x] **T2 — Devise : modèles + catalogue** (AC: 2, 3, 7)
  - [x] `lib/src/domain/z_money.dart` (`ZMoney`, `fromMapSafe` défensif) ; `lib/src/domain/z_currency_info.dart` (`ZCurrencyInfo`).
  - [x] `lib/assets/currencies.json` (ISO 4217, ~180 entrées : code/name/symbol/decimalDigits).
  - [x] `lib/src/data/z_currency_catalog.dart` (patron `ZCountryCatalog` : paresse+cache+`_loading`+`fromList`+`bundle`+défensif ; `byCode`/`search` ; `sharedDefaultCurrencyCatalog()`).
- [x] **T3 — `ZCurrencyField` (patron AD-2)** (AC: 4, 8, 9, 10)
  - [x] `lib/src/presentation/z_currency_field_widget.dart` : contrôleur recherche `late final` (initState/dispose), émet code devise (ou `ZMoney`) via `ctx.onChanged` ; factory `.builder({ZCurrencyCatalog?})` ; thème/RTL/≥48 dp/Semantics opérables. Réutiliser/factoriser le sélecteur inline (patron `z_country_picker_field.dart`), sans dupliquer la logique a11y/RTL.
- [x] **T4 — États/provinces : modèle + catalogue + widget** (AC: 5, 7, 8, 9, 10)
  - [x] `lib/src/domain/z_subdivision.dart` (`ZSubdivision`, `fromMapSafe` défensif).
  - [x] `lib/assets/subdivisions.json` (ISO 3166-2, **sous-ensemble curaté** indexé par pays ; pays prioritaires + échantillon).
  - [x] `lib/src/data/z_subdivision_catalog.dart` (patron catalogue ; `forCountry(iso)` → liste ; défensif/injectable).
  - [x] `lib/src/presentation/z_state_field_widget.dart` : sélecteur dépendant de `countryIso`, émet code ISO 3166-2 ; repli **texte libre** si aucune subdivision ; factory `.builder({ZSubdivisionCatalog?})`.
- [x] **T5 — Intégration adresse (rétro-compat)** (AC: 6, 13)
  - [x] `z_address_field_widget.dart` : sous-champ `region` → `ZStateField` **si** le pays a des subdivisions ; sinon `TextField` libre **identique** à E11a-2 ; changement de pays met à jour l'option. Sans catalogue subdivisions → comportement E11a-2 inchangé.
- [x] **T6 — Outillage de test (AI-E10-1/AI-E10-2)** (AC: 10, 11)
  - [x] `test/support/a11y_asserts.dart` : `assertSemanticActionTap`/`assertMinTapTarget`.
  - [x] Étendre `test/isolation_gates_test.dart` : garde grep cwd-robuste + strip-comment, denylist complète, couverture des nouveaux fichiers.
- [x] **T7 — Barrel & exports** (AC: 2, 11)
  - [x] `lib/zcrud_intl.dart` : ajouter `ZIntlFieldConfig`, `ZMoney`, `ZCurrencyInfo`, `ZCurrencyCatalog`, `ZCurrencyField`, `ZSubdivision`, `ZSubdivisionCatalog`, `ZStateField` ; **aucun** symbole de lib tierce ; **ne retirer/renommer aucun** export E11a-2.
- [x] **T8 — Tests** (AC: 1-10) — round-trip modèles + tables défensives ; catalogues (paresse/cache/concurrent/injection/asset absent) ; widgets (registre/tranche/dépendance pays/SM-1/dispose/RTL/a11y) ; rétro-compat E11a-2 (config null).
- [x] **T9 — Gates** (AC: 11, 12, 13)
  - [x] Confinement `phone_numbers_parser` (1 importateur), grep barrel, `zcrud_core` sans lib intl, `graph_proof` CORE OUT=0, scan secrets, garde RTL/couleur, `dart pub get --dry-run`, `melos list`=14, **59 tests E11a-2 verts**, `analyze`+`test` RC=0.

## Stratégie de tests

- **Unitaires modèle (pur-Dart)** : round-trip `ZMoney`/`ZCurrencyInfo`/`ZSubdivision`/`ZIntlFieldConfig` (`==`/`hashCode`) ; table défensive AD-10 (code devise inconnu, map money corrompue, amount non fini, subdivision inconnue, tranche `null`).
- **Catalogues** : chargement paresseux depuis asset de test ; asset absent / JSON malformé → vide (pas de throw) ; cache (2ᵉ lecture sans re-parse) ; charges concurrentes → un seul parse ; `fromList` injecté ; `ZCurrencyCatalog.byCode/search`, `ZSubdivisionCatalog.forCountry`.
- **Widget** : (a) `ZCurrencyField`/`ZStateField` via `.builder` → widget présent ; (b) sélection devise → tranche = code ISO 4217 ; sélection état → tranche = code ISO 3166-2 ; (c) changer le pays de `ZStateField`/adresse → liste subdivisions mise à jour, pays sans subdivision → texte libre ; (d) **rétro-compat E11a-2** : `ZIntlFieldConfig` null → rendu/chemins identiques (rejouer la suite E11a-2 verte) ; config non-null → pays par défaut résolu depuis la config ; (e) SM-1 : `onInit`==1, focus conservé ≥2 frappes (dispatch réel pour l'adresse, pump direct pour autonomes), compteur build voisin inchangé ; (f) `dispose` → contrôleurs libérés, deux champs montés → contrôleurs distincts ; (g) rendu sous `Directionality.rtl` sans exception ; **`assertSemanticActionTap`/`assertMinTapTarget`** sur triggers/items (AI-E10-1).
- **Fakes** en test (pas d'accès disque réel) : `ZCurrencyCatalog.fromList`, `ZSubdivisionCatalog.fromMap`.
- **Gates statiques** : grep confinement `phone_numbers_parser` (1 importateur) ; grep anti-lib dans le barrel + `zcrud_core/pubspec.yaml` ; grep anti-secret/`badCertificateCallback` ; garde RTL cwd-robuste + strip-comment (AI-E10-2) ; `graph_proof` **CORE OUT=0** ; **suite E11a-2 (59 tests) rejouée verte**.

## Dev Notes

### Fichiers du cœur à NE PAS modifier (lecture de référence)

- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` — **base abstraite `ZFieldConfig` (AD-4)** ; `ZIntlFieldConfig` en hérite **dans `zcrud_intl`**. **Ne pas** ajouter de config intl au cœur.
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (l. 40, 64) — `ZFieldConfig? config` déjà présent, circule via `ctx.field.config`.
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (l. 411, 438) — routage `registryOrFallback` → `tryBuilderFor(field.type.name)` → repli. kind = `field.type.name` (inchangé). **Ne pas** ajouter de valeur d'enum.
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` — `phoneNumber`/`country`/`address` présents ; **PAS** de `currency`/`state` (devise/états passent par widgets/catalogues/config, pas par l'enum).
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — `widgetRegistry`/`theme`/`labels`. **Ne pas** ajouter de slot ; catalogues capturés par closure des factories.

### Patrons E11a-2 / E11b-1 à imiter (ne pas réinventer)

- **E11a-2 (`packages/zcrud_intl/`)** — base **directe** : `z_country_catalog.dart` (paresse+cache+`_loading` dé-dup MEDIUM-1+`fromList`/`bundle`+défensif+`sharedDefault…()` LOW-1) est le **gabarit exact** de `ZCurrencyCatalog`/`ZSubdivisionCatalog`. `z_country_field_widget.dart`/`z_country_picker_field.dart` (sélecteur recherche+liste, Semantics **opérable** MEDIUM-2, ≥48 dp, thème injecté) = gabarit de `ZCurrencyField`/`ZStateField` — **réutiliser** le sélecteur, ne pas dupliquer l'a11y. `z_phone_field_widget.dart` (contrôleur/focus `late final` initState/dispose, sync guardée hors focus, `defaultIsoCode`) = patron AD-2 ; `defaultIsoCode` sera **surchargé par-champ** via `ZIntlFieldConfig`.
- **E11b-1 (`packages/zcrud_geo/`)** — patron **config additive** : `z_geo_field_config.dart` (`ZGeoFieldConfig extends ZFieldConfig`, `const`, défauts surchargeables neutres, lue via `ctx.field.config`, rétro-compat E11a-1 stricte) est le **gabarit exact** de `ZIntlFieldConfig`. `z_geo_field_config_test.dart` = gabarit du test de config.
- **Barrel** : `lib/zcrud_intl.dart` (déjà en place) — **ajouter** les nouveaux exports, ne rien retirer ; garder les libs/ponts hors barrel.

### Learnings absorbés (E5 / E11a-1 / E11a-2 / E10)

- **AD-10 réel (E5/E11a-1/E11a-2)** : tester les cas RÉELS (code devise inconnu, map corrompue, subdivision inconnue, asset absent/JSON malformé) → neutre, jamais de throw.
- **Anti-fuite (E5/E11a-2)** : disposer **tout** contrôleur/focus ; par-montage.
- **MEDIUM-1 E11a-2 (dé-dup charge)** : mémoïser le `Future` en vol (`_loading`) dans les nouveaux catalogues → asset lu/parsé **1×** sous charges concurrentes.
- **MEDIUM-2 E11a-2 (a11y opérable)** : action `tap` **sur le nœud `Semantics` englobant** (pas un `ExcludeSemantics` inopérable) ; champ éditable expose sa sémantique native.
- **LOW-1 E11a-2 (catalogue partagé)** : `sharedDefaultCurrencyCatalog()`/`…Subdivision…()` pour éviter une lecture d'asset par kind.
- **AI-E10-1 (retro E10)** : **outiller** l'a11y — helpers `assertSemanticActionTap`/`assertMinTapTarget` réutilisables (ces helpers **n'existent pas encore** dans le repo → les créer ici, cible explicite « E11b widgets geo/intl »).
- **AI-E10-2 (retro E10)** : garde grep **exhaustive + cwd-robuste + strip-comment** (denylist complète) — étendre `isolation_gates_test.dart` existant.
- **E3-3b** : ces champs passent par la présentation (`ZWidgetRegistry`/composition), **pas** `ZTypeRegistry` (codec pur-Dart).

### Project Structure Notes

- Tout sous `packages/zcrud_intl/lib/` : `src/domain/` (modèles neutres + `ZIntlFieldConfig`, pur-Dart, AD-14) ; `src/data/` (catalogues) ; `src/presentation/` (widgets Flutter) ; `assets/currencies.json` + `assets/subdivisions.json`. Barrel `lib/zcrud_intl.dart`. `test/support/a11y_asserts.dart`. Aucun `*.g.dart` committé.
- `pubspec.yaml` de `zcrud_intl` : déclarer les **2 nouveaux assets** ; **NE PAS** ajouter de lib lourde (`intl`/`money2`/`currency_picker`) — catalogues = JSON local. `phone_numbers_parser` inchangé (confiné).
- Nommage : types publics préfixés `Z` (`ZIntlFieldConfig`, `ZMoney`, `ZCurrencyInfo`, `ZCurrencyCatalog`, `ZCurrencyField`, `ZSubdivision`, `ZSubdivisionCatalog`, `ZStateField`) ; fichiers snake_case ; persistance snake_case ; enums camelCase ; codes ISO = `String` opaque (4217 devise, 3166-2 subdivision, 3166-1 pays).

### Latest tech

- **Devise** : **asset JSON ISO 4217 bundlé** (pas de lib) — cohérent AD-1/AD-12 (offline, sans clé). Le formatage monétaire riche (symbole/positionnement locale) reste minimal (symbole + decimalDigits du catalogue) ; le formatage locale-aware `intl` complet = hors périmètre (dép lourde).
- **États/provinces** : **asset JSON ISO 3166-2 bundlé**, indexé par pays, **sous-ensemble curaté injectable** ; exhaustivité = v2.
- Confirmer compat SDK Dart `^3.12.2` + Flutter du workspace (gate E1-4, `dart pub get --dry-run`). Aucune nouvelle dépendance externe attendue.

### References

- [Source: epics.md#E11b — Story E11b-2] (`_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` l. 150-154) — `zcrud_intl` complet : **devise + états + surcharges** ; défauts nationaux **surchargeables**. Dépend de E11a, phase v1.x/v2.
- [Source: prd.md#FR-21] (l. 289-293) — champs téléphone/pays/**devise** ; constantes en **assets JSON paresseux** ; **aucun défaut national codé en dur non surchargeable**.
- [Source: architecture.md#AD-1/AD-4/AD-10/AD-12/AD-13/AD-14/AD-15] — isolation (libs/assets hors cœur) ; extension par config additive `ZFieldConfig` ; désérialisation défensive ; zéro secret/offline ; RTL/a11y/thème injecté ; pureté des couches ; aucun gestionnaire d'état.
- [Source: E11a-2 story] `e11a-2-zcrud-intl-telephone-pays-adresse.md` — sous-ensemble livré (frontière l. 24 : devise/états/surcharges = E11b-2) ; patron catalogue/widget/isolation/défensif ; findings MEDIUM-1/MEDIUM-2/LOW-1 à réappliquer.
- [Source: E11b-1 story] `e11b-1-zcrud-geo-complet.md` — patron **config additive `ZFieldConfig`** sans nouvelle valeur d'enum ; rétro-compat MVP stricte ; gate isolation/secrets étendus.
- [Source: epic-10-retrospective.md] AI-E10-1 (helpers `assertSemanticActionTap`/`assertMinTapTarget`) + AI-E10-2 (garde grep exhaustive/cwd-robuste/strip-comment) — **cible explicite E11b widgets geo/intl**.
- [Source: zcrud_core] `z_field_config.dart` (base AD-4), `z_field_spec.dart` (l. 40/64 `config`), `z_field_widget.dart` (l. 411/438 routage), `edition_field_type.dart` (pas de `currency`/`state`), `zcrud_scope.dart`.
- [Source: CLAUDE.md] Key Don'ts — jamais de lib intl/gestionnaire d'état dans `zcrud_core` ; jamais de secret ; thème injecté ; RTL directionnel ; cibles ≥ 48 dp ; `ListView.builder`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story)

### Debug Log References

- Vérif verte CIBLÉE rejouée sur disque :
  - `dart analyze packages/zcrud_intl` → **No issues found!** (RC=0)
  - `flutter test` (cwd `packages/zcrud_intl`) → **129 tests passés** (RC=0) —
    59 baseline E11a-2 **inchangés** + 70 nouveaux E11b-2. (À la racine du
    workspace, les tests d'asset réel échouent faute de bundling par-package :
    `flutter test` se lance **depuis le dossier du package**.)
  - `python3 scripts/dev/graph_proof.py` → `zcrud_intl -> zcrud_core`,
    **out-degree(zcrud_core) = 0 (runtime)**, acyclique.
  - `dart pub get --dry-run` RC=0 ; `melos list` = **14** packages.
  - Confinement `phone_numbers_parser` : **1** importateur
    (`z_phone_codec.dart`) — inchangé.
  - `zcrud_core/pubspec.yaml` : **aucune** dép `intl`/`money2`/`currency_picker`/
    `phone_numbers_parser` runtime (le seul match `intl` est un commentaire).

### Completion Notes List

- **Décision d'architecture respectée (zéro core-change)** : aucune valeur d'enum
  `EditionFieldType.currency`/`.state` ; devise/états livrés en **widgets +
  modèles + catalogues COMPOSABLES**, défauts nationaux via
  `ZIntlFieldConfig extends ZFieldConfig` (patron E11b-1) lu par `ctx.field.config`.
  **Aucun fichier hors `packages/zcrud_intl/` modifié.**
- **AC1** ✅ `ZIntlFieldConfig` (`const`, `==`/`hashCode`, `preferredCountryIsos`
  comparés élément-à-élément) lue par-champ dans phone/country/address ;
  rétro-compat STRICTE (`config == null` → chemin E11a-2 ; config d'un autre type
  ignorée).
- **AC2/AC3** ✅ `ZMoney`/`ZCurrencyInfo` neutres + `ZCurrencyCatalog`
  (paresse+cache+dé-dup `_loading`+`fromList`/`bundle`+défensif+partagé).
- **AC4** ✅ `ZCurrencyField.builder` → `ZFieldWidgetBuilder` ; sélection → code
  ISO 4217 `String` (ou `ZMoney` si `showAmount`).
- **AC5** ✅ `ZSubdivision`/`ZSubdivisionCatalog.forCountry` (indexé par pays) +
  `ZStateField` (repli **texte libre** si pays sans subdivision / inconnu).
- **AC6** ✅ Intégration adresse : `region` → sélecteur d'état si le pays a des
  subdivisions (catalogue injecté) ; sinon `TextField` libre **identique** à
  E11a-2 ; changement de pays met à jour l'option ; sans `subdivisionCatalog` →
  comportement E11a-2 inchangé.
- **AC7** ✅ Table défensive AD-10 (code inconnu, map corrompue, amount non fini,
  subdivision `ZZ-99`, valeur `null`, asset absent/malformé) → neutre, jamais de
  throw.
- **AC8** ✅ SM-1 : contrôleurs `late final` créés 1× (`onInit`==1), focus
  conservé ≥2 frappes (devise + état).
- **AC9** ✅ Anti-fuite : dispose de tous contrôleurs/focus ; picker générique
  interne dispose son propre contrôleur ; par-montage.
- **AC10** ✅ Thème injecté (`ZcrudTheme.of`), RTL directionnel, `Semantics`
  **opérables** + ≥48 dp via helpers **AI-E10-1** `assertSemanticActionTap`/
  `assertMinTapTarget` (créés) appliqués aux triggers **et** items.
- **AC11/AC12** ✅ Gate isolation étendu **AI-E10-2** (cwd-robuste + strip-comment
  + denylist couleur/RTL/état-mgr + ban `intl`/`money2`/`currency_picker`) ;
  barrel sans symbole tiers ; `graph_proof` CORE OUT=0 ; secrets/`badCertificate`
  absents ; offline (assets bundlés).
- **AC13** ✅ Rétro-compat E11a-2 STRICTE : **59 tests E11a-2 verts** ; aucun
  export retiré/renommé.
- **Sélecteur factorisé** : `ZOptionPickerField<T>` interne (a11y/RTL uniques)
  réemployé par devise, état et région d'adresse — pas de duplication.
- **Aucun besoin core détecté.**

### File List

Nouveaux :
- `packages/zcrud_intl/lib/src/domain/z_intl_field_config.dart`
- `packages/zcrud_intl/lib/src/domain/z_money.dart`
- `packages/zcrud_intl/lib/src/domain/z_currency_info.dart`
- `packages/zcrud_intl/lib/src/domain/z_subdivision.dart`
- `packages/zcrud_intl/lib/src/data/z_currency_catalog.dart`
- `packages/zcrud_intl/lib/src/data/z_subdivision_catalog.dart`
- `packages/zcrud_intl/lib/src/presentation/z_option_picker_field.dart`
- `packages/zcrud_intl/lib/src/presentation/z_currency_field_widget.dart`
- `packages/zcrud_intl/lib/src/presentation/z_state_field_widget.dart`
- `packages/zcrud_intl/lib/assets/currencies.json`
- `packages/zcrud_intl/lib/assets/subdivisions.json`
- `packages/zcrud_intl/test/support/a11y_asserts.dart`
- `packages/zcrud_intl/test/z_intl_e11b_models_test.dart`
- `packages/zcrud_intl/test/z_currency_catalog_test.dart`
- `packages/zcrud_intl/test/z_subdivision_catalog_test.dart`
- `packages/zcrud_intl/test/z_currency_field_test.dart`
- `packages/zcrud_intl/test/z_state_field_test.dart`
- `packages/zcrud_intl/test/z_intl_config_wiring_test.dart`

Modifiés :
- `packages/zcrud_intl/lib/zcrud_intl.dart` (exports additifs)
- `packages/zcrud_intl/pubspec.yaml` (2 assets ; aucune lib ajoutée)
- `packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart` (config)
- `packages/zcrud_intl/lib/src/presentation/z_country_field_widget.dart` (config)
- `packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart` (config + intégration état)
- `packages/zcrud_intl/lib/src/presentation/z_country_picker_field.dart` (preferredIsos/searchable additifs)
- `packages/zcrud_intl/test/isolation_gates_test.dart` (gate étendu AI-E10-2)
