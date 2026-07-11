---
baseline_commit: 1bcae2ad4ea1a66198f02020a6f29f77e1e2e2f6
---

# Story DP-7 : Barre d'outils éditeur geo — `ZGeoEditorToolbarConfig` (parité DODLP, gap B9)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur migrant un champ géo DODLP (`GeofenceField`) vers zcrud**,
je veux **une config de barre d'outils d'éditeur géo (`ZGeoEditorToolbarConfig`) additive à `ZGeoFieldConfig`, avec les toggles et presets équivalents à DODLP, rendue par `ZGeoFieldWidget`**,
afin que **les champs géo authored sous DODLP (`GeoEditorToolbarConfig` : 18 toggles, 5 presets) migrent 1:1 leur surface de configuration, et que l'utilisateur retrouve les boutons undo / clear / ma-position / type-de-carte, SANS toucher `zcrud_core` (AD-1), sans embarquer aucune clé/SDK de géoloc, et sans régresser AD-2 (rebuild ciblé) / AD-10 (défensif) / AD-13 (a11y/RTL/thème) ni la rétro-compat E11a-1/E11b-1.**

## Contexte & cadrage

**Épopée E-DP — Parité migration DODLP (post-v1.x).** Objectif : rendre la migration DODLP→zcrud **structurellement fidèle**. Source de vérité détaillée : `docs/dodlp-edition-parity-gap.md` (matrice ≈117 features : 14 bloquants, ~24 majeurs). DP-7 traite le gap **B9** (bloquant #9).

- **epics.md §E-DP (l. 169)** : « **DP-7. Barre d'outils éditeur geo.** `ZGeoEditorToolbarConfig` (toggles/presets). [B9, zcrud_geo] ».
- **Gap (dodlp-edition-parity-gap.md §2.5, l. 127)** : « Geo — barre d'outils éditeur | `GeoEditorToolbarConfig` 18 toggles/5 presets (`geo_editor_config.dart:7-273`) | **missing** — `z_map_adapter.dart` center/shape only | Saisie manuelle lat/lng, pas d'éditeur GIS | **blocking** ».
- **Action B9 (l. 189)** : « Ajouter `ZGeoEditorToolbarConfig` (`zcrud_geo/domain/`) + rendu boutons **undo/clear/my-location/type-carte** dans `z_geo_field_widget.dart` (adapters Google/OSM). »

Le résumé exécutif (l. 30) confirme : « **Champ geo — barre d'outils éditeur** — `GeoEditorToolbarConfig` (18 toggles, 5 presets) absent ; zcrud = saisie manuelle de coordonnées lat/lng, pas d'éditeur GIS. »

### Référence DODLP (LECTURE SEULE — `lib/modules/data_crud/models/geo_editor_config.dart`)

`GeoEditorToolbarConfig` (const, `copyWith`) porte **18 toggles booléens** + `disabled` (bool) + `mapOptionsLabel` (String), regroupés :

| Groupe | Toggles (nom DODLP) | Défaut |
|---|---|---|
| Drawing Tools | `showModeSelector`, `showMyLocationButton`, `showUndoButton`, `showClearButton`, `showOptimizeButton` | true × 5 |
| Map Type | `showMapTypeToggle`, `showExtendedMapTypes` | true, false |
| Map Features | `showTrafficToggle`, `showBuildingsToggle`, `showIndoorViewToggle` | false × 3 |
| Gesture Controls | `showRotationToggle`, `showTiltToggle` | false × 2 |
| Advanced | `showZoomControlsToggle`, `showCompassToggle`, `showMapToolbarToggle` | false × 3 |
| Layout | `useMapOptionsDropdown`, `showButtonLabels`, `compactMode` | false, true, false |

**5 presets** (statiques `const`) — flags exacts à répliquer :
- **`none`** : `disabled:true`, tout à false, `compactMode:true`. (masque tout)
- **`minimal`** : `showMyLocationButton/Undo/Clear:true`, `showMapTypeToggle:true` ; `showModeSelector:false`, `showOptimize:false`, `showButtonLabels:false`, `compactMode:true`. (picking simple)
- **`standard`** : Drawing Tools tous true (dont `showModeSelector`, `showOptimize`), `showMapTypeToggle:true`, features/gestures/advanced false, `showButtonLabels:true`, `compactMode:false`. (défaut équilibré)
- **`full`** : **tous** les 18 toggles à true, `useMapOptionsDropdown:true`, `showButtonLabels:true`, `compactMode:false`. (GIS avancé)
- **`professional`** : comme `full` mais `showIndoorViewToggle:false`, `showZoomControlsToggle:false`, `showCompassToggle:false`, `showMapToolbarToggle:false`. (levé/cartographie)

DODLP porte aussi `GeoEditorMapState` (état runtime des options carte : `mapType` [enum `GeoMapType` Normal/Hybrid/Satellite/Terrain], `trafficEnabled`, `buildingsEnabled`, `indoorViewEnabled`, `rotateGesturesEnabled`, `tiltGesturesEnabled`, `zoomControlsEnabled`, `compassEnabled`, `mapToolbarEnabled`, `myLocationEnabled`) et `GeoEditorToolbarItem` (id/label/`IconData`/tooltip pour chaque bouton). `GeoFieldConfig` DODLP expose `toolbarConfig` (`GeoEditorToolbarConfig?`) — **exactement le point de branchement** que DP-7 réplique côté `ZGeoFieldConfig`.

### État réel zcrud (vérifié sur disque, commit `1bcae2a`)

**DÉJÀ livré (E11a-1 + E11b-1)** — NE PAS ré-implémenter, réutiliser :
- Modèles neutres `ZGeoPoint`, `ZGeoShape` (polygone, `addVertex`, `vertices` non-modifiable), `ZGeoCircle` (centre + rayon, `isValid`) — `packages/zcrud_geo/lib/src/domain/`.
- **`ZGeoFieldConfig extends ZFieldConfig`** (const, `==`/`hashCode`) : `geometry`, `defaultCenter`, `defaultZoom`, `mapHeight`, `tileUrlTemplate`, `mapStyleJson`, `interactive`. Défauts neutres/surchargeables (AD-12). — `lib/src/domain/z_geo_field_config.dart`.
- **`ZGeoFieldWidget`** (patron AD-2 : contrôleurs/focus `late final` créés 1× en `initState`, sync guardée hors focus via `_hasFieldFocus`, écriture via `ctx.onChanged` seulement, `_workingShape` atomique, `_geometry` résolu 1× immuable, dispose adaptateur possédé). Rend déjà : lignes coordonnées, champ rayon (cercle), bouton « ajouter sommet » + liste sommets (polygone, ≥48dp + `Semantics`), surface carte via `ZMapAdapter`. — `lib/src/presentation/z_geo_field_widget.dart`.
- **Port `ZMapAdapter`** neutre : `buildMap(context, {center, shape, circle, onTap, interactive, tileUrlTemplate, mapStyleJson, defaultZoom})` + `dispose` ; fabrique `ZMapAdapterFactory`. — `lib/src/presentation/z_map_adapter.dart`.
- Adaptateurs OSM (`flutter_map`) et Google (`google_maps_flutter`), confinés, sans clé — `lib/src/presentation/adapters/` + entrées `lib/adapters/{osm,google}.dart`.
- Gates : isolation SDK carte (jamais dans `zcrud_core`), scan secrets, RTL/a11y/thème — `test/isolation_gates_test.dart`, `test/z_geo_field_widget_test.dart`.

**MANQUE (périmètre de CETTE story)** : **aucune** barre d'outils d'édition. Les formes (point/polygone/cercle) existent ; le gap B9 est la **barre d'outils** (config + rendu boutons + options carte pilotables). Le champ actuel n'a ni undo, ni clear, ni ma-position, ni sélecteur de type de carte.

### Périmètre RETENU (IN) vs HORS-story

**IN (cette story, `zcrud_geo` uniquement + tests) :**
1. **`ZGeoEditorToolbarConfig`** — sous-classe const pur-Dart (domaine, AD-14) : les **18 toggles + `disabled` + `mapOptionsLabel`** (parité 1:1 DODLP), `==`/`hashCode`/`copyWith`, + **5 presets** (`none`/`minimal`/`standard`/`full`/`professional`) aux flags exacts.
2. **Champ additif `toolbarConfig` (`ZGeoEditorToolbarConfig?`, défaut `null`)** sur `ZGeoFieldConfig` (+ `copyWith`, `==`, `hashCode` mis à jour). `null` → **aucune barre d'outils** → rétro-compat E11a-1/E11b-1 **stricte**.
3. **Rendu de la barre d'outils** dans `ZGeoFieldWidget`, au-dessus de la surface carte, uniquement si `toolbarConfig != null && !disabled`. Boutons **câblés** (B9 explicite) : **undo**, **clear**, **ma-position**, **type-de-carte** (Normal/Hybride, + étendu Satellite/Terrain). Chaque bouton apparaît selon son toggle. a11y ≥48dp, directionnel, thème injecté, **zéro couleur en dur**.
4. **Options carte neutres** : enum `ZGeoMapType {normal, hybrid, satellite, terrain}` + `ZGeoMapOptions` (état neutre : mapType + flags features/gestures/advanced). Les toggles map-type/features/gestures/advanced pilotent un `ZGeoMapOptions` local ; passé à l'adaptateur via **param additif rétro-compatible** `ZMapAdapter.buildMap(..., ZGeoMapOptions? mapOptions)` (défaut `null` → comportement inchangé). Chaque adaptateur **honore ce qu'il supporte, ignore le reste** (même contrat que `tileUrlTemplate`/`mapStyleJson`).
5. **Seam « ma position » neutre** : typedef `ZGeoLocationResolver = Future<ZGeoPoint?> Function()` (dans `zcrud_geo`, **aucun SDK de géoloc**, aucune permission), injecté via `ZGeoFieldWidget.builder(locationResolver: ...)`. Bouton masqué/désactivé si absent. **Aucune** dépendance `geolocator`/`location` ajoutée, **aucun** secret.
6. Exports barrel des nouveaux types publics ; gates isolation/secrets étendus (verts) ; vérif verte.

**HORS-story (justifié) :**
- **Runtime `showModeSelector` (bascule de géométrie à chaud)** : la géométrie zcrud est résolue **1× par montage et immuable** (`_geometry` `late final`, cf. `z_geo_field_widget.dart:139,167,203`) — invariant AD-2 délibéré (frontière de rebuild jamais élargie). Le **flag est conservé** dans `ZGeoEditorToolbarConfig` (migration 1:1 de la config authored), mais la bascule de géométrie à l'exécution est **déférée** (change le type de la valeur de tranche + re-seed des contrôleurs → refonte AD-2 non triviale, hors B9). Documenter le déféré par écrit (Dev Notes + code-review). Suivi : follow-up DP-7b si un usage prod l'exige.
- **`showOptimizeButton`** : flag conservé pour la parité de config ; le bouton peut être rendu (polygone) mais la simplification est **optionnelle/LOW** (op pure sur `ZGeoShape` si triviale, sinon différée — pas dans B9). Ne pas bloquer le vert dessus.
- **Rendu réel** trafic/bâtiments/indoor/rotation/tilt/zoom/compass/mapToolbar : la **config + le pilotage neutre `ZGeoMapOptions`** sont livrés ; leur effet visuel dépend de ce que chaque SDK supporte (Google honore la plupart, OSM ignore). C'est le contrat « honoré si supporté » — ne pas exiger un test pixel du SDK.
- `zcrud_core` : **NE PAS toucher** (voir *Impact zcrud_core* : aucun besoin détecté).

## Acceptance Criteria

1. **`ZGeoEditorToolbarConfig` — surface de config parité DODLP.** Une classe `const` pur-Dart (couche `domain`, AD-14, aucun widget/`IconData`/dépendance lourde) expose les **18 toggles booléens** DODLP (noms zcrud équivalents : `showModeSelector`, `showMyLocationButton`, `showUndoButton`, `showClearButton`, `showOptimizeButton`, `showMapTypeToggle`, `showExtendedMapTypes`, `showTrafficToggle`, `showBuildingsToggle`, `showIndoorViewToggle`, `showRotationToggle`, `showTiltToggle`, `showZoomControlsToggle`, `showCompassToggle`, `showMapToolbarToggle`, `useMapOptionsDropdown`, `showButtonLabels`, `compactMode`) + `disabled` (bool) + `mapOptionsLabel` (String), avec les **mêmes valeurs par défaut** que DODLP. `==`, `hashCode`, `copyWith` couvrent tous les champs.
2. **5 presets exacts.** `ZGeoEditorToolbarConfig.none / minimal / standard / full / professional` sont des `const` statiques dont les flags **correspondent exactement** à `GeoEditorToolbarConfig.{none,minimal,standard,full,professional}` (cf. table du cadrage). Un test vérifie flag-par-flag au moins `none` (tout masqué/`disabled`), `full` (18 à true) et `professional` (full sauf indoor/zoom/compass/mapToolbar).
3. **Additif à `ZGeoFieldConfig`, rétro-compat stricte.** `ZGeoFieldConfig` gagne un champ `final ZGeoEditorToolbarConfig? toolbarConfig` (défaut `null`), propagé dans `copyWith`, `==`, `hashCode`. Un `ZGeoFieldConfig` construit **sans** `toolbarConfig` est `==` à un `ZGeoFieldConfig` E11b-1 équivalent, et un champ `location`/`geoArea`/cercle **sans** `toolbarConfig` rend **exactement** l'UI E11a-1/E11b-1 (aucune barre d'outils ajoutée). Test de non-régression : arbre de widgets identique (absence de la clé `z-geo-toolbar`) quand `toolbarConfig == null`.
4. **Rendu de la barre d'outils (boutons B9).** Quand `toolbarConfig != null && toolbarConfig.disabled == false`, `ZGeoFieldWidget` rend une barre d'outils (clé `z-geo-toolbar`) au-dessus de la surface carte. Les boutons **undo** (`showUndoButton`), **clear** (`showClearButton`), **ma-position** (`showMyLocationButton` **et** seam présent), **type-de-carte** (`showMapTypeToggle`) apparaissent/disparaissent selon leurs toggles ; quand `showExtendedMapTypes`, le sélecteur de type propose Satellite/Terrain en plus de Normal/Hybride. Un test pilote chaque toggle et asserte la présence/absence du bouton correspondant.
5. **Actions câblées (voie unique `ctx.onChanged`, AD-2).**
   - **clear** : remet la valeur de tranche à `null` via `ctx.onChanged(null)`, vide les contrôleurs texte, réinitialise `_workingShape` (polygone) — sans recréer contrôleurs/focus ni élargir la frontière de rebuild.
   - **undo** : polygone → retire le dernier sommet (réutilise `_removeVertex`/`_workingShape` atomique) ; point/cercle → efface la dernière saisie de coordonnée (équivaut à clear si un seul état). Aucune exception si rien à annuler.
   - **ma-position** : appelle le `ZGeoLocationResolver` injecté ; sur un `ZGeoPoint` non-null valide, applique la même voie que le tap carte (`_setPointFromTap`/`_setCircleCenterFromTap`/`_appendVertex` selon géométrie) ; `null`/erreur → no-op silencieux (AD-10, jamais de crash).
   - **type-de-carte** : met à jour `ZGeoMapOptions.mapType` (state local via `setState`, action **discrète** — pas la voie de frappe, AD-2 respecté) et le passe à l'adaptateur.
   Un test widget vérifie chaque action (émission de tranche / no-op).
