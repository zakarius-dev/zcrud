/// `ZGeoMapView` — **vue de lecture multi-formes** hors formulaire (G6, parité
/// `GeofenceView` legacy `gfv:16-188` ; AD-1/AD-4/AD-10/AD-13/FR-26).
///
/// ## Ce que fait réellement le legacy (mesuré, pas cru)
///
/// `GeofenceView` (`gfv`) : reçoit `Map<DynamicModel, List<GeoShape>>`,
/// pose un libellé par forme via `geoShapeLabelBuilder` (repris en
/// `style.infoWindowTitle`, `gfv:111-114`), **sélectionne par TAP MARQUEUR**
/// (`_onMarkerTap`, `gfv:132-139` — jamais par le corps de la forme), centre
/// initialement sur la **moyenne arithmétique** de tous les points
/// (`gfv:52-76`), zoom initial 14 (`gfv:31`), et bascule `normal ↔ hybrid`
/// via un FAB (`gfv:141-147, 167-185`). Consommé par `berths_screen.dart:131`
/// et `depotages_carte_screen.dart:177`.
///
/// ## Portage zcrud
///
/// - **AUCUN moteur nouveau** : le rendu passe par le port existant
///   ([ZMapAdapter.buildMap]) via son paramètre additif `overlays`
///   ([ZGeoMapOverlay]) — chaque entrée est une valeur NEUTRE
///   ([ZGeoPoint]/[ZGeoCircle]/[ZGeoShape]) rendue avec son style porté
///   (G9/G14) et un marqueur d'ancrage tappable.
/// - [labelBuilder] → `style.infoWindowTitle` (même canal que le legacy) ;
/// - [onShapeSelected] → tap du marqueur d'ancrage (parité mesurée) ;
/// - centrage : moyenne arithmétique (parité `gfv:52-76`) **puis**
///   `fitBounds` sur la boîte englobante globale après le premier frame si
///   l'adaptateur est [ZMapCameraCapable] (G7, honoré-si-supporté) ;
/// - toggle de type de carte : bouton thémé ≥48dp (`Semantics`, l10n injectée,
///   `PositionedDirectional` — AD-13/FR-26 ; le FAB legacy codait blanc/noir).
///
/// **Cycle de vie (MAJEUR-1)** : la vue POSSÈDE son instance d'adaptateur
/// (fabrique appelée 1× en `initState`, disposée en `dispose`) — jamais
/// d'instance partagée. **AD-10** : entrée invalide ignorée, jamais de crash ;
/// sans fabrique, la vue rend un espace vide (pas de carte, pas de throw).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_geo_circle.dart';
import '../domain/z_geo_map_options.dart';
import '../domain/z_geo_metrics.dart';
import '../domain/z_geo_point.dart';
import '../domain/z_geo_shape.dart';
import '../domain/z_geo_shape_style.dart';
import 'z_map_adapter.dart';

/// Entrée de [ZGeoMapView] : une valeur géo neutre + libellé/rappel optionnels.
class ZGeoMapViewEntry {
  /// Construit l'entrée `const`. [value] : [ZGeoPoint]/[ZGeoCircle]/[ZGeoShape]
  /// (tout autre type est ignoré au rendu — AD-10). [id] : identité stable
  /// optionnelle (défaut : index de la liste). [renderAsPolyline] : `true` →
  /// une [ZGeoShape] est rendue en tracé ouvert.
  const ZGeoMapViewEntry({
    required this.value,
    this.id,
    this.renderAsPolyline = false,
  });

  /// Valeur géo neutre — jamais un type SDK.
  final Object value;

  /// Identité stable optionnelle (sélection) ; `null` → index.
  final String? id;

  /// `true` → forme rendue en tracé ouvert.
  final bool renderAsPolyline;
}

/// Libellé d'une entrée (repris en `style.infoWindowTitle` — canal legacy).
typedef ZGeoMapViewLabelBuilder = String? Function(ZGeoMapViewEntry entry);

