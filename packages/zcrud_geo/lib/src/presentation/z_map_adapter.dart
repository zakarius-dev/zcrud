/// `ZMapAdapter` — **abstraction de rendu carte optionnelle**.
///
/// Le champ géo (`ZGeoFieldWidget`) doit pouvoir afficher une carte sans que
/// `zcrud_geo` — ni a fortiori `zcrud_core` — n'expose un type de SDK carte.
/// Ce port est **pur** (aucune dépendance `flutter_map`/`google_maps`) : il
/// ne parle que de types neutres (`ZGeoPoint`/`ZGeoShape`/`Widget`/
/// callbacks). L'implémentation concrète (OSM via `flutter_map`, cf.
/// `adapters/z_osm_map_adapter.dart`) confine le SDK à son propre fichier et
/// n'est pas exportée par le barrel principal (invariant AD-1 : le SDK reste
/// hors de la voie d'import par défaut).
///
/// **Cycle de vie** : l'adaptateur possède un éventuel contrôleur natif (ex.
/// `MapController`). Le champ géo ne reçoit **jamais** une instance
/// partagée : il reçoit une **fabrique** ([ZMapAdapterFactory]) qu'il appelle
/// **une fois en `State.initState`** pour créer son instance possédée,
/// disposée en `State.dispose`. Une instance d'adaptateur est donc **à usage
/// unique par montage de champ** : jamais aliasée entre deux champs, jamais
/// réutilisée après un dispose. Deux champs géo (ou un remontage) obtiennent
/// **deux instances distinctes**, chacune avec son propre contrôleur natif.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_geo_circle.dart';
import '../domain/z_geo_map_options.dart';
import '../domain/z_geo_point.dart';
import '../domain/z_geo_shape.dart';

/// Fabrique d'[ZMapAdapter] : crée une **nouvelle** instance possédée à
/// chaque appel. Le champ géo l'invoque **une fois par montage**
/// (`initState`) pour garantir « une instance par montage » — jamais
/// d'instance partagée/aliasée.
typedef ZMapAdapterFactory = ZMapAdapter Function();

/// Seam **neutre** de résolution « ma position ». Renvoie un [ZGeoPoint]
/// neutre (ou `null` si indisponible/refusée/erreur). **Aucun SDK de
/// géolocalisation, aucune permission** n'est embarqué par `zcrud_geo` :
/// l'application hôte injecte sa propre implémentation via
/// `ZGeoFieldWidget.builder(locationResolver:)` (capturée par closure —
/// invariant AD-4, aucun slot `zcrud_core`). Le bouton « ma position » est
/// masqué/désactivé si ce seam est absent.
///
/// ## Contrat de permissions (à la charge de l'implémentation hôte)
///
/// `zcrud_geo` ne déclare **aucune** permission plateforme et n'appelle
/// **jamais** un SDK de géolocalisation (invariant AD-1 : `geolocator`
/// n'entre pas dans ce paquet — voir le paquet compagnon `zcrud_geo_location`
/// pour une implémentation clé en main). L'implémentation injectée porte tout
/// le cycle :
///
/// 1. vérifier que le **service** de localisation est actif (sinon informer
///    l'utilisateur côté hôte et renvoyer `null`) ;
/// 2. vérifier/demander la **permission** (`denied` → une seule redemande ;
///    `deniedForever` → `null` sans redemander) ;
/// 3. lire la position ;
/// 4. tout refus/échec/timeout → **`null`**, jamais un throw (le champ avale
///    de toute façon les exceptions — invariant AD-10 — mais le contrat
///    nominal est `null`).
///
/// Côté champ : en géométrie polygone/polyligne, une position résolue
/// **recentre la caméra** au lieu d'ajouter un sommet ; en point/cercle elle
/// fixe la valeur ET recentre. Le recentrage n'est effectif que si
/// l'adaptateur est [ZMapCameraCapable] (honoré-si-supporté).
typedef ZGeoLocationResolver = Future<ZGeoPoint?> Function();

/// Callback de fin de **drag d'un sommet** : [index] du sommet dans
/// `shape.vertices` + nouvelle [position] neutre.
typedef ZGeoVertexDragEnd = void Function(int index, ZGeoPoint position);

