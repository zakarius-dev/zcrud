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
typedef ZGeoLocationResolver = Future<ZGeoPoint?> Function();

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
  ///   honoré-si-supporté que [mapOptions].
  ///
  /// **Style de forme (DP-21/M13)** : le rendu honore [ZGeoShape.style]
  /// (couleurs ARGB neutres → `Color` SDK confiné, épaisseur/opacité/visibilité)
  /// et [ZGeoShape.holes] (trous d'un polygone) **si l'adaptateur les supporte**,
  /// avec repli sur le thème injecté (FR-26) quand une couleur est absente. Le
  /// style est porté par la forme elle-même : aucun paramètre supplémentaire.
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
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
  });

  /// Libère le contrôleur natif éventuel (learning E5). Idempotent : un second
  /// appel ne doit pas throw.
  void dispose();
}