/// Vue carte multi-formes en lecture seule (G6, parité `GeofenceView`).
class ZGeoMapView extends StatefulWidget {
  /// Construit la vue. [adapterFactory] : fabrique du port carte (`null` →
  /// espace vide, aucun crash). [entries] : formes à afficher.
  /// [labelBuilder] : libellé par entrée (marqueur labellisé G14).
  /// [onShapeSelected] : tap du marqueur d'ancrage d'une entrée.
  /// [initialZoom] : parité legacy 14 (`gfv:31`). [showMapTypeToggle] :
  /// bouton de bascule `normal ↔ hybrid` (parité `gfv:141-147`).
  /// [initialMapType] : type de carte de départ (parité legacy `normal`,
  /// `gfv:42`). [autoFitBounds] : cadrage auto sur la boîte englobante après
  /// le premier frame (si l'adaptateur est [ZMapCameraCapable]).
  const ZGeoMapView({
    required this.entries,
    this.adapterFactory,
    this.labelBuilder,
    this.onShapeSelected,
    this.initialZoom = 14,
    this.showMapTypeToggle = true,
    this.initialMapType = ZGeoMapType.normal,
    this.autoFitBounds = true,
    super.key,
  });

  /// Formes à afficher (entrée invalide ignorée — AD-10).
  final List<ZGeoMapViewEntry> entries;

  /// Fabrique d'adaptateur carte (instance possédée par la vue — MAJEUR-1).
  final ZMapAdapterFactory? adapterFactory;

  /// Libellé par entrée → `style.infoWindowTitle` (parité `gfv:111-114`).
  final ZGeoMapViewLabelBuilder? labelBuilder;

  /// Sélection par tap du marqueur d'ancrage (parité `gfv:132-139`).
  final ValueChanged<ZGeoMapViewEntry>? onShapeSelected;

  /// Zoom initial (parité legacy 14).
  final double initialZoom;

  /// Affiche le bouton de bascule de type de carte (parité `gfv:141-147`).
  final bool showMapTypeToggle;

  /// Type de carte initial (parité legacy `normal`).
  final ZGeoMapType initialMapType;

  /// Cadre la caméra sur la boîte englobante globale au premier frame
  /// (honoré-si-supporté — G7).
  final bool autoFitBounds;

  @override
  State<ZGeoMapView> createState() => _ZGeoMapViewState();
}

class _ZGeoMapViewState extends State<ZGeoMapView> {
  /// Instance d'adaptateur possédée (MAJEUR-1) — créée 1×, disposée en fin de
  /// vie, jamais partagée.
  ZMapAdapter? _adapter;

  /// Type de carte courant (bascule `normal ↔ hybrid`, parité `gfv:141-147`).
  late ZGeoMapType _mapType = widget.initialMapType;

  /// Index des overlays par id (sélection).
  final Map<String, ZGeoMapViewEntry> _entryById =
      <String, ZGeoMapViewEntry>{};

