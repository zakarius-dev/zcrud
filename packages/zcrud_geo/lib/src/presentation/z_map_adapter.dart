/// `ZMapAdapter` — **abstraction de rendu carte optionnelle** (E11a-1, AD-1).
///
/// origine: le champ géo (`ZGeoFieldWidget`) doit pouvoir afficher une carte
/// SANS que `zcrud_geo` (ni a fortiori `zcrud_core`) n'expose un type de SDK
/// carte. Ce port est **pur** (aucune dépendance `flutter_map`/`google_maps`) :
/// il ne parle QUE de types neutres (`ZGeoPoint`/`ZGeoShape`/`Widget`/callbacks).
/// L'implémentation concrète (OSM `flutter_map`, cf.
/// `adapters/z_osm_map_adapter.dart`) confine le SDK à son propre fichier et
/// n'est PAS exportée par le barrel principal (AD-1 : le SDK reste hors de la
/// voie d'import par défaut).
///
/// **Cycle de vie (learning E5, MAJEUR-1)** : l'adaptateur possède un éventuel
/// contrôleur natif (ex. `MapController`). Le champ géo ne reçoit **jamais** une
/// instance partagée : il reçoit une **fabrique** ([ZMapAdapterFactory]) qu'il
/// appelle **1× en `State.initState`** pour créer SON instance possédée, disposée
/// en `State.dispose` (anti-fuite). Une instance d'adaptateur est donc **à usage
/// unique par montage de champ** : jamais aliasée entre deux champs, jamais
/// réutilisée après un dispose. Deux champs géo (ou un remontage) obtiennent
/// **deux instances distinctes**, chacune avec son propre `MapController`.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_geo_circle.dart';
import '../domain/z_geo_map_options.dart';
import '../domain/z_geo_point.dart';
import '../domain/z_geo_shape.dart';

/// Fabrique d'[ZMapAdapter] : crée une **nouvelle** instance possédée à chaque
/// appel (MAJEUR-1). Le champ géo l'invoque **1× par montage** (`initState`) pour
/// garantir « une instance par montage » — jamais d'instance partagée/aliasée.
typedef ZMapAdapterFactory = ZMapAdapter Function();

/// Seam **neutre** de résolution « ma position » (DP-7, gap B9). Renvoie un
/// [ZGeoPoint] neutre (ou `null` si indisponible/refusée/erreur). **Aucun SDK de
/// géolocalisation, aucune permission** n'est embarqué par `zcrud_geo` : l'app
/// hôte injecte sa propre implémentation via `ZGeoFieldWidget.builder(
/// locationResolver:)` (capturée par closure — AD-4, aucun slot `zcrud_core`).
/// Le bouton « ma position » est masqué/désactivé si ce seam est absent.
///
/// ## Contrat de permissions (G10 — à la charge de l'IMPLÉMENTATION hôte)
///
/// `zcrud_geo` ne déclare **aucune** permission plateforme et n'appelle
/// **jamais** un SDK de géolocalisation (AD-1 : `geolocator` n'entre pas dans
/// ce paquet). L'implémentation injectée porte TOUT le cycle mesuré sur le
/// legacy (`gff:219-265`, `centerOnCurrentLocation`) :
///
/// 1. vérifier que le **service** de localisation est actif (sinon informer
///    l'utilisateur côté hôte et renvoyer `null`) ;
/// 2. vérifier/demander la **permission** (`denied` → une seule redemande ;
///    `deniedForever` → `null` sans redemander) ;
/// 3. lire la position (le legacy utilise `LocationAccuracy.high`,
///    `distanceFilter: 10`, timeout 10 s) ;
/// 4. tout refus/échec/timeout → **`null`**, jamais un throw (le champ avale
///    de toute façon les exceptions — AD-10 — mais le contrat nominal est
///    `null`).
///
/// Côté champ (G10) : en géométrie polygone/polyligne, une position résolue
/// **recentre la caméra (zoom 16, parité legacy `gff:255`)** au lieu d'ajouter
/// un sommet ; en point/cercle elle fixe la valeur ET recentre. Le recentrage
/// n'est effectif que si l'adaptateur est [ZMapCameraCapable]
/// (honoré-si-supporté).
typedef ZGeoLocationResolver = Future<ZGeoPoint?> Function();

