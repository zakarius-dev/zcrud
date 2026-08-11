# zcrud_geo

Champ géo riche pour zcrud : un modèle de valeur neutre (point/cercle/aire),
des adaptateurs carte pluggables (OSM sans clé, Google Maps optionnel), et un
widget de champ complet servi via `ZWidgetRegistry`.

## Aperçu {#apercu}

`zcrud_geo` porte les types de champ `location` (point) et `geoArea`
(polygone), ainsi qu'une géométrie `circle` additive. Le domaine
(`ZGeoPoint`/`ZGeoCircle`/`ZGeoShape`) est **pur-Dart** : aucun type SDK carte
n'y apparaît, invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1).
Le rendu carte passe par le port [`ZMapAdapter`](lib/src/presentation/z_map_adapter.dart),
que deux adaptateurs concrets implémentent — OSM (`flutter_map`, sans clé
API) et Google Maps — chacun confiné à sa propre entrée d'import dédiée
(`lib/adapters/osm.dart`, `lib/adapters/google.dart`), jamais exposée par le
barrel principal. Le widget de champ (`ZGeoFieldWidget`) suit le patron
réactif granulaire du cœur (invariant AD-2) : contrôleurs et focus créés une
fois, jamais recréés au fil de la frappe.

**Utilisez ce paquet** pour un champ de formulaire saisissant une position,
un cercle ou une zone géographique — avec édition sur carte, barre d'outils,
plein écran, style de forme et métriques (aire/périmètre), le tout opt-in.
**N'utilisez pas ce paquet** pour une simple résolution « ma position » côté
hôte sans champ de formulaire (voir `zcrud_geo_location` pour un resolver
clé en main), ni pour du rendu de carte hors du moteur de formulaire zcrud —
`ZGeoMapView` couvre ce dernier cas si vous restez dans le paquet.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
// Adaptateur OSM : entrée dédiée, hors barrel principal (invariant AD-1).
import 'package:zcrud_geo/adapters/osm.dart';

/// Enregistre le champ géo pour les types `location` (point) et `geoArea`
/// (polygone), rendus via l'adaptateur OSM (aucune clé API requise).
void registerGeoField(ZWidgetRegistry registry) {
  registry
    ..register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))
    ..register('geoArea', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new));
}

