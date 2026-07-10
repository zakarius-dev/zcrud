---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story E11b.1 : zcrud_geo complet — cercle + `ZGeoFieldConfig` + 2ᵉ adaptateur (Google **et** OSM)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant un champ géo riche (au-delà de la parité MVP DODLP livrée en E11a-1)**,
je veux **compléter `zcrud_geo` avec la géométrie « cercle », une config de champ surchargeable (`ZGeoFieldConfig`) et un second adaptateur carte (Google, en parité de l'OSM existant)**,
afin que **la triade FR-20 « point / polygone / cercle » soit couverte, que l'app hôte choisisse Google *ou* OSM sans imposer de dépendance au reste, et sans embarquer aucune clé API ni défaut national codé en dur non surchargeable (AD-12), le tout SANS toucher `zcrud_core` (AD-1) ni régresser AD-2/AD-10/AD-13.**

## Contexte & cadrage

**Épopée E11b — Reste géo / intl / export (v1.x/v2).** Objectif de l'épopée : **compléter au-delà du lot parité MVP** (E11a). **Couvre :** FR-20, FR-21, FR-8-export (reste) · AD-12. **Dépend de :** E11a. **Phase :** v1.x/v2. Source : `epics.md` §E11b (l. 150-155).

Story E11b-1 = **`zcrud_geo` complet** : d'après l'épopée (l. 153) « polygone/cercle + 2ᵉ adaptateur (Google **et** OSM), `GeoFieldConfig` ; AC : édition point/polygone/cercle ; les deux adaptateurs ; aucun défaut national codé en dur non surchargeable ». FR-20 (`prd.md` l. 283-287) : « champ géo (point/polygone/cercle) … `ZGeoShape` agnostique du SDK ; adaptateurs Google/OSM optionnels ; **aucune clé API embarquée dans le package** ».

### Écart E11a-1 → « complet » (vérifié sur disque)

**DÉJÀ livré en E11a-1** (`packages/zcrud_geo/`, story `e11a-1-*`, `done`, 52 tests) — **NE PAS ré-implémenter, réutiliser** :
- **Modèles neutres** : `ZGeoPoint` (point, lat/lng + label/address, bornes/défensif AD-10) et `ZGeoShape` (polygone = `List<ZGeoPoint> vertices`), `toMap`/`fromMapSafe` défensifs, `==`/`hashCode`/`copyWith`. Aucun type SDK en signature.
- **Port carte neutre** `ZMapAdapter` (`buildMap(context, {center, shape, onTap, interactive})` + `dispose`) + fabrique `ZMapAdapterFactory` (une instance par montage, MAJEUR-1 corrigé).
- **`ZGeoFieldWidget`** (patron AD-2 : contrôleurs/focus `late final` créés 1× en `initState`, sync guardée hors focus, écriture via `ctx.onChanged`, `_workingShape` atomique MEDIUM-3, `_pointOf` re-check `isValid` LOW-5, `label()` l10n + `mapHeight` LOW-4, dispose du contrôleur natif), servi via `ZWidgetRegistry` (kind = `field.type.name` : `"location"`/`"geoArea"`).
- **`ZOsmMapAdapter`** (`flutter_map`, SANS clé, confiné à `src/presentation/adapters/z_osm_map_adapter.dart` + entrée `lib/adapters/osm.dart`).
- **Gates** : isolation carte (`flutter_map`/`latlong2` au seul `zcrud_geo/pubspec.yaml`, jamais `zcrud_core` — CORE OUT=0), scan secrets, RTL/a11y/thème.

**MANQUE pour « complet »** (périmètre de CETTE story) :
1. **Géométrie « cercle »** — non modélisée. FR-20 exige point/polygone/**cercle**. → nouveau modèle neutre `ZGeoCircle` (centre + rayon) + édition + rendu.
2. **`ZGeoFieldConfig`** — la géométrie du champ est aujourd'hui **inférée du nom d'enum** (`location`→point, `geoArea`→polygone) et il n'existe **aucun** « cercle » dans `EditionFieldType` (et on **ne peut pas** en ajouter : `zcrud_core` interdit d'édition). → porter la géométrie et les défauts **surchargeables** (centre/zoom/hauteur/URL de tuiles ou style) **par champ** via une **config additive** `ZGeoFieldConfig extends ZFieldConfig` (point d'extension AD-4 **déjà prévu** par le cœur, cf. *Impact zcrud_core*).
3. **2ᵉ adaptateur : Google** — seul l'OSM existe. FR-20/épopée : « adaptateurs Google **et** OSM ». → `ZGoogleMapAdapter` (`google_maps_flutter`) confiné, sans clé.
4. **Rendu cercle dans le port + adaptateurs** — `ZMapAdapter.buildMap` gagne un paramètre optionnel `ZGeoCircle? circle` (additif, rétro-compatible), rendu par OSM (`CircleLayer`) et Google (`Circle`).

### Périmètre RETENU (IN) vs HORS-story

**IN (cette story) :** ZGeoCircle · ZGeoFieldConfig (géométrie + défauts surchargeables) · édition cercle dans `ZGeoFieldWidget` · extension additive `buildMap(... circle)` du port + OSM circle + `ZGoogleMapAdapter` (confiné, sans clé) · gates isolation/secrets étendus à Google · vérif verte.

**HORS-story (explicite, ne PAS anticiper) :**
- **Géocodage / reverse-geocoding** (port `ZGeocoder`) — non nommé par FR-20/E11b-1 (dont l'AC est point/polygone/cercle + 2 adaptateurs + config). Risque « service à clé »/no-secret. → **v2 / story dédiée ultérieure**. Un point d'extension pourra être ajouté proprement plus tard sans casser cette story.
- **Clustering de marqueurs, dessin gestuel avancé de polygone (drag des sommets sur la carte), multi-polygone/trous** → v2.
- **`zcrud_intl` (E11b-2)** et **`zcrud_export` (E11b-3)** — stories distinctes de l'épopée.
- **Assertion de rendu interactif complet de la carte Google sous `flutter test`** — `google_maps_flutter` s'affiche via une **PlatformView native** qui **ne peint pas** dans le harnais headless. La preuve automatisée du `ZGoogleMapAdapter` se limite donc à : conformité de signature neutre, confinement SDK, no-secret, `dispose` idempotent, `buildMap(...)` sans exception au build. Le rendu interactif réel est validé **hors CI** (appareil/intégration). Ce n'est **pas** une lacune mais une limite du harnais (cf. AC9, *Stratégie de tests*).

### ADs applicables (NON-NÉGOCIABLES)

- **AD-1** — `zcrud_geo → zcrud_core` uniquement ; `google_maps_flutter` (comme `flutter_map`) ne fuit **jamais** dans `zcrud_core` ni dans la valeur de tranche ni dans une signature publique du barrel ; adaptateurs **optionnels**, confinés à leur fichier + entrée d'import dédiée ; graphe acyclique (CORE OUT=0) préservé.
- **AD-2 / SM-1** — l'édition cercle respecte le patron : `TextEditingController`/`FocusNode` stables (`late final`, create/dispose, jamais recréés/ré-injectés en frappe), rebuild ciblé à la tranche, focus préservé. Voie d'écriture unique `ctx.onChanged`.
- **AD-4** — `ZGeoFieldConfig` est une **sous-classe concrète `const` de `ZFieldConfig`** (base abstraite déjà prévue par le cœur) déclarée **dans `zcrud_geo`** ; lue via `ctx.field.config` ; **aucune** modification du cœur, aucun `sealed`, aucun héritage de type sérialisé. La géométrie « cercle » passe par la **config**, PAS par une nouvelle valeur d'enum `EditionFieldType`.
- **AD-10** — `ZGeoCircle.fromMapSafe` défensif : centre absent/invalide, rayon absent/non numérique/non fini/négatif → état neutre (`null`), **jamais** de throw ; `ZGeoFieldConfig` tolère des valeurs absentes (défauts sûrs).
- **AD-12** — **AUCUNE clé API/secret** dans `zcrud_geo` (la clé Google Maps est fournie par la **config plateforme** de l'app hôte — manifest Android/`AppDelegate` iOS, E1-5). Interdits : clé littérale, `badCertificateCallback => true`, endpoint/tuile privé en dur non surchargeable. « Aucun défaut national codé en dur non surchargeable » (épopée) : centre/zoom/style de `ZGeoFieldConfig` ont des défauts **neutres et surchargeables**.
- **AD-13** — RTL directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional`), `Semantics` explicites, cibles ≥ 48 dp, thème injecté (`ZcrudTheme.of`, repli `Theme.of`), zéro couleur/style en dur ; libellés visibles via `label()`/`ZcrudScope.labels`.
- **AD-14/AD-15** — `ZGeoCircle` (domaine) = **pur-Dart** (aucun Flutter/SDK) ; `ZGeoFieldConfig` = pur-données `const` ; **aucun** gestionnaire d'état importé.

## Conception (résumé pour le dev)

1. **Modèle `ZGeoCircle` neutre** (`lib/src/domain/z_geo_circle.dart`, pur-Dart) :
   - `ZGeoCircle { ZGeoPoint center; double radiusMeters; String? label; }`. `radiusMeters > 0` fini ; centre valide (réutilise `ZGeoPoint.isValid`).
   - `toMap()` (`{center: {...}, radius_m: …, label?}`) ; `fromMapSafe(raw)` **défensif AD-10** (centre `ZGeoPoint.fromMapSafe`; rayon `num`/`String`→`double` fini > 0 ; sinon `null`, jamais de throw). `isValid`, `copyWith`, `==`/`hashCode`/`toString`.
   - **Aucun** type SDK (pas de `Circle`/`LatLng`). Exporté par le barrel.
2. **Config `ZGeoFieldConfig extends ZFieldConfig`** (`lib/src/domain/z_geo_field_config.dart`, pur-données `const`) :
   - `enum ZGeoGeometry { point, polygon, circle }`.
   - Champs surchargeables (défauts **neutres**, jamais « national en dur ») : `geometry` (nullable → repli inférence type-name), `ZGeoPoint? defaultCenter` (défaut `null` → adaptateur choisit un centre neutre), `double? defaultZoom`, `double? mapHeight`, `String? tileUrlTemplate` (OSM ; surchargeable), `String? mapStyleJson` (Google ; surchargeable), `bool interactive = true`.
   - `const`, `==`/`hashCode`. **Zéro** dépendance lourde. Vit dans `zcrud_geo` (AD-4, cf. docstring de `ZFieldConfig` qui nomme littéralement `GeoFieldConfig → zcrud_geo`).
3. **Édition cercle dans `ZGeoFieldWidget`** :
   - **Résolution de géométrie** : `final cfg = ctx.field.config is ZGeoFieldConfig ? … : null; final geometry = cfg?.geometry ?? _builderDefaultGeometry ?? _fromTypeName(field.type.name)` (`location`→point, `geoArea`→polygon). **Rétro-compat E11a-1 stricte** : sans config, comportement identique.
   - **Mode cercle** : deux `TextEditingController` centre (lat/lng) + un contrôleur **rayon** (`_radiusController`), tous `late final` créés 1× (`initState`), disposés en `dispose`. Tap carte → fixe le centre (rayon conservé). Saisie/tap recompose un `ZGeoCircle` neutre émis via `ctx.onChanged` (ou `null` si incomplet/invalide — AD-10). Sync guardée hors focus (comme `location`). Rayon invalide/≤0 → pas d'émission de cercle valide.
   - Refactor interne minimal : généraliser le `switch (geometry)` (point/polygon/circle) sans élargir la frontière de rebuild ni casser les chemins existants.
   - `mapHeight` : `cfg?.mapHeight ?? widget.mapHeight` (défaut existant 200). Défauts centre/zoom passés à l'adaptateur via `buildMap`.
4. **Extension additive du port `ZMapAdapter`** :
   - `Widget buildMap(context, {ZGeoPoint? center, ZGeoShape? shape, ZGeoCircle? circle, ValueChanged<ZGeoPoint>? onTap, bool interactive = true})` — **paramètre `circle` optionnel, défaut `null`** (rétro-compatible pour les appelants). Les implémenteurs internes (`ZOsmMapAdapter`, `FakeMapAdapter` de test) adoptent la nouvelle signature. *(Note compat : évolution mineure 0.x d'un port ; un adaptateur externe éventuel recompile — additif, non-cassant fonctionnellement.)*
5. **`ZOsmMapAdapter` : rendu cercle** — `CircleLayer`/`CircleMarker` (`flutter_map`) quand `circle != null` ; rayon en mètres. Toujours SANS clé, `tileUrlTemplate` surchargeable.
6. **`ZGoogleMapAdapter` (2ᵉ adaptateur)** — `lib/src/presentation/adapters/z_google_map_adapter.dart` + entrée dédiée `lib/adapters/google.dart` :
   - `implements ZMapAdapter` en **types neutres uniquement** ; `google_maps_flutter` (types `GoogleMap`/`GoogleMapController`/`LatLng`/`Marker`/`Polygon`/`Circle`) **confiné** à ce fichier (jamais exporté par le barrel principal, jamais dans `zcrud_core`).
   - `buildMap` : `GoogleMap` centré ; `onTap` → `ZGeoPoint` neutre ; polygone (`Set<Polygon>`), cercle (`Set<Circle>`), marqueur centre. `mapStyleJson` surchargeable. **AUCUNE clé** dans le code (la clé vit dans le manifest/AppDelegate de l'app hôte). Possède un `Completer<GoogleMapController>` disposé en `dispose()` (idempotent, learning E5).
   - `pubspec.yaml` de `zcrud_geo` : ajoute `google_maps_flutter: ^2.x` — **rien** dans `zcrud_core`.
7. **Barrel & entrées** — `lib/zcrud_geo.dart` exporte `ZGeoCircle`, `ZGeoFieldConfig`, `ZGeoGeometry` (modèles neutres) ; **PAS** de symbole SDK. OSM via `lib/adapters/osm.dart`, Google via `lib/adapters/google.dart` (deux voies d'import explicites, hors barrel principal).
8. **Gates** — isolation (`google_maps_flutter` au seul `zcrud_geo/pubspec.yaml`, jamais `zcrud_core` ; importé uniquement dans `z_google_map_adapter.dart` ; absent du barrel principal) ; secrets (aucune clé Google/token, aucun `badCertificateCallback`).

### Impact zcrud_core

**NON — aucune modification de `zcrud_core`.** Justification vérifiée sur disque :
- **`ZFieldConfig` est déjà le point d'extension AD-4** attendu. Sa docstring (`packages/zcrud_core/lib/src/domain/edition/z_field_config.dart`, l. 6-12) nomme **explicitement** : « les configs **lourdes** (`GeoFieldConfig` → **zcrud_geo**/E11a …) sont **additives** et appartiennent à leurs packages/stories — **jamais tirées dans le cœur** ». La base est `abstract` (jamais `sealed`) précisément pour l'extension inter-package.
- **`ZFieldSpec.config` (`ZFieldConfig?`) existe déjà** (`z_field_spec.dart`, l. 40 & 64) et **circule jusqu'au widget** via `ctx.field.config` (le dispatcher passe `ZFieldWidgetContext(field: …)`). La géométrie « cercle » est donc portée **par la config par-champ**, sans nouvelle valeur d'enum ni slot `ZcrudScope`.
- Le seam `ZWidgetRegistry` + routage `registryOrFallback` + repli `ZUnsupportedFieldWidget` (E11a-1) restent inchangés. La fabrique d'adaptateur est toujours **capturée par closure** de `builder`.