  @override
  void initState() {
    super.initState();
    _adapter = widget.adapterFactory?.call();
    if (widget.autoFitBounds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllBounds());
    }
  }

  @override
  void dispose() {
    _adapter?.dispose();
    super.dispose();
  }

  /// Centre initial : moyenne arithmétique de TOUS les points (parité stricte
  /// `gfv:52-76`). Aucun point exploitable → `null` (l'adaptateur choisit son
  /// centre neutre).
  ZGeoPoint? get _initialCenter {
    double lat = 0, lng = 0;
    int count = 0;
    for (final ZGeoMapViewEntry entry in widget.entries) {
      for (final ZGeoPoint p in _pointsOf(entry.value)) {
        lat += p.lat;
        lng += p.lng;
        count++;
      }
    }
    if (count == 0) return null;
    return ZGeoPoint(lat: lat / count, lng: lng / count);
  }

  static List<ZGeoPoint> _pointsOf(Object value) => switch (value) {
        final ZGeoPoint p when p.isValid => <ZGeoPoint>[p],
        final ZGeoCircle c when c.isValid => <ZGeoPoint>[c.center],
        final ZGeoShape s => s.vertices,
        _ => const <ZGeoPoint>[],
      };

  /// G7 — cadrage auto sur la boîte englobante globale (honoré-si-supporté :
  /// no-op silencieux si l'adaptateur n'a pas la capacité caméra — AD-10).
  Future<void> _fitAllBounds() async {
    final Object? adapter = _adapter;
    if (adapter is! ZMapCameraCapable) return;
    double? minLat, maxLat, minLng, maxLng;
    for (final ZGeoMapViewEntry entry in widget.entries) {
      // La boîte d'un cercle inclut son rayon (extension métrique G12).
      final ZGeoBounds? b = switch (entry.value) {
        final ZGeoCircle c => c.bounds,
        final ZGeoShape s => s.bounds,
        final ZGeoPoint p when p.isValid =>
          ZGeoBounds(southWest: p, northEast: p),
        _ => null,
      };
      if (b == null) continue;
      minLat = (minLat == null || b.southWest.lat < minLat)
          ? b.southWest.lat
          : minLat;
      minLng = (minLng == null || b.southWest.lng < minLng)
          ? b.southWest.lng
          : minLng;
      maxLat = (maxLat == null || b.northEast.lat > maxLat)
          ? b.northEast.lat
          : maxLat;
      maxLng = (maxLng == null || b.northEast.lng > maxLng)
          ? b.northEast.lng
          : maxLng;
    }
    if (minLat == null || minLng == null || maxLat == null || maxLng == null) {
      return;
    }
    try {
      await adapter.fitBounds(
        ZGeoPoint(lat: minLat, lng: minLng),
        ZGeoPoint(lat: maxLat, lng: maxLng),
      );
    } catch (_) {
      // AD-10 : un adaptateur défaillant ne crashe jamais la vue.
    }
  }

  /// Overlays neutres : libellé du [ZGeoMapView.labelBuilder] repris en
  /// `style.infoWindowTitle` quand la valeur n'en porte pas déjà un (même
  /// politique que le legacy `gfv:111-114`, qui écrase — ici la valeur PRIME :
  /// une donnée existante n'est pas fabriquée par-dessus).
  List<ZGeoMapOverlay> _overlays() {
    _entryById.clear();
    final List<ZGeoMapOverlay> overlays = <ZGeoMapOverlay>[];
    for (int i = 0; i < widget.entries.length; i++) {
      final ZGeoMapViewEntry entry = widget.entries[i];
      final String id = entry.id ?? 'entry-$i';
      _entryById[id] = entry;
      final String? title = widget.labelBuilder?.call(entry);
      Object value = entry.value;
      if (title != null && title.isNotEmpty) {
        value = switch (value) {
          final ZGeoPoint p when p.style?.infoWindowTitle == null =>
            p.copyWith(
              style: (p.style ?? const ZGeoShapeStyle())
                  .copyWith(infoWindowTitle: title),
            ),
          final ZGeoCircle c when c.style?.infoWindowTitle == null =>
            c.copyWith(
              style: (c.style ?? const ZGeoShapeStyle())
                  .copyWith(infoWindowTitle: title),
            ),
          final ZGeoShape s when s.style?.infoWindowTitle == null =>
            s.copyWith(
              style: (s.style ?? const ZGeoShapeStyle())
                  .copyWith(infoWindowTitle: title),
            ),
          _ => value,
        };
      }
      overlays.add(ZGeoMapOverlay(
        id: id,
        value: value,
        renderAsPolyline: entry.renderAsPolyline,
      ));
    }
    return overlays;
  }

  void _onOverlayTap(String id) {
    final ZGeoMapViewEntry? entry = _entryById[id];
    if (entry != null) widget.onShapeSelected?.call(entry);
  }

  /// Bascule `normal ↔ hybrid` (parité `gfv:141-147`) — action discrète.
  void _toggleMapType() => setState(() {
        _mapType = _mapType == ZGeoMapType.normal
            ? ZGeoMapType.hybrid
            : ZGeoMapType.normal;
      });

  @override
  Widget build(BuildContext context) {
    final ZMapAdapter? adapter = _adapter;
    if (adapter == null) {
      // AD-10 : sans fabrique, espace vide — jamais de crash.
      return const SizedBox.shrink();
    }
    final Widget map = adapter.buildMap(
      context,
      center: _initialCenter,
      interactive: true,
      defaultZoom: widget.initialZoom,
      mapOptions: ZGeoMapOptions(mapType: _mapType),
      overlays: _overlays(),
      onOverlayMarkerTap:
          widget.onShapeSelected == null ? null : _onOverlayTap,
    );
    if (!widget.showMapTypeToggle) return map;
    final String toggleText = label(
      context,
      _mapType == ZGeoMapType.normal
          ? 'geo.mapView.showSatellite'
          : 'geo.mapView.showMap',
      fallback: _mapType == ZGeoMapType.normal ? 'Satellite' : 'Carte',
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(child: map),
        PositionedDirectional(
          top: 16,
          end: 16,
          child: ConstrainedBox(
            key: const Key('z-geo-map-view-type-toggle'),
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Semantics(
              container: true,
              button: true,
              label: toggleText,
              child: ExcludeSemantics(
                // Couleurs par rôles de thème (FR-26 — le FAB legacy codait
                // blanc/noir en dur, `gfv:175-180`).
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    onPressed: _toggleMapType,
                    tooltip: toggleText,
                    icon: Icon(
                      _mapType == ZGeoMapType.normal
                          ? Icons.satellite_alt_outlined
                          : Icons.map_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