/// Callback de fin de **drag d'un sommet** (G13) : [index] du sommet dans
/// `shape.vertices` + nouvelle [position] neutre.
typedef ZGeoVertexDragEnd = void Function(int index, ZGeoPoint position);

/// Callback de fin de **déplacement de forme entière** (G13, parité legacy
/// `gff:1603-1642` via le marqueur au centroïde) : delta en degrés décimaux à
/// appliquer à chaque sommet (parité `_moveShape(deltaLat, deltaLng)`).
typedef ZGeoShapeDragEnd = void Function(double deltaLat, double deltaLng);

/// Callback de fin de **drag de la poignée de rayon** d'un cercle (G11) :
/// nouveau rayon en mètres (distance haversine centre→poignée).
typedef ZGeoRadiusDragEnd = void Function(double radiusMeters);

/// **Capacité caméra optionnelle** d'un adaptateur carte (G7).
///
/// ## Pourquoi une interface SÉPARÉE et pas deux méthodes sur [ZMapAdapter]
///
/// [ZMapAdapter] est un port **pur** (tous membres abstraits) et ses
/// implémenteurs connus — y compris externes — utilisent `implements` : toute
/// méthode ajoutée au port, même avec un corps no-op par défaut, casserait
/// leur compilation (`implements` exige de TOUT réimplémenter). La forme
/// additive qui **compile pour un implémenteur existant** (AD-4, contrainte
/// n°1) est donc une capacité **opt-in** : un adaptateur qui sait piloter sa
/// caméra ajoute `implements ZMapCameraCapable` ; l'appelant teste
/// `adapter is ZMapCameraCapable` et **ne fait rien sinon**
/// (honoré-si-supporté — le « défaut no-op » vit au site d'appel).
///
/// Contrat (parité legacy `map_interface.dart:7`, `UnifiedMapController`) :
/// jamais de throw si la carte n'est pas (encore) montée — no-op silencieux
/// (AD-10).
abstract class ZMapCameraCapable {
  /// Déplace la caméra sur [center] ([zoom] optionnel ; `null` → zoom courant
  /// conservé si l'adaptateur le connaît, sinon son défaut). Carte non montée
  /// ou point invalide → no-op silencieux, jamais de throw (AD-10).
  Future<void> moveCamera(ZGeoPoint center, {double? zoom});

  /// Cadre la caméra sur la boîte [southWest]→[northEast]. Mêmes garanties
  /// défensives que [moveCamera].
  Future<void> fitBounds(ZGeoPoint southWest, ZGeoPoint northEast);
}

/// **Capacité de gestes d'édition optionnelle** d'un adaptateur carte
/// (G11/G13). Même logique opt-in que [ZMapCameraCapable] (AD-4 : rien n'est
/// ajouté au port pur — un implémenteur externe existant compile inchangé et
/// n'offre simplement pas le drag, contrat honoré-si-supporté).
///
/// Les handlers sont des **champs mutables** (et non des paramètres de
/// `buildMap` : en ajouter casserait les overrides existants du port) : le
/// champ géo les (dé)pose avant chaque `buildMap` ; l'adaptateur rend les
/// poignées correspondantes **uniquement quand le handler est non-`null`**
/// (`null` ⇒ rendu strictement inchangé — AD-4) :
///
/// - [onVertexDragEnd] ≠ `null` → sommets **draggables** (fin de drag :
///   parité legacy `gff:1603-1642`, `_handleMarkerDragEnd`) ;
/// - [onShapeDragEnd] ≠ `null` → **marqueur au centroïde** draggable
///   (mode « Déplacer », parité `gff:310-315` + `gff:647-664`) ;
/// - [onCircleRadiusDragEnd] ≠ `null` → **poignée de rayon** draggable sur le
///   périmètre du cercle (G11).
abstract class ZMapGesturesCapable {
  /// Fin de drag d'un sommet (G13). `null` → sommets non draggables.
  abstract ZGeoVertexDragEnd? onVertexDragEnd;