/// Callback de fin de **déplacement de forme entière** via le marqueur au
/// centroïde : delta en degrés décimaux à appliquer à chaque sommet.
typedef ZGeoShapeDragEnd = void Function(double deltaLat, double deltaLng);

/// Callback de fin de **drag de la poignée de rayon** d'un cercle : nouveau
/// rayon en mètres (distance haversine centre→poignée).
typedef ZGeoRadiusDragEnd = void Function(double radiusMeters);

/// **Capacité caméra optionnelle** d'un adaptateur carte.
///
/// ## Pourquoi une interface séparée et pas deux méthodes sur [ZMapAdapter]
///
/// [ZMapAdapter] est un port **pur** (tous membres abstraits) et ses
/// implémenteurs connus — y compris externes — utilisent `implements` : toute
/// méthode ajoutée au port, même avec un corps no-op par défaut, casserait
/// leur compilation (`implements` exige de tout réimplémenter). La forme
/// additive qui **compile pour un implémenteur existant** (invariant AD-4)
/// est donc une capacité **opt-in** : un adaptateur qui sait piloter sa
/// caméra ajoute `implements ZMapCameraCapable` ; l'appelant teste
/// `adapter is ZMapCameraCapable` et **ne fait rien sinon**
/// (honoré-si-supporté — le « défaut no-op » vit au site d'appel).
///
/// Contrat : jamais de throw si la carte n'est pas (encore) montée — no-op
/// silencieux (invariant AD-10).
abstract class ZMapCameraCapable {
  /// Déplace la caméra sur [center] ([zoom] optionnel ; `null` → zoom courant
  /// conservé si l'adaptateur le connaît, sinon son défaut). Carte non montée
  /// ou point invalide → no-op silencieux, jamais de throw (invariant AD-10).
  Future<void> moveCamera(ZGeoPoint center, {double? zoom});

  /// Cadre la caméra sur la boîte [southWest]→[northEast]. Mêmes garanties
  /// défensives que [moveCamera].
  Future<void> fitBounds(ZGeoPoint southWest, ZGeoPoint northEast);
}

/// **Capacité de gestes d'édition optionnelle** d'un adaptateur carte. Même
/// logique opt-in que [ZMapCameraCapable] (invariant AD-4 : rien n'est ajouté
/// au port pur — un implémenteur externe existant compile inchangé et
/// n'offre simplement pas le drag, contrat honoré-si-supporté).
///
/// Les handlers sont des **champs mutables** (et non des paramètres de
/// `buildMap` : en ajouter casserait les overrides existants du port) : le
/// champ géo les (dé)pose avant chaque `buildMap` ; l'adaptateur rend les
/// poignées correspondantes **uniquement quand le handler est non-`null`**
/// (`null` ⇒ rendu inchangé) :
///
/// - [onVertexDragEnd] ≠ `null` → sommets **draggables** ;
/// - [onShapeDragEnd] ≠ `null` → **marqueur au centroïde** draggable (mode
///   « Déplacer ») ;
/// - [onCircleRadiusDragEnd] ≠ `null` → **poignée de rayon** draggable sur
///   le périmètre du cercle.
abstract class ZMapGesturesCapable {
  /// Fin de drag d'un sommet. `null` → sommets non draggables.
  abstract ZGeoVertexDragEnd? onVertexDragEnd;

  /// Fin de déplacement de la forme entière via le marqueur au centroïde.
  /// `null` → aucun marqueur de déplacement rendu.
  abstract ZGeoShapeDragEnd? onShapeDragEnd;

  /// Fin de drag de la poignée de rayon du cercle. `null` → aucune poignée
  /// rendue.
  abstract ZGeoRadiusDragEnd? onCircleRadiusDragEnd;
}

