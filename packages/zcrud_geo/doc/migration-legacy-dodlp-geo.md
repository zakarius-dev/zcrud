# Migration des valeurs géo legacy DODLP → zcrud_geo (G1)

> CR : `cr-geo-field-parity-legacy-2026-08-11.md`, § G1. Source legacy mesurée :
> DODLP `lib/modules/data_crud/models/geo_shape.dart` (`GeoShape.toJson()`).

Le legacy persiste chaque valeur géo en **chaîne JSON** d'un type polymorphe
unique auto-descriptif :

```json
{
  "type": "polygon",                       // point | circle | polygon | polyline (camelCase)
  "points": [{"lat": 6.13, "lng": 1.22}],  // cercle : points[0] = centre
  "radius": 250.0,                          // cercle uniquement (mètres)
  "style": {"fillColor": 859997684, "strokeColor": 4282549748, "strokeWidth": 3, "...": "..."},
  "holes": [[{"lat": 0, "lng": 0}]],       // polygone uniquement
  "id": "…", "label": "…", "metadata": {}
}
```

## Lecture (automatique, sans migration de données)

Depuis G1, la **lecture** zcrud comprend ce format nativement — aucun script de
migration Firestore n'est requis :

- `ZGeoValue.fromMapSafe(raw)` : point d'entrée **discriminé** (route sur
  `type`) → `ZGeoPoint` / `ZGeoCircle` / `ZGeoShape` / `null`. C'est l'entrée
  recommandée pour toute valeur d'origine inconnue.
- `ZGeoPoint/ZGeoCircle/ZGeoShape.fromMapSafe` acceptent aussi directement la
  chaîne JSON legacy et les alias de **lecture** ci-dessous.

## Correspondance champ à champ

| Legacy | zcrud | Note |
|---|---|---|
| enveloppe `String` JSON | `Map` | la String reste lue (jsonDecode défensif, invalide → `null`) |
| `type: "point"` + `points[0]` | `ZGeoPoint` (`lat`/`lng`) | `label` de la forme repris |
| `type: "circle"` + `points[0]` + `radius` | `ZGeoCircle` (`center` + `radius_m`) | **routage obligatoire** — lire un cercle comme forme perdrait le rayon ; `ZGeoShape.fromMapSafe` rend `null` sur un `type: "circle"` |
| `type: "polygon"` + `points` + `holes` | `ZGeoShape` (`vertices` + `holes`) | `holes` : mêmes clés |
| `type: "polyline"` + `points` | `ZGeoShape` | l'« ouverture » du tracé vient de `ZGeoFieldConfig.geometry = polyline`, pas de la valeur |
| `points` (lecture aussi : `latitude`/`longitude`) | `vertices` | alias de lecture seulement |
| `radius` (m) | `radius_m` | alias de lecture seulement |
| `style.fillColor`/`strokeColor`/`iconColor` (**int ARGB** = `Color.value`) | `style.fillColorArgb`/`strokeColorArgb`/`iconColorArgb` | même entier, aucun recodage |
| `style.iconSize`/`iconAnchor`/`iconRotation` | — | ignorés sans erreur (G17, hors périmètre G1) |
| `id`/`label`/`metadata` | `id`/`label`/`metadata` | inchangés |
| `List` JSON nue de points (lecteur legacy `fromDynamic`) | 1 → `ZGeoPoint`, sinon `ZGeoShape` | parité lecteur legacy |

## Écriture et impact hôte

- L'**écriture** zcrud (`toMap`) est **strictement inchangée** : à la première
  re-sauvegarde, la valeur passe au format zcrud (`vertices`/`center`/
  `radius_m`/`*Argb`, sans `type`).
- **Hôte passif** : rien à faire.
- **Hôte qui compensait** (pré-conversion legacy→zcrud avant d'alimenter le
  champ) : la compensation devient redondante et peut être **retirée** ; elle
  reste inoffensive tant qu'elle produit des valeurs zcrud valides. Tripwire
  recommandé : un test hôte qui affirme la perte legacy rougira désormais.
- Toute anomalie rend `null` (AD-10) — jamais de throw, jamais de forme vide
  non-nulle à la place d'un cercle.