/// Un point neutre, valable sans aucun adaptateur carte injecté.
const point = ZGeoPoint(lat: 13.5, lng: 2.1);
```

## Concepts clés {#concepts-cles}

- **Modèle de valeur neutre** — `ZGeoPoint`, `ZGeoCircle`, `ZGeoShape` sont
  trois types **disjoints, sans ancêtre commun** ; la géométrie du champ
  (`ZGeoFieldConfig.geometry`) détermine lequel est produit. `ZGeoValue.fromMapSafe`
  route une valeur brute (legacy ou zcrud) sur le bon type, jamais de throw
  (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10)).
- **Adaptateurs carte pluggables** — le port `ZMapAdapter` ne parle que de
  types neutres ; `ZOsmMapAdapter`/`ZGoogleMapAdapter` traduisent vers leur
  SDK respectif dans un fichier confiné, atteint par une entrée d'import
  dédiée. Sans adaptateur injecté, le champ dégrade proprement en saisie
  coordonnées seule.
- **Présentations et plein écran** — `ZGeoFieldConfig.presentation` bascule
  entre édition complète en flux et aperçu inerte + édition en plein écran
  (`ZGeoFieldConfig.allowFullscreen`) ; la route immersive rend toujours le
  champ avec toutes ses capacités.
- **Capacités opt-in** — barre d'outils d'éditeur, picker de style, chip de
  métriques (aire/périmètre), chrome de carte (encart/en-tête) sont tous
  additifs et désactivés par défaut sauf la barre d'outils (`standard`) ;
  voir [`ZGeoFieldConfig`](lib/src/domain/z_geo_field_config.dart).
- **Compatibilité de lecture avec un format hérité** — les modèles de valeur
  lisent nativement un format JSON historique polymorphe (voir
  [doc/migration-legacy-dodlp-geo.md](doc/migration-legacy-dodlp-geo.md)) ;
  l'écriture (`toMap`) produit toujours le format zcrud.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Modèle de valeur** | |
| `ZGeoPoint` / `ZGeoCircle` / `ZGeoShape` | Point, cercle, aire ou tracé — modèles pur-Dart, sérialisation défensive. |
| `ZGeoValue` | Routeur de lecture discriminé (legacy ou zcrud) vers le bon type de valeur. |
| `ZGeoJson` / `ZGeoPointGeoJson` / `ZGeoShapeGeoJson` / `ZGeoCircleGeoJson` | Import/export GeoJSON (RFC 7946) des valeurs neutres. |
| `ZGeoShapeStyle` | Style de rendu neutre (couleurs ARGB, épaisseur, icône, info-window). |
| `ZGeoShapeMetrics` / `ZGeoCircleMetrics` / `ZGeoBounds` | Extensions de métriques pures : aire, périmètre, centroïde, boîte englobante, appartenance. |
| **Configuration du champ** | |
| `ZGeoFieldConfig` / `ZGeoGeometry` / `ZGeoPresentation` | Config additive du champ : géométrie, défauts de carte, présentation, capacités opt-in. |
| `ZGeoEditorToolbarConfig` | Config de la barre d'outils d'éditeur (18 toggles + 5 presets). |
| `ZGeoMapOptions` / `ZGeoMapType` | État neutre des options de carte (type, trafic, gestes…). |
| `ZGeoTileReference` / `ZGeoStyleReference` / `ZGeoChromeReference` | Valeurs de référence auditées (tuiles OSM, presets de style, chrome). |
| **Widgets** | |
| `ZGeoFieldWidget` | Champ d'édition géo complet, servi via `ZWidgetRegistry`. |
| `ZGeoMapView` | Vue de lecture multi-formes hors formulaire. |
| `ZGeoShapeStylePicker` | Toolbar de style fill/stroke d'une forme. |
| **Port carte et adaptateurs** | |
| `ZMapAdapter` / `ZMapAdapterFactory` | Port de rendu carte en types neutres, et sa fabrique. |
| `ZMapCameraCapable` / `ZMapGesturesCapable` | Capacités optionnelles opt-in (caméra pilotable, gestes d'édition). |
| `ZGeoLocationResolver` | Seam neutre « ma position » (voir `zcrud_geo_location` pour une implémentation clé en main). |
| `ZOsmMapAdapter` (`adapters/osm.dart`) | Adaptateur OSM via `flutter_map`, sans clé API. |
| `ZGoogleMapAdapter` (`adapters/google.dart`) | Adaptateur Google Maps ; clé API fournie par la config plateforme de l'hôte. |

## Cas limites et invariants {#cas-limites}

- **Désérialisation défensive partout** — un point/cercle/forme corrompu,
  hors-bornes ou d'un format inattendu ne fait jamais throw : `fromMapSafe`
  rend `null` (ou une forme vide) plutôt qu'une exception (invariant AD-10).
- **Aucun type SDK carte ne fuit** — ni dans la valeur de tranche, ni dans une
  signature publique du barrel principal ; les deux adaptateurs concrets
  vivent derrière des entrées d'import dédiées (invariant AD-1).
- **Zéro secret** — l'adaptateur OSM ne requiert aucune clé ; l'adaptateur
  Google lit sa clé depuis la config plateforme de l'application hôte,
  jamais depuis ce paquet (invariant AD-12).
- **Une instance d'adaptateur par montage de champ** — la fabrique
  ([`ZMapAdapterFactory`](lib/src/presentation/z_map_adapter.dart)) est
  appelée une fois en `initState` ; l'instance n'est jamais partagée entre
  deux champs ni réutilisée après `dispose`.
- **RTL et accessibilité** ([AD-13](../../docs/site/concepts/invariants.md#ad-13))
  — variantes directionnelles, cibles tactiles ≥ 48 dp, `Semantics` explicites
  sur les boutons de la barre d'outils et du picker de style.
- **Formes de valeur inertes** — sans adaptateur carte injecté, le champ
  dégrade en saisie coordonnées seule sans jamais crasher.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_geo.md`](../../docs/site/paquets/zcrud_geo.md)
- [`zcrud_geo_location`](../zcrud_geo_location/README.md) — resolver « ma position » clé en main pour ce paquet.
- [Migration des valeurs legacy DODLP](doc/migration-legacy-dodlp-geo.md) — correspondance champ à champ du format historique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZFieldConfig`, `ZWidgetRegistry`, `ZFieldWidgetContext`, `ZcrudTheme`.

## Licence {#licence}

MIT — voir la racine du dépôt.
