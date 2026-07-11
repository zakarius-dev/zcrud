---
baseline_commit: 1bcae2ad4ea1a66198f02020a6f29f77e1e2e2f6
---

# Story DP.8: Adresse String + Places (parité DODLP, gap B10)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrant DODLP sur zcrud**,
I want **un `ZAddressCodec` de compatibilité de schéma (String ↔ `ZPostalAddress`) et un seam `ZPlaceSearchProvider` de recherche géographique injectable (sans aucune clé dans le package), plus le câblage du kind `addressSearchField`**,
so that **les données d'adresse DODLP existantes (persistées en String) migrent sans réécriture ni casse, et l'autocomplétion Google Places (ou tout autre fournisseur) redevient possible côté app — le tout confiné à `zcrud_intl`, sans modifier `zcrud_core`**.

## Contexte & problème (gap B10, `docs/dodlp-edition-parity-gap.md` §2.5)

DODLP et zcrud ont des **schémas de persistance incompatibles** pour le champ adresse :

- **DODLP** (`address` ET `addressSearchField` — 2 valeurs d'enum, **même rendu**) persiste une **String** dans le champ. Le widget est un `FormBuilderTextField` (`minLines:1, maxLines:3`) dont la valeur écrite au modèle est `controller.text = address.address`, un **String** ; `onChanged: (String? value) → item[fieldName] = value`. Un bouton loupe ouvre `PlacesAutocomplete.show(...)` puis `GoogleMapsPlaces.getDetailsByPlaceId(...)` (via un **proxy** `PROXY_BASE_URL`, clé côté serveur), et `googlePlaceDetalsToAddress` construit un `flutter_contacts.Address` transitoire ; **seule la String `address.address`** (= `formattedAddress`, sinon `placeDescription`/`name`) est réinjectée dans le contrôleur → **la valeur du champ persistée reste une String**. (Les sous-champs structurés `isoCountry/state/…` ne partent que via `field.onChange` vers des attributs frères, hors du champ adresse lui-même.)
- **zcrud** (E11a-2/E11b-2) persiste un **`ZPostalAddress` structuré** (`toMap()` → `Map` de 6 sous-champs : `line1, line2, city, region, postalCode, countryCode` + `formatted`), servi par le sous-formulaire `ZAddressFieldWidget`. **Aucune** recherche géo (E11b/AD-12 : sous-ensemble MVP hors-ligne, l'autocomplétion réseau était explicitement HORS périmètre).

**Conséquence migration** : une collection DODLP contient des adresses = String ; zcrud attend un Map. Sans pont, soit le parse échoue, soit une migration réécrit toutes les lignes (change le format sur disque). B10 tranche : **garder `ZPostalAddress` ET fournir `ZAddressCodec` (String ↔ structuré) + seam `ZPlaceSearchProvider`**.

## Acceptance Criteria

1. **AC1 — `ZAddressCodec` (String ↔ `ZPostalAddress`).** Un codec **pur-Dart** (`lib/src/domain/z_address_codec.dart`) expose :
   - `ZPostalAddress? decodeString(Object? raw)` : `raw is String` non vide → `ZPostalAddress(formatted: raw)` (la String legacy est portée telle quelle dans `formatted`, sous-champs structurés à `null`) ; `raw` `null`/vide/non-`String` → `null` (état neutre).
   - `String? encodeToString(ZPostalAddress? addr)` : `null`/`addr.isEmpty` → `null` ; sinon **préfère `addr.formatted`** ; à défaut **compose** une String depuis les sous-champs renseignés dans l'ordre `line1, line2, city, region, postalCode, countryCode`, jointe par `", "`.
   - **Défensif AD-10** : les deux méthodes **ne throw JAMAIS** (aucune valeur d'entrée, y compris `Map`, `int`, `List`, ne provoque d'exception).

2. **AC2 — Round-trip String (fidélité migration DODLP).** Pour toute String `s` non vide : `encodeToString(decodeString(s)) == s` (aucune perte du texte legacy). `decodeString(null) == null`, `decodeString('') == null`, `decodeString('   ') == null`, `decodeString(<Map/int/List>) == null` (jamais de throw). Testé.

3. **AC3 — Round-trip structuré + perte documentée.** (a) Un `ZPostalAddress` **avec** `formatted` round-trippe son `formatted` à l'octet près (`decodeString(encodeToString(a)).formatted == a.formatted`). (b) Un `ZPostalAddress` structuré **sans** `formatted` : `encodeToString` produit la String composée, et `decodeString` de cette String rend un `ZPostalAddress` dont **seul `formatted`** est renseigné (structure→String est **volontairement lossy** : la re-décomposition en sous-champs est HORS périmètre — elle relèverait d'un parseur d'adresse, non fourni). Cette perte est **documentée** dans le dartdoc du codec. Testé.

4. **AC4 — Seam `ZPlaceSearchProvider` (recherche géo injectable, ZÉRO secret).** Un **port abstrait pur-Dart** (`lib/src/domain/z_place_search_provider.dart`) :
   - `Future<List<ZPlacePrediction>> search(String query, {String? countryIso, String? sessionToken})` ;
   - `Future<ZPostalAddress?> details(String placeId, {String? sessionToken})` (le fournisseur mappe le résultat géo → `ZPostalAddress` neutre, incluant `formatted`).
   - Types de données neutres associés : `ZPlacePrediction { String placeId; String description; }` (pur-Dart, `const`, `==`/`hashCode`).
   - **AUCUNE clé API, AUCUN endpoint/URL, AUCUNE dépendance réseau (`http`/`google_maps_webservice`/`flutter_google_places`), AUCUN proxy** dans `zcrud_intl`. L'implémentation (Google Places via proxy, OSM Nominatim, mock…) vit **entièrement dans l'app hôte**. Le gate de secrets (`isolation_gates_test.dart`) reste vert.

5. **AC5 — Câblage `addressSearchField` (mapping n:1) + affordance de recherche.** La factory du widget adresse enregistre le **même** `ZAddressFieldWidget` sous les **deux** kinds `"address"` **et** `"addressSearchField"` (parité DODLP, rendu identique). Le `ZPlaceSearchProvider` est **injecté par closure** dans la factory `.builder(...)` (même patron que `catalog`/`subdivisionCatalog`, AD-4). Quand un provider est injecté, le widget affiche une **affordance de recherche** (`IconButton` loupe, cible ≥ 48 dp, `Semantics` label localisé via `label(context, 'intl.address.search', fallback: …)`) qui : appelle `search(...)` (avec `countryIso = _countryIso` courant), laisse choisir une prédiction, appelle `details(placeId)`, puis **remplit les sous-champs + `formatted`** du `ZPostalAddress` via la **voie d'émission UNIQUE** `_emit()` (AD-2 : jamais de rebuild global, un seul `ctx.onChanged`).

6. **AC6 — Compat schéma String au bord de persistance (données DODLP non réécrites).** `ZAddressCodec` est utilisable comme **couple (dé)sérialiseur du champ** pour une collection en mode « compat String » : une valeur de tranche legacy = String est **ingérée** par le widget sans crash (le widget accepte déjà `Object?` : `_addressOf` doit router une `String` vers `ZAddressCodec.decodeString`, en plus des chemins `ZPostalAddress`/`Map` existants), et une story « compat String » **réémet une String** via `encodeToString` (documenté : câblage app au bord de (dé)sérialisation), de sorte que les lignes DODLP migrées **ne sont pas réécrites en Map**. Le mode structuré natif zcrud (Map) reste le défaut inchangé. Testé (ingestion String → affichage `formatted` ; round-trip String stable).

7. **AC7 — Rétro-compat E11a-2 / E11b-2 STRICTE.** Sans `ZPlaceSearchProvider` **et** sans usage du codec, `ZAddressFieldWidget` se comporte **exactement** comme aujourd'hui : sous-formulaire structuré, sélecteur d'état/province quand `subdivisionCatalog` est injecté (E11b-2), **aucun** bouton de recherche affiché (provider `null` → affordance absente). L'API publique de `ZPostalAddress` et `ZIntlFieldConfig` n'évolue que de façon **additive** (AD-10). Tous les tests E11a-2/E11b-2 existants restent **verts** sans modification.

8. **AC8 — Conformité AD & gates verts.** Codec + port = **pur-Dart** couche `domain` (AD-14, aucune closure/widget/lib lourde). Widget : `Semantics` explicites, cibles ≥ 48 dp, variantes **directionnelles** (`TextAlign.start`, `EdgeInsetsDirectional`), thème via `ZcrudTheme` (AD-13). Nouveaux symboles publics exportés par le barrel `lib/zcrud_intl.dart`. `melos run generate` OK → `dart analyze` RC=0 → `flutter test` RC=0 ; `isolation_gates_test.dart` (AD-1/AD-12/AD-13 + scan secrets) **étendu** pour couvrir les nouveaux fichiers et **vert**.

9. **AC9 — Tests.** Couvrir : (a) round-trip String (AC2) + défensif (`null`/`''`/`Map`/`int`/`List` → `null`, jamais de throw) ; (b) round-trip structuré + perte documentée (AC3) ; (c) seam **mocké** — `FakeZPlaceSearchProvider` renvoyant prédictions puis `ZPostalAddress` : sélection → **un seul** `ctx.onChanged` (voie d'émission unique AD-2), `onBuild` ne compte pas de rebuild global ; (d) `addressSearchField` **et** `address` résolvent tous deux vers `ZAddressFieldWidget` ; (e) provider **absent** ⇒ **aucun** bouton de recherche (rétro-compat) ; (f) ingestion d'une valeur de tranche = String legacy (AC6) sans crash.

## Tasks / Subtasks

- [x] **T1 — `ZAddressCodec` pur-Dart** (AC1, AC2, AC3, AC6)
  - [x] Créer `packages/zcrud_intl/lib/src/domain/z_address_codec.dart` : `decodeString(Object?) → ZPostalAddress?`, `encodeToString(ZPostalAddress?) → String?`, défensif (ne throw jamais), composition ordonnée `line1..countryCode` jointe `", "`.
  - [x] Dartdoc : documenter explicitement la **perte structure→String** (re-décomposition hors périmètre) et la stratégie « String legacy → `formatted` ».
  - [x] Exporter depuis le barrel.
- [x] **T2 — Port `ZPlaceSearchProvider` + `ZPlacePrediction`** (AC4)
  - [x] Créer `packages/zcrud_intl/lib/src/domain/z_place_search_provider.dart` : classe abstraite `ZPlaceSearchProvider` (`search`, `details`) + `ZPlacePrediction` (`const`, `==`/`hashCode`/`toString`). **Aucune** dépendance réseau/clé/endpoint.
  - [x] Exporter depuis le barrel.
- [x] **T3 — Câblage `addressSearchField` + affordance recherche** (AC5, AC7)
  - [x] Étendre `ZAddressFieldWidget.builder(...)` : paramètre optionnel `ZPlaceSearchProvider? placeSearch` (capturé par closure) ; helper `registerZAddressFieldWidgets(...)` exposant le builder sous les kinds `"address"` **et** `"addressSearchField"` (enregistrement app/binding via `ZWidgetRegistry.register` — pas de modif core).
  - [x] Dans le widget : si `placeSearch != null`, `IconButton` loupe (`Semantics`, ≥ 48 dp) → `search` → sélection prédiction → `details` → `_fillFromPlace` → `_emit()` (voie unique AD-2). Si `null` → **rien** (rétro-compat stricte).
  - [x] Router une valeur de tranche `String` dans `_addressOf` via `ZAddressCodec.decodeString` (en plus de `ZPostalAddress`/`Map`).
- [x] **T4 — l10n** (AC5, AC8) : clés `intl.address.search`/`intl.address.formatted`/`intl.address.searchCancel` via le mécanisme `label(...)` (fallback FR) ; aucune chaîne codée en dur.
- [x] **T5 — Tests** (AC9) : `z_address_codec_test.dart` (round-trip + défensif), extension de `z_intl_field_widgets_test.dart` (seam mocké single-emit, double kind, provider absent, ingestion String), et extension denylist/couverture d'`isolation_gates_test.dart` (nouveaux fichiers + seam réseau-agnostique).
- [x] **T6 — Vérif verte** : `dart analyze` RC=0 → `flutter test` RC=0 (150 tests) sur `zcrud_intl` ; `graph_proof.py` CORE OUT=0 ; tests E11a-2/E11b-2 verts sans modification.

## Dev Notes

### Format address DODLP EXACT (source of truth relevée sur disque)

- Fichier : `dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:1454-1595` — `case EditionFieldTypes.address:` **et** `case EditionFieldTypes.addressSearchField:` tombent dans **le même bloc** (rendu identique). Enum : `dodlp-otr/lib/modules/data_crud/models.dart:76` (`addressSearchField`).
- **Valeur persistée du champ = String** : le widget est un `FormBuilderTextField(name: fieldName, minLines: 1, maxLines: 3, controller: fieldController, …)`. Le sélecteur Places fait `controller?.text = address.address;` et `onChanged: (String? value) { item = invokeItemSetter(item, attribute: fieldName, value: value); … }`. → **la valeur du champ `fieldName` est la String `address.address`**, pas un objet structuré.
- `address.address` (`dodlp-otr/lib/modules/data_crud/functions.dart:973-995` `googlePlaceDetalsToAddress`) = `details.formattedAddress` (sinon `placeDescription`/`details.name` si `formattedAddress` commence par `"Unnamed Road"`). Le type transitoire est `flutter_contacts.Address` (`~/.pub-cache/.../flutter_contacts-*/lib/properties/address.dart` : premier positionnel `String address`, + sous-champs `street/pobox/neighborhood/city/state/postalCode/country/isoCountry/subAdminArea/subLocality`). **Ces sous-champs ne sont PAS persistés dans la valeur du champ adresse** ; seuls `isoCountry`/frères partent via `field.onChange` vers d'autres attributs de l'item.
- Recherche : `google_maps.PlacesAutocomplete.show(context, apiKey:'', mode:overlay, sessionToken, components:[Component(country, isoCountry ?? "tg")], proxyBaseUrl: PROXY_BASE_URL)` puis `GoogleMapsPlaces(apiKey:'', baseUrl: PROXY_BASE_URL).getDetailsByPlaceId(prediction.placeId!, sessionToken)`. Clé **côté serveur** via proxy `https://api.zakarius.com/v1/googke_places_proxy/` (`dodlp-otr/lib/modules/data_crud/google_maps.dart:9`). ⇒ le seam zcrud doit rester **agnostique** (pas d'URL/clé) ; l'app DODLP branche son proxy.

**Conclusion de format** : schéma persisté DODLP du champ adresse = **`String` plate** (adresse formatée). Schéma zcrud = **`Map` structuré** (`ZPostalAddress.toMap`). Pont = `ZAddressCodec`.

### Stratégie de compat schéma (recommandée)

- **Ingestion (lecture)** : `decodeString(String legacy)` → `ZPostalAddress(formatted: legacy)`. Le widget affiche la String dans un sous-champ (via `formatted`) sans crash. `_addressOf` doit accepter `String` (nouveau branchement) en plus de `ZPostalAddress`/`Map`.
- **Persistance (écriture)** : deux modes, choisis **par l'app au bord de (dé)sérialisation du champ** (pas dans le cœur) :
  1. **Mode compat String** (collections DODLP migrées) : sérialiser via `encodeToString` → **reste une String** → aucune réécriture de format sur disque, round-trip stable (AC2/AC6).
  2. **Mode structuré natif** (collections zcrud neuves) : `ZPostalAddress.toMap` (défaut inchangé, E11a-2).
- La **lossy** structure→String (AC3) est assumée : on ne re-décompose pas une String en sous-champs (pas de parseur d'adresse embarqué). Migration fidèle = **ne pas perdre la String**, pas reconstruire la structure.
- `ZAddressCodec` reste des **fonctions pures** (couple decode/encode) ; le branchement au registre de codecs de champ (le cas échéant, cf. `ZCodecRegistry` du cœur, AD-7) est réalisé **par l'app/binding**, pas par une édition du cœur.

### Fichiers à toucher (tous dans `packages/zcrud_intl`)

- **NEW** `lib/src/domain/z_address_codec.dart` (T1).
- **NEW** `lib/src/domain/z_place_search_provider.dart` (T2).
- **UPDATE** `lib/src/presentation/z_address_field_widget.dart` — factory `.builder` (+ `placeSearch`), affordance recherche conditionnelle, `_addressOf` accepte `String`, helper d'enregistrement double-kind. **Préserver** : contrôleurs/focus stables par sous-champ (AD-2), `didUpdateWidget` sync guardée hors focus, voie d'émission unique `_emit()`, sélecteur subdivisions E11b-2, rétro-compat `config == null`.
- **UPDATE** `lib/zcrud_intl.dart` — exports additifs (`z_address_codec.dart`, `z_place_search_provider.dart`).
- **NEW** `test/z_address_codec_test.dart` ; **UPDATE** `test/z_intl_field_widgets_test.dart` (seam mocké, double kind, provider absent, ingestion String) ; **UPDATE** `test/isolation_gates_test.dart` (couverture nouveaux fichiers).

### État actuel des fichiers UPDATE (lu sur disque)

- `z_address_field_widget.dart` : `StatefulWidget` conforme AD-2 (contrôleurs `_line1.._postal` + 5 `FocusNode` créés en `initState`, disposés ; `_hasFocus` garde la sync ; `_emit()` recompose un `ZPostalAddress` neutre, émet `null` si vide). `_addressOf(Object?)` route déjà `ZPostalAddress` direct + `ZPostalAddress.fromMapSafe(value)` — **il faut y ajouter le branchement `String` → `ZAddressCodec.decodeString`**. `.builder({catalog, subdivisionCatalog, onInit, onBuild})` capture les catalogues par closure — **y ajouter `placeSearch`**. Le sélecteur pays inline + le slot région (texte libre OU `ZOptionPickerField` subdivisions) doivent rester intacts.
- `z_postal_address.dart` : `formatted` **existe déjà** (champ libre) — le codec s'y appuie, **aucune** évolution de `ZPostalAddress` requise.
- `zcrud_intl.dart` : barrel actuel exporte les 5 widgets + domaines ; ajouts additifs seulement.

### Besoin `zcrud_core` détecté

**AUCUN.** Le kind est une simple `String` au `ZWidgetRegistry` (enregistrer sous `"addressSearchField"` ne requiert pas de modif du cœur) ; le point d'extension `ZFieldConfig`/`ctx.field.config` et l'injection par closure (`catalog`, `subdivisionCatalog`, `placeSearch`) sont déjà disponibles ; `ZPostalAddress.formatted` existe déjà. Le codec et le port sont **entièrement** dans `zcrud_intl` (couche domaine pur-Dart). → Story **confinée à `zcrud_intl` (+ tests)**, conforme à la contrainte de périmètre. Si le dev découvre un manque de point d'extension core, **STOP + signaler** (ne pas éditer `zcrud_core`).

### Rappels AD applicables

- **AD-1/AD-14** : codec + port = domaine pur-Dart, aucune lib lourde ; barrel n'exporte aucun symbole tiers.
- **AD-2** : contrôleurs stables, voie d'émission unique `_emit()`, jamais de rebuild global (le remplissage Places passe par `_emit`).
- **AD-4/AD-10** : extensibilité additive, désérialisation défensive (codec ne throw jamais, `fromMapSafe` inchangé).
- **AD-12** : aucun défaut national codé en dur non surchargeable, **aucun secret/clé/endpoint** (le seam est vide de tout réseau).
- **AD-13** : `Semantics`, ≥ 48 dp, directionnel, thème injecté.

### Testing standards

- Framework : `flutter_test` (widget) + tests unitaires Dart pour le codec.
- Seam mocké : `FakeZPlaceSearchProvider implements ZPlaceSearchProvider` dans le test (pas de réseau).
- SM-1 : compteur `onBuild`/`onInit` déjà en place dans le widget — vérifier que le remplissage Places n'entraîne **pas** de rebuild global.
- Gates : `isolation_gates_test.dart` rejoué (AD-1/AD-12/AD-13 + secrets).

### Project Structure Notes

- Alignement : nouveaux fichiers sous `lib/src/domain/` (pur-Dart) et tests sous `test/`, cohérent avec E11a-2/E11b-2. Barrel = seule API publique.
- Variance : introduction de la **première** capacité « recherche géo » de `zcrud_intl`, jusqu'ici explicitement hors périmètre (E11b/AD-12) — légitime ici car **le package ne fournit que le seam**, l'implémentation réseau restant hors package.

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.5 Champs spécialisés — ligne `address` schéma (blocking) + §3 B10]
- [Source: docs/dodlp-edition-parity-gap.md#2.2 `address`/`addressSearchField` (mapping n:1)]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E-DP — DP-8]
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:1454-1595 (rendu address/addressSearchField, persistance String)]
- [Source: dodlp-otr/lib/modules/data_crud/functions.dart:973-995 (googlePlaceDetalsToAddress)]
- [Source: dodlp-otr/lib/modules/data_crud/google_maps.dart:9 (PROXY_BASE_URL — clé côté serveur)]
- [Source: packages/zcrud_intl/lib/src/domain/z_postal_address.dart (ZPostalAddress + `formatted`)]
- [Source: packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart (widget AD-2 existant)]
- [Source: packages/zcrud_core/lib/src/domain/registry/z_codec_registry.dart (ZCodecRegistry — enregistrement app-side)]
- [Source: CLAUDE.md — AD-1/AD-2/AD-4/AD-10/AD-12/AD-13/AD-14, Key Don'ts]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze` (cwd `packages/zcrud_intl`) → RC=0, « No issues found! ».
- `flutter test` (cwd `packages/zcrud_intl`, assets requis) → RC=0, **150 tests passés**.
- `python3 scripts/dev/graph_proof.py` → « CORE OUT=0 OK », ACYCLIQUE OK, `zcrud_intl -> zcrud_core` (aucune nouvelle arête).

### Completion Notes List

- **Périmètre STRICTEMENT confiné à `packages/zcrud_intl` (+ tests)** — AUCUNE modif de `zcrud_core` (le kind `addressSearchField` est une simple `String` au `ZWidgetRegistry` ; le dispatcher core résout déjà via `field.type.name` ; `ZPostalAddress.formatted` existait déjà). AUCUN besoin core détecté. AUCUN fichier DODLP touché.
- **AC1/AC2/AC3/AC6** — `ZAddressCodec` pur-Dart (`abstract final`) : `decodeString` (String legacy → `formatted`, défensif jamais throw pour `null`/vide/`Map`/`int`/`List`/`bool`/`double`/`Object`), `encodeToString` (préfère `formatted`, sinon compose `line1..countryCode` joint `", "`). Round-trip String byte-exact ; perte structure→String documentée en dartdoc.
- **AC4** — port `ZPlaceSearchProvider` (`search`/`details`) + `ZPlacePrediction` (`const`, `==`/`hashCode`/`toString`), pur-Dart, ZÉRO clé/endpoint/réseau. Gate secrets étendu (denylist réseau `http`/`google_maps_webservice`/`flutter_google_places`/… + assert codec/port sans Flutter) vert.
- **AC5** — helper `registerZAddressFieldWidgets(registry, …)` enregistre le **même** builder sous `address` ET `addressSearchField` ; `placeSearch` injecté par closure ; affordance loupe (`IconButton` ≥48 dp, `Semantics`) → dialogue `_PlaceSearchDialog` → remplissage `_fillFromPlace` → **un seul** `ctx.onChanged` (voie unique AD-2, prouvé par test single-emit).
- **AC7** — rétro-compat stricte : sans `placeSearch` aucun bouton recherche ; `_formatted` défaut `null` → chemin E11a-2 identique ; API `ZPostalAddress`/`ZIntlFieldConfig` inchangée (additif). Les 150 tests (dont E11a-2/E11b-2) verts sans modification des tests existants.
- **AC8** — codec+port couche `domain` pur-Dart (AD-14) ; widget `Semantics`/≥48 dp/`TextAlign.start`/`EdgeInsetsDirectional`/thème `ZcrudTheme` (AD-13) ; exports additifs au barrel. `isolation_gates_test.dart` étendu et vert.
- **AC9** — couverture : round-trip String + défensif (codec), round-trip structuré + perte (codec), seam mocké single-emit, double kind, provider absent, ingestion String legacy.
- Note qualité : aperçu `formatted` en lecture seule via `InputDecorator`+`Text` (pas de `TextEditingController` inline → aucune fuite, non recréé au build).

### File List

- NEW `packages/zcrud_intl/lib/src/domain/z_address_codec.dart`
- NEW `packages/zcrud_intl/lib/src/domain/z_place_search_provider.dart`
- UPDATE `packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart`
- UPDATE `packages/zcrud_intl/lib/zcrud_intl.dart`
- NEW `packages/zcrud_intl/test/z_address_codec_test.dart`
- UPDATE `packages/zcrud_intl/test/z_intl_field_widgets_test.dart`
- UPDATE `packages/zcrud_intl/test/isolation_gates_test.dart`

### Change Log

- DP-8 : `ZAddressCodec` (compat String legacy DODLP) + seam `ZPlaceSearchProvider`/`ZPlacePrediction` + câblage double-kind `address`/`addressSearchField` + affordance recherche géo (voie unique AD-2). Confiné à `zcrud_intl`. (2026-07-11)