→ **Aucune sérialisation de fichier core à prévoir.** Si, en cours de dev, un besoin RÉEL de toucher `zcrud_core` apparaissait (p. ex. une nouvelle valeur `EditionFieldType.geoCircle` jugée indispensable), **STOP + signalement à l'orchestrateur** AVANT toute édition du cœur — la conception ci-dessus (géométrie via `ZGeoFieldConfig`) est faite précisément pour l'éviter.

## Acceptance Criteria

1. **Modèle `ZGeoCircle` neutre & sérialisable (AD-1/AD-14).** `ZGeoCircle { ZGeoPoint center; double radiusMeters; String? label }` vit dans `zcrud_geo` (`src/domain/`, pur-Dart), expose `toMap`/`fromMapSafe`/`isValid`/`copyWith`, round-trip stable. **Aucun** type SDK carte n'apparaît dans son API publique. *Test : round-trip `toMap→fromMapSafe` ; `dart analyze` ; grep signature sans `LatLng`/`Circle`.*
2. **Défensif `ZGeoCircle` (AD-10).** `raw` non-`Map`, centre absent/invalide, rayon absent/non numérique/non fini (NaN/Inf)/≤0 → `fromMapSafe` retourne `null` **sans jamais throw** ; `isValid` faux pour rayon ≤0 ou centre hors-bornes. *Test : table de cas (absent, non-num, NaN/Inf, rayon 0, rayon négatif, centre lat=200) → `null`/invalide, pas d'exception.*
3. **`ZGeoFieldConfig` additive (AD-4), lue par-champ.** `ZGeoFieldConfig extends ZFieldConfig` (`const`, pur-données) porte `ZGeoGeometry geometry` + défauts **surchargeables** (`defaultCenter`/`defaultZoom`/`mapHeight`/`tileUrlTemplate`/`mapStyleJson`/`interactive`) et vit dans `zcrud_geo` ; posée sur `ZFieldSpec.config`, elle est lue via `ctx.field.config` par le widget. **Aucune** modification de `zcrud_core`. *Test : `ZGeoFieldConfig(...)` assignée à `ZFieldSpec.config` → le widget résout la géométrie/les défauts depuis la config ; `==`/`hashCode` corrects ; `dart analyze` (core intact).*
4. **Édition cercle (AD-2).** En géométrie `circle`, saisir centre (lat/lng) + rayon (ou taper la carte pour fixer le centre) écrit un `ZGeoCircle` neutre dans la tranche via `ctx.onChanged` ; rayon absent/invalide/≤0 → pas de cercle valide émis (état neutre). *Test widget : saisie centre+rayon → `controller.valueOf(field)` == `ZGeoCircle` attendu ; rayon `-5`/`0` → cercle non valide / `null`.*
5. **Rétro-compatibilité E11a-1 (aucune régression).** Sans `ZGeoFieldConfig` (config `null`), la géométrie reste inférée du `field.type.name` (`location`→point, `geoArea`→polygon) et le comportement E11a-1 est **identique** ; les 52 tests E11a-1 restent verts. *Test : champ `location`/`geoArea` sans config → mêmes chemins qu'E11a-1 (point/polygone), suite E11a-1 verte.*
6. **Port `ZMapAdapter` étendu, rétro-compatible.** `buildMap` gagne `ZGeoCircle? circle` (optionnel, défaut `null`) ; les appelants existants (repli, tap) compilent inchangés ; `ZOsmMapAdapter` et le fake adoptent la signature. *Test : appel `buildMap` sans `circle` (chemins E11a-1) OK ; avec `circle` → surface rendue sans exception.*
7. **OSM : rendu cercle (sans clé).** Avec `circle != null`, `ZOsmMapAdapter` rend un cercle (`CircleLayer`/`CircleMarker`, rayon mètres) sous `MaterialApp` sans exception ; toujours SANS clé, `tileUrlTemplate` surchargeable ; `dispose` idempotent. *Test : `ZOsmMapAdapter.buildMap(circle: …)` pump réel sans throw ; double `dispose()` `returnsNormally`.*
8. **2ᵉ adaptateur Google — port neutre, SDK confiné, sans clé (AD-1/AD-12).** `ZGoogleMapAdapter implements ZMapAdapter` en signatures **neutres** (aucun type `google_maps_flutter` en API publique) ; `google_maps_flutter` importé **uniquement** dans `src/presentation/adapters/z_google_map_adapter.dart`, atteint via `lib/adapters/google.dart`, **absent** du barrel principal ; **aucune** clé/token/`badCertificateCallback` dans le package ; `dispose()` idempotent. *Test : conformité de signature (compile + grep API sans type SDK) ; `dispose()` ×2 `returnsNormally` ; `buildMap(...)` construit sans throw (PlatformView non peinte en headless — cf. note testabilité).*
9. **Gate isolation étendu (AD-1).** `google_maps_flutter` (et `flutter_map`/`latlong2`) n'apparaissent **qu'au** `pubspec.yaml` de `zcrud_geo` (jamais `zcrud_core` — CORE OUT=0) ; le barrel `lib/zcrud_geo.dart` n'exporte aucun symbole SDK ; les imports SDK ne vivent que dans les deux fichiers d'adaptateur. *Gate/test : assertions sur `pubspec` (`zcrud_core` sans lib carte, `zcrud_geo` avec) + grep imports SDK confinés + barrel sans `adapters/`.*
10. **Gate secrets étendu (AD-12).** Aucune clé Google Maps / token / endpoint privé en dur dans `zcrud_geo` ; aucun `badCertificateCallback => true` ; défauts (centre/zoom/tuiles/style) neutres et surchargeables. *Gate : scan de secrets vert (regex clé Google/`badCertificateCallback`) sur `lib/` récursif (inclut les 2 adaptateurs).*
11. **Thème injecté + RTL + a11y ≥48 dp (AD-13).** Le champ cercle : couleurs/styles via `ZcrudTheme.of` (repli `Theme.of`), paddings/alignements **directionnels**, `Semantics` explicites, cibles tactiles ≥ 48 dp, libellés visibles via `label()`/`ZcrudScope.labels` (ex. `geo.radius`, `geo.center`). *Test : rendu sous `Directionality.rtl` sans exception + audit statique (grep anti `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, couleur littérale, chaîne UI figée).*
12. **Anti-fuite de cycle de vie (learning E5).** Les contrôleurs centre/rayon + focus + le contrôleur natif des DEUX adaptateurs (OSM `MapController`, Google `GoogleMapController`) sont disposés ; `dispose` idempotent ; aucun listener/contrôleur fuité. *Test : pump→pumpWidget(SizedBox) ; fake `disposed==true` ; double dispose des adaptateurs réels `returnsNormally`.*
13. **Vérif verte rejouée.** `melos run generate` OK → `dart/flutter analyze` RC=0 (workspace) → `flutter test` (`zcrud_geo`) RC=0 → `melos run verify` (graphe ACYCLIQUE, CORE OUT=0, secrets, reflectable, codegen, compat) RC=0 ; `melos list` = 14. *Gate `done`.*

## Tasks / Subtasks

- [x] **T1 — Modèle `ZGeoCircle` neutre** (AC: 1, 2)
  - [x] `lib/src/domain/z_geo_circle.dart` : `ZGeoCircle` (centre `ZGeoPoint` + `radiusMeters` + `label?`), `toMap`/`fromMapSafe` défensif (rayon fini > 0, centre valide), `isValid`, `copyWith`, `==`/`hashCode`/`toString`. Aucun type SDK.
- [x] **T2 — Config `ZGeoFieldConfig` (AD-4)** (AC: 3)
  - [x] `lib/src/domain/z_geo_field_config.dart` : `enum ZGeoGeometry { point, polygon, circle }` + `ZGeoFieldConfig extends ZFieldConfig` (`const`, défauts surchargeables neutres, `==`/`hashCode`). Aucune dep lourde ; `import 'package:zcrud_core/zcrud_core.dart'` pour la base `ZFieldConfig`.
- [x] **T3 — Édition cercle + résolution de géométrie par config** (AC: 3, 4, 5, 11, 12)
  - [x] `z_geo_field_widget.dart` : résoudre `geometry` = `config?.geometry ?? _builderDefault ?? _fromTypeName` (rétro-compat E11a-1) ; ajouter le mode `circle` (contrôleur rayon `late final`, tap→centre, émission `ZGeoCircle`/`null` défensif, sync guardée hors focus) ; défauts (`mapHeight`/centre) depuis la config ; thème/RTL/a11y/labels ; dispose du contrôleur rayon.
  - [x] Ne PAS élargir la frontière de rebuild ; ne PAS casser les chemins point/polygone existants.
- [x] **T4 — Extension additive du port + OSM cercle** (AC: 6, 7, 12)
  - [x] `z_map_adapter.dart` : `buildMap(... ZGeoCircle? circle …)` (optionnel défaut `null`).
  - [x] `z_osm_map_adapter.dart` : rendu `CircleLayer`/`CircleMarker` (`useRadiusInMeter`) quand `circle` valide ; signature mise à jour ; `dispose` idempotent conservé.
  - [x] `test/support/fake_map_adapter.dart` : adopter la signature + capturer `circle`.
- [x] **T5 — 2ᵉ adaptateur Google (confiné, sans clé)** (AC: 8, 9, 10, 12)
  - [x] `lib/src/presentation/adapters/z_google_map_adapter.dart` : `implements ZMapAdapter` via `google_maps_flutter` (types SDK confinés) ; `buildMap` (centre/polygone/cercle/tap neutre, `mapStyleJson` surchargeable, **zéro clé**) ; `Completer<GoogleMapController>` disposé en `dispose` idempotent.
  - [x] `lib/adapters/google.dart` : entrée d'export dédiée (hors barrel principal), docstring d'usage (`adapterFactory: ZGoogleMapAdapter.new`, clé = config plateforme).
  - [x] `pubspec.yaml` : ajouté `google_maps_flutter: ^2.9.0` (résolu 2.17.1) — rien dans `zcrud_core`.
- [x] **T6 — Barrel & exports** (AC: 1, 3, 9)
  - [x] `lib/zcrud_geo.dart` : exporte `ZGeoCircle`, `ZGeoFieldConfig`, `ZGeoGeometry` ; **aucun** symbole SDK (Google/OSM hors barrel principal).
- [x] **T7 — Tests** (AC: 1-12) — voir *Stratégie de tests*.
- [x] **T8 — Gates** (AC: 9, 10, 13)
  - [x] Étendu `isolation_gates_test.dart` (Google au `zcrud_geo`, absent de `zcrud_core`, imports confinés au seul adaptateur, barrel sans SDK) + scan secrets Google + `graph_proof` CORE OUT=0.
  - [x] `analyze` (workspace) + `test` (`zcrud_geo`) RC=0 ; gates `graph`/`secrets`/`reflectable`/`codegen`/`melos`/`compat` verts. NB `verify:serialization` repo-wide est RED hors-périmètre (crash de compilation d'un test `zcrud_flashcard` — WS-B/E9-3 en cours ; aucun lien avec `zcrud_geo`).

## Stratégie de tests

- **Unitaires modèle (pur-Dart)** : `z_geo_circle_test.dart` — round-trip `toMap`/`fromMapSafe` ; table défensive AD-10 (raw non-Map, centre absent/invalide/hors-bornes, rayon absent/non-num/NaN/Inf/0/négatif → `null` ; `isValid`) ; `copyWith`/`==`/`hashCode`.
- **Config** : `z_geo_field_config_test.dart` — `const`/égalité ; assignée à `ZFieldSpec.config` puis lue via `ctx.field.config` (le cœur route la config, non modifié).
- **Widget cercle** : `z_geo_field_widget_test.dart` (étendu) — (a) config `geometry: circle` → mode cercle rendu (centre + rayon) ; saisie → tranche `ZGeoCircle` neutre ; rayon `0`/`-5` → cercle non valide/`null` ; (b) tap carte (fake) → fixe le centre, cercle recomposé ; (c) **rétro-compat** : sans config, `location`/`geoArea` inchangés (point/polygone) ; (d) SM-1 : `onInit==1`, focus préservé après frappe du rayon ; (e) dispose → fake `disposed==true` ; (f) `Directionality.rtl` sans exception.
- **OSM cercle** : `z_osm_map_adapter_test.dart` (étendu) — `buildMap(circle: …)` pump réel sous `MaterialApp` sans throw ; `dispose` idempotent.
- **Google adaptateur** : `z_google_map_adapter_test.dart` (nouveau) — conformité port (`is ZMapAdapter`), signatures neutres (compile) ; `dispose()` ×2 `returnsNormally` ; `buildMap(...)` construit sans throw (PlatformView non peinte en headless — assertion limitée au non-throw + confinement). Grep : `google_maps_flutter` importé nulle part ailleurs.
- **Gates statiques** : `isolation_gates_test.dart` (étendu) — `zcrud_core/pubspec.yaml` sans `google_maps_flutter`/`flutter_map`/`latlong2` ; `zcrud_geo/pubspec.yaml` AVEC ; barrel principal sans `adapters/`/symbole SDK ; imports SDK confinés aux 2 fichiers d'adaptateur ; scan secrets (clé Google/`badCertificateCallback`) sur `lib/` récursif ; scan RTL/chaînes figées.
- **Fakes en test** (pas de SDK réel côté widget) : `FakeMapAdapter` reste l'oracle du contrat (rendu/tap/circle/dispose) — prouve l'isolation AD-1 sans dépendre d'un vrai rendu carte.

## Dev Notes

### Fichiers du cœur à NE PAS modifier (lecture de référence — l'enabler AD-4)

- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` — **base abstraite `ZFieldConfig` (AD-4)**. Docstring (l. 6-12) : `GeoFieldConfig → zcrud_geo` est **additive**, hors cœur. `ZGeoFieldConfig` en hérite ici, dans `zcrud_geo`. **Ne pas** ajouter la config géo au cœur.
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (l. 40, 64) — `ZFieldConfig? config` déjà présent et circulant jusqu'au widget (`ctx.field.config`).
- `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` — `ZWidgetRegistry`/`ZFieldWidgetBuilder`/`ZFieldWidgetContext` (contrat inchangé ; le kind reste `field.type.name`).
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` — `location`/`geoArea` présents ; **PAS de nouvelle valeur** (le « cercle » passe par `ZGeoFieldConfig`, pas par l'enum).

### Fichiers `zcrud_geo` à réutiliser/étendre (E11a-1, lecture obligatoire)

- `lib/src/domain/z_geo_point.dart` (réutilisé tel quel : `center`, `isValid`, `fromMapSafe`, `_asFiniteDouble` en modèle du parse rayon défensif).
- `lib/src/domain/z_geo_shape.dart` (polygone inchangé).
- `lib/src/presentation/z_map_adapter.dart` (ajout param `circle`), `z_geo_field_widget.dart` (ajout mode cercle + résolution config), `adapters/z_osm_map_adapter.dart` (rendu cercle), `test/support/fake_map_adapter.dart` (signature).
- `lib/zcrud_geo.dart`, `lib/adapters/osm.dart` (modèle pour `lib/adapters/google.dart`), `pubspec.yaml`.

### Learnings absorbés (E11a-1 code-review)

- **MAJEUR-1** : adaptateur via **fabrique** (`ZMapAdapterFactory`), une instance possédée par montage, disposée en `dispose` — appliquer **à l'identique** au `ZGoogleMapAdapter` (jamais d'instance partagée ; `ZGoogleMapAdapter.new` comme fabrique).
- **MEDIUM-2** : tester le **vrai** adaptateur (idempotence `dispose`, `buildMap` sans throw) — impératif pour Google (contrôleur natif). Ne pas se contenter du fake.
- **MEDIUM-3** : mutations d'état (ici centre/rayon du cercle) **atomiques** (état local possédé) si plusieurs événements dans la même frame ; ré-injection guardée hors focus.
- **LOW-4/LOW-5** : libellés via `label()`/`ZcrudScope.labels` (`geo.radius`, `geo.center`) ; ne faire confiance qu'aux valeurs `isValid` en lecture de tranche (re-parse défensif sinon).
- **E5** : disposer TOUT contrôleur natif (OSM `MapController`, Google `GoogleMapController` via `Completer`).

### Testabilité Google (à intégrer, non-négociable)

`google_maps_flutter` s'affiche via une **PlatformView native** non peinte par `flutter test`. La preuve automatisée se limite à : (1) `implements ZMapAdapter` compile avec signatures neutres ; (2) SDK confiné (grep) ; (3) no-secret (scan) ; (4) `dispose()` idempotent ; (5) `buildMap(...)` construit sans exception. Le rendu interactif réel est **hors CI** (appareil). C'est cohérent avec l'esprit AD-1 (le port neutre + le fake portent la preuve fonctionnelle ; l'adaptateur réel prouve le confinement/cycle de vie).

### Project Structure Notes

- Tout sous `packages/zcrud_geo/lib/` : `src/domain/` (`z_geo_circle.dart`, `z_geo_field_config.dart` — pur-Dart/données) ; `src/presentation/adapters/` (`z_google_map_adapter.dart`) ; entrées `lib/adapters/{osm,google}.dart`. Barrel `lib/zcrud_geo.dart`. Tests sous `test/`. Aucun `*.g.dart` committé.
- Nommage : types publics préfixés `Z` (`ZGeoCircle`, `ZGeoFieldConfig`, `ZGeoGeometry`, `ZGoogleMapAdapter`) ; fichiers snake_case ; persistance snake_case (`radius_m`), enums camelCase.

### Latest tech (à confirmer via `pub`/`dry-run` au dev)

- **Google :** `google_maps_flutter` (≈ ^2.9.x/^2.14.x en 2026) — la clé reste **hors package** (manifest Android `com.google.android.geo.API_KEY` / `AppDelegate` iOS, E1-5). Ne PAS l'introduire en dur.
- **OSM cercle :** `flutter_map` (^8.3.1 déjà résolu) — `CircleLayer`/`CircleMarker` (`useRadiusInMeter: true`).
- Confirmer compat SDK Dart `^3.12.2` + gate compat (E1-4, `dart pub get --dry-run`) après ajout `google_maps_flutter`.

### References

- [Source: epics.md#E11b] (`_bmad-output/planning-artifacts/epics/…/epics.md` l. 150-153) — E11b-1 : polygone/cercle + 2ᵉ adaptateur (Google **et** OSM), `GeoFieldConfig` ; aucun défaut national codé en dur non surchargeable.
- [Source: prd.md#FR-20] l. 283-287 — champ géo point/polygone/cercle ; `ZGeoShape` agnostique SDK ; adaptateurs Google/OSM optionnels ; **aucune clé API dans le package**.
- [Source: architecture.md#AD-12] l. 112-115 — zéro secret ; pas de `badCertificateCallback` ; endpoints surchargeables.
- [Source: architecture.md#AD-1] l. 49 — arête `zcrud_geo → zcrud_core` ; l. 171 — `google_maps_flutter`/`flutter_osm_plugin` optionnels confinés à `zcrud_geo`.
- [Source: architecture.md#AD-4] — extension par sous-classe additive (jamais `sealed`) ; base abstraite.
- [Source: zcrud_core] `z_field_config.dart` (base `ZFieldConfig` abstraite, docstring `GeoFieldConfig → zcrud_geo`, l. 6-12) ; `z_field_spec.dart` (l. 40/64, `config` circule jusqu'au widget).
- [Source: e11a-1-zcrud-geo-champ-geo-carte.md] — modèles/port/widget/OSM déjà livrés ; patron AD-2 ; fabrique d'adaptateur (MAJEUR-1).
- [Source: code-review-e11a-1.md] — learnings MAJEUR-1/MEDIUM-2/-3/LOW-4/-5, à répliquer.
- [Source: CLAUDE.md] Key Don'ts — jamais de secret/clé Maps dans un package ; jamais de type carte lourd dans `zcrud_core` ; thème injecté ; RTL directionnel ; cibles ≥ 48 dp ; `ListView.builder`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story` invoqué via le tool `Skill` — pas de fallback disque).

