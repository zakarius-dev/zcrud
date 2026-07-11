# DP-21 — Geo : style des formes + polyline + holes/metadata (gap MAJEUR M13)

**Mode** : DEV DIRECT (dev-story accéléré, sans create-story).
**Package cible (disjoint)** : `packages/zcrud_geo` (satellite). **Aucun** fichier
`zcrud_core` ni DODLP modifié (DODLP lu en seule référence).
**Source** : `docs/dodlp-edition-parity-gap.md` §2.5, ligne M13. Référence lecture
seule : `dodlp-otr/lib/modules/data_crud/models/geo_shape.dart`
(`GeoShapeStyle`, `GeoShapeType.polyline`, `holes`/`metadata`/`id`).

## Objectif

Porter, **neutre et additif**, le style de rendu des formes géo, la 4e forme
(polyligne, tracé ouvert) et les attributs `holes`/`metadata`/`id` de `ZGeoShape`,
sans qu'aucun type SDK carte (Google/OSM) ni `dart:ui`/`Color` n'entre dans le
domaine (AD-1/AD-5).

## Critères d'acceptation — implémentés

- **AC1 — 4e forme `polyline`** : valeur `polyline` ajoutée à l'enum
  `ZGeoGeometry` (camelCase, canonique §5). La valeur de tranche reste un
  `ZGeoShape` (mêmes sommets ordonnés qu'un polygone) ; le widget la collecte via
  la **même UI** que le polygone (bouton/liste de sommets) et signale un **tracé
  ouvert** à l'adaptateur. *(`z_geo_field_config.dart`, `z_geo_field_widget.dart`)*
- **AC2 — `ZGeoShapeStyle` pur-données `const` neutre (AD-5/AD-14)** : nouveau
  modèle domaine. Couleurs exprimées en **entier ARGB 32 bits** (`fillColorArgb`,
  `strokeColorArgb`, `iconColorArgb`) — **aucun `Color` SDK**. Champs :
  `strokeWidth`, `opacity` (bornée [0,1]), `visible`, `zIndex`, `geodesic`,
  `draggable`, `consumeTapEvents`, `iconAsset`, `showInfoWindow`,
  `infoWindowTitle`, `infoWindowSnippet`. `toMap`/`fromMapSafe`/`copyWith` +
  `==`/`hashCode`. *(`z_geo_shape_style.dart`)*
- **AC3 — `ZGeoShape` enrichi (additif strict)** : ajout de `id` (String?),
  `style` (`ZGeoShapeStyle?`), `holes` (`List<List<ZGeoPoint>>?`), `metadata`
  (`Map<String,Object?>?`), tous **optionnels `null` par défaut**. `holes`/
  `metadata` copiés **non modifiables**. Une forme E11a-1 sans ces attributs
  produit **exactement** l'ancien `Map` (clés omises quand `null`).
  *(`z_geo_shape.dart`)*
- **AC4 — parse défensif (AD-10)** : `fromMapSafe` ne throw jamais — `style`/
  `metadata` corrompus → `null` ; trou non-`List` ignoré ; sommets de trou
  invalides filtrés ; `holes` non-`List` → `null` ; opacité non finie/hors bornes
  bornée ou défaut ; couleur illisible → `null`.
- **AC5 — adapters traduisent, honorent/ignorent (contrat DP-7)** :
  - **Google** (`z_google_map_adapter.dart`) : `style` → `Polygon`/`Polyline`
    (fill/stroke/width/geodesic/zIndex/visible/consumeTapEvents), `holes` →
    `Polygon.holes`, `renderShapeAsPolyline` → `Polyline` (tracé ouvert). Sans
    `style` → défauts SDK d'origine (rétro-compat E11b-1 stricte).
  - **OSM** (`z_osm_map_adapter.dart`) : `style` → `PolygonLayer`/`PolylineLayer`
    (couleurs ARGB→`Color` **confiné**, épaisseur, `visible`), `holes` →
    `holePointsList`, `renderShapeAsPolyline` → `PolylineLayer`. Repli couleurs
    sur le **thème injecté** (FR-26).
  - Le nouveau paramètre de port `renderShapeAsPolyline` est **neutre**, additif,
    honoré-si-supporté (même contrat que `mapOptions`).
- **AC6 — neutralité SDK / AD-1** : le barrel `zcrud_geo.dart` exporte
  `ZGeoShapeStyle` (pur-données) ; **aucun** type SDK/`Color` dans une signature
  publique ni dans la valeur de tranche. Conversion ARGB→`Color` **confinée** aux
  deux fichiers d'adaptateur. `graph_proof` : `zcrud_geo -> zcrud_core` seul,
  acyclique, core out-degree 0.
- **AC7 — a11y (AD-13) + RTL** : UI de collecte polyligne = UI polygone existante
  (cibles ≥48dp, `Semantics`, layout directionnel) — inchangée.

## Fichiers

**Créés** :
- `packages/zcrud_geo/lib/src/domain/z_geo_shape_style.dart`
- `packages/zcrud_geo/test/z_geo_shape_style_test.dart`

**Modifiés** :
- `packages/zcrud_geo/lib/src/domain/z_geo_shape.dart` (id/style/holes/metadata)
- `packages/zcrud_geo/lib/src/domain/z_geo_field_config.dart` (enum `polyline`)
- `packages/zcrud_geo/lib/zcrud_geo.dart` (export `z_geo_shape_style.dart`)
- `packages/zcrud_geo/lib/src/presentation/z_map_adapter.dart` (param `renderShapeAsPolyline` + doc style)
- `packages/zcrud_geo/lib/src/presentation/adapters/z_google_map_adapter.dart`
- `packages/zcrud_geo/lib/src/presentation/adapters/z_osm_map_adapter.dart`
- `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` (géométrie polyligne)
- `packages/zcrud_geo/test/support/fake_map_adapter.dart` (capture `renderShapeAsPolyline`)
- `packages/zcrud_geo/test/z_geo_shape_test.dart` (attributs + défensif)
- `packages/zcrud_geo/test/z_google_map_adapter_test.dart` (polyline/style/holes honorés)
- `packages/zcrud_geo/test/z_osm_map_adapter_test.dart` (PolylineLayer vs PolygonLayer, style visible/holes)
- `packages/zcrud_geo/test/z_geo_field_widget_test.dart` (géométrie polyligne bout-en-bout)

## Vérif verte (rejouée réellement sur disque)

- `dart analyze packages/zcrud_geo` → **RC=0** (No issues found!)
- `flutter test packages/zcrud_geo` → **162 tests, All tests passed!**
- `python3 scripts/dev/graph_proof.py` (depuis la racine) → **RC=0** — acyclique,
  `zcrud_geo -> zcrud_core` seul, `CORE OUT=0 OK`.

> Note : un premier run de `flutter test` a montré 3 fichiers en échec de
> compilation **transitoire** dus à une édition **concurrente en cours** de
> `zcrud_core` (workstream DP-12, `z_number_field_widget.dart` mi-écriture,
> `resolvedLabel` indéfini). Après stabilisation du workstream voisin, la suite
> `zcrud_geo` passe intégralement. Aucun fichier `zcrud_core` n'a été modifié par
> DP-21.

## Invariants respectés

AD-1 (aucun SDK/`Color` dans le domaine ; conversion confinée aux adaptateurs) ·
AD-5 (couleurs en int ARGB neutre) · AD-10 (parse défensif, jamais de throw) ·
AD-13 (a11y ≥48dp, RTL) · AD-14 (pur-données `const`) · FR-26 (repli thème
injecté, zéro couleur en dur côté widget) · rétro-compat **additive stricte**
(les 3 formes existantes intactes, `ZGeoShape` sans style/holes inchangé, barrel
additif, enums camelCase).