  /// Fin de déplacement de la forme entière via le marqueur au centroïde
  /// (G13). `null` → aucun marqueur de déplacement rendu.
  abstract ZGeoShapeDragEnd? onShapeDragEnd;

  /// Fin de drag de la poignée de rayon du cercle (G11). `null` → aucune
  /// poignée rendue.
  abstract ZGeoRadiusDragEnd? onCircleRadiusDragEnd;
}

/// **Couche de lecture multi-formes** (G6) : une valeur géo neutre
/// ([ZGeoPoint]/[ZGeoCircle]/[ZGeoShape] — champ [value] typé `Object` faute
/// d'ancêtre commun, routé par `is` dans l'adaptateur) + un [id] stable pour
/// la sélection par tap marqueur. [renderAsPolyline] : `true` → une
/// [ZGeoShape] est rendue en tracé ouvert. Une valeur d'un autre type est
/// **ignorée** sans erreur (AD-10).
class ZGeoMapOverlay {
  /// Construit l'overlay `const`.
  const ZGeoMapOverlay({
    required this.id,
    required this.value,
    this.renderAsPolyline = false,
  });

  /// Identifiant stable remonté par `onOverlayMarkerTap`.
  final String id;

  /// Valeur géo neutre (point/cercle/forme) — jamais un type SDK.
  final Object value;

  /// `true` → forme rendue en tracé ouvert (polyligne).
  final bool renderAsPolyline;
}