### Debug Log References

- `dart pub get` (packages/zcrud_geo) → RC=0 ; `google_maps_flutter` résolu **2.17.1** (contrainte `^2.9.0`).
- `dart analyze packages/zcrud_geo` → RC=0 (No issues found).
- `melos run analyze` (repo-wide, 14 packages) → RC=0 (aucune régression cross-package de mon changement).
- `flutter test packages/zcrud_geo` → **97 tests, RC=0** (52 E11a-1 non régressés + 45 nouveaux).
- `graph_proof.py` → **CORE OUT=0**, ACYCLIQUE OK, 19 arêtes, 14 nœuds (l'arête `google_maps_flutter` reste confinée à `zcrud_geo`, invisible au graphe zcrud_*).
- Gates : `gate:secrets` RC=0, `gate:reflectable` RC=0, `gate:codegen` RC=0, `gate:melos` RC=0, `gate:compat` RC=0 ; `melos list` = 14.
- `verify:serialization` (repo-wide) → RED **HORS-PÉRIMÈTRE** : crash de compilation `dart test` sur `packages/zcrud_flashcard/test/z_study_session_config_test.dart` (« type 'InvalidType' is not a subtype of type 'FunctionType' ») — appartient au workstream WS-B/E9-3 (en cours). `zcrud_geo` = SKIP (aucun test `serialization-compat`) et ne dépend pas de `zcrud_flashcard`. Aucun lien avec E11b-1.

### Completion Notes List

- **Testabilité Google (documentée, non-lacune)** : `google_maps_flutter` s'affiche via PlatformView native non peinte en headless. `z_google_map_adapter_test.dart` prouve : conformité `is ZMapAdapter`, `dispose` idempotent ×2, `buildMap(...)` construit le graphe (GoogleMap + markers/polygons/circles) **sans exception** — le `GoogleMap` construit n'est pas monté dans l'arbre (retour d'un `SizedBox`), évitant la dépendance à un rendu natif indisponible en CI.
- **AD-4 respecté sans toucher `zcrud_core`** : `ZGeoFieldConfig extends ZFieldConfig` déclarée dans `zcrud_geo`, posée sur `ZFieldSpec.config`, lue via `ctx.field.config`. La géométrie « cercle » passe par la config (pas de nouvelle valeur `EditionFieldType`, pas de slot `ZcrudScope`).
- **Rétro-compat E11a-1 stricte** : sans `ZGeoFieldConfig` ni override builder, `location`→point / `geoArea`→polygone inchangés (tests dédiés + 52 tests E11a-1 verts).
- **AD-12 / no-secret** : aucune clé Google dans le package (clé = config plateforme, E1-5) ; aucun `badCertificateCallback` ; défauts (centre/zoom/tuiles/style) neutres et surchargeables. Gate secrets vert.
- **AD-1 / confinement** : `google_maps_flutter` importé **uniquement** dans `z_google_map_adapter.dart` (gate d'isolation étendu le vérifie) ; barrel principal sans symbole SDK ; adaptateur Google atteint via `package:zcrud_geo/adapters/google.dart`.
- **Learnings E11a-1 répliqués** : fabrique d'adaptateur (MAJEUR-1) ; `dispose` idempotent du `GoogleMapController` via `Completer` (E5) ; contrôleur rayon `late final` créé/disposé 1× (AD-2, SM-1) ; libellé rayon routé via `label(context,'geo.radius')` (LOW-4) ; lecture défensive `_circleOf` (LOW-5).

### File List

**Créés**
- `packages/zcrud_geo/lib/src/domain/z_geo_circle.dart`
- `packages/zcrud_geo/lib/src/domain/z_geo_field_config.dart`
- `packages/zcrud_geo/lib/src/presentation/adapters/z_google_map_adapter.dart`
- `packages/zcrud_geo/lib/adapters/google.dart`
- `packages/zcrud_geo/test/z_geo_circle_test.dart`
- `packages/zcrud_geo/test/z_geo_field_config_test.dart`
- `packages/zcrud_geo/test/z_google_map_adapter_test.dart`

**Modifiés**
- `packages/zcrud_geo/lib/src/presentation/z_map_adapter.dart` (param `circle` additif)
- `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` (mode cercle + résolution `ZGeoFieldConfig` + override builder `geometry`)
- `packages/zcrud_geo/lib/src/presentation/adapters/z_osm_map_adapter.dart` (rendu `CircleLayer`)
- `packages/zcrud_geo/lib/zcrud_geo.dart` (exports `ZGeoCircle`/`ZGeoFieldConfig`/`ZGeoGeometry`)
- `packages/zcrud_geo/pubspec.yaml` (`google_maps_flutter: ^2.9.0`)
- `packages/zcrud_geo/test/support/fake_map_adapter.dart` (signature `circle`)
- `packages/zcrud_geo/test/z_geo_field_widget_test.dart` (groupes cercle + rétro-compat + mapHeight)
- `packages/zcrud_geo/test/z_osm_map_adapter_test.dart` (rendu cercle + tileUrl surchargeable)
- `packages/zcrud_geo/test/isolation_gates_test.dart` (confinement Google + pubspec + barrel)

**NON modifiés (confirmé)** : `zcrud_core` (aucun fichier), tout autre package hors `zcrud_geo`. (`pubspec.lock` racine régénéré par `dart pub get` — artefact de résolution, non source.)

### Change Log

- 2026-07-10 — Implémentation E11b-1 : `ZGeoCircle` (modèle neutre défensif AD-10), `ZGeoFieldConfig`/`ZGeoGeometry` (config additive AD-4), édition cercle dans `ZGeoFieldWidget` (résolution de géométrie par config, rétro-compat E11a-1 stricte), extension additive `ZMapAdapter.buildMap(circle:)`, rendu cercle OSM, 2ᵉ adaptateur `ZGoogleMapAdapter` (confiné, sans clé — AD-1/AD-12). 97 tests verts (RC=0), CORE OUT=0.
</content>
</invoke>
