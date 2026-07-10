# Code Review — E11b-1 : `zcrud_geo` complet (cercle + `ZGeoFieldConfig` + 2ᵉ adaptateur Google/OSM)

- **Mode d'exécution** : skill réel `bmad-code-review` invoqué via le tool `Skill` (pas de fallback disque). Revue adversariale menée par l'orchestrateur (Blind Hunter + Edge Case Hunter + Acceptance Auditor consolidés) faute de sous-agents disponibles dans ce contexte.
- **Périmètre** : fichiers E11b-1 sous `packages/zcrud_geo/` uniquement (baseline `04aaaf0`). Aucun autre package revu (workstreams E9 ignorés).
- **Date** : 2026-07-10.

## Vérifications rejouées réellement sur disque (package geo uniquement)

| Gate | Commande | Résultat réel |
|------|----------|---------------|
| Analyze | `dart analyze packages/zcrud_geo` | **RC=0** — No issues found |
| Tests | `flutter test` (packages/zcrud_geo) | **97/97 PASS, RC=0** (52 E11a-1 non régressés + 45 nouveaux) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK, CORE OUT=0**, 19 arêtes, 14 nœuds ; `google_maps_flutter` invisible au graphe zcrud_* (confiné) |
| Secrets | grep `AIza…` / `badCertificateCallback` / `API_KEY` sur `lib/` | **Zéro secret** — seules occurrences = prose de doc-comments décrivant ce qu'il ne faut PAS faire |

`melos run verify` repo-wide NON rejoué (dev actif ailleurs — consigne).

## Confirmations d'axes durs