6. **Options carte neutres plombées à l'adaptateur (additif).** `ZGeoMapType` (enum camelCase `normal/hybrid/satellite/terrain`) et `ZGeoMapOptions` (neutre, `const`, `copyWith`/`==`) sont définis dans `zcrud_geo`. `ZMapAdapter.buildMap` gagne un paramètre **nommé optionnel** `ZGeoMapOptions? mapOptions` (défaut `null`) : les appelants existants compilent inchangés ; OSM/Google honorent ce qu'ils supportent, ignorent le reste. Test : un fake adapter reçoit bien le `mapOptions` reflétant les toggles ; `null` quand pas de `toolbarConfig`.
7. **Seam « ma position » sans SDK ni secret.** `ZGeoLocationResolver` est un typedef pur (`Future<ZGeoPoint?> Function()`) dans `zcrud_geo`, injecté via `ZGeoFieldWidget.builder(locationResolver:)` (capturé par closure, **aucun** nouveau slot `zcrud_core`/`ZcrudScope`). Aucune dépendance de géolocalisation ajoutée au `pubspec.yaml`. Le bouton ma-position est **masqué** (ou désactivé) si le seam est absent, même quand `showMyLocationButton == true`. Gate secrets : aucun `apiKey`/`token`/endpoint/`badCertificateCallback` introduit.
8. **AD-2 préservé (SM-1).** Taper N caractères dans un champ coordonnée ne reconstruit que la tranche du champ ; les contrôleurs/`FocusNode`/`State` ne sont **jamais** recréés par l'ajout de la barre d'outils (compteur `onInit == 1` après frappe + toggles). La barre d'outils n'introduit **aucun** `setState` sur la voie de frappe (seulement sur les actions discrètes type-de-carte/mode). `readOnly` désactive toutes les actions de la barre (boutons `onPressed: null`).
9. **AD-13 (a11y / RTL / thème) & zéro couleur en dur.** Chaque bouton de la barre a une cible tactile **≥ 48×48 dp** (`ConstrainedBox`/`IconButton` conforme) et un `Semantics`/`tooltip`/`labelText` explicite ; libellés routés via `label(context, 'geo.<key>', fallback: '…')` (pattern existant `geo.radius`/`geo.addVertex`, fallback inline → **aucun** changement l10n `zcrud_core` requis) ; layout **directionnel** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`, `Wrap`/`Row` sans `left/right`) ; couleurs issues du thème injecté (`ZcrudTheme.of(context)` / `Theme.of(context).colorScheme` / `IconButton` par défaut) — **aucun** `Color(0x…)`/`Colors.*` codé en dur. Test RTL + test thème custom.
10. **Gates & barrel.** Les nouveaux types publics (`ZGeoEditorToolbarConfig`, `ZGeoMapType`, `ZGeoMapOptions`, `ZGeoLocationResolver`) sont exportés par `lib/zcrud_geo.dart`. Les gates d'isolation (`test/isolation_gates_test.dart`) restent verts : aucun symbole SDK carte n'est exporté par le barrel principal, `zcrud_core` ne tire aucune lib carte, aucun secret dans `lib/`.
11. **Vérif verte.** `melos run generate` (ou build_runner ciblé) OK → `dart/flutter analyze` RC=0 → `flutter test` RC=0 sur `packages/zcrud_geo` (et repo-wide au gate de commit d'epic). Nouveaux tests couvrant AC1–AC10 verts.

## Tasks / Subtasks

- [x] **T1 — `ZGeoEditorToolbarConfig` (domaine)** (AC: 1, 2)
  - [x] Créer `lib/src/domain/z_geo_editor_toolbar_config.dart` : classe `const`, 18 toggles + `disabled` + `mapOptionsLabel`, défauts = DODLP, docstring « origine » (parité B9, pur-Dart AD-14).
  - [x] `==`/`hashCode`/`copyWith` sur tous les champs (pattern `ZGeoFieldConfig`).
  - [x] 5 presets `const` statiques (`none/minimal/standard/full/professional`) aux flags exacts (vérifiés contre la source DODLP `geo_editor_config.dart:113-225`).
- [x] **T2 — Options carte neutres** (AC: 6)
  - [x] `ZGeoMapType` (enum camelCase `normal/hybrid/satellite/terrain`, canonique §5) + `ZGeoMapOptions` (`const`, `copyWith`, `==`, `hashCode`) — `lib/src/domain/`.
  - [x] Étendre `ZMapAdapter.buildMap` avec `ZGeoMapOptions? mapOptions` (nommé, défaut `null`, docstring compat additive) ; répercuté dans Google (traduit `MapType`/trafic/features/gestes) + OSM (accepté, ignoré — raster non concerné) sans casser les signatures.
- [x] **T3 — `toolbarConfig` additif sur `ZGeoFieldConfig`** (AC: 3)
  - [x] Ajouté `final ZGeoEditorToolbarConfig? toolbarConfig` (défaut `null`) + `copyWith` (nouveau) / `==` / `hashCode`.
- [x] **T4 — Seam localisation** (AC: 7)
  - [x] `typedef ZGeoLocationResolver = Future<ZGeoPoint?> Function();` dans `z_map_adapter.dart` ; `locationResolver` ajouté à `ZGeoFieldWidget` + `builder(...)` (capturé par closure). Aucune dep géoloc.
- [x] **T5 — Rendu barre d'outils** (AC: 4, 5, 8, 9)
  - [x] `_toolbar(context, theme)` (clé `z-geo-toolbar`) rendu uniquement si `_toolbarConfig != null && !disabled`, au-dessus de `_mapSurface`.
  - [x] Boutons undo/clear/ma-position/type-de-carte + toggles features gated par toggles ; `Wrap` directionnel (`AlignmentDirectional`) ; chaque bouton ≥48dp (`ConstrainedBox`) + `Semantics`/`tooltip` + libellé l10n `geo.*` (fallback inline).
  - [x] Actions : `_clearAll`, `_undo`, `_useMyLocation` (async, garde `mounted`, avale erreur/null AD-10), `_cycleMapType`, `_updateMapOptions` — voie `ctx.onChanged` / `setState(ZGeoMapOptions)`. `readOnly` → `onPressed: null`.
  - [x] `_geometry` reste `late final` (pas de bascule de mode — déféré, cf. HORS-story) ; `_mapOptions` local mutable (action discrète seulement, `null` si aucune barre).
  - [x] `mapOptions: _mapOptions` passé à `adapter.buildMap`.
- [x] **T6 — Barrel + gates** (AC: 10)
  - [x] Exporté `ZGeoEditorToolbarConfig`, `ZGeoMapType`, `ZGeoMapOptions` dans `lib/zcrud_geo.dart` (`ZGeoLocationResolver` déjà via l'export de `z_map_adapter.dart`).
  - [x] `isolation_gates_test.dart` vert : gates génériques couvrent déjà les nouveaux fichiers sous `lib/` (barrel sans SDK ; secrets clean ; RTL).
- [x] **T7 — Tests** (AC: 1–11)
  - [x] `test/z_geo_editor_toolbar_config_test.dart` : défauts, presets flag-par-flag (none/minimal/standard/full/professional), `copyWith`, `==`/`hashCode`.
  - [x] `test/z_geo_map_options_test.dart` : enum neutre, état `const`, `copyWith`, égalité.
  - [x] `test/z_geo_editor_toolbar_widget_test.dart` (nouveau) : rendu conditionnel par toggle ; actions undo/clear/ma-position/type-carte ; propagation `mapOptions` (null sans barre) ; rétro-compat ; SM-1 (onInit==1) ; `readOnly` désactive ; RTL ; thème dark ; l10n surchargeable ; ≥48dp. `test/z_geo_field_config_test.dart` étendu (rétro-compat `==`/`copyWith`).
- [x] **T8 — Vérif verte** (AC: 11) : `analyze` RC=0 + `flutter test` (zcrud_geo) RC=0 (136 tests) + `graph_proof` CORE OUT=0.

## Dev Notes

### Fichiers à toucher (tous sous `packages/zcrud_geo/`, + tests)

- **NEW** `lib/src/domain/z_geo_editor_toolbar_config.dart` — config + presets.
- **NEW** `lib/src/domain/z_geo_map_options.dart` — `ZGeoMapType` + `ZGeoMapOptions`.
- **UPDATE** `lib/src/domain/z_geo_field_config.dart` — champ `toolbarConfig` (copyWith/==/hashCode).
- **UPDATE** `lib/src/presentation/z_map_adapter.dart` — param `mapOptions` (additif) + typedef `ZGeoLocationResolver` (ou fichier dédié).
- **UPDATE** `lib/src/presentation/z_geo_field_widget.dart` — barre d'outils + actions + `locationResolver` + `_mapOptions`.
- **UPDATE** `lib/src/presentation/adapters/z_osm_map_adapter.dart` & `z_google_map_adapter.dart` — consommer `mapOptions` (honoré/ignoré).
- **UPDATE** `lib/zcrud_geo.dart` — exports.
- **UPDATE** `test/z_geo_field_widget_test.dart`, `test/isolation_gates_test.dart` ; **NEW** tests config/options.

### Contraintes AD (rappels chirurgicaux)

- **AD-2** : le champ `ZGeoFieldWidget` a déjà le patron (contrôleurs `late final`, sync guardée `_hasFieldFocus`, `_workingShape` atomique, `_geometry` immuable). La barre d'outils N'EST PAS sur la voie de frappe : ses actions sont **discrètes** ; `setState` autorisé pour `_mapOptions.mapType`, JAMAIS pour un champ texte. Ne pas recréer les contrôleurs, ne pas rendre `_geometry` mutable (mode-switch déféré). Réutiliser `_setPointFromTap`/`_setCircleCenterFromTap`/`_appendVertex`/`_removeVertex` existants pour undo/clear/ma-position.
- **AD-10** : `_useMyLocation` doit garder `mounted`, avaler erreur/`null` du resolver sans crash ; toute coordonnée passe par `ZGeoPoint.isValid` (déjà appliqué par les helpers de tap).
- **AD-13** : cibles ≥48dp (voir `_addVertexButton`/`_vertexList` existants : `ConstrainedBox(BoxConstraints(minHeight:48,minWidth:48))` + `Semantics(container/button/label)` + `ExcludeSemantics` autour de l'`IconButton`) — **répliquer ce pattern**. `TextAlign.start`, `AlignmentDirectional`, `EdgeInsetsDirectional` uniquement. Couleurs : `ZcrudTheme.of(context)` (`labelColor`, `gapS/M/L`, `fieldPadding`) + `IconButton` (couleur icône par défaut du thème) / `Theme.of(context).colorScheme` en repli — **jamais** de littéral couleur.
- **AD-12** : `mapOptionsLabel` et libellés via l10n injectée + fallback inline. Aucun défaut national/endpoint/clé.
- **AD-1** : `ZGeoMapType`/`ZGeoMapOptions` neutres (aucun `MapType` de SDK). Le barrel n'exporte aucun symbole SDK. Les adaptateurs traduisent `ZGeoMapType`→type SDK **dans** leur fichier confiné.
- **AD-4** : tout passe par la config additive `ZGeoFieldConfig` + closures de `builder(...)` — aucun nouveau slot `zcrud_core`/`ZcrudScope`.

### l10n (clés nouvelles, fallback inline — pattern existant)

Réutiliser `label(context, key, fallback:)` (`z_geo_field_widget.dart:477,502`). Clés suggérées : `geo.undo` (« Annuler »), `geo.clear` (« Effacer »), `geo.myLocation` (« Ma position »), `geo.mapType` (« Type de carte »), `geo.mapType.normal/hybrid/satellite/terrain`. **Aucun** changement `zcrud_core` : les fallbacks inline suffisent (les délégués d'app peuvent les surcharger).

### Impact `zcrud_core` — AUCUN besoin détecté

- La config additive vit dans `zcrud_geo` (`ZGeoFieldConfig extends ZFieldConfig`, point d'extension AD-4 déjà utilisé en E11b-1).
- Le seam `ZGeoLocationResolver` et les options carte vivent dans `zcrud_geo` (capturés par la closure de `builder`), pas dans `ZcrudScope`.
- Les nouvelles clés l10n utilisent le fallback inline (déjà supporté par `label()` de `zcrud_core`).
- Le param `mapOptions` étend le port **local** `ZMapAdapter` (dans `zcrud_geo`), pas le cœur.
- **Conclusion : `zcrud_core` NE DOIT PAS être modifié.** Si le dev découvre un besoin (ex. un slot de resolver global), il doit **s'arrêter et le signaler** plutôt que toucher le cœur.

### Rétro-compat E11a-1 / E11b-1 (non négociable)

`toolbarConfig` défaut `null` et `mapOptions` défaut `null` ⇒ tout champ existant rend **exactement** l'UI actuelle et appelle `buildMap` avec les mêmes arguments effectifs. Ajouter un test « golden structurel léger » : sans `toolbarConfig`, `find.byKey(const Key('z-geo-toolbar'))` → `findsNothing`, et les tests E11a-1/E11b-1 existants restent verts sans modification.

### Testing standards

`flutter_test` + `WidgetTester` ; harness existant `_appWithRegistry`/`_registry`/`FakeMapAdapter` (`test/support/fake_map_adapter.dart` — l'étendre pour capter `mapOptions`). Hooks `onInit`/`onBuild` déjà exposés pour SM-1. Gates rejoués comme tests (isolation/secrets).

### Project Structure Notes

Conforme à la structure `zcrud_geo` (`lib/src/{domain,presentation}` + barrel `lib/zcrud_geo.dart`). Nouveaux fichiers domaine pur-Dart (AD-14) ; presentation dépend de Flutter. Aucune variance détectée.

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.5 (l.127), #B9 (l.189), #résumé (l.30)]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E-DP DP-7 (l.169)]
- [Source (LECTURE SEULE DODLP): lib/modules/data_crud/models/geo_editor_config.dart:7-465 (config 7-273, mapState 275-331, items 333-465)]
- [Source (LECTURE SEULE DODLP): lib/modules/data_crud/models/geo_field_config.dart:8-53 (branchement `toolbarConfig`)]
- [Source: packages/zcrud_geo/lib/src/domain/z_geo_field_config.dart (config additive existante)]
- [Source: packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart (patron AD-2, ≥48dp, l10n)]
- [Source: packages/zcrud_geo/lib/src/presentation/z_map_adapter.dart (port neutre, params additifs)]
- [Source: packages/zcrud_geo/test/{z_geo_field_widget_test.dart,isolation_gates_test.dart} (harness + gates)]
- [Source: CLAUDE.md (AD-1/2/4/10/12/13, Key Don'ts, vérif verte)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, effort high).

### Debug Log References

- `dart analyze packages/zcrud_geo` → RC=0 (No issues found, lib + tests).
- `flutter test packages/zcrud_geo` → RC=0, **136 tests** verts (dont 5 fichiers nouveaux/étendus DP-7).
- `python3 scripts/dev/graph_proof.py` → RC=0, ACYCLIQUE OK, **CORE OUT=0**, `zcrud_geo -> zcrud_core` uniquement (aucune arête SDK vers le cœur).

### Completion Notes List

- **Parité presets DODLP 1:1** : flags répliqués depuis la source `lib/modules/data_crud/models/geo_editor_config.dart` (lecture seule). ⚠️ Le parenthétique de l'AC2 « full (18 à true) » est **imprécis** : DODLP `full` garde `compactMode:false` (17 toggles true + `compactMode:false`). La règle liante étant « correspondent **exactement** à DODLP », le preset `full` réplique fidèlement DODLP (`compactMode:false`), et le test l'assert flag-par-flag. Documenté ici.
- **AD-2/SM-1 préservé** : la barre n'est JAMAIS sur la voie de frappe ; ses actions discrètes (type de carte, toggles) passent par `setState(_mapOptions)` ; les `TextEditingController`/`FocusNode`/`State` ne sont pas recréés (test `onInit==1` après frappe + toggle). `readOnly` → tous les boutons `onPressed: null`.
- **Rétro-compat stricte** : `toolbarConfig`/`mapOptions` défaut `null` → aucune barre rendue, `buildMap` reçoit `mapOptions: null` → comportement E11a-1/E11b-1 inchangé (tests dédiés + suite existante intacte).
- **Zéro secret / zéro SDK géoloc** : seam `ZGeoLocationResolver` = typedef pur injecté par closure ; aucune dépendance `geolocator`/`location` ; gate secrets vert. SDK carte confiné aux adaptateurs (Google traduit `ZGeoMapType`→`MapType` et honore trafic/features/gestes ; OSM ignore, contrat « honoré-si-supporté »).
- **HORS-story respecté** : `showModeSelector` (bascule géométrie à chaud) et `showOptimizeButton` conservés en config pour la parité mais non câblés en runtime (déférés, `_geometry` reste `late final`). Aucun besoin `zcrud_core` détecté ; le cœur n'a PAS été touché.

### File List

**Nouveaux (packages/zcrud_geo) :**
- `lib/src/domain/z_geo_editor_toolbar_config.dart`
- `lib/src/domain/z_geo_map_options.dart`
- `test/z_geo_editor_toolbar_config_test.dart`
- `test/z_geo_map_options_test.dart`
- `test/z_geo_editor_toolbar_widget_test.dart`

**Modifiés (packages/zcrud_geo) :**
- `lib/src/domain/z_geo_field_config.dart` (champ `toolbarConfig` + `copyWith`/`==`/`hashCode`)
- `lib/src/presentation/z_map_adapter.dart` (param `mapOptions` + typedef `ZGeoLocationResolver`)
- `lib/src/presentation/z_geo_field_widget.dart` (barre d'outils + actions + `locationResolver` + `_mapOptions`)
- `lib/src/presentation/adapters/z_google_map_adapter.dart` (consomme `mapOptions`)
- `lib/src/presentation/adapters/z_osm_map_adapter.dart` (accepte `mapOptions`, ignoré)
- `lib/zcrud_geo.dart` (exports)
- `test/support/fake_map_adapter.dart` (capture `lastMapOptions`)
- `test/z_geo_field_config_test.dart` (rétro-compat `toolbarConfig`)

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-07-11 | 0.1 | DP-7 implémentée (gap B9) : `ZGeoEditorToolbarConfig` (18 toggles + 5 presets, parité DODLP), `ZGeoMapType`/`ZGeoMapOptions` neutres, `toolbarConfig` additif sur `ZGeoFieldConfig`, barre d'outils (undo/clear/ma-position/type-carte + toggles features) dans `ZGeoFieldWidget`, seam `ZGeoLocationResolver`, param additif `mapOptions` sur `ZMapAdapter`. Vert : analyze RC=0, 136 tests, graph CORE OUT=0. `zcrud_core` non touché. |
