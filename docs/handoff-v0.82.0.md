# Handoff **v0.82.0** — les deux CR d'exploration soldées : geo G1→G23 + enrichissements, markdown GAP-1→12, et un 39ᵉ paquet

> **Tag à épingler : `v0.82.0`** — solde **intégralement** vos deux CR du 2026-08-11 (avec v0.81.0
> pour G1 et GAP-1..4). **Nouveau paquet : `zcrud_geo_location`** (39 paquets).
> 🔴 **Quatre changements de défaut visibles**, listés en § 3 — tout le reste est opt-in.
> ⚠️ Notre CI reste à l'arrêt (facturation) — vérifications locales uniquement.

---

## 1. Geo — G2→G23 + le trio d'enrichissement

**Paramétrage** : multi-géométries (`allowedGeometries`, la valeur initiale prime — parité), fournisseur
par champ (`adapterKey`/`adapterFactories`, repli mono-factory immobile), défaut toolbar `standard`.
**Rendu** : tuiles OSM typées (ESRI sat/hybride, OpenTopoMap terrain — URLs **mesurées** chez vous,
en référence auditée surchargeable), style sur les 3 types de valeur, marqueurs labellisés (OSM :
pastille thémée ; Google : écart **documenté**, pas simulé — bitmap async impossible en `buildMap`
synchrone… et votre legacy Google n'honorait **jamais** `iconAsset` non plus, mesuré), `iconSize/
Anchor/Rotation` portés **et relus** (la lecture G1 les jetait — corrigé), presets legacy en référence.
**Interaction** : plein écran (brouillon local, écrit **seulement à « Enregistrer »**, fermeture d'un
brouillon modifié confirmée — la perte silencieuse du legacy n'est **pas** copiée), caméra au port via
**capacités opt-in** (`ZMapCameraCapable` : la lettre de votre CR — « méthodes au port » — aurait cassé
tout implémenteur `implements`, mesuré), « ma position » **recentre** (zoom 16) au lieu d'ajouter un
sommet, cercle 2-taps haversine + poignée draggable, drag de sommets/formes sur les DEUX adaptateurs
(OSM : `flutter_map` n'a aucun drag natif et son arène avale les gestes enfants — recognizer dédié,
prouvé par gestes réels).
**Surface** : `ZGeoMapView` (lecture multi-formes, labels, sélection, centrage, toggle), style picker
câblé (`showStylePicker`, style persisté), métriques (formules **de votre legacy**, nature documentée :
aire sphérique, cercle planaire) + chip localisé, `showOptimizeButton`/`useMapOptionsDropdown` rendus
**réels**, chrome de carte opt-in (pied **localisé** `geo.pointsDefined` — votre texte anglais en dur
n'est pas copié), compaction < 600 dp, `myLocation*` (OSM : documenté sans équivalent), zoom min/max
exposés (`zoomStep` : porté mais **sans consommateur** — dit tel quel).
**Enrichissement** : `containsPoint` (ray casting, trous, frontière inclusive, cercle haversine) et
GeoJSON `toGeoJson`/`fromGeoJsonSafe` — l'inversion lon,lat de RFC 7946 a sa garde dédiée, rouge dans
les deux sens.

## 2. Markdown — GAP-5→12 (avec GAP-1..4 en v0.81.0, la CR est soldée)

`ZRichTextStyleSet` par champ (tous les slots de votre `qdsh`) — **vos polices et votre palette ne
sont PAS entrées chez nous** : l'injection hôte suffit, c'est vous qui portez Inter/Poppins/FiraCode.
Chrome « carte » opt-in (`ZMarkdownChromeReference` : dimensions/opacités **seulement**, zéro couleur),
pilule « Rédiger/Modifier/Valider » avec `deferWrites` en **double opt-in** — l'auto-save reste le
défaut. `textScaleFactor` + spec de formule (vos facteurs legacy étaient **morts** dans votre propre
code — mesuré). **`spellCheck` refusé sur mesure** : `flutter_quill` ne l'expose pas, et votre legacy
ne l'appliquait jamais. Icônes rounded/multi-rangées/fond thémé en opt-in (aucun tooltip FR en dur —
votre legacy n'en posait aucun, la l10n Quill est préservée), icône tableau alignée, copie long-press
opt-in (SnackBar via `maybeOf`, silencieux sans libellé), état vide enrichi opt-in.

## 3. 🔴 Les quatre changements de défaut (les seuls)

| Changement | Qui le voit | Geste si vous compensiez |
|---|---|---|
| **toolbar geo `standard`** quand `toolbarConfig` null (G15 — votre préférence) | tout hôte geo passif | retirez votre barre maison, ou `ZGeoEditorToolbarConfig.none` |
| **OSM honore `mapType`** (G3) : hybrid ⇒ tuiles ESRI | hôte geo passif en mode hybrid | retirez votre fond satellite custom, ou posez `tileUrlTemplates` |
| **rotation/tilt `false`** (G22 — parité legacy) | hôte qui comptait sur `true` | réactivez explicitement dans `ZGeoMapOptions` |
| **barré retiré des présets `full`/`markdown`** + icône tableau (GAP-8/10) | tout hôte markdown | `copyWith(showStrikethrough: true)` — mesuré : **aucun** de vos 4 dépôts ne consomme la config de toolbar |

Également visibles mais corrections attendues : bouton plein écran geo (défaut `true`, parité) ;
« ma position » ne crée plus de sommet fantôme.

## 4. `zcrud_geo_location` — 39ᵉ paquet (G10)

`resolver: zcrudGeolocatorResolver()` et c'est tout : `geolocator` **confiné** (aucun type ne fuit,
grep montré), causes d'échec **distinctes** (`serviceDisabled` / `permissionDenied` /
`permissionDeniedForever` / `error`), jamais de throw — y compris si **votre** callback d'échec throw.
Parité comportementale mesurée sur votre `gff:219-265` : une seule redemande, `deniedForever` sans
redemande, `high`/10 m/10 s. **Le message utilisateur reste chez vous** — seule la cause voyage.
⚠️ À déclarer **par l'hôte** : `ACCESS_FINE_LOCATION` (Android), `NSLocationWhenInUseUsageDescription`
(iOS) — le satellite n'embarque aucun manifest. Ajouté à la recette de consommation git
(`docs/private-git-consumption.md`) — c'est la porte `verify` qui a exigé cette ligne.

## 5. Vérification

`melos generate` **RC=0** (0 `.g.dart`) · `melos analyze` **RC=0** · `melos verify` **RC=0** (39 nœuds,
acyclique, `CORE OUT=0`, recette de consommation complète) — rejoués **après** le bump.
`zcrud_geo` **358** (+157 depuis v0.81.0) · `zcrud_geo_location` **22** (nouveau) · `zcrud_markdown`
**564** (+28) · `zcrud_core` 1744 · `example` 108. **0 erreur, 0 avertissement.**

**R3 — 47 injections cumulées sur les 6 lots, toutes rouges par ASSERTION**, sha avant/après,
restauration par copie, résidus prouvés par greps négatifs montrés, lignes de base dans les deux sens.

🔴 **Un agent est mort en plein vol** (erreur API) pendant le lot surface. L'état a été **mesuré**
(vert, sans résidu d'injection), puis un agent de reprise a fait l'inventaire contradictoire des 11
items et **re-prouvé les 17 gardes héritées par injection** — une garde héritée d'un agent
interrompu n'est jamais présumée mordante. Résultat : 11/11 livrés, 0 garde inerte, arbre bit-à-bit
identique après la campagne de preuve.

## 6. Signalé, non fait

* Le **type-somme fort** des valeurs géo (votre G1-c au sens plein) : `ZGeoValue.fromMapSafe` rend
  `Object?` — l'ancêtre commun est un changement de modèle, **votre arbitrage**.
* `zoomStep` : porté, sans consommateur côté adaptateurs (dit en § 1).
* Le reste de votre § 2 d'enrichissement (tuiles hors-ligne, géocodage, clustering, snapping…) —
  au fil des CR.
* Dettes antérieures : cf. `v0.81.0` et les handoffs précédents.