/// Port de rendu carte en **types neutres uniquement**. Optionnel : si aucun
/// adaptateur n'est injecté, le champ géo dégrade proprement (saisie
/// coordonnées seule), sans crash.
abstract class ZMapAdapter {
  /// Construit la surface carte.
  ///
  /// - [center] : point de centrage initial (si `null`, l'implémentation choisit
  ///   un centre neutre par défaut) ;
  /// - [shape] : aire à surligner (sommets/polyligne) — optionnel ;
  /// - [circle] : cercle à surligner (centre + rayon mètres) — optionnel
  ///   (E11b-1, additif rétro-compatible : défaut `null` → aucun cercle) ;
  /// - [onTap] : remonté quand l'utilisateur tape la carte, en **coordonnées
  ///   neutres** ([ZGeoPoint]) — jamais un type SDK ;
  /// - [interactive] : `false` pour un aperçu non manipulable (lecture seule) ;
  /// - [tileUrlTemplate] : gabarit d'URL de tuiles **surchargeable par-champ**
  ///   (honoré par l'adaptateur OSM ; ignoré par Google) — `null` → défaut de
  ///   l'adaptateur (E11b-1, additif) ;
  /// - [tileUrlTemplates] : gabarits de tuiles **par type de carte** (G3,
  ///   honoré par l'adaptateur OSM pour rendre `mapOptions.mapType`
  ///   satellite/hybride/terrain ; ignoré par Google qui a des types natifs) —
  ///   `null` → défauts audités `ZGeoTileReference.defaults` ;
  /// - [mapStyleJson] : style de carte **surchargeable par-champ** (honoré par
  ///   l'adaptateur Google ; ignoré par OSM) — `null` → défaut de l'adaptateur ;
  /// - [defaultZoom] : zoom initial **surchargeable par-champ** (honoré par les
  ///   deux adaptateurs) — `null` → défaut de l'adaptateur ;
  /// - [mapOptions] : options de carte **neutres** pilotées par la barre d'outils
  ///   d'éditeur (DP-7 : type de carte, trafic, bâtiments, gestes, contrôles…) —
  ///   `null` (défaut) → comportement inchangé. Chaque adaptateur **honore ce
  ///   qu'il supporte, ignore le reste** (même contrat que [tileUrlTemplate]/
  ///   [mapStyleJson]) ;
  /// - [renderShapeAsPolyline] : quand `true`, [shape] est rendue en **tracé
  ///   ouvert** (polyligne, 4e forme DP-21/M13) et non en polygone fermé — aucun
  ///   segment de fermeture, aucun remplissage. `false` (défaut) → rendu polygone
  ///   inchangé (rétro-compat E11a-1/E11b-1). Signal **neutre**, même contrat
  ///   honoré-si-supporté que [mapOptions] ;
  /// - [minZoom]/[maxZoom] : bornes de zoom **surchargeables par-champ** (G23,
  ///   honorées-si-supportées : OSM `MapOptions.minZoom/maxZoom`, Google
  ///   `minMaxZoomPreference`) — `null` → défaut de l'adaptateur ;
  /// - [overlays] : **couches de LECTURE multi-formes** (G6, base de
  ///   `ZGeoMapView`) — chaque entrée ([ZGeoMapOverlay]) porte une valeur
  ///   neutre (point/cercle/forme) rendue EN PLUS de [shape]/[circle], avec
  ///   son style porté par la valeur (G9/G14) et un **marqueur d'ancrage**
  ///   (centre/centroïde) identifié par `overlay.id`. `null`/vide (défaut) →
  ///   rendu strictement inchangé (AD-4) ;
  /// - [onOverlayMarkerTap] : tap sur le marqueur d'ancrage d'un overlay →
  ///   remonte son `id` (parité legacy `gfv:132-139` : la sélection de
  ///   `GeofenceView` passe par le TAP MARQUEUR, mesuré — pas par le corps de
  ///   la forme). `null` → marqueurs d'overlay non tappables.
  ///
  /// **Style de forme (DP-21/M13, étendu G9/G14/G17)** : le rendu honore le
  /// style porté par la **valeur elle-même** — [ZGeoShape.style], et désormais
  /// [ZGeoCircle.style] et [ZGeoPoint.style] (G9 : les 3 types) — couleurs ARGB
  /// neutres → `Color` SDK confiné, épaisseur/visibilité, marqueur labellisé
  /// (`infoWindowTitle`/`iconAsset`/`iconColorArgb` — G14) et géométrie d'icône
  /// (`iconSize`/`iconRotation`/`iconAnchor` — G17), **si l'adaptateur les
  /// supporte**, avec repli sur le thème injecté (FR-26) quand une couleur est
  /// absente. `style == null` ⇒ rendu strictement inchangé (AD-4). Aucun
  /// paramètre supplémentaire : le style voyage avec la valeur.
  ///
  /// Retourne un `Widget` opaque : l'appelant ne voit AUCUN type carte.
  ///
  /// **Note compat (0.x)** : les ajouts [circle]/[tileUrlTemplate]/[mapStyleJson]/
  /// [defaultZoom]/[mapOptions]/[renderShapeAsPolyline] sont des évolutions
  /// **mineures additives** du port ; les appelants existants compilent
  /// inchangés ; un adaptateur externe recompile (additif, non-cassant).
  Widget buildMap(
    BuildContext context, {
    ZGeoPoint? center,
    ZGeoShape? shape,
    ZGeoCircle? circle,
    ValueChanged<ZGeoPoint>? onTap,
    bool interactive = true,
    String? tileUrlTemplate,
    Map<ZGeoMapType, String>? tileUrlTemplates,
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
    double? minZoom,
    double? maxZoom,
    List<ZGeoMapOverlay>? overlays,
    ValueChanged<String>? onOverlayMarkerTap,
  });

  /// Libère le contrôleur natif éventuel (learning E5). Idempotent : un second
  /// appel ne doit pas throw.
  void dispose();
}