/// **Couche de lecture multi-formes** : une valeur géo neutre
/// ([ZGeoPoint]/[ZGeoCircle]/[ZGeoShape] — champ [value] typé `Object` faute
/// d'ancêtre commun, routé par `is` dans l'adaptateur) + un [id] stable pour
/// la sélection par tap marqueur. [renderAsPolyline] : `true` → une
/// [ZGeoShape] est rendue en tracé ouvert. Une valeur d'un autre type est
/// **ignorée** sans erreur (invariant AD-10).
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
  /// - [center] : point de centrage initial (si `null`, l'implémentation
  ///   choisit un centre neutre par défaut) ;
  /// - [shape] : aire à surligner (sommets/polyligne) — optionnel ;
  /// - [circle] : cercle à surligner (centre + rayon mètres) — optionnel,
  ///   défaut `null` → aucun cercle ;
  /// - [onTap] : remonté quand l'utilisateur tape la carte, en **coordonnées
  ///   neutres** ([ZGeoPoint]) — jamais un type SDK ;
  /// - [interactive] : `false` pour un aperçu non manipulable (lecture seule) ;
  /// - [tileUrlTemplate] : gabarit d'URL de tuiles **surchargeable par-champ**
  ///   (honoré par l'adaptateur OSM ; ignoré par Google) — `null` → défaut de
  ///   l'adaptateur ;
  /// - [tileUrlTemplates] : gabarits de tuiles **par type de carte** (honoré
  ///   par l'adaptateur OSM pour rendre `mapOptions.mapType`
  ///   satellite/hybride/terrain ; ignoré par Google qui a des types natifs) —
  ///   `null` → défauts audités `ZGeoTileReference.defaults` ;
  /// - [mapStyleJson] : style de carte **surchargeable par-champ** (honoré
  ///   par l'adaptateur Google ; ignoré par OSM) — `null` → défaut de
  ///   l'adaptateur ;
  /// - [defaultZoom] : zoom initial **surchargeable par-champ** (honoré par
  ///   les deux adaptateurs) — `null` → défaut de l'adaptateur ;
  /// - [mapOptions] : options de carte **neutres** pilotées par la barre
  ///   d'outils d'éditeur (type de carte, trafic, bâtiments, gestes,
  ///   contrôles…) — `null` (défaut) → comportement inchangé. Chaque
  ///   adaptateur **honore ce qu'il supporte, ignore le reste** (même
  ///   contrat que [tileUrlTemplate]/[mapStyleJson]) ;
  /// - [renderShapeAsPolyline] : quand `true`, [shape] est rendue en **tracé
  ///   ouvert** (polyligne) et non en polygone fermé — aucun segment de
  ///   fermeture, aucun remplissage. `false` (défaut) → rendu polygone
  ///   inchangé. Signal **neutre**, même contrat honoré-si-supporté que
  ///   [mapOptions] ;
  /// - [minZoom]/[maxZoom] : bornes de zoom **surchargeables par-champ**
  ///   (honorées-si-supportées : OSM `MapOptions.minZoom/maxZoom`, Google
  ///   `minMaxZoomPreference`) — `null` → défaut de l'adaptateur ;
  /// - [overlays] : **couches de lecture multi-formes** (base de
  ///   `ZGeoMapView`) — chaque entrée ([ZGeoMapOverlay]) porte une valeur
  ///   neutre (point/cercle/forme) rendue en plus de [shape]/[circle], avec
  ///   son style porté par la valeur et un **marqueur d'ancrage**
  ///   (centre/centroïde) identifié par `overlay.id`. `null`/vide (défaut) →
  ///   rendu inchangé ;
  /// - [onOverlayMarkerTap] : tap sur le marqueur d'ancrage d'un overlay →
  ///   remonte son `id` (la sélection passe par le **tap marqueur**, pas par
  ///   le corps de la forme). `null` → marqueurs d'overlay non tappables.
  ///
  /// **Style de forme** : le rendu honore le style porté par la **valeur
  /// elle-même** — [ZGeoShape.style], [ZGeoCircle.style] et [ZGeoPoint.style]
  /// — couleurs ARGB neutres → `Color` SDK confiné, épaisseur/visibilité,
  /// marqueur labellisé (`infoWindowTitle`/`iconAsset`/`iconColorArgb`) et
  /// géométrie d'icône (`iconSize`/`iconRotation`/`iconAnchor`), **si
  /// l'adaptateur les supporte**, avec repli sur le thème injecté quand une
  /// couleur est absente. `style == null` ⇒ rendu inchangé. Aucun paramètre
  /// supplémentaire : le style voyage avec la valeur.
  ///
  /// Retourne un `Widget` opaque : l'appelant ne voit aucun type carte.
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

  /// Libère le contrôleur natif éventuel. Idempotent : un second appel ne
  /// doit pas throw.
  void dispose();
}