- ✅ **Zéro secret** : aucune clé Google, aucun token, aucun `badCertificateCallback => true` dans les DEUX adaptateurs. La clé Google reste en config plateforme (documentée dans `adapters/google.dart`). Gate secrets vert.
- ✅ **SDK confiné** : `import 'package:google_maps_flutter/…'` présent dans **un seul** fichier (`z_google_map_adapter.dart`), vérifié par le gate d'isolation (`hasLength(1)`). Barrel principal `lib/zcrud_geo.dart` sans aucun symbole SDK ni `adapters/`. Adaptateur atteint via l'entrée dédiée `adapters/google.dart`. Idem OSM (E11a-1) inchangé.
- ✅ **Modèles neutres (AD-1/AD-5/AD-12)** : `ZGeoCircle`, `ZGeoFieldConfig`, port `ZMapAdapter` — aucune signature publique n'expose `LatLng`/`Circle`/`GoogleMap…`. La valeur de tranche cercle = `ZGeoCircle` pur-Dart.
- ✅ **ZGeoCircle défensif (AD-10)** : `fromMapSafe` retourne `null` (jamais throw) pour raw non-Map, centre absent/hors-bornes, rayon absent/non-num/NaN/±Inf/0/négatif ; `isValid` corollaire. Table de tests exhaustive.
- ✅ **ZGeoFieldConfig additif (AD-4)** : `extends ZFieldConfig` `const`, déclaré dans `zcrud_geo`, posé sur `ZFieldSpec.config`, lu via `ctx.field.config`. Aucune modification de `zcrud_core`, aucune nouvelle `EditionFieldType`, aucun `sealed`.
- ✅ **Rétro-compat E11a-1 STRICTE** : sans config ni override builder, `location`→point / `geoArea`→polygone inchangés (`_resolveGeometry`), 52 tests E11a-1 verts, tests dédiés de non-régression présents.
- ✅ **Port `ZMapAdapter` étendu ADDITIVEMENT** : `circle` optionnel défaut `null` ; appelants sans `circle` compilent inchangés ; OSM + fake adoptent la signature.
- ✅ **Cycle de vie** : contrôleurs centre/lng/**rayon** + 3 FocusNodes `late final` créés 1× / disposés ; `MapController` (OSM) et `GoogleMapController` via `Completer` (Google) disposés, `dispose` idempotent (test ×2 `returnsNormally`). Anti-course sur `onMapCreated` (`_disposed` → `controller.dispose()`).
- ✅ **AD-13** : `AlignmentDirectional`/`EdgeInsetsDirectional`/`TextAlign.start`, cibles ≥48 dp (ConstrainedBox 48×48), `Semantics`, thème injecté (`ZcrudTheme.of`, couleur cercle OSM depuis `colorScheme.primary`), rendu `Directionality.rtl` testé. Gate RTL statique vert.

---

## Findings

### HIGH / MAJEUR
**Aucun.** Pas de fuite SDK, pas de secret, pas de rupture rétro-compat, pas de fuite de cycle de vie, pas de throw non défensif.

### MEDIUM

**MEDIUM-1 — `ZGeoFieldConfig.tileUrlTemplate`, `.mapStyleJson`, `.defaultZoom` sont des champs MORTS : jamais lus par le widget ni transmis aux adaptateurs.**
`z_geo_field_config.dart:77,84,87` (déclarations) vs `z_geo_field_widget.dart:204,369,565-577` (seuls `geometry`, `mapHeight`, `defaultCenter`, `interactive` sont consommés).

- **Constat vérifié** (`grep` sur `lib/`) : le widget lit uniquement `_config?.geometry`, `_config?.mapHeight`, `_config?.defaultCenter`, `_config?.interactive`. `_config?.defaultZoom`, `_config?.tileUrlTemplate`, `_config?.mapStyleJson` ne sont référencés **nulle part**. Les champs homonymes des adaptateurs (`ZOsmMapAdapter.tileUrlTemplate`, `ZGoogleMapAdapter.mapStyleJson`, `initialZoom`) sont **constructeur-only** et déconnectés de la config : la fabrique `ZMapAdapterFactory = ZMapAdapter Function()` est **sans argument**, donc `ZGoogleMapAdapter.new` / `ZOsmMapAdapter.new` ne reçoivent jamais la config, et `buildMap(...)` n'a aucun paramètre tuiles/style/zoom.
- **Impact** : poser `ZGeoFieldConfig(tileUrlTemplate: 'https://…', mapStyleJson: '…', defaultZoom: 8)` sur un champ **n'a strictement aucun effet** — l'adaptateur garde ses défauts de constructeur. Or l'AC3 liste explicitement `tileUrlTemplate`/`mapStyleJson`/`defaultZoom` comme « défauts **surchargeables** … lus via `ctx.field.config` par le widget », et les docstrings de `ZGeoFieldConfig` (l.16-17, 51-57) les annoncent comme « surchargeables par l'app hôte ». La promesse d'API est partiellement creuse (surface trompeuse). Les tests AC3 ne couvrent que `==`/`hashCode` + résolution de `geometry`, d'où le vert malgré le trou.
- **Nuance AD-12** : ce n'est PAS une violation AD-12 stricte — tuiles/style/zoom **restent** surchargeables via une closure de fabrique custom (`() => ZOsmMapAdapter(tileUrlTemplate: x)`), donc « aucun défaut non surchargeable » tient. Le défaut est le **couplage manquant** entre `ZGeoFieldConfig` et l'adaptateur.
- **Recommandation** (au choix, dans le périmètre) :
  1. **Plomber** les 3 champs : soit étendre `buildMap(..., double? zoom, String? tileUrlTemplate, String? mapStyleJson)` (additif), soit passer la config à une fabrique typée `ZMapAdapterFactory = ZMapAdapter Function(ZGeoFieldConfig? config)` et faire consommer `_config?.defaultZoom/tileUrlTemplate/mapStyleJson` par les adaptateurs ; ajouter un test « config.tileUrlTemplate atteint le `TileLayer` » et « config.defaultZoom atteint la caméra ».
  2. **Sinon** : retirer les 3 champs de `ZGeoFieldConfig` et corriger docstrings + AC3 pour ne promettre que `geometry`/`mapHeight`/`defaultCenter`/`interactive`, en documentant que tuiles/style/zoom passent par la fabrique d'adaptateur. **Un report doit être justifié par écrit** (CLAUDE.md — MEDIUM).

### LOW / nits

**LOW-1 — Mode cercle : un tap carte pour fixer le centre AVANT saisie d'un rayon valide ne recentre pas la carte.**
`z_geo_field_widget.dart:300-304, 560-566`. `_setCircleCenterFromTap` appelle `_emitCircleFromFields`, qui émet `null` tant que le rayon est absent/invalide ; `_mapSurface` dérive alors `circle = _circleOf(ctx.value) = null` → `center = _config?.defaultCenter` (souvent `null`) → l'adaptateur retombe sur son centre neutre. Asymétrie avec le mode `point` (où le tap recentre toujours). Impact UX mineur (un cercle sans rayon n'a pas de sens). Option : conserver le dernier centre tapé dans un `_workingCenter` local pour recentrer la carte même sans rayon.

**LOW-2 — Libellés des champs lat/lng figés en anglais (`'latitude'`/`'longitude'`), non routés l10n.**
`z_geo_field_widget.dart:425,433,459`. Contrairement au rayon (`label(context,'geo.radius')`), les libellés centre sont des littéraux. Pré-existant E11a-1, mais l'AC11 nomme `geo.center` : router ces libellés via `ZcrudScope.labels` (`geo.latitude`/`geo.longitude`) pour la cohérence i18n/a11y.

**LOW-3 — `interactive:false` (config) sans `readOnly` laisse la carte tappable.**
`z_geo_field_widget.dart:577-580`. `interactive` (gestes) et `onTap` sont découplés : un « aperçu non manipulable » (`ZGeoFieldConfig(interactive:false)` sur un champ non-readOnly) désactive zoom/scroll mais reste tappable (déplace le point/centre). Clarifier la sémantique attendue d'`interactive` (aperçu lecture seule ⇒ probablement aussi `onTap:null`).

**Nit — `_fmt` via `double.toString()`** peut produire une notation scientifique pour des valeurs extrêmes (pré-existant E11a-1) ; sans impact fonctionnel.

---

## Verdict

**Prêt pour `done` SOUS RÉSERVE du traitement de MEDIUM-1** (correction préférée, ou report explicitement justifié par écrit conformément à la politique MEDIUM de CLAUDE.md). Aucune HIGH/MAJEUR. Story fonctionnellement solide, gates verts (analyze RC=0, 97/97 tests, CORE OUT=0, zéro-secret, SDK confiné, rétro-compat E11a-1 stricte confirmée). Les LOW sont optionnelles.

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_geo` RC=0, `flutter test packages/zcrud_geo` **98 tests** (+1) RC=0, `graph_proof` CORE OUT=0 / ACYCLIQUE (SDK Google confiné).

- **MEDIUM-1 (champs morts) — CORRIGÉ (option « plomber »).** `buildMap` du port `ZMapAdapter` reçoit désormais 3 paramètres additifs optionnels `tileUrlTemplate`/`mapStyleJson`/`defaultZoom` ; le widget les passe depuis `ctx.field.config` ; l'adaptateur **OSM** honore `tileUrlTemplate` (TileLayer) + `defaultZoom` (zoom initial), l'adaptateur **Google** honore `mapStyleJson` (style) + `defaultZoom` — chacun ignore (documenté) le champ propre à l'autre backend. `FakeMapAdapter` mis à jour. **Test ajouté** : une config avec les 3 surcharges → assertions que `buildMap` les reçoit réellement (champs non morts). Additif/rétro-compatible (défauts `null` → comportement E11a-1 inchangé).
- **LOW-1 (tap cercle sans rayon ne recentre pas), LOW-2 (labels lat/lng non l10n — pré-existant E11a-1), LOW-3 (`interactive:false` sans readOnly reste tappable), Nit (`_fmt` toString) — CONSIGNÉS** (optionnels ; LOW-2 pré-existant hors périmètre E11b-1 ; à reprendre en E11b/l10n si besoin réel).

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
